import Foundation

/// Định dạng lại mã sơ đồ Mermaid — FR-MMD-006.
///
/// ## Formatter này KHÔNG phân tích cú pháp, và đó là giới hạn có chủ ý
///
/// Nó làm đúng ba việc: **thụt lề theo khối**, **cắt khoảng trắng thừa**, và (khi được xin)
/// **gom dòng khai báo lên đầu**. Nó không hiểu ngữ nghĩa của sơ đồ, không sắp lại cạnh, không
/// đổi tên gì.
///
/// Lý do: cây phân tích thật nằm trong mermaid.js và không có API trả nó ra. Một formatter đoán
/// cấu trúc rồi viết lại văn bản của người dùng là thứ chỉ cần sai một lần là mất lòng tin vĩnh
/// viễn — mà "sai" ở đây nghĩa là **sơ đồ đang chạy bỗng không vẽ được nữa**. Nên nó chỉ đụng
/// vào KHOẢNG TRẮNG và THỨ TỰ DÒNG, hai thứ nó kiểm chứng được.
///
/// ## Chú thích được giữ NGUYÊN VĂN
///
/// Đặc tả đòi đúng câu ấy. Chú thích `%%` chỉ được thụt lại cho thẳng hàng; nội dung sau `%%`
/// không bị đụng tới, kể cả khoảng trắng bên trong — một chú thích kẻ bảng bằng dấu cách sẽ vỡ
/// nếu formatter "dọn" nó.
public enum MermaidFormatter {

    public struct Options: Equatable, Sendable {

        /// Sắp lại thứ tự khai báo — vế *"thứ tự khai báo theo quy ước chọn được"*.
        public enum DeclarationOrder: String, CaseIterable, Equatable, Sendable {
            /// Giữ nguyên thứ tự người dùng viết.
            case keep
            /// Đưa dòng KHAI BÁO thuần lên đầu khối, giữ nguyên thứ tự tương đối giữa chúng.
            case declarationsFirst
        }

        public var indent: Int
        public var declarationOrder: DeclarationOrder

        public init(indent: Int = 2, declarationOrder: DeclarationOrder = .keep) {
            self.indent = max(1, min(8, indent))
            self.declarationOrder = declarationOrder
        }
    }

    /// Từ mở khối: dòng bắt đầu bằng một trong số này thì các dòng sau thụt thêm một cấp.
    static let openers = [
        "subgraph", "alt", "opt", "loop", "par", "critical", "rect", "box",
        "namespace", "state", "class",
    ]

    /// Từ đóng khối.
    static let closers = ["end"]

    /// Từ đứng GIỮA một khối: chính nó lùi ra một cấp, nhưng khối vẫn mở.
    static let middles = ["else", "and", "option"]

    public static func format(_ source: String, options: Options = Options()) -> String {
        let lines = source.components(separatedBy: "\n")
        var out: [String] = []
        var depth = 0
        var index = 0

        // --- Frontmatter giữ NGUYÊN VĂN ----------------------------------------------------
        //
        // Nó là YAML, không phải mã sơ đồ; thụt lề trong YAML MANG NGHĨA, nên "chuẩn hoá" nó ở
        // đây là đổi nội dung chứ không phải đổi hình thức.
        if let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" {
            out.append(first)
            index = 1
            while index < lines.count {
                out.append(lines[index])
                let closed = lines[index].trimmingCharacters(in: .whitespaces) == "---"
                index += 1
                if closed { break }
            }
        }

        // --- Dòng khai báo ------------------------------------------------------------------
        var declarationSeen = false
        var body: [(depth: Int, text: String)] = []

        while index < lines.count {
            let raw = lines[index]
            index += 1
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                body.append((depth, ""))
                continue
            }
            // Chỉ thị `%%{…}%%` và chú thích `%%` đứng ở cấp hiện tại, nội dung không đụng tới.
            if trimmed.hasPrefix("%%") {
                body.append((depth, trimmed))
                continue
            }
            if !declarationSeen {
                declarationSeen = true
                body.append((0, trimmed))
                depth = 1
                continue
            }

            let word = firstWord(trimmed).lowercased()
            if closers.contains(word) || trimmed == "}" {
                depth = max(1, depth - 1)
                body.append((depth, trimmed))
                continue
            }
            if middles.contains(word) {
                // `else` lùi ra một cấp cho chính nó rồi khối vẫn mở — cùng lối `else` của mã.
                body.append((max(1, depth - 1), trimmed))
                continue
            }
            body.append((depth, trimmed))
            if opensBlock(trimmed, word: word) { depth += 1 }
        }

        var ordered = body
        if options.declarationOrder == .declarationsFirst {
            ordered = reorderDeclarations(body)
        }

        for (level, text) in ordered {
            out.append(text.isEmpty
                ? ""
                : String(repeating: " ", count: level * options.indent) + text)
        }
        // Giữ đúng một dấu xuống dòng ở cuối nếu nguồn có; không tự thêm nếu nguồn không có.
        var result = out.joined(separator: "\n")
        if source.hasSuffix("\n"), !result.hasSuffix("\n") { result += "\n" }
        return result
    }

    /// Dòng này có mở một khối mới không.
    static func opensBlock(_ line: String, word: String) -> Bool {
        // `state Foo` KHÔNG mở khối, `state Foo {` thì có. Cùng chuyện với `class`, `namespace`:
        // chúng vừa là câu khai báo một dòng vừa là đầu một khối, và dấu `{` cuối dòng là thứ
        // duy nhất phân biệt.
        if ["state", "class", "namespace", "box"].contains(word) {
            return line.hasSuffix("{")
        }
        if openers.contains(word) { return true }
        // Khối `{` mở ở cuối dòng — dạng `KHACH_HANG {` của erDiagram.
        return line.hasSuffix("{")
    }

    static func firstWord(_ line: String) -> String {
        String(line.prefix { !$0.isWhitespace })
    }

    /// Đưa dòng KHAI BÁO THUẦN lên đầu, giữ nguyên thứ tự tương đối.
    ///
    /// ## Vì sao mặc định là KHÔNG làm việc này
    ///
    /// Ở `sequenceDiagram`, thứ tự `participant` quyết định thứ tự CỘT — gom chúng lên đầu mà
    /// giữ nguyên thứ tự tương đối thì hình không đổi, nhưng chỉ cần một chỗ đảo là sơ đồ khác
    /// hẳn. Ở `flowchart`, thứ tự node ảnh hưởng tới cách bố cục phá thế hoà. Đó là lý do đặc
    /// tả nói *"theo quy ước CHỌN ĐƯỢC"*: đây là một quy ước của đội, không phải một cách viết
    /// đúng hơn — nên nó phải được xin, không được tự áp.
    static func reorderDeclarations(
        _ body: [(depth: Int, text: String)]
    ) -> [(depth: Int, text: String)] {
        guard let declarationIndex = body.firstIndex(where: { $0.depth == 0 && !$0.text.isEmpty })
        else { return body }

        var head = Array(body[...declarationIndex])
        let rest = Array(body[(declarationIndex + 1)...])

        // Chỉ gom ở cấp NGOÀI CÙNG (depth 1). Trong một `subgraph`, dòng khai báo thuộc về khối
        // ấy và kéo nó ra ngoài là đổi cấu trúc chứ không đổi thứ tự.
        var declarations: [(depth: Int, text: String)] = []
        var others: [(depth: Int, text: String)] = []
        var insideBlock = 0
        for entry in rest {
            let word = firstWord(entry.text).lowercased()
            if closers.contains(word) || entry.text == "}" { insideBlock = max(0, insideBlock - 1) }
            let atTopLevel = entry.depth == 1 && insideBlock == 0
            if opensBlock(entry.text, word: word) { insideBlock += 1 }

            if atTopLevel, isDeclaration(entry.text) {
                declarations.append(entry)
            } else {
                others.append(entry)
            }
        }
        // Dòng trống ở đầu phần còn lại sẽ thành một khoảng trống lơ lửng sau khi gom; bỏ nó.
        while let first = others.first, first.text.isEmpty { others.removeFirst() }
        head.append(contentsOf: declarations)
        if !declarations.isEmpty, !others.isEmpty { head.append((1, "")) }
        head.append(contentsOf: others)
        return head
    }

    /// Dòng này có phải một KHAI BÁO thuần không (không có cạnh, không có thông điệp).
    static func isDeclaration(_ line: String) -> Bool {
        guard !line.isEmpty, !line.hasPrefix("%%") else { return false }
        let word = firstWord(line).lowercased()
        // Dòng MỞ hay ĐÓNG khối không bao giờ là khai báo thuần.
        //
        // Bỏ vế này thì `subgraph Nhóm` lọt qua mọi phép thử bên dưới (không mũi tên, không dấu
        // hai chấm) và bị GOM LÊN ĐẦU cùng với `end` của nó — khối rỗng nằm trên, còn nội dung
        // của nó trôi xuống dưới. Bài kiểm "gom khai báo không kéo dòng ra khỏi khối" dựng đúng
        // ca ấy và bắt được.
        if openers.contains(word) || closers.contains(word) || middles.contains(word) {
            return false
        }
        if line.hasSuffix("{") || line == "}" { return false }
        if ["participant", "actor"].contains(word) { return true }
        // Có mũi tên thì là CẠNH, không phải khai báo. Kiểm trên phần ngoài nhãn để một nhãn
        // chứa "-->" không làm dòng khai báo bị hiểu nhầm thành cạnh.
        let outside = strippingLabels(line)
        for arrow in ["-->", "---", "-.->", "==>", "->>", "-->>", "->", "--", "..>", "<|--",
                      "*--", "o--", "..|>", "||--", "}o--", "--o", "--*"] where
            outside.contains(arrow) {
            return false
        }
        if outside.contains(":") { return false }   // thông điệp, mục gantt, lát bánh
        return true
    }

    static func strippingLabels(_ line: String) -> String {
        var out = ""
        var depth = 0
        var inQuote = false
        for character in line {
            if character == "\"" {
                inQuote.toggle()
                continue
            }
            if inQuote { continue }
            if "[({".contains(character) {
                depth += 1
                continue
            }
            if "])}".contains(character) {
                depth = max(0, depth - 1)
                continue
            }
            if depth == 0 { out.append(character) }
        }
        return out
    }
}
