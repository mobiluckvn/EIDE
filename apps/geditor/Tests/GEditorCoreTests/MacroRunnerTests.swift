import XCTest
@testable import GEditorCore

/// Ghi và phát macro (FR-AUTO-601/602 · TC-AUTO-01, TC-AUTO-02).
final class MacroRunnerTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    // MARK: - Những bước cơ bản

    func testInsertAtCaret() {
        let text = buffer("abc\n")
        let runner = MacroRunner(buffer: text, caretOffset: 1)
        runner.run(Macro(name: "m", steps: [.insert("X")]), repetitions: 1)
        XCTAssertEqual(text.text, "aXbc\n")
        XCTAssertEqual(runner.caretOffset, 2)
    }

    func testDeleteBackwardRemovesAWholeCharacter() {
        // "ệ" là 3 byte. Xóa một BYTE sẽ để lại rác — với tiếng Việt là hầu hết các lần xóa.
        //
        // Offset tính TỪ NỘI DUNG, không đếm tay: bản đầu tôi ghi 4, mà "Vi" là 2 byte nên
        // ngay sau "ệ" là 5. Đếm tay offset của chữ nhiều byte là chỗ tôi đã sai vài lần.
        let content = "Việt\n"
        let text = buffer(content)
        let afterE = "Việ".utf8.count
        let runner = MacroRunner(buffer: text, caretOffset: afterE)
        runner.run(Macro(name: "m", steps: [.deleteBackward]), repetitions: 1)
        XCTAssertEqual(text.text, "Vit\n")
    }

    func testSelectLineExcludesTheNewline() {
        let text = buffer("mot\nhai\n")
        let runner = MacroRunner(buffer: text, caretOffset: 5)
        runner.run(Macro(name: "m", steps: [.selectLine, .insert("X")]), repetitions: 1)
        XCTAssertEqual(text.text, "mot\nX\n", "xuống dòng phải còn nguyên")
    }

    func testMovesWalkLines() {
        let text = buffer("aa\nbb\ncc\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        runner.run(Macro(name: "m", steps: [.move(.nextLine), .move(.lineEnd), .insert("!")]),
                   repetitions: 1)
        XCTAssertEqual(text.text, "aa\nbb!\ncc\n")
    }

    // MARK: - TC-AUTO-01: phát N lần bằng làm tay N lần

    func testHundredRepetitionsMatchDoingItByHand() {
        let source = (0 ..< 100).map { "loi \($0) ERROR duoi\n" }.joined()
        let expected = (0 ..< 100).map { "loi \($0) WARN duoi\n" }.joined()

        let text = buffer(source)
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        let macro = Macro(name: "doi", steps: [
            .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("WARN"),
        ])
        let result = runner.run(macro, repetitions: 100)

        XCTAssertEqual(result.repetitions, 100)
        XCTAssertEqual(result.reason, .finished)
        XCTAssertEqual(text.text, expected)
    }

    /// Toàn bộ lần chạy là MỘT bước undo (FR-CORE-004).
    ///
    /// Bắt người dùng bấm Cmd+Z một trăm lần là biến undo thành thứ không dùng được.
    func testWholeRunIsOneUndoStep() {
        let source = (0 ..< 50).map { "x\($0) ERROR\n" }.joined()
        let text = buffer(source)
        let depth = text.undoDepth

        let runner = MacroRunner(buffer: text, caretOffset: 0)
        runner.run(Macro(name: "doi", steps: [
            .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("WARN"),
        ]), repetitions: 50)

        XCTAssertNotEqual(text.text, source)
        XCTAssertEqual(text.undoDepth, depth + 1, "50 lần thay thế phải là MỘT bước undo")
        XCTAssertTrue(text.undo())
        XCTAssertEqual(text.text, source, "một lần undo phải về nguyên trạng")
    }

    func testMacroThatChangesNothingLeavesNoUndoStep() {
        let text = buffer("khong co gi\n")
        let depth = text.undoDepth
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        runner.run(Macro(name: "m", steps: [.move(.lineEnd)]), repetitions: 3)
        XCTAssertEqual(text.undoDepth, depth, "không sửa gì thì không được để lại bước hoàn tác")
    }

    // MARK: - Regex và nhóm bắt

    func testRegexCaptureGroupsInReplacement() {
        let text = buffer("ten=Nguyen\nten=Tran\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        runner.run(Macro(name: "m", steps: [
            .find(pattern: "ten=(\\w+)", mode: .regex, matchCase: true, wholeWord: false),
            .replaceSelection("name[$1]"),
        ]), repetitions: 2)
        XCTAssertEqual(text.text, "name[Nguyen]\nname[Tran]\n")
    }

    func testDollarWithoutAGroupStaysLiteral() {
        let text = buffer("gia 100\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        runner.run(Macro(name: "m", steps: [
            .find(pattern: "100", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("$9 USD"),
        ]), repetitions: 1)
        XCTAssertEqual(text.text, "gia $9 USD\n")
    }

    // MARK: - TC-AUTO-02: chạy đến cuối file

    func testRunUntilEndOfFileStopsWhenNothingIsLeft() {
        let source = (0 ..< 500).map { "dong \($0) ERROR\n" }.joined()
        let text = buffer(source)
        let runner = MacroRunner(buffer: text, caretOffset: 0)

        let result = runner.run(Macro(name: "m", steps: [
            .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("OK"),
        ]), repetitions: 0)

        XCTAssertEqual(result.repetitions, 500)
        XCTAssertEqual(result.reason, .notFound)
        XCTAssertFalse(text.text.contains("ERROR"))
    }

    /// Macro đi từng dòng phải dừng ở CUỐI FILE, không chạy mãi.
    func testLineWalkingMacroStopsAtTheLastLine() {
        let text = buffer((0 ..< 200).map { "dong \($0)\n" }.joined())
        let runner = MacroRunner(buffer: text, caretOffset: 0)

        let result = runner.run(Macro(name: "m", steps: [
            .move(.lineStart), .insert("> "), .move(.nextLine),
        ]), repetitions: 0)

        XCTAssertEqual(result.reason, .endOfDocument)
        // Khẳng định KẾT QUẢ, không khẳng định số vòng: số vòng phụ thuộc việc tài liệu có
        // dòng rỗng cuối hay không, còn thứ người dùng quan tâm là mọi dòng đều được xử lý.
        let lines = text.text.split(separator: "\n", omittingEmptySubsequences: false)
        for index in 0 ..< 200 {
            XCTAssertEqual(lines[index], "> dong \(index)", "dòng \(index)")
        }
    }

    /// Macro KHÔNG làm gì cả cũng phải dừng — đây là điều TC-AUTO-02 gọi tên: "không lặp vô hạn".
    func testMacroWithNoProgressStopsInsteadOfHanging() {
        let text = buffer("noi dung\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        let result = runner.run(Macro(name: "m", steps: [.move(.documentStart)]), repetitions: 0)
        XCTAssertEqual(result.reason, .madeNoProgress)
        XCTAssertEqual(result.repetitions, 1)
    }

    func testCancellationStopsTheRun() {
        let text = buffer((0 ..< 10_000).map { "dong \($0) ERROR\n" }.joined())
        let token = CancelToken()
        token.cancel()

        let runner = MacroRunner(buffer: text, caretOffset: 0)
        let result = runner.run(Macro(name: "m", steps: [
            .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("OK"),
        ]), repetitions: 0, cancelToken: token)

        XCTAssertEqual(result.reason, .cancelled)
        XCTAssertEqual(result.repetitions, 0)
    }

    /// Đếm số lần phải ĐÚNG khi tài liệu có ít chỗ khớp hơn số lần yêu cầu.
    func testStopsEarlyWhenThereAreFewerMatchesThanRepetitions() {
        let text = buffer("ERROR mot\nbinh thuong\nERROR hai\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        let result = runner.run(Macro(name: "m", steps: [
            .find(pattern: "ERROR", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("OK"),
        ]), repetitions: 100)

        XCTAssertEqual(result.repetitions, 2)
        XCTAssertEqual(result.reason, .notFound)
        XCTAssertEqual(text.text, "OK mot\nbinh thuong\nOK hai\n")
    }

    func testEmptyMacroDoesNothing() {
        let text = buffer("giu nguyen\n")
        let runner = MacroRunner(buffer: text, caretOffset: 0)
        let result = runner.run(Macro(name: "rong", steps: []), repetitions: 10)
        XCTAssertEqual(result.reason, .finished)
        XCTAssertEqual(text.text, "giu nguyen\n")
    }
}

/// Tìm chỗ khớp KẾ TIẾP từ một vị trí (nền của bước `find` trong macro).
final class DocumentSearchNextTests: XCTestCase {

    private func pattern(_ text: String, _ mode: SearchMode = .normal) throws -> PCRE2Pattern {
        try PCRE2Pattern(pattern: text, options: SearchOptions(mode: mode, matchCase: true))
    }

    func testFindsTheFirstMatchAtOrAfterTheOffset() throws {
        let buffer = TextBuffer(text: "aa X bb X cc\n")
        let compiled = try pattern("X")
        XCTAssertEqual(try DocumentSearch.findNext(pattern: compiled, in: buffer, from: 0)?.range, 3 ..< 4)
        XCTAssertEqual(try DocumentSearch.findNext(pattern: compiled, in: buffer, from: 4)?.range, 8 ..< 9)
    }

    func testWrapsWhenAskedAndDoesNotWhenNot() throws {
        let buffer = TextBuffer(text: "X sau do khong con\n")
        let compiled = try pattern("X")
        XCTAssertEqual(
            try DocumentSearch.findNext(pattern: compiled, in: buffer, from: 5, wrap: true)?.range,
            0 ..< 1
        )
        XCTAssertNil(try DocumentSearch.findNext(pattern: compiled, in: buffer, from: 5, wrap: false))
    }

    /// `^` phải vẫn là "đầu dòng" kể cả khi bắt đầu tìm từ GIỮA dòng.
    ///
    /// Cắt cửa sổ ngay tại offset sẽ biến giữa dòng thành "đầu dòng" và regex neo dòng khớp
    /// sai chỗ — lỗi chỉ hiện ra với regex, tức là đúng chỗ người dùng tin tưởng nhất.
    func testLineAnchorsStillMeanLineStart() throws {
        let buffer = TextBuffer(text: "mot hai\nba bon\n")
        let compiled = try pattern("^ba", .regex)
        XCTAssertEqual(try DocumentSearch.findNext(pattern: compiled, in: buffer, from: 4)?.range, 8 ..< 10)
    }

    func testNoMatchIsNil() throws {
        let buffer = TextBuffer(text: "khong co gi\n")
        XCTAssertNil(try DocumentSearch.findNext(pattern: try pattern("ZZZ"), in: buffer, from: 0))
    }

    func testEmptyBufferIsSafe() throws {
        XCTAssertNil(try DocumentSearch.findNext(pattern: try pattern("x"), in: TextBuffer(text: ""), from: 0))
    }
}

/// Lưu macro có tên, sống qua các lần mở app (FR-AUTO-601, TC-AUTO-01).
final class MacroStoreTests: XCTestCase {

    private var root: URL!

    override func setUp() {
        super.setUp()
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("geditor-macros-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func store() -> MacroStore { MacroStore(root: root) }

    func testSavedMacroComesBackExactly() throws {
        let macro = Macro(name: "Đổi ERROR", steps: [
            .find(pattern: "^ERROR (\\w+)$", mode: .regex, matchCase: true, wholeWord: false),
            .replaceSelection("WARN $1"),
            .move(.nextLine),
            .insert("x"),
            .deleteBackward,
            .selectLine,
        ])
        let store = self.store()
        try store.save(macro)

        // Đọc bằng một store MỚI: đúng thứ xảy ra khi mở lại app.
        let reopened = try MacroStore(root: root).all()
        XCTAssertEqual(reopened, [macro])
    }

    func testSeveralMacrosSortedByName() throws {
        let store = self.store()
        for name in ["Zeta", "alpha", "Beta"] {
            try store.save(Macro(name: name, steps: [.insert(name)]))
        }
        XCTAssertEqual(try store.all().map(\.name), ["alpha", "Beta", "Zeta"])
    }

    /// Tên macro do NGƯỜI DÙNG đặt, nên nó có thể chứa bất cứ thứ gì.
    ///
    /// "sửa CSV / cột 3" mà ghép thẳng vào đường dẫn thì dấu gạch chéo thành thư mục con và
    /// file rơi vào chỗ không ai tìm được; tên bắt đầu bằng dấu chấm thì thành file ẩn.
    func testDangerousNamesBecomeSafeFileNames() throws {
        let store = self.store()
        let macro = Macro(name: "sửa CSV / cột 3", steps: [.insert("x")])
        try store.save(macro)

        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertFalse(files[0].contains("/"))
        XCTAssertFalse(files[0].hasPrefix("."))
        XCTAssertEqual(try store.all().first?.name, "sửa CSV / cột 3", "TÊN vẫn giữ nguyên")
    }

    func testEmptyNameStillGetsAFile() throws {
        let store = self.store()
        try store.save(Macro(name: "...", steps: [.insert("x")]))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["macro.json"])
    }

    func testCorruptFileIsSkippedNotFatal() throws {
        let store = self.store()
        try store.save(Macro(name: "tot", steps: [.insert("x")]))
        try Data("{ hỏng".utf8).write(to: root.appendingPathComponent("hong.json"))
        XCTAssertEqual(try store.all().map(\.name), ["tot"], "file hỏng bị bỏ qua, phần còn lại vẫn đọc")
    }

    func testDeleteRemovesIt() throws {
        let store = self.store()
        try store.save(Macro(name: "tam", steps: [.insert("x")]))
        try store.delete(named: "tam")
        XCTAssertTrue(try store.all().isEmpty)
        XCTAssertNoThrow(try store.delete(named: "tam"))
    }

    func testEmptyDirectoryIsEmptyList() throws {
        XCTAssertTrue(try store().all().isEmpty)
    }
}
