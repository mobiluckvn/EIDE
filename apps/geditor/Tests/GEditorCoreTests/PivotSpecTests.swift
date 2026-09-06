import XCTest
@testable import GEditorCore

/// FR-QRY-003 — pivot sinh SQL. Không chạy truy vấn nào: câu SQL LÀ đầu ra.
final class PivotSpecTests: XCTestCase {

    func testGopMotCotMotGiaTri() {
        let spec = PivotSpec(
            rows: ["tinh"], values: [.init(column: "doanh_thu", aggregate: .sum)])
        XCTAssertEqual(spec.sql(), """
            SELECT "tinh",
                   SUM("doanh_thu") AS "tong_doanh_thu"
            FROM t
            GROUP BY "tinh"
            ORDER BY "tong_doanh_thu" DESC
            """)
    }

    func testNhieuCotNhieuPhepGop() {
        let spec = PivotSpec(
            rows: ["tinh", "nam"],
            values: [
                .init(column: "doanh_thu", aggregate: .sum),
                .init(column: "ma_don", aggregate: .distinct),
                .init(column: "doanh_thu", aggregate: .average),
            ])
        let sql = spec.sql()
        XCTAssertTrue(sql.contains("GROUP BY \"tinh\", \"nam\""), sql)
        XCTAssertTrue(sql.contains("COUNT(DISTINCT \"ma_don\")"), sql)
        XCTAssertTrue(sql.contains("AVG(\"doanh_thu\") AS \"tb_doanh_thu\""), sql)
        // Sắp theo GIÁ TRỊ ĐẦU TIÊN: pivot gần như luôn mở ra để tìm "cái nào lớn nhất".
        XCTAssertTrue(sql.hasSuffix("ORDER BY \"tong_doanh_thu\" DESC"), sql)
    }

    func testCHIcoGiaTriMaKhongCoHang() {
        // "Tổng doanh thu là bao nhiêu" — thứ người ta hay hỏi đầu tiên. Đừng chặn.
        let spec = PivotSpec(rows: [], values: [.init(column: "doanh_thu", aggregate: .sum)])
        let sql = spec.sql()
        XCTAssertTrue(sql.contains("SUM(\"doanh_thu\")"), sql)
        XCTAssertFalse(sql.contains("GROUP BY"), sql)
    }

    func testCHIcoHangThiSAPtheoChinhCotAy() {
        // Thứ tự ỔN ĐỊNH là điều kiện để chạy lại hai lần cho ra cùng bảng.
        let spec = PivotSpec(rows: ["tinh"], values: [])
        XCTAssertTrue(spec.sql().hasSuffix("ORDER BY \"tinh\""), spec.sql())
    }

    func testCHUACHONgiThiChuoiRONG() {
        XCTAssertEqual(PivotSpec().sql(), "")
    }

    func testTATsapXepThiKHONGcoORDERBYtheoGiaTri() {
        let spec = PivotSpec(
            rows: ["tinh"], values: [.init(column: "x", aggregate: .sum)],
            sortByFirstValue: false)
        XCTAssertFalse(spec.sql().contains("DESC"), spec.sql())
    }

    func testLIMIT() {
        let spec = PivotSpec(
            rows: ["tinh"], values: [.init(column: "x", aggregate: .count)], limit: 10)
        XCTAssertTrue(spec.sql().hasSuffix("LIMIT 10"), spec.sql())
    }

    // MARK: - Tên cột là dữ liệu của người dùng

    func testTENCOTcoDAUNHAYkhongPHEVOcauSQL() {
        // Tên cột đến từ dòng tiêu đề CSV — chuỗi ta không kiểm soát.
        let spec = PivotSpec(
            rows: ["Doanh thu \"thực\""],
            values: [.init(column: "a\"b", aggregate: .sum)])
        let sql = spec.sql()
        XCTAssertTrue(sql.contains("\"Doanh thu \"\"thực\"\"\""), sql)
        XCTAssertTrue(sql.contains("SUM(\"a\"\"b\")"), sql)
    }

    func testTENCOTcoDAUCACHvaDAUTIENGVIET() {
        let spec = PivotSpec(
            rows: ["Tỉnh / Thành"], values: [.init(column: "Doanh thu", aggregate: .sum)])
        let sql = spec.sql()
        XCTAssertTrue(sql.contains("\"Tỉnh / Thành\""), sql)
        XCTAssertTrue(sql.contains("SUM(\"Doanh thu\")"), sql)
    }

    func testNHANCOTketQuaKHONGtrungNhau() {
        // Kéo `Tổng doanh thu` vào cạnh một cột đã tên `tong_doanh_thu`: DuckDB sẽ trả hai cột
        // cùng tên, bảng kết quả hiện hai cột không phân biệt được, và tệp CSV xuất ra có hai
        // tiêu đề giống hệt nhau.
        let spec = PivotSpec(
            rows: ["tong_doanh_thu"],
            values: [.init(column: "doanh_thu", aggregate: .sum)])
        let sql = spec.sql()
        XCTAssertTrue(sql.contains("AS \"tong_doanh_thu_2\""), sql)
    }

    func testHAIphepGopTRENcungMotCotThiNhanKhacNhau() {
        let spec = PivotSpec(
            rows: [],
            values: [
                .init(column: "x", aggregate: .sum),
                .init(column: "x", aggregate: .average),
                .init(column: "x", aggregate: .maximum),
            ])
        let sql = spec.sql()
        for alias in ["tong_x", "tb_x", "max_x"] {
            XCTAssertTrue(sql.contains("AS \"\(alias)\""), "thiếu \(alias): \(sql)")
        }
    }

    // MARK: - Câu sinh ra phải CHẠY ĐƯỢC

    func testCauSinhRaChayDuocTrenDuckDB() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        // Không đủ nếu chỉ so chuỗi: một câu đúng hình dạng vẫn có thể sai cú pháp. Chạy nó qua
        // đúng engine mà Workbench dùng.
        let text = "tinh,doanh_thu,ma_don\nHuế,100,A\nHà Nội,250,B\nHuế,300,C\n"
        let buffer = TextBuffer(original: MemoryByteSource(Array(text.utf8)))
        let spec = PivotSpec(
            rows: ["tinh"],
            values: [
                .init(column: "doanh_thu", aggregate: .sum),
                .init(column: "ma_don", aggregate: .distinct),
            ])
        let result = try CSVQueryEngine.run(spec.sql(), in: buffer, dialect: .comma)
        XCTAssertEqual(result.titles, ["tinh", "tong_doanh_thu", "khac_nhau_ma_don"])
        XCTAssertEqual(result.rows, [["Huế", "400", "2"], ["Hà Nội", "250", "1"]])
    }
}
