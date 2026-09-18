import AppKit
import EideLoi

/// **Cột phải — hàng đợi ba khối cố định.** `#rail`, UXC-31 §2F.
///
/// Đúng ba khối, đúng thứ tự: ĐANG CHẠY / CHỜ TÔI / HOÀN TÁC ĐƯỢC. Khối rỗng VẪN hiện tiêu đề
/// kèm một dòng lý do (§2F.2) — một khối biến mất khiến người dùng tưởng mình nhớ nhầm chỗ.
///
/// Cả ba đều là BẢN CHIẾU (B7): chúng không giữ trạng thái nguồn, không nghe sự kiện. Thứ trả
/// lời "đang làm gì" là thẻ Run trong vùng trao đổi; ở đây chỉ một dòng.
public final class EideCotPhai: NSView {

    public var onChonRun: ((String) -> Void)?
    public var onDuyet: ((String, Bool) -> Void)?
    public var onHoanTac: ((String) -> Void)?

    private let cocDangChay = NSStackView()
    private let cocCho = NSStackView()
    private let cocHoanTac = NSStackView()
    private let nhanCho = NSTextField(labelWithString: "CHỜ TÔI")
    private let nhanHoanTac = NSTextField(labelWithString: "HOÀN TÁC ĐƯỢC")

    /// Số thẻ tối đa mỗi khối. Cột rộng 236 pt: 55 thẻ hoàn tác biến nó thành một cuộn dài vô
    /// nghĩa, và thứ người cần — mục MỚI NHẤT — nằm ngay đầu. Phần bị cắt KHÔNG im lặng: một
    /// dòng cuối khối nói còn bao nhiêu và xem ở đâu.
    public static let TOI_DA = 8

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        let nhanChay = NSTextField(labelWithString: "ĐANG CHẠY")
        for n in [nhanChay, nhanCho, nhanHoanTac] {
            n.font = NSFont.boldSystemFont(ofSize: 10.5)
            n.textColor = EideToken.Mau.faint
        }
        for c in [cocDangChay, cocCho, cocHoanTac] {
            c.orientation = .vertical
            c.alignment = .leading
            c.spacing = 6
        }

        let coc = NSStackView(views: [nhanChay, cocDangChay,
                                      nhanCho, cocCho,
                                      nhanHoanTac, cocHoanTac])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 6
        coc.setCustomSpacing(12, after: cocDangChay)
        coc.setCustomSpacing(12, after: cocCho)
        coc.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        coc.translatesAutoresizingMaskIntoConstraints = false

        let cuon = NSScrollView()
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
            coc.widthAnchor.constraint(equalTo: cuon.contentView.widthAnchor),
        ])
        datDangChay([])
        datCho([])
        datHoanTac([])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func datDangChay(_ ds: [(ma: String, dong: String)]) {
        _do(cocDangChay, rong: "Không có lượt chạy nào.", ds.map { m in
            let b = NSButton(title: m.dong, target: self, action: #selector(_chonRun(_:)))
            b.bezelStyle = .inline
            b.alignment = .left
            b.font = EideToken.fontUI
            b.contentTintColor = EideToken.Mau.info
            b.identifier = NSUserInterfaceItemIdentifier(m.ma)
            return b
        })
    }

    public func datCho(_ ds: [(ma: String, tieuDe: String, ly: String)]) {
        nhanCho.stringValue = ds.isEmpty ? "CHỜ TÔI" : "CHỜ TÔI (\(ds.count))"
        _do(cocCho, rong: "Trống — không việc nào chờ anh.", ds.map { m in
            let t = NSTextField(labelWithString: m.tieuDe)
            t.font = NSFont.boldSystemFont(ofSize: 12)
            _catDuoi(t)
            let l = NSTextField(wrappingLabelWithString: m.ly)
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.muted
            let ok = NSButton(title: "Duyệt", target: self, action: #selector(_duyet(_:)))
            let no = NSButton(title: "Từ chối", target: self, action: #selector(_tuChoi(_:)))
            for b in [ok, no] {
                b.bezelStyle = .inline
                b.font = EideToken.fontUI
                b.identifier = NSUserInterfaceItemIdentifier(m.ma)
            }
            let nut = NSStackView(views: [ok, no])
            nut.orientation = .horizontal
            nut.spacing = 6
            let o = NSStackView(views: [t, l, nut])
            o.orientation = .vertical
            o.alignment = .leading
            o.spacing = 2
            o.edgeInsets = NSEdgeInsets(top: 6, left: 9, bottom: 6, right: 9)
            o.wantsLayer = true
            o.layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
            o.layer?.cornerRadius = 7
            return o
        })
    }

    public func datHoanTac(_ ds: [(ma: String, nhan: String, han: String)]) {
        nhanHoanTac.stringValue = ds.isEmpty ? "HOÀN TÁC ĐƯỢC" : "HOÀN TÁC ĐƯỢC (\(ds.count))"
        _do(cocHoanTac, rong: "Chưa có mục nào trong cửa sổ hoàn tác.", ds.map { m in
            let t = NSTextField(labelWithString: m.nhan)
            t.font = NSFont.boldSystemFont(ofSize: 12)
            _catDuoi(t)
            let h = NSTextField(labelWithString: m.han)
            h.font = EideToken.fontUI
            h.textColor = EideToken.Mau.muted
            _catDuoi(h)
            let b = NSButton(title: "Hoàn tác", target: self, action: #selector(_hoanTac(_:)))
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            // Đỏ như bản demo: hoàn tác là việc ĐẢO một thứ đã xảy ra. Màu xám mặc định của
            // `.inline` trông y hệt nút đang bị vô hiệu hoá — người không bấm thứ trông như chết.
            b.contentTintColor = EideToken.Mau.bad
            b.identifier = NSUserInterfaceItemIdentifier(m.ma)
            let o = NSStackView(views: [t, h, b])
            o.orientation = .vertical
            o.alignment = .leading
            o.spacing = 2
            o.edgeInsets = NSEdgeInsets(top: 6, left: 9, bottom: 6, right: 9)
            o.wantsLayer = true
            o.layer?.backgroundColor = EideToken.Mau.bg.cgColor
            o.layer?.cornerRadius = 7
            return o
        })
    }

    /// Nhãn một dòng trong cột hẹp: cắt đuôi, và KHÔNG được phép đòi thêm bề ngang. `cap` như
    /// `code.merge_conflict_resolve` dài hơn cả cột — mặc định AppKit sẽ giãn thẻ ra cho vừa.
    private func _catDuoi(_ n: NSTextField) {
        n.lineBreakMode = .byTruncatingTail
        n.cell?.truncatesLastVisibleLine = true
        n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        n.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func _do(_ coc: NSStackView, rong: String, _ ds: [NSView]) {
        for v in coc.arrangedSubviews { coc.removeArrangedSubview(v); v.removeFromSuperview() }
        if ds.isEmpty {
            let n = NSTextField(wrappingLabelWithString: rong)
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.faint
            coc.addArrangedSubview(n)
            return
        }
        for v in ds.prefix(Self.TOI_DA) {
            coc.addArrangedSubview(v)
            // Ghim bề rộng thẻ vào cột. Thiếu dòng này, NSStackView để thẻ rộng theo nhãn dài
            // nhất rồi ĐẨY phần thừa ra ngoài vùng cắt — chữ mất mà không có cảnh báo nào.
            v.widthAnchor.constraint(equalTo: coc.widthAnchor).isActive = true
        }
        if ds.count > Self.TOI_DA {
            let n = NSTextField(wrappingLabelWithString:
                "… và \(ds.count - Self.TOI_DA) mục nữa — xem màn Nhật ký.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.faint
            coc.addArrangedSubview(n)
            n.widthAnchor.constraint(equalTo: coc.widthAnchor).isActive = true
        }
    }

    @objc private func _chonRun(_ n: NSButton) { n.identifier.map { onChonRun?($0.rawValue) } }
    @objc private func _duyet(_ n: NSButton) { n.identifier.map { onDuyet?($0.rawValue, true) } }
    @objc private func _tuChoi(_ n: NSButton) { n.identifier.map { onDuyet?($0.rawValue, false) } }
    @objc private func _hoanTac(_ n: NSButton) { n.identifier.map { onHoanTac?($0.rawValue) } }
}
