import AppKit

/// Ba khung nhìn TRI THỨC — UXD-13 màn 5 (Passport), 7 (Graph → RagAsk), 10 (Doc).
///
/// Spec: UXD-13 U2 (nhìn thấy được), U5 (mọi nút là một năng lực), U8 (tiếng Việt trước),
/// U9 (ba trạng thái rỗng/lỗi/chờ), U10 (tương phản, bàn phím); API-15 §1 `passport.query`,
/// `view.rag_ask`, `view.provenance`, `doc.open`; KAD-07 (tầng tri thức, tầng tin cậy).
///
/// ## Vì sao ba màn này trước hai mươi màn kia
///
/// Chúng là ba màn cho thấy đúng luận điểm của sản phẩm, và không màn nào khác thay được:
/// **tri thức có trích dẫn** (Passport), **truy nguồn được** (RagAsk), và **tài liệu tự sinh
/// từ chính tri thức ấy** (Doc). Mười bảy màn còn lại là khung nhìn chuyên đề — Bench,
/// Discovery, Debug probe — và phần lớn chúng chưa có dữ liệu để hiện, vì dữ liệu ấy đến từ
/// một bo mạch chưa cắm.
///
/// ## Một bất biến chung cho cả ba
///
/// **Không khung nhìn nào ở đây được hiện một con số mà không hiện nguồn của nó.** Đó là lý do
/// `PassportView` luôn kèm cột `nguồn`, `RagAskView` từ chối hiện câu trả lời không có trích
/// dẫn, và `DocView` tô xám mục lỗi thời. Một giao diện đẹp hiện ra con số `0x76` mà không nói
/// ai bảo thế thì nó vừa phá đúng thứ cả tầng tri thức được dựng lên để giữ.

// MARK: - Màn 5: Hộ chiếu chip

/// Bảng fact của một hộ chiếu, kèm tầng tin cậy và nguồn.
public final class PassportView: NSView, KhungNhinEide {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hộ chiếu chip" }

    /// (part) — người gõ mã linh kiện rồi Enter.
    public var onTra: ((String) -> Void)?
    /// (fact_id) — bấm vào một dòng để xem chuỗi truy nguồn.
    public var onXemNguon: ((String) -> Void)?

    private let o = NSTextField()
    private let tomTat = NSTextField(labelWithString: "")
    private let bang = NSStackView()

    /// Số dòng fact đang hiện — cho test đếm mà không phải dựng cả cửa sổ.
    public private(set) var soDong = 0

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        o.placeholderString = "Mã linh kiện — ví dụ st.stm32f411ce"
        o.font = EideToken.fontUI
        o.target = self
        o.action = #selector(guiTra)
        tomTat.font = EideToken.fontUI
        tomTat.textColor = EideToken.Mau.muted
        bang.orientation = .vertical
        bang.alignment = .leading
        bang.spacing = 2

        let coc = NSStackView(views: [o, tomTat, bang])
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
            coc.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -s),
            o.widthAnchor.constraint(equalTo: coc.widthAnchor),
        ])
        capNhat(ketQua: [:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func guiTra() {
        let t = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { onTra?(t) }
    }

    /// Điền sẵn ô nhập — KHÔNG tự tra. Người mở màn bằng `/passport.query stm32` có thể muốn
    /// sửa lại mã trước khi tra, và một màn tự chạy ngay lúc mở là một màn họ không kiểm soát.
    public func dienSan(_ t: String) { o.stringValue = t }

    /// Nội dung ô nhập — cho test đọc mà không phải giả lập gõ phím.
    public var noiDungO: String { o.stringValue }

    /// Kết quả `passport.query`: `{facts[], citations[], tiers{}, latency_ms}`.
    ///
    /// **`latency_ms` hiện ra, không giấu đi.** PASSPORT-02 bước 1 đòi "< 200 ms", và một con
    /// số hứa trong hợp đồng mà giao diện không bao giờ hiện thì không ai biết lúc nó thôi
    /// đúng — đúng loại im lặng mà cả dự án này dành nhiều công để tránh.
    public func capNhat(ketQua: [String: Any]) {
        for v in bang.arrangedSubviews { bang.removeArrangedSubview(v); v.removeFromSuperview() }
        soDong = 0

        let facts = (ketQua["facts"] as? [[String: Any]]) ?? []
        let cit = (ketQua["citations"] as? [[String: Any]]) ?? []
        let tiers = (ketQua["tiers"] as? [String: Any]) ?? [:]
        let ms = EideSo.nguyen(ketQua["latency_ms"]) ?? 0

        if facts.isEmpty {
            tomTat.stringValue = ketQua.isEmpty
                ? "Gõ mã linh kiện rồi Enter để tra hộ chiếu."
                : "Không có fact nào cho mã này. Thử `extract.svd` hoặc `registry.pull` trước."
            bang.addArrangedSubview(_nhanMo(tomTat.stringValue))
            return
        }

        let vang = EideSo.nguyen(tiers["gold"]) ?? 0
        let bac = EideSo.nguyen(tiers["silver"]) ?? 0
        let dong = EideSo.nguyen(tiers["bronze"]) ?? 0
        tomTat.stringValue = "\(facts.count) fact · vàng \(vang) · bạc \(bac) · đồng \(dong)"
            + " · \(cit.count) nguồn · \(ms) ms"
        tomTat.textColor = ms > 200 ? EideToken.Mau.warn : EideToken.Mau.muted

        for f in facts {
            bang.addArrangedSubview(_dongFact(f))
            soDong += 1
        }
    }

    private func _dongFact(_ f: [String: Any]) -> NSView {
        let fid = (f["id"] as? String) ?? ""
        let subj = (f["subject"] as? String) ?? ""
        let pred = (f["predicate"] as? String) ?? ""
        let tier = (f["tier"] as? String) ?? "bronze"
        let st = (f["status"] as? String) ?? ""
        let gt = EideKnowledgeFormat.giaTri(f["value"])
        let don = (f["unit"] as? String).map { " \($0)" } ?? ""

        let nhan = NSTextField(labelWithString:
            "\(EideKnowledgeFormat.tenNgan(subj)) · \(pred) = \(gt)\(don)")
        nhan.font = EideToken.fontUI
        nhan.textColor = EideToken.Mau.text

        let huyHieu = NSTextField(labelWithString: EideKnowledgeFormat.nhanTang(tier, st))
        huyHieu.font = NSFont.boldSystemFont(ofSize: 10)
        huyHieu.textColor = EideKnowledgeFormat.mauTang(tier, st)

        // NGUỒN là nút, không phải nhãn: U5 nói "mọi nút là một năng lực", và nút này gọi
        // `view.provenance`. Hiện fact mà không mở được đường tới nguồn thì trích dẫn chỉ là
        // một chuỗi ký tự.
        let nut = NSButton(title: "nguồn", target: self, action: #selector(xemNguon(_:)))
        nut.bezelStyle = .inline
        nut.font = EideToken.fontUI
        nut.identifier = NSUserInterfaceItemIdentifier(fid)

        let hang = NSStackView(views: [huyHieu, nhan, nut])
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[1]
        return hang
    }

    @objc private func xemNguon(_ s: NSButton) {
        if let id = s.identifier?.rawValue, !id.isEmpty { onXemNguon?(id) }
    }

    private func _nhanMo(_ t: String) -> NSTextField {
        let v = NSTextField(labelWithString: t)
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.muted
        return v
    }
}

// MARK: - Màn 7: Hỏi đáp có trích dẫn

/// Ô hỏi RAG. **Câu trả lời KHÔNG có trích dẫn thì không hiện.**
public final class RagAskView: NSView, KhungNhinEide {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hỏi đáp có trích dẫn" }

    public var onHoi: ((String) -> Void)?
    public var onXemVet: ((String) -> Void)?

    private let o = NSTextField()
    private let traLoi = NSTextField(wrappingLabelWithString: "")
    private let cotTrich = NSStackView()
    private let nutVet = NSButton()

    public private(set) var soTrichDan = 0
    /// Có đang từ chối hiện câu trả lời vì thiếu trích dẫn không — cho test đọc.
    public private(set) var daChanVoTrichDan = false

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        o.placeholderString = "Hỏi về dự án — ví dụ: I2C1 dùng chân nào?"
        o.font = EideToken.fontUI
        o.target = self
        o.action = #selector(guiHoi)
        traLoi.font = EideToken.fontUI
        cotTrich.orientation = .vertical
        cotTrich.alignment = .leading
        cotTrich.spacing = 2
        nutVet.title = "Xem vết truy hồi"
        nutVet.bezelStyle = .inline
        nutVet.font = EideToken.fontUI
        nutVet.target = self
        nutVet.action = #selector(xemVet)
        nutVet.isHidden = true

        let coc = NSStackView(views: [o, traLoi, cotTrich, nutVet])
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
            coc.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -s),
            o.widthAnchor.constraint(equalTo: coc.widthAnchor),
            traLoi.widthAnchor.constraint(equalTo: coc.widthAnchor),
        ])
        capNhat(ketQua: [:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func guiHoi() {
        let t = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { onHoi?(t) }
    }

    /// Điền sẵn ô hỏi — không tự hỏi. Xem `PassportView.dienSan`.
    public func dienSan(_ t: String) { o.stringValue = t }

    public var noiDungO: String { o.stringValue }

    private var traceId = ""

    @objc private func xemVet() { if !traceId.isEmpty { onXemVet?(traceId) } }

    /// Kết quả `view.rag_ask`: `{answer, citations[], trace_id, not_found}`.
    ///
    /// **Không trích dẫn ⇒ không hiện câu trả lời.** Đây là chỗ dễ nhân nhượng nhất trong cả
    /// giao diện: mô hình đã trả lời rồi, câu văn trôi chảy, và giấu nó đi trông như phần mềm
    /// hỏng. Nhưng `view.rag_ask` sinh ra để trả lời *có nguồn*; một câu không nguồn hiện ở đây
    /// sẽ được người dùng đọc y như một câu có nguồn — và họ không có cách nào phân biệt.
    ///
    /// Hiện LÝ DO thay vì hiện khoảng trắng (U9): người dùng cần biết đây không phải lỗi mạng.
    public func capNhat(ketQua: [String: Any]) {
        for v in cotTrich.arrangedSubviews {
            cotTrich.removeArrangedSubview(v); v.removeFromSuperview()
        }
        soTrichDan = 0
        daChanVoTrichDan = false
        traceId = (ketQua["trace_id"] as? String) ?? ""
        nutVet.isHidden = traceId.isEmpty

        if ketQua.isEmpty {
            traLoi.stringValue = "Gõ câu hỏi rồi Enter."
            traLoi.textColor = EideToken.Mau.muted
            return
        }

        let cau = ((ketQua["answer"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trich = (ketQua["citations"] as? [[String: Any]]) ?? []

        if trich.isEmpty {
            daChanVoTrichDan = true
            nutVet.isHidden = true
            // HAI tình huống, HAI câu — và `not_found` là của hợp đồng, không phải suy từ
            // `answer` rỗng. "Tri thức chưa phủ" bảo người ta đi trích thêm tài liệu; "mô hình
            // trả lời mà không dẫn nguồn" bảo người ta nghi ngờ câu trả lời. Gộp một câu thì
            // người dùng làm sai việc trong nửa số lần.
            let khongThay = (ketQua["not_found"] as? Bool) ?? cau.isEmpty
            traLoi.stringValue = khongThay
                ? "Không tìm thấy gì trong tri thức của dự án cho câu hỏi này — thử `ingest.*` "
                  + "hoặc `extract.*` để nạp tài liệu trước."
                : "Mô hình có trả lời nhưng KHÔNG kèm trích dẫn nào, nên câu trả lời không hiện "
                  + "ở đây. Đừng tin câu vừa sinh ra: hỏi lại hẹp hơn, hoặc nạp tài liệu phủ "
                  + "đúng chỗ này rồi hỏi lại."
            traLoi.textColor = EideToken.Mau.warn
            return
        }

        traLoi.stringValue = cau
        traLoi.textColor = EideToken.Mau.text
        for t in trich {
            cotTrich.addArrangedSubview(_dongTrich(t))
            soTrichDan += 1
        }
    }

    private func _dongTrich(_ t: [String: Any]) -> NSView {
        let id = (t["source_id"] as? String) ?? (t["id"] as? String) ?? ""
        let uri = (t["uri"] as? String) ?? ""
        let tang = (t["tier"] as? String) ?? ""
        let trang = EideSo.nguyen(t["page"]).map { " · tr.\($0)" } ?? ""
        let v = NSTextField(labelWithString:
            "[\(id)] \(EideKnowledgeFormat.tenNgan(uri))\(trang)"
            + (tang.isEmpty ? "" : " · \(tang)"))
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.muted
        return v
    }
}

// MARK: - Màn 10: Tài liệu

/// Tài liệu vừa sinh: đường dẫn, lỗi văn phong theo `kind`, và mục LỖI THỜI.
///
/// Khung nhìn này gộp kết quả của ba năng lực vì ở màn 10 chúng là ba pha của MỘT việc:
/// `doc.generate` sinh ra tài liệu `{doc_id, path, style_issues}`, `doc.style_check` nói tài
/// liệu ấy sai chuẩn ở đâu `{issues[]{kind, location, text}}`, và `doc.sync` nói mục nào đã lỗi
/// thời `{stale[], updated[]}`. Tách thành ba panel thì người đọc thấy đường dẫn ở một chỗ và
/// cảnh báo ở chỗ khác — rồi mở tệp ra đọc mà không mang theo cảnh báo nào.
///
/// `uncited` được tô đậm hơn các `kind` khác. Nó là "câu có số liệu kỹ thuật không có [cite]"
/// (DOC-08 bước 1) — tức đúng thứ bất biến của cả ba màn này cấm, chỉ khác là lần này con số
/// không nguồn nằm trong một tệp sắp gửi cho người khác đọc.
public final class DocView: NSView, KhungNhinEide {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Tài liệu dự án" }

    /// (location) — bấm một lỗi để nhảy tới chỗ ấy trong tài liệu.
    public var onMoMuc: ((String) -> Void)?

    private let tieuDe = NSTextField(labelWithString: "Tài liệu")
    private let cot = NSStackView()

    /// Số dòng đang hiện (lỗi văn phong + mục lỗi thời).
    public private(set) var soMuc = 0
    /// Số mục `doc.sync` báo lỗi thời.
    public private(set) var soMucLoiThoi = 0
    /// Số lỗi `uncited` — số liệu kỹ thuật không trích dẫn.
    public private(set) var soKhongTrichDan = 0

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        tieuDe.font = NSFont.boldSystemFont(ofSize: 12)
        tieuDe.textColor = EideToken.Mau.text
        cot.orientation = .vertical
        cot.alignment = .leading
        cot.spacing = 2

        let coc = NSStackView(views: [tieuDe, cot])
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
            coc.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -s),
        ])
        capNhat(ketQua: [:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Gộp `doc.generate` `{doc_id, path, style_issues}`, `doc.style_check` `{issues[]}` và
    /// `doc.sync` `{stale[], updated[]}` — gọi được với kết quả của bất kỳ cái nào trong ba.
    ///
    /// **`style_issues` và mục lỗi thời hiện ngay cạnh đường dẫn, không giấu trong tab khác.**
    /// Một tài liệu sinh xong với 7 lỗi văn phong mà giao diện chỉ hiện "đã sinh: SRS.md" thì
    /// con số 7 chỉ tồn tại trong store. `doc.sync` cũng vậy: nó đánh dấu mục lỗi thời khi một
    /// fact được trích dẫn đổi đi, và nếu dấu ấy không gặp được người đọc đúng lúc họ sắp tin
    /// thì nó không bảo vệ được ai.
    public func capNhat(ketQua: [String: Any]) {
        for v in cot.arrangedSubviews { cot.removeArrangedSubview(v); v.removeFromSuperview() }
        soMuc = 0
        soMucLoiThoi = 0
        soKhongTrichDan = 0

        let docId = (ketQua["doc_id"] as? String) ?? ""
        let duongDan = (ketQua["path"] as? String) ?? ""
        let loi = (ketQua["issues"] as? [[String: Any]]) ?? []
        // `doc.sync` trả `stale[]` là mảng object (DOC-12), không phải mảng chuỗi.
        let loiThoi = (ketQua["stale"] as? [[String: Any]]) ?? []
        let daSua = (ketQua["updated"] as? [String]) ?? []
        // Sau `doc.generate` mới chỉ có CON SỐ; danh sách chi tiết phải gọi `doc.style_check`.
        let soLoiKhai = EideSo.nguyen(ketQua["style_issues"]) ?? 0

        if ketQua.isEmpty {
            tieuDe.stringValue = "Tài liệu"
            tieuDe.textColor = EideToken.Mau.text
            cot.addArrangedSubview(_nhanMo(
                "Chưa sinh tài liệu nào — gõ `/doc.generate` rồi chọn loại (URD, SRS, SAD…)."))
            return
        }

        soKhongTrichDan = loi.filter { ($0["kind"] as? String) == "uncited" }.count
        soMucLoiThoi = loiThoi.count

        var dau: [String] = []
        if !docId.isEmpty { dau.append(docId) }
        if !loi.isEmpty || soLoiKhai > 0 {
            dau.append("\(max(loi.count, soLoiKhai)) lỗi văn phong")
        }
        if soKhongTrichDan > 0 { dau.append("\(soKhongTrichDan) KHÔNG TRÍCH DẪN") }
        if soMucLoiThoi > 0 { dau.append("\(soMucLoiThoi) LỖI THỜI") }
        if !daSua.isEmpty { dau.append("\(daSua.count) đã cập nhật") }
        tieuDe.stringValue = dau.isEmpty ? "Tài liệu" : dau.joined(separator: " · ")
        tieuDe.textColor = (soKhongTrichDan > 0 || soMucLoiThoi > 0)
            ? EideToken.Mau.warn : EideToken.Mau.text

        if !duongDan.isEmpty {
            cot.addArrangedSubview(_nhanMo(duongDan))
        }

        // Lỗi thời lên TRƯỚC lỗi văn phong: một mục nói sai sự thật tệ hơn một mục viết chưa
        // đúng chuẩn, và danh sách dài thì người chỉ đọc mấy dòng đầu.
        for m in loiThoi {
            let ten = (m["heading"] as? String) ?? (m["section"] as? String)
                ?? (m["id"] as? String) ?? "(không tên)"
            let vi = (m["fact_id"] as? String).map { " — fact \($0) đã đổi" } ?? ""
            cot.addArrangedSubview(_dong(nhan: ten, phu: "⚠︎ lỗi thời\(vi)",
                                         mau: EideToken.Mau.warn, di: ten))
            soMuc += 1
        }

        for e in loi {
            let kind = (e["kind"] as? String) ?? "?"
            let noi = (e["location"] as? String) ?? ""
            let van = (e["text"] as? String) ?? ""
            let nang = kind == "uncited"
            cot.addArrangedSubview(_dong(nhan: noi.isEmpty ? kind : noi,
                                         phu: "\(_tenLoi(kind))\(van.isEmpty ? "" : " — \(van)")",
                                         mau: nang ? EideToken.Mau.bad : EideToken.Mau.muted,
                                         di: noi))
            soMuc += 1
        }

        if soMuc == 0 {
            cot.addArrangedSubview(_nhanMo(
                loi.isEmpty && soLoiKhai == 0
                    ? "Không có lỗi văn phong, không có mục lỗi thời."
                    : "Có \(soLoiKhai) lỗi văn phong — chạy `/doc.style_check` để xem chi tiết."))
        }
    }

    /// Năm `kind` của DOC-08, nói bằng tiếng Việt. Hiện `uncited` trần thì người đọc phải đoán.
    private func _tenLoi(_ k: String) -> String {
        switch k {
        case "uncited": return "số liệu không trích dẫn"
        case "lang": return "lạm dụng tiếng Anh"
        case "term": return "thuật ngữ chưa giải nghĩa"
        case "format": return "sai định dạng chuẩn"
        case "glossary": return "thiếu trong bảng thuật ngữ"
        default: return k
        }
    }

    private func _dong(nhan: String, phu: String, mau: NSColor, di: String) -> NSView {
        let nut = NSButton(title: nhan, target: self, action: #selector(moMuc(_:)))
        nut.bezelStyle = .inline
        nut.font = EideToken.fontUI
        nut.identifier = NSUserInterfaceItemIdentifier(di)

        let p = NSTextField(labelWithString: phu)
        p.font = EideToken.fontUI
        p.textColor = mau

        let hang = NSStackView(views: [nut, p])
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[1]
        return hang
    }

    @objc private func moMuc(_ s: NSButton) {
        if let t = s.identifier?.rawValue, !t.isEmpty { onMoMuc?(t) }
    }

    private func _nhanMo(_ t: String) -> NSTextField {
        let v = NSTextField(labelWithString: t)
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.muted
        return v
    }
}

// MARK: - Định dạng dùng chung

/// Cách hiện tầng tin cậy, tên IRI và giá trị fact — một chỗ, ba khung nhìn.
///
/// Tách ra vì cả ba đều hiện cùng những thứ ấy, và ba bản chép sẽ lệch nhau: một màn gọi
/// `verified` là "đã kiểm", màn kia gọi là "đã đo", và người dùng tưởng đó là hai trạng thái.
public enum EideKnowledgeFormat {

    /// Đuôi của một IRI phân cấp: `chip:st.stm32f411/periph:I2C1` → `I2C1`.
    ///
    /// Hiện cả IRI thì mỗi dòng dài gấp ba và phần khác nhau giữa các dòng bị đẩy ra ngoài mép.
    /// Đuôi là phần người đọc thật sự phân biệt bằng.
    public static func tenNgan(_ s: String) -> String {
        if s.isEmpty { return "" }
        let cuoi = s.split(separator: "/").last.map(String.init) ?? s
        return cuoi.split(separator: ":").last.map(String.init) ?? cuoi
    }

    /// Giá trị fact → chuỗi. `0x40005400` giữ nguyên dạng hex vì người đọc datasheet đọc hex.
    public static func giaTri(_ v: Any?) -> String {
        switch v {
        case let s as String: return s
        case let i as Int: return String(i)
        case let d as Double: return d == d.rounded() ? String(Int(d)) : String(d)
        case let b as Bool: return b ? "true" : "false"
        case let a as [Any]: return "[" + a.map { giaTri($0) }.joined(separator: ", ") + "]"
        case .none: return "—"
        default: return String(describing: v ?? "—")
        }
    }

    /// Nhãn ngắn cho (tầng, trạng thái). **Trạng thái thắng tầng khi nó cảnh báo.**
    ///
    /// Một fact `gold` nhưng `conflict` phải hiện là XUNG ĐỘT, không hiện là "vàng": tầng nói
    /// nguồn đáng tin tới đâu, trạng thái nói fact NÀY đã dùng được chưa. Hiện tầng ở đó là mời
    /// người ta tin một con số đang có hai giá trị mâu thuẫn.
    public static func nhanTang(_ tier: String, _ status: String) -> String {
        switch status {
        case "conflict": return "XUNG ĐỘT"
        case "normalized": return "chưa duyệt"
        case "superseded": return "đã thay"
        case "rejected": return "đã loại"
        default: break
        }
        switch tier {
        case "gold": return "vàng"
        case "silver": return "bạc"
        default: return "đồng"
        }
    }

    public static func mauTang(_ tier: String, _ status: String) -> NSColor {
        switch status {
        case "conflict", "rejected": return EideToken.Mau.bad
        case "normalized", "superseded": return EideToken.Mau.warn
        default: break
        }
        return tier == "gold" ? EideToken.Mau.ok : EideToken.Mau.muted
    }
}


// MARK: - Trạng thái "chưa nạp" của ba màn tri thức

/// Ba lớp trên viết trước `ManHinhCoSo` nên không thừa kế `chuaNap`, nhưng chúng KHÔNG có vấn
/// đề mà `chuaNap` sinh ra để chữa: cả ba có ô nhập của riêng mình, nên câu lúc rỗng vốn đã là
/// một lời mời ("Gõ mã linh kiện rồi Enter", "Gõ câu hỏi rồi Enter") chứ không phải một khẳng
/// định về trạng thái hệ thống. `ProjectStatusView` thì khác: nó mở ra và nói *"Chưa mở dự án
/// nào"* — một câu về hệ thống, phát ra từ một màn chưa hỏi hệ thống câu nào.
///
/// Ba hàm dưới chuyển tiếp thẳng, và chúng tồn tại để panel gọi được `chuaNap` trên mọi khung
/// nhìn mà không phải nhớ cái nào là ngoại lệ.
extension PassportView {
    public func chuaNap(_ viSao: String) { capNhat(ketQua: [:]) }
}

extension RagAskView {
    public func chuaNap(_ viSao: String) { capNhat(ketQua: [:]) }
}

extension DocView {
    public func chuaNap(_ viSao: String) { capNhat(ketQua: [:]) }
}
