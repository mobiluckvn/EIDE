import XCTest
@testable import GEditorCore

/// Nhiều caret / nhiều vùng chọn (FR-CORE-001).
///
/// `NSTextView` chỉ có một caret gõ được nên toàn bộ mô hình này là của GEditor — và vì thế
/// nó phải được kiểm kỹ hơn thứ mượn của hệ thống.
final class MultiSelectionTests: XCTestCase {

    private func apply(_ edits: [TextEdit], to buffer: TextBuffer) -> String {
        buffer.applyEdits(edits, label: "kiểm")
        return buffer.text
    }

    // MARK: - Bất biến

    func testAlwaysSortedAscending() {
        let selection = MultiSelection([30 ..< 30, 10 ..< 10, 20 ..< 20])
        XCTAssertEqual(selection.ranges.map(\.lowerBound), [10, 20, 30])
    }

    /// Hai caret trùng chỗ phải GỘP: gõ một ký tự mà chèn hai lần là lỗi người dùng thấy ngay.
    func testDuplicateCaretsMerge() {
        var selection = MultiSelection(caretAt: 5)
        selection.add(5 ..< 5)
        XCTAssertEqual(selection.count, 1)
    }

    func testOverlappingSelectionsMerge() {
        let selection = MultiSelection([0 ..< 10, 5 ..< 20])
        XCTAssertEqual(selection.ranges, [0 ..< 20])
    }

    func testNeverEmpty() {
        XCTAssertEqual(MultiSelection([]).count, 1)
    }

    func testCollapseToPrimary() {
        var selection = MultiSelection([0 ..< 0, 10 ..< 10, 20 ..< 20], primaryIndex: 1)
        selection.collapseToPrimary()
        XCTAssertEqual(selection.ranges, [10 ..< 10])
    }

    /// Vùng vừa thêm phải thành vùng CHÍNH — người dùng vừa trỏ vào đó.
    func testAddedRangeBecomesPrimary() {
        var selection = MultiSelection(caretAt: 0)
        selection.add(50 ..< 50)
        XCTAssertEqual(selection.primary, 50 ..< 50)
    }

    // MARK: - Gõ trên nhiều caret

    func testInsertAtEveryCaret() {
        let buffer = TextBuffer(text: "a\nb\nc\n")
        let selection = MultiSelection([0 ..< 0, 2 ..< 2, 4 ..< 4])
        XCTAssertEqual(apply(selection.edits(inserting: "X"), to: buffer), "Xa\nXb\nXc\n")
    }

    func testTypingReplacesSelections() {
        let buffer = TextBuffer(text: "một hai ba\n")
        // Chọn "một" và "hai".
        let selection = MultiSelection([0 ..< 5, 6 ..< 9])
        XCTAssertEqual(apply(selection.edits(inserting: "X"), to: buffer), "X X ba\n")
    }

    /// FR-CORE-004: gõ một ký tự với nhiều caret vẫn là MỘT bước undo.
    func testTypingIsOneUndoStep() {
        let buffer = TextBuffer(text: (0 ..< 1_000).map { "dòng \($0)" }.joined(separator: "\n"))
        let carets = (0 ..< 1_000).map { line -> Range<Int> in
            let offset = buffer.offset(ofLineStart: line)
            return offset ..< offset
        }
        let selection = MultiSelection(carets)
        let before = buffer.text
        let depth = buffer.undoDepth

        buffer.applyEdits(selection.edits(inserting: "> "), label: "Gõ")
        XCTAssertEqual(buffer.undoDepth, depth + 1, "1.000 caret phải là MỘT bước undo")
        XCTAssertTrue(buffer.text.hasPrefix("> dòng 0"))
        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, before)
    }

    // MARK: - Xóa

    /// Backspace phải xóa MỘT KÝ TỰ, không phải một byte — "ệ" là 3 byte.
    func testBackspaceDeletesWholeCharacter() {
        let buffer = TextBuffer(text: "Việt\n")
        let selection = MultiSelection(caretAt: 5)   // ngay sau "ệ"
        XCTAssertEqual(apply(selection.editsDeletingBackward(in: buffer), to: buffer), "Vit\n")
    }

    func testBackspaceAtStartDoesNothing() {
        let buffer = TextBuffer(text: "abc")
        XCTAssertTrue(MultiSelection(caretAt: 0).editsDeletingBackward(in: buffer).isEmpty)
    }

    func testForwardDeleteRemovesWholeCharacter() {
        let buffer = TextBuffer(text: "Việt\n")
        let selection = MultiSelection(caretAt: 2)   // ngay trước "ệ"
        XCTAssertEqual(apply(selection.editsDeletingForward(in: buffer), to: buffer), "Vit\n")
    }

    func testBackspaceOnMultipleCarets() {
        // "ax\nbx\ncx\n" — caret ở 2, 5, 8 là ngay SAU chữ "x" của mỗi dòng.
        let buffer = TextBuffer(text: "ax\nbx\ncx\n")
        let selection = MultiSelection([2 ..< 2, 5 ..< 5, 8 ..< 8])
        XCTAssertEqual(apply(selection.editsDeletingBackward(in: buffer), to: buffer), "a\nb\nc\n")
    }

    // MARK: - Caret trôi sau khi sửa

    /// Chèn "x" vào ba caret thì caret thứ hai đã dịch 1 byte, thứ ba dịch 2 byte.
    ///
    /// Không tính lại thì caret trôi dần và ký tự THỨ HAI rơi sai chỗ — lỗi không lộ ra ở lần
    /// gõ đầu tiên, nên phải có test.
    func testCaretsMoveAfterInsertion() {
        let buffer = TextBuffer(text: "a\nb\nc\n")
        let selection = MultiSelection([0 ..< 0, 2 ..< 2, 4 ..< 4])
        let edits = selection.edits(inserting: "X")
        buffer.applyEdits(edits, label: "gõ")

        let moved = selection.afterApplying(edits)
        XCTAssertEqual(moved.ranges.map(\.lowerBound), [1, 4, 7])

        // Gõ tiếp phải ra đúng "XXa\nXXb\nXXc\n".
        buffer.applyEdits(moved.edits(inserting: "X"), label: "gõ")
        XCTAssertEqual(buffer.text, "XXa\nXXb\nXXc\n")
    }

    func testCaretsMoveAfterDeletion() {
        let buffer = TextBuffer(text: "ax\nbx\ncx\n")
        let selection = MultiSelection([2 ..< 2, 5 ..< 5, 8 ..< 8])
        let edits = selection.editsDeletingBackward(in: buffer)
        buffer.applyEdits(edits, label: "xóa")

        let moved = selection.afterApplying(edits)
        XCTAssertEqual(buffer.text, "a\nb\nc\n")
        XCTAssertEqual(moved.ranges.map(\.lowerBound), [1, 3, 5])
    }

    /// Gõ nhiều ký tự khi các vùng chọn KHÔNG rỗng — ca đã lọt lưới và chỉ lộ ra khi bấm thật.
    ///
    /// Ký tự đầu thay đúng cả ba vùng, ký tự thứ hai trở đi dồn hết vào một chỗ: caret sau khi
    /// thay bị tính lùi về ĐẦU vùng thay vì nhảy tới cuối phần vừa gõ. Bộ test cũ không bắt
    /// được vì mọi ca gõ nhiều lần đều dùng caret RỖNG.
    func testRepeatedTypingOverSelectionsStaysAligned() {
        let text = "ERROR một\nOK hai\nERROR ba\n"
        let buffer = TextBuffer(text: text)

        // Tính offset TỪ NỘI DUNG, không gõ số tay: đếm byte của chữ có dấu bằng đầu là cách
        // chắc chắn sai, và đã sai bốn lần trong đợt này.
        let bytes = Array(text.utf8)
        func range(of needle: String, from start: Int) -> Range<Int> {
            let pattern = Array(needle.utf8)
            let index = bytes[start...].firstRange(of: pattern)!.lowerBound
            return index ..< index + pattern.count
        }
        let first = range(of: "ERROR", from: 0)
        let middle = range(of: "OK", from: first.upperBound)
        let last = range(of: "ERROR", from: middle.upperBound)
        var selection = MultiSelection([first, middle, last])
        for character in "LOI" {
            let edits = selection.edits(inserting: String(character))
            buffer.applyEdits(edits, label: "gõ")
            selection = selection.afterApplying(edits)
        }
        XCTAssertEqual(buffer.text, "LOI một\nLOI hai\nLOI ba\n")
        XCTAssertEqual(selection.count, 3, "vẫn phải còn ba caret sau khi gõ")
    }

    /// Gõ mười lần liên tiếp trên ba caret: kết quả phải giống hệt gõ mười lần trên một caret,
    /// lặp ba lần. Đây là phép kiểm bắt được mọi kiểu trôi caret.
    func testRepeatedTypingStaysAligned() {
        let buffer = TextBuffer(text: "a\nb\nc\n")
        var selection = MultiSelection([0 ..< 0, 2 ..< 2, 4 ..< 4])
        for character in "0123456789" {
            let edits = selection.edits(inserting: String(character))
            buffer.applyEdits(edits, label: "gõ")
            selection = selection.afterApplying(edits)
        }
        XCTAssertEqual(buffer.text, "0123456789a\n0123456789b\n0123456789c\n")
    }

    // MARK: - Caret CHẠM vùng chọn bên cạnh

    /// Caret đứng ngay SAU một vùng chọn: phép xoá lùi của nó không được thò vào vùng ấy.
    ///
    /// `[5,8)` và caret `[8,8)` là trạng thái hợp lệ — hai vùng chọn chỉ cấm CHỒNG nhau, chạm
    /// nhau thì được. Nhưng caret xoá lùi một ký tự thành `[7,8)`, nằm gọn trong `[5,8)`, và
    /// `applyEdits` có `precondition` cho bất biến "không giao nhau": app SẬP.
    ///
    /// Người dùng tới đây dễ: ⌘D chọn một từ, Cmd+Click thêm caret ngay sau nó, rồi Backspace.
    /// Bộ chạy dài `--soak` bắt được ở hạt giống 3, bước 8861 (NFR-REL-03).
    func testBackwardDeleteDoesNotReachIntoThePrecedingSelection() {
        let buffer = TextBuffer(text: "0123456789\n")
        let selection = MultiSelection([5 ..< 8, 8 ..< 8])
        let edits = selection.editsDeletingBackward(in: buffer)

        let sorted = edits.map { $0.range }.sorted { $0.lowerBound < $1.lowerBound }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.upperBound, later.lowerBound, "hai vùng sửa giao nhau")
        }
        buffer.applyEdits(edits, label: "xoá")
        XCTAssertEqual(buffer.text, "0123489\n", "chỉ vùng chọn bị xoá; caret không có gì để xoá thêm")
    }

    /// Chiều ngược lại: caret đứng ngay TRƯỚC một vùng chọn.
    func testForwardDeleteDoesNotReachIntoTheFollowingSelection() {
        let buffer = TextBuffer(text: "0123456789\n")
        let selection = MultiSelection([5 ..< 5, 5 ..< 8])
        let edits = selection.editsDeletingForward(in: buffer)

        let sorted = edits.map { $0.range }.sorted { $0.lowerBound < $1.lowerBound }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.upperBound, later.lowerBound, "hai vùng sửa giao nhau")
        }
        buffer.applyEdits(edits, label: "xoá")
        XCTAssertEqual(buffer.text, "0123489\n")
    }

    /// Ca thường vẫn phải chạy đúng — bài trên xanh mà bài này đỏ thì bản sửa đã đi quá tay.
    func testBackwardDeleteStillWorksOnSeparateCarets() {
        let buffer = TextBuffer(text: "abc def ghi\n")
        let selection = MultiSelection([3 ..< 3, 7 ..< 7])
        buffer.applyEdits(selection.editsDeletingBackward(in: buffer), label: "xoá")
        XCTAssertEqual(buffer.text, "ab de ghi\n")
    }

    // MARK: - Thu vùng chọn về tài liệu hiện tại

    /// Vùng chọn trỏ QUÁ cuối tài liệu phải thu lại, không được lọt xuống buffer.
    ///
    /// Vùng chọn sống ở tầng giao diện còn nội dung sống trong buffer, và hai thứ đổi ở hai
    /// nhịp khác nhau. Mọi hàm đọc buffer đều có `precondition`, nên một vùng chọn lạc hậu
    /// không hiện sai một con số — nó làm app SẬP. Bộ chạy dài `--soak` bắt được ba lần.
    func testClampPullsRangesInsideTheDocument() {
        let selection = MultiSelection([0 ..< 3, 10 ..< 20])
        XCTAssertEqual(selection.clamped(to: 5).ranges, [0 ..< 3, 5 ..< 5])
    }

    /// Tài liệu rỗng: mọi vùng chọn thu về caret ở 0, và vẫn còn ĐÚNG MỘT vùng.
    ///
    /// Bất biến "luôn có ít nhất một" phải sống sót qua phép thu — không thì mọi chỗ gọi
    /// `primary` sẽ chỉ mục ra ngoài mảng.
    func testClampToEmptyDocumentKeepsOneCaret() {
        let clamped = MultiSelection([4 ..< 9, 12 ..< 12]).clamped(to: 0)
        XCTAssertEqual(clamped.ranges, [0 ..< 0])
        XCTAssertEqual(clamped.primary, 0 ..< 0)
    }

    /// Đã nằm trong tài liệu thì phép thu KHÔNG được đụng vào.
    func testClampLeavesValidSelectionAlone() {
        let selection = MultiSelection([1 ..< 2, 4 ..< 6], primaryIndex: 1)
        XCTAssertEqual(selection.clamped(to: 10), selection)
        XCTAssertEqual(selection.clamped(to: 10).primaryIndex, 1)
    }
}

/// Cmd+D — chọn lần xuất hiện kế tiếp (FR-CORE-001).
final class OccurrenceSearchTests: XCTestCase {

    private let text = "một hai một ba một\nhai bốn\n"

    func testFindsNextOccurrence() {
        let buffer = TextBuffer(text: text)
        let first = OccurrenceSearch.next(Array("một".utf8), in: buffer, after: 0)
        XCTAssertEqual(first?.lowerBound, 0)
        let second = OccurrenceSearch.next(Array("một".utf8), in: buffer, after: 1)
        XCTAssertEqual(second.map { String(decoding: buffer.bytes(in: $0), as: UTF8.self) }, "một")
        XCTAssertGreaterThan(second!.lowerBound, 1)
    }

    /// Tới lần cuối rồi bấm tiếp phải QUAY VÒNG về đầu, không được im lặng.
    func testWrapsAround() {
        let buffer = TextBuffer(text: text)
        let last = OccurrenceSearch.next(Array("bốn".utf8), in: buffer, after: 0)!
        let wrapped = OccurrenceSearch.next(Array("bốn".utf8), in: buffer, after: last.upperBound)
        XCTAssertEqual(wrapped, last, "phải quay vòng và tìm lại chính nó")
    }

    func testReturnsNilWhenAbsent() {
        XCTAssertNil(OccurrenceSearch.next(Array("năm".utf8), in: TextBuffer(text: text), after: 0))
    }

    /// Chữ có dấu phải là MỘT từ: "Nguyễn" không được cắt ở byte đầu của "ễ".
    func testWordAroundOffsetHandlesVietnamese() {
        let buffer = TextBuffer(text: "xin chào Nguyễn Trãi\n")
        let word = OccurrenceSearch.word(at: 12, in: buffer)
        XCTAssertEqual(String(decoding: buffer.bytes(in: word), as: UTF8.self), "Nguyễn")
    }

    /// Caret đứng NGAY SAU một từ thì lấy từ đó — giống double-click ở cuối từ, và là thứ
    /// người dùng muốn khi bấm Cmd+D mà chưa chọn gì.
    func testWordJustAfterWordTakesThatWord() {
        // "một" là 5 byte (m + ộ×3 + t) nên dấu cách nằm ở offset 5.
        let buffer = TextBuffer(text: "một hai\n")
        let word = OccurrenceSearch.word(at: 5, in: buffer)
        XCTAssertEqual(String(decoding: buffer.bytes(in: word), as: UTF8.self), "một")
    }

    /// Đứng giữa hai dấu cách thì KHÔNG có từ nào — không được vơ bừa từ ở xa.
    func testWordBetweenSeparatorsIsEmpty() {
        let buffer = TextBuffer(text: "một  hai\n")
        XCTAssertTrue(OccurrenceSearch.word(at: 6, in: buffer).isEmpty)
    }

    /// Offset rơi vào GIỮA một ký tự nhiều byte vẫn phải cho ra trọn từ.
    func testWordFromInsideMultiByteCharacter() {
        let buffer = TextBuffer(text: "một hai\n")
        let word = OccurrenceSearch.word(at: 3, in: buffer)
        XCTAssertEqual(String(decoding: buffer.bytes(in: word), as: UTF8.self), "một")
    }

    /// Từ DÀI HƠN một lô đọc vẫn phải ra trọn vẹn.
    ///
    /// `word(at:)` đọc theo lô 4 KB thay vì từng byte (⌘D giữa một từ 1 MB từng tốn 463 ms).
    /// Cái bẫy mà cách sửa ấy đẻ ra là đúng chỗ này: một từ dài hơn lô thì phép dò phải đi
    /// tiếp sang lô kế, không được dừng ở biên lô. Một chuỗi base64 hay một token JSON thu gọn
    /// dài hơn 4 KB là chuyện thường.
    func testWordLongerThanOneChunk() {
        let long = String(repeating: "a", count: 10_000)
        let buffer = TextBuffer(text: "x " + long + " y\n")
        let word = OccurrenceSearch.word(at: 2 + long.count / 2, in: buffer)
        XCTAssertEqual(word, 2 ..< (2 + long.count))
    }

    /// Và trọn vẹn cả khi từ bắt đầu đúng ở đầu tài liệu, không có gì chặn phía trước.
    func testWordLongerThanOneChunkAtDocumentStart() {
        let long = String(repeating: "b", count: 9_000)
        let buffer = TextBuffer(text: long + " y\n")
        XCTAssertEqual(OccurrenceSearch.word(at: 4_500, in: buffer), 0 ..< long.count)
    }

    /// Biên ký tự cũng đọc theo lô — kiểm cả hai chiều trên chữ nhiều byte.
    func testCharacterBoundariesAroundMultiByteCharacters() {
        // "ệ" là 3 byte. Đi tới và lùi lại phải khớp nhau ở mọi bước.
        let buffer = TextBuffer(text: "aệbệc\n")
        var forward: [Int] = [0]
        var offset = 0
        while offset < buffer.count - 1 {
            offset = buffer.nextCharacterBoundary(after: offset)
            forward.append(offset)
        }
        XCTAssertEqual(forward, [0, 1, 4, 5, 8, 9])
        for boundary in forward.dropFirst() {
            XCTAssertEqual(
                buffer.nextCharacterBoundary(
                    after: buffer.previousCharacterBoundary(before: boundary)),
                boundary, "lùi rồi tiến phải quay về đúng chỗ cũ tại \(boundary)")
        }
    }

    /// Tìm được kết quả nằm VẮT QUA biên cửa sổ quét.
    func testFindsAcrossScanWindow() {
        let filler = String(repeating: "x", count: 1 << 20)
        let buffer = TextBuffer(text: filler + "MỐC" + filler)
        let found = OccurrenceSearch.next(Array("MỐC".utf8), in: buffer, after: 0)
        XCTAssertNotNil(found, "kết quả ở biên cửa sổ quét bị bỏ sót")
        XCTAssertEqual(found.map { String(decoding: buffer.bytes(in: $0), as: UTF8.self) }, "MỐC")
    }
}
