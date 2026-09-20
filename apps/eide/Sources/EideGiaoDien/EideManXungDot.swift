import AppKit
import EideLoi

/// **S8 — Xung đột tri thức.** UXC-31 §8 S8; năng lực `view.conflict_board` (VIEW-04),
/// `kg.conflicts` (KG-02), `kg.resolve_conflict` (KG-06).
///
/// ## Vì sao màn này tồn tại
///
/// Hai nguồn của hãng nói hai con số khác nhau về cùng một thanh ghi. Không màn nào khác trong
/// sản phẩm được phép quyết chuyện ấy: KG-06 ghi `ask: Luôn` và trả **E3000 nếu actor=policy**,
/// vì một tác tử tự chọn giữa hai fact mâu thuẫn chính là cách một sai lệch tri thức trở thành
/// sự thật trong store — rồi thành một hằng số trong firmware.
///
/// ## Ba điều màn này phải nói mà dữ liệu không tự nói
///
/// 1. **`resource_ready = false` KHÁC "sạch".** `kg.conflicts` kiểm hai loại xung đột; loại tài
///    nguyên cần bảng `hw_map` của mốc M2. Chưa có bảng thì nó trả rỗng — và "không thấy" đọc
///    thành "không có" là đúng loại im lặng mà cả kho này dành nhiều công để tránh.
/// 2. **Bấm một nút ở đây KHÔNG áp dụng ngay.** KG-06 là R1/T2 qua cổng G-FACT, nên lời gọi
///    dừng ở `pending` và rơi vào *Chờ tôi*. Một màn nói "đã xong" lúc ấy là nói sai.
/// 3. **Rỗng phải kèm quyết định gần nhất**, đúng câu UXC-31 quy định — vì "không còn xung đột"
///    và "chưa bao giờ có xung đột nào" là hai tình trạng khác hẳn nhau.
public final class EideManXungDot: EideManCoSo {

    public override class var tien: String { "XungDot" }

    /// Số bản ghi sổ cái đọc ngược để tìm quyết định gần nhất cho trạng thái rỗng.
    public static let TIM_LUI = 200

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi

        // Hai lời gọi cho hai câu hỏi khác nhau, không phải một lời gọi thừa: `conflict_board`
        // trả HÀNG đã dựng sẵn hai vế (VIEW-04 sinh ra để làm đúng việc ấy), còn `resource_ready`
        // chỉ có trong `kg.conflicts` — và nó là thứ nói rằng bảng dưới đây đã kiểm hết chưa.
        // Dự án vừa tạo CHƯA có `store.sqlite` — nó chỉ ra đời khi có thứ đầu tiên cần ghi vào.
        // `view.conflict_board` gặp chuyện ấy trả E2000, và E2000 ở đây KHÔNG phải một sự cố:
        // nó là câu "dự án này chưa có tri thức nào". Để nguyên thì màn hiện "không đọc được:
        // … (E2000)" và đẩy người đi kiểm daemon — một việc không hỏng.
        guard let bang = try await nangLucNeuCo(goi, "view.conflict_board") else {
            return rong(vi: "dự án này chưa có store tri thức — chưa thứ gì được nhập vào",
                        buocKe: "nhập datasheet/SVD ở màn Nhập tài liệu (S4); xung đột chỉ xuất "
                              + "hiện khi có từ hai nguồn nói về cùng một thứ")
        }
        let rows = (bang["rows"] as? [[String: Any]]) ?? []
        let tho = try? await nangLuc(goi, "kg.conflicts")
        let sanSang = (tho?["resource_ready"] as? Bool) ?? true

        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        if !sanSang { _bangChuaKiem() }

        guard !rows.isEmpty else {
            let gan = await _quyetDinhGanNhat(goi)
            return rong(vi: "không còn xung đột tri thức nào đang mở"
                          + (sanSang ? "" : " — nhưng phần TÀI NGUYÊN chưa được kiểm, xem băng trên"),
                        buocKe: gan.map { "quyết định gần nhất: \($0)" }
                            ?? "chưa có quyết định nào — xung đột xuất hiện khi hai nguồn nói "
                             + "khác nhau về cùng một thứ, thường sau một lần `extract.pdf_errata`")
        }

        tieuDePhu("\(rows.count) XUNG ĐỘT ĐANG MỞ")
        for r in rows { them(_the(r)) }
        them(cocBao)
    }

    // MARK: - dựng thẻ

    private func _the(_ r: [String: Any]) -> NSView {
        let ma = (r["conflict_id"] as? String) ?? "?"
        let chuThe = (r["subject"] as? String) ?? "?"
        let viTu = (r["predicate"] as? String) ?? "?"
        // **`detail` KHÔNG lên thẻ.** Nó là một CÂU do lõi dựng cho sổ cái, và chính docstring
        // của `kg._hai_ben` đã ghi vì sao nó vô dụng ở đây: câu thì không chia cột, không tô
        // theo tầng, không sắp xếp được. Tệ hơn, đo 20/09 trên cửa sổ thật: câu ấy in giá trị ở
        // HỆ 10 (`'1073763328' ≠ '1073764352'`) và gọi nguồn bằng mã băm (`s_rm`), nằm ngay
        // trên hai cột in đúng cùng hai con số ở hệ 16 kèm tên tệp. Một màn, hai cách đọc cùng
        // một dữ liệu, và cách tệ hơn đứng trước.
        let t = EideTheXungDot(
            ma: ma,
            tieuDe: "\(EideManHoChieu.duoiCung(chuThe)) · \(viTu)",
            phuDe: Self.chuTheDayDu(chuThe),
            a: Self.ve(r["a"], nhan: "A", viTu: viTu),
            b: Self.ve(r["b"], nhan: "B", viTu: viTu),
            // KG-06 `choice` là enum ba giá trị. Nút thứ ba có mặt vì nhánh `both_conditional`
            // là nhánh ĐÚNG của trường hợp thường gặp nhất: errata chỉ áp cho một revision, nên
            // cả hai fact đều đúng, mỗi cái cho một rev.
            them: [("Cả hai — có điều kiện", "both_conditional")])
        t.onChon = { [weak self] ma, chon in
            Task { await self?._chon(ma, chon) }
        }
        return t
    }

    /// Một vế `{fact_id, value, tier, status, source}` → thứ người đọc để quyết.
    ///
    /// Giá trị đi qua đúng bộ định dạng của màn Hộ chiếu chip: một địa chỉ hiện ở hệ 10 tại đây
    /// thì người phải tự đổi hệ trong đầu để so với datasheet — mà so với datasheet chính là
    /// việc họ đang làm khi đứng trước màn này.
    static func ve(_ x: Any?, nhan: String, viTu: String) -> EideVeXungDot {
        let d = (x as? [String: Any]) ?? [:]
        let tang = Self.tangTrongThe((d["tier"] as? String) ?? "", (d["status"] as? String) ?? "")
        var phu: [(String, String)] = [("tầng", tang)]
        if let s = d["source"] as? String, !s.isEmpty {
            phu.append(("nguồn", EideManHoChieu.tenTep(s)))
        }
        if let f = d["fact_id"] as? String { phu.append(("fact", String(f.suffix(8)))) }
        return EideVeXungDot(nhan: "\(nhan) · \(tang)",
                             giaTri: EideManHoChieu.giaTriTheoViTu(d["value"], viTu),
                             phu: phu,
                             khoa: nhan.lowercased())
    }

    /// Nhãn tầng BÊN TRONG một thẻ xung đột — khác nhãn ở màn Hộ chiếu chip đúng một điểm.
    ///
    /// Hai trạng thái bị bỏ qua ở đây: `conflict` và `normalized`.
    ///
    /// Lý do đo được 20/09 trên cửa sổ thật. Khi hai fact mâu thuẫn, lõi chỉ đánh dấu `conflict`
    /// cho fact ĐẾN SAU; fact đến trước giữ nguyên `normalized`. Dùng chung nhãn với màn Hộ
    /// chiếu chip thì vế A hiện "vàng · chưa duyệt" còn vế B hiện "⚠ XUNG ĐỘT" — đọc như thể
    /// chỉ một bên đang bị tranh chấp, trong khi cả thẻ tồn tại vì CẢ HAI đang tranh chấp.
    ///
    /// Hai chữ ấy đều ĐÚNG và đều KHÔNG PHÂN BIỆT: trong một thẻ xung đột, không vế nào đã
    /// duyệt và cả hai đều đang tranh chấp — theo đúng cấu tạo của thẻ. Một nhãn đúng mà chỉ
    /// hiện ở một bên thì dựng ra một khác biệt không có thật, và khác biệt là đúng thứ người
    /// đang tìm khi họ đứng trước hai con số để chọn.
    ///
    /// Các trạng thái CÓ phân biệt thì giữ nguyên: `superseded`, `rejected`, `reviewed`.
    static func tangTrongThe(_ tier: String, _ status: String) -> String {
        EideManHoChieu.nhanTang(tier, ["conflict", "normalized"].contains(status) ? "" : status)
    }

    /// Chủ thể đầy đủ làm dòng phụ — tiêu đề đã rút gọn còn `I2C1 · base_address`, và IRI đầy
    /// đủ là thứ người copy ra để tra ở chỗ khác.
    static func chuTheDayDu(_ s: String) -> String { s }

    // MARK: - hành động

    /// Người chọn một vế.
    ///
    /// **Không bóc vỏ bằng `doc()` ở đây.** `EideKetQua.boc` ném khi lượt chạy không `done`, mà
    /// với KG-06 thì `pending` là kết cục ĐÚNG chứ không phải lỗi: cổng G-FACT hỏi người, và
    /// mục hỏi ấy nằm ở *Chờ tôi*. Bóc bằng `doc()` sẽ biến đường đi đúng của chính sách thành
    /// một dòng đỏ.
    private func _chon(_ ma: String, _ chon: String) async {
        guard let goi = goiLoi else { return }
        _xoaBao()
        // `both_conditional` đòi `condition` (KG-06 trả E1000 nếu thiếu). Hỏi ngay tại chỗ:
        // điều kiện là một câu của người, không phải thứ giao diện đặt hộ được.
        var tham: [String: Any] = ["conflict_id": ma, "choice": chon, "actor": Self.nguoi()]
        if chon == "both_conditional" {
            guard let dk = Self.hoiDieuKien() else {
                return _bao("Đã bỏ qua — giữ cả hai fact cần một điều kiện nói rõ mỗi fact đúng "
                            + "cho trường hợp nào.", mau: EideToken.Mau.muted)
            }
            tham["condition"] = dk
        }
        do {
            let r = try await goi("caps.invoke", ["id": "kg.resolve_conflict", "params": tham])
            switch r["status"] as? String {
            case "done":
                let hien = ((r["result"] as? [String: Any])?["current"] as? String) ?? "?"
                _bao("Đã áp dụng — fact hiện hành: \(hien). Hoàn tác được trong cửa sổ hoàn tác "
                     + "(`supersede_facts`).", mau: EideToken.Mau.ok)
                await nap(goi)
            case "pending":
                _bao("Đã gửi — chưa ghi vào store. " + Self.vinao(r["decision"])
                     + " Mục đang nằm ở CHỜ TÔI bên cột phải; duyệt ở đó thì store mới đổi.",
                     mau: EideToken.Mau.warn)
            default:
                let e = (r["error"] as? [String: Any]) ?? [:]
                _bao("Không áp dụng được: \((e["message"] as? String) ?? "\(r["status"] ?? "?")")"
                     + ((e["eide_code"] as? String).map { " (\($0))" } ?? ""),
                     mau: EideToken.Mau.bad)
            }
        } catch {
            _bao("Không gọi được lõi: \(error)", mau: EideToken.Mau.bad)
        }
    }

    /// Câu "vì sao còn phải chờ", dựng từ chính quyết định của cổng.
    ///
    /// Đo 20/09 trên lõi thật: lời gọi này dừng ở `{decision: ASK, rule: DEFAULT, gate: "*",
    /// reason: "Năng lực mức T2 — mặc định hỏi người"}` — tức quy tắc BẮT HẾT theo mức tự chủ,
    /// không phải một quy tắc G-FACT. Bản đầu của màn viết cứng "cổng G-FACT hỏi người": một
    /// câu nghe có thẩm quyền, khớp tài liệu, và KHÔNG khớp thứ máy vừa trả về. `gate = "*"`
    /// thì in ra "cổng *" cũng vô nghĩa, nên tên cổng chỉ hiện khi nó là một cổng thật.
    static func vinao(_ x: Any?) -> String {
        let qd = (x as? [String: Any]) ?? [:]
        let luat = (qd["rule"] as? String) ?? ""
        let cong = (qd["gate"] as? String) ?? ""
        let ly = (qd["reason"] as? String) ?? "cổng chính sách hỏi người trước khi ghi"
        var dau = ly
        if !luat.isEmpty { dau += " (luật \(luat)" + (cong.isEmpty || cong == "*" ? ")" : ", cổng \(cong))") }
        return dau + "."
    }

    /// Tên người chịu trách nhiệm, ghi vào `fact.confirmed_by`.
    ///
    /// Dạng `human:<tên>` theo quy ước tác giả máy-đọc-được của `eide_core/git.py`. Gói cũ gửi
    /// chuỗi trần `"human"`, và chuỗi ấy làm hỏng đúng điều UXC-31 §8 S8 đòi ở dòng lịch sử:
    /// *ghi TÊN NGƯỜI và thời điểm*. "human" không phải một cái tên.
    static func nguoi() -> String { "human:" + NSUserName() }

    /// Hỏi điều kiện cho nhánh `both_conditional`.
    static func hoiDieuKien() -> String? {
        let a = NSAlert()
        a.messageText = "Giữ cả hai fact — với điều kiện nào?"
        a.informativeText = "Ví dụ: \"errata áp cho rev B trở đi\". Câu này đi vào store cùng "
                          + "hai fact, và là thứ người sau đọc để biết vì sao cả hai cùng đúng."
        a.addButton(withTitle: "Ghi")
        a.addButton(withTitle: "Bỏ qua")
        let o = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        o.placeholderString = "điều kiện áp dụng"
        a.accessoryView = o
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        let t = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - băng và tra cứu

    private func _bangChuaKiem() {
        let n = NSTextField(wrappingLabelWithString:
            "Xung đột TÀI NGUYÊN chưa được kiểm — store này chưa có bảng `hw_map` (mốc M2). "
            + "Bảng dưới chỉ phủ xung đột FACT; \"không thấy\" ở đây không có nghĩa là sạch.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)
    }

    /// Quyết định xung đột gần nhất, đọc từ SỔ CÁI.
    ///
    /// `kg.resolve_conflict` ghi một bản ghi `gate.human` kèm `note` bắt đầu bằng tên năng lực
    /// — nên lịch sử quyết định không cần một bảng riêng, và không có đường nào để màn này hiện
    /// một quyết định mà sổ cái không có.
    private func _quyetDinhGanNhat(_ goi: @escaping EideGoi) async -> String? {
        guard let r = try? await doc(goi, "view.timeline", ["limit": Self.TIM_LUI]),
              let ds = r["events"] as? [[String: Any]] else { return nil }
        for e in ds.reversed() {
            guard (e["kind"] as? String) == "gate.human",
                  let d = e["data"] as? [String: Any],
                  let note = d["note"] as? String,
                  note.hasPrefix("kg.resolve_conflict") else { continue }
            let ai = (d["by"] as? String) ?? "?"
            return "\(note) — \(ai), \(EideManNhatKy.gio(e["at"] as? String))"
        }
        return nil
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
