import AppKit
import GEditorCore

/// Cây thư mục của workspace (FR-DOC-308).
///
/// `NSOutlineView` nạp con theo TỪNG CẤP, đúng như `Workspace.children` đọc: mở một thư mục
/// mới là lúc hỏi bên trong nó có gì. Nạp sẵn cả cây khi mở workspace sẽ treo ngay ở thư mục
/// dự án đầu tiên có `node_modules`.
final class WorkspaceView: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Cây thư mục workspace") }

    private let titleLabel = NSTextField(labelWithString: L("Chưa mở thư mục nào"))
    private let filterField = NSSearchField()
    private let scrollView = NSScrollView()
    private let outline = NSOutlineView()

    private var root: String?
    /// Con của từng thư mục, đọc tới đâu nhớ tới đó.
    private var childrenCache: [String: [WorkspaceEntry]] = [:]
    /// Kết quả lọc; `nil` = đang hiện cây.
    private var matches: [WorkspaceEntry]?

    private var watcher: DirectoryWatcher?
    private var findToken: CancelToken?

    /// Người dùng mở một file.
    var onOpenFile: ((String) -> Void)?
    /// Người dùng chọn một lệnh trên menu ngữ cảnh.
    var onCommand: ((Command) -> Void)?

    enum Command {
        case newFile(inDirectory: String)
        case newFolder(inDirectory: String)
        case rename(String)
        case moveToTrash(String)
        case revealInFinder(String)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }


    deinit { watcher?.stop() }

    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        titleLabel.font = Tokens.Font.caption
        titleLabel.textColor = Tokens.Color.secondaryInk
        titleLabel.lineBreakMode = .byTruncatingHead
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        filterField.placeholderString = L("Tìm file trong thư mục")
        filterField.controlSize = .small
        filterField.font = Tokens.Font.caption
        filterField.target = self
        filterField.action = #selector(filterChanged)
        filterField.delegate = self
        filterField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = FunctionListView.width - 16
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.rowHeight = Tokens.Metrics.listRowHeight
        outline.dataSource = self
        outline.delegate = self
        outline.style = .plain
        outline.backgroundColor = Tokens.Color.chrome
        outline.usesAlternatingRowBackgroundColors = false
        outline.target = self
        outline.doubleAction = #selector(rowDoubleClicked)
        outline.menu = makeContextMenu()

        scrollView.documentView = outline
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

    // MARK: - Mở thư mục

    func open(root path: String) {
        watcher?.stop()
        root = path
        childrenCache.removeAll()
        matches = nil
        filterField.stringValue = ""
        titleLabel.stringValue = (path as NSString).lastPathComponent
        titleLabel.toolTip = path
        outline.reloadData()

        // Cây phải theo kịp đĩa: người dùng chạy `git checkout` ở Terminal rồi quay sang đây,
        // và một cây đứng yên sẽ nói dối về những file không còn tồn tại.
        watcher = DirectoryWatcher(root: path) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshKeepingState() }
        }
        watcher?.start()
    }

    /// Đọc lại cây nhưng GIỮ những thư mục đang mở và dòng đang chọn.
    ///
    /// Dựng lại từ đầu thì mỗi lần build chạy xong, cây tự cụp hết lại — và người dùng phải mở
    /// lại từng cấp để về đúng chỗ họ đang làm việc.
    private func refreshKeepingState() {
        let expanded = (0 ..< outline.numberOfRows)
            .compactMap { outline.item(atRow: $0) as? String }
            .filter { outline.isItemExpanded($0) }
        let selectedPath = (outline.item(atRow: outline.selectedRow) as? String)

        childrenCache.removeAll()
        outline.reloadData()

        for path in expanded { outline.expandItem(path) }
        if let selectedPath {
            let row = outline.row(forItem: selectedPath)
            if row >= 0 { outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        }
    }

    private func children(of path: String) -> [WorkspaceEntry] {
        if let cached = childrenCache[path] { return cached }
        let entries = Workspace.children(of: path)
        childrenCache[path] = entries
        return entries
    }

    private func entry(for path: String) -> WorkspaceEntry? {
        if let matches { return matches.first { $0.path == path } }
        let parent = (path as NSString).deletingLastPathComponent
        return children(of: parent).first { $0.path == path }
    }

    // MARK: - Lọc

    @objc private func filterChanged() {
        findToken?.cancel()
        guard let root else { return }
        let needle = filterField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            matches = nil
            outline.reloadData()
            titleLabel.stringValue = (root as NSString).lastPathComponent
            return
        }

        let token = CancelToken()
        findToken = token
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = Workspace.find(needle, under: root, cancelToken: token)
            DispatchQueue.main.async {
                guard let self, !token.isCancelled else { return }
                self.matches = found
                self.outline.reloadData()
                self.titleLabel.stringValue = "\(found.count) kết quả cho «\(needle)»"
            }
        }
    }

    // MARK: - Thao tác

    @objc private func rowDoubleClicked() {
        guard let path = outline.item(atRow: outline.clickedRow) as? String,
              let entry = entry(for: path) else { return }
        if entry.isDirectory {
            if outline.isItemExpanded(path) { outline.collapseItem(path) } else { outline.expandItem(path) }
        } else {
            onOpenFile?(path)
        }
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: L("File mới…"), action: #selector(newFile), keyEquivalent: "")
        menu.addItem(withTitle: L("Thư mục mới…"), action: #selector(newFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Đổi tên…"), action: #selector(renameItem), keyEquivalent: "")
        menu.addItem(withTitle: L("Chuyển vào Thùng rác"), action: #selector(trashItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Hiện trong Finder"), action: #selector(revealItem), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    /// Đường dẫn của dòng vừa bấm chuột phải; không có thì lấy gốc workspace.
    private var contextPath: String? {
        (outline.item(atRow: outline.clickedRow) as? String) ?? root
    }

    /// Thư mục để tạo mục mới: chính nó nếu là thư mục, ngược lại là thư mục CHỨA nó.
    private var contextDirectory: String? {
        guard let path = contextPath else { return nil }
        guard let entry = entry(for: path) else { return path }
        return entry.isDirectory ? path : (path as NSString).deletingLastPathComponent
    }

    @objc private func newFile() {
        guard let directory = contextDirectory else { return }
        onCommand?(.newFile(inDirectory: directory))
    }

    @objc private func newFolder() {
        guard let directory = contextDirectory else { return }
        onCommand?(.newFolder(inDirectory: directory))
    }

    @objc private func renameItem() {
        guard let path = contextPath, path != root else { return }
        onCommand?(.rename(path))
    }

    @objc private func trashItem() {
        guard let path = contextPath, path != root else { return }
        onCommand?(.moveToTrash(path))
    }

    @objc private func revealItem() {
        guard let path = contextPath else { return }
        onCommand?(.revealInFinder(path))
    }

    /// Đọc lại sau khi chính ứng dụng vừa đổi file — không chờ FSEvents báo về.
    func refreshNow() { refreshKeepingState() }

    // MARK: - Móc tự kiểm

    var rootForSelfTest: String? { root }
    var titleForSelfTest: String { titleLabel.stringValue }
    var rowCountForSelfTest: Int { outline.numberOfRows }
    var visibleNamesForSelfTest: [String] {
        (0 ..< outline.numberOfRows).compactMap {
            (outline.item(atRow: $0) as? String).map { ($0 as NSString).lastPathComponent }
        }
    }
    func expandForSelfTest(_ path: String) { outline.expandItem(path) }
    func setFilterForSelfTest(_ text: String) {
        filterField.stringValue = text
        filterChanged()
        // Lọc chạy nền; chờ nó về để bài kiểm đọc đúng thứ người dùng sẽ thấy.
        let deadline = Date().addingTimeInterval(10)
        while !text.isEmpty, matches == nil, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
    func openFileForSelfTest(_ path: String) { onOpenFile?(path) }
}

extension WorkspaceView: NSSearchFieldDelegate {
    func controlTextDidChange(_ notification: Notification) { filterChanged() }
}

extension WorkspaceView: NSOutlineViewDataSource, NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let matches { return item == nil ? matches.count : 0 }
        guard let root else { return 0 }
        let path = (item as? String) ?? root
        return children(of: path).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let matches { return matches[index].path }
        let path = (item as? String) ?? root ?? ""
        return children(of: path)[index].path
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard matches == nil, let path = item as? String else { return false }
        return entry(for: path)?.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let path = item as? String else { return nil }
        let name = (path as NSString).lastPathComponent
        let isDirectory = entry(for: path)?.isDirectory ?? false

        let identifier = NSUserInterfaceItemIdentifier("wsCell")
        let field: NSTextField
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingMiddle
        }
        field.font = Tokens.Font.ui
        field.textColor = Tokens.Color.editorInk
        // Ở chế độ lọc thì hiện cả đường dẫn tương đối: hai file cùng tên ở hai thư mục khác
        // nhau là chuyện thường, và một danh sách toàn "index.js" thì không chọn được cái nào.
        if let root, matches != nil {
            let relative = path.hasPrefix(root)
                ? String(path.dropFirst(root.count).drop(while: { $0 == "/" }))
                : path
            field.stringValue = relative
        } else {
            field.stringValue = isDirectory ? "\(name)/" : name
        }
        field.toolTip = path
        return field
    }
}
