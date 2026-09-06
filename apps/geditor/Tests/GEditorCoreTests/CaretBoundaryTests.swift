import XCTest
@testable import GEditorCore

/// Vị trí con trỏ ở BIÊN cuối tài liệu (FR-CORE-018).
///
/// Caret đứng SAU ký tự cuối cùng là trạng thái hoàn toàn bình thường — bấm Cmd+A rồi mũi tên
/// phải là ra ngay. Offset khi ấy bằng ĐÚNG `buffer.count`, tức trỏ vào chỗ chưa có byte nào.
final class CaretBoundaryTests: XCTestCase {

    /// Tài liệu kết thúc bằng newline: con trỏ ở cuối đứng đầu dòng RỖNG tiếp theo —
    /// "Dòng 3, Cột 1" đúng như mọi trình soạn thảo khác hiện.
    func testPositionAtEndOfDocumentEndingWithNewline() {
        let buffer = TextBuffer(text: "mot\nhai\n")
        let position = buffer.position(atOffset: buffer.count)
        XCTAssertEqual(position.line, 2, "dòng rỗng sau newline cuối")
        XCTAssertEqual(position.byteColumn, 0)
    }

    func testPositionAtEndOfDocumentWithoutTrailingNewline() {
        let buffer = TextBuffer(text: "mot\nhai")
        let position = buffer.position(atOffset: buffer.count)
        XCTAssertEqual(position.line, 1)
        XCTAssertEqual(position.byteColumn, 3)
    }

    func testPositionAtEndOfEmptyDocument() {
        let buffer = TextBuffer(text: "")
        let position = buffer.position(atOffset: 0)
        XCTAssertEqual(position.line, 0)
        XCTAssertEqual(position.byteColumn, 0)
    }

    /// Cặp `lineNumber` → `offset(ofLineStart:)` phải đi lọt ở MỌI offset của MỌI tài liệu.
    /// Đây chính là cặp đã làm app chết.
    func testLineLookupPairSurvivesEveryOffset() {
        for text in ["mot\nhai\n", "mot\nhai", "", "\n", "\n\n\n", "một\nhai\n", "a\r\nb\r\n"] {
            let buffer = TextBuffer(text: text)
            for offset in 0 ... buffer.count {
                let line = buffer.lineNumber(atOffset: offset)
                let start = buffer.offset(ofLineStart: line)
                XCTAssertLessThanOrEqual(start, offset, String(reflecting: text))
                _ = buffer.position(atOffset: offset)
            }
        }
    }

    /// `offset(ofLineStart:)` phải chịu được chính con số mà `lineNumber` trả về — hai hàm này
    /// luôn đi cặp với nhau trong `position(atOffset:)`.
    func testLineStartOfVirtualLastLineIsEndOfBuffer() {
        let buffer = TextBuffer(text: "mot\nhai\n")
        XCTAssertEqual(buffer.offset(ofLineStart: buffer.lineCount), buffer.count)
    }
}
