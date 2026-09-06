import Foundation

/// Đưa kết quả thuật toán trở lại HÌNH VẼ và trở lại BẢNG — FR-KNW-914.
///
/// Đặc tả đòi kết quả có **ba đích**: *"bảng xếp hạng; TÔ MÀU ngược lên Graph Preview (kích
/// thước node theo PageRank, màu theo cộng đồng); cột mới trong bảng node ra tab mới"*. Tệp này
/// lo hai đích sau; đích thứ nhất là bảng, tầng app dựng.
///
/// ## "Kích thước node theo PageRank" — Mermaid không làm được, và ta nói ra
///
/// Mermaid không cho đặt kích thước từng node; nó tự bố cục. Thứ nó cho là **độ dày viền**.
/// Nên PageRank vào độ dày viền chứ không vào kích thước, và câu ấy nằm trong chú giải hiện
/// cạnh hình — không giấu. Một bản đồ chú giải sai là một bản đồ dẫn sai đường.
public enum GraphOverlay {

    /// Bảng màu cho cộng đồng.
    ///
    /// Không dùng thang đỏ–lục: 8% nam giới đọc nó thành một mảng xám đồng đều, và hai cộng
    /// đồng cạnh nhau sẽ trông y hệt. Cùng lý do đã chọn thang lam↔cam cho heatmap tương quan
    /// của FR-MIN-005.
    ///
    /// Màu nhạt vì chữ trên node là chữ đen: một nền đậm làm nhãn biến mất, và nhãn là thứ
    /// người dùng dùng để bấm.
    public static let communityColours = [
        "#cfe3f7", "#ffe0b2", "#d7ccc8", "#c8e6c9", "#f8bbd0", "#d1c4e9",
        "#b2ebf2", "#fff9c4", "#ffccbc", "#e0e0e0",
    ]

    /// Bao nhiêu mức độ dày viền cho PageRank.
    ///
    /// Bốn mức, không phải một thang liên tục: mắt người không đọc được chênh lệch 1 px, và một
    /// thang liên tục trên 125.000 node chỉ tạo ra nhiễu.
    ///
    /// Ranh giới là PHÂN VỊ, và phép so là NGẶT — nên điểm hoà nhau rơi xuống mức dưới. Một đồ
    /// thị mà phần lớn node bằng điểm nhau (hình sao chẳng hạn) khi ấy có đúng một node nổi lên,
    /// thay vì cả đồ thị cùng dày viền.
    public static let strokeTiers = [1, 2, 4, 6]

    public struct Legend: Equatable, Sendable {
        public var lines: [String]
    }

    /// Kiểu vẽ cho từng node, cộng chú giải đi kèm.
    ///
    /// - Parameter communities: nhãn cộng đồng theo số hiệu node, `nil` = không tô màu.
    /// - Parameter pageRank: điểm theo số hiệu node, `nil` = không đổi viền.
    public static func styles(
        for graph: GraphCSR, communities: [Int]?, pageRank: [Double]?
    ) -> (styles: DOTToMermaid.NodeStyles, legend: Legend) {
        var styles: DOTToMermaid.NodeStyles = [:]
        var legend: [String] = []

        var tiers: [Int] = []
        if let pageRank, !pageRank.isEmpty {
            // Ngưỡng theo PHÂN VỊ, không theo giá trị: PageRank lệch nặng về một phía (vài node
            // rất cao, phần lớn gần bằng nhau), nên chia đều theo giá trị sẽ dồn 99% node vào
            // một mức và mức ấy nói lên đúng con số không.
            let sorted = pageRank.sorted()
            let cuts = [0.5, 0.8, 0.95].map { fraction -> Double in
                sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction))]
            }
            // So sánh NGẶT, không phải `>=`. Với `>=`, một đồ thị mà phần lớn node bằng điểm
            // nhau (rất thường gặp: mọi node lá của một hình sao) sẽ có ngưỡng phân vị RƠI ĐÚNG
            // vào giá trị chung ấy, và toàn bộ node nhảy lên mức cao nhất — đúng ngược ý định.
            // Ngặt thì hoà rơi xuống mức dưới, nên «viền dày hơn» luôn có nghĩa «điểm cao hơn».
            tiers = pageRank.map { score in
                if score > cuts[2] { return 3 }
                if score > cuts[1] { return 2 }
                if score > cuts[0] { return 1 }
                return 0
            }
            legend.append("Độ dày viền = PageRank (4 mức theo phân vị 50/80/95). "
                + "Mermaid KHÔNG cho đặt kích thước node, nên «kích thước theo PageRank» của "
                + "đặc tả được thể hiện bằng độ dày viền.")
        }

        for node in 0 ..< graph.nodeCount {
            var parts: [String] = []
            if let communities, node < communities.count {
                let colour = communityColours[communities[node] % communityColours.count]
                parts.append("fill:\(colour)")
            }
            if node < tiers.count {
                parts.append("stroke-width:\(strokeTiers[tiers[node]])px")
            }
            guard !parts.isEmpty else { continue }
            styles[graph.names[node]] = parts.joined(separator: ",")
        }

        if let communities, !communities.isEmpty {
            let count = Set(communities).count
            legend.insert("Màu nền = cộng đồng (\(count) cộng đồng, "
                + "\(communityColours.count) màu xoay vòng — hai cộng đồng xa nhau có thể "
                + "trùng màu).", at: 0)
        }
        return (styles, Legend(lines: legend))
    }

    /// Bảng node kèm CỘT MỚI, dạng CSV — đích thứ ba của đặc tả.
    ///
    /// CSV chứ không phải một bảng trong bộ nhớ: mở ra tab mới thì nó là một tài liệu thật,
    /// lọc/sắp/truy vấn SQL được bằng chính những công cụ đã có, và lưu lại được. Một bảng chỉ
    /// hiện trên màn hình là một bảng biến mất khi đóng panel.
    public static func nodeTableCSV(
        for graph: GraphCSR,
        pageRank: GraphAlgorithms.PageRank?,
        communities: GraphAlgorithms.Communities?,
        components: GraphAlgorithms.Components?
    ) -> String {
        var titles = ["id", "ten", "bac_ra", "bac_vao"]
        if pageRank != nil { titles += ["pagerank", "hang_pagerank"] }
        if communities != nil { titles.append("cong_dong") }
        if components != nil { titles.append("thanh_phan") }
        var out = titles.joined(separator: ",") + "\n"

        var rankOf = [Int](repeating: 0, count: graph.nodeCount)
        if let pageRank {
            for (position, node) in pageRank.ranking.enumerated() { rankOf[node] = position + 1 }
        }
        for node in 0 ..< graph.nodeCount {
            var row = [
                graph.names[node], graph.displays[node],
                String(graph.degree(node, .out)), String(graph.degree(node, .incoming)),
            ]
            if let pageRank {
                row.append(String(format: "%.8f", pageRank.scores[node]))
                row.append(String(rankOf[node]))
            }
            if let communities { row.append(String(communities.labels[node])) }
            if let components { row.append(String(components.labels[node])) }
            out += row.map(field).joined(separator: ",") + "\n"
        }
        return out
    }

    private static func field(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Bảng xếp hạng — đích thứ nhất.
    public static func ranking(
        _ pageRank: GraphAlgorithms.PageRank, in graph: GraphCSR, limit: Int = 20
    ) -> [(name: String, score: Double, rank: Int)] {
        pageRank.ranking.prefix(limit).enumerated().map { position, node in
            (graph.displays[node], pageRank.scores[node], position + 1)
        }
    }
}
