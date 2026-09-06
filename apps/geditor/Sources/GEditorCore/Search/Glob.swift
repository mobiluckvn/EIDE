import Foundation

/// Khớp tên file theo mẫu shell — bộ lọc "Filters" của hộp Find in Files (FR-SRCH-106).
///
/// Cố ý KHÔNG dùng `NSPredicate`/`fnmatch`: cả hai kéo theo hành vi phụ thuộc locale và
/// hệ thống, trong khi bộ lọc tìm kiếm phải cho cùng kết quả trên mọi máy.
///
/// Hỗ trợ `*` (không hoặc nhiều ký tự), `?` (đúng một ký tự), `[abc]` và `[a-z]`, phủ định
/// bằng `[!abc]` hoặc `[^abc]`. So khớp KHÔNG phân biệt hoa thường vì hệ thống file mặc định
/// của macOS cũng vậy — `*.TXT` phải bắt được `ghi-chú.txt`.
///
/// Mẫu khớp với TÊN file, không phải đường dẫn: `*.csv` bắt mọi file .csv ở mọi độ sâu. Lọc
/// theo thư mục là việc của `excludeDirectories`, tách bạch cho khỏi nhập nhằng.
public enum Glob {

    private enum Token {
        case literal(Character)
        case any                       // ?
        case star                      // *
        case set(Set<Character>, negated: Bool)
    }

    /// Tên file có khớp `pattern` không.
    public static func matches(_ name: String, pattern: String) -> Bool {
        let tokens = compile(pattern.lowercased())
        return match(Array(name.lowercased()), tokens)
    }

    /// Khớp với BẤT KỲ mẫu nào trong danh sách. Danh sách rỗng = khớp tất cả.
    ///
    /// Quy ước "rỗng nghĩa là tất cả" cho phép bộ lọc mặc định là không lọc gì, đúng như
    /// người dùng mong đợi khi để trống ô Filters.
    public static func matchesAny(_ name: String, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return true }
        return patterns.contains { matches(name, pattern: $0) }
    }

    private static func compile(_ pattern: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(pattern)
        var index = 0

        while index < characters.count {
            switch characters[index] {
            case "*":
                // Gộp `**` thành một `*`: hai dấu sao liền nhau không thêm sức mạnh nào cho
                // việc khớp tên file, chỉ làm thuật toán quay lui nhiều lần vô ích.
                if case .star = tokens.last { } else { tokens.append(.star) }
                index += 1

            case "?":
                tokens.append(.any)
                index += 1

            case "[":
                if let (token, next) = parseSet(characters, from: index) {
                    tokens.append(token)
                    index = next
                } else {
                    // `[` không đóng: coi như ký tự thường thay vì báo lỗi — người dùng đang
                    // gõ dở trong ô lọc, không nên nổ vào mặt họ.
                    tokens.append(.literal("["))
                    index += 1
                }

            default:
                tokens.append(.literal(characters[index]))
                index += 1
            }
        }
        return tokens
    }

    private static func parseSet(_ characters: [Character], from start: Int) -> (Token, Int)? {
        var index = start + 1
        var negated = false
        if index < characters.count, characters[index] == "!" || characters[index] == "^" {
            negated = true
            index += 1
        }

        var members = Set<Character>()
        var isFirst = true
        while index < characters.count {
            let character = characters[index]
            // `]` ngay sau dấu mở là thành viên, không phải dấu đóng — quy ước của shell.
            if character == "]", !isFirst {
                return (.set(members, negated: negated), index + 1)
            }
            if index + 2 < characters.count, characters[index + 1] == "-", characters[index + 2] != "]",
               let lower = character.unicodeScalars.first?.value,
               let upper = characters[index + 2].unicodeScalars.first?.value,
               lower <= upper {
                for scalar in lower ... upper {
                    if let unicode = Unicode.Scalar(scalar) { members.insert(Character(unicode)) }
                }
                index += 3
            } else {
                members.insert(character)
                index += 1
            }
            isFirst = false
        }
        return nil
    }

    /// Khớp hai con trỏ có quay lui — chỉ nhớ MỘT vị trí `*` gần nhất.
    ///
    /// Đủ và tuyến tính cho mẫu tên file thực tế; thuật toán quy hoạch động đầy đủ chỉ cần
    /// khi mẫu có nhiều `*` lồng nhau kiểu bệnh lý, thứ không xuất hiện trong ô Filters.
    private static func match(_ name: [Character], _ tokens: [Token]) -> Bool {
        var nameIndex = 0
        var tokenIndex = 0
        var starToken = -1
        var starName = 0

        func accepts(_ token: Token, _ character: Character) -> Bool {
            switch token {
            case .literal(let expected): return expected == character
            case .any: return true
            case .star: return false
            case .set(let members, let negated): return members.contains(character) != negated
            }
        }

        while nameIndex < name.count {
            if tokenIndex < tokens.count, case .star = tokens[tokenIndex] {
                starToken = tokenIndex
                starName = nameIndex
                tokenIndex += 1
            } else if tokenIndex < tokens.count, accepts(tokens[tokenIndex], name[nameIndex]) {
                tokenIndex += 1
                nameIndex += 1
            } else if starToken >= 0 {
                // Quay lui: cho `*` nuốt thêm một ký tự.
                tokenIndex = starToken + 1
                starName += 1
                nameIndex = starName
            } else {
                return false
            }
        }

        while tokenIndex < tokens.count, case .star = tokens[tokenIndex] {
            tokenIndex += 1
        }
        return tokenIndex == tokens.count
    }
}
