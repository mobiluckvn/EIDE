import AppKit

/// **Một lượt trao đổi** — bong bóng, theo `.msg` của bản demo UX v2.0.
///
/// ## Vì sao bong bóng chứ không phải một dòng có tiền tố
///
/// Vùng trao đổi cũ là một khối văn bản nối chuỗi: `Anh: …` xuống dòng `EIDE: …` xuống dòng.
/// Nó đọc được, và nó bắt mắt người phải LÀM VIỆC để biết ai đang nói — đọc tiền tố ở đầu dòng,
/// rồi dò xem câu kết thúc ở đâu khi nó dài ba dòng. Trong một vùng cao 220 pt có bốn năm lượt,
/// việc ấy lặp lại liên tục.
///
/// Bong bóng trả lời câu "ai nói" bằng VỊ TRÍ và MÀU, trước khi người đọc chữ đầu tiên: người
/// bên phải nền đỏ nhạt, tác tử bên trái nền trắng có viền. Đó là lý do mọi giao diện trò chuyện
/// đều làm thế, và là thứ bản demo giữ lại khi bỏ hết những phần khác.
///
/// Rộng tối đa 78% để bong bóng có mép — một khối chữ chạm cả hai mép thì không còn là bong
/// bóng, và mắt lại phải đi tìm tiền tố.
public final class EideBongBong: NSView {

    /// Ai nói.
    public enum Ai {
        case nguoi, tacTu, cho, loi, heThong

        /// Nhãn cũ — giữ để `soLuotDeTest` và nhật ký đọc được như trước.
        public var nhan: String {
            switch self {
            case .nguoi: return "Anh"
            case .tacTu: return "EIDE"
            case .cho: return "Chờ anh"
            case .loi: return "Lỗi"
            case .heThong: return "·"
            }
        }

        var benPhai: Bool { self == .nguoi }

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

    private let nhan = NSTextField(wrappingLabelWithString: "")

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

        nhan.stringValue = van
        nhan.font = EideToken.fontUI
        nhan.textColor = ai == .heThong ? EideToken.Mau.muted : EideToken.Mau.text
        nhan.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nhan)
        NSLayoutConstraint.activate([
            nhan.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            nhan.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            nhan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            nhan.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
