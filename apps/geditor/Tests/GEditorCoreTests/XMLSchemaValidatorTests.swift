import XCTest
@testable import GEditorCore

/// Kiểm XML theo DTD và XSD (FR-FMT-505, PoC-I).
final class XMLSchemaValidatorTests: XCTestCase {

    private let dtdDocument = """
    <?xml version="1.0"?>
    <!DOCTYPE danhba [
      <!ELEMENT danhba (nguoi+)>
      <!ELEMENT nguoi (ten, tuoi)>
      <!ELEMENT ten (#PCDATA)>
      <!ELEMENT tuoi (#PCDATA)>
    ]>
    <danhba><nguoi><ten>Nguyễn An</ten><tuoi>30</tuoi></nguoi></danhba>
    """

    private let schema = """
    <?xml version="1.0"?>
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
      <xs:element name="nguoi">
        <xs:complexType><xs:sequence>
          <xs:element name="ten" type="xs:string"/>
          <xs:element name="tuoi" type="xs:integer"/>
        </xs:sequence></xs:complexType>
      </xs:element>
    </xs:schema>
    """

    // MARK: - DTD

    func testAcceptsDocumentMatchingItsInlineDTD() {
        XCTAssertEqual(XMLSchemaValidator.validateAgainstInlineDTD(dtdDocument), .valid)
    }

    /// Từ chối, và nói ĐÚNG CHỖ — số dòng là thứ làm danh sách lỗi bấm được.
    func testRejectsDocumentBreakingItsDTDAndSaysWhere() {
        let broken = dtdDocument.replacingOccurrences(
            of: "<tuoi>30</tuoi>", with: "<mau>xanh</mau>")
        guard case let .invalid(issues) = XMLSchemaValidator.validateAgainstInlineDTD(broken) else {
            return XCTFail("phải từ chối")
        }
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.line != nil }, "không lỗi nào có số dòng: \(issues)")
        XCTAssertTrue(
            issues.contains { $0.message.contains("mau") },
            "không nói tên phần tử sai: \(issues.map(\.message))")
    }

    /// **Tài liệu KHÔNG có DTD thì không có gì để vi phạm.**
    ///
    /// Đây là ca dễ trả lời sai theo hướng ngược: bắt mọi file phải có DTD thì công cụ vô dụng
    /// với phần lớn file XML thật.
    func testDocumentWithoutDTDIsValid() {
        XCTAssertEqual(
            XMLSchemaValidator.validateAgainstInlineDTD("<a><b/></a>"), .valid)
    }

    /// XML hỏng cú pháp cũng phải bị từ chối, không được lọt qua thành "hợp lệ".
    func testMalformedXMLIsRejected() {
        guard case .invalid = XMLSchemaValidator.validateAgainstInlineDTD("<a><b></a>") else {
            return XCTFail("XML hỏng mà vẫn nhận")
        }
    }

    // MARK: - XSD

    /// Máy dựng nào cũng phải có libxml2 — nếu một ngày không có thì đây là chỗ báo.
    ///
    /// Cố ý ĐỎ chứ không bỏ qua: mất libxml2 là mất một yêu cầu đã hứa, và ta muốn biết điều
    /// đó từ CI chứ không từ người dùng.
    func testSystemLibXML2IsPresent() {
        XCTAssertTrue(
            XMLSchemaValidator.isXSDAvailable,
            "máy này không có libxml2 — FR-FMT-505 dựa vào thư viện hệ thống, xem PoC-I")
        // Dạng NGƯỜI ĐỌC ĐƯỢC: libxml2 trả "20913", và con số ấy hiện ra cho người dùng thì
        // không nói với ai điều gì.
        let version = XMLSchemaValidator.libraryVersion ?? ""
        XCTAssertTrue(version.contains("."), "phiên bản phải ở dạng x.y.z, nhận \(version)")
    }

    func testAcceptsDocumentMatchingSchema() {
        let outcome = XMLSchemaValidator.validate(
            "<nguoi><ten>An</ten><tuoi>30</tuoi></nguoi>", againstXSD: schema)
        XCTAssertEqual(outcome, .valid)
    }

    func testRejectsDocumentBreakingSchema() {
        let outcome = XMLSchemaValidator.validate(
            "<nguoi><ten>An</ten><tuoi>ba mươi</tuoi></nguoi>", againstXSD: schema)
        guard case let .invalid(issues) = outcome else { return XCTFail("phải từ chối") }
        XCTAssertFalse(issues.isEmpty)
        // Chi tiết lỗi đọc ra từ struct C bằng offset — mong manh theo thiết kế, nên bài kiểm
        // chỉ đòi nó NÓI ĐƯỢC GÌ ĐÓ, không đòi câu chữ chính xác của libxml2.
        XCTAssertFalse(issues[0].message.isEmpty)
        // Đã đo được rằng đường đọc struct C cho ra thông điệp THẬT kèm số dòng (PoC-I), nên
        // bài kiểm đòi đúng thế — nếu một ngày bố cục struct đổi thì chính chỗ này báo.
        XCTAssertTrue(
            issues.contains { $0.message.contains("tuoi") },
            "không nói tên phần tử sai: \(issues.map(\.message))")
    }

    /// Lược đồ SAI là lỗi của người dùng, không phải "không kiểm được" — hai câu trả lời ấy dẫn
    /// người dùng đi hai hướng khác nhau.
    func testBrokenSchemaIsReportedAsInvalidNotUnavailable() {
        let outcome = XMLSchemaValidator.validate("<a/>", againstXSD: "<không phải xsd")
        guard case .invalid = outcome else {
            return XCTFail("lược đồ hỏng phải là .invalid, nhận \(outcome)")
        }
    }

    /// Chữ có dấu đi qua được cả hai đường — sản phẩm này tồn tại vì tiếng Việt.
    func testVietnameseContentSurvivesBothPaths() {
        XCTAssertEqual(XMLSchemaValidator.validateAgainstInlineDTD(dtdDocument), .valid)
        XCTAssertEqual(
            XMLSchemaValidator.validate(
                "<nguoi><ten>Nguyễn Thị Hồng Nhung</ten><tuoi>30</tuoi></nguoi>",
                againstXSD: schema),
            .valid)
    }

    /// Gọi nhiều lần liên tiếp không được để lỗi của lượt trước lẫn sang lượt sau.
    ///
    /// Bộ gom lỗi là `static`, nên đây chính là chỗ nó dễ sai nhất.
    func testRepeatedValidationsDoNotLeakIssuesIntoEachOther() {
        for _ in 0 ..< 3 {
            guard case .invalid = XMLSchemaValidator.validate(
                "<nguoi><ten>An</ten><tuoi>sai</tuoi></nguoi>", againstXSD: schema)
            else { return XCTFail("phải từ chối") }
            XCTAssertEqual(
                XMLSchemaValidator.validate(
                    "<nguoi><ten>An</ten><tuoi>1</tuoi></nguoi>", againstXSD: schema),
                .valid, "lỗi của lượt trước lẫn sang lượt sau")
        }
    }
}
