import AppKit
import GEditorCore

/// Thanh Tìm/Thay neo trong cửa sổ (FR-SRCH-101…104, UI/UX §3).
///
/// Neo trong cửa sổ chứ không phải hộp thoại nổi: hộp thoại nổi che mất chính đoạn văn bản
/// người dùng đang tìm, và trên macOS nó chặn luôn phím tắt của cửa sổ bên dưới.
///
/// View này KHÔNG biết gì về tìm kiếm — nó chỉ thu thập lựa chọn và báo lên. Mọi việc khớp
/// do `PCRE2SearchEngine` làm, để cùng một engine phục vụ Find, Replace, Find in Files và
/// Mark (FR-SRCH-101 đòi ba chế độ dùng thống nhất).
final class FindPanelView: NSView {

    // Chiều cao do NỘI DUNG quyết định: hàng điều khiển được ghim vào cả mép trên lẫn mép
    // dưới của panel, nên panel không bao giờ nhỏ hơn thứ nó chứa.
    //
    // Hai lần trước đều sai vì cố ĐOÁN chiều cao: đặt cứng 76pt, rồi tính bằng
    // `fittingSize` (trả về quá nhỏ khi view chưa được bố cục). Cả hai lần hàng thứ hai
    // tràn xuống CHỒNG LÊN status bar — che mất chính bảng mã người dùng cần đọc trước khi
    // lưu. Không thấy được khi đọc mã, chỉ thấy khi chạy app và nhìn.

    struct Query {
        var pattern = ""
        var replacement = ""
        var mode: SearchMode = .normal
        var matchCase = false
        var wholeWord = false

        var options: SearchOptions {
            SearchOptions(mode: mode, matchCase: matchCase, wholeWord: wholeWord)
        }
    }

    enum Action {
        case findNext, findPrevious, replaceCurrent, replaceAll, countAll, close
        /// Người dùng vừa gõ thêm một ký tự vào ô Tìm (FR-SRCH-108).
        case incremental
    }

    var onAction: ((Action, Query) -> Void)?

    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let modePopUp = NSPopUpButton()
    private let matchCaseBox = NSButton(checkboxWithTitle: "Phân biệt hoa thường", target: nil, action: nil)
    private let wholeWordBox = NSButton(checkboxWithTitle: "Cả từ", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let column = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(.windowBackgroundColor)
    }

    var query: Query {
        Query(
            pattern: findField.stringValue,
            replacement: replaceField.stringValue,
            mode: [SearchMode.normal, .extended, .regex][modePopUp.indexOfSelectedItem],
            matchCase: matchCaseBox.state == .on,
            wholeWord: wholeWordBox.state == .on
        )
    }

    func focusFindField() {
        window?.makeFirstResponder(findField)
    }

    /// Chữ đang nằm ở ô kết quả — bài kiểm canh để ô này không mang tin của tính năng khác.
    var statusForSelfTest: String { statusLabel.stringValue }

    /// Hiện kết quả hoặc lỗi. Lỗi tô màu EMBER để phân biệt với thông tin bình thường.
    func showStatus(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? Tokens.Color.ember : .secondaryLabelColor
    }

    private func setUp() {
        wantsLayer = true
        applyLayerBackground(.windowBackgroundColor)

        findField.placeholderString = "Tìm"
        replaceField.placeholderString = "Thay bằng"
        for field in [findField, replaceField] {
            field.controlSize = .small
            field.font = Tokens.Font.editor()
            field.target = self
            field.action = #selector(findFieldSubmitted)
        }
        // FR-SRCH-108: gõ tới đâu tìm tới đó. Chỉ ô TÌM, không phải ô thay — gõ vào ô thay
        // không đổi thứ đang tìm.
        findField.delegate = self

        // NFR-USE-03. `placeholderString` KHÔNG phải nhãn: VoiceOver đọc nó khi ô rỗng rồi im
        // bặt ngay khi có chữ, nên người dùng gõ nửa chừng quay lại sẽ không còn biết mình
        // đang đứng ở ô nào.
        findField.setAccessibilityLabel(L("Tìm"))
        replaceField.setAccessibilityLabel(L("Thay bằng"))
        modePopUp.setAccessibilityLabel(L("Chế độ tìm kiếm"))
        statusLabel.setAccessibilityLabel(L("Kết quả tìm kiếm"))

        modePopUp.addItems(withTitles: ["Chuỗi thuần", "Extended (\\n \\t \\xNN)", "Biểu thức chính quy"])
        modePopUp.controlSize = .small
        modePopUp.target = self
        modePopUp.action = #selector(optionsChanged)
        for box in [matchCaseBox, wholeWordBox] {
            box.target = self
            box.action = #selector(optionsChanged)
            box.controlSize = .small
            box.font = Tokens.Font.caption
        }
        statusLabel.font = Tokens.Font.caption
        statusLabel.textColor = .secondaryLabelColor

        let findRow = NSStackView(views: [
            findField,
            button("Kế", #selector(findNext)),
            button("Trước", #selector(findPrevious)),
            button("Đếm", #selector(countAll)),
            button("Đóng", #selector(closePanel)),
        ])
        let replaceRow = NSStackView(views: [
            replaceField,
            button("Thay", #selector(replaceCurrent)),
            button("Thay tất cả", #selector(replaceAll)),
            modePopUp,
            matchCaseBox,
            wholeWordBox,
            statusLabel,
        ])

        for row in [findRow, replaceRow] {
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = Tokens.Metrics.spacing(2)
            row.translatesAutoresizingMaskIntoConstraints = false
        }
        // Ô nhập giãn theo cửa sổ, nút giữ nguyên bề rộng của chúng.
        findField.setContentHuggingPriority(.init(1), for: .horizontal)
        replaceField.setContentHuggingPriority(.init(1), for: .horizontal)
        statusLabel.setContentHuggingPriority(.init(1), for: .horizontal)

        column.setViews([findRow, replaceRow], in: .top)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = Tokens.Metrics.spacing(1)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        let inset = Tokens.Metrics.spacing(3)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            column.topAnchor.constraint(equalTo: topAnchor, constant: Tokens.Metrics.spacing(2)),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Tokens.Metrics.spacing(2)),
            findRow.widthAnchor.constraint(equalTo: column.widthAnchor),
            replaceRow.widthAnchor.constraint(equalTo: column.widthAnchor),
        ])
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = Tokens.Font.caption
        return button
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    @objc private func findFieldSubmitted() { onAction?(.findNext, query) }
    @objc private func optionsChanged() { onAction?(.countAll, query) }
    @objc private func findNext() { onAction?(.findNext, query) }
    @objc private func findPrevious() { onAction?(.findPrevious, query) }
    @objc private func countAll() { onAction?(.countAll, query) }
    @objc private func replaceCurrent() { onAction?(.replaceCurrent, query) }
    @objc private func replaceAll() { onAction?(.replaceAll, query) }
    @objc private func closePanel() { onAction?(.close, query) }

    /// Nạp sẵn ô Tìm/Thay từ một chỗ khác trong app — FR-DQR-006 mở hộp thay thế cho một luật
    /// chất lượng đang trượt.
    ///
    /// KHÔNG tự chạy tìm: đặc tả đòi *"Replace có preview"*, và chạy ngay khi mở là bỏ mất cái
    /// preview ấy. Người dùng phải nhìn thấy mình sắp thay gì trước khi bấm.
    func prefill(pattern: String, replacement: String = "", mode: SearchMode = .normal) {
        findField.stringValue = pattern
        replaceField.stringValue = replacement
        let index = [SearchMode.normal, .extended, .regex].firstIndex(of: mode) ?? 0
        modePopUp.selectItem(at: index)
    }

    /// Đưa một chuỗi vào ô Tìm ĐÚNG như người dùng gõ, kể cả nhịp tìm tăng dần.
    func typeIntoFindFieldForSelfTest(_ text: String) {
        findField.stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: findField))
    }
}

extension FindPanelView: NSTextFieldDelegate {

    /// Gõ tới đâu tìm tới đó (FR-SRCH-108).
    ///
    /// KHÔNG hoãn lại vài chục mili giây như lối thường thấy. Chỗ nhận việc này —
    /// `MainWindowController` — đã có sẵn hai lớp phòng vệ: `DocumentSearch` chạy trên mmap
    /// chứ không dựng cả tài liệu, và mỗi lần tìm có hạn giờ 5 giây. Thêm một tầng hoãn nữa
    /// chỉ làm phản hồi trễ đi mà không gỡ được gì.
    ///
    /// Ô Tìm rỗng thì cũng phải báo, để chỗ gọi xoá phần tô của lần tìm trước.
    func controlTextDidChange(_ notification: Notification) {
        guard (notification.object as? NSTextField) === findField else { return }
        onAction?(.incremental, query)
    }
}
