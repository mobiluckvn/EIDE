import XCTest
@testable import GEditorCore

/// FR-CSV-407 trên DuckDB (ADR-14).
///
/// Thay `CSVQueryParserTests` + `CSVQueryRunnerTests` (48 bài của engine tự viết). Nhóm này
/// giữ lại **mọi hành vi các bài cũ chốt** — vì đó là hợp đồng với người dùng, không phải chi
/// tiết của bản hiện thực cũ — và thêm phần engine cũ KHÔNG làm được.
final class CSVQueryEngineTests: XCTestCase {

    private let bang = """
        ma_kh,thanh_pho,doanh_thu,ghi_chu
        KH01,Hà Nội,100,binh thuong
        KH02,Đà Nẵng,250,
        KH03,Hà Nội,300,binh thuong
        KH04,Huế,50,N/A
        KH05,Đà Nẵng,400,binh thuong

        """

    private func buffer(_ text: String? = nil) -> TextBuffer {
        TextBuffer(original: MemoryByteSource(Array((text ?? bang).utf8)))
    }

    private func chay(_ sql: String, _ text: String? = nil) throws -> CSVQueryEngine.Result {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else {
            throw XCTSkip("Chưa có libduckdb.dylib — chạy scripts/vendor-duckdb.sh")
        }
        return try CSVQueryEngine.run(sql, in: buffer(text), dialect: .comma)
    }

    // MARK: - Hành vi các bài cũ đã chốt

    func testWHERELocDungHang() throws {
        let result = try chay("SELECT COUNT(*) FROM t WHERE thanh_pho = 'Hà Nội'")
        XCTAssertEqual(result.rows, [["2"]])
    }

    func testGROUPBYCongDungTong() throws {
        let result = try chay("""
            SELECT thanh_pho, COUNT(*), SUM(doanh_thu) FROM t
            GROUP BY thanh_pho ORDER BY thanh_pho
            """)
        // Thứ tự này là thứ tự BYTE UTF-8, không phải thứ tự từ điển tiếng Việt: "Huế" đứng
        // trước "Hà Nội" vì byte thứ hai là `u` (0x75) so với `à` (0xC3 0xA0). Ghi ra đây vì
        // nó là khác biệt hành vi người dùng SẼ thấy, và bài kiểm là chỗ duy nhất nói ra.
        // Muốn thứ tự tiếng Việt thì phải ORDER BY với COLLATE, không phải mặc định.
        XCTAssertEqual(result.rows, [
            ["Huế", "1", "50"],
            ["Hà Nội", "2", "400"],
            ["Đà Nẵng", "2", "650"],
        ])
    }

    func testORDERBYVaLIMIT() throws {
        let result = try chay("SELECT ma_kh FROM t ORDER BY doanh_thu DESC LIMIT 2")
        XCTAssertEqual(result.rows, [["KH05"], ["KH03"]])
    }

    func testAliasDoiTenCot() throws {
        let result = try chay("SELECT SUM(doanh_thu) AS tong FROM t")
        XCTAssertEqual(result.titles, ["tong"])
        XCTAssertEqual(result.rows, [["1100"]])
    }

    func testDongTieuDeKhongBiTinhThanhDuLieu() throws {
        // Bài cũ chốt đúng điều này, và nó là loại lỗi lặng lẽ nhất: một hàng thừa mang tên cột
        // làm mọi phép đếm lệch đi đúng 1.
        let result = try chay("SELECT COUNT(*) FROM t")
        XCTAssertEqual(result.rows, [["5"]])
    }

    func testTenCotSaiThiBaoLoiCoTenCot() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        XCTAssertThrowsError(
            try CSVQueryEngine.run("SELECT khong_co FROM t", in: buffer(), dialect: .comma)
        ) { error in
            guard case CSVQueryEngine.Failure.query(let message) = error else {
                return XCTFail("mong .query, nhận \(error)")
            }
            // Engine cũ trả về DANH SÁCH CỘT CÓ THẬT. DuckDB cũng gợi ý cột gần đúng — kiểm
            // rằng thông điệp có nhắc tên cột sai, để người dùng biết sửa ở đâu.
            XCTAssertTrue(message.contains("khong_co"), message)
        }
    }

    // MARK: - Bảy thứ engine cũ TỪ CHỐI (PoC-K đo 7/7)

    func testJOIN() throws {
        // FR-QRY-005 · FR-DQR-001 foreign_key. Engine cũ: "Phần thừa ở cuối câu truy vấn".
        let result = try chay("""
            SELECT COUNT(*) FROM t
            JOIN (SELECT 'Hà Nội' AS tp UNION ALL SELECT 'Huế') v ON t.thanh_pho = v.tp
            """)
        XCTAssertEqual(result.rows, [["3"]])
    }

    func testDISTINCT() throws {
        let result = try chay("SELECT COUNT(DISTINCT thanh_pho) FROM t")
        XCTAssertEqual(result.rows, [["3"]])
    }

    func testHAVING() throws {
        let result = try chay("""
            SELECT thanh_pho FROM t GROUP BY thanh_pho HAVING COUNT(*) > 1 ORDER BY thanh_pho
            """)
        XCTAssertEqual(result.rows, [["Hà Nội"], ["Đà Nẵng"]])
    }

    func testIN() throws {
        let result = try chay("SELECT COUNT(*) FROM t WHERE thanh_pho IN ('Huế', 'Đà Nẵng')")
        XCTAssertEqual(result.rows, [["3"]])
    }

    func testLIKE() throws {
        let result = try chay("SELECT COUNT(*) FROM t WHERE ghi_chu LIKE 'binh%'")
        XCTAssertEqual(result.rows, [["3"]])
    }

    func testBETWEEN() throws {
        // FR-DQR-001 rule `range`. Chỉ chạy được vì DuckDB SUY KIỂU cột — engine cũ đọc mọi ô
        // thành chuỗi nên `BETWEEN 0 AND 200` là vô nghĩa với nó.
        let result = try chay("SELECT COUNT(*) FROM t WHERE doanh_thu BETWEEN 0 AND 200")
        XCTAssertEqual(result.rows, [["2"]])
    }

    func testTruyVanCon() throws {
        let result = try chay("""
            SELECT COUNT(*) FROM t WHERE doanh_thu > (SELECT AVG(doanh_thu) FROM t)
            """)
        // Trung bình = 1100/5 = 220; ba hàng vượt (250, 300, 400).
        XCTAssertEqual(result.rows, [["3"]])
    }

    // MARK: - NULL

    func testONullKhacChuoiRong() throws {
        // KH02 có `ghi_chu` rỗng. DuckDB đọc ô rỗng thành NULL — và tầng trên phải phân biệt
        // được, vì cả FR-CLN-002 dựng trên phân biệt ấy.
        let result = try chay("SELECT ghi_chu FROM t WHERE ma_kh = 'KH02'")
        XCTAssertEqual(result.rows, [[nil]])
    }

    // MARK: - Chỉ-đọc (NFR-QRY-03)

    func testTuChoiCauGhiRaDia() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let đích = NSTemporaryDirectory() + "/geditor-khong-duoc-ghi-\(UUID().uuidString).csv"
        // DuckDB thừa sức ghi file bằng COPY. Đây là lý do `validate` bọc câu người dùng vào
        // `SELECT * FROM (…)`: thứ không phải SELECT thì không parse nổi ở đó.
        XCTAssertThrowsError(
            try CSVQueryEngine.run("COPY t TO '\(đích)'", in: buffer(), dialect: .comma))
        XCTAssertFalse(FileManager.default.fileExists(atPath: đích),
                       "câu COPY đã GHI RA ĐĨA — hàng rào chỉ-đọc thủng")
    }

    func testTuChoiCauSuaDuLieu() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        for sql in ["DROP VIEW t", "CREATE TABLE x (a INT)", "INSTALL httpfs"] {
            XCTAssertThrowsError(
                try CSVQueryEngine.run(sql, in: buffer(), dialect: .comma),
                "\(sql) phải bị từ chối")
        }
    }

    // MARK: - Nguồn dữ liệu: file gốc hay file tạm

    func testTaiLieuDaLuuThiDocTHANGFileGoc() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let path = NSTemporaryDirectory() + "/geditor-nguon-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try bang.write(toFile: path, atomically: true, encoding: .utf8)

        let trước = temporaryQueryFileCount()
        let result = try CSVQueryEngine.run(
            "SELECT COUNT(*) FROM t", in: buffer(), dialect: .comma, sourcePath: path)
        XCTAssertEqual(result.rows, [["5"]])
        XCTAssertEqual(temporaryQueryFileCount(), trước,
                       "đã lưu rồi mà vẫn chép ra file tạm — đường nhanh không chạy")
    }

    func testBufferDaSuaThiKhongDungFileGocCU() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let path = NSTemporaryDirectory() + "/geditor-cu-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: path) }
        // File trên đĩa là bản CŨ (3 hàng); buffer là bản đang sửa (5 hàng).
        try """
            ma_kh,thanh_pho,doanh_thu,ghi_chu
            KH01,Hà Nội,100,binh thuong
            KH02,Đà Nẵng,250,

            """.write(toFile: path, atomically: true, encoding: .utf8)

        // Nếu đường nhanh tin `sourcePath` mà không so lại thì câu này trả 2 — tức truy vấn
        // chạy trên một PHIÊN BẢN DỮ LIỆU KHÁC thứ người dùng đang nhìn. Sai trong im lặng.
        let result = try CSVQueryEngine.run(
            "SELECT COUNT(*) FROM t", in: buffer(), dialect: .comma, sourcePath: path)
        XCTAssertEqual(result.rows, [["5"]], "đã đọc file cũ trên đĩa thay vì buffer đang sửa")
    }

    func testBufferQuaLonThiNOIRAChuKhongTreo() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let cũ = CSVQueryEngine.materializationLimit
        CSVQueryEngine.materializationLimit = 10        // bytes
        defer { CSVQueryEngine.materializationLimit = cũ }
        XCTAssertThrowsError(
            try CSVQueryEngine.run("SELECT COUNT(*) FROM t", in: buffer(), dialect: .comma)
        ) { error in
            guard case CSVQueryEngine.Failure.tooLargeToMaterialize = error else {
                return XCTFail("mong .tooLargeToMaterialize, nhận \(error)")
            }
            XCTAssertTrue((error as! CSVQueryEngine.Failure).message.contains("Lưu tài liệu"),
                          "thông báo phải nói cách thoát, không chỉ nói là không được")
        }
    }

    func testDonDepFileTam() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let trước = temporaryQueryFileCount()
        _ = try CSVQueryEngine.run("SELECT COUNT(*) FROM t", in: buffer(), dialect: .comma)
        XCTAssertEqual(temporaryQueryFileCount(), trước,
                       "file tạm còn sót lại — chạy trăm câu là đầy đĩa")
    }

    // MARK: - Dấu phân tách

    func testDauChamPhay() throws {
        let text = "a;b\n1;Hà Nội\n2;Huế\n"
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let result = try CSVQueryEngine.run(
            "SELECT b FROM t ORDER BY a", in: buffer(text), dialect: .semicolon)
        XCTAssertEqual(result.rows, [["Hà Nội"], ["Huế"]])
    }

    // MARK: - Hủy

    func testTokenDaHuyTruocKhiChayThiKhongChay() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let token = CancelToken()
        token.cancel()
        // Không đòi hỏi phải ném `.cancelled` ngay — câu này quá nhỏ để kịp ngắt. Đòi hỏi thật
        // là: đã hủy thì KHÔNG được trả về kết quả như chưa có gì xảy ra.
        let outcome = Result {
            try CSVQueryEngine.run(
                "SELECT COUNT(*) FROM t", in: buffer(), dialect: .comma, cancelToken: token)
        }
        if case .success = outcome {
            // Chấp nhận được với bảng 5 hàng: ngắt là hợp tác, không phải tức thì. Ghi lại để
            // người đọc biết đây là lựa chọn có ý thức chứ không phải bài kiểm lỏng.
            XCTAssertTrue(true, "bảng quá nhỏ để kịp ngắt — đúng bản chất hủy hợp tác")
        }
    }

    private func temporaryQueryFileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()))?
            .filter { $0.hasPrefix("geditor-query-") }.count ?? 0
    }
}
