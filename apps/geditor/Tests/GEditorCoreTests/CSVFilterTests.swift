import XCTest
@testable import GEditorCore

/// Lọc tương tác theo cột (FR-QRY-002).
final class CSVFilterTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private var table: TextBuffer {
        document("""
        ma,tinh,doanh_so
        A1,Hà Nội,100
        A2,Huế,250
        A3,Đà Nẵng,
        A4,Hà Nội,900
        A5,N/A,1500

        """)
    }

    private func rows(_ inputs: [(Int, String)]) -> [Int] {
        let conditions = inputs.compactMap { CSVFilter.parse($0.1, column: $0.0) }
        return CSVFilter.rows(matching: conditions, in: table, dialect: .comma).rows
    }

    // MARK: - Đọc cú pháp

    func testParsesTheWholeSyntax() {
        func test(_ raw: String) -> CSVFilterCondition.Test? {
            CSVFilter.parse(raw, column: 0)?.test
        }
        XCTAssertEqual(test("Hà Nội"), .contains("Hà Nội"))
        XCTAssertEqual(test("=Huế"), .equals("Huế"))
        XCTAssertEqual(test("!=Huế"), .notEquals("Huế"))
        XCTAssertEqual(test(">100"), .greater(100))
        XCTAssertEqual(test(">=100"), .greaterOrEqual(100))
        XCTAssertEqual(test("<100"), .less(100))
        XCTAssertEqual(test("<=100"), .lessOrEqual(100))
        XCTAssertEqual(test("100..200"), .between(100, 200))
        XCTAssertEqual(test("200..100"), .between(100, 200), "khoảng ngược vẫn là khoảng ấy")
        XCTAssertEqual(test("a|b|c"), .inList(["a", "b", "c"]))
        XCTAssertEqual(test("null"), .isNull)
        XCTAssertEqual(test("!null"), .isNotNull)
        XCTAssertNil(test("   "), "ô trống không lọc gì")
    }

    /// Ô lọc đọc số theo đúng luật của phần còn lại trong ứng dụng.
    ///
    /// `1.000` đứng một mình đọc được cả hai cách, và cách đọc ấy được chốt theo quy ước
    /// Anh-Mỹ ở mọi nơi — nên `>1.000` là "hơn một phẩy không". Muốn một nghìn thì gõ `>1000`.
    /// Ràng nó vào bài kiểm để không ai lặng lẽ đổi một bên mà quên bên kia.
    func testNumbersFollowTheSameRulesAsTheRestOfTheApp() {
        XCTAssertEqual(CSVFilter.parse(">1000", column: 0)?.test, .greater(1000))
        XCTAssertEqual(CSVFilter.parse(">1.000", column: 0)?.test, .greater(1))
        XCTAssertEqual(CSVFilter.parse(">1,5", column: 0)?.test, .greater(1.5))
        // Ô dữ liệu có CẢ HAI dấu thì không mơ hồ, và so sánh ra đúng như người dùng mong.
        XCTAssertTrue(CSVFilter.matches("1.234,56", .greater(1000)))
    }

    /// `>abc` không phải phép so số — đừng nuốt nó, hãy coi như tìm chuỗi.
    func testNonNumericComparisonFallsBackToText() {
        XCTAssertEqual(CSVFilter.parse(">abc", column: 0)?.test, .contains(">abc"))
    }

    // MARK: - Khớp

    /// Gõ không dấu vẫn ra chữ có dấu — bàn phím đang ở chế độ nào cũng dùng được.
    func testDiacriticInsensitive() {
        XCTAssertTrue(CSVFilter.matches("Huế", .contains("hue")))
        XCTAssertTrue(CSVFilter.matches("Đà Nẵng", .contains("da nang")))
        XCTAssertTrue(CSVFilter.matches("Hà Nội", .equals("ha noi")))
    }

    /// Ô không phải số thì KHÔNG khớp phép so số, và đó không phải lỗi.
    func testNonNumericCellsNeverMatchNumericTests() {
        XCTAssertFalse(CSVFilter.matches("chưa rõ", .greater(0)))
        XCTAssertFalse(CSVFilter.matches("", .less(1000)))
    }

    // MARK: - Lọc cả bảng

    func testFiltersByText() {
        XCTAssertEqual(rows([(1, "Hà Nội")]), [1, 4])
    }

    func testFiltersByNumber() {
        XCTAssertEqual(rows([(2, ">=250")]), [2, 4, 5])
        XCTAssertEqual(rows([(2, "100..900")]), [1, 2, 4])
    }

    func testNullAndNotNull() {
        // Ô rỗng ở hàng 3 và "N/A" ở hàng 5 đều là thiếu.
        XCTAssertEqual(rows([(2, "null")]), [3])
        XCTAssertEqual(rows([(1, "null")]), [5])
        XCTAssertEqual(rows([(1, "!null")]), [1, 2, 3, 4])
    }

    /// Nhiều ô lọc là AND — mỗi ô thu hẹp thêm, đúng như bộ lọc của bảng tính.
    func testMultipleColumnsAreAnded() {
        XCTAssertEqual(rows([(1, "Hà Nội"), (2, ">500")]), [4])
        XCTAssertTrue(rows([(1, "Huế"), (2, ">500")]).isEmpty)
    }

    func testInList() {
        XCTAssertEqual(rows([(1, "Huế|Đà Nẵng")]), [2, 3])
    }

    /// Kết quả nói cả TỔNG, không chỉ số khớp: "3 dòng" và "3 / 1.000.000 dòng" là hai câu
    /// khác hẳn nhau với người đang lọc.
    func testResultReportsTotal() {
        let conditions = [CSVFilter.parse("Hà Nội", column: 1)!]
        let result = CSVFilter.rows(matching: conditions, in: table, dialect: .comma)
        XCTAssertEqual(result.total, 5)
        XCTAssertEqual(result.summary, "2 / 5 dòng khớp")
    }

    /// Hàng ngắn hơn cột đang lọc: ô ấy không tồn tại, và không tồn tại cũng là không có dữ liệu.
    func testShortRowCountsAsMissing() {
        let buffer = document("ma,tinh\nA1,Huế\nA2\n")
        let conditions = [CSVFilter.parse("null", column: 1)!]
        XCTAssertEqual(CSVFilter.rows(matching: conditions, in: buffer, dialect: .comma).rows, [2])
    }

    /// Lọc là cách NHÌN, không phải cách sửa (NFR-QRY-03).
    func testFilteringNeverTouchesTheDocument() {
        let source = table.text
        let buffer = document(source)
        let depth = buffer.undoDepth
        _ = CSVFilter.rows(
            matching: [CSVFilter.parse(">100", column: 2)!], in: buffer, dialect: .comma
        )
        XCTAssertEqual(buffer.text, source)
        XCTAssertEqual(buffer.undoDepth, depth)
    }

    // MARK: - Xuất tập khớp

    /// Kết quả lọc ra tab mới phải là ĐÚNG những dòng ấy của file gốc, kèm hàng tiêu đề.
    func testExtractKeepsHeaderAndRawBytes() throws {
        let buffer = document("ma,tinh\nA1,\"Huế, Việt Nam\"\nA2,Hà Nội\n")
        let matched = CSVFilter.rows(
            matching: [CSVFilter.parse("Huế", column: 1)!], in: buffer, dialect: .comma
        ).rows
        let text = try CSVFilter.extract(rows: matched, from: buffer, dialect: .comma)

        // Dấu bọc giữ nguyên: bóc ra rồi bọc lại sẽ đổi file ở những chỗ người dùng không đụng.
        XCTAssertEqual(text, "ma,tinh\nA1,\"Huế, Việt Nam\"\n")
    }

    func testExtractOfNothingStillKeepsHeader() throws {
        let text = try CSVFilter.extract(rows: [], from: table, dialect: .comma)
        XCTAssertEqual(text, "ma,tinh,doanh_so\n")
    }

    // MARK: - Hủy

    /// Hủy giữa chừng thì kết quả phải NÓI RA là dở dang, không đưa ra một con số nửa vời.
    func testCancelledResultSaysSo() {
        let token = CancelToken()
        token.cancel()
        let result = CSVFilter.rows(
            matching: [CSVFilter.parse("Hà Nội", column: 1)!],
            in: table, dialect: .comma, cancelToken: token
        )
        XCTAssertTrue(result.cancelled)
        XCTAssertTrue(result.summary.contains("dừng giữa chừng"))
    }
}
