import AppKit
import GEditorCore

/// Panel kết quả tìm kiếm ở đáy cửa sổ (FR-SRCH-105, UI/UX §3).
///
/// Danh sách PHẲNG với hàng tiêu đề file xen giữa, chứ không phải `NSOutlineView` gập được.
/// Lý do: kết quả tìm trong thư mục thường là hàng nghìn dòng trải trên hàng trăm file, và
/// thứ người dùng làm với chúng là CUỘN rồi nhảy tới — không phải gập ra gập vào. Danh sách
/// phẳng cuộn nhanh hơn và không tốn một lần bấm để thấy kết quả đầu tiên.
final class SearchResultsView: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Kết quả tìm trong thư mục") }

    enum Row {
        case file(path: String, hits: Int)
        case hit(path: String, hit: FindInFiles.Hit)
        /// Hàng xem trước của Replace in Files — có ô đánh dấu để BỎ CHỌN từng file.
        ///
        /// TC-SRCH-07 đòi đúng điều này: xem trước 200 file, bỏ chọn 3, commit thì chỉ 197
        /// file được ghi và 3 file kia nguyên vẹn. Không có ô đánh dấu thì "xem trước" chỉ là
        /// một hộp thoại xác nhận, và người dùng phải chấp nhận cả gói hoặc bỏ cả gói.
        case replacement(plan: FindInFiles.FileReplacement)
    }

    /// Người dùng chọn một kết quả — mở file và nhảy tới đúng vị trí.
    var onOpenHit: ((String, FindInFiles.Hit) -> Void)?
    var onClose: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Người dùng bấm "Thực hiện thay" — nhận danh sách file CÒN ĐƯỢC CHỌN.
    var onCommitReplacement: (([String]) -> Void)?
    /// Bấm «Xuất» — lớp trên dựng tab mới từ lượt đang xem.
    var onExport: (() -> Void)?
    /// Chọn một lượt tìm CŨ trong danh sách lịch sử.
    var onSelectHistory: ((Int) -> Void)?

    private let table = NSTableView()
    private let scrollView = NSScrollView()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let cancelButton = NSButton(title: L("Hủy"), target: nil, action: nil)
    private var rows: [Row] = []
    /// File bị bỏ chọn trong bản xem trước. Mặc định mọi file đều được chọn.
    private var deselected: Set<String> = []
    private let commitButton = NSButton(title: L("Thực hiện thay"), target: nil, action: nil)
    private let exportButton = NSButton(title: L("Xuất"), target: nil, action: nil)

    /// Danh sách lượt tìm trước đó — SRS FR-SRCH-105 đòi «lịch sử nhiều lượt tìm».
    ///
    /// Nó có mặt vì một thói quen làm việc có thật: tìm `TODO`, đọc dở, tìm tiếp `FIXME` để so,
    /// rồi muốn quay lại danh sách đầu. Trước đây `showResults` GHI ĐÈ lượt trước, nên đường
    /// quay lại duy nhất là chạy lại cả phép tìm trên thư mục — vài giây, và trên kho lớn thì
    /// lâu hơn thế.
    private let historyPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    // MARK: - Dữ liệu

    /// Đang chạy: hiện tiến trình và nút Hủy (TC-SRCH-06 đòi hủy đáp ứng ≤ 200 ms).
    func showRunning(_ message: String) {
        summaryLabel.stringValue = message
        summaryLabel.textColor = .secondaryLabelColor
        cancelButton.isHidden = false
        rows = []
        table.reloadData()
    }

    func showResults(_ summary: FindInFiles.Summary, pattern: String) {
        rows = summary.results.flatMap { result -> [Row] in
            [.file(path: result.path, hits: result.hits.count)]
                + result.hits.map { .hit(path: result.path, hit: $0) }
        }
        let skipped = summary.filesSkipped.count
        summaryLabel.stringValue = "\(summary.totalHits) kết quả cho \"\(pattern)\" trong "
            + "\(summary.results.count)/\(summary.filesScanned) file"
            + (skipped > 0 ? " · bỏ qua \(skipped) file" : "")
            + String(format: " · %.2f s", summary.elapsed)
        summaryLabel.textColor = .secondaryLabelColor
        cancelButton.isHidden = true
        commitButton.isHidden = true
        exportButton.isHidden = summary.totalHits == 0
        table.reloadData()
    }

    /// Đổ lại danh sách lượt tìm đã lưu, và đánh dấu lượt đang xem.
    func setHistory(_ titles: [String], selected: Int) {
        historyPopUp.removeAllItems()
        historyPopUp.addItems(withTitles: titles)
        if titles.indices.contains(selected) { historyPopUp.selectItem(at: selected) }
        // Một lượt thì không có gì để chọn giữa — giấu đi thay vì hiện một popup chỉ có một
        // mục, thứ mời người dùng bấm vào rồi thấy đúng cái họ đang xem.
        historyPopUp.isHidden = titles.count < 2
    }

    /// Bản xem trước của Replace in Files: một hàng mỗi file, có ô đánh dấu.
    func showReplacementPreview(_ plans: [FindInFiles.FileReplacement], pattern: String, template: String) {
        deselected = []
        rows = plans.map { .replacement(plan: $0) }
        let total = plans.reduce(0) { $0 + $1.matchCount }
        summaryLabel.stringValue = "Xem trước: thay \(total) kết quả \"\(pattern)\" → "
            + "\"\(template)\" trong \(plans.count) file. Bỏ chọn file không muốn ghi."
        summaryLabel.textColor = .secondaryLabelColor
        cancelButton.isHidden = true
        commitButton.isHidden = plans.isEmpty
        table.reloadData()
    }

    func showMessage(_ message: String, isError: Bool = false) {
        rows = []
        summaryLabel.stringValue = message
        summaryLabel.textColor = isError ? Tokens.Color.ember : .secondaryLabelColor
        cancelButton.isHidden = true
        commitButton.isHidden = true
        table.reloadData()
    }

    // MARK: - Dựng

    private func setUp() {
        wantsLayer = true

        table.headerView = nil
        table.rowHeight = 18
        table.usesAlternatingRowBackgroundColors = false
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(openSelected)
        table.addTableColumn(NSTableColumn(identifier: .init("kq")))

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        summaryLabel.font = Tokens.Font.caption
        summaryLabel.lineBreakMode = .byTruncatingTail
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        cancelButton.font = Tokens.Font.caption
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)
        cancelButton.isHidden = true

        commitButton.bezelStyle = .rounded
        commitButton.controlSize = .small
        commitButton.font = Tokens.Font.caption
        commitButton.target = self
        commitButton.action = #selector(commitPressed)
        commitButton.isHidden = true
        commitButton.keyEquivalent = "\r"

        exportButton.bezelStyle = .rounded
        exportButton.controlSize = .small
        exportButton.font = Tokens.Font.caption
        exportButton.target = self
        exportButton.action = #selector(exportPressed)
        exportButton.toolTip = L("Mở kết quả thành một tab văn bản — lưu lại bằng ⌘S")
        exportButton.isHidden = true

        historyPopUp.controlSize = .small
        historyPopUp.font = Tokens.Font.caption
        historyPopUp.target = self
        historyPopUp.action = #selector(historyPicked)
        historyPopUp.isHidden = true
        historyPopUp.setAccessibilityLabel(L("Lượt tìm trước đó"))

        let closeButton = NSButton(title: L("Đóng"), target: self, action: #selector(closePressed))
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .small
        closeButton.font = Tokens.Font.caption

        let header = NSStackView(views: [summaryLabel, historyPopUp, exportButton,
                                         cancelButton, commitButton, closeButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = Tokens.Metrics.spacing(2)
        header.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.setContentHuggingPriority(.init(1), for: .horizontal)

        addSubview(header)
        addSubview(scrollView)

        let inset = Tokens.Metrics.spacing(3)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: Tokens.Metrics.spacing(1)),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Tokens.Metrics.spacing(1)),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
    }

    /// Chữ của từng dòng đang hiện — bài tự kiểm đọc để biết danh sách có đúng không.
    var rowTextsForSelfTest: [String] {
        rows.map { String(describing: $0) }
    }

    @objc private func closePressed() { onClose?() }
    @objc private func cancelPressed() { onCancel?() }
    @objc private func exportPressed() { onExport?() }
    @objc private func historyPicked() { onSelectHistory?(historyPopUp.indexOfSelectedItem) }

    /// Cửa cho bài tự kiểm bấm đúng hai điều khiển mới, thay vì gọi tắt vào lớp trên.
    func exportForSelfTest() { exportPressed() }
    func selectHistoryForSelfTest(_ index: Int) {
        historyPopUp.selectItem(at: index)
        historyPicked()
    }
    var historyTitlesForSelfTest: [String] { historyPopUp.itemTitles }
    var summaryForSelfTest: String { summaryLabel.stringValue }
    var canExportForSelfTest: Bool { !exportButton.isHidden }

    @objc private func commitPressed() {
        let selected = rows.compactMap { row -> String? in
            guard case .replacement(let plan) = row else { return nil }
            return deselected.contains(plan.path) ? nil : plan.path
        }
        onCommitReplacement?(selected)
    }

    @objc private func toggleFile(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        if sender.state == .on { deselected.remove(path) } else { deselected.insert(path) }
    }

    @objc private func openSelected() {
        let index = table.selectedRow
        guard index >= 0, index < rows.count else { return }
        if case .hit(let path, let hit) = rows[index] { onOpenHit?(path, hit) }
    }
}

extension SearchResultsView: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row index: Int) -> NSView? {
        let field = NSTextField(labelWithString: "")
        field.font = Tokens.Font.caption
        field.lineBreakMode = .byTruncatingTail

        switch rows[index] {
        case .file(let path, let hits):
            // Tên file đậm, đường dẫn nhạt: mắt tìm tên file trước, đường dẫn chỉ để phân biệt
            // khi trùng tên.
            let name = (path as NSString).lastPathComponent
            let directory = (path as NSString).deletingLastPathComponent
            let text = NSMutableAttributedString(
                string: "\(name)  ",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.append(NSAttributedString(
                string: "\(directory)  ·  \(hits) kết quả",
                attributes: [.font: Tokens.Font.caption, .foregroundColor: NSColor.secondaryLabelColor]
            ))
            field.attributedStringValue = text

        case .replacement(let plan):
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleFile(_:)))
            box.state = deselected.contains(plan.path) ? .off : .on
            box.identifier = NSUserInterfaceItemIdentifier(plan.path)
            box.controlSize = .small

            let delta = plan.byteDelta == 0 ? "" : String(format: " · %+d byte", plan.byteDelta)
            let label = NSTextField(labelWithString:
                "\((plan.path as NSString).lastPathComponent)  \(plan.matchCount) kết quả\(delta)")
            label.font = Tokens.Font.caption
            label.lineBreakMode = .byTruncatingTail

            let stack = NSStackView(views: [box, label])
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = Tokens.Metrics.spacing(1)
            stack.edgeInsets = NSEdgeInsets(top: 0, left: Tokens.Metrics.spacing(3), bottom: 0, right: 0)
            return stack

        case .hit(_, let hit):
            let text = NSMutableAttributedString(
                string: String(format: "    %5d:%-4d  ", hit.line, hit.byteColumn),
                attributes: [.font: Tokens.Font.caption, .foregroundColor: NSColor.tertiaryLabelColor]
            )
            text.append(NSAttributedString(
                string: hit.lineText,
                attributes: [.font: Tokens.Font.editor(), .foregroundColor: NSColor.labelColor]
            ))
            field.attributedStringValue = text
        }
        return field
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow index: Int) -> Bool {
        if case .hit = rows[index] { return true }
        return false
    }
}
