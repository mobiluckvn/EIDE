import XCTest
@testable import GEditorCore

/// FR-KNW-924 — Graph Quality Report, và phép so mờ dùng chung.
final class TextDistanceTests: XCTestCase {

    func testLEVENSHTEINTinhTay() {
        func distance(_ a: String, _ b: String) -> Int {
            TextDistance.levenshtein(Array(a.utf8), Array(b.utf8), limit: 99)
        }
        XCTAssertEqual(distance("", ""), 0)
        XCTAssertEqual(distance("abc", "abc"), 0)
        XCTAssertEqual(distance("abc", "abd"), 1)          // thay một
        XCTAssertEqual(distance("abc", "ab"), 1)           // xoá một
        XCTAssertEqual(distance("ab", "abc"), 1)           // thêm một
        XCTAssertEqual(distance("kitten", "sitting"), 3)   // ví dụ kinh điển
    }

    /// Trần CẮT SỚM: vượt trần thì trả `limit + 1`, không tính tiếp.
    func testTRANCatSom() {
        let a = Array(String(repeating: "a", count: 200).utf8)
        let b = Array(String(repeating: "b", count: 200).utf8)
        XCTAssertEqual(TextDistance.levenshtein(a, b, limit: 5), 6)
    }

    /// Chênh lệch ĐỘ DÀI đã vượt trần thì khỏi tính — đó là cận dưới của khoảng cách.
    func testCHENHLECHDoDaiLaCanDuoi() {
        XCTAssertEqual(TextDistance.levenshtein(Array("a".utf8), Array("abcdef".utf8), limit: 2), 3)
    }

    /// Chuẩn hoá: bỏ dấu, hạ chữ thường, gom khoảng trắng.
    ///
    /// Bỏ dấu ở ĐÂY thì đúng, khác hẳn `BM25Tokenizer` (GIỮ dấu): ở đây ta tìm những nhãn đáng
    /// lẽ là MỘT mà bị gõ khác nhau, và thiếu dấu là kiểu gõ khác phổ biến nhất.
    func testCHUANHOABoDauVaGomKhoangTrang() {
        XCTAssertEqual(
            TextDistance.similarity("Nguyễn  Văn A", "nguyen van a", threshold: 0.8), 1,
            accuracy: 1e-12)
    }

    /// Chia cho chuỗi DÀI hơn, không cho trung bình.
    ///
    /// «An» và «An Nguyễn Văn» khác nhau 11 ký tự trên 13; chia cho trung bình sẽ cho ra một
    /// con số nghe như "khá giống".
    func testCHIACHOChuoiDaiHon() {
        let value = TextDistance.similarity("An", "An Nguyen Van", threshold: 0.5)
        XCTAssertEqual(value, 0, accuracy: 1e-12, "vượt ngưỡng thì trả 0")
    }

    func testGOMCUMBacCau() {
        // «Nguyen Van A» ≈ «Nguyễn Văn A» ≈ «Nguyen Van Á»; «Trần Thị B» đứng riêng.
        let values = ["Nguyen Van A", "Nguyễn Văn A", "Nguyen Van Á", "Trần Thị B"]
        let clusters = TextDistance.clusters(values, threshold: 0.85)
        XCTAssertEqual(clusters, [[0, 1, 2]])
    }

    func testKHONGGANNhauThiKhongGom() {
        XCTAssertTrue(TextDistance.clusters(["An", "Bình", "Chi"], threshold: 0.85).isEmpty)
    }
}

/// FR-KNW-924 — chấm sức khoẻ đồ thị.
final class GraphQualityTests: XCTestCase {

    private func value(
        _ report: GraphQuality.Report, _ dimension: QualityRules.Dimension
    ) -> Double? {
        report.score.dimensions.first { $0.dimension == dimension }?.value
    }

    private func note(
        _ report: GraphQuality.Report, _ dimension: QualityRules.Dimension
    ) -> String? {
        report.score.dimensions.first { $0.dimension == dimension }?.note
    }

    // MARK: - Bảy phép kiểm

    /// Node mồ côi: bậc 0.
    func testNODEMOCOI() {
        let report = GraphQuality.run(DOTGraph.parse("""
            digraph {
                a [label="A"];
                b [label="B"];
                coi [label="Mồ côi"];
                a -> b;
            }
            """))
        XCTAssertEqual(report.orphans, ["coi"])
        // 100 × (3 − 1) ÷ 3
        XCTAssertEqual(value(report, .accuracy) ?? -1, 200.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(report.problems(of: .orphan).map(\.line), [3])
    }

    /// Cạnh trùng lặp; trên đồ thị VÔ HƯỚNG thì `a--b` và `b--a` là MỘT.
    func testCANHTRUNGLAP() {
        let directed = GraphQuality.run(DOTGraph.parse("""
            digraph { a [label="A"]; b [label="B"]; a -> b; a -> b; b -> a }
            """))
        XCTAssertEqual(directed.duplicateEdges, 1, "b→a KHÁC a→b trên đồ thị có hướng")

        let undirected = GraphQuality.run(DOTGraph.parse("""
            graph { a [label="A"]; b [label="B"]; a -- b; b -- a }
            """))
        XCTAssertEqual(undirected.duplicateEdges, 1)
    }

    /// Cạnh trỏ tới node CHƯA KHAI.
    ///
    /// DOT tự sinh node khi nó xuất hiện trong một cạnh, nên "chưa khai" = không có câu lệnh
    /// khai riêng. Đó đúng là thứ đặc tả hỏi: một cạnh trỏ tới cái tên không ai định nghĩa.
    func testCANHDangling() {
        let report = GraphQuality.run(DOTGraph.parse("""
            digraph {
                a [label="A"];
                b [label="B"];
                a -> b;
                a -> khong_khai;
            }
            """))
        XCTAssertEqual(report.danglingEdges, 1)
        XCTAssertEqual(report.problems(of: .danglingEdge).first?.line, 4)
        // 100 × (4 đầu cạnh − 1) ÷ 4
        XCTAssertEqual(value(report, .validity) ?? -1, 75, accuracy: 1e-9)
    }

    /// KHÔNG node nào khai riêng thì chiều HỢP LỆ **không chấm được**, không phải 0.
    ///
    /// Mọi node đều "chưa khai" là một câu vô nghĩa, và cho 0 điểm vì nó là chấm sai.
    func testKHONGAIKhaiRiengThiKhongChamHopLe() {
        let report = GraphQuality.run(DOTGraph.parse("digraph { a -> b; b -> c }"))
        XCTAssertNil(value(report, .validity))
        XCTAssertEqual(note(report, .validity)?.contains("khai ngầm"), true)
    }

    /// Thuộc tính bắt buộc thiếu — trên BẤT KỲ tên thuộc tính nào, không chỉ ba cái có nghĩa
    /// riêng với phần vẽ.
    func testTHUOCTINHBatBuocThieu() {
        let report = GraphQuality.run(
            DOTGraph.parse("""
                digraph {
                    a [label="A", nguon="web"];
                    b [label="B"];
                    a -> b [label="gửi", do_tin_cay="cao"];
                    a -> b [label="nhắc"];
                }
                """),
            config: .init(requiredNodeKeys: ["nguon"], requiredEdgeKeys: ["do_tin_cay"]))
        XCTAssertEqual(report.missingNodeKeys, 1)
        XCTAssertEqual(report.missingEdgeKeys, 1)
        // Ô phải có: 1 khoá × 2 node + 1 khoá × 2 cạnh = 4; thiếu 2.
        XCTAssertEqual(value(report, .completeness) ?? -1, 50, accuracy: 1e-9)
    }

    /// Không khai thuộc tính bắt buộc nào thì chiều ĐẦY ĐỦ **không chấm được**.
    func testKHONGKHAIBatBuocThiKhongChamDayDu() {
        let report = GraphQuality.run(DOTGraph.parse("digraph { a [label=\"A\"] }"))
        XCTAssertNil(value(report, .completeness))
        XCTAssertEqual(note(report, .completeness)?.contains("require_node"), true)
    }

    /// Đảo rời: tỷ lệ node trong đảo lớn nhất.
    func testDAORoi() {
        let report = GraphQuality.run(DOTGraph.parse("""
            digraph {
                a [label="A"]; b [label="B"]; c [label="C"]; d [label="D"];
                a -> b;
                c -> d;
            }
            """))
        XCTAssertEqual(report.islands, 2)
        XCTAssertEqual(report.largestIsland, 2)
        // 100 × 2 ÷ 4
        XCTAssertEqual(value(report, .consistency) ?? -1, 50, accuracy: 1e-9)
    }

    /// Nhãn node trùng gần, dùng phép so mờ DÙNG CHUNG.
    func testNHANTRUNGGAN() {
        let report = GraphQuality.run(DOTGraph.parse("""
            digraph {
                n1 [label="Nguyễn Văn A"];
                n2 [label="Nguyen Van A"];
                n3 [label="Trần Thị B"];
                n1 -> n3;
                n2 -> n3;
            }
            """))
        XCTAssertEqual(report.nearLabelGroups.count, 1)
        XCTAssertEqual(Set(report.nearLabelGroups[0]), Set(["Nguyễn Văn A", "Nguyen Van A"]))
        XCTAssertEqual(report.problems(of: .nearLabel).count, 1,
                       "một cụm báo MỘT dòng, không báo mỗi node một dòng")
    }

    /// Vượt trần thì chiều KHÔNG TRÙNG **không chấm được**, và lý do nói cách chấm được.
    func testVUOTTRANMoThiKhongChamKhongTrung() {
        var text = "digraph {\n"
        for index in 0 ..< 10 { text += "  n\(index) [label=\"N\(index)\"];\n" }
        text += "}"
        let report = GraphQuality.run(DOTGraph.parse(text), config: .init(fuzzyLimit: 5))
        XCTAssertNil(value(report, .uniqueness))
        XCTAssertEqual(report.fuzzySkipped, 10)
        XCTAssertEqual(note(report, .uniqueness)?.contains("fuzzy_limit"), true)
    }

    // MARK: - Khung chung

    /// Chiều TƯƠI MỚI luôn `nil` và bị LOẠI khỏi điểm tổng.
    func testTUOIMOIKhongChamDuoc() {
        let report = GraphQuality.run(DOTGraph.parse("digraph { a [label=\"A\"]; a -> b }"))
        XCTAssertNil(value(report, .timeliness))
        XCTAssertTrue(report.score.unscored.contains { $0.dimension == .timeliness })
    }

    /// Mọi chiều chấm được đều mang theo CÔNG THỨC và SỐ LIỆU.
    func testMOICHIEUCoCongThucVaSoLieu() {
        let report = GraphQuality.run(
            DOTGraph.parse("digraph { a [label=\"A\", x=\"1\"]; b [label=\"B\", x=\"2\"]; a -> b }"),
            config: .init(requiredNodeKeys: ["x"]))
        for dimension in report.score.dimensions where dimension.value != nil {
            XCTAssertFalse(dimension.formula.isEmpty, "\(dimension.dimension)")
            XCTAssertFalse(dimension.detail.isEmpty, "\(dimension.dimension)")
        }
    }

    /// Khối Phương pháp NÓI RA ranh giới của chính nó.
    ///
    /// Bản đầu của bài này canh câu "FR-KNW-917 chưa có mã". Khi 917 có mã (28/08/2026) nó đỏ —
    /// đúng việc của nó, và buộc phải viết lại thay vì để một câu chữ nói về thế giới không còn
    /// tồn tại.
    ///
    /// Ranh giới KHÔNG mất đi, chỉ đổi chỗ: `GraphSchema` đọc một tệp YAML RỜI, và báo cáo này
    /// cố ý không tự đi tìm tệp ấy — một báo cáo âm thầm nạp thêm luật ở đâu đó là báo cáo không
    /// tái lập được. Nên vẫn phải nói ra, chỉ là nói điều khác.
    func testPHUONGPHAPNoiRaRanhGioiCuaChinhNo() {
        let report = GraphQuality.run(DOTGraph.parse("digraph { a [label=\"A\"] }"))
        let text = GraphQuality.methodology(report)
        XCTAssertTrue(text.contains("FR-KNW-917"), text)
        XCTAssertTrue(text.contains("THUỘC TÍNH BẮT BUỘC"), text)
        XCTAssertTrue(text.contains("không tự nạp"), "phải nói rõ nó KHÔNG tự đi tìm schema: \(text)")
    }

    /// Lỗi sắp theo DÒNG — bảng lỗi đọc từ trên xuống là đọc theo tệp.
    func testLOISapTheoDong() {
        let report = GraphQuality.run(DOTGraph.parse("""
            digraph {
                a [label="A"];
                b [label="B"];
                coi [label="Mồ côi"];
                a -> b;
                a -> b;
                a -> chua_khai;
            }
            """))
        let lines = report.problems.map(\.line)
        XCTAssertEqual(lines, lines.sorted())
        XCTAssertGreaterThanOrEqual(report.problems.count, 3)
    }

    /// Hai lượt chạy cho kết quả GIỐNG HỆT.
    func testHAILUOTCHAYGiongHet() {
        var text = "digraph {\n"
        for index in 0 ..< 40 {
            text += "  n\(index) [label=\"Tên \(index % 13)\"];\n"
            text += "  n\(index) -> n\((index * 7 + 3) % 40);\n"
        }
        text += "}"
        let graph = DOTGraph.parse(text)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(
            GraphQuality.run(graph, now: now), GraphQuality.run(graph, now: now))
    }
}

// MARK: - Khối ```quality ở chế độ đồ thị

/// FR-KNW-924 — chạy trong block ```quality và CLI quality gate.
final class GraphQualityBlockTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try """
            digraph G {
                a [label="Nguyễn Văn A", nguon="web"];
                b [label="Nguyen Van A", nguon="pdf"];
                c [label="Trần Thị B"];
                coi [label="Mồ côi", nguon="web"];
                a -> b;
                a -> b;
                a -> chua_khai;
            }
            """.write(toFile: folder + "/do-thi.dot", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func render(_ text: String) throws -> ReportRenderer.Rendered {
        try ReportRenderer.render(
            try ReportDocument.parse(text),
            in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
            options: ReportRenderer.Options(basePath: folder))
    }

    func testKHOICOGRAPHThiSangCheDoDoThi() throws {
        let spec = try QualityBlockSpec.parse("""
            graph: do-thi.dot
            require_node: [nguon]
            label_similarity: 0.9
            fuzzy_limit: 100
            """)
        XCTAssertEqual(spec.graph, "do-thi.dot")
        XCTAssertEqual(spec.graphConfig.requiredNodeKeys, ["nguon"])
        XCTAssertEqual(spec.graphConfig.labelSimilarity, 0.9)
        XCTAssertEqual(spec.graphConfig.fuzzyLimit, 100)
    }

    /// Khai CẢ HAI nguồn thì từ chối — một khối chấm MỘT thứ.
    func testKHAICaCorpusLanGraphThiTuChoi() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("corpus: a.jsonl\ngraph: b.dot")) { error in
            XCTAssertTrue((error as? QualityBlockSpec.Failure)?.message.contains("MỘT thứ")
                ?? false)
        }
    }

    /// Khoá của chế độ đồ thị dùng nhầm thì báo lỗi NÓI RA vì sao.
    func testKHOADoThiDungNhamThiBaoRoLyDo() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("rules_file: luat.yaml\nrequire_node: [x]")) { error in
            let message = (error as? QualityBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("chế độ đồ thị"), message)
        }
    }

    func testNGUONGSAIThiBaoLoi() {
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("graph: a.dot\nlabel_similarity: 0.2"))
        XCTAssertThrowsError(try QualityBlockSpec.parse("graph: a.dot\nfuzzy_limit: -1"))
    }

    /// Đường ghép đầy đủ: dựng báo cáo thật.
    func testDUNGBAOCAOThatRaScorecard() throws {
        let result = try render("""
            # Sức khoẻ đồ thị

            ```quality
            graph: do-thi.dot
            require_node: [nguon]
            title: Đồ thị tri thức
            ```
            """)
        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("Đồ thị tri thức"))
        // Bảy phép kiểm phải hiện ra.
        XCTAssertTrue(result.html.contains("node mồ côi"), "thiếu node mồ côi")
        XCTAssertTrue(result.html.contains("cạnh trùng lặp"), "thiếu cạnh trùng")
        XCTAssertTrue(result.html.contains("node chưa khai"), "thiếu cạnh treo")
        XCTAssertTrue(result.html.contains("nhãn node trùng gần"), "thiếu nhãn gần")
        XCTAssertTrue(result.html.contains("thiếu thuộc tính"), "thiếu thuộc tính bắt buộc")
        // Và khối Phương pháp nói ra cái CHƯA kiểm được.
        XCTAssertTrue(result.html.contains("FR-KNW-917"))
        // Chiều Tươi mới bị loại, nói thành chữ.
        XCTAssertTrue(result.html.contains("KHÔNG chấm được"))
    }

    /// `fail_under` cảnh báo — đây là vế "CLI quality gate" của đặc tả.
    func testFAILUNDERCanhBao() throws {
        let result = try render("""
            ```quality
            graph: do-thi.dot
            fail_under: 99
            ```
            """)
        XCTAssertFalse(result.qualityAlerts.isEmpty)
        XCTAssertTrue(result.qualityAlerts[0].message.contains("DƯỚI ngưỡng"))
    }

    /// Tệp thiếu thì khối HỎNG có chỗ nhảy, không làm hỏng cả báo cáo.
    func testTEPTHIEUThiKhoiHong() throws {
        let result = try render("""
            ```quality
            graph: khong-co.dot
            ```

            Văn xuôi phía sau vẫn phải còn.
            """)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.html.contains("Văn xuôi phía sau vẫn phải còn"))
    }
}
