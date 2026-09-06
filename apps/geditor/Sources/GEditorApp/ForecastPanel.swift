import AppKit
import GEditorCore

/// Bảng dự báo — FR-MIN-004, phần giao diện.
///
/// ## Phán xét đứng TRÊN biểu đồ, không nằm dưới bảng số
///
/// Đặc tả: *"nếu model không thắng baseline, nói thẳng trong kết quả"*. Chỗ đặt câu ấy quyết
/// định nó có được đọc hay không.
///
/// Thứ tự tự nhiên của một công cụ dự báo là: biểu đồ đẹp trước, số liệu sau, ghi chú cuối. Với
/// thứ tự ấy, câu *"mô hình thua baseline"* nằm ở chỗ ít người cuộn tới nhất — và người dùng đã
/// tin vào đường cong từ ba giây trước đó rồi. Nên nó nằm ngay dòng đầu, và khi mô hình thua thì
/// nó đổi màu.
///
/// ## Biểu đồ và bảng đọc CÙNG một kết quả
///
/// Không có đường tính thứ hai cho bảng số. `ChartRender.forecastPrimitives` dựng hình từ đúng
/// mảng mà bảng in ra, nên một dòng trong bảng không thể lệch khỏi một điểm trên hình.
final class ForecastPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Dự báo") }

    static let height: CGFloat = 340

    private let columnPopup = NSPopUpButton()
    private let horizonField = NSTextField()
    private let periodField = NSTextField()
    private let modelPopup = NSPopUpButton()
    private let verdictLabel = NSTextField(labelWithString: "")
    private let chart = ChartView()
    private let scrollView = NSScrollView()
    private let table = NSTableView()
    private let exportButton = NSButton()
    private let closeButton = NSButton()

    private(set) var comparison: TimeSeries.Comparison?
    private var history: [Double] = []

    var onPickColumn: ((String) -> Void)?
    var onChangeSettings: (() -> Void)?
    var onExport: ((TimeSeries.Comparison) -> Void)?
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

        columnPopup.target = self
        columnPopup.action = #selector(columnChanged)
        columnPopup.setAccessibilityLabel(L("Cột giá trị theo thời gian"))

        modelPopup.addItems(withTitles: [
            L("Holt-Winters cộng"), L("Holt-Winters nhân"),
            L("seasonal-naive"), L("naive"),
        ])
        modelPopup.target = self
        modelPopup.action = #selector(settingsChanged)
        modelPopup.setAccessibilityLabel(L("Mô hình dự báo"))

        horizonField.stringValue = "6"
        horizonField.target = self
        horizonField.action = #selector(settingsChanged)
        horizonField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        horizonField.setAccessibilityLabel(L("Số kỳ dự báo"))

        // Đặc tả: chu kỳ mùa vụ "tự phát hiện qua ACF HOẶC người dùng đặt tay". Vế thứ hai cần
        // thiết hơn vẻ ngoài của nó: ACF chỉ thấy chu kỳ có trong dữ liệu, còn người dùng biết
        // dữ liệu của mình là hàng tháng (12), hàng quý (4) hay hàng tuần (7) kể cả khi tín
        // hiệu mùa vụ yếu. Trống = tự phát hiện.
        periodField.placeholderString = L("tự")
        periodField.target = self
        periodField.action = #selector(settingsChanged)
        periodField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        periodField.setAccessibilityLabel(L("Chu kỳ mùa vụ, để trống thì tự phát hiện"))

        verdictLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        verdictLabel.lineBreakMode = .byWordWrapping
        verdictLabel.maximumNumberOfLines = 3
        verdictLabel.setAccessibilityLabel(L("Kết luận so với baseline"))

        configure(exportButton, title: L("Xuất tab mới"), action: #selector(exportTapped))
        configure(closeButton, title: L("Đóng"), action: #selector(closeTapped))

        let controls = NSStackView(views: [
            NSTextField(labelWithString: L("Cột:")), columnPopup,
            NSTextField(labelWithString: L("Mô hình:")), modelPopup,
            NSTextField(labelWithString: L("Số kỳ:")), horizonField,
            NSTextField(labelWithString: L("Chu kỳ:")), periodField,
            NSView(), exportButton, closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false

        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.setAccessibilityLabel(L("Bảng giá trị dự báo"))
        for (identifier, title, width) in [
            ("period", L("Kỳ"), 50.0), ("value", L("Dự báo"), 90.0),
            ("i80", L("Dải 80%"), 150.0), ("i95", L("Dải 95%"), 150.0),
        ] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true

        chart.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        verdictLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(controls)
        addSubview(verdictLabel)
        addSubview(chart)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            verdictLabel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
            verdictLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            verdictLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            chart.topAnchor.constraint(equalTo: verdictLabel.bottomAnchor, constant: 6),
            chart.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            chart.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            chart.heightAnchor.constraint(equalToConstant: 170),

            scrollView.topAnchor.constraint(equalTo: chart.bottomAnchor, constant: 6),
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

    func present(
        _ comparison: TimeSeries.Comparison, history: [Double], column: String,
        allColumns: [String]
    ) {
        self.comparison = comparison
        self.history = history

        if columnPopup.itemTitles != allColumns {
            columnPopup.removeAllItems()
            columnPopup.addItems(withTitles: allColumns)
        }
        columnPopup.selectItem(withTitle: column)

        verdictLabel.stringValue = comparison.verdict
        // Đổi màu khi mô hình THUA. Cùng chữ, cùng chỗ, nhưng mắt bắt được ngay cả khi người
        // dùng chưa đọc.
        verdictLabel.textColor = comparison.modelBeatsBaselines
            ? Tokens.Color.editorInk
            : Tokens.Color.ember
        verdictLabel.toolTip = comparison.methodology

        redrawChart()
        table.reloadData()
    }

    private func redrawChart() {
        guard let comparison else { return }
        let forecast = comparison.chosen
        var note = ""
        if let accuracy = forecast.accuracy {
            note = String(
                format: L("MAE %@ · MAPE %@"),
                ChartRender.number(accuracy.mae),
                accuracy.mape.map { ChartRender.number($0) + "%" } ?? L("không tính được"))
        }
        chart.showRaw(ChartRender.forecastPrimitives(
            history: history, fitted: forecast.fitted, future: forecast.future,
            lower80: forecast.lower80, upper80: forecast.upper80,
            lower95: forecast.lower95, upper95: forecast.upper95,
            layout: ChartRender.Layout(
                width: Double(max(1, chart.bounds.width)),
                height: Double(max(1, chart.bounds.height))),
            title: forecast.model.vietnamese, note: note))
    }

    override func layout() {
        super.layout()
        // Danh sách hình phụ thuộc kích thước, nên phải dựng lại khi khung đổi. Rẻ: đây là hình
        // học thuần tuý trên vài chục điểm, không phải chạy lại mô hình.
        redrawChart()
    }

    var selectedModel: TimeSeries.Model {
        TimeSeries.Model.allCases[
            max(0, min(modelPopup.indexOfSelectedItem, TimeSeries.Model.allCases.count - 1))]
    }

    var horizon: Int { max(1, Int(horizonField.stringValue) ?? 6) }

    /// `nil` = để ACF tự tìm.
    var period: Int? {
        guard let value = Int(periodField.stringValue.trimmingCharacters(in: .whitespaces)),
              value >= 2 else { return nil }
        return value
    }

    @objc private func columnChanged() {
        guard let title = columnPopup.titleOfSelectedItem else { return }
        onPickColumn?(title)
    }

    @objc private func settingsChanged() { onChangeSettings?() }

    @objc private func exportTapped() {
        guard let comparison else { return }
        onExport?(comparison)
    }

    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var verdictTextForSelfTest: String { verdictLabel.stringValue }
    var verdictIsWarningForSelfTest: Bool { verdictLabel.textColor == Tokens.Color.ember }
    var rowCountForSelfTest: Int { table.numberOfRows }
    var svgForSelfTest: String { chart.svgForSelfTest }
    func setHorizonForSelfTest(_ value: Int) {
        horizonField.stringValue = String(value)
        settingsChanged()
    }
    func setPeriodForSelfTest(_ value: Int?) {
        periodField.stringValue = value.map(String.init) ?? ""
        settingsChanged()
    }
    func selectModelForSelfTest(_ index: Int) {
        modelPopup.selectItem(at: index)
        settingsChanged()
    }
}

extension ForecastPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { comparison?.chosen.future.count ?? 0 }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let forecast = comparison?.chosen, row < forecast.future.count,
              let tableColumn else { return nil }
        let text: String
        switch tableColumn.identifier.rawValue {
        case "period": text = "+\(row + 1)"
        case "value": text = ChartRender.number(forecast.future[row])
        case "i80":
            text = "\(ChartRender.number(forecast.lower80[row])) … "
                + ChartRender.number(forecast.upper80[row])
        default:
            text = "\(ChartRender.number(forecast.lower95[row])) … "
                + ChartRender.number(forecast.upper95[row])
        }
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        return field
    }
}
