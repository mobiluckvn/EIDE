import Foundation

/// Năm thuật toán đồ thị — FR-KNW-914.
///
/// Đặc tả: *"Bộ thuật toán **tự cài đặt** theo đúng chuẩn FR-MIN (tất định, tiến trình + hủy,
/// khối Phương pháp): láng giềng k-hop; đường đi ngắn nhất (BFS không trọng số / Dijkstra có
/// trọng số); thành phần liên thông; PageRank (damping 0,85, ngưỡng hội tụ hiển thị); phát hiện
/// cộng đồng Louvain (modularity báo cáo)."*
///
/// ## Ba luật của cụm FR-MIN, áp nguyên vào đây
///
/// **Tất định.** Cùng đồ thị → cùng kết quả, kể cả những chỗ hoà. Hàng xóm đã sắp theo số hiệu
/// khi dựng CSR, mọi vòng lặp duyệt theo số hiệu, và mọi phép cộng số thực chạy theo cùng một
/// thứ tự. Louvain chuẩn XÁO TRỘN thứ tự node để thoát cực trị địa phương — bản ở đây **không
/// xáo**, và cái giá ấy được nói ra chứ không giấu.
///
/// **Tiến trình + huỷ.** Mọi thuật toán nhận `progress` và `cancelToken`, và trả về kết quả
/// DÙNG ĐƯỢC kèm cờ khi bị huỷ giữa chừng — chứ không ném lỗi làm mất sạch công đã làm.
///
/// **Khối Phương pháp.** Mỗi kết quả mang theo `methodology`: thuật toán nào, tham số nào, và
/// **cái gì là giả định**. Với đồ thị, giả định nguy hiểm nhất là trọng số: một cạnh không khai
/// `weight` được tính là 1, và một đồ thị TRỘN hai loại cạnh sẽ cho đường đi ngắn nhất mà người
/// đọc tưởng là đo được.
public enum GraphAlgorithms {

    /// Bao nhiêu node thì hỏi tiến độ một lần.
    static let progressInterval = 50_000

    // MARK: - Láng giềng k-hop

    public struct Neighbourhood: Equatable, Sendable {
        /// (node, số hop tới nó), theo hop tăng dần rồi số hiệu tăng dần.
        public var nodes: [(node: Int, hops: Int)]
        public var seeds: [Int]
        public var k: Int
        public var view: GraphCSR.View
        public var wasCancelled: Bool
        public var methodology: String

        public static func == (left: Neighbourhood, right: Neighbourhood) -> Bool {
            left.nodes.map(\.node) == right.nodes.map(\.node)
                && left.nodes.map(\.hops) == right.nodes.map(\.hops)
                && left.seeds == right.seeds && left.k == right.k && left.view == right.view
                && left.wasCancelled == right.wasCancelled
        }
    }

    /// Láng giềng trong `k` hop tính từ `seeds`.
    ///
    /// BFS theo TẦNG, nên "hop" là số bước ÍT NHẤT tới node ấy — không phải "có đường đi dài k
    /// bước". Hai thứ khác nhau, và người dùng hỏi "ai cách tôi 2 bước" đang hỏi cái đầu.
    ///
    /// Seed KHÔNG nằm trong kết quả: nó là chỗ xuất phát, và để nó trong danh sách "láng giềng
    /// 0 hop" làm mọi phép đếm phía sau lệch đúng bằng số seed.
    public static func neighbourhood(
        of seeds: [Int], k: Int, in graph: GraphCSR, view: GraphCSR.View = .both,
        cancelToken: CancelToken? = nil, progress: ((Double) -> Bool)? = nil
    ) -> Neighbourhood {
        var distance = [Int32](repeating: -1, count: graph.nodeCount)
        var frontier: [Int] = []
        for seed in seeds.sorted() where seed >= 0 && seed < graph.nodeCount {
            guard distance[seed] < 0 else { continue }
            distance[seed] = 0
            frontier.append(seed)
        }
        var out: [(node: Int, hops: Int)] = []
        var cancelled = false
        var visited = frontier.count

        for hop in 1 ... max(1, k) {
            guard hop <= k, !frontier.isEmpty, !cancelled else { break }
            var next: [Int] = []
            for node in frontier {
                if cancelToken?.isCancelled == true { cancelled = true; break }
                for position in graph.range(node, view) {
                    let neighbour = graph.target(position, view)
                    guard distance[neighbour] < 0 else { continue }
                    distance[neighbour] = Int32(hop)
                    next.append(neighbour)
                    out.append((neighbour, hop))
                }
                visited += 1
                if visited % progressInterval == 0, let progress,
                   !progress(Double(hop) / Double(max(k, 1))) {
                    cancelled = true
                    break
                }
            }
            // Sắp theo số hiệu trong TỪNG tầng: BFS đẩy vào theo thứ tự gặp, và thứ tự gặp phụ
            // thuộc thứ tự tầng trước — sắp lại là chỗ rẻ nhất để tính tất định thành hiển nhiên.
            next.sort()
            frontier = next
        }
        out.sort { $0.hops != $1.hops ? $0.hops < $1.hops : $0.node < $1.node }

        return Neighbourhood(
            nodes: out, seeds: seeds.sorted(), k: k, view: view, wasCancelled: cancelled,
            methodology: "BFS theo tầng từ \(seeds.count) node gốc, tối đa \(k) hop, "
                + "\(view.vietnamese). «Hop» là số bước ÍT NHẤT tới node đó, không phải độ dài "
                + "một đường đi bất kỳ. Node gốc KHÔNG nằm trong kết quả.")
    }

    // MARK: - Đường đi ngắn nhất

    public struct Path: Equatable, Sendable {
        /// Dãy node từ nguồn tới đích. Rỗng = không có đường đi.
        public var nodes: [Int]
        public var cost: Double
        public var usedWeights: Bool
        public var wasCancelled: Bool
        public var methodology: String
    }

    /// Đường đi ngắn nhất giữa hai node.
    ///
    /// BFS khi mọi cạnh có cùng trọng số, Dijkstra khi không. Chọn TỰ ĐỘNG theo dữ liệu chứ
    /// không theo một tuỳ chọn: BFS trên đồ thị có trọng số trả về đường đi ÍT CẠNH nhất, không
    /// phải đường đi RẺ nhất — và hai thứ ấy khác nhau, còn người dùng thì không có cách nào
    /// biết công cụ vừa chọn cái nào.
    public static func shortestPath(
        from source: Int, to destination: Int, in graph: GraphCSR,
        view: GraphCSR.View = .out, cancelToken: CancelToken? = nil
    ) -> Path {
        guard source >= 0, source < graph.nodeCount,
              destination >= 0, destination < graph.nodeCount else {
            return Path(nodes: [], cost: 0, usedWeights: false, wasCancelled: false,
                        methodology: "node nguồn hoặc đích không có trong đồ thị")
        }
        let weighted = graph.hasWeightedEdges
        var previous = [Int32](repeating: -1, count: graph.nodeCount)
        var cost = [Double](repeating: .infinity, count: graph.nodeCount)
        cost[source] = 0
        var cancelled = false

        if !weighted {
            var queue = [source]
            var head = 0
            var visited = Set([source])
            while head < queue.count {
                if cancelToken?.isCancelled == true { cancelled = true; break }
                let node = queue[head]
                head += 1
                if node == destination { break }
                for position in graph.range(node, view) {
                    let neighbour = graph.target(position, view)
                    guard visited.insert(neighbour).inserted else { continue }
                    previous[neighbour] = Int32(node)
                    cost[neighbour] = cost[node] + 1
                    queue.append(neighbour)
                }
            }
        } else {
            // Dijkstra với đống nhị phân. Không dùng `Set` các node đã xong: một mảng cờ rẻ hơn
            // và tránh hẳn phép băm trong vòng nóng.
            var done = [Bool](repeating: false, count: graph.nodeCount)
            var heap: [(cost: Double, node: Int)] = [(0, source)]
            func siftUp(_ start: Int) {
                var child = start
                while child > 0 {
                    let parent = (child - 1) / 2
                    guard isBetter(heap[child], heap[parent]) else { break }
                    heap.swapAt(child, parent)
                    child = parent
                }
            }
            func siftDown(_ start: Int) {
                var parent = start
                while true {
                    let left = parent * 2 + 1
                    guard left < heap.count else { break }
                    var best = left
                    let right = left + 1
                    if right < heap.count, isBetter(heap[right], heap[best]) { best = right }
                    guard isBetter(heap[best], heap[parent]) else { break }
                    heap.swapAt(best, parent)
                    parent = best
                }
            }
            while !heap.isEmpty {
                if cancelToken?.isCancelled == true { cancelled = true; break }
                let top = heap[0]
                heap[0] = heap[heap.count - 1]
                heap.removeLast()
                if !heap.isEmpty { siftDown(0) }
                guard !done[top.node] else { continue }
                done[top.node] = true
                if top.node == destination { break }
                for position in graph.range(top.node, view) {
                    let neighbour = graph.target(position, view)
                    let candidate = top.cost + graph.weight(position, view)
                    guard candidate < cost[neighbour] else { continue }
                    cost[neighbour] = candidate
                    previous[neighbour] = Int32(top.node)
                    heap.append((candidate, neighbour))
                    siftUp(heap.count - 1)
                }
            }
        }

        var path: [Int] = []
        if cost[destination].isFinite {
            var node = destination
            path.append(node)
            while node != source, previous[node] >= 0 {
                node = Int(previous[node])
                path.append(node)
            }
            path.reverse()
            if path.first != source { path = [] }
        }
        var note = weighted
            ? "Dijkstra với trọng số từ thuộc tính DOT `weight`"
            : "BFS không trọng số (mọi cạnh nặng như nhau)"
        note += ", \(view.vietnamese)."
        if weighted, graph.hasUnweightedEdges {
            note += " ⚠ Đồ thị TRỘN cạnh có và không khai `weight`; cạnh không khai được tính "
                + "là 1 — đó là một GIẢ ĐỊNH, không phải một số đo."
        }
        return Path(
            nodes: path, cost: cost[destination].isFinite ? cost[destination] : 0,
            usedWeights: weighted, wasCancelled: cancelled, methodology: note)
    }

    /// Đống nhỏ-nhất-trên-đỉnh; hoà chi phí thì node số hiệu NHỎ hơn ra trước — tất định.
    private static func isBetter(
        _ left: (cost: Double, node: Int), _ right: (cost: Double, node: Int)
    ) -> Bool {
        left.cost != right.cost ? left.cost < right.cost : left.node < right.node
    }

    // MARK: - Thành phần liên thông

    public struct Components: Equatable, Sendable {
        /// Số hiệu thành phần của từng node.
        public var labels: [Int]
        /// Kích thước từng thành phần, GIẢM DẦN; `sizes[i]` ứng với `order[i]`.
        public var sizes: [Int]
        /// Số hiệu thành phần theo thứ tự kích thước giảm dần.
        public var order: [Int]
        public var wasCancelled: Bool
        public var methodology: String

        public var count: Int { sizes.count }
        /// Node mồ côi: thành phần chỉ có một node.
        public var isolatedCount: Int { sizes.filter { $0 == 1 }.count }
    }

    /// Thành phần liên thông trên đồ thị BỎ HƯỚNG.
    ///
    /// Bỏ hướng là một lựa chọn có nghĩa, không phải mặc định tiện tay: trên đồ thị có hướng,
    /// đi theo chiều ra cho ra "thành phần liên thông MẠNH" — một khái niệm khác hẳn, và người
    /// dùng sẽ đọc một con số đúng cho câu hỏi họ không hỏi. Phần Phương pháp nói rõ điều này.
    ///
    /// Số hiệu thành phần đánh theo node NHỎ NHẤT trong nó, nên hai lượt chạy cho cùng số hiệu.
    public static func connectedComponents(
        in graph: GraphCSR, cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> Components {
        var labels = [Int](repeating: -1, count: graph.nodeCount)
        var sizes: [Int] = []
        var cancelled = false
        var queue: [Int] = []

        for start in 0 ..< graph.nodeCount {
            guard labels[start] < 0 else { continue }
            if cancelToken?.isCancelled == true { cancelled = true; break }
            if start % progressInterval == 0, let progress,
               !progress(Double(start) / Double(max(graph.nodeCount, 1))) {
                cancelled = true
                break
            }
            let label = sizes.count
            var size = 0
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            labels[start] = label
            var head = 0
            while head < queue.count {
                let node = queue[head]
                head += 1
                size += 1
                for position in graph.range(node, .both) {
                    let neighbour = graph.target(position, .both)
                    guard labels[neighbour] < 0 else { continue }
                    labels[neighbour] = label
                    queue.append(neighbour)
                }
            }
            sizes.append(size)
        }
        let order = sizes.indices.sorted {
            sizes[$0] != sizes[$1] ? sizes[$0] > sizes[$1] : $0 < $1
        }
        return Components(
            labels: labels, sizes: order.map { sizes[$0] }, order: order,
            wasCancelled: cancelled,
            methodology: "BFS lặp trên đồ thị **bỏ hướng**. Với đồ thị có hướng, đây KHÔNG phải "
                + "thành phần liên thông mạnh — đi theo chiều ra là một câu hỏi khác. Số hiệu "
                + "thành phần đánh theo node xuất hiện trước, nên hai lượt chạy cho cùng số hiệu.")
    }

    // MARK: - PageRank

    public struct PageRank: Equatable, Sendable {
        public var scores: [Double]
        /// Node theo điểm giảm dần; hoà thì số hiệu tăng dần.
        public var ranking: [Int]
        public var iterations: Int
        /// Chênh lệch lớn nhất ở vòng cuối — *"ngưỡng hội tụ hiển thị"* của đặc tả.
        public var delta: Double
        public var converged: Bool
        public var wasCancelled: Bool
        public var methodology: String
    }

    public static let damping = 0.85
    public static let convergenceThreshold = 1e-8
    public static let maximumIterations = 100

    /// PageRank, damping 0,85.
    ///
    /// ## Node KHÔNG có cạnh đi ra (dangling) là chỗ mọi cài đặt hay sai
    ///
    /// Một node không trỏ đi đâu thì phần điểm của nó biến mất sau mỗi vòng, và tổng điểm tụt
    /// dần về 0 — bảng xếp hạng vẫn "trông đúng" vì thứ tự không đổi, nhưng con số thì vô
    /// nghĩa và không so được giữa hai đồ thị. Bản ở đây gom điểm ấy lại và **rải đều cho mọi
    /// node**, đúng như định nghĩa gốc.
    public static func pageRank(
        in graph: GraphCSR, cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> PageRank {
        let count = graph.nodeCount
        guard count > 0 else {
            return PageRank(scores: [], ranking: [], iterations: 0, delta: 0, converged: true,
                            wasCancelled: false, methodology: "đồ thị rỗng")
        }
        var scores = [Double](repeating: 1 / Double(count), count: count)
        var next = [Double](repeating: 0, count: count)
        var outDegree = [Int](repeating: 0, count: count)
        for node in 0 ..< count { outDegree[node] = graph.range(node, .out).count }

        var iterations = 0
        var delta = 0.0
        var converged = false
        var cancelled = false

        for iteration in 1 ... maximumIterations {
            if cancelToken?.isCancelled == true { cancelled = true; break }
            iterations = iteration
            var dangling = 0.0
            for node in 0 ..< count where outDegree[node] == 0 { dangling += scores[node] }
            let base = (1 - damping) / Double(count) + damping * dangling / Double(count)
            for node in 0 ..< count { next[node] = base }
            // Duyệt theo số hiệu node và theo thứ tự hàng xóm đã sắp: phép cộng số thực KHÔNG
            // giao hoán về bit, nên thứ tự cộng là điều kiện của tính tất định.
            for node in 0 ..< count {
                guard outDegree[node] > 0 else { continue }
                let share = damping * scores[node] / Double(outDegree[node])
                for position in graph.range(node, .out) {
                    next[graph.target(position, .out)] += share
                }
            }
            delta = 0
            for node in 0 ..< count { delta = max(delta, abs(next[node] - scores[node])) }
            swap(&scores, &next)
            if let progress, !progress(Double(iteration) / Double(maximumIterations)) {
                cancelled = true
                break
            }
            if delta < convergenceThreshold { converged = true; break }
        }

        let ranking = (0 ..< count).sorted {
            scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1
        }
        return PageRank(
            scores: scores, ranking: ranking, iterations: iterations, delta: delta,
            converged: converged, wasCancelled: cancelled,
            methodology: "PageRank lặp, damping \(damping), dừng khi chênh lệch lớn nhất "
                + "< \(convergenceThreshold) hoặc sau \(maximumIterations) vòng. "
                + "Lượt này: \(iterations) vòng, chênh lệch cuối "
                + String(format: "%.3e", delta)
                + (converged ? " — ĐÃ hội tụ." : " — CHƯA hội tụ, con số là ước lượng.")
                + " Điểm của node không có cạnh đi ra được rải đều cho mọi node, nếu không thì "
                + "tổng điểm tụt dần và không so được giữa hai đồ thị.")
    }

    // MARK: - Louvain

    public struct Communities: Equatable, Sendable {
        /// Số hiệu cộng đồng của từng node.
        public var labels: [Int]
        public var sizes: [Int]
        /// Modularity của phân hoạch — *"modularity báo cáo"* của đặc tả.
        public var modularity: Double
        public var passes: Int
        public var wasCancelled: Bool
        public var methodology: String

        public var count: Int { sizes.count }
    }

    /// Louvain — gom cộng đồng bằng cách tăng modularity từng bước.
    ///
    /// ## Bản này KHÔNG xáo trộn thứ tự node, và đó là một đánh đổi
    ///
    /// Louvain chuẩn duyệt node theo thứ tự NGẪU NHIÊN ở mỗi lượt, vì thứ tự cố định dễ mắc vào
    /// một cực trị địa phương. Nhưng NFR-MIN-02 đòi kết quả TẤT ĐỊNH, và một thuật toán gom
    /// cụm cho ra bảng màu khác nhau ở mỗi lần bấm là thứ không ai tin được.
    ///
    /// Nên: duyệt theo số hiệu node, cố định. Cái giá là modularity có thể thấp hơn bản xáo
    /// trộn vài phần trăm — và con số modularity được BÁO CÁO, nên người dùng thấy được chất
    /// lượng phân hoạch chứ không phải tin lời.
    public static func louvain(
        in graph: GraphCSR, cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> Communities {
        let count = graph.nodeCount
        guard count > 0 else {
            return Communities(labels: [], sizes: [], modularity: 0, passes: 0,
                               wasCancelled: false, methodology: "đồ thị rỗng")
        }
        var totalWeight = 0.0
        for node in 0 ..< count { totalWeight += graph.weightedDegree(node) }
        let m2 = totalWeight                    // = 2m
        guard m2 > 0 else {
            return Communities(
                labels: Array(0 ..< count), sizes: [Int](repeating: 1, count: count),
                modularity: 0, passes: 0, wasCancelled: false,
                methodology: "đồ thị không có cạnh nào — mỗi node là một cộng đồng")
        }

        var community = Array(0 ..< count)
        var communityWeight = (0 ..< count).map { graph.weightedDegree($0) }
        var nodeWeight = communityWeight
        var cancelled = false
        var passes = 0

        // Một lượt = duyệt hết node một lần. Lặp tới khi không node nào đổi cộng đồng nữa.
        for pass in 1 ... 20 {
            passes = pass
            var moved = false
            for node in 0 ..< count {
                if cancelToken?.isCancelled == true { cancelled = true; break }
                if node % progressInterval == 0, let progress,
                   !progress(Double(pass) / 20) {
                    cancelled = true
                    break
                }
                let current = community[node]
                let degree = nodeWeight[node]
                // Trọng số nối từ node tới từng cộng đồng lân cận.
                var links: [Int: Double] = [:]
                for position in graph.range(node, .both) {
                    let neighbour = graph.target(position, .both)
                    guard neighbour != node else { continue }
                    links[community[neighbour], default: 0] += graph.weight(position, .both)
                }
                // Rời cộng đồng hiện tại trước khi tính lợi ích của từng lựa chọn.
                communityWeight[current] -= degree
                var best = current
                var bestGain = (links[current] ?? 0) - communityWeight[current] * degree / m2
                // Duyệt cộng đồng theo SỐ HIỆU tăng dần: `Dictionary` không có thứ tự, và một
                // vòng lặp trên nó làm kết quả đổi giữa hai lần chạy.
                for candidate in links.keys.sorted() {
                    let gain = links[candidate]! - communityWeight[candidate] * degree / m2
                    // Hoà thì giữ cộng đồng số hiệu NHỎ hơn — lại là tất định.
                    if gain > bestGain || (gain == bestGain && candidate < best) {
                        best = candidate
                        bestGain = gain
                    }
                }
                communityWeight[best] += degree
                if best != current {
                    community[node] = best
                    moved = true
                }
            }
            if cancelled || !moved { break }
        }

        // Đánh số lại cho liền mạch, theo thứ tự xuất hiện — tất định và dễ đọc.
        var mapping: [Int: Int] = [:]
        var labels = [Int](repeating: 0, count: count)
        var sizes: [Int] = []
        for node in 0 ..< count {
            let raw = community[node]
            if let existing = mapping[raw] {
                labels[node] = existing
                sizes[existing] += 1
            } else {
                let label = sizes.count
                mapping[raw] = label
                labels[node] = label
                sizes.append(1)
            }
        }

        // Modularity: Σ_c [ trong_c / 2m − (tổng_c / 2m)² ]
        var inside = [Double](repeating: 0, count: sizes.count)
        var total = [Double](repeating: 0, count: sizes.count)
        for node in 0 ..< count {
            total[labels[node]] += nodeWeight[node]
            for position in graph.range(node, .both) {
                let neighbour = graph.target(position, .both)
                guard labels[neighbour] == labels[node] else { continue }
                inside[labels[node]] += graph.weight(position, .both)
            }
        }
        var modularity = 0.0
        for label in sizes.indices {
            modularity += inside[label] / m2 - (total[label] / m2) * (total[label] / m2)
        }

        return Communities(
            labels: labels, sizes: sizes, modularity: modularity, passes: passes,
            wasCancelled: cancelled,
            methodology: "Louvain một tầng, duyệt node theo SỐ HIỆU (không xáo trộn) để kết quả "
                + "tất định — bản chuẩn xáo trộn để thoát cực trị địa phương, nên modularity ở "
                + "đây có thể thấp hơn vài phần trăm. Modularity đạt được: "
                + String(format: "%.4f", modularity) + " trên \(sizes.count) cộng đồng sau "
                + "\(passes) lượt. Trọng số lấy từ thuộc tính DOT `weight`, cạnh không khai "
                + "tính là 1.")
    }
}
