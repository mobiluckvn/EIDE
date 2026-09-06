import XCTest
@testable import GEditorCore

/// Công cụ XML (FR-FMT-505, phần không cần libxml2).
final class XMLToolTests: XCTestCase {

    // MARK: - Kiểm well-formed

    func testWellFormedDocumentPasses() {
        XCTAssertNil(XMLTool.validate("<a><b/></a>"))
        XCTAssertNil(XMLTool.validate("<?xml version=\"1.0\"?>\n<a x=\"1\">chào</a>\n"))
        XCTAssertNil(XMLTool.validate("<!DOCTYPE a><a/>"))
        XCTAssertNil(XMLTool.validate("<a><!-- ghi chú --><b><![CDATA[<không> phải thẻ]]></b></a>"))
    }

    /// Thông báo phải GỌI ĐÚNG TÊN cái sai; đó là cả lý do viết parser tay.
    func testErrorsNameTheActualMistake() {
        assertIssue("<a></b>", contains: "đóng cho `<a>`")
        assertIssue("<a>", contains: "không có `</a>` nào đóng lại")
        assertIssue("</a>", contains: "không có thẻ mở nào đang chờ")
        assertIssue("<a x=1></a>", contains: "phải nằm trong dấu nháy")
        assertIssue("<a x></a>", contains: "thiếu dấu `=`")
        assertIssue("<a x=\"1\" x=\"2\"/>", contains: "viết hai lần")
        assertIssue("<a><!-- chưa đóng </a>", contains: "chú thích")
        assertIssue("<a/><b/>", contains: "2 thẻ gốc")
        assertIssue("", contains: "Không có thẻ nào")
        assertIssue("<1a/>", contains: "phải bắt đầu bằng chữ cái")
        assertIssue("<a x=\"co < trong gia tri\"/>", contains: "`&lt;`")
    }

    /// Lỗi phải chỉ đúng DÒNG, không thì người dùng phải tự dò cả file.
    func testIssueCarriesLineAndColumn() {
        let issue = XMLTool.validate("<a>\n  <b>\n  </c>\n</a>")
        XCTAssertEqual(issue?.line, 3)
        XCTAssertTrue(issue?.message.contains("</c>") == true, issue?.message ?? "")
    }

    /// Thuộc tính trùng tên hỏng ÂM THẦM: bộ đọc nào cũng lấy một trong hai và file vẫn "chạy".
    func testDuplicateAttributeIsAnError() {
        assertIssue("<a ten=\"mot\" ten=\"hai\"/>", contains: "`ten` viết hai lần")
    }

    // MARK: - Định dạng

    func testFormatIndentsElementOnlyContent() {
        let source = "<a><b><c/></b><d/></a>"
        guard case .changed(let result) = XMLTool.format(source) else {
            return XCTFail("mong có thay đổi")
        }
        XCTAssertEqual(result, """
        <a>
          <b>
            <c/>
          </b>
          <d/>
        </a>
        """)
    }

    /// **Nội dung hỗn hợp KHÔNG được đụng vào.** Thụt lại `<p>xin <b>chào</b></p>` là thêm dấu
    /// xuống dòng và dấu cách vào chính câu ấy — cây thẻ vẫn thế nhưng nội dung đã đổi.
    func testMixedContentIsLeftExactlyAsWritten() {
        let source = "<p>xin <b>chào</b> bạn</p>"
        XCTAssertEqual(XMLTool.format(source), .unchanged)

        let nested = "<a><p>xin <b>chào</b></p></a>"
        guard case .changed(let result) = XMLTool.format(nested) else {
            return XCTFail("mong có thay đổi ở tầng ngoài")
        }
        XCTAssertEqual(result, "<a>\n  <p>xin <b>chào</b></p>\n</a>")
    }

    func testFormatKeepsCommentsInstructionsAndCDATA() {
        let source = "<?xml version=\"1.0\"?><a><!--ghi chú--><b><![CDATA[<x>]]></b></a>"
        guard case .changed(let result) = XMLTool.format(source) else {
            return XCTFail("mong có thay đổi")
        }
        XCTAssertTrue(result.contains("<!--ghi chú-->"), result)
        XCTAssertTrue(result.contains("<![CDATA[<x>]]>"), result)
        XCTAssertTrue(result.hasPrefix("<?xml version=\"1.0\"?>"), result)
    }

    /// Nguyên văn thuộc tính phải còn y hệt: kiểu dấu nháy, thứ tự, và cách viết thực thể.
    ///
    /// Đây là thứ `XMLParser` của hệ thống KHÔNG cho: nó trả về nội dung đã giải mã, nên
    /// `&amp;` sẽ thành `&` và `'` thành `"` sau một lần "định dạng lại".
    func testAttributesKeepTheirExactText() {
        let source = "<a ten='Nguyễn' ghi=\"a &amp; b\" so=\"007\"><b/></a>"
        guard case .changed(let result) = XMLTool.format(source) else {
            return XCTFail("mong có thay đổi")
        }
        XCTAssertTrue(result.contains("ten='Nguyễn'"), result)
        XCTAssertTrue(result.contains("ghi=\"a &amp; b\""), result)
        XCTAssertTrue(result.contains("so=\"007\""), result)
    }

    func testFormatIsIdempotent() {
        let source = "<a><b><c/></b></a>"
        guard case .changed(let once) = XMLTool.format(source) else {
            return XCTFail("mong có thay đổi")
        }
        XCTAssertEqual(XMLTool.format(once), .unchanged, "định dạng lần hai lại đổi tiếp")
    }

    func testFormatRejectsBrokenInputInsteadOfGuessing() {
        guard case .invalid(let issue) = XMLTool.format("<a><b></a>") else {
            return XCTFail("file hỏng mà vẫn định dạng")
        }
        XCTAssertTrue(issue.message.contains("đóng cho `<b>`"), issue.message)
    }

    // MARK: - Thu gọn

    func testMinifyDropsWhitespaceBetweenElements() {
        let source = """
        <a>
          <b>
            <c/>
          </b>
        </a>
        """
        XCTAssertEqual(XMLTool.minify(source), .changed("<a><b><c/></b></a>"))
    }

    func testMinifyKeepsTextContent() {
        XCTAssertEqual(XMLTool.minify("<a>  chữ  </a>"), .unchanged)
        XCTAssertEqual(XMLTool.minify("<p>xin <b>chào</b></p>"), .unchanged)
    }

    func testMinifyThenFormatRoundTripsTheTree() {
        let source = "<a>\n  <b x=\"1\"/>\n  <c/>\n</a>"
        guard case .changed(let small) = XMLTool.minify(source),
              case .changed(let big) = XMLTool.format(small) else {
            return XCTFail("một trong hai bước không đổi gì")
        }
        XCTAssertEqual(big, source)
    }

    // MARK: - Tiếng Việt

    func testVietnameseContentSurvives() {
        let source = "<sach><ten>Truyện Kiều</ten><tac_gia>Nguyễn Du</tac_gia></sach>"
        guard case .changed(let result) = XMLTool.format(source) else {
            return XCTFail("mong có thay đổi")
        }
        XCTAssertTrue(result.contains("<ten>Truyện Kiều</ten>"), result)
        XCTAssertEqual(XMLTool.minify(result), .changed(source))
    }

    // MARK: - Phụ

    // MARK: - XPath (FR-FMT-505)

    private let donHang = """
        <don_hang ma="DH-1">
          <hang ma="A1" so_luong="2">Bàn gỗ</hang>
          <hang ma="B2" so_luong="1">Ghế tựa</hang>
        </don_hang>
        """

    func testXPathChonNodeVaThuocTinh() {
        guard case .nodes(let nodes) = XMLTool.evaluateXPath("//hang/@ma", in: donHang) else {
            return XCTFail("không đánh giá được biểu thức")
        }
        XCTAssertEqual(nodes, ["A1", "B2"])
    }

    func testXPathViTuVaHam() {
        guard case .nodes(let thu2) = XMLTool.evaluateXPath("//hang[2]", in: donHang) else {
            return XCTFail("vị từ [2] không chạy")
        }
        XCTAssertEqual(thu2.count, 1)
        XCTAssertTrue(thu2[0].contains("Ghế tựa"), "ra \(thu2)")

        guard case .nodes(let dem) = XMLTool.evaluateXPath("count(//hang)", in: donHang) else {
            return XCTFail("hàm count() không chạy")
        }
        XCTAssertEqual(dem, ["2"])
    }

    /// Chữ tiếng Việt phải qua được cả hai chiều — đây là sản phẩm cho người Việt.
    func testXPathGiuNguyenTiengViet() {
        guard case .nodes(let nodes) =
            XMLTool.evaluateXPath("//hang[@ma='A1']/text()", in: donHang) else {
            return XCTFail("không đánh giá được")
        }
        XCTAssertEqual(nodes, ["Bàn gỗ"])
    }

    /// Tài liệu hỏng thì đổ lỗi cho TÀI LIỆU, không đổ cho biểu thức.
    func testXPathTrenTaiLieuHongNoiDungChoHong() {
        guard case .invalidDocument(let issue) = XMLTool.evaluateXPath("//a", in: "<a><b></a>") else {
            return XCTFail("tài liệu hỏng mà không báo")
        }
        XCTAssertTrue(issue.message.contains("b"), "ra «\(issue.message)»")
    }

    func testXPathSaiCuPhapNoiRa() {
        guard case .badQuery = XMLTool.evaluateXPath("//[[[", in: donHang) else {
            return XCTFail("biểu thức hỏng mà vẫn nhận")
        }
    }

    func testXPathKhongKhopThiRaRong() {
        guard case .nodes(let nodes) = XMLTool.evaluateXPath("//khong_co", in: donHang) else {
            return XCTFail("không đánh giá được")
        }
        XCTAssertTrue(nodes.isEmpty)
    }

    // MARK: - Tự đóng thẻ (FR-FMT-505)

    func testTuDongTheSauKhiGoDauLonHon() {
        XCTAssertEqual(XMLTool.closingTag(afterTyping: "<don_hang>"), "</don_hang>")
        XCTAssertEqual(XMLTool.closingTag(afterTyping: "  <hang ma=\"A1\">"), "</hang>")
        XCTAssertEqual(XMLTool.closingTag(afterTyping: "xin chào <b>"), "</b>")
    }

    /// Bốn ca phải TỪ CHỐI. Mỗi ca là một lần chèn thừa làm hỏng tài liệu.
    func testKhongTuDongTrongBonCa() {
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<br/>"), "thẻ tự đóng")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "</p>"), "chính là thẻ đóng")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<?xml version=\"1.0\"?>"), "khai báo")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<!-- ghi chú -->"), "chú thích")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<!DOCTYPE html>"), "DOCTYPE")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "nếu a > b thì"), "dấu lớn hơn thường")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<>"), "thẻ rỗng")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<1a>"), "tên không hợp lệ")
        XCTAssertNil(XMLTool.closingTag(afterTyping: "<a"), "chưa gõ dấu đóng")
    }

    private func assertIssue(_ text: String, contains needle: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let issue = XMLTool.validate(text) else {
            return XCTFail("`\(text)` lẽ ra phải báo lỗi", file: file, line: line)
        }
        XCTAssertTrue(
            issue.message.contains(needle),
            "`\(text)` báo «\(issue.message)», mong có «\(needle)»",
            file: file, line: line
        )
    }
}
