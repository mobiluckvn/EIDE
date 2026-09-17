import AppKit

/// **Vùng phải — chỗ giám sát và tham gia.** THIET-KE-UI sheet 1, chủ sản phẩm duyệt 14/09/2026.
///
/// Ba khối xếp dọc, không bao giờ ẩn:
///
/// 1. **Đang làm** — dòng thời gian sự kiện sổ cái, mới nhất trên cùng.
/// 2. **Chờ anh** — mục ASK kèm cổng, quy tắc, lý do; duyệt/từ chối ngay tại chỗ.
/// 3. **Hoàn tác được** — việc tác tử đã tự làm, còn rút lại được, kèm hạn.
///
/// ## Vì sao ba khối này ở đây chứ không phải trong một màn
///
/// Trước 14/09, nhật ký là **mục số 22 của sidebar**: muốn biết tác tử đang làm gì thì phải rời
/// màn đang xem, bấm vào mục ấy, rồi bấm quay lại. Đó không phải giám sát — đó là tra cứu.
/// Người ngồi trông một tác tử tự chạy cần thấy nó **trong lúc** làm việc khác, và ba khối này
/// là ba câu hỏi họ hỏi liên tục: *nó đang làm gì · nó có đang chờ tôi không · tôi rút lại được
/// những gì*.
///
/// Hàng đợi cũng vậy. UXD-13 U2 nói nó luôn hiện, và bản cũ đặt nó ở đáy cột giữa — nơi nó bị
/// đẩy khuất ngay khi một màn chuyên đề mở ra.
public final class EideVungPhai: NSView {

    /// Khung nhìn Nhật ký — **màn S2**, không phải một khối của cột này.
    ///
    /// Giữ ở đây vì panel lấy nó qua `vungPhai.nhatKy` từ lâu, nhưng nó KHÔNG được thêm vào cột
    /// phải nữa. Lý do là một lỗi im lặng sống từ ngày màn Nhật ký ra đời: cùng một thể hiện
    /// `NSView` vừa được cột phải `addSubview`, vừa được panel `addSubview` để làm màn S2 — mà
    /// một view chỉ có MỘT cha, nên lần thêm thứ hai âm thầm kéo nó khỏi cột phải. Kết quả:
    /// tiêu đề "ĐANG LÀM" đứng trên một khoảng trống suốt cả phiên, và ràng buộc `cao ≥ 200`
    /// của nó thành một ràng buộc mồ côi. Mọi ảnh chụp từ 15/09 đều cho thấy khoảng trống ấy —
    /// tôi đọc qua chúng nhiều lần mà không hỏi vì sao chỗ đó rỗng.
    public let nhatKy = NhatKyView(frame: .zero)
    public let hangDoi = ReviewQueueView()

    /// Chiều rộng cố định. 300 px là chỗ vừa đủ cho `14:42  extract.atdf  287 fact` không xuống
    /// dòng — dòng thời gian mà xuống dòng thì mắt không quét dọc được nữa, và quét dọc là cách
    /// người ta đọc một danh sách đang chạy.
    public static let RONG: CGFloat = 300

    /// Khối ĐANG CHẠY — bản chiếu một dòng của thẻ Run (UXC-31 §2F.1).
    public let dangChay = EideDangChay()

    private let tieuDe1 = NSTextField(labelWithString: "ĐANG CHẠY")
    private let vach = NSBox()

    public override init(frame: NSRect) {
        super.init(frame: frame)
        dung()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func dung() {
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        tieuDe1.font = NSFont.boldSystemFont(ofSize: 11)
        tieuDe1.textColor = EideToken.Mau.muted
        vach.boxType = .separator

        for v in [tieuDe1, dangChay, vach, hangDoi] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let g = EideToken.space[1]
        NSLayoutConstraint.activate([
            tieuDe1.topAnchor.constraint(equalTo: topAnchor, constant: g),
            tieuDe1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),

            dangChay.topAnchor.constraint(equalTo: tieuDe1.bottomAnchor, constant: 2),
            dangChay.leadingAnchor.constraint(equalTo: leadingAnchor),
            dangChay.trailingAnchor.constraint(equalTo: trailingAnchor),

            vach.topAnchor.constraint(equalTo: dangChay.bottomAnchor, constant: g),
            vach.leadingAnchor.constraint(equalTo: leadingAnchor),
            vach.trailingAnchor.constraint(equalTo: trailingAnchor),

            hangDoi.topAnchor.constraint(equalTo: vach.bottomAnchor, constant: g),
            hangDoi.leadingAnchor.constraint(equalTo: leadingAnchor),
            hangDoi.trailingAnchor.constraint(equalTo: trailingAnchor),
            hangDoi.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Nhật ký chiếm phần trên, hàng đợi phần dưới — nhưng hàng đợi được ƯU TIÊN khi có
            // việc chờ: một mục ASK bị cắt mất nút Duyệt là một mục người dùng không trả lời
            // được, và tác tử đứng chờ vì một lỗi bố cục.
            hangDoi.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
        hangDoi.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? {
        "Giám sát: đang làm, chờ người, hoàn tác được"
    }
}
