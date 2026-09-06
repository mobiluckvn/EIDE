import AppKit
import GEditorCore

/// Hộp thoại Column Editor (FR-CORE-003).
///
/// Dựng bằng tay chứ không bằng `NSAlert` với một ô nhập: ở đây có ba chế độ và bốn tham số,
/// mà nhồi ngần ấy vào accessory view của alert thì vừa chật vừa không đặt được thứ tự tab.
final class ColumnEditorPanel: NSWindowController {

    /// Kết quả người dùng chọn; `nil` = huỷ.
    private(set) var content: ColumnEditor.Content?

    private let modePicker = NSSegmentedControl(
        labels: [L("Văn bản"), L("Dãy số"), L("Dãy ngày")], trackingMode: .selectOne, target: nil, action: nil
    )
    private let textField = NSTextField(string: "")
    private let startField = NSTextField(string: "1")
    private let stepField = NSTextField(string: "1")
    private let paddingField = NSTextField(string: "0")
    private let radixPicker = NSPopUpButton()
    private let uppercaseBox = NSButton(checkboxWithTitle: L("Chữ HOA (hex)"), target: nil, action: nil)
    private let dateField = NSTextField(string: "")
    private let dateFormatField = NSTextField(string: "dd/MM/yyyy")
    private let previewLabel = NSTextField(labelWithString: "")

    private let lineCount: Int
    private var completion: ((ColumnEditor.Content?) -> Void)?

    init(lineCount: Int) {
        self.lineCount = lineCount
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 250),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = LF("Column Editor — %d dòng", lineCount)
        super.init(window: window)
        build()
        refreshPreview()
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(over parent: NSWindow, completion: @escaping (ColumnEditor.Content?) -> Void) {
        self.completion = completion
        guard let window else { return completion(nil) }
        parent.beginSheet(window) { _ in }
    }

    private func build() {
        guard let content = window?.contentView else { return }

        modePicker.selectedSegment = 0
        modePicker.target = self
        modePicker.action = #selector(modeChanged)

        for radix in ColumnEditor.Radix.allCases {
            radixPicker.addItem(withTitle: radix.displayName)
            radixPicker.lastItem?.tag = radix.rawValue
        }
        radixPicker.selectItem(withTag: ColumnEditor.Radix.decimal.rawValue)
        radixPicker.target = self
        radixPicker.action = #selector(anythingChanged)

        // Ngày mặc định là HÔM NAY, định dạng theo kiểu Việt Nam.
        let today = DateFormatter()
        today.dateFormat = "dd/MM/yyyy"
        dateField.stringValue = today.string(from: Date())

        for field in [textField, startField, stepField, paddingField, dateField, dateFormatField] {
            field.target = self
            field.action = #selector(anythingChanged)
            field.delegate = self
        }
        uppercaseBox.target = self
        uppercaseBox.action = #selector(anythingChanged)

        previewLabel.font = Tokens.Font.editor()
        previewLabel.textColor = Tokens.Color.secondaryInk
        previewLabel.lineBreakMode = .byTruncatingTail

        let rows = NSStackView(views: [
            modePicker,
            labelled(L("Văn bản"), textField),
            labelled(L("Bắt đầu"), startField),
            labelled(L("Bước"), stepField),
            labelled(L("Đệm 0 tới"), paddingField),
            labelled(L("Hệ"), radixPicker),
            uppercaseBox,
            labelled(L("Ngày đầu"), dateField),
            labelled(L("Định dạng"), dateFormatField),
            previewLabel,
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 8
        rows.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        rows.translatesAutoresizingMaskIntoConstraints = false

        let ok = NSButton(title: L("Chèn"), target: self, action: #selector(confirm))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Huỷ"), target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, ok])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(rows)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: content.topAnchor),
            rows.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: rows.bottomAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])
        modeChanged()
    }

    private func labelled(_ title: String, _ field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .trailingEdge
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        field.widthAnchor.constraint(equalToConstant: 190).isActive = true
        return row
    }

    // MARK: - Trạng thái

    private var mode: Int { modePicker.selectedSegment }

    @objc private func modeChanged() {
        // Ẩn hẳn phần không dùng, không chỉ làm mờ: hộp thoại ngắn thì đọc nhanh hơn.
        for (index, view) in (window?.contentView?.subviews.first as? NSStackView)?
            .arrangedSubviews.enumerated() ?? [NSView]().enumerated() {
            switch index {
            case 1: view.isHidden = mode != 0                 // văn bản
            case 2, 3, 4, 5, 6: view.isHidden = mode != 1     // dãy số
            case 7, 8: view.isHidden = mode != 2              // dãy ngày
            default: break
            }
        }
        refreshPreview()
    }

    @objc private func anythingChanged() { refreshPreview() }

    /// Xem trước ba dòng đầu và dòng cuối — người dùng thấy ngay mình sắp chèn cái gì.
    private func refreshPreview() {
        guard let content = currentContent() else {
            previewLabel.stringValue = "—"
            return
        }
        let values = ColumnEditor.values(content, count: lineCount)
        guard !values.isEmpty else { return previewLabel.stringValue = "—" }
        let head = values.prefix(3).joined(separator: " · ")
        previewLabel.stringValue = values.count > 3 ? "\(head) … \(values[values.count - 1])" : head
    }

    private func currentContent() -> ColumnEditor.Content? {
        switch mode {
        case 0:
            return .text(textField.stringValue)
        case 1:
            let radix = ColumnEditor.Radix(rawValue: radixPicker.selectedTag()) ?? .decimal
            return .number(
                start: Int(startField.stringValue) ?? 0,
                step: Int(stepField.stringValue) ?? 1,
                radix: radix,
                padding: max(0, Int(paddingField.stringValue) ?? 0),
                uppercase: uppercaseBox.state == .on
            )
        default:
            let parser = DateFormatter()
            parser.dateFormat = dateFormatField.stringValue
            guard let start = parser.date(from: dateField.stringValue) else { return nil }
            return .date(start: start, stepDays: Int(stepField.stringValue) ?? 1,
                         format: dateFormatField.stringValue)
        }
    }

    @objc private func confirm() {
        content = currentContent()
        finish()
    }

    @objc private func cancel() {
        content = nil
        finish()
    }

    private func finish() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
        completion?(content)
        completion = nil
    }
}

extension ColumnEditorPanel: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) { refreshPreview() }
}

// MARK: - Đường vào cho bài tự kiểm
//
// Panel này từng có **0% độ phủ** dù `FR-CORE-003` đã đánh ✅ — tính năng chạy được, mà không
// một dòng nào của lớp này từng được thực thi trong bất kỳ bài kiểm nào (`trang-thai.md`
// MNT-02bis). Các đường vào dưới đây đi qua ĐÚNG những điều khiển thật mà người dùng chạm tới,
// chứ không gọi tắt vào `ColumnEditor` ở lõi — lõi đã có 14 bài kiểm riêng, và chép lại chúng ở
// đây thì vẫn để nguyên khoảng trống: phần NỐI giữa ô nhập và lõi.
extension ColumnEditorPanel {

    /// 0 = Văn bản · 1 = Dãy số · 2 = Dãy ngày. Đi qua `modeChanged` như một cú bấm thật.
    func setModeForSelfTest(_ index: Int) {
        modePicker.selectedSegment = index
        modePicker.performClick(nil)
    }

    func setFieldsForSelfTest(
        text: String? = nil, start: String? = nil, step: String? = nil,
        padding: String? = nil, date: String? = nil, dateFormat: String? = nil,
        radix: ColumnEditor.Radix? = nil, uppercase: Bool? = nil
    ) {
        if let text { textField.stringValue = text }
        if let start { startField.stringValue = start }
        if let step { stepField.stringValue = step }
        if let padding { paddingField.stringValue = padding }
        if let date { dateField.stringValue = date }
        if let dateFormat { dateFormatField.stringValue = dateFormat }
        if let radix { radixPicker.selectItem(withTag: radix.rawValue) }
        if let uppercase { uppercaseBox.state = uppercase ? .on : .off }
        refreshPreview()
    }

    /// Chuỗi xem trước ĐANG HIỆN trên panel — thứ người dùng thật sự đọc trước khi bấm OK.
    var previewForSelfTest: String { previewLabel.stringValue }

    /// Bấm OK / Huỷ. Đi qua `confirm()`/`cancel()` rồi `finish()`, tức đóng cả sheet.
    func confirmForSelfTest() { confirm() }
    func cancelForSelfTest() { cancel() }
}
