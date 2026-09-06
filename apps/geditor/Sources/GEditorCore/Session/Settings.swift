import Foundation

/// Cấu hình người dùng (FR-UI-803 · NFR-PORT-03).
///
/// **Một file JSON đọc được bằng mắt, không phải `UserDefaults`.** ADR-09 chốt thế và có lý do
/// cụ thể: `UserDefaults` nằm trong một plist nhị phân, ở một chỗ khác nhau giữa hai kênh phát
/// hành (bản sandbox có container riêng), không diff được, không chép sang máy khác được, và
/// khi hỏng thì không ai sửa tay nổi. NFR-PORT-03 đòi cấu hình DI ĐỘNG — chép một file là xong.
///
/// **`schemaVersion` để đọc được file của bản cũ, và từ chối file của bản MỚI HƠN.** Bản cũ đọc
/// file mới rồi ghi đè lại sẽ xoá mất những khoá nó không hiểu — người dùng chạy hai bản trên
/// hai máy đồng bộ chung một thư mục là mất cấu hình mà không hiểu vì sao.
///
/// **Khoá thiếu thì dùng mặc định, không phải lỗi.** Người dùng sửa tay file này là chuyện được
/// khuyến khích, và một file thiếu một khoá không được làm app không mở lên nổi.
public struct Settings: Codable, Equatable, Sendable {

    /// Bản của lược đồ. TĂNG khi đổi ý nghĩa một khoá, không phải khi thêm khoá mới.
    public static let currentSchemaVersion = 1

    public var schemaVersion = Settings.currentSchemaVersion

    // MARK: - Soạn thảo

    public var fontSize: Double = 13
    public var tabWidth: Int = 4
    public var usesTabsForIndent = false

    /// Thụt lề RIÊNG cho từng ngôn ngữ — SRS FR-CORE-009.
    ///
    /// Khoá là `SyntaxLanguage.rawValue` (`go`, `python`, `javascript`…); ngôn ngữ không có
    /// mặt ở đây thì dùng `tabWidth`/`usesTabsForIndent` chung.
    ///
    /// **Vì sao một con số chung là không đủ.** Người ta không chọn thụt lề theo sở thích, họ
    /// theo quy ước của từng cộng đồng: Go dùng TAB (`gofmt` ghi đè mọi thứ khác), Python 4
    /// dấu cách (PEP 8), JavaScript/JSON/YAML thường 2. Một lập trình viên mở cả ba loại tệp
    /// trong một buổi, và với một con số chung thì mỗi tệp họ chạm vào là một lần diff mọc
    /// thêm những dòng họ không hề sửa.
    ///
    /// Mặc định RỖNG, cố ý: sản phẩm không đoán hộ quy ước của kho mã người khác. Ai cần thì
    /// khai trong `settings.json`, hoặc bấm mục Tab trên thanh trạng thái.
    public var languageIndent: [String: IndentStyle] = [:]

    /// Một kiểu thụt lề: rộng bao nhiêu, và dùng TAB hay dấu cách.
    public struct IndentStyle: Codable, Equatable, Sendable {
        public var width: Int
        public var usesTabs: Bool

        public init(width: Int, usesTabs: Bool) {
            self.width = width
            self.usesTabs = usesTabs
        }
    }
    /// FR-CORE-008 — mặc định TẮT, xem `MainWindowController.trimsTrailingWhitespaceOnSave`.
    public var trimTrailingWhitespaceOnSave = false
    /// FR-ENC-206 — chuẩn hoá về NFC khi lưu. Mặc định TẮT vì nó đổi byte của file.
    public var normalizeToNFCOnSave = false
    public var smartIndent = true
    public var highlightAllMatches = true

    /// Mở tệp ra là vào thẳng chế độ **View** nếu tệp ấy có — mặc định BẬT.
    ///
    /// Người dùng nói: *"các file nên để mặc định chế độ view nếu có"*. Đúng với cách người ta
    /// mở một tệp `.docx` hay `.pdf`: họ muốn ĐỌC nó, không muốn nhìn Markdown rút ra.
    ///
    /// Chỉ áp cho những chế độ View dựng NGAY TRONG TAB. Xem trước Markdown và xem trước báo
    /// cáo mở ra một cửa sổ/panel riêng — bật sẵn chúng là tự dựng thêm cửa sổ cho mỗi tệp
    /// người dùng mở, thứ không ai xin.
    public var openInViewMode = true

    /// NFR-USE-05 — chữ ghép (ligature) trong vùng soạn thảo. **Mặc định TẮT.**
    ///
    /// Tắt vì đây là trình soạn thảo mã và dữ liệu: một chữ ghép gộp `!=` thành một hình duy
    /// nhất, nên **số ký tự trên màn hình không còn khớp số ký tự trong tệp** — mà chính sản
    /// phẩm này có Column Editor, chế độ cột và ngắt dòng tại cột, ba thứ đều đo bằng cột. Với
    /// tiếng Việt còn một vế nữa: font có ligature cho cặp `fi`, `fl` sẽ dán liền hai chữ trong
    /// những từ như `tài chính` viết bằng font tỉ lệ.
    ///
    /// Vẫn cho BẬT vì với văn xuôi thì chữ ghép đẹp hơn thật, và người dùng font lập trình có
    /// ligature (Fira Code, JetBrains Mono) chọn font ấy chính là để thấy chúng.
    public var ligatures = false

    // MARK: - Bảng mã và xuống dòng cho file mới (FR-ENC-207)

    public var defaultEncoding = "utf-8"
    public var defaultEOL = "lf"

    // MARK: - Giao diện

    /// FR-UI-804 — `"vi"`, `"en"`, hoặc `"system"` để theo ngôn ngữ hệ điều hành.
    public var language = "system"
    /// FR-UI-801 — `"system"`, `"light"`, `"dark"`.
    public var appearance = "system"

    /// FR-UI-801 — tên theme đang dùng; không tìm thấy thì về theme mặc định.
    public var themeName = Theme.cam.name

    /// Chiều cao người dùng đã KÉO cho từng panel: tên tầng → point.
    ///
    /// Chỉ chứa những panel người dùng đã tự chỉnh. Panel chưa động tới thì không có mặt ở đây
    /// và lấy chiều cao theo TỈ LỆ cửa sổ — xem `MainWindowController.panelOpenHeight`.
    ///
    /// Ghi cả bảng thì mỗi lần sản phẩm đổi một con số mặc định, người dùng cũ vẫn kẹt với con
    /// số cũ mà không hiểu vì sao — cùng lý do `keyBindings` chỉ ghi phần khác mặc định.
    public var panelHeights: [String: Double] = [:]

    /// Mở cửa sổ Trợ giúp ở trang giới thiệu mỗi lần khởi động (NFR-USE-04).
    ///
    /// **Mặc định BẬT, và tắt được bằng đúng một ô tích ngay trên cửa sổ ấy.** Một màn hình chào
    /// không tắt được là thứ người dùng nhớ về sản phẩm lâu hơn mọi tính năng trong đó. Đổi lại,
    /// khoá này nằm trong `settings.json` chứ không nằm trong một chỗ ẩn — ai lỡ tắt rồi muốn bật
    /// lại thì sửa một dòng, hoặc mở lại từ menu `Help`.
    public var showWelcomeOnLaunch = true

    /// FR-UI-802 — phím tắt người dùng đổi: tên lệnh → phím.
    ///
    /// Chỉ chứa phần KHÁC mặc định. Ghi cả bảng thì mỗi lần sản phẩm đổi một phím mặc định,
    /// người dùng cũ sẽ mắc kẹt ở bảng cũ mà không ai nói cho họ biết.
    public var keyBindings: [String: String] = [:]

    public init() {}

    // MARK: - Đọc / ghi

    public enum Failure: Error, Equatable {
        /// File do một bản GEditor mới hơn ghi ra.
        case newerSchema(found: Int, supported: Int)
    }

    /// Đọc cấu hình từ `url`. File không có thì trả về mặc định — đó là trạng thái bình thường
    /// của lần chạy đầu, không phải lỗi.
    public static func load(from url: URL) throws -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
        let probe = try JSONDecoder().decode(SchemaProbe.self, from: data)
        guard probe.schemaVersion <= currentSchemaVersion else {
            throw Failure.newerSchema(found: probe.schemaVersion, supported: currentSchemaVersion)
        }
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    /// Ghi cấu hình, nguyên tử và có xuống dòng thụt lề để người đọc bằng mắt còn theo được.
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Ghi nguyên tử: mất điện giữa chừng không được để lại một file cấu hình cụt đầu, vì
        // lần khởi động sau sẽ không đọc nổi nó.
        try data.write(to: url, options: .atomic)
    }

    /// Chỉ đọc số hiệu lược đồ, không đụng tới khoá nào khác.
    ///
    /// `init(from:)` viết tay chứ không để `Codable` sinh: bản sinh sẵn NÉM khi thiếu khoá, kể
    /// cả khi thuộc tính đã có giá trị mặc định — giá trị mặc định chỉ dùng cho `init()`. Một
    /// file người dùng gõ tay `{}` sẽ làm app không mở lên nổi, và đây đúng là loại lỗi mà bài
    /// kiểm "khoá thiếu rơi về mặc định" sinh ra để bắt.
    private struct SchemaProbe: Decodable {
        var schemaVersion = 0

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        }

        enum CodingKeys: String, CodingKey { case schemaVersion }
    }
}

extension Settings {

    /// Mọi khoá đều có mặc định, nên thiếu khoá là chuyện bình thường.
    ///
    /// `Codable` sinh sẵn `init(from:)` sẽ NÉM khi thiếu khoá. Viết tay để mỗi khoá vắng mặt
    /// rơi về giá trị mặc định — người dùng sửa tay file này là điều được khuyến khích, và một
    /// khoá viết thiếu không được làm app không mở lên nổi.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        func value<T: Decodable>(_ key: CodingKeys, _ default: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) as? T ?? `default`
        }
        schemaVersion = value(.schemaVersion, fallback.schemaVersion)
        fontSize = value(.fontSize, fallback.fontSize)
        tabWidth = value(.tabWidth, fallback.tabWidth)
        usesTabsForIndent = value(.usesTabsForIndent, fallback.usesTabsForIndent)
        // Khoá mới phải có mặt ở CẢ HAI chiều. `SettingsTests` đã bắt được đúng lỗi này một
        // lần rồi (04/09): khoá ghi xuống được nhưng đọc lại không ra, vì `init(from:)` viết
        // tay và người thêm khoá chỉ sửa phần ghi.
        languageIndent = value(.languageIndent, fallback.languageIndent)
        trimTrailingWhitespaceOnSave = value(
            .trimTrailingWhitespaceOnSave, fallback.trimTrailingWhitespaceOnSave
        )
        normalizeToNFCOnSave = value(.normalizeToNFCOnSave, fallback.normalizeToNFCOnSave)
        smartIndent = value(.smartIndent, fallback.smartIndent)
        highlightAllMatches = value(.highlightAllMatches, fallback.highlightAllMatches)
        ligatures = value(.ligatures, fallback.ligatures)
        openInViewMode = value(.openInViewMode, fallback.openInViewMode)
        defaultEncoding = value(.defaultEncoding, fallback.defaultEncoding)
        defaultEOL = value(.defaultEOL, fallback.defaultEOL)
        language = value(.language, fallback.language)
        appearance = value(.appearance, fallback.appearance)
        themeName = value(.themeName, fallback.themeName)
        panelHeights = value(.panelHeights, fallback.panelHeights)
        showWelcomeOnLaunch = value(.showWelcomeOnLaunch, fallback.showWelcomeOnLaunch)
        keyBindings = value(.keyBindings, fallback.keyBindings)
    }
}
