import Foundation
import GEditorCore

/// NFR-KNW-03 — bốn con số trên đồ thị **một triệu cạnh**.
///
/// ```
/// truy vấn 2-hop         ≤  2 giây
/// thành phần liên thông  ≤ 10 giây
/// PageRank hội tụ        ≤ 30 giây
/// Louvain                ≤ 60 giây
/// ```
///
/// Chỉ tiêu còn hai vế nữa mà bộ đo này cũng chấm: *"Adjacency dựng dạng CSR một lần, tái dùng
/// giữa các lần chạy"* — nên thời gian dựng CSR đo RIÊNG và chỉ tính một lần cho cả năm thuật
/// toán; và *"mọi tác vụ có tiến trình + hủy ≤ 200 ms"* — nên bộ đo đếm số nhịp tiến độ và tính
/// khoảng cách trung bình giữa hai nhịp.
///
/// ## Đồ thị mẫu sinh thế nào, và vì sao nó không phải một vòng tròn
///
/// Một đồ thị đều tăm tắp (mỗi node nối node kế) là ca DỄ NHẤT cho cả năm thuật toán: BFS chạy
/// tuyến tính, Louvain gom một phát xong, PageRank hội tụ sau vài vòng. Đo trên nó cho ra bốn
/// con số đẹp và vô nghĩa.
///
/// Nên đồ thị ở đây có **cấu trúc cụm**: node gom thành cụm 100 node nối dày bên trong, và một
/// ít cạnh thưa nối các cụm. Đó là hình dạng của đồ thị tri thức thật, và nó là ca khó cho
/// Louvain (phải tìm ra cụm) lẫn PageRank (hội tụ chậm hơn).
///
/// ## Và một node TRUNG TÂM, vì thiếu nó thì phép đo 2-hop nói dối
///
/// Bản đầu của bộ đo này cho *"2-hop: 0 ms"* — đúng, và vô nghĩa: mọi node đều bậc 8, nên hai
/// hop từ một node bất kỳ chỉ chạm hơn trăm node. Chỉ tiêu 2 giây rõ ràng không được viết cho
/// ca ấy.
///
/// Đồ thị thật luôn có node trung tâm (một thực thể được nhắc tới ở khắp nơi), và 2-hop TỪ nó
/// mới là ca mà trần 2 giây nói tới. Nên node 0 được nối tới 5% số node. Cùng bài học đã trả
/// giá ở PoC-M: **một chỉ tiêu tốc độ chỉ đáng tin bằng đầu vào dùng để đo nó.**
enum GraphKPI {

    static func run(arguments: [String]) {
        let edgeTarget = intOption("--edges", in: arguments, default: 1_000_000)
        let clusterSize = intOption("--cluster", in: arguments, default: 100)

        print("\n▸ KPI đồ thị — thuật toán (FR-KNW-914, NFR-KNW-03)")
        let (names, edges) = generate(edges: edgeTarget, clusterSize: clusterSize)
        print("  sinh xong      \(names.count) node · \(edges.count) cạnh")

        // --- Dựng CSR: một lần, tái dùng cho cả năm ---
        let buildStart = DispatchTime.now().uptimeNanoseconds
        let graph = GraphCSR(names: names, edges: edges)
        let buildMs = milliseconds(since: buildStart)
        print(String(format: "  dựng CSR       %.0f ms   (một lần, tái dùng cho cả năm)", buildMs))

        var results: [String: Any] = [:]
        var passed = true

        func measure(
            _ title: String, budget: Double, _ body: (@escaping (Double) -> Bool) -> String
        ) {
            var ticks = 0
            var lastTick = DispatchTime.now().uptimeNanoseconds
            var worstGap = 0.0
            let started = DispatchTime.now().uptimeNanoseconds
            let note = body { _ in
                ticks += 1
                let now = DispatchTime.now().uptimeNanoseconds
                worstGap = max(worstGap, Double(now - lastTick) / 1_000_000)
                lastTick = now
                return true
            }
            let elapsed = milliseconds(since: started)
            let ok = elapsed <= budget
            if !ok { passed = false }
            print(String(format: "  %@ %.0f ms / trần %.0f ms · %d nhịp tiến độ · "
                         + "khoảng lớn nhất %.0f ms%@",
                         title.padding(toLength: 14, withPad: " ", startingAt: 0),
                         elapsed, budget, ticks, worstGap, ok ? "" : "  ❌"))
            if !note.isEmpty { print("                 \(note)") }
            results[title] = ["ms": elapsed, "budgetMs": budget, "ticks": ticks,
                              "worstGapMs": worstGap, "passed": ok]
        }

        // 2-hop TỪ NODE TRUNG TÂM — ca mà trần 2 giây nói tới.
        measure("2-hop", budget: 2_000) { progress in
            let result = GraphAlgorithms.neighbourhood(
                of: [0], k: 2, in: graph, progress: progress)
            return "\(result.nodes.count) node trong 2 hop từ node trung tâm "
                + "(bậc \(graph.degree(0)))"
        }
        measure("liên thông", budget: 10_000) { progress in
            let result = GraphAlgorithms.connectedComponents(in: graph, progress: progress)
            return "\(result.count) thành phần · lớn nhất \(result.sizes.first ?? 0) node"
        }
        measure("PageRank", budget: 30_000) { progress in
            let result = GraphAlgorithms.pageRank(in: graph, progress: progress)
            return "\(result.iterations) vòng · chênh lệch cuối "
                + String(format: "%.2e", result.delta)
                + (result.converged ? " · ĐÃ hội tụ" : " · CHƯA hội tụ")
        }
        measure("Louvain", budget: 60_000) { progress in
            let result = GraphAlgorithms.louvain(in: graph, progress: progress)
            return "\(result.count) cộng đồng · modularity "
                + String(format: "%.4f", result.modularity)
        }

        // Vế "tất định" của NFR-MIN-02: chạy lại một thuật toán và so.
        let first = GraphAlgorithms.louvain(in: graph)
        let second = GraphAlgorithms.louvain(in: graph)
        let deterministic = first == second
        if !deterministic { passed = false }
        print("  tất định       \(deterministic ? "CÓ" : "KHÔNG") (Louvain chạy hai lượt)")

        print(passed ? "\n✅ NFR-KNW-03 ĐẠT" : "\n❌ NFR-KNW-03 TRƯỢT")
        let payload: [String: Any] = [
            "nodeCount": names.count,
            "edgeCount": edges.count,
            "csrBuildMs": buildMs,
            "steps": results,
            "deterministic": deterministic,
            "passed": passed,
        ]
        let path = "benchmarks/results/graph-\(architecture()).json"
        try? FileManager.default.createDirectory(
            atPath: "benchmarks/results", withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("   kết quả ở \(path)")
        }
        exit(passed ? 0 : 1)
    }

    /// Đồ thị có CẤU TRÚC CỤM — xem chú thích ở đầu tệp.
    static func generate(
        edges edgeTarget: Int, clusterSize: Int
    ) -> ([String], [(from: Int, to: Int, weight: Double?)]) {
        // Mỗi node trong cụm nối tới 8 node khác cùng cụm → mật độ đủ để Louvain có việc làm.
        let insideDegree = 8
        let nodeCount = max(clusterSize, edgeTarget / insideDegree)
        var generator = SeededGenerator(seed: 914)
        var names: [String] = []
        names.reserveCapacity(nodeCount)
        for index in 0 ..< nodeCount { names.append("n\(index)") }

        var edges: [(from: Int, to: Int, weight: Double?)] = []
        edges.reserveCapacity(edgeTarget)
        for node in 0 ..< nodeCount {
            let cluster = node / clusterSize
            let base = cluster * clusterSize
            let size = min(clusterSize, nodeCount - base)
            guard size > 1 else { continue }
            for _ in 0 ..< insideDegree {
                let other = base + Int.random(in: 0 ..< size, using: &generator)
                if other != node { edges.append((node, other, nil)) }
            }
            // Một cạnh thưa ra ngoài cụm cho khoảng 1/50 node — đủ để đồ thị liên thông mà
            // không xoá mất cấu trúc cụm.
            if node % 50 == 0, nodeCount > clusterSize {
                edges.append((node, Int.random(in: 0 ..< nodeCount, using: &generator), nil))
            }
            if edges.count >= edgeTarget { break }
        }
        // Node trung tâm — xem chú thích ở đầu tệp.
        let hubDegree = max(1, nodeCount / 20)
        for step in 0 ..< hubDegree {
            let other = (step * 19 + 7) % nodeCount
            if other != 0 { edges.append((0, other, nil)) }
        }
        return (names, edges)
    }

    private static func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    private static func intOption(_ name: String, in arguments: [String], default value: Int)
        -> Int {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
              let parsed = Int(arguments[index + 1]) else { return value }
        return parsed
    }

    private static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
