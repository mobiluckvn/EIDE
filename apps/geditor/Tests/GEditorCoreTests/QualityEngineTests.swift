import XCTest
@testable import GEditorCore

/// FR-DQR-001 — chấm dữ liệu theo bộ quy tắc `.gquality.yaml`.
final class QualityEngineTests: XCTestCase {

    /// Bảng thử, và MỌI kỳ vọng dưới đây suy từ chính bảng này bằng cách đếm tay — không suy từ
    /// kết quả engine trả về. Lấy kết quả phép đo làm đáp án thì phép kiểm không kiểm gì cả.
    ///
    /// ma_don: KH01..KH05, KH03 lặp hai lần → 1 vi phạm `unique`
    /// doanh_thu: một ô rỗng, một ô âm, một ô chữ
    /// email: một ô sai mẫu
    /// tinh: một ô ngoài danh sách
    /// ngay_dat / ngay_giao: một hàng giao TRƯỚC khi đặt
    private let bang = """
        ma_don,doanh_thu,email,tinh,ngay_dat,ngay_giao
        KH01,100,an@vd.vn,Hà Nội,2026-01-01,2026-01-05
        KH02,,binh@vd.vn,Huế,2026-01-02,2026-01-06
        KH03,-50,chi@vd.vn,Đà Nẵng,2026-01-03,2026-01-07
        KH03,300,khong-phai-email,Hà Nội,2026-01-04,2026-01-02
        KH05,abc,em@vd.vn,Sài Gòn,2026-01-05,2026-01-09

        """

    private func chay(_ yaml: String) throws -> QualityEngine.Report {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let rules = try QualityRules.load(fromYAML: yaml)
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        return try QualityEngine.evaluate(rules, in: buffer, dialect: .comma)
    }

    private func viPham(_ report: QualityEngine.Report, _ index: Int) -> Int {
        report.results[index].violations
    }

    // MARK: - Từng loại luật

    func testNotNullDemDungOTrong() throws {
        let report = try chay("rules:\n  - col: doanh_thu\n    not_null: true")
        XCTAssertEqual(report.rowCount, 5)
        XCTAssertEqual(viPham(report, 0), 1)
        XCTAssertFalse(report.results[0].passed)
    }

    func testNotNullCoNGUONGthiVanPASS() throws {
        // 1/5 = 20% null. Ngưỡng 25% thì ĐẠT — đây là vế `max_null_pct` mà đặc tả đòi, và nó
        // là khác biệt giữa "phán xét theo kỳ vọng" với "báo mọi thứ khác 0 là hỏng".
        let report = try chay("""
            rules:
              - col: doanh_thu
                not_null: 25
            """)
        XCTAssertEqual(viPham(report, 0), 1)
        XCTAssertTrue(report.results[0].passed, "20% null dưới ngưỡng 25% mà vẫn báo trượt")
    }

    func testUnique() throws {
        let report = try chay("rules:\n  - col: ma_don\n    unique: true")
        // KH03 xuất hiện hai lần → **2 hàng** vi phạm, không phải 1.
        //
        // Đây là một quyết định về Ý NGHĨA, đổi ngày 26/08/2026: số vi phạm phải bằng số hàng
        // sẽ được TÔ khi người dùng bấm vào luật. Cách cũ đếm số hàng THỪA
        // (`COUNT(*) − COUNT(DISTINCT)` = 1) nên bảng nói "1 vi phạm" trong khi Mark tô 2 dòng.
        // Hai con số cho cùng một luật là chỗ người dùng mất lòng tin vào cả báo cáo.
        XCTAssertEqual(viPham(report, 0), 2)
    }

    func testDtypeIntBoQuaOTRONG() throws {
        let report = try chay("rules:\n  - col: doanh_thu\n    dtype: int")
        // Chỉ "abc" sai kiểu. Ô RỖNG không sai kiểu — nó không có giá trị để mà sai, và tính nó
        // vào đây là đếm một vi phạm hai lần (xem ghi chú đầu QualityEngine).
        XCTAssertEqual(viPham(report, 0), 1)
    }

    func testRange() throws {
        let report = try chay("""
            rules:
              - col: doanh_thu
                range: {min: 0}
            """)
        // -50 ngoài khoảng, "abc" không đổi được sang số → cũng tính. Ô rỗng thì không.
        XCTAssertEqual(viPham(report, 0), 2)
    }

    func testRegex() throws {
        let report = try chay("""
            rules:
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
            """)
        XCTAssertEqual(viPham(report, 0), 1)
    }

    func testInSet() throws {
        let report = try chay("""
            rules:
              - col: tinh
                in_set: [Hà Nội, Huế, Đà Nẵng]
            """)
        XCTAssertEqual(viPham(report, 0), 1, "Sài Gòn ngoài danh sách")
    }

    func testLength() throws {
        let report = try chay("rules:\n  - col: ma_don\n    length: {min: 4, max: 4}")
        XCTAssertEqual(viPham(report, 0), 0)
    }

    func testDateFormat() throws {
        let report = try chay("""
            rules:
              - col: ngay_dat
                date_format: '%Y-%m-%d'
            """)
        XCTAssertEqual(viPham(report, 0), 0)
    }

    func testCompareLienCot() throws {
        let report = try chay("""
            rules:
              - compare: {a: ngay_giao, op: '>=', b: ngay_dat}
            """)
        XCTAssertEqual(viPham(report, 0), 1, "hàng KH03 thứ hai giao trước khi đặt")
    }

    func testExprSQLtuyY() throws {
        // Chính ví dụ SRS: `expr: "ngay_giao >= ngay_dat"`.
        let report = try chay("""
            rules:
              - expr: "ngay_giao >= ngay_dat"
                severity: warn
            """)
        XCTAssertEqual(viPham(report, 0), 1)
        XCTAssertEqual(report.results[0].rule.severity, .warn)
        XCTAssertTrue(report.failedWarnings.count == 1)
        XCTAssertTrue(report.failedErrors.isEmpty, "warn không được tính thành error")
    }

    // MARK: - MỘT lượt quét cho nhiều luật (NFR-DQR-01)

    func testNhieuLuatVanDungKetQua() throws {
        let report = try chay("""
            rules:
              - col: ma_don
                unique: true
              - col: doanh_thu
                not_null: true
              - col: doanh_thu
                range: {min: 0}
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
              - col: tinh
                in_set: [Hà Nội, Huế, Đà Nẵng]
              - compare: {a: ngay_giao, op: '>=', b: ngay_dat}
            """)
        XCTAssertEqual(report.results.count, 6)
        XCTAssertEqual(report.results.map(\.violations), [2, 1, 2, 1, 1, 1])
        // Thứ tự phải khớp thứ tự trong TỆP: bảng kết quả đọc song song với tệp quy tắc là thứ
        // người ta làm khi sửa chuẩn.
        XCTAssertEqual(report.results[0].rule.column, "ma_don")
        XCTAssertEqual(report.results[5].rule.column, nil)
    }

    // MARK: - Luật hỏng thì nói LUẬT NÀO

    func testTenCotSaiThiChiDUNGLUATnaoHong() throws {
        let report = try chay("""
            rules:
              - col: ma_don
                unique: true
              - col: khong_co_cot_nay
                not_null: true
            """)
        XCTAssertEqual(report.results.count, 2)
        // Luật đúng vẫn phải cho kết quả — cả lượt quét hỏng vì một luật sai mà báo cáo trả về
        // "có gì đó sai" thì người dùng không sửa được gì.
        XCTAssertEqual(report.results[0].violations, 2)
        XCTAssertNil(report.results[0].failure)
        XCTAssertNotNil(report.results[1].failure)
        XCTAssertTrue(report.results[1].failure?.contains("khong_co_cot_nay") == true,
                      report.results[1].failure ?? "")
        XCTAssertFalse(report.results[1].passed, "luật không chạy được KHÔNG được coi là ĐẠT")
    }

    // MARK: - Khoá ngoại (liên file)

    func testForeignKey() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let tra = NSTemporaryDirectory() + "/geditor-tinh-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: tra) }
        try "ten_tinh\nHà Nội\nHuế\nĐà Nẵng\n".write(toFile: tra, atomically: true, encoding: .utf8)

        let rules = try QualityRules.load(fromYAML: """
            rules:
              - col: tinh
                foreign_key: {file: '\(tra)', column: ten_tinh}
            """)
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        let report = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma)
        XCTAssertEqual(report.results.count, 1)
        XCTAssertEqual(report.results[0].violations, 1, "Sài Gòn không có trong bảng tra")
        XCTAssertEqual(report.results[0].rowCount, 5)
    }

    func testHaiLuatTRUNGNHAUkhongLamSAPapp() throws {
        // Chép dán một khối luật là chuyện người dùng làm thường xuyên. Bản đầu của
        // `QualityEngine` sắp lại thứ tự bằng `Dictionary(uniqueKeysWithValues:)` khoá bằng
        // chính `Rule` — và nó SẬP ở đúng đây. Phép đo NFR-DQR-01 bắt được; 16 bài kiểm trước
        // đó thì không, vì không bài nào có hai luật trùng.
        let report = try chay("""
            rules:
              - col: ma_don
                unique: true
              - col: ma_don
                unique: true
            """)
        XCTAssertEqual(report.results.count, 2)
        XCTAssertEqual(report.results.map(\.violations), [2, 2])
    }

    // MARK: - Chỉ ra ĐÚNG HÀNG vi phạm (FR-DQR-001)

    private func hangViPham(_ yaml: String) throws -> [Int] {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let rules = try QualityRules.load(fromYAML: yaml)
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        return try QualityEngine.violatingRowNumbers(
            for: rules.rules[0], in: buffer, dialect: .comma)
    }

    func testChiRaDungSOHIEUHANG() throws {
        // doanh_thu rỗng ở hàng 2 (KH02). Số hàng tính theo DỮ LIỆU, không tính dòng tiêu đề.
        XCTAssertEqual(try hangViPham("rules:\n  - col: doanh_thu\n    not_null: true"), [2])
        // Sài Gòn ở hàng 5.
        XCTAssertEqual(
            try hangViPham("""
                rules:
                  - col: tinh
                    in_set: [Hà Nội, Huế, Đà Nẵng]
                """), [5])
    }

    func testUNIQUEtoCAHAIhangTrungNhau() throws {
        // KH03 ở hàng 3 và 4. Chỉ tô hàng 4 thì người dùng thấy một dòng "trùng" mà không thấy
        // dòng nó trùng với, và không sửa được gì.
        XCTAssertEqual(try hangViPham("rules:\n  - col: ma_don\n    unique: true"), [3, 4])
    }

    func testUNIQUEchayDuocKhiTaiLieuCHUALUU() throws {
        // Không truyền `sourcePath` — tài liệu chưa lưu. Bản đầu tự tham chiếu đường dẫn nguồn
        // và hỏng ở đúng đây.
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let rules = try QualityRules.load(fromYAML: "rules:\n  - col: ma_don\n    unique: true")
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        XCTAssertEqual(
            try QualityEngine.violatingRowNumbers(
                for: rules.rules[0], in: buffer, dialect: .comma, sourcePath: nil),
            [3, 4])
    }

    func testSOHANGkhopSOLUONGdaDEM() throws {
        // Hai đường khác nhau — `evaluate` đếm bằng một lượt gộp, `violatingRowNumbers` liệt kê
        // bằng một lượt tuần tự. Chúng PHẢI cho cùng câu trả lời, nếu không thì bảng kết quả
        // nói một đằng và Mark chỉ một nẻo.
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        for yaml in [
            "rules:\n  - col: doanh_thu\n    not_null: true",
            "rules:\n  - col: ma_don\n    unique: true",
            "rules:\n  - col: doanh_thu\n    range: {min: 0}",
        ] {
            let rules = try QualityRules.load(fromYAML: yaml)
            let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
            let report = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma)
            let rows = try QualityEngine.violatingRowNumbers(
                for: rules.rules[0], in: buffer, dialect: .comma)
            XCTAssertEqual(report.results[0].violations, rows.count, yaml)
        }
    }

    func testGioiHanSoHangTraVe() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        // Không ai duyệt tay một triệu dòng vi phạm; trần phải có thật.
        let rules = try QualityRules.load(fromYAML: "rules:\n  - col: ma_don\n    unique: true")
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        XCTAssertEqual(
            try QualityEngine.violatingRowNumbers(
                for: rules.rules[0], in: buffer, dialect: .comma, limit: 1).count, 1)
    }

    // MARK: - Thoát chuỗi

    func testTenCotCoDauNhayKHONGpheVoCauSQL() {
        let quoted = QualityEngine.quoteIdentifier("ten \"la\"")
        XCTAssertEqual(quoted, "\"ten \"\"la\"\"\"")
        XCTAssertEqual(QualityEngine.quoteLiteral("O'Brien"), "'O''Brien'")
    }

    func testChiDOCkhongGhi() throws {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        // NFR-DQR-02: chấm điểm không được sửa dữ liệu nguồn. Kiểm bằng CHECKSUM chứ không bằng
        // đọc mã.
        let path = NSTemporaryDirectory() + "/geditor-nguon-dqr-\(UUID().uuidString).csv"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try bang.write(toFile: path, atomically: true, encoding: .utf8)
        let truoc = try PluginTrust.sha256(ofFileAt: path)

        let rules = try QualityRules.load(fromYAML: "rules:\n  - col: ma_don\n    unique: true")
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        _ = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma, sourcePath: path)

        XCTAssertEqual(try PluginTrust.sha256(ofFileAt: path), truoc,
                       "chấm điểm ĐÃ SỬA file nguồn — NFR-DQR-02 thủng")
    }
}
