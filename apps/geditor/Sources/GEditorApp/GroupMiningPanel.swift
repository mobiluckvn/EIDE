import AppKit
import GEditorCore

/// Bảng khai phá theo nhóm — FR-MIN-007, phần giao diện.
///
/// ## Bảng XẾP HẠNG, không phải bảng liệt kê
///
/// Đặc tả gọi đầu ra là *"BẢNG XẾP HẠNG NHÓM"*, viết hoa. Khác biệt không nhỏ: sáu mươi ba tỉnh
/// liệt kê theo tên là sáu mươi ba dòng người dùng phải tự đọc và tự so; xếp theo "nhóm nhiều
/// bất thường nhất" thì dòng đầu tiên đã là câu trả lời.
///
/// Ba cách xếp là ba câu hỏi khác nhau — *chỗ nào dữ liệu bẩn nhất*, *chỗ nào khó dự báo nhất*,
/// *chỗ nào quan hệ giữa hai cột đi ngược với phần còn lại* — nên chúng là một bộ chọn, không
/// phải ba bảng cạnh nhau.
///
/// ## Drill là ĐÁNH DẤU NGƯỢC vào dữ liệu gốc
///
/// Đặc tả nêu nguyên tắc chung của cả cụm khai phá: *"kết quả khai phá ĐÁNH DẤU NGƯỢC được vào
/// dữ liệu gốc (Mark engine)"*. Nên bấm đúp một nhóm không mở ra một cửa sổ báo cáo thứ hai — nó
/// tô các dòng của nhóm ấy ngay trong tài liệu và nhảy tới dòng đầu. Người dùng ở lại trong dữ
/// liệu của mình.
final class GroupMiningPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Khai phá theo nhóm") }

    static let height: CGFloat = 280

    private let groupPopup = NSPopUpButton()
    private let valuePopup = NSPopUpButton()
    private let pairPopup = NSPopUpButton()
    private let rankingPopup = NSPopUpButton()
    private let summary = NSTextField(labelWithString: "")
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()

    private(set) var report: GroupMining.Report?
    private var shown: [GroupMining.GroupResult] = []

    var onChangeSettings: (() -> Void)?
    var onDrill: ((GroupMining.GroupResult) -> Void)?
    var onExport: ((GroupMining.Report) -> Void)?
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

        for (popup, label) in [
            (groupPopup, L("Cột nhóm")), (valuePopup, L("Cột giá trị")),
            (pairPopup, L("Cột thứ hai cho tương quan")),
        ] {
            popup.target = self
            popup.action = #selector(settingsChanged)
            popup.setAccessibilityLabel(label)
        }

        rankingPopup.addItems(withTitles: GroupMining.Ranking.allCases.map(\.vietnamese))
        rankingPopup.target = self
        rankingPopup.action = #selector(rankingChanged)
        rankingPopup.setAccessibilityLabel(L("Cách xếp hạng"))

        summary.font = NSFont.systemFont(ofSize: 11)
        summary.textColor = Tokens.Color.editorInk.withAlphaComponent(0.75)
        summary.lineBreakMode = .byTruncatingTail

        configure(exportButton, title: L("Xuất tab mới"), action: #selector(exportTapped))
        configure(closeButton, title: L("Đóng"), action: #selector(closeTapped))

        let controls = NSStackView(views: [
            NSTextField(labelWithString: L("Nhóm theo:")), groupPopup,
            NSTextField(labelWithString: L("Giá trị:")), valuePopup,
            NSTextField(labelWithString: L("↔")), pairPopup,
            NSView(), exportButton, closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 6
        controls.translatesAutoresizingMaskIntoConstraints = false

        let second = NSStackView(views: [
            NSTextField(labelWithString: L("Xếp theo:")), rankingPopup, summary,
        ])
        second.orientation = .horizontal
        second.spacing = 6
        second.translatesAutoresizingMaskIntoConstraints = false

        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(rowDoubleClicked)
        table.setAccessibilityLabel(L("Bảng xếp hạng nhóm"))
        for (identifier, title, width) in [
            ("name", L("Nhóm"), 140.0), ("rows", L("Hàng"), 60.0),
            ("anomaly", L("Bất thường"), 110.0), ("fence", L("Hàng rào riêng"), 150.0),
            ("mape", L("MAPE"), 80.0), ("r", L("r"), 70.0),
            ("gap", L("Lệch r"), 70.0), ("note", L("Ghi chú"), 260.0),
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
    }

    private func configure(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    // MARK: - Nạp

    func setColumns(text: [String], numeric: [String]) {
        if groupPopup.itemTitles != text {
            groupPopup.removeAllItems()
            groupPopup.addItems(withTitles: text)
        }
        if valuePopup.itemTitles != numeric {
            valuePopup.removeAllItems()
            valuePopup.addItems(withTitles: numeric)
            pairPopup.removeAllItems()
            pairPopup.addItems(withTitles: numeric)
            // Cột thứ hai mặc định KHÁC cột thứ nhất: r(x, x) = 1 ở mọi nhóm, và bảng "lệch
            // tương quan" khi ấy toàn số 0 — trông như "không có gì bất thường".
            if numeric.count > 1 { pairPopup.selectItem(at: 1) }
        }
    }

    func present(_ report: GroupMining.Report) {
        self.report = report
        var text = String(
            format: L("%d nhóm · mốc tương quan toàn bộ %@"),
            report.groups.count,
            report.pooledCorrelation.map { ChartRender.number($0) } ?? L("không đo được"))
        if report.truncated > 0 {
            text += LF(" · ĐÃ CẮT %d nhóm", report.truncated)
        }
        // NFR-MIN-05 đòi kết quả một phần phải được **đánh dấu rõ**. Tooltip không đủ: một bảng
        // 300 nhóm trông y hệt một bảng 1.000 nhóm bị huỷ dở, và người đọc sẽ kết luận về những
        // nhóm chưa từng được chấm.
        if report.cancelled {
            text += L(" · ĐÃ HUỶ giữa chừng — bảng chưa đầy đủ")
        }
        summary.stringValue = text
        summary.textColor = report.truncated > 0 || report.cancelled
            ? Tokens.Color.ember
            : Tokens.Color.editorInk.withAlphaComponent(0.75)
        summary.toolTip = report.methodology
        rankingChanged()
    }

    var groupColumn: String? { groupPopup.titleOfSelectedItem }
    var valueColumn: String? { valuePopup.titleOfSelectedItem }
    var pairColumn: String? { pairPopup.titleOfSelectedItem }

    private var ranking: GroupMining.Ranking {
        GroupMining.Ranking.allCases[
            max(0, min(rankingPopup.indexOfSelectedItem,
                       GroupMining.Ranking.allCases.count - 1))]
    }

    @objc private func settingsChanged() { onChangeSettings?() }

    @objc private func rankingChanged() {
        shown = report?.ranked(by: ranking, limit: 200) ?? []
        // Nhóm KHÔNG chấm được vẫn phải hiện, ở cuối bảng. `ranked` loại chúng ra vì xếp hạng
        // một nhóm không có số liệu là vô nghĩa — nhưng biến chúng khỏi màn hình thì người dùng
        // tưởng dữ liệu chỉ có bấy nhiêu nhóm.
        shown += (report?.groups.filter { !$0.note.isEmpty }) ?? []
        table.reloadData()
    }

    @objc private func rowDoubleClicked() {
        guard table.clickedRow >= 0, table.clickedRow < shown.count else { return }
        onDrill?(shown[table.clickedRow])
    }

    @objc private func exportTapped() {
        guard let report else { return }
        onExport?(report)
    }

    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    var shownNamesForSelfTest: [String] { shown.map(\.name) }
    func selectRankingForSelfTest(_ index: Int) {
        rankingPopup.selectItem(at: index)
        rankingChanged()
    }
    func selectGroupColumnForSelfTest(_ name: String) {
        groupPopup.selectItem(withTitle: name)
        settingsChanged()
    }
    func selectValueColumnForSelfTest(_ name: String) {
        valuePopup.selectItem(withTitle: name)
        settingsChanged()
    }
    func drillForSelfTest(_ index: Int) {
        guard index < shown.count else { return }
        onDrill?(shown[index])
    }
}

extension GroupMiningPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < shown.count, let tableColumn else { return nil }
        let group = shown[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "name": text = group.name
        case "rows": text = String(group.rowCount)
        case "anomaly":
            text = group.fence == nil
                ? "—"
                : "\(group.anomalies) (\(ChartRender.number(group.anomalyRate))%)"
        case "fence":
            // Hàng rào của RIÊNG nhóm hiện thành cột: đó là bằng chứng nhìn được rằng hai nhóm
            // đang được đo bằng hai cây thước khác nhau, và là cả điểm của yêu cầu này.
            text = group.fence.map {
                "\(ChartRender.number($0.low)) … \(ChartRender.number($0.high))"
            } ?? "—"
        case "mape": text = group.mape.map { ChartRender.number($0) + "%" } ?? "—"
        case "r": text = group.correlation.map { ChartRender.number($0) } ?? "—"
        case "gap": text = group.correlationGap.map { ChartRender.number($0) } ?? "—"
        default: text = group.note.isEmpty ? group.forecastVerdict : group.note
        }
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: 11)
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = group.note.isEmpty ? group.forecastVerdict : group.note
        if !group.note.isEmpty {
            field.textColor = Tokens.Color.editorInk.withAlphaComponent(0.5)
        }
        return field
    }
}
