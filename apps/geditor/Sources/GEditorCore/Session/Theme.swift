import Foundation

/// Bảng màu người dùng chọn được (FR-UI-801).
///
/// **Màu ghi bằng chuỗi hex, không phải `NSColor`.** Kiểu này nằm ở LÕI, mà lõi không được
/// import AppKit (NFR-MNT-01, có script CI chặn). Cái lợi đi kèm: một theme là một file JSON
/// người ta chép cho nhau được, và mở ra đọc là hiểu — đúng tinh thần NFR-PORT-03.
///
/// **Mỗi màu có bản SÁNG và bản TỐI.** macOS đổi nền theo hệ thống hoặc theo giờ trong ngày, và
/// một theme chỉ định nghĩa một bản sẽ có nửa số lần là chữ đen trên nền đen.
///
/// **Không định nghĩa hết mọi màu của giao diện.** Chỉ những màu của VÙNG SOẠN THẢO và màu nhấn
/// — thứ người ta thật sự muốn đổi. Màu của nút, đường kẻ, nền panel để hệ điều hành lo, vì
/// chúng phải khớp với phần còn lại của máy chứ không phải với theme.
public struct Theme: Codable, Equatable, Sendable {

    /// Một màu ở hai chế độ nền.
    public struct Pair: Codable, Equatable, Sendable {
        public var light: String
        public var dark: String

        public init(light: String, dark: String) {
            self.light = light
            self.dark = dark
        }
    }

    public var name: String
    /// Màu nhấn: con nháy, viền khung tầm nhìn, tab đang mở.
    public var accent: Pair
    public var editorBackground: Pair
    public var editorInk: Pair
    public var selection: Pair
    public var searchHighlight: Pair

    public init(
        name: String, accent: Pair, editorBackground: Pair, editorInk: Pair,
        selection: Pair, searchHighlight: Pair
    ) {
        self.name = name
        self.accent = accent
        self.editorBackground = editorBackground
        self.editorInk = editorInk
        self.selection = selection
        self.searchHighlight = searchHighlight
    }

    /// Theme mặc định — chính bảng màu đang dùng, viết ra thành dữ liệu.
    ///
    /// Viết ra chứ không để ngầm định trong mã: người dùng muốn sửa một màu sẽ "Xuất theme hiện
    /// tại" rồi sửa một dòng, thay vì phải dựng cả file từ đầu và đoán tên khoá.
    public static let cam = Theme(
        name: "GEditor Cam",
        accent: Pair(light: "#ED6A1F", dark: "#ED6A1F"),
        editorBackground: Pair(light: "#FFFDFB", dark: "#1A1613"),
        editorInk: Pair(light: "#1C1917", dark: "#EDE8E3"),
        selection: Pair(light: "#FFDCC5", dark: "#4A2410"),
        searchHighlight: Pair(light: "#FFF3B0", dark: "#5A4A12")
    )

    /// Theme xám trung tính, cho người thấy màu cam quá mạnh khi nhìn cả ngày.
    public static let than = Theme(
        name: "Than chì",
        accent: Pair(light: "#3B7DD8", dark: "#5B9BF0"),
        editorBackground: Pair(light: "#FFFFFF", dark: "#15181C"),
        editorInk: Pair(light: "#1A1D21", dark: "#E4E7EB"),
        selection: Pair(light: "#CFE1F8", dark: "#22384F"),
        searchHighlight: Pair(light: "#FFF3B0", dark: "#4E4A1E")
    )

    public static let builtIn = [cam, than]

    // MARK: - Đọc / ghi

    public static func load(from url: URL) throws -> Theme {
        try JSONDecoder().decode(Theme.self, from: try Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// Mọi theme trong thư mục, cộng với các theme dựng sẵn.
    ///
    /// File hỏng thì BỎ QUA file ấy, không ném: một theme người dùng gõ sai một dấu phẩy không
    /// được làm biến mất cả danh sách và cũng không được chặn app khởi động.
    public static func all(in directory: URL) -> [Theme] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let custom = names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .compactMap { try? load(from: directory.appendingPathComponent($0)) }
        // Theme người dùng đặt trùng tên với theme dựng sẵn thì bản của họ THẮNG: họ sửa cái
        // đó ra vì muốn dùng bản sửa.
        var out = builtIn
        for theme in custom {
            if let index = out.firstIndex(where: { $0.name == theme.name }) {
                out[index] = theme
            } else {
                out.append(theme)
            }
        }
        return out
    }

    // MARK: - Hex

    /// `#RRGGBB` → ba thành phần 0…1, hoặc `nil` nếu chuỗi không hợp lệ.
    ///
    /// Trả `nil` chứ không rơi về đen: một màu gõ sai mà thành đen sẽ trông như một lựa chọn
    /// thiết kế, và người dùng đi tìm lỗi ở chỗ khác.
    public static func components(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}
