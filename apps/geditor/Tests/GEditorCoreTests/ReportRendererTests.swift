import XCTest
@testable import GEditorCore

final class ChartSpecTests: XCTestCase {

    func testDOCDuMoiKhoa() throws {
        let spec = try ChartSpec.parse("""
            kind: line
            query: SELECT a, b FROM t
            title: Doanh thu
            x_label: Tháng
            y_label: Tiền
            number_format: vi
            decimals: 0
            suffix: " ₫"
            theme: brand
            source: Nguồn — ban-hang.csv
            limit: 500
            """)
        XCTAssertEqual(spec.kind, .line)
        XCTAssertEqual(spec.query, "SELECT a, b FROM t")
        XCTAssertEqual(spec.title, "Doanh thu")
        XCTAssertEqual(spec.xLabel, "Tháng")
        XCTAssertEqual(spec.numberStyle.decimals, 0)
        XCTAssertEqual(spec.numberStyle.suffix, " ₫")
        XCTAssertEqual(spec.palette, .brand)
        XCTAssertEqual(spec.limit, 500)
        XCTAssertEqual(spec.source, "Nguồn — ban-hang.csv")
    }

    func testKHOALAThiBAOLOI_KhongBoQua() {
        // Gõ `titel:` mà bỏ qua thì biểu đồ hiện ra không tiêu đề và người dùng đi tìm lỗi ở
        // chỗ khác. Đây là loại lỗi tốn thời gian nhất trong mọi định dạng cấu hình.
        XCTAssertThrowsError(try ChartSpec.parse("kind: bar\ntitel: X")) { error in
            let message = (error as? ChartSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("«titel»"), message)
            XCTAssertTrue(message.contains("title"), "phải liệt kê khoá đúng: \(message)")
        }
    }

    func testKIEUBieuDoLaThiLietKeCaiCo() {
        XCTAssertThrowsError(try ChartSpec.parse("kind: pie")) { error in
            let message = (error as? ChartSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("bar"), message)
            XCTAssertTrue(message.contains("scatter"), message)
        }
    }

    func testTYPEVaKINDLaMOT() throws {
        XCTAssertEqual(try ChartSpec.parse("type: scatter").kind, .scatter)
    }

    func testTHUAKESTUFrontmatter() throws {
        // Khai lại `number_format` ở từng khối là cách chắc chắn để một khối bị quên và cả
        // trang có hai quy ước số.
        let defaults = try ChartSpec.defaults(from: try YAMLReader.parse("""
            number_format: en
            theme: g-dark
            """))
        let spec = try ChartSpec.parse("kind: bar", inheriting: defaults)
        XCTAssertEqual(spec.numberStyle, .english)
        XCTAssertEqual(spec.palette, .gDark)

        // Nhưng khối vẫn đè được khi nó muốn.
        let overridden = try ChartSpec.parse(
            "kind: bar\nnumber_format: vi", inheriting: defaults)
        XCTAssertEqual(overridden.numberStyle, .vietnamese)
        XCTAssertEqual(overridden.palette, .gDark, "khoá không khai thì vẫn kế thừa")
    }

    func testBIENCuaDecimalsVaLimit() {
        XCTAssertThrowsError(try ChartSpec.parse("decimals: 12"))
        XCTAssertThrowsError(try ChartSpec.parse("limit: 2"))
        XCTAssertNoThrow(try ChartSpec.parse("limit: 3"))
    }

    func testBANGMAUThieuKhaiThiRoiVeMauGoc() {
        // Một theme tuỳ biến chỉ khai ba màu dãy vẫn phải vẽ được trục và lưới.
        let partial = ChartRender.Palette(colours: [.series1: "#123456"])
        XCTAssertEqual(partial.hex(.series1), "#123456")
        XCTAssertEqual(partial.hex(.axis), ChartRender.Ink.axis.hex)
    }
}

final class MarkdownHTMLTests: XCTestCase {

    func testTIEUDEVaDOANVAN() {
        let html = MarkdownHTML.render("# Tiêu đề\n\nMột đoạn.\n\n## Mục con")
        XCTAssertTrue(html.contains("<h1>Tiêu đề</h1>"), html)
        XCTAssertTrue(html.contains("<p>Một đoạn.</p>"), html)
        XCTAssertTrue(html.contains("<h2>Mục con</h2>"), html)
    }

    func testDINHDANGTrongDong() {
        let html = MarkdownHTML.render("**đậm** và *nghiêng* và `mã`")
        XCTAssertTrue(html.contains("<strong>đậm</strong>"), html)
        XCTAssertTrue(html.contains("<em>nghiêng</em>"), html)
        XCTAssertTrue(html.contains("<code>mã</code>"), html)
    }

    func testDAUSAOLeThiGiuNGUYEN() {
        // "2 * 3 = 6" không phải chữ nghiêng bỏ dở. Đoán ý ở đây sẽ nuốt phần còn lại của dòng.
        let html = MarkdownHTML.render("2 * 3 = 6")
        XCTAssertFalse(html.contains("<em>"), html)
        XCTAssertTrue(html.contains("2 * 3 = 6"), html)
    }

    func testMATRONGDONGDiTRUOCDamNghieng() {
        // Một đoạn `a * b` trong dấu nháy ngược chứa dấu sao là phép nhân, không phải nghiêng.
        let html = MarkdownHTML.render("`a * b` xong")
        XCTAssertTrue(html.contains("<code>a * b</code>"), html)
        XCTAssertFalse(html.contains("<em>"), html)
    }

    func testTHOATHTMLTruocKhiChenThe() {
        // Thoát SAU khi chèn thẻ sẽ biến chính `<strong>` vừa chèn thành `&lt;strong&gt;`.
        let html = MarkdownHTML.render("**<script>alert(1)</script>**")
        XCTAssertTrue(html.contains("<strong>&lt;script&gt;"), html)
        XCTAssertFalse(html.contains("<script>"), html)
    }

    func testHTMLTHOKhongChayDuoc() {
        // Báo cáo được CHIA SẺ. Một tài liệu chứa `<script>` không được chạy trên máy người nhận.
        let html = MarkdownHTML.render("<script>alert(1)</script>\n\n<img onerror=x>")
        XCTAssertFalse(html.contains("<script"), html)
        XCTAssertFalse(html.contains("<img"), html)
    }

    func testLIENKETAnToanThiGiuLai() {
        let html = MarkdownHTML.render("[trang](https://example.com) và [tệp](./a.csv)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">trang</a>"), html)
        XCTAssertTrue(html.contains("<a href=\"./a.csv\">tệp</a>"), html)
    }

    func testLIENKETJavascriptBiBO_NhungChuVanCon() {
        // Bỏ liên kết chứ không bỏ chữ: người đọc vẫn thấy đích để tự đánh giá.
        let html = MarkdownHTML.render("[bấm đi](javascript:alert(1))")
        XCTAssertFalse(html.contains("<a href"), html)
        XCTAssertTrue(html.contains("bấm đi"), html)
    }

    func testDANHSACH() {
        let bullets = MarkdownHTML.render("- một\n- hai")
        XCTAssertTrue(bullets.contains("<ul><li>một</li><li>hai</li></ul>"), bullets)
        let ordered = MarkdownHTML.render("1. một\n2. hai")
        XCTAssertTrue(ordered.contains("<ol><li>một</li><li>hai</li></ol>"), ordered)
    }

    func testKHOIMAGiuNguyenVaDuocThoat() {
        let html = MarkdownHTML.render("```sql\nSELECT * FROM t WHERE a < 3\n```")
        XCTAssertTrue(html.contains("<pre><code class=\"lang-sql\">"), html)
        XCTAssertTrue(html.contains("a &lt; 3"), html)
    }

    func testTRICHDANVaDUONGKE() {
        XCTAssertTrue(MarkdownHTML.render("> lời trích").contains("<blockquote>"))
        XCTAssertTrue(MarkdownHTML.render("---").contains("<hr>"))
    }
}

final class ReportRendererTests: XCTestCase {

    private func buffer() -> TextBuffer {
        TextBuffer(text: """
            tinh,doanh_thu
            Hà Nội,1500000
            Huế,900000
            Đà Nẵng,1200000

            """)
    }

    private func render(
        _ text: String, values: [String: String] = [:]
    ) throws -> ReportRenderer.Rendered {
        try ReportRenderer.render(
            try ReportDocument.parse(text), in: buffer(), dialect: .comma,
            options: ReportRenderer.Options(values: values))
    }

    // MARK: - NFR-RPT-01 — cache theo khối

    func testCACHEkhoiTRUNGkhiNGUONkhongDOI_vaTRUOTkhiNGUONdoi() throws {
        // Chỉ tiêu: *"kết quả block được cache theo hash(query + trạng thái nguồn) — chỉ block
        // có nguồn đổi mới chạy lại"*. Vế này KHÔNG có mã cho tới khi có người đo: bộ đo dựng
        // cùng một tài liệu hai lần và thấy lượt hai tốn gần đúng bằng lượt đầu.
        //
        // Hai vế phải kiểm cùng nhau. Chỉ kiểm "trúng cache" thì một hiện thực nhớ SAI — bỏ qua
        // trạng thái nguồn — cũng xanh, và nó trả về số liệu cũ cho một tệp đã đổi. Đó là kiểu
        // hỏng tệ nhất của một công cụ báo cáo: con số trông đúng và không có gì báo là cũ.
        let text = """
            # Báo cáo

            ```query
            SELECT tinh, doanh_thu FROM t ORDER BY doanh_thu DESC
            ```
            """
        let document = try ReportDocument.parse(text)
        let cache = ReportBlockCache()
        let options = ReportRenderer.Options(blockCache: cache)

        let first = try ReportRenderer.render(document, in: buffer(), dialect: .comma,
                                              options: options)
        XCTAssertEqual(cache.hits, 0)
        XCTAssertEqual(cache.misses, 1)
        XCTAssertEqual(first.succeeded, 1)

        // Lượt hai trên CÙNG nguồn: phải trúng, và ra đúng cùng nội dung.
        let second = try ReportRenderer.render(document, in: buffer(), dialect: .comma,
                                               options: options)
        XCTAssertEqual(cache.hits, 1, "cùng câu, cùng nguồn mà không trúng cache")
        XCTAssertEqual(second.html, first.html)

        // Nguồn ĐỔI: phải chạy lại, và ra kết quả MỚI.
        let changed = TextBuffer(text: """
            tinh,doanh_thu
            Hà Nội,1500000
            Huế,900000
            Đà Nẵng,1200000
            Cần Thơ,9999999

            """)
        let third = try ReportRenderer.render(document, in: changed, dialect: .comma,
                                              options: options)
        XCTAssertEqual(cache.hits, 1, "nguồn đã đổi mà vẫn trả kết quả cũ trong bộ nhớ tạm")
        XCTAssertTrue(third.html.contains("Cần Thơ"),
                      "nguồn đổi mà báo cáo vẫn là bản cũ — đúng kiểu hỏng nguy hiểm nhất")
    }

    func testCACHEkhoiPHANbietTHEOthamSO() throws {
        // Cùng một câu truy vấn, hai bộ tham số: nếu khoá băm câu GỐC thay vì câu đã thay tham
        // số thì lượt sinh loạt 63 tỉnh sẽ ra 63 bản sao của tỉnh đầu tiên.
        let document = try ReportDocument.parse("""
            ```query
            SELECT tinh, doanh_thu FROM t WHERE tinh = :tinh
            ```
            """)
        let cache = ReportBlockCache()
        let hue = try ReportRenderer.render(
            document, in: buffer(), dialect: .comma,
            options: ReportRenderer.Options(values: ["tinh": "Huế"], blockCache: cache))
        let hanoi = try ReportRenderer.render(
            document, in: buffer(), dialect: .comma,
            options: ReportRenderer.Options(values: ["tinh": "Hà Nội"], blockCache: cache))

        XCTAssertEqual(cache.hits, 0, "hai bộ tham số khác nhau mà dùng chung một ô nhớ")
        // So theo TÊN TỈNH chứ không theo con số: bảng in số theo quy ước Việt (`1.500.000`),
        // nên dò chuỗi số thô là dò một thứ không có trên trang.
        XCTAssertTrue(hue.html.contains("Huế"))
        XCTAssertFalse(hue.html.contains("Hà Nội"))
        XCTAssertTrue(hanoi.html.contains("Hà Nội"))
        XCTAssertFalse(hanoi.html.contains("Huế"))
    }

    // MARK: - NFR-RPT-02 — kế thừa CHỈ-ĐỌC

    func testDUNGbaoCAOKHONGdungVAOduLIEUnguon_kiemBANGchecksum() throws {
        // Chỉ tiêu viết thẳng cách kiểm: *"Report/Dashboard tuyệt đối không sửa dữ liệu nguồn
        // (kiểm checksum — kế thừa NFR-QRY-03); mọi đầu ra ghi file MỚI"*. Suốt từ khi cụm
        // FR-RPT khép, mục này nằm ở ô "CÓ mã, chưa có phép đo" — tính chất ĐÚNG, nhưng không
        // có gì giữ nó.
        //
        // Kiểm trên CẢ TỆP TRÊN ĐĨA lẫn buffer trong bộ nhớ: DuckDB đọc thẳng tệp nguồn ở vài
        // đường (`sourcePath`), nên một lệnh `COPY … TO` hay một `CREATE TABLE` lọt vào khối
        // ```query sẽ chạm đĩa mà buffer không hay biết.
        let folder = NSTemporaryDirectory() + "rpt02-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let path = folder + "/nguon.csv"
        let csv = """
            tinh,doanh_thu
            Hà Nội,1500000
            Huế,900000
            Đà Nẵng,1200000

            """
        try Data(csv.utf8).write(to: URL(fileURLWithPath: path))

        func checksum() throws -> Int {
            let bytes = try Data(contentsOf: URL(fileURLWithPath: path))
            // Tổng kiểm đơn giản nhưng nhạy với MỌI byte: cộng có trọng số theo vị trí, nên
            // hoán vị hai byte cũng đổi kết quả. Không dùng độ dài — đổi một ô thành giá trị
            // dài bằng cũ thì độ dài không nói gì.
            return bytes.enumerated().reduce(0) { $0 &+ (Int($1.element) &* ($1.offset &+ 1)) }
        }

        let before = try checksum()
        let buffer = TextBuffer(text: csv)
        let beforeBuffer = buffer.text

        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("""
                # Doanh thu

                ```query
                SELECT tinh, doanh_thu FROM t ORDER BY doanh_thu DESC
                ```

                ```chart
                kind: bar
                query: SELECT tinh, doanh_thu FROM t
                title: Theo tỉnh
                ```
                """),
            in: buffer, dialect: .comma)

        XCTAssertFalse(rendered.hasFailures, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 2, "hai khối phải chạy thật, không thì bài này rỗng nghĩa")
        XCTAssertEqual(try checksum(), before, "dựng báo cáo mà TỆP NGUỒN đổi byte")
        XCTAssertEqual(buffer.text, beforeBuffer, "dựng báo cáo mà BUFFER nguồn đổi")
    }

    func testKHOIQUERYRaBangCoSOCanPHAI() throws {
        let rendered = try render("""
            # Báo cáo

            ```query
            SELECT tinh, doanh_thu FROM t ORDER BY doanh_thu DESC
            ```
            """)
        XCTAssertFalse(rendered.hasFailures, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 1)
        XCTAssertTrue(rendered.html.contains("<h1>Báo cáo</h1>"), rendered.html)
        XCTAssertTrue(rendered.html.contains("<th>tinh</th>"), rendered.html)
        // Số theo quy ước Việt và căn PHẢI — cột số căn trái thì hàng nghìn không thẳng cột.
        XCTAssertTrue(rendered.html.contains("<td class=\"num\">1.500.000</td>"), rendered.html)
        XCTAssertTrue(rendered.html.contains("<td class=\"txt\">Hà Nội</td>"), rendered.html)
    }

    func testMOTKHOIHONGThiCacKhoiKIAVANRA() throws {
        // Quyết định lớn nhất của trình kết xuất. Cách hiển nhiên — ném lỗi ra ngoài — biến một
        // báo cáo ba khối có một lỗi chính tả thành màn hình trắng.
        let rendered = try render("""
            ```query
            SELECT tinh FROM t
            ```

            ```query
            SELECT cot_khong_ton_tai FROM t
            ```

            ```query
            SELECT doanh_thu FROM t
            ```
            """)
        XCTAssertEqual(rendered.succeeded, 2, "hai khối lành phải chạy")
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertEqual(rendered.failures[0].blockIndex, 1)
        // Hộp lỗi nằm ĐÚNG CHỖ trong trang, giữa hai bảng.
        //
        // So vị trí trong phần THÂN, không trong cả tệp: chuỗi `g-error` cũng có trong bảng
        // kiểu ở `<head>`, và bản đầu của bài kiểm này bắt trúng chỗ ấy rồi kết luận sai.
        let bodyHTML = try XCTUnwrap(rendered.html.components(separatedBy: "<main>").last)
        let errorAt = try XCTUnwrap(bodyHTML.range(of: "g-error")?.lowerBound)
        let firstTable = try XCTUnwrap(bodyHTML.range(of: "<table>")?.lowerBound)
        let lastTable = try XCTUnwrap(
            bodyHTML.range(of: "<table>", options: .backwards)?.lowerBound)
        XCTAssertLessThan(firstTable, errorAt)
        XCTAssertLessThan(errorAt, lastTable)
    }

    func testHOPLOIKemSODONGDeNhayToi() throws {
        let rendered = try render("""
            văn xuôi

            ```query
            SELECT khong_co FROM t
            ```
            """)
        XCTAssertEqual(rendered.failures.first?.line, 2)
        XCTAssertTrue(rendered.html.contains("dòng 3"), rendered.html)
    }

    func testKHOICHARTKhongCoQueryThiDungKetQuaKhoiTRUOC() throws {
        // Buộc chart mang câu SQL riêng thì một báo cáo "bảng rồi biểu đồ của chính bảng ấy"
        // phải chép câu truy vấn hai lần, và hai bản sẽ lệch nhau.
        let rendered = try render("""
            ```query
            SELECT tinh, doanh_thu FROM t
            ```

            ```chart
            kind: bar
            title: Doanh thu
            ```
            """)
        XCTAssertFalse(rendered.hasFailures, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 2)
        XCTAssertTrue(rendered.html.contains("<svg"), "phải nhúng SVG trong dòng")
        XCTAssertTrue(rendered.html.contains("Doanh thu"), rendered.html)
    }

    func testCHARTKhongCoQueryVaKhongCoKhoiTruocThiNOIRO() throws {
        let rendered = try render("```chart\nkind: bar\n```")
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertTrue(
            rendered.failures[0].message.contains("chưa có khối"), rendered.failures[0].message)
    }

    func testLOIDULIEUCuaChartChiDuongVeKhoiChoMUON() throws {
        // Người dùng sẽ đi sửa khối chart — nơi không có câu SQL nào để sửa — nếu không nói.
        let rendered = try render("""
            ```query
            SELECT tinh FROM t
            ```

            ```chart
            kind: bar
            ```
            """)
        let message = rendered.failures.first?.message ?? ""
        XCTAssertTrue(message.contains("cột SỐ"), message)
        XCTAssertTrue(message.contains("khối query thứ 1"), message)
    }

    func testLOICUPHAPCuaChartKHONGNhacToiKhoiQuery() throws {
        let rendered = try render("""
            ```query
            SELECT tinh, doanh_thu FROM t
            ```

            ```chart
            titel: sai
            ```
            """)
        let message = rendered.failures.first?.message ?? ""
        XCTAssertTrue(message.contains("khoá lạ"), message)
        XCTAssertFalse(message.contains("khối query thứ"), "lỗi cú pháp không liên quan tới nó")
    }

    func testTHAMSOThayVaoTruocKhiChay() throws {
        let rendered = try render("""
            ```query
            SELECT tinh FROM t WHERE tinh = :ten
            ```
            """, values: ["ten": "Huế"])
        XCTAssertFalse(rendered.hasFailures, "\(rendered.failures)")
        XCTAssertTrue(rendered.html.contains("Huế"), rendered.html)
    }

    func testTHIEUTHAMSOThiNOIRoTenNao() throws {
        let rendered = try render("""
            ```query
            SELECT * FROM t WHERE tinh = :ten AND thang = :thang
            ```
            """)
        let message = rendered.failures.first?.message ?? ""
        XCTAssertTrue(message.contains(":ten"), message)
        XCTAssertTrue(message.contains(":thang"), message)
    }

    /// Khối ```mining nay CHẠY (FR-MIN-007) — nên một khoá lạ phải báo đúng lỗi ấy, chứ không
    /// còn báo "chưa hỗ trợ".
    func testKHOIMININGKhoaLa() throws {
        let rendered = try render("```mining\nkind: cluster\n```")
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertTrue(
            rendered.failures[0].message.contains("«kind»"), rendered.failures[0].message)
    }

    /// Khối ```quality nay CHẠY (FR-DQR-003) — nên một khối thiếu `rules_file` phải báo đúng
    /// lỗi ấy, chứ không còn báo "chưa hỗ trợ".
    func testKHOIQUALITYThieuRULESFILE() throws {
        let rendered = try render("```quality\ntitle: x\n```")
        XCTAssertEqual(rendered.failures.count, 1)
        XCTAssertTrue(
            rendered.failures[0].message.contains("rules_file"), rendered.failures[0].message)
    }

    func testHTMLTUCHUA_KhongMotYeuCauMangNao() throws {
        let rendered = try render("""
            ---
            title: Báo cáo tháng 8
            ---
            # Tiêu đề

            ```query
            SELECT tinh, doanh_thu FROM t
            ```

            ```chart
            kind: bar
            ```
            """)
        let html = rendered.html
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<title>Báo cáo tháng 8</title>"), "tiêu đề từ frontmatter")
        XCTAssertTrue(html.contains("<style>"), "CSS phải nội tuyến")
        // Không một tham chiếu ra ngoài nào.
        for forbidden in ["<script", "src=\"http", "href=\"http", "@import", "url(http"] {
            XCTAssertFalse(html.contains(forbidden), "còn «\(forbidden)» trong HTML")
        }
        XCTAssertTrue(html.contains("@media print"), "phải có luật in — FR-DOC-313")
    }

    func testBANGDaiThiCatVaNOIRaLaDaCat() throws {
        var text = "a\n"
        for index in 0..<50 { text += "\(index)\n" }
        let big = TextBuffer(text: text)
        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("```query\nSELECT a FROM t\n```"),
            in: big, dialect: .comma,
            options: ReportRenderer.Options(rowLimit: 10))
        XCTAssertTrue(rendered.html.contains("10 / 50 hàng"), "cắt mà không nói là cắt thì "
            + "người đọc cộng tay ra một tổng khác tổng thật")
    }

    func testQUYUOCSOCuaFrontmatterAnhHuongCaBang() throws {
        let rendered = try render("""
            ---
            number_format: en
            ---
            ```query
            SELECT doanh_thu FROM t
            ```
            """)
        XCTAssertTrue(rendered.html.contains("1,500,000"), rendered.html)
        XCTAssertFalse(rendered.html.contains("1.500.000"), rendered.html)
    }

    func testTATDINH() throws {
        let text = """
            ```query
            SELECT tinh, doanh_thu FROM t
            ```
            ```chart
            kind: bar
            ```
            """
        XCTAssertEqual(try render(text).html, try render(text).html)
    }
}

// MARK: - Tham số trong văn xuôi, và lưới dashboard

final class ReportProseAndGridTests: XCTestCase {

    private func buffer() -> TextBuffer {
        TextBuffer(text: "tinh,doanh_thu\nHà Nội,1500000\nHuế,900000\n")
    }

    func testTHAYThamSoTrongVANXUOI() throws {
        // Một mẫu báo cáo tham số hoá gần như luôn có "Số liệu tháng **:thang**" ở phần mở đầu.
        // In ra nguyên chữ `:thang` giữa một báo cáo gửi đi là hỏng theo cách khó biện minh.
        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("Số liệu tháng **:thang** tại :vung."),
            in: buffer(), dialect: .comma,
            options: ReportRenderer.Options(values: ["thang": "2026-08", "vung": "miền Bắc"]))
        XCTAssertTrue(rendered.html.contains("<strong>2026-08</strong>"), rendered.html)
        XCTAssertTrue(rendered.html.contains("tại miền Bắc"), rendered.html)
    }

    func testCHIThayTenDAKHAI_VanBanKhacGiuNguyen() {
        // Thay mọi thứ trông giống `:tên` sẽ phá `mailto:`, `ghi chú:xyz`, `C:\temp`.
        let values = ["thang": "2026-08"]
        XCTAssertEqual(
            ReportRenderer.substituteInProse("liên hệ mailto:abc@x.vn", values: values),
            "liên hệ mailto:abc@x.vn")
        XCTAssertEqual(
            ReportRenderer.substituteInProse("Ghi chú: xem thêm", values: values),
            "Ghi chú: xem thêm")
        XCTAssertEqual(
            ReportRenderer.substituteInProse("tháng :thang", values: values), "tháng 2026-08")
    }

    func testKHONGDungToiToanTuEPKIEU() {
        // `::` của DuckDB có thể nằm trong một đoạn mã trong dòng của phần văn xuôi.
        XCTAssertEqual(
            ReportRenderer.substituteInProse("doanh_thu::INTEGER", values: ["INTEGER": "X"]),
            "doanh_thu::INTEGER")
    }

    func testKHONGCoThamSoThiTraVeNguyenVan() {
        let text = "một câu có : dấu hai chấm"
        XCTAssertEqual(ReportRenderer.substituteInProse(text, values: [:]), text)
    }

    func testLUOIDashboardTuFrontmatter() throws {
        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("""
                ---
                layout:
                  columns: 2
                ---
                # Bảng điều khiển

                ```query
                SELECT tinh FROM t
                ```
                """),
            in: buffer(), dialect: .comma)
        XCTAssertTrue(rendered.html.contains("grid-template-columns:repeat(2"), rendered.html)
        // Văn xuôi phải TRẢI HẾT chiều ngang — nếu nó cũng chiếm một ô thì tiêu đề mục nằm cạnh
        // một biểu đồ và người đọc không biết tiêu đề ấy nói về khối nào.
        XCTAssertTrue(rendered.html.contains("grid-column: 1 / -1"), rendered.html)
    }

    func testSOCOTBiKEPVeKhoangDocDuoc() {
        XCTAssertEqual(ReportRenderer.columns(from: try? YAMLReader.parse("columns: 12")), 4)
        XCTAssertEqual(ReportRenderer.columns(from: try? YAMLReader.parse("columns: 0")), 1)
        XCTAssertEqual(ReportRenderer.columns(from: nil), 1)
    }

    func testMOTCOTThiKHONGDungLuoi() throws {
        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("# Chỉ một cột"), in: buffer(), dialect: .comma)
        // So trên thẻ `<main>`, không so trên cả tệp: phần CSS của trang cũng có
        // `grid-template-columns` (dải thanh điểm của thẻ chất lượng dùng lưới), nên tìm chuỗi
        // ấy trong cả trang là hỏi một câu khác câu đang cần hỏi.
        XCTAssertTrue(rendered.html.contains("<main>"), rendered.html)
        XCTAssertFalse(rendered.html.contains("<main style="), rendered.html)
    }

    func testDAUVANNguonGhiVaoKetQua() throws {
        // FR-RPT-003: "chỉ báo dữ liệu cũ khi file nguồn đã đổi sau lần render".
        let root = NSTemporaryDirectory() + "geditor-rpt-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = root + "/nguon.csv"
        try "tinh,doanh_thu\nHuế,900000\n".write(toFile: path, atomically: true, encoding: .utf8)

        let rendered = try ReportRenderer.render(
            try ReportDocument.parse("# X"), in: buffer(), dialect: .comma,
            options: ReportRenderer.Options(sourcePath: path))
        XCTAssertNotNil(rendered.sourceFingerprint)
        XCTAssertFalse(rendered.isStale(against: path))

        // Sửa GIỮ NGUYÊN độ dài — chỉ so cỡ file thì lọt.
        try "tinh,doanh_thu\nHue,900000\n ".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertTrue(rendered.isStale(against: path))
    }
}
