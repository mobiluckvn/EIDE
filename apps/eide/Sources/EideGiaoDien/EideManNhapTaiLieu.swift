import AppKit
import EideLoi

/// **S4 — Nhập tài liệu.** UXC-31 §8 S4; năng lực `ingest.*`, `extract.*`, `archive.*`.
///
/// ## Đây là bước đầu tiên trong đời một dự án
///
/// Mọi thứ về sau đứng trên nó: không có nguồn thì không có fact, không có fact thì
/// `code.constant_guard` chặn mọi hằng số phần cứng, và tác tử dừng ở phần tri thức. Màn này
/// vì thế phải làm đúng một việc cho thật gọn — biến một tệp trong Finder thành fact có nguồn.
///
/// ## Đường ống, và vì sao đúng thứ tự ấy
///
/// 1. `ingest.classify` — chữ ký nội dung TRƯỚC phần mở rộng. Nó trả `extractor`, tức tên năng
///    lực phải chạy tiếp; màn này là bên gọi ĐẦU TIÊN dispatch trên trường ấy.
/// 2. `ingest.hash_dedupe` — băm NỘI DUNG. Cùng một datasheet tải hai lần vào hai chỗ là cùng
///    một nguồn; trích lại lần hai sinh ra một bộ fact trùng, và mỗi fact trùng là một mục nữa
///    phải duyệt ở G-FACT.
/// 3. extractor của từng tệp MỚI.
/// 4. `ingest.index_text` cho README/md — chỉ tài liệu ngữ cảnh, không phải datasheet.
///
/// ## Điều màn này KHÔNG có, và đã ghi ra
///
/// UXC-31 đòi một **bảng nguồn thường trực** kèm trạng thái duyệt. Không năng lực nào trong 242
/// cái đọc ra bảng `source` — xem [DEV-134]. Nên ở đây có hai bảng thật thà hơn: bảng của LƯỢT
/// NHẬP vừa chạy, và LỊCH SỬ NHẬP dựng từ sổ cái. Không cái nào tự nhận là danh mục nguồn.
public final class EideManNhapTaiLieu: EideManCoSo {

    public override class var tien: String { "Ingest" }

    /// Số lần nhập gần nhất đọc từ sổ cái.
    public static let TOI_DA = 40

    /// Tên tham số nhận ĐƯỜNG DẪN của từng năng lực trích.
    ///
    /// Bảy trong chín extractor nhận `file`. Hai cái còn lại không, và gửi sai tên cho chúng
    /// trả E1000 cho đúng hai loại tệp thường gặp: `csv` và kho nén. Bảng này có bản sinh đôi
    /// trong `tests/test_ingest_passport.py::test_extractor_nhan_tep_qua_dung_ten_tham_so` —
    /// phía ấy đọc thẳng `input_schema`, nên một extractor mới nhận tên khác sẽ làm bài kiểm
    /// Python đỏ trước khi kịp làm màn này câm.
    public static let THAM_TEP: [String: String] = [
        "archive.list": "path",
        "extract.bom": "sources",
    ]

    private var goiLoi: EideGoi?
    private let cocTienDo = NSStackView()
    private let vungTha = EideVungTha(loiMoi: "Kéo PDF · SVD · ATDF · netlist · BOM vào đây")

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocTienDo.orientation = .vertical
        cocTienDo.alignment = .leading
        cocTienDo.spacing = 4

        vungTha.onTha = { [weak self] ds in
            Task { await self?.nhap(ds) }
        }
        them(vungTha)
        them(cocTienDo)

        let lan = await _lichSuNhap(goi)
        guard !lan.isEmpty else {
            // Đúng câu UXC-31 quy định cho trạng thái rỗng của S4 — và vùng thả vẫn nằm trên
            // nó, vì lời mời và lời giải thích là hai việc khác nhau.
            return rong(vi: "chưa nhập tài liệu nào vào dự án này",
                        buocKe: "kéo PDF/SVD/BOM vào vùng trên, hoặc chạy "
                              + "`eide ingest <tệp>` ở dòng lệnh")
        }
        tieuDePhu("\(lan.count) LẦN NHẬP GẦN ĐÂY — theo sổ cái, không phải danh mục nguồn (DEV-134)")
        // "FACT MỚI", không phải "FACT". `store.write` đếm số fact GHI RA; một lô mà mọi fact
        // đã có sẵn thì gộp hết và con số ấy bằng 0 — đúng, nhưng đọc "FACT 0" thành "lần nhập
        // này hỏng". Đo 20/09 trên hai lượt `passport.import` gộp: bảng nói 2 lần nhập · 0 fact.
        bang(cot: [("LÚC", 132), ("LÔ / LÝ DO", 220), ("FACT MỚI", 84), ("XUNG ĐỘT", 84), ("AI", 0)],
             dong: lan)
    }

    // MARK: - đường ống nhập

    /// Chạy cả đường ống cho một lô tệp, in tiến độ từng bước.
    ///
    /// Tiến độ in ra NGAY chứ không dồn tới cuối: `extract.pdf_layout` trên một reference manual
    /// 1200 trang chạy hàng chục giây, và một màn đứng im suốt từng ấy thời gian là một màn
    /// người dùng cho là treo — cùng lớp lỗi với nhãn "Đang đọc…" của `EideManCoSo.nap`.
    public func nhap(_ ds: [String]) async {
        guard let goi = goiLoi else { return }
        _xoaTienDo()
        _tienDo("Nhận \(ds.count) tệp — đang phân loại…", mau: EideToken.Mau.muted)

        let phanLoai: [[String: Any]]
        do {
            let r = try await nangLuc(goi, "ingest.classify", ["files": ds])
            phanLoai = (r["classification"] as? [[String: Any]]) ?? []
        } catch {
            return _tienDo("Không phân loại được: \(error)", mau: EideToken.Mau.bad)
        }

        // Trùng lặp hỏi TRƯỚC khi trích, không phải sau: cả điểm của `hash_dedupe` là tránh
        // chạy lại một lượt trích đắt tiền.
        var trung: Set<String> = []
        if let r = try? await nangLuc(goi, "ingest.hash_dedupe", ["files": ds]) {
            for d in (r["dup"] as? [[String: Any]]) ?? [] {
                if let f = d["file"] as? String { trung.insert(f) }
            }
        }

        var dong: [[String]] = []
        for x in phanLoai {
            let tep = (x["file"] as? String) ?? "?"
            let ten = (tep as NSString).lastPathComponent
            let loai = (x["kind"] as? String) ?? "?"
            let tang = (x["tier"] as? String) ?? ""
            let tin = (x["confidence"] as? Double).map { String(format: "%.1f", $0) } ?? "?"

            if trung.contains(tep) {
                dong.append([ten, loai, tang, tin, "đã có trong store — bỏ qua"])
                continue
            }
            guard let ex = x["extractor"] as? String else {
                // `extractor = null` là một câu trả lời, không phải chỗ trống: README/md đi
                // đường chỉ mục toàn văn, còn ảnh và HTML thì chưa có năng lực nào đọc.
                dong.append([ten, loai, tang, tin, Self.viSaoKhongTrich(loai)])
                continue
            }
            _tienDo("\(ten) → \(ex)…", mau: EideToken.Mau.muted)
            dong.append([ten, loai, tang, tin, await _chay(goi, ex, tep)])
        }

        // README/md: chỉ mục toàn văn, KHÔNG thành fact. Bước 1 của ARCHIVE-07 giới hạn đúng
        // thế, và lý do đáng nhớ: đổ datasheet vào FTS5 sẽ khiến `memory.retrieve` trả về đoạn
        // văn không trích dẫn được, cạnh tranh chỗ với fact có trích dẫn.
        let vanBan = phanLoai.compactMap { x -> String? in
            let k = (x["kind"] as? String) ?? ""
            return (k == "readme" || k == "md") ? x["file"] as? String : nil
        }
        if !vanBan.isEmpty,
           let r = try? await nangLuc(goi, "ingest.index_text", ["files": vanBan]) {
            let n = (r["indexed"] as? [Any])?.count ?? 0
            _tienDo("Đã lập chỉ mục toàn văn cho \(n) tệp ngữ cảnh.", mau: EideToken.Mau.muted)
        }

        _tienDo("Xong \(dong.count) tệp.", mau: EideToken.Mau.ok)
        tieuDePhu("LƯỢT NHẬP VỪA RỒI")
        bang(cot: [("TỆP", 210), ("LOẠI", 92), ("TẦNG", 74), ("ĐỘ TIN", 68), ("KẾT QUẢ", 0)],
             dong: dong)
    }

    /// Chạy một extractor cho một tệp, trả về Ô KẾT QUẢ.
    ///
    /// `pending` không phải lỗi: extractor là R1, và với một dự án đặt mức tự chủ thấp thì cổng
    /// hỏi người trước khi fact vào store. Nói "đã trích 0 fact" lúc ấy là nói sai.
    private func _chay(_ goi: @escaping EideGoi, _ ex: String, _ tep: String) async -> String {
        let khoa = Self.THAM_TEP[ex] ?? "file"
        let tham: [String: Any] = khoa == "sources" ? [khoa: [tep]] : [khoa: tep]
        do {
            let r = try await goi("caps.invoke", ["id": ex, "params": tham])
            switch r["status"] as? String {
            case "done":
                let kq = (r["result"] as? [String: Any]) ?? [:]
                if let n = kq["n_facts"] as? Int { return "\(n) fact" }
                if let e = kq["entries"] as? [Any] { return "\(e.count) mục trong kho" }
                return "xong"
            case "pending":
                return "CHỜ DUYỆT — " + EideManXungDot.vinao(r["decision"])
            default:
                let e = (r["error"] as? [String: Any]) ?? [:]
                return "lỗi: " + ((e["message"] as? String) ?? "\(r["status"] ?? "?")")
                     + ((e["eide_code"] as? String).map { " (\($0))" } ?? "")
            }
        } catch {
            return "không gọi được: \(error)"
        }
    }

    /// Nhãn nhận dạng một lần nhập.
    ///
    /// `reason` của `store.write` là chuỗi RỖNG trong đường đi thường gặp nhất: `passport.import`
    /// không nhận `reason` từ bên gọi, nên nó ghi `""`. Một phép `?? "nhập tri thức"` không cứu
    /// được vì `""` không phải `nil` — đo 20/09 trên cửa sổ thật, cột ấy trống trơn suốt cả bảng.
    /// `batch_id` thì luôn có, và nó là thứ tra ngược được về đúng lô fact.
    public static func nhanLo(_ d: [String: Any]) -> String {
        if let ly = d["reason"] as? String, !ly.trimmingCharacters(in: .whitespaces).isEmpty {
            return ly
        }
        if let lo = d["batch_id"] as? String, !lo.isEmpty {
            return "lô \(lo.hasPrefix("b_") ? String(lo.dropFirst(2).prefix(10)) : lo)"
        }
        return "nhập tri thức"
    }

    /// Vì sao một loại tệp không có extractor — nói ra, đừng để ô trống.
    public static func viSaoKhongTrich(_ loai: String) -> String {
        switch loai {
        case "readme", "md": return "tài liệu ngữ cảnh — vào chỉ mục toàn văn, không thành fact"
        case "image": return "cần đường ảnh cho Gateway (DEV-076/DEV-079) — chưa đọc được"
        case "html": return "chưa năng lực nào đọc HTML thành fact"
        case "unknown": return "không nhận ra loại — kiểm lại tệp"
        default: return "không có extractor cho loại này"
        }
    }

    // MARK: - lịch sử

    /// Lịch sử nhập, đọc từ SỔ CÁI.
    ///
    /// `store.write` mang `{batch_id, n_facts, n_conflicts, actor, reason}` — đủ để nói mỗi lần
    /// nhập ghi được bao nhiêu fact và vấp bao nhiêu xung đột, KHÔNG đủ để nói mỗi NGUỒN có bao
    /// nhiêu fact. Khác biệt ấy là toàn bộ nội dung của [DEV-134], và tiêu đề bảng nói thẳng ra
    /// thay vì để người đọc tưởng đây là danh mục nguồn.
    private func _lichSuNhap(_ goi: @escaping EideGoi) async -> [[String]] {
        guard let r = try? await doc(goi, "view.timeline", ["limit": 400]),
              let ds = r["events"] as? [[String: Any]] else { return [] }
        var ra: [[String]] = []
        for e in ds.reversed() where (e["kind"] as? String) == "store.write" {
            let d = (e["data"] as? [String: Any]) ?? [:]
            ra.append([
                EideManNhatKy.gio(e["at"] as? String),
                Self.nhanLo(d),
                "\(d["n_facts"] as? Int ?? 0)",
                "\(d["n_conflicts"] as? Int ?? 0)",
                EideManNhatKy.ai(d["actor"] as? String),
            ])
            if ra.count >= Self.TOI_DA { break }
        }
        return ra
    }

    // MARK: - tiến độ

    private func _tienDo(_ s: String, mau: NSColor) {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        cocTienDo.addArrangedSubview(n)
    }

    private func _xoaTienDo() {
        for v in cocTienDo.arrangedSubviews {
            cocTienDo.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    /// Cho test và cho `--tu-kiem` đẩy tệp vào mà không cần một thao tác kéo thật.
    public func thaDeTest(_ ds: [String]) { vungTha.thaDeTest(ds) }
}
