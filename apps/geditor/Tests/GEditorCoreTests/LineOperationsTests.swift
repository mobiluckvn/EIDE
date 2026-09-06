import XCTest
@testable import GEditorCore

/// Thao tác dòng (FR-CORE-007) và nén dòng trống (FR-CORE-008).
final class LineOperationsTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func apply(_ edits: [TextEdit], to buffer: TextBuffer) -> String {
        buffer.applyEdits(edits, label: "kiểm")
        return buffer.text
    }

    // MARK: - Ghép dòng

    func testJoinLines() {
        let text = buffer("một\nhai\nba\n")
        let result = apply(DocumentOps.joinLines(in: text), to: text)
        XCTAssertEqual(result, "mộthaiba\n")
    }

    func testJoinWithSeparator() {
        let text = buffer("một\nhai\nba\n")
        let result = apply(DocumentOps.joinLines(in: text, separator: " "), to: text)
        XCTAssertEqual(result, "một hai ba\n")
    }

    /// Ghép một phần: phần ngoài vùng chọn không được đụng tới.
    func testJoinRangeLeavesRestAlone() {
        let text = buffer("a\nb\nc\nd\n")
        let result = apply(DocumentOps.joinLines(in: text, lineRange: 1 ... 2), to: text)
        XCTAssertEqual(result, "a\nbc\nd\n")
    }

    /// CRLF phải sống sót: ghép nội dung không phải là đổi kiểu xuống dòng.
    func testJoinKeepsCRLF() {
        let text = buffer("một\r\nhai\r\nba\r\n")
        let result = apply(DocumentOps.joinLines(in: text), to: text)
        XCTAssertEqual(result, "mộthaiba\r\n")
    }

    // MARK: - Tách dòng

    func testSplitByLengthCountsCharactersNotBytes() throws {
        // "Nguyễn Trãi" là 11 ký tự nhưng 14 byte. Giới hạn 8 phải hiểu theo ký tự.
        let text = buffer("Nguyễn Trãi\n")
        let result = apply(try DocumentOps.splitLines(in: text, atLength: 8), to: text)
        XCTAssertEqual(result, "Nguyễn\nTrãi\n")
    }

    func testSplitByLengthHardCutsWhenNoSpace() throws {
        let text = buffer("abcdefghij\n")
        let result = apply(try DocumentOps.splitLines(in: text, atLength: 4), to: text)
        XCTAssertEqual(result, "abcd\nefgh\nij\n")
    }

    func testSplitByCharacterDropsSeparator() throws {
        let text = buffer("a,b,c\n")
        let result = apply(try DocumentOps.splitLines(in: text, atCharacter: ","), to: text)
        XCTAssertEqual(result, "a\nb\nc\n")
    }

    /// Dòng không vượt giới hạn thì KHÔNG sinh edit — thao tác phải tỉ lệ với phần thay đổi.
    func testSplitOnlyTouchesLongLines() throws {
        let text = buffer("ngắn\n" + String(repeating: "x", count: 40) + "\nngắn\n")
        let edits = try DocumentOps.splitLines(in: text, atLength: 10)
        XCTAssertEqual(edits.count, 1, "chỉ dòng dài mới được sinh edit")
    }

    func testSplitUsesDocumentEOL() throws {
        let text = buffer("aaaa bbbb\r\n")
        let result = apply(try DocumentOps.splitLines(in: text, atLength: 4), to: text)
        XCTAssertEqual(result, "aaaa\r\nbbbb\r\n", "phải chèn CRLF, không chèn LF vào file CRLF")
    }

    // MARK: - Dời dòng

    func testMoveLineDown() {
        let text = buffer("a\nb\nc\nd\n")
        let result = apply(DocumentOps.moveLines(in: text, lineRange: 0 ... 0, by: 1), to: text)
        XCTAssertEqual(result, "b\na\nc\nd\n")
    }

    func testMoveLineUp() {
        let text = buffer("a\nb\nc\nd\n")
        let result = apply(DocumentOps.moveLines(in: text, lineRange: 2 ... 2, by: -1), to: text)
        XCTAssertEqual(result, "a\nc\nb\nd\n")
    }

    func testMoveBlockOfLines() {
        let text = buffer("a\nb\nc\nd\ne\n")
        let result = apply(DocumentOps.moveLines(in: text, lineRange: 0 ... 1, by: 2), to: text)
        XCTAssertEqual(result, "c\nd\na\nb\ne\n")
    }

    /// Dời ra ngoài biên phải KHÔNG làm gì, không được cắt mất dòng.
    func testMoveBeyondEdgeIsNoOp() {
        let text = buffer("a\nb\n")
        XCTAssertTrue(DocumentOps.moveLines(in: text, lineRange: 0 ... 0, by: -1).isEmpty)
        XCTAssertTrue(DocumentOps.moveLines(in: text, lineRange: 1 ... 1, by: 1).isEmpty)
    }

    // MARK: - Đảo thứ tự

    func testReverseLines() {
        let text = buffer("một\nhai\nba\n")
        let result = apply(DocumentOps.reverseLines(in: text), to: text)
        XCTAssertEqual(result, "ba\nhai\nmột\n")
    }

    /// File không kết thúc bằng ký tự xuống dòng: đảo xong vẫn không được mọc thêm dòng mới,
    /// và dòng cuối vẫn phải là dòng không có EOL.
    func testReverseKeepsMissingFinalNewline() {
        let text = buffer("a\nb\nc")
        let result = apply(DocumentOps.reverseLines(in: text), to: text)
        XCTAssertEqual(result, "c\nb\na")
    }

    func testReverseIsItsOwnInverse() {
        let original = "một\nhai\nba\nbốn\n"
        let text = buffer(original)
        _ = apply(DocumentOps.reverseLines(in: text), to: text)
        let result = apply(DocumentOps.reverseLines(in: text), to: text)
        XCTAssertEqual(result, original)
    }

    // MARK: - Nén dòng trống

    func testSqueezeBlankLinesKeepsOne() {
        let text = buffer("a\n\n\n\nb\n\nc\n")
        let result = apply(DocumentOps.squeezeBlankLines(in: text), to: text)
        XCTAssertEqual(result, "a\n\nb\n\nc\n")
    }

    /// "Dòng trống" gồm cả dòng chỉ chứa khoảng trắng — SRS nói rõ như vậy.
    func testSqueezeTreatsWhitespaceOnlyLinesAsBlank() {
        let text = buffer("a\n\n   \n\t\nb\n")
        let result = apply(DocumentOps.squeezeBlankLines(in: text), to: text)
        XCTAssertEqual(result, "a\n\nb\n")
    }

    // MARK: - Bất biến chung

    /// FR-CORE-004: mọi thao tác hàng loạt là ĐÚNG MỘT bước undo.
    func testEveryOperationIsOneUndoStep() throws {
        let original = "một\nhai\nba\nbốn\nnăm\n"

        for (name, makeEdits) in [
            ("ghép", { (b: TextBuffer) in DocumentOps.joinLines(in: b) }),
            ("đảo", { (b: TextBuffer) in DocumentOps.reverseLines(in: b) }),
            ("dời", { (b: TextBuffer) in DocumentOps.moveLines(in: b, lineRange: 0 ... 1, by: 2) }),
            ("tách", { (b: TextBuffer) in (try? DocumentOps.splitLines(in: b, atLength: 2)) ?? [] }),
        ] {
            let text = buffer(original)
            let depth = text.undoDepth
            text.applyEdits(makeEdits(text), label: name)
            XCTAssertEqual(text.undoDepth, depth + 1, "\(name) phải là một bước undo")
            XCTAssertTrue(text.undo())
            XCTAssertEqual(text.text, original, "undo \(name) phải về nguyên trạng")
        }
    }
}
