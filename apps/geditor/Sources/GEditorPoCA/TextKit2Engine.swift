import AppKit

/// Ứng viên 2: TextKit 2 (`NSTextView` với `NSTextLayoutManager`), đối chứng của ADR-01.
///
/// Đây là bản dựng CÔNG BẰNG NHẤT có thể cho TextKit 2 mà vẫn là thứ dùng được thật:
/// - `usingTextLayoutManager: true` → TextKit 2, không phải TextKit 1 giả dạng.
/// - `NSTextStorage` giữ nội dung, đúng như mọi ứng dụng AppKit vẫn làm.
///
/// Cái KHÔNG làm ở đây, và phải nói rõ vì nó ảnh hưởng tới kết luận: không viết
/// `NSTextContentManager` tùy biến lấy nội dung lười từ piece table. Về lý thuyết đó là đường
/// cứu TextKit 2 khỏi việc nuốt cả file vào `NSTextStorage`. Nhưng `NSTextContentManager` vẫn
/// đòi `NSTextElement` cho từng đoạn và vẫn đánh chỉ số bằng `NSTextLocation` — chi phí dựng
/// và giữ chỉ số ấy chính là thứ PoC phải đo, nên bản tùy biến sẽ là một PoC riêng chứ không
/// phải một biến thể. ADR-01 ghi lại giới hạn này (§ "Điều chưa đo").
/// `NSTextView` tự đếm số lần vẽ — đối chứng của SCN_PAINTED bên Scintilla.
final class CountingTextView: NSTextView {
    var paintCount = 0

    override func draw(_ dirtyRect: NSRect) {
        paintCount += 1
        super.draw(dirtyRect)
    }

    /// Dựng một `NSTextView` chạy TextKit 2 THẬT, gắn vào scroll view.
    ///
    /// Ở một chỗ dùng chung vì bản sao chép tay cho engine cửa sổ đã bỏ sót phần
    /// `NSTextLayoutManager` và view hiện ra TRẮNG TRƠN — trong khi bộ đếm vẽ vẫn báo
    /// 300/300. Bộ đếm nói "có gọi draw", nó không nói "có chữ trên màn hình".
    static func makeTextKit2View(in scrollView: NSScrollView) -> CountingTextView {
        let textView = CountingTextView(frame: .zero, textContainer: nil)

        let layoutManager = NSTextLayoutManager()
        let contentStorage = NSTextContentStorage()
        contentStorage.addTextLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.textContainer = container
        textView.replaceTextContainer(container)

        textView.isRichText = false
        textView.isEditable = true
        textView.allowsUndo = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        return textView
    }
}

final class TextKit2Engine: DisplayEngine {

    let name = "TextKit 2 (NSTextView)"
    private let scrollView = NSScrollView()
    private let textView: CountingTextView

    /// Vị trí UTF-16 đầu mỗi dòng, dựng MỘT LẦN lúc nạp.
    ///
    /// `NSTextStorage` đánh chỉ số theo UTF-16 còn phép đo nói theo dòng; không có bảng này
    /// thì mỗi lần gõ phải quét lại cả chuỗi. Một trình soạn thảo TextKit 2 thật cũng phải
    /// dựng bảng này — nên chi phí RAM của nó là một PHÁT HIỆN của PoC, không phải gian lận:
    /// nó được báo cáo riêng trong kết quả.
    private var lineStarts: [Int] = []
    private var caret = 0
    private var cachedLength = 0

    init() {
        textView = CountingTextView.makeTextKit2View(in: scrollView)
    }

    var view: NSView { scrollView }

    func load(_ bytes: [UInt8]) throws {
        let text = String(decoding: bytes, as: UTF8.self)
        textView.string = text
        cachedLength = bytes.count
        guard textView.string.utf8.count == bytes.count else {
            throw EngineError.refused("nội dung không vào đủ")
        }

        lineStarts = [0]
        var units = 0
        for scalar in text.unicodeScalars {
            units += UTF16.width(scalar)
            if scalar == "\n" { lineStarts.append(units) }
        }
    }

    /// RAM mà bảng chỉ số dòng chiếm — con số này đi vào báo cáo.
    var lineIndexBytes: Int { lineStarts.count * MemoryLayout<Int>.size }

    func beginTyping(atLine line: Int) {
        caret = lineStarts.indices.contains(line) ? lineStarts[line] : 0
        textView.setSelectedRange(NSRange(location: caret, length: 0))
    }

    func typeOneCharacter(_ text: String) {
        textView.textStorage?.replaceCharacters(in: NSRange(location: caret, length: 0), with: text)
        caret += text.utf16.count
        textView.setSelectedRange(NSRange(location: caret, length: 0))
    }

    func forceDisplay() {
        // `layoutViewport()`, KHÔNG phải `ensureLayout(for: documentRange)`. Cái sau dựng bố
        // cục cả tài liệu — trên 500 MB đó là phép đo không ai chạy hết, và cũng không phải
        // thứ TextKit 2 làm khi người dùng gõ. Bố cục theo viewport là đường mà một trình soạn
        // thảo TextKit 2 thật đi, nên đo nó mới công bằng.
        //
        // Vẫn phải gọi tường minh: bỏ qua thì việc dựng bố cục bị đẩy sang lần vẽ sau và phép
        // đo ghi nhầm nó vào thao tác kế tiếp.
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        textView.display()
    }

    /// TextKit 2 / `NSTextView` chỉ có MỘT vùng chọn và MỘT caret.
    ///
    /// `NSTextView.selectedRanges` nhận nhiều range, nhưng đó là nhiều vùng CHỌN chứ không
    /// phải nhiều caret gõ được: gõ một phím chỉ thay thế vùng chính. FR-CORE-001 đòi gõ đồng
    /// thời, nên đây là "không hỗ trợ" chứ không phải "hỗ trợ một phần".
    func setCarets(_ positions: [Int]) -> Bool { false }

    /// Không có column mode. `NSTextView` không có khái niệm chọn theo khối.
    func selectRectangle(fromLine: Int, toLine: Int, column: Int) -> Bool { false }

    func scrollToLine(_ line: Int) {
        let location = lineStarts.indices.contains(line) ? lineStarts[line] : 0
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
    }

    func takePaintCount() -> Int {
        let count = textView.paintCount
        textView.paintCount = 0
        return count
    }

    var viewportDescription: String {
        let visible = textView.visibleRect
        let lineHeight = textView.font?.boundingRectForFont.height ?? 1
        return String(format: "%.0f×%.0f pt, ~%.0f dòng hiện",
                      textView.bounds.width, visible.height, visible.height / lineHeight)
    }

    var nativeLength: Int { textView.textStorage?.length ?? 0 }
    var caretPosition: Int { caret }
    var countsBytes: Bool { false }

    var inputClient: NSTextInputClient? { textView }
    func documentText() -> String { textView.string }

    func placeCaret(after prefix: String) {
        textView.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
    }

    func resetDocument() {
        textView.string = ""
        lineStarts = [0]
        caret = 0
        cachedLength = 0
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.window?.makeFirstResponder(textView)
    }

    var documentLength: Int { cachedLength }
    var lineCount: Int { lineStarts.count }
}
