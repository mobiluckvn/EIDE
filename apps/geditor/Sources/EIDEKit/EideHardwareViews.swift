import AppKit

/// Bốn màn "phần cứng & gỡ lỗi" — UXD-13 màn 14 (Discovery), 15 (LogAssist), 16 (Debug),
/// 18 (Bench).
///
/// Spec: CDS-12 DISCOVER-01..12, DEBUG-01..06, TARGET-01..09, BENCH-01..03, MEASURE-01..03;
/// UXD-13 §2, U2, U9; SEC-25 (thao tác phần cứng là R3/R4).
///
/// ## Ba trong bốn màn này gọi năng lực CHƯA HIỆN THỰC
///
/// `discover.*` 0/12, `bench.*` 0/3, `target.*` 0/9 — tất cả chờ một bo mạch (quyết định
/// 08/09/2026 của chủ sản phẩm). Bốn màn vẫn được dựng đủ theo hợp đồng, nhưng trạng thái rỗng
/// của chúng phải nói ra **lý do đúng**: "chưa có dữ liệu" và "năng lực chưa hiện thực" là hai
/// tình huống khác nhau, và người dùng làm hai việc khác nhau với chúng — một bên đi cắm board,
/// một bên biết là không cắm cũng vô ích.
///
/// Đây không phải chỗ giữ chỗ. Một màn đã dựng đúng hợp đồng là một màn ngày có board chỉ cần
/// nối dây; và quan trọng hơn, viết nó bây giờ là cách duy nhất phát hiện ra hợp đồng nào chưa
/// đủ để dựng giao diện — rẻ hơn nhiều so với phát hiện lúc board đã nằm trên bàn.

// MARK: - Màn 14: Dò board

/// `discover.ports` `{ports[]{dev, vid, pid, product, serial, kind, driver_ok}}`,
/// `discover.probe` `{probes[]{kind, serial, fw, tool}}`,
/// `discover.chip_id` `{identity{method, raw, passport_match, confidence}}`,
/// `discover.board_match` `{candidates[]{board_id, score, reasons[]}}`,
/// `discover.bus_scan` `{devices[]{addr|id, matched_part}}`,
/// `discover.power` `{power{vdd, idd, ok, warnings[]}}`.
public final class DiscoveryView: ManHinhCoSo {

    public var onChonBoard: ((String) -> Void)?

    public private(set) var soCong = 0
    public private(set) var soProbe = 0
    public private(set) var soThietBiBus = 0
    /// Số cổng có driver KHÔNG ổn — xem `capNhat`.
    public private(set) var soDriverHong = 0
    /// Độ tin cậy nhận diện chip, `nil` nếu chưa đọc được ID.
    public private(set) var tinChip: Double?

    public init() { super.init(ten: "Dò board") }

    /// **`driver_ok: false` là câu trả lời cho câu hỏi người dùng sắp hỏi.**
    ///
    /// Một board cắm vào mà không hiện ra thì câu hỏi đầu tiên luôn là "máy có thấy nó không?".
    /// `discover.ports` phân biệt được ba tình huống — không có cổng nào, có cổng nhưng driver
    /// chưa nạp, có cổng và driver tốt — và cả ba dẫn tới ba việc khác hẳn nhau. Gộp chúng
    /// thành "không tìm thấy board" là để người dùng đi rút ra cắm lại một sợi cáp vẫn tốt.
    ///
    /// **`confidence` của `chip_id` không được giấu.** DISCOVER-03 đọc IDCODE rồi so với hộ
    /// chiếu; một `passport_match` với độ tin cậy 0,4 là một phỏng đoán, và nạp firmware theo
    /// một phỏng đoán về con chip là cách làm hỏng chip.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soCong = 0; soProbe = 0; soThietBiBus = 0; soDriverHong = 0; tinChip = nil

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Nhóm `discover.*` chưa hiện thực — 12 năng lực đều cần một bo mạch thật "
                  + "(quyết định 08/09/2026). Màn này đã dựng theo hợp đồng và sẽ chạy ngay khi "
                  + "có board; chưa có board thì cắm cáp cũng không hiện gì.")
            return
        }

        let cong = (ketQua["ports"] as? [[String: Any]]) ?? []
        let probe = (ketQua["probes"] as? [[String: Any]]) ?? []
        let dinhDanh = ketQua["identity"] as? [String: Any]
        let ungVien = (ketQua["candidates"] as? [[String: Any]]) ?? []
        let thietBi = (ketQua["devices"] as? [[String: Any]]) ?? []
        let nguon = ketQua["power"] as? [String: Any]
        let dongHo = ketQua["clocks"] as? [String: Any]
        let cauHinh = (ketQua["path"] as? String) ?? ""

        soCong = cong.count
        soProbe = probe.count
        soThietBiBus = thietBi.count
        soDriverHong = cong.filter { ($0["driver_ok"] as? Bool) == false }.count
        tinChip = dinhDanh?["confidence"] as? Double

        var d: [String] = []
        if soCong > 0 { d.append("\(soCong) cổng") }
        if soDriverHong > 0 { d.append("\(soDriverHong) THIẾU DRIVER") }
        if soProbe > 0 { d.append("\(soProbe) probe") }
        if soThietBiBus > 0 { d.append("\(soThietBiBus) thiết bị trên bus") }
        if let t = tinChip { d.append(String(format: "nhận diện chip %.0f%%", t * 100)) }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (soDriverHong > 0 || (tinChip ?? 1) < 0.6)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        if let i = dinhDanh { _hienChip(i) }

        for p in probe {
            let loai = (p["kind"] as? String) ?? "?"
            let sn = (p["serial"] as? String).map { "SN \($0)" } ?? ""
            let fw = (p["fw"] as? String).map { "fw \($0)" } ?? ""
            let cc = (p["tool"] as? String).map { "qua \($0)" } ?? ""
            themDong(loai, [sn, fw, cc].filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: EideToken.Mau.ok)
        }

        for c in cong {
            let dev = (c["dev"] as? String) ?? "?"
            let sp = (c["product"] as? String) ?? ""
            let vidpid = [c["vid"], c["pid"]].compactMap { $0 }
                .map { EideKnowledgeFormat.giaTri($0) }.joined(separator: ":")
            let ok = (c["driver_ok"] as? Bool) ?? true
            themDong(dev,
                     [sp, vidpid, ok ? "" : "DRIVER CHƯA NẠP — cài driver rồi cắm lại"]
                        .filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: ok ? nil : EideToken.Mau.bad)
        }

        for u in ungVien.sorted(by: { (($0["score"] as? Double) ?? 0) > (($1["score"] as? Double) ?? 0) }) {
            let bid = (u["board_id"] as? String) ?? "?"
            let diem = EideSo.thuc(u["score"]) ?? 0
            let ly = ((u["reasons"] as? [String]) ?? []).joined(separator: ", ")
            themDong(bid, String(format: "khớp %.0f%%", diem * (diem <= 1 ? 100 : 1))
                        + (ly.isEmpty ? "" : " — \(ly)"),
                     mau: diem >= 0.8 ? EideToken.Mau.ok : EideToken.Mau.warn,
                     nut: true, ma: bid, bam: #selector(chonBoard(_:)))
        }

        for t in thietBi {
            let dc = EideKnowledgeFormat.giaTri(t["addr"] ?? t["id"])
            let khop = (t["matched_part"] as? String) ?? "chưa khớp linh kiện nào"
            themDong(dc, khop, mau: t["matched_part"] == nil ? EideToken.Mau.warn : nil)
        }

        if let n = nguon { _hienNguon(n) }
        if let k = dongHo { _hienDongHo(k) }
        if !cauHinh.isEmpty { themDong("cấu hình sinh ra", cauHinh, mau: EideToken.Mau.info) }

        if let fw = ketQua["firmware"] as? [String: Any] { _hienFirmware(fw) }
        if let ch = EideSo.nguyen(ketQua["chosen"]) { _hienTocDo(ch, ketQua) }

        if soDong == 0 {
            noiRong("Không thấy cổng, probe hay thiết bị nào. Kiểm cáp, nguồn, và chế độ boot.")
        }
    }

    private func _hienChip(_ i: [String: Any]) {
        let cach = (i["method"] as? String) ?? "?"
        let tho = EideKnowledgeFormat.giaTri(i["raw"])
        let khop = (i["passport_match"] as? String) ?? ""
        let tin = EideSo.thuc(i["confidence"]) ?? 0
        let yeu = tin < 0.6
        themDong("chip đọc được",
                 "\(tho) qua \(cach)"
                    + (khop.isEmpty ? " — KHÔNG khớp hộ chiếu nào" : " → \(khop)")
                    + String(format: " · tin cậy %.0f%%", tin * 100),
                 mau: yeu || khop.isEmpty ? EideToken.Mau.bad : EideToken.Mau.ok)
        if yeu && !khop.isEmpty {
            let v = noiRong("Khớp hộ chiếu ở mức phỏng đoán. Đừng nạp firmware theo nó — "
                          + "chạy `discover.bus_scan` để có thêm bằng chứng trước.")
            v.textColor = EideToken.Mau.bad
        }
    }

    private func _hienNguon(_ n: [String: Any]) {
        let vdd = EideKnowledgeFormat.giaTri(n["vdd"])
        let idd = EideKnowledgeFormat.giaTri(n["idd"])
        let ok = (n["ok"] as? Bool) ?? true
        themDong("nguồn", "VDD \(vdd) V · IDD \(idd) mA", mau: ok ? nil : EideToken.Mau.bad)
        for w in (n["warnings"] as? [String]) ?? [] {
            themDong(" · cảnh báo", w, mau: EideToken.Mau.warn)
        }
    }

    private func _hienDongHo(_ k: [String: Any]) {
        // DISCOVER-07 so tần số ĐO ĐƯỢC với tần số ĐÃ CẤU HÌNH. Lệch nhau là nguyên nhân kinh
        // điển của UART ra ký tự rác — và nó không làm chương trình crash, nên không ai nghi.
        for (ten, v) in k.sorted(by: { $0.key < $1.key }) {
            guard let m = v as? [String: Any] else {
                themDong(ten, EideKnowledgeFormat.giaTri(v)); continue
            }
            let do_ = EideSo.thuc(m["measured"]) ?? 0
            let cau = EideSo.thuc(m["configured"]) ?? 0
            let lech = cau > 0 ? abs(do_ - cau) / cau : 0
            themDong(ten,
                     "đo \(EideKnowledgeFormat.giaTri(do_)) · cấu hình \(EideKnowledgeFormat.giaTri(cau))"
                        + (lech > 0.02 ? String(format: " · LỆCH %.1f%%", lech * 100) : ""),
                     mau: lech > 0.02 ? EideToken.Mau.bad : nil)
        }
    }

    /// `discover.firmware_probe` `{firmware{banner, version, bootloader, known_good_match}}`.
    ///
    /// **`known_good_match` là câu trả lời cho "board này còn nguyên không".** Firmware đang
    /// chạy khớp một bản đã biết tốt nghĩa là có chỗ lui — TARGET-02 `reflash_known_good` dựa
    /// vào đúng điều đó. Không khớp thì mọi thao tác nạp sau này là một chiều.
    private func _hienFirmware(_ fw: [String: Any]) {
        let ban = (fw["banner"] as? String) ?? ""
        let ver = (fw["version"] as? String) ?? ""
        let boot = (fw["bootloader"] as? String) ?? ""
        let khop = (fw["known_good_match"] as? String) ?? ""
        themDong("firmware đang chạy",
                 [ban, ver, boot.isEmpty ? "" : "bootloader \(boot)"]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
        themDong(" · bản đã biết tốt",
                 khop.isEmpty ? "KHÔNG khớp bản nào — nạp firmware sẽ không có chỗ lui"
                              : khop,
                 mau: khop.isEmpty ? EideToken.Mau.warn : EideToken.Mau.ok)
    }

    /// `discover.link_speed` `{chosen, tried[], limit}`.
    private func _hienTocDo(_ chon: Int, _ ketQua: [String: Any]) {
        let thu = (ketQua["tried"] as? [Any]) ?? []
        let tran = EideSo.nguyen(ketQua["limit"])
        themDong("tốc độ liên kết",
                 "\(chon)" + (tran.map { " · trần \($0)" } ?? "")
                    + (thu.isEmpty ? "" : " · đã thử \(thu.count) mức"),
                 mau: tran != nil && chon < tran! ? EideToken.Mau.warn : EideToken.Mau.ok)
    }

    @objc private func chonBoard(_ s: NSButton) {
        if let b = s.identifier?.rawValue, !b.isEmpty { onChonBoard?(b) }
    }
}

// MARK: - Màn 15: Log & serial

/// `debug.log_stats` `{stats{file, lines, range, top_patterns[], levels{}, time_span, gaps[]}}`,
/// `debug.ask_at` `{diagnosis, session_id}`, `target.serial` `{lines[], matched}`.
public final class LogAssistView: ManHinhCoSo {

    public var onMoDong: ((Int) -> Void)?

    public private(set) var soDongLog = 0
    public private(set) var soKhoangLang = 0
    public private(set) var soLoi = 0

    public init() { super.init(ten: "Log & serial") }

    /// **Khoảng lặng là một phát hiện, không phải một phép thống kê.**
    ///
    /// `debug.log_stats` tìm những khoảng im lặng dài bất thường (trung vị × 5). Một log
    /// gigabyte cuộn qua mắt người thì đều như nhau; chỗ hệ thống *ngừng nói* mới là chỗ nó
    /// treo, và đó chính là chỗ không có dòng nào để đọc. Mỗi khoảng lặng kèm số dòng hai đầu
    /// để mở đúng chỗ trong GEditor — một con số giây không có số dòng thì vô dụng trên một
    /// tệp 40 triệu dòng.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soDongLog = 0; soKhoangLang = 0; soLoi = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa đọc log nào — `/debug.log_stats <tệp>`. "
                  + "(`target.serial` cần board, chưa hiện thực.)")
            return
        }

        let tk = (ketQua["stats"] as? [String: Any]) ?? [:]
        let chanDoan = ketQua["diagnosis"] as? [String: Any]
        let dongSerial = (ketQua["lines"] as? [[String: Any]]) ?? []
        let khop = ketQua["matched"] as? Bool

        soDongLog = EideSo.nguyen(tk["lines"]) ?? dongSerial.count
        let lang = (tk["gaps"] as? [[String: Any]]) ?? []
        soKhoangLang = lang.count
        let muc = (tk["levels"] as? [String: Any]) ?? [:]
        soLoi = EideSo.nguyen(muc["ERROR"]) ?? EideSo.nguyen(muc["error"]) ?? 0
        let mau = (tk["top_patterns"] as? [[String: Any]]) ?? []
        let khoang = tk["time_span"] as? [String: Any]

        var d: [String] = []
        if soDongLog > 0 { d.append("\(soDongLog) dòng") }
        if let k = khoang, let gy = k["duration_s"] as? Double {
            d.append(String(format: "trải %.1f s", gy))
        }
        if soLoi > 0 { d.append("\(soLoi) ERROR") }
        if soKhoangLang > 0 { d.append("\(soKhoangLang) KHOẢNG LẶNG") }
        if let m = khop { d.append(m ? "expect khớp" : "expect KHÔNG khớp") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (soLoi > 0 || soKhoangLang > 0) ? EideToken.Mau.warn : EideToken.Mau.muted

        // Khoảng lặng lên đầu: đó là thứ duy nhất ở đây người không tự thấy khi cuộn log.
        for g in lang {
            let sau = EideSo.nguyen(g["after_line"]) ?? 0
            let truoc = EideSo.nguyen(g["before_line"]) ?? 0
            let giay = EideSo.thuc(g["gap_s"]) ?? 0
            themDong(String(format: "lặng %.3f s", giay),
                     "giữa dòng \(sau) và \(truoc) — hệ thống ngừng nói ở đây",
                     mau: EideToken.Mau.warn,
                     nut: sau > 0, ma: String(sau), bam: #selector(moDong(_:)))
        }

        if !muc.isEmpty {
            let mo = muc.sorted { $0.key < $1.key }
                .map { "\($0.key) \(EideKnowledgeFormat.giaTri($0.value))" }
            themDong("theo mức", mo.joined(separator: " · "),
                     mau: soLoi > 0 ? EideToken.Mau.warn : nil)
        }

        for m in mau {
            let p = (m["pattern"] as? String) ?? "?"
            let n = EideSo.nguyen(m["count"]) ?? 0
            themDong("×\(n)", p)
        }

        if let c = chanDoan { _hienChanDoan(c, ketQua["session_id"] as? String) }

        for l in dongSerial.prefix(30) {
            let t = (l["text"] as? String) ?? EideKnowledgeFormat.giaTri(l)
            let moc = EideSo.thuc(l["t"]).map { String(format: "%.3f", $0) } ?? ""
            themDong(moc, t)
        }
        if dongSerial.count > 30 { noiRong("… và \(dongSerial.count - 30) dòng nữa.") }

        if soDong == 0 { noiRong("Log đọc được nhưng không có mẫu, mức hay khoảng lặng nào.") }
    }

    private func _hienChanDoan(_ c: [String: Any], _ phien: String?) {
        // DEBUG-02 trả chẩn đoán CÓ TRÍCH DẪN (vùng log + hộ chiếu + mã). Một chẩn đoán không
        // dẫn nguồn ở đây cũng đúng vấn đề của `RagAskView`: nghe rất hợp lý và không kiểm được.
        let tom = (c["summary"] as? String) ?? (c["text"] as? String) ?? ""
        let trich = ((c["citations"] as? [Any]) ?? []).count
        themDong("chẩn đoán", tom.isEmpty ? "(rỗng)" : tom,
                 mau: trich > 0 ? EideToken.Mau.text : EideToken.Mau.warn)
        themDong(" · nguồn", trich > 0 ? "\(trich) trích dẫn"
                                       : "KHÔNG trích dẫn — coi đây là phỏng đoán",
                 mau: trich > 0 ? EideToken.Mau.muted : EideToken.Mau.bad)
        if let p = phien, !p.isEmpty {
            themDong(" · phiên gỡ lỗi", p, mau: EideToken.Mau.info)
        }
    }

    @objc private func moDong(_ s: NSButton) {
        if let n = Int(s.identifier?.rawValue ?? ""), n > 0 { onMoDong?(n) }
    }
}

// MARK: - Màn 16: Gỡ lỗi probe

/// `debug.hypothesize` `{diagnosis}`, `debug.experiment` `{evidence}`,
/// `debug.propose_fix` `{proposal{kind, step_text, k6_change?}}`,
/// `target.probe_read`/`target.diagnose_fault` `{evidence}`,
/// `target.observe` `{evidence[], all_passed, machine_observable}`.
public final class DebugView: ManHinhCoSo {

    /// `(experiment, target)` — DEBUG-04 đòi cả hai, và `experiment` là một OBJECT
    /// `{cap, args, expect}` do `debug.hypothesize` sinh ra. Trả về một chuỗi mô tả rồi để
    /// panel dựng lại object là dựng một thí nghiệm khác với thí nghiệm đã được đề xuất.
    public var onChayThiNghiem: (([String: Any], String) -> Void)?

    public private(set) var soGiaThuyet = 0
    public private(set) var soBangChung = 0
    /// `target.observe` — kỳ vọng có quan sát được bằng MÁY không. Xem `capNhat`.
    public private(set) var mayQuanSatDuoc: Bool?

    public init() { super.init(ten: "Gỡ lỗi probe") }

    /// **`machine_observable: false` là lý do KHÔNG kết luận, không phải một cảnh báo nhỏ.**
    ///
    /// TARGET-09 tách rõ: `all_passed` nói kỳ vọng có đạt không, `machine_observable` nói máy
    /// có tự kiểm được không. Một kỳ vọng kiểu "đèn LED nhấp nháy đúng nhịp" mà không có kênh
    /// quan sát thì `all_passed` chẳng nói gì cả — cùng một hình dạng với `unverified` của
    /// `sim.*`, và cùng một lý do để không gộp.
    ///
    /// **Giả thuyết xếp hạng phải hiện kèm THÍ NGHIỆM PHÂN BIỆT.** DEBUG-03 sinh ra chúng theo
    /// cặp; một danh sách giả thuyết không kèm cách phân biệt là một danh sách để người đọc
    /// chọn cái nghe thuận tai nhất.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soGiaThuyet = 0; soBangChung = 0; mayQuanSatDuoc = nil
        _thiNghiemTheoGt = [:]; _dichTheoGt = [:]

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Chưa có phiên gỡ lỗi nào. `debug.hypothesize` và `debug.propose_fix` chạy "
                  + "được không cần board; `target.probe_*` thì cần — 9 năng lực `target.*` "
                  + "chưa hiện thực.")
            return
        }

        let cd = ketQua["diagnosis"] as? [String: Any]
        let bc = ketQua["evidence"]
        let dx = ketQua["proposal"] as? [String: Any]
        let deu = ketQua["all_passed"] as? Bool
        mayQuanSatDuoc = ketQua["machine_observable"] as? Bool

        let gt = (cd?["hypotheses"] as? [[String: Any]]) ?? []
        soGiaThuyet = gt.count
        if let m = bc as? [[String: Any]] { soBangChung = m.count }
        else if bc is [String: Any] { soBangChung = 1 }

        var d: [String] = []
        if soGiaThuyet > 0 { d.append("\(soGiaThuyet) giả thuyết") }
        if soBangChung > 0 { d.append("\(soBangChung) bằng chứng") }
        if let a = deu { d.append(a ? "kỳ vọng đạt" : "kỳ vọng KHÔNG đạt") }
        if mayQuanSatDuoc == false { d.append("MÁY KHÔNG TỰ KIỂM ĐƯỢC") }
        tomTat.stringValue = d.joined(separator: " · ")
        tomTat.textColor = (mayQuanSatDuoc == false || deu == false)
            ? EideToken.Mau.warn : EideToken.Mau.muted

        if mayQuanSatDuoc == false {
            let v = noiRong("Kỳ vọng này máy không tự kiểm được, nên kết quả \"đạt\" ở trên "
                          + "không phải bằng chứng. Cần người xác nhận, hoặc thêm kênh quan sát "
                          + "(probe, logic analyzer, serial expect).")
            v.textColor = EideToken.Mau.warn
        }

        for (i, g) in gt.enumerated() {
            let ten = (g["text"] as? String) ?? (g["hypothesis"] as? String) ?? "?"
            let diem = EideSo.thuc(g["score"]).map { String(format: " · %.0f%%", $0 * 100) } ?? ""
            // Thí nghiệm phân biệt đi CÙNG giả thuyết, không xuống cuối màn.
            let tn = (g["experiment"] as? [String: Any])
                ?? (g["discriminator"] as? [String: Any])
            let moTa = (tn?["cap"] as? String)
                ?? (g["experiment"] as? String) ?? (g["discriminator"] as? String) ?? ""
            let ma = "gt\(i)"
            if let x = tn { _thiNghiemTheoGt[ma] = x }
            _dichTheoGt[ma] = (g["target"] as? String) ?? (cd?["target"] as? String) ?? ""
            themDong("\(i + 1). \(ten)",
                     diem + (moTa.isEmpty ? " · KHÔNG có thí nghiệm phân biệt"
                                          : " · thử: \(moTa)"),
                     mau: tn == nil ? EideToken.Mau.warn : nil,
                     nut: tn != nil, ma: ma, bam: #selector(chayThiNghiem(_:)))
        }

        if let m = bc as? [[String: Any]] { for e in m { _hienBangChung(e) } }
        else if let m = bc as? [String: Any] { _hienBangChung(m) }

        if let p = dx { _hienDeXuat(p) }

        if let pid = ketQua["id"] as? String {
            // DEBUG-05 lưu phiên để mở lại sau — một phiên gỡ lỗi kéo dài nhiều ngày, và mã
            // phiên là thứ duy nhất nối các lần lại với nhau.
            themDong("phiên đã lưu", pid, mau: EideToken.Mau.info)
        }
        if let ok = ketQua["ok"] as? Bool {
            // TARGET-06 GHI vào thanh ghi/RAM — `ok: false` ở đây không phải "chưa xong", nó
            // là "đã thử và phần cứng từ chối".
            themDong("ghi qua probe", ok ? "thành công" : "PHẦN CỨNG TỪ CHỐI",
                     mau: ok ? EideToken.Mau.ok : EideToken.Mau.bad)
        }

        if soDong == 0 { noiRong("Phiên gỡ lỗi chưa có giả thuyết hay bằng chứng nào.") }
    }

    private func _hienBangChung(_ e: [String: Any]) {
        let loai = (e["kind"] as? String) ?? (e["tool"] as? String) ?? "bằng chứng"
        let tom = (e["summary"] as? String) ?? EideKnowledgeFormat.giaTri(e["value"])
        // EvidencePack có `log_ref`/`at`: một bằng chứng không truy lại được thì không phải
        // bằng chứng, chỉ là một câu khẳng định thêm.
        let vet = (e["log_ref"] as? String) ?? (e["ref"] as? String) ?? ""
        themDong(loai, tom + (vet.isEmpty ? " — KHÔNG có vết log" : " · \(vet)"),
                 mau: vet.isEmpty ? EideToken.Mau.warn : nil)
        if let u = e["unwind"] as? [Any] {
            for f in u.prefix(8) { themDong("  ", EideKnowledgeFormat.giaTri(f)) }
        }
    }

    private func _hienDeXuat(_ p: [String: Any]) {
        let loai = (p["kind"] as? String) ?? "?"
        let van = (p["step_text"] as? String) ?? ""
        themDong("đề xuất sửa (\(_tenLoai(loai)))", van, mau: EideToken.Mau.info)
        if let k6 = p["k6_change"] {
            // Đổi K6 là đổi RÀNG BUỘC, không phải đổi mã — nó ảnh hưởng mọi lần sinh mã sau
            // này, nên phải đọc khác một đề xuất sửa một dòng.
            themDong(" · đổi ràng buộc K6", EideKnowledgeFormat.giaTri(k6),
                     mau: EideToken.Mau.warn)
        }
    }

    private func _tenLoai(_ k: String) -> String {
        switch k {
        case "code": return "mã"
        case "constraint": return "ràng buộc"
        case "hardware": return "phần cứng"
        default: return k
        }
    }

    private var _thiNghiemTheoGt: [String: [String: Any]] = [:]
    private var _dichTheoGt: [String: String] = [:]

    @objc private func chayThiNghiem(_ s: NSButton) {
        guard let k = s.identifier?.rawValue, let x = _thiNghiemTheoGt[k] else { return }
        onChayThiNghiem?(x, _dichTheoGt[k] ?? "")
    }
}

// MARK: - Màn 18: Benchmark

/// `bench.run` `{report}` (per task/model CF/BF/BC, tokens, rounds),
/// `bench.badge` `{badges[]}`.
public final class BenchView: ManHinhCoSo {

    public private(set) var soTacVu = 0
    public private(set) var soHuyHieu = 0

    public init() { super.init(ten: "Benchmark") }

    /// **Huy hiệu `verified` gắn cho một gói phải nói rõ nó dựa trên cái gì.**
    ///
    /// BENCH-02 gắn huy hiệu, và huy hiệu ấy đi theo gói vào registry — nơi người khác thấy nó
    /// mà không thấy lần chạy sinh ra nó. Nên ở đây, chỗ duy nhất hai thứ còn đứng cạnh nhau,
    /// huy hiệu phải hiện kèm điểm và ngày. Một nhãn "verified" trần là một nhãn tự chứng thực.
    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        soTacVu = 0; soHuyHieu = 0

        if ketQua.isEmpty {
            tomTat.stringValue = ""
            noiRong("Nhóm `bench.*` chưa hiện thực — 3 năng lực đều cần board thật để đo "
                  + "CF/BF/BC (quyết định 08/09/2026).")
            return
        }

        let bc = ketQua["report"] as? [String: Any]
        let hh = (ketQua["badges"] as? [[String: Any]]) ?? []
        soHuyHieu = hh.count

        let tv = (bc?["tasks"] as? [[String: Any]]) ?? []
        soTacVu = tv.count

        var d: [String] = []
        if soTacVu > 0 { d.append("\(soTacVu) tác vụ") }
        if let tk = bc?["tokens"] { d.append("\(EideKnowledgeFormat.giaTri(tk)) token") }
        if soHuyHieu > 0 { d.append("\(soHuyHieu) huy hiệu") }
        tomTat.stringValue = d.joined(separator: " · ")

        for t in tv {
            let ten = (t["task"] as? String) ?? (t["name"] as? String) ?? "?"
            let mh = (t["model"] as? String) ?? ""
            // CF/BF/BC — ba chỉ số của BEN-24. Hiện cả ba hay không hiện gì: một chỉ số lẻ
            // không so sánh được với gì.
            let bo = ["CF", "BF", "BC"].compactMap { k -> String? in
                guard let v = t[k] ?? t[k.lowercased()] else { return nil }
                return "\(k) \(EideKnowledgeFormat.giaTri(v))"
            }
            themDong(ten, ([mh] + bo).filter { !$0.isEmpty }.joined(separator: " · "),
                     mau: bo.count == 3 ? nil : EideToken.Mau.warn)
        }

        for b in hh {
            let ten = (b["badge"] as? String) ?? (b["kind"] as? String) ?? "?"
            let goi = (b["package"] as? String) ?? ""
            let diem = b["score"].map { " · điểm \(EideKnowledgeFormat.giaTri($0))" } ?? ""
            let ngay = (b["at"] as? String).map { " · \($0)" } ?? ""
            let co = !diem.isEmpty && !ngay.isEmpty
            themDong("\(ten) \(goi)",
                     co ? "\(diem)\(ngay)".trimmingCharacters(in: .whitespaces)
                        : "KHÔNG kèm điểm/ngày — huy hiệu tự chứng thực",
                     mau: co ? EideToken.Mau.ok : EideToken.Mau.warn)
        }

        if soDong == 0 { noiRong("Chưa có tác vụ hay huy hiệu nào.") }
    }
}
