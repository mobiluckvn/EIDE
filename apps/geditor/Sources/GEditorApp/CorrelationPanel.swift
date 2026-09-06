import AppKit
import GEditorCore

/// Bảng tương quan — FR-MIN-005, phần giao diện.
///
/// ## Ma trận SỐ và heatmap là MỘT thứ, không phải hai
///
/// Đặc tả viết *"hiển thị ma trận số + heatmap"*. Cách đọc sai là dựng hai khung cạnh nhau —
/// một bảng số và một tấm màu — buộc người dùng đối chiếu bằng mắt giữa hai lưới. Cách đọc đúng
/// là **con số nằm trên nền màu của chính nó**: màu cho biết đọc ô nào trước, số cho biết chính
/// xác bao nhiêu.
///
/// Hệ quả: chữ phải đổi màu theo nền (`Correlation.heatInkHex`). Chữ đen cố định biến mất trên
/// ô lam đậm ở `r = −1` — tức đúng những ô đáng chú ý nhất là những ô không đọc được.
///
/// ## Câu «không hàm ý nhân quả» nằm TRÊN bảng, không nằm trong tooltip
///
/// Nó là thứ dễ bỏ qua nhất và cũng là thứ đặc tả nhấn mạnh nhất. Một chú thích chỉ hiện khi rê
/// chuột là một chú thích không ai đọc.
final class CorrelationPanel: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Ma trận tương quan") }

    static let height: CGFloat = 300

    private let methodPopup = NSPopUpButton()
    private let caveatLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()

    private(set) var matrix: Correlation.Matrix?
    /// Dữ liệu cột, giữ lại để dựng scatter khi bấm một ô mà không phải đọc lại đĩa — cùng lý
    /// do với ảnh chụp của `AnomalyPanel`.
    private var columnValues: [[Double]] = []

    var onChangeMethod: ((Correlation.Method) -> Void)?
    var onPickPair: ((Int, Int) -> Void)?
    var onExport: ((Correlation.Matrix) -> Void)?
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

        methodPopup.addItems(withTitles: Correlation.Method.allCases.map(\.vietnamese))
        methodPopup.target = self
        methodPopup.action = #selector(methodChanged)
        methodPopup.setAccessibilityLabel(L("Phương pháp tương quan"))

        // Chữ thường, không đậm, nhưng LUÔN hiện: một cảnh báo hét lên bị bỏ qua nhanh như một
        // cảnh báo giấu đi.
        caveatLabel.stringValue = L("Tương quan không hàm ý nhân quả.")
        caveatLabel.font = NSFont.systemFont(ofSize: 11)
        caveatLabel.textColor = Tokens.Color.ember

        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = Tokens.Color.editorInk.withAlphaComponent(0.7)
        detailLabel.lineBreakMode = .byTruncatingTail

        configure(exportButton, title: L("Xuất tab mới"), action: #selector(exportTapped))
        configure(closeButton, title: L("Đóng"), action: #selector(closeTapped))

        let controls = NSStackView(views: [
            NSTextField(labelWithString: L("Cách:")), methodPopup, caveatLabel,
            NSView(), exportButton, closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false

        table.usesAlternatingRowBackgroundColors = false
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.action = #selector(cellClicked)
        table.setAccessibilityLabel(L("Ma trận tương quan"))
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(controls)
        addSubview(detailLabel)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            detailLabel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 6),
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

    func present(_ matrix: Correlation.Matrix, columns: [[Double]]) {
        self.matrix = matrix
        self.columnValues = columns

        while table.tableColumns.count > 0 { table.removeTableColumn(table.tableColumns[0]) }
        let header = NSTableColumn(identifier: .init("__name"))
        header.title = ""
        header.width = 130
        table.addTableColumn(header)
        for (index, name) in matrix.columns.enumerated() {
            let column = NSTableColumn(identifier: .init("c\(index)"))
            column.title = name
            column.width = 78
            table.addTableColumn(column)
        }

        let strongest = matrix.strongest(limit: 1).first
        if let strongest, let value = strongest.value {
            detailLabel.stringValue = String(
                format: L("Cặp mạnh nhất: %@ ↔ %@ = %@ (n = %d). Bấm một ô để xem biểu đồ phân tán."),
                matrix.columns[strongest.row], matrix.columns[strongest.column],
                ChartRender.number(value), strongest.count)
        } else {
            detailLabel.stringValue = L("Không cặp nào đo được.")
        }
        detailLabel.toolTip = matrix.methodology
        table.reloadData()
    }

    @objc private func methodChanged() {
        let method = Correlation.Method.allCases[
            max(0, min(methodPopup.indexOfSelectedItem, Correlation.Method.allCases.count - 1))]
        onChangeMethod?(method)
    }

    @objc private func cellClicked() {
        guard let matrix, table.clickedRow >= 0 else { return }
        let column = table.clickedColumn - 1      // cột 0 là nhãn hàng
        guard column >= 0, column < matrix.columns.count,
              table.clickedRow < matrix.columns.count,
              column != table.clickedRow          // đường chéo không có gì để vẽ
        else { return }
        onPickPair?(table.clickedRow, column)
    }

    @objc private func exportTapped() {
        guard let matrix else { return }
        onExport?(matrix)
    }

    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var detailTextForSelfTest: String { detailLabel.stringValue }
    var caveatTextForSelfTest: String { caveatLabel.stringValue }
    var columnCountForSelfTest: Int { table.tableColumns.count }
    func selectMethodForSelfTest(_ index: Int) {
        methodPopup.selectItem(at: index)
        methodChanged()
    }
    func pickPairForSelfTest(_ row: Int, _ column: Int) { onPickPair?(row, column) }
    func valuesForSelfTest(_ index: Int) -> [Double] {
        index < columnValues.count ? columnValues[index] : []
    }
    func backgroundHexForSelfTest(row: Int, column: Int) -> String? {
        guard let value = matrix?.value(row, column) else { return nil }
        return Correlation.heatHex(value)
    }
}

extension CorrelationPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { matrix?.columns.count ?? 0 }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let matrix, let tableColumn, row < matrix.columns.count else { return nil }

        if tableColumn.identifier.rawValue == "__name" {
            let field = NSTextField(labelWithString: matrix.columns[row])
            field.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            field.textColor = Tokens.Color.editorInk
            field.lineBreakMode = .byTruncatingTail
            return field
        }

        guard let column = Int(tableColumn.identifier.rawValue.dropFirst()),
              let cell = matrix.cell(row, column)
        else { return nil }

        let view = HeatCell()
        if let value = cell.value {
            view.fill = hexColour(Correlation.heatHex(value))
            view.text = ChartRender.number(value)
            view.ink = hexColour(Correlation.heatInkHex(value))
            view.toolTip = String(
                format: L("%@ ↔ %@: %@ trên %d hàng"),
                matrix.columns[row], matrix.columns[column],
                ChartRender.number(value), cell.count)
        } else {
            // Ô không đo được KHÔNG được để trống — trống đọc thành "không có vấn đề gì". Cùng
            // quy ước với chiều không chấm được của bảng chất lượng (FR-DQR-002).
            view.fill = Tokens.Color.chrome
            view.text = "—"
            view.ink = Tokens.Color.editorInk.withAlphaComponent(0.5)
            view.toolTip = cell.note
        }
        return view
    }

    private func hexColour(_ hex: String) -> NSColor {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

/// Một ô heatmap: nền màu, số ở giữa.
///
/// Tự vẽ thay vì dùng `NSTextField` có `backgroundColor`, vì `NSTextField` vẽ nền theo bounds
/// của chính nó và để lại viền hở giữa các ô — một lưới heatmap có khe hở đọc thành lưới có
/// đường kẻ, và mắt lấy đường kẻ ấy làm ranh giới nhóm.
private final class HeatCell: NSView {

    var fill: NSColor = .clear { didSet { needsDisplay = true } }
    var ink: NSColor = .black { didSet { needsDisplay = true } }
    var text = "" { didSet { needsDisplay = true } }

    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityValue() -> Any? { text }
    override func accessibilityLabel() -> String? { toolTip }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        bounds.fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: ink,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        string.draw(at: NSPoint(
            x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}
