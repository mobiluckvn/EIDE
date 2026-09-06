import AppKit
import GEditorCore

/// Hàng ô lọc dưới tiêu đề cột của Table view (FR-QRY-002).
///
/// Mỗi cột một ô; gõ vào đó là lọc ngay, không cần biết SQL. Đây là tầng thấp nhất trong ba
/// tầng truy vấn mà đặc tả đặt ra, và là tầng duy nhất người dùng văn phòng chạm tới hằng ngày.
///
/// Thanh riêng, không nhét vào `NSTableHeaderView`: header của AppKit vẽ nhãn cột căn giữa
/// theo chiều cao của chính nó, nên cao gấp đôi lên thì chữ tiêu đề rơi vào giữa ô lọc. Thanh
/// riêng bám theo độ cuộn ngang — đúng cách hàng tiêu đề dính ở chế độ văn bản đang làm.
final class CSVFilterBar: NSView {

    static let height: CGFloat = 28

    /// Người dùng vừa đổi nội dung một ô. Chỗ gọi gom lại rồi chạy lọc.
    var onChange: (() -> Void)?

    /// Ô lọc theo cột LOGIC.
    private var fields: [Int: NSTextField] = [:]
    /// Vị trí ngang của từng cột logic, tính trong tọa độ của bảng.
    private var columnFrames: [(column: Int, x: CGFloat, width: CGFloat)] = []

    /// Độ lệch ngang, bám theo thanh cuộn của bảng.
    var horizontalOffset: CGFloat = 0 {
        didSet {
            guard horizontalOffset != oldValue else { return }
            layoutFields()
        }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)
    }

    required init?(coder: NSCoder) { nil }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }


    /// Dựng lại các ô theo bố cục cột hiện hành.
    ///
    /// Giữ NGUYÊN nội dung người dùng đã gõ cho những cột còn đó: ẩn một cột khác hay cuộn
    /// ngang không phải lý do để xóa bộ lọc họ vừa đặt.
    func setColumns(_ columns: [(column: Int, x: CGFloat, width: CGFloat)], font: NSFont) {
        columnFrames = columns
        let wanted = Set(columns.map(\.column))

        for (column, field) in fields where !wanted.contains(column) {
            field.removeFromSuperview()
            fields.removeValue(forKey: column)
        }
        for entry in columns where fields[entry.column] == nil {
            let field = NSTextField()
            field.font = font
            field.placeholderString = L("lọc…")
            field.isBordered = true
            field.bezelStyle = .roundedBezel
            field.controlSize = .small
            field.target = self
            field.action = #selector(fieldChanged)
            field.delegate = self
            addSubview(field)
            fields[entry.column] = field
        }
        layoutFields()
    }

    private func layoutFields() {
        for entry in columnFrames {
            guard let field = fields[entry.column] else { continue }
            field.frame = NSRect(
                x: entry.x - horizontalOffset + 2, y: 3,
                width: max(20, entry.width - 4), height: Self.height - 6
            )
            // Ô nằm ngoài khung nhìn vẫn tồn tại (giữ nội dung) nhưng không vẽ.
            field.isHidden = field.frame.maxX < 0 || field.frame.minX > bounds.width
        }
    }

    override func layout() {
        super.layout()
        layoutFields()
    }

    @objc private func fieldChanged() { onChange?() }

    /// Nội dung tất cả ô đang có chữ, theo cột logic.
    var texts: [Int: String] {
        fields.compactMapValues { field in
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : field.stringValue
        }
    }

    var isEmpty: Bool { texts.isEmpty }

    /// Xóa mọi ô lọc.
    ///
    /// - Parameter notify: báo cho chỗ gọi chạy lại phép lọc. Khi nạp một tài liệu KHÁC thì
    ///   không báo — bảng sắp dựng lại từ đầu, và chạy lọc trên trạng thái nửa vời là thừa.
    func clear(notify: Bool = true) {
        for field in fields.values { field.stringValue = "" }
        if notify { onChange?() }
    }

    // MARK: - Móc tự kiểm

    func setTextForSelfTest(_ text: String, column: Int) {
        fields[column]?.stringValue = text
        onChange?()
    }

    var fieldCountForSelfTest: Int { fields.count }
}

extension CSVFilterBar: NSTextFieldDelegate {

    /// Lọc theo từng phím gõ, không chờ Enter.
    ///
    /// Đó là điều làm nên chữ "tương tác" trong tên yêu cầu: người dùng thấy tập kết quả hẹp
    /// dần trong lúc gõ và dừng lại khi vừa đủ. Chỗ gọi chịu trách nhiệm không để mỗi phím
    /// thành một lượt quét cả file — xem `CSVFilter.rows(prefix:)`.
    func controlTextDidChange(_ notification: Notification) {
        onChange?()
    }
}
