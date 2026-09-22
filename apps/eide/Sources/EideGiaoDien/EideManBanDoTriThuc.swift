import AppKit
import EideLoi

/// **S7 — Bản đồ tri thức & hỏi đáp.** UXC-31 §8 S7; năng lực `view.kg_map` (VIEW-01),
/// `view.rag_ask` (VIEW-07), `view.rag_trace` (VIEW-08).
///
/// ## Một màn, hai câu hỏi
///
/// Đồ thị trả lời *"máy biết những gì, và chúng nối với nhau ra sao"*. Ô hỏi trả lời *"máy nói
/// gì về chuyện này, và dựa vào đâu"*. Chúng ở cùng một màn vì câu thứ hai chỉ tin được khi
/// nhìn thấy câu thứ nhất.
///
/// ## Ràng buộc nặng nhất của cả sản phẩm nằm ở đây
///
/// VIEW-07 bước 1 đặt ba điều, và cả ba đều là ràng buộc về việc KHÔNG nói: trả lời CHỈ từ
/// chunk; mọi câu kèm `[n]`; điểm < 0,35 thì `not_found`. Màn này phải giữ cả ba cho tới tận
/// điểm ảnh cuối cùng — **một câu trả lời hiện ra mà không kèm nguồn bấm được thì cả tầng tri
/// thức bên dưới thành trang trí.** Vì thế `not_found` KHÔNG hiện như một lỗi: nó là kết quả
/// đúng, và là chỗ duy nhất trong sản phẩm mà trả về rỗng nghĩa là làm đúng việc.
public final class EideManBanDoTriThuc: EideManCoSo {

    public override class var tien: String { "Graph" }

    private var goiLoi: EideGoi?
    private let doThi = EideDoThi()
    private let oHoi = NSTextField()
    private let cocTraLoi = NSStackView()
    private let nhanChon = NSTextField(labelWithString: "")
    private var traceCuoi: String?

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        _dungOHoi()
        cocTraLoi.orientation = .vertical
        cocTraLoi.alignment = .leading
        cocTraLoi.spacing = 4

        let kq: [String: Any]?
        do {
            kq = try await nangLucNeuCo(goi, "view.kg_map")
        } catch let e as EideKetQua.Loi where e.maEide == "E5000" {
            // VIEW-01 ném E5000 khi đồ thị vượt 50.000 nút và bảo "hãy lọc trước". Đó là một
            // chỉ dẫn, không phải một sự cố — chuyển nguyên nó thành bước kế tiếp.
            return rong(vi: "đồ thị quá lớn để dựng: \(e)",
                        buocKe: "lọc theo tier/status/kind rồi mở lại — `view.kg_map` nhận "
                              + "`filter` với `tier[]`, `status[]`, `kinds[]`, `layer[]`")
        }

        let g = (kq?["graph"] as? [String: Any]) ?? [:]
        let ds = ((g["nodes"] as? [[String: Any]]) ?? []).compactMap(EideNutDoThi.init)
        let canh = ((g["edges"] as? [[String: Any]]) ?? []).compactMap(EideCanhDoThi.init)

        guard !ds.isEmpty else {
            them(_khungHoi())
            them(cocTraLoi)
            return rong(vi: kq == nil
                            ? "dự án này chưa có store tri thức — chưa thứ gì được nhập vào"
                            : "đồ thị tri thức chưa có nút nào — store chưa có fact",
                        buocKe: "nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ "
                              + "chính fact và nguồn của chúng")
        }

        doThi.dat(nut: ds, canh: canh)
        doThi.onChon = { [weak self] n in self?._chonNut(n) }

        tieuDePhu(Self.dongTomTat(soNut: ds.count, soCanh: canh.count,
                                  gomCum: (g["clustered"] as? Bool) ?? false,
                                  biCat: doThi.soBiCat))
        them(_khungDoThi())
        them(nhanChon)
        nhanChon.font = EideToken.fontMono
        nhanChon.textColor = EideToken.Mau.muted
        nhanChon.stringValue = "Bấm một nút để xem định danh đầy đủ."

        them(_chuGiai(g["legend"] as? [String: Any]))
        them(_khungHoi())
        them(cocTraLoi)
    }

    /// Dòng tóm tắt — và nó phải nói cả phần KHÔNG được vẽ.
    ///
    /// Lõi gom cụm chứ không cắt (VIEW-01), nên chỗ cắt duy nhất là bên vẽ. Một đồ thị hiện 240
    /// nút trong khi có 900 trông đầy đủ và thiếu, mà không gì báo cho người xem biết.
    public static func dongTomTat(soNut: Int, soCanh: Int, gomCum: Bool, biCat: Int) -> String {
        var s = "\(soNut) NÚT · \(soCanh) CẠNH"
        if gomCum { s += " · đã GOM CỤM theo ngoại vi (mỗi cụm ghi số nút bên trong)" }
        if biCat > 0 { s += " · vẽ \(soNut - biCat) nút đầu, CÒN \(biCat) chưa vẽ" }
        return s
    }

    // MARK: - hỏi đáp

    private func _dungOHoi() {
        oHoi.placeholderString = "Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22?"
        oHoi.font = EideToken.fontUI
        oHoi.target = self
        oHoi.action = #selector(_hoi)
    }

    private func _khungHoi() -> NSView {
        let nut = NSButton(title: "Hỏi", target: self, action: #selector(_hoi))
        nut.bezelStyle = .rounded
        nut.keyEquivalent = "\r"
        // Nút chỉ sáng khi ô câu hỏi có chữ — xem `EideNutTheoO`.
        EideNutTheoO.noi(oHoi, nut)
        let h = NSStackView(views: [oHoi, nut])
        h.orientation = .horizontal
        h.spacing = 8
        oHoi.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return h
    }

    @objc private func _hoi() {
        let q = oHoi.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let goi = goiLoi else { return }
        Task { await _chayHoi(goi, q) }
    }

    private func _chayHoi(_ goi: @escaping EideGoi, _ q: String) async {
        _xoaTraLoi()
        _dong("Đang truy hồi…", mau: EideToken.Mau.faint)
        do {
            let r = try await nangLuc(goi, "view.rag_ask", ["question": q])
            _xoaTraLoi()
            traceCuoi = r["trace_id"] as? String

            if (r["not_found"] as? Bool) == true {
                // KHÔNG hiện như lỗi. VIEW-07: "< 0,35 → not_found — thà nói không biết".
                _dong("Không đủ căn cứ để trả lời. Không đoạn tài liệu nào trong store đạt "
                      + "ngưỡng tin cậy cho câu hỏi này.", mau: EideToken.Mau.warn)
                _dong("Bước kế tiếp: nhập thêm tài liệu ở màn Nhập tài liệu (S4), hoặc hỏi hẹp "
                      + "hơn vào một chủ thể đã có trong đồ thị trên.", mau: EideToken.Mau.muted)
                _nutViSao()
                return
            }

            let cit = (r["citations"] as? [[String: Any]]) ?? []
            // Bất biến của VIEW-07: **không trích dẫn thì không hiện câu trả lời.** Lõi đã ném
            // E5002 khi có câu thiếu `[n]`, nhưng bên vẽ không được dựa vào một lớp khác giữ
            // hộ bất biến của mình — đây là điểm ảnh cuối cùng trước mắt người dùng.
            guard !cit.isEmpty else {
                return _dong("Lõi trả về câu trả lời KHÔNG kèm trích dẫn — màn này không hiện "
                             + "nó. VIEW-07 đòi 100% citations.", mau: EideToken.Mau.bad)
            }
            _dong((r["answer"] as? String) ?? "", mau: EideToken.Mau.text)
            tieuDePhuTrongTraLoi("\(cit.count) NGUỒN")
            for c in cit { _dongTrichDan(c) }
            _nutViSao()
        } catch {
            _xoaTraLoi()
            _dong(Self.viSaoHong(error), mau: EideToken.Mau.bad)
        }
    }

    /// Lỗi của `view.rag_ask` → câu người đọc làm được gì với nó.
    ///
    /// E5002 ở đây gần như luôn là "chưa lập chỉ mục RAG", và lõi đã kèm `remedy` — nói lại
    /// bằng tiếng người thay vì in nguyên mã lỗi, vì người mở màn này không phải người viết lõi.
    public static func viSaoHong(_ e: Error) -> String {
        let s = "\(e)"
        if s.contains("E5002"), s.contains("chỉ mục") || s.contains("rag_index") {
            return "Chưa có chỉ mục RAG cho dự án này. Nhập một tài liệu văn bản (README, ghi "
                 + "chú) ở màn Nhập tài liệu (S4) — `ingest.index_text` lập chỉ mục cho chúng."
        }
        return "Không hỏi được: \(s)"
    }

    private func _nutViSao() {
        guard traceCuoi != nil else { return }
        let b = NSButton(title: "Vì sao câu trả lời này?", target: self, action: #selector(_viSao))
        b.bezelStyle = .inline
        cocTraLoi.addArrangedSubview(b)
    }

    /// `view.rag_trace` — ba điểm thành phần, đúng tc của VIEW-08 ("Hiển thị đủ 3 điểm").
    @objc private func _viSao() {
        guard let goi = goiLoi, let tid = traceCuoi else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let r = try await nangLuc(goi, "view.rag_trace", ["trace_id": tid])
                hienTrace(r)
            } catch {
                _dong("Không mở được vết truy hồi: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// Tách khỏi phần gọi lõi để phép kiểm đo được nó mà không cần daemon.
    public func hienTrace(_ r: [String: Any]) {
        let d = (r["scores"] as? [String: Any]) ?? [:]
        tieuDePhuTrongTraLoi("VÌ SAO — ba thành phần điểm")
        // Ba điểm này là toàn bộ nội dung của VIEW-08. Gộp thành một con số thì "vì sao" trở
        // lại thành "tin đi": không ai biết câu trả lời đến từ khớp CHỮ, khớp NGHĨA hay từ một
        // bước lan tỏa trên đồ thị.
        for k in ["bm25", "vector", "graph"] {
            _dong("  \(k): \(EideManHoChieu.giaTri(d[k] ?? "—"))", mau: EideToken.Mau.muted)
        }
        let duong = (r["graph_path"] as? [String]) ?? []
        if !duong.isEmpty {
            _dong("  đường lan tỏa: " + duong.joined(separator: " → "), mau: EideToken.Mau.muted)
        }
        let n = (r["chunks"] as? [Any])?.count ?? 0
        _dong("  \(n) đoạn được cân nhắc", mau: EideToken.Mau.faint)
    }

    /// Một trích dẫn — kèm nút mở nguồn, vì "trích dẫn nhấp mở nguồn" là chữ của UXC-31 §8 S7.
    private func _dongTrichDan(_ c: [String: Any]) {
        let n = EideManHoChieu.nguyen(c["n"]) ?? 0
        let sid = (c["source_id"] as? String) ?? "?"
        let diem = (c["score"] as? Double).map { String(format: " · điểm %.2f", $0) } ?? ""
        _dong("[\(n)] \(EideManHoChieu.tenTep(sid)) · "
              + "\(EideManHoChieu.viTri(c["locator"]))\(diem)", mau: EideToken.Mau.text)
        if let s = c["snippet"] as? String, !s.isEmpty {
            _dong("    “\(s.prefix(220))\(s.count > 220 ? "…" : "")”", mau: EideToken.Mau.muted)
        }
        if let d = EideManHoChieu.duongTep(sid) {
            let b = NSButton(title: "Mở \(EideManHoChieu.tenTep(sid))",
                             target: self, action: #selector(_moNguon(_:)))
            b.bezelStyle = .inline
            b.identifier = NSUserInterfaceItemIdentifier(d.path)
            cocTraLoi.addArrangedSubview(b)
        }
    }

    @objc private func _moNguon(_ n: NSButton) {
        guard let p = n.identifier?.rawValue else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    // MARK: - khối phụ

    private func _chonNut(_ n: EideNutDoThi) {
        // Nhãn trên đồ thị là đoạn CUỐI của IRI (`reg:CR1`), nên hai con chip khác nhau cho hai
        // nút trông y hệt. Bấm vào phải ra định danh ĐẦY ĐỦ.
        var s = n.id
        if let t = n.tang { s += "  · tầng \(EideManHoChieu.nhanTang(t, n.trangThai ?? ""))" }
        nhanChon.stringValue = s
    }

    private func _khungDoThi() -> NSView {
        let cuon = NSScrollView()
        cuon.documentView = doThi
        cuon.hasVerticalScroller = true
        cuon.hasHorizontalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        cuon.heightAnchor.constraint(equalToConstant: 360).isActive = true
        return cuon
    }

    private func _chuGiai(_ legend: [String: Any]?) -> NSView {
        var phan: [String] = []
        for (nhom, nhan) in [("tier", "tầng"), ("status", "trạng thái")] {
            let d = (legend?[nhom] as? [String: Any]) ?? [:]
            if !d.isEmpty { phan.append("\(nhan): " + d.keys.sorted().joined(separator: " · ")) }
        }
        phan.append("cạnh: CITES xanh · USES lục · CONFLICTS_WITH đỏ đậm · SUPERSEDES nét đứt")
        let n = NSTextField(wrappingLabelWithString: phan.joined(separator: "   |   "))
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.faint
        return n
    }

    private func tieuDePhuTrongTraLoi(_ s: String) {
        _baoDamGan()
        let n = NSTextField(labelWithString: s)
        n.font = NSFont.boldSystemFont(ofSize: 10.5)
        n.textColor = EideToken.Mau.faint
        cocTraLoi.addArrangedSubview(n)
    }

    /// Tự gắn vùng trả lời vào thân nếu chưa. Không có dòng này thì một câu trả lời về SAU một
    /// lần nạp lại vẽ vào một khung nhìn không có cha: đúng dữ liệu, đúng bố cục, và không một
    /// điểm ảnh nào trên màn hình — cùng lỗi đã gặp ở `EideManHoChieu.hienChuoi`.
    private func _baoDamGan() {
        if cocTraLoi.superview == nil { them(cocTraLoi) }
    }

    private func _dong(_ s: String, mau: NSColor) {
        _baoDamGan()
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        cocTraLoi.addArrangedSubview(n)
    }

    private func _xoaTraLoi() {
        for v in cocTraLoi.arrangedSubviews {
            cocTraLoi.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    /// Cho test đặt câu hỏi mà không cần gõ phím.
    public func hoiDeTest(_ q: String) {
        oHoi.stringValue = q
        _hoi()
    }
}
