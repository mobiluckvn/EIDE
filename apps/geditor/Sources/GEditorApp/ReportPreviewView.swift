import AppKit
import WebKit
import GEditorCore

/// Khung xem trước báo cáo — FR-RPT-001 (*"soạn bên trái, preview bên phải"*).
///
/// ## WebKit liên kết lúc nạp, và đó là quyết định ĐÃ ĐO
///
/// ADR-14 cấm nạp framework nặng lúc khởi động mà không khai. WebKit ở đây được `import` thẳng,
/// nên nó liên kết lúc nạp — và điều đó chỉ chấp nhận được vì **PoC-L đã đo**: +1,4 ms trên sàn
/// nhiễu 0,9 ms, vì WebKit nằm sẵn trong dyld shared cache. Con số ấy được khai vào
/// `LINKED_FRAMEWORKS_ALLOWED` của `check-core-no-ui.sh`; bỏ khai thì cổng đỏ.
///
/// Cái đắt là **dựng `WKWebView`**, không phải liên kết framework — đó là lý do view này
/// `lazy`: một người không bao giờ mở báo cáo thì không bao giờ trả giá ấy.
///
/// ## Nạp bằng `loadHTMLString`, KHÔNG qua tệp tạm
///
/// Hai lý do. Tệp tạm để lại rác trên đĩa khi ứng dụng bị tắt giữa chừng, và quan trọng hơn:
/// nạp từ `file://` cho trang quyền đọc thư mục — một báo cáo là văn bản của người khác gửi
/// tới, và HTML sinh ra từ nó không cần quyền nào cả. `baseURL: nil` nghĩa là trang không có
/// gốc để giải đường dẫn tương đối, tức không đọc được tệp nào.
///
/// ## Không có JavaScript
///
/// Trình kết xuất không sinh script nào, và ở đây tắt hẳn để chắc: `.greport.md` có thể đến từ
/// một kho mã người khác gửi, và một trang có script chạy trong ứng dụng soạn thảo là một bề mặt
/// tấn công không có lý do tồn tại.
final class ReportPreviewView: NSView {

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Xem trước báo cáo") }

    private let header = NSTextField(labelWithString: "")
    private let paramButton = NSButton()
    private let exportButton = NSButton()
    private let printButton = NSButton()
    private let closeButton = NSButton()

    private lazy var web: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setValue(false, forKey: "drawsBackground")
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        return view
    }()

    private(set) var rendered: ReportRenderer.Rendered?

    var onExport: (() -> Void)?
    var onPrint: (() -> Void)?
    var onEditParameters: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.chrome)
    }

    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.chrome)

        header.font = NSFont.systemFont(ofSize: 11)
        header.lineBreakMode = .byTruncatingTail
        header.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, action) in [
            (paramButton, L("Tham số…"), #selector(editParameters)),
            (exportButton, L("Xuất HTML…"), #selector(exportTapped)),
            (printButton, L("In / PDF…"), #selector(printTapped)),
            (closeButton, L("Đóng"), #selector(closeTapped)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
            button.action = action
        }

        let controls = NSStackView(views: [
            paramButton, exportButton, printButton, NSView(), closeButton,
        ])
        controls.orientation = .horizontal
        controls.spacing = 4
        controls.translatesAutoresizingMaskIntoConstraints = false

        addSubview(controls)
        addSubview(header)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            header.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    // MARK: - Hiện

    func show(_ rendered: ReportRenderer.Rendered, stale: Bool) {
        self.rendered = rendered
        var text: String
        if rendered.hasFailures {
            text = String(
                format: L("%d khối chạy được · %d khối HỎNG"),
                rendered.succeeded, rendered.failures.count)
        } else {
            text = LF("%d khối chạy được", rendered.succeeded)
        }
        if stale {
            // FR-RPT-003. Dữ liệu cũ mà không báo thì người dùng đọc một bảng đã lỗi thời và
            // không có cách nào biết.
            text += L(" · DỮ LIỆU CŨ — file nguồn đã đổi, bấm dựng lại")
        }
        header.stringValue = text
        header.textColor = (rendered.hasFailures || stale)
            ? Tokens.Color.ember
            : Tokens.Color.editorInk.withAlphaComponent(0.7)
        web.loadHTMLString(rendered.html, baseURL: nil)
    }

    func showParseFailure(_ message: String) {
        rendered = nil
        header.stringValue = message
        header.textColor = Tokens.Color.ember
        // Trang trắng chứ không giữ nội dung cũ: giữ lại thì người dùng tưởng bản đang xem là
        // bản mới, và họ xuất ra một tệp không khớp với thứ họ vừa gõ.
        web.loadHTMLString(
            "<body style=\"font:14px -apple-system;padding:24px;color:#7d2f16\">"
                + MarkdownHTML.escape(message) + "</body>", baseURL: nil)
    }

    @objc private func exportTapped() { onExport?() }
    @objc private func printTapped() { onPrint?() }
    @objc private func editParameters() { onEditParameters?() }
    @objc private func closeTapped() { onClose?() }

    /// Khung in cho FR-RPT-005 vế (b) — PDF qua đường in của hệ thống.
    ///
    /// Trả về chính `WKWebView`: từ macOS 11 nó tự dựng `NSPrintOperation` biết ngắt trang theo
    /// luật `@media print` trong CSS. Tự vẽ lại nội dung để in là dựng một trình kết xuất thứ
    /// hai, và nó sẽ lệch khỏi cái đầu tiên.
    func printOperation(with info: NSPrintInfo) -> NSPrintOperation {
        web.printOperation(with: info)
    }

    // MARK: - Móc tự kiểm

    var headerTextForSelfTest: String { header.stringValue }
    var htmlForSelfTest: String { rendered?.html ?? "" }
    var failureCountForSelfTest: Int { rendered?.failures.count ?? 0 }
}
