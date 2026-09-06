import AppKit
import GEditorCore

/// Ứng viên 3, do PoC-A đẻ ra: **TextKit 2 vẽ trực tiếp từ piece table** (ADR-01 §4).
///
/// Hai ứng viên SAD giao đều tự giữ tài liệu và đều vượt trần bộ nhớ (ADR-01 §3.2). Ứng viên
/// này trả lời câu hỏi thật: TextKit 2 có chịu được việc KHÔNG giữ tài liệu không.
final class LazyTextKitEngine: DisplayEngine {

    let name = "TextKit 2 trên piece table"
    private let scrollView = NSScrollView()
    private var textView: LazyTextView?
    private var buffer = TextBuffer(text: "")
    private var caret = 0

    var view: NSView { scrollView }

    func load(_ bytes: [UInt8]) throws {
        // Ghi ra đĩa rồi mở bằng mmap, đúng đường mà sản phẩm đi. Nạp từ mảng trong RAM sẽ
        // giấu mất chính thứ hướng này định chứng minh: nội dung KHÔNG nằm trong bộ nhớ ứng
        // dụng, nó nằm trong file và hệ điều hành quản trang.
        let path = NSTemporaryDirectory() + "geditor-poca-\(getpid()).txt"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        defer { unlink(path) }

        // ÉP UTF-8, không để tự nhận diện: PoC này đo engine hiển thị, và nội dung thử là
        // UTF-8 đã biết chắc. (Để tự nhận diện thì bộ dò đoán nhầm sang bảng mã một byte và
        // buffer phình từ 1.048.591 lên 1.651.962 byte — xem docs/adr/ADR-01 §6.)
        let document = try Document.open(path: path, encoding: .utf8)
        buffer = document.buffer
        guard buffer.count == bytes.count else {
            throw EngineError.refused("chỉ nạp \(buffer.count)/\(bytes.count) byte")
        }

        let view = LazyTextView(buffer: buffer, font: .monospacedSystemFont(ofSize: 12, weight: .regular))
        view.frame = NSRect(x: 0, y: 0, width: 2_000,
                            height: CGFloat(buffer.lineCount) * view.lineHeight)
        textView = view
        scrollView.documentView = view
        scrollView.hasVerticalScroller = true
    }

    func beginTyping(atLine line: Int) {
        caret = buffer.offset(ofLineStart: Swift.min(Swift.max(line, 0), buffer.lineCount - 1))
        textView?.scrollToLine(line)
    }

    func typeOneCharacter(_ text: String) {
        textView?.replace(caret ..< caret, with: text)
        caret += text.utf8.count
    }

    func forceDisplay() {
        textView?.displayIfNeeded()
    }

    /// Multi-caret và column mode: **chưa làm trong PoC này**, không phải "không làm được".
    ///
    /// Khác hẳn TextKit 2 qua `NSTextView`, ở đây vùng chọn là của GEditor chứ không của
    /// AppKit, nên không có rào chắn kỹ thuật nào — chỉ là công việc chưa viết. Báo cáo phải
    /// phân biệt hai chuyện đó, nếu không thì bảng so sánh sẽ nói dối.
    func setCarets(_ positions: [Int]) -> Bool { false }
    func selectRectangle(fromLine: Int, toLine: Int, column: Int) -> Bool { false }

    func scrollToLine(_ line: Int) { textView?.scrollToLine(line) }

    func takePaintCount() -> Int { textView?.takePaintCount() ?? 0 }

    var viewportDescription: String {
        guard let textView else { return "chưa nạp" }
        let visible = scrollView.contentView.bounds
        return String(format: "%.0f×%.0f pt, ~%.0f dòng hiện, %d đoạn đã dựng bố cục · %@",
                      visible.width, visible.height, visible.height / textView.lineHeight,
                      textView.takeFragmentCount(), textView.contentManagerActivity)
    }

    var documentLength: Int { buffer.count }
    var lineCount: Int { buffer.lineCount }
    var nativeLength: Int { buffer.count }
    var caretPosition: Int { caret }
    var countsBytes: Bool { true }

    /// Không có `NSTextView` nên không có `NSTextInputClient` nào sẵn — muốn dùng hướng này
    /// thì phải TỰ hiện thực giao thức bộ gõ. Với NFR-USE-02 đó là rủi ro lớn, và là một lý
    /// do nữa để không chọn nó (ứng viên này đã chết vì lý do khác, xem ADR-01 §6).
    var inputClient: NSTextInputClient? { nil }
    func documentText() -> String { String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self) }
    func resetDocument() { try? load([]) }
    func placeCaret(after prefix: String) { caret = prefix.utf8.count }
}
