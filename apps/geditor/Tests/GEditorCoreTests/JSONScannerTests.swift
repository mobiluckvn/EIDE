import XCTest
@testable import GEditorCore

/// FR-KNW-901 · FR-KNW-902 — bộ đọc JSON trên byte.
final class JSONScannerTests: XCTestCase {

    private func validate(_ text: String) -> JSONScanner.Failure? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeBufferPointer { JSONScanner.validate($0) }
    }

    private func fields(_ text: String) -> [JSONScanner.Field]? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeBufferPointer { JSONScanner.topLevelFields($0) }
    }

    private func pretty(_ text: String) -> String? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeBufferPointer { JSONScanner.pretty($0) }
    }

    /// Bộ mẫu dùng chung cho bài đối chiếu. Mỗi mẫu là một dòng JSONL có thể gặp thật.
    static let samples: [String] = [
        // --- hợp lệ ---
        #"{}"#,
        #"{"a":1}"#,
        #"{ "a" : 1 , "b" : "hai" }"#,
        #"{"a":[1,2,3],"b":{"c":null}}"#,
        #"{"a":-0.5e-3}"#,
        #"{"a":0}"#,
        #"{"a":true,"b":false,"c":null}"#,
        #"{"tiếng":"việt có dấu đầy đủ ạ ầ ẫ ỡ ự"}"#,
        #"{"a":"thoát \" và \\ và \/ và \b\f\n\r\t và ạ"}"#,
        #"{"a":""}"#,
        #"[]"#,
        #"[1,2,3]"#,
        #"[{"a":1},{"a":2}]"#,
        #""chuỗi trần""#,
        "123",
        "true",
        "null",
        #"{"a":1e300}"#,
        #"{"a":123456789012345678901234567890}"#,
        #"{"a":"x","a":"y"}"#,                       // khoá TRÙNG — JSON cho phép
        // --- KHÔNG hợp lệ ---
        "",
        "   ",
        #"{"#,
        #"}"#,
        #"{"a"}"#,
        #"{"a":}"#,
        #"{a:1}"#,                                    // khoá không có nháy
        #"{'a':1}"#,                                  // nháy đơn
        #"{"a":01}"#,
        #"{"a":.5}"#,
        #"{"a":+1}"#,
        #"{"a":1.}"#,
        #"{"a":1e}"#,
        #"{"a":NaN}"#,
        #"{"a":Infinity}"#,
        #"{"a":undefined}"#,
        #"{"a":"chưa đóng}"#,
        #"{"a":"sai thoát \q"}"#,
        #"{"a":"\u12"}"#,
        #"{"a":1}rác"#,
        #"{"a":1}{"b":2}"#,
        "{\"a\":\"có ký tự điều khiển \u{01} thô\"}",
        #"// chú thích"#,
        #"{/*chú thích*/"a":1}"#,
        "không phải json",
        #"{"a":1 "b":2}"#,
    ]

    /// Mẫu mà `JSONSerialization` NHẬN còn bộ này TỪ CHỐI — khác biệt CỐ Ý, xem bài kiểm
    /// `testPHAYTHUAThiNghiemHonJSONSerializationCoChuY`.
    static let lenientOnly: [String] = [
        #"{"a":1,}"#,
        #"[1,2,]"#,
        #"{"a":1,"b":2,}"#,
    ]

    /// **Bài kiểm quan trọng nhất của tệp này.** Hai bộ phải cho cùng một phán quyết.
    ///
    /// Một bộ kiểm tra viết tay mà RỘNG TAY hơn `JSONSerialization` sẽ nói "hợp lệ" về bản ghi
    /// mà mọi công cụ hạ nguồn từ chối — và nó nói thế trong im lặng. Chặt tay hơn thì báo lỗi
    /// giả trên dữ liệu tốt, dễ thấy hơn nhưng vẫn sai.
    func testDONGYVoiJSONSerializationTrenMoiMau() {
        for sample in Self.samples {
            let mine = validate(sample) == nil
            let theirs = (try? JSONSerialization.jsonObject(
                with: Data(sample.utf8), options: [.fragmentsAllowed])) != nil
            XCTAssertEqual(mine, theirs,
                           "phán quyết lệch ở mẫu: \(sample.debugDescription)")
        }
    }

    /// Đối chiếu trên dữ liệu SINH RA, không chỉ trên danh sách viết tay.
    ///
    /// Danh sách viết tay chỉ chứa những ca người viết NGHĨ RA. Bộ sinh dưới đây ghép ngẫu
    /// nhiên có gieo cố định từ những mảnh cú pháp — kể cả những mảnh sai — nên nó tạo ra tổ
    /// hợp mà người viết không nghĩ tới.
    func testDONGYVoiJSONSerializationTrenDuLieuSINHRA() {
        var generator = SeededGenerator(seed: 901)
        let pieces = [
            "{", "}", "[", "]", ",", ":", "\"a\"", "\"b\"", "1", "0", "01", "-1", "1.5",
            "1e3", "true", "false", "null", " ", "\"\"", "\"x\"", "\\", "'", "NaN", "\t",
        ]
        var checked = 0
        for _ in 0 ..< 4_000 {
            let length = Int.random(in: 1 ... 9, using: &generator)
            let text = (0 ..< length)
                .map { _ in pieces.randomElement(using: &generator)! }.joined()
            let failure = validate(text)
            let mine = failure == nil
            let theirs = (try? JSONSerialization.jsonObject(
                with: Data(text.utf8), options: [.fragmentsAllowed])) != nil
            if mine != theirs {
                // Chỗ lệch DUY NHẤT được phép: dấu phẩy thừa. Mọi chỗ lệch khác là lỗi.
                XCTAssertTrue(
                    !mine && theirs && (failure?.message.contains("phẩy thừa") ?? false),
                    "phán quyết lệch ngoài chỗ đã biết: \(text.debugDescription) — "
                        + "\(failure?.message ?? "hợp lệ")")
            }
            checked += 1
        }
        XCTAssertEqual(checked, 4_000)
    }

    /// **Khác biệt CỐ Ý với `JSONSerialization`: dấu phẩy thừa.**
    ///
    /// Đây là một tiền đề của tệp này đã bị chính bài kiểm đối chiếu lật ngược. Bản đầu viết ra
    /// với giả định "bộ viết tay chỉ được phép chặt tay hoặc rộng tay so với bộ thật là sai";
    /// hoá ra `JSONSerialization` NHẬN `{"a":1,}` và `[1,2,]`, còn RFC 8259 thì không.
    ///
    /// Chọn NGHIÊM, và chọn có lý do đo được: `json.loads` của Python, `JSON.parse` của
    /// JavaScript và serde của Rust đều từ chối dấu phẩy thừa. Một corpus JSONL được ứng dụng
    /// này chấm "hợp lệ" rồi vỡ ở bước sau trong pipeline của người dùng là hỏng theo hướng
    /// nguy hiểm — im lặng. Báo lỗi trên một dòng mà macOS chấp nhận thì tệ hơn nhưng NHÌN
    /// THẤY được, và người dùng sửa một dấu phẩy là xong.
    func testPHAYTHUAThiNghiemHonJSONSerializationCoChuY() {
        for sample in Self.lenientOnly {
            XCTAssertNotNil(
                (try? JSONSerialization.jsonObject(
                    with: Data(sample.utf8), options: [.fragmentsAllowed])),
                "tiền đề của bài kiểm này là JSONSerialization NHẬN mẫu: \(sample)")
            let failure = validate(sample)
            XCTAssertNotNil(failure, "bộ này phải TỪ CHỐI: \(sample)")
            XCTAssertTrue(failure?.message.contains("phẩy thừa") ?? false,
                          "lý do phải nói rõ là dấu phẩy thừa: \(failure?.message ?? "")")
        }
    }

    /// Lỗi phải nói RA CHỖ, không chỉ nói "sai".
    func testLOINOIRAViTriTrongDong() {
        guard let failure = validate(#"{"a":1,}"#) else {
            return XCTFail("đáng lẽ phải báo lỗi")
        }
        XCTAssertEqual(failure.offset, 7)
        XCTAssertTrue(failure.message.contains("phẩy thừa"), failure.message)

        guard let second = validate(#"{"a":"chưa đóng}"#) else {
            return XCTFail("đáng lẽ phải báo lỗi")
        }
        // Trỏ vào dấu nháy MỞ, không phải cuối dòng: chỗ người dùng cần sửa là chỗ ấy.
        XCTAssertEqual(second.offset, 5)
    }

    /// Lồng quá sâu thì DỪNG và nói ra, không đệ quy tới sập.
    func testLONGQUASAUThiDungChuKhongSap() {
        let deep = String(repeating: "[", count: 5_000) + String(repeating: "]", count: 5_000)
        guard let failure = validate(deep) else { return XCTFail("đáng lẽ phải báo lỗi") }
        XCTAssertTrue(failure.message.contains("lồng sâu"), failure.message)
    }

    // MARK: - Trường mức trên cùng

    func testTRUONGMUCTRENCUNGGiuDungThuTuVaKieu() throws {
        let list = try XCTUnwrap(fields(
            #"{"id":"c1","text":"xin chào","n":12,"ok":true,"meta":{"a":1},"tags":[1],"x":null}"#))
        XCTAssertEqual(list.map(\.name), ["id", "text", "n", "ok", "meta", "tags", "x"])
        XCTAssertEqual(list.map(\.kind),
                       [.string, .string, .number, .boolean, .object, .array, .null])
    }

    /// Dải giá trị trỏ đúng byte — để tô sáng và để lấy chuỗi ra không phải phân tích lại.
    func testDAIGIATRITroDungByte() throws {
        let line = #"{"id":"c1","n":12}"#
        let list = try XCTUnwrap(fields(line))
        let bytes = Array(line.utf8)
        XCTAssertEqual(String(decoding: bytes[list[0].value], as: UTF8.self), "\"c1\"")
        XCTAssertEqual(String(decoding: bytes[list[1].value], as: UTF8.self), "12")
    }

    /// Khoá TRÙNG giữ cả hai — giấu bớt một khoá là giấu đúng thứ đáng ngờ.
    func testKHOATRUNGGiuCaHai() throws {
        let list = try XCTUnwrap(fields(#"{"a":1,"a":2}"#))
        XCTAssertEqual(list.map(\.name), ["a", "a"])
    }

    /// Không phải đối tượng, hoặc không hợp lệ, thì trả `nil` — không đoán.
    func testKHONGPHAIDOITUONGThiNil() {
        XCTAssertNil(fields("[1,2,3]"))
        XCTAssertNil(fields(#"{"a":1,}"#))
        XCTAssertNil(fields(#"{"a":1} thừa"#))
    }

    /// Chỉ lấy trường MỨC TRÊN CÙNG, không đào vào đối tượng lồng.
    func testCHILAYMUCTRENCUNG() throws {
        let list = try XCTUnwrap(fields(#"{"meta":{"nguon":"web","sau":{"x":1}},"id":"c1"}"#))
        XCTAssertEqual(list.map(\.name), ["meta", "id"])
    }

    // MARK: - In đẹp

    func testINDEPGiuNguyenThuTuKhoaVaCachGhiSo() throws {
        let line = #"{"z":1.0,"a":1e3,"m":{"k":[1,2]}}"#
        let text = try XCTUnwrap(pretty(line))
        // Thứ tự khoá GIỮ NGUYÊN như trong tệp — `JSONSerialization` sắp lại theo băm.
        let zIndex = try XCTUnwrap(text.range(of: "\"z\""))
        let aIndex = try XCTUnwrap(text.range(of: "\"a\""))
        XCTAssertLessThan(zIndex.lowerBound, aIndex.lowerBound)
        // Số giữ nguyên CÁCH GHI — `1.0` không thành `1`, `1e3` không thành `1000`.
        XCTAssertTrue(text.contains("1.0"), text)
        XCTAssertTrue(text.contains("1e3"), text)
    }

    /// In đẹp rồi đọc lại phải ra cùng một dữ liệu — bài kiểm vòng tròn.
    func testINDEPRoiDocLaiRaCungDuLieu() throws {
        for sample in Self.samples where validate(sample) == nil {
            let text = try XCTUnwrap(pretty(sample), sample)
            let before = try JSONSerialization.jsonObject(
                with: Data(sample.utf8), options: [.fragmentsAllowed])
            let after = try JSONSerialization.jsonObject(
                with: Data(text.utf8), options: [.fragmentsAllowed])
            XCTAssertEqual(
                NSDictionary(dictionary: ["v": before]), NSDictionary(dictionary: ["v": after]),
                "in đẹp làm đổi dữ liệu ở mẫu: \(sample)")
        }
    }

    func testINDEPTuChoiDongHong() {
        XCTAssertNil(pretty(#"{"a":1,}"#))
    }

    func testDOITUONGRONGVaMANGRONGInGon() throws {
        XCTAssertEqual(try XCTUnwrap(pretty(#"{"a":{},"b":[]}"#)),
                       "{\n  \"a\": {},\n  \"b\": []\n}")
    }
}
