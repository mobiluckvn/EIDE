import AppKit

/// Ô lệnh với gợi ý "/" — UXD-13 U1 và §4 (CommandBox).
///
/// U1: *"ô lệnh có gợi ý `/` liệt kê năng lực có `ui`"*. §4: *"Nhập nhiều dòng; `/` gợi ý năng
/// lực (tên + một câu); Enter gửi; lịch sử ↑↓"*.
///
/// Trường `ui` mà U1 nói tới KHÔNG có trong `cds.json` (0/238 năng lực khai nó), nên phía Python
/// suy nó từ bảng màn hình UXD-13 §2 và trả về trong `caps.list` — xem DEVIATIONS DEV-046. Ở đây
/// chỉ cần biết: năng lực nào có `ui` rỗng thì không vào menu.
///
/// **Chỉ gợi ý năng lực ĐÃ HIỆN THỰC.** Một mục menu gọi ra lỗi E1001 dạy người dùng rằng menu
/// không đáng tin, và bài học ấy dính lại lâu hơn cái lỗi. Cùng lý do với việc MCP chỉ phơi tool
/// đã hiện thực.
public final class CommandBox: NSView, NSTextViewDelegate {

    public struct NangLuc {
        public let id: String
        public let mota: String
        public let manHinh: String
        public init(id: String, mota: String, manHinh: String) {
            self.id = id; self.mota = mota; self.manHinh = manHinh
        }
    }

    public var onGui: ((String) -> Void)?

    private let van = NSTextView()
    private let cuon = NSScrollView()
    private let bang = NSTableView()
    private let cuonBang = NSScrollView()
    private var goiY: [NangLuc] = []
    private var tatCa: [NangLuc] = []
    private var lichSu: [String] = []
    private var viTriLichSu = -1

    /// Chiều cao ô nhập: một dòng khi trống, giãn tới bốn dòng rồi cuộn.
    private var caoVan: NSLayoutConstraint!
    private let caoDong: CGFloat = 18
    private let toiDaDong = 4

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Ô lệnh" }

    public init() {
        super.init(frame: .zero)

        van.delegate = self
        van.font = EideToken.fontUI
        van.isRichText = false
        van.textContainerInset = NSSize(width: EideToken.space[1], height: EideToken.space[1] / 2)
        van.setAccessibilityLabel("Ô lệnh. Gõ gạch chéo để xem danh sách năng lực.")
        cuon.documentView = van
        cuon.borderType = .lineBorder
        cuon.hasVerticalScroller = true

        bang.headerView = nil
        bang.rowHeight = 34
        bang.dataSource = self
        bang.delegate = self
        bang.target = self
        bang.doubleAction = #selector(chonDong)
        bang.addTableColumn(NSTableColumn(identifier: .init("goiy")))
        cuonBang.documentView = bang
        cuonBang.borderType = .lineBorder
        cuonBang.hasVerticalScroller = true
        cuonBang.isHidden = true
        cuonBang.setAccessibilityLabel("Gợi ý năng lực")

        for v in [cuonBang, cuon] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        caoVan = cuon.heightAnchor.constraint(equalToConstant: caoDong + EideToken.space[1])
        NSLayoutConstraint.activate([
            cuonBang.topAnchor.constraint(equalTo: topAnchor),
            cuonBang.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuonBang.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuonBang.heightAnchor.constraint(lessThanOrEqualToConstant: 34 * 6),
            cuon.topAnchor.constraint(equalTo: cuonBang.bottomAnchor, constant: EideToken.space[0]),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            caoVan,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Nạp danh sách từ `caps.list`. Lọc ở đây chứ không ở nơi gọi: quy tắc "có `ui` và đã hiện
    /// thực" là quy tắc của MENU, và để nó ở một chỗ thì không có bản sao nào trôi đi.
    public func napNangLuc(_ ds: [NangLuc]) {
        tatCa = ds.filter { !$0.manHinh.isEmpty }.sorted { $0.id < $1.id }
    }

    public var soNangLuc: Int { tatCa.count }

    // MARK: - gợi ý

    /// Tiền tố sau dấu "/" ở ĐẦU dòng hiện tại, hoặc nil nếu không đang gõ lệnh.
    ///
    /// Chỉ đầu dòng: một đường dẫn `src/main.c` giữa câu không được mở menu, và người ta gõ dấu
    /// gạch chéo giữa câu thường xuyên hơn là gõ nó để tìm năng lực.
    func tienTo(_ s: String) -> String? {
        guard let dong = s.split(separator: "\n", omittingEmptySubsequences: false).last else { return nil }
        guard dong.hasPrefix("/") else { return nil }
        return String(dong.dropFirst())
    }

    func loc(_ tienTo: String) -> [NangLuc] {
        let t = tienTo.lowercased()
        guard !t.isEmpty else { return tatCa }
        // Khớp id trước, rồi mô tả — người gõ "/kg" muốn thấy nhóm kg trước một năng lực khác
        // tình cờ có chữ "kg" trong mô tả.
        let theoId = tatCa.filter { $0.id.lowercased().contains(t) }
        let theoMoTa = tatCa.filter { !$0.id.lowercased().contains(t) && $0.mota.lowercased().contains(t) }
        return theoId + theoMoTa
    }

    public func textDidChange(_ notification: Notification) {
        capNhatCao()
        guard let t = tienTo(van.string) else { return an() }
        goiY = loc(t)
        cuonBang.isHidden = goiY.isEmpty
        bang.reloadData()
        if !goiY.isEmpty { bang.selectRowIndexes([0], byExtendingSelection: false) }
    }

    private func an() {
        cuonBang.isHidden = true
        goiY = []
    }

    private func capNhatCao() {
        let dong = max(1, min(toiDaDong, van.string.split(separator: "\n", omittingEmptySubsequences: false).count))
        caoVan.constant = CGFloat(dong) * caoDong + EideToken.space[1]
    }

    @objc private func chonDong() { ápDungGoiY() }

    private func ápDungGoiY() {
        guard bang.selectedRow >= 0, bang.selectedRow < goiY.count else { return }
        let nl = goiY[bang.selectedRow]
        var dong = van.string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        dong[dong.count - 1] = "/" + nl.id + " "
        van.string = dong.joined(separator: "\n")
        van.setSelectedRange(NSRange(location: van.string.count, length: 0))
        an()
    }

    // MARK: - phím

    public func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
        // Menu đang mở: ↑↓ đi trong menu, Enter/Tab chọn, Esc đóng. Chỉ khi menu đóng thì ↑↓
        // mới là lịch sử — nếu không, hai chức năng tranh nhau cùng một phím.
        if !cuonBang.isHidden {
            switch sel {
            case #selector(NSResponder.moveDown(_:)): return diChuyen(1)
            case #selector(NSResponder.moveUp(_:)): return diChuyen(-1)
            case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                ápDungGoiY(); return true
            case #selector(NSResponder.cancelOperation(_:)): an(); return true
            default: return false
            }
        }
        switch sel {
        case #selector(NSResponder.insertNewline(_:)):
            gui(); return true
        case #selector(NSResponder.moveUp(_:)): return duyetLichSu(1)
        case #selector(NSResponder.moveDown(_:)): return duyetLichSu(-1)
        default: return false
        }
    }

    private func diChuyen(_ b: Int) -> Bool {
        guard !goiY.isEmpty else { return false }
        let moi = max(0, min(goiY.count - 1, bang.selectedRow + b))
        bang.selectRowIndexes([moi], byExtendingSelection: false)
        bang.scrollRowToVisible(moi)
        return true
    }

    private func duyetLichSu(_ b: Int) -> Bool {
        guard !lichSu.isEmpty else { return false }
        // Chỉ cướp phím ↑ khi con trỏ ở dòng ĐẦU: ô nhập nhiều dòng, và ↑ giữa một câu ba dòng
        // phải là di chuyển con trỏ như mọi ô văn bản khác.
        let truoc = (van.string as NSString).substring(to: van.selectedRange().location)
        if b > 0 && truoc.contains("\n") { return false }
        if b < 0 && viTriLichSu < 0 { return false }
        viTriLichSu = max(-1, min(lichSu.count - 1, viTriLichSu + b))
        van.string = viTriLichSu < 0 ? "" : lichSu[lichSu.count - 1 - viTriLichSu]
        van.setSelectedRange(NSRange(location: van.string.count, length: 0))
        capNhatCao()
        return true
    }

    private func gui() {
        let t = van.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lichSu.append(t)
        viTriLichSu = -1
        van.string = ""
        capNhatCao()
        onGui?(t)
    }
}

extension CommandBox: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { goiY.count }

    public func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let nl = goiY[row]
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        v.edgeInsets = NSEdgeInsets(top: 2, left: EideToken.space[1], bottom: 2, right: EideToken.space[1])

        let ten = NSTextField(labelWithString: "/" + nl.id)
        ten.font = EideToken.fontMono
        ten.textColor = EideToken.Mau.text
        // §4: "tên + MỘT CÂU". Cắt ở đây chứ không để mô tả dài đẩy menu rộng ra — một menu
        // rộng bằng cả cửa sổ che mất chính câu người đang gõ.
        let mota = NSTextField(labelWithString: nl.mota.count > 74
                               ? String(nl.mota.prefix(73)) + "…" : nl.mota)
        mota.font = EideToken.fontUI
        mota.textColor = EideToken.Mau.muted
        v.addArrangedSubview(ten)
        v.addArrangedSubview(mota)
        v.setAccessibilityLabel("\(nl.id). \(nl.mota). Màn hình \(nl.manHinh).")
        return v
    }
}
