import XCTest
@testable import GEditorCore

/// Chọn theo khối chữ nhật (FR-CORE-002).
final class ColumnSelectionTests: XCTestCase {

    /// Dòng dài ngắn khác nhau, và có chữ có dấu — đúng thứ làm cột lệch nếu đếm theo byte.
    private let text = """
    Nguyễn 001 Hà Nội
    Trần 002 Huế
    Lê Hoàng 003 Đà Nẵng
    x
    """ + "\n"

    private func buffer() -> TextBuffer { TextBuffer(text: text) }

    private func selectedTexts(_ selection: MultiSelection, _ buffer: TextBuffer) -> [String] {
        selection.ranges.map { String(decoding: buffer.bytes(in: $0), as: UTF8.self) }
    }

    // MARK: - Cột THỊ GIÁC: TAB nở tới nấc kế tiếp (FR-CORE-002)
    //
    // Đây là khoản nợ được ghi ra ngay trong `ColumnSelection` từ đầu: "TAB tính là MỘT cột,
    // không nở ra theo tab width". Nó không nhỏ, vì mã nguồn thụt bằng TAB là chuyện thường —
    // tức là với đúng loại file mà người ta hay chọn cột nhất thì khối lệch hẳn so với mắt.

    /// Bảng thụt bằng TAB. Với tabWidth 4, chữ đầu của mỗi dòng nằm ở cột THỊ GIÁC 4.
    private let tabbed = "\tmot\n\thai\n\tba\n" 

    func testTabExpandsToTheNextTabStop() {
        let text = TextBuffer(text: tabbed)
        // Cột 0…4 là chính cái TAB. Chọn từ 4 tới 7 phải ra đúng phần chữ.
        let selection = ColumnSelection.selection(in: text, from: (0, 4), to: (0, 7), tabWidth: 4)
        XCTAssertEqual(selectedTexts(selection, text), ["mot"])
    }

    /// Trước khi sửa, cột 4 rơi vào giữa chữ vì TAB chỉ tính một cột.
    func testCountingTabAsOneColumnWouldBeWrong() {
        let text = TextBuffer(text: tabbed)
        // tabWidth 1 tái hiện đúng hành vi CŨ — giữ lại làm đối chứng, để thấy nó khác hẳn.
        //
        // Với TAB tính một cột thì `\tmot` chỉ có bốn cột (0…3), nên cột 4…7 đã nằm QUÁ cuối
        // dòng và khối ra RỖNG. Người dùng kéo trúng chữ mà không chọn được gì.
        let old = ColumnSelection.selection(in: text, from: (0, 4), to: (0, 7), tabWidth: 1)
        XCTAssertEqual(selectedTexts(old, text), [""], "hành vi cũ: cột 4 đã quá cuối dòng")
    }

    /// Dòng thụt bằng TAB và dòng thụt bằng dấu cách phải DÓNG NHAU trên màn hình.
    ///
    /// Đây là mệnh đề mà người dùng thật sự nhìn thấy, và là lý do cả tính năng này tồn tại.
    func testTabAndSpaceIndentationLineUp() {
        let text = TextBuffer(text: "\tmot\n    hai\n\tba\n")
        let selection = ColumnSelection.selection(in: text, from: (0, 4), to: (2, 7), tabWidth: 4)
        XCTAssertEqual(selectedTexts(selection, text), ["mot", "hai", "ba"])
    }

    /// Tab width là CỦA NGƯỜI DÙNG: cùng một văn bản, hai giá trị, hai khối khác nhau.
    func testTabWidthChangesTheBlock() {
        let text = TextBuffer(text: "\tmot\n")
        XCTAssertEqual(
            selectedTexts(ColumnSelection.selection(in: text, from: (0, 4), to: (0, 7), tabWidth: 4), text),
            ["mot"])
        XCTAssertEqual(
            selectedTexts(ColumnSelection.selection(in: text, from: (0, 8), to: (0, 11), tabWidth: 8), text),
            ["mot"])
    }

    /// TAB nở tới NẤC, không phải cộng thêm `tabWidth`.
    ///
    /// Với tabWidth 4, `ab\tc` thì TAB chỉ chiếm hai cột (từ 2 tới nấc 4), không phải bốn.
    func testTabAdvancesToTheStopNotByAFixedAmount() {
        let text = TextBuffer(text: "ab\tc\n")
        XCTAssertEqual(ColumnSelection.column(ofOffset: 3, in: text, tabWidth: 4), 4,
                       "`c` phải ở cột 4, không phải 6")
    }

    /// Cột đích rơi vào GIỮA một TAB thì về biên gần hơn; hoà thì về bên trái.
    func testColumnInsideATabSnapsToTheNearerEdge() {
        let text = TextBuffer(text: "\tmot\n")
        let content = text.contentRange(ofLine: 0)
        // TAB trải cột 0…4. Cột 1 gần biên trái (0) hơn.
        XCTAssertEqual(
            ColumnSelection.offset(inLine: content, column: 1, in: text, tabWidth: 4), 0)
        // Cột 3 gần biên phải (4) hơn.
        XCTAssertEqual(
            ColumnSelection.offset(inLine: content, column: 3, in: text, tabWidth: 4), 1)
        // Cột 2 hoà — về bên trái, để hai lần kéo giống nhau cho cùng một khối.
        XCTAssertEqual(
            ColumnSelection.offset(inLine: content, column: 2, in: text, tabWidth: 4), 0)
    }

    /// Ký tự nhiều byte vẫn là MỘT cột. Đừng sửa TAB rồi làm hỏng chữ có dấu.
    func testMultiByteCharactersStillCountAsOneColumn() {
        // "Nguyễn" là 6 ký tự nhưng 8 BYTE (`ễ` chiếm 3), nên TAB nằm ở offset 8 và `x` ở 9.
        // Hai con số ấy khác nhau chính là lý do cột không đo được bằng byte.
        let text = TextBuffer(text: "Nguyễn\tx\n")
        XCTAssertEqual(ColumnSelection.column(ofOffset: 8, in: text, tabWidth: 4), 6,
                       "sáu ký tự là sáu cột, dù chúng chiếm tám byte")
        XCTAssertEqual(ColumnSelection.column(ofOffset: 9, in: text, tabWidth: 4), 8,
                       "TAB đứng ở cột 6 nở tới nấc 8")
    }

    /// Dán khối vào vùng thụt bằng TAB cũng phải đo bằng cột thị giác.
    func testPastingABlockUsesVisualColumns() {
        let text = TextBuffer(text: "\tmot\n\thai\n")
        // Một caret ngay sau TAB của dòng đầu (cột thị giác 4).
        let selection = MultiSelection(caretAt: 1)
        let edits = selection.edits(pastingBlock: ["A", "B"], in: text, tabWidth: 4)
        XCTAssertEqual(edits.count, 2)
        // Dòng thứ hai cũng phải chèn ngay sau TAB của nó, không phải sau ký tự thứ tư.
        XCTAssertEqual(edits[1].range.lowerBound, text.contentRange(ofLine: 1).lowerBound + 1)
    }

    // MARK: - Dựng khối

    /// Cột đếm theo KÝ TỰ: "Nguyễn" là 6 ký tự nhưng 9 byte.
    func testColumnsCountCharactersNotBytes() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (0, 6))
        XCTAssertEqual(selectedTexts(selection, text), ["Nguyễn"])
    }

    func testRectangleAcrossLines() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (2, 4))
        XCTAssertEqual(selectedTexts(selection, text), ["Nguy", "Trần", "Lê H"])
    }

    /// Kéo ngược (từ dưới lên, từ phải sang trái) phải ra CÙNG một khối.
    func testDragDirectionDoesNotMatter() {
        let text = buffer()
        let forward = ColumnSelection.selection(in: text, from: (0, 2), to: (2, 6))
        let backward = ColumnSelection.selection(in: text, from: (2, 6), to: (0, 2))
        XCTAssertEqual(selectedTexts(forward, text), selectedTexts(backward, text))
    }

    /// Dòng NGẮN hơn cột phải được chừa ra, không được nuốt ký tự xuống dòng.
    func testShortLineIsClampedNotOverflowed() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (2, 10), to: (3, 15))
        let parts = selectedTexts(selection, text)
        XCTAssertEqual(parts.count, 2)
        XCTAssertFalse(parts.contains { $0.contains("\n") }, "khối tràn sang dòng khác")
        XCTAssertEqual(parts[1], "", "dòng \"x\" ngắn hơn cột 10 nên không có gì được chọn")
    }

    func testColumnOfOffsetIsInverseOfSelection() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 3), to: (0, 3))
        XCTAssertEqual(ColumnSelection.column(ofOffset: selection.ranges[0].lowerBound, in: text), 3)
    }

    // MARK: - Gõ và xóa trên khối

    /// Gõ trên khối dùng LẠI đường của FR-CORE-001, nên phải là một bước undo.
    func testTypingOverBlockReplacesEveryLine() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (2, 4))
        let depth = text.undoDepth
        text.applyEdits(selection.edits(inserting: "##"), label: "gõ khối")
        XCTAssertEqual(text.undoDepth, depth + 1)
        XCTAssertEqual(text.text, """
        ##ễn 001 Hà Nội
        ## 002 Huế
        ##oàng 003 Đà Nẵng
        x
        """ + "\n")
    }

    func testDeletingBlock() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (2, 5))
        text.applyEdits(selection.edits(inserting: ""), label: "xóa khối")
        // 5 ký tự đầu của "Nguyễn" là "Nguyễ" — còn lại "n 001…".
        XCTAssertEqual(text.text, """
        n 001 Hà Nội
        002 Huế
        àng 003 Đà Nẵng
        x
        """ + "\n")
    }

    // MARK: - Chép và dán khối

    func testBlockTextJoinsLines() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (2, 4))
        XCTAssertEqual(selection.blockText(in: text), "Nguy\nTrần\nLê H")
    }

    /// Số dòng khối bằng số caret: dán theo cặp.
    func testPasteBlockLineByLine() {
        let text = buffer()
        let selection = ColumnSelection.selection(in: text, from: (0, 0), to: (2, 4))
        text.applyEdits(selection.edits(pastingBlock: ["A", "B", "C"], in: text), label: "dán")
        XCTAssertEqual(text.text, """
        Aễn 001 Hà Nội
        B 002 Huế
        Coàng 003 Đà Nẵng
        x
        """ + "\n")
    }

    /// MỘT caret, khối nhiều dòng: giữ đúng hình chữ nhật — SRS đòi rõ điều này.
    func testPasteBlockAtSingleCaretKeepsRectangle() {
        let text = TextBuffer(text: "aaa\nbbb\nccc\n")
        let selection = MultiSelection(caretAt: 1)      // giữa "aaa", cột 1
        text.applyEdits(selection.edits(pastingBlock: ["1", "2", "3"], in: text), label: "dán")
        XCTAssertEqual(text.text, "a1aa\nb2bb\nc3cc\n")
    }

    /// Khối dài hơn số dòng còn lại: dán tới đâu hết dòng thì thôi, không tự thêm dòng mới.
    func testPasteBlockLongerThanDocument() {
        let text = TextBuffer(text: "aaa\nbbb\n")
        let selection = MultiSelection(caretAt: 0)
        text.applyEdits(selection.edits(pastingBlock: ["1", "2", "3", "4"], in: text), label: "dán")
        XCTAssertEqual(text.text, "1aaa\n2bbb\n")
    }

    /// Vùng chọn KHÔNG rỗng + khối nhiều dòng: THAY vùng ấy, không chèn theo hình chữ nhật.
    ///
    /// Đây là ca làm app sập, không phải ca hiện sai. Nhánh giữ hình chữ nhật chèn dòng thứ i
    /// vào DÒNG thứ i tính từ chỗ dán; nếu chỗ dán là một vùng bôi đen thì phép thay thế ấy
    /// phủ lên chính những dòng mà các phép chèn sau nhắm tới, và `applyEdits` gặp hai vùng
    /// sửa GIAO NHAU — một `precondition`, tức `abort`.
    ///
    /// Bộ chạy dài `--soak` tìm ra ở bước 418 (NFR-REL-03) bằng chuỗi "chọn tất rồi dán".
    func testPasteBlockOverNonEmptySelectionReplaces() {
        let text = TextBuffer(text: "aaa\nbbb\nccc\n")
        let selection = MultiSelection([0 ..< 5])         // "aaa\nb", bôi đè qua biên dòng
        text.applyEdits(selection.edits(pastingBlock: ["1", "2"], in: text), label: "dán")
        XCTAssertEqual(text.text, "1\n2bb\nccc\n")
    }

    /// Chọn TẤT rồi dán — đúng chuỗi thao tác bộ chạy dài đã bắt được.
    func testPasteBlockOverSelectAllDoesNotOverlap() {
        let text = TextBuffer(text: "aaa\nbbb\nccc\n")
        let selection = MultiSelection([0 ..< text.count])
        let edits = selection.edits(pastingBlock: ["1", "2", "3"], in: text)
        // Bất biến thật sự cần giữ: các vùng sửa KHÔNG được giao nhau.
        let sorted = edits.map { $0.range }.sorted { $0.lowerBound < $1.lowerBound }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            XCTAssertLessThanOrEqual(
                earlier.upperBound, later.lowerBound,
                "hai vùng sửa giao nhau — `applyEdits` sẽ làm app sập chứ không sai một con số")
        }
        text.applyEdits(edits, label: "dán")
        XCTAssertEqual(text.text, "1\n2\n3")
    }

    /// Dòng ngắn hơn cột dán: chèn ở cuối dòng, KHÔNG đệm khoảng trắng.
    func testPasteIntoShortLineDoesNotPad() {
        let text = TextBuffer(text: "aaaaa\nb\n")
        let selection = MultiSelection(caretAt: 4)      // cột 4 của dòng đầu
        text.applyEdits(selection.edits(pastingBlock: ["X", "Y"], in: text), label: "dán")
        XCTAssertEqual(text.text, "aaaaXa\nbY\n")
    }
}
