import AppKit
import EideLoi

/// **Vùng trao đổi người ↔ tác tử** — `#dock` của bản demo, UXC-31 §2D.
///
/// Ba hàng, và chỉ ba: thanh tiêu đề, dòng bong bóng, hàng nhập. Đây là chỗ chủ sản phẩm nói
/// *"rất đơn giản"* — mọi thứ khác đã có chỗ của nó ở bốn vùng kia.
///
/// Bất biến B3: không trạng thái nào bằng 0. Thu gọn 48 pt vẫn để lại ô gõ, vì "giao diện để
/// người và máy cùng trao đổi là phải có và BẤT BIẾN".
public final class EideDock: NSView {

    /// Ba trạng thái chiều cao — §2D.1, lấy đúng số của bản demo.
    public enum Cao: CGFloat, CaseIterable {
        case thuGon = 48, chuan = 220, moRong = 320
    }

    /// Người gõ xong và gửi.
    public var onGui: ((String) -> Void)?

    public private(set) var cao: Cao = .chuan
    /// Số lượt đang hiện — cho bài kiểm đọc.
    public var soLuot: Int { cocLuot.arrangedSubviews.count }

    private let nhan = NSTextField(labelWithString: "VÙNG TRAO ĐỔI")
    private let cuon = NSScrollView()
    private let cocLuot = NSStackView()
    private let oGo = NSTextField()
    private let nutGui = NSButton()
    private lazy var rangCao = heightAnchor.constraint(equalToConstant: Cao.chuan.rawValue)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor

        nhan.font = NSFont.boldSystemFont(ofSize: 10)
        nhan.textColor = EideToken.Mau.faint

        let dem = NSView()
        dem.setContentHuggingPriority(.init(1), for: .horizontal)
        var nut: [NSView] = [nhan, dem]
        for (chu, c) in [("▁", Cao.thuGon), ("▂", .chuan), ("▃", .moRong)] {
            let b = NSButton(title: chu, target: self, action: #selector(_bamCao(_:)))
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.toolTip = "Vùng trao đổi cao \(Int(c.rawValue)) pt"
            b.identifier = NSUserInterfaceItemIdentifier("\(Int(c.rawValue))")
            nut.append(b)
        }
        let hangDau = NSStackView(views: nut)
        hangDau.orientation = .horizontal
        hangDau.alignment = .centerY
        hangDau.spacing = 2

        cocLuot.orientation = .vertical
        cocLuot.alignment = .leading
        cocLuot.spacing = 5
        // `contentView` LẬT và đặt TRƯỚC `documentView`: gốc toạ độ AppKit ở góc DƯỚI-trái, nên
        // một cột dài hơn khung sẽ neo từ dưới lên và mở ra là thấy phần cuối.
        cuon.contentView = EideKhungLat()
        cuon.documentView = cocLuot
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false

        oGo.placeholderString = "Ra lệnh cho tác tử bằng một câu tiếng Việt…"
        oGo.font = EideToken.fontUI
        oGo.target = self
        oGo.action = #selector(_gui)
        nutGui.title = "Gửi"
        nutGui.bezelStyle = .rounded
        nutGui.keyEquivalent = "\r"
        nutGui.target = self
        nutGui.action = #selector(_gui)
        let hangNhap = NSStackView(views: [oGo, nutGui])
        hangNhap.orientation = .horizontal
        hangNhap.spacing = 8

        for v in [hangDau, cuon, hangNhap] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        cocLuot.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rangCao,
            hangDau.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            hangDau.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hangDau.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            cuon.topAnchor.constraint(equalTo: hangDau.bottomAnchor, constant: 2),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cuon.bottomAnchor.constraint(equalTo: hangNhap.topAnchor, constant: -7),

            hangNhap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hangNhap.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            hangNhap.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),

            cocLuot.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            cocLuot.trailingAnchor.constraint(equalTo: cuon.contentView.trailingAnchor),
            cocLuot.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
        ])

        themLuot(.heThong, "Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.")
    }

    /// Đổi chiều cao. `buoc` = người BẤM (bỏ qua phép hoãn "đang gõ").
    public func datCao(_ c: Cao, buoc: Bool = false) {
        if !buoc, window?.firstResponder === oGo.currentEditor() { return }
        cao = c
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.15
            $0.allowsImplicitAnimation = true
            rangCao.animator().constant = c.rawValue
            superview?.layoutSubtreeIfNeeded()
        }
    }

    /// Thêm một lượt. Bong bóng neo trái hay phải tuỳ người nói — §2D.5.
    public func themLuot(_ ai: EideBongBong.Ai, _ van: String) {
        let b = EideBongBong(ai: ai, van: van)
        let hang = NSStackView(views: ai == .nguoi ? [NSView(), b] : [b, NSView()])
        hang.orientation = .horizontal
        hang.spacing = 0
        hang.translatesAutoresizingMaskIntoConstraints = false
        cocLuot.addArrangedSubview(hang)
        NSLayoutConstraint.activate([
            hang.widthAnchor.constraint(equalTo: cocLuot.widthAnchor),
            b.widthAnchor.constraint(lessThanOrEqualTo: cocLuot.widthAnchor, multiplier: 0.78),
        ])
        _cuonXuongCuoi()
    }

    /// Thêm một THẺ (thẻ Run, câu hỏi gộp) vào dòng hội thoại, rộng hết chiều.
    public func themThe(_ v: NSView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        cocLuot.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: cocLuot.widthAnchor).isActive = true
        _cuonXuongCuoi()
    }

    public func goThe(_ v: NSView) {
        cocLuot.removeArrangedSubview(v)
        v.removeFromSuperview()
    }

    private func _cuonXuongCuoi() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let y = max(0, self.cocLuot.frame.height - self.cuon.contentSize.height)
            self.cuon.contentView.scroll(to: NSPoint(x: 0, y: y))
            self.cuon.reflectScrolledClipView(self.cuon.contentView)
        }
    }

    @objc private func _bamCao(_ n: NSButton) {
        guard let s = n.identifier?.rawValue, let px = Double(s),
              let c = Cao(rawValue: CGFloat(px)) else { return }
        datCao(c, buoc: true)
    }

    @objc private func _gui() {
        let v = oGo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        oGo.stringValue = ""
        themLuot(.nguoi, v)
        onGui?(v)
    }
}

/// Khung cuộn LẬT — gốc toạ độ ở góc TRÊN-trái, để danh sách đọc từ trên xuống.
public final class EideKhungLat: NSClipView {
    public override var isFlipped: Bool { true }
}
