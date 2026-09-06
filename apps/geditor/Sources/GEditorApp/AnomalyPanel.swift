import AppKit
import GEditorCore

/// Bảng bất thường — FR-MIN-001, phần giao diện.
///
/// Đặc tả đòi bốn thứ, và thứ khó nhất là thứ ba:
/// (a) cột điểm bất thường · (b) đánh dấu dòng qua Mark engine, **màu theo mức nặng** ·
/// (c) **thanh trượt ngưỡng, xem trước số dòng khớp ngay lập tức** · (d) xuất sang tab mới.
///
/// ## Vì sao (c) quyết định cả kiến trúc của panel này
///
/// "Xem trước ngay lập tức" nghĩa là mỗi lần thanh trượt nhích một nấc thì con số phải đổi
/// theo — vài chục lần một giây khi người ta kéo. Nếu mỗi nhịp ấy đi hỏi lại DuckDB thì trên
/// một bảng triệu dòng thanh trượt sẽ giật cứng, và NFR-PERF-02 (thao tác gõ/kéo ≤ 16 ms) vỡ.
///
/// Nên panel **đọc cột ra bộ nhớ ĐÚNG MỘT LẦN**, rồi mọi lần kéo chỉ chạy lại phép thống kê
/// trên mảng `Double` sẵn có. Phần đắt là đọc dữ liệu, không phải phép tính: một triệu số qua
/// IQR là một lần sắp xếp, tính bằng chục mili-giây.
///
/// Hệ quả phải nói rõ: mảng ấy là **ảnh chụp** tại lúc bấm "Tìm". Tài liệu sửa sau đó thì con
/// số trên thanh trượt nói về dữ liệu cũ — nên panel hiện lại số hàng đã đọc, và đóng lại khi
/// tài liệu đổi thay vì âm thầm dùng ảnh cũ.
final class AnomalyPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Bất thường") }

    static let height: CGFloat = 260

    /// Ba mức nặng, và ba màu Mark khác nhau.
    ///
    /// Đánh dấu tất cả bằng một màu thì (b) chỉ còn là "tô vàng vài trăm dòng" — người dùng vẫn
    /// phải đọc từng dòng để biết cái nào đáng xem trước. Mức tính theo BỘI của ngưỡng chứ
    /// không theo giá trị tuyệt đối, vì thang điểm khác nhau giữa các phương pháp.
    enum Severity: Int {
        case mild, moderate, severe

        static func of(score: Double, threshold: Double) -> Severity {
            guard threshold > 0 else { return .severe }
            let ratio = score / threshold
            if ratio >= 3 { return .severe }
            if ratio >= 1.5 { return .moderate }
            return .mild
        }

        /// Chỉ số màu trong `LineMarkBook`. Cách nhau để ba mức trông khác hẳn nhau.
        var markColor: Int {
            switch self {
            case .mild: return 3
            case .moderate: return 1
            case .severe: return 0
            }
        }

        var vietnamese: String {
            switch self {
            case .mild: return L("nhẹ")
            case .moderate: return L("vừa")
            case .severe: return L("nặng")
            }
        }
    }

    private let columnPopup = NSPopUpButton()
    private let methodPopup = NSPopUpButton()
    private let slider = NSSlider()
    private let previewLabel = NSTextField(labelWithString: "")
    private let methodologyLabel = NSTextField(labelWithString: "")
    private let markButton = NSButton()
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()

    /// Ảnh chụp cột đang xét. Xem ghi chú đầu tệp về vì sao nó nằm ở đây.
    private var values: [Double] = []
    private var columns: [String] = []
    private(set) var report: AnomalyDetector.Report?

    var onPickColumn: ((String) -> Void)?
    var onReveal: ((AnomalyDetector.Finding, Severity) -> Void)?
    var onMarkAll: (([(AnomalyDetector.Finding, Severity)]) -> Void)?
    var onExport: ((AnomalyDetector.Report) -> Void)?
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

        let columnLabel = NSTextField(labelWithString: L("Cột:"))
        columnPopup.target = self
        columnPopup.action = #selector(columnChanged)
        columnPopup.setAccessibilityLabel(L("Cột số cần xét"))

        let methodLabel = NSTextField(labelWithString: L("Cách:"))
        methodPopup.target = self
        methodPopup.action = #selector(recompute)
        methodPopup.setAccessibilityLabel(L("Phương pháp phát hiện"))

        slider.minValue = 1
        slider.maxValue = 6
        slider.doubleValue = 3
        slider.target = self
        slider.action = #selector(recompute)
        // `isContinuous` là điều kiện của yêu cầu (c): mặc định AppKit chỉ gửi hành động khi
        // NHẢ chuột, và khi ấy "xem trước" không còn là xem trước nữa.
        slider.isContinuous = true
        slider.setAccessibilityLabel(L("Ngưỡng"))

        previewLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        previewLabel.textColor = Tokens.Color.editorInk
        methodologyLabel.font = NSFont.systemFont(ofSize: 11)
        methodologyLabel.textColor = Tokens.Color.editorInk.withAlphaComponent(0.7)
        methodologyLabel.lineBreakMode = .byTruncatingTail
        methodologyLabel.setAccessibilityLabel(L("Phương pháp đã dùng"))

        configure(markButton, title: L("Đánh dấu"), action: #selector(markAll))
        configure(exportButton, title: L("Xuất tab mới"), action: #selector(exportTapped))
        configure(closeButton, title: L("Đóng"), action: #selector(closeTapped))

        let controls = NSStackView(views: [
            columnLabel, columnPopup, methodLabel, methodPopup,
            slider, previewLabel,
            NSView(), markButton, exportButton, closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 120).isActive = true

        buildTable()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        methodologyLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(controls)
        addSubview(methodologyLabel)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            methodologyLabel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
            methodologyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            methodologyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(
                equalTo: methodologyLabel.bottomAnchor, constant: 6),
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

    private func buildTable() {
        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(rowDoubleClicked)
        table.setAccessibilityLabel(L("Danh sách bất thường"))
        for (identifier, title, width) in [
            ("row", L("Dòng"), 70.0), ("value", L("Giá trị"), 90.0),
            ("score", L("Điểm"), 70.0), ("severity", L("Mức"), 60.0),
            ("why", L("Vì sao"), 520.0),
        ] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
    }

    // MARK: - Nạp dữ liệu

    /// Đưa ảnh chụp cột vào panel và chấm lần đầu.
    func present(values: [Double], column: String, allColumns: [String]) {
        self.values = values
        self.columns = allColumns

        columnPopup.removeAllItems()
        columnPopup.addItems(withTitles: allColumns)
        columnPopup.selectItem(withTitle: column)

        if methodPopup.numberOfItems == 0 {
            methodPopup.addItems(withTitles: [L("z-score"), L("IQR"), L("MAD")])
        }
        // Khuyến nghị theo độ lệch — CHỌN SẴN, và nói ra là đã chọn giúp. Không im lặng đổi
        // phương pháp giữa hai bộ dữ liệu mà người dùng không biết vì sao kết quả khác nhau.
        let recommended = AnomalyDetector.recommendedMethod(for: values)
        switch recommended {
        case .mad: methodPopup.selectItem(at: 2)
        case .iqr: methodPopup.selectItem(at: 1)
        case .zScore: methodPopup.selectItem(at: 0)
        }
        recompute(nil)
    }

    private var selectedMethod: AnomalyDetector.Method {
        let threshold = slider.doubleValue
        switch methodPopup.indexOfSelectedItem {
        case 1: return .iqr(k: threshold / 2)   // thang k của IQR nhỏ hơn: 1,5 là mốc quen dùng
        case 2: return .mad(threshold: threshold)
        default: return .zScore(threshold: threshold)
        }
    }

    @objc private func columnChanged() {
        guard let title = columnPopup.titleOfSelectedItem else { return }
        onPickColumn?(title)
    }

    /// Chấm lại trên ảnh chụp sẵn có. Chạy mỗi nhịp thanh trượt, nên KHÔNG chạm đĩa.
    @objc private func recompute(_ sender: Any?) {
        guard !values.isEmpty else { return }
        let method = selectedMethod
        guard let result = try? AnomalyDetector.detect(
            values, column: columnPopup.titleOfSelectedItem ?? "", method: method)
        else { return }
        report = result
        previewLabel.stringValue = String(
            format: L("%d / %d dòng (%.2f%%)"),
            result.findings.count, result.checked, result.rate)
        methodologyLabel.stringValue = result.methodology
            .replacingOccurrences(of: "\n", with: "  ")
        methodologyLabel.toolTip = result.methodology
        table.reloadData()
    }

    private func severity(_ finding: AnomalyDetector.Finding) -> Severity {
        Severity.of(score: finding.score, threshold: thresholdForSeverity)
    }

    /// Ngưỡng ĐANG dùng, theo đúng thang của phương pháp đang chọn.
    private var thresholdForSeverity: Double {
        switch selectedMethod {
        case .zScore(let t): return t
        case .mad(let t): return t
        // Điểm của IQR vốn đã tính bằng SỐ LẦN vượt ra khỏi hàng rào, nên mốc là 1.
        case .iqr: return 1
        }
    }

    @objc private func markAll() {
        guard let report else { return }
        onMarkAll?(report.findings.map { ($0, severity($0)) })
    }

    @objc private func exportTapped() {
        guard let report else { return }
        onExport?(report)
    }

    @objc private func closeTapped() { onClose?() }

    @objc private func rowDoubleClicked() {
        guard let report, table.clickedRow >= 0, table.clickedRow < report.findings.count
        else { return }
        let finding = report.findings[table.clickedRow]
        onReveal?(finding, severity(finding))
    }

    // MARK: - Móc tự kiểm

    var previewTextForSelfTest: String { previewLabel.stringValue }
    var findingCountForSelfTest: Int { report?.findings.count ?? 0 }
    func setThresholdForSelfTest(_ value: Double) {
        slider.doubleValue = value
        recompute(nil)
    }
    func selectMethodForSelfTest(_ index: Int) {
        methodPopup.selectItem(at: index)
        recompute(nil)
    }
    var selectedMethodIndexForSelfTest: Int { methodPopup.indexOfSelectedItem }
    /// Chọn cột cần xét theo TÊN — bài tự kiểm và bộ chụp ảnh cần chỉ đúng cột có nghĩa.
    ///
    /// Panel mặc định lấy cột số ĐẦU TIÊN của bảng, mà ở một bảng dẫn xuất cột ấy thường là mã
    /// định danh (`ma_tinh`, `id`) — tìm bất thường trên đó không nói lên điều gì.
    func selectColumnForSelfTest(_ name: String) {
        guard columnPopup.itemTitles.contains(name) else { return }
        columnPopup.selectItem(withTitle: name)
        onPickColumn?(name)
    }
    func severityForSelfTest(_ finding: AnomalyDetector.Finding) -> Severity { severity(finding) }
}

extension AnomalyPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { report?.findings.count ?? 0 }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let report, row < report.findings.count, let tableColumn else { return nil }
        let finding = report.findings[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "row":
            // +1 vì người dùng đếm hàng từ 1, và +1 nữa cho dòng tiêu đề. Đây là số để ĐỌC;
            // phần nhảy tới dòng đi qua `CSVRowIndex` chứ không dùng con số này.
            text = String(finding.row + 2)
        case "value": text = ChartRender.number(finding.value)
        case "score": text = ChartRender.number(finding.score)
        case "severity": text = severity(finding).vietnamese
        default: text = finding.explanation
        }
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: 11)
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = finding.explanation
        if tableColumn.identifier.rawValue == "severity" {
            field.textColor = severity(finding) == .severe
                ? Tokens.Color.ember : Tokens.Color.editorInk
        }
        return field
    }
}
