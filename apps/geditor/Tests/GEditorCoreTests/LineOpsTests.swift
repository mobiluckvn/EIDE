import XCTest
@testable import GEditorCore

/// Truy vết: FR-CORE-005…010. Tương ứng TC-CORE-06/07/08/11/12 trong STP §3.1.
final class LineOpsTests: XCTestCase {

    // MARK: - Sort (TC-CORE-06/07)

    func testNaturalSort() {
        let sorted = LineOps.sort(lines: ["file1", "file10", "file2"], kind: .natural)
        XCTAssertEqual(sorted, ["file1", "file2", "file10"])
    }

    func testNumericSortDescending() {
        let sorted = LineOps.sort(lines: ["10", "9", "100"], kind: .numeric, ascending: false)
        XCTAssertEqual(sorted, ["100", "10", "9"])
    }

    func testNonNumericLinesSortAfterNumbers() {
        let sorted = LineOps.sort(lines: ["5", "abc", "1"], kind: .numeric)
        XCTAssertEqual(sorted, ["1", "5", "abc"])
    }

    func testSortByColumn() {
        let lines = ["a,30,x", "b,10,y", "c,20,z"]
        let sorted = LineOps.sort(lines: lines, kind: .numeric, column: 1)
        XCTAssertEqual(sorted, ["b,10,y", "c,20,z", "a,30,x"])
    }

    func testSortIsStableForEqualKeys() {
        let lines = ["b,1", "a,1", "c,1"]
        let sorted = LineOps.sort(lines: lines, kind: .numeric, column: 1)
        XCTAssertEqual(sorted, lines, "khóa bằng nhau phải giữ nguyên thứ tự ban đầu")
    }

    // MARK: - Dedup (TC-CORE-08)

    func testDedupWholeDocumentKeepsFirst() {
        let lines = ["a", "b", "a", "c", "b"]
        XCTAssertEqual(LineOps.duplicateLineIndices(lines: lines), [2, 4])
    }

    func testDedupKeepLast() {
        let lines = ["a", "b", "a"]
        XCTAssertEqual(LineOps.duplicateLineIndices(lines: lines, keep: .last), [0])
    }

    func testDedupConsecutiveOnly() {
        let lines = ["a", "a", "b", "a"]
        XCTAssertEqual(
            LineOps.duplicateLineIndices(lines: lines, scope: .consecutive), [1],
            "chỉ gộp dòng trùng LIỀN NHAU — dòng 'a' cuối phải giữ lại"
        )
    }

    // MARK: - Khoảng trắng

    func testTrimSides() {
        XCTAssertEqual(LineOps.trim("  giữa  "), "giữa")
        XCTAssertEqual(LineOps.trim("  giữa  ", side: .leading), "giữa  ")
        XCTAssertEqual(LineOps.trim("  giữa  ", side: .trailing), "  giữa")
    }

    func testBlankLineIncludesWhitespaceOnly() {
        XCTAssertTrue(LineOps.isBlank(""))
        XCTAssertTrue(LineOps.isBlank("   \t "))
        XCTAssertFalse(LineOps.isBlank("  x"))
    }

    // MARK: - TAB ↔ Space (TC-CORE-12)

    func testTabsToSpacesRespectsTabStops() {
        XCTAssertEqual(LineOps.tabsToSpaces("a\tb", tabWidth: 4), "a   b")
        XCTAssertEqual(LineOps.tabsToSpaces("\tx", tabWidth: 4), "    x")
    }

    func testSpacesToTabsOnlyTouchesIndentation() {
        XCTAssertEqual(LineOps.spacesToTabs("        x", tabWidth: 4), "\t\tx")
        XCTAssertEqual(
            LineOps.spacesToTabs("a    b", tabWidth: 4), "a    b",
            "space GIỮA dòng không được gộp thành tab — sẽ phá văn bản căn cột"
        )
    }

    func testTabSpaceRoundTripPreservesIndentation() {
        let original = "\t\tnội dung"
        let expanded = LineOps.tabsToSpaces(original, tabWidth: 4)
        XCTAssertEqual(LineOps.spacesToTabs(expanded, tabWidth: 4), original)
    }

    // MARK: - Hoa/thường (TC-CORE-11)

    func testCamelToSnake() {
        XCTAssertEqual(LineOps.convertCase("userNameField", to: .snake), "user_name_field")
    }

    func testSnakeToCamel() {
        XCTAssertEqual(LineOps.convertCase("user_name_field", to: .camel), "userNameField")
    }

    func testKebabConversion() {
        XCTAssertEqual(LineOps.convertCase("userNameField", to: .kebab), "user-name-field")
    }

    func testInvertCase() {
        XCTAssertEqual(LineOps.convertCase("aBc", to: .invert), "AbC")
    }

    func testSentenceCase() {
        XCTAssertEqual(LineOps.convertCase("XIN CHÀO CÁC BẠN", to: .sentence), "Xin chào các bạn")
    }
}
