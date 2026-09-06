import XCTest
@testable import GEditorCore

/// Bộ đọc tập con YAML cho `.gquality.yaml` (FR-DQR-001).
final class YAMLReaderTests: XCTestCase {

    func testViDuNGUYENVANtrongSRS() throws {
        // Chính ví dụ SRS §3.2.15 in ra cho người dùng đọc. Nếu bộ đọc không đọc nổi ví dụ của
        // đặc tả thì mọi thứ khác không có ý nghĩa gì.
        let value = try YAMLReader.parse("""
            rules: [{col: ma_don, unique: true, severity: error}, \
            {col: doanh_thu, range: {min: 0}}, \
            {expr: "ngay_giao >= ngay_dat", severity: warn}]
            """)
        guard let rules = value["rules"]?.sequenceValue, rules.count == 3 else {
            return XCTFail("không đọc ra 3 luật: \(value)")
        }
        XCTAssertEqual(rules[0]["col"]?.stringValue, "ma_don")
        XCTAssertEqual(rules[0]["unique"]?.boolValue, true)
        XCTAssertEqual(rules[0]["severity"]?.stringValue, "error")
        XCTAssertEqual(rules[1]["range"]?["min"]?.doubleValue, 0)
        // Biểu thức có `>=` KHÔNG được cắt nhầm ở dấu hai chấm nào cả.
        XCTAssertEqual(rules[2]["expr"]?.stringValue, "ngay_giao >= ngay_dat")
    }

    func testDangKHOItheoThutLe() throws {
        let value = try YAMLReader.parse("""
            schemaVersion: 1
            rules:
              - col: ma_don
                unique: true
                severity: error
              - col: doanh_thu
                range:
                  min: 0
                  max: 1000000
            weights:
              completeness: 2
              validity: 1
            """)
        XCTAssertEqual(value["schemaVersion"]?.intValue, 1)
        let rules = value["rules"]?.sequenceValue ?? []
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0]["col"]?.stringValue, "ma_don")
        XCTAssertEqual(rules[1]["range"]?["max"]?.doubleValue, 1_000_000)
        XCTAssertEqual(value["weights"]?["completeness"]?.doubleValue, 2)
    }

    func testChuThichBiBOnhungKHONGboDauThangTrongChuoi() throws {
        let value = try YAMLReader.parse("""
            # cả dòng này là chú thích
            a: 1   # và cả đoạn này
            b: "mau #FF0000"
            """)
        XCTAssertEqual(value["a"]?.intValue, 1)
        // Dấu `#` trong chuỗi là dữ liệu. Cắt nó đi là đổi mã màu thành chuỗi rỗng, im lặng.
        XCTAssertEqual(value["b"]?.stringValue, "mau #FF0000")
    }

    func testChuoiTRONGNHAYgiuNguyenLaCHU() throws {
        let value = try YAMLReader.parse("""
            a: '0912'
            b: 0912
            c: 'true'
            """)
        // `'0912'` là số điện thoại, không phải số 912 — đúng loại nhầm mà mọi bảng tính mắc
        // và người dùng Việt gặp hằng ngày.
        XCTAssertEqual(value["a"]?.stringValue, "0912")
        XCTAssertEqual(value["b"]?.doubleValue, 912)
        XCTAssertEqual(value["c"]?.stringValue, "true")
        XCTAssertNil(value["c"].flatMap { if case .boolean = $0 { return true } else { return nil } })
    }

    func testKhoaTRUNGthiNEMLOIchuKhongGhiDeImLang() throws {
        // Một luật chất lượng bị luật cùng tên phía dưới ghi đè trong im lặng là đúng thứ tệp
        // này sinh ra để chặn.
        XCTAssertThrowsError(try YAMLReader.parse("a: 1\na: 2")) { error in
            guard let failure = error as? YAMLReader.Failure else { return XCTFail() }
            XCTAssertEqual(failure.line, 2)
            XCTAssertTrue(failure.message.contains("hai lần"), failure.message)
        }
    }

    func testNoiKHONGLAMDUOCthiNOIRAkemSoDong() throws {
        for (text, dauHieu) in [
            ("a: |\n  khoi van ban", "khối văn bản"),
            ("---\na: 1", "nhiều tài liệu"),
            ("a: &neo 1", "anchor"),
        ] {
            XCTAssertThrowsError(try YAMLReader.parse(text), text) { error in
                guard let failure = error as? YAMLReader.Failure else { return XCTFail() }
                XCTAssertTrue(failure.reason.contains(dauHieu),
                              "«\(text)» → \(failure.message)")
                XCTAssertGreaterThan(failure.line, 0, "lỗi không có số dòng thì khó sửa")
            }
        }
    }

    func testTepRONGlaMappingRONGchuKhongPhaiLOI() throws {
        XCTAssertEqual(try YAMLReader.parse(""), .mapping([]))
        XCTAssertEqual(try YAMLReader.parse("# chỉ có chú thích\n"), .mapping([]))
    }

    func testDanhSachINLINEvaMotMucDon() throws {
        let value = try YAMLReader.parse("""
            keys: [ma_don, ngay]
            one: ma_don
            """)
        XCTAssertEqual(value["keys"]?.sequenceValue?.compactMap(\.stringValue), ["ma_don", "ngay"])
        // Một mục đơn ở chỗ chờ danh sách: nhận như danh sách một phần tử. Từ chối ở đây chỉ
        // bắt người dùng gõ thêm hai dấu ngoặc mà không bảo vệ gì.
        XCTAssertEqual(value["one"]?.sequenceValue?.compactMap(\.stringValue), ["ma_don"])
    }

    func testThieuDauDongThiNEMLOIchuKhongDocNuaVoi() throws {
        XCTAssertThrowsError(try YAMLReader.parse("a: [1, 2")) { error in
            guard let failure = error as? YAMLReader.Failure else { return XCTFail() }
            XCTAssertTrue(failure.reason.contains("]"), failure.message)
        }
        XCTAssertThrowsError(try YAMLReader.parse("a: {b: 1"))
    }
}
