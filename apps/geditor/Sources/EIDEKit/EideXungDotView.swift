import AppKit

/// **Xung đột tri thức** — UC-C9. `kg.conflicts` → `{conflicts[], resource_ready}`,
/// `kg.resolve_conflict` → `{current}`.
///
/// Spec: CDS-12.4 KG-02, KG-06 (tier **T2**, `actor` bắt buộc); KAD-07 §5.1 bảng gộp.
///
/// ## Vì sao xung đột phải là màn riêng, và vì sao nó là màn của NGƯỜI
///
/// `kg.resolve_conflict` là T2 với `ask_when: "khi người chọn"` — tức hợp đồng nói thẳng rằng
/// việc này không thuộc về tác tử. Lý do không phải sự thận trọng chung: một xung đột fact
/// nghĩa là **hai nguồn hãng nói hai điều khác nhau về cùng một con chip**, và chọn sai bên thì
/// mọi thứ dựng trên đó — mã, mô phỏng, ngân sách bộ nhớ — đều sai theo, im lặng.
///
/// Trước 14/09/2026, `kg.conflicts` **không gắn màn nào** (`EidePanel.noUI`): xung đột được đếm
/// trong bản đồ tri thức rồi thôi. Người dùng biết có 3 xung đột và không có đường nào để xem
/// chúng là gì.
///
/// ## Hai cột song song, không phải một danh sách
///
/// Bên A và bên B phải đặt cạnh nhau **cùng hàng**, mỗi bên kèm nguồn và tầng. Xếp dọc thành
/// một danh sách thì người đọc phải nhớ bên trên nói gì trong lúc đọc bên dưới — và đó là lúc
/// người ta chọn theo cái vừa đọc thay vì theo cái đúng.
public final class XungDotView: ManHinhCoSo {

    /// Người chọn một bên: `(conflict_id, "a" | "b" | "both_conditional", điều kiện)`.
    public var onChon: ((String, String, String?) -> Void)?

    private var dangCho: [String] = []

    public init() {
        super.init(ten: "Xung đột tri thức")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        dangCho.removeAll()

        // `kg.resolve_conflict` trả `{current}` — giá trị hiện hành SAU khi giải. Người vừa bấm
        // "Chọn A" mà màn không đổi gì thì họ không biết cú bấm có ăn không, và sẽ bấm lại.
        if let cur = ketQua["current"] as? String, !cur.isEmpty {
            themDong("đã giải — giá trị hiện hành", cur, mau: EideToken.Mau.ok)
            noiRong("Fact bên kia được đánh dấu `superseded`, KHÔNG xoá: KAD-07 §6.7 giữ cả hai "
                    + "để về sau còn truy được vì sao đã chọn thế. Mở lại màn để xem danh sách "
                    + "xung đột còn lại.")
            return
        }

        let ds = (ketQua["conflicts"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
        // `resource_ready: false` nghĩa là xung đột TÀI NGUYÊN (chân, ngoại vi dùng chung) chưa
        // kiểm được — thiếu hộ chiếu mạch. Nói ra, vì "0 xung đột" khi chưa kiểm được là câu
        // nói dối nguy hiểm nhất màn này có thể nói.
        if (ketQua["resource_ready"] as? Bool) == false {
            noiRong("Chưa kiểm được xung đột TÀI NGUYÊN (chân, ngoại vi dùng chung) — "
                    + "cần hộ chiếu mạch. Danh sách dưới chỉ gồm xung đột FACT.")
        }
        if ds.isEmpty {
            noiRong("Không có xung đột nào. Hai nguồn trở lên nói cùng một điều về mỗi fact.")
            return
        }
        tomTat.stringValue = "\(ds.count) xung đột — mỗi cái cần anh chọn một bên"
        for c in ds { _hienMot(c) }
    }

    private func _hienMot(_ c: [String: Any]) {
        let id = (c["id"] as? String) ?? (c["conflict_id"] as? String) ?? "?"
        let loai = (c["type"] as? String) ?? "fact"
        dangCho.append(id)

        themDong(loai == "resource" ? "xung đột TÀI NGUYÊN" : "xung đột FACT",
                 (c["detail"] as? String) ?? (c["subject"] as? String) ?? id,
                 mau: EideToken.Mau.bad)

        // `nodes` là hai (hoặc hơn) fact mâu thuẫn. Hợp đồng KG-02 mô tả `nodes[]`; bản ghi có
        // thể là id trần hoặc object đầy đủ, nên đọc được cả hai.
        let nodes = (c["nodes"] as? [Any]) ?? []
        let hai = nodes.prefix(2).map { n -> [String: Any] in
            (n as? [String: Any]) ?? ["id": "\(n)"]
        }
        let hang = NSStackView()
        hang.orientation = .horizontal
        hang.alignment = .top
        hang.distribution = .fillEqually
        hang.spacing = EideToken.space[2]
        for (i, n) in hai.enumerated() {
            hang.addArrangedSubview(_cot(ben: i == 0 ? "A" : "B", n))
        }
        cot.addArrangedSubview(hang)
        cot.addArrangedSubview(_nut(id: id, co2Ben: hai.count >= 2))
    }

    /// Một bên của xung đột: giá trị, nguồn, tầng, độ tin.
    ///
    /// **Nguồn và tầng phải hiện cùng giá trị**, không giấu sau một cú bấm. Người chọn giữa
    /// `0x40005400` và `0x40005800` mà không biết cái nào đến từ SVD hãng, cái nào từ một bảng
    /// PDF quét, thì họ đang tung đồng xu.
    private func _cot(ben: String, _ n: [String: Any]) -> NSView {
        let c = NSStackView()
        c.orientation = .vertical
        c.alignment = .leading
        c.spacing = 2

        let t = NSTextField(labelWithString: "Bên \(ben)")
        t.font = NSFont.boldSystemFont(ofSize: 11)
        t.textColor = EideToken.Mau.text
        c.addArrangedSubview(t)

        // Thứ tự là thứ tự NGƯỜI ĐỌC cần, không phải thứ tự cột SQL: giá trị trước (thứ đang
        // cãi nhau), rồi nguồn (thứ quyết định tin bên nào), rồi phần còn lại. `source_uri` đặt
        // TRÊN `source_id` vì `src_ee2e3dd3…` không nói gì với ai, còn tên tệp thì nói hết.
        for (nhan, khoa) in [("giá trị", "value"), ("đơn vị", "unit"),
                             ("chủ thể", "subject"), ("vị từ", "predicate"),
                             ("nguồn", "source_uri"), ("loại nguồn", "source_kind"),
                             ("mã nguồn", "source_id"),
                             ("tầng", "tier"), ("độ tin", "confidence"),
                             ("cách trích", "method"), ("trạng thái", "status"),
                             ("trang", "locator")] {
            guard let v = n[khoa], !"\(v)".isEmpty, "\(v)" != "<null>" else { continue }
            // Nguồn là một đường dẫn dài, và phần đáng đọc nằm ở CUỐI. Cắt đuôi theo lệ thường
            // sẽ giấu đúng tên tệp — thứ duy nhất phân biệt "TRM v1.1" với "datasheet rev 0.4".
            // Hiện tên tệp, giữ cả đường dẫn trong tooltip.
            let hien = khoa == "source_uri" ? ("\(v)" as NSString).lastPathComponent : "\(v)"
            let l = NSTextField(labelWithString: "\(nhan): \(hien)")
            l.font = khoa == "value" ? EideToken.fontMono : EideToken.fontUI
            l.textColor = khoa == "tier" ? EideMuc.mau("\(v)") : EideToken.Mau.muted
            l.lineBreakMode = .byTruncatingMiddle
            if khoa == "source_uri" { l.toolTip = "\(v)" }
            c.addArrangedSubview(l)
        }
        return c
    }

    private func _nut(id: String, co2Ben: Bool) -> NSView {
        let hang = NSStackView()
        hang.orientation = .horizontal
        hang.spacing = EideToken.space[1]
        for (nhan, ma) in [("Chọn A", "a"), ("Chọn B", "b")] {
            let b = NSButton(title: nhan, target: self, action: #selector(bamChon(_:)))
            b.bezelStyle = .rounded
            b.identifier = .init("\(id)|\(ma)")
            b.isEnabled = co2Ben
            hang.addArrangedSubview(b)
        }
        // "Cả hai, có điều kiện" là lựa chọn THỨ BA mà hợp đồng khai (`both_conditional`), và nó
        // là lựa chọn đúng trong một trường hợp rất thật: hai giá trị đều đúng, cho hai phiên
        // bản silicon khác nhau. Bỏ nó đi là ép người dùng khai sai một trong hai.
        let ca = NSButton(title: "Cả hai — có điều kiện…", target: self,
                          action: #selector(bamCaHai(_:)))
        ca.bezelStyle = .rounded
        ca.identifier = .init(id)
        ca.isEnabled = co2Ben
        hang.addArrangedSubview(ca)
        return hang
    }

    @objc private func bamChon(_ s: NSButton) {
        let p = (s.identifier?.rawValue ?? "").split(separator: "|", maxSplits: 1)
        guard p.count == 2 else { return }
        onChon?(String(p[0]), String(p[1]), nil)
    }

    @objc private func bamCaHai(_ s: NSButton) {
        guard let id = s.identifier?.rawValue else { return }
        let a = NSAlert()
        a.messageText = "Cả hai đúng — trong điều kiện nào?"
        a.informativeText = "Ví dụ: \"bên A đúng cho chip revision v1.1, bên B cho v0.4\". "
            + "Điều kiện này đi vào hộ chiếu cùng cả hai fact."
        let o = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        a.accessoryView = o
        a.addButton(withTitle: "Ghi")
        a.addButton(withTitle: "Huỷ")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let dk = o.stringValue.trimmingCharacters(in: .whitespaces)
        guard !dk.isEmpty else {
            // Không điều kiện thì "cả hai" là vô nghĩa: hộ chiếu sẽ có hai giá trị cho cùng một
            // fact và không gì phân biệt được chúng.
            let b = NSAlert()
            b.messageText = "Cần một điều kiện"
            b.informativeText = "Không có điều kiện thì hai fact mâu thuẫn vẫn mâu thuẫn."
            b.runModal()
            return
        }
        onChon?(id, "both_conditional", dk)
    }

    /// Số xung đột đang chờ người quyết — để test và để điều hướng hiện con số.
    public var soXungDot: Int { dangCho.count }

    /// Bấm "Chọn A/B" bằng mã — cho test.
    public func bamChonDeTest(id: String, ben: String) { onChon?(id, ben, nil) }

    /// Nút Chọn có bấm được không — một xung đột chỉ có một bên thì không có gì để chọn giữa.
    public func nutChonBatDeTest() -> Bool {
        func quet(_ v: NSView) -> Bool {
            if let b = v as? NSButton, b.title.hasPrefix("Chọn"), b.isEnabled { return true }
            return v.subviews.contains { quet($0) }
        }
        return quet(cot)
    }
}
