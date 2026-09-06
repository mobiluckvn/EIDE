import AppKit
import GEditorCore

/// Bản đồ tài liệu — dải hẹp bên phải vùng soạn thảo (FR-DOC-306).
///
/// Ba thứ vẽ chồng lên nhau, theo đúng thứ tự:
///
/// 1. **Hình dáng tài liệu** — mỗi hàng một vệt mực, thụt vào theo thụt lề. Đây là thứ làm bản
///    đồ nhận ra được: một hàm dài trông khác một khối dữ liệu phẳng.
/// 2. **Dòng đã đánh dấu** (FR-SRCH-107) — cùng bảng màu với dấu trong vùng soạn thảo, nếu
///    không thì hai chỗ nói về cùng một thứ bằng hai ngôn ngữ khác nhau.
/// 3. **Khung tầm nhìn** — phần đang hiện trên màn hình.
///
/// **Bấm là nhảy, kéo là cuộn.** Không có chế độ "xem trước khi nhả chuột": với file lớn, mỗi
/// lần nhảy là một lần nạp lại cửa sổ, và làm việc ấy theo từng điểm ảnh chuột đi qua sẽ biến
/// một cú kéo thành hàng trăm lần nạp.
final class DocumentMapView: NSView {

    /// Bề rộng cố định. Đủ để thấy hình dáng, đủ hẹp để không ăn chỗ của chữ.
    static let width: CGFloat = 92

    /// Người dùng chọn một dòng trên bản đồ.
    var onSelectLine: ((Int) -> Void)?

    /// Bề cao đã đổi. Số hàng bản đồ tính theo bề cao, nên đổi bề cao là bản đồ cũ hết đúng.
    ///
    /// Phải là view tự báo chứ không phải chỗ gọi tự đoán: chỗ gọi không biết bố cục chạy lúc
    /// nào. Bật bản đồ lên rồi dựng ngay tại đó thì bố cục chưa áp, `bounds.height` bằng 0, và
    /// bản đồ ra đúng MỘT hàng — một vệt mực cao hết view, trông y hệt một cột xám đều.
    var onHeightChanged: (() -> Void)?

    /// Số hàng bản đồ nên có ở bề cao hiện tại: một hàng cho mỗi điểm dọc.
    var desiredRowCount: Int { max(1, Int(bounds.height)) }

    private var map: DocumentMap?
    private var visibleLines: Range<Int> = 0 ..< 0
    private var markedLines: [Int: Int] = [:]

    override var isFlipped: Bool { true }

    // MARK: - VoiceOver (NFR-USE-03)
    //
    // View TỰ VẼ thì hoàn toàn vô hình với VoiceOver: AppKit chỉ suy được nhãn từ những điều
    // khiển chuẩn có `title`. Không khai ở đây thì người dùng VoiceOver gặp một vùng câm giữa
    // cửa sổ, không biết nó là gì và cũng không biết bấm vào thì xảy ra chuyện gì.

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .slider }

    override func accessibilityLabel() -> String? { "Bản đồ tài liệu" }

    override func accessibilityValue() -> Any? {
        guard let map, !map.isEmpty else { return "trống" }
        guard !visibleLines.isEmpty else { return "\(map.lineCount) dòng" }
        return "đang xem dòng \(visibleLines.lowerBound + 1) đến \(visibleLines.upperBound)"
            + " trên \(map.lineCount)"
    }

    override func accessibilityHelp() -> String? {
        "Bấm hoặc kéo để nhảy tới một vùng của tài liệu"
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)
    }

    required init?(coder: NSCoder) { nil }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }


    // MARK: - Nạp

    /// Đặt bản đồ mới. Chỗ gọi chịu trách nhiệm chỉ dựng lại khi tài liệu ĐỔI — dựng lại theo
    /// từng nhịp cuộn tốn 5–10 ms mỗi khung hình cho một thứ không hề thay đổi.
    func present(_ map: DocumentMap) {
        self.map = map
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize.height != frame.height
        super.setFrameSize(newSize)
        if changed { onHeightChanged?() }
    }

    /// Cập nhật khung tầm nhìn. Rẻ: không đụng tới bản đồ.
    func setVisibleLines(_ range: Range<Int>) {
        guard range != visibleLines else { return }
        visibleLines = range
        needsDisplay = true
    }

    /// Dòng nào đang được đánh dấu, và bằng màu nào.
    func setMarkedLines(_ marks: [Int: Int]) {
        guard marks != markedLines else { return }
        markedLines = marks
        needsDisplay = true
    }

    // MARK: - Vẽ

    override func draw(_ dirtyRect: NSRect) {
        lastDrawBounds = bounds
        lastDrawInkRects = []
        guard let map, !map.isEmpty, bounds.height > 0 else { return }

        let rowHeight = bounds.height / CGFloat(map.rows.count)
        let inset: CGFloat = 4
        let usable = bounds.width - inset * 2

        // Nét mực mảnh nhưng KHÔNG mảnh hơn một điểm ảnh vật lý: dưới ngưỡng ấy macOS làm mờ
        // nó đi và bản đồ của một file dài trông như trống trơn.
        let inkHeight = max(rowHeight - 0.5, 1 / (window?.backingScaleFactor ?? 2))

        Tokens.Color.editorInk.withAlphaComponent(0.55).setFill()
        for (index, row) in map.rows.enumerated() where !row.isBlank {
            let y = CGFloat(index) * rowHeight
            guard y + rowHeight >= dirtyRect.minY, y <= dirtyRect.maxY else { continue }
            let x = inset + CGFloat(row.inkStart) * usable
            let width = max(CGFloat(row.inkEnd - row.inkStart) * usable, 1)
            let rect = NSRect(x: x, y: y, width: width, height: inkHeight)
            rect.fill()
            if lastDrawInkRects.count < 24 { lastDrawInkRects.append(rect) }
        }

        drawMarks(map: map, rowHeight: rowHeight)
        drawViewport(map: map)
    }

    private func drawMarks(map: DocumentMap, rowHeight: CGFloat) {
        guard !markedLines.isEmpty else { return }
        let palette = Tokens.Color.markColors
        for (line, color) in markedLines {
            let index = map.row(forLine: line)
            let y = CGFloat(index) * rowHeight
            palette[min(max(color, 0), palette.count - 1)].setFill()
            // Dấu vẽ TRÀN cả bề ngang và cao tối thiểu 2 điểm ảnh: một dòng đã đánh dấu trong
            // file 3 triệu dòng chiếm chưa tới một phần nghìn điểm ảnh, và mục đích của dấu là
            // để tìm thấy nó.
            NSRect(x: 0, y: y, width: bounds.width, height: max(rowHeight, 2)).fill()
        }
    }

    private func drawViewport(map: DocumentMap) {
        guard !visibleLines.isEmpty else { return }
        let range = map.fractionRange(forLines: visibleLines)
        let top = CGFloat(range.lowerBound) * bounds.height
        let bottom = CGFloat(range.upperBound) * bounds.height
        // Cao tối thiểu 6 điểm ảnh: với file 3 triệu dòng, 40 dòng đang hiện chiếm 0,001% chiều
        // cao — đúng về tỉ lệ và vô hình về mặt sử dụng.
        let rect = NSRect(x: 0, y: top, width: bounds.width, height: max(bottom - top, 6))

        Tokens.Color.selection.withAlphaComponent(0.28).setFill()
        rect.fill()
        Tokens.Color.orange.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    // MARK: - Chuột

    override func mouseDown(with event: NSEvent) { jump(to: event) }
    override func mouseDragged(with event: NSEvent) { jump(to: event) }

    private func jump(to event: NSEvent) {
        guard let map, !map.isEmpty, bounds.height > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        onSelectLine?(map.line(atFraction: Double(point.y / bounds.height)))
    }

    // MARK: - Móc tự kiểm

    /// Hình học của LẦN VẼ GẦN NHẤT, ghi lại ngay trong `draw(_:)`.
    ///
    /// Hỏi `bounds` từ bên ngoài trả lời một câu hỏi khác: nó cho biết bề rộng LÚC HỎI, còn thứ
    /// quyết định ảnh là bề rộng LÚC VẼ. Hai số ấy khác nhau đúng ở loại lỗi đang truy — vẽ
    /// trước khi bố cục áp xong — nên phải đo cái sau.
    private(set) var lastDrawBounds: NSRect = .zero
    private(set) var lastDrawInkRects: [NSRect] = []

    var rowCountForSelfTest: Int { map?.rows.count ?? 0 }
    var mappedLineCountForSelfTest: Int { map?.lineCount ?? 0 }
    var visibleLinesForSelfTest: Range<Int> { visibleLines }
    func clickAtFractionForSelfTest(_ fraction: Double) {
        guard let map else { return }
        onSelectLine?(map.line(atFraction: fraction))
    }
}
