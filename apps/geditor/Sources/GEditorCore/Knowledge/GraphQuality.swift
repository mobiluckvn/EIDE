import Foundation

/// Chấm sức khoẻ đồ thị theo khung FR-DQR — FR-KNW-924.
///
/// Đặc tả: *"node mồ côi (degree 0), cạnh trùng lặp, cạnh dangling (endpoint chưa khai báo), vi
/// phạm schema (nếu có YAML FR-KNW-917), số đảo rời (connected components — đảo nhiều là corpus
/// thiếu liên kết), thuộc tính bắt buộc thiếu, nhãn node trùng gần (fuzzy). Ra scorecard + danh
/// sách lỗi click-nhảy-dòng."*
///
/// ## Ánh xạ sang sáu chiều DQR-002
///
/// | Chiều | Đo bằng | Vì sao ánh xạ như vậy |
/// |---|---|---|
/// | Đầy đủ | thuộc tính bắt buộc thiếu | node/cạnh khai rồi mà không có thuộc tính đã hứa |
/// | Hợp lệ | cạnh dangling | cạnh trỏ tới node chưa khai — một cạnh không dùng được |
/// | Không trùng | cạnh trùng lặp + nhãn trùng gần | cùng một quan hệ khai hai lần; cùng một thực thể mang hai tên |
/// | Nhất quán | số đảo rời | một kho tri thức vỡ thành mười mảnh thì mười mảnh ấy không nói chuyện với nhau |
/// | Chính xác (ước lượng) | node mồ côi | node không nối với gì thường là node khai thừa hoặc khai sai tên |
/// | Tươi mới | — | **KHÔNG chấm được**: DOT không khai ngày |
///
/// Chiều TƯƠI MỚI trả `nil` chứ không trả 100, đúng luật của khung — cùng lý do đã ghi ở
/// `ChunkQuality`. Một đồ thị được cho 100 điểm "tươi mới" vì không ai biết nó cũ bao nhiêu là
/// một điểm số nói dối theo hướng có lợi.
///
/// ## Vi phạm schema: cái gì kiểm được HÔM NAY
///
/// `Config.requiredNodeKeys` và `requiredEdgeKeys` cho khai **thuộc tính bắt buộc** ngay trong
/// khối — đủ cho vế "thuộc tính bắt buộc thiếu" của đặc tả.
///
/// Vế "vi phạm schema" đầy đủ (kiểu, quan hệ cho phép giữa hai nhãn) nay có ở `GraphSchema`
/// (FR-KNW-917, 28/08/2026), nhưng nó đọc một tệp YAML **rời** và báo cáo này **cố ý không tự
/// đi tìm tệp ấy**: một báo cáo âm thầm nạp thêm luật từ một chỗ nào đó là báo cáo không tái lập
/// được — chạy lại trên máy khác cho điểm khác mà không ai biết vì sao. Ranh giới ấy vẫn được
/// NÓI RA trong phần Phương pháp.
public enum GraphQuality {

    public struct Config: Equatable, Sendable {
        /// Thuộc tính mọi node phải có.
        public var requiredNodeKeys: [String]
        /// Thuộc tính mọi cạnh phải có.
        public var requiredEdgeKeys: [String]
        /// Ngưỡng giống nhau để gọi hai nhãn là trùng gần.
        public var labelSimilarity: Double
        /// Trần số nhãn đưa vào phép so mờ. 0 = không trần.
        public var fuzzyLimit: Int

        public init(
            requiredNodeKeys: [String] = [], requiredEdgeKeys: [String] = [],
            labelSimilarity: Double = 0.85, fuzzyLimit: Int = 5_000
        ) {
            self.requiredNodeKeys = requiredNodeKeys
            self.requiredEdgeKeys = requiredEdgeKeys
            self.labelSimilarity = min(1, max(0.5, labelSimilarity))
            self.fuzzyLimit = max(0, fuzzyLimit)
        }
    }

    /// Một lỗi, kèm DÒNG để bấm nhảy tới — đặc tả đòi "danh sách lỗi click-nhảy-dòng".
    public struct Problem: Equatable, Sendable {
        public enum Kind: String, Equatable, Sendable {
            case orphan, duplicateEdge, danglingEdge, missingNodeKey, missingEdgeKey, nearLabel

            public var vietnamese: String {
                switch self {
                case .orphan: return "node mồ côi"
                case .duplicateEdge: return "cạnh trùng lặp"
                case .danglingEdge: return "cạnh trỏ tới node chưa khai"
                case .missingNodeKey: return "node thiếu thuộc tính bắt buộc"
                case .missingEdgeKey: return "cạnh thiếu thuộc tính bắt buộc"
                case .nearLabel: return "nhãn node trùng gần"
                }
            }
        }
        public var kind: Kind
        /// Dòng trong tệp DOT, 0-based.
        public var line: Int
        public var detail: String
    }

    public struct Report: Equatable, Sendable {
        public var nodeCount: Int
        public var edgeCount: Int
        public var problems: [Problem]
        public var orphans: [String]
        public var duplicateEdges: Int
        public var danglingEdges: Int
        public var islands: Int
        public var largestIsland: Int
        public var nearLabelGroups: [[String]]
        public var missingNodeKeys: Int
        public var missingEdgeKeys: Int
        public var fuzzySkipped: Int?
        public var config: Config
        public var score: QualityScore

        public func problems(of kind: Problem.Kind) -> [Problem] {
            problems.filter { $0.kind == kind }
        }
    }

    // MARK: - Chạy

    public static func run(
        _ graph: DOTGraph, config: Config = Config(), now: Date = Date(),
        cancelToken: CancelToken? = nil
    ) -> Report {
        var problems: [Problem] = []
        let csr = GraphCSR(graph)
        let lineOfNode = Dictionary(
            graph.nodes.map { ($0.name, $0.line) }, uniquingKeysWith: { first, _ in first })

        // --- Cạnh dangling: trỏ tới node CHƯA KHAI ---
        //
        // DOT tự khai node khi nó xuất hiện trong một cạnh, nên "chưa khai" ở đây nghĩa là
        // KHÔNG có câu lệnh khai riêng cho nó. Đó đúng là thứ đặc tả hỏi: một cạnh trỏ tới một
        // cái tên mà không ai định nghĩa là một cạnh không dùng được.
        var declared = Set<String>()
        for node in graph.nodes where !node.attributes.isEmpty || node.label != nil {
            declared.insert(node.name)
        }
        // Đồ thị KHÔNG khai node nào có thuộc tính thì mọi node đều "chưa khai" — vô nghĩa. Khi
        // ấy coi như mọi node đã khai và chiều HỢP LỆ trả `nil` kèm lý do.
        let hasDeclarations = !declared.isEmpty
        var dangling = 0
        if hasDeclarations {
            for edge in graph.edges {
                for endpoint in [edge.from, edge.to] where !declared.contains(endpoint) {
                    dangling += 1
                    problems.append(Problem(
                        kind: .danglingEdge, line: edge.line,
                        detail: "«\(endpoint)» chỉ xuất hiện trong cạnh, không có câu lệnh khai"))
                }
            }
        }

        // --- Cạnh trùng lặp ---
        //
        // Trùng = cùng cặp đầu-cuối. Trên đồ thị VÔ HƯỚNG thì `a -- b` và `b -- a` là một, nên
        // khoá được sắp lại; trên đồ thị có hướng thì chúng là hai cạnh khác nhau.
        var seenEdges: [String: Int] = [:]
        var duplicates = 0
        for edge in graph.edges {
            let key = graph.isDirected
                ? "\(edge.from)\u{1}\(edge.to)"
                : [edge.from, edge.to].sorted().joined(separator: "\u{1}")
            if let first = seenEdges[key] {
                duplicates += 1
                problems.append(Problem(
                    kind: .duplicateEdge, line: edge.line,
                    detail: "«\(edge.from)» → «\(edge.to)» đã khai ở dòng \(first + 1)"))
            } else {
                seenEdges[key] = edge.line
            }
        }

        // --- Node mồ côi ---
        var orphans: [String] = []
        for node in 0 ..< csr.nodeCount where csr.degree(node) == 0 {
            orphans.append(csr.names[node])
            problems.append(Problem(
                kind: .orphan, line: lineOfNode[csr.names[node]] ?? 0,
                detail: "«\(csr.displays[node])» không nối với node nào"))
        }

        // --- Đảo rời ---
        let components = GraphAlgorithms.connectedComponents(in: csr, cancelToken: cancelToken)

        // --- Thuộc tính bắt buộc ---
        var missingNode = 0
        for node in graph.nodes {
            for key in config.requiredNodeKeys where node.attributes[key.lowercased()] == nil {
                missingNode += 1
                problems.append(Problem(
                    kind: .missingNodeKey, line: node.line,
                    detail: "«\(node.name)» thiếu thuộc tính «\(key)»"))
            }
        }
        var missingEdge = 0
        for edge in graph.edges {
            for key in config.requiredEdgeKeys where edge.attributes[key.lowercased()] == nil {
                missingEdge += 1
                problems.append(Problem(
                    kind: .missingEdgeKey, line: edge.line,
                    detail: "cạnh «\(edge.from)» → «\(edge.to)» thiếu thuộc tính «\(key)»"))
            }
        }

        // --- Nhãn trùng gần ---
        var nearGroups: [[String]] = []
        var fuzzySkipped: Int?
        if config.fuzzyLimit > 0 && graph.nodes.count > config.fuzzyLimit {
            fuzzySkipped = graph.nodes.count
        } else {
            let labels = graph.nodes.map(\.display)
            for group in TextDistance.clusters(
                labels, threshold: config.labelSimilarity, cancelToken: cancelToken) {
                nearGroups.append(group.map { labels[$0] })
                // Báo ở dòng của node ĐẦU TIÊN trong cụm: người dùng bấm rồi tự thấy cả cụm
                // trong chi tiết, và một cụm ba node mà báo ba dòng thì bảng lỗi phồng lên gấp ba.
                problems.append(Problem(
                    kind: .nearLabel, line: graph.nodes[group[0]].line,
                    detail: group.map { "«\(labels[$0])»" }.joined(separator: " ≈ ")))
            }
        }

        problems.sort {
            $0.line != $1.line ? $0.line < $1.line : $0.kind.rawValue < $1.kind.rawValue
        }

        let score = self.score(
            graph: graph, config: config, hasDeclarations: hasDeclarations,
            dangling: dangling, duplicates: duplicates, orphans: orphans.count,
            components: components, missingNode: missingNode, missingEdge: missingEdge,
            nearGroups: nearGroups, fuzzySkipped: fuzzySkipped, now: now)

        return Report(
            nodeCount: graph.nodes.count, edgeCount: graph.edges.count, problems: problems,
            orphans: orphans, duplicateEdges: duplicates, danglingEdges: dangling,
            islands: components.count, largestIsland: components.sizes.first ?? 0,
            nearLabelGroups: nearGroups, missingNodeKeys: missingNode,
            missingEdgeKeys: missingEdge, fuzzySkipped: fuzzySkipped, config: config,
            score: score)
    }

    // MARK: - Điểm

    static func score(
        graph: DOTGraph, config: Config, hasDeclarations: Bool,
        dangling: Int, duplicates: Int, orphans: Int,
        components: GraphAlgorithms.Components, missingNode: Int, missingEdge: Int,
        nearGroups: [[String]], fuzzySkipped: Int?, now: Date
    ) -> QualityScore {
        let nodes = Double(max(graph.nodes.count, 1))
        let edges = Double(max(graph.edges.count, 1))
        var dimensions: [QualityScore.DimensionScore] = []
        // Trọng số ĐỀU, cùng lý do đã ghi ở `ChunkQuality`: bịa một bộ trọng số lệch là bịa ra
        // một phán xét mà không ai ký tên.
        let weight = 1.0

        // --- Đầy đủ ---
        let required = config.requiredNodeKeys.count + config.requiredEdgeKeys.count
        if required == 0 {
            dimensions.append(.init(
                dimension: .completeness, value: nil,
                formula: "100 × (số ô thuộc tính bắt buộc CÓ) ÷ (số ô phải có)",
                detail: "—",
                note: "khối không khai «require_node» hay «require_edge», nên không có thuộc "
                    + "tính nào bắt buộc để mà thiếu",
                weight: weight))
        } else {
            let slots = Double(config.requiredNodeKeys.count) * nodes
                + Double(config.requiredEdgeKeys.count) * edges
            let missing = Double(missingNode + missingEdge)
            dimensions.append(.init(
                dimension: .completeness, value: 100 * (slots - missing) / slots,
                formula: "100 × (số ô thuộc tính bắt buộc CÓ) ÷ (số ô phải có)",
                detail: "100 × (\(Int(slots)) − \(Int(missing))) ÷ \(Int(slots))",
                weight: weight))
        }

        // --- Hợp lệ ---
        if !hasDeclarations {
            dimensions.append(.init(
                dimension: .validity, value: nil,
                formula: "100 × (số đầu cạnh trỏ tới node ĐÃ KHAI) ÷ (tổng số đầu cạnh)",
                detail: "—",
                note: "không node nào có câu lệnh khai riêng, nên «chưa khai» không phân biệt "
                    + "được với «khai ngầm trong cạnh»",
                weight: weight))
        } else {
            let endpoints = edges * 2
            dimensions.append(.init(
                dimension: .validity,
                value: 100 * (endpoints - Double(dangling)) / endpoints,
                formula: "100 × (số đầu cạnh trỏ tới node ĐÃ KHAI) ÷ (tổng số đầu cạnh)",
                detail: "100 × (\(Int(endpoints)) − \(dangling)) ÷ \(Int(endpoints))",
                weight: weight))
        }

        // --- Không trùng ---
        if let skipped = fuzzySkipped {
            dimensions.append(.init(
                dimension: .uniqueness, value: nil,
                formula: "100 × (1 − (cạnh trùng + node trong cụm nhãn trùng gần) ÷ (cạnh + node))",
                detail: "—",
                note: "đồ thị có \(skipped) node, vượt trần «fuzzy_limit» = \(config.fuzzyLimit) "
                    + "cho phép so nhãn mờ. Nâng trần (hoặc đặt 0 để bỏ) thì chấm được — phép "
                    + "so mờ là O(n²) sau lọc độ dài",
                weight: weight))
        } else {
            let duplicated = Double(duplicates + nearGroups.reduce(0) { $0 + $1.count })
            let total = nodes + edges
            dimensions.append(.init(
                dimension: .uniqueness, value: 100 * (total - duplicated) / total,
                formula: "100 × (1 − (cạnh trùng + node trong cụm nhãn trùng gần) ÷ (cạnh + node))",
                detail: "100 × (\(Int(total)) − \(Int(duplicated))) ÷ \(Int(total))"
                    + " · \(duplicates) cạnh trùng · \(nearGroups.count) cụm nhãn gần "
                    + "(ngưỡng \(String(format: "%.2f", config.labelSimilarity)))",
                weight: weight))
        }

        // --- Nhất quán: đảo rời ---
        //
        // Tỷ lệ node nằm trong đảo LỚN NHẤT. Một kho tri thức vỡ thành mười mảnh thì mười mảnh
        // ấy không nói chuyện với nhau, và mọi phép đi đường trên đó chỉ đi được trong một mảnh.
        if graph.nodes.isEmpty {
            dimensions.append(.init(
                dimension: .consistency, value: nil,
                formula: "100 × (số node trong đảo lớn nhất) ÷ (tổng số node)",
                detail: "—", note: "đồ thị không có node nào", weight: weight))
        } else {
            let largest = Double(components.sizes.first ?? 0)
            dimensions.append(.init(
                dimension: .consistency, value: 100 * largest / nodes,
                formula: "100 × (số node trong đảo lớn nhất) ÷ (tổng số node)",
                detail: "100 × \(Int(largest)) ÷ \(Int(nodes)) · \(components.count) đảo"
                    + (components.isolatedCount > 0
                        ? " · \(components.isolatedCount) đảo chỉ một node" : ""),
                weight: weight))
        }

        // --- Chính xác (ước lượng): node mồ côi ---
        dimensions.append(.init(
            dimension: .accuracy, value: 100 * (nodes - Double(orphans)) / nodes,
            formula: "100 × (số node CÓ ít nhất một cạnh) ÷ (tổng số node)",
            detail: "100 × (\(Int(nodes)) − \(orphans)) ÷ \(Int(nodes))",
            weight: weight))

        // --- Tươi mới ---
        dimensions.append(.init(
            dimension: .timeliness, value: nil, formula: "—", detail: "—",
            note: "DOT không khai ngày, và đoán tuổi từ mtime của tệp là đoán tuổi của LẦN GHI "
                + "chứ không phải của nội dung",
            weight: weight))

        return QualityScore(
            dimensions: dimensions, rowCount: graph.nodes.count, evaluatedAt: now)
    }

    /// Khối Phương pháp — nói ra cả cái CHƯA kiểm được.
    public static func methodology(_ report: Report) -> String {
        var parts = [
            "Bảy phép kiểm trên cấu trúc đồ thị, không dùng mô hình nào.",
            "«Chưa khai» nghĩa là node không có câu lệnh khai riêng — DOT tự sinh node khi nó "
                + "xuất hiện trong một cạnh.",
            "«Trùng gần» dùng khoảng cách Levenshtein sau khi bỏ dấu và hạ chữ thường, ngưỡng "
                + String(format: "%.2f", report.config.labelSimilarity) + ".",
        ]
        // Ranh giới vẫn phải nói ra — chỉ đổi NỘI DUNG, không bỏ đi. Từ FR-KNW-917 (28/08/2026)
        // đã có `GraphSchema` kiểm kiểu và quan hệ cho phép, nhưng nó là một tệp YAML RỜI mà báo
        // cáo này không tự đi tìm: một báo cáo âm thầm nạp thêm luật ở đâu đó là báo cáo không
        // tái lập được. Nên chỗ này nói rõ nó kiểm tới đâu và chỉ sang chỗ kiểm nốt.
        parts.append("⚠ Báo cáo này kiểm THUỘC TÍNH BẮT BUỘC khai trong khối. Vi phạm schema đầy "
            + "đủ (kiểu thuộc tính, quan hệ cho phép giữa hai nhãn) do FR-KNW-917 kiểm, từ một "
            + "tệp schema YAML rời — chạy riêng, không tự nạp vào đây.")
        return parts.joined(separator: " ")
    }
}
