import Foundation

/// Chuyển CSV sang định dạng khác (FR-CSV-406).
///
/// Mọi hàm ở đây đọc buffer theo CỬA SỔ qua `CSVEngine.forEachRow`, nên bộ nhớ dùng thêm là
/// một cửa sổ chứ không phải cả tài liệu. Nhưng KẾT QUẢ thì nằm trọn trong RAM: chỗ gọi phải
/// tự quyết định có mở nó thành tab mới hay ghi thẳng ra file. Nói rõ ở đây vì con số ấy
/// không nhỏ — CSV sang XML thường phình ba tới bốn lần.
///
/// - Parameter maxRows: 0 = cả tài liệu; số dương = chỉ bấy nhiêu hàng DỮ LIỆU, dùng cho bản
///   xem trước. Xem trước phải đi qua ĐÚNG hàm sinh ra bản thật, không phải một hàm rút gọn
///   viết riêng: hai đường khác nhau thì bản xem trước sẽ nói dối đúng vào lúc người dùng tin nó.
public enum CSVExport {

    /// Các định dạng đích.
    public enum Format: String, CaseIterable, Sendable {
        case tsv
        case json
        case xml
        case markdown
        case sqlInsert

        public var displayName: String {
            switch self {
            case .tsv: return "TSV (phân tách bằng Tab)"
            case .json: return "JSON"
            case .xml: return "XML"
            case .markdown: return "Bảng Markdown"
            case .sqlInsert: return "Câu lệnh SQL INSERT"
            }
        }

        /// Đuôi file gợi ý khi ghi ra đĩa hoặc đặt tên tab mới.
        public var fileExtension: String {
            switch self {
            case .tsv: return "tsv"
            case .json: return "json"
            case .xml: return "xml"
            case .markdown: return "md"
            case .sqlInsert: return "sql"
            }
        }
    }

    /// Chuyển đổi theo `format`.
    public static func convert(
        _ buffer: TextBuffer,
        dialect: CSVDialect,
        to format: Format,
        hasHeader: Bool = true,
        tableName: String = "du_lieu",
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        switch format {
        case .tsv:
            return try changeDialect(
                buffer, from: dialect, to: .tab, maxRows: maxRows, cancelToken: cancelToken
            )
        case .json:
            return try CSVOps.toJSON(
                buffer, dialect: dialect, hasHeader: hasHeader,
                maxRows: maxRows, cancelToken: cancelToken
            )
        case .xml:
            return try toXML(
                buffer, dialect: dialect, hasHeader: hasHeader,
                maxRows: maxRows, cancelToken: cancelToken
            )
        case .markdown:
            return try toMarkdown(
                buffer, dialect: dialect, hasHeader: hasHeader,
                maxRows: maxRows, cancelToken: cancelToken
            )
        case .sqlInsert:
            return try toSQLInsert(
                buffer, dialect: dialect, hasHeader: hasHeader, tableName: tableName,
                maxRows: maxRows, cancelToken: cancelToken
            )
        }
    }

    // MARK: - Đổi delimiter / quote

    /// Viết lại tài liệu với dấu phân tách và dấu bọc khác (FR-CSV-406).
    ///
    /// Khác với hoán vị cột, ở đây việc CHUẨN HÓA cách bọc là đúng mục đích: đầu ra phải hợp
    /// lệ theo dialect MỚI, nên mọi field đều được bóc ra rồi bọc lại theo luật mới. Field
    /// chứa dấu phân tách mới — ví dụ một ô có sẵn ký tự Tab khi đổi sang TSV — vì thế được
    /// bọc lại, chứ không lặng lẽ tách thành hai cột.
    public static func changeDialect(
        _ buffer: TextBuffer,
        from source: CSVDialect,
        to target: CSVDialect,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        var out = ""
        var rows = 0
        try CSVEngine.forEachRow(in: buffer, dialect: source, cancelToken: cancelToken) { row in
            let fields = row.map { field -> String in
                CSVEngine.escape(value(field, in: buffer, dialect: source), dialect: target)
            }
            out += fields.joined(separator: String(UnicodeScalar(target.delimiter))) + "\n"
            rows += 1
            return maxRows <= 0 || rows < maxRows
        }
        return out
    }

    // MARK: - XML

    /// CSV → XML, mỗi hàng một `<hang>`, mỗi cột một phần tử con.
    ///
    /// Tên cột được LÀM SẠCH thành tên phần tử hợp lệ: XML không cho tên chứa khoảng trắng hay
    /// bắt đầu bằng chữ số, và một tên sai làm cả file không phân tích được — hỏng toàn bộ,
    /// không phải hỏng một ô.
    public static func toXML(
        _ buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        var names: [String] = []
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<bang>\n"
        var isFirstRow = true
        var rows = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            if isFirstRow {
                isFirstRow = false
                if hasHeader {
                    names = row.enumerated().map { index, field in
                        elementName(value(field, in: buffer, dialect: dialect), fallback: index)
                    }
                    return true
                }
            }
            while names.count < row.count { names.append("cot\(names.count + 1)") }

            out += "  <hang>\n"
            for (index, field) in row.enumerated() {
                let text = xmlEscaped(value(field, in: buffer, dialect: dialect))
                out += "    <\(names[index])>\(text)</\(names[index])>\n"
            }
            out += "  </hang>\n"
            rows += 1
            return maxRows <= 0 || rows < maxRows
        }
        return out + "</bang>\n"
    }

    /// Tên phần tử XML hợp lệ, giữ được chữ tiếng Việt.
    ///
    /// XML 1.0 cho phép chữ Unicode trong tên, nên không cần bỏ dấu — bỏ dấu sẽ làm hai cột
    /// "ngày" và "ngay" trở thành một. Chỉ thay những ký tự thật sự không hợp lệ.
    static func elementName(_ raw: String, fallback index: Int) -> String {
        var out = ""
        for scalar in raw.unicodeScalars {
            let ok = CharacterSet.alphanumerics.contains(scalar)
                || scalar == "_" || scalar == "-" || scalar == "."
            out.unicodeScalars.append(ok ? scalar : "_")
        }
        // Tên XML không được bắt đầu bằng chữ số, dấu chấm, dấu gạch ngang, hay chuỗi rỗng.
        if let first = out.unicodeScalars.first,
           CharacterSet.decimalDigits.contains(first) || first == "-" || first == "." {
            out = "_" + out
        }
        return out.isEmpty ? "cot\(index + 1)" : out
    }

    static func xmlEscaped(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(character)
            }
        }
        return out
    }

    // MARK: - Markdown

    /// CSV → bảng Markdown.
    ///
    /// Số cột của bảng lấy theo hàng RỘNG NHẤT trong phần được xuất, không theo hàng tiêu đề:
    /// bảng Markdown thiếu cột thì phần dữ liệu thừa biến mất, và biến mất im lặng.
    public static func toMarkdown(
        _ buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        var header: [String] = []
        var body: [[String]] = []
        var isFirstRow = true
        var rows = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            let values = row.map { markdownEscaped(value($0, in: buffer, dialect: dialect)) }
            if isFirstRow {
                isFirstRow = false
                if hasHeader { header = values; return true }
            }
            body.append(values)
            rows += 1
            return maxRows <= 0 || rows < maxRows
        }

        let width = max(header.count, body.map(\.count).max() ?? 0)
        guard width > 0 else { return "" }
        while header.count < width { header.append("Cột \(header.count + 1)") }

        var out = "| " + header.joined(separator: " | ") + " |\n"
        out += "|" + String(repeating: " --- |", count: width) + "\n"
        for var values in body {
            while values.count < width { values.append("") }
            out += "| " + values.joined(separator: " | ") + " |\n"
        }
        return out
    }

    /// Ký tự phá vỡ cấu trúc bảng Markdown.
    ///
    /// Dấu `|` chưa escape sẽ tách một ô thành hai cột, và mọi cột sau nó lệch đi — cùng loại
    /// hỏng với dấu phẩy chưa bọc trong CSV. Xuống dòng thì phá luôn cả hàng, nên đổi thành
    /// `<br>` (thứ mà bảng Markdown chấp nhận).
    static func markdownEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "\r", with: "<br>")
    }

    // MARK: - SQL INSERT

    /// CSV → câu lệnh `INSERT`.
    ///
    /// Cột nào suy ra được là SỐ thì giá trị viết trần, không bọc nháy (`FR-CSV-405` lo phần
    /// suy luận). Bọc mọi thứ thành chuỗi sẽ đẩy cả cột số vào cơ sở dữ liệu dưới dạng chữ, và
    /// mọi phép tính sau đó phải ép kiểu.
    ///
    /// Ô rỗng của cột số thành `NULL` — chuỗi rỗng không phải là số, và `''` sẽ bị cơ sở dữ
    /// liệu từ chối hoặc âm thầm đổi thành 0. Ô rỗng của cột chữ vẫn là `''`, vì ở đó "chuỗi
    /// rỗng" là một giá trị có thật.
    public static func toSQLInsert(
        _ buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        tableName: String = "du_lieu",
        types: [CSVValueType]? = nil,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> String {
        let columnTypes = try types ?? CSVValidator.inferTypes(
            in: buffer, dialect: dialect, hasHeader: hasHeader, cancelToken: cancelToken
        )

        var names: [String] = []
        var out = ""
        var isFirstRow = true
        var rows = 0
        let table = sqlIdentifier(tableName)

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            if isFirstRow {
                isFirstRow = false
                if hasHeader {
                    names = row.map { sqlIdentifier(value($0, in: buffer, dialect: dialect)) }
                    return true
                }
            }
            while names.count < row.count { names.append(sqlIdentifier("cot\(names.count + 1)")) }

            let columns = (0 ..< row.count).map { names[$0] }.joined(separator: ", ")
            let values = row.enumerated().map { index, field -> String in
                let text = value(field, in: buffer, dialect: dialect)
                let isNumber = index < columnTypes.count && columnTypes[index] == .number
                if isNumber { return text.isEmpty ? "NULL" : text }
                return sqlString(text)
            }.joined(separator: ", ")

            out += "INSERT INTO \(table) (\(columns)) VALUES (\(values));\n"
            rows += 1
            return maxRows <= 0 || rows < maxRows
        }
        return out
    }

    /// Tên bảng/cột bọc trong nháy kép theo chuẩn SQL, nháy kép bên trong nhân đôi.
    static func sqlIdentifier(_ raw: String) -> String {
        let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped.isEmpty ? "cot" : escaped)\""
    }

    /// Chuỗi SQL: bọc nháy đơn, nháy đơn bên trong NHÂN ĐÔI.
    ///
    /// Đây là chỗ duy nhất trong cả nhóm chuyển đổi mà làm sai không chỉ ra kết quả xấu — một
    /// giá trị như `O'Brien` chưa nhân đôi sẽ làm câu lệnh không chạy, và một giá trị cố ý
    /// dựng sẵn sẽ nối thêm câu lệnh khác vào sau.
    static func sqlString(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "''") + "'"
    }

    // MARK: - Dùng chung

    private static func value(
        _ field: CSVField, in buffer: TextBuffer, dialect: CSVDialect
    ) -> String {
        String(
            decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
            as: UTF8.self
        )
    }
}
