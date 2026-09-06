import XCTest
@testable import GEditorCore

/// Tự hoàn thành (FR-CORE-013).
final class CompletionEngineTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func words(_ text: String, query: String, symbols: [String] = []) -> [String] {
        CompletionEngine.suggestions(
            prefix: query, in: buffer(text), around: text.utf8.count, symbols: symbols
        ).map(\.word)
    }

    // MARK: - Thu thập từ

    func testCollectsWordsIncludingVietnamese() {
        let found = CompletionEngine.words(
            in: buffer("khach_hang = 'Nguyễn Văn An'  # ghi_chú"), around: 0
        )
        XCTAssertTrue(found.contains("khach_hang"), "\(found)")
        XCTAssertTrue(found.contains("Nguyễn"), "\(found)")
        // Chữ có dấu phải tính: một trình soạn thảo cho người Việt mà không gợi ý được
        // `ghi_chú` thì tính năng này chỉ dùng được nửa thời gian.
        XCTAssertTrue(found.contains("ghi_chú"), "\(found)")
    }

    func testSkipsOneCharacterWords() {
        let found = CompletionEngine.words(in: buffer("a bb ccc"), around: 0)
        XCTAssertEqual(found, ["bb", "ccc"])
    }

    /// Chỉ quét quanh con nháy: trên file một gigabyte thì mỗi phím gõ không thể là một lượt
    /// đọc cả file.
    func testOnlyScansTheWindowAroundTheCaret() {
        // Từ ở XA nằm tận đầu file; phần đệm ở giữa dùng chữ khác để cửa sổ cuối file không
        // vô tình chứa nó.
        var text = "xa_tit_mu_khoi = 0\n"
        text += String(repeating: "dem_cho_day ", count: 200_000)   // ~2,4 MB
        text += "\ngan_con_nhay = 1\n"
        let document = buffer(text)

        let found = CompletionEngine.words(
            in: document, around: document.count, windowBytes: 4096
        )
        XCTAssertTrue(found.contains("gan_con_nhay"), "\(found.count) từ")
        XCTAssertFalse(found.contains("xa_tit_mu_khoi"), "quét cả file thay vì cửa sổ")
    }

    // MARK: - Từ đang gõ dở

    func testReadsThePrefixBeforeTheCaret() {
        let document = buffer("let khach_ha")
        XCTAssertEqual(CompletionEngine.prefix(in: document, before: document.count), "khach_ha")
        XCTAssertEqual(CompletionEngine.prefix(in: buffer("a + "), before: 4), "")
    }

    // MARK: - Khớp mờ

    /// Ký tự của truy vấn phải đúng thứ tự nhưng không cần liền nhau.
    func testFuzzyMatching() {
        XCTAssertNotNil(CompletionEngine.score("khach_hang", query: "khh"))
        XCTAssertNotNil(CompletionEngine.score("khach_hang", query: "khach"))
        XCTAssertNil(CompletionEngine.score("khach_hang", query: "xyz"))
        // Sai thứ tự thì không khớp.
        XCTAssertNil(CompletionEngine.score("khach_hang", query: "hkh"))
    }

    /// Khớp liền nhau phải hơn khớp rải rác.
    func testContiguousBeatsScattered() {
        let contiguous = CompletionEngine.score("khach", query: "kha") ?? 0
        let scattered = CompletionEngine.score("kxhxaxc", query: "kha") ?? 0
        XCTAssertGreaterThan(contiguous, scattered)
    }

    /// Khớp đầu từ con (`_`, camelCase) được thưởng.
    func testWordBoundariesAreRewarded() {
        let boundary = CompletionEngine.score("khach_hang", query: "kh") ?? 0
        let middle = CompletionEngine.score("xkhach", query: "kh") ?? 0
        XCTAssertGreaterThan(boundary, middle)

        XCTAssertNotNil(CompletionEngine.score("tinhTongTien", query: "ttt"))
    }

    /// Gõ không dấu vẫn ra chữ có dấu — cùng luật với ô lọc CSV và Function List.
    func testDiacriticInsensitive() {
        XCTAssertNotNil(CompletionEngine.score("ghi_chú", query: "ghichu"))
        XCTAssertNotNil(CompletionEngine.score("Đà Nẵng", query: "da"))
    }

    // MARK: - Xếp hạng

    /// Ứng viên NGẮN đứng trên: gõ `te` thì `ten` phải trên `ten_khach_hang_day_du`.
    func testShorterCandidatesRankHigher() {
        let found = words("ten ten_khach_hang_day_du ten_kh", query: "te")
        XCTAssertEqual(found.first, "ten", "\(found)")
    }

    /// Tên hàm/lớp được ưu tiên hơn từ thường: gõ đúng tên hàm quan trọng hơn gõ đúng một từ
    /// trong chú thích.
    func testSymbolsOutrankPlainWords() {
        let found = words(
            "# tinh_tong là một chú thích\ntinh_tong_khac = 1\n",
            query: "tinh", symbols: ["tinh_tong"]
        )
        XCTAssertEqual(found.first, "tinh_tong", "\(found)")
    }

    /// Chính từ đang gõ không được gợi ý lại.
    func testDoesNotSuggestTheQueryItself() {
        XCTAssertFalse(words("khach khach_hang", query: "khach").contains("khach"))
    }

    /// Dưới ngưỡng thì KHÔNG gợi ý gì — một danh sách bung ra ở ký tự đầu sẽ che chính dòng
    /// người dùng đang gõ.
    func testMinimumPrefix() {
        let document = buffer("khach_hang khac")
        XCTAssertTrue(CompletionEngine.suggestions(
            prefix: "k", in: document, around: document.count
        ).isEmpty)
        XCTAssertFalse(CompletionEngine.suggestions(
            prefix: "kh", in: document, around: document.count
        ).isEmpty)
        // Ngưỡng cấu hình được, đúng như đặc tả đòi.
        XCTAssertFalse(CompletionEngine.suggestions(
            prefix: "k", in: document, around: document.count, minimumPrefix: 1
        ).isEmpty)
    }

    func testRespectsTheLimit() {
        var text = ""
        for index in 0 ..< 50 { text += "khach_hang_\(index) " }
        let document = buffer(text)
        XCTAssertEqual(
            CompletionEngine.suggestions(
                prefix: "khach", in: document, around: document.count, limit: 5
            ).count,
            5
        )
    }

    /// Cùng điểm thì thứ tự phải ỔN ĐỊNH — một danh sách tự đảo chỗ là danh sách không ai dám
    /// bấm nhanh.
    func testStableOrderForEqualScores() {
        let text = "alpha_x alpha_y alpha_z"
        let first = words(text, query: "alpha")
        let second = words(text, query: "alpha")
        XCTAssertEqual(first, second)
    }

    /// Tự hoàn thành chỉ ĐỌC tài liệu.
    func testNeverTouchesTheDocument() {
        let source = "khach_hang = 1\n"
        let document = buffer(source)
        let depth = document.undoDepth
        _ = CompletionEngine.suggestions(prefix: "kha", in: document, around: document.count)
        XCTAssertEqual(document.text, source)
        XCTAssertEqual(document.undoDepth, depth)
    }
}
