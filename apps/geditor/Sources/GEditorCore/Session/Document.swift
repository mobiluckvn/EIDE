import Foundation

/// Một tài liệu đang mở — lớp ghép mọi mảnh của lõi lại với nhau.
///
/// Trước lớp này, mở một file cần người gọi tự làm đúng thứ tự: mmap, nhận diện bảng mã, giải
/// mã, dựng buffer, phân tích EOL, nhớ byte gốc để còn diễn giải lại được, kiểm quyền ghi.
/// Bỏ sót bất kỳ bước nào cũng ra một sản phẩm chạy được nhưng sai — và cái sai chỉ lộ ra khi
/// người dùng lưu đè lên dữ liệu của họ.
///
/// Ba bất biến lớp này giữ:
///
/// 1. **Bộ nhớ luôn là UTF-8.** Bảng mã chỉ tồn tại ở hai đầu: lúc đọc và lúc ghi.
/// 2. **Byte gốc còn nguyên cho tới khi lưu.** Đó là điều kiện để "diễn giải lại" (FR-ENC-203)
///    có nghĩa — và với file UTF-8 thì "byte gốc" chính là vùng mmap, không tốn thêm gì.
/// 3. **Mọi đường ghi đi qua `AtomicFileWriter`.** Ngắt giữa chừng để lại file gốc nguyên vẹn
///    (NFR-REL-02, TC-DOC-02).
public final class Document {

    public enum Failure: Error, CustomStringConvertible {
        case readOnly(path: String)
        case cannotReinterpretModifiedDocument
        case noPathForSave
        case lossyConversion(EncodingChange.ConversionPreview)

        public var description: String {
            switch self {
            case .readOnly(let path):
                return "Tài liệu chỉ đọc: \(path)"
            case .cannotReinterpretModifiedDocument:
                return "Không diễn giải lại được tài liệu đã sửa — hãy hoàn tác hoặc lưu trước. "
                    + "Diễn giải lại đọc lại BYTE GỐC trên đĩa, nên nó sẽ vứt bỏ mọi thay đổi."
            case .noPathForSave:
                return "Tài liệu chưa có đường dẫn — dùng Lưu thành…"
            case .lossyConversion(let preview):
                return preview.warning ?? "Chuyển đổi bảng mã làm mất ký tự"
            }
        }
    }

    /// Trạng thái file trên đĩa so với lúc ta đọc nó (TC-DOC-06, NFR-REL-04).
    public enum ExternalChange: Equatable {
        case unchanged
        case modified
        case deleted
        /// Chưa từng lưu nên không có gì để so.
        case unknown
    }

    public struct SaveResult {
        public let path: String
        public let encoding: TextEncoding
        public let eol: EOL
        public let bytesWritten: Int
        /// Số ký tự không biểu diễn được trong bảng mã đích và đã bị thay bằng `?`.
        public let unrepresentable: Int
    }

    private struct Fingerprint: Equatable {
        let size: Int
        let modified: Date
    }

    // MARK: - Trạng thái

    public let id: String

    /// Hai đường dẫn có trỏ vào cùng một file không, sau khi đi hết symlink.
    private static func sameFile(_ a: String, _ b: String) -> Bool {
        URL(fileURLWithPath: a).resolvingSymlinksInPath().standardizedFileURL
            == URL(fileURLWithPath: b).resolvingSymlinksInPath().standardizedFileURL
    }

    /// URL của tài liệu, để bài kiểm hỏi đúng khóa mà `SandboxAccess` đang đếm.
    var pathURLForTesting: URL? { path.map { URL(fileURLWithPath: $0) } }

    /// Bookmark để mở lại file này ở phiên sau. Xem `SandboxAccess`.
    public internal(set) var accessBookmark: Data?

    /// URL đang giữ quyền truy cập, nếu tài liệu này mở ra từ bookmark.
    ///
    /// Giữ để thả đúng một lượt lúc đóng. Không thả thì quyền tích lại suốt phiên; thả nhầm
    /// chỗ thì một tab khác trỏ vào cùng file mất quyền giữa chừng.
    private var heldAccess: URL?

    /// Nhận lại QUYỀN truy cập sandbox từ một tài liệu khác, rồi tước quyền ấy khỏi nó.
    ///
    /// Cần khi khôi phục một tệp media từ bookmark: bookmark mở ra quyền, nhưng nội dung phải
    /// dựng lại bằng đường media trên đúng đường dẫn ấy — và tài liệu dựng theo đường dẫn không
    /// mang theo quyền nào. Không chuyển quyền sang thì lần ⌘S sau bị sandbox từ chối, im lặng,
    /// và chỉ ở bản App Store.
    ///
    /// "Tước khỏi nó" là phần bắt buộc: hai tài liệu cùng giữ một `heldAccess` thì cái nào bị
    /// giải phóng trước cũng gọi `SandboxAccess.end`, và cái còn lại mất quyền giữa chừng.
    public func adoptAccess(from other: Document) {
        heldAccess = other.heldAccess
        accessBookmark = other.accessBookmark
        other.heldAccess = nil
    }

    deinit {
        if let heldAccess { SandboxAccess.end(heldAccess) }
    }
    public private(set) var path: String?
    public let buffer: TextBuffer

    /// Khác `nil` khi tài liệu này không phải văn bản — xem `Document.forMedia`.
    ///
    /// Lớp trên hỏi cờ này để biết dựng khung xem nào. Nó KHÔNG suy lại từ đường dẫn mỗi lần
    /// hỏi: nhận diện phải đọc tệp, và một thuộc tính đọc tệp mỗi lần truy cập là thứ sẽ bị gọi
    /// trong vòng lặp vẽ mà không ai để ý.
    public private(set) var mediaKind: MediaKind?

    /// Sheet đang mở của một `.xlsx`, theo TÊN.
    ///
    /// **Phải có, và phải theo tên chứ không theo chỉ số.** Trước khi có nó, đường ghi ngược
    /// luôn nhắm vào `sheets.first` — đúng khi chỉ mở được sheet đầu, và thành ghi NHẦM SHEET
    /// ngay khi người dùng chuyển sang sheet khác. Đó là kiểu hỏng im lặng tệ nhất: dữ liệu
    /// vẫn được ghi, vẫn mở lại được, chỉ là nằm sai chỗ.
    ///
    /// Theo TÊN vì chỉ số đổi khi người dùng sắp lại sheet trong Excel giữa hai lần mở, còn tên
    /// thì không. Tên không còn thì phép ghi phải TỪ CHỐI, không được rơi về sheet đầu.
    public var spreadsheetSheet: String?

    /// Bảng mã đã dùng để ĐỌC tài liệu này.
    public private(set) var encoding: TextEncoding
    /// Bảng mã sẽ dùng khi GHI. Khác `encoding` sau khi người dùng chọn "Chuyển đổi sang…".
    public private(set) var targetEncoding: TextEncoding
    public private(set) var detection: [EncodingDetector.Guess]
    public private(set) var eolReport: EOLReport
    public private(set) var isReadOnly: Bool

    /// Quyền ghi THẬT của file, nhớ lại trước khi chế độ theo dõi khóa tạm (FR-DOC-309).
    private var wasReadOnlyBeforeFollow = false

    /// Large File Mode (FR-DOC-310): tài liệu quá lớn cho các thao tác dựng cả nội dung
    /// trong RAM. Lớp trên phải hỏi cờ này trước khi gọi những thao tác đó.
    public private(set) var isLargeFileMode: Bool

    /// Ngưỡng bật Large File Mode.
    public static let largeFileThreshold = 256 * 1024 * 1024

    /// Nguồn byte GỐC như trên đĩa — giữ để diễn giải lại được. Với file UTF-8 đây chính là
    /// vùng mmap nên không tốn thêm bộ nhớ nào.
    private var originalSource: ByteSource?
    private var fingerprint: Fingerprint?
    private var savedUndoDepth: Int
    private var savedHistoryBranch: Int

    private init(
        id: String,
        path: String?,
        buffer: TextBuffer,
        encoding: TextEncoding,
        detection: [EncodingDetector.Guess],
        eolReport: EOLReport,
        isReadOnly: Bool,
        isLargeFileMode: Bool,
        originalSource: ByteSource?,
        fingerprint: Fingerprint?
    ) {
        self.id = id
        self.path = path
        self.buffer = buffer
        self.encoding = encoding
        self.targetEncoding = encoding
        self.detection = detection
        self.eolReport = eolReport
        self.isReadOnly = isReadOnly
        self.isLargeFileMode = isLargeFileMode
        self.originalSource = originalSource
        self.fingerprint = fingerprint
        self.savedUndoDepth = buffer.undoDepth
        self.savedHistoryBranch = buffer.historyBranch
    }

    // MARK: - Mở

    /// Mở file: nhận diện bảng mã, giải mã, dựng buffer.
    ///
    /// - Parameter encoding: ép dùng bảng mã này thay vì tự nhận diện.
    public static func open(path: String, encoding forced: TextEncoding? = nil) throws -> Document {
        let document = try load(path: path, encoding: forced, keepPath: true)
        // Tạo bookmark NGAY LÚC NÀY, khi quyền còn trong tay. Đợi tới lúc cần dùng thì đã muộn:
        // trong sandbox, quyền với file người dùng vừa chọn chết theo lần chạy app.
        document.accessBookmark = SandboxAccess.makeBookmark(for: URL(fileURLWithPath: path))
        return document
    }

    /// Mở lại một file từ security-scoped bookmark của phiên trước (FR-DOC-303 trong sandbox).
    ///
    /// Trả `nil` khi bookmark không giải mã được — file đã bị xóa, hoặc chuyển sang máy khác.
    /// Chỗ gọi phải phân biệt được ca ấy với ca "mở được", vì người dùng cần biết tab nào mất
    /// và vì sao.
    /// - Parameter preferredPath: đường dẫn người dùng đã thấy ở phiên trước. Bookmark giải mã
    ///   ra dạng ĐÃ ĐI QUA SYMLINK (`/private/var/…` thay vì `/var/…`), và nếu để nguyên dạng ấy
    ///   thì tab hiện ra một đường khác với hôm qua, còn mọi phép so khớp "file này đã mở chưa"
    ///   theo chuỗi đường dẫn sẽ trượt. Giữ tên cũ khi cả hai trỏ vào CÙNG một file.
    public static func open(
        bookmark: Data, preferredPath: String? = nil, encoding forced: TextEncoding? = nil
    ) -> Document? {
        guard let resolved = SandboxAccess.open(bookmark) else { return nil }
        guard let document = try? load(
            path: resolved.url.path, encoding: forced, keepPath: true
        ) else {
            SandboxAccess.end(resolved.url)
            return nil
        }
        if let preferredPath, sameFile(preferredPath, resolved.url.path) {
            document.path = preferredPath
        }
        document.heldAccess = resolved.url
        // Bookmark cũ (file bị đổi tên hoặc di chuyển) vẫn dùng được lần này, nhưng phải làm
        // mới — bỏ qua thì mỗi lần đổi tên lại tiến gần hơn tới lần hỏng hẳn.
        document.accessBookmark = resolved.isStale
            ? SandboxAccess.makeBookmark(for: resolved.url) ?? bookmark
            : bookmark
        return document
    }

    /// Nội dung đến từ ống dẫn (`ps aux | geditor`), đã được ghi ra file tạm.
    ///
    /// Giống `open` về nhận diện bảng mã, EOL và Large File Mode, nhưng `path` là `nil`: đây
    /// là tài liệu CHƯA CÓ TRÊN ĐĨA theo nghĩa người dùng hiểu, nên Lưu phải hỏi Lưu ở đâu chứ
    /// không được ghi đè lên file tạm rồi biến mất.
    ///
    /// File tạm được XÓA ngay sau khi mở. Vùng mmap vẫn đọc được sau `unlink` (POSIX giữ inode
    /// tới khi không còn ai tham chiếu), nên nội dung không mất mà cũng không để lại rác —
    /// quan trọng vì dữ liệu qua ống dẫn có thể là thứ nhạy cảm người dùng không muốn nằm lại
    /// trong /tmp.
    public static func fromPipe(temporaryPath: String, encoding forced: TextEncoding? = nil) throws -> Document {
        let document = try load(path: temporaryPath, encoding: forced, keepPath: false)
        unlink(temporaryPath)
        return document
    }

    private static func load(path: String, encoding forced: TextEncoding?, keepPath: Bool) throws -> Document {
        let mapped = try MappedFile(path: path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)

        // Nhận diện chỉ đọc phần đầu file — `EncodingDetector` tự giới hạn mẫu, nhưng ta cũng
        // không muốn dựng mảng cả GB chỉ để đoán.
        let sampleSize = min(mapped.count, EncodingDetector.sampleBytes)
        let sample = mapped.withUnsafeBytes { Array($0.prefix(sampleSize)) }
        let guesses = forced == nil ? EncodingDetector.detect(sample) : []
        let encoding = forced ?? guesses.first?.encoding ?? .utf8

        let buffer: TextBuffer
        if encoding == .utf8 {
            // Đường nhanh: UTF-8 không BOM thì byte trên đĩa ĐÃ LÀ biểu diễn trong bộ nhớ.
            // Dựng buffer thẳng trên vùng mmap — không sao chép byte nào, và đây là đường mà
            // Large File Mode dựa vào (ADR-02).
            buffer = TextBuffer(original: mapped)
        } else {
            let raw = mapped.withUnsafeBytes { Array($0) }
            buffer = TextBuffer(original: MemoryByteSource(try EncodingConverter.decode(raw, from: encoding)))
        }

        // Phân tích EOL trên phần đầu: kiểu EOL không đổi giữa chừng ở file thật, và quét cả
        // 1 GB chỉ để hiện "CRLF" trên status bar là không đáng.
        let eolSample = buffer.bytes(in: 0 ..< min(buffer.count, EncodingDetector.sampleBytes))

        return Document(
            id: UUID().uuidString,
            path: keepPath ? path : nil,
            buffer: buffer,
            encoding: encoding,
            detection: guesses,
            eolReport: EncodingEngine.analyzeEOL(eolSample),
            isReadOnly: keepPath && !FileManager.default.isWritableFile(atPath: path),
            isLargeFileMode: mapped.count >= largeFileThreshold,
            originalSource: mapped,
            fingerprint: keepPath ? fingerprint(from: attributes) : nil
        )
    }

    /// Tài liệu KHÔNG phải văn bản — ảnh, PDF, Office, file nén.
    ///
    /// **Vì sao vẫn là một `Document`.** Cả bộ máy tab của ứng dụng đều khoá theo
    /// `document.path`: mở trùng, phiên làm việc, danh sách file gần đây, tab vừa đóng, `-w`
    /// của dòng lệnh. Dựng một loại tab thứ hai nằm ngoài bộ máy ấy là chép lại cả sáu thứ đó
    /// và để chúng trôi khỏi nhau. Nên tài liệu media vẫn là `Document` bình thường, chỉ khác
    /// hai điểm: **buffer rỗng** (không giải mã nhị phân thành văn bản) và `mediaKind` khác
    /// `nil` để lớp trên biết mà dựng khung xem tương ứng.
    ///
    /// **Vì sao buffer rỗng chứ không phải nội dung tệp.** Một PDF 200 MB mà đem giải mã theo
    /// bảng mã rồi dựng chỉ mục dòng thì tốn cả trí nhớ lẫn thời gian cho một thứ không ai
    /// nhìn. Nội dung thật do khung xem tự đọc từ đĩa, theo cách của định dạng ấy.
    ///
    /// **Khoá chỉ đọc ngay từ đầu.** Buffer rỗng mà cho gõ vào thì ⌘S sẽ ghi một tệp rỗng đè
    /// lên ảnh của người dùng. Việc sửa nội dung media đi qua đường riêng của từng khung xem,
    /// không đi qua buffer.
    public static func forMedia(path: String, kind: MediaKind) -> Document {
        let document = Document(
            id: UUID().uuidString,
            path: path,
            buffer: TextBuffer(text: ""),
            encoding: .utf8,
            detection: [],
            eolReport: EOLReport(lf: 0, crlf: 0, cr: 0),
            isReadOnly: true,
            isLargeFileMode: false,
            originalSource: nil,
            fingerprint: fingerprint(from: try? FileManager.default
                .attributesOfItem(atPath: path))
        )
        document.mediaKind = kind
        // Cùng lý do với `open(path:)`: trong sandbox, quyền với tệp người dùng vừa chọn chết
        // theo lần chạy app, nên bookmark phải tạo NGAY lúc quyền còn trong tay.
        document.accessBookmark = SandboxAccess.makeBookmark(for: URL(fileURLWithPath: path))
        return document
    }

    /// Bảng tính `.xlsx` đã đổi sang CSV — mở ra bằng chính bảng CSV của sản phẩm.
    ///
    /// **Khác `forMedia` ở chỗ buffer CÓ nội dung.** Đây là điểm mấu chốt của cả hướng đi: một
    /// khi bảng tính đã ở dạng cột, toàn bộ Query Workbench, bàn làm sạch, biểu đồ, thẻ chất
    /// lượng và khai phá theo nhóm dùng được ngay — không phải dựng lại thứ gì.
    ///
    /// **Vẫn KHOÁ chỉ đọc, và đó là chỗ chưa xong.** Buffer là CSV còn tệp trên đĩa là `.xlsx`;
    /// cho ⌘S chạy thì nó ghi CSV đè lên bảng tính của người dùng — mất sạch sheet khác, công
    /// thức, định dạng. Ghi ngược đúng cách đòi sửa ĐÚNG những ô đã đổi trong XML gốc và giữ
    /// nguyên phần còn lại, cùng lối "không đụng bản gốc" của chú thích PDF. Chưa làm thì phải
    /// KHOÁ, không được để mở rồi hy vọng người dùng không bấm.
    public static func forSpreadsheet(
        path: String, csv: String, kind: MediaKind = .excel, sheet: String? = nil
    ) -> Document {
        let document = Document(
            id: UUID().uuidString,
            path: path,
            buffer: TextBuffer(text: csv),
            encoding: .utf8,
            detection: [],
            eolReport: EOLReport(lf: csv.isEmpty ? 0 : 1, crlf: 0, cr: 0),
            // Cả ba định dạng Office nay GHI NGƯỢC được (`XLSXWriter`, `DOCXWriter`,
            // `PPTXWriter`), nên không cái nào còn bị khoá. Luật vẫn giữ nguyên cho tương lai:
            // định dạng nào chưa có bộ ghi thì phải khoá, chứ không mở rồi hy vọng người dùng
            // không bấm ⌘S.
            isReadOnly: false,
            isLargeFileMode: false,
            originalSource: nil,
            fingerprint: fingerprint(from: try? FileManager.default
                .attributesOfItem(atPath: path))
        )
        document.mediaKind = kind
        document.spreadsheetSheet = sheet
        document.accessBookmark = SandboxAccess.makeBookmark(for: URL(fileURLWithPath: path))
        return document
    }

    /// Đánh dấu tài liệu Office đã lưu xong.
    ///
    /// Tài liệu Office không đi qua `save()` — nội dung của nó ghi ngược vào OOXML bằng đường
    /// riêng. Nhưng cờ "đã sửa" thì vẫn phải tắt, nếu không thì tab giữ dấu chấm mãi và câu hỏi
    /// "có thay đổi chưa lưu" hiện ra sau khi đã lưu.
    public func markSavedForOffice() {
        savedUndoDepth = buffer.undoDepth
        savedHistoryBranch = buffer.historyBranch
    }

    /// Tài liệu mới, chưa có trên đĩa (FR-ENC-207).
    public static func untitled(encoding: TextEncoding = .utf8, eol: EOL = .lf) -> Document {
        Document(
            id: UUID().uuidString,
            path: nil,
            buffer: TextBuffer(text: ""),
            encoding: encoding,
            detection: [],
            eolReport: EOLReport(lf: eol == .lf ? 1 : 0, crlf: eol == .crlf ? 1 : 0, cr: eol == .cr ? 1 : 0),
            isReadOnly: false,
            isLargeFileMode: false,
            originalSource: nil,
            fingerprint: nil
        )
    }

    private static func fingerprint(from attributes: [FileAttributeKey: Any]?) -> Fingerprint? {
        guard let size = attributes?[.size] as? NSNumber,
              let modified = attributes?[.modificationDate] as? Date
        else { return nil }
        return Fingerprint(size: size.intValue, modified: modified)
    }

    // MARK: - Trạng thái sửa đổi

    public var isModified: Bool {
        buffer.undoDepth != savedUndoDepth || buffer.historyBranch != savedHistoryBranch
    }

    /// Đánh dấu tài liệu ĐÃ LƯU mà không tự ghi — khi một thành phần KHÁC đã ghi tệp.
    ///
    /// Trong EIDE, nút Lưu của một tệp thuộc dự án đi qua năng lực `code.human_save` chứ không
    /// ghi thẳng đĩa (UXD-13 v2.0 §7.1): năng lực ấy phải là NGƯỜI GHI DUY NHẤT thì phép kiểm
    /// "tệp đã đổi từ lúc mở" mới có nghĩa — nếu trình soạn thảo ghi trước rồi mới gọi năng lực
    /// thì nội dung trên đĩa đã là nội dung mới, và không xung đột nào còn phát hiện được.
    ///
    /// Nên sau khi năng lực ghi xong, tài liệu cần biết mình không còn "sửa dở" nữa. Không có
    /// hàm này thì dấu chấm "chưa lưu" ở tiêu đề cửa sổ nằm lại vĩnh viễn, và ⌘S lần sau lại
    /// gửi đúng nội dung ấy đi lần nữa.
    public func danhDauDaLuu() {
        savedUndoDepth = buffer.undoDepth
        savedHistoryBranch = buffer.historyBranch
    }

    /// Kiểu EOL chiếm đa số; `nil` khi tài liệu chưa có dòng nào kết thúc.
    public var eol: EOL? { eolReport.dominant }

    /// File trộn nhiều kiểu EOL → banner cảnh báo + nút chuẩn hóa (TC-ENC-04).
    public var hasMixedEOL: Bool { eolReport.isMixed }

    /// Khóa tài liệu ở chế độ chỉ đọc (FR-DOC-311) — `geditor --read-only`.
    ///
    /// Chỉ khóa thêm, không mở khóa: file không có quyền ghi thì vẫn là chỉ đọc dù ai gọi gì.
    public func lockForReading() {
        isReadOnly = true
    }

    /// Khóa chỉ đọc TẠM THỜI cho chế độ theo dõi file (FR-DOC-309).
    ///
    /// Khác `lockForReading` ở chỗ nó mở lại được — nhưng chỉ mở lại về đúng trạng thái quyền
    /// THẬT của file. Nhớ lại trạng thái cũ chứ không cứng nhắc gán `false`: file vốn không có
    /// quyền ghi mà tắt theo dõi xong lại cho sửa là hứa một điều sẽ vỡ lúc lưu.
    public func markReadOnlyForFollowMode() {
        wasReadOnlyBeforeFollow = isReadOnly
        isReadOnly = true
    }

    public func clearReadOnlyForFollowMode() {
        isReadOnly = wasReadOnlyBeforeFollow
    }

    /// Mở khoá theo YÊU CẦU CỦA NGƯỜI DÙNG — họ bấm vào mục «chỉ đọc» trên thanh trạng thái.
    ///
    /// Tách khỏi `clearReadOnlyForFollowMode` dù hai hàm có lúc làm cùng một việc: hàm kia khôi
    /// phục trạng thái TRƯỚC KHI theo dõi, còn hàm này nói "người dùng muốn sửa tệp này". Gọi
    /// nhầm hàm kia cho tệp mở bằng `--read-only` thì nó mở khoá dựa trên một biến chưa bao giờ
    /// được ghi, tức đúng kết quả nhưng vì nhầm lý do — và lần sửa sau sẽ không còn đúng nữa.
    ///
    /// KHÔNG kiểm quyền ghi ở đây: lõi không quyết định thay tầng giao diện, và chỗ gọi đã hỏi
    /// hệ tệp trước. Cờ này chỉ nói tài liệu có cho gõ hay không.
    public func unlockForEditing() {
        isReadOnly = false
        wasReadOnlyBeforeFollow = false
    }

    // MARK: - FR-ENC-203: diễn giải lại vs chuyển đổi

    /// Đọc lại BYTE GỐC bằng bảng mã khác — sửa mojibake (TC-ENC-02).
    ///
    /// Từ chối khi tài liệu đã sửa: thao tác này thay toàn bộ nội dung bằng bản giải mã lại
    /// của byte trên đĩa, nên mọi thay đổi chưa lưu sẽ mất. Bắt người gọi xử lý tình huống đó
    /// một cách tường minh thay vì âm thầm vứt dữ liệu.
    public func reinterpret(as newEncoding: TextEncoding) throws {
        guard !isModified else { throw Failure.cannotReinterpretModifiedDocument }
        guard let originalSource else { throw Failure.noPathForSave }

        let raw = originalSource.withUnsafeBytes { Array($0) }
        let decoded = try EncodingConverter.decode(raw, from: newEncoding)

        // Đi qua `applyEdits` chứ không dựng buffer mới: giữ đúng một lịch sử undo cho tài
        // liệu, nên người dùng đảo lại được nếu đoán sai bảng mã.
        buffer.applyEdits(
            [TextEdit(range: 0 ..< buffer.count, bytes: decoded)],
            label: "Diễn giải lại theo \(newEncoding.displayName)"
        )
        encoding = newEncoding
        targetEncoding = newEncoding
        eolReport = EncodingEngine.analyzeEOL(
            buffer.bytes(in: 0 ..< min(buffer.count, EncodingDetector.sampleBytes))
        )
    }

    /// Xem trước việc chuyển đổi sang bảng mã khác — KHÔNG đổi gì cả.
    public func previewConversion(to newEncoding: TextEncoding) -> EncodingChange.ConversionPreview {
        EncodingChange.convert(utf8: buffer.bytes(in: 0 ..< buffer.count), to: newEncoding)
    }

    /// Chọn bảng mã sẽ dùng khi ghi. Nội dung không đổi; file sẽ đổi lúc lưu.
    public func setTargetEncoding(_ newEncoding: TextEncoding) {
        targetEncoding = newEncoding
    }

    // MARK: - EOL (FR-ENC-204)

    /// Chuẩn hóa mọi EOL về `target` — trả về sửa đổi, MỘT bước undo (TC-ENC-04).
    public func normalizeEOL(to target: EOL) -> [TextEdit] {
        let content = buffer.bytes(in: 0 ..< buffer.count)
        let converted = EncodingEngine.convertEOL(content, to: target)
        guard converted != content else { return [] }
        return [TextEdit(range: 0 ..< buffer.count, bytes: converted)]
    }

    /// Cập nhật lại thống kê EOL sau khi nội dung đổi.
    public func refreshEOLReport() {
        eolReport = EncodingEngine.analyzeEOL(
            buffer.bytes(in: 0 ..< min(buffer.count, EncodingDetector.sampleBytes))
        )
    }

    // MARK: - Lưu (FR-DOC-314, NFR-REL-02)

    /// Lưu về đúng chỗ cũ.
    ///
    /// - Parameter allowLossy: bắt buộc phải `true` khi bảng mã đích không chứa hết ký tự.
    ///   Mặc định `false` để việc mất ký tự không bao giờ xảy ra mà người gọi không biết.
    @discardableResult
    public func save(allowLossy: Bool = false) throws -> SaveResult {
        guard let path else { throw Failure.noPathForSave }
        guard !isReadOnly else { throw Failure.readOnly(path: path) }
        return try write(to: path, encoding: targetEncoding, allowLossy: allowLossy)
    }

    /// Lưu thành file khác, đổi được cả bảng mã và EOL (FR-DOC-314).
    ///
    /// Đổi EOL được áp vào BUFFER trước khi ghi, như một bước undo, để nội dung trong bộ nhớ
    /// và nội dung trên đĩa không bao giờ lệch nhau.
    @discardableResult
    public func save(
        to newPath: String,
        encoding newEncoding: TextEncoding? = nil,
        eol newEOL: EOL? = nil,
        allowLossy: Bool = false
    ) throws -> SaveResult {
        if let newEOL {
            let edits = normalizeEOL(to: newEOL)
            if !edits.isEmpty {
                buffer.applyEdits(edits, label: "Chuyển EOL sang \(newEOL.rawValue)")
            }
        }

        let result = try write(
            to: newPath, encoding: newEncoding ?? targetEncoding, allowLossy: allowLossy
        )

        // "Lưu thành…" chuyển quyền sở hữu sang file mới: tài liệu từ đây trỏ vào đó, và cờ
        // chỉ-đọc phải tính lại theo file mới chứ không giữ của file cũ.
        path = newPath
        encoding = result.encoding
        targetEncoding = result.encoding
        isReadOnly = !FileManager.default.isWritableFile(atPath: newPath)
        refreshEOLReport()
        return result
    }

    private func write(
        to targetPath: String, encoding writeEncoding: TextEncoding, allowLossy: Bool
    ) throws -> SaveResult {
        let content = buffer.bytes(in: 0 ..< buffer.count)
        let preview = EncodingChange.convert(utf8: content, to: writeEncoding)

        if preview.isLossy && !allowLossy {
            throw Failure.lossyConversion(preview)
        }

        // Ghi lại bản CŨ trước khi đè lên nó (FR-DOC-305).
        //
        // Thứ tự là bắt buộc: kho phiên bản giữ nội dung file tại thời điểm gọi, nên gọi sau
        // khi ghi thì lịch sử toàn bản mới. Và nó KHÔNG được làm hỏng phép lưu — lịch sử là
        // tiện nghi, nội dung mới là thứ người dùng đang giữ trong tay.
        DocumentVersions.recordVersion(of: targetPath)

        try AtomicFileWriter.write(preview.bytes, to: targetPath)

        savedUndoDepth = buffer.undoDepth
        savedHistoryBranch = buffer.historyBranch
        fingerprint = Self.fingerprint(
            from: try? FileManager.default.attributesOfItem(atPath: targetPath)
        )

        return SaveResult(
            path: targetPath,
            encoding: writeEncoding,
            eol: eolReport.dominant ?? .lf,
            bytesWritten: preview.bytes.count,
            unrepresentable: preview.unrepresentable
        )
    }

    // MARK: - Thay đổi từ bên ngoài (TC-DOC-06)

    /// File trên đĩa có bị công cụ khác sửa từ lúc ta đọc/ghi lần cuối không.
    ///
    /// So kích thước và thời điểm sửa. Không đọc lại nội dung: hàm này được gọi mỗi lần cửa
    /// sổ giành lại tiêu điểm, mà đọc lại một file 1 GB ở đó thì treo giao diện.
    public func externalChange() -> ExternalChange {
        guard let path, let fingerprint else { return .unknown }
        guard FileManager.default.fileExists(atPath: path) else { return .deleted }
        let current = Self.fingerprint(from: try? FileManager.default.attributesOfItem(atPath: path))
        return current == fingerprint ? .unchanged : .modified
    }

    /// Đọc lại từ đĩa, bỏ nội dung đang có.
    public func revert() throws {
        guard let path else { throw Failure.noPathForSave }
        let fresh = try Document.open(path: path, encoding: encoding)
        buffer.applyEdits(
            [TextEdit(range: 0 ..< buffer.count, bytes: fresh.buffer.bytes(in: 0 ..< fresh.buffer.count))],
            label: "Đọc lại từ đĩa"
        )
        originalSource = fresh.originalSource
        fingerprint = fresh.fingerprint
        eolReport = fresh.eolReport
        isReadOnly = fresh.isReadOnly
        savedUndoDepth = buffer.undoDepth
        savedHistoryBranch = buffer.historyBranch
    }

    // MARK: - Bản nháp (FR-DOC-304)

    /// Ghi bản nháp chưa lưu. Nội dung ghi ở dạng UTF-8 — bản nháp là của ta, không phải của
    /// người dùng, nên không cần theo bảng mã đích.
    ///
    /// Chọn giữa hai cách theo KÍCH THƯỚC, không theo cấu hình:
    ///
    ///  - **delta** — chỉ ghi nhật ký sửa đổi, phát lại trên file gốc lúc khôi phục. Sửa vài
    ///    chỗ trong file 1 GB thì bản nháp chỉ vài KB.
    ///  - **đầy đủ** — ghi cả nội dung, theo từng đoạn thẳng từ piece table.
    ///
    /// Bản đầu luôn ghi đầy đủ VÀ dựng cả tài liệu thành một mảng: với Large File Mode đó là
    /// cấp phát 1 GB rồi ghi 1 GB xuống đĩa MỖI 20 GIÂY. Đường nào cũng sai — hết RAM thì thôi
    /// autosave, mà autosave là thứ TC-DOC-01 dựa vào để không mất dữ liệu khi bị kill -9.
    ///
    /// Delta cần file gốc còn nguyên để phát lại, nên chỉ dùng khi tài liệu ĐÃ có đường dẫn và
    /// file trên đĩa chưa bị ai đổi.
    public func writeSnapshot(caretOffset: Int, store: SnapshotStore = SnapshotStore()) throws {
        let log = buffer.editLog()
        let logSize = log.reduce(0) { $0 + $1.estimatedByteCount }
        let canUseDelta = path != nil
            && externalChange() == .unchanged
            && logSize * 2 < buffer.count

        let manifest = Snapshot(
            kind: canUseDelta ? .delta : .full,
            documentID: id,
            originalPath: path,
            savedAtEpoch: Date().timeIntervalSince1970,
            byteCount: canUseDelta ? logSize : buffer.count,
            caretOffset: caretOffset
        )

        if canUseDelta {
            let encoder = JSONEncoder()
            try store.write(Array(try encoder.encode(log)), manifest: manifest)
        } else {
            // Ghi theo từng đoạn: không bao giờ có cả tài liệu trong RAM cùng lúc.
            try store.write(manifest: manifest) { descriptor in
                var failure: Error?
                buffer.forEachChunk { chunk in
                    guard failure == nil, chunk.count > 0 else { return }
                    do { try Self.writeAll(descriptor, chunk) } catch { failure = error }
                }
                if let failure { throw failure }
            }
        }
    }

    private static func writeAll(_ descriptor: Int32, _ chunk: UnsafeRawBufferPointer) throws {
        var offset = 0
        while offset < chunk.count {
            let written = Darwin.write(descriptor, chunk.baseAddress!.advanced(by: offset), chunk.count - offset)
            if written < 0 {
                if errno == EINTR { continue }
                throw AtomicFileWriter.Failure.writeFailed(errno: errno)
            }
            offset += written
        }
    }

    /// Dựng lại tài liệu từ một bản nháp (NFR-REL-01, TC-DOC-01).
    ///
    /// Bản delta mở lại file gốc rồi PHÁT LẠI nhật ký, nên lịch sử undo được dựng lại y như
    /// lúc bị ngắt — người dùng lùi được về trước từng thao tác, không chỉ về bản đã lưu.
    public static func restore(
        _ snapshot: Snapshot, store: SnapshotStore = SnapshotStore()
    ) throws -> Document {
        let content = try store.content(for: snapshot.documentID)

        switch snapshot.kind {
        case .delta:
            guard let path = snapshot.originalPath else {
                throw Failure.noPathForSave
            }
            let document = try Document.open(path: path)
            let log = try JSONDecoder().decode([TextBuffer.EditRecord].self, from: Data(content))
            document.buffer.replay(log)
            return document

        case .full:
            let document: Document
            if let path = snapshot.originalPath, let onDisk = try? Document.open(path: path) {
                document = onDisk
            } else {
                document = .untitled()
            }
            document.buffer.applyEdits(
                [TextEdit(range: 0 ..< document.buffer.count, bytes: content)],
                label: "Khôi phục bản nháp"
            )
            return document
        }
    }

    public func discardSnapshot(store: SnapshotStore = SnapshotStore()) throws {
        try store.discard(documentID: id)
    }

    /// Tệp này vừa được ĐỔI TÊN hoặc CHUYỂN CHỖ trên đĩa — FR-DOC-314.
    ///
    /// Gọi SAU khi phép dời trên đĩa đã xong, không phải trước: dời hỏng giữa chừng mà đường
    /// dẫn đã đổi thì tab đang mở trỏ vào một tệp không tồn tại, và lần ⌘S sau đó ghi ra một
    /// tệp mới ở chỗ không ai chờ.
    ///
    /// **Bookmark cũ bị bỏ đi.** Nó trỏ vào inode cũ, và ở bản App Store thì quyền truy cập
    /// đi theo bookmark ấy: giữ lại là để một quyền chỉ đúng nửa vời. Bookmark mới được dựng ở
    /// lần lưu kế tiếp, khi quyền còn nằm trong tay.
    public func retarget(to newPath: String) {
        path = newPath
        accessBookmark = nil
    }
}
