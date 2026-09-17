import AppKit

/// **Thanh tab của vùng làm việc** — UXC-31 §2C.1, theo bản demo UX v2.0.
///
/// ## Vì sao một IDE cần tab mà một bảng điều khiển thì không
///
/// Trước thay đổi này, mở một màn là THAY màn đang xem. Với một bảng điều khiển thì đúng: mỗi
/// lần chỉ nhìn một thứ. Nhưng EIDE có một tác tử tự mở màn theo việc nó đang làm (NT2), nên
/// trong một lượt chạy tám bước người dùng bị kéo qua bốn năm màn — và khi muốn quay lại thứ
/// vừa đọc dở, họ phải nhớ nó tên gì rồi tự tìm trên cột điều hướng.
///
/// Tab biến dãy màn tác tử vừa đi qua thành một dấu vết bấm lại được. Đó cũng là lý do bản demo
/// đặt tab ở đây chứ không phải ở chỗ khác: nó là bộ nhớ ngắn hạn của phiên làm việc.
///
/// ## Không giữ trạng thái của màn
///
/// Thanh này chỉ giữ DANH SÁCH tên; nội dung từng màn vẫn nằm trong khung nhìn của nó, vẫn do
/// sự kiện sổ cái nuôi. Đóng một tab không xoá gì — mở lại là thấy đúng thứ cũ.
public final class EideThanhTab: NSView {

    /// Người chọn một tab.
    public var onChon: ((String) -> Void)?
    /// Người đóng một tab.
    public var onDong: ((String) -> Void)?

    /// Các tab đang mở, theo thứ tự mở. Khoá là TIỀN TỐ màn (`Passport`), không phải nhãn.
    public private(set) var tab: [(tien: String, nhan: String)] = []
    /// Tab đang hoạt động.
    public private(set) var dangMo: String?

    private let hang = NSStackView()
    private let cuon = NSScrollView()

    public override func accessibilityRole() -> NSAccessibility.Role? { .tabGroup }

    public init() {
        super.init(frame: .zero)
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = 2
        cuon.contentView = KhungLat()
        cuon.documentView = hang
        cuon.hasHorizontalScroller = false
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        hang.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            hang.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            hang.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
            hang.bottomAnchor.constraint(equalTo: cuon.contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Mở (hoặc chuyển tới) một tab. Không trùng: mở lại màn đang có tab thì chỉ chuyển tiêu điểm.
    public func mo(tien: String, nhan: String) {
        if !tab.contains(where: { $0.tien == tien }) {
            tab.append((tien, nhan))
        }
        dangMo = tien
        _ve()
    }

    /// Đóng một tab. Trả về tab nên mở tiếp, `nil` nếu không còn tab nào.
    @discardableResult
    public func dong(tien: String) -> String? {
        tab.removeAll { $0.tien == tien }
        if dangMo == tien { dangMo = tab.last?.tien }
        _ve()
        return dangMo
    }

    public func dongHet() {
        tab.removeAll()
        dangMo = nil
        _ve()
    }

    private func _ve() {
        for v in hang.arrangedSubviews { hang.removeArrangedSubview(v); v.removeFromSuperview() }
        isHidden = tab.isEmpty
        for t in tab {
            let o = NSStackView()
            o.orientation = .horizontal
            o.spacing = 2
            o.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 6)
            o.wantsLayer = true
            let hoat = t.tien == dangMo
            o.layer?.backgroundColor = (hoat ? EideToken.Mau.surface : EideToken.Mau.bg).cgColor
            o.layer?.cornerRadius = 6
            o.layer?.borderWidth = 1
            o.layer?.borderColor = EideToken.Mau.border.cgColor

            let b = NSButton(title: t.nhan, target: self, action: #selector(_chon(_:)))
            b.bezelStyle = .inline
            b.font = hoat ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI
            b.contentTintColor = hoat ? EideToken.Mau.text : EideToken.Mau.muted
            b.identifier = NSUserInterfaceItemIdentifier(t.tien)
            o.addArrangedSubview(b)

            let x = NSButton(title: "✕", target: self, action: #selector(_dong(_:)))
            x.bezelStyle = .inline
            x.font = EideToken.fontUI
            x.contentTintColor = EideToken.Mau.faint
            x.identifier = NSUserInterfaceItemIdentifier(t.tien)
            x.setAccessibilityLabel("Đóng \(t.nhan)")
            o.addArrangedSubview(x)

            hang.addArrangedSubview(o)
        }
    }

    @objc private func _chon(_ n: NSButton) {
        if let t = n.identifier?.rawValue { onChon?(t) }
    }

    @objc private func _dong(_ n: NSButton) {
        if let t = n.identifier?.rawValue { onDong?(t) }
    }
}
