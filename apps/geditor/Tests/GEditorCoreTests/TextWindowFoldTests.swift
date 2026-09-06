import XCTest
@testable import GEditorCore

/// Cửa sổ văn bản khi có vùng gấp — phần dễ hỏng nhất của code folding.
///
/// Cả tính năng đứng hay đổ ở đây: nếu phép quy đổi vị trí lệch một byte thì con nháy đặt sai,
/// vùng chọn xóa nhầm chữ, và màu cú pháp trôi sang chỗ khác. Mà kiểu hỏng ấy không sập, không
/// báo gì — nó chỉ làm sai âm thầm.
final class TextWindowFoldTests: XCTestCase {

    private let text = "ten: cua hang\ndia_chi:\n  so: 12\n  duong: Lê Lợi\nghi_chu: xong\n"

    private func makeBuffer() -> TextBuffer { TextBuffer(text: text) }

    private func foldOfSecondBlock(_ buffer: TextBuffer) -> FoldRange {
        FoldRanges.byIndentation(in: buffer).first { $0.headerLine == 1 }!
    }

    // MARK: - Chữ hiện ra

    func testFoldedWindowOmitsTheBodyLines() {
        let buffer = makeBuffer()
        let fold = foldOfSecondBlock(buffer)
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])
        XCTAssertEqual(window.text, "ten: cua hang\ndia_chi:\nghi_chu: xong\n")
        XCTAssertTrue(window.hasFolds)
        XCTAssertEqual(window.foldedHeaderLines, [1])
    }

    func testWindowWithoutFoldsIsUnchanged() {
        let buffer = makeBuffer()
        XCTAssertEqual(TextWindowing.window(around: 0, in: buffer).text, text)
        XCTAssertFalse(TextWindowing.window(around: 0, in: buffer).hasFolds)
    }

    // MARK: - Quy đổi vị trí

    /// Mọi offset NHÌN THẤY ĐƯỢC phải đi vòng qua hai phép quy đổi mà quay về đúng chính nó.
    func testVisibleOffsetsRoundTrip() {
        let buffer = makeBuffer()
        let fold = foldOfSecondBlock(buffer)
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])

        for offset in 0 ... buffer.count where !window.isHidden(documentOffset: offset) {
            let utf16 = window.utf16Offset(forDocumentOffset: offset)
            let back = window.documentOffset(forUTF16Offset: utf16)
            XCTAssertEqual(back, offset, "offset \(offset) đi vòng về thành \(back)")
        }
    }

    /// Chữ ở SAU vùng gấp phải trỏ đúng chỗ — đây là chỗ mốc dòng dễ lệch nhất.
    func testOffsetsAfterTheFoldAreCorrect() {
        let buffer = makeBuffer()
        let fold = foldOfSecondBlock(buffer)
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])

        let ghiChu = buffer.offset(ofLineStart: 4)
        let utf16 = window.utf16Offset(forDocumentOffset: ghiChu)
        XCTAssertEqual(utf16Text(window.text.utf16.prefix(utf16)), "ten: cua hang\ndia_chi:\n")
        XCTAssertEqual(window.documentOffset(forUTF16Offset: utf16), ghiChu)
    }

    /// Offset nằm TRONG phần đã giấu về cuối dòng đầu, không trôi sang dòng kế.
    func testHiddenOffsetsLandAtTheHeaderLine() {
        let buffer = makeBuffer()
        let fold = foldOfSecondBlock(buffer)
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])

        let endOfHeader = window.utf16Offset(forDocumentOffset: fold.caretHome)
        for offset in fold.hiddenBytes {
            XCTAssertEqual(
                window.utf16Offset(forDocumentOffset: offset), endOfHeader,
                "offset \(offset) trong phần đã giấu lại trỏ ra ngoài dòng đầu"
            )
        }
    }

    /// Chữ tiếng Việt sau vùng gấp: byte và UTF-16 lệch nhau, và đó là chỗ đã sai vài lần.
    func testVietnameseAfterFoldKeepsOffsets() {
        let buffer = TextBuffer(text: "a:\n  x: 1\n  y: 2\nten: Nguyễn Văn A\n")
        let fold = FoldRanges.byIndentation(in: buffer).first { $0.headerLine == 0 }!
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])
        XCTAssertEqual(window.text, "a:\nten: Nguyễn Văn A\n")

        let nguyen = buffer.count - "Nguyễn Văn A\n".utf8.count
        let utf16 = window.utf16Offset(forDocumentOffset: nguyen)
        XCTAssertEqual(window.documentOffset(forUTF16Offset: utf16), nguyen)
        let tail = utf16Text(window.text.utf16.suffix(window.utf16Count - utf16))
        XCTAssertEqual(tail, "Nguyễn Văn A\n")
    }

    // MARK: - Nhiều vùng, vùng lồng nhau

    func testTwoFoldsInOneWindow() {
        let buffer = TextBuffer(text: "a:\n  1\nb:\n  2\nc: 3\n")
        let folds = FoldRanges.byIndentation(in: buffer)
        XCTAssertEqual(folds.count, 2)
        let window = TextWindowing.window(around: 0, in: buffer, folds: folds)
        XCTAssertEqual(window.text, "a:\nb:\nc: 3\n")
        XCTAssertEqual(window.foldedHeaderLines, [0, 2])
    }

    /// Gấp cả vùng ngoài lẫn vùng trong: hai dải byte lồng nhau, bỏ hai lần sẽ cắt lẹm.
    func testNestedFoldsCollapseIntoOne() {
        let buffer = TextBuffer(text: "a:\n  b:\n    1\n  c: 2\nd: 3\n")
        let folds = FoldRanges.byIndentation(in: buffer)
        XCTAssertEqual(folds.count, 2, "mong một vùng ngoài và một vùng trong")
        let window = TextWindowing.window(around: 0, in: buffer, folds: folds)
        XCTAssertEqual(window.text, "a:\nd: 3\n")

        for offset in 0 ... buffer.count where !window.isHidden(documentOffset: offset) {
            XCTAssertEqual(
                window.documentOffset(forUTF16Offset: window.utf16Offset(forDocumentOffset: offset)),
                offset
            )
        }
    }

    /// Vùng gấp nằm hoàn toàn NGOÀI cửa sổ thì không được ảnh hưởng gì.
    func testFoldOutsideTheWindowIsIgnored() {
        let buffer = makeBuffer()
        let far = FoldRange(
            headerLine: 0, lastLine: 1,
            hiddenBytes: (buffer.count + 100) ..< (buffer.count + 200),
            caretHome: buffer.count + 50, kind: .indentation
        )
        let window = TextWindowing.window(around: 0, in: buffer, folds: [far])
        XCTAssertEqual(window.text, text)
        XCTAssertFalse(window.hasFolds)
    }

    /// Số dòng dài nhất phải tính trên chữ CÒN HIỆN, không tính dòng đã giấu — bề rộng khung
    /// chữ dựa vào nó, và một dòng đã giấu thì không đòi chỗ.
    func testLongestLineIgnoresHiddenLines() {
        let buffer = TextBuffer(text: "a:\n  mot dong rat rat rat dai\nb: 3\n")
        let fold = FoldRanges.byIndentation(in: buffer).first!
        let window = TextWindowing.window(around: 0, in: buffer, folds: [fold])
        XCTAssertEqual(window.longestLineUTF16Length, 4)      // "b: 3"
    }
}

/// Đọc một đoạn UTF-16 của cửa sổ thành chuỗi.
///
/// Viết hàm riêng vì `String(someUTF16Slice)` nhìn thì đúng nhưng nó gọi lại chính khởi tạo ấy
/// và chạy vô hạn — bài kiểm đầu tiên viết thế và nhận về signal 11.
private func utf16Text(_ slice: String.UTF16View.SubSequence) -> String {
    String(decoding: Array(slice), as: UTF16.self)
}
