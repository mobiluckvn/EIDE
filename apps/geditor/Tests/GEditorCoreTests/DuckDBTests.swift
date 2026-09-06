import XCTest
@testable import GEditorCore

/// Lớp bọc DuckDB (ADR-14) — bài kiểm cho chính CÁI CỬA, không cho tầng truy vấn bên trên.
///
/// Tách riêng vì nó hỏng theo kiểu khác hẳn: sai chữ ký `dlsym` thì không "trả kết quả sai",
/// nó ghi đè bộ nhớ hoặc làm sập tiến trình. Một bài kiểm chạy sớm và chạm vào từng hàm là
/// cách rẻ nhất để bắt loại hỏng ấy trước khi nó nấp trong một câu SQL dài.
final class DuckDBTests: XCTestCase {

    /// Bỏ qua cả nhóm khi máy chưa có dylib, và NÓI RA.
    ///
    /// Không dùng `XCTSkip` im lặng: một nhóm bài kiểm tự tắt mà không kêu là một nhóm sẽ tắt
    /// vĩnh viễn trên CI mà không ai biết. Ở đây thông điệp đi kèm đường dẫn đã thử.
    private func requireDuckDB() throws -> DuckDB.Connection {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else {
            throw XCTSkip("""
                Chưa có libduckdb.dylib — chạy scripts/vendor-duckdb.sh trước.
                \(DuckDB.failureReason ?? "")
                """)
        }
        return try DuckDB.connect()
    }

    func testChayCauDonGian() throws {
        let connection = try requireDuckDB()
        let table = try connection.query("SELECT 40 + 2 AS tong")
        XCTAssertEqual(table.titles, ["tong"])
        XCTAssertEqual(table.rows, [["42"]])
    }

    func testPhienBanDocDuoc() throws {
        _ = try requireDuckDB()
        let version = DuckDB.shared?.version ?? ""
        // Không chốt cứng con số: phiên bản sẽ đổi. Chốt rằng ta ĐỌC được nó — vì nó phải hiện
        // trong About (cùng lý do XMLSchemaValidator kèm phiên bản libxml2: hai máy khác phiên
        // bản có thể cho verdict khác nhau ở góc hiếm, và người báo lỗi cần nói được số nào).
        XCTAssertFalse(version.isEmpty)
        XCTAssertNotEqual(version, "không rõ")
    }

    func testNULLKhacChuoiRong() throws {
        let connection = try requireDuckDB()
        let table = try connection.query("SELECT NULL AS a, '' AS b")
        XCTAssertEqual(table.rows.count, 1)
        // Phân biệt này không phải chuyện thẩm mỹ: trong dữ liệu thật "chưa có giá trị" và
        // "giá trị là chuỗi rỗng" là hai chuyện khác nhau, và cả cụm FR-CLN-002 dựng trên đó.
        XCTAssertNil(table.rows[0][0])
        XCTAssertEqual(table.rows[0][1], "")
    }

    func testCauSaiCuPhapNemLoiCoNoiDung() throws {
        let connection = try requireDuckDB()
        XCTAssertThrowsError(try connection.query("SELECT FROM WHERE")) { error in
            guard case DuckDB.Failure.query(let message) = error else {
                return XCTFail("mong lỗi .query, nhận \(error)")
            }
            XCTAssertFalse(message.isEmpty, "lỗi rỗng thì người dùng không sửa được gì")
        }
    }

    func testDocCSVTuFile() throws {
        let connection = try requireDuckDB()
        let path = NSTemporaryDirectory() + "/geditor-duckdb-test-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try """
        ma_kh,thanh_pho,doanh_thu
        KH01,Hà Nội,100
        KH02,Đà Nẵng,250
        KH03,Hà Nội,300

        """.write(toFile: path, atomically: true, encoding: .utf8)

        let escaped = path.replacingOccurrences(of: "'", with: "''")
        let table = try connection.query("""
            SELECT thanh_pho, COUNT(*) AS so_hang, SUM(doanh_thu) AS tong
            FROM read_csv('\(escaped)', header = true)
            GROUP BY thanh_pho ORDER BY thanh_pho
            """)
        XCTAssertEqual(table.titles, ["thanh_pho", "so_hang", "tong"])
        XCTAssertEqual(table.rows, [
            ["Hà Nội", "2", "400"],
            ["Đà Nẵng", "1", "250"],
        ].sorted { ($0[0] ?? "") < ($1[0] ?? "") })
    }

    func testChuTiengVietQuaLaiNguyenVen() throws {
        let connection = try requireDuckDB()
        // Đi qua C string hai chiều. Một lỗi mã hoá ở cửa này sẽ hỏng im lặng trên đúng thứ
        // dữ liệu mà sản phẩm này phục vụ.
        let table = try connection.query("SELECT 'Nguyễn Thị Ánh Tuyết' AS ten")
        XCTAssertEqual(table.rows, [["Nguyễn Thị Ánh Tuyết"]])
    }

    func testHaiKetNoiDocLapNhau() throws {
        _ = try requireDuckDB()
        let a = try DuckDB.connect()
        let b = try DuckDB.connect()
        _ = try a.query("CREATE TABLE chi_co_o_a (x INT)")
        // Mỗi kết nối là một cơ sở dữ liệu trong bộ nhớ RIÊNG. Nếu chúng dùng chung thì hai
        // panel truy vấn mở cùng lúc sẽ giẫm lên bảng tạm của nhau.
        XCTAssertThrowsError(try b.query("SELECT * FROM chi_co_o_a"))
    }
}

/// Bắt trường hợp file LFS chưa hydrate — nói ra thay vì lặng lẽ bỏ qua.
///
/// `XCTSkip` là đúng khi máy KHÔNG CÓ dylib. Nó là sai khi có một file con trỏ LFS 130 byte
/// nằm đúng chỗ: khi ấy cả nhóm bài kiểm tự tắt và bộ kiểm xanh cho một sản phẩm không truy
/// vấn được. Hai tình huống ấy phải phân biệt, và chỉ một trong hai được phép im lặng.
func requireHydratedDuckDB(file: StaticString = #filePath, line: UInt = #line) throws {
    for path in DuckDB.libraryCandidates {
        guard let size = try? FileManager.default
            .attributesOfItem(atPath: path)[.size] as? Int else { continue }
        if size < 1_000_000 {
            XCTFail("""
                \(path) chỉ \(size) byte — đây là con trỏ Git LFS chưa tải, không phải dylib.
                Chạy: git lfs install && git lfs pull
                """, file: file, line: line)
            return
        }
        return
    }
    throw XCTSkip("Máy chưa có libduckdb.dylib — chạy scripts/vendor-duckdb.sh")
}
