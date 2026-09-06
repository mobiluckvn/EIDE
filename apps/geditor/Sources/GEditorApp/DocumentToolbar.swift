import AppKit
import GEditorCore

/// Khung chung của mọi tài liệu — nằm ngay dưới thanh tab, giống nhau cho MỌI loại tệp.
///
/// ## Vì sao phải có nó
///
/// Trước đây mỗi chế độ View tự dựng thanh công cụ riêng: PDF hai hàng nút, bảng CSV một kiểu,
/// cây cấu trúc một kiểu, sơ đồ một kiểu. Người dùng mở một tệp mới là phải học lại chỗ bấm — và
/// với phần lớn loại tệp thì **không có chỗ bấm nào cả**, chế độ View chỉ vào được bằng phím tắt.
///
/// Một khung chung giải cả hai: cùng một chỗ, cùng một hình dạng, cho mọi tệp. Người dùng học
/// một lần.
///
/// ## Ba vùng, thứ tự cố định
///
/// 1. **Công tắc View / Code** — luôn ở mép trái, luôn cùng hình dạng. Đây là thứ người dùng
///    tìm, nên nó không bao giờ đổi chỗ theo loại tệp.
/// 2. **Tên của chế độ View** — «Trang PDF», «Bảng tính», «Cây JSON»… Nói ra View của tệp NÀY
///    là cái gì; không có nó thì công tắc mời người dùng sang một nơi họ không biết là nơi nào.
/// 3. **Hành động riêng của chế độ đang bật** — trang trước/sau của PDF, chọn sheet của Excel,
///    ô lọc của cây. Chúng khác nhau theo loại tệp, nhưng **chỗ đứng thì không**.
final class DocumentToolbar: NSView {

    static let height: CGFloat = 34

    /// Người dùng bấm công tắc. `true` = muốn sang View.
    var onSwitch: ((Bool) -> Void)?

    private let modeSwitch = NSSegmentedControl(
        labels: ["View", "Code"], trackingMode: .selectOne, target: nil, action: nil)
    private let kindLabel = NSTextField(labelWithString: "")
    /// Chỗ cho hành động riêng của từng chế độ — mỗi lần đổi tài liệu thì đổ lại.
    private let actions = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Vạch phân cách với vùng bên dưới — cùng lý do với sidebar: hai vùng cùng tông màu trôi
    /// vào nhau thì mắt phải tự đoán mép.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Tokens.Color.separator.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }

    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        modeSwitch.target = self
        modeSwitch.action = #selector(switchChanged)
        modeSwitch.controlSize = .small
        modeSwitch.segmentStyle = .rounded
        modeSwitch.translatesAutoresizingMaskIntoConstraints = false
        modeSwitch.setAccessibilityLabel(L("Chế độ hiển thị"))

        kindLabel.font = Tokens.Font.caption
        kindLabel.textColor = Tokens.Color.secondaryInk
        kindLabel.lineBreakMode = .byTruncatingTail
        kindLabel.translatesAutoresizingMaskIntoConstraints = false

        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = Tokens.Metrics.spacing(2)
        actions.translatesAutoresizingMaskIntoConstraints = false

        addSubview(modeSwitch)
        addSubview(kindLabel)
        addSubview(actions)

        let inset = Tokens.Metrics.spacing(3)
        NSLayoutConstraint.activate([
            modeSwitch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            modeSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),

            kindLabel.leadingAnchor.constraint(
                equalTo: modeSwitch.trailingAnchor, constant: inset),
            kindLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            actions.leadingAnchor.constraint(
                greaterThanOrEqualTo: kindLabel.trailingAnchor, constant: inset),
            actions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            actions.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - Đổ trạng thái

    /// Cập nhật khung theo tài liệu đang mở.
    ///
    /// - Parameters:
    ///   - kind: tên chế độ View của tệp này, ví dụ «Trang PDF». Rỗng = tệp không có View.
    ///   - inView: đang ở chế độ View hay Code.
    ///   - canToggle: tệp này có hai chế độ không.
    func present(kind: String, inView: Bool, canToggle: Bool) {
        modeSwitch.setEnabled(canToggle, forSegment: 0)
        modeSwitch.selectedSegment = inView ? 0 : 1
        modeSwitch.isEnabled = canToggle
        // Tệp một chế độ thì nói thẳng ra, chứ không để một công tắc mờ không lời giải thích.
        kindLabel.stringValue = canToggle
            ? kind
            : L("Tệp này chỉ có một chế độ hiển thị")
        modeSwitch.toolTip = canToggle
            ? L("Đổi giữa View và Code (⌥⌘V)")
            : L("Tệp này chỉ có một chế độ hiển thị")
    }

    /// Đặt lại nhóm nút riêng của chế độ đang bật.
    ///
    /// Nhận VIEW chứ không nhận danh sách nút: mỗi chế độ tự biết nó cần gì, và khung chung
    /// không nên biết PDF có bao nhiêu nút. Cái nó áp đặt là CHỖ ĐỨNG và khoảng cách.
    func setActions(_ views: [NSView]) {
        for old in actions.arrangedSubviews {
            actions.removeArrangedSubview(old)
            old.removeFromSuperview()
        }
        for view in views { actions.addArrangedSubview(view) }
    }

    @objc private func switchChanged() {
        onSwitch?(modeSwitch.selectedSegment == 0)
    }

    // MARK: - Cửa cho bài tự kiểm

    var selectedIsViewForSelfTest: Bool { modeSwitch.selectedSegment == 0 }
    var isEnabledForSelfTest: Bool { modeSwitch.isEnabled }
    var kindForSelfTest: String { kindLabel.stringValue }
    var actionCountForSelfTest: Int { actions.arrangedSubviews.count }

    /// Bấm vào một nửa của công tắc đúng như người dùng bấm.
    func clickForSelfTest(view: Bool) {
        guard modeSwitch.isEnabled else { return }
        modeSwitch.selectedSegment = view ? 0 : 1
        switchChanged()
    }
}
