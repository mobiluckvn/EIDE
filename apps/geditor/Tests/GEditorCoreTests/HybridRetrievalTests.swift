import XCTest
@testable import GEditorCore

/// FR-KNW-925 — truy hồi lai BM25 × tín hiệu đồ thị.
final class HybridRetrievalTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("hybrid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    /// Corpus và đồ thị nhỏ, mọi kỳ vọng suy được bằng tay.
    ///
    /// Đồ thị: `An — Bình — Chi`, và `Dũng` đứng riêng.
    /// Corpus: mỗi chunk nhắc tới một người, cộng một chunk nhiễu.
    private func build() throws -> (BM25Index, GraphCSR, HybridRetrieval.EntityDictionary) {
        let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
        try """
            {"id":"c1","text":"hợp đồng do An ký duyệt"}
            {"id":"c2","text":"biên bản do Bình lập"}
            {"id":"c3","text":"quyết định do Chi ban hành"}
            {"id":"c4","text":"ghi chú do Dũng viết"}
            {"id":"c5","text":"hợp đồng mẫu không nhắc ai"}
            """.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let graph = GraphCSR(DOTGraph.parse("""
            graph {
                An -- "Bình";
                "Bình" -- Chi;
                "Dũng";
            }
            """))
        return (index, graph, HybridRetrieval.dictionary(for: graph))
    }

    // MARK: - Ràng buộc α = 1

    /// **Ràng buộc đắt nhất của cả tính năng**: α = 1 phải trùng BM25 thuần.
    ///
    /// Đặc tả đòi kiểm bằng test, và đây là cái neo: một phép lai không quy về được baseline
    /// của nó là một phép lai mà không ai kiểm được.
    func testALPHAMotTrungBM25Thuan() throws {
        let (index, graph, dictionary) = try build()
        for question in ["hợp đồng An", "biên bản Bình", "quyết định", "do viết"] {
            let pure = index.search(question, k: 5).map(\.document)
            let hybrid = HybridRetrieval.search(
                question, k: 5, index: index, graph: graph, dictionary: dictionary,
                config: .init(alpha: 1)).hits.map(\.document)
            XCTAssertEqual(hybrid, pure, "α = 1 lệch BM25 thuần ở câu «\(question)»")
        }
    }

    /// Kể cả khi MỌI ứng viên cùng điểm — chỗ mà min-max chia cho 0.
    func testALPHAMotTrungBM25ThuanKhiMoiDiemBangNhau() throws {
        let corpus = (folder as NSString).appendingPathComponent("deu.jsonl")
        try (0 ..< 6).map { #"{"id":"c\#($0)","text":"cùng một nội dung"}"# }
            .joined(separator: "\n")
            .write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let graph = GraphCSR(DOTGraph.parse("graph { a -- b }"))
        let dictionary = HybridRetrieval.dictionary(for: graph)

        let pure = index.search("cùng nội dung", k: 4).map(\.document)
        let hybrid = HybridRetrieval.search(
            "cùng nội dung", k: 4, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 1)).hits.map(\.document)
        XCTAssertEqual(hybrid, pure)
    }

    /// Câu hỏi KHÔNG có entity nào thì kết quả cũng rơi về BM25 thuần — với mọi α.
    func testKHONGCoEntityThiRoiVeBM25Thuan() throws {
        let (index, graph, dictionary) = try build()
        let pure = index.search("hợp đồng mẫu", k: 5).map(\.document)
        for alpha in [0.0, 0.4, 0.7] {
            let result = HybridRetrieval.search(
                "hợp đồng mẫu", k: 5, index: index, graph: graph, dictionary: dictionary,
                config: .init(alpha: alpha))
            XCTAssertEqual(result.hits.map(\.document), pure, "α = \(alpha)")
            XCTAssertTrue(result.methodology.contains("KHÔNG nhận ra entity"),
                          result.methodology)
        }
    }

    // MARK: - Tín hiệu đồ thị

    /// Entity trong câu hỏi được nhận ra, và vùng láng giềng đúng bán kính.
    func testNHANRAEntityVaVungLangGieng() throws {
        let (index, graph, dictionary) = try build()
        let result = HybridRetrieval.search(
            "An ký gì", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.5, hops: 1))
        XCTAssertEqual(result.queryEntities, ["An"])
        // 1-hop từ An: chính An + Bình = 2 node.
        XCTAssertEqual(result.neighbourhoodSize, 2)

        let two = HybridRetrieval.search(
            "An ký gì", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.5, hops: 2))
        // 2-hop thêm Chi.
        XCTAssertEqual(two.neighbourhoodSize, 3)
    }

    /// Chunk nhắc entity LÁNG GIỀNG được cộng điểm; chunk nhắc entity ngoài vùng thì không.
    ///
    /// `Dũng` đứng riêng trên đồ thị, nên chunk của Dũng phải có tín hiệu 0 dù nó cũng là một
    /// entity hợp lệ.
    func testCHUNKNgoaiVungKhongDuocCongDiem() throws {
        let (index, graph, dictionary) = try build()
        let result = HybridRetrieval.search(
            "An Bình Chi Dũng do", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.5, hops: 1))
        // Câu hỏi nhắc cả bốn, nên cả bốn đều ở hop 0 → mọi chunk đều có tín hiệu.
        XCTAssertEqual(Set(result.queryEntities), Set(["An", "Bình", "Chi", "Dũng"]))

        // Câu hỏi chỉ nhắc An, bán kính 1: chunk của Chi và Dũng nằm ngoài vùng.
        let narrow = HybridRetrieval.search(
            "An do", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.5, hops: 1))
        func signal(_ identifier: String) -> Double {
            let document = (try? index.identifierMap())?[identifier]?.first ?? -1
            return narrow.hits.first { $0.document == document }?.graphSignal ?? -1
        }
        XCTAssertEqual(signal("c1"), 1, accuracy: 1e-12, "chunk của An: entity ở hop 0")
        XCTAssertEqual(signal("c2"), 1, accuracy: 1e-12, "chunk của Bình: hop 1 → 1/1")
        XCTAssertEqual(signal("c3"), 0, accuracy: 1e-12, "Chi ở hop 2, ngoài bán kính 1")
        XCTAssertEqual(signal("c4"), 0, accuracy: 1e-12, "Dũng không nối với ai")
    }

    /// Trọng số 1/hop: entity ở hop 2 đóng góp một nửa so với hop 1.
    func testTRONGSOMotChiaHop() throws {
        let (index, graph, dictionary) = try build()
        let result = HybridRetrieval.search(
            "An do", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.5, hops: 2))
        let map = try index.identifierMap()
        func signal(_ identifier: String) -> Double {
            let document = map[identifier]?.first ?? -1
            return result.hits.first { $0.document == document }?.graphSignal ?? -1
        }
        XCTAssertEqual(signal("c2"), 1, accuracy: 1e-12, "Bình ở hop 1 → 1/1")
        XCTAssertEqual(signal("c3"), 0.5, accuracy: 1e-12, "Chi ở hop 2 → 1/2")
    }

    /// Entity DÀI thắng entity ngắn nằm trong nó.
    ///
    /// «Ngân hàng Nhà nước» phải thắng «Ngân hàng»; khớp ngắn trước thì entity dài không bao
    /// giờ được nhận và tín hiệu đồ thị trỏ vào một node chung chung.
    func testENTITYDaiThangEntityNgan() {
        let graph = GraphCSR(DOTGraph.parse("""
            graph { "Ngân hàng" -- "Ngân hàng Nhà nước" }
            """))
        let dictionary = HybridRetrieval.dictionary(for: graph)
        let found = HybridRetrieval.entities(
            in: "quyết định của Ngân hàng Nhà nước", using: dictionary)
        XCTAssertEqual(found.map { graph.displays[$0] }, ["Ngân hàng Nhà nước"])
    }

    // MARK: - Phép lai

    /// α nhỏ hơn thì tín hiệu đồ thị đổi được thứ hạng — dựng hẳn một ca mà nó PHẢI đổi.
    ///
    /// Ca này phải xây cẩn thận, và bản đầu của nó xây sai: tôi cho entity «An» vào cả câu hỏi
    /// lẫn một chunk, và quên rằng «An» là từ HIẾM nên BM25 tự nó đã xếp chunk ấy lên đầu —
    /// phép lai không có gì để chứng minh.
    ///
    /// Bản này: câu hỏi «hồ sơ An», chunk A lặp «hồ sơ» ba lần và KHÔNG nhắc ai, chunk B nhắc
    /// «Bình» (cách An một hop) và chỉ có «hồ sơ» một lần. BM25 xếp A trước; với α nhỏ, tín
    /// hiệu đồ thị phải kéo B lên.
    func testALPHANhoThiDoThiDoiDuocThuHang() throws {
        let corpus = (folder as NSString).appendingPathComponent("xephang.jsonl")
        try """
            {"id":"a","text":"hồ sơ hồ sơ hồ sơ"}
            {"id":"b","text":"hồ sơ của Bình"}
            """.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let graph = GraphCSR(DOTGraph.parse("graph { An -- \"Bình\" }"))
        let dictionary = HybridRetrieval.dictionary(for: graph)

        let pure = HybridRetrieval.search(
            "hồ sơ An", k: 2, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 1)).hits.map(\.document)
        XCTAssertEqual(pure, [0, 1], "tiền đề: BM25 xếp chunk lặp từ lên trước")

        let hybrid = HybridRetrieval.search(
            "hồ sơ An", k: 2, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.1, hops: 1)).hits.map(\.document)
        XCTAssertEqual(hybrid, [1, 0], "α nhỏ thì chunk có entity láng giềng phải vượt lên")
    }

    /// **Giới hạn phải nói ra**: phép lai chỉ XẾP LẠI thứ BM25 đã tìm ra.
    ///
    /// Một chunk nằm ngoài top-N ứng viên thì tín hiệu đồ thị mạnh đến mấy cũng không cứu được
    /// — nó không có mặt để mà xếp lại. Phép lai cải thiện THỨ TỰ, không cải thiện ĐỘ PHỦ.
    func testPHEPLAIKhongCuuDuocChunkNamNgoaiUngVien() throws {
        let (index, graph, dictionary) = try build()
        // Chỉ lấy MỘT ứng viên: chunk của Bình không lọt vào, dù nó ở hop 1 của An.
        let result = HybridRetrieval.search(
            "An do", k: 5, index: index, graph: graph, dictionary: dictionary,
            config: .init(alpha: 0.1, candidateCount: 1, hops: 1))
        XCTAssertEqual(result.hits.count, 1)
        XCTAssertTrue(result.methodology.contains("không cứu được"), result.methodology)
    }

    /// Điểm lai đúng CÔNG THỨC, tính tay từ hai thành phần đã có trong kết quả.
    func testDIEMLAIDungCongThuc() throws {
        let (index, graph, dictionary) = try build()
        let config = HybridRetrieval.Config(alpha: 0.7, hops: 2)
        let result = HybridRetrieval.search(
            "An do", k: 5, index: index, graph: graph, dictionary: dictionary, config: config)
        for hit in result.hits {
            XCTAssertEqual(
                hit.score,
                config.alpha * hit.normalizedBM25 + (1 - config.alpha) * hit.graphSignal,
                accuracy: 1e-12)
        }
    }

    /// Hai lượt chạy cho kết quả GIỐNG HỆT.
    func testHAILUOTCHAYGiongHet() throws {
        let (index, graph, dictionary) = try build()
        let first = HybridRetrieval.search(
            "An Bình do", k: 5, index: index, graph: graph, dictionary: dictionary)
        let second = HybridRetrieval.search(
            "An Bình do", k: 5, index: index, graph: graph, dictionary: dictionary)
        XCTAssertEqual(first.hits, second.hits)
    }

    /// Phương pháp nói ra công thức, α, bán kính, và NGUỒN của danh sách entity.
    func testPHUONGPHAPNoiRaCongThucVaNguonDanhSachEntity() throws {
        let (index, graph, dictionary) = try build()
        let text = HybridRetrieval.search(
            "An do", k: 3, index: index, graph: graph, dictionary: dictionary).methodology
        XCTAssertTrue(text.contains("norm(BM25)"), text)
        XCTAssertTrue(text.contains("1/hop"), text)
        XCTAssertTrue(text.contains("tên và nhãn node"), text)
    }

    // MARK: - Đánh giá A/B/C

    /// Ba lượt trên CÙNG bộ đánh giá, và lượt đầu là BM25 thuần.
    func testABCTrenCungBoDanhGia() throws {
        let (index, graph, dictionary) = try build()
        let golden: [RetrievalEval.Query] = [
            .init(id: "q1", question: "An ký", relevant: ["c1"]),
            .init(id: "q2", question: "Bình lập", relevant: ["c2"]),
            .init(id: "q3", question: "An liên quan ai", relevant: ["c2", "c3"]),
        ]
        let result = HybridRetrieval.bakeoff(
            golden: golden, k: 3, index: index, graph: graph, dictionary: dictionary,
            identifierMap: try index.identifierMap())

        XCTAssertEqual(result.trials.count, 3)
        XCTAssertEqual(result.trials[0].name, "BM25 thuần")
        XCTAssertTrue(result.trials[1].name.contains("0.7"))
        XCTAssertEqual(result.comparisons.count, 2)
        // Mọi lượt chấm CÙNG số câu — nếu không thì bảng delta so hai phép đo khác nhau.
        XCTAssertEqual(Set(result.trials.map { $0.report.summary.queryCount }), [3])
        XCTAssertTrue(result.methodology.contains("đa hop"), result.methodology)
    }

    /// Nhóm câu ĐA HOP tách riêng, và định nghĩa của nó tính được từ dữ liệu.
    func testNHOMCAUDaHopTachRieng() throws {
        let (index, graph, dictionary) = try build()
        // «An liên quan ai» — chunk đúng là c3 (Chi), và Chi cách An 2 hop.
        // Câu hỏi phải KHIẾN BM25 trả về chunk đúng, nếu không thì phép lai chẳng có gì để xếp
        // lại — xem `testPHEPLAIKhongCuuDuocChunkNamNgoaiUngVien`.
        let golden: [RetrievalEval.Query] = [
            .init(id: "gan", question: "An ký hợp đồng", relevant: ["c1"]),
            .init(id: "xa", question: "An quyết định ban hành", relevant: ["c3"]),
        ]
        let result = HybridRetrieval.bakeoff(
            golden: golden, k: 5, index: index, graph: graph, dictionary: dictionary,
            identifierMap: try index.identifierMap())
        let hybrid = result.trials[1]
        XCTAssertTrue(hybrid.multiHopQueryIDs.contains("xa"),
                      "\(hybrid.multiHopQueryIDs)")
        XCTAssertFalse(hybrid.multiHopQueryIDs.contains("gan"))
    }
}
