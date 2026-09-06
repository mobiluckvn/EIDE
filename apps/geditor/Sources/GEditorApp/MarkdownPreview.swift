import AppKit
import GEditorCore

/// Xem trước Markdown (FR-FMT-506).
///
/// **Không dùng WebView.** Nạp WebKit kéo theo cả một engine trình duyệt vào tiến trình — đúng
/// thứ ADR-08 đang cố gỡ ra khỏi đường khởi động, và cho một tính năng phần lớn phiên làm việc
/// không ai mở. `NSAttributedString(markdown:)` có sẵn từ macOS 12 (đúng trần NFR-PORT-02) và
/// đủ cho những gì một trình soạn thảo cần hiện.
///
/// **Giới hạn phải nói ra, vì nó sẽ làm người dùng ngạc nhiên:** bộ dựng của hệ thống hiểu
/// Markdown mức *inline* — đậm, nghiêng, mã, liên kết, danh sách — nhưng KHÔNG dựng bảng và
/// KHÔNG tô màu khối mã. Panel nói thẳng điều đó ở chân cửa sổ thay vì để người dùng tưởng
/// file của họ viết sai.
///
/// **Có trần cỡ.** Dựng Markdown đòi cả tài liệu thành `String` — đúng thứ kiến trúc này tránh.
/// Trên `sizeLimit` thì từ chối và nói rõ.
final class MarkdownPreview: NSWindowController {

    static let sizeLimit = 4 << 20

    private let textView = NSTextView()
    private let noteLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = L("Xem trước Markdown")
        super.init(window: window)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        textView.isEditable = false
        textView.isRichText = true
        textView.backgroundColor = Tokens.Color.editorBackground
        textView.textContainerInset = NSSize(width: 16, height: 16)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        textView.autoresizingMask = [.width]

        noteLabel.font = Tokens.Font.caption
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.stringValue = L("Xem trước dựng bằng bộ Markdown của hệ thống: chưa dựng bảng và chưa tô màu khối mã.")

        let column = NSStackView(views: [scroll, noteLabel])
        column.orientation = .vertical
        column.spacing = 6
        column.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 8, right: 8)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 400).isActive = true
        window?.contentView = column
    }

    /// Chèn sơ đồ đã vẽ vào chỗ khối ` ```mermaid ` — FR-MMD-003.
    ///
    /// ## SVG thành ẢNH ĐÍNH KÈM, không thành trang web
    ///
    /// Cửa sổ này cố ý KHÔNG dùng WebView (xem ghi chú đầu lớp), và quyết định ấy vẫn đúng: đổi
    /// nó thành một trang web chỉ để hiện sơ đồ là kéo cả một engine trình duyệt vào một tính
    /// năng vốn không cần. `NSTextAttachment` với `NSImage` dựng từ SVG giữ được cả hai vế —
    /// sơ đồ hiện ra, mà phần còn lại vẫn là văn bản thuần.
    ///
    /// **Máy không đọc được SVG thì giữ nguyên khối mã.** `NSImage(data:)` đọc SVG từ macOS 13;
    /// NFR-PORT-02 đòi chạy từ macOS 12. Trên máy cũ, `NSImage` trả `nil` và người dùng thấy mã
    /// sơ đồ như trước — mất một tính năng, không mất nội dung.
    func insert(diagrams: [Int: NSImage]) {
        guard !diagrams.isEmpty, let storage = textView.textStorage else { return }
        // Đi từ CUỐI lên: mỗi lần thay làm mọi phạm vi phía sau dịch đi.
        for (index, marker) in markers.enumerated().reversed() {
            guard let image = diagrams[index] else { continue }
            guard marker.location != NSNotFound,
                  NSMaxRange(marker) <= storage.length else { continue }
            let attachment = NSTextAttachment()
            attachment.image = image
            // Kẹp bề rộng theo khung chữ: một sơ đồ 2.000 px sẽ tràn ra ngoài và người đọc chỉ
            // thấy góc trên bên trái của nó.
            let maximum = max(200, textView.bounds.width - 48)
            if image.size.width > maximum {
                let scale = maximum / image.size.width
                attachment.bounds = NSRect(
                    x: 0, y: 0, width: maximum, height: image.size.height * scale)
            }
            storage.replaceCharacters(
                in: marker, with: NSAttributedString(attachment: attachment))
        }
        markers = []
    }

    /// Phạm vi của từng khối mermaid trong văn bản đã dựng, theo thứ tự khối.
    private var markers: [NSRange] = []

    /// Dựng lại nội dung. Trả về `nil` khi xong, hoặc lý do từ chối.
    @discardableResult
    func present(markdown: String) -> String? {
        guard markdown.utf8.count <= Self.sizeLimit else {
            let megabytes = Double(markdown.utf8.count) / 1_048_576
            return String(format: "Tài liệu %.1f MB quá lớn để xem trước", megabytes)
        }
        // Khối mermaid được thay bằng một DẤU MỐC trước khi dựng, rồi tìm lại dấu ấy để biết
        // chỗ chèn ảnh. Cách khác — dò lại khối mã trong chuỗi đã dựng — không làm được: bộ
        // dựng Markdown của hệ thống bỏ hàng rào ``` đi, nên trong kết quả không còn gì phân
        // biệt khối mermaid với một khối mã bất kỳ.
        let (text, count) = Self.replacingMermaid(in: markdown)
        // `.full` để dòng trống tách đoạn đúng như Markdown quy định; mặc định của hệ thống coi
        // cả tài liệu là MỘT đoạn và mọi tiêu đề dính vào nhau thành một khối chữ.
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            return "Không dựng được xem trước"
        }
        let string = NSMutableAttributedString(parsed)
        string.addAttributes(
            [.foregroundColor: Tokens.Color.editorInk, .font: Tokens.Font.ui],
            range: NSRange(location: 0, length: string.length)
        )
        markers = (0..<count).map { index in
            string.mutableString.range(of: Self.marker(index))
        }
        textView.textStorage?.setAttributedString(string)
        return nil
    }

    /// Dấu mốc cho khối thứ `index`.
    ///
    /// Dùng ký tự đóng khung hiếm gặp thay vì một chuỗi chữ thường: người dùng hoàn toàn có thể
    /// viết chữ "MERMAID-0" trong tài liệu của họ, và khi ấy ảnh sẽ chèn vào đúng chỗ ấy.
    static func marker(_ index: Int) -> String { "⟦mermaid-\(index)⟧" }

    /// Thay mọi khối ` ```mermaid ` bằng dấu mốc; trả về số khối đã thay.
    static func replacingMermaid(in markdown: String) -> (text: String, count: Int) {
        let blocks = MermaidDocument.blocks(in: markdown)
        guard !blocks.isEmpty else { return (markdown, 0) }
        var lines = markdown.components(separatedBy: "\n")
        // Đi từ CUỐI lên để chỉ số dòng của khối phía trước không bị dịch.
        for block in blocks.reversed() {
            let bodyLines = block.source.isEmpty
                ? 0 : block.source.components(separatedBy: "\n").count
            var end = block.fenceLine + 1 + bodyLines   // dòng hàng rào đóng
            if end >= lines.count { end = lines.count - 1 }
            guard block.fenceLine <= end, end < lines.count else { continue }
            lines.replaceSubrange(block.fenceLine...end, with: [marker(block.index)])
        }
        return (lines.joined(separator: "\n"), blocks.count)
    }

    // MARK: - Móc tự kiểm

    var renderedTextForSelfTest: String { textView.string }
}
