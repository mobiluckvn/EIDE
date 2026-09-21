import AppKit
import EideLoi

/// Nền chung của bốn màn nhóm THIẾT KẾ (S10–S13).
///
/// Cả bốn đứng trên cùng một câu hỏi — *"dự án này đang có những hiện vật gì"* — và cùng một
/// năng lực trả lời: `view.artifacts` (VIEW-14). Trước khi có nó, mọi thứ chạm tới hiện vật kỹ
/// nghệ trong store đều là năng lực SINH, nên bốn màn này hoặc không dựng được, hoặc mỗi lần mở
/// là một lần tiêu tiền mô hình.
///
/// **`R0` không có nghĩa là "chỉ đọc trạng thái có sẵn"** — đó là chỗ dễ nhầm nhất của cả nhóm:
/// `req.elicit` là R0 nhưng gọi mô hình, `arch.adr` là R0 nhưng ghi tệp, `diagram.architecture`
/// là R0 nhưng dựng lược đồ mới. Lớp này tồn tại một phần để giữ ranh giới ấy ở một chỗ.
@MainActor
open class EideManThietKe: EideManCoSo {

    /// Đọc một loại hiện vật. `nil` = dự án chưa có store.
    public func hienVat(_ goi: @escaping EideGoi, _ loai: String,
                        _ them: [String: Any] = [:]) async throws -> (dong: [[String: Any]], tong: Int)? {
        guard let r = try await nangLucNeuCo(goi, "view.artifacts", ["kind": loai].merging(them) { a, _ in a })
        else { return nil }
        return ((r["items"] as? [[String: Any]]) ?? [], EideManHoChieu.nguyen(r["total"]) ?? 0)
    }

    /// Trạng thái rỗng dùng chung: chưa có hiện vật loại này.
    ///
    /// Bốn màn nói bốn câu khác nhau ở phần "bước kế tiếp", vì bốn hiện vật ra đời từ bốn chỗ
    /// khác nhau — gộp thành một câu chung sẽ chỉ người dùng tới sai nơi ba lần trong bốn.
    public func rongVi(_ gi: String, buocKe: String) {
        rong(vi: "\(gi) — chưa có hiện vật nào thuộc loại này trong store", buocKe: buocKe)
    }
}

/// **S10 — Yêu cầu & kiến trúc.** UXC-31 §8 S10; `view.artifacts` (VIEW-14), `req.ground_hw`
/// (REQ-03), `arch.adr` (ARCH-08).
///
/// ## Cột KHẢ THI là lý do màn này tồn tại
///
/// UXC-31 viết rõ: *"bảng FR/NFR với cột khả thi (`req.ground_hw` — **căn cứ phần cứng thật**)"*.
/// Một bảng yêu cầu không có cột ấy thì bất kỳ công cụ quản lý việc nào cũng làm được. Cột khả
/// thi là chỗ tri thức phần cứng chạm vào yêu cầu: "ADC 1 MSPS" gặp fact "2,4 MSPS" thì đạt,
/// gặp "yêu cầu 5 MSPS" thì không — và **kèm fact id**, không kèm một lời khuyên.
public final class EideManYeuCau: EideManThietKe {

    public override class var tien: String { "ReqArch" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let yc = try await hienVat(goi, "requirement") else {
            return rongVi("dự án chưa có store",
                          buocKe: "gõ một câu tiếng Việt mô tả việc cần làm — `req.elicit` rút "
                                + "yêu cầu ra từ đó")
        }
        let adr = (try await hienVat(goi, "adr"))?.dong ?? []

        guard !yc.dong.isEmpty || !adr.isEmpty else {
            return rongVi("chưa có yêu cầu nào",
                          buocKe: "ra lệnh cho tác tử ở vùng trao đổi; `req.elicit` → "
                                + "`req.classify` ghi yêu cầu xuống store")
        }

        if !yc.dong.isEmpty {
            let chuaXet = yc.dong.filter { ($0["feasibility"] as? String) == nil }.count
            tieuDePhu("\(yc.tong) YÊU CẦU"
                      + (chuaXet > 0 ? " — \(chuaXet) CHƯA đối chiếu phần cứng" : ""))
            bang(cot: [("MÃ", 86), ("LOẠI", 62), ("ƯU TIÊN", 78), ("TRẠNG THÁI", 96),
                       ("KHẢ THI", 130), ("NỘI DUNG", 0)],
                 dong: yc.dong.map { d in
                     [(d["id"] as? String) ?? "?",
                      (d["kind"] as? String) ?? "—",
                      (d["priority"] as? String) ?? "—",
                      (d["status"] as? String) ?? "—",
                      Self.oKhaThi(d["feasibility"]),
                      (d["text"] as? String) ?? "—"]
                 })
        }

        guard !adr.isEmpty else { return }
        tieuDePhu("\(adr.count) QUYẾT ĐỊNH KIẾN TRÚC (ADR)")
        bang(cot: [("MÃ", 86), ("TRẠNG THÁI", 96), ("TRÍCH DẪN", 110), ("QUYẾT ĐỊNH", 0)],
             dong: adr.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["status"] as? String) ?? "—",
                  Self.oTrichDan(d["citations"]),
                  ((d["title"] as? String) ?? "") + " — " + ((d["decision"] as? String) ?? "")]
             })
    }

    /// Ô cột KHẢ THI — **`nil` là một câu trả lời thứ ba.**
    ///
    /// "Chưa đối chiếu" khác hẳn "đối chiếu rồi và không đạt", và gộp chúng thành một ô trống
    /// là đúng loại im lặng cả kho này tránh: một yêu cầu chưa ai kiểm trông y hệt một yêu cầu
    /// đã kiểm và sạch.
    public static func oKhaThi(_ x: Any?) -> String {
        guard let s = x as? String, !s.isEmpty else { return "chưa đối chiếu" }
        switch s.lowercased() {
        case "ok", "true", "feasible": return "đạt"
        case "no", "false", "infeasible": return "⛔ KHÔNG đạt"
        default: return s
        }
    }

    /// **ADR không trích dẫn gì là một ADR không kiểm lại được.** KAD-07 dựng cả tầng tri thức
    /// để mọi quyết định truy về một fact; một ô trống ở đây nói rằng quyết định ấy đứng ngoài.
    public static func oTrichDan(_ x: Any?) -> String {
        let ds = (x as? [Any]) ?? []
        guard !ds.isEmpty else { return "⚠ không có" }
        return "\(ds.count) fact"
    }
}

/// **S12 — Kế hoạch.** UXC-31 §8 S12; `view.artifacts`, `plan.sufficiency` (PLAN-06).
///
/// ## `missing[]` lên ĐẦU bảng, không xuống cuối
///
/// UXC-31 viết: *"`missing[]` hiện thành khối **còn thiếu** đầu bảng"*. Thứ tự ấy là nội dung:
/// một kế hoạch thiếu căn cứ vẫn chạy được từng bước và vẫn hỏng ở bước cuối, nên thứ người cần
/// đọc TRƯỚC khi đọc các bước là danh sách những gì chưa có.
public final class EideManKeHoach: EideManThietKe {

    public override class var tien: String { "PlanDiff" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let kh = try await hienVat(goi, "plan") else {
            return rongVi("dự án chưa có store",
                          buocKe: "ra lệnh cho tác tử — `plan.create` dựng kế hoạch cho một "
                                + "tính năng, và tính năng đến từ `plan.define_feature`")
        }
        guard !kh.dong.isEmpty else {
            return rongVi("chưa có kế hoạch cho tính năng nào",
                          buocKe: "gõ một câu mô tả tính năng cần làm; `plan.create` lập chuỗi "
                                + "bước kèm fact trích dẫn cho từng bước")
        }

        // Khối "còn thiếu" TRƯỚC bảng bước — thứ tự là nội dung, không phải trình bày.
        for f in kh.dong.prefix(3) {
            guard let id = f["id"] as? String,
                  let r = try? await nangLuc(goi, "plan.sufficiency", ["task_ref": id]) else { continue }
            let du = (r["sufficient"] as? Bool) ?? true
            let thieu = (r["missing"] as? [Any]) ?? []
            guard !du || !thieu.isEmpty else { continue }
            _khoiConThieu(id, thieu)
        }

        tieuDePhu("\(kh.tong) TÍNH NĂNG CÓ KẾ HOẠCH")
        bang(cot: [("MÃ", 110), ("TRẠNG THÁI", 100), ("YÊU CẦU", 130), ("SỬA LẦN CUỐI", 132),
                   ("TÊN", 0)],
             dong: kh.dong.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["status"] as? String) ?? "—",
                  Self.oYeuCau(d["requirement_ids"]),
                  EideManNhatKy.gio(d["updated_at"] as? String),
                  (d["title"] as? String) ?? "—"]
             })
    }

    private func _khoiConThieu(_ id: String, _ thieu: [Any]) {
        let n = NSTextField(wrappingLabelWithString:
            "⚠ `\(id)` — CÒN THIẾU \(thieu.count) căn cứ: "
            + thieu.prefix(6).map { EideManHoChieu.giaTri($0) }.joined(separator: ", ")
            + (thieu.count > 6 ? "…" : "")
            + ". Kế hoạch thiếu căn cứ vẫn chạy được từng bước và vẫn hỏng ở bước cuối.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)
    }

    /// Một tính năng không nối về yêu cầu nào là một tính năng không ai truy được vì sao nó tồn
    /// tại — REQ-06 dựng ma trận truy vết chính để chỗ này không trống.
    public static func oYeuCau(_ x: Any?) -> String {
        let ds = (x as? [Any]) ?? []
        guard !ds.isEmpty else { return "⚠ không nối yêu cầu" }
        return ds.prefix(3).map { EideManHoChieu.giaTri($0) }.joined(separator: ", ")
             + (ds.count > 3 ? " +\(ds.count - 3)" : "")
    }
}

/// **S11 — Lược đồ.** UXC-31 §8 S11; `view.artifacts`, `diagram.sync` (DIAGRAM-14).
///
/// ## Chỉ báo đồng bộ hai chiều mã ↔ hình
///
/// *"lệch thì băng vàng + nút đồng bộ"*. Một lược đồ lệch khỏi mã là thứ tệ hơn không có lược
/// đồ: người đọc tin vào hình, và hình nói sai. Nên cột `stale` không nằm lẫn trong bảng mà
/// được kéo lên thành một băng.
public final class EideManLuocDo: EideManThietKe {

    public override class var tien: String { "DiagramView" }

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        guard let ld = try await hienVat(goi, "diagram") else {
            return rongVi("dự án chưa có store",
                          buocKe: "`diagram.*` dựng lược đồ từ module, netlist và fact — nhập "
                                + "tài liệu ở S4 trước")
        }
        guard !ld.dong.isEmpty else {
            return rongVi("chưa có lược đồ nào",
                          buocKe: "ra lệnh cho tác tử dựng lược đồ (`diagram.architecture`, "
                                + "`diagram.sequence`, `diagram.pinmap`…) — chúng ghi vào store")
        }

        let lech = ld.dong.filter { Self.laLech($0) }
        if !lech.isEmpty { _bangLech(lech) }

        tieuDePhu("\(ld.tong) LƯỢC ĐỒ" + (lech.isEmpty ? "" : " · \(lech.count) LỆCH VỚI MÃ"))
        bang(cot: [("MÃ", 120), ("LOẠI", 116), ("NGÔN NGỮ", 84), ("ĐỒNG BỘ", 128),
                   ("DỰNG LÚC", 132), ("ĐƯỜNG DẪN", 0)],
             dong: ld.dong.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["kind"] as? String) ?? "—",
                  (d["lang"] as? String) ?? "—",
                  Self.oDongBo(d),
                  EideManNhatKy.gio(d["at"] as? String),
                  (d["path"] as? String) ?? "—"]
             })
        them(cocBao)
    }

    /// `stale` trong store là INTEGER (0/1), không phải Bool — SQLite không có kiểu boolean.
    /// Đọc bằng `as? Bool` sẽ ra `nil` cho MỌI hàng, và cột đồng bộ im lặng báo "khớp".
    public static func laLech(_ d: [String: Any]) -> Bool {
        if let b = d["stale"] as? Bool { return b }
        return (EideManHoChieu.nguyen(d["stale"]) ?? 0) != 0
    }

    public static func oDongBo(_ d: [String: Any]) -> String {
        guard laLech(d) else {
            let voi = (d["synced_with"] as? String) ?? ""
            return voi.isEmpty ? "khớp" : "khớp · \(EideManHoChieu.tenTep(voi))"
        }
        return "⚠ LỆCH với mã"
    }

    private func _bangLech(_ ds: [[String: Any]]) {
        let n = NSTextField(wrappingLabelWithString:
            "⚠ \(ds.count) lược đồ đang LỆCH với mã: "
            + ds.prefix(4).map { ($0["id"] as? String) ?? "?" }.joined(separator: ", ")
            + (ds.count > 4 ? "…" : "")
            + ". Một lược đồ lệch tệ hơn không có lược đồ — người đọc tin vào hình, và hình "
            + "đang nói sai.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)

        for d in ds.prefix(6) {
            let b = NSButton(title: "Đồng bộ \((d["id"] as? String) ?? "?")",
                             target: self, action: #selector(_dongBo(_:)))
            b.bezelStyle = .inline
            b.identifier = NSUserInterfaceItemIdentifier((d["id"] as? String) ?? "")
            them(b)
        }
    }

    @objc private func _dongBo(_ n: NSButton) {
        guard let goi = goiLoi, let id = n.identifier?.rawValue, !id.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                // `direction` nêu tường minh: DIAGRAM-14 đồng bộ HAI CHIỀU, và để lõi tự đoán
                // chiều là để nó ghi đè mã bằng hình trong đúng trường hợp người vừa sửa mã.
                let r = try await nangLuc(goi, "diagram.sync",
                                          ["diagram_id": id, "direction": "code_to_diagram"])
                let ap = (r["applied"] as? Bool) ?? false
                _bao(ap ? "Đã dựng lại `\(id)` từ mã."
                        : "Chưa áp — `diagram.sync` trả về khác biệt để anh xem trước.",
                     mau: ap ? EideToken.Mau.ok : EideToken.Mau.warn)
                if ap { await nap(goi) }
            } catch {
                _bao("Không đồng bộ được `\(id)`: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

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
}

/// **S13 — Tài liệu.** UXC-31 §8 S13; `view.artifacts`, `doc.style_check` (DOC-08).
///
/// ## "Mọi khẳng định có nguồn" là một phép kiểm, không phải một lời khuyên
///
/// `doc.style_check` phân loại vấn đề thành `lang|term|uncited|format|glossary`, và một trong
/// năm loại ấy nặng hơn hẳn bốn loại kia: `uncited`. Sai chính tả thuật ngữ làm tài liệu khó
/// đọc; một khẳng định không nguồn làm tài liệu **không kiểm được** — đúng thứ cả sản phẩm tồn
/// tại để tránh. Nên cột vấn đề tách riêng nó.
public final class EideManTaiLieu: EideManThietKe {

    public override class var tien: String { "Doc" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let tl = try await hienVat(goi, "doc") else {
            return rongVi("dự án chưa có store",
                          buocKe: "`doc.generate` viết tài liệu từ chính store — nhập tài liệu "
                                + "và sinh mã trước, rồi bảo tác tử viết SRS/SDD")
        }
        guard !tl.dong.isEmpty else {
            return rongVi("chưa sinh tài liệu nào",
                          buocKe: "bảo tác tử `doc.generate --type SRS` — bảng số liệu dựng từ "
                                + "store, mục Nguồn truy ngược về từng `source`")
        }

        let cu = tl.dong.filter { !(($0["stale_sections"] as? [Any]) ?? []).isEmpty }
        let khongNguon = tl.dong.reduce(0) { $0 + Self.soKhongNguon($1["style_issues"]) }
        if !cu.isEmpty || khongNguon > 0 { _bangCanhBao(cu.count, khongNguon) }

        tieuDePhu("\(tl.tong) TÀI LIỆU ĐÃ SINH")
        bang(cot: [("MÃ", 98), ("LOẠI", 86), ("NGÔN NGỮ", 76), ("MỤC CŨ", 84),
                   ("VẤN ĐỀ", 150), ("ĐƯỜNG DẪN", 0)],
             dong: tl.dong.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["type"] as? String) ?? "—",
                  (d["lang"] as? String) ?? "—",
                  Self.oMucCu(d["stale_sections"]),
                  Self.oVanDe(d["style_issues"]),
                  (d["path"] as? String) ?? "—"]
             })
    }

    /// Số vấn đề loại `uncited` — tách riêng vì nó là loại duy nhất làm tài liệu KHÔNG KIỂM ĐƯỢC.
    public static func soKhongNguon(_ x: Any?) -> Int {
        ((x as? [[String: Any]]) ?? []).filter { ($0["kind"] as? String) == "uncited" }.count
    }

    public static func oVanDe(_ x: Any?) -> String {
        let ds = (x as? [[String: Any]]) ?? []
        guard !ds.isEmpty else { return "không" }
        let kn = soKhongNguon(x)
        let con = ds.count - kn
        var phan: [String] = []
        if kn > 0 { phan.append("⛔ \(kn) KHÔNG NGUỒN") }
        if con > 0 { phan.append("\(con) văn phong") }
        return phan.joined(separator: " · ")
    }

    public static func oMucCu(_ x: Any?) -> String {
        let n = ((x as? [Any]) ?? []).count
        return n == 0 ? "—" : "⚠ \(n)"
    }

    private func _bangCanhBao(_ soCu: Int, _ khongNguon: Int) {
        var phan: [String] = []
        if khongNguon > 0 {
            phan.append("⛔ \(khongNguon) khẳng định KHÔNG CÓ NGUỒN — tài liệu ấy không kiểm "
                        + "lại được, và đó là thứ cả sản phẩm tồn tại để tránh")
        }
        if soCu > 0 {
            phan.append("⚠ \(soCu) tài liệu có mục đã CŨ so với mã — `doc.sync` dựng lại chúng")
        }
        let n = NSTextField(wrappingLabelWithString: phan.joined(separator: ". ") + ".")
        n.font = EideToken.fontUI
        n.textColor = khongNguon > 0 ? EideToken.Mau.bad : EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = khongNguon > 0 ? EideToken.Mau.badBg : EideToken.Mau.warnBg
        them(n)
    }
}
