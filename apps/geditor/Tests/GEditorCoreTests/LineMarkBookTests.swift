import XCTest
@testable import GEditorCore

/// Chín màu đánh dấu độc lập (FR-SRCH-107).
final class LineMarkBookTests: XCTestCase {

    func testStartsEmptyOnColorZero() {
        let book = LineMarkBook()
        XCTAssertTrue(book.isEmpty)
        XCTAssertEqual(book.activeColor, 0)
        XCTAssertEqual(LineMarkBook.colorCount, 9)
    }

    /// Điều quan trọng nhất: một dòng thuộc NHIỀU màu cùng lúc.
    ///
    /// Đây là lý do chín màu phải là chín TẬP chứ không phải một thuộc tính màu gắn vào dòng.
    func testOneLineCanCarrySeveralColors() {
        var book = LineMarkBook()
        book.toggle(5)
        book.setActiveColor(3)
        book.toggle(5)
        book.setActiveColor(8)
        book.toggle(5)

        XCTAssertEqual(book.colors(at: 5), [0, 3, 8])
        XCTAssertEqual(book.count, 1, "vẫn chỉ là MỘT dòng được đánh dấu")
    }

    func testColorsAreIndependent() {
        var book = LineMarkBook()
        book.toggle(1)
        book.setActiveColor(4)
        book.toggle(2)

        XCTAssertEqual(book[0].sorted, [1])
        XCTAssertEqual(book[4].sorted, [2])
        XCTAssertEqual(book.union.sorted, [1, 2])

        book.clearActive()                       // chỉ xóa màu 4
        XCTAssertEqual(book[0].sorted, [1])
        XCTAssertTrue(book[4].isEmpty)
    }

    func testToggleRemovesOnSecondCall() {
        var book = LineMarkBook()
        book.toggle(7)
        book.toggle(7)
        XCTAssertTrue(book.isEmpty)
    }

    /// Màu tô là màu NHỎ NHẤT, không phải màu vừa thêm: cùng tài liệu phải trông giống nhau ở
    /// hai lần mở, mà "vừa thêm" thì phụ thuộc thứ tự thao tác.
    func testDisplayColorIsTheLowestNotTheLatest() {
        var book = LineMarkBook()
        book.setActiveColor(6)
        book.toggle(2)
        book.setActiveColor(1)
        book.toggle(2)
        XCTAssertEqual(book.displayColor(at: 2), 1)
        XCTAssertNil(book.displayColor(at: 3))
    }

    func testInvertTouchesOnlyTheActiveColor() {
        var book = LineMarkBook()
        book.toggle(0)                            // màu 0: {0}
        book.setActiveColor(2)
        book.toggle(1)                            // màu 2: {1}
        book.invertActive(lineCount: 4)           // màu 2: {0,2,3}

        XCTAssertEqual(book[0].sorted, [0])
        XCTAssertEqual(book[2].sorted, [0, 2, 3])
    }

    func testClearAllWipesEveryColor() {
        var book = LineMarkBook()
        for color in 0 ..< 9 {
            book.setActiveColor(color)
            book.toggle(color)
        }
        XCTAssertEqual(book.count, 9)
        book.clearAll()
        XCTAssertTrue(book.isEmpty)
    }

    func testColorIndexIsClamped() {
        var book = LineMarkBook()
        book.setActiveColor(99)
        XCTAssertEqual(book.activeColor, 8)
        book.setActiveColor(-4)
        XCTAssertEqual(book.activeColor, 0)
        XCTAssertTrue(book[999].isEmpty)          // không được sập
    }

    // MARK: - Điều hướng (F2 / ⇧F2)

    func testNavigationWalksForwardAndBack() {
        var book = LineMarkBook()
        for line in [3, 10, 42] { book.toggle(line) }

        XCTAssertEqual(book.nextMarkedLine(after: 0, withinLineCount: 100_000), 3)
        XCTAssertEqual(book.nextMarkedLine(after: 3, withinLineCount: 100_000), 10)
        XCTAssertEqual(book.previousMarkedLine(before: 42, withinLineCount: 100_000), 10)
        XCTAssertEqual(book.previousMarkedLine(before: 3, withinLineCount: 100_000), 42, "lùi từ dấu đầu thì vòng xuống cuối")
    }

    /// Tới dấu cuối rồi bấm tiếp phải QUAY VÒNG. Không quay vòng thì phím trông như hỏng.
    func testNavigationWrapsAround() {
        var book = LineMarkBook()
        for line in [3, 10] { book.toggle(line) }
        XCTAssertEqual(book.nextMarkedLine(after: 10, withinLineCount: 100_000), 3)
        XCTAssertEqual(book.nextMarkedLine(after: 9_999, withinLineCount: 100_000), 3)
    }

    func testNavigationReturnsNilOnlyWhenThereAreNoMarks() {
        XCTAssertNil(LineMarkBook().nextMarkedLine(after: 0, withinLineCount: 100_000))
        XCTAssertNil(LineMarkBook().previousMarkedLine(before: 0, withinLineCount: 100_000))
    }

    func testNavigationCanFollowOneColorOnly() {
        var book = LineMarkBook()
        book.toggle(1)                 // màu 0
        book.setActiveColor(5)
        book.toggle(2)                 // màu 5

        XCTAssertEqual(book.nextMarkedLine(after: 0, withinLineCount: 100_000, color: 5), 2, "bỏ qua dòng 1 của màu khác")
        XCTAssertEqual(book.nextMarkedLine(after: 0, withinLineCount: 100_000), 1, "không nêu màu thì đi qua mọi màu")
    }

    // MARK: - Tài liệu CO LẠI dưới chân các dấu

    /// Dấu là SỐ DÒNG, còn nội dung đổi dưới chân nó. Điều hướng không được trả về một dòng
    /// đã biến mất — chỗ gọi đem số ấy đi hỏi `offset(ofLineStart:)`, một hàm có `precondition`,
    /// nên nó làm app SẬP chứ không hiện sai một con số.
    ///
    /// Bộ chạy dài `--soak` tìm ra ở bước 337: đánh dấu, xoá cho tài liệu rỗng, rồi bấm F2.
    func testNavigationSkipsMarksBeyondTheDocument() {
        var book = LineMarkBook()
        for line in [3, 10, 42] { book.toggle(line) }

        // Tài liệu chỉ còn 11 dòng: dấu ở 42 không còn chỗ đứng.
        XCTAssertEqual(book.nextMarkedLine(after: 3, withinLineCount: 11), 10)
        XCTAssertEqual(book.nextMarkedLine(after: 10, withinLineCount: 11), 3, "vòng lại, KHÔNG nhảy tới 42")
        XCTAssertEqual(book.previousMarkedLine(before: 3, withinLineCount: 11), 10)
    }

    /// Tài liệu rỗng: không dấu nào còn tồn tại, nên phải trả `nil` — chỗ gọi có sẵn nhánh
    /// "không có dấu nào" cho trường hợp ấy.
    func testNavigationReturnsNilWhenDocumentIsEmpty() {
        var book = LineMarkBook()
        for line in [3, 10, 42] { book.toggle(line) }

        XCTAssertNil(book.nextMarkedLine(after: 0, withinLineCount: 0))
        XCTAssertNil(book.previousMarkedLine(before: 0, withinLineCount: 0))
        XCTAssertFalse(book.isEmpty, "các dấu vẫn còn đó — chỉ là không dòng nào hiện hữu")
    }
}
