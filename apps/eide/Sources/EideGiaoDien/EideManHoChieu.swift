import AppKit
import EideLoi

/// **S5 — Hộ chiếu chip.** UXC-31 §8 S5; năng lực `passport.query` (PASSPORT-02) và
/// `view.provenance` (VIEW-03).
///
/// ## Màn này tồn tại để ĐỐI CHIẾU, không phải để tra cứu
///
/// Người mở S5 đang cầm datasheet của hãng ở màn bên cạnh và hỏi một câu: *điều EIDE tin có
/// khớp điều tài liệu nói không?* Mọi quyết định trình bày dưới đây đều rơi ra từ câu ấy — hệ
/// đếm của địa chỉ, chỗ đặt số trang, và việc một ô mâu thuẫn phải tự nói nó mâu thuẫn.
///
/// Đây cũng là chỗ luận điểm trung tâm của đề án hiện ra thành một thứ nhìn được: mỗi con số
/// mà tác tử dùng để sinh mã đều có một dòng ở đây, và dòng ấy trỏ về một nguồn.
public final class EideManHoChieu: EideManCoSo {

    public override class var tien: String { "Passport" }

    /// Số dòng fact hiện tối đa.
    ///
    /// `passport.query` trên STM32F411 trả **13 439 fact**, và hợp đồng PASSPORT-02 KHÔNG có
    /// tham số `limit` — khác `view.timeline`, vốn vừa được thêm `limit` ở [DEV-132]. Nên chỗ
    /// cắt đúng theo hợp đồng hiện hành là ở đây, tại bên vẽ. Phần bị cắt không im lặng: dòng
    /// tiêu đề phụ nói đã cắt bao nhiêu và lọc hẹp lại bằng cách nào.
    public static let TOI_DA = 300

    /// Ngưỡng PASSPORT-02 bước 1 hứa: "< 200 ms".
    public static let HAN_MS = 200

    /// Giữ lại để hai cái nút dưới bảng gọi lõi được sau khi `napDuLieu` đã trả về.
    private var goiLoi: EideGoi?
    private let chonFact = NSPopUpButton()
    private let cocNguon: NSStackView = {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 4
        return s
    }()
    private var factTheoNhan: [String: String] = [:]

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi

        // Đầu vào của màn là con chip ĐÃ GHIM của dự án, không phải một ô tìm kiếm. UXC-31 viết
        // trạng thái rỗng của S5 là *"chưa ghim chip; bước kế: nhập datasheet hoặc
        // target.detect"* — tức màn này trả lời "dự án này dựa trên tri thức nào", chứ không
        // phải "kho biết những chip nào". Câu thứ hai là của `passport.list`, và nó thuộc màn
        // khác.
        let bc = try await nangLuc(goi, "project.status")
        let rp = (bc["report"] as? [String: Any]) ?? [:]
        let tg = (rp["target"] as? [String: Any]) ?? [:]
        let ghim = (tg["chip"] as? String) ?? ""
        guard !ghim.isEmpty else {
            return rong(vi: "dự án chưa ghim chip nào — `constraints.yaml` không có `target.chip`",
                        buocKe: "nhập datasheet ở màn Nhập tài liệu (S4) rồi ghim bằng "
                              + "`project.set_target`, hoặc cắm board và chạy `target.detect`")
        }

        // `project.set_target` ghim CẢ PHIÊN BẢN (`st.stm32f411ce@1.2.0`) — đó là điểm của
        // PROJECT-06. Nhưng `passport.query` lọc theo tiền tố IRI `chip:<part>`, nên phần
        // `@version` phải rụng trước khi hỏi, kẻo bộ lọc không khớp fact nào và màn báo "chưa có
        // fact" cho một hộ chiếu đầy đủ.
        let part = Self.boPhienBan(ghim)
        let kq = try await nangLuc(goi, "passport.query", ["part": part])

        let facts = (kq["facts"] as? [[String: Any]]) ?? []
        let cit = (kq["citations"] as? [[String: Any]]) ?? []
        let tiers = (kq["tiers"] as? [String: Any]) ?? [:]
        let ms = Self.nguyen(kq["latency_ms"]) ?? 0

        guard !facts.isEmpty else {
            return rong(vi: "đã ghim `\(ghim)` nhưng store chưa có fact nào cho nó",
                        buocKe: "nhập datasheet/SVD cho chip này ở màn Nhập tài liệu (S4) — "
                              + "ghim một chip không tự kéo tri thức về")
        }

        _dongGhim(tg, ghim: ghim)
        _dongTang(tiers, facts: facts, soNguon: cit.count, ms: ms)

        // Mâu thuẫn nói TRƯỚC bảng. Một ô ⚠ nằm ở dòng 812 của 300 dòng đang hiện là một cảnh
        // báo không ai gặp; cả điểm của nó là chặn người dùng trước khi họ tin con số.
        let xungDot = facts.filter { ($0["status"] as? String) == "conflict" }
        if !xungDot.isEmpty { _bangCanhBao(xungDot) }

        let uri = Self.banDoNguon(cit)
        let hien = facts.prefix(Self.TOI_DA)
        tieuDePhu("\(facts.count) FACT"
                  + (facts.count > hien.count
                     ? " — hiện \(hien.count) đầu; lọc hẹp bằng `passport.query` kèm "
                       + "`periph`/`register` để thấy phần còn lại"
                     : ""))
        // CHỦ THỂ rộng 264 pt vì `periph:AC/reg:DIDR1/field:AIN0D` — dạng dài nhất còn thường
        // gặp — vừa đúng trong đó. `bang()` vẫn cắt kèm `…` cho phần dài hơn, nhưng cắt là
        // đường lui; chỗ này chọn bề rộng để đường lui gần như không phải dùng tới.
        bang(cot: [("CHỦ THỂ", 264), ("THUỘC TÍNH", 132), ("GIÁ TRỊ", 132), ("TẦNG", 136), ("NGUỒN", 0)],
             dong: hien.map { f in
                 let vt = (f["predicate"] as? String) ?? "?"
                 return [Self.chuTheNgan((f["subject"] as? String) ?? "?", part: part),
                         vt,
                         Self.giaTriTheoViTu(f["value"], vt),
                         Self.nhanTang((f["tier"] as? String) ?? "", (f["status"] as? String) ?? ""),
                         Self.oNguon(f, uri: uri)]
             })

        _khoiNguon(Array(hien))
    }

    // MARK: - các khối của màn

    /// Dòng "chip đã ghim" — và nó lấy tên chip từ `pins`, không từ `target.chip`.
    ///
    /// Đo 20/09 trên lõi thật: `report.target` mang CẢ HAI dạng. `target.chip` là tên trần
    /// (`st.stm32f411ce`), còn `target.pins.chip` là thứ `project.set_target` thực sự ghim —
    /// `st.stm32f411ce@1.2.0`. Hiện dạng thứ nhất là bỏ mất đúng điều PROJECT-06 tồn tại để
    /// nói: dự án này dựa trên BẢN MÔ TẢ NÀO của con chip, chứ không chỉ trên con chip nào.
    ///
    /// `@?` là một câu trả lời thứ ba, và nó không được im: chip đã ghim nhưng chưa có hộ chiếu
    /// nào để ghim phiên bản. Fact vẫn tra ra (chúng nằm trong store), nhưng `passport.diff`
    /// sau này không có mốc để so.
    private func _dongGhim(_ tg: [String: Any], ghim: String) {
        let pins = (tg["pins"] as? [String: Any]) ?? [:]
        let ten = (pins["chip"] as? String) ?? ghim
        tieuDePhu("CHIP ĐÃ GHIM")
        var dong = [["Chip", ten]]
        if let isa = tg["isa"] as? String, !isa.isEmpty { dong.append(["ISA", isa]) }
        if let board = tg["board"] as? String, !board.isEmpty { dong.append(["Board", board]) }
        if ten.hasSuffix("@?") {
            dong.append(["Phiên bản hộ chiếu",
                         "CHƯA GHIM — chưa có hộ chiếu cho chip này, nên `passport.diff` "
                         + "không có mốc để so khi tri thức đổi"])
        }
        bang(cot: [("MỤC", 158), ("GIÁ TRỊ", 0)], dong: dong)
    }

    /// Dòng tóm tắt — và nó nói cả điều mà bảng tầng KHÔNG nói.
    ///
    /// `tiers` đếm theo tầng nguồn. Nhưng câu hỏi thật của người mở màn này là *dùng được bao
    /// nhiêu trong số đó làm hằng số trong firmware*, và câu trả lời ấy theo một luật khác:
    /// `code.constant_guard` cho một literal đi qua khi fact có `status` là `reviewed`/
    /// `verified` **hoặc** tầng `gold` (CODE-04 bước 1; TC-04, TC-06).
    ///
    /// Hai con số ấy lệch nhau ngay sau một lần nhập: mọi fact vừa `passport.import` đều mang
    /// `status = normalized`. Chỉ hiện "vàng 2 · bạc 0 · đồng 1" thì màn đang nói một câu đúng
    /// mà người đọc sẽ hiểu thành một câu sai — rằng có hai con số dùng được ngay.
    private func _dongTang(_ tiers: [String: Any], facts: [[String: Any]],
                           soNguon: Int, ms: Int) {
        let vang = Self.nguyen(tiers["gold"]) ?? 0
        let bac = Self.nguyen(tiers["silver"]) ?? 0
        let dong = Self.nguyen(tiers["bronze"]) ?? 0
        let n = NSTextField(wrappingLabelWithString:
            "\(facts.count) fact · vàng \(vang) · bạc \(bac) · đồng \(dong) · "
            + "\(soNguon) nguồn · \(ms) ms"
            + (ms > Self.HAN_MS ? " — QUÁ HẠN 200 ms mà PASSPORT-02 bước 1 hứa" : ""))
        n.font = EideToken.fontUI
        // Con số độ trễ HIỆN RA, không giấu. Hợp đồng hứa một ngưỡng; giao diện không bao giờ
        // hiện nó thì không ai biết lúc nó thôi đúng.
        n.textColor = ms > Self.HAN_MS ? EideToken.Mau.warn : EideToken.Mau.muted
        them(n)

        let chan = facts.filter { !Self.quaDuocGuard($0) }.count
        guard chan > 0 else { return }
        let m = NSTextField(wrappingLabelWithString:
            "\(chan)/\(facts.count) fact CHƯA dùng được làm hằng số phần cứng — "
            + "`code.constant_guard` chỉ cho qua fact `reviewed`/`verified` hoặc tầng vàng "
            + "(CODE-04 bước 1). Duyệt chúng trước khi bảo tác tử sinh mã dựa vào đây.")
        m.font = EideToken.fontUI
        m.textColor = EideToken.Mau.warn
        m.wantsLayer = true
        m.drawsBackground = true
        m.backgroundColor = EideToken.Mau.warnBg
        them(m)
    }

    private func _bangCanhBao(_ xungDot: [[String: Any]]) {
        let ten = xungDot.prefix(3)
            .map { ($0["predicate"] as? String) ?? "?" }
            .joined(separator: ", ")
        let n = NSTextField(wrappingLabelWithString:
            "⚠ \(xungDot.count) ô mâu thuẫn (\(ten)\(xungDot.count > 3 ? "…" : "")) — hai nguồn "
            + "nói hai giá trị khác nhau và chưa ai quyết. Mở màn Xung đột tri thức (S8) để "
            + "chọn vế; tới lúc ấy ĐỪNG dùng các con số này làm hằng số phần cứng.")
        n.font = EideToken.fontUI
        n.textColor = EideToken.Mau.bad
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = EideToken.Mau.badBg
        them(n)
    }

    /// Khối "xem nguồn" — đường đi của `view.provenance`.
    ///
    /// UXC-31 đòi **chính ô Nguồn bấm được**. Bảng của gói này là MỘT `NSTextField` cho cả bảng
    /// (xem `EideManCoSo.bang` — hai bản trước dựng một khung nhìn mỗi ô và cả hai hỏng bố
    /// cục), nên một ô riêng lẻ chưa nhận được cú bấm. Chỗ bấm vì thế nằm ngay dưới bảng: chọn
    /// fact rồi mở chuỗi nguồn của nó. Dữ liệu đi đúng đường hợp đồng; thao tác thì còn một
    /// bước thừa, và đó là khoảng trống của khung bảng chứ không phải của năng lực.
    private func _khoiNguon(_ facts: [[String: Any]]) {
        factTheoNhan = [:]
        chonFact.removeAllItems()
        // Chỉ fact CÓ locator mới vào danh sách: mở nguồn của một fact không có vị trí là mở
        // một tệp rồi bỏ mặc người đọc tự tìm, tức đúng việc mà cột nguồn sinh ra để khỏi phải làm.
        for f in facts where f["locator"] != nil {
            guard let id = f["id"] as? String else { continue }
            let nhan = "\(Self.duoiCung((f["subject"] as? String) ?? "?"))"
                     + " · \((f["predicate"] as? String) ?? "?")"
            let duyNhat = factTheoNhan[nhan] == nil ? nhan : "\(nhan) [\(id.suffix(6))]"
            factTheoNhan[duyNhat] = id
            chonFact.addItem(withTitle: duyNhat)
        }
        guard chonFact.numberOfItems > 0 else { return }

        tieuDePhu("NGUỒN")
        let nut = NSButton(title: "Xem nguồn", target: self, action: #selector(_xemNguon))
        nut.bezelStyle = .rounded
        let hang = NSStackView(views: [chonFact, nut])
        hang.orientation = .horizontal
        hang.spacing = 8
        them(hang)

        them(cocNguon)
    }

    @objc private func _xemNguon() {
        guard let goi = goiLoi, let nhan = chonFact.titleOfSelectedItem,
              let fid = factTheoNhan[nhan] else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaCocNguon()
            do {
                let r = try await doc(goi, "view.provenance", ["fact_id": fid])
                hienChuoi((r["chain"] as? [[String: Any]]) ?? [])
            } catch {
                _themDongNguon("không đọc được chuỗi nguồn: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// Chuỗi `view.provenance` → các dòng đọc được. Tách khỏi phần gọi lõi để test đo được nó
    /// mà không cần daemon.
    public func hienChuoi(_ chain: [[String: Any]]) {
        // Tự gắn vào thân nếu chưa. Không có dòng này thì một chuỗi nguồn về SAU một lần nạp
        // lại — hoặc về cho một fact không nằm trong danh sách chọn — vẽ vào một khung nhìn
        // không có cha: đúng dữ liệu, đúng bố cục, và không một điểm ảnh nào trên màn hình.
        if cocNguon.superview == nil { them(cocNguon) }
        _xoaCocNguon()
        guard !chain.isEmpty else {
            return _themDongNguon("chuỗi rỗng — fact này không có nguồn nào",
                                  mau: EideToken.Mau.warn)
        }
        for (i, m) in chain.enumerated() {
            let ng = (m["source"] as? [String: Any]) ?? [:]
            let uri = (ng["uri"] as? String) ?? "?"
            // Mắt xích thứ hai trở đi là fact ĐÃ BỊ THAY. Nói rõ, vì cả điểm của việc trả cả
            // chuỗi là cho biết trước đây ta tin gì — thứ cần đến đúng lúc con số mới cũng sai.
            let dau = i == 0 ? "hiện hành" : "đã thay (\(i) bước trước)"
            _themDongNguon("\(dau) · \(Self.tenTep(uri)) · \(Self.viTri(m["locator"]))"
                           + ((m["method"] as? String).map { " · [\($0)]" } ?? "")
                           + ((m["confirmed_by"] as? String).map { " · người duyệt: \($0)" } ?? ""),
                           mau: i == 0 ? EideToken.Mau.text : EideToken.Mau.muted)
            if let s = m["snippet"] as? String, !s.isEmpty {
                _themDongNguon("    “\(s)”", mau: EideToken.Mau.muted)
            }
            if i == 0, let d = Self.duongTep(uri) {
                // Mở được TỆP, chưa mở được đúng TRANG: macOS không có đường mở PDF ở một trang
                // cho trước qua `NSWorkspace`. Số trang và bbox vì thế phải nằm ngay trên dòng
                // trên — người còn phải tự cuộn, nhưng không phải tự tìm.
                let b = NSButton(title: "Mở \(Self.tenTep(uri))", target: self,
                                 action: #selector(_moTep(_:)))
                b.bezelStyle = .inline
                b.identifier = NSUserInterfaceItemIdentifier(d.path)
                cocNguon.addArrangedSubview(b)
            }
        }
    }

    @objc private func _moTep(_ n: NSButton) {
        guard let p = n.identifier?.rawValue else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    private func _xoaCocNguon() {
        for v in cocNguon.arrangedSubviews {
            cocNguon.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    private func _themDongNguon(_ s: String, mau: NSColor) {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        cocNguon.addArrangedSubview(n)
    }

    // MARK: - định dạng (thuần, test đo thẳng)

    /// `st.stm32f411ce@1.2.0` → `st.stm32f411ce`.
    public static func boPhienBan(_ s: String) -> String {
        String(s.split(separator: "@").first ?? "")
    }

    /// Chủ thể bớt phần ai cũng biết. Mọi dòng của màn này đều thuộc cùng một chip, nên
    /// `chip:st.stm32f411ce/` lặp lại 300 lần chỉ để đẩy phần khác nhau ra khỏi bề rộng cột.
    public static func chuTheNgan(_ s: String, part: String) -> String {
        var t = s
        for tien in ["chip:\(part)/", "chip:\(part)", "chip:"] where t.hasPrefix(tien) {
            t = String(t.dropFirst(tien.count))
            break
        }
        return t.isEmpty ? "(chip)" : t
    }

    /// Đoạn cuối của một IRI — `…/reg:CR1` → `CR1`.
    public static func duoiCung(_ s: String) -> String {
        let cuoi = s.split(separator: "/").last.map(String.init) ?? s
        return cuoi.split(separator: ":").last.map(String.init) ?? cuoi
    }

    /// Giá trị theo VỊ TỪ — địa chỉ ra hệ 16, kích thước bộ nhớ ra KiB kèm số byte.
    ///
    /// `passport.query` trả `base_address: 1070055424`. Con số ấy đúng và vô dụng: không kỹ sư
    /// nhúng nào đọc địa chỉ thanh ghi ở hệ 10, và không ai đối chiếu được nó với `0x3FC7C000`
    /// in trong datasheet mà không lấy máy tính ra. Cả màn này tồn tại để ĐỐI CHIẾU — hiện sai
    /// hệ đếm là phá đúng việc ấy.
    public static func giaTriTheoViTu(_ v: Any?, _ viTu: String) -> String {
        let hex: Set<String> = ["base_address", "address", "offset", "reset_value", "mask"]
        if hex.contains(viTu), let n = nguyen(v) {
            // `%08X` cho địa chỉ 32 bit; offset nhỏ KHÔNG đệm tới 8 chữ số vì `0x00000004` đọc
            // chậm hơn `0x04` mà không thêm thông tin gì.
            return n > 0xFFFF ? String(format: "0x%08X", n) : String(format: "0x%02X", n)
        }
        if viTu == "memory_size", let n = nguyen(v), n >= 1024 {
            let kib = Double(n) / 1024
            let s = kib == kib.rounded() ? String(Int(kib)) : String(format: "%.1f", kib)
            return "\(s) KiB (\(n))"
        }
        return giaTri(v)
    }

    /// Giá trị JSON → chuỗi.
    ///
    /// **`0` và `1` KHÔNG phải `false` và `true`.** JSONSerialization trả mọi số về `NSNumber`,
    /// và trên Darwin `(0 as NSNumber) as? Bool` THÀNH CÔNG — nên một nhánh `case let b as Bool`
    /// đứng trước nhánh số sẽ nuốt mọi 0/1 trong dữ liệu. Đo 20/09 bằng ảnh chụp cửa sổ thật
    /// trên hộ chiếu ATmega328P: `bit_range` của `ACSR/field:ACIS` là `[0, 1]` — hai bit đầu —
    /// và màn in ra `[false, true]`. Không phép kiểm nào đỏ: giá trị vẫn là một mảng hai phần
    /// tử, vẫn đúng kiểu, chỉ là nó nói một điều khác hẳn điều datasheet nói.
    ///
    /// Phân biệt đúng phải hỏi CFBoolean, không hỏi `as? Bool`.
    public static func giaTri(_ v: Any?) -> String {
        switch v {
        case let s as String: return s
        case let n as NSNumber:
            return CFGetTypeID(n) == CFBooleanGetTypeID() ? (n.boolValue ? "true" : "false")
                                                          : n.stringValue
        case let b as Bool: return b ? "true" : "false"
        case let a as [Any]: return "[" + a.map { giaTri($0) }.joined(separator: ", ") + "]"
        case let o as [String: Any]: return "{\(o.count) khoá}"
        case .none: return "—"
        default: return "\(v!)"
        }
    }

    /// Nhãn (tầng, trạng thái) — và nó phải nói CẢ HAI khi cả hai còn nghĩa.
    ///
    /// Trạng thái thắng tầng khi nó **phủ định** fact: một fact `gold` đang `conflict` phải hiện
    /// là XUNG ĐỘT, không hiện là "vàng", vì hiện tầng ở đó là mời người ta tin một con số đang
    /// có hai giá trị.
    ///
    /// Nhưng `normalized` thì KHÔNG phủ định — và nuốt tầng ở đó là một lỗi đọc được bằng mắt.
    /// Đo 20/09 trên hộ chiếu ATmega328P: cả 287 fact đều `gold` + `normalized`, nên dòng tóm
    /// tắt nói "vàng 287" trong khi cả 287 hàng nói "chưa duyệt" — hai câu về cùng một thứ,
    /// mâu thuẫn nhau, trên cùng một màn. Tệ hơn: `code.constant_guard` CHO cả 287 cái đi qua
    /// (CODE-04 bước 1 — vàng thì qua kể cả khi chưa duyệt), nên cột ấy còn mâu thuẫn với cả
    /// hành vi thật của cổng. Hai mẩu tin ghép lại thì ba câu khớp nhau: `vàng · chưa duyệt`.
    public static func nhanTang(_ tier: String, _ status: String) -> String {
        switch status {
        case "conflict": return "⚠ XUNG ĐỘT"
        case "superseded": return "đã thay"
        case "rejected": return "đã loại"
        default: break
        }
        let t: String
        switch tier {
        case "gold": t = "vàng"
        case "silver": t = "bạc"
        case "bronze": t = "đồng"
        default: t = tier.isEmpty ? "—" : tier
        }
        return status == "normalized" ? "\(t) · chưa duyệt" : t
    }

    /// Luật của `code.constant_guard` (CODE-04 bước 1) chép đúng một lần, ở đây.
    ///
    /// Viết lại luật này bằng lời trong giao diện là tạo bản thứ hai của cùng một sự thật, và
    /// hai bản sẽ trôi khỏi nhau. Nó ở đây vì màn S5 là chỗ người quyết định có tin một con số
    /// hay không — chỗ ấy phải nói đúng câu mà cổng sẽ nói, không phải một câu gần giống.
    public static func quaDuocGuard(_ f: [String: Any]) -> Bool {
        let st = (f["status"] as? String) ?? ""
        return st == "reviewed" || st == "verified" || (f["tier"] as? String) == "gold"
    }

    /// `source_id` → `uri`. `citations` của PASSPORT-02 mang sẵn ánh xạ ấy, và lý do nó là một
    /// trường riêng chính là để bên gọi khỏi tự nối: `src_ee2e3dd3…` không nói gì với ai.
    public static func banDoNguon(_ cit: [[String: Any]]) -> [String: String] {
        var m: [String: String] = [:]
        for c in cit {
            if let id = c["source_id"] as? String { m[id] = (c["uri"] as? String) ?? id }
        }
        return m
    }

    /// Ô cột NGUỒN: tên tệp + vị trí trong tệp.
    public static func oNguon(_ f: [String: Any], uri: [String: String]) -> String {
        let sid = (f["source_id"] as? String) ?? ""
        let ten = uri[sid].map(tenTep) ?? (sid.isEmpty ? "—" : sid)
        let vt = viTri(f["locator"])
        return vt == "—" ? ten : "\(ten) · \(vt)"
    }

    public static func tenTep(_ uri: String) -> String {
        (uri as NSString).lastPathComponent
    }

    /// `locator` → `tr.42 [72,530,180,14]`.
    ///
    /// Số trang VÀ bbox, cả hai. Trang đưa người tới đúng chỗ trong tệp; bbox là thứ phân biệt
    /// "con số này đọc từ một ô trong bảng" với "con số này do mô hình đoán từ văn xuôi" — và
    /// đó là khác biệt quyết định có tin được hay không.
    public static func viTri(_ loc: Any?) -> String {
        guard let d = loc as? [String: Any] else {
            if let s = loc as? String, !s.isEmpty { return s }
            return "—"
        }
        var phan: [String] = []
        if let p = nguyen(d["page"]) { phan.append("tr.\(p)") }
        if let l = nguyen(d["line"]) { phan.append("d.\(l)") }
        if let b = d["bbox"] as? [Any], !b.isEmpty {
            phan.append("[" + b.map { nguyen($0).map(String.init) ?? "?" }.joined(separator: ",") + "]")
        }
        if phan.isEmpty, let s = d["path"] as? String { phan.append(s) }
        return phan.isEmpty ? "—" : phan.joined(separator: " ")
    }

    /// `uri` → đường tệp mở được, hoặc `nil`. Chỉ nhận tệp CÓ THẬT trên máy: một nút mở ra lỗi
    /// của Finder tệ hơn một nút không có.
    public static func duongTep(_ uri: String) -> URL? {
        let p = uri.hasPrefix("file://") ? String(uri.dropFirst(7)) : uri
        guard p.hasPrefix("/"), FileManager.default.fileExists(atPath: p) else { return nil }
        return URL(fileURLWithPath: p)
    }

    public static func nguyen(_ v: Any?) -> Int? {
        switch v {
        case let i as Int: return i
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }
}
