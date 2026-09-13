import AppKit

/// Thanh trạng thái tự chủ — UXD-13 U2, U6.
///
/// "Thanh trạng thái tự chủ LUÔN hiện: mức, số việc tự làm, số chờ, hạn hoàn tác" cùng nút
/// "■ Dừng khẩn". Nó luôn hiện vì đó là câu trả lời cho câu hỏi người dùng sẽ hỏi thường
/// xuyên nhất khi giao việc cho một tác tử: *máy đang được phép làm gì mà không hỏi tôi?*
public final class AutonomyBar: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Trạng thái tự chủ" }

    public var onDungKhan: (() -> Void)?

    private let nhan = NSTextField(labelWithString: "…")
    private let nutDung = NSButton()

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.secondary.cgColor

        nhan.font = EideToken.fontUI
        nhan.textColor = .white
        nutDung.title = "■ Dừng khẩn"
        nutDung.font = EideToken.fontUI
        nutDung.bezelStyle = .rounded
        nutDung.contentTintColor = .white
        nutDung.target = self
        nutDung.action = #selector(dung)
        // U6: phím tắt ⌘⇧. — dừng khẩn phải với tới được mà không cần tìm chuột.
        nutDung.keyEquivalent = "."
        nutDung.keyEquivalentModifierMask = [.command, .shift]
        nutDung.setAccessibilityLabel("Dừng khẩn, phím tắt Command Shift chấm")

        for v in [nhan, nutDung] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            nhan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            nhan.centerYAnchor.constraint(equalTo: centerYAnchor),
            nutDung.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            nutDung.centerYAnchor.constraint(equalTo: centerYAnchor),
            nhan.trailingAnchor.constraint(lessThanOrEqualTo: nutDung.leadingAnchor, constant: -s),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func dung() { onDungKhan?() }

    public func capNhat(muc: String?, dungKhan: Bool, soCho: Int, soHoanTac: Int) {
        // U10: "không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)" — trạng thái dừng được nói
        // bằng CHỮ, màu chỉ là lớp thứ hai. Người mù màu vẫn phải đọc được.
        let m = dungKhan ? "■ ĐÃ DỪNG (A0)" : (muc ?? "—")
        nhan.stringValue = "\(m)  ·  \(soCho) chờ anh  ·  \(soHoanTac) hoàn tác được"
        layer?.backgroundColor = (dungKhan ? EideToken.Mau.primary : EideToken.Mau.secondary).cgColor
    }
}

/// Vùng hội thoại — UXD-13 U1 (ChatPanel là màn hình mặc định), U8, U9.
public final class ChatView: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hội thoại với tác tử" }

    public enum Ai { case nguoi, tacTu, cho, loi, heThong }

    public var onGui: ((String) -> Void)?

    private let cuon = NSScrollView()
    private let van = NSTextView()
    /// Ô lệnh có gợi ý "/" (U1). Công khai để panel nạp danh sách năng lực vào.
    public let oLenh = CommandBox()
    /// Chỗ đặt thẻ tương tác (câu hỏi gộp U3, báo cáo, tiến độ). Nằm GIỮA bản ghi hội thoại và
    /// ô lệnh: một thẻ đang đợi trả lời phải ở ngay trên chỗ người đang gõ, không trôi lên trên
    /// theo dòng chảy hội thoại rồi khuất khỏi màn hình đúng lúc đồng hồ đang đếm.
    private let cocThe = NSStackView()

    public init() {
        super.init(frame: .zero)
        van.isEditable = false
        van.drawsBackground = true
        van.backgroundColor = EideToken.Mau.surface
        van.textContainerInset = NSSize(width: EideToken.space[2], height: EideToken.space[1])
        cuon.documentView = van
        cuon.hasVerticalScroller = true
        cuon.borderType = .lineBorder

        oLenh.onGui = { [weak self] t in self?.onGui?(t) }

        cocThe.orientation = .vertical
        cocThe.alignment = .leading
        cocThe.spacing = EideToken.space[1]
        cocThe.setAccessibilityLabel("Thẻ đang chờ")

        for v in [cuon, cocThe, oLenh] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[1]
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cocThe.topAnchor.constraint(equalTo: cuon.bottomAnchor, constant: s),
            cocThe.leadingAnchor.constraint(equalTo: leadingAnchor),
            cocThe.trailingAnchor.constraint(equalTo: trailingAnchor),
            oLenh.topAnchor.constraint(equalTo: cocThe.bottomAnchor, constant: s),
            oLenh.leadingAnchor.constraint(equalTo: leadingAnchor),
            oLenh.trailingAnchor.constraint(equalTo: trailingAnchor),
            oLenh.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        themLuot(by: .heThong, text: "Sẵn sàng. Gõ một câu tiếng Việt; tôi sẽ nói lại ý hiểu trước khi làm.")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Thêm một thẻ tương tác; thẻ tự gỡ mình khi trả lời xong.
    public func themThe(_ the: NSView) {
        cocThe.addArrangedSubview(the)
        the.widthAnchor.constraint(equalTo: cocThe.widthAnchor).isActive = true
        if let q = the as? QuestionCard {
            let truoc = q.onTraLoi
            q.onTraLoi = { [weak self, weak q] v, hetGio in
                truoc?(v, hetGio)
                guard let q else { return }
                self?.themLuot(by: hetGio ? .heThong : .nguoi,
                               text: hetGio ? "hết giờ — chọn mặc định: \(v)" : v)
                // Gỡ sau khi đã ghi vào bản ghi hội thoại: câu trả lời phải còn dấu vết, thẻ
                // thì không — để lại một thẻ đã trả lời chỉ làm người dùng tưởng còn phải bấm.
                self?.cocThe.removeArrangedSubview(q)
                q.removeFromSuperview()
            }
        }
    }

    public var soThe: Int { cocThe.arrangedSubviews.count }

    public func themLuot(by ai: Ai, text: String) {
        let (nhan, mau): (String, NSColor) = {
            switch ai {
            case .nguoi:   return ("Anh", EideToken.Mau.text)
            case .tacTu:   return ("EIDE", EideToken.Mau.secondary)
            case .cho:     return ("Chờ anh", EideToken.Mau.warn)      // U2: việc cần người
            case .loi:     return ("Lỗi", EideToken.Mau.bad)
            case .heThong: return ("·", EideToken.Mau.muted)
            }
        }()
        let d = NSMutableAttributedString(
            string: "\(nhan): ",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: mau])
        d.append(NSAttributedString(
            string: text + "\n",
            attributes: [.font: EideToken.fontUI, .foregroundColor: EideToken.Mau.text]))
        van.textStorage?.append(d)
        van.scrollToEndOfDocument(nil)
    }
}

/// Hàng đợi — UXD-13 U2 và §4 (QueueList).
///
/// U2: HAI danh sách, "chờ tôi" và "đã làm — hoàn tác được". Tách hai danh sách là điểm chính,
/// không phải cách trình bày: chúng trả lời hai câu hỏi khác nhau — *tôi phải làm gì bây giờ* và
/// *máy vừa làm gì mà tôi còn rút lại được*. Gộp một danh sách thì câu thứ hai biến mất, và
/// "làm rồi báo cáo" mất vế báo cáo.
///
/// §4 đòi mỗi mục có "tag cổng, tóm tắt, rủi ro, lý do quy tắc, hạn hoàn tác" và hành động
/// "duyệt/từ chối/hoàn tác/hàng loạt". Ba hành động đầu có ở đây; **hàng loạt thì chưa, có chủ
/// ý**: duyệt hàng loạt một chồng mục ASK lẫn lộn nhiều cổng và nhiều lớp rủi ro chính là cách
/// biến cổng chính sách thành một con dấu. Nếu làm, nó phải gom theo cùng cổng + cùng quy tắc để
/// người duyệt MỘT LOẠI quyết định chứ không phải một đống — và đó là một thiết kế cần bàn, không
/// phải một nút thêm vào cho đủ. Xem DEVIATIONS DEV-050.
public final class ReviewQueueView: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hàng đợi: chờ tôi và đã làm" }

    /// (run_id, "approve" | "reject")
    public var onQuyetDinh: ((String, String) -> Void)?
    /// (undo_ref)
    public var onHoanTac: ((String) -> Void)?

    private let choNhan = NSTextField(labelWithString: "Chờ anh")
    private let hoanTacNhan = NSTextField(labelWithString: "Đã làm — hoàn tác được")
    private let choCot = NSStackView()
    private let hoanTacCot = NSStackView()

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        for (n, m) in [(choNhan, EideToken.Mau.warn), (hoanTacNhan, EideToken.Mau.ok)] {
            n.font = NSFont.boldSystemFont(ofSize: 12)
            n.textColor = m
        }
        for c in [choCot, hoanTacCot] {
            c.orientation = .vertical
            c.alignment = .leading
            c.spacing = EideToken.space[1]
        }
        let cot1 = NSStackView(views: [choNhan, choCot])
        let cot2 = NSStackView(views: [hoanTacNhan, hoanTacCot])
        for c in [cot1, cot2] {
            c.orientation = .vertical
            c.alignment = .leading
            c.spacing = EideToken.space[0]
        }
        let hang = NSStackView(views: [cot1, cot2])
        hang.orientation = .horizontal
        hang.distribution = .fillEqually
        hang.spacing = EideToken.space[3]
        hang.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hang)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: topAnchor, constant: s),
            hang.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            hang.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            hang.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -s),
        ])
        capNhat(cho: [], hoanTac: [])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Số nút hành động đang hiện — cho test đếm mà không phải dựng cả cửa sổ.
    public private(set) var soNut = 0

    /// Mục "đã làm" gần nhất còn hoàn tác được — cho ⌘Z của UXD-13 §6.
    ///
    /// Trả `false` khi không có gì để hoàn tác, và panel chuyển phím lại cho GEditor (nơi ⌘Z
    /// là "Hoàn tác" của trình soạn thảo). Nuốt phím rồi không làm gì là cách tệ nhất: người
    /// dùng bấm hai lần, rồi ba lần, rồi tưởng ứng dụng treo.
    ///
    /// **Hoàn tác cái GẦN NHẤT, không phải cái đang chọn.** UXD-13 §6 ghi "hoàn tác mục đã
    /// chọn", nhưng danh sách này chưa có khái niệm chọn — và cái gần nhất là thứ người vừa
    /// thấy máy làm, tức thứ họ định rút lại khi bấm ⌘Z. Xem DEV-096.
    @discardableResult
    public func hoanTacMucDau() -> Bool {
        guard let uref = _urefGanNhat else { return false }
        onHoanTac?(uref)
        return true
    }

    private var _urefGanNhat: String?

    /// Kết quả `kg.review_facts` — duyệt hàng loạt fact ở cổng G-FACT.
    ///
    /// **`rejected` không được gộp vào `asked`.** KG-06 tách riêng ba con số: đã duyệt, còn
    /// hỏi, và **bị TỪ CHỐI** — nhánh REJECT của G-FACT, ví dụ fact tầng đồng không được vào
    /// tri thức dù người bấm duyệt. Gộp "từ chối" vào "còn hỏi" khiến người dùng chờ một câu
    /// hỏi không bao giờ tới, cho một fact đã bị chính sách loại.
    public func capNhatDuyetLoat(_ ketQua: [String: Any]) {
        let duyet = EideSo.nguyen(ketQua["reviewed"]) ?? 0
        let hoi = EideSo.nguyen(ketQua["asked"]) ?? 0
        let tuChoi = EideSo.nguyen(ketQua["rejected"]) ?? 0
        guard duyet + hoi + tuChoi > 0 else { return }
        choCot.addArrangedSubview(_nhanMo(
            "duyệt loạt: \(duyet) đã vào tri thức · \(hoi) còn hỏi"
            + (tuChoi > 0 ? " · \(tuChoi) BỊ CHÍNH SÁCH TỪ CHỐI" : "")))
    }

    public func capNhat(cho: [[String: Any]], hoanTac: [[String: Any]]) {
        _urefGanNhat = hoanTac.first.flatMap {
            ($0["undo_ref"] as? String) ?? ($0["id"] as? String)
        }
        choNhan.stringValue = "Chờ anh (\(cho.count))"
        hoanTacNhan.stringValue = "Đã làm — hoàn tác được (\(hoanTac.count))"
        for c in [choCot, hoanTacCot] {
            for v in c.arrangedSubviews { c.removeArrangedSubview(v); v.removeFromSuperview() }
        }
        soNut = 0

        // U9: "mọi panel có ba trạng thái thiết kế sẵn" — rỗng phải NÓI RA là rỗng, không để một
        // khoảng trắng khiến người dùng tưởng đang tải.
        if cho.isEmpty {
            choCot.addArrangedSubview(_nhanMo("Không có việc nào chờ anh."))
        }
        for m in cho { choCot.addArrangedSubview(_dongCho(m)) }

        if hoanTac.isEmpty {
            hoanTacCot.addArrangedSubview(_nhanMo("Chưa có việc nào tự làm."))
        }
        for m in hoanTac { hoanTacCot.addArrangedSubview(_dongHoanTac(m)) }
    }

    private func _nhanMo(_ t: String) -> NSTextField {
        let v = NSTextField(labelWithString: t)
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.muted
        return v
    }

    private func _dongCho(_ m: [String: Any]) -> NSView {
        let rid = (m["run_id"] as? String) ?? ""
        let d = (m["decision"] as? [String: Any]) ?? [:]
        let cap = (m["cap"] as? String) ?? "?"
        let cong = (d["gate"] as? String) ?? ""
        let quy = (d["rule"] as? String) ?? ""
        let ly = (d["reason"] as? String) ?? ""

        let coc = NSStackView()
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 2
        coc.addArrangedSubview(_manh("\(cap)   \(cong.isEmpty ? "" : "[\(cong)]") \(quy)",
                                     dam: true, mau: EideToken.Mau.text))
        // §4 đòi "lý do quy tắc" hiện ra: người duyệt cần biết VÌ SAO máy hỏi, không chỉ biết là
        // nó đang hỏi. Không có câu ấy thì mọi mục trông giống nhau và người bấm theo thói quen.
        if !ly.isEmpty { coc.addArrangedSubview(_manh(ly, dam: false, mau: EideToken.Mau.muted)) }

        let nut = NSStackView()
        nut.orientation = .horizontal
        nut.spacing = EideToken.space[1]
        for (nhan, quyet) in [("Duyệt", "approve"), ("Từ chối", "reject")] {
            let b = NSButton(title: nhan, target: self, action: #selector(_bamQuyetDinh(_:)))
            b.bezelStyle = .rounded
            b.font = EideToken.fontUI
            b.identifier = NSUserInterfaceItemIdentifier("\(quyet):\(rid)")
            b.setAccessibilityLabel("\(nhan) \(cap). Lý do máy hỏi: \(ly)")
            nut.addArrangedSubview(b)
            soNut += 1
        }
        coc.addArrangedSubview(nut)
        return coc
    }

    private func _dongHoanTac(_ m: [String: Any]) -> NSView {
        let uref = (m["undo_ref"] as? String) ?? ""
        let cap = (m["cap"] as? String) ?? "?"
        let loai = (m["kind"] as? String) ?? ""
        let han = String(((m["deadline"] as? String) ?? "hết phiên").prefix(16))

        let coc = NSStackView()
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 2
        coc.addArrangedSubview(_manh("\(cap)   \(loai)", dam: true, mau: EideToken.Mau.text))
        coc.addArrangedSubview(_manh("hoàn tác được đến \(han)", dam: false, mau: EideToken.Mau.muted))
        let b = NSButton(title: "Hoàn tác", target: self, action: #selector(_bamHoanTac(_:)))
        b.bezelStyle = .rounded
        b.font = EideToken.fontUI
        b.identifier = NSUserInterfaceItemIdentifier(uref)
        b.setAccessibilityLabel("Hoàn tác \(cap), loại \(loai), hạn \(han)")
        coc.addArrangedSubview(b)
        soNut += 1
        return coc
    }

    private func _manh(_ t: String, dam: Bool, mau: NSColor) -> NSTextField {
        let v = NSTextField(labelWithString: t)
        v.font = dam ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI
        v.textColor = mau
        v.lineBreakMode = .byTruncatingTail
        return v
    }

    @objc private func _bamQuyetDinh(_ s: NSButton) {
        let p = (s.identifier?.rawValue ?? "").split(separator: ":", maxSplits: 1)
        guard p.count == 2 else { return }
        onQuyetDinh?(String(p[1]), String(p[0]))
    }

    @objc private func _bamHoanTac(_ s: NSButton) {
        guard let u = s.identifier?.rawValue, !u.isEmpty else { return }
        onHoanTac?(u)
    }
}
