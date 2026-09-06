import AppKit
import GEditorCore

/// Ứng viên 4: **`NSTextView` chỉ giữ một CỬA SỔ nội dung**, tài liệu nằm trong piece table.
///
/// Sinh ra sau khi ứng viên 3 chết (ADR-01 §6.1): `NSTextContentManager` tùy biến không được
/// TextKit 2 lái. Nhưng thứ giết ứng viên 3 là CƠ CHẾ, không phải TextKit 2 — nên câu hỏi còn
/// lại là: giữ `NSTextView` (tức là giữ `NSTextInputClient` và IME miễn phí) mà chỉ nạp phần
/// đang xem thì có đủ không.
///
/// Đánh đổi phải nói rõ: `NSTextView` chỉ thấy cửa sổ, nên MỌI thứ tính trên cả tài liệu —
/// tìm kiếm, thay thế, số dòng, nhảy tới dòng — phải do lõi GEditor làm. Điều đó vốn đã đúng
/// với kiến trúc hiện tại (lõi độc lập UI, NFR-MNT-01), nên không phải chi phí mới.
final class PagedTextKitEngine: DisplayEngine {

    /// Cửa sổ 2 MB quanh chỗ đang xem. Đủ để cuộn vài màn hình mà không phải nạp lại, và nhỏ
    /// hơn hai bậc so với trần bộ nhớ ở mọi cỡ file.
    static let windowBytes = 2 << 20

    let name = "TextKit 2 · cửa sổ 2 MB trên piece table"
    private let scrollView = NSScrollView()
    private let textView: CountingTextView
    private var buffer = TextBuffer(text: "")
    /// Khoảng byte của tài liệu mà `textView` đang giữ.
    private var window: Range<Int> = 0 ..< 0
    private var caret = 0
    private var paints = 0
    private(set) var repaginations = 0
    private(set) var repaginationMilliseconds: [Double] = []

    init() {
        textView = CountingTextView.makeTextKit2View(in: scrollView)
    }

    var view: NSView { scrollView }

    func load(_ bytes: [UInt8]) throws {
        let path = NSTemporaryDirectory() + "geditor-poca-paged-\(getpid()).txt"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        defer { unlink(path) }

        let document = try Document.open(path: path, encoding: .utf8)
        buffer = document.buffer
        guard buffer.count == bytes.count else {
            throw EngineError.refused("chỉ nạp \(buffer.count)/\(bytes.count) byte")
        }
        page(around: 0)
    }

    /// Nạp cửa sổ quanh offset, cắt theo BIÊN DÒNG.
    ///
    /// Cắt giữa dòng thì dòng đầu và cuối của cửa sổ hiện thiếu, và cắt giữa một ký tự nhiều
    /// byte thì hiện ra ký tự thay thế — với tiếng Việt là gặp ngay chứ không phải hiếm.
    private func page(around offset: Int) {
        // Tìm biên bằng MỘT lần tra chỉ mục dòng, không dò ngược từng dòng.
        //
        // Bản đầu dò ngược từng dòng một và "nhảy tới cuối file" mất 1,95 s trên 500 MB. Đó là
        // lỗi của vòng lặp này chứ không phải của TextKit — nhưng nếu không sửa thì nó sẽ nằm
        // trong bảng kết quả với tư cách một kết luận về TextKit.
        let half = Self.windowBytes / 2
        let center = Swift.min(Swift.max(offset, 0), Swift.max(buffer.count - 1, 0))
        let startLine = buffer.lineNumber(atOffset: Swift.max(0, center - half))
        let start = buffer.offset(ofLineStart: startLine)
        let end = Swift.min(buffer.count, start + Self.windowBytes)

        let started = DispatchTime.now().uptimeNanoseconds
        window = start ..< end
        textView.string = String(decoding: buffer.bytes(in: window), as: UTF8.self)
        repaginations += 1
        repaginationMilliseconds.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
    }

    func beginTyping(atLine line: Int) {
        let offset = buffer.offset(ofLineStart: Swift.min(Swift.max(line, 0), buffer.lineCount - 1))
        if !window.contains(offset) { page(around: offset) }
        caret = offset
        textView.setSelectedRange(NSRange(location: utf16Offset(ofDocumentOffset: offset), length: 0))
    }

    func typeOneCharacter(_ text: String) {
        // Sửa vào NGUỒN SỰ THẬT trước, rồi phản chiếu vào cửa sổ. Ngược lại là để view thành
        // nguồn sự thật thứ hai, và hai nguồn thì sớm muộn cũng lệch.
        buffer.replace(caret ..< caret, with: text, label: "gõ")
        window = window.lowerBound ..< (window.upperBound + text.utf8.count)
        let location = utf16Offset(ofDocumentOffset: caret)
        textView.textStorage?.replaceCharacters(in: NSRange(location: location, length: 0), with: text)
        caret += text.utf8.count
        textView.setSelectedRange(NSRange(location: location + text.utf16.count, length: 0))
    }

    /// Offset byte trong tài liệu → offset UTF-16 trong cửa sổ.
    ///
    /// Chỉ quét trong phạm vi CỬA SỔ (2 MB), không quét cả tài liệu — đây chính là chỗ mà
    /// bản dựng TextKit 2 đầu tiên của tôi sai và làm phép đo nói về hàm đổi chỉ số.
    private func utf16Offset(ofDocumentOffset offset: Int) -> Int {
        let clamped = Swift.min(Swift.max(offset, window.lowerBound), window.upperBound)
        let prefix = buffer.bytes(in: window.lowerBound ..< clamped)
        return String(decoding: prefix, as: UTF8.self).utf16.count
    }

    func forceDisplay() {
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        textView.display()
    }

    func setCarets(_ positions: [Int]) -> Bool { false }
    func selectRectangle(fromLine: Int, toLine: Int, column: Int) -> Bool { false }

    func scrollToLine(_ line: Int) {
        let offset = buffer.offset(ofLineStart: Swift.min(Swift.max(line, 0), buffer.lineCount - 1))
        if !window.contains(offset) { page(around: offset) }
        textView.scrollRangeToVisible(NSRange(location: utf16Offset(ofDocumentOffset: offset), length: 0))
    }

    func takePaintCount() -> Int {
        let count = textView.paintCount
        textView.paintCount = 0
        return count
    }

    var viewportDescription: String {
        let visible = scrollView.contentView.bounds
        let average = repaginationMilliseconds.isEmpty ? 0
            : repaginationMilliseconds.reduce(0, +) / Double(repaginationMilliseconds.count)
        return String(format: "%.0f×%.0f pt · cửa sổ %.1f MB · nạp lại cửa sổ %d lần, tb %.1f ms",
                      visible.width, visible.height,
                      Double(window.count) / 1_048_576, repaginations, average)
    }

    var documentLength: Int { buffer.count }
    var lineCount: Int { buffer.lineCount }
    var nativeLength: Int { buffer.count }
    var caretPosition: Int { caret }
    var countsBytes: Bool { true }

    /// Bộ gõ vẫn nói chuyện với `NSTextView` như thường — đó chính là điểm mạnh của hướng này.
    /// Khi làm thật, thay đổi từ view phải được phản chiếu ngược vào piece table qua delegate.
    var inputClient: NSTextInputClient? { textView }
    func documentText() -> String { textView.string }

    func placeCaret(after prefix: String) {
        textView.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
    }

    func resetDocument() {
        buffer = TextBuffer(text: "")
        window = 0 ..< 0
        caret = 0
        textView.string = ""
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.window?.makeFirstResponder(textView)
    }
}
