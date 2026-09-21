import AppKit
import EideLoi

/// **Form tham số sinh từ hợp đồng** — UXC-31 §4.4.
///
/// Năng lực có tham số BẮT BUỘC thì bảng lệnh không được gọi thẳng. Trước form này, chọn
/// `passport.query` từ ⌘K sẽ gọi với `{}` và nhận E1000 INPUT_SCHEMA — một mã lỗi đúng, đọc
/// xong vẫn không biết phải điền gì.
///
/// ## Sinh từ `caps.describe`, không từ một bảng chép tay
///
/// 244 năng lực thì một bảng chép tay sẽ lệch ngay ở lần sửa hợp đồng đầu tiên, và lệch im
/// lặng: form vẫn hiện, vẫn cho bấm, chỉ là hỏi sai thứ. `input_schema` trong `cds.json` là
/// nguồn duy nhất, và nó đã ở đúng dạng máy đọc được.
///
/// ## Vì sao KHÔNG tự điền giá trị "hợp lý"
///
/// Cùng lý do `goiNangLuc` không đoán tham số: nhiều năng lực trong số này ghi tệp, nạp firmware
/// hoặc gọi mô hình mất tiền. Một giá trị mặc định tôi nghĩ ra trông y hệt một giá trị người
/// dùng chọn — cho tới lúc nó ghi nhầm chỗ.
@MainActor
public final class EideFormThamSo: NSView {

    /// Người bấm Chạy, kèm tham số đã điền.
    public var onChay: ((String, [String: Any]) -> Void)?

    /// Một ô của form, dựng từ một thuộc tính của `input_schema`.
    struct O {
        let ten: String
        let loai: String
        let batBuoc: Bool
        let enumDs: [String]
        let mota: String
        let khungNhin: NSView
    }

    private let tieuDe = NSTextField(labelWithString: "")
    private let coc = NSStackView()
    private let nutChay = NSButton()
    private let nhanThieu = NSTextField(labelWithString: "")
    private var capId = ""
    private var o: [O] = []

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Nền mờ phủ toàn khung, hộp trắng ở giữa — cùng hình dạng với bảng lệnh, vì người dùng
        // vừa từ bảng lệnh sang đây và không nên phải học một lớp phủ thứ hai.
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        isHidden = true

        tieuDe.font = NSFont.boldSystemFont(ofSize: 14)
        nhanThieu.font = EideToken.fontUI
        nhanThieu.textColor = EideToken.Mau.warn

        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 8

        nutChay.title = "Chạy"
        nutChay.bezelStyle = .rounded
        nutChay.keyEquivalent = "\r"
        nutChay.target = self
        nutChay.action = #selector(_chay)
        let huy = NSButton(title: "Huỷ", target: self, action: #selector(_huy))
        huy.bezelStyle = .inline
        let hangNut = NSStackView(views: [nutChay, huy])
        hangNut.orientation = .horizontal
        hangNut.spacing = 8

        let hop = NSStackView(views: [tieuDe, coc, nhanThieu, hangNut])
        hop.orientation = .vertical
        hop.alignment = .leading
        hop.spacing = 10
        hop.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        hop.wantsLayer = true
        hop.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        hop.layer?.cornerRadius = 8
        hop.layer?.borderWidth = 1
        hop.layer?.borderColor = EideToken.Mau.border.cgColor
        hop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hop)
        NSLayoutConstraint.activate([
            hop.centerXAnchor.constraint(equalTo: centerXAnchor),
            hop.topAnchor.constraint(equalTo: topAnchor, constant: 110),
            hop.widthAnchor.constraint(equalToConstant: 520),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Tên các tham số BẮT BUỘC của một hợp đồng. Rỗng = gọi thẳng được.
    public static func batBuoc(_ mota: [String: Any]) -> [String] {
        let s = (mota["input_schema"] as? [String: Any]) ?? [:]
        return (s["required"] as? [String] ?? []).filter { !$0.isEmpty }
    }

    /// Mở form cho một năng lực. `mota` là kết quả `caps.describe`.
    public func mo(id: String, mota: [String: Any]) {
        capId = id
        tieuDe.stringValue = "\(id) — cần tham số"
        for v in coc.arrangedSubviews { coc.removeArrangedSubview(v); v.removeFromSuperview() }
        o = []

        let s = (mota["input_schema"] as? [String: Any]) ?? [:]
        let thuocTinh = (s["properties"] as? [String: Any]) ?? [:]
        let can = Set(Self.batBuoc(mota))
        // Bắt buộc TRƯỚC, rồi tuỳ chọn — và trong mỗi nhóm thì theo thứ tự chữ cái. Thứ tự của
        // một `Dictionary` Swift đổi giữa hai lần chạy, nên không ghim thứ tự ở đây thì form
        // xáo chỗ các ô mỗi lần mở, và người dùng không nhớ được ô nào ở đâu.
        for ten in thuocTinh.keys.sorted(by: { (can.contains($0) ? 0 : 1, $0)
                                             < (can.contains($1) ? 0 : 1, $1) }) {
            let d = (thuocTinh[ten] as? [String: Any]) ?? [:]
            coc.addArrangedSubview(_dungO(ten, d, batBuoc: can.contains(ten)))
        }
        if thuocTinh.isEmpty {
            let n = NSTextField(wrappingLabelWithString:
                "Hợp đồng của `\(id)` khai tham số bắt buộc nhưng không khai `properties` — "
                + "không dựng được form. Gọi bằng `eide caps invoke` với JSON tự viết.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.bad
            coc.addArrangedSubview(n)
        }
        isHidden = false
        _kiem()
        window?.makeFirstResponder(o.first?.khungNhin)
    }

    public func dong() {
        isHidden = true
        window?.makeFirstResponder(nil)
    }

    /// Tham số đang điền — cho bài đo đọc, và cũng là thứ nút Chạy gửi đi.
    public func thamSo() -> [String: Any] {
        var ra: [String: Any] = [:]
        for x in o {
            // **`NSPopUpButton` KIỂM TRƯỚC — nó là một `NSButton`.** Đảo hai nhánh này thì mọi ô
            // enum rơi vào nhánh boolean: `conThieu()` thấy chúng luôn có giá trị nên nút Chạy
            // sống ngay từ lúc mở form, và tham số gửi đi là `true`/`false` thay cho lựa chọn.
            // Với `passport.query` thì `predicate: false` — trượt schema, đúng cái lỗi form này
            // sinh ra để tránh.
            if let p = x.khungNhin as? NSPopUpButton {     // enum
                // `— chọn —` là CHƯA CHỌN, không phải một giá trị. Nó không nằm trong enum của
                // hợp đồng, nên gửi đi sẽ trượt schema.
                if let v = p.titleOfSelectedItem, x.enumDs.contains(v) { ra[x.ten] = v }
                continue
            }
            if let c = x.khungNhin as? NSButton {          // boolean
                ra[x.ten] = c.state == .on
                continue
            }
            guard let t = x.khungNhin as? NSTextField else { continue }
            let v = t.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { continue }
            // Số thì gửi SỐ. Gửi "5" cho một trường `integer` sẽ trượt `input_schema` và trả
            // E1000 — đúng cái lỗi form này sinh ra để tránh.
            switch x.loai {
            case "integer": ra[x.ten] = Int(v) ?? v
            case "number": ra[x.ten] = Double(v) ?? v
            default: ra[x.ten] = v
            }
        }
        return ra
    }

    /// Tham số bắt buộc còn TRỐNG. Rỗng = bấm Chạy được.
    public func conThieu() -> [String] {
        let da = thamSo()
        return o.filter { $0.batBuoc && da[$0.ten] == nil }.map(\.ten)
    }

    /// Điền các ô — cho bài đo đi đúng đường người dùng đi.
    public func dienDeTest(_ gt: [String: String]) {
        for x in o {
            guard let v = gt[x.ten] else { continue }
            if let p = x.khungNhin as? NSPopUpButton { p.selectItem(withTitle: v) }
            else if let c = x.khungNhin as? NSButton { c.state = v == "true" ? .on : .off }
            else if let t = x.khungNhin as? NSTextField { t.stringValue = v }
        }
        _kiem()
    }

    private func _dungO(_ ten: String, _ d: [String: Any], batBuoc: Bool) -> NSView {
        let loai = (d["type"] as? String) ?? "string"
        let enumDs = (d["enum"] as? [Any] ?? []).map { "\($0)" }
        let mota = (d["description"] as? String) ?? ""

        let nhan = NSTextField(labelWithString: ten + (batBuoc ? " *" : ""))
        nhan.font = batBuoc ? NSFont.boldSystemFont(ofSize: 12) : EideToken.fontUI
        nhan.textColor = batBuoc ? EideToken.Mau.text : EideToken.Mau.muted

        let nhap: NSView
        if !enumDs.isEmpty {
            let p = NSPopUpButton()
            // **Mục rỗng đứng đầu cho CẢ hai loại.** Bản đầu chỉ thêm nó cho tham số tuỳ chọn,
            // với lý do "bắt buộc thì kiểu gì cũng phải chọn" — sai, và sai đúng theo cách tệp
            // tài liệu lớp này vừa cảnh báo: một popup luôn có giá trị thì `conThieu()` không
            // bao giờ thấy nó thiếu, nút Chạy sống ngay từ lúc mở, và form gửi đi lựa chọn ĐẦU
            // TIÊN trong enum như thể người dùng đã chọn nó. Với `predicate` của
            // `passport.query` thì đó là một truy vấn khác hẳn truy vấn họ định làm.
            p.addItems(withTitles: [batBuoc ? "— chọn —" : ""] + enumDs)
            p.target = self
            p.action = #selector(_doi)
            nhap = p
        } else if loai == "boolean" {
            let c = NSButton(checkboxWithTitle: "", target: self, action: #selector(_doi))
            nhap = c
        } else {
            let t = NSTextField()
            t.font = EideToken.fontUI
            t.placeholderString = mota.isEmpty ? loai : mota
            t.delegate = self
            nhap = t
        }
        nhap.translatesAutoresizingMaskIntoConstraints = false
        nhap.widthAnchor.constraint(equalToConstant: 300).isActive = true

        o.append(O(ten: ten, loai: loai, batBuoc: batBuoc, enumDs: enumDs,
                   mota: mota, khungNhin: nhap))

        let hang = NSStackView(views: [nhan, nhap])
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = 10
        // Mô tả từ hợp đồng nằm DƯỚI ô, không thành placeholder khi ô là popup/checkbox — hai
        // loại ấy không có placeholder, và mất mô tả là mất chính thứ nói cho người biết điền gì.
        guard !mota.isEmpty, enumDs.isEmpty == false || loai == "boolean" else { return hang }
        let m = NSTextField(wrappingLabelWithString: mota)
        m.font = EideToken.fontUI
        m.textColor = EideToken.Mau.faint
        let doc = NSStackView(views: [hang, m])
        doc.orientation = .vertical
        doc.alignment = .leading
        doc.spacing = 1
        return doc
    }

    /// Nút Chạy sống/chết theo các ô bắt buộc — §4.4 "không cho gọi thiếu".
    private func _kiem() {
        let thieu = conThieu()
        nutChay.isEnabled = thieu.isEmpty
        nhanThieu.stringValue = thieu.isEmpty ? ""
            : "Còn thiếu: \(thieu.joined(separator: ", ")) — hợp đồng CDS-12 khai bắt buộc."
    }

    @objc private func _doi() { _kiem() }
    @objc private func _huy() { dong() }

    @objc private func _chay() {
        guard conThieu().isEmpty else { return _kiem() }
        let t = thamSo()
        let id = capId
        dong()
        onChay?(id, t)
    }

    public override func cancelOperation(_ sender: Any?) { dong() }
}

extension EideFormThamSo: NSTextFieldDelegate {
    public func controlTextDidChange(_ obj: Notification) { _kiem() }
}
