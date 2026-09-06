import Foundation

/// Tệp prompt template và định nghĩa tool — FR-KNW-909.
///
/// Đặc tả: *"Highlight + folding cho prompt template (.md/.j2 với YAML frontmatter) và định
/// nghĩa tool JSON; validate theo JSON Schema do người dùng chỉ định."*
///
/// ## Frontmatter là một KHỐI GẤP ĐƯỢC, không phải một cách tô màu
///
/// Một prompt template thật hay có mười lăm dòng frontmatter (model, nhiệt độ, biến, ví dụ) rồi
/// mới tới phần chữ. Người sửa prompt cần nhìn phần chữ; người sửa cấu hình cần nhìn frontmatter.
/// Gấp được là cách rẻ nhất cho cả hai — và nó dùng lại `FoldRanges` chứ không dựng cơ chế mới.
public enum PromptFile {

    /// Đuôi tệp được coi là prompt template.
    public static let extensions = ["j2", "jinja", "jinja2", "prompt"]

    /// Khoảng BYTE của khối frontmatter, KỂ CẢ hai dòng `---`.
    ///
    /// Trả `nil` khi tệp không mở đầu bằng `---`. Frontmatter **phải** ở ngay đầu tệp: một khối
    /// `---` ở giữa tài liệu Markdown là đường kẻ ngang, không phải cấu hình, và nhận nhầm nó
    /// sẽ gấp mất một đoạn chữ của người dùng.
    public static func frontmatterRange(in buffer: TextBuffer) -> Range<Int>? {
        guard buffer.lineCount >= 2 else { return nil }
        guard dong(buffer, 0).trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return nil }
        for line in 1 ..< buffer.lineCount {
            if dong(buffer, line).trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                let end = line + 1 < buffer.lineCount
                    ? buffer.offset(ofLineStart: line + 1) : buffer.count
                return 0 ..< end
            }
        }
        // Mở mà không đóng: KHÔNG đoán là "tới hết tệp". Một tệp Markdown bắt đầu bằng `---`
        // rồi không có `---` thứ hai là tệp không có frontmatter, và gấp cả tệp lại là hỏng.
        return nil
    }

    /// Vùng gấp cho frontmatter — nối vào `FoldRanges` ở tầng gọi.
    public static func foldRange(in buffer: TextBuffer) -> FoldRange? {
        guard let range = frontmatterRange(in: buffer) else { return nil }
        let lastLine = buffer.lineNumber(atOffset: max(range.upperBound - 1, 0))
        guard lastLine > 0 else { return nil }
        // Dòng `---` đầu vẫn hiện — nó là chỗ bấm để mở lại, đúng quy ước `FoldRange.headerLine`.
        let hiddenStart = buffer.offset(ofLineStart: 1)
        return FoldRange(headerLine: 0, lastLine: lastLine,
                         hiddenBytes: hiddenStart ..< range.upperBound,
                         caretHome: hiddenStart, kind: .section)
    }

    /// Phần YAML bên trong frontmatter, đã bỏ hai dòng `---`.
    public static func frontmatterYAML(in buffer: TextBuffer) -> String? {
        guard let range = frontmatterRange(in: buffer) else { return nil }
        let text = String(decoding: buffer.bytes(in: range), as: UTF8.self)
        var lines = text.components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" { lines.removeFirst() }
        if let i = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---" }) {
            lines = Array(lines[..<i])
        }
        return lines.joined(separator: "\n")
    }

    /// Nội dung một dòng, **đã bỏ cả ký tự xuống dòng**.
    ///
    /// `.whitespaces` KHÔNG gồm `\n` — đó là bẫy đã làm bản đầu của `frontmatterRange` trả `nil`
    /// cho mọi tệp: nó so `"---\n"` với `"---"` và không bao giờ khớp. Dùng
    /// `.whitespacesAndNewlines` ở đây một lần, thay vì nhớ nó ở từng chỗ gọi.
    static func dong(_ buffer: TextBuffer, _ line: Int) -> String {
        let start = buffer.offset(ofLineStart: line)
        let end = line + 1 < buffer.lineCount
            ? buffer.offset(ofLineStart: line + 1) : buffer.count
        return String(decoding: buffer.bytes(in: start ..< end), as: UTF8.self)
    }

    // MARK: - Grammar Jinja2

    /// Tô màu cho `.j2` — hạ tầng FR-FMT-502, cùng lập luận đã ghi ở `MermaidGrammar`.
    ///
    /// `stringDelimiters` chỉ có `"` và `'` ở mức từ vựng; UDL không hiểu `{{ … }}` là một cấu
    /// trúc lồng nhau, nên biến trong template không được tô riêng. Nói ra thay vì để người dùng
    /// tưởng grammar hỏng: thứ họ thấy là từ khoá điều khiển được tô, phần chữ thì không.
    public static let jinjaLanguage = UserDefinedLanguage(
        name: "Prompt / Jinja2",
        extensions: extensions,
        keywordGroups: [
            "keyword": ["if", "elif", "else", "endif", "for", "endfor", "in", "block",
                        "endblock", "extends", "include", "import", "from", "macro",
                        "endmacro", "call", "endcall", "filter", "endfilter", "set",
                        "with", "endwith", "raw", "endraw", "do"],
            "type": ["length", "upper", "lower", "title", "trim", "join", "default",
                     "tojson", "safe", "escape", "replace", "round", "sort", "unique"],
            "constant": ["true", "false", "none", "and", "or", "not", "is", "loop"],
        ],
        caseSensitive: true,
        lineComment: nil,
        blockComment: ["{#", "#}"],
        stringDelimiters: ["\"", "'"],
        escapeCharacter: "\\"
    )
}
