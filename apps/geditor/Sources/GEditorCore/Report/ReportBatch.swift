import Foundation

/// Sinh loạt báo cáo từ một danh sách tham số — FR-RPT-006, và là vế *"chạy batch theo danh
/// sách tham số"* của FR-DQR-003 (*"63 tỉnh, 63 báo cáo chất lượng"*).
///
/// ```sh
/// geditor --report thang.greport.md --param-list tinh.csv --out bc/ du-lieu.csv
/// ```
///
/// ## Danh sách tham số nhận CSV hoặc JSON, và KHÔNG nhận gì khác
///
/// CSV vì đó là thứ người ta đã có sẵn (danh sách 63 tỉnh nằm trong một cột của một bảng nào
/// đó); JSON vì đó là thứ một hệ thống khác sinh ra. Không nhận YAML: một danh sách tham số là
/// dữ liệu phẳng, và thêm một định dạng thứ ba chỉ để viết cùng một bảng theo lối thứ ba là
/// thêm một chỗ để hỏng.
///
/// ## Một bộ tham số hỏng KHÔNG dừng cả loạt
///
/// Cùng luật với "một khối hỏng không giết cả báo cáo": chạy 63 tỉnh mà tỉnh thứ tư thiếu dữ
/// liệu thì 62 tỉnh còn lại vẫn phải ra. Kết quả gom lại thành một bảng tổng kết, và mã thoát
/// nói ra là có bao nhiêu bộ hỏng — người chạy đêm hôm không đọc từng dòng, họ đọc mã thoát.
public enum ReportBatch {

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Một bộ tham số, giữ nguyên THỨ TỰ CỘT của tệp nguồn.
    ///
    /// Thứ tự quan trọng vì tên tệp đầu ra mặc định ghép từ các giá trị: đổi thứ tự cột là đổi
    /// tên mọi tệp đầu ra, và một thư mục báo cáo đổi tên hàng loạt sau một lần sửa vô hại là
    /// thứ không ai truy ra được nguyên nhân.
    public struct ParameterSet: Equatable, Sendable {
        public var order: [String]
        public var values: [String: String]

        public init(order: [String], values: [String: String]) {
            self.order = order
            self.values = values
        }

        /// Chuỗi mô tả bộ này, để in ra bảng tổng kết.
        public var label: String {
            order.compactMap { name in
                values[name].map { "\(name)=\($0)" }
            }.joined(separator: " ")
        }
    }

    // MARK: - Đọc danh sách

    public static func parameterSets(fromFile path: String) throws -> [ParameterSet] {
        guard let bytes = FileManager.default.contents(atPath: path) else {
            throw Failure(message: "không đọc được danh sách tham số \(path)")
        }
        let isJSON = (path as NSString).pathExtension.lowercased() == "json"
            || bytes.first.map { $0 == UInt8(ascii: "[") || $0 == UInt8(ascii: "{") } == true
        let sets = isJSON
            ? try fromJSON(bytes, path: path)
            : try fromCSV([UInt8](bytes), path: path)
        guard !sets.isEmpty else {
            throw Failure(message: "\(path) không có bộ tham số nào")
        }
        return sets
    }

    static func fromJSON(_ data: Data, path: String) throws -> [ParameterSet] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            throw Failure(message: "\(path) không phải JSON hợp lệ")
        }
        let objects: [[String: Any]]
        if let array = root as? [[String: Any]] {
            objects = array
        } else if let single = root as? [String: Any] {
            // Một object đơn cũng nhận: chạy thử một bộ trước khi chạy cả sáu mươi ba là thao
            // tác đầu tiên người ta làm, và bắt họ bọc thêm hai dấu ngoặc vuông là một rào cản
            // không bảo vệ gì.
            objects = [single]
        } else {
            throw Failure(message: "\(path): JSON phải là MẢNG các object «tên: giá trị»")
        }
        return try objects.enumerated().map { index, object in
            var values: [String: String] = [:]
            // Khoá của JSON không có thứ tự, nên sắp theo bảng chữ cái để tên tệp đầu ra tất
            // định. CSV thì giữ thứ tự cột thật.
            let order = object.keys.sorted()
            for key in order {
                guard let text = scalarText(object[key]) else {
                    throw Failure(message: "\(path) bộ thứ \(index + 1): giá trị của «\(key)» "
                        + "không phải chuỗi/số/boolean")
                }
                values[key] = text
            }
            return ParameterSet(order: order, values: values)
        }
    }

    static func scalarText(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as NSNumber:
            // `NSNumber` gói cả boolean lẫn số. `1` phải ra "1", không ra "true".
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            let double = number.doubleValue
            return double == double.rounded() && abs(double) < 1e15
                ? String(number.intValue) : String(double)
        default: return nil
        }
    }

    static func fromCSV(_ bytes: [UInt8], path: String) throws -> [ParameterSet] {
        let dialect = CSVEngine.detectDialect(sample: bytes)
        let rows = CSVEngine.parse(bytes, dialect: dialect)
        guard let header = rows.first else {
            throw Failure(message: "\(path) rỗng")
        }
        let names = header.map { text(of: $0, in: bytes, dialect: dialect) }
        guard names.allSatisfy({ !$0.isEmpty }) else {
            throw Failure(message: "\(path): hàng tiêu đề có ô trống — mỗi cột phải là TÊN của "
                + "một tham số")
        }
        var sets: [ParameterSet] = []
        for row in rows.dropFirst() {
            // Hàng trống ở cuối tệp là chuyện thường của CSV; bỏ qua chứ không báo lỗi.
            let cells = row.map { text(of: $0, in: bytes, dialect: dialect) }
            if cells.allSatisfy(\.isEmpty) { continue }
            var values: [String: String] = [:]
            for (index, name) in names.enumerated() {
                values[name] = index < cells.count ? cells[index] : ""
            }
            sets.append(ParameterSet(order: names, values: values))
        }
        return sets
    }

    private static func text(of field: CSVField, in bytes: [UInt8], dialect: CSVDialect)
        -> String {
        let raw = Array(bytes[field.range])
        let unescaped = field.isQuoted ? CSVEngine.unescape(raw, dialect: dialect) : raw
        return String(decoding: unescaped, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Tên tệp đầu ra

    /// Tên tệp cho một bộ tham số.
    ///
    /// `template` nhận chỗ trống `{tên}`. Không khai thì tên ghép từ THÂN tệp báo cáo và các giá
    /// trị, theo thứ tự cột: `thang.greport.md` + `{tinh: Huế}` → `thang-Huế.html`.
    public static func outputName(
        template: String?, set: ParameterSet, reportPath: String, fileExtension: String = "html"
    ) -> String {
        if let template, !template.isEmpty {
            var out = template
            for (name, value) in set.values {
                out = out.replacingOccurrences(of: "{\(name)}", with: slug(value))
            }
            return out
        }
        var stem = (reportPath as NSString).lastPathComponent
        for suffix in [".greport.md", ".md"] where stem.hasSuffix(suffix) {
            stem = String(stem.dropLast(suffix.count))
            break
        }
        let parts = set.order.compactMap { set.values[$0] }.filter { !$0.isEmpty }
        let joined = parts.map(slug).joined(separator: "-")
        return (joined.isEmpty ? stem : stem + "-" + joined) + "." + fileExtension
    }

    /// Làm sạch một giá trị để dùng trong TÊN TỆP.
    ///
    /// Giữ chữ tiếng Việt có dấu — macOS xử lý được, và `bao-cao-Thừa Thiên Huế.html` đọc được
    /// hơn hẳn `bao-cao-thua-thien-hue.html`. Chỉ bỏ những ký tự thật sự phá đường dẫn: `/`,
    /// `:`, và ký tự điều khiển. Khoảng trắng thành `_` vì một tên tệp có dấu cách buộc mọi
    /// script gọi nó phải nhớ bọc nháy.
    public static func slug(_ value: String) -> String {
        var out = ""
        for character in value {
            if character == "/" || character == ":" || character == "\\" {
                out.append("-")
            } else if character.isWhitespace {
                out.append("_")
            } else if character.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) {
                out.append(character)
            }
        }
        return out.isEmpty ? "khong-ten" : out
    }

    // MARK: - Kết quả

    public struct Outcome: Sendable {
        public struct Entry: Sendable {
            public var label: String
            public var path: String?
            public var failed: Bool
            public var message: String

            public init(label: String, path: String?, failed: Bool, message: String) {
                self.label = label
                self.path = path
                self.failed = failed
                self.message = message
            }
        }

        public var entries: [Entry]

        public init(entries: [Entry] = []) {
            self.entries = entries
        }

        public var failedCount: Int { entries.filter(\.failed).count }
        public var succeededCount: Int { entries.count - failedCount }

        /// Bảng tổng kết cho người đọc — FR-RPT-006 (*"báo cáo tổng kết thành công/lỗi từng
        /// file"*).
        public var report: String {
            var lines = entries.map { entry -> String in
                let mark = entry.failed ? "✖" : "✔"
                let where_ = entry.path.map { " → " + ($0 as NSString).lastPathComponent } ?? ""
                return "\(mark) \(entry.label)\(where_)"
                    + (entry.message.isEmpty ? "" : "  \(entry.message)")
            }
            lines.append("— \(succeededCount) xong · \(failedCount) hỏng "
                + "trên \(entries.count) bộ tham số")
            return lines.joined(separator: "\n")
        }
    }
}
