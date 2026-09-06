import Foundation
import LibArchive

/// Đọc `.7z`, `.rar`, `.cab`, `.lha`, `.iso`, `.xar`, `.cpio`, `.ar` bằng **libarchive nạp từ
/// nguồn** (`scripts/vendor-libarchive.sh`).
///
/// # Chỗ này thay cho cái gì
///
/// Bản trước gọi `/usr/bin/tar` như một tiến trình con. Nó chạy được, nhưng chỉ ở bản tải trực
/// tiếp: bản App Store nằm trong sandbox, và một ứng dụng sinh tiến trình con để đọc file nén
/// là thứ người duyệt sẽ hỏi. Kết quả là bản App Store hiện một câu từ chối ở đúng chỗ người
/// dùng vừa bấm mở tệp.
///
/// Liên kết tĩnh thư viện vào bundle thì hai bản có CÙNG một danh sách định dạng, và không bản
/// nào cần sinh tiến trình. `Distribution.current` không còn xuất hiện ở đường này nữa.
///
/// # Vì sao KHÔNG dùng libarchive của macOS
///
/// SDK **có** `libarchive.tbd` — tức link được. Nhưng SDK **không có `archive.h`**. Không
/// header nghĩa là không có hợp đồng API: muốn gọi thì phải tự khai nguyên mẫu hàm, tức tự
/// đoán một ABI Apple chưa từng hứa sẽ giữ. Đó cũng đúng là lý do `PCRE2` không dùng
/// `/usr/lib/libpcre2-8.dylib`.
///
/// # Vì sao bật từng định dạng thay vì gọi `archive_read_support_format_all`
///
/// `..._all()` bật cả bộ lọc `program`, thứ **sinh tiến trình con** gọi `gzip -d`, `unlzma`…
/// Nó chính là thứ cả lượt vendor này sinh ra để bỏ đi. Danh sách dưới đây là danh sách đọc
/// được: mỗi dòng một định dạng ta có chủ ý mở, không phải "tất cả trừ những thứ tình cờ không
/// link được". Nguồn của các bộ lọc ấy còn không được chép vào repo.
public enum LibArchiveReader {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        /// `nil` = thư viện không đưa ra câu nào. Chuyện ấy CÓ xảy ra: một tệp mang đúng chữ ký
        /// `.7z` nhưng ruột là rác làm `archive_read_next_header` trả ARCHIVE_FATAL với
        /// `archive_error_string()` rỗng. Lúc ấy phải tự viết một câu nói được điều gì đó, chứ
        /// không phải in ra "không rõ lý do" — câu ấy chiếm chỗ của một lời giải thích mà không
        /// giải thích gì.
        case cannotOpen(String?)
        case cannotRead(String?)
        case encrypted
        case entryNotFound(String)
        case tooLarge(Int)

        public var description: String {
            switch self {
            case .cannotOpen(let detail):
                guard let detail else {
                    return "Không mở được kho nén: tệp này không thuộc định dạng nào GEditor"
                        + " đọc được, hoặc đã hỏng — chẳng hạn tải về dở dang."
                }
                return "Không mở được kho nén: \(detail)"
            case .cannotRead(let detail):
                guard let detail else {
                    return "Không đọc được nội dung mục này — phần dữ liệu của nó trong kho đã"
                        + " hỏng."
                }
                return "Không đọc được nội dung: \(detail)"
            case .encrypted:
                return "Kho nén này có mật khẩu. GEditor chưa mở được kho đặt mật khẩu."
            case .entryNotFound(let path):
                return "Không còn thấy mục «\(path)» trong kho — tệp có thể đã đổi."
            case .tooLarge(let limit):
                return "Mục này giải nén ra lớn hơn \(limit / 1_048_576) MB nên đã dừng."
                    + " Kho nén có thể được dựng để làm cạn bộ nhớ."
            }
        }
    }

    public struct Entry: Equatable, Sendable {
        public var path: String
        public var size: Int
        public var isDirectory: Bool
        public var modified: Date?
        public var isEncrypted: Bool
    }

    /// Trần cho MỘT mục giải nén ra.
    ///
    /// Cùng con số và cùng lý do với `ZipArchive.extractionLimit`: một kho vài chục KB có thể
    /// khai một mục vài chục GB, và bên đọc không có cách nào biết trước ngoài việc đếm khi
    /// đang giải. Con số ở `ZipArchive` là nguồn duy nhất — chép lại ở đây sẽ có ngày hai chỗ
    /// lệch nhau.
    public static var extractionLimit: Int { ZipArchive.extractionLimit }

    /// Cỡ khối đọc từ đĩa. 64 KB là con số libarchive khuyến nghị cho tệp trên đĩa.
    private static let blockSize = 65536

    // MARK: - Liệt kê

    public static func list(path: String) throws -> [Entry] {
        let handle = try open(path)
        defer { archive_read_free(handle) }

        var result: [Entry] = []
        while true {
            var raw: OpaquePointer?
            let status = archive_read_next_header(handle, &raw)
            if status == ARCHIVE_EOF { break }
            // ARCHIVE_WARN vẫn cho đọc tiếp — nó là "mục này có chỗ lạ", không phải "hỏng".
            guard status == ARCHIVE_OK || status == ARCHIVE_WARN, let entry = raw else {
                throw Failure.cannotOpen(errorText(handle))
            }
            result.append(describe(entry))
        }
        return result
    }

    // MARK: - Lấy nội dung một mục

    /// Đọc nội dung một mục.
    ///
    /// libarchive là API **tuần tự**: không có phép nhảy tới mục thứ n. Nên hàm này mở lại kho
    /// và duyệt từ đầu cho tới khi gặp đúng đường dẫn cần.
    ///
    /// Với kho `.7z` dạng khối đặc (solid), duyệt tới mục thứ n còn phải giải nén cả n−1 mục
    /// trước nó. Vậy nên **đừng gọi hàm này trong một vòng lặp** để bung cả kho — dùng
    /// `readAll(path:handler:)`, nó chỉ duyệt một lượt.
    public static func data(archive path: String, entry wanted: Entry) throws -> [UInt8] {
        let handle = try open(path)
        defer { archive_read_free(handle) }

        while true {
            var raw: OpaquePointer?
            let status = archive_read_next_header(handle, &raw)
            if status == ARCHIVE_EOF { break }
            guard status == ARCHIVE_OK || status == ARCHIVE_WARN, let entry = raw else {
                throw Failure.cannotRead(errorText(handle))
            }
            guard pathname(entry) == wanted.path else { continue }
            if archive_entry_is_encrypted(entry) != 0 { throw Failure.encrypted }
            return try readCurrent(handle)
        }
        throw Failure.entryNotFound(wanted.path)
    }

    /// Duyệt MỘT lượt qua cả kho, trao từng mục kèm nội dung.
    ///
    /// Đây là đường dùng cho "bung tất cả". `data(archive:entry:)` gọi trong vòng lặp sẽ là
    /// O(n²) trên kho thường và tệ hơn hẳn trên `.7z` khối đặc, nơi mỗi lần duyệt lại phải
    /// giải nén lại mọi mục đứng trước.
    ///
    /// `handler` ném lỗi thì cả lượt duyệt dừng — để nút Huỷ dừng được thật, chứ không phải
    /// dừng sau khi đã bung xong.
    public static func readAll(
        path: String, handler: (Entry, [UInt8]) throws -> Void
    ) throws {
        let handle = try open(path)
        defer { archive_read_free(handle) }

        while true {
            var raw: OpaquePointer?
            let status = archive_read_next_header(handle, &raw)
            if status == ARCHIVE_EOF { break }
            guard status == ARCHIVE_OK || status == ARCHIVE_WARN, let entry = raw else {
                throw Failure.cannotRead(errorText(handle))
            }
            let described = describe(entry)
            guard !described.isDirectory else { continue }
            if described.isEncrypted { throw Failure.encrypted }
            try handler(described, try readCurrent(handle))
        }
    }

    // MARK: - Mở kho

    /// Đặt `LC_CTYPE` về UTF-8 đúng một lần cho cả tiến trình.
    ///
    /// KHÔNG BỎ ĐƯỢC, và đây là chỗ đã tốn một lượt gỡ. libarchive chuyển tên tệp sang bảng mã
    /// của locale hiện hành. Ứng dụng Cocoa không gọi `setlocale`, nên locale là "C" — tức
    /// ASCII — và mọi tên có dấu đều KHÔNG chuyển được. Khi ấy `archive_entry_pathname()`,
    /// `..._utf8()` và `..._w()` **cả ba đều trả NULL**, và mục hiện ra với tên rỗng.
    ///
    /// Nó không phải chuyện chỉ xảy ra trong bài kiểm: `bsdtar` in tên đúng chính vì nó gọi
    /// `setlocale(LC_ALL, "")` lúc khởi động, còn GEditor thì không.
    ///
    /// Chỉ đụng `LC_CTYPE`, không đụng `LC_ALL`: `LC_NUMERIC` mà đổi thì dấu thập phân đổi
    /// theo, và mọi chỗ đọc số trong CSV sẽ lệch. `LC_CTYPE` = UTF-8 thì đúng với thứ Swift và
    /// Foundation vẫn giả định sẵn.
    ///
    /// `static let` để Swift lo phần chạy đúng một lần: `setlocale` sửa trạng thái toàn tiến
    /// trình, gọi lại nhiều lần từ nhiều luồng là một cuộc đua.
    private static let localeReady: Bool = {
        setlocale(LC_CTYPE, "UTF-8") != nil
    }()

    /// Mở kho và bật đúng những bộ lọc và định dạng GEditor có chủ ý hỗ trợ.
    private static func open(_ path: String) throws -> OpaquePointer {
        _ = localeReady

        guard let handle = archive_read_new() else {
            throw Failure.cannotOpen("không cấp phát được bộ đọc")
        }

        // Bộ lọc — tầng giải nén ngoài. Không cái nào gọi chương trình ngoài.
        archive_read_support_filter_none(handle)
        archive_read_support_filter_gzip(handle)
        archive_read_support_filter_bzip2(handle)
        archive_read_support_filter_xz(handle)
        // `.Z` của Unix cũ. Bộ giải nén nằm gọn trong libarchive, không thêm phụ thuộc nào.
        archive_read_support_filter_compress(handle)

        // Định dạng — tầng mục lục bên trong.
        archive_read_support_format_7zip(handle)
        archive_read_support_format_rar(handle)      // RAR 4 trở về trước
        archive_read_support_format_rar5(handle)     // RAR 5
        archive_read_support_format_zip(handle)
        archive_read_support_format_tar(handle)
        archive_read_support_format_cab(handle)
        archive_read_support_format_lha(handle)      // .lha và .lzh
        archive_read_support_format_iso9660(handle)
        archive_read_support_format_xar(handle)
        archive_read_support_format_cpio(handle)
        archive_read_support_format_ar(handle)
        // Kho rỗng hợp lệ. Không có nó thì một tệp 0 byte báo "không nhận ra định dạng",
        // trong khi sự thật là kho không có mục nào.
        archive_read_support_format_empty(handle)

        // `..._format_raw` CỐ Ý không bật: nó nhận BẤT KỲ chuỗi byte nào là một kho có đúng
        // một mục. Bật lên thì một tệp hỏng sẽ mở ra thành "kho hợp lệ" thay vì báo lỗi, và
        // `MediaKind` sẽ mất đường phân biệt. Nguồn của nó còn không được chép vào repo.

        guard archive_read_open_filename(handle, path, blockSize) == ARCHIVE_OK else {
            let detail = errorText(handle)
            archive_read_free(handle)
            throw Failure.cannotOpen(detail)
        }
        return handle
    }

    // MARK: - Đọc một mục đang mở

    private static func readCurrent(_ handle: OpaquePointer) throws -> [UInt8] {
        var result: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: blockSize)
        while true {
            let read = buffer.withUnsafeMutableBytes {
                archive_read_data(handle, $0.baseAddress, blockSize)
            }
            if read == 0 { break }
            guard read > 0 else { throw Failure.cannotRead(errorText(handle)) }
            // Đếm TRONG LÚC giải nén, không tin cỡ mà kho tự khai. Một kho dựng để làm cạn bộ
            // nhớ sẽ khai cỡ nhỏ rồi tuôn ra dữ liệu không dứt — chặn theo cỡ khai báo là
            // chặn đúng thứ kẻ tấn công điền vào.
            guard result.count + read <= extractionLimit else {
                throw Failure.tooLarge(extractionLimit)
            }
            result.append(contentsOf: buffer[0 ..< read])
        }
        return result
    }

    // MARK: - Đọc thuộc tính của một mục

    static func describe(_ entry: OpaquePointer) -> Entry {
        let path = pathname(entry)
        // `archive_entry_size_is_set` phải hỏi trước: vài định dạng không ghi cỡ, và khi ấy
        // `archive_entry_size` trả 0 — không phân biệt được với một tệp rỗng thật.
        let size = archive_entry_size_is_set(entry) != 0 ? Int(archive_entry_size(entry)) : 0
        let modified: Date? = archive_entry_mtime_is_set(entry) != 0
            ? Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(entry)))
            : nil
        // Cờ thư mục lấy từ kiểu tệp; đuôi `/` là nhánh lùi cho định dạng không ghi kiểu.
        let isDirectory = archive_entry_filetype(entry) == GEDITOR_AE_IFDIR || path.hasSuffix("/")
        return Entry(path: path, size: size, isDirectory: isDirectory,
                     modified: modified,
                     isEncrypted: archive_entry_is_encrypted(entry) != 0)
    }

    /// Đường dẫn của một mục, ưu tiên bản UTF-8.
    ///
    /// `archive_entry_pathname` trả về byte theo locale hiện hành, và tên tiếng Việt trong một
    /// kho tạo trên Windows sẽ ra ký tự rác. Bản `_utf8` trả `NULL` khi không chuyển được, lúc
    /// ấy mới lùi về bản thô.
    static func pathname(_ entry: OpaquePointer) -> String {
        if let utf8 = archive_entry_pathname_utf8(entry) { return String(cString: utf8) }
        if let raw = archive_entry_pathname(entry) { return String(cString: raw) }
        return ""
    }

    /// Câu giải thích của libarchive, hoặc `nil` khi nó im lặng.
    ///
    /// Trả `nil` chứ không trả một chuỗi thay thế: chỗ biết nên nói gì khi thư viện im lặng là
    /// `Failure.description`, nơi đã biết đang hỏng ở bước mở hay bước đọc.
    private static func errorText(_ handle: OpaquePointer) -> String? {
        guard let message = archive_error_string(handle) else { return nil }
        let text = String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
