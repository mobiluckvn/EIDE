import AppKit
import GEditorCore

/// Khung xem nhị phân — offset · hex · chữ, cho tệp cỡ bất kỳ.
///
/// ## Đọc qua `MappedFile`, không đọc tệp vào RAM
///
/// Dùng lại đúng thứ piece table đang dùng (ADR-02): tệp được ánh xạ bộ nhớ, kernel nạp trang
/// theo nhu cầu. Mở một tệp 1 GB ở chế độ nhị phân tốn đúng phần đang nhìn thấy.
///
/// ## Vì sao có PHÂN TRANG, dù dữ liệu đã ánh xạ sẵn
///
/// Đây là giới hạn của AppKit chứ không phải của phép đọc. `NSTableView` đặt các hàng theo toạ
/// độ điểm; một tệp 1 GB là **62,5 triệu hàng**, tức một tài liệu cao một tỉ điểm. Qua khoảng
/// mười sáu triệu điểm thì phép tính vị trí bắt đầu mất chính xác, và biểu hiện là hàng nhảy
/// chỗ khi cuộn — một khung hex nhảy chỗ thì vô dụng, vì thứ duy nhất nó dùng để làm là đọc
/// đúng offset.
///
/// Nên khung này hiện **một cửa sổ 4 MB** và có thanh điều hướng. 4 MB là 262.144 hàng ≈ 4,2
/// triệu điểm — nằm xa dưới ngưỡng mất chính xác, và vẫn đủ lớn để cuộn thoải mái trong một
/// vùng. Cửa sổ hiện tại luôn được nói ra ở thanh trên, không giấu: người dùng phải biết mình
/// đang nhìn phần nào của tệp.
final class HexViewerView: NSView, NSTableViewDataSource, NSTableViewDelegate {

    /// Số byte của một cửa sổ. Xem ghi chú ở đầu lớp về vì sao có con số này.
    static let windowBytes = 4 << 20

    var onStatus: ((String) -> Void)?

    private var file: MappedFile?
    private var path: String = ""
    /// Offset byte của đầu cửa sổ đang hiện. Luôn là bội của 16 để hàng không lệch cột.
    private(set) var windowStart = 0

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let toolbar = NSStackView()
    private let rangeLabel = NSTextField(labelWithString: "")
    private let offsetField = NSTextField()
    private let previousButton = NSButton()
    private let nextButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Dựng

    private func build() {
        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.rowHeight = 16
        table.gridStyleMask = []
        table.backgroundColor = Tokens.Color.editorBackground
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = false
        table.style = .plain

        // Ba cột, bề rộng CỐ ĐỊNH tính từ phông đơn cách. Để chúng co giãn theo nội dung thì
        // cột hex đổi bề ngang giữa dòng đủ 16 byte và dòng cuối thiếu byte, và cả bảng nhảy.
        let mono = Tokens.Font.editor(size: 12)
        let digit = ("0" as NSString).size(withAttributes: [.font: mono]).width
        for (id, chars) in [("offset", 10), ("hex", 50), ("ascii", 18)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.width = digit * CGFloat(chars)
            column.minWidth = column.width
            table.addTableColumn(column)
        }

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Tokens.Color.editorBackground
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        offsetField.placeholderString = L("Tới offset (vd 1F400 hoặc 0x1F400)")
        offsetField.font = Tokens.Font.monoInline(size: 11)
        offsetField.target = self
        offsetField.action = #selector(goToTypedOffset)
        offsetField.translatesAutoresizingMaskIntoConstraints = false
        offsetField.widthAnchor.constraint(equalToConstant: 220).isActive = true

        for (button, title, action) in [
            (previousButton, "‹", #selector(previousWindow)),
            (nextButton, "›", #selector(nextWindow)),
        ] {
            button.title = title
            button.bezelStyle = .rounded
            button.target = self
            button.action = action
        }
        let copyButton = NSButton(title: L("Chép dòng đã chọn"), target: self,
                                  action: #selector(copySelectedRows))
        copyButton.bezelStyle = .rounded
        copyButton.font = Tokens.Font.caption

        rangeLabel.font = Tokens.Font.caption
        rangeLabel.textColor = Tokens.Color.secondaryInk

        toolbar.addArrangedSubview(previousButton)
        toolbar.addArrangedSubview(nextButton)
        toolbar.addArrangedSubview(offsetField)
        toolbar.addArrangedSubview(copyButton)
        toolbar.addArrangedSubview(rangeLabel)

        addSubview(toolbar)
        addSubview(scroll)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Nạp

    func load(path: String) {
        self.path = path
        do {
            file = try MappedFile(path: path)
        } catch {
            file = nil
            onStatus?(LF("Không đọc được «%@»", (path as NSString).lastPathComponent))
        }
        windowStart = 0
        reload()
    }

    var fileSize: Int { file?.count ?? 0 }

    /// Số byte thật sự có trong cửa sổ đang hiện.
    private var windowLength: Int {
        max(0, min(Self.windowBytes, fileSize - windowStart))
    }

    private func reload() {
        table.reloadData()
        updateToolbar()
        table.scrollRowToVisible(0)
    }

    private func updateToolbar() {
        let size = fileSize
        previousButton.isEnabled = windowStart > 0
        nextButton.isEnabled = windowStart + Self.windowBytes < size
        guard size > 0 else {
            rangeLabel.stringValue = L("Tệp rỗng")
            return
        }
        let end = windowStart + windowLength
        rangeLabel.stringValue = LF(
            "0x%@ … 0x%@ trong %@",
            HexDump.offsetColumn(windowStart, size: size),
            HexDump.offsetColumn(max(end - 1, 0), size: size),
            ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        )
    }

    // MARK: - Điều hướng

    @objc private func previousWindow(_ sender: Any?) {
        go(toOffset: max(0, windowStart - Self.windowBytes))
    }

    @objc private func nextWindow(_ sender: Any?) {
        go(toOffset: windowStart + Self.windowBytes)
    }

    /// Nhảy tới một offset. Cửa sổ đặt sao cho offset ấy nằm trong đó, và **đầu cửa sổ luôn là
    /// bội của 16** — lệch đi thì mọi hàng lệch cột so với mọi công cụ hex khác.
    func go(toOffset offset: Int) {
        let size = fileSize
        guard size > 0 else { return }
        let clamped = min(max(0, offset), size - 1)
        let aligned = (clamped / Self.windowBytes) * Self.windowBytes
        windowStart = aligned
        table.reloadData()
        updateToolbar()
        let row = (clamped - aligned) / HexDump.bytesPerRow
        table.scrollRowToVisible(min(row, max(0, numberOfRows(in: table) - 1)))
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    /// Đọc offset người dùng gõ. Nhận cả `1F400`, `0x1F400` và số thập phân có tiền tố `#`.
    @objc private func goToTypedOffset(_ sender: Any?) {
        let raw = offsetField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let value: Int?
        if raw.hasPrefix("#") {
            value = Int(raw.dropFirst())
        } else {
            let body = raw.lowercased().hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
            value = Int(body, radix: 16)
        }
        guard let offset = value else {
            onStatus?(LF("Không đọc được offset «%@»", raw))
            return
        }
        guard offset < fileSize else {
            onStatus?(LF("Offset 0x%@ vượt quá cỡ tệp",
                         String(offset, radix: 16, uppercase: true)))
            return
        }
        go(toOffset: offset)
    }

    // MARK: - Đọc byte

    /// Byte của một hàng, đọc thẳng từ vùng nhớ đã ánh xạ.
    private func bytes(forRow row: Int) -> (offset: Int, bytes: [UInt8]) {
        let offset = windowStart + row * HexDump.bytesPerRow
        guard let file, offset < file.count else { return (offset, []) }
        let length = min(HexDump.bytesPerRow, file.count - offset)
        let slice = file.withUnsafeBytes { raw -> [UInt8] in
            guard let base = raw.baseAddress else { return [] }
            return [UInt8](UnsafeRawBufferPointer(start: base + offset, count: length))
        }
        return (offset, slice)
    }

    @objc private func copySelectedRows(_ sender: Any?) {
        let rows = table.selectedRowIndexes.isEmpty
            ? IndexSet(integersIn: 0 ..< numberOfRows(in: table))
            : table.selectedRowIndexes
        // Dùng CHÍNH hàm dựng chữ của khung xem — chép ra phải giống hệt thứ đang nhìn.
        let text = rows.map { row -> String in
            let (offset, slice) = bytes(forRow: row)
            return HexDump.line(offset: offset, bytes: slice, size: fileSize)
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        onStatus?(LF("Đã chép %d dòng", rows.count))
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        HexDump.rowCount(forSize: windowLength)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView? {
        guard let tableColumn else { return nil }
        let (offset, slice) = bytes(forRow: row)
        let text: String
        let colour: NSColor
        switch tableColumn.identifier.rawValue {
        case "offset":
            text = HexDump.offsetColumn(offset, size: fileSize)
            colour = Tokens.Color.secondaryInk
        case "hex":
            text = HexDump.hexColumn(slice)
            colour = .labelColor
        default:
            text = HexDump.asciiColumn(slice)
            colour = Tokens.Color.ember
        }

        let identifier = tableColumn.identifier
        let cell: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            cell = reused
        } else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = identifier
            cell.font = Tokens.Font.editor(size: 12)
            cell.isSelectable = true
            cell.lineBreakMode = .byClipping
        }
        cell.stringValue = text
        cell.textColor = colour
        return cell
    }

    // MARK: - Cửa cho bộ tự kiểm

    var rowCountForSelfTest: Int { numberOfRows(in: table) }
    var windowStartForSelfTest: Int { windowStart }

    func lineForSelfTest(row: Int) -> String {
        let (offset, slice) = bytes(forRow: row)
        return HexDump.line(offset: offset, bytes: slice, size: fileSize)
    }

    func goToOffsetTextForSelfTest(_ text: String) {
        offsetField.stringValue = text
        goToTypedOffset(nil)
    }
}
