import AppKit

/// Hai thẻ của UXD-13 §4 mà kênh sự kiện phát ra nhưng chưa ai hiện: **thẻ ý hiểu** và
/// **thẻ tiến độ chuỗi**.
///
/// Spec: UXD-13 §4 (RestateCard, RunProgress), §3 (tương tác "Nhấp Sửa ý hiểu", "Nhấp nút
/// chuỗi"), U2 (làm rồi báo cáo, nhìn thấy được); API-15 §1 `event.chat.restated`
/// `{intent_id, text}`, `event.run.progress` `{run_id, node_id, cap, state, pct?}`,
/// `event.job.progress` `{job_id, pct, log_tail[]}`, `job.cancel`.
///
/// ## Vì sao hai thẻ này là phần cuối, không phải phần thừa
///
/// Chúng là hai chỗ duy nhất trong cả giao diện trả lời câu hỏi *"máy đang làm gì lúc này"*.
/// Mọi khung nhìn khác hiện **kết quả** — thứ đã xong. Giữa lúc một chuỗi 17 bước đang chạy,
/// người dùng nhìn vào panel và thấy… hội thoại đứng yên. U2 nói "làm rồi báo cáo, NHÌN THẤY
/// ĐƯỢC", và phần "nhìn thấy được" không chỉ nói về lúc xong.

// MARK: - Thẻ ý hiểu

/// `event.chat.restated` `{intent_id, text}` — "Tôi hiểu là…" kèm lối SỬA.
///
/// **Nút "Sửa ý hiểu" là phần quan trọng hơn cả câu văn.** DPS-09 chấp nhận rằng mô hình hiểu
/// sai; điều không chấp nhận được là người dùng nhìn thấy nó hiểu sai mà không có đường nào
/// nói lại ngoài việc gõ lại từ đầu. UXD-13 §3 nói rõ: bấm vào thì ô lệnh được điền sẵn văn
/// bản ý hiểu để người sửa.
public final class RestateCard: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Thẻ ý hiểu" }

    /// (text) — người bấm "Sửa ý hiểu"; panel điền `text` vào ô lệnh.
    public var onSua: ((String) -> Void)?

    private let van = NSTextField(wrappingLabelWithString: "")
    private let buoc = NSStackView()
    private var noiDung = ""

    /// Số bước rút gọn đang hiện.
    public private(set) var soBuoc = 0

    public init(text: String, buoc ds: [String] = [], intentId: String = "") {
        super.init(frame: .zero)
        noiDung = text
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.infoBg.cgColor
        layer?.cornerRadius = EideToken.radius[0]

        let tieu = NSTextField(labelWithString: "Tôi hiểu là…")
        tieu.font = NSFont.boldSystemFont(ofSize: 12)
        tieu.textColor = EideToken.Mau.info

        van.stringValue = text.isEmpty ? "(máy không nói được nó hiểu gì)" : text
        van.font = EideToken.fontUI
        van.textColor = text.isEmpty ? EideToken.Mau.warn : EideToken.Mau.text

        buoc.orientation = .vertical
        buoc.alignment = .leading
        buoc.spacing = 2
        for (i, b) in ds.prefix(8).enumerated() {
            let l = NSTextField(labelWithString: "\(i + 1). \(b)")
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.muted
            buoc.addArrangedSubview(l)
            soBuoc += 1
        }
        if ds.count > 8 {
            let l = NSTextField(labelWithString: "… và \(ds.count - 8) bước nữa")
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.muted
            buoc.addArrangedSubview(l)
        }

        let nut = NSButton(title: "Sửa ý hiểu", target: self, action: #selector(sua))
        nut.bezelStyle = .inline
        nut.font = EideToken.fontUI
        nut.setAccessibilityLabel("Sửa ý hiểu — điền câu này vào ô lệnh để anh sửa")

        let coc = NSStackView(views: [tieu, van, buoc, nut])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = EideToken.space[1]
        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor, constant: s),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -s),
            van.widthAnchor.constraint(equalTo: coc.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func sua() { onSua?(noiDung) }
}

// MARK: - Thẻ tiến độ chuỗi

/// `event.run.progress` — chip theo trạng thái từng nút của chuỗi, kèm nút HUỶ.
///
/// **Một chuỗi đang chạy phải huỷ được từ giao diện.** UXD-13 §4 nói "hủy nút", và
/// `event.job.progress` đi cùng `job.cancel` trong API-15 vì cùng một lý do: một việc nặng
/// chạy nền mà người dùng chỉ biết đứng nhìn là một việc họ sẽ tắt cả ứng dụng để dừng.
///
/// **Thẻ này gộp theo `run_id`, không tạo thẻ mới cho mỗi thông điệp.** Daemon phát một
/// `event.run.progress` cho mỗi nút bắt đầu và mỗi nút xong; một chuỗi 17 bước sinh 34 thông
/// điệp, và 34 thẻ chồng lên nhau thì không ai đọc được cái nào.
public final class RunProgressCard: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Tiến độ chuỗi \(runId)" }

    /// (run_id | job_id) — người bấm HUỶ.
    public var onHuy: ((String) -> Void)?
    /// (cap) — bấm một chip để xem chi tiết CapabilityRun.
    public var onXemNut: ((String) -> Void)?

    public let runId: String
    private let tomTat = NSTextField(labelWithString: "")
    private let hang = NSStackView()
    private let nutHuy = NSButton()

    /// Trạng thái từng nút, theo thứ tự xuất hiện. Khoá là `node_id` hoặc `cap`.
    private var trangThai: [(khoa: String, cap: String, state: String)] = []

    public private(set) var soNut = 0
    public private(set) var daXong = false

    /// Gọi MỘT LẦN khi thẻ vừa chuyển sang xong — panel dùng để gỡ thẻ đi.
    public var onXong: (() -> Void)?
    private var daBaoXong = false
    /// Tên năng lực đã thấy trong các sự kiện của lượt chạy này, theo thứ tự.
    private var _tenDaThay: [String] = []

    /// Dải chip từng nút. Ẩn khi chưa có nút nào — xem `capNhat`.
    private let _cuonChip = NSScrollView()
    /// Phần trăm gần nhất, `nil` nếu daemon chưa gửi.
    public private(set) var phanTram: Int?

    /// Dòng tóm tắt — cho test đọc mà không phải dò cây khung nhìn.
    public var tomTat_choTest: String { tomTat.stringValue }

    public init(runId: String) {
        self.runId = runId
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        tomTat.font = EideToken.fontUI
        tomTat.textColor = EideToken.Mau.muted
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[1]

        nutHuy.title = "Huỷ"
        nutHuy.bezelStyle = .inline
        nutHuy.font = EideToken.fontUI
        nutHuy.target = self
        nutHuy.action = #selector(huy)

        let cuon = _cuonChip
        cuon.documentView = hang
        cuon.hasHorizontalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false

        let dau = NSStackView(views: [tomTat, nutHuy])
        dau.orientation = .horizontal
        dau.alignment = .centerY
        dau.spacing = EideToken.space[1]

        let coc = NSStackView(views: [dau, cuon])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = EideToken.space[1]
        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor, constant: s),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -s),
            cuon.widthAnchor.constraint(equalTo: coc.widthAnchor),
            cuon.heightAnchor.constraint(equalToConstant: 28),
        ])
        capNhat([:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Nhận một `event.run.progress` hoặc `event.job.progress`.
    ///
    /// Thông điệp bắt đầu mang `cap`, thông điệp kết thúc mang `status` — hai hình dạng khác
    /// nhau cho cùng một nút, và chúng phải gộp về một chip chứ không thành hai.
    public func capNhat(_ p: [String: Any]) {
        let cap = (p["cap"] as? String) ?? ""
        let khoa = (p["node_id"] as? String) ?? cap
        let tt = (p["state"] as? String) ?? (p["status"] as? String) ?? ""
        if let pc = EideSo.nguyen(p["pct"]) { phanTram = pc }

        if !khoa.isEmpty || !tt.isEmpty {
            if let i = trangThai.firstIndex(where: { $0.khoa == khoa && !khoa.isEmpty }) {
                trangThai[i].state = tt.isEmpty ? trangThai[i].state : tt
                if !cap.isEmpty { trangThai[i].cap = cap }
            } else if !khoa.isEmpty {
                trangThai.append((khoa, cap, tt.isEmpty ? "running" : tt))
            }
        }

        // `log_tail` của `event.job.progress` — mấy dòng cuối của một việc nặng. Không hiện
        // thì "đang chạy 40%" là tất cả những gì người dùng biết trong ba phút.
        let duoi = (p["log_tail"] as? [String]) ?? []

        soNut = trangThai.count
        daXong = !trangThai.isEmpty && trangThai.allSatisfy {
            ["done", "failed", "cancelled"].contains($0.state)
        }
        nutHuy.isHidden = daXong
        if daXong && !daBaoXong {
            daBaoXong = true
            onXong?()
        }

        var d: [String] = []
        let xong = trangThai.filter { $0.state == "done" }.count
        if soNut > 0 { d.append("\(xong)/\(soNut) bước") }
        if let pc = phanTram { d.append("\(pc)%") }
        if daXong { d.append("xong") }
        if let l = duoi.last, !l.isEmpty { d.append(l) }
        // TÊN NĂNG LỰC lên trước, mã lượt chạy chỉ là đuôi.
        //
        // Thẻ vốn ghi `12b8c3f535b8 · 1/1 bước · xong` — một mã băm mười hai ký tự làm nhãn cho
        // một việc vừa chạy. Người dùng không tra được mã ấy ở đâu, và mười lăm thẻ như thế xếp
        // chồng thì không thẻ nào nói được việc gì vừa xảy ra. Tên năng lực thì họ đọc được
        // ngay, và `caps.describe` tra được. Đo 16/09/2026 trong vòng chạy qua giao diện.
        // Nhớ tên năng lực NGAY từ sự kiện đầu tiên. `trangThai` chỉ có mục khi sự kiện mang
        // `node_id`, mà sự kiện mở màn của một lượt chạy đơn thì không — nên thẻ hiện "Đang chạy
        // 038c110c8b65…" suốt cả lượt. Đo 16/09/2026: ba thẻ cùng lúc, cả ba là mã băm.
        if !cap.isEmpty, !_tenDaThay.contains(cap) { _tenDaThay.append(cap) }
        // Dải chip cao 28 pt cố định, kể cả khi RỖNG. Một chuỗi nhiều nút thì dải ấy đáng giá;
        // một lượt chạy đơn không có nút nào, và ba thẻ như thế ăn 270 pt của vùng trao đổi —
        // đủ để đẩy lượt đối thoại mới nhất ra ngoài tầm nhìn. Trong NSStackView, `isHidden`
        // THU HỒI chỗ (khác với ràng buộc thường), nên chỉ cần bật cờ.
        _cuonChip.isHidden = trangThai.isEmpty
        let ten = _tenDaThay
        let nhanChinh = ten.isEmpty ? runId
            : (ten.count == 1 ? ten[0] : "\(ten[0]) +\(ten.count - 1)")
        tomTat.stringValue = d.isEmpty ? "Đang chạy \(nhanChinh)…"
                                       : "\(nhanChinh) · " + d.joined(separator: " · ")
        tomTat.textColor = daXong ? EideToken.Mau.muted : EideToken.Mau.info

        for v in hang.arrangedSubviews { hang.removeArrangedSubview(v); v.removeFromSuperview() }
        for t in trangThai {
            let b = NSButton(title: Self.nhanNut(t.cap.isEmpty ? t.khoa : t.cap, t.state),
                             target: self, action: #selector(xemNut(_:)))
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.contentTintColor = Self.mauTrangThai(t.state)
            b.identifier = NSUserInterfaceItemIdentifier(t.cap.isEmpty ? t.khoa : t.cap)
            hang.addArrangedSubview(b)
        }
    }

    /// Năm trạng thái của UXD-13 §4: xong / đang / chờ / hỏi / song song.
    static func nhanNut(_ ten: String, _ state: String) -> String {
        let dau: String
        switch state {
        case "done": dau = "✓"
        case "failed", "error": dau = "✗"
        case "cancelled": dau = "⊘"
        case "pending", "ask": dau = "?"      // chờ người — U9 đòi nhìn thấy được
        case "waiting", "queued": dau = "·"
        default: dau = "▸"                     // đang chạy
        }
        return "\(dau) \(EideKnowledgeFormat.tenNgan(ten))"
    }

    static func mauTrangThai(_ state: String) -> NSColor {
        switch state {
        case "done": return EideToken.Mau.ok
        case "failed", "error": return EideToken.Mau.bad
        case "pending", "ask": return EideToken.Mau.warn
        case "cancelled": return EideToken.Mau.muted
        default: return EideToken.Mau.info
        }
    }

    @objc private func huy() { onHuy?(runId) }

    @objc private func xemNut(_ s: NSButton) {
        if let c = s.identifier?.rawValue, !c.isEmpty { onXemNut?(c) }
    }
}
