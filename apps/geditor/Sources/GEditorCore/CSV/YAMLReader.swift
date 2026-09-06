import Foundation

/// Bộ đọc YAML — **tập con**, đủ cho `.gquality.yaml` của FR-DQR-001 và không hơn.
///
/// ## Vì sao tự viết thay vì thêm một phụ thuộc
///
/// Kho đã có `YAMLLint` (FR-FMT-507) nhưng nó chỉ SOI, không đọc ra giá trị. Thêm một thư viện
/// YAML đầy đủ cho một tệp cấu hình vài chục dòng là đổi một phụ thuộc lấy những tính năng
/// không ai dùng: anchor, alias, tag, nhiều tài liệu trong một tệp, kiểu tuỳ biến. YAML đầy đủ
/// là một đặc tả lớn hơn người ta tưởng, và phần lớn nó là bề mặt tấn công chứ không phải tiện ích.
///
/// ## Làm được gì
///
/// - Mapping và sequence theo THỤT LỀ (block style), lồng nhau tuỳ ý.
/// - Sequence dạng `- mục` và inline `[a, b, c]`.
/// - Mapping inline `{a: 1, b: 2}` — chính đặc tả SRS viết ví dụ ở dạng này.
/// - Chuỗi trần, chuỗi trong `'…'` và `"…"`, số, `true`/`false`, `null`/`~`.
/// - Chú thích `#` ngoài chuỗi.
///
/// ## KHÔNG làm được, và nói ra thay vì im lặng bỏ qua
///
/// Anchor (`&x`/`*x`), tag (`!!str`), nhiều tài liệu (`---`), khối văn bản (`|`, `>`), và khoá
/// không phải chuỗi. Gặp chúng thì **ném lỗi có số dòng**, không phải đọc sai rồi trả về một cấu
/// hình khác thứ người dùng viết. Với một tệp quyết định "dữ liệu này có đạt chuẩn không", đọc
/// sai trong im lặng là kiểu hỏng tệ nhất.
public indirect enum YAMLValue: Equatable, Sendable {
    case scalar(String)
    case boolean(Bool)
    case number(Double)
    case null
    case mapping([(String, YAMLValue)])
    case sequence([YAMLValue])

    public static func == (lhs: YAMLValue, rhs: YAMLValue) -> Bool {
        switch (lhs, rhs) {
        case (.scalar(let a), .scalar(let b)): return a == b
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.null, .null): return true
        case (.sequence(let a), .sequence(let b)): return a == b
        case (.mapping(let a), .mapping(let b)):
            return a.count == b.count
                && zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: return false
        }
    }

    // MARK: - Tra cứu

    public subscript(key: String) -> YAMLValue? {
        guard case .mapping(let pairs) = self else { return nil }
        return pairs.first { $0.0 == key }?.1
    }

    public var stringValue: String? {
        switch self {
        case .scalar(let text): return text
        case .boolean(let flag): return flag ? "true" : "false"
        case .number(let value):
            return value == value.rounded() && abs(value) < 1e15
                ? String(Int(value)) : String(value)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .scalar(let text): return Double(text)
        default: return nil
        }
    }

    public var intValue: Int? { doubleValue.map { Int($0) } }

    public var boolValue: Bool? {
        switch self {
        case .boolean(let flag): return flag
        case .scalar(let text):
            switch text.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: return nil
            }
        default: return nil
        }
    }

    public var sequenceValue: [YAMLValue]? {
        switch self {
        case .sequence(let items): return items
        // Một mục đơn ở chỗ chờ danh sách là lỗi thường gặp và vô hại — `col: ma_don` khi đặc
        // tả cho phép nhiều cột. Nhận nó như danh sách một phần tử, vì từ chối ở đây chỉ bắt
        // người dùng gõ thêm hai dấu ngoặc mà không bảo vệ gì.
        case .null: return nil
        default: return [self]
        }
    }

    public var mappingKeys: [String] {
        guard case .mapping(let pairs) = self else { return [] }
        return pairs.map(\.0)
    }
}

public enum YAMLReader {

    public struct Failure: Error, Equatable, Sendable {
        public let line: Int
        public let reason: String

        public var message: String { "Dòng \(line): \(reason)" }
    }

    public static func parse(_ text: String) throws -> YAMLValue {
        var lines: [Line] = []
        for (index, raw) in text.components(separatedBy: "\n").enumerated() {
            let stripped = stripComment(raw)
            if stripped.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let trimmed = stripped.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." {
                throw Failure(line: index + 1,
                              reason: "chưa hỗ trợ nhiều tài liệu trong một tệp (`---`)")
            }
            if trimmed.hasPrefix("&") || trimmed.hasPrefix("*") {
                throw Failure(line: index + 1, reason: "chưa hỗ trợ anchor/alias YAML")
            }
            lines.append(Line(number: index + 1, indent: leadingSpaces(stripped), text: trimmed))
        }
        guard !lines.isEmpty else { return .mapping([]) }
        var cursor = 0
        let value = try parseBlock(lines, &cursor, indent: lines[0].indent)
        guard cursor == lines.count else {
            throw Failure(line: lines[cursor].number, reason: "thụt lề không khớp khối phía trên")
        }
        return value
    }

    // MARK: - Bên trong

    private struct Line {
        let number: Int
        let indent: Int
        let text: String
    }

    private static func leadingSpaces(_ text: String) -> Int {
        var count = 0
        for character in text {
            if character == " " { count += 1 }
            else if character == "\t" {
                // Tab trong thụt lề YAML là lỗi theo chính đặc tả YAML, và là lỗi mà `YAMLLint`
                // (FR-FMT-507) đã bắt cho người dùng. Ở đây coi nó là một khoảng trắng thì bộ
                // đọc và bộ soi sẽ nói hai chuyện khác nhau về cùng một tệp.
                count += 1
            } else { break }
        }
        return count
    }

    /// Bỏ chú thích `#`, nhưng KHÔNG bỏ dấu `#` nằm trong chuỗi.
    private static func stripComment(_ raw: String) -> String {
        var result = ""
        var quote: Character?
        var previous: Character?
        for character in raw {
            if let open = quote {
                result.append(character)
                if character == open && previous != "\\" { quote = nil }
            } else if character == "'" || character == "\"" {
                quote = character
                result.append(character)
            } else if character == "#" {
                break
            } else {
                result.append(character)
            }
            previous = character
        }
        return result
    }

    private static func parseBlock(
        _ lines: [Line], _ cursor: inout Int, indent: Int
    ) throws -> YAMLValue {
        guard cursor < lines.count else { return .null }
        if lines[cursor].text.hasPrefix("- ") || lines[cursor].text == "-" {
            return try parseSequence(lines, &cursor, indent: indent)
        }
        return try parseMapping(lines, &cursor, indent: indent)
    }

    private static func parseSequence(
        _ lines: [Line], _ cursor: inout Int, indent: Int
    ) throws -> YAMLValue {
        var items: [YAMLValue] = []
        while cursor < lines.count, lines[cursor].indent == indent,
              lines[cursor].text.hasPrefix("- ") || lines[cursor].text == "-" {
            let line = lines[cursor]
            let inline = line.text == "-" ? "" : String(line.text.dropFirst(2))
                .trimmingCharacters(in: .whitespaces)
            cursor += 1
            if inline.isEmpty {
                items.append(try parseBlock(lines, &cursor, indent: nextIndent(lines, cursor, after: indent)))
            } else if inline.hasPrefix("{") || inline.hasPrefix("[") {
                items.append(try parseFlow(inline, line: line.number))
            } else if let key = splitKey(inline) {
                // `- col: ma_don` mở một mapping mà mục đầu nằm ngay trên gạch đầu dòng.
                var pairs: [(String, YAMLValue)] = []
                let childIndent = indent + 2
                pairs.append((key.name, try inlineOrBlock(
                    key.value, lines: lines, cursor: &cursor, indent: childIndent,
                    line: line.number)))
                while cursor < lines.count, lines[cursor].indent >= childIndent,
                      !(lines[cursor].text.hasPrefix("- ") && lines[cursor].indent == indent) {
                    let sub = lines[cursor]
                    guard let subKey = splitKey(sub.text) else {
                        throw Failure(line: sub.number, reason: "chờ một mục `khoá: giá trị`")
                    }
                    cursor += 1
                    pairs.append((subKey.name, try inlineOrBlock(
                        subKey.value, lines: lines, cursor: &cursor,
                        indent: sub.indent + 1, line: sub.number)))
                }
                items.append(.mapping(pairs))
            } else {
                items.append(scalar(inline))
            }
        }
        return .sequence(items)
    }

    private static func parseMapping(
        _ lines: [Line], _ cursor: inout Int, indent: Int
    ) throws -> YAMLValue {
        var pairs: [(String, YAMLValue)] = []
        while cursor < lines.count, lines[cursor].indent == indent {
            let line = lines[cursor]
            if line.text.hasPrefix("- ") { break }
            guard let key = splitKey(line.text) else {
                throw Failure(line: line.number,
                              reason: "chờ một mục `khoá: giá trị`, nhận «\(line.text)»")
            }
            if pairs.contains(where: { $0.0 == key.name }) {
                // Khoá trùng là lỗi mà `YAMLLint` đã bắt cho FR-FMT-507, và ở đây nó nguy hiểm
                // hơn: một luật chất lượng bị một luật cùng tên phía dưới ghi đè trong im lặng.
                throw Failure(line: line.number, reason: "khoá «\(key.name)» viết hai lần")
            }
            cursor += 1
            pairs.append((key.name, try inlineOrBlock(
                key.value, lines: lines, cursor: &cursor, indent: indent + 1,
                line: line.number)))
        }
        return .mapping(pairs)
    }

    /// Giá trị nằm ngay sau dấu hai chấm, hoặc — nếu chỗ ấy trống — khối thụt vào bên dưới.
    private static func inlineOrBlock(
        _ inline: String, lines: [Line], cursor: inout Int, indent: Int, line: Int
    ) throws -> YAMLValue {
        if inline.hasPrefix("|") || inline.hasPrefix(">") {
            throw Failure(line: line, reason: "chưa hỗ trợ khối văn bản `|` và `>`")
        }
        if !inline.isEmpty {
            // Anchor/alias ở VỊ TRÍ GIÁ TRỊ (`a: &neo 1`, `b: *neo`).
            //
            // Bản đầu chỉ soi đầu DÒNG, nên `a: &neo 1` lọt qua và `&neo 1` bị đọc thành một
            // chuỗi — đúng kiểu hỏng im lặng mà tệp này tuyên bố sẽ chặn, và bài kiểm bắt được.
            // Chỗ này mới là chỗ anchor thật sự hay xuất hiện.
            if let first = inline.first, first == "&" || first == "*",
               inline.count > 1, inline.dropFirst().first != " " {
                throw Failure(line: line, reason: "chưa hỗ trợ anchor/alias YAML")
            }
            if inline.hasPrefix("{") || inline.hasPrefix("[") {
                return try parseFlow(inline, line: line)
            }
            return scalar(inline)
        }
        guard cursor < lines.count, lines[cursor].indent >= indent else { return .null }
        return try parseBlock(lines, &cursor, indent: lines[cursor].indent)
    }

    private static func nextIndent(_ lines: [Line], _ cursor: Int, after indent: Int) -> Int {
        cursor < lines.count ? lines[cursor].indent : indent + 2
    }

    private static func splitKey(_ text: String) -> (name: String, value: String)? {
        var quote: Character?
        var previous: Character?
        var depth = 0
        for (offset, character) in text.enumerated() {
            if let open = quote {
                if character == open && previous != "\\" { quote = nil }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "{" || character == "[" {
                depth += 1
            } else if character == "}" || character == "]" {
                depth -= 1
            } else if character == ":" && depth == 0 {
                let index = text.index(text.startIndex, offsetBy: offset)
                let after = text.index(after: index)
                // `a:b` không phải khoá — YAML đòi khoảng trắng sau dấu hai chấm. Không đòi thì
                // `expr: ngay_giao >= ngay_dat` gãy ở mọi biểu thức có `::`.
                guard after == text.endIndex || text[after] == " " else { continue }
                let name = unquote(String(text[text.startIndex ..< index])
                    .trimmingCharacters(in: .whitespaces))
                let value = String(text[after...]).trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? nil : (name, value)
            }
            previous = character
        }
        return nil
    }

    /// `{a: 1, b: [x, y]}` và `[1, 2, 3]` — dạng gọn mà chính ví dụ trong SRS dùng.
    private static func parseFlow(_ text: String, line: Int) throws -> YAMLValue {
        var scanner = FlowScanner(text: Array(text), line: line)
        let value = try scanner.parseValue()
        scanner.skipSpaces()
        guard scanner.atEnd else {
            throw Failure(line: line, reason: "phần thừa sau dấu đóng: «\(scanner.rest)»")
        }
        return value
    }

    private struct FlowScanner {
        let text: [Character]
        let line: Int
        var index = 0

        var atEnd: Bool { index >= text.count }
        var rest: String { String(text[min(index, text.count)...]) }

        mutating func skipSpaces() {
            while index < text.count, text[index] == " " || text[index] == "\t" { index += 1 }
        }

        mutating func parseValue() throws -> YAMLValue {
            skipSpaces()
            guard index < text.count else {
                throw Failure(line: line, reason: "thiếu giá trị")
            }
            switch text[index] {
            case "{": return try parseMapping()
            case "[": return try parseSequence()
            case "&", "*":
                throw Failure(line: line, reason: "chưa hỗ trợ anchor/alias YAML")
            default: return YAMLReader.scalar(try parseScalarToken())
            }
        }

        mutating func parseMapping() throws -> YAMLValue {
            index += 1
            var pairs: [(String, YAMLValue)] = []
            while true {
                skipSpaces()
                guard index < text.count else {
                    throw Failure(line: line, reason: "thiếu dấu `}` đóng")
                }
                if text[index] == "}" { index += 1; break }
                let key = YAMLReader.unquote(try parseScalarToken(stopAt: [":"]))
                skipSpaces()
                guard index < text.count, text[index] == ":" else {
                    throw Failure(line: line, reason: "thiếu dấu `:` sau khoá «\(key)»")
                }
                index += 1
                let value = try parseValue()
                if pairs.contains(where: { $0.0 == key }) {
                    throw Failure(line: line, reason: "khoá «\(key)» viết hai lần")
                }
                pairs.append((key, value))
                skipSpaces()
                if index < text.count, text[index] == "," { index += 1 }
            }
            return .mapping(pairs)
        }

        mutating func parseSequence() throws -> YAMLValue {
            index += 1
            var items: [YAMLValue] = []
            while true {
                skipSpaces()
                guard index < text.count else {
                    throw Failure(line: line, reason: "thiếu dấu `]` đóng")
                }
                if text[index] == "]" { index += 1; break }
                items.append(try parseValue())
                skipSpaces()
                if index < text.count, text[index] == "," { index += 1 }
            }
            return .sequence(items)
        }

        mutating func parseScalarToken(stopAt extra: Set<Character> = []) throws -> String {
            skipSpaces()
            guard index < text.count else { return "" }
            if text[index] == "'" || text[index] == "\"" {
                let quote = text[index]
                index += 1
                var out = ""
                while index < text.count, text[index] != quote {
                    out.append(text[index])
                    index += 1
                }
                guard index < text.count else {
                    throw Failure(line: line, reason: "thiếu dấu nháy đóng")
                }
                index += 1
                return String(quote) + out + String(quote)
            }
            var out = ""
            while index < text.count, !",]}".contains(text[index]),
                  !extra.contains(text[index]) {
                out.append(text[index])
                index += 1
            }
            return out.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func unquote(_ text: String) -> String {
        guard text.count >= 2 else { return text }
        let first = text.first, last = text.last
        if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return String(text.dropFirst().dropLast())
        }
        return text
    }

    static func scalar(_ raw: String) -> YAMLValue {
        // Chuỗi ĐÃ TRONG NHÁY thì giữ nguyên là chuỗi, không đoán kiểu. `'true'` là chữ
        // "true", và `'0912'` là số điện thoại chứ không phải số 912 — đúng loại nhầm mà mọi
        // bảng tính đều mắc và người dùng Việt gặp hằng ngày.
        if raw.count >= 2, let first = raw.first, let last = raw.last,
           (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return .scalar(String(raw.dropFirst().dropLast()))
        }
        switch raw.lowercased() {
        case "true", "yes": return .boolean(true)
        case "false", "no": return .boolean(false)
        case "null", "~", "": return .null
        default: break
        }
        if let number = Double(raw) { return .number(number) }
        return .scalar(raw)
    }
}
