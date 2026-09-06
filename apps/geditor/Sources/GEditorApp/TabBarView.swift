import AppKit

/// Thanh tab đa tài liệu (FR-DOC-301).
///
/// Tự vẽ chứ không dùng `NSTabView`: SRS đòi ghim tab, tô màu tab, chấm bẩn, và menu ngữ cảnh
/// Close Others/Left/Right — `NSTabView` không có chỗ cho những thứ đó, và nhồi vào nó tốn công
/// hơn là vẽ một thanh nút.
final class TabBarView: NSView {

    struct Item: Equatable {
        var title: String
        var isModified: Bool
        var isPinned: Bool
        var colorIndex: Int?
        var tooltip: String?
    }

    /// Bảng màu tô tab — lấy từ bảng màu sản phẩm, không bịa màu mới.
    static let colors: [NSColor] = [
        Tokens.Color.orange, Tokens.Color.ember, Tokens.Color.gold,
        NSColor.systemTeal, NSColor.systemPurple,
    ]

    static let height: CGFloat = 30

    /// Chỗ chừa bên trái cho ba nút đèn giao thông của cửa sổ.
    ///
    /// Cửa sổ dùng `.fullSizeContentView` nên nội dung trải cả dưới thanh tiêu đề, và thanh tab
    /// nằm ngay trên cùng — không chừa thì tab đầu tiên nằm DƯỚI ba nút ấy và bấm không được.
    ///
    /// Đã thử neo vào `window.contentLayoutGuide` cho "đúng bài" và cửa sổ không dựng nổi
    /// (0 cửa sổ, không một dòng log). Chừa chỗ bằng một hằng số thì thô hơn nhưng nhìn thấy
    /// được, sửa được, và không làm hỏng cả cửa sổ.
    static let trafficLightInset: CGFloat = 78

    /// Gán lại mà nội dung y hệt thì KHÔNG đụng gì tới giao diện.
    ///
    /// `refreshChrome()` đổ lại cả hai thuộc tính này sau gần như mọi thao tác, và hầu hết
    /// những lần ấy không có gì đổi. Xem `rebuild()` để biết vì sao dựng lại đắt hơn nhiều so
    /// với vẻ ngoài của nó.
    var items: [Item] = [] {
        didSet {
            guard items != oldValue else { return }
            rebuild()
        }
    }
    var activeIndex = 0 {
        didSet {
            guard activeIndex != oldValue else { return }
            rebuild()
        }
    }

    // MARK: - VoiceOver (NFR-USE-03)
    //
    // Thanh tab tự vẽ, nên VoiceOver không thấy gì. Khai thành MỘT phần tử kiểu `tabGroup` với
    // giá trị là tab đang mở: đó là câu người dùng cần nghe khi họ vừa ⌘} sang tab khác. Khai
    // từng tab thành phần tử riêng thì đúng bài hơn nhưng đòi dựng lại cây accessibility mỗi
    // lần rebuild, và bản này chưa cần tới mức ấy.

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .tabGroup }
    override func accessibilityLabel() -> String? { "Thanh tab" }

    override func accessibilityValue() -> Any? {
        guard items.indices.contains(activeIndex) else { return "không có tab nào" }
        let item = items[activeIndex]
        let modified = item.isModified ? ", chưa lưu" : ""
        return "\(item.title)\(modified) — tab \(activeIndex + 1) trên \(items.count)"
    }

    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onContextMenu: ((Int, NSPoint) -> Void)?

    /// Người dùng vừa kéo tab từ vị trí này sang vị trí kia (FR-DOC-301).
    var onReorder: ((Int, Int) -> Void)?
    /// Thả tab RA NGOÀI thanh tab. Điểm tính theo toạ độ MÀN HÌNH (FR-DOC-302).
    ///
    /// Toạ độ màn hình chứ không phải toạ độ cửa sổ, vì đích có thể là một cửa sổ KHÁC — và
    /// toạ độ cửa sổ thì chỉ có nghĩa bên trong cửa sổ đã sinh ra nó.
    var onDropOnScreen: ((Int, NSPoint) -> Void)?

    private var buttons: [TabButton] = []

    /// Danh tính các nút tab — bài tự kiểm dùng để đòi thanh này DÙNG LẠI view, không dựng lại.
    var buttonIdentitiesForSelfTest: [ObjectIdentifier] { buttons.map(ObjectIdentifier.init) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.height)
    }

    /// Bắt cú nhấn ở THANH TAB, không ở từng nút tab.
    ///
    /// Lý do là an toàn bộ nhớ, không phải kiến trúc: mỗi lần đổi chỗ tab thì thanh dựng lại
    /// toàn bộ nút, nên nút nào đang có `mouseDown` trên ngăn xếp sẽ bị giải phóng giữa chừng.
    /// Bắt ở thanh — thứ sống suốt thao tác — thì không còn chỗ cho lỗi ấy.
    ///
    /// Nút đóng của mỗi tab vẫn nhận cú nhấn của nó như thường: nó là `NSButton` con, nên
    /// `hitTest` trả về nó trước khi tới đây.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_TABS"] != nil {
            NSLog("[tabs] mouseDown (%.0f, %.0f) → %@", point.x, point.y,
                  String(describing: tabIndex(atX: point.x)))
        }
        guard let index = tabIndex(atX: point.x) else {
            // Chỗ TRỐNG của thanh tab vẫn phải kéo được cửa sổ, như mọi trình duyệt. Cửa sổ đã
            // bị khoá `isMovable` nên phải tự gọi — và gọi từ đây thì nó chỉ xảy ra khi người
            // dùng thật sự nhấn ngoài mọi tab.
            window?.performDrag(with: event)
            return
        }
        beginDrag(from: index, with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if ProcessInfo.processInfo.environment["GEDITOR_TRACE_TABS"] != nil {
            NSLog("[tabs] mouseDown (%.0f, %.0f) → %@", point.x, point.y,
                  String(describing: tabIndex(atX: point.x)))
        }
        guard let index = tabIndex(atX: point.x) else { return }
        onContextMenu?(index, point)
    }

    /// Tab nằm dưới toạ độ x, hoặc `nil` nếu nhấn vào chỗ trống của thanh.
    private func tabIndex(atX x: CGFloat) -> Int? {
        buttons.firstIndex { x >= $0.frame.minX && x < $0.frame.maxX }
    }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.Color.chrome.setFill()
        bounds.fill()
        // Vạch ngăn với vùng soạn thảo.
        Tokens.Color.separator.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    override func layout() {
        super.layout()
        positionButtons()
    }

    /// Tự đặt vị trí từng tab thay vì nhờ `NSStackView`.
    ///
    /// Đã thử stack (trong scroll view) và nó vẽ đúng MỘT tab dù mô hình có ba — lần thứ ba
    /// trong dự án này một layout AppKit "đọc mã thấy đúng, nhìn màn hình thấy sai". Với một
    /// thanh tab thì tự tính vị trí vừa ngắn hơn vừa không có chỗ để bất ngờ.
    ///
    /// Nhiều tab hơn bề rộng thì tab bị CO LẠI đều nhau, tối thiểu 90 pt rồi cắt bớt tên. Chưa
    /// có cuộn ngang — với số tab thực tế thì co lại đọc vẫn được, và cuộn là việc riêng.
    private func positionButtons() {
        guard !buttons.isEmpty else { return }
        let available = bounds.width - Self.trafficLightInset - 8
        let ideal = Swift.min(180, Swift.max(90, available / CGFloat(buttons.count)))
        var x: CGFloat = Self.trafficLightInset
        for button in buttons {
            // Đặt khung con NGAY tại đây thay vì trông vào `layout()` của từng nút: ba nút có
            // khung đúng mà chỉ một nút vẽ ra chữ, và lượt layout của AppKit là nghi phạm duy
            // nhất còn lại. Tự làm thì không còn chỗ để nghi.
            button.place(in: NSRect(x: x, y: 0, width: ideal, height: Self.height))
            x += ideal + 1
        }
    }

    /// Vòng kéo tab, tự chạy thay vì dùng `NSDraggingSession`.
    ///
    /// Ba lý do, theo thứ tự quan trọng:
    ///
    /// 1. **Đổi chỗ NGAY trong lúc kéo.** Đó là hành vi người dùng mong đợi ở mọi trình soạn
    ///    thảo, và với `NSDraggingSession` thì phải tự vẽ ảnh kéo và tự tính khe thả — nhiều
    ///    việc hơn chứ không ít hơn.
    /// 2. **Thả sang nửa kia của màn hình** chỉ là một phép thử toạ độ, không cần đăng ký kiểu
    ///    dữ liệu kéo thả trên từng khung soạn thảo.
    /// 3. Dự án đã có sẵn một vòng kéo tự chạy cho việc chọn khối cột, nên đây là nếp quen.
    ///
    /// **Kéo sang cửa sổ khác chạy được mà KHÔNG cần `NSDraggingSession`.** Trong lúc vòng này
    /// chạy, mọi sự kiện chuột vẫn đi về cửa sổ đã nhận `mouseDown` — kể cả khi con trỏ đã ra
    /// ngoài nó. Nên chỉ cần đổi toạ độ sang MÀN HÌNH lúc thả rồi hỏi xem cửa sổ nào nằm dưới
    /// điểm ấy.
    ///
    /// `NSDraggingSession` sẽ cho thêm hình ảnh tab bay theo con trỏ và phản hồi ở cửa sổ đích.
    /// Cái giá của nó là mỗi khung soạn thảo phải khai kiểu dữ liệu kéo thả riêng, và đường
    /// kéo thả của `NSTextView` sẽ tranh chỗ với nó — đúng ba lý do đã kể ở trên. Đổi lấy hình
    /// ảnh bay là không đáng.
    ///
    /// Vòng chạy ở THANH TAB chứ không ở từng nút: mỗi lần đổi chỗ là thanh dựng lại toàn bộ
    /// nút, nên nút đang chạy vòng sẽ bị hủy giữa chừng.
    func beginDrag(from index: Int, with event: NSEvent) {
        let start = convert(event.locationInWindow, from: nil)
        var current = index
        var didMove = false

        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let point = convert(next.locationInWindow, from: nil)

            if next.type == .leftMouseUp {
                // Chưa vượt ngưỡng thì đây là một cú BẤM, không phải cú kéo. Không có ngưỡng
                // thì tay run vài pixel cũng thành đổi chỗ tab.
                if !didMove {
                    onSelect?(current)
                } else if !bounds.contains(point) {
                    // Thả NGOÀI thanh tab. Hai đích khác nhau, và thứ tự xét quan trọng:
                    //
                    // 1. Rơi vào một CỬA SỔ KHÁC → dời tab sang đó (FR-DOC-302).
                    // 2. Rơi vào chính cửa sổ này → chia đôi màn hình, như trước.
                    //
                    // Xét cửa sổ khác trước: điểm thả nằm ngoài cửa sổ này thì `dropTab` cũ
                    // cũng đã từ chối, nên đảo thứ tự chỉ làm mất một nhánh.
                    let screen = window?.convertPoint(toScreen: next.locationInWindow)
                        ?? NSEvent.mouseLocation
                    onDropOnScreen?(current, screen)
                }
                return
            }

            if ProcessInfo.processInfo.environment["GEDITOR_TRACE_TABS"] != nil {
                NSLog("[tabs] kéo tới (%.0f, %.0f) · khe %d · hiện tại %d",
                      point.x, point.y, slot(atX: point.x), current)
            }
            if !didMove, abs(point.x - start.x) < 4, abs(point.y - start.y) < 4 { continue }
            didMove = true

            guard bounds.contains(point) else { continue }
            let target = slot(atX: point.x)
            guard target != current else { continue }
            onReorder?(current, target)
            current = target
        }
    }

    /// Khe mà con trỏ đang nằm trên.
    private func slot(atX x: CGFloat) -> Int {
        guard !buttons.isEmpty else { return 0 }
        for (index, button) in buttons.enumerated() where x < button.frame.maxX {
            return index
        }
        return buttons.count - 1
    }

    /// Đồng bộ số nút với số tab, rồi đổ nội dung vào những nút ĐÃ CÓ.
    ///
    /// **Vì sao không vứt hết rồi tạo lại.** Mỗi `TabButton` mới kéo theo một chùm đăng ký KVO
    /// của AppKit (`NSKeyValueDependency` và các block đi kèm) mà hệ thống KHÔNG thu lại khi
    /// view rời khỏi cây. Thanh này dựng lại ở mỗi lần đổi tab, nên cái giá ấy cộng dồn theo
    /// từng thao tác của người dùng chứ không theo số tab.
    ///
    /// Bộ chạy dài `--soak` đo được (NFR-REL-03): đây là nguồn rò thứ HAI, tìm ra sau khi sửa
    /// `StatusBarView` xong mà bộ nhớ vẫn leo — 62.000 đối tượng KVO còn đọng sau 5.000 thao
    /// tác. Cùng một mẫu lỗi, ở hai chỗ khác nhau, và cả hai đều là "dựng lại cho chắc".
    ///
    /// Cách tìm: `heap <pid>` chỉ ra lớp chiếm chỗ, `MallocStackLogging=1` +
    /// `malloc_history` chỉ thẳng ra `TabBarView.rebuild()`.
    private func rebuild() {
        while buttons.count > items.count {
            buttons.removeLast().removeFromSuperview()
        }
        while buttons.count < items.count {
            let button = TabButton(onClose: { [weak self] in self?.onClose?($0) })
            buttons.append(button)
            addSubview(button)
        }
        for (index, item) in items.enumerated() {
            buttons[index].update(item: item, isActive: index == activeIndex, index: index)
        }
        positionButtons()
        needsDisplay = true
    }
}

/// Một tab.
private final class TabButton: NSView {

    private var index = 0
    private var item = TabBarView.Item(title: "", isModified: false, isPinned: false)
    private var isActive = false
    private let onClose: (Int) -> Void

    /// Chữ VẼ THẲNG, không dùng `NSTextField`.
    ///
    /// Không phải để gọn: `NSTextField` là một khung con nhận hit-test, và nó cho phép kéo cả
    /// CỬA SỔ. Cửa sổ dùng `.fullSizeContentView` nên thanh tab nằm đúng chỗ thanh tiêu đề —
    /// kết quả đo bằng cú kéo chuột thật: kéo tab thì cửa sổ chạy từ x=60 sang x=−327, ra
    /// ngoài màn hình, còn thứ tự tab không đổi. Đặt `mouseDownCanMoveWindow = false` cho tab
    /// không cứu được, vì thuộc tính ấy chỉ đọc nên không đặt được lên `NSTextField`.
    private var title = ""
    private let closeButton = NSButton()

    init(onClose: @escaping (Int) -> Void) {
        self.onClose = onClose
        super.init(frame: .zero)

        closeButton.title = "✕"
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 10)
        closeButton.target = self
        closeButton.action = #selector(close)
        closeButton.toolTip = "Đóng tab"

        addSubview(closeButton)
    }

    /// Đổ nội dung một tab vào nút đã có. Không tạo view nào.
    func update(item: TabBarView.Item, isActive: Bool, index: Int) {
        self.item = item
        self.isActive = isActive
        self.index = index

        // Chấm BẨN thay cho nút đóng khi tài liệu chưa lưu — cùng quy ước với Safari và Xcode:
        // người dùng ít khi đóng nhầm một tab chưa lưu nếu chỗ ấy không phải nút đóng.
        title = (item.isPinned ? "📌 " : "") + item.title + (item.isModified ? " •" : "")
        toolTip = item.tooltip
        needsDisplay = true
    }

    /// Đặt khung của chính nút và của chữ/nút đóng bên trong, trong một lần.
    func place(in rect: NSRect) {
        frame = rect
        let closeSize: CGFloat = 16
        closeButton.frame = NSRect(
            x: rect.width - closeSize - 6, y: (rect.height - closeSize) / 2,
            width: closeSize, height: closeSize
        )
        needsDisplay = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        (isActive ? Tokens.Color.editorBackground : Tokens.Color.chrome).setFill()
        // `bounds`, KHÔNG phải `dirtyRect`.
        //
        // AppKit truyền vào một dirtyRect có thể LỚN HƠN view rất nhiều — đo được
        // {{-4,-690},{1100,720}} cho một nút 180×30, tức cả cửa sổ quy về hệ toạ độ của nút.
        // Tô dirtyRect nghĩa là mỗi tab tô đè lên mọi tab khác, và cái vẽ sau cùng thắng: ba
        // tab tồn tại, khung đúng, mà màn hình chỉ thấy MỘT.
        bounds.fill()

        // Màu tab hiện thành vạch dưới, không tô nền: nền màu làm chữ khó đọc, và tab đang mở
        // đã dùng nền để phân biệt rồi.
        if let colorIndex = item.colorIndex, colorIndex < TabBarView.colors.count {
            TabBarView.colors[colorIndex].setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 3).fill()
        } else if isActive {
            Tokens.Color.orange.setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle      // cắt GIỮA: đuôi tên file quan trọng
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: isActive ? .semibold : .regular),
            .foregroundColor: isActive ? Tokens.Color.editorInk : Tokens.Color.secondaryInk,
            .paragraphStyle: paragraph,
        ]
        (title as NSString).draw(
            in: NSRect(x: 10, y: (bounds.height - 16) / 2,
                       width: Swift.max(0, bounds.width - 38), height: 16),
            withAttributes: attributes
        )
    }


    @objc private func close() { onClose(index) }
}
