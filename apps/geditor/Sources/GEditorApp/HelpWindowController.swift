import AppKit
import GEditorCore

/// Cửa sổ Trợ giúp — mục lục bên trái, nội dung bên phải, ô tìm ở trên (NFR-USE-04).
///
/// ## Vì sao là một cửa sổ riêng, không phải một tab Markdown như trước
///
/// Bản trước mở trang trợ giúp thành một tab văn bản chưa lưu. Cách ấy rẻ và có hai cái lợi thật
/// — tìm bằng `⌘F` và chép ra được. Nhưng nó hỏng ở ba chỗ khi nội dung lớn lên:
///
/// 1. **Trợ giúp chiếm mất chỗ làm việc.** Người ta mở trợ giúp để làm tiếp việc đang dở, mà tab
///    trợ giúp lại đẩy chính tài liệu ấy đi chỗ khác. Một cửa sổ riêng đặt cạnh được.
/// 2. **Không có mục lục.** Với hai trang thì cuộn là đủ; với gần trăm trang thì không.
/// 3. **Bảng hiện ra thành dấu gạch đứng.** Tab văn bản hiện Markdown NGUỒN, và phần lớn giá trị
///    của trang trợ giúp một trình soạn thảo nằm ở bảng phím tắt.
///
/// **Chỉ có MỘT cửa sổ trợ giúp.** Mở lại là đưa cửa sổ đang có ra trước và nhảy tới trang được
/// hỏi. Nhiều cửa sổ trợ giúp chồng lên nhau chỉ tạo ra câu hỏi "cái nào là cái tôi vừa mở".
final class HelpWindowController: NSWindowController, NSOutlineViewDataSource,
                                  NSOutlineViewDelegate, NSSearchFieldDelegate {

    static private(set) var shared: HelpWindowController?

    /// Mở cửa sổ trợ giúp ở một trang.
    ///
    /// `welcome` bật phần chân trang chào mừng — ô tích "không hiện lại" và nút đóng. Chỉ lần
    /// mở lúc khởi động mới bật nó: gắn ô tích ấy vào MỌI lần mở trợ giúp là mời người dùng tắt
    /// nhầm một thứ họ đang cần.
    @discardableResult
    static func show(
        topicID: String = HelpContent.entryTopicID,
        welcome: Bool = false,
        settings: HelpWelcomeSettings? = nil
    ) -> HelpWindowController {
        let controller: HelpWindowController
        if let existing = shared {
            controller = existing
        } else {
            controller = HelpWindowController()
            shared = controller
        }
        controller.welcomeSettings = settings
        controller.setWelcomeFooter(visible: welcome)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.go(to: topicID)
        return controller
    }

    // MARK: - Trạng thái

    /// Sách đang hiện. KHÔNG `let` nữa: người đọc đổi được ngôn ngữ ngay trong cửa sổ này.
    ///
    /// Ngôn ngữ ĐỌC tách khỏi ngôn ngữ GIAO DIỆN có lý do thật: một người dùng giao diện tiếng
    /// Việt vẫn có thể muốn đọc bản tiếng Anh để đối chiếu thuật ngữ với tài liệu gốc, và
    /// ngược lại — bắt họ đổi cả ứng dụng rồi khởi động lại chỉ để đọc một trang là cái giá
    /// không ai trả.
    private var book: HelpBook
    private var welcomeSettings: HelpWelcomeSettings?

    /// Kết quả tìm đang hiện. Rỗng = mục lục bình thường.
    private var results: [HelpBook.SearchHit] = []
    private var isSearching = false

    /// Lịch sử điều hướng cho nút Lùi. Không có nút Tiến: đo trên chính lối dùng thì "tiến" gần
    /// như không ai bấm, còn mỗi nút thêm vào thanh trên là một thứ nữa phải nhìn qua.
    private var history: [String] = []
    private var currentTopicID: String?

    // MARK: - View

    private let searchField = NSSearchField()
    private let outline = NSOutlineView()
    private let contentStack = NSStackView()
    private let contentScroll = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let breadcrumbLabel = NSTextField(labelWithString: "")
    private let backButton = NSButton()
    private let footer = NSView()
    private let dontShowAgainBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let translationNotice = NSTextField(labelWithString: "")
    /// Chọn ngôn ngữ ĐỌC sách — không đụng tới ngôn ngữ giao diện.
    private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Mã ngôn ngữ của từng mục trong popup, cùng thứ tự.
    private var languageCodes: [String] = []

    private var nodes: [HelpNode] = []

    init() {
        let language = L10n.effective.rawValue
        self.book = HelpContent.book(language: language)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L("Trợ giúp GEditor")
        window.setFrameAutosaveName("GEditorHelpWindow")
        window.minSize = NSSize(width: 820, height: 480)
        super.init(window: window)

        nodes = book.chapters.map(HelpNode.init)
        build()
        showTranslationNoticeIfNeeded(language: language)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Dựng

    private func build() {
        guard let contentView = window?.contentView else { return }

        // --- Bên trái: ô tìm + mục lục ---
        searchField.placeholderString = L("Tìm trong trợ giúp")
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false

        outline.headerView = nil
        outline.rowSizeStyle = .default
        outline.indentationPerLevel = 14
        outline.floatsGroupRows = false
        outline.dataSource = self
        outline.delegate = self
        outline.selectionHighlightStyle = .regular
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("topic"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        let outlineScroll = NSScrollView()
        outlineScroll.documentView = outline
        outlineScroll.hasVerticalScroller = true
        outlineScroll.drawsBackground = false
        outlineScroll.translatesAutoresizingMaskIntoConstraints = false

        let sidebar = NSView()
        sidebar.applyLayerBackground(Tokens.Color.chrome)
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(searchField)
        sidebar.addSubview(outlineScroll)

        // --- Bên phải: tiêu đề + nội dung ---
        backButton.title = "‹ " + L("Lùi")
        backButton.bezelStyle = .rounded
        backButton.controlSize = .small
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.isEnabled = false
        backButton.translatesAutoresizingMaskIntoConstraints = false

        buildLanguagePopUp()

        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = Tokens.Color.ember
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        breadcrumbLabel.font = Tokens.Font.caption
        breadcrumbLabel.textColor = Tokens.Color.secondaryInk
        breadcrumbLabel.translatesAutoresizingMaskIntoConstraints = false

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.edgeInsets = NSEdgeInsets(top: 20, left: 28, bottom: 40, right: 28)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let document = HelpFlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: document.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])

        contentScroll.documentView = document
        contentScroll.hasVerticalScroller = true
        contentScroll.drawsBackground = true
        contentScroll.backgroundColor = .textBackgroundColor
        contentScroll.translatesAutoresizingMaskIntoConstraints = false

        buildFooter()

        let right = NSView()
        // Nền TƯỜNG MINH, không để mặc định của cửa sổ lo.
        //
        // Bản đầu để trống, và ảnh chụp lộ ra ngay: dải mang thanh Lùi + đường dẫn + tiêu đề ra
        // một màu khác hẳn phần nội dung ngay dưới nó, còn nút Lùi thì chìm hẳn. Một khung có
        // nền và một khung không có nền đặt liền nhau thì luôn có một đường ranh ở giữa, và
        // người nhìn đọc nó thành một lỗi giao diện.
        right.applyLayerBackground(.textBackgroundColor)
        right.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(backButton)
        right.addSubview(languagePopUp)
        right.addSubview(breadcrumbLabel)
        right.addSubview(titleLabel)
        right.addSubview(contentScroll)
        right.addSubview(footer)

        contentView.addSubview(sidebar)
        contentView.addSubview(right)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 260),

            searchField.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 14),

            outlineScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            outlineScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            outlineScroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            outlineScroll.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),

            right.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            right.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            right.topAnchor.constraint(equalTo: contentView.topAnchor),
            right.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: right.leadingAnchor, constant: 28),
            backButton.topAnchor.constraint(equalTo: right.topAnchor, constant: 16),

            breadcrumbLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            breadcrumbLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            // Popup ngôn ngữ neo mép PHẢI: nó là thứ dùng một lần rồi quên, không nên chen vào
            // đường mắt đi từ nút Lùi tới nhan đề trang.
            languagePopUp.trailingAnchor.constraint(equalTo: right.trailingAnchor, constant: -28),
            languagePopUp.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            breadcrumbLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: languagePopUp.leadingAnchor, constant: -12),

            titleLabel.leadingAnchor.constraint(equalTo: right.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: right.trailingAnchor, constant: -28),
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),

            contentScroll.leadingAnchor.constraint(equalTo: right.leadingAnchor),
            contentScroll.trailingAnchor.constraint(equalTo: right.trailingAnchor),
            contentScroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentScroll.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: right.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: right.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: right.bottomAnchor),
        ])

        outline.expandItem(nil, expandChildren: true)
    }

    private func buildFooter() {
        footer.applyLayerBackground(Tokens.Color.chrome)
        footer.translatesAutoresizingMaskIntoConstraints = false

        dontShowAgainBox.title = L("Không mở cửa sổ này khi khởi động nữa")
        dontShowAgainBox.target = self
        dontShowAgainBox.action = #selector(toggleWelcomeOnLaunch)
        dontShowAgainBox.translatesAutoresizingMaskIntoConstraints = false

        let start = NSButton(title: L("Bắt đầu dùng"), target: self, action: #selector(closeWindow))
        start.bezelStyle = .rounded
        start.keyEquivalent = "\r"
        start.translatesAutoresizingMaskIntoConstraints = false

        let line = NSView()
        line.applyLayerBackground(Tokens.Color.separator)
        line.translatesAutoresizingMaskIntoConstraints = false

        footer.addSubview(line)
        footer.addSubview(dontShowAgainBox)
        footer.addSubview(start)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            line.topAnchor.constraint(equalTo: footer.topAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),

            dontShowAgainBox.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 28),
            dontShowAgainBox.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            start.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -28),
            start.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
        footerHeight = footer.heightAnchor.constraint(equalToConstant: 0)
        footerHeight?.isActive = true
    }

    private var footerHeight: NSLayoutConstraint?

    /// Chân trang chào mừng.
    ///
    /// Ẩn bằng cách cho chiều cao về 0 chứ không gỡ view: gỡ rồi dựng lại làm cả cột nội dung
    /// nhảy một nhịp mỗi lần mở trợ giúp từ menu.
    private func setWelcomeFooter(visible: Bool) {
        footerHeight?.constant = visible ? 52 : 0
        footer.isHidden = !visible
        if visible, let settings = welcomeSettings {
            dontShowAgainBox.state = settings.showWelcomeOnLaunch() ? .off : .on
        }
    }

    // MARK: - Ngôn ngữ của sách

    /// Dựng popup chọn ngôn ngữ ĐỌC.
    ///
    /// Chỉ liệt kê những ngôn ngữ **thật sự có sách** (`HelpContent.translatedLanguages`). Một
    /// mục chọn vào rồi vẫn thấy tiếng Việt là một mục nói dối — và người dùng sẽ đổ cho sản
    /// phẩm hỏng chứ không đoán ra là bản dịch chưa có.
    private func buildLanguagePopUp() {
        languageCodes = HelpContent.translatedLanguages.sorted()
        languagePopUp.removeAllItems()
        languagePopUp.addItems(withTitles: languageCodes.map(HelpContent.languageName))
        if let index = languageCodes.firstIndex(of: book.language) {
            languagePopUp.selectItem(at: index)
        }
        languagePopUp.controlSize = .small
        languagePopUp.font = Tokens.Font.caption
        languagePopUp.target = self
        languagePopUp.action = #selector(languagePicked)
        languagePopUp.translatesAutoresizingMaskIntoConstraints = false
        languagePopUp.setAccessibilityLabel(L("Ngôn ngữ của sách trợ giúp"))
        // Một ngôn ngữ thì không có gì để chọn giữa — giấu đi thay vì mời người dùng bấm vào
        // rồi thấy đúng thứ họ đang đọc.
        languagePopUp.isHidden = languageCodes.count < 2
    }

    @objc private func languagePicked() {
        let index = languagePopUp.indexOfSelectedItem
        guard languageCodes.indices.contains(index) else { return }
        showBook(language: languageCodes[index])
    }

    /// Đổi sang sách của một ngôn ngữ khác, GIỮ NGUYÊN trang đang đọc.
    ///
    /// Giữ nguyên trang là phần quan trọng: mã trang (`id`) cố ý không dịch, đúng để lúc này
    /// đổi được ngôn ngữ mà người đọc không bị ném về mục lục. Trang nào bản kia chưa có thì
    /// về trang đầu — nói ra bằng chính việc nhan đề đổi, chứ không mở một trang trắng.
    func showBook(language: String) {
        guard language != book.language else { return }
        let topicID = currentTopicID
        book = HelpContent.book(language: language)
        nodes = book.chapters.map(HelpNode.init)
        history = []
        currentTopicID = nil
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true)
        showTranslationNoticeIfNeeded(language: language)
        go(to: topicID.flatMap { book.topic(id: $0) }?.id ?? HelpContent.entryTopicID)
        if let index = languageCodes.firstIndex(of: language) {
            languagePopUp.selectItem(at: index)
        }
    }

    var helpLanguageForSelfTest: String { book.language }
    func pickHelpLanguageForSelfTest(_ language: String) { showBook(language: language) }
    var helpLanguageChoicesForSelfTest: [String] { languageCodes }

    private func showTranslationNoticeIfNeeded(language: String) {
        guard !HelpContent.isTranslated(language) else { return }
        translationNotice.stringValue = L(
            "Bản dịch trợ giúp cho ngôn ngữ này chưa có — đang hiện bản tiếng Việt."
        )
        translationNotice.font = Tokens.Font.caption
        translationNotice.textColor = Tokens.Color.secondaryInk
    }

    // MARK: - Điều hướng

    /// Mở một trang. Ghi trang đang đứng vào lịch sử để nút Lùi có chỗ quay về.
    func go(to topicID: String) {
        guard let topic = book.topic(id: topicID) else { return }
        if let current = currentTopicID, current != topicID {
            history.append(current)
        }
        currentTopicID = topicID
        backButton.isEnabled = !history.isEmpty
        render(topic)
        selectInOutline(topicID)
    }

    @objc private func goBack() {
        guard let previous = history.popLast() else { return }
        currentTopicID = previous
        backButton.isEnabled = !history.isEmpty
        if let topic = book.topic(id: previous) {
            render(topic)
            selectInOutline(previous)
        }
    }

    @objc private func closeWindow() { window?.close() }

    @objc private func toggleWelcomeOnLaunch(_ sender: NSButton) {
        welcomeSettings?.setShowWelcomeOnLaunch(sender.state == .off)
    }

    private func render(_ topic: HelpTopic) {
        // Tiêu đề đi qua ĐÚNG bộ ký hiệu nội tuyến của thân bài. Không có bước này thì trang
        // "Cú pháp `.gquality.yaml`" hiện ra kèm hai dấu nháy ngược nguyên xi — ảnh chụp đầu
        // tiên lộ ra đúng chỗ ấy.
        titleLabel.attributedStringValue = HelpBlockViews.attributed(
            topic.title, font: NSFont.systemFont(ofSize: 22, weight: .bold),
            color: Tokens.Color.ember
        )
        breadcrumbLabel.stringValue = book.chapter(containing: topic.id)?.title ?? ""

        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if !translationNotice.stringValue.isEmpty {
            contentStack.addArrangedSubview(translationNotice)
        }

        let summary = NSTextField(labelWithString: topic.summary)
        summary.font = NSFont.systemFont(ofSize: 14)
        summary.textColor = Tokens.Color.secondaryInk
        summary.lineBreakMode = .byWordWrapping
        summary.maximumNumberOfLines = 0
        summary.preferredMaxLayoutWidth = HelpBlockViews.contentWidth
        summary.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(summary)

        for view in HelpBlockViews.views(
            for: topic.blocks, book: book, onNavigate: { [weak self] in self?.go(to: $0) }
        ) {
            contentStack.addArrangedSubview(view)
        }

        // Về đầu trang. Không giữ vị trí cuộn của trang trước: cuộn xuống giữa một trang mới mở
        // là cách chắc chắn làm người đọc tưởng mình bấm nhầm.
        contentScroll.documentView?.scroll(.zero)
        contentScroll.reflectScrolledClipView(contentScroll.contentView)
    }

    private func selectInOutline(_ topicID: String) {
        guard !isSearching else { return }
        for node in nodes {
            guard let index = node.children.firstIndex(where: { $0.topic?.id == topicID })
            else { continue }
            outline.expandItem(node)
            let row = outline.row(forItem: node.children[index])
            guard row >= 0 else { return }
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outline.scrollRowToVisible(row)
            return
        }
    }

    // MARK: - Ô tìm

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        isSearching = !query.isEmpty
        results = isSearching ? book.search(query) : []
        outline.reloadData()
        if !isSearching {
            outline.expandItem(nil, expandChildren: true)
            if let current = currentTopicID { selectInOutline(current) }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if isSearching { return item == nil ? results.count : 0 }
        guard let item else { return nodes.count }
        return (item as? HelpNode)?.children.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if isSearching { return HelpNode(hit: results[index]) }
        guard let node = item as? HelpNode else { return nodes[index] }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard !isSearching else { return false }
        return ((item as? HelpNode)?.children.count ?? 0) > 0
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any)
        -> NSView? {
        guard let node = item as? HelpNode else { return nil }
        let field = NSTextField(labelWithString: node.title)
        field.lineBreakMode = .byTruncatingTail
        if node.topic == nil {
            field.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            field.textColor = Tokens.Color.secondaryInk
        } else {
            field.font = Tokens.Font.ui
        }
        let cell = NSTableCellView()
        cell.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? HelpNode)?.topic != nil
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outline.selectedRow
        guard row >= 0, let node = outline.item(atRow: row) as? HelpNode,
              let topic = node.topic, topic.id != currentTopicID
        else { return }
        go(to: topic.id)
    }
}

/// Một dòng trong mục lục: chương (không chọn được) hoặc trang.
///
/// `NSOutlineView` đòi item là `AnyObject` và **so sánh bằng danh tính**, nên phải là class và
/// phải giữ lại đúng các thể hiện đã đưa ra — dựng mới ở mỗi lần hỏi thì cây tự sập lại sau mỗi
/// lần nạp lại.
final class HelpNode {
    let title: String
    let topic: HelpTopic?
    private(set) var children: [HelpNode] = []

    init(_ chapter: HelpChapter) {
        title = chapter.title.uppercased()
        topic = nil
        children = chapter.topics.map { HelpNode($0) }
    }

    /// Mục lục hiện chữ THUẦN: một dòng `Cú pháp `.gquality.yaml`` in nguyên dấu nháy ngược
    /// trong danh sách trông như lỗi gõ, còn ở thân bài thì đúng chỗ ấy lại là phông mã.
    init(_ topic: HelpTopic) {
        title = HelpInline.plainText(topic.title)
        self.topic = topic
    }

    init(hit: HelpBook.SearchHit) {
        title = HelpInline.plainText(hit.topic.title)
        topic = hit.topic
    }
}

/// Toạ độ gốc ở góc TRÊN bên trái. Không có nó thì nội dung dựng ngược từ dưới lên và trang dài
/// bắt đầu ở đáy cửa sổ.
final class HelpFlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Hai việc cửa sổ trợ giúp cần ở cấu hình, tách thành giao thức để bài kiểm không phải dựng cả
/// một `MainWindowController`.
protocol HelpWelcomeSettings: AnyObject {
    func showWelcomeOnLaunch() -> Bool
    func setShowWelcomeOnLaunch(_ value: Bool)
}

// MARK: - Cửa cho bộ tự kiểm

/// Chỉ ĐỌC trạng thái và bấm đúng những nút người dùng bấm được.
///
/// Không mở thêm đường nào để bài kiểm đi tắt: bài "ô tích ghi xuống cấu hình" phải đi qua chính
/// `action` của nút, vì chỗ hỏng thật nằm ở dây nối giữa nút và cấu hình — gọi thẳng hàm ghi thì
/// bài kiểm xanh kể cả khi dây ấy đứt.
extension HelpWindowController {

    var currentTopicIDForSelfTest: String? { currentTopicID }
    /// Nhan đề đang hiện — bài kiểm đọc nó để chắc sách đã đổi THẬT, không chỉ đổi cái nhãn.
    var currentTitleForSelfTest: String { titleLabel.stringValue }

    var canGoBackForSelfTest: Bool { backButton.isEnabled }

    var welcomeFooterVisibleForSelfTest: Bool { !footer.isHidden }

    var dontShowAgainCheckedForSelfTest: Bool { dontShowAgainBox.state == .on }

    /// Bấm ô tích đúng như người dùng bấm: đổi trạng thái rồi gửi `action` đi.
    func clickDontShowAgainForSelfTest() {
        dontShowAgainBox.state = dontShowAgainBox.state == .on ? .off : .on
        if let action = dontShowAgainBox.action {
            NSApp.sendAction(action, to: dontShowAgainBox.target, from: dontShowAgainBox)
        }
    }

    /// Số view đang dựng trong khung nội dung — để bài kiểm thấy trang thật sự có gì.
    var contentViewCountForSelfTest: Int { contentStack.arrangedSubviews.count }
}
