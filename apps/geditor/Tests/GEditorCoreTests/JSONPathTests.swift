import XCTest
@testable import GEditorCore

/// JSONPath (FR-FMT-504, phần còn nợ).
final class JSONPathTests: XCTestCase {

    private let source = """
    {
      "cua_hang": {
        "sach": [
          { "ten": "Truyện Kiều", "gia": 120000, "co_san": true, "tac_gia": "Nguyễn Du" },
          { "ten": "Số đỏ", "gia": 85000, "co_san": false, "tac_gia": "Vũ Trọng Phụng" },
          { "ten": "Dế Mèn", "gia": 95000, "co_san": true, "tac_gia": "Tô Hoài" }
        ],
        "dia chi": "Hà Nội",
        "so_dien_thoai": null
      },
      "gia": 999
    }
    """

    private func run(_ query: String) throws -> [JSONPath.Match] {
        let bytes = Array(source.utf8)
        let index = JSONIndex(bytes: bytes)
        XCTAssertNil(index.failure)
        return try JSONPath.run(query, on: index, bytes: bytes)
    }

    private func previews(_ query: String) throws -> [String] {
        try run(query).map(\.preview)
    }

    // MARK: - Cơ bản

    func testRootReturnsTheWholeDocument() throws {
        let matches = try run("$")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].path, "$")
        XCTAssertEqual(matches[0].kind, .object)
    }

    func testDottedNames() throws {
        XCTAssertEqual(try previews("$.cua_hang['dia chi']"), ["Hà Nội"])
        XCTAssertEqual(try previews("$.gia"), ["999"])
    }

    func testBracketNamesAcceptBothQuotes() throws {
        XCTAssertEqual(try previews(#"$.cua_hang["dia chi"]"#), ["Hà Nội"])
    }

    func testIndexAndNegativeIndex() throws {
        XCTAssertEqual(try previews("$.cua_hang.sach[0].ten"), ["Truyện Kiều"])
        XCTAssertEqual(try previews("$.cua_hang.sach[-1].ten"), ["Dế Mèn"])
    }

    func testWildcard() throws {
        XCTAssertEqual(try previews("$.cua_hang.sach[*].ten"), ["Truyện Kiều", "Số đỏ", "Dế Mèn"])
        XCTAssertEqual(try previews("$.cua_hang.sach.*.gia"), ["120000", "85000", "95000"])
    }

    func testUnion() throws {
        XCTAssertEqual(try previews("$.cua_hang.sach[0,2].ten"), ["Truyện Kiều", "Dế Mèn"])
        XCTAssertEqual(
            try previews("$.cua_hang.sach[1]['ten','gia']"), ["Số đỏ", "85000"]
        )
    }

    func testSlices() throws {
        XCTAssertEqual(try previews("$.cua_hang.sach[0:2].ten"), ["Truyện Kiều", "Số đỏ"])
        XCTAssertEqual(try previews("$.cua_hang.sach[1:].ten"), ["Số đỏ", "Dế Mèn"])
        XCTAssertEqual(try previews("$.cua_hang.sach[::2].ten"), ["Truyện Kiều", "Dế Mèn"])
    }

    /// Đệ quy phải tìm được `gia` ở CẢ HAI tầng, không chỉ tầng gần nhất.
    func testRecursiveDescent() throws {
        XCTAssertEqual(try previews("$..gia").sorted(), ["120000", "85000", "95000", "999"].sorted())
    }

    func testRecursiveWildcardVisitsEverything() throws {
        let all = try run("$..*")
        // Mọi nút trừ chính gốc.
        let index = JSONIndex(text: source)
        XCTAssertEqual(all.count, index.nodes.count - 1)
    }

    // MARK: - Lọc

    func testFilterOnNumber() throws {
        XCTAssertEqual(
            try previews("$.cua_hang.sach[?(@.gia > 90000)].ten"), ["Truyện Kiều", "Dế Mèn"]
        )
        XCTAssertEqual(try previews("$.cua_hang.sach[?(@.gia <= 85000)].ten"), ["Số đỏ"])
    }

    func testFilterOnString() throws {
        XCTAssertEqual(
            try previews(#"$.cua_hang.sach[?(@.tac_gia == "Tô Hoài")].ten"#), ["Dế Mèn"]
        )
    }

    /// `?(@.co_san)` với `false` là KHÔNG khớp — cùng quy ước với JavaScript.
    func testExistenceFilterTreatsFalseAsAbsent() throws {
        XCTAssertEqual(
            try previews("$.cua_hang.sach[?(@.co_san)].ten"), ["Truyện Kiều", "Dế Mèn"]
        )
    }

    func testFilterAgainstNull() throws {
        XCTAssertEqual(try run("$.cua_hang[?(@ == null)]").count, 1)
    }

    /// So sánh số phải ra SỐ. Nếu so chuỗi thì "9" > "10" và cả bộ lọc giá cho kết quả sai.
    func testNumberComparisonIsNumeric() throws {
        let text = #"{"a":[{"v":9},{"v":10}]}"#
        let bytes = Array(text.utf8)
        let index = JSONIndex(bytes: bytes)
        let matches = try JSONPath.run("$.a[?(@.v > 9)].v", on: index, bytes: bytes)
        XCTAssertEqual(matches.map(\.preview), ["10"])
    }

    /// So sánh chỉ khớp khi KIỂU khớp: chuỗi "85000" không bằng số 85000.
    func testTypeMustMatch() throws {
        let text = #"{"a":[{"v":"85000"},{"v":85000}]}"#
        let bytes = Array(text.utf8)
        let index = JSONIndex(bytes: bytes)
        XCTAssertEqual(
            try JSONPath.run("$.a[?(@.v == 85000)].v", on: index, bytes: bytes).map(\.preview),
            ["85000"]
        )
        XCTAssertEqual(
            try JSONPath.run("$.a[?(@.v == 85000)]", on: index, bytes: bytes).count, 1
        )
    }

    // MARK: - Kết quả nói được mình ở đâu

    func testMatchCarriesPathLineAndRange() throws {
        let matches = try run("$.cua_hang.sach[1].ten")
        XCTAssertEqual(matches.count, 1)
        let match = matches[0]
        XCTAssertEqual(match.path, "$.cua_hang.sach[1].ten")
        XCTAssertEqual(match.line, 5)
        let bytes = Array(source.utf8)
        XCTAssertEqual(String(decoding: bytes[match.range], as: UTF8.self), "\"Số đỏ\"")
    }

    func testResultsAreInDocumentOrderAndUnique() throws {
        let lines = try run("$..ten").map(\.line)
        XCTAssertEqual(lines, lines.sorted())
        XCTAssertEqual(Set(lines).count, lines.count)
    }

    func testContainerPreviewCountsChildren() throws {
        XCTAssertEqual(try previews("$.cua_hang.sach"), ["[ 3 phần tử ]"])
        XCTAssertEqual(try previews("$.cua_hang.sach[0]"), ["{ 4 khóa }"])
    }

    // MARK: - Không khớp KHÁC với truy vấn sai

    func testNoMatchIsEmptyNotAnError() throws {
        XCTAssertTrue(try run("$.khong_co_khoa_nay").isEmpty)
        XCTAssertTrue(try run("$.cua_hang.sach[99]").isEmpty)
        XCTAssertTrue(try run("$.cua_hang.sach[?(@.gia > 999999)]").isEmpty)
    }

    func testSyntaxErrorsSayWhatAndWhere() {
        assertFails("cua_hang", contains: "phải bắt đầu bằng $")
        assertFails("$.", contains: "Thiếu tên khóa")
        assertFails("$.a[", contains: "Thiếu `]`")
        assertFails("$.a[]", contains: "rỗng")
        assertFails("$['a", contains: "Thiếu dấu nháy đóng")
        assertFails("$.a[?(@.b = 1)]", contains: "`==`")
        assertFails("$.a[?(@.b)", contains: "Thiếu `]`")
    }

    /// Cú pháp hợp lệ nhưng chưa làm thì phải NÓI RA, không im lặng trả rỗng.
    func testUnsupportedPartsAreNamed() {
        assertFails("$.a[(@.length-1)]", contains: "biểu thức script")
        assertFails("$.a[?(@.b > 1 && @.c < 2)]", contains: "nhiều điều kiện")
        assertFails("$.a[0:2,4]", contains: "dấu phẩy bên trong lát cắt")
    }

    private func assertFails(_ query: String, contains needle: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        do {
            let matches = try run(query)
            XCTFail("`\(query)` lẽ ra phải lỗi, nhưng trả về \(matches.count) kết quả",
                    file: file, line: line)
        } catch let failure as JSONPath.Failure {
            XCTAssertTrue(
                failure.message.contains(needle),
                "`\(query)` báo `\(failure.message)`, mong đợi có `\(needle)`",
                file: file, line: line
            )
        } catch {
            XCTFail("lỗi lạ: \(error)", file: file, line: line)
        }
    }

    /// Mảng toàn số vô hướng: `@` trỏ vào chính phần tử, không có `.khoa` nào để đi theo.
    ///
    /// Ca này khác hẳn `[?(@.gia > x)]` về đường mã — `follow([])` phải trả về chính nút — và
    /// nó là dạng người ta hay gõ nhất khi lọc một mảng số.
    func testFilterOnBareScalarArray() throws {
        let text = #"{"gia": [120000, 85000, 95000]}"#
        let bytes = Array(text.utf8)
        let index = JSONIndex(bytes: bytes)
        XCTAssertEqual(
            try JSONPath.run("$.gia[?(@ > 90000)]", on: index, bytes: bytes).map(\.preview),
            ["120000", "95000"]
        )
    }

    // MARK: - Bảng dòng

    func testLineTableAgreesWithCounting() {
        let text = "mot\nhai\n\nbon\n"
        let table = LineTable(bytes: Array(text.utf8))
        XCTAssertEqual(table.line(at: 0), 1)
        XCTAssertEqual(table.line(at: 3), 1)      // trước \n của dòng 1
        XCTAssertEqual(table.line(at: 4), 2)
        XCTAssertEqual(table.line(at: 8), 3)      // dòng rỗng
        XCTAssertEqual(table.line(at: 9), 4)
    }
}

