import Foundation

/// Một CỬA SỔ nội dung: phần tài liệu mà lớp hiển thị đang thật sự giữ (ADR-01).
///
/// Quyết định ADR-01: `NSTextView` chỉ giữ ~2 MB quanh chỗ đang xem, còn tài liệu nằm trong
/// piece table trên mmap. Cửa sổ là chỗ hai thế giới gặp nhau, nên nó phải làm đúng ba việc:
///
/// 1. **Cắt theo BIÊN DÒNG.** Cắt giữa dòng thì dòng đầu và dòng cuối hiện ra cụt; cắt giữa
///    một ký tự nhiều byte thì hiện ra ký tự thay thế — với tiếng Việt là gặp ngay, không phải
///    trường hợp hiếm.
/// 2. **Đổi qua lại giữa offset BYTE của tài liệu và offset UTF-16 của view.** Đây là chỗ
///    ADR-01 §4 gọi tên là dễ sai nhất, và dự án này đã có vài lỗi đúng ở kiểu quy đổi ấy.
/// 3. **Không quét cả cửa sổ cho mỗi lần đổi.** Giữ mốc dòng theo cả hai đơn vị, tra bằng tìm
///    kiếm nhị phân rồi chỉ đi trong PHẠM VI MỘT DÒNG.
///
/// Giới hạn đã biết: với dòng dài bất thường (một file 2 MB không có ký tự xuống dòng nào),
/// bước đi trong dòng trở thành O(độ dài dòng). Sửa được bằng mốc phụ trong dòng; chưa làm vì
/// chưa đo thấy nó thành vấn đề, và đo trước khi tối ưu là quy tắc của dự án này.
public struct TextWindow: Equatable {

    /// Phạm vi byte của cửa sổ trong TÀI LIỆU.
    public let range: Range<Int>

    /// Nội dung cửa sổ — đây chính là chuỗi mà view giữ.
    public let text: String

    /// Offset byte (tuyệt đối) đầu mỗi dòng trong cửa sổ.
    private let byteLineStarts: [Int]
    /// Offset UTF-16 (tương đối với `text`) đầu mỗi dòng, cùng thứ tự.
    private let utf16LineStarts: [Int]

    /// Số dòng đầu tiên của cửa sổ trong tài liệu — để quy đổi số dòng khi cần.
    public let firstLine: Int

    /// Độ dài dòng DÀI NHẤT trong cửa sổ, tính bằng ô hiển thị (UTF-16), không kể "\n".
    ///
    /// Đếm ngay trong lượt quét dựng cửa sổ chứ không quét lại: lớp hiển thị cần số này ở MỌI
    /// lần nạp cửa sổ để đặt bề rộng khung chữ khi tắt ngắt dòng, và một lượt quét thêm trên
    /// 2 MB đo được khoảng 2 ms — đủ để thấy khi cuộn.
    public let longestLineUTF16Length: Int

    /// Những khoảng byte bị GẤP và chỗ con nháy đậu thay cho chúng.
    ///
    /// Cửa sổ có gấp thì `text` không còn liên tục với tài liệu: giữa hai dòng kề nhau trong
    /// `text` có thể là mấy trăm dòng đã giấu. Mọi mốc dòng vẫn đúng vì chúng ghi cả hai đơn vị,
    /// nhưng một offset rơi VÀO GIỮA phần bị giấu thì không có chỗ nào trong `text` để trỏ tới —
    /// và nếu cứ để phép quy đổi chạy tiếp, nó sẽ đi xuyên qua dòng kế và trả về một vị trí
    /// trông có vẻ hợp lý mà sai. Nên phải kẹp trước, ở đây.
    private let hidden: [(range: Range<Int>, caretHome: Int)]

    /// Bề rộng byte THẬT của những scalar mà mã hoá lại cho ra số byte KHÁC — khoá là offset
    /// UTF-16 của scalar ấy trong `text`. Rỗng với mọi tài liệu UTF-8 hợp lệ.
    ///
    /// **Vì sao cần.** Cả lớp này quy đổi byte ↔ UTF-16 bằng cách đi trên các scalar đã giải mã
    /// và cộng `UTF8.width(scalar)` — tức là MÃ HOÁ LẠI thứ vừa giải mã. Phép ấy chỉ đúng khi
    /// byte gốc hợp lệ. Một byte hỏng giải mã thành `U+FFFD`, mà `U+FFFD` mã hoá lại thành 3
    /// byte, nên mỗi byte hỏng làm offset trôi thêm 2 — và trôi TÍCH LUỸ cho tới cuối cửa sổ.
    ///
    /// Đây không phải trường hợp bịa: `Document.open` có đường nhanh cho UTF-8 dựng buffer
    /// thẳng trên vùng mmap, KHÔNG kiểm tính hợp lệ. Một file tải dở, một log trộn bảng mã, một
    /// file Latin-1 bị đoán nhầm — buffer đã có byte hỏng ngay khi mở.
    ///
    /// Hậu quả nặng hơn vẻ ngoài: sập là triệu chứng dễ thấy nhất (bộ chạy dài `--soak` bắt
    /// được ở `PieceTable.bytes(in:)`), nhưng cái đáng sợ là mốc dòng sau chỗ hỏng cũng lệch,
    /// nên một cú bấm chuột hay một lần gõ rơi vào ĐÚNG CHỖ KHÁC — sai trong im lặng.
    private let byteWidthCorrections: [Int: Int]

    /// Bề rộng byte thật của `scalar` đứng ở offset UTF-16 `utf16`.
    private func byteWidth(_ scalar: Unicode.Scalar, at utf16: Int) -> Int {
        byteWidthCorrections.isEmpty ? UTF8.width(scalar)
            : (byteWidthCorrections[utf16] ?? UTF8.width(scalar))
    }

    public var isEmpty: Bool { range.isEmpty }
    public var utf16Count: Int { text.utf16.count }
    public var hasFolds: Bool { !hidden.isEmpty }

    /// Các dòng (số dòng trong TÀI LIỆU) đang là dòng đầu của một vùng đã gấp.
    public let foldedHeaderLines: [Int]

    init(range: Range<Int>, text: String, firstLine: Int,
         byteLineStarts: [Int], utf16LineStarts: [Int], longestLineUTF16Length: Int = 0,
         hidden: [(range: Range<Int>, caretHome: Int)] = [],
         foldedHeaderLines: [Int] = [],
         byteWidthCorrections: [Int: Int] = [:]) {
        self.byteWidthCorrections = byteWidthCorrections
        self.range = range
        self.text = text
        self.firstLine = firstLine
        self.byteLineStarts = byteLineStarts
        self.utf16LineStarts = utf16LineStarts
        self.longestLineUTF16Length = longestLineUTF16Length
        self.hidden = hidden
        self.foldedHeaderLines = foldedHeaderLines
    }

    public static func == (a: TextWindow, b: TextWindow) -> Bool {
        a.range == b.range && a.text == b.text && a.firstLine == b.firstLine
            && a.foldedHeaderLines == b.foldedHeaderLines
    }

    /// Offset có nằm trong phần đã gấp không.
    public func isHidden(documentOffset offset: Int) -> Bool {
        hidden.contains { $0.range.contains(offset) }
    }

    public func contains(documentOffset offset: Int) -> Bool {
        offset >= range.lowerBound && offset <= range.upperBound
    }

    // MARK: - Quy đổi

    /// Offset byte trong tài liệu → offset UTF-16 trong `text`.
    ///
    /// Offset rơi vào GIỮA một ký tự nhiều byte được kẹp TIẾN tới biên ký tự kế tiếp — cùng
    /// quy ước đã dùng ở lớp trình bày. Với tiếng Việt thì offset giữa ký tự không phải chuyện
    /// hiếm ("ễ" là 3 byte), nên quy ước phải rõ ràng và một chiều: kẹp lùi ở chỗ này và kẹp
    /// tiến ở chỗ kia là cách chắc chắn để hai phép quy đổi lệch nhau một ký tự.
    ///
    /// Offset ngoài cửa sổ bị KẸP về biên gần nhất chứ không trả `nil`: lớp hiển thị hỏi vị trí
    /// của những thứ nằm ngoài tầm nhìn khá thường xuyên (kết quả tìm kiếm kế tiếp, dấu trang),
    /// và bắt mọi chỗ gọi xử lý `nil` sẽ đẻ ra hàng chục nhánh mà phần lớn sẽ xử lý cẩu thả.
    /// Chỗ nào cần biết "có nằm trong cửa sổ không" thì hỏi `contains(documentOffset:)`.
    /// Quy đổi MỘT LOẠT offset đã SẮP TĂNG DẦN, trong đúng một lượt đi qua chữ.
    ///
    /// # Vì sao cần cái này bên cạnh `utf16Offset(forDocumentOffset:)`
    ///
    /// Hàm đơn lẻ dựng lại vị trí từ ĐẦU DÒNG cho mỗi lần gọi. Với một dòng ngắn thì không sao.
    /// Với CSV nhiều cột thì nó thành bậc hai: tô màu một hàng 200 ô gọi 400 lần, mỗi lần đi
    /// trung bình nửa hàng — đo trên tệp 200 cột được **37,8 ms cho một lượt tô**, trong khi
    /// phần đặt thuộc tính vào `NSTextStorage` chỉ tốn 4,1 ms.
    ///
    /// Con số ấy lật ngược điều chú thích trong `WindowedTextView` vẫn khẳng định ("chi phí
    /// không nằm ở phân tích mà ở `addAttribute`"). Nó đúng ở thời điểm được viết, với dữ liệu
    /// được đo lúc đó; nó thôi đúng khi có người mở một CSV rộng.
    ///
    /// Ở đây con trỏ chỉ ĐI TỚI, nên cả loạt tốn đúng một lượt quét — O(bề dài vùng) thay vì
    /// O(số đoạn × bề dài dòng).
    ///
    /// - Parameter offsets: phải KHÔNG GIẢM. Gặp một offset lùi lại thì hàm tự quay về đường
    ///   đơn lẻ cho riêng nó, nên đầu vào sai thứ tự vẫn cho kết quả đúng, chỉ chậm.
    public func utf16Offsets(forSortedDocumentOffsets offsets: [Int]) -> [Int] {
        guard !offsets.isEmpty, !byteLineStarts.isEmpty else { return [] }

        var result: [Int] = []
        result.reserveCapacity(offsets.count)

        // Vị trí đang đứng, giữ đồng thời bằng ba đơn vị: byte tài liệu, offset UTF-16, và chỉ
        // số scalar trong `text`. Giữ cả ba là cách duy nhất để bước tiếp mà không phải dựng
        // lại cái nào.
        var byte = range.lowerBound
        var utf16 = 0
        var cursor = text.unicodeScalars.startIndex

        for offset in offsets {
            let clamped = Swift.min(Swift.max(offset, range.lowerBound), range.upperBound)

            // Vùng đã gấp phá thế đơn điệu (offset trong vùng ấy nhảy về `caretHome`), và một
            // offset lùi lại cũng vậy. Cả hai đều hiếm, nên xử lý bằng đường đơn lẻ thay vì
            // làm rối con trỏ — đúng ở mọi đầu vào quan trọng hơn nhanh ở đầu vào lạ.
            if clamped < byte || hidden.contains(where: { $0.range.contains(clamped) }) {
                result.append(utf16Offset(forDocumentOffset: clamped))
                continue
            }

            while byte < clamped, cursor < text.unicodeScalars.endIndex {
                let scalar = text.unicodeScalars[cursor]
                byte += byteWidth(scalar, at: utf16)
                utf16 += UTF16.width(scalar)
                cursor = text.unicodeScalars.index(after: cursor)
            }
            result.append(utf16)
        }
        return result
    }

    public func utf16Offset(forDocumentOffset offset: Int) -> Int {
        var clamped = Swift.min(Swift.max(offset, range.lowerBound), range.upperBound)
        // Rơi vào phần đã gấp thì về cuối dòng đầu của vùng ấy — chỗ gần nhất còn nhìn thấy.
        for fold in hidden where fold.range.contains(clamped) {
            clamped = fold.caretHome
            break
        }
        guard !byteLineStarts.isEmpty else { return 0 }

        let index = lineIndex(containingByteOffset: clamped)
        let lineByteStart = byteLineStarts[index]
        var utf16 = utf16LineStarts[index]

        // Đi trong PHẠM VI MỘT DÒNG. Đây là lý do phải giữ mốc dòng theo cả hai đơn vị.
        var byte = lineByteStart
        var cursor = utf16Index(at: utf16)
        while byte < clamped, cursor < text.endIndex {
            let scalar = text.unicodeScalars[cursor]
            byte += byteWidth(scalar, at: utf16)
            utf16 += UTF16.width(scalar)
            cursor = text.unicodeScalars.index(after: cursor)
        }
        return utf16
    }

    /// Offset UTF-16 trong `text` → offset byte trong tài liệu.
    public func documentOffset(forUTF16Offset offset: Int) -> Int {
        let clamped = Swift.min(Swift.max(offset, 0), utf16Count)
        guard !utf16LineStarts.isEmpty else { return range.lowerBound }

        let index = lineIndex(containingUTF16Offset: clamped)
        var byte = byteLineStarts[index]
        var utf16 = utf16LineStarts[index]

        var cursor = utf16Index(at: utf16)
        while utf16 < clamped, cursor < text.endIndex {
            let scalar = text.unicodeScalars[cursor]
            byte += byteWidth(scalar, at: utf16)
            utf16 += UTF16.width(scalar)
            cursor = text.unicodeScalars.index(after: cursor)
        }
        return byte
    }

    private func utf16Index(at offset: Int) -> String.UnicodeScalarView.Index {
        text.utf16.index(text.utf16.startIndex, offsetBy: offset).samePosition(in: text.unicodeScalars)
            ?? text.unicodeScalars.startIndex
    }

    private func lineIndex(containingByteOffset offset: Int) -> Int {
        var low = 0
        var high = byteLineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if byteLineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private func lineIndex(containingUTF16Offset offset: Int) -> Int {
        var low = 0
        var high = utf16LineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if utf16LineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }

    // MARK: - Ngắt dòng mềm (FR-CORE-015)

    /// Số dòng của riêng cửa sổ này.
    public var lineCount: Int { Swift.max(byteLineStarts.count, 1) }

    /// Độ dài dòng thứ `index` của cửa sổ, tính bằng đơn vị UTF-16, KHÔNG kể ký tự xuống dòng.
    ///
    /// Dùng UTF-16 chứ không dùng byte vì cái cần đếm là Ô HIỂN THỊ. "Nguyễn" là 9 byte nhưng
    /// chiếm 6 ô; đếm theo byte sẽ tưởng mọi dòng tiếng Việt dài gấp rưỡi và ước lượng thừa gần
    /// gấp đôi số hàng.
    public func utf16Length(ofLine index: Int) -> Int {
        guard index >= 0, index < byteLineStarts.count else { return 0 }
        let start = utf16LineStarts[index]
        let isLast = index == byteLineStarts.count - 1
        let end = isLast ? utf16Count : utf16LineStarts[index + 1] - 1   // trừ chính "\n"
        return Swift.max(0, end - start)
    }

    /// Số HÀNG màn hình trung bình cho mỗi DÒNG tài liệu, khi ngắt mềm ở `columnsPerRow` cột.
    ///
    /// Đây là chỗ lớp hiển thị lấy `rowsPerLine` cho `VerticalGeometry`. Đo trên cửa sổ rồi suy
    /// ra cả tài liệu — không có cách nào khác: dựng bố cục đầy đủ 2 MB bằng TextKit 2 đo được
    /// **437 ms**, còn cả lượt nạp lại cửa sổ chỉ tốn khoảng 5 ms — xem `defaultSize`.
    ///
    /// **Đây là số ƯỚC LƯỢNG THẤP, và nói rõ vì sao:** hàm này chia chẵn theo cột, còn ngắt
    /// dòng thật thì gãy ở BIÊN TỪ, nên một từ không vừa sẽ bị đẩy hẳn xuống hàng dưới và dòng
    /// thật chiếm nhiều hàng hơn con số này. Hệ quả nhìn thấy được: thanh cuộn hơi ngắn hơn
    /// thực tế trên tài liệu lớn. Không bù trừ bằng hệ số phỏng đoán — thà sai một chiều biết
    /// trước còn hơn sai hai chiều không giải thích được. Phần chữ KHÔNG bao giờ bị cắt mất vì
    /// khung chữ tự nới theo bố cục thật (xem `WindowedTextView.positionTextView`).
    public func rowsPerLine(columnsPerRow: Int) -> Double {
        guard columnsPerRow > 0, !text.isEmpty else { return 1 }

        var rows = 0
        for index in 0 ..< byteLineStarts.count {
            let length = utf16Length(ofLine: index)
            // Dòng rỗng vẫn chiếm MỘT hàng.
            rows += Swift.max(1, (length + columnsPerRow - 1) / columnsPerRow)
        }
        return Swift.max(1, Double(rows) / Double(byteLineStarts.count))
    }
}

public enum TextWindowing {

    /// Cỡ cửa sổ mặc định.
    ///
    /// 2 MB: đủ để cuộn vài chục màn hình mà không phải nạp lại, và nhỏ hơn trần bộ nhớ hai
    /// bậc ở mọi cỡ file. Xem bảng §3.2 của ADR-01.
    ///
    /// **Giá mỗi lần nạp: 5,17 ms** (trung vị 5 lượt, cửa sổ 2 MB chữ tiếng Việt) — nay có
    /// `geditor-bench core → textWindowBuild2MBMs` canh, nên nó không trôi được nữa.
    ///
    /// Con số "4,5 ms" từng nằm rải rác trong tệp này **không phải một ngân sách**, dù có chỗ
    /// đã gọi nó như vậy. Nó vào đây một lần với tư cách số ĐÃ ĐO rồi được nhắc lại thành
    /// "ngân sách" — một phép trôi chữ, không phải một quyết định. Số đo thật của ứng dụng
    /// trên file 100 MB là **5,4–8,8 ms** (ADR-01 §8bis), tức 5,17 ms ở đây là đúng hạng.
    public static let defaultSize = 2 << 20

    /// Dựng cửa sổ quanh `offset`, cắt theo biên dòng.
    public static func window(
        around offset: Int,
        in buffer: TextBuffer,
        size: Int = defaultSize,
        folds: [FoldRange] = []
    ) -> TextWindow {
        guard buffer.count > 0 else {
            return TextWindow(range: 0 ..< 0, text: "", firstLine: 0,
                              byteLineStarts: [0], utf16LineStarts: [0])
        }

        let half = size / 2
        let center = Swift.min(Swift.max(offset, 0), buffer.count - 1)

        // MỘT lần tra chỉ mục dòng cho mỗi biên, không dò ngược từng dòng: bản dò ngược trong
        // PoC làm "nhảy tới cuối file" mất 1,95 s trên 500 MB.
        let firstLine = buffer.lineNumber(atOffset: Swift.max(0, center - half))
        let start = buffer.offset(ofLineStart: firstLine)

        var end = Swift.min(buffer.count, start + size)
        if end < buffer.count {
            // Lùi về đầu dòng chứa `end` để không cắt cụt dòng cuối cửa sổ.
            let endLine = buffer.lineNumber(atOffset: end)
            let endLineStart = buffer.offset(ofLineStart: endLine)
            if endLineStart > start { end = endLineStart }
        }

        return makeWindow(range: start ..< end, firstLine: firstLine, in: buffer, folds: folds)
    }

    /// Dựng cửa sổ trên đúng một phạm vi byte cho trước (phạm vi phải nằm trên biên dòng).
    public static func window(
        range: Range<Int>, in buffer: TextBuffer, folds: [FoldRange] = []
    ) -> TextWindow {
        makeWindow(
            range: range, firstLine: buffer.lineNumber(atOffset: range.lowerBound),
            in: buffer, folds: folds
        )
    }

    /// Bề rộng byte THẬT của từng scalar, cho những chỗ khác với lúc mã hoá lại.
    ///
    /// Chỉ chạy khi đã biết chắc nguồn có byte hỏng. Dùng `UTF8.ForwardParser` — cùng luật
    /// "maximal subpart" mà `String(decoding:)` dùng để thay `U+FFFD`, nên số scalar hai bên
    /// khớp nhau theo đúng cấu tạo chứ không theo may rủi.
    ///
    /// Nếu vì lý do nào đó chúng KHÔNG khớp, hàm trả về những gì ghép được và dừng — thà thiếu
    /// một hiệu chỉnh (quay về hành vi cũ ở phần đuôi) còn hơn ghép lệch rồi trả về một bảng
    /// sai mà mọi chỗ khác tin tưởng.
    private static func byteWidthCorrections(text: String, bytes: [UInt8]) -> [Int: Int] {
        var widths: [Int] = []
        widths.reserveCapacity(bytes.count)
        var parser = UTF8.ForwardParser()
        var input = bytes.makeIterator()
        parse: while true {
            switch parser.parseScalar(from: &input) {
            case .valid(let sequence): widths.append(sequence.count)
            case .error(let length): widths.append(length)    // → đúng MỘT `U+FFFD`
            case .emptyInput: break parse
            }
        }

        var corrections: [Int: Int] = [:]
        var utf16 = 0
        var index = 0
        for scalar in text.unicodeScalars {
            guard index < widths.count else { break }
            if widths[index] != UTF8.width(scalar) { corrections[utf16] = widths[index] }
            utf16 += UTF16.width(scalar)
            index += 1
        }
        return corrections
    }

    private static func makeWindow(
        range: Range<Int>, firstLine: Int, in buffer: TextBuffer, folds: [FoldRange] = []
    ) -> TextWindow {
        // Chỉ giữ những vùng gấp CHẠM vào cửa sổ, và gộp vùng lồng nhau: gấp cả `a` lẫn `a.b`
        // thì phần giấu của `a.b` nằm gọn trong phần giấu của `a`, và bỏ hai lần cùng một dải
        // byte sẽ cắt lẹm sang chữ bên cạnh.
        var hidden: [(range: Range<Int>, caretHome: Int)] = []
        var headerLines: [Int] = []
        for fold in folds.sorted(by: { $0.hiddenBytes.lowerBound < $1.hiddenBytes.lowerBound })
        where fold.hiddenBytes.upperBound > range.lowerBound
            && fold.hiddenBytes.lowerBound < range.upperBound {
            if let last = hidden.last, fold.hiddenBytes.lowerBound < last.range.upperBound {
                if fold.hiddenBytes.upperBound > last.range.upperBound {
                    hidden[hidden.count - 1] = (
                        last.range.lowerBound ..< fold.hiddenBytes.upperBound, last.caretHome
                    )
                }
                continue
            }
            hidden.append((fold.hiddenBytes, fold.caretHome))
            headerLines.append(fold.headerLine)
        }

        let windowBytes: [UInt8]
        let text: String
        if hidden.isEmpty {
            windowBytes = buffer.bytes(in: range)
            text = String(decoding: windowBytes, as: UTF8.self)
        } else {
            var out: [UInt8] = []
            out.reserveCapacity(range.count)
            var cursor = range.lowerBound
            for fold in hidden {
                let stop = Swift.max(cursor, Swift.min(fold.range.lowerBound, range.upperBound))
                if cursor < stop { out.append(contentsOf: buffer.bytes(in: cursor ..< stop)) }
                cursor = Swift.max(cursor, Swift.min(fold.range.upperBound, range.upperBound))
            }
            if cursor < range.upperBound {
                out.append(contentsOf: buffer.bytes(in: cursor ..< range.upperBound))
            }
            windowBytes = out
            text = String(decoding: out, as: UTF8.self)
        }

        // ĐƯỜNG NHANH, và cách nhận ra nó chỉ tốn một phép so sánh.
        //
        // Mã hoá lại một chuỗi đã giải mã KHÔNG BAO GIỜ cho ra ít byte hơn nguồn; nó chỉ dài
        // hơn khi có byte hỏng bị thay bằng `U+FFFD`. Nên "số byte bằng nhau" ⟺ "nguồn hợp lệ",
        // và tài liệu hợp lệ — tức gần như mọi tài liệu — không phải trả một đồng nào cho
        // chuyện này.
        //
        // "Không một đồng nào" là số ĐO, không phải lời hứa: dựng cửa sổ 2 MB tiếng Việt mất
        // 4,75 ms khi bỏ hẳn dòng này và 4,79 ms khi có — chênh dưới 1%, nằm trong nhiễu. Rẻ
        // vì `String` của Swift lưu UTF-8 sẵn, nên `.utf8.count` là O(1) chứ không phải một
        // lượt quét. Cả lượt dựng cửa sổ chỉ tốn khoảng 5 ms (xem `TextWindowing.defaultSize`),
        // nên ở đây không có chỗ cho một lượt quét thừa — ai sửa thì đo lại bằng
        // `geditor-bench core → textWindowBuild2MBMs`.
        let corrections = text.utf8.count == windowBytes.count
            ? [:] : byteWidthCorrections(text: text, bytes: windowBytes)

        // Dựng mốc dòng theo CẢ HAI đơn vị trong một lượt quét duy nhất.
        var byteStarts = [range.lowerBound]
        var utf16Starts = [0]
        var byte = range.lowerBound
        var utf16 = 0
        var nextFold = 0

        /// Nhảy qua mọi vùng đã gấp mà `byte` vừa chạm tới.
        ///
        /// Gọi SAU mỗi ký tự xuống dòng, vì vùng gấp luôn bắt đầu ở đầu một dòng. Không nhảy
        /// thì mốc byte của những dòng sau vùng gấp sẽ lệch đúng bằng kích thước phần đã giấu,
        /// và mọi cú nhấp chuột dưới chỗ gấp đều rơi sai chỗ.
        func skipFolds() {
            while nextFold < hidden.count, hidden[nextFold].range.lowerBound <= byte {
                if hidden[nextFold].range.upperBound > byte { byte = hidden[nextFold].range.upperBound }
                nextFold += 1
            }
        }
        skipFolds()
        // Dòng dài nhất đếm luôn ở đây. Lớp hiển thị cần nó ở mọi lần nạp cửa sổ (bề rộng khung
        // chữ khi tắt ngắt dòng), và quét lại 2 MB lần nữa tốn khoảng 2 ms.
        var longest = 0
        var lineStartUTF16 = 0
        for scalar in text.unicodeScalars {
            // Bề rộng THẬT, không phải bề rộng lúc mã hoá lại — xem `byteWidthCorrections`.
            // Quên chỗ này thì mọi mốc dòng sau một byte hỏng đều lệch, và cú bấm chuột dưới
            // chỗ ấy rơi sai dòng.
            byte += corrections.isEmpty ? UTF8.width(scalar) : (corrections[utf16] ?? UTF8.width(scalar))
            utf16 += UTF16.width(scalar)
            if scalar == "\n" {
                skipFolds()
                byteStarts.append(byte)
                utf16Starts.append(utf16)
                longest = Swift.max(longest, utf16 - 1 - lineStartUTF16)   // trừ chính "\n"
                lineStartUTF16 = utf16
            }
        }
        longest = Swift.max(longest, utf16 - lineStartUTF16)               // dòng cuối, nếu không có "\n"

        return TextWindow(
            range: range, text: text, firstLine: firstLine,
            byteLineStarts: byteStarts, utf16LineStarts: utf16Starts,
            longestLineUTF16Length: longest,
            hidden: hidden, foldedHeaderLines: headerLines,
            byteWidthCorrections: corrections
        )
    }
}
