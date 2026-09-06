import Foundation

/// Gói mở rộng: script, theme và ngôn ngữ tự định nghĩa trong MỘT file (FR-PLUG-701 · FR-PLUG-705).
///
/// **Một file JSON, không phải thư mục nén.** Định dạng nén đòi giải nén ra đâu đó, và "đâu đó"
/// là chỗ mọi lỗi bảo mật của trình cài đặt sinh ra: đường dẫn `../..` trong tên mục, ghi đè
/// file ngoài thư mục đích, liên kết tượng trưng trỏ ra ngoài. Một file JSON phẳng không có
/// những cửa ấy — mọi thứ bên trong là **nội dung**, và ta tự quyết định ghi ra đâu.
///
/// **Cái giá:** không đóng gói được nhị phân hay ảnh. Chấp nhận: FR-PLUG-702 (plugin native) là
/// một yêu cầu riêng, và nó vướng ràng buộc App Store chứ không vướng định dạng gói.
///
/// **Cài đặt là chép file, gỡ là xoá file.** Không có sổ đăng ký, không có trạng thái nào ngoài
/// những file nằm trong `scripts/`, `themes/`, `grammars/`. Người dùng gỡ tay bằng Finder cũng
/// đúng như gỡ bằng ứng dụng — một trình quản lý gói mà đi lệch khỏi hiện trạng đĩa là một
/// trình quản lý gói sẽ nói dối.
public struct PluginPackage: Codable, Equatable, Sendable {

    public static let currentFormatVersion = 1
    /// Đuôi file quy ước.
    public static let fileExtension = "geditorpkg"

    public var formatVersion = PluginPackage.currentFormatVersion
    public var name: String
    /// Semver của chính gói này, do tác giả đặt.
    public var version: String
    public var author: String?
    public var summary: String?

    /// Script JavaScript: tên file (không đuôi) → nội dung.
    public var scripts: [String: String]
    public var themes: [Theme]
    public var languages: [UserDefinedLanguage]

    public init(
        name: String, version: String, author: String? = nil, summary: String? = nil,
        scripts: [String: String] = [:], themes: [Theme] = [], languages: [UserDefinedLanguage] = []
    ) {
        self.name = name
        self.version = version
        self.author = author
        self.summary = summary
        self.scripts = scripts
        self.themes = themes
        self.languages = languages
    }

    public var isEmpty: Bool { scripts.isEmpty && themes.isEmpty && languages.isEmpty }

    /// Mô tả một dòng cho danh sách.
    public var subtitle: String {
        var parts: [String] = []
        if !scripts.isEmpty { parts.append("\(scripts.count) script") }
        if !themes.isEmpty { parts.append("\(themes.count) theme") }
        if !languages.isEmpty { parts.append("\(languages.count) ngôn ngữ") }
        return parts.isEmpty ? "gói rỗng" : parts.joined(separator: " · ")
    }

    // MARK: - Lỗi

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case newerFormat(found: Int, supported: Int)
        case unsafeName(String)
        case emptyPackage

        public var description: String {
            switch self {
            case .newerFormat(let found, let supported):
                return "Gói dùng định dạng v\(found), bản này chỉ đọc được tới v\(supported)"
            case .unsafeName(let name):
                return "Tên «\(name)» không dùng làm tên file được"
            case .emptyPackage:
                return "Gói không chứa script, theme hay ngôn ngữ nào"
            }
        }
    }

    // MARK: - Đọc / ghi

    public static func load(from url: URL) throws -> PluginPackage {
        let data = try Data(contentsOf: url)
        let probe = try JSONDecoder().decode(FormatProbe.self, from: data)
        guard probe.formatVersion <= currentFormatVersion else {
            throw Failure.newerFormat(found: probe.formatVersion, supported: currentFormatVersion)
        }
        return try JSONDecoder().decode(PluginPackage.self, from: data)
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    private struct FormatProbe: Decodable {
        var formatVersion = 0

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 0
        }

        enum CodingKeys: String, CodingKey { case formatVersion }
    }

    // MARK: - Cài / gỡ

    /// Nơi từng loại nội dung đi tới.
    public struct Destinations {
        public let scripts: URL
        public let themes: URL
        public let languages: URL

        public init(scripts: URL, themes: URL, languages: URL) {
            self.scripts = scripts
            self.themes = themes
            self.languages = languages
        }
    }

    /// Những file gói này đã đặt lên đĩa.
    public struct Installation: Equatable {
        public let packageName: String
        public let files: [String]
    }

    /// Chép nội dung gói ra các thư mục dữ liệu.
    ///
    /// Mọi file mang tiền tố tên gói, ví dụ `gói-của-tôi.đánh-số.js`. Hai gói khác nhau có thể
    /// cùng có một script tên `format`, và không có tiền tố thì gói cài sau nuốt mất gói cài
    /// trước mà không ai báo gì. Tiền tố cũng là thứ làm phép GỠ thành khả thi: gỡ một gói là
    /// xoá đúng những file mang tên nó.
    @discardableResult
    public func install(into destinations: Destinations) throws -> Installation {
        guard !isEmpty else { throw Failure.emptyPackage }
        try validateNames()

        var written: [String] = []
        for (scriptName, source) in scripts.sorted(by: { $0.key < $1.key }) {
            let url = destinations.scripts.appendingPathComponent("\(prefix).\(scriptName).js")
            try write(Data(source.utf8), to: url)
            written.append(url.path)
        }
        for theme in themes {
            let url = destinations.themes.appendingPathComponent("\(prefix).\(Self.slug(theme.name)).json")
            try theme.save(to: url)
            written.append(url.path)
        }
        for language in languages {
            let url = destinations.languages
                .appendingPathComponent("\(prefix).\(Self.slug(language.name)).json")
            try language.save(to: url)
            written.append(url.path)
        }
        return Installation(packageName: name, files: written)
    }

    /// Xoá mọi file mang tiền tố của gói `name`.
    ///
    /// Trả về đường dẫn đã xoá. Không có file nào là danh sách rỗng, KHÔNG phải lỗi: gỡ một thứ
    /// đã không còn ở đó thì kết quả mong muốn đã đạt.
    @discardableResult
    public static func uninstall(
        name: String, from destinations: Destinations
    ) -> [String] {
        let marker = slug(name) + "."
        var removed: [String] = []
        for directory in [destinations.scripts, destinations.themes, destinations.languages] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for file in names.sorted() where file.hasPrefix(marker) {
                let url = directory.appendingPathComponent(file)
                if (try? FileManager.default.removeItem(at: url)) != nil { removed.append(url.path) }
            }
        }
        return removed
    }

    /// Những gói đang cài, suy ra TỪ ĐĨA chứ không từ một sổ đăng ký.
    ///
    /// Không giữ sổ là chủ ý: người dùng xoá tay một file trong Finder thì hiện trạng đã đổi, và
    /// một cuốn sổ nói khác đi là một cuốn sổ nói dối. Cái giá là ta chỉ biết TÊN gói, không
    /// biết phiên bản — chấp nhận được, vì thứ họ cần khi gỡ là tên.
    public static func installedNames(in destinations: Destinations) -> [String] {
        var names: Set<String> = []
        for directory in [destinations.scripts, destinations.themes, destinations.languages] {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for file in files {
                let parts = file.split(separator: ".")
                // `<gói>.<tên>.<đuôi>` — đúng ba phần. File người dùng tự đặt (`a.js`) chỉ có
                // hai và không bị nhận nhầm là gói.
                guard parts.count >= 3 else { continue }
                names.insert(String(parts[0]))
            }
        }
        return names.sorted()
    }

    // MARK: - An toàn tên

    private var prefix: String { Self.slug(name) }

    /// Tên gói và tên nội dung phải dùng làm tên file được.
    ///
    /// Đây là hàng rào quan trọng nhất của cả lớp này. Một gói tải từ internet có thể đặt tên
    /// script là `../../../../etc/passwd`, và nếu ta ghép thẳng vào đường dẫn thì phép "cài đặt"
    /// trở thành phép ghi đè file hệ thống.
    func validateNames() throws {
        guard !Self.slug(name).isEmpty else { throw Failure.unsafeName(name) }
        for scriptName in scripts.keys where !Self.isSafe(scriptName) {
            throw Failure.unsafeName(scriptName)
        }
        for theme in themes where Self.slug(theme.name).isEmpty {
            throw Failure.unsafeName(theme.name)
        }
        for language in languages where Self.slug(language.name).isEmpty {
            throw Failure.unsafeName(language.name)
        }
    }

    static func isSafe(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64 else { return false }
        guard !name.contains("/"), !name.contains("\\"), !name.contains(":") else { return false }
        guard name != ".", name != "..", !name.hasPrefix(".") else { return false }
        return true
    }

    /// Tên rút gọn dùng làm phần đầu tên file: bỏ dấu, thay khoảng trắng bằng gạch ngang.
    ///
    /// Bỏ dấu vì tên file có dấu tiếng Việt vẫn hợp lệ nhưng gõ lại trong Terminal thì khổ, và
    /// người ta hay phải làm thế khi gỡ tay.
    public static func slug(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "vi"))
        let allowed = folded.map { character -> Character in
            if character.isLetter || character.isNumber { return Character(character.lowercased()) }
            return "-"
        }
        // Gộp gạch ngang liền nhau và cắt hai đầu: `Gói của tôi!!!` → `goi-cua-toi`.
        return String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
