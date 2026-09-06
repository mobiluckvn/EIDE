import Foundation

/// Dịch Cypher sang SQL DuckDB trên bảng node/cạnh — FR-KNW-913.
///
/// ## Vì sao dịch sang SQL thay vì tự chạy đồ thị
///
/// Đặc tả nói thẳng cơ chế: *"dịch truy vấn sang SQL DuckDB trên bảng node/edge nội bộ — câu SQL
/// sinh ra **LUÔN hiển thị và sửa tiếp được** trong Query Workbench (đúng khuôn Pivot: vừa dùng
/// vừa học)"*. Ba thứ đến kèm quyết định ấy:
///
/// 1. **Người dùng học được.** Câu SQL hiện ra là một bài giảng về chính đồ thị của họ: hop là
///    phép nối, nhãn là một điều kiện, `count` là `GROUP BY`.
/// 2. **Sửa tiếp được.** Tập con Cypher ở đây hẹp; khi nó không đủ, người dùng sửa thẳng SQL
///    thay vì phải chờ một phiên bản sau.
/// 3. **Không có bộ máy đồ thị thứ hai để nuôi.** DuckDB đã ở trong sản phẩm (ADR-14).
///
/// ## Bảng node và cạnh: cột CỐ ĐỊNH, và đó là ranh giới
///
/// | Bảng | Cột |
/// |---|---|
/// | `node` | `id` · `name` (chữ hiện trên hình) · `kind` |
/// | `edge` | `source` · `target` · `type` · `label` |
///
/// Thuộc tính TUỲ Ý không có: một truy vấn hỏi `a.gia` sẽ bị từ chối kèm danh sách cột có thật.
/// Từ chối chứ không sinh SQL với một tên cột lạ, vì DuckDB sẽ báo lỗi bằng tiếng Anh về một
/// bảng người dùng chưa từng thấy — và họ sẽ đi tìm lỗi trong tệp DOT của mình.
///
/// DOT không có khái niệm "nhãn node" như Cypher. Quy ước ở đây: `kind` lấy từ thuộc tính DOT
/// `type`, không có thì `class`, không có nữa thì `shape` — xem `DOTGraph.Node.kind`. Quy ước ấy
/// được in trong phần giải thích kế hoạch, chứ không giấu.
public enum CypherSQL {

    public static let nodeTable = "node"
    public static let edgeTable = "edge"
    public static let nodeColumns = ["id", "name", "kind"]
    public static let edgeColumns = ["source", "target", "type", "label"]

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    public struct Translation: Equatable, Sendable {
        public var sql: String
        /// Giải thích kế hoạch chạy — đặc tả đòi *"kèm giải thích kế hoạch chạy"*.
        public var plan: [String]
        /// Biến node dùng trong RETURN — để tô sáng ngược lên Graph Preview.
        public var nodeVariables: [String]
        public var edgeVariables: [String]
    }

    // MARK: - Dịch

    public static func translate(_ query: CypherQuery) throws -> Translation {
        var nodeVariables: [String: Int] = [:]      // tên biến → vị trí trong mẫu
        for (position, node) in query.nodes.enumerated() where !node.variable.isEmpty {
            guard nodeVariables[node.variable] == nil else {
                throw Failure(message: "biến node «\(node.variable)» khai hai lần — mỗi node "
                    + "trong mẫu phải có tên riêng")
            }
            nodeVariables[node.variable] = position
        }
        var edgeVariables: [String: Int] = [:]
        for (position, edge) in query.edges.enumerated() where !edge.variable.isEmpty {
            guard edgeVariables[edge.variable] == nil, nodeVariables[edge.variable] == nil else {
                throw Failure(message: "biến «\(edge.variable)» trùng tên với một biến khác")
            }
            edgeVariables[edge.variable] = position
        }

        // --- FROM và JOIN ---
        var from: [String] = []
        var conditions: [String] = []
        var plan: [String] = []

        let firstAlias = alias(forNode: 0, in: query)
        from.append("\(nodeTable) AS \(firstAlias)")
        plan.append("bắt đầu từ bảng «\(nodeTable)» với bí danh \(firstAlias)")
        append(filters(for: query.nodes[0], alias: firstAlias), to: &conditions)

        for (position, edge) in query.edges.enumerated() {
            let left = alias(forNode: position, in: query)
            let right = alias(forNode: position + 1, in: query)
            let edgeAlias = alias(forEdge: position, in: query)
            // Điều kiện nối chỉ được nhắc tới những bảng ĐÃ nối trước đó — SQL không cho
            // tham chiếu tới bảng phía sau. Nên cạnh nối vào node TRÁI, rồi node PHẢI nối vào
            // cạnh. Bản đầu gộp cả hai vế vào điều kiện của cạnh và DuckDB từ chối ngay.
            let edgeJoin: String
            let nodeJoin: String
            switch edge.direction {
            case .forward:
                edgeJoin = "\(edgeAlias).source = \(left).id"
                nodeJoin = "\(right).id = \(edgeAlias).target"
            case .backward:
                edgeJoin = "\(edgeAlias).target = \(left).id"
                nodeJoin = "\(right).id = \(edgeAlias).source"
            case .any:
                // Cạnh vô hướng khớp CẢ HAI chiều. Điều kiện của node phải buộc hai vế vào
                // nhau, chứ không chỉ «id nằm ở một trong hai đầu»: không buộc thì một cạnh
                // a→b sẽ khớp cả b ở đầu kia lẫn chính a, và `count` đếm gấp đôi.
                edgeJoin = "(\(edgeAlias).source = \(left).id"
                    + " OR \(edgeAlias).target = \(left).id)"
                nodeJoin = "((\(edgeAlias).source = \(left).id"
                    + " AND \(right).id = \(edgeAlias).target)"
                    + " OR (\(edgeAlias).target = \(left).id"
                    + " AND \(right).id = \(edgeAlias).source))"
            }
            from.append("JOIN \(edgeTable) AS \(edgeAlias) ON \(edgeJoin)")
            from.append("JOIN \(nodeTable) AS \(right) ON \(nodeJoin)")
            plan.append("hop \(position + 1): nối qua «\(edgeTable)» "
                + describe(edge.direction) + " tới \(right)")
            append(filters(for: edge, alias: edgeAlias), to: &conditions)
            append(filters(for: query.nodes[position + 1], alias: right), to: &conditions)
        }

        if let condition = query.condition {
            conditions.append(try sql(for: condition, nodes: nodeVariables, edges: edgeVariables,
                                      query: query))
            plan.append("lọc theo WHERE")
        }

        // --- SELECT ---
        var projections: [String] = []
        var grouping: [String] = []
        var hasAggregate = false
        for item in query.items {
            let expression = try sql(for: item, nodes: nodeVariables, edges: edgeVariables,
                                     query: query)
            projections.append("\(expression) AS \(quoteIdentifier(item.name))")
            if item.aggregate == nil { grouping.append(expression) } else { hasAggregate = true }
        }
        var out = "SELECT " + (query.distinct ? "DISTINCT " : "")
            + projections.joined(separator: ", ")
        out += "\nFROM " + from.joined(separator: "\n     ")
        if !conditions.isEmpty {
            out += "\nWHERE " + conditions.joined(separator: "\n  AND ")
        }
        if hasAggregate, !grouping.isEmpty {
            out += "\nGROUP BY " + grouping.joined(separator: ", ")
            plan.append("gom nhóm theo " + grouping.joined(separator: ", ")
                + " vì RETURN có hàm gộp")
        }
        if !query.orders.isEmpty {
            let names = try query.orders.map { order -> String in
                guard query.items.contains(where: { $0.name == order.name }) else {
                    throw Failure(message: "ORDER BY «\(order.name)» không có trong RETURN — "
                        + "sắp theo một cột không trả về thì người đọc bảng không kiểm lại được; "
                        + "thêm nó vào RETURN (có thể kèm AS)")
                }
                return quoteIdentifier(order.name) + (order.descending ? " DESC" : " ASC")
            }
            out += "\nORDER BY " + names.joined(separator: ", ")
        }
        if let limit = query.limit { out += "\nLIMIT \(limit)" }
        if let skip = query.skip { out += "\nOFFSET \(skip)" }

        plan.append("\(query.hops) hop / trần \(CypherQuery.maximumHops)")
        plan.append("bảng «\(nodeTable)» có cột " + nodeColumns.joined(separator: ", ")
            + "; bảng «\(edgeTable)» có cột " + edgeColumns.joined(separator: ", ")
            + ". Thuộc tính tuỳ ý của DOT KHÔNG thành cột — «kind» lấy từ thuộc tính `type`, "
            + "không có thì `class`, không có nữa thì `shape`.")

        return Translation(
            sql: out, plan: plan,
            nodeVariables: query.nodes.map(\.variable).filter { !$0.isEmpty },
            edgeVariables: query.edges.map(\.variable).filter { !$0.isEmpty })
    }

    private static func describe(_ direction: CypherQuery.Direction) -> String {
        switch direction {
        case .forward: return "theo chiều đi"
        case .backward: return "theo chiều ngược"
        case .any: return "KHÔNG phân biệt chiều"
        }
    }

    private static func append(_ items: [String], to list: inout [String]) {
        list.append(contentsOf: items)
    }

    /// Bí danh SQL của node thứ `position`.
    ///
    /// Node vô danh vẫn cần bí danh để nối được, nên nó nhận `_n0`, `_n1`… Tiền tố gạch dưới để
    /// không bao giờ đụng tên biến người dùng đặt.
    static func alias(forNode position: Int, in query: CypherQuery) -> String {
        let variable = query.nodes[position].variable
        return variable.isEmpty ? "_n\(position)" : quoteIdentifier(variable)
    }

    static func alias(forEdge position: Int, in query: CypherQuery) -> String {
        let variable = query.edges[position].variable
        return variable.isEmpty ? "_e\(position)" : quoteIdentifier(variable)
    }

    private static func filters(for node: CypherQuery.NodePattern, alias: String) -> [String] {
        var out: [String] = []
        if let label = node.label { out.append("\(alias).kind = \(literal(.text(label)))") }
        for property in node.properties where nodeColumns.contains(property.key) {
            out.append("\(alias).\(property.key) = \(literal(property.value))")
        }
        // Thuộc tính không phải cột: bỏ qua ở đây, và `sql(for:)` sẽ từ chối nếu nó xuất hiện
        // trong WHERE/RETURN. Trong `{…}` thì nó không có nghĩa nào khác ngoài "không khớp gì",
        // nên trả một điều kiện luôn SAI thay vì lặng lẽ bỏ.
        for property in node.properties where !nodeColumns.contains(property.key) {
            out.append("FALSE /* «\(property.key)» không phải cột của node */")
        }
        return out
    }

    private static func filters(for edge: CypherQuery.EdgePattern, alias: String) -> [String] {
        var out: [String] = []
        if let type = edge.type { out.append("\(alias).type = \(literal(.text(type)))") }
        for property in edge.properties where edgeColumns.contains(property.key) {
            out.append("\(alias).\(property.key) = \(literal(property.value))")
        }
        for property in edge.properties where !edgeColumns.contains(property.key) {
            out.append("FALSE /* «\(property.key)» không phải cột của cạnh */")
        }
        return out
    }

    // MARK: - Điều kiện

    private static func sql(
        for condition: CypherQuery.Condition,
        nodes: [String: Int], edges: [String: Int], query: CypherQuery
    ) throws -> String {
        switch condition {
        case let .compare(variable, property, op, value):
            let column = try resolve(variable: variable, property: property,
                                     nodes: nodes, edges: edges, query: query)
            switch op {
            case .contains:
                return "\(column) LIKE '%' || \(literal(value)) || '%'"
            case .startsWith:
                return "\(column) LIKE \(literal(value)) || '%'"
            case .endsWith:
                return "\(column) LIKE '%' || \(literal(value))"
            default:
                if case .null = value {
                    throw Failure(message: "so sánh với null bằng «\(op.rawValue)» luôn cho "
                        + "null — dùng «IS NULL» hoặc «IS NOT NULL»")
                }
                return "\(column) \(op.rawValue) \(literal(value))"
            }
        case let .isNull(variable, property, negated):
            let column = try resolve(variable: variable, property: property,
                                     nodes: nodes, edges: edges, query: query)
            return "\(column) IS \(negated ? "NOT " : "")NULL"
        case let .and(left, right):
            return "(" + (try sql(for: left, nodes: nodes, edges: edges, query: query))
                + " AND " + (try sql(for: right, nodes: nodes, edges: edges, query: query)) + ")"
        case let .or(left, right):
            return "(" + (try sql(for: left, nodes: nodes, edges: edges, query: query))
                + " OR " + (try sql(for: right, nodes: nodes, edges: edges, query: query)) + ")"
        case let .not(inner):
            return "NOT (" + (try sql(for: inner, nodes: nodes, edges: edges, query: query)) + ")"
        }
    }

    private static func sql(
        for item: CypherQuery.ReturnItem,
        nodes: [String: Int], edges: [String: Int], query: CypherQuery
    ) throws -> String {
        if item.isStar { return "count(*)" }
        let column: String
        if let property = item.property {
            column = try resolve(variable: item.variable, property: property,
                                 nodes: nodes, edges: edges, query: query)
        } else {
            // `RETURN a` trả về CHỮ HIỆN TRÊN NODE, không trả về id.
            //
            // Người dùng đọc bảng kết quả cạnh sơ đồ, và thứ họ đối chiếu là chữ trên hình.
            // Trả id thì với một tệp DOT dùng `n1`, `n2` làm tên, cả bảng là những con số.
            column = try resolve(variable: item.variable, property:
                                    nodes[item.variable] != nil ? "name" : "label",
                                 nodes: nodes, edges: edges, query: query)
        }
        guard let aggregate = item.aggregate else { return column }
        switch aggregate {
        case .count: return "count(\(column))"
        // `collect` của Cypher trả về một DANH SÁCH; ở đây nó thành một chuỗi nối bằng dấu
        // phẩy. Không phải vì tiện: bảng kết quả hiện chữ, và cột kiểu LIST của DuckDB đi qua
        // lớp chuyển giá trị của sản phẩm này thành NULL — tức người dùng thấy một cột rỗng và
        // tưởng không có dữ liệu. Một chuỗi đọc được thì thấy được, và nói ra ở đây là đủ.
        case .collect: return "string_agg(\(column), ', ')"
        }
    }

    /// Quy `biến.thuộc_tính` về một cột SQL, hoặc TỪ CHỐI kèm danh sách cột có thật.
    private static func resolve(
        variable: String, property: String,
        nodes: [String: Int], edges: [String: Int], query: CypherQuery
    ) throws -> String {
        if let position = nodes[variable] {
            guard nodeColumns.contains(property) else {
                throw Failure(message: "node «\(variable)» không có thuộc tính «\(property)» — "
                    + "bảng node chỉ có: " + nodeColumns.joined(separator: ", "))
            }
            return "\(alias(forNode: position, in: query)).\(property)"
        }
        if let position = edges[variable] {
            guard edgeColumns.contains(property) else {
                throw Failure(message: "cạnh «\(variable)» không có thuộc tính «\(property)» — "
                    + "bảng edge chỉ có: " + edgeColumns.joined(separator: ", "))
            }
            return "\(alias(forEdge: position, in: query)).\(property)"
        }
        let known = (nodes.keys.sorted() + edges.keys.sorted()).joined(separator: ", ")
        throw Failure(message: "biến «\(variable)» không có trong MATCH"
            + (known.isEmpty ? "" : " — mẫu khai: \(known)"))
    }

    // MARK: - Chuỗi an toàn

    /// Giá trị nhúng thẳng vào SQL, có thoát dấu nháy.
    ///
    /// Nhúng thẳng chứ không tham số hoá vì câu SQL phải **đọc được và sửa được** trong Query
    /// Workbench — một câu đầy dấu `?` thì không sửa tiếp được, và cả điểm của FR-KNW-913 là
    /// người dùng đọc được nó.
    ///
    /// Cái giá là phải thoát cho đúng: dấu nháy đơn nhân đôi, đúng luật SQL chuẩn.
    static func literal(_ value: CypherQuery.Value) -> String {
        switch value {
        case let .text(text):
            return "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
        case let .number(number):
            return number == number.rounded() && abs(number) < 1e15
                ? String(Int(number)) : String(number)
        case let .boolean(flag):
            return flag ? "TRUE" : "FALSE"
        case .null:
            return "NULL"
        }
    }

    /// Định danh SQL, bọc nháy kép và nhân đôi nháy kép bên trong.
    static func quoteIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Bảng node/cạnh từ một đồ thị

    /// Ghi hai tệp CSV `node.csv` và `edge.csv` vào `folder`, trả về bản đồ tên bảng → đường dẫn.
    ///
    /// CSV chứ không phải bảng trong bộ nhớ, vì `CSVQueryEngine` đăng ký nguồn phụ bằng đường
    /// dẫn tệp — cùng đường mà FR-CSV-407 đã dùng cho danh mục bảng ảo. Một đường thứ hai để
    /// nạp dữ liệu vào DuckDB là một đường thứ hai phải nuôi.
    public static func materialize(
        _ graph: DOTGraph, in folder: String
    ) throws -> [String: String] {
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        var nodeCSV = "id,name,kind\n"
        for node in graph.nodes {
            nodeCSV += [node.name, node.display, node.kind ?? ""]
                .map(csvField).joined(separator: ",") + "\n"
        }
        var edgeCSV = "source,target,type,label\n"
        for edge in graph.edges {
            edgeCSV += [edge.from, edge.to, "", edge.label ?? ""]
                .map(csvField).joined(separator: ",") + "\n"
        }
        let nodePath = (folder as NSString).appendingPathComponent("node.csv")
        let edgePath = (folder as NSString).appendingPathComponent("edge.csv")
        try AtomicFileWriter.write(Array(nodeCSV.utf8), to: nodePath)
        try AtomicFileWriter.write(Array(edgeCSV.utf8), to: edgePath)
        return [nodeTable: nodePath, edgeTable: edgePath]
    }

    static func csvField(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
