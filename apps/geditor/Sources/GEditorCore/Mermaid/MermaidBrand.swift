import Foundation

/// Bộ màu thương hiệu cho sơ đồ — FR-MMD-007 (*"THEME BRAND tùy biến qua %%{init}%% với preset
/// công ty lưu được"*).
///
/// ## Một tệp JSON cạnh theme, không phải một mục trong `settings.json`
///
/// Cùng luật ADR-09 với theme, macro và bộ quy tắc chất lượng: **cấu hình là văn bản, nằm cạnh
/// thứ nó nói về, chép sang máy khác được**. Chữ *"preset CÔNG TY"* trong đặc tả nói thẳng ra
/// điều đó — một bộ màu của công ty là thứ một người dựng rồi gửi cho hai chục người còn lại, và
/// một dòng trong `settings.json` của từng người thì không gửi đi đâu được.
///
/// ## Sinh ra `%%{init}%%` chứ không chỉ đặt tham số lúc vẽ
///
/// Hai đường dùng, và cả hai đều cần:
///
/// - **Xem trước**: truyền `themeVariables` thẳng vào `mermaid.initialize` — nhanh, không đụng
///   vào tài liệu.
/// - **Chèn vào tài liệu**: sinh một dòng `%%{init: …}%%` để sơ đồ **tự mang màu của nó** khi
///   rời khỏi GEditor. Một sơ đồ dán vào GitHub hay Confluence sẽ mất sạch màu nếu màu chỉ nằm
///   trong cấu hình của app.
public struct MermaidBrand: Codable, Equatable, Sendable {

    /// Tên preset, để người dùng biết mình đang dùng bộ nào.
    public var name: String
    /// Màu chính của node.
    public var primaryColor: String
    /// Màu chữ trên node.
    public var primaryTextColor: String
    /// Màu viền node.
    public var primaryBorderColor: String
    /// Màu đường nối.
    public var lineColor: String
    /// Màu nền của cả sơ đồ khi xuất ảnh có nền ĐỤC.
    public var background: String
    /// Phông chữ. Rỗng = để mermaid tự chọn.
    public var fontFamily: String

    public init(
        name: String = "Thương hiệu", primaryColor: String = "#3a7bd5",
        primaryTextColor: String = "#ffffff", primaryBorderColor: String = "#2a5ba8",
        lineColor: String = "#5a6270", background: String = "#ffffff",
        fontFamily: String = "-apple-system, \"Helvetica Neue\", sans-serif"
    ) {
        self.name = name
        self.primaryColor = primaryColor
        self.primaryTextColor = primaryTextColor
        self.primaryBorderColor = primaryBorderColor
        self.lineColor = lineColor
        self.background = background
        self.fontFamily = fontFamily
    }

    /// Bộ mặc định — màu nhấn của chính GEditor (xem `Tokens.Color`), để bản chưa cấu hình gì
    /// vẫn ra một sơ đồ nhìn được chứ không ra một bảng màu ngẫu nhiên.
    public static let `default` = MermaidBrand()

    // MARK: - Đọc / ghi

    public static var fileURL: URL {
        AppPaths.themesDirectory.appendingPathComponent("mermaid-brand.json")
    }

    /// Đọc preset. Thiếu tệp hoặc tệp hỏng thì rơi về mặc định — một bộ màu hỏng không được
    /// làm mất khả năng vẽ sơ đồ.
    public static func load(from url: URL = MermaidBrand.fileURL) -> MermaidBrand {
        guard let data = try? Data(contentsOf: url),
              let brand = try? JSONDecoder().decode(MermaidBrand.self, from: data)
        else { return .default }
        return brand
    }

    public func save(to url: URL = MermaidBrand.fileURL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    // MARK: - Sang mermaid

    /// Bảng `themeVariables` cho `mermaid.initialize`.
    ///
    /// Thứ tự khoá TẤT ĐỊNH (sắp theo tên) vì nó cũng là nguồn của chuỗi `%%{init}%%`: hai lần
    /// sinh phải ra hai chuỗi giống hệt, nếu không mỗi lần chèn lại là một dòng khác trong
    /// `git diff` dù không ai đổi gì.
    public var themeVariables: [(key: String, value: String)] {
        var pairs: [(String, String)] = [
            ("primaryColor", primaryColor),
            ("primaryTextColor", primaryTextColor),
            ("primaryBorderColor", primaryBorderColor),
            ("lineColor", lineColor),
            ("background", background),
        ]
        if !fontFamily.isEmpty { pairs.append(("fontFamily", fontFamily)) }
        return pairs.sorted { $0.0 < $1.0 }
    }

    /// Dòng `%%{init: …}%%` chèn được vào đầu một sơ đồ.
    ///
    /// `theme: "base"` là bắt buộc: `themeVariables` chỉ có tác dụng trên theme `base`. Đặt
    /// `default` rồi thay biến là một tổ hợp im lặng không làm gì — đúng loại lỗi khiến người
    /// dùng nghĩ mình khai sai màu.
    public var initDirective: String {
        let variables = themeVariables
            .map { "\"\($0.key)\": \(jsonString($0.value))" }
            .joined(separator: ", ")
        return "%%{init: {\"theme\": \"base\", \"themeVariables\": {\(variables)}}}%%"
    }

    /// Trước 28/08/2026 hàm này chỉ thoát `"` và `\\` — một giá trị chứa xuống dòng sinh ra
    /// JSON hỏng, và chỗ nhận nó là JavaScript trong WKWebView, nơi chuỗi hỏng thành lỗi cú pháp
    /// làm sơ đồ không vẽ được chứ không thành một thông báo đọc được.
    private func jsonString(_ text: String) -> String { JSONText.quoted(text) }
}
