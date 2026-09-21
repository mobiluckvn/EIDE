import AppKit
import EideLoi

/// **Modal ASK — UXC-31 §6.1 và §9.3.**
///
/// Tác tử muốn ghi một tệp người đang sửa dở → cổng trả ASK theo `P-EDIT-01`, và câu hỏi ấy
/// phải hiện thành một modal với **đúng hai lựa chọn**:
///
/// - "Lưu bản của tôi rồi tác tử tiếp tục"
/// - "Tác tử chờ — tôi sửa tiếp"
///
/// ## Vì sao không có lựa chọn thứ ba
///
/// §6.1 viết thẳng "Không lựa chọn thứ ba", và lý do nằm ở chỗ mọi lựa chọn thứ ba người ta hay
/// nghĩ ra đều là một cách mất việc: "để tác tử ghi đè" mất bản của người, "gộp tự động" là
/// đúng thứ merge 3 bên (§6.2) phải làm và phải làm ở chỗ khác, còn "bỏ qua" thì không nói được
/// ai thắng. Hai lựa chọn này phủ hết: hoặc bản của người vào trước, hoặc tác tử đứng lại.
///
/// ## §9.3 — Esc là lựa chọn AN TOÀN, không bao giờ là đồng ý
///
/// Người bấm Esc là người muốn thoát khỏi một hộp thoại, không phải người vừa cân nhắc xong.
/// Nối Esc vào "đồng ý" nghĩa là một phản xạ thoát ra trở thành một lần phê duyệt cho tác tử
/// ghi đè tệp — và họ sẽ không biết mình vừa duyệt gì.
///
/// Tiêu điểm cũng bị NHỐT trong modal: Tab chỉ chạy vòng giữa hai nút. Không nhốt thì Tab đi
/// tiếp ra cửa sổ phía sau, người dùng gõ Enter và kích hoạt một nút họ không nhìn thấy.
@MainActor
public final class EideModalHoi: NSView {

    /// `true` = người chọn vế THUẬN (lưu bản của tôi rồi tác tử tiếp tục).
    public var onChon: ((Bool) -> Void)?

    public static let NHAN_THUAN = "Lưu bản của tôi rồi tác tử tiếp tục"
    public static let NHAN_AN_TOAN = "Tác tử chờ — tôi sửa tiếp"

    private let tieuDe = NSTextField(labelWithString: "")
    private let than = NSTextField(wrappingLabelWithString: "")
    private let nutThuan = NSButton()
    private let nutAnToan = NSButton()
    private var maCho = ""

    /// Nhãn hai nút đang hiện — cho bài đo đếm, vì "đúng hai" là nội dung của §6.1.
    public var nhanNut: [String] { [nutThuan.title, nutAnToan.title] }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        isHidden = true

        tieuDe.font = NSFont.boldSystemFont(ofSize: 14)
        than.font = EideToken.fontUI
        than.textColor = EideToken.Mau.muted

        nutThuan.title = Self.NHAN_THUAN
        nutThuan.bezelStyle = .rounded
        nutThuan.font = NSFont.boldSystemFont(ofSize: 12)
        nutThuan.target = self
        nutThuan.action = #selector(_thuan)
        // KHÔNG gán `keyEquivalent = "\r"` cho vế thuận: Enter khi ấy thành nút mặc định, và
        // một phím Enter gõ vội duyệt cho tác tử ghi đè — cùng loại hỏng với Esc = đồng ý.
        nutAnToan.title = Self.NHAN_AN_TOAN
        nutAnToan.bezelStyle = .rounded
        nutAnToan.font = NSFont.boldSystemFont(ofSize: 12)
        nutAnToan.keyEquivalent = "\r"
        nutAnToan.target = self
        nutAnToan.action = #selector(_anToan)

        let hangNut = NSStackView(views: [nutAnToan, nutThuan])
        hangNut.orientation = .horizontal
        hangNut.spacing = 10

        let hop = NSStackView(views: [tieuDe, than, hangNut])
        hop.orientation = .vertical
        hop.alignment = .leading
        hop.spacing = 12
        hop.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        hop.wantsLayer = true
        hop.layer?.backgroundColor = EideToken.Mau.surface.cgColor
        hop.layer?.cornerRadius = 8
        hop.layer?.borderWidth = 2
        hop.layer?.borderColor = EideToken.Mau.warn.cgColor
        hop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hop)
        NSLayoutConstraint.activate([
            hop.centerXAnchor.constraint(equalTo: centerXAnchor),
            hop.topAnchor.constraint(equalTo: topAnchor, constant: 140),
            hop.widthAnchor.constraint(equalToConstant: 560),
            than.widthAnchor.constraint(equalToConstant: 520),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Mở modal cho một mục chờ `P-EDIT-01`.
    ///
    /// `tep` là tệp người đang sửa dở, `nil` khi cửa sổ này không mở tệp nào — và khi ấy câu hỏi
    /// phải NÓI RA điều đó thay vì hứa lưu một bộ đệm không tồn tại.
    public func mo(maCho: String, cap: String, tep: String?, vi: String) {
        self.maCho = maCho
        tieuDe.stringValue = "Tác tử muốn ghi tệp anh đang sửa dở"
        than.stringValue =
            "`\(cap)` định ghi \(tep.map { "`\($0)`" } ?? "một tệp trong dự án"), nhưng "
            + (tep != nil
               ? "bộ đệm của anh còn sửa chưa lưu."
               : "cửa sổ này không mở tệp nào đang sửa dở — bộ đệm bẩn nằm ở chỗ khác, nên chọn "
                 + "vế đầu sẽ chỉ cho tác tử chạy tiếp chứ không lưu hộ được gì.")
            + "\n\nCổng chặn theo P-EDIT-01\(vi.isEmpty ? "" : " — \(vi)")."
        nutThuan.title = tep != nil ? Self.NHAN_THUAN : "Tác tử cứ tiếp tục"
        isHidden = false
        window?.makeFirstResponder(nutAnToan)   // §9.3 — tiêu điểm ĐẦU ở vế an toàn
    }

    public func dong() {
        isHidden = true
        maCho = ""
        window?.makeFirstResponder(nil)
    }

    /// Mã mục chờ đang hỏi. Rỗng khi modal đóng.
    public var dangHoi: String { isHidden ? "" : maCho }

    // §9.3 — nhốt tiêu điểm: Tab chỉ chạy vòng giữa hai nút.
    public override var acceptsFirstResponder: Bool { !isHidden }

    public override func keyDown(with event: NSEvent) {
        guard !isHidden else { return super.keyDown(with: event) }
        if event.keyCode == 48 {    // Tab
            let ke = window?.firstResponder === nutAnToan ? nutThuan : nutAnToan
            window?.makeFirstResponder(ke)
            return
        }
        super.keyDown(with: event)
    }

    /// **Esc = vế AN TOÀN.** Không bao giờ = đồng ý.
    public override func cancelOperation(_ sender: Any?) { _anToan() }

    @objc private func _thuan() {
        dong()
        onChon?(true)
    }

    @objc private func _anToan() {
        dong()
        onChon?(false)
    }
}
