import AppKit
import GEditorCore

/// View vẽ bằng TextKit 2 nhưng **không dùng `NSTextView`**, nội dung lấy từ piece table.
///
/// Vì sao không dùng `NSTextView`: nó gắn chặt với `NSTextContentStorage` (nó có hẳn thuộc
/// tính `textContentStorage` kiểu ấy), tức là gắn chặt với việc giữ cả tài liệu trong
/// `NSTextStorage` — đúng thứ mà bảng §3.2 của ADR-01 nói là vượt trần bộ nhớ. Dùng thẳng
/// `NSTextLayoutManager` là đường TextKit 2 để mở cho trường hợp này.
///
/// Cái mất, và phải nói rõ vì nó đắt: bỏ `NSTextView` là bỏ luôn `NSTextInputClient` có sẵn,
/// tức là **IME tiếng Việt phải tự làm**. NFR-USE-02 chặn phát hành, nên đây là rủi ro lớn
/// nhất của hướng này chứ không phải bộ nhớ hay tốc độ.
///
/// Giả định của PoC: **chiều cao dòng đều nhau và không ngắt dòng mềm**. Nó cho phép quy đổi
/// thẳng vị trí cuộn ↔ số dòng mà không cần dựng bố cục cả tài liệu. Trình soạn thảo thật với
/// word wrap phải làm khác (ước lượng rồi chỉnh dần); đó là việc của bước sau, không phải của
/// câu hỏi PoC này.
final class LazyTextView: NSView, NSTextViewportLayoutControllerDelegate {

    let buffer: TextBuffer
    let contentManager: PieceTableContentManager
    private let layoutManager = NSTextLayoutManager()
    private let font: NSFont
    let lineHeight: CGFloat

    private var appleStorage: NSTextContentStorage?
    private(set) var paintCount = 0
    private(set) var laidOutFragments = 0

    init(buffer: TextBuffer, font: NSFont) {
        self.buffer = buffer
        self.font = font
        self.lineHeight = (font.ascender - font.descender + font.leading).rounded(.up)
        self.contentManager = PieceTableContentManager(buffer: buffer, font: font)
        super.init(frame: .zero)

        // CHẨN ĐOÁN: dùng NSTextContentStorage của Apple với cùng mã vẽ. Nếu bản này hiện chữ
        // mà bản piece table không, thì lỗi nằm ở content manager chứ không ở phần vẽ.
        if ProcessInfo.processInfo.environment["GEDITOR_POCA_APPLE_STORAGE"] != nil {
            let storage = NSTextContentStorage()
            storage.textStorage?.setAttributedString(NSAttributedString(
                string: String(decoding: buffer.bytes(in: 0 ..< buffer.count), as: UTF8.self),
                attributes: [.font: font, .foregroundColor: NSColor.textColor]
            ))
            let container = NSTextContainer(size: NSSize(width: 4_000, height: 0))
            layoutManager.textContainer = container
            storage.addTextLayoutManager(layoutManager)
            layoutManager.textViewportLayoutController.delegate = self
            appleStorage = storage
            return
        }

        // Bề rộng HỮU HẠN, chiều cao 0 = không giới hạn (quy ước của TextKit). Bản đầu đặt
        // cả hai bằng greatestFiniteMagnitude và TextKit nhận đúng một đoạn rồi thôi.
        let container = NSTextContainer(size: NSSize(width: 4_000, height: 0))
        container.lineBreakMode = .byClipping
        container.maximumNumberOfLines = 0
        layoutManager.textContainer = container
        contentManager.addTextLayoutManager(layoutManager)
        layoutManager.textViewportLayoutController.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    /// Chiều cao ước lượng từ SỐ DÒNG, không phải từ bố cục.
    ///
    /// Đây là điểm mấu chốt của cả hướng này: biết chiều cao tài liệu mà không phải dựng bố
    /// cục cho nó. Với 7,3 triệu dòng, dựng bố cục hết chỉ để biết chiều cao thanh cuộn là
    /// đúng cái làm mọi trình soạn thảo chết ở file lớn.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: CGFloat(buffer.lineCount) * lineHeight)
    }

    func documentDidChange() {
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        paintCount += 1
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        // Đi qua `NSTextViewportLayoutController` — đúng kiến trúc TextKit 2 cho khung nhìn.
        // Tự duyệt fragment theo vị trí của mình thì phải TỰ TAY đưa `NSTextLocation` vào
        // TextKit, và đó là chỗ nó nổ: xem ADR-01 §6.1.
        drawingContext = context
        layoutManager.textViewportLayoutController.layoutViewport()
        drawingContext = nil
    }

    private var drawingContext: CGContext?

    // MARK: - NSTextViewportLayoutControllerDelegate

    private(set) var viewportQueries: [String] = []

    func viewportBounds(for controller: NSTextViewportLayoutController) -> CGRect {
        // Vùng đang hiện, nới thêm một màn hình mỗi phía để cuộn không thấy khoảng trắng.
        let bounds = visibleRect.insetBy(dx: 0, dy: -visibleRect.height)
        if viewportQueries.count < 3 {
            viewportQueries.append(String(format: "(%.0f,%.0f %.0f×%.0f)",
                                          bounds.minX, bounds.minY, bounds.width, bounds.height))
        }
        return bounds
    }

    func textViewportLayoutController(
        _ controller: NSTextViewportLayoutController,
        configureRenderingSurfaceFor fragment: NSTextLayoutFragment
    ) {
        laidOutFragments += 1
        guard let drawingContext else { return }
        fragment.draw(at: fragment.layoutFragmentFrame.origin, in: drawingContext)
    }

    func takePaintCount() -> Int {
        let count = paintCount
        paintCount = 0
        return count
    }

    var contentManagerActivity: String {
        "TextKit hỏi nội dung \(contentManager.enumerationCalls) lần, "
        + "nhận \(contentManager.elementsHandedOut) đoạn"
        + " · viewportBounds \(viewportQueries.count) lần \(viewportQueries.joined())"
        + " · frame \(Int(frame.width))×\(Int(frame.height))"
    }

    func takeFragmentCount() -> Int {
        let count = laidOutFragments
        laidOutFragments = 0
        return count
    }

    /// Sửa nội dung qua `TextBuffer` rồi báo cho TextKit bỏ bố cục cũ của khoảng đó.
    func replace(_ range: Range<Int>, with text: String) {
        contentManager.performEditingTransaction {
            buffer.replace(range, with: text, label: "gõ")
            contentManager.noteEdit(oldRange: range, newLength: text.utf8.count)
        }
        // Chỉ vẽ lại dòng bị đụng, không vẽ lại cả view: chi phí một lần gõ phải tỉ lệ với
        // phần thay đổi, không tỉ lệ với cỡ tài liệu.
        let line = buffer.lineNumber(atOffset: range.lowerBound)
        setNeedsDisplay(NSRect(x: 0, y: CGFloat(line) * lineHeight,
                               width: bounds.width, height: lineHeight * 2))
    }

    func scrollToLine(_ line: Int) {
        let y = CGFloat(line) * lineHeight
        scrollToVisible(NSRect(x: 0, y: y, width: 1, height: lineHeight))
    }
}
