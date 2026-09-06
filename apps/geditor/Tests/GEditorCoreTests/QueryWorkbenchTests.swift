import XCTest
@testable import GEditorCore

/// FR-QRY-001 Query Workbench — tham số, lịch sử, câu đã lưu, nhiều nguồn.
final class QueryWorkbenchTests: XCTestCase {

    // MARK: - Tham số `:tên`

    func testTimDungTenTheoThuTuXuatHien() {
        let names = QueryParameters.names(
            in: "SELECT * FROM t WHERE thang = :thang AND tinh = :tinh AND x > :thang")
        // Theo thứ tự ĐỌC, không theo bảng chữ cái, và không lặp.
        XCTAssertEqual(names, ["thang", "tinh"])
    }

    func testTOANTUEPKIEUkhongPhaiThamSo() {
        // `::` của DuckDB/Postgres. Bắt nhầm nó là biến một câu chạy được thành một hộp thoại
        // hỏi giá trị cho `:INTEGER`.
        XCTAssertEqual(QueryParameters.names(in: "SELECT doanh_thu::INTEGER FROM t"), [])
        XCTAssertEqual(
            QueryParameters.names(in: "SELECT a::INT, b FROM t WHERE c = :thang"), ["thang"])
    }

    func testDAUHAICHAMTRONGCHUOIkhongPhaiThamSo() {
        XCTAssertEqual(QueryParameters.names(in: "SELECT * FROM t WHERE ghi_chu = 'gio: 10'"), [])
        XCTAssertEqual(QueryParameters.names(in: "SELECT \"cot: la\" FROM t"), [])
    }

    func testThayGiaTriCoBOCthanhLiteral() {
        let sql = QueryParameters.substitute(
            "SELECT * FROM t WHERE ten = :ten", values: ["ten": "O'Brien"])
        // Dấu nháy phải được nhân đôi. Người gõ `O'Brien` vào ô nhập không tấn công ai, nhưng
        // hậu quả thì giống hệt.
        XCTAssertEqual(sql, "SELECT * FROM t WHERE ten = 'O''Brien'")
    }

    func testSOdiQuaNGUYENDANG() {
        // Bọc một số thành chuỗi thì `:nam > 2020` so chữ với số và DuckDB báo lỗi đổi kiểu.
        XCTAssertEqual(
            QueryParameters.substitute("SELECT * FROM t WHERE nam > :nam", values: ["nam": "2020"]),
            "SELECT * FROM t WHERE nam > 2020")
    }

    func testThamSoKHONGCOgiaTriThanhNULLvaBaoLaThieu() {
        let sql = "SELECT * FROM t WHERE a = :a AND b = :b"
        XCTAssertEqual(QueryParameters.missing(in: sql, values: ["a": "1"]), ["b"])
        XCTAssertEqual(
            QueryParameters.substitute(sql, values: ["a": "1"]),
            "SELECT * FROM t WHERE a = 1 AND b = NULL")
    }

    func testThayNhieuLanCungMotThamSo() {
        XCTAssertEqual(
            QueryParameters.substitute(
                "SELECT :x, :x FROM t WHERE y = :x", values: ["x": "abc"]),
            "SELECT 'abc', 'abc' FROM t WHERE y = 'abc'")
    }

    // MARK: - Lịch sử và câu đã lưu

    func testLichSuMOINHATdungDau() {
        var library = QueryLibrary()
        library.record("SELECT 1", at: "2026-08-26T10:00:00Z")
        library.record("SELECT 2", at: "2026-08-26T10:01:00Z")
        XCTAssertEqual(library.history.map(\.sql), ["SELECT 2", "SELECT 1"])
    }

    func testChayLaiCauCUkhongThemDongTRUNG() {
        // Bấm Chạy ba lần để xem lại kết quả là chuyện thường; ba dòng giống hệt nhau chỉ đẩy
        // những câu khác ra khỏi trần.
        var library = QueryLibrary()
        library.record("SELECT 1", at: "a")
        library.record("SELECT 2", at: "b")
        library.record("SELECT 1", at: "c")
        XCTAssertEqual(library.history.map(\.sql), ["SELECT 1", "SELECT 2"])
        XCTAssertEqual(library.history[0].at, "c", "phải cập nhật thời điểm")
    }

    func testLichSuCoTRAN() {
        var library = QueryLibrary()
        for index in 0 ... QueryLibrary.historyLimit + 10 {
            library.record("SELECT \(index)", at: "t\(index)")
        }
        XCTAssertEqual(library.history.count, QueryLibrary.historyLimit)
        XCTAssertEqual(library.history.first?.sql, "SELECT \(QueryLibrary.historyLimit + 10)")
    }

    func testCauRONGkhongVaoLichSu() {
        var library = QueryLibrary()
        library.record("   \n  ", at: "a")
        XCTAssertTrue(library.history.isEmpty)
    }

    func testLuuTheoTENvaGhiDeKhiTrungTen() {
        var library = QueryLibrary()
        library.save(name: "Báo cáo tháng", sql: "SELECT 1")
        library.save(name: "Báo cáo tháng", sql: "SELECT 2")
        XCTAssertEqual(library.saved.count, 1)
        XCTAssertEqual(library.sql(named: "Báo cáo tháng"), "SELECT 2")
    }

    func testGhiRoiDocLaiNguyenVen() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-qry-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var library = QueryLibrary()
        library.record("SELECT * FROM t WHERE tinh = 'Huế'", at: "2026-08-26T10:00:00Z")
        library.save(name: "Doanh thu Huế", sql: "SELECT SUM(doanh_thu) FROM t")
        try library.save(to: url)
        XCTAssertEqual(try QueryLibrary.load(from: url), library)
        // Đọc được bằng mắt (ADR-09), và giữ nguyên chữ tiếng Việt.
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("Huế"), "chữ tiếng Việt bị mã hoá mất — không sửa tay được")
        XCTAssertTrue(text.contains("\n"))
    }

    func testTuChoiTepCuaBANMOIHON() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-qry-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{\"schemaVersion\":99,\"history\":[],\"saved\":[]}".utf8).write(to: url)
        XCTAssertThrowsError(try QueryLibrary.load(from: url))
        // Và KHÔNG ghi đè.
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("99"))
    }

    func testTepChuaCoLaThuVienRONGchuKhongPhaiLOI() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-qry-chua-co-\(UUID().uuidString).json")
        XCTAssertEqual(try QueryLibrary.load(from: url), QueryLibrary())
    }

    // MARK: - Nhiều nguồn

    func testTenBangKhongHopLeBiTUCHOI() {
        XCTAssertTrue(CSVQueryEngine.isValidTableName("khach_hang"))
        XCTAssertTrue(CSVQueryEngine.isValidTableName("_tam"))
        XCTAssertFalse(CSVQueryEngine.isValidTableName("2020"))
        XCTAssertFalse(CSVQueryEngine.isValidTableName("t"), "trùng bảng của tài liệu đang mở")
        // Tên bảng suy từ TÊN FILE của người dùng, tức từ chuỗi ta không kiểm soát.
        XCTAssertFalse(CSVQueryEngine.isValidTableName("a\"; DROP VIEW t; --"))
        XCTAssertFalse(CSVQueryEngine.isValidTableName("có dấu"))
    }

    func testJOINgiuaTaiLieuDangMoVaNguonPHU() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let phu = NSTemporaryDirectory() + "/geditor-vung-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: phu) }
        try "tinh,vung\nHà Nội,Bắc\nHuế,Trung\nĐà Nẵng,Trung\n"
            .write(toFile: phu, atomically: true, encoding: .utf8)

        let chinh = "ma,tinh\nA,Hà Nội\nB,Huế\nC,Đà Nẵng\nD,Cần Thơ\n"
        let buffer = TextBuffer(original: MemoryByteSource(Array(chinh.utf8)))
        let result = try CSVQueryEngine.run("""
            SELECT v.vung, COUNT(*) FROM t JOIN vung_mien v ON t.tinh = v.tinh
            GROUP BY v.vung ORDER BY v.vung
            """, in: buffer, dialect: .comma, extraSources: ["vung_mien": phu])
        XCTAssertEqual(result.rows, [["Bắc", "1"], ["Trung", "2"]])
    }

    func testNguonJSONLdocDuoc() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        // FR-QRY-001 đòi console chạy trên "CSV, TSV, JSONL, Parquet". JSONL không đọc bằng
        // `read_csv` được — mỗi dòng là một đối tượng, không phải một hàng phân tách bằng dấu.
        let path = NSTemporaryDirectory() + "/geditor-jsonl-\(UUID().uuidString).jsonl"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try """
            {"ten": "An", "tuoi": 30}
            {"ten": "Bình", "tuoi": 41}

            """.write(toFile: path, atomically: true, encoding: .utf8)

        let buffer = TextBuffer(original: MemoryByteSource(Array("a\n1\n".utf8)))
        let result = try CSVQueryEngine.run(
            "SELECT ten FROM nguoi ORDER BY tuoi", in: buffer, dialect: .comma,
            extraSources: ["nguoi": path])
        XCTAssertEqual(result.rows, [["An"], ["Bình"]])
    }

    func testChonHamDocTheoDUOIFILE() {
        // Chọn theo đuôi chứ không dò nội dung: dò nội dung nghĩa là đọc file trước khi biết
        // đọc nó bằng gì, và đoán sai trên một file 2 GB thì tốn cả một lượt quét để phát hiện.
        XCTAssertTrue(CSVQueryEngine.readerCall(for: "/a/b.parquet", escaped: "/a/b.parquet")
            .hasPrefix("read_parquet("))
        XCTAssertTrue(CSVQueryEngine.readerCall(for: "/a/b.jsonl", escaped: "/a/b.jsonl")
            .hasPrefix("read_json_auto("))
        XCTAssertTrue(CSVQueryEngine.readerCall(for: "/a/b.tsv", escaped: "/a/b.tsv")
            .contains("delim"))
        // Đuôi lạ rơi về read_csv — DuckDB tự nói ra nếu nó không đọc nổi.
        XCTAssertTrue(CSVQueryEngine.readerCall(for: "/a/b.dat", escaped: "/a/b.dat")
            .hasPrefix("read_csv("))
    }

    func testNguonPHUhongThiNoiTENnguonAy() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let buffer = TextBuffer(original: MemoryByteSource(Array("a\n1\n".utf8)))
        XCTAssertThrowsError(
            try CSVQueryEngine.run("SELECT * FROM t", in: buffer, dialect: .comma,
                                   extraSources: ["thieu": "/khong/co/that.csv"])
        ) { error in
            guard case CSVQueryEngine.Failure.query(let message) = error else {
                return XCTFail("mong .query, nhận \(error)")
            }
            XCTAssertTrue(message.contains("thieu"), message)
        }
    }
}
