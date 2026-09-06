import XCTest
@testable import GEditorCore

/// Truy vết: FR-DOC-309 theo dõi file (tail -f).
///
/// Mọi bài ở đây `start()` rồi `stop()` NGAY, và sau đó chỉ dùng `poll()`.
///
/// `start()` là thứ ghi lại cỡ và inode ban đầu — bỏ nó thì không có gì để so. Còn `stop()` là
/// để tắt đường sự kiện của `DispatchSource`: để nó chạy thì hệ điều hành xen vào giữa hai
/// bước của bài kiểm và báo thêm những nhịp thật nhưng không đoán trước được — xoay vòng log
/// có một khoảnh khắc file không tồn tại, và bài kiểm sẽ lúc xanh lúc đỏ. Máy trạng thái mới
/// là thứ cần kiểm ở đây; đường dây sự kiện thật kiểm ở tầng giao diện.
final class FileTailWatcherTests: XCTestCase {

    private var directory = ""

    override func setUpWithError() throws {
        directory = NSTemporaryDirectory() + "geditor-tail-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    private func makeFile(_ name: String, _ content: String) throws -> String {
        let path = directory + "/" + name
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Vừa bắt đầu theo dõi thì KHÔNG báo phần đã có sẵn: người dùng vừa mở file và đã thấy nó.
    func testStartDoesNotReportExistingContent() throws {
        let path = try makeFile("a.log", "đã có sẵn\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()
        watcher.poll()
        XCTAssertTrue(changes.isEmpty)
    }

    func testAppendReportsOnlyTheNewBytes() throws {
        let path = try makeFile("a.log", "một\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()

        let before = "một\n".utf8.count
        let handle = FileHandle(forWritingAtPath: path)!
        handle.seekToEndOfFile()
        handle.write(Data("hai\n".utf8))
        try handle.close()

        watcher.poll()
        XCTAssertEqual(changes, [.appended(before ..< (before + 4))])
    }

    /// `> app.log` — cỡ NHỎ đi. Đọc "từ chỗ cũ tới hết" sẽ ra rác.
    func testTruncationIsReportedAsReplacement() throws {
        let path = try makeFile("a.log", "một dòng dài\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()

        try "x\n".write(toFile: path, atomically: false, encoding: .utf8)
        watcher.poll()
        XCTAssertEqual(changes, [.replaced(newSize: 2)])
    }

    /// `logrotate`: đổi tên file cũ rồi tạo file mới CÙNG TÊN. Cỡ có thể lớn hơn, nên so cỡ
    /// không bắt được — chỉ inode mới nói ra.
    func testRotationIsDetectedEvenWhenNewFileIsLarger() throws {
        let path = try makeFile("a.log", "ngắn\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()

        try FileManager.default.moveItem(atPath: path, toPath: path + ".1")
        let longer = String(repeating: "dài hơn nhiều\n", count: 10)
        try longer.write(toFile: path, atomically: true, encoding: .utf8)

        watcher.poll()
        XCTAssertEqual(changes, [.replaced(newSize: longer.utf8.count)])
    }

    func testVanishedFileIsReported() throws {
        let path = try makeFile("a.log", "một\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()

        try FileManager.default.removeItem(atPath: path)
        watcher.poll()
        XCTAssertEqual(changes, [.vanished])
    }

    func testNoChangeReportsNothing() throws {
        let path = try makeFile("a.log", "im lìm\n")
        var changes: [FileTailWatcher.Change] = []
        let watcher = FileTailWatcher(path: path) { changes.append($0) }
        XCTAssertTrue(watcher.start())
        watcher.stop()
        watcher.poll()
        watcher.poll()
        XCTAssertTrue(changes.isEmpty, "file không đổi thì không được báo gì")
    }

    func testStartFailsForMissingFile() {
        let watcher = FileTailWatcher(path: directory + "/không-có.log") { _ in }
        XCTAssertFalse(watcher.start())
        XCTAssertFalse(watcher.isRunning)
    }
}
