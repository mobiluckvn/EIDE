import AppKit
import EideLoi

/// **Bốn màn chạm tới PHẦN CỨNG THẬT** — S17 Dò board, S18 Log & serial, S19 Gỡ lỗi probe,
/// S21 Bench. UXC-31 §8; [DEV-186].
///
/// ## Vì sao bốn màn này ra đời muộn, và vì sao chúng phải ra đời
///
/// Tới 22/09/2026 cả bốn có mặt trong menu cột trái và **không có lớp màn nào** — bấm vào mở ra
/// một vùng làm việc trống. Bộ dò nút `--do-nut` không thấy: nó duyệt menu, `moMan()` chỉ canh
/// danh sách menu nên vẫn trả `true`, rồi nó đếm nút trên một vùng trống và báo "0 nút chết
/// trên 25 màn". Một menu hứa 25 màn mà giao được 21 là lời hứa hão, và phép đo khi ấy đang
/// đứng về phía lời hứa.
///
/// ## Ba màn trong bốn sẽ RỖNG trên máy không cắm gì — và đó là trạng thái đúng
///
/// `discover.*`, `debug.experiment`, `target.serial` đều cần một board có thật. Màn rỗng ở đây
/// không phải màn hỏng: nó nói ra CẦN GÌ để có dữ liệu, đúng luật B5. Thứ sai là màn trống
/// không nói gì — thứ vừa thay thế.
///
/// ## Không màn nào TỰ chạm phần cứng khi mở
///
/// `discover.probe` và `discover.bus_scan` gửi tín hiệu xuống board; `debug.experiment` nạp
/// firmware thí nghiệm. Mở màn mà tự chạy là tác động lên phần cứng của người dùng vì họ bấm
/// nhầm một mục menu — POL-17 G-OPS tồn tại để chặn đúng chuyện ấy, và giao diện không được đi
/// vòng qua nó. Mọi thao tác chạm board đều sau MỘT nút bấm có nhãn nói rõ nó sẽ làm gì.
///
/// Riêng `discover.ports` chỉ liệt kê cổng USB của máy phát triển — không gửi gì xuống board —
/// nên nó chạy được lúc mở màn.

// MARK: - S17 Dò board

/// **S17 — Dò board.** UXC-31 §8 S17; `discover.ports` (DISCOVER-01), `discover.probe`,
/// `discover.chip_id`, `discover.bus_scan`, `discover.power`, `discover.link_speed`.
public final class EideManDoBoard: EideManCoSo {

    public override class var tien: String { "Discovery" }

    private var goiLoi: EideGoi?
    private let cocDo = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocDo.orientation = .vertical
        cocDo.alignment = .leading
        cocDo.spacing = 4

        // Cổng USB của MÁY — không gửi gì xuống board, nên chạy ngay được.
        let r = try? await nangLuc(goi, "discover.ports")
        let cong = (r?["ports"] as? [[String: Any]]) ?? []

        tieuDePhu("CỔNG VÀ PROBE — \(cong.count) cổng đang cắm")
        if cong.isEmpty {
            them(Self.chu("Không cổng USB/serial nào đang cắm. Cắm board rồi bấm “Dò lại”.",
                          mau: EideToken.Mau.muted))
        } else {
            bang(cot: [("THIẾT BỊ", 190), ("VID:PID", 104), ("LOẠI", 96), ("DRIVER", 96),
                       ("SERIAL", 0)],
                 dong: cong.map { p in
                     [(p["dev"] as? String) ?? "?",
                      Self.vidPid(p),
                      (p["kind"] as? String) ?? "—",
                      // Driver THIẾU là lý do thường gặp nhất khiến board cắm rồi mà không nạp
                      // được — nói thẳng chứ không để ô trống.
                      ((p["driver_ok"] as? Bool) ?? true) ? "ok" : "THIẾU DRIVER",
                      (p["serial"] as? String) ?? "—"]
                 })
        }

        // Chip đã ghim, để đối chiếu KHỚP/LỆCH sau khi dò.
        let st = try? await nangLuc(goi, "project.status")
        let tg = ((st?["report"]) as? [String: Any])?["target"] as? [String: Any] ?? [:]
        let chip = EideManHoChieu.giaTri(tg["chip"])
        them(Self.chu(chip.isEmpty || chip == "—"
            ? "Dự án CHƯA ghim chip — dò xong sẽ không đối chiếu KHỚP/LỆCH được với gì cả."
            : "Chip đã ghim: `\(chip)`. Dò xong, ID đọc từ board sẽ đối chiếu với chip này và "
              + "báo KHỚP hay LỆCH.",
            mau: EideToken.Mau.muted))

        them(_hangNut())
        them(cocDo)

        if cong.isEmpty {
            them(Self.chu("Bus quét được và nguồn điện chỉ đọc được khi có probe — cắm probe "
                          + "(ST-Link, J-Link, CMSIS-DAP, PICkit, AVRISP…) rồi bấm “Dò probe”.",
                          mau: EideToken.Mau.faint))
        }
    }

    /// Bốn thao tác CHẠM BOARD, mỗi cái một nút. Nhãn nói rõ nó gửi gì xuống — người bấm phải
    /// biết trước, vì `discover.bus_scan` ghi lên bus I2C của một mạch đang chạy.
    private func _hangNut() -> NSView {
        let ds = [("Dò probe", "discover.probe"),
                  ("Đọc ID chip", "discover.chip_id"),
                  ("Quét bus I2C/SPI", "discover.bus_scan"),
                  ("Đọc nguồn điện", "discover.power"),
                  ("Dò tốc độ kết nối", "discover.link_speed")]
        let h = NSStackView(views: ds.map { nhan, cap in
            let b = NSButton(title: nhan, target: self, action: #selector(_chay(_:)))
            b.bezelStyle = .inline
            b.identifier = NSUserInterfaceItemIdentifier(cap)
            b.font = EideToken.fontUI
            return b
        })
        h.orientation = .horizontal
        h.spacing = 6
        return h
    }

    @objc private func _chay(_ n: NSButton) {
        guard let cap = n.identifier?.rawValue, let goi = goiLoi else { return }
        Task { @MainActor in
            cocDo.arrangedSubviews.forEach { $0.removeFromSuperview() }
            cocDo.addArrangedSubview(Self.chu("Đang chạy `\(cap)`…", mau: EideToken.Mau.faint))
            do {
                let r = try await nangLuc(goi, cap)
                cocDo.arrangedSubviews.forEach { $0.removeFromSuperview() }
                cocDo.addArrangedSubview(Self.chu(Self.tomTat(cap, r), mau: EideToken.Mau.text))
            } catch {
                cocDo.arrangedSubviews.forEach { $0.removeFromSuperview() }
                // Lỗi của một lần dò KHÔNG phải lỗi của màn: board chưa cắm là tình huống
                // thường gặp nhất và nó có cách sửa.
                cocDo.addArrangedSubview(Self.chu("`\(cap)` không chạy được: \(error)",
                                                  mau: EideToken.Mau.bad))
            }
        }
    }

    /// Kết quả một lần dò → một câu. Mỗi năng lực trả một hình dạng khác nhau, nên mỗi cái một
    /// câu; một hàm chung in `{n khoá}` là đúng thứ [DEV-171] vừa gỡ ở màn Kế hoạch.
    public static func tomTat(_ cap: String, _ r: [String: Any]) -> String {
        switch cap {
        case "discover.probe":
            let ds = (r["probes"] as? [[String: Any]]) ?? []
            guard !ds.isEmpty else { return "Không thấy probe nào đang cắm." }
            return "\(ds.count) probe: " + ds.map {
                "\(($0["kind"] as? String) ?? "?") (\(($0["tool"] as? String) ?? "—"))"
            }.joined(separator: ", ")
        case "discover.chip_id":
            let i = (r["identity"] as? [String: Any]) ?? [:]
            let raw = EideManHoChieu.giaTri(i["raw"])
            // KHỚP/LỆCH là câu quan trọng nhất của cả màn: nạp firmware của chip A lên chip B
            // là cách hỏng board nhanh nhất, và `passport_match` là chỗ duy nhất biết.
            let khop = (i["passport_match"] as? Bool)
            let ket = khop == true ? "KHỚP hộ chiếu đã ghim"
                    : (khop == false ? "LỆCH so với chip đã ghim — ĐỪNG nạp firmware"
                                     : "chưa đối chiếu được với hộ chiếu nào")
            return "ID đọc được: \(raw) (qua \(EideManHoChieu.giaTri(i["method"]))) — \(ket)."
        case "discover.bus_scan":
            let ds = (r["devices"] as? [[String: Any]]) ?? []
            guard !ds.isEmpty else { return "Bus quét xong, không thiết bị nào trả lời." }
            return "Bus: \(ds.count) thiết bị — " + ds.map {
                EideManHoChieu.giaTri($0["addr"] ?? $0["id"])
                + (($0["matched_part"] as? String).map { " = \($0)" } ?? "")
            }.joined(separator: ", ")
        case "discover.power":
            let p = (r["power"] as? [String: Any]) ?? [:]
            let canh = (p["warnings"] as? [Any]) ?? []
            return "Nguồn điện: VDD \(EideManHoChieu.giaTri(p["vdd"])), "
                 + "IDD \(EideManHoChieu.giaTri(p["idd"]))"
                 + (canh.isEmpty ? " — trong ngưỡng."
                                 : " — \(canh.count) cảnh báo: "
                                   + canh.map { EideManHoChieu.giaTri($0) }
                                         .joined(separator: "; "))
        case "discover.link_speed":
            let chon = EideManHoChieu.nguyen(r["chosen"]).map { "\($0)" } ?? "—"
            let tran = EideManHoChieu.nguyen(r["limit"]).map { " (trần \($0))" } ?? ""
            return "Tốc độ kết nối chọn được: \(chon)\(tran)."
        default:
            return "`\(cap)` chạy xong."
        }
    }

    public static func vidPid(_ p: [String: Any]) -> String {
        let v = EideManHoChieu.giaTri(p["vid"]), i = EideManHoChieu.giaTri(p["pid"])
        return (v == "—" && i == "—") ? "—" : "\(v):\(i)"
    }

    static func chu(_ s: String, mau: NSColor) -> NSTextField {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        return n
    }
}

// MARK: - S18 Log & serial

/// **S18 — Log & serial.** UXC-31 §8 S18; `debug.log_stats` (DEBUG-01), `debug.ask_at`
/// (DEBUG-02), `serial.open`/`serial.write` (API-15 §2).
///
/// Hai nửa của màn trả lời hai câu khác nhau: log ĐÃ GHI trả lời *"vừa rồi có gì bất thường"*,
/// còn serial trực tiếp trả lời *"ngay bây giờ nó đang nói gì"*. Gộp chúng vào một khung cuộn
/// chung là đánh mất phân biệt ấy — dòng serial mới chen vào giữa thống kê của một phiên cũ.
public final class EideManLog: EideManCoSo {

    public override class var tien: String { "LogAssist" }

    private var goiLoi: EideGoi?
    private let oMau = NSTextField()
    private let oHoi = NSTextField()
    private let cocKetQua = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocKetQua.orientation = .vertical
        cocKetQua.alignment = .leading
        cocKetQua.spacing = 4

        let r = try? await nangLuc(goi, "debug.log_stats")
        let tk = (r?["stats"] as? [String: Any]) ?? [:]
        let mau = (tk["top_patterns"] as? [[String: Any]]) ?? []

        tieuDePhu("THỐNG KÊ LOG")
        if mau.isEmpty {
            them(EideManDoBoard.chu(
                "Chưa có log nào đăng ký cho dự án này. `log.register` nhận một tệp log "
                + "(GEditor hoặc tệp rời); sau đó `debug.log_stats` rút mẫu lặp, khoảng trống "
                + "thời gian và phân bố mức.", mau: EideToken.Mau.muted))
        } else {
            bang(cot: [("MẪU LẶP", 360), ("SỐ LẦN", 84), ("MỨC", 0)],
                 dong: mau.map { m in
                     [EideManHoChieu.giaTri(m["pattern"] ?? m["text"]),
                      "\(EideManHoChieu.nguyen(m["count"]) ?? 0)",
                      EideManHoChieu.giaTri(m["level"])]
                 })
            let khoang = (tk["gaps"] as? [Any]) ?? []
            if !khoang.isEmpty {
                // Khoảng TRỐNG trong log là bằng chứng của treo/reset — thứ dễ bỏ sót nhất khi
                // đọc log bằng mắt, vì nó là chỗ KHÔNG có gì.
                them(EideManDoBoard.chu("\(khoang.count) khoảng trống thời gian — thiết bị im "
                                        + "trong những quãng ấy (treo, reset, hoặc mất nguồn).",
                                        mau: EideToken.Mau.warn))
            }
        }

        them(_khungLoc())
        them(_khungHoiTaiDong())
        them(cocKetQua)
    }

    /// Lọc theo MẪU LỖI — §8 S18.
    private func _khungLoc() -> NSView {
        oMau.placeholderString = "Lọc log theo mẫu lỗi — ví dụ: HardFault|watchdog|timeout"
        oMau.font = EideToken.fontUI
        oMau.target = self
        oMau.action = #selector(_loc)
        let b = NSButton(title: "Lọc", target: self, action: #selector(_loc))
        b.bezelStyle = .inline
        // Nút chỉ sáng khi ô có chữ: lọc theo một mẫu RỖNG không phải một việc, và nút bấm
        // được mà không làm gì là nút dạy người dùng thôi tin nút.
        EideNutTheoO.noi(oMau, b)
        let h = NSStackView(views: [oMau, b])
        h.orientation = .horizontal
        h.spacing = 8
        oMau.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return h
    }

    /// **Hỏi tại dòng** — DEBUG-02. Ngữ cảnh gồm vùng log quanh dòng ấy, thống kê, hộ chiếu và
    /// mã liên quan; nên câu trả lời kèm fact và mã, không phải một đoạn văn chung chung.
    private func _khungHoiTaiDong() -> NSView {
        oHoi.placeholderString = "Hỏi tại dòng — dán một dòng log rồi hỏi “vì sao dòng này?”"
        oHoi.font = EideToken.fontUI
        oHoi.target = self
        oHoi.action = #selector(_hoiTaiDong)
        let b = NSButton(title: "Hỏi tại dòng", target: self, action: #selector(_hoiTaiDong))
        b.bezelStyle = .rounded
        EideNutTheoO.noi(oHoi, b)
        let h = NSStackView(views: [oHoi, b])
        h.orientation = .horizontal
        h.spacing = 8
        oHoi.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let g = NSTextField(wrappingLabelWithString:
            "Serial trực tiếp: `serial.open` mở cổng và đẩy từng dòng lên vùng trao đổi bằng "
            + "`event.serial.line` — cần board đang cắm.")
        g.font = EideToken.fontUI
        g.textColor = EideToken.Mau.faint
        let coc = NSStackView(views: [h, g])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 3
        return coc
    }

    @objc private func _loc() {
        guard let goi = goiLoi else { return }
        let m = oMau.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        Task { @MainActor in
            _xoa()
            do {
                let r = try await nangLuc(goi, "debug.log_stats", ["pattern": m])
                let tk = (r["stats"] as? [String: Any]) ?? [:]
                let ds = (tk["top_patterns"] as? [[String: Any]]) ?? []
                cocKetQua.addArrangedSubview(EideManDoBoard.chu(
                    ds.isEmpty ? "Không dòng nào khớp `\(m)`."
                               : "\(ds.count) mẫu khớp `\(m)`.", mau: EideToken.Mau.text))
                for d in ds.prefix(12) {
                    cocKetQua.addArrangedSubview(EideManDoBoard.chu(
                        "· " + EideManHoChieu.giaTri(d["pattern"] ?? d["text"])
                        + " × \(EideManHoChieu.nguyen(d["count"]) ?? 0)",
                        mau: EideToken.Mau.muted))
                }
            } catch {
                cocKetQua.addArrangedSubview(EideManDoBoard.chu("Không lọc được: \(error)",
                                                               mau: EideToken.Mau.bad))
            }
        }
    }

    @objc private func _hoiTaiDong() {
        guard let goi = goiLoi else { return }
        let q = oHoi.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        Task { @MainActor in
            _xoa()
            cocKetQua.addArrangedSubview(EideManDoBoard.chu("Đang hỏi…",
                                                            mau: EideToken.Mau.faint))
            do {
                let r = try await nangLuc(goi, "debug.ask_at", ["line": q])
                _xoa()
                let d = (r["diagnosis"] as? [String: Any]) ?? [:]
                cocKetQua.addArrangedSubview(EideManDoBoard.chu(
                    EideManHoChieu.giaTri(d["answer"] ?? d["text"]), mau: EideToken.Mau.text))
                for k in ["facts", "code", "citations"] {
                    let ds = (d[k] as? [Any]) ?? []
                    guard !ds.isEmpty else { continue }
                    cocKetQua.addArrangedSubview(EideManDoBoard.chu(
                        "\(k): " + ds.prefix(6).map { EideManHoChieu.giaTri($0) }
                                     .joined(separator: ", "),
                        mau: EideToken.Mau.muted))
                }
            } catch {
                _xoa()
                cocKetQua.addArrangedSubview(EideManDoBoard.chu("Không hỏi được: \(error)",
                                                                mau: EideToken.Mau.bad))
            }
        }
    }

    private func _xoa() { cocKetQua.arrangedSubviews.forEach { $0.removeFromSuperview() } }
}

// MARK: - S19 Gỡ lỗi probe

/// **S19 — Gỡ lỗi probe.** UXC-31 §8 S19; `debug.hypothesize` (DEBUG-03), `debug.experiment`
/// (DEBUG-04), `debug.propose_fix`.
///
/// ## Giả thuyết phải kèm BẰNG CHỨNG PHẢN BÁC, không chỉ bằng chứng ủng hộ
///
/// Một danh sách chỉ có bằng chứng ủng hộ là một danh sách tự khẳng định: giả thuyết nào cũng
/// trông đúng. Chỗ hữu ích của DEBUG-03 nằm ở thí nghiệm PHÂN BIỆT — thí nghiệm mà hai giả
/// thuyết hàng đầu cho hai kết quả khác nhau.
public final class EideManGoLoi: EideManCoSo {

    public override class var tien: String { "Debug" }

    private var goiLoi: EideGoi?
    private let cocKQ = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocKQ.orientation = .vertical
        cocKQ.alignment = .leading
        cocKQ.spacing = 4

        let r = try? await nangLuc(goi, "debug.hypothesize")
        let d = (r?["diagnosis"] as? [String: Any]) ?? [:]
        let gt = (d["hypotheses"] as? [[String: Any]]) ?? []

        tieuDePhu("GIẢ THUYẾT ĐANG XÉT")
        if gt.isEmpty {
            them(EideManDoBoard.chu(
                "Chưa có giả thuyết nào — `debug.hypothesize` cần một triệu chứng để bắt đầu: "
                + "một log đã đăng ký (màn Log & serial, S18), một lần dựng hỏng, hoặc một kỳ "
                + "vọng mô phỏng không đạt. Mô tả triệu chứng ở vùng trao đổi.",
                mau: EideToken.Mau.muted))
        } else {
            bang(cot: [("GIẢ THUYẾT", 300), ("ĐIỂM", 70), ("ỦNG HỘ", 200), ("PHẢN BÁC", 0)],
                 dong: gt.map { h in
                     [EideManHoChieu.giaTri(h["text"] ?? h["hypothesis"]),
                      EideManHoChieu.giaTri(h["score"]),
                      Self.gomBangChung(h["supporting"] ?? h["for"]),
                      // Ô này trống nhiều hơn ô ỦNG HỘ, và đó là một tín hiệu chứ không phải
                      // một khiếm khuyết trình bày: giả thuyết chưa ai tìm cách bác bỏ là giả
                      // thuyết chưa được kiểm.
                      Self.gomBangChung(h["refuting"] ?? h["against"])]
                 })
        }

        // EvidencePack — log, số đo, thanh ghi đọc được.
        let bc = (d["evidence"] as? [String: Any]) ?? [:]
        tieuDePhu("EVIDENCEPACK — BẰNG CHỨNG ĐÃ THU")
        if bc.isEmpty {
            them(EideManDoBoard.chu(
                "EvidencePack rỗng: chưa có log, số đo hay thanh ghi nào được thu cho phiên gỡ "
                + "lỗi này.", mau: EideToken.Mau.muted))
        } else {
            bang(cot: [("LOẠI", 150), ("NỘI DUNG", 0)],
                 dong: bc.keys.sorted().map { [$0, EideManHoChieu.giaTri(bc[$0])] })
        }

        tieuDePhu("THÍ NGHIỆM TIẾP THEO TÁC TỬ ĐỀ NGHỊ")
        let tn = (d["experiments"] as? [[String: Any]]) ?? []
        if tn.isEmpty {
            them(EideManDoBoard.chu(
                "Chưa có thí nghiệm nào được đề nghị. Thí nghiệm sinh ra cùng giả thuyết: "
                + "`debug.hypothesize` chọn phép thử PHÂN BIỆT được hai giả thuyết hàng đầu.",
                mau: EideToken.Mau.muted))
        } else {
            for t in tn.prefix(5) { them(_theThiNghiem(t)) }
        }
        them(cocKQ)
    }

    public static func gomBangChung(_ x: Any?) -> String {
        let ds = (x as? [Any]) ?? []
        guard !ds.isEmpty else { return "—" }
        return ds.prefix(3).map { EideManHoChieu.giaTri($0) }.joined(separator: "; ")
             + (ds.count > 3 ? " +\(ds.count - 3)" : "")
    }

    /// Thẻ một thí nghiệm — và nút chạy nó nói rõ nó CHẠM VÀO GÌ.
    ///
    /// `debug.experiment` nạp firmware thí nghiệm hoặc điều khiển probe; đó là thao tác G-OPS,
    /// và POL-17 đòi người cấp phép khi board chưa đánh dấu `lab`. Nút này không đi vòng qua
    /// cổng ấy — nó gọi năng lực như mọi chỗ khác, và cổng chặn thì câu hỏi hiện ở vùng trao
    /// đổi cùng hai nút Duyệt/Từ chối ([DEV-181]).
    private func _theThiNghiem(_ t: [String: Any]) -> NSView {
        let n = NSTextField(wrappingLabelWithString:
            "• " + EideManHoChieu.giaTri(t["text"] ?? t["description"])
            + (["distinguishes", "phan_biet"].compactMap { t[$0] }.first
                .map { " — phân biệt: \(EideManHoChieu.giaTri($0))" } ?? ""))
        n.font = EideToken.fontUI
        let b = NSButton(title: "Chạy thí nghiệm", target: self, action: #selector(_chayTN(_:)))
        b.bezelStyle = .inline
        b.font = EideToken.fontUI
        b.identifier = NSUserInterfaceItemIdentifier(
            EideManHoChieu.giaTri(t["id"] ?? t["text"] ?? "?"))
        let h = NSStackView(views: [n, b])
        h.orientation = .horizontal
        h.spacing = 8
        h.alignment = .firstBaseline
        return h
    }

    @objc private func _chayTN(_ n: NSButton) {
        guard let ma = n.identifier?.rawValue, let goi = goiLoi else { return }
        Task { @MainActor in
            cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
            cocKQ.addArrangedSubview(EideManDoBoard.chu(
                "Đang chạy thí nghiệm `\(ma)` — thao tác này chạm phần cứng, cổng G-OPS có thể "
                + "hỏi anh ở vùng trao đổi.", mau: EideToken.Mau.faint))
            do {
                let r = try await nangLuc(goi, "debug.experiment", ["experiment": ma])
                cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
                cocKQ.addArrangedSubview(EideManDoBoard.chu(
                    "Kết quả: " + EideManHoChieu.giaTri(r["result"] ?? r),
                    mau: EideToken.Mau.text))
            } catch {
                cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
                cocKQ.addArrangedSubview(EideManDoBoard.chu("Thí nghiệm không chạy được: "
                                                            + "\(error)",
                                                            mau: EideToken.Mau.bad))
            }
        }
    }
}

// MARK: - S21 Bench

/// **S21 — Bench.** UXC-31 §8 S21; `bench.run` (BENCH-01), `bench.badge` (BENCH-02).
///
/// ## Màn KHÔNG tự chạy bench khi mở
///
/// `bench.run` gọi mô hình nhiều lượt cho cả bộ tác vụ CF/BF/BC — tức là tốn tiền thật. Mở màn
/// mà tự chạy là tiêu ngân sách của người dùng vì họ bấm vào một mục menu. Cùng lý do đã viết
/// cho `sim.run` ở màn Mô phỏng, và ở đây cái giá đo bằng USD chứ không bằng giây CPU.
public final class EideManBench: EideManCoSo {

    public override class var tien: String { "Bench" }

    private var goiLoi: EideGoi?
    private let cocKQ = NSStackView()

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocKQ.orientation = .vertical
        cocKQ.alignment = .leading
        cocKQ.spacing = 4

        let hh = try? await nangLuc(goi, "bench.badge")
        let ds = (hh?["badges"] as? [[String: Any]]) ?? []

        tieuDePhu("BÀI CF / BF / BC")
        them(EideManDoBoard.chu(
            "CF = correctness-first, BF = build-first, BC = budget-constrained — ba bộ tác vụ "
            + "của BENCH-01. Bench gọi mô hình nhiều lượt nên nó TỐN TIỀN THẬT; màn này không "
            + "tự chạy khi mở.", mau: EideToken.Mau.muted))

        let b = NSButton(title: "Chạy bench (tốn token)", target: self, action: #selector(_chay))
        b.bezelStyle = .rounded
        b.font = NSFont.boldSystemFont(ofSize: 12)
        them(b)

        tieuDePhu("HUY HIỆU ĐẠT ĐƯỢC")
        if ds.isEmpty {
            them(EideManDoBoard.chu(
                "Chưa có huy hiệu nào. `bench.badge` gắn `verified`/`bench` cho một gói sau khi "
                + "nó đạt ngưỡng — chưa chạy bench thì chưa có gì để gắn.",
                mau: EideToken.Mau.muted))
        } else {
            bang(cot: [("GÓI", 220), ("HUY HIỆU", 130), ("ĐIỂM", 80), ("SO VỚI LẦN TRƯỚC", 0)],
                 dong: ds.map { h in
                     [EideManHoChieu.giaTri(h["package"] ?? h["pack"]),
                      EideManHoChieu.giaTri(h["badge"] ?? h["kind"]),
                      EideManHoChieu.giaTri(h["score"]),
                      Self.soSanh(h["delta"] ?? h["previous"])]
                 })
        }
        them(cocKQ)
    }

    /// So với lần chạy trước — dấu đi kèm số.
    ///
    /// `+0.03` và `0.03` là hai câu khác nhau khi con số có thể âm, và một bảng so sánh mất dấu
    /// là một bảng nói ngược đúng một nửa số trường hợp.
    public static func soSanh(_ x: Any?) -> String {
        guard let d = x as? Double else {
            let s = EideManHoChieu.giaTri(x)
            return s == "—" ? "chưa có lần trước để so" : s
        }
        return (d > 0 ? "+" : "") + String(format: "%.3f", d)
    }

    @objc private func _chay() {
        guard let goi = goiLoi else { return }
        Task { @MainActor in
            cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
            cocKQ.addArrangedSubview(EideManDoBoard.chu("Đang chạy bench — có thể mất vài phút "
                                                        + "và tiêu token.",
                                                        mau: EideToken.Mau.faint))
            do {
                let r = try await nangLuc(goi, "bench.run")
                cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
                let bc = (r["report"] as? [String: Any]) ?? [:]
                cocKQ.addArrangedSubview(EideManDoBoard.chu(
                    "Xong. " + bc.keys.sorted().map {
                        "\($0): \(EideManHoChieu.giaTri(bc[$0]))"
                    }.joined(separator: " · "), mau: EideToken.Mau.text))
            } catch {
                cocKQ.arrangedSubviews.forEach { $0.removeFromSuperview() }
                cocKQ.addArrangedSubview(EideManDoBoard.chu("Bench không chạy được: \(error)",
                                                            mau: EideToken.Mau.bad))
            }
        }
    }
}
