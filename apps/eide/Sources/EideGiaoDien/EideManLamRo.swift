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

        let cho = ((try? await doc(goi, "queue.list"))?["items"] as? [[String: Any]]) ?? []
        let luot = ((try? await doc(goi, "chat.history", ["limit": Self.TOI_DA]))?["turns"]
                    as? [[String: Any]]) ?? []
        let hoi = cho.filter { Self.laCauHoiGop($0) }

        guard !hoi.isEmpty || !luot.isEmpty else {
            return rong(vi: "chưa có lượt trao đổi nào trong phiên này",
                        buocKe: "gõ một câu tiếng Việt ở vùng trao đổi phía dưới — tác tử nói "
                              + "lại ý hiểu trước khi làm, và ý hiểu ấy hiện ở đây")
        }

        if !hoi.isEmpty { _khoiCauHoi(hoi) }
        if let y = Self.yHieuGanNhat(luot) { _theYHieu(y) }
        _chuoiBuoc(luot)
        them(cocBao)
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
