import AppKit
import GEditorCore

/// Panel truy vấn JSONPath (FR-FMT-504).
///
/// Một ô nhập và một danh sách bấm được, nằm lại cho tới khi người dùng đóng. Truy vấn là việc
/// LẶP: gõ, xem trúng bao nhiêu, sửa lại. Một hộp thoại bắt bấm OK sau mỗi lần thử sẽ biến việc
/// ấy thành cực hình, và mất luôn khả năng bấm vào kết quả để nhảy tới đúng chỗ trong file.
///
/// **Ba trạng thái, và chúng phải trông khác nhau**: chưa gõ gì · truy vấn sai · không có gì
/// khớp. Gộp hai cái sau lại là đẩy người dùng đi sửa dữ liệu trong khi thứ sai là dấu ngoặc
/// họ gõ thiếu.
final class JSONPathPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Truy vấn JSONPath") }

    static let height: CGFloat = 200

    private let field = NSTextField()
    private let summary = NSTextField(labelWithString: "")
    private let helpButton = NSButton()
    private let exportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let list = NSTableView()

    private var matches: [JSONPath.Match] = []

    /// Người dùng gõ xong một truy vấn — chỗ gọi chạy nó rồi gọi `present`.
    var onQuery: ((String) -> Void)?
    /// Người dùng chọn một kết quả — chỗ gọi đưa màn hình tới khoảng byte ấy.
    var onSelect: ((JSONPath.Match) -> Void)?
    /// Xuất mọi kết quả ra tab mới.
    var onExport: (([JSONPath.Match]) -> Void)?
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

        field.placeholderString = "$.cua_hang.sach[?(@.gia > 100000)].ten"
        field.font = Tokens.Font.monoInline()
        field.target = self
        // Chạy khi nhấn Enter, KHÔNG theo từng phím: một truy vấn đang gõ dở gần như luôn sai
        // cú pháp, và một dòng báo lỗi đỏ nhấp nháy theo từng ký tự thì không ai đọc nữa.
        field.action = #selector(runQuery)
        field.translatesAutoresizingMaskIntoConstraints = false

        summary.font = Tokens.Font.caption
        summary.textColor = Tokens.Color.editorInk
        summary.lineBreakMode = .byTruncatingTail
        summary.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (helpButton, L("Cú pháp"), #selector(showHelp)),
            (exportButton, "Xuất ra tab mới", #selector(exportTapped)),
            (closeButton, L("Đóng"), #selector(closeTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
        }
        exportButton.isEnabled = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("match"))
        column.width = 800
        list.addTableColumn(column)
        list.headerView = nil
        list.rowHeight = Tokens.Metrics.listRowHeight
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        list.backgroundColor = Tokens.Color.chrome
        list.usesAlternatingRowBackgroundColors = false
        list.target = self
        list.action = #selector(rowClicked)

        scrollView.documentView = list
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(field)
        addSubview(summary)
        addSubview(scrollView)

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            field.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            field.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -8),

            helpButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            exportButton.leadingAnchor.constraint(equalTo: helpButton.trailingAnchor, constant: 8),
            exportButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: exportButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            summary.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 6),

            scrollView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    // MARK: - Trạng thái

    func focusField() {
        window?.makeFirstResponder(field)
    }

    /// Tài liệu không phải JSON đọc được — nói ra ngay, đừng để người dùng gõ truy vấn vào hư vô.
    func presentUnusable(_ reason: String) {
        matches = []
        list.reloadData()
        exportButton.isEnabled = false
        summary.stringValue = reason
        summary.textColor = Tokens.Color.error
    }

    func present(_ matches: [JSONPath.Match], query: String) {
        self.matches = matches
        list.reloadData()
        exportButton.isEnabled = !matches.isEmpty
        if matches.isEmpty {
            // "Không có gì khớp" là một câu trả lời ĐÚNG, không phải lỗi — nên nó không đỏ.
            summary.stringValue = "Không có gì khớp `\(query)`"
            summary.textColor = Tokens.Color.editorInk
        } else {
            summary.stringValue = "\(matches.count) kết quả"
            summary.textColor = Tokens.Color.editorInk
        }
    }

    func presentFailure(_ failure: JSONPath.Failure, query: String) {
        matches = []
        list.reloadData()
        exportButton.isEnabled = false
        // Chỉ đúng chỗ sai trong CHÍNH truy vấn: người dùng nhìn thấy ký tự nào hỏng thì sửa
        // ngay, còn "truy vấn không hợp lệ" thì họ đọc lại cả dòng và đoán.
        if case .syntax(_, let offset) = failure, offset <= query.count {
            let caret = String(repeating: " ", count: offset) + "▲"
            summary.stringValue = "⚠ \(failure.message)   \(caret)"
        } else {
            summary.stringValue = "⚠ \(failure.message)"
        }
        summary.textColor = Tokens.Color.error
    }

    var query: String { field.stringValue }

    // MARK: - Hành động

    @objc private func runQuery() {
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            matches = []
            list.reloadData()
            exportButton.isEnabled = false
            summary.stringValue = ""
            return
        }
        onQuery?(text)
    }

    @objc private func rowClicked() {
        let row = list.clickedRow
        guard row >= 0, row < matches.count else { return }
        onSelect?(matches[row])
    }

    @objc private func exportTapped() { onExport?(matches) }
    @objc private func closeTapped() { onClose?() }

    /// Cú pháp viết được — đặt ngay trong app vì không ai nhớ JSONPath thuộc lòng.
    @objc private func showHelp() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Bấm để chèn vào ô truy vấn"), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (snippet, explanation) in Self.syntaxHelp {
            let item = NSMenuItem(
                title: "\(snippet)      \(explanation)", action: #selector(insertSnippet(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = snippet
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: helpButton.bounds.height), in: helpButton)
    }

    @objc private func insertSnippet(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? String else { return }
        field.stringValue = snippet
        focusField()
    }

    static let syntaxHelp: [(String, String)] = [
        ("$", "cả tài liệu"),
        ("$.ten", "khóa `ten` ở gốc"),
        ("$['dia chi']", "khóa có dấu cách"),
        ("$.sach[0]", "phần tử đầu"),
        ("$.sach[-1]", "phần tử cuối"),
        ("$.sach[*]", "mọi phần tử"),
        ("$.sach[0:2]", "lát cắt"),
        ("$.sach[0,2]", "hợp nhiều chỉ số"),
        ("$..gia", "mọi khóa `gia` ở mọi tầng"),
        ("$..*", "mọi nút"),
        ("$.sach[?(@.gia > 100000)]", "lọc theo số"),
        ("$.sach[?(@.co_san)]", "lọc theo có mặt"),
    ]

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    var matchCountForSelfTest: Int { matches.count }
    func matchForSelfTest(_ index: Int) -> JSONPath.Match? {
        index >= 0 && index < matches.count ? matches[index] : nil
    }
    func typeQueryForSelfTest(_ text: String) {
        field.stringValue = text
        runQuery()
    }
    func clickRowForSelfTest(_ index: Int) {
        guard index >= 0, index < matches.count else { return }
        onSelect?(matches[index])
    }
    func exportForSelfTest() { onExport?(matches) }
}

extension JSONPathPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { matches.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < matches.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("matchCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.monoInline()
            field.lineBreakMode = .byTruncatingTail
        }
        let match = matches[row]
        // Số dòng đứng trước: người dùng đang nhìn một file, và "dòng 128" là thứ họ đối chiếu
        // được ngay với thanh trạng thái.
        field.stringValue = "\(match.line)   \(match.path)   =   \(match.preview)"
        field.textColor = Tokens.Color.editorInk
        return field
    }
}
