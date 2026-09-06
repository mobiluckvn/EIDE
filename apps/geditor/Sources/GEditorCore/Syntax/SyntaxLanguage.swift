import Foundation
import TreeSitter

/// Hai mươi ngôn ngữ của Phase 1 (FR-FMT-501).
///
/// Mười bảy grammar biên dịch TĨNH vào binary (xem `GEditorTreeSitter.h`). Ba grammar nặng
/// nhất — C++, C#, Ruby — nằm trong một dylib cạnh binary, nạp bằng `dlopen` lần đầu người dùng
/// mở file thuộc ba ngôn ngữ ấy; xem `GrammarLibrary` và ADR-08 để biết vì sao.
public enum SyntaxLanguage: String, CaseIterable, Sendable {
    case bash, c, cpp, csharp, css, go, html, java, javascript, json
    case lua, php, python, regex, ruby, rust, toml, typescript, xml, yaml

    /// Tên hiển thị ở thanh trạng thái.
    public var displayName: String {
        switch self {
        case .bash: return "Shell"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .css: return "CSS"
        case .go: return "Go"
        case .html: return "HTML"
        case .java: return "Java"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .lua: return "Lua"
        case .php: return "PHP"
        case .python: return "Python"
        case .regex: return "Regex"
        case .ruby: return "Ruby"
        case .rust: return "Rust"
        case .toml: return "TOML"
        case .typescript: return "TypeScript"
        case .xml: return "XML"
        case .yaml: return "YAML"
        }
    }

    /// Đuôi file dẫn tới ngôn ngữ này.
    ///
    /// Nhận dạng theo ĐUÔI FILE, không đoán theo nội dung. Đoán theo nội dung sai thì cả file
    /// bị tô nhầm và người dùng không hiểu vì sao; còn đuôi file thì họ sửa được, và sắp tới
    /// sẽ chọn tay được ở thanh trạng thái.
    public static let extensions: [String: SyntaxLanguage] = [
        "sh": .bash, "bash": .bash, "zsh": .bash, "command": .bash,
        "c": .c, "h": .c,
        "cpp": .cpp, "cc": .cpp, "cxx": .cpp, "hpp": .cpp, "hh": .cpp, "hxx": .cpp,
        "cs": .csharp,
        "css": .css,
        "go": .go,
        "html": .html, "htm": .html, "xhtml": .html,
        "java": .java,
        "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "json": .json, "jsonl": .json, "geojson": .json,
        "lua": .lua,
        "php": .php, "phtml": .php,
        "py": .python, "pyw": .python, "pyi": .python,
        "rb": .ruby, "rake": .ruby, "gemspec": .ruby,
        "rs": .rust,
        "toml": .toml,
        "ts": .typescript, "mts": .typescript, "cts": .typescript,
        "xml": .xml, "xsd": .xml, "xsl": .xml, "svg": .xml, "plist": .xml,
        "yaml": .yaml, "yml": .yaml,
    ]

    /// Tên file đặc biệt, không có đuôi.
    public static let fileNames: [String: SyntaxLanguage] = [
        "Makefile": .bash, "Dockerfile": .bash, "Gemfile": .ruby, "Rakefile": .ruby,
        ".bashrc": .bash, ".zshrc": .bash, ".profile": .bash,
    ]

    /// Ngôn ngữ của một đường dẫn; `nil` nghĩa là văn bản thuần.
    public static func detect(path: String) -> SyntaxLanguage? {
        let name = (path as NSString).lastPathComponent
        if let byName = fileNames[name] { return byName }
        let ext = (name as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return extensions[ext]
    }

    /// Con trỏ grammar. `nil` nếu grammar không nạp được — không bao giờ sập vì chuyện ấy.
    ///
    /// KHÔNG ngôn ngữ nào biên dịch tĩnh vào binary chính: cả hai mươi bảng tra nằm trong dylib
    /// nạp lười (`GrammarLibrary`, ADR-08 §2.13). Chúng chiếm 70,5 % binary đã liên kết và
    /// phiên nào chỉ mở `.txt` thì không dùng tới một byte nào của chúng.
    ///
    /// Một `switch` theo `self` từng đứng ở đây, mỗi nhánh gọi thẳng `tree_sitter_<tên>()`. Giờ
    /// không còn: một `switch` hai mươi nhánh cùng gọi một hàm là hai mươi chỗ để quên khi thêm
    /// ngôn ngữ thứ hai mươi mốt. Bảng tên nằm ở `GrammarLibrary.symbolNames`, một chỗ.
    ///
    /// `nil` chỉ có nghĩa là file hiện ra không màu — mở được file quan trọng hơn tô đúng nó.
    var handle: OpaquePointer? { GrammarLibrary.handle(rawValue) }

    var highlightQuerySource: String? { HighlightQueries.byLanguage[rawValue] }

    // MARK: - Dấu comment (FR-CORE-014)

    /// Dấu mở comment MỘT DÒNG. `nil` nghĩa là ngôn ngữ này không có kiểu comment ấy.
    ///
    /// XML/HTML là ví dụ: chúng chỉ có comment khối `<!-- -->`. Trả `nil` thay vì bịa ra một
    /// dấu gần đúng — chèn `//` vào một file XML là làm hỏng file.
    public var lineCommentToken: String? {
        switch self {
        case .bash, .python, .ruby, .toml, .yaml: return "#"
        case .lua: return "--"
        case .c, .cpp, .csharp, .go, .java, .javascript, .php, .rust, .typescript: return "//"
        case .css, .html, .json, .regex, .xml: return nil
        }
    }

    /// Cặp dấu comment KHỐI, dùng khi ngôn ngữ không có comment một dòng.
    public var blockCommentTokens: (open: String, close: String)? {
        switch self {
        case .css: return ("/*", "*/")
        case .html, .xml: return ("<!--", "-->")
        case .c, .cpp, .csharp, .go, .java, .javascript, .php, .rust, .typescript:
            return ("/*", "*/")
        case .lua: return ("--[[", "]]")
        case .bash, .json, .python, .regex, .ruby, .toml, .yaml: return nil
        }
    }

    /// Ký tự MỞ khối, dùng cho tự động thụt lề (FR-CORE-011).
    ///
    /// Python và YAML không có ở đây: khối của chúng mở bằng dấu hai chấm cuối dòng hoặc bằng
    /// chính phép thụt lề, và `blockOpeners` không diễn tả được điều đó — xem `opensBlock`.
    public var blockOpeners: Set<Character> {
        switch self {
        case .python, .yaml, .regex: return []
        default: return ["{", "[", "("]
        }
    }

    /// Dòng này có mở một khối mới không — tức dòng SAU nó phải thụt thêm một bậc.
    public func opensBlock(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        switch self {
        case .python:
            // Dấu hai chấm cuối dòng là thứ mở khối trong Python. Chú thích đứng sau nó thì
            // vẫn tính, nên cắt phần chú thích trước khi hỏi.
            let code = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            return code.trimmingCharacters(in: .whitespaces).hasSuffix(":")
        case .yaml:
            return trimmed.hasSuffix(":")
        default:
            guard let last = trimmed.last else { return false }
            return blockOpeners.contains(last)
        }
    }
}
