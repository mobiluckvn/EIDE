import AppKit

/// **Ô nhập sinh từ hợp đồng** — THIET-KE-UI sheet 3, chủ sản phẩm duyệt 14/09/2026.
///
/// ## Vì sao thứ này tồn tại
///
/// Đo 14/09: **18 trên 22 màn mở ra là trống**, và không phải vì thiếu dữ liệu — vì năng lực
/// đứng sau chúng cần tham số (`part`, `file`, `feature`, `artifact`…) mà giao diện không có
/// chỗ nào nhập. Màn thì có, đường vào thì không. Chủ sản phẩm gọi đúng tên: *"giao diện hiện
/// tại lỗi quá chẳng dùng được gì"*.
///
/// Sinh ô nhập **từ `input_schema` của chính hợp đồng**, không viết tay từng màn. Ba lý do, và
/// lý do thứ ba mới là lý do thật:
///
/// 1. 37 tham số trên 21 màn — viết tay là 37 chỗ có thể sai.
/// 2. Thêm một năng lực vào màn thì ô nhập tự có.
/// 3. **Ô nhập viết tay sẽ trôi khỏi hợp đồng.** Một tham số đổi tên trong `cds.json` thì form
///    viết tay vẫn gửi tên cũ, và lỗi hiện ra là "E1000 thiếu tham số" cho một ô người dùng
///    vừa điền — đúng loại lỗi không ai đoán được nguyên nhân.
///
/// ## Điều khiển theo LOẠI tham số, không chỉ theo kiểu JSON
///
/// `file` là chuỗi, nhưng bắt người ta gõ tay đường dẫn tuyệt đối là thiết kế tệ; nó phải là
/// nút chọn tệp kèm kéo thả. `part` là chuỗi, nhưng nó có tập giá trị đọc được từ
/// `passport.list`. Bảng `DAC_BIET` giữ những ngoại lệ ấy — nhỏ, và mỗi dòng là một quyết định
/// về trải nghiệm chứ không phải về kiểu dữ liệu.
public final class EideONhap: NSView {

    /// Người bấm "Chạy". Panel nối vào đây để gọi năng lực.
    public var onChay: ((String, [String: Any]) -> Void)?

    /// Người bấm nút chọn tệp — panel mở `NSOpenPanel` (view không tự mở để test được).
    public var onChonTep: ((@escaping (String) -> Void) -> Void)?

    /// Ô cần gợi ý → panel gọi năng lực nguồn và trả về danh sách.
    ///
    /// Panel làm việc gọi, không phải view: danh sách `part` đến từ `passport.list` của ĐÚNG dự
    /// án đang mở, và view không biết gì về client.
    public var onLayGoiY: ((String, @escaping ([String]) -> Void) -> Void)?

    private var capId = ""
    private var truong: [(ten: String, kieu: String, batBuoc: Bool, o: NSView)] = []
    private let hang = NSStackView()
    private let nutChay = NSButton()
    private let nhanLoi = NSTextField(labelWithString: "")

    /// Tham số cần nhiều hơn một ô chữ. Khoá là TÊN tham số, vì cùng một tên mang cùng một
    /// nghĩa xuyên suốt `cds.json` — `part` luôn là mã linh kiện, `file` luôn là đường dẫn.
    public enum Dac: Equatable {
        case chonTep                 // nút Chọn tệp… + kéo thả
        case goiY(nguon: String)     // ô chữ + danh sách gợi ý lấy từ một năng lực
        case chu                     // ô chữ thường
        case so
        case batTat
    }

    public static let DAC_BIET: [String: Dac] = [
        "file": .chonTep, "path": .chonTep, "artifact": .chonTep, "scenario": .chonTep,
        "part": .goiY(nguon: "passport.list"),
        "chip": .goiY(nguon: "passport.list"),
        "feature": .goiY(nguon: "project.status"),
        "isa": .goiY(nguon: "env.detect"),
    ]

    /// Kiểu JSON → điều khiển, khi tên tham số không nằm trong `DAC_BIET`.
    public static func dieuKhien(ten: String, kieu: String) -> Dac {
        if let d = DAC_BIET[ten] { return d }
        switch kieu {
        case "integer", "number": return .so
        case "boolean": return .batTat
        default: return .chu
        }
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        hang.orientation = .vertical
        hang.alignment = .leading
        hang.spacing = EideToken.space[1]
        nutChay.title = "Chạy"
        nutChay.bezelStyle = .rounded
        nutChay.keyEquivalent = "\r"
        nutChay.target = self
        nutChay.action = #selector(bamChay)
        nhanLoi.font = EideToken.fontUI
        nhanLoi.textColor = EideToken.Mau.bad
        nhanLoi.isHidden = true

        for v in [hang, nutChay, nhanLoi] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: topAnchor),
            hang.leadingAnchor.constraint(equalTo: leadingAnchor),
            hang.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            nutChay.topAnchor.constraint(equalTo: hang.bottomAnchor, constant: EideToken.space[1]),
            nutChay.leadingAnchor.constraint(equalTo: leadingAnchor),
            nhanLoi.centerYAnchor.constraint(equalTo: nutChay.centerYAnchor),
            nhanLoi.leadingAnchor.constraint(equalTo: nutChay.trailingAnchor,
                                             constant: EideToken.space[1]),
            nhanLoi.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            bottomAnchor.constraint(equalTo: nutChay.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Dựng form từ hợp đồng

    /// `caps.describe` → các ô nhập.
    ///
    /// Nhận nguyên kết quả `caps.describe` chứ không nhận một cấu trúc đã lọc: chỗ nào cần lọc
    /// thì lọc ở đây, một lần, thay vì để mỗi màn tự đọc schema theo cách riêng.
    @MainActor
    public func dungTu(capId: String, moTa: [String: Any]) {
        self.capId = capId
        for v in hang.arrangedSubviews { hang.removeArrangedSubview(v); v.removeFromSuperview() }
        truong.removeAll()
        nhanLoi.isHidden = true

        let sch = (moTa["input_schema"] as? [String: Any]) ?? [:]
        let props = (sch["properties"] as? [String: Any]) ?? [:]
        let batBuoc = Set((sch["required"] as? [Any])?.compactMap { $0 as? String } ?? [])

        // Thứ tự: BẮT BUỘC trước, rồi theo bảng chữ cái. JSON không giữ thứ tự có ý nghĩa, và
        // một form mà ô bắt buộc nằm lẫn giữa các ô tuỳ chọn thì người dùng điền thiếu rồi mới
        // biết.
        let ten = props.keys.sorted { a, b in
            batBuoc.contains(a) != batBuoc.contains(b) ? batBuoc.contains(a) : a < b
        }
        for t in ten {
            let p = (props[t] as? [String: Any]) ?? [:]
            let kieu = (p["type"] as? String) ?? ((p["type"] as? [Any])?.first as? String) ?? "string"
            let bb = batBuoc.contains(t)
            let o = oCho(ten: t, kieu: kieu, mo: (p["description"] as? String) ?? "")
            hang.addArrangedSubview(o.khung)
            truong.append((t, kieu, bb, o.o))
        }
        if ten.isEmpty {
            // Năng lực không tham số: vẫn phải có nút, vì người dùng cần CHẠY được nó. Bản cũ
            // im lặng không hiện gì và màn trông như hỏng.
            let l = NSTextField(labelWithString: "Năng lực này không cần tham số.")
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.muted
            hang.addArrangedSubview(l)
        }
        nutChay.title = "Chạy \(capId)"
    }

    private func oCho(ten: String, kieu: String, mo: String)
        -> (khung: NSView, o: NSView) {
        let dong = NSStackView()
        dong.orientation = .horizontal
        dong.alignment = .centerY
        dong.spacing = EideToken.space[1]

        let nhan = NSTextField(labelWithString: ten)
        nhan.font = EideToken.fontUI
        nhan.textColor = EideToken.Mau.text
        nhan.widthAnchor.constraint(equalToConstant: 96).isActive = true
        dong.addArrangedSubview(nhan)

        let dk = Self.dieuKhien(ten: ten, kieu: kieu)
        let o: NSView
        switch dk {
        case .batTat:
            let b = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            o = b
        case .chonTep:
            let t = NSTextField()
            t.placeholderString = "đường dẫn — hoặc bấm Chọn tệp…"
            t.font = EideToken.fontMono
            t.widthAnchor.constraint(equalToConstant: 300).isActive = true
            let b = NSButton(title: "Chọn tệp…", target: self, action: #selector(bamChonTep(_:)))
            b.bezelStyle = .rounded
            b.identifier = .init(ten)
            dong.addArrangedSubview(t)
            dong.addArrangedSubview(b)
            o = t
        default:
            let t = NSTextField()
            t.placeholderString = mo.isEmpty ? (dk == .so ? "số" : "") : mo
            t.font = dk == .so ? EideToken.fontUI : EideToken.fontMono
            t.widthAnchor.constraint(equalToConstant: 300).isActive = true
            if case let .goiY(nguon) = dk {
                t.toolTip = "Gợi ý lấy từ \(nguon)"
                // Hỏi gợi ý NGAY khi dựng ô, không đợi người gõ. Người dùng không biết mã linh
                // kiện trông thế nào cho tới khi thấy một cái — và `st.stm32f411ce` không phải
                // thứ đoán ra được. Danh sách tới sau thì ô tự có gợi ý; không tới thì ô vẫn gõ
                // tay được, chỉ mất tiện.
                _xinGoiY(cho: t, ten: ten, nguon: nguon)
            }
            o = t
        }
        if !(dk == .chonTep) { dong.addArrangedSubview(o) }
        o.setAccessibilityLabel(ten)
        return (dong, o)
    }

    /// Xin danh sách gợi ý cho một ô và gắn vào nó.
    ///
    /// Gắn bằng `placeholderString` + `toolTip` chứ không bằng một menu thả xuống: tập giá trị
    /// ở đây là MỞ (một dự án có thể tra một chip chưa có hộ chiếu), nên một danh sách đóng sẽ
    /// chặn đúng trường hợp người dùng cần nhất. Gợi ý là gợi ý, không phải ràng buộc.
    private func _xinGoiY(cho o: NSTextField, ten: String, nguon: String) {
        onLayGoiY?(nguon) { [weak o] ds in
            Task { @MainActor in
                guard let o, !ds.isEmpty else { return }
                o.placeholderString = ds.count == 1
                    ? "ví dụ: \(ds[0])"
                    : "ví dụ: \(ds.prefix(3).joined(separator: ", "))"
                    + (ds.count > 3 ? " … (\(ds.count) mục)" : "")
                // Một giá trị duy nhất thì ĐIỀN SẴN: dự án chỉ có một hộ chiếu chip thì bắt
                // người dùng gõ lại tên nó là nghi thức thừa.
                if ds.count == 1 && o.stringValue.isEmpty { o.stringValue = ds[0] }
            }
        }
    }

    @objc private func bamChonTep(_ sender: NSButton) {
        guard let ten = sender.identifier?.rawValue,
              let o = truong.first(where: { $0.ten == ten })?.o as? NSTextField else { return }
        onChonTep? { duong in
            Task { @MainActor in o.stringValue = duong }
        }
    }

    // MARK: - Đọc giá trị

    /// Tham số người dùng đã điền, đã ép kiểu theo schema.
    ///
    /// Ép kiểu ở đây chứ không để daemon từ chối: `"16000000"` gửi cho một tham số `integer` sẽ
    /// bị `validate_input` trả E1000, và thông báo ấy nói về schema chứ không nói về ô người
    /// dùng vừa gõ.
    @MainActor
    public func thamSo() -> [String: Any] {
        var ra: [String: Any] = [:]
        for t in truong {
            if let b = t.o as? NSButton {
                if b.state == .on { ra[t.ten] = true }
                continue
            }
            guard let o = t.o as? NSTextField else { continue }
            let v = o.stringValue.trimmingCharacters(in: .whitespaces)
            if v.isEmpty { continue }
            switch t.kieu {
            case "integer": ra[t.ten] = Int(v) ?? v
            case "number": ra[t.ten] = Double(v) ?? v
            case "boolean": ra[t.ten] = (v.lowercased() == "true")
            default: ra[t.ten] = v
            }
        }
        return ra
    }

    /// Ô bắt buộc nào còn trống — trả TÊN, để câu báo lỗi nói đúng ô.
    @MainActor
    public func thieu() -> [String] {
        let co = thamSo()
        return truong.filter { $0.batBuoc && co[$0.ten] == nil }.map(\.ten)
    }

    @objc private func bamChay() {
        let t = thieu()
        guard t.isEmpty else {
            // Chặn ở đây thay vì để daemon trả E1000: lỗi hiện ngay cạnh nút, nói đúng tên ô,
            // và không tốn một vòng gọi để biết một điều giao diện đã biết sẵn.
            nhanLoi.stringValue = "Còn thiếu: " + t.joined(separator: ", ")
            nhanLoi.isHidden = false
            return
        }
        nhanLoi.isHidden = true
        onChay?(capId, thamSo())
    }

    /// Báo lỗi trả về từ daemon, ngay cạnh nút — không đẩy vào hội thoại nơi nó trôi mất.
    @MainActor
    public func baoLoi(_ vi: String) {
        nhanLoi.stringValue = vi
        nhanLoi.isHidden = vi.isEmpty
    }

    /// Số ô đang hiện — để test và để màn biết có gì để hiện không.
    @MainActor
    public var soO: Int { truong.count }

    /// Bấm "Chạy" bằng mã — dùng cho test và cho phím tắt về sau.
    @MainActor
    public func bamChayDeTest() { bamChay() }

    @MainActor
    public func datGiaTri(_ ten: String, _ v: String) {
        (truong.first { $0.ten == ten }?.o as? NSTextField)?.stringValue = v
    }
}
