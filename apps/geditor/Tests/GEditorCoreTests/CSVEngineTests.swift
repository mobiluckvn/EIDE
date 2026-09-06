import XCTest
@testable import GEditorCore

/// Truy vết: FR-CSV-401 (parser RFC 4180 + auto-detect), FR-CSV-403 (ghi ngược ô).
/// Tương ứng TC-CSV-01/02 trong STP §3.5.
final class CSVEngineTests: XCTestCase {

    private func fields(_ text: String, dialect: CSVDialect = .comma) -> [[String]] {
        let bytes = Array(text.utf8)
        return CSVEngine.parse(bytes, dialect: dialect).map { row in
            row.map { field in
                String(decoding: CSVEngine.unescape(Array(bytes[field.range]), dialect: dialect), as: UTF8.self)
            }
        }
    }

    // MARK: - RFC 4180 edge case (TC-CSV-01)

    func testQuotedFieldContainingDelimiter() {
        let rows = fields("ma,ten\nDH-01,\"Công ty Anh Đào, CN Huế\"\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["DH-01", "Công ty Anh Đào, CN Huế"])
    }

    func testEscapedQuoteInsideQuotedField() {
        let rows = fields("ten\n\"Siêu thị \"\"Bốn Mùa\"\"\"\n")
        XCTAssertEqual(rows[1], ["Siêu thị \"Bốn Mùa\""])
    }

    func testNewlineInsideQuotedFieldKeepsOneLogicalRow() {
        let rows = fields("a,b\n\"dòng 1\ndòng 2\",x\n")
        XCTAssertEqual(rows.count, 2, "xuống dòng trong field bọc KHÔNG tách hàng logic")
        XCTAssertEqual(rows[1], ["dòng 1\ndòng 2", "x"])
    }

    func testLastLineWithoutTrailingNewline() {
        let rows = fields("a,b\n1,2")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["1", "2"])
    }

    func testTrailingDelimiterProducesEmptyField() {
        let rows = fields("a,b,\n")
        XCTAssertEqual(rows[0], ["a", "b", ""])
    }

    func testCRLFRowSeparator() {
        let rows = fields("a,b\r\n1,2\r\n")
        XCTAssertEqual(rows, [["a", "b"], ["1", "2"]])
    }

    // MARK: - Auto-detect delimiter (TC-CSV-02)

    func testDetectComma() {
        let sample = Array("ma,ten,tinh\n1,Anh Đào,Huế\n2,Mai Lan,Đà Nẵng\n".utf8)
        XCTAssertEqual(CSVEngine.detectDialect(sample: sample), .comma)
    }

    func testDetectSemicolonWithCommasInside() {
        // File xuất từ Excel locale VN: phân tách ";" nhưng nội dung có "," — bẫy kinh điển.
        let sample = Array("ma;ten;ghi chu\n1;Anh Đào;a, b, c\n2;Mai Lan;x, y, z\n".utf8)
        XCTAssertEqual(CSVEngine.detectDialect(sample: sample), .semicolon)
    }

    func testDetectTab() {
        let sample = Array("ma\tten\tsl\n1\tA\t10\n2\tB\t20\n".utf8)
        XCTAssertEqual(CSVEngine.detectDialect(sample: sample), .tab)
    }

    // MARK: - Ghi ngược (FR-CSV-403)

    func testEscapeWrapsValuesNeedingQuotes() {
        XCTAssertEqual(CSVEngine.escape("Hà Nội", dialect: .comma), "Hà Nội")
        XCTAssertEqual(CSVEngine.escape("Anh Đào, CN Huế", dialect: .comma), "\"Anh Đào, CN Huế\"")
        XCTAssertEqual(CSVEngine.escape("Bốn \"Mùa\"", dialect: .comma), "\"Bốn \"\"Mùa\"\"\"")
        XCTAssertEqual(CSVEngine.escape("có\nxuống dòng", dialect: .comma), "\"có\nxuống dòng\"")
        XCTAssertEqual(CSVEngine.escape(" đầu dòng", dialect: .comma), "\" đầu dòng\"")
    }

    func testEscapeUnescapeRoundTrip() {
        let values = ["đơn giản", "a,b", "có \"nháy\"", "dòng\nmới", ""]
        for value in values {
            let escaped = CSVEngine.escape(value, dialect: .comma)
            let restored = CSVEngine.unescape(Array(escaped.utf8), dialect: .comma)
            XCTAssertEqual(String(decoding: restored, as: UTF8.self), value)
        }
    }

    /// Màu rainbow gán theo chỉ số cột LOGIC — quoted field không được làm lệch cột.
    func testColumnIndexUnaffectedByQuotedDelimiters() {
        let rows = fields("a,\"x,y,z\",c\n")
        XCTAssertEqual(rows[0].count, 3, "field bọc chứa dấu phẩy vẫn chỉ là MỘT cột")
    }
}
