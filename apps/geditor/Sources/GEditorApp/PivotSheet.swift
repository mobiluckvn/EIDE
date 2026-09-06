import AppKit
import GEditorCore

/// Sheet dựng pivot — FR-QRY-003.
///
/// **Không chạy gì.** Nó dựng một `PivotSpec`, sinh câu SQL, và đưa câu ấy vào ô truy vấn của
/// Workbench. Người dùng thấy câu mình vừa dựng bằng chuột và sửa tiếp được — đó là nghĩa của
/// *"vừa dùng vừa học"* trong đặc tả, và cũng là lý do không có đường chạy thứ hai để lệch khỏi
/// đường của Workbench.
///
/// Xem trước câu SQL cập nhật theo TỪNG lần chọn, không chờ bấm nút: người ta học được cấu trúc
/// `GROUP BY` bằng cách thấy nó mọc ra khi mình kéo thêm một cột, không bằng cách đọc nó sau khi
/// đã xong.
final class PivotSheet: NSObject {

    private let window: NSWindow
    private let rowList = NSTableView()
    private let valueList = NSTableView()
    private let preview = NSTextField(wrappingLabelWithString: "")
    private let aggregateButton = NSPopUpButton()
    private let columnButton = NSPopUpButton()

    private let columns: [String]
    private var spec = PivotSpec()
    private var onApply: ((String) -> Void)?

    init(columns: [String]) {
        self.columns = columns
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        build()
    }

    private func build() {
        let content = NSView(frame: window.contentLayoutRect)
        content.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: L("Pivot — gộp theo cột"))
        title.font = NSFont.boldSystemFont(ofSize: 13)

        for (list, columnTitle) in [(rowList, L("Hàng (gộp nhóm)")), (valueList, L("Giá trị"))] {
            let column = NSTableColumn(identifier: .init("c"))
            column.title = columnTitle
            list.addTableColumn(column)
            list.headerView = NSTableHeaderView()
            list.rowHeight = Tokens.Metrics.listRowHeight
            list.dataSource = self
            list.delegate = self
            list.style = .plain
        }

        for name in columns { columnButton.addItem(withTitle: name) }
        for aggregate in PivotSpec.Aggregate.allCases {
            aggregateButton.addItem(withTitle: aggregate.vietnamese)
            aggregateButton.lastItem?.representedObject = aggregate.rawValue
        }

        let addRow = button(L("+ Hàng"), #selector(addRowColumn))
        let addValue = button(L("+ Giá trị"), #selector(addValue))
        let clear = button(L("Xoá hết"), #selector(clearAll))
        let cancel = button(L("Huỷ"), #selector(cancel))
        let apply = button(L("Đưa vào ô truy vấn"), #selector(apply))
        apply.keyEquivalent = "\r"

        preview.font = Tokens.Font.monoInline()
        preview.textColor = Tokens.Color.editorInk
        preview.stringValue = L("Chọn cột để dựng câu truy vấn.")

        let rowScroll = NSScrollView(); rowScroll.documentView = rowList
        let valueScroll = NSScrollView(); valueScroll.documentView = valueList
        for scroll in [rowScroll, valueScroll] {
            scroll.hasVerticalScroller = true
            scroll.borderType = .bezelBorder
        }

        let picker = NSStackView(views: [columnButton, aggregateButton, addRow, addValue, clear])
        picker.orientation = .horizontal
        picker.spacing = 8
        let lists = NSStackView(views: [rowScroll, valueScroll])
        lists.orientation = .horizontal
        lists.distribution = .fillEqually
        lists.spacing = 12
        let buttons = NSStackView(views: [NSView(), cancel, apply])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView(views: [title, picker, lists, preview, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            lists.heightAnchor.constraint(equalToConstant: 150),
            picker.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -32),
        ])
        window.contentView = content
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = Tokens.Font.caption
        return button
    }

    func present(in parent: NSWindow?, onApply: @escaping (String) -> Void) {
        self.onApply = onApply
        guard let parent else { return }
        parent.beginSheet(window)
    }

    private func refresh() {
        rowList.reloadData()
        valueList.reloadData()
        let sql = spec.sql()
        preview.stringValue = sql.isEmpty ? L("Chọn cột để dựng câu truy vấn.") : sql
    }

    // MARK: - Hành động

    @objc private func addRowColumn() {
        guard let name = columnButton.titleOfSelectedItem else { return }
        // Không thêm TRÙNG: `GROUP BY tinh, tinh` là hợp lệ với SQL và vô nghĩa với người dùng.
        guard !spec.rows.contains(name) else { return }
        spec.rows.append(name)
        refresh()
    }

    @objc private func addValue() {
        guard let name = columnButton.titleOfSelectedItem,
              let raw = aggregateButton.selectedItem?.representedObject as? String,
              let aggregate = PivotSpec.Aggregate(rawValue: raw)
        else { return }
        guard !spec.values.contains(where: { $0.column == name && $0.aggregate == aggregate })
        else { return }
        spec.values.append(.init(column: name, aggregate: aggregate))
        refresh()
    }

    @objc private func clearAll() {
        spec = PivotSpec()
        refresh()
    }

    @objc private func cancel() {
        window.sheetParent?.endSheet(window)
    }

    @objc private func apply() {
        let sql = spec.sql()
        window.sheetParent?.endSheet(window)
        guard !sql.isEmpty else { return }
        onApply?(sql)
    }

    // MARK: - Móc tự kiểm

    var previewForSelfTest: String { preview.stringValue }
    func addRowForSelfTest(_ name: String) {
        columnButton.selectItem(withTitle: name)
        addRowColumn()
    }
    func addValueForSelfTest(_ name: String, _ aggregate: PivotSpec.Aggregate) {
        columnButton.selectItem(withTitle: name)
        aggregateButton.selectItem(withTitle: aggregate.vietnamese)
        addValue()
    }
    func applyForSelfTest() -> String {
        let sql = spec.sql()
        onApply?(sql)
        return sql
    }
}

extension PivotSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === rowList ? spec.rows.count : spec.values.count
    }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        let label = NSTextField(labelWithString: "")
        label.font = Tokens.Font.caption
        label.textColor = Tokens.Color.editorInk
        if tableView === rowList {
            label.stringValue = row < spec.rows.count ? spec.rows[row] : ""
        } else if row < spec.values.count {
            let value = spec.values[row]
            label.stringValue = "\(value.aggregate.vietnamese) · \(value.column)"
        }
        return label
    }
}
