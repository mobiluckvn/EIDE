import AppKit
import GEditorCore

/// Sidebar Function List (FR-DOC-307).
///
/// Mục lục của tài liệu đang mở: hàm, lớp, phương thức, hoặc mục cấp cao của file cấu hình.
/// Bấm một dòng là nhảy tới đúng chỗ định nghĩa.
///
/// Việc thật nó giải: một file mã ba nghìn dòng thì cuộn tay để tìm một hàm là việc người ta
/// làm hàng chục lần mỗi giờ. Notepad++ có Function List, và đó là một trong những thứ đầu
/// tiên người dùng đi tìm khi chuyển sang.
final class FunctionListView: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Danh sách hàm và lớp") }

    static let width: CGFloat = 240

    private let titleLabel = NSTextField(labelWithString: "")
    private let filterField = NSSearchField()
    private let scrollView = NSScrollView()
    private let list = NSTableView()

    /// Toàn bộ mục của tài liệu.
    private var symbols: [DocumentSymbol] = []
    /// Phần đang hiện sau khi lọc theo tên.
    private var shown: [DocumentSymbol] = []

    /// Người dùng chọn một mục — chỗ gọi đưa con nháy tới đó.
    var onSelect: ((DocumentSymbol) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    /// Vạch phân cách với vùng soạn thảo.
    ///
    /// Không có nó thì hai vùng cùng tông màu trôi vào nhau, và mắt phải tự đoán đâu là mép
    /// sidebar mỗi lần liếc sang.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Tokens.Color.separator.setFill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()
    }

    required init?(coder: NSCoder) { nil }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }


    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        titleLabel.font = Tokens.Font.caption
        titleLabel.textColor = Tokens.Color.secondaryInk
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Ô lọc theo tên: với file có hai trăm hàm thì mục lục cũng cần mục lục.
        filterField.placeholderString = L("Lọc theo tên")
        filterField.controlSize = .small
        filterField.font = Tokens.Font.caption
        filterField.target = self
        filterField.action = #selector(filterChanged)
        filterField.delegate = self
        filterField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("symbol"))
        column.width = Self.width - 16
        list.addTableColumn(column)
        list.headerView = nil
        list.rowHeight = Tokens.Metrics.listRowHeight
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        // Nền bảng phải khớp nền sidebar. Mặc định `NSTableView` tự tô TRẮNG, nên sidebar bị
        // cắt thành hai mảng màu ngay dưới ô lọc — thấy rõ trên ảnh chụp.
        list.backgroundColor = Tokens.Color.chrome
        list.usesAlternatingRowBackgroundColors = false
        list.target = self
        list.action = #selector(rowClicked)

        scrollView.documentView = list
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        for view in [titleLabel, filterField, scrollView] { addSubview(view) }

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            filterField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            filterField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            filterField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            scrollView.topAnchor.constraint(equalTo: filterField.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Nạp danh sách

    func present(_ result: DocumentOutline.Result) {
        symbols = result.symbols
        titleLabel.stringValue = result.summary
        applyFilter()
    }

    /// Đang chờ phép quét nền — nói ra để ô trống không bị đọc thành "file này không có hàm nào".
    func showScanning() {
        titleLabel.stringValue = L("Đang đọc cấu trúc tài liệu…")
    }

    @objc private func filterChanged() { applyFilter() }

    private func applyFilter() {
        let needle = filterField.stringValue.trimmingCharacters(in: .whitespaces)
        if needle.isEmpty {
            shown = symbols
        } else {
            // Dùng chung phép so của ô lọc CSV: gõ không dấu vẫn ra chữ có dấu, và người dùng
            // không phải nhớ hai luật tìm kiếm khác nhau trong cùng một ứng dụng.
            shown = symbols.filter { CSVFilter.matches($0.name, .contains(needle)) }
        }
        list.reloadData()
    }

    @objc private func rowClicked() {
        let row = list.clickedRow
        guard row >= 0, row < shown.count else { return }
        onSelect?(shown[row])
    }

    /// Đánh dấu mục chứa con nháy — để mục lục cho biết "anh đang ở đây".
    func highlight(offset: Int) {
        guard !shown.isEmpty else { return }
        var best: Int?
        for (index, symbol) in shown.enumerated() where symbol.offset <= offset {
            best = index
        }
        guard let best else { return }
        list.selectRowIndexes(IndexSet(integer: best), byExtendingSelection: false)
        list.scrollRowToVisible(best)
    }

    // MARK: - Móc tự kiểm

    var titleForSelfTest: String { titleLabel.stringValue }
    var countForSelfTest: Int { shown.count }
    var namesForSelfTest: [String] { shown.map(\.name) }
    func setFilterForSelfTest(_ text: String) {
        filterField.stringValue = text
        applyFilter()
    }
    func clickRowForSelfTest(_ index: Int) {
        guard index >= 0, index < shown.count else { return }
        onSelect?(shown[index])
    }
    var selectedRowForSelfTest: Int { list.selectedRow }
}

extension FunctionListView: NSSearchFieldDelegate {
    func controlTextDidChange(_ notification: Notification) { applyFilter() }
}

extension FunctionListView: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < shown.count else { return nil }
        let symbol = shown[row]

        let identifier = NSUserInterfaceItemIdentifier("symbolCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingTail
        }

        // Thụt lề theo mức lồng nhau: phương thức nằm dưới lớp của nó, đọc được như một mục lục.
        let indent = String(repeating: "  ", count: min(symbol.depth, 4))
        field.stringValue = "\(indent)\(icon(for: symbol.kind)) \(symbol.name)"
        field.font = Tokens.Font.ui
        field.textColor = Tokens.Color.editorInk
        field.toolTip = "Dòng \(symbol.line)"
        return field
    }

    /// Ký hiệu ngắn thay cho chữ "func"/"class": sidebar hẹp, và mỗi ký tự dành cho TÊN đều
    /// đáng giá hơn một nhãn loại mà người ta đoán được từ chính cái tên.
    private func icon(for kind: DocumentSymbol.Kind) -> String {
        switch kind {
        case .function: return "ƒ"
        case .method: return "·ƒ"
        case .type: return "◆"
        case .section: return "§"
        }
    }
}
