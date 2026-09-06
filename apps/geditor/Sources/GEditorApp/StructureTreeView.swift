import AppKit
import GEditorCore

/// Chế độ **View** của tài liệu có cấu trúc — cây khoá–giá trị gấp mở được.
///
/// ## Bấm một nút là nhảy về NGUỒN
///
/// Đây là thứ phân biệt một cây dùng được với một bản in đẹp. View và Code phải là hai cách nhìn
/// CÙNG MỘT tài liệu, nên mọi nút đều dẫn được về đúng khoảng byte của nó trong văn bản. Nút nào
/// không biết chỗ của mình thì **không cho bấm** — thà không có đường nhảy còn hơn có một đường
/// nhảy tới chỗ sai.
///
/// ## Mở sẵn hai tầng đầu, không mở hết
///
/// Mở hết cây của một tệp JSON mười nghìn nút cho ra một danh sách dài hơn chính văn bản gốc —
/// tức là làm mất đúng thứ người ta sang chế độ View để tìm. Đóng hết thì màn hình chỉ có một
/// dòng và người dùng phải bấm mới biết bên trong có gì. Hai tầng là chỗ đứng giữa: thấy được
/// khung của tài liệu, chưa thấy chi tiết.
final class StructureTreeView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {

    /// Người dùng chọn một nút — tham số là khoảng byte trong nguồn.
    var onSelectRange: ((Range<Int>) -> Void)?
    var onStatus: ((String) -> Void)?
    /// Người dùng bỏ cây đi mà KHÔNG chọn nút nào — Esc. Con nháy phải nằm nguyên chỗ cũ.
    var onDismiss: (() -> Void)?

    private let outline = StructureOutlineView()
    private let scroll = NSScrollView()
    private let header = NSTextField(labelWithString: "")
    private let filterField = NSSearchField()
    private var tree = StructureTree(nodes: [], roots: [])
    /// Bọc chỉ số nút thành `AnyObject` — `NSOutlineView` so item bằng DANH TÍNH, nên phải giữ
    /// lại đúng các thể hiện đã đưa ra, không dựng mới ở mỗi lần hỏi.
    private var boxes: [TreeBox] = []

    /// Gốc và con ĐANG HIỆN. Khi không lọc, chúng đúng bằng `tree.roots` và `children` của từng
    /// nút; khi có lọc, chúng là phần còn lại sau phép lọc.
    ///
    /// Lọc bằng cách dựng lại DANH SÁCH CON chứ không bằng cách dựng một cây mới: chỉ số nút giữ
    /// nguyên, nên mọi thứ neo theo chỉ số — hộp `TreeBox`, đường nhảy về nguồn, phép mở đường
    /// theo con nháy — vẫn đúng mà không phải quy đổi lần nữa. Một bảng quy đổi chỉ số là đúng
    /// chỗ để một cú bấm rơi vào nút khác.
    private var shownRoots: [Int] = []
    private var shownChildren: [[Int]] = []
    /// Số nút KHỚP phép lọc, không tính tổ tiên kéo theo. `nil` = không lọc.
    private var matchCount: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        applyLayerBackground(Tokens.Color.editorBackground)

        header.font = Tokens.Font.caption
        header.textColor = Tokens.Color.secondaryInk
        header.translatesAutoresizingMaskIntoConstraints = false

        outline.headerView = nil
        outline.dataSource = self
        outline.delegate = self
        outline.rowSizeStyle = .default
        outline.indentationPerLevel = 14
        outline.backgroundColor = Tokens.Color.editorBackground
        outline.gridStyleMask = []
        outline.style = .plain
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("node"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.target = self
        outline.action = #selector(rowClicked)
        // Bàn phím phải làm được đúng những gì chuột làm được. Mũi tên và phím gấp/mở thì
        // `NSOutlineView` lo sẵn; hai phím còn thiếu là hai phím KẾT THÚC một lượt xem: Enter
        // đi tới chỗ vừa tìm ra, Esc bỏ đi tay không.
        outline.onReturn = { [weak self] in self?.activateSelectedRow() }
        outline.onEscape = { [weak self] in self?.onDismiss?() }

        // Ô lọc: cùng chữ và cùng phép so với ô lọc của mục lục hàm và của bảng CSV. Người dùng
        // không phải học luật tìm kiếm thứ ba trong cùng một ứng dụng.
        filterField.placeholderString = L("Lọc theo tên")
        filterField.controlSize = .small
        filterField.font = Tokens.Font.caption
        filterField.target = self
        filterField.action = #selector(filterChanged)
        filterField.delegate = self
        filterField.translatesAutoresizingMaskIntoConstraints = false

        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Tokens.Color.editorBackground
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        // Tab đi vòng giữa hai thứ dùng được của khung này. Không nối thì bàn phím vào được cây
        // nhưng không bao giờ ra được ô lọc — ô lọc thành thứ chỉ chuột chạm tới.
        outline.nextKeyView = filterField
        filterField.nextKeyView = outline

        addSubview(header)
        addSubview(filterField)
        addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            header.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            filterField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            filterField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            filterField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: filterField.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Nạp

    func show(_ tree: StructureTree) {
        self.tree = tree
        boxes = tree.nodes.indices.map(TreeBox.init)
        // Mỗi lần nạp tài liệu là bỏ phép lọc cũ. Giữ lại chữ trong ô lọc thì cây của tệp mới mở
        // ra đã bị cắt xén sẵn, và không có gì trên màn hình nói vì sao nó cụt.
        filterField.stringValue = ""
        resetShown()
        outline.reloadData()

        if tree.tooLarge {
            // Không phải lỗi — là một lựa chọn có chủ ý, nên nói bằng giọng khác lỗi.
            header.stringValue = L("Tài liệu quá lớn để dựng cây — dùng chế độ Code")
            return
        }
        if let failure = tree.failure {
            header.stringValue = LF("Không dựng được cây: %@", failure)
            return
        }
        header.stringValue = LF("%d nút", tree.count)
        expandFirstLevels()
    }

    // MARK: - Lọc

    /// Trả cây về nguyên vẹn — không lọc gì.
    private func resetShown() {
        shownRoots = tree.roots
        shownChildren = tree.nodes.map(\.children)
        matchCount = nil
    }

    @objc private func filterChanged() { applyFilter() }

    /// Lọc cây theo chữ trong ô lọc.
    ///
    /// ## Giữ TỔ TIÊN của nút khớp, không trả về một danh sách phẳng
    ///
    /// Một khoá `ten` có thể nằm ở mười chỗ khác nhau trong cùng tài liệu, và câu hỏi thật của
    /// người đang lọc gần như luôn là *"cái nào trong số đó"* — mà chỉ đường đi từ gốc mới trả
    /// lời được. Cắt phẳng thì mười dòng giống hệt nhau và người dùng phải bấm từng cái để đoán.
    ///
    /// ## Lọc theo cả NHÃN lẫn GIÁ TRỊ
    ///
    /// Đi tìm `Huế` trong một tệp JSON là chuyện thường ngang với đi tìm khoá `tinh`. Lọc mỗi
    /// nhãn thì nửa số câu hỏi không hỏi được, trong khi giá trị đã nằm sẵn trên màn hình ngay
    /// cạnh nhãn.
    private func applyFilter() {
        let needle = filterField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            resetShown()
            outline.reloadData()
            expandFirstLevels()
            header.stringValue = LF("%d nút", tree.count)
            return
        }

        // Dùng chung phép so của ô lọc CSV: gõ KHÔNG DẤU vẫn ra chữ có dấu.
        var keep = [Bool](repeating: false, count: tree.nodes.count)
        var matched = 0
        for (position, node) in tree.nodes.enumerated()
        where CSVFilter.matches(node.label, .contains(needle))
            || CSVFilter.matches(node.detail, .contains(needle)) {
            keep[position] = true
            matched += 1
        }

        // Kéo theo tổ tiên. Quét NGƯỢC từ nút cuối lên: con luôn nằm sau cha trong mảng phẳng
        // (cả ba bộ chỉ mục đều thêm cha trước con), nên một lượt là đủ — không cần đệ quy, và
        // cũng không cần bảng cha.
        for position in tree.nodes.indices.reversed() where !tree.nodes[position].children.isEmpty {
            if tree.nodes[position].children.contains(where: { keep[$0] }) { keep[position] = true }
        }

        shownRoots = tree.roots.filter { keep[$0] }
        shownChildren = tree.nodes.map { $0.children.filter { keep[$0] } }
        matchCount = matched

        outline.reloadData()
        // Mở HẾT phần còn lại: sau khi lọc, thứ còn trên màn hình đúng bằng thứ người dùng vừa
        // hỏi tới — bắt họ bấm mở từng tầng là bắt họ làm lại phép lọc bằng tay.
        for box in boxes where keep[box.index] { outline.expandItem(box) }
        header.stringValue = matched == 0 ? L("Không có kết quả") : LF("%d nút", matched)
    }

    /// Mở sẵn hai tầng đầu — xem ghi chú ở đầu lớp về vì sao là hai.
    private func expandFirstLevels() {
        for box in boxes where tree.nodes[box.index].depth < 2 {
            outline.expandItem(box)
        }
    }

    /// Mở đường xuống nút ứng với con nháy rồi chọn nó — **chiều ngược của phép nhảy về nguồn**.
    ///
    /// Không có vế này thì cây mở ra ở ĐẦU tài liệu dù người dùng vừa đứng ở dòng chín nghìn:
    /// hai tầng mở sẵn là một chỗ đứng chung cho mọi tệp, không phải chỗ đứng của người này.
    ///
    /// Mở SÂU HƠN hai tầng khi cần, và đó là chủ ý: luật hai tầng trả lời câu hỏi *"mở tệp này
    /// ra thì thấy gì"*, còn ở đây câu hỏi đã khác — *"chỗ tôi đang đứng nằm đâu trong cây"* — và
    /// một cây có mở mà không thấy chỗ ấy thì chưa trả lời được.
    ///
    /// Chọn hàng nhưng KHÔNG chạy hành động của hàng: hành động ấy nhảy về Code và đóng cây lại,
    /// tức bật View xong lại tắt ngay. `NSOutlineView` chỉ gọi `action` khi người dùng bấm thật,
    /// nên chỉ cần không tự gọi nó ở đây.
    func reveal(offset: Int) {
        let path = tree.path(containing: offset)
        guard let target = path.last, target < boxes.count else { return }
        // Mở từ GỐC xuống: một nút chỉ có hàng khi mọi tầng trên nó đã mở, nên thứ tự này bắt buộc.
        for index in path.dropLast() where index < boxes.count {
            outline.expandItem(boxes[index])
        }
        let row = outline.row(forItem: boxes[target])
        guard row >= 0 else { return }
        outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outline.scrollRowToVisible(row)
    }

    @objc private func rowClicked(_ sender: Any?) {
        activate(row: outline.clickedRow >= 0 ? outline.clickedRow : outline.selectedRow)
    }

    /// Enter đi qua ĐÚNG đường mà cú bấm chuột đi — một hành vi, một chỗ viết.
    private func activateSelectedRow() { activate(row: outline.selectedRow) }

    private func activate(row: Int) {
        guard row >= 0, let box = outline.item(atRow: row) as? TreeBox else { return }
        let node = tree.nodes[box.index]
        guard node.canJumpToSource else { return }
        onSelectRange?(node.range)
    }

    /// Đưa bàn phím về cây. Không có vế này thì phím bấm vẫn rơi vào vùng soạn thảo đang ẩn —
    /// người dùng gõ mà không thấy gì xảy ra, thứ khó đoán hơn hẳn một phím không có tác dụng.
    func takeFocus() { window?.makeFirstResponder(outline) }

    /// Đường dẫn của nút đang chọn — `nil` khi chưa chọn gì.
    ///
    /// Dùng cho ⌘C: cây đang che vùng soạn thảo, nên "chép" ở đây phải nghĩa là chép thứ người
    /// dùng đang NHÌN. Chép vùng chọn của một trình soạn thảo đang bị che là chép một thứ vô
    /// hình — và đúng cái vô hình ấy sẽ được dán ra chỗ khác.
    var selectedPathText: String? {
        let row = outline.selectedRow
        guard row >= 0, let box = outline.item(atRow: row) as? TreeBox else { return nil }
        let text = tree.pathText(of: box.index)
        return text.isEmpty ? nil : text
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let box = item as? TreeBox else { return shownRoots.count }
        return shownChildren[box.index].count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let box = item as? TreeBox else { return boxes[shownRoots[index]] }
        return boxes[shownChildren[box.index][index]]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let box = item as? TreeBox else { return false }
        return !shownChildren[box.index].isEmpty
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any)
        -> NSView? {
        guard let box = item as? TreeBox else { return nil }
        let node = tree.nodes[box.index]

        let text = NSMutableAttributedString(
            string: node.label,
            attributes: [.font: Tokens.Font.editor(size: 12),
                         .foregroundColor: NSColor.labelColor])
        if !node.detail.isEmpty {
            text.append(NSAttributedString(
                string: "  " + node.detail,
                attributes: [.font: Tokens.Font.editor(size: 12),
                             .foregroundColor: colour(for: node.kind)]))
        }

        let field = NSTextField(labelWithAttributedString: text)
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        let cell = NSTableCellView()
        cell.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    /// Màu theo KIỂU giá trị, dùng lại bảng màu sẵn có của sản phẩm.
    ///
    /// Không bịa bảng màu thứ hai: một cây tô bằng màu lạ sẽ dạy người dùng hai nghĩa cho cùng
    /// một màu, trong khi vùng soạn thảo ngay bên cạnh đã tô cú pháp bằng bảng màu kia.
    private func colour(for kind: StructureTree.Kind) -> NSColor {
        switch kind {
        case .object, .array, .element: return Tokens.Color.secondaryInk
        case .string, .text: return Tokens.Color.ember
        case .number: return Tokens.Color.action
        case .bool, .null: return Tokens.Color.gold
        case .attribute: return Tokens.Color.secondaryInk
        }
    }

    // MARK: - Cửa cho bộ tự kiểm

    var rowCountForSelfTest: Int { outline.numberOfRows }
    var headerForSelfTest: String { header.stringValue }
    var nodeCountForSelfTest: Int { tree.count }
    var selectedRowForSelfTest: Int { outline.selectedRow }

    /// Bấm vào hàng thứ `row` đúng như người dùng bấm.
    func clickRowForSelfTest(_ row: Int) {
        selectRowForSelfTest(row)
        rowClicked(nil)
    }

    /// Chọn hàng như mũi tên lên/xuống chọn — và KHÔNG kích hoạt gì. Phân biệt hai việc ấy là
    /// cả điểm của bài kiểm phím Enter: chọn là nhìn, kích hoạt mới là đi.
    func selectRowForSelfTest(_ row: Int) {
        guard row >= 0, row < outline.numberOfRows else { return }
        outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    /// Gõ vào ô lọc đúng như người dùng gõ — đi qua chính `applyFilter`, không gọi tắt vào trong.
    func setFilterForSelfTest(_ text: String) {
        filterField.stringValue = text
        filterChanged()
    }

    var visibleLabelsForSelfTest: [String] {
        (0 ..< outline.numberOfRows).map { labelForSelfTest(row: $0) }
    }

    func labelForSelfTest(row: Int) -> String {
        guard let box = outline.item(atRow: row) as? TreeBox else { return "" }
        return tree.nodes[box.index].label
    }

    /// Gõ Enter đúng như người dùng gõ — đi qua cả phép lọc mã phím, không gọi tắt vào trong.
    func pressReturnForSelfTest() {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window?.windowNumber ?? 0, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ) else { return }
        outline.keyDown(with: event)
    }

    /// Esc đi tới người nhận qua `cancelOperation`, không qua `keyDown` — nên bài kiểm cũng gọi
    /// đúng cửa ấy chứ không dựng một sự kiện phím giả rồi tin là nó đi cùng đường.
    func pressEscapeForSelfTest() { outline.cancelOperation(nil) }
}

extension StructureTreeView: NSSearchFieldDelegate {
    /// Lọc theo từng phím gõ. `action` của `NSSearchField` chỉ bắn khi gõ Enter hoặc sau một
    /// quãng nghỉ, nên thiếu vế này thì ô lọc trông như bị treo.
    func controlTextDidChange(_ notification: Notification) { applyFilter() }
}

/// `NSOutlineView` biết nghe hai phím kết thúc một lượt xem.
///
/// Cùng khuôn với `CSVTableViewList` của bảng CSV, và vì cùng lý do: `NSTableView` nuốt phím
/// Enter làm phím "sửa ô", còn Esc thì đi qua `cancelOperation` chứ không qua `keyDown`.
private final class StructureOutlineView: NSOutlineView {

    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // 36 = Return, 76 = Enter ở bàn phím số.
        guard event.keyCode == 36 || event.keyCode == 76 else { return super.keyDown(with: event) }
        onReturn?()
    }

    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

/// Hộp bọc chỉ số nút — `NSOutlineView` đòi item là `AnyObject`.
final class TreeBox {
    let index: Int
    init(_ index: Int) { self.index = index }
}
