import Foundation

/// Một bước làm sạch đã chốt đủ tham số để chạy (FR-CLN-006).
///
/// Tách Ý ĐỊNH khỏi việc THỰC THI. Giao diện chỉ dựng một bước — "cột 3, chuẩn hóa ngày, quy
/// ước ngày-trước" — rồi đưa cho lõi chạy; nó không phải biết gọi hàm nào trong bảy hàm, và
/// quan trọng hơn: bản xem trước với bản áp thật chắc chắn đi cùng một đường, chỉ khác `maxRows`.
///
/// Đây cũng là mầm của Cleaning Recipe (FR-CLN-005): một công thức là một DÃY bước như thế này,
/// ghi ra JSON và chạy lại trên file khác.
public struct CSVCleanStep: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        case normalizeDates(order: CSVDayMonthOrder?)
        case normalizeNumbers(to: CSVNumberStyle, source: CSVNumberStyle?, grouped: Bool)
        case trim(collapseInner: Bool)
        case changeCase(CSVLetterCase)
        case fillWithValue(String)
        case fill(CSVFillDirection)
        case deleteRowsWithNull
    }

    public var column: Int
    public var kind: Kind

    public init(column: Int, kind: Kind) {
        self.column = column
        self.kind = kind
    }

    /// Nhãn cho nhật ký undo và cho báo cáo — người dùng phải đọc được ở cả hai nơi rằng vừa
    /// có chuyện gì xảy ra với dữ liệu của họ (NFR-CLN-02c).
    public func displayName(columnName: String) -> String {
        switch kind {
        case let .normalizeDates(order):
            // Nhãn của quy ước đã có sẵn ngoặc ("ngày trước (DD/MM)"), nên nối bằng gạch chứ
            // đừng bọc thêm một lớp ngoặc nữa — thấy trên ảnh chụp.
            let suffix = order.map { " — \($0.displayName)" } ?? ""
            return "Chuẩn hóa ngày cột «\(columnName)»\(suffix)"
        case let .normalizeNumbers(style, _, grouped):
            return "Đổi số cột «\(columnName)» sang \(style.displayName)"
                + (grouped ? "" : ", bỏ dấu nhóm")
        case let .trim(collapseInner):
            return collapseInner
                ? "Cắt và nén khoảng trắng cột «\(columnName)»"
                : "Cắt khoảng trắng cột «\(columnName)»"
        case let .changeCase(letterCase):
            return "Đổi cột «\(columnName)» sang \(letterCase.displayName)"
        case let .fillWithValue(value):
            return "Điền «\(value)» vào ô thiếu cột «\(columnName)»"
        case let .fill(direction):
            return "Điền ô thiếu cột «\(columnName)» — \(direction.displayName)"
        case .deleteRowsWithNull:
            return "Xóa hàng thiếu dữ liệu ở cột «\(columnName)»"
        }
    }
}

/// Kết quả chạy một bước: sửa Ô hay xóa HÀNG.
///
/// Hai thứ khác nhau thật sự nên không gộp làm một: xóa hàng không có "trước → sau" để xem, và
/// gộp lại sẽ đẻ ra một kiểu mà nửa số trường luôn rỗng.
public enum CSVCleanOutcome: Equatable {
    case cells(CSVClean.Plan)
    case rows(CSVClean.RowPlan)

    public var edits: [TextEdit] {
        switch self {
        case let .cells(plan): return plan.edits
        case let .rows(plan): return plan.edits
        }
    }

    public var summary: String {
        switch self {
        case let .cells(plan): return plan.report.summary
        case let .rows(plan): return plan.summary
        }
    }

    /// Bảng "trước → sau" cho sheet xem trước; rỗng với bước xóa hàng.
    public var samples: [CSVClean.Sample] {
        switch self {
        case let .cells(plan): return plan.samples
        case .rows: return []
        }
    }

    /// Số ô không suy luận được — chúng được để nguyên và đánh dấu, không bị đoán.
    public var unparsable: [CSVClean.CellRef] {
        switch self {
        case let .cells(plan): return plan.report.unparsable
        case .rows: return []
        }
    }

    public var isEmpty: Bool { edits.isEmpty }
}

extension CSVCleanStep {

    /// Chạy bước và trả về KẾ HOẠCH — không đụng vào buffer.
    ///
    /// - Parameter maxRows: 0 = cả tài liệu; số dương = bản xem trước. Với bản xem trước của
    ///   bước xóa hàng, `edits` không phải thứ để áp (xem `CSVClean.deleteRowsWithNull`).
    public func run(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> CSVCleanOutcome {
        switch kind {
        case let .normalizeDates(order):
            return .cells(try CSVClean.normalizeDates(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                order: order, maxRows: maxRows, cancelToken: cancelToken
            ))
        case let .normalizeNumbers(style, source, grouped):
            return .cells(try CSVClean.normalizeNumbers(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                to: style, sourceStyle: source, grouped: grouped,
                maxRows: maxRows, cancelToken: cancelToken
            ))
        case let .trim(collapseInner):
            return .cells(try CSVClean.trimCells(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                collapseInner: collapseInner, maxRows: maxRows, cancelToken: cancelToken
            ))
        case let .changeCase(letterCase):
            return .cells(try CSVClean.changeCase(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                to: letterCase, maxRows: maxRows, cancelToken: cancelToken
            ))
        case let .fillWithValue(value):
            return .cells(try CSVClean.fillNulls(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                with: value, spec: spec, maxRows: maxRows, cancelToken: cancelToken
            ))
        case let .fill(direction):
            return .cells(try CSVClean.fillNulls(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                direction: direction, spec: spec, maxRows: maxRows, cancelToken: cancelToken
            ))
        case .deleteRowsWithNull:
            return .rows(try CSVClean.deleteRowsWithNull(
                column: column, in: buffer, dialect: dialect, hasHeader: hasHeader,
                spec: spec, maxRows: maxRows, cancelToken: cancelToken
            ))
        }
    }
}
