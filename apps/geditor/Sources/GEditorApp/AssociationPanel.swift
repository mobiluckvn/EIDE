import AppKit
import GEditorCore

/// Bảng luật kết hợp — FR-MIN-003, phần giao diện.
///
/// ## Cột `lift` đứng CẠNH cột `confidence`, và bảng sắp theo lift
///
/// Đây là quyết định thiết kế quan trọng nhất của panel này, và nó chống lại một thói quen.
/// Công cụ khai phá giỏ hàng thường sắp theo confidence vì con số ấy dễ hiểu nhất — *"92% người
/// mua A cũng mua B"*. Nhưng nếu B có trong 95% giỏ thì luật ấy nói người mua A mua B **ít hơn**
/// trung bình, và sắp theo confidence đưa đúng những luật vô nghĩa nhất lên đầu.
///
/// Nên: bảng sắp theo `lift`, cột `lift` nằm ngay cạnh `confidence`, và mỗi luật có lift quanh 1
/// mang theo một câu cảnh báo hiện ngay trong hàng.
///
/// ## Bấm một luật thì tô các giao dịch trong FILE NGUỒN
///
/// Đặc tả: *"click một luật đánh dấu (Mark) mọi giao dịch chứa luật đó trong file nguồn"*. Một
/// bảng luật không bấm tới được dữ liệu chỉ là một bảng số — người dùng không kiểm được luật ấy
/// có thật không, và không làm gì tiếp được với nó.
final class AssociationPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Luật kết hợp") }

    static let height: CGFloat = 280

    /// Hai dạng đầu vào mà đặc tả nêu.
    enum InputShape: Int {
        /// Mỗi dòng một giỏ, item phân tách bởi một ký tự.
        case basket
        /// Hai cột `[mã giao dịch, item]`.
        case long
    }

    private let shapePopup = NSPopUpButton()
    private let firstPopup = NSPopUpButton()
    private let secondPopup = NSPopUpButton()
    private let delimiterField = NSTextField()
    private let supportField = NSTextField()
    private let confidenceField = NSTextField()
    private let summary = NSTextField(labelWithString: "")
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()

    private(set) var result: Apriori.Result?

    var onChangeSettings: (() -> Void)?
    var onPickRule: ((Apriori.Rule) -> Void)?
    var onExport: ((Apriori.Result) -> Void)?
    var onClose: (() -> Void)?

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

        shapePopup.addItems(withTitles: [L("Mỗi dòng một giỏ"), L("Hai cột: mã · item")])
        shapePopup.target = self
        shapePopup.action = #selector(shapeChanged)
        shapePopup.setAccessibilityLabel(L("Dạng dữ liệu giao dịch"))

        for (popup, label) in [
            (firstPopup, L("Cột giỏ hàng hoặc mã giao dịch")), (secondPopup, L("Cột item")),
        ] {
            popup.target = self
            popup.action = #selector(settingsChanged)
            popup.setAccessibilityLabel(label)
        }

        delimiterField.stringValue = ","
        delimiterField.target = self
        delimiterField.action = #selector(settingsChanged)
        delimiterField.widthAnchor.constraint(equalToConstant: 34).isActive = true
        delimiterField.setAccessibilityLabel(L("Ký tự phân tách item"))

        supportField.stringValue = "1"
        confidenceField.stringValue = "50"
        for field in [supportField, confidenceField] {
            field.target = self
            field.action = #selector(settingsChanged)
            field.widthAnchor.constraint(equalToConstant: 48).isActive = true
        }
        supportField.setAccessibilityLabel(L("Support tối thiểu, phần trăm"))
        confidenceField.setAccessibilityLabel(L("Confidence tối thiểu, phần trăm"))

        summary.font = NSFont.systemFont(ofSize: 11)
        summary.textColor = Tokens.Color.editorInk.withAlphaComponent(0.75)
        summary.lineBreakMode = .byTruncatingTail

        configure(exportButton, title: L("Xuất tab mới"), action: #selector(exportTapped))
        configure(closeButton, title: L("Đóng"), action: #selector(closeTapped))

        let controls = NSStackView(views: [
            shapePopup, firstPopup, secondPopup,
            NSTextField(labelWithString: L("Tách bởi:")), delimiterField,
            NSView(), exportButton, closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 6
        controls.translatesAutoresizingMaskIntoConstraints = false

        let second = NSStackView(views: [
            NSTextField(labelWithString: L("Support ≥")), supportField,
            NSTextField(labelWithString: L("% · Confidence ≥")), confidenceField,
            NSTextField(labelWithString: L("%")), summary,
        ])
        second.orientation = .horizontal
        second.spacing = 4
        second.translatesAutoresizingMaskIntoConstraints = false

        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(rowDoubleClicked)
        table.setAccessibilityLabel(L("Bảng luật kết hợp"))
        for (identifier, title, width) in [
            ("rule", L("Luật"), 280.0), ("support", L("Support"), 80.0),
            ("confidence", L("Confidence"), 90.0), ("lift", L("Lift"), 70.0),
            ("leverage", L("Leverage"), 80.0), ("caution", L("Cảnh báo"), 320.0),
        ] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(controls)
        addSubview(second)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            second.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
            second.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            second.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: second.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        shapeChanged()
    }

    private func configure(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    // MARK: - Nạp

    func setColumns(_ columns: [String]) {
        guard firstPopup.itemTitles != columns else { return }
        for popup in [firstPopup, secondPopup] {
            popup.removeAllItems()
            popup.addItems(withTitles: columns)
        }
        if columns.count > 1 { secondPopup.selectItem(at: 1) }
    }

    func present(_ result: Apriori.Result) {
        self.result = result
        var text = String(
            format: L("%d giao dịch · %d item · %d luật"),
            result.transactionCount, result.itemCount, result.rules.count)
        if result.rules.isEmpty, result.transactionCount > 0 {
            // Nói rõ vì sao rỗng. Một bảng trống không kèm lý do đọc thành "công cụ hỏng".
            text += L(" — không luật nào đạt ngưỡng; hạ support hoặc confidence xuống")
        }
        summary.stringValue = text
        summary.textColor = result.hitCandidateLimit
            ? Tokens.Color.ember
            : Tokens.Color.editorInk.withAlphaComponent(0.75)
        if result.hitCandidateLimit {
            summary.stringValue += L(" — ĐÃ DỪNG SỚM, bảng KHÔNG đầy đủ")
        }
        summary.toolTip = result.methodology
        table.reloadData()
    }

    var shape: InputShape { shapePopup.indexOfSelectedItem == 1 ? .long : .basket }
    var firstColumn: String? { firstPopup.titleOfSelectedItem }
    var secondColumn: String? { secondPopup.titleOfSelectedItem }
    var delimiter: Character { delimiterField.stringValue.first ?? "," }
    var minimumSupport: Double {
        max(0.0001, (Double(supportField.stringValue) ?? 1) / 100)
    }
    var minimumConfidence: Double {
        max(0, min(1, (Double(confidenceField.stringValue) ?? 50) / 100))
    }

    @objc private func shapeChanged() {
        let isLong = shape == .long
        secondPopup.isHidden = !isLong
        delimiterField.isEnabled = !isLong
        settingsChanged()
    }

    @objc private func settingsChanged() { onChangeSettings?() }

    @objc private func rowDoubleClicked() {
        guard let result, table.clickedRow >= 0, table.clickedRow < result.rules.count else {
            return
        }
        onPickRule?(result.rules[table.clickedRow])
    }

    @objc private func exportTapped() {
        guard let result else { return }
        onExport?(result)
    }

    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    var ruleTextsForSelfTest: [String] { result?.rules.map(\.text) ?? [] }
    func selectShapeForSelfTest(_ index: Int) {
        shapePopup.selectItem(at: index)
        shapeChanged()
    }
    func selectColumnsForSelfTest(first: String, second: String?) {
        firstPopup.selectItem(withTitle: first)
        if let second { secondPopup.selectItem(withTitle: second) }
        settingsChanged()
    }
    func setDelimiterForSelfTest(_ character: Character) {
        delimiterField.stringValue = String(character)
        settingsChanged()
    }
    func setThresholdsForSelfTest(support: Double, confidence: Double) {
        supportField.stringValue = String(support)
        confidenceField.stringValue = String(confidence)
        settingsChanged()
    }
    func pickRuleForSelfTest(_ index: Int) {
        guard let result, index < result.rules.count else { return }
        onPickRule?(result.rules[index])
    }
}

extension AssociationPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { result?.rules.count ?? 0 }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let result, row < result.rules.count, let tableColumn else { return nil }
        let rule = result.rules[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "rule": text = rule.text
        case "support": text = ChartRender.number(rule.support * 100) + "%"
        case "confidence": text = ChartRender.number(rule.confidence * 100) + "%"
        case "lift": text = ChartRender.number(rule.lift)
        case "leverage": text = ChartRender.number(rule.leverage)
        default: text = rule.caution
        }
        let field = NSTextField(labelWithString: text)
        field.font = tableColumn.identifier.rawValue == "rule"
            ? NSFont.systemFont(ofSize: 11)
            : NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = rule.caution.isEmpty
            ? LF("%d / %d giao dịch chứa cả hai vế",
                     rule.count, result.transactionCount)
            : rule.caution
        if !rule.caution.isEmpty { field.textColor = Tokens.Color.ember }
        return field
    }
}
