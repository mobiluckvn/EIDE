import AppKit
import GEditorCore

/// Chế độ **View** của tệp Office — trang do sản phẩm tự dựng.
///
/// ## Vì sao bỏ QuickLook
///
/// Bản trước gọi QuickLook, chính bộ dựng mà Finder bấm Space ra. Trung thực, nhưng là một hộp
/// đen **không có API phóng và không có API vừa-bề-ngang**: nó vẽ trang ở khổ tự nhiên rồi căn
/// giữa. Trên cửa sổ rộng, một trang A4 chiếm chưa tới một phần ba bề ngang và hai bên là hai
/// mảng trắng — không ràng buộc bố cục nào sửa được, vì chuyện đó xảy ra bên trong tiến trình
/// dựng của hệ điều hành.
///
/// Nên đường đi bây giờ là đường mà một trình đọc tài liệu thật đi: lõi đọc tệp thành **mô hình
/// trang** (`DOCXLayout`), tầng này đổi sang đối tượng của macOS (`DocumentPageBuilder`), rồi
/// `DocumentPagesView` vẽ từng tờ giấy ở đúng bề rộng khung. Phép phóng là một con số nhân của
/// chính sản phẩm, nên "vừa bề ngang" là chuyện làm được.
///
/// ## Vẫn CHỈ ĐỌC, và vẫn nói ra khi trang là bản cũ
///
/// Mọi phép sửa ở chế độ Code — View là hệ quả, Code là bản gốc, đúng luật chung của sản phẩm.
/// Khác QuickLook một điểm quan trọng: trang ở đây dựng từ **tệp trên đĩa**, nên buffer đã sửa mà
/// chưa lưu thì trang là bản cũ. Giấu điều đó là để người dùng đọc một tài liệu không còn tồn
/// tại; dải chữ trên đầu nói ra, kèm nút **Lưu rồi dựng lại**.
final class OfficeDocumentView: NSView {

    /// Người dùng bấm "Lưu rồi dựng lại".
    var onSaveAndReload: (() -> Void)?
    /// Trang đang đọc đổi: (trang, tổng).
    var onPageChanged: ((Int, Int) -> Void)?

    let pages = DocumentPagesView()
    private let notice = NSTextField(labelWithString: "")
    private let reloadButton = NSButton(title: "", target: nil, action: nil)
    private var noticeHeight: NSLayoutConstraint!

    private(set) var path: String?
    /// Nguồn trang đang dựng — giữ lại vì `DocumentPagesView` chỉ giữ tham chiếu yếu.
    private var source: DocumentPageSource?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Nền vẽ bằng `draw`, không bằng layer — xem `PageCardView` về lý do cả nhánh này phải
    /// tránh `wantsLayer`.
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
        notice.font = Tokens.Font.caption
        notice.textColor = Tokens.Color.ember
        notice.lineBreakMode = .byTruncatingTail
        notice.translatesAutoresizingMaskIntoConstraints = false

        reloadButton.title = L("Lưu rồi dựng lại")
        reloadButton.bezelStyle = .inline
        reloadButton.controlSize = .small
        reloadButton.font = Tokens.Font.caption
        reloadButton.target = self
        reloadButton.action = #selector(saveAndReload)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false

        pages.translatesAutoresizingMaskIntoConstraints = false
        pages.onPageChanged = { [weak self] page, total in self?.onPageChanged?(page, total) }

        addSubview(notice)
        addSubview(reloadButton)
        addSubview(pages)

        noticeHeight = notice.heightAnchor.constraint(equalToConstant: 0)
        let inset = Tokens.Metrics.spacing(3)
        NSLayoutConstraint.activate([
            notice.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            notice.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            noticeHeight,

            reloadButton.centerYAnchor.constraint(equalTo: notice.centerYAnchor),
            reloadButton.leadingAnchor.constraint(
                equalTo: notice.trailingAnchor, constant: inset),

            pages.topAnchor.constraint(equalTo: notice.bottomAnchor, constant: 4),
            pages.leadingAnchor.constraint(equalTo: leadingAnchor),
            pages.trailingAnchor.constraint(equalTo: trailingAnchor),
            pages.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        showNotice(nil)
    }

    // MARK: - Nạp

    /// Dựng tệp ở `path`. `isStale` = buffer đã sửa mà chưa lưu.
    ///
    /// Trả về `false` khi không dựng nổi — người gọi khi ấy phải ở lại chế độ Code thay vì để
    /// người dùng nhìn một khoảng xám.
    @discardableResult
    func present(path: String, kind: MediaKind?, isStale: Bool) -> Bool {
        self.path = path
        var messages: [String] = []
        if isStale {
            messages.append(L("Đang xem bản TRÊN ĐĨA — những sửa đổi chưa lưu không có ở đây."))
        }

        switch kind {
        case .word:
            guard let document = try? DOCXLayout.read(path: path) else {
                showNotice(L("Không dựng được trang của tệp này — dùng chế độ Code."))
                return false
            }
            let pageSource = DocumentTextPageSource(document: document)
            source = pageSource
            pages.present(source: pageSource)
        case .powerpoint:
            guard let deck = try? PPTXLayout.read(path: path), !deck.slides.isEmpty else {
                showNotice(L("Không dựng được trang của tệp này — dùng chế độ Code."))
                return false
            }
            let pageSource = SlidePageSource(deck: deck)
            source = pageSource
            pages.present(source: pageSource)
        default:
            showNotice(L("Không dựng được trang của tệp này — dùng chế độ Code."))
            return false
        }

        showNotice(messages.isEmpty ? nil : messages.joined(separator: "  ·  "))
        return true
    }

    private func showNotice(_ text: String?) {
        notice.stringValue = text ?? ""
        notice.isHidden = text == nil
        reloadButton.isHidden = text == nil
        noticeHeight.constant = text == nil ? 0 : 18
    }

    @objc private func saveAndReload() { onSaveAndReload?() }

    // MARK: - Cửa cho bài tự kiểm

    var previewedPathForSelfTest: String? { path }
    var noticeForSelfTest: String { notice.isHidden ? "" : notice.stringValue }
    func tapReloadForSelfTest() { saveAndReload() }
    var pageCountForSelfTest: Int { pages.pageCountForSelfTest }
    var pageWidthOnScreenForSelfTest: CGFloat { pages.pageWidthOnScreenForSelfTest }
    var imageCountForSelfTest: Int {
        (source as? DocumentTextPageSource)?.imageCount
            ?? (source as? SlidePageSource)?.imageCount ?? 0
    }

    /// Trang chứa `needle`, đếm từ 0 — dùng cho ô tìm trên khung chung.
    func page(containing needle: String) -> Int? {
        (source as? DocumentTextPageSource)?.page(containing: needle)
            ?? (source as? SlidePageSource)?.page(containing: needle)
    }

    /// Số chỗ khớp `needle` trong tài liệu đang mở.
    func matchCount(for needle: String) -> Int {
        if let text = source as? DocumentTextPageSource { return text.matches(for: needle).count }
        if let slides = source as? SlidePageSource { return slides.matchCount(for: needle) }
        return 0
    }

    /// Nhảy tới chỗ khớp thứ `ordinal`, tô nó lên, và trả về trang. `nil` = không tìm thấy.
    @discardableResult
    func showMatch(_ needle: String, ordinal: Int) -> Int? {
        var page: Int?
        if let text = source as? DocumentTextPageSource {
            page = text.highlightMatch(needle, ordinal: ordinal)
        } else if let slides = source as? SlidePageSource {
            page = slides.page(containing: needle, ordinal: ordinal)
        }
        guard let page else { return nil }
        pages.scroll(toPage: page)
        pages.redrawVisible()
        return page
    }

    func clearSearchHighlight() {
        (source as? DocumentTextPageSource)?.clearHighlight()
        pages.redrawVisible()
    }
}

/// Trang slide dựng từ **hình khối có toạ độ** — không phải dàn ý đổ lên tờ trắng.
///
/// Mỗi `PPTXLayout.Shape` là một hộp: có chỗ đứng trên khổ slide, có thể có nền, viền, ảnh, và
/// chữ. Vẽ đúng thứ tự trong tệp là đủ để lớp trên che lớp dưới như PowerPoint làm.
///
/// **Còn thiếu, nói thẳng:** hiệu ứng chuyển cảnh, bóng đổ, gradient, biểu đồ và SmartArt (chúng
/// nằm trong `p:graphicFrame` dưới dạng một cây riêng). Một hộp không dựng được thì để trống chứ
/// không vẽ bừa.
final class SlidePageSource: DocumentPageSource {

    private let deck: PPTXLayout.Deck
    /// Chữ của từng hộp, dựng sẵn một lần: dựng lại ở mỗi lượt vẽ là dựng lại vài nghìn lần khi
    /// người dùng chỉ đang cuộn.
    private let texts: [[NSAttributedString]]
    private let images: [[NSImage?]]

    let pageSizePt: CGSize
    var pageCount: Int { deck.slides.count }
    var imageCount: Int { deck.imageCount }

    init(deck: PPTXLayout.Deck) {
        self.deck = deck
        pageSizePt = CGSize(width: deck.widthPt, height: deck.heightPt)
        texts = deck.slides.map { slide in
            slide.shapes.map { shape in
                let result = NSMutableAttributedString()
                for paragraph in shape.paragraphs {
                    result.append(DocumentPageBuilder.attributed(
                        slideParagraph: paragraph, width: shape.width))
                }
                return result
            }
        }
        images = deck.slides.map { slide in
            slide.shapes.map { shape in
                shape.image.flatMap { NSImage(data: Data($0.data)) }
            }
        }
    }

    func draw(page index: Int, dirtyRect: CGRect) {
        guard deck.slides.indices.contains(index) else { return }
        let slide = deck.slides[index]

        if let background = slide.background {
            DocumentPageBuilder.color(background).setFill()
            CGRect(origin: .zero, size: pageSizePt).fill()
        }

        for (position, shape) in slide.shapes.enumerated() {
            let box = CGRect(x: shape.x, y: shape.y, width: shape.width, height: shape.height)
            guard box.width > 0, box.height > 0 else { continue }

            NSGraphicsContext.saveGraphicsState()
            if shape.rotation != 0, let context = NSGraphicsContext.current?.cgContext {
                // Xoay quanh TÂM hộp. Xoay quanh gốc toạ độ đẩy hộp ra khỏi slide.
                context.translateBy(x: box.midX, y: box.midY)
                context.rotate(by: shape.rotation * .pi / 180)
                context.translateBy(x: -box.midX, y: -box.midY)
            }

            let path = shape.isEllipse
                ? NSBezierPath(ovalIn: box)
                : NSBezierPath(rect: box)
            if let fill = shape.fill {
                DocumentPageBuilder.color(fill).setFill()
                path.fill()
            }
            if let stroke = shape.stroke, shape.strokeWidthPt > 0 {
                DocumentPageBuilder.color(stroke).setStroke()
                path.lineWidth = shape.strokeWidthPt
                path.stroke()
            }
            if let picture = images[index][position] {
                picture.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1)
            }

            let text = texts[index][position]
            if text.length > 0 {
                // Lề trong của hộp chữ PowerPoint: 0,1 inch hai bên, 0,05 inch trên dưới.
                text.draw(in: box.insetBy(dx: 7.2, dy: 3.6))
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// Chữ thuần của cả bộ slide, theo thứ tự — cho ô tìm kiếm.
    var plainText: String {
        deck.slides.map { $0.shapes.map(\.plainText).joined(separator: "\n") }
            .joined(separator: "\n")
    }

    /// Những slide chứa `needle`, theo thứ tự.
    ///
    /// Slide đếm theo TRANG chứ không theo từng chỗ khớp: một slide chỉ có vài dòng chữ, nên
    /// nhảy tới từng chỗ khớp trong cùng một slide là nhảy tại chỗ.
    private func slides(containing needle: String) -> [Int] {
        guard !needle.isEmpty else { return [] }
        return deck.slides.enumerated().compactMap { index, slide in
            let text = slide.shapes.map(\.plainText).joined(separator: "\n")
            return text.range(
                of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                ? index : nil
        }
    }

    func matchCount(for needle: String) -> Int { slides(containing: needle).count }

    /// Slide đầu tiên chứa `needle`, đếm từ 0.
    func page(containing needle: String) -> Int? { slides(containing: needle).first }

    /// Slide thứ `ordinal` trong số những slide chứa `needle`.
    func page(containing needle: String, ordinal: Int) -> Int? {
        let found = slides(containing: needle)
        guard !found.isEmpty else { return nil }
        return found[((ordinal % found.count) + found.count) % found.count]
    }
}
