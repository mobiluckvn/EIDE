import Foundation

/// Đánh dấu dòng và lọc theo dấu (FR-SRCH-107).
///
/// Đây là phần LÕI: tập dòng được đánh dấu, và các phép sinh `TextEdit` từ nó. Phần hiển thị —
/// tô nền dòng, chấm bookmark ở lề, chín màu độc lập — thuộc lớp trình bày và chờ engine do
/// ADR-01 chốt. Mô hình ở đây đã sẵn sàng cho chín màu: mỗi màu là một `LineMarkSet` riêng.
///
/// Vì sao dấu là tập SỐ DÒNG chứ không phải tập offset byte: người dùng nghĩ theo dòng ("xóa
/// mọi dòng có chữ ERROR"), và mọi phép lọc đều làm việc trên dòng. Giữ theo offset sẽ phải
/// quy đổi ở mọi thao tác, mà quy đổi là chỗ đã sinh ra vài lỗi trong dự án này.
public struct LineMarkSet: Equatable {

    public private(set) var lines: Set<Int>

    public init(_ lines: Set<Int> = []) { self.lines = lines }

    public var isEmpty: Bool { lines.isEmpty }
    public var count: Int { lines.count }
    public func contains(_ line: Int) -> Bool { lines.contains(line) }

    public mutating func toggle(_ line: Int) {
        if lines.contains(line) { lines.remove(line) } else { lines.insert(line) }
    }

    public mutating func clear() { lines.removeAll() }

    /// Đảo dấu trên toàn tài liệu.
    public mutating func invert(lineCount: Int) {
        lines = Set(0 ..< lineCount).subtracting(lines)
    }

    /// Số dòng đã đánh dấu, theo thứ tự tăng dần.
    public var sorted: [Int] { lines.sorted() }
}

public enum LineMarks {

    // MARK: - Đánh dấu theo pattern

    /// Đánh dấu mọi dòng chứa ít nhất một kết quả khớp (Mark All).
    ///
    /// Một dòng có mười kết quả vẫn chỉ là MỘT dấu: dấu thuộc về dòng, không thuộc về kết quả.
    public static func marking(
        pattern: String,
        in buffer: TextBuffer,
        engine: SearchEngine,
        options: SearchOptions = SearchOptions(),
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> LineMarkSet {
        let content = buffer.bytes(in: 0 ..< buffer.count)
        let matches = try engine.find(
            pattern: pattern, in: content, options: options, limit: limit, cancelToken: cancelToken
        )
        return marking(matchOffsets: matches.map(\.range.lowerBound), in: buffer)
    }

    /// Đánh dấu các dòng chứa những offset cho trước.
    ///
    /// Tách riêng để dùng lại được với kết quả tìm kiếm đã có sẵn — panel kết quả không nên
    /// phải chạy lại phép tìm chỉ để đánh dấu.
    public static func marking(matchOffsets: [Int], in buffer: TextBuffer) -> LineMarkSet {
        guard buffer.lineCount > 0 else { return LineMarkSet() }
        let lastLine = buffer.lineCount - 1
        var marked = Set<Int>()
        // Offset ở cuối tài liệu có thể cho ra "dòng ảo" (xem `PieceTable.offset(ofLineStart:)`);
        // kẹp về dòng thật, vì dòng ảo không có nội dung để đánh dấu.
        for offset in matchOffsets {
            marked.insert(Swift.min(buffer.lineNumber(atOffset: offset), lastLine))
        }
        return LineMarkSet(marked)
    }

    // MARK: - Thao tác trên dòng đã đánh dấu

    /// Xóa các dòng được đánh dấu.
    public static func deleteEdits(marked: LineMarkSet, in buffer: TextBuffer) -> [TextEdit] {
        edits(removingLines: marked.lines, in: buffer)
    }

    /// Giữ LẠI các dòng được đánh dấu, xóa phần còn lại (Remove Unmarked Lines).
    public static func keepOnlyEdits(marked: LineMarkSet, in buffer: TextBuffer) -> [TextEdit] {
        var inverted = marked
        inverted.invert(lineCount: buffer.lineCount)
        return edits(removingLines: inverted.lines, in: buffer)
    }

    /// Nội dung các dòng được đánh dấu, mỗi dòng một dòng (Copy Marked Lines).
    ///
    /// Kết thúc bằng ký tự xuống dòng của chính tài liệu chứ không phải "\n" cố định: người
    /// dùng chép từ file CRLF rồi dán sang chỗ khác vẫn phải ra CRLF.
    public static func text(of marked: LineMarkSet, in buffer: TextBuffer) -> String {
        let ranges = DocumentOps.lineRanges(of: buffer)
        var out: [UInt8] = []
        for line in marked.sorted where line < ranges.count {
            out.append(contentsOf: buffer.bytes(in: ranges[line]))
            // Dòng cuối tài liệu có thể không có ký tự xuống dòng — thêm vào để các dòng chép
            // ra không dính vào nhau.
            if out.last != UInt8(ascii: "\n") { out.append(UInt8(ascii: "\n")) }
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func edits(removingLines doomed: Set<Int>, in buffer: TextBuffer) -> [TextEdit] {
        guard !doomed.isEmpty else { return [] }
        let ranges = DocumentOps.lineRanges(of: buffer)
        let selected = doomed.sorted().compactMap { $0 < ranges.count ? ranges[$0] : nil }
        return DocumentOps.coalesce(selected).map { TextEdit(range: $0, bytes: []) }
    }
}
