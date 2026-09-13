import AppKit

/// Khung chung cho các màn hình chuyên đề của UXD-13 §2.
///
/// Spec: UXD-13 U7 (token PTIT), U9 (ba trạng thái rỗng/lỗi/chờ), U10 (tương phản, bàn phím);
/// NFR-USE-03 (nhãn trợ năng cho nhóm).
///
/// ## Vì sao một lớp cơ sở chứ không phải hai mươi ba lần chép
///
/// Hai mươi ba màn mỗi màn tự dựng viền, tự chọn khoảng cách, tự quyết định "rỗng thì hiện gì"
/// sẽ cho ra hai mươi ba giao diện hơi khác nhau — và người dùng đọc sự khác nhau ấy như một
/// tín hiệu ("màn này chắc quan trọng hơn"), trong khi nó chỉ là dấu vết của thứ tự viết mã.
/// Quan trọng hơn: **quy tắc U9 về trạng thái rỗng chỉ có giá trị nếu KHÔNG màn nào quên nó.**
/// Đặt `noiRong` vào lớp cơ sở thì quên là chuyện phải cố tình.
///
/// Lớp này cố ý KHÔNG biết gì về daemon. Nó nhận một `[String: Any]` — đúng thứ `caps.invoke`
/// trả về — và biến thành các dòng. Panel giữ phần nối dây; màn giữ phần *hiện cái gì*.
open class ManHinhCoSo: NSView {

    /// Tên màn, hiện ở đầu. Lớp con đặt trong `init`.
    public let tieuDe = NSTextField(labelWithString: "")
    /// Dòng tóm tắt dưới tiêu đề — chỗ của những con số đáng nhìn trước.
    public let tomTat = NSTextField(labelWithString: "")
    /// Thân màn: các dòng xếp dọc, cuộn được.
    public let cot = NSStackView()

    private let cuon = NSScrollView()

    /// Số dòng đang hiện — cho test đếm mà không phải dò cây khung nhìn.
    public private(set) var soDong = 0

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { tieuDe.stringValue }

    public init(ten: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        tieuDe.stringValue = ten
        tieuDe.font = NSFont.boldSystemFont(ofSize: 12)
        tieuDe.textColor = EideToken.Mau.text
        tomTat.font = EideToken.fontUI
        tomTat.textColor = EideToken.Mau.muted

        cot.orientation = .vertical
        cot.alignment = .leading
        cot.spacing = 2
        cot.translatesAutoresizingMaskIntoConstraints = false

        // Cuộn được, vì `board.check_pins` trên một board thật trả về hàng chục dòng và một
        // danh sách bị cắt cụt ở đáy khung là một danh sách người đọc tưởng đã hết.
        cuon.documentView = cot
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false

        let dau = NSStackView(views: [tieuDe, tomTat])
        dau.orientation = .vertical
        dau.alignment = .leading
        dau.spacing = 2
        dau.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dau)
        addSubview(cuon)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            dau.topAnchor.constraint(equalTo: topAnchor, constant: s),
            dau.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            dau.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),

            cuon.topAnchor.constraint(equalTo: dau.bottomAnchor, constant: EideToken.space[1]),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -s),
            cot.widthAnchor.constraint(equalTo: cuon.widthAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    // MARK: - API cho lớp con

    /// Xóa thân màn. Gọi ở đầu mỗi `capNhat`.
    public func xoaThan() {
        for v in cot.arrangedSubviews { cot.removeArrangedSubview(v); v.removeFromSuperview() }
        soDong = 0
    }

    /// Một dòng chữ mờ — dùng cho trạng thái rỗng và ghi chú.
    @discardableResult
    public func noiRong(_ t: String) -> NSTextField {
        let v = NSTextField(wrappingLabelWithString: t)
        v.font = EideToken.fontUI
        v.textColor = EideToken.Mau.muted
        cot.addArrangedSubview(v)
        return v
    }

    /// Một dòng dữ liệu: nhãn đậm + phần phụ, phần phụ mang màu trạng thái.
    ///
    /// `nut` bật thì nhãn thành nút bấm được — U5 nói mọi nút là một năng lực, nên chỉ bật khi
    /// dòng ấy THẬT SỰ mở ra được một việc.
    @discardableResult
    public func themDong(_ nhan: String, _ phu: String, mau: NSColor? = nil,
                         nut: Bool = false, ma: String = "",
                         bam: Selector? = nil) -> NSView {
        let trai: NSView
        if nut, let sel = bam {
            let b = NSButton(title: nhan, target: self, action: sel)
            b.bezelStyle = .inline
            b.font = EideToken.fontUI
            b.identifier = NSUserInterfaceItemIdentifier(ma)
            trai = b
        } else {
            let l = NSTextField(labelWithString: nhan)
            l.font = EideToken.fontUI
            l.textColor = EideToken.Mau.text
            trai = l
        }
        let p = NSTextField(labelWithString: phu)
        p.font = EideToken.fontUI
        p.textColor = mau ?? EideToken.Mau.muted

        let hang = NSStackView(views: [trai, p])
        hang.orientation = .horizontal
        hang.alignment = .centerY
        hang.spacing = EideToken.space[1]
        cot.addArrangedSubview(hang)
        soDong += 1
        return hang
    }

    /// Nhận kết quả `caps.invoke`. Lớp con bắt buộc cài.
    open func capNhat(ketQua: [String: Any]) {
        xoaThan()
        noiRong("Màn này chưa nối năng lực nào.")
    }
}

/// Đọc một số từ JSON mà không quan tâm nó tới dưới dạng nào.
///
/// JSON không phân biệt số nguyên với số thực, và các cầu nối thì phân biệt: `JSONSerialization`
/// trả `NSNumber`, một `47.2` cạnh một `128004` trong cùng object có thể khiến cả hai thành
/// `Double`, và `as? Int` im lặng trả `nil` — đúng nghĩa là một số bị đọc thành 0 mà không có
/// lỗi nào. Với `after_line` của `debug.log_stats` thì 0 nghĩa là "mở log ở dòng 0", tức chỉ
/// người dùng tới một chỗ không phải chỗ hệ thống treo.
public enum EideSo {

    public static func nguyen(_ v: Any?) -> Int? {
        switch v {
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }

    public static func thuc(_ v: Any?) -> Double? {
        switch v {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}

// MARK: - Cách đọc những thứ nhiều màn cùng gặp

/// Mức nghiêm trọng dùng chung cho `board.check_pins`, `arch.review`, `code.static`,
/// `diagram.lint`, `sim.*` — năm năng lực khác nhau, cùng một thang.
///
/// Tách ra vì mỗi màn tự dịch `severity` sẽ cho ra năm bảng màu: một màn coi `warning` là vàng,
/// màn kia coi là xám, và người dùng học được rằng màu ở đây không có nghĩa gì.
public enum EideMuc {

    public static func mau(_ s: String) -> NSColor {
        switch s.lowercased() {
        case "error", "critical", "fatal", "high", "conflict": return EideToken.Mau.bad
        case "warning", "warn", "medium": return EideToken.Mau.warn
        case "info", "low", "note": return EideToken.Mau.info
        default: return EideToken.Mau.muted
        }
    }

    public static func ten(_ s: String) -> String {
        switch s.lowercased() {
        case "error", "fatal": return "lỗi"
        case "critical", "high": return "nghiêm trọng"
        case "warning", "warn", "medium": return "cảnh báo"
        case "info", "low", "note": return "ghi chú"
        default: return s
        }
    }

    /// Nặng trước. Danh sách dài thì người chỉ đọc mấy dòng đầu, nên thứ tự là một quyết định
    /// về nội dung chứ không phải về thẩm mỹ.
    public static func diem(_ s: String) -> Int {
        switch s.lowercased() {
        case "critical", "fatal", "high": return 0
        case "error", "conflict": return 1
        case "warning", "warn", "medium": return 2
        case "info", "low", "note": return 3
        default: return 4
        }
    }
}
