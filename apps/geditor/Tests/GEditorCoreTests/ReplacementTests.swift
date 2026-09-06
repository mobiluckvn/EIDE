import XCTest
@testable import GEditorCore

/// Kiểm thử Replace All (FR-SRCH-103, FR-CORE-004).
final class ReplacementTests: XCTestCase {

    private func plan(
        _ pattern: String,
        _ template: String,
        in text: String,
        mode: SearchMode = .regex,
        limit: Int = 0
    ) throws -> ReplacementPlan {
        let compiled = try PCRE2Pattern(pattern: pattern, options: SearchOptions(mode: mode))
        return try Array(text.utf8).withUnsafeBytes {
            try compiled.replacementEdits(in: $0, template: template, limit: limit)
        }
    }

    /// Áp kế hoạch vào một buffer và trả về kết quả — đúng cách lớp trên sẽ dùng.
    private func apply(_ plan: ReplacementPlan, to text: String) -> String {
        let buffer = TextBuffer(text: text)
        buffer.applyEdits(plan.edits, label: "Thay thế tất cả")
        return String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self)
    }

    // MARK: - Cơ bản

    func testLiteralReplacement() throws {
        let source = "một hai một ba một"
        let result = try plan("một", "MỘT", in: source, mode: .normal)
        XCTAssertEqual(result.matchCount, 3)
        XCTAssertEqual(apply(result, to: source), "MỘT hai MỘT ba MỘT")
    }

    func testByteDeltaMatchesActualChange() throws {
        let source = "aaa"
        let result = try plan("a", "bbbb", in: source, mode: .normal)
        XCTAssertEqual(result.byteDelta, 9, "3 lần × (4 − 1) byte")
        XCTAssertEqual(apply(result, to: source).utf8.count, source.utf8.count + result.byteDelta)
    }

    func testDeletionViaEmptyTemplate() throws {
        let source = "a1b2c3"
        let result = try plan("\\d", "", in: source)
        XCTAssertEqual(apply(result, to: source), "abc")
        XCTAssertEqual(result.byteDelta, -3)
    }

    /// FR-CORE-004: dù thay bao nhiêu vị trí, undo phải trả về nguyên trạng trong MỘT bước.
    func testWholeReplacementIsOneUndoStep() throws {
        let source = String(repeating: "cũ\n", count: 500)
        let result = try plan("cũ", "mới", in: source, mode: .normal)
        XCTAssertEqual(result.matchCount, 500)

        let buffer = TextBuffer(text: source)
        buffer.applyEdits(result.edits, label: "Thay thế tất cả")
        XCTAssertEqual(buffer.text, String(repeating: "mới\n", count: 500))

        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, source)
        XCTAssertFalse(buffer.canUndo, "500 vị trí phải là MỘT bước undo, không phải 500")
    }

    // MARK: - Tham chiếu nhóm

    func testDollarGroupReferences() throws {
        let source = "2026-08-20"
        let result = try plan("(\\d{4})-(\\d{2})-(\\d{2})", "$3/$2/$1", in: source)
        XCTAssertEqual(apply(result, to: source), "20/08/2026")
    }

    func testBracedGroupReference() throws {
        let source = "abc"
        let result = try plan("(a)(b)(c)", "${3}${2}${1}", in: source)
        XCTAssertEqual(apply(result, to: source), "cba")
    }

    func testNamedGroupReference() throws {
        let source = "DH-0091"
        let result = try plan("(?<prefix>[A-Z]+)-(?<number>\\d+)", "${number}-${prefix}", in: source)
        XCTAssertEqual(apply(result, to: source), "0091-DH")
    }

    /// Nhóm không tham gia lần khớp phải thành chuỗi rỗng, không phải lỗi.
    func testUnsetGroupBecomesEmpty() throws {
        let source = "b"
        let result = try plan("(a)?(b)", "[$1][$2]", in: source)
        XCTAssertEqual(apply(result, to: source), "[][b]")
    }

    /// `\1` là thói quen từ Notepad++; ta dịch sang `${1}` trước khi đưa cho PCRE2.
    func testBackslashGroupReferenceIsTranslated() throws {
        let source = "ab"
        let result = try plan("(a)(b)", "\\2\\1", in: source)
        XCTAssertEqual(apply(result, to: source), "ba")
    }

    /// `\1` theo sau bởi chữ số literal không được nuốt thành nhóm 12.
    func testBackslashGroupReferenceDoesNotSwallowFollowingDigits() {
        XCTAssertEqual(PCRE2Pattern.normalizeTemplate("\\1"), "${1}")
        XCTAssertEqual(PCRE2Pattern.normalizeTemplate("\\12"), "${12}")
        XCTAssertEqual(PCRE2Pattern.normalizeTemplate("\\123"), "${12}3")
        XCTAssertEqual(PCRE2Pattern.normalizeTemplate("\\\\1"), "\\\\1", "gạch chéo đã escape không phải tham chiếu")
        XCTAssertEqual(PCRE2Pattern.normalizeTemplate("\\U$1\\E"), "\\U$1\\E", "escape ép hoa/thường giữ nguyên")
    }

    // MARK: - Biến đổi hoa/thường (chính là FR-SRCH-103)

    func testUppercaseUntilE() throws {
        // Pattern khớp HAI lần ("công ty" và "anh đào"); `\U…\E` chỉ ép hoa nhóm 1 của mỗi
        // lần khớp, còn nhóm 2 giữ nguyên — đó chính là điều cần khẳng định về phạm vi `\E`.
        let source = "công ty anh đào"
        let result = try plan("(\\w+) (\\w+)", "\\U$1\\E $2", in: source)
        XCTAssertEqual(result.matchCount, 2)
        XCTAssertEqual(apply(result, to: source), "CÔNG ty ANH đào", "\\U phải ép hoa cả tiếng Việt")
    }

    func testCapitalizeSingleCharacter() throws {
        let source = "huế đà nẵng"
        let result = try plan("\\w+", "\\u$0", in: source)
        XCTAssertEqual(apply(result, to: source), "Huế Đà Nẵng")
    }

    func testLowercaseTransformation() throws {
        let source = "THỪA THIÊN"
        let result = try plan("(\\w+)", "\\L$1\\E", in: source)
        XCTAssertEqual(apply(result, to: source), "thừa thiên")
    }

    func testEscapedSequencesInTemplate() throws {
        let source = "a,b"
        let result = try plan(",", "\\n", in: source, mode: .normal)
        XCTAssertEqual(apply(result, to: source), "a\nb")
    }

    func testDoubleDollarIsLiteralDollar() throws {
        let source = "x"
        let result = try plan("x", "$$", in: source, mode: .normal)
        XCTAssertEqual(apply(result, to: source), "$")
    }

    // MARK: - Khớp rỗng

    func testEmptyMatchInsertsAtEveryPosition() throws {
        let source = "abc"
        let result = try plan("", "-", in: source)
        XCTAssertEqual(result.matchCount, 4)
        XCTAssertEqual(apply(result, to: source), "-a-b-c-")
    }

    // MARK: - Giới hạn và lỗi

    func testLimitTruncatesPlan() throws {
        let source = String(repeating: "x", count: 100)
        let result = try plan("x", "y", in: source, mode: .normal, limit: 10)
        XCTAssertTrue(result.truncated)
        XCTAssertEqual(result.edits.count, 10)
    }

    func testBadTemplateReportsPosition() {
        XCTAssertThrowsError(try plan("(a)", "${chưa đóng", in: "a")) { error in
            guard let templateError = error as? ReplacementTemplateError else {
                return XCTFail("phải là ReplacementTemplateError, nhận \(error)")
            }
            XCTAssertFalse(templateError.message.isEmpty)
        }
    }

    func testReferenceToNonexistentGroupIsAnError() {
        XCTAssertThrowsError(try plan("(a)", "$9", in: "a")) { error in
            XCTAssertTrue(
                error is ReplacementTemplateError || error is RegexCompileError,
                "nhận \(error)"
            )
        }
    }

    // MARK: - Đường nhanh cho template hằng

    /// Template không có `$` và `\` cho ra cùng một dãy byte ở mọi lần khớp; kiểm rằng đường
    /// nhanh vẫn ra đúng kết quả trên số lượng lớn, và không sinh mảng riêng cho từng lần.
    func testConstantTemplateFastPathIsCorrectAtScale() throws {
        let source = String(repeating: "tìm\n", count: 20_000)
        let result = try plan("tìm", "thấy", in: source, mode: .normal)
        XCTAssertEqual(result.matchCount, 20_000)

        // Mọi TextEdit phải dùng chung một vùng lưu trữ (copy-on-write), nếu không thì một
        // triệu kết quả sẽ là một triệu mảng — thứ làm hỏng NFR-PERF-08.
        let first = result.edits[0].bytes
        let last = result.edits[result.edits.count - 1].bytes
        XCTAssertEqual(first, last)
        XCTAssertEqual(apply(result, to: source), String(repeating: "thấy\n", count: 20_000))
    }

    // MARK: - UTF-8

    func testByteOffsetsStayCorrectWithMultibyteText() throws {
        let source = "Huế và Đà Nẵng"
        let result = try plan("Đà Nẵng", "Hà Nội", in: source, mode: .normal)
        XCTAssertEqual(result.matchCount, 1)
        XCTAssertEqual(apply(result, to: source), "Huế và Hà Nội")
    }

    func testWorksOnInvalidUTF8Subject() throws {
        var bytes = Array("trước ".utf8)
        bytes.append(0xFF)
        bytes.append(contentsOf: Array(" sau".utf8))

        let compiled = try PCRE2Pattern(
            pattern: "sau", options: SearchOptions(mode: .normal), allowInvalidUTF: true
        )
        let result = try bytes.withUnsafeBytes {
            try compiled.replacementEdits(in: $0, template: "SAU", subjectIsValidUTF8: false)
        }
        XCTAssertEqual(result.matchCount, 1)
    }
}
