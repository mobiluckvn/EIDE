import AppKit
import GEditorCore

/// Panel chế độ JSONL — FR-KNW-901 và FR-KNW-902.
///
/// Ba tab, và ba tab ấy là ba câu hỏi khác nhau về cùng một tệp:
///
/// | Tab | Câu hỏi | FR |
/// |---|---|---|
/// | Bản ghi | *bản ghi tôi đang đứng trông thế nào* | 901 |
/// | Lỗi | *dòng nào hỏng, hỏng vì gì* | 901 |
/// | Chunk | *tệp này là corpus kiểu gì, chunk dài ngắn ra sao* | 902 |
///
/// ## Vì sao là PANEL chứ không phải một cửa sổ riêng
///
/// FR-KNW-901 viết *"xem record dạng thẻ (pretty) **song song** văn bản thô"*. Chữ "song song"
/// là điều kiện: người dùng đọc thẻ để hiểu, rồi sửa ở văn bản thô. Một cửa sổ riêng che mất
/// văn bản thô, và một hộp thoại thì bắt đóng lại trước khi sửa được gì.
final class JSONLPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM, nếu không VoiceOver đọc ra một danh sách trôi nổi.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Chế độ JSONL") }

    static let height: CGFloat = 260

    enum Tab: Int { case record, problems, chunks }

    private let tabs = NSSegmentedControl()
    private let summary = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let cancelButton = NSButton()
    private let closeButton = NSButton()
    private let filterPopup = NSPopUpButton()

    private let cardScroll = NSScrollView()
    private let card = NSTextView()
    private let listScroll = NSScrollView()
    private let list = NSTableView()

    private var problems: [JSONLScan.Problem] = []
    private var jumpRows: [(line: Int, detail: String)] = []
    private var inspection: ChunkInspector.Report?
    private var filterChoices: [(field: String, value: String, label: String)] = []

    /// Người dùng bấm một dòng — chỗ gọi đưa con nháy tới dòng ấy.
    var onSelectLine: ((Int) -> Void)?
    var onCancelScan: (() -> Void)?
    /// Người dùng chọn một bộ lọc metadata (`nil` = bỏ lọc).
    var onFilter: ((_ field: String, _ value: String) -> Void)?
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

        tabs.segmentCount = 3
        tabs.setLabel(L("Bản ghi"), forSegment: 0)
        tabs.setLabel(L("Lỗi"), forSegment: 1)
        tabs.setLabel(L("Chunk"), forSegment: 2)
        tabs.selectedSegment = 0
        tabs.segmentStyle = .rounded
        tabs.font = Tokens.Font.caption
        tabs.target = self
        tabs.action = #selector(tabChanged)
        tabs.translatesAutoresizingMaskIntoConstraints = false

        summary.font = Tokens.Font.caption
        summary.textColor = Tokens.Color.editorInk
        summary.lineBreakMode = .byTruncatingTail
        summary.translatesAutoresizingMaskIntoConstraints = false

        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.isHidden = true
        progress.controlSize = .small
        progress.translatesAutoresizingMaskIntoConstraints = false

        filterPopup.font = Tokens.Font.caption
        filterPopup.target = self
        filterPopup.action = #selector(filterChanged)
        filterPopup.isHidden = true
        filterPopup.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (cancelButton, L("Huỷ"), #selector(cancelTapped)),
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
        cancelButton.isHidden = true

        card.isEditable = false
        card.isSelectable = true
        card.font = Tokens.Font.monoInline()
        card.drawsBackground = false
        card.textContainerInset = NSSize(width: 6, height: 6)
        cardScroll.documentView = card
        cardScroll.hasVerticalScroller = true
        cardScroll.hasHorizontalScroller = true
        cardScroll.drawsBackground = false
        cardScroll.translatesAutoresizingMaskIntoConstraints = false

        let lineColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
        lineColumn.title = L("Dòng")
        lineColumn.width = 80
        let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
        detailColumn.title = L("Chi tiết")
        detailColumn.width = 700
        list.addTableColumn(lineColumn)
        list.addTableColumn(detailColumn)
        list.rowHeight = Tokens.Metrics.listRowHeight
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        list.backgroundColor = Tokens.Color.chrome
        list.usesAlternatingRowBackgroundColors = false
        list.target = self
        list.action = #selector(rowClicked)
        listScroll.documentView = list
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false
        listScroll.isHidden = true
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        addSubview(tabs)
        addSubview(summary)
        addSubview(progress)
        addSubview(filterPopup)
        addSubview(cardScroll)
        addSubview(listScroll)

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            tabs.topAnchor.constraint(equalTo: topAnchor, constant: inset),

            filterPopup.leadingAnchor.constraint(equalTo: tabs.trailingAnchor, constant: 10),
            filterPopup.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            filterPopup.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            cancelButton.trailingAnchor.constraint(
                equalTo: closeButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),

            progress.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),
            progress.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: 120),

            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            summary.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 6),

            cardScroll.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),
            cardScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            cardScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            cardScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),

            listScroll.topAnchor.constraint(equalTo: cardScroll.topAnchor),
            listScroll.leadingAnchor.constraint(equalTo: cardScroll.leadingAnchor),
            listScroll.trailingAnchor.constraint(equalTo: cardScroll.trailingAnchor),
            listScroll.bottomAnchor.constraint(equalTo: cardScroll.bottomAnchor),
        ])
    }

    // MARK: - Trạng thái

    var selectedTab: Tab { Tab(rawValue: tabs.selectedSegment) ?? .record }

    /// Thẻ bản ghi tại con nháy — FR-KNW-901.
    func presentRecord(line: Int, pretty: String?, raw: String) {
        guard selectedTab == .record else { return }
        if let pretty {
            card.string = pretty
            card.textColor = Tokens.Color.editorInk
            summary.stringValue = L("Bản ghi ở dòng") + " \(line + 1)"
            summary.textColor = Tokens.Color.editorInk
        } else {
            // Dòng hỏng thì hiện VĂN BẢN THÔ chứ không hiện thẻ trống: người dùng đang đứng ở
            // đây để sửa nó, và thứ họ cần thấy là đúng những ký tự đang có.
            card.string = raw
            card.textColor = Tokens.Color.editorInk
            summary.stringValue = L("Dòng") + " \(line + 1) " + L("không phải JSON hợp lệ")
            summary.textColor = Tokens.Color.error
        }
    }

    func presentScanning(_ fraction: Double) {
        progress.isHidden = false
        cancelButton.isHidden = false
        progress.doubleValue = fraction
    }

    /// Kết quả kiểm — FR-KNW-901.
    func presentScan(_ result: JSONLScan.Result) {
        progress.isHidden = true
        cancelButton.isHidden = true
        problems = result.problems
        var parts = [
            "\(result.recordCount) " + L("bản ghi"),
            "\(result.problemCount) " + L("lỗi"),
        ]
        if result.blankCount > 0 { parts.append("\(result.blankCount) " + L("dòng trắng")) }
        if result.nonObjectCount > 0 {
            parts.append("\(result.nonObjectCount) " + L("không phải đối tượng"))
        }
        if result.problemsTruncated {
            parts.append(L("bảng hiện") + " \(result.problems.count)")
        }
        if result.wasCancelled { parts.append(L("ĐÃ HUỶ giữa chừng")) }
        tabs.setLabel(L("Lỗi") + (result.problemCount > 0 ? " (\(result.problemCount))" : ""),
                      forSegment: 1)
        if selectedTab == .problems {
            summary.stringValue = parts.joined(separator: " · ")
            summary.textColor = result.problemCount > 0
                ? Tokens.Color.error : Tokens.Color.editorInk
            jumpRows = problems.map { (line: $0.line, detail: $0.message) }
            list.reloadData()
        }
    }

    /// Kết quả soi chunk — FR-KNW-902.
    func presentInspection(_ report: ChunkInspector.Report) {
        inspection = report
        filterChoices = []
        filterPopup.removeAllItems()
        filterPopup.addItem(withTitle: L("Không lọc"))
        for field in report.fields where !field.topValues.isEmpty
            && field.name != report.textField {
            for value in field.topValues {
                let display = value.value.count > 40
                    ? String(value.value.prefix(40)) + "…" : value.value
                filterChoices.append((
                    field: field.name, value: value.value,
                    label: "\(field.name) = \(display)  (\(value.count))"))
            }
        }
        for choice in filterChoices { filterPopup.addItem(withTitle: choice.label) }
        if selectedTab == .chunks { showChunks() }
    }

    /// Kết quả lọc theo metadata — FR-KNW-902.
    func presentFilter(field: String, value: String, lines: [Int]) {
        jumpRows = lines.map { (line: $0, detail: "\(field) = \(value)") }
        summary.stringValue = "\(lines.count) " + L("bản ghi khớp bộ lọc")
        summary.textColor = Tokens.Color.editorInk
        listScroll.isHidden = false
        cardScroll.isHidden = true
        list.reloadData()
    }

    // MARK: - Hành động

    @objc private func tabChanged() {
        switch selectedTab {
        case .record:
            cardScroll.isHidden = false
            listScroll.isHidden = true
            filterPopup.isHidden = true
            summary.stringValue = L("Đưa con nháy tới một dòng để xem bản ghi")
            summary.textColor = Tokens.Color.editorInk
        case .problems:
            cardScroll.isHidden = true
            listScroll.isHidden = false
            filterPopup.isHidden = true
            jumpRows = problems.map { (line: $0.line, detail: $0.message) }
            summary.stringValue = problems.isEmpty
                ? L("Không có bản ghi nào hỏng") : "\(problems.count) " + L("lỗi")
            summary.textColor = problems.isEmpty ? Tokens.Color.editorInk : Tokens.Color.error
            list.reloadData()
        case .chunks:
            showChunks()
        }
    }

    private func showChunks() {
        cardScroll.isHidden = false
        listScroll.isHidden = true
        filterPopup.isHidden = false
        guard let report = inspection else {
            card.string = L("Chưa soi. Chạy lại lệnh «JSONL: soi chunk» sau khi kiểm xong.")
            summary.stringValue = ""
            return
        }
        card.string = JSONLPanel.chunkReportText(report)
        card.textColor = Tokens.Color.editorInk
        summary.stringValue = "\(report.recordCount) " + L("chunk")
            + " · " + L("trường văn bản") + " «\(report.textField ?? "—")»"
        summary.textColor = Tokens.Color.editorInk
    }

    /// Báo cáo chunk dạng CHỮ, có cột bằng ký tự.
    ///
    /// Chữ chứ không phải hình vẽ, vì ba lý do: nó **chép được** sang một ghi chú hay một issue;
    /// nó **theo được** cỡ chữ trợ năng mà không cần vẽ lại; và một histogram vẽ bằng ký tự
    /// trong panel cao 260 pixel thì đọc được không kém một histogram vẽ bằng đường.
    static func chunkReportText(_ report: ChunkInspector.Report) -> String {
        var out: [String] = []
        out.append(L("SCHEMA (đoán — sửa được bằng cách chọn trường khác)"))
        for candidate in report.schema.textCandidates.prefix(3) {
            let mark = candidate.field == report.textField ? "→" : " "
            out.append("  \(mark) " + L("văn bản") + ": \(candidate.field)"
                + "   \(String(format: "%.2f", candidate.score))   \(candidate.reason)")
        }
        for candidate in report.schema.idCandidates.prefix(2) {
            let mark = candidate.field == report.schema.id ? "→" : " "
            out.append("  \(mark) " + L("định danh") + ": \(candidate.field)"
                + "   \(String(format: "%.2f", candidate.score))   \(candidate.reason)")
        }
        if !report.schema.metadataFields.isEmpty {
            out.append("    " + L("metadata") + ": "
                + report.schema.metadataFields.joined(separator: ", "))
        }
        if let nested = report.schema.nestedMetadataField {
            out.append("    " + L("metadata lồng") + ": \(nested)")
        }
        out.append("")

        out.append(L("TRƯỜNG"))
        for field in report.fields {
            let kinds = field.kinds.map(\.vietnamese).joined(separator: "/")
            var line = "  \(field.name)   \(kinds)   " + L("phủ") + " \(field.presentCount)"
            if field.kinds.count > 1 { line += "   ⚠ " + L("nhiều kiểu") }
            out.append(line)
        }
        out.append("")

        for (title, histogram) in [
            (L("ĐỘ DÀI — ký tự"), report.characters),
            (L("ĐỘ DÀI — từ"), report.words),
            (L("ĐỘ DÀI — token ước lượng"), report.tokens),
        ] {
            out.append(title + LF("   (%d…%d, trung bình %.0f)",
                                      histogram.minimum, histogram.maximum, histogram.average))
            let peak = histogram.counts.max() ?? 1
            for index in histogram.counts.indices {
                let width = peak > 0 ? Int(Double(histogram.counts[index]) / Double(peak) * 40)
                                     : 0
                out.append("  " + histogram.label(index).padding(
                    toLength: 16, withPad: " ", startingAt: 0)
                    + String(repeating: "█", count: width)
                    + " \(histogram.counts[index])")
            }
            out.append("")
        }

        out.append(L("RỖNG VÀ TRÙNG"))
        out.append("  " + L("chunk rỗng") + ": \(report.emptyCount)"
            + (report.emptyLines.isEmpty ? "" : "   " + L("dòng") + " "
                + report.emptyLines.prefix(10).map { String($0 + 1) }.joined(separator: ", ")
                + (report.emptyLines.count > 10 ? ", …" : "")))
        out.append("  " + L("nhóm trùng chính xác") + ": \(report.duplicateCount)")
        for group in report.duplicateGroups.prefix(10) {
            out.append("    " + L("dòng") + " "
                + group.prefix(8).map { String($0 + 1) }.joined(separator: ", ")
                + (group.count > 8 ? ", …" : ""))
        }
        if report.invalidCount > 0 {
            out.append("")
            out.append("  ⚠ \(report.invalidCount) " + L("dòng không đọc được, không vào thống kê"))
        }
        // Giới hạn phải nói ra, không giấu — cùng luật với khối "Phương pháp" của FR-MIN.
        out.append("")
        out.append(L("PHƯƠNG PHÁP"))
        out.append("  " + L("«ký tự» đếm theo ký tự Unicode (scalar), không theo cụm hiển thị"))
        out.append("  " + L("«từ» tách theo khoảng trắng ASCII"))
        out.append("  " + L("«token» đếm bằng bộ tách âm tiết — KHÔNG phải bộ tách của model"))
        out.append("  " + L("«trùng» là trùng CHÍNH XÁC; trùng GẦN nằm ở khối ```quality"))
        return out.joined(separator: "\n")
    }

    @objc private func filterChanged() {
        let index = filterPopup.indexOfSelectedItem - 1
        guard index >= 0, index < filterChoices.count else {
            jumpRows = []
            listScroll.isHidden = true
            cardScroll.isHidden = false
            list.reloadData()
            showChunks()
            return
        }
        let choice = filterChoices[index]
        onFilter?(choice.field, choice.value)
    }

    @objc private func rowClicked() {
        let row = list.clickedRow
        guard row >= 0, row < jumpRows.count else { return }
        onSelectLine?(jumpRows[row].line)
    }

    // MARK: - Móc cho bài tự kiểm

    var cardTextForSelfTest: String { card.string }
    var listedLinesForSelfTest: [Int] { jumpRows.map(\.line) }
    var summaryForSelfTest: String { summary.stringValue }

    /// Đổi tab qua ĐÚNG đường người dùng bấm, để bài kiểm không đi vòng qua hành vi thật.
    func selectTabForSelfTest(_ tab: Tab) {
        tabs.selectedSegment = tab.rawValue
        tabChanged()
    }

    @objc private func cancelTapped() { onCancelScan?() }
    @objc private func closeTapped() { onClose?() }
}

extension JSONLPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { jumpRows.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < jumpRows.count, let column = tableColumn else { return nil }
        let identifier = column.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
            ?? {
                let field = NSTextField(labelWithString: "")
                field.identifier = identifier
                field.font = Tokens.Font.monoInline()
                field.lineBreakMode = .byTruncatingTail
                return field
            }()
        if identifier.rawValue == "line" {
            cell.stringValue = String(jumpRows[row].line + 1)
            cell.alignment = .trailingEdge
        } else {
            cell.stringValue = jumpRows[row].detail
            cell.alignment = .leadingEdge
        }
        return cell
    }
}
