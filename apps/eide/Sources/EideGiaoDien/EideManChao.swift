import AppKit
import EideLoi

/// **Màn hình chào** — UXC-31 §3.1, trả lời phát hiện R2 của bản rà soát.
///
/// Workspace chưa có dự án nào thì TOÀN MÀN là màn này: một câu chào, một đoạn giải thích trạng
/// thái rỗng, một ô gợi ý, và ĐÚNG MỘT nút chính. Không menu, không cột phải.
///
/// ## Vì sao đúng một nút
///
/// Người vừa cài xong có đúng một việc phải làm. Mọi nút thứ hai ở màn này là một ngã rẽ họ
/// phải cân nhắc trước khi biết sản phẩm làm gì — và đó là chỗ người ta đóng ứng dụng lại.
///
/// Đây cũng là trạng thái rỗng lớn nhất của sản phẩm, nên nó phải theo đúng luật B5 như mọi
/// trạng thái rỗng khác: nói LÝ DO rỗng, rồi nói BƯỚC KẾ TIẾP.
public final class EideManChao: NSView {

    /// Người bấm tạo dự án, kèm câu mô tả họ vừa gõ (có thể rỗng).
    public var onTao: ((String) -> Void)?

    private let o = NSTextField()
    private let nut = NSButton()
    private let nhanTt = NSTextField(labelWithString: "")

    /// Đang tạo dự án hay không. Cửa duy nhất chặn bấm hai lần — `project.create` không phải
    /// lệnh bình thường: bấm đúp sinh hai thư mục, và cái thứ hai người dùng không biết là mình
    /// đã tạo.
    private var dangBan = false

    /// Câu gợi ý đang hiện — cho bài kiểm đọc.
    public private(set) var goiY = ""

    /// Ba lệnh mẫu CHẠY ĐƯỢC THẬT, xoay vòng (§3.4). Không phải ví dụ trừu tượng: mỗi câu là
    /// một dự án nhúng có thật, để người gõ theo mà không phải nghĩ.
    public static let MAU = [
        "robot hai bánh tự cân bằng trên ATmega328P",
        "đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART",
        "nhấp nháy LED và đo dòng tiêu thụ trên ESP32-C3",
    ]

    public init(goiY: String = MAU[0]) {
        self.goiY = goiY
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.bg.cgColor

        let chao = NSTextField(labelWithString: "Chào mừng đến EIDE")
        chao.font = NSFont.boldSystemFont(ofSize: 19)

        let ly = NSTextField(wrappingLabelWithString:
            "Chưa có dự án nào trong workspace. Đây là trạng thái rỗng có LÝ DO và BƯỚC KẾ TIẾP "
            + "— quy tắc của mọi màn trong EIDE.")
        ly.font = EideToken.fontUI
        ly.textColor = EideToken.Mau.muted

        let g = NSTextField(wrappingLabelWithString:
            "Bước kế tiếp: mô tả dự án bằng MỘT câu — ví dụ \"\(goiY)\".")
        g.font = EideToken.fontUI
        g.textColor = EideToken.Mau.faint

        o.placeholderString = goiY
        o.font = EideToken.fontUI
        o.target = self
        o.action = #selector(_tao)

        nut.title = "Tạo dự án đầu tiên"
        nut.target = self
        nut.action = #selector(_tao)
        nut.bezelStyle = .rounded
        nut.keyEquivalent = "\r"
        nut.font = NSFont.boldSystemFont(ofSize: 13)

        nhanTt.font = EideToken.fontUI
        nhanTt.textColor = EideToken.Mau.bad
        nhanTt.isHidden = true

        let hop = NSStackView(views: [chao, ly, g, o, nut, nhanTt])
        hop.orientation = .vertical
        hop.alignment = .leading
        hop.spacing = 12
        hop.edgeInsets = NSEdgeInsets(top: 26, left: 30, bottom: 26, right: 30)
        hop.wantsLayer = true
        hop.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        hop.layer?.cornerRadius = 12
        hop.layer?.borderWidth = 1
        hop.layer?.borderColor = EideToken.Mau.border.cgColor
        hop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hop)
        NSLayoutConstraint.activate([
            hop.centerXAnchor.constraint(equalTo: centerXAnchor),
            hop.centerYAnchor.constraint(equalTo: centerYAnchor),
            hop.widthAnchor.constraint(equalToConstant: 520),
            o.widthAnchor.constraint(equalTo: hop.widthAnchor, constant: -60),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Báo lại cho người: đang tạo, hoặc vì sao không tạo được. Mở khoá nút khi hết bận, nếu
    /// không một lần hỏng là màn này chết vĩnh viễn.
    public func datTrangThai(_ van: String, ban: Bool) {
        dangBan = ban
        nut.isEnabled = !ban
        nhanTt.stringValue = van
        nhanTt.isHidden = van.isEmpty
        nhanTt.textColor = ban ? EideToken.Mau.muted : EideToken.Mau.bad
    }

    @objc private func _tao() {
        guard !dangBan else { return }
        let v = o.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ô rỗng thì dùng chính câu gợi ý, KHÔNG gửi chuỗi rỗng: `project.create` sẽ tạo một dự
        // án tên "" ở đâu đó, và người dùng có một thư mục rác mà không biết vì sao.
        onTao?(v.isEmpty ? goiY : v)
    }
}
