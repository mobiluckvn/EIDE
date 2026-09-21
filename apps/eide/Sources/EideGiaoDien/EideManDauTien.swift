import AppKit
import EideLoi

/// **S2 — Nhật ký hoạt động.** UXC-31 §8 S2; năng lực `view.timeline` (VIEW-12).
///
/// Dòng thời gian là thứ trả lời câu hỏi *"máy vừa làm gì?"*, nên nó phải nói được AI làm: cột
/// `Ai` phân biệt người với tác tử. Bản cũ hiện `by` nguyên dạng (`agent`, `human`, `human:congvt`)
/// và ba giá trị ấy đọc như ba loại chủ thể khác nhau trong khi chỉ có hai.
public final class EideManNhatKy: EideManCoSo {

    public override class var tien: String { "NhatKy" }

    /// Số dòng hiện tối đa. Sổ cái của một dự án làm một tuần đã vài nghìn bản ghi, và một màn
    /// dựng vài nghìn hàng stack thì mất vài giây để mở — người sẽ tưởng ứng dụng treo.
    public static let TOI_DA = 120

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        // Cắt ở LÕI, không ở đây. Kéo về cả sổ cái rồi bỏ đi 98% là 2,6 giây chờ cho 120 dòng
        // — đo trên dự án có 9 128 sự kiện (DEV-132).
        let r = try await doc(goi, "view.timeline", ["limit": Self.TOI_DA])
        let ds = (r["events"] as? [[String: Any]]) ?? []
        let tong = (r["total"] as? Int) ?? ds.count
        guard !ds.isEmpty else {
            return rong(vi: "sổ cái của dự án này chưa có bản ghi nào",
                        buocKe: "ra lệnh cho tác tử — mọi việc nó làm đều để lại một dòng ở đây")
        }
        // MỚI NHẤT LÊN TRƯỚC. `view.timeline` sắp tăng dần để ghép bốn nguồn, nhưng câu hỏi của
        // người mở màn này luôn là "vừa xảy ra chuyện gì", không phải "hôm khai sinh có gì".
        let moi = ds.reversed()
        tieuDePhu("\(tong) BẢN GHI" + (tong > ds.count ? " — hiện \(ds.count) mới nhất" : ""))
        bang(cot: [("LÚC", 132), ("AI", 58), ("VIỆC", 168), ("CHI TIẾT", 0)],
             dong: moi.map { e in
                 [Self.gio(e["at"] as? String), Self.ai(e["by"] as? String),
                  e["kind"] as? String ?? "?", Self.chiTiet(e["data"] as? [String: Any] ?? [:])]
             })
    }

    /// **§7.3 diff render.** Một sự kiện mới = MỘT hàng chèn lên đầu, không nạp lại màn.
    ///
    /// Đây là màn đo ra con số tệ nhất của cách lùi: nạp lại ở mỗi sự kiện làm nó mất 7,68 s
    /// (DEV-132), và ngay cả bản gộp 0,4 s vẫn tốn một lời gọi `view.timeline` 0,47 s cộng một
    /// lượt dựng `NSTextField` ~200 ms cho mỗi lần. Ở đây: dựng lại chuỗi (~6 ms trên 120 hàng)
    /// rồi gán vào chính khung nhìn đang có.
    ///
    /// Dữ liệu lấy từ CHÍNH sự kiện, không hỏi lại lõi — `event.*` mang đủ `at`/`kind`/`data`,
    /// và hỏi lại là quay về đúng chi phí vừa tránh được.
    ///
    /// Trả `false` khi màn chưa dựng bảng (đang ở trạng thái rỗng): hàng đầu tiên phải đi qua
    /// `napDuLieu` để bảng và tiêu đề ra đời cùng nhau.
    public override func apDung(_ ten: String, _ p: [String: Any]) -> Bool {
        guard ten.hasPrefix("event."), let luc = p["at"] as? String else { return false }
        return themHangDau([Self.gio(luc),
                            Self.ai(p["by"] as? String),
                            (p["kind"] as? String) ?? (ten.dropFirst(6) + ""),
                            Self.chiTiet((p["data"] as? [String: Any]) ?? p)],
                           toiDa: Self.TOI_DA)
    }

    /// `2026-09-18T16:04:21.123456+00:00` → `18/09 16:04:21`. Ngày ĐẦY ĐỦ chỉ tốn 6 ký tự và
    /// nó là khác biệt giữa "vừa xong" với "tuần trước" — thứ một dòng thời gian tồn tại để nói.
    public static func gio(_ s: String?) -> String {
        guard let s, s.count >= 19 else { return "—" }
        let d = s.prefix(10).suffix(5)               // MM-DD
        return "\(d.suffix(2))/\(d.prefix(2)) \(s.dropFirst(11).prefix(8))"
    }

    /// `human`, `human:congvt`, `agent`, `nil` → hai chủ thể, không phải bốn.
    public static func ai(_ s: String?) -> String {
        let v = s ?? ""
        return v.hasPrefix("human") ? "người" : (v.isEmpty ? "máy" : "máy")
    }

    /// Một dòng dữ liệu thô đọc được. Ưu tiên các khoá người cần; phần còn lại KHÔNG bị giấu
    /// hẳn — nó rút thành số khoá, để người biết là còn thứ mình chưa nhìn thấy.
    public static func chiTiet(_ d: [String: Any]) -> String {
        let uuTien = ["cap", "status", "decision", "gate", "level", "text", "path", "file", "reason"]
        var phan: [String] = []
        for k in uuTien where d[k] != nil {
            phan.append("\(k)=\(gonGang(d[k]!))")
        }
        let con = d.keys.filter { !uuTien.contains($0) && !$0.hasPrefix("_") }
        if !con.isEmpty { phan.append("(+\(con.count) trường)") }
        return phan.isEmpty ? "—" : phan.joined(separator: " · ")
    }

    /// Một giá trị JSON bất kỳ → MỘT dòng đọc được.
    ///
    /// Nội suy thẳng `"\(giá trị)"` cho một từ điển lồng sẽ in ra dạng mô tả nhiều dòng của
    /// Objective-C, và nó ESCAPE tiếng Việt thành `\U1edbp`. Đo 18/09 trên màn Nhật ký: mỗi
    /// bản ghi `cap.run.start` chiếm sáu dòng, trong đó dòng lý do đọc là
    /// `"L\U1edbp R0 ch\U1ec9 \U0111\U1ecdc"` — chữ vẫn còn đủ, chỉ là không ai đọc được.
    public static func gonGang(_ v: Any) -> String {
        switch v {
        case let s as String:
            return s.count > 72 ? String(s.prefix(72)) + "…" : s
        case let b as Bool:
            return b ? "true" : "false"
        case let n as NSNumber:
            return n.stringValue
        case let a as [Any]:
            return "[\(a.count) mục]"
        case let o as [String: Any]:
            // Một tầng lồng thì MỞ RA — `decision` của mọi bản ghi cổng nằm ở đây, và nó là
            // thứ người mở màn Nhật ký muốn đọc nhất.
            let vo = ["decision", "rule", "gate", "status", "id", "name"]
            let lay = vo.filter { o[$0] != nil }.prefix(2)
                        .map { "\($0)=\(gonGang(o[$0]!))" }
            return lay.isEmpty ? "{\(o.count) khoá}" : "{" + lay.joined(separator: " ") + "}"
        default:
            return "\(v)"
        }
    }
}

/// **S25 — Chính sách tự chủ.** UXC-31 §8 S25; năng lực `policy.rules` (POLICY-08).
///
/// Bảng CHỈ ĐỌC. Sửa chính sách đi bằng `eide policy set`/`sign` ở dòng lệnh, có chủ đích: một
/// cái nút "nới quyền" nằm ngay trong tầm tay tác tử là thứ POL-17 tồn tại để ngăn.
public final class EideManChinhSach: EideManCoSo {

    public override class var tien: String { "ChinhSach" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        let kq = try await nangLuc(goi, "policy.rules")
        let ds = (kq["rules"] as? [[String: Any]]) ?? []

        // Niêm CHƯA KÝ là thứ phải nói TRƯỚC bảng: lúc ấy ba danh sách trắng bị bỏ khỏi biểu
        // thức, nên bảng dưới đây đúng, mà hành vi thật KHÁC nó.
        if (kq["signed"] as? Bool) == false {
            let lyDo = (kq["reason"] as? String) ?? ""
            let n = NSTextField(wrappingLabelWithString:
                "Danh sách trắng CHƯA ký — PolicyGate bỏ `trusted_sources`, `trusted_packages` và "
                + "`allowed_licenses` khỏi biểu thức, nên các quy tắc dựa vào chúng không khớp và "
                + "lời gọi rơi xuống quy tắc bắt hết."
                + (lyDo.isEmpty ? "" : " Lý do: \(lyDo)."))
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.warn
            n.wantsLayer = true
            n.drawsBackground = true
            n.backgroundColor = EideToken.Mau.warnBg
            them(n)
        }

        guard !ds.isEmpty else {
            return rong(vi: "PolicyGate không nạp được quy tắc nào",
                        buocKe: "kiểm `docs/spec/policy/rules.yaml` rồi mở lại dự án")
        }
        tieuDePhu("\(ds.count) QUY TẮC ĐANG CÓ HIỆU LỰC")
        bang(cot: [("MÃ", 92), ("CỔNG", 74), ("QUYẾT", 74), ("ĐIỀU KIỆN", 0)],
             dong: ds.map { q in
                 [q["id"] as? String ?? "?", q["gate"] as? String ?? "—",
                  q["decision"] as? String ?? "—",
                  (q["when"] as? String) ?? (q["reason"] as? String) ?? "—"]
             })
    }
}

/// **S1 — Tổng quan.** UXC-31 §8 S1; `session.state` + `budget.state`.
public final class EideManTongQuan: EideManCoSo {

    public override class var tien: String { "Main" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        let p = try await doc(goi, "session.state")
        var dong: [[String]] = []
        // `thieu` là danh sách trường lõi CHƯA lưu (DEV-110). Hiện nó ra thành dòng, không nuốt:
        // một ô trống không nói được nó trống vì chưa có dữ liệu hay vì màn quên đọc.
        let thieu = (p["thieu"] as? [String]) ?? []
        dong.append(["Phiên", (p["session_id"] as? String) ?? "chưa mở phiên nào"])
        dong.append(["Mở lúc", EideManNhatKy.gio(p["opened_at"] as? String)])
        dong.append(["Tự chủ hiệu lực", (p["autonomy_effective"] as? String) ?? "—"])
        dong.append(["Dừng khẩn", ((p["stopped"] as? Bool) ?? false) ? "ĐANG BẬT" : "tắt"])
        dong.append(["Lượt trao đổi", "\(p["turns"] as? Int ?? 0)"])
        dong.append(["Mục hoàn tác", "\(p["undo_items"] as? Int ?? 0)"])
        if !thieu.isEmpty {
            dong.append(["Chưa có dữ liệu", thieu.joined(separator: ", ") + " (DEV-110)"])
        }
        tieuDePhu("PHIÊN LÀM VIỆC")
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)

        if let b = try? await doc(goi, "budget.state") {
            tieuDePhu("NGÂN SÁCH MÔ HÌNH")
            // Tên khoá chép ĐÚNG từ `daemon/rpc.py::budget_state`. Bản đầu đoán ba tên khác
            // (`spent_today`, `daily_limit`, `calls`) và cả ba đều không tồn tại, nên bảng này
            // hiện `0,0000 USD` suốt từ 20/09 tới lúc màn S22 đọc lại hợp đồng — một bảng số
            // liệu luôn bằng 0 trông y hệt một dự án chưa tiêu đồng nào.
            bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: [
                ["Hôm nay", String(format: "%.4f USD", (b["spent_usd"] as? Double) ?? 0)],
                ["Hạn ngày", EideManMoHinh.oHanMuc(b["daily_budget_usd"])],
                ["Số lời gọi", "\(EideManHoChieu.nguyen(b["calls_today"]) ?? 0)"],
            ])
        }
    }
}
