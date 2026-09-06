import AppKit
import GEditorCore

/// Bảng Mermaid Studio — FR-MMD-001 (vẽ) và FR-MMD-002 (xem trước song song).
///
/// ## Soạn TRÁI, sơ đồ PHẢI — cùng khuôn xem trước báo cáo
///
/// FR-MMD-002 nói *"mở rộng khuôn Markdown preview (FR-FMT-506)"*, và trong app này khuôn ấy đã
/// có hình dạng cụ thể ở `ReportPreviewView`: một cột bên phải của hàng giữa, mở/đóng bằng ràng
/// buộc bề rộng. Dùng lại đúng hình dạng ấy chứ không dựng một cửa sổ rời — một cửa sổ rời thì
/// người dùng phải tự xếp hai cửa sổ cạnh nhau mỗi lần, và mất luôn cảm giác "gõ bên này thấy
/// bên kia đổi".
///
/// ## Bảng này KHÔNG tự dựng WKWebView
///
/// Nó mượn chính web view của `MermaidRenderer`. Lý do ở ghi chú `MermaidRenderer.displayView`:
/// hai web view cho cùng một việc tốn gấp đôi RAM, và bấm-vào-sơ-đồ chỉ bắt được nếu thứ trên
/// màn hình là chính trang đã vẽ ra nó.
final class MermaidPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Sơ đồ Mermaid") }

    private let header = NSTextField(labelWithString: "")
    private let themePicker = NSSegmentedControl()
    private let transparentBox = NSButton()
    private let exportButton = NSPopUpButton()
    private let closeButton = NSButton()
    private let container = NSView()
    private var algorithmHeight: NSLayoutConstraint!
    /// Ô Cypher — FR-KNW-913, chỉ hiện với tài liệu DOT.
    private let cypherField = NSTextField()
    private var cypherHeight: NSLayoutConstraint!
    private let algorithmPicker = NSPopUpButton()
    /// Công tắc soạn trực quan — FR-KNW-915 (DOT) và FR-MMD-004 (mermaid).
    private let visualEditBox = NSButton()
    /// Bảng thuộc tính cho gantt/pie — FR-MMD-004.
    let propertyTable = MermaidPropertyTable()
    private var propertyHeight: NSLayoutConstraint!

    /// Người dùng gõ xong một truy vấn Cypher và nhấn Enter.
    var onCypher: ((String) -> Void)?
    /// Người dùng chọn một thuật toán đồ thị — FR-KNW-914.
    var onAlgorithm: ((Algorithm) -> Void)?
    /// Người dùng bật/tắt soạn trực quan — FR-KNW-915.
    var onVisualEditing: ((Bool) -> Void)?

    public enum Algorithm: Int, CaseIterable {
        case none, pageRank, communities, components, quality, resolveEntities,
             applyResolution, exportTable, renameNode, mergeNodes, splitNode, extractSubgraph,
             addNode, addEdge, editLabel, removeElement

        var title: String {
            switch self {
            case .none: return L("Thuật toán…")
            // FR-KNW-915 — bốn phép soạn, cũng có mặt ở đây chứ không CHỈ có cử chỉ chuột:
            // kéo và double-click không dùng được bằng bàn phím, mà NFR-USE-03 đòi *"điều
            // hướng đầy đủ bằng bàn phím"*. Bốn mục này chạy trên VÙNG CHỌN trong văn bản, nên
            // cùng một phép tới được bằng cả hai đường.
            case .addNode: return L("Thêm node…")
            case .addEdge: return L("Thêm cạnh giữa hai node đang chọn…")
            case .editLabel: return L("Sửa nhãn node đang chọn…")
            case .removeElement: return L("Xoá node/cạnh đang chọn")
            case .renameNode: return L("Đổi tên node đang chọn")
            case .mergeNodes: return L("Gộp các node đang chọn")
            case .splitNode: return L("Tách node đang chọn")
            case .extractSubgraph: return L("Trích subgraph đang chọn ra tab mới")
            case .pageRank: return L("PageRank (độ dày viền)")
            case .communities: return L("Cộng đồng (màu nền)")
            case .components: return L("Thành phần liên thông")
            case .quality: return L("Chấm sức khoẻ đồ thị")
            case .resolveEntities: return L("Gom biến thể entity → bảng duyệt")
            case .applyResolution: return L("Áp bảng duyệt đã sửa")
            case .exportTable: return L("Xuất bảng node ra tab mới")
            }
        }
    }

    /// Người dùng chọn một mục trong menu Xuất — FR-MMD-007.
    enum ExportChoice {
        case png(MermaidExport.Scale)
        case svg
        case copyImage
        case brandPreset
    }

    var onExport: ((ExportChoice) -> Void)?
    var onClose: (() -> Void)?
    var onChangeTheme: ((MermaidRenderer.Theme) -> Void)?

    private(set) var theme: MermaidRenderer.Theme = .light
    /// Nền trong suốt — mermaid vốn không vẽ nền, nên đây là mặc định TẮT của một thứ phải
    /// thêm vào chứ không phải bỏ đi. Xem `MermaidExport.png`.
    var isTransparent: Bool { transparentBox.state == .on }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }

    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        header.font = Tokens.Font.caption
        header.textColor = Tokens.Color.editorInk
        header.lineBreakMode = .byTruncatingTail
        header.translatesAutoresizingMaskIntoConstraints = false

        themePicker.segmentCount = MermaidRenderer.Theme.allCases.count
        for (index, item) in MermaidRenderer.Theme.allCases.enumerated() {
            themePicker.setLabel(item.vietnamese, forSegment: index)
        }
        themePicker.selectedSegment = 0
        themePicker.segmentStyle = .rounded
        themePicker.target = self
        themePicker.action = #selector(themeChanged)
        themePicker.translatesAutoresizingMaskIntoConstraints = false

        transparentBox.setButtonType(.switch)
        transparentBox.title = L("Nền trong suốt")
        transparentBox.font = Tokens.Font.caption
        transparentBox.state = .off
        transparentBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(transparentBox)

        // Menu bật xuống thay vì bốn nút: bốn cách xuất mà mỗi cách một nút thì thanh tiêu đề
        // dài hơn cả sơ đồ, và ba trong bốn nút ấy hiếm khi được bấm.
        exportButton.pullsDown = true
        exportButton.bezelStyle = .rounded
        exportButton.font = Tokens.Font.caption
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        let menu = NSMenu()
        menu.addItem(withTitle: L("Xuất…"), action: nil, keyEquivalent: "")
        for scale in MermaidExport.Scale.allCases {
            let item = NSMenuItem(
                title: LF("Lưu PNG %@…", scale.label),
                action: #selector(exportPNG(_:)), keyEquivalent: "")
            item.target = self
            item.tag = scale.rawValue
            menu.addItem(item)
        }
        for (title, action) in [
            (L("Lưu SVG…"), #selector(exportSVG)),
            (L("Chép ảnh vào clipboard"), #selector(copyImage)),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let brand = NSMenuItem(
            title: L("Màu thương hiệu…"), action: #selector(editBrand), keyEquivalent: "")
        brand.target = self
        menu.addItem(brand)
        exportButton.menu = menu
        addSubview(exportButton)

        closeButton.title = L("Đóng")
        closeButton.bezelStyle = .rounded
        closeButton.font = Tokens.Font.caption
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        for algorithm in Algorithm.allCases {
            algorithmPicker.addItem(withTitle: algorithm.title)
        }
        algorithmPicker.font = Tokens.Font.caption
        algorithmPicker.target = self
        algorithmPicker.action = #selector(algorithmChanged)
        algorithmPicker.isHidden = true
        algorithmPicker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(algorithmPicker)

        // TẮT mặc định, và bật là một hành động thấy được. Xem ghi chú ở phần JavaScript của
        // `MermaidRenderer`: không có công tắc thì mọi cú kéo trên sơ đồ đều sửa tệp.
        visualEditBox.setButtonType(.switch)
        visualEditBox.title = L("Soạn trực quan")
        visualEditBox.toolTip = L("Kéo từ node này sang node kia để thêm cạnh; "
            + "double-click để sửa nhãn. Mỗi thao tác một bước hoàn tác.")
        visualEditBox.font = Tokens.Font.caption
        visualEditBox.state = .off
        visualEditBox.isHidden = true
        visualEditBox.target = self
        visualEditBox.action = #selector(visualEditingChanged)
        visualEditBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEditBox)

        cypherField.placeholderString =
            "MATCH (a)-[r]->(b) WHERE a.name CONTAINS 'An' RETURN a.name, b.name"
        cypherField.font = Tokens.Font.monoInline()
        cypherField.target = self
        // Chạy khi nhấn Enter, KHÔNG theo từng phím: một truy vấn đang gõ dở gần như luôn sai
        // cú pháp, và mỗi phím gõ là một lượt dựng bảng node/cạnh rồi gọi DuckDB.
        cypherField.action = #selector(runCypher)
        cypherField.isHidden = true
        cypherField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cypherField)

        propertyTable.isHidden = true
        propertyTable.translatesAutoresizingMaskIntoConstraints = false
        addSubview(propertyTable)

        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(themePicker)
        addSubview(container)

        let inset = Tokens.Metrics.spacing(1)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            header.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            header.trailingAnchor.constraint(
                lessThanOrEqualTo: themePicker.leadingAnchor, constant: -8),

            themePicker.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            transparentBox.leadingAnchor.constraint(
                equalTo: themePicker.trailingAnchor, constant: 10),
            transparentBox.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            exportButton.leadingAnchor.constraint(
                equalTo: transparentBox.trailingAnchor, constant: 8),
            exportButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.leadingAnchor.constraint(
                equalTo: exportButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            algorithmPicker.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            algorithmPicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            algorithmPicker.trailingAnchor.constraint(
                lessThanOrEqualTo: visualEditBox.leadingAnchor, constant: -8),

            visualEditBox.centerYAnchor.constraint(equalTo: algorithmPicker.centerYAnchor),
            visualEditBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            cypherField.topAnchor.constraint(
                equalTo: algorithmPicker.bottomAnchor, constant: 6),
            cypherField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            cypherField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            container.topAnchor.constraint(equalTo: cypherField.bottomAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: propertyTable.topAnchor),

            propertyTable.leadingAnchor.constraint(equalTo: leadingAnchor),
            propertyTable.trailingAnchor.constraint(equalTo: trailingAnchor),
            propertyTable.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        propertyHeight = propertyTable.heightAnchor.constraint(equalToConstant: 0)
        propertyHeight.isActive = true
        cypherHeight = cypherField.heightAnchor.constraint(equalToConstant: 0)
        cypherHeight.isActive = true
        algorithmHeight = algorithmPicker.heightAnchor.constraint(equalToConstant: 0)
        algorithmHeight.isActive = true
    }

    @objc private func algorithmChanged() {
        guard let choice = Algorithm(rawValue: algorithmPicker.indexOfSelectedItem),
              choice != .none else { return }
        // Trả về mục đầu ngay: đây là một NÚT LỆNH đội lốt hộp chọn, không phải một trạng thái.
        // Để nó đứng ở lựa chọn vừa bấm thì người dùng bấm lại cùng mục sẽ không chạy gì.
        algorithmPicker.selectItem(at: 0)
        onAlgorithm?(choice)
    }

    @objc private func runCypher() {
        let text = cypherField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        onCypher?(text)
    }

    // MARK: - Móc cho bài tự kiểm

    func setCypherForSelfTest(_ text: String) {
        cypherField.stringValue = text
        runCypher()
    }

    var isCypherBarVisibleForSelfTest: Bool { !cypherField.isHidden }
    func runAlgorithmForSelfTest(_ algorithm: Algorithm) { onAlgorithm?(algorithm) }

    /// Gắn web view của bộ render vào bảng. Gọi lại nhiều lần cũng chỉ gắn một lần.
    func attach(_ view: NSView) {
        guard view.superview !== container else { return }
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    /// Dòng trạng thái sau mỗi lượt vẽ.
    func present(_ results: [MermaidRenderer.Rendered], kinds: [MermaidDiagramKind]) {
        lastResults = results
        let failed = results.filter(\.isFailure)
        if results.isEmpty {
            header.stringValue = L("Chưa có sơ đồ nào")
            header.textColor = Tokens.Color.editorInk
        } else if failed.isEmpty {
            let names = Set(kinds.map(\.vietnamese)).sorted().joined(separator: ", ")
            header.stringValue = String(
                format: L("%d sơ đồ · %@"), results.count, names)
            header.textColor = Tokens.Color.editorInk
        } else {
            // Nói ra SỐ sơ đồ hỏng và dòng của cái đầu tiên: hộp lỗi đã nằm đúng chỗ trong
            // trang, nhưng người dùng có thể đang cuộn ở chỗ khác.
            let first = failed[0]
            header.stringValue = String(
                format: L("%d/%d sơ đồ HỎNG — sơ đồ thứ %d%@"),
                failed.count, results.count, first.index + 1,
                first.line.map { LF(", dòng %d", $0) } ?? "")
            header.textColor = Tokens.Color.error
        }
        exportButton.isEnabled = results.contains { $0.svg != nil }
    }

    /// Ô Cypher — FR-KNW-913. Chỉ hiện khi tài liệu là đồ thị DOT.
    ///
    /// Nằm ngay dưới sơ đồ chứ không ở một bảng riêng: câu truy vấn và hình vẽ là hai nửa của
    /// cùng một việc — hỏi rồi nhìn xem cái gì sáng lên.
    func showCypherBar(_ visible: Bool) {
        cypherField.isHidden = !visible
        algorithmPicker.isHidden = !visible
        cypherHeight.constant = visible ? 24 : 0
        algorithmHeight.constant = visible ? 22 : 0
    }

    /// Công tắc soạn trực quan — hiện với CẢ DOT lẫn mermaid.
    ///
    /// Tách khỏi `showCypherBar` ở FR-MMD-004: Cypher là chuyện của đồ thị tri thức, còn soạn
    /// trực quan nay áp cho cả sơ đồ mermaid. Gộp hai thứ thì mở một tệp `.mmd` sẽ không có công
    /// tắc nào để bật.
    func showVisualEditToggle(_ visible: Bool) {
        visualEditBox.isHidden = !visible
        // Rời khỏi tài liệu soạn được thì TẮT hẳn, chứ không chỉ giấu công tắc đi. Giấu mà vẫn
        // bật nghĩa là mọi cú kéo vẫn đang soạn — với một công tắc người dùng không còn nhìn
        // thấy để tắt.
        if !visible, visualEditBox.state == .on {
            visualEditBox.state = .off
            onVisualEditing?(false)
        }
    }

    /// Hiện/ẩn bảng thuộc tính (gantt · pie) — FR-MMD-004.
    func showPropertyTable(_ visible: Bool) {
        propertyTable.isHidden = !visible
        propertyHeight.constant = visible ? 170 : 0
    }

    var isPropertyTableVisibleForSelfTest: Bool { !propertyTable.isHidden }

    @objc private func visualEditingChanged() {
        onVisualEditing?(visualEditBox.state == .on)
    }

    /// Soạn trực quan đang bật hay không — FR-KNW-915.
    var isVisualEditing: Bool { visualEditBox.state == .on }

    func setVisualEditingForSelfTest(_ on: Bool) {
        visualEditBox.state = on ? .on : .off
        visualEditingChanged()
    }

    var isVisualEditBoxVisibleForSelfTest: Bool { !visualEditBox.isHidden }

    func focusCypher() { window?.makeFirstResponder(cypherField) }

    var cypherText: String { cypherField.stringValue }

    /// Ghi chú KHÔNG phải lỗi — ví dụ phần DOT mà phép chuyển bỏ qua (FR-KNW-905).
    ///
    /// Màu bình thường chứ không đỏ, và đó là khác biệt có nghĩa: "subgraph đọc phẳng" là một
    /// giới hạn đã biết, không phải một thứ hỏng. Nhuộm đỏ nó thì người dùng đi tìm lỗi ở một
    /// sơ đồ đang vẽ đúng.
    func showNote(_ message: String) {
        guard !message.isEmpty else { return }
        header.stringValue = message
        header.textColor = Tokens.Color.editorInk
    }

    func showFailure(_ message: String) {
        header.stringValue = message
        header.textColor = Tokens.Color.error
        exportButton.isEnabled = false
    }

    private(set) var lastResults: [MermaidRenderer.Rendered] = []

    // MARK: - Hành động

    @objc private func themeChanged() {
        theme = MermaidRenderer.Theme.allCases[
            max(0, min(MermaidRenderer.Theme.allCases.count - 1, themePicker.selectedSegment))]
        onChangeTheme?(theme)
    }

    @objc private func exportPNG(_ sender: NSMenuItem) {
        guard let scale = MermaidExport.Scale(rawValue: sender.tag) else { return }
        onExport?(.png(scale))
    }

    @objc private func exportSVG() { onExport?(.svg) }
    @objc private func copyImage() { onExport?(.copyImage) }
    @objc private func editBrand() { onExport?(.brandPreset) }
    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var headerTextForSelfTest: String { header.stringValue }
    var diagramCountForSelfTest: Int { lastResults.count }
    var failureCountForSelfTest: Int { lastResults.filter(\.isFailure).count }
    func selectThemeForSelfTest(_ theme: MermaidRenderer.Theme) {
        themePicker.selectedSegment =
            MermaidRenderer.Theme.allCases.firstIndex(of: theme) ?? 0
        themeChanged()
    }

    func setTransparentForSelfTest(_ on: Bool) { transparentBox.state = on ? .on : .off }
    func exportForSelfTest(_ choice: ExportChoice) { onExport?(choice) }
    /// Chữ trên các mục của menu Xuất — bài tự kiểm đọc để chắc bốn đường xuất đều có mặt.
    var exportMenuTitlesForSelfTest: [String] {
        (exportButton.menu?.items ?? []).map(\.title)
    }
    var lastSVGForSelfTest: String? { lastResults.compactMap(\.svg).first }
}
