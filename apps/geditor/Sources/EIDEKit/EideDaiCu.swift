import AppKit

/// Dải **"Dữ liệu cũ — bấm để tải lại"** — bất biến B6 của UXC-31, tiêu chí nghiệm thu N6.
///
/// ## Vì sao một dải riêng chứ không phải một dòng trong hội thoại
///
/// Hội thoại cuộn: một câu "mất kết nối" trôi lên trên sau ba lượt và người đang đọc một bảng
/// số liệu không thấy nó. Dải này neo trên cùng vùng làm việc và ở nguyên đó tới khi hết cũ —
/// vì câu nó nói không phải về một lượt trao đổi, mà về MỌI thứ đang hiện trên màn.
///
/// ## Vì sao cần nói ra
///
/// Đây là bài học rút thẳng từ danh sách lỗi im lặng: một màn hiện dữ liệu của mười phút trước
/// mà không nói nó là của mười phút trước thì không khác gì một màn hiện số sai. Người dùng đọc
/// nó, tin nó, và ra quyết định dựa vào nó. Trạng thái "tôi không chắc" phải nhìn thấy được.
public final class EideDaiCu: NSView {

    /// Người bấm "tải lại".
    public var onTaiLai: (() -> Void)?

    /// Đang ở trạng thái cũ hay không — cho bài kiểm đọc mà không phải dò cây khung nhìn.
    public private(set) var dangCu = false

    private let nhan = NSTextField(labelWithString: "")
    private let nut = NSButton()
    private var caoRang: NSLayoutConstraint!

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? {
        dangCu ? "Dữ liệu trên màn đã cũ, bấm để tải lại" : nil
    }

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = EideToken.Mau.warnBg.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        nhan.font = EideToken.fontUI
        nhan.textColor = EideToken.Mau.warn
        nut.title = "Tải lại"
        nut.bezelStyle = .inline
        nut.font = EideToken.fontUI
        nut.target = self
        nut.action = #selector(taiLai)

        let hang = NSStackView(views: [nhan, nut])
        hang.orientation = .horizontal
        hang.spacing = EideToken.space[1]
        hang.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hang)
        caoRang = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            hang.leadingAnchor.constraint(equalTo: leadingAnchor, constant: EideToken.space[2]),
            hang.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor,
                                           constant: -EideToken.space[2]),
            hang.centerYAnchor.constraint(equalTo: centerYAnchor),
            caoRang,
        ])
        datCu(false, tre: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func taiLai() { onTaiLai?() }

    /// Bật/tắt dải. `tre` là số giây kể từ lần cuối nghe được daemon.
    ///
    /// Chiều cao 0 khi bình thường chứ không chỉ `isHidden`: trong một `NSStackView` thì hai
    /// cách tương đương, nhưng dải này neo bằng ràng buộc thường, và `isHidden` KHÔNG thu hồi
    /// chỗ — một dải ẩn vẫn ăn 28 pt của vùng làm việc suốt cả phiên.
    public func datCu(_ cu: Bool, tre: TimeInterval) {
        dangCu = cu
        caoRang.constant = cu ? 28 : 0
        nut.isHidden = !cu
        nhan.stringValue = cu
            ? "Dữ liệu cũ — không nghe được daemon \(Int(tre)) giây qua. Bấm để tải lại."
            : ""
        isHidden = !cu
    }
}
