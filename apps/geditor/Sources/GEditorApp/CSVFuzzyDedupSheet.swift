import AppKit
import GEditorCore

/// Sheet duyệt cụm trùng lặp mờ — FR-CLN-004.
///
/// ## Vì sao là DUYỆT chứ không phải XEM TRƯỚC
///
/// Mọi sheet khác của cụm FR-CLN cho người dùng nhìn kết quả của một phép biến đổi rồi bấm
/// Áp dụng — quyết định là một câu hỏi có/không. Ở đây thì không: mỗi cụm là **một câu hỏi
/// riêng**, và câu trả lời đúng có thể là "gộp" cho cụm này và "để yên" cho cụm ngay dưới.
/// Đặc tả viết thẳng *"không bao giờ tự merge"*, nên bảng này khởi đầu với **mọi cụm đều
/// KHÔNG chọn** — người dùng phải chủ động tick từng cụm.
///
/// Đó không phải sự cẩn thận thừa. Gộp nhầm hai bản ghi là mất dữ liệu IM LẶNG: không ô nào
/// trống đi, không dòng nào đỏ lên, chỉ có hai thực thể hoá thành một. Một hộp thoại mặc định
/// tick sẵn tất cả sẽ biến điều đó thành một cú Enter.
///
/// ## Điểm tương đồng hiện là CẬN DƯỚI
///
/// Cụm gom bắc cầu (A gần B, B gần C ⇒ cùng cụm), nên con số đáng nhìn là cặp **xa nhau nhất**
/// trong cụm — không phải trung bình. Trung bình che đúng cặp có thể sai.
final class CSVFuzzyDedupSheet: NSViewController {

    private let clusters: [CSVFuzzyDedup.Cluster]
    private let columnName: String

    /// Người dùng chốt — chỗ gọi áp `decisions` lên cả file.
    var onApply: (([Int: CSVFuzzyDedup.Decision]) -> Void)?

    /// Quyết định hiện tại. **Rỗng lúc đầu, có chủ ý** — xem ghi chú đầu lớp.
    private var decisions: [Int: CSVFuzzyDedup.Decision] = [:]
    /// Giá trị đích của từng cụm; mặc định là đề nghị, người dùng sửa được.
    private var targets: [Int: String] = [:]

    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let table = NSTableView()
    private let applyButton = NSButton()

    init(clusters: [CSVFuzzyDedup.Cluster], columnName: String) {
        self.clusters = clusters
        self.columnName = columnName
        for (i, c) in clusters.enumerated() { targets[i] = c.suggested }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 460))
        dung()
        capNhatTomTat()
    }

    private func dung() {
        titleLabel.stringValue = String(
            format: L("Trùng lặp mờ — cột «%@»: %d cụm ứng viên"), columnName, clusters.count)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        summaryLabel.font = Tokens.Font.caption
        summaryLabel.textColor = Tokens.Color.secondaryInk
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 2

        for (id, ten, rong) in [
            ("gop", L("Gộp"), 44.0), ("giong", L("Giống"), 60.0),
            ("gia_tri", L("Các giá trị trong cụm"), 330.0), ("dich", L("Gộp về"), 180.0),
        ] {
            let cot = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            cot.title = ten
            cot.width = rong
            table.addTableColumn(cot)
        }
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 34
        table.style = .plain

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        applyButton.title = L("Gộp các cụm đã chọn")
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(apDung)

        let huy = NSButton(title: L("Huỷ"), target: self, action: #selector(huyBo))
        huy.bezelStyle = .rounded
        huy.keyEquivalent = "\u{1b}"

        let nut = NSStackView(views: [huy, applyButton])
        nut.orientation = .horizontal
        nut.spacing = 10

        let cot = NSStackView(views: [titleLabel, summaryLabel, scroll, nut])
        cot.orientation = .vertical
        cot.alignment = .leading
        cot.spacing = 10
        cot.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 14, right: 16)
        cot.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cot)
        NSLayoutConstraint.activate([
            cot.topAnchor.constraint(equalTo: view.topAnchor),
            cot.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cot.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cot.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: cot.widthAnchor, constant: -32),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
            nut.trailingAnchor.constraint(equalTo: cot.trailingAnchor, constant: -16),
        ])
    }

    private func capNhatTomTat() {
        let chon = decisions.values.filter { $0 != .keep }.count
        let hang = decisions.enumerated().reduce(0) { tong, muc in
            muc.element.value == .keep ? tong : tong + (clusters[muc.element.key].count)
        }
        summaryLabel.stringValue = chon == 0
            ? L("Chưa chọn cụm nào — bấm Gộp thì KHÔNG có gì thay đổi. Máy không tự gộp bao giờ.")
            : LF("Đã chọn %d cụm · %d hàng sẽ đổi giá trị · MỘT bước hoàn tác",
                     chon, hang)
        applyButton.isEnabled = chon > 0
    }

    @objc private func tickCum(_ sender: NSButton) {
        let i = sender.tag
        decisions[i] = sender.state == .on
            ? .unify(to: targets[i] ?? clusters[i].suggested) : .keep
        capNhatTomTat()
    }

    @objc private func doiDich(_ sender: NSTextField) {
        let i = sender.tag
        targets[i] = sender.stringValue
        // Sửa ô đích của một cụm ĐANG chọn thì quyết định phải đi theo, nếu không người dùng gõ
        // một giá trị rồi bấm Gộp và nhận về giá trị cũ.
        if decisions[i] != nil, decisions[i] != .keep {
            decisions[i] = .unify(to: sender.stringValue)
        }
        capNhatTomTat()
    }

    @objc private func apDung() {
        let quyet = decisions.filter { $0.value != .keep }
        dong()
        onApply?(quyet)
    }

    @objc private func huyBo() { dong() }

    /// Đóng sheet. `dismiss(nil)` KHÔNG đóng được sheet dựng bằng `beginSheet` — nó chỉ hợp với
    /// `presentAsSheet`, và dùng nhầm thì hộp thoại đứng lì mà không báo gì.
    private func dong() {
        guard let cua = view.window, let cha = cua.sheetParent else { return }
        cha.endSheet(cua)
    }

    // MARK: - Đường vào cho bài tự kiểm

    var summaryForSelfTest: String { summaryLabel.stringValue }
    var canApplyForSelfTest: Bool { applyButton.isEnabled }
    func tickForSelfTest(_ index: Int) {
        decisions[index] = .unify(to: targets[index] ?? clusters[index].suggested)
        capNhatTomTat()
    }
    func applyForSelfTest() { apDung() }
}

extension CSVFuzzyDedupSheet: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { clusters.count }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let cum = clusters[row]
        switch column?.identifier.rawValue {
        case "gop":
            let hop = NSButton(checkboxWithTitle: "", target: self, action: #selector(tickCum(_:)))
            hop.tag = row
            hop.state = (decisions[row] ?? .keep) == .keep ? .off : .on
            return hop

        case "giong":
            let o = NSTextField(labelWithString:
                String(format: "%.0f%%", cum.lowestSimilarity * 100))
            o.font = Tokens.Font.caption
            // Cụm càng LỎNG càng đáng ngờ, nên nó phải nổi lên chứ không chìm đi.
            o.textColor = cum.lowestSimilarity < 0.92
                ? Tokens.Color.ember : Tokens.Color.secondaryInk
            return o

        case "gia_tri":
            let o = NSTextField(labelWithString: cum.values.joined(separator: "  ·  "))
            o.font = Tokens.Font.caption
            o.lineBreakMode = .byTruncatingTail
            o.toolTip = cum.values.joined(separator: "\n")
            return o

        default:
            let o = NSTextField(string: targets[row] ?? cum.suggested)
            o.tag = row
            o.target = self
            o.action = #selector(doiDich(_:))
            o.font = Tokens.Font.caption
            return o
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
}
