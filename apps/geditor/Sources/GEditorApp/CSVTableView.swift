import AppKit
import GEditorCore

/// Table view cho file CSV (FR-CSV-403).
///
/// Quan hệ với văn bản, theo SAD Hình 4: **văn bản là nguồn sự thật, bảng là bản chiếu**.
/// Bảng không giữ một bản dữ liệu riêng — mỗi ô đọc thẳng từ buffer qua `CSVRowIndex`, và mỗi
/// lần sửa ô là một `TextEdit` trên chính buffer ấy. Giữ bản sao thì hai bên trôi khỏi nhau,
/// và người dùng sẽ lưu ra file cái mà họ KHÔNG nhìn thấy.
///
/// Bảng ảo hoá hoàn toàn: `NSTableView` chỉ hỏi những hàng đang nhìn thấy, và chỉ mục trả lời
/// một màn hình bốn mươi hàng trong 0,06 ms trên tài liệu một triệu hàng (đo ở
/// `scripts/run-csv-table-kpi.sh`).
final class CSVTableView: NSView {

    // NFR-USE-03: đặt tên cho NHÓM. Bảng và danh sách bên trong thì AppKit tự mô tả, nhưng
    // nếu nhóm không có tên thì VoiceOver đọc ra một danh sách trôi nổi không rõ của cái gì.
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { L("Bảng dữ liệu CSV") }

    /// Chiều rộng cột số thứ tự.
    private static let numberColumnWidth: CGFloat = 64
    private static let defaultColumnWidth: CGFloat = 140
    private static let toolbarHeight: CGFloat = 34

    // MARK: - Trạng thái

    private var buffer: TextBuffer?
    private var index: CSVRowIndex?
    private var dialect: CSVDialect = .comma

    /// Hàng đầu có phải tiêu đề không. Chưa có UI đổi; mặc định CÓ, đúng như phần lớn file CSV.
    private var hasHeader = true

    /// Thứ tự hiển thị hiện hành. `nil` = thứ tự file.
    private var sortOrder: CSVSort.Order?

    /// Tập hàng khớp bộ lọc, theo thứ tự file. `nil` = không lọc gì.
    ///
    /// Lọc đứng TRƯỚC sắp xếp trong đường hiển thị: người dùng lọc để thu hẹp, rồi sắp xếp
    /// phần còn lại. Làm ngược lại thì mỗi lần gõ thêm một ký tự sẽ phải sắp xếp lại cả file.
    private var filteredRows: [Int]?
    private var filterTotal = 0
    private var filterToken: CancelToken?
    private var filterPartial = false

    /// Danh sách hàng file theo đúng thứ tự BẢNG đang hiện — kết quả của lọc rồi tới sắp xếp.
    ///
    /// Tính sẵn MỘT lần mỗi khi lọc hoặc sắp xếp đổi. Ghép hai thứ ấy ngay trong hàm tra cứu
    /// sẽ dựng lại cùng một danh sách cho mỗi Ô mà `NSTableView` hỏi tới.
    private var displayRows: [Int]?

    /// Token của lần sắp xếp đang chạy nền.
    private var sortToken: CancelToken?

    /// Đệm một hàng đã đọc.
    ///
    /// `NSTableView` hỏi từng Ô một, nên một hàng sáu cột là sáu câu hỏi liền nhau cho cùng
    /// một hàng. Nhớ đúng một hàng vừa đọc là đủ để sáu câu hỏi ấy thành một lần phân tích.
    private var cachedRow: (row: Int, values: [String])?

    // MARK: - View

    private let scrollView = NSScrollView()
    private let filterBar = CSVFilterBar()
    private let table = CSVTableViewList()
    private let toolbar = NSView()
    private let hiddenNote = NSTextField(labelWithString: "")
    private let sortLabel = NSTextField(labelWithString: "")
    private let applySortButton = NSButton()
    private let validateButton = NSButton()
    private let convertButton = NSButton()
    private let modeControl = NSSegmentedControl()
    private let filterLabel = NSTextField(labelWithString: "")
    private let exportFilteredButton = NSButton()

    /// Lệnh trên một cột, phát ra từ menu ngữ cảnh của hàng tiêu đề (FR-CSV-404/408).
    ///
    /// Chỉ ẨN CỘT là chuyện của riêng bảng — nó không đụng vào file. Bốn lệnh còn lại sửa
    /// văn bản, nên chúng đi ngược lên chỗ gọi để qua đúng đường `apply` (có chốt chặn tài
    /// liệu chỉ-đọc, có gộp thành một bước undo).
    enum ColumnCommand {
        case rename(Int)
        case delete(Int)
        case insertLeft(Int)
        case insertRight(Int)
        case move(from: Int, to: Int)
    }

    var onColumnCommand: ((ColumnCommand) -> Void)?

    /// Người dùng bấm L("Văn bản").
    var onSwitchToText: (() -> Void)?
    /// Người dùng bấm "Kiểm tra dữ liệu".
    var onValidate: (() -> Void)?
    /// Người dùng bấm L("Chuyển đổi ▾").
    var onConvert: (() -> Void)?
    /// Số dòng khớp bộ lọc đổi; `nil` = không lọc gì.
    var onFilterChanged: ((String?) -> Void)?
    /// Người dùng bấm L("Xuất dòng khớp").
    var onExportFiltered: (([Int]) -> Void)?

    /// Những ô SAI KIỂU, theo hàng file → tập cột (FR-CSV-405).
    ///
    /// Danh sách lỗi nói "hàng 1204, cột doanh_thu"; màu trên bảng nói "chỗ này đây" khi người
    /// dùng đã tới đúng hàng ấy. Thiếu màu thì họ vẫn phải dò bằng mắt qua mười hai cột.
    var typeIssues: [Int: Set<Int>] = [:] {
        didSet { table.reloadData() }
    }
    /// Sửa một ô — chỗ gọi biến nó thành `TextEdit` và một bước undo.
    var onEditCell: ((_ row: Int, _ column: Int, _ newValue: String) -> Void)?
    /// Thông báo ngắn (dùng chung chỗ hiện trạng thái với panel tìm kiếm).
    var onStatus: ((String) -> Void)?
    /// Ghi thứ tự đang hiển thị vào file.
    var onApplySort: ((CSVSort.Order) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Nền layer KHÔNG tự theo appearance — xem `NSView.applyLayerBackground`.
    ///
    /// Đây chính là view làm lộ ra cả lỗi: ảnh `--capture csv` cho một bảng nền TỐI trong khi
    /// cảnh `trong` của cùng lượt chạy thì sáng.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayerBackground(Tokens.Color.editorBackground)
        toolbar.applyLayerBackground(Tokens.Color.chrome)
    }


    private func build() {
        wantsLayer = true
        applyLayerBackground(Tokens.Color.editorBackground)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.applyLayerBackground(Tokens.Color.chrome)

        modeControl.segmentCount = 2
        modeControl.setLabel(L("Bảng"), forSegment: 0)
        modeControl.setLabel(L("Văn bản"), forSegment: 1)
        modeControl.selectedSegment = 0
        modeControl.segmentStyle = .rounded
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        sortLabel.font = Tokens.Font.caption
        sortLabel.textColor = Tokens.Color.secondaryInk
        sortLabel.translatesAutoresizingMaskIntoConstraints = false

        applySortButton.title = L("Áp sắp xếp vào file")
        applySortButton.bezelStyle = .rounded
        applySortButton.font = Tokens.Font.caption
        applySortButton.target = self
        applySortButton.action = #selector(applySortTapped)
        applySortButton.isHidden = true
        applySortButton.translatesAutoresizingMaskIntoConstraints = false

        validateButton.title = "Kiểm tra dữ liệu"
        validateButton.bezelStyle = .rounded
        validateButton.font = Tokens.Font.caption
        validateButton.target = self
        validateButton.action = #selector(validateTapped)
        validateButton.translatesAutoresizingMaskIntoConstraints = false

        toolbar.addSubview(modeControl)
        toolbar.addSubview(sortLabel)
        toolbar.addSubview(applySortButton)
        convertButton.title = L("Chuyển đổi ▾")
        convertButton.bezelStyle = .rounded
        convertButton.font = Tokens.Font.caption
        convertButton.target = self
        convertButton.action = #selector(convertTapped)
        convertButton.translatesAutoresizingMaskIntoConstraints = false

        filterLabel.font = Tokens.Font.caption
        filterLabel.textColor = Tokens.Color.secondaryInk
        filterLabel.translatesAutoresizingMaskIntoConstraints = false

        exportFilteredButton.title = L("Xuất dòng khớp")
        exportFilteredButton.bezelStyle = .rounded
        exportFilteredButton.font = Tokens.Font.caption
        exportFilteredButton.target = self
        exportFilteredButton.action = #selector(exportFiltered)
        exportFilteredButton.isHidden = true
        exportFilteredButton.translatesAutoresizingMaskIntoConstraints = false

        toolbar.addSubview(filterLabel)
        toolbar.addSubview(exportFilteredButton)
        toolbar.addSubview(validateButton)
        toolbar.addSubview(convertButton)

        table.dataSource = self
        table.delegate = self
        table.rowHeight = Tokens.Metrics.csvRowHeightCompact
        // Nền của BẢNG đọc từ theme, không để `NSTableView` tự lấy màu hệ thống.
        //
        // Thiếu dòng này thì thân bảng đi theo chế độ Sáng/Tối của MACOS trong khi cả cửa sổ
        // còn lại đi theo `Tokens.theme`: chọn theme "Than chì" trên một máy đang để chế độ
        // sáng thì bảng trắng nằm giữa một cửa sổ tối. Panel SQL đã làm đúng cách này từ đầu.
        //
        // Vạch sọc xen kẽ GIỮ NGUYÊN. Màu của nó do hệ thống cấp nên vẫn còn lệch một chút,
        // nhưng đó là một lựa chọn thiết kế về khả năng đọc bảng, không phải chỗ để tôi đổi
        // dựa trên một tấm ảnh.
        table.backgroundColor = Tokens.Color.editorBackground
        table.usesAlternatingRowBackgroundColors = true
        table.allowsColumnResizing = true
        table.allowsColumnReordering = false
        table.style = .plain
        table.gridStyleMask = [.solidVerticalGridLineMask]
        table.onStartEditing = { [weak self] row, column in
            self?.table.editColumn(column, row: row, with: nil, select: true)
        }
        // Chuột phải trên hàng tiêu đề: menu thao tác cột (FR-CSV-404/408).
        let header = CSVTableHeaderView()
        header.menuForColumn = { [weak self] visibleIndex in
            guard let self else { return nil }
            let logical = visibleIndex >= 0 && visibleIndex < self.table.tableColumns.count
                ? self.logicalColumn(of: self.table.tableColumns[visibleIndex])
                : nil
            return self.headerMenu(forLogicalColumn: logical)
        }
        table.headerView = header

        hiddenNote.font = Tokens.Font.caption
        hiddenNote.textColor = Tokens.Color.secondaryInk
        hiddenNote.isHidden = true
        hiddenNote.translatesAutoresizingMaskIntoConstraints = false

        NotificationCenter.default.addObserver(
            self, selector: #selector(tableColumnDidMove(_:)),
            name: NSTableView.columnDidMoveNotification, object: table
        )

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Tokens.Color.editorBackground
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterBar.onChange = { [weak self] in self?.filterChanged() }

        addSubview(toolbar)
        addSubview(filterBar)
        addSubview(scrollView)
        addSubview(hiddenNote)

        // Thanh lọc bám theo độ cuộn ngang của bảng, hệt hàng tiêu đề dính ở chế độ văn bản.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(tableDidScroll(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )

        NSLayoutConstraint.activate([
            hiddenNote.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Tokens.Metrics.spacing(2)
            ),
            hiddenNote.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Tokens.Metrics.spacing(2)
            ),
            hiddenNote.bottomAnchor.constraint(equalTo: bottomAnchor),

            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: Self.toolbarHeight),

            modeControl.leadingAnchor.constraint(
                equalTo: toolbar.leadingAnchor, constant: Tokens.Metrics.spacing(2)
            ),
            modeControl.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            sortLabel.leadingAnchor.constraint(
                equalTo: modeControl.trailingAnchor, constant: Tokens.Metrics.spacing(3)
            ),
            sortLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            filterLabel.leadingAnchor.constraint(equalTo: sortLabel.trailingAnchor, constant: 12),
            filterLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            exportFilteredButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: filterLabel.trailingAnchor, constant: 8
            ),
            // Neo vào nút bên trái của dãy, KHÔNG vào `validateButton`: chỗ ấy đã có
            // `convertButton`, và hai nút cùng một mỏ neo thì chúng nằm chồng lên nhau —
            // thấy rõ trên ảnh chụp, chữ của hai nút đan vào nhau.
            exportFilteredButton.trailingAnchor.constraint(
                equalTo: applySortButton.leadingAnchor, constant: -8
            ),
            exportFilteredButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            applySortButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: sortLabel.trailingAnchor, constant: Tokens.Metrics.spacing(2)
            ),
            applySortButton.trailingAnchor.constraint(
                equalTo: convertButton.leadingAnchor, constant: -Tokens.Metrics.spacing(2)
            ),
            convertButton.trailingAnchor.constraint(
                equalTo: validateButton.leadingAnchor, constant: -8
            ),
            convertButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            applySortButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            validateButton.trailingAnchor.constraint(
                equalTo: toolbar.trailingAnchor, constant: -Tokens.Metrics.spacing(2)
            ),
            validateButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            filterBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            filterBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: CSVFilterBar.height),

            scrollView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Bảng dừng NGAY TRÊN dòng nhắc, không chạy xuống hết khung. Bản đầu ghim cả hai
            // vào đáy và dòng nhắc vẽ đè lên hàng cuối — nhìn ảnh chụp mới thấy, đọc code thì
            // không.
            scrollView.bottomAnchor.constraint(equalTo: hiddenNote.topAnchor),
        ])
        // Chiều cao 0 khi không có cột ẩn: chừa sẵn một dòng trống dưới bảng là lấy mất chỗ
        // hiển thị dữ liệu suốt thời gian không dùng tới.
        hiddenNoteHeight = hiddenNote.heightAnchor.constraint(equalToConstant: 0)
        hiddenNoteHeight.isActive = true
    }

    // MARK: - Nạp dữ liệu

    /// Gắn tài liệu và chỉ mục đã dựng sẵn.
    ///
    /// Chỉ mục dựng ở luồng nền TRƯỚC khi gọi vào đây — dựng chỉ mục một triệu hàng mất khoảng
    /// một phần ba giây, và làm việc ấy trên luồng chính là đứng hình đúng lúc người dùng vừa
    /// bấm chuyển chế độ.
    func present(buffer: TextBuffer, index: CSVRowIndex, dialect: CSVDialect) {
        self.buffer = buffer
        self.index = index
        self.dialect = dialect
        sortOrder = nil
        // Bộ lọc là của TÀI LIỆU CŨ. Giữ lại thì mở file khác xong bảng chỉ hiện vài hàng mà
        // không ai hiểu vì sao — và mọi thao tác sau đó (sửa ô, xóa cột) chạy trên một tập hàng
        // mà người dùng tưởng là cả file. Một bài tự kiểm không liên quan đã đỏ vì đúng chỗ này.
        filteredRows = nil
        displayRows = nil
        filterPartial = false
        filterToken?.cancel()
        filterBar.clear(notify: false)
        updateFilterLabel()
        cachedRow = nil
        // Cột ẩn là chỉ số LOGIC của tài liệu đang xem. Giữ lại khi nạp tài liệu khác thì
        // bảng lặng lẽ giấu đi một cột bất kỳ của file mới — cùng loại lỗi với việc giữ dấu
        // dòng khi đổi tài liệu, và cùng cách sửa. Bộ tự kiểm bắt được vì nó dùng chung một
        // cửa sổ cho mọi bài: cột ẩn của bài trước làm ba bài sau đỏ.
        hiddenColumns.removeAll()
        rebuildColumns()
        updateSortLabel()
        table.reloadData()
    }

    /// Hàng dữ liệu đầu tiên (bỏ qua hàng tiêu đề).
    private var firstDataRow: Int { hasHeader ? 1 : 0 }

    /// Số hàng trong FILE ứng với hàng thứ `display` của bảng.
    private func fileRow(forDisplayRow display: Int) -> Int? {
        if let displayRows {
            guard display >= 0, display < displayRows.count else { return nil }
            return displayRows[display]
        }
        if let sortOrder {
            guard display >= 0, display < sortOrder.rows.count else { return nil }
            return sortOrder.rows[display]
        }
        guard let index else { return nil }
        let row = display + firstDataRow
        return row < index.rowCount ? row : nil
    }

    /// Hàng bảng ứng với hàng file — dùng khi chuyển từ văn bản sang bảng.
    func displayRow(forFileRow row: Int) -> Int {
        if let sortOrder, let position = sortOrder.rows.firstIndex(of: row) { return position }
        return Swift.max(0, row - firstDataRow)
    }

    private func values(ofDisplayRow display: Int) -> [String] {
        if let cachedRow, cachedRow.row == display { return cachedRow.values }
        guard let buffer, let index, let row = fileRow(forDisplayRow: display) else { return [] }
        let values = index.values(ofRow: row, in: buffer)
        cachedRow = (display, values)
        return values
    }

    /// Tên các cột, lấy từ hàng tiêu đề.
    private func headerNames() -> [String] {
        guard let buffer, let index, hasHeader, index.rowCount > 0 else { return [] }
        return index.values(ofRow: 0, in: buffer)
    }

    /// Các cột đang ẨN (chỉ số LOGIC).
    ///
    /// Ẩn là chuyện của bảng, không phải của file: cột vẫn còn nguyên trong văn bản, chỉ là
    /// không chiếm chỗ trên màn hình. Trộn "ẩn" với "xóa" là cách mất dữ liệu nhanh nhất, nên
    /// hai lệnh nằm cách nhau trong menu và lệnh xóa nói rõ nó sửa file.
    private var hiddenColumns: Set<Int> = []

    private func rebuildColumns() {
        isRebuilding = true
        defer {
            isRebuilding = false
            lastKnownColumnOrder = table.tableColumns.compactMap(logicalColumn)
        }
        for column in table.tableColumns { table.removeTableColumn(column) }
        guard let index else { return }

        let numberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("#"))
        numberColumn.title = "#"
        numberColumn.width = Self.numberColumnWidth
        numberColumn.resizingMask = .userResizingMask
        table.addTableColumn(numberColumn)

        // Dựng theo hàng RỘNG NHẤT, không theo hàng tiêu đề. Một hàng thừa cột mà bảng chỉ có
        // số cột của tiêu đề thì phần thừa biến mất khỏi màn hình — và thứ người dùng không
        // nhìn thấy là thứ họ sẽ vô tình xoá.
        let names = headerNames()
        for column in 0 ..< Swift.max(index.widestRowColumnCount, 1) {
            guard !hiddenColumns.contains(column) else { continue }
            let item = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(column)"))
            item.title = column < names.count && !names[column].isEmpty
                ? names[column]
                : LF("Cột %d", column + 1)
            item.width = Self.defaultColumnWidth
            item.resizingMask = .userResizingMask
            table.addTableColumn(item)
        }
        // Kéo tiêu đề để hoán vị chỉ mở khi KHÔNG có cột nào đang ẩn — xem `columnDidMove`.
        table.allowsColumnReordering = hiddenColumns.isEmpty
        syncFilterBar()
        updateHiddenNote()
    }

    /// Dòng nhắc "Cột ẩn: …" dưới bảng.
    ///
    /// Bắt buộc phải có: một cột biến mất khỏi màn hình mà không có gì nhắc thì người dùng sẽ
    /// tin là file không có cột ấy — rồi xuất ra JSON và ngạc nhiên.
    private func updateHiddenNote() {
        guard !hiddenColumns.isEmpty else {
            hiddenNote.stringValue = ""
            hiddenNote.isHidden = true
            hiddenNoteHeight.constant = 0
            return
        }
        let names = hiddenColumns.sorted().map(columnName)
        hiddenNote.stringValue =
            LF("Cột ẩn: %@ (%d) — hiện lại từ menu ngữ cảnh trên hàng tiêu đề",
                   names.joined(separator: ", "), names.count)
        hiddenNote.isHidden = false
        hiddenNoteHeight.constant = Self.hiddenNoteHeightWhenShown
    }

    private static let hiddenNoteHeightWhenShown: CGFloat = 20
    private var hiddenNoteHeight: NSLayoutConstraint!

    // MARK: - Menu ngữ cảnh trên hàng tiêu đề (FR-CSV-404/408)

    fileprivate func headerMenu(forLogicalColumn logical: Int?) -> NSMenu {
        let menu = NSMenu()

        if let logical {
            let name = columnName(logical)
            menu.addItem(withTitle: LF("Cột %d: %@", logical + 1, name),
                         action: nil, keyEquivalent: "")
                .isEnabled = false
            menu.addItem(.separator())

            add(to: menu, "Ẩn cột này") { [weak self] in
                self?.hide(column: logical)
            }
            add(to: menu, "Đổi tên tiêu đề…") { [weak self] in
                self?.onColumnCommand?(.rename(logical))
            }
            menu.addItem(.separator())
            add(to: menu, "Chèn cột trống bên trái") { [weak self] in
                self?.onColumnCommand?(.insertLeft(logical))
            }
            add(to: menu, "Chèn cột trống bên phải") { [weak self] in
                self?.onColumnCommand?(.insertRight(logical))
            }
            menu.addItem(.separator())
            // Xóa nằm CUỐI và cách hẳn nhóm trên: nó là lệnh duy nhất trong menu này làm mất
            // dữ liệu, và đặt nó cạnh "Ẩn cột" là mời bấm nhầm.
            add(to: menu, "Xóa cột này khỏi file…") { [weak self] in
                self?.onColumnCommand?(.delete(logical))
            }
        }

        if !hiddenColumns.isEmpty {
            menu.addItem(.separator())
            for column in hiddenColumns.sorted() {
                add(to: menu, "Hiện lại: %@",
                    title: LF("Hiện lại: %@", columnName(column))) { [weak self] in
                    self?.show(column: column)
                }
            }
        }
        return menu
    }

    /// Thêm một mục vào menu ngữ cảnh, tra bản dịch VÀ biểu tượng từ cùng một khoá.
    ///
    /// Nhận khoá GỐC chứ không nhận chuỗi đã dịch — cùng luật với `AppDelegate.makeMenu`. Bản
    /// trước nhận `L("Ẩn cột này")` đã dịch sẵn; muốn tra thêm biểu tượng thì phải dịch ngược,
    /// mà dịch ngược thì trượt ở mọi thứ tiếng trừ tiếng Việt.
    ///
    /// `title` chỉ dùng cho mục có nhan đề ĐỘNG ("Hiện lại: tên cột"): khoá vẫn là chuỗi định
    /// dạng, còn nhan đề đã ghép sẵn.
    private func add(to menu: NSMenu, _ key: String, title: String? = nil,
                     action: @escaping () -> Void) {
        let item = NSMenuItem(title: title ?? L(key),
                              action: #selector(runMenuAction(_:)), keyEquivalent: "")
        item.image = MenuIcons.image(for: key)
        item.target = self
        item.representedObject = ActionBox(action)
        menu.addItem(item)
    }

    /// Hộp giữ closure cho `NSMenuItem` — `representedObject` cần một `AnyObject`.
    private final class ActionBox {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }

    @objc private func runMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? ActionBox)?.run()
    }

    private func hide(column: Int) {
        // Không cho ẩn cột CUỐI CÙNG đang hiện: một cái bảng không còn cột nào thì không có
        // đường nào bấm chuột phải để hiện lại.
        guard table.tableColumns.count > 2 else {
            onStatus?(L("Phải còn ít nhất một cột đang hiện"))
            return
        }
        hiddenColumns.insert(column)
        rebuildColumns()
        table.reloadData()
        onStatus?(LF("Đã ẩn cột %@ — cột vẫn còn nguyên trong file",
                         columnName(column)))
    }

    private func show(column: Int) {
        hiddenColumns.remove(column)
        rebuildColumns()
        table.reloadData()
    }

    /// Người dùng vừa kéo một tiêu đề sang chỗ khác.
    ///
    /// `NSTableView` đã đổi chỗ cột trên màn hình rồi; việc ở đây là dịch cú kéo ấy thành một
    /// phép hoán vị TRONG FILE. Sau khi văn bản đổi, chỗ gọi dựng lại bảng từ thứ tự mới của
    /// file, nên hai bên gặp lại nhau ở đúng một trạng thái.
    ///
    /// Dùng thẳng chỉ số cũ/mới mà thông báo mang theo, KHÔNG suy ra từ việc so hai danh sách
    /// thứ tự: cách so ấy đúng khi kéo sang trái và sai khi kéo sang phải. Kéo cột 0 tới cuối
    /// trong ba cột cho danh sách mới [1,2,0], và chỗ khác nhau ĐẦU TIÊN nằm ở vị trí 0 —
    /// suy ra "cột 1 dời về 0", tức hoán vị sai hẳn.
    fileprivate func columnDidMove(from oldIndex: Int, to newIndex: Int) {
        guard !isRebuilding, oldIndex >= 1, newIndex >= 1 else { return }
        // Chỉ số ở đây tính cả cột "#" đứng đầu, nên trừ một để về vị trí giữa các cột dữ
        // liệu. Và vì cột dữ liệu chỉ khớp một-một với cột LOGIC khi không có cột nào ẩn,
        // kéo tiêu đề bị khóa lúc đang ẩn cột (xem `rebuildColumns`).
        guard oldIndex - 1 < lastKnownColumnOrder.count else { return }
        let from = lastKnownColumnOrder[oldIndex - 1]
        onColumnCommand?(.move(from: from, to: newIndex - 1))
    }

    /// Thứ tự cột lần cuối bảng dựng ra — mốc để dịch chỉ số hiển thị sang chỉ số logic.
    private var lastKnownColumnOrder: [Int] = []
    private var isRebuilding = false

    // MARK: - Sắp xếp

    /// Bấm tiêu đề cột: sắp xếp HIỂN THỊ. File không đổi một byte.
    fileprivate func headerClicked(_ column: NSTableColumn) {
        guard let logical = logicalColumn(of: column), let buffer, let index else { return }

        // Bấm lại đúng cột đang sắp thì ĐẢO HƯỚNG; bấm lần thứ ba thì bỏ sắp xếp, trở về thứ
        // tự file. Không có đường quay về thứ tự gốc thì người dùng phải đóng mở lại file.
        let direction: CSVSort.Direction
        if let sortOrder, sortOrder.column == logical {
            guard sortOrder.direction == .ascending else { return clearSort() }
            direction = .descending
        } else {
            direction = .ascending
        }

        sortToken?.cancel()
        let token = CancelToken()
        sortToken = token
        let header = hasHeader
        onStatus?(L("Đang sắp xếp…"))

        // Sắp xếp một triệu hàng theo cột chữ mất khoảng ba giây (đo ở
        // `scripts/run-csv-table-kpi.sh`), nên nó KHÔNG được chạy trên luồng chính.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let order = try? CSVSort.order(
                column: logical, direction: direction, hasHeader: header,
                index: index, in: buffer, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled, let order else { return }
                // Giữ HÀNG đang chọn qua lần sắp xếp. `reloadData` xoá lựa chọn, và mất nó thì
                // người dùng đang xem một bản ghi cụ thể sẽ mất dấu nó ngay khi sắp xếp —
                // cũng là lúc con nháy không còn chỗ để quay về ở chế độ văn bản.
                let previous = self.selectedFileRow
                self.sortOrder = order
                self.cachedRow = nil
                self.sortsCompleted += 1
                self.updateSortLabel()
                self.table.reloadData()
                if let previous { self.select(fileRow: previous) }
                self.onStatus?(LF("Sắp xếp theo %@ %@ · chỉ hiển thị",
                                       self.columnName(order.column), order.direction.arrow))
            }
        }
    }

    private func clearSort() {
        sortToken?.cancel()
        sortOrder = nil
        cachedRow = nil
        sortsCompleted += 1
        updateSortLabel()
        table.reloadData()
        onStatus?(L("Trở về thứ tự trong file"))
    }

    private func columnName(_ logical: Int) -> String {
        let names = headerNames()
        return logical < names.count && !names[logical].isEmpty
            ? names[logical] : LF("Cột %d", logical + 1)
    }

    private func logicalColumn(of column: NSTableColumn) -> Int? {
        guard column.identifier.rawValue.hasPrefix("c") else { return nil }
        return Int(column.identifier.rawValue.dropFirst())
    }

    private func updateSortLabel() {
        guard let sortOrder else {
            sortLabel.stringValue = ""
            applySortButton.isHidden = true
            return
        }
        // Chữ "chỉ hiển thị" luôn đi kèm, vì đó là toàn bộ khác biệt giữa hai việc: nhìn cho
        // dễ, và sửa file.
        sortLabel.stringValue =
            LF("Sắp xếp: %@ %@ (chỉ hiển thị)",
                   columnName(sortOrder.column), sortOrder.direction.arrow)
        applySortButton.isHidden = false
    }

    @objc private func applySortTapped() {
        guard let sortOrder else { return }
        onApplySort?(sortOrder)
    }

    @objc private func validateTapped() { onValidate?() }

    @objc private func convertTapped() { onConvert?() }

    @objc private func modeChanged() {
        guard modeControl.selectedSegment == 1 else { return }
        onSwitchToText?()
    }

    // MARK: - Điều hướng

    /// Chọn và cuộn tới một hàng FILE.
    func select(fileRow: Int) {
        let display = displayRow(forFileRow: fileRow)
        guard display >= 0, display < numberOfRows() else { return }
        table.selectRowIndexes(IndexSet(integer: display), byExtendingSelection: false)
        table.scrollRowToVisible(display)
    }

    /// Hàng đang chọn, các ô cách nhau bằng TAB — dạng để ⌘C đưa lên clipboard.
    ///
    /// **TAB chứ không phải dấu phân tách của tệp.** Thứ người ta dán vào sau một cú ⌘C trên
    /// bảng gần như luôn là một bảng khác — Excel, Numbers, một ô trong tài liệu — và những chỗ
    /// ấy đọc TAB. Dán ra một dòng `a;b;c` thì nó vào gọn một ô duy nhất.
    ///
    /// Ô có chứa TAB hoặc xuống dòng thì được bọc theo đúng luật RFC 4180, dùng lại
    /// `CSVEngine.escape` chứ không viết phép bọc thứ hai: một ô chứa TAB mà để trần sẽ tách
    /// thành hai ô ở chỗ dán, tức ⌘C làm hỏng dữ liệu một cách im lặng.
    var selectedRowForCopy: String? {
        let row = table.selectedRow
        guard row >= 0 else { return nil }
        let values = self.values(ofDisplayRow: row)
        guard !values.isEmpty else { return nil }
        return values.map { CSVEngine.escape($0, dialect: .tab) }.joined(separator: "\t")
    }

    /// Hàng FILE đang được chọn — để trả con nháy về đúng chỗ khi quay lại chế độ văn bản.
    var selectedFileRow: Int? {
        let row = table.selectedRow
        guard row >= 0 else { return nil }
        return fileRow(forDisplayRow: row)
    }

    // MARK: - Lọc theo cột (FR-QRY-002)

    /// Đặt lại vị trí các ô lọc theo bố cục cột hiện hành.
    private func syncFilterBar() {
        var entries: [(column: Int, x: CGFloat, width: CGFloat)] = []
        for (visible, item) in table.tableColumns.enumerated() {
            guard let logical = logicalColumn(of: item) else { continue }
            let rect = table.rect(ofColumn: visible)
            entries.append((logical, rect.minX, rect.width))
        }
        filterBar.setColumns(entries, font: Tokens.Font.monoInline(size: 11))
        filterBar.horizontalOffset = scrollView.contentView.bounds.origin.x
    }

    @objc private func tableDidScroll(_ notification: Notification) {
        filterBar.horizontalOffset = scrollView.contentView.bounds.origin.x
    }

    /// Người dùng vừa gõ vào một ô lọc.
    ///
    /// Chạy hai nhịp: lô đầu ĐỦ MỘT MÀN HÌNH để bảng có gì hiện ngay (đo được vài mili giây
    /// kể cả trên bảng một triệu hàng), rồi lượt quét đầy đủ ở luồng nền để biết tổng số dòng
    /// khớp. Quét cả file ngay trong lúc gõ thì mỗi phím là một hai giây đứng hình.
    private func filterChanged() {
        filterToken?.cancel()
        guard let buffer, !filterBar.isEmpty else {
            filteredRows = nil
            filterTotal = 0
            rebuildDisplayRows()
            updateFilterLabel()
            table.reloadData()
            return
        }

        let conditions = filterBar.texts.compactMap { CSVFilter.parse($0.value, column: $0.key) }
        let dialect = self.dialect
        let hasHeader = self.hasHeader

        // Nhịp một: đủ một màn hình, chạy ngay tại đây.
        let first = CSVFilter.rows(
            matching: conditions, in: buffer, dialect: dialect, hasHeader: hasHeader,
            prefix: CSVFilter.firstScreen
        )
        filteredRows = first.rows
        filterTotal = first.total
        filterPartial = first.partial
        rebuildDisplayRows()
        updateFilterLabel()
        table.reloadData()

        guard first.partial else { return }

        // Nhịp hai: quét nốt ở nền.
        let token = CancelToken()
        filterToken = token
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let full = CSVFilter.rows(
                matching: conditions, in: buffer, dialect: dialect,
                hasHeader: hasHeader, cancelToken: token
            )
            DispatchQueue.main.async {
                guard let self, !token.isCancelled, !full.cancelled else { return }
                self.filteredRows = full.rows
                self.filterTotal = full.total
                self.filterPartial = false
                self.rebuildDisplayRows()
                self.updateFilterLabel()
                self.table.reloadData()
            }
        }
    }

    private func updateFilterLabel() {
        guard let filteredRows else {
            filterLabel.stringValue = ""
            exportFilteredButton.isHidden = true
            onFilterChanged?(nil)
            return
        }
        let text = filterPartial
            ? LF("%d+ dòng khớp — đang tìm tiếp…", filteredRows.count)
            : LF("%d / %d dòng khớp", filteredRows.count, filterTotal)
        filterLabel.stringValue = text
        // Chỉ mời xuất khi phép lọc đã xong: xuất một tập dở dang sẽ cho ra file thiếu dòng
        // mà trông vẫn hoàn chỉnh.
        exportFilteredButton.isHidden = filterPartial || filteredRows.isEmpty
        onFilterChanged?(text)
    }

    @objc private func exportFiltered() {
        guard let filteredRows, !filterPartial else { return }
        onExportFiltered?(filteredRows)
    }

    /// Tính lại danh sách hàng hiển thị sau khi lọc hoặc sắp xếp đổi.
    private func rebuildDisplayRows() {
        guard let filteredRows else {
            displayRows = nil
            return
        }
        guard let sortOrder else {
            displayRows = filteredRows
            return
        }
        // Sắp xếp áp lên đúng tập đã lọc, giữ thứ tự của phép sắp xếp.
        let keep = Set(filteredRows)
        displayRows = sortOrder.rows.filter { keep.contains($0) }
    }

    private func numberOfRows() -> Int {
        if let displayRows { return displayRows.count }
        if let sortOrder { return sortOrder.rows.count }
        guard let index else { return 0 }
        return Swift.max(0, index.rowCount - firstDataRow)
    }

    // MARK: - Móc tự kiểm

    var rowCountForSelfTest: Int { numberOfRows() }

    /// Phát một tin CỦA BẢNG đúng đường mà `headerClicked` và `clearSort` phát.
    ///
    /// Bài kiểm dùng nó để hỏi *tin ấy rơi vào đâu* — câu hỏi về DÂY NỐI, không phải về phép
    /// sắp xếp. Gọi qua `headerClicked` thì phải dựng một `NSTableColumn` thật và chờ một lượt
    /// sắp xếp ở luồng nền, tốn công cho một thứ không liên quan đến điều đang hỏi.
    func emitStatusForSelfTest(_ text: String) { onStatus?(text) }
    /// Chọn một hàng HIỂN THỊ như người dùng bấm vào nó.
    func selectDisplayRowForSelfTest(_ row: Int) {
        guard row >= 0, row < numberOfRows() else { return }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    var filterLabelForSelfTest: String { filterLabel.stringValue }
    var filteredRowsForSelfTest: [Int]? { filteredRows }
    var exportFilteredVisibleForSelfTest: Bool { !exportFilteredButton.isHidden }
    func setFilterForSelfTest(_ text: String, column: Int) {
        filterBar.setTextForSelfTest(text, column: column)
    }
    func clearFiltersForSelfTest() { filterBar.clear() }
    func exportFilteredForSelfTest() { exportFiltered() }
    var columnCountForSelfTest: Int { table.tableColumns.count - 1 }
    var columnTitlesForSelfTest: [String] { table.tableColumns.dropFirst().map(\.title) }
    var sortLabelForSelfTest: String { sortLabel.stringValue }
    var applyButtonVisibleForSelfTest: Bool { !applySortButton.isHidden }
    func valuesForSelfTest(displayRow: Int) -> [String] { values(ofDisplayRow: displayRow) }
    func fileRowForSelfTest(displayRow: Int) -> Int? { fileRow(forDisplayRow: displayRow) }
    func clickHeaderForSelfTest(_ logical: Int) {
        guard let column = table.tableColumns.first(where: {
            $0.identifier.rawValue == "c\(logical)"
        }) else { return }
        headerClicked(column)
    }
    /// Số lần sắp xếp đã hoàn tất — bài tự kiểm chờ trên con số này.
    ///
    /// Chờ bằng cách nhìn nhãn "Sắp xếp: …" thì sai: bấm lần thứ ba là BỎ sắp xếp, nhãn trở
    /// về rỗng, và phép chờ ấy sẽ đứng mãi.
    private var sortsCompleted = 0

    func waitForSortForSelfTest() {
        let target = sortsCompleted + 1
        let deadline = Date().addingTimeInterval(30)
        while sortsCompleted < target, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
    func commitEditForSelfTest(displayRow: Int, column: Int, value: String) {
        commitEdit(displayRow: displayRow, logicalColumn: column, value: value)
    }
    var selectedFileRowForSelfTest: Int? { selectedFileRow }
    func applySortForSelfTest() { applySortTapped() }

    func hideColumnForSelfTest(_ logical: Int) { hide(column: logical) }
    /// Đối xứng với `hideColumnForSelfTest`. Có để bài kiểm dựng được menu tiêu đề ở trạng
    /// thái "đang có cột ẩn" rồi TRẢ LẠI nguyên trạng — một bài kiểm để lại cột ẩn sẽ làm
    /// bài chạy sau nó đỏ vì lý do không liên quan gì tới thứ nó kiểm.
    func showColumnForSelfTest(_ logical: Int) { show(column: logical) }
    var hiddenNoteForSelfTest: String { hiddenNote.stringValue }
    /// Bảng có thật sự nhường chỗ cho dòng nhắc không — kiểm bằng HÌNH HỌC, không bằng cờ.
    ///
    /// `minY` chứ không phải `bounds.height - maxY`: view này KHÔNG lật, nên trục y đi lên và
    /// `maxY` là mép TRÊN. Công thức đầu tiên tôi viết đo khoảng trống phía trên bảng — luôn
    /// bằng chiều cao thanh công cụ, nên vế "phải có chỗ trống" xanh mà chẳng kiểm gì cả.
    var tableBottomGapForSelfTest: CGFloat {
        layoutSubtreeIfNeeded()
        return scrollView.frame.minY - bounds.minY
    }
    var reorderAllowedForSelfTest: Bool { table.allowsColumnReordering }
    func headerMenuTitlesForSelfTest(_ logical: Int?) -> [String] {
        headerMenu(forLogicalColumn: logical).items.map(\.title)
    }
    /// Giả lập cú kéo tiêu đề: chỉ số tính CẢ cột "#", đúng như thông báo của AppKit mang tới.
    func simulateColumnDragForSelfTest(fromVisible: Int, toVisible: Int) {
        columnDidMove(from: fromVisible, to: toVisible)
    }

    // MARK: - Sửa ô

    fileprivate func commitEdit(displayRow: Int, logicalColumn: Int, value: String) {
        guard let row = fileRow(forDisplayRow: displayRow) else { return }
        cachedRow = nil
        onEditCell?(row, logicalColumn, value)
    }
}

// MARK: - Nguồn dữ liệu

extension CSVTableView: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { numberOfRows() }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = tableColumn.identifier

        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.font = Tokens.Font.monoInline()
            field.lineBreakMode = .byTruncatingTail
            field.drawsBackground = false
            field.isBordered = false
            field.delegate = self
        }

        if logicalColumn(of: tableColumn) == nil {
            // Cột số thứ tự: số hàng TRONG FILE, đếm từ 1 — cùng cách đếm với "Dòng" ở thanh
            // trạng thái và với mọi lệnh cột. Khi đang sắp xếp hiển thị, con số này nhảy cóc,
            // và đó chính là điều cần cho người dùng thấy: hàng vẫn ở nguyên chỗ cũ trong file.
            field.isEditable = false
            field.alignment = .trailingEdge
            field.textColor = Tokens.Color.secondaryInk
            field.stringValue = fileRow(forDisplayRow: row).map { "\($0 + 1)" } ?? ""
            return field
        }

        let column = logicalColumn(of: tableColumn) ?? 0
        let values = self.values(ofDisplayRow: row)
        field.isEditable = true
        field.alignment = .leadingEdge
        field.stringValue = column < values.count ? values[column] : ""

        // Ô sai kiểu: chữ ĐỎ và viền đỏ mảnh. Phải đặt lại cả hai ở nhánh ngược lại, vì ô được
        // dùng lại khi cuộn — không xóa thì màu đỏ trôi sang những ô hoàn toàn đúng.
        let isBad = fileRow(forDisplayRow: row).map { typeIssues[$0]?.contains(column) == true } ?? false
        field.textColor = isBad ? Tokens.Color.error : Tokens.Color.editorInk
        field.wantsLayer = true
        field.layer?.borderWidth = isBad ? 1 : 0
        field.layer?.borderColor = isBad ? Tokens.Color.error.cgColor : nil
        field.layer?.cornerRadius = isBad ? Tokens.Metrics.cornerChip : 0
        return field
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        headerClicked(tableColumn)
    }

    /// Cột "#" không kéo đi đâu được, và không cột nào được kéo lên trước nó.
    ///
    /// Nó là mốc để đọc bảng — số hàng trong file. Cho nó trôi đi giữa dữ liệu là bỏ mất mốc
    /// ấy, và tệ hơn: chỉ số hiển thị không còn dịch được sang chỉ số cột logic.
    func tableView(
        _ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newIndex: Int
    ) -> Bool {
        columnIndex >= 1 && newIndex >= 1
    }

    @objc fileprivate func tableColumnDidMove(_ notification: Notification) {
        guard let old = notification.userInfo?["NSOldColumn"] as? Int,
              let new = notification.userInfo?["NSNewColumn"] as? Int else { return }
        columnDidMove(from: old, to: new)
    }

    /// Chọn cả hàng thì nền phải khác hẳn — nhưng không được che mất chữ.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
}

extension CSVTableView: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let row = table.row(for: field)
        let columnIndex = table.column(for: field)
        guard row >= 0, columnIndex >= 0 else { return }
        guard let logical = logicalColumn(of: table.tableColumns[columnIndex]) else { return }

        let current = values(ofDisplayRow: row)
        let old = logical < current.count ? current[logical] : ""
        // Không sửa gì thì KHÔNG sinh bước undo. Bấm vào ô rồi bấm ra ngoài là chuyện xảy ra
        // liên tục; mỗi lần như thế đẻ một bước undo thì lịch sử hoàn tác thành vô dụng.
        guard field.stringValue != old else { return }
        commitEdit(displayRow: row, logicalColumn: logical, value: field.stringValue)
    }
}

// MARK: - Hàng tiêu đề nhận chuột phải

/// Hàng tiêu đề trả về menu ngữ cảnh của ĐÚNG cột bị bấm.
///
/// `NSTableHeaderView` mặc định dùng chung một menu cho cả hàng, nên nếu chỉ gán `menu` thì
/// mọi cột hiện cùng một menu và lệnh "Xóa cột này" sẽ xóa nhầm cột.
private final class CSVTableHeaderView: NSTableHeaderView {

    var menuForColumn: ((Int) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return menuForColumn?(column(at: point))
    }
}

// MARK: - Bảng có bàn phím

/// `NSTableView` với phím Enter mở sửa ô, đúng như đặc tả UI/UX §6.1.
private final class CSVTableViewList: NSTableView {

    var onStartEditing: ((_ row: Int, _ column: Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        // 36 = Return, 76 = Enter ở bàn phím số.
        guard event.keyCode == 36 || event.keyCode == 76 else { return super.keyDown(with: event) }
        let row = selectedRow
        guard row >= 0, numberOfColumns > 1 else { return super.keyDown(with: event) }
        // Cột 0 là số thứ tự, không sửa được — Enter mở ô dữ liệu đầu tiên. Từ đó Tab sang ô
        // kế, đúng như đặc tả UI/UX §6.1.
        onStartEditing?(row, 1)
    }
}
