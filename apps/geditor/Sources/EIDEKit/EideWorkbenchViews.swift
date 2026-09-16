import AppKit

/// Bốn màn "bàn làm việc" — UXD-13 màn 2 (Main), 4 (Ingest), 6 (Board), 8 (ReqArch).
///
/// Spec: CDS-12 PROJECT-05 `project.status`, TARGET-01 `target.detect`, INGEST-01..03,
/// ARCHIVE-01, BOARD-01..05, REQ-01..08, ARCH-01..11; UXD-13 §2 bảng màn hình, U2, U9.
///
/// ## Một bất biến chung
///
/// Bốn màn này là nơi dữ liệu ĐI VÀO dự án (tài liệu, netlist, yêu cầu) và nơi tổng hợp lại
/// những gì đã vào. Bất biến của chúng khác với ba màn tri thức: ở đó là "không hiện số mà
/// không hiện nguồn", ở đây là **không có thứ gì đi vào tri thức mà người không thấy nó đi**.
/// Một tệp được phân loại sai tầng, một chân bị xung đột, một yêu cầu không đo được — cả ba
/// đều là thứ sẽ nằm im rất lâu nếu màn hình không bắt người nhìn vào chúng ngay lúc chúng
/// xuất hiện.

// MARK: - Màn 2: Tổng quan dự án

/// `project.status` `{report{features, gates_open, undo_items, cost_today, autonomy, target}}`
/// và `target.detect` `{targets[]{id, kind, port, probe, chip_id, lab}}`.
public final class ProjectStatusView: ManHinhCoSo {

    public var onMoTinhNang: ((String) -> Void)?

    public private(set) var soTinhNang = 0
    public private(set) var soFailing = 0
    public private(set) var soCongMo = 0
    /// Chi phí hôm nay, USD. Hiện cả khi bằng 0 — xem `capNhat`.
    public private(set) var chiPhiHomNay: Double = 0

    public init() { super.init(ten: "Tổng quan dự án") }

    /// **`cost_today` hiện cả khi bằng 0.** Một con số chi phí chỉ xuất hiện lúc nó đã lớn là
    /// con số người dùng gặp lần đầu vào đúng lúc muộn nhất. Hiện từ 0,00 USD thì người có một
    /// đường cơ sở để so, và một ngày nó nhảy vọt thì họ nhận ra ngay.
    ///
    /// **Mức tự chủ ở đây đối chiếu với `AutonomyBar`, không thay nó.** Hai chỗ hiện cùng một
    /// giá trị là hai chỗ có thể lệch nhau; nếu lệch thì cái sai nguy hiểm hơn cái thiếu, nên
    /// màn này nói thẳng "A3 (thanh trên nói A2)" thay vì im lặng chọn một trong hai.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soTinhNang = 0; soFailing = 0; soCongMo = 0; chiPhiHomNay = 0

        // `project.status` bọc trong `report`; `target.detect` trả thẳng `targets`.
        let bc = (ketQua["report"] as? [String: Any]) ?? ketQua
        if bc.isEmpty {
            tomTat.stringValue = ""
            // Hai tình huống, hai câu. `report` rỗng mà CÓ phiên nghĩa là dự án đã mở, chỉ chưa
            // có tính năng nào — khác hẳn chưa mở dự án. Nói nhầm câu ở đây là gửi người dùng
            // đi tạo dự án thứ hai trong lúc dự án thứ nhất đang mở.
            if ketQua["session"] != nil {
                noiRong("Dự án đã mở nhưng chưa có tính năng nào — gõ yêu cầu ở ô lệnh, "
                        + "hoặc chạy `/req.elicit` để bắt đầu từ ý tưởng.")
                _hienPhien(ketQua)
            } else {
                noiRong("Chưa mở dự án nào — Tệp → Mở dự án EIDE…, hoặc gõ "
                        + "\"tạo dự án cho chip STM32F411\" ở ô lệnh.")
            }
            return
        }

        let tinhNang = (bc["features"] as? [[String: Any]]) ?? []
        let cong = (bc["gates_open"] as? [[String: Any]]) ?? []
        let hoanTac = (bc["undo_items"] as? [[String: Any]]) ?? []
        chiPhiHomNay = EideSo.thuc(bc["cost_today"]) ?? Double(EideSo.nguyen(bc["cost_today"]) ?? 0)
        let tuChu = (bc["autonomy"] as? String) ?? ""
        let dich = bc["target"]

        // `features` và `gates_open` tới ở HAI hình dạng, và màn phải đọc được cả hai.
        //
        // Hợp đồng PROJECT-04 để `report` là `object` tự do với một dòng mô tả liệt kê tên
        // trường — không nói trường nào là mảng, trường nào là số. Hiện thực trả `features:
        // {total, passing, failing, first_failing}` và `gates_open: 0` (đếm sẵn); màn thì đọc cả
        // hai như MẢNG, nên nó nhận `nil`, gán 0, và Tổng quan hiện đúng MỘT dòng trên một dự án
        // có 8 fact, 4 mục hoàn tác và một chip đã ghim. Đo 16/09/2026 bằng bài kiểm kê 23 màn.
        //
        // Đọc dạng đếm sẵn TRƯỚC: nó là thứ hiện thực thật sự trả về. Dạng mảng giữ lại vì
        // `target.detect` và các bản ghi cũ dùng nó.
        if let dem = bc["features"] as? [String: Any] {
            soTinhNang = EideSo.nguyen(dem["total"]) ?? 0
            soFailing = EideSo.nguyen(dem["failing"])
                ?? max(0, soTinhNang - (EideSo.nguyen(dem["passing"]) ?? soTinhNang))
        } else {
            soTinhNang = tinhNang.count
            soFailing = tinhNang.filter { ((($0["status"] as? String) ?? "")) != "passing" }.count
        }
        soCongMo = EideSo.nguyen(bc["gates_open"]) ?? cong.count

        var d: [String] = []
        if soTinhNang > 0 {
            d.append("\(soTinhNang - soFailing)/\(soTinhNang) tính năng passing")
        }
        if soCongMo > 0 { d.append("\(soCongMo) cổng đang mở") }
        if !hoanTac.isEmpty { d.append("\(hoanTac.count) hoàn tác được") }
        d.append(String(format: "%.2f USD hôm nay", chiPhiHomNay))
        if !tuChu.isEmpty { d.append("tự chủ \(tuChu)") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = soFailing > 0 ? EideToken.Mau.warn : EideToken.Mau.muted

        if let t = _moTaDich(dich) { themDong("Đích", t, mau: EideToken.Mau.info) }
        _hienPhien(ketQua)

        // `target.detect` trả `targets[]` — NHIỀU đích, khác hẳn `report.target` (đích đang
        // ghim). Cắm hai board cùng lúc là chuyện thường ở bàn thí nghiệm, và một màn chỉ hiện
        // một cái sẽ nạp firmware lên cái người dùng không nghĩ tới.
        for t in (ketQua["targets"] as? [[String: Any]]) ?? [] {
            let lab = ((t["lab"] as? Bool) ?? false) ? " · LAB (tự nạp được)" : ""
            themDong((t["id"] as? String) ?? (t["chip_id"] as? String) ?? "?",
                     [(t["kind"] as? String) ?? "", (t["port"] as? String) ?? "",
                      (t["probe"] as? String) ?? ""].filter { !$0.isEmpty }
                        .joined(separator: " · ") + lab,
                     mau: EideToken.Mau.info)
        }

        for f in tinhNang {
            let ma = (f["id"] as? String) ?? (f["code"] as? String) ?? "?"
            let ten = (f["name"] as? String) ?? (f["title"] as? String) ?? ""
            let tt = (f["status"] as? String) ?? "?"
            // Bằng chứng đi CÙNG dòng trạng thái. "passing" không kèm bằng chứng là một lời
            // khẳng định trần; FEATURES.json có cột ấy chính vì thế.
            let bang = (f["evidence"] as? String) ?? (f["gate"] as? String) ?? ""
            themDong("\(ma) \(ten)",
                     tt + (bang.isEmpty ? "" : " · \(bang)"),
                     mau: tt == "passing" ? EideToken.Mau.ok : EideToken.Mau.warn,
                     nut: true, ma: ma, bam: #selector(moTinhNang(_:)))
        }

        for g in cong {
            let loai = (g["gate"] as? String) ?? (g["kind"] as? String) ?? "cổng"
            let vi = (g["reason"] as? String) ?? (g["capability"] as? String) ?? ""
            themDong(loai, "chờ anh quyết \(vi)", mau: EideToken.Mau.warn)
        }

        if soDong == 0 { noiRong("Dự án đã mở nhưng chưa có tính năng nào — `req.elicit` trước.") }
    }

    private func _moTaDich(_ v: Any?) -> String? {
        if let s = v as? String, !s.isEmpty { return s }
        guard let t = v as? [String: Any] else { return nil }
        // `chip` là tên `project.status` dùng; `chip_id`/`id` là tên `target.detect` dùng. Bản cũ
        // hỏi hai cái sau rồi rơi về `"?"`, nên màn Tổng quan hiện `Đích  ?` trên một dự án đã
        // ghim `esp.esp32c3` — đúng con chip mà mọi thứ khác trong dự án dựa vào. Đo 16/09/2026.
        let chip = (t["chip"] as? String) ?? (t["chip_id"] as? String) ?? (t["id"] as? String)
            ?? "?"
        let cong = (t["port"] as? String).map { " · \($0)" } ?? ""
        let probe = (t["probe"] as? String).map { " · \($0)" } ?? ""
        // `lab` không phải nhãn trang trí: board đánh dấu lab mới được tự nạp (BOARD-05),
        // nên nó là một quyền, và một quyền thì phải nhìn thấy được.
        let lab = ((t["lab"] as? Bool) ?? false) ? " · LAB (tự nạp được)" : ""
        // `board: null` nói một điều THẬT và quan trọng: chip đã ghim, board thì chưa. Im lặng ở
        // đây để người dùng tự đoán xem `nạp firmware` sẽ đi đâu.
        let board: String
        if let b = t["board"] as? String, !b.isEmpty {
            board = " · board \(b)"
        } else if t.keys.contains("board") {
            board = " · chưa gắn board"
        } else {
            board = ""
        }
        return chip + board + cong + probe + lab
    }

    @objc private func moTinhNang(_ s: NSButton) {
        if let m = s.identifier?.rawValue, !m.isEmpty { onMoTinhNang?(m) }
    }
}

// MARK: - Màn 4: Nhập tài liệu

/// `ingest.classify` `{classification[]{file, kind, tier, extractor, confidence}}`,
/// `ingest.hash_dedupe` `{new[], dup[]}`, `archive.list` `{entries[]}`.
extension ProjectStatusView {

    /// Trạng thái PHIÊN (M2) — `session.state`, USECASE §4 mục 7.
    ///
    /// MEM-11 §2 định nghĩa M2 là thứ sống từ lúc mở tới lúc đóng dự án: lịch sử lượt, quyền
    /// theo phiên (R4), target đang cắm, mức tự chủ hiệu lực, việc hoàn tác được. Trước 15/09
    /// giao diện không hiện gì về nó — người dùng không có cách nào biết phiên này đã cấp
    /// những quyền gì.
    ///
    /// **Hai trường rỗng được NÓI RA, không giấu đi.** `permits` và `board` có trong hợp đồng
    /// nhưng `SessionMemory` chưa lưu (DEV-110). Im lặng bỏ chúng thì khoảng trống biến mất
    /// khỏi tầm nhìn — đúng khuôn DEV-093, nơi một thiếu sót nằm im vì không ai hỏi tới.
    func _hienPhien(_ ketQua: [String: Any]) {
        guard let s = ketQua["session"] as? [String: Any] else { return }
        if let id = s["session_id"] as? String {
            var ct = id
            if let n = EideSo.nguyen(s["turns"]), n > 0 { ct += " · \(n) lượt" }
            if let u = EideSo.nguyen(s["undo_items"]), u > 0 { ct += " · \(u) hoàn tác được" }
            themDong("phiên", ct)
        }
        let quyen = (s["permits"] as? [Any])?.compactMap { $0 as? String } ?? []
        if !quyen.isEmpty {
            // Quyền R4 theo phiên là thứ nguy hiểm nhất còn hiệu lực trong một phiên: nó cho
            // tác tử làm một việc KHÔNG HOÀN TÁC ĐƯỢC mà không hỏi lại.
            themDong("quyền R4 đang có hiệu lực", quyen.joined(separator: " · "),
                     mau: EideToken.Mau.warn)
        }
        if let b = s["board"] as? String, !b.isEmpty {
            themDong("board đã gắn vào phiên", b, mau: EideToken.Mau.info)
        }
        let thieu = (s["thieu"] as? [Any])?.compactMap { $0 as? String } ?? []
        if thieu.contains("permits") || thieu.contains("board") {
            noiRong("Quyền R4 theo phiên và board đã gắn CHƯA được lưu — MEM-11 §2 kể chúng "
                    + "trong M2 nhưng `SessionMemory` chưa có hai trường ấy. Xem DEV-110.")
        }
    }
}

public final class IngestView: ManHinhCoSo {

    public var onTrichXuat: ((String) -> Void)?

    public private(set) var soTep = 0
    public private(set) var soTrung = 0
    /// Số tệp phân loại với độ tin cậy dưới ngưỡng — xem `capNhat`.
    public private(set) var soThapTin = 0

    /// Dưới mức này thì việc phân loại là một PHỎNG ĐOÁN, và nó phải đọc ra như phỏng đoán.
    /// 0,6 là cùng ngưỡng DPS-09 §4.1 dùng cho intent (`confidence < 0,6 ⇒ unknown`): một sản
    /// phẩm có hai ngưỡng tin cậy khác nhau cho cùng một ý là sản phẩm không giải thích được.
    public static let nguongTin = 0.6

    public init() { super.init(ten: "Nhập tài liệu") }

    /// **Tệp phân loại yếu không được trôi qua trong im lặng.** Cột "đường đi" của mockup nói
    /// mỗi tệp sẽ thành cái gì — hộ chiếu, ngữ cảnh, hay bỏ qua — và đó là quyết định đắt nhất
    /// trong cả màn: một datasheet bị đọc nhầm thành "văn bản ngữ cảnh" thì 42 fact thanh ghi
    /// không bao giờ ra đời, và không có gì báo lỗi cả, vì không có gì hỏng.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soTep = 0; soTrung = 0; soThapTin = 0

        let pl = (ketQua["classification"] as? [[String: Any]]) ?? []
        let moi = (ketQua["new"] as? [String]) ?? []
        let trung = (ketQua["dup"] as? [[String: Any]]) ?? []
        let muc = (ketQua["entries"] as? [[String: Any]]) ?? []
        let daChiMuc = EideSo.nguyen(ketQua["indexed"])
        // Kết quả TRÍCH XUẤT — 15 năng lực `extract.*` cùng đổ về màn này, và phần lớn chúng
        // trả một `batch_id` với số fact sinh ra. Không hiện thì cả nhóm extract chạy trong im
        // lặng: người thả một PDF vào, thấy dòng "đã phân loại", rồi không bao giờ biết 42 fact
        // thanh ghi có ra đời hay không.
        let lo = (ketQua["batch_id"] as? String) ?? ""
        let soFact = EideSo.nguyen(ketQua["n_facts"])
        let yeu = EideSo.nguyen(ketQua["low_confidence"]) ?? 0
        let linhKien = (ketQua["part"] as? String) ?? ""
        let tepGiai = (ketQua["files"] as? [String]) ?? []
        let boQua = (ketQua["skipped"] as? [[String: Any]]) ?? []
        let khop = (ketQua["matches"] as? [[String: Any]]) ?? []
        let khoi = (ketQua["blocks"] as? [[String: Any]]) ?? []
        let mucLuc = (ketQua["toc"] as? [[String: Any]]) ?? []
        let bom = (ketQua["bom"] as? [[String: Any]]) ?? []
        let khongKhop = (ketQua["unmatched"] as? [String]) ?? []
        let mucTieu = (ketQua["goal"] as? String) ?? ""
        let tinhNang = (ketQua["features"] as? [[String: Any]]) ?? []
        let donVi = EideSo.nguyen(ketQua["code_units"])
        let khongNguon = (ketQua["unsourced"] as? [[String: Any]]) ?? []
        let chuThich = (ketQua["text_blocks"] as? [[String: Any]]) ?? []
        let linhKienAnh = (ketQua["parts"] as? [[String: Any]]) ?? []
        let nguon = (ketQua["source_id"] as? String) ?? ""
        let doDuoc = ketQua["measurement"] as? [String: Any]
        let kyNang = (ketQua["skill_path"] as? String) ?? ""

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Kéo thả tài liệu vào ô lệnh, hoặc `/archive.list <tệp.zip>`.")
            return
        }

        soTrung = trung.count
        soThapTin = pl.filter { (($0["confidence"] as? Double) ?? 1) < Self.nguongTin }.count

        var d: [String] = []
        if !pl.isEmpty {
            let tang = Dictionary(grouping: pl, by: { ($0["tier"] as? String) ?? "?" })
                .map { "\($0.value.count) \(_tenTang($0.key))" }.sorted()
            d.append("\(pl.count) tệp")
            d.append(contentsOf: tang)
        }
        if !muc.isEmpty { d.append("\(muc.count) mục trong kho nén") }
        if !moi.isEmpty { d.append("\(moi.count) mới") }
        if soTrung > 0 { d.append("\(soTrung) trùng hash") }
        if let n = daChiMuc { d.append("\(n) tệp đã lập chỉ mục") }
        if soThapTin > 0 { d.append("\(soThapTin) CHƯA CHẮC") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = soThapTin > 0 ? EideToken.Mau.warn : EideToken.Mau.muted

        // Chưa chắc lên đầu: chúng là thứ duy nhất ở màn này cần người nhìn.
        let xep = pl.sorted { (($0["confidence"] as? Double) ?? 1) < (($1["confidence"] as? Double) ?? 1) }
        for c in xep {
            let tep = (c["file"] as? String) ?? "?"
            let loai = (c["kind"] as? String) ?? "?"
            let tang = (c["tier"] as? String) ?? ""
            let bo = (c["extractor"] as? String) ?? ""
            let tin = EideSo.thuc(c["confidence"]) ?? 1
            let yeu = tin < Self.nguongTin
            soTep += 1
            let duongDi = bo.isEmpty ? "không sinh fact — giữ làm ngữ cảnh" : "→ \(bo)"
            themDong(EideKnowledgeFormat.tenNgan(tep),
                     "\(loai) · \(_tenTang(tang)) · \(duongDi)"
                        + (yeu ? String(format: " · tin cậy %.0f%% — CẦN ANH XEM", tin * 100) : ""),
                     mau: yeu ? EideToken.Mau.bad : EideKnowledgeFormat.mauTang(tang, ""),
                     nut: !bo.isEmpty, ma: tep, bam: #selector(trichXuat(_:)))
        }

        for t in trung {
            let tep = (t["file"] as? String) ?? (t["path"] as? String) ?? "?"
            let voi = (t["source_id"] as? String).map { " — đã có: \($0)" } ?? ""
            themDong(EideKnowledgeFormat.tenNgan(tep), "trùng hash, bỏ qua\(voi)",
                     mau: EideToken.Mau.muted)
        }

        for m in muc.prefix(50) {
            let p = (m["path"] as? String) ?? "?"
            let doan = (m["kind_guess"] as? String) ?? ""
            let long = ((m["nested"] as? Bool) ?? false) ? " · kho lồng" : ""
            themDong(p, doan + long)
        }
        if muc.count > 50 { noiRong("… và \(muc.count - 50) mục nữa (hiện 50 đầu).") }

        _hienTrichXuat(lo: lo, soFact: soFact, yeu: yeu, linhKien: linhKien,
                       tepGiai: tepGiai, boQua: boQua, khop: khop, khoi: khoi,
                       mucLuc: mucLuc, bom: bom, khongKhop: khongKhop, mucTieu: mucTieu,
                       tinhNang: tinhNang, donVi: donVi, khongNguon: khongNguon,
                       chuThich: chuThich, linhKienAnh: linhKienAnh, nguon: nguon,
                       giayPhep: (ketQua["license"] as? String) ?? "",
                       bam: EideSo.nguyen(ketQua["size_bytes"]),
                       doDuoc: doDuoc, kyNang: kyNang)

        if soDong == 0 { noiRong("Không có tệp nào được nhận diện.") }
    }

    /// Kết quả của nhóm `extract.*`, `archive.*` và `search.fetch`.
    ///
    /// **`low_confidence` đi CÙNG `n_facts`, không tách ra chỗ khác.** EXTRACT-06 đếm riêng số
    /// fact đọc được với độ tin cậy thấp, và đó là con số quyết định người có phải mở PDF ra
    /// đối chiếu hay không. Hiện "42 fact" mà nuốt mất "9 trong đó chưa chắc" là mời người tin
    /// cả 42.
    private func _hienTrichXuat(lo: String, soFact: Int?, yeu: Int, linhKien: String,
                                tepGiai: [String], boQua: [[String: Any]],
                                khop: [[String: Any]], khoi: [[String: Any]],
                                mucLuc: [[String: Any]], bom: [[String: Any]],
                                khongKhop: [String], mucTieu: String,
                                tinhNang: [[String: Any]], donVi: Int?,
                                khongNguon: [[String: Any]], chuThich: [[String: Any]],
                                linhKienAnh: [[String: Any]], nguon: String,
                                giayPhep: String, bam: Int?,
                                doDuoc: [String: Any]?, kyNang: String) {
        if let m = doDuoc {
            // EXTRACT-15 đọc SỐ ĐO từ ảnh chụp màn hình máy hiện sóng. Một con số đọc từ ảnh
            // không phải một phép đo — nó là phép đọc lại một phép đo, và sai số của người
            // chụp, của thang chia, của nén ảnh đều nằm trong đó.
            let mo = m.sorted { $0.key < $1.key }
                .map { "\($0.key)=\(EideKnowledgeFormat.giaTri($0.value))" }
                .joined(separator: " · ")
            themDong("số đo đọc từ ảnh", mo + " — từ ẢNH, không phải phép đo trực tiếp",
                     mau: EideToken.Mau.warn)
        }
        if !kyNang.isEmpty {
            // EXTRACT-13 biến công thức trong datasheet thành một skill chạy được.
            themDong("skill sinh từ công thức", kyNang, mau: EideToken.Mau.info)
        }
        if !lo.isEmpty || soFact != nil {
            let n = soFact ?? 0
            themDong("lô trích xuất \(lo)",
                     "\(n) fact" + (linhKien.isEmpty ? "" : " cho \(linhKien)")
                        + (yeu > 0 ? " · \(yeu) CHƯA CHẮC — cần anh xem" : ""),
                     mau: yeu > 0 ? EideToken.Mau.warn : EideToken.Mau.ok)
        }
        if !tepGiai.isEmpty {
            themDong("giải nén", "\(tepGiai.count) tệp", mau: EideToken.Mau.info)
            for f in tepGiai.prefix(20) { themDong("  ", f) }
            if tepGiai.count > 20 { noiRong("… và \(tepGiai.count - 20) tệp nữa.") }
        }
        for s in boQua {
            // ARCHIVE-02 bỏ qua tệp vì zip-slip, quá sâu, hoặc quá lớn — ba lý do rất khác
            // nhau, và cái đầu là một cuộc tấn công chứ không phải một giới hạn.
            let ten = (s["path"] as? String) ?? "?"
            let vi = (s["reason"] as? String) ?? ""
            themDong("bỏ qua: \(ten)", vi, mau: EideToken.Mau.warn)
        }
        for m in khop.prefix(20) {
            themDong((m["path"] as? String) ?? "?", (m["snippet"] as? String) ?? "")
        }
        if !khoi.isEmpty {
            let loaiKhoi = Dictionary(grouping: khoi, by: { ($0["type"] as? String) ?? "?" })
                .map { "\($0.value.count) \($0.key)" }.sorted().joined(separator: " · ")
            themDong("bố cục", "\(khoi.count) khối — \(loaiKhoi)")
        }
        if !mucLuc.isEmpty { themDong("mục lục", "\(mucLuc.count) mục") }
        if !bom.isEmpty {
            themDong("BOM", "\(bom.count) linh kiện"
                        + (khongKhop.isEmpty ? "" : " · \(khongKhop.count) KHÔNG khớp"),
                     mau: khongKhop.isEmpty ? EideToken.Mau.ok : EideToken.Mau.warn)
            for b in bom.prefix(15) {
                let r = (b["ref"] as? String) ?? "?"
                let mpn = (b["mpn"] as? String) ?? "(chưa rõ mã)"
                themDong("  \(r)", mpn + ((b["value"] as? String).map { " · \($0)" } ?? ""),
                         mau: b["mpn"] == nil ? EideToken.Mau.warn : nil)
            }
        }
        for u in khongKhop.prefix(10) {
            themDong("không khớp linh kiện", u, mau: EideToken.Mau.warn)
        }
        if !mucTieu.isEmpty { themDong("mục tiêu đọc được", mucTieu, mau: EideToken.Mau.info) }
        for f in tinhNang.prefix(15) {
            themDong((f["title"] as? String) ?? "?",
                     (f["expectation"] as? String) ?? "chưa có kỳ vọng đo được",
                     mau: f["expectation"] == nil ? EideToken.Mau.warn : nil)
        }
        if let d = donVi {
            themDong("hằng số trong mã", "\(d) đơn vị"
                        + (khongNguon.isEmpty ? "" : " · \(khongNguon.count) KHÔNG NGUỒN"),
                     mau: khongNguon.isEmpty ? EideToken.Mau.ok : EideToken.Mau.bad)
        }
        for u in khongNguon.prefix(15) {
            let f = (u["file"] as? String) ?? "?"
            let l = EideSo.nguyen(u["line"]) ?? 0
            themDong("\(EideKnowledgeFormat.tenNgan(f)):\(l)",
                     "\(EideKnowledgeFormat.giaTri(u["literal"])) — không trỏ fact nào",
                     mau: EideToken.Mau.bad)
        }
        if !chuThich.isEmpty { themDong("OCR", "\(chuThich.count) khối chữ đọc được") }
        for p in linhKienAnh.prefix(15) {
            let nh = (p["label"] as? String) ?? "?"
            let dd = (p["mpn_guess"] as? String) ?? "chưa đoán được mã"
            themDong(nh, dd + " · từ ẢNH, cần người xác nhận", mau: EideToken.Mau.warn)
        }
        if !nguon.isEmpty {
            // SEARCH-09 tải về kèm license — một nguồn không rõ giấy phép không được vào kho.
            themDong("nguồn tải về \(nguon)",
                     (giayPhep.isEmpty ? "KHÔNG rõ giấy phép" : "giấy phép \(giayPhep)")
                        + (bam.map { " · \($0) byte" } ?? ""),
                     mau: giayPhep.isEmpty ? EideToken.Mau.bad : nil)
        }
    }

    private func _tenTang(_ t: String) -> String {
        switch t {
        case "gold": return "vàng"
        case "silver": return "bạc"
        case "bronze": return "đồng"
        case "": return "chưa xếp tầng"
        default: return t
        }
    }

    @objc private func trichXuat(_ s: NSButton) {
        if let t = s.identifier?.rawValue, !t.isEmpty { onTrichXuat?(t) }
    }
}

// MARK: - Màn 6: Hộ chiếu mạch

/// `board.build_passport` `{board_passport_id, nets, warnings[]}`,
/// `board.check_pins` `{conflicts[]{pin, kind, detail, severity}}`,
/// `diagram.pinmap` `{diagram, table[]}`.
public final class BoardView: ManHinhCoSo {

    /// Nhận cả object xung đột, không chỉ tên chân: `board.propose_fix` đòi `conflict` là một
    /// object `{pin, kind, detail, severity}`. Trả mỗi tên chân rồi để panel dựng lại object là
    /// dựng một thứ gần giống bản gốc — và "gần giống" ở một đề xuất sửa mạch thì không đủ.
    public var onXemChan: (([String: Any]) -> Void)?

    public private(set) var soXungDot = 0
    public private(set) var soChan = 0
    public private(set) var soNet = 0
    /// Đã chạy `board.check_pins` cho dữ liệu đang hiện chưa — xem `capNhat`.
    public private(set) var daKiemChan = false

    public init() { super.init(ten: "Hộ chiếu mạch") }

    /// **Bảng chân chưa kiểm hiện ra kèm lời nhắc rằng nó chưa được kiểm.**
    ///
    /// `diagram.pinmap` vẽ được bảng chân từ HwMap mà không cần `board.check_pins` chạy trước.
    /// Một bảng chân trông đầy đủ và sạch sẽ thì đọc y như một bảng chân đã qua kiểm tra — và
    /// người ta hàn theo nó. Xung đột PB3 trong mockup (LED_STATUS đè SPI1_MOSI) đúng là loại
    /// lỗi chỉ lộ ra khi có ai đó chạy phép kiểm; im lặng ở đây nghĩa là im lặng đúng chỗ
    /// người dùng sắp đưa mỏ hàn vào.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soXungDot = 0; soChan = 0; soNet = 0
        _xungTheoChan = [:]

        let xung = (ketQua["conflicts"] as? [[String: Any]]) ?? []
        let bang = (ketQua["table"] as? [[String: Any]]) ?? []
        let canhBao = (ketQua["warnings"] as? [String]) ?? []
        let hcId = (ketQua["board_passport_id"] as? String) ?? ""
        soNet = EideSo.nguyen(ketQua["nets"]) ?? 0
        // `conflicts` có mặt (kể cả rỗng) nghĩa là phép kiểm ĐÃ chạy. Vắng mặt thì chưa.
        daKiemChan = ketQua["conflicts"] != nil

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có hộ chiếu mạch — `/board.build_passport` từ netlist KiCad.")
            return
        }

        soXungDot = xung.count
        soChan = bang.count

        var d: [String] = []
        if !hcId.isEmpty { d.append(hcId) }
        if soNet > 0 { d.append("\(soNet) net") }
        if soChan > 0 { d.append("\(soChan) chân") }
        if daKiemChan {
            d.append(soXungDot == 0 ? "0 xung đột chân" : "\(soXungDot) XUNG ĐỘT CHÂN")
        } else if soChan > 0 {
            d.append("CHƯA KIỂM CHÂN")
        }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (soXungDot > 0 || (!daKiemChan && soChan > 0))
            ? EideToken.Mau.warn : EideToken.Mau.muted

        if soChan > 0 && !daKiemChan {
            let v = noiRong("Bảng chân này chưa qua `board.check_pins` — xung đột chân/AF, "
                          + "chân reserved và trùng địa chỉ bus đều chưa được xét.")
            v.textColor = EideToken.Mau.warn
        }

        for c in xung.sorted(by: { EideMuc.diem(($0["severity"] as? String) ?? "")
                                 < EideMuc.diem(($1["severity"] as? String) ?? "") }) {
            let chan = (c["pin"] as? String) ?? "?"
            let loai = (c["kind"] as? String) ?? ""
            let chiTiet = (c["detail"] as? String) ?? ""
            let muc = (c["severity"] as? String) ?? "error"
            _xungTheoChan[chan] = c
            themDong(chan, "\(EideMuc.ten(muc)) · \(loai) — \(chiTiet)", mau: EideMuc.mau(muc),
                     nut: true, ma: chan, bam: #selector(xemChan(_:)))
        }

        for w in canhBao { themDong("cảnh báo", w, mau: EideToken.Mau.warn) }

        for r in bang {
            let net = (r["net"] as? String) ?? "?"
            let chan = (r["pin"] as? String) ?? (r["mcu_pin"] as? String) ?? ""
            let af = (r["function"] as? String) ?? (r["af"] as? String) ?? ""
            let lk = (r["component"] as? String) ?? ""
            let rb = (r["constraint"] as? String) ?? ""
            let phan = [chan, af, lk, rb].filter { !$0.isEmpty }.joined(separator: " · ")
            themDong(net, phan, nut: !chan.isEmpty, ma: chan, bam: #selector(xemChan(_:)))
        }

        _hienRangBuoc(ketQua)

        if soDong == 0 { noiRong("Hộ chiếu mạch rỗng — netlist chưa có net nào dùng được.") }
    }

    /// `board.constraints` `{constraints}`, `board.mark_lab` `{lab}`,
    /// `board.propose_fix` `{options[]{change, cost, touches_code}}`.
    private func _hienRangBuoc(_ ketQua: [String: Any]) {
        if let rb = ketQua["constraints"] as? [String: Any] {
            // K6 của BOARD-03 đi thẳng vào Coder: mọi lần sinh mã sau này đều chịu ràng buộc
            // này. Chân reserved là chỗ đắt nhất — dùng nhầm một chân SWD là mất luôn đường
            // nạp, và lỗi ấy chỉ lộ ra sau khi đã nạp.
            if let chan = rb["reserved_pins"] as? [Any], !chan.isEmpty {
                themDong("chân KHÔNG được dùng",
                         chan.map { EideKnowledgeFormat.giaTri($0) }.joined(separator: ", "),
                         mau: EideToken.Mau.warn)
            }
            for (k, v) in rb.sorted(by: { $0.key < $1.key }) where k != "reserved_pins" {
                themDong(k, EideKnowledgeFormat.giaTri(v))
            }
        }
        if let lab = ketQua["lab"] as? Bool {
            themDong("đánh dấu lab", lab ? "BẬT — board này tự nạp firmware được"
                                         : "tắt — nạp firmware vẫn cần người duyệt",
                     mau: lab ? EideToken.Mau.warn : EideToken.Mau.muted)
        }
        for o in (ketQua["options"] as? [[String: Any]]) ?? [] {
            // BOARD-04 nói rõ `touches_code`: một cách sửa đụng vào mã thì rẻ hơn hàn lại, và
            // đó là thông tin quyết định người chọn cách nào.
            let doi = (o["change"] as? String) ?? "?"
            let gia = EideKnowledgeFormat.giaTri(o["cost"])
            let cham = (o["touches_code"] as? Bool) ?? false
            themDong("cách sửa", "\(doi) · giá \(gia)"
                        + (cham ? " · ĐỤNG MÃ (rẻ hơn hàn lại)" : " · chỉ phần cứng"),
                     mau: cham ? EideToken.Mau.info : EideToken.Mau.warn)
        }
    }

    /// Chân → object xung đột của chính nó. Dòng bảng chân không có xung đột thì không gọi
    /// `propose_fix`: đề xuất sửa cho một chân không hỏng là một đề xuất vô nghĩa.
    private var _xungTheoChan: [String: [String: Any]] = [:]

    @objc private func xemChan(_ s: NSButton) {
        guard let c = s.identifier?.rawValue, let x = _xungTheoChan[c] else { return }
        onXemChan?(x)
    }
}

// MARK: - Màn 8: Yêu cầu & kiến trúc

/// `req.classify` `{reqset[], codes_assigned}`, `req.detect_conflict` `{issues[]}`,
/// `arch.review` `{findings[]}`, `arch.memory_budget`/`arch.timing_budget` `{budget}`,
/// `arch.decompose` `{module_graph{modules[], edges[]}}`, `req.trace_matrix` `{file, gaps[]}`.
public final class ReqArchView: ManHinhCoSo {

    public var onMoYeuCau: ((String) -> Void)?

    public private(set) var soYeuCau = 0
    public private(set) var soVanDe = 0
    /// Số yêu cầu KHÔNG đo được — xem `capNhat`.
    public private(set) var soKhongDoDuoc = 0
    /// `false` khi `arch.timing_budget` nói lịch không xếp được, hoặc RAM/Flash vượt hạn.
    public private(set) var nganSachDat = true

    public init() { super.init(ten: "Yêu cầu & kiến trúc") }

    /// **Yêu cầu không đo được hiện như một vấn đề, không hiện như một yêu cầu.**
    ///
    /// REQ-04 tách ba loại: `conflict`, `ambiguous`, `unmeasurable`. Loại thứ ba là loại đắt
    /// nhất và dễ bỏ qua nhất — "phản ứng nhanh" đọc lên nghe như một yêu cầu hoàn chỉnh, và
    /// nó sẽ đi thẳng qua kiến trúc, qua mã, tới tận lúc nghiệm thu mới có người hỏi "nhanh là
    /// bao nhiêu?". Màn này đặt câu đề xuất định lượng ngay cạnh nó.
    ///
    /// **`schedulable=false` và `ok=false` lên tiêu đề.** Một ngân sách thời gian thực không
    /// xếp được lịch nghĩa là kiến trúc này không chạy nổi trên con chip này — kết luận lớn
    /// nhất mà `arch.*` đưa ra được, và nó nằm trong một trường boolean dễ trôi qua mắt.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soYeuCau = 0; soVanDe = 0; soKhongDoDuoc = 0; nganSachDat = true

        let rs = (ketQua["reqset"] as? [[String: Any]]) ?? []
        let vd = (ketQua["issues"] as? [[String: Any]]) ?? []
        let ra = (ketQua["findings"] as? [[String: Any]]) ?? []
        let ns = ketQua["budget"] as? [String: Any]
        let do_ = ketQua["module_graph"] as? [String: Any]
        let lo = (ketQua["gaps"] as? [[String: Any]]) ?? []

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có yêu cầu nào — `/req.elicit` để bắt đầu từ ý tưởng.")
            return
        }

        soYeuCau = rs.count
        soVanDe = vd.count + ra.count
        soKhongDoDuoc = vd.filter { ($0["kind"] as? String) == "unmeasurable" }.count

        var d: [String] = []
        if soYeuCau > 0 { d.append("\(soYeuCau) yêu cầu") }
        if let mg = do_ {
            let m = (mg["modules"] as? [[String: Any]])?.count ?? 0
            let e = (mg["edges"] as? [[String: Any]])?.count ?? 0
            d.append("\(m) module · \(e) liên kết")
        }
        if let b = ns {
            // Hai năng lực ngân sách, hai cờ khác tên, cùng một ý: kiến trúc này có vừa không.
            let xep = b["schedulable"] as? Bool
            let dat = b["ok"] as? Bool
            if xep == false || dat == false { nganSachDat = false }
            if let u = b["utilization"] as? Double {
                d.append(String(format: "tải CPU %.0f%%", u * (u <= 1 ? 100 : 1)))
            }
            if xep == false { d.append("KHÔNG XẾP ĐƯỢC LỊCH") }
            if dat == false { d.append("VƯỢT NGÂN SÁCH") }
        }
        if soKhongDoDuoc > 0 { d.append("\(soKhongDoDuoc) CHƯA ĐO ĐƯỢC") }
        if !lo.isEmpty { d.append("\(lo.count) lỗ hổng truy vết") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (!nganSachDat || soKhongDoDuoc > 0)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        // Vấn đề trước yêu cầu: chúng là thứ chặn cả phần còn lại.
        for i in vd {
            let loai = (i["kind"] as? String) ?? "?"
            let ma = ((i["req_ids"] as? [String]) ?? []).joined(separator: ", ")
            let van = (i["text"] as? String) ?? ""
            let dx = (i["suggestion"] as? String) ?? ""
            themDong(ma.isEmpty ? _tenVanDe(loai) : "\(ma) — \(_tenVanDe(loai))",
                     van + (dx.isEmpty ? "" : "  ⟶ đề xuất: \(dx)"),
                     mau: loai == "conflict" ? EideToken.Mau.bad : EideToken.Mau.warn,
                     nut: !ma.isEmpty, ma: ma, bam: #selector(moYeuCau(_:)))
        }

        for f in ra.sorted(by: { EideMuc.diem(($0["severity"] as? String) ?? "")
                               < EideMuc.diem(($1["severity"] as? String) ?? "") }) {
            let muc = (f["severity"] as? String) ?? "info"
            let mo = (f["module"] as? String) ?? ""
            let qt = (f["rule"] as? String) ?? ""
            let tin = (f["message"] as? String) ?? ""
            themDong("\(mo) \(qt)".trimmingCharacters(in: .whitespaces),
                     "\(EideMuc.ten(muc)) — \(tin)", mau: EideMuc.mau(muc))
        }

        for r in rs {
            let ma = (r["id"] as? String) ?? (r["code"] as? String) ?? "?"
            let loai = (r["kind"] as? String) ?? (r["type"] as? String) ?? ""
            let van = (r["text"] as? String) ?? (r["statement"] as? String) ?? ""
            let uu = (r["priority"] as? String) ?? (r["moscow"] as? String) ?? ""
            // `grounded` nói yêu cầu này đã neo được vào một fact phần cứng có thật
            // (REQ-03 `ground_hw`). Không neo được thì nó là mong muốn, chưa là yêu cầu.
            let neo = (r["grounded"] as? String) ?? (r["fact_id"] as? String) ?? ""
            let phan = [loai, uu, van, neo.isEmpty ? "chưa neo phần cứng" : "neo \(neo)"]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            themDong(ma, phan, mau: neo.isEmpty ? EideToken.Mau.warn : EideToken.Mau.muted,
                     nut: true, ma: ma, bam: #selector(moYeuCau(_:)))
        }

        if let b = ns { _hienNganSach(b) }

        for g in lo {
            let tu = (g["from"] as? String) ?? (g["req_id"] as? String) ?? "?"
            let thieu = (g["missing"] as? String) ?? (g["kind"] as? String) ?? ""
            themDong(tu, "lỗ hổng truy vết — thiếu \(thieu)", mau: EideToken.Mau.warn)
        }

        _hienGiaoDienVaFsm(ketQua)
        _hienSoSanhPhuongAn(ketQua)

        if soDong == 0 { noiRong("Không có yêu cầu, module hay phát hiện nào để hiện.") }
    }

    /// `arch.interface_spec` `{interfaces}`, `arch.state_machine` `{fsm}`,
    /// `req.acceptance` `{acceptance[]}`, `req.change_impact` `{impact}`.
    /// `arch.compare` → `{comparison{matrix, scores, recommendation}}` — UC-B10.
    ///
    /// ## Vì sao bảng đánh đổi phải hiện ĐỦ, không chỉ hiện khuyến nghị
    ///
    /// `arch.compare` là **T1\*** — tác tử tự làm khi hàm quyết định có bằng chứng, không thì
    /// hỏi. Nghĩa là khuyến nghị của nó là một đề xuất, và người chọn. Hiện mỗi dòng
    /// "khuyến nghị: RTOS" thì người không có gì để không đồng ý: họ hoặc gật, hoặc phải đi hỏi
    /// lại từ đầu.
    ///
    /// Nên hiện cả **ma trận** (phương án × tiêu chí) và **điểm**, với phương án được khuyến
    /// nghị đánh dấu — nhưng không sắp nó lên đầu. Sắp theo điểm là để người đọc thấy khoảng
    /// cách giữa các phương án: hai phương án 8,5 và 8,4 là một lựa chọn khác hẳn 8,5 và 4,0.
    private func _hienSoSanhPhuongAn(_ ketQua: [String: Any]) {
        guard let ss = ketQua["comparison"] as? [String: Any] else { return }

        let diem = (ss["scores"] as? [String: Any]) ?? [:]
        let kn = (ss["recommendation"] as? String)
            ?? ((ss["recommendation"] as? [String: Any])?["option"] as? String)

        if let kn {
            themDong("khuyến nghị", kn + " — anh quyết, tác tử chỉ đề xuất (T1*)",
                     mau: EideToken.Mau.info)
        }
        // Ma trận: mỗi hàng một phương án, mỗi cột một tiêu chí.
        let mt = (ss["matrix"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
        for hang in mt {
            let ten = (hang["option"] as? String) ?? (hang["name"] as? String) ?? "?"
            let d = EideSo.thuc(diem[ten]) ?? EideSo.thuc(hang["score"])
            var ct = hang.filter { $0.key != "option" && $0.key != "name" && $0.key != "score" }
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: " · ")
            if let d { ct = String(format: "%.1f điểm · ", d) + ct }
            themDong((ten == kn ? "★ " : "  ") + ten, ct,
                     mau: ten == kn ? EideToken.Mau.ok : nil)
        }
        if mt.isEmpty && !diem.isEmpty {
            // Có điểm mà không có ma trận: vẫn hiện điểm, vì con số so sánh được là thứ tối
            // thiểu người cần để không đồng ý một cách có căn cứ.
            for (ten, d) in diem.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                themDong((ten == kn ? "★ " : "  ") + ten,
                         EideSo.thuc(d).map { String(format: "%.1f điểm", $0) } ?? "\(d)",
                         mau: ten == kn ? EideToken.Mau.ok : nil)
            }
        }
        if mt.isEmpty && diem.isEmpty && kn == nil {
            noiRong("`arch.compare` trả về một so sánh rỗng — không có phương án nào để cân.")
        }
    }

    private func _hienGiaoDienVaFsm(_ ketQua: [String: Any]) {
        if let gd = ketQua["interfaces"] as? [[String: Any]] {
            for i in gd {
                let mo = (i["module"] as? String) ?? "?"
                let ham = ((i["functions"] as? [Any]) ?? []).count
                let tin = ((i["messages"] as? [Any]) ?? []).count
                themDong(mo, "\(ham) hàm · \(tin) thông điệp")
            }
        }
        if let fsm = ketQua["fsm"] as? [String: Any] {
            let tt = ((fsm["states"] as? [Any]) ?? []).count
            let ch = ((fsm["transitions"] as? [Any]) ?? []).count
            let bb = (fsm["invariants"] as? [Any]) ?? []
            themDong("máy trạng thái",
                     "\(tt) trạng thái · \(ch) chuyển · bắt đầu "
                        + EideKnowledgeFormat.giaTri(fsm["initial"]))
            // ARCH-07 trả `invariants[]` — những điều PHẢI đúng ở mọi trạng thái. Một FSM
            // không có bất biến nào là một FSM chưa ai nghĩ về chỗ nó có thể hỏng.
            themDong(" · bất biến",
                     bb.isEmpty ? "KHÔNG có — chưa ai nêu điều gì phải luôn đúng"
                                : bb.map { EideKnowledgeFormat.giaTri($0) }
                                    .joined(separator: "; "),
                     mau: bb.isEmpty ? EideToken.Mau.warn : nil)
        }
        for a in (ketQua["acceptance"] as? [[String: Any]]) ?? [] {
            // REQ-07 đòi `observable kind` — cách MÁY kiểm được tiêu chí này. Thiếu nó thì
            // "nghiệm thu" quay về một người gật đầu, và đó đúng là thứ `sim.*`/`target.observe`
            // sinh ra để thay thế.
            let ma = (a["req_id"] as? String) ?? "?"
            let quan = (a["observable"] as? String) ?? (a["kind"] as? String) ?? ""
            let khi = [(a["given"] as? String), (a["when"] as? String), (a["then"] as? String)]
                .compactMap { $0 }.joined(separator: " → ")
            themDong(ma, khi + (quan.isEmpty ? " · KHÔNG nói máy kiểm bằng gì"
                                             : " · máy kiểm bằng \(quan)"),
                     mau: quan.isEmpty ? EideToken.Mau.warn : nil)
        }
        if let ah = ketQua["impact"] as? [String: Any] {
            // REQ-08: đổi một yêu cầu thì kéo theo gì. Danh sách rỗng ở đây KHÔNG có nghĩa là
            // an toàn — nó có thể nghĩa là truy vết chưa dựng xong.
            let phan = ["modules", "code_units", "tests", "docs", "diagrams", "features"]
                .compactMap { k -> String? in
                    guard let n = (ah[k] as? [Any])?.count, n > 0 else { return nil }
                    return "\(n) \(k)"
                }
            themDong("ảnh hưởng",
                     phan.isEmpty ? "không thấy gì bị ảnh hưởng — kiểm lại ma trận truy vết"
                                  : phan.joined(separator: " · "),
                     mau: phan.isEmpty ? EideToken.Mau.warn : EideToken.Mau.info)
        }
    }

    private func _hienNganSach(_ b: [String: Any]) {
        // Ngân sách RAM/Flash: `per module`. Ngân sách thời gian: `tasks[]`.
        if let tasks = b["tasks"] as? [[String: Any]] {
            for t in tasks {
                let ten = (t["name"] as? String) ?? (t["task"] as? String) ?? "?"
                let ck = EideSo.thuc(t["period"]).map { "chu kỳ \(Int($0)) µs" } ?? ""
                let w = EideSo.thuc(t["wcet_est"]).map { "WCET ~\(Int($0)) µs" } ?? ""
                let p = EideSo.nguyen(t["prio"]).map { "ưu tiên \($0)" } ?? ""
                themDong(ten, [ck, w, p].filter { !$0.isEmpty }.joined(separator: " · "))
            }
        }
        for (k, v) in b where !["tasks", "utilization", "schedulable", "ok", "limits"].contains(k) {
            guard let m = v as? [String: Any] else { continue }
            let ram = EideSo.nguyen(m["ram"]).map { "RAM \($0) B" } ?? ""
            let flash = EideSo.nguyen(m["flash"]).map { "Flash \($0) B" } ?? ""
            let stack = EideSo.nguyen(m["stack"]).map { "stack \($0) B" } ?? ""
            let phan = [ram, flash, stack].filter { !$0.isEmpty }.joined(separator: " · ")
            if !phan.isEmpty { themDong(k, phan) }
        }
    }

    private func _tenVanDe(_ k: String) -> String {
        switch k {
        case "conflict": return "MÂU THUẪN"
        case "ambiguous": return "mơ hồ"
        case "unmeasurable": return "chưa đo được"
        default: return k
        }
    }

    @objc private func moYeuCau(_ s: NSButton) {
        if let m = s.identifier?.rawValue, !m.isEmpty { onMoYeuCau?(m) }
    }
}
