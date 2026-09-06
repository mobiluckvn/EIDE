import Foundation

/// Chấm dữ liệu theo bộ quy tắc — FR-DQR-001, chạy trên DuckDB (ADR-14).
///
/// ## Một lượt quét cho MỌI luật theo cột
///
/// NFR-DQR-01 đòi *"1 triệu dòng × 50 rule ≤ 15 giây"* và nói rõ cách: *"RuleCompiler gom các
/// rule cùng cột thành ÍT LƯỢT QUÉT nhất có thể"*. Cách hiển nhiên — chạy 50 câu `SELECT
/// COUNT(*) … WHERE …` — là 50 lượt quét, và ở cỡ ấy nó tốn 50 lần thời gian của một lượt.
///
/// Nên bộ biên dịch dịch mỗi luật thành một **biểu thức boolean "hàng này VI PHẠM"**, rồi gộp
/// tất cả vào MỘT câu:
///
/// ```sql
/// SELECT COUNT(*),
///        COUNT(*) FILTER (WHERE <vi phạm 0>),
///        COUNT(*) FILTER (WHERE <vi phạm 1>), …
/// FROM t
/// ```
///
/// Một lượt quét, bao nhiêu luật cũng thế. `unique` không viết được thành bộ lọc theo hàng nên
/// nó vào cùng câu ấy dưới dạng `COUNT(*) - COUNT(DISTINCT …)`. Chỉ `foreign_key` phải ra câu
/// riêng, vì nó đọc thêm một file khác.
///
/// ## NULL không phải vi phạm của luật khác
///
/// Ô rỗng vi phạm `not_null` — và CHỈ `not_null`. Một ô rỗng không "sai kiểu", không "ngoài
/// khoảng", không "sai mẫu": nó không có giá trị để mà sai. Tính nó vào mọi luật của cùng cột
/// là đếm một vi phạm năm lần, và điểm sáu chiều của FR-DQR-002 sẽ tụt vì đúng một ô trống.
public enum QualityEngine {

    public struct RuleResult: Equatable, Sendable {
        public var rule: QualityRules.Rule
        /// Số hàng vi phạm. `-1` khi luật không chạy được (xem `failure`).
        public var violations: Int
        public var rowCount: Int
        /// Câu lỗi khi luật không chạy được — tên cột sai, regex hỏng, file tra không có.
        public var failure: String?

        public var passed: Bool {
            guard failure == nil else { return false }
            if case .notNull(let allowed) = rule.kind, allowed > 0 {
                return violationPercent <= allowed
            }
            return violations == 0
        }

        public var violationPercent: Double {
            rowCount > 0 ? Double(violations) / Double(rowCount) * 100 : 0
        }

        public init(
            rule: QualityRules.Rule, violations: Int, rowCount: Int, failure: String? = nil
        ) {
            self.rule = rule
            self.violations = violations
            self.rowCount = rowCount
            self.failure = failure
        }
    }

    public struct Report: Equatable, Sendable {
        public var results: [RuleResult]
        public var rowCount: Int
        public var milliseconds: Double

        /// Luật `severity: error` bị fail — thứ quyết định exit code của quality gate
        /// (FR-DQR-005).
        public var failedErrors: [RuleResult] {
            results.filter { !$0.passed && $0.rule.severity == .error }
        }

        public var failedWarnings: [RuleResult] {
            results.filter { !$0.passed && $0.rule.severity == .warn }
        }

        public init(results: [RuleResult], rowCount: Int, milliseconds: Double) {
            self.results = results
            self.rowCount = rowCount
            self.milliseconds = milliseconds
        }
    }

    // MARK: - Chạy

    public static func evaluate(
        _ rules: QualityRules,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Report {
        let started = DispatchTime.now().uptimeNanoseconds
        var ordered: [(index: Int, result: RuleResult)] = []
        var rowCount = 0

        // Giữ CHỈ SỐ của từng luật, không dùng chính luật làm khoá tra.
        //
        // Bản đầu dựng `Dictionary(uniqueKeysWithValues:)` khoá bằng `Rule` để sắp lại thứ tự —
        // và nó **SẬP** ngay khi tệp có hai luật giống hệt nhau. Lặp một luật là chuyện người
        // dùng hoàn toàn có thể làm (chép dán một khối), và một tệp cấu hình không được phép
        // làm sập app. Phép đo NFR-DQR-01 bắt được lỗi này; 16 bài kiểm trước đó thì không, vì
        // không bài nào có hai luật trùng.
        let indexed = Array(rules.rules.enumerated())
        let inline = indexed.filter { !$0.element.kind.needsOwnScan }
        if !inline.isEmpty {
            var projections: [String] = ["COUNT(*)"]
            for (slot, entry) in inline.enumerated() {
                projections.append(aggregate(for: entry.element, alias: "r\(slot)"))
            }
            let sql = "SELECT " + projections.joined(separator: ", ")
                + " FROM \(CSVQueryEngine.tableName)"
            do {
                let table = try CSVQueryEngine.run(
                    sql, in: buffer, dialect: dialect,
                    sourcePath: sourcePath, cancelToken: cancelToken)
                guard let row = table.rows.first else {
                    throw CSVQueryEngine.Failure.query("bảng rỗng")
                }
                rowCount = row.first.flatMap { $0.flatMap(Int.init) } ?? 0
                for (slot, entry) in inline.enumerated() {
                    let value = slot + 1 < row.count ? row[slot + 1].flatMap(Int.init) : nil
                    ordered.append((entry.offset, RuleResult(
                        rule: entry.element, violations: value ?? -1, rowCount: rowCount,
                        failure: value == nil ? "không đọc được số vi phạm" : nil)))
                }
            } catch let failure as CSVQueryEngine.Failure {
                // Cả lượt quét hỏng vì MỘT luật sai — thường là tên cột gõ nhầm. Chạy lại từng
                // luật một để nói được luật NÀO hỏng: chậm hơn, nhưng chỉ xảy ra khi đã có lỗi,
                // và một báo cáo nói "có gì đó sai" mà không nói ở đâu thì không sửa được.
                if case .cancelled = failure { throw failure }
                ordered = inline.map { entry in
                    (entry.offset, evaluateAlone(entry.element, in: buffer, dialect: dialect,
                                                 sourcePath: sourcePath, cancelToken: cancelToken))
                }
                rowCount = ordered.first?.result.rowCount ?? 0
            }
        }

        // --- Luật cần lượt quét riêng ----------------------------------------------------
        for entry in indexed where entry.element.kind.needsOwnScan {
            try cancelToken.check()
            ordered.append((entry.offset, evaluateAlone(
                entry.element, in: buffer, dialect: dialect,
                sourcePath: sourcePath, cancelToken: cancelToken)))
        }

        // Số hàng có thể chưa được đặt: khi MỌI luật đều chạy quét riêng (chỉ có `unique` và
        // `foreign_key`) thì lượt gộp không chạy lần nào. Lấy từ chính các lượt riêng — chúng
        // đều trả về tổng số hàng.
        //
        // Không chạy thêm một `SELECT COUNT(*)` cho chắc: đó là một lượt quét nữa trên bảng có
        // thể hàng trăm MB, để lấy một con số đã nằm sẵn trong tay.
        if rowCount == 0 {
            rowCount = ordered.map(\.result.rowCount).max() ?? 0
        }

        // Giữ ĐÚNG thứ tự người dùng viết trong tệp: bảng kết quả đọc song song với tệp quy tắc
        // là thứ người ta làm khi sửa chuẩn.
        ordered.sort { $0.index < $1.index }
        let results = ordered.map { entry -> RuleResult in
            var result = entry.result
            // Đồng bộ tổng số hàng cho mọi luật, kể cả luật chạy quét riêng: tỷ lệ % của chúng
            // phải tính trên cùng một mẫu số, nếu không hai dòng cạnh nhau trong bảng sẽ nói
            // hai chuyện khác nhau về cùng một bảng dữ liệu.
            if result.rowCount == 0 { result.rowCount = rowCount }
            return result
        }

        let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        return Report(results: results, rowCount: rowCount, milliseconds: milliseconds)
    }

    private static func evaluateAlone(
        _ rule: QualityRules.Rule, in buffer: TextBuffer, dialect: CSVDialect,
        sourcePath: String?, cancelToken: CancelToken
    ) -> RuleResult {
        do {
            let sql: String
            if case .unique = rule.kind, let column = rule.column {
                sql = uniqueCountSQL(column: column)
            } else if case .foreignKey(let file, let column) = rule.kind, let own = rule.column {
                // Anti-join: đếm hàng có giá trị mà bảng tra KHÔNG có. Giá trị NULL bỏ qua —
                // "chưa điền" là việc của `not_null`, không phải của khoá ngoại.
                sql = """
                    SELECT COUNT(*), COUNT(*) FROM \(CSVQueryEngine.tableName) AS t
                    WHERE t.\(quoteIdentifier(own)) IS NOT NULL
                      AND t.\(quoteIdentifier(own)) NOT IN (
                        SELECT \(quoteIdentifier(column)) FROM read_csv(\(quoteLiteral(file)),
                        header = true) WHERE \(quoteIdentifier(column)) IS NOT NULL)
                    """
            } else {
                sql = "SELECT COUNT(*), \(aggregate(for: rule, alias: "r"))"
                    + " FROM \(CSVQueryEngine.tableName)"
            }
            let table = try CSVQueryEngine.run(
                sql, in: buffer, dialect: dialect,
                sourcePath: sourcePath, cancelToken: cancelToken)
            guard let row = table.rows.first, row.count >= 2,
                  let total = row[0].flatMap(Int.init), let bad = row[1].flatMap(Int.init)
            else {
                return RuleResult(rule: rule, violations: -1, rowCount: 0,
                                  failure: "không đọc được kết quả")
            }
            // Câu foreign_key đếm tổng bằng chính bộ lọc, nên `total` ở đó là số hàng vi phạm.
            if case .foreignKey = rule.kind {
                let all = try? CSVQueryEngine.run(
                    "SELECT COUNT(*) FROM \(CSVQueryEngine.tableName)", in: buffer,
                    dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken)
                let rows = all?.rows.first?.first.flatMap { $0.flatMap(Int.init) } ?? total
                return RuleResult(rule: rule, violations: bad, rowCount: rows)
            }
            return RuleResult(rule: rule, violations: bad, rowCount: total)
        } catch let failure as CSVQueryEngine.Failure {
            return RuleResult(rule: rule, violations: -1, rowCount: 0, failure: failure.message)
        } catch {
            return RuleResult(rule: rule, violations: -1, rowCount: 0,
                              failure: String(describing: error))
        }
    }

    /// Số hiệu hàng vi phạm một luật — FR-DQR-001 *"click rule → Mark và nhảy tới dòng"*.
    ///
    /// `unique` và `foreign_key` không viết được thành bộ lọc theo hàng ở `violationPredicate`
    /// (chúng cần nhìn cả cột, hoặc nhìn sang file khác), nên chúng có biểu thức riêng ở đây.
    /// Hai biểu thức ấy chỉ dùng cho việc CHỈ CHỖ; con số đếm vẫn đi đường của `evaluate`, và
    /// hai đường phải cho cùng câu trả lời — có bài kiểm đòi đúng điều đó.
    public static func violatingRowNumbers(
        for rule: QualityRules.Rule,
        in buffer: TextBuffer,
        dialect: CSVDialect,
        sourcePath: String? = nil,
        limit: Int = 500,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [Int] {
        let predicate: String
        var extraProjection: String?
        switch rule.kind {
        case .unique:
            guard let column = rule.column else { return [] }
            let quoted = quoteIdentifier(column)
            // Đếm bằng CỬA SỔ HÀM trên cùng lượt quét, không đọc lại file.
            //
            // Bản đầu tự tham chiếu `read_csv(<đường dẫn nguồn>)` — và nó hỏng với tài liệu
            // CHƯA LƯU, vì khi ấy không có đường dẫn nào để tham chiếu.
            //
            // Điều kiện là `> 1`, nên MỌI hàng mang giá trị lặp đều được tô, kể cả hàng ĐẦU
            // TIÊN. Chỉ tô những bản sau thì người dùng thấy một dòng "trùng" mà không thấy
            // dòng nó trùng với, và không sửa được gì.
            extraProjection = "COUNT(*) OVER (PARTITION BY \(quoted)) AS __dup"
            predicate = "\(quoted) IS NOT NULL AND __dup > 1"
        case .foreignKey(let file, let column):
            guard let own = rule.column else { return [] }
            let escaped = file.replacingOccurrences(of: "'", with: "''")
            predicate = "\(quoteIdentifier(own)) IS NOT NULL AND \(quoteIdentifier(own)) "
                + "NOT IN (SELECT \(quoteIdentifier(column)) FROM read_csv('\(escaped)', "
                + "header = true) WHERE \(quoteIdentifier(column)) IS NOT NULL)"
        default:
            predicate = violationPredicate(rule)
        }
        guard predicate != "FALSE" else { return [] }
        return try CSVQueryEngine.rowNumbers(
            matching: predicate, extraProjection: extraProjection, in: buffer, dialect: dialect,
            sourcePath: sourcePath, limit: limit, cancelToken: cancelToken)
    }

    // MARK: - Biên dịch luật thành SQL

    /// Câu SQL đếm số hàng vi phạm luật này.
    static func aggregate(for rule: QualityRules.Rule, alias: String) -> String {
        "COUNT(*) FILTER (WHERE \(violationPredicate(rule))) AS \(alias)"
    }

    /// Câu đếm riêng cho `unique` — xem `needsOwnScan`.
    static func uniqueCountSQL(column: String) -> String {
        let quoted = quoteIdentifier(column)
        return """
            SELECT COUNT(*), COUNT(*) FILTER (WHERE \(quoted) IN (
              SELECT \(quoted) FROM \(CSVQueryEngine.tableName)
              WHERE \(quoted) IS NOT NULL
              GROUP BY \(quoted) HAVING COUNT(*) > 1))
            FROM \(CSVQueryEngine.tableName)
            """
    }

    /// Biểu thức đúng khi hàng VI PHẠM.
    static func violationPredicate(_ rule: QualityRules.Rule) -> String {
        // Ô rỗng chỉ vi phạm `not_null`. Xem ghi chú ở đầu tệp.
        func present(_ column: String) -> String { "\(quoteIdentifier(column)) IS NOT NULL" }

        switch rule.kind {
        case .notNull:
            guard let column = rule.column else { return "FALSE" }
            return "\(quoteIdentifier(column)) IS NULL"

        case .unique:
            return "FALSE"   // xử lý ở `aggregate`

        case .dtype(let type):
            guard let column = rule.column else { return "FALSE" }
            let quoted = quoteIdentifier(column)
            switch type {
            case .text:
                // Mọi ô đều đọc được thành chữ, nên luật này không bao giờ vi phạm. Giữ nó lại
                // thay vì từ chối lúc đọc tệp: `dtype: text` là cách người dùng NÓI RA rằng cột
                // này cố ý là chữ, và một luật luôn pass vẫn là một tài liệu.
                return "FALSE"
            case .int: return "\(present(column)) AND TRY_CAST(\(quoted) AS BIGINT) IS NULL"
            case .float: return "\(present(column)) AND TRY_CAST(\(quoted) AS DOUBLE) IS NULL"
            case .date: return "\(present(column)) AND TRY_CAST(\(quoted) AS DATE) IS NULL"
            }

        case .range(let low, let high):
            guard let column = rule.column else { return "FALSE" }
            let value = "TRY_CAST(\(quoteIdentifier(column)) AS DOUBLE)"
            var checks = ["\(value) IS NULL"]   // không đổi được sang số cũng là ngoài khoảng
            if let low { checks.append("\(value) < \(sqlNumber(low))") }
            if let high { checks.append("\(value) > \(sqlNumber(high))") }
            return "\(present(column)) AND (\(checks.joined(separator: " OR ")))"

        case .length(let low, let high):
            guard let column = rule.column else { return "FALSE" }
            let value = "length(CAST(\(quoteIdentifier(column)) AS VARCHAR))"
            var checks: [String] = []
            if let low { checks.append("\(value) < \(low)") }
            if let high { checks.append("\(value) > \(high)") }
            return "\(present(column)) AND (\(checks.joined(separator: " OR ")))"

        case .regex(let pattern):
            guard let column = rule.column else { return "FALSE" }
            return "\(present(column)) AND NOT regexp_matches("
                + "CAST(\(quoteIdentifier(column)) AS VARCHAR), \(quoteLiteral(pattern)))"

        case .inSet(let values):
            guard let column = rule.column else { return "FALSE" }
            let list = values.map(quoteLiteral).joined(separator: ", ")
            return "\(present(column)) AND CAST(\(quoteIdentifier(column)) AS VARCHAR)"
                + " NOT IN (\(list))"

        case .dateFormat(let format):
            guard let column = rule.column else { return "FALSE" }
            return "\(present(column)) AND TRY_STRPTIME("
                + "CAST(\(quoteIdentifier(column)) AS VARCHAR), \(quoteLiteral(format))) IS NULL"

        case .compare(let left, let op, let right):
            let a = quoteIdentifier(left), b = quoteIdentifier(right)
            // Hàng thiếu một trong hai vế KHÔNG vi phạm: không có gì để so.
            return "\(a) IS NOT NULL AND \(b) IS NOT NULL AND NOT (\(a) \(op) \(b))"

        case .expr(let text):
            // `IS FALSE` chứ không `NOT (…)`: biểu thức trả NULL (vì một vế rỗng) thì đó là
            // "không kết luận được", không phải "vi phạm". `NOT NULL` là NULL, và `COUNT
            // FILTER` bỏ qua NULL — nhưng viết ra cho rõ ý còn hơn dựa vào chỗ ấy.
            return "(\(text)) IS FALSE"

        case .foreignKey:
            return "FALSE"   // có câu riêng
        }
    }

    // MARK: - Thoát chuỗi

    /// Tên cột trong dấu nháy kép, nhân đôi dấu nháy bên trong.
    ///
    /// Bắt buộc: tên cột trong CSV của người dùng có dấu cách, dấu tiếng Việt, và đôi khi có cả
    /// dấu nháy. Ghép thẳng là sinh ra một câu SQL hỏng — hoặc tệ hơn, một câu SQL khác.
    static func quoteIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func quoteLiteral(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private static func sqlNumber(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int(value)) : String(value)
    }
}

private extension QualityRules.Rule.Kind {
    /// Luật phải chạy câu riêng.
    ///
    /// `foreignKey` vì nó đọc thêm một file khác.
    ///
    /// `unique` vì một lý do khác hẳn, và lý do ấy là một quyết định về Ý NGHĨA: số vi phạm
    /// phải bằng số hàng sẽ được TÔ khi người dùng bấm vào luật. Cách cũ đếm
    /// `COUNT(*) − COUNT(DISTINCT)` — tức số hàng THỪA — nên bảng nói "1 vi phạm" trong khi
    /// Mark tô 2 dòng (cả `KH03` gốc lẫn bản trùng). Hai con số cho cùng một luật là chỗ người
    /// dùng mất lòng tin vào cả báo cáo, và một bài kiểm đối chiếu hai đường đã bắt được đúng nó.
    ///
    /// Đếm "mọi hàng mang giá trị lặp" cần một truy vấn con, không nhét vào lượt quét gộp được.
    /// Cái giá là một lượt quét thêm cho mỗi luật `unique` — chấp nhận được: NFR-DQR-01 còn dư
    /// 46 lần (312 ms trên trần 15 000).
    var needsOwnScan: Bool {
        switch self {
        case .foreignKey, .unique: return true
        default: return false
        }
    }
}
