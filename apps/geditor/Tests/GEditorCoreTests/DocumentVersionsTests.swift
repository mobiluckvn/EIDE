import XCTest
@testable import GEditorCore

/// Duyệt và khôi phục bản đã lưu (FR-DOC-305, hướng A của PoC-J).
final class DocumentVersionsTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-versions-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeFile(_ name: String = "thu.txt") -> String {
        directory.appendingPathComponent(name).path
    }

    /// Dựng một tài liệu đã có đường dẫn, bằng đúng đường sản phẩm dùng.
    private func makeDocument(at path: String, text: String) throws -> Document {
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
        return try Document.open(path: path)
    }

    // MARK: - Ghi và đọc lịch sử

    /// Lưu ba lần thì đọc lại được hai bản CŨ — bản hiện tại nằm trên đĩa, không nằm trong lịch sử.
    func testKeepsPreviousContentsAcrossSaves() throws {
        let path = makeFile()
        let document = try makeDocument(at: path, text: "bản 1 — Nguyễn")
        for text in ["bản 2 — Trần", "bản 3 — Lê"] {
            document.buffer.applyEdits(
                [TextEdit(range: 0 ..< document.buffer.count, text: text)], label: "sửa")
            _ = try document.save()
        }

        let versions = DocumentVersions.versions(of: path)
        XCTAssertGreaterThanOrEqual(versions.count, 2, "phải giữ được bản cũ")

        let texts = versions.compactMap { DocumentVersions.contents(of: $0) }
            .map { String(decoding: $0, as: UTF8.self) }
        XCTAssertTrue(texts.contains("bản 1 — Nguyễn"), "mất bản đầu: \(texts)")
        XCTAssertTrue(texts.contains("bản 2 — Trần"), "mất bản giữa: \(texts)")
        XCTAssertFalse(
            texts.contains("bản 3 — Lê"),
            "bản HIỆN TẠI không được nằm trong lịch sử — nó đang ở trên đĩa")
    }

    /// Mới nhất đứng TRƯỚC: người ta đọc lịch sử từ gần tới xa.
    func testVersionsAreSortedNewestFirst() throws {
        let path = makeFile()
        let document = try makeDocument(at: path, text: "một")
        for text in ["hai", "ba", "bốn"] {
            document.buffer.applyEdits(
                [TextEdit(range: 0 ..< document.buffer.count, text: text)], label: "sửa")
            _ = try document.save()
        }
        let dates = DocumentVersions.versions(of: path).compactMap(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >), "lịch sử không sắp theo ngày")
    }

    /// File chưa từng lưu thì lịch sử RỖNG, không phải lỗi.
    func testUnknownFileHasNoVersions() {
        XCTAssertTrue(DocumentVersions.versions(of: makeFile("khong-co-that.txt")).isEmpty)
    }

    /// Ghi bản mới KHÔNG được làm hỏng phép lưu khi hệ thống từ chối.
    ///
    /// Lịch sử là tiện nghi; nội dung mới là thứ người dùng đang giữ trong tay. Ở đây kiểm bằng
    /// đường mà chắc chắn bị từ chối: file chưa tồn tại.
    func testRecordingIsBestEffortAndNeverBlocksSaving() throws {
        XCTAssertFalse(DocumentVersions.recordVersion(of: makeFile("chua-co.txt")))

        let path = makeFile("van-luu-duoc.txt")
        let document = try makeDocument(at: path, text: "nội dung")
        XCTAssertNoThrow(try document.save())
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "nội dung")
    }

    /// **File quá lớn thì KHÔNG ghi lịch sử.**
    ///
    /// Ghi một bản là chép cả file vào kho phiên bản. Với file hàng GB thì mỗi lần ⌘S là hàng
    /// GB đi vào đĩa mà người dùng không yêu cầu — họ chỉ bấm lưu.
    func testHugeFilesAreSkipped() throws {
        let path = makeFile("to.bin")
        // Vượt trần một chút là đủ; không cần dựng file thật to.
        let big = Data(repeating: 0x41, count: DocumentVersions.versioningLimit + 1)
        try big.write(to: URL(fileURLWithPath: path))
        XCTAssertFalse(
            DocumentVersions.recordVersion(of: path),
            "file quá trần mà vẫn ghi lịch sử")
    }

    /// Nội dung trả về là BYTE, nên byte hỏng đi qua nguyên vẹn.
    ///
    /// Giải mã sớm sẽ làm hỏng đúng những file mà sản phẩm này sinh ra để cứu — file bảng mã
    /// cũ, file UTF-8 có byte hỏng. Cùng bài học với `TextWindow` và byte hỏng.
    func testContentsSurviveInvalidUTF8() throws {
        let path = makeFile("hong.txt")
        var bytes = Array("Nguyễn".utf8)
        bytes.append(0xC3)                       // mở đầu một ký tự 2 byte rồi bỏ dở
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        XCTAssertTrue(DocumentVersions.recordVersion(of: path))
        try Data("đè lên".utf8).write(to: URL(fileURLWithPath: path))

        let versions = DocumentVersions.versions(of: path)
        let recovered = versions.compactMap { DocumentVersions.contents(of: $0) }
        XCTAssertTrue(recovered.contains(bytes), "byte hỏng không đi qua nguyên vẹn")
    }
}
