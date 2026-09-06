import AppKit
import GEditorCore

/// Nguồn trang: thứ duy nhất `DocumentPagesView` cần biết về một tài liệu.
///
/// Tách ra vì trang giấy Word, trang slide và trang bảng tính khác nhau ở CÁCH VẼ chứ không khác
/// nhau ở cách cuộn, cách phóng, hay cách đếm trang. Một khung cuộn dùng chung cho cả ba là lý
/// do người dùng học một lần rồi dùng được ở mọi loại tệp.
protocol DocumentPageSource: AnyObject {
    /// Khổ trang theo POINT của tài liệu — không phải theo màn hình.
    var pageSizePt: CGSize { get }
    var pageCount: Int { get }
    /// Vẽ trang `index` trong hệ toạ độ POINT của trang. Phép phóng do khung cuộn lo.
    func draw(page index: Int, dirtyRect: CGRect)
}

/// Chế độ **View** dựng thành TRANG — cuộn liên tục, mỗi trang một tờ giấy.
///
/// ## Vì sao không dùng bộ xem của hệ điều hành
///
/// Bản trước dùng QuickLook, chính bộ dựng mà Finder bấm Space ra. Nó trung thực, nhưng nó là
/// một hộp đen: **không có API phóng, không có API vừa-bề-ngang**. Nó vẽ trang ở khổ tự nhiên
/// rồi căn giữa, nên trên một cửa sổ rộng 3300 pt thì một trang A4 chiếm chưa tới một phần ba bề
/// ngang — hai mảng trắng khổng lồ hai bên. Không có ràng buộc bố cục nào sửa được điều đó, vì
/// nó xảy ra BÊN TRONG tiến trình dựng của hệ điều hành.
///
/// Nên trang ở đây do sản phẩm tự vẽ, và phép phóng là một con số nhân do sản phẩm tự đặt. Đổi
/// lại phải tự lo phân trang, tự lo font, tự lo bảng — cái giá đã trả ở `DOCXLayout` và
/// `DocumentPageBuilder`.
///
/// ## Bố cục
///
/// Nền xám, mỗi trang là một tờ giấy trắng có bóng đổ, xếp dọc, cách nhau một khoảng. Đó là hình
/// dạng mà mọi trình đọc tài liệu đều dùng, và nó không phải chuyện thẩm mỹ: mép tờ giấy là thứ
/// nói cho người đọc biết lề của tài liệu kết thúc ở đâu và khoảng trống của ứng dụng bắt đầu từ
/// đâu.
final class DocumentPagesView: NSView {

    /// Phép phóng.
    enum Zoom: Equatable {
        /// Trang rộng đúng bằng khung — mặc định.
        case fitWidth
        /// Cả trang vừa trong khung.
        case fitPage
        case factor(CGFloat)
    }

    /// Khoảng cách giữa mép khung và tờ giấy, và giữa hai tờ.
    private static let gutter: CGFloat = 16

    var zoom: Zoom = .fitWidth {
        didSet {
            guard zoom != oldValue else { return }
            layoutPages()
            onZoomChanged?(scale)
        }
    }

    /// Trang đang ở đầu tầm nhìn (đếm từ 1) và tổng số trang.
    var onPageChanged: ((Int, Int) -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?

    private let scrollView = NSScrollView()
    private let canvas = PagesCanvasView()
    private var source: DocumentPageSource?
    private var cards: [PageCardView] = []
    private(set) var scale: CGFloat = 1
    private var reportedPage = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    /// **KHÔNG `wantsLayer`.** Đây không phải chuyện phong cách — xem chú thích của
    /// `PageCardView`: một `wantsLayer` ở đây ép cả cây bên dưới thành layer-backed, và tờ canvas
    /// cao vài chục nghìn point sẽ vượt giới hạn texture của CoreAnimation rồi biến mất SẠCH.
    override func draw(_ dirtyRect: NSRect) {
        // Cắt về BOUNDS trước khi tô.
        //
        // Trên macOS, `NSView` KHÔNG tự cắt phần vẽ theo khung của mình (`clipsToBounds` mặc
        // định tắt), và `dirtyRect` trong một lượt `cacheDisplay` có thể rộng hơn khung. Tô
        // thẳng `dirtyRect` vì thế sơn đè lên thanh tab và khung công cụ ở phía trên — đã xảy
        // ra thật, và nó chỉ lộ ra trong ảnh chụp chứ không lộ ra khi cuộn.
        Tokens.Color.pageBackdrop.setFill()
        dirtyRect.intersection(bounds).fill()
    }

    private func build() {

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Tokens.Color.pageBackdrop
        scrollView.documentView = canvas
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Cuộn theo trang phải MƯỢT ở tài liệu vài trăm trang; vẽ lại cả canvas mỗi khung hình
        // là thứ làm nó giật. Chỉ những tờ giấy lộ ra mới được vẽ lại.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        scrollView.backgroundColor = Tokens.Color.pageBackdrop
        needsDisplay = true
    }

    // MARK: - Nạp

    func present(source: DocumentPageSource) {
        self.source = source
        for card in cards { card.removeFromSuperview() }
        cards = (0 ..< source.pageCount).map { index in
            let card = PageCardView()
            card.source = source
            card.pageIndex = index
            canvas.addSubview(card)
            return card
        }
        // `-1` chứ không phải `0`: bộ báo chỉ phát khi số trang ĐỔI, nên khởi tạo bằng 0 thì
        // trang 1 không bao giờ được báo và nhãn «Trang 1/363» không bao giờ hiện ra.
        reportedPage = -1
        scrollView.contentView.scroll(to: .zero)
        layoutPages()
    }

    var pageCount: Int { source?.pageCount ?? 0 }

    /// Vẽ lại những tờ giấy đang lộ ra.
    ///
    /// Chỉ những tờ ĐANG THẤY: gọi `needsDisplay` cho cả 383 tờ là bắt AppKit dựng lại từng ấy
    /// trang cho một thay đổi chỉ ảnh hưởng tới một tờ.
    func redrawVisible() {
        let visible = scrollView.contentView.bounds
        for card in cards where card.frame.intersects(visible) { card.needsDisplay = true }
    }

    /// Cuộn tới trang `index` (đếm từ 0).
    func scroll(toPage index: Int) {
        guard cards.indices.contains(index) else { return }
        let target = cards[index].frame.origin.y - Self.gutter
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, target)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Bố cục và phóng

    override func layout() {
        super.layout()
        layoutPages()
    }

    private func layoutPages() {
        guard let source, source.pageCount > 0 else {
            canvas.frame = NSRect(origin: .zero, size: bounds.size)
            return
        }

        let paper = source.pageSizePt
        guard paper.width > 0, paper.height > 0 else { return }

        // Bề rộng có thể dùng: trừ hai bên lề VÀ trừ bề rộng thanh cuộn dọc. Quên thanh cuộn thì
        // ở chế độ "vừa bề ngang" trang rộng hơn khung đúng bằng thanh cuộn, và thanh cuộn NGANG
        // hiện ra — một tài liệu vừa khít lại đòi cuộn ngang là lỗi người dùng thấy ngay.
        let scrollerWidth: CGFloat = scrollView.hasVerticalScroller
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: scrollView.scrollerStyle)
            : 0
        let availableWidth = max(80, bounds.width - Self.gutter * 2 - scrollerWidth)
        // Chiều cao KHÔNG có sàn 80 pt như bề ngang.
        //
        // Sàn ấy làm "vừa trang" nói dối: trong một khung cao 54 pt nó tính theo 80 pt rồi cho
        // ra tờ giấy cao 84 pt — tràn ra ngoài đúng cái khung mà nó vừa hứa là vừa. Bề ngang thì
        // cần sàn (khung hẹp vẫn phải đọc được bằng cách cuộn ngang); chiều cao thì không, vì
        // trang vốn đã cuộn dọc.
        let availableHeight = max(1, bounds.height - Self.gutter * 2)

        switch zoom {
        case .fitWidth:
            scale = availableWidth / paper.width
        case .fitPage:
            scale = min(availableWidth / paper.width, availableHeight / paper.height)
        case .factor(let value):
            scale = value
        }
        // Trần và sàn: một tài liệu khổ danh thiếp trên màn hình 6K sẽ ra phép phóng 12 lần, và
        // chữ to bằng nắm tay không phải thứ ai muốn. Sàn để không bao giờ ra một trang 3 pixel.
        scale = max(0.1, min(6, scale))

        let pageWidth = (paper.width * scale).rounded()
        let pageHeight = (paper.height * scale).rounded()
        let originX = max(Self.gutter, ((bounds.width - scrollerWidth) - pageWidth) / 2)

        var y = Self.gutter
        for card in cards {
            card.frame = NSRect(x: originX, y: y, width: pageWidth, height: pageHeight)
            card.scale = scale
            y += pageHeight + Self.gutter
        }
        canvas.frame = NSRect(
            x: 0, y: 0,
            width: max(bounds.width - scrollerWidth, pageWidth + Self.gutter * 2),
            height: max(bounds.height, y)
        )
        reportVisiblePage()
    }

    @objc private func scrolled() { reportVisiblePage() }

    private func reportVisiblePage() {
        guard !cards.isEmpty else { return }
        let top = scrollView.contentView.bounds.origin.y
        // Trang đang đọc là trang mà mép trên của khung rơi vào — không phải trang đầu tiên hiện
        // ra. Hai thứ đó khác nhau đúng lúc người dùng đang ở giữa hai trang.
        var index = 0
        for (position, card) in cards.enumerated() where card.frame.minY <= top + 1 {
            index = position
        }
        guard index != reportedPage else { return }
        reportedPage = index
        onPageChanged?(index + 1, cards.count)
    }

    // MARK: - Chọn chữ bằng chuột

    /// Nguồn trang có cho chọn chữ không — slide thì không, vì chữ trên slide nằm rải trong
    /// từng hộp và một vệt kéo qua ba hộp không có nghĩa gì.
    private var selectableSource: DocumentTextPageSource? { source as? DocumentTextPageSource }

    private var dragAnchor: PageLocation?

    override func mouseDown(with event: NSEvent) {
        guard let text = selectableSource else { return super.mouseDown(with: event) }
        guard let hit = locate(event) else {
            text.clearSelection()
            redrawVisible()
            return
        }
        // Bấm hai lần chọn cả TỪ, ba lần chọn cả đoạn — đúng thói quen của mọi ô chữ trên macOS.
        if event.clickCount >= 2 {
            text.selectUnit(at: hit, whole: event.clickCount >= 3)
            dragAnchor = nil
        } else {
            dragAnchor = hit
            text.setSelection(from: hit, to: hit)
        }
        redrawVisible()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let text = selectableSource, let anchor = dragAnchor else {
            return super.mouseDragged(with: event)
        }
        guard let hit = locate(event) else { return }
        text.setSelection(from: anchor, to: hit)
        redrawVisible()
        // Kéo quá mép thì cuộn theo — không có nó thì không chọn nổi quá một màn hình.
        autoscroll(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchor = nil
        super.mouseUp(with: event)
    }

    /// Điểm chuột → chỗ trong tài liệu, qua tờ giấy nằm dưới con trỏ.
    private func locate(_ event: NSEvent) -> PageLocation? {
        guard let text = selectableSource else { return nil }
        let inCanvas = canvas.convert(event.locationInWindow, from: nil)
        guard let index = cards.firstIndex(where: { $0.frame.contains(inCanvas) })
            ?? cards.firstIndex(where: { $0.frame.maxY >= inCanvas.y })
        else { return nil }
        let card = cards[index]
        let inCard = CGPoint(x: inCanvas.x - card.frame.minX, y: inCanvas.y - card.frame.minY)
        let onPaper = CGPoint(x: inCard.x / scale, y: inCard.y / scale)
        return text.location(page: index, point: onPaper)
    }

    /// Chữ đang bôi đen — `MainWindowController` đọc nó cho ⌘C.
    var selectedText: String { selectableSource?.selectedText ?? "" }

    func selectAllText() {
        selectableSource?.selectAll()
        redrawVisible()
    }

    func clearSelection() {
        selectableSource?.clearSelection()
        redrawVisible()
    }

    // MARK: - Phím và con lăn

    /// ⌘+ / ⌘− / ⌘0 và Ctrl-con lăn — cùng phím với mọi trình đọc tài liệu.
    override func magnify(with event: NSEvent) {
        let current = scale
        setZoom(factor: current * (1 + event.magnification))
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.scrollWheel(with: event)
            return
        }
        setZoom(factor: scale * (1 + event.scrollingDeltaY / 200))
    }

    func setZoom(factor: CGFloat) {
        zoom = .factor(max(0.1, min(6, factor)))
    }

    func zoomIn() { setZoom(factor: scale * 1.25) }
    func zoomOut() { setZoom(factor: scale / 1.25) }

    override var acceptsFirstResponder: Bool { true }

    /// ⌘A đi thẳng vào đây khi khung trang đang giữ bàn phím.
    ///
    /// Menu «Chọn tất cả» trỏ vào `NSText.selectAll(_:)` và đi theo chuỗi responder, nên chỉ cần
    /// khai đúng chữ ký ấy là nó tìm tới. Không khai thì ⌘A rơi xuống vùng soạn thảo đang bị che
    /// và chọn hết một thứ người dùng không nhìn thấy — đúng mẫu lỗi "lệnh chung tác động lên
    /// thứ đang bị che" đã gặp bốn lần trong sản phẩm này.
    @objc override func selectAll(_ sender: Any?) { selectAllText() }

    /// Phím điều hướng của một trình đọc tài liệu.
    ///
    /// `NSScrollView` tự lo con lăn nhưng KHÔNG tự lo Page Up / Home / End khi khung cuộn không
    /// phải first responder — mà ở đây nó không phải, vì view này nhận phím để còn xử ⌘C.
    override func keyDown(with event: NSEvent) {
        let step = bounds.height * 0.9
        switch Int(event.keyCode) {
        case 116: scrollBy(-step)                       // Page Up
        case 121: scrollBy(step)                        // Page Down
        case 115: scroll(toPage: 0)                     // Home
        case 119: scroll(toPage: max(0, cards.count - 1))   // End
        case 126: scrollBy(-40)                         // ↑
        case 125: scrollBy(40)                          // ↓
        default: super.keyDown(with: event)
        }
    }

    private func scrollBy(_ delta: CGFloat) {
        let origin = scrollView.contentView.bounds.origin
        let limit = max(0, canvas.frame.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(
            to: NSPoint(x: origin.x, y: min(limit, max(0, origin.y + delta))))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Cửa cho bài tự kiểm

    var scaleForSelfTest: CGFloat { scale }
    var pageCountForSelfTest: Int { cards.count }
    /// Bề ngang tờ giấy trên màn hình, theo point.
    var pageWidthOnScreenForSelfTest: CGFloat { cards.first?.frame.width ?? 0 }
    var canvasWidthForSelfTest: CGFloat { canvas.frame.width }
    /// Tỉ lệ ngang/dọc của KHỔ TÀI LIỆU — A4 dọc ≈ 0,71 · slide 16:9 ≈ 1,78.
    var pageAspectForSelfTest: CGFloat {
        guard let source, source.pageSizePt.height > 0 else { return 0 }
        return source.pageSizePt.width / source.pageSizePt.height
    }

    /// Buộc bố cục chạy NGAY, rồi xếp lại trang.
    ///
    /// Ép cả lượt autolayout chứ không chỉ gọi `layoutPages`: khi bài kiểm chạy không có ai
    /// ngồi trước máy, cửa sổ có thể chưa qua lượt bố cục nào và `bounds` còn bằng 0 — đo lúc
    /// ấy ra "khung rộng 0 pt", một câu trả lời nói về thời điểm hỏi chứ không nói về sản phẩm.
    /// Đã xảy ra thật, và chỉ ở bản bundle sandbox.
    /// Chữ chân trang của trang `index` — bài tự kiểm hỏi để biết trang lấy của PHẦN nào.
    func footerTextForSelfTest(page index: Int) -> String {
        (source as? DocumentTextPageSource)?.footerTextForSelfTest(page: index) ?? ""
    }

    func layoutNowForSelfTest() {
        window?.contentView?.layoutSubtreeIfNeeded()
        layoutPages()
    }

    /// Những view trên đường dựng trang đang bật layer.
    ///
    /// Bài kiểm hỏi câu này vì một `wantsLayer` ở đây làm **cả vùng xem trắng trơn** mà không
    /// phép so hành vi nào bắt được: `draw` vẫn chạy, số trang vẫn đúng, bề ngang vẫn đúng, xuất
    /// một tờ ra PDF vẫn đủ chữ và đủ màu. Thứ hỏng nằm ở tầng compositing — tờ canvas cao vài
    /// chục nghìn point vượt giới hạn texture của CoreAnimation, và nó bỏ trắng chứ không báo.
    var layerBackedAnywhereForSelfTest: [String] {
        var found: [String] = []
        if wantsLayer { found.append("DocumentPagesView") }
        if canvas.wantsLayer { found.append("canvas") }
        if cards.first?.wantsLayer == true { found.append("PageCardView") }
        return found
    }

    /// Tỉ lệ điểm ảnh KHÁC TRẮNG trên tờ giấy đầu, 0…1.
    ///
    /// Phép đo duy nhất trả lời được câu "trang có chữ trên đó không". Mọi phép so khác — số
    /// trang, bề ngang, đường dẫn đang dựng — đều xanh ở lần hỏng đầu tiên, khi màn hình thật sự
    /// chỉ là một mảng trắng.
    func firstPageInkForSelfTest() -> Double {
        inkForSelfTest(page: 0, band: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// Mực trong một DẢI của tờ giấy, toạ độ theo tỉ lệ 0…1 của trang.
    ///
    /// Cần dải chứ không chỉ cả tờ vì đầu và chân trang nằm trong BĂNG LỀ: đo cả tờ thì phần
    /// thân át hết, và một chân trang biến mất vẫn cho ra con số y hệt.
    func inkForSelfTest(page index: Int, band: CGRect) -> Double {
        guard cards.indices.contains(index) else { return 0 }
        let card = cards[index]
        guard card.bounds.width > 1 else { return 0 }
        let box = CGRect(
            x: card.bounds.width * band.minX, y: card.bounds.height * band.minY,
            width: card.bounds.width * band.width, height: card.bounds.height * band.height)
        return ink(of: card, in: box)
    }

    private func ink(of card: NSView, in box: NSRect) -> Double {
        guard box.width > 1, box.height > 1 else { return 0 }
        // Đo CẢ DẢI được hỏi, không đo một góc của nó.
        //
        // Bản đầu lấy mẫu 420×600 pt ở góc trên bên trái và báo "trắng" cho ba cuốn sách thật —
        // sai, vì trang bìa của chúng căn GIỮA và bắt đầu bằng một khoảng cách 45 pt. Một phép
        // đo "có mực không" mà chỉ nhìn một góc thì trả lời sai đúng ở những trang được trình
        // bày cẩn thận nhất.
        guard let rep = card.bitmapImageRepForCachingDisplay(in: box) else { return 0 }
        card.cacheDisplay(in: box, to: rep)
        // Bước nhảy theo khổ thật: khoảng 200 mẫu mỗi chiều là đủ để thấy có chữ hay không, và
        // không phụ thuộc phép phóng đang là bao nhiêu.
        let step = max(1, min(rep.pixelsWide, rep.pixelsHigh) / 200)
        var ink = 0
        var total = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: step) {
            for x in stride(from: 0, to: rep.pixelsWide, by: step) {
                total += 1
                let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                if let color, color.brightnessComponent < 0.92 { ink += 1 }
            }
        }
        return total == 0 ? 0 : Double(ink) / Double(total)
    }
}

/// Nền chứa các tờ giấy. Lật trục để trang 1 nằm trên cùng.
private final class PagesCanvasView: NSView {
    override var isFlipped: Bool { true }
}

/// Một tờ giấy.
///
/// ## Vì sao tờ giấy này KHÔNG dùng layer
///
/// Bản đầu đặt `wantsLayer = true` để lấy bóng đổ của CoreAnimation — nền trắng, `shadowRadius`,
/// ba dòng là xong. Kết quả: **cả vùng xem trắng trơn**, không trang, không nền xám, không cả
/// đường viền đỏ mà bản chẩn đoán vẽ ra. Mà `draw` vẫn chạy: xuất chính tờ giấy ấy ra PDF thì có
/// đủ chữ, đủ màu, đủ ảnh.
///
/// Nguyên nhân: `wantsLayer` ở view cha ép **cả cây bên dưới** thành layer-backed, kể cả tờ
/// canvas chứa toàn bộ các trang. Một tài liệu 20 trang cho canvas cao hơn 30.000 pt — 60.000
/// pixel ở màn hình Retina — vượt giới hạn texture của CoreAnimation. Khi ấy nó không vẽ nửa
/// vời và cũng không báo lỗi: nó bỏ trắng.
///
/// Nên bóng đổ ở đây vẽ bằng `NSShadow`, và tờ giấy vẽ bằng `draw`. Vẽ theo yêu cầu cũng là thứ
/// `NSScrollView` vốn làm tốt: chỉ tờ nào lộ ra mới tốn công.
private final class PageCardView: NSView {

    weak var source: DocumentPageSource?
    var pageIndex = 0
    var scale: CGFloat = 1 {
        didSet { if scale != oldValue { needsDisplay = true } }
    }

    override var isFlipped: Bool { true }

    /// Tờ giấy TRẮNG kể cả ở giao diện tối.
    ///
    /// Đảo màu trang theo theme nghe có vẻ tử tế, nhưng tài liệu mang màu của chính nó: một ô
    /// bảng tô vàng nhạt trên nền đen đảo ra thành thứ không ai thiết kế. Trình đọc tài liệu nào
    /// cũng để trang trắng, và người dùng đọc một tờ giấy chứ không đọc một cửa sổ.
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Bóng đổ chỉ vẽ khi mép tờ giấy nằm trong vùng bẩn — vẽ bóng cho một dải giữa trang là
        // tốn công cho thứ không ai thấy.
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 5
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.white.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let source else { return }
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        // Vùng bẩn quy về toạ độ TRANG: nguồn vẽ chỉ nên dựng phần lộ ra.
        let paperDirty = CGRect(
            x: dirtyRect.minX / scale, y: dirtyRect.minY / scale,
            width: dirtyRect.width / scale, height: dirtyRect.height / scale)
        source.draw(page: pageIndex, dirtyRect: paperDirty)
        context.restoreGState()
    }
}
