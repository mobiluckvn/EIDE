import XCTest
@testable import GEditorCore

/// Truy vết: NFR-REL-02 (ghi file atomic), FR-DOC-314. Tương ứng TC-DOC-02 trong STP §3.4.
final class AtomicFileWriterTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testWriteCreatesFileWithExactContent() throws {
        let path = directory.appendingPathComponent("moi.txt").path
        try AtomicFileWriter.write(Array("xin chào".utf8), to: path)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "xin chào")
    }

    func testOverwritePreservesPermissions() throws {
        let path = directory.appendingPathComponent("quyen.txt").path
        try AtomicFileWriter.write(Array("cũ".utf8), to: path)
        chmod(path, 0o640)

        try AtomicFileWriter.write(Array("mới".utf8), to: path)

        var st = stat()
        XCTAssertEqual(stat(path, &st), 0)
        XCTAssertEqual(st.st_mode & 0o777, 0o640, "quyền file gốc phải được bảo toàn khi lưu đè")
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "mới")
    }

    func testPreservesExtendedAttributes() throws {
        let path = directory.appendingPathComponent("xattr.txt").path
        try AtomicFileWriter.write(Array("nội dung".utf8), to: path)

        let name = "com.geditor.test"
        let value = Array("giá trị".utf8)
        XCTAssertEqual(setxattr(path, name, value, value.count, 0, 0), 0)

        try AtomicFileWriter.write(Array("nội dung mới".utf8), to: path)

        let size = getxattr(path, name, nil, 0, 0, 0)
        XCTAssertGreaterThan(size, 0, "extended attribute (gồm cả tag Finder) phải được giữ lại")
    }

    /// Không để lại rác: file tạm `.geditor-XXXXXX` phải biến mất sau khi ghi xong.
    func testNoTemporaryFilesLeftBehind() throws {
        let path = directory.appendingPathComponent("sach.txt").path
        try AtomicFileWriter.write(Array("a".utf8), to: path)
        try AtomicFileWriter.write(Array("b".utf8), to: path)

        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(entries.filter { $0.hasPrefix(".geditor-") }, [])
    }

    /// Ghi hỏng giữa chừng KHÔNG được chạm vào file gốc (TC-DOC-02).
    func testFailureMidWriteLeavesOriginalIntact() throws {
        let path = directory.appendingPathComponent("goc.txt").path
        try AtomicFileWriter.write(Array("nội dung gốc".utf8), to: path)

        struct Boom: Error {}
        XCTAssertThrowsError(
            try AtomicFileWriter.write(to: path) { fd in
                _ = "một phần".withCString { write(fd, $0, strlen($0)) }
                throw Boom()   // giả lập đầy đĩa / mất quyền giữa chừng
            }
        )

        XCTAssertEqual(
            try String(contentsOfFile: path, encoding: .utf8), "nội dung gốc",
            "file gốc phải nguyên vẹn 100% khi lưu thất bại"
        )
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(entries.filter { $0.hasPrefix(".geditor-") }, [], "phải dọn file tạm khi lỗi")
    }

    func testSnapshotStoreRoundTrip() throws {
        let store = SnapshotStore(root: directory.appendingPathComponent("snapshots"))
        let manifest = Snapshot(
            documentID: "doc-1",
            originalPath: "/tmp/bao_cao.csv",
            savedAtEpoch: 1_755_600_000,
            byteCount: 5,
            caretOffset: 3
        )
        try store.write(Array("chưa lưu".utf8), manifest: manifest)

        let pending = try store.pendingSnapshots()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.documentID, "doc-1")
        XCTAssertEqual(pending.first?.caretOffset, 3)
        XCTAssertEqual(String(decoding: try store.content(for: "doc-1"), as: UTF8.self), "chưa lưu")

        try store.discard(documentID: "doc-1")
        XCTAssertEqual(try store.pendingSnapshots().count, 0)
    }
}
