import Foundation

/// Một đoạn văn bản thuộc về một CỘT (FR-CSV-402).
public struct CSVColumnSpan: Equatable, Sendable {
    /// Phạm vi byte trong tài liệu, gồm cả dấu bọc nếu field có bọc.
    public let range: Range<Int>
    /// Chỉ số cột LOGIC, đếm từ 0.
    public let column: Int
    /// Hàng logic thứ mấy kể từ đầu vùng đang xét; 0 là hàng đầu tiên.
    public let row: Int

    public init(range: Range<Int>, column: Int, row: Int) {
        self.range = range
        self.column = column
        self.row = row
    }
}

/// Tô màu theo CỘT trên một cửa sổ nội dung (FR-CSV-402).
///
/// Cùng bài toán với tô màu cú pháp, và cùng lời giải: lớp hiển thị chỉ giữ 2 MB, còn cột thì
/// chỉ đếm đúng khi biết hàng bắt đầu từ đâu. Cắt cửa sổ vào GIỮA một field bọc ngoặc chứa
/// xuống dòng sẽ làm mọi cột sau đó lệch một bậc — và màu lệch cột trên file dữ liệu còn tệ
/// hơn không có màu, vì người dùng đọc theo màu.
public enum CSVColumns {

    /// Quãng lùi tối đa khi đi tìm đầu hàng an toàn.
    public static let safeStartSearchLimit = 1 << 20

    /// Đầu HÀNG an toàn tại hoặc trước `offset`.
    ///
    /// Cách xác định: đếm dấu bọc từ một mốc lùi về trước. Với CSV đúng RFC 4180, số dấu bọc
    /// tính từ ĐẦU FILE tới một đầu dòng là CHẴN khi và chỉ khi đầu dòng ấy nằm ngoài field
    /// bọc — kể cả khi bên trong có `""`, vì `""` là hai dấu nên không đổi tính chẵn lẻ.
    ///
    /// **Chính xác** khi quãng lùi chạm tới đầu file. **Phỏng đoán** khi phải dừng ở trần:
    /// lúc ấy tính chẵn lẻ được tính từ một mốc chưa chắc nằm ngoài field bọc. Nói rõ ra thay
    /// vì để tưởng là luôn đúng; trường hợp ấy cần một file có field bọc dài hơn 1 MB.
    ///
    /// Đường tắt cho trường hợp thường gặp nhất: quãng lùi KHÔNG có dấu bọc nào thì mọi đầu
    /// dòng đều an toàn, khỏi cần đếm.
    public static func safeRowStart(
        at offset: Int, in buffer: TextBuffer, dialect: CSVDialect
    ) -> Int {
        guard offset > 0, buffer.count > 0 else { return 0 }
        let target = Swift.min(offset, buffer.count)
        let floor = Swift.max(0, target - safeStartSearchLimit)

        let region = buffer.bytes(in: floor ..< target)
        guard region.contains(dialect.quote) else {
            // Không có dấu bọc nào: đầu dòng nào cũng an toàn.
            return lineStart(at: target, in: buffer, notBefore: floor, region: region, base: floor)
        }

        // Đi từ mốc lùi về phía trước, đếm dấu bọc, ghi lại đầu dòng gần `target` nhất mà số
        // dấu bọc tới đó là chẵn.
        var quotes = 0
        var best = floor
        var atLineStart = true
        for (index, byte) in region.enumerated() {
            if atLineStart, quotes % 2 == 0 { best = floor + index }
            atLineStart = false
            if byte == dialect.quote { quotes += 1 }
            if byte == 0x0A { atLineStart = true }
        }
        if atLineStart, quotes % 2 == 0 { best = target }
        return best
    }

    private static func lineStart(
        at target: Int, in buffer: TextBuffer, notBefore floor: Int, region: [UInt8], base: Int
    ) -> Int {
        var index = region.count - 1
        while index >= 0 {
            if region[index] == 0x0A { return base + index + 1 }
            index -= 1
        }
        return floor
    }

    /// Các đoạn cột phủ `range`.
    ///
    /// Bắt đầu phân tích từ đầu hàng an toàn (có thể nằm TRƯỚC `range`), rồi bỏ những đoạn
    /// nằm hẳn ngoài `range`. Đoạn vắt qua biên bị cắt cho vừa — cửa sổ chỉ tô được phần nó
    /// nhìn thấy.
    public static func spans(
        in buffer: TextBuffer,
        range: Range<Int>,
        dialect: CSVDialect,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) -> [CSVColumnSpan] {
        guard buffer.count > 0, !range.isEmpty else { return [] }
        // Kẹp TỪNG ĐẦU rồi mới dựng Range.
        //
        // `max(0, lower) ..< min(count, upper)` trông vô hại nhưng sập khi phạm vi nằm hẳn
        // ngoài tài liệu: 99 ..< 4. Swift không trả về khoảng rỗng, nó dừng chương trình.
        let lower = Swift.min(Swift.max(0, range.lowerBound), buffer.count)
        let upper = Swift.min(Swift.max(lower, range.upperBound), buffer.count)
        let clamped = lower ..< upper
        guard !clamped.isEmpty else { return [] }

        let start = safeRowStart(at: clamped.lowerBound, in: buffer, dialect: dialect)
        let end = rowAlignedEnd(after: clamped.upperBound, in: buffer)
        guard end > start else { return [] }

        let bytes = buffer.bytes(in: start ..< end)
        let rows = CSVEngine.parse(bytes, dialect: dialect, maxRows: maxRows, cancelToken: cancelToken)

        var spans: [CSVColumnSpan] = []
        var rowIndex = 0
        for row in rows {
            defer { rowIndex += 1 }
            for (column, field) in row.enumerated() {
                let lower = field.range.lowerBound + start
                let upper = field.range.upperBound + start
                guard upper > clamped.lowerBound, lower < clamped.upperBound else { continue }
                let clippedLower = Swift.max(lower, clamped.lowerBound)
                let clippedUpper = Swift.min(upper, clamped.upperBound)
                guard clippedUpper > clippedLower else { continue }
                spans.append(CSVColumnSpan(
                    range: clippedLower ..< clippedUpper, column: column, row: rowIndex
                ))
            }
        }
        return spans
    }

    /// Nới về sau tới hết dòng vật lý, để hàng cuối không bị cắt cụt giữa chừng.
    private static func rowAlignedEnd(after offset: Int, in buffer: TextBuffer) -> Int {
        guard offset < buffer.count else { return buffer.count }
        let line = buffer.lineNumber(atOffset: offset)
        guard line + 1 < buffer.lineCount else { return buffer.count }
        return buffer.offset(ofLineStart: line + 1)
    }
}
