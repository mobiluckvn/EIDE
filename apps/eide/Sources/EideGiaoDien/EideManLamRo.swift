import AppKit
import EideLoi

/// **S9 — Làm rõ yêu cầu.** UXC-31 §8 S9; `chat.restate` (CHAT-05), `chat.clarify` (CHAT-04),
/// và đường trả lời `chat.answer`.
///
/// ## Màn này KHÔNG sinh gì khi mở
///
/// `chat.restate` và `chat.clarify` đều gọi mô hình — tức qua mạng và qua tiền. Một màn tự gọi
/// chúng lúc mở là một màn tiêu tiền của người dùng mỗi lần họ bấm vào cột trái. Nên S9 chỉ
/// ĐỌC: ý hiểu mà tác tử đã nói ra (`chat.history`) và câu hỏi đang chờ (`queue.list`).
///
/// ## "Mỗi câu có mặc định an toàn, người bỏ qua được"
///
/// Câu ấy của UXC-31 là ràng buộc nặng nhất ở đây, và nó chống lại một thứ rất dễ làm: bắt
/// người dùng trả lời xong mới cho đi tiếp. D3 của DPS-09 gộp mọi điểm mờ vào MỘT lần hỏi
/// chính vì hỏi lắt nhắt làm người ta bấm bừa — và một câu hỏi không bỏ qua được thì cũng dạy
/// đúng phản xạ ấy.
public final class EideManLamRo: EideManCoSo {

    public override class var tien: String { "LamRo" }

    /// Số lượt trao đổi đọc ngược. Đủ để thấy ý hiểu gần nhất và vài lượt trước nó.
    public static let TOI_DA = 30

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        // ĐIỂM CẦN LÀM RÕ trước, vì đó là KẾT QUẢ của màn này. [DEV-151]
        //
        // Tới 21/09/2026 màn này mở ra chỉ có lịch sử trò chuyện và hàng đợi câu hỏi — tức nó
        // hiện VIỆC ĐANG LÀM chứ không hiện THỨ LÀM RA. Chủ sản phẩm nói thẳng: *"nếu đang làm
        // rõ yêu cầu thì yêu cầu cần làm rõ nó phải hiển thị ở tab Làm rõ yêu cầu"*.
        //
        // Nguyên nhân sâu hơn giao diện: `req.elicit.gaps` và `req.detect_conflict.issues` —
        // đúng danh sách ấy — được tính rồi vứt đi, không bảng nào giữ. Migration 0008 cho
        // chúng một chỗ; chỗ này đọc ra.
        let lamRo = ((try? await nangLucNeuCo(goi, "view.artifacts",
                                              ["kind": "clarification", "limit": 200]))?["items"]
                     as? [[String: Any]]) ?? []
        let cho = ((try? await doc(goi, "queue.list"))?["items"] as? [[String: Any]]) ?? []
        let luot = ((try? await doc(goi, "chat.history", ["limit": Self.TOI_DA]))?["turns"]
                    as? [[String: Any]]) ?? []
        let hoi = cho.filter { Self.laCauHoiGop($0) }

        guard !lamRo.isEmpty || !hoi.isEmpty || !luot.isEmpty else {
            return rong(vi: "chưa có điểm nào cần làm rõ",
                        buocKe: "mô tả việc cần làm ở vùng trao đổi — `req.elicit` tìm điểm mờ "
                              + "và `req.detect_conflict` tìm chỗ mâu thuẫn, cả hai hiện ở đây")
        }

        if !lamRo.isEmpty { _khoiLamRo(lamRo); _khoiTraLoi(lamRo) }
        if !hoi.isEmpty { _khoiCauHoi(hoi) }
        if let y = Self.yHieuGanNhat(luot) { _theYHieu(y) }
        _chuoiBuoc(luot)
        them(cocBao)
    }

    // MARK: - điểm cần làm rõ (kết quả của màn này)

    /// Nhãn tiếng người cho `clarification.kind`.
    ///
    /// Bốn giá trị này do `req.detect_conflict` sinh (`conflict|ambiguous|unmeasurable`) và
    /// `req.elicit` (`gap`) — chúng là từ vựng của hợp đồng, không phải chữ để hiện cho người
    /// đọc. Bảng ở đây dịch chúng, và CHỈ chúng: gặp giá trị lạ thì hiện nguyên, vì bịa một
    /// nhãn cho thứ mình không biết là nói hộ tác tử một điều nó không nói.
    public static func nhanLoai(_ k: String) -> String {
        switch k {
        case "gap":          return "THIẾU THÔNG TIN"
        case "conflict":     return "MÂU THUẪN"
        case "ambiguous":    return "CÒN MƠ HỒ"
        case "unmeasurable": return "CHƯA ĐO ĐƯỢC"
        default:             return k.uppercased()
        }
    }

    /// Gọi sau khi người lưu một câu trả lời — để phiên làm mới thanh trên và cột phải.
    public var onDaTraLoi: (() async -> Void)?

    /// Ô trả lời đang mở — `clar_id` của điểm người vừa bấm.
    private var dangTraLoi = ""
    private var noiNut: EideNutTheoO?
    private let oTraLoi = NSTextField()

    private func _khoiTraLoi(_ ds: [[String: Any]]) {
        // Ô NHẬP ngay dưới bảng, không phải hộp thoại: người đọc bảng rồi trả lời tại chỗ, và
        // một hộp thoại che mất chính cái bảng họ đang đối chiếu.
        let mo = ds.filter { (($0["status"] as? String) ?? "open") == "open" }
        guard !mo.isEmpty else { return }

        let chon = NSPopUpButton()
        chon.addItem(withTitle: "— chọn điểm cần trả lời —")
        for d in mo {
            let ma = (d["id"] as? String) ?? "?"
            chon.addItem(withTitle: "\(ma) · \(((d["text"] as? String) ?? "").prefix(56))")
            chon.lastItem?.representedObject = ma
        }
        chon.target = self
        chon.action = #selector(_chonDiem(_:))

        oTraLoi.placeholderString = "Câu trả lời của anh — gõ rồi bấm Lưu"
        oTraLoi.font = EideToken.fontUI
        oTraLoi.target = self
        oTraLoi.action = #selector(_luuTraLoi)
        oTraLoi.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true

        let luu = NSButton(title: "Lưu câu trả lời", target: self, action: #selector(_luuTraLoi))
        luu.bezelStyle = .rounded
        luu.keyEquivalent = "\r"
        noiNut = EideNutTheoO.noi(oTraLoi, luu)

        let hang = NSStackView(views: [chon, oTraLoi, luu])
        hang.orientation = .horizontal
        hang.spacing = 8
        them(hang)
        let ghi = NSTextField(wrappingLabelWithString:
            "Câu trả lời ghi tác giả `human:<tên>` và HOÀN TÁC ĐƯỢC từng lần — mỗi lần lưu là "
            + "một bản mới, không ghi đè bản trước.")
        ghi.font = EideToken.fontUI
        ghi.textColor = EideToken.Mau.muted
        them(ghi)
        dangTraLoi = (mo.first?["id"] as? String) ?? ""
        maDiemDauTien = mo.first?["id"] as? String
    }

    @objc private func _chonDiem(_ n: NSPopUpButton) {
        dangTraLoi = (n.selectedItem?.representedObject as? String) ?? ""
    }

    /// Mã điểm cần làm rõ ĐANG MỞ đầu tiên trong bảng — cho bài kiểm.
    ///
    /// Mã băm theo NỘI DUNG (xem `ghi_clarification`), nên một kịch bản viết sẵn không thể
    /// biết trước nó. Lấy từ chính bảng đang hiện là cách một người dùng cũng làm: họ đọc dòng
    /// trên cùng rồi trả lời nó.
    public private(set) var maDiemDauTien: String?

    /// Gõ câu trả lời rồi bấm Lưu — ĐÚNG đường người dùng đi.
    ///
    /// Công khai vì bài kiểm phải thao tác đúng cái nút người bấm, không gọi tắt xuống năng
    /// lực. Cùng khuôn với `EideDock.guiDeTest`: một bài kiểm gọi thẳng `req.answer_clarification`
    /// sẽ xanh kể cả khi nút Lưu không nối vào đâu cả.
    public func traLoiDeTest(_ clarId: String, _ van: String) async {
        dangTraLoi = clarId
        oTraLoi.stringValue = van
        noiNut?.capNhat()
        _luuTraLoi()
        // `_luuTraLoi` chạy trong một Task riêng; chờ nó xong rồi mới trả về, nếu không bài
        // kiểm chụp ảnh trước khi bảng kịp vẽ lại.
        for _ in 0..<60 where !oTraLoi.stringValue.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    @objc private func _luuTraLoi() {
        let van = oTraLoi.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dangTraLoi.isEmpty, !van.isEmpty, let goi = goiLoi else { return }
        let ma = dangTraLoi
        Task { @MainActor in
            _ = try? await goi("caps.invoke",
                               ["id": "req.answer_clarification",
                                "params": ["clar_id": ma, "answer": van]])
            oTraLoi.stringValue = ""
            noiNut?.capNhat()
            // Vẽ lại màn từ store: KHÔNG tự sửa bảng trên màn hình. Cập nhật tại chỗ nghĩa là
            // tin rằng lời gọi đã thành công — mà nó có thể bị cổng chặn, và khi ấy bảng nói
            // một đằng còn store một nẻo.
            xoa()
            try? await napDuLieu(goi)
            // LÀM MỚI cả thanh trên và cột phải. Trả lời xong là một việc rời khỏi danh sách
            // chờ, nhưng badge "Chờ tôi" chỉ được tính trong `_lamMoi`. Đo 22/09/2026 bằng ảnh
            // chụp: bảng ghi "3 chưa trả lời" còn thanh trên vẫn ghi "Chờ tôi 5" — hai con số
            // về cùng một thứ, cạnh nhau, khác nhau.
            await onDaTraLoi?()
        }
    }

    private func _khoiLamRo(_ ds: [[String: Any]]) {
        let mo = ds.filter { (($0["status"] as? String) ?? "open") == "open" }
        tieuDePhu("\(ds.count) ĐIỂM CẦN LÀM RÕ"
                  + (mo.count < ds.count ? " — \(mo.count) chưa trả lời" : ""))
        // Cột nói ĐÚNG thứ nó chứa. [DEV-191] "NỘI DUNG" là một nhãn đúng với mọi bảng trên
        // đời; ở đây ô ấy chứa CÂU HỎI của tác tử, và "VÌ BƯỚC NÀO" là thứ §8 S9 đòi nói ra —
        // một câu hỏi không gắn với bước sinh ra nó thì người trả lời không biết nó phục vụ gì.
        bang(cot: [("LOẠI", 140), ("YÊU CẦU", 130), ("TRẠNG THÁI", 110),
                   ("VÌ BƯỚC NÀO", 150), ("CÂU HỎI", 0)],
             dong: ds.map { d in
                 let req = (d["req_ids"] as? [Any])?.map { "\($0)" }.joined(separator: ", ")
                 let tl = (d["answer"] as? String).map { "đã trả lời: \($0)" }
                 return [Self.nhanLoai((d["kind"] as? String) ?? "?"),
                         (req?.isEmpty == false ? req! : "—"),
                         (((d["status"] as? String) ?? "open") == "open" ? "CHỜ ANH" : "xong"),
                         // `source_cap` là năng lực đã dừng lại để hỏi — đúng "vì bước nào".
                         (d["source_cap"] as? String).map { "`\($0)`" } ?? "—",
                         ((d["text"] as? String) ?? "")
                             + ((d["suggestion"] as? String).map { "\n   ↳ tác tử đề xuất: \($0)" } ?? "")
                             + (tl.map { "\n   ↳ \($0)" } ?? "")]
             })
    }

    // MARK: - câu hỏi gộp

    /// Một mục chờ có phải CÂU HỎI GỘP không.
    ///
    /// Hàng đợi trộn hai thứ: câu hỏi của `chat.clarify` và mục ASK của một năng lực bất kỳ bị
    /// cổng chặn. Cả hai đều trả lời bằng `gate.decide`, nhưng chỉ loại đầu thuộc màn này —
    /// loại sau thuộc cột phải. Không tách thì S9 hiện lại nguyên cột phải dưới một cái tên khác.
    public static func laCauHoiGop(_ m: [String: Any]) -> Bool {
        let cap = (m["cap"] as? String) ?? ""
        return cap.hasPrefix("chat.") || m["question"] != nil
    }

    private func _khoiCauHoi(_ ds: [[String: Any]]) {
        tieuDePhu("\(ds.count) CÂU HỎI ĐANG CHỜ ANH")
        for m in ds { them(_theHoi(m)) }
    }

    /// Thẻ một câu hỏi — kèm **mặc định an toàn** và đường **bỏ qua**.
    private func _theHoi(_ m: [String: Any]) -> NSView {
        let ma = (m["run_id"] as? String) ?? ""
        let qd = (m["decision"] as? [String: Any]) ?? [:]
        let van = NSTextField(wrappingLabelWithString:
            Self.cauHoi(m) + "\n" + EideManXungDot.vinao(qd))
        van.font = EideToken.fontUI
        van.textColor = EideToken.Mau.text

        var nut: [NSView] = []
        for (nhan, khoa) in [("Đồng ý", "approve"), ("Không", "reject")] {
            let b = NSButton(title: nhan, target: self, action: #selector(_traLoi(_:)))
            b.bezelStyle = .rounded
            b.identifier = NSUserInterfaceItemIdentifier("\(khoa)|\(ma)")
            nut.append(b)
        }
        // "Người bỏ qua được" — UXC-31 §8 S9. Bỏ qua KHÔNG phải từ chối: nó để câu hỏi nguyên
        // chỗ trong hàng đợi và dùng mặc định an toàn cho lượt này. Gộp hai thứ vào nút "Không"
        // sẽ khiến một lần bỏ qua thành một lần từ chối vĩnh viễn.
        let bo = NSButton(title: "Bỏ qua — dùng mặc định an toàn",
                          target: self, action: #selector(_boQua(_:)))
        bo.bezelStyle = .inline
        bo.identifier = NSUserInterfaceItemIdentifier(ma)
        nut.append(bo)

        let hang = NSStackView(views: nut)
        hang.orientation = .horizontal
        hang.spacing = 8

        let coc = NSStackView(views: [van, hang])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 6
        coc.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        let khung = NSView()
        khung.wantsLayer = true
        khung.layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
        khung.layer?.cornerRadius = EideToken.radius[0]
        coc.translatesAutoresizingMaskIntoConstraints = false
        khung.addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: khung.topAnchor),
            coc.leadingAnchor.constraint(equalTo: khung.leadingAnchor),
            coc.trailingAnchor.constraint(lessThanOrEqualTo: khung.trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: khung.bottomAnchor),
        ])
        return khung
    }

    /// Câu hỏi hiện ra cho người đọc.
    public static func cauHoi(_ m: [String: Any]) -> String {
        if let q = m["question"] as? String, !q.isEmpty { return q }
        if let q = (m["question"] as? [String: Any])?["text"] as? String, !q.isEmpty { return q }
        let cap = (m["cap"] as? String) ?? "?"
        return "`\(cap)` cần anh quyết trước khi chạy tiếp."
    }

    @objc private func _traLoi(_ n: NSButton) {
        guard let goi = goiLoi, let v = n.identifier?.rawValue else { return }
        let phan = v.split(separator: "|", maxSplits: 1).map(String.init)
        guard phan.count == 2 else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                _ = try await goi("chat.answer", ["question_id": phan[1], "option": phan[0]])
                _bao(phan[0] == "approve" ? "Đã đồng ý — tác tử chạy tiếp."
                                          : "Đã từ chối — tác tử dừng ở bước ấy.",
                     mau: phan[0] == "approve" ? EideToken.Mau.ok : EideToken.Mau.warn)
                await nap(goi)
            } catch {
                _bao("Không gửi được câu trả lời: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// Bỏ qua — câu hỏi Ở NGUYÊN trong hàng đợi.
    ///
    /// Không gọi `chat.answer`: gọi nó là quyết, và quyết thay người dùng đúng lúc họ vừa nói
    /// "tôi chưa muốn quyết" là cách chắc nhất để họ thôi đọc các câu hỏi sau.
    @objc private func _boQua(_ n: NSButton) {
        _xoaBao()
        _bao("Đã bỏ qua. Câu hỏi vẫn nằm nguyên trong CHỜ TÔI ở cột phải; tác tử dùng mặc định "
             + "an toàn cho lượt này và sẽ hỏi lại khi việc ấy tới lượt.",
             mau: EideToken.Mau.muted)
    }

    // MARK: - ý hiểu và chuỗi bước

    /// Ý hiểu gần nhất — `chat.restate` ghi vào lượt với vai `restate`.
    public static func yHieuGanNhat(_ luot: [[String: Any]]) -> String? {
        for t in luot.reversed() {
            let vai = ((t["role"] as? String) ?? (t["kind"] as? String) ?? "").lowercased()
            guard vai.contains("restate") || vai.contains("y_hieu") else { continue }
            if let v = (t["text"] as? String) ?? (t["content"] as? String), !v.isEmpty { return v }
        }
        return nil
    }

    private func _theYHieu(_ s: String) {
        tieuDePhu("Ý HIỂU CỦA TÁC TỬ — `chat.restate`")
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.text
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.infoBg
        them(n)
    }

    /// Chuỗi bước dự kiến, đọc từ chính các lượt đã ghi.
    private func _chuoiBuoc(_ luot: [[String: Any]]) {
        guard !luot.isEmpty else { return }
        tieuDePhu("\(luot.count) LƯỢT TRAO ĐỔI GẦN ĐÂY")
        bang(cot: [("LÚC", 124), ("AI", 64), ("NỘI DUNG", 0)],
             dong: luot.reversed().map { t in
                 [EideManNhatKy.gio((t["at"] as? String) ?? (t["ts"] as? String)),
                  EideManNhatKy.ai((t["role"] as? String) ?? (t["by"] as? String)),
                  EideManHoChieu.giaTri((t["text"] as? Any) ?? t["content"])]
             })
    }

    // MARK: - phụ

    private func _bao(_ s: String, mau: NSColor) {
        if cocBao.superview == nil { them(cocBao) }
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        cocBao.addArrangedSubview(n)
    }

    private func _xoaBao() {
        for v in cocBao.arrangedSubviews { cocBao.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    /// Cho test bấm mà không cần chuột.
    public func boQuaDeTest() { _boQua(NSButton()) }
}
