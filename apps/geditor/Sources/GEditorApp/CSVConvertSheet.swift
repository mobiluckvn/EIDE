import AppKit
import GEditorCore

/// Sheet chuyển đổi định dạng CSV, có bản xem trước (FR-CSV-406).
///
/// Xem trước NĂM hàng đầu trước khi tạo tab mới, đúng như UI/UX §6.1 đặt. Không phải để trang
/// trí: người dùng chọn "SQL INSERT" mà không biết tên bảng sẽ là gì, dấu bọc ra sao, cột nào
/// thành số — nhìn năm dòng là biết ngay, còn tạo xong một tab mười nghìn dòng rồi mới thấy
/// sai thì phải đóng đi làm lại.
///
/// Bản xem trước gọi ĐÚNG hàm sinh ra bản thật với `maxRows: 5`. Viết riêng một hàm rút gọn
/// cho ô xem trước là cách chắc chắn để nó nói dối đúng vào lúc người dùng tin nó.
///
/// Ô xem trước KHÔNG dùng `NSTextView`. Đã có một lỗi ngắt dòng ở đây: năm hàng TSV hiện
/// thành tám dòng, đo trong ứng dụng đang chạy ra `chuỗi=5 vẽ=8 frame=586 container=vô hạn`
/// — container khai là vô hạn mà bố cục vẫn ngắt theo bề ngang khung. Không cách nào trong
/// `maxSize` vô hạn · `isHorizontallyResizable` · `autoresizingMask = []` · dựng tường minh
/// chồng TextKit 1 gỡ được nó.
///
/// Ô này chỉ cần hiện năm dòng chữ đơn cách nên không nợ gì TextKit: một `NSTextField` nhiều
/// dòng, `wraps = false`, nằm trong scroll view là đủ và không có tầng nào tự ý bố trí lại.
/// Bề ngang khung không còn dính dáng gì tới chỗ chữ xuống dòng nữa — chỉ `\n` mới xuống dòng.
final class CSVConvertSheet: NSViewController {

    /// Ngưỡng mở kết quả thành tab mới.
    ///
    /// Tab mới giữ TOÀN BỘ kết quả trong bộ nhớ, và CSV sang XML thường phình ba tới bốn lần.
    /// Trên ngưỡng này thì chỉ cho ghi ra file — thà nói trước còn hơn để ứng dụng chết giữa
    /// chừng sau khi người dùng đã chờ.
    static let newTabSizeLimit = 64 * 1024 * 1024

    private let formatPopup = NSPopUpButton()

    /// Lề trong của ô xem trước, để chữ không dính sát viền khung.
    private static let previewInset: CGFloat = 6

    /// Ô xem trước: một nhãn nhiều dòng, không ngắt dòng.
    ///
    /// `wraps = false` cộng `maximumNumberOfLines = 0` cho ra đúng thứ cần: `\n` xuống dòng,
    /// còn bề ngang khung thì không. Kích thước do `sizePreviewToFit()` đặt tay, nên không có
    /// ràng buộc nào kéo nó co lại theo khung — chính chỗ ấy làm hỏng bản `NSTextView`.
    private let previewField: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.isSelectable = true
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = false
        return field
    }()

    /// Nền của ô xem trước, cũng là document view của scroll view.
    ///
    /// Phải LẬT (`isFlipped`) và phải phủ kín clip view: document view nhỏ hơn clip view thì
    /// AppKit dán nó vào GÓC DƯỚI, và bản xem trước hai dòng sẽ nằm lửng ở đáy khung.
    private let previewCanvas = PreviewCanvas()

    /// Scroll view bọc ô xem trước; giữ lại để biết bề ngang khả kiến lúc đo lại kích thước.
    private let previewScroll = NSScrollView()

    private let noteLabel = NSTextField(labelWithString: "")
    private let newTabButton = NSButton()
    private let saveButton = NSButton()

    private let buffer: TextBuffer
    private let dialect: CSVDialect
    private let tableName: String

    /// Người dùng chốt: định dạng và nơi đưa kết quả tới.
    enum Destination { case newTab, file }
    var onConvert: ((CSVExport.Format, Destination) -> Void)?

    init(buffer: TextBuffer, dialect: CSVDialect, tableName: String) {
        self.buffer = buffer
        self.dialect = dialect
        self.tableName = tableName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 420))

        let title = NSTextField(labelWithString: L("Chuyển đổi định dạng"))
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        formatPopup.addItems(withTitles: CSVExport.Format.allCases.map(\.displayName))
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        formatPopup.translatesAutoresizingMaskIntoConstraints = false

        let previewLabel = NSTextField(labelWithString: L("Xem trước 5 hàng đầu"))
        previewLabel.font = Tokens.Font.caption
        previewLabel.textColor = Tokens.Color.secondaryInk
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        previewCanvas.fillColor = Tokens.Color.editorBackground
        previewCanvas.addSubview(previewField)

        let scrollView = previewScroll
        scrollView.documentView = previewCanvas
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Tokens.Color.editorBackground
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        noteLabel.font = Tokens.Font.caption
        noteLabel.textColor = Tokens.Color.secondaryInk
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        newTabButton.title = L("Tạo tab mới")
        newTabButton.bezelStyle = .rounded
        newTabButton.keyEquivalent = "\r"
        newTabButton.target = self
        newTabButton.action = #selector(makeNewTab)
        newTabButton.translatesAutoresizingMaskIntoConstraints = false

        saveButton.title = L("Lưu ra file…")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveToFile)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton()
        cancel.title = "Hủy"
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.target = self
        cancel.action = #selector(cancelSheet)
        cancel.translatesAutoresizingMaskIntoConstraints = false

        for view in [title, formatPopup, previewLabel, scrollView, noteLabel,
                     newTabButton, saveButton, cancel] {
            root.addSubview(view)
        }

        let inset = Tokens.Metrics.spacing(4)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: inset),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),

            formatPopup.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            formatPopup.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            formatPopup.widthAnchor.constraint(equalToConstant: 260),

            previewLabel.topAnchor.constraint(equalTo: formatPopup.bottomAnchor, constant: 14),
            previewLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),

            scrollView.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            scrollView.heightAnchor.constraint(equalToConstant: 190),

            noteLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            noteLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            noteLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            cancel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            cancel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -inset),
            saveButton.trailingAnchor.constraint(equalTo: cancel.leadingAnchor, constant: -8),
            saveButton.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
            newTabButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            newTabButton.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
        ])

        view = root
        refreshPreview()
    }

    var selectedFormat: CSVExport.Format {
        let index = max(0, formatPopup.indexOfSelectedItem)
        return CSVExport.Format.allCases[min(index, CSVExport.Format.allCases.count - 1)]
    }

    @objc private func formatChanged() { refreshPreview() }

    /// Đặt chữ vào ô xem trước rồi đo lại khung cho vừa.
    private func setPreviewText(_ text: String) {
        previewField.attributedStringValue = NSAttributedString(
            string: text, attributes: Self.previewAttributes(lineBreak: .byClipping)
        )
        sizePreviewToFit()
    }

    /// Thuộc tính chữ của ô xem trước.
    ///
    /// Nấc tab đặt lại thành TÁM ký tự. Nấc mặc định của AppKit là 28pt — với chữ đơn cách cỡ
    /// 12 thì chưa đầy bốn ký tự, nên một ô vừa kết thúc sát nấc sẽ dính liền vào ô sau: ảnh
    /// chụp cho ra `Chin MuoiSo 123`, trông như bản TSV mất dấu phân tách. Bản xem trước có mặt
    /// để chỉ ra đúng hình dạng kết quả, nên nó không được tự tạo ra một hình dạng sai.
    static func previewAttributes(
        lineBreak: NSLineBreakMode
    ) -> [NSAttributedString.Key: Any] {
        let font = Tokens.Font.monoInline()
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = lineBreak
        style.tabStops = []
        style.defaultTabInterval = 8 * ("0" as NSString).size(withAttributes: [.font: font]).width
        return [.font: font, .foregroundColor: Tokens.Color.editorInk, .paragraphStyle: style]
    }

    /// Cho ô xem trước đúng khung mà chữ cần, rồi cho nền phủ kín phần còn lại.
    ///
    /// Ô được cấp đủ bề ngang cho dòng DÀI NHẤT, nên không tầng nào còn cớ để ngắt dòng; muốn
    /// đọc phần vượt ra ngoài thì cuộn ngang. Đo tay từng dòng rồi lấy giá trị lớn hơn so với
    /// `cellSize`: phép đo tay giữ đúng điều đang cần bảo đảm — một dòng văn bản là một dòng
    /// vẽ — còn `cellSize` biết những lề vụn của cell mà ta không nên đoán.
    private func sizePreviewToFit() {
        guard previewField.superview === previewCanvas else { return }
        let inset = Self.previewInset
        let measured = Self.measurePreview(previewField.attributedStringValue)
        var size = measured
        if let natural = previewField.cell?.cellSize,
           natural.width.isFinite, natural.height.isFinite {
            size.width = max(size.width, ceil(natural.width))
            size.height = max(size.height, ceil(natural.height))
        }
        previewField.frame = NSRect(x: inset, y: inset, width: size.width, height: size.height)

        let visible = previewScroll.contentView.bounds.size
        previewCanvas.frame = NSRect(
            x: 0, y: 0,
            width: max(previewField.frame.maxX + inset, visible.width),
            height: max(previewField.frame.maxY + inset, visible.height)
        )
    }

    /// Bề ngang của dòng dài nhất và bề cao của đúng ngần ấy dòng.
    ///
    /// Đo bằng CHÍNH thuộc tính của chuỗi, kể cả nấc tab: đo bằng riêng font sẽ ra hẹp hơn thực
    /// tế ở mọi dòng có tab, và ô hẹp hơn chữ thì cắt mất phần cuối — không ngắt dòng nhưng vẫn
    /// là mất chữ.
    static func measurePreview(_ text: NSAttributedString) -> NSSize {
        let attributes = text.length > 0
            ? text.attributes(at: 0, effectiveRange: nil)
            : previewAttributes(lineBreak: .byClipping)
        let font = attributes[.font] as? NSFont ?? Tokens.Font.monoInline()
        let lines = text.string.components(separatedBy: "\n")
        let width = lines.reduce(CGFloat.zero) {
            max($0, ($1 as NSString).size(withAttributes: attributes).width)
        }
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        return NSSize(width: ceil(width) + 2, height: lineHeight * CGFloat(lines.count))
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Khung rộng ra thì nền phải rộng theo, nếu không sẽ hở một dải xám bên phải.
        sizePreviewToFit()
    }

    private func refreshPreview() {
        let format = selectedFormat
        let text: String
        do {
            text = try CSVExport.convert(
                buffer, dialect: dialect, to: format, tableName: tableName, maxRows: 5
            )
        } catch {
            text = "Không dựng được bản xem trước: \(error)"
        }
        setPreviewText(text)

        let tooBig = buffer.count > Self.newTabSizeLimit
        newTabButton.isEnabled = !tooBig
        noteLabel.stringValue = tooBig
            ? "Tài liệu lớn hơn \(Self.newTabSizeLimit / 1024 / 1024) MB — kết quả chỉ ghi được ra file, vì tab mới phải giữ toàn bộ trong bộ nhớ."
            : L("Kết quả mở thành tab mới, chưa lưu. Tài liệu gốc không đổi.")
    }

    @objc private func makeNewTab() { finish(.newTab) }
    @objc private func saveToFile() { finish(.file) }

    @objc private func cancelSheet() {
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .cancel) }
    }

    private func finish(_ destination: Destination) {
        let format = selectedFormat
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .OK) }
        onConvert?(format, destination)
    }

    // MARK: - Móc tự kiểm

    var previewTextForSelfTest: String { previewField.stringValue }

    /// Đếm số dòng chữ THỰC SỰ ĐƯỢC VẼ trong ô xem trước.
    ///
    /// Vẽ ô ra một tấm bitmap, tìm hàng điểm ảnh có mực đầu tiên và cuối cùng, rồi chia chiều
    /// cao vệt mực cho chiều cao một dòng. Hỏi AppKit "anh định bố trí thế nào" là cách đã cho
    /// ra bài kiểm xanh trong khi ứng dụng thật ngắt dòng — chính phép hỏi đã đổi bộ máy bố
    /// trí trước khi đo. Ở đây chỉ đo thứ đã nằm trên tấm bitmap.
    ///
    /// Đo VỆT MỰC chứ không đếm từng dải: gạch dưới trong `dia_chi` rơi xuống dưới đường chân
    /// chữ và tách thành một dải riêng, nên phép đếm dải báo 6 dòng cho 5 hàng. Khoảng cách
    /// giữa hai dòng thì không nhập nhằng như vậy.
    func drawnPreviewLineCountForSelfTest() -> Int {
        let bounds = previewField.bounds
        guard bounds.width >= 1, bounds.height >= 1,
              let rep = previewField.bitmapImageRepForCachingDisplay(in: bounds)
        else { return -1 }
        previewField.cacheDisplay(in: bounds, to: rep)

        var firstInked = -1
        var lastInked = -1
        for y in 0..<rep.pixelsHigh {
            var inked = false
            for x in 0..<rep.pixelsWide where rep.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.3 {
                inked = true
                break
            }
            if inked {
                if firstInked < 0 { firstInked = y }
                lastInked = y
            }
        }
        guard firstInked >= 0 else { return 0 }

        let scale = CGFloat(rep.pixelsHigh) / bounds.height
        let inkHeight = CGFloat(lastInked - firstInked + 1) / max(scale, 1)
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: Tokens.Font.monoInline()))
        // Vệt mực của N dòng cao (N-1) dòng cộng thân chữ của dòng cuối — thân chữ luôn thấp
        // hơn một dòng, nên làm tròn ra đúng N.
        return max(1, Int((inkHeight / lineHeight).rounded()))
    }

    /// Bẻ ô xem trước về đúng cấu hình HỎNG cũ: ngắt dòng theo bề ngang khung.
    ///
    /// Có mặt để bài kiểm tự đo lại cái thước của nó. Một bài kiểm ngắt dòng chỉ đáng tin khi
    /// nó ĐỎ được — bài trước đây xanh với mọi cấu hình nên chẳng khẳng định được gì.
    func forcePreviewWrapForSelfTest(width: CGFloat) {
        previewField.cell?.wraps = true
        previewField.lineBreakMode = .byWordWrapping
        previewField.attributedStringValue = NSAttributedString(
            string: previewField.stringValue,
            attributes: Self.previewAttributes(lineBreak: .byWordWrapping)
        )
        previewField.frame = NSRect(x: Self.previewInset, y: Self.previewInset,
                                    width: width, height: 400)
    }

    /// Trả ô xem trước về cấu hình thật sau khi bẻ.
    func restorePreviewForSelfTest() {
        previewField.cell?.wraps = false
        previewField.lineBreakMode = .byClipping
        refreshPreview()
    }

    /// Bề ngang khả kiến của khung xem trước — bề ngang mà bản hỏng cũ ngắt dòng theo.
    var previewVisibleWidthForSelfTest: CGFloat { previewScroll.contentView.bounds.width }

    /// Bề ngang cuộn được của ô xem trước, tính cả phần nằm ngoài khung.
    var previewScrollableWidthForSelfTest: CGFloat { previewCanvas.frame.width }

    /// Bề ngang mà dòng dài nhất cần để hiện đủ.
    var previewNeededWidthForSelfTest: CGFloat { previewField.frame.maxX }

    var newTabEnabledForSelfTest: Bool { newTabButton.isEnabled }
    var noteForSelfTest: String { noteLabel.stringValue }
    func selectFormatForSelfTest(_ format: CSVExport.Format) {
        guard let index = CSVExport.Format.allCases.firstIndex(of: format) else { return }
        formatPopup.selectItem(at: index)
        formatChanged()
    }
    /// Cửa sổ giữ sheet trong lúc tự kiểm.
    ///
    /// Phải có cửa sổ THẬT, không chỉ gọi `_ = view`: ngoài cửa sổ thì ô xem trước không có bề
    /// ngang nào để mà ngắt dòng, nên bài kiểm ngắt dòng xanh với mọi cấu hình. Đã đúng như
    /// vậy ở bản đầu — bài kiểm không kiểm được gì cho tới khi có chỗ này.
    private var selfTestWindow: NSWindow?

    func loadViewForSelfTest() {
        guard selfTestWindow == nil else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentViewController = self
        window.layoutIfNeeded()
        selfTestWindow = window
    }
}

/// Nền của ô xem trước: lật trục dọc và tự tô màu nền soạn thảo.
///
/// Lật vì chữ phải bắt đầu từ mép TRÊN; tự tô vì clip view để lộ màu xám hệ thống ở phần
/// document view chưa có gì, và bản xem trước trông như bị cắt đôi.
private final class PreviewCanvas: NSView {
    var fillColor: NSColor = .textBackgroundColor
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()
    }
}
