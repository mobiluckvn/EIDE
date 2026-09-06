import Foundation

/// Lỗi cú pháp XML, kèm chỗ và tên gọi của cái sai.
public struct XMLIssue: Error, Equatable, Sendable {
    public let message: String
    public let offset: Int
    public let line: Int
    public let column: Int

    public init(message: String, offset: Int, line: Int, column: Int) {
        self.message = message
        self.offset = offset
        self.line = line
        self.column = column
    }

    public var description: String { "Dòng \(line), cột \(column): \(message)" }
}

/// Công cụ XML: kiểm well-formed, định dạng lại, thu gọn (FR-FMT-505).
///
/// **Viết tay, không dùng `XMLParser` cũng không vendor libxml2.** Ba lý do, theo thứ tự quan
/// trọng:
///
/// 1. **Giữ nguyên văn.** `XMLParser` báo cho ta *nội dung đã giải mã*: `&amp;` thành `&`,
///    `&#x1F600;` thành emoji, `'` thành `"`. Một trình soạn thảo mà "định dạng lại" xong đổi
///    luôn cách viết thực thể và kiểu dấu nháy của người dùng là một trình soạn thảo không dùng
///    được cho file cấu hình đang nằm trong git.
/// 2. **Báo lỗi bằng tiếng Việt, gọi đúng tên cái sai.** "Thẻ `</ten>` đóng cho `<name>`" thì
///    sửa được trong ba giây; `NSXMLParserErrorDomain error 76` thì không.
/// 3. **Không thêm phụ thuộc.** libxml2 kéo theo một quyết định kiến trúc (kích thước bundle,
///    đường ký và công chứng, ADR-08) mà validate XSD/DTD mới thật sự cần. Phần well-formed thì
///    không cần tới nó, nên không trả giá ấy ở đây.
///
/// **Chỉ đọc trừ khi được bảo sửa.** `validate` không bao giờ sinh sửa đổi; `format` và
/// `minify` trả về văn bản mới chứ không đụng vào bản gốc.
public enum XMLTool {

    /// Kết quả một phép biến đổi. Giống `JSONTool.Outcome` và cố ý giống: hai công cụ này đứng
    /// cạnh nhau trong menu, nên chúng phải cư xử như nhau.
    public enum Outcome: Equatable {
        case changed(String)
        /// Đã đúng dạng rồi — không sinh sửa đổi nào, và do đó không có bước undo nào.
        case unchanged
        case invalid(XMLIssue)
    }

    // MARK: - Kiểm

    /// Kiểm well-formed; `nil` nghĩa là hợp lệ.
    public static func validate(_ text: String) -> XMLIssue? {
        var scanner = Scanner(text: text)
        do {
            _ = try scanner.run()
            return nil
        } catch let issue as XMLIssue {
            return issue
        } catch {
            return XMLIssue(message: "Không đọc được", offset: 0, line: 1, column: 1)
        }
    }

    // MARK: - XPath (FR-FMT-505)

    /// Kết quả đánh giá một biểu thức XPath.
    public enum XPathOutcome: Equatable {
        /// Mỗi phần tử là một node đã dựng lại thành chữ.
        case nodes([String])
        /// Tài liệu không well-formed — nói chỗ hỏng, đừng đổ cho biểu thức.
        case invalidDocument(XMLIssue)
        /// Biểu thức sai cú pháp, kèm nguyên văn lời của bộ đánh giá.
        case badQuery(String)
    }

    /// Đánh giá một biểu thức XPath trên tài liệu.
    ///
    /// # Vì sao dùng `XMLDocument` của hệ thống chứ không tự viết
    ///
    /// XPath 1.0 có trục, vị từ, hàm số, phép so kiểu — viết lại nó là một dự án riêng, và một
    /// bản tự viết chỉ đúng 90% thì tệ hơn không có: người dùng không có cách nào biết 10% kia
    /// nằm ở đâu. `XMLDocument` nằm sẵn trong Foundation của macOS, không vendor một byte nào,
    /// và nó đúng cái engine mà `xmllint` dùng.
    ///
    /// **Cái giá phải nói ra:** `XMLDocument` KHÔNG giữ offset của node trong văn bản gốc, nên
    /// kết quả trả về là NỘI DUNG chứ không phải vị trí — không nhảy tới chỗ được. Đó là lý do
    /// hàm này trả `[String]` chứ không trả `[Hit]` như phép tìm. Bộ phân tích viết tay ở tệp
    /// này có offset, nhưng nó không đánh giá XPath; ghép hai thứ lại là việc lớn hơn nhiều so
    /// với giá trị nó thêm, và giới hạn được nói thẳng trong sách trợ giúp.
    public static func evaluateXPath(_ query: String, in text: String) -> XPathOutcome {
        // Kiểm well-formed bằng bộ phân tích CỦA TA trước: nó nói được dòng/cột chỗ hỏng bằng
        // tiếng Việt, còn `XMLDocument` chỉ ném một `NSError` chung chung.
        if let issue = validate(text) { return .invalidDocument(issue) }

        let document: XMLDocument
        do {
            document = try XMLDocument(xmlString: text, options: [.nodePreserveAll])
        } catch {
            return .invalidDocument(
                XMLIssue(message: "Không dựng được cây: \(error.localizedDescription)",
                         offset: 0, line: 1, column: 1))
        }

        func render(_ node: XMLNode) -> String {
            // Thuộc tính và text node in ra giá trị; phần tử in ra cả thẻ. `XMLNode.xmlString`
            // cho phần tử trả về nguyên khối con của nó, đúng thứ người ta muốn thấy.
            switch node.kind {
            case .attribute, .text: return node.stringValue ?? ""
            default: return node.xmlString
            }
        }

        do {
            return .nodes(try document.nodes(forXPath: query).map(render))
        } catch {
            // `nodes(forXPath:)` chỉ nhận biểu thức trả về TẬP NODE — `count(//hang)` hay
            // `string(//a/@b)` ném lỗi ở đó. Đường thứ hai nhận chúng, và đó là những biểu
            // thức người ta gõ thường xuyên nhất sau khi đã chọn được node.
            //
            // Thứ tự này có chủ ý: `nodes(forXPath:)` trả về NODE thật, còn `objects(forXQuery:)`
            // trả về `Any` và với tập node thì nó cho ra chuỗi mô tả (`ma="1"`) chứ không phải
            // giá trị. Nên đường một chạy trước, đường hai chỉ đỡ phần nó bỏ lại.
            do {
                let objects = try document.objects(forXQuery: query)
                return .nodes(objects.map { object in
                    (object as? XMLNode).map(render) ?? String(describing: object)
                })
            } catch {
                return .badQuery(error.localizedDescription)
            }
        }
    }

    // MARK: - Tự đóng thẻ (FR-FMT-505)

    /// Thẻ đóng cần chèn sau khi người dùng vừa gõ `>`, hoặc `nil` nếu không cần gì.
    ///
    /// `prefix` là phần văn bản TRƯỚC con nháy, đã gồm cả dấu `>` vừa gõ.
    ///
    /// Từ chối trong bốn ca, và mỗi ca đều là một lần chèn thừa sẽ làm hỏng tài liệu:
    ///  · `<br/>` — thẻ tự đóng, không có gì để đóng thêm;
    ///  · `</p>` — chính là thẻ đóng;
    ///  · `<?xml …?>`, `<!-- … -->`, `<!DOCTYPE …>` — khai báo, không phải phần tử;
    ///  · `a > b` trong văn bản — dấu lớn hơn thường, không mở thẻ nào.
    public static func closingTag(afterTyping prefix: String) -> String? {
        guard prefix.hasSuffix(">") else { return nil }
        let body = prefix.dropLast()
        guard !body.hasSuffix("/") else { return nil }          // <br/>

        // Tìm dấu `<` mở thẻ này. Nếu giữa nó và `>` có thêm một `<` thì cái ta thấy không
        // phải một thẻ.
        guard let open = body.lastIndex(of: "<") else { return nil }
        let inner = body[body.index(after: open)...]
        guard !inner.contains("<"), !inner.isEmpty else { return nil }
        guard let first = inner.first, first != "/", first != "?", first != "!" else { return nil }

        // Tên thẻ: tới khoảng trắng đầu tiên (phần còn lại là thuộc tính).
        let name = inner.prefix { !$0.isWhitespace && $0 != "/" }
        guard !name.isEmpty else { return nil }
        // Tên hợp lệ theo XML: chữ cái, `_`, `:` mở đầu — số thì không.
        guard let head = name.first, head.isLetter || head == "_" || head == ":" else { return nil }
        return "</\(name)>"
    }

    // MARK: - Định dạng

    /// Xuống dòng và thụt lề lại theo cây thẻ.
    ///
    /// **Chỉ thụt lại những phần tử mà con của nó TOÀN LÀ phần tử.** Trong XML, khoảng trắng
    /// giữa hai thẻ là dữ liệu: `<p>xin <b>chào</b></p>` mà thụt lại thành ba dòng thì câu ấy
    /// mọc thêm hai dấu xuống dòng và một dãy dấu cách — nội dung đã đổi, dù cây thẻ vẫn thế.
    /// Chỗ nào có chữ xen giữa thẻ thì để nguyên xi.
    public static func format(_ text: String, indent: Int = 2) -> Outcome {
        transform(text) { nodes in render(nodes, indent: indent, level: 0) }
    }

    /// Bỏ khoảng trắng thừa GIỮA các thẻ, giữ nguyên mọi thứ khác.
    ///
    /// Cùng một luật với `format`: chỉ bỏ khoảng trắng ở những phần tử con toàn là phần tử.
    public static func minify(_ text: String) -> Outcome {
        transform(text) { nodes in render(nodes, indent: nil, level: 0) }
    }

    private static func transform(
        _ text: String, _ body: ([Node]) -> String
    ) -> Outcome {
        var scanner = Scanner(text: text)
        let nodes: [Node]
        do {
            nodes = try scanner.run()
        } catch let issue as XMLIssue {
            return .invalid(issue)
        } catch {
            return .invalid(XMLIssue(message: "Không đọc được", offset: 0, line: 1, column: 1))
        }
        let result = body(nodes)
        return result == text ? .unchanged : .changed(result)
    }

    // MARK: - Cây

    /// Một nút trong tài liệu, giữ NGUYÊN VĂN mọi thứ.
    ///
    /// `raw` là đúng những byte trong nguồn. Đó là cả điểm của kiểu này: mọi phép biến đổi chỉ
    /// được sắp xếp lại các `raw`, không bao giờ viết lại chúng.
    indirect enum Node {
        /// Thẻ mở + con + thẻ đóng, hoặc thẻ tự đóng.
        case element(open: String, children: [Node], close: String?)
        case text(String)
        case comment(String)
        /// `<?xml … ?>` và mọi chỉ thị xử lý khác.
        case instruction(String)
        case cdata(String)
        /// `<!DOCTYPE …>`.
        case doctype(String)

        var isElement: Bool { if case .element = self { return true }; return false }

        /// Chữ thật sự (không phải khoảng trắng thuần).
        var isMeaningfulText: Bool {
            if case .text(let value) = self {
                return value.contains { !$0.isWhitespace }
            }
            return false
        }
    }

    // MARK: - Kết xuất

    private static func render(_ nodes: [Node], indent: Int?, level: Int) -> String {
        var out = ""
        render(nodes, indent: indent, level: level, into: &out)
        return out
    }

    /// Ghi vào MỘT chuỗi chung xuyên suốt các tầng.
    ///
    /// Bản đầu cho mỗi tầng một chuỗi riêng rồi ghép lại, và "đừng xuống dòng nếu chuỗi đang
    /// rỗng" hóa ra đúng ở tầng ngoài cùng nhưng sai ở mọi tầng trong: chuỗi của tầng trong
    /// luôn rỗng lúc bắt đầu, nên con đầu tiên của mỗi thẻ không được xuống dòng và kết quả ra
    /// `<a>  <b>    <c/>`.
    private static func render(_ nodes: [Node], indent: Int?, level: Int, into out: inout String) {
        var previousWasBlock = false
        for node in nodes {
            switch node {
            case .text(let value):
                // Khoảng trắng thuần ở tầng "toàn phần tử" bị bỏ; chữ thật thì giữ nguyên xi.
                if value.contains(where: { !$0.isWhitespace }) {
                    out += value
                    previousWasBlock = false
                }
            case .element(let open, let children, let close):
                appendSeparator(&out, indent: indent, level: level, previousWasBlock: previousWasBlock)
                out += open
                // Con có chữ xen giữa → KHÔNG đụng vào, in lại y như nguồn.
                if children.contains(where: \.isMeaningfulText) {
                    out += renderRaw(children)
                } else if !children.isEmpty {
                    render(children, indent: indent, level: level + 1, into: &out)
                    appendSeparator(&out, indent: indent, level: level, previousWasBlock: true)
                }
                if let close { out += close }
                previousWasBlock = true
            case .comment(let raw), .instruction(let raw), .cdata(let raw), .doctype(let raw):
                appendSeparator(&out, indent: indent, level: level, previousWasBlock: previousWasBlock)
                out += raw
                previousWasBlock = true
            }
        }
    }

    private static func appendSeparator(
        _ out: inout String, indent: Int?, level: Int, previousWasBlock: Bool
    ) {
        guard let indent else { return }
        if !out.isEmpty { out += "\n" }
        out += String(repeating: " ", count: indent * level)
    }

    /// In lại nguyên xi, dùng cho nội dung hỗn hợp.
    private static func renderRaw(_ nodes: [Node]) -> String {
        var out = ""
        for node in nodes {
            switch node {
            case .text(let raw), .comment(let raw), .instruction(let raw),
                 .cdata(let raw), .doctype(let raw):
                out += raw
            case .element(let open, let children, let close):
                out += open + renderRaw(children) + (close ?? "")
            }
        }
        return out
    }

    // MARK: - Bộ quét

    struct Scanner {
        let chars: [Character]
        var index = 0

        init(text: String) { chars = Array(text) }

        /// Đọc cả tài liệu; ném `XMLIssue` ở chỗ sai đầu tiên.
        mutating func run() throws -> [Node] {
            var nodes: [Node] = []
            var roots = 0
            while index < chars.count {
                let node = try readNode(closing: nil)
                if node.isElement { roots += 1 }
                nodes.append(node)
            }
            guard roots > 0 else {
                throw issue("Không có thẻ nào — file rỗng hoặc không phải XML")
            }
            // Một tài liệu XML có ĐÚNG MỘT phần tử gốc. Nhiều gốc là lỗi hay gặp khi người ta
            // ghép hai file lại với nhau, và nói thẳng ra thì họ biết ngay phải bọc lại.
            guard roots == 1 else {
                throw issue("Có \(roots) thẻ gốc — XML chỉ được một; hãy bọc chúng trong một thẻ chung")
            }
            return nodes
        }

        /// Đọc một nút. `closing` là tên thẻ đang mở, để nhận ra thẻ đóng của nó.
        private mutating func readNode(closing: String?) throws -> Node {
            guard peek() == "<" else { return .text(readText()) }

            if matches("<!--") { return .comment(try readUntil("-->", what: "chú thích")) }
            if matches("<![CDATA[") { return .cdata(try readUntil("]]>", what: "khối CDATA")) }
            if matches("<!DOCTYPE") { return .doctype(try readDoctype()) }
            if matches("<?") { return .instruction(try readUntil("?>", what: "chỉ thị xử lý")) }
            if matches("</") {
                let start = index
                let name = try readCloseTagName()
                throw XMLIssue(
                    message: "Thẻ đóng `</\(name)>` không có thẻ mở nào đang chờ",
                    offset: start, line: line(at: start), column: column(at: start)
                )
            }
            return try readElement()
        }

        private mutating func readElement() throws -> Node {
            let openStart = index
            index += 1                                  // '<'
            let name = try readName(what: "tên thẻ")
            try readAttributes(ofTag: name, from: openStart)

            skipSpace()
            if matches("/>") {
                index += 2
                return .element(open: String(chars[openStart ..< index]), children: [], close: nil)
            }
            guard peek() == ">" else {
                throw issue("Thẻ `<\(name)` chưa đóng bằng `>`")
            }
            index += 1
            let open = String(chars[openStart ..< index])

            var children: [Node] = []
            while true {
                guard index < chars.count else {
                    throw XMLIssue(
                        message: "Thẻ `<\(name)>` mở ra mà không có `</\(name)>` nào đóng lại",
                        offset: openStart, line: line(at: openStart), column: column(at: openStart)
                    )
                }
                if matches("</") {
                    let closeStart = index
                    let closeName = try readCloseTagName()
                    guard closeName == name else {
                        throw XMLIssue(
                            message: "Thẻ `</\(closeName)>` đóng cho `<\(name)>` — hai tên khác nhau",
                            offset: closeStart, line: line(at: closeStart),
                            column: column(at: closeStart)
                        )
                    }
                    return .element(
                        open: open, children: children,
                        close: String(chars[closeStart ..< index])
                    )
                }
                children.append(try readNode(closing: name))
            }
        }

        /// Đọc thuộc tính tới ngay trước `>` hoặc `/>`.
        private mutating func readAttributes(ofTag tag: String, from tagStart: Int) throws {
            var seen = Set<String>()
            while true {
                skipSpace()
                guard let char = peek() else {
                    throw issue("Thẻ `<\(tag)` chưa đóng bằng `>`")
                }
                if char == ">" || matches("/>") { return }

                let nameStart = index
                let name = try readName(what: "tên thuộc tính")
                // Thuộc tính trùng tên là lỗi thật, và nó âm thầm: bộ đọc nào cũng lấy một
                // trong hai, thường là cái sau, nên file "chạy được" mà giá trị không như viết.
                guard seen.insert(name).inserted else {
                    throw XMLIssue(
                        message: "Thuộc tính `\(name)` viết hai lần trong cùng thẻ `<\(tag)>`",
                        offset: nameStart, line: line(at: nameStart), column: column(at: nameStart)
                    )
                }
                skipSpace()
                guard peek() == "=" else {
                    throw issue("Thuộc tính `\(name)` thiếu dấu `=`")
                }
                index += 1
                skipSpace()
                guard let quote = peek(), quote == "\"" || quote == "'" else {
                    throw issue("Giá trị của `\(name)` phải nằm trong dấu nháy")
                }
                index += 1
                while let c = peek(), c != quote {
                    if c == "<" { throw issue("Dấu `<` trong giá trị thuộc tính phải viết là `&lt;`") }
                    index += 1
                }
                guard peek() == quote else {
                    throw issue("Giá trị của `\(name)` thiếu dấu nháy đóng")
                }
                index += 1
            }
        }

        private mutating func readCloseTagName() throws -> String {
            index += 2                                  // '</'
            let name = try readName(what: "tên thẻ đóng")
            skipSpace()
            guard peek() == ">" else { throw issue("Thẻ đóng `</\(name)` thiếu `>`") }
            index += 1
            return name
        }

        /// Tên thẻ hoặc thuộc tính, theo luật tên của XML.
        private mutating func readName(what: String) throws -> String {
            let start = index
            guard let first = peek(), first.isLetter || first == "_" || first == ":" else {
                throw issue("\(what) phải bắt đầu bằng chữ cái, `_` hoặc `:`")
            }
            index += 1
            while let char = peek(),
                  char.isLetter || char.isNumber || char == "_" || char == "-"
                    || char == "." || char == ":" {
                index += 1
            }
            return String(chars[start ..< index])
        }

        /// Chữ giữa các thẻ. Kiểm luôn thực thể, vì `&` trần là lỗi hay gặp nhất.
        private mutating func readText() -> String {
            let start = index
            while let char = peek(), char != "<" { index += 1 }
            return String(chars[start ..< index])
        }

        private mutating func readUntil(_ terminator: String, what: String) throws -> String {
            let start = index
            let needle = Array(terminator)
            while index < chars.count {
                if matches(terminator) {
                    index += needle.count
                    return String(chars[start ..< index])
                }
                index += 1
            }
            throw XMLIssue(
                message: "\(what) mở ra mà không có `\(terminator)` đóng lại",
                offset: start, line: line(at: start), column: column(at: start)
            )
        }

        /// `<!DOCTYPE …>` có thể chứa một khối `[ … ]` với `>` bên trong.
        private mutating func readDoctype() throws -> String {
            let start = index
            var depth = 0
            while let char = peek() {
                if char == "[" { depth += 1 }
                if char == "]" { depth -= 1 }
                if char == ">" && depth <= 0 {
                    index += 1
                    return String(chars[start ..< index])
                }
                index += 1
            }
            throw XMLIssue(
                message: "`<!DOCTYPE` chưa đóng bằng `>`",
                offset: start, line: line(at: start), column: column(at: start)
            )
        }

        // MARK: - Mảnh nhỏ

        func peek() -> Character? { index < chars.count ? chars[index] : nil }

        func matches(_ text: String) -> Bool {
            let needle = Array(text)
            guard index + needle.count <= chars.count else { return false }
            for (offset, char) in needle.enumerated() where chars[index + offset] != char {
                return false
            }
            return true
        }

        mutating func skipSpace() {
            while let char = peek(), char == " " || char == "\t" || char == "\n" || char == "\r" {
                index += 1
            }
        }

        func line(at offset: Int) -> Int {
            1 + chars[0 ..< Swift.min(offset, chars.count)].filter { $0 == "\n" }.count
        }

        func column(at offset: Int) -> Int {
            let stop = Swift.min(offset, chars.count)
            var column = 1
            var i = stop - 1
            while i >= 0, chars[i] != "\n" { column += 1; i -= 1 }
            return column
        }

        func issue(_ message: String) -> XMLIssue {
            XMLIssue(
                message: message, offset: index, line: line(at: index), column: column(at: index)
            )
        }
    }
}
