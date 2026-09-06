import XCTest
@testable import GEditorCore

final class NumberStyleTests: XCTestCase {

    func testQUYUOCVIET() {
        let style = NumberStyle.vietnamese
        XCTAssertEqual(style.format(1234.56), "1.234,56")
        XCTAssertEqual(style.format(1_234_567), "1.234.567")
        XCTAssertEqual(style.format(999), "999")
        XCTAssertEqual(style.format(1000), "1.000")
        XCTAssertEqual(style.format(0), "0")
    }

    func testQUYUOCANHVaPLAIN() {
        XCTAssertEqual(NumberStyle.english.format(1234.56), "1,234.56")
        XCTAssertEqual(NumberStyle.plain.format(1234.56), "1234.56")
    }

    func testKHONGDoiTheoLOCALECuaMAY() {
        // Đây là cả lý do không dùng `NumberFormatter`: cùng một tài liệu dựng trên hai máy đặt
        // ngôn ngữ khác nhau phải cho ra HAI TỆP GIỐNG HỆT. Bài kiểm này không đổi được locale
        // của tiến trình, nhưng nó chốt rằng kết quả là hằng số chứ không đọc từ đâu khác.
        XCTAssertEqual(NumberStyle.vietnamese.format(1234.5), "1.234,5")
        XCTAssertEqual(NumberStyle.vietnamese.format(1234.5), "1.234,5")
    }

    func testSOAM() {
        // Dấu trừ dài (−, U+2212) chứ không phải gạch nối: trong bảng số, gạch nối trông hệt
        // dấu gạch ngang phân cách và mắt bỏ sót dấu âm.
        XCTAssertEqual(NumberStyle.vietnamese.format(-1234.5), "−1.234,5")
        XCTAssertEqual(NumberStyle.vietnamese.format(-0.5), "−0,5")
    }

    func testSOCHUSOThapPhanTUNHIENThiBoDuoi0() {
        // Một cột có cả 1000 lẫn 12,5: ép hai chữ số thì 1000 thành "1.000,00" (thừa), ép
        // không chữ số thì 12,5 thành "13" (SAI).
        let style = NumberStyle.vietnamese
        XCTAssertEqual(style.format(1000), "1.000")
        XCTAssertEqual(style.format(12.5), "12,5")
        XCTAssertEqual(style.format(12.25), "12,25")
    }

    func testEPSOCHUSOThiCaCotDEUNhau() {
        let style = NumberStyle(decimals: 2)
        XCTAssertEqual(style.format(1000), "1.000,00")
        XCTAssertEqual(style.format(12.5), "12,50")
        XCTAssertEqual(style.format(0.005), "0,01")
    }

    func testLAMTRONTRUOCKhiTachPhanNguyen() {
        // Làm tròn SAU khi tách sẽ cho 1999,95 thành phần nguyên 1999 với phần lẻ "10" —
        // tức "1.999,10", vừa sai vừa không giống bất kỳ con số nào.
        let style = NumberStyle(decimals: 1)
        XCTAssertEqual(style.format(1999.95), "2.000,0")
        XCTAssertEqual(style.format(9.99), "10,0")
    }

    func testSAISOPhayDongKhongLoRaNgoai() {
        // 0,1 + 0,2 = 0,30000000000000004. Không bù sai số thì phần lẻ in ra là "29" hoặc "30"
        // tuỳ hướng cắt.
        XCTAssertEqual(NumberStyle(decimals: 2).format(0.1 + 0.2), "0,30")
        XCTAssertEqual(NumberStyle(decimals: 2).format(2.675), "2,68")
    }

    func testTIENTOVaHAUTO() {
        let style = NumberStyle(decimals: 0, suffix: " ₫")
        XCTAssertEqual(style.format(2_400_000), "2.400.000 ₫")
        XCTAssertEqual(NumberStyle(decimals: 1, suffix: "%").format(12.34), "12,3%")
    }

    func testKHONGHUUHANThiHIENGACHNgang() {
        XCTAssertEqual(NumberStyle.vietnamese.format(.nan), "—")
        XCTAssertEqual(NumberStyle.vietnamese.format(.infinity), "—")
    }

    func testOCHUGIUNGUYEN_KhongEpThanhSo() {
        // Một ô "2.5" trong cột MÃ SẢN PHẨM không được định dạng lại thành "2,5". Nhận diện số
        // theo quy ước MÁY (`1234.56`) vì đó là dạng DuckDB trả về.
        let style = NumberStyle.vietnamese
        XCTAssertEqual(style.formatCell("1234.56"), "1.234,56")
        XCTAssertEqual(style.formatCell("Hà Nội"), "Hà Nội")
        XCTAssertEqual(style.formatCell("2026-08"), "2026-08")
        XCTAssertEqual(style.formatCell(nil), "")
    }

    func testTENQuyUoc() {
        XCTAssertEqual(NumberStyle.named("vi"), .vietnamese)
        XCTAssertEqual(NumberStyle.named("English"), .english)
        XCTAssertEqual(NumberStyle.named("plain"), .plain)
        XCTAssertNil(NumberStyle.named("khong-co"))
    }
}

final class ReportParametersTests: XCTestCase {

    private func frontmatter(_ yaml: String) throws -> YAMLValue {
        try YAMLReader.parse(yaml)
    }

    func testKHAIGONSuyKieuTuGiaTri() throws {
        let declared = try ReportParameters.declared(in: try frontmatter("""
            params:
              thang: "2026-08"
              nguong: 1000
              ten: Hà Nội
            """))
        XCTAssertEqual(declared.count, 3)
        let byName = Dictionary(uniqueKeysWithValues: declared.map { ($0.name, $0) })
        XCTAssertEqual(byName["thang"]?.kind, .date)
        XCTAssertEqual(byName["nguong"]?.kind, .number)
        XCTAssertEqual(byName["ten"]?.kind, .string)
    }

    func testSOTRONVietRaKHONGCoDuoiChamKhong() throws {
        // `default: 1000` phải thành "1000". "1000.0" trong `LIMIT :n` là lỗi cú pháp, và
        // trong `WHERE ma = :n` thì nó không khớp gì cả.
        let declared = try ReportParameters.declared(in: try frontmatter("""
            params:
              n: 1000
            """))
        XCTAssertEqual(declared.first?.defaultValue, "1000")
    }

    func testKHAIDAYDU() throws {
        let declared = try ReportParameters.declared(in: try frontmatter("""
            params:
              nguong:
                type: number
                default: 5000
                label: Ngưỡng doanh thu
            """))
        let parameter = try XCTUnwrap(declared.first)
        XCTAssertEqual(parameter.kind, .number)
        XCTAssertEqual(parameter.defaultValue, "5000")
        XCTAssertEqual(parameter.displayLabel, "Ngưỡng doanh thu")
    }

    func testKIEULaThiBAOLOIKemDanhSachHopLe() {
        XCTAssertThrowsError(try ReportParameters.declared(in: try frontmatter("""
            params:
              x:
                type: mau-sac
                default: đỏ
            """))) { error in
            let message = (error as? ReportParameters.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("string, number, date"), message)
        }
    }

    func testKhongCoParamsThiRong() throws {
        XCTAssertTrue(try ReportParameters.declared(in: try frontmatter("title: x")).isEmpty)
        XCTAssertTrue(try ReportParameters.declared(in: nil).isEmpty)
    }

    func testTHUTUUUTIEN_DongLenhThangTatCa() {
        // Thứ tự ngược lại ("tài liệu biết rõ nhất") phá đúng thứ FR-RPT-006 cần: sinh loạt báo
        // cáo mỗi bộ tham số một tệp. Mặc định thắng thì cả loạt ra cùng một báo cáo, trong im lặng.
        let declared = [
            ReportParameter(name: "thang", kind: .date, defaultValue: "2026-01"),
            ReportParameter(name: "vung", kind: .string, defaultValue: "Bắc"),
        ]
        let values = ReportParameters.resolve(
            declared: declared,
            supplied: ["thang": "2026-06"],
            overrides: ["thang": "2026-08"])
        XCTAssertEqual(values["thang"], "2026-08", "dòng lệnh thắng")
        XCTAssertEqual(values["vung"], "Bắc", "không ai đè thì dùng mặc định")
    }

    func testGIATRIRONGKhongDeLenGiaTriCoSan() {
        // `--param thang=` không được xoá mất mặc định — người dùng gõ thiếu chứ không phải
        // đang khai "rỗng".
        let declared = [ReportParameter(name: "thang", kind: .date, defaultValue: "2026-01")]
        let values = ReportParameters.resolve(
            declared: declared, supplied: [:], overrides: ["thang": ""])
        XCTAssertEqual(values["thang"], "2026-01")
    }

    func testTHIEUGiaTriThiTimRaTrenMOIKhoiQuery() throws {
        // Một báo cáo hay có năm câu dùng chung `:thang`; thiếu giá trị thì cả năm hỏng.
        let document = try ReportDocument.parse("""
            ```query
            SELECT * FROM t WHERE thang = :thang
            ```
            ```query
            SELECT * FROM t WHERE vung = :vung AND thang = :thang
            ```
            """)
        XCTAssertEqual(
            ReportParameters.missing(in: document, values: ["thang": "2026-08"]), ["vung"])
        XCTAssertEqual(
            ReportParameters.missing(in: document, values: [:]), ["thang", "vung"])
    }

    func testDOCThamSoDongLenh() throws {
        let (name, value) = try ReportParameters.parseArgument("thang=2026-08")
        XCTAssertEqual(name, "thang")
        XCTAssertEqual(value, "2026-08")
    }

    func testGIATRICoDauBANGThiKhongBiCatDuoi() throws {
        // Tách ở MỌI dấu bằng sẽ cắt mất phần đuôi trong im lặng.
        let (name, value) = try ReportParameters.parseArgument("loc=a=b=c")
        XCTAssertEqual(name, "loc")
        XCTAssertEqual(value, "a=b=c")
    }

    func testTHAMSODongLenhSaiDangThiNoiRoDangDung() {
        XCTAssertThrowsError(try ReportParameters.parseArgument("thang")) { error in
            let message = (error as? ReportParameters.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("ten=gia_tri"), message)
        }
        XCTAssertThrowsError(try ReportParameters.parseArgument("=2026-08"))
    }

    func testGIATRIDiQuaDungHamBocCuaWorkbench() {
        // Một dấu nháy trong giá trị không được phá câu truy vấn. Không giải lại bài toán ấy —
        // dùng đúng `QueryParameters.substitute` mà Query Workbench dùng, nên một câu chạy đúng
        // ở Workbench thì chạy đúng trong báo cáo.
        let sql = QueryParameters.substitute(
            "SELECT * FROM t WHERE ten = :ten", values: ["ten": "O'Brien"])
        XCTAssertTrue(sql.contains("'O''Brien'"), sql)
    }
}
