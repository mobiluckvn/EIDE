import XCTest
@testable import GEditorCore

/// FR-MMD-007 — đọc và sửa nhẹ chuỗi SVG.
final class MermaidSVGTests: XCTestCase {

    /// Thẻ gốc CHÉP ĐÚNG từ một tệp mermaid 11.17.2 thật, không gõ lại theo trí nhớ.
    ///
    /// `width="100%"` và `viewBox` mang hai thông tin khác hẳn nhau, và mọi phép tính cỡ ảnh
    /// dựa vào việc phân biệt được chúng.
    private let real = """
        <svg id="g1" width="100%" xmlns="http://www.w3.org/2000/svg" class="flowchart" \
        style="max-width: 133.09375px;" viewBox="0 0 133.09375 363.875" \
        role="graphics-document document" aria-roledescription="flowchart-v2">\
        <style>#g1{font-family:"trebuchet ms";}</style><g class="root"><rect width="10"/></g></svg>
        """

    func testDOCCOTuVIEWBOX() throws {
        let size = try XCTUnwrap(MermaidSVG.size(of: real))
        XCTAssertEqual(size.width, 133.09375, accuracy: 0.0001)
        XCTAssertEqual(size.height, 363.875, accuracy: 0.0001)
    }

    /// Không đọc `width="100%"` thành cỡ — và không lấy nhầm `width` của một thẻ BÊN TRONG.
    func testKHONGLayNHAMWidthCuaTheBenTrong() {
        XCTAssertEqual(MermaidSVG.attribute("width", in: real), "100%")
        // Thẻ `<rect width="10"/>` nằm sau dấu `>` đầu tiên nên không được nhìn tới.
        XCTAssertNotEqual(MermaidSVG.attribute("width", in: real), "10")
    }

    func testKHONGCOVIEWBOXThiTraNIL() {
        XCTAssertNil(MermaidSVG.size(of: "<svg width=\"100\"></svg>"))
        XCTAssertNil(MermaidSVG.size(of: "<svg viewBox=\"0 0 0 0\"></svg>"))
        XCTAssertNil(MermaidSVG.size(of: "không phải svg"))
    }

    /// Cỡ điểm ảnh làm tròn LÊN: làm tròn xuống cắt mất hàng điểm ảnh ở mép, mà với sơ đồ có
    /// viền thì hàng ấy chính là cái viền.
    func testCOANHLamTronLEN() throws {
        let size = try XCTUnwrap(MermaidSVG.size(of: real))
        XCTAssertEqual(size.pixels(scale: 1).width, 134)
        XCTAssertEqual(size.pixels(scale: 1).height, 364)
        XCTAssertEqual(size.pixels(scale: 2).width, 267)
        XCTAssertEqual(size.pixels(scale: 3).height, 1092)
    }

    func testBACHIEULETheoTyLe() {
        let size = MermaidSVG.Size(width: 100, height: 50)
        XCTAssertEqual(size.pixels(scale: 1).width, 100)
        XCTAssertEqual(size.pixels(scale: 2).width, 200)
        XCTAssertEqual(size.pixels(scale: 3).width, 300)
        // Cỡ 0 vẫn phải ra ít nhất 1 điểm ảnh — `NSBitmapImageRep` từ chối cỡ 0.
        XCTAssertEqual(MermaidSVG.Size(width: 0.1, height: 0.1).pixels(scale: 0.001).width, 1)
    }

    /// Nền chèn NGAY SAU thẻ mở, để nó nằm DƯỚI mọi thứ khác.
    ///
    /// SVG vẽ theo thứ tự tài liệu; một hình nền đặt ở cuối sẽ che mất cả sơ đồ.
    func testNENChenNgaySauTheMo() throws {
        let out = MermaidSVG.addingBackground(real, color: "#ffffff")
        let rect = try XCTUnwrap(out.range(of: "<rect x=\"0\" y=\"0\""))
        let style = try XCTUnwrap(out.range(of: "<style>"))
        XCTAssertTrue(rect.lowerBound < style.lowerBound, "nền phải nằm TRƯỚC nội dung")
        XCTAssertTrue(out.contains("width=\"133.0938\""), out.prefix(400).description)
        XCTAssertTrue(out.contains("fill=\"#ffffff\""))
    }

    func testKHONGCOVIEWBOXThiKhongDungVaoSVG() {
        let plain = "<svg></svg>"
        XCTAssertEqual(MermaidSVG.addingBackground(plain, color: "#fff"), plain)
        XCTAssertEqual(MermaidSVG.withExplicitSize(plain), plain)
    }

    /// `width="100%"` phải thành cỡ THẬT khi ghi ra tệp: nếu không, cùng một tệp mở trong
    /// Preview thì vừa màn hình mà dán vào Word thì bé bằng một dòng chữ.
    func testDATCOTHATVaoTheGoc() {
        let out = MermaidSVG.withExplicitSize(real)
        XCTAssertEqual(MermaidSVG.attribute("width", in: out), "133.0938")
        XCTAssertEqual(MermaidSVG.attribute("height", in: out), "363.8750")
        // `viewBox` giữ nguyên — nó là hệ toạ độ, không phải cỡ hiển thị.
        XCTAssertEqual(MermaidSVG.attribute("viewBox", in: out), "0 0 133.09375 363.875")
    }

    func testDATCOTHATCoTyLe() {
        let out = MermaidSVG.withExplicitSize(real, scale: 2)
        XCTAssertEqual(MermaidSVG.attribute("width", in: out), "266.1875")
    }
}

/// FR-MMD-007 — preset màu thương hiệu.
final class MermaidBrandTests: XCTestCase {

    func testGHIVaDOCLai() throws {
        let folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-brand-\(UUID().uuidString)")
        let url = URL(fileURLWithPath: folder).appendingPathComponent("mermaid-brand.json")
        defer { try? FileManager.default.removeItem(atPath: folder) }

        var brand = MermaidBrand()
        brand.name = "Công ty A"
        brand.primaryColor = "#ff8800"
        try brand.save(to: url)
        XCTAssertEqual(MermaidBrand.load(from: url), brand)
    }

    /// Tệp hỏng hoặc thiếu thì rơi về MẶC ĐỊNH — một bộ màu hỏng không được làm mất khả năng
    /// vẽ sơ đồ.
    func testTEPHONGThiRoiVeMacDinh() throws {
        let folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("gq-brand-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("hong.json")
        try "{ không phải JSON".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertEqual(MermaidBrand.load(from: url), .default)
        XCTAssertEqual(
            MermaidBrand.load(from: URL(fileURLWithPath: "/khong/co/that.json")), .default)
    }

    /// `theme: "base"` là BẮT BUỘC trong chỉ thị.
    ///
    /// `themeVariables` chỉ có tác dụng trên theme `base`; đặt `default` rồi thay biến là một
    /// tổ hợp im lặng không làm gì — đúng loại lỗi khiến người dùng nghĩ mình khai sai màu.
    func testCHITHIPhaiDatThemeBase() {
        let directive = MermaidBrand.default.initDirective
        XCTAssertTrue(directive.hasPrefix("%%{init: {\"theme\": \"base\""), directive)
        XCTAssertTrue(directive.hasSuffix("}}%%"), directive)
        XCTAssertTrue(directive.contains("\"primaryColor\""), directive)
    }

    /// Chỉ thị sinh ra phải TẤT ĐỊNH: hai lần sinh cho hai chuỗi giống hệt, nếu không mỗi lần
    /// chèn lại là một dòng khác trong `git diff` dù không ai đổi gì.
    func testCHITHITatDinh() {
        var brand = MermaidBrand()
        brand.primaryColor = "#123456"
        XCTAssertEqual(brand.initDirective, brand.initDirective)
        XCTAssertEqual(
            brand.themeVariables.map(\.key),
            brand.themeVariables.map(\.key).sorted(),
            "khoá phải sắp thứ tự")
    }

    /// Chỉ thị là một dòng, và nó phải PHÂN TÍCH ĐƯỢC như một chỉ thị mermaid — tức
    /// `MermaidDocument.declaration` phải bỏ qua nó và tìm thấy dòng khai báo phía sau.
    func testCHITHIKhongLamMatDongKhaiBao() {
        let source = MermaidBrand.default.initDirective + "\nflowchart TD\n  A --> B"
        XCTAssertEqual(MermaidDocument.declaration(in: source), "flowchart TD")
        XCTAssertEqual(MermaidDocument.wholeFile(source).kind, .flowchart)
    }

    func testDAUNHAYTrongMauDuocThoat() {
        var brand = MermaidBrand()
        brand.fontFamily = "\"Times New Roman\", serif"
        XCTAssertTrue(brand.initDirective.contains("\\\"Times New Roman\\\""),
                      brand.initDirective)
    }
}
