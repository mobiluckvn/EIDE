import AppKit
import EideLoi

/// **Cột trái — điều hướng 6 nhóm / 25 màn.** `#nav` của bản demo, UXC-31 §2B.
///
/// Nhóm gập được, mục đang mở có vạch đỏ bên trái, huy hiệu số cho việc chờ người. Tác tử tự mở
/// một màn thì nhóm chứa nó tự bung và mục nhấp nháy đúng hai nhịp — đủ để mắt bắt đường đi,
/// không đủ để gây nhiễu.
public final class EideDieuHuong: NSView {

    public var onChon: ((String) -> Void)?

    /// Số việc chờ người theo màn — nguồn DUY NHẤT với khối "Chờ tôi" ở cột phải (B7).
    public var choTheoMan: [String: Int] = [:] { didSet { _ve() } }
    public private(set) var dangMo: String?
    private var nhomGap: Set<String> = []

    private let cuon = NSScrollView()
    private let coc = NSStackView()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 0
        coc.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        coc.translatesAutoresizingMaskIntoConstraints = false
        cuon.contentView = EideKhungLat()
        cuon.documentView = coc
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            coc.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: cuon.contentView.trailingAnchor),
            coc.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
        ])
        _ve()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func chon(_ tien: String, nhapNhay: Bool = false) {
        dangMo = tien
        if let n = EideManHinhDS.nhom.first(where: { $0.man.contains { $0.tien == tien } }) {
            nhomGap.remove(n.ten)
        }
        _ve()
        if nhapNhay { _nhapNhay(tien) }
    }

    private func _ve() {
        for v in coc.arrangedSubviews { coc.removeArrangedSubview(v); v.removeFromSuperview() }
        for n in EideManHinhDS.nhom {
            coc.addArrangedSubview(_tieuDeNhom(n))
            guard !nhomGap.contains(n.ten) else { continue }
            for m in n.man { coc.addArrangedSubview(_muc(m)) }
        }
        for v in coc.arrangedSubviews {
            v.widthAnchor.constraint(equalTo: coc.widthAnchor).isActive = true
        }
    }

    private func _tieuDeNhom(_ n: EideManHinhDS.Nhom) -> NSView {
        let b = NSButton(title: n.ten, target: self, action: #selector(_gapNhom(_:)))
        b.bezelStyle = .inline
        b.alignment = .left
        b.font = NSFont.boldSystemFont(ofSize: 10.5)
        b.contentTintColor = EideToken.Mau.faint
        b.identifier = NSUserInterfaceItemIdentifier(n.ten)
        b.toolTip = n.cauHoi
        let cho = n.man.reduce(0) { $0 + (choTheoMan[$1.tien] ?? 0) }
        return _hang(b, huyHieu: cho, thut: 12, vachDo: false)
    }

    private func _muc(_ m: EideManHinhDS.Man) -> NSView {
        let hoat = m.tien == dangMo
        let b = NSButton(title: m.nhan, target: self, action: #selector(_bamMuc(_:)))
        b.bezelStyle = .inline
        b.alignment = .left
        b.font = hoat ? NSFont.boldSystemFont(ofSize: 13) : EideToken.fontUI
        b.contentTintColor = hoat ? EideToken.Mau.text : EideToken.Mau.muted
        b.identifier = NSUserInterfaceItemIdentifier(m.tien)
        return _hang(b, huyHieu: choTheoMan[m.tien] ?? 0, thut: 20, vachDo: hoat)
    }

    private func _hang(_ nut: NSButton, huyHieu: Int, thut: CGFloat, vachDo: Bool) -> NSView {
        let h = NSView()
        h.translatesAutoresizingMaskIntoConstraints = false
        h.wantsLayer = true
        if vachDo {
            h.layer?.backgroundColor = EideToken.Mau.bg.cgColor
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = EideToken.Mau.primary.cgColor
            v.translatesAutoresizingMaskIntoConstraints = false
            h.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: h.leadingAnchor),
                v.topAnchor.constraint(equalTo: h.topAnchor),
                v.bottomAnchor.constraint(equalTo: h.bottomAnchor),
                v.widthAnchor.constraint(equalToConstant: 3),
            ])
        }
        nut.translatesAutoresizingMaskIntoConstraints = false
        h.addSubview(nut)
        var rb: [NSLayoutConstraint] = [
            nut.leadingAnchor.constraint(equalTo: h.leadingAnchor, constant: thut),
            nut.topAnchor.constraint(equalTo: h.topAnchor, constant: 4),
            nut.bottomAnchor.constraint(equalTo: h.bottomAnchor, constant: -4),
        ]
        if huyHieu > 0 {
            let hh = NSTextField(labelWithString: " \(huyHieu) ")
            hh.font = NSFont.boldSystemFont(ofSize: 11)
            hh.textColor = EideToken.Mau.warn
            hh.wantsLayer = true
            hh.layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
            hh.layer?.cornerRadius = 9
            hh.translatesAutoresizingMaskIntoConstraints = false
            h.addSubview(hh)
            rb += [
                hh.trailingAnchor.constraint(equalTo: h.trailingAnchor, constant: -10),
                hh.centerYAnchor.constraint(equalTo: h.centerYAnchor),
                nut.trailingAnchor.constraint(lessThanOrEqualTo: hh.leadingAnchor, constant: -4),
            ]
        } else {
            rb.append(nut.trailingAnchor.constraint(lessThanOrEqualTo: h.trailingAnchor,
                                                    constant: -10))
        }
        NSLayoutConstraint.activate(rb)
        h.identifier = NSUserInterfaceItemIdentifier(nut.identifier?.rawValue ?? "")
        return h
    }

    /// Nhấp nháy ĐÚNG hai nhịp × 300 ms — §2B.5. Tôn trọng "Giảm chuyển động" của hệ điều hành.
    private func _nhapNhay(_ tien: String) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        guard let h = coc.arrangedSubviews.first(where: { $0.identifier?.rawValue == tien })
        else { return }
        h.wantsLayer = true
        let a = CABasicAnimation(keyPath: "backgroundColor")
        a.fromValue = EideToken.Mau.warnBg.cgColor
        a.toValue = (h.layer?.backgroundColor) ?? NSColor.clear.cgColor
        a.duration = 0.3
        a.repeatCount = 2
        h.layer?.add(a, forKey: "nhapNhay")
    }

    @objc private func _bamMuc(_ n: NSButton) {
        guard let t = n.identifier?.rawValue else { return }
        chon(t)
        onChon?(t)
    }

    @objc private func _gapNhom(_ n: NSButton) {
        guard let t = n.identifier?.rawValue else { return }
        if nhomGap.contains(t) { nhomGap.remove(t) } else { nhomGap.insert(t) }
        _ve()
    }
}
