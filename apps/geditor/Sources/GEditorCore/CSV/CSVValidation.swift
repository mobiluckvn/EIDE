import Foundation

/// Kiểu dữ liệu SUY LUẬN ĐƯỢC của một cột (FR-CSV-405).
public enum CSVValueType: Equatable, Sendable {
    case number
    case date(CSVDateFormat)
    /// Không suy ra được kiểu nào — cột này không kiểm kiểu, và không báo lỗi kiểu bao giờ.
    case text

    public var displayName: String {
        switch self {
        case .number: return "số"
        case let .date(format): return "ngày (\(format.displayName))"
        case .text: return "chuỗi"
        }
    }
}

/// Các dạng ngày nhận biết được.
///
/// Chỉ ba dạng, và đều là dạng KHÔNG NHẬP NHẰNG một khi đã chốt theo cả cột. Cố nhận thêm
/// `MM/DD/YYYY` sẽ biến "03/04/2026" thành hai cách đọc khác nhau, và đoán sai ở đây nghĩa là
/// báo lỗi cho những ô hoàn toàn đúng — thứ khiến người dùng tắt hẳn tính năng kiểm tra.
public enum CSVDateFormat: String, Equatable, Sendable {
    case iso              // 2026-08-19
    case dayFirstSlash    // 19/08/2026
    case dayFirstDash     // 19-08-2026

    public var displayName: String {
        switch self {
        case .iso: return "YYYY-MM-DD"
        case .dayFirstSlash: return "DD/MM/YYYY"
        case .dayFirstDash: return "DD-MM-YYYY"
        }
    }
}

/// Một lỗi tìm thấy khi kiểm tra (FR-CSV-405).
public struct CSVIssue: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        case columnCount(expected: Int, actual: Int)
        case wrongType(column: Int, expected: CSVValueType, value: String)
    }

    /// Số hàng LOGIC, đếm từ 0 — cùng hệ với `CSVRowIndex`, để bảng nhảy tới đúng chỗ.
    ///
    /// `CSVOps.RowIssue` đếm từ 1. Hai cách đếm cạnh nhau là cái bẫy, nên tên ở đây khác hẳn
    /// (`rowIndex`, không phải `row`) và chỗ nào hiển thị ra người dùng thì cộng 1.
    public let rowIndex: Int
    /// Offset byte đầu hàng — đủ để đưa con nháy tới nơi ở chế độ văn bản.
    public let offset: Int
    public let kind: Kind

    public init(rowIndex: Int, offset: Int, kind: Kind) {
        self.rowIndex = rowIndex
        self.offset = offset
        self.kind = kind
    }

    public var description: String {
        switch kind {
        case let .columnCount(expected, actual):
            return "Hàng \(rowIndex + 1): có \(actual) cột, cần \(expected)"
        case let .wrongType(column, expected, value):
            return "Hàng \(rowIndex + 1), cột \(column + 1): «\(value)» không phải \(expected.displayName)"
        }
    }
}

/// Kết quả một lượt kiểm tra.
public struct CSVValidationReport: Equatable, Sendable {
    public let types: [CSVValueType]
    public let issues: [CSVIssue]
    /// Đã chạm trần số lỗi và DỪNG SỚM.
    ///
    /// Phải nói ra: "12 lỗi" và "12 lỗi đầu tiên trong số không biết bao nhiêu" là hai kết
    /// luận khác hẳn nhau, và người dùng sẽ hành động khác nhau.
    public let truncated: Bool
    public let rowsChecked: Int
}

/// Kiểm tra dữ liệu CSV: số cột và kiểu theo cột (FR-CSV-405).
public enum CSVValidator {

    /// Số ô không rỗng tối thiểu để dám kết luận kiểu của một cột.
    ///
    /// Ba ô đều là số thì chưa nói lên gì — một cột mã chứng từ có thể tình cờ bắt đầu bằng ba
    /// dòng toàn số. Dưới ngưỡng này thì cột coi như chuỗi và không bao giờ báo lỗi kiểu.
    public static let minimumSample = 8

    /// Tỉ lệ ô khớp để chốt kiểu.
    ///
    /// KHÔNG phải 100%: nếu đòi mọi ô đều khớp thì một cột một triệu số có ba ô hỏng sẽ bị xếp
    /// là chuỗi và không báo gì cả — mà ba ô ấy chính là thứ cần tìm. Đa số thắng, thiểu số là
    /// lỗi. Đổi lại, cột thật sự lẫn lộn (một nửa số, một nửa chữ) rơi về chuỗi và im lặng,
    /// đúng như nó nên thế.
    public static let typeThreshold = 0.95

    // MARK: - Suy luận kiểu

    /// Đoán kiểu từng cột từ `sampleRows` hàng đầu.
    ///
    /// Đọc mẫu chứ không đọc cả file: với tài liệu một triệu hàng, quét toàn bộ chỉ để biết
    /// "cột này là số" là trả giá gấp nghìn lần cho cùng một câu trả lời. Hệ quả phải nói rõ:
    /// một cột số mà mọi giá trị lạ đều nằm sau hàng thứ `sampleRows` vẫn được nhận đúng kiểu,
    /// còn cột đổi kiểu giữa chừng thì kiểu lấy theo phần đầu.
    public static func inferTypes(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        sampleRows: Int = 1_000,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [CSVValueType] {
        var nonEmpty: [Int] = []
        var numbers: [Int] = []
        var dates: [[CSVDateFormat: Int]] = []
        var rowNumber = 0

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            if hasHeader, rowNumber == 0 { return true }

            while nonEmpty.count < row.count {
                nonEmpty.append(0); numbers.append(0); dates.append([:])
            }
            for (column, field) in row.enumerated() {
                let value = text(of: field, in: buffer, dialect: dialect)
                guard !value.isEmpty else { continue }
                nonEmpty[column] += 1
                if Double(value) != nil { numbers[column] += 1 }
                if let format = dateFormat(of: value) { dates[column][format, default: 0] += 1 }
            }
            return rowNumber < sampleRows + (hasHeader ? 1 : 0) - 1
        }

        return (0 ..< nonEmpty.count).map { column in
            let total = Double(nonEmpty[column])
            guard nonEmpty[column] >= minimumSample else { return .text }
            if Double(numbers[column]) / total >= typeThreshold { return .number }
            if let (format, count) = dates[column].max(by: { $0.value < $1.value }),
               Double(count) / total >= typeThreshold {
                return .date(format)
            }
            return .text
        }
    }

    // MARK: - Kiểm tra

    /// Quét cả tài liệu MỘT lượt, tìm cả hai loại lỗi.
    ///
    /// Một lượt chứ không phải hai: số cột và kiểu dữ liệu đọc cùng một dữ liệu, và với file
    /// một gigabyte thì quét hai lần là trả giá gấp đôi cho cùng một câu trả lời.
    ///
    /// - Parameter limit: dừng sau bấy nhiêu lỗi; 0 = không giới hạn.
    public static func validate(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        types: [CSVValueType]? = nil,
        expectedColumns: Int? = nil,
        limit: Int = 1_000,
        cancelToken: CancelToken = CancelToken()
    ) throws -> CSVValidationReport {
        let columnTypes = try types ?? inferTypes(
            in: buffer, dialect: dialect, hasHeader: hasHeader, cancelToken: cancelToken
        )

        var issues: [CSVIssue] = []
        var expected = expectedColumns
        var rowNumber = 0
        var truncated = false

        try CSVEngine.forEachRow(in: buffer, dialect: dialect, cancelToken: cancelToken) { row in
            defer { rowNumber += 1 }
            let offset = row.first?.range.lowerBound ?? 0

            // Hàng ĐẦU TIÊN định nghĩa số cột chuẩn khi người gọi không nói rõ — kể cả khi nó
            // là hàng tiêu đề, vì tiêu đề chính là chỗ khai báo file có mấy cột.
            if expected == nil { expected = row.count }

            if let expected, row.count != expected {
                issues.append(CSVIssue(
                    rowIndex: rowNumber, offset: offset,
                    kind: .columnCount(expected: expected, actual: row.count)
                ))
                if limit > 0, issues.count >= limit { truncated = true; return false }
            }

            // Hàng tiêu đề không kiểm kiểu: tên cột là chữ, và báo "ten_cot không phải số" ở
            // mọi file có tiêu đề sẽ chôn vùi những lỗi thật.
            guard !(hasHeader && rowNumber == 0) else { return true }

            for (column, field) in row.enumerated() {
                guard column < columnTypes.count else { break }
                let type = columnTypes[column]
                guard type != .text else { continue }
                let value = text(of: field, in: buffer, dialect: dialect)
                // Ô rỗng là THIẾU dữ liệu, không phải SAI kiểu. Gộp hai thứ ấy sẽ làm danh
                // sách lỗi ngập những dòng vô nghĩa với file có ô để trống hợp lệ.
                guard !value.isEmpty, !matches(value, type) else { continue }
                issues.append(CSVIssue(
                    rowIndex: rowNumber, offset: offset,
                    kind: .wrongType(column: column, expected: type, value: value)
                ))
                if limit > 0, issues.count >= limit { truncated = true; return false }
            }
            return true
        }

        return CSVValidationReport(
            types: columnTypes, issues: issues, truncated: truncated, rowsChecked: rowNumber
        )
    }

    // MARK: - Kiểm một giá trị

    public static func matches(_ value: String, _ type: CSVValueType) -> Bool {
        switch type {
        case .number: return Double(value) != nil
        case let .date(format): return dateFormat(of: value) == format
        case .text: return true
        }
    }

    /// Dạng ngày của một giá trị, hoặc `nil` nếu không phải ngày HỢP LỆ.
    ///
    /// Kiểm cả lịch, không chỉ kiểm hình dạng: "31/02/2026" đúng khuôn nhưng không tồn tại, và
    /// đó chính là loại lỗi mà người ta bật tính năng này lên để tìm.
    ///
    /// Tự tách chuỗi thay vì dùng `DateFormatter`: hàm này chạy trên từng ô của cả tài liệu,
    /// và `DateFormatter` tốn hàng chục micro-giây mỗi lần gọi — nhân với một triệu hàng là
    /// hàng chục giây cho một việc mà đọc mười ký tự là xong.
    public static func dateFormat(of value: String) -> CSVDateFormat? {
        let bytes = Array(value.utf8)
        guard bytes.count == 10 else { return nil }

        func digits(_ range: Range<Int>) -> Int? {
            var out = 0
            for index in range {
                let byte = bytes[index]
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                out = out * 10 + Int(byte - 0x30)
            }
            return out
        }

        let separator = bytes[4]
        if separator == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") {
            guard let year = digits(0 ..< 4), let month = digits(5 ..< 7),
                  let day = digits(8 ..< 10), isRealDate(year: year, month: month, day: day)
            else { return nil }
            return .iso
        }

        guard bytes[2] == bytes[5] else { return nil }
        let mark = bytes[2]
        guard mark == UInt8(ascii: "/") || mark == UInt8(ascii: "-") else { return nil }
        guard let day = digits(0 ..< 2), let month = digits(3 ..< 5), let year = digits(6 ..< 10),
              isRealDate(year: year, month: month, day: day) else { return nil }
        return mark == UInt8(ascii: "/") ? .dayFirstSlash : .dayFirstDash
    }

    /// Ngày có thật trên lịch hay không. Dùng chung với `CSVClean.readDate` — hai bản kiểm
    /// cùng một thứ là cách chắc chắn để chúng lệch nhau về sau.
    static func isRealDate(year: Int, month: Int, day: Int) -> Bool {
        guard month >= 1, month <= 12, day >= 1 else { return false }
        let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let lengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return day <= lengths[month - 1]
    }

    private static func text(
        of field: CSVField, in buffer: TextBuffer, dialect: CSVDialect
    ) -> String {
        String(
            decoding: CSVEngine.unescape(buffer.bytes(in: field.range), dialect: dialect),
            as: UTF8.self
        )
    }
}
