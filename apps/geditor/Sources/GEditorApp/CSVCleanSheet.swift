import AppKit
import GEditorCore

/// Sheet xem trước một bước làm sạch (FR-CLN-001/002, NFR-CLN-02a).
///
/// Bất biến của cả cụm FR-CLN là không thao tác nào ghi thẳng mà không cho nhìn trước. Sheet
/// này là chỗ nhìn: mười dòng "trước → sau" dựng bằng CHÍNH hàm sẽ chạy trên cả file, chỉ khác
/// `maxRows`. Bản xem trước đi đường riêng là cách chắc chắn để nó nói dối đúng lúc người dùng
/// tin nó — đã bị một lần ở sheet chuyển đổi (FR-CSV-406).
///
/// Bảng dùng `NSTableView` chứ không phải một ô chữ: chữ ở đây phải xếp thành hai cột thẳng
/// hàng để mắt so được trước với sau, và bảng làm việc ấy mà không cần ai chỉnh nấc tab.
final class CSVCleanSheet: NSViewController {

    private let finding: CSVCleanFinding
    private let buffer: TextBuffer
    private let dialect: CSVDialect
    private let spec: CSVNullSpec

    /// Người dùng chốt bước làm sạch — chỗ gọi chạy nó trên cả file.
    var onApply: ((CSVCleanStep) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let optionLabel = NSTextField(labelWithString: "")
    private let optionPopup = NSPopUpButton()
    private let fillValueField = NSTextField()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let warningLabel = NSTextField(labelWithString: "")
    private let applyButton = NSButton()
    private let table = NSTableView()

    private var samples: [CSVClean.Sample] = []
    private var outcome: CSVCleanOutcome?

    /// Các lựa chọn của popup, theo đúng thứ tự hiện ra.
    private var options: [(title: String, kind: CSVCleanStep.Kind)] = []

    init(finding: CSVCleanFinding, buffer: TextBuffer, dialect: CSVDialect, spec: CSVNullSpec) {
        self.finding = finding
        self.buffer = buffer
        self.dialect = dialect
        self.spec = spec
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 460))

        titleLabel.stringValue = "\(finding.title) — cột «\(finding.columnName)»"
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        optionLabel.stringValue = optionPrompt
        optionLabel.font = Tokens.Font.caption
        optionLabel.textColor = Tokens.Color.secondaryInk
        optionLabel.translatesAutoresizingMaskIntoConstraints = false

        options = buildOptions()
        optionPopup.addItems(withTitles: options.map(\.title))
        optionPopup.target = self
        optionPopup.action = #selector(optionChanged)
        optionPopup.translatesAutoresizingMaskIntoConstraints = false

        fillValueField.placeholderString = L("Giá trị điền vào ô thiếu")
        fillValueField.target = self
        fillValueField.action = #selector(optionChanged)
        fillValueField.isHidden = true
        fillValueField.translatesAutoresizingMaskIntoConstraints = false

        buildTable()
        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        summaryLabel.font = Tokens.Font.caption
        summaryLabel.textColor = Tokens.Color.secondaryInk
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        warningLabel.font = Tokens.Font.caption
        warningLabel.textColor = Tokens.Color.error
        warningLabel.lineBreakMode = .byWordWrapping
        warningLabel.maximumNumberOfLines = 2
        warningLabel.translatesAutoresizingMaskIntoConstraints = false

        applyButton.title = L("Áp dụng")
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(apply)
        applyButton.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton()
        cancel.title = "Hủy"
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.target = self
        cancel.action = #selector(cancelSheet)
        cancel.translatesAutoresizingMaskIntoConstraints = false

        for view in [titleLabel, optionLabel, optionPopup, fillValueField, scrollView,
                     summaryLabel, warningLabel, applyButton, cancel] {
            root.addSubview(view)
        }

        let inset = Tokens.Metrics.spacing(4)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: inset),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            optionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            optionLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),

            optionPopup.topAnchor.constraint(equalTo: optionLabel.bottomAnchor, constant: 4),
            optionPopup.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            optionPopup.widthAnchor.constraint(equalToConstant: 320),

            fillValueField.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor),
            fillValueField.leadingAnchor.constraint(equalTo: optionPopup.trailingAnchor, constant: 8),
            fillValueField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            scrollView.topAnchor.constraint(equalTo: optionPopup.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            scrollView.heightAnchor.constraint(equalToConstant: 210),

            summaryLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            summaryLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            warningLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 4),
            warningLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            warningLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),

            cancel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            cancel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -inset),
            applyButton.trailingAnchor.constraint(equalTo: cancel.leadingAnchor, constant: -8),
            applyButton.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
        ])

        view = root
        refresh()
    }

    private func buildTable() {
        let before = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("before"))
        before.title = "Trước"
        before.width = 280
        let after = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("after"))
        after.title = "Sau"
        after.width = 280
        table.addTableColumn(before)
        table.addTableColumn(after)
        table.rowHeight = Tokens.Metrics.listRowHeight
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.style = .plain
    }

    // MARK: - Lựa chọn theo loại phát hiện

    private var optionPrompt: String {
        switch finding.kind {
        case .mixedDates: return L("Đưa cột về ISO 8601 (YYYY-MM-DD)")
        case .mixedNumbers: return L("Quy ước số cho cả cột")
        case .nulls: return L("Làm gì với ô thiếu")
        case .untrimmed: return "Cắt khoảng trắng"
        }
    }

    /// Danh sách lựa chọn — mỗi mục là một bước đã đủ tham số để chạy.
    ///
    /// Câu hỏi về quy ước CHỈ hiện khi dữ liệu không tự trả lời được. Cột mà mọi ô ngày đều có
    /// ngày > 12 thì hỏi là hỏi thừa, và mỗi câu hỏi thừa làm người dùng bấm nhanh hơn cho xong
    /// ở câu hỏi thật.
    private func buildOptions() -> [(title: String, kind: CSVCleanStep.Kind)] {
        switch finding.kind {
        case .mixedDates:
            let scan = try? CSVClean.scanDates(
                column: finding.column, in: buffer, dialect: dialect, maxRows: 5_000
            )
            guard let scan, scan.needsQuestion else {
                let known: CSVDayMonthOrder?
                if case let .certain(order) = scan?.evidence { known = order } else { known = nil }
                return [(L("Chuẩn hóa về ISO 8601"), .normalizeDates(order: known))]
            }
            return [
                (L("Ô mơ hồ đọc là NGÀY trước (31/12)"), .normalizeDates(order: .dayFirst)),
                (L("Ô mơ hồ đọc là THÁNG trước (12/31)"), .normalizeDates(order: .monthFirst)),
                (L("Bỏ qua ô mơ hồ, chỉ sửa ô chắc chắn"), .normalizeDates(order: nil)),
            ]

        case .mixedNumbers:
            return [
                (L("Về Việt/Âu (1.234,56)"),
                 .normalizeNumbers(to: .vietnamese, source: nil, grouped: true)),
                (L("Về Anh-Mỹ (1,234.56)"),
                 .normalizeNumbers(to: .anglo, source: nil, grouped: true)),
                (L("Về Anh-Mỹ, bỏ dấu nhóm (1234.56)"),
                 .normalizeNumbers(to: .anglo, source: nil, grouped: false)),
            ]

        case .nulls:
            return [
                (L("Điền một giá trị mặc định…"), .fillWithValue("")),
                (L("Điền xuôi — lấy giá trị phía trên"), .fill(.forward)),
                (L("Điền ngược — lấy giá trị phía dưới"), .fill(.backward)),
                (L("Xóa hàng có ô thiếu ở cột này"), .deleteRowsWithNull),
            ]

        case .untrimmed:
            return [
                (L("Cắt khoảng trắng hai đầu"), .trim(collapseInner: false)),
                (L("Cắt hai đầu và nén khoảng trắng bên trong"), .trim(collapseInner: true)),
            ]
        }
    }

    private var selectedStep: CSVCleanStep {
        let index = min(max(0, optionPopup.indexOfSelectedItem), options.count - 1)
        var kind = options[index].kind
        if case .fillWithValue = kind { kind = .fillWithValue(fillValueField.stringValue) }
        return CSVCleanStep(column: finding.column, kind: kind)
    }

    @objc private func optionChanged() { refresh() }

    private func refresh() {
        if case .fillWithValue = selectedStep.kind {
            fillValueField.isHidden = false
        } else {
            fillValueField.isHidden = true
        }

        // Xem trước MƯỜI hàng đầu: tức thời kể cả trên file một gigabyte. Con số trong tóm tắt
        // vì thế là con số của MẪU, và dòng dưới nói rõ điều đó ra.
        let result = try? selectedStep.run(
            in: buffer, dialect: dialect, spec: spec, maxRows: CSVClean.sampleLimit
        )
        outcome = result
        samples = result?.samples ?? []
        table.reloadData()

        summaryLabel.stringValue = result.map { previewSummary($0) } ?? L("Không dựng được bản xem trước")

        let stranded = result?.unparsable.count ?? 0
        warningLabel.stringValue = stranded > 0
            ? "\(stranded) ô trong mẫu không đọc chắc chắn được — chúng được GIỮ NGUYÊN và đánh dấu, không bị đoán."
            : ""

        // Không có gì để đổi thì không cho bấm: một nút L("Áp dụng") chạy xong mà chẳng đổi gì
        // trông y hệt như một nút hỏng.
        applyButton.isEnabled = !(result?.isEmpty ?? true)
    }

    private func previewSummary(_ outcome: CSVCleanOutcome) -> String {
        // Báo cáo đã tự nói phạm vi ("… trong 10 hàng đầu"), nên đừng nói lại lần nữa ở đầu câu.
        switch outcome {
        case let .cells(plan):
            return plan.report.summary + "   ·   cả cột: \(finding.cells) ô phát hiện"
        case let .rows(plan):
            return plan.summary + "   ·   cả file: \(finding.cells) ô thiếu ở cột này"
        }
    }

    @objc private func apply() {
        let step = selectedStep
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .OK) }
        onApply?(step)
    }

    @objc private func cancelSheet() {
        view.window.map { $0.sheetParent?.endSheet($0, returnCode: .cancel) }
    }

    // MARK: - Móc tự kiểm

    var optionTitlesForSelfTest: [String] { options.map(\.title) }
    var summaryForSelfTest: String { summaryLabel.stringValue }
    var warningForSelfTest: String { warningLabel.stringValue }
    var applyEnabledForSelfTest: Bool { applyButton.isEnabled }
    var samplesForSelfTest: [CSVClean.Sample] { samples }
    var selectedStepForSelfTest: CSVCleanStep { selectedStep }

    func selectOptionForSelfTest(_ index: Int) {
        optionPopup.selectItem(at: index)
        optionChanged()
    }

    func setFillValueForSelfTest(_ value: String) {
        fillValueField.stringValue = value
        optionChanged()
    }

    private var selfTestWindow: NSWindow?

    /// Cửa sổ giữ sheet trong lúc tự kiểm — cùng lý do với `CSVConvertSheet`.
    func loadViewForSelfTest() {
        guard selfTestWindow == nil else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentViewController = self
        window.layoutIfNeeded()
        selfTestWindow = window
    }
}

extension CSVCleanSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { samples.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < samples.count, let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("cleanCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.monoInline()
            field.lineBreakMode = .byTruncatingTail
        }

        let sample = samples[row]
        if tableColumn.identifier.rawValue == "before" {
            field.stringValue = sample.before
            field.textColor = Tokens.Color.secondaryInk
        } else if let after = sample.after {
            field.stringValue = after
            field.textColor = Tokens.Color.editorInk
        } else {
            // Ô không đọc được: nói thẳng là GIỮ NGUYÊN. Để trống ở đây sẽ đọc thành "ô này sẽ
            // bị xóa" — đúng nỗi sợ mà bản xem trước sinh ra để dập tắt.
            field.stringValue = L("· giữ nguyên, không đọc được ·")
            field.textColor = Tokens.Color.error
        }
        return field
    }
}
