import Foundation

/// Thẩm định JSON theo một JSON Schema do người dùng chỉ định — FR-KNW-909.
///
/// ## Tập con, và nói rõ là tập con
///
/// JSON Schema đầy đủ (draft 2020-12) có `$ref`, `allOf`/`anyOf`/`oneOf`, `if`/`then`/`else`,
/// `patternProperties`, `dependentSchemas`, `unevaluatedProperties`. Hiện thực đủ nó là một dự
/// án riêng, và phần lớn những thứ ấy không xuất hiện trong một tệp định nghĩa tool.
///
/// Ở đây là **tập con của các từ khoá mà một định nghĩa tool thật sự dùng**: `type`, `required`,
/// `properties`, `items`, `enum`, `minimum`/`maximum`, `minLength`/`maxLength`, `pattern`,
/// `additionalProperties: false`.
///
/// Gặp một từ khoá NGOÀI tập ấy thì **báo ra** (`unsupported`), không im lặng bỏ qua. Đó là khác
/// biệt quan trọng nhất của tệp này: một bộ thẩm định im lặng bỏ qua `oneOf` sẽ cho «hợp lệ» với
/// một tệp mà schema thật sự từ chối — sai theo hướng nguy hiểm nhất, vì người dùng tin nó.
///
/// ## Lỗi mang SỐ DÒNG lấy từ `JSONIndex`
///
/// Đặc tả của cụm này đòi "lỗi cú pháp chỉ đúng dòng". `JSONIndex` giữ khoảng BYTE của từng nút,
/// nên số dòng đi thẳng từ chỗ đọc tới chỗ báo — không phải dò lại bằng cách tìm chuỗi, cách vốn
/// sai ngay khi hai khoá trùng tên ở hai nhánh.
public enum JSONSchemaCheck {

    public struct Diagnostic: Equatable, Sendable {
        /// Dòng 0-BASED, cùng quy ước `GraphGrammars.Diagnostic` và `GraphSchema.Violation`.
        public let line: Int
        /// Đường tới chỗ sai, ví dụ `parameters.properties.city`.
        public let path: String
        public let message: String
        /// `true` khi lỗi là "schema dùng từ khoá tôi chưa hiểu" chứ không phải "dữ liệu sai".
        public let unsupported: Bool

        public init(line: Int, path: String, message: String, unsupported: Bool = false) {
            self.line = line
            self.path = path
            self.message = message
            self.unsupported = unsupported
        }
    }

    /// Từ khoá hiểu được. Mọi thứ khác trong một schema object sẽ thành `unsupported`.
    static let known: Set<String> = [
        "type", "required", "properties", "items", "enum", "minimum", "maximum",
        "minLength", "maxLength", "pattern", "additionalProperties",
        // Không ảnh hưởng phép kiểm nhưng hợp lệ và rất hay gặp — bỏ qua chúng là ĐÚNG.
        "title", "description", "default", "examples", "$schema", "$id",
    ]

    /// Thẩm định `json` theo `schema`. Cả hai là văn bản.
    public static func validate(json: String, schema: String) -> [Diagnostic] {
        guard let schemaObject = try? JSONSerialization.jsonObject(with: Data(schema.utf8)),
              let schemaMap = schemaObject as? [String: Any] else {
            return [Diagnostic(line: 0, path: "", message: "schema không phải một đối tượng JSON")]
        }
        guard let value = try? JSONSerialization.jsonObject(
            with: Data(json.utf8), options: [.fragmentsAllowed]) else {
            return [Diagnostic(line: 0, path: "", message: "tệp không phải JSON hợp lệ")]
        }

        let bytes = Array(json.utf8)
        let index = JSONIndex(bytes: bytes)
        var out: [Diagnostic] = []
        kiem(value, schemaMap, path: "", index: index, bytes: bytes, into: &out)
        return out.sorted { ($0.line, $0.path) < ($1.line, $1.path) }
    }

    // MARK: - Phép kiểm

    private static func kiem(
        _ value: Any, _ schema: [String: Any], path: String,
        index: JSONIndex, bytes: [UInt8], into out: inout [Diagnostic]
    ) {
        let line = dong(of: path, index: index, bytes: bytes)

        for key in schema.keys where !known.contains(key) {
            out.append(Diagnostic(
                line: line, path: path,
                message: "schema dùng «\(key)» — bộ kiểm này chưa hiểu, nên KHÔNG kiểm vế ấy",
                unsupported: true))
        }

        if let ten = schema["type"] as? String, !hopKieu(value, ten) {
            out.append(Diagnostic(line: line, path: path,
                                  message: "phải là \(ten), đang là \(tenKieu(value))"))
            // Kiểu đã sai thì mọi phép kiểm sâu hơn chỉ đẻ ra nhiễu — người sửa cần MỘT câu.
            return
        }

        if let cho_phep = schema["enum"] as? [Any] {
            let hop = cho_phep.contains { "\($0)" == "\(value)" }
            if !hop {
                out.append(Diagnostic(
                    line: line, path: path,
                    message: "«\(value)» không nằm trong \(cho_phep.map { "\($0)" })"))
            }
        }

        if let so = soCua(value) {
            if let min = soCua(schema["minimum"] ?? ""), so < min {
                out.append(Diagnostic(line: line, path: path, message: "phải ≥ \(min)"))
            }
            if let max = soCua(schema["maximum"] ?? ""), so > max {
                out.append(Diagnostic(line: line, path: path, message: "phải ≤ \(max)"))
            }
        }

        if let s = value as? String {
            if let min = schema["minLength"] as? Int, s.count < min {
                out.append(Diagnostic(line: line, path: path, message: "phải dài ≥ \(min) ký tự"))
            }
            if let max = schema["maxLength"] as? Int, s.count > max {
                out.append(Diagnostic(line: line, path: path, message: "phải dài ≤ \(max) ký tự"))
            }
            if let mau = schema["pattern"] as? String {
                // Regex HỎNG trong schema là lỗi của SCHEMA, không phải của dữ liệu — nói đúng
                // bên nào sai, nếu không người dùng đi sửa nhầm tệp.
                if let re = try? NSRegularExpression(pattern: mau) {
                    let ca = NSRange(s.startIndex..., in: s)
                    if re.firstMatch(in: s, range: ca) == nil {
                        out.append(Diagnostic(line: line, path: path,
                                              message: "không khớp mẫu «\(mau)»"))
                    }
                } else {
                    out.append(Diagnostic(line: line, path: path,
                                          message: "schema có mẫu regex hỏng: «\(mau)»",
                                          unsupported: true))
                }
            }
        }

        if let map = value as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            for ten in (schema["required"] as? [String] ?? []) where map[ten] == nil {
                out.append(Diagnostic(line: line, path: noi(path, ten),
                                      message: "thiếu trường bắt buộc «\(ten)»"))
            }
            if schema["additionalProperties"] as? Bool == false {
                for ten in map.keys.sorted() where properties[ten] == nil {
                    out.append(Diagnostic(line: dong(of: noi(path, ten), index: index, bytes: bytes),
                                          path: noi(path, ten),
                                          message: "trường «\(ten)» không được khai trong schema"))
                }
            }
            for (ten, con) in properties.sorted(by: { $0.key < $1.key }) {
                guard let giaTri = map[ten], let conSchema = con as? [String: Any] else { continue }
                kiem(giaTri, conSchema, path: noi(path, ten),
                     index: index, bytes: bytes, into: &out)
            }
        }

        if let mang = value as? [Any], let itemSchema = schema["items"] as? [String: Any] {
            for (i, muc) in mang.enumerated() {
                kiem(muc, itemSchema, path: "\(path)[\(i)]",
                     index: index, bytes: bytes, into: &out)
            }
        }
    }

    // MARK: - Phụ

    /// Số dòng của một đường dẫn, tra bằng JSONPath của chính `JSONIndex`.
    ///
    /// ## Bản đầu SAI vì so hai định dạng khác nhau
    ///
    /// Nó so đường dẫn nội bộ (`retries`, `a.b[0]`) với `JSONIndex.path(of:)` vốn trả JSONPath
    /// (`$.retries`, `$.a.b[0]`) — không bao giờ khớp, nên MỌI lỗi rơi về dòng 0. Bài kiểm bắt
    /// được, và nó là đúng loại hỏng nguy hiểm: lỗi vẫn hiện ra, chỉ chỉ sai chỗ.
    ///
    /// Bản này quy đường dẫn nội bộ về JSONPath bằng CHÍNH luật của `JSONIndex` (`isPlainName`),
    /// nên hai bên không thể trôi khỏi nhau: khoá tiếng Việt được bọc `['…']` ở cả hai chỗ vì
    /// cùng một hàm quyết định.
    static func dong(of path: String, index: JSONIndex, bytes: [UInt8]) -> Int {
        guard !path.isEmpty, !index.isEmpty else { return 0 }
        let can = jsonPath(path)
        for i in index.nodes.indices where index.path(of: i) == can {
            return bytes[..<index.nodes[i].range.lowerBound].filter { $0 == 0x0A }.count
        }
        return 0
    }

    /// `retries` → `$.retries` · `a.b[0]` → `$.a.b[0]` · `[1]` → `$[1]`
    static func jsonPath(_ path: String) -> String {
        var out = "$"
        var i = path.startIndex
        while i < path.endIndex {
            if path[i] == "[" {
                guard let j = path[i...].firstIndex(of: "]") else { break }
                out += String(path[i ... j])
                i = path.index(after: j)
                continue
            }
            if path[i] == "." { i = path.index(after: i); continue }
            let j = path[i...].firstIndex { $0 == "." || $0 == "[" } ?? path.endIndex
            let khoa = String(path[i ..< j])
            out += JSONIndex.isPlainName(khoa)
                ? ".\(khoa)"
                : "['\(khoa.replacingOccurrences(of: "\'", with: "\\\'"))']"
            i = j
        }
        return out
    }

    static func noi(_ path: String, _ key: String) -> String {
        path.isEmpty ? key : "\(path).\(key)"
    }

    static func soCua(_ value: Any) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    /// `integer` khác `number`: một schema đòi `integer` mà nhận `3.5` là sai, và bỏ qua khác
    /// biệt ấy là bỏ qua đúng loại lỗi hay gặp nhất trong định nghĩa tool.
    static func hopKieu(_ value: Any, _ ten: String) -> Bool {
        switch ten {
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return value is Bool || (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } == true
        case "integer":
            guard let d = soCua(value), !(value is String) else { return false }
            return d == d.rounded()
        case "number": return soCua(value) != nil && !(value is String)
        case "null": return value is NSNull
        default: return true          // kiểu lạ thì KHÔNG phán — im lặng đúng hơn đoán bừa.
        }
    }

    static func tenKieu(_ value: Any) -> String {
        if value is [String: Any] { return "object" }
        if value is [Any] { return "array" }
        if value is String { return "string" }
        if value is NSNull { return "null" }
        if let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return "boolean" }
        if soCua(value) != nil { return "number" }
        return "?"
    }
}
