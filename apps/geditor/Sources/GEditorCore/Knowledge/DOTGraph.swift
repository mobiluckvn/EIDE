import Foundation

/// Đọc DOT/Graphviz thành đồ thị — FR-KNW-905, và nền cho FR-KNW-910/914/916.
///
/// ## Vì sao TỰ đọc DOT thay vì vendor Graphviz
///
/// ADR-15 §7 chốt: *"chuyển DOT → Mermaid, dùng lại `MermaidRenderer`"*, để tránh vendor một
/// engine vẽ THỨ HAI (viz.js nặng ~3 MB và là một thứ nữa phải nuôi, ngay cạnh mermaid 3,4 MB
/// đã có). Chốt ấy chỉ đứng được nếu ta đọc được DOT — và đọc DOT thì không cần cả Graphviz,
/// vì thứ ta cần là **cấu trúc** (node, cạnh, nhãn), không phải **bố cục** (toạ độ từng node).
/// Bố cục là việc của mermaid.
///
/// ## Ranh giới: bộ này đọc phần DOT mà nó CHẮC
///
/// DOT có những góc mà một bộ đọc viết tay không nên hứa: `subgraph` lồng nhau nhiều tầng,
/// `rank=same`, thuộc tính HTML-like `<...>`, cụm `{a b c} -> d`. Bộ này:
///
/// * đọc được: `digraph`/`graph`, node có và không có thuộc tính, cạnh `->` và `--`, chuỗi cạnh
///   `a -> b -> c`, nhãn `label="…"`, chú thích `//`, `/* */` và `#`, `subgraph` MỘT tầng;
/// * **nói ra** những gì nó bỏ qua, thành `warnings` — chứ không im lặng vẽ thiếu.
///
/// Một sơ đồ vẽ thiếu ba cạnh mà không có gì báo là tệ hơn hẳn một sơ đồ không vẽ.
public struct DOTGraph: Equatable, Sendable {

    public struct Node: Equatable, Sendable {
        public var name: String
        public var label: String?
        /// Dòng khai node, 0-based — để bấm node trên hình nhảy về đúng dòng.
        public var line: Int
        public var shape: String?
        /// "Loại" của node — thứ gần nhất với nhãn (`:Label`) của Cypher.
        ///
        /// DOT không có khái niệm ấy, nên quy ước phải chọn và phải nói ra: lấy thuộc tính
        /// `type`, không có thì `class`, không có nữa thì `shape`. Hai tên đầu là quy ước hay
        /// gặp trong DOT viết tay; `shape` là đường lui vì rất nhiều sơ đồ phân biệt loại node
        /// bằng đúng hình dạng của nó.
        ///
        /// Quy ước này in trong phần giải thích kế hoạch chạy của FR-KNW-913, chứ không giấu.
        public var kind: String?
        /// MỌI thuộc tính khai trong `[...]`, giữ nguyên tên.
        ///
        /// `label`/`shape`/`kind` ở trên là ba thuộc tính có nghĩa riêng với phần vẽ và phần
        /// truy vấn; bảng này giữ tất cả, kể cả những tên ta chưa biết dùng làm gì. Không giữ
        /// thì FR-KNW-924 không kiểm được "thuộc tính bắt buộc thiếu" trên bất kỳ tên nào ngoài
        /// ba cái ấy — tức là kiểm được một luật hẹp hơn hẳn luật người dùng khai.
        public var attributes: [String: String]

        public init(
            name: String, label: String? = nil, line: Int, shape: String? = nil,
            kind: String? = nil, attributes: [String: String] = [:]
        ) {
            self.name = name
            self.label = label
            self.line = line
            self.shape = shape
            self.kind = kind
            self.attributes = attributes
        }

        /// Chữ hiện trên hình: nhãn nếu có, không thì chính tên.
        public var display: String { label ?? name }
    }

    public struct Edge: Equatable, Sendable {
        public var from: String
        public var to: String
        public var label: String?
        public var line: Int
        /// Trọng số từ thuộc tính DOT `weight`. `nil` = không khai.
        ///
        /// Có mặt cho đường đi ngắn nhất CÓ TRỌNG SỐ (FR-KNW-914). Cạnh không khai trọng số
        /// tính là 1 — và khi một đồ thị TRỘN cạnh có và không có trọng số, phần Phương pháp
        /// nói ra điều đó, vì "1" là một giả định chứ không phải một số đo.
        public var weight: Double?
        /// MỌI thuộc tính khai trong `[...]` của cạnh.
        public var attributes: [String: String]

        public init(
            from: String, to: String, label: String? = nil, line: Int, weight: Double? = nil,
            attributes: [String: String] = [:]
        ) {
            self.from = from
            self.to = to
            self.label = label
            self.line = line
            self.weight = weight
            self.attributes = attributes
        }
    }

    public var isDirected: Bool
    public var name: String
    public var nodes: [Node]
    public var edges: [Edge]
    /// Những gì bộ đọc BỎ QUA, kèm số dòng. Hiện lên panel, không nuốt.
    public var warnings: [(line: Int, message: String)]

    public static func == (left: DOTGraph, right: DOTGraph) -> Bool {
        left.isDirected == right.isDirected && left.name == right.name
            && left.nodes == right.nodes && left.edges == right.edges
            && left.warnings.map(\.line) == right.warnings.map(\.line)
            && left.warnings.map(\.message) == right.warnings.map(\.message)
    }

    /// Tệp này có phải DOT không.
    ///
    /// Ngửi bằng luật CHẶT: phải có từ khoá `digraph` hoặc `graph` ở đầu một câu lệnh, và một
    /// dấu `{`. Đuôi `.dot` cũng là bằng chứng — nhưng `.dot` còn là đuôi của template Word,
    /// nên đuôi một mình không đủ.
    public static func looksLikeDOT(_ text: String, path: String?) -> Bool {
        let head = String(text.prefix(4_096))
        let stripped = stripComments(head)
        guard stripped.contains("{") else { return false }
        for line in stripped.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let words = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "{" })
            guard let first = words.first?.lowercased() else { continue }
            if first == "digraph" || first == "graph" || first == "strict" { return true }
            // Câu lệnh đầu tiên không phải khai đồ thị → không phải DOT.
            return false
        }
        _ = path
        return false
    }

    // MARK: - Đọc

    public static func parse(_ text: String) -> DOTGraph {
        var graph = DOTGraph(
            isDirected: true, name: "", nodes: [], edges: [], warnings: [])
        var seen: [String: Int] = [:]           // tên node → chỉ số trong `nodes`
        let lines = stripComments(text).components(separatedBy: "\n")
        var subgraphDepth = 0
        var declared = false

        for (number, raw) in lines.enumerated() {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // --- khai đồ thị ---
            if !declared {
                let lowered = line.lowercased()
                if lowered.hasPrefix("strict ") { line = String(line.dropFirst(7)) }
                let lowered2 = line.lowercased()
                if lowered2.hasPrefix("digraph") || lowered2.hasPrefix("graph") {
                    graph.isDirected = lowered2.hasPrefix("digraph")
                    let head = line.prefix(while: { $0 != "{" })
                    let words = head.split(whereSeparator: { $0 == " " || $0 == "\t" })
                    if words.count > 1 { graph.name = unquote(String(words[1])) }
                    declared = true
                    line = String(line.drop(while: { $0 != "{" }).dropFirst())
                        .trimmingCharacters(in: .whitespaces)
                    if line.isEmpty { continue }
                }
            }

            if line.hasPrefix("subgraph") || line == "{" {
                subgraphDepth += 1
                if subgraphDepth == 1 {
                    // Một tầng thì đọc được — node bên trong vẫn là node. Nhóm thì mất.
                    graph.warnings.append((number,
                        "subgraph được đọc PHẲNG: node và cạnh bên trong vẫn có, nhưng nhóm "
                        + "không hiện thành khung trên hình"))
                } else {
                    graph.warnings.append((number, "subgraph lồng nhiều tầng — bỏ qua tầng này"))
                }
                continue
            }
            if line == "}" {
                if subgraphDepth > 0 { subgraphDepth -= 1 }
                continue
            }

            // Nhiều câu lệnh trên một dòng, ngăn bằng `;`.
            for statement in splitStatements(line) {
                // Dấu `}` đóng khối có thể nằm CUỐI cùng dòng với câu lệnh: `digraph { a -> b }`.
                // Không bóc nó ra thì tên node cuối cùng thành «b }» — một lỗi im lặng, vì nó
                // vẫn vẽ ra một node, chỉ là node sai tên và không nối được với gì.
                let (body, closes) = peelClosingBraces(statement)
                parse(statement: body, line: number, into: &graph, seen: &seen)
                for _ in 0 ..< closes where subgraphDepth > 0 { subgraphDepth -= 1 }
            }
        }
        return graph
    }

    private static func parse(
        statement raw: String, line: Int, into graph: inout DOTGraph, seen: inout [String: Int]
    ) {
        let statement = raw.trimmingCharacters(in: .whitespaces)
        guard !statement.isEmpty, statement != "}" else { return }

        // Thuộc tính mặc định cho cả đồ thị: `node [shape=box]`, `graph [rankdir=LR]`, `a=b`.
        let head = statement.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "[" })
            .first.map { $0.lowercased() } ?? ""
        if ["node", "edge", "graph"].contains(head), !statement.contains("->"),
           !statement.contains("--") {
            graph.warnings.append((line,
                "thuộc tính mặc định «\(head)» không chuyển sang Mermaid được — Mermaid không "
                + "có khái niệm tương đương"))
            return
        }
        if !statement.contains("->"), !statement.contains("--"), statement.contains("="),
           !statement.contains("[") {
            graph.warnings.append((line, "gán thuộc tính đồ thị «\(statement)» — bỏ qua"))
            return
        }

        // --- cạnh ---
        //
        // Tách theo `->` hoặc `--`, và một câu lệnh có thể là CHUỖI: `a -> b -> c`.
        let separator = statement.contains("->") ? "->" : (statement.contains("--") ? "--" : nil)
        if let separator {
            let (body, attributes) = splitAttributes(statement)
            let parts = body.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard parts.count >= 2 else { return }
            let label = attribute("label", in: attributes)
            let table = attributeTable(attributes)
            for index in 0 ..< (parts.count - 1) {
                let from = unquote(parts[index])
                let to = unquote(parts[index + 1])
                if from.hasPrefix("{") || to.hasPrefix("{") {
                    graph.warnings.append((line,
                        "cụm `{a b c}` ở hai đầu cạnh chưa đọc được — cạnh này bị bỏ"))
                    continue
                }
                ensure(from, line: line, into: &graph, seen: &seen)
                ensure(to, line: line, into: &graph, seen: &seen)
                graph.edges.append(Edge(
                    from: from, to: to, label: label, line: line,
                    weight: attribute("weight", in: attributes).flatMap(Double.init),
                    attributes: table))
            }
            return
        }

        // --- khai node ---
        let (body, attributes) = splitAttributes(statement)
        let name = unquote(body.trimmingCharacters(in: .whitespaces))
        guard !name.isEmpty else { return }
        ensure(name, line: line, into: &graph, seen: &seen)
        if let index = seen[name] {
            if let label = attribute("label", in: attributes) { graph.nodes[index].label = label }
            if let shape = attribute("shape", in: attributes) { graph.nodes[index].shape = shape }
            graph.nodes[index].kind = attribute("type", in: attributes)
                ?? attribute("class", in: attributes)
                ?? graph.nodes[index].shape
            // Gộp chứ không thay: `a [label="x"]; a [type="y"]` khai node ấy làm hai lần, và
            // mất một trong hai bảng là mất một luật kiểm của FR-KNW-924.
            for (key, value) in attributeTable(attributes) {
                graph.nodes[index].attributes[key] = value
            }
            // Dòng KHAI node đè lên dòng nó xuất hiện lần đầu trong một cạnh: bấm node trên
            // hình thì người dùng muốn tới chỗ ĐỊNH NGHĨA, không tới chỗ nhắc tên.
            if !attributes.isEmpty { graph.nodes[index].line = line }
        }
    }

    private static func ensure(
        _ name: String, line: Int, into graph: inout DOTGraph, seen: inout [String: Int]
    ) {
        guard seen[name] == nil else { return }
        seen[name] = graph.nodes.count
        graph.nodes.append(Node(name: name, line: line))
    }

    // MARK: - Cắt chuỗi

    /// Bỏ chú thích `//`, `#` và `/* */`, GIỮ NGUYÊN số dòng.
    ///
    /// Giữ số dòng là điều kiện, không phải tiện lợi: mọi thứ về sau (bấm node → nhảy tới dòng,
    /// danh sách cảnh báo) đều đếm dòng trên văn bản GỐC mà người dùng đang nhìn.
    static func stripComments(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        var inString = false
        var inBlock = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if inBlock {
                if character == "*", next < text.endIndex, text[next] == "/" {
                    inBlock = false
                    index = text.index(after: next)
                    continue
                }
                if character == "\n" { out.append(character) }
                index = next
                continue
            }
            if inString {
                out.append(character)
                if character == "\\", next < text.endIndex {
                    out.append(text[next])
                    index = text.index(after: next)
                    continue
                }
                if character == "\"" { inString = false }
                index = next
                continue
            }
            if character == "\"" { inString = true; out.append(character); index = next; continue }
            if character == "/", next < text.endIndex, text[next] == "*" {
                inBlock = true
                index = text.index(after: next)
                continue
            }
            if character == "/", next < text.endIndex, text[next] == "/" {
                while index < text.endIndex, text[index] != "\n" { index = text.index(after: index) }
                continue
            }
            if character == "#" {
                while index < text.endIndex, text[index] != "\n" { index = text.index(after: index) }
                continue
            }
            out.append(character)
            index = next
        }
        return out
    }

    /// Bóc những dấu `}` ở CUỐI một câu lệnh, trả về phần thân và số dấu đã bóc.
    ///
    /// Tên node không được kết thúc bằng `}` khi không có nháy, nên phép bóc này an toàn.
    static func peelClosingBraces(_ statement: String) -> (body: String, closes: Int) {
        var body = statement
        var closes = 0
        while true {
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("}") else { return (body, closes) }
            // `{` ở đâu đó phía trước nghĩa là dấu `}` này đóng một thuộc tính hoặc một cụm,
            // không phải đóng khối — để nguyên cho chỗ khác lo.
            guard !trimmed.dropLast().contains("{") else { return (body, closes) }
            body = String(trimmed.dropLast())
            closes += 1
        }
    }

    /// Tách câu lệnh theo `;` — nhưng KHÔNG tách bên trong chuỗi hay bên trong `[...]`.
    static func splitStatements(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inString = false
        var depth = 0
        for character in line {
            if character == "\"" { inString.toggle() }
            if !inString {
                if character == "[" { depth += 1 }
                if character == "]" { depth = max(0, depth - 1) }
                if character == ";", depth == 0 {
                    out.append(current)
                    current = ""
                    continue
                }
            }
            current.append(character)
        }
        out.append(current)
        return out.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Tách phần thân và phần `[thuộc tính]`.
    static func splitAttributes(_ statement: String) -> (body: String, attributes: String) {
        var inString = false
        var start: String.Index?
        var index = statement.startIndex
        while index < statement.endIndex {
            let character = statement[index]
            if character == "\"" { inString.toggle() }
            if !inString, character == "[" { start = index; break }
            index = statement.index(after: index)
        }
        guard let start else { return (statement, "") }
        var end = statement.endIndex
        var cursor = statement.index(after: start)
        inString = false
        while cursor < statement.endIndex {
            let character = statement[cursor]
            if character == "\"" { inString.toggle() }
            if !inString, character == "]" { end = cursor; break }
            cursor = statement.index(after: cursor)
        }
        let attributes = String(statement[statement.index(after: start) ..< end])
        // Thân là phần TRƯỚC và phần SAU khối thuộc tính, nối lại.
        //
        // Bản đầu chỉ trả phần trước, nên `a [label="x"] -> b` mất hẳn ` -> b` — cạnh biến mất
        // trong im lặng. Dạng ấy hiếm nhưng hợp lệ, và im lặng bỏ một cạnh là đúng cái kiểu
        // hỏng mà cả tệp này cố tránh.
        let after = end < statement.endIndex
            ? String(statement[statement.index(after: end)...]) : ""
        return (String(statement[statement.startIndex ..< start]) + " " + after, attributes)
    }

    /// Giá trị của một thuộc tính trong chuỗi `[a=1, label="x"]`.
    static func attribute(_ name: String, in attributes: String) -> String? {
        var inString = false
        var current = ""
        var pairs: [String] = []
        for character in attributes {
            if character == "\"" { inString.toggle() }
            if !inString, character == "," {
                pairs.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        pairs.append(current)
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0].lowercased() == name else { continue }
            return unquote(parts[1])
        }
        return nil
    }

    /// Mọi cặp `khoá=giá trị` trong chuỗi `[...]`.
    static func attributeTable(_ attributes: String) -> [String: String] {
        var out: [String: String] = [:]
        var inString = false
        var current = ""
        var pairs: [String] = []
        for character in attributes {
            if character == "\"" { inString.toggle() }
            if !inString, character == "," {
                pairs.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        pairs.append(current)
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, !parts[0].isEmpty else { continue }
            out[unquote(parts[0]).lowercased()] = unquote(parts[1])
        }
        return out
    }

    static func unquote(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespaces)
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        value = String(value.dropFirst().dropLast())
        return value.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: " ")
    }

    // MARK: - Tra cứu cho đồng bộ hai chiều

    /// Dòng khai của một node — bấm node trên hình thì nhảy tới đây.
    public func line(ofNode name: String) -> Int? {
        nodes.first { $0.name == name || $0.display == name }?.line
    }

    /// Tên node nhắc tới trên một dòng — con nháy ở dòng ấy thì node tương ứng sáng lên.
    public func names(onLine line: Int) -> [String] {
        var out: [String] = []
        for node in nodes where node.line == line { out.append(node.display) }
        for edge in edges where edge.line == line {
            for name in [edge.from, edge.to] {
                let display = nodes.first { $0.name == name }?.display ?? name
                if !out.contains(display) { out.append(display) }
            }
        }
        return out
    }
}
