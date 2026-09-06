import AppKit
import GEditorCore

/// Bảng thuộc tính cho gantt và pie — FR-MMD-004.
///
/// Đặc tả kê riêng hai loại này: *"gantt/pie — sửa qua bảng thuộc tính bên cạnh"*. Lý do nằm ở
/// chính hình vẽ: một lát bánh hay một thanh gantt **không có hai đầu để kéo**. Thao tác duy
/// nhất có nghĩa trên chúng là đổi con số và đổi tên, và một cái bảng làm việc ấy tốt hơn hẳn
/// mọi cử chỉ chuột.
///
/// Bảng này KHÔNG giữ dữ liệu của riêng nó. Mỗi lượt vẽ lại đổ dòng từ `MermaidEdit.parse`, và
/// mỗi ô sửa xong sinh một `TextEdit` áp vào buffer — buffer vẫn là nguồn sự thật duy nhất, đúng
/// như phần còn lại của cụm. Giữ một bản sao ở đây là dựng nguồn sự thật thứ hai, và nó sẽ lệch
/// ngay lần đầu người dùng sửa thẳng trong văn bản.
final class MermaidPropertyTable: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Bảng thuộc tính sơ đồ") }

    /// Người dùng sửa xong một ô: (dòng trong nguồn sơ đồ, tên mới, giá trị mới).
    var onEdit: ((_ line: Int, _ label: String, _ value: String) -> Void)?
    var onAdd: (() -> Void)?
    var onRemove: ((_ line: Int) -> Void)?

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let caption = NSTextField(labelWithString: "")
    private(set) var rows: [MermaidEdit.Row] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        let ten = NSTableColumn(identifier: .init("label"))
        ten.title = L("Tên mục")
        ten.width = 200
        let giaTri = NSTableColumn(identifier: .init("value"))
        giaTri.title = L("Giá trị")
        giaTri.width = 160
        table.addTableColumn(ten)
        table.addTableColumn(giaTri)
        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .small
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = false

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        caption.font = Tokens.Font.caption
        caption.textColor = Tokens.Color.editorInk
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)

        for (button, title, action) in [
            (addButton, L("+"), #selector(addTapped)),
            (removeButton, L("−"), #selector(removeTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
        }

        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            caption.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            addButton.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -4),
            addButton.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Đổ lại dòng sau mỗi lượt vẽ.
    func present(_ rows: [MermaidEdit.Row], kind: MermaidDiagramKind) {
        // Giữ dòng đang chọn qua các lượt đổ: mất nó thì mỗi lần preview vẽ lại (300 ms sau
        // phím cuối) người dùng lại phải bấm lại vào đúng dòng họ đang sửa.
        let dangChon = table.selectedRow >= 0 && table.selectedRow < self.rows.count
            ? self.rows[table.selectedRow].line : nil
        self.rows = rows
        caption.stringValue = String(
            format: L("%@ · %d mục — sửa thẳng trong bảng, mỗi ô một bước hoàn tác"),
            kind.vietnamese, rows.count)
        table.reloadData()
        if let dangChon, let i = rows.firstIndex(where: { $0.line == dangChon }) {
            table.selectRowIndexes([i], byExtendingSelection: false)
        }
    }

    var selectedLine: Int? {
        let row = table.selectedRow
        guard row >= 0, row < rows.count else { return nil }
        return rows[row].line
    }

    @objc private func addTapped() { onAdd?() }

    @objc private func removeTapped() {
        guard let line = selectedLine else { return NSSound.beep() }
        onRemove?(line)
    }

    // MARK: - Móc tự kiểm

    var rowCountForSelfTest: Int { rows.count }
    var captionForSelfTest: String { caption.stringValue }
    func selectRowForSelfTest(_ index: Int) {
        guard index >= 0, index < rows.count else { return }
        table.selectRowIndexes([index], byExtendingSelection: false)
    }
    func editForSelfTest(row: Int, label: String, value: String) {
        guard row >= 0, row < rows.count else { return }
        onEdit?(rows[row].line, label, value)
    }
    func addForSelfTest() { onAdd?() }
    func removeForSelfTest() { removeTapped() }
}

extension MermaidPropertyTable: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < rows.count, let column = tableColumn else { return nil }
        let laTen = column.identifier.rawValue == "label"
        let field = NSTextField(string: laTen ? rows[row].label : rows[row].value)
        field.isEditable = true
        field.isBordered = false
        field.drawsBackground = false
        field.font = Tokens.Font.caption
        field.target = self
        field.action = #selector(cellEdited(_:))
        field.tag = row * 2 + (laTen ? 0 : 1)
        return field
    }

    @objc private func cellEdited(_ sender: NSTextField) {
        let row = sender.tag / 2
        guard row < rows.count else { return }
        let laTen = sender.tag % 2 == 0
        let label = laTen ? sender.stringValue : rows[row].label
        let value = laTen ? rows[row].value : sender.stringValue
        onEdit?(rows[row].line, label, value)
    }
}
