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
    private let nhanChay = NSTextField(labelWithString: "ĐANG CHẠY")
    private let nhanCho = NSTextField(labelWithString: "CHỜ TÔI")
    private let nhanHoanTac = NSTextField(labelWithString: "HOÀN TÁC ĐƯỢC")
    private let cuon = NSScrollView()

    /// Ba khối của cột — §2F.1. Dùng làm ĐÍCH cho hai bộ đếm ở thanh trên (§2A.4/2A.5).
    public enum Khoi { case dangChay, cho, hoanTac }

    /// Người bấm nút gấp/mở cột — §2.2. `true` = xin dải hẹp.
    public var onDoiHep: ((Bool) -> Void)?

    /// Đang ở dải hẹp hay cột đầy đủ.
    public private(set) var hep = false

    private let nutGap = NSButton()
    private let daiIcon = NSStackView()
    private var dem: (chay: Int, cho: Int, hoanTac: Int) = (0, 0, 0)

    /// Số thẻ tối đa mỗi khối. Cột rộng 236 pt: 55 thẻ hoàn tác biến nó thành một cuộn dài vô
    /// nghĩa, và thứ người cần — mục MỚI NHẤT — nằm ngay đầu. Phần bị cắt KHÔNG im lặng: một
    /// dòng cuối khối nói còn bao nhiêu và xem ở đâu.
    public static let TOI_DA = 8

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

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

        cuon.contentView = EideKhungLat()
        cuon.documentView = coc
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false

        // Dải icon của §2.2. Ba mục, ĐÚNG ba mục và đúng thứ tự của cột đầy đủ — người dùng thu
        // cột lại rồi bung ra phải thấy cùng một danh sách ở cùng một chỗ.
        nutGap.bezelStyle = .inline
        nutGap.font = EideToken.fontUI
        nutGap.contentTintColor = EideToken.Mau.faint
        nutGap.target = self
        nutGap.action = #selector(_gap)
        nutGap.translatesAutoresizingMaskIntoConstraints = false
        daiIcon.orientation = .vertical
        daiIcon.alignment = .centerX
        daiIcon.spacing = 10
        daiIcon.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        daiIcon.isHidden = true
        daiIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        addSubview(daiIcon)
        addSubview(nutGap)
        NSLayoutConstraint.activate([
            nutGap.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            nutGap.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            daiIcon.topAnchor.constraint(equalTo: nutGap.bottomAnchor, constant: 4),
            daiIcon.leadingAnchor.constraint(equalTo: leadingAnchor),
            daiIcon.trailingAnchor.constraint(equalTo: trailingAnchor),
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
        datHep(false)
    }

    /// **Dải hẹp 44 pt — §2.2.** Ba con số vẫn hiện; cột KHÔNG bao giờ biến mất.
    ///
    /// "Không được ẩn hẳn" là điều khoản đáng kể nhất của §2.2: hàng đợi CHỜ TÔI là chỗ duy nhất
    /// người dùng biết tác tử đang đợi mình, và một cột biến mất ở cửa sổ hẹp biến mọi mục chờ
    /// thành im lặng. Dải hẹp giữ đúng ba con số ấy.
    ///
    /// Nút gấp luôn hiện ở cả hai trạng thái: gấp được mà không bung lại được thì người dùng mất
    /// hẳn hàng đợi cho tới lần khởi động sau.
    public func datHep(_ h: Bool) {
        hep = h
        cuon.isHidden = h
        daiIcon.isHidden = !h
        nutGap.title = h ? "⟨" : "⟩"
        nutGap.toolTip = h ? "Mở rộng cột hàng đợi" : "Thu cột hàng đợi thành dải hẹp"
        nutGap.setAccessibilityLabel(nutGap.toolTip)
        _veDai()
    }

    private func _veDai() {
        for v in daiIcon.arrangedSubviews {
            daiIcon.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        guard hep else { return }
        for (bieu, so, ten) in [("▶", dem.chay, "Đang chạy"),
                                ("⏳", dem.cho, "Chờ tôi"),
                                ("↩", dem.hoanTac, "Hoàn tác được")] {
            let b = NSTextField(labelWithString: bieu)
            b.font = EideToken.fontUI
            b.alignment = .center
            let n = NSTextField(labelWithString: "\(so)")
            n.font = NSFont.boldSystemFont(ofSize: 11)
            n.alignment = .center
            // Khác 0 thì NỔI. Một dải hẹp đầy số xám cùng cỡ không nói được cái nào đang đợi.
            n.textColor = so > 0 ? EideToken.Mau.warn : EideToken.Mau.faint
            let o = NSStackView(views: [b, n])
            o.orientation = .vertical
            o.alignment = .centerX
            o.spacing = 0
            o.toolTip = "\(ten): \(so)"
            o.setAccessibilityLabel("\(ten): \(so)")
            daiIcon.addArrangedSubview(o)
        }
    }

    @objc private func _gap() {
        datHep(!hep)
        onDoiHep?(hep)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func datDangChay(_ ds: [(ma: String, dong: String)]) {
        dem.chay = ds.count
        _veDai()
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

    /// Một mục chờ người. `traLoiChu` mặc định `false` — mục bị cổng chặn, gật hoặc lắc.
    public struct MucCho {
        public let ma: String, tieuDe: String, ly: String, traLoiChu: Bool
        public init(ma: String, tieuDe: String, ly: String, traLoiChu: Bool = false) {
            self.ma = ma; self.tieuDe = tieuDe; self.ly = ly; self.traLoiChu = traLoiChu
        }
    }

    /// Người bấm "Trả lời ở tab Làm rõ yêu cầu" — mở màn S9. Đặt từ `EidePhien`.
    public var onMoLamRo: (() -> Void)?

    /// `traLoiChu = true` → mục này cần một CÂU TRẢ LỜI bằng chữ, không phải duyệt/từ chối.
    ///
    /// Hai loại việc chờ người trông giống nhau trong danh sách mà cần hai thao tác khác hẳn:
    /// mục bị cổng chặn thì người gật hoặc lắc; một ĐIỂM CẦN LÀM RÕ thì người phải VIẾT ra câu
    /// trả lời. Đo 22/09/2026 bằng ảnh chụp cửa sổ thật: cột phải hiện "Duyệt / Từ chối" cho
    /// câu hỏi "Xưởng có mạng LAN có dây không?" — bấm Duyệt sẽ gọi `gate.decide` trên một
    /// `run_id` không tồn tại, và dù có tồn tại thì "duyệt" cũng không trả lời được câu hỏi ấy.
    public func datCho(_ ds: [MucCho]) {
        dem.cho = ds.count
        _veDai()
        nhanCho.stringValue = ds.isEmpty ? "CHỜ TÔI" : "CHỜ TÔI (\(ds.count))"
        _do(cocCho, rong: "Trống — không việc nào chờ anh.", ds.map { m in
            let t = NSTextField(labelWithString: m.tieuDe)
            t.font = NSFont.boldSystemFont(ofSize: 12)
            _catDuoi(t)
            let l = NSTextField(wrappingLabelWithString: m.ly)
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.muted
            var nutDs: [NSView] = []
            if m.traLoiChu {
                let b = NSButton(title: "Trả lời ở tab Làm rõ yêu cầu",
                                 target: self, action: #selector(_moLamRo))
                b.bezelStyle = .inline
                b.font = EideToken.fontUI
                nutDs = [b]
            } else {
                let ok = NSButton(title: "Duyệt", target: self, action: #selector(_duyet(_:)))
                let no = NSButton(title: "Từ chối", target: self, action: #selector(_tuChoi(_:)))
                for b in [ok, no] {
                    b.bezelStyle = .inline
                    b.font = EideToken.fontUI
                    b.identifier = NSUserInterfaceItemIdentifier(m.ma)
                }
                nutDs = [ok, no]
            }
            let nut = NSStackView(views: nutDs)
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

    /// Mã của mục hoàn tác TRÊN CÙNG — thứ người gần như luôn muốn gỡ. Cho bài kiểm.
    public private(set) var maHoanTacDau: String?

    public func datHoanTac(_ ds: [(ma: String, nhan: String, han: String)]) {
        maHoanTacDau = ds.first?.ma
        dem.hoanTac = ds.count
        _veDai()
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

    /// Cuộn tới một khối — đích của hai bộ đếm ở thanh trên (§2A.4/2A.5).
    ///
    /// **Luôn nhấp nháy tiêu đề khối, kể cả khi không cuộn được.** Cửa sổ cao thì cả ba khối đã
    /// nằm trong tầm nhìn, nên phép cuộn là một lệnh không-làm-gì; một nút bấm vào không thấy
    /// chuyện gì xảy ra là nút người dùng kết luận đã hỏng. Nháy là câu trả lời "đây, chỗ này".
    public func cuonToi(_ k: Khoi) {
        let n: NSTextField = switch k {
        case .dangChay: nhanChay
        case .cho: nhanCho
        case .hoanTac: nhanHoanTac
        }
        if let doc = cuon.documentView {
            // Khoảng cách từ ĐỈNH tài liệu, tính cho cả hai chiều hệ toạ độ. `NSStackView` không
            // lật, còn `EideKhungLat` thì có: lấy thẳng `minY` của nhãn sẽ cuộn tới khối NGƯỢC
            // lại — đo được vì khối đầu tiên nhảy xuống đáy.
            let o = doc.convert(n.bounds, from: n)
            let y = (doc.isFlipped ? o.minY : doc.frame.height - o.maxY) - 10
            let toiDa = max(0, doc.frame.height - cuon.contentSize.height)
            cuon.contentView.scroll(to: NSPoint(x: 0, y: min(max(0, y), toiDa)))
            cuon.reflectScrolledClipView(cuon.contentView)
        }
        _nhay(n)
    }

    /// Vị trí cuộn hiện tại — cho bài đo đọc.
    public var viTriCuon: CGFloat { cuon.contentView.bounds.origin.y }

    /// Nháy hai nhịp × 250 ms. Tôn trọng "Giảm chuyển động" như §2B.5.
    private func _nhay(_ n: NSTextField) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        n.wantsLayer = true
        let a = CABasicAnimation(keyPath: "backgroundColor")
        a.fromValue = EideToken.Mau.warnBg.cgColor
        a.toValue = n.layer?.backgroundColor ?? NSColor.clear.cgColor
        a.duration = 0.25
        a.repeatCount = 2
        n.layer?.add(a, forKey: "nhay")
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
    /// Bấm nút "Hoàn tác" của một mục — ĐÚNG đường người bấm. Cho bài kiểm.
    ///
    /// Gọi thẳng `undo.apply` trong bài kiểm sẽ xanh kể cả khi nút không nối vào đâu — đúng
    /// loại lỗi mà `_ = try await` ở `EidePhien._hoanTac` từng gây ra (báo "Đã hoàn tác" cho
    /// một lần hoàn tác không xảy ra).
    public func bamHoanTacDeTest(_ ma: String) { onHoanTac?(ma) }

    @objc private func _moLamRo() { onMoLamRo?() }

    @objc private func _duyet(_ n: NSButton) { n.identifier.map { onDuyet?($0.rawValue, true) } }
    @objc private func _tuChoi(_ n: NSButton) { n.identifier.map { onDuyet?($0.rawValue, false) } }
    @objc private func _hoanTac(_ n: NSButton) { n.identifier.map { onHoanTac?($0.rawValue) } }
}
