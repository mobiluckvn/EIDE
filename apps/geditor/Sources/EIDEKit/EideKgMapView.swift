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
        tiLePhu = nil; soNgoaiViTrong = 0

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
        if do_ != nil { _hienDoThi(nodes) }

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

        for e in sk.prefix(40) {
            let loai = (e["kind"] as? String) ?? (e["type"] as? String) ?? "?"
            let luc = (e["at"] as? String) ?? ""
            let mo = (e["detail"] as? String) ?? (e["subject"] as? String) ?? ""
            themDong(luc.isEmpty ? loai : "\(luc) · \(loai)", mo)
        }
        if sk.count > 40 { noiRong("… và \(sk.count - 40) mốc nữa.") }

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
    private func _hienDoThi(_ nodes: [[String: Any]]) {
        let theoTang = Dictionary(grouping: nodes, by: { ($0["tier"] as? String) ?? "—" })
        for (tang, ds) in theoTang.sorted(by: { _thuTuTang($0.key) < _thuTuTang($1.key) }) {
            let xau = ds.filter { (($0["status"] as? String) ?? "") == "conflict" }.count
            themDong(EideKnowledgeFormat.nhanTang(tang, ""),
                     "\(ds.count) nút" + (xau > 0 ? " · \(xau) đang mâu thuẫn" : ""),
                     mau: xau > 0 ? EideToken.Mau.bad : EideKnowledgeFormat.mauTang(tang, ""))
            for n in ds.prefix(12) {
                let id = (n["id"] as? String) ?? ""
                let nhan = (n["label"] as? String) ?? EideKnowledgeFormat.tenNgan(id)
                let loai = (n["kind"] as? String) ?? ""
                themDong("  \(nhan)", loai, nut: !id.isEmpty, ma: id,
                         bam: #selector(moNut(_:)))
            }
            if ds.count > 12 { noiRong("  … và \(ds.count - 12) nút \(tang) nữa.") }
        }
    }

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
