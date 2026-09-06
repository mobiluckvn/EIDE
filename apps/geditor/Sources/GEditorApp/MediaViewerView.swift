import AppKit
import GEditorCore

/// Khung xem cho tài liệu KHÔNG phải văn bản — ảnh, PDF, Office, file nén.
///
/// **Nằm ĐÈ lên vùng soạn thảo, không nằm cạnh.** Cùng luật với bảng CSV: hai cách xem của
/// cùng một tab thì chỉ một cái được hiện. Đặt cạnh nhau sẽ chia đôi bề ngang cho một khung
/// luôn rỗng — tài liệu media không có gì để hiện ở khung soạn thảo.
///
/// **Một container, nhiều ruột.** Mỗi loại có khung riêng (`ImageViewerView`,
/// `PDFViewerView`, `ArchiveViewerView`), và container này chỉ lo việc thay ruột với dựng
/// thanh tiêu đề chung. Gộp cả bốn vào một view sẽ thành một `switch` khổng lồ mà mỗi nhánh
/// lại cần bộ điều khiển riêng.
final class MediaViewerView: NSView {

    /// Mở một nội dung văn bản thành tab mới — dùng khi người dùng lấy chữ ra khỏi PDF, hoặc
    /// mở một mục văn bản trong file nén.
    var onOpenTextInNewTab: ((String, String) -> Void)?
    /// Mở một tệp trên đĩa thành tab mới (mục vừa bung ra khỏi file nén).
    var onOpenFile: ((String) -> Void)?
    var onStatus: ((String) -> Void)?

    private let header = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let body = NSView()
    private var current: NSView?

    private(set) var path: String?
    private(set) var kind: MediaKind?

    /// Hai cách nhìn cùng một tệp.
    ///
    /// KHÔNG phải hai khung đặt cạnh nhau: một tệp media không có gì để hiện ở nửa còn lại, và
    /// chia đôi bề ngang cho một khung rỗng là lấy mất chỗ của khung đang có việc. Cùng luật với
    /// bảng CSV và vùng soạn thảo.
    enum DisplayMode { case normal, hex }

    private(set) var mode: DisplayMode = .normal
    private let modeButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyLayerBackground(Tokens.Color.editorBackground)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        header.applyLayerBackground(Tokens.Color.chrome)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        detailLabel.font = Tokens.Font.caption
        detailLabel.textColor = Tokens.Color.secondaryInk
        modeButton.bezelStyle = .rounded
        modeButton.controlSize = .small
        modeButton.font = Tokens.Font.caption
        modeButton.target = self
        modeButton.action = #selector(toggleMode)
        modeButton.title = L("Xem nhị phân")

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        modeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        header.addSubview(modeButton)

        body.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(body)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 30),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            modeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -10),
            modeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Thay ruột

    /// Mở một tệp.
    ///
    /// `kind` là `nil` khi người dùng chủ động xin xem nhị phân một tệp VĂN BẢN — lúc ấy không
    /// có loại media nào để chọn khung, và chế độ nhị phân là chế độ duy nhất.
    func show(path: String, kind: MediaKind?, mode: DisplayMode = .normal) {
        self.path = path
        self.kind = kind
        self.mode = kind == nil ? .hex : mode
        titleLabel.stringValue = (path as NSString).lastPathComponent

        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? nil
        detailLabel.stringValue = [kind.map { L($0.displayName) }, size.map(Self.humanSize)]
            .compactMap { $0 }.joined(separator: "  ·  ")
        // Tệp văn bản xem nhị phân thì KHÔNG có đường quay lại trong khung này — đường về là
        // chính lệnh trên menu, và một nút bấm vào không có gì xảy ra thì tệ hơn không có nút.
        modeButton.isHidden = kind == nil
        rebuildBody()
    }

    /// Lật giữa xem thường và xem nhị phân.
    ///
    /// Trả `false` khi tệp KHÔNG phải media — với một tệp văn bản, đường về không nằm trong
    /// khung này mà là vùng soạn thảo, và chỗ quyết định điều đó là cửa sổ chứ không phải đây.
    @discardableResult
    func toggleBinaryMode() -> Bool {
        guard kind != nil else { return false }
        toggleMode(nil)
        return true
    }

    @objc private func toggleMode(_ sender: Any?) {
        mode = mode == .normal ? .hex : .normal
        rebuildBody()
    }

    private func rebuildBody() {
        guard let path else { return }
        modeButton.title = mode == .normal ? L("Xem nhị phân") : L("Xem bình thường")

        // Dừng nhạc/phim TRƯỚC khi gỡ khung. Gỡ view không dừng `AVPlayer` — nó giữ tham chiếu
        // riêng, và hậu quả là bấm "Xem nhị phân" xong tiếng vẫn chạy sau lưng.
        (current as? MediaPlayerView)?.stop()
        current?.removeFromSuperview()

        guard mode == .normal, let kind else {
            let viewer = HexViewerView()
            viewer.onStatus = { [weak self] in self?.detailLabel.stringValue = $0 }
            viewer.load(path: path)
            attach(viewer)
            return
        }
        attach(bodyView(for: path, kind: kind))
    }

    private func attach(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: body.topAnchor),
            view.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: body.bottomAnchor),
        ])
        current = view
    }

    private func bodyView(for path: String, kind: MediaKind) -> NSView {
        let view: NSView
        switch kind {
        case .image:
            let viewer = ImageViewerView()
            viewer.onStatus = { [weak self] in self?.detailLabel.stringValue = $0 }
            viewer.load(path: path)
            view = viewer
        case .pdf:
            let viewer = PDFViewerView()
            viewer.onStatus = { [weak self] in self?.detailLabel.stringValue = $0 }
            viewer.onOpenTextInNewTab = { [weak self] text, label in
                self?.onOpenTextInNewTab?(text, label)
            }
            viewer.load(path: path)
            view = viewer
        case .archive, .word, .excel, .powerpoint:
            // Office cũng vào đây: ruột của chúng LÀ file nén, nên trong khi bộ đọc OOXML còn
            // đang làm, người dùng vẫn mở được tệp và lấy được phần bên trong ra — hơn hẳn một
            // thông báo "chưa hỗ trợ".
            let viewer = ArchiveViewerView()
            viewer.onStatus = { [weak self] in self?.detailLabel.stringValue = $0 }
            viewer.onOpenTextInNewTab = { [weak self] text, label in
                self?.onOpenTextInNewTab?(text, label)
            }
            viewer.onOpenFile = { [weak self] in self?.onOpenFile?($0) }
            viewer.load(path: path, kind: kind)
            view = viewer
        case .audio, .video:
            let viewer = MediaPlayerView()
            viewer.onStatus = { [weak self] in self?.detailLabel.stringValue = $0 }
            // Không phát được thì khung phát mời sang chế độ nhị phân — và chỗ ấy phải đi qua
            // ĐÚNG lối bật/tắt của container, không dựng riêng một khung hex thứ hai.
            viewer.onRequestHexView = { [weak self] in
                guard let self, self.mode == .normal else { return }
                self.toggleMode(nil)
            }
            viewer.load(path: path, kind: kind)
            view = viewer
        }
        return view
    }

    func clear() {
        current?.removeFromSuperview()
        current = nil
        path = nil
        kind = nil
    }

    /// Khung con đang hiện — để bài tự kiểm hỏi đúng thứ đang trên màn hình.
    var contentForSelfTest: NSView? { current }

    static func humanSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        return unit == 0
            ? "\(bytes) B"
            : String(format: "%.1f %@", value, units[unit])
    }
}

// MARK: - Ảnh

/// Khung xem ảnh — phóng to, thu nhỏ, vừa khung, kích thước thật, xoay.
///
/// **Dùng `NSImageView` chứ không tự vẽ.** Tự vẽ thì mất hoạt ảnh GIF, mất quản lý bộ nhớ theo
/// tỉ lệ của AppKit, và phải tự làm lại phần nội suy khi phóng to. Đổi lại chỉ mất quyền kiểm
/// soát vài chi tiết mà không ai đòi.
///
/// **Ảnh mở ra ở chế độ VỪA KHUNG, không phải 100%.** Ảnh chụp màn hình 5K mở ở 100% trong một
/// cửa sổ 1200 điểm chỉ hiện đúng góc trên bên trái — người dùng thấy một mảng màu và không
/// biết mình đang nhìn cái gì.
final class ImageViewerView: NSView {

    var onStatus: ((String) -> Void)?

    private let scroll = NSScrollView()
    private let imageView = NSImageView()
    private let toolbar = NSStackView()
    private var image: NSImage?
    private var zoom: CGFloat = 1
    private var rotation = 0
    private let zoomLabel = NSTextField(labelWithString: "")
    private let playButton = NSButton()
    /// Số khung của ảnh động; 1 nghĩa là ảnh tĩnh.
    private(set) var frameCount = 1

    /// Các mức phóng rời rạc. Nhân/chia liên tục cho 1,25 sẽ ra những con số như 137% mà không
    /// ai muốn đọc; một thang cố định luôn về được đúng 100%.
    private static let zoomSteps: [CGFloat] = [0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 16]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true          // GIF động vẫn phải động
        imageView.imageAlignment = .alignCenter

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = Tokens.Color.editorBackground
        scroll.documentView = imageView
        // Cuộn bằng hai ngón vẫn cuộn; ⌘ + lăn thì phóng — xem `scrollWheel`.
        scroll.allowsMagnification = false

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        zoomLabel.font = Tokens.Font.caption
        zoomLabel.textColor = Tokens.Color.secondaryInk
        for (title, action) in [
            ("−", #selector(zoomOut)), ("+", #selector(zoomIn)),
            (L("Vừa khung"), #selector(zoomToFit)), ("100%", #selector(zoomActual)),
            (L("Xoay"), #selector(rotateQuarterTurn)), (L("Chép ảnh"), #selector(copyImage)),
        ] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            toolbar.addArrangedSubview(button)
        }
        // Nút phát chỉ hiện với ảnh NHIỀU KHUNG. Một nút "Tạm dừng" trên ảnh tĩnh là một nút
        // bấm vào không có gì xảy ra — thứ dạy người dùng rằng giao diện này không đáng tin.
        playButton.bezelStyle = .rounded
        playButton.font = Tokens.Font.caption
        playButton.target = self
        playButton.action = #selector(togglePlayback)
        playButton.isHidden = true
        toolbar.addArrangedSubview(playButton)
        toolbar.addArrangedSubview(zoomLabel)

        addSubview(scroll)
        addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func load(path: String) {
        guard let loaded = NSImage(contentsOfFile: path) else {
            onStatus?(LF("Không đọc được ảnh «%@»",
                             (path as NSString).lastPathComponent))
            return
        }
        image = loaded
        rotation = 0
        imageView.image = loaded

        // Số khung hỏi THẲNG bộ đọc ảnh, không suy từ đuôi tệp: `.png` có thể là APNG động,
        // `.webp` có thể động hoặc tĩnh, và `.gif` một khung thì vẫn là ảnh tĩnh.
        frameCount = Self.frameCount(of: loaded)
        playButton.isHidden = frameCount <= 1
        imageView.animates = frameCount > 1
        playButton.title = L("Tạm dừng")
        if frameCount > 1 {
            onStatus?(LF("Ảnh động · %d khung", frameCount))
        }
        // Bố cục có thể chưa chạy lúc này (view vừa được gắn vào cửa sổ), nên `bounds` còn
        // bằng 0 và phép tính "vừa khung" sẽ ra tỉ lệ vô nghĩa. Hoãn một nhịp.
        DispatchQueue.main.async { [weak self] in self?.zoomToFit(nil) }
    }

    /// Số khung của một ảnh — 1 với ảnh tĩnh.
    ///
    /// Đọc từ `NSBitmapImageRep`, tức từ chính bộ giải mã ảnh của hệ điều hành. Nhờ vậy APNG,
    /// GIF động và WebP động đều trả lời đúng bằng một đường, không phải mỗi định dạng một nhánh.
    static func frameCount(of image: NSImage) -> Int {
        for rep in image.representations {
            guard let bitmap = rep as? NSBitmapImageRep,
                  let frames = bitmap.value(forProperty: .frameCount) as? Int
            else { continue }
            return max(1, frames)
        }
        return 1
    }

    @objc private func togglePlayback(_ sender: Any?) {
        guard frameCount > 1 else { return }
        imageView.animates.toggle()
        playButton.title = imageView.animates ? L("Tạm dừng") : L("Phát")
    }

    /// Kích thước ĐIỂM ẢNH thật, không phải kích thước điểm của AppKit.
    ///
    /// Với ảnh Retina (`@2x`) hai con số này khác nhau gấp đôi, và con số người dùng muốn biết
    /// là số điểm ảnh — đó là thứ ghi trong mọi công cụ khác.
    private var pixelSize: NSSize {
        guard let image else { return .zero }
        if let rep = image.representations.first {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }

    var isAnimatingForSelfTest: Bool { imageView.animates }
    var frameCountForSelfTest: Int { frameCount }
    func togglePlaybackForSelfTest() { togglePlayback(nil) }

    private func applyZoom() {
        guard let image else { return }
        let base = pixelSize
        let swapped = rotation % 180 != 0
        let width = (swapped ? base.height : base.width) * zoom
        let height = (swapped ? base.width : base.height) * zoom
        imageView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        imageView.image = rotation == 0 ? image : Self.rotated(image, degrees: rotation)
        zoomLabel.stringValue = String(format: "%.0f%%  ·  %d × %d",
                                       zoom * 100, Int(base.width), Int(base.height))
    }

    @objc private func zoomIn(_ sender: Any?) {
        zoom = Self.zoomSteps.first { $0 > zoom + 0.001 } ?? Self.zoomSteps.last!
        applyZoom()
    }

    @objc private func zoomOut(_ sender: Any?) {
        zoom = Self.zoomSteps.last { $0 < zoom - 0.001 } ?? Self.zoomSteps.first!
        applyZoom()
    }

    @objc private func zoomActual(_ sender: Any?) {
        zoom = 1
        applyZoom()
    }

    @objc func zoomToFit(_ sender: Any?) {
        let base = pixelSize
        guard base.width > 0, base.height > 0 else { return }
        let available = scroll.contentSize
        guard available.width > 1, available.height > 1 else { return }
        let swapped = rotation % 180 != 0
        let w = swapped ? base.height : base.width
        let h = swapped ? base.width : base.height
        // Ảnh nhỏ hơn khung thì để nguyên 100% — phóng một biểu tượng 16×16 lên kín màn hình
        // là biến nó thành một mảng ô vuông mờ.
        zoom = min(1, min(available.width / w, available.height / h))
        applyZoom()
    }

    @objc private func rotateQuarterTurn(_ sender: Any?) {
        rotation = (rotation + 90) % 360
        applyZoom()
    }

    @objc private func copyImage(_ sender: Any?) {
        guard let image = imageView.image else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        onStatus?(L("Đã chép ảnh vào clipboard"))
    }

    /// ⌘ + lăn chuột để phóng, đúng thói quen của Preview.
    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { return super.scrollWheel(with: event) }
        if event.scrollingDeltaY > 0 { zoomIn(nil) } else if event.scrollingDeltaY < 0 { zoomOut(nil) }
    }

    private static func rotated(_ image: NSImage, degrees: Int) -> NSImage {
        let size = image.size
        let swapped = degrees % 180 != 0
        let target = NSSize(width: swapped ? size.height : size.width,
                            height: swapped ? size.width : size.height)
        let out = NSImage(size: target)
        out.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: target.width / 2, yBy: target.height / 2)
        transform.rotate(byDegrees: CGFloat(-degrees))
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size),
                   operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }

    // MARK: - Cho bài tự kiểm

    var zoomForSelfTest: CGFloat { zoom }
    var pixelSizeForSelfTest: NSSize { pixelSize }
    var hasImageForSelfTest: Bool { image != nil }
    func zoomInForSelfTest() { zoomIn(nil) }
    func zoomOutForSelfTest() { zoomOut(nil) }
    func rotateForSelfTest() { rotateQuarterTurn(nil) }
    var rotationForSelfTest: Int { rotation }
}
