import XCTest
@testable import GEditorCore

/// FR-KNW-914 — thuật toán đồ thị.
final class GraphAlgorithmsTests: XCTestCase {

    /// Đồ thị nhỏ, mọi kỳ vọng tính tay.
    ///
    /// ```
    /// a → b → c
    /// a → c
    /// d → e            (thành phần thứ hai)
    /// f                (mồ côi)
    /// ```
    private func sample() -> GraphCSR {
        GraphCSR(DOTGraph.parse("""
            digraph {
                a -> b;
                b -> c;
                a -> c;
                d -> e;
                f;
            }
            """))
    }

    private func names(_ graph: GraphCSR, _ nodes: [Int]) -> [String] {
        nodes.map { graph.names[$0] }
    }

    // MARK: - CSR

    func testCSRDungBacVaHangXom() {
        let graph = sample()
        XCTAssertEqual(graph.nodeCount, 6)
        XCTAssertEqual(graph.edgeCount, 4)
        let a = graph.index(of: "a")!
        XCTAssertEqual(graph.degree(a, .out), 2)
        XCTAssertEqual(graph.degree(a, .incoming), 0)
        XCTAssertEqual(graph.degree(a, .both), 2)
        let c = graph.index(of: "c")!
        XCTAssertEqual(graph.degree(c, .out), 0)
        XCTAssertEqual(graph.degree(c, .incoming), 2)
    }

    /// Hàng xóm SẮP theo số hiệu — điều kiện của tính tất định ở mọi thuật toán phía sau.
    func testHANGXOMDuocSap() {
        let graph = GraphCSR(DOTGraph.parse("digraph { a -> z; a -> b; a -> m }"))
        let a = graph.index(of: "a")!
        let targets = graph.range(a, .out).map { graph.target($0, .out) }
        XCTAssertEqual(targets, targets.sorted())
    }

    // MARK: - k-hop

    /// Từ `a`, bỏ hướng: 1 hop = {b, c}; 2 hop thêm gì? b và c đã có, nên không thêm.
    func testKHOPDemDungTang() {
        let graph = sample()
        let a = graph.index(of: "a")!
        let one = GraphAlgorithms.neighbourhood(of: [a], k: 1, in: graph)
        XCTAssertEqual(Set(names(graph, one.nodes.map(\.node))), Set(["b", "c"]))
        XCTAssertTrue(one.nodes.allSatisfy { $0.hops == 1 })

        let two = GraphAlgorithms.neighbourhood(of: [a], k: 2, in: graph)
        XCTAssertEqual(Set(names(graph, two.nodes.map(\.node))), Set(["b", "c"]))
    }

    /// «Hop» là số bước ÍT NHẤT, không phải «có một đường đi dài k bước».
    ///
    /// `c` tới được từ `a` bằng một bước (a→c) và bằng hai bước (a→b→c). Đáp án phải là 1.
    func testHOPLaSoBuocItNhat() {
        let graph = sample()
        let a = graph.index(of: "a")!
        let result = GraphAlgorithms.neighbourhood(of: [a], k: 2, in: graph, view: .out)
        let c = graph.index(of: "c")!
        XCTAssertEqual(result.nodes.first { $0.node == c }?.hops, 1)
    }

    /// Node gốc KHÔNG nằm trong kết quả.
    func testNODEGOCKhongNamTrongKetQua() {
        let graph = sample()
        let a = graph.index(of: "a")!
        let result = GraphAlgorithms.neighbourhood(of: [a], k: 3, in: graph)
        XCTAssertFalse(result.nodes.contains { $0.node == a })
    }

    /// Chiều đi và chiều tới cho hai câu trả lời KHÁC nhau.
    func testCHIEUDiVaChieuToiKhacNhau() {
        let graph = sample()
        let c = graph.index(of: "c")!
        XCTAssertTrue(GraphAlgorithms.neighbourhood(of: [c], k: 1, in: graph, view: .out)
            .nodes.isEmpty)
        XCTAssertEqual(
            Set(names(graph, GraphAlgorithms.neighbourhood(
                of: [c], k: 1, in: graph, view: .incoming).nodes.map(\.node))),
            Set(["a", "b"]))
    }

    // MARK: - Đường đi ngắn nhất

    /// Không trọng số: a → c là một bước, không phải hai.
    func testDUONGDIKhongTrongSo() {
        let graph = sample()
        let path = GraphAlgorithms.shortestPath(
            from: graph.index(of: "a")!, to: graph.index(of: "c")!, in: graph)
        XCTAssertEqual(names(graph, path.nodes), ["a", "c"])
        XCTAssertEqual(path.cost, 1)
        XCTAssertFalse(path.usedWeights)
        XCTAssertTrue(path.methodology.contains("BFS"), path.methodology)
    }

    /// Có trọng số thì đường RẺ nhất, không phải đường ÍT CẠNH nhất.
    ///
    /// `a -> c` nặng 10, còn `a -> b -> c` nặng 1 + 1 = 2. BFS sẽ trả về đường một cạnh và SAI.
    func testDUONGDICoTrongSoChonDuongReNhat() {
        let graph = GraphCSR(DOTGraph.parse("""
            digraph {
                a -> c [weight=10];
                a -> b [weight=1];
                b -> c [weight=1];
            }
            """))
        let path = GraphAlgorithms.shortestPath(
            from: graph.index(of: "a")!, to: graph.index(of: "c")!, in: graph)
        XCTAssertEqual(names(graph, path.nodes), ["a", "b", "c"])
        XCTAssertEqual(path.cost, 2, accuracy: 1e-12)
        XCTAssertTrue(path.usedWeights)
        XCTAssertTrue(path.methodology.contains("Dijkstra"), path.methodology)
    }

    /// Đồ thị TRỘN cạnh có và không khai trọng số thì Phương pháp phải CẢNH BÁO.
    ///
    /// Cạnh không khai được tính là 1 — đó là một giả định, không phải một số đo, và người đọc
    /// bảng đường đi cần biết mình đang đọc cái gì.
    func testTRONTrongSoThiCanhBao() {
        let graph = GraphCSR(DOTGraph.parse("digraph { a -> b [weight=5]; b -> c }"))
        let path = GraphAlgorithms.shortestPath(
            from: graph.index(of: "a")!, to: graph.index(of: "c")!, in: graph)
        XCTAssertTrue(path.methodology.contains("GIẢ ĐỊNH"), path.methodology)
    }

    func testKHONGCoDuongDiThiTraRong() {
        let graph = sample()
        let path = GraphAlgorithms.shortestPath(
            from: graph.index(of: "a")!, to: graph.index(of: "e")!, in: graph)
        XCTAssertTrue(path.nodes.isEmpty)
    }

    // MARK: - Thành phần liên thông

    /// Ba thành phần: {a,b,c} · {d,e} · {f}.
    func testTHANHPHANLienThongDemTay() {
        let result = GraphAlgorithms.connectedComponents(in: sample())
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.sizes, [3, 2, 1])
        XCTAssertEqual(result.isolatedCount, 1)
    }

    /// Bỏ hướng, KHÔNG phải liên thông mạnh.
    ///
    /// `a -> b` một chiều: liên thông mạnh sẽ cho hai thành phần, bỏ hướng cho một.
    func testBOHUONGChuKhongPhaiLienThongManh() {
        let result = GraphAlgorithms.connectedComponents(
            in: GraphCSR(DOTGraph.parse("digraph { a -> b }")))
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.methodology.contains("liên thông mạnh"), result.methodology)
    }

    // MARK: - PageRank

    /// Tổng điểm PageRank luôn bằng 1 — kể cả khi có node không có cạnh đi ra.
    ///
    /// Đây là chỗ mọi cài đặt hay sai: điểm của node «dangling» biến mất sau mỗi vòng và tổng
    /// tụt dần về 0. Thứ tự xếp hạng vẫn "trông đúng", nên lỗi ấy sống rất lâu.
    func testTONGDIEMPageRankBangMot() {
        for text in [
            "digraph { a -> b; b -> c; a -> c }",          // c là dangling
            "digraph { a -> b; b -> a }",
            "digraph { a; b; c }",                          // KHÔNG cạnh nào
        ] {
            let result = GraphAlgorithms.pageRank(in: GraphCSR(DOTGraph.parse(text)))
            XCTAssertEqual(result.scores.reduce(0, +), 1, accuracy: 1e-9, text)
        }
    }

    /// Node được trỏ tới nhiều hơn thì điểm cao hơn.
    func testPAGERANKNodeDuocTroToiNhieuThiCaoHon() {
        let graph = GraphCSR(DOTGraph.parse("""
            digraph { a -> z; b -> z; c -> z; a -> b }
            """))
        let result = GraphAlgorithms.pageRank(in: graph)
        XCTAssertEqual(graph.names[result.ranking[0]], "z")
    }

    /// Ngưỡng hội tụ HIỂN THỊ — đặc tả đòi thẳng.
    func testPAGERANKNoiRaSoVongVaChenhLech() {
        let result = GraphAlgorithms.pageRank(in: sample())
        XCTAssertGreaterThan(result.iterations, 0)
        XCTAssertTrue(result.converged)
        XCTAssertTrue(result.methodology.contains("damping 0.85"), result.methodology)
        XCTAssertTrue(result.methodology.contains("hội tụ"), result.methodology)
    }

    // MARK: - Louvain

    /// Hai cụm tách hẳn nhau thì Louvain phải tìm ra đúng hai.
    func testLOUVAINTimRaHaiCumTachHan() {
        let graph = GraphCSR(DOTGraph.parse("""
            graph {
                a1 -- a2; a2 -- a3; a3 -- a1;
                b1 -- b2; b2 -- b3; b3 -- b1;
            }
            """))
        let result = GraphAlgorithms.louvain(in: graph)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.sizes.sorted(), [3, 3])
        // Modularity của hai cụm tách hẳn phải cao.
        XCTAssertGreaterThan(result.modularity, 0.4)
    }

    /// Modularity phải được BÁO CÁO, và phần Phương pháp nói ra cái giá của tính tất định.
    func testLOUVAINBaoCaoModularityVaNoiRaDanhDoi() {
        let result = GraphAlgorithms.louvain(in: sample())
        XCTAssertTrue(result.methodology.contains("Modularity"), result.methodology)
        XCTAssertTrue(result.methodology.contains("không xáo trộn"), result.methodology)
        XCTAssertTrue(result.methodology.contains("cực trị địa phương"), result.methodology)
    }

    func testDOTHIKhongCanhThiMoiNodeMotCongDong() {
        let result = GraphAlgorithms.louvain(in: GraphCSR(DOTGraph.parse("digraph { a; b; c }")))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.modularity, 0)
    }

    // MARK: - Tất định và huỷ

    /// Hai lượt chạy cho kết quả GIỐNG HỆT — cả năm thuật toán.
    ///
    /// NFR-MIN-02 đòi tất định, và với thuật toán đồ thị thì chỗ dễ vỡ nhất là duyệt một
    /// `Dictionary` hay `Set` — thứ tự của chúng đổi giữa các lần chạy.
    func testHAILUOTCHAYChoKetQuaGiongHet() {
        var text = "graph {\n"
        for index in 0 ..< 60 {
            text += "  n\(index) -- n\((index * 7 + 3) % 60);\n"
            text += "  n\(index) -- n\((index + 1) % 60);\n"
        }
        text += "}"
        let graph = GraphCSR(DOTGraph.parse(text))

        XCTAssertEqual(
            GraphAlgorithms.neighbourhood(of: [0], k: 3, in: graph),
            GraphAlgorithms.neighbourhood(of: [0], k: 3, in: graph))
        XCTAssertEqual(
            GraphAlgorithms.connectedComponents(in: graph),
            GraphAlgorithms.connectedComponents(in: graph))
        XCTAssertEqual(GraphAlgorithms.pageRank(in: graph), GraphAlgorithms.pageRank(in: graph))
        XCTAssertEqual(GraphAlgorithms.louvain(in: graph), GraphAlgorithms.louvain(in: graph))
        XCTAssertEqual(
            GraphAlgorithms.shortestPath(from: 0, to: 30, in: graph),
            GraphAlgorithms.shortestPath(from: 0, to: 30, in: graph))
    }

    /// Huỷ giữa chừng trả kết quả DÙNG ĐƯỢC kèm cờ, không ném lỗi làm mất công đã làm.
    func testHUYGiuaChungTraKetQuaKemCo() {
        var text = "graph {\n"
        for index in 0 ..< 500 { text += "  n\(index) -- n\((index + 1) % 500);\n" }
        text += "}"
        let graph = GraphCSR(DOTGraph.parse(text))

        let token = CancelToken()
        token.cancel()
        XCTAssertTrue(GraphAlgorithms.connectedComponents(in: graph, cancelToken: token)
            .wasCancelled)
        XCTAssertTrue(GraphAlgorithms.pageRank(in: graph, cancelToken: token).wasCancelled)
        XCTAssertTrue(GraphAlgorithms.louvain(in: graph, cancelToken: token).wasCancelled)
        XCTAssertTrue(GraphAlgorithms.neighbourhood(
            of: [0], k: 5, in: graph, cancelToken: token).wasCancelled)
    }
}

// MARK: - Đưa kết quả về hình và về bảng

/// FR-KNW-914 — ba đích của kết quả.
final class GraphOverlayTests: XCTestCase {

    private func sample() -> (DOTGraph, GraphCSR) {
        let graph = DOTGraph.parse("""
            graph {
                a1 -- a2; a2 -- a3; a3 -- a1;
                b1 -- b2; b2 -- b3; b3 -- b1;
                a1 -- b1;
            }
            """)
        return (graph, GraphCSR(graph))
    }

    /// Màu theo cộng đồng, và chú giải NÓI RA màu xoay vòng.
    func testMAUTheoCongDongVaChuGiaiNoiRaGioiHan() {
        let (_, csr) = sample()
        let communities = GraphAlgorithms.louvain(in: csr)
        let result = GraphOverlay.styles(
            for: csr, communities: communities.labels, pageRank: nil)
        XCTAssertEqual(result.styles.count, csr.nodeCount)
        XCTAssertTrue(result.styles["a1"]?.contains("fill:") ?? false)
        XCTAssertTrue(result.legend.lines.joined().contains("xoay vòng"),
                      "\(result.legend.lines)")
    }

    /// "Kích thước node theo PageRank" thành ĐỘ DÀY VIỀN, và chú giải nói thẳng vì sao.
    ///
    /// Mermaid không cho đặt kích thước từng node. Một chú giải nói "kích thước" trong khi hình
    /// vẽ đổi viền là một bản đồ dẫn sai đường.
    func testPAGERANKThanhDoDayVienVaNoiRaVISAO() {
        let (_, csr) = sample()
        let pageRank = GraphAlgorithms.pageRank(in: csr)
        let result = GraphOverlay.styles(for: csr, communities: nil, pageRank: pageRank.scores)
        XCTAssertTrue(result.styles.values.contains { $0.contains("stroke-width") })
        let legend = result.legend.lines.joined()
        XCTAssertTrue(legend.contains("Độ dày viền"), legend)
        XCTAssertTrue(legend.contains("KHÔNG cho đặt kích thước"), legend)
    }

    /// Điểm HOÀ NHAU rơi xuống mức DƯỚI, không nhảy lên mức trên.
    ///
    /// Bản đầu so `>=` với ngưỡng phân vị, và một hình sao (20 node lá bằng điểm nhau, một node
    /// trung tâm) làm ngưỡng rơi đúng vào giá trị chung — toàn bộ 21 node nhảy lên mức dày
    /// nhất, tức bản đồ nói "ai cũng quan trọng". So NGẶT thì «viền dày hơn» luôn có nghĩa
    /// «điểm cao hơn».
    func testDIEMHOANHAURoiXuongMucDuoi() {
        var text = "digraph {\n"
        for index in 0 ..< 20 { text += "  n\(index) -> hub;\n" }
        text += "}"
        let csr = GraphCSR(DOTGraph.parse(text))
        let pageRank = GraphAlgorithms.pageRank(in: csr)
        let result = GraphOverlay.styles(for: csr, communities: nil, pageRank: pageRank.scores)
        func width(_ name: String) -> String {
            result.styles[name]?.components(separatedBy: "stroke-width:").last ?? ""
        }
        XCTAssertEqual(width("hub"), "6px", "node trung tâm phải ở mức dày nhất")
        XCTAssertEqual(width("n0"), "1px", "node lá bằng điểm nhau phải ở mức mỏng nhất")
    }

    /// Mọi node bằng điểm nhau thì KHÔNG node nào nổi lên.
    func testMOINodeBangDiemThiKhongAiNoiLen() {
        let csr = GraphCSR(DOTGraph.parse("digraph { a -> b; b -> c; c -> a }"))
        let pageRank = GraphAlgorithms.pageRank(in: csr)
        let result = GraphOverlay.styles(for: csr, communities: nil, pageRank: pageRank.scores)
        XCTAssertEqual(Set(result.styles.values), Set(["stroke-width:1px"]))
    }

    /// Bảng node có CỘT MỚI, và số hạng PageRank khớp với thứ tự xếp hạng.
    func testBANGNODECoCotMoiVaHangKhopXepHang() throws {
        let (_, csr) = sample()
        let pageRank = GraphAlgorithms.pageRank(in: csr)
        let communities = GraphAlgorithms.louvain(in: csr)
        let components = GraphAlgorithms.connectedComponents(in: csr)
        let csv = GraphOverlay.nodeTableCSV(
            for: csr, pageRank: pageRank, communities: communities, components: components)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "id,ten,bac_ra,bac_vao,pagerank,hang_pagerank,cong_dong,thanh_phan")
        XCTAssertEqual(lines.count, csr.nodeCount + 1)

        // Node xếp hạng 1 phải có `hang_pagerank` = 1.
        let best = csr.names[pageRank.ranking[0]]
        let row = try XCTUnwrap(lines.first { $0.hasPrefix(best + ",") })
        XCTAssertEqual(row.split(separator: ",").map(String.init)[5], "1")
    }

    /// Không chạy thuật toán nào thì bảng chỉ có cột CƠ BẢN — không cột rỗng vô nghĩa.
    func testKHONGChayThuatToanThiKhongCoCotRong() {
        let (_, csr) = sample()
        let csv = GraphOverlay.nodeTableCSV(
            for: csr, pageRank: nil, communities: nil, components: nil)
        XCTAssertEqual(csv.split(separator: "\n")[0], "id,ten,bac_ra,bac_vao")
    }

    /// Kiểu vẽ đi vào bản chuyển Mermaid, và hai lượt chuyển cho cùng một chuỗi.
    func testKIEUVEDiVaoBanChuyenVaTatDinh() {
        let (dot, csr) = sample()
        let communities = GraphAlgorithms.louvain(in: csr)
        let styles = GraphOverlay.styles(
            for: csr, communities: communities.labels, pageRank: nil).styles
        let first = DOTToMermaid.convert(dot, styles: styles)
        let second = DOTToMermaid.convert(dot, styles: styles)
        XCTAssertEqual(first.mermaid, second.mermaid)
        XCTAssertTrue(first.mermaid.contains("style n0 fill:"), first.mermaid)
    }
}
