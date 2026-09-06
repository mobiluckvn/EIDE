import AppKit
import GEditorCore

/// Sheet tham số phân cụm — FR-MIN-002.
///
/// ## Đường cong WCSS vẽ NGAY TRONG SHEET, đó là yêu cầu chứ không phải trang trí
///
/// Đặc tả: *"k do người dùng chọn HOẶC gợi ý tự động bằng elbow trên đường cong WCSS (vẽ ngay
/// trong sheet tham số)"*. Lý do nằm ở chữ *"gợi ý"*: WCSS luôn giảm khi k tăng, nên không có
/// "k tối ưu" theo nghĩa thống kê — elbow chỉ là một mẹo đọc đồ thị. Đưa ra một con số trần trụi
/// («nên chọn k = 4») mà không cho thấy đường cong là biến một mẹo thành một phán quyết.
///
/// Thấy đường cong, người dùng tự đánh giá được chỗ gãy có rõ không. Đường cong mượt không có
/// chỗ gãy nào là câu trả lời *"dữ liệu này không có cấu trúc cụm rõ rệt"* — và đó là một câu
/// trả lời hữu ích mà một con số đơn lẻ không nói được.
///
/// ## Sheet KHÔNG chạy phân cụm thật
///
/// Nó chỉ dựng đường cong (rẻ: k-means trên tối đa 10 giá trị k) và trả tham số về. Cùng khuôn
/// với `PivotSheet`: một đường chạy duy nhất ở tầng trên, không có đường thứ hai để lệch.
final class ClusterSheet: NSObject {

    enum Algorithm: Int {
        case kMeans, dbscan
    }

    struct Choice {
        var columns: [String]
        var algorithm: Algorithm
        var k: Int
        var eps: Double
        var minPoints: Int
        var scaling: Clustering.Scaling
    }

    private let allColumns: [String]
    /// Dữ liệu cột, để dựng đường cong mà không phải đọc lại đĩa.
    private let values: [[Double]]

    private let columnTable = NSTableView()
    private let algorithmPopup = NSPopUpButton()
    private let scalingPopup = NSPopUpButton()
    private let kField = NSTextField()
    private let epsField = NSTextField()
    private let minPointsField = NSTextField()
    private let suggestion = NSTextField(labelWithString: "")
    private let curveView = ChartView()
    private let runButton = NSButton()

    private var selected: Set<Int> = []
    private var onRun: ((Choice) -> Void)?

    private let window: NSWindow

    init(columns: [String], values: [[Double]]) {
        self.allColumns = columns
        self.values = values
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        // Hai cột đầu chọn sẵn: phân cụm cần ít nhất hai chiều để scatter có nghĩa, và bắt
        // người dùng bấm hai lần trước khi thấy bất cứ thứ gì là một rào cản không cần thiết.
        selected = Set(columns.indices.prefix(2))
    }

    /// Mở sheet. Cùng khuôn với `PivotSheet` — một khuôn sheet trong cả ứng dụng.
    func present(in parent: NSWindow?, onRun: @escaping (Choice) -> Void) {
        self.onRun = onRun
        build()
        recomputeCurve()
        guard let parent else { return }
        parent.beginSheet(window)
    }

    private func build() {
        let root = NSView(frame: window.contentLayoutRect)

        columnTable.headerView = nil
        columnTable.rowSizeStyle = .small
        columnTable.delegate = self
        columnTable.dataSource = self
        columnTable.setAccessibilityLabel(L("Cột đưa vào phân cụm"))
        let column = NSTableColumn(identifier: .init("c"))
        column.width = 170
        columnTable.addTableColumn(column)
        let columnScroll = NSScrollView()
        columnScroll.documentView = columnTable
        columnScroll.hasVerticalScroller = true
        columnScroll.translatesAutoresizingMaskIntoConstraints = false

        algorithmPopup.addItems(withTitles: [L("k-means"), L("DBSCAN")])
        algorithmPopup.target = self
        algorithmPopup.action = #selector(algorithmChanged)
        scalingPopup.addItems(withTitles: Clustering.Scaling.allCases.map(\.vietnamese))
        scalingPopup.target = self
        scalingPopup.action = #selector(recomputeCurve)

        kField.stringValue = "3"
        epsField.stringValue = "0.5"
        minPointsField.stringValue = "4"
        for field in [kField, epsField, minPointsField] {
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        }

        suggestion.font = NSFont.systemFont(ofSize: 11)
        suggestion.textColor = Tokens.Color.editorInk.withAlphaComponent(0.75)
        suggestion.lineBreakMode = .byWordWrapping
        suggestion.maximumNumberOfLines = 3

        curveView.translatesAutoresizingMaskIntoConstraints = false
        curveView.setAccessibilityLabel(L("Đường cong WCSS"))

        runButton.title = L("Phân cụm")
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"
        runButton.target = self
        runButton.action = #selector(run)
        let cancel = NSButton(title: L("Huỷ"), target: self, action: #selector(dismissSheet))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        let parameters = NSStackView(views: [
            NSTextField(labelWithString: L("Cách:")), algorithmPopup,
            NSTextField(labelWithString: L("Chuẩn hoá:")), scalingPopup,
        ])
        parameters.orientation = .horizontal
        parameters.spacing = 6

        let numbers = NSStackView(views: [
            NSTextField(labelWithString: L("k:")), kField,
            NSTextField(labelWithString: L("eps:")), epsField,
            NSTextField(labelWithString: L("minPts:")), minPointsField,
        ])
        numbers.orientation = .horizontal
        numbers.spacing = 6

        let buttons = NSStackView(views: [NSView(), cancel, runButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let right = NSStackView(views: [parameters, numbers, suggestion, curveView, buttons])
        right.orientation = .vertical
        right.alignment = .leading
        right.spacing = 8
        right.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(columnScroll)
        root.addSubview(right)
        NSLayoutConstraint.activate([
            columnScroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            columnScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            columnScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            columnScroll.widthAnchor.constraint(equalToConstant: 180),

            right.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            right.leadingAnchor.constraint(equalTo: columnScroll.trailingAnchor, constant: 16),
            right.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            right.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),

            curveView.heightAnchor.constraint(equalToConstant: 200),
            curveView.widthAnchor.constraint(equalTo: right.widthAnchor),
        ])
        window.title = L("Phân cụm")
        window.contentView = root
        algorithmChanged()
    }

    // MARK: - Đường cong

    @objc private func algorithmChanged() {
        let isKMeans = algorithmPopup.indexOfSelectedItem == 0
        kField.isEnabled = isKMeans
        epsField.isEnabled = !isKMeans
        minPointsField.isEnabled = !isKMeans
        recomputeCurve()
    }

    /// Dựng lại đường cong gợi ý trên ẢNH CHỤP sẵn có.
    ///
    /// Với k-means: WCSS theo k. Với DBSCAN: k-distance. Hai đường cong khác nhau cho hai bài
    /// toán chọn tham số khác nhau, nhưng cùng một phép đo "chỗ gãy" — xem `Clustering.elbow`.
    @objc private func recomputeCurve() {
        let indices = selected.sorted()
        guard indices.count >= 1 else {
            suggestion.stringValue = L("Chọn ít nhất một cột.")
            curveView.show(nil, kind: .line)
            return
        }
        let names = indices.map { allColumns[$0] }
        let rows = rowsForSelection(indices)
        let scaling = Clustering.Scaling.allCases[
            max(0, min(scalingPopup.indexOfSelectedItem, Clustering.Scaling.allCases.count - 1))]

        if algorithmPopup.indexOfSelectedItem == 0 {
            guard let (curve, suggested) = try? Clustering.elbow(
                rows: rows, columns: names, maxK: 10, scaling: scaling) else {
                suggestion.stringValue = L("Không đủ dữ liệu để dựng đường cong.")
                curveView.show(nil, kind: .line)
                return
            }
            kField.stringValue = String(suggested)
            suggestion.stringValue = String(
                format: L("Elbow gợi ý k = %d. WCSS LUÔN giảm khi k tăng, nên đây là mẹo đọc đồ thị chứ không phải tiêu chí thống kê — nhìn đường cong xem chỗ gãy có rõ không."),
                suggested)
            let points = curve.map { ChartData.Point(x: Double($0.k), y: $0.wcss) }
            curveView.show(
                ChartData.series(name: "WCSS", points: points), kind: .line,
                title: L("WCSS theo k"))
        } else {
            guard let (curve, eps, note) = try? Clustering.kDistanceCurve(
                rows: rows, columns: names, minPoints: Int(minPointsField.stringValue),
                scaling: scaling) else {
                suggestion.stringValue = L("Không đủ dữ liệu để dựng đường cong.")
                curveView.show(nil, kind: .line)
                return
            }
            epsField.stringValue = ChartRender.number(eps)
            minPointsField.stringValue = String(2 * names.count)
            suggestion.stringValue = String(
                format: L("k-distance gợi ý eps = %@ (minPts mặc định 2 × số cột = %d). %@"),
                ChartRender.number(eps), 2 * names.count, note)
            let points = curve.enumerated().map {
                ChartData.Point(x: Double($0.offset), y: $0.element)
            }
            curveView.show(
                ChartData.series(name: "k-distance", points: points), kind: .line,
                title: L("Khoảng cách tới hàng xóm thứ k"))
        }
    }

    private func rowsForSelection(_ indices: [Int]) -> [[Double]] {
        let count = values.first?.count ?? 0
        return (0..<count).map { row in indices.map { values[$0][row] } }
    }

    // MARK: - Chạy

    @objc private func run() {
        let indices = selected.sorted()
        guard !indices.isEmpty else { return }
        let choice = Choice(
            columns: indices.map { allColumns[$0] },
            algorithm: algorithmPopup.indexOfSelectedItem == 0 ? .kMeans : .dbscan,
            k: max(1, Int(kField.stringValue) ?? 3),
            eps: Double(epsField.stringValue) ?? 0.5,
            minPoints: max(1, Int(minPointsField.stringValue) ?? 4),
            scaling: Clustering.Scaling.allCases[
                max(0, min(scalingPopup.indexOfSelectedItem,
                           Clustering.Scaling.allCases.count - 1))])
        let handler = onRun
        dismissSheet()
        handler?(choice)
    }

    @objc private func dismissSheet() {
        window.sheetParent?.endSheet(window)
    }

    // MARK: - Móc tự kiểm

    var suggestionForSelfTest: String { suggestion.stringValue }
    var kForSelfTest: String { kField.stringValue }
    var epsForSelfTest: String { epsField.stringValue }
    var curvePointCountForSelfTest: Int { curveView.primitiveCountForSelfTest }
    /// Dựng giao diện mà KHÔNG mở sheet — bài tự kiểm chạy không người, và một sheet mở ra sẽ
    /// treo cả lượt chạy.
    func buildForSelfTest(onRun: @escaping (Choice) -> Void) {
        self.onRun = onRun
        build()
        recomputeCurve()
    }
    func selectColumnsForSelfTest(_ indices: [Int]) {
        selected = Set(indices)
        recomputeCurve()
    }
    func selectAlgorithmForSelfTest(_ index: Int) {
        algorithmPopup.selectItem(at: index)
        algorithmChanged()
    }
    func selectScalingForSelfTest(_ index: Int) {
        scalingPopup.selectItem(at: index)
        recomputeCurve()
    }
    func runForSelfTest() { run() }
}

extension ClusterSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { allColumns.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < allColumns.count else { return nil }
        let button = NSButton(
            checkboxWithTitle: allColumns[row], target: self, action: #selector(toggleColumn(_:)))
        button.tag = row
        button.state = selected.contains(row) ? .on : .off
        button.font = NSFont.systemFont(ofSize: 11)
        return button
    }

    @objc private func toggleColumn(_ sender: NSButton) {
        if sender.state == .on { selected.insert(sender.tag) } else { selected.remove(sender.tag) }
        recomputeCurve()
    }
}
