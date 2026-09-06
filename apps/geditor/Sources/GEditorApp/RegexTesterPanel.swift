import AppKit
import GEditorCore

/// Panel thử và giải thích biểu thức chính quy (FR-SRCH-110).
///
/// **Chạy trên một MẨU văn bản người dùng dán vào, không phải trên tài liệu.** Đó là cả điểm
/// của công cụ: người ta viết regex sai vài lần trước khi viết đúng, và mỗi lần thử trên tài
/// liệu 200 MB là một lần chờ. Ô mẫu được điền sẵn bằng vùng chọn hiện tại — đúng thứ họ vừa
/// nhìn thấy và muốn khớp.
///
/// **Cột "giải thích" là nửa còn lại của công cụ.** Chạy được mà không hiểu vì sao chạy được
/// thì lần sau vẫn phải mò lại từ đầu.
final class RegexTesterPanel: NSWindowController {

    private let patternField = NSTextField()
    private let sampleView = NSTextView()
    private let resultView = NSTextView()
    private let explainView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = L("Thử biểu thức chính quy")
        super.init(window: window)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        patternField.placeholderString = #"(\w+)@(\w+)\.com"#
        patternField.font = Tokens.Font.monoInline()
        patternField.target = self
        patternField.action = #selector(rerun)
        patternField.delegate = self
        patternField.setAccessibilityLabel(L("Biểu thức chính quy"))

        for view in [sampleView, resultView, explainView] {
            view.font = Tokens.Font.monoInline()
            view.backgroundColor = Tokens.Color.editorBackground
            view.textColor = Tokens.Color.editorInk
            view.isRichText = false
            view.textContainerInset = NSSize(width: 6, height: 6)
        }
        sampleView.delegate = self
        resultView.isEditable = false
        explainView.isEditable = false
        sampleView.setAccessibilityLabel(L("Văn bản thử"))
        resultView.setAccessibilityLabel(L("Kết quả khớp"))
        explainView.setAccessibilityLabel(L("Giải thích biểu thức"))

        statusLabel.font = Tokens.Font.caption
        statusLabel.textColor = .secondaryLabelColor

        let column = NSStackView(views: [
            labelled(L("Biểu thức"), patternField),
            labelled(L("Văn bản thử"), scrolled(sampleView, height: 140)),
            labelled(L("Kết quả"), scrolled(resultView, height: 140)),
            labelled(L("Biểu thức này làm gì"), scrolled(explainView, height: 120)),
            statusLabel,
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        window?.contentView = column
    }

    private func labelled(_ title: String, _ view: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = Tokens.Font.caption
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [label, view])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 660).isActive = true
        return stack
    }

    private func scrolled(_ view: NSTextView, height: CGFloat) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = view
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        view.autoresizingMask = [.width]
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        return scroll
    }

    /// Điền sẵn ô mẫu bằng vùng chọn hiện tại.
    func present(sample: String) {
        if !sample.isEmpty { sampleView.string = sample }
        rerun()
        window?.makeFirstResponder(patternField)
    }

    @objc private func rerun() {
        let pattern = patternField.stringValue
        explainView.string = RegexTester.explain(pattern)
            .map { "\($0.text)\t— \($0.meaning ?? "không nhận ra")" }
            .joined(separator: "\n")

        guard !pattern.isEmpty else {
            resultView.string = ""
            statusLabel.stringValue = ""
            return
        }
        do {
            let result = try RegexTester.run(
                pattern: pattern,
                options: SearchOptions(mode: .regex, matchCase: true, wholeWord: false),
                on: sampleView.string
            )
            resultView.string = result.previews.enumerated().map { index, preview in
                var line = "\(index + 1). \(preview.whole)"
                for (number, group) in preview.groups.enumerated() {
                    // Nhóm KHÔNG tham gia khớp hiện là «không khớp», không phải chuỗi rỗng —
                    // hai thứ ấy khác nhau và đó là chỗ người ta hay hiểu sai khi viết $1.
                    line += "\n     $\(number + 1) = \(group.map { "«\($0)»" } ?? "không khớp")"
                }
                return line
            }.joined(separator: "\n")

            statusLabel.stringValue = result.matches.isEmpty
                ? L("Không khớp chỗ nào")
                : "\(result.matches.count) lần khớp"
                    + (result.truncated ? L(" (đã cắt bớt)") : "")
            statusLabel.textColor = .secondaryLabelColor
        } catch {
            resultView.string = ""
            statusLabel.stringValue = String(describing: error)
            statusLabel.textColor = Tokens.Color.ember
        }
    }

    // MARK: - Móc tự kiểm

    func setPatternForSelfTest(_ pattern: String) {
        patternField.stringValue = pattern
        rerun()
    }

    func setSampleForSelfTest(_ sample: String) {
        sampleView.string = sample
        rerun()
    }

    var resultTextForSelfTest: String { resultView.string }
    var explanationForSelfTest: String { explainView.string }
    var statusForSelfTest: String { statusLabel.stringValue }
}

extension RegexTesterPanel: NSTextFieldDelegate, NSTextViewDelegate {
    /// Gõ tới đâu chạy tới đó, ở cả hai ô: thử regex là việc lặp đi lặp lại, và bắt bấm Enter
    /// sau mỗi ký tự sẽ làm nó chậm hơn chính việc mò trong đầu.
    func controlTextDidChange(_ notification: Notification) { rerun() }
    func textDidChange(_ notification: Notification) { rerun() }
}
