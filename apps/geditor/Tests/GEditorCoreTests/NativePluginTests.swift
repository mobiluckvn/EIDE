import XCTest
@testable import GEditorCore

/// Giao thức plugin native chạy ở tiến trình riêng (FR-PLUG-702/703, ADR-12).
final class NativePluginTests: XCTestCase {

    // MARK: - Khung thông điệp trên ống

    /// Đi và về phải ra chính nó.
    func testRoundTripsARequest() throws {
        let request = NativePluginRequest.run(
            command: "hoa-thuong", text: "Nguyễn Đà Nẵng", selection: 3 ..< 9)
        let data = try NativePluginWire.encode(request)
        let decoded = try NativePluginWire.decode(NativePluginRequest.self, from: data)
        XCTAssertEqual(decoded?.value, request)
        XCTAssertEqual(decoded?.consumed, data.count)
    }

    /// **Chưa đủ byte là trạng thái BÌNH THƯỜNG của một ống, không phải lỗi.**
    ///
    /// Đọc một lần trên ống có thể ra nửa thông điệp. Nếu phép giải mã ném lỗi ở đó thì chỗ gọi
    /// buộc phải đoán "lỗi này có nghĩa là chờ thêm hay là hỏng thật" — và đoán sai một trong
    /// hai chiều đều dẫn tới treo hoặc mất thông điệp.
    func testPartialMessageReturnsNilNotError() throws {
        let data = try NativePluginWire.encode(NativePluginRequest.describe)
        for cut in 0 ..< data.count {
            XCTAssertNil(
                try NativePluginWire.decode(NativePluginRequest.self, from: data.prefix(cut)),
                "cắt ở \(cut) byte phải là 'chờ thêm', không phải lỗi")
        }
    }

    /// Hai thông điệp dính nhau trong một lần đọc: phải tách được cái đầu và nói đúng đã tiêu
    /// bao nhiêu byte, để cái thứ hai không mất.
    func testDecodesFirstOfTwoBackToBackMessages() throws {
        var stream = try NativePluginWire.encode(NativePluginRequest.describe)
        let second = NativePluginRequest.run(command: "x", text: "y", selection: nil)
        stream.append(try NativePluginWire.encode(second))

        let first = try XCTUnwrap(
            NativePluginWire.decode(NativePluginRequest.self, from: stream))
        XCTAssertEqual(first.value, .describe)

        let rest = stream.dropFirst(first.consumed)
        let decoded = try NativePluginWire.decode(NativePluginRequest.self, from: Data(rest))
        XCTAssertEqual(decoded?.value, second)
    }

    /// **Đầu kia là mã của NGƯỜI KHÁC.** Một plugin hỏng khai độ dài 4 GB thì app không được
    /// ngồi cấp phát cho tới khi hết bộ nhớ.
    func testRefusesAbsurdlyLargeMessage() {
        var data = Data([0x7F, 0xFF, 0xFF, 0xFF])       // ~2 GB
        data.append(contentsOf: [0x7B, 0x7D])
        XCTAssertThrowsError(
            try NativePluginWire.decode(NativePluginRequest.self, from: data)
        ) { error in
            guard case NativePluginWire.Failure.messageTooLarge = error else {
                return XCTFail("phải là messageTooLarge, nhận \(error)")
            }
        }
    }

    /// JSON hỏng phải là lỗi NÓI RA, không phải một giá trị bịa ra.
    func testMalformedBodyIsReported() throws {
        var data = Data([0, 0, 0, 3])
        data.append(contentsOf: Array("abc".utf8))
        XCTAssertThrowsError(try NativePluginWire.decode(NativePluginRequest.self, from: data)) {
            guard case NativePluginWire.Failure.malformed = $0 else {
                return XCTFail("phải là malformed, nhận \($0)")
            }
        }
    }

    /// Văn bản người dùng chứa đủ mọi ký tự — kể cả `\n`, `}` và ký tự NUL. Khung thông điệp
    /// dùng tiền tố ĐỘ DÀI chính là để những thứ ấy không phá được biên thông điệp.
    func testUserTextWithDelimiterLookalikesSurvives() throws {
        let nasty = "dòng 1\n}{\"giả\":\"json\"}\n\u{0}\tTAB và \u{1F600}\n"
        let request = NativePluginRequest.run(command: "c", text: nasty, selection: nil)
        var stream = try NativePluginWire.encode(request)
        stream.append(try NativePluginWire.encode(NativePluginRequest.describe))

        let first = try XCTUnwrap(NativePluginWire.decode(NativePluginRequest.self, from: stream))
        XCTAssertEqual(first.value, request)
        let rest = Data(stream.dropFirst(first.consumed))
        XCTAssertEqual(try NativePluginWire.decode(NativePluginRequest.self, from: rest)?.value,
                       .describe)
    }

    // MARK: - Bản khai của plugin

    func testAcceptsAMatchingManifest() {
        let manifest = NativePluginManifest(
            name: "Bỏ dấu", version: "1.0", commands: ["bo-dau": "Bỏ dấu tiếng Việt"])
        XCTAssertNil(manifest.incompatibilityReason())
    }

    /// Lời từ chối phải nói ĐỦ để người dùng biết cập nhật cái nào.
    ///
    /// "Không tương thích" là câu vô dụng: người dùng không biết lỗi ở plugin hay ở app, nên
    /// họ không biết phải làm gì. Câu chữ ở đây đi thẳng ra màn hình.
    func testRejectsNewerApiWithAnActionableMessage() {
        let manifest = NativePluginManifest(
            name: "Gói mới", version: "2.0", apiVersion: 3, commands: ["a": "A"])
        let reason = manifest.incompatibilityReason(against: 1)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("3"), "phải nói plugin cần API nào: \(reason!)")
        XCTAssertTrue(reason!.contains("1"), "phải nói app nói API nào: \(reason!)")
        XCTAssertTrue(reason!.contains("Gói mới"), "phải nói TÊN gói: \(reason!)")
    }

    /// Plugin CŨ hơn thì vẫn chạy — thêm trường tuỳ chọn không được phá cái đã cài.
    func testOlderApiIsStillAccepted() {
        let manifest = NativePluginManifest(
            name: "Gói cũ", version: "0.9", apiVersion: 1, commands: ["a": "A"])
        XCTAssertNil(manifest.incompatibilityReason(against: 5))
    }

    func testRejectsManifestWithNoCommands() {
        let manifest = NativePluginManifest(name: "Rỗng", version: "1.0", commands: [:])
        XCTAssertNotNil(manifest.incompatibilityReason())
    }

    /// "Không đổi gì" và "đổi thành chuỗi rỗng" là HAI câu trả lời khác nhau, và phép mã hoá
    /// phải giữ được sự khác nhau ấy — nếu không, một plugin chỉ-xem sẽ đẻ ra một bước hoàn
    /// tác rỗng ở mỗi lần chạy.
    func testNoChangeIsDistinctFromEmptyText() throws {
        for response in [NativePluginResponse.replacement(nil), .replacement("")] {
            let data = try NativePluginWire.encode(response)
            let decoded = try NativePluginWire.decode(NativePluginResponse.self, from: data)
            XCTAssertEqual(decoded?.value, response)
        }
        XCTAssertNotEqual(NativePluginResponse.replacement(nil), .replacement(""))
    }
}
