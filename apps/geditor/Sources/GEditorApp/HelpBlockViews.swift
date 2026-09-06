import AppKit
import GEditorCore

/// Dựng từng khối của một trang trợ giúp thành `NSView`.
///
/// **Vì sao là một chồng view chứ không phải một `NSAttributedString` trong `NSTextView`.**
/// Hướng chuỗi thuộc tính gọn hơn nhiều — cho tới lúc gặp bảng. `NSTextTable` dựng được bảng
/// nhưng chiều rộng cột thì gần như không điều khiển nổi, và một bảng phím tắt bị cột đầu ngốn
/// hết chỗ là bảng không đọc được. Thêm nữa, khối mã cần một nút **Chép** — một nút thật, không
/// phải một vùng chữ giả vờ làm nút.
///
/// **Chiều rộng cột tính theo TỈ LỆ của khung nội dung**, không theo nội dung. Để AppKit tự chia
/// theo nội dung thì hai bảng cạnh nhau trong cùng một trang sẽ có mép cột lệch nhau, và mắt
/// người đọc bảng bắt được ngay sự lệch ấy dù không gọi tên được nó.
enum HelpBlockViews {

    /// Bề rộng cột chữ. Không để nội dung giãn hết cửa sổ: một dòng văn dài quá khoảng 90 ký tự
    /// thì mắt lạc dòng khi xuống hàng, và cửa sổ trợ giúp thường bị kéo rộng hết màn hình.
    static let contentWidth: CGFloat = 660

    static func views(
        for blocks: [HelpBlock],
        book: HelpBook,
        onNavigate: @escaping (String) -> Void
    ) -> [NSView] {
        blocks.map { view(for: $0, book: book, onNavigate: onNavigate) }
    }

    private static func view(
        for block: HelpBlock, book: HelpBook, onNavigate: @escaping (String) -> Void
    ) -> NSView {
        switch block {
        case let .paragraph(text):
            return label(text, font: Tokens.Font.ui)
        case let .heading(text):
            let view = label(text, font: NSFont.systemFont(ofSize: 15, weight: .semibold))
            view.textColor = Tokens.Color.ember
            return view
        case let .bullets(items):
            return list(items, marker: { _ in "•" })
        case let .steps(items):
            return list(items, marker: { "\($0 + 1)." })
        case let .table(headers, rows):
            return table(headers: headers, rows: rows)
        case let .shortcuts(items):
            return shortcuts(items)
        case let .code(language, caption, source):
            return code(language: language, caption: caption, source: source)
        case let .note(text):
            return callout(text, accent: Tokens.Color.action, title: L("Lưu ý"))
        case let .warning(text):
            return callout(text, accent: Tokens.Color.error, title: L("Cẩn thận"))
        case let .seeAlso(ids):
            return seeAlso(ids, book: book, onNavigate: onNavigate)
        }
    }

    // MARK: - Chữ

    /// Nhãn nhiều dòng dựng từ ký hiệu nội tuyến của `HelpInline`.
    private static func label(_ text: String, font: NSFont) -> NSTextField {
        let field = NSTextField(labelWithAttributedString: attributed(text, font: font))
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.preferredMaxLayoutWidth = contentWidth
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    /// `color` là màu của phần chữ thường. Phần `` `mã` `` luôn mang màu nhấn riêng, trừ khi
    /// chính chữ thường đã dùng màu ấy — tiêu đề trang là trường hợp đó, và hai màu bằng nhau ở
    /// đấy là đúng ý: một chữ trong tiêu đề đổi màu chỉ vì nó nằm trong dấu nháy trông như lỗi.
    static func attributed(
        _ text: String, font: NSFont, color: NSColor = .labelColor
    ) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        // Chữ Việt có dấu chồng hai tầng (`ệ`, `ỡ`) nên cần nhiều chỗ hơn giữa hai dòng so với
        // mặc định của hệ thống; thiếu chỗ thì dấu của dòng dưới chạm chân dòng trên.
        for run in HelpInline.runs(text) {
            let attributes: [NSAttributedString.Key: Any]
            switch run.style {
            case .plain:
                attributes = [.font: font, .foregroundColor: color,
                              .paragraphStyle: paragraph]
            case .strong:
                let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                attributes = [.font: bold, .foregroundColor: color,
                              .paragraphStyle: paragraph]
            case .code:
                attributes = [
                    .font: Tokens.Font.monoInline(size: font.pointSize - 1),
                    .foregroundColor: color == .labelColor ? Tokens.Color.ember : color,
                    .paragraphStyle: paragraph,
                ]
            }
            out.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return out
    }

    // MARK: - Danh sách

    private static func list(_ items: [String], marker: (Int) -> String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, item) in items.enumerated() {
            let bullet = NSTextField(labelWithString: marker(index))
            bullet.font = Tokens.Font.ui
            bullet.textColor = Tokens.Color.secondaryInk
            bullet.alignment = .right
            bullet.translatesAutoresizingMaskIntoConstraints = false
            bullet.widthAnchor.constraint(equalToConstant: 22).isActive = true

            let body = label(item, font: Tokens.Font.ui)
            body.preferredMaxLayoutWidth = contentWidth - 32

            let row = NSStackView(views: [bullet, body])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 10
            row.translatesAutoresizingMaskIntoConstraints = false
            body.widthAnchor.constraint(equalToConstant: contentWidth - 32).isActive = true
            stack.addArrangedSubview(row)
        }
        return stack
    }

    // MARK: - Bảng

    /// Tỉ lệ bề rộng cột.
    ///
    /// Cột đầu hẹp hơn có chủ ý: ở gần như mọi bảng trong sách này, cột đầu là tên lệnh hoặc ký
    /// hiệu còn cột sau là câu giải thích.
    private static func widths(columns: Int) -> [CGFloat] {
        switch columns {
        case 1: return [1.0]
        case 2: return [0.34, 0.66]
        case 3: return [0.26, 0.30, 0.44]
        default: return Array(repeating: 1.0 / CGFloat(columns), count: columns)
        }
    }

    private static func table(headers: [String], rows: [[String]]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let fractions = widths(columns: headers.count)
        let bold = NSFont.systemFont(ofSize: 12, weight: .semibold)

        stack.addArrangedSubview(tableRow(headers, fractions: fractions, font: bold))
        stack.addArrangedSubview(hairline(strong: true))
        for (index, row) in rows.enumerated() {
            stack.addArrangedSubview(
                tableRow(row, fractions: fractions, font: NSFont.systemFont(ofSize: 12))
            )
            if index < rows.count - 1 { stack.addArrangedSubview(hairline(strong: false)) }
        }
        return stack
    }

    private static func tableRow(
        _ cells: [String], fractions: [CGFloat], font: NSFont
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        row.translatesAutoresizingMaskIntoConstraints = false

        // Trừ đi phần khoảng cách giữa các cột, nếu không thì tổng bề rộng vượt khung và cột
        // cuối bị đẩy ra ngoài mép phải.
        let gaps = CGFloat(max(0, cells.count - 1)) * 12
        let usable = contentWidth - gaps

        for (index, cell) in cells.enumerated() {
            let fraction = index < fractions.count ? fractions[index] : 1.0 / CGFloat(cells.count)
            let width = (usable * fraction).rounded(.down)
            let field = label(cell, font: font)
            field.preferredMaxLayoutWidth = width
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
            row.addArrangedSubview(field)
        }
        return row
    }

    private static func hairline(strong: Bool) -> NSView {
        let line = NSView()
        line.applyLayerBackground(
            strong ? Tokens.Color.separator.withAlphaComponent(0.5) : Tokens.Color.separator
        )
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return line
    }

    // MARK: - Phím tắt

    /// Bảng phím là loại riêng vì cột phím phải là **bề rộng cố định** và dùng phông mã.
    ///
    /// Ký hiệu `⌥⌘←` và `F2` chênh nhau rất nhiều về bề ngang; để chúng tự co giãn thì mỗi hàng
    /// một mép, và mắt không quét dọc được nữa.
    private static func shortcuts(_ items: [HelpShortcut]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let keys = NSTextField(labelWithString: item.keys)
            keys.font = Tokens.Font.monoInline(size: 12)
            keys.alignment = .center
            keys.translatesAutoresizingMaskIntoConstraints = false
            keys.applyLayerBackground(Tokens.Color.chrome)
            keys.layer?.cornerRadius = 5
            keys.layer?.borderWidth = 1
            keys.layer?.borderColor = Tokens.Color.separator.cgColor
            keys.widthAnchor.constraint(equalToConstant: 110).isActive = true
            keys.heightAnchor.constraint(equalToConstant: 22).isActive = true

            let action = label(item.action, font: Tokens.Font.ui)
            let width = contentWidth - 110 - 12
            action.preferredMaxLayoutWidth = width
            action.widthAnchor.constraint(equalToConstant: width).isActive = true

            let row = NSStackView(views: [keys, action])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            row.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(row)
        }
        return stack
    }

    // MARK: - Khối mã

    private static func code(language: String, caption: String, source: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        if !caption.isEmpty {
            let captionLabel = label(caption, font: Tokens.Font.caption)
            captionLabel.textColor = Tokens.Color.secondaryInk
            stack.addArrangedSubview(captionLabel)
        }

        let box = NSView()
        box.applyLayerBackground(Tokens.Color.chrome)
        box.layer?.cornerRadius = Tokens.Metrics.cornerControl
        // Viền mảnh, không phải để trang trí: ở nền TỐI thì `chrome` và nền trang chênh nhau
        // vài phần trăm độ sáng, và khối mã tan hẳn vào trang — ảnh chụp đầu tiên cho thấy đúng
        // thế. Viền vẽ ra cái hộp mà màu nền không vẽ nổi.
        box.layer?.borderWidth = 1
        box.layer?.borderColor = Tokens.Color.separator.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false

        let text = NSTextField(labelWithString: source)
        text.font = Tokens.Font.editor(size: 12)
        text.isSelectable = true
        text.lineBreakMode = .byWordWrapping
        text.maximumNumberOfLines = 0
        text.preferredMaxLayoutWidth = contentWidth - 32 - 70
        text.translatesAutoresizingMaskIntoConstraints = false

        let badge = NSTextField(labelWithString: language)
        badge.font = Tokens.Font.caption
        badge.textColor = Tokens.Color.secondaryInk
        badge.translatesAutoresizingMaskIntoConstraints = false

        let copy = HelpCopyButton(source: source)

        box.addSubview(text)
        box.addSubview(badge)
        box.addSubview(copy)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: contentWidth),
            text.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            text.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
            text.trailingAnchor.constraint(lessThanOrEqualTo: copy.leadingAnchor, constant: -12),
            copy.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            copy.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
            badge.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            badge.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
        ])
        stack.addArrangedSubview(box)
        return stack
    }

    // MARK: - Hộp lưu ý

    private static func callout(_ text: String, accent: NSColor, title: String) -> NSView {
        let box = NSView()
        box.applyLayerBackground(accent.withAlphaComponent(0.08))
        box.layer?.cornerRadius = Tokens.Metrics.cornerControl
        box.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSView()
        bar.applyLayerBackground(accent)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let heading = NSTextField(labelWithString: title.uppercased())
        heading.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        heading.textColor = accent
        heading.translatesAutoresizingMaskIntoConstraints = false

        let body = label(text, font: Tokens.Font.ui)
        body.preferredMaxLayoutWidth = contentWidth - 44

        box.addSubview(bar)
        box.addSubview(heading)
        box.addSubview(body)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: contentWidth),
            bar.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            bar.topAnchor.constraint(equalTo: box.topAnchor),
            bar.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 3),
            heading.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            heading.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            body.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            body.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            body.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            body.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])
        return box
    }

    // MARK: - Xem thêm

    private static func seeAlso(
        _ ids: [String], book: HelpBook, onNavigate: @escaping (String) -> Void
    ) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let heading = NSTextField(labelWithString: L("Xem thêm"))
        heading.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        heading.textColor = Tokens.Color.secondaryInk
        stack.addArrangedSubview(heading)

        for id in ids {
            // Trang không có thì BỎ QUA chứ không dựng một nút bấm vào là không có gì xảy ra.
            // Bộ soát `HelpBook.problems()` đã bắt trường hợp này ở tầng bài kiểm; ở đây chỉ cần
            // không để nó thành một nút chết trên màn hình người dùng.
            guard let topic = book.topic(id: id) else { continue }
            let link = HelpLinkButton(topicID: id, title: topic.title, onNavigate: onNavigate)
            stack.addArrangedSubview(link)
        }
        return stack
    }
}

/// Nút chép nội dung khối mã.
///
/// Đổi nhãn thành "Đã chép" trong hai giây rồi trả lại. Không có phản hồi thì người dùng bấm
/// lại lần nữa, và một lần bấm không có gì xảy ra là cách nhanh nhất để họ nghĩ nút bị hỏng.
final class HelpCopyButton: NSButton {

    private let source: String

    init(source: String) {
        self.source = source
        super.init(frame: .zero)
        title = L("Chép")
        bezelStyle = .rounded
        controlSize = .small
        font = Tokens.Font.caption
        target = self
        action = #selector(copySource)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(L("Chép đoạn mã mẫu"))
    }

    required init?(coder: NSCoder) { nil }

    @objc private func copySource() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
        title = L("Đã chép")
        let restore = DispatchWorkItem { [weak self] in self?.title = L("Chép") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: restore)
    }
}

/// Liên kết sang trang khác.
final class HelpLinkButton: NSButton {

    private let topicID: String
    private let onNavigate: (String) -> Void

    init(topicID: String, title: String, onNavigate: @escaping (String) -> Void) {
        self.topicID = topicID
        self.onNavigate = onNavigate
        super.init(frame: .zero)
        isBordered = false
        attributedTitle = NSAttributedString(string: "→ " + title, attributes: [
            .font: Tokens.Font.ui,
            .foregroundColor: Tokens.Color.action,
        ])
        target = self
        action = #selector(go)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    @objc private func go() { onNavigate(topicID) }
}
