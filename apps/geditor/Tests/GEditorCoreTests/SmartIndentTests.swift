import XCTest
@testable import GEditorCore

/// Truy vết: FR-CORE-011 tự động thụt lề · FR-CORE-017 lịch sử clipboard.
final class SmartIndentTests: XCTestCase {

    func testInheritsIndentOfCurrentLine() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "    let a = 1", language: .rust), "    ")
        XCTAssertEqual(SmartIndent.indent(afterLine: "không thụt", language: .rust), "")
    }

    func testAddsOneStepAfterOpeningBrace() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "fn main() {", language: .rust), "    ")
        XCTAssertEqual(SmartIndent.indent(afterLine: "    if x {", language: .rust), "        ")
    }

    /// Python mở khối bằng dấu hai chấm cuối dòng, không bằng dấu ngoặc.
    func testPythonOpensBlockWithColon() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "def f():", language: .python), "    ")
        XCTAssertEqual(SmartIndent.indent(afterLine: "  x = 1", language: .python), "  ")
    }

    /// Chú thích đứng sau dấu hai chấm thì dấu ấy vẫn mở khối.
    func testPythonColonBeforeCommentStillOpensBlock() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "if x:  # ghi chú", language: .python), "    ")
    }

    /// Dấu ngoặc KHÔNG mở khối trong Python — `f(` chỉ là lời gọi hàm viết dở.
    func testPythonIgnoresBraces() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "  x = f(", language: .python), "  ")
    }

    /// Văn bản thuần chỉ thừa hưởng thụt lề, không đoán khối.
    func testPlainTextOnlyInherits() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "   danh sách {", language: nil), "   ")
    }

    func testBlankLineGivesNoIndent() {
        XCTAssertEqual(SmartIndent.indent(afterLine: "", language: .rust), "")
        XCTAssertEqual(SmartIndent.indent(afterLine: "      ", language: .rust), "      ")
    }

    // MARK: - TAB và cột

    /// Đo bằng CỘT chứ không bằng số ký tự: một TAB và tám dấu cách trông giống nhau trên màn
    /// hình, và dòng mới phải khớp với thứ NHÌN THẤY.
    func testTabIsMeasuredInColumns() {
        XCTAssertEqual(SmartIndent.width(of: "\t", tabWidth: 8), 8)
        XCTAssertEqual(SmartIndent.width(of: "  \t", tabWidth: 8), 8, "TAB nở tới nấc kế tiếp")
        XCTAssertEqual(SmartIndent.width(of: "\t  ", tabWidth: 8), 10)
    }

    func testIndentWithTabsUsesTabs() {
        let result = SmartIndent.indent(
            afterLine: "\tif x {", language: .rust, usesTabs: true, tabWidth: 4, step: 4
        )
        XCTAssertEqual(result, "\t\t")
    }

    /// Cột lẻ đệm bằng dấu cách: một TAB không chia nhỏ được, và làm tròn lên sẽ đẩy dòng mới
    /// thụt sâu hơn dòng nó đang theo.
    func testOddColumnsPadWithSpaces() {
        let result = SmartIndent.indent(
            afterLine: "  if x {", language: .rust, usesTabs: true, tabWidth: 4, step: 4
        )
        XCTAssertEqual(result, "\t  ", "6 cột = một TAB 4 cột + hai dấu cách")
    }

    // MARK: - Lịch sử clipboard (FR-CORE-017)

    func testRingKeepsMostRecentFirst() {
        var ring = ClipboardRing()
        ring.record("một")
        ring.record("hai")
        XCTAssertEqual(ring.entries, ["hai", "một"])
    }

    /// Chép lại cùng một đoạn phải NÂNG LÊN đầu, không sinh bản thứ hai.
    func testRecordingSameTextMovesItToFront() {
        var ring = ClipboardRing()
        ring.record("a")
        ring.record("b")
        ring.record("a")
        XCTAssertEqual(ring.entries, ["a", "b"])
    }

    func testRingIsBounded() {
        var ring = ClipboardRing()
        for index in 0 ..< (ClipboardRing.capacity + 10) { ring.record("mục \(index)") }
        XCTAssertEqual(ring.entries.count, ClipboardRing.capacity)
        XCTAssertEqual(ring.entries.first, "mục \(ClipboardRing.capacity + 9)")
    }

    /// Chép cả một file lớn rồi chép tiếp thứ khác thì phần lớn ấy không được nằm lại trong RAM.
    func testOversizedEntryIsNotKept() {
        var ring = ClipboardRing()
        ring.record(String(repeating: "x", count: ClipboardRing.entryLimit + 1))
        XCTAssertTrue(ring.isEmpty, "mục quá trần vẫn dán được từ clipboard hệ điều hành")
    }

    func testEmptyTextIsNotRecorded() {
        var ring = ClipboardRing()
        ring.record("")
        XCTAssertTrue(ring.isEmpty)
    }

    /// Nhãn phải phân biệt được hai mục khác nhau, và không phá bố cục menu.
    func testLabelFlattensNewlines() {
        XCTAssertEqual(ClipboardRing.label(for: "a\nb"), "a⏎b")
        XCTAssertEqual(ClipboardRing.label(for: "a\tb"), "a⇥b")
        XCTAssertTrue(ClipboardRing.label(for: String(repeating: "x", count: 100)).hasSuffix("…"))
    }

    func testLabelKeepsVietnameseIntact() {
        XCTAssertEqual(ClipboardRing.label(for: "Thừa Thiên Huế"), "Thừa Thiên Huế")
    }
}
