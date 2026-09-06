import AppKit
import GEditorCore

/// Khung duyệt file nén — và cùng lúc là khung soi ruột của tệp Office.
///
/// **Một khung cho hai việc, vì đó là cùng một việc.** `.docx`, `.xlsx`, `.pptx` đều LÀ file
/// ZIP; khác biệt duy nhất là bên trong có bộ xương OOXML. Nên cùng bảng này mở được cả hai,
/// và người dùng Office có ngay một thứ hữu ích thật: xem được `word/document.xml`, lấy được
/// ảnh nhúng ra, thấy được tệp nào chiếm chỗ.
///
/// **Không bung cả file nén ra đĩa để xem.** Người dùng bấm vào một mục thì chỉ mục ấy được
/// giải nén, và giải vào bộ nhớ. Bung cả tệp là ghi hàng nghìn tệp vào một thư mục tạm mà
/// người dùng không xin, cho một thao tác chỉ để nhìn.
final class ArchiveViewerView: NSView {

    var onStatus: ((String) -> Void)?
    var onOpenTextInNewTab: ((String, String) -> Void)?
    var onOpenFile: ((String) -> Void)?

    private let scroll = NSScrollView()
    private let table = NSTableView()
    private let toolbar = NSStackView()
    private let summary = NSTextField(labelWithString: "")
    private var path: String?

    /// Một mục của kho, bất kể kho là ZIP hay TAR.
    ///
    /// Hai định dạng có cấu trúc khác hẳn nhau — ZIP có mục lục và nén từng mục, TAR là một
    /// luồng phẳng nén cả khối — nên chúng KHÔNG dùng chung một lớp đọc. Nhưng bảng hiện ra
    /// thì giống nhau, nên chúng gặp nhau ở đây, ở đúng chỗ hẹp nhất.
    private struct Row {
        var path: String
        var size: Int
        var compressed: Int?
        var modified: Date?
        var isEncrypted: Bool
        var read: () throws -> [UInt8]
    }

    private var rows: [Row] = []

    /// Đường "bung cả kho trong MỘT lượt duyệt", nếu bộ đọc của kho này có.
    ///
    /// `Row.read` mở lại kho cho từng mục. Với ZIP và TAR thì không sao — chúng có mục lục và
    /// nhảy thẳng tới chỗ cần. Nhưng `.7z` dạng khối đặc thì để đọc mục thứ n phải giải nén
    /// lại cả n−1 mục đứng trước, nên bung một kho 500 mục theo cách ấy là 125.000 lần giải
    /// nén thừa.
    ///
    /// `nil` = kho này không cần đường riêng; vòng lặp `Row.read` đã đủ nhanh.
    private var bulkRead: ((_ handler: (String, [UInt8]) throws -> Void) throws -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = Tokens.Metrics.listRowHeight
        table.target = self
        table.doubleAction = #selector(openSelected)
        table.allowsMultipleSelection = true

        for (identifier, title, width) in [
            ("ten", L("Tên"), CGFloat(360)),
            ("goc", L("Kích thước"), 100),
            ("nen", L("Đã nén"), 100),
            ("ti-le", L("Tỉ lệ"), 60),
            ("luc", L("Sửa lúc"), 140),
        ] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        for (title, action) in [
            (L("Mở mục đang chọn"), #selector(openSelected)),
            (L("Bung ra thư mục…"), #selector(extractAll)),
        ] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.font = Tokens.Font.caption
            toolbar.addArrangedSubview(button)
        }
        summary.font = Tokens.Font.caption
        summary.textColor = Tokens.Color.secondaryInk
        toolbar.addArrangedSubview(summary)

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

    func load(path: String, kind: MediaKind) {
        self.path = path
        do {
            let (doc, bulk) = try Self.readRows(path: path)
            rows = doc
            bulkRead = bulk
            // Thư mục không có nội dung để mở, và chúng chỉ làm dài danh sách. Cây thư mục vẫn
            // đọc ra được từ chính đường dẫn của từng mục.
            rows.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            table.reloadData()

            let total = rows.reduce(0) { $0 + $1.size }
            var parts = [LF("%d mục", rows.count),
                         LF("giải nén ra %@", MediaViewerView.humanSize(total))]
            if kind.isOfficeOpenXML {
                // Nói thẳng vì sao một tệp Word lại hiện ra bảng này. Im lặng thì người dùng
                // tưởng ứng dụng hỏng.
                parts.append(L("— ruột của tệp Office là file nén, đây là các phần bên trong"))
            }
            summary.stringValue = parts.joined(separator: "  ·  ")
        } catch {
            rows = []
            table.reloadData()
            summary.stringValue = "\(error)"
            onStatus?("\(error)")
        }
    }

    /// Đọc mục lục, chọn bộ đọc theo NỘI DUNG chứ không theo đuôi tệp.
    ///
    /// ZIP thử trước vì nó có chữ ký ở ngay bốn byte đầu; TAR thì không có chữ ký ở đầu (chữ ký
    /// `ustar` nằm ở offset 257, và TAR cổ không có chữ ký nào), nên nó là nhánh lùi.
    private static func readRows(
        path: String
    ) throws -> ([Row], ((_ handler: (String, [UInt8]) throws -> Void) throws -> Void)?) {
        if let zip = try? ZipArchive(path: path) {
            // ZIP có mục lục: đọc mục thứ n không phải đi qua n−1 mục trước, nên không cần
            // đường bung riêng.
            return (zip.entries.filter { !$0.isDirectory }.map { entry in
                Row(path: entry.path, size: entry.uncompressedSize,
                    compressed: entry.compressedSize, modified: entry.modified,
                    isEncrypted: entry.isEncrypted,
                    read: { try zip.data(for: entry) })
            }, nil)
        }
        if let tar = try? TarArchive(path: path) {
            return (tar.entries.filter { !$0.isDirectory }.map { entry in
                // TAR nén CẢ KHỐI, không nén từng mục — nên không có "cỡ đã nén" cho một mục,
                // và cột ấy để trống thay vì bịa ra một con số.
                Row(path: entry.path, size: entry.size, compressed: nil,
                    modified: entry.modified, isEncrypted: false,
                    read: { try tar.data(for: entry) })
            }, nil)
        }
        // Còn lại — 7z, rar, cab, lha, iso, xar, cpio, ar, và cả bzip2 mà `TarArchive` từ chối
        // — đi qua libarchive nạp từ nguồn. Liên kết tĩnh, nên bản App Store mở được y hệt bản
        // tải trực tiếp: không còn nhánh nào phải nói "định dạng này bản Store chưa mở được".
        let entries = try LibArchiveReader.list(path: path)
            .filter { !$0.isDirectory }
            .map { entry in
                // Kho dạng khối đặc (`.7z` solid, `.tar.bz2`) nén CẢ KHỐI chứ không nén từng
                // mục, nên không có "cỡ đã nén" của riêng một mục. Cột ấy để trống thay vì bịa
                // ra một con số.
                Row(path: entry.path, size: entry.size, compressed: nil,
                    modified: entry.modified, isEncrypted: entry.isEncrypted,
                    read: { try LibArchiveReader.data(archive: path, entry: entry) })
            }
        return (entries, { handler in
            try LibArchiveReader.readAll(path: path) { entry, bytes in
                try handler(entry.path, bytes)
            }
        })
    }

    // MARK: - Mở một mục

    @objc private func openSelected(_ sender: Any?) {
        guard let entry = rows[safe: table.selectedRow] else { return }
        do {
            let bytes = try entry.read()
            // Mục là văn bản thì mở thẳng thành tab — đó là thứ GEditor làm tốt nhất, và nó
            // biến cả file nén thành thứ tìm kiếm được.
            if let text = Self.asText(bytes) {
                onOpenTextInNewTab?(text, (entry.path as NSString).lastPathComponent)
                return
            }
            // Không phải văn bản: ghi ra thư mục tạm rồi mở như một tệp bình thường, để chính
            // khung xem ảnh/PDF lo phần còn lại. Không tự đoán tiếp ở đây.
            let temporary = NSTemporaryDirectory() + "/geditor-nen-" + UUID().uuidString
            try FileManager.default.createDirectory(atPath: temporary,
                                                    withIntermediateDirectories: true)
            let out = (temporary as NSString)
                .appendingPathComponent((entry.path as NSString).lastPathComponent)
            try Data(bytes).write(to: URL(fileURLWithPath: out))
            onOpenFile?(out)
        } catch {
            onStatus?("\(error)")
            presentAlert("\(error)")
        }
    }

    @objc private func extractAll(_ sender: Any?) {
        guard !rows.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("Bung vào đây")
        guard Unattended.chooseFile(panel) == .OK, let target = panel.url else { return }
        extract(into: target)
    }

    /// Bung mọi mục vào `target`.
    ///
    /// Tách khỏi phần CHỌN THƯ MỤC vì lượt chạy không người trả về `.abort` ở mọi hộp chọn file
    /// — cố ý, xem `Unattended.chooseFile`. Gộp hai việc thì cả phép bung, kể cả phép chặn Zip
    /// Slip trong đó, không có cách nào chạy được dưới bộ tự kiểm: một hàng rào chỉ có trên
    /// giấy. Ở đây bài kiểm bỏ qua đúng cái hộp thoại, phần còn lại đi nguyên đường thật.
    private func extract(into target: URL) {
        var written = 0
        var refused: [String] = []
        var failed: [String] = []

        /// Ghi MỘT mục ra đĩa. Dùng chung cho cả hai đường bên dưới, để phép kiểm Zip Slip chỉ
        /// tồn tại ở đúng một chỗ — hai bản sao của một phép kiểm an toàn thì sớm muộn cũng có
        /// một bản bị sửa mà bản kia không.
        func ghi(_ entryPath: String, _ bytes: [UInt8]) {
            // Zip Slip: mục có đường dẫn thoát ra ngoài thư mục đích thì BỎ, và nói ra. Bỏ im
            // lặng cũng an toàn, nhưng nó giấu mất chuyện tệp nén này đang cố làm gì.
            //
            // Áp cho CẢ TAR và 7z, không riêng ZIP: mọi định dạng kho đều chứa đường dẫn tuỳ
            // ý, và lỗ hổng ấy có tuổi đời còn lớn hơn tên gọi "Zip Slip".
            guard let destination = ZipArchive.safeDestination(
                for: entryPath, under: target.path) else {
                refused.append(entryPath)
                return
            }
            do {
                try FileManager.default.createDirectory(
                    atPath: (destination as NSString).deletingLastPathComponent,
                    withIntermediateDirectories: true)
                try Data(bytes).write(to: URL(fileURLWithPath: destination))
                written += 1
            } catch {
                failed.append(entryPath)
            }
        }

        if let bulk = bulkRead {
            // Kho không có mục lục nhảy thẳng được: duyệt MỘT lượt và ghi ra ngay khi đi qua.
            do {
                try bulk { entryPath, bytes in ghi(entryPath, bytes) }
            } catch {
                // Lỗi ở giữa lượt duyệt thì phần đã bung vẫn còn trên đĩa và vẫn dùng được;
                // báo phần chưa xong thay vì im lặng coi như đủ.
                onStatus?("\(error)")
                summary.stringValue = "\(error)"
                return
            }
        } else {
            for entry in rows {
                do { ghi(entry.path, try entry.read()) } catch { failed.append(entry.path) }
            }
        }

        var message = LF("Đã bung %d mục", written)
        if !failed.isEmpty {
            message += "  ·  " + LF("%d mục hỏng", failed.count)
        }
        if !refused.isEmpty {
            message += "  ·  " + LF("%d mục bị TỪ CHỐI vì đường dẫn thoát ra ngoài",
                                        refused.count)
        }
        onStatus?(message)
        summary.stringValue = message
    }

    private func presentAlert(_ text: String) {
        let alert = NSAlert()
        alert.messageText = L("Không mở được mục này")
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        _ = Unattended.ask(alert)
    }

    /// Byte này có phải văn bản đọc được không.
    ///
    /// Cùng phép đo với `MediaKind`: byte NUL là dấu hiệu rẻ và đủ đúng. Thêm vế UTF-8 hợp lệ
    /// vì ở đây ta sắp DỰNG một chuỗi — khác với chỗ kia chỉ phân loại.
    static func asText(_ bytes: [UInt8]) -> String? {
        guard !bytes.contains(0) else { return nil }
        guard let text = String(bytes: bytes, encoding: .utf8) else { return nil }
        return text
    }

    // MARK: - Cho bài tự kiểm

    var rowCountForSelfTest: Int { rows.count }
    var entryPathsForSelfTest: [String] { rows.map(\.path) }
    var summaryForSelfTest: String { summary.stringValue }
    func extractAllForSelfTest(into target: URL) { extract(into: target) }
    func selectRowForSelfTest(_ index: Int) {
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }
    func openSelectedForSelfTest() { openSelected(nil) }
}

extension ArchiveViewerView: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let entry = rows[safe: row], let tableColumn else { return nil }
        let text: String
        var alignment = NSTextAlignment.left
        switch tableColumn.identifier.rawValue {
        case "ten": text = entry.path
        case "goc":
            text = MediaViewerView.humanSize(entry.size)
            alignment = .right
        case "nen":
            text = entry.compressed.map(MediaViewerView.humanSize) ?? "—"
            alignment = .right
        case "ti-le":
            let ratio = entry.compressed.flatMap { compressed -> Double? in
                entry.size > 0 ? Double(compressed) / Double(entry.size) : nil
            }
            text = ratio.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
            alignment = .right
        default:
            text = entry.modified.map { Self.stamp.string(from: $0) } ?? "—"
        }

        let identifier = NSUserInterfaceItemIdentifier("o")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
            ?? {
                let field = NSTextField(labelWithString: "")
                field.identifier = identifier
                field.font = Tokens.Font.caption
                field.lineBreakMode = .byTruncatingMiddle
                return field
            }()
        cell.stringValue = text
        cell.alignment = alignment
        // Mục có mật khẩu thì phải nhìn ra ngay, chứ không phải bấm vào mới biết.
        cell.textColor = entry.isEncrypted && tableColumn.identifier.rawValue == "ten"
            ? Tokens.Color.secondaryInk
            : Tokens.Color.editorInk
        return cell
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
