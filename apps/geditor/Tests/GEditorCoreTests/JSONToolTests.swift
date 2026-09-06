import XCTest
@testable import GEditorCore

/// Công cụ JSON: định dạng, thu gọn, kiểm lỗi, sắp xếp khóa (FR-FMT-504).
final class JSONToolTests: XCTestCase {

    /// Kết quả dạng văn bản. `.unchanged` nghĩa là đầu ra TRÙNG đầu vào — công cụ cố ý không
    /// sinh sửa đổi khi không có gì để đổi, nên ở đây trả lại chính nguồn.
    private func text(of outcome: JSONTool.Outcome, source: String) -> String? {
        switch outcome {
        case let .changed(out): return out
        case .unchanged: return source
        case .invalid: return nil
        }
    }

    private func formatted(_ source: String, indent: Int = 2) -> String? {
        text(of: JSONTool.format(source, indent: indent), source: source)
    }

    private func minified(_ source: String) -> String? {
        text(of: JSONTool.minify(source), source: source)
    }

    // MARK: - Định dạng

    func testFormatsNestedStructures() {
        let source = #"{"ten":"GEditor","cot":[1,2],"sau":{"a":true,"b":null}}"#
        XCTAssertEqual(formatted(source), """
        {
          "ten": "GEditor",
          "cot": [
            1,
            2
          ],
          "sau": {
            "a": true,
            "b": null
          }
        }

        """)
    }

    func testEmptyContainersStayOnOneLine() {
        XCTAssertEqual(formatted(#"{"a":[],"b":{}}"#), """
        {
          "a": [],
          "b": {}
        }

        """)
    }

    func testTabIndent() {
        XCTAssertEqual(formatted(#"{"a":1}"#, indent: 0), "{\n\t\"a\": 1\n}\n")
    }

    /// Định dạng lại một file đã đúng dạng thì KHÔNG sinh sửa đổi nào.
    ///
    /// Nếu không, mỗi lần bấm nút là một khối thay đổi trong Git cho một file không đổi gì.
    func testAlreadyFormattedIsUnchanged() {
        let source = "{\n  \"a\": 1\n}\n"
        XCTAssertEqual(JSONTool.format(source), .unchanged)
    }

    // MARK: - Giữ nguyên dữ liệu

    /// Số giữ NGUYÊN VĂN. Đây là lý do không dùng `JSONSerialization`.
    ///
    /// `1.0` thành `1`, `1e3` thành `1000`, và mã số mười tám chữ số mất chữ số cuối — một
    /// công cụ "định dạng lại" mà đổi dữ liệu là thứ không ai tha thứ được.
    func testNumbersKeepTheirExactText() {
        let source = #"{"a":1.0,"b":1e3,"c":123456789012345678901,"d":-0.5,"e":2.50}"#
        let out = minified(source)
        XCTAssertEqual(out, source)
    }

    /// Thứ tự khóa giữ nguyên như trong file — `Dictionary` thì không hứa điều đó.
    func testKeyOrderIsPreserved() {
        let source = #"{"zeta":1,"alpha":2,"mid":3}"#
        XCTAssertEqual(minified(source), source)
    }

    /// Chuỗi giữ nguyên escape, không bị viết lại theo kiểu khác.
    func testStringsKeepTheirEscapes() {
        let source = #"{"a":"dòng\nmới","b":"é","c":"nháy \" bên trong"}"#
        XCTAssertEqual(minified(source), source)
    }

    // MARK: - Thu gọn

    func testMinifyRemovesAllTheSpace() {
        let source = """
        {
          "ten": "GEditor",
          "cot": [ 1, 2 ]
        }
        """
        XCTAssertEqual(minified(source), #"{"ten":"GEditor","cot":[1,2]}"#)
    }

    /// Định dạng rồi thu gọn phải quay về đúng bản thu gọn ban đầu.
    func testRoundTrip() {
        let compact = #"{"a":[1,{"b":"x"}],"c":true}"#
        guard let pretty = formatted(compact) else { return XCTFail("không định dạng được") }
        XCTAssertEqual(minified(pretty), compact)
    }

    // MARK: - Kiểm lỗi

    func testValidJSONHasNoIssue() {
        XCTAssertNil(JSONTool.validate(#"{"a":[1,2,{"b":null}]}"#))
        XCTAssertNil(JSONTool.validate("[]"))
        XCTAssertNil(JSONTool.validate(#""chỉ một chuỗi""#))
    }

    /// Lỗi phải nói ĐÚNG CHỖ: dòng, cột, và phải sửa gì.
    func testErrorsPointAtTheRightPlace() {
        let source = """
        {
          "a": 1,
          "b": 2
          "c": 3
        }
        """
        guard let issue = JSONTool.validate(source) else { return XCTFail("phải báo lỗi") }
        XCTAssertEqual(issue.line, 4, issue.description)
        XCTAssertTrue(issue.message.contains("dấu phẩy"), issue.message)
    }

    /// Dấu phẩy thừa là lỗi hay gặp nhất khi sửa tay JSON — gọi đúng tên nó ra.
    func testTrailingCommaIsNamed() {
        guard let object = JSONTool.validate(#"{"a":1,}"#) else { return XCTFail("phải báo lỗi") }
        XCTAssertTrue(object.message.contains("Dấu phẩy thừa"), object.message)

        guard let array = JSONTool.validate("[1,2,]") else { return XCTFail("phải báo lỗi") }
        XCTAssertTrue(array.message.contains("Dấu phẩy thừa"), array.message)
    }

    func testOtherCommonMistakes() {
        let cases: [(String, String)] = [
            ("", "rỗng"),
            ("{a:1}", "nháy kép"),
            (#"{"a" 1}"#, "hai chấm"),
            (#"{"a":1} thừa"#, "thừa"),
            (#"{"a":"chưa đóng}"#, "chưa đóng"),
            (#"{"a":01x}"#, "phẩy"),
            (#"{"a":1.}"#, "thập phân"),
            (#"{"a":1e}"#, "mũ"),
        ]
        for (source, hint) in cases {
            guard let issue = JSONTool.validate(source) else {
                return XCTFail("«\(source)» phải báo lỗi")
            }
            XCTAssertTrue(
                issue.message.lowercased().contains(hint.lowercased()),
                "«\(source)» → «\(issue.message)», chờ có chữ «\(hint)»"
            )
        }
    }

    /// Định dạng một file hỏng thì KHÔNG đụng vào nó, chỉ báo lỗi.
    func testFormattingBrokenJSONChangesNothing() {
        guard case let .invalid(issue) = JSONTool.format(#"{"a":1,}"#) else {
            return XCTFail("phải trả về lỗi")
        }
        XCTAssertTrue(issue.message.contains("Dấu phẩy thừa"))
    }

    // MARK: - Sắp xếp khóa

    func testSortsKeysAlphabetically() {
        let source = #"{"zeta":1,"alpha":2,"Mid":3}"#
        guard case let .changed(out) = JSONTool.sortKeys(source, recursive: false) else {
            return XCTFail("phải sắp xếp")
        }
        XCTAssertEqual(out, """
        {
          "alpha": 2,
          "Mid": 3,
          "zeta": 1
        }

        """)
    }

    func testSortsNestedObjectsWhenRecursive() {
        let source = #"{"b":{"z":1,"a":2},"a":3}"#
        guard case let .changed(out) = JSONTool.sortKeys(source) else {
            return XCTFail("phải sắp xếp")
        }
        XCTAssertEqual(minified(out), #"{"a":3,"b":{"a":2,"z":1}}"#)
    }

    /// Mảng KHÔNG bị sắp xếp: thứ tự phần tử là DỮ LIỆU, không phải cách trình bày.
    func testArraysKeepTheirOrder() {
        let source = #"{"a":[3,1,2]}"#
        guard case let .changed(out) = JSONTool.sortKeys(source) else {
            return XCTFail("phải đổi (định dạng lại)")
        }
        XCTAssertEqual(minified(out), source)
    }

    // MARK: - Dữ liệu thật

    /// File JSONL (mỗi dòng một object) KHÔNG phải một tài liệu JSON — phải báo, không nuốt.
    func testJSONLinesIsNotOneDocument() {
        let source = "{\"a\":1}\n{\"a\":2}\n"
        guard let issue = JSONTool.validate(source) else { return XCTFail("phải báo lỗi") }
        XCTAssertTrue(issue.message.contains("thừa"), issue.message)
    }

    func testUnicodeContentSurvives() {
        let source = #"{"tỉnh":"Thừa Thiên Huế","ghi_chú":"đủ dấu"}"#
        XCTAssertEqual(minified(source), source)
    }
}
