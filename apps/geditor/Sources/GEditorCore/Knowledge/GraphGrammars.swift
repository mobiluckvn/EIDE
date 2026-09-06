import Foundation

/// Tô màu và thẩm định cú pháp cho bốn định dạng đồ thị — FR-KNW-904.
///
/// Đặc tả kể năm định dạng: **DOT/Graphviz, Mermaid, Cypher, RDF Turtle, GraphML**. Mermaid đã
/// có grammar riêng từ FR-MMD-006 (`MermaidGrammar`), nên tệp này thêm bốn cái còn lại và
/// **không** viết lại cái thứ năm.
///
/// ## Tô màu bằng UDL, thẩm định bằng bộ đọc THẬT
///
/// Hai việc khác nhau, và gộp chúng là sai. `UserDefinedLanguage` là bộ quét TỪ VỰNG: nó biết
/// «digraph» là từ khoá, không biết dấu ngoặc có đóng hay chưa. Dùng nó để báo lỗi cú pháp thì
/// hoặc không bắt được gì, hoặc kêu oan.
///
/// Nên thẩm định đi qua **bộ đọc thật đã có sẵn trong kho**: `DOTGraph` cho DOT, `CypherQuery`
/// cho Cypher, `LibXML2` cho GraphML. Chỉ Turtle là không có bộ đọc nào, nên nó có một bộ kiểm
/// nhẹ và **nói thẳng ra rằng nó nhẹ** — xem `validateTurtle`.
///
/// ## Vì sao không viết grammar tree-sitter
///
/// Cùng lập luận đã ghi ở `MermaidGrammar`: đổi lại là năm grammar tree-sitter phải build riêng
/// và nuôi riêng, cho những định dạng mà thứ người đọc cần phân biệt chỉ là *từ khoá / chuỗi /
/// chú thích*. Cái giá không đáng.
public enum GraphGrammars {

    /// Bốn ngôn ngữ, nối vào sau danh sách của người dùng nên tệp `grammars/*.json` của họ thắng.
    public static let languages: [UserDefinedLanguage] = [dot, cypher, turtle, graphml]

    // MARK: - DOT / Graphviz

    public static let dot = UserDefinedLanguage(
        name: "Graphviz DOT",
        extensions: ["dot", "gv"],
        keywordGroups: [
            "keyword": ["digraph", "graph", "subgraph", "strict", "node", "edge"],
            // Thuộc tính hay gặp nhất — tô khác từ khoá vì chúng nằm ở tầng khác của cú pháp.
            "type": [
                "label", "shape", "color", "fillcolor", "style", "fontname", "fontsize",
                "rankdir", "rank", "weight", "dir", "arrowhead", "penwidth", "cluster",
            ],
            "constant": [
                "box", "ellipse", "circle", "diamond", "plaintext", "record", "none",
                "filled", "dashed", "dotted", "bold", "invis", "true", "false",
                "TB", "LR", "BT", "RL", "same", "min", "max", "source", "sink",
            ],
        ],
        caseSensitive: true,
        lineComment: "//",
        blockComment: ["/*", "*/"],
        stringDelimiters: ["\""],
        escapeCharacter: "\\"
    )

    // MARK: - Cypher

    /// Cypher KHÔNG phân biệt hoa thường ở từ khoá — `MATCH` và `match` là một.
    ///
    /// Khai `caseSensitive: false` là bắt buộc chứ không phải tiện: người ta gõ Cypher cả hai
    /// kiểu, và một nửa file không được tô màu trông như một nửa file bị hỏng.
    public static let cypher = UserDefinedLanguage(
        name: "Cypher",
        extensions: ["cypher", "cql"],
        keywordGroups: [
            "keyword": [
                "match", "optional", "where", "return", "with", "order", "by", "skip",
                "limit", "unwind", "create", "merge", "set", "delete", "detach", "remove",
                "call", "yield", "union", "as", "distinct", "asc", "desc", "on",
            ],
            "type": ["count", "collect", "sum", "avg", "min", "max", "size", "labels",
                     "type", "id", "keys", "properties", "toString", "toInteger"],
            "constant": ["true", "false", "null", "and", "or", "not", "xor", "in", "is",
                         "starts", "ends", "contains"],
        ],
        caseSensitive: false,
        lineComment: "//",
        blockComment: ["/*", "*/"],
        stringDelimiters: ["\"", "'"],
        escapeCharacter: "\\"
    )

    // MARK: - RDF Turtle

    public static let turtle = UserDefinedLanguage(
        name: "RDF Turtle",
        extensions: ["ttl", "turtle"],
        keywordGroups: [
            "keyword": ["@prefix", "@base", "prefix", "base"],
            "constant": ["a", "true", "false"],
        ],
        caseSensitive: false,
        lineComment: "#",
        blockComment: nil,
        stringDelimiters: ["\"", "'"],
        escapeCharacter: "\\"
    )

    // MARK: - GraphML

    public static let graphml = UserDefinedLanguage(
        name: "GraphML",
        extensions: ["graphml"],
        keywordGroups: [
            "keyword": ["graphml", "graph", "node", "edge", "key", "data", "hyperedge",
                        "port", "endpoint", "desc", "default"],
            "type": ["id", "source", "target", "directed", "edgedefault", "for",
                     "attr.name", "attr.type"],
        ],
        caseSensitive: true,
        lineComment: nil,
        blockComment: ["<!--", "-->"],
        stringDelimiters: ["\"", "'"],
        escapeCharacter: ""
    )

    // MARK: - Thẩm định

    public struct Diagnostic: Equatable, Sendable {
        /// Dòng 0-BASED — cùng quy ước `DOTGraph.line` và `GraphSchema.Violation.line`.
        ///
        /// Ghi lại ở đây vì đây là lớp thứ ba mang số dòng, và một quy ước không được ghi là
        /// cách lỗi "nhảy lệch một dòng" ra đời.
        public let line: Int
        public let message: String
    }

    public enum Kind: String, CaseIterable, Sendable {
        case dot, cypher, turtle, graphml

        /// Nhận ra theo ĐUÔI FILE. Trả `nil` khi không biết — đoán bừa thì một tệp `.txt` bị
        /// thẩm định theo luật Cypher và báo hàng loạt lỗi vô nghĩa.
        public static func forPath(_ path: String) -> Kind? {
            switch (path as NSString).pathExtension.lowercased() {
            case "dot", "gv": return .dot
            case "cypher", "cql": return .cypher
            case "ttl", "turtle": return .turtle
            case "graphml": return .graphml
            default: return nil
            }
        }
    }

    public static func validate(_ text: String, kind: Kind) -> [Diagnostic] {
        switch kind {
        case .dot:
            // Bộ đọc THẬT, không phải một phép kiểm riêng: `DOTGraph` đã ghi mọi thứ nó bỏ qua
            // vào `warnings` kèm số dòng, và một phép kiểm thứ hai sẽ trôi khỏi nó.
            return DOTGraph.parse(text).warnings.map {
                Diagnostic(line: $0.line, message: $0.message)
            }
        case .cypher:
            do {
                _ = try CypherQuery.parse(text)
                return []
            } catch {
                // `CypherQuery` báo lỗi cho CẢ câu, không theo dòng. Quy về dòng đầu tiên có
                // chữ thay vì dòng 0: một câu Cypher hay đứng sau vài dòng chú thích, và neo
                // lỗi vào dòng trống đầu tệp là chỉ sai chỗ.
                let dong = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .firstIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? 0
                return [Diagnostic(line: dong, message: "\(error)")]
            }
        case .turtle:
            return validateTurtle(text)
        case .graphml:
            return validateXML(text)
        }
    }

    /// Kiểm Turtle ở mức NHẸ, và nói thẳng ra là nhẹ.
    ///
    /// Kho không có bộ đọc Turtle đầy đủ, và viết một cái cho đúng đặc tả W3C là một dự án riêng
    /// (prefix, collection, blank node lồng nhau, literal ba nháy, kiểu dữ liệu). Cái ở đây bắt
    /// đúng ba lỗi hay gặp nhất khi người ta gõ tay:
    ///
    /// - câu không kết thúc bằng `.` `;` hay `,`;
    /// - dùng một prefix chưa khai;
    /// - dấu nháy không đóng.
    ///
    /// Nó **không** kết luận "tệp này hợp lệ" — chỉ kết luận "không thấy ba lỗi kia". Khác biệt
    /// ấy phải nói ra, vì một danh sách lỗi RỖNG rất dễ đọc thành một lời bảo đảm.
    static func validateTurtle(_ text: String) -> [Diagnostic] {
        var out: [Diagnostic] = []
        var daKhai: Set<String> = []
        for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.lowercased().hasPrefix("@prefix") || line.lowercased().hasPrefix("prefix") {
                if let r = line.range(of: ":") {
                    let ten = line[..<r.lowerBound].split(separator: " ").last.map(String.init) ?? ""
                    daKhai.insert(ten)
                }
                continue
            }

            if line.filter({ $0 == "\"" }).count % 2 != 0 {
                out.append(Diagnostic(line: i, message: "dấu nháy không đóng"))
            }
            if let cuoi = line.last, !".;,".contains(cuoi) {
                out.append(Diagnostic(line: i, message: "câu phải kết thúc bằng «.», «;» hoặc «,»"))
            }
            // Prefix dùng mà chưa khai. Bỏ qua phần trong dấu nháy để một literal chứa dấu hai
            // chấm không bị đọc thành prefix.
            let ngoaiNhay = line.split(separator: "\"").enumerated()
                .filter { $0.offset % 2 == 0 }.map(\.element).joined(separator: " ")
            for tu in ngoaiNhay.split(whereSeparator: { " \t<>[](),;.".contains($0) }) {
                guard let r = tu.firstIndex(of: ":"), r != tu.startIndex else { continue }
                let ten = String(tu[..<r])
                if !daKhai.contains(ten), !ten.contains("//") {
                    out.append(Diagnostic(line: i, message: "prefix «\(ten):» chưa khai báo"))
                }
            }
        }
        return out
    }

    /// GraphML là XML, nên dùng bộ đọc XML của hệ thống thay vì tự đếm thẻ.
    static func validateXML(_ text: String) -> [Diagnostic] {
        do {
            _ = try XMLDocument(xmlString: text, options: [])
            return []
        } catch {
            // `XMLDocument` gói số dòng trong `userInfo`; không có thì về dòng 0 và nói nguyên
            // văn lỗi — nguyên văn vẫn tra được, một câu chung chung thì không.
            let ns = error as NSError
            let dong = (ns.userInfo["NSXMLParserErrorLineNumber"] as? Int).map { $0 - 1 } ?? 0
            return [Diagnostic(line: max(dong, 0), message: ns.localizedDescription)]
        }
    }
}
