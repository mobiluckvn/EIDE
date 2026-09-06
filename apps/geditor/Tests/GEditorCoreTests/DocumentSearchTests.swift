import XCTest
@testable import GEditorCore

/// Tìm kiếm trên cả tài liệu mà không dựng cả tài liệu thành mảng byte (ADR-01).
final class DocumentSearchTests: XCTestCase {

    private func pattern(_ text: String, mode: SearchMode = .normal) throws -> PCRE2Pattern {
        try PCRE2Pattern(pattern: text, options: SearchOptions(mode: mode))
    }

    /// Đối chứng: kết quả phải TRÙNG KHÍT với cách cũ — dựng cả tài liệu rồi khớp một lần.
    private func assertMatchesNaive(
        _ buffer: TextBuffer, _ needle: String, mode: SearchMode = .normal,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let compiled = try pattern(needle, mode: mode)
        let windowed = try DocumentSearch.find(pattern: compiled, in: buffer)

        var naive: [SearchMatch] = []
        let all = buffer.bytes(in: 0 ..< buffer.count)
        try all.withUnsafeBytes { region in
            try compiled.enumerateMatches(in: region, cancelToken: CancelToken()) {
                naive.append($0)
                return true
            }
        }
        XCTAssertEqual(windowed.map(\.range), naive.map(\.range),
                       "quét theo cửa sổ lệch với quét một lần", file: file, line: line)
    }

    // MARK: - Đường liên tục

    func testContiguousBufferIsSearchedWithoutCopy() {
        let buffer = TextBuffer(text: "một hai ba\n")
        XCTAssertEqual(buffer.pieceCount, 1)
        let seen: Int? = buffer.withContiguousBytes { $0.count }
        XCTAssertEqual(seen, buffer.count, "tài liệu chưa sửa phải đi đường liên tục")
    }

    /// Tài liệu đã sửa thì phân mảnh — phải trả `nil` chứ không được tự sao chép.
    func testFragmentedBufferHasNoContiguousView() {
        let buffer = TextBuffer(text: "một hai ba\n")
        buffer.replace(4 ..< 7, with: "BA", label: "sửa")
        XCTAssertGreaterThan(buffer.pieceCount, 1)
        XCTAssertNil(buffer.withContiguousBytes { $0.count })
    }

    func testFindOnContiguousBuffer() throws {
        let buffer = TextBuffer(text: "một hai ba hai\n")
        let found = try DocumentSearch.find(pattern: try pattern("hai"), in: buffer)
        XCTAssertEqual(found.count, 2)
        try assertMatchesNaive(buffer, "hai")
    }

    // MARK: - Đường theo cửa sổ

    /// Buộc đi đường cửa sổ bằng cách làm tài liệu phân mảnh, rồi so với cách cũ.
    func testWindowedPathMatchesNaive() throws {
        let buffer = TextBuffer(text: (0 ..< 500).map { "dòng \($0) ERROR dữ liệu" }.joined(separator: "\n") + "\n")
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        XCTAssertGreaterThan(buffer.pieceCount, 1, "phải phân mảnh để đi đường cửa sổ")

        try assertMatchesNaive(buffer, "ERROR")
        try assertMatchesNaive(buffer, "dữ liệu")
        try assertMatchesNaive(buffer, "^dòng", mode: .regex)
        try assertMatchesNaive(buffer, "\\d+", mode: .regex)
    }

    /// Cửa sổ cắt tại BIÊN DÒNG: `^` không được khớp ở giữa dòng vì trùng biên cửa sổ.
    ///
    /// Đây là lý do thật của việc cắt theo dòng, không phải thẩm mỹ.
    func testLineAnchorsAreNotBrokenByWindowBoundary() throws {
        // Dựng tài liệu lớn hơn một cửa sổ để chắc chắn có nhiều hơn một biên.
        let line = "0123456789 ERROR " + String(repeating: "x", count: 200) + "\n"
        let buffer = TextBuffer(text: String(repeating: line, count: 60_000))
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        XCTAssertGreaterThan(buffer.count, DocumentSearch.windowSize, "tài liệu phải lớn hơn một cửa sổ")

        let found = try DocumentSearch.find(pattern: try pattern("^0", mode: .regex), in: buffer)
        // Mỗi dòng đúng một kết quả, không hơn: nếu biên cửa sổ tạo "đầu dòng" giả thì số này vọt lên.
        XCTAssertEqual(found.count, 60_000)
    }

    /// Kết quả vắt qua biên cửa sổ vẫn phải tìm ra, và KHÔNG được đếm hai lần.
    func testMatchNearWindowBoundaryIsFoundExactlyOnce() throws {
        let filler = String(repeating: "x", count: 100) + "\n"
        var text = String(repeating: filler, count: 90_000)
        // Đặt một mốc duy nhất ở quãng giữa, nơi các biên cửa sổ rơi vào.
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        text.insert(contentsOf: "MỐC_DUY_NHẤT\n", at: middle)

        let buffer = TextBuffer(text: text)
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        XCTAssertGreaterThan(buffer.count, DocumentSearch.windowSize)

        let found = try DocumentSearch.find(pattern: try pattern("MỐC_DUY_NHẤT"), in: buffer)
        XCTAssertEqual(found.count, 1, "kết quả gần biên bị bỏ sót hoặc đếm hai lần")
    }

    func testLimitStopsEarly() throws {
        let buffer = TextBuffer(text: (0 ..< 1_000).map { "dòng \($0) ERROR" }.joined(separator: "\n"))
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        let found = try DocumentSearch.find(pattern: try pattern("ERROR"), in: buffer, limit: 10)
        XCTAssertEqual(found.count, 10)
    }

    func testEmptyDocument() throws {
        XCTAssertTrue(try DocumentSearch.find(pattern: try pattern("x"), in: TextBuffer(text: "")).isEmpty)
    }

    /// Một dòng dài hơn cả cửa sổ: không được treo vòng lặp.
    func testSingleLineLongerThanWindow() throws {
        let buffer = TextBuffer(text: String(repeating: "y", count: DocumentSearch.windowSize + 5_000))
        buffer.replace(0 ..< 0, with: "MỐC", label: "sửa")
        let found = try DocumentSearch.find(pattern: try pattern("MỐC"), in: buffer)
        XCTAssertEqual(found.count, 1)
    }
}

/// Thay thế trên cả tài liệu, cũng không dựng cả tài liệu (ADR-01, FR-SRCH-103).
final class DocumentReplacementTests: XCTestCase {

    private func pattern(_ text: String, mode: SearchMode = .normal) throws -> PCRE2Pattern {
        try PCRE2Pattern(pattern: text, options: SearchOptions(mode: mode))
    }

    /// Đối chứng với cách cũ: dựng cả tài liệu rồi thay một lần.
    private func assertSameAsNaive(
        _ text: String, _ needle: String, _ template: String, mode: SearchMode = .normal
    ) throws {
        let compiled = try pattern(needle, mode: mode)

        let windowed = TextBuffer(text: text)
        windowed.replace(0 ..< 0, with: "", label: "chạm")   // ép phân mảnh
        let plan = try DocumentSearch.replacementEdits(
            pattern: compiled, template: template, in: windowed
        )
        windowed.applyEdits(plan.edits, label: "thay")

        let naive = TextBuffer(text: text)
        let all = naive.bytes(in: 0 ..< naive.count)
        let reference = try all.withUnsafeBytes {
            try compiled.replacementEdits(in: $0, template: template)
        }
        naive.applyEdits(reference.edits, label: "thay")

        XCTAssertEqual(windowed.text, naive.text)
        XCTAssertEqual(plan.matchCount, reference.matchCount)
    }

    func testReplaceMatchesNaiveOnSmallDocument() throws {
        try assertSameAsNaive("một hai ba hai\n", "hai", "HAI")
    }

    func testReplaceWithCaptureGroups() throws {
        try assertSameAsNaive("a=1\nb=2\nc=3\n", "(\\w)=(\\d)", "$2:$1", mode: .regex)
    }

    func testReplaceVietnamese() throws {
        try assertSameAsNaive("Việt Nam\nViệt ngữ\n", "Việt", "VIỆT")
    }

    /// Tài liệu lớn hơn một cửa sổ: kết quả phải khớp với cách cũ, và không thay hai lần.
    func testReplaceAcrossWindowBoundaries() throws {
        let line = "dòng dữ liệu ERROR " + String(repeating: "z", count: 120) + "\n"
        let text = String(repeating: line, count: 70_000)
        XCTAssertGreaterThan(text.utf8.count, DocumentSearch.windowSize)

        let buffer = TextBuffer(text: text)
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        let plan = try DocumentSearch.replacementEdits(
            pattern: try pattern("ERROR"), template: "LỖI", in: buffer
        )
        XCTAssertEqual(plan.matchCount, 70_000, "thay sót hoặc thay hai lần ở biên cửa sổ")

        buffer.applyEdits(plan.edits, label: "thay")
        XCTAssertFalse(buffer.text.contains("ERROR"))
        XCTAssertEqual(buffer.text.components(separatedBy: "LỖI").count - 1, 70_000)
    }

    /// FR-CORE-004: thay tất cả vẫn là MỘT bước undo dù có bao nhiêu kết quả.
    func testReplaceAllIsOneUndoStep() throws {
        let buffer = TextBuffer(text: (0 ..< 2_000).map { "dòng \($0) ERROR" }.joined(separator: "\n"))
        buffer.replace(0 ..< 0, with: "đầu\n", label: "sửa")
        let before = buffer.text
        let depth = buffer.undoDepth

        let plan = try DocumentSearch.replacementEdits(
            pattern: try pattern("ERROR"), template: "LỖI", in: buffer
        )
        buffer.applyEdits(plan.edits, label: "Thay thế tất cả")
        XCTAssertEqual(buffer.undoDepth, depth + 1)
        XCTAssertTrue(buffer.undo())
        XCTAssertEqual(buffer.text, before)
    }
}
