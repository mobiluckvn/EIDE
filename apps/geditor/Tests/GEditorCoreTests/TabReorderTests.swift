import XCTest
@testable import GEditorCore

/// Kéo đổi vị trí tab (FR-DOC-301).
///
/// Bài quan trọng nhất ở đây không phải phép dời phần tử — nó là `track`: mọi chỉ số đang trỏ
/// vào danh sách tab phải dời theo. Sai chỗ ấy thì kéo một tab là màn hình lặng lẽ nhảy sang
/// tài liệu khác.
final class TabReorderTests: XCTestCase {

    private let items = ["A", "B", "C", "D"]

    // MARK: - Dời phần tử

    func testMoveRight() {
        XCTAssertEqual(TabReorder.apply(items, from: 0, to: 2), ["B", "C", "A", "D"])
    }

    func testMoveLeft() {
        XCTAssertEqual(TabReorder.apply(items, from: 3, to: 1), ["A", "D", "B", "C"])
    }

    func testMoveToSamePlaceChangesNothing() {
        XCTAssertEqual(TabReorder.apply(items, from: 2, to: 2), items)
    }

    func testOutOfRangeIsIgnoredNotCrashing() {
        XCTAssertEqual(TabReorder.apply(items, from: 9, to: 1), items)
        XCTAssertEqual(TabReorder.apply(items, from: 0, to: 99), ["B", "C", "D", "A"])
        XCTAssertEqual(TabReorder.apply(items, from: 3, to: -5), ["D", "A", "B", "C"])
        XCTAssertEqual(TabReorder.apply([String](), from: 0, to: 0), [])
    }

    // MARK: - Dời chỉ số đang theo dõi

    /// Chính tab đang bị kéo thì đi theo tới chỗ mới. Đây là ca hay bị quên nhất.
    func testTheDraggedTabItselfFollows() {
        XCTAssertEqual(TabReorder.track(0, from: 0, to: 2, count: 4), 2)
        XCTAssertEqual(TabReorder.track(3, from: 3, to: 1, count: 4), 1)
    }

    func testTabsInBetweenShiftLeftWhenDraggingRight() {
        // A B C D, kéo A (0) tới 2  →  B C A D
        XCTAssertEqual(TabReorder.track(1, from: 0, to: 2, count: 4), 0, "B: 1 → 0")
        XCTAssertEqual(TabReorder.track(2, from: 0, to: 2, count: 4), 1, "C: 2 → 1")
        XCTAssertEqual(TabReorder.track(3, from: 0, to: 2, count: 4), 3, "D không đổi")
    }

    func testTabsInBetweenShiftRightWhenDraggingLeft() {
        // A B C D, kéo D (3) tới 1  →  A D B C
        XCTAssertEqual(TabReorder.track(0, from: 3, to: 1, count: 4), 0, "A không đổi")
        XCTAssertEqual(TabReorder.track(1, from: 3, to: 1, count: 4), 2, "B: 1 → 2")
        XCTAssertEqual(TabReorder.track(2, from: 3, to: 1, count: 4), 3, "C: 2 → 3")
    }

    /// Bài tổng: sau khi kéo, chỉ số đã dời phải trỏ vào ĐÚNG phần tử cũ — với MỌI cặp (from, to)
    /// và MỌI chỉ số. Đây là bất biến thật, và nó bắt được cả những ca tôi không nghĩ ra.
    func testTrackedIndexAlwaysStillPointsAtTheSameElement() {
        for from in 0 ..< items.count {
            for to in 0 ..< items.count {
                let moved = TabReorder.apply(items, from: from, to: to)
                for index in 0 ..< items.count {
                    let after = TabReorder.track(index, from: from, to: to, count: items.count)
                    XCTAssertEqual(
                        moved[after], items[index],
                        "kéo \(from)→\(to): chỉ số \(index) («\(items[index])») thành \(after) («\(moved[after])»)"
                    )
                }
            }
        }
    }

    func testEmptyListIsSafe() {
        XCTAssertEqual(TabReorder.track(0, from: 0, to: 0, count: 0), 0)
        XCTAssertEqual(TabReorder.track(5, from: 1, to: 2, count: 0), 0)
    }

    func testIndexIsClamped() {
        XCTAssertEqual(TabReorder.track(99, from: 0, to: 1, count: 3), 2)
        XCTAssertEqual(TabReorder.track(-4, from: 2, to: 0, count: 3), 1)
    }
}
