import AppKit
import EideLoi

/// **Thanh tab** — `#tabs`, UXC-31 §2C.1. Nền `#faf9f7`, viền dưới.
public final class EideThanhTab: NSView {

    public var onChon: ((String) -> Void)?
    public var onDong: ((String) -> Void)?

    public private(set) var tab: [String] = []
    public private(set) var dangMo: String?

    private let hang = NSStackView()
    private let cuon = NSScrollView()
    private let vach = NSBox()

    public override func accessibilityRole() -> NSAccessibility.Role? { .tabGroup }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor
        vach.boxType = .separator

        hang.orientation = .horizontal
        hang.alignment = .bottom
        hang.spacing = 2
        hang.translatesAutoresizingMaskIntoConstraints = false
        cuon.contentView = EideKhungLat()
        cuon.documentView = hang
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        vach.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        addSubview(vach)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            cuon.bottomAnchor.constraint(equalTo: vach.topAnchor),
            vach.leadingAnchor.constraint(equalTo: leadingAnchor),
            vach.trailingAnchor.constraint(equalTo: trailingAnchor),
            vach.bottomAnchor.constraint(equalTo: bottomAnchor),
            vach.heightAnchor.constraint(equalToConstant: 1),
            hang.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            hang.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
            hang.bottomAnchor.constraint(equalTo: cuon.contentView.bottomAnchor),
            heightAnchor.constraint(equalToConstant: 33),
        ])
        _ve()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func mo(_ tien: String) {
        if !tab.contains(tien) { tab.append(tien) }
        dangMo = tien
        _ve()
    }

    @discardableResult
    public func dong(_ tien: String) -> String? {
        tab.removeAll { $0 == tien }
        if dangMo == tien { dangMo = tab.last }
        _ve()
        return dangMo
    }

    private func _ve() {
        for v in hang.arrangedSubviews { hang.removeArrangedSubview(v); v.removeFromSuperview() }
        for t in tab {
            let hoat = t == dangMo
            let o = NSStackView()
            o.orientation = .horizontal
            o.spacing = 2
            o.edgeInsets = NSEdgeInsets(top: 3, left: 10, bottom: 3, right: 6)
            o.wantsLayer = true
            o.layer?.backgroundColor = (hoat ? EideToken.Mau.surface : EideToken.Mau.bg).cgColor
            o.layer?.cornerRadius = 7
            o.layer?.borderWidth = 1
            o.layer?.borderColor = EideToken.Mau.border.cgColor

            let b = NSButton(title: EideManHinhDS.nhan(t), target: self, action: #selector(_chon(_:)))
            b.bezelStyle = .inline
            b.font = hoat ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI
            b.contentTintColor = hoat ? EideToken.Mau.text : EideToken.Mau.muted
            b.identifier = NSUserInterfaceItemIdentifier(t)
            o.addArrangedSubview(b)

            let x = NSButton(title: "✕", target: self, action: #selector(_dong(_:)))
            x.bezelStyle = .inline
            x.font = EideToken.fontUI
            x.contentTintColor = EideToken.Mau.faint
            x.identifier = NSUserInterfaceItemIdentifier(t)
            x.setAccessibilityLabel("Đóng \(EideManHinhDS.nhan(t))")
            o.addArrangedSubview(x)
            hang.addArrangedSubview(o)
        }
    }

    @objc private func _chon(_ n: NSButton) { n.identifier.map { onChon?($0.rawValue) } }
    @objc private func _dong(_ n: NSButton) { n.identifier.map { onDong?($0.rawValue) } }
}
