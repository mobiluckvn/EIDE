import XCTest
@testable import GEditorCore

/// Bản đồ tài liệu (FR-DOC-306).
final class DocumentMapTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    // MARK: - Hình dáng

    func testEachLineBecomesARowWhenThereIsRoom() {
        let map = DocumentMap(buffer: buffer("a\nbb\nccc\n"), rowCount: 100)
        XCTAssertEqual(map.rows.count, 3)
        XCTAssertEqual(map.rows.map(\.line), [0, 1, 2])
        XCTAssertEqual(map.linesPerRow, 1)
    }

    /// Tài liệu dài hơn số hàng thì mỗi hàng đại diện nhiều dòng, và MẪU PHẢI TRẢI ĐỀU.
    ///
    /// Lấy mẫu dồn về đầu là cách hỏng âm thầm hay gặp: bản đồ vẫn vẽ ra một hình gì đó, nhưng
    /// hai phần ba dưới của tài liệu không hề được nhìn tới.
    func testRowsSampleAcrossTheWholeDocument() {
        let text = (0 ..< 1000).map { "dòng \($0)" }.joined(separator: "\n") + "\n"
        let map = DocumentMap(buffer: buffer(text), rowCount: 50)
        XCTAssertEqual(map.rows.count, 50)
        XCTAssertEqual(map.linesPerRow, 20, accuracy: 0.001)
        XCTAssertLessThan(map.rows[0].line, 20)
        XCTAssertGreaterThan(map.rows[49].line, 970)
        XCTAssertEqual(map.rows.map(\.line), map.rows.map(\.line).sorted())
    }

    func testLongerLinesDrawWiderInk() {
        let map = DocumentMap(buffer: buffer("a\n" + String(repeating: "x", count: 60) + "\n"),
                              rowCount: 10)
        XCTAssertLessThan(map.rows[0].inkEnd, map.rows[1].inkEnd)
    }

    func testIndentPushesInkToTheRight() {
        let map = DocumentMap(buffer: buffer("abc\n        abc\n"), rowCount: 10)
        XCTAssertEqual(map.rows[0].inkStart, 0)
        XCTAssertGreaterThan(map.rows[1].inkStart, 0)
        XCTAssertGreaterThan(map.rows[1].inkEnd, map.rows[1].inkStart)
    }

    func testBlankLinesHaveNoInk() {
        let map = DocumentMap(buffer: buffer("abc\n\nabc\n"), rowCount: 10)
        XCTAssertTrue(map.rows[1].isBlank, "dòng trắng vẫn vẽ ra mực")
    }

    /// Một dòng cực dài KHÔNG được bóp mọi dòng khác thành vô hình.
    func testOneHugeLineDoesNotFlattenTheRest() {
        let text = "abcdefghij\n" + String(repeating: "x", count: 5000) + "\nabcdefghij\n"
        let map = DocumentMap(buffer: buffer(text), rowCount: 10)
        XCTAssertEqual(map.rows[1].inkEnd, 1, "dòng dài phải chạm mép, không hơn")
        XCTAssertGreaterThan(map.rows[0].inkEnd, 0.05, "dòng thường bị bóp gần như vô hình")
    }

    func testTabCountsAsEightColumns() {
        let map = DocumentMap(buffer: buffer("\tabc\n        abc\n"), rowCount: 10)
        XCTAssertEqual(map.rows[0].inkStart, map.rows[1].inkStart, accuracy: 0.0001)
    }

    /// Thụt lề đọc nhiều nhất `maximumIndentProbe` byte — dòng thụt sâu hơn thế cho ra ĐÚNG
    /// mức trần, chứ không đọc cả dòng chỉ để biết nó thụt bao nhiêu.
    func testDeepIndentIsCappedNotRead() {
        let deep = String(repeating: " ", count: 5000) + "x"
        let map = DocumentMap(buffer: buffer(deep + "\n"), rowCount: 10)
        XCTAssertEqual(
            map.rows[0].inkStart,
            Double(DocumentMap.maximumIndentProbe) / DocumentMap.referenceWidth,
            accuracy: 0.0001
        )
    }

    // MARK: - Trường hợp biên

    /// Tài liệu rỗng vẫn là MỘT dòng trắng — bản đồ vẽ ra một hàng không mực, không phải rỗng.
    func testEmptyDocumentIsOneBlankRow() {
        let map = DocumentMap(buffer: buffer(""), rowCount: 100)
        XCTAssertEqual(map.rows.count, 1)
        XCTAssertTrue(map.rows[0].isBlank)
        XCTAssertEqual(map.line(atFraction: 0.5), 0)
    }

    func testZeroRowsAsksForNothing() {
        XCTAssertTrue(DocumentMap(buffer: buffer("a\nb\n"), rowCount: 0).isEmpty)
    }

    // MARK: - Quy đổi

    func testLineAtFractionSpansTheDocument() {
        let text = (0 ..< 100).map { "d\($0)" }.joined(separator: "\n") + "\n"
        let map = DocumentMap(buffer: buffer(text), rowCount: 20)
        XCTAssertEqual(map.line(atFraction: 0), 0)
        XCTAssertEqual(map.line(atFraction: 0.5), 50)
        XCTAssertEqual(map.line(atFraction: 1), map.lineCount - 1)
    }

    /// Bấm hụt ra ngoài bản đồ thì KẸP về biên, không trả về vị trí vô nghĩa.
    func testFractionOutsideIsClamped() {
        let map = DocumentMap(buffer: buffer("a\nb\nc\n"), rowCount: 10)
        XCTAssertEqual(map.line(atFraction: -5), 0)
        XCTAssertEqual(map.line(atFraction: 5), map.lineCount - 1)
    }

    func testViewportRangeMapsToFractions() {
        let text = (0 ..< 100).map { "d\($0)" }.joined(separator: "\n") + "\n"
        let map = DocumentMap(buffer: buffer(text), rowCount: 20)
        let range = map.fractionRange(forLines: 25 ..< 50)
        XCTAssertEqual(range.lowerBound, 0.25, accuracy: 0.01)
        XCTAssertEqual(range.upperBound, 0.5, accuracy: 0.01)
    }

    func testRowForLineRoundTrips() {
        let text = (0 ..< 500).map { "d\($0)" }.joined(separator: "\n") + "\n"
        let map = DocumentMap(buffer: buffer(text), rowCount: 50)
        for line in stride(from: 0, to: 500, by: 37) {
            let row = map.row(forLine: line)
            XCTAssertTrue(map.rows.indices.contains(row))
            XCTAssertLessThan(abs(map.rows[row].line - line), Int(map.linesPerRow) + 1)
        }
    }
}
