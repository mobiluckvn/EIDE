import XCTest
@testable import GEditorCore

/// Truy vết: FR-FMT-502 ngôn ngữ tự định nghĩa.
final class UserDefinedLanguageTests: XCTestCase {

    private var directory = URL(fileURLWithPath: "/dev/null")

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-udl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func scopes(_ language: UserDefinedLanguage, _ text: String) -> [(String, String)] {
        let bytes = Array(text.utf8)
        return language.spans(in: text).map {
            (String(decoding: bytes[$0.range], as: UTF8.self), $0.scope)
        }
    }

    func testHighlightsKeywords() {
        let language = UserDefinedLanguage(
            name: "T", keywordGroups: ["keyword": ["nếu", "thì"]]
        )
        XCTAssertEqual(
            scopes(language, "nếu x thì y").map(\.0), ["nếu", "thì"]
        )
    }

    func testCaseInsensitiveMode() {
        var language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["IF"]])
        language.caseSensitive = false
        XCTAssertEqual(scopes(language, "if x").count, 1)

        language.caseSensitive = true
        XCTAssertTrue(scopes(language, "if x").isEmpty, "phân biệt hoa thường thì `if` khác `IF`")
    }

    /// Từ khoá nằm TRONG CHUỖI không phải từ khoá. Tô nó lên trông giống hệt một lỗi cú pháp
    /// mà người dùng đi tìm mãi không ra.
    func testKeywordInsideStringIsNotHighlighted() {
        let language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["nếu"]])
        let result = scopes(language, #"x = "nếu""#)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].1, "string")
    }

    func testKeywordInsideCommentIsNotHighlighted() {
        var language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["nếu"]])
        language.lineComment = ";"
        let result = scopes(language, "; nếu\nnếu")
        XCTAssertEqual(result.map(\.1), ["comment", "keyword"])
    }

    func testBlockComment() {
        var language = UserDefinedLanguage(name: "T")
        language.blockComment = ["/*", "*/"]
        XCTAssertEqual(scopes(language, "a /* b */ c").map(\.0), ["/* b */"])
    }

    /// Chuỗi chưa đóng không được nuốt phần còn lại của file — dừng ở cuối dòng.
    func testUnterminatedStringStopsAtLineEnd() {
        let language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["nếu"]])
        let result = scopes(language, "x = \"chưa đóng\nnếu")
        XCTAssertEqual(result.last?.1, "keyword", "dòng sau vẫn được tô bình thường")
    }

    /// Vị trí trả về tính bằng BYTE, không phải ký tự: tiếng Việt làm hai số ấy khác nhau, và
    /// lấy nhầm sẽ tô lệch sang giữa một ký tự UTF-8.
    func testRangesAreByteOffsets() {
        let language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["thì"]])
        let spans = language.spans(in: "nếu x thì y")
        XCTAssertEqual(spans.count, 1)
        // "nếu x " = n(1) ế(3) u(1) space(1) x(1) space(1) = 8 byte
        XCTAssertEqual(spans[0].range.lowerBound, 8)
        XCTAssertEqual(spans[0].range.upperBound, 8 + "thì".utf8.count)
    }

    func testOffsetIsApplied() {
        let language = UserDefinedLanguage(name: "T", keywordGroups: ["keyword": ["a"]])
        XCTAssertEqual(language.spans(in: "a", offset: 100).first?.range, 100 ..< 101)
    }

    func testGroupsAreReportedSeparately() {
        let language = UserDefinedLanguage(
            name: "T", keywordGroups: ["keyword": ["nếu"], "constant": ["đúng"]]
        )
        let result = scopes(language, "nếu đúng")
        XCTAssertEqual(Set(result.map(\.1)), ["keyword", "constant"])
    }

    // MARK: - Nhận theo đuôi file

    func testMatchesByExtension() {
        var language = UserDefinedLanguage(name: "T")
        language.extensions = ["mycfg", "MYC"]
        XCTAssertNotNil(UserDefinedLanguage.matching(path: "/a/b.mycfg", in: [language]))
        XCTAssertNotNil(UserDefinedLanguage.matching(path: "/a/b.myc", in: [language]),
                        "so đuôi KHÔNG phân biệt hoa thường")
        XCTAssertNil(UserDefinedLanguage.matching(path: "/a/b.txt", in: [language]))
        XCTAssertNil(UserDefinedLanguage.matching(path: "/a/Makefile", in: [language]))
    }

    // MARK: - Đọc / ghi

    func testRoundTrip() throws {
        let url = directory.appendingPathComponent("vi-du.json")
        try UserDefinedLanguage.example.save(to: url)
        XCTAssertEqual(try UserDefinedLanguage.load(from: url), UserDefinedLanguage.example)
    }

    /// Ví dụ dựng sẵn phải THẬT SỰ chạy được, không chỉ là dữ liệu mẫu trông đẹp.
    func testExampleActuallyHighlights() {
        let result = scopes(UserDefinedLanguage.example, "NẾU đúng THÌ ; ghi chú")
        XCTAssertEqual(result.map(\.1), ["keyword", "constant", "keyword", "comment"])
    }

    func testBrokenFileIsSkippedNotFatal() throws {
        try "{ hỏng".write(
            to: directory.appendingPathComponent("hong.json"), atomically: true, encoding: .utf8
        )
        try UserDefinedLanguage.example.save(to: directory.appendingPathComponent("tot.json"))
        XCTAssertEqual(UserDefinedLanguage.all(in: directory).count, 1)
    }
}
