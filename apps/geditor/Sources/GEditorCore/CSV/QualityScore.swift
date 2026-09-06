import Foundation

/// Điểm chất lượng sáu chiều — FR-DQR-002.
///
/// Đây là chỗ cụm FR-DQR khác hẳn Data Profile (FR-CLN-003): Profile MÔ TẢ (*"cột này 2% null"*),
/// còn điểm số PHÁN XÉT (*"2% null có đạt chuẩn tôi khai không"*). Một con số 0–100 mà người ta
/// dán lên báo cáo, nên nó phải chịu được câu hỏi *"con số này ở đâu ra"*.
///
/// ## Ba tính chất NFR-DQR-03 đòi, và cách giữ chúng
///
/// **1. Công thức in trong kết quả.** Mỗi chiều mang theo `formula` — chuỗi công thức thật, không
/// phải mô tả. Người đọc báo cáo phải tính lại được bằng tay từ `detail`.
///
/// **2. Tất định bit-by-bit.** Cùng dữ liệu + cùng luật → cùng điểm. Có đúng MỘT chỗ phá được
/// tính chất này, và đặc tả không nhắc tới: **TIMELINESS so dữ liệu với "bây giờ"**. Nên "bây
/// giờ" là **tham số đầu vào** (`now:`), mặc định là thời điểm chạy, và **được ghi vào kết quả**.
/// Cùng khuôn "seed ghi kèm trong mọi kết quả" mà NFR-MIN-02 đòi cho khai phá dữ liệu: thứ gì
/// không tất định thì phải hiện ra thành một giá trị đọc được, không giấu trong lời gọi.
///
/// **3. Không heuristic ẩn.** Chiều nào KHÔNG chấm được thì trả `nil` và nói lý do — nó bị loại
/// khỏi trung bình có trọng số, **không** được âm thầm tính là 100. Một bảng dữ liệu chưa khai
/// `uniqueness_key` mà được cho 100 điểm "không trùng" là một điểm số nói dối, và nó nói dối theo
/// hướng có lợi — đúng hướng nguy hiểm.
public struct QualityScore: Equatable, Sendable {

    public struct DimensionScore: Equatable, Sendable {
        public var dimension: QualityRules.Dimension
        /// 0–100. `nil` khi không chấm được — xem `note`.
        public var value: Double?
        /// Công thức THẬT, để người đọc tính lại được.
        public var formula: String
        /// Các con số đi vào công thức.
        public var detail: String
        /// Vì sao không chấm được, khi `value == nil`.
        public var note: String?
        public var weight: Double

        public init(
            dimension: QualityRules.Dimension, value: Double?, formula: String,
            detail: String, note: String? = nil, weight: Double
        ) {
            self.dimension = dimension
            self.value = value
            self.formula = formula
            self.detail = detail
            self.note = note
            self.weight = weight
        }
    }

    /// Tỷ lệ ô rỗng của MỘT cột.
    ///
    /// Có mặt vì FR-DQR-004 đòi snapshot lịch sử ghi *"%null từng cột"* — và con số ấy đã được
    /// tính sẵn trong lượt quét của chiều COMPLETENESS. Chạy thêm một lượt nữa để lấy lại thứ
    /// vừa đếm xong là trả hai lần cho một câu trả lời.
    public struct ColumnNulls: Equatable, Sendable {
        public var column: String
        public var nullCount: Int
        public var percent: Double

        public init(column: String, nullCount: Int, percent: Double) {
            self.column = column
            self.nullCount = nullCount
            self.percent = percent
        }
    }

    public var dimensions: [DimensionScore]
    public var rowCount: Int
    /// Theo THỨ TỰ CỘT của bảng, không sắp lại: hai snapshot cạnh nhau phải so được từng dòng.
    public var columnNulls: [ColumnNulls]
    /// Thời điểm dùng để tính TIMELINESS — ghi lại để chạy lại cho ra cùng điểm.
    public var evaluatedAt: Date

    /// Trung bình có trọng số của những chiều CHẤM ĐƯỢC. `nil` khi không chiều nào chấm được.
    public var total: Double? {
        let scored = dimensions.compactMap { score -> (Double, Double)? in
            guard let value = score.value else { return nil }
            return (value, score.weight)
        }
        let weight = scored.reduce(0) { $0 + $1.1 }
        guard weight > 0 else { return nil }
        return scored.reduce(0) { $0 + $1.0 * $1.1 } / weight
    }

    /// Những chiều bị loại khỏi điểm tổng — phải hiện ra cạnh điểm, không nằm trong chú thích.
    public var unscored: [DimensionScore] { dimensions.filter { $0.value == nil } }

    public init(
        dimensions: [DimensionScore], rowCount: Int,
        columnNulls: [ColumnNulls] = [], evaluatedAt: Date
    ) {
        self.dimensions = dimensions
        self.rowCount = rowCount
        self.columnNulls = columnNulls
        self.evaluatedAt = evaluatedAt
    }
}

public enum QualityScorer {

    /// Ngưỡng outlier MAD cho chiều ACCURACY-PROXY.
    ///
    /// `|x − trung vị| > 3 × 1,4826 × MAD`. Hằng số 1,4826 đưa MAD về cùng thang với độ lệch
    /// chuẩn của phân bố chuẩn, nên ngưỡng 3 ở đây đọc được như "3 sigma" quen thuộc.
    ///
    /// Đặc tả nói *"tái dùng đúng thuật toán FR-MIN-001"*. Khi tệp này được viết, FR-MIN-001
    /// chưa có mã, nên công thức ra đời ở đây — kèm lời hứa rằng FR-MIN-001 sẽ dùng LẠI đúng
    /// hằng số chứ không viết bản thứ hai.
    ///
    /// **Nợ ấy đã trả 26/08/2026:** hằng số nay sống ở `AnomalyDetector`, và chỗ này chỉ trỏ
    /// tới. Hai bản hiện thực của cùng một công thức là hai con số khác nhau cho cùng một dữ
    /// liệu, và người dùng sẽ thấy chiều ACCURACY nói khác bảng bất thường.
    public static var madSigmaFactor: Double { AnomalyDetector.madSigmaFactor }
    public static let madThreshold = 3.0

    public static func score(
        _ report: QualityEngine.Report,
        rules: QualityRules,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        now: Date = Date(),
        cancelToken: CancelToken = CancelToken()
    ) throws -> QualityScore {
        let rowCount = report.rowCount
        var dimensions: [QualityScore.DimensionScore] = []

        func weight(_ dimension: QualityRules.Dimension) -> Double {
            rules.weights[dimension] ?? 1
        }

        // --- 1. COMPLETENESS = 1 − tỷ lệ null, tính trên MỌI cột -------------------------
        let filled = try completeness(
            rules: rules, buffer: buffer, dialect: dialect, sourcePath: sourcePath,
            rowCount: rowCount, cancelToken: cancelToken, weight: weight(.completeness))
        dimensions.append(filled.score)

        // --- 2. VALIDITY và 4. CONSISTENCY = tỷ lệ pass của luật -------------------------
        dimensions.append(rulePassRate(
            report, dimension: .validity, weight: weight(.validity),
            emptyNote: "chưa khai luật định dạng nào (dtype · range · length · regex · in_set · date_format)"))
        dimensions.append(rulePassRate(
            report, dimension: .consistency, weight: weight(.consistency),
            emptyNote: "chưa khai luật liên cột hay liên file nào (expr · compare · foreign_key)"))

        // --- 3. UNIQUENESS = 1 − tỷ lệ bản ghi trùng trên KHOÁ KHAI BÁO ------------------
        dimensions.append(try uniqueness(
            rules: rules, buffer: buffer, dialect: dialect, sourcePath: sourcePath,
            rowCount: rowCount, cancelToken: cancelToken, weight: weight(.uniqueness)))

        // --- 5. ACCURACY-PROXY = 1 − tỷ lệ outlier MAD -----------------------------------
        dimensions.append(try accuracy(
            rules: rules, buffer: buffer, dialect: dialect, sourcePath: sourcePath,
            cancelToken: cancelToken, weight: weight(.accuracy)))

        // --- 6. TIMELINESS = tuổi dữ liệu so ngưỡng --------------------------------------
        dimensions.append(try timeliness(
            rules: rules, buffer: buffer, dialect: dialect, sourcePath: sourcePath,
            now: now, cancelToken: cancelToken, weight: weight(.timeliness)))

        return QualityScore(
            dimensions: dimensions, rowCount: rowCount, columnNulls: filled.columns,
            evaluatedAt: now)
    }

    // MARK: - Từng chiều

    private static func completeness(
        rules: QualityRules, buffer: TextBuffer, dialect: CSVDialect, sourcePath: String?,
        rowCount: Int, cancelToken: CancelToken, weight: Double
    ) throws -> (score: QualityScore.DimensionScore, columns: [QualityScore.ColumnNulls]) {
        let formula = "100 × (1 − số ô rỗng / tổng số ô)"
        guard rowCount > 0 else {
            return (.init(dimension: .completeness, value: nil, formula: formula,
                          detail: "bảng rỗng", note: "không có hàng nào để chấm",
                          weight: weight), [])
        }
        let columns = try columnNames(buffer: buffer, dialect: dialect,
                                      sourcePath: sourcePath, cancelToken: cancelToken)
        guard !columns.isEmpty else {
            return (.init(dimension: .completeness, value: nil, formula: formula,
                          detail: "không đọc được tên cột", note: "không đọc được tên cột",
                          weight: weight), [])
        }
        // `COUNT(col)` bỏ qua NULL, nên tổng của chúng là số ô CÓ giá trị — một lượt quét cho
        // mọi cột, cùng lý do gom luật của `QualityEngine`.
        let projections = columns
            .map { "COUNT(\(QualityEngine.quoteIdentifier($0)))" }
            .joined(separator: ", ")
        let table = try CSVQueryEngine.run(
            "SELECT \(projections) FROM \(CSVQueryEngine.tableName)",
            in: buffer, dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken)
        guard let row = table.rows.first else {
            return (.init(dimension: .completeness, value: nil, formula: formula,
                          detail: "không đọc được kết quả", note: "không đọc được kết quả",
                          weight: weight), [])
        }
        let counts = row.map { $0.flatMap(Int.init) }
        let filled = counts.compactMap { $0 }.reduce(0, +)
        let cells = rowCount * columns.count
        let value = cells > 0 ? Double(filled) / Double(cells) * 100 : 0
        // %null từng cột đi kèm luôn — FR-DQR-004 cần nó cho snapshot lịch sử, và nó đã nằm
        // trong đúng hàng kết quả vừa đọc.
        let perColumn = columns.enumerated().compactMap {
            index, name -> QualityScore.ColumnNulls? in
            guard index < counts.count, let present = counts[index] else { return nil }
            let missing = max(0, rowCount - present)
            return QualityScore.ColumnNulls(
                column: name, nullCount: missing,
                percent: Double(missing) / Double(rowCount) * 100)
        }
        return (.init(
            dimension: .completeness, value: value, formula: formula,
            detail: "\(cells - filled) ô rỗng / \(cells) ô (\(columns.count) cột × \(rowCount) hàng)",
            weight: weight), perColumn)
    }

    /// VALIDITY và CONSISTENCY — **tỷ lệ pass của LUẬT**, đúng nguyên văn đặc tả.
    ///
    /// Đặc tả viết *"tỷ lệ pass của các rule định dạng/dtype/range/regex"*, tức đếm theo LUẬT,
    /// trong khi bốn chiều còn lại đếm theo HÀNG. Chênh nhau rất lớn: một luật hỏng ở đúng một
    /// hàng trên một triệu vẫn kéo VALIDITY từ 100 xuống 0 nếu đó là luật định dạng duy nhất.
    ///
    /// Làm đúng câu chữ, và in **cả hai con số** vào `detail` để người đọc thấy ngay chuyện gì
    /// đang xảy ra. Nếu anh muốn đổi sang đếm theo hàng thì đó là một dòng ở đây — nhưng nó là
    /// quyết định về ý nghĩa của điểm số, không phải chi tiết hiện thực.
    private static func rulePassRate(
        _ report: QualityEngine.Report, dimension: QualityRules.Dimension,
        weight: Double, emptyNote: String
    ) -> QualityScore.DimensionScore {
        let formula = "100 × (số luật ĐẠT / tổng số luật thuộc chiều này)"
        let relevant = report.results.filter { $0.rule.dimension == dimension }
        guard !relevant.isEmpty else {
            return .init(dimension: dimension, value: nil, formula: formula,
                         detail: "0 luật", note: emptyNote, weight: weight)
        }
        let passed = relevant.filter(\.passed).count
        let violatingRows = relevant.filter { $0.violations > 0 }.map(\.violations).max() ?? 0
        return .init(
            dimension: dimension,
            value: Double(passed) / Double(relevant.count) * 100,
            formula: formula,
            detail: "\(passed)/\(relevant.count) luật đạt"
                + (violatingRows > 0 ? " · luật hỏng nhiều nhất: \(violatingRows) hàng" : ""),
            weight: weight)
    }

    private static func uniqueness(
        rules: QualityRules, buffer: TextBuffer, dialect: CSVDialect, sourcePath: String?,
        rowCount: Int, cancelToken: CancelToken, weight: Double
    ) throws -> QualityScore.DimensionScore {
        let formula = "100 × (1 − số bản ghi trùng / tổng số hàng)"
        guard !rules.uniquenessKey.isEmpty else {
            return .init(
                dimension: .uniqueness, value: nil, formula: formula, detail: "chưa khai khoá",
                note: "chưa khai `uniqueness_key` trong tệp quy tắc — không có khoá thì không "
                    + "biết thế nào là 'trùng'. Chiều này bị LOẠI khỏi điểm tổng, không được "
                    + "tính là 100.",
                weight: weight)
        }
        guard rowCount > 0 else {
            return .init(dimension: .uniqueness, value: nil, formula: formula,
                         detail: "bảng rỗng", note: "không có hàng nào để chấm", weight: weight)
        }
        let key = rules.uniquenessKey.map(QualityEngine.quoteIdentifier).joined(separator: ", ")
        let table = try CSVQueryEngine.run(
            "SELECT COUNT(*), COUNT(DISTINCT (\(key))) FROM \(CSVQueryEngine.tableName)",
            in: buffer, dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken)
        guard let row = table.rows.first, row.count >= 2,
              let total = row[0].flatMap(Int.init), let distinct = row[1].flatMap(Int.init)
        else {
            return .init(dimension: .uniqueness, value: nil, formula: formula,
                         detail: "không đọc được kết quả",
                         note: "không đọc được kết quả", weight: weight)
        }
        let duplicates = max(0, total - distinct)
        return .init(
            dimension: .uniqueness,
            value: total > 0 ? Double(total - duplicates) / Double(total) * 100 : 0,
            formula: formula,
            detail: "\(duplicates) bản ghi trùng / \(total) hàng · khoá: "
                + rules.uniquenessKey.joined(separator: " + "),
            weight: weight)
    }

    private static func accuracy(
        rules: QualityRules, buffer: TextBuffer, dialect: CSVDialect, sourcePath: String?,
        cancelToken: CancelToken, weight: Double
    ) throws -> QualityScore.DimensionScore {
        let formula = "100 × (1 − số ô outlier / số ô có giá trị) · "
            + "outlier khi |x − trung vị| > \(format(madThreshold)) × "
            + "\(format(madSigmaFactor)) × MAD"
        guard !rules.accuracyColumns.isEmpty else {
            return .init(
                dimension: .accuracy, value: nil, formula: formula, detail: "chưa khai cột",
                note: "chưa khai `accuracy_columns` — chiều này chỉ có nghĩa trên cột SỐ mà "
                    + "người dùng chỉ định, vì 'bất thường' phụ thuộc vào cột ấy đo cái gì. "
                    + "Bị LOẠI khỏi điểm tổng.",
                weight: weight)
        }
        var outliers = 0
        var checked = 0
        var perColumn: [String] = []
        for column in rules.accuracyColumns {
            try cancelToken.check()
            let quoted = QualityEngine.quoteIdentifier(column)
            // Trung vị rồi MAD rồi đếm — ba tầng, một câu, một lượt quét mỗi tầng của DuckDB.
            //
            // `mad > 0` là điều kiện BẮT BUỘC: cột mà mọi giá trị bằng nhau có MAD = 0, và khi
            // ấy mọi lệch khác 0 đều "vượt ngưỡng" — cột hằng số sẽ bị chấm 0 điểm chính xác.
            // Không đo được độ phân tán thì không kết luận, chứ không kết luận xấu.
            let sql = """
                WITH v AS (
                  SELECT TRY_CAST(\(quoted) AS DOUBLE) AS x
                  FROM \(CSVQueryEngine.tableName)
                  WHERE \(quoted) IS NOT NULL AND TRY_CAST(\(quoted) AS DOUBLE) IS NOT NULL),
                m AS (SELECT median(x) AS med FROM v),
                d AS (SELECT median(abs(v.x - m.med)) AS mad FROM v, m)
                SELECT
                  COUNT(*),
                  COUNT(*) FILTER (
                    WHERE d.mad > 0
                      AND abs(v.x - m.med) > \(format(madThreshold)) * \
                          \(format(madSigmaFactor)) * d.mad)
                FROM v, m, d
                """
            let table = try CSVQueryEngine.run(
                sql, in: buffer, dialect: dialect, sourcePath: sourcePath,
                cancelToken: cancelToken)
            guard let row = table.rows.first, row.count >= 2,
                  let total = row[0].flatMap(Int.init), let bad = row[1].flatMap(Int.init)
            else { continue }
            checked += total
            outliers += bad
            perColumn.append("\(column): \(bad)/\(total)")
        }
        guard checked > 0 else {
            return .init(
                dimension: .accuracy, value: nil, formula: formula,
                detail: rules.accuracyColumns.joined(separator: ", "),
                note: "không cột nào khai trong `accuracy_columns` có giá trị SỐ đọc được",
                weight: weight)
        }
        return .init(
            dimension: .accuracy,
            value: Double(checked - outliers) / Double(checked) * 100,
            formula: formula,
            detail: "\(outliers) ô bất thường / \(checked) ô · "
                + perColumn.joined(separator: " · "),
            weight: weight)
    }

    private static func timeliness(
        rules: QualityRules, buffer: TextBuffer, dialect: CSVDialect, sourcePath: String?,
        now: Date, cancelToken: CancelToken, weight: Double
    ) throws -> QualityScore.DimensionScore {
        let formula = "100 khi tuổi ≤ ngưỡng; giảm tuyến tính về 0 khi tuổi đạt 2× ngưỡng"
        guard let freshness = rules.freshness else {
            return .init(
                dimension: .timeliness, value: nil, formula: formula, detail: "chưa khai",
                note: "chưa khai `freshness` (cột thời gian + `max_age_days`). Bị LOẠI khỏi "
                    + "điểm tổng.",
                weight: weight)
        }
        let quoted = QualityEngine.quoteIdentifier(freshness.column)
        let table = try CSVQueryEngine.run(
            "SELECT max(TRY_CAST(\(quoted) AS TIMESTAMP)) FROM \(CSVQueryEngine.tableName)",
            in: buffer, dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken)
        guard let text = table.rows.first?.first ?? nil,
              let newest = parseTimestamp(text)
        else {
            return .init(
                dimension: .timeliness, value: nil, formula: formula,
                detail: "cột «\(freshness.column)»",
                note: "không đọc được mốc thời gian nào từ cột «\(freshness.column)» — "
                    + "cột có tồn tại không, và có đúng là cột thời gian không?",
                weight: weight)
        }
        let ageDays = now.timeIntervalSince(newest) / 86_400
        // Giảm TUYẾN TÍNH thay vì rơi thẳng xuống 0 khi quá hạn: một bộ dữ liệu trễ một ngày và
        // một bộ trễ một năm không nên cùng điểm, và một mốc cứng khiến điểm số nhảy giật quanh
        // đúng cái ngưỡng người dùng đang cân nhắc. Đặc tả không định nghĩa hàm giảm; chỗ này
        // chọn hàm đơn giản nhất giải thích được, và in nó ra trong `formula`.
        let ratio = ageDays <= freshness.maxAgeDays
            ? 1.0
            : max(0, 2 - ageDays / freshness.maxAgeDays)
        return .init(
            dimension: .timeliness, value: ratio * 100, formula: formula,
            detail: "mốc mới nhất \(iso(newest)) · tuổi \(format(ageDays)) ngày · "
                + "ngưỡng \(format(freshness.maxAgeDays)) ngày · tính theo mốc \(iso(now))",
            weight: weight)
    }

    // MARK: - Mảnh

    private static func columnNames(
        buffer: TextBuffer, dialect: CSVDialect, sourcePath: String?, cancelToken: CancelToken
    ) throws -> [String] {
        try CSVQueryEngine.run(
            "SELECT * FROM \(CSVQueryEngine.tableName) LIMIT 0",
            in: buffer, dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken).titles
    }

    private static func parseTimestamp(_ text: String) -> Date? {
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int(value)) : String(format: "%g", value)
    }
}
