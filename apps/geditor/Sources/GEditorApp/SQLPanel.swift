import AppKit
import GEditorCore

/// Panel truy vấn SQL trên bảng CSV đang mở (FR-CSV-407 · ADR-11).
///
/// Cùng hình dạng với panel JSONPath, và cùng lý do: truy vấn là việc LẶP — gõ, xem ra bao
/// nhiêu, sửa lại. Một hộp thoại bắt bấm OK sau mỗi lần thử sẽ biến việc ấy thành cực hình.
///
/// **Khác JSONPath ở hai chỗ, và cả hai đều do số đo quyết:**
///
/// 1. **Kết quả là một BẢNG, không phải danh sách.** `SELECT thanh_pho, SUM(doanh_thu)` trả về
///    nhiều cột, và nhét chúng vào một dòng chữ là bắt người dùng tự tách bằng mắt.
/// 2. **Chạy ở LUỒNG NỀN.** ADR-11 §2 đo được một câu `GROUP BY` trên 1 triệu hàng tốn
///    0,6–1,5 giây. Chạy trên luồng chính là app đứng hình đúng khoảng ấy — và người dùng của
///    một trình soạn thảo hàng Gigabyte sẽ gặp nó ở mọi câu truy vấn, không phải thi thoảng.
///
/// **Bốn trạng thái, và chúng phải trông khác nhau**: chưa gõ · đang chạy · truy vấn sai ·
/// không có hàng nào khớp. Gộp hai cái cuối là đẩy người dùng đi sửa dữ liệu trong khi thứ sai
/// là câu họ gõ — cùng cái bẫy mà panel JSONPath đã ghi ra.
final class SQLPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM, nếu không VoiceOver đọc ra một bảng trôi nổi không rõ của gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Truy vấn SQL") }

    static let height: CGFloat = 220

    private let field = NSTextField()
    private let summary = NSTextField(labelWithString: "")
    private let helpButton = NSButton()
    private let exportButton = NSButton()
    private let chartButton = NSButton()
    private let pivotButton = NSButton()
    private let catalogButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let table = NSTableView()

    // FR-QRY-001 — Query Workbench.
    private let historyButton = NSPopUpButton()
    private let savedButton = NSPopUpButton()
    private let parameterRow = NSStackView()
    private var parameterFields: [String: NSTextField] = [:]

    private var result: CSVQueryEngine.Result?
    private var library = QueryLibrary()

    var onQuery: ((String) -> Void)?
    var onExport: ((CSVQueryEngine.Result) -> Void)?
    var onHelp: (() -> Void)?
    var onClose: (() -> Void)?
    /// Người dùng bấm "Lưu câu này…" — tầng trên hỏi tên rồi ghi vào thư viện.
    var onSaveQuery: ((String) -> Void)?
    /// Vẽ biểu đồ từ kết quả đang hiện (FR-QRY-004).
    var onChart: ((CSVQueryEngine.Result) -> Void)?
    /// Mở sheet dựng pivot (FR-QRY-003).
    var onPivot: (() -> Void)?
    /// Mở danh mục bảng ảo (FR-QRY-005).
    var onCatalog: (() -> Void)?

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

        field.placeholderString =
            "SELECT thanh_pho, COUNT(*), SUM(doanh_thu) FROM t GROUP BY thanh_pho ORDER BY COUNT(*) DESC"
        field.font = Tokens.Font.monoInline()
        field.target = self
        // Chạy khi nhấn Enter, KHÔNG theo từng phím. Hai lý do, và lý do thứ hai nặng hơn:
        // một câu đang gõ dở gần như luôn sai cú pháp; và mỗi lần chạy là một lượt quét cả
        // bảng, nên chạy theo phím là quét lại 157 MB sau mỗi ký tự.
        field.action = #selector(runQuery)
        field.translatesAutoresizingMaskIntoConstraints = false

        summary.font = Tokens.Font.caption
        summary.textColor = Tokens.Color.editorInk
        summary.lineBreakMode = .byTruncatingTail
        summary.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (helpButton, L("Cú pháp"), #selector(showHelp)),
            (pivotButton, L("Pivot…"), #selector(pivotTapped)),
            (catalogButton, L("Nguồn…"), #selector(catalogTapped)),
            (chartButton, L("Biểu đồ"), #selector(chartTapped)),
            (exportButton, L("Xuất ra tab mới"), #selector(exportTapped)),
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
        chartButton.isEnabled = false

        table.headerView = NSTableHeaderView()
        table.rowHeight = Tokens.Metrics.listRowHeight
        table.dataSource = self
        table.delegate = self
        table.style = .plain
        table.backgroundColor = Tokens.Color.chrome
        table.usesAlternatingRowBackgroundColors = false
        table.allowsColumnResizing = true
        // Cột nở đều cho kín bề rộng. Để mặc định thì ba cột hẹp nằm dồn bên trái và phần còn
        // lại là một mảng trống có vạch chia — trông như một cột thứ tư rỗng. Đúng loại lỗi mà
        // chỉ nhìn ảnh mới thấy, và `--capture sql` đã thấy nó ngay lần chụp đầu.
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // FR-QRY-001: lịch sử và câu đã lưu.
        //
        // Hai menu RIÊNG, không gộp. Chúng khác nhau ở chỗ AI quyết định: lịch sử là thứ app tự
        // ghi, câu đã lưu là thứ người dùng cố ý đặt tên. Gộp lại thì câu quan trọng trôi mất
        // giữa hai chục lần thử.
        for (button, action) in [
            (historyButton, #selector(pickHistory)),
            (savedButton, #selector(pickSaved)),
        ] {
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
        }

        // Ô nhập tham số — chỉ hiện khi câu truy vấn CÓ tham số. Một hàng ô trống thường trực
        // là một hàng người dùng phải học cách bỏ qua.
        parameterRow.orientation = .horizontal
        parameterRow.spacing = 8
        parameterRow.translatesAutoresizingMaskIntoConstraints = false
        parameterRow.isHidden = true
        addSubview(parameterRow)

        addSubview(field)
        addSubview(summary)
        addSubview(scrollView)

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            field.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            field.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -8),

            helpButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            chartButton.leadingAnchor.constraint(equalTo: helpButton.trailingAnchor, constant: 8),
            chartButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            exportButton.leadingAnchor.constraint(equalTo: chartButton.trailingAnchor, constant: 8),
            exportButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: exportButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            pivotButton.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            pivotButton.leadingAnchor.constraint(equalTo: savedButton.trailingAnchor, constant: 8),
            catalogButton.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            catalogButton.leadingAnchor.constraint(
                equalTo: pivotButton.trailingAnchor, constant: 8),

            historyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            historyButton.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 6),
            historyButton.widthAnchor.constraint(equalToConstant: 120),
            savedButton.leadingAnchor.constraint(
                equalTo: historyButton.trailingAnchor, constant: 8),
            savedButton.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            savedButton.widthAnchor.constraint(equalToConstant: 150),

            parameterRow.leadingAnchor.constraint(
                equalTo: catalogButton.trailingAnchor, constant: 12),
            parameterRow.centerYAnchor.constraint(equalTo: historyButton.centerYAnchor),
            parameterRow.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -inset),

            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            summary.topAnchor.constraint(equalTo: historyButton.bottomAnchor, constant: 6),

            scrollView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    // MARK: - Trạng thái

    func focusField() { window?.makeFirstResponder(field) }

    var query: String { field.stringValue }

    /// Tài liệu không phải bảng dùng được — nói ra ngay thay vì để người dùng gõ vào hư vô.
    func presentUnusable(_ reason: String) {
        clearTable()
        summary.stringValue = reason
        summary.textColor = Tokens.Color.error
    }

    /// Truy vấn đang chạy ở luồng nền.
    ///
    /// Có trạng thái riêng vì một câu trên bảng lớn mất hơn một giây, và một panel im lặng
    /// trong một giây trông y hệt một panel hỏng.
    func presentRunning() {
        summary.stringValue = L("Đang chạy…")
        summary.textColor = Tokens.Color.editorInk
    }

    func present(_ result: CSVQueryEngine.Result, milliseconds: Double) {
        self.result = result
        rebuildColumns(titles: result.titles)
        table.reloadData()
        exportButton.isEnabled = !result.rows.isEmpty
        // Chỉ bật khi VẼ ĐƯỢC. Một nút bấm vào rồi hiện lỗi là một nút đáng lẽ đã tắt.
        chartButton.isEnabled = ChartData.series(from: result) != nil

        let time = String(format: "%.0f ms", milliseconds)
        // KHÔNG còn "quét N hàng" như bản engine tự viết.
        //
        // Con số ấy là sản phẩm phụ của một bộ quét tự viết chạy tuần tự; DuckDB chạy đường ống
        // song song và không có một "số hàng đã quét" nào có nghĩa để trả về. Bịa ra một con số
        // trông giống nó sẽ tệ hơn là không có, vì người dùng sẽ tin.
        if result.rows.isEmpty {
            // "Không hàng nào khớp" là một câu trả lời ĐÚNG, không phải lỗi — nên nó không đỏ.
            summary.stringValue = "Không hàng nào khớp · \(time)"
        } else {
            summary.stringValue = "\(result.rows.count) hàng · \(time)"
        }
        summary.textColor = Tokens.Color.editorInk
    }

    func presentFailure(_ message: String, query: String) {
        clearTable()
        // DuckDB đã tự chỉ vị trí trong thông điệp của nó (kèm cả dòng `LINE 1:` và dấu mũ),
        // nên không dựng thêm mũi tên thứ hai — hai mũi tên chỉ hai chỗ khác nhau thì tệ hơn
        // không có mũi tên nào.
        summary.stringValue = "⚠ " + message
        summary.textColor = Tokens.Color.error
    }

    private func clearTable() {
        result = nil
        rebuildColumns(titles: [])
        table.reloadData()
        exportButton.isEnabled = false
        chartButton.isEnabled = false
    }

    /// Dựng lại cột theo tiêu đề của kết quả.
    ///
    /// Mỗi câu truy vấn có hình dạng riêng, nên cột phải dựng lại mỗi lần. Giữ cột cũ là hiện
    /// dữ liệu của câu này dưới tiêu đề của câu trước — sai theo kiểu trông rất thuyết phục.
    private func rebuildColumns(titles: [String]) {
        for column in table.tableColumns { table.removeTableColumn(column) }
        for (index, title) in titles.enumerated() {
            let column = NSTableColumn(
                identifier: NSUserInterfaceItemIdentifier("col\(index)"))
            column.title = title
            column.width = 160
            column.minWidth = 60
            table.addTableColumn(column)
        }
        // `columnAutoresizingStyle` một mình KHÔNG đủ: nó chỉ chia lại bề rộng khi bảng đổi
        // kích thước, mà ở đây cột được thêm vào một bảng đã có kích thước sẵn. Thiếu dòng này
        // thì ba cột hẹp dồn bên trái và phần còn lại là mảng trống có vạch chia. Lần chụp thứ
        // hai của `--capture sql` mới lộ ra: lần đầu tôi tưởng đã sửa xong.
        table.sizeToFit()
    }

    // MARK: - Query Workbench (FR-QRY-001)

    /// Nạp lịch sử và câu đã lưu vào hai menu.
    func setLibrary(_ library: QueryLibrary) {
        self.library = library

        historyButton.removeAllItems()
        historyButton.addItem(withTitle: L("Lịch sử"))
        for entry in library.history.prefix(20) {
            // Cắt ngắn để menu còn đọc được, nhưng giữ ĐẦU câu: `SELECT thanh_pho, SUM(…` nói
            // được câu ấy làm gì, còn phần đuôi thì không.
            let title = entry.sql.replacingOccurrences(of: "\n", with: " ")
            historyButton.addItem(withTitle: String(title.prefix(70)))
            historyButton.lastItem?.representedObject = entry.sql
        }
        historyButton.isEnabled = !library.history.isEmpty

        savedButton.removeAllItems()
        savedButton.addItem(withTitle: L("Câu đã lưu"))
        for entry in library.saved {
            savedButton.addItem(withTitle: entry.name)
            savedButton.lastItem?.representedObject = entry.sql
        }
        savedButton.menu?.addItem(.separator())
        savedButton.addItem(withTitle: L("Lưu câu này…"))
    }

    @objc private func pickHistory(_ sender: NSPopUpButton) {
        guard let sql = sender.selectedItem?.representedObject as? String else { return }
        field.stringValue = sql
        refreshParameterFields()
        sender.selectItem(at: 0)
    }

    @objc private func pickSaved(_ sender: NSPopUpButton) {
        defer { sender.selectItem(at: 0) }
        if let sql = sender.selectedItem?.representedObject as? String {
            field.stringValue = sql
            refreshParameterFields()
            return
        }
        if sender.selectedItem?.title == L("Lưu câu này…") {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            onSaveQuery?(text)
        }
    }

    /// Dựng lại hàng ô nhập theo tham số CÓ TRONG câu đang gõ.
    ///
    /// Giữ lại giá trị đã nhập của tham số cùng tên: sửa câu truy vấn rồi phải gõ lại `:thang`
    /// là đúng thứ khiến người ta bỏ tính năng tham số và quay về sửa tay giữa câu SQL.
    private func refreshParameterFields() {
        let names = QueryParameters.names(in: field.stringValue)
        let previous = parameterFields.mapValues { $0.stringValue }
        for view in parameterRow.arrangedSubviews { parameterRow.removeArrangedSubview(view); view.removeFromSuperview() }
        parameterFields = [:]
        for name in names {
            let label = NSTextField(labelWithString: ":\(name)")
            label.font = Tokens.Font.caption
            label.textColor = Tokens.Color.editorInk
            let input = NSTextField()
            input.font = Tokens.Font.monoInline()
            input.stringValue = previous[name] ?? ""
            input.target = self
            input.action = #selector(runQuery)
            input.widthAnchor.constraint(equalToConstant: 90).isActive = true
            parameterFields[name] = input
            parameterRow.addArrangedSubview(label)
            parameterRow.addArrangedSubview(input)
        }
        parameterRow.isHidden = names.isEmpty
    }

    /// Giá trị người dùng đã nhập cho từng tham số.
    var parameterValues: [String: String] {
        parameterFields.mapValues { $0.stringValue }
    }

    // MARK: - Hành động

    @objc private func runQuery() {
        // Dựng lại ô nhập TRƯỚC khi chạy: người dùng gõ câu có `:thang` rồi nhấn Enter ngay,
        // và nếu ô nhập chỉ hiện ra sau lần chạy đầu thì lần ấy luôn chạy với NULL.
        refreshParameterFields()
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            clearTable()
            summary.stringValue = ""
            return
        }
        onQuery?(text)
    }

    @objc private func pivotTapped() { onPivot?() }
    @objc private func catalogTapped() { onCatalog?() }

    /// Đặt câu truy vấn vào ô mà KHÔNG chạy — pivot đưa câu vào đây để người dùng đọc và sửa.
    func setQuery(_ sql: String) {
        field.stringValue = sql
        refreshParameterFields()
    }

    @objc private func chartTapped() {
        guard let result else { return }
        onChart?(result)
    }

    @objc private func exportTapped() {
        guard let result else { return }
        onExport?(result)
    }

    /// Menu cú pháp bấm được, cùng lối với panel JSONPath.
    ///
    /// Danh sách này KHÔNG chỉ liệt kê thứ làm được — nửa dưới nói thẳng thứ KHÔNG làm được.
    /// Người dùng biết SQL sẽ gõ `JOIN` trong năm phút đầu, và biết trước rẻ hơn nhiều so với
    /// gõ xong mới nhận một dòng lỗi.
    @objc private func showHelp() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Bấm để chèn vào ô truy vấn"), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (snippet, explanation) in Self.syntaxHelp {
            let item = NSMenuItem(
                title: "\(snippet)      \(explanation)", action: #selector(insertSnippet(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = snippet
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let limits = NSMenuItem(
            title: L("Chưa làm: JOIN · truy vấn con · HAVING · DISTINCT · LIKE · IN · BETWEEN"
                + " · UNION · cửa sổ hàm"),
            action: nil, keyEquivalent: "")
        limits.isEnabled = false
        menu.addItem(limits)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: helpButton.bounds.height), in: helpButton)
        onHelp?()
    }

    @objc private func insertSnippet(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? String else { return }
        field.stringValue = snippet
        focusField()
    }

    static let syntaxHelp: [(String, String)] = [
        ("SELECT * FROM t LIMIT 100", L("trăm hàng đầu")),
        ("SELECT a, b FROM t", L("chọn cột")),
        ("SELECT a AS ten FROM t", L("đặt tên cột kết quả")),
        ("SELECT * FROM t WHERE a = 'x'", L("lọc theo chữ")),
        ("SELECT * FROM t WHERE a > 100", L("lọc theo số")),
        ("SELECT * FROM t WHERE a IS NULL", L("ô rỗng")),
        ("SELECT * FROM t WHERE a = 1 AND (b = 2 OR c = 3)", L("ghép điều kiện")),
        ("SELECT COUNT(*) FROM t", L("đếm hàng")),
        ("SELECT a, COUNT(*), SUM(b), AVG(b) FROM t GROUP BY a", L("gộp nhóm")),
        ("SELECT MIN(a), MAX(a) FROM t", L("nhỏ nhất, lớn nhất")),
        ("SELECT a FROM t ORDER BY a DESC LIMIT 10", L("sắp xếp và cắt")),
        ("SELECT \"ten cot\" FROM t", L("tên cột có dấu cách")),
    ]
    @objc private func closeTapped() { onClose?() }

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    var columnTitlesForSelfTest: [String] { table.tableColumns.map(\.title) }
    var rowCountForSelfTest: Int { result?.rows.count ?? 0 }
    /// Số hàng, hoặc `nil` khi CHƯA chạy được câu nào.
    ///
    /// `nil` chứ không 0: một bài tự kiểm chạy trên máy không có libduckdb cần phân biệt được
    /// "chạy ra 0 hàng" với "không chạy được" — gộp hai thứ ấy thì bài kiểm sẽ xanh trên một
    /// máy chưa bao giờ thực sự chạy truy vấn nào.
    var optionalRowCountForSelfTest: Int? { result?.rows.count }
    var isExportEnabledForSelfTest: Bool { exportButton.isEnabled }
    var isChartEnabledForSelfTest: Bool { chartButton.isEnabled }
    func tapChartForSelfTest() { chartTapped() }
    func typeQueryForSelfTest(_ text: String) {
        field.stringValue = text
        runQuery()
    }

    // FR-QRY-001
    var parameterNamesForSelfTest: [String] { parameterFields.keys.sorted() }
    var isParameterRowVisibleForSelfTest: Bool { !parameterRow.isHidden }
    var historyTitlesForSelfTest: [String] {
        historyButton.itemTitles.dropFirst().map { $0 }
    }
    var savedTitlesForSelfTest: [String] {
        savedButton.itemTitles.dropFirst().filter { $0 != L("Lưu câu này…") }
    }
    func setParameterForSelfTest(_ name: String, _ value: String) {
        parameterFields[name]?.stringValue = value
    }
    /// Gõ câu MÀ KHÔNG chạy — để bài kiểm dựng được ô nhập tham số trước khi đặt giá trị.
    func typeQueryWithoutRunningForSelfTest(_ text: String) {
        field.stringValue = text
        refreshParameterFields()
    }
}

extension SQLPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { result?.rows.count ?? 0 }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let result, row < result.rows.count,
              let tableColumn,
              let column = table.tableColumns.firstIndex(of: tableColumn),
              column < result.rows[row].count
        else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("cell")
        let label: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            label = reused
        } else {
            label = NSTextField(labelWithString: "")
            label.identifier = identifier
            label.font = Tokens.Font.monoInline()
            label.lineBreakMode = .byTruncatingTail
        }
        // `NULL` hiện thành chữ NULL chứ không thành ô trống: ô trống trong bảng kết quả
        // trông y hệt một chuỗi rỗng, và với dữ liệu thật thì hai thứ ấy khác nhau.
        label.stringValue = result.rows[row][column] ?? "NULL"
        return label
    }
}
