import Foundation

/// Markdown → HTML, tập con đủ cho báo cáo — FR-RPT-001 và FR-RPT-005.
///
/// ## Tập con, và nói thẳng nó đỡ được gì
///
/// **Đỡ:** tiêu đề `#`…`######` · đoạn văn · `**đậm**` · `*nghiêng*` · `` `mã` `` ·
/// `[nhãn](đích)` · danh sách `-`/`*`/`1.` · trích dẫn `>` · đường kẻ `---` · khối mã rào.
///
/// **Không đỡ:** bảng Markdown, chú thích chân trang, danh sách lồng nhau quá một mức, HTML thô
/// nhúng trong Markdown.
///
/// Bảng là khoản bỏ sót đáng nói nhất, và nó có lý do: trong `.greport.md` bảng đến từ khối
/// ```query — dữ liệu thật, sinh ra từ truy vấn. Một bảng gõ tay trong báo cáo dữ liệu là thứ
/// nên nghi ngờ, vì nó không chạy lại được khi số liệu đổi.
///
/// ## Vì sao KHÔNG kéo một thư viện Markdown vào
///
/// Bộ này chưa tới hai trăm dòng và chỉ chạy trên tài liệu của chính người dùng. Một thư viện
/// đầy đủ mang theo bảng, footnote, HTML thô, và mọi thứ đi kèm — trong đó **HTML thô là một lỗ
/// hổng**: báo cáo được chia sẻ, và một tài liệu chứa `<script>` sẽ chạy trong trình duyệt của
/// người nhận. Ở đây mọi ký tự đều đi qua `escape`, nên chuyện ấy không xảy ra được.
public enum MarkdownHTML {

    public static func render(_ markdown: String) -> String {
        var out: [String] = []
        let lines = markdown.components(separatedBy: "\n")
        var index = 0
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            out.append("<p>" + inline(paragraph.joined(separator: " ")) + "</p>")
            paragraph.removeAll()
        }

        while index < lines.count {
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // --- Khối mã rào -------------------------------------------------------------
            if line.hasPrefix("```") {
                flushParagraph()
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var body: [String] = []
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[index])
                    index += 1
                }
                index += 1        // bỏ qua hàng rào đóng
                let classAttribute = language.isEmpty ? "" : " class=\"lang-\(escape(language))\""
                out.append("<pre><code\(classAttribute)>"
                    + escape(body.joined(separator: "\n")) + "</code></pre>")
                continue
            }

            if line.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            // --- Đường kẻ ngang ------------------------------------------------------------
            if line == "---" || line == "***" || line == "___" {
                flushParagraph()
                out.append("<hr>")
                index += 1
                continue
            }

            // --- Tiêu đề -------------------------------------------------------------------
            if line.hasPrefix("#") {
                let hashes = line.prefix { $0 == "#" }.count
                if hashes <= 6, line.dropFirst(hashes).first == " " {
                    flushParagraph()
                    let text = String(line.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                    out.append("<h\(hashes)>" + inline(text) + "</h\(hashes)>")
                    index += 1
                    continue
                }
            }

            // --- Trích dẫn -----------------------------------------------------------------
            if line.hasPrefix(">") {
                flushParagraph()
                var quoted: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    quoted.append(String(current.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                out.append("<blockquote><p>"
                    + inline(quoted.joined(separator: " ")) + "</p></blockquote>")
                continue
            }

            // --- Danh sách -----------------------------------------------------------------
            if let marker = listMarker(line) {
                flushParagraph()
                let tag = marker == .ordered ? "ol" : "ul"
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let kind = listMarker(current), kind == marker else { break }
                    items.append("<li>" + inline(stripMarker(current, kind)) + "</li>")
                    index += 1
                }
                out.append("<\(tag)>" + items.joined() + "</\(tag)>")
                continue
            }

            paragraph.append(line)
            index += 1
        }
        flushParagraph()
        return out.joined(separator: "\n")
    }

    private enum ListKind { case bullet, ordered }

    private static func listMarker(_ line: String) -> ListKind? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return .bullet }
        // `1.` `2)` — chỉ nhận khi có ít nhất một chữ số rồi tới `.` hoặc `)` rồi tới khoảng trắng.
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")" else { return nil }
        return rest.dropFirst().first == " " ? .ordered : nil
    }

    private static func stripMarker(_ line: String, _ kind: ListKind) -> String {
        switch kind {
        case .bullet: return String(line.dropFirst(2))
        case .ordered:
            let digits = line.prefix { $0.isNumber }.count
            return String(line.dropFirst(digits + 2))
        }
    }

    /// Định dạng trong dòng. Thoát HTML TRƯỚC, rồi mới chèn thẻ.
    ///
    /// Thứ tự này là bắt buộc: thoát sau khi chèn thẻ sẽ biến chính `<strong>` vừa chèn thành
    /// `&lt;strong&gt;` và cả trang thành văn bản thô.
    static func inline(_ text: String) -> String {
        var result = escape(text)
        // Mã trong dòng đi TRƯỚC đậm/nghiêng: một đoạn `` `a * b` `` chứa dấu sao là nhân, không
        // phải nghiêng.
        result = replacePaired(result, delimiter: "`", tag: "code")
        result = replacePaired(result, delimiter: "**", tag: "strong")
        result = replacePaired(result, delimiter: "*", tag: "em")
        result = links(result)
        return result
    }

    private static func replacePaired(
        _ text: String, delimiter: String, tag: String
    ) -> String {
        let parts = text.components(separatedBy: delimiter)
        // Số phần chẵn nghĩa là số dấu phân cách LẺ, tức có một dấu không có cặp — để nguyên
        // thay vì đoán ý. Một dòng "2 * 3 = 6" không phải là chữ nghiêng bỏ dở.
        guard parts.count >= 3, parts.count % 2 == 1 else { return text }
        var out = parts[0]
        var index = 1
        while index < parts.count {
            out += "<\(tag)>" + parts[index] + "</\(tag)>"
            if index + 1 < parts.count { out += parts[index + 1] }
            index += 2
        }
        return out
    }

    private static func links(_ text: String) -> String {
        // `[nhãn](đích)`. Chỉ nhận đích http/https/mailto và đường dẫn tương đối — `javascript:`
        // trong một báo cáo được chia sẻ là mã của người khác chạy trên máy người nhận.
        let pattern = "\\[([^\\]]*)\\]\\(([^)\\s]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let full = NSRange(text.startIndex..., in: text)
        var result = ""
        var last = text.startIndex
        for match in regex.matches(in: text, range: full) {
            guard let whole = Range(match.range, in: text),
                  let labelRange = Range(match.range(at: 1), in: text),
                  let targetRange = Range(match.range(at: 2), in: text) else { continue }
            result += text[last ..< whole.lowerBound]
            let target = String(text[targetRange])
            if isSafeLink(target) {
                result += "<a href=\"\(target)\">\(text[labelRange])</a>"
            } else {
                // Giữ nguyên chữ, bỏ liên kết. Người đọc vẫn thấy đích để tự đánh giá.
                result += "[\(text[labelRange])](\(target))"
            }
            last = whole.upperBound
        }
        result += text[last...]
        return result
    }

    private static func isSafeLink(_ target: String) -> Bool {
        let lowered = target.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
            || lowered.hasPrefix("mailto:") { return true }
        // Đường dẫn tương đối: không có dấu `:` trước dấu `/` đầu tiên.
        guard let colon = lowered.firstIndex(of: ":") else { return true }
        guard let slash = lowered.firstIndex(of: "/") else { return false }
        return colon > slash
    }

    public static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(character)
            }
        }
        return out
    }
}
