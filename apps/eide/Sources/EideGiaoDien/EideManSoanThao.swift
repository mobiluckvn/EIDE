import AppKit
import EideLoi

/// **S14 — Trình soạn thảo.** UXC-31 mục 5 trọn vẹn; `code.constant_guard` (CODE-04),
/// `code.human_save` (CODE-17).
///
/// ## "Nơi người và tác tử gặp nhau"
///
/// Đó là tiêu đề mục 5, và nó là mô tả đúng chứ không phải lời hoa mỹ: đây là màn duy nhất mà
/// cả hai cùng ghi vào một tệp. Mọi thứ khó ở đây đều rơi ra từ điều ấy — buffer bẩn, tệp đổi
/// trên đĩa, tác tử đang sửa tệp người đang xem.
///
/// ## Đọc từ ĐĨA, ghi qua CỔNG
///
/// Không RPC nào đọc mã nguồn, và đó là chủ ý: `code.human_save` nhận `base_content`, tức hợp
/// đồng CODE-17 giả định bên gọi đã tự đọc tệp. Trình soạn thảo đọc đĩa như mọi trình soạn
/// thảo; thứ đi qua cổng là lần GHI. Chia thế mới đúng: đọc một tệp không phải hành động cần
/// chính sách, còn ghi thì có — và P-EDIT-02 cho `code.human_save` APPROVE ở mọi mức tự chủ
/// chính vì người đang ngồi đó bấm nút.
public final class EideManSoanThao: EideManCoSo {

    public override class var tien: String { "Code" }

    /// Đuôi tệp mã mà màn này mở. Giới hạn có chủ ý: mở một tệp nhị phân 40 MB vào `NSTextView`
    /// là treo cửa sổ, và `code.constant_guard` cũng chỉ quét đúng nhóm đuôi này.
    public static let DUOI = ["c", "h", "cpp", "hpp", "cc", "py", "s", "ld"]

    /// Trần kích thước tệp. Trên ngưỡng này thì nói ra chứ không mở rồi treo.
    public static let TRAN_BYTE = 2 * 1024 * 1024

    private var goiLoi: EideGoi?
    private var goc = ""            // nội dung lúc mở — `base_content` của CODE-17
    private var duong = ""
    private let chonTep = NSPopUpButton()
    private let soanThao = NSTextView()
    private let le = EideLeSoanThao()
    private let cocBang = NSStackView()
    private var thuMuc: String?

    /// Đường dẫn tệp đang mở — cho `--tu-kiem` và bài đo.
    public var dangMo: String { duong }

    public override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        goiLoi = goi
        cocBang.orientation = .vertical
        cocBang.alignment = .leading
        cocBang.spacing = 4

        let bc = try await nangLuc(goi, "project.status")
        thuMuc = (bc["report"] as? [String: Any])?["path"] as? String
            ?? (bc["report"] as? [String: Any])?["project_dir"] as? String

        let ds = Self.quetTep(thuMuc)
        guard !ds.isEmpty else {
            return rong(vi: thuMuc == nil
                            ? "chưa biết thư mục dự án — `project.status` không trả `path`"
                            : "không tìm thấy tệp mã nào trong dự án",
                        buocKe: "bảo tác tử sinh mã (`code.generate_module`), hoặc thêm tệp "
                              + "`.c`/`.h` vào thư mục dự án rồi mở lại màn")
        }

        _dungThanhTep(ds)
        them(cocBang)
        _dungSoanThao()
        await moTep(goi, ds[0])
    }

    // MARK: - mở tệp

    /// Quét tệp mã trong thư mục dự án. Đọc ĐĨA, không qua RPC — xem docstring của lớp.
    public static func quetTep(_ goc: String?) -> [String] {
        guard let goc, let it = FileManager.default.enumerator(atPath: goc) else { return [] }
        var ra: [String] = []
        for x in it {
            guard let p = x as? String else { continue }
            // Bỏ `.eide/`, `.git/`, `.build/`: chúng đầy tệp sinh ra, và một danh sách 4000 mục
            // thì không ai chọn được gì trong đó.
            if p.hasPrefix(".") || p.contains("/.") || p.contains(".build/") { continue }
            if DUOI.contains((p as NSString).pathExtension.lowercased()) { ra.append(p) }
            if ra.count >= 500 { break }
        }
        return ra.sorted()
    }

    public func moTep(_ goi: @escaping EideGoi, _ tuongDoi: String) async {
        guard let thuMuc else { return }
        let day = (thuMuc as NSString).appendingPathComponent(tuongDoi)
        let co = (try? FileManager.default.attributesOfItem(atPath: day)[.size] as? Int) ?? 0
        guard (co ?? 0) <= Self.TRAN_BYTE else {
            return _bang("Tệp \(tuongDoi) lớn \((co ?? 0) / 1024) KB — vượt trần "
                         + "\(Self.TRAN_BYTE / 1024) KB của trình soạn thảo. Mở bằng trình khác.",
                         mau: EideToken.Mau.warn)
        }
        guard let noi = try? String(contentsOfFile: day, encoding: .utf8) else {
            return _bang("Không đọc được \(tuongDoi) dưới dạng UTF-8.", mau: EideToken.Mau.bad)
        }
        duong = day
        goc = noi
        soanThao.string = noi
        _xoaBang()
        await capNhatLe(goi)
    }

    // MARK: - lề (§5.1, §5.2)

    /// Dựng lề từ `code.constant_guard`.
    ///
    /// §5.1 đòi hai dấu khác nhau, và khác biệt giữa chúng là toàn bộ luận điểm của sản phẩm:
    /// **● xanh** = hằng số này trỏ về một fact đã duyệt; **▎đỏ** = hằng số phần cứng không có
    /// nguồn, và `G-FACT` sẽ chặn merge. Một trình soạn thảo bình thường không phân biệt nổi
    /// hai dòng ấy — nó chỉ thấy hai con số.
    public func capNhatLe(_ goi: @escaping EideGoi) async {
        guard !duong.isEmpty else { return }
        let patch: [String: Any] = ["files": [["path": duong, "content": soanThao.string]]]
        guard let r = try? await nangLuc(goi, "code.constant_guard", ["patch": patch]) else {
            return
        }
        let vp = (r["violations"] as? [[String: Any]]) ?? []
        le.dat(khongNguon: Set(vp.compactMap { EideManHoChieu.nguyen($0["line"]) }),
               coFact: Self.dongCoFact(soanThao.string))
        _xoaBang()
        if !vp.isEmpty {
            _bang("▎ \(vp.count) hằng số phần cứng KHÔNG trỏ fact — `G-FACT` sẽ chặn merge. "
                  + (vp.first.flatMap { $0["reason"] as? String } ?? ""),
                  mau: EideToken.Mau.bad)
        }
    }

    /// Dòng có chú thích `eide:fact` — quy ước PRS-16 §3.
    public static func dongCoFact(_ van: String) -> Set<Int> {
        var ra: Set<Int> = []
        for (i, d) in van.components(separatedBy: "\n").enumerated() where d.contains("eide:fact") {
            ra.insert(i + 1)
        }
        return ra
    }

    // MARK: - lưu (§5.3, §5.4, §5.5)

    /// Buffer bẩn — §5.3.
    public var ban: Bool { !duong.isEmpty && soanThao.string != goc }

    @objc private func _luu() {
        guard let goi = goiLoi, ban else { return }
        Task { [weak self] in
            guard let self else { return }
            _xoaBang()
            do {
                let r = try await nangLuc(goi, "code.human_save", [
                    "path": duong, "content": soanThao.string,
                    // `base_content` là nội dung LÚC MỞ, không phải nội dung trên đĩa bây giờ.
                    // Đó là cả cơ chế phát hiện E6004: lõi so nó với đĩa, và lệch nghĩa là ai
                    // đó đã ghi trong lúc ta gõ.
                    "base_content": goc, "by": EideManXungDot.nguoi(),
                ])
                goc = soanThao.string
                _bang("Đã lưu — commit \(((r["commit"] as? String) ?? "?").prefix(10))"
                      + ", seq \(EideManHoChieu.nguyen(r["seq"]) ?? 0). Mục hoàn tác đã vào cột "
                      + "phải.", mau: EideToken.Mau.ok)
                await capNhatLe(goi)
            } catch let e as EideKetQua.Loi where e.maEide == "E6004" {
                // §5.5: "TUYỆT ĐỐI không ghi đè (B4)". Màn KHÔNG có nút "ghi đè" — không phải
                // vì quên, mà vì một nút như thế biến cả cơ chế merge ba bên thành tuỳ chọn.
                _bang("⛔ Tệp đã đổi trên đĩa từ lúc anh mở — KHÔNG ghi đè. Bản của anh vẫn "
                      + "nguyên trong bộ đệm. Mở màn Diff & cổng merge (S15) để hợp nhất ba bên.",
                      mau: EideToken.Mau.bad)
            } catch {
                _bang("Không lưu được: \(error)", mau: EideToken.Mau.bad)
            }
        }
    }

    /// §5.6 — tác tử đang sửa tệp người đang xem.
    ///
    /// Băng XANH chứ không vàng, và người vẫn gõ được: đây là thông báo, không phải cảnh báo.
    /// Chặn bàn phím ở đây sẽ biến một lượt chạy nền thành một lần khoá màn hình.
    public override func apDung(_ ten: String, _ p: [String: Any]) -> Bool {
        guard ten == "event.run.progress",
              let tep = (p["path"] as? String) ?? (p["file"] as? String),
              !duong.isEmpty, duong.hasSuffix(tep) || tep.hasSuffix(duong) else { return false }
        let i = EideManHoChieu.nguyen(p["i"]) ?? 0
        let n = EideManHoChieu.nguyen(p["of"]) ?? 0
        _bang("🤖 Tác tử đang sửa tệp này (Run \(((p["run_id"] as? String) ?? "?").prefix(8))"
              + (n > 0 ? ", bước \(i)/\(n)" : "") + ") — anh vẫn gõ được.",
              mau: EideToken.Mau.info)
        return true
    }

    // MARK: - dựng khung nhìn

    private func _dungThanhTep(_ ds: [String]) {
        chonTep.removeAllItems()
        chonTep.addItems(withTitles: ds)
        chonTep.target = self
        chonTep.action = #selector(_doiTep)
        let luu = NSButton(title: "Lưu", target: self, action: #selector(_luu))
        luu.bezelStyle = .rounded
        luu.keyEquivalent = "s"
        luu.keyEquivalentModifierMask = [.command]
        let h = NSStackView(views: [chonTep, luu])
        h.orientation = .horizontal
        h.spacing = 8
        them(h)
    }

    @objc private func _doiTep() {
        guard let goi = goiLoi, let t = chonTep.titleOfSelectedItem else { return }
        // Buffer bẩn mà đổi tệp là mất việc của người — hỏi trước, và mặc định là GIỮ.
        if ban {
            let a = NSAlert()
            a.messageText = "Bộ đệm có sửa chưa lưu"
            a.informativeText = "Đổi sang `\(t)` sẽ bỏ phần anh vừa gõ trong `"
                              + "\((duong as NSString).lastPathComponent)`."
            a.addButton(withTitle: "Ở lại")
            a.addButton(withTitle: "Bỏ và đổi")
            guard a.runModal() == .alertSecondButtonReturn else { return }
        }
        Task { [weak self] in await self?.moTep(goi, t) }
    }

    private func _dungSoanThao() {
        soanThao.isRichText = false
        soanThao.font = EideToken.fontMono
        soanThao.isAutomaticQuoteSubstitutionEnabled = false
        soanThao.delegate = le
        le.onGo = { [weak self] in self?._goPhim() }

        let cuon = NSScrollView()
        cuon.documentView = soanThao
        cuon.hasVerticalScroller = true
        cuon.hasHorizontalRuler = false
        cuon.rulersVisible = true
        cuon.hasVerticalRuler = true
        le.scrollView = cuon
        cuon.verticalRulerView = le
        cuon.translatesAutoresizingMaskIntoConstraints = false
        cuon.heightAnchor.constraint(equalToConstant: 420).isActive = true
        them(cuon)
    }

    /// §5.3 — buffer bẩn thì băng vàng, và câu ấy nói đúng điều sẽ xảy ra với tác tử.
    private func _goPhim() {
        onNguoiGo?()
        guard ban else { return _xoaBang() }
        if cocBang.arrangedSubviews.contains(where: {
            (($0 as? NSTextField)?.stringValue ?? "").contains("CHƯA LƯU")
        }) { return }
        _xoaBang()
        _bang("Bộ đệm có sửa CHƯA LƯU của anh — tác tử muốn ghi tệp này sẽ bị hỏi (P-EDIT-01).",
              mau: EideToken.Mau.warn)
    }

    private func _bang(_ s: String, mau: NSColor) {
        let n = NSTextField(wrappingLabelWithString: s)
        n.font = EideToken.fontUI
        n.textColor = mau
        n.wantsLayer = true
        n.drawsBackground = true
        n.backgroundColor = mau == EideToken.Mau.bad ? EideToken.Mau.badBg
                          : (mau == EideToken.Mau.ok ? EideToken.Mau.okBg
                          : (mau == EideToken.Mau.info ? EideToken.Mau.infoBg
                                                       : EideToken.Mau.warnBg))
        cocBang.addArrangedSubview(n)
    }

    private func _xoaBang() {
        for v in cocBang.arrangedSubviews { cocBang.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    // MARK: - cho bài đo

    public func datNoiDungDeTest(_ s: String) {
        soanThao.string = s
        _goPhim()
    }

    /// Giả lập một tệp ĐANG MỞ. Đặt `goc` mà không đặt `duong` là dựng một trạng thái không
    /// có thật — `ban` đòi cả hai, vì "bộ đệm bẩn" chỉ có nghĩa khi có một tệp để bẩn.
    public func moTepDeTest(_ duongDan: String, _ noiDung: String) {
        duong = duongDan
        goc = noiDung
        soanThao.string = noiDung
    }
    public var chuBang: String {
        cocBang.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " | ")
    }
    public var leDeTest: EideLeSoanThao { le }
}

/// **Lề trái của trình soạn thảo** — §5.1.
///
/// Một `NSRulerView` chứ không phải một cột nhãn bên cạnh: lề phải cuộn CÙNG văn bản và phải
/// biết dòng nào đang ở đâu sau khi chữ gấp dòng. Dựng bằng hai khung nhìn song song thì chúng
/// lệch nhau ngay ở tệp đầu tiên có dòng dài.
@MainActor
public final class EideLeSoanThao: NSRulerView, NSTextViewDelegate {

    public var onGo: (() -> Void)?
    private(set) var khongNguon: Set<Int> = []
    private(set) var coFact: Set<Int> = []

    public func dat(khongNguon a: Set<Int>, coFact b: Set<Int>) {
        khongNguon = a
        coFact = b
        needsDisplay = true
    }

    public override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        ruleThickness = 26
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) { fatalError() }

    public func textDidChange(_ notification: Notification) {
        needsDisplay = true
        onGo?()
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = clientView as? NSTextView, let lm = tv.layoutManager,
              let tc = tv.textContainer else { return }
        let van = tv.string as NSString
        let hien = lm.glyphRange(forBoundingRect: scrollView?.contentView.bounds ?? .zero,
                                 in: tc)
        var dong = 1
        var vt = 0
        while vt < van.length {
            let r = van.lineRange(for: NSRange(location: vt, length: 0))
            if NSLocationInRange(r.location, hien) || NSIntersectionRange(r, hien).length > 0 {
                let g = lm.glyphRange(forCharacterRange: r, actualCharacterRange: nil)
                var o = lm.boundingRect(forGlyphRange: g, in: tc)
                o.origin.y += tv.textContainerInset.height - (scrollView?.contentView.bounds.origin.y ?? 0)
                _ve(dong: dong, y: o.minY, cao: o.height)
            }
            vt = NSMaxRange(r)
            dong += 1
        }
    }

    private func _ve(dong: Int, y: CGFloat, cao: CGFloat) {
        if khongNguon.contains(dong) {
            // ▎ĐỎ — hằng số phần cứng không nguồn. Vẽ một VẠCH chứ không một chấm: nó phải
            // khác chấm xanh cả về hình lẫn về màu, vì bản in đen trắng và mắt mù màu vẫn phải
            // phân biệt được hai trạng thái trái ngược nhau.
            EideToken.Mau.bad.setFill()
            NSRect(x: 6, y: y + 2, width: 3, height: max(4, cao - 4)).fill()
        } else if coFact.contains(dong) {
            EideToken.Mau.ok.setFill()
            NSBezierPath(ovalIn: NSRect(x: 8, y: y + cao / 2 - 3, width: 6, height: 6)).fill()
        }
    }
}
