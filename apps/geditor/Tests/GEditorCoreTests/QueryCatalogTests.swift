import XCTest
@testable import GEditorCore

/// FR-QRY-005 — danh mục bảng ảo.
final class QueryCatalogTests: XCTestCase {

    private var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "geditor-catalog-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    @discardableResult
    private func viet(_ name: String, _ text: String) throws -> String {
        let path = root + "/" + name
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Tên mặc định

    func testTenMacDinhTuTENFILE() {
        XCTAssertEqual(QueryCatalog.defaultName(forPath: "/a/khach_hang.csv"), "khach_hang")
        XCTAssertEqual(QueryCatalog.defaultName(forPath: "/a/Bao cao thang 7.csv"),
                       "Bao_cao_thang_7")
        XCTAssertEqual(QueryCatalog.defaultName(forPath: "/a/don-hang.csv"), "don_hang")
    }

    func testBODAUtiengVietTrongTenBang() {
        // Tên bảng phải là định danh SQL ASCII; tên file thì không.
        XCTAssertEqual(QueryCatalog.defaultName(forPath: "/a/Tỉnh thành.csv"), "Tinh_thanh")
    }

    func testCHUdKHONGbiMatDau() {
        // `đ` là một CHỮ CÁI riêng, không phải `d` có dấu — `diacriticInsensitive` không gỡ nó,
        // và không xử lý tay thì `đơn_hàng.csv` mất chữ đầu.
        let name = QueryCatalog.defaultName(forPath: "/a/đơn hàng.csv")
        XCTAssertNotNil(name)
        XCTAssertTrue(name!.lowercased().hasPrefix("d"), name ?? "")
    }

    func testTenKhongDUNGDUOCthiTraNILchuKhongBia() {
        // Một danh mục toàn `bang_1`, `bang_2` là một danh mục không tra được.
        XCTAssertNil(QueryCatalog.defaultName(forPath: "/a/2026.csv"), "bắt đầu bằng số")
        XCTAssertNil(QueryCatalog.defaultName(forPath: "/a/!!!.csv"))
    }

    // MARK: - Đăng ký

    func testDangKyRoiSinhRaNguonChoEngine() throws {
        let path = try viet("kh.csv", "a,b\n1,2\n")
        var catalog = QueryCatalog()
        try catalog.register(path: path, name: "kh")
        XCTAssertEqual(catalog.sources, ["kh": path])
    }

    func testTUCHOItenTRUNG() throws {
        let a = try viet("a.csv", "x\n1\n")
        let b = try viet("b.csv", "x\n1\n")
        var catalog = QueryCatalog()
        try catalog.register(path: a, name: "bang")
        XCTAssertThrowsError(try catalog.register(path: b, name: "bang")) { error in
            XCTAssertEqual(error as? QueryCatalog.Failure, .duplicateName("bang"))
        }
    }

    func testTUCHOItenKHONGHOPLE() throws {
        let path = try viet("a.csv", "x\n1\n")
        var catalog = QueryCatalog()
        // Trùng tên bảng của tài liệu đang mở là một cái bẫy im lặng: câu `FROM t` sẽ chạy trên
        // file khác thứ người dùng đang nhìn.
        XCTAssertThrowsError(try catalog.register(path: path, name: "t"))
        XCTAssertThrowsError(try catalog.register(path: path, name: "có dấu"))
        XCTAssertThrowsError(try catalog.register(path: path, name: "2020"))
    }

    // MARK: - Tự vô hiệu khi file đổi

    func testFILEDOIthiBAOlaCU() throws {
        let path = try viet("a.csv", "x\n1\n")
        var catalog = QueryCatalog()
        try catalog.register(path: path, name: "a")
        XCTAssertTrue(catalog.staleTables.isEmpty)

        // Đổi nội dung GIỮ NGUYÊN độ dài — chỉ so cỡ file thì lọt.
        try "x\n9\n".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertEqual(catalog.staleTables.count, 1,
                       "sửa một ô mà giữ nguyên độ dài thì danh mục không nhận ra")
    }

    func testFILEBIENMATcungLaDOI() throws {
        let path = try viet("a.csv", "x\n1\n")
        var catalog = QueryCatalog()
        try catalog.register(path: path, name: "a")
        try FileManager.default.removeItem(atPath: path)
        // Một bảng trỏ vào chỗ không còn gì là bảng người dùng phải BIẾT, không phải bảng lặng
        // lẽ báo lỗi lúc chạy.
        XCTAssertEqual(catalog.staleTables.count, 1)
    }

    func testNAPLAIthiHETcu() throws {
        let path = try viet("a.csv", "x\n1\n")
        var catalog = QueryCatalog()
        try catalog.register(path: path, name: "a")
        try "x,y\n1,2\n".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertFalse(catalog.staleTables.isEmpty)
        catalog.refresh(name: "a", columns: [.init(name: "x", type: "BIGINT"),
                                             .init(name: "y", type: "BIGINT")])
        XCTAssertTrue(catalog.staleTables.isEmpty)
        XCTAssertEqual(catalog.tables[0].columns.count, 2)
    }

    // MARK: - Suy schema qua DuckDB

    func testSUYSCHEMAtuFileThat() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let path = try viet("kh.csv", "ma,ten,tuoi\nA,An,30\nB,Bình,41\n")
        let buffer = TextBuffer(original: MemoryByteSource(Array("z\n1\n".utf8)))
        let result = try CSVQueryEngine.run(
            QueryCatalog.describeSQL(forPath: path), in: buffer, dialect: .comma)
        let columns = QueryCatalog.columns(fromDescribe: result)
        XCTAssertEqual(columns.map(\.name), ["ma", "ten", "tuoi"])
        // Kiểu để HIỆN, không để quyết định — nhưng nó phải đúng, nếu không danh mục nói dối.
        XCTAssertTrue(columns[2].type.contains("INT"), columns[2].type)
        XCTAssertTrue(columns[1].type.contains("VARCHAR"), columns[1].type)
    }

    func testJOINhaiBangDaDangKy() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let don = try viet("don.csv", "ma,tinh\nA,Huế\nB,Hà Nội\n")
        let vung = try viet("vung.csv", "tinh,mien\nHuế,Trung\nHà Nội,Bắc\n")
        var catalog = QueryCatalog()
        try catalog.register(path: don, name: "don")
        try catalog.register(path: vung, name: "vung")

        let buffer = TextBuffer(original: MemoryByteSource(Array("z\n1\n".utf8)))
        let result = try CSVQueryEngine.run("""
            SELECT v.mien, COUNT(*) FROM don d JOIN vung v ON d.tinh = v.tinh
            GROUP BY v.mien ORDER BY v.mien
            """, in: buffer, dialect: .comma, extraSources: catalog.sources)
        XCTAssertEqual(result.rows, [["Bắc", "1"], ["Trung", "1"]])
    }
}
