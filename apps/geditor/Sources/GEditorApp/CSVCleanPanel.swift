import AppKit
import GEditorCore

/// Bàn làm sạch dữ liệu (FR-CLN-006).
///
/// Một danh mục phát hiện theo ngữ cảnh file đang mở: mỗi dòng nói ra CỘT nào, chuyện gì, BAO
/// NHIÊU ô, và có sẵn nút sửa. Người dùng văn phòng đi hết một buổi làm sạch mà không phải viết
/// một biểu thức chính quy nào — đó là toàn bộ lý do cụm này tồn tại.
///
/// Panel chứ không phải hộp thoại, cùng lý do với panel kiểm dữ liệu: làm sạch là việc làm dần
/// từng nhóm, và một hộp thoại buộc đóng lại sau mỗi lần bấm sẽ bắt người dùng mở lại từ đầu
/// cho nhóm tiếp theo.
final class CSVCleanPanel: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Bàn làm sạch dữ liệu") }

    static let height: CGFloat = 200

    /// Hai cách nhìn cùng một file: sửa cái gì, và dữ liệu đang trông ra sao.
    ///
    /// Cùng một panel chứ không phải hai cửa sổ, đúng như UI/UX §6.2 vẽ: hồ sơ là thứ người
    /// dùng liếc sang để QUYẾT ĐỊNH có nên chạy một nhóm làm sạch hay không, nên bắt họ đóng
    /// cái này mở cái kia là chen một bức tường vào giữa hai nửa của một việc.
    enum Mode: Int { case findings, profile }

    private let summary = NSTextField(labelWithString: "")
    private let progress = NSTextField(labelWithString: "")
    private let modePicker = NSSegmentedControl()
    private let recipeButton = NSButton()
    private let reportButton = NSButton()
    private let closeButton = NSButton()
    private let scrollView = NSScrollView()
    private let list = NSTableView()

    private var findings: [CSVCleanFinding] = []
    private var profile: CSVProfileReport?
    private(set) var mode: Mode = .findings

    /// Người dùng chuyển sang tab Hồ sơ — chỗ gọi chạy phép quét nếu chưa có.
    var onNeedProfile: (() -> Void)?

    /// Nhật ký những bước ĐÃ ÁP — vế (c) của NFR-CLN-02, và cũng là thứ sẽ thành Recipe.
    private(set) var applied: [(step: CSVCleanStep, columnName: String, summary: String)] = []

    /// Người dùng bấm số lượng: đưa màn hình tới ô đầu tiên của phát hiện ấy.
    var onSelectFinding: ((CSVCleanFinding) -> Void)?
    /// Người dùng bấm nút hành động: mở sheet xem trước.
    var onAct: ((CSVCleanFinding) -> Void)?
    /// Người dùng bấm một dòng hồ sơ có giá trị bất thường.
    var onSelectProfileColumn: ((CSVColumnProfile) -> Void)?
    var onExportReport: (() -> Void)?
    /// Gom các bước đã áp thành công thức đặt tên được (FR-CLN-005).
    var onSaveRecipe: (() -> Void)?
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

        progress.font = Tokens.Font.caption
        progress.textColor = Tokens.Color.secondaryInk
        progress.translatesAutoresizingMaskIntoConstraints = false

        modePicker.segmentCount = 2
        modePicker.setLabel(L("Phát hiện"), forSegment: 0)
        modePicker.setLabel(L("Hồ sơ dữ liệu"), forSegment: 1)
        modePicker.selectedSegment = 0
        modePicker.segmentStyle = .rounded
        modePicker.target = self
        modePicker.action = #selector(modeChanged)
        modePicker.translatesAutoresizingMaskIntoConstraints = false

        recipeButton.title = L("Lưu công thức…")
        recipeButton.bezelStyle = .rounded
        recipeButton.font = Tokens.Font.caption
        recipeButton.target = self
        recipeButton.action = #selector(saveRecipeTapped)
        recipeButton.isEnabled = false
        recipeButton.translatesAutoresizingMaskIntoConstraints = false

        reportButton.title = L("Xuất báo cáo")
        reportButton.bezelStyle = .rounded
        reportButton.font = Tokens.Font.caption
        reportButton.target = self
        reportButton.action = #selector(exportTapped)
        reportButton.isEnabled = false
        reportButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.title = L("Đóng")
        closeButton.bezelStyle = .rounded
        closeButton.font = Tokens.Font.caption
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let what = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("what"))
        what.title = L("Phát hiện")
        what.width = 520
        what.minWidth = 240
        what.resizingMask = .autoresizingMask

        // Cột nút GIỮ NGUYÊN bề rộng khi cửa sổ giãn ra; chỉ cột mô tả nở theo. Để cả hai cùng
        // nở thì nút "Xử lý…" kéo dài gần nửa panel — thấy trên ảnh chụp — và một nút rộng gấp
        // ba lần chữ trong nó trông như một thanh nhấn nhầm chỗ.
        let action = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        action.title = ""
        action.width = 180
        action.minWidth = 180
        action.maxWidth = 180
        action.resizingMask = []

        list.addTableColumn(what)
        list.addTableColumn(action)
        list.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        list.headerView = nil
        list.rowHeight = Tokens.Metrics.listRowHeight + 6
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        list.target = self
        list.action = #selector(rowClicked)

        scrollView.documentView = list
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        for view in [summary, modePicker, progress, recipeButton, reportButton, closeButton, scrollView] {
            addSubview(view)
        }

        let inset = Tokens.Metrics.spacing(2)
        NSLayoutConstraint.activate([
            summary.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            summary.topAnchor.constraint(equalTo: topAnchor, constant: inset),

            modePicker.leadingAnchor.constraint(equalTo: summary.trailingAnchor, constant: 16),
            modePicker.centerYAnchor.constraint(equalTo: summary.centerYAnchor),

            progress.leadingAnchor.constraint(greaterThanOrEqualTo: modePicker.trailingAnchor, constant: 12),
            progress.centerYAnchor.constraint(equalTo: summary.centerYAnchor),
            recipeButton.leadingAnchor.constraint(equalTo: progress.trailingAnchor, constant: 12),
            recipeButton.centerYAnchor.constraint(equalTo: summary.centerYAnchor),
            reportButton.leadingAnchor.constraint(equalTo: recipeButton.trailingAnchor, constant: 8),
            reportButton.centerYAnchor.constraint(equalTo: summary.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: reportButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            closeButton.centerYAnchor.constraint(equalTo: summary.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: inset),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    // MARK: - Nạp danh mục

    /// Số lượt quét đã đổ vào panel. Bài tự kiểm chờ theo con số này thay vì ngủ một khoảng cố
    /// định — ngủ thì bài kiểm vừa chậm vừa thỉnh thoảng đỏ trên máy đang bận.
    private(set) var scanCount = 0

    func present(_ findings: [CSVCleanFinding], rowsScanned: Int, partial: Bool) {
        self.findings = findings
        self.rowsScanned = rowsScanned
        self.partialScan = partial
        scanCount += 1
        summary.textColor = Tokens.Color.editorInk
        refreshHeader()
        updateProgress()
        list.reloadData()
    }

    private var rowsScanned = 0
    private var partialScan = false

    /// Nạp hồ sơ dữ liệu vừa quét xong.
    func present(profile: CSVProfileReport) {
        self.profile = profile
        if mode == .profile { refreshHeader() }
        list.reloadData()
    }

    @objc private func modeChanged() {
        mode = Mode(rawValue: modePicker.selectedSegment) ?? .findings
        // Hồ sơ chỉ chạy khi người dùng thật sự mở sang xem: trên bảng một triệu hàng nó mất
        // vài giây, và tiêu vài giây cho một câu trả lời chưa ai hỏi là cách chắc chắn để
        // Bàn làm sạch mang tiếng chậm.
        if mode == .profile, profile == nil { onNeedProfile?() }
        refreshHeader()
        list.reloadData()
    }

    private func refreshHeader() {
        switch mode {
        case .findings:
            let scope = partialScan ? " (quét \(rowsScanned) hàng đầu)" : ""
            summary.stringValue = findings.isEmpty
                ? "Không phát hiện gì cần làm sạch trong \(rowsScanned) hàng"
                : "Phát hiện — \(findings.count) nhóm\(scope)"
        case .profile:
            if let profile {
                // "0.0 s" trông như phép quét chưa chạy. Dưới một phần mười giây thì nói là
                // dưới, đừng làm tròn xuống số không.
                let elapsed = profile.seconds < 0.1
                    ? "< 0,1 s" : String(format: "%.1f s", profile.seconds)
                summary.stringValue = String(
                    format: "Hồ sơ dữ liệu — %d cột · %d hàng · %@",
                    profile.columns.count, profile.rowsScanned, elapsed
                )
            } else {
                summary.stringValue = L("Hồ sơ dữ liệu — đang quét…")
            }
        }
    }

    /// Xóa nhật ký để bắt đầu một phiên làm sạch mới.
    ///
    /// Phải gọi khi mở Bàn làm sạch, KHÔNG gọi khi quét lại sau mỗi bước. Thiếu nó thì báo cáo
    /// của file này liệt kê cả những bước đã làm trên file trước — với một báo cáo bàn giao dữ
    /// liệu, đó là nói sai về việc đã làm gì với dữ liệu của ai.
    func resetLog() {
        applied.removeAll()
        // Hồ sơ nói về tài liệu CŨ. Giữ lại là hiện số liệu của file khác dưới tên file này.
        profile = nil
        reportButton.isEnabled = false
        recipeButton.isEnabled = false
        updateProgress()
    }

    /// Ghi nhận một bước đã áp: dòng tiến độ và nút báo cáo sống bằng nhật ký này.
    func recordApplied(_ step: CSVCleanStep, columnName: String, summary: String) {
        applied.append((step, columnName, summary))
        reportButton.isEnabled = true
        recipeButton.isEnabled = true
        updateProgress()
    }

    private func updateProgress() {
        guard !findings.isEmpty || !applied.isEmpty else {
            progress.stringValue = ""
            return
        }
        progress.stringValue = applied.isEmpty
            ? L("Chưa áp dụng nhóm nào · mỗi nhóm là một bước undo")
            : "Đã áp dụng \(applied.count) nhóm · mỗi nhóm là một bước undo"
    }

    /// Báo cáo Markdown của cả buổi làm sạch (NFR-CLN-02c).
    ///
    /// Ghi cả những nhóm CÒN LẠI chứ không chỉ những nhóm đã sửa: một báo cáo chỉ kể phần đã
    /// làm sẽ đọc như thể file đã sạch.
    func makeReport(fileName: String) -> String {
        var out = LF("# Báo cáo làm sạch — %@\n\n", fileName)

        out += LF("## Đã áp dụng (%d)\n\n", applied.count)
        if applied.isEmpty {
            out += L("_Chưa áp dụng bước nào._\n")
        } else {
            for (index, entry) in applied.enumerated() {
                out += "\(index + 1). \(entry.step.displayName(columnName: entry.columnName))\n"
                out += "   - \(entry.summary)\n"
            }
        }

        if let profile {
            out += L("\n## Hồ sơ dữ liệu\n\n")
            out += LF("_%d cột · %d hàng · quét %.1f s_\n\n",
                          profile.columns.count, profile.rowsScanned, profile.seconds)
            out += L("| Cột | Kiểu | Null | Distinct | Nhỏ nhất | Lớn nhất | Trung bình |\n")
            out += "|---|---|---|---|---|---|---|\n"
            for entry in profile.columns {
                let distinct = entry.distinctExact ? "\(entry.distinct)" : "> \(entry.distinct)"
                let mean = entry.mean.map { String(format: "%.4g", $0) } ?? ""
                out += "| \(entry.name) | \(entry.type.displayName) | "
                out += String(format: "%.1f%%", entry.nullPercent)
                out += " | \(distinct) | \(entry.minimum ?? "") | \(entry.maximum ?? "") | \(mean) |\n"
            }

            // Phương pháp phải đi kèm con số, đúng nguyên tắc "giải thích được" của Sổ tay
            // thuật toán: người đọc báo cáo phải tự kiểm chứng được, và phải biết chỗ nào là
            // ước lượng.
            //
            // Khối này là MỘT chuỗi chứ không phải sáu mảnh nối lại như bản trước: nối mảnh thì
            // người dịch nhận được sáu câu cụt không đọc được thành đoạn, và bản dịch sẽ vỡ
            // nhịp. Một chuỗi dài khó chịu trong mã, nhưng nó là đơn vị mà người dịch cần.
            out += LF("""
                \n**Phương pháp.** Một lượt quét, chỉ đọc. Trung bình và độ lệch chuẩn tính \
                bằng Welford. Distinct đếm chính xác tới %d giá trị; vượt ngưỡng thì con số là \
                CẬN DƯỚI và bảng «hay gặp» bị bỏ. Giá trị bất thường chấm bằng |z| > 3 — thước \
                này bị chính outlier kéo lệch khi phân bố lệch, nên hãy đọc nó như một gợi ý để \
                nhìn, không phải một phán quyết. Ô thiếu không tính vào distinct. Cột chữ lấy \
                nhỏ nhất/lớn nhất theo thứ tự BYTE, không phải thứ tự chữ cái tiếng Việt.\n
                """, CSVProfiler.distinctLimit)

            let flagged = profile.columns.filter { !$0.outliers.isEmpty }
            if !flagged.isEmpty {
                out += L("\n### Giá trị bất thường\n\n")
                for entry in flagged {
                    let values = entry.outliers.prefix(5)
                        .map { LF("hàng %d: %@", $0.rowIndex + 1, $0.value) }
                        .joined(separator: " · ")
                    out += LF("- cột «%@» — %d ô: %@\n",
                                  entry.name, entry.outliers.count, values)
                }
            }
        }

        out += LF("\n## Còn lại (%d)\n\n", findings.count)
        if findings.isEmpty {
            out += L("_Không còn phát hiện nào._\n")
        } else {
            for finding in findings {
                out += LF("- cột «%@»: %@\n", finding.columnName, finding.title)
            }
        }
        return out
    }

    @objc private func closeTapped() { onClose?() }
    @objc private func exportTapped() { onExportReport?() }
    @objc private func saveRecipeTapped() { onSaveRecipe?() }

    @objc private func rowClicked() {
        let row = list.clickedRow
        guard row >= 0 else { return }

        // Ở chế độ hồ sơ, bấm một dòng là đi tới ô BẤT THƯỜNG đầu tiên của cột ấy — "click số
        // liệu để lọc tới các dòng liên quan" (FR-CLN-003).
        if mode == .profile {
            guard let profile, row < profile.columns.count else { return }
            let entry = profile.columns[row]
            guard !entry.outliers.isEmpty else { return }
            onSelectProfileColumn?(entry)
            return
        }

        guard row < findings.count else { return }
        // Bấm vào cột hành động thì MỞ SHEET; bấm vào phần mô tả thì nhảy tới ô đầu tiên.
        if list.clickedColumn == 1 {
            onAct?(findings[row])
        } else {
            onSelectFinding?(findings[row])
        }
    }

    // MARK: - Móc tự kiểm

    var summaryForSelfTest: String { summary.stringValue }
    var progressForSelfTest: String { progress.stringValue }
    var findingCountForSelfTest: Int { findings.count }
    var findingTitlesForSelfTest: [String] { findings.map(\.title) }
    func findingForSelfTest(_ index: Int) -> CSVCleanFinding? {
        index >= 0 && index < findings.count ? findings[index] : nil
    }
    func actForSelfTest(_ index: Int) {
        guard index >= 0, index < findings.count else { return }
        onAct?(findings[index])
    }
    func selectFindingForSelfTest(_ index: Int) {
        guard index >= 0, index < findings.count else { return }
        onSelectFinding?(findings[index])
    }
    var reportEnabledForSelfTest: Bool { reportButton.isEnabled }
    var recipeEnabledForSelfTest: Bool { recipeButton.isEnabled }
    var profileForSelfTest: CSVProfileReport? { profile }
    func selectModeForSelfTest(_ mode: Mode) {
        modePicker.selectedSegment = mode.rawValue
        modeChanged()
    }
}

extension CSVCleanPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        mode == .findings ? findings.count : (profile?.columns.count ?? 0)
    }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let tableColumn else { return nil }
        if mode == .profile { return profileView(column: tableColumn, row: row) }
        guard row < findings.count else { return nil }
        let finding = findings[row]

        if tableColumn.identifier.rawValue == "action" {
            let button = NSButton()
            button.title = finding.actionTitle
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            button.tag = row
            button.target = self
            button.action = #selector(actionButtonTapped(_:))
            return button
        }

        let identifier = NSUserInterfaceItemIdentifier("findingCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.ui
            field.lineBreakMode = .byTruncatingTail
        }
        // Tên cột đứng trước: người dùng tìm theo cột của mình, không theo loại lỗi.
        field.stringValue = "«\(finding.columnName)» — \(finding.title)"
        field.textColor = Tokens.Color.editorInk
        return field
    }

    /// Một dòng hồ sơ: tên cột và kiểu bên trái, số liệu bên phải.
    ///
    /// Số liệu ở cột phải chứ không nhét hết vào một dòng chữ dài: mắt người đọc bảng hồ sơ là
    /// đang SO các cột với nhau, và so được thì con số phải thẳng hàng.
    private func profileView(column: NSTableColumn, row: Int) -> NSView? {
        guard let profile, row < profile.columns.count else { return nil }
        let entry = profile.columns[row]

        let identifier = NSUserInterfaceItemIdentifier("profileCell")
        let field: NSTextField
        if let reused = list.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingTail
        }

        if column.identifier.rawValue == "what" {
            field.font = Tokens.Font.ui
            field.stringValue = "«\(entry.name)» — \(entry.summary)"
            // Cột có ô bất thường được gọi tên bằng MÀU, vì đó là dòng người dùng cần nhìn tới.
            field.textColor = entry.outliers.isEmpty
                ? Tokens.Color.editorInk : Tokens.Color.error
        } else {
            field.font = Tokens.Font.caption
            field.textColor = Tokens.Color.secondaryInk
            field.stringValue = entry.topValues.isEmpty
                ? (entry.topExact ? "" : L("quá nhiều giá trị"))
                : L("hay gặp: ") + entry.topValues.prefix(2)
                    .map { "\($0.value) (\($0.count))" }.joined(separator: ", ")
        }
        return field
    }

    @objc private func actionButtonTapped(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < findings.count else { return }
        onAct?(findings[sender.tag])
    }
}
