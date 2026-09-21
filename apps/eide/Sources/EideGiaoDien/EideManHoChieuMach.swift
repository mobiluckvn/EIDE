import AppKit
import EideLoi

/// **S6 — Hộ chiếu mạch.** UXC-31 §8 S6; năng lực `diagram.pinmap` (DIAGRAM-03),
/// `board.check_pins` (BOARD-02), `board.constraints` (BOARD-03), `board.propose_fix` (BOARD-04),
/// `board.mark_lab` (BOARD-05).
///
/// ## Màn cuối của nhóm TRI THỨC, và là chỗ tri thức chạm vào đồng
///
/// S5 nói *con chip* biết gì. Màn này nói *tấm mạch trước mặt* nối những gì vào đâu — và đó là
/// chỗ hai nguồn tri thức gặp nhau: hộ chiếu chip (chân nào làm được gì) và netlist (chân nào
/// đang nối vào đâu). Mọi xung đột chân đều sinh ra từ chỗ giao ấy.
///
/// ## Khai báo mạch lab là một lời khai về AN TOÀN
///
/// `board.mark_lab` mở cổng `G-OPS-01` cho tác tử tự nạp firmware. BOARD-05 đòi **cả hai** lời
/// khai (`no_actuator`, `current_limited`) và E1000 khi thiếu một — vì "board không có cơ cấu
/// chấp hành nhưng chưa hạn dòng" vẫn cháy được. Màn này vì thế không có một nút "đánh dấu
/// lab": nó có hai ô xác nhận, và nút chỉ sống khi cả hai được tích.
public final class EideManHoChieuMach: EideManCoSo {

    public override class var tien: String { "Board" }

    private var goiLoi: EideGoi?
    private var board = ""
    private let cocBao = NSStackView()
    private let oKhongCoCoCau = NSButton(checkboxWithTitle:
        "Board KHÔNG có cơ cấu chấp hành (động cơ, van, rơ-le…)", target: nil, action: nil)
    private let oHanDong = NSButton(checkboxWithTitle:
        "Nguồn cấp ĐÃ hạn dòng", target: nil, action: nil)
    private let nutLab = NSButton(title: "Khai báo là mạch lab", target: nil, action: nil)

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBao.orientation = .vertical
        cocBao.alignment = .leading
        cocBao.spacing = 4

        let bc = try await nangLuc(goi, "project.status")
        let tg = ((bc["report"] as? [String: Any])?["target"] as? [String: Any]) ?? [:]
        board = (tg["board"] as? String) ?? ""
        guard !board.isEmpty else {
            // Đúng câu UXC-31 §8 S6 quy định cho trạng thái rỗng.
            return rong(vi: "chưa có schematic/BOM — dự án chưa ghim board nào",
                        buocKe: "nhập netlist KiCad hoặc BOM ở màn Nhập tài liệu (S4), rồi "
                              + "`board.build_passport` dựng hộ chiếu mạch từ chúng")
        }

        guard let pm = try await nangLucNeuCo(goi, "diagram.pinmap", ["board": board]) else {
            return rong(vi: "board `\(board)` đã ghim nhưng store chưa có net nào của nó",
                        buocKe: "nhập netlist ở màn Nhập tài liệu (S4) — bản đồ chân dựng từ "
                              + "netlist chứ không từ tên board")
        }
        let hang = (pm["table"] as? [[String: Any]]) ?? []

        // Xung đột đọc RIÊNG chứ không lấy cờ `conflict` của bảng chân: cờ ấy chỉ nói có/không,
        // còn `check_pins` nói xung đột LOẠI GÌ và NẶNG tới đâu — mà đó là thứ quyết định người
        // dùng phải sửa ngay hay ghi chú lại.
        let xd = ((try? await nangLuc(goi, "board.check_pins", ["board": board]))?["conflicts"]
                  as? [[String: Any]]) ?? []
        let theoChan = Dictionary(grouping: xd) { ($0["pin"] as? String) ?? "" }

        _dongBoard(tg)
        if !xd.isEmpty { _bangXungDot(xd) }

        // **Bảng chân rỗng KHÔNG được kết thúc màn.** `diagram.pinmap` cần fact `pin_function`
        // của hộ chiếu CHIP để ánh xạ `U1 chân 28` → `PB6/SCL`; chưa nhập datasheet chân thì
        // bảng rỗng — trong khi `board.check_pins` và `board.constraints` vẫn chạy trên chính
        // netlist ấy và vẫn có kết quả. Đo 20/09 trên một netlist thật: bảng 0 hàng, mà
        // `check_pins` tìm ra một net I2C thiếu điện trở kéo lên và `constraints` trả về giới
        // hạn bus 400 kHz. Trả `rong()` ở đây là vứt cả hai đi cùng với khối khai báo lab.
        if hang.isEmpty {
            _ghiChu(vi: "chưa ánh xạ được chân MCU — `diagram.pinmap` cần fact `pin_function` "
                      + "của hộ chiếu chip, không chỉ cần netlist",
                    buocKe: "nhập datasheet chân của MCU ở màn Nhập tài liệu (S4); phần kiểm "
                          + "xung đột và ràng buộc dưới đây vẫn đọc được từ netlist")
        } else {
            tieuDePhu("\(hang.count) CHÂN" + (xd.isEmpty ? "" : " · \(xd.count) XUNG ĐỘT"))
            bang(cot: [("CHÂN", 96), ("AF", 118), ("NET", 130), ("LINH KIỆN", 150),
                       ("HƯỚNG", 74), ("KIỂM", 0)],
                 dong: hang.map { d in
                     let chan = (d["pin"] as? String) ?? "?"
                     return [chan,
                             (d["af"] as? String) ?? "—",
                             (d["net"] as? String) ?? "—",
                             (d["part"] as? String) ?? "—",
                             (d["dir"] as? String) ?? "—",
                             Self.oKiem(theoChan[chan] ?? [],
                                        coCo: (d["conflict"] as? Bool) ?? false)]
                 })
        }

        await _khoiRangBuoc(goi)
        // v1.3 — đọc trạng thái lab ĐANG CÓ HIỆU LỰC. `policy.rules.boards` (DEV-135)
        // đọc từ CÙNG cấu hình `G-OPS-01` dùng để quyết định, nên ô này và cổng không
        // thể nói hai chuyện khác nhau về một board.
        let lab = ((try? await nangLuc(goi, "policy.rules"))?["boards"]
                   as? [String: Any])?[board] as? [String: Any]
        them(_khoiLab(lab))
        them(cocBao)
    }

    /// Ghi chú hai phần — như `rong()` nhưng KHÔNG kết thúc màn.
    ///
    /// Bất biến B5 đòi mọi chỗ trống nói "vì gì" và "bước kế tiếp"; nó không đòi chỗ trống ấy
    /// phải là cả màn. Một phần rỗng giữa hai phần có dữ liệu cần đúng hai câu ấy, tại chỗ.
    private func _ghiChu(vi ly: String, buocKe: String) {
        for (s, m) in [("Phần này đang trống — vì: \(ly)", EideToken.Mau.muted),
                       ("Bước kế tiếp: \(buocKe)", EideToken.Mau.faint)] {
            let n = NSTextField(wrappingLabelWithString: s)
            n.font = EideToken.fontUI
            n.textColor = m
            them(n)
        }
    }

    /// Ô cột KIỂM.
    ///
    /// Bảng chân mang sẵn cờ `conflict` (có/không), còn `check_pins` mang LOẠI và MỨC NẶNG. Khi
    /// hai nguồn ấy lệch nhau — cờ bật mà `check_pins` không nêu chân ấy — thì nói ra chứ không
    /// chọn một bên: một trong hai đường đang sai, và giấu đi thì không ai biết đường nào.
    public static func oKiem(_ xd: [[String: Any]], coCo: Bool) -> String {
        guard !xd.isEmpty else {
            return coCo ? "⚠ cờ xung đột nhưng check_pins không nêu — hai đường lệch nhau" : "ok"
        }
        let nang = xd.contains { ($0["severity"] as? String) == "blocker" }
        let loai = xd.compactMap { $0["kind"] as? String }.joined(separator: ", ")
        return "\(nang ? "⛔ CHẶN" : "⚠") \(loai)"
    }

    // MARK: - các khối

    private func _dongBoard(_ tg: [String: Any]) {
        let pins = (tg["pins"] as? [String: Any]) ?? [:]
        tieuDePhu("BOARD ĐÃ GHIM")
        var dong = [["Board", (pins["board"] as? String) ?? board]]
        if let c = tg["chip"] as? String, !c.isEmpty { dong.append(["Chip", c]) }
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)
    }

    private func _bangXungDot(_ xd: [[String: Any]]) {
        let chan = xd.filter { ($0["severity"] as? String) == "blocker" }
        let n = NSTextField(wrappingLabelWithString:
            chan.isEmpty
            ? "⚠ \(xd.count) cảnh báo chân — xem cột KIỂM. Không cái nào ở mức CHẶN."
            : "⛔ \(chan.count)/\(xd.count) xung đột ở mức CHẶN: "
              + chan.prefix(4).map { ($0["pin"] as? String) ?? "?" }.joined(separator: ", ")
              + (chan.count > 4 ? "…" : "")
              + ". Sinh mã dựa trên bản đồ chân này sẽ sinh ra firmware nối sai chân.")
        n.font = EideToken.fontUI
        n.textColor = chan.isEmpty ? EideToken.Mau.warn : EideToken.Mau.bad
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = chan.isEmpty ? EideToken.Mau.warnBg : EideToken.Mau.badBg
        them(n)

        for x in xd.prefix(8) { them(_hangXungDot(x)) }
    }

    /// Một xung đột + nút xin phương án sửa.
    ///
    /// `board.propose_fix` sinh phương án bằng cách TRA BẢNG `pin_function` chứ không gọi mô
    /// hình (BOARD-04 bước 1, [DEV-067]) — chân nào thay được cho chân nào là một sự thật của
    /// datasheet, mà mô hình không có bảng ấy. Nút này vì thế rẻ và đáng bấm.
    private func _hangXungDot(_ x: [String: Any]) -> NSView {
        let mo = NSTextField(wrappingLabelWithString:
            "\((x["pin"] as? String) ?? "?") · \((x["kind"] as? String) ?? "?") — "
            + ((x["detail"] as? String) ?? ""))
        mo.font = EideToken.fontUI
        mo.textColor = EideToken.Mau.text
        let b = NSButton(title: "Phương án sửa", target: self, action: #selector(_xinPhuongAn(_:)))
        b.bezelStyle = .inline
        b.identifier = NSUserInterfaceItemIdentifier((x["pin"] as? String) ?? "")
        let h = NSStackView(views: [mo, b])
        h.orientation = .horizontal
        h.alignment = .top
        h.spacing = 8
        return h
    }

    @objc private func _xinPhuongAn(_ n: NSButton) {
        guard let goi = goiLoi, let chan = n.identifier?.rawValue else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                let xd = ((try await nangLuc(goi, "board.check_pins", ["board": board]))["conflicts"]
                          as? [[String: Any]]) ?? []
                guard let x = xd.first(where: { ($0["pin"] as? String) == chan }) else {
                    return _bao("Xung đột ở \(chan) không còn — mở lại màn để xem bản mới.",
                                mau: EideToken.Mau.muted)
                }
                let r = try await nangLuc(goi, "board.propose_fix", ["conflict": x])
                hienPhuongAn(chan, (r["options"] as? [[String: Any]]) ?? [])
            } catch {
                _bao("Không sinh được phương án: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// Tách khỏi phần gọi lõi để test đo được.
    public func hienPhuongAn(_ chan: String, _ ds: [[String: Any]]) {
        _xoaBao()
        guard !ds.isEmpty else {
            return _bao("Không có phương án nào cho \(chan). BOARD-04 nêu \"chưa tra được chân "
                        + "thay thế\" khi hộ chiếu chân chưa có — nhập datasheet chân ở S4.",
                        mau: EideToken.Mau.warn)
        }
        _bao("\(ds.count) phương án cho \(chan) — xếp theo ít thay đổi nhất:",
             mau: EideToken.Mau.text)
        for (i, o) in ds.enumerated() {
            // `touches_code` là thứ quyết định phương án này rẻ hay đắt: đổi một chân trên mạch
            // là việc của mỏ hàn, còn đổi một chân đã có mã passing dùng tới là một lần sửa mã
            // kèm chạy lại test — và BOARD-04 đánh dấu ASK cho đúng trường hợp ấy.
            let cham = (o["touches_code"] as? Bool) == true
            _bao("  \(i + 1). \(EideManHoChieu.giaTri(o["change"]))"
                 + "  · giá \(EideManHoChieu.giaTri(o["cost"]))"
                 + (cham ? "  · CHẠM MÃ đang chạy — cần người duyệt" : ""),
                 mau: cham ? EideToken.Mau.warn : EideToken.Mau.text)
        }
    }

    private func _khoiRangBuoc(_ goi: @escaping EideGoi) async {
        guard let r = try? await nangLuc(goi, "board.constraints", ["board": board]),
              let c = r["constraints"] as? [String: Any], !c.isEmpty else { return }
        tieuDePhu("RÀNG BUỘC SINH TỪ MẠCH")
        bang(cot: [("MỤC", 230), ("GIÁ TRỊ", 0)], dong: Self.phang(c))
    }

    /// Trải một cây ràng buộc thành các hàng `đường.dẫn → giá trị`.
    ///
    /// `EideManHoChieu.giaTri` rút một từ điển thành `{n khoá}` — đúng cho một ô trong bảng fact,
    /// và sai ở đây. Đo 20/09 trên một netlist thật: bảng hiện `bus_limits · {1 khoá}`, giấu mất
    /// `{i2c: {max_khz: 400, pullup_ohm: 4700, why: "kéo lên 4700 Ω ≤ 4700 Ω — đủ nhanh cho
    /// Fast-mode 400 kHz"}}`. Câu `why` ấy là toàn bộ giá trị của `board.constraints`: nó nói
    /// giới hạn đến TỪ ĐÂU, nên người đọc kiểm lại được thay vì phải tin.
    public static func phang(_ x: [String: Any], _ tien: String = "") -> [[String]] {
        var ra: [[String]] = []
        for k in x.keys.sorted() {
            let duong = tien.isEmpty ? k : "\(tien).\(k)"
            if let con = x[k] as? [String: Any] {
                // Từ điển RỖNG không đệ quy được, và `{0 khoá}` lại là đếm thay vì nói. Đúng
                // câu ở đây là "chưa có" — cùng một `voltage.rails` rỗng, hai cách viết dẫn
                // người đọc tới hai kết luận khác nhau.
                ra += con.isEmpty ? [[duong, "chưa có"]] : phang(con, duong)
            } else {
                ra.append([duong, EideManHoChieu.giaTri(x[k])])
            }
        }
        return ra
    }

    /// Khối khai báo mạch lab.
    ///
    /// **Trạng thái hiện tại đọc từ `policy.rules.boards`** — v1.3, [DEV-135].
    ///
    /// Tới 21/09 khối này phải nói "chưa đọc lại được": `board.mark_lab` ghi `boards.<id>` vào
    /// `autonomy.yaml` mà không năng lực nào trong 244 cái đọc ra khoá ấy. Màn nói thẳng điều
    /// đó thay vì hiện một trạng thái nó không biết — một ô "lab: chưa" trông y hệt một ô chưa
    /// đọc được.
    ///
    /// Nay `POLICY-08` trả thêm `boards`, đọc từ CÙNG cấu hình mà `G-OPS-01` dùng để quyết
    /// định. `nil` vẫn là một câu trả lời: board này CHƯA được khai, khác hẳn "khai là không".
    private func _khoiLab(_ lab: [String: Any]?) -> NSView {
        tieuDePhu("MẠCH LAB — mở cổng cho tác tử TỰ NẠP firmware")
        let giai = NSTextField(wrappingLabelWithString:
            "BOARD-05 đòi CẢ HAI lời khai, vì \"không có cơ cấu chấp hành nhưng chưa hạn dòng\" "
            + "vẫn cháy được. Lời khai ghi tên anh vào `autonomy.yaml` và ký lại niêm. "
            + Self.cauTrangThai(lab, board: board))
        giai.font = EideToken.fontUI
        giai.textColor = EideToken.Mau.muted
        them(giai)

        for o in [oKhongCoCoCau, oHanDong] {
            o.target = self
            o.action = #selector(_doiTich)
        }
        nutLab.target = self
        nutLab.action = #selector(_khaiLab)
        nutLab.bezelStyle = .rounded
        nutLab.isEnabled = false

        let coc = NSStackView(views: [oKhongCoCoCau, oHanDong, nutLab])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 6
        return coc
    }

    /// Nút chỉ sống khi CẢ HAI ô được tích — hợp đồng trả E1000 khi thiếu một, và một nút bấm
    /// được rồi mới báo lỗi là một nút dạy người dùng bỏ qua thông báo.
    /// Câu trạng thái lab của một board. **Ba trạng thái, không hai.**
    ///
    /// `nil` = chưa khai bao giờ; khai rồi thì `lab` và `has_actuator` mỗi cái vẫn có thể thiếu
    /// — và thiếu KHÔNG được đọc thành `false`. BOARD-05 đòi cả hai lời khai vì "không có cơ
    /// cấu chấp hành nhưng chưa hạn dòng" vẫn cháy được; một trường thiếu bị đoán thành "an
    /// toàn" là bỏ mất đúng nửa nguy hiểm của phép đòi ấy.
    public static func cauTrangThai(_ lab: [String: Any]?, board: String) -> String {
        guard let lab else {
            return "Board `\(board)` CHƯA được khai là mạch lab — cổng `G-OPS-01` đang hỏi "
                 + "người trước mỗi lần nạp."
        }
        func ba(_ k: String) -> String {
            if let n = lab[k] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() {
                return n.boolValue ? "có" : "không"
            }
            if let b = lab[k] as? Bool { return b ? "có" : "không" }
            return "CHƯA khai"
        }
        let vi = (lab["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return "Trạng thái hiện tại của `\(board)`: mạch lab **\(ba("lab"))** · không cơ cấu "
             + "chấp hành **\(ba("has_actuator"))**"
             + (vi.map { " — \($0)" } ?? "") + "."
    }

    @objc private func _doiTich() {
        nutLab.isEnabled = oKhongCoCoCau.state == .on && oHanDong.state == .on
    }

    @objc private func _khaiLab() {
        guard let goi = goiLoi else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBao()
            do {
                let r = try await goi("caps.invoke", ["id": "board.mark_lab", "params": [
                    "board": board, "no_actuator": true, "current_limited": true,
                    "by": EideManXungDot.nguoi(),
                ]])
                switch r["status"] as? String {
                case "done":
                    let lab = ((r["result"] as? [String: Any])?["lab"] as? Bool) ?? false
                    // `lab: false` KHÔNG phải lỗi: BOARD-05 đối chiếu lời khai với netlist, và
                    // thấy mạch lái động cơ thì ghi `false` kèm lý do. Lời khai của người có thể
                    // sai vì người khai không phải người vẽ mạch.
                    _bao(lab ? "Đã khai báo `\(board)` là mạch lab — niêm đã ký lại."
                             : "Lõi KHÔNG chấp nhận: netlist có mạch lái cơ cấu chấp hành, trái "
                               + "với lời khai. Board ghi `lab: false` kèm lý do.",
                         mau: lab ? EideToken.Mau.ok : EideToken.Mau.bad)
                case "pending":
                    _bao("Đã gửi — chưa ghi. " + EideManXungDot.vinao(r["decision"])
                         + " Mục đang nằm ở CHỜ TÔI bên cột phải.", mau: EideToken.Mau.warn)
                default:
                    let e = (r["error"] as? [String: Any]) ?? [:]
                    _bao("Không khai báo được: " + ((e["message"] as? String) ?? "?")
                         + ((e["eide_code"] as? String).map { " (\($0))" } ?? ""),
                         mau: EideToken.Mau.bad)
                }
            } catch {
                _bao("Không gọi được lõi: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    // MARK: - phụ

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

    /// Cho test bấm mà không cần chuột.
    public func tichDeTest(khongCoCoCau: Bool, hanDong: Bool) {
        oKhongCoCoCau.state = khongCoCoCau ? .on : .off
        oHanDong.state = hanDong ? .on : .off
        _doiTich()
    }

    public var nutLabSongKhong: Bool { nutLab.isEnabled }
}
