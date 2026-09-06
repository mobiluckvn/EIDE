import AppKit
import GEditorCore

/// Bảng chất lượng dữ liệu — FR-DQR-001 (luật) và FR-DQR-002 (điểm sáu chiều).
///
/// Cùng hình dạng với panel kiểm CSV (FR-CSV-405) và vì cùng lý do: một danh sách lỗi mà không
/// bấm tới được chỗ sai chỉ là một lời phàn nàn. Đặc tả viết thẳng ra điều ấy — *"click rule →
/// Mark và nhảy tới các dòng vi phạm"*.
///
/// ## Điểm số đứng CẠNH danh sách luật, không đứng riêng
///
/// Một con số 0–100 tự nó không nói được phải sửa gì. Người dùng nhìn "72 điểm" rồi hỏi ngay
/// "vì cái gì" — nên hàng điểm sáu chiều và bảng luật phải nhìn thấy cùng lúc.
///
/// ## Chiều KHÔNG chấm được hiện ra thành chữ, không thành khoảng trống
///
/// `QualityScorer` cố ý trả `nil` cho chiều thiếu dữ kiện thay vì cho 100 điểm. Nếu panel vẽ
/// `nil` thành một ô trống thì cả sự cẩn thận ấy mất sạch: người đọc sẽ hiểu là "không có vấn
/// đề gì". Nên nó hiện là `—` kèm lý do trong tooltip.
final class QualityPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Chất lượng dữ liệu") }

    static let height: CGFloat = 240

    /// Hai cách nhìn cùng một lượt chấm: đang sai cái gì, và nó đang đi về đâu.
    ///
    /// Cùng một panel chứ không phải hai, đúng lối Bàn làm sạch đã đặt: xu hướng là thứ người
    /// dùng liếc sang để biết *"đợt dữ liệu này có xấu đi không"*, và bắt họ đóng bảng luật để
    /// xem nó là chen một bức tường vào giữa hai nửa của một câu hỏi.
    enum Mode: Int { case rules, trend }

    private let scoreLine = NSTextField(labelWithString: "")
    private let dimensionRow = NSStackView()
    private let summary = NSTextField(labelWithString: "")
    private let modePicker = NSSegmentedControl()
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()
    private let trendChart = ChartView()
    private var trendChartHeight = NSLayoutConstraint()

    private var report: QualityEngine.Report?
    private var score: QualityScore?
    private(set) var mode: Mode = .rules
    /// Lịch sử đã đọc, MỚI NHẤT ở đầu bảng — người ta hỏi "lần gần nhất thế nào" trước.
    private var history: [QualitySnapshot] = []
    /// Ngoài lề của lịch sử: số dòng hỏng, để nói ra chứ không nuốt.
    private var brokenHistoryLines = 0

    /// Người dùng bấm một luật — tầng trên đi tìm và tô các dòng vi phạm.
    var onSelectRule: ((QualityEngine.RuleResult) -> Void)?
    /// Người dùng bấm nút sửa của một luật TRƯỢT — FR-DQR-006.
    var onFixRule: ((QualityEngine.RuleResult) -> Void)?
    var onExport: (() -> Void)?
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

        scoreLine.font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        scoreLine.textColor = Tokens.Color.editorInk
        scoreLine.translatesAutoresizingMaskIntoConstraints = false

        dimensionRow.orientation = .horizontal
        dimensionRow.spacing = 14
        dimensionRow.translatesAutoresizingMaskIntoConstraints = false

        summary.font = Tokens.Font.caption
        summary.textColor = Tokens.Color.editorInk
        summary.lineBreakMode = .byTruncatingTail
        summary.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (exportButton, L("Xuất vi phạm ra tab mới"), #selector(exportTapped)),
            (closeButton, L("Đóng"), #selector(closeTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
        }
        exportButton.isEnabled = false

        modePicker.segmentCount = 2
        modePicker.setLabel(L("Luật"), forSegment: 0)
        modePicker.setLabel(L("Xu hướng"), forSegment: 1)
        modePicker.selectedSegment = 0
        modePicker.segmentStyle = .rounded
        modePicker.target = self
        modePicker.action = #selector(modeChanged)
        modePicker.translatesAutoresizingMaskIntoConstraints = false

        applyColumns()
        table.headerView = NSTableHeaderView()
        table.rowHeight = Tokens.Metrics.listRowHeight
        table.dataSource = self
        table.delegate = self
        table.style = .plain
        table.backgroundColor = Tokens.Color.chrome
        table.usesAlternatingRowBackgroundColors = false
        // Chọn được HAI dòng: bảng so sánh của FR-DQR-004 so *"2 snapshot bất kỳ"*, và cách rẻ
        // nhất để nói "hai cái nào" là chọn đúng hai dòng.
        table.allowsMultipleSelection = true
        table.target = self
        // Bấm MỘT lần, không phải hai. Đây là danh sách để đi tới, không phải để mở ra —
        // cùng lối với panel kiểm CSV và panel kết quả tìm kiếm.
        table.action = #selector(rowClicked)

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        trendChart.translatesAutoresizingMaskIntoConstraints = false
        trendChart.isHidden = true

        addSubview(scoreLine)
        addSubview(dimensionRow)
        addSubview(summary)
        addSubview(modePicker)
        addSubview(trendChart)
        addSubview(scrollView)

        let inset = Tokens.Metrics.spacing(2)
        trendChartHeight = trendChart.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            modePicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            modePicker.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),

            trendChart.topAnchor.constraint(equalTo: modePicker.bottomAnchor, constant: 6),
            trendChart.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            trendChart.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            trendChartHeight,

            scoreLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scoreLine.topAnchor.constraint(equalTo: topAnchor, constant: inset),

            dimensionRow.leadingAnchor.constraint(
                equalTo: scoreLine.trailingAnchor, constant: 16),
            dimensionRow.centerYAnchor.constraint(equalTo: scoreLine.centerYAnchor),
            dimensionRow.trailingAnchor.constraint(
                lessThanOrEqualTo: exportButton.leadingAnchor, constant: -12),

            exportButton.centerYAnchor.constraint(equalTo: scoreLine.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: exportButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: scoreLine.centerYAnchor),

            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            summary.topAnchor.constraint(equalTo: scoreLine.bottomAnchor, constant: 6),

            scrollView.topAnchor.constraint(equalTo: trendChart.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    /// Cột của bảng đổi theo chế độ.
    ///
    /// Dựng lại thay vì dùng chung năm cột cho cả hai: một bảng xu hướng mang tiêu đề "Vi phạm"
    /// trên cột chứa số hàng là loại nhầm lẫn mà người đọc không nghi ngờ, vì tiêu đề trông vẫn
    /// hợp lý.
    private func applyColumns() {
        for column in table.tableColumns { table.removeTableColumn(column) }
        let layout: [(String, String, CGFloat)] = mode == .rules
            ? [("severity", L("Mức"), 60), ("rule", L("Luật"), 360),
               ("violations", L("Vi phạm"), 90), ("percent", L("Tỷ lệ"), 70),
               // Cột nút của FR-DQR-006. Giữ NGUYÊN bề rộng khi cửa sổ giãn — cùng lý do đã ghi
               // ở Bàn làm sạch: một nút rộng gấp ba lần chữ trong nó trông như nhấn nhầm chỗ.
               ("fix", "", 180)]
            : [("when", L("Lúc chấm"), 180), ("total", L("Điểm"), 70),
               ("rows", L("Số hàng"), 90), ("delta", L("Lệch"), 70),
               ("failed", L("Luật trượt"), 100)]
        for (identifier, title, width) in layout {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            if identifier == "fix" {
                column.minWidth = width
                column.maxWidth = width
                column.resizingMask = []
            }
            table.addTableColumn(column)
        }
    }

    // MARK: - Nạp kết quả

    func present(_ report: QualityEngine.Report, score: QualityScore) {
        self.report = report
        self.score = score

        if let total = score.total {
            scoreLine.stringValue = String(format: "%.0f/100", total)
            scoreLine.textColor = total >= 90 ? Tokens.Color.editorInk
                : (total >= 70 ? Tokens.Color.ember : Tokens.Color.error)
        } else {
            scoreLine.stringValue = "—/100"
            scoreLine.textColor = Tokens.Color.editorInk
        }

        for view in dimensionRow.arrangedSubviews {
            dimensionRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for dimension in score.dimensions {
            let label = NSTextField(labelWithString: "")
            label.font = Tokens.Font.caption
            if let value = dimension.value {
                label.stringValue = "\(dimension.dimension.vietnamese) \(Int(value.rounded()))"
                label.textColor = Tokens.Color.editorInk
            } else {
                // KHÔNG vẽ thành ô trống — xem ghi chú ở đầu lớp.
                label.stringValue = "\(dimension.dimension.vietnamese) —"
                label.textColor = Tokens.Color.ember
            }
            // Công thức và số liệu vào tooltip: NFR-DQR-03 đòi công thức in trong kết quả, và
            // một điểm số không tra lại được là một điểm số không ai kiểm được.
            label.toolTip = [dimension.formula, dimension.detail, dimension.note]
                .compactMap { $0 }.joined(separator: "\n")
            dimensionRow.addArrangedSubview(label)
        }

        let errors = report.failedErrors.count
        let warnings = report.failedWarnings.count
        exportButton.isEnabled = errors + warnings > 0
        // Đang xem xu hướng thì GIỮ dòng tóm tắt của xu hướng: chấm lại sau một bước sửa
        // (FR-DQR-006) không được kéo người dùng khỏi bảng họ đang đọc.
        if mode == .rules { refreshRuleSummary() }
        table.reloadData()
    }

    private func refreshRuleSummary() {
        guard let report else { return }
        let errors = report.failedErrors.count
        let warnings = report.failedWarnings.count
        if errors == 0 && warnings == 0 {
            summary.stringValue = String(
                format: L("%d luật, tất cả ĐẠT · %d hàng · %.0f ms"),
                report.results.count, report.rowCount, report.milliseconds)
            summary.textColor = Tokens.Color.editorInk
        } else {
            summary.stringValue = String(
                format: L("%d lỗi · %d cảnh báo trên %d luật · %d hàng · %.0f ms"),
                errors, warnings, report.results.count, report.rowCount, report.milliseconds)
            summary.textColor = errors > 0 ? Tokens.Color.error : Tokens.Color.ember
        }
    }

    // MARK: - Xu hướng (FR-DQR-004)

    /// Nạp lịch sử đã đọc từ `.gquality.history.jsonl`.
    func present(history log: QualityHistory.Log) {
        // Đảo về MỚI NHẤT TRƯỚC cho bảng; biểu đồ thì vẫn đi theo thời gian tăng dần.
        history = log.snapshots.reversed()
        brokenHistoryLines = log.brokenLines
        drawTrend(log)
        if mode == .trend {
            refreshTrendSummary()
            table.reloadData()
        }
    }

    private func drawTrend(_ log: QualityHistory.Log) {
        let points = QualityDrift.trend(log).enumerated().map { index, entry in
            ChartData.Point(x: Double(index), y: entry.total,
                            label: QualityPanel.shortDay(entry.date))
        }
        guard points.count >= 2 else {
            // Một điểm KHÔNG phải một xu hướng. Vẽ một chấm rồi gọi nó là đường là mời người
            // đọc suy ra một chiều đi lên hay đi xuống chưa hề có trong dữ liệu.
            trendChart.show(nil, kind: .line, title: "")
            return
        }
        trendChart.show(
            ChartData.Series(name: L("Điểm chất lượng"), points: points,
                             originalCount: points.count),
            kind: .line, title: L("Điểm theo thời gian"))
    }

    @objc private func modeChanged() {
        mode = Mode(rawValue: modePicker.selectedSegment) ?? .rules
        applyColumns()
        trendChart.isHidden = mode != .trend
        trendChartHeight.constant = mode == .trend ? 96 : 0
        table.deselectAll(nil)
        if mode == .trend { refreshTrendSummary() } else { refreshRuleSummary() }
        table.reloadData()
    }

    private func refreshTrendSummary() {
        guard !history.isEmpty else {
            summary.stringValue = L("Chưa có mốc nào trong lịch sử — mỗi lần chấm sẽ ghi thêm "
                + "một dòng vào tệp «.history.jsonl» cạnh bộ luật.")
            summary.textColor = Tokens.Color.editorInk
            return
        }
        var text = LF("%d mốc trong lịch sử", history.count)
        if brokenHistoryLines > 0 {
            text += LF(" · %d dòng KHÔNG đọc được", brokenHistoryLines)
        }
        text += L(" · chọn hai dòng để so")
        summary.stringValue = text
        summary.textColor = brokenHistoryLines > 0 ? Tokens.Color.ember : Tokens.Color.editorInk
    }

    /// Chọn đúng hai dòng → so hai snapshot ấy, đúng vế *"2 snapshot bất kỳ"*.
    private func compareSelection() {
        let selected = table.selectedRowIndexes.sorted()
        guard selected.count == 2, selected.allSatisfy({ $0 < history.count }) else {
            return refreshTrendSummary()
        }
        // Bảng xếp mới-nhất-trước, nên dòng có chỉ số LỚN hơn là bản CŨ hơn.
        let comparison = QualityDrift.compare(
            current: history[selected[0]], previous: history[selected[1]])
        var parts: [String] = []
        if let delta = comparison.totalDelta {
            parts.append(LF("điểm %+.1f", delta))
        }
        let dropped = comparison.dimensions
            .filter { ($0.delta ?? 0) < -0.05 }
            .sorted { ($0.delta ?? 0) < ($1.delta ?? 0) }
        if dropped.isEmpty {
            parts.append(L("không chiều nào tụt"))
        } else {
            parts.append(L("tụt: ") + dropped.prefix(3).map {
                String(format: "%@ %+.1f", $0.vietnamese, $0.delta ?? 0)
            }.joined(separator: ", "))
        }
        if !comparison.newlyFailing.isEmpty {
            parts.append(LF("%d luật mới trượt: %@",
                                comparison.newlyFailing.count,
                                comparison.newlyFailing.prefix(2).joined(separator: " · ")))
        }
        if let rows = comparison.rowCountDelta, rows != 0 {
            parts.append(LF("số hàng %+d", rows))
        }
        summary.stringValue = parts.joined(separator: " · ")
        summary.textColor = (comparison.totalDelta ?? 0) < 0 || !comparison.newlyFailing.isEmpty
            ? Tokens.Color.ember : Tokens.Color.editorInk
    }

    private static func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }

    // MARK: - Hành động

    @objc private func rowClicked() {
        let row = table.clickedRow
        guard row >= 0 else { return }
        guard mode == .rules else { return compareSelection() }
        guard let report, row < report.results.count else { return }
        onSelectRule?(report.results[row])
    }

    @objc private func fixButtonTapped(_ sender: NSButton) {
        guard let report, sender.tag >= 0, sender.tag < report.results.count else { return }
        onFixRule?(report.results[sender.tag])
    }

    private func fixTooltip(for rule: QualityRules.Rule) -> String {
        switch QualityFix.tool(for: rule) {
        case let .manual(reason): return L("Không sửa tự động được: ") + reason
        default: return L("Mở đúng công cụ trong Bàn làm sạch, xong thì chấm lại ngay.")
        }
    }

    @objc private func exportTapped() { onExport?() }
    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var scoreTextForSelfTest: String { scoreLine.stringValue }
    var summaryForSelfTest: String { summary.stringValue }
    var ruleCountForSelfTest: Int { report?.results.count ?? 0 }
    var dimensionLabelsForSelfTest: [String] {
        dimensionRow.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
    }
    var dimensionTooltipsForSelfTest: [String] {
        dimensionRow.arrangedSubviews.compactMap { ($0 as? NSTextField)?.toolTip }
    }
    func clickRuleForSelfTest(_ index: Int) {
        guard let report, index < report.results.count else { return }
        onSelectRule?(report.results[index])
    }

    func fixRuleForSelfTest(_ index: Int) {
        guard let report, index < report.results.count else { return }
        onFixRule?(report.results[index])
    }

    func selectModeForSelfTest(_ mode: Mode) {
        modePicker.selectedSegment = mode.rawValue
        modeChanged()
    }

    var historyCountForSelfTest: Int { history.count }

    /// Chọn hai dòng lịch sử rồi so — đúng đường người dùng đi.
    func compareRowsForSelfTest(_ rows: [Int]) {
        table.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        compareSelection()
    }

    /// Chữ trên nút sửa của từng dòng — `nil` khi dòng ấy không có nút.
    var fixButtonTitlesForSelfTest: [String?] {
        guard let report else { return [] }
        return report.results.map { result in
            guard !result.passed, result.failure == nil else { return nil }
            return L(QualityFix.tool(for: result.rule).actionTitle)
        }
    }
}

extension QualityPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        mode == .rules ? (report?.results.count ?? 0) : history.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard mode == .trend else { return }
        compareSelection()
    }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard mode == .rules else { return trendCell(tableColumn, row: row) }
        guard let report, row < report.results.count, let column = tableColumn else { return nil }
        let result = report.results[row]
        let identifier = column.identifier

        if identifier.rawValue == "fix" {
            // Luật ĐẠT không có gì để sửa. Luật KHÔNG CHẠY ĐƯỢC cũng vậy — thứ hỏng ở đó là bộ
            // luật, không phải dữ liệu, và mở Bàn làm sạch cho nó là chỉ sai chỗ.
            guard !result.passed, result.failure == nil else { return nil }
            let button = NSButton()
            button.title = L(QualityFix.tool(for: result.rule).actionTitle)
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.tag = row
            button.target = self
            button.action = #selector(fixButtonTapped(_:))
            button.toolTip = fixTooltip(for: result.rule)
            return button
        }

        let label = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let made = NSTextField(labelWithString: "")
                made.identifier = identifier
                made.font = Tokens.Font.caption
                made.lineBreakMode = .byTruncatingTail
                return made
            }()

        switch identifier.rawValue {
        case "severity":
            if result.failure != nil {
                // Luật KHÔNG CHẠY ĐƯỢC là một trạng thái thứ ba, không phải "đạt" cũng không
                // phải "trượt". Gộp nó vào một trong hai là nói dối về thứ mình không biết.
                label.stringValue = L("hỏng")
                label.textColor = Tokens.Color.ember
            } else if result.passed {
                label.stringValue = L("đạt")
                label.textColor = Tokens.Color.editorInk
            } else {
                label.stringValue = result.rule.severity == .error ? L("lỗi") : L("cảnh báo")
                label.textColor = result.rule.severity == .error
                    ? Tokens.Color.error : Tokens.Color.ember
            }
        case "rule":
            label.stringValue = result.failure ?? result.rule.title
            label.toolTip = result.failure ?? result.rule.title
            label.textColor = Tokens.Color.editorInk
        case "violations":
            label.stringValue = result.failure != nil ? "—" : String(result.violations)
            label.textColor = Tokens.Color.editorInk
        default:
            label.stringValue = result.failure != nil
                ? "—" : String(format: "%.2f%%", result.violationPercent)
            label.textColor = Tokens.Color.editorInk
        }
        return label
    }

    /// Một dòng của bảng xu hướng — FR-DQR-004.
    private func trendCell(_ tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, row < history.count else { return nil }
        let snapshot = history[row]
        let identifier = column.identifier
        let label = NSTextField(labelWithString: "")
        label.font = Tokens.Font.caption
        label.lineBreakMode = .byTruncatingTail
        label.textColor = Tokens.Color.editorInk

        switch identifier.rawValue {
        case "when":
            label.stringValue = snapshot.timestamp
            label.toolTip = snapshot.sourcePath ?? ""
        case "total":
            // Mốc KHÔNG có điểm hiện `—` chứ không hiện 0 — cùng luật với chiều không chấm được.
            label.stringValue = snapshot.total.map { String(format: "%.1f", $0) } ?? "—"
        case "rows":
            label.stringValue = String(snapshot.rowCount)
        case "delta":
            // Lệch so với mốc LIỀN TRƯỚC theo thời gian, tức dòng NGAY DƯỚI (bảng mới-trước).
            let olderRow = row + 1
            guard olderRow < history.count,
                  let now = snapshot.total, let before = history[olderRow].total else {
                label.stringValue = "—"
                break
            }
            let delta = now - before
            label.stringValue = String(format: "%+.1f", delta)
            label.textColor = delta < -0.05
                ? Tokens.Color.error
                : (delta > 0.05 ? Tokens.Color.editorInk : Tokens.Color.secondaryInk)
        default:
            let failed = snapshot.rules.filter { !$0.passed }.count
            label.stringValue = "\(failed)/\(snapshot.rules.count)"
            label.textColor = failed > 0 ? Tokens.Color.ember : Tokens.Color.editorInk
        }
        return label
    }
}
