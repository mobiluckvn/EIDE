import XCTest
@testable import GEditorCore

/// Truy vết: FR-FMT-508 chế độ Log.
final class LogFormatTests: XCTestCase {

    private func level(_ line: String) -> LogFormat.Level? {
        LogFormat.level(of: Array(line.utf8))
    }

    func testRecognisesCommonLevels() {
        XCTAssertEqual(level("2026-08-23 19:12:06 [app] ERROR không mở được file"), .error)
        XCTAssertEqual(level("INFO khởi động xong"), .info)
        XCTAssertEqual(level("2026-08-23T19:12:06Z WARN đĩa gần đầy"), .warning)
        XCTAssertEqual(level("[FATAL] hết bộ nhớ"), .critical)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(level("error: hỏng"), .error)
        XCTAssertEqual(level("Warning: chú ý"), .warning)
    }

    /// Chỉ khớp ở BIÊN TỪ. `terror` không phải một dòng lỗi.
    func testDoesNotMatchInsideWords() {
        XCTAssertNil(level("terrorism là một chủ đề"))
        XCTAssertNil(level("winfo là tên biến"))
        XCTAssertNil(level("infoDictionary trả về nil"))
    }

    /// Nhưng dấu gạch dưới và ngoặc vẫn là biên: `[ERROR]` và `NO_ERROR` đều phải nhận ra.
    func testNonLetterBoundariesCount() {
        XCTAssertEqual(level("[ERROR] hỏng"), .error)
        XCTAssertEqual(level("code=NO_ERROR"), .error)
    }

    /// `ERROR` phải xét TRƯỚC `ERR`, không thì từ dài hơn không bao giờ khớp.
    func testLongerKeywordWins() {
        XCTAssertEqual(level("WARNING chú ý"), .warning)
        XCTAssertEqual(level("CRITICAL hỏng nặng"), .critical)
    }

    /// Không nhận ra thì trả `nil`, KHÔNG đoán: một dòng tiếp nối của stack trace không có mức
    /// riêng, và gán bừa mức của dòng trước sẽ làm phép lọc trả về những dòng không ai hỏi.
    func testUnknownLineHasNoLevel() {
        XCTAssertNil(level("    at com.example.Foo.bar(Foo.java:42)"))
        XCTAssertNil(level(""))
        XCTAssertNil(level("một dòng tiếng Việt bình thường"))
    }

    /// Chỉ soi phần ĐẦU dòng: một dòng dài nhắc tới "error" ở cuối không phải dòng lỗi, và
    /// nhận nhầm sẽ làm một file log bình thường đỏ rực.
    func testOnlyProbesTheStartOfTheLine() {
        let long = String(repeating: "x", count: LogFormat.probeLimit + 10) + " ERROR"
        XCTAssertNil(level(long))
    }

    func testSeverityOrdering() {
        XCTAssertLessThan(LogFormat.Level.debug, LogFormat.Level.error)
        XCTAssertLessThan(LogFormat.Level.warning, LogFormat.Level.critical)
        XCTAssertEqual(LogFormat.Level.allCases.count, 7)
    }

    func testLevelsAcrossBuffer() {
        let buffer = TextBuffer(text: "INFO một\nkhông rõ\nERROR hai\n")
        let levels = LogFormat.levels(in: buffer, lineRange: 0 ... 2)
        XCTAssertEqual(levels[0], .info)
        XCTAssertNil(levels[1])
        XCTAssertEqual(levels[2], .error)
    }

    // MARK: - Tự nhận ra file log

    func testRecognisesRealLog() {
        let text = (0 ..< 50).map { "2026-08-23 19:12:0\($0 % 10) INFO dòng \($0)" }
            .joined(separator: "\n") + "\n"
        XCTAssertTrue(LogFormat.looksLikeLog(TextBuffer(text: text)))
    }

    /// Một file mã nguồn có vài chuỗi `"ERROR"` KHÔNG phải log — nhận nhầm thì cả file bị tô
    /// theo mức và người dùng không hiểu chuyện gì đang xảy ra.
    func testSourceFileWithFewErrorStringsIsNotALog() {
        var text = ""
        for index in 0 ..< 100 {
            text += index % 20 == 0 ? "print(\"ERROR: \\(x)\")\n" : "let bien\(index) = \(index)\n"
        }
        XCTAssertFalse(LogFormat.looksLikeLog(TextBuffer(text: text)))
    }

    func testShortFileIsNeverALog() {
        XCTAssertFalse(LogFormat.looksLikeLog(TextBuffer(text: "ERROR một\nERROR hai\n")))
    }
}
