import Foundation

/// Thử và giải thích một biểu thức chính quy (FR-SRCH-110).
///
/// **Chạy trên MỘT MẨU văn bản do người dùng dán vào, không phải trên tài liệu.** Đó là cả
/// điểm của công cụ này: người ta viết regex sai vài lần trước khi viết đúng, và mỗi lần thử
/// trên tài liệu 200 MB là một lần chờ. Có trần `sampleLimit` để cái mẩu ấy đúng là một mẩu.
///
/// **Phần "giải thích" cố ý THÔ.** Nó tách biểu thức thành các mảnh và gọi tên từng mảnh, chứ
/// không dựng cây cú pháp PCRE2 đầy đủ. Một bộ giải thích đầy đủ là một dự án riêng, và với
/// người đang mò một pattern thì "`\d+` — một hoặc nhiều chữ số" đã trả lời đúng câu họ hỏi.
/// Chỗ nào không chắc thì nói "không rõ" chứ không đoán — đoán sai về regex là dẫn người ta
/// đi sai đường lâu hơn là im lặng.
public enum RegexTester {

    /// Cỡ lớn nhất của mẩu văn bản thử.
    public static let sampleLimit = 256 * 1024

    public struct Result: Equatable {
        public let matches: [SearchMatch]
        /// Văn bản của từng lần khớp và từng nhóm — để hiện thẳng, khỏi cắt lại.
        public let previews: [Preview]
        public let truncated: Bool

        public init(matches: [SearchMatch], previews: [Preview], truncated: Bool) {
            self.matches = matches
            self.previews = previews
            self.truncated = truncated
        }
    }

    public struct Preview: Equatable {
        public let whole: String
        /// `nil` = nhóm không tham gia lần khớp này, khác hẳn với chuỗi rỗng.
        public let groups: [String?]

        public init(whole: String, groups: [String?]) {
            self.whole = whole
            self.groups = groups
        }
    }

    /// Chạy `pattern` trên `sample`.
    ///
    /// Có trần số lần khớp: một pattern như `a*` khớp ở MỌI vị trí, và hiện 256 000 dòng kết
    /// quả thì panel không dùng được nữa. Cắt và NÓI RA là đã cắt.
    public static func run(
        pattern: String, options: SearchOptions, on sample: String, limit: Int = 500
    ) throws -> Result {
        let bytes = Array(sample.utf8.prefix(sampleLimit))
        let compiled = try PCRE2Pattern(pattern: pattern, options: options)

        var matches: [SearchMatch] = []
        var truncated = false
        try bytes.withUnsafeBytes { buffer in
            try compiled.enumerateMatches(in: buffer) { match in
                matches.append(match)
                if matches.count >= limit {
                    truncated = true
                    return false
                }
                return true
            }
        }

        let previews = matches.map { match in
            Preview(
                whole: text(bytes, match.range),
                groups: match.groups.map { $0.map { text(bytes, $0) } }
            )
        }
        return Result(matches: matches, previews: previews, truncated: truncated)
    }

    private static func text(_ bytes: [UInt8], _ range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= bytes.count, !range.isEmpty else { return "" }
        return String(decoding: bytes[range], as: UTF8.self)
    }

    // MARK: - Giải thích

    public struct Token: Equatable {
        /// Mẩu nguyên văn trong biểu thức.
        public let text: String
        /// Nói bằng tiếng Việt mẩu ấy làm gì. `nil` = không nhận ra.
        public let meaning: String?

        public init(text: String, meaning: String?) {
            self.text = text
            self.meaning = meaning
        }
    }

    static let escapes: [Character: String] = [
        "d": "một chữ số", "D": "một ký tự KHÔNG phải chữ số",
        "w": "một ký tự từ (chữ, số, gạch dưới)", "W": "một ký tự KHÔNG phải ký tự từ",
        "s": "một khoảng trắng", "S": "một ký tự KHÔNG phải khoảng trắng",
        "b": "biên của một từ", "B": "chỗ KHÔNG phải biên từ",
        "n": "xuống dòng", "t": "TAB", "r": "về đầu dòng",
        "A": "đầu chuỗi", "z": "cuối chuỗi", "Z": "cuối chuỗi, trước ký tự xuống dòng cuối",
        "K": "quên phần đã khớp trước đó",
    ]

    /// Tách biểu thức thành các mảnh có tên.
    ///
    /// KHÔNG phân tích lồng nhau. `(a|b)+` ra ba mảnh — nhóm, hoặc, lặp — chứ không ra một cây.
    /// Với người đang đọc lại pattern mình vừa viết thì đó là mức chi tiết đúng.
    public static func explain(_ pattern: String) -> [Token] {
        var tokens: [Token] = []
        var characters = Array(pattern)
        var index = 0

        func take(_ count: Int, _ meaning: String?) {
            let end = Swift.min(index + count, characters.count)
            tokens.append(Token(text: String(characters[index ..< end]), meaning: meaning))
            index = end
        }

        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\\":
                guard index + 1 < characters.count else { return tokens + [Token(text: "\\", meaning: nil)] }
                let next = characters[index + 1]
                take(2, escapes[next] ?? "ký tự «\(next)» hiểu theo nghĩa đen")
            case "[":
                // Lớp ký tự: nuốt tới `]` không bị escape. `]` ngay sau `[` hoặc `[^` là ký tự
                // thật chứ không đóng lớp — luật của POSIX mà PCRE2 giữ.
                var end = index + 1
                if end < characters.count, characters[end] == "^" { end += 1 }
                if end < characters.count, characters[end] == "]" { end += 1 }
                while end < characters.count, characters[end] != "]" {
                    if characters[end] == "\\" { end += 1 }
                    end += 1
                }
                let negated = index + 1 < characters.count && characters[index + 1] == "^"
                take(end - index + 1, negated ? "một ký tự KHÔNG thuộc tập này" : "một ký tự thuộc tập này")
            case "(":
                if matchAhead(characters, index, "(?:") { take(3, "nhóm không bắt giá trị") }
                else if matchAhead(characters, index, "(?=") { take(3, "phía sau phải là…") }
                else if matchAhead(characters, index, "(?!") { take(3, "phía sau KHÔNG được là…") }
                else if matchAhead(characters, index, "(?<=") { take(4, "phía trước phải là…") }
                else if matchAhead(characters, index, "(?<!") { take(4, "phía trước KHÔNG được là…") }
                else { take(1, "mở nhóm bắt giá trị") }
            case ")": take(1, "đóng nhóm")
            case "{":
                var end = index + 1
                while end < characters.count, characters[end] != "}" { end += 1 }
                take(end - index + 1, "lặp theo số lần chỉ định")
            case "*": take(1, "không lần nào hoặc nhiều lần")
            case "+": take(1, "một hoặc nhiều lần")
            case "?":
                // `?` ngay sau một lượng từ là "càng ít càng tốt", không phải "có cũng được".
                let previous = tokens.last?.text
                let lazy = previous == "*" || previous == "+" || previous == "?"
                    || (previous?.hasPrefix("{") ?? false)
                take(1, lazy ? "khớp càng ít càng tốt" : "có cũng được, không có cũng được")
            case ".": take(1, "một ký tự bất kỳ")
            case "^": take(1, "đầu dòng")
            case "$": take(1, "cuối dòng")
            case "|": take(1, "hoặc")
            default:
                // Gom các ký tự nghĩa đen liền nhau thành MỘT mảnh: tách từng chữ ra sẽ cho một
                // danh sách dài dằng dặc mà không nói thêm được gì.
                var end = index
                while end < characters.count, !"\\[](){}*+?.^$|".contains(characters[end]) { end += 1 }
                take(end - index, "khớp đúng chữ này")
            }
        }
        return tokens
    }

    private static func matchAhead(_ characters: [Character], _ index: Int, _ needle: String) -> Bool {
        let want = Array(needle)
        guard index + want.count <= characters.count else { return false }
        return Array(characters[index ..< (index + want.count)]) == want
    }
}
