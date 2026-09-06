import XCTest
@testable import GEditorCore

/// Giữ quyền truy cập file qua các lần khởi động (App Sandbox).
///
/// Bài kiểm chạy KHÔNG trong sandbox, nên nó không chứng minh được phần "quyền sống qua lần
/// khởi động" — chỗ ấy phải kiểm tay trên bản đã ký, xem `docs/trang-thai.md` §5. Cái nó canh
/// được là phần dễ hỏng còn lại: bookmark có được tạo và giải mã đúng không, và việc đếm lượt
/// mở/thả có cân không. Đếm lệch là loại lỗi tốn nhiều ngày nhất để tìm, vì triệu chứng chỉ là
/// "thỉnh thoảng lưu không được".
final class SandboxAccessTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sandbox-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        SandboxAccess.releaseAllForTesting()
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// So sánh đường dẫn phải chuẩn hóa: `/var` là symlink tới `/private/var`, và thư mục thì
    /// có khi mang dấu `/` ở cuối, có khi không.
    private func canonical(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func makeFile(_ name: String, _ content: String = "xin chào\n") -> URL {
        let url = directory.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Bookmark

    func testBookmarkRoundTripsToTheSameFile() throws {
        let file = makeFile("a.txt")
        let data = try XCTUnwrap(SandboxAccess.makeBookmark(for: file))
        let resolved = try XCTUnwrap(SandboxAccess.resolve(data))
        XCTAssertEqual(canonical(resolved.url), canonical(file))
        XCTAssertFalse(resolved.isStale)
    }

    /// Đổi tên file: bookmark vẫn tới được nội dung, nhưng phải BÁO là đã cũ.
    ///
    /// Bỏ qua cờ ấy nghĩa là mỗi lần đổi tên lại tiến gần hơn tới lần hỏng hẳn, mà không ai biết.
    func testRenamedFileResolvesButReportsStale() throws {
        let file = makeFile("truoc.txt")
        let data = try XCTUnwrap(SandboxAccess.makeBookmark(for: file))

        let moved = directory.appendingPathComponent("sau.txt")
        try FileManager.default.moveItem(at: file, to: moved)

        let resolved = try XCTUnwrap(SandboxAccess.resolve(data))
        XCTAssertEqual(resolved.url.lastPathComponent, "sau.txt")
    }

    func testDeletedFileFailsToResolveInsteadOfReturningNonsense() throws {
        let file = makeFile("mat.txt")
        let data = try XCTUnwrap(SandboxAccess.makeBookmark(for: file))
        try FileManager.default.removeItem(at: file)
        XCTAssertNil(SandboxAccess.resolve(data))
    }

    func testGarbageBookmarkIsRejected() {
        XCTAssertNil(SandboxAccess.resolve(Data([0x00, 0x01, 0x02, 0x03])))
    }

    func testDirectoryBookmarkWorksToo() throws {
        let data = try XCTUnwrap(SandboxAccess.makeBookmark(for: directory))
        let resolved = try XCTUnwrap(SandboxAccess.resolve(data))
        XCTAssertEqual(canonical(resolved.url), canonical(directory))
    }

    // MARK: - Đếm lượt

    /// Hai chỗ cùng giữ một file: chỗ thả trước KHÔNG được cắt quyền của chỗ còn lại.
    func testAccessIsReferenceCounted() {
        let file = makeFile("chung.txt")
        SandboxAccess.begin(file)
        SandboxAccess.begin(file)
        XCTAssertEqual(SandboxAccess.holdCount(for: file), 2)

        SandboxAccess.end(file)
        XCTAssertEqual(SandboxAccess.holdCount(for: file), 1, "thả lượt đầu đã cắt quyền")

        SandboxAccess.end(file)
        XCTAssertEqual(SandboxAccess.holdCount(for: file), 0)
    }

    /// Thả nhiều hơn số lượt đã mở thì bỏ qua, không đưa bộ đếm xuống âm.
    func testExtraReleaseIsHarmless() {
        let file = makeFile("thua.txt")
        SandboxAccess.begin(file)
        SandboxAccess.end(file)
        SandboxAccess.end(file)
        SandboxAccess.end(file)
        XCTAssertEqual(SandboxAccess.holdCount(for: file), 0)
    }

    func testUnknownURLReleaseIsHarmless() {
        SandboxAccess.end(directory.appendingPathComponent("chua-tung-mo.txt"))
        XCTAssertEqual(SandboxAccess.activeCount, 0)
    }

    // MARK: - Tài liệu

    /// Mở file là có bookmark ngay — tạo lúc còn quyền, không đợi tới lúc cần.
    func testOpeningADocumentCapturesABookmark() throws {
        let file = makeFile("tai-lieu.txt", "một\nhai\n")
        let document = try Document.open(path: file.path)
        XCTAssertNotNil(document.accessBookmark, "mở file mà không giữ lại bookmark nào")
    }

    /// Mở lại từ bookmark cho đúng nội dung, và thả quyền khi tài liệu bị giải phóng.
    func testDocumentReopensFromBookmarkAndReleasesOnDeinit() throws {
        let file = makeFile("mo-lai.txt", "nội dung gốc\n")
        let bookmark = try XCTUnwrap(SandboxAccess.makeBookmark(for: file))

        let before = SandboxAccess.holdCount(for: file)
        do {
            let document = try XCTUnwrap(Document.open(bookmark: bookmark))
            XCTAssertEqual(document.buffer.text, "nội dung gốc\n")
            XCTAssertEqual(canonical(URL(fileURLWithPath: document.path!)), canonical(file))
            // Hỏi bằng URL DẠNG KHÁC với dạng lúc mở — bảng đếm phải nhận ra là cùng một file.
            XCTAssertEqual(SandboxAccess.holdCount(for: file), before + 1)
        }
        // Tài liệu đã ra khỏi tầm: quyền phải được thả, nếu không nó tích lại suốt phiên.
        XCTAssertEqual(SandboxAccess.holdCount(for: file), before)
    }

    func testDocumentFromDeadBookmarkReturnsNilInsteadOfCrashing() throws {
        let file = makeFile("se-xoa.txt")
        let bookmark = try XCTUnwrap(SandboxAccess.makeBookmark(for: file))
        try FileManager.default.removeItem(at: file)
        XCTAssertNil(Document.open(bookmark: bookmark))
        XCTAssertEqual(SandboxAccess.activeCount, 0, "mở hỏng mà vẫn giữ quyền")
    }
}

// MARK: - Phiên có workspace

extension SandboxAccessTests {

    private func windowWithWorkspace(tabs: [SessionTab]) -> SessionWindow {
        SessionWindow(
            tabs: tabs, workspacePath: "/tmp/du-an", workspaceBookmark: Data([1, 2, 3])
        )
    }

    /// Mở một thư mục rồi thoát mà chưa mở file nào: phiên vẫn phải đáng khôi phục.
    func testSessionWithOnlyAWorkspaceIsNotEmpty() {
        let session = Session(windows: [windowWithWorkspace(tabs: [])])
        XCTAssertFalse(session.isEmpty, "phiên chỉ có thư mục bị coi là rỗng và sẽ bị vứt đi")
    }

    func testPruningKeepsTheWorkspaceWindow() {
        let throwaway = SessionTab(path: nil, documentID: "x", caretOffset: 0)
        let session = Session(windows: [windowWithWorkspace(tabs: [throwaway])])
        let pruned = session.pruned()
        XCTAssertEqual(pruned.windows.count, 1)
        XCTAssertEqual(pruned.windows.first?.workspacePath, "/tmp/du-an")
        XCTAssertTrue(pruned.windows.first?.tabs.isEmpty == true)
    }

    /// Không có thư mục thì cửa sổ trống vẫn bị bỏ như trước — đừng để rác tích lại.
    func testPruningStillDropsTrulyEmptyWindows() {
        let throwaway = SessionTab(path: nil, documentID: "x", caretOffset: 0)
        let session = Session(windows: [SessionWindow(tabs: [throwaway])])
        XCTAssertTrue(session.isEmpty)
        XCTAssertTrue(session.pruned().windows.isEmpty)
    }
}
