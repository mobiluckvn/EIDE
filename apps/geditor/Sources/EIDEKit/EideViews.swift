import AppKit

/// Thanh trạng thái tự chủ — UXD-13 U2, U6.
///
/// "Thanh trạng thái tự chủ LUÔN hiện: mức, số việc tự làm, số chờ, hạn hoàn tác" cùng nút
/// "■ Dừng khẩn". Nó luôn hiện vì đó là câu trả lời cho câu hỏi người dùng sẽ hỏi thường
/// xuyên nhất khi giao việc cho một tác tử: *máy đang được phép làm gì mà không hỏi tôi?*
public final class AutonomyBar: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Trạng thái tự chủ" }

    public var onDungKhan: (() -> Void)?

    private let nhan = NSTextField(labelWithString: "…")
    private let nutDung = NSButton()

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.secondary.cgColor

        nhan.font = EideToken.fontUI
        nhan.textColor = .white
        nutDung.title = "■ Dừng khẩn"
        nutDung.font = EideToken.fontUI
        nutDung.bezelStyle = .rounded
        nutDung.contentTintColor = .white
        nutDung.target = self
        nutDung.action = #selector(dung)
        // U6: phím tắt ⌘⇧. — dừng khẩn phải với tới được mà không cần tìm chuột.
        nutDung.keyEquivalent = "."
        nutDung.keyEquivalentModifierMask = [.command, .shift]
        nutDung.setAccessibilityLabel("Dừng khẩn, phím tắt Command Shift chấm")

        for v in [nhan, nutDung] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            nhan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            nhan.centerYAnchor.constraint(equalTo: centerYAnchor),
            nutDung.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            nutDung.centerYAnchor.constraint(equalTo: centerYAnchor),
            nhan.trailingAnchor.constraint(lessThanOrEqualTo: nutDung.leadingAnchor, constant: -s),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func dung() { onDungKhan?() }

    public func capNhat(muc: String?, dungKhan: Bool, soCho: Int, soHoanTac: Int) {
        // U10: "không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)" — trạng thái dừng được nói
        // bằng CHỮ, màu chỉ là lớp thứ hai. Người mù màu vẫn phải đọc được.
        let m = dungKhan ? "■ ĐÃ DỪNG (A0)" : (muc ?? "—")
        nhan.stringValue = "\(m)  ·  \(soCho) chờ anh  ·  \(soHoanTac) hoàn tác được"
        layer?.backgroundColor = (dungKhan ? EideToken.Mau.primary : EideToken.Mau.secondary).cgColor
    }
}

/// Vùng hội thoại — UXD-13 U1 (ChatPanel là màn hình mặc định), U8, U9.
public final class ChatView: NSView, NSTextFieldDelegate {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hội thoại với tác tử" }

    public enum Ai { case nguoi, tacTu, cho, loi, heThong }

    public var onGui: ((String) -> Void)?

    private let cuon = NSScrollView()
    private let van = NSTextView()
    private let oLenh = NSTextField()

    public init() {
        super.init(frame: .zero)
        van.isEditable = false
        van.drawsBackground = true
        van.backgroundColor = EideToken.Mau.surface
        van.textContainerInset = NSSize(width: EideToken.space[2], height: EideToken.space[1])
        cuon.documentView = van
        cuon.hasVerticalScroller = true
        cuon.borderType = .lineBorder

        // U1: "ô lệnh có gợi ý '/' liệt kê năng lực có `ui`" — gợi ý là việc sau; nhưng chỗ
        // gõ phải là thứ đầu tiên người thấy, nên nó nằm dưới cùng và luôn ở đó.
        oLenh.placeholderString = "Gõ lệnh cho EIDE…  (ví dụ: nháy LED trên PB6 mỗi giây)"
        oLenh.font = EideToken.fontUI
        oLenh.delegate = self
        oLenh.setAccessibilityLabel("Ô lệnh")

        for v in [cuon, oLenh] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let s = EideToken.space[1]
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            oLenh.topAnchor.constraint(equalTo: cuon.bottomAnchor, constant: s),
            oLenh.leadingAnchor.constraint(equalTo: leadingAnchor),
            oLenh.trailingAnchor.constraint(equalTo: trailingAnchor),
            oLenh.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        themLuot(by: .heThong, text: "Sẵn sàng. Gõ một câu tiếng Việt; tôi sẽ nói lại ý hiểu trước khi làm.")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func controlTextDidEndEditing(_ obj: Notification) {
        let t = oLenh.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        oLenh.stringValue = ""
        onGui?(t)
    }

    public func themLuot(by ai: Ai, text: String) {
        let (nhan, mau): (String, NSColor) = {
            switch ai {
            case .nguoi:   return ("Anh", EideToken.Mau.text)
            case .tacTu:   return ("EIDE", EideToken.Mau.secondary)
            case .cho:     return ("Chờ anh", EideToken.Mau.warn)      // U2: việc cần người
            case .loi:     return ("Lỗi", EideToken.Mau.bad)
            case .heThong: return ("·", EideToken.Mau.muted)
            }
        }()
        let d = NSMutableAttributedString(
            string: "\(nhan): ",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: mau])
        d.append(NSAttributedString(
            string: text + "\n",
            attributes: [.font: EideToken.fontUI, .foregroundColor: EideToken.Mau.text]))
        van.textStorage?.append(d)
        van.scrollToEndOfDocument(nil)
    }
}

/// Hàng đợi — UXD-13 U2: HAI danh sách, "chờ tôi" và "đã làm — hoàn tác được".
///
/// Tách hai danh sách là điểm chính của U2, không phải cách trình bày: chúng trả lời hai câu
/// hỏi khác nhau — *tôi phải làm gì bây giờ* và *máy vừa làm gì mà tôi còn rút lại được*.
/// Gộp một danh sách thì câu thứ hai biến mất, và "làm rồi báo cáo" mất vế báo cáo.
public final class ReviewQueueView: NSView {

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "Hàng đợi: chờ tôi và đã làm" }

    private let choNhan = NSTextField(labelWithString: "Chờ anh")
    private let hoanTacNhan = NSTextField(labelWithString: "Đã làm — hoàn tác được")
    private let choND = NSTextField(labelWithString: "")
    private let hoanTacND = NSTextField(labelWithString: "")

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = EideToken.radius[0]

        for (n, m) in [(choNhan, EideToken.Mau.warn), (hoanTacNhan, EideToken.Mau.ok)] {
            n.font = NSFont.boldSystemFont(ofSize: 12)
            n.textColor = m
        }
        for v in [choND, hoanTacND] {
            v.font = EideToken.fontUI
            v.textColor = EideToken.Mau.muted
            v.maximumNumberOfLines = 3
        }
        let cot1 = NSStackView(views: [choNhan, choND])
        let cot2 = NSStackView(views: [hoanTacNhan, hoanTacND])
        for c in [cot1, cot2] {
            c.orientation = .vertical
            c.alignment = .leading
            c.spacing = EideToken.space[0]
        }
        let hang = NSStackView(views: [cot1, cot2])
        hang.orientation = .horizontal
        hang.distribution = .fillEqually
        hang.spacing = EideToken.space[3]
        hang.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hang)
        let s = EideToken.space[2]
        NSLayoutConstraint.activate([
            hang.topAnchor.constraint(equalTo: topAnchor, constant: s),
            hang.leadingAnchor.constraint(equalTo: leadingAnchor, constant: s),
            hang.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -s),
            hang.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -s),
        ])
        capNhat(cho: [], hoanTac: [])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func capNhat(cho: [[String: Any]], hoanTac: [[String: Any]]) {
        // U9: "mọi panel có ba trạng thái thiết kế sẵn" — rỗng phải NÓI RA là rỗng, không để
        // một khoảng trắng khiến người dùng tưởng đang tải.
        choNhan.stringValue = "Chờ anh (\(cho.count))"
        hoanTacNhan.stringValue = "Đã làm — hoàn tác được (\(hoanTac.count))"
        choND.stringValue = cho.isEmpty
            ? "Không có việc nào chờ anh."
            : cho.prefix(3).map { ($0["cap"] as? String) ?? "?" }.joined(separator: "\n")
        hoanTacND.stringValue = hoanTac.isEmpty
            ? "Chưa có việc nào tự làm."
            : hoanTac.prefix(3).map {
                "\(($0["cap"] as? String) ?? "?") — đến \(String((($0["deadline"] as? String) ?? "hết phiên").prefix(16)))"
            }.joined(separator: "\n")
    }
}
