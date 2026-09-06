import XCTest
@testable import GEditorCore

/// Truy vấn SQL trên corpus và đồ thị — FR-KNW-907.
final class CorpusSQLTests: XCTestCase {

    private var thuMuc = ""

    override func setUpWithError() throws {
        try XCTSkipUnless(DuckDB.isAvailable, "máy này chưa có libduckdb — git lfs pull")
        thuMuc = NSTemporaryDirectory() + "geditor-corpus-sql-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: thuMuc, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !thuMuc.isEmpty { try? FileManager.default.removeItem(atPath: thuMuc) }
    }

    private func ghi(_ ten: String, _ noiDung: String) throws -> String {
        let duong = thuMuc + "/" + ten
        try noiDung.write(toFile: duong, atomically: true, encoding: .utf8)
        return duong
    }

    /// Corpus chunk: `a1` trùng khoá, `source` thiếu ở một bản ghi và RỖNG ở một bản khác.
    private func corpus() throws -> String {
        try ghi("corpus.jsonl", """
        {"id":"a1","text":"Công ty An Phát","source":"web"}
        {"id":"a2","text":"Xưởng gỗ Trường Sơn","source":""}
        {"id":"a1","text":"Công ty An Phát","source":null}

        """)
    }

    /// Đồ thị nhỏ: n4 không nối với gì cả.
    private func doThi() throws -> (nodes: String, edges: String) {
        let n = try ghi("nodes.csv", "id\nn1\nn2\nn3\nn4\n")
        let e = try ghi("edges.csv", "source,target\nn1,n2\nn2,n3\nn1,n3\n")
        return (n, e)
    }

    // MARK: - Đọc thẳng JSONL

    func testDocThangJSONLKhongCanTaiLieuNaoDangMo() throws {
        let result = try CorpusSQL.run(
            "SELECT count(*) AS n FROM \"c\"", sources: ["c": try corpus()])
        XCTAssertEqual(result.rows.first?.first, "3")
    }

    func testDocThangTSVvaCSVcungMotDuongVao() throws {
        let tsv = try ghi("bang.tsv", "a\tb\n1\t2\n")
        let result = try CorpusSQL.run("SELECT b FROM \"x\"", sources: ["x": tsv])
        XCTAssertEqual(result.rows.first?.first, "2")
    }

    // MARK: - Bản ghi trùng

    func testBanGhiTrungKemSoLan() throws {
        let result = try CorpusSQL.run(
            CorpusSQL.duplicateRecordsSQL(table: "c", key: "id"),
            sources: ["c": try corpus()])
        XCTAssertEqual(result.rows.count, 1, "chỉ «a1» trùng")
        XCTAssertEqual(result.rows.first?.first, "a1")
        XCTAssertEqual(result.rows.first?.last, "2")
    }

    // MARK: - Phủ metadata

    /// Vế quan trọng nhất của câu này: chuỗi RỖNG KHÔNG tính là có giá trị. Corpus xuất từ công
    /// cụ khác thường ghi trường thiếu thành `""` chứ không `NULL`, và một cột toàn `""` mà báo
    /// "phủ 100%" là câu trả lời sai cho đúng câu hỏi người ta đang hỏi.
    func testPhuMetadataKhongTinhChuoiRONGlaCoGiaTri() throws {
        let duong = try corpus()
        let cot = try CorpusSQL.columns(of: "c", path: duong)
        XCTAssertEqual(Set(cot), ["id", "text", "source"])

        let result = try CorpusSQL.run(
            CorpusSQL.metadataCoverageSQL(table: "c", columns: cot),
            sources: ["c": duong])

        var phu: [String: String] = [:]
        for hang in result.rows {
            if let ten = hang.first ?? nil, let pt = hang.last ?? nil { phu[ten] = pt }
        }
        XCTAssertEqual(phu["id"], "100.0")
        XCTAssertEqual(phu["text"], "100.0")
        // 3 bản ghi: "web" có giá trị, "" và NULL đều không → 1/3.
        XCTAssertEqual(phu["source"], "33.3", "chuỗi rỗng hoặc NULL đều KHÔNG phải giá trị")
    }

    func testPhuMetadataKhongCotNaoThiKhongNemLoi() throws {
        let result = try CorpusSQL.run(
            CorpusSQL.metadataCoverageSQL(table: "c", columns: []),
            sources: ["c": try corpus()])
        XCTAssertTrue(result.rows.isEmpty)
    }

    // MARK: - Đồ thị

    /// Bậc đếm CẢ cạnh vào lẫn cạnh ra. n1 có 2, n2 có 2, n3 có 2 → ba node bậc 2.
    func testPhanBoBacDemCaHaiChieu() throws {
        let (_, e) = try doThi()
        let result = try CorpusSQL.run(
            CorpusSQL.degreeDistributionSQL(edges: "e"), sources: ["e": e])
        XCTAssertEqual(result.rows.count, 1, "mọi node trong cạnh đều bậc 2")
        XCTAssertEqual(result.rows.first?.first, "2")
        XCTAssertEqual(result.rows.first?.last, "3")
    }

    /// Đối chứng cho ghi chú "đếm một phía là sai": nếu chỉ đếm cột nguồn thì n3 (chỉ đứng ở
    /// phía đích) biến mất khỏi phân bố — đúng loại sai cho ra một bảng trông hợp lý.
    func testDemMotPhiaChoKetQuaKHACvaDoLaLyDoDemCaHai() throws {
        let (_, e) = try doThi()
        let motPhia = try CorpusSQL.run("""
            SELECT count(DISTINCT "source") AS n FROM "e"
            """, sources: ["e": e])
        XCTAssertEqual(motPhia.rows.first?.first, "2", "chỉ n1 và n2 từng đứng ở phía nguồn")

        let caHai = try CorpusSQL.run(
            CorpusSQL.degreeDistributionSQL(edges: "e"), sources: ["e": e])
        let tongNode = caHai.rows.compactMap { Int($0.last.flatMap { $0 } ?? "") }.reduce(0, +)
        XCTAssertEqual(tongNode, 3, "đếm cả hai chiều thấy đủ ba node")
    }

    func testNodeMoCoi() throws {
        let (n, e) = try doThi()
        let result = try CorpusSQL.run(
            CorpusSQL.orphanNodesSQL(nodes: "n", edges: "e"),
            sources: ["n": n, "e": e])
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows.first?.first, "n4")
    }

    // MARK: - Hàng rào chỉ-đọc (NFR-QRY-03)

    /// Đây là một ĐƯỜNG VÀO KHÁC, nên hàng rào phải đứng chắn ở đây chứ không "tin rằng
    /// `CSVQueryEngine` đã kiểm". Một hàng rào chỉ giữ được những lối nó thật sự đứng chắn.
    func testCauGHIbiTUCHOI() throws {
        let duong = try corpus()
        XCTAssertThrowsError(
            try CorpusSQL.run("CREATE TABLE hong AS SELECT 1", sources: ["c": duong])
        ) { error in
            XCTAssertEqual(error as? CorpusSQL.Failure, .notReadOnly)
        }
    }

    func testCOPYraFILEbiTUCHOIvaKHONGtaoFileNao() throws {
        let dich = thuMuc + "/khong-duoc-tao.csv"
        _ = try? CorpusSQL.run(
            "COPY (SELECT 1) TO '\(dich)'", sources: ["c": try corpus()])
        XCTAssertFalse(FileManager.default.fileExists(atPath: dich),
                       "COPY đi lọt thì hàng rào chỉ-đọc là hàng rào trên giấy")
    }

    func testNhieuCauLENHbiTUCHOI() throws {
        XCTAssertThrowsError(
            try CorpusSQL.run("SELECT 1; SELECT 2", sources: ["c": try corpus()])
        )
    }

    func testTenNguonKhongHopLeBiTUCHOI() throws {
        XCTAssertThrowsError(
            try CorpusSQL.run("SELECT 1", sources: ["x\"; DROP": try corpus()])
        )
    }
}
