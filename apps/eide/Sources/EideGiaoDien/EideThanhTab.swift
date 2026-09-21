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

    /// Thêm tab mà **không** chuyển sang nó — §2C.3 "không cướp màn".
    ///
    /// Tách khỏi `mo(_:)` chứ không thêm cờ: hai hàm này khác nhau ở đúng điều người dùng quan
    /// tâm — cái đang nhìn có bị đổi hay không — và một tham số `bool` ở chỗ gọi không nói ra
    /// điều ấy.
    public func moNen(_ tien: String) {
        guard !tab.contains(tien) else { return }
        tab.append(tien)
        _ve()
    }

    /// Chuyển tab ở vị trí `tu` tới vị trí `den`. Ngoài khoảng thì không làm gì.
    @discardableResult
    public func doiCho(_ tu: Int, _ den: Int) -> Bool {
        guard tab.indices.contains(tu), tab.indices.contains(den), tu != den else { return false }
        tab.insert(tab.remove(at: tu), at: den)
        _ve()
        return true
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

            // `EideNutTab()` rồi gán tay: `NSButton(title:target:action:)` là một factory method
            // của Objective-C trả về `NSButton *`, nên lớp con không kế thừa được nó.
            let b = EideNutTab()
            b.title = EideManHinhDS.nhan(t)
            b.target = self
            b.action = #selector(_chon(_:))
            b.onKeo = { [weak self] nut, x in self?._tha(nut, x) }
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

    /// Thả một tab đang kéo xuống hoành độ `x` (toạ độ CỬA SỔ).
    private func _tha(_ nut: NSButton, _ x: CGFloat) {
        guard let t = nut.identifier?.rawValue, let tu = tab.firstIndex(of: t) else { return }
        doiCho(tu, viTriTha(x))
    }

    /// Hoành độ cửa sổ → chỉ số tab sẽ chen vào. Tách ra để đo được mà không cần chuột thật.
    ///
    /// So với MIDX chứ không với mép: thả vào nửa trái của một tab nghĩa là "đứng trước nó",
    /// nửa phải là "đứng sau" — cùng quy ước mọi thanh tab người dùng đã quen.
    public func viTriTha(_ xTrongCuaSo: CGFloat) -> Int {
        let p = hang.convert(NSPoint(x: xTrongCuaSo, y: 0), from: nil)
        for (i, v) in hang.arrangedSubviews.enumerated() where p.x < v.frame.midX { return i }
        return max(0, tab.count - 1)
    }
}

/// **Nút tab kéo được** — §2C.1.
///
/// `NSButton` nuốt chuột trong vòng theo dõi riêng của nó, nên một `mouseDragged` ở khung nhìn
/// cha không bao giờ chạy. Vòng lặp sự kiện ở đây thay cho vòng của AppKit: đi quá `NGUONG` thì
/// là KÉO, còn nhả tay trong ngưỡng thì vẫn là một cú BẤM bình thường.
///
/// Không dùng `NSDraggingSession`: kéo giữa các ứng dụng không phải việc ở đây, mà phiên kéo
/// của AppKit lại đòi một pasteboard type và một hình kéo — hai thứ chỉ có nghĩa khi có nơi
/// khác để thả.
public final class EideNutTab: NSButton {

    /// Quá ngưỡng này (điểm, theo trục ngang) mới tính là kéo.
    public static let NGUONG: CGFloat = 6

    public var onKeo: ((EideNutTab, CGFloat) -> Void)?

    public override func mouseDown(with event: NSEvent) {
        let dau = event.locationInWindow.x
        var keo = false
        while let s = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if abs(s.locationInWindow.x - dau) > Self.NGUONG { keo = true }
            guard s.type == .leftMouseUp else {
                if keo { alphaValue = 0.55 }
                continue
            }
            alphaValue = 1
            if keo {
                onKeo?(self, s.locationInWindow.x)
            } else if let a = action {
                // Nhả tay trong ngưỡng = một cú bấm. Gửi tay chứ không gọi `super.mouseDown`:
                // gọi lại super ở đây là vào đúng vòng theo dõi vừa bị thay thế, và nó chờ một
                // sự kiện chuột-xuống sẽ không bao giờ đến nữa.
                sendAction(a, to: target)
            }
            return
        }
    }
}
