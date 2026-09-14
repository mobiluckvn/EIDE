import AppKit

/// Năm màn "hệ thống" — UXD-13 màn 17 (ToolForge), 19 (Registry), 20 (Models), 21 (Env),
/// 22 (FlowMap).
///
/// Spec: CDS-12 TOOL-01..10, REGISTRY-01..05, ENV-01..07, POLICY-01..07; POL-17 §3 (ký);
/// SEC-25 §2/§3 (sandbox, không mạng); UXD-13 §2, U2, U9; API-15 §5 `model.call`.
///
/// ## Bất biến chung: những màn này quyết định EIDE được phép làm gì
///
/// Bốn màn trước nói về dự án; năm màn này nói về chính hệ thống — công cụ nó tự viết ra, gói
/// tri thức nó nạp vào, mô hình nó gọi, công cụ ngoài nó chạy, và những chỗ nó phải dừng lại
/// chờ người. Bất biến: **mọi thứ ở đây mở rộng quyền của máy, nên mọi thứ ở đây phải nói rõ
/// ai đã cho phép và dựa trên bằng chứng gì.** Một công cụ tự viết được thăng cấp mà không ai
/// đọc `observed_effects`, một gói nạp vào mà không kiểm chữ ký — cả hai đều là cách quyền
/// được mở rộng trong im lặng.

// MARK: - Màn 17: Công cụ tự tạo

/// `tool.need` `{spec, reuse[]}`, `tool.write` `{tool_id, code_path, test_path, effects[]}`,
/// `tool.test` `{report, observed_effects[], effects_ok}`, `tool.run` `{result, report}`,
/// `tool.register` `{capability_code, capability_id}`, `tool.repair` `{code_path, give_up}`,
/// `tool.promote` `{proposal}`, `tool.search` `{tools[]}`.
public final class ToolForgeView: ManHinhCoSo {

    public var onChayThu: ((String) -> Void)?

    public private(set) var soCongCu = 0
    /// `tool.test` — tác dụng quan sát được có khớp phần khai báo không. `nil` = chưa chạy test.
    public private(set) var tacDungKhop: Bool?
    public private(set) var soTacDungLa = 0

    public init() { super.init(ten: "Công cụ tự tạo") }

    /// **`effects_ok: false` là lý do KHÔNG đăng ký, không phải một ghi chú.**
    ///
    /// TOOL-04 chạy công cụ trong sandbox rồi so tác dụng QUAN SÁT ĐƯỢC với tác dụng công cụ
    /// tự KHAI BÁO. Lệch nhau nghĩa là công cụ làm một việc mà bản khai của nó không nói — ghi
    /// tệp ngoài vùng cho phép, mở mạng, gọi một tiến trình khác. Đăng ký nó thành năng lực
    /// `user.*` (TOOL-06) là đưa thứ ấy vào Router, nơi tác tử gọi được mà không hỏi ai nữa.
    ///
    /// Đây là chỗ một sản phẩm tự viết công cụ cho mình có thể tự mở rộng quyền của mình, nên
    /// màn này để `observed_effects` ở chỗ dễ đọc nhất, cạnh chữ "đã đăng ký".
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soCongCu = 0; tacDungKhop = nil; soTacDungLa = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có công cụ tự tạo nào — `/tool.need` khi một chuỗi thiếu năng lực.")
            return
        }

        let spec = ketQua["spec"] as? [String: Any]
        let dungLai = (ketQua["reuse"] as? [[String: Any]]) ?? []
        let ds = (ketQua["tools"] as? [[String: Any]]) ?? []
        let tid = (ketQua["tool_id"] as? String) ?? ""
        let maNguon = (ketQua["code_path"] as? String) ?? ""
        let khai = (ketQua["effects"] as? [String]) ?? []
        let thay = (ketQua["observed_effects"] as? [String]) ?? []
        tacDungKhop = ketQua["effects_ok"] as? Bool
        let maNL = (ketQua["capability_id"] as? String) ?? ""
        let maCode = (ketQua["capability_code"] as? String) ?? ""
        let boCuoc = ketQua["give_up"] as? Bool
        let deXuat = ketQua["proposal"] as? [String: Any]

        soCongCu = ds.count
        soTacDungLa = thay.filter { !khai.contains($0) }.count

        var d: [String] = []
        if !tid.isEmpty { d.append(tid) }
        if soCongCu > 0 { d.append("\(soCongCu) công cụ đã có") }
        if !dungLai.isEmpty { d.append("\(dungLai.count) cái dùng lại được") }
        if tacDungKhop == false { d.append("TÁC DỤNG NGOÀI KHAI BÁO (\(soTacDungLa))") }
        else if tacDungKhop == true { d.append("tác dụng khớp khai báo") }
        if !maNL.isEmpty { d.append("đã đăng ký \(maNL)") }
        if boCuoc == true { d.append("sửa ĐÃ BỎ CUỘC") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (tacDungKhop == false || boCuoc == true)
            ? EideToken.Mau.bad : EideToken.Mau.muted

        if tacDungKhop == false {
            let v = noiRong("Công cụ này làm những việc bản khai của nó không nói. Đừng đăng ký "
                          + "nó thành năng lực `user.*` — đăng ký là đưa nó vào Router, nơi tác "
                          + "tử gọi được mà không hỏi ai nữa.")
            v.textColor = EideToken.Mau.bad
        }

        // Dùng lại TRƯỚC khi viết mới: TOOL-01 tìm cái đã có chính vì một kho công cụ tự sinh
        // không kiểm soát sẽ đầy những hàm gần giống nhau.
        for r in dungLai {
            let ten = (r["tool_id"] as? String) ?? (r["id"] as? String) ?? "?"
            let diem = EideSo.thuc(r["score"]).map { String(format: " · khớp %.0f%%", $0 * 100) } ?? ""
            themDong("dùng lại: \(ten)", "đã có sẵn\(diem)", mau: EideToken.Mau.ok)
        }

        if let s = spec { _hienBanKhai(s) }

        for e in khai { themDong("khai báo tác dụng", e, mau: EideToken.Mau.info) }
        for e in thay {
            let la = !khai.contains(e)
            themDong(la ? "NGOÀI KHAI BÁO" : "quan sát được", e,
                     mau: la ? EideToken.Mau.bad : EideToken.Mau.ok)
        }

        if !maNguon.isEmpty {
            themDong("mã", maNguon, mau: EideToken.Mau.muted,
                     nut: !tid.isEmpty, ma: tid, bam: #selector(chayThu(_:)))
        }
        if !maNL.isEmpty {
            themDong("năng lực tạm", "\(maCode) \(maNL)", mau: EideToken.Mau.warn)
        }
        if deXuat != nil {
            // TOOL-08 thăng cấp lên `eide.*` — đổi namespace là đổi ai chịu trách nhiệm.
            themDong("đề nghị thăng cấp", "chuyển từ `user.*` sang `eide.*` — cần người duyệt",
                     mau: EideToken.Mau.warn)
        }

        for t in ds {
            let ten = (t["tool_id"] as? String) ?? "?"
            let dung = EideSo.nguyen(t["uses"]).map { "\($0) lượt dùng" } ?? ""
            let lanCuoi = (t["last_ok"] as? String).map { "lần cuối OK \($0)" } ?? "CHƯA lần nào OK"
            themDong(ten, [dung, lanCuoi].filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: t["last_ok"] == nil ? EideToken.Mau.warn : nil)
        }

        if let ok = ketQua["ok"] as? Bool {
            // TOOL-10 vô hiệu hoá một công cụ nhưng GIỮ lịch sử: những lần chạy cũ vẫn phải
            // truy được, vì kết quả của chúng đã đi vào tri thức dự án.
            themDong("vô hiệu hoá công cụ", ok ? "xong — lịch sử chạy vẫn giữ"
                                               : "KHÔNG vô hiệu hoá được",
                     mau: ok ? EideToken.Mau.ok : EideToken.Mau.bad)
        }

        if soDong == 0 { noiRong("Không có công cụ, bản khai hay tác dụng nào để hiện.") }
    }

    private func _hienBanKhai(_ s: [String: Any]) {
        let ten = (s["name"] as? String) ?? "?"
        let vi = (s["purpose"] as? String) ?? ""
        themDong("ToolSpec \(ten)", vi)
        let nhan = (s["acceptance"] as? [Any]) ?? []
        // TOOL-01 đòi `acceptance[]`. Một công cụ không có tiêu chí nghiệm thu thì `tool.test`
        // chẳng có gì để chấm, và "test đã chạy" trở thành một câu không mang thông tin.
        themDong(" · nghiệm thu",
                 nhan.isEmpty ? "KHÔNG có tiêu chí — tool.test sẽ không chấm được gì"
                              : "\(nhan.count) tiêu chí",
                 mau: nhan.isEmpty ? EideToken.Mau.bad : nil)
        if let deps = s["deps"] as? [Any], !deps.isEmpty {
            themDong(" · phụ thuộc", deps.map { EideKnowledgeFormat.giaTri($0) }
                .joined(separator: ", "))
        }
    }

    @objc private func chayThu(_ s: NSButton) {
        if let t = s.identifier?.rawValue, !t.isEmpty { onChayThu?(t) }
    }
}

// MARK: - Màn 19: Registry

/// `registry.search` `{packages[]}`, `registry.pull` `{pinned, facts}`,
/// `registry.pack` `{file, manifest}`, `registry.publish` `{published, url}`,
/// `registry.seed` `{report{n_ok, n_fail, per_vendor}}`.
public final class RegistryView: ManHinhCoSo {

    public var onNap: ((String) -> Void)?

    public private(set) var soGoi = 0
    public private(set) var soFactNap = 0
    /// Số gói KHÔNG có chữ ký trong kết quả tìm — xem `capNhat`.
    public private(set) var soKhongKy = 0

    public init() { super.init(ten: "Registry") }

    /// **Gói không có chữ ký phải đọc ra là không có chữ ký.**
    ///
    /// REGISTRY-02 nói `pull` "kiểm chữ ký" trước khi nạp vào store. Một gói tri thức là hàng
    /// nghìn fact về phần cứng, và chúng sẽ trở thành hằng số trong firmware qua
    /// `code.constant_guard` — tức chữ ký ở đây bảo vệ đúng thứ mà cả tầng tri thức được dựng
    /// lên để bảo vệ. Hiện một danh sách gói mà không hiện trạng thái chữ ký là mời người dùng
    /// nạp một gói không rõ nguồn gốc bằng một cú bấm.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soGoi = 0; soFactNap = 0; soKhongKy = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa tìm gói nào — `/registry.search <mpn>`.")
            return
        }

        let goi = (ketQua["packages"] as? [[String: Any]]) ?? []
        let ghim = (ketQua["pinned"] as? String) ?? ""
        soFactNap = EideSo.nguyen(ketQua["facts"]) ?? 0
        let tep = (ketQua["file"] as? String) ?? ""
        let khai = ketQua["manifest"] as? [String: Any]
        let daPhat = ketQua["published"] as? Bool
        let diaChi = (ketQua["url"] as? String) ?? ""
        let bc = ketQua["report"] as? [String: Any]

        soGoi = goi.count
        soKhongKy = goi.filter { ($0["signed"] as? Bool) != true && $0["signature"] == nil }.count

        var d: [String] = []
        if soGoi > 0 { d.append("\(soGoi) gói") }
        if soKhongKy > 0 { d.append("\(soKhongKy) KHÔNG CHỮ KÝ") }
        if !ghim.isEmpty { d.append("đã ghim \(ghim) · \(soFactNap) fact") }
        if !tep.isEmpty { d.append("đóng gói \(EideKnowledgeFormat.tenNgan(tep))") }
        if daPhat == true { d.append("đã phát hành") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = soKhongKy > 0 ? EideToken.Mau.warn : EideToken.Mau.muted

        for p in goi {
            let id = (p["id"] as? String) ?? (p["package"] as? String) ?? "?"
            let ver = (p["version"] as? String).map { "@\($0)" } ?? ""
            let n = EideSo.nguyen(p["facts"]).map { "\($0) fact" } ?? ""
            let ky = (p["signed"] as? Bool) ?? (p["signature"] != nil)
            let hh = ((p["badges"] as? [Any]) ?? []).count
            themDong("\(id)\(ver)",
                     [n, ky ? "đã ký" : "CHƯA KÝ — kiểm nguồn trước khi nạp",
                      hh > 0 ? "\(hh) huy hiệu" : ""].filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: ky ? nil : EideToken.Mau.bad,
                     nut: ky, ma: id, bam: #selector(nap(_:)))
        }

        if !ghim.isEmpty {
            themDong("đã nạp", "\(ghim) — \(soFactNap) fact vào store", mau: EideToken.Mau.ok)
        }

        if let m = khai {
            for (k, v) in m.sorted(by: { $0.key < $1.key }).prefix(10) {
                themDong("manifest \(k)", EideKnowledgeFormat.giaTri(v))
            }
        }

        if daPhat == true && !diaChi.isEmpty {
            themDong("phát hành tại", diaChi, mau: EideToken.Mau.info)
        } else if daPhat == false {
            // REGISTRY-04: nội bộ tự động, công khai HỎI. `published: false` không phải lỗi.
            themDong("chưa phát hành", "phát hành công khai cần anh duyệt", mau: EideToken.Mau.warn)
        }

        if let r = bc {
            let ok = EideSo.nguyen(r["n_ok"]) ?? 0
            let fail = EideSo.nguyen(r["n_fail"]) ?? 0
            themDong("gieo hạt", "\(ok) thành công · \(fail) hỏng",
                     mau: fail > 0 ? EideToken.Mau.warn : EideToken.Mau.ok)
            if let hang = r["per_vendor"] as? [String: Any] {
                for (h, v) in hang.sorted(by: { $0.key < $1.key }) {
                    themDong(" · \(h)", EideKnowledgeFormat.giaTri(v))
                }
            }
        }

        if soDong == 0 { noiRong("Không có gói nào khớp.") }
    }

    @objc private func nap(_ s: NSButton) {
        if let p = s.identifier?.rawValue, !p.isEmpty { onNap?(p) }
    }
}

// MARK: - Màn 20: Mô hình & chi phí

/// Chi phí hôm nay từ `project.status` `{report{cost_today}}`, mức tự chủ từ `autonomy.get`.
///
/// **Màn này hiện ít hơn UXD-13 mô tả, và nói ra điều đó.** Xem `capNhat`.
public final class ModelsView: ManHinhCoSo {

    public private(set) var chiPhiHomNay: Double = 0
    public private(set) var soLuotGoi = 0

    public init() { super.init(ten: "Mô hình & chi phí") }

    /// **API-15 không có phương thức nào cho màn này.**
    ///
    /// UXD-13 §2 liệt kê màn 20 và gắn nó với `policy` + `gateway`, nhưng trong 57 phương thức
    /// JSON-RPC không có cái nào trả bảng vai trò→mô hình hay chi tiết chi phí; và `model.call`
    /// — sự kiện sổ cái mang `role, model_id, tokens_in/out, cost_usd, latency_ms` — không nằm
    /// trong 16 phương thức `event.*`, nên panel cũng không nhận được nó theo thời gian thực.
    ///
    /// Thứ panel lấy được là `cost_today` trong `project.status`. Màn này hiện đúng thứ ấy và
    /// **nói thẳng phần còn thiếu cùng cách xem nó** (CLI đọc sổ cái). Vẽ ra một bảng mô hình
    /// đẹp đẽ từ dữ liệu không có là cách tệ nhất để lấp một khoảng trống giữa hai tài liệu —
    /// xem DEVIATIONS DEV-093.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        chiPhiHomNay = 0; soLuotGoi = 0

        let bc = (ketQua["report"] as? [String: Any]) ?? ketQua
        chiPhiHomNay = EideSo.thuc(bc["cost_today"]) ?? 0
        soLuotGoi = EideSo.nguyen(bc["calls_today"]) ?? 0
        let tuChu = (bc["autonomy"] as? String) ?? (ketQua["autonomy"] as? String) ?? ""
        let dung = (ketQua["stopped"] as? Bool) ?? false

        var d: [String] = []
        d.append(String(format: "%.2f USD hôm nay", chiPhiHomNay))
        if soLuotGoi > 0 { d.append("\(soLuotGoi) lượt gọi") }
        if !tuChu.isEmpty { d.append("tự chủ \(tuChu)") }
        if dung { d.append("ĐANG DỪNG KHẨN") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = dung ? EideToken.Mau.bad : EideToken.Mau.muted

        themDong("chi phí hôm nay", String(format: "%.4f USD", chiPhiHomNay),
                 mau: EideToken.Mau.info)
        if !tuChu.isEmpty { themDong("mức tự chủ", tuChu) }

        _hienTuSoCai(ketQua)
    }

    /// Gom `model.call` từ SỔ CÁI theo vai trò — UC-F7, đóng [DEV-093].
    ///
    /// ## Vì sao đổi nguồn
    ///
    /// Bản cũ đọc `models.yaml` và `project.status`, tức đọc **cấu hình**: nó nói tác tử ĐƯỢC
    /// PHÉP dùng mô hình nào, không nói nó ĐÃ dùng gì. Hai câu ấy khác nhau ở đúng chỗ người
    /// trả tiền quan tâm.
    ///
    /// Nay đọc `view.timeline` (VIEW-12, `ref: memory.ledger`) và lọc `model.call`. Mỗi bản ghi
    /// có `role`, `model`, `tokens_in/out`, `cost_usd`, `ms` — đủ để gom theo vai trò mà không
    /// cần thêm một phương thức RPC nào.
    ///
    /// **Không hiện nội dung prompt.** Sổ cái đã che khoá API (`che_bi_mat`), nhưng che khoá
    /// khác với không đưa mã nguồn người dùng ra một cửa sổ có thể đang chia sẻ màn hình —
    /// `TRUONG_KHONG_DAY` của daemon lược chúng từ trước, và màn này cũng không đi tìm.
    private func _hienTuSoCai(_ ketQua: [String: Any]) {
        let ds = ((ketQua["events"] as? [Any]) ?? [])
            .compactMap { $0 as? [String: Any] }
            .filter { ($0["kind"] as? String) == "model.call" }
        guard !ds.isEmpty else {
            // Ba trạng thái rỗng khác nhau — xem `NhatKyView`. Ở đây chỉ có hai, và cả hai đều
            // phải nói ra: chưa gọi mô hình lần nào, hay chưa đọc được sổ cái.
            noiRong(ketQua["events"] == nil
                    ? "Chưa đọc được sổ cái — mở một dự án rồi thử lại."
                    : "Chưa có lượt gọi mô hình nào trong sổ cái của dự án này.")
            return
        }

        struct Gom { var luot = 0; var vao = 0; var ra = 0; var usd = 0.0; var ms = 0 }
        var theoVaiTro: [String: Gom] = [:]
        var tongUsd = 0.0, tongVao = 0, tongRa = 0
        for e in ds {
            let d = (e["data"] as? [String: Any]) ?? e
            let vai = (d["role"] as? String) ?? (d["model"] as? String) ?? "(không rõ vai trò)"
            var g = theoVaiTro[vai] ?? Gom()
            g.luot += 1
            g.vao += EideSo.nguyen(d["tokens_in"]) ?? 0
            g.ra += EideSo.nguyen(d["tokens_out"]) ?? 0
            g.usd += EideSo.thuc(d["cost_usd"]) ?? 0
            g.ms += EideSo.nguyen(d["ms"]) ?? EideSo.nguyen(d["latency_ms"]) ?? 0
            theoVaiTro[vai] = g
            tongUsd += EideSo.thuc(d["cost_usd"]) ?? 0
            tongVao += EideSo.nguyen(d["tokens_in"]) ?? 0
            tongRa += EideSo.nguyen(d["tokens_out"]) ?? 0
        }
        soLuotGoi = ds.count
        chiPhiHomNay = tongUsd
        tomTat.stringValue = "\(ds.count) lượt gọi · \(tongVao) token vào · \(tongRa) ra"
            + (tongUsd > 0 ? String(format: " · %.4f USD", tongUsd) : " · chưa có giá")
        tomTat.textColor = EideToken.Mau.muted

        // Sắp theo CHI PHÍ giảm dần, không theo bảng chữ cái: người mở màn này muốn biết tiền
        // đi đâu, và vai trò tốn nhất phải nằm dòng đầu.
        for (vai, g) in theoVaiTro.sorted(by: { $0.value.usd != $1.value.usd
                                                ? $0.value.usd > $1.value.usd
                                                : $0.key < $1.key }) {
            var ct = "\(g.luot) lượt · \(g.vao) vào · \(g.ra) ra"
            if g.usd > 0 { ct += String(format: " · %.4f USD", g.usd) }
            if g.ms > 0 { ct += " · \(g.ms / max(1, g.luot)) ms/lượt" }
            themDong(vai, ct, mau: EideToken.Mau.info)
        }

        if tongUsd == 0 {
            // Không phải lượt gọi nào cũng biết giá (mô hình chạy cục bộ, gateway không trả).
            // Hiện "0,0000 USD" là khẳng định nó miễn phí.
            noiRong("Không lượt gọi nào mang giá — có thể mô hình chạy cục bộ, hoặc gateway "
                    + "không trả `cost_usd`. Số token vẫn đúng.")
        }
    }
}

// MARK: - Màn 21: Môi trường

/// `env.detect` `{env{os, arch, python, ports[], probes[], shell}}`,
/// `env.check` `{report[]{tool, required, found, version, ok, hash}}`,
/// `env.lock` `{lock, drift[]}`, `env.guide_install` `{steps[], links[]}`,
/// `env.install` `{report}`.
public final class EnvView: ManHinhCoSo {

    public var onCai: ((String) -> Void)?

    public private(set) var soThieu = 0
    public private(set) var soTroi = 0

    public init() { super.init(ten: "Môi trường") }

    /// **Công cụ thiếu hiện kèm CÁCH CÀI, không chỉ kèm chữ "thiếu".**
    ///
    /// ENV-02 trả `{tool, required, found, version, ok}`. Một dòng "arm-none-eabi-gcc: thiếu"
    /// để người dùng tự đi tìm; và trên máy Mac thì cái họ tìm thấy đầu tiên thường là bản
    /// Homebrew KHÔNG kèm newlib — tức cài xong vẫn không dựng được, mà thông báo lỗi lúc ấy
    /// nói về một tệp header chứ không nói về gói cài sai.
    ///
    /// **`drift[]` của `env.lock` là cảnh báo nặng.** Phiên bản công cụ trôi đi nghĩa là
    /// firmware dựng hôm nay khác firmware dựng tuần trước từ cùng một mã — và không có gì
    /// trong mã thay đổi để giải thích điều đó.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soThieu = 0; soTroi = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa dò môi trường — `/env.detect` rồi `/env.check`.")
            return
        }

        let mt = ketQua["env"] as? [String: Any]
        let bang = (ketQua["report"] as? [[String: Any]]) ?? []
        let khoa = ketQua["lock"] as? [String: Any]
        let troi = (ketQua["drift"] as? [[String: Any]]) ?? []
        let buoc = (ketQua["steps"] as? [String]) ?? []
        let lien = (ketQua["links"] as? [String]) ?? []

        soThieu = bang.filter { ($0["ok"] as? Bool) == false }.count
        soTroi = troi.count

        var d: [String] = []
        if let e = mt {
            let os = (e["os"] as? String) ?? "?"
            let arch = (e["arch"] as? String) ?? "?"
            d.append("\(os) \(arch)")
        }
        if !bang.isEmpty { d.append("\(bang.count - soThieu)/\(bang.count) công cụ sẵn sàng") }
        if soThieu > 0 { d.append("\(soThieu) THIẾU") }
        if soTroi > 0 { d.append("\(soTroi) PHIÊN BẢN TRÔI") }
        if khoa != nil && soTroi == 0 { d.append("đã khóa phiên bản") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (soThieu > 0 || soTroi > 0) ? EideToken.Mau.warn : EideToken.Mau.muted

        for t in troi {
            let ten = (t["tool"] as? String) ?? "?"
            let cu = (t["locked"] as? String) ?? (t["expected"] as? String) ?? "?"
            let moi = (t["found"] as? String) ?? "?"
            themDong(ten, "khóa \(cu) · máy đang có \(moi) — firmware dựng ra sẽ khác",
                     mau: EideToken.Mau.bad)
        }

        for t in bang.sorted(by: { (($0["ok"] as? Bool) ?? true) == false
                                 && (($1["ok"] as? Bool) ?? true) }) {
            let ten = (t["tool"] as? String) ?? "?"
            let ok = (t["ok"] as? Bool) ?? false
            let thay = (t["found"] as? String) ?? ""
            let can = (t["required"] as? String) ?? ""
            let ver = (t["version"] as? String) ?? ""
            themDong(ten,
                     ok ? [ver, thay].filter { !$0.isEmpty }.joined(separator: " · ")
                        : "THIẾU\(can.isEmpty ? "" : " (cần \(can))") — bấm để xem cách cài",
                     mau: ok ? EideToken.Mau.ok : EideToken.Mau.bad,
                     nut: !ok, ma: ten, bam: #selector(cai(_:)))
        }

        if let e = mt { _hienMoiTruong(e) }

        for (i, b) in buoc.enumerated() { themDong("bước \(i + 1)", b) }
        for l in lien { themDong("liên kết", l, mau: EideToken.Mau.info) }

        for c in (ketQua["installed"] as? [Any]) ?? [] {
            themDong("đã cài", EideKnowledgeFormat.giaTri(c), mau: EideToken.Mau.ok)
        }

        if soDong == 0 { noiRong("Môi trường đọc được nhưng không có công cụ nào trong manifest.") }
    }

    private func _hienMoiTruong(_ e: [String: Any]) {
        for k in ["os", "arch", "python", "shell"] {
            if let v = e[k] { themDong(k, EideKnowledgeFormat.giaTri(v)) }
        }
        if let c = e["ports"] as? [Any] {
            themDong("cổng", c.isEmpty ? "không thấy cổng nào" : "\(c.count) cổng",
                     mau: c.isEmpty ? EideToken.Mau.muted : nil)
        }
        if let p = e["probes"] as? [Any] {
            themDong("probe", p.isEmpty ? "không thấy probe nào" : "\(p.count) probe",
                     mau: p.isEmpty ? EideToken.Mau.muted : nil)
        }
    }

    @objc private func cai(_ s: NSButton) {
        if let t = s.identifier?.rawValue, !t.isEmpty { onCai?(t) }
    }
}

// MARK: - Màn 22: Hành trình & cổng người

/// Màn duy nhất trong bảng UXD-13 §2 KHÔNG gắn năng lực nào (`nang_luc: []`).
///
/// Nó không hiện dữ liệu của một năng lực mà hiện **trạng thái của chính dòng công việc**:
/// chuỗi đang chạy tới đâu, đang tắc ở cổng nào, và ai phải ra quyết định tiếp theo. Nguồn:
/// `queue.list` (mục đang chờ) và `autonomy.get`.
public final class FlowMapView: ManHinhCoSo {

    public var onMoMuc: ((String) -> Void)?

    public private(set) var soDangCho = 0
    public private(set) var mucTuChu = ""
    public private(set) var dangDungKhan = false

    /// Chín cổng của POL-17 (`rules.yaml`), theo thứ tự một việc đi qua chúng.
    ///
    /// Thứ tự ở đây là thứ tự THỜI GIAN, không phải bảng chữ cái: người nhìn màn này để biết
    /// việc đang tắc ở đâu, nên các cổng phải xếp theo đường đi của việc.
    ///
    /// Danh sách này đếm được từ `rules.yaml` chứ không chép từ trí nhớ — bản đầu tôi viết bảy
    /// cổng và thiếu mất `G-TOOL` (công cụ tác tử tự viết) với `G-WL` (thêm vào danh sách
    /// trắng). Thiếu đúng hai cổng canh chỗ hệ thống tự mở rộng quyền của mình, và chúng sẽ
    /// hiện ra dưới nhãn "KHÔNG có trong POL-17" — một lời buộc tội sai nhắm vào tài liệu.
    public static let congTheoThuTu: [(ma: String, ten: String)] = [
        ("G-SRC", "nguồn tài liệu vào kho"),
        ("G-FACT", "fact vào tri thức"),
        ("G1", "kế hoạch"),
        ("G-TOOL", "công cụ tác tử tự viết"),
        ("G3", "diff mã"),
        ("G4", "nạp/chạy phần cứng"),
        ("G5", "công bố ra ngoài"),
        ("G-OPS", "thao tác vận hành"),
        ("G-WL", "thêm vào danh sách trắng"),
    ]

    public init() { super.init(ten: "Hành trình & cổng người") }

    /// **Cổng KHÔNG có mục chờ vẫn hiện ra.**
    ///
    /// Chỉ hiện những cổng đang tắc thì người dùng thấy một danh sách ngắn và không biết nó
    /// ngắn vì mọi thứ trôi chảy hay vì màn hình chỉ biết bấy nhiêu. Bảy cổng luôn hiện đủ, cái
    /// nào rỗng thì nói là rỗng — đó cũng chính là cách `sim.*` phân biệt "đạt" với "không
    /// quan sát được".
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soDangCho = 0; mucTuChu = ""; dangDungKhan = false

        let muc = (ketQua["items"] as? [[String: Any]]) ?? []
        mucTuChu = (ketQua["autonomy"] as? String) ?? ""
        dangDungKhan = (ketQua["stopped"] as? Bool) ?? false
        soDangCho = muc.count

        var d: [String] = []
        if !mucTuChu.isEmpty { d.append("tự chủ \(mucTuChu)") }
        d.append(soDangCho == 0 ? "không có mục nào chờ" : "\(soDangCho) mục chờ anh")
        if dangDungKhan { d.append("ĐANG DỪNG KHẨN") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (dangDungKhan || soDangCho > 0)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        if dangDungKhan {
            let v = noiRong("Dừng khẩn đang bật: mức tự chủ đã về A0 và mọi việc tự động đều "
                          + "ngừng. Đặt lại mức tự chủ để chạy tiếp.")
            v.textColor = EideToken.Mau.bad
        }

        // Nhóm mục chờ theo cổng, rồi hiện ĐỦ bảy cổng.
        var theoCong: [String: [[String: Any]]] = [:]
        for m in muc {
            let g = (m["gate"] as? String) ?? (m["kind"] as? String) ?? "?"
            theoCong[g, default: []].append(m)
        }

        for c in Self.congTheoThuTu {
            let ds = theoCong[c.ma] ?? []
            themDong("\(c.ma) — \(c.ten)",
                     ds.isEmpty ? "không có gì chờ" : "\(ds.count) mục chờ anh quyết",
                     mau: ds.isEmpty ? EideToken.Mau.muted : EideToken.Mau.warn)
            for m in ds {
                let id = (m["gate_id"] as? String) ?? (m["id"] as? String) ?? ""
                let vi = (m["reason"] as? String) ?? (m["capability"] as? String) ?? ""
                themDong("  · \(id)", vi, mau: EideToken.Mau.text,
                         nut: !id.isEmpty, ma: id, bam: #selector(moMuc(_:)))
            }
        }

        // Cổng lạ — có mục chờ ở một cổng không nằm trong bảy cái trên. Không nuốt nó đi: nó
        // nghĩa là POL-17 và mã đã lệch nhau, và màn này là chỗ duy nhất nhìn thấy điều đó.
        let biet = Set(Self.congTheoThuTu.map(\.ma))
        for (g, ds) in theoCong.sorted(by: { $0.key < $1.key }) where !biet.contains(g) {
            themDong("\(g) — KHÔNG có trong POL-17", "\(ds.count) mục chờ",
                     mau: EideToken.Mau.bad)
        }
    }

    @objc private func moMuc(_ s: NSButton) {
        if let m = s.identifier?.rawValue, !m.isEmpty { onMoMuc?(m) }
    }
}
