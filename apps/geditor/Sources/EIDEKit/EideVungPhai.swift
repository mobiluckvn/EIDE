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

    public let nhatKy = NhatKyView(frame: .zero)
    public let hangDoi = ReviewQueueView()

    /// Chiều rộng cố định. 300 px là chỗ vừa đủ cho `14:42  extract.atdf  287 fact` không xuống
    /// dòng — dòng thời gian mà xuống dòng thì mắt không quét dọc được nữa, và quét dọc là cách
    /// người ta đọc một danh sách đang chạy.
    public static let RONG: CGFloat = 300

    private let tieuDe1 = NSTextField(labelWithString: "ĐANG LÀM")
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

        for v in [tieuDe1, nhatKy, vach, hangDoi] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        let g = EideToken.space[1]
        NSLayoutConstraint.activate([
            tieuDe1.topAnchor.constraint(equalTo: topAnchor, constant: g),
            tieuDe1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: g),

            nhatKy.topAnchor.constraint(equalTo: tieuDe1.bottomAnchor, constant: 2),
            nhatKy.leadingAnchor.constraint(equalTo: leadingAnchor),
            nhatKy.trailingAnchor.constraint(equalTo: trailingAnchor),

            vach.topAnchor.constraint(equalTo: nhatKy.bottomAnchor, constant: g),
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
            nhatKy.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        // Nhật ký nhường chỗ trước khi hàng đợi phải nhường.
        nhatKy.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        hangDoi.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? {
        "Giám sát: đang làm, chờ người, hoàn tác được"
    }
}
