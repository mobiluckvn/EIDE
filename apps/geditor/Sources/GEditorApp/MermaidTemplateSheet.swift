import AppKit
import GEditorCore

/// Thư viện mẫu sơ đồ — FR-MMD-005 (*"chèn một click"*).
///
/// ## Danh sách bên trái, XEM TRƯỚC bên phải
///
/// Cùng khuôn `ClusterSheet` và `PivotSheet` — một khuôn sheet cho cả ứng dụng. Nhưng ở đây ô
/// xem trước có một việc riêng: mẫu là VĂN BẢN sẽ đi thẳng vào tài liệu, nên người dùng cần đọc
/// nó trước khi chèn. Một danh sách chỉ có tên (*"Lưu đồ quy trình duyệt"*) buộc họ chèn rồi
/// hoàn tác để biết mình vừa chèn gì.
///
/// ## Mẫu ĐẦY ĐỦ và MẨU cú pháp nằm chung một danh sách, nhưng phân nhóm rõ
///
/// Hai thứ dùng ở hai lúc khác nhau: mẫu đầy đủ khi bắt đầu một sơ đồ, mẩu khi đang viết dở.
/// Tách thành hai cửa sổ thì người dùng phải biết trước mình cần cái nào; gộp không phân nhóm
/// thì một mẩu ba dòng đứng cạnh một sơ đồ mười dòng và trông như nhau.
final class MermaidTemplateSheet: NSObject {

    private let window: NSWindow
    private let table = NSTableView()
    private let preview = NSTextView()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let insertButton = NSButton()

    /// Danh sách đã sắp: mẫu đầy đủ trước, mẩu cú pháp sau.
    private let rows: [Row]
    private var onInsert: ((MermaidTemplate) -> Void)?

    private enum Row {
        case header(String)
        case template(MermaidTemplate)
    }

    /// - Parameter kind: loại sơ đồ con nháy đang đứng trong, để đưa mẫu của loại ấy LÊN ĐẦU.
    ///   `nil` khi không xác định được.
    init(preferring kind: MermaidDiagramKind?) {
        var rows: [Row] = []
        func append(_ title: String, _ items: [MermaidTemplate]) {
            guard !items.isEmpty else { return }
            rows.append(.header(title))
            rows.append(contentsOf: items.map(Row.template))
        }
        // Loại đang soạn lên đầu: người dùng mở thư viện GIỮA lúc viết một sơ đồ tuần tự thì
        // thứ họ cần gần như chắc chắn là mẩu của sequence, không phải mẫu gantt.
        if let kind, MermaidLibrary.templates(for: kind).isEmpty == false {
            append(LF("Đang soạn: %@", kind.vietnamese),
                   MermaidLibrary.templates(for: kind))
        }
        append(L("Mẫu sơ đồ đầy đủ"), MermaidLibrary.diagramTemplates.filter {
            kind == nil || $0.kind != kind
        })
        append(L("Mẩu cú pháp"), MermaidLibrary.fragments.filter {
            kind == nil || $0.kind != kind
        })
        self.rows = rows
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 460),
            styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
    }

    func present(in parent: NSWindow?, onInsert: @escaping (MermaidTemplate) -> Void) {
        self.onInsert = onInsert
        build()
        selectFirstTemplate()
        guard let parent else { return }
        parent.beginSheet(window)
    }

    private func build() {
        let root = NSView(frame: window.contentLayoutRect)

        table.headerView = nil
        table.rowSizeStyle = .small
        table.delegate = self
        table.dataSource = self
        table.setAccessibilityLabel(L("Thư viện mẫu sơ đồ"))
        table.target = self
        table.doubleAction = #selector(insertTapped)
        let column = NSTableColumn(identifier: .init("c"))
        column.width = 240
        table.addTableColumn(column)

        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        preview.isEditable = false
        preview.isRichText = false
        preview.font = Tokens.Font.editor(size: 13)
        preview.textContainerInset = NSSize(width: 10, height: 10)
        preview.backgroundColor = Tokens.Color.editorBackground
        preview.textColor = Tokens.Color.editorInk
        let previewScroll = NSScrollView()
        previewScroll.documentView = preview
        previewScroll.hasVerticalScroller = true
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        preview.autoresizingMask = [.width]

        summaryLabel.font = Tokens.Font.caption
        summaryLabel.textColor = Tokens.Color.secondaryInk
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 2
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        insertButton.title = L("Chèn")
        insertButton.bezelStyle = .rounded
        insertButton.keyEquivalent = "\r"
        insertButton.target = self
        insertButton.action = #selector(insertTapped)
        insertButton.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton()
        cancel.title = L("Huỷ")
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.target = self
        cancel.action = #selector(cancelTapped)
        cancel.translatesAutoresizingMaskIntoConstraints = false

        for view in [listScroll, previewScroll, summaryLabel, insertButton, cancel] {
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            listScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            listScroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            listScroll.widthAnchor.constraint(equalToConstant: 240),
            listScroll.bottomAnchor.constraint(equalTo: insertButton.topAnchor, constant: -12),

            previewScroll.leadingAnchor.constraint(
                equalTo: listScroll.trailingAnchor, constant: 12),
            previewScroll.topAnchor.constraint(equalTo: listScroll.topAnchor),
            previewScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            previewScroll.bottomAnchor.constraint(
                equalTo: summaryLabel.topAnchor, constant: -8),

            summaryLabel.leadingAnchor.constraint(equalTo: previewScroll.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: previewScroll.trailingAnchor),
            summaryLabel.bottomAnchor.constraint(equalTo: insertButton.topAnchor, constant: -12),

            insertButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            insertButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            cancel.trailingAnchor.constraint(equalTo: insertButton.leadingAnchor, constant: -8),
            cancel.centerYAnchor.constraint(equalTo: insertButton.centerYAnchor),
        ])
        window.title = L("Thư viện mẫu sơ đồ")
        window.contentView = root
    }

    private func selectFirstTemplate() {
        guard let index = rows.firstIndex(where: {
            if case .template = $0 { return true } else { return false }
        }) else { return }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        showPreview(at: index)
    }

    private func showPreview(at row: Int) {
        guard case let .template(template) = rows[row] else { return }
        preview.string = template.source
        summaryLabel.stringValue = template.summary
        insertButton.isEnabled = true
    }

    private var selectedTemplate: MermaidTemplate? {
        let row = table.selectedRow
        guard row >= 0, row < rows.count, case let .template(template) = rows[row] else {
            return nil
        }
        return template
    }

    @objc private func insertTapped() {
        guard let template = selectedTemplate else { return }
        window.sheetParent?.endSheet(window)
        onInsert?(template)
    }

    @objc private func cancelTapped() {
        window.sheetParent?.endSheet(window)
    }

    // MARK: - Móc tự kiểm

    var templateCountForSelfTest: Int {
        rows.filter { if case .template = $0 { return true } else { return false } }.count
    }
    var previewTextForSelfTest: String { preview.string }
    var firstTemplateTitleForSelfTest: String? {
        for row in rows { if case let .template(template) = row { return template.title } }
        return nil
    }
    /// Chọn theo tên rồi chèn — đúng đường người dùng đi, không gọi tắt.
    @discardableResult
    func insertForSelfTest(titled title: String) -> Bool {
        guard let index = rows.firstIndex(where: {
            if case let .template(template) = $0 { return template.title == title }
            return false
        }) else { return false }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        showPreview(at: index)
        insertTapped()
        return true
    }
}

extension MermaidTemplateSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    /// Dòng tiêu đề nhóm KHÔNG chọn được — chọn nó rồi bấm Chèn thì không có gì để chèn.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .header = rows[row] { return false }
        return true
    }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        switch rows[row] {
        case let .header(title):
            label.stringValue = title.uppercased()
            label.font = Tokens.Font.caption
            label.textColor = Tokens.Color.secondaryInk
        case let .template(template):
            label.stringValue = "  " + template.title
            label.font = Tokens.Font.ui
            label.textColor = Tokens.Color.editorInk
        }
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard row >= 0, row < rows.count else { return }
        showPreview(at: row)
    }
}
