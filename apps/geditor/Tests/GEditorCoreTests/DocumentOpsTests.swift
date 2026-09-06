import XCTest
@testable import GEditorCore

/// Kiểm thử cầu nối giữa thao tác dòng và tài liệu (FR-CORE-004…010).
///
/// Mọi test ở đây khẳng định cùng một bất biến ngoài kết quả: thao tác hàng loạt phải là
/// ĐÚNG MỘT bước undo. Đó là điều khiến `DocumentOps` tồn tại — `LineOps` tự nó không biết
/// gì về undo, và nếu mỗi dòng thành một bước thì người dùng phải nhấn ⌘Z một triệu lần.
final class DocumentOpsTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    /// Áp edit rồi trả về nội dung — kèm khẳng định một bước undo và undo khôi phục đúng.
    private func apply(
        _ edits: [TextEdit], to buffer: TextBuffer, file: StaticString = #filePath, line: UInt = #line
    ) -> String {
        let before = buffer.text
        buffer.applyEdits(edits, label: "Kiểm thử")
        let after = buffer.text
        XCTAssertTrue(buffer.undo(), "phải có bước undo", file: file, line: line)
        XCTAssertEqual(buffer.text, before, "undo phải khôi phục nguyên trạng", file: file, line: line)
        XCTAssertFalse(buffer.canUndo, "phải là ĐÚNG MỘT bước undo", file: file, line: line)
        buffer.redo()
        return after
    }

    // MARK: - Truy cập dòng

    func testLineRanges() {
        XCTAssertEqual(DocumentOps.lineRanges(of: buffer("a\nb\nc")), [0 ..< 2, 2 ..< 4, 4 ..< 5])
        XCTAssertEqual(DocumentOps.lineRanges(of: buffer("a\nb\n")), [0 ..< 2, 2 ..< 4])
        XCTAssertEqual(DocumentOps.lineRanges(of: buffer("")), [])
        // Phạm vi tính bằng BYTE: "một dòng" là 8 ký tự nhưng 11 byte UTF-8.
        XCTAssertEqual(DocumentOps.lineRanges(of: buffer("một dòng")), [0 ..< 11])
    }

    func testLineRangesWithCRLF() {
        let ranges = DocumentOps.lineRanges(of: buffer("a\r\nb\r\n"))
        XCTAssertEqual(ranges, [0 ..< 3, 3 ..< 6])
    }

    func testCoalesceMergesAdjacentRanges() {
        XCTAssertEqual(DocumentOps.coalesce([0 ..< 2, 2 ..< 4, 6 ..< 8]), [0 ..< 4, 6 ..< 8])
        XCTAssertEqual(DocumentOps.coalesce([]), [])
        XCTAssertEqual(DocumentOps.coalesce([0 ..< 1]), [0 ..< 1])
    }

    // MARK: - Khử trùng lặp (FR-CORE-006)

    func testRemoveDuplicatesKeepingFirst() throws {
        let source = "a\nb\na\nc\nb\na\n"
        let target = buffer(source)
        let edits = try DocumentOps.removeDuplicateLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "a\nb\nc\n")
    }

    func testRemoveDuplicatesKeepingLast() throws {
        let target = buffer("a\nb\na\nc\n")
        let edits = try DocumentOps.removeDuplicateLines(in: target, keep: .last)
        XCTAssertEqual(apply(edits, to: target), "b\na\nc\n")
    }

    func testRemoveConsecutiveDuplicatesOnly() throws {
        let target = buffer("a\na\nb\na\n")
        let edits = try DocumentOps.removeDuplicateLines(in: target, scope: .consecutive)
        XCTAssertEqual(apply(edits, to: target), "a\nb\na\n", "chỉ gộp dòng trùng LIỀN NHAU")
    }

    /// Dòng xóa liền nhau phải gộp thành một edit — đây là thứ giữ cho một triệu dòng trùng
    /// không sinh ra một triệu thao tác trên cây piece.
    func testAdjacentDeletionsAreCoalescedIntoOneEdit() throws {
        let target = buffer("x\n" + String(repeating: "trùng\n", count: 100) + "y\n")
        let edits = try DocumentOps.removeDuplicateLines(in: target)
        XCTAssertEqual(edits.count, 1, "99 dòng trùng liền nhau phải thành 1 edit")
        XCTAssertEqual(apply(edits, to: target), "x\ntrùng\ny\n")
    }

    func testDuplicateRemovalPreservesOrderOfKeptLines() throws {
        let target = buffer("cam\ntáo\nchuối\ncam\ntáo\nxoài\n")
        let edits = try DocumentOps.removeDuplicateLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "cam\ntáo\nchuối\nxoài\n")
    }

    func testDuplicateRemovalComparesBytesNotDisplay() throws {
        // "ế" dạng dựng sẵn và dạng tổ hợp hiển thị giống hệt nhưng KHÁC byte. Coi chúng là
        // một sẽ xóa mất dữ liệu; chuẩn hóa là việc của FR-ENC-206, không phải của dedup.
        let target = buffer("ế\n" + "ế" + "\n")  // dòng 2 dạng tổ hợp
        let composed = "\u{1EBF}\n"
        let decomposed = "e\u{0302}\u{0301}\n"
        let mixed = buffer(composed + decomposed + composed)
        let edits = try DocumentOps.removeDuplicateLines(in: mixed)
        XCTAssertEqual(edits.count, 1, "chỉ dòng thứ ba trùng byte với dòng đầu")
        _ = target
    }

    // MARK: - Sắp xếp (FR-CORE-005)

    func testLexicographicSort() {
        let target = buffer("chuối\ncam\ntáo\n")
        let edits = DocumentOps.sortLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "cam\nchuối\ntáo\n")
    }

    /// TC-CORE-07 — natural sort: file1, file10, file2 → file1, file2, file10.
    func testNaturalSort() {
        let target = buffer("file1\nfile10\nfile2\n")
        let edits = DocumentOps.sortLines(in: target, kind: .natural)
        XCTAssertEqual(apply(edits, to: target), "file1\nfile2\nfile10\n")
    }

    func testDescendingNumericSort() {
        let target = buffer("10\n9\n100\n")
        let edits = DocumentOps.sortLines(in: target, kind: .numeric, ascending: false)
        XCTAssertEqual(apply(edits, to: target), "100\n10\n9\n")
    }

    /// TC-CORE-06 — sắp theo cột 2, kiểu số, giảm dần; dòng có quoted field KHÔNG được vỡ.
    ///
    /// Đây là test bắt lỗi tách chuỗi thô: field `"Anh Đào, CN Huế"` chứa dấu phẩy, tách bằng
    /// `split(separator: ",")` sẽ coi nó là hai cột và lấy nhầm khóa sắp xếp.
    func testSortByColumnDoesNotBreakQuotedFields() {
        let source = """
        DH-01,"Anh Đào, CN Huế",300
        DH-02,"Sông Hàn",100
        DH-03,"Bà Rịa, Vũng Tàu",200

        """
        let target = buffer(source)
        let edits = DocumentOps.sortLines(in: target, kind: .numeric, ascending: false, column: 2)
        XCTAssertEqual(apply(edits, to: target), """
        DH-01,"Anh Đào, CN Huế",300
        DH-03,"Bà Rịa, Vũng Tàu",200
        DH-02,"Sông Hàn",100

        """)
    }

    func testSortByQuotedColumnUsesUnescapedValue() {
        let target = buffer("a,\"z\"\nb,\"a\"\n")
        let edits = DocumentOps.sortLines(in: target, column: 1)
        XCTAssertEqual(apply(edits, to: target), "b,\"a\"\na,\"z\"\n")
    }

    func testSortIsStableForEqualKeys() {
        let target = buffer("1,b\n1,a\n0,c\n")
        let edits = DocumentOps.sortLines(in: target, kind: .numeric, column: 0)
        XCTAssertEqual(apply(edits, to: target), "0,c\n1,b\n1,a\n", "khóa bằng nhau giữ thứ tự cũ")
    }

    /// Sắp xếp nội dung, KHÔNG sắp xếp ký tự xuống dòng: một file toàn LF không được mọc ra
    /// CRLF ở giữa chỉ vì có một dòng CRLF lạc bị đẩy lên trên.
    func testSortKeepsEOLStyleOfEachPosition() {
        let target = buffer("c\r\na\nb\n")
        let edits = DocumentOps.sortLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "a\r\nb\nc\n")
    }

    func testSortOfAlreadySortedProducesNoEdits() {
        XCTAssertTrue(DocumentOps.sortLines(in: buffer("a\nb\nc\n")).isEmpty)
    }

    func testSortWithinLineRangeOnly() {
        let target = buffer("giữ\nc\na\nb\ngiữ cuối\n")
        let edits = DocumentOps.sortLines(in: target, lineRange: 1 ... 3)
        XCTAssertEqual(apply(edits, to: target), "giữ\na\nb\nc\ngiữ cuối\n")
    }

    // MARK: - Biến đổi từng dòng

    func testTransformOnlyEmitsEditsForChangedLines() throws {
        let target = buffer("KHÔNG ĐỔI\nđổi\nKHÔNG ĐỔI 2\n")
        let edits = try DocumentOps.transformLines(in: target) { $0.uppercased() }
        XCTAssertEqual(edits.count, 1, "chỉ dòng thực sự đổi mới sinh edit")
        XCTAssertEqual(apply(edits, to: target), "KHÔNG ĐỔI\nĐỔI\nKHÔNG ĐỔI 2\n")
    }

    func testTrimTrailingWhitespace() throws {
        let target = buffer("a   \nb\t\nc\n")
        let edits = try DocumentOps.trimLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "a\nb\nc\n")
    }

    func testRemoveBlankLines() {
        let target = buffer("a\n\n   \nb\n\t\nc\n")
        let edits = DocumentOps.removeBlankLines(in: target)
        XCTAssertEqual(apply(edits, to: target), "a\nb\nc\n")
    }

    /// TC-CORE-12 — TAB ↔ Space giữ nguyên hình thức thụt lề, round-trip không đổi nội dung,
    /// mỗi chiều là một bước undo.
    func testTabSpaceRoundTrip() throws {
        let source = "\tmột\n\t\thai\n    ba\n"
        let target = buffer(source)

        let toSpaces = try DocumentOps.tabsToSpaces(in: target, tabWidth: 4)
        target.applyEdits(toSpaces, label: "Tab→Space")
        XCTAssertEqual(target.text, "    một\n        hai\n    ba\n")

        let toTabs = try DocumentOps.spacesToTabs(in: target, tabWidth: 4)
        target.applyEdits(toTabs, label: "Space→Tab")
        XCTAssertEqual(target.text, "\tmột\n\t\thai\n\tba\n", "thụt lề giữ nguyên hình thức")

        XCTAssertTrue(target.undo())
        XCTAssertTrue(target.undo())
        XCTAssertEqual(target.text, source, "mỗi chiều đúng một bước undo")
    }

    /// TC-CORE-11 — chuyển camelCase → snake_case.
    func testConvertCase() throws {
        let target = buffer("userNameField\n")
        let edits = try DocumentOps.convertCase(in: target, to: .snake)
        XCTAssertEqual(apply(edits, to: target), "user_name_field\n")
    }

    func testConvertCaseOnVietnamese() throws {
        let target = buffer("thừa thiên huế\n")
        let edits = try DocumentOps.convertCase(in: target, to: .upper)
        XCTAssertEqual(apply(edits, to: target), "THỪA THIÊN HUẾ\n")
    }

    // MARK: - Nhân đôi & xóa dòng (FR-CORE-007)

    func testDuplicateSingleLine() {
        let target = buffer("một\nhai\nba\n")
        let edits = DocumentOps.duplicateLines(in: target, lineRange: 1 ... 1)
        XCTAssertEqual(apply(edits, to: target), "một\nhai\nhai\nba\n")
    }

    func testDuplicateBlockKeepsOrder() {
        let target = buffer("a\nb\nc\nd\n")
        let edits = DocumentOps.duplicateLines(in: target, lineRange: 1 ... 2)
        XCTAssertEqual(apply(edits, to: target), "a\nb\nc\nb\nc\nd\n")
    }

    /// Dòng CUỐI không có EOL. Chép nguyên xi thì hai dòng dính thành một.
    func testDuplicateLastLineWithoutTrailingNewline() {
        let target = buffer("a\nb")
        let edits = DocumentOps.duplicateLines(in: target, lineRange: 1 ... 1)
        XCTAssertEqual(apply(edits, to: target), "a\nb\nb")
    }

    func testDuplicateKeepsCRLF() {
        let target = buffer("a\r\nb\r\n")
        let edits = DocumentOps.duplicateLines(in: target, lineRange: 0 ... 0)
        XCTAssertEqual(apply(edits, to: target), "a\r\na\r\nb\r\n")
    }

    func testDeleteLines() {
        let target = buffer("a\nb\nc\n")
        let edits = DocumentOps.deleteLines(in: target, lineRange: 1 ... 1)
        XCTAssertEqual(apply(edits, to: target), "a\nc\n")
    }

    /// Xóa tới hết tài liệu phải nuốt cả EOL của dòng đứng trước, không thì còn lại một dòng
    /// trống mà người dùng không hề tạo ra.
    func testDeleteLastLineLeavesNoBlankLine() {
        let target = buffer("a\nb\nc")
        let edits = DocumentOps.deleteLines(in: target, lineRange: 2 ... 2)
        XCTAssertEqual(apply(edits, to: target), "a\nb")
    }

    func testDeleteEveryLineEmptiesDocument() {
        let target = buffer("a\nb\n")
        let edits = DocumentOps.deleteLines(in: target, lineRange: 0 ... 1)
        XCTAssertEqual(apply(edits, to: target), "")
    }

    // MARK: - Comment nhanh (FR-CORE-014)

    func testCommentThenUncommentIsIdentity() {
        let target = buffer("let a = 1\nlet b = 2\n")
        let on = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 1, token: "//")
        target.applyEdits(on, label: "comment")
        XCTAssertEqual(target.text, "// let a = 1\n// let b = 2\n")

        let off = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 1, token: "//")
        target.applyEdits(off, label: "bỏ comment")
        XCTAssertEqual(target.text, "let a = 1\nlet b = 2\n")
    }

    /// Dấu chèn ở cột thụt lề NÔNG NHẤT của khối, giữ nguyên hình dáng thụt lề bên trong.
    func testCommentInsertsAtShallowestIndent() {
        let target = buffer("    if x:\n        y = 1\n")
        let edits = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 1, token: "#")
        XCTAssertEqual(apply(edits, to: target), "    # if x:\n    #     y = 1\n")
    }

    /// Khối comment DỞ đi cùng một hướng: còn một dòng chưa comment thì comment tất, chứ
    /// không biến khối thành bàn cờ.
    func testPartiallyCommentedBlockGetsFullyCommented() {
        let target = buffer("// a\nb\n")
        let edits = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 1, token: "//")
        XCTAssertEqual(apply(edits, to: target), "// // a\n// b\n")
    }

    func testCommentSkipsBlankLines() {
        let target = buffer("a\n\nb\n")
        let edits = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 2, token: "#")
        XCTAssertEqual(apply(edits, to: target), "# a\n\n# b\n")
    }

    /// Thụt lề bằng chữ tiếng Việt: cột đếm theo KÝ TỰ, chỗ chèn tính theo BYTE. Lấy nhầm số
    /// là cắt vào giữa một ký tự UTF-8 và làm hỏng chữ.
    func testUncommentOnVietnameseLineKeepsBytesIntact() {
        let target = buffer("# một dòng tiếng Việt\n")
        let edits = DocumentOps.toggleLineComment(in: target, lineRange: 0 ... 0, token: "#")
        XCTAssertEqual(apply(edits, to: target), "một dòng tiếng Việt\n")
    }

    func testBlockCommentRoundTrip() {
        let target = buffer("<a/>\n<b/>\n")
        let on = DocumentOps.toggleBlockComment(
            in: target, lineRange: 0 ... 1, open: "<!--", close: "-->"
        )
        target.applyEdits(on, label: "comment")
        XCTAssertEqual(target.text, "<!-- <a/>\n<b/> -->\n")

        let off = DocumentOps.toggleBlockComment(
            in: target, lineRange: 0 ... 1, open: "<!--", close: "-->"
        )
        target.applyEdits(off, label: "bỏ comment")
        XCTAssertEqual(target.text, "<a/>\n<b/>\n")
    }

    // MARK: - Chuẩn hóa Unicode (FR-ENC-206)

    /// "ế" ở dạng NFD là ba điểm mã, NFC là một. Hai dòng trông giống hệt nhau.
    func testNormalizeToNFCCollapsesDecomposedVietnamese() throws {
        let decomposed = "Hue\u{0302}\u{0301}"
        let target = buffer(decomposed + "\n")
        XCTAssertEqual(target.text.utf8.count, 8)   // 3 chữ + 2 dấu tổ hợp 2 byte + \n
        let edits = try DocumentOps.transformLines(in: target) {
            EncodingEngine.normalize($0, to: .nfc)
        }
        let result = apply(edits, to: target)
        XCTAssertEqual(result, "Huế\n")
        XCTAssertEqual(result.utf8.count, 6)       // "ế" dựng sẵn còn 3 byte
    }

    /// Chuẩn hóa một tài liệu ĐÃ chuẩn thì không sinh edit nào — không được đụng vào file.
    func testNormalizeIsNoOpWhenAlreadyNormalized() throws {
        let target = buffer("Huế\n")
        let edits = try DocumentOps.transformLines(in: target) {
            EncodingEngine.normalize($0, to: .nfc)
        }
        XCTAssertTrue(edits.isEmpty)
    }

    // MARK: - Hủy

    func testCancellationIsHonoured() {
        let target = buffer(String(repeating: "dòng\n", count: 200_000))
        let token = CancelToken(timeout: 0.001)
        XCTAssertThrowsError(try DocumentOps.removeDuplicateLines(in: target, cancelToken: token))
    }
}
