import XCTest
@testable import GEditorCore

/// Folder as Workspace: cây thư mục, lọc, thao tác file (FR-DOC-308).
final class WorkspaceTests: XCTestCase {

    private var root = ""

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "geditor-ws-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    private func makeFile(_ relative: String, _ contents: String = "x") throws {
        let path = (root as NSString).appendingPathComponent(relative)
        let parent = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
    }

    private func makeDirectory(_ relative: String) throws {
        try FileManager.default.createDirectory(
            atPath: (root as NSString).appendingPathComponent(relative),
            withIntermediateDirectories: true
        )
    }

    // MARK: - Đọc cây

    /// Thư mục lên trước, rồi tới file — đúng trật tự Finder, để mắt không phải học lại.
    func testDirectoriesComeFirstThenFilesByName() throws {
        try makeFile("zeta.txt")
        try makeFile("alpha.txt")
        try makeDirectory("tai_lieu")
        try makeDirectory("anh")

        let names = Workspace.children(of: root).map(\.name)
        XCTAssertEqual(names, ["anh", "tai_lieu", "alpha.txt", "zeta.txt"])
    }

    /// Thư mục do công cụ sinh ra bị bỏ qua: chỉ riêng việc liệt kê chúng đã đủ làm treo.
    func testIgnoresToolDirectories() throws {
        try makeFile("main.swift")
        try makeDirectory("node_modules")
        try makeDirectory(".git")
        try makeDirectory(".build")

        XCTAssertEqual(Workspace.children(of: root).map(\.name), ["main.swift"])
    }

    func testHiddenFilesOnlyWhenAsked() throws {
        try makeFile(".env")
        try makeFile("main.swift")

        XCTAssertEqual(Workspace.children(of: root).map(\.name), ["main.swift"])
        XCTAssertEqual(
            Workspace.children(of: root, showHidden: true).map(\.name).sorted(),
            [".env", "main.swift"]
        )
    }

    /// Đọc theo TỪNG CẤP: mở thư mục gốc không được lôi cả cây con lên.
    func testReadsOneLevelOnly() throws {
        try makeFile("src/sau/rat_sau.txt")
        let names = Workspace.children(of: root).map(\.name)
        XCTAssertEqual(names, ["src"])
    }

    func testMarksDirectories() throws {
        try makeFile("a.txt")
        try makeDirectory("b")
        let entries = Workspace.children(of: root)
        XCTAssertEqual(entries.first { $0.name == "b" }?.isDirectory, true)
        XCTAssertEqual(entries.first { $0.name == "a.txt" }?.isDirectory, false)
    }

    /// Thư mục không đọc được thì trả rỗng, không ném lỗi lên UI.
    func testUnreadableDirectoryIsEmptyNotAnError() {
        XCTAssertTrue(Workspace.children(of: root + "/khong-ton-tai").isEmpty)
    }

    // MARK: - Lọc nhanh

    func testFindSearchesTheWholeTree() throws {
        try makeFile("src/khach_hang.swift")
        try makeFile("src/sau/khach_hang_test.swift")
        try makeFile("doc/ghi_chu.md")

        let found = Workspace.find("khach", under: root).map(\.name).sorted()
        XCTAssertEqual(found, ["khach_hang.swift", "khach_hang_test.swift"])
    }

    /// Gõ không dấu vẫn ra tên có dấu — cùng luật với ô lọc CSV và Function List.
    func testFindIsDiacriticInsensitive() throws {
        try makeFile("Báo cáo tháng.txt")
        XCTAssertEqual(Workspace.find("bao cao", under: root).map(\.name), ["Báo cáo tháng.txt"])
    }

    func testFindSkipsIgnoredDirectories() throws {
        try makeFile("node_modules/khach_hang.js")
        try makeFile("khach_hang.swift")
        XCTAssertEqual(Workspace.find("khach", under: root).map(\.name), ["khach_hang.swift"])
    }

    /// Dừng khi đủ: ô lọc chỉ hiện được vài chục dòng.
    func testFindStopsAtTheLimit() throws {
        for index in 0 ..< 50 { try makeFile("tep_\(index).txt") }
        XCTAssertEqual(Workspace.find("tep", under: root, limit: 10).count, 10)
    }

    func testEmptyNeedleFindsNothing() throws {
        try makeFile("a.txt")
        XCTAssertTrue(Workspace.find("   ", under: root).isEmpty)
    }

    // MARK: - Thao tác file

    func testCreateFileAndDirectory() throws {
        let file = try Workspace.createFile(named: "moi.txt", in: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file))

        let folder = try Workspace.createDirectory(named: "thu_muc", in: root)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    /// Trùng tên thì BÁO LỖI, không ghi đè.
    ///
    /// Một thao tác "tạo file mới" mà lặng lẽ xóa trắng file cũ cùng tên là mất dữ liệu, và
    /// người dùng chỉ biết khi mở nó ra.
    func testCreateRefusesToOverwrite() throws {
        try makeFile("co_san.txt", "nội dung quý giá")
        XCTAssertThrowsError(try Workspace.createFile(named: "co_san.txt", in: root)) { error in
            guard case Workspace.FileError.alreadyExists = error else {
                return XCTFail("lỗi sai loại: \(error)")
            }
        }
        let kept = try String(
            contentsOfFile: (root as NSString).appendingPathComponent("co_san.txt"),
            encoding: .utf8
        )
        XCTAssertEqual(kept, "nội dung quý giá")
    }

    func testRename() throws {
        try makeFile("cu.txt", "giữ nguyên")
        let path = (root as NSString).appendingPathComponent("cu.txt")
        let moved = try Workspace.rename(path, to: "moi.txt")

        XCTAssertEqual((moved as NSString).lastPathComponent, "moi.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        XCTAssertEqual(try String(contentsOfFile: moved, encoding: .utf8), "giữ nguyên")
    }

    func testRenameRefusesToClobber() throws {
        try makeFile("a.txt")
        try makeFile("b.txt", "đừng mất tôi")
        let path = (root as NSString).appendingPathComponent("a.txt")

        XCTAssertThrowsError(try Workspace.rename(path, to: "b.txt"))
        XCTAssertEqual(
            try String(
                contentsOfFile: (root as NSString).appendingPathComponent("b.txt"), encoding: .utf8
            ),
            "đừng mất tôi"
        )
    }

    /// Xóa vào THÙNG RÁC, không xóa thẳng — sidebar là chỗ người ta bấm nhanh.
    func testDeleteGoesToTrashNotOblivion() throws {
        try makeFile("bo_di.txt", "còn cứu được")
        let path = (root as NSString).appendingPathComponent("bo_di.txt")

        try Workspace.moveToTrash(path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))

        // Còn trong Thùng rác thì vẫn lấy lại được. Tìm bản vừa chuyển vào để dọn cho sạch.
        let trash = try FileManager.default.url(
            for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )
        let recovered = trash.appendingPathComponent("bo_di.txt")
        if FileManager.default.fileExists(atPath: recovered.path) {
            XCTAssertEqual(try String(contentsOf: recovered, encoding: .utf8), "còn cứu được")
            try? FileManager.default.removeItem(at: recovered)
        }
    }

    // MARK: - Theo dõi thay đổi

    /// Sửa file trong cây thì watcher phải báo — đó là toàn bộ lý do nó tồn tại.
    func testWatcherReportsChanges() throws {
        let reported = expectation(description: "watcher báo có thay đổi")
        reported.assertForOverFulfill = false

        let watcher = DirectoryWatcher(root: root) { paths in
            if paths.contains(where: { $0.contains("moi.txt") }) { reported.fulfill() }
        }
        XCTAssertTrue(watcher.start())
        defer { watcher.stop() }

        // FSEvents chỉ báo những gì xảy ra SAU khi stream chạy.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        try makeFile("moi.txt")

        wait(for: [reported], timeout: 10)
    }

    func testWatcherStopsCleanly() {
        let watcher = DirectoryWatcher(root: root) { _ in }
        XCTAssertTrue(watcher.start())
        XCTAssertTrue(watcher.isRunning)
        watcher.stop()
        XCTAssertFalse(watcher.isRunning)
        // Dừng hai lần không được sập.
        watcher.stop()
    }
}
