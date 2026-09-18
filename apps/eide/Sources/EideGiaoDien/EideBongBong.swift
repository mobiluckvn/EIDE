import AppKit
import EideLoi

/// Một lượt trao đổi — `.msg` của bản demo. Rộng tối đa 78%, bo góc 9.
///
/// Màu và VỊ TRÍ trả lời câu "ai đang nói" trước khi người đọc chữ đầu tiên. Bản cũ dùng một
/// khối văn bản với tiền tố `Anh:` / `EIDE:`; nó đọc được, và nó bắt mắt làm việc ở mỗi lượt.
public final class EideBongBong: NSView {

    public enum Ai {
        case nguoi, tacTu, cho, loi, heThong

        public var nhan: String {
            switch self {
            case .nguoi: return "Anh"
            case .tacTu: return "EIDE"
            case .cho: return "Chờ anh"
            case .loi: return "Lỗi"
            case .heThong: return "·"
            }
        }
        var nen: NSColor {
            switch self {
            case .nguoi: return EideToken.Mau.badBg
            case .cho: return EideToken.Mau.warnBg
            case .loi: return EideToken.Mau.badBg
            default: return EideToken.Mau.surface
            }
        }
        var vien: NSColor? {
            switch self {
            case .nguoi: return nil
            case .cho: return EideToken.Mau.warn
            case .loi: return EideToken.Mau.bad
            default: return EideToken.Mau.border
            }
        }
    }

    public let ai: Ai
    public let van: String

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? { "\(ai.nhan): \(van)" }

    public init(ai: Ai, van: String) {
        self.ai = ai
        self.van = van
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = ai.nen.cgColor
        layer?.cornerRadius = 9
        if let v = ai.vien {
            layer?.borderWidth = 1
            layer?.borderColor = v.cgColor
        }
        let n = NSTextField(wrappingLabelWithString: van)
        n.font = EideToken.fontUI
        n.textColor = ai == .heThong ? EideToken.Mau.muted : EideToken.Mau.text
        n.translatesAutoresizingMaskIntoConstraints = false
        addSubview(n)
        NSLayoutConstraint.activate([
            n.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            n.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            n.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            n.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
