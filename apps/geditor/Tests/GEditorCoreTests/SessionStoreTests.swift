import XCTest
@testable import GEditorCore

/// Phiên làm việc: ghi, đọc, và những cách nó có thể hỏng (FR-DOC-303).
final class SessionStoreTests: XCTestCase {

    private var root: URL!

    override func setUp() {
        super.setUp()
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-session-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func store() -> SessionStore { SessionStore(root: root) }

    private func tab(_ path: String?, modified: Bool = false, caret: Int = 0) -> SessionTab {
        SessionTab(path: path, documentID: UUID().uuidString, caretOffset: caret,
                   isModified: modified)
    }

    // MARK: - Vòng tròn ghi → đọc

    func testRoundTripKeepsEverything() throws {
        let session = Session(windows: [
            SessionWindow(
                tabs: [
                    SessionTab(path: "/a.txt", documentID: "id-a", caretOffset: 120,
                               isPinned: true, colorIndex: 3, isModified: false),
                    SessionTab(path: nil, documentID: "id-b", caretOffset: 7,
                               isPinned: false, colorIndex: nil, isModified: true),
                ],
                activeTabIndex: 1,
                frame: [10, 20, 800, 600]
            ),
        ])
        let store = self.store()
        try store.save(session)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded, session)
        XCTAssertEqual(loaded.windows[0].tabs[0].caretOffset, 120)
        XCTAssertEqual(loaded.windows[0].tabs[0].colorIndex, 3)
        XCTAssertTrue(loaded.windows[0].tabs[1].isModified)
        XCTAssertEqual(loaded.windows[0].frame, [10, 20, 800, 600])
    }

    func testLoadWithoutFileIsNilNotAnError() throws {
        XCTAssertNil(try store().load())
    }

    /// File phiên hỏng KHÔNG được làm hỏng lần khởi động.
    ///
    /// Không mở lại được phiên cũ là chuyện khó chịu; không mở được app là chuyện hỏng. Và vẫn
    /// còn bản nháp của FR-DOC-304 làm lưới an toàn thứ hai.
    func testCorruptFileLoadsAsNil() throws {
        let store = self.store()
        try store.save(Session(windows: [SessionWindow(tabs: [tab("/a.txt")])]))
        try Data("{ đây không phải JSON".utf8).write(to: store.fileURL)
        XCTAssertNil(try store.load())
    }

    func testFutureSchemaIsRefused() throws {
        let store = self.store()
        var session = Session(windows: [SessionWindow(tabs: [tab("/a.txt")])])
        session.schemaVersion = Session.currentSchemaVersion + 1
        let data = try JSONEncoder().encode(session)
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: store.fileURL)
        XCTAssertNil(try store.load(), "schema tương lai thì thà không mở còn hơn mở sai")
    }

    /// File phiên phải là JSON ĐỌC ĐƯỢC BẰNG MẮT (ADR-09).
    ///
    /// Khi phiên khôi phục sai, đây là chỗ đầu tiên người ta mở ra xem.
    func testFileIsHumanReadableJSON() throws {
        let store = self.store()
        try store.save(Session(windows: [
            SessionWindow(tabs: [SessionTab(path: "/duong/dan.txt", documentID: "x", caretOffset: 5)]),
        ]))
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("/duong/dan.txt"))
        XCTAssertTrue(text.contains("\n"), "phải xuống dòng, không phải một dòng JSON dí sát")
    }

    func testClearRemovesTheFile() throws {
        let store = self.store()
        try store.save(Session(windows: [SessionWindow(tabs: [tab("/a.txt")])]))
        try store.clear()
        XCTAssertNil(try store.load())
        XCTAssertNoThrow(try store.clear(), "xóa hai lần không được ném lỗi")
    }

    // MARK: - Lọc tab không đáng khôi phục

    func testEmptyUntouchedTabIsNotWorthRestoring() {
        XCTAssertFalse(tab(nil).isWorthRestoring)
        XCTAssertTrue(tab(nil, modified: true).isWorthRestoring)
        XCTAssertTrue(tab("/a.txt").isWorthRestoring)
    }

    func testPruneDropsEmptyTabsAndEmptyWindows() {
        let session = Session(windows: [
            SessionWindow(tabs: [tab(nil), tab("/a.txt"), tab(nil)]),
            SessionWindow(tabs: [tab(nil), tab(nil)]),
        ])
        let pruned = session.pruned()
        XCTAssertEqual(pruned.windows.count, 1)
        XCTAssertEqual(pruned.windows[0].tabs.count, 1)
        XCTAssertEqual(pruned.windows[0].tabs[0].path, "/a.txt")
    }

    /// Sau khi lọc, chỉ số tab đang mở phải trỏ đúng TAB CŨ.
    ///
    /// Giữ nguyên số cũ thì bỏ một tab ở đầu là mở lại đúng tab khác — sai lặng lẽ, và người
    /// dùng chỉ thấy "app mở nhầm file".
    func testPruneRemapsTheActiveTab() {
        let keep = tab("/giu.txt")
        let session = Session(windows: [
            SessionWindow(tabs: [tab(nil), tab(nil), keep], activeTabIndex: 2),
        ])
        let pruned = session.pruned()
        XCTAssertEqual(pruned.windows[0].activeTabIndex, 0)
        XCTAssertEqual(pruned.windows[0].tabs[pruned.windows[0].activeTabIndex].path, "/giu.txt")
    }

    func testEmptySessionKnowsItIsEmpty() {
        XCTAssertTrue(Session(windows: []).isEmpty)
        XCTAssertTrue(Session(windows: [SessionWindow(tabs: [tab(nil)])]).isEmpty)
        XCTAssertFalse(Session(windows: [SessionWindow(tabs: [tab("/a.txt")])]).isEmpty)
    }

    // MARK: - Kẹp giá trị vô lý

    func testActiveIndexIsClamped() {
        let window = SessionWindow(tabs: [tab("/a.txt"), tab("/b.txt")], activeTabIndex: 99)
        XCTAssertEqual(window.activeTabIndex, 1)
        XCTAssertEqual(SessionWindow(tabs: [], activeTabIndex: 5).activeTabIndex, 0)
    }

    func testNegativeCaretBecomesZero() {
        XCTAssertEqual(SessionTab(path: nil, documentID: "x", caretOffset: -9).caretOffset, 0)
    }

    // MARK: - Chia đôi màn hình trong phiên (FR-DOC-302 + FR-DOC-303)

    func testSplitStateSurvivesTheRoundTrip() throws {
        let session = Session(windows: [
            SessionWindow(
                tabs: [tab("/a.txt"), tab("/b.txt")], activeTabIndex: 0,
                split: SessionSplit(isVertical: false, secondTabIndex: 1)
            ),
        ])
        let store = self.store()
        try store.save(session)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.windows[0].split?.isVertical, false)
        XCTAssertEqual(loaded.windows[0].split?.secondTabIndex, 1)
    }

    func testNoSplitStaysNil() throws {
        let store = self.store()
        try store.save(Session(windows: [SessionWindow(tabs: [tab("/a.txt")])]))
        XCTAssertNil(try XCTUnwrap(store.load()).windows[0].split)
    }

    /// Nửa thứ hai cũng phải được đánh số LẠI sau khi lọc tab.
    ///
    /// Không tính lại thì bỏ một tab trắng ở đầu là nửa thứ hai mở lại đúng tài liệu khác —
    /// cùng loại lỗi với `activeTabIndex`, và lặng lẽ y như thế.
    func testPruneRemapsTheSecondPane() {
        let second = tab("/hai.txt")
        let session = Session(windows: [
            SessionWindow(
                tabs: [tab(nil), tab("/mot.txt"), second], activeTabIndex: 1,
                split: SessionSplit(isVertical: true, secondTabIndex: 2)
            ),
        ])
        let pruned = session.pruned()
        XCTAssertEqual(pruned.windows[0].tabs.count, 2)
        XCTAssertEqual(pruned.windows[0].split?.secondTabIndex, 1)
        XCTAssertEqual(pruned.windows[0].tabs[1].path, "/hai.txt")
    }

    /// Nhiều cửa sổ phải đi qua được vòng ghi/đọc — SRS đòi "hỗ trợ nhiều cửa sổ".
    func testSeveralWindowsSurviveTheRoundTrip() throws {
        let session = Session(windows: [
            SessionWindow(tabs: [tab("/a.txt")], frame: [0, 0, 100, 100]),
            SessionWindow(tabs: [tab("/b.txt"), tab("/c.txt")], activeTabIndex: 1),
        ])
        let store = self.store()
        try store.save(session)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.windows.count, 2)
        XCTAssertEqual(loaded.windows[1].tabs.map(\.path), ["/b.txt", "/c.txt"])
        XCTAssertEqual(loaded.windows[1].activeTabIndex, 1)
    }
}
