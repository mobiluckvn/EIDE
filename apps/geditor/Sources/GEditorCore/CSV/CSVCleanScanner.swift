import Foundation

/// Một phát hiện của Bàn làm sạch (FR-CLN-006).
///
/// Mỗi phát hiện là một CÂU nói được thành lời với người dùng văn phòng: cột nào, chuyện gì,
/// bao nhiêu ô, và nút bấm nào sửa được. Không có mục nào chỉ để trưng ra rằng máy có nhìn.
public struct CSVCleanFinding: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        /// Cột ngày có nhiều hơn một dạng viết.
        case mixedDates(shapes: Int)
        /// Cột số lẫn cả quy ước Việt/Âu và Anh-Mỹ.
        case mixedNumbers
        /// Ô thiếu, đếm theo từng chuỗi đại diện.
        case nulls(byPlaceholder: [String: Int])
        /// Khoảng trắng thừa ở hai đầu ô; `invisible` là số ô có ký tự trắng VÔ HÌNH.
        case untrimmed(invisible: Int)
    }

    public let column: Int
    public let columnName: String
    public let kind: Kind
    /// Số ô phát hiện được — con số mà UI hiện ra và người dùng bấm vào.
    public let cells: Int
    /// Vài ô đầu tiên, đủ để bấm tới xem ngay.
    public let sampleCells: [CSVClean.CellRef]

    /// Dựng tay một phát hiện.
    ///
    /// Có mặt cho FR-DQR-006: bảng chất lượng biết cột nào hỏng theo kiểu gì mà KHÔNG đi qua
    /// `CSVCleanScanner`, và nó cần mở đúng cái sheet mà Bàn làm sạch mở. Dựng một phát hiện ở
    /// đó là cách duy nhất để hai đường vào dùng CHUNG một hộp xem-trước, thay vì đẻ ra một hộp
    /// thứ hai sẽ lệch dần khỏi hộp thứ nhất.
    public init(
        column: Int, columnName: String, kind: Kind, cells: Int,
        sampleCells: [CSVClean.CellRef]
    ) {
        self.column = column
        self.columnName = columnName
        self.kind = kind
        self.cells = cells
        self.sampleCells = sampleCells
    }

    public var title: String {
        switch kind {
        case let .mixedDates(shapes):
            return "Ngày \(shapes) định dạng khác nhau · \(cells) ô"
        case .mixedNumbers:
            return "Số lẫn quy ước Việt/Âu và Anh-Mỹ · \(cells) ô"
        case let .nulls(byPlaceholder):
            let kinds = byPlaceholder
                .sorted { ($0.value, $0.key) > ($1.value, $1.key) }
                .prefix(3)
                .map { $0.key.isEmpty ? "ô rỗng" : "«\($0.key)»" }
                .joined(separator: ", ")
            return "Ô thiếu (\(kinds)) · \(cells) ô"
        case let .untrimmed(invisible):
            let tail = invisible > 0 ? ", \(invisible) ô có ký tự trắng vô hình" : ""
            return "Khoảng trắng thừa\(tail) · \(cells) ô"
        }
    }

    public var actionTitle: String {
        switch kind {
        case .mixedDates: return "Chuẩn hóa ISO…"
        case .mixedNumbers: return "Đổi quy ước…"
        case .nulls: return "Xử lý…"
        case .untrimmed: return "Cắt khoảng trắng…"
        }
    }
}

/// Bộ phát hiện của Bàn làm sạch (FR-CLN-006).
///
/// Quét MỘT lượt cho MỌI cột và mọi phép kiểm. Gọi lần lượt `scanDates`, `scanNumbers`,
/// `scanNulls` cho từng cột thì đúng kết quả nhưng là hai chục lượt nhân bốn phép kiểm trên
/// cùng một file — với bảng một triệu hàng, đó là tám mươi lần đọc để trả lời những câu hỏi mà
/// một lần đọc là đủ (NFR-CLN-01).
///
/// **Số đo, bản release, bảng 1 triệu hàng × 20 cột (20 triệu ô): 9,4–10,2 giây**
/// (`scripts/run-clean-kpi.sh`).
///
/// Con số ấy từng được NGOẠI SUY từ bảng 100k × 10 và ra 17 giây — sai gần hai lần so với phép
/// đo thật (12,1 giây trước khi tối ưu). Chi phí trên mỗi ô không phải hằng số: bảng băm đầy
/// dần, bộ nhớ đệm trượt khác đi. Bài học đủ đắt để ghi lại: **đo ở đúng cỡ, đừng nhân lên.**
///
/// Bộ quét này vẫn dựng `String` cho từng ô, khác với hồ sơ dữ liệu (`CSVProfiler`) đã chuyển
/// hẳn sang đọc byte và nhờ đó nhanh gấp đôi. Chuyển nốt được, nhưng nó chưa vướng chỉ tiêu
/// nào nên chưa đáng đánh đổi độ rõ của mã lấy tốc độ.
public enum CSVCleanScanner {

    /// Thống kê thô của một cột, gom trong lượt quét.
    struct ColumnStats {
        var nonEmpty = 0
        var dateShapes: Set<CSVDateShape> = []
        var dateCells = 0
        var numberCells = 0
        var sawVietnamese = false
        var sawAnglo = false
        var nullsByPlaceholder: [String: Int] = [:]
        var nullCells = 0
        var untrimmed = 0
        var untrimmedInvisible = 0
        var firstNulls: [CSVClean.CellRef] = []
        var firstDates: [CSVClean.CellRef] = []
        var firstNumbers: [CSVClean.CellRef] = []
        var firstUntrimmed: [CSVClean.CellRef] = []
    }

    /// Tỉ lệ ô phải thuộc một kiểu thì mới coi cột là kiểu ấy.
    ///
    /// Cùng ngưỡng và cùng lý do với `CSVValidator.typeThreshold`: đa số thắng, thiểu số là
    /// thứ cần tìm. Cột thật sự lẫn lộn thì không thuộc kiểu nào và Bàn làm sạch im lặng về
    /// nó — đúng như nó nên thế, vì không có thao tác nào áp cho cả cột mà không làm hỏng một
    /// nửa.
    public static let typeThreshold = 0.95

    /// Số ô không rỗng tối thiểu để dám kết luận về một cột.
    public static let minimumSample = 8

    /// Quét tài liệu và trả về danh mục phát hiện, sắp theo số ô giảm dần.
    ///
    /// - Parameter maxRows: 0 = cả tài liệu. Quét mẫu cho ra danh mục NHANH nhưng con số là
    ///   con số của mẫu; chỗ gọi phải nói rõ điều đó ra chứ đừng hiện "89 ô" cho một phép đếm
    ///   dừng ở hàng thứ mười nghìn.
    public static func scan(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [CSVCleanFinding] {
        var names: [String] = []
        var stats: [ColumnStats] = []
        var rowNumber = 0
        var dataRows = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }

            while stats.count < row.count {
                stats.append(ColumnStats())
                names.append("cột \(names.count + 1)")
            }

            if hasHeader, rowNumber == 0 {
                for (index, field) in row.enumerated() {
                    names[index] = value(of: field, in: buffer, dialect: dialect)
                }
                return true
            }

            for (column, field) in row.enumerated() {
                let raw = value(of: field, in: buffer, dialect: dialect)
                record(raw, column: column, rowIndex: rowNumber,
                       offset: field.range.lowerBound, spec: spec, into: &stats[column])
            }

            dataRows += 1
            return maxRows <= 0 || dataRows < maxRows
        }

        return findings(from: stats, names: names, rows: dataRows)
    }

    /// Cập nhật thống kê bằng MỘT ô. Mọi phép kiểm dùng chung một lần đọc chuỗi.
    private static func record(
        _ raw: String, column: Int, rowIndex: Int, offset: Int,
        spec: CSVNullSpec, into stats: inout ColumnStats
    ) {
        func cell() -> CSVClean.CellRef {
            CSVClean.CellRef(rowIndex: rowIndex, column: column, offset: offset, value: raw)
        }

        if spec.isNull(raw) {
            stats.nullCells += 1
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            stats.nullsByPlaceholder[key, default: 0] += 1
            if stats.firstNulls.count < CSVClean.sampleLimit { stats.firstNulls.append(cell()) }
            return
        }
        stats.nonEmpty += 1

        // Khoảng trắng thừa xét TRƯỚC và độc lập với kiểu: một ô ngày có kèm khoảng trắng vẫn
        // là một ô cần cắt.
        let trimmed = CSVClean.trimmed(raw, collapseInner: false)
        if trimmed != raw {
            stats.untrimmed += 1
            if raw.unicodeScalars.contains(where: { $0 != " " && CSVClean.isCleanableSpace($0) }) {
                stats.untrimmedInvisible += 1
            }
            if stats.firstUntrimmed.count < CSVClean.sampleLimit {
                stats.firstUntrimmed.append(cell())
            }
        }

        if let shape = CSVClean.dateShape(of: trimmed) {
            stats.dateCells += 1
            stats.dateShapes.insert(shape)
            if stats.firstDates.count < CSVClean.sampleLimit { stats.firstDates.append(cell()) }
            return
        }

        switch CSVClean.readNumber(trimmed) {
        case let .certain(_, implies):
            stats.numberCells += 1
            switch implies {
            case .vietnamese: stats.sawVietnamese = true
            case .anglo: stats.sawAnglo = true
            case nil: break
            }
            if stats.firstNumbers.count < CSVClean.sampleLimit { stats.firstNumbers.append(cell()) }
        case .needsStyle:
            stats.numberCells += 1
            if stats.firstNumbers.count < CSVClean.sampleLimit { stats.firstNumbers.append(cell()) }
        case .notANumber:
            break
        }
    }

    private static func findings(
        from stats: [ColumnStats], names: [String], rows: Int
    ) -> [CSVCleanFinding] {
        var out: [CSVCleanFinding] = []

        for (column, stat) in stats.enumerated() {
            let name = column < names.count ? names[column] : "cột \(column + 1)"
            let total = Double(stat.nonEmpty)
            let enough = stat.nonEmpty >= minimumSample

            if enough, stat.dateShapes.count > 1,
               Double(stat.dateCells) / total >= typeThreshold {
                out.append(CSVCleanFinding(
                    column: column, columnName: name,
                    kind: .mixedDates(shapes: stat.dateShapes.count),
                    cells: stat.dateCells, sampleCells: stat.firstDates
                ))
            }

            if enough, stat.sawVietnamese, stat.sawAnglo,
               Double(stat.numberCells) / total >= typeThreshold {
                out.append(CSVCleanFinding(
                    column: column, columnName: name, kind: .mixedNumbers,
                    cells: stat.numberCells, sampleCells: stat.firstNumbers
                ))
            }

            if stat.nullCells > 0 {
                out.append(CSVCleanFinding(
                    column: column, columnName: name,
                    kind: .nulls(byPlaceholder: stat.nullsByPlaceholder),
                    cells: stat.nullCells, sampleCells: stat.firstNulls
                ))
            }

            if stat.untrimmed > 0 {
                out.append(CSVCleanFinding(
                    column: column, columnName: name,
                    kind: .untrimmed(invisible: stat.untrimmedInvisible),
                    cells: stat.untrimmed, sampleCells: stat.firstUntrimmed
                ))
            }
        }

        // Nhiều ô hơn thì lên trước: người dùng sửa thứ ảnh hưởng rộng nhất trước, và danh mục
        // dài mà xếp theo thứ tự cột thì mục quan trọng nhất có thể nằm tận cuối.
        return out.sorted { lhs, rhs in
            lhs.cells != rhs.cells ? lhs.cells > rhs.cells : lhs.column < rhs.column
        }
    }

    private static func value(
        of field: CSVField, in buffer: TextBuffer, dialect: CSVDialect
    ) -> String {
        String(
            decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
            as: UTF8.self
        )
    }
}

/// Dạng viết của một ô ngày — dùng để đếm "cột này có mấy định dạng khác nhau".
public enum CSVDateShape: Equatable, Hashable, Sendable {
    case iso              // 2026-07-02
    case slash            // 02/07/2026
    case dash             // 02-07-2026
    case dot              // 02.07.2026
    case monthName        // 5-Jul-26
}

extension CSVClean {

    /// Dạng viết của một ô ngày, hoặc `nil` nếu ô không phải ngày.
    ///
    /// Đi qua đúng `readDate` để hai chỗ không bao giờ bất đồng về "cái gì là ngày": Bàn làm
    /// sạch báo "8.412 ô ngày" mà nút Chuẩn hóa chỉ đổi 8.000 ô thì con số kia thành lời hứa
    /// suông.
    public static func dateShape(of value: String) -> CSVDateShape? {
        guard readDate(value) != .notADate else { return nil }
        if value.contains(where: { $0.isLetter }) { return .monthName }
        if value.contains("/") { return value.hasPrefix("20") || value.hasPrefix("19") ? .iso : .slash }
        if value.contains(".") { return .dot }
        // Còn lại là dấu gạch: ISO nếu năm đứng đầu.
        let head = value.prefix(4)
        return head.count == 4 && head.allSatisfy(\.isNumber) ? .iso : .dash
    }
}
