import Foundation

/// Lỗi cú pháp JSON, kèm chỗ đứng của nó (FR-FMT-504).
public struct JSONIssue: Error, Equatable, Sendable {
    public let message: String
    /// Offset byte trong tài liệu — đủ để đưa con nháy tới nơi.
    public let offset: Int
    public let line: Int
    public let column: Int

    public var description: String { "Dòng \(line), cột \(column): \(message)" }
}

/// Công cụ JSON: định dạng, thu gọn, kiểm lỗi, sắp xếp khóa (FR-FMT-504).
///
/// **Không dùng `JSONSerialization`.** Nó bỏ THỨ TỰ KHÓA (trả về `Dictionary`), và nó viết lại
/// số qua `Double`: `1.0` thành `1`, `1e3` thành `1000`, và một mã số dài mười tám chữ số thì
/// mất chữ số cuối. Một công cụ "định dạng lại" mà đổi dữ liệu là thứ không ai tha thứ được —
/// người dùng bấm nút ấy để file DỄ ĐỌC HƠN, không phải để nó khác đi.
///
/// Nên ở đây tự đọc, và giữ nguyên văn bản gốc của mỗi số, mỗi chuỗi.
public enum JSONTool {

    // MARK: - Cây giữ nguyên văn

    /// Một giá trị JSON, giữ NGUYÊN VĂN phần vô hướng.
    indirect enum Value {
        /// Chuỗi, còn nguyên dấu nháy và escape như trong nguồn.
        case string(String)
        /// Số, còn nguyên như người dùng viết: `1.0` vẫn là `1.0`, `1e3` vẫn là `1e3`.
        case number(String)
        case bool(Bool)
        case null
        case array([Value])
        /// Object giữ thứ tự khóa như trong nguồn.
        case object([(key: String, value: Value)])
    }

    // MARK: - Kiểm lỗi

    /// Kiểm cú pháp; `nil` nghĩa là hợp lệ.
    public static func validate(_ text: String) -> JSONIssue? {
        var parser = Parser(text: text)
        do {
            _ = try parser.parseDocument()
            return nil
        } catch let issue as JSONIssue {
            return issue
        } catch {
            return JSONIssue(message: "Không đọc được", offset: 0, line: 1, column: 1)
        }
    }

    // MARK: - Định dạng

    /// Kết quả một phép biến đổi.
    public enum Outcome: Equatable {
        case changed(String)
        /// Đã đúng dạng rồi — không sinh sửa đổi nào.
        case unchanged
        case invalid(JSONIssue)
    }

    /// Trải rộng cho dễ đọc.
    ///
    /// - Parameter indent: số dấu cách mỗi cấp; 0 nghĩa là dùng Tab.
    public static func format(_ text: String, indent: Int = 2) -> Outcome {
        transform(text, indent: indent, sortKeys: false, recursive: false)
    }

    /// Thu gọn về một dòng, bỏ mọi khoảng trắng thừa.
    public static func minify(_ text: String) -> Outcome {
        transform(text, indent: nil, sortKeys: false, recursive: false)
    }

    /// Sắp xếp khóa theo thứ tự chữ cái.
    ///
    /// - Parameter recursive: sắp cả các object lồng bên trong.
    ///
    /// Sắp xếp khóa ĐỔI dữ liệu theo nghĩa của Git — cả file thành một khối thay đổi. Đáng
    /// làm khi người ta muốn so hai file cấu hình, nhưng phải là việc họ chủ động chọn, nên nó
    /// là một lệnh riêng chứ không phải một tùy chọn nấp trong nút "Định dạng".
    public static func sortKeys(_ text: String, indent: Int = 2, recursive: Bool = true) -> Outcome {
        transform(text, indent: indent, sortKeys: true, recursive: recursive)
    }

    private static func transform(
        _ text: String, indent: Int?, sortKeys: Bool, recursive: Bool
    ) -> Outcome {
        var parser = Parser(text: text)
        let value: Value
        do {
            value = try parser.parseDocument()
        } catch let issue as JSONIssue {
            return .invalid(issue)
        } catch {
            return .invalid(JSONIssue(message: "Không đọc được", offset: 0, line: 1, column: 1))
        }

        let sorted = sortKeys ? sortedValue(value, recursive: recursive) : value
        var out = ""
        write(sorted, indent: indent, level: 0, into: &out)
        if indent != nil { out += "\n" }
        return out == text ? .unchanged : .changed(out)
    }

    private static func sortedValue(_ value: Value, recursive: Bool) -> Value {
        switch value {
        case let .object(pairs):
            let sorted = pairs.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            guard recursive else { return .object(sorted) }
            return .object(sorted.map { ($0.key, sortedValue($0.value, recursive: true)) })
        case let .array(items):
            // Mảng KHÔNG bị sắp xếp: thứ tự phần tử trong mảng là dữ liệu, không phải cách
            // trình bày. Chỉ đi vào bên trong để sắp các object nằm trong đó.
            return recursive ? .array(items.map { sortedValue($0, recursive: true) }) : value
        default:
            return value
        }
    }

    /// Viết ra văn bản. `indent == nil` là thu gọn.
    private static func write(_ value: Value, indent: Int?, level: Int, into out: inout String) {
        func newline(_ level: Int) {
            guard let indent else { return }
            out += "\n"
            out += indent == 0
                ? String(repeating: "\t", count: level)
                : String(repeating: " ", count: indent * level)
        }

        switch value {
        case let .string(raw): out += raw
        case let .number(raw): out += raw
        case let .bool(flag): out += flag ? "true" : "false"
        case .null: out += "null"

        case let .array(items):
            guard !items.isEmpty else { return out += "[]" }
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                newline(level + 1)
                write(item, indent: indent, level: level + 1, into: &out)
            }
            newline(level)
            out += "]"

        case let .object(pairs):
            guard !pairs.isEmpty else { return out += "{}" }
            out += "{"
            for (index, pair) in pairs.enumerated() {
                if index > 0 { out += "," }
                newline(level + 1)
                out += pair.key
                out += indent == nil ? ":" : ": "
                write(pair.value, indent: indent, level: level + 1, into: &out)
            }
            newline(level)
            out += "}"
        }
    }

    // MARK: - Bộ đọc

    /// Bộ đọc JSON theo RFC 8259, làm việc trên byte.
    ///
    /// Thông điệp lỗi viết cho NGƯỜI ĐỌC file, không phải cho người viết parser: "thiếu dấu
    /// phẩy giữa hai mục" nói được phải sửa gì, còn "unexpected token" thì không.
    struct Parser {
        private let bytes: [UInt8]
        private var index = 0

        init(text: String) { bytes = Array(text.utf8) }

        mutating func parseDocument() throws -> Value {
            skipWhitespace()
            guard index < bytes.count else { throw issue("File rỗng, không có giá trị JSON nào") }
            let value = try parseValue()
            skipWhitespace()
            guard index >= bytes.count else {
                throw issue("Còn thừa nội dung sau giá trị JSON đã kết thúc")
            }
            return value
        }

        private mutating func parseValue() throws -> Value {
            skipWhitespace()
            guard index < bytes.count else { throw issue("Thiếu giá trị") }

            switch bytes[index] {
            case UInt8(ascii: "{"): return try parseObject()
            case UInt8(ascii: "["): return try parseArray()
            case UInt8(ascii: "\""): return .string(try parseString())
            case UInt8(ascii: "t"): try expect("true"); return .bool(true)
            case UInt8(ascii: "f"): try expect("false"); return .bool(false)
            case UInt8(ascii: "n"): try expect("null"); return .null
            default: return .number(try parseNumber())
            }
        }

        private mutating func parseObject() throws -> Value {
            index += 1                       // '{'
            var pairs: [(key: String, value: Value)] = []
            skipWhitespace()
            if peek() == UInt8(ascii: "}") { index += 1; return .object(pairs) }

            while true {
                skipWhitespace()
                guard peek() == UInt8(ascii: "\"") else {
                    throw issue("Khóa của object phải là chuỗi trong dấu nháy kép")
                }
                let key = try parseString()
                skipWhitespace()
                guard peek() == UInt8(ascii: ":") else { throw issue("Thiếu dấu hai chấm sau khóa") }
                index += 1
                pairs.append((key, try parseValue()))
                skipWhitespace()

                switch peek() {
                case UInt8(ascii: ","):
                    index += 1
                    skipWhitespace()
                    // Dấu phẩy thừa trước `}` là lỗi hay gặp nhất khi sửa tay JSON, và nói
                    // đúng tên nó ra thì người dùng sửa trong ba giây.
                    if peek() == UInt8(ascii: "}") { throw issue("Dấu phẩy thừa trước dấu }") }
                case UInt8(ascii: "}"):
                    index += 1
                    return .object(pairs)
                default:
                    throw issue("Thiếu dấu phẩy giữa hai mục của object")
                }
            }
        }

        private mutating func parseArray() throws -> Value {
            index += 1                       // '['
            var items: [Value] = []
            skipWhitespace()
            if peek() == UInt8(ascii: "]") { index += 1; return .array(items) }

            while true {
                items.append(try parseValue())
                skipWhitespace()
                switch peek() {
                case UInt8(ascii: ","):
                    index += 1
                    skipWhitespace()
                    if peek() == UInt8(ascii: "]") { throw issue("Dấu phẩy thừa trước dấu ]") }
                case UInt8(ascii: "]"):
                    index += 1
                    return .array(items)
                default:
                    throw issue("Thiếu dấu phẩy giữa hai phần tử của mảng")
                }
            }
        }

        /// Đọc chuỗi, trả về NGUYÊN VĂN kể cả dấu nháy và escape.
        private mutating func parseString() throws -> String {
            let start = index
            index += 1                       // '"'
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "\\") {
                    index += 2               // bỏ qua ký tự được escape
                    continue
                }
                if byte == UInt8(ascii: "\"") {
                    index += 1
                    return String(decoding: bytes[start ..< index], as: UTF8.self)
                }
                if byte == 0x0A { throw issue("Chuỗi chưa đóng trước khi hết dòng") }
                index += 1
            }
            throw issue("Chuỗi chưa đóng trước khi hết file")
        }

        private mutating func parseNumber() throws -> String {
            let start = index
            if peek() == UInt8(ascii: "-") { index += 1 }
            var digits = 0
            while let byte = peek(), byte >= 0x30, byte <= 0x39 { index += 1; digits += 1 }
            guard digits > 0 else { throw issue("Không phải giá trị JSON hợp lệ") }

            if peek() == UInt8(ascii: ".") {
                index += 1
                var fraction = 0
                while let byte = peek(), byte >= 0x30, byte <= 0x39 { index += 1; fraction += 1 }
                guard fraction > 0 else { throw issue("Thiếu chữ số sau dấu chấm thập phân") }
            }
            if let byte = peek(), byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E") {
                index += 1
                if let sign = peek(), sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") {
                    index += 1
                }
                var exponent = 0
                while let byte = peek(), byte >= 0x30, byte <= 0x39 { index += 1; exponent += 1 }
                guard exponent > 0 else { throw issue("Thiếu chữ số của phần mũ") }
            }
            return String(decoding: bytes[start ..< index], as: UTF8.self)
        }

        private mutating func expect(_ word: String) throws {
            let expected = Array(word.utf8)
            guard index + expected.count <= bytes.count,
                  Array(bytes[index ..< (index + expected.count)]) == expected
            else { throw issue("Không phải giá trị JSON hợp lệ") }
            index += expected.count
        }

        private func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }

        private mutating func skipWhitespace() {
            while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        /// Dựng lỗi kèm dòng và cột — đếm lại từ đầu, nhưng chỉ một lần cho mỗi lần đọc file.
        private func issue(_ message: String) -> JSONIssue {
            var line = 1
            var column = 1
            for byte in bytes[0 ..< min(index, bytes.count)] {
                if byte == 0x0A { line += 1; column = 1 } else { column += 1 }
            }
            return JSONIssue(message: message, offset: index, line: line, column: column)
        }
    }
}
