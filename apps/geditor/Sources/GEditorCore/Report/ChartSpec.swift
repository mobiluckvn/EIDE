import Foundation

/// Spec biểu đồ trong khối ```chart — FR-RPT-001 (cú pháp) và FR-RPT-002 (kiểu dáng).
///
/// ```yaml
/// kind: bar
/// query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
/// title: Doanh thu theo tỉnh
/// x_label: Tỉnh
/// y_label: Doanh thu
/// number_format: vi
/// decimals: 0
/// suffix: " ₫"
/// theme: brand
/// source: Nguồn — ban-hang.csv, chốt 26/08/2026
/// ```
///
/// ## Không có `query` thì dùng kết quả của khối query LIỀN TRƯỚC
///
/// Đây là luật quan trọng nhất của định dạng, và nó chọn sự tiện dụng có chủ ý. Cách khác —
/// buộc mọi khối chart mang câu SQL của riêng nó — làm một báo cáo "bảng rồi biểu đồ của chính
/// bảng ấy" phải chép câu truy vấn hai lần. Chép hai lần thì sớm muộn hai bản lệch nhau, và khi
/// ấy bảng nói một đằng biểu đồ nói một nẻo trong cùng một trang.
///
/// Đổi lại, thứ tự khối trở nên **có nghĩa**: chèn một khối query vào giữa sẽ đổi dữ liệu của
/// biểu đồ bên dưới. Nên trình kết xuất nói rõ biểu đồ đang lấy dữ liệu từ khối nào khi có lỗi.
///
/// ## Vì sao `source` là một khoá riêng chứ không phải một dòng văn xuôi
///
/// Đặc tả đòi *"chú thích nguồn"*. Viết nó thành văn xuôi dưới biểu đồ cũng hiện ra được — trên
/// màn hình. Nhưng biểu đồ sẽ được xuất thành PNG/SVG rồi dán vào chỗ khác, và lúc đó dòng văn
/// xuôi ở lại. Là một khoá thì nó **nằm trong chính hình vẽ** và đi theo tấm ảnh, cùng lý do với
/// câu "tương quan không hàm ý nhân quả" của FR-MIN-005.
public struct ChartSpec: Equatable, Sendable {

    public var kind: ChartData.Kind
    /// SQL riêng của biểu đồ. Rỗng = dùng kết quả khối query liền trước.
    public var query: String
    public var title: String
    public var xLabel: String
    public var yLabel: String
    public var source: String
    public var numberStyle: NumberStyle
    public var palette: ChartRender.Palette
    /// Rút gọn còn tối đa bao nhiêu điểm. `nil` = theo mặc định của `ChartData`.
    public var limit: Int?

    public init(
        kind: ChartData.Kind = .bar, query: String = "", title: String = "",
        xLabel: String = "", yLabel: String = "", source: String = "",
        numberStyle: NumberStyle = .vietnamese,
        palette: ChartRender.Palette = .gLight, limit: Int? = nil
    ) {
        self.kind = kind
        self.query = query
        self.title = title
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.source = source
        self.numberStyle = numberStyle
        self.palette = palette
        self.limit = limit
    }

    public var style: ChartRender.Style {
        ChartRender.Style(palette: palette, numbers: numberStyle)
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Khoá được hiểu. Dùng để bắt lỗi gõ sai — xem `parse`.
    static let knownKeys: Set<String> = [
        "kind", "type", "query", "title", "x_label", "y_label", "source",
        "number_format", "decimals", "prefix", "suffix", "theme", "limit",
    ]

    public static func parse(
        _ yaml: String, inheriting defaults: ChartSpec = ChartSpec()
    ) throws -> ChartSpec {
        let root: YAMLValue
        do {
            root = try YAMLReader.parse(yaml)
        } catch let failure as YAMLReader.Failure {
            throw Failure(message: "khối chart không đọc được: \(failure.message)")
        }

        // Khoá lạ là LỖI, không phải bỏ qua.
        //
        // Gõ `titel:` thay vì `title:` mà bỏ qua thì biểu đồ hiện ra không có tiêu đề và người
        // dùng đi tìm lỗi ở chỗ khác. Đây là loại lỗi tốn nhiều thời gian nhất trong mọi định
        // dạng cấu hình, và nó rẻ để chặn.
        for key in root.mappingKeys where !knownKeys.contains(key) {
            throw Failure(message: "khối chart có khoá lạ «\(key)» — các khoá hiểu được: "
                + knownKeys.sorted().joined(separator: ", "))
        }

        var spec = defaults
        // `kind` và `type` là một; đặc tả gọi là "kiểu", còn người quen YAML hay gõ `type`.
        if let name = (root["kind"] ?? root["type"])?.stringValue {
            guard let kind = ChartData.Kind(rawValue: name.lowercased()) else {
                throw Failure(message: "kiểu biểu đồ «\(name)» không hiểu — có: "
                    + ChartData.Kind.allCases.map(\.rawValue).joined(separator: ", "))
            }
            spec.kind = kind
        }
        if let query = root["query"]?.stringValue { spec.query = query }
        if let title = root["title"]?.stringValue { spec.title = title }
        if let label = root["x_label"]?.stringValue { spec.xLabel = label }
        if let label = root["y_label"]?.stringValue { spec.yLabel = label }
        if let source = root["source"]?.stringValue { spec.source = source }

        if let name = root["number_format"]?.stringValue {
            guard let style = NumberStyle.named(name) else {
                throw Failure(message: "quy ước số «\(name)» không hiểu — có: vi, en, plain")
            }
            spec.numberStyle = style
        }
        if let decimals = root["decimals"]?.intValue {
            guard (0...9).contains(decimals) else {
                throw Failure(message: "decimals phải trong khoảng 0…9, nhận \(decimals)")
            }
            spec.numberStyle.decimals = decimals
        }
        if let prefix = root["prefix"]?.stringValue { spec.numberStyle.prefix = prefix }
        if let suffix = root["suffix"]?.stringValue { spec.numberStyle.suffix = suffix }

        if let name = root["theme"]?.stringValue {
            guard let palette = ChartRender.Palette.named(name) else {
                throw Failure(message: "theme «\(name)» không hiểu — có: g-light, g-dark, brand")
            }
            spec.palette = palette
        }
        if let limit = root["limit"]?.intValue {
            guard limit >= 3 else {
                // Dưới 3 điểm thì LTTB không rút gọn được (nó luôn giữ điểm đầu và cuối), và
                // một biểu đồ 2 điểm không nói được gì. Nói ra thay vì âm thầm kẹp về 3.
                throw Failure(message: "limit phải từ 3 trở lên, nhận \(limit)")
            }
            spec.limit = limit
        }
        return spec
    }

    /// Mặc định lấy từ frontmatter, để cả báo cáo dùng chung một quy ước số và một theme.
    ///
    /// Khai lại `number_format` ở từng khối là cách chắc chắn để một khối bị quên và cả trang
    /// có hai quy ước số — người đọc sẽ tưởng hai bảng nói về hai loại đơn vị.
    public static func defaults(from frontmatter: YAMLValue?) throws -> ChartSpec {
        var spec = ChartSpec()
        guard let frontmatter else { return spec }
        if let name = frontmatter["number_format"]?.stringValue {
            guard let style = NumberStyle.named(name) else {
                throw Failure(message: "frontmatter: quy ước số «\(name)» không hiểu")
            }
            spec.numberStyle = style
        }
        if let decimals = frontmatter["decimals"]?.intValue {
            spec.numberStyle.decimals = decimals
        }
        if let name = frontmatter["theme"]?.stringValue {
            guard let palette = ChartRender.Palette.named(name) else {
                throw Failure(message: "frontmatter: theme «\(name)» không hiểu")
            }
            spec.palette = palette
        }
        return spec
    }
}
