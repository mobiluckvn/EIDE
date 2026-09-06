import Foundation

/// Đồ thị dạng CSR — nền chung của mọi thuật toán trong FR-KNW-914.
///
/// ## Vì sao CSR, và vì sao dựng MỘT lần
///
/// NFR-KNW-03 viết thẳng: *"Adjacency dựng dạng CSR một lần, tái dùng giữa các lần chạy"*. Hai
/// vế, hai lý do khác nhau:
///
/// **CSR** (compressed sparse row) là hai mảng phẳng — `offsets` nói hàng xóm của node `v` nằm
/// ở đâu, `targets` chứa chúng liền nhau. So với `[String: [String]]`, nó đổi một lần băm chuỗi
/// cho mỗi bước duyệt lấy một phép cộng chỉ số. Trên đồ thị một triệu cạnh, khác biệt ấy là
/// khác biệt giữa "chạy được" và "chạy xong thì người dùng đã bỏ đi".
///
/// **Một lần** vì người dùng chạy nhiều thuật toán trên CÙNG một đồ thị: PageRank rồi Louvain
/// rồi k-hop. Dựng lại ở mỗi lần là trả ba lần cho một việc.
///
/// ## Ba khung nhìn, và chúng khác nhau thật
///
/// | Khung nhìn | Dùng cho |
/// |---|---|
/// | `out` — cạnh đi RA | PageRank, đường đi có hướng |
/// | `in` — cạnh đi VÀO | PageRank cần biết ai trỏ tới mình |
/// | `both` — bỏ hướng | thành phần liên thông, Louvain, k-hop |
///
/// Gộp ba thành một là sai về NGHĨA chứ không phải kém tối ưu: thành phần liên thông trên đồ
/// thị có hướng mà chỉ đi theo chiều ra thì trả về "thành phần liên thông MẠNH", một khái niệm
/// khác hẳn — và người dùng sẽ đọc một con số đúng cho câu hỏi họ không hỏi.
public struct GraphCSR: Sendable {

    /// Tên node theo số hiệu — để dịch kết quả trở lại thứ người dùng đọc.
    public let names: [String]
    /// Chữ hiện trên hình theo số hiệu.
    public let displays: [String]
    public let isDirected: Bool

    /// Cạnh đi ra: `outTargets[outOffsets[v] ..< outOffsets[v+1]]`.
    let outOffsets: [Int32]
    let outTargets: [Int32]
    let outWeights: [Double]

    let inOffsets: [Int32]
    let inTargets: [Int32]

    /// Bỏ hướng: mỗi cạnh xuất hiện ở CẢ HAI đầu.
    let bothOffsets: [Int32]
    let bothTargets: [Int32]
    let bothWeights: [Double]

    /// Có cạnh nào KHÔNG khai trọng số không — phần Phương pháp phải nói ra.
    public let hasUnweightedEdges: Bool
    public let hasWeightedEdges: Bool

    public var nodeCount: Int { names.count }
    public var edgeCount: Int { outTargets.count }

    public func index(of name: String) -> Int? { lookup[name] }
    private let lookup: [String: Int]

    // MARK: - Dựng

    public init(_ graph: DOTGraph) {
        var lookup: [String: Int] = [:]
        var names: [String] = []
        var displays: [String] = []
        for node in graph.nodes where lookup[node.name] == nil {
            lookup[node.name] = names.count
            names.append(node.name)
            displays.append(node.display)
        }
        self.lookup = lookup
        self.names = names
        self.displays = displays
        self.isDirected = graph.isDirected

        var unweighted = false
        var weighted = false
        var pairs: [(from: Int32, to: Int32, weight: Double)] = []
        pairs.reserveCapacity(graph.edges.count)
        for edge in graph.edges {
            guard let from = lookup[edge.from], let to = lookup[edge.to] else { continue }
            if edge.weight == nil { unweighted = true } else { weighted = true }
            pairs.append((Int32(from), Int32(to), edge.weight ?? 1))
        }
        hasUnweightedEdges = unweighted
        hasWeightedEdges = weighted

        (outOffsets, outTargets, outWeights) = GraphCSR.build(
            count: names.count, pairs: pairs.map { ($0.from, $0.to, $0.weight) })
        let reversed = pairs.map { ($0.to, $0.from, $0.weight) }
        (inOffsets, inTargets, _) = GraphCSR.build(count: names.count, pairs: reversed)
        (bothOffsets, bothTargets, bothWeights) = GraphCSR.build(
            count: names.count, pairs: pairs.map { ($0.from, $0.to, $0.weight) } + reversed)
    }

    /// Dựng thẳng từ danh sách cạnh theo SỐ HIỆU.
    ///
    /// Có mặt cho hai chỗ: bộ đo NFR-KNW-03 (một triệu cạnh, dựng qua văn bản DOT thì phần lớn
    /// thời gian đo là thời gian phân tích chuỗi), và FR-KNW-910 (edge list) sắp tới.
    public init(
        names: [String], displays: [String]? = nil, isDirected: Bool = true,
        edges: [(from: Int, to: Int, weight: Double?)]
    ) {
        var lookup: [String: Int] = [:]
        lookup.reserveCapacity(names.count)
        for (index, name) in names.enumerated() where lookup[name] == nil { lookup[name] = index }
        self.lookup = lookup
        self.names = names
        self.displays = displays ?? names
        self.isDirected = isDirected

        var unweighted = false
        var weighted = false
        var pairs: [(Int32, Int32, Double)] = []
        pairs.reserveCapacity(edges.count)
        for edge in edges where edge.from < names.count && edge.to < names.count {
            if edge.weight == nil { unweighted = true } else { weighted = true }
            pairs.append((Int32(edge.from), Int32(edge.to), edge.weight ?? 1))
        }
        hasUnweightedEdges = unweighted
        hasWeightedEdges = weighted
        (outOffsets, outTargets, outWeights) = GraphCSR.build(count: names.count, pairs: pairs)
        let reversed = pairs.map { ($0.1, $0.0, $0.2) }
        (inOffsets, inTargets, _) = GraphCSR.build(count: names.count, pairs: reversed)
        (bothOffsets, bothTargets, bothWeights) = GraphCSR.build(
            count: names.count, pairs: pairs + reversed)
    }

    /// Đếm-rồi-đổ: hai lượt, không cấp phát một mảng con cho mỗi node.
    ///
    /// Cách hiển nhiên (`var lists = [[Int32]](repeating: [], count: n)`) cấp phát một mảng cho
    /// MỖI node — trên một triệu node đó là một triệu lần cấp phát, và cùng bẫy copy-on-write
    /// đã làm bộ dựng chỉ mục BM25 thành O(n²).
    ///
    /// Hàng xóm được SẮP theo số hiệu trong từng node: mọi thuật toán duyệt theo thứ tự ấy, nên
    /// kết quả TẤT ĐỊNH mà không phải sắp lại ở từng chỗ dùng (NFR-MIN-02).
    static func build(
        count: Int, pairs: [(Int32, Int32, Double)]
    ) -> (offsets: [Int32], targets: [Int32], weights: [Double]) {
        var degrees = [Int32](repeating: 0, count: count)
        for pair in pairs where Int(pair.0) < count { degrees[Int(pair.0)] += 1 }
        var offsets = [Int32](repeating: 0, count: count + 1)
        var running: Int32 = 0
        for node in 0 ..< count {
            offsets[node] = running
            running += degrees[node]
        }
        offsets[count] = running
        var cursor = offsets
        var targets = [Int32](repeating: 0, count: Int(running))
        var weights = [Double](repeating: 1, count: Int(running))
        for pair in pairs where Int(pair.0) < count {
            let position = Int(cursor[Int(pair.0)])
            targets[position] = pair.1
            weights[position] = pair.2
            cursor[Int(pair.0)] += 1
        }
        // Sắp hàng xóm trong từng node — điều kiện của tính tất định.
        for node in 0 ..< count {
            let start = Int(offsets[node])
            let end = Int(offsets[node + 1])
            guard end - start > 1 else { continue }
            let order = (start ..< end).sorted {
                targets[$0] != targets[$1] ? targets[$0] < targets[$1] : $0 < $1
            }
            let sortedTargets = order.map { targets[$0] }
            let sortedWeights = order.map { weights[$0] }
            for (offset, position) in (start ..< end).enumerated() {
                targets[position] = sortedTargets[offset]
                weights[position] = sortedWeights[offset]
            }
        }
        return (offsets, targets, weights)
    }

    // MARK: - Duyệt

    public enum View: String, Sendable {
        case out, incoming, both

        public var vietnamese: String {
            switch self {
            case .out: return "theo chiều đi"
            case .incoming: return "theo chiều tới"
            case .both: return "bỏ hướng"
            }
        }
    }

    func range(_ node: Int, _ view: View) -> Range<Int> {
        switch view {
        case .out: return Int(outOffsets[node]) ..< Int(outOffsets[node + 1])
        case .incoming: return Int(inOffsets[node]) ..< Int(inOffsets[node + 1])
        case .both: return Int(bothOffsets[node]) ..< Int(bothOffsets[node + 1])
        }
    }

    func target(_ position: Int, _ view: View) -> Int {
        switch view {
        case .out: return Int(outTargets[position])
        case .incoming: return Int(inTargets[position])
        case .both: return Int(bothTargets[position])
        }
    }

    func weight(_ position: Int, _ view: View) -> Double {
        switch view {
        case .out: return outWeights[position]
        case .incoming: return 1
        case .both: return bothWeights[position]
        }
    }

    /// Bậc của một node theo khung nhìn.
    public func degree(_ node: Int, _ view: View = .both) -> Int { range(node, view).count }

    /// Tổng trọng số của các cạnh chạm vào node — Louvain cần nó ở mọi bước.
    func weightedDegree(_ node: Int) -> Double {
        var total = 0.0
        for position in range(node, .both) { total += bothWeights[position] }
        return total
    }
}
