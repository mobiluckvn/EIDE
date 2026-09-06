import XCTest
@testable import GEditorCore

/// Truy vết: FR-SRCH-110 regex tester / explainer.
final class RegexTesterTests: XCTestCase {

    private let regex = SearchOptions(mode: .regex, matchCase: true, wholeWord: false)

    func testRunsOnSampleAndCapturesGroups() throws {
        let result = try RegexTester.run(
            pattern: #"(\w+)@(\w+)\.com"#, options: regex,
            on: "an@vidu.com và binh@khac.com"
        )
        XCTAssertEqual(result.matches.count, 2)
        XCTAssertEqual(result.previews[0].whole, "an@vidu.com")
        XCTAssertEqual(result.previews[0].groups, ["an", "vidu"])
        XCTAssertEqual(result.previews[1].groups, ["binh", "khac"])
        XCTAssertFalse(result.truncated)
    }

    /// Nhóm KHÔNG tham gia lần khớp phải là `nil`, khác hẳn chuỗi rỗng — đó là chỗ người ta hay
    /// hiểu sai khi viết chuỗi thay thế.
    func testUnmatchedGroupIsNilNotEmpty() throws {
        let result = try RegexTester.run(pattern: "(a)|(b)", options: regex, on: "b")
        XCTAssertEqual(result.previews.first?.groups.first ?? "x", nil)
        XCTAssertEqual(result.previews.first?.groups.last, "b")
    }

    func testVietnameseSample() throws {
        let result = try RegexTester.run(pattern: "Hu.", options: regex, on: "Thừa Thiên Huế")
        XCTAssertEqual(result.previews.first?.whole, "Huế")
    }

    /// Một pattern khớp ở mọi vị trí cho ra hàng nghìn kết quả; hiện hết thì panel không dùng
    /// được nữa — cắt và NÓI RA là đã cắt.
    ///
    /// Dùng `a` chứ không phải `a*`: `a*` ăn THAM nên nó nuốt cả 5000 ký tự trong MỘT lần khớp
    /// rồi khớp rỗng ở cuối, tổng cộng hai lần. Đó là hành vi đúng của PCRE2, và là lý do bản
    /// đầu của bài kiểm này đỏ.
    func testTooManyMatchesAreTruncatedAndReported() throws {
        let result = try RegexTester.run(
            pattern: "a", options: regex, on: String(repeating: "a", count: 5000), limit: 10
        )
        XCTAssertEqual(result.matches.count, 10)
        XCTAssertTrue(result.truncated)
    }

    func testInvalidPatternThrows() {
        XCTAssertThrowsError(try RegexTester.run(pattern: "(", options: regex, on: "x"))
    }

    func testNoMatchIsNotAnError() throws {
        let result = try RegexTester.run(pattern: "xyz", options: regex, on: "abc")
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertFalse(result.truncated)
    }

    // MARK: - Giải thích

    private func meanings(_ pattern: String) -> [String] {
        RegexTester.explain(pattern).map { "\($0.text)=\($0.meaning ?? "?")" }
    }

    func testExplainsCommonPieces() {
        let tokens = RegexTester.explain(#"\d+"#)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].text, #"\d"#)
        XCTAssertEqual(tokens[0].meaning, "một chữ số")
        XCTAssertEqual(tokens[1].meaning, "một hoặc nhiều lần")
    }

    /// `?` sau một lượng từ nghĩa là "càng ít càng tốt", không phải "có cũng được". Hai nghĩa
    /// này khác nhau hoàn toàn, và nhầm là nguồn của rất nhiều regex chạy sai.
    func testLazyQuantifierIsNotOptional() {
        let lazyTokens = RegexTester.explain(".+?")
        XCTAssertEqual(lazyTokens.last?.meaning, "khớp càng ít càng tốt")
        let optional = RegexTester.explain("ab?")
        XCTAssertEqual(optional.last?.meaning, "có cũng được, không có cũng được")
    }

    func testCharacterClassIsOneToken() {
        let tokens = RegexTester.explain("[a-z0-9]+")
        XCTAssertEqual(tokens.first?.text, "[a-z0-9]")
        XCTAssertEqual(tokens.first?.meaning, "một ký tự thuộc tập này")
        XCTAssertEqual(RegexTester.explain("[^abc]").first?.meaning, "một ký tự KHÔNG thuộc tập này")
    }

    /// `]` ngay sau `[` là ký tự thật, không đóng lớp — luật POSIX mà PCRE2 giữ.
    func testClosingBracketRightAfterOpenIsLiteral() {
        XCTAssertEqual(RegexTester.explain("[]]").first?.text, "[]]")
    }

    func testGroupKinds() {
        XCTAssertTrue(meanings("(?:ab)").contains { $0.contains("nhóm không bắt giá trị") })
        XCTAssertTrue(meanings("(?=ab)").contains { $0.contains("phía sau phải là") })
        XCTAssertTrue(meanings("(?<!ab)").contains { $0.contains("phía trước KHÔNG được là") })
    }

    /// Ký tự nghĩa đen liền nhau gom thành MỘT mảnh: tách từng chữ cho ra một danh sách dài
    /// dằng dặc mà không nói thêm được gì.
    func testLiteralRunIsOneToken() {
        let tokens = RegexTester.explain("chào")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "chào")
    }

    /// Escape không nhận ra thì nói "hiểu theo nghĩa đen" chứ không đoán bừa.
    func testUnknownEscapeIsDescribedHonestly() {
        XCTAssertEqual(RegexTester.explain(#"\q"#).first?.meaning, "ký tự «q» hiểu theo nghĩa đen")
    }

    func testTrailingBackslashDoesNotCrash() {
        XCTAssertEqual(RegexTester.explain(#"a\"#).count, 2)
    }

    func testEmptyPattern() {
        XCTAssertTrue(RegexTester.explain("").isEmpty)
    }
}
