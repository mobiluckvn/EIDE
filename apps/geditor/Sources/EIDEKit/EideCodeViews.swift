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
        soTep = 0; soTepThayCaTep = 0

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

        // BẢN VÁ — nửa sau của màn, và tới 15/09/2026 nó hoàn toàn vắng mặt.
        if let vá = ketQua["patch"] as? [String: Any] { _hienBanVa(vá) }

        if soDong == 0 && soTep == 0 { noiRong("Kế hoạch rỗng — không có bước nào.") }
    }

    /// Số tệp trong bản vá đang hiện — cho test và để `capNhat` biết màn có rỗng thật không.
    public private(set) var soTep = 0
    /// Số tệp bị thay TOÀN BỘ (mode `create`/`replace`) thay vì vá từng dòng.
    public private(set) var soTepThayCaTep = 0

    /// `CodePatch` (PRS-16 §4): `{files[{path, content, mode}], cites[], rationale, tests[],
    /// missing_facts[]}`.
    ///
    /// ## Vì sao bản vá phải hiện RA MÃ, không phải hiện số tệp
    ///
    /// Màn này là cổng **G3** — chỗ người duyệt mã do mô hình sinh ra. Bản cũ hiện kế hoạch rất
    /// kỹ rồi dừng: không một dòng mã nào lên màn, dù `code.*` trả `patch` và mockup
    /// `docs/ui/PlanDiff.dc.html` vẽ hẳn một khối diff làm trung tâm. Người dùng được mời duyệt
    /// một thứ họ không nhìn thấy — và "duyệt mà không nhìn" đúng là thói quen mà cả cơ chế cổng
    /// dựng lên để chặn.
    ///
    /// ## `mode` quyết định cách hiện, và phải NÓI RA
    ///
    /// Hợp đồng cho ba `mode`: `diff` là vá từng dòng, `create`/`replace` là **cả tệp**. Hiện
    /// một `replace` như thể nó là diff là nói dối về phạm vi thay đổi: người đọc thấy vài dòng
    /// xanh và tưởng chỉ thêm bấy nhiêu, trong khi cả tệp cũ vừa bị bỏ đi. Nên `replace` hiện
    /// bằng khối mã kèm một câu nói rõ đây là toàn bộ nội dung mới.
    /// Câu nói khi bản vá dài hơn trần hiển thị.
    ///
    /// Khác hẳn câu mặc định. Ở một bảng fact, "cắt bớt cho khỏi treo" là đủ. Ở đây người dùng
    /// đang đứng trước nút Duyệt, và phần bị cắt là mã họ sắp chấp nhận **mà không nhìn thấy** —
    /// nên câu phải nói về việc duyệt, và phải chỉ đường tới chỗ đọc được cả bản vá.
    static let CAT_O_CONG_DUYET =
        "phần còn lại KHÔNG hiện ở đây. Đừng duyệt phần anh chưa đọc: mở tệp trong màn Mã nguồn "
        + "để xem cả bản vá trước khi bấm Duyệt."

    private func _hienBanVa(_ va: [String: Any]) {
        let tep = (va["files"] as? [[String: Any]]) ?? []
        soTep = tep.count

        // `rationale` là bắt buộc trong schema và nó là thứ đáng đọc TRƯỚC mã: nó nói vì sao,
        // còn mã chỉ nói cái gì.
        if let li = va["rationale"] as? String, !li.isEmpty {
            themDong("vì sao (coder)", "", mau: EideToken.Mau.info)
            noiRong(li)
        }

        // `missing_facts` lên trước mã: mã trích dẫn một fact KHÔNG CÓ là mã dựa trên phỏng
        // đoán, và đó là điều cần biết trước khi đọc một dòng nào của nó.
        let thieuFact = (va["missing_facts"] as? [String]) ?? []
        if !thieuFact.isEmpty {
            themDong("mã cần fact CHƯA CÓ (\(thieuFact.count))",
                     thieuFact.prefix(8).joined(separator: ", "), mau: EideToken.Mau.bad)
        }
        let trich = (va["cites"] as? [String]) ?? []
        themDong("trích dẫn", trich.isEmpty
                 ? "KHÔNG trích dẫn fact nào — constant-guard sẽ chặn ở G-FACT"
                 : "\(trich.count) fact: " + trich.prefix(6).joined(separator: ", "),
                 mau: trich.isEmpty ? EideToken.Mau.warn : EideToken.Mau.muted)
        if let kt = va["tests"] as? [String], !kt.isEmpty {
            themDong("test kèm theo", kt.joined(separator: ", "))
        }

        soTepThayCaTep = 0
        for f in tep {
            let duong = (f["path"] as? String) ?? "(không rõ tệp)"
            let noi = (f["content"] as? String) ?? ""
            let cheDo = (f["mode"] as? String) ?? "diff"
            if cheDo == "diff" {
                themDong(duong, _tomTatDiff(noi), mau: EideToken.Mau.info)
                themDiff(noi, viSaoCat: Self.CAT_O_CONG_DUYET)
            } else {
                soTepThayCaTep += 1
                let soDongMoi = noi.isEmpty ? 0 : noi.components(separatedBy: .newlines).count
                themDong(duong,
                         cheDo == "create"
                            ? "TỆP MỚI · \(soDongMoi) dòng"
                            : "THAY CẢ TỆP · \(soDongMoi) dòng — đây không phải vá từng dòng, "
                              + "toàn bộ nội dung cũ bị bỏ đi",
                         mau: cheDo == "create" ? EideToken.Mau.ok : EideToken.Mau.warn)
                themMa(dong: noi.components(separatedBy: .newlines).enumerated().map {
                    EideDongMa(so: $0.offset + 1, chu: $0.element)
                }, viSaoCat: Self.CAT_O_CONG_DUYET)
            }
        }
    }

    /// `+12 −3` — đếm dòng thêm/bớt của một unified diff.
    ///
    /// Bỏ qua `+++`/`---` của phần đầu: chúng bắt đầu bằng `+`/`-` nhưng là tên tệp, và đếm
    /// chúng làm mọi bản vá một-tệp đều dư ra đúng một dòng thêm và một dòng bớt.
    private func _tomTatDiff(_ d: String) -> String {
        var them = 0, bot = 0
        for dòng in d.components(separatedBy: .newlines) {
            if dòng.hasPrefix("+++") || dòng.hasPrefix("---") { continue }
            if dòng.hasPrefix("+") { them += 1 }
            else if dòng.hasPrefix("-") { bot += 1 }
        }
        return "+\(them) −\(bot)"
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
        soTepMa = 0; soDongCoFact = 0; _phanQuyetCuoi = nil

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
        _phanQuyetCuoi = phanQuyet.isEmpty ? nil : (biChan, soViPham)

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
        // MÃ CÓ CHÚ THÍCH FACT — bốn vùng cuối của mockup `Code.dc.html`.
        _hienMaCoFact(ketQua, viPham: vp)

        if soDong == 0 && soTepMa == 0 {
            noiRong("Không có vi phạm, không có báo cáo công cụ nào để hiện.")
        }
    }

    /// Số tệp đang hiện mã — cho test và cho `capNhat` biết màn có rỗng thật không.
    public private(set) var soTepMa = 0
    /// Số dòng mang chú thích fact trong tệp đang hiện.
    public private(set) var soDongCoFact = 0

    /// Người bấm một dòng mang fact: `(fact_id)` — panel mở `passport.query`.
    public var onXemFact: ((String) -> Void)?

    /// Mã nguồn kèm chú thích fact ở lề, thanh đầu tệp, và dải cổng công cụ.
    ///
    /// ## Vì sao chú thích fact phải nằm Ở LỀ, không nằm trong một danh sách bên dưới
    ///
    /// Luận điểm của cả đề án là **mọi hằng số phần cứng trong mã truy được về một fact đã
    /// duyệt**. Một danh sách "tệp này trích 7 fact" đặt dưới khối mã chứng minh được con số ấy
    /// và không chứng minh được điều quan trọng hơn: *dòng NÀY dựa trên fact NÀO*. Người đọc mã
    /// nhìn `#define BME280_ADDR 0x76u` và câu hỏi của họ là "0x76 ở đâu ra" — câu trả lời phải
    /// nằm ngay cạnh con số, không nằm cách đó ba mươi dòng.
    ///
    /// Đọc tệp TỪ ĐĨA chứ không chờ một năng lực trả nội dung: `code.constant_guard` trả
    /// `{file, line, literal, reason}` — nó nói dòng nào sai mà không nói dòng ấy viết gì. Panel
    /// chạy trên cùng máy với dự án, nên đọc thẳng là đường ngắn nhất và không thêm một năng lực
    /// nào chỉ để làm việc mà hệ tệp đã làm.
    private func _hienMaCoFact(_ ketQua: [String: Any], viPham: [[String: Any]]) {
        soTepMa = 0
        soDongCoFact = 0

        // Tệp nào: `path` nếu có, nếu không thì tệp của vi phạm ĐẦU TIÊN — đó là tệp người dùng
        // đang cần nhìn.
        let duong = (ketQua["path"] as? String) ?? (ketQua["file"] as? String)
            ?? (viPham.first?["file"] as? String) ?? tepDangXem ?? ""
        guard !duong.isEmpty else { return }
        let day = _duongDayDu(duong, ketQua: ketQua)
        guard let noi = try? String(contentsOfFile: day, encoding: .utf8) else {
            themDong(EideKnowledgeFormat.tenNgan(duong),
                     "không đọc được tệp để hiện mã — kiểm đường dẫn", mau: EideToken.Mau.warn)
            return
        }

        let dongVP = Set(viPham.filter {
            ((($0["file"] as? String) ?? "") as NSString).lastPathComponent
                == (duong as NSString).lastPathComponent
        }.compactMap { EideSo.nguyen($0["line"]) })

        let dong = noi.components(separatedBy: .newlines)
        var factTheoDong: [Int: String] = [:]
        for (i, d) in dong.enumerated() {
            if let f = Self.factTrongDong(d) {
                factTheoDong[i + 1] = f.mo
                soDongCoFact += 1
            }
        }

        // THANH ĐẦU TỆP — mockup vẽ `driver_bme280.c · armv7e-m · 118 dòng · constant-guard:
        // 1 vi phạm`. Kiến trúc lấy từ kết quả khi có; KHÔNG đoán từ đuôi tệp.
        var dau: [String] = ["\(dong.count) dòng"]
        if let a = (ketQua["arch"] as? String) ?? (ketQua["isa"] as? String) { dau.append(a) }
        dau.append("\(soDongCoFact) dòng có fact")
        // Đếm DÒNG, và nói rõ là dòng.
        //
        // Một dòng có thể chứa nhiều hằng số vi phạm: `i2c_write8(ADDR, 0xF5u, 0x27u, …)` là hai
        // vi phạm trên một dòng. Viết "4 vi phạm" trong khi danh sách ngay trên có 5 dòng là một
        // mâu thuẫn người đọc thấy ngay, và nó làm họ nghi ngờ cả hai con số. Lề đánh dấu theo
        // DÒNG, nên thanh đầu tệp cũng phải nói theo dòng.
        dau.append(dongVP.isEmpty ? "constant-guard: sạch"
                                  : "constant-guard: \(dongVP.count) dòng vi phạm")
        themDong((duong as NSString).lastPathComponent, dau.joined(separator: " · "),
                 mau: dongVP.isEmpty ? EideToken.Mau.info : EideToken.Mau.bad)

        themMa(dong: dong.enumerated().map { i, d in
            EideDongMa(so: i + 1, chu: d, fact: factTheoDong[i + 1], viPham: dongVP.contains(i + 1))
        }, chonDong: { [weak self] so in
            guard let f = Self.factTrongDong(dong.indices.contains(so - 1) ? dong[so - 1] : "")
            else { return }
            self?.onXemFact?(f.id)
        })
        soTepMa = 1
    }

    /// Đường dẫn đầy đủ của tệp: `code.*` trả đường TƯƠNG ĐỐI so với gốc dự án.
    private func _duongDayDu(_ duong: String, ketQua: [String: Any]) -> String {
        if duong.hasPrefix("/") { return duong }
        let goc = (ketQua["project_dir"] as? String) ?? duAnHienTai ?? ""
        return goc.isEmpty ? duong : (goc as NSString).appendingPathComponent(duong)
    }

    /// Thư mục dự án — panel đặt vào để màn dựng được đường dẫn đầy đủ.
    public var duAnHienTai: String?

    /// Tệp người dùng đang xem — bên gọi đặt vào TRƯỚC khi chạy một năng lực `code.*`.
    ///
    /// Cần thiết vì kết quả không phải lúc nào cũng nói tệp nào: `code.constant_guard` trả
    /// `{verdict, violations}`, và khi mã SẠCH thì `violations` rỗng — tức đúng lúc mọi thứ tốt
    /// thì màn lại không biết hiện tệp nào. Người gọi thì luôn biết: họ vừa chọn tệp ấy.
    public var tepDangXem: String?

    /// Chú thích fact trong một dòng mã: `/* eide:fact f_b1c2 BME280 addr 0x76 */`.
    ///
    /// Nhận cả `hkw:fact` — mockup UXD-13 viết bằng tiền tố cũ của dự án, và mã sinh ra trước
    /// khi đổi tên vẫn nằm trong các dự án đang có. Bỏ qua tiền tố cũ nghĩa là chú thích biến
    /// mất khỏi lề đúng ở những tệp lâu đời nhất.
    static func factTrongDong(_ d: String) -> (id: String, mo: String)? {
        for khoa in ["eide:fact", "hkw:fact"] {
            guard let r = d.range(of: khoa) else { continue }
            let sau = d[r.upperBound...].drop { $0 == " " || $0 == ":" }
            let id = String(sau.prefix { !$0.isWhitespace })
            // Id phải TRÔNG NHƯ một id. `/* eide:fact */` không có id, và phép lấy "từ kế tiếp"
            // ngây thơ trả về `*/` — một fact tên `*/` sẽ đi thẳng vào `passport.query` khi
            // người dùng bấm vào dòng ấy. Chú thích viết dở là chuyện thường; biến nó thành một
            // lời gọi vô nghĩa thì không.
            guard !id.isEmpty, let dau = id.first,
                  dau.isLetter || dau == "_",
                  id.allSatisfy({ $0.isLetter || $0.isNumber || "_-.:".contains($0) })
            else { continue }
            var mo = String(sau.dropFirst(id.count))
            for cat in ["*/", "*)", "-->"] {
                if let c = mo.range(of: cat) { mo = String(mo[..<c.lowerBound]) }
            }
            mo = mo.trimmingCharacters(in: .whitespaces)
            return (id, mo.isEmpty ? id : "\(id) — \(mo)")
        }
        return nil
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
        // DẢI CỔNG CÔNG CỤ — mockup `Code.dc.html` đặt `build 3,1 s · size Flash 38% · static 0
        // vi phạm · host-test 12/12 · constant-guard 1 vi phạm` thành MỘT dòng đáy.
        //
        // Ngang chứ không dọc là chủ ý: năm con số ấy là thứ người ta LIẾC chứ không đọc, và xếp
        // dọc thì chúng chiếm năm dòng của vùng đọc mã. Bản cũ dựng mỗi số một dòng `nhãn: giá
        // trị`, nên một lượt dựng đầy đủ đẩy khối mã xuống dưới màn hình.
        _hienDaiCong(r)
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

    /// Dải ngang: tên công cụ, đạt/không, thời gian, và các phần trăm bộ nhớ.
    private func _hienDaiCong(_ r: [String: Any]) {
        var o: [EideDaiTrangThai.O] = []
        let cong = (r["tool"] as? String) ?? "công cụ"
        if let dat = r["passed"] as? Bool {
            o.append(.init(cong, dat ? "đạt" : "KHÔNG ĐẠT",
                           mau: dat ? EideToken.Mau.ok : EideToken.Mau.bad))
        }
        if let ms = EideSo.nguyen(r["duration_ms"]) {
            o.append(.init("thời gian", String(format: "%.1f s", Double(ms) / 1000)))
        }
        let m = (r["metrics"] as? [String: Any]) ?? [:]
        for k in ["flash_pct", "ram_pct"] {
            guard let so = EideSo.thuc(m[k]) else { continue }
            let ti = so > 1 ? so / 100 : so
            o.append(.init(k == "flash_pct" ? "Flash" : "RAM",
                           String(format: "%.0f%%", ti * 100),
                           mau: ti >= Self.nguongChatBoNho ? EideToken.Mau.warn : nil))
        }
        // `constant-guard` vào dải CẢ KHI đạt: cổng im lặng lúc đạt là cổng người ta quên mất là
        // có, và quên rồi thì một lần `block` trông như một lỗi lạ chứ không như một cổng.
        if let pq = _phanQuyetCuoi {
            o.append(.init("constant-guard", pq.chan ? "\(pq.so) vi phạm — CHẶN" : "sạch",
                           mau: pq.chan ? EideToken.Mau.bad : EideToken.Mau.ok))
        }
        guard !o.isEmpty else { return }
        themDaiTrangThai(o)
    }

    /// Phán quyết constant-guard của lượt cập nhật hiện tại — để dải cổng nói về nó.
    private var _phanQuyetCuoi: (chan: Bool, so: Int)?

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
                let tt = (e["status"] as? String) ?? "?"
                let ly = (e["reason"] as? String) ?? ""
                let mau: NSColor = tt == "passed" ? EideToken.Mau.ok
                    : (tt == "unverified" ? EideToken.Mau.warn : EideToken.Mau.bad)
                themDong(Self.tenKyVong(e),
                         "\(_tenTrangThai(tt))\(ly.isEmpty ? "" : " — \(ly)")", mau: mau)
            }

            _hienBatDuoc(r)
        }

        if !bang.isEmpty { _hienBangQuet(bang, totNhat: totNhat) }

        if let b = totNhat, bang.isEmpty {
            let mo = b.keys.sorted().map { "\($0)=\(EideKnowledgeFormat.giaTri(b[$0]))" }
            themDong("tốt nhất", mo.joined(separator: " · "), mau: EideToken.Mau.ok)
        }

        if let sosanh = ketQua["diff"] as? [String: Any] { _hienSoSanhHil(sosanh, ketQua) }

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

    /// `sim.sweep` `{table[], best}` — một BẢNG, và bản cũ dựng nó thành câu.
    ///
    /// Mỗi hàng ra một dòng `quét a=1 · b=2 · c=3`. Quét tham số là việc SO SÁNH các hàng với
    /// nhau để tìm cấu hình tốt nhất; xếp thành câu thì cùng một tham số nằm ở vị trí khác nhau
    /// trên mỗi dòng tuỳ độ dài giá trị trước nó, và mắt không quét dọc được. Đúng lý do vì sao
    /// màn Hộ chiếu cũng phải bỏ cách dựng ấy.
    ///
    /// Hàng `best` được tô, không tách ra một dòng riêng: tách ra thì người đọc phải tự tìm nó
    /// trong bảng để xem nó hơn các hàng khác ở chỗ nào — mà đó chính là câu hỏi.
    private func _hienBangQuet(_ bang: [[String: Any]], totNhat: [String: Any]?) {
        // Cột = HỢP các khoá của mọi hàng. Lấy khoá của hàng đầu thì một tham số chỉ xuất hiện
        // từ hàng thứ hai trở đi sẽ biến mất khỏi bảng mà không ai biết.
        var cot: [String] = []
        for h in bang {
            for k in h.keys.sorted() where !cot.contains(k) { cot.append(k) }
        }
        guard !cot.isEmpty else { return }

        func la(_ h: [String: Any]) -> Bool {
            guard let b = totNhat, !b.isEmpty else { return false }
            return b.allSatisfy { k, v in
                EideKnowledgeFormat.giaTri(h[k]) == EideKnowledgeFormat.giaTri(v)
            }
        }
        let iTot = bang.firstIndex(where: la)
        themDong("quét tham số", "\(bang.count) cấu hình"
                 + (iTot != nil ? " · hàng tô xanh là tốt nhất" : ""),
                 mau: EideToken.Mau.info)
        themBang(cot: cot,
                 hang: bang.map { h in cot.map { EideKnowledgeFormat.giaTri(h[$0]) } },
                 canPhai: Set(cot.indices.filter { i in
                     bang.allSatisfy { Double(EideKnowledgeFormat.giaTri($0[cot[i]])) != nil }
                 }),
                 mauO: { h, _ in h == iTot ? EideToken.Mau.ok : nil })
    }

    /// `sim.compare_hil` `{diff, proposals}` — bảng SIL ↔ HIL của mockup `Sim.dc.html`.
    ///
    /// **Lệch giữa SIL và HIL là tin quan trọng nhất màn này mang.** Nó nói mô hình mô phỏng sai
    /// ở đâu so với board thật, và mọi kết luận rút từ SIL về sau đều đứng trên chỗ lệch ấy.
    /// Hợp đồng để `diff` là `object` tự do, nên đọc cả hai hình dạng hay gặp: `{chỉ số: {sil,
    /// hil, verdict}}` và `{chỉ số: [sil, hil]}`.
    private func _hienSoSanhHil(_ diff: [String: Any], _ ketQua: [String: Any]) {
        var hang: [[String]] = []
        for (ten, v) in diff.sorted(by: { $0.key < $1.key }) {
            if let m = v as? [String: Any] {
                hang.append([ten,
                             EideKnowledgeFormat.giaTri(m["sil"] ?? m["SIL"]),
                             EideKnowledgeFormat.giaTri(m["hil"] ?? m["HIL"]),
                             (m["verdict"] as? String) ?? (m["status"] as? String) ?? ""])
            } else if let a = v as? [Any], a.count >= 2 {
                hang.append([ten, EideKnowledgeFormat.giaTri(a[0]),
                             EideKnowledgeFormat.giaTri(a[1]), ""])
            } else {
                // Hình dạng lạ: hiện NGUYÊN giá trị vào cột chênh lệch thay vì bỏ hàng đi. Một
                // chỉ số lệch bị nuốt vì hợp đồng không nói rõ hình dạng là đúng thứ tệ nhất.
                hang.append([ten, "", "", EideKnowledgeFormat.giaTri(v)])
            }
        }
        guard !hang.isEmpty else { return }
        themDong("so sánh SIL ↔ HIL", "\(hang.count) chỉ số", mau: EideToken.Mau.warn)
        themBang(cot: ["chỉ số", "SIL", "HIL", "kết luận"], hang: hang, canPhai: [1, 2])

        // `proposals` là đề xuất SỬA MÔ HÌNH, và nó chờ người duyệt — nói rõ điều đó, vì một đề
        // xuất trông như một kết luận sẽ được đọc như việc đã rồi.
        let de = (ketQua["proposals"] as? [String]) ?? []
        for d in de {
            themDong("đề xuất (chờ duyệt)", d, mau: EideToken.Mau.warn)
        }
    }

    private func _hienBatDuoc(_ r: [String: Any]) {
        guard let b = (r["captured"] as? [String: Any])
            ?? ((r["metrics"] as? [String: Any])?["captured"] as? [String: Any]) else { return }
        if let uart = b["uart"] as? [Any], !uart.isEmpty {
            // LOG ĐẦY ĐỦ, phông đơn cách, có số dòng — mockup `Sim.dc.html` vẽ hẳn một khung
            // console cho nó. Bản cũ hiện 5 dòng đầu rồi thôi, và 5 dòng đầu của một log
            // firmware là phần khởi động: đúng phần KHÔNG bao giờ chứa lý do hỏng. Thứ người ta
            // đọc log để tìm nằm ở cuối, hoặc ở giữa, hoặc ở dòng ngay trước khi nó im.
            themDong("UART bắt được", "\(uart.count) dòng", mau: EideToken.Mau.info)
            themMa(dong: uart.enumerated().map {
                EideDongMa(so: $0.offset + 1, chu: EideKnowledgeFormat.giaTri($0.element))
            })
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

    /// Tên người đọc được của một dòng `expect`.
    ///
    /// Hợp đồng SIM-05 để `expect[]` là mảng object tự do, và hình dạng THẬT của engine qemu là
    /// `{kind, pattern, within_s, status, matched}` — không có `expect` lẫn `name`. Bản cũ hỏi
    /// đúng hai khoá ấy rồi rơi về `"?"`, nên màn hiện sáu dòng `?  đạt`: người dùng biết có sáu
    /// kỳ vọng và không biết kỳ vọng nào. Đo 16/09/2026 trên luồng AVR.
    ///
    /// Dựng tên từ thứ CÓ: `uart "EIDE: atmega328p"` nói đủ cả loại kênh lẫn điều đang chờ.
    static func tenKyVong(_ e: [String: Any]) -> String {
        if let t = (e["expect"] as? String) ?? (e["name"] as? String), !t.isEmpty { return t }
        let loai = (e["kind"] as? String) ?? ""
        let mau = (e["pattern"] as? String) ?? (e["value"] as? String) ?? ""
        if !loai.isEmpty || !mau.isEmpty {
            return [loai, mau.isEmpty ? "" : "\"\(mau)\""]
                .filter { !$0.isEmpty }.joined(separator: " ")
        }
        // Không khoá nào quen: hiện NGUYÊN các trường còn lại thay vì "?". Một dòng khó đọc vẫn
        // hơn một dòng không nói gì — và nó chỉ ra đúng khoá mà hàm này còn thiếu.
        let bo: Set<String> = ["status", "reason", "matched"]
        let con = e.filter { !bo.contains($0.key) }
        return con.isEmpty ? "(kỳ vọng không tên)"
            : con.map { "\($0.key)=\(EideKnowledgeFormat.giaTri($0.value))" }
                .sorted().joined(separator: " · ")
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
