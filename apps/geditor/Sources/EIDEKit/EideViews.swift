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

    /// Người đổi mức tự chủ — APD-08 §2 (A0…A4).
    ///
    /// Đây là núm điều khiển CHÍNH của cả chính sách tự chủ, và trước 14/09/2026 giao diện
    /// không có nó: muốn đổi A2 ↔ A3 phải sửa `.eide/autonomy.yaml` bằng tay rồi khởi động lại
    /// daemon. Một cơ chế chỉ dùng được bằng cách sửa tệp cấu hình là một cơ chế người dùng
    /// không dùng — và khi ấy mức mặc định thành mức duy nhất.
    public var onDoiMuc: ((String) -> Void)?

    /// Người bấm vào tên dự án — mở menu chọn/tạo dự án.
    ///
    /// **Điểm vào đầu tiên của cả sản phẩm.** Trước 14/09 nó chỉ nằm trong menu Tệp, và một
    /// người mới mở EIDE lên không có cách nào biết mình phải vào đó: cửa sổ hiện 21 màn trống
    /// mà không nói rằng chúng trống VÌ CHƯA CÓ DỰ ÁN. Đặt lên thanh luôn hiện, cạnh mức tự
    /// chủ, vì đó là hai thứ trả lời câu "tôi đang ở đâu và tác tử được phép làm gì".
    public var onChonDuAn: (() -> Void)?

    private let nutDuAn = NSButton()
    private let nhan = NSTextField(labelWithString: "…")
    private let nutDung = NSButton()
    private let chonMuc = NSPopUpButton()
    private let bangTin = NSTextField(labelWithString: "")

    /// Năm mức của APD-08 §2, kèm một câu nói mức ấy cho phép tác tử làm gì.
    ///
    /// Câu giải thích không phải trang trí: "A3" tự nó không nói gì, và người chọn một mức mà
    /// không biết nó mở ra cái gì thì hoặc chọn bừa, hoặc không dám chọn.
    public static let MUC: [(ma: String, mo: String)] = [
        ("A0", "A0 — dừng, không tự làm gì"),
        ("A1", "A1 — chỉ đọc và tra cứu"),
        ("A2", "A2 — tự ghi tri thức và sinh mã"),
        ("A3", "A3 — thêm: cài công cụ, nạp board lab"),
        ("A4", "A4 — tự chủ tối đa trong lớp rủi ro cho phép"),
    ]

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.secondary.cgColor

        nhan.font = EideToken.fontUI
        nhan.textColor = .white
        nutDuAn.title = "Chưa mở dự án ▾"
        nutDuAn.bezelStyle = .rounded
        nutDuAn.font = EideToken.fontUI
        nutDuAn.target = self
        nutDuAn.action = #selector(bamDuAn)
        nutDuAn.setAccessibilityLabel("Dự án đang mở — bấm để chọn hoặc tạo dự án")
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

        for (i, m) in Self.MUC.enumerated() {
            chonMuc.addItem(withTitle: m.mo)
            chonMuc.item(at: i)?.representedObject = m.ma
        }
        chonMuc.target = self
        chonMuc.action = #selector(doiMuc)
        chonMuc.bezelStyle = .rounded
        chonMuc.setAccessibilityLabel("Mức tự chủ")

        // Băng tin leo thang: mặc định ẩn. Nó chỉ hiện khi tác tử ĐANG DỪNG CHỜ người, và đó
        // phải là thứ khác hẳn một dòng lẫn trong hội thoại — `policy.escalate` nghĩa là công
        // việc đã dừng lại, không phải một ghi chú.
        bangTin.font = EideToken.fontUI
        bangTin.textColor = .white
        bangTin.isHidden = true
        bangTin.setAccessibilityLabel("Tác tử đang chờ người")

        for v in [nutDuAn, nhan, nutDung, chonMuc, bangTin] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            nutDuAn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            nutDuAn.centerYAnchor.constraint(equalTo: centerYAnchor),

            nhan.leadingAnchor.constraint(equalTo: nutDuAn.trailingAnchor, constant: s),
            nhan.centerYAnchor.constraint(equalTo: centerYAnchor),

            nutDung.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            nutDung.centerYAnchor.constraint(equalTo: centerYAnchor),

            chonMuc.trailingAnchor.constraint(equalTo: nutDung.leadingAnchor, constant: -s),
            chonMuc.centerYAnchor.constraint(equalTo: centerYAnchor),
            chonMuc.widthAnchor.constraint(lessThanOrEqualToConstant: 300),

            nhan.trailingAnchor.constraint(lessThanOrEqualTo: bangTin.leadingAnchor, constant: -s),
            bangTin.trailingAnchor.constraint(lessThanOrEqualTo: chonMuc.leadingAnchor,
                                              constant: -s),
            bangTin.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func dung() { onDungKhan?() }

    @objc private func bamDuAn() { onChonDuAn?() }

    /// Tên dự án đang mở, hoặc nil khi chưa mở dự án nào.
    ///
    /// Nói "Chưa mở dự án" chứ không để trống: một nút trống trên thanh là một nút người dùng
    /// không biết để làm gì, còn câu ấy vừa nói tình trạng vừa mời bấm vào.
    public func datDuAn(_ ten: String?) {
        nutDuAn.title = (ten.map { "Dự án: \($0)" } ?? "Chưa mở dự án") + " ▾"
    }

    /// Nhãn đang hiện trên nút dự án — để test.
    public var nhanDuAn: String { nutDuAn.title }

    /// Bấm nút dự án bằng mã — dùng cho test và cho phím tắt về sau.
    public func bamDuAnDeTest() { bamDuAn() }

    @objc private func doiMuc() {
        guard let ma = chonMuc.selectedItem?.representedObject as? String else { return }
        // Không tự đổi nhãn ở đây. Mức có hiệu lực do daemon quyết — POL-17 tính nó từ dự án,
        // board và loại hành động — nên panel phải hỏi lại và hiện thứ daemon TRẢ VỀ. Đổi nhãn
        // ngay là hứa một điều chưa chắc xảy ra: A4 chọn trên một board chưa đánh dấu lab vẫn
        // bị hạ xuống, và người dùng thì đang nhìn chữ "A4".
        onDoiMuc?(ma)
    }

    public func capNhat(muc: String?, dungKhan: Bool, soCho: Int, soHoanTac: Int) {
        // U10: "không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)" — trạng thái dừng được nói
        // bằng CHỮ, màu chỉ là lớp thứ hai. Người mù màu vẫn phải đọc được.
        let m = dungKhan ? "■ ĐÃ DỪNG (A0)" : (muc ?? "—")
        nhan.stringValue = "\(m)  ·  \(soCho) chờ anh  ·  \(soHoanTac) hoàn tác được"
        layer?.backgroundColor = (dungKhan ? EideToken.Mau.primary : EideToken.Mau.secondary).cgColor

        // Đồng bộ ô chọn với mức THẬT. Mức daemon trả về có thể khác mức người vừa chọn (xem
        // `doiMuc`), và để ô chọn đứng ở lựa chọn cũ là để nó nói dối.
        let ma = dungKhan ? "A0" : (muc ?? "")
        if let i = Self.MUC.firstIndex(where: { ma.hasPrefix($0.ma) }) {
            chonMuc.selectItem(at: i)
        }
        chonMuc.isEnabled = !dungKhan
    }

    /// Hiện băng tin "tác tử đang chờ người", hoặc ẩn nó đi.
    ///
    /// APD-08 §5 kể năm lý do leo thang: cổng trả ASK, một hành động hỏng 2 lần, ngân sách còn
    /// dưới 20%, board lệch hộ chiếu, mẫu bất thường. Cả năm đều có nghĩa "công việc dừng ở
    /// đây cho tới khi anh trả lời", và chỗ đúng để nói điều đó là thanh LUÔN HIỆN.
    public func leoThang(_ vi: String?) {
        guard let vi, !vi.isEmpty else {
            bangTin.isHidden = true
            return
        }
        bangTin.stringValue = "⚠︎ ĐANG CHỜ ANH: \(vi)"
        bangTin.isHidden = false
    }

    /// Mức đang hiện trên ô chọn — để test và để panel đối chiếu.
    public var mucDangChon: String? {
        chonMuc.selectedItem?.representedObject as? String
    }

    public var dangBaoLeoThang: Bool { !bangTin.isHidden }
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
        hang.alignment = .top
        hang.spacing = EideToken.space[3]
        hang.translatesAutoresizingMaskIntoConstraints = false

        // CUỘN, không phải `bottomAnchor <= bottomAnchor`.
        //
        // Ràng buộc "nhỏ hơn hoặc bằng" cho phép stack tràn ra ngoài khung khi danh sách dài,
        // và AppKit vẽ đè chứ không cắt: đo trên một store thật có 56 mục chờ thì 56 cặp nút
        // "Duyệt"/"Từ chối" chồng lên nhau thành một khối đặc, không đọc được và không bấm
        // đúng được. Hàng đợi là chỗ người duyệt việc cho tác tử — một danh sách không đọc
        // được ở đây nghĩa là người bấm bừa hoặc bỏ qua.
        let cuonHang = NSScrollView()
        cuonHang.documentView = hang
        cuonHang.hasVerticalScroller = true
        cuonHang.drawsBackground = false
        cuonHang.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuonHang)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            cuonHang.topAnchor.constraint(equalTo: topAnchor, constant: s),
            cuonHang.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            cuonHang.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            cuonHang.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -s),
            hang.widthAnchor.constraint(equalTo: cuonHang.widthAnchor),
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
