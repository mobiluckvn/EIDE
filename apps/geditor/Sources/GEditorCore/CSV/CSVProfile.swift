import Foundation

/// Hồ sơ của MỘT cột (FR-CLN-003).
///
/// Mọi con số ở đây phải kèm được một câu giải thích. Người dùng nhìn "distinct: 63" rồi ra
/// quyết định về dữ liệu của họ; con số nào là ƯỚC LƯỢNG thì phải nói ra là ước lượng, chứ
/// không trộn lẫn với con số đếm thật.
public struct CSVColumnProfile: Equatable, Sendable {

    public let column: Int
    public let name: String
    /// Kiểu suy ra từ chính dữ liệu, cùng thang với `CSVValidator`.
    public let type: CSVValueType

    public let rows: Int
    public let nullCells: Int
    /// Ô đọc được theo đúng kiểu của cột — mẫu số của mọi thống kê số học bên dưới.
    public let typedCells: Int

    /// Số giá trị THẬT khác nhau — ô thiếu không tính, vì "N/A" là chỗ trống chứ không phải
    /// một giá trị. `distinctExact == false` nghĩa là đã tràn ngưỡng đếm và con số này là CẬN
    /// DƯỚI, không phải câu trả lời.
    public let distinct: Int
    public let distinctExact: Bool

    /// Vài giá trị hay gặp nhất kèm số lần, đếm CHÍNH XÁC.
    ///
    /// Rỗng khi cột vượt ngưỡng distinct: với cột gần-như-duy-nhất thì "hay gặp" vốn không có
    /// nghĩa, và một danh sách dở dang sẽ thiên vị những giá trị đến sớm. `topExact` nói ra
    /// khác biệt giữa "cột này không có giá trị nào lặp" và "đã bỏ đếm".
    public let topValues: [(value: String, count: Int)]
    public let topExact: Bool

    /// Nhỏ nhất / lớn nhất theo THỨ TỰ CỦA KIỂU: số so bằng giá trị, ngày so trên dạng ISO,
    /// chuỗi so theo thứ tự BYTE. So chuỗi cho cột số sẽ cho "9" > "10", và đó là loại sai mà
    /// người đọc báo cáo không tài nào phát hiện.
    ///
    /// Thứ tự byte không phải thứ tự chữ cái tiếng Việt — nó xếp "Huế" trước "Đà Nẵng". Với
    /// cột mã (`A1…A99`) thì vẫn đúng thứ tự người ta mong; với cột chữ tiếng Việt thì đây là
    /// một khoảng-giá-trị, không phải một phép sắp xếp. Báo cáo nói rõ điều đó ra.
    public let minimum: String?
    public let maximum: String?

    /// Chỉ cột số. Tính bằng Welford một lượt — cộng dồn thẳng rồi chia sẽ mất chữ số nghĩa
    /// ngay khi tổng vượt quá thang của từng giá trị.
    public let mean: Double?
    public let standardDeviation: Double?

    /// Giá trị bất thường theo |z| > 3, kèm điểm z để giải thích được.
    ///
    /// Dùng z-score vì nó tính được trong CÙNG một lượt quét. Sổ tay thuật toán §1.1 nói rõ
    /// gót chân của nó: chính outlier kéo lệch mean và σ, nên phân bố lệch phải dùng MAD hay
    /// IQR — cả hai đều cần tứ phân vị, tức là một lượt quét thứ hai hoặc một bản tóm tắt
    /// phân vị. Chưa làm, và hồ sơ phải NÓI RA rằng nó đang dùng thước nào.
    public let outliers: [CSVClean.CellRef]

    public static func == (lhs: CSVColumnProfile, rhs: CSVColumnProfile) -> Bool {
        lhs.column == rhs.column && lhs.name == rhs.name && lhs.type == rhs.type
            && lhs.rows == rhs.rows && lhs.nullCells == rhs.nullCells
            && lhs.typedCells == rhs.typedCells && lhs.distinct == rhs.distinct
            && lhs.distinctExact == rhs.distinctExact && lhs.topExact == rhs.topExact
            && lhs.topValues.map(\.value) == rhs.topValues.map(\.value)
            && lhs.topValues.map(\.count) == rhs.topValues.map(\.count)
            && lhs.minimum == rhs.minimum && lhs.maximum == rhs.maximum
            && lhs.mean == rhs.mean && lhs.standardDeviation == rhs.standardDeviation
            && lhs.outliers == rhs.outliers
    }

    /// Tỉ lệ ô thiếu, dạng phần trăm.
    public var nullPercent: Double {
        rows > 0 ? Double(nullCells) * 100 / Double(rows) : 0
    }

    /// Một dòng tóm tắt đọc được thành lời.
    public var summary: String {
        var parts = [type.displayName]
        parts.append(String(format: "null %.1f%%", nullPercent))
        parts.append(distinctExact ? "\(distinct) distinct" : "hơn \(distinct) distinct")
        if let mean {
            parts.append(String(format: "trung bình %.4g", mean))
        }
        if let minimum, let maximum {
            parts.append("từ \(minimum) tới \(maximum)")
        }
        if !outliers.isEmpty {
            parts.append("\(outliers.count) giá trị bất thường")
        }
        return parts.joined(separator: " · ")
    }
}

/// Hồ sơ toàn bảng (FR-CLN-003).
public struct CSVProfileReport: Equatable, Sendable {
    public let columns: [CSVColumnProfile]
    public let rowsScanned: Int
    public let partial: Bool
    /// Thời gian quét, giây — đưa thẳng vào báo cáo như hình 6.2 ("Data Profile · 1,2 s").
    public let seconds: Double
}

/// Hồ sơ dữ liệu chạy trong MỘT lượt quét (FR-CLN-003).
///
/// Không có DuckDB ở đây, dù SRS mô tả năng lực này "chạy DuckDB". Những gì hồ sơ cần —
/// kiểu, tỉ lệ null, distinct, min/max/mean, giá trị hay gặp, giá trị bất thường — đều tính
/// được trong một lượt bằng các thuật toán cổ điển vài chục dòng, và đó đúng là nguyên tắc
/// "tự cài đặt trong lõi, không dependency" mà Sổ tay thuật toán đặt ra. DuckDB vẫn sẽ cần cho
/// FR-QRY (SQL thật, join nhiều file); hồ sơ không phải lý do để kéo nó vào sớm.
///
/// Đọc thẳng trên BYTE của cửa sổ, không dựng `String` cho mỗi ô: chuỗi chỉ được tạo cho những
/// giá trị thật sự phải giữ lại (bảng đếm top, mẫu bất thường). Đây là chỗ nửa thời gian của
/// bộ quét cũ nằm ở đó.
public enum CSVProfiler {

    /// Ngưỡng đếm distinct chính xác cho mỗi cột.
    ///
    /// Trên ngưỡng này thì bảng băm bị bỏ và con số trở thành CẬN DƯỚI. Cách khác là ước lượng
    /// bằng HyperLogLog, nhưng một con số ước lượng đứng cạnh những con số đếm thật mà không
    /// ai nói cho biết thì tệ hơn một cận dưới trung thực. Cột phân loại — thứ mà người ta
    /// thật sự muốn biết distinct — hầu như luôn nằm dưới ngưỡng này.
    public static let distinctLimit = 10_000

    /// Số mẫu bất thường giữ lại cho mỗi cột.
    public static let outlierSamples = 10

    public static func profile(
        in buffer: TextBuffer,
        dialect: CSVDialect,
        hasHeader: Bool = true,
        spec: CSVNullSpec = .default,
        maxRows: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> CSVProfileReport {
        let started = DispatchTime.now().uptimeNanoseconds

        var names: [String] = []
        var stats: [ColumnStats] = []
        var rowNumber = 0
        var dataRows = 0
        var partial = false

        // --- lượt một: gom thống kê ------------------------------------------------------
        try CSVEngine.forEachWindow(
            in: buffer, dialect: dialect, cancelToken: cancelToken
        ) { rows, bytes, base in
            for row in rows {
                defer { rowNumber += 1 }

                while stats.count < row.count {
                    stats.append(ColumnStats())
                    names.append("cột \(names.count + 1)")
                }

                if hasHeader, rowNumber == 0 {
                    for (index, field) in row.enumerated() {
                        names[index] = String(
                            decoding: CSVEngine.unescape(Array(bytes[field.range]), dialect: dialect),
                            as: UTF8.self
                        )
                    }
                    continue
                }

                for (column, field) in row.enumerated() {
                    stats[column].record(
                        bytes: bytes, range: field.range, quoted: field.isQuoted,
                        dialect: dialect, spec: spec,
                        rowIndex: rowNumber, column: column, base: base
                    )
                }

                dataRows += 1
                if maxRows > 0, dataRows >= maxRows { partial = true; return false }
            }
            return true
        }

        // --- lượt hai: chỉ trên những ô ĐÃ GIỮ LẠI, để chấm điểm bất thường ---------------
        //
        // Không quét lại tài liệu: điểm z cần mean và σ của CẢ cột, mà hai thứ ấy chỉ biết
        // được khi lượt một kết thúc. Nên lượt một giữ sẵn một ít ô cực trị của mỗi cột, và
        // ở đây chỉ chấm điểm ngần ấy ô.
        let columns = stats.enumerated().map { column, stat in
            stat.finish(column: column, name: column < names.count ? names[column] : "cột \(column + 1)")
        }

        let seconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9
        return CSVProfileReport(
            columns: columns, rowsScanned: dataRows, partial: partial, seconds: seconds
        )
    }
}
