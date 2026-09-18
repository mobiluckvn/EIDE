import AppKit
import EideLoi

/// **Vùng làm việc** — `#screen`: nền trắng, cuộn dọc, đệm 16×20.
///
/// Giữ MỘT màn mỗi lúc. Màn nào cũng có header chuẩn (§2C.4): tiêu đề 16 pt + dòng phụ ghi
/// NĂNG LỰC đứng sau. Không màn nào được thiếu dòng phụ — một màn không ghi được năng lực là
/// một màn hiện thứ gì đó mà không ai truy được nó từ đâu ra (phát hiện R6).
public final class EideVungLamViec: NSView {

    /// Trạng thái rỗng khi chưa mở màn nào — §2C.2.
    private let khiTrong = NSTextField(wrappingLabelWithString: "")
    private let tieuDe = NSTextField(labelWithString: "")
    private let nangLuc = NSTextField(labelWithString: "")
    private let than = NSStackView()
    private let cuon = NSScrollView()

    public private(set) var dangMo: String?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.surface.cgColor

        tieuDe.font = NSFont.boldSystemFont(ofSize: 16)
        tieuDe.textColor = EideToken.Mau.text
        nangLuc.font = EideToken.fontMono
        nangLuc.textColor = EideToken.Mau.muted
        // Dòng phụ KHÔNG được đòi bề rộng. Màn Trình soạn thảo có 16 năng lực đứng sau; nối
        // chúng bằng " · " ra một dòng dài ~2 000 pt, và NSWindow coi ràng buộc bắt buộc trong
        // `contentView` là ràng buộc của CHÍNH CỬA SỔ — cửa sổ nhảy từ 1456 lên 2482 pt ngay khi
        // tác tử tự mở màn ấy, rồi KHÔNG co lại. Đây đúng là cơ chế đã làm cửa sổ bản cũ nhích
        // dần 720 → 818 pt suốt nhiều ngày mà không ai truy ra nguyên nhân.
        nangLuc.lineBreakMode = .byTruncatingTail
        nangLuc.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for n in [tieuDe, khiTrong] {
            n.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        khiTrong.font = EideToken.fontUI
        khiTrong.textColor = EideToken.Mau.muted

        than.orientation = .vertical
        than.alignment = .leading
        than.spacing = 8
        than.translatesAutoresizingMaskIntoConstraints = false

        let coc = NSStackView(views: [tieuDe, nangLuc, khiTrong, than])
        coc.orientation = .vertical
        coc.alignment = .leading
        coc.spacing = 4
        coc.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        coc.translatesAutoresizingMaskIntoConstraints = false

        cuon.contentView = EideKhungLat()
        cuon.documentView = coc
        cuon.hasVerticalScroller = true
        cuon.drawsBackground = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cuon)
        NSLayoutConstraint.activate([
            cuon.topAnchor.constraint(equalTo: topAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor),
            cuon.trailingAnchor.constraint(equalTo: trailingAnchor),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor),
            coc.leadingAnchor.constraint(equalTo: cuon.contentView.leadingAnchor),
            coc.trailingAnchor.constraint(equalTo: cuon.contentView.trailingAnchor),
            coc.topAnchor.constraint(equalTo: cuon.contentView.topAnchor),
            // Bề rộng của `than` phải đến TỪ NGOÀI. Stack dọc căn `.leading` không kéo giãn khung
            // nhìn con, nên nếu màn bên trong lại lấy bề rộng theo `than` thì hai bên định nghĩa
            // lẫn nhau — một vòng tròn hợp lệ với Auto Layout, và nó giải ra giá trị NHỎ NHẤT.
            // Đo 18/09: bảng bốn cột co về ~190 pt, chữ tràn ra ngoài nền hàng, mọi cột sau cột
            // thứ hai rơi xuống dòng kế. Đủ chữ nên nó đọc như một kiểu trình bày xấu.
            than.widthAnchor.constraint(equalTo: coc.widthAnchor, constant: -40),
        ])
        dongMan()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Mở một màn: header chuẩn + thân rỗng chờ dữ liệu.
    public func moMan(_ tien: String, nangLucDs: [String]) {
        dangMo = tien
        tieuDe.stringValue = EideManHinhDS.nhan(tien)
        tieuDe.isHidden = false
        // Ba cái đầu, rồi đếm phần còn lại. Mười sáu tên năng lực nối bằng " · " là một dòng
        // không ai đọc; ba cái đầu cộng "+13 nữa" trả lời đúng câu hỏi người đặt ra ở đây —
        // *màn này lấy dữ liệu từ đâu* — và danh sách đủ nằm trong tooltip.
        nangLuc.stringValue = nangLucDs.isEmpty ? "—"
            : nangLucDs.prefix(3).joined(separator: " · ")
              + (nangLucDs.count > 3 ? " · +\(nangLucDs.count - 3) nữa" : "")
        nangLuc.toolTip = nangLucDs.isEmpty ? nil : nangLucDs.joined(separator: "\n")
        nangLuc.isHidden = false
        khiTrong.isHidden = true
        xoaThan()
    }

    public func dongMan() {
        dangMo = nil
        tieuDe.isHidden = true
        nangLuc.isHidden = true
        khiTrong.isHidden = false
        khiTrong.stringValue = "Vùng làm việc trống — chọn màn ở cột trái, "
            + "hoặc ra lệnh để tác tử tự mở đúng màn."
        xoaThan()
    }

    /// Trạng thái rỗng ĐÚNG HAI PHẦN — bất biến B5: lý do, rồi bước kế tiếp.
    public func khiRong(vi ly: String, buocKe: String) {
        xoaThan()
        let a = NSTextField(wrappingLabelWithString: "Màn này đang rỗng — vì: \(ly)")
        a.font = EideToken.fontUI
        a.textColor = EideToken.Mau.muted
        let b = NSTextField(wrappingLabelWithString: "Bước kế tiếp: \(buocKe)")
        b.font = EideToken.fontUI
        b.textColor = EideToken.Mau.faint
        themThan(a)
        themThan(b)
    }

    public func xoaThan() {
        for v in than.arrangedSubviews { than.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    public func themThan(_ v: NSView) {
        than.addArrangedSubview(v)
    }

    /// Số khung nhìn trong thân — cho bài kiểm đọc.
    public var soThan: Int { than.arrangedSubviews.count }

    /// Đặt màn thật vào thân. Một màn mỗi lúc; màn cũ bị gỡ hẳn khỏi cây khung nhìn.
    ///
    /// Giữ lại thể hiện cũ để "quay về tab trước" khỏi phải nạp lại là một tối ưu đắt giá: một
    /// NSView chỉ có MỘT cha, và một danh sách màn sống ngầm là cách bản cũ để một khung nhìn
    /// đăng ký hai chỗ rồi biến mất ở chỗ thứ nhất (lỗi im lặng 71).
    /// Màn đang nằm trong thân, nếu nó là một màn thật — cho bài đo đọc.
    public var manDangMo: EideManCoSo? { than.arrangedSubviews.compactMap { $0 as? EideManCoSo }.first }

    public func datMan(_ v: NSView) {
        xoaThan()
        themThan(v)
        v.widthAnchor.constraint(equalTo: than.widthAnchor).isActive = true
    }
}
