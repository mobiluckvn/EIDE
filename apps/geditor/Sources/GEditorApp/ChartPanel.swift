import AppKit
import GEditorCore

/// Panel biểu đồ — FR-QRY-004.
///
/// Mỏng có chủ ý: nó là một `ChartView` cộng một menu chọn loại và hai nút xuất. Mọi thứ đáng
/// kiểm đã nằm ở lõi (`ChartData`, `ChartRender`) và ở `ChartView`.
final class ChartPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Biểu đồ") }

    static let height: CGFloat = 300

    let chart = ChartView()
    private let kindButton = NSPopUpButton()
    private let note = NSTextField(labelWithString: "")
    private let pngButton = NSButton()
    private let svgButton = NSButton()
    private let closeButton = NSButton()

    private var result: CSVQueryEngine.Result?
    private var direct: (series: ChartData.Series, trendLine: (slope: Double, intercept: Double)?)?
    private var directGroups: [Int]?

    var onExportPNG: (() -> Void)?
    var onExportSVG: (() -> Void)?
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

        for kind in ChartData.Kind.allCases {
            kindButton.addItem(withTitle: kind.vietnamese)
            kindButton.lastItem?.representedObject = kind.rawValue
        }
        kindButton.bezelStyle = .rounded
        kindButton.font = Tokens.Font.caption
        kindButton.target = self
        kindButton.action = #selector(kindChanged)
        kindButton.translatesAutoresizingMaskIntoConstraints = false

        note.font = Tokens.Font.caption
        note.textColor = Tokens.Color.editorInk
        note.lineBreakMode = .byTruncatingTail
        note.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (pngButton, L("Xuất PNG"), #selector(exportPNG)),
            (svgButton, L("Xuất SVG"), #selector(exportSVG)),
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

        chart.translatesAutoresizingMaskIntoConstraints = false
        addSubview(kindButton)
        addSubview(note)
        addSubview(chart)

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            kindButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            kindButton.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            kindButton.widthAnchor.constraint(equalToConstant: 130),

            note.leadingAnchor.constraint(equalTo: kindButton.trailingAnchor, constant: 12),
            note.centerYAnchor.constraint(equalTo: kindButton.centerYAnchor),
            note.trailingAnchor.constraint(lessThanOrEqualTo: pngButton.leadingAnchor, constant: -12),

            pngButton.centerYAnchor.constraint(equalTo: kindButton.centerYAnchor),
            svgButton.leadingAnchor.constraint(equalTo: pngButton.trailingAnchor, constant: 8),
            svgButton.centerYAnchor.constraint(equalTo: kindButton.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: svgButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: kindButton.centerYAnchor),

            chart.topAnchor.constraint(equalTo: kindButton.bottomAnchor, constant: 6),
            chart.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            chart.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            chart.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    /// Nạp kết quả truy vấn và vẽ.
    ///
    /// Trả `false` khi bảng không có cột SỐ nào — tầng trên nói ra bằng banner. Vẽ biểu đồ từ
    /// một bảng toàn chữ là vẽ ra một thứ không có nghĩa.
    @discardableResult
    func present(_ result: CSVQueryEngine.Result, title: String) -> Bool {
        self.result = result
        direct = nil
        directGroups = nil
        guard ChartData.series(from: result) != nil else {
            chart.show(nil, kind: currentKind)
            note.stringValue = L("Bảng này không có cột số nào để vẽ.")
            pngButton.isEnabled = false
            svgButton.isEnabled = false
            return false
        }
        pngButton.isEnabled = true
        svgButton.isEnabled = true
        redraw(title: title)
        return true
    }

    /// Đường vẽ THẲNG, không đi qua một kết quả truy vấn — dùng cho scatter hai cột của
    /// FR-MIN-005.
    ///
    /// Câu «Tương quan không hàm ý nhân quả» đi vào `samplingNote` của dãy, tức được vẽ NGAY
    /// TRÊN hình. Đó là chỗ duy nhất đúng: đặc tả đòi *"mọi kết quả kèm chú thích cố định"*, mà
    /// biểu đồ này sẽ được xuất ra PNG rồi dán vào báo cáo — một chú thích nằm ở nhãn dưới
    /// panel sẽ rụng lại ở đây và tấm ảnh đi ra ngoài mà không mang theo cảnh báo nào.
    func showScatter(
        points: [ChartData.Point], title: String,
        trendLine: (slope: Double, intercept: Double)?, caveat: String
    ) {
        result = nil
        // `ChartData.series` rút gọn khi cần và TỰ ghi lại là đã rút gọn — ghép câu chú thích
        // vào sau chứ không thay thế, vì hai câu nói hai chuyện khác nhau và cả hai đều phải
        // đi theo tấm ảnh.
        var series = ChartData.series(name: title, points: points)
        series.samplingNote = [series.samplingNote, caveat]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        direct = (series: series, trendLine: trendLine)
        directGroups = nil
        kindButton.selectItem(withTitle: ChartData.Kind.scatter.vietnamese)
        pngButton.isEnabled = true
        svgButton.isEnabled = true
        chart.show(series, kind: .scatter, title: title, trendLine: trendLine)
        note.stringValue = series.samplingNote
    }

    /// Scatter tô màu theo cụm — FR-MIN-002.
    ///
    /// Ghi chú lấy mẫu silhouette (nếu có) đi vào hình, cùng lý do với câu chú thích nhân quả
    /// của FR-MIN-005: tấm ảnh sẽ rời khỏi ứng dụng và phải tự nói được nó là ước lượng.
    func showClusters(
        points: [ChartData.Point], groups: [Int], title: String, note: String
    ) {
        result = nil
        // KHÔNG rút gọn ở đây: LTTB chọn điểm theo hình dáng đường, mà scatter phân cụm không
        // có đường nào — rút gọn sẽ vứt bỏ đúng những điểm rìa làm nên hình dạng cụm, và nhãn
        // nhóm sẽ lệch khỏi điểm. Bảng lớn thì hình dày đặc, và đó là sự thật của dữ liệu.
        var series = ChartData.Series(
            name: title, points: points, originalCount: points.count)
        series.samplingNote = note
        direct = (series: series, trendLine: nil)
        directGroups = groups
        kindButton.selectItem(withTitle: ChartData.Kind.scatter.vietnamese)
        pngButton.isEnabled = true
        svgButton.isEnabled = true
        chart.show(series, kind: .scatter, title: title, pointGroups: groups)
        self.note.stringValue = note
    }

    private var currentKind: ChartData.Kind {
        (kindButton.selectedItem?.representedObject as? String)
            .flatMap(ChartData.Kind.init(rawValue:)) ?? .bar
    }

    private func redraw(title: String = "") {
        if let direct {
            // Đổi loại biểu đồ trên một scatter hai cột: vẫn vẽ được (cột, đường…), nhưng đường
            // hồi quy chỉ có nghĩa trên phân tán nên `ChartRender` tự bỏ qua nó.
            chart.show(direct.series, kind: currentKind, title: title,
                       trendLine: direct.trendLine, pointGroups: directGroups)
            note.stringValue = direct.series.samplingNote
            return
        }
        guard let result else { return }
        let kind = currentKind
        // Phân bố cần dãy dựng theo KHOẢNG, không phải dãy điểm thô.
        let series = kind == .histogram
            ? ChartData.histogramSeries(from: result)
            : ChartData.series(from: result)
        chart.show(series, kind: kind, title: title)
        note.stringValue = series?.samplingNote ?? ""
    }

    @objc private func kindChanged() { redraw() }
    @objc private func exportPNG() { onExportPNG?() }
    @objc private func exportSVG() { onExportSVG?() }
    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var noteForSelfTest: String { note.stringValue }
    var isExportEnabledForSelfTest: Bool { pngButton.isEnabled }
    func selectKindForSelfTest(_ kind: ChartData.Kind) {
        kindButton.selectItem(withTitle: kind.vietnamese)
        redraw()
    }
    /// Đọc SVG của hình đang vẽ. Đi qua `ChartView` chứ không dựng lại danh sách hình ở đây —
    /// nếu bài kiểm dựng riêng thì nó kiểm một hình khác với hình trên màn hình.
    var svgForSelfTest: String { chart.svgForSelfTest }
}
