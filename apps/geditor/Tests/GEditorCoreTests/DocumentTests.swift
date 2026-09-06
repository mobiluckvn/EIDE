import XCTest
@testable import GEditorCore

/// Kiểm thử lớp ghép tài liệu (FR-DOC-304, FR-DOC-310, FR-DOC-311, FR-DOC-314, FR-ENC-202…204).
final class DocumentTests: XCTestCase {

    private var root = ""

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "/geditor-doc-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Trả lại quyền trước khi xóa: một test cố tình khóa thư mục để thử lỗi ghi.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root)
        try? FileManager.default.removeItem(atPath: root)
    }

    @discardableResult
    private func writeFile(_ name: String, _ bytes: [UInt8]) throws -> String {
        let path = "\(root)/\(name)"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        return path
    }

    private func readFile(_ path: String) throws -> [UInt8] {
        Array(try Data(contentsOf: URL(fileURLWithPath: path)))
    }

    // MARK: - Mở

    func testOpenUTF8() throws {
        let path = try writeFile("a.txt", Array("Tiếng Việt\nDòng hai\n".utf8))
        let document = try Document.open(path: path)

        XCTAssertEqual(document.encoding, .utf8)
        XCTAssertEqual(document.buffer.text, "Tiếng Việt\nDòng hai\n")
        XCTAssertEqual(document.buffer.lineCount, 2)
        XCTAssertFalse(document.isModified)
        XCTAssertFalse(document.isReadOnly)
        XCTAssertFalse(document.isLargeFileMode)
    }

    func testOpenStripsBOM() throws {
        let path = try writeFile("bom.txt", [0xEF, 0xBB, 0xBF] + Array("Việt".utf8))
        let document = try Document.open(path: path)

        XCTAssertEqual(document.encoding, .utf8BOM)
        XCTAssertEqual(document.buffer.text, "Việt", "BOM không được lọt vào nội dung")
    }

    func testOpenLegacyEncodingIsDetectedAndDecoded() throws {
        let text = "Cộng hòa Xã hội Chủ nghĩa Việt Nam. Thừa Thiên Huế, Đà Nẵng, Quảng Ngãi."
        let path = try writeFile("tcvn.txt", SingleByteCodec.tcvn3.encode(Array(text.utf8)).bytes)
        let document = try Document.open(path: path)

        XCTAssertEqual(document.encoding, .tcvn3)
        XCTAssertEqual(document.buffer.text, text)
        XCTAssertGreaterThan(document.detection.first?.confidence ?? 0, 0.5)
    }

    func testForcedEncodingSkipsDetection() throws {
        let path = try writeFile("x.txt", SingleByteCodec.viscii.encode(Array("Việt".utf8)).bytes)
        let document = try Document.open(path: path, encoding: .viscii)
        XCTAssertEqual(document.buffer.text, "Việt")
    }

    /// Large File Mode phải bật theo NGƯỠNG chứ không theo cảm tính (FR-DOC-310).
    /// Dùng file thưa để không phải ghi thật 256 MB xuống đĩa.
    func testLargeFileModeThreshold() throws {
        let path = "\(root)/lớn.txt"
        FileManager.default.createFile(atPath: path, contents: Data("dòng\n".utf8))
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.truncate(atOffset: UInt64(Document.largeFileThreshold + 1))
        try handle.close()

        let document = try Document.open(path: path, encoding: .utf8)
        XCTAssertTrue(document.isLargeFileMode)
    }

    // MARK: - Trạng thái sửa đổi

    func testModifiedFlagFollowsUndoHistory() throws {
        let path = try writeFile("m.txt", Array("gốc\n".utf8))
        let document = try Document.open(path: path)
        XCTAssertFalse(document.isModified)

        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "thêm ")], label: "Gõ")
        XCTAssertTrue(document.isModified)

        document.buffer.undo()
        XCTAssertFalse(document.isModified, "hoàn tác về đúng trạng thái đã lưu = chưa sửa")

        document.buffer.redo()
        XCTAssertTrue(document.isModified)
    }

    /// Undo về điểm đã lưu rồi sửa theo hướng KHÁC cho cùng độ sâu undo. Chỉ đếm độ sâu thì
    /// tài liệu bị coi là chưa sửa dù nội dung đã khác — đó là lý do có `historyBranch`.
    func testDivergentHistoryCountsAsModified() throws {
        let path = try writeFile("d.txt", Array("gốc\n".utf8))
        let document = try Document.open(path: path)

        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "A")], label: "A")
        try document.save()
        XCTAssertFalse(document.isModified)

        document.buffer.undo()
        XCTAssertTrue(document.isModified, "đã lùi khỏi trạng thái đã lưu")

        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "B")], label: "B")
        XCTAssertEqual(document.buffer.undoDepth, 1, "cùng độ sâu với lúc lưu")
        XCTAssertTrue(document.isModified, "nội dung khác thì phải là đã sửa")
    }

    func testSaveClearsModifiedFlag() throws {
        let path = try writeFile("s.txt", Array("gốc\n".utf8))
        let document = try Document.open(path: path)
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "mới ")], label: "Gõ")

        try document.save()
        XCTAssertFalse(document.isModified)
        XCTAssertEqual(String(decoding: try readFile(path), as: UTF8.self), "mới gốc\n")
    }

    // MARK: - TC-ENC-02: sửa mojibake tiếng Việt

    /// Luồng đầy đủ đúng như STP mô tả: mở file CSV xuất từ Excel (Windows-1258) bị hiểu
    /// nhầm bảng mã → "Diễn giải lại" sang 1258 → "Chuyển đổi sang" UTF-8 → lưu.
    /// Kết quả: chữ hiển thị đúng, file lưu là UTF-8 hợp lệ, khứ hồi không mất ký tự.
    func testRepairMojibakeEndToEnd() throws {
        let original = "Đơn hàng,Công ty Anh Đào,Thừa Thiên Huế\n"
        let path = try writeFile(
            "excel.csv", SingleByteCodec.windows1258.encode(Array(original.utf8)).bytes
        )

        // Mở NHẦM bằng VISCII — mô phỏng việc nhận diện đoán sai.
        let document = try Document.open(path: path, encoding: .viscii)
        XCTAssertNotEqual(document.buffer.text, original, "đọc sai bảng mã thì phải ra chữ khác")

        // Bước 1 — diễn giải lại. Byte trên đĩa KHÔNG đổi.
        let bytesBefore = try readFile(path)
        try document.reinterpret(as: .windows1258)
        XCTAssertEqual(document.buffer.text, original, "chữ phải đúng sau khi diễn giải lại")
        XCTAssertEqual(try readFile(path), bytesBefore, "diễn giải lại KHÔNG được đụng vào file")

        // Bước 2 — chuyển đổi sang UTF-8 rồi lưu.
        XCTAssertFalse(document.previewConversion(to: .utf8).isLossy)
        document.setTargetEncoding(.utf8)
        let result = try document.save()

        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.unrepresentable, 0)
        let saved = try readFile(path)
        XCTAssertTrue(ByteScan.isValidUTF8(saved), "file lưu phải là UTF-8 hợp lệ")
        XCTAssertEqual(String(decoding: saved, as: UTF8.self), original, "khứ hồi không mất ký tự")

        // Mở lại từ đầu: giờ nhận diện phải ra UTF-8.
        let reopened = try Document.open(path: path)
        XCTAssertEqual(reopened.encoding, .utf8)
        XCTAssertEqual(reopened.buffer.text, original)
    }

    /// Diễn giải lại là thao tác đảo lại được — nó đi qua lịch sử undo chung.
    func testReinterpretIsUndoable() throws {
        let path = try writeFile("r.txt", SingleByteCodec.tcvn3.encode(Array("Việt".utf8)).bytes)
        let document = try Document.open(path: path, encoding: .viscii)
        let wrong = document.buffer.text

        try document.reinterpret(as: .tcvn3)
        XCTAssertEqual(document.buffer.text, "Việt")

        document.buffer.undo()
        XCTAssertEqual(document.buffer.text, wrong, "đoán sai bảng mã thì phải lùi lại được")
    }

    /// Chỗ dễ mất dữ liệu nhất: diễn giải lại đọc lại BYTE GỐC, nên nó vứt mọi thay đổi
    /// chưa lưu. Phải từ chối chứ không được im lặng làm.
    func testReinterpretRefusesModifiedDocument() throws {
        let path = try writeFile("rm.txt", Array("nội dung\n".utf8))
        let document = try Document.open(path: path)
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "sửa ")], label: "Gõ")

        XCTAssertThrowsError(try document.reinterpret(as: .viscii)) { error in
            guard case Document.Failure.cannotReinterpretModifiedDocument = error else {
                return XCTFail("nhận \(error)")
            }
        }
        XCTAssertEqual(document.buffer.text, "sửa nội dung\n", "nội dung phải còn nguyên")
    }

    // MARK: - Lưu (FR-DOC-314)

    /// Bảng mã đích không chứa hết ký tự thì KHÔNG được lưu lặng lẽ.
    func testLossySaveRequiresExplicitConsent() throws {
        let path = try writeFile("l.txt", Array("Việt 日本\n".utf8))
        let document = try Document.open(path: path)
        document.setTargetEncoding(.tcvn3)

        XCTAssertThrowsError(try document.save()) { error in
            guard case Document.Failure.lossyConversion(let preview) = error else {
                return XCTFail("nhận \(error)")
            }
            XCTAssertEqual(preview.unrepresentable, 2)
            XCTAssertTrue(preview.warning?.contains("日") == true)
        }
        XCTAssertEqual(String(decoding: try readFile(path), as: UTF8.self), "Việt 日本\n",
                       "từ chối lưu thì file phải nguyên vẹn")

        let result = try document.save(allowLossy: true)
        XCTAssertEqual(result.unrepresentable, 2)
    }

    func testSaveAsChangesPathEncodingAndEOL() throws {
        let path = try writeFile("as.txt", Array("một\r\nhai\r\n".utf8))
        let document = try Document.open(path: path)
        XCTAssertEqual(document.eol, .crlf)

        let newPath = "\(root)/mới.txt"
        let result = try document.save(to: newPath, encoding: .viscii, eol: .lf)

        XCTAssertEqual(document.path, newPath)
        XCTAssertEqual(document.encoding, .viscii)
        XCTAssertEqual(result.bytesWritten, try readFile(newPath).count)
        XCTAssertEqual(document.buffer.text, "một\nhai\n", "buffer và file phải khớp nhau")
        XCTAssertEqual(
            SingleByteCodec.viscii.decode(try readFile(newPath)),
            Array("một\nhai\n".utf8)
        )
        XCTAssertEqual(String(decoding: try readFile(path), as: UTF8.self), "một\r\nhai\r\n",
                       "file cũ không bị đụng tới")
    }

    /// TC-DOC-08 — tài liệu chỉ đọc: mọi đường lưu bị chặn, Lưu thành… vẫn chạy.
    func testReadOnlyDocumentRefusesSave() throws {
        let path = try writeFile("ro.txt", Array("nội dung\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: path)

        let document = try Document.open(path: path)
        XCTAssertTrue(document.isReadOnly)
        XCTAssertThrowsError(try document.save()) { error in
            guard case Document.Failure.readOnly = error else { return XCTFail("nhận \(error)") }
        }

        let copy = "\(root)/bản-sao.txt"
        XCTAssertNoThrow(try document.save(to: copy))
        XCTAssertEqual(String(decoding: try readFile(copy), as: UTF8.self), "nội dung\n")
        XCTAssertFalse(document.isReadOnly, "sau Lưu thành… quyền phải tính theo file MỚI")
    }

    /// TC-DOC-02 — ghi hỏng giữa chừng thì file gốc phải nguyên vẹn 100%.
    ///
    /// Mô phỏng bằng cách khóa quyền ghi của THƯ MỤC: `AtomicFileWriter` không tạo được file
    /// tạm, nên hỏng ở đúng bước đầu tiên — trước khi có bất kỳ khả năng nào đụng tới file đích.
    func testFailedSaveLeavesOriginalIntact() throws {
        let path = try writeFile("atomic.txt", Array("nội dung gốc\n".utf8))
        let document = try Document.open(path: path)
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "mới ")], label: "Gõ")

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root) }

        XCTAssertThrowsError(try document.save())
        XCTAssertEqual(String(decoding: try readFile(path), as: UTF8.self), "nội dung gốc\n")
        XCTAssertTrue(document.isModified, "lưu hỏng thì tài liệu vẫn là đã sửa")

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root)
            .filter { $0.hasPrefix(".geditor-") }
        XCTAssertTrue(leftovers.isEmpty, "không được để lại file rác: \(leftovers)")
    }

    // MARK: - EOL (TC-ENC-04)

    func testMixedEOLIsReported() throws {
        let path = try writeFile("mixed.txt", Array("một\r\nhai\nba\r\n".utf8))
        let document = try Document.open(path: path)

        XCTAssertTrue(document.hasMixedEOL, "file trộn EOL phải được cảnh báo")
        XCTAssertEqual(document.eol, .crlf, "kiểu chiếm đa số")

        let edits = document.normalizeEOL(to: .lf)
        document.buffer.applyEdits(edits, label: "Chuẩn hóa EOL")
        XCTAssertEqual(document.buffer.text, "một\nhai\nba\n")

        document.refreshEOLReport()
        XCTAssertFalse(document.hasMixedEOL)
        XCTAssertEqual(document.eol, .lf)

        XCTAssertTrue(document.buffer.undo())
        XCTAssertEqual(document.buffer.text, "một\r\nhai\nba\r\n", "chuẩn hóa là MỘT bước undo")
    }

    // MARK: - File đổi bên ngoài (TC-DOC-06)

    func testExternalChangeDetection() throws {
        let path = try writeFile("ext.txt", Array("gốc\n".utf8))
        let document = try Document.open(path: path)
        XCTAssertEqual(document.externalChange(), .unchanged)

        // Thời gian sửa có độ phân giải giây trên vài hệ thống file; đặt thẳng cho chắc.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path
        )
        try Data("khác\n".utf8).write(to: URL(fileURLWithPath: path))
        XCTAssertEqual(document.externalChange(), .modified)

        try document.revert()
        XCTAssertEqual(document.buffer.text, "khác\n")
        XCTAssertEqual(document.externalChange(), .unchanged)
        XCTAssertFalse(document.isModified)

        try FileManager.default.removeItem(atPath: path)
        XCTAssertEqual(document.externalChange(), .deleted)
    }

    func testUntitledDocumentHasNoExternalState() {
        let document = Document.untitled()
        XCTAssertEqual(document.externalChange(), .unknown)
        XCTAssertNil(document.path)
        XCTAssertFalse(document.isModified)
        XCTAssertThrowsError(try document.save())
    }

    // MARK: - Bản nháp (FR-DOC-304)

    func testSnapshotRoundTrip() throws {
        let store = SnapshotStore(root: URL(fileURLWithPath: root).appendingPathComponent("nháp"))
        let path = try writeFile("snap.txt", Array("nội dung\n".utf8))
        let document = try Document.open(path: path)
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "chưa lưu ")], label: "Gõ")

        try document.writeSnapshot(caretOffset: 5, store: store)

        let pending = try store.pendingSnapshots()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].originalPath, path)
        XCTAssertEqual(pending[0].caretOffset, 5)
        XCTAssertEqual(
            String(decoding: try store.content(for: document.id), as: UTF8.self),
            "chưa lưu nội dung\n"
        )

        try document.discardSnapshot(store: store)
        XCTAssertTrue(try store.pendingSnapshots().isEmpty)
    }

    /// Sửa vài chỗ trong một tài liệu lớn thì bản nháp phải là DELTA và nhỏ xíu.
    ///
    /// Bản đầu luôn ghi cả nội dung: với file 1 GB đó là cấp phát 1 GB rồi ghi 1 GB xuống đĩa
    /// MỖI CHU KỲ autosave. Test này chốt lại rằng không quay về cách đó.
    func testLargeDocumentUsesDeltaSnapshot() throws {
        let store = SnapshotStore(root: URL(fileURLWithPath: root).appendingPathComponent("nháp"))
        let content = String(repeating: "dòng dữ liệu mẫu\n", count: 20_000)
        let path = try writeFile("lớn.txt", Array(content.utf8))
        let document = try Document.open(path: path)
        let originalSize = document.buffer.count

        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "THÊM ")], label: "Gõ")
        try document.writeSnapshot(caretOffset: 3, store: store)

        let manifest = try XCTUnwrap(try store.pendingSnapshots().first)
        XCTAssertEqual(manifest.kind, .delta)

        let written = try store.content(for: document.id).count
        XCTAssertLessThan(
            written, originalSize / 100,
            "bản nháp delta (\(written) byte) phải nhỏ hơn nội dung (\(originalSize) byte) rất nhiều"
        )
    }

    /// Khôi phục từ delta phải dựng lại CẢ nội dung LẪN lịch sử undo — người dùng lùi được về
    /// trước từng thao tác, không chỉ về bản đã lưu.
    func testRestoreFromDeltaRebuildsContentAndHistory() throws {
        let store = SnapshotStore(root: URL(fileURLWithPath: root).appendingPathComponent("nháp"))
        let content = String(repeating: "một dòng\n", count: 5_000)
        let path = try writeFile("delta.txt", Array(content.utf8))
        let document = try Document.open(path: path)

        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "A")], label: "Gõ A")
        document.buffer.applyEdits([TextEdit.insert(at: 1, text: "B")], label: "Gõ B")
        let expected = document.buffer.text
        try document.writeSnapshot(caretOffset: 2, store: store)
        XCTAssertEqual(try store.pendingSnapshots().first?.kind, .delta)

        let restored = try Document.restore(try XCTUnwrap(store.pendingSnapshots().first), store: store)
        XCTAssertEqual(restored.buffer.text, expected)
        XCTAssertEqual(restored.buffer.undoDepth, 2, "phải dựng lại đúng hai bước undo")

        XCTAssertTrue(restored.buffer.undo())
        XCTAssertTrue(restored.buffer.text.hasPrefix("Amột"), "lùi được về trước thao tác thứ hai")
    }

    /// Tài liệu chưa có đường dẫn thì không phát lại được trên file gốc — phải ghi đầy đủ.
    func testUntitledDocumentUsesFullSnapshot() throws {
        let store = SnapshotStore(root: URL(fileURLWithPath: root).appendingPathComponent("nháp"))
        let document = Document.untitled()
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "nội dung mới")], label: "Gõ")
        try document.writeSnapshot(caretOffset: 0, store: store)

        let manifest = try XCTUnwrap(try store.pendingSnapshots().first)
        XCTAssertEqual(manifest.kind, .full)

        let restored = try Document.restore(manifest, store: store)
        XCTAssertEqual(restored.buffer.text, "nội dung mới")
    }

    /// File gốc bị đổi bên ngoài thì delta không còn phát lại đúng được — phải ghi đầy đủ.
    func testExternallyChangedFileForcesFullSnapshot() throws {
        let store = SnapshotStore(root: URL(fileURLWithPath: root).appendingPathComponent("nháp"))
        let path = try writeFile("đổi.txt", Array(String(repeating: "x\n", count: 20_000).utf8))
        let document = try Document.open(path: path)
        document.buffer.applyEdits([TextEdit.insert(at: 0, text: "A")], label: "Gõ")

        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path
        )
        try Data("nội dung khác\n".utf8).write(to: URL(fileURLWithPath: path))

        try document.writeSnapshot(caretOffset: 0, store: store)
        XCTAssertEqual(try store.pendingSnapshots().first?.kind, .full,
                       "file gốc đã đổi thì phát lại nhật ký sẽ ra nội dung sai")
    }
}
