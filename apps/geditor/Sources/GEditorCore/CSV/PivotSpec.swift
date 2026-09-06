import Foundation

/// Pivot — FR-QRY-003.
///
/// Đặc tả: *"Kéo-thả cột vào vùng Hàng / Giá trị (sum, count, avg, min, max, distinct); câu SQL
/// tương ứng LUÔN hiển thị và sửa tiếp được trong Workbench (vừa dùng vừa học); kết quả mở tab
/// mới."*
///
/// ## Câu SQL là ĐẦU RA, không phải chi tiết bên trong
///
/// Đó là câu quan trọng nhất của yêu cầu này, và nó quyết định cả thiết kế. Pivot ở đây **không
/// chạy gì** — nó sinh ra một chuỗi SQL rồi đưa cho Query Workbench. Ba hệ quả:
///
/// 1. Người dùng **thấy** câu mình vừa dựng bằng chuột, sửa tiếp được, lưu lại được, chạy từ CLI
///    được. Đó là nghĩa của *"vừa dùng vừa học"*.
/// 2. Không có đường chạy thứ hai để lệch khỏi đường của Workbench — cùng engine, cùng hàng rào
///    chỉ-đọc, cùng bộ dịch lỗi.
/// 3. Kiểm được bằng cách so CHUỖI, không cần dữ liệu và không cần DuckDB.
///
/// Vì thế tệp này không có một lời gọi truy vấn nào.
public struct PivotSpec: Equatable, Sendable {

    public enum Aggregate: String, CaseIterable, Equatable, Sendable {
        case sum, count, average, minimum, maximum, distinct

        public var vietnamese: String {
            switch self {
            case .sum: return "Tổng"
            case .count: return "Đếm"
            case .average: return "Trung bình"
            case .minimum: return "Nhỏ nhất"
            case .maximum: return "Lớn nhất"
            case .distinct: return "Đếm khác nhau"
            }
        }

        /// Hàm SQL, và nhãn cột kết quả.
        func sql(column: String) -> (expression: String, alias: String) {
            let quoted = PivotSpec.quote(column)
            switch self {
            case .sum: return ("SUM(\(quoted))", "tong_\(column)")
            case .count: return ("COUNT(\(quoted))", "dem_\(column)")
            case .average: return ("AVG(\(quoted))", "tb_\(column)")
            case .minimum: return ("MIN(\(quoted))", "min_\(column)")
            case .maximum: return ("MAX(\(quoted))", "max_\(column)")
            case .distinct: return ("COUNT(DISTINCT \(quoted))", "khac_nhau_\(column)")
            }
        }
    }

    public struct Value: Equatable, Sendable {
        public var column: String
        public var aggregate: Aggregate

        public init(column: String, aggregate: Aggregate) {
            self.column = column
            self.aggregate = aggregate
        }
    }

    /// Cột gộp nhóm — vùng "Hàng".
    public var rows: [String]
    /// Phép gộp — vùng "Giá trị".
    public var values: [Value]
    /// Sắp theo giá trị đầu tiên, giảm dần. Mặc định BẬT: pivot gần như luôn được mở ra để tìm
    /// "cái nào lớn nhất", và bắt người dùng thêm `ORDER BY` bằng tay ở bước ấy là bắt họ học
    /// SQL trước khi dùng được thứ đáng lẽ không cần SQL.
    public var sortByFirstValue: Bool
    public var limit: Int?
    public var table: String

    public init(
        rows: [String] = [], values: [Value] = [], sortByFirstValue: Bool = true,
        limit: Int? = nil, table: String = CSVQueryEngine.tableName
    ) {
        self.rows = rows
        self.values = values
        self.sortByFirstValue = sortByFirstValue
        self.limit = limit
        self.table = table
    }

    public var isEmpty: Bool { rows.isEmpty && values.isEmpty }

    // MARK: - Sinh SQL

    /// Câu SQL tương ứng. Chuỗi rỗng khi chưa chọn gì.
    ///
    /// Xuống dòng theo mệnh đề, không dồn một dòng: người dùng sẽ SỬA câu này, và một câu 200
    /// ký tự trên một dòng là câu không ai sửa nổi trong một ô nhập.
    public func sql() -> String {
        guard !isEmpty else { return "" }

        var projections = rows.map(PivotSpec.quote)
        var aliases: [String] = []
        for value in values {
            let (expression, alias) = value.aggregate.sql(column: value.column)
            let safeAlias = PivotSpec.uniqueAlias(alias, taken: aliases + rows)
            aliases.append(safeAlias)
            projections.append("\(expression) AS \(PivotSpec.quote(safeAlias))")
        }
        // Chỉ có Giá trị mà không có Hàng vẫn là một câu hợp lệ: nó gộp cả bảng thành một dòng.
        // Đó là thứ người ta hay làm đầu tiên ("tổng doanh thu là bao nhiêu"), nên đừng chặn.
        if projections.isEmpty { return "" }

        var out = "SELECT " + projections.joined(separator: ",\n       ")
        out += "\nFROM \(table)"
        if !rows.isEmpty {
            out += "\nGROUP BY " + rows.map(PivotSpec.quote).joined(separator: ", ")
        }
        if sortByFirstValue, let first = aliases.first {
            out += "\nORDER BY \(PivotSpec.quote(first)) DESC"
        } else if !rows.isEmpty {
            // Không có giá trị để sắp thì sắp theo chính cột nhóm — kết quả có thứ tự ỔN ĐỊNH
            // là điều kiện để chạy lại hai lần cho ra cùng một bảng, và để so hai lần chạy.
            out += "\nORDER BY " + rows.map(PivotSpec.quote).joined(separator: ", ")
        }
        if let limit { out += "\nLIMIT \(max(1, limit))" }
        return out
    }

    // MARK: - Mảnh

    /// Tên cột trong dấu nháy kép, nhân đôi dấu nháy bên trong.
    ///
    /// Bắt buộc và không có ngoại lệ: tên cột đến từ dòng tiêu đề CSV của người dùng, tức từ
    /// một chuỗi ta không kiểm soát. Một cột tên `Doanh thu "thực"` ghép thẳng vào là sinh ra
    /// một câu SQL hỏng — hoặc một câu SQL khác.
    static func quote(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Nhãn cột kết quả không được TRÙNG nhau.
    ///
    /// Kéo `doanh_thu` vào vùng Giá trị hai lần (một Tổng, một Trung bình) thì hai nhãn khác
    /// nhau sẵn. Nhưng kéo `Tổng doanh thu` vào cạnh một cột đã tên `tong_doanh_thu` thì trùng,
    /// và DuckDB trả về hai cột cùng tên — bảng kết quả khi ấy hiện hai cột không phân biệt
    /// được, và phần xuất CSV sinh ra một tệp có hai tiêu đề giống nhau.
    static func uniqueAlias(_ base: String, taken: [String]) -> String {
        guard taken.contains(base) else { return base }
        var index = 2
        while taken.contains("\(base)_\(index)") { index += 1 }
        return "\(base)_\(index)"
    }
}
