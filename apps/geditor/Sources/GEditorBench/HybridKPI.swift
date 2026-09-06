import Foundation
import GEditorCore

/// NFR-KNW-05 — *"Re-rank hybrid trên top-500 ứng viên ≤ 300 ms sau khi BM25 trả kết quả (đồ
/// thị đã dựng CSR)"*.
///
/// Chỉ tiêu đo ĐÚNG phần xếp lại, không tính lượt BM25 — và `HybridRetrieval.Result` đã có sẵn
/// `rerankMilliseconds` với chú thích *"NFR-KNW-05 chấm chỗ này"*. Tức phần đo đạc nằm sẵn
/// trong mã từ lâu; thứ chưa từng có là **người chạy nó ở cỡ chỉ tiêu và ghi lại con số**.
///
/// ## Cỡ phải đủ để 500 ứng viên là 500 ứng viên
///
/// `candidateCount: 500` chỉ có nghĩa khi corpus có hơn 500 chunk khớp câu hỏi. Corpus nhỏ thì
/// BM25 trả về ba chục ứng viên, phép xếp lại chạy trên ba chục, và con số đo được nói về một
/// tải nhẹ hơn chỉ tiêu vài chục lần. Bộ đo vì thế ĐẾM số ứng viên thật và từ chối kết luận khi
/// nó chưa đủ.
enum HybridKPI {

    struct Report: Encodable {
        let kpi: String
        let architecture: String
        let chunks: Int
        let graphNodes: Int
        let candidates: Int
        let rerankMs: Double
        let budgetMs: Double
        let queries: Int
        let medianRerankMs: Double
        let worstRerankMs: Double
        let enoughCandidates: Bool
        let pass: Bool
        let notes: [String]
    }

    static func run(chunks: Int, nodes: Int, queries: Int) throws -> Report {
        var notes: [String] = []
        let folder = NSTemporaryDirectory() + "knw05-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }

        FileHandle.standardError.write(Data("   dựng corpus \(chunks) chunk…\n".utf8))
        let corpus = folder + "/chunks.jsonl"
        var text = ""
        var generator = SeededGenerator(seed: 20_260_907)
        // Mỗi chunk nhắc tới vài entity trong đồ thị, và tất cả cùng chứa từ khoá `hợp đồng` để
        // một câu hỏi duy nhất kéo về đủ 500 ứng viên.
        for index in 0 ..< chunks {
            let a = Int(generator.next() % UInt64(nodes))
            let b = Int(generator.next() % UInt64(nodes))
            text += "{\"id\":\"c\(index)\",\"text\":\"hợp đồng số \(index) giữa "
                + "N\(a) và N\(b) đã ký duyệt\"}\n"
        }
        try text.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)

        FileHandle.standardError.write(Data("   dựng đồ thị \(nodes) node…\n".utf8))
        var dot = "graph {\n"
        for node in 0 ..< nodes {
            // Vành khuyên cộng dây cung: mọi node có bậc ≥ 2, nên vùng láng giềng 2-hop không
            // rỗng ở bất kỳ điểm xuất phát nào — đúng hình dạng mà phép xếp lại phải chạy thật.
            dot += "  N\(node) -- N\((node + 1) % nodes);\n"
            dot += "  N\(node) -- N\((node + 7) % nodes);\n"
        }
        dot += "}\n"
        let graph = GraphCSR(DOTGraph.parse(dot))
        let dictionary = HybridRetrieval.dictionary(for: graph)

        var samples: [Double] = []
        var candidates = 0
        for query in 0 ..< queries {
            let node = (query * 13) % nodes
            let result = HybridRetrieval.search(
                "hợp đồng N\(node)", k: 20, index: index, graph: graph,
                dictionary: dictionary, config: HybridRetrieval.Config(candidateCount: 500))
            samples.append(result.rerankMilliseconds)
            // Đếm ứng viên bằng CHÍNH lượt BM25 mà phép xếp lại dùng, không bằng `hits.count`:
            // `hits` là top-k trả về cho người dùng (20), còn thứ chỉ tiêu nói tới là tập ứng
            // viên ĐƯA VÀO xếp lại (500). Bản đầu đếm nhầm và bộ đo báo "20 ứng viên" cho một
            // lượt chạy trên 500.
            candidates = max(candidates, index.search("hợp đồng N\(node)", k: 500).count)
        }

        // Trung vị theo STP §4.1, và ghi cả lượt XẤU NHẤT: một phép xếp lại thỉnh thoảng mất
        // gấp ba là thứ người dùng cảm được, còn trung vị thì che mất.
        let median = Measure.median(samples)
        let worst = samples.max() ?? 0
        let enough = candidates >= 500
        if !enough {
            notes.append("BM25 chỉ trả \(candidates) ứng viên (< 500) — corpus quá nhỏ để "
                         + "kết luận về chỉ tiêu «top-500». Tăng --chunks.")
        }

        let budget = 300.0
        return Report(
            kpi: "NFR-KNW-05", architecture: MiningKPI.architecture(),
            chunks: chunks, graphNodes: nodes, candidates: candidates,
            rerankMs: median, budgetMs: budget, queries: queries,
            medianRerankMs: median, worstRerankMs: worst,
            enoughCandidates: enough,
            pass: enough && worst <= budget, notes: notes)
    }
}
