import AppKit
import GEditorCore

/// Hàng tiêu đề DÍNH khi cuộn file CSV (FR-CSV-402).
///
/// Việc thật nó giải: cuộn tới dòng 40.000 của một file có mười hai cột thì không ai nhớ cột
/// thứ chín là gì. Không có hàng tiêu đề dính, người dùng phải cuộn ngược lên đầu file để
/// đếm cột — và đếm nhầm là sửa nhầm dữ liệu.
///
/// Tự vẽ chứ không nhân bản một `NSTextView` thứ hai: nó chỉ có đúng một dòng, dùng đúng font
/// đơn cách của vùng soạn thảo, và một text view nữa sẽ kéo theo cả bộ máy bố cục cho một
/// dòng chữ.
final class CSVHeaderView: NSView {

    /// Chiều cao phần đệm trên/dưới quanh chữ.
    static let padding: CGFloat = 3

    private var attributed: NSAttributedString?
    /// Tên và phạm vi ngang của từng cột — dùng cho tooltip.
    private var columns: [(name: String, x: CGFloat, width: CGFloat)] = []

    /// Độ lệch ngang, bám theo thanh cuộn ngang của vùng soạn thảo.
    var horizontalOffset: CGFloat = 0 {
        didSet {
            guard horizontalOffset != oldValue else { return }
            needsDisplay = true
            rebuildTooltips()
        }
    }

    /// Lề trái, khớp với `textContainerInset` của vùng soạn thảo để chữ thẳng cột.
    var leftInset: CGFloat = 6

    override var isFlipped: Bool { true }
    /// Chuột đi thẳng xuống vùng soạn thảo — trừ tooltip, hàng này không nhận thao tác nào.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - VoiceOver (NFR-USE-03)
    //
    // Hàng tiêu đề dính là view TỰ VẼ, nên VoiceOver không thấy chữ trong đó. Với người dùng
    // VoiceOver, thông tin "cột nào là cột nào" chính là thứ hàng này tồn tại để nói ra —
    // giấu nó đi thì cả bảng CSV mất ngữ cảnh.
    //
    // `hitTest` trả `nil` KHÔNG ảnh hưởng: đó là chuyện của chuột, còn VoiceOver đi theo cây
    // accessibility chứ không theo phép thử điểm.

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityLabel() -> String? { L("Hàng tiêu đề cột") }

    override func accessibilityValue() -> Any? {
        guard !columns.isEmpty else { return L("Không có cột nào") }
        return columns.enumerated()
            .map { "\($0.offset + 1). \($0.element.name)" }
            .joined(separator: ", ")
    }

    /// Đặt nội dung hàng tiêu đề.
    ///
    /// `fields` là văn bản THÔ của từng field (còn nguyên dấu bọc nếu có) — vẽ đúng cái người
    /// dùng thấy ở dòng đầu file, không phải bản đã bỏ ngoặc. Hai thứ khác nhau thì hàng dính
    /// sẽ không thẳng cột với nội dung bên dưới.
    func setHeader(fields: [String], delimiter: Character, font: NSFont) {
        guard !fields.isEmpty else {
            attributed = nil
            columns = []
            needsDisplay = true
            return
        }

        let text = NSMutableAttributedString()
        var measured: [(String, CGFloat, CGFloat)] = []
        var x: CGFloat = 0

        for (index, field) in fields.enumerated() {
            let piece = NSAttributedString(string: field, attributes: [
                .font: font,
                .foregroundColor: Tokens.Color.rainbow(index),
            ])
            let width = piece.size().width
            measured.append((field, x, width))
            text.append(piece)
            x += width

            if index < fields.count - 1 {
                let separator = NSAttributedString(string: String(delimiter), attributes: [
                    .font: font,
                    .foregroundColor: Tokens.Color.secondaryInk,
                ])
                text.append(separator)
                x += separator.size().width
            }
        }

        attributed = text
        columns = measured.map { (name: $0.0, x: $0.1, width: $0.2) }
        needsDisplay = true
        rebuildTooltips()
    }

    override func draw(_ dirtyRect: NSRect) {
        // Nền CHROME chứ không phải nền vùng soạn thảo: hàng dính phải nhìn ra là một lớp
        // khác đang che chữ, không phải một dòng dữ liệu bình thường.
        Tokens.Color.chrome.setFill()
        bounds.fill()
        Tokens.Color.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()

        attributed?.draw(at: NSPoint(x: leftInset - horizontalOffset, y: Self.padding))
    }

    /// Tooltip cho từng cột: tên cột và số thứ tự.
    ///
    /// Số thứ tự đếm từ 1 vì mọi lệnh cột của app đều đếm từ 1 (xem "Xóa cột…"). Hai cách
    /// đếm trong cùng một ứng dụng là cách chắc chắn làm người dùng xoá nhầm cột.
    private func rebuildTooltips() {
        removeAllToolTips()
        for (index, column) in columns.enumerated() {
            let rect = NSRect(
                x: column.x + leftInset - horizontalOffset, y: 0,
                width: column.width, height: bounds.height
            )
            guard rect.maxX > 0, rect.minX < bounds.width else { continue }
            addToolTip(rect, owner: "Cột \(index + 1): \(column.name)" as NSString, userData: nil)
        }
    }

    // MARK: - Móc tự kiểm

    var headerTextForSelfTest: String { attributed?.string ?? "" }
    var columnCountForSelfTest: Int { columns.count }
    func columnColorForSelfTest(_ index: Int) -> NSColor? {
        guard let attributed, !columns.isEmpty, index < columns.count else { return nil }
        // Vị trí ký tự đầu của cột thứ `index` trong chuỗi đã dựng.
        var location = 0
        for previous in 0 ..< index {
            location += columns[previous].name.count + 1   // +1 cho dấu phân tách
        }
        guard location < attributed.length else { return nil }
        return attributed.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    override func layout() {
        super.layout()
        rebuildTooltips()
    }
}
