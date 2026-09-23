import AppKit
import EideLoi

/// Nền chung của bốn màn nhóm THIẾT KẾ (S10–S13).
///
/// Cả bốn đứng trên cùng một câu hỏi — *"dự án này đang có những hiện vật gì"* — và cùng một
/// năng lực trả lời: `view.artifacts` (VIEW-14). Trước khi có nó, mọi thứ chạm tới hiện vật kỹ
/// nghệ trong store đều là năng lực SINH, nên bốn màn này hoặc không dựng được, hoặc mỗi lần mở
/// là một lần tiêu tiền mô hình.
///
/// **`R0` không có nghĩa là "chỉ đọc trạng thái có sẵn"** — đó là chỗ dễ nhầm nhất của cả nhóm:
/// `req.elicit` là R0 nhưng gọi mô hình, `arch.adr` là R0 nhưng ghi tệp, `diagram.architecture`
/// là R0 nhưng dựng lược đồ mới. Lớp này tồn tại một phần để giữ ranh giới ấy ở một chỗ.
@MainActor
open class EideManThietKe: EideManCoSo {

    /// Đọc một loại hiện vật. `nil` = dự án chưa có store.
    public func hienVat(_ goi: @escaping EideGoi, _ loai: String,
                        _ them: [String: Any] = [:]) async throws -> (dong: [[String: Any]], tong: Int)? {
        guard let r = try await nangLucNeuCo(goi, "view.artifacts", ["kind": loai].merging(them) { a, _ in a })
        else { return nil }
        return ((r["items"] as? [[String: Any]]) ?? [], EideManHoChieu.nguyen(r["total"]) ?? 0)
    }

    /// Trạng thái rỗng dùng chung: chưa có hiện vật loại này.
    ///
    /// Bốn màn nói bốn câu khác nhau ở phần "bước kế tiếp", vì bốn hiện vật ra đời từ bốn chỗ
    /// khác nhau — gộp thành một câu chung sẽ chỉ người dùng tới sai nơi ba lần trong bốn.
    public func rongVi(_ gi: String, buocKe: String) {
        rong(vi: "\(gi) — chưa có hiện vật nào thuộc loại này trong store", buocKe: buocKe)
    }
}

/// **S10 — Yêu cầu & kiến trúc.** UXC-31 §8 S10; `view.artifacts` (VIEW-14), `req.ground_hw`
/// (REQ-03), `arch.adr` (ARCH-08).
///
/// ## Cột KHẢ THI là lý do màn này tồn tại
///
/// UXC-31 viết rõ: *"bảng FR/NFR với cột khả thi (`req.ground_hw` — **căn cứ phần cứng thật**)"*.
/// Một bảng yêu cầu không có cột ấy thì bất kỳ công cụ quản lý việc nào cũng làm được. Cột khả
/// thi là chỗ tri thức phần cứng chạm vào yêu cầu: "ADC 1 MSPS" gặp fact "2,4 MSPS" thì đạt,
/// gặp "yêu cầu 5 MSPS" thì không — và **kèm fact id**, không kèm một lời khuyên.
public final class EideManYeuCau: EideManThietKe {

    public override class var tien: String { "ReqArch" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let yc = try await hienVat(goi, "requirement") else {
            return rongVi("dự án chưa có store",
                          buocKe: "gõ một câu tiếng Việt mô tả việc cần làm — `req.elicit` rút "
                                + "yêu cầu ra từ đó")
        }
        let adr = (try await hienVat(goi, "adr"))?.dong ?? []

        guard !yc.dong.isEmpty || !adr.isEmpty else {
            return rongVi("chưa có yêu cầu nào",
                          buocKe: "ra lệnh cho tác tử ở vùng trao đổi; `req.elicit` → "
                                + "`req.classify` ghi yêu cầu xuống store")
        }

        if !yc.dong.isEmpty {
            // **Yêu cầu KHÔNG ĐO ĐƯỢC, đánh dấu riêng** — §8 S10, [DEV-191].
            //
            // `req.detect_conflict` đã trả `issues[] {kind: "unmeasurable", req_ids}` từ trước
            // và **không màn nào đọc**. Đây là cột khác hẳn KHẢ THI: một yêu cầu "hệ thống phải
            // phản hồi nhanh" hoàn toàn KHẢ THI trên con chip đã ghim, mà không ai chấm được nó
            // đạt hay trượt — nên nó sẽ trôi tới tận lúc nghiệm thu rồi thành một cuộc tranh
            // luận. Đánh dấu ở đây là chỗ rẻ nhất để bắt.
            //
            // Tính ở LÕI chứ không viết lại phép đo trong Swift: `do_duoc` chuẩn hoá đơn vị
            // ("400 kHz" = "0,4 MHz"), và một bản sao thứ hai của luật ấy sẽ lệch.
            // `reqset_ids` BẮT BUỘC (REQ-04). Gọi thiếu thì E1000, `try?` nuốt, và cột dưới in
            // "✓ có ngưỡng đo" cho MỌI yêu cầu — một câu trả lời SAI, tệ hơn hẳn một ô trống.
            // Đo 23/09/2026 trên dự án mẫu: `NFR-001 "phản hồi nhanh và ổn định"` được đánh dấu
            // đo được, đúng loại lỗi mà chính mục này sinh ra để bắt.
            var khongDo: Set<String> = []
            var goiY: [String: String] = [:]
            let maYC = yc.dong.compactMap { $0["id"] as? String }
            if let r = try? await nangLuc(goi, "req.detect_conflict", ["reqset_ids": maYC]),
               let issues = r["issues"] as? [[String: Any]] {
                for i in issues where (i["kind"] as? String) == "unmeasurable" {
                    for x in (i["req_ids"] as? [Any]) ?? [] {
                        let ma = EideManHoChieu.giaTri(x)
                        khongDo.insert(ma)
                        goiY[ma] = (i["suggestion"] as? String) ?? ""
                    }
                }
            }
            let chuaXet = yc.dong.filter { ($0["feasibility"] as? String) == nil }.count
            // Nói CẢ con số 0. Một phép rà chỉ lên tiếng khi có vấn đề thì không phân biệt được
            // "đã rà, sạch" với "chưa rà" — và người đọc mặc định hiểu theo vế thứ nhất.
            tieuDePhu("\(yc.tong) YÊU CẦU"
                      + (chuaXet > 0 ? " — \(chuaXet) CHƯA đối chiếu phần cứng" : "")
                      + " · \(khongDo.count) yêu cầu KHÔNG ĐO ĐƯỢC")
            bang(cot: [("MÃ", 86), ("LOẠI", 62), ("ƯU TIÊN", 78), ("TRẠNG THÁI", 96),
                       ("KHẢ THI", 130), ("ĐO ĐƯỢC", 150), ("NỘI DUNG", 0)],
                 dong: yc.dong.map { d in
                     let ma = (d["id"] as? String) ?? "?"
                     return [ma,
                             (d["kind"] as? String) ?? "—",
                             (d["priority"] as? String) ?? "—",
                             (d["status"] as? String) ?? "—",
                             Self.oKhaThi(d["feasibility"]),
                             khongDo.contains(ma)
                                ? "✖ KHÔNG ĐO ĐƯỢC — " + (goiY[ma] ?? "thiếu ngưỡng kèm đơn vị")
                                : "✓ có ngưỡng đo",
                             (d["text"] as? String) ?? "—"]
                 })
        }

        await _maTranTruyVet(goi)

        guard !adr.isEmpty else { return }
        tieuDePhu("\(adr.count) QUYẾT ĐỊNH KIẾN TRÚC (ADR)")
        bang(cot: [("MÃ", 86), ("TRẠNG THÁI", 96), ("TRÍCH DẪN", 110), ("QUYẾT ĐỊNH", 0)],
             dong: adr.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["status"] as? String) ?? "—",
                  Self.oTrichDan(d["citations"]),
                  ((d["title"] as? String) ?? "") + " — " + ((d["decision"] as? String) ?? "")]
             })
    }

    /// **Ma trận TRUY VẾT yêu cầu ↔ module ↔ mã ↔ test** — §8 S10, [DEV-191].
    ///
    /// `req.trace_matrix` (REQ-06) sinh tệp và trả `gaps[]` — những yêu cầu KHÔNG nối được về
    /// một module, một đơn vị mã hay một bài kiểm. Màn hiện `gaps` chứ không hiện cả ma trận:
    /// ma trận đầy đủ là một bảng hàng trăm ô, còn thứ người mở màn này cần biết là **chỗ đứt**.
    /// Nối đủ thì nói ra là đủ — cùng lý do với con số 0 của phép rà đo được ở trên.
    private func _maTranTruyVet(_ goi: @escaping EideGoi) async {
        tieuDePhu("MA TRẬN TRUY VẾT — yêu cầu ↔ module ↔ mã ↔ test")
        guard let r = try? await nangLuc(goi, "req.trace_matrix", ["format": "md"]) else {
            return them(Self.chuTK("Không dựng được ma trận truy vết — `req.trace_matrix` "
                                   + "không chạy được.", mau: EideToken.Mau.warn))
        }
        let gaps = (r["gaps"] as? [[String: Any]]) ?? []
        let tep = (r["file"] as? String) ?? ""
        them(Self.chuTK("Ma trận đầy đủ: `\(tep.isEmpty ? "—" : tep)`",
                        mau: EideToken.Mau.muted))
        guard !gaps.isEmpty else {
            return them(Self.chuTK("✓ Không chỗ đứt nào — mọi yêu cầu đều nối được về module, "
                                   + "mã và bài kiểm.", mau: EideToken.Mau.ok))
        }
        bang(cot: [("YÊU CẦU", 110), ("ĐỨT Ở ĐÂU", 0)],
             dong: gaps.prefix(20).map { g in
                 [EideManHoChieu.giaTri(g["req_id"] ?? g["id"]),
                  EideManHoChieu.giaTri(g["missing"] ?? g["reason"] ?? g["kind"])]
             })
    }

    static func chuTK(_ s: String, mau: NSColor) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        return n
    }

    /// Ô cột KHẢ THI — **`nil` là một câu trả lời thứ ba.**
    ///
    /// "Chưa đối chiếu" khác hẳn "đối chiếu rồi và không đạt", và gộp chúng thành một ô trống
    /// là đúng loại im lặng cả kho này tránh: một yêu cầu chưa ai kiểm trông y hệt một yêu cầu
    /// đã kiểm và sạch.
    public static func oKhaThi(_ x: Any?) -> String {
        guard let s = x as? String, !s.isEmpty else { return "chưa đối chiếu" }
        switch s.lowercased() {
        case "ok", "true", "feasible": return "đạt"
        case "no", "false", "infeasible": return "⛔ KHÔNG đạt"
        default: return s
        }
    }

    /// **ADR không trích dẫn gì là một ADR không kiểm lại được.** KAD-07 dựng cả tầng tri thức
    /// để mọi quyết định truy về một fact; một ô trống ở đây nói rằng quyết định ấy đứng ngoài.
    public static func oTrichDan(_ x: Any?) -> String {
        let ds = (x as? [Any]) ?? []
        guard !ds.isEmpty else { return "⚠ không có" }
        return "\(ds.count) fact"
    }
}

/// **S12 — Kế hoạch.** UXC-31 §8 S12; `view.artifacts`, `plan.sufficiency` (PLAN-06).
///
/// ## `missing[]` lên ĐẦU bảng, không xuống cuối
///
/// UXC-31 viết: *"`missing[]` hiện thành khối **còn thiếu** đầu bảng"*. Thứ tự ấy là nội dung:
/// một kế hoạch thiếu căn cứ vẫn chạy được từng bước và vẫn hỏng ở bước cuối, nên thứ người cần
/// đọc TRƯỚC khi đọc các bước là danh sách những gì chưa có.
public final class EideManKeHoach: EideManThietKe {

    public override class var tien: String { "PlanDiff" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let kh = try await hienVat(goi, "plan") else {
            return rongVi("dự án chưa có store",
                          buocKe: "ra lệnh cho tác tử — `plan.create` dựng kế hoạch cho một "
                                + "tính năng, và tính năng đến từ `plan.define_feature`")
        }
        guard !kh.dong.isEmpty else {
            return rongVi("chưa có kế hoạch cho tính năng nào",
                          buocKe: "gõ một câu mô tả tính năng cần làm; `plan.create` lập chuỗi "
                                + "bước kèm fact trích dẫn cho từng bước")
        }

        // Khối "còn thiếu" TRƯỚC bảng bước — thứ tự là nội dung, không phải trình bày.
        for f in kh.dong.prefix(3) {
            guard let id = f["id"] as? String,
                  let r = try? await nangLuc(goi, "plan.sufficiency", ["task_ref": id]) else { continue }
            let du = (r["sufficient"] as? Bool) ?? true
            let thieu = (r["missing"] as? [Any]) ?? []
            guard !du || !thieu.isEmpty else { continue }
            _khoiConThieu(id, thieu)
        }

        tieuDePhu("\(kh.tong) TÍNH NĂNG CÓ KẾ HOẠCH")
        bang(cot: [("MÃ", 110), ("TRẠNG THÁI", 100), ("YÊU CẦU", 130), ("SỬA LẦN CUỐI", 132),
                   ("TÊN", 0)],
             dong: kh.dong.map { d in
                 [(d["id"] as? String) ?? "?",
                  (d["status"] as? String) ?? "—",
                  Self.oYeuCau(d["requirement_ids"]),
                  EideManNhatKy.gio(d["updated_at"] as? String),
                  (d["title"] as? String) ?? "—"]
             })
    }

    /// Một mục `missing` → một câu người đọc được. [DEV-171]
    ///
    /// `plan.sufficiency` trả `missing[]` gồm các ĐỐI TƯỢNG, và `giaTri` đưa mọi đối tượng về
    /// `"{3 khoá}"`. Nên dòng cảnh báo trước bản này đọc ra: *"CÒN THIẾU 2 căn cứ: {3 khoá},
    /// {3 khoá}"* — đúng số lượng, không một chữ nào nói thiếu CÁI GÌ. Một cảnh báo không nói
    /// được nội dung của chính nó thì người dùng chỉ còn cách đoán, và đoán sai thì họ bỏ qua.
    ///
    /// Ba loại có ba hình dạng khác nhau vì chúng dẫn tới ba hành động khác nhau — đi tìm tài
    /// liệu, cài công cụ, hay trả lời tác tử. Gộp chúng vào một câu chung là xoá đúng phần
    /// thông tin khiến người dùng biết phải làm gì tiếp.
    public static func moTaThieu(_ v: Any) -> String {
        guard let o = v as? [String: Any] else { return EideManHoChieu.giaTri(v) }
        if let t = o["text"] as? String, !t.isEmpty { return t }
        switch o["loai"] as? String {
        case "tri_thuc": return "chưa có fact nào cho `\(EideManHoChieu.giaTri(o["predicate"]))`"
        case "cong_cu":  return "thiếu công cụ `\(EideManHoChieu.giaTri(o["ten"]))`"
        default:
            // Loại THÊM SAU NÀY. Rơi về `giaTri` ở đây là dựng lại đúng cái bẫy vừa gỡ: mục
            // mới sẽ hiện `{2 khoá}` và không ai biết, vì dòng cảnh báo vẫn trông bình thường.
            // Dựng câu từ chính các khoá — xấu hơn một câu viết tay, nhưng nói được nội dung.
            let bo: Set<String> = ["loai", "hanh_dong"]
            let phan = o.keys.sorted().filter { !bo.contains($0) }
                        .map { "\($0)=\(EideManHoChieu.giaTri(o[$0]))" }
            let ten = (o["loai"] as? String) ?? "chưa rõ loại"
            return phan.isEmpty ? ten : ten + ": " + phan.joined(separator: " · ")
        }
    }

    private func _khoiConThieu(_ id: String, _ thieu: [Any]) {
        let n = NSTextField(wrappingLabelWithString:
            "⚠ `\(id)` — CÒN THIẾU \(thieu.count) căn cứ:\n"
            + thieu.prefix(6).map { "   • " + Self.moTaThieu($0) }.joined(separator: "\n")
            + (thieu.count > 6 ? "\n   • …" : "")
            + "\nKế hoạch thiếu căn cứ vẫn chạy được từng bước và vẫn hỏng ở bước cuối.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)
    }

    /// Một tính năng không nối về yêu cầu nào là một tính năng không ai truy được vì sao nó tồn
    /// tại — REQ-06 dựng ma trận truy vết chính để chỗ này không trống.
    public static func oYeuCau(_ x: Any?) -> String {
        let ds = (x as? [Any]) ?? []
        guard !ds.isEmpty else { return "⚠ không nối yêu cầu" }
        return ds.prefix(3).map { EideManHoChieu.giaTri($0) }.joined(separator: ", ")
             + (ds.count > 3 ? " +\(ds.count - 3)" : "")
    }
}

/// **S11 — Lược đồ.** UXC-31 §8 S11; `view.artifacts`, `diagram.sync` (DIAGRAM-14).
///
/// ## Chỉ báo đồng bộ hai chiều mã ↔ hình
///
/// *"lệch thì băng vàng + nút đồng bộ"*. Một lược đồ lệch khỏi mã là thứ tệ hơn không có lược
/// đồ: người đọc tin vào hình, và hình nói sai. Nên cột `stale` không nằm lẫn trong bảng mà
/// được kéo lên thành một băng.
public final class EideManLuocDo: EideManThietKe {

    public override class var tien: String { "DiagramView" }

    private var goiLoi: EideGoi?
    private let cocBao = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        guard let ld = try await hienVat(goi, "diagram") else {
            return rongVi("dự án chưa có store",
                          buocKe: "`diagram.*` dựng lược đồ từ module, netlist và fact — nhập "
                                + "tài liệu ở S4 trước")
        }
        guard !ld.dong.isEmpty else {
            return rongVi("chưa có lược đồ nào",
                          buocKe: "ra lệnh cho tác tử dựng lược đồ (`diagram.architecture`, "
                                + "`diagram.sequence`, `diagram.pinmap`…) — chúng ghi vào store")
        }

        let lech = ld.dong.filter { Self.laLech($0) }
        if !lech.isEmpty { _bangLech(lech) }

        // "Lược đồ nào đang DÙNG TRONG tài liệu nào" — chiều ngược của `nhungLuocDo`, cùng một
        // nguồn sự thật là văn bản tài liệu. Một lược đồ không nằm trong tài liệu nào là lược
        // đồ chỉ mình tác tử nhìn thấy; đó là thông tin, không phải chỗ trống.
        let tlds = ((try? await hienVat(goi, "doc"))??.dong) ?? []
        let nhung = EideManTaiLieu.nhungLuocDo(duAnGoc,
                                     tep: tlds.compactMap { $0["path"] as? String },
                                     luocDo: ld.dong)
        var dungO: [String: [String]] = [:]
        for (tep, ds) in nhung {
            for ma in ds { dungO[ma, default: []].append((tep as NSString).lastPathComponent) }
        }

        tieuDePhu("\(ld.tong) LƯỢC ĐỒ" + (lech.isEmpty ? "" : " · \(lech.count) LỆCH VỚI MÃ"))
        bang(cot: [("MÃ", 120), ("LOẠI", 110), ("NGÔN NGỮ", 80), ("ĐỒNG BỘ", 124),
                   ("DÙNG TRONG TÀI LIỆU", 170), ("DỰNG LÚC", 124), ("ĐƯỜNG DẪN", 0)],
             dong: ld.dong.map { d in
                 let ma = (d["id"] as? String) ?? "?"
                 return [ma,
                         (d["kind"] as? String) ?? "—",
                         (d["lang"] as? String) ?? "—",
                         Self.oDongBo(d),
                         dungO[ma]?.joined(separator: ", ") ?? "chưa tài liệu nào nhúng",
                         EideManNhatKy.gio(d["at"] as? String),
                         (d["path"] as? String) ?? "—"]
             })
        them(cocBao)
    }

    /// `stale` trong store là INTEGER (0/1), không phải Bool — SQLite không có kiểu boolean.
    /// Đọc bằng `as? Bool` sẽ ra `nil` cho MỌI hàng, và cột đồng bộ im lặng báo "khớp".
    public static func laLech(_ d: [String: Any]) -> Bool {
        if let b = d["stale"] as? Bool { return b }
        return (EideManHoChieu.nguyen(d["stale"]) ?? 0) != 0
    }

    public static func oDongBo(_ d: [String: Any]) -> String {
        guard laLech(d) else {
            let voi = (d["synced_with"] as? String) ?? ""
            return voi.isEmpty ? "khớp" : "khớp · \(EideManHoChieu.tenTep(voi))"
        }
        return "⚠ LỆCH với mã"
    }

    private func _bangLech(_ ds: [[String: Any]]) {
        let n = NSTextField(wrappingLabelWithString:
            "⚠ \(ds.count) lược đồ đang LỆCH với mã: "
            + ds.prefix(4).map { ($0["id"] as? String) ?? "?" }.joined(separator: ", ")
            + (ds.count > 4 ? "…" : "")
            + ". Một lược đồ lệch tệ hơn không có lược đồ — người đọc tin vào hình, và hình "
            + "đang nói sai.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.warnBg
        them(n)

        for d in ds.prefix(6) {
            let b = NSButton(title: "Đồng bộ \((d["id"] as? String) ?? "?")",
                             target: self, action: #selector(_dongBo(_:)))
            b.bezelStyle = .inline
            b.identifier = NSUserInterfaceItemIdentifier((d["id"] as? String) ?? "")
            them(b)
        }
    }

    @objc private func _dongBo(_ n: NSButton) {
        guard let goi = goiLoi, let id = n.identifier?.rawValue, !id.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                // `direction` nêu tường minh: DIAGRAM-14 đồng bộ HAI CHIỀU, và để lõi tự đoán
                // chiều là để nó ghi đè mã bằng hình trong đúng trường hợp người vừa sửa mã.
                let r = try await nangLuc(goi, "diagram.sync",
                                          ["diagram_id": id, "direction": "code_to_diagram"])
                let ap = (r["applied"] as? Bool) ?? false
                _bao(ap ? "Đã dựng lại `\(id)` từ mã."
                        : "Chưa áp — `diagram.sync` trả về khác biệt để anh xem trước.",
                     mau: ap ? EideToken.Mau.ok : EideToken.Mau.warn)
                if ap { await nap(goi) }
            } catch {
                _bao("Không đồng bộ được `\(id)`: \(error)", mau: EideToken.Mau.bad)
            }
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

/// **S13 — Tài liệu.** UXC-31 §8 S13; `view.artifacts`, `doc.style_check` (DOC-08).
///
/// ## "Mọi khẳng định có nguồn" là một phép kiểm, không phải một lời khuyên
///
/// `doc.style_check` phân loại vấn đề thành `lang|term|uncited|format|glossary`, và một trong
/// năm loại ấy nặng hơn hẳn bốn loại kia: `uncited`. Sai chính tả thuật ngữ làm tài liệu khó
/// đọc; một khẳng định không nguồn làm tài liệu **không kiểm được** — đúng thứ cả sản phẩm tồn
/// tại để tránh. Nên cột vấn đề tách riêng nó.
public final class EideManTaiLieu: EideManThietKe {

    public override class var tien: String { "Doc" }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        guard let tl = try await hienVat(goi, "doc") else {
            return rongVi("dự án chưa có store",
                          buocKe: "`doc.generate` viết tài liệu từ chính store — nhập tài liệu "
                                + "và sinh mã trước, rồi bảo tác tử viết SRS/SDD")
        }
        guard !tl.dong.isEmpty else {
            return rongVi("chưa sinh tài liệu nào",
                          buocKe: "bảo tác tử `doc.generate --type SRS` — bảng số liệu dựng từ "
                                + "store, mục Nguồn truy ngược về từng `source`")
        }

        let cu = tl.dong.filter { !(($0["stale_sections"] as? [Any]) ?? []).isEmpty }
        let khongNguon = tl.dong.reduce(0) { $0 + Self.soKhongNguon($1["style_issues"]) }
        if !cu.isEmpty || khongNguon > 0 { _bangCanhBao(cu.count, khongNguon) }

        // Liên kết lược đồ ↔ tài liệu đọc từ chính tệp văn bản — xem `nhungLuocDo`.
        let ld = ((try? await hienVat(goi, "diagram"))??.dong) ?? []
        let nhung = Self.nhungLuocDo(duAnGoc,
                                     tep: tl.dong.compactMap { $0["path"] as? String },
                                     luocDo: ld)

        tieuDePhu("\(tl.tong) TÀI LIỆU ĐÃ SINH")
        bang(cot: [("MÃ", 98), ("LOẠI", 86), ("NGÔN NGỮ", 76), ("MỤC CŨ", 84),
                   ("VẤN ĐỀ", 130), ("LƯỢC ĐỒ ĐÃ NHÚNG", 150), ("ĐƯỜNG DẪN", 0)],
             dong: tl.dong.map { d in
                 let p = (d["path"] as? String) ?? "—"
                 return [(d["id"] as? String) ?? "?",
                         (d["type"] as? String) ?? "—",
                         (d["lang"] as? String) ?? "—",
                         Self.oMucCu(d["stale_sections"]),
                         Self.oVanDe(d["style_issues"]),
                         (nhung[p]?.joined(separator: ", ")).map { $0.isEmpty ? "—" : $0 }
                            ?? "không hình nào",
                         p]
             })

        await _khoiVanPhong(goi, tl.dong)
    }

    /// **Lỗi văn phong — `doc.style_check` (DOC-06).** §8 S12, [DEV-193].
    ///
    /// Cột VẤN ĐỀ ở bảng trên đọc `style_issues` mà `view.artifacts` trả về — và cột ấy CHỈ có
    /// dữ liệu nếu một lượt `doc.style_check` đã chạy và ghi xuống store. Trên một tài liệu vừa
    /// sinh thì nó trống, nên màn im lặng về đúng thứ DOC-06 tồn tại để nói.
    ///
    /// Chạy kiểm NGAY khi mở màn được vì `doc.style_check` chỉ ĐỌC: nó không sửa tài liệu,
    /// không ghi tệp, không chạm phần cứng. Khác hẳn `sim.build_platform` ở màn Mô phỏng —
    /// ranh giới là "có ghi gì không", không phải "có tốn thời gian không".
    private func _khoiVanPhong(_ goi: @escaping EideGoi, _ ds: [[String: Any]]) async {
        tieuDePhu("KIỂM VĂN PHONG — `doc.style_check`")
        var dong: [[String]] = []
        for d in ds.prefix(6) {
            guard let ma = d["id"] as? String else { continue }
            guard let r = try? await nangLuc(goi, "doc.style_check", ["doc_id": ma]) else {
                dong.append([ma, "không chạy được", "—"])
                continue
            }
            let issues = (r["issues"] as? [[String: Any]]) ?? []
            let khongNguon = Self.soKhongNguon(issues)
            dong.append([ma,
                         issues.isEmpty ? "✓ sạch" : "\(issues.count) vấn đề",
                         khongNguon > 0
                            ? "\(khongNguon) khẳng định KHÔNG NGUỒN — tài liệu không kiểm được"
                            : (issues.first.map { EideManHoChieu.giaTri($0["text"] ?? $0["kind"]) }
                               ?? "—")])
        }
        guard !dong.isEmpty else {
            return them(EideManYeuCau.chuTK("Không tài liệu nào để kiểm văn phong.",
                                   mau: EideToken.Mau.muted))
        }
        bang(cot: [("TÀI LIỆU", 110), ("KẾT QUẢ", 130), ("ĐÁNG CHÚ Ý NHẤT", 0)], dong: dong)
    }

    /// **Lược đồ nào nhúng trong tài liệu nào** — `{đường dẫn tài liệu: [mã lược đồ]}`.
    /// §8 S11 và §8 S12, [DEV-193].
    ///
    /// ## Nguồn sự thật là CHÍNH TỆP TÀI LIỆU, không phải một bảng
    ///
    /// `doc.embed_diagram` chèn hình vào văn bản và trả về số hình; nó KHÔNG ghi một dòng liên
    /// kết nào xuống store. Nên câu *"lược đồ này đang dùng ở đâu"* chỉ trả lời được bằng cách
    /// đọc tài liệu. Dựng thêm một bảng liên kết là dựng một bản sao thứ hai sẽ trôi: xoá một
    /// hình khỏi văn bản mà bảng vẫn giữ dòng cũ thì màn nói sai theo hướng nguy hiểm — người
    /// đọc tin rằng hình còn ở đó.
    ///
    /// Bắt theo MÃ lược đồ và theo TÊN TỆP: `![Hình 1](diagrams/kien-truc.svg)` và
    /// `<!-- eide:diagram D-001 -->` đều là cách chèn có thật trong kho.
    public static func nhungLuocDo(_ goc: String?, tep: [String],
                                   luocDo: [[String: Any]]) -> [String: [String]] {
        guard let goc else { return [:] }
        var ra: [String: [String]] = [:]
        for t in tep {
            let duong = (goc as NSString).appendingPathComponent(t)
            guard let van = try? String(contentsOfFile: duong, encoding: .utf8) else { continue }
            for ld in luocDo {
                let ma = (ld["id"] as? String) ?? ""
                let p = (ld["path"] as? String) ?? ""
                let ten = p.isEmpty ? "" : (p as NSString).lastPathComponent
                let khop = (!ma.isEmpty && van.contains(ma))
                    || (!ten.isEmpty && van.contains((ten as NSString).deletingPathExtension))
                if khop { ra[t, default: []].append(ma.isEmpty ? ten : ma) }
            }
        }
        return ra
    }

    /// Số vấn đề loại `uncited` — tách riêng vì nó là loại duy nhất làm tài liệu KHÔNG KIỂM ĐƯỢC.
    public static func soKhongNguon(_ x: Any?) -> Int {
        ((x as? [[String: Any]]) ?? []).filter { ($0["kind"] as? String) == "uncited" }.count
    }

    public static func oVanDe(_ x: Any?) -> String {
        let ds = (x as? [[String: Any]]) ?? []
        guard !ds.isEmpty else { return "không" }
        let kn = soKhongNguon(x)
        let con = ds.count - kn
        var phan: [String] = []
        if kn > 0 { phan.append("⛔ \(kn) KHÔNG NGUỒN") }
        if con > 0 { phan.append("\(con) văn phong") }
        return phan.joined(separator: " · ")
    }

    public static func oMucCu(_ x: Any?) -> String {
        let n = ((x as? [Any]) ?? []).count
        return n == 0 ? "—" : "⚠ \(n)"
    }

    private func _bangCanhBao(_ soCu: Int, _ khongNguon: Int) {
        var phan: [String] = []
        if khongNguon > 0 {
            phan.append("⛔ \(khongNguon) khẳng định KHÔNG CÓ NGUỒN — tài liệu ấy không kiểm "
                        + "lại được, và đó là thứ cả sản phẩm tồn tại để tránh")
        }
        if soCu > 0 {
            phan.append("⚠ \(soCu) tài liệu có mục đã CŨ so với mã — `doc.sync` dựng lại chúng")
        }
        let n = NSTextField(wrappingLabelWithString: phan.joined(separator: ". ") + ".")
        n.font = EideToken.fontUI
        n.textColor = khongNguon > 0 ? EideToken.Mau.bad : EideToken.Mau.warn
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = khongNguon > 0 ? EideToken.Mau.badBg : EideToken.Mau.warnBg
        them(n)
    }
}
