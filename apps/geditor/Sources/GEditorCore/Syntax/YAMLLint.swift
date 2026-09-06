import Foundation

/// Một cảnh báo của bộ lint YAML (FR-FMT-507).
public struct YAMLIssue: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        /// Khóa xuất hiện hai lần trong cùng một khối; `firstLine` là lần đầu.
        case duplicateKey(String, firstLine: Int)
        /// Thụt lề không khớp cấp nào đang mở.
        case badIndent(found: Int)
        /// Ký tự Tab ở phần thụt lề — YAML cấm hẳn.
        case tabIndent
    }

    public let kind: Kind
    public let line: Int
    public let offset: Int

    public var message: String {
        switch kind {
        case let .duplicateKey(key, firstLine):
            return "Khóa «\(key)» đã có ở dòng \(firstLine) — bản sau sẽ ĐÈ bản trước"
        case let .badIndent(found):
            return "Thụt lề \(found) dấu cách không khớp cấp nào đang mở"
        case .tabIndent:
            return "Dùng Tab để thụt lề — YAML chỉ chấp nhận dấu cách"
        }
    }

    public var description: String { "Dòng \(line): \(message)" }
}

/// Lint YAML cơ bản (FR-FMT-507).
///
/// Hai lỗi đáng bắt nhất, và cũng là hai lỗi mà trình soạn thảo im lặng thì người dùng mất
/// hàng giờ:
///
///  - **Khóa trùng.** YAML không báo lỗi; nó lặng lẽ lấy bản CUỐI. Một file cấu hình có hai
///    khóa `port` cách nhau bốn chục dòng sẽ chạy theo cái dưới, còn người sửa thì nhìn cái
///    trên và không hiểu vì sao thay đổi của mình không có tác dụng.
///  - **Tab trong phần thụt lề.** YAML cấm hẳn; trình phân tích báo lỗi ở một dòng khác hẳn
///    chỗ có Tab, nên đọc thông điệp gốc thường dẫn đi sai đường.
///
/// Đây là lint theo DÒNG, không phải một bộ phân tích YAML đầy đủ: nó không hiểu flow style
/// (`{a: 1}`), khối chữ nhiều dòng (`|`, `>`), hay neo (`&`, `*`). Với những cấu trúc ấy nó
/// im lặng thay vì đoán — báo nhầm một lỗi không có thật còn tệ hơn không báo, vì nó dạy người
/// dùng bỏ qua cảnh báo.
public enum YAMLLint {

    public static func check(_ text: String) -> [YAMLIssue] {
        var issues: [YAMLIssue] = []

        /// Các khối đang mở: (mức thụt lề, khóa đã gặp trong khối ấy).
        var stack: [(indent: Int, keys: [String: Int])] = [(0, [:])]
        var offset = 0
        var lineNumber = 0
        /// Khóa gần nhất có giá trị vô hướng ngay trên cùng dòng hay không.
        ///
        /// Một khóa đã có giá trị thì KHÔNG mở được khối con: `a: 1` rồi dòng sau thụt sâu hơn
        /// là thụt lề sai, chứ không phải một cấp mới. Thiếu chỗ này thì mọi dòng lệch vài dấu
        /// cách đều lặng lẽ thành "cấp con", và bộ lint im lặng đúng lúc cần lên tiếng.
        var lastKeyHadValue = false
        /// Đang trong khối chữ nhiều dòng (`|` hoặc `>`) thì mọi dòng bên trong là DỮ LIỆU.
        var literalIndent: Int?

        for line in text.components(separatedBy: "\n") {
            lineNumber += 1
            defer { offset += line.utf8.count + 1 }

            let indent = leadingSpaces(of: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Trong khối chữ: thoát ra khi gặp dòng có nội dung thụt lề nông hơn.
            if let open = literalIndent {
                if trimmed.isEmpty || indent > open { continue }
                literalIndent = nil
            }

            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
                continue
            }

            if line.prefix(while: { $0 == " " || $0 == "\t" }).contains("\t") {
                issues.append(YAMLIssue(kind: .tabIndent, line: lineNumber, offset: offset))
                continue
            }

            // Mục của danh sách (`- ...`): nó mở một khối riêng, và khóa bên trong mỗi mục là
            // độc lập với mục khác. Không theo dõi khóa trong danh sách — làm vậy sẽ báo trùng
            // cho hai mục hợp lệ có cùng cấu trúc.
            if trimmed.hasPrefix("-") {
                unwind(to: indent, stack: &stack)
                lastKeyHadValue = false
                continue
            }

            guard let key = mappingKey(of: trimmed) else {
                // Không phải cặp khóa-giá trị (giá trị nhiều dòng, flow style…). Im lặng.
                continue
            }

            unwind(to: indent, stack: &stack)

            if indent > stack[stack.count - 1].indent {
                guard !lastKeyHadValue else {
                    issues.append(YAMLIssue(
                        kind: .badIndent(found: indent), line: lineNumber, offset: offset
                    ))
                    continue
                }
                stack.append((indent, [:]))
            } else if indent != stack[stack.count - 1].indent {
                issues.append(YAMLIssue(kind: .badIndent(found: indent), line: lineNumber, offset: offset))
                continue
            }

            if let first = stack[stack.count - 1].keys[key] {
                issues.append(YAMLIssue(
                    kind: .duplicateKey(key, firstLine: first), line: lineNumber, offset: offset
                ))
            } else {
                stack[stack.count - 1].keys[key] = lineNumber
            }

            lastKeyHadValue = hasScalarValue(trimmed)
            // Giá trị rỗng sau dấu hai chấm nghĩa là khối con sắp mở ra ở dòng sau.
            if let marker = literalMarker(of: trimmed) {
                literalIndent = marker ? indent : nil
                lastKeyHadValue = false
            }
        }

        return issues
    }

    /// Đóng các khối sâu hơn mức thụt lề vừa gặp.
    private static func unwind(to indent: Int, stack: inout [(indent: Int, keys: [String: Int])]) {
        while stack.count > 1, indent < stack[stack.count - 1].indent {
            stack.removeLast()
        }
    }

    private static func leadingSpaces(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    /// Khóa của một cặp `khóa: giá trị`, hoặc `nil` nếu dòng không phải cặp ấy.
    ///
    /// Dấu hai chấm bên trong dấu nháy không tính: `ten: "12:30"` có một khóa, không phải hai.
    static func mappingKey(of trimmed: String) -> String? {
        var inSingle = false
        var inDouble = false
        var index = trimmed.startIndex

        while index < trimmed.endIndex {
            let character = trimmed[index]
            switch character {
            case "'" where !inDouble: inSingle.toggle()
            case "\"" where !inSingle: inDouble.toggle()
            case "#" where !inSingle && !inDouble:
                return nil                       // chú thích trước khi thấy dấu hai chấm
            case ":" where !inSingle && !inDouble:
                let next = trimmed.index(after: index)
                // `a:b` không phải cặp khóa-giá trị trong YAML; phải có khoảng trắng sau dấu.
                guard next == trimmed.endIndex || trimmed[next] == " " else { break }
                let key = String(trimmed[trimmed.startIndex ..< index])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                return key.isEmpty ? nil : key
            default: break
            }
            index = trimmed.index(after: index)
        }
        return nil
    }

    /// Dòng này có giá trị vô hướng ngay sau dấu hai chấm không.
    static func hasScalarValue(_ trimmed: String) -> Bool {
        guard let colon = trimmed.firstIndex(of: ":") else { return false }
        let rest = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        if rest.isEmpty || rest.hasPrefix("#") { return false }
        // `|` và `>` mở khối chữ, `&`/`*` là neo — không phải giá trị vô hướng gọn một dòng.
        return !rest.hasPrefix("|") && !rest.hasPrefix(">")
    }

    /// Dòng này có mở một khối chữ nhiều dòng (`|`, `>`) không.
    private static func literalMarker(of trimmed: String) -> Bool? {
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let rest = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("|") || rest.hasPrefix(">") else { return nil }
        return true
    }
}
