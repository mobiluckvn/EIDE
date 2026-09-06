import XCTest
@testable import GEditorCore

/// Truy vết: FR-CORE-012 khớp ngoặc / thẻ.
final class BracketMatcherTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func partner(_ text: String, caret: Int, _ language: SyntaxLanguage?) -> Int? {
        BracketMatcher.match(in: buffer(text), at: caret, language: language)?.partner
    }

    func testMatchesSimplePair() {
        let text = "f(x)"
        XCTAssertEqual(partner(text, caret: 1, .c), 3, "( ở vị trí 1 khớp với ) ở vị trí 3")
        XCTAssertEqual(partner(text, caret: 3, .c), 1, "và ngược lại")
    }

    func testMatchesNestedPairs() {
        let text = "a(b(c)d)e"
        XCTAssertEqual(partner(text, caret: 1, .c), 7, "ngoặc ngoài phải bỏ qua cặp bên trong")
        XCTAssertEqual(partner(text, caret: 3, .c), 5)
    }

    /// Con nháy vừa gõ xong `)` thì nó đứng SAU dấu ấy — và đó chính là lúc người dùng muốn
    /// biết dấu vừa gõ đóng cho cái gì.
    func testMatchesBracketJustBeforeCaret() {
        XCTAssertEqual(partner("f(x)", caret: 4, .c), 1)
    }

    func testUnmatchedBracketReturnsNil() {
        XCTAssertNil(partner("f(x", caret: 1, .c))
        XCTAssertNil(partner("x)", caret: 1, .c))
    }

    func testCaretNotOnBracketReturnsNil() {
        XCTAssertNil(partner("f(x)", caret: 0, .c))
    }

    // MARK: - Chuỗi và chú thích — lý do tồn tại của cả bộ quét

    /// Dấu ngoặc trong CHUỖI không mở hay đóng khối nào. Bộ đếm byte sẽ lệch từ đây tới hết
    /// file và khớp NHẦM CHỖ.
    func testBracketsInsideStringsAreIgnored() {
        let text = "f(\"a)b\")"
        XCTAssertEqual(partner(text, caret: 1, .c), 7, ") trong chuỗi không được tính")
    }

    func testBracketsInsideLineCommentAreIgnored() {
        let text = "f(\n  // )\n)"
        XCTAssertEqual(partner(text, caret: 1, .c), 10)
    }

    func testBracketsInsideBlockCommentAreIgnored() {
        let text = "f(\n  /* ) */\n)"
        XCTAssertEqual(partner(text, caret: 1, .c), 13)
    }

    /// `"\""` là MỘT chuỗi chứa dấu nháy, không phải hai chuỗi rỗng liền nhau.
    func testEscapedQuoteDoesNotEndString() {
        let text = "f(\"\\\")\")"
        XCTAssertEqual(partner(text, caret: 1, .c), 7)
    }

    /// Dấu nháy lẻ trong văn xuôi — `don't` — không được nuốt phần còn lại của file.
    func testLoneApostropheDoesNotSwallowRestOfDocument() {
        let text = "a(don't\nb)"
        XCTAssertEqual(partner(text, caret: 1, .c), 9)
    }

    /// Python dùng `#`, không dùng `//`. Lấy nhầm dấu là phân loại sai cả file.
    func testCommentTokenFollowsLanguage() {
        let text = "f(\n  # )\n)"
        XCTAssertEqual(partner(text, caret: 1, .python), 9)
        // Với C thì `#` KHÔNG phải chú thích, nên dấu ) trên dòng ấy mới là dấu khớp.
        XCTAssertEqual(partner(text, caret: 1, .c), 7)
    }

    // MARK: - Biên

    /// Tài liệu quá lớn thì KHÔNG khớp, chứ không đoán bừa. Neo giữa chừng có thể rơi vào giữa
    /// một chuỗi, và bôi sáng sai cặp ngoặc tệ hơn không bôi sáng gì.
    func testDocumentAboveLimitIsDeclined() {
        let padding = String(repeating: "x", count: BracketMatcher.fullScanLimit)
        let target = buffer("f(y)\n" + padding)
        XCTAssertNil(BracketMatcher.match(in: target, at: 1, language: .c))
    }

    func testEmptyDocument() {
        XCTAssertNil(BracketMatcher.match(in: buffer(""), at: 0, language: .c))
    }

    /// Không nhận ra ngôn ngữ vẫn phải chạy: dấu nháy là quy ước gần như chung, và bỏ qua
    /// chuỗi vẫn tốt hơn nhiều so với đếm ngoặc trần.
    func testPlainTextStillSkipsStrings() {
        XCTAssertEqual(partner("f(\"a)b\")", caret: 1, nil), 7)
    }

    func testMatchesSquareAndCurlyBraces() {
        XCTAssertEqual(partner("[a]", caret: 0, .c), 2)
        XCTAssertEqual(partner("{a}", caret: 0, .c), 2)
        // Ngoặc KHÁC LOẠI không khớp với nhau.
        XCTAssertNil(partner("[a}", caret: 0, .c))
    }
}
