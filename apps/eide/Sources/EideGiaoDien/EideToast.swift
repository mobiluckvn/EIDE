import AppKit
import EideLoi

/// **Toast kết quả cổng** — UXC-31 §4.3.
///
/// Gọi một năng lực từ bảng lệnh thì kết quả người cần thấy trước nhất không phải dữ liệu trả
/// về, mà là **cổng chính sách đã quyết gì**: APPROVE / ASK / DENY kèm mã quy tắc. Đó là câu
/// trả lời cho "vì sao lệnh của tôi không chạy" — và không có nó thì một lệnh bị DENY trông y
/// hệt một lệnh chạy xong lặng lẽ.
///
/// Toast chứ không bong bóng trong vùng trao đổi: bảng lệnh là một lớp phủ giữa màn hình, và
/// người vừa dùng nó đang nhìn vào giữa màn hình. Một dòng chữ xuất hiện ở đáy cửa sổ, trong
/// một khung đang cuộn, là một dòng họ không thấy.
///
/// **Tự tắt sau `GIAY`, nhưng không nuốt mất nội dung**: mọi toast đồng thời được ghi một dòng
/// vào vùng trao đổi, nên thứ vừa chớp qua vẫn đọc lại được. Một thông báo chỉ tồn tại năm giây
/// là một thông báo người dùng không có cách nào xem lại.
@MainActor
public final class EideToast: NSView {

    /// Bao lâu thì tự tắt.
    public static let GIAY: TimeInterval = 5

    private let nhan = NSTextField(labelWithString: "")
    private var hen: Timer?

    /// Chữ đang hiện — cho bài đo đọc. Rỗng khi đang ẩn.
    public var chu: String { isHidden ? "" : nhan.stringValue }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        isHidden = true

        nhan.font = NSFont.boldSystemFont(ofSize: 12)
        nhan.maximumNumberOfLines = 3
        nhan.lineBreakMode = .byWordWrapping
        nhan.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nhan)
        NSLayoutConstraint.activate([
            nhan.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            nhan.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            nhan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nhan.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Hiện một quyết định cổng. `dec` là trường `decision` của `caps.invoke`.
    public func hien(_ dec: [String: Any], cap: String) {
        nhan.stringValue = Self.cau(dec, cap: cap)
        let q = (dec["decision"] as? String)?.uppercased() ?? ""
        let mau: NSColor = q == "APPROVE" ? EideToken.Mau.ok
                         : (q == "ASK" ? EideToken.Mau.warn : EideToken.Mau.bad)
        let nen: NSColor = q == "APPROVE" ? EideToken.Mau.okBg
                         : (q == "ASK" ? EideToken.Mau.warnBg : EideToken.Mau.badBg)
        nhan.textColor = mau
        layer?.backgroundColor = nen.cgColor
        layer?.borderColor = mau.cgColor
        isHidden = false
        hen?.invalidate()
        hen = Timer.scheduledTimer(withTimeInterval: Self.GIAY, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.an() }
        }
    }

    public func an() {
        hen?.invalidate()
        hen = nil
        isHidden = true
    }

    /// Một dòng đọc được từ quyết định cổng.
    ///
    /// **Thiếu trường thì nói thiếu, không bỏ trống.** Một toast ghi "DENY" trần trụi không cho
    /// người dùng đường nào đi tiếp; mã quy tắc là thứ họ tra được trong POL-17, còn lý do là
    /// thứ họ đọc được ngay.
    public static func cau(_ dec: [String: Any], cap: String) -> String {
        let q = (dec["decision"] as? String)?.uppercased() ?? "KHÔNG RÕ"
        let luat = (dec["rule"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "không rõ quy tắc"
        let cong = (dec["gate"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let vi = (dec["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return "\(q) · `\(cap)`\(cong.map { " · cổng \($0)" } ?? "") · \(luat)"
             + (vi.map { " — \($0)" } ?? "")
    }
}
