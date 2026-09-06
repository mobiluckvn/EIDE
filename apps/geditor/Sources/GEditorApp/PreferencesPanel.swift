import AppKit
import GEditorCore

/// Cửa sổ Cài đặt (FR-UI-803).
///
/// **Mọi thứ ở đây đều ghi thẳng vào `settings.json`**, file văn bản đọc được bằng mắt ở
/// `~/Library/Application Support/GEditor/` (NFR-PORT-03). Cửa sổ này chỉ là một cách sửa file
/// ấy cho tiện — nút "Mở file cấu hình" nói ra điều đó thay vì giấu đi.
///
/// **Không có nút OK/Huỷ.** Đổi là ăn ngay và ghi ngay, đúng lối cài đặt của macOS từ lâu. Nút
/// Huỷ đòi giữ một bản sao trạng thái cũ và hoàn tác từng thứ một — nhiều mã hơn cho một hành
/// vi mà người dùng Mac không còn trông đợi.
final class PreferencesPanel: NSWindowController {

    private var settings: Settings
    private let onChange: (Settings) -> Void

    private let fontSizeField = NSTextField()
    private let tabWidthField = NSTextField()
    private let usesTabsBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let trimOnSaveBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let normalizeBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smartIndentBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let highlightAllBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ligatureBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let openInViewBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let languagePopUp = NSPopUpButton()
    private let appearancePopUp = NSPopUpButton()
    private let themePopUp = NSPopUpButton()
    private let themeNames: [String]
    private let noteLabel = NSTextField(labelWithString: "")

    init(settings: Settings, themeNames: [String] = [Theme.cam.name], onChange: @escaping (Settings) -> Void) {
        self.settings = settings
        self.themeNames = themeNames.isEmpty ? [Theme.cam.name] : themeNames
        self.onChange = onChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = L("Cài đặt…").replacingOccurrences(of: "…", with: "")
        super.init(window: window)
        build()
        load()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 10
        form.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        form.addArrangedSubview(heading(L("Soạn thảo")))
        for field in [fontSizeField, tabWidthField] {
            field.controlSize = .small
            field.target = self
            field.action = #selector(valueChanged)
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        }
        form.addArrangedSubview(row(L("Cỡ chữ"), fontSizeField))
        form.addArrangedSubview(row(L("Bề rộng TAB"), tabWidthField))
        for (box, title) in [
            (usesTabsBox, L("Thụt lề bằng TAB")),
            (smartIndentBox, L("Tự động thụt lề khi xuống dòng")),
            (highlightAllBox, L("Tô mọi kết quả tìm kiếm")),
            (trimOnSaveBox, L("Cắt khoảng trắng cuối dòng khi lưu")),
            (normalizeBox, L("Chuẩn hóa về NFC khi lưu")),
            // NFR-USE-05. Nhãn nói ra CÁI GIÁ chứ không chỉ tên tính năng: người bật nó cần
            // biết vì sao một trình soạn thảo mã lại để mặc định tắt.
            (ligatureBox, L("Chữ ghép (ligature) — tắt thì mỗi ký tự một ô")),
            (openInViewBox, L("Mở tệp là vào thẳng chế độ View nếu tệp ấy có")),
        ] {
            box.title = title
            box.target = self
            box.action = #selector(valueChanged)
            form.addArrangedSubview(box)
        }

        form.addArrangedSubview(heading(L("Giao diện")))
        buildLanguageMenu()
        languagePopUp.target = self
        languagePopUp.action = #selector(valueChanged)
        form.addArrangedSubview(row(L("Ngôn ngữ"), languagePopUp))

        for title in [L("Theo hệ thống"), L("Sáng"), L("Tối")] {
            appearancePopUp.addItem(withTitle: title)
        }
        appearancePopUp.target = self
        appearancePopUp.action = #selector(valueChanged)
        form.addArrangedSubview(row(L("Nền"), appearancePopUp))

        for name in themeNames { themePopUp.addItem(withTitle: name) }
        themePopUp.target = self
        themePopUp.action = #selector(valueChanged)
        form.addArrangedSubview(row(L("Theme"), themePopUp))

        form.addArrangedSubview(heading(L("Phím tắt")))
        let preset = NSButton(
            title: L("Dùng preset Notepad++"), target: self, action: #selector(applyNotepadPreset)
        )
        let clearKeys = NSButton(
            title: L("Về phím mặc định"), target: self, action: #selector(clearKeyBindings)
        )
        for button in [preset, clearKeys] { button.controlSize = .small }
        form.addArrangedSubview(NSStackView(views: [preset, clearKeys]))

        let reveal = NSButton(
            title: L("Mở file cấu hình"), target: self, action: #selector(revealSettingsFile)
        )
        let exportTheme = NSButton(
            title: L("Xuất theme hiện tại"), target: self, action: #selector(exportTheme)
        )
        for button in [reveal, exportTheme] { button.controlSize = .small }
        form.addArrangedSubview(NSStackView(views: [reveal, exportTheme]))

        noteLabel.font = Tokens.Font.caption
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.stringValue = L("Đổi ngôn ngữ áp dụng đầy đủ ở lần mở app kế tiếp.")
        form.addArrangedSubview(noteLabel)

        window?.contentView = form
    }

    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        return label
    }

    private func row(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = Tokens.Font.ui
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.spacing = 8
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true
        return stack
    }

    private func load() {
        fontSizeField.stringValue = String(Int(settings.fontSize))
        tabWidthField.stringValue = String(settings.tabWidth)
        usesTabsBox.state = settings.usesTabsForIndent ? .on : .off
        smartIndentBox.state = settings.smartIndent ? .on : .off
        highlightAllBox.state = settings.highlightAllMatches ? .on : .off
        ligatureBox.state = settings.ligatures ? .on : .off
        openInViewBox.state = settings.openInViewMode ? .on : .off
        trimOnSaveBox.state = settings.trimTrailingWhitespaceOnSave ? .on : .off
        normalizeBox.state = settings.normalizeToNFCOnSave ? .on : .off
        selectLanguage(named: settings.language)
        appearancePopUp.selectItem(at: ["system", "light", "dark"].firstIndex(of: settings.appearance) ?? 0)
        themePopUp.selectItem(at: themeNames.firstIndex(of: settings.themeName) ?? 0)
    }

    @objc private func valueChanged() {
        // Kẹp trong khoảng dùng được thay vì nhận bừa: người dùng gõ 0 vào ô bề rộng TAB thì
        // mọi phép tính cột chia cho 0, và gõ 500 vào cỡ chữ thì một dòng không lọt màn hình.
        settings.fontSize = Double(min(max(Int(fontSizeField.stringValue) ?? 13, 8), 32))
        settings.tabWidth = min(max(Int(tabWidthField.stringValue) ?? 4, 1), 16)
        settings.usesTabsForIndent = usesTabsBox.state == .on
        settings.smartIndent = smartIndentBox.state == .on
        settings.highlightAllMatches = highlightAllBox.state == .on
        settings.ligatures = ligatureBox.state == .on
        settings.openInViewMode = openInViewBox.state == .on
        settings.trimTrailingWhitespaceOnSave = trimOnSaveBox.state == .on
        settings.normalizeToNFCOnSave = normalizeBox.state == .on
        settings.language = selectedLanguage().rawValue
        settings.appearance = ["system", "light", "dark"][appearancePopUp.indexOfSelectedItem]
        settings.themeName = themeNames[min(max(themePopUp.indexOfSelectedItem, 0), themeNames.count - 1)]
        load()                          // hiện lại giá trị ĐÃ KẸP, để người dùng thấy điều đã xảy ra
        onChange(settings)
    }

    @objc private func applyNotepadPreset() {
        settings.keyBindings = KeyBindings.notepadPlusPlusPreset
        onChange(settings)
    }

    @objc private func clearKeyBindings() {
        settings.keyBindings = [:]
        onChange(settings)
        // `KeyBindings.apply` chỉ ĐÈ phím lên menu, nó không biết gỡ ra: phím mặc định nằm
        // trong `buildMenuBar` và chỉ được đặt lúc dựng menu. Nói thẳng ra điều đó thay vì để
        // người dùng bấm xong rồi tự hỏi vì sao phím cũ vẫn còn.
        noteLabel.stringValue = L("Phím mặc định trở lại ở lần mở app kế tiếp.")
    }

    /// Ghi theme hiện tại ra `themes/`. Chỗ gọi làm, vì `AppPaths` thuộc về nó.
    var onExportTheme: (() -> Void)?

    @objc private func exportTheme() { onExportTheme?() }

    @objc private func revealSettingsFile() {
        // Ghi trước rồi mới hiện trong Finder: file chưa từng được ghi thì Finder mở ra một
        // thư mục không có nó, và người dùng kết luận là app không lưu cấu hình.
        try? settings.save(to: AppPaths.settingsFile)
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.settingsFile])
    }

    // MARK: - Móc tự kiểm

    var settingsForSelfTest: Settings { settings }

    func setFontSizeForSelfTest(_ text: String) {
        fontSizeField.stringValue = text
        valueChanged()
    }

    func setLanguageForSelfTest(_ language: L10n.Language) {
        selectLanguage(named: language.rawValue)
        valueChanged()
    }

    /// Tên đang hiện trên bộ chọn, cho bài kiểm.
    var languageTitleForSelfTest: String { languagePopUp.titleOfSelectedItem ?? "" }

    /// Số MỤC CHỌN ĐƯỢC trên bộ chọn — dải phân cách và tiêu đề vùng không tính.
    var selectableLanguageCountForSelfTest: Int {
        languagePopUp.itemArray.filter { $0.representedObject is L10n.Language }.count
    }
}

// MARK: - Bộ chọn ngôn ngữ

extension PreferencesPanel {

    /// Dựng menu ngôn ngữ, gom theo vùng.
    ///
    /// Ba mươi lăm mục trong một danh sách phẳng là một cuộn dài không ai dò nổi. Gom theo vùng
    /// thì người dùng nhảy thẳng tới khối của mình — và các khối theo đúng thứ tự anh nêu:
    /// Âu/Mỹ, Trung Đông, Á.
    ///
    /// **Ngôn ngữ gắn vào `representedObject`, không suy từ CHỈ SỐ.** Bản cũ đọc
    /// `L10n.Language.allCases[indexOfSelectedItem]`, đúng chừng nào menu còn là ảnh phản chiếu
    /// một-đối-một của `allCases`. Thêm một dải phân cách là mọi chỉ số sau nó lệch một, và
    /// người dùng chọn tiếng Ả Rập lại được tiếng Do Thái — im lặng, vì cả hai đều là ngôn ngữ
    /// hợp lệ và không có gì để nổ.
    func buildLanguageMenu() {
        let menu = NSMenu()

        func them(_ language: L10n.Language) {
            let item = NSMenuItem(title: language.displayName, action: nil, keyEquivalent: "")
            item.representedObject = language
            // Tên bản ngữ phải hiện đúng chiều của CHÍNH nó: "العربية" trong một menu tiếng Việt
            // vẫn phải đọc từ phải. Không đặt thì AppKit căn theo chiều giao diện và chữ Ả Rập
            // dính mép trái, trông như lỗi phông.
            if language.isRTL {
                item.attributedTitle = NSAttributedString(
                    string: language.displayName,
                    attributes: [.writingDirection: [NSWritingDirection.rightToLeft.rawValue]]
                )
            }
            menu.addItem(item)
        }

        them(.system)
        them(.vi)
        for region in L10n.Language.Region.allCases {
            menu.addItem(.separator())
            let header = NSMenuItem(title: region.title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for language in L10n.Language.inRegion(region) { them(language) }
        }
        languagePopUp.menu = menu
    }

    /// Ngôn ngữ đang chọn. Rơi về `.system` khi người dùng bằng cách nào đó đứng trên một tiêu
    /// đề vùng — mục ấy `isEnabled = false` nên không chọn được, nhưng đừng để một giả định về
    /// giao diện quyết định giá trị đem đi ghi vào cấu hình.
    func selectedLanguage() -> L10n.Language {
        languagePopUp.selectedItem?.representedObject as? L10n.Language ?? .system
    }

    func selectLanguage(named code: String) {
        let item = languagePopUp.itemArray.first {
            ($0.representedObject as? L10n.Language)?.rawValue == code
        }
        languagePopUp.select(item ?? languagePopUp.itemArray.first)
    }
}
