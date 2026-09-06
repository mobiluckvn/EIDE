import XCTest
@testable import GEditorCore

/// Bộ dựng cây XML — nền cho chế độ View của XML và HTML.
final class XMLIndexTests: XCTestCase {

    private func tree(_ xml: String) -> StructureTree { StructureTree.xml(text: xml) }

    // MARK: - Hình dạng

    func testTHEvaTHUOCtinhVAchuRAdungBAloai() {
        let t = tree(#"<don ma="A1"><khach>Nguyễn An</khach></don>"#)
        XCTAssertNil(t.failure)
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.label, "don")
        XCTAssertEqual(root.kind, .element)

        let con = root.children.map { t.nodes[$0] }
        XCTAssertEqual(con.map(\.label), ["@ma", "khach"],
                       "thuộc tính mang tiền tố @ theo đúng ký hiệu XPath")
        XCTAssertEqual(con[0].kind, .attribute)
        XCTAssertEqual(con[0].detail, "A1")

        let chu = t.nodes[con[1].children[0]]
        XCTAssertEqual(chu.kind, .text)
        XCTAssertEqual(chu.detail, "Nguyễn An")
    }

    func testKHOANGtrangGIUAcacTHEkhongTHANHnut() {
        // Khoảng trắng giữa hai thẻ là định dạng, không phải nội dung. Đưa nó thành nút thì một
        // tài liệu xuống dòng đẹp có số nút chữ nhiều gấp đôi số thẻ.
        let t = tree("<a>\n  <b>x</b>\n  <c/>\n</a>")
        let chu = t.nodes.filter { $0.kind == .text }
        XCTAssertEqual(chu.count, 1, "chỉ có đúng một nút chữ: \(chu.map(\.detail))")
        XCTAssertEqual(chu[0].detail, "x")
    }

    func testTHEtuDONGdongKHONGcoCON() {
        let t = tree(#"<a><b/></a>"#)
        let b = t.nodes[t.nodes[t.roots[0]].children[0]]
        XCTAssertEqual(b.label, "b")
        XCTAssertTrue(b.children.isEmpty)
    }

    // MARK: - Khoảng byte

    func testKHOANGbyteCUAtheBAOtronPHANtu() {
        let xml = #"<a><b>x</b></a>"#
        let bytes = Array(xml.utf8)
        let t = tree(xml)
        let b = t.nodes[t.nodes[t.roots[0]].children[0]]
        XCTAssertEqual(String(decoding: bytes[b.range], as: UTF8.self), "<b>x</b>",
                       "khoảng của thẻ phải bao từ `<` của thẻ mở tới `>` của thẻ đóng")
    }

    func testTENtheTIENGvietDIquaNGUYENven() {
        // Byte tiếp nối UTF-8 luôn ≥ 0x80 nên không bao giờ trùng dấu phân cách ASCII.
        let t = tree("<khách_hàng tỉnh=\"Huế\">Đà Nẵng</khách_hàng>")
        XCTAssertNil(t.failure)
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.label, "khách_hàng")
        XCTAssertEqual(t.nodes[root.children[0]].label, "@tỉnh")
        XCTAssertEqual(t.nodes[root.children[0]].detail, "Huế")
    }

    // MARK: - Bỏ qua phần không phải nội dung

    func testCHUthichVAchiTHIxuLYbiBOqua() {
        let t = tree("<?xml version=\"1.0\"?>\n<!-- ghi chú -->\n<a>x</a>")
        XCTAssertNil(t.failure)
        XCTAssertEqual(t.roots.count, 1)
        XCTAssertEqual(t.nodes[t.roots[0]].label, "a")
    }

    func testCDATAthanhNUTchu() {
        let t = tree("<a><![CDATA[1 < 2 & 3]]></a>")
        XCTAssertNil(t.failure)
        let chu = t.nodes.filter { $0.kind == .text }
        XCTAssertEqual(chu.map(\.detail), ["1 < 2 & 3"],
                       "CDATA phải ra chữ NGUYÊN VĂN, kể cả dấu < bên trong")
    }

    func testDOCTYPEcoKHAIbaoNOIboVANquaDUOC() {
        let t = tree("<!DOCTYPE a [<!ELEMENT a (#PCDATA)>]>\n<a>x</a>")
        XCTAssertNil(t.failure, "\(t.failure ?? "")")
        XCTAssertEqual(t.nodes[t.roots[0]].label, "a")
    }

    // MARK: - Từ chối chứ không dựng nửa vời

    func testTHEkhongDONGthiBAOloi() {
        let t = tree("<a><b>x</a>")
        XCTAssertNotNil(t.failure)
        XCTAssertTrue(t.isEmpty, "đã báo lỗi thì không được trả về nút nào")
    }

    func testTHEdongKHONGkhopNOIraCAhaiTEN() {
        // "Thẻ không khớp" một mình bắt người dùng tự đi tìm cái kia.
        let t = tree("<a><b>x</c></a>")
        guard let failure = t.failure else { return XCTFail("không báo lỗi") }
        XCTAssertTrue(failure.contains("</c>"), failure)
        XCTAssertTrue(failure.contains("<b>"), failure)
    }

    func testTHEdongTHUAbiBAT() {
        let t = tree("<a>x</a></b>")
        XCTAssertNotNil(t.failure)
    }

    func testTEProngKHONGphaiXML() {
        XCTAssertNotNil(tree("").failure)
        XCTAssertNotNil(tree("   \n  ").failure)
    }

    func testTHUOCtinhTHIEUnhayBIbat() {
        XCTAssertNotNil(tree("<a ma=A1></a>").failure)
    }

    // MARK: - Lồng sâu

    func testLONGvaiNGHINtangKHONGlamTRANngamXEP() {
        // `XMLTool.Scanner` đệ quy sẽ chết ở đây; ngăn xếp tường minh thì không.
        let sau = 3000
        let xml = String(repeating: "<a>", count: sau) + "x"
            + String(repeating: "</a>", count: sau)
        let t = tree(xml)
        XCTAssertNil(t.failure, "\(t.failure ?? "")")
        XCTAssertEqual(t.nodes.map(\.depth).max(), sau)
    }
}
