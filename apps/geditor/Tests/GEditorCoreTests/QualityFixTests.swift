import XCTest
@testable import GEditorCore

/// FR-DQR-006 — luật trượt nối với đúng công cụ sửa.
final class QualityFixTests: XCTestCase {

    private func rule(_ kind: QualityRules.Rule.Kind, col: String? = "a") -> QualityRules.Rule {
        QualityRules.Rule(column: col, kind: kind)
    }

    /// Bốn cặp đặc tả kê thẳng ra.
    func testBONCAPDacTaKe() {
        XCTAssertEqual(
            QualityFix.tool(for: rule(.notNull(maxNullPercent: 0))), .missingValues(column: "a"))
        XCTAssertEqual(
            QualityFix.tool(for: rule(.dateFormat("%d/%m/%Y"))), .normalizeDates(column: "a"))
        XCTAssertEqual(QualityFix.tool(for: rule(.unique)), .deduplicate(column: "a"))
        XCTAssertEqual(QualityFix.tool(for: rule(.regex("^A"))), .replace(column: "a"))
        XCTAssertEqual(QualityFix.tool(for: rule(.inSet(["x"]))), .replace(column: "a"))
    }

    /// `dtype: date` cùng một chuyện với `date_format` — ô không đổi được sang ngày.
    func testDTYPEDATECungDiVaoChuanHoaNgay() {
        XCTAssertEqual(QualityFix.tool(for: rule(.dtype(.date))), .normalizeDates(column: "a"))
        XCTAssertFalse(QualityFix.tool(for: rule(.dtype(.int))).isAutomatic)
    }

    /// Luật không có công cụ tương ứng vẫn có nút, nhưng nói ra LÝ DO.
    ///
    /// Ẩn nút đi thì người dùng tưởng mình bỏ sót một thao tác.
    func testLUATKHONGSUATUDONGDUOCVanNoiLyDo() {
        for kind in [
            QualityRules.Rule.Kind.range(min: 0, max: 10),
            .length(min: 3, max: nil),
            .compare(left: "a", op: "<=", right: "b"),
            .expr("a > b"),
            .foreignKey(file: "x.csv", column: "id"),
        ] {
            let tool = QualityFix.tool(for: rule(kind))
            XCTAssertFalse(tool.isAutomatic, "\(kind) không nên tự sửa")
            guard case let .manual(reason) = tool else { return XCTFail("\(kind)") }
            XCTAssertFalse(reason.isEmpty, "\(kind) thiếu lý do")
            XCTAssertFalse(tool.actionTitle.isEmpty, "vẫn phải có chữ trên nút")
        }
    }

    func testLUATKHONGCOCOTThiKhongDoanCot() {
        XCTAssertFalse(
            QualityFix.tool(for: rule(.expr("a > b"), col: nil)).isAutomatic)
        XCTAssertNil(QualityFix.tool(for: rule(.expr("a > b"), col: nil)).column)
    }

    /// "Luật liên quan" gồm cả luật LIÊN CỘT có nhắc tới cột vừa sửa.
    ///
    /// Điền một ô rỗng có thể làm `ngay_giao >= ngay_dat` từ đạt thành trượt; chỉ chấm lại đúng
    /// luật vừa sửa thì bảng hiện một điểm số sai theo hướng đẹp hơn thật.
    func testLUATLIENQUANGomCaLuatLIENCOT() {
        let rules = QualityRules(rules: [
            rule(.notNull(maxNullPercent: 0), col: "ngay_dat"),
            rule(.notNull(maxNullPercent: 0), col: "tinh"),
            QualityRules.Rule(
                column: nil, kind: .compare(left: "ngay_dat", op: "<=", right: "ngay_giao")),
            QualityRules.Rule(column: nil, kind: .expr("ngay_dat IS NOT NULL")),
        ])
        XCTAssertEqual(QualityFix.rulesTouching(column: "ngay_dat", in: rules), [0, 2, 3])
        XCTAssertEqual(QualityFix.rulesTouching(column: "tinh", in: rules), [1])
        XCTAssertEqual(QualityFix.rulesTouching(column: "khong_co", in: rules), [])
    }
}

/// FR-DQR-006 — các GIÁ TRỊ đang vi phạm, để nạp sẵn hộp thay thế.
final class QualityViolatingValuesTests: XCTestCase {

    private let bang = """
        ma_don,tinh
        KH01,Hà Nội
        KH02,Sài Gòn
        KH03,Cần Thơ
        KH04,Sài Gòn

        """

    private func chay(_ yaml: String) throws -> [String] {
        try requireHydratedDuckDB()
        guard DuckDB.isAvailable else { throw XCTSkip("chưa có libduckdb") }
        let rules = try QualityRules.load(fromYAML: yaml)
        return try QualityEngine.violatingValues(
            for: rules.rules[0],
            in: TextBuffer(original: MemoryByteSource(Array(bang.utf8))), dialect: .comma)
    }

    /// Trả về giá trị THẬT, đã khử trùng, xếp thứ tự ổn định.
    ///
    /// Mẫu `regex` trong luật mô tả cái ĐÚNG; muốn tìm cái sai bằng chính nó thì phải bọc một
    /// phủ định lồng nhau — thứ người dùng không đọc được và không sửa được.
    func testINSETRaGiaTriTHATKhongRaMauLuat() throws {
        let values = try chay("""
            rules:
              - col: tinh
                in_set: [Hà Nội, Huế]
            """)
        XCTAssertEqual(values, ["Cần Thơ", "Sài Gòn"], "phải khử trùng và sắp ổn định")
    }

    func testREGEXRaGiaTriKhongKhopMau() throws {
        let values = try chay("""
            rules:
              - col: ma_don
                regex: '^KH0[12]$'
            """)
        XCTAssertEqual(values, ["KH03", "KH04"])
    }

    func testKHONGCOVIPHAMThiRaRONG() throws {
        XCTAssertTrue(try chay("""
            rules:
              - col: ma_don
                regex: '^KH'
            """).isEmpty)
    }

    /// `unique` và `foreign_key` không viết được thành bộ lọc theo hàng, nên chúng ra rỗng ở đây
    /// — và điều đó đúng: công cụ của chúng là khử trùng lặp, không phải thay thế.
    func testLUATKHONGCOBOLOCTHEOHANGThiRaRONG() throws {
        XCTAssertTrue(try chay("""
            rules:
              - col: ma_don
                unique: true
            """).isEmpty)
    }
}
