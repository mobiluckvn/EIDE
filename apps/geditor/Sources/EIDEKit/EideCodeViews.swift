import AppKit

/// Bốn màn "mã & kế hoạch" — UXD-13 màn 9 (DiagramView), 11 (PlanDiff), 12 (Code), 13 (Sim).
///
/// Spec: CDS-12 DIAGRAM-01..14, PLAN-01..07, CODE-01..16, SIM-01..07; DDD-14 `tool_report`
/// (`{id, tool, passed, log_ref, metrics, artifacts, duration_ms}`); UXD-13 §2, U2, U5, U9.
///
/// ## Bất biến chung của bốn màn này
///
/// Đây là bốn màn nơi máy ĐỀ XUẤT và người DUYỆT — kế hoạch, diff, kết quả dựng, kết quả mô
/// phỏng. Bất biến của chúng: **không bao giờ hiện một kết quả "đạt" mà không hiện thứ đã
/// kiểm nó, và không bao giờ để một lý do TỪ CHỐI đọc nhẹ hơn nó thật sự là.** Một `verdict:
/// block` của `code.constant_guard` hiện ra như một dòng cảnh báo vàng sẽ được bấm qua; một
/// kế hoạch `sufficient: false` hiện ra như một kế hoạch bình thường sẽ được duyệt.

// MARK: - Màn 9: Lược đồ

/// `diagram.render` `{path, lint[]}`, `diagram.lint` `{issues[]{severity, line, message}}`,
/// `diagram.sync` `{diff, applied}`.
public final class DiagramView: ManHinhCoSo {

    public var onMoDong: ((Int) -> Void)?

    public private(set) var soLoi = 0
    public private(set) var duongDanAnh = ""
    /// `diagram.sync` đã ghi thay đổi vào tệp chưa.
    public private(set) var daApDung = false

    public init() { super.init(ten: "Lược đồ") }

    /// **Lược đồ vẽ xong vẫn phải nói ra lỗi lint của nó.**
    ///
    /// `diagram.render` trả cả `path` lẫn `lint[]` trong một lần gọi — tức một lược đồ có nút
    /// mồ côi, có cạnh trỏ vào hư không, vẫn render ra một tấm ảnh hoàn toàn bình thường. Ảnh
    /// ấy rồi sẽ được chèn vào tài liệu (`doc.embed_diagram`) và đọc như một mô tả đúng của hệ
    /// thống. Lint là thứ duy nhất biết nó không đúng, nên nó phải hiện cùng chỗ với ảnh chứ
    /// không nằm trong một tab "chi tiết kỹ thuật" nào đó.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soLoi = 0; duongDanAnh = ""; daApDung = false

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa vẽ lược đồ nào — `/diagram.block`, `/diagram.state`, `/diagram.sequence`…")
            return
        }

        duongDanAnh = (ketQua["path"] as? String) ?? ""
        // Mười năng lực `diagram.block/architecture/sequence/state/flow/timing/memory_map/
        // kg_view/gantt/from_image` đều trả `{diagram}` — một Diagram của DDD-14 mang `lang`,
        // `src` và `path`. Không đọc nó thì cả mười cái vẽ xong rồi màn hình không hiện gì:
        // đúng nhóm năng lực đông nhất của màn này.
        let lg = ketQua["diagram"] as? [String: Any]
        let tinFromAnh = EideSo.thuc(ketQua["confidence"])
        // Hai năng lực, hai tên khóa, cùng một danh sách: `render` gọi là `lint`, `lint` gọi là
        // `issues`. Gộp ở đây chứ không bắt panel nhớ cái nào của ai.
        let loi = (ketQua["lint"] as? [[String: Any]]) ?? (ketQua["issues"] as? [[String: Any]]) ?? []
        let khac = ketQua["diff"] as? [String: Any]
        daApDung = (ketQua["applied"] as? Bool) ?? false
        soLoi = loi.count

        var d: [String] = []
        if !duongDanAnh.isEmpty { d.append(EideKnowledgeFormat.tenNgan(duongDanAnh)) }
        if soLoi > 0 { d.append("\(soLoi) lỗi lược đồ") } else if !duongDanAnh.isEmpty {
            d.append("lint sạch")
        }
        if khac != nil { d.append(daApDung ? "đã đồng bộ vào tệp" : "CHƯA áp dụng") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = soLoi > 0 ? EideToken.Mau.warn : EideToken.Mau.muted

        if !duongDanAnh.isEmpty && soLoi > 0 {
            let v = noiRong("Ảnh đã vẽ xong nhưng lược đồ còn \(soLoi) lỗi — đừng chèn nó vào "
                          + "tài liệu trước khi sửa, vì ảnh không mang theo cảnh báo nào.")
            v.textColor = EideToken.Mau.warn
        }

        for e in loi.sorted(by: { EideMuc.diem(($0["severity"] as? String) ?? "")
                                < EideMuc.diem(($1["severity"] as? String) ?? "") }) {
            let muc = (e["severity"] as? String) ?? "warning"
            let dong = EideSo.nguyen(e["line"]) ?? 0
            let tin = (e["message"] as? String) ?? ""
            themDong(dong > 0 ? "dòng \(dong)" : EideMuc.ten(muc), tin, mau: EideMuc.mau(muc),
                     nut: dong > 0, ma: String(dong), bam: #selector(moDong(_:)))
        }

        if let d = lg { _hienLuocDo(d, tin: tinFromAnh) }
        if let k = khac { _hienKhac(k) }

        if soDong == 0 && !duongDanAnh.isEmpty {
            noiRong("Lược đồ sạch: \(duongDanAnh)")
        }
    }

    /// Một `Diagram` của DDD-14: `{id, kind, lang, src, path, model_ref, stale}`.
    ///
    /// **`src` hiện ra, không chỉ `path`.** Người dùng màn này sửa lược đồ, và thứ họ sửa là mã
    /// Mermaid/PlantUML chứ không phải tấm ảnh. Một màn chỉ nói "đã vẽ: hinh.svg" bắt họ đi mở
    /// tệp khác để biết máy vừa viết gì.
    ///
    /// **`stale` là cảnh báo, không phải nhãn.** `diagram.sync` đánh dấu lược đồ lỗi thời khi
    /// mã đổi; một lược đồ lỗi thời trông y hệt một lược đồ đúng, và nó đang mô tả sai hệ thống.
    private func _hienLuocDo(_ d: [String: Any], tin: Double?) {
        let loai = (d["kind"] as? String) ?? ""
        let ngonNgu = (d["lang"] as? String) ?? ""
        let ma = (d["src"] as? String) ?? ""
        let duong = (d["path"] as? String) ?? ""
        let neo = (d["model_ref"] as? String) ?? ""
        let loiThoi = (d["stale"] as? Bool) ?? false

        if duongDanAnh.isEmpty && !duong.isEmpty { duongDanAnh = duong }

        themDong([loai, ngonNgu].filter { !$0.isEmpty }.joined(separator: " · "),
                 duong.isEmpty ? "chưa render ra tệp" : duong,
                 mau: duong.isEmpty ? EideToken.Mau.warn : EideToken.Mau.info)

        if loiThoi {
            themDong("LỖI THỜI", "mã hoặc kiến trúc đã đổi sau khi vẽ — lược đồ này đang mô tả "
                               + "sai hệ thống; chạy `/diagram.sync` trước khi dùng",
                     mau: EideToken.Mau.bad)
        }
        if !neo.isEmpty { themDong("neo vào", neo) }
        if let t = tin {
            // DIAGRAM-12 dựng lược đồ TỪ ẢNH — một phép đoán, và ngưỡng tin cậy của nó quyết
            // định lược đồ có được ghi vào dự án hay chỉ để người xem.
            themDong("dựng từ ảnh", String(format: "tin cậy %.0f%%", t * 100)
                        + (t < 0.6 ? " — quá thấp để ghi vào dự án" : ""),
                     mau: t < 0.6 ? EideToken.Mau.warn : nil)
        }
        if !ma.isEmpty {
            let dong = ma.split(separator: "\n", omittingEmptySubsequences: false)
            themDong("mã lược đồ", "\(dong.count) dòng")
            for l in dong.prefix(40) { themDong("  ", String(l)) }
            if dong.count > 40 { noiRong("… và \(dong.count - 40) dòng nữa.") }
        }
    }

    private func _hienKhac(_ k: [String: Any]) {
        // `diagram.sync` trả `diff` tự do theo hướng đồng bộ (to_code / to_diagram). Hiện các
        // khóa có mặt thay vì đoán một hình dạng cố định.
        for (ten, v) in k.sorted(by: { $0.key < $1.key }) {
            if let a = v as? [Any] {
                themDong(ten, "\(a.count) thay đổi", mau: a.isEmpty ? nil : EideToken.Mau.info)
            } else {
                themDong(ten, EideKnowledgeFormat.giaTri(v))
            }
        }
    }

    @objc private func moDong(_ s: NSButton) {
        if let n = Int(s.identifier?.rawValue ?? ""), n > 0 { onMoDong?(n) }
    }
}

// MARK: - Màn 11: Kế hoạch & diff

/// `plan.create` `{plan, decision}`, `plan.sufficiency` `{sufficient, missing[]}`,
/// `plan.estimate` `{estimate{tokens, cost_usd, tool_rounds, minutes}, within_budget}`,
/// `plan.order` `{order[], cycles[][]}`, `code.review` `{review}`,
/// `code.merge` `{commit, branch, undo_until}`.
public final class PlanDiffView: ManHinhCoSo {

    public var onDuyet: ((String) -> Void)?

    public private(set) var soBuoc = 0
    public private(set) var soThieu = 0
    /// `plan.sufficiency` — `nil` khi chưa chạy, khác hẳn với `false`.
    public private(set) var duTriThuc: Bool?
    public private(set) var trongNganSach = true
    public private(set) var soChuTrinh = 0

    public init() { super.init(ten: "Kế hoạch & mã") }

    /// **Một kế hoạch `sufficient: false` không được đọc như một kế hoạch bình thường.**
    ///
    /// PLAN-07 tự đánh giá đủ tri thức TRƯỚC khi làm, và trả `missing[]` — những thứ hệ thống
    /// biết là mình chưa biết. Cổng G1 là chỗ người duyệt kế hoạch; duyệt một kế hoạch thiếu
    /// tri thức là duyệt một việc đã biết trước sẽ phải làm lại. Nên `missing[]` lên đầu màn,
    /// trên cả các bước — người phải đọc "còn thiếu 3 thứ" trước khi đọc "bước 1, bước 2".
    ///
    /// **`undo_until` hiện ra vì cửa sổ hoàn tác có hạn.** `code.merge` trả về một mốc thời
    /// gian; sau mốc ấy `undo.apply` trả E7000. Một giao diện chỉ nói "đã merge" để người dùng
    /// tin rằng họ còn rút lại được mãi mãi.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soBuoc = 0; soThieu = 0; duTriThuc = nil; trongNganSach = true; soChuTrinh = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có kế hoạch — `/plan.create` sau khi `req.*` và `arch.*` xong.")
            return
        }

        let ke = ketQua["plan"] as? [String: Any]
        let thieu = (ketQua["missing"] as? [[String: Any]]) ?? []
        duTriThuc = ketQua["sufficient"] as? Bool
        let uoc = ketQua["estimate"] as? [String: Any]
        let thuTu = (ketQua["order"] as? [String]) ?? []
        let vong = (ketQua["cycles"] as? [[String]]) ?? []
        let ra = ketQua["review"] as? [String: Any]
        let commit = (ketQua["commit"] as? String) ?? ""
        let nhanh = (ketQua["branch"] as? String) ?? ""
        let hanHoanTac = (ketQua["undo_until"] as? String) ?? ""
        let quyet = ketQua["decision"] as? [String: Any]

        soThieu = thieu.count
        soChuTrinh = vong.count
        trongNganSach = (ketQua["within_budget"] as? Bool) ?? true

        let buoc = (ke?["steps"] as? [[String: Any]]) ?? []
        soBuoc = buoc.count

        var d: [String] = []
        if soBuoc > 0 { d.append("\(soBuoc) bước") }
        if duTriThuc == false { d.append("THIẾU TRI THỨC (\(soThieu))") }
        else if duTriThuc == true { d.append("đủ tri thức") }
        if let u = uoc {
            let usd = EideSo.thuc(u["cost_usd"]) ?? 0
            let phut = EideSo.nguyen(u["minutes"]) ?? 0
            d.append(String(format: "~%.2f USD · ~%d phút", usd, phut))
            if !trongNganSach { d.append("VƯỢT NGÂN SÁCH") }
        }
        if soChuTrinh > 0 { d.append("\(soChuTrinh) VÒNG PHỤ THUỘC") }
        if !commit.isEmpty { d.append("đã merge \(EideKnowledgeFormat.tenNgan(commit))") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (duTriThuc == false || !trongNganSach || soChuTrinh > 0)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        // Thiếu tri thức lên TRƯỚC các bước.
        for m in thieu {
            let gi = (m["what"] as? String) ?? (m["kind"] as? String) ?? "?"
            let cach = (m["how"] as? String) ?? (m["suggestion"] as? String) ?? ""
            themDong("còn thiếu: \(gi)", cach, mau: EideToken.Mau.bad)
        }

        for v in vong {
            themDong("vòng phụ thuộc", v.joined(separator: " → "), mau: EideToken.Mau.bad)
        }

        for (i, b) in buoc.enumerated() {
            let ten = (b["title"] as? String) ?? (b["name"] as? String) ?? "bước \(i + 1)"
            let cap = (b["capability"] as? String) ?? ""
            // PLAN-03 đòi kế hoạch có TRÍCH DẪN fact. Một bước không trích dẫn gì là một bước
            // dựa trên phỏng đoán của mô hình — cùng loại vấn đề với `RagAskView`.
            let trich = ((b["citations"] as? [String]) ?? []).count
            themDong("\(i + 1). \(ten)",
                     [cap, trich > 0 ? "\(trich) trích dẫn" : "KHÔNG trích dẫn"]
                        .filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: trich > 0 ? EideToken.Mau.muted : EideToken.Mau.warn)
        }

        for (i, m) in thuTu.enumerated() { themDong("thứ tự \(i + 1)", m) }

        if let r = ra { _hienRaSoat(r) }

        if !commit.isEmpty {
            themDong("merge", "\(commit) trên \(nhanh)", mau: EideToken.Mau.ok)
            if hanHoanTac.isEmpty {
                themDong("hoàn tác", "hợp đồng không trả `undo_until` — không rõ hạn rút lại",
                         mau: EideToken.Mau.warn)
            } else {
                themDong("hoàn tác được đến", hanHoanTac, mau: EideToken.Mau.info)
            }
        }

        if let q = quyet {
            let cong = (q["gate"] as? String) ?? "G1"
            let kq = (q["decision"] as? String) ?? (q["status"] as? String) ?? "chờ"
            let vi = (q["reason"] as? String) ?? ""
            themDong(cong, "\(kq) \(vi)", mau: kq == "approve" ? EideToken.Mau.ok : EideToken.Mau.warn,
                     nut: kq != "approve", ma: (q["gate_id"] as? String) ?? "",
                     bam: #selector(duyet(_:)))
        }

        if let f = ketQua["feature"] as? [String: Any] { _hienTinhNang(f) }

        if soDong == 0 { noiRong("Kế hoạch rỗng — không có bước nào.") }
    }

    /// `plan.define_feature` `{feature{id, title, expectation, constraints[], touches[]}}`.
    ///
    /// **`expectation` phải MÁY QUAN SÁT ĐƯỢC** — hợp đồng PLAN-01 nói thẳng điều đó trong mô
    /// tả trường. Một tính năng có kỳ vọng kiểu "chạy mượt" sẽ đi hết chuỗi tới `sim.scenario`
    /// rồi mới hỏng, vì không có gì để chấm.
    private func _hienTinhNang(_ f: [String: Any]) {
        let ma = (f["id"] as? String) ?? "?"
        let ten = (f["title"] as? String) ?? ""
        let ky = (f["expectation"] as? String) ?? ""
        themDong("\(ma) \(ten)",
                 ky.isEmpty ? "KHÔNG có kỳ vọng đo được — `sim.scenario` sẽ không chấm được gì"
                            : ky,
                 mau: ky.isEmpty ? EideToken.Mau.bad : EideToken.Mau.ok)
        if let rb = f["constraints"] as? [Any], !rb.isEmpty {
            themDong(" · ràng buộc",
                     rb.map { EideKnowledgeFormat.giaTri($0) }.joined(separator: "; "))
        }
        if let ch = f["touches"] as? [Any], !ch.isEmpty {
            themDong(" · chạm vào",
                     ch.map { EideKnowledgeFormat.giaTri($0) }.joined(separator: ", "))
        }
    }

    private func _hienRaSoat(_ r: [String: Any]) {
        let diem = EideSo.thuc(r["score"]) ?? EideSo.nguyen(r["score"]).map(Double.init) ?? -1
        let dat = r["passed"] as? Bool
        let y = (r["findings"] as? [[String: Any]]) ?? []
        var p: [String] = []
        if diem >= 0 { p.append("điểm \(EideKnowledgeFormat.giaTri(diem))") }
        if let d = dat { p.append(d ? "đạt" : "KHÔNG ĐẠT") }
        p.append("\(y.count) phát hiện")
        themDong("rà soát (reviewer khác hãng)", p.joined(separator: " · "),
                 mau: dat == false ? EideToken.Mau.bad : nil)
        for f in y {
            let muc = (f["severity"] as? String) ?? "info"
            themDong(" · " + ((f["rule"] as? String) ?? ""),
                     (f["message"] as? String) ?? "", mau: EideMuc.mau(muc))
        }
    }

    @objc private func duyet(_ s: NSButton) {
        if let g = s.identifier?.rawValue, !g.isEmpty { onDuyet?(g) }
    }
}

// MARK: - Màn 12: Mã nguồn

/// `code.constant_guard` `{verdict, violations[]{file, line, literal, reason}}`,
/// `code.build`/`code.static`/`code.test_host`/`code.size` `{report}` (ToolReport).
public final class CodeView: ManHinhCoSo {

    public var onMoViPham: ((String, Int) -> Void)?

    public private(set) var soViPham = 0
    /// `true` khi `code.constant_guard` trả `verdict: block`.
    public private(set) var biChan = false
    public private(set) var dungDuoc: Bool?

    public init() { super.init(ten: "Mã nguồn") }

    /// **`verdict: block` là CHẶN, không phải cảnh báo.**
    ///
    /// `code.constant_guard` là mắt xích trung tâm của luận điểm đề án: mọi hằng số phần cứng
    /// trong mã phải trỏ về một fact `reviewed`/`verified`. Một `block` hiện ra như một dòng
    /// vàng giữa mười dòng khác sẽ được bấm qua, và bấm qua nó một lần là đủ để một địa chỉ
    /// thanh ghi do mô hình đoán ra đi vào firmware.
    ///
    /// **`flash_pct`/`ram_pct` gần trần phải cảnh báo TRƯỚC khi vượt.** `code.size` trả phần
    /// trăm; 97% không phải lỗi nên không có gì báo, nhưng nó là lần dựng cuối cùng còn thành
    /// công — và người phát hiện ra điều đó lúc thêm tính năng sau thì đã mất một buổi.
    public static let nguongChatBoNho = 0.85

    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soViPham = 0; biChan = false; dungDuoc = nil

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có kết quả nào — `/code.build`, `/code.constant_guard`, `/code.size`.")
            return
        }

        let phanQuyet = (ketQua["verdict"] as? String) ?? ""
        let vp = (ketQua["violations"] as? [[String: Any]]) ?? []
        let bc = ketQua["report"] as? [String: Any]
        let patch = ketQua["patch"] as? [String: Any]
        let boCuoc = ketQua["give_up"] as? Bool

        biChan = phanQuyet == "block"
        soViPham = vp.count

        var d: [String] = []
        if !phanQuyet.isEmpty {
            d.append(biChan ? "CONSTANT-GUARD CHẶN (\(soViPham) hằng số)" : "constant-guard đạt")
        }
        if let r = bc {
            let cc = (r["tool"] as? String) ?? "công cụ"
            dungDuoc = r["passed"] as? Bool
            d.append("\(cc): \(dungDuoc == true ? "đạt" : "KHÔNG ĐẠT")")
            if let ms = r["duration_ms"] as? Int { d.append("\(ms) ms") }
        }
        if boCuoc == true { d.append("tự sửa ĐÃ BỎ CUỘC") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (biChan || dungDuoc == false || boCuoc == true)
            ? EideToken.Mau.bad : EideToken.Mau.muted

        if biChan {
            let v = noiRong("Cổng G-FACT chặn bản vá này: mỗi hằng số phần cứng phải trỏ về một "
                          + "fact đã duyệt. Đây không phải cảnh báo — bản vá không được merge.")
            v.textColor = EideToken.Mau.bad
        }

        for v in vp {
            let tep = (v["file"] as? String) ?? "?"
            let dong = EideSo.nguyen(v["line"]) ?? 0
            let hang = (v["literal"] as? String) ?? EideKnowledgeFormat.giaTri(v["literal"])
            let ly = (v["reason"] as? String) ?? ""
            themDong("\(EideKnowledgeFormat.tenNgan(tep)):\(dong)",
                     "\(hang) — \(ly)", mau: EideToken.Mau.bad,
                     nut: true, ma: "\(tep)#\(dong)", bam: #selector(moViPham(_:)))
        }

        if let r = bc { _hienBaoCao(r) }
        if let p = patch {
            let tep = (p["files"] as? [Any])?.count ?? 0
            themDong("bản vá", tep > 0 ? "\(tep) tệp" : "rỗng",
                     mau: boCuoc == true ? EideToken.Mau.warn : nil)
        }

        _hienDeXuatVaTest(ketQua)

        if soDong == 0 { noiRong("Không có vi phạm, không có báo cáo công cụ nào để hiện.") }
    }

    /// `code.annotate` `{suggestions[]}`, `code.generate_tests` `{tests[]}`,
    /// `code.revert` `{revert_commit}`.
    private func _hienDeXuatVaTest(_ ketQua: [String: Any]) {
        for s in (ketQua["suggestions"] as? [[String: Any]]) ?? [] {
            // CODE-14 là phép ngược của `constant_guard`: tìm fact khớp cho một hằng số trần.
            // `confidence` quyết định người có được bấm "gắn" hay phải tự kiểm — một fact gán
            // nhầm còn tệ hơn một hằng số không nguồn, vì nó trông như đã được duyệt.
            let dong = EideSo.nguyen(s["line"]) ?? 0
            let hang = EideKnowledgeFormat.giaTri(s["literal"])
            let fid = (s["fact_id"] as? String) ?? ""
            let tin = EideSo.thuc(s["confidence"]) ?? 0
            themDong("dòng \(dong): \(hang)",
                     (fid.isEmpty ? "không tìm được fact nào khớp"
                                  : "khớp \(fid)")
                        + String(format: " · tin cậy %.0f%%", tin * 100)
                        + (tin < 0.7 ? " — tự kiểm trước khi gắn" : ""),
                     mau: fid.isEmpty || tin < 0.7 ? EideToken.Mau.warn : EideToken.Mau.ok)
        }
        for k in (ketQua["tests"] as? [[String: Any]]) ?? [] {
            let loai = (k["kind"] as? String) ?? "?"
            let duong = (k["path"] as? String) ?? "?"
            // `kind` là host | sim | hil — ba mức bằng chứng rất khác nhau, và `hil` là mức duy
            // nhất chạm phần cứng thật.
            themDong(EideKnowledgeFormat.tenNgan(duong),
                     "test \(loai)" + (loai == "hil" ? " — cần board thật" : ""),
                     mau: loai == "hil" ? EideToken.Mau.warn : nil)
        }
        if let rc = ketQua["revert_commit"] as? String {
            themDong("đã revert", rc, mau: EideToken.Mau.ok)
        }
    }

    private func _hienBaoCao(_ r: [String: Any]) {
        if let log = r["log_ref"] as? String, !log.isEmpty {
            themDong("log", log, mau: EideToken.Mau.info)
        }
        guard let m = r["metrics"] as? [String: Any] else { return }
        for (k, v) in m.sorted(by: { $0.key < $1.key }) {
            let phanTram = k.hasSuffix("_pct")
            let so = (v as? Double) ?? Double((v as? Int) ?? 0)
            // `_pct` có thể là 0..1 hoặc 0..100 tùy công cụ; chuẩn hóa về 0..1 để so ngưỡng.
            let ti = phanTram ? (so > 1 ? so / 100 : so) : 0
            let chat = phanTram && ti >= Self.nguongChatBoNho
            themDong(k, EideKnowledgeFormat.giaTri(v)
                        + (chat ? String(format: "  ⚠︎ %.0f%% — sắp hết chỗ", ti * 100) : ""),
                     mau: chat ? EideToken.Mau.warn : nil)
        }
        if let top = m["top_symbols"] as? [[String: Any]] {
            for s in top.prefix(5) {
                themDong(" · " + ((s["name"] as? String) ?? "?"),
                         EideKnowledgeFormat.giaTri(s["size"]))
            }
        }
    }

    @objc private func moViPham(_ s: NSButton) {
        let p = (s.identifier?.rawValue ?? "").split(separator: "#", maxSplits: 1).map(String.init)
        guard p.count == 2, let n = Int(p[1]) else { return }
        onMoViPham?(p[0], n)
    }
}

// MARK: - Màn 13: Mô phỏng

/// `sim.run` `{report}` với `captured{uart[], gpio[], vars{}}`,
/// `sim.sweep` `{table[], best}`, `sim.scenario` `{scenario_path}`.
public final class SimView: ManHinhCoSo {

    public var onXemKichBan: ((String) -> Void)?

    public private(set) var soKyVong = 0
    public private(set) var soDat = 0
    /// Số kỳ vọng KHÔNG QUAN SÁT ĐƯỢC — khác hẳn số kỳ vọng SAI. Xem `capNhat`.
    public private(set) var soChuaKiem = 0
    public private(set) var dat: Bool?

    public init() { super.init(ten: "Mô phỏng") }

    /// **`unverified` không được gộp vào `failed`.**
    ///
    /// Lõi `sim.*` đã giữ một bất biến đắt: không kỳ vọng nào được coi là ĐẠT nếu engine không
    /// có kênh quan sát cho nó, và một kịch bản có dù một dòng `unverified` thì `passed=false`.
    /// Màn này phải hiện ba trạng thái chứ không hai, vì hai chữ ấy dẫn tới hai việc khác hẳn
    /// nhau: `failed` nghĩa là *firmware sai* — đi sửa mã; `unverified` nghĩa là *engine không
    /// nhìn thấy được* — đi đổi engine hoặc thêm kênh quan sát. Gộp chúng lại là đẩy người
    /// dùng đi sửa một đoạn mã không có lỗi.
    ///
    /// Điều này quan trọng gấp đôi vì `sim_first` dùng chính con số ấy để cho phép nạp firmware
    /// lên board thật.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soKyVong = 0; soDat = 0; soChuaKiem = 0; dat = nil

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa chạy mô phỏng — `/sim.scenario <feature>` rồi `/sim.run`.")
            return
        }

        let bc = ketQua["report"] as? [String: Any]
        let bang = (ketQua["table"] as? [[String: Any]]) ?? []
        let totNhat = ketQua["best"] as? [String: Any]
        let duong = (ketQua["scenario_path"] as? String) ?? ""

        if !duong.isEmpty {
            tomTat.stringValue = "kịch bản: \(duong)"
            themDong("kịch bản", duong, mau: EideToken.Mau.info,
                     nut: true, ma: duong, bam: #selector(xemKichBan(_:)))
        }

        if let r = bc {
            dat = r["passed"] as? Bool
            // SIM-05 đặt bảng chấm trong `metrics.expect`, và ĐẾM SẴN `n_passed`/`n_unverified`.
            // Dùng số của lõi chứ không tự đếm lại: hai chỗ đếm là hai chỗ có thể lệch nhau, và
            // chỗ lệch sẽ nằm ở đúng cái quyết định firmware có được nạp lên board hay không.
            let mt = (r["metrics"] as? [String: Any]) ?? [:]
            let ky = (mt["expect"] as? [[String: Any]]) ?? []
            soKyVong = ky.count
            soDat = EideSo.nguyen(mt["n_passed"])
                ?? ky.filter { (($0["status"] as? String) ?? "") == "passed" }.count
            soChuaKiem = EideSo.nguyen(mt["n_unverified"])
                ?? ky.filter { (($0["status"] as? String) ?? "") == "unverified" }.count
            let sai = soKyVong - soDat - soChuaKiem

            var d: [String] = []
            d.append(dat == true ? "ĐẠT" : "không đạt")
            if soKyVong > 0 {
                d.append("\(soDat)/\(soKyVong) kỳ vọng đạt")
                if sai > 0 { d.append("\(sai) SAI") }
                if soChuaKiem > 0 { d.append("\(soChuaKiem) KHÔNG QUAN SÁT ĐƯỢC") }
            }
            if let en = mt["engine"] as? String { d.append(en) }
            if let ms = r["duration_ms"] as? Int { d.append("\(ms) ms") }
            // `terminated_by: timeout` nghĩa là firmware chưa chạy hết kịch bản. Một kịch bản
            // bị cắt giữa chừng có thể "đạt" mọi dòng expect ĐÃ chấm mà vẫn chưa nói được gì
            // về phần sau — nên lý do dừng là một phần của kết quả.
            if (mt["terminated_by"] as? String) == "timeout" { d.append("DỪNG VÌ HẾT GIỜ") }
            tomTat.stringValue = d.joined(separator: " · ")
            tomTat.textColor = dat == true ? EideToken.Mau.ok : EideToken.Mau.warn

            if soChuaKiem > 0 {
                let v = noiRong("\(soChuaKiem) kỳ vọng engine hiện tại không nhìn thấy được. "
                              + "Đây KHÔNG phải lỗi firmware — đừng đi sửa mã; đổi engine hoặc "
                              + "thêm kênh quan sát cho kịch bản.")
                v.textColor = EideToken.Mau.warn
            }

            for e in ky {
                let ten = (e["expect"] as? String) ?? (e["name"] as? String) ?? "?"
                let tt = (e["status"] as? String) ?? "?"
                let ly = (e["reason"] as? String) ?? ""
                let mau: NSColor = tt == "passed" ? EideToken.Mau.ok
                    : (tt == "unverified" ? EideToken.Mau.warn : EideToken.Mau.bad)
                themDong(ten, "\(_tenTrangThai(tt))\(ly.isEmpty ? "" : " — \(ly)")", mau: mau)
            }

            _hienBatDuoc(r)
        }

        for r in bang.prefix(30) {
            let ten = r.keys.sorted().map { "\($0)=\(EideKnowledgeFormat.giaTri(r[$0]))" }
            themDong("quét", ten.joined(separator: " · "))
        }
        if bang.count > 30 { noiRong("… và \(bang.count - 30) hàng nữa.") }

        if let b = totNhat {
            let mo = b.keys.sorted().map { "\($0)=\(EideKnowledgeFormat.giaTri(b[$0]))" }
            themDong("tốt nhất", mo.joined(separator: " · "), mau: EideToken.Mau.ok)
        }

        _hienNenTang(ketQua)

        if soDong == 0 { noiRong("Mô phỏng không trả về kỳ vọng nào để hiện.") }
    }

    /// `sim.build_platform` `{platform_dir, engine, coverage}`, `sim.mock_peripheral`
    /// `{mock_path, params}`, `sim.model_plant` `{model_path, params_used, provisional}`.
    private func _hienNenTang(_ ketQua: [String: Any]) {
        if let d = ketQua["platform_dir"] as? String {
            let en = (ketQua["engine"] as? String) ?? "?"
            themDong("nền mô phỏng", "\(en) · \(d)", mau: EideToken.Mau.info)
            if let cv = ketQua["coverage"] as? [String: Any], !cv.isEmpty {
                // SIM-01 `coverage` nói engine mô phỏng được NHỮNG GÌ của con chip. Đây là chỗ
                // quyết định `unverified` sẽ nhiều hay ít về sau, nên hiện nó lúc dựng nền rẻ
                // hơn hẳn để người phát hiện lúc chạy kịch bản.
                for (k, v) in cv.sorted(by: { $0.key < $1.key }) {
                    themDong("  \(k)", EideKnowledgeFormat.giaTri(v))
                }
            }
        }
        if let m = ketQua["mock_path"] as? String {
            themDong("ngoại vi giả", m, mau: EideToken.Mau.info)
        }
        if let m = ketQua["model_path"] as? String {
            themDong("mô hình vật lý", m, mau: EideToken.Mau.info)
        }
        if let tt = ketQua["provisional"] as? [Any], !tt.isEmpty {
            // SIM-03 đánh dấu tham số TẠM — số chưa đo được trên vật thật. Một mô hình chạy
            // bằng số tạm vẫn cho ra đồ thị đẹp, và đồ thị ấy không nói gì về board thật.
            themDong("tham số TẠM",
                     tt.map { EideKnowledgeFormat.giaTri($0) }.joined(separator: ", ")
                        + " — chưa đo trên vật thật",
                     mau: EideToken.Mau.warn)
        }
        if let p = ketQua["params_used"] as? [String: Any], !p.isEmpty {
            for (k, v) in p.sorted(by: { $0.key < $1.key }).prefix(10) {
                themDong("  \(k)", EideKnowledgeFormat.giaTri(v))
            }
        }
    }

    private func _hienBatDuoc(_ r: [String: Any]) {
        guard let b = (r["captured"] as? [String: Any])
            ?? ((r["metrics"] as? [String: Any])?["captured"] as? [String: Any]) else { return }
        if let uart = b["uart"] as? [Any], !uart.isEmpty {
            themDong("UART bắt được", "\(uart.count) dòng", mau: EideToken.Mau.info)
            for d in uart.prefix(5) { themDong(" · ", EideKnowledgeFormat.giaTri(d)) }
        }
        if let gpio = b["gpio"] as? [Any], !gpio.isEmpty {
            themDong("GPIO", "\(gpio.count) lần đổi mức", mau: EideToken.Mau.info)
        }
        if let bien = b["vars"] as? [String: Any], !bien.isEmpty {
            for (k, v) in bien.sorted(by: { $0.key < $1.key }).prefix(8) {
                themDong("biến \(k)", EideKnowledgeFormat.giaTri(v))
            }
        }
    }

    private func _tenTrangThai(_ t: String) -> String {
        switch t {
        case "passed": return "đạt"
        case "failed": return "SAI"
        case "unverified": return "không quan sát được"
        default: return t
        }
    }

    @objc private func xemKichBan(_ s: NSButton) {
        if let d = s.identifier?.rawValue, !d.isEmpty { onXemKichBan?(d) }
    }
}
