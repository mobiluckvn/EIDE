import XCTest
@testable import GEditorCore

/// FR-DQR-002 — điểm chất lượng sáu chiều.
final class QualityScoreTests: XCTestCase {

    /// Cùng bảng của `QualityEngineTests`, và mọi kỳ vọng vẫn đếm tay từ bảng này.
    ///
    /// 5 hàng × 6 cột = 30 ô, đúng 1 ô rỗng (doanh_thu của KH02).
    /// ma_don: KH03 lặp → 1 bản ghi trùng.
    private let bang = """
        ma_don,doanh_thu,email,tinh,ngay_dat,ngay_giao
        KH01,100,an@vd.vn,Hà Nội,2026-01-01,2026-01-05
        KH02,,binh@vd.vn,Huế,2026-01-02,2026-01-06
        KH03,-50,chi@vd.vn,Đà Nẵng,2026-01-03,2026-01-07
        KH03,300,khong-phai-email,Hà Nội,2026-01-04,2026-01-02
        KH05,abc,em@vd.vn,Sài Gòn,2026-01-05,2026-01-09

        """

    private let moc = Date(timeIntervalSince1970: 1_767_225_600)   // 2026-01-01T00:00:00Z

    private func cham(_ yaml: String, now: Date? = nil) throws -> QualityScore {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let rules = try QualityRules.load(fromYAML: yaml)
        let buffer = TextBuffer(original: MemoryByteSource(Array(bang.utf8)))
        let report = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma)
        return try QualityScorer.score(
            report, rules: rules, in: buffer, dialect: .comma,
            now: now ?? Date(timeIntervalSince1970: 1_767_312_000))   // 2026-01-02
    }

    private func chieu(_ score: QualityScore, _ dimension: QualityRules.Dimension)
        -> QualityScore.DimensionScore {
        score.dimensions.first { $0.dimension == dimension }!
    }

    // MARK: - Từng chiều

    func testCompletenessDemDungOTrong() throws {
        let score = try cham("rules:\n  - col: ma_don\n    unique: true")
        let c = chieu(score, .completeness)
        // 1 ô rỗng / 30 ô → 29/30 = 96,666…%
        XCTAssertEqual(c.value ?? 0, 29.0 / 30.0 * 100, accuracy: 0.001)
        XCTAssertTrue(c.detail.contains("1 ô rỗng"), c.detail)
        XCTAssertTrue(c.detail.contains("30 ô"), c.detail)
    }

    func testUniquenessTheoKHOAKHAIBAO() throws {
        let score = try cham("""
            uniqueness_key: [ma_don]
            rules:
              - col: ma_don
                unique: true
            """)
        let u = chieu(score, .uniqueness)
        // 5 hàng, 4 khoá phân biệt → 1 trùng → 4/5 = 80%
        XCTAssertEqual(u.value ?? 0, 80, accuracy: 0.001)
    }

    func testCHUAKHAIkhoaThiKHONGCHAMchuKhongPhaiCho100() throws {
        // Đây là tính chất quan trọng nhất của cả tệp: một bảng chưa khai khoá mà được cho 100
        // điểm "không trùng" là điểm số nói dối, và nói dối theo hướng CÓ LỢI.
        let score = try cham("rules:\n  - col: ma_don\n    not_null: true")
        let u = chieu(score, .uniqueness)
        XCTAssertNil(u.value)
        XCTAssertTrue(u.note?.contains("không được tính là 100") == true, u.note ?? "")
        // Và nó phải bị LOẠI khỏi điểm tổng, không kéo tổng xuống bằng 0.
        XCTAssertFalse(score.unscored.isEmpty)
        XCTAssertNotNil(score.total)
    }

    func testValidityDemTHEOLUATdungNguyenVanDacTa() throws {
        let score = try cham("""
            rules:
              - col: doanh_thu
                dtype: int
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
              - col: ngay_dat
                date_format: '%Y-%m-%d'
            """)
        let v = chieu(score, .validity)
        // 3 luật định dạng, 1 đạt (date_format) → 33,33%
        XCTAssertEqual(v.value ?? 0, 100.0 / 3.0, accuracy: 0.001)
        XCTAssertTrue(v.detail.contains("1/3 luật đạt"), v.detail)
        // Công thức phải nói rõ nó đếm theo LUẬT — đó là chỗ dễ hiểu nhầm nhất của cả điểm số.
        XCTAssertTrue(v.formula.contains("số luật ĐẠT"), v.formula)
    }

    func testConsistencyLaLuatLIENCOTvaLIENFILE() throws {
        let score = try cham("""
            rules:
              - compare: {a: ngay_giao, op: '>=', b: ngay_dat}
            """)
        let c = chieu(score, .consistency)
        XCTAssertEqual(c.value ?? 0, 0, accuracy: 0.001, "1 luật liên cột, trượt → 0%")
    }

    func testAccuracyMADbatDuocGiaTriCucDoan() throws {
        // doanh_thu đọc được: 100, -50, 300 (ô rỗng và "abc" bị loại). Trung vị 100,
        // MAD = trung vị(|0|, |150|, |200|) = 150. Ngưỡng = 3 × 1,4826 × 150 ≈ 667.
        // Không giá trị nào vượt → 100%.
        let score = try cham("""
            accuracy_columns: [doanh_thu]
            rules:
              - col: doanh_thu
                not_null: true
            """)
        let a = chieu(score, .accuracy)
        XCTAssertEqual(a.value ?? 0, 100, accuracy: 0.001)
        XCTAssertTrue(a.detail.contains("3 ô"), a.detail)
        // Công thức phải in ra CẢ HAI hằng số — không thì con số này không tính lại được.
        XCTAssertTrue(a.formula.contains("1.4826") || a.formula.contains("1,4826")
                        || a.formula.contains("1.4826"), a.formula)
    }

    func testCotHANGSOkhongBiChamLaBatThuong() throws {
        // MAD = 0 khi mọi giá trị bằng nhau. Khi ấy mọi lệch khác 0 đều "vượt ngưỡng" và cột sẽ
        // bị chấm 0 điểm chính xác — không đo được độ phân tán thì KHÔNG kết luận, chứ không
        // kết luận xấu.
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let text = "a,b\n5,x\n5,y\n5,z\n"
        let rules = try QualityRules.load(fromYAML: "accuracy_columns: [a]\nrules: []")
        let buffer = TextBuffer(original: MemoryByteSource(Array(text.utf8)))
        let report = try QualityEngine.evaluate(rules, in: buffer, dialect: .comma)
        let score = try QualityScorer.score(report, rules: rules, in: buffer, dialect: .comma)
        XCTAssertEqual(chieu(score, .accuracy).value ?? 0, 100, accuracy: 0.001)
    }

    // MARK: - Tất định (NFR-DQR-03)

    func testTIMELINESSdungMOCTRUYENVAOchuKhongDungBayGio() throws {
        // Chỗ DUY NHẤT phá được tính tất định. "Bây giờ" là tham số, và được ghi vào kết quả.
        let yaml = """
            freshness: {column: ngay_dat, max_age_days: 10}
            rules: []
            """
        // Mốc mới nhất trong bảng là 2026-01-05. Chấm ở 2026-01-06 → tuổi 1 ngày ≤ 10 → 100.
        let som = try cham(yaml, now: Date(timeIntervalSince1970: 1_767_657_600))
        XCTAssertEqual(chieu(som, .timeliness).value ?? 0, 100, accuracy: 0.001)

        // Chấm ở 2026-01-26 → tuổi 21 ngày > 2×10 → 0.
        let muon = try cham(yaml, now: Date(timeIntervalSince1970: 1_769_385_600))
        XCTAssertEqual(chieu(muon, .timeliness).value ?? 0, 0, accuracy: 0.001)

        XCTAssertNotEqual(som.evaluatedAt, muon.evaluatedAt)
        XCTAssertTrue(chieu(som, .timeliness).detail.contains("tính theo mốc"),
                      "kết quả phải GHI RA mốc đã dùng, nếu không thì không chạy lại được")
    }

    func testCUNGDULIEUvaCUNGMOCthiCUNGDIEM() throws {
        let yaml = """
            uniqueness_key: [ma_don]
            accuracy_columns: [doanh_thu]
            freshness: {column: ngay_dat, max_age_days: 10}
            rules:
              - col: ma_don
                unique: true
              - col: doanh_thu
                dtype: int
            """
        let a = try cham(yaml, now: moc)
        let b = try cham(yaml, now: moc)
        XCTAssertEqual(a.dimensions.map(\.value), b.dimensions.map(\.value))
        XCTAssertEqual(a.total, b.total)
    }

    // MARK: - Điểm tổng

    func testTRONGSOtuTepQuyTac() throws {
        // completeness ≈ 96,67 (trọng số 3), validity 0 (trọng số 1).
        // Bốn chiều kia không chấm được → bị loại.
        let score = try cham("""
            weights: {completeness: 3, validity: 1}
            rules:
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
            """)
        let expected = (29.0 / 30.0 * 100 * 3 + 0 * 1) / 4
        XCTAssertEqual(score.total ?? 0, expected, accuracy: 0.001)
    }

    func testTRONGSOlaMOTkhiKhongKhai() throws {
        let score = try cham("""
            rules:
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
            """)
        // completeness và validity, mỗi chiều trọng số 1.
        let expected = (29.0 / 30.0 * 100 + 0) / 2
        XCTAssertEqual(score.total ?? 0, expected, accuracy: 0.001)
    }

    func testTRONGSOlaKHONGthiChieuAyKhongTinhVaoTong() throws {
        let score = try cham("""
            weights: {validity: 0}
            rules:
              - col: email
                regex: '^[^@]+@[^@]+\\.[a-z]+$'
            """)
        XCTAssertEqual(score.total ?? 0, 29.0 / 30.0 * 100, accuracy: 0.001)
    }

    func testMOICHIEUdeuCoCONGTHUCinRa() throws {
        let score = try cham("rules: []")
        XCTAssertEqual(score.dimensions.count, 6)
        for dimension in score.dimensions {
            // NFR-DQR-03: công thức từng chiều in trong kết quả. Một chiều không có công thức
            // là một con số người đọc không kiểm lại được.
            XCTAssertFalse(dimension.formula.isEmpty, "\(dimension.dimension) thiếu công thức")
            if dimension.value == nil {
                XCTAssertNotNil(dimension.note, "\(dimension.dimension) không chấm được mà không nói lý do")
            }
        }
    }
}
