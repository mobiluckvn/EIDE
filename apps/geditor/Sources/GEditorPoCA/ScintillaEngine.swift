import AppKit
import ScintillaCocoa

/// Ứng viên 1: Scintilla-Cocoa 5.5.5 (SAD nêu là mặc định của ADR-01).
final class ScintillaEngine: DisplayEngine {

    let name = "Scintilla-Cocoa 5.5.5"
    private let scintilla = GEScintillaView(frame: .zero)
    var view: NSView { scintilla }

    func load(_ bytes: [UInt8]) throws {
        bytes.withUnsafeBytes { scintilla.loadUTF8($0.baseAddress!, length: bytes.count) }
        // Scintilla trả về độ dài nó THẬT SỰ nhận. Không kiểm chỗ này thì một lần nạp thất
        // bại lặng lẽ sẽ biến thành "Scintilla nhanh tuyệt vời" trong kết quả PoC.
        guard scintilla.documentLength == bytes.count else {
            throw EngineError.refused(
                "chỉ nhận \(scintilla.documentLength)/\(bytes.count) byte"
            )
        }
    }

    private var caret = 0

    func beginTyping(atLine line: Int) {
        caret = scintilla.position(ofLine: line)
        scintilla.go(toPosition: caret)
    }

    func typeOneCharacter(_ text: String) {
        scintilla.insertText(text, atPosition: caret)
        caret += text.utf8.count
        scintilla.go(toPosition: caret)
    }

    func forceDisplay() {
        scintilla.display()
    }

    func setCarets(_ positions: [Int]) -> Bool {
        scintilla.setCaretPositions(positions.map(NSNumber.init(value:)))
        return true
    }

    func selectRectangle(fromLine: Int, toLine: Int, column: Int) -> Bool {
        let anchor = positionOfLine(fromLine) + column
        let caret = positionOfLine(toLine) + column
        scintilla.selectRectangle(from: anchor, to: caret)
        return true
    }

    func scrollToLine(_ line: Int) {
        scintilla.scroll(toLine: line)
    }

    func takePaintCount() -> Int { scintilla.takePaintCount() }

    var viewportDescription: String { scintilla.viewportDescription() }

    var nativeLength: Int { scintilla.documentLength }
    var caretPosition: Int { caret }
    var countsBytes: Bool { true }

    var inputClient: NSTextInputClient? { scintilla.inputClient() }
    func documentText() -> String { scintilla.documentText() }

    func placeCaret(after prefix: String) {
        caret = prefix.utf8.count          // Scintilla đếm BYTE
        scintilla.go(toPosition: caret)
    }

    func resetDocument() {
        try? load([])
        caret = 0
        scintilla.go(toPosition: 0)
        scintilla.window?.makeFirstResponder(scintilla.inputClient() as? NSView)
    }

    var documentLength: Int { scintilla.documentLength }
    var lineCount: Int { scintilla.lineCount }

    /// Vị trí byte đầu dòng, hỏi thẳng line index của Scintilla.
    private func positionOfLine(_ line: Int) -> Int {
        scintilla.position(ofLine: line)
    }
}
