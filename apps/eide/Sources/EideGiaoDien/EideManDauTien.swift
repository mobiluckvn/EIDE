import AppKit
import EideLoi

/// **S2 — Nhật ký hoạt động.** UXC-31 §8 S2; năng lực `view.timeline` (VIEW-12).
///
/// Dòng thời gian là thứ trả lời câu hỏi *"máy vừa làm gì?"*, nên nó phải nói được AI làm: cột
/// `Ai` phân biệt người với tác tử. Bản cũ hiện `by` nguyên dạng (`agent`, `human`, `human:congvt`)
/// và ba giá trị ấy đọc như ba loại chủ thể khác nhau trong khi chỉ có hai.
public final class EideManNhatKy: EideManCoSo {

    public override class var tien: String { "NhatKy" }

    /// Số dòng hiện tối đa. Sổ cái của một dự án làm một tuần đã vài nghìn bản ghi, và một màn
    /// dựng vài nghìn hàng stack thì mất vài giây để mở — người sẽ tưởng ứng dụng treo.
    public static let TOI_DA = 120

    /// Bộ lọc đang bật — §8 S2 đòi bốn lối xem, không phải một danh sách trộn.
    ///
    /// Sổ cái trộn mọi thứ theo thời gian, và đó đúng là hình dạng nó cần có. Nhưng bốn câu hỏi
    /// người mang tới màn này thì khác nhau: *"tôi đã làm gì"*, *"nó tự làm gì"*, *"hỏng ở đâu"*,
    /// *"cổng quyết gì"*. Bắt họ đọc 120 dòng để trả lời một trong bốn là bắt họ làm việc của
    /// bộ lọc.
    public enum Loc: String, CaseIterable {
        case tatCa = "Tất cả"
        case cuaToi = "Chỉ việc của tôi"
        case tacTu = "Chỉ việc tác tử tự làm"
        case loi = "Chỉ lỗi"
        case cong = "Chỉ cổng"
    }

    public private(set) var loc: Loc = .tatCa
    private var goiLoi: EideGoi?

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        // Cắt ở LÕI, không ở đây. Kéo về cả sổ cái rồi bỏ đi 98% là 2,6 giây chờ cho 120 dòng
        // — đo trên dự án có 9 128 sự kiện (DEV-132).
        let r = try await doc(goi, "view.timeline", ["limit": Self.TOI_DA])
        let ds = (r["events"] as? [[String: Any]]) ?? []
        let tong = (r["total"] as? Int) ?? ds.count
        guard !ds.isEmpty else {
            return rong(vi: "sổ cái của dự án này chưa có bản ghi nào",
                        buocKe: "ra lệnh cho tác tử — mọi việc nó làm đều để lại một dòng ở đây")
        }
        _hangLoc()
        // MỚI NHẤT LÊN TRƯỚC. `view.timeline` sắp tăng dần để ghép bốn nguồn, nhưng câu hỏi của
        // người mở màn này luôn là "vừa xảy ra chuyện gì", không phải "hôm khai sinh có gì".
        let moi = ds.reversed().filter { Self.hop($0, loc) }
        tieuDePhu("\(tong) BẢN GHI"
                  + (loc == .tatCa ? (tong > ds.count ? " — hiện \(ds.count) mới nhất" : "")
                                   : " — lọc “\(loc.rawValue)”: \(moi.count) dòng"))
        guard !moi.isEmpty else {
            // Lọc ra rỗng KHÁC sổ cái rỗng, và nói nhầm hai thứ ấy làm người dùng tưởng dự án
            // chưa chạy gì. Nói rõ là bộ lọc đang che, và che theo tiêu chí nào.
            return them(_chuNK("Không bản ghi nào khớp “\(loc.rawValue)” trong \(ds.count) dòng "
                               + "mới nhất. Bấm “Tất cả” để bỏ lọc."))
        }
        bang(cot: [("LÚC", 116), ("AI", 50), ("LOẠI", 118), ("NĂNG LỰC", 150),
                   ("KẾT QUẢ", 74), ("CHI PHÍ", 76), ("CHI TIẾT", 0)],
             dong: moi.map { e in
                 let d = (e["data"] as? [String: Any]) ?? [:]
                 return [Self.gio(e["at"] as? String), Self.ai(e["by"] as? String),
                         e["kind"] as? String ?? "?",
                         Self.nangLucCua(d), Self.ketQua(d), Self.chiPhi(d),
                         Self.chiTiet(d)]
             })
    }

    /// Hàng nút lọc. Nút chứ không menu thả xuống: năm lối xem, và lối đang bật phải NHÌN THẤY
    /// được mà không cần mở gì ra — một bộ lọc đang bật mà trông như đang tắt là cách nhanh nhất
    /// khiến người dùng kết luận sai về dữ liệu.
    private func _hangLoc() {
        let hang = NSStackView(views: Loc.allCases.map { l in
            let b = NSButton(title: l.rawValue, target: self, action: #selector(_doiLoc(_:)))
            b.bezelStyle = l == loc ? .rounded : .inline
            b.font = l == loc ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI
            b.identifier = NSUserInterfaceItemIdentifier(l.rawValue)
            // Bộ lọc ĐANG BẬT thì nút của nó TẮT. Bấm lại nó không đổi gì — và một nút trông
            // bấm được mà bấm xong không đổi gì dạy người dùng rằng nút ở màn này không đáng
            // tin. Bộ dò `--bam-thu` bắt đúng chuyện ấy 22/09/2026.
            b.isEnabled = l != loc
            return b
        })
        hang.orientation = .horizontal
        hang.spacing = 6
        let nhan = NSTextField(labelWithString: "Lọc:")
        nhan.font = NSFont.boldSystemFont(ofSize: 10.5)
        nhan.textColor = EideToken.Mau.faint
        let coc = NSStackView(views: [nhan, hang])
        coc.orientation = .horizontal
        coc.spacing = 8
        them(coc)
    }

    @objc private func _doiLoc(_ n: NSButton) {
        guard let ten = n.identifier?.rawValue,
              let l = Loc.allCases.first(where: { $0.rawValue == ten }), l != loc,
              let goi = goiLoi else { return }
        loc = l
        // Vẽ lại TỪ LÕI chứ không lọc bảng đang hiện: bảng đang hiện đã bị chính bộ lọc trước
        // cắt mất dòng, nên lọc chồng lên nó thì "Tất cả" không bao giờ về được đủ.
        xoa()
        Task { @MainActor in try? await napDuLieu(goi) }
    }

    /// Bản ghi này có thuộc lối xem đang chọn không?
    ///
    /// Đọc `by` và `kind` — hai trường mọi bản ghi sổ cái đều có. Không đọc chữ trong mô tả:
    /// mô tả do bốn nguồn khác nhau viết, và một bộ lọc bám vào câu chữ sẽ im lặng bỏ sót đúng
    /// lúc nguồn thứ năm xuất hiện.
    static func hop(_ e: [String: Any], _ l: Loc) -> Bool {
        let kind = (e["kind"] as? String) ?? ""
        let by = (e["by"] as? String) ?? ""
        let d = (e["data"] as? [String: Any]) ?? [:]
        switch l {
        case .tatCa: return true
        case .cuaToi: return by.hasPrefix("human")
        case .tacTu: return by == "agent"
        case .loi:
            // "Lỗi" gồm cả lời gọi hỏng lẫn bản ghi mang mã lỗi — hai cách một việc hỏng để lại
            // dấu, và bỏ một trong hai là bỏ đúng nửa số lỗi.
            if (d["status"] as? String) == "failed" { return true }
            if d["eide_code"] != nil || d["error"] != nil { return true }
            return kind.contains("error") || kind.contains("failed")
        case .cong:
            return kind.hasPrefix("gate.") || d["gate"] != nil || d["decision"] != nil
        }
    }

    /// Tên năng lực của một bản ghi — `cap`, hoặc `id` với các bản ghi của lời gọi lẻ.
    static func nangLucCua(_ d: [String: Any]) -> String {
        for k in ["cap", "action_cap", "cap_id", "id"] {
            if let v = d[k] as? String, !v.isEmpty { return v }
        }
        return "—"
    }

    /// Kết quả: `done`/`failed`/`pending` của một lời gọi, hoặc quyết định của một cổng.
    ///
    /// KHÔNG bịa "done" cho bản ghi không nói gì: phần lớn 26 loại bản ghi không phải là một
    /// lời gọi có kết quả, và điền đại một chữ vào cột này biến chúng thành những việc đã xong
    /// mà chưa từng chạy.
    static func ketQua(_ d: [String: Any]) -> String {
        if let s = d["status"] as? String, !s.isEmpty { return s }
        if let q = d["decision"] as? String, !q.isEmpty { return q }
        return "—"
    }

    static func chiPhi(_ d: [String: Any]) -> String {
        guard let c = d["cost_usd"] as? Double, c > 0 else { return "—" }
        return String(format: "%.4f USD", c)
    }

    private func _chuNK(_ s: String) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.muted
        return n
    }

    /// **§7.3 diff render.** Một sự kiện mới = MỘT hàng chèn lên đầu, không nạp lại màn.
    ///
    /// Đây là màn đo ra con số tệ nhất của cách lùi: nạp lại ở mỗi sự kiện làm nó mất 7,68 s
    /// (DEV-132), và ngay cả bản gộp 0,4 s vẫn tốn một lời gọi `view.timeline` 0,47 s cộng một
    /// lượt dựng `NSTextField` ~200 ms cho mỗi lần. Ở đây: dựng lại chuỗi (~6 ms trên 120 hàng)
    /// rồi gán vào chính khung nhìn đang có.
    ///
    /// Dữ liệu lấy từ CHÍNH sự kiện, không hỏi lại lõi — `event.*` mang đủ `at`/`kind`/`data`,
    /// và hỏi lại là quay về đúng chi phí vừa tránh được.
    ///
    /// Trả `false` khi màn chưa dựng bảng (đang ở trạng thái rỗng): hàng đầu tiên phải đi qua
    /// `napDuLieu` để bảng và tiêu đề ra đời cùng nhau.
    public override func apDung(_ ten: String, _ p: [String: Any]) -> Bool {
        guard ten.hasPrefix("event."), let luc = p["at"] as? String else { return false }
        let kind = (p["kind"] as? String) ?? String(ten.dropFirst(6))
        let d = (p["data"] as? [String: Any]) ?? p
        // BỘ LỌC ÁP CẢ CHO HÀNG MỚI. Không áp thì một sự kiện tới trong lúc đang lọc "Chỉ lỗi"
        // sẽ chen vào bảng dù nó không phải lỗi — và người dùng đọc một bảng có nhãn "Chỉ lỗi"
        // chứa một dòng không lỗi sẽ tin vào nhãn, không tin vào dòng.
        guard Self.hop(["kind": kind, "by": p["by"] as Any, "data": d], loc) else { return true }
        // Số cột phải KHỚP bảng đang hiện. Bảng đổi từ 4 sang 7 cột ở [DEV-185]; một hàng 4 ô
        // chèn vào bảng 7 cột không đỏ ở đâu cả, nó chỉ lệch — và lệch từ dòng mới nhất trở đi,
        // tức là đúng dòng người đang nhìn.
        return themHangDau([Self.gio(luc),
                            Self.ai(p["by"] as? String),
                            kind,
                            Self.nangLucCua(d), Self.ketQua(d), Self.chiPhi(d),
                            Self.chiTiet(d)],
                           toiDa: Self.TOI_DA)
    }

    /// `2026-09-18T16:04:21.123456+00:00` → `18/09 16:04:21`. Ngày ĐẦY ĐỦ chỉ tốn 6 ký tự và
    /// nó là khác biệt giữa "vừa xong" với "tuần trước" — thứ một dòng thời gian tồn tại để nói.
    public static func gio(_ s: String?) -> String {
        guard let s, s.count >= 19 else { return "—" }
        let d = s.prefix(10).suffix(5)               // MM-DD
        return "\(d.suffix(2))/\(d.prefix(2)) \(s.dropFirst(11).prefix(8))"
    }

    /// `human`, `human:congvt`, `agent`, `nil` → hai chủ thể, không phải bốn.
    public static func ai(_ s: String?) -> String {
        let v = s ?? ""
        return v.hasPrefix("human") ? "người" : (v.isEmpty ? "máy" : "máy")
    }

    /// Một dòng dữ liệu thô đọc được. Ưu tiên các khoá người cần; phần còn lại KHÔNG bị giấu
    /// hẳn — nó rút thành số khoá, để người biết là còn thứ mình chưa nhìn thấy.
    public static func chiTiet(_ d: [String: Any]) -> String {
        let uuTien = ["cap", "status", "decision", "gate", "level", "text", "path", "file", "reason"]
        var phan: [String] = []
        for k in uuTien where d[k] != nil {
            phan.append("\(k)=\(gonGang(d[k]!))")
        }
        let con = d.keys.filter { !uuTien.contains($0) && !$0.hasPrefix("_") }
        if !con.isEmpty { phan.append("(+\(con.count) trường)") }
        return phan.isEmpty ? "—" : phan.joined(separator: " · ")
    }

    /// Một giá trị JSON bất kỳ → MỘT dòng đọc được.
    ///
    /// Nội suy thẳng `"\(giá trị)"` cho một từ điển lồng sẽ in ra dạng mô tả nhiều dòng của
    /// Objective-C, và nó ESCAPE tiếng Việt thành `\U1edbp`. Đo 18/09 trên màn Nhật ký: mỗi
    /// bản ghi `cap.run.start` chiếm sáu dòng, trong đó dòng lý do đọc là
    /// `"L\U1edbp R0 ch\U1ec9 \U0111\U1ecdc"` — chữ vẫn còn đủ, chỉ là không ai đọc được.
    public static func gonGang(_ v: Any) -> String {
        switch v {
        case let s as String:
            return s.count > 72 ? String(s.prefix(72)) + "…" : s
        case let b as Bool:
            return b ? "true" : "false"
        case let n as NSNumber:
            return n.stringValue
        case let a as [Any]:
            return "[\(a.count) mục]"
        case let o as [String: Any]:
            // Một tầng lồng thì MỞ RA — `decision` của mọi bản ghi cổng nằm ở đây, và nó là
            // thứ người mở màn Nhật ký muốn đọc nhất.
            let vo = ["decision", "rule", "gate", "status", "id", "name"]
            let lay = vo.filter { o[$0] != nil }.prefix(2)
                        .map { "\($0)=\(gonGang(o[$0]!))" }
            return lay.isEmpty ? "{\(o.count) khoá}" : "{" + lay.joined(separator: " ") + "}"
        default:
            return "\(v)"
        }
    }
}

/// **S25 — Chính sách tự chủ.** UXC-31 §8 S25; năng lực `policy.rules` (POLICY-08).
///
/// Bảng CHỈ ĐỌC. Sửa chính sách đi bằng `eide policy set`/`sign` ở dòng lệnh, có chủ đích: một
/// cái nút "nới quyền" nằm ngay trong tầm tay tác tử là thứ POL-17 tồn tại để ngăn.
public final class EideManChinhSach: EideManCoSo {

    public override class var tien: String { "ChinhSach" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        let kq = try await nangLuc(goi, "policy.rules")
        let ds = (kq["rules"] as? [[String: Any]]) ?? []

        // ---- TRẠNG THÁI NIÊM PHONG, nói cả khi ĐÃ ký. [DEV-185]
        //
        // Bản trước chỉ nói khi CHƯA ký. Nhưng "niêm có khớp không" là một trong ba thứ §8 S25
        // liệt kê, và người mở màn chính sách ra để kiểm tra an toàn thì câu họ cần nghe là một
        // câu KHẲNG ĐỊNH — "niêm đang khớp" — chứ không phải sự vắng mặt của một cảnh báo.
        // Không có gì phân biệt "đã ký" với "màn quên kiểm" nếu cả hai đều im.
        //
        // Niêm CHƯA ký thì nói TRƯỚC bảng: lúc ấy ba danh sách trắng bị bỏ khỏi biểu thức, nên
        // bảng dưới đây đúng, mà hành vi thật KHÁC nó.
        let daKy = (kq["signed"] as? Bool) ?? false
        let lyDo = (kq["reason"] as? String) ?? ""
        let n = NSTextField(wrappingLabelWithString: daKy
            ? "Niêm phong chính sách: ĐANG KHỚP — ba danh sách trắng (`trusted_sources`, "
              + "`trusted_packages`, `allowed_licenses`) có hiệu lực, bảng dưới đây đúng với "
              + "hành vi thật của PolicyGate."
            : "Niêm phong chính sách: CHƯA KÝ — PolicyGate bỏ `trusted_sources`, "
              + "`trusted_packages` và `allowed_licenses` khỏi biểu thức, nên các quy tắc dựa "
              + "vào chúng không khớp và lời gọi rơi xuống quy tắc bắt hết."
              + (lyDo.isEmpty ? "" : " Lý do: \(lyDo).")
              + " Ký lại bằng `eide policy sign --by <tên>`.")
        n.font = EideToken.fontUI
        n.textColor = daKy ? EideToken.Mau.ok : EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = daKy ? EideToken.Mau.okBg : EideToken.Mau.warnBg
        them(n)

        guard !ds.isEmpty else {
            return rong(vi: "PolicyGate không nạp được quy tắc nào",
                        buocKe: "kiểm `docs/spec/policy/rules.yaml` rồi mở lại dự án")
        }
        tieuDePhu("\(ds.count) QUY TẮC ĐANG CÓ HIỆU LỰC")
        bang(cot: [("MÃ", 92), ("CỔNG", 74), ("QUYẾT", 74), ("ĐIỀU KIỆN", 0)],
             dong: ds.map { q in
                 [q["id"] as? String ?? "?", q["gate"] as? String ?? "—",
                  q["decision"] as? String ?? "—",
                  (q["when"] as? String) ?? (q["reason"] as? String) ?? "—"]
             })
    }
}

/// **S1 — Tổng quan.** UXC-31 §8 S1; `session.state`, `budget.state`, `project.status`,
/// `queue.list`, `view.timeline`, `passport.browse`.
///
/// ## Màn này trả lời bốn câu, không phải in bốn bảng
///
/// Người mở S1 ra không hỏi "phiên làm việc có mã gì". Họ hỏi *"dự án tôi đang ở đâu"*, và câu
/// ấy tách thành đúng bốn câu con — UXC-31 §8 S1 liệt kê đúng bốn:
///
/// 1. **Tính năng**: bao nhiêu đã chạy được, cái nào đang dở.
/// 2. **Đang chờ tôi**: còn mấy việc treo, và bấm được sang chỗ xử lý.
/// 3. **Phần cứng**: chip/board nào đã ghim, ISA gì, hộ chiếu có chưa.
/// 4. **Tác tử vừa làm gì**: ba việc gần nhất, kèm giờ.
///
/// Tới 22/09/2026 màn hiện phiên làm việc và ngân sách — hai thứ đúng và không nằm trong bốn
/// câu trên. Đo bằng [DEV-183] trên một dự án có 290 fact: 4/6 mục của S1 không hiện.
///
/// ## Mỗi khối đứng riêng: hỏng một khối không được làm trắng cả màn
///
/// Năm nguồn dữ liệu, và bốn trong năm đi qua `nangLucNeuCo`/`try?`. Màn tổng quan là màn mở
/// đầu tiên của mọi phiên; để một lời gọi hỏng kéo cả màn xuống là biến một lỗi nhỏ thành
/// "sản phẩm không chạy". Khối nào không đọc được thì NÓI RA khối ấy hỏng, không im.
public final class EideManTongQuan: EideManCoSo {

    public override class var tien: String { "Main" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        try await _khoiTinhNang(goi)
        try await _khoiChoToi(goi)
        try await _khoiPhanCung(goi)
        try await _khoiVuaXong(goi)

        let p = try await doc(goi, "session.state")
        var dong: [[String]] = []
        // `thieu` là danh sách trường lõi CHƯA lưu (DEV-110). Hiện nó ra thành dòng, không nuốt:
        // một ô trống không nói được nó trống vì chưa có dữ liệu hay vì màn quên đọc.
        let thieu = (p["thieu"] as? [String]) ?? []
        dong.append(["Phiên", (p["session_id"] as? String) ?? "chưa mở phiên nào"])
        dong.append(["Mở lúc", EideManNhatKy.gio(p["opened_at"] as? String)])
        dong.append(["Tự chủ hiệu lực", (p["autonomy_effective"] as? String) ?? "—"])
        dong.append(["Dừng khẩn", ((p["stopped"] as? Bool) ?? false) ? "ĐANG BẬT" : "tắt"])
        dong.append(["Lượt trao đổi", "\(p["turns"] as? Int ?? 0)"])
        dong.append(["Mục hoàn tác", "\(p["undo_items"] as? Int ?? 0)"])
        if !thieu.isEmpty {
            dong.append(["Chưa có dữ liệu", thieu.joined(separator: ", ") + " (DEV-110)"])
        }
        tieuDePhu("PHIÊN LÀM VIỆC")
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)

        if let b = try? await doc(goi, "budget.state") {
            tieuDePhu("NGÂN SÁCH MÔ HÌNH")
            // Tên khoá chép ĐÚNG từ `daemon/rpc.py::budget_state`. Bản đầu đoán ba tên khác
            // (`spent_today`, `daily_limit`, `calls`) và cả ba đều không tồn tại, nên bảng này
            // hiện `0,0000 USD` suốt từ 20/09 tới lúc màn S22 đọc lại hợp đồng — một bảng số
            // liệu luôn bằng 0 trông y hệt một dự án chưa tiêu đồng nào.
            bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: [
                ["Hôm nay", String(format: "%.4f USD", (b["spent_usd"] as? Double) ?? 0)],
                ["Hạn ngày", EideManMoHinh.oHanMuc(b["daily_budget_usd"])],
                ["Số lời gọi", "\(EideManHoChieu.nguyen(b["calls_today"]) ?? 0)"],
            ])
        }
    }

    // MARK: - bốn khối của §8 S1

    /// **Tính năng: n passing / n tổng, cái đang làm dở.**
    ///
    /// `project.status` đã tính sẵn cả ba con số lẫn `first_failing` — màn chỉ việc đọc. Con số
    /// này nằm ở S1 chứ không ở màn Kế hoạch vì nó là câu trả lời cho *"dự án xong tới đâu"*,
    /// và đó là câu người mở app hỏi trước mọi câu khác.
    private func _khoiTinhNang(_ goi: @escaping EideGoi) async throws {
        guard let r = try await nangLucNeuCo(goi, "project.status") else { return }
        let bc = (r["report"] as? [String: Any]) ?? [:]
        let f = (bc["features"] as? [String: Any]) ?? [:]
        let tong = EideManHoChieu.nguyen(f["total"]) ?? 0
        let pass = EideManHoChieu.nguyen(f["passing"]) ?? 0
        let fail = EideManHoChieu.nguyen(f["failing"]) ?? 0
        tieuDePhu("TÍNH NĂNG")
        guard tong > 0 else {
            // Không im và cũng không in "0 / 0": một bảng toàn số 0 trông y hệt một dự án đã
            // làm xong mà hỏng hết. Nói thẳng là CHƯA CÓ, và nói chỗ làm ra chúng.
            return them(_chu("Chưa có tính năng nào trong hồ sơ — `plan.define_feature` "
                             + "ghi tính năng xuống store; 0 passing trên 0 tổng.",
                             mau: EideToken.Mau.muted))
        }
        var dong: [[String]] = [
            ["Đã chạy được", "\(pass) passing / \(tong) tổng"],
            ["Đang hỏng", fail > 0 ? "\(fail) failing" : "không có"],
        ]
        if let dau = f["first_failing"] as? String, !dau.isEmpty {
            dong.append(["Đang làm dở", dau])
        }
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)
    }

    /// **Đang chờ tôi: số mục + 3 cái gần nhất, bấm được sang đúng màn.**
    ///
    /// Hai nguồn, vì "việc chờ anh" có hai loại và chúng ở hai chỗ: mục bị CỔNG chặn
    /// (`queue.list`) và điểm CẦN LÀM RÕ đang mở (`view.artifacts kind=clarification`). Gộp
    /// chúng ở đây chứ không để người dùng cộng tay hai con số — đúng bài học của [DEV-151],
    /// khi thanh trên ghi "Chờ tôi 0" còn tab Làm rõ hiện 5 dòng "CHỜ ANH".
    ///
    /// Bấm vào một dòng thì sang MÀN XỬ LÝ ĐƯỢC nó, không sang màn xem: mục cổng → vùng trao
    /// đổi (nơi có nút Duyệt từ [DEV-181]), điểm làm rõ → S9.
    private func _khoiChoToi(_ goi: @escaping EideGoi) async throws {
        let cho = ((try? await doc(goi, "queue.list"))?["items"] as? [[String: Any]]) ?? []
        let lamRo = (((try? await nangLuc(goi, "view.artifacts",
                                         ["kind": "clarification", "limit": 50]))?["items"]
                      as? [[String: Any]]) ?? [])
            .filter { (($0["status"] as? String) ?? "open") == "open" }
        let tong = cho.count + lamRo.count
        tieuDePhu("ĐANG CHỜ TÔI — \(tong) mục")
        guard tong > 0 else {
            return them(_chu("Không việc nào chờ anh.", mau: EideToken.Mau.ok))
        }
        var dong: [[String]] = []
        var bam: OBam = [:]
        for m in cho.prefix(3) {
            let qd = (m["decision"] as? [String: Any]) ?? [:]
            dong.append(["Cổng chặn",
                         (m["cap"] as? String) ?? "?",
                         (qd["reason"] as? String) ?? "chính sách không nói lý do"])
            bam[BamO(dong.count - 1, 1)] = { [weak self] in self?.onMoMan?("Main") }
        }
        for m in lamRo.prefix(max(0, 3 - cho.count)) {
            dong.append(["Cần làm rõ",
                         EideManLamRo.nhanLoai((m["kind"] as? String) ?? ""),
                         (m["text"] as? String) ?? "—"])
            bam[BamO(dong.count - 1, 1)] = { [weak self] in
                self?.onMoMan?(EideManLamRo.tien)
            }
        }
        bang(cot: [("LOẠI", 104), ("CHỖ XỬ LÝ", 150), ("VÌ SAO", 0)], dong: dong, bam: bam)
        if tong > dong.count {
            them(_chu("…và \(tong - dong.count) mục nữa — xem đủ ở cột phải.",
                      mau: EideToken.Mau.faint))
        }
    }

    /// **Chip/board đã ghim + ISA + trạng thái hộ chiếu.**
    ///
    /// Chip ghim nằm trong `constraints.yaml` (`project.status.report.target`), còn hộ chiếu
    /// nằm trong store. Hai chỗ, và chúng LỆCH ĐƯỢC: ghim một chip mà chưa nhập hộ chiếu của
    /// nó là trạng thái bình thường ngay sau `project.set_target`, và cũng là lý do mọi lệnh
    /// sinh mã sau đó hỏng. Nên màn nói cả hai vế, kể cả khi vế sau là "chưa có".
    private func _khoiPhanCung(_ goi: @escaping EideGoi) async throws {
        let r = try? await nangLuc(goi, "project.status")
        let bc = ((r?["report"]) as? [String: Any]) ?? [:]
        let tg = (bc["target"] as? [String: Any]) ?? [:]
        let hc = ((try? await doc(goi, "passport.browse", ["limit": 20]))?["items"]
                  as? [[String: Any]]) ?? []
        tieuDePhu("PHẦN CỨNG ĐÃ GHIM")
        let chip = EideManHoChieu.giaTri(tg["chip"])
        guard !chip.isEmpty, chip != "—" else {
            return them(_chu("Chưa ghim chip nào — `project.set_target` ghim chip/board, và "
                             + "mọi lệnh sinh mã đều đọc từ chỗ ghim ấy.",
                             mau: EideToken.Mau.warn))
        }
        var dong: [[String]] = [["Chip", chip]]
        let board = EideManHoChieu.giaTri(tg["board"])
        if !board.isEmpty, board != "—" { dong.append(["Board", board]) }
        // ISA quyết định chuỗi công cụ; thiếu nó thì `env.check` dừng lại hỏi người ([DEV-181]).
        dong.append(["ISA", {
            let v = EideManHoChieu.giaTri(tg["isa"])
            return (v.isEmpty || v == "—") ? "chưa biết — tác tử sẽ hỏi khi cần" : v
        }()])
        dong.append(["Hộ chiếu", hc.isEmpty
                     ? "CHƯA CÓ — nhập datasheet/ATDF ở màn Nhập tài liệu (S3)"
                     : "\(hc.count) bản trong store"])
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)
    }

    /// **3 việc tác tử vừa làm xong (có giờ).**
    ///
    /// Đọc `view.timeline` như màn Nhật ký, nhưng chỉ ba dòng và chỉ việc ĐÃ XONG. S1 trả lời
    /// *"tác tử vừa làm gì"*; cả dòng thời gian đầy đủ là câu hỏi của màn S8, và in nó ở đây
    /// chỉ làm người đọc phải lọc bằng mắt.
    private func _khoiVuaXong(_ goi: @escaping EideGoi) async throws {
        let r = try? await doc(goi, "view.timeline", ["limit": 60])
        let ds = ((r?["events"]) as? [[String: Any]]) ?? []
        let xong = ds.reversed().filter { Self.laViecXong($0) }.prefix(3)
        tieuDePhu("TÁC TỬ VỪA LÀM XONG")
        guard !xong.isEmpty else {
            return them(_chu("Chưa có việc nào chạy xong trong dự án này.",
                             mau: EideToken.Mau.muted))
        }
        bang(cot: [("LÚC", 132), ("VIỆC", 0)],
             dong: xong.map { [EideManNhatKy.gio($0["ts"] as? String),
                               Self.tenViec($0)] })
    }

    /// Bản ghi này có phải một việc ĐÃ CHẠY XONG không?
    ///
    /// Lọc theo `kind`, không theo chữ trong mô tả: dòng thời gian trộn bốn nguồn và mỗi nguồn
    /// viết mô tả một kiểu. Chỉ nhận `cap.run.finish` trạng thái `done` — `pending` là việc
    /// đang chờ người (đã có khối riêng ở trên), `failed` là việc hỏng và gọi nó là "vừa làm
    /// xong" thì màn này nói dối đúng lúc người dùng cần biết sự thật nhất.
    static func laViecXong(_ e: [String: Any]) -> Bool {
        guard (e["kind"] as? String) == "cap.run.finish" else { return false }
        return ((e["data"] as? [String: Any])?["status"] as? String) == "done"
    }

    static func tenViec(_ e: [String: Any]) -> String {
        let d = (e["data"] as? [String: Any]) ?? [:]
        let cap = (d["cap"] as? String) ?? (e["cap"] as? String) ?? "việc chưa rõ tên"
        let ms = EideManHoChieu.nguyen(d["ms"]).map { " · \($0) ms" } ?? ""
        return "`\(cap)`" + ms
    }

    private func _chu(_ s: String, mau: NSColor) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        return n
    }
}
