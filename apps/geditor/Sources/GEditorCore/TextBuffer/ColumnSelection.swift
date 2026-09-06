import Foundation

/// Chọn theo KHỐI CHỮ NHẬT (FR-CORE-002).
///
/// Khối chữ nhật quy về đúng một `MultiSelection`: mỗi dòng trong khối là một vùng chọn. Nhờ
/// vậy gõ, xóa và undo dùng lại nguyên máy móc của FR-CORE-001 — không có đường thứ hai vào
/// cùng một tài liệu, và cũng không có bất biến thứ hai phải giữ.
///
/// **Cột đếm theo THỊ GIÁC, không theo ký tự và cũng không theo byte.**
///
/// - Không theo byte: "Nguyễn" là 6 ký tự nhưng 9 byte; người dùng kéo chuột theo cái họ nhìn.
/// - Không theo ký tự: một TAB chiếm MỘT ký tự nhưng trải tới nấc tab kế tiếp trên màn hình.
///
/// Đếm theo ký tự là khoản nợ đã ghi ra từ đầu ở đây, và nó không nhỏ: mã nguồn thụt bằng TAB
/// là chuyện thường, nên với đúng loại file mà người ta hay chọn cột nhất thì khối lệch hẳn so
/// với thứ họ nhìn thấy. Luật nấc tab đã có sẵn ở `SmartIndent.width(of:tabWidth:)` và
/// FR-CORE-011 dùng nó từ lâu — chỗ này chỉ là dùng cùng một luật.
///
/// **Cột đích rơi vào GIỮA một TAB thì về biên GẦN HƠN, hoà thì về bên trái.** Con nháy chỉ
/// đứng được ở biên ký tự, nên phải làm tròn; làm tròn về biên gần nhất là đúng thứ xảy ra khi
/// bấm chuột vào giữa một TAB ở bất kỳ chỗ nào khác trong app.
public enum ColumnSelection {

    /// Tab width mặc định, khớp `Settings.tabWidth`.
    ///
    /// Có mặc định để lõi tự dùng được và để bài kiểm không phải nhắc lại con số ở mọi dòng —
    /// nhưng app LUÔN truyền giá trị thật của người dùng vào.
    public static let defaultTabWidth = 4

    /// Dựng khối chữ nhật giữa hai điểm (dòng, cột thị giác).
    ///
    /// Hai điểm theo thứ tự nào cũng được: kéo chuột lên trên hay xuống dưới, sang trái hay
    /// sang phải, đều ra cùng một khối.
    public static func selection(
        in buffer: TextBuffer,
        from start: (line: Int, column: Int),
        to end: (line: Int, column: Int),
        tabWidth: Int = defaultTabWidth
    ) -> MultiSelection {
        let firstLine = Swift.min(start.line, end.line)
        let lastLine = Swift.max(start.line, end.line)
        let leftColumn = Swift.min(start.column, end.column)
        let rightColumn = Swift.max(start.column, end.column)

        guard buffer.lineCount > 0 else { return MultiSelection(caretAt: 0) }
        let lower = Swift.max(0, firstLine)
        let upper = Swift.min(buffer.lineCount - 1, lastLine)
        guard lower <= upper else { return MultiSelection(caretAt: 0) }

        var ranges: [Range<Int>] = []
        for line in lower ... upper {
            let content = buffer.contentRange(ofLine: line)
            let from = offset(inLine: content, column: leftColumn, in: buffer, tabWidth: tabWidth)
            let to = offset(inLine: content, column: rightColumn, in: buffer, tabWidth: tabWidth)
            ranges.append(from ..< Swift.max(from, to))
        }

        // Vùng CHÍNH là dòng cuối người dùng kéo tới — màn hình phải theo con trỏ chuột.
        let primary = end.line >= start.line ? ranges.count - 1 : 0
        return MultiSelection(ranges, primaryIndex: primary)
    }

    /// Offset byte của cột THỊ GIÁC thứ `column` trong một dòng.
    ///
    /// Dòng ngắn hơn cột thì kẹp vào CUỐI DÒNG chứ không tràn sang dòng sau: khối chữ nhật kéo
    /// qua một dòng ngắn phải chừa dòng ấy ra, không được nuốt ký tự xuống dòng.
    static func offset(
        inLine content: Range<Int>, column target: Int, in buffer: TextBuffer, tabWidth: Int
    ) -> Int {
        guard target > 0 else { return content.lowerBound }
        var reader = LineReader(content, buffer)
        var offset = content.lowerBound
        var visual = 0

        while offset < content.upperBound, visual < target {
            let next = reader.nextBoundary(after: offset)
            let width = advance(
                isTab: reader.isTab(at: offset, characterEndsAt: next),
                at: visual, tabWidth: tabWidth)
            if visual + width > target {
                // Cột đích rơi vào GIỮA ký tự này — chỉ xảy ra với TAB. Về biên gần hơn; hoà
                // thì về bên trái, để hai lần kéo giống nhau cho ra cùng một khối.
                return (target - visual) <= (visual + width - target) ? offset : next
            }
            visual += width
            offset = next
        }
        return Swift.min(offset, content.upperBound)
    }

    /// Cột THỊ GIÁC của một offset byte trong dòng chứa nó.
    public static func column(
        ofOffset offset: Int, in buffer: TextBuffer, tabWidth: Int = defaultTabWidth
    ) -> Int {
        let line = Swift.min(buffer.lineNumber(atOffset: offset), Swift.max(buffer.lineCount - 1, 0))
        let content = buffer.contentRange(ofLine: line)
        var reader = LineReader(content, buffer)
        var cursor = content.lowerBound
        var column = 0
        while cursor < offset, cursor < content.upperBound {
            let next = reader.nextBoundary(after: cursor)
            column += advance(
                isTab: reader.isTab(at: cursor, characterEndsAt: next),
                at: column, tabWidth: tabWidth)
            cursor = next
        }
        return column
    }

    /// Bề rộng thị giác của một ký tự đứng ở cột `visual`. Cùng luật nấc tab với `SmartIndent`.
    @inline(__always)
    static func advance(isTab: Bool, at visual: Int, tabWidth: Int) -> Int {
        guard isTab else { return 1 }
        let step = Swift.max(1, tabWidth)
        return step - (visual % step)
    }

    /// Đọc byte của một dòng theo LÔ.
    ///
    /// **Cả biên ký tự lẫn phép hỏi "có phải TAB không" đều đi qua đây, và đó là cả điểm.**
    /// `TextBuffer.nextCharacterBoundary(after:)` gọi `bytes(in: i ..< i+1)` cho MỖI BYTE, tức
    /// một lần cấp phát mảng cho mỗi byte. Đo được: đi tới cuối một dòng 1 triệu ký tự mất
    /// **569 ms**. Cùng phép đi ấy đọc theo lô 64 KB mất vài ms.
    ///
    /// Kết quả KHÔNG đổi: `nextCharacterBoundary` chỉ bỏ qua byte nối UTF-8 (`0b10xxxxxx`),
    /// và vòng lặp ở đây làm đúng thế. "Ký tự" trong cả tệp này nghĩa là biên UTF-8, không
    /// phải cụm hiển thị.
    ///
    /// Lô cũng KHÔNG đọc cả dòng: cả dòng vào bộ nhớ thì lại đúng chỗ ADR-02 tránh.
    private struct LineReader {
        private let content: Range<Int>
        private let buffer: TextBuffer
        private var chunk: [UInt8] = []
        private var chunkStart = 0

        static let chunkBytes = 64 * 1024

        init(_ content: Range<Int>, _ buffer: TextBuffer) {
            self.content = content
            self.buffer = buffer
            chunkStart = content.lowerBound
        }

        /// Byte tại `offset`, nạp lô khi ra ngoài lô đang giữ.
        private mutating func byte(at offset: Int) -> UInt8 {
            if offset < chunkStart || offset >= chunkStart + chunk.count {
                chunkStart = offset
                let end = Swift.min(offset + Self.chunkBytes, content.upperBound)
                chunk = buffer.bytes(in: offset ..< end)
            }
            let index = offset - chunkStart
            return index >= 0 && index < chunk.count ? chunk[index] : 0
        }

        /// Biên ký tự kế tiếp — cùng luật với `TextBuffer.nextCharacterBoundary`, đọc theo lô.
        mutating func nextBoundary(after offset: Int) -> Int {
            var index = offset + 1
            while index < content.upperBound, byte(at: index) & 0xC0 == 0x80 { index += 1 }
            return Swift.min(index, content.upperBound)
        }

        /// TAB là MỘT byte `0x09`, nên ký tự dài hơn một byte thì chắc chắn không phải TAB —
        /// hỏi trước, khỏi phải đọc byte nào.
        mutating func isTab(at offset: Int, characterEndsAt next: Int) -> Bool {
            guard next - offset == 1 else { return false }
            return byte(at: offset) == 0x09
        }
    }
}

public extension MultiSelection {

    /// Dán một khối nhiều dòng: dòng thứ i của khối vào caret thứ i (FR-CORE-002).
    ///
    /// Số dòng của khối và số caret thường không bằng nhau, và hai trường hợp ấy có ý nghĩa
    /// khác hẳn nhau:
    ///
    /// - **Bằng nhau** — dán theo cặp, đây là trường hợp chép một khối rồi dán sang chỗ khác.
    /// - **Một caret, khối nhiều dòng** — dán cả khối vào đúng chỗ đó, GIỮ HÌNH CHỮ NHẬT như
    ///   SRS đòi: mỗi dòng của khối rơi xuống dòng kế tiếp, cùng một cột.
    /// - **Còn lại** — dán nguyên cả khối vào mọi caret. Đoán khôn hơn thế sẽ sai theo những
    ///   cách người dùng không lường được.
    func edits(
        pastingBlock lines: [String], in buffer: TextBuffer,
        tabWidth: Int = ColumnSelection.defaultTabWidth
    ) -> [TextEdit] {
        guard !lines.isEmpty else { return [] }

        if lines.count == ranges.count {
            return zip(ranges, lines).map { TextEdit(range: $0, text: $1) }
        }

        // `anchor.isEmpty` là điều kiện BẮT BUỘC, không phải chi tiết.
        //
        // Nhánh này giữ hình chữ nhật bằng cách chèn dòng thứ i vào DÒNG thứ i tính từ chỗ dán.
        // Nếu vùng chọn không rỗng — người dùng bôi đen rồi dán — thì phép thay thế ấy phủ lên
        // chính những dòng mà các phép chèn sau nhắm tới, và `applyEdits` gặp hai vùng sửa GIAO
        // NHAU. Bất biến ấy có `precondition`, nên nó không sinh ra kết quả lạ mà làm app SẬP.
        //
        // Chọn tất rồi dán một khối cột là chuỗi thao tác người dùng làm thật. Bộ chạy dài
        // `--soak` tìm ra nó ở bước 418 (NFR-REL-03).
        //
        // Vùng chọn không rỗng thì rơi xuống nhánh cuối: THAY vùng ấy bằng cả khối. Đó cũng là
        // thứ người dùng mong — họ bôi đen để thay, không phải để chèn thêm.
        if ranges.count == 1, lines.count > 1, ranges[0].isEmpty {
            let anchor = ranges[0]
            // Cột THỊ GIÁC, cùng luật với lúc chọn khối. Đo bằng ký tự ở đây thì khối dán vào
            // một vùng thụt bằng TAB sẽ lệch so với khối đã chép ra.
            let column = ColumnSelection.column(
                ofOffset: anchor.lowerBound, in: buffer, tabWidth: tabWidth)
            let firstLine = buffer.lineNumber(atOffset: anchor.lowerBound)
            var edits: [TextEdit] = [TextEdit(range: anchor, text: lines[0])]

            for (index, text) in lines.dropFirst().enumerated() {
                let line = firstLine + index + 1
                guard line < buffer.lineCount else { break }
                let content = buffer.contentRange(ofLine: line)
                let offset = ColumnSelection.offset(
                    inLine: content, column: column, in: buffer, tabWidth: tabWidth)
                // Dòng ngắn hơn cột thì chèn ở cuối dòng — không đệm khoảng trắng, vì đệm là
                // sửa nội dung người dùng không yêu cầu.
                edits.append(TextEdit(range: offset ..< offset, text: text))
            }
            return edits
        }

        let whole = lines.joined(separator: "\n")
        return ranges.map { TextEdit(range: $0, text: whole) }
    }

    /// Nội dung của mọi vùng chọn, mỗi vùng một dòng — dùng khi CHÉP một khối cột.
    func blockText(in buffer: TextBuffer) -> String {
        ranges.map { String(decoding: buffer.bytes(in: $0), as: UTF8.self) }.joined(separator: "\n")
    }
}
