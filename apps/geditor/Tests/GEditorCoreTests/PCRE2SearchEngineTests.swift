import XCTest
@testable import GEditorCore

/// Kiểm thử engine regex PCRE2 (ADR-03, PoC-C).
///
/// Trọng tâm nằm ở VÒNG LẶP KHỚP TOÀN CỤC chứ không phải ở PCRE2 — upstream đã có bộ test
/// riêng của họ. Ba chỗ vòng lặp dễ sai và đều làm treo hoặc mất kết quả một cách im lặng:
/// khớp rỗng, `\K` kéo lùi điểm bắt đầu, và nhích-một-ký-tự trên UTF-8/CRLF.
final class PCRE2SearchEngineTests: XCTestCase {

    private let engine = PCRE2SearchEngine()

    private func find(
        _ pattern: String,
        in text: String,
        mode: SearchMode = .regex,
        matchCase: Bool = true,
        wholeWord: Bool = false,
        multiline: Bool = true,
        dotAll: Bool = false,
        limit: Int = 0
    ) throws -> [SearchMatch] {
        try engine.find(
            pattern: pattern,
            in: Array(text.utf8),
            options: SearchOptions(
                mode: mode, matchCase: matchCase, wholeWord: wholeWord,
                multiline: multiline, dotMatchesNewline: dotAll
            ),
            limit: limit,
            cancelToken: CancelToken()
        )
    }

    private func ranges(_ matches: [SearchMatch]) -> [Range<Int>] { matches.map(\.range) }

    private func text(_ match: SearchMatch, in source: String) -> String {
        String(decoding: Array(source.utf8)[match.range], as: UTF8.self)
    }

    // MARK: - Bản dựng

    /// NFR-PORT-01: JIT phải có mặt và nhắm ĐÚNG kiến trúc đang chạy, không âm thầm rơi về
    /// interpreter. Đây là khẳng định rẻ nhất bắt được lỗi cấu hình build PCRE2.
    func testJITAvailableForCurrentArchitecture() {
        XCTAssertTrue(PCRE2SearchEngine.isJITAvailable, "PCRE2 dựng thiếu SUPPORT_JIT")
        let target = PCRE2SearchEngine.jitTarget
        #if arch(arm64)
        XCTAssertTrue(target.contains("ARM") || target.contains("aarch"), "jitTarget = \(target)")
        #elseif arch(x86_64)
        XCTAssertTrue(target.contains("x86"), "jitTarget = \(target)")
        #endif
        XCTAssertFalse(PCRE2SearchEngine.version.isEmpty)
    }

    func testPatternIsActuallyJITCompiled() throws {
        let pattern = try PCRE2Pattern(pattern: "\\d+", options: SearchOptions(mode: .regex))
        XCTAssertTrue(pattern.isJITCompiled, "pattern thường phải JIT hóa được")
    }

    // MARK: - Cơ bản

    func testLiteralModeEscapesNothingByAccident() throws {
        // Chế độ normal phải coi ".*" là ba ký tự, không phải regex.
        let matches = try find(".*", in: "a.*b và a.b", mode: .normal)
        XCTAssertEqual(ranges(matches), [1 ..< 3])
    }

    func testCaseInsensitive() throws {
        let matches = try find("huế", in: "Huế HUẾ huế", mode: .normal, matchCase: false)
        XCTAssertEqual(matches.count, 3, "so khớp không phân biệt hoa thường phải đúng với tiếng Việt")
    }

    func testWholeWordLiteral() throws {
        let source = "cat concat cat."
        let matches = try find("cat", in: source, mode: .normal, wholeWord: true)
        XCTAssertEqual(ranges(matches), [0 ..< 3, 11 ..< 14])
    }

    func testWholeWordRegex() throws {
        let matches = try find("c.t", in: "cat concat cut", wholeWord: true)
        XCTAssertEqual(ranges(matches), [0 ..< 3, 11 ..< 14])
    }

    func testGroups() throws {
        let source = "2026-08-19"
        let matches = try find("(\\d{4})-(\\d{2})-(\\d{2})", in: source)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].groups.count, 3)
        XCTAssertEqual(matches[0].groups[0], 0 ..< 4)
        XCTAssertEqual(matches[0].groups[2], 8 ..< 10)
    }

    func testUnmatchedGroupIsNil() throws {
        let matches = try find("(a)|(b)", in: "b")
        XCTAssertEqual(matches.count, 1)
        XCTAssertNil(matches[0].groups[0], "nhóm không tham gia phải là nil, không phải 0..<0")
        XCTAssertEqual(matches[0].groups[1], 0 ..< 1)
    }

    func testLimitStopsEarly() throws {
        let matches = try find("a", in: String(repeating: "a", count: 100), limit: 5)
        XCTAssertEqual(matches.count, 5)
    }

    func testCompileErrorCarriesPositionAndMessage() {
        XCTAssertThrowsError(try find("(chưa đóng", in: "x")) { error in
            guard let compileError = error as? RegexCompileError else {
                return XCTFail("phải là RegexCompileError, nhận \(error)")
            }
            XCTAssertFalse(compileError.message.isEmpty)
            XCTAssertGreaterThan(compileError.offset, 0, "phải chỉ được VỊ TRÍ sai trong pattern")
        }
    }

    // MARK: - Những gì ICU không làm được (lý do bỏ NSRegularExpression)

    /// `\K` đặt lại điểm bắt đầu báo cáo. ICU không có; Notepad++ có.
    func testBackslashKResetsMatchStart() throws {
        let matches = try find("foo\\Kbar", in: "foobar")
        XCTAssertEqual(ranges(matches), [3 ..< 6], "\\K phải loại 'foo' khỏi vùng khớp")
    }

    /// `\K` trong vòng lặp toàn cục là bẫy lặp vô hạn: điểm bắt đầu báo cáo lùi về trước
    /// vị trí đang tìm. Test này treo nếu vòng lặp xử lý sai.
    func testBackslashKDoesNotLoopForever() throws {
        let matches = try find("a\\K", in: "aaa")
        XCTAssertEqual(ranges(matches), [1 ..< 1, 2 ..< 2, 3 ..< 3])
    }

    func testVariableLengthLookbehind() throws {
        // PCRE2 cho lookbehind độ dài thay đổi trong giới hạn; ICU từ chối pattern này.
        let matches = try find("(?<=đơn\\s{1,3})\\d+", in: "đơn   1234")
        XCTAssertEqual(ranges(matches).count, 1)
    }

    // MARK: - Khớp rỗng

    /// `a*` khớp chuỗi rỗng ở mọi vị trí. Kỳ vọng lấy theo hành vi chuẩn của Perl/PCRE
    /// với cờ /g trên "bab": "", "a", "", "".
    func testEmptyMatchesAdvanceExactlyLikePerl() throws {
        let matches = try find("a*", in: "bab")
        XCTAssertEqual(ranges(matches), [0 ..< 0, 1 ..< 2, 2 ..< 2, 3 ..< 3])
    }

    func testEmptyPatternMatchesEveryPosition() throws {
        let matches = try find("", in: "abc", mode: .regex)
        XCTAssertEqual(ranges(matches), [0 ..< 0, 1 ..< 1, 2 ..< 2, 3 ..< 3])
    }

    /// Nhích qua khớp rỗng phải nhích một KÝ TỰ, không phải một BYTE — nếu không, lần tìm
    /// tiếp theo bắt đầu giữa một chuỗi UTF-8 và kết quả sai lệch âm thầm.
    func testEmptyMatchAdvancesByCharacterNotByte() throws {
        let source = "áé"   // hai ký tự, bốn byte
        let matches = try find("x*", in: source)
        XCTAssertEqual(ranges(matches), [0 ..< 0, 2 ..< 2, 4 ..< 4])
    }

    /// CRLF là MỘT ký tự xuống dòng: không được nhích vào giữa cặp.
    func testEmptyMatchDoesNotSplitCRLF() throws {
        let matches = try find("x*", in: "a\r\nb")
        XCTAssertEqual(ranges(matches), [0 ..< 0, 1 ..< 1, 3 ..< 3, 4 ..< 4])
    }

    // MARK: - Unicode / tiếng Việt

    func testWordCharactersIncludeVietnameseDiacritics() throws {
        // Không có PCRE2_UCP, `\w` chỉ là [A-Za-z0-9_] và sẽ cắt "Huế" thành "Hu".
        let source = "Thừa Thiên Huế"
        let matches = try find("\\w+", in: source)
        XCTAssertEqual(matches.map { text($0, in: source) }, ["Thừa", "Thiên", "Huế"])
    }

    func testUnicodePropertyClass() throws {
        let source = "abc123áé"
        let matches = try find("\\p{L}+", in: source)
        XCTAssertEqual(matches.map { text($0, in: source) }, ["abc", "áé"])
    }

    func testByteOffsetsAreBytesNotCharacters() throws {
        let source = "áb"   // 'á' = 2 byte
        let matches = try find("b", in: source, mode: .normal)
        XCTAssertEqual(ranges(matches), [2 ..< 3], "hợp đồng của lõi là offset BYTE")
    }

    /// File thật có byte hỏng (dữ liệu TCVN3/VNI chưa chuyển mã, mở nhầm file nhị phân).
    /// Không được để một byte hỏng làm hỏng cả lần tìm.
    func testInvalidUTF8DoesNotAbortSearch() throws {
        var bytes = Array("trước ".utf8)
        bytes.append(0xFF)                       // không hợp lệ trong UTF-8
        bytes.append(contentsOf: Array(" sau".utf8))

        let matches = try engine.find(
            pattern: "sau", in: bytes,
            options: SearchOptions(mode: .normal), limit: 0, cancelToken: CancelToken()
        )
        XCTAssertEqual(matches.count, 1, "phải vẫn khớp phần hợp lệ sau byte hỏng")
    }

    // MARK: - Neo dòng

    func testMultilineAnchors() throws {
        let source = "một\nhai\nba"
        let matches = try find("^\\w+", in: source)
        XCTAssertEqual(matches.map { text($0, in: source) }, ["một", "hai", "ba"])
    }

    func testWithoutMultilineAnchorsOnlyMatchDocumentStart() throws {
        let matches = try find("^\\w+", in: "một\nhai", multiline: false)
        XCTAssertEqual(matches.count, 1)
    }

    func testDotDoesNotCrossNewlineByDefault() throws {
        XCTAssertEqual(try find("a.b", in: "a\nb").count, 0)
        XCTAssertEqual(try find("a.b", in: "a\nb", dotAll: true).count, 1)
    }

    // MARK: - Chế độ Extended

    func testExtendedModeDecodesEscapes() throws {
        let matches = try find("a\\tb", in: "a\tb", mode: .extended)
        XCTAssertEqual(ranges(matches), [0 ..< 3])
    }

    func testExtendedModeStillLiteralForRegexMetacharacters() throws {
        let matches = try find("a\\t.", in: "a\t. và a\tx", mode: .extended)
        XCTAssertEqual(ranges(matches), [0 ..< 3], "'.' trong extended vẫn là dấu chấm")
    }

    // MARK: - TC-SRCH-03 — pattern backtracking độc KHÔNG được treo

    /// Đây là test quan trọng nhất của ADR-03.
    ///
    /// `FoundationSearchEngine` KHÔNG pass được test này: nó không có trần backtracking, nên
    /// một lần khớp duy nhất giữ luồng cho tới khi xong (có thể là hàng phút). PCRE2 cưỡng
    /// chế `match_limit` NGAY GIỮA lần khớp và trả lỗi.
    func testCatastrophicBacktrackingFailsFastInsteadOfHanging() throws {
        // Fixture và ngưỡng lấy nguyên từ STP TC-SRCH-03: pattern (a+)+$ trên chuỗi 10.000
        // ký tự "a" cộng "b", phải bị chặn trong ≤ 2 s.
        let subject = String(repeating: "a", count: 10_000) + "b"
        let start = Date()

        XCTAssertThrowsError(try find("(a+)+$", in: subject)) { error in
            guard let budget = error as? RegexBudgetExceeded else {
                return XCTFail("phải là RegexBudgetExceeded, nhận \(error)")
            }
            XCTAssertEqual(budget.kind, .matchLimit)
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 2.0, "TC-SRCH-03 đòi ≤ 2 s, mất \(elapsed)s")
    }

    /// Trần thấp phải cắt sớm hơn trần cao — chứng minh `matchLimit` thật sự có hiệu lực
    /// chứ không phải pattern tự dừng vì lý do khác.
    func testLowerMatchLimitCutsEarlier() throws {
        let subject = String(repeating: "a", count: 10_000) + "b"
        var limits = PCRE2Pattern.Limits()
        limits.matchLimit = 1_000

        let strict = PCRE2SearchEngine(limits: limits)
        XCTAssertThrowsError(
            try strict.find(
                pattern: "(a+)+$", in: Array(subject.utf8),
                options: SearchOptions(mode: .regex), limit: 0, cancelToken: CancelToken()
            )
        )
    }

    /// Pattern lành phải không bị trần chặn nhầm.
    func testNormalPatternIsNotBlockedByLimits() throws {
        let source = String(repeating: "khách hàng 12345\n", count: 2_000)
        let matches = try find("\\d+", in: source)
        XCTAssertEqual(matches.count, 2_000)
    }

    /// Deadline theo đồng hồ vẫn phải cắt được lần tìm có RẤT NHIỀU kết quả — cơ chế này
    /// bù cho `matchLimit` (vốn chỉ chặn bên trong MỘT lần khớp).
    func testDeadlineStopsLongRunningSearch() {
        let source = String(repeating: "a", count: 2_000_000)
        let token = CancelToken(timeout: 0.001)
        XCTAssertThrowsError(
            try engine.find(
                pattern: "a", in: Array(source.utf8),
                options: SearchOptions(mode: .normal), limit: 0, cancelToken: token
            )
        ) { error in
            XCTAssertTrue(error is DeadlineExceeded, "nhận \(error)")
        }
    }

    // MARK: - Đối chứng với engine ICU

    /// Trên tập pattern mà ICU và PCRE2 đồng nghĩa, hai engine phải cho kết quả GIỐNG HỆT.
    /// Bất đồng ở đây gần như luôn là lỗi vòng lặp khớp của ta, không phải khác biệt cú pháp.
    func testAgreesWithFoundationEngineOnCommonPatterns() throws {
        let icu = FoundationSearchEngine()
        let source = """
        DH-0091,Công ty Anh Đào,128500000,2026-07-02
        DH-0092,Xí nghiệp Sông Hàn,98000000,2026-07-03

        DH-0100,,0,2026-12-31
        """
        let bytes = Array(source.utf8)

        let patterns = [
            "DH-\\d+",
            "\\d{4}-\\d{2}-\\d{2}",
            ",,",
            "^DH",
            "\\d+$",
            "(\\w+)-(\\d+)",
            "[A-Z]{2}",
        ]

        for pattern in patterns {
            let options = SearchOptions(mode: .regex, matchCase: true)
            let mine = try engine.find(
                pattern: pattern, in: bytes, options: options, limit: 0, cancelToken: CancelToken()
            )
            let theirs = try icu.find(
                pattern: pattern, in: bytes, options: options, limit: 0, cancelToken: CancelToken()
            )
            XCTAssertEqual(ranges(mine), ranges(theirs), "bất đồng ở pattern \(pattern)")
        }
    }
}
