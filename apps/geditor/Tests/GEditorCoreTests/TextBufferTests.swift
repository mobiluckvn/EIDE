import XCTest
@testable import GEditorCore

/// Truy vết: FR-CORE-004 (undo/redo, gom nhóm theo thao tác logic), ADR-02 (piece table).
final class TextBufferTests: XCTestCase {

    func testPieceTableReplacePreservesContent() {
        let table = PieceTable(text: "xin chào thế giới")
        // "chào" chiếm 5 byte UTF-8 (à = 2 byte) — offset của lõi là BYTE, không phải ký tự.
        table.replace(4 ..< 9, with: Array("CHÀO".utf8))
        XCTAssertEqual(table.utf8String, "xin CHÀO thế giới")
        XCTAssertEqual(table.count, Array("xin CHÀO thế giới".utf8).count)
    }

    func testPieceTableInsertAndDelete() {
        let table = PieceTable(text: "abcdef")
        table.replace(3 ..< 3, with: Array("XY".utf8))   // chèn
        XCTAssertEqual(table.utf8String, "abcXYdef")
        table.replace(0 ..< 3, with: [])                  // xóa
        XCTAssertEqual(table.utf8String, "XYdef")
    }

    func testOriginalSourceIsNeverMutated() {
        let source = MemoryByteSource("nguyên bản")
        let table = PieceTable(original: source)
        table.replace(0 ..< 6, with: Array("SỬA".utf8))
        XCTAssertEqual(source.count, Array("nguyên bản".utf8).count, "file gốc không được đụng tới")
    }

    /// FR-CORE-004: mọi thao tác hàng loạt là MỘT bước undo.
    func testBatchEditIsSingleUndoStep() {
        let buffer = TextBuffer(text: "aaa\naaa\naaa\n")
        let edits = [
            TextEdit(range: 0 ..< 3, text: "bbb"),
            TextEdit(range: 4 ..< 7, text: "bbb"),
            TextEdit(range: 8 ..< 11, text: "bbb"),
        ]
        buffer.applyEdits(edits, label: "Thay tất cả")
        XCTAssertEqual(buffer.text, "bbb\nbbb\nbbb\n")

        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, "aaa\naaa\naaa\n", "3 vị trí phải gỡ trong ĐÚNG một lần undo")
        XCTAssertFalse(buffer.canUndo)
    }

    func testUndoRedoRoundTripWithDifferentLengths() {
        let buffer = TextBuffer(text: "một hai ba")
        buffer.applyEdits([
            TextEdit(range: 0 ..< 3, text: "MỘT-DÀI-HƠN"),
            TextEdit(range: 8 ..< 10, text: "B"),
        ], label: "Sửa hỗn hợp")
        let afterEdit = buffer.text

        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, "một hai ba")
        XCTAssertTrue(buffer.redo())
        XCTAssertEqual(buffer.text, afterEdit)
    }

    func testUndoLabelDrivesEditMenu() {
        let buffer = TextBuffer(text: "x")
        buffer.replace(0 ..< 1, with: "y", label: "Sắp xếp dòng")
        XCTAssertEqual(buffer.undoLabel, "Sắp xếp dòng")
    }

    func testLineAccess() {
        let buffer = TextBuffer(text: "dòng một\ndòng hai\r\ndòng ba")
        XCTAssertEqual(buffer.lineCount, 3)
        XCTAssertEqual(buffer.line(0), "dòng một")
        XCTAssertEqual(buffer.line(1), "dòng hai", "CRLF phải bị cắt khỏi nội dung dòng")
        XCTAssertEqual(buffer.line(2), "dòng ba")
    }

    func testLineIndexInvalidatedAfterEdit() {
        let buffer = TextBuffer(text: "a\nb\n")
        XCTAssertEqual(buffer.lineCount, 2)
        buffer.applyEdits([TextEdit(range: 4 ..< 4, text: "c\nd\n")], label: "Chèn")
        XCTAssertEqual(buffer.lineCount, 4, "chỉ mục dòng phải được dựng lại sau khi sửa")
    }

    func testPositionLookup() {
        let buffer = TextBuffer(text: "abc\ndef\nghi")
        let position = buffer.position(atOffset: 5)
        XCTAssertEqual(position.line, 1)
        XCTAssertEqual(position.byteColumn, 1)
    }

    /// `id` phải là DUY NHẤT trong cả phiên, kể cả khi buffer cũ đã bị giải phóng.
    ///
    /// Đây là bất biến mà mọi bản nhớ tạm khoá theo `(buffer, revision)` dựa vào. Bản đầu khoá
    /// theo `ObjectIdentifier`, tức ĐỊA CHỈ ô nhớ — và địa chỉ được cấp lại. Bài này chứng minh
    /// việc cấp lại có thật (in ra số lần trùng địa chỉ), rồi đòi `id` KHÔNG bao giờ trùng.
    ///
    /// Triệu chứng ngoài đời: đóng một tab JSON, mở tab JSON khác, chạy JSONPath — và nhận kết
    /// quả của tài liệu đã đóng, vì `revision` đếm từ 0 trong từng buffer nên hai tài liệu vừa
    /// mở đều mang revision 0. Bộ tự kiểm bắt được nó ở dạng trượt chập chờn ~5% số lượt.
    func testBufferIDNeverRepeatsEvenWhenAddressIsReused() {
        var ids: [Int] = []
        var addresses: [ObjectIdentifier] = []
        for i in 0 ..< 500 {
            // Mỗi vòng buffer cũ ra khỏi phạm vi và được giải phóng NGAY, nên vòng sau rất dễ
            // được cấp đúng ô nhớ ấy.
            let buffer = TextBuffer(text: "nội dung \(i)")
            ids.append(buffer.id)
            addresses.append(ObjectIdentifier(buffer))
        }

        let diaChiTrung = addresses.count - Set(addresses).count
        // Không ĐÒI phải có trùng địa chỉ — trình cấp phát không hứa điều đó. Chỉ ghi lại, để
        // người đọc sau biết con số này thường lớn và hiểu vì sao khoá theo địa chỉ là sai.
        print("[TextBuffer] địa chỉ bị cấp lại \(diaChiTrung)/\(addresses.count) lần")

        XCTAssertEqual(Set(ids).count, ids.count,
                       "id buffer bị trùng — mọi bản nhớ khoá theo (buffer, revision) sẽ trúng nhầm")
    }

    /// Hai buffer SỐNG CÙNG LÚC cũng phải khác id — vế còn lại của cùng một bất biến.
    func testBufferIDDistinctAmongLiveBuffers() {
        let a = TextBuffer(text: "a")
        let b = TextBuffer(text: "b")
        XCTAssertNotEqual(a.id, b.id)
        // Và id KHÔNG đổi khi nội dung đổi: nó định danh buffer, không định danh nội dung.
        let truoc = a.id
        a.applyEdits([TextEdit(range: 1 ..< 1, text: "x")], label: "Chèn")
        XCTAssertEqual(a.id, truoc)
        XCTAssertEqual(a.revision, 1, "revision mới là thứ đổi theo nội dung")
    }
}
