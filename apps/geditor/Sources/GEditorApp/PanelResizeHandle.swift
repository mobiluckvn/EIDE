import AppKit

/// Thanh kéo ở MÉP TRÊN của một panel, để người dùng tự chọn nó cao bao nhiêu.
///
/// # Vì sao cần
///
/// Mười bốn panel của GEditor có chiều cao viết cứng trong mã: 160 pt cho bảng lỗi CSV, 220 pt
/// cho kết quả SQL, 340 pt cho dự báo. Những con số ấy được chọn khi nhìn một cửa sổ cỡ trung,
/// và chúng không đổi theo bất cứ thứ gì — không theo màn hình, không theo số dòng kết quả,
/// không theo ý người dùng.
///
/// Hậu quả trên màn hình lớn đúng như anh mô tả: bảng kết quả có ba trăm dòng thì đứng trong
/// một khe 220 pt, còn vùng soạn thảo phía trên — đang trống — chiếm một nghìn một trăm. Phần
/// nhiều thông tin thì bé, phần không có gì thì rộng.
///
/// # Vì sao là thanh kéo chứ không phải `NSSplitView`
///
/// Cột dọc của cửa sổ do `rebuildColumn()` dựng bằng ràng buộc, và nó có tới mười chín tầng
/// vào ra tuỳ lúc. Chuyển sang `NSSplitView` là viết lại toàn bộ chỗ ấy cùng mọi bài kiểm bám
/// theo nó, để đổi lấy đúng một tính năng: kéo được. Thanh kéo này sửa duy nhất hằng số chiều
/// cao — cùng biến mà mã hiện tại đã dùng — nên phần còn lại của bố cục không đổi một dòng.
final class PanelResizeHandle: NSView {

    /// Chênh lệch chiều cao mỗi nhịp kéo. Dương = panel cao lên.
    var onDrag: ((CGFloat) -> Void)?
    /// Người dùng thả chuột — chỗ gọi ghi lại lựa chọn.
    var onFinish: (() -> Void)?

    static let thickness: CGFloat = 6

    private var lastY: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    /// Con trỏ đổi thành mũi tên hai chiều khi rê tới.
    ///
    /// Không có nó thì thanh kéo vô hình với người dùng: nó chỉ dày 6 pt và không có nhãn, nên
    /// con trỏ là thứ DUY NHẤT nói rằng chỗ này kéo được.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Một vạch mảnh giữa thanh, đủ để mắt nhận ra đây là mép chia — cùng lối các trình
        // soạn thảo khác dùng, và nhạt hơn đường kẻ phân cách thường để không hút mắt.
        Tokens.Color.separator.setFill()
        let line = NSRect(x: bounds.midX - 14, y: bounds.midY - 1, width: 28, height: 2)
        NSBezierPath(roundedRect: line, xRadius: 1, yRadius: 1).fill()
    }

    override func mouseDown(with event: NSEvent) {
        lastY = event.locationInWindow.y
    }

    override func mouseDragged(with event: NSEvent) {
        let now = event.locationInWindow.y
        // Toạ độ cửa sổ có y TĂNG khi đi lên, và panel nằm ở đáy cột — nên kéo thanh này lên
        // là panel cao thêm. Dấu ở đây mà ngược thì panel co lại khi người dùng kéo giãn, và
        // đó là kiểu hỏng người ta bỏ cuộc sau một lần thử chứ không báo lại.
        onDrag?(now - lastY)
        lastY = now
    }

    override func mouseUp(with event: NSEvent) {
        onFinish?()
    }

    /// Kéo một quãng, dùng cho bài tự kiểm.
    ///
    /// **Dựng sự kiện chuột THẬT rồi gọi `mouseDown`/`mouseDragged`/`mouseUp`**, chứ không gọi
    /// thẳng `onDrag?(delta)`.
    ///
    /// Khác biệt ấy không phải hình thức, và tôi biết vì đã viết bản gọi thẳng trước. Phép trừ
    /// quyết định CHIỀU kéo nằm trong `mouseDragged`; một bản kiểm gọi thẳng `onDrag` đi vòng
    /// qua đúng dòng ấy. Thử đảo dấu để xem bài kiểm có đỏ không — nó vẫn xanh. Tức là bài
    /// kiểm nói nó canh chiều kéo, mà không canh gì cả.
    func dragForSelfTest(by delta: CGFloat) {
        guard let window else {
            onDrag?(delta)
            onFinish?()
            return
        }
        func mouse(_ type: NSEvent.EventType, _ y: CGFloat) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type, location: NSPoint(x: 10, y: y), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1
            )
        }
        // Mốc bắt đầu tuỳ ý — chỉ HIỆU giữa hai điểm mới có nghĩa.
        let start: CGFloat = 400
        if let down = mouse(.leftMouseDown, start) { mouseDown(with: down) }
        if let drag = mouse(.leftMouseDragged, start + delta) { mouseDragged(with: drag) }
        if let up = mouse(.leftMouseUp, start + delta) { mouseUp(with: up) }
    }
}
