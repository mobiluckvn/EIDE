import Foundation

/// Kiểu CSV nhận diện được: ký tự phân tách + ký tự bọc field.
public struct CSVDialect: Equatable {
    public var delimiter: UInt8
    public var quote: UInt8

    public init(delimiter: UInt8, quote: UInt8 = UInt8(ascii: "\"")) {
        self.delimiter = delimiter
        self.quote = quote
    }

    public static let comma = CSVDialect(delimiter: UInt8(ascii: ","))
    public static let semicolon = CSVDialect(delimiter: UInt8(ascii: ";"))
    public static let tab = CSVDialect(delimiter: UInt8(ascii: "\t"))
    public static let pipe = CSVDialect(delimiter: UInt8(ascii: "|"))

    /// Nhãn hiển thị trên status bar ("CSV · dấu phẩy").
    public var displayName: String {
        switch delimiter {
        case UInt8(ascii: ","): return "dấu phẩy"
        case UInt8(ascii: ";"): return "chấm phẩy"
        case UInt8(ascii: "\t"): return "tab"
        case UInt8(ascii: "|"): return "gạch đứng"
        default: return String(UnicodeScalar(delimiter))
        }
    }
}

/// Một field đã định vị: phạm vi byte thô (gồm cả dấu bọc nếu có).
public struct CSVField: Equatable {
    public var range: Range<Int>
    public var isQuoted: Bool
}

/// Parser CSV/TSV theo RFC 4180 (FR-CSV-401).
///
/// Ba luật RFC 4180 phải giữ tuyệt đối — mọi thao tác cột đều dựa vào chúng:
///  1. Field bọc trong `"` có thể chứa delimiter.
///  2. `""` bên trong field bọc là một dấu `"` literal.
///  3. Field bọc có thể chứa CR/LF — một "dòng logic" ≠ một dòng vật lý.
///
/// Parser trả về PHẠM VI BYTE, không trả chuỗi: Table View và thao tác cột đọc
/// ngược vào buffer qua phạm vi này (SAD §2.3 — buffer là nguồn sự thật duy nhất).
public enum CSVEngine {

    /// Đoán dialect từ N dòng đầu bằng thống kê (FR-CSV-401).
    ///
    /// Tiêu chí: delimiter nào cho số field/dòng ổn định nhất (phương sai thấp nhất,
    /// ưu tiên số field lớn hơn khi hòa) thì thắng.
    public static func detectDialect(
        sample: [UInt8],
        candidates: [CSVDialect] = [.comma, .semicolon, .tab, .pipe],
        maxRows: Int = 20
    ) -> CSVDialect {
        var best = candidates[0]
        var bestScore = -Double.greatestFiniteMagnitude

        for dialect in candidates {
            let rows = parse(sample, dialect: dialect, maxRows: maxRows)
            let counts = rows.map { Double($0.count) }
            guard counts.count >= 1, let first = counts.first, first > 1 else { continue }

            let mean = counts.reduce(0, +) / Double(counts.count)
            let variance = counts.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(counts.count)
            // Ổn định (variance thấp) quan trọng hơn số cột nhiều.
            let score = -variance * 10 + mean
            if score > bestScore {
                bestScore = score
                best = dialect
            }
        }
        return best
    }

    /// Phân tích toàn bộ `bytes` thành các hàng logic, mỗi hàng là danh sách field.
    ///
    /// - Parameter maxRows: dừng sớm (dùng cho auto-detect và preview); 0 = không giới hạn.
    public static func parse(
        _ bytes: [UInt8],
        dialect: CSVDialect,
        maxRows: Int = 0,
        cancelToken: CancelToken? = nil
    ) -> [[CSVField]] {
        var rows: [[CSVField]] = []
        var row: [CSVField] = []
        var i = 0
        var sinceLastCheck = 0
        let n = bytes.count
        let quote = dialect.quote
        let delimiter = dialect.delimiter

        while i < n {
            // Kiểm tra hủy theo lô, không theo từng byte: lock mỗi byte sẽ phá throughput.
            sinceLastCheck += 1
            if let cancelToken, sinceLastCheck >= 65_536 {
                sinceLastCheck = 0
                if (try? cancelToken.check()) == nil { break }
            }

            // --- một field ---
            let fieldStart = i
            var isQuoted = false

            if bytes[i] == quote {
                isQuoted = true
                i += 1
                while i < n {
                    if bytes[i] == quote {
                        if i + 1 < n && bytes[i + 1] == quote {
                            i += 2          // "" → dấu " literal, vẫn trong field
                        } else {
                            i += 1          // đóng field
                            break
                        }
                    } else {
                        i += 1              // gồm cả CR/LF nằm trong field
                    }
                }
            } else {
                while i < n, bytes[i] != delimiter,
                      bytes[i] != UInt8(ascii: "\n"), bytes[i] != UInt8(ascii: "\r") {
                    i += 1
                }
            }
            row.append(CSVField(range: fieldStart ..< i, isQuoted: isQuoted))

            // --- biên field / biên hàng ---
            if i < n && bytes[i] == delimiter {
                i += 1
                if i == n {                  // dòng kết thúc bằng delimiter → field rỗng cuối
                    row.append(CSVField(range: i ..< i, isQuoted: false))
                }
                continue
            }
            if i < n && (bytes[i] == UInt8(ascii: "\n") || bytes[i] == UInt8(ascii: "\r")) {
                if bytes[i] == UInt8(ascii: "\r"), i + 1 < n, bytes[i + 1] == UInt8(ascii: "\n") {
                    i += 2
                } else {
                    i += 1
                }
                rows.append(row)
                row = []
                if maxRows > 0 && rows.count >= maxRows { return rows }
                continue
            }
            if i >= n { break }
        }

        if !row.isEmpty { rows.append(row) }
        return rows
    }

    /// Duyệt từng hàng LOGIC của một tài liệu mà KHÔNG dựng cả nội dung trong RAM.
    ///
    /// `parse(_:)` nhận một mảng byte, nên gọi nó trên tài liệu 1 GB là sao chép 1 GB — đúng
    /// loại khiếm khuyết vừa sửa ở đường ghi bản nháp. Hàm này đọc theo CỬA SỔ: mỗi lần lấy
    /// một khoảng, phân tích các hàng TRỌN VẸN trong đó, rồi bắt đầu lại từ hàng bị cắt.
    ///
    /// Bộ nhớ dùng tối đa là một cửa sổ cộng một hàng — không phụ thuộc kích thước tài liệu.
    /// Phạm vi field trả về là offset TOÀN CỤC trong buffer.
    ///
    /// - Parameter body: trả `false` để dừng sớm.
    public static func forEachRow(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        windowBytes: Int = 1 << 20,
        cancelToken: CancelToken = CancelToken(),
        _ body: ([CSVField]) throws -> Bool
    ) throws {
        try forEachWindow(
            in: buffer, dialect: dialect, windowBytes: windowBytes, cancelToken: cancelToken
        ) { rows, _, base in
            for row in rows {
                let shifted = row.map {
                    CSVField(
                        range: ($0.range.lowerBound + base) ..< ($0.range.upperBound + base),
                        isQuoted: $0.isQuoted
                    )
                }
                if try !body(shifted) { return false }
            }
            return true
        }
    }

    /// Duyệt theo CỬA SỔ, đưa ra cả mảng byte của cửa sổ ấy.
    ///
    /// Có mặt cho những phép quét đọc TỪNG Ô của cả bảng — hồ sơ dữ liệu, bộ phát hiện làm
    /// sạch. `forEachRow` chỉ trả phạm vi toàn cục, nên người gọi phải `buffer.bytes(in:)` cho
    /// mỗi ô, và đó là MỘT LẦN CẤP PHÁT MẢNG cho mỗi ô: với bảng 1 triệu hàng × 20 cột là hai
    /// mươi triệu lần. Ở đây mỗi cửa sổ cấp phát đúng một lần, và người gọi đọc thẳng trong đó.
    ///
    /// Phạm vi field trong `rows` tính theo CỬA SỔ (bắt đầu từ 0), còn `base` là offset của
    /// cửa sổ trong tài liệu — cộng vào mới ra offset toàn cục. Hai hệ tọa độ cạnh nhau là cái
    /// bẫy, nên tên tham số nói thẳng ra.
    ///
    /// - Parameter body: trả `false` để dừng sớm.
    public static func forEachWindow(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        windowBytes: Int = 1 << 20,
        cancelToken: CancelToken = CancelToken(),
        _ body: (ArraySlice<[CSVField]>, [UInt8], Int) throws -> Bool
    ) throws {
        var position = 0
        var window = max(windowBytes, 4096)

        while position < buffer.count {
            try cancelToken.check()

            let end = min(position + window, buffer.count)
            let slice = buffer.bytes(in: position ..< end)
            let rows = parse(slice, dialect: dialect, cancelToken: cancelToken)
            let reachedEnd = end == buffer.count

            // Hàng cuối của cửa sổ có thể bị cắt giữa chừng, nên chỉ dùng nó khi đã tới hết
            // tài liệu. Phân tích lại một hàng ở vòng sau rẻ hơn nhiều so với đoán sai.
            let usable = reachedEnd ? rows[...] : rows.dropLast()

            guard !usable.isEmpty else {
                // Cả cửa sổ không chứa nổi một hàng trọn vẹn (field bọc rất dài, hoặc dòng
                // khổng lồ). Nới cửa sổ thay vì bỏ cuộc — nếu không sẽ kẹt tại chỗ.
                guard !reachedEnd else { return }
                window *= 2
                continue
            }

            if try !body(usable, slice, position) { return }

            position = reachedEnd
                ? end
                : position + (rows.last?.first?.range.lowerBound ?? (end - position))
        }
    }

    /// Bỏ dấu bọc và giải escape `""` → giá trị thật của field.
    public static func unescape(_ raw: [UInt8], dialect: CSVDialect) -> [UInt8] {
        guard raw.count >= 2, raw.first == dialect.quote, raw.last == dialect.quote else { return raw }
        var out: [UInt8] = []
        out.reserveCapacity(raw.count - 2)
        var i = 1
        let end = raw.count - 1
        while i < end {
            if raw[i] == dialect.quote, i + 1 < end, raw[i + 1] == dialect.quote {
                out.append(dialect.quote)
                i += 2
            } else {
                out.append(raw[i])
                i += 1
            }
        }
        return out
    }

    /// Bọc lại giá trị khi ghi ngược vào văn bản (FR-CSV-403 — sửa ô ở Table view).
    ///
    /// Bọc khi giá trị chứa delimiter, dấu bọc, CR/LF, hoặc có khoảng trắng đầu/cuối.
    public static func escape(_ value: String, dialect: CSVDialect) -> String {
        let quote = Character(UnicodeScalar(dialect.quote))
        let delimiter = Character(UnicodeScalar(dialect.delimiter))
        let needsQuoting = value.contains(delimiter)
            || value.contains(quote)
            || value.contains("\n")
            || value.contains("\r")
            || value.first == " "
            || value.last == " "
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: String(quote), with: String(repeating: quote, count: 2))
        return "\(quote)\(escaped)\(quote)"
    }
}
