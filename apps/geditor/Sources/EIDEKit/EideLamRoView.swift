import AppKit

/// **Làm rõ yêu cầu** — UC-B2 (tác tử nói lại cách nó hiểu) và UC-B3 (hỏi gộp).
///
/// Spec: CDS-12.6 CHAT-05 `chat.restate` (`{intent, chain}` → `{text}`), CHAT-04 `chat.clarify`
/// (`{gaps}` → `{question, answer, by}`); DPS-09 §4.4; UXD-13 U1.
///
/// ## Vì sao đây phải là một MÀN, không phải một thẻ trong hội thoại
///
/// Bản cũ hiện cách-tác-tử-hiểu bằng một thẻ trôi trong dòng chat. Ba vấn đề, và cái thứ ba là
/// cái nặng:
///
/// 1. Thẻ **trôi mất** khi có thêm vài lượt — người quay lại không tìm được điều mình đã đồng ý.
/// 2. Câu hỏi gộp của `chat.clarify` có **phương án và mặc định**; một bong bóng chat không chỗ
///    nào đặt được bốn lựa chọn và một giá trị mặc định.
/// 3. **Đây là chỗ rẻ nhất để sửa một hiểu lầm.** Sửa ở đây tốn một câu; để tác tử chạy xong
///    rồi mới phát hiện nó hiểu sai thì tốn cả một lượt sinh mã, một lượt dựng, và niềm tin.
///
/// Nên: một màn, giữ nguyên trên màn hình tới khi người trả lời, có nút **Đúng — làm đi** và
/// **Sửa ý hiểu** đặt cạnh nhau ngang hàng. Không có nút nào là "mặc định" bị bấm nhầm.
public final class LamRoView: ManHinhCoSo {

    /// Người bấm "Đúng — làm đi": chạy chuỗi đúng như tác tử vừa mô tả.
    public var onDongY: (() -> Void)?

    /// Người bấm "Sửa ý hiểu": nạp lại câu vào ô lệnh để sửa, KHÔNG gửi.
    ///
    /// Nạp lại chứ không xoá trắng: người dùng sửa một chữ trong câu của mình, không gõ lại từ
    /// đầu. Đây là hành vi mà `RestateCard` đã có và phải giữ.
    public var onSuaYHieu: ((String) -> Void)?

    /// Người trả lời xong câu hỏi gộp → `{tên khoảng trống: giá trị}`.
    public var onTraLoi: (([String: String]) -> Void)?

    private var cauGoc = ""
    private var oTraLoi: [(khoa: String, o: NSView)] = []

    public init() {
        super.init(ten: "Làm rõ yêu cầu")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func capNhat(ketQua: [String: Any]) {
        xoaThan()
        oTraLoi.removeAll()

        // Ba nguồn dữ liệu, ba hợp đồng khác nhau — màn nhận cái nào có cái ấy, vì `chat.*` là
        // một chuỗi và người dùng có thể mở màn ở bất kỳ khâu nào của chuỗi.
        let daHieu = _hienYHieu(ketQua)
        let daHoi = _hienCauHoi(ketQua)
        let daYDinh = _hienYDinh(ketQua)

        if !daHieu && !daHoi && !daYDinh {
            noiRong("Chưa có gì cần làm rõ. Gõ một câu tiếng Việt ở ô lệnh — tác tử sẽ nói lại "
                    + "cách nó hiểu trước khi bắt tay làm.")
        }
    }

    // MARK: - Ba khối

    /// `chat.restate` → `{text}`. Câu tác tử nói lại cách nó hiểu.
    private func _hienYHieu(_ r: [String: Any]) -> Bool {
        guard let t = (r["text"] as? String) ?? (r["restated"] as? String), !t.isEmpty else {
            return false
        }
        cauGoc = (r["source_text"] as? String) ?? t
        themDong("Tôi hiểu là", t, mau: EideToken.Mau.info)

        // Chuỗi năng lực SẼ chạy — thứ người dùng cần nhất để biết mình đang đồng ý với cái gì.
        // Một câu "tôi hiểu là anh muốn đọc cảm biến" không nói cho ai biết rằng nó sắp tải
        // 35 MB tài liệu và ghi 8.000 fact vào dự án.
        if let ds = (r["chain"] as? [Any])?.compactMap({ ($0 as? [String: Any])?["cap"] as? String
                                                         ?? $0 as? String }), !ds.isEmpty {
            themDong("sẽ chạy \(ds.count) bước", ds.joined(separator: " → "))
        }
        _hienNutDongY()
        return true
    }

    private func _hienNutDongY() {
        let hang = NSStackView()
        hang.orientation = .horizontal
        hang.spacing = EideToken.space[2]

        let dongY = NSButton(title: "Đúng — làm đi", target: self, action: #selector(bamDongY))
        dongY.bezelStyle = .rounded
        // KHÔNG đặt `keyEquivalent = "\r"`. Đây là nút xác nhận một việc tác tử sắp làm thật; để
        // Enter bấm hộ là biến một cú gõ vô ý thành một lượt chạy.
        let sua = NSButton(title: "Sửa ý hiểu", target: self, action: #selector(bamSua))
        sua.bezelStyle = .rounded

        hang.addArrangedSubview(dongY)
        hang.addArrangedSubview(sua)
        cot.addArrangedSubview(hang)
    }

    /// `chat.clarify` → `{question, answer?, by?}`. Câu hỏi GỘP có phương án và mặc định.
    private func _hienCauHoi(_ r: [String: Any]) -> Bool {
        guard let q = r["question"] as? [String: Any] else { return false }

        if let t = q["text"] as? String, !t.isEmpty {
            themDong("Tác tử hỏi", t, mau: EideToken.Mau.warn)
        }
        // `gaps` là danh sách chỗ còn thiếu; mỗi chỗ có thể có `options` và `default`.
        let gaps = (q["gaps"] as? [Any])?.compactMap { $0 as? [String: Any] }
            ?? (q["items"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
        for g in gaps {
            let khoa = (g["key"] as? String) ?? (g["name"] as? String) ?? "?"
            let hoi = (g["question"] as? String) ?? (g["text"] as? String) ?? khoa
            let mac = (g["default"] as? String) ?? (g["default"].map { "\($0)" })
            let chon = (g["options"] as? [Any])?.compactMap { $0 as? String } ?? []
            cot.addArrangedSubview(_oCho(khoa: khoa, hoi: hoi, chon: chon, mac: mac))
        }
        if !gaps.isEmpty {
            let g = NSButton(title: "Trả lời", target: self, action: #selector(bamTraLoi))
            g.bezelStyle = .rounded
            cot.addArrangedSubview(g)
        }
        // Câu hỏi đã có câu trả lời rồi (người vừa trả lời, hoặc hết giờ lấy mặc định) — nói ra
        // AI trả lời, vì "hết giờ" và "người chọn" là hai chuyện rất khác nhau khi truy lại sau.
        if let a = r["answer"] as? [String: Any], !a.isEmpty {
            let boi = (r["by"] as? String) == "timeout" ? "hết giờ — lấy mặc định" : "người trả lời"
            themDong("đã trả lời (\(boi))",
                     a.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " · "),
                     mau: EideToken.Mau.ok)
        }
        return true
    }

    /// `chat.parse_intent` → `{intent}`. Hiện khi chưa tới bước nói lại.
    private func _hienYDinh(_ r: [String: Any]) -> Bool {
        guard let i = r["intent"] as? [String: Any], !i.isEmpty else { return false }
        themDong("ý định", (i["name"] as? String) ?? (i["kind"] as? String) ?? "(chưa rõ)")
        if let t = i["text"] as? String { cauGoc = t }
        for (k, v) in i.sorted(by: { $0.key < $1.key }) where k != "name" && k != "kind" {
            themDong("  \(k)", "\(v)")
        }
        // Chưa có `chat.restate` thì CHƯA hiện nút đồng ý: người không thể đồng ý với một thứ
        // chưa được nói thành câu.
        noiRong("Tác tử chưa nói lại cách nó hiểu — chờ `chat.restate`.")
        return true
    }

    private func _oCho(khoa: String, hoi: String, chon: [String], mac: String?) -> NSView {
        let hang = NSStackView()
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[1]

        let nhan = NSTextField(labelWithString: hoi)
        nhan.font = EideToken.fontUI
        nhan.textColor = EideToken.Mau.text
        hang.addArrangedSubview(nhan)

        let o: NSView
        if chon.isEmpty {
            let t = NSTextField()
            t.stringValue = mac ?? ""
            t.placeholderString = mac.map { "mặc định: \($0)" } ?? ""
            t.widthAnchor.constraint(equalToConstant: 240).isActive = true
            o = t
        } else {
            let p = NSPopUpButton()
            p.addItems(withTitles: chon)
            // Chọn sẵn MẶC ĐỊNH nếu nó nằm trong danh sách — nhưng chỉ khi nằm trong danh sách.
            // Chọn bừa mục đầu rồi gọi đó là mặc định là bịa ra một lựa chọn hợp đồng không nói.
            if let mac, let i = chon.firstIndex(of: mac) { p.selectItem(at: i) }
            o = p
        }
        o.setAccessibilityLabel(hoi)
        hang.addArrangedSubview(o)
        oTraLoi.append((khoa, o))
        return hang
    }

    // MARK: - Nút

    @objc private func bamDongY() { onDongY?() }

    @objc private func bamSua() { onSuaYHieu?(cauGoc) }

    @objc private func bamTraLoi() {
        var ra: [String: String] = [:]
        for t in oTraLoi {
            if let o = t.o as? NSTextField {
                let v = o.stringValue.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { ra[t.khoa] = v }
            } else if let p = t.o as? NSPopUpButton, let v = p.titleOfSelectedItem {
                ra[t.khoa] = v
            }
        }
        onTraLoi?(ra)
    }

    /// Số ô trả lời đang hiện — để test.
    public var soOTraLoi: Int { oTraLoi.count }

    /// Bấm "Sửa ý hiểu" bằng mã — cho test và cho phím tắt về sau.
    public func bamSuaDeTest() { bamSua() }

    /// Câu trả lời hiện đang điền trong các ô — cho test và để lưu nháp về sau.
    public func dapDeTest() -> [String: String] {
        var ra: [String: String] = [:]
        for t in oTraLoi {
            if let o = t.o as? NSTextField {
                let v = o.stringValue.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { ra[t.khoa] = v }
            } else if let p = t.o as? NSPopUpButton, let v = p.titleOfSelectedItem {
                ra[t.khoa] = v
            }
        }
        return ra
    }
}
