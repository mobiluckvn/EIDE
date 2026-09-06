import XCTest
@testable import GEditorCore

/// Column Editor — chèn văn bản, dãy số, dãy ngày vào mọi dòng của khối cột (FR-CORE-003).
final class ColumnEditorTests: XCTestCase {

    // MARK: - Văn bản

    func testFixedTextRepeats() {
        XCTAssertEqual(ColumnEditor.values(.text("• "), count: 3), ["• ", "• ", "• "])
    }

    func testZeroCountGivesNothing() {
        XCTAssertEqual(ColumnEditor.values(.text("x"), count: 0), [])
    }

    // MARK: - Dãy số

    func testDecimalSequence() {
        let values = ColumnEditor.values(
            .number(start: 1, step: 1, radix: .decimal, padding: 0, uppercase: false), count: 4
        )
        XCTAssertEqual(values, ["1", "2", "3", "4"])
    }

    func testStepAndPadding() {
        let values = ColumnEditor.values(
            .number(start: 10, step: 5, radix: .decimal, padding: 4, uppercase: false), count: 3
        )
        XCTAssertEqual(values, ["0010", "0015", "0020"])
    }

    func testHexUppercaseAndLowercase() {
        let upper = ColumnEditor.values(
            .number(start: 250, step: 1, radix: .hexadecimal, padding: 2, uppercase: true), count: 3
        )
        XCTAssertEqual(upper, ["FA", "FB", "FC"])

        let lower = ColumnEditor.values(
            .number(start: 250, step: 1, radix: .hexadecimal, padding: 2, uppercase: false), count: 1
        )
        XCTAssertEqual(lower, ["fa"])
    }

    func testOctalAndBinary() {
        XCTAssertEqual(
            ColumnEditor.values(.number(start: 8, step: 1, radix: .octal, padding: 0, uppercase: false), count: 2),
            ["10", "11"]
        )
        XCTAssertEqual(
            ColumnEditor.values(.number(start: 5, step: 1, radix: .binary, padding: 4, uppercase: false), count: 2),
            ["0101", "0110"]
        )
    }

    /// Số âm: dấu trừ đứng TRƯỚC phần đệm 0, không chen vào giữa.
    func testNegativeNumbersPadCorrectly() {
        let values = ColumnEditor.values(
            .number(start: -2, step: 1, radix: .decimal, padding: 3, uppercase: false), count: 4
        )
        XCTAssertEqual(values, ["-002", "-001", "000", "001"])
    }

    /// Bước ÂM — đếm ngược cũng phải chạy.
    func testNegativeStep() {
        let values = ColumnEditor.values(
            .number(start: 3, step: -1, radix: .decimal, padding: 0, uppercase: false), count: 4
        )
        XCTAssertEqual(values, ["3", "2", "1", "0"])
    }

    /// Số dài hơn ô đệm thì KHÔNG bị cắt — mất chữ số là hỏng dữ liệu.
    func testValueLongerThanPaddingIsNotTruncated() {
        let values = ColumnEditor.values(
            .number(start: 12_345, step: 1, radix: .decimal, padding: 2, uppercase: false), count: 1
        )
        XCTAssertEqual(values, ["12345"])
    }

    // MARK: - Dãy ngày

    func testDateSequence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!

        let values = ColumnEditor.values(
            .date(start: start, stepDays: 1, format: "dd/MM/yyyy"), count: 3, calendar: calendar
        )
        XCTAssertEqual(values, ["30/08/2026", "31/08/2026", "01/09/2026"], "phải qua được ranh giới tháng")
    }

    func testDateStepOfSeveralDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 30))!

        let values = ColumnEditor.values(
            .date(start: start, stepDays: 2, format: "yyyy-MM-dd"), count: 3, calendar: calendar
        )
        XCTAssertEqual(values, ["2026-12-30", "2027-01-01", "2027-01-03"], "phải qua được ranh giới năm")
    }

    // MARK: - Ghép với vùng chọn

    func testInsertingEachValueIntoItsOwnLine() {
        let buffer = TextBuffer(text: "a\nb\nc\n")
        let selection = MultiSelection([0 ..< 0, 2 ..< 2, 4 ..< 4])
        let values = ColumnEditor.values(
            .number(start: 1, step: 1, radix: .decimal, padding: 2, uppercase: false), count: selection.count
        )
        buffer.applyEdits(selection.edits(insertingEach: values), label: "đánh số")
        XCTAssertEqual(buffer.text, "01a\n02b\n03c\n")
    }

    /// FR-CORE-004: đánh số cả nghìn dòng vẫn là MỘT bước undo.
    func testNumberingIsOneUndoStep() {
        let buffer = TextBuffer(text: (0 ..< 1_000).map { "dòng \($0)" }.joined(separator: "\n"))
        let carets = (0 ..< 1_000).map { line -> Range<Int> in
            let offset = buffer.offset(ofLineStart: line)
            return offset ..< offset
        }
        let selection = MultiSelection(carets)
        let values = ColumnEditor.values(
            .number(start: 1, step: 1, radix: .decimal, padding: 4, uppercase: false), count: selection.count
        )
        let before = buffer.text
        let depth = buffer.undoDepth

        buffer.applyEdits(selection.edits(insertingEach: values), label: "đánh số")
        XCTAssertEqual(buffer.undoDepth, depth + 1)
        XCTAssertTrue(buffer.text.hasPrefix("0001dòng 0"))
        XCTAssertTrue(buffer.text.contains("1000dòng 999"))
        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, before)
    }

    /// Thiếu giá trị thì các dòng còn lại KHÔNG bị đụng tới.
    func testFewerValuesThanRangesLeavesRestAlone() {
        let buffer = TextBuffer(text: "a\nb\nc\n")
        let selection = MultiSelection([0 ..< 0, 2 ..< 2, 4 ..< 4])
        buffer.applyEdits(selection.edits(insertingEach: ["X", "Y"]), label: "chèn")
        XCTAssertEqual(buffer.text, "Xa\nYb\nc\n")
    }
}
