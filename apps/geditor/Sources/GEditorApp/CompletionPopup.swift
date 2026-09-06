import AppKit
import GEditorCore

/// Danh sách gợi ý tự hoàn thành nổi lên dưới con nháy (FR-CORE-013).
///
/// Cửa sổ nổi chứ không phải một view con của vùng soạn thảo: nó phải vẽ ĐÈ lên chữ, kể cả khi
/// con nháy ở sát mép dưới, và một view con thì bị cắt theo khung cha.
///
/// **Không cướp bàn phím.** Cửa sổ này không bao giờ thành key window; người dùng vẫn đang gõ
/// vào tài liệu, còn mũi tên và Enter thì vùng soạn thảo chuyển tiếp sang đây. Cách khác —
/// cho popup nhận phím — sẽ làm bộ gõ tiếng Việt mất ngữ cảnh giữa chừng một từ đang soạn.
final class CompletionPopup: NSObject {

    /// Số dòng hiện cùng lúc.
    private static let visibleRows = 8
    private static let rowHeight: CGFloat = 20
    private static let width: CGFloat = 280

    private var window: NSWindow?
    private let list = NSTableView()
    private let scrollView = NSScrollView()

    private(set) var candidates: [CompletionCandidate] = []
    private(set) var selectedIndex = 0

    /// Người dùng chốt một gợi ý.
    var onCommit: ((CompletionCandidate) -> Void)?

    var isVisible: Bool { window?.isVisible ?? false }

    override init() {
        super.init()
        build()
    }

    private func build() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("word"))
        column.width = Self.width - 8
        list.addTableColumn(column)
        list.headerView = nil
        list.rowHeight = Self.rowHeight
        list.dataSource = self
        list.delegate = self
        list.style = .plain
        list.backgroundColor = Tokens.Color.chrome
        list.usesAlternatingRowBackgroundColors = false
        list.target = self
        list.action = #selector(rowClicked)

        scrollView.documentView = list
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .lineBorder
    }

    // MARK: - Hiện / ẩn

    /// Hiện danh sách, đặt góc trên-trái tại `origin` (tọa độ màn hình).
    func show(_ candidates: [CompletionCandidate], at origin: NSPoint, parent: NSWindow?) {
        guard !candidates.isEmpty, let parent else { return hide() }
        self.candidates = candidates
        selectedIndex = 0

        let rows = min(candidates.count, Self.visibleRows)
        let size = NSSize(width: Self.width, height: CGFloat(rows) * Self.rowHeight + 2)

        let window = self.window ?? makeWindow()
        self.window = window
        window.setContentSize(size)
        // Đặt góc TRÊN của danh sách tại điểm đưa vào: `origin` là chân dòng đang gõ, nên
        // danh sách xổ xuống dưới nó, không che chính dòng ấy.
        window.setFrameTopLeftPoint(origin)
        if window.parent == nil { parent.addChildWindow(window, ordered: .above) }
        window.orderFront(nil)

        list.reloadData()
        select(0)
    }

    func hide() {
        guard let window else { return }
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
        candidates = []
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = scrollView
        window.backgroundColor = Tokens.Color.chrome
        window.hasShadow = true
        window.level = .floating
        // Không bao giờ thành key window: người dùng vẫn đang gõ vào tài liệu.
        window.ignoresMouseEvents = false
        return window
    }

    // MARK: - Bàn phím (vùng soạn thảo chuyển tiếp sang đây)

    /// Xử lý một phím; trả `true` nếu đã nuốt nó.
    func handleKey(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        switch event.keyCode {
        case 125: select(selectedIndex + 1); return true          // ↓
        case 126: select(selectedIndex - 1); return true          // ↑
        case 36, 76, 48:                                          // Return, Enter, Tab
            commit()
            return true
        case 53:                                                  // Esc
            hide()
            return true
        default:
            return false
        }
    }

    private func select(_ index: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = min(max(0, index), candidates.count - 1)
        list.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        list.scrollRowToVisible(selectedIndex)
    }

    private func commit() {
        guard selectedIndex < candidates.count else { return hide() }
        let chosen = candidates[selectedIndex]
        hide()
        onCommit?(chosen)
    }

    @objc private func rowClicked() {
        guard list.clickedRow >= 0 else { return }
        select(list.clickedRow)
        commit()
    }

    // MARK: - Móc tự kiểm

    var wordsForSelfTest: [String] { candidates.map(\.word) }
    var selectedWordForSelfTest: String? {
        selectedIndex < candidates.count ? candidates[selectedIndex].word : nil
    }
    func moveForSelfTest(_ delta: Int) { select(selectedIndex + delta) }
    func commitForSelfTest() { commit() }
}

extension CompletionPopup: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { candidates.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard row < candidates.count else { return nil }
        let candidate = candidates[row]

        let identifier = NSUserInterfaceItemIdentifier("completionCell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.monoInline()
            field.lineBreakMode = .byTruncatingTail
        }
        // Ký hiệu (hàm, lớp) có dấu riêng: chúng đến từ cây cú pháp chứ không phải từ một chữ
        // nào đó nằm trong chú thích, và người dùng nên biết khác biệt ấy.
        field.stringValue = candidate.source == .symbol
            ? "ƒ \(candidate.word)"
            : "  \(candidate.word)"
        field.textColor = Tokens.Color.editorInk
        return field
    }
}
