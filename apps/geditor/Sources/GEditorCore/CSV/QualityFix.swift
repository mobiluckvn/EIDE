import Foundation

/// Nối một luật TRƯỢT với đúng công cụ sửa nó — FR-DQR-006.
///
/// ```
/// not_null            → Xử lý giá trị thiếu   (FR-CLN-002)
/// date_format / dtype: date → Chuẩn hóa ngày  (FR-CLN-001)
/// unique              → Khử trùng lặp         (FR-CORE-006)
/// regex / in_set      → Thay thế có xem trước (FR-CORE-004)
/// ```
///
/// ## Vì sao bảng ánh xạ này nằm ở LÕI chứ không ở panel
///
/// Nó là một quyết định về Ý NGHĨA — *"luật này hỏng thì công cụ nào sửa được"* — chứ không phải
/// một chi tiết giao diện. Đặt nó trong `QualityPanel` thì bài kiểm cho nó phải dựng một cửa sổ
/// AppKit, và cả cụm FR-DQR sẽ có đúng một mảnh không kiểm được ở tầng lõi.
///
/// ## Luật KHÔNG có công cụ tương ứng thì nói ra, không giấu nút đi
///
/// `range`, `length`, `compare`, `expr`, `foreign_key` không có công cụ nào sửa được bằng một
/// bước máy làm — sửa một giá trị ngoài khoảng là quyết định của người biết dữ liệu ấy nghĩa gì.
/// Nên nút vẫn hiện nhưng ở dạng "không sửa tự động được", kèm lý do; ẩn nó đi thì người dùng
/// tưởng mình bỏ sót một thao tác.
public enum QualityFix {

    public enum Tool: Equatable, Sendable {
        /// FR-CLN-002 — Xử lý giá trị thiếu trên cột.
        case missingValues(column: String)
        /// FR-CLN-001 — Chuẩn hóa ngày về ISO trên cột.
        case normalizeDates(column: String)
        /// Khử trùng lặp. `key` là cột lẽ ra phải duy nhất.
        case deduplicate(column: String)
        /// Thay thế có xem trước, trên các GIÁ TRỊ đang vi phạm của cột.
        case replace(column: String)
        /// Không có công cụ nào sửa tự động được — kèm lý do đọc được.
        case manual(reason: String)

        public var isAutomatic: Bool {
            if case .manual = self { return false }
            return true
        }

        /// Chữ trên nút.
        public var actionTitle: String {
            switch self {
            case .missingValues: return "Xử lý giá trị thiếu…"
            case .normalizeDates: return "Chuẩn hóa ngày…"
            case .deduplicate: return "Khử trùng lặp…"
            case .replace: return "Thay thế…"
            case .manual: return "Xem các dòng sai"
            }
        }

        public var column: String? {
            switch self {
            case let .missingValues(column), let .normalizeDates(column),
                 let .deduplicate(column), let .replace(column):
                return column
            case .manual: return nil
            }
        }
    }

    /// Công cụ cho một luật. Thuần ánh xạ — không đọc dữ liệu, không quét gì.
    public static func tool(for rule: QualityRules.Rule) -> Tool {
        guard let column = rule.column else {
            return .manual(reason: "luật liên cột không sửa được bằng một thao tác trên một "
                + "cột — hãy xem các dòng sai rồi quyết định")
        }
        switch rule.kind {
        case .notNull:
            return .missingValues(column: column)
        case .dateFormat:
            return .normalizeDates(column: column)
        case .dtype(let type):
            // `dtype: date` cùng một chuyện với `date_format`: ô không đổi được sang ngày.
            // `int`/`float` thì Chuẩn hóa số (FR-CLN-003) sửa được phần lớn ca thật — nhưng
            // đặc tả FR-DQR-006 không kê nó, nên chỗ này không tự ý thêm.
            return type == .date
                ? .normalizeDates(column: column)
                : .manual(reason: "ô sai kiểu \(type.rawValue) cần người xem giá trị thật rồi "
                    + "quyết định — máy đoán hộ là hỏng dữ liệu trong im lặng")
        case .unique:
            return .deduplicate(column: column)
        case .regex, .inSet:
            return .replace(column: column)
        case .range(let low, let high):
            let bounds = [low.map { "≥ \($0)" }, high.map { "≤ \($0)" }]
                .compactMap { $0 }.joined(separator: " và ")
            return .manual(reason: "giá trị ngoài khoảng (\(bounds)) — sửa một con số ngoài "
                + "khoảng là quyết định của người biết dữ liệu ấy nghĩa gì")
        case .length:
            return .manual(reason: "độ dài sai — cắt bớt hay đệm thêm đều làm đổi dữ liệu, "
                + "nên đây là việc của người")
        case .compare, .expr, .foreignKey:
            return .manual(reason: "luật liên cột / liên file — không có một thao tác đơn nào "
                + "sửa được, hãy xem các dòng sai")
        }
    }

    /// Luật nào phải chấm lại sau khi sửa cột này — FR-DQR-006 (*"các rule liên quan TỰ CHẠY
    /// LẠI"*).
    ///
    /// "Liên quan" gồm cả luật liên cột có nhắc tới cột ấy: điền giá trị vào một ô rỗng có thể
    /// làm `ngay_giao >= ngay_dat` từ đạt thành trượt, và một bảng chỉ chấm lại đúng luật vừa
    /// sửa sẽ hiện ra một điểm số sai theo hướng đẹp hơn thật.
    public static func rulesTouching(column: String, in rules: QualityRules) -> [Int] {
        rules.rules.enumerated().compactMap { index, rule in
            if rule.column == column { return index }
            switch rule.kind {
            case let .compare(left, _, right):
                return left == column || right == column ? index : nil
            case let .expr(text):
                // So thô: tên cột xuất hiện trong biểu thức. Rộng hơn cần thiết, và rộng là
                // hướng đúng — chấm lại thừa một luật tốn vài mili-giây, bỏ sót một luật cho ra
                // một điểm số sai.
                return text.contains(column) ? index : nil
            default:
                return nil
            }
        }
    }
}

public extension QualityEngine {

    /// Các GIÁ TRỊ đang vi phạm một luật, đã khử trùng — để dựng sẵn ô "Tìm" của hộp thay thế.
    ///
    /// Trả về giá trị THẬT chứ không phải một mẫu suy ra từ luật. Với `regex`, mẫu trong luật mô
    /// tả cái ĐÚNG, nên muốn tìm cái sai bằng chính nó thì phải bọc một phủ định — mà một biểu
    /// thức phủ định lồng nhau là thứ người dùng không đọc được và không sửa được. Một danh sách
    /// giá trị có thật thì họ nhìn là hiểu ngay.
    static func violatingValues(
        for rule: QualityRules.Rule,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        limit: Int = 50,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [String] {
        guard let column = rule.column else { return [] }
        let predicate = violationPredicate(rule)
        guard predicate != "FALSE" else { return [] }
        let quoted = quoteIdentifier(column)
        let sql = """
            SELECT DISTINCT CAST(\(quoted) AS VARCHAR) FROM \(CSVQueryEngine.tableName)
            WHERE \(predicate)
            ORDER BY 1
            LIMIT \(max(1, limit))
            """
        let table = try CSVQueryEngine.run(
            sql, in: buffer, dialect: dialect, sourcePath: sourcePath,
            cancelToken: cancelToken)
        return table.rows.compactMap { $0.first ?? nil }
    }
}
