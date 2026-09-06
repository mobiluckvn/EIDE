import AppKit
import GEditorCore

/// Trình xem và sửa công thức trước khi chạy (FR-CLN-005).
///
/// Công thức đến từ máy khác, viết cho file khác. Chạy thẳng nó lên dữ liệu của mình mà không
/// nhìn là điều không ai nên làm, nên sheet này bày ra TỪNG BƯỚC và cho tắt bớt — đúng như
/// UI/UX §6.2 đòi ("trình sửa recipe liệt kê từng bước bật/tắt được").
///
/// Bên cạnh mỗi bước là kết quả đối chiếu với file ĐANG MỞ: bước nào tìm không ra cột thì nói
/// ngay ở đây, chứ không để người dùng chạy xong mới biết một nửa công thức không áp được.
final class CSVRecipeSheet: NSViewController {

    private var recipe: CSVRecipe
    private let columnNames: [String]

    /// Người dùng bấm Chạy — chỗ gọi nhận về công thức đã bật/tắt xong.
    var onRun: ((CSVRecipe) -> Void)?
    /// Chạy trên cả một thư mục. Đường này KHÔNG ghi đè: kết quả ra file mới cạnh file gốc.
    var onRunFolder: ((CSVRecipe) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let noteLabel = NSTextField(labelWithString: "")
    private let table = NSTableView()
    private let runButton = NSButton()
    private let folderButton = NSButton()

    init(recipe: CSVRecipe, columnNames: [String]) {
        self.recipe = recipe
        self.columnNames = columnNames
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))

        titleLabel.stringValue = "Công thức «\(recipe.name)» — \(recipe.steps.count) bước"
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        noteLabel.font = Tokens.Font.caption
        noteLabel.textColor = Tokens.Color.secondaryInk
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.maximumNumberOfLines = 2
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        let onColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("on"))
        onColumn.width = 26
        onColumn.minWidth = 26
        onColumn.maxWidth = 26
        onColumn.resizingMask = []
        let stepColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("step"))
        stepColumn.width = 400
        stepColumn.resizingMask = .autoresizingMask
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.width = 170
        statusColumn.minWidth = 170
        statusColumn.maxWidth = 170
        statusColumn.resizingMask = []

        table.addTableColumn(onColumn)
        table.addTableColumn(stepColumn)
        table.addTableColumn(statusColumn)
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.headerView = nil
        table.rowHeight = Tokens.Metrics.listRowHeight + 4
        table.dataSource = self
        table.delegate = self
        table.style = .plain

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        runButton.title = L("Chạy trên tài liệu này")
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"
        runButton.target = self
        runButton.action = #selector(run)
        runButton.translatesAutoresizingMaskIntoConstraints = false

        folderButton.title = L("Chạy trên thư mục…")
        folderButton.bezelStyle = .rounded
        folderButton.target = self
        folderButton.action = #selector(runFolder)
        folderButton.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton()
        cancel.title = "Hủy"
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.target = self
        cancel.action = #selector(cancelSheet)
        cancel.translatesAutoresizingMaskIntoConstraints = false

        for view in [titleLabel, noteLabel, scrollView, folderButton, runButton, cancel] {
            root.addSubview(view)
        }

        let inset = Tokens.Metrics.spacing(4)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: inset),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            noteLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            noteLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            noteLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            scrollView.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            scrollView.heightAnchor.constraint(equalToConstant: 240),

            cancel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            cancel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -inset),
            runButton.trailingAnchor.constraint(equalTo: cancel.leadingAnchor, constant: -8),
            runButton.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
            folderButton.trailingAnchor.constraint(equalTo: runButton.leadingAnchor, constant: -8),
            folderButton.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
        ])

        view = root
        refreshNote()
    }

    /// Bước này có tìm được cột trên file đang mở không.
    private func resolvedColumn(_ step: CSVRecipeStep) -> Int? {
        CSVRecipeRunner.resolve(step, in: columnNames)
    }

    private func refreshNote() {
        let missing = recipe.steps.filter { $0.enabled && resolvedColumn($0) == nil }
        if missing.isEmpty {
            noteLabel.stringValue = L("Cả công thức là MỘT bước undo. Tài liệu gốc trên đĩa không đổi cho tới khi anh lưu.")
            noteLabel.textColor = Tokens.Color.secondaryInk
        } else {
            // Nói TRƯỚC khi chạy, không để người dùng chạy xong mới biết một nửa công thức
            // không áp được.
            let names = missing.compactMap(\.columnName).map { "«\($0)»" }.joined(separator: ", ")
            noteLabel.stringValue = "\(missing.count) bước sẽ bị bỏ qua: file này không có cột \(names)."
            noteLabel.textColor = Tokens.Color.error
        }
        runButton.isEnabled = recipe.enabledCount > 0
        folderButton.isEnabled = recipe.enabledCount > 0
    }

    @objc private func toggleStep(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < recipe.steps.count else { return }
        recipe.steps[sender.tag].enabled = sender.state == .on
        refreshNote()
        table.reloadData()
    }

    @objc private func runFolder() {
        let chosen = recipe
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .OK) }
        onRunFolder?(chosen)
    }

    @objc private func run() {
        let result = recipe
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .OK) }
        onRun?(result)
    }

    @objc private func cancelSheet() {
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .cancel) }
    }

    // MARK: - Móc tự kiểm

    var recipeForSelfTest: CSVRecipe { recipe }
    var noteForSelfTest: String { noteLabel.stringValue }
    var runEnabledForSelfTest: Bool { runButton.isEnabled }
    var folderEnabledForSelfTest: Bool { folderButton.isEnabled }
    func setStepEnabledForSelfTest(_ index: Int, _ enabled: Bool) {
        guard index >= 0, index < recipe.steps.count else { return }
        recipe.steps[index].enabled = enabled
        refreshNote()
    }

    private var selfTestWindow: NSWindow?

    func loadViewForSelfTest() {
        guard selfTestWindow == nil else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentViewController = self
        window.layoutIfNeeded()
        selfTestWindow = window
    }
}

extension CSVRecipeSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { recipe.steps.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < recipe.steps.count, let tableColumn else { return nil }
        let step = recipe.steps[row]

        switch tableColumn.identifier.rawValue {
        case "on":
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleStep(_:)))
            box.state = step.enabled ? .on : .off
            box.tag = row
            return box

        case "status":
            let field = NSTextField(labelWithString: "")
            field.font = Tokens.Font.caption
            if !step.enabled {
                field.stringValue = L("tắt")
                field.textColor = Tokens.Color.secondaryInk
            } else if resolvedColumn(step) == nil {
                field.stringValue = L("không thấy cột")
                field.textColor = Tokens.Color.error
            } else {
                field.stringValue = L("sẵn sàng")
                field.textColor = Tokens.Color.secondaryInk
            }
            return field

        default:
            let field = NSTextField(labelWithString: step.displayName)
            field.font = Tokens.Font.ui
            field.lineBreakMode = .byTruncatingTail
            field.textColor = step.enabled ? Tokens.Color.editorInk : Tokens.Color.secondaryInk
            return field
        }
    }
}
