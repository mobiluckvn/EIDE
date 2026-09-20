import AppKit
import EideLoi

/// Một VẾ của một xung đột — cấu trúc thuần, không biết gì về fact hay về mã.
///
/// Đó là điểm của nó: UXC-31 §6.3 cấm viết màn riêng cho xung đột MÃ và bắt dùng lại đúng
/// component của màn Xung đột tri thức (S8). Ràng buộc ấy chỉ giữ được nếu component không
/// nhận vào `fact` — nên nó nhận vào *một nhãn, một giá trị, vài dòng phụ, và một khoá*.
public struct EideVeXungDot {
    /// Nhãn của vế: `"A · vàng"` cho fact, `"Người sửa 14:22"` cho mã.
    public let nhan: String
    /// Giá trị đem ra so — thứ người đọc để quyết.
    public let giaTri: String
    /// Dòng phụ `(tên, giá trị)`: tầng, nguồn, trạng thái, thời điểm…
    public let phu: [(String, String)]
    /// Khoá trả về khi người chọn vế này — `"a"`/`"b"` theo KG-06.
    public let khoa: String

    public init(nhan: String, giaTri: String, phu: [(String, String)], khoa: String) {
        self.nhan = nhan
        self.giaTri = giaTri
        self.phu = phu
        self.khoa = khoa
    }
}

/// **Thẻ một xung đột — hai vế CÙNG HÀNG.** UXC-31 §8 S8, và §6.3 dùng lại nguyên thẻ này cho
/// xung đột MÃ.
///
/// Hai vế phải nằm cùng hàng chứ không xếp trên dưới, vì việc người dùng làm ở đây là SO SÁNH
/// hai giá trị. Xếp dọc thì mắt phải nhớ giá trị thứ nhất trong lúc đọc giá trị thứ hai, và
/// khác biệt quan trọng nhất — thường là vài chữ số giữa hai địa chỉ — là thứ trí nhớ ngắn hạn
/// đánh rơi trước tiên.
@MainActor
public final class EideTheXungDot: NSView {

    /// `(mã xung đột, khoá lựa chọn)`. Khoá đi thẳng vào tham số `choice` của năng lực đứng
    /// sau; thẻ không dịch nghĩa, vì mỗi lần dịch là một chỗ để lệch.
    public var onChon: ((String, String) -> Void)?

    public let ma: String
    private let cocNut = NSStackView()

    /// - Parameters:
    ///   - ma: mã xung đột, truyền nguyên vào năng lực (KG-06 nhận `<fact_a>:<fact_b>`).
    ///   - tieuDe: thứ đang tranh chấp — `chip:…/periph:I2C1 · base_address`, hay đường tệp.
    ///   - phuDe: một câu mô tả, hoặc rỗng.
    ///   - them: nút NGOÀI hai vế — `("Cả hai — có điều kiện", "both_conditional")` cho fact,
    ///     `("Soạn tay", "manual")` cho mã. Danh sách do bên gọi khai, vì mỗi nguồn dữ liệu có
    ///     tập hành động riêng mà chính sách cho phép.
    public init(ma: String, tieuDe: String, phuDe: String,
                a: EideVeXungDot, b: EideVeXungDot, them: [(String, String)] = []) {
        self.ma = ma
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = EideToken.Mau.border.cgColor
        layer?.cornerRadius = EideToken.radius[0]

        let td = NSTextField(wrappingLabelWithString: tieuDe)
        td.font = NSFont.boldSystemFont(ofSize: 12)
        td.textColor = EideToken.Mau.text

        let hai = NSStackView(views: [Self.ve(a), Self.ve(b)])
        hai.orientation = .horizontal
        hai.distribution = .fillEqually
        hai.alignment = .top
        hai.spacing = 12

        cocNut.orientation = .horizontal
        cocNut.spacing = 8
        for (nhan, khoa) in [(a.nhanNut, a.khoa), (b.nhanNut, b.khoa)] + them {
            let n = NSButton(title: nhan, target: self, action: #selector(_bam(_:)))
            n.bezelStyle = .rounded
            n.identifier = NSUserInterfaceItemIdentifier(khoa)
            cocNut.addArrangedSubview(n)
        }

        var hang: [NSView] = [td]
        if !phuDe.isEmpty {
            let p = NSTextField(wrappingLabelWithString: phuDe)
            p.font = EideToken.fontUI
            p.textColor = EideToken.Mau.muted
            hang.append(p)
        }
        hang += [hai, cocNut]

        let coc = NSStackView(views: hang)
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 8
        coc.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        coc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coc)
        NSLayoutConstraint.activate([
            coc.topAnchor.constraint(equalTo: topAnchor),
            coc.leadingAnchor.constraint(equalTo: leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: trailingAnchor),
            coc.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// Nhãn nút của thẻ, cho test đọc mà không phải đi bộ cây khung nhìn.
    public var nhanNut: [String] {
        cocNut.arrangedSubviews.compactMap { ($0 as? NSButton)?.title }
    }

    @objc private func _bam(_ n: NSButton) {
        n.identifier.map { onChon?(ma, $0.rawValue) }
    }

    private static func ve(_ v: EideVeXungDot) -> NSView {
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: v.nhan + "\n", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 10.5),
            .foregroundColor: EideToken.Mau.faint,
        ]))
        s.append(NSAttributedString(string: v.giaTri + "\n", attributes: [
            .font: EideToken.fontMono,
            .foregroundColor: EideToken.Mau.text,
        ]))
        for (k, g) in v.phu {
            s.append(NSAttributedString(string: "\(k): \(g)\n", attributes: [
                .font: EideToken.fontUI,
                .foregroundColor: EideToken.Mau.muted,
            ]))
        }
        let n = NSTextField(labelWithAttributedString: s)
        n.lineBreakMode = .byWordWrapping
        n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return n
    }
}

private extension EideVeXungDot {
    /// Nhãn nút suy từ chính nhãn vế: `"A · vàng"` → `"Chọn A"`. Không để bên gọi tự đặt, vì
    /// hai vế đặt tên nút lệch nhau là cách nhanh nhất để người bấm nhầm vế.
    var nhanNut: String { "Chọn \(nhan.split(separator: " ").first.map(String.init) ?? khoa.uppercased())" }
}
