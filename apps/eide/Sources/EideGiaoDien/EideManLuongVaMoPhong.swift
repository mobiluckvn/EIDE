import AppKit
import EideLoi

/// **S3 — Bản đồ luồng.** UXC-31 §8 S3; `view.timeline` lọc theo pha.
///
/// ## "Hết màn mồ côi"
///
/// Ba chữ ấy trong UXC-31 là lý do màn này tồn tại. Hai mươi lăm màn là một danh sách phẳng, và
/// một danh sách phẳng không nói cho người mới biết **thứ tự**: mở màn nào trước, việc mình
/// đang làm nằm ở đâu trong cả quy trình. Tám pha P0–P7 của BPD là thứ tự ấy, đã viết sẵn
/// trong tài liệu từ trước khi có giao diện.
///
/// ## Pha hiện tại suy từ SỔ CÁI, không từ một biến trạng thái
///
/// Không chỗ nào trong sản phẩm lưu "dự án đang ở pha nào" — và thêm một biến như thế là thêm
/// một thứ trôi khỏi sự thật. Pha hiện tại ở đây = pha của lời gọi năng lực GẦN NHẤT có trong
/// bản đồ BPD. Nó phái sinh, nên nó không bao giờ sai lệch với sổ cái.
public final class EideManLuong: EideManCoSo {

    public override class var tien: String { "FlowMap" }

    public static let TOI_DA = 400

    private var goiLoi: EideGoi?

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        guard let r = try? await doc(goi, "view.timeline", ["limit": Self.TOI_DA]),
              let ds = r["events"] as? [[String: Any]] else {
            return rong(vi: "không đọc được sổ cái",
                        buocKe: "kiểm daemon còn sống rồi mở lại màn")
        }

        let (dem, hienTai, ngoai) = Self.demTheoPha(ds)
        guard dem.values.reduce(0, +) > 0 else {
            return rong(vi: "sổ cái chưa có lời gọi năng lực nào thuộc tám quy trình P0–P7",
                        buocKe: "ra lệnh cho tác tử ở vùng trao đổi — mọi việc nó làm đều rơi "
                              + "vào một trong tám pha, và pha ấy sáng lên ở đây")
        }

        tieuDePhu(hienTai.map { "ĐANG Ở \($0)" } ?? "CHƯA XÁC ĐỊNH ĐƯỢC PHA HIỆN TẠI")
        for p in EideBanDoPha.PHA { them(_hangPha(p, so: dem[p.ma] ?? 0, hienTai: p.ma == hienTai)) }

        if ngoai > 0 {
            // KHÔNG im lặng bỏ qua: 68 trong 244 năng lực có mặt trong tám quy trình, nên phần
            // lớn lời gọi rơi ra ngoài là chuyện bình thường — nhưng người xem phải biết sơ đồ
            // này không phủ hết sổ cái, kẻo họ đọc "P3: 0" thành "chưa sinh mã".
            let n = NSTextField(wrappingLabelWithString:
                "\(ngoai) lời gọi KHÔNG thuộc pha nào — BPD xếp 68 trong 244 năng lực vào tám "
                + "quy trình; phần còn lại là năng lực phụ trợ. Sơ đồ này vì thế không phủ hết "
                + "sổ cái; màn Nhật ký (S2) mới phủ.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.faint
            them(n)
        }
    }

    /// Đếm lời gọi theo pha, và tìm pha HIỆN TẠI.
    ///
    /// Trả cả `ngoai` — số lời gọi không thuộc pha nào. Bỏ con số ấy đi là để người đọc tưởng
    /// tám pha phủ hết mọi việc tác tử làm.
    public static func demTheoPha(_ ds: [[String: Any]]) -> (dem: [String: Int],
                                                             hienTai: String?,
                                                             ngoai: Int) {
        var dem: [String: Int] = [:]
        var hienTai: String?
        var ngoai = 0
        for e in ds {
            guard let cap = (e["cap"] as? String)
                    ?? ((e["data"] as? [String: Any])?["cap"] as? String) else { continue }
            guard let p = EideBanDoPha.phaCua(cap) else { ngoai += 1; continue }
            dem[p, default: 0] += 1
            // `view.timeline` sắp TĂNG dần, nên lần gán cuối là lời gọi mới nhất.
            hienTai = p
        }
        return (dem, hienTai, ngoai)
    }

    /// Một hàng pha — bấm được, mở S2 lọc sẵn theo đúng pha ấy.
    private func _hangPha(_ p: EidePha, so: Int, hienTai: Bool) -> NSView {
        let b = NSButton(title: "\(p.ma) · \(p.ten)", target: self, action: #selector(_moNhatKy(_:)))
        b.bezelStyle = .inline
        b.identifier = NSUserInterfaceItemIdentifier(p.ma)
        b.contentTintColor = hienTai ? EideToken.Mau.primary : EideToken.Mau.text
        b.font = hienTai ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI

        let n = NSTextField(labelWithString:
            so == 0 ? "chưa có lời gọi nào" : "\(so) lời gọi · \(p.caps.count) năng lực")
        n.font = EideToken.fontUI
        n.textColor = so == 0 ? EideToken.Mau.faint : EideToken.Mau.muted

        let h = NSStackView(views: [b, n])
        h.orientation = .horizontal
        h.spacing = 10
        h.alignment = .firstBaseline
        return h
    }

    /// "bấm pha mở S2 lọc sẵn" — §8 S3.
    ///
    /// Chưa có đường truyền BỘ LỌC sang màn Nhật ký, nên bấm chỉ mở S2. Nói ra chứ không lặng
    /// lẽ mở một màn không lọc gì: người bấm vào P3 rồi thấy cả sổ cái sẽ tưởng bộ lọc hỏng.
    @objc private func _moNhatKy(_ n: NSButton) {
        guard let ma = n.identifier?.rawValue else { return }
        let t = NSTextField(wrappingLabelWithString:
            "Mở màn Nhật ký (S2) rồi tìm các lời gọi của \(ma) — đường truyền bộ lọc giữa hai "
            + "màn chưa có, nên S2 hiện mở ở trạng thái đầy đủ.")
        t.font = EideToken.fontUI
        t.textColor = EideToken.Mau.muted
        them(t)
    }
}

/// **S16 — Mô phỏng.** UXC-31 §8 S16; `sim.run` (SIM-05) qua sổ cái `tool.report`.
///
/// ## Ba trạng thái, không hai — và đó là phần đáng nhớ nhất của cả khối mô phỏng
///
/// Một kỳ vọng mà engine hiện có KHÔNG nhìn thấy được trả `unverified` kèm lý do, chứ không
/// trả `failed`. Gộp chúng thì người ta đi sửa một chỗ không hỏng; gộp `unverified` vào
/// `passed` thì một firmware chưa ai quan sát đi thẳng lên board. Màn này giữ nguyên ba cột.
///
/// ## Màn KHÔNG tự chạy mô phỏng khi mở
///
/// `sim.run` là R0, nhưng R0 không có nghĩa là rẻ: nó khởi động một engine, nạp firmware và
/// chạy tới hết `duration_s`. Mở màn mà tự chạy là đốt vài chục giây CPU mỗi lần bấm vào cột
/// trái. Màn đọc LƯỢT CHẠY GẦN NHẤT từ sổ cái.
public final class EideManMoPhong: EideManCoSo {

    public override class var tien: String { "Sim" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let r = try? await doc(goi, "view.timeline", ["limit": 400]),
              let ds = r["events"] as? [[String: Any]] else {
            return rong(vi: "không đọc được sổ cái", buocKe: "kiểm daemon còn sống")
        }
        let luot = ds.filter {
            ($0["kind"] as? String) == "tool.report"
                && (($0["data"] as? [String: Any])?["tool"] as? String) == "sim.run"
        }
        guard let cuoi = luot.last, let d = cuoi["data"] as? [String: Any] else {
            // Đúng câu UXC-31 §8 S16 quy định.
            return rong(vi: "chưa có lượt mô phỏng nào trong dự án này",
                        buocKe: "bước kế: tác tử chạy `sim.run` — cần một kịch bản "
                              + "(`sim.scenario`) và một firmware đã dựng (`code.build`)")
        }

        let mt = (d["metrics"] as? [String: Any]) ?? [:]
        let ky = (mt["expect"] as? [[String: Any]]) ?? []
        let chuaThay = ky.filter { ($0["status"] as? String) == "unverified" }

        if !chuaThay.isEmpty { _bangChuaThay(chuaThay.count, ky.count) }

        tieuDePhu("LƯỢT MÔ PHỎNG GẦN NHẤT — \(EideManNhatKy.gio(cuoi["at"] as? String))")
        bang(cot: [("MỤC", 178), ("GIÁ TRỊ", 0)], dong: [
            ["Kết luận", Self.oKetLuan(d["passed"], chuaThay: chuaThay.count)],
            ["Engine", EideManHoChieu.giaTri(mt["engine"])],
            ["Kịch bản", EideManHoChieu.tenTep(EideManHoChieu.giaTri(mt["scenario"]))],
            ["Tính năng", EideManHoChieu.giaTri(mt["feature"])],
            ["Thời lượng", EideManHoChieu.giaTri(mt["duration_s"]) + " s"],
            ["Kết thúc do", Self.oKetThuc(mt["terminated_by"])],
            ["Nhật ký UART", EideManHoChieu.giaTri(d["log_ref"])],
        ])

        guard !ky.isEmpty else { return }
        tieuDePhu("\(ky.count) KỲ VỌNG")
        bang(cot: [("KỲ VỌNG", 250), ("KÊNH", 96), ("KẾT QUẢ", 130), ("VÌ SAO", 0)],
             dong: ky.map { k in
                 [EideManHoChieu.giaTri(k["expect"] ?? k["name"] ?? k["id"]),
                  EideManHoChieu.giaTri(k["channel"] ?? k["kind"]),
                  Self.oKetQua(k["status"]),
                  (k["reason"] as? String) ?? (k["why"] as? String) ?? "—"]
             })
    }

    /// **`unverified` KHÔNG phải `failed`.** Một dòng `unverified` kéo cả lượt chạy xuống
    /// `passed=false`, nhưng lý do thì khác hẳn: "firmware làm sai" và "EIDE chưa nhìn thấy
    /// được" là hai câu dẫn tới hai việc khác nhau.
    public static func oKetQua(_ x: Any?) -> String {
        switch (x as? String) ?? "" {
        case "passed": return "✅ đạt"
        case "failed": return "⛔ TRƯỢT"
        case "unverified": return "⚠ CHƯA QUAN SÁT ĐƯỢC"
        default: return EideManHoChieu.giaTri(x)
        }
    }

    public static func oKetLuan(_ dat: Any?, chuaThay: Int) -> String {
        let ok = (dat as? Bool) == true || EideManHoChieu.nguyen(dat) == 1
        if ok { return "✅ ĐẠT" }
        return chuaThay > 0
            ? "⛔ KHÔNG đạt — và \(chuaThay) kỳ vọng chưa quan sát được, xem băng trên"
            : "⛔ KHÔNG đạt"
    }

    /// Hết giờ khác chạy xong. Một lượt chạy bị `timeout` cắt ngang có thể vẫn báo "đạt" cho
    /// những kỳ vọng đã kiểm trước đó — nhưng nó chưa chạy hết kịch bản.
    public static func oKetThuc(_ x: Any?) -> String {
        (x as? String) == "timeout" ? "⚠ HẾT GIỜ — chưa chạy hết kịch bản" : "chạy xong"
    }

    private func _bangChuaThay(_ n: Int, _ tong: Int) {
        let v = NSTextField(wrappingLabelWithString:
            "⚠ \(n)/\(tong) kỳ vọng CHƯA QUAN SÁT ĐƯỢC — engine hiện có không có kênh để nhìn "
            + "chúng. Đây KHÔNG phải \"firmware làm sai\": gộp hai thứ thành TRƯỢT thì anh đi "
            + "sửa một chỗ không hỏng, gộp vào ĐẠT thì một firmware chưa ai quan sát đi thẳng "
            + "lên board.")
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.warn
        v.wantsLayer = true
        v.drawsBackground = true
        v.backgroundColor = EideToken.Mau.warnBg
        them(v)
    }
}
