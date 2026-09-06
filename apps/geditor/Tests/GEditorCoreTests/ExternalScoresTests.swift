import XCTest
@testable import GEditorCore

/// FR-KNW-921 — nhập & so sánh điểm retrieval ngoài.
final class ExternalScoresTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    @discardableResult
    private func write(_ text: String, name: String = "diem.jsonl") throws -> String {
        let path = folder + "/" + name
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Đọc tệp

    /// Ba dòng, hai câu hỏi; xếp hạng theo điểm GIẢM DẦN.
    func testDOCVaXepTheoDiemGiamDan() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"hợp đồng","chunk_id":"c2","score":0.31}
            {"query":"hợp đồng","chunk_id":"c1","score":0.92}
            {"query":"đà lạt","chunk_id":"c4","score":0.77}
            """))
        XCTAssertEqual(file.rowCount, 3)
        XCTAssertEqual(file.questionCount, 2)
        XCTAssertEqual(file.order, .descending)
        XCTAssertEqual(file.scoreField, "score")
        XCTAssertEqual(file.ranking["hợp đồng"]?.map(\.id), ["c1", "c2"])
        XCTAssertEqual(file.ranking["đà lạt"]?.map(\.id), ["c4"])
    }

    /// **Trường `distance` thì NHỎ HƠN xếp trên** — đoán sai chiều là lật ngược cả bảng.
    func testTRUONGDistanceThiNhoHonXepTren() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"xa","distance":0.9}
            {"query":"q","chunk_id":"gan","distance":0.1}
            """))
        XCTAssertEqual(file.order, .ascending)
        XCTAssertEqual(file.scoreField, "distance")
        XCTAssertEqual(file.ranking["q"]?.map(\.id), ["gan", "xa"])
    }

    /// Ép chiều bằng tay thì thắng tên trường.
    func testEPCHIEUThangTenTruong() throws {
        let path = try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            {"query":"q","chunk_id":"b","score":0.1}
            """)
        let file = try ExternalScores.load(path: path, order: .ascending)
        XCTAssertEqual(file.ranking["q"]?.map(\.id), ["b", "a"])
    }

    /// **Một tệp một thang điểm** — đổi trường giữa chừng thì DỪNG, không trộn.
    func testDOITHANGDiemGiuaChungThiTuChoi() throws {
        let path = try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            {"query":"q","chunk_id":"b","distance":0.1}
            """)
        XCTAssertThrowsError(try ExternalScores.load(path: path)) { error in
            let message = (error as? ExternalScores.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("dòng 2"), message)
            XCTAssertTrue(message.contains("một thang điểm"), message)
        }
    }

    func testDONGHongThiNoiRaSoDong() throws {
        let path = try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            khong-phai-json
            """)
        XCTAssertThrowsError(try ExternalScores.load(path: path)) { error in
            XCTAssertTrue(((error as? ExternalScores.Failure)?.message ?? "").contains("dòng 2"))
        }
    }

    /// Dòng thiếu trường thì bỏ qua và ĐẾM, không im lặng.
    func testDONGTHIEUTruongThiDemChuKhongIm() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            {"query":"q","score":0.5}
            {"chunk_id":"b","score":0.5}
            """))
        XCTAssertEqual(file.rowCount, 1)
        XCTAssertTrue(file.warnings.contains { $0.contains("2 dòng thiếu trường") },
                      "\(file.warnings)")
    }

    /// Dòng trùng (cùng câu, cùng id): giữ lần đầu và đếm — cộng dồn hay lấy max là quyết định
    /// của người làm pipeline, không phải của công cụ đọc.
    func testDONGTRUNGGiuLanDauVaDem() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            {"query":"q","chunk_id":"a","score":0.1}
            """))
        XCTAssertEqual(file.ranking["q"]?.count, 1)
        XCTAssertEqual(file.ranking["q"]?.first?.score, 0.9)
        XCTAssertTrue(file.warnings.contains { $0.contains("1 dòng trùng") }, "\(file.warnings)")
    }

    /// Điểm hoà nhau thì phá hoà theo id — thứ tự trong tệp KHÔNG được quyết định kết quả.
    func testDIEMHoaThiPhaTheoID() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"z","score":0.5}
            {"query":"q","chunk_id":"a","score":0.5}
            """))
        XCTAssertEqual(file.ranking["q"]?.map(\.id), ["a", "z"])
    }

    func testTEPRongThiNoiRoDinhDang() throws {
        let path = try write("\n\n")
        XCTAssertThrowsError(try ExternalScores.load(path: path)) { error in
            XCTAssertTrue(((error as? ExternalScores.Failure)?.message ?? "").contains("JSONL"))
        }
    }

    // MARK: - Chuẩn hoá câu hỏi

    /// Gọn khoảng trắng và thường hoá, nhưng **GIỮ DẤU**.
    func testCHUANHOAGiuDau() {
        XCTAssertEqual(ExternalScores.normalize("  Hợp   đồng \n"), "hợp đồng")
        XCTAssertNotEqual(
            ExternalScores.normalize("Nguyễn"), ExternalScores.normalize("Nguyen"),
            "bỏ dấu ở đây là gộp hai câu hỏi khác nhau")
    }

    // MARK: - Ghép với golden set

    private let golden = [
        RetrievalEval.Query(id: "q1", question: "hợp đồng", relevant: ["c1"]),
        RetrievalEval.Query(id: "q2", question: "đà lạt", relevant: ["c4"]),
        RetrievalEval.Query(id: "q3", question: "biên bản bàn giao", relevant: ["c3"]),
    ]

    /// Ghép theo CÂU HỎI, không theo qid — và câu hụt được kể tên.
    func testGHEPTheoCauHoiVaKeRaCauHut() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"Hợp  đồng","chunk_id":"c1","score":0.9}
            {"query":"đà lạt","chunk_id":"c4","score":0.8}
            {"query":"câu chỉ có ở tệp ngoài","chunk_id":"c2","score":0.7}
            """))
        let join = ExternalScores.join(file, golden: golden)
        XCTAssertEqual(join.matched.map(\.id), ["q1", "q2"], "khác hoa/khoảng trắng vẫn ghép")
        XCTAssertEqual(join.unmatched.map(\.id), ["q3"])
        XCTAssertEqual(join.extraQuestions, ["câu chỉ có ở tệp ngoài"])
    }

    /// **Ghép hụt vì lệch một ký tự thì phải có GỢI Ý**, không chỉ báo "0 câu ghép được".
    func testGHEPHutThiGoiYCauGanGiong() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"biên bản bàn giao?","chunk_id":"c3","score":0.9}
            """))
        let join = ExternalScores.join(file, golden: golden)
        XCTAssertTrue(join.matched.isEmpty)
        XCTAssertEqual(join.suggestions.count, 1)
        XCTAssertTrue(join.suggestions[0].contains("biên bản bàn giao?"), join.suggestions[0])
    }

    /// Câu khác hẳn thì KHÔNG gợi ý bừa.
    func testCAUKHACHanThiKhongGoiYBua() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"thời tiết mùa hè ở nơi khác","chunk_id":"c9","score":0.9}
            """))
        let join = ExternalScores.join(file, golden: golden)
        XCTAssertTrue(join.suggestions.isEmpty, "\(join.suggestions)")
    }

    // MARK: - Bộ truy hồi và độ phủ

    private let map = ["c1": [0], "c3": [2], "c4": [3, 7]]

    func testTRUYHOITraSoHieuTaiLieuTheoThuHang() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"c3","score":0.2}
            {"query":"q","chunk_id":"c4","score":0.9}
            {"query":"q","chunk_id":"c1","score":0.5}
            """))
        let retrieve = ExternalScores.retriever(file, identifierMap: map)
        // c4 (0,9) → tài liệu 3 và 7 · c1 (0,5) → 0 · c3 (0,2) → 2
        XCTAssertEqual(retrieve("q", 10), [3, 7, 0, 2])
        XCTAssertEqual(retrieve("q", 2), [3, 7], "k phải cắt đúng chỗ")
        XCTAssertEqual(retrieve("câu không có", 10), [])
    }

    /// Id corpus không có thì bị BỎ QUA khi truy hồi — và được ĐẾM riêng.
    func testIDLACBiBoQuaVaDuocDem() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"lac-1","score":0.9}
            {"query":"q","chunk_id":"c1","score":0.5}
            {"query":"q","chunk_id":"lac-2","score":0.4}
            """))
        XCTAssertEqual(ExternalScores.retriever(file, identifierMap: map)("q", 10), [0])
        let coverage = ExternalScores.coverage(file, identifierMap: map)
        XCTAssertEqual(coverage.unknownCount, 2)
        XCTAssertEqual(coverage.totalCount, 3)
        XCTAssertEqual(coverage.ratio, 2.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(coverage.samples, ["lac-1", "lac-2"])
    }

    // MARK: - Đi qua bộ chấm điểm của 919

    /// Hai hệ đi qua ĐÚNG MỘT bộ chấm điểm, nên hai con số so được với nhau.
    func testHAIHEDiQuaCungBoChamDiem() throws {
        let corpus = folder + "/chunks.jsonl"
        try """
            {"id":"c1","text":"hợp đồng mua bán nhà đất"}
            {"id":"c2","text":"hợp đồng lao động"}
            {"id":"c3","text":"biên bản bàn giao nhà"}
            """.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let identifiers = try index.identifierMap()
        let queries = [RetrievalEval.Query(id: "q1", question: "hợp đồng", relevant: ["c1"])]

        // Hệ ngoài xếp c1 đầu → recall@2 = 1.
        let good = try ExternalScores.load(path: try write("""
            {"query":"hợp đồng","chunk_id":"c1","score":0.9}
            {"query":"hợp đồng","chunk_id":"c3","score":0.1}
            """, name: "tot.jsonl"))
        let goodReport = RetrievalEval.run(
            golden: queries, k: 2, identifierMap: identifiers,
            configuration: good.methodology,
            retrieve: ExternalScores.retriever(good, identifierMap: identifiers))
        XCTAssertEqual(goodReport.summary.recall, 1, accuracy: 1e-12)
        XCTAssertEqual(goodReport.summary.mrr, 1, accuracy: 1e-12)

        // Hệ ngoài xếp c1 thứ hai → recall vẫn 1 nhưng MRR = 1/2.
        let weak = try ExternalScores.load(path: try write("""
            {"query":"hợp đồng","chunk_id":"c3","score":0.9}
            {"query":"hợp đồng","chunk_id":"c1","score":0.1}
            """, name: "yeu.jsonl"))
        let weakReport = RetrievalEval.run(
            golden: queries, k: 2, identifierMap: identifiers,
            configuration: weak.methodology,
            retrieve: ExternalScores.retriever(weak, identifierMap: identifiers))
        XCTAssertEqual(weakReport.summary.recall, 1, accuracy: 1e-12)
        XCTAssertEqual(weakReport.summary.mrr, 0.5, accuracy: 1e-12)

        let comparison = RetrievalEval.compare(goodReport, weakReport)
        XCTAssertEqual(comparison.rows.count, 1)
        XCTAssertEqual(comparison.mrrDelta, -0.5, accuracy: 1e-12)
    }

    /// Khối Phương pháp nói ra ranh giới ADR-11.
    func testPHUONGPHAPNoiRaKhongTinhVector() throws {
        let file = try ExternalScores.load(path: try write("""
            {"query":"q","chunk_id":"a","score":0.9}
            """))
        XCTAssertTrue(file.methodology.contains("KHÔNG tính vector"), file.methodology)
        XCTAssertTrue(file.methodology.contains("score"), file.methodology)
        XCTAssertTrue(file.methodology.contains("lớn hơn xếp trên"), file.methodology)
    }
}
