import XCTest
@testable import GEditorCore

/// Đánh dấu dòng và lọc theo dấu (FR-SRCH-107).
final class LineMarksTests: XCTestCase {

    private let engine = PCRE2SearchEngine()

    private let document = """
    2026-08-20 INFO  khởi động
    2026-08-20 ERROR không mở được /tmp/dữ liệu.csv
    2026-08-20 INFO  đã nạp 1000 dòng
    2026-08-20 ERROR mất kết nối
    2026-08-20 WARN  thử lại
    """ + "\n"

    private func buffer() -> TextBuffer { TextBuffer(text: document) }

    private func apply(_ edits: [TextEdit], to buffer: TextBuffer) -> String {
        buffer.applyEdits(edits, label: "kiểm")
        return buffer.text
    }

    // MARK: - Đánh dấu

    func testMarkAllByPattern() throws {
        let text = buffer()
        let marks = try LineMarks.marking(pattern: "ERROR", in: text, engine: engine)
        XCTAssertEqual(marks.sorted, [1, 3])
    }

    /// Một dòng có nhiều kết quả vẫn chỉ là MỘT dấu.
    func testManyMatchesOnOneLineMakeOneMark() throws {
        let text = TextBuffer(text: "a a a\nb\n")
        let marks = try LineMarks.marking(pattern: "a", in: text, engine: engine)
        XCTAssertEqual(marks.sorted, [0])
    }

    func testMarkVietnameseText() throws {
        let text = buffer()
        let marks = try LineMarks.marking(pattern: "dữ liệu", in: text, engine: engine)
        XCTAssertEqual(marks.sorted, [1])
    }

    /// Regex có lớp Unicode phải chạy được trên chữ có dấu (FR-SRCH-102).
    func testMarkWithUnicodeRegex() throws {
        let text = buffer()
        let marks = try LineMarks.marking(
            pattern: "\\p{L}+ kết nối", in: text, engine: engine,
            options: SearchOptions(mode: .regex)
        )
        XCTAssertEqual(marks.sorted, [3])
    }

    func testInvert() {
        var marks = LineMarkSet([1, 3])
        marks.invert(lineCount: 5)
        XCTAssertEqual(marks.sorted, [0, 2, 4])
    }

    func testToggle() {
        var marks = LineMarkSet()
        marks.toggle(2)
        XCTAssertTrue(marks.contains(2))
        marks.toggle(2)
        XCTAssertFalse(marks.contains(2))
    }

    // MARK: - Lọc

    func testDeleteMarkedLines() throws {
        let text = buffer()
        let marks = try LineMarks.marking(pattern: "ERROR", in: text, engine: engine)
        let result = apply(LineMarks.deleteEdits(marked: marks, in: text), to: text)
        XCTAssertEqual(result, """
        2026-08-20 INFO  khởi động
        2026-08-20 INFO  đã nạp 1000 dòng
        2026-08-20 WARN  thử lại
        """ + "\n")
    }

    /// Remove Unmarked Lines — giữ lại đúng dòng đã đánh dấu.
    func testKeepOnlyMarkedLines() throws {
        let text = buffer()
        let marks = try LineMarks.marking(pattern: "ERROR", in: text, engine: engine)
        let result = apply(LineMarks.keepOnlyEdits(marked: marks, in: text), to: text)
        XCTAssertEqual(result, """
        2026-08-20 ERROR không mở được /tmp/dữ liệu.csv
        2026-08-20 ERROR mất kết nối
        """ + "\n")
    }

    func testCopyMarkedLines() throws {
        let text = buffer()
        let marks = try LineMarks.marking(pattern: "ERROR", in: text, engine: engine)
        XCTAssertEqual(LineMarks.text(of: marks, in: text), """
        2026-08-20 ERROR không mở được /tmp/dữ liệu.csv
        2026-08-20 ERROR mất kết nối
        """ + "\n")
    }

    /// Chép từ file CRLF phải ra CRLF — người dùng dán sang chỗ khác không được lẫn kiểu dòng.
    func testCopyKeepsCRLF() throws {
        let text = TextBuffer(text: "một\r\nhai\r\nba\r\n")
        let marks = LineMarkSet([0, 2])
        XCTAssertEqual(LineMarks.text(of: marks, in: text), "một\r\nba\r\n")
    }

    /// Dòng liền nhau phải gộp thành MỘT edit — xóa 400.000 dòng liền kề không được sinh
    /// 400.000 mảnh trong bước undo.
    func testAdjacentLinesCoalesceIntoOneEdit() {
        let text = TextBuffer(text: (0 ..< 100).map { "dòng \($0)" }.joined(separator: "\n") + "\n")
        let edits = LineMarks.deleteEdits(marked: LineMarkSet(Set(10 ..< 60)), in: text)
        XCTAssertEqual(edits.count, 1)
    }

    // MARK: - Bất biến

    /// FR-CORE-004: lọc theo dấu là MỘT bước undo, dù xóa bao nhiêu dòng.
    func testFilteringIsOneUndoStep() throws {
        let text = buffer()
        // `|` là cú pháp regex — mặc định của SearchOptions là tìm chuỗi THUẦN.
        let marks = try LineMarks.marking(
            pattern: "INFO|WARN", in: text, engine: engine,
            options: SearchOptions(mode: .regex)
        )
        let depth = text.undoDepth
        text.applyEdits(LineMarks.deleteEdits(marked: marks, in: text), label: "Xóa dòng đã đánh dấu")
        XCTAssertEqual(text.undoDepth, depth + 1)
        XCTAssertTrue(text.undo())
        XCTAssertEqual(text.text, document)
    }

    func testEmptyMarksChangeNothing() {
        let text = buffer()
        XCTAssertTrue(LineMarks.deleteEdits(marked: LineMarkSet(), in: text).isEmpty)
    }

    /// Đánh dấu tất cả rồi "giữ lại dòng đã đánh dấu" thì không được đổi gì.
    func testKeepOnlyEverythingIsNoOp() {
        let text = buffer()
        let all = LineMarkSet(Set(0 ..< text.lineCount))
        XCTAssertTrue(LineMarks.keepOnlyEdits(marked: all, in: text).isEmpty)
    }
}
