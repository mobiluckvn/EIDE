import AppKit

/// Nửa **bản đồ** của màn 7 — UXD-13 "Graph → RagAsk (Bản đồ tri thức & hỏi đáp)".
///
/// Spec: CDS-12 VIEW-01 `kg_map`, VIEW-02 `kg_focus`, VIEW-04 `conflict_board`,
/// VIEW-05 `coverage_map`, VIEW-06 `impact_map`, VIEW-08 `rag_trace`, VIEW-09 `rag_index`,
/// VIEW-10 `rag_compare`, VIEW-11 `doc_side_by_side`, VIEW-12 `timeline`;
/// KAD-07 (tầng tri thức, tầng tin cậy); UXD-13 U2, U9.
///
/// ## Vì sao một khung nhìn thứ hai cho cùng một màn
///
/// Tên màn có hai vế, và chúng trả lời hai câu hỏi khác nhau: *"cho tôi biết điều này"*
/// (`RagAskView`) và *"cho tôi thấy tri thức đang có hình gì"* (khung nhìn này). Mười năng lực
/// `view.*` thuộc vế thứ hai, và trước hôm nay **không cái nào hiện được** — người dùng gõ
/// `/view.coverage_map`, năng lực chạy xong, và màn hỏi đáp kết luận "Không tìm thấy gì trong
/// tri thức của dự án".
///
/// ## Bất biến: bản đồ phải nói ra chỗ TRỐNG, không chỉ chỗ có
///
/// Một bản đồ tri thức đẹp đẽ với 13.494 fact vẫn có thể thiếu đúng thanh ghi người ta cần.
/// `coverage_map` tồn tại chính vì thế, và nó là năng lực đáng hiện nhất trong mười cái: nó
/// đếm `registers_total` bên cạnh `with_facts`, tức nó biết phần mình KHÔNG biết. Khung nhìn
/// này đưa tỉ lệ phủ lên tiêu đề thay vì đưa tổng số fact — tổng số fact là con số dễ làm
/// người ta yên tâm mà không nói được điều gì.
public final class KgMapView: ManHinhCoSo {

    /// (node_id) — bấm một nút để mở bản đồ lân cận (`view.kg_focus`).
    public var onMoNut: ((String) -> Void)?
    /// (conflict_id) — mở một mâu thuẫn để duyệt.
    public var onMoXungDot: ((String) -> Void)?

    public private(set) var soNut = 0
    public private(set) var soCanh = 0
    public private(set) var soXungDot = 0
    public private(set) var soSuKien = 0
    /// Tỉ lệ thanh ghi đã có fact, `nil` nếu chưa chạy `view.coverage_map`.
    public private(set) var tiLePhu: Double?
    /// Số ngoại vi chưa có fact nào — xem `capNhat`.
    public private(set) var soNgoaiViTrong = 0

    /// Dưới mức này thì một ngoại vi coi như chưa dùng được: quá nửa thanh ghi chưa có fact,
    /// và mã sinh ra cho nó sẽ phải đoán. Ngưỡng của khung nhìn, không phải của hợp đồng —
    /// `coverage_map` trả số thô và để người đọc tự xét.
    public static let nguongPhuYeu = 0.5

    public init() { super.init(ten: "Bản đồ tri thức") }

    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soNut = 0; soCanh = 0; soXungDot = 0; soSuKien = 0
        tiLePhu = nil; soNgoaiViTrong = 0; soNutTrenCay = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa dựng bản đồ — `/view.kg_map` (toàn dự án), `/view.coverage_map` "
                  + "(độ phủ), `/view.conflict_board` (mâu thuẫn) hoặc `/view.timeline`.")
            return
        }

        let do_ = ketQua["graph"] as? [String: Any]
        let duong = (ketQua["paths_to_sources"] as? [[String]]) ?? []
        let hang = (ketQua["rows"] as? [[String: Any]]) ?? []
        let nhiet = ketQua["heatmap"] as? [String: Any]
        let sk = (ketQua["events"] as? [[String: Any]]) ?? []
        let doan = ketQua["chunks"]
        let diem = ketQua["scores"] as? [String: Any]
        let loi = (ketQua["graph_path"] as? [String]) ?? []
        let soSanh = (ketQua["comparison"] as? [[String: Any]]) ?? []
        let trai = ketQua["left"] as? [String: Any]
        let phai = ketQua["right"] as? [String: Any]
        let trangThai = ketQua["status"] as? [String: Any]

        var d: [String] = []

        // ĐẾM trước, VẼ sau. Tóm tắt cần mọi con số, còn thân màn có thứ tự riêng: mâu thuẫn
        // lên đầu vì chúng là thứ duy nhất ở màn này CHẶN việc, rồi mới tới đồ thị.
        let nodes = ((do_?["nodes"]) as? [[String: Any]]) ?? []
        if let g = do_ {
            soNut = nodes.count
            soCanh = ((g["edges"] as? [[String: Any]]) ?? []).count
            d.append("\(soNut) nút · \(soCanh) liên kết")
        }

        if let h = nhiet { d.append(contentsOf: _hienDoPhuDem(h)) }
        if !hang.isEmpty {
            soXungDot = hang.count
            d.append("\(soXungDot) MÂU THUẪN")
        }
        if !sk.isEmpty { soSuKien = sk.count; d.append("\(soSuKien) mốc") }
        if let n = EideSo.nguyen(doan) { d.append("\(n) đoạn đã lập chỉ mục") }
        if !soSanh.isEmpty { d.append("so \(soSanh.count) nguồn") }

        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (soXungDot > 0 || soNgoaiViTrong > 0)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        // Mâu thuẫn lên đầu phần thân: chúng là thứ duy nhất ở màn này CHẶN việc.
        for r in hang {
            let cid = (r["conflict_id"] as? String) ?? ""
            let ve = (r["subject"] as? String) ?? "?"
            let a = EideKnowledgeFormat.giaTri(r["a"])
            let b = EideKnowledgeFormat.giaTri(r["b"])
            let tang = ((r["tiers"] as? [Any]) ?? []).map { EideKnowledgeFormat.giaTri($0) }
                .joined(separator: " vs ")
            themDong(EideKnowledgeFormat.tenNgan(ve),
                     "\(a) ⟷ \(b)" + (tang.isEmpty ? "" : " · \(tang)"),
                     mau: EideToken.Mau.bad,
                     nut: !cid.isEmpty, ma: cid, bam: #selector(moXungDot(_:)))
        }

        if let h = nhiet { _hienDoPhu(h) }
        if let g = do_ {
            _hienDoThi(nodes, canh: (g["edges"] as? [[String: Any]]) ?? [])
        }

        for p in duong.prefix(10) {
            // VIEW-02 trả ĐƯỜNG ĐI tới nguồn — đó là câu trả lời cho "vì sao tin fact này",
            // và nó chỉ có nghĩa khi hiện cả chuỗi chứ không hiện mỗi điểm cuối.
            themDong("đường tới nguồn", p.joined(separator: " → "), mau: EideToken.Mau.info)
        }

        if let s = diem, let c = doan as? [[String: Any]] {
            _hienVetTruyHoi(c, diem: s, loi: loi)
        } else if !loi.isEmpty {
            themDong("đường đi trong đồ thị", loi.joined(separator: " → "),
                     mau: EideToken.Mau.info)
        }

        for c in soSanh {
            let nguon = (c["source"] as? String) ?? (c["tier"] as? String) ?? "?"
            let cau = (c["answer"] as? String) ?? ""
            let khac = ((c["differences"] as? [Any]) ?? []).count
            themDong(nguon, cau + (khac > 0 ? "  ⚠︎ \(khac) điểm khác" : ""),
                     mau: khac > 0 ? EideToken.Mau.warn : nil)
        }

        if let t = trai, let ph = phai { _hienCanhNhau(t, ph) }

        if !sk.isEmpty { _hienDongThoiGian(sk) }

        if let s = trangThai {
            for (k, v) in s.sorted(by: { $0.key < $1.key }) {
                themDong("chỉ mục \(k)", EideKnowledgeFormat.giaTri(v))
            }
        }

        if soDong == 0 {
            noiRong("Bản đồ dựng xong nhưng chưa có nút nào — dự án chưa có fact.")
        }
    }

    /// Nút của đồ thị, **nhóm theo tầng tin cậy**.
    ///
    /// Một danh sách 500 nút phẳng thì không ai đọc. Nhóm theo `tier` là cách nhóm duy nhất
    /// trả lời được câu người dùng thật sự hỏi: *bao nhiêu phần tri thức này đáng tin?*
    /// Đồ thị dựng thành CÂY theo cạnh, kèm một dòng đếm theo tầng.
    ///
    /// ## Vì sao bản cũ sai
    ///
    /// Nó nhóm nút theo tầng rồi liệt kê phẳng — và **không hiện một cạnh nào**, dù `soCanh` đếm
    /// chúng ngay dòng trên. Với dữ liệu thật của dự án demo: 17 nút, 26 cạnh, và cả 26 cạnh
    /// biến mất. Nhưng cạnh CHÍNH LÀ tri thức ở màn này: `chip → HAS → mem:SRAM`,
    /// `f_10ef… → CITES → src_ee2e…`. Một danh sách nút không cạnh trả lời được câu "có bao
    /// nhiêu" và không trả lời được câu duy nhất người ta mở màn này để hỏi — *cái này nối với
    /// cái gì, và vì sao ta tin nó*.
    ///
    /// ## Gốc là nút KHÔNG AI TRỎ TỚI
    ///
    /// Đúng hình dạng mockup `docs/ui/Graph.dc.html` vẽ: `chip:st.stm32f411` trên cùng, rồi
    /// `periph:I2C1`, `reg:CR1`, `field:ACK`. Quan hệ (`HAS`, `CITES`, `ABOUT`, `SUPERSEDES`)
    /// hiện làm dấu bên phải tên con, vì trong một cây thì cạnh không vẽ được thành mũi tên.
    /// `view.timeline` `{events[]}` — dòng thời gian thành BẢNG.
    ///
    /// Bản cũ dựng 40 mốc đầu thành 40 dòng nhãn rồi ghi "… và 271 mốc nữa". Ba thứ mất:
    ///
    /// 1. **Sắp xếp.** "Chuyện gì xảy ra gần nhất", "ai làm nhiều nhất", "loại sự kiện nào
    ///    nhiều" — một cú bấm tiêu đề cột. Với 311 mốc thì không ai đọc hết để tự thấy.
    /// 2. **Cột `ai`.** Sổ cái ghi `by: human | agent` cho MỌI bản ghi, và câu hỏi trung tâm của
    ///    một công cụ tác tử là *cái này do tôi hay do nó làm*. Bản cũ không hiện cột ấy.
    /// 3. **271 mốc bị cắt** — và phần bị cắt là phần CŨ, tức phần chứa lý do một thứ hôm nay
    ///    đang sai. Trần 2.000 hàng của `themBang` rộng hơn hẳn 40.
    private func _hienDongThoiGian(_ sk: [[String: Any]]) {
        themDong("dòng thời gian", "\(sk.count) mốc", mau: EideToken.Mau.info)
        themBang(cot: ["lúc", "loại", "ai", "chi tiết"],
                 hang: sk.map { e in
                     [Self.gioNgan((e["at"] as? String) ?? ""),
                      (e["kind"] as? String) ?? (e["type"] as? String) ?? "?",
                      (e["by"] as? String) ?? (e["actor"] as? String) ?? "",
                      Self.moTaMoc(e)]
                 },
                 mauO: { i, cot in
                     guard cot == 2, i < sk.count else { return nil }
                     // Việc do TÁC TỬ tự làm tô khác việc do người làm. Đây là cột người ta quét
                     // dọc để tìm "nó đã tự làm gì" — màu làm việc ấy nhanh hơn đọc.
                     return ((sk[i]["by"] as? String) ?? "") == "agent"
                         ? EideToken.Mau.warn : EideToken.Mau.muted
                 })
    }

    /// `2026-09-15T04:55:11.482439+00:00` → `04:55:11`.
    ///
    /// Ngày đầy đủ chiếm một phần ba bề rộng bảng để nói một điều gần như luôn giống nhau trên
    /// mọi hàng. Chuỗi không đọc được thì trả NGUYÊN — cắt bừa một chuỗi lạ sẽ giấu mất chính
    /// dấu hiệu rằng mốc thời gian ấy hỏng.
    static func gioNgan(_ s: String) -> String {
        guard let t = s.firstIndex(of: "T") else { return s }
        let sau = s[s.index(after: t)...]
        let gio = sau.prefix(8)
        return gio.count == 8 && gio.filter({ $0 == ":" }).count == 2 ? String(gio) : s
    }

    /// Một câu ngắn cho `data` của mốc — mỗi loại sự kiện có trường đáng đọc riêng.
    static func moTaMoc(_ e: [String: Any]) -> String {
        if let t = (e["detail"] as? String) ?? (e["subject"] as? String) { return t }
        guard let d = e["data"] as? [String: Any], !d.isEmpty else { return "" }
        // `cap` trước tiên: với `cap.run.*` — loại sự kiện đông nhất — nó là thứ duy nhất đáng
        // đọc, và nó là thứ từng THIẾU (lỗi im lặng số 33).
        if let c = d["cap"] as? String {
            let them = (d["decision"] as? [String: Any])?["decision"] as? String
            return them.map { "\(c) · \($0)" } ?? c
        }
        let bo: Set<String> = ["args_hash", "prev_hash", "hash"]
        return d.filter { !bo.contains($0.key) }
            .map { "\($0.key)=\(EideKnowledgeFormat.giaTri($0.value))" }
            .sorted().prefix(3).joined(separator: " · ")
    }

    private func _hienDoThi(_ nodes: [[String: Any]], canh: [[String: Any]]) {
        let theoId = Dictionary(nodes.map { (($0["id"] as? String) ?? "", $0) },
                                uniquingKeysWith: { a, _ in a })

        // Cạnh TRÙNG phải bỏ: `view.kg_map` trả `chip → HAS → mem:SRAM` hai lần trên dữ liệu
        // thật (một lần cho mỗi fact về cùng chủ thể), và không bỏ thì cây hiện cùng một con hai
        // lần — người đọc sẽ tưởng có hai vùng nhớ tên SRAM.
        var daCo = Set<String>()
        var con: [String: [(id: String, quanHe: String)]] = [:]
        var coCha = Set<String>()
        for e in canh {
            let tu = (e["from"] as? String) ?? (e["source"] as? String) ?? ""
            let toi = (e["to"] as? String) ?? (e["target"] as? String) ?? ""
            let qh = (e["type"] as? String) ?? (e["kind"] as? String) ?? ""
            guard !tu.isEmpty, !toi.isEmpty, daCo.insert("\(tu)|\(qh)|\(toi)").inserted else {
                continue
            }
            con[tu, default: []].append((toi, qh))
            coCha.insert(toi)
        }

        let tang = Dictionary(grouping: nodes, by: { ($0["tier"] as? String) ?? "—" })
        for (t, ds) in tang.sorted(by: { _thuTuTang($0.key) < _thuTuTang($1.key) }) {
            let xau = ds.filter { (($0["status"] as? String) ?? "") == "conflict" }.count
            themDong(EideKnowledgeFormat.nhanTang(t, ""),
                     "\(ds.count) nút" + (xau > 0 ? " · \(xau) đang mâu thuẫn" : ""),
                     mau: xau > 0 ? EideToken.Mau.bad : EideKnowledgeFormat.mauTang(t, ""))
        }

        var goc = nodes.compactMap { $0["id"] as? String }.filter { !coCha.contains($0) }
        // Đồ thị toàn chu trình thì KHÔNG nút nào có bậc vào 0, và cây sẽ rỗng. Lấy nút đầu làm
        // gốc chứ không im lặng trả về một màn trống — một màn trống ở đây đọc như "dự án chưa
        // có tri thức", câu sai nguy hiểm nhất màn này nói được.
        if goc.isEmpty, let dau = nodes.first?["id"] as? String { goc = [dau] }

        var daVe = Set<String>()
        var dung = 0
        func nut(_ id: String, quanHe: String, duongDi: Set<String>) -> EideNutCay {
            let n = theoId[id]
            let nhan = (n?["label"] as? String) ?? EideKnowledgeFormat.tenNgan(id)
            let xungDot = ((n?["status"] as? String) ?? "") == "conflict"
            daVe.insert(id)
            dung += 1

            var cc: [EideNutCay] = []
            // `duongDi` chặn chu trình: `SUPERSEDES` nối fact cũ với fact mới và có thể vòng
            // lại. Không chặn thì cây dựng tới hết bộ nhớ.
            if !duongDi.contains(id), dung < EideTuVung.hangToiDa {
                let tiep = duongDi.union([id])
                for c in (con[id] ?? []).sorted(by: { $0.quanHe < $1.quanHe }) {
                    cc.append(nut(c.id, quanHe: c.quanHe, duongDi: tiep))
                }
            } else if duongDi.contains(id) {
                cc = [EideNutCay(ten: "↻ đã xuất hiện ở trên", duong: "", laThuMuc: false,
                                 dau: "chu trình", mauDau: EideToken.Mau.warn)]
            }
            return EideNutCay(
                ten: nhan, duong: id, laThuMuc: !cc.isEmpty, con: cc,
                dau: [quanHe, (n?["kind"] as? String) ?? ""].filter { !$0.isEmpty }
                    .joined(separator: " · "),
                mauDau: xungDot ? EideToken.Mau.bad
                                : EideKnowledgeFormat.mauTang((n?["tier"] as? String) ?? "", ""),
                moSan: true)
        }

        let cay = goc.sorted().map { nut($0, quanHe: "", duongDi: []) }
        soNutTrenCay = dung
        guard !cay.isEmpty else { return }
        themCay(goc: cay) { [weak self] n in
            guard !n.duong.isEmpty else { return }
            self?.onMoNut?(n.duong)
        }

        // Nút không tới được từ gốc nào vẫn phải hiện ra.
        //
        // Nút CÔ LẬP hoàn toàn (không cạnh nào) thì không rơi vào đây: bậc vào của nó là 0 nên
        // nó thành một GỐC và đã nằm trong cây — đúng như phải thế, vì một fact không ABOUT chủ
        // thể nào và không CITES nguồn nào là fact đáng ngờ nhất trong store. Nhánh này bắt
        // trường hợp còn lại: một cụm toàn chu trình, không nút nào bậc vào 0, nên phép duyệt từ
        // các gốc không bao giờ chạm tới.
        let moCoi = nodes.compactMap { $0["id"] as? String }.filter { !daVe.contains($0) }
        if !moCoi.isEmpty {
            themDong("\(moCoi.count) nút KHÔNG nối vào đâu",
                     moCoi.prefix(6).joined(separator: ", "), mau: EideToken.Mau.warn)
        }
    }

    /// Số HÀNG trên cây — cho test.
    ///
    /// Khác số nút, và khác một cách có chủ ý: đồ thị tri thức là một DAG, nên một nút dùng
    /// chung (`mem:SRAM` vừa là con `HAS` của chip vừa là đích `ABOUT` của mỗi fact) xuất hiện
    /// dưới MỌI cha của nó. Gộp nó lại thành một hàng sẽ giấu mất một trong hai quan hệ — mà
    /// quan hệ mới là thứ màn này hiện ra để nói.
    public private(set) var soNutTrenCay = 0

    private func _thuTuTang(_ t: String) -> Int {
        switch t {
        case "gold": return 0
        case "silver": return 1
        case "bronze": return 2
        default: return 3
        }
    }

    /// `coverage_map`: `periph → {registers_total, with_facts, reviewed, requested}`.
    ///
    /// **Đưa tỉ lệ phủ lên tiêu đề, không đưa tổng số fact.** Tổng số fact là con số dễ làm
    /// người ta yên tâm mà không nói được gì: 13.494 fact vẫn có thể thiếu đúng thanh ghi đang
    /// cần. Tỉ lệ phủ thì nói thẳng phần hệ thống KHÔNG biết.
    private func _dongDoPhu(_ h: [String: Any]) -> [(String, Int, Int, Int, Int)] {
        h.compactMap { ten, v in
            guard let m = v as? [String: Any] else { return nil }
            return (ten,
                    EideSo.nguyen(m["registers_total"]) ?? 0,
                    EideSo.nguyen(m["with_facts"]) ?? 0,
                    EideSo.nguyen(m["reviewed"]) ?? 0,
                    EideSo.nguyen(m["requested"]) ?? 0)
        }
    }

    /// Chỉ ĐẾM, cho dòng tóm tắt.
    private func _hienDoPhuDem(_ h: [String: Any]) -> [String] {
        let dong = _dongDoPhu(h)
        let tong = dong.reduce(0) { $0 + $1.1 }
        let co = dong.reduce(0) { $0 + $1.2 }
        soNgoaiViTrong = dong.filter { $0.1 > 0 && Double($0.2) / Double($0.1) < Self.nguongPhuYeu }
            .count
        guard tong > 0 else { return [] }
        tiLePhu = Double(co) / Double(tong)
        var ra = [String(format: "phủ %.0f%% thanh ghi (%d/%d)", (tiLePhu ?? 0) * 100, co, tong)]
        if soNgoaiViTrong > 0 { ra.append("\(soNgoaiViTrong) NGOẠI VI THIẾU TRI THỨC") }
        return ra
    }

    private func _hienDoPhu(_ h: [String: Any]) {
        // Ngoại vi phủ THẤP lên trước: đó là chỗ mã sinh ra sẽ phải đoán.
        for (ten, t, c, dd, yc) in _dongDoPhu(h).sorted(by: {
            (Double($0.2) / Double(max($0.1, 1))) < (Double($1.2) / Double(max($1.1, 1)))
        }) {
            let ti = Double(c) / Double(max(t, 1))
            themDong(ten,
                     String(format: "%d/%d thanh ghi có fact (%.0f%%)", c, t, ti * 100)
                        + " · \(dd) đã duyệt"
                        + (yc > 0 ? " · \(yc) đang chờ nguồn" : ""),
                     mau: ti < Self.nguongPhuYeu ? EideToken.Mau.warn : EideToken.Mau.ok)
        }
    }

    /// `rag_trace`: đoạn văn bản truy hồi + điểm + đường đi trong đồ thị.
    ///
    /// Điểm số hiện ra vì nó nói *vì sao đoạn này được chọn*. Một danh sách đoạn văn không kèm
    /// điểm thì người đọc không phân biệt được đoạn khớp chắc chắn với đoạn vừa đủ qua ngưỡng.
    private func _hienVetTruyHoi(_ chunks: [[String: Any]], diem: [String: Any],
                                 loi: [String]) {
        if !loi.isEmpty {
            themDong("đường đi trong đồ thị", loi.joined(separator: " → "),
                     mau: EideToken.Mau.info)
        }
        for c in chunks.prefix(20) {
            let id = (c["id"] as? String) ?? (c["chunk_id"] as? String) ?? "?"
            let van = (c["text"] as? String) ?? (c["snippet"] as? String) ?? ""
            let d = EideSo.thuc(diem[id]) ?? EideSo.thuc(c["score"])
            themDong(id, (d.map { String(format: "%.2f · ", $0) } ?? "") + van)
        }
    }

    /// `doc_side_by_side`: vùng nguồn bên trái, fact/mã bên phải.
    private func _hienCanhNhau(_ trai: [String: Any], _ phai: [String: Any]) {
        let nguon = (trai["source"] as? String) ?? "?"
        let trang = EideSo.nguyen(trai["page"]).map { " tr.\($0)" } ?? ""
        themDong("nguồn", "\(nguon)\(trang)", mau: EideToken.Mau.info)
        let f = (phai["fact_id"] as? String) ?? (phai["id"] as? String) ?? ""
        let gt = EideKnowledgeFormat.giaTri(phai["value"] ?? phai["code"])
        themDong("đã trích", (f.isEmpty ? "" : "\(f): ") + gt)
    }

    @objc private func moNut(_ s: NSButton) {
        if let n = s.identifier?.rawValue, !n.isEmpty { onMoNut?(n) }
    }

    @objc private func moXungDot(_ s: NSButton) {
        if let c = s.identifier?.rawValue, !c.isEmpty { onMoXungDot?(c) }
    }
}
