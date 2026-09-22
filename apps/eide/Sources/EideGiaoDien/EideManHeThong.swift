import AppKit
import EideLoi

/// **S21 — Môi trường.** UXC-31 §8 S21; `env.check` (ENV-02), `env.guide_install` (ENV-04).
///
/// ## "Nút sửa KHÔNG bao giờ chạy sudo"
///
/// Câu ấy của UXC-31 không phải một lời khuyên về bảo mật — nó là ranh giới quyền. `env.install`
/// là năng lực **R4** duy nhất của cả nhóm, và cách nó giữ an toàn là đi qua danh sách trắng đã
/// ký (POL-17 §3). Một nút "sửa giúp tôi" chạy `sudo` sẽ vòng qua đúng cơ chế ấy. Nên nút ở đây
/// gọi `env.guide_install` (R0) — nó trả về CÁC BƯỚC cho người tự làm, không tự làm hộ.
public final class EideManMoiTruong: EideManCoSo {

    public override class var tien: String { "Env" }

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        let bc = try await nangLuc(goi, "project.status")
        let tg = ((bc["report"] as? [String: Any])?["target"] as? [String: Any]) ?? [:]
        let isa = (tg["isa"] as? String) ?? ""
        guard !isa.isEmpty else {
            return rong(vi: "dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, "
                          + "không theo máy",
                        buocKe: "ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy "
                              + "ISA từ `family_patterns` của manifest")
        }

        guard let r = try? await nangLuc(goi, "env.check", ["isa": isa]),
              let ds = r["report"] as? [[String: Any]], !ds.isEmpty else {
            return rong(vi: "`env.check` không trả công cụ nào cho ISA `\(isa)`",
                        buocKe: "kiểm `docs/spec/isa/\(isa).yaml` có mục `toolchain` không")
        }

        let thieu = ds.filter { ($0["ok"] as? Bool) != true }
        let batBuoc = thieu.filter { ($0["required"] as? Bool) == true }
        if !thieu.isEmpty { _bangThieu(batBuoc.count, thieu.count) }

        // Gọi thẳng tên "ISA" chứ không chỉ in giá trị của nó. `avr8` là một chuỗi ký tự; câu
        // *"ISA của dự án này là avr8, và nó cần những công cụ sau"* mới là thứ người đọc dùng
        // được — nhất là khi họ vừa từ màn Hộ chiếu chip sang để hiểu vì sao lệnh dựng hỏng.
        tieuDePhu("ISA CỦA DỰ ÁN: `\(isa)` — CHUỖI DỰNG CẦN \(ds.count) CÔNG CỤ"
                  + (thieu.isEmpty ? ", có đủ" : ", THIẾU \(thieu.count)"))
        bang(cot: [("CÔNG CỤ", 150), ("CẦN", 62), ("PHIÊN BẢN", 110), ("TỐI THIỂU", 92),
                   ("TRẠNG THÁI", 96), ("ĐƯỜNG DẪN", 0)],
             dong: ds.map { d in
                 [(d["tool"] as? String) ?? "?",
                  ((d["required"] as? Bool) == true) ? "bắt buộc" : "tuỳ",
                  (d["version"] as? String) ?? "—",
                  (d["min"] as? String) ?? "—",
                  Self.oTrangThai(d),
                  (d["found"] as? String) ?? "chưa cài"]
             })

        for d in thieu.prefix(6) where (d["tool"] as? String) != nil {
            let b = NSButton(title: "Cách cài \(d["tool"] as! String)",
                             target: self, action: #selector(_huongDan(_:)))
            b.bezelStyle = .inline
            b.identifier = NSUserInterfaceItemIdentifier(d["tool"] as! String)
            them(b)
        }
        them(cocBao)
    }

    /// Ba trạng thái, không hai: có mà CŨ khác hẳn không có.
    ///
    /// `ok` gộp cả hai thành `false`, nên bảng phải tự tách lại: một máy có `arm-none-eabi-gcc`
    /// 9.2 trong khi manifest đòi ≥ 12 cần một việc khác hẳn một máy chưa cài gì.
    public static func oTrangThai(_ d: [String: Any]) -> String {
        if (d["ok"] as? Bool) == true { return "✅ đạt" }
        let co = (d["found"] as? String) ?? ""
        if co.isEmpty { return "⛔ chưa cài" }
        return "⚠ có nhưng CŨ"
    }

    private func _bangThieu(_ batBuoc: Int, _ tong: Int) {
        let n = NSTextField(wrappingLabelWithString:
            batBuoc > 0
            ? "⛔ \(batBuoc)/\(tong) công cụ BẮT BUỘC chưa đạt — `code.build` sẽ dừng ở bước "
              + "dựng. Nút bên dưới chỉ CÁCH cài, không tự cài: `env.install` là năng lực R4 "
              + "và nó đi qua danh sách trắng đã ký."
            : "⚠ \(tong) công cụ tuỳ chọn chưa đạt — chuỗi dựng vẫn chạy, nhưng một số bước "
              + "(mô phỏng, đo kích thước) sẽ bỏ qua có báo.")
        n.font = EideToken.fontUI
        n.textColor = batBuoc > 0 ? EideToken.Mau.bad : EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = batBuoc > 0 ? EideToken.Mau.badBg : EideToken.Mau.warnBg
        them(n)
    }

    @objc private func _huongDan(_ n: NSButton) {
        guard let goi = goiLoi, let t = n.identifier?.rawValue else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                let r = try await nangLuc(goi, "env.guide_install", ["tool": t])
                hienHuongDan(t, r)
            } catch {
                _bao("Không lấy được hướng dẫn cho `\(t)`: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// Tách khỏi phần gọi lõi để bài đo đọc được.
    public func hienHuongDan(_ tool: String, _ r: [String: Any]) {
        _xoaBao()
        let buoc = (r["steps"] as? [Any]) ?? []
        let lien = (r["links"] as? [Any]) ?? []
        guard !buoc.isEmpty || !lien.isEmpty else {
            return _bao("Không có hướng dẫn cài cho `\(tool)` trong manifest ISA.",
                        mau: EideToken.Mau.warn)
        }
        _bao("Cách cài `\(tool)` — làm bằng tay, EIDE không chạy hộ:", mau: EideToken.Mau.text)
        for (i, b) in buoc.enumerated() {
            _bao("  \(i + 1). \(EideManHoChieu.giaTri(b))", mau: EideToken.Mau.muted)
        }
        for l in lien { _bao("  → \(EideManHoChieu.giaTri(l))", mau: EideToken.Mau.info) }
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

/// **S22 — Mô hình & chi phí.** UXC-31 §8 S22; `budget.state` (API-15 §1).
///
/// ## "Chạm hạn mức → sự kiện + băng cảnh báo, KHÔNG chạy tiếp im lặng"
///
/// Đó là cả lý do màn này tồn tại. Một tác tử tiêu tiền của người dùng mà không nói gì là thứ
/// hỏng nặng nhất trong nhóm HỆ THỐNG — nặng hơn một màn sai số, vì người dùng chỉ biết sau khi
/// hoá đơn về.
///
/// `sap_het` có BA giá trị, và giá trị thứ ba là phần đáng giữ: `nil` nghĩa là **chưa biết** vì
/// chưa đặt hạn mức, không phải "còn nhiều". Một cảnh báo ngân sách sai hướng thì hoặc làm
/// người ta hoảng, hoặc dạy người ta bỏ qua nó.
public final class EideManMoHinh: EideManCoSo {

    public override class var tien: String { "Models" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        let b = try await doc(goi, "budget.state")

        let sapHet = b["sap_het"] as? Bool
        if sapHet == true { _bangSapHet(b) }
        if b["daily_budget_usd"] == nil || b["daily_budget_usd"] is NSNull { _bangChuaDatHan() }

        tieuDePhu("NGÂN SÁCH MÔ HÌNH — HÔM NAY")
        bang(cot: [("MỤC", 178), ("GIÁ TRỊ", 0)], dong: [
            ["Đã tiêu", String(format: "%.4f USD", (b["spent_usd"] as? Double) ?? 0)],
            ["Hạn ngày", Self.oHanMuc(b["daily_budget_usd"])],
            ["Còn lại", Self.oHanMuc(b["remaining_usd"])],
            ["Số lời gọi", "\(EideManHoChieu.nguyen(b["calls_today"]) ?? 0)"],
            ["Ngưỡng cảnh báo", "\(EideManHoChieu.nguyen(b["warn_pct"]) ?? 0)% còn lại"],
            ["Sắp hết", Self.oSapHet(sapHet)],
        ])

        // Thanh hạn mức — UXC-31 đòi "thanh hạn mức", và một thanh chỉ vẽ được khi CÓ hạn.
        if let han = b["daily_budget_usd"] as? Double, han > 0 {
            them(EideThanhMuc(daTieu: (b["spent_usd"] as? Double) ?? 0, han: han,
                              nguong: Double(EideManHoChieu.nguyen(b["warn_pct"]) ?? 20)))
        }

        // v1.3 — bảng VAI → MÔ HÌNH. `budget.state` nay trả `roles` ([DEV-136]); tới 21/09
        // khối này phải nói thẳng rằng không năng lực nào đọc `models.yaml`.
        let vai = (b["roles"] as? [String: Any]) ?? [:]
        if vai.isEmpty {
            let n = NSTextField(wrappingLabelWithString:
                "Bảng VAI TRÒ → MÔ HÌNH rỗng — `models.yaml` chưa khai vai trò nào, hoặc daemon "
                + "không đọc được tệp ấy. Hạn mức và chi phí phía trên vẫn đúng: chúng cộng từ "
                + "SỔ CÁI, không từ cấu hình.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.muted
            them(n)
        } else {
            tieuDePhu("\(vai.count) VAI TRÒ → MÔ HÌNH — thứ tự ứng viên là thứ tự Gateway THỬ, "
                      + "không phải thứ tự ưu tiên viết tay")
            bang(cot: [("VAI TRÒ", 130), ("NHIỆT", 60), ("SCHEMA", 110),
                       ("ỨNG VIÊN (theo thứ tự thử)", 0)],
                 dong: vai.keys.sorted().map { ten in
                     let r = (vai[ten] as? [String: Any]) ?? [:]
                     return [ten,
                             Self.oNhiet(r["temperature"]),
                             (r["output_schema"] as? String) ?? "—",
                             Self.oUngVien(r["candidates"])]
                 })
        }

        await _khoiLuotGoi(goi)
    }

    /// **Lượt gọi mô hình gần nhất: vai trò · token vào/ra · giá · độ trễ.** [DEV-185]
    ///
    /// Bảng VAI TRÒ → MÔ HÌNH ở trên nói CẤU HÌNH; con số chi phí nói TỔNG. Giữa hai thứ ấy
    /// thiếu đúng cái người mở màn này cần khi thấy hoá đơn cao hơn dự tính: **lượt nào đã
    /// tiêu**. Không có nó thì câu trả lời duy nhất cho "vì sao hôm nay 3 USD" là mở sổ cái
    /// bằng tay và lọc `model.call`.
    ///
    /// Đọc từ sổ cái chứ không từ một bộ đếm riêng — cùng nguồn với `budget.state`, nên hai
    /// con số trên cùng màn hình không bao giờ lệch nhau.
    private func _khoiLuotGoi(_ goi: @escaping EideGoi) async {
        let r = try? await doc(goi, "view.timeline", ["limit": 200])
        let goiMo = (((r?["events"]) as? [[String: Any]]) ?? [])
            .filter { ($0["kind"] as? String) == "model.call" }
            .reversed().prefix(10)
        tieuDePhu("LƯỢT GỌI MÔ HÌNH GẦN NHẤT")
        guard !goiMo.isEmpty else {
            let n = NSTextField(wrappingLabelWithString:
                "Chưa có lượt gọi mô hình nào trong sổ cái — dự án này chưa tiêu token nào.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.muted
            them(n)
            return
        }
        bang(cot: [("LÚC", 116), ("VAI TRÒ", 104), ("MÔ HÌNH", 168),
                   ("TOKEN VÀO", 84), ("TOKEN RA", 78), ("GIÁ", 86), ("TRỄ", 0)],
             dong: goiMo.map { e in
                 let d = (e["data"] as? [String: Any]) ?? [:]
                 // Lượt HỎNG cũng hiện, và hiện rõ là hỏng: một lượt gọi lỗi vẫn tốn token vào
                 // ở phần lớn nhà cung cấp, nên giấu nó đi là giấu đúng phần chi phí người dùng
                 // không hiểu vì sao có.
                 let loi = (d["error_kind"] as? String).map { " ✖ \($0)" } ?? ""
                 return [EideManNhatKy.gio(e["at"] as? String),
                         (d["role"] as? String) ?? "—",
                         ((d["model_id"] as? String) ?? "—") + loi,
                         "\(EideManHoChieu.nguyen(d["tokens_in"]) ?? 0)",
                         "\(EideManHoChieu.nguyen(d["tokens_out"]) ?? 0)",
                         String(format: "%.4f USD", (d["cost_usd"] as? Double) ?? 0),
                         EideManHoChieu.nguyen(d["latency_ms"]).map { "\($0) ms" } ?? "—"]
             })
    }

    /// `nil` = vai không đặt nhiệt độ, tức Gateway dùng mặc định của nhà cung cấp. Hiện `0`
    /// cho một vai chưa đặt là nói rằng nó chạy XÁC ĐỊNH — trong khi nó không.
    public static func oNhiet(_ x: Any?) -> String {
        guard let n = EideManHoChieu.nguyen(x) ?? (x as? Double).map({ Int($0 * 100) })
        else { return "mặc định" }
        return (x as? Double).map { String(format: "%.1f", $0) } ?? "\(n)"
    }

    /// Ứng viên hiện CẢ bí danh lẫn model_id thật: `models.yaml` viết bí danh
    /// (`gemini-flash`), còn thứ người dùng đối chiếu với hoá đơn là tên thật.
    public static func oUngVien(_ x: Any?) -> String {
        let ds = (x as? [[String: Any]]) ?? []
        guard !ds.isEmpty else { return "— chưa khai ứng viên nào" }
        return ds.map { c in
            let bi = (c["alias"] as? String) ?? "?"
            let that = (c["model"] as? String) ?? bi
            return bi == that ? bi : "\(bi) → \(that)"
        }.joined(separator: "  ·  ")
    }

    /// `nil` là "chưa đặt hạn mức", không phải 0 USD. Hai câu ấy trái ngược nhau.
    public static func oHanMuc(_ x: Any?) -> String {
        guard let d = x as? Double else { return "chưa đặt" }
        return String(format: "%.2f USD", d)
    }

    /// Ba trạng thái — `nil` = chưa biết.
    public static func oSapHet(_ x: Bool?) -> String {
        guard let b = x else { return "chưa biết — chưa đặt hạn mức ngày" }
        return b ? "⚠ CÓ" : "không"
    }

    private func _bangSapHet(_ b: [String: Any]) {
        let n = NSTextField(wrappingLabelWithString:
            "⚠ SẮP HẾT NGÂN SÁCH NGÀY — còn \(Self.oHanMuc(b["remaining_usd"])) trên hạn "
            + "\(Self.oHanMuc(b["daily_budget_usd"])). Tác tử KHÔNG tự dừng; nó leo thang lên "
            + "anh (APD-08 §5). Đây là chỗ anh quyết nâng hạn hay dừng lượt chạy.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)
    }

    private func _bangChuaDatHan() {
        let n = NSTextField(wrappingLabelWithString:
            "Chưa đặt hạn mức ngày trong `models.yaml` (`policy.daily_budget_usd`). Không có "
            + "hạn thì không có cảnh báo — và \"chưa biết\" khác hẳn \"còn nhiều\".")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.muted
        them(n)
    }
}

/// Thanh hạn mức — một khung nhìn, vẽ bằng `draw(_:)`.
@MainActor
public final class EideThanhMuc: NSView {
    private let tiLe: Double
    private let nguong: Double

    public init(daTieu: Double, han: Double, nguong pct: Double) {
        tiLe = han > 0 ? min(1.2, daTieu / han) : 0
        nguong = max(0, min(1, 1 - pct / 100))
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 14).isActive = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override func draw(_ dirty: NSRect) {
        EideToken.Mau.border.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        // Vượt hạn thì ĐỎ, chưa tới ngưỡng thì xanh lá — và ngưỡng có vạch riêng, vì người cần
        // thấy mình còn bao xa tới nó chứ không chỉ thấy mình đang ở đâu.
        (tiLe >= 1 ? EideToken.Mau.bad : (tiLe >= nguong ? EideToken.Mau.warn : EideToken.Mau.ok))
            .setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * min(1, tiLe),
                                         height: bounds.height),
                     xRadius: 4, yRadius: 4).fill()
        EideToken.Mau.text.setFill()
        NSRect(x: bounds.width * nguong, y: 0, width: 1.5, height: bounds.height).fill()
    }
}

/// **S23 — Công cụ tự tạo.** UXC-31 §8 S23; sổ cái `tool.report`.
///
/// ## Đường thăng cấp bắt buộc qua sandbox + bài kiểm
///
/// UXC-31 đòi *"hiện số lần dùng ĐẠT"*, và con số ấy là điều kiện của `tool.promote`: TOOL-08
/// ghi "dùng ≥ 3 lần, 0 lỗi". Nên bảng này đếm theo `passed`, không đếm tổng số lần chạy — một
/// công cụ chạy 10 lần hỏng 7 thì con số "10" nói sai hoàn toàn về nó.
public final class EideManCongCu: EideManCoSo {

    public override class var tien: String { "ToolForge" }

    /// TOOL-08: "Dùng ≥ 3 lần, 0 lỗi".
    public static let NGUONG_THANG = 3

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        // v1.3 — đọc DANH MỤC qua `view.artifacts kind=tool` (VIEW-14), không dựng lại từ sổ
        // cái. [DEV-136]
        //
        // Bản cũ lọc `tool.report` trong 500 bản ghi gần nhất của `view.timeline`, và nó sai
        // theo hai chiều cùng lúc: một công cụ chạy nhiều từ lâu bị TRÔI ra khỏi cửa sổ 500 nên
        // biến mất khỏi danh mục, còn một dự án chạy dày thì 500 bản ghi không đủ tới công cụ
        // thứ hai. Phép gộp nay ở SQL, và `total` là SỐ CÔNG CỤ chứ không phải số lượt chạy.
        guard let r = try await nangLucNeuCo(goi, "view.artifacts", ["kind": "tool"]),
              let ds = r["items"] as? [[String: Any]] else {
            return rong(vi: "không đọc được danh mục công cụ từ store",
                        buocKe: "kiểm daemon còn sống rồi mở lại màn")
        }
        // `sim.run` cũng ghi `tool.report` (xem `sim.py`), nên không lọc thì nó hiện ra ở đây
        // như một công cụ tác tử tự viết. Năng lực DỰNG SẴN mang id có dấu chấm (`ns.name`);
        // công cụ tự tạo mang tên trần do `tool.write` đặt.
        let cc = ds.filter { !(($0["tool"] as? String) ?? "").contains(".") }
        guard !cc.isEmpty else {
            return rong(vi: "chưa công cụ nào của tác tử được chạy trong dự án này",
                        buocKe: "khi một chuỗi thiếu năng lực phù hợp, `tool.need` → "
                              + "`tool.write` → `tool.test` tự viết một công cụ; lượt chạy của "
                              + "nó hiện ở đây")
        }

        tieuDePhu("\(cc.count) CÔNG CỤ TỰ TẠO — gộp từ `tool_report` qua `view.artifacts` "
                  + "(VIEW-14). Thăng cấp cần: dùng ≥ \(Self.NGUONG_THANG) lần, 0 lỗi (TOOL-08)")
        bang(cot: [("CÔNG CỤ", 190), ("ĐẠT", 68), ("HỎNG", 68), ("THĂNG CẤP", 170),
                   ("LẦN CHẠY CUỐI", 0)],
             dong: cc.map { x in
                 let ten = (x["tool"] as? String) ?? "?"
                 let dat = EideManHoChieu.nguyen(x["dat"]) ?? 0
                 let tong = EideManHoChieu.nguyen(x["tong"]) ?? 0
                 return [ten, "\(dat)", "\(tong - dat)",
                         Self.oThangCap(dat: dat, hong: tong - dat),
                         EideManNhatKy.gio(x["at"] as? String)]
             })
    }

    /// Điều kiện thăng cấp, chép đúng TOOL-08 — và nó nói RÕ còn thiếu bao nhiêu.
    ///
    /// "Chưa đủ" mà không nói thiếu gì thì người đọc phải đi tra tài liệu để biết mình cần chạy
    /// thêm mấy lần.
    public static func oThangCap(dat: Int, hong: Int) -> String {
        // NGẮN, vì đây là một Ô BẢNG. Bản đầu nhét cả câu trích TOOL-08 vào đây và `catVua` của
        // `bang()` cắt mất đuôi — đúng như nó phải làm, nhưng phần bị cắt lại là phần mang
        // nghĩa. Câu trích luật nay nằm ở tiêu đề phụ, nơi có cả chiều ngang cho nó.
        if hong > 0 { return "⛔ \(hong) lượt hỏng" }
        if dat >= NGUONG_THANG { return "✅ đủ điều kiện" }
        return "⏳ cần thêm \(NGUONG_THANG - dat)"
    }
}

/// **S24 — Registry.** UXC-31 §8 S24; `registry.search` (REGISTRY-01).
///
/// ## Huy hiệu là thứ đắt nhất trong cả hệ thống
///
/// `registry.search` xếp theo BADGE trước rồi mới tới điểm khớp chuỗi, và docstring của nó nói
/// vì sao: một huy hiệu `verified_on_board` đòi một lần nạp firmware lên board thật. Bảng này
/// vì thế đặt cột huy hiệu trước cột phiên bản — thứ tự cột là thứ tự người nên đọc.
public final class EideManRegistry: EideManCoSo {

    public override class var tien: String { "Registry" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        // `q` rỗng: REGISTRY-01 trả RỖNG chứ không ném khi registry không tới được, nên một
        // truy vấn rộng là cách đọc danh mục mà không cần năng lực riêng.
        let r = try await nangLuc(goi, "registry.search", ["q": ""])
        let goi_ = (r["packages"] as? [[String: Any]]) ?? []
        guard !goi_.isEmpty else {
            return rong(vi: "registry chưa có gói nào tới được từ máy này",
                        buocKe: "`registry.seed` nạp danh mục cục bộ, hoặc trỏ `registry` trong "
                              + "`models.yaml` tới một chỉ mục có thật")
        }
        tieuDePhu("\(goi_.count) GÓI TRONG REGISTRY")
        bang(cot: [("GÓI", 190), ("HUY HIỆU", 150), ("CHỮ KÝ", 110), ("LICENSE", 110),
                   ("LOẠI", 0)],
             dong: goi_.map { d in
                 [(d["id"] as? String) ?? "?",
                  Self.oHuyHieu(d["badges"]),
                  Self.oChuKy(d["signature"] ?? d["signed"]),
                  (d["license"] as? String) ?? "—",
                  (d["kind"] as? String) ?? "—"]
             })
    }

    public static func oHuyHieu(_ x: Any?) -> String {
        let ds = ((x as? [Any]) ?? []).map { EideManHoChieu.giaTri($0) }
        return ds.isEmpty ? "—" : ds.joined(separator: " · ")
    }

    /// **Không chữ ký là một cảnh báo, không phải một ô trống.** Một gói chưa ký cài vào dự án
    /// là mã của người lạ chạy trên máy anh — POL-17 dựng `trusted_packages` đúng vì chuyện ấy.
    public static func oChuKy(_ x: Any?) -> String {
        if let s = x as? String, !s.isEmpty { return "✅ " + String(s.prefix(10)) }
        if (x as? Bool) == true { return "✅ có" }
        return "⚠ CHƯA KÝ"
    }
}
