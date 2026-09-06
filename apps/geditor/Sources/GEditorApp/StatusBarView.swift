import AppKit
import GEditorCore

/// Status bar tương tác (FR-UI-805, P0).
///
/// Hai yêu cầu đi kèm nhau:
///  - Trạng thái LUÔN đọc được: encoding, EOL, ngôn ngữ, chế độ (LFM/CSV/Monitoring),
///    vị trí caret, thống kê vùng chọn (NT-5, FR-CORE-018).
///  - Mỗi mục CLICK ĐƯỢC để đổi nhanh — đây là điểm khác biệt so với status bar
///    chỉ-đọc của các editor khác (UI/UX §3).
final class StatusBarView: NSView {

    struct State: Equatable {
        var caretLine = 1
        var caretColumn = 1
        /// Cột đang là con số ƯỚC LƯỢNG (đếm byte) chứ không phải cột thị giác thật.
        ///
        /// Chỉ xảy ra trên dòng cực dài — xem `MainWindowController.updateCaretStatus`. Có cờ
        /// này để nhãn nói ra, thay vì hiện một con số trông y hệt mà nghĩa đã khác.
        var caretColumnIsApproximate = false
        /// Vị trí BYTE của con nháy — SRS FR-CORE-018 đòi «offset» bên cạnh dòng và cột.
        ///
        /// Cần thật, không phải cho đủ mục: mọi công cụ khác của sản phẩm nói bằng offset —
        /// lỗi JSON/XML, kết quả `--doc-sweep`, ô «Đi tới @1024», khung xem nhị phân. Không có
        /// con số này trên thanh thì người dùng không có cách nào bắc cầu giữa chúng và chỗ
        /// con nháy đang đứng.
        var caretOffset = 0
        var selectionSummary: String?
        /// Cỡ tài liệu: số byte và số dòng.
        var documentBytes = 0
        var documentLines = 1
        var encoding = "UTF-8"
        var eol = EOL.lf
        var language = L("Văn bản thuần")
        var isReadOnly = false
        var mode: String?          // "CSV · dấu phẩy", "Large File Mode", L("Đang theo dõi")
        var tabWidth = 4
        /// Chế độ ngắt dòng mềm đang bật (FR-CORE-015).
        var wrapMode = WrapMode.off
        /// Cột dùng cho chế độ "ngắt tại cột"; nhớ lại khi vòng qua chế độ ấy lần sau.
        var wrapColumn = 80

        /// Chế độ hiển thị đang bật, và tệp này có đổi được không — NFR-USE-01.
        ///
        /// **Vì sao nó phải nằm trên thanh trạng thái.** Chế độ View/Code trước đây chỉ có MỘT
        /// lối vào: mục menu `Xem ▸ Đổi chế độ View / Code` (⌥⌘V). Một người dùng mở tệp JSON
        /// lên sẽ không bao giờ biết là có một cây khoá–giá trị đang chờ họ — và người lỡ bấm
        /// vào đó cũng không thấy đường quay lại. Tính năng chạy được mà không ai tìm ra thì với
        /// người dùng nó không tồn tại.
        ///
        /// Thanh trạng thái là chỗ đúng vì sản phẩm đã dạy người dùng bấm vào nó: bảng mã, kiểu
        /// xuống dòng, ngôn ngữ, ngắt dòng đều đổi được bằng một cú bấm ở đây.
        var displayMode = DisplayViewLabel.codeOnly
    }

    /// Trạng thái đang hiện. Gán lại mà nội dung y hệt thì KHÔNG đụng gì tới giao diện.
    ///
    /// `updateCaretStatus()` chạy sau mỗi lần sửa và mỗi lần con nháy nhúc nhích, và phần lớn
    /// những lần ấy không đổi một chữ nào trên thanh. So sánh rẻ hơn vẽ lại rất nhiều.
    var state = State() {
        didSet {
            guard state != oldValue else { return }
            apply()
        }
    }

    /// Bộ xử lý khi người dùng click một mục — lớp trên mở menu đổi nhanh.
    var onSegmentClick: ((Segment) -> Void)?

    enum Segment {
        case caret, docSize, encoding, eol, language, mode, readOnly, tabWidth, wrap, viewCode
    }

    /// HAI stack neo về hai mép, không phải một stack với spacer ở giữa.
    ///
    /// Bản đầu dùng một `NSStackView` và chèn một `NSView` rỗng làm spacer. `NSView` rỗng
    /// không có kích thước nội tại nên stack cho nó co giãn tự do: nó nuốt hết chiều rộng và
    /// đẩy mọi mục bên phải (bảng mã, EOL, ngôn ngữ, tab) ra ngoài khung nhìn. Lỗi này KHÔNG
    /// thấy được khi đọc mã — chỉ lộ ra khi chạy app và nhìn vào status bar.
    private let leading = NSStackView()
    private let trailing = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        wantsLayer = true
        for stack in [leading, trailing] {
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = Tokens.Metrics.spacing(3)
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
        }

        let inset = Tokens.Metrics.spacing(3)
        NSLayoutConstraint.activate([
            leading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            leading.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor),
            // Bên trái nhường chỗ khi cửa sổ hẹp: trạng thái ở bên phải quan trọng hơn vị trí
            // con trỏ, vì đó là nơi người dùng đọc bảng mã trước khi lưu.
            trailing.leadingAnchor.constraint(
                greaterThanOrEqualTo: leading.trailingAnchor, constant: inset
            ),
            heightAnchor.constraint(equalToConstant: Tokens.Metrics.statusBarHeight),
        ])
        buildSegments()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Cao độ: panel neo không dùng bóng, phân tách bằng đường 1 px (UI/UX §2.3).
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
    }

    /// Con số cột như người dùng sẽ đọc.
    ///
    /// Dấu `~` khi đó là ước lượng. Một con số trông y hệt mà nghĩa đã đổi là kiểu nói dối khó
    /// phát hiện nhất — người dùng không có cách nào biết.
    private var caretColumnText: String {
        state.caretColumnIsApproximate ? "~\(state.caretColumn)" : "\(state.caretColumn)"
    }

    /// Các nút của thanh, dựng ĐÚNG MỘT LẦN và dùng lại mãi.
    ///
    /// **Vì sao không dựng lại mỗi lần trạng thái đổi.** Bản đầu vứt hết `arrangedSubviews` rồi
    /// tạo tám `NSButton` mới ở mỗi lần gán `state` — mà `state` được gán sau mỗi lần sửa và
    /// mỗi lần con nháy nhúc nhích. Mỗi `NSButton` mới kéo theo cả một chùm đăng ký KVO của
    /// AppKit (`NSKeyValueDependency`, `NSKeyValueDependencyContext` và các block đi kèm), và
    /// chúng KHÔNG được thu lại khi nút rời khỏi cây view.
    ///
    /// Bộ chạy dài `--soak` đo được cái giá ấy (NFR-REL-03): sau 4.000 thao tác sửa, heap giữ
    /// **226.000 `NSKeyValueDependency` · 224.000 `__NSMallocBlock__` · 223.000
    /// `__NSExactBlockVariable__`** — khoảng 36 MB chỉ riêng bốn lớp ấy, và bộ nhớ tiến trình
    /// leo tuyến tính ~11 KB mỗi thao tác, tới 191 MB sau 15.000 thao tác (trần RAM nhàn rỗi
    /// của NFR-PERF-05 là 80 MB).
    ///
    /// Cách tìm ra đáng ghi lại, vì đọc mã KHÔNG ra: `heap <pid>` chỉ ra lớp nào chiếm chỗ, rồi
    /// `MallocStackLogging=1` + `malloc_history <pid> <địa-chỉ>` chỉ thẳng ra
    /// `StatusBarView.rebuild()`. Thanh trạng thái là chỗ cuối cùng người ta ngờ tới khi thấy
    /// bộ nhớ phình — nó chỉ có mấy con số.
    private lazy var segments: [Segment: NSButton] = {
        var made: [Segment: NSButton] = [:]
        // Danh sách này và danh sách xếp chỗ ở `buildSegments` phải khớp nhau. Thêm vào một
        // chỗ mà quên chỗ kia thì mục ấy KHÔNG BAO GIỜ hiện, và không có gì báo — đúng chuyện
        // vừa xảy ra với mục View/Code.
        for segment in [Segment.caret, .docSize, .readOnly, .viewCode, .mode, .encoding, .eol,
                        .language, .tabWidth, .wrap] {
            made[segment] = makeSegment("", segment: segment)
        }
        made[.readOnly]?.contentTintColor = Tokens.Color.ember
        made[.mode]?.contentTintColor = Tokens.Color.action
        return made
    }()

    /// Dựng cây view một lần. Thứ tự ở đây là thứ tự trên màn hình.
    private func buildSegments() {
        if let caret = segments[.caret] { leading.addArrangedSubview(caret) }
        // Cỡ tài liệu đứng cạnh vị trí con nháy: cả hai trả lời cùng một câu hỏi — "tôi đang ở
        // đâu, trong một thứ dài bao nhiêu".
        if let size = segments[.docSize] { leading.addArrangedSubview(size) }
        for segment in [Segment.readOnly, .viewCode, .mode, .encoding, .eol, .language,
                        .tabWidth, .wrap] {
            if let button = segments[segment] { trailing.addArrangedSubview(button) }
        }
        apply()
    }

    /// Đổ trạng thái vào các nút đã có. KHÔNG tạo, KHÔNG xoá view nào.
    ///
    /// Hai mục có thể vắng mặt (chỉ đọc, chế độ) thì ẩn đi chứ không gỡ ra: `NSStackView` thu
    /// hồi chỗ của một `arrangedSubview` đang ẩn, nên nhìn vẫn y hệt lúc gỡ hẳn.
    private func apply() {
        // «@340» chứ không phải «Vị trí 340»: cùng ký hiệu với ô «Đi tới @340», nên con số đọc
        // được ở đây gõ thẳng vào đó được, không phải học hai cách viết cho một thứ.
        var caretText = "Dòng \(state.caretLine), Cột \(caretColumnText) · @\(state.caretOffset)"
        if let summary = state.selectionSummary {
            caretText += " · \(summary)"
        }
        setTitle(caretText, on: .caret)

        setTitle(LF("%d byte · %d dòng", state.documentBytes, state.documentLines), on: .docSize)

        setTitle(L("🔒 Chỉ đọc"), on: .readOnly)
        segments[.readOnly]?.isHidden = !state.isReadOnly

        setTitle(state.mode ?? "", on: .mode)
        segments[.mode]?.isHidden = state.mode == nil

        setTitle(state.encoding, on: .encoding)
        setTitle(state.eol.rawValue, on: .eol)
        setTitle(state.language, on: .language)
        setTitle("Tab: \(state.tabWidth)", on: .tabWidth)
        // Ngắt dòng phải NHÌN THẤY được: nó đổi cách đọc cả file mà không đổi một byte nội
        // dung nào, nên không có chỗ nào khác để biết nó đang bật.
        setTitle("Ngắt: \(state.wrapMode.displayName)", on: .wrap)

        // Mũi tên hai chiều là thứ nói "bấm được" mà không tốn một chữ nào — và nó VẮNG khi tệp
        // chỉ có một chế độ, nên hình dạng của nhãn tự phân biệt hai ca.
        if let button = segments[.viewCode] {
            button.attributedTitle = state.displayMode.attributedTitle(
                active: Tokens.Color.action, inactive: Tokens.Color.secondaryInk)
            button.toolTip = state.displayMode.tooltip
            button.isEnabled = state.displayMode.canToggle
            // Màu nói chế độ nào đang bật, nhưng VoiceOver không đọc được màu — nên nhãn trợ
            // năng phải nói ra bằng chữ (NFR-USE-03).
            button.setAccessibilityLabel(
                state.displayMode.title + " — " + state.displayMode.spokenState)
        }
    }

    private func setTitle(_ title: String, on segment: Segment) {
        guard let button = segments[segment], button.title != title else { return }
        button.title = title
        // VoiceOver phải đọc được từng mục trạng thái (NFR-USE-03). Nhãn đi kèm chữ, nên nó
        // phải được đổi ở ĐÂY — để nó lại trong hàm dựng thì thanh sẽ đọc một đằng hiện một nẻo.
        button.setAccessibilityLabel(title)
    }

    private func makeSegment(_ title: String, segment: Segment) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(segmentClicked(_:)))
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = Tokens.Font.caption
        button.setButtonType(.momentaryChange)
        button.identifier = NSUserInterfaceItemIdentifier(String(describing: segment))
        // VoiceOver phải đọc được từng mục trạng thái (NFR-USE-03).
        button.setAccessibilityLabel(title)
        // Hai mục bên trái phải NHƯỜNG CHỖ khi cửa sổ hẹp lại.
        //
        // Bài kiểm ngắt dòng bắt được khi mục «cỡ tài liệu» vừa ra đời: thanh trạng thái không
        // co được nữa, nên bề rộng tối thiểu của CẢ CỬA SỔ nhích lên và người dùng mất khả
        // năng thu hẹp cửa sổ như trước. Một mục thông tin không được quyết định cửa sổ hẹp
        // tới đâu.
        if segment == .caret || segment == .docSize {
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            button.cell?.lineBreakMode = .byTruncatingTail
        }
        return button
    }

    @objc private func segmentClicked(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue else { return }
        let mapping: [String: Segment] = [
            "caret": .caret, "docSize": .docSize, "encoding": .encoding, "eol": .eol,
            "language": .language, "mode": .mode, "readOnly": .readOnly, "tabWidth": .tabWidth,
            "wrap": .wrap, "viewCode": .viewCode,
        ]
        if let segment = mapping[raw] { onSegmentClick?(segment) }
    }

    // MARK: - Móc tự kiểm

    /// Từng mục của thanh: TÊN, danh tính đối tượng, chữ đang hiện, đang ẩn hay không.
    ///
    /// Trả cả bốn thứ trong một lần vì bài kiểm cần cả hai vế: view phải là ĐÚNG view cũ (danh
    /// tính không đổi), mà chữ thì phải cập nhật thật. Chỉ kiểm vế đầu thì một thanh trạng thái
    /// chết cứng cũng xanh.
    /// Nhãn, trạng thái bật/tắt và tooltip của mục View/Code — NFR-USE-01.
    var viewCodeForSelfTest: (title: String, enabled: Bool, tooltip: String, active: String) {
        let button = segments[.viewCode]
        return (button?.attributedTitle.string ?? "", button?.isEnabled ?? false,
                button?.toolTip ?? "", state.displayMode.spokenState)
    }

    /// Bấm một mục trên thanh trạng thái đúng như người dùng bấm — đi qua chính `segmentClicked`,
    /// nên nó kiểm được cả phép ánh xạ định danh → mục, chỗ đã một lần khiến mục mới im lặng
    /// không phản ứng.
    /// Chữ đang hiện trên một mục — xem `MainWindowController.statusCaretTitleForSelfTest`.
    func titleForSelfTest(_ segment: Segment) -> String { segments[segment]?.title ?? "" }

    func clickSegmentForSelfTest(_ segment: Segment) {
        guard let button = segments[segment], button.isEnabled else { return }
        segmentClicked(button)
    }

    var segmentsForSelfTest: [(name: String, identity: ObjectIdentifier, title: String, hidden: Bool)] {
        segments
            .map { (String(describing: $0.key), ObjectIdentifier($0.value), $0.value.title, $0.value.isHidden) }
            .sorted { $0.0 < $1.0 }
    }
}

/// Nhãn của mục View/Code trên thanh trạng thái.
///
/// Tách khỏi `DisplayModes` của lõi vì đây là chuyện CHỮ NGHĨA trên giao diện, không phải chuyện
/// tệp nào có chế độ nào — và lõi không được biết gì về `NSButton`.
enum DisplayViewLabel: Equatable {
    /// Đang ở Code, và đổi sang View được.
    case code
    /// Đang ở View, và quay về Code được.
    case view
    /// Tệp chỉ có một chế độ — mã nguồn, văn bản thuần.
    case codeOnly

    var canToggle: Bool { self != .codeOnly }

    /// Hiện CẢ HAI chế độ, tô sáng cái đang bật.
    ///
    /// Bản đầu chỉ hiện chế độ đang bật kèm mũi tên (`⇄ View`), và bài kiểm phơi ra ngay là nó
    /// MƠ HỒ: đọc «⇄ View» trong lúc đang nhìn mã nguồn thì không biết nó nói "anh đang ở View"
    /// hay "bấm để sang View". Hiện cả hai thì câu hỏi ấy không đặt ra được nữa — và người dùng
    /// còn biết luôn là có đúng hai chế độ, chứ không phải một danh sách dài.
    func attributedTitle(active: NSColor, inactive: NSColor) -> NSAttributedString {
        let font = Tokens.Font.caption
        guard self != .codeOnly else {
            return NSAttributedString(
                string: "Code", attributes: [.font: font, .foregroundColor: inactive])
        }
        let text = NSMutableAttributedString()
        let isView = self == .view
        text.append(NSAttributedString(
            string: "View", attributes: [.font: font,
                                         .foregroundColor: isView ? active : inactive]))
        text.append(NSAttributedString(
            string: " · ", attributes: [.font: font, .foregroundColor: inactive]))
        text.append(NSAttributedString(
            string: "Code", attributes: [.font: font,
                                         .foregroundColor: isView ? inactive : active]))
        return text
    }

    /// Chữ thuần, cho VoiceOver và cho bài kiểm.
    var title: String {
        switch self {
        case .code: return "View · Code"
        case .view: return "View · Code"
        case .codeOnly: return "Code"
        }
    }

    /// Chế độ đang bật, đọc thành chữ — VoiceOver phải nghe được điều mà màu sắc đang nói.
    var spokenState: String {
        switch self {
        case .code: return L("Đang ở chế độ Code")
        case .view: return L("Đang ở chế độ View")
        case .codeOnly: return L("Tệp này chỉ có một chế độ hiển thị")
        }
    }

    var tooltip: String {
        switch self {
        case .code: return L("Đang xem mã nguồn — bấm để sang chế độ View (⌥⌘V)")
        case .view: return L("Đang ở chế độ View — bấm để quay về mã nguồn (⌥⌘V)")
        case .codeOnly: return L("Tệp này chỉ có một chế độ hiển thị")
        }
    }
}
