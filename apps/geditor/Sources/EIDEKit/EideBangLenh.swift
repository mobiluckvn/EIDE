import AppKit

/// **Bảng lệnh (command palette)** — ⌘K, UXC-31 §4.
///
/// Một lớp phủ giữa-trên màn: ô tìm, danh sách kết quả, Enter chạy, Esc đóng.
///
/// ## Vì sao không dùng lại menu "/" của ô lệnh
///
/// ⌘K vốn điền sẵn dấu `/` vào ô lệnh rồi để menu gợi ý của ô ấy lo phần còn lại — rẻ, và sai ở
/// ba chỗ. (1) Menu gợi ý lọc theo TÊN; §4.2 đòi tìm cả theo MÔ TẢ, vì người dùng nhớ *"cái tra
/// thanh ghi"* chứ không nhớ `passport.query`. (2) Nó không tìm được MÀN, mà nửa số thứ người ta
/// muốn mở là màn. (3) Ô lệnh nằm trong vùng trao đổi, và ở trạng thái thu gọn 48 pt thì danh
/// sách gợi ý không có chỗ để bung ra.
///
/// ## Tìm KHÔNG DẤU
///
/// Người Việt gõ nhanh thường bỏ dấu. "ho chieu" phải ra "Hộ chiếu chip"; bắt gõ đủ dấu trong
/// một ô tìm-nhanh là biến phím tắt thành một bài kiểm tra chính tả.
public final class EideBangLenh: NSView {

    /// Người chọn một mục: `(id năng lực hoặc tiền tố màn, là màn hay không)`.
    public var onChon: ((String, Bool) -> Void)?
    /// Người đóng bảng.
    public var onDong: (() -> Void)?

    /// Một mục tìm được.
    public struct Muc {
        public let id: String
        public let mota: String
        public let laMan: Bool
        public init(id: String, mota: String, laMan: Bool) {
            self.id = id; self.mota = mota; self.laMan = laMan
        }
    }

    private var tatCa: [Muc] = []
    private var hienThi: [Muc] = []

    private let o = NSTextField()
    private let bang = NSTableView()
    private let cuon = NSScrollView()
    private let dem = NSTextField(labelWithString: "")

    /// Số mục đang hiện — cho bài kiểm đọc.
    public var soHien: Int { hienThi.count }

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border2.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[2]

        o.placeholderString = "Gõ tên năng lực, mô tả, hay tên màn…"
        o.font = EideToken.fontUI
        o.target = self
        o.action = #selector(_chayMucDau)
        o.delegate = self
        dem.font = EideToken.fontUI
        dem.textColor = EideToken.Mau.faint

        bang.headerView = nil
        bang.rowHeight = 22
        bang.addTableColumn(NSTableColumn(identifier: .init("m")))
        bang.dataSource = self
        bang.delegate = self
        bang.target = self
        bang.doubleAction = #selector(_chayDangChon)
        cuon.documentView = bang
        cuon.hasVerticalScroller = true

        for v in [o, dem, cuon] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            o.topAnchor.constraint(equalTo: topAnchor, constant: s),
            o.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            o.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            dem.topAnchor.constraint(equalTo: o.bottomAnchor, constant: 4),
            dem.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            cuon.topAnchor.constraint(equalTo: dem.bottomAnchor, constant: 4),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -s),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Nạp nguồn dữ liệu: mọi năng lực trong registry + mọi màn.
    public func nap(_ ds: [Muc]) {
        tatCa = ds
        _loc("")
    }

    /// Mở bảng và đưa con trỏ vào ô tìm.
    public func moRa() {
        isHidden = false
        o.stringValue = ""
        _loc("")
        window?.makeFirstResponder(o)
    }

    public func dongLai() {
        isHidden = true
        onDong?()
    }

    /// Bỏ dấu tiếng Việt và hạ chữ thường — dùng cho cả truy vấn lẫn dữ liệu.
    public static func khongDau(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
    }

    /// Lọc theo truy vấn — phơi ra cho bài kiểm gọi thẳng, không phải qua bàn phím.
    public func locDeTest(_ q: String) { _loc(q) }

    /// Dòng đếm/lý do rỗng — cho bài kiểm đọc.
    public var demDeTest: String { dem.stringValue }

    private func _loc(_ q: String) {
        let k = Self.khongDau(q).trimmingCharacters(in: .whitespaces)
        hienThi = k.isEmpty ? tatCa : tatCa.filter {
            Self.khongDau($0.id).contains(k) || Self.khongDau($0.mota).contains(k)
        }
        dem.stringValue = hienThi.isEmpty
            ? "Không khớp gì — thử một từ trong mô tả, ví dụ \"thanh ghi\" hay \"mô phỏng\"."
            : "\(hienThi.count) mục"
        bang.reloadData()
        if !hienThi.isEmpty { bang.selectRowIndexes([0], byExtendingSelection: false) }
    }

    @objc private func _chayMucDau() { _chay(0) }
    @objc private func _chayDangChon() { _chay(bang.selectedRow) }

    private func _chay(_ i: Int) {
        guard i >= 0, i < hienThi.count else { return }
        let m = hienThi[i]
        dongLai()
        onChon?(m.id, m.laMan)
    }

    public override func keyDown(with su: NSEvent) {
        if su.keyCode == 53 { return dongLai() }        // Esc
        super.keyDown(with: su)
    }
}

extension EideBangLenh: NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int { hienThi.count }

    public func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row: Int) -> NSView? {
        guard row < hienThi.count else { return nil }
        let m = hienThi[row]
        let ten = NSTextField(labelWithString: m.id)
        ten.font = m.laMan ? EideToken.fontUI : EideToken.fontMono
        ten.textColor = m.laMan ? EideToken.Mau.text : EideToken.Mau.primary
        let mo = NSTextField(labelWithString: m.mota)
        mo.font = EideToken.fontUI
        mo.textColor = EideToken.Mau.muted
        mo.lineBreakMode = .byTruncatingTail
        let h = NSStackView(views: [ten, mo])
        h.orientation = .horizontal
        h.spacing = EideToken.space[1]
        return h
    }

    public func controlTextDidChange(_ n: Notification) { _loc(o.stringValue) }

    public func control(_ c: NSControl, textView: NSTextView,
                        doCommandBy sel: Selector) -> Bool {
        // Mũi tên lên/xuống đi trong DANH SÁCH trong khi con trỏ vẫn ở ô tìm — nếu không thì
        // muốn chọn mục thứ hai phải rời ô tìm, và mọi ký tự gõ tiếp sẽ rơi vào bảng.
        switch sel {
        case #selector(NSResponder.moveDown(_:)):
            _doiChon(+1); return true
        case #selector(NSResponder.moveUp(_:)):
            _doiChon(-1); return true
        case #selector(NSResponder.cancelOperation(_:)):
            dongLai(); return true
        default:
            return false
        }
    }

    private func _doiChon(_ d: Int) {
        guard !hienThi.isEmpty else { return }
        let i = max(0, min(hienThi.count - 1, bang.selectedRow + d))
        bang.selectRowIndexes([i], byExtendingSelection: false)
        bang.scrollRowToVisible(i)
    }
}
