import AppKit
import EideLoi

/// **Thanh trên** — `#topbar`, UXC-31 §2A. Đúng thứ tự trái → phải, không thêm bớt.
public final class EideThanhTren: NSView {

    public var onDuAn: (() -> Void)?
    public var onBangLenh: (() -> Void)?
    public var onDungKhan: (() -> Void)?
    /// Bấm một bộ đếm → cuộn tới khối tương ứng ở cột phải (§2A.4/2A.5), không mở màn mới.
    public var onDemCho: (() -> Void)?
    public var onDemHoanTac: (() -> Void)?

    private let ten = NSButton()
    private let muc = NSTextField(labelWithString: "Tự chủ A2")
    private let demCho = NSButton()
    private let demHoanTac = NSButton()
    private let nutDung = NSButton()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        let logo = NSTextField(labelWithString: "EIDE")
        logo.font = NSFont.boldSystemFont(ofSize: 15)
        logo.textColor = EideToken.Mau.primary

        ten.title = "— chưa mở dự án — ▾"
        ten.bezelStyle = .rounded
        ten.font = NSFont.boldSystemFont(ofSize: 13)
        ten.target = self
        ten.action = #selector(_duAn)

        muc.font = NSFont.boldSystemFont(ofSize: 11)
        muc.textColor = EideToken.Mau.info
        muc.wantsLayer = true
        muc.layer?.backgroundColor = EideToken.Mau.infoBg.cgColor
        muc.layer?.cornerRadius = 10

        for (b, s) in [(demCho, #selector(_cho)), (demHoanTac, #selector(_hoanTac))] {
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.contentTintColor = EideToken.Mau.muted
            b.target = self
            b.action = s
        }
        datDem(cho: 0, hoanTac: 0)

        let kbtn = NSButton(title: "⌘K · bảng lệnh", target: self, action: #selector(_bangLenh))
        kbtn.bezelStyle = .inline
        kbtn.font = EideToken.fontUI
        kbtn.contentTintColor = EideToken.Mau.faint

        nutDung.title = "■ Dừng khẩn"
        nutDung.bezelStyle = .rounded
        nutDung.font = NSFont.boldSystemFont(ofSize: 12)
        nutDung.contentTintColor = EideToken.Mau.primary
        nutDung.target = self
        nutDung.action = #selector(_dung)

        let dem = NSView()
        dem.setContentHuggingPriority(.init(1), for: .horizontal)
        let h = NSStackView(views: [logo, ten, muc, demCho, demHoanTac, dem, kbtn, nutDung])
        h.orientation = .horizontal
        h.alignment = .centerY
        h.spacing = 12
        h.translatesAutoresizingMaskIntoConstraints = false
        addSubview(h)
        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            h.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            h.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func datDuAn(_ s: String?) {
        ten.title = (s.map { ($0 as NSString).lastPathComponent } ?? "— chưa mở dự án —") + " ▾"
    }

    public func datMuc(_ m: String) {
        muc.stringValue = " Tự chủ \(m) "
        // A0 = nền ĐỎ. Mức "tác tử không tự làm gì" phải khác hẳn mọi mức khác về màu, vì nó là
        // trạng thái người vừa bấm Dừng khẩn hoặc vừa siết quyền — và cả hai đều cần thấy ngay.
        let a0 = m == "A0"
        muc.textColor = a0 ? EideToken.Mau.primary : EideToken.Mau.info
        muc.layer?.backgroundColor = (a0 ? EideToken.Mau.badBg : EideToken.Mau.infoBg).cgColor
    }

    public func datDem(cho: Int, hoanTac: Int) {
        demCho.title = "Chờ tôi \(cho)"
        demHoanTac.title = "Hoàn tác \(hoanTac)"
    }

    @objc private func _duAn() { onDuAn?() }
    @objc private func _bangLenh() { onBangLenh?() }
    @objc private func _dung() { onDungKhan?() }
    @objc private func _cho() { onDemCho?() }
    @objc private func _hoanTac() { onDemHoanTac?() }
}
