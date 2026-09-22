import AppKit
import EideLoi

/// **S15 — Diff & cổng merge.** UXC-31 §8 S15 và §6.3; `code.review` (CODE-11),
/// `code.merge_conflict_resolve` (CODE-18), `view.artifacts` (VIEW-14).
///
/// ## §6.3 cấm viết màn riêng cho xung đột mã
///
/// > "Màn xung đột MÃ **tái dùng đúng component** màn Xung đột tri thức (S8): hai vế cùng hàng
/// > — *Người sửa hh:mm* / *Tác tử Run #n* — nút Chọn A / Chọn B / Soạn tay …
/// > **một component, hai nguồn dữ liệu — cấm viết màn riêng**."
///
/// Nên màn này dựng `EideTheXungDot` y như S8, chỉ đổi dữ liệu đổ vào. Lý do của luật ấy không
/// phải là tiết kiệm mã: hai màn quyết định trông khác nhau thì người dùng phải học hai lần
/// cách đọc một xung đột, và lần thứ hai họ học ở đúng lúc căng thẳng nhất — khi mã của họ và
/// mã của tác tử đang giẫm lên nhau.
///
/// ## Bảng cổng nói LÝ DO CHẶN, không chỉ nói trạng thái
///
/// UXC-31 đòi *"mỗi cổng trạng thái ✅/⛔/⏳ + lý do chặn bấm mở đúng chỗ"*. Một bảng bốn dòng
/// toàn dấu ⛔ mà không nói vì sao thì người đọc chỉ biết mình bị chặn, không biết phải làm gì —
/// và cổng chính sách trở thành một bức tường thay vì một danh sách việc.
public final class EideManDiffMerge: EideManCoSo {

    public override class var tien: String { "DiffMerge" }

    /// Bốn cổng của đường merge, đúng thứ tự UXC-31 §8 S15 nêu.
    public static let CONG = ["G-FACT", "G1", "G3", "G4", "G5"]

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        // Xung đột mã: cùng đường với S8 nhưng khác nguồn — `kg.conflicts` trả xung đột FACT,
        // còn xung đột MÃ nằm ở hàng đợi dưới dạng mục chờ của `code.merge_conflict_resolve`.
        let cho = ((try? await doc(goi, "queue.list"))?["items"] as? [[String: Any]]) ?? []
        let xd = cho.filter { Self.laXungDotMa($0) }

        if !xd.isEmpty {
            tieuDePhu("\(xd.count) XUNG ĐỘT MÃ ĐANG CHỜ QUYẾT")
            for m in xd { them(_the(m)) }
        }

        let cong = Self.bangCong(cho)
        tieuDePhu("CỔNG TRÊN ĐƯỜNG MERGE")
        bang(cot: [("CỔNG", 96), ("TRẠNG THÁI", 110), ("LÝ DO / VIỆC CẦN LÀM", 0)], dong: cong)

        await _khoiBonCongCu(goi)

        them(cocBao)
        guard xd.isEmpty else { return }
        // Không có xung đột KHÔNG có nghĩa là merge được: bảng cổng ở trên mới nói điều đó.
        _bao("Không có xung đột mã nào đang chờ. Bảng cổng phía trên nói đường merge đã thông "
             + "chưa — hai câu ấy khác nhau.", mau: EideToken.Mau.muted)
    }

    /// Bốn cổng công cụ mà G3 đòi — POL-17 G3, BPD §10 ("4 cổng công cụ đạt, reviewer khác
    /// hãng PASS, diff trong phạm vi").
    ///
    /// Danh sách CỐ ĐỊNH và hiện đủ bốn dòng kể cả khi chưa chạy cái nào. Chỉ liệt kê những
    /// công cụ ĐÃ có báo cáo thì một bảng trống đọc như "không có yêu cầu nào" — trong khi sự
    /// thật là "bốn yêu cầu, chưa cái nào chạy".
    public static let BON_CONG_CU = ["build", "static", "test", "size"]

    /// **Kết quả 4 công cụ kiểm + reviewer khác hãng** — §8 S19. [DEV-185]
    ///
    /// Đây là BẰNG CHỨNG mà G3 dùng để quyết. Bảng cổng ở trên nói cổng đã quyết gì; khối này
    /// nói dựa vào đâu. Thiếu nó thì người duyệt G3 bấm "Duyệt" mà không thấy thứ mình đang
    /// duyệt — và POL-17 sinh ra chính là để chuyện đó không xảy ra.
    private func _khoiBonCongCu(_ goi: @escaping EideGoi) async {
        let r0 = try? await nangLuc(goi, "view.artifacts", ["kind": "tool", "limit": 50])
        let bc = (r0?["items"] as? [[String: Any]]) ?? []
        // Báo cáo mới nhất của mỗi công cụ — `view.artifacts` sắp theo `at`, nên lần gán sau
        // đè lần trước.
        var moiNhat: [String: [String: Any]] = [:]
        for r in bc { if let t = r["tool"] as? String { moiNhat[t] = r } }

        tieuDePhu("BẰNG CHỨNG CHO G3 — 4 CÔNG CỤ KIỂM + REVIEWER KHÁC HÃNG")
        var dong: [[String]] = Self.BON_CONG_CU.map { t in
            guard let r = moiNhat[t] else { return [t, "⏳ chưa chạy", "—", "—"] }
            let dat = (r["passed"] as? Bool) ?? ((EideManHoChieu.nguyen(r["passed"]) ?? 0) == 1)
            return [t, dat ? "✅ đạt" : "⛔ KHÔNG đạt",
                    "\(EideManHoChieu.nguyen(r["tong"]) ?? 0)",
                    EideManNhatKy.gio(r["at"] as? String)]
        }
        // Reviewer khác hãng là điều kiện THỨ NĂM và nó không phải một công cụ — `code.review`
        // ghi báo cáo dưới tên riêng. Gộp vào cùng bảng vì với người duyệt, cả năm là một danh
        // sách kiểm; tách ra hai bảng là để họ quên mất cái thứ năm.
        if let r = moiNhat["review"] ?? moiNhat["reviewer"] {
            let dat = (r["passed"] as? Bool) ?? false
            dong.append(["reviewer khác hãng", dat ? "✅ PASS" : "⛔ KHÔNG PASS",
                         "\(EideManHoChieu.nguyen(r["tong"]) ?? 0)",
                         EideManNhatKy.gio(r["at"] as? String)])
        } else {
            dong.append(["reviewer khác hãng", "⏳ chưa chạy", "—",
                         "`code.review` chấm checklist"])
        }
        bang(cot: [("CÔNG CỤ", 180), ("KẾT QUẢ", 130), ("SỐ MỤC", 84), ("LÚC", 0)], dong: dong)
    }

    /// Một mục chờ có phải XUNG ĐỘT MÃ không.
    public static func laXungDotMa(_ m: [String: Any]) -> Bool {
        let cap = (m["cap"] as? String) ?? ""
        return cap == "code.merge_conflict_resolve" || cap == "code.merge"
            || (m["conflict_id"] != nil && cap.hasPrefix("code."))
    }

    /// Bảng cổng — ✅/⛔/⏳ kèm LÝ DO.
    ///
    /// `⏳` là trạng thái thứ ba và nó không thừa: "chưa chạy" khác hẳn "chạy rồi và đạt". Gộp
    /// hai cái thành ✅ là nói với người dùng rằng một cổng chưa ai mở đã mở.
    public static func bangCong(_ cho: [[String: Any]]) -> [[String]] {
        var theoCong: [String: [String: Any]] = [:]
        for m in cho {
            let qd = (m["decision"] as? [String: Any]) ?? [:]
            let g = (qd["gate"] as? String) ?? ""
            if CONG.contains(g) { theoCong[g] = qd }
        }
        return CONG.map { g in
            guard let qd = theoCong[g] else { return [g, "⏳ chưa chạy", "cổng này chưa có lời gọi nào đi qua trong phiên"] }
            let quyet = (qd["decision"] as? String) ?? "?"
            return [g,
                    quyet == "APPROVE" ? "✅ qua" : (quyet == "REJECT" ? "⛔ chặn" : "⛔ chờ anh"),
                    (qd["reason"] as? String) ?? "—"]
        }
    }

    /// Thẻ một xung đột mã — **cùng component với S8** (§6.3).
    private func _the(_ m: [String: Any]) -> NSView {
        let ma = (m["conflict_id"] as? String) ?? (m["run_id"] as? String) ?? "?"
        let tep = (m["path"] as? String) ?? (m["file"] as? String) ?? "?"
        let t = EideTheXungDot(
            ma: ma,
            tieuDe: EideManHoChieu.tenTep(tep) + Self.vungSua(m),
            phuDe: tep,
            a: Self.ve(m["human"] ?? m["a"], nhan: Self.nhanNguoi(m), khoa: "a"),
            b: Self.ve(m["agent"] ?? m["b"], nhan: Self.nhanTacTu(m), khoa: "b"),
            // Nút thứ ba của xung đột MÃ khác của xung đột FACT: "Soạn tay" thay cho "Cả hai —
            // có điều kiện". Hai vùng mã giẫm lên nhau không gộp được bằng một điều kiện.
            them: [("Soạn tay", "manual")])
        t.onChon = { [weak self] ma, chon in
            Task { await self?._quyet(ma, chon) }
        }
        return t
    }

    /// Nhãn vế NGƯỜI — "Người sửa hh:mm", đúng chữ của §6.3.
    public static func nhanNguoi(_ m: [String: Any]) -> String {
        let luc = EideManNhatKy.gio((m["human_at"] as? String) ?? (m["at"] as? String))
        return "Người sửa \(luc == "—" ? "" : String(luc.suffix(8)))".trimmingCharacters(in: .whitespaces)
    }

    /// Nhãn vế TÁC TỬ — "Tác tử Run #n".
    public static func nhanTacTu(_ m: [String: Any]) -> String {
        let r = (m["run_id"] as? String) ?? (m["agent_run"] as? String) ?? ""
        return r.isEmpty ? "Tác tử" : "Tác tử Run \(r.prefix(8))"
    }

    public static func vungSua(_ m: [String: Any]) -> String {
        guard let a = EideManHoChieu.nguyen(m["line"]) else { return "" }
        let b = EideManHoChieu.nguyen(m["line_end"]) ?? a
        return " · dòng \(a)\(b > a ? "–\(b)" : "")"
    }

    static func ve(_ x: Any?, nhan: String, khoa: String) -> EideVeXungDot {
        let d = (x as? [String: Any]) ?? [:]
        let ma = (d["content"] as? String) ?? (d["text"] as? String) ?? (x as? String) ?? "—"
        var phu: [(String, String)] = []
        if let ai = d["by"] as? String, !ai.isEmpty { phu.append(("tác giả", ai)) }
        if let c = d["commit"] as? String, !c.isEmpty { phu.append(("commit", String(c.prefix(10)))) }
        return EideVeXungDot(nhan: nhan, giaTri: ma, phu: phu, khoa: khoa)
    }

    private func _quyet(_ ma: String, _ chon: String) async {
        guard let goi = goiLoi else { return }
        _xoaBao()
        guard chon != "manual" else {
            // "Soạn tay" KHÔNG gọi năng lực: nó đưa người về trình soạn thảo. Tự ghi một bản
            // hợp nhất rồi gọi là quyết thay họ đúng lúc họ vừa nói mình muốn tự làm.
            return _bao("Mở màn Trình soạn thảo (S14) và sửa tay vùng ấy, rồi Lưu — "
                        + "`code.human_save` ghi commit mang tên anh. Xung đột vẫn nằm nguyên "
                        + "trong CHỜ TÔI cho tới lúc ấy.", mau: EideToken.Mau.muted)
        }
        do {
            let r = try await goi("caps.invoke", ["id": "code.merge_conflict_resolve", "params": [
                "conflict_id": ma, "choices": [["hunk": ma, "take": chon]],
            ]])
            switch r["status"] as? String {
            case "done":
                let kq = (r["result"] as? [String: Any]) ?? [:]
                _bao("Đã hợp nhất \(EideManHoChieu.nguyen(kq["resolved"]) ?? 0) vùng — commit "
                     + "\(((kq["commit"] as? String) ?? "?").prefix(10)), ghi HAI cha.",
                     mau: EideToken.Mau.ok)
                await nap(goi)
            case "pending":
                _bao("Đã gửi — chưa ghi. " + EideManXungDot.vinao(r["decision"])
                     + " Mục đang nằm ở CHỜ TÔI bên cột phải.", mau: EideToken.Mau.warn)
            default:
                let e = (r["error"] as? [String: Any]) ?? [:]
                _bao("Không hợp nhất được: " + ((e["message"] as? String) ?? "?"),
                     mau: EideToken.Mau.bad)
            }
        } catch {
            _bao("Không gọi được lõi: \(error)", mau: EideToken.Mau.bad)
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
