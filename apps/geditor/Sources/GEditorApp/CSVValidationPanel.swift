import AppKit
import GEditorCore

/// Panel kết quả kiểm tra dữ liệu CSV (FR-CSV-405).
///
/// Một danh sách lỗi bấm được, không phải một hộp thoại. Hộp thoại buộc người dùng đọc hết rồi
/// bấm OK, và sau khi bấm OK thì danh sách biến mất — với một file có bốn chục dòng lệch, đó là
/// bắt họ nhớ thuộc lòng số dòng rồi tự đi tìm. Panel nằm lại cho tới khi họ đóng, và mỗi dòng
/// là một cú nhảy tới đúng chỗ.
final class CSVValidationPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Danh sách lỗi dữ liệu") }

    static let height: CGFloat = 160

    private let summary = NSTextField(labelWithString: "")
    private let jumpButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let list = NSTableView()

    private var issues: [CSVIssue] = []

    /// Người dùng chọn một lỗi — chỗ gọi đưa màn hình tới đó.
    var onSelectIssue: ((CSVIssue) -> Void)?
    var onClose: (() -> Void)?

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


    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        summary.font = Tokens.Font.ui
        summary.translatesAutoresizingMaskIntoConstraints = false

        jumpButton.title = L("Tới lỗi đầu tiên")
        jumpButton.bezelStyle = .rounded
        jumpButton.font = Tokens.Font.caption
        jumpButton.target = self
        jumpButton.action = #selector(jumpToFirst)
        jumpButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.title = L("Đóng")
        closeButton.bezelStyle = .rounded
        closeButton.font = Tokens.Font.caption
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("issue"))
        column.width = 600
        list.addTableColumn(column)
        list.headerView = nil
        list.rowHeight = Tokens.Metrics.listRowHeight
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        list.target = self
        list.action = #selector(rowClicked)

        scrollView.documentView = list
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(summary)
        addSubview(jumpButton)
        addSubview(closeButton)
        addSubview(scrollView)

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            jumpButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: summary.trailingAnchor, constant: inset
            ),
            jumpButton.centerYAnchor.constraint(equalTo: summary.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: jumpButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: summary.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: inset),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    // MARK: - Nạp kết quả

    func present(_ report: CSVValidationReport, columnNames: [String]) {
        issues = report.issues
        self.columnNames = columnNames

        if report.issues.isEmpty {
            summary.stringValue = LF("Không tìm thấy lỗi trong %d hàng", report.rowsChecked)
            summary.textColor = Tokens.Color.editorInk
        } else {
            let counts = countByKind(report.issues)
            var parts: [String] = []
            if counts.columnCount > 0 { parts.append(LF("%d hàng lệch số cột", counts.columnCount)) }
            if counts.wrongType > 0 { parts.append(LF("%d ô sai kiểu dữ liệu", counts.wrongType)) }
            // Nói rõ khi danh sách đã bị cắt: "12 lỗi" và "12 lỗi đầu tiên trong số không biết
            // bao nhiêu" là hai kết luận khác hẳn, và người dùng sẽ hành động khác nhau.
            let tail = report.truncated
                ? LF(" (đã dừng ở %d lỗi đầu)", report.issues.count) : ""
            summary.stringValue = "⚠ " + parts.joined(separator: " · ") + tail
            summary.textColor = Tokens.Color.error
        }

        // Kiểu suy luận được cũng phải hiện ra: người dùng cần biết vì sao một ô bị coi là sai.
        // "Cột doanh_thu là số" giải thích được lỗi; không có nó thì lỗi trông như tùy tiện.
        let inferred = zip(columnNames, report.types)
            .filter { $0.1 != .text }
            .map { "\($0.0): \($0.1.displayName)" }
        if !inferred.isEmpty {
            summary.stringValue += L("   —   kiểu nhận ra: ") + inferred.joined(separator: ", ")
        }

        jumpButton.isEnabled = !issues.isEmpty
        list.reloadData()
    }

    private var columnNames: [String] = []

    private func countByKind(_ issues: [CSVIssue]) -> (columnCount: Int, wrongType: Int) {
        var counts = (columnCount: 0, wrongType: 0)
        for issue in issues {
            switch issue.kind {
            case .columnCount: counts.columnCount += 1
            case .wrongType: counts.wrongType += 1
            }
        }
        return counts
    }

    @objc private func jumpToFirst() {
        guard let first = issues.first else { return }
        list.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        list.scrollRowToVisible(0)
        onSelectIssue?(first)
    }

    @objc private func closeTapped() { onClose?() }

    @objc private func rowClicked() {
        let row = list.clickedRow
        guard row >= 0, row < issues.count else { return }
        onSelectIssue?(issues[row])
    }

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    /// Tên cột panel đang dùng để gọi tên chỗ sai — bài kiểm canh nó thuộc về ĐÚNG tài liệu.
    var columnNamesForSelfTest: [String] { columnNames }
    var issueCountForSelfTest: Int { issues.count }
    func issueForSelfTest(_ index: Int) -> CSVIssue? {
        index >= 0 && index < issues.count ? issues[index] : nil
    }
    func clickIssueForSelfTest(_ index: Int) {
        guard index >= 0, index < issues.count else { return }
        onSelectIssue?(issues[index])
    }
}

extension CSVValidationPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { issues.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < issues.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("issueCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.monoInline()
            field.lineBreakMode = .byTruncatingTail
        }

        let issue = issues[row]
        // Tên cột thay cho số thứ tự khi biết được: "cột doanh_thu" tìm được bằng mắt trên
        // màn hình, còn "cột 5" thì phải ngồi đếm.
        if case let .wrongType(column, expected, value) = issue.kind, column < columnNames.count {
            field.stringValue =
                LF("Hàng %d, cột %@: «%@» không phải %@",
                       issue.rowIndex + 1, columnNames[column], value, expected.displayName)
        } else {
            field.stringValue = issue.description
        }
        field.textColor = Tokens.Color.editorInk
        return field
    }
}
