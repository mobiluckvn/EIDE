import AppKit

/// Khối **ĐANG CHẠY** ở cột phải — UXC-31 §2F.1, bản chiếu một dòng của thẻ Run.
///
/// ## Vì sao là BẢN CHIẾU, không phải nguồn
///
/// Bất biến B7: mỗi câu hỏi của người dùng có đúng một nơi trả lời. *"Tác tử đang làm gì"* được
/// trả lời ở **thẻ Run** trong vùng trao đổi — nơi có đủ chuỗi bước, nút Dừng, nút Mở chi tiết.
/// Khối này chỉ chiếu lại một dòng, để người đang xem một màn chuyên đề vẫn liếc thấy có việc
/// đang chạy mà không phải cuộn xuống.
///
/// Nên nó KHÔNG giữ trạng thái riêng và không nghe sự kiện. Panel gọi `datDs` mỗi khi thẻ Run
/// đổi. Hai nguồn cho cùng một câu trả lời là cách chúng lệch nhau.
public final class EideDangChay: NSView {

    /// Người bấm một dòng — mở Nhật ký lọc theo mã lượt chạy.
    public var onChon: ((String) -> Void)?

    /// Số dòng đang hiện — cho bài kiểm đọc.
    public private(set) var soDong = 0

    private let cot = NSStackView()

    public override func accessibilityRole() -> NSAccessibility.Role? { .group }
    public override func accessibilityLabel() -> String? {
        soDong == 0 ? "Không có lượt chạy nào" : "\(soDong) lượt chạy đang chạy"
    }

    public init() {
        super.init(frame: .zero)
        cot.orientation = .vertical
        cot.alignment = .leading
        cot.spacing = 2
        cot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cot)
        NSLayoutConstraint.activate([
            cot.topAnchor.constraint(equalTo: topAnchor),
            cot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: EideToken.space[1]),
            cot.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor,
                                          constant: -EideToken.space[1]),
            cot.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        datDs([])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// `(mã lượt chạy, một dòng mô tả)`. Rỗng thì hiện lý do rỗng — B5: khối rỗng vẫn có mặt và
    /// vẫn nói, vì một khối biến mất khiến người dùng tưởng mình nhớ nhầm chỗ.
    public func datDs(_ ds: [(ma: String, dong: String)]) {
        for v in cot.arrangedSubviews { cot.removeArrangedSubview(v); v.removeFromSuperview() }
        soDong = ds.count
        if ds.isEmpty {
            let n = NSTextField(labelWithString: "Không có lượt chạy nào.")
            n.font = EideToken.fontUI
            n.textColor = EideToken.Mau.faint
            cot.addArrangedSubview(n)
            return
        }
        for (ma, dong) in ds {
            let b = NSButton(title: dong, target: self, action: #selector(bam(_:)))
            b.bezelStyle = .inline
            b.alignment = .left
            b.font = EideToken.fontUI
            b.contentTintColor = EideToken.Mau.info
            b.identifier = NSUserInterfaceItemIdentifier(ma)
            cot.addArrangedSubview(b)
        }
    }

    @objc private func bam(_ n: NSButton) {
        if let id = n.identifier?.rawValue { onChon?(id) }
    }
}
