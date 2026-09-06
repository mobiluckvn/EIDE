import Foundation

/// Xuất kết quả truy vấn — FR-QRY-006 *"export CSV/JSON/Markdown"*.
///
/// Ở lõi chứ không ở CLI, vì cùng ba định dạng ấy panel truy vấn cũng cần. Một bản hiện thực
/// thứ hai ở tầng giao diện là hai cách bọc dấu phẩy, và chúng sẽ lệch nhau đúng ở ô dữ liệu
/// khó nhất.
public enum QueryExport {

    public enum Format: String, CaseIterable, Equatable, Sendable {
        case csv, json, markdown

        /// Nhận cả `md` — người ta gõ `--format md` nhiều hơn `--format markdown`.
        public init?(argument: String) {
            switch argument.lowercased() {
            case "csv": self = .csv
            case "json": self = .json
            case "md", "markdown": self = .markdown
            default: return nil
            }
        }

        public var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            case .markdown: return "md"
            }
        }
    }

    public static func text(
        _ result: CSVQueryEngine.Result, format: Format
    ) -> String {
        switch format {
        case .csv: return csv(result)
        case .json: return json(result)
        case .markdown: return markdown(result)
        }
    }

    /// Đường ra có ĐÈ LÊN chính nguồn không (NFR-QRY-03).
    ///
    /// *"Mọi filter, query, pivot, chart tuyệt đối không sửa file nguồn; mọi kết quả ghi ra
    /// tab/file MỚI."* Chỉ tiêu ấy là P0 trong phạm vi FR-QRY.
    ///
    /// Chạy `--query … --out . --overwrite *.csv` trong chính thư mục dữ liệu là một lệnh gõ
    /// được, trông hợp lý, và **phá sạch dữ liệu gốc** — kết quả gộp năm dòng ghi đè lên bảng
    /// một triệu hàng. `--overwrite` KHÔNG được phép mở cửa ấy: cờ đó có nghĩa "ghi đè file
    /// KẾT QUẢ cũ", không có nghĩa "cho phép huỷ nguồn".
    ///
    /// So sau khi chuẩn hoá đường dẫn: `./a.csv` và `a.csv` là cùng một file, và người gõ vội
    /// thì gõ kiểu nào cũng có.
    public static func wouldOverwriteSource(output: String, source: String) -> Bool {
        URL(fileURLWithPath: output).standardizedFileURL.path
            == URL(fileURLWithPath: source).standardizedFileURL.path
    }

    // MARK: - CSV

    /// `NULL` thành ô RỖNG — quy ước CSV.
    ///
    /// Có mất mát, và nói ra: xuất ra rồi thì "chưa có giá trị" và "chuỗi rỗng" không phân biệt
    /// được nữa. Chấp nhận vì mọi công cụ đọc CSV đều hiểu ô rỗng theo nghĩa ấy; muốn giữ phân
    /// biệt thì xuất JSON.
    private static func csv(_ result: CSVQueryEngine.Result) -> String {
        var out = result.titles.map(escapeCSV).joined(separator: ",") + "\n"
        for row in result.rows {
            out += row.map { escapeCSV($0 ?? "") }.joined(separator: ",") + "\n"
        }
        return out
    }

    static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n")
            || value.contains("\r")
        else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - JSON

    /// Mảng đối tượng, **giữ đúng thứ tự cột**.
    ///
    /// Viết tay thay vì dùng `JSONEncoder` với `[String: String]`: từ điển không có thứ tự, và
    /// `.sortedKeys` sắp theo bảng chữ cái. Một kết quả `SELECT ma, ten, tuoi` mà xuất ra
    /// `{ma, ten, tuoi}` đảo thành `{ma, ten, tuoi}` theo alphabet là mất thông tin người dùng
    /// đã cố ý đặt vào câu truy vấn.
    ///
    /// `NULL` thành `null` thật, không thành `""` — đây là định dạng duy nhất trong ba cái giữ
    /// được phân biệt ấy.
    private static func json(_ result: CSVQueryEngine.Result) -> String {
        var out = "[\n"
        for (index, row) in result.rows.enumerated() {
            var pairs: [String] = []
            for (column, title) in result.titles.enumerated() {
                let value = column < row.count ? row[column] : nil
                pairs.append("    \(escapeJSON(title)): \(value.map(escapeJSON) ?? "null")")
            }
            out += "  {\n" + pairs.joined(separator: ",\n") + "\n  }"
            out += index == result.rows.count - 1 ? "\n" : ",\n"
        }
        return out + "]\n"
    }

    static func escapeJSON(_ value: String) -> String {
        var out = "\""
        for character in value.unicodeScalars {
            switch character {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                // Ký tự điều khiển phải đi qua `\uXXXX`; chữ tiếng Việt thì KHÔNG — thoát nó
                // thành `ế` là biến một tệp người đọc được thành một tệp phải giải mã.
                if character.value < 0x20 {
                    out += String(format: "\\u%04x", character.value)
                } else {
                    out.unicodeScalars.append(character)
                }
            }
        }
        return out + "\""
    }

    // MARK: - Markdown

    /// Bảng Markdown. `NULL` hiện thành chữ `NULL`.
    ///
    /// Khác CSV ở chỗ này, và cố ý: Markdown là để NGƯỜI ĐỌC, và một ô trống giữa bảng trông
    /// giống một ô chưa điền chứ không giống "không có giá trị".
    private static func markdown(_ result: CSVQueryEngine.Result) -> String {
        guard !result.titles.isEmpty else { return "" }
        var out = "| " + result.titles.map(escapeMarkdown).joined(separator: " | ") + " |\n"
        out += "|" + result.titles.map { _ in "---" }.joined(separator: "|") + "|\n"
        for row in result.rows {
            let cells = result.titles.indices.map { column -> String in
                let value = column < row.count ? row[column] : nil
                return escapeMarkdown(value ?? "NULL")
            }
            out += "| " + cells.joined(separator: " | ") + " |\n"
        }
        return out
    }

    static func escapeMarkdown(_ value: String) -> String {
        // Dấu `|` trong dữ liệu cắt bảng thành cột thừa. Xuống dòng cũng vậy — nó cắt cả HÀNG.
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
