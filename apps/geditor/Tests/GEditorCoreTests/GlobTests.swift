import XCTest
@testable import GEditorCore

/// Kiểm thử bộ lọc tên file của Find in Files (FR-SRCH-106).
final class GlobTests: XCTestCase {

    func testLiteralAndStar() {
        XCTAssertTrue(Glob.matches("báo-cáo.csv", pattern: "*.csv"))
        XCTAssertTrue(Glob.matches("a.csv", pattern: "*"))
        XCTAssertFalse(Glob.matches("a.txt", pattern: "*.csv"))
        XCTAssertTrue(Glob.matches("a.csv", pattern: "a.csv"))
        XCTAssertTrue(Glob.matches("báo-cáo-2026.csv", pattern: "báo-*-2026.csv"))
        XCTAssertTrue(Glob.matches("abc", pattern: "a*c"))
        XCTAssertFalse(Glob.matches("abc", pattern: "a*d"))
    }

    func testStarMatchesEmpty() {
        XCTAssertTrue(Glob.matches("ac", pattern: "a*c"))
        XCTAssertTrue(Glob.matches(".csv", pattern: "*.csv"))
    }

    func testQuestionMark() {
        XCTAssertTrue(Glob.matches("a1.txt", pattern: "a?.txt"))
        XCTAssertFalse(Glob.matches("a12.txt", pattern: "a?.txt"))
        XCTAssertFalse(Glob.matches("a.txt", pattern: "a?.txt"), "? phải khớp ĐÚNG một ký tự")
    }

    func testCharacterSets() {
        XCTAssertTrue(Glob.matches("a1.txt", pattern: "a[0-9].txt"))
        XCTAssertFalse(Glob.matches("ax.txt", pattern: "a[0-9].txt"))
        XCTAssertTrue(Glob.matches("ab.txt", pattern: "a[abc].txt"))
        XCTAssertTrue(Glob.matches("ax.txt", pattern: "a[!0-9].txt"))
        XCTAssertFalse(Glob.matches("a1.txt", pattern: "a[!0-9].txt"))
        XCTAssertTrue(Glob.matches("ax.txt", pattern: "a[^0-9].txt"), "^ cũng là dấu phủ định")
    }

    /// Hệ thống file mặc định của macOS không phân biệt hoa thường; bộ lọc phải theo.
    func testCaseInsensitive() {
        XCTAssertTrue(Glob.matches("BÁO-CÁO.CSV", pattern: "*.csv"))
        XCTAssertTrue(Glob.matches("báo-cáo.csv", pattern: "*.CSV"))
    }

    func testUnclosedBracketIsTreatedAsLiteral() {
        // Người dùng đang gõ dở trong ô Filters — không được nổ, chỉ đơn giản là chưa khớp.
        XCTAssertTrue(Glob.matches("a[b", pattern: "a[b"))
        XCTAssertFalse(Glob.matches("ab", pattern: "a[b"))
    }

    func testConsecutiveStars() {
        XCTAssertTrue(Glob.matches("bất kỳ tên nào", pattern: "**"))
        XCTAssertTrue(Glob.matches("a-b-c.txt", pattern: "a**c.txt"))
    }

    func testEmptyPatternListMatchesEverything() {
        XCTAssertTrue(Glob.matchesAny("bất kỳ.gì", patterns: []))
        XCTAssertTrue(Glob.matchesAny("a.csv", patterns: ["*.txt", "*.csv"]))
        XCTAssertFalse(Glob.matchesAny("a.log", patterns: ["*.txt", "*.csv"]))
    }

    /// Mẫu nhiều `*` xen kẽ là chỗ thuật toán quay lui dễ sai nhất.
    func testBacktrackingWithMultipleStars() {
        XCTAssertTrue(Glob.matches("axxbxxc.txt", pattern: "*b*c*"))
        XCTAssertFalse(Glob.matches("axxcxxb.txt", pattern: "*b*c*"))
        XCTAssertTrue(Glob.matches("aaa", pattern: "*a*a*a*"))
        XCTAssertFalse(Glob.matches("aa", pattern: "*a*a*a*"))
    }
}
