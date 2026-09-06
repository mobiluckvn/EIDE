import Foundation

/// Cổng chất lượng cho pipeline và CI — FR-DQR-005.
///
/// ```sh
/// geditor --quality chuan.yaml du-lieu.csv --fail-under 90 --json ket-qua.json
/// ```
///
/// ## Mã thoát 0 · 1 · 2, KHÔNG theo `sysexits.h`
///
/// Phần CLI còn lại của GEditor dùng `EX_USAGE 64`, `EX_DATAERR 65`, `EX_NOINPUT 66` — quy ước
/// của BSD, và nó đúng cho một lệnh dành cho người gõ. Cổng này thì không: đặc tả viết thẳng
/// *"exit code: 0 (pass), 1 (điểm dưới ngưỡng hoặc có rule error fail), 2 (lỗi chạy)"*, và đó
/// là quy ước mà mọi công cụ kiểm trong CI đang dùng.
///
/// Đây là chỗ hai quy ước gặp nhau, nên nó được nói ra ở cả `--help` lẫn đây thay vì để người
/// đọc mã tự phát hiện. Một cổng trả 65 cho "dữ liệu bẩn" sẽ bị viết thành `|| true` trong
/// `.gitlab-ci.yml` của người dùng, và khi ấy cổng không còn là cổng.
///
/// ## "Luật không chạy được" tính là TRƯỢT, không tính là lỗi chạy
///
/// Một luật gõ sai tên cột cho `failure != nil`. Đó KHÔNG phải mã 2: lệnh đã chạy xong, đã đọc
/// được dữ liệu, và câu trả lời là *"bộ luật này không áp được lên bảng này"* — một câu trả lời
/// về CHẤT LƯỢNG. Mã 2 dành cho những chuyện lệnh không làm nổi: không mở được tệp, không có
/// DuckDB, tệp luật hỏng cú pháp.
public enum QualityGate {

    public struct Options: Sendable {
        /// Điểm tổng dưới ngưỡng này thì TRƯỢT. `nil` = không chấm theo điểm, chỉ theo luật.
        public var failUnder: Double?
        /// Bao nhiêu HÀNG ví dụ cho mỗi luật trượt trong JSON. 0 = không lấy.
        ///
        /// Mỗi luật trượt tốn một lượt quét thêm, nên mặc định chỉ lấy khi có `--json`: một cổng
        /// chỉ cần biết đạt hay không thì không nên trả tiền cho những dòng ví dụ không ai đọc.
        public var violationSamples: Int
        /// Mốc cho chiều TIMELINESS — đóng đinh được để hai lần chạy cho cùng điểm.
        public var now: Date?
        /// Ghi snapshot vào lịch sử (FR-DQR-004).
        public var recordHistory: Bool

        public init(
            failUnder: Double? = nil, violationSamples: Int = 0, now: Date? = nil,
            recordHistory: Bool = false
        ) {
            self.failUnder = failUnder
            self.violationSamples = violationSamples
            self.now = now
            self.recordHistory = recordHistory
        }
    }

    public enum Status: String, Sendable {
        case pass, fail, error
    }

    public struct FileOutcome: Sendable {
        public var path: String
        public var status: Status
        /// `nil` khi `status == .error`.
        public var report: QualityEngine.Report?
        public var score: QualityScore?
        /// Điểm TRƯỚC khi chạy công thức làm sạch — chỉ có khi đi cùng `--recipe`.
        public var scoreBefore: QualityScore?
        /// Hàng ví dụ theo từng luật trượt: tiêu đề luật → số hiệu hàng (1-based, theo THỨ TỰ
        /// FILE).
        public var samples: [(rule: String, rows: [Int])]
        public var reasons: [String]
        public var drift: QualityDrift.Comparison?

        public init(
            path: String, status: Status, report: QualityEngine.Report? = nil,
            score: QualityScore? = nil, scoreBefore: QualityScore? = nil,
            samples: [(rule: String, rows: [Int])] = [], reasons: [String] = [],
            drift: QualityDrift.Comparison? = nil
        ) {
            self.path = path
            self.status = status
            self.report = report
            self.score = score
            self.scoreBefore = scoreBefore
            self.samples = samples
            self.reasons = reasons
            self.drift = drift
        }
    }

    public struct Outcome: Sendable {
        public var files: [FileOutcome]
        public var rulesPath: String

        public init(files: [FileOutcome], rulesPath: String) {
            self.files = files
            self.rulesPath = rulesPath
        }

        /// Mã thoát GỘP của cả lượt chạy nhiều file.
        ///
        /// Lấy mã NẶNG NHẤT: một file lỗi chạy giữa hai mươi file đạt vẫn phải làm cả lượt
        /// trượt. Cách khác — lấy mã của file cuối — là cách một pipeline báo xanh vì tình cờ
        /// file cuối cùng lành lặn.
        public var exitCode: Int32 {
            if files.contains(where: { $0.status == .error }) { return 2 }
            if files.contains(where: { $0.status == .fail }) { return 1 }
            return 0
        }

        public var passedCount: Int { files.filter { $0.status == .pass }.count }
        public var failedCount: Int { files.filter { $0.status == .fail }.count }
        public var errorCount: Int { files.filter { $0.status == .error }.count }
    }

    // MARK: - Chạy

    /// Chấm một danh sách file theo cùng một bộ luật.
    ///
    /// `prepare` chạy TRƯỚC khi chấm, trên chính buffer sẽ được chấm — đây là chỗ `--recipe`
    /// cắm vào (*"kết hợp --recipe: làm sạch xong tự chấm lại"*). Trả về `true` nếu có sửa gì.
    public static func run(
        rules: QualityRules,
        rulesPath: String,
        files: [String],
        dialect: CSVDialect = .comma,
        options: Options = Options(),
        cancelToken: CancelToken = CancelToken(),
        prepare: ((TextBuffer, String) throws -> Bool)? = nil
    ) -> Outcome {
        var outcomes: [FileOutcome] = []
        for path in files {
            outcomes.append(evaluate(
                rules: rules, rulesPath: rulesPath, path: path, dialect: dialect,
                options: options, cancelToken: cancelToken, prepare: prepare))
        }
        return Outcome(files: outcomes, rulesPath: rulesPath)
    }

    private static func evaluate(
        rules: QualityRules, rulesPath: String, path: String, dialect: CSVDialect,
        options: Options, cancelToken: CancelToken,
        prepare: ((TextBuffer, String) throws -> Bool)?
    ) -> FileOutcome {
        guard let bytes = FileManager.default.contents(atPath: path) else {
            return FileOutcome(path: path, status: .error,
                               reasons: ["không đọc được \(path)"])
        }
        let buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
        let now = options.now ?? Date()
        do {
            // --- Làm sạch trước, nếu có ---------------------------------------------------
            var scoreBefore: QualityScore?
            if let prepare {
                // Chấm TRƯỚC khi làm sạch để nói được công thức đã cải thiện bao nhiêu. Không
                // có con số này thì `--recipe --quality` chỉ nói "nay đạt", mà không nói nó
                // từng ở đâu — và người ta không biết công thức có làm gì không.
                let firstReport = try QualityEngine.evaluate(
                    rules, in: buffer, dialect: dialect, sourcePath: path,
                    cancelToken: cancelToken)
                scoreBefore = try QualityScorer.score(
                    firstReport, rules: rules, in: buffer, dialect: dialect, sourcePath: path,
                    now: now, cancelToken: cancelToken)
                _ = try prepare(buffer, path)
            }

            // Buffer đã sửa thì KHÔNG truyền `sourcePath` nữa: `CSVQueryEngine` đọc thẳng từ
            // file khi có đường dẫn và buffer chưa đổi, nên đưa đường dẫn vào đây là chấm lại
            // bản CHƯA làm sạch mà vẫn ra một con số trông rất hợp lý.
            let sourceForScoring = prepare == nil ? path : nil
            let report = try QualityEngine.evaluate(
                rules, in: buffer, dialect: dialect, sourcePath: sourceForScoring,
                cancelToken: cancelToken)
            let score = try QualityScorer.score(
                report, rules: rules, in: buffer, dialect: dialect,
                sourcePath: sourceForScoring, now: now, cancelToken: cancelToken)

            var reasons: [String] = []
            var status = Status.pass
            let brokenRules = report.results.filter { $0.failure != nil }
            if !brokenRules.isEmpty {
                status = .fail
                reasons.append("\(brokenRules.count) luật KHÔNG chạy được: "
                    + brokenRules.prefix(3).map { $0.failure ?? "" }.joined(separator: " · "))
            }
            let failedErrors = report.failedErrors.filter { $0.failure == nil }
            if !failedErrors.isEmpty {
                status = .fail
                reasons.append("\(failedErrors.count) luật mức `error` TRƯỢT: "
                    + failedErrors.prefix(3).map(\.rule.title).joined(separator: " · "))
            }
            if let threshold = options.failUnder {
                if let total = score.total {
                    if total < threshold {
                        status = .fail
                        reasons.append(String(
                            format: "điểm %.1f dưới ngưỡng %.1f", total, threshold))
                    }
                } else {
                    // KHÔNG chấm được mà lại có ngưỡng: đó là TRƯỢT, không phải đạt. Coi "không
                    // biết" là "đạt" ở một cổng chặn là cách cổng ấy mở toang trong im lặng.
                    status = .fail
                    reasons.append("không chiều nào chấm được nên không có điểm tổng để so với "
                        + "ngưỡng — bộ luật này chưa đủ để dựng một cổng")
                }
            }

            // --- Hàng ví dụ ------------------------------------------------------------
            var samples: [(rule: String, rows: [Int])] = []
            if options.violationSamples > 0 {
                for result in report.results
                where result.failure == nil && !result.passed && result.violations > 0 {
                    let rows = (try? QualityEngine.violatingRowNumbers(
                        for: result.rule, in: buffer, dialect: dialect,
                        sourcePath: sourceForScoring, limit: options.violationSamples,
                        cancelToken: cancelToken)) ?? []
                    samples.append((result.rule.title, rows))
                }
            }

            // --- Lịch sử và trôi dạt (FR-DQR-004) ----------------------------------------
            var drift: QualityDrift.Comparison?
            let card = QualityCard.Result(
                report: report, score: score, rules: rules, rulesPath: rulesPath,
                sourcePath: path)
            if options.recordHistory {
                drift = QualityHistory.record(card, rulesPath: rulesPath)
            }
            if let alerts = drift?.alerts, !alerts.isEmpty {
                reasons.append(contentsOf: alerts)
                // Trôi dạt vượt ngưỡng KHÔNG tự làm trượt cổng: ngưỡng trôi dạt nói "đợt này
                // khác đợt trước", còn cổng nói "đợt này có dùng được không". Trộn hai câu ấy
                // thì một lần dữ liệu tốt lên rồi xấu đi trong ngưỡng cho phép cũng chặn merge.
                // Muốn chặn thì dùng `--fail-under`.
            }

            return FileOutcome(
                path: path, status: status, report: report, score: score,
                scoreBefore: scoreBefore, samples: samples, reasons: reasons, drift: drift)
        } catch let failure as CSVQueryEngine.Failure {
            return FileOutcome(path: path, status: .error, reasons: [failure.message])
        } catch {
            return FileOutcome(path: path, status: .error,
                               reasons: [error.localizedDescription])
        }
    }

    // MARK: - JSON cho pipeline

    /// JSON máy đọc được — FR-DQR-005 (*"score, dimensions{}, rules[], violations_sample[]"*).
    ///
    /// Tự dựng chuỗi thay vì `JSONEncoder`: khoá phải theo ĐÚNG tên đặc tả đặt (`violations_sample`,
    /// `fail_under`), và thứ tự khoá phải ổn định để `git diff` của một tệp kết quả đọc được.
    /// `JSONEncoder` với `.sortedKeys` cho thứ tự bảng chữ cái, tức `dimensions` đứng trên
    /// `score` — đọc được với máy, khó đọc với người.
    public static func json(_ outcome: Outcome, options: Options = Options()) -> String {
        var files: [String] = []
        for file in outcome.files {
            var parts: [String] = []
            parts.append("\"file\": \(quote(file.path))")
            parts.append("\"status\": \(quote(file.status.rawValue))")
            parts.append("\"score\": \(number(file.score?.total))")
            if let before = file.scoreBefore?.total {
                parts.append("\"score_before_recipe\": \(number(before))")
            }
            parts.append("\"row_count\": \(file.score?.rowCount ?? 0)")
            if let score = file.score {
                parts.append("\"evaluated_at\": "
                    + quote(QualityHistory.iso(score.evaluatedAt)))
                let dimensions = score.dimensions.map { entry -> String in
                    var inner = ["\"value\": \(number(entry.value))",
                                 "\"weight\": \(number(entry.weight))",
                                 "\"formula\": \(quote(entry.formula))",
                                 "\"detail\": \(quote(entry.detail))"]
                    if let note = entry.note { inner.append("\"note\": \(quote(note))") }
                    return "      \(quote(entry.dimension.rawValue)): { "
                        + inner.joined(separator: ", ") + " }"
                }
                parts.append("\"dimensions\": {\n" + dimensions.joined(separator: ",\n")
                    + "\n    }")
            }
            if let report = file.report {
                let rules = report.results.map { result -> String in
                    var inner = ["\"rule\": \(quote(result.rule.title))",
                                 "\"severity\": \(quote(result.rule.severity.rawValue))",
                                 "\"passed\": \(result.passed ? "true" : "false")",
                                 "\"violations\": \(result.violations)",
                                 "\"violation_percent\": "
                                    + String(format: "%.4f", result.violationPercent)]
                    if let column = result.rule.column {
                        inner.insert("\"column\": \(quote(column))", at: 1)
                    }
                    if let failure = result.failure {
                        inner.append("\"error\": \(quote(failure))")
                    }
                    return "      { " + inner.joined(separator: ", ") + " }"
                }
                parts.append("\"rules\": [\n" + rules.joined(separator: ",\n") + "\n    ]")
                parts.append("\"milliseconds\": " + String(format: "%.1f", report.milliseconds))
            }
            let samples = file.samples.map { entry in
                "      { \"rule\": \(quote(entry.rule)), \"rows\": ["
                    + entry.rows.map(String.init).joined(separator: ", ") + "] }"
            }
            parts.append("\"violations_sample\": ["
                + (samples.isEmpty ? "]" : "\n" + samples.joined(separator: ",\n") + "\n    ]"))
            if !file.reasons.isEmpty {
                parts.append("\"reasons\": ["
                    + file.reasons.map(quote).joined(separator: ", ") + "]")
            }
            if let drift = file.drift, drift.hasPrevious {
                var inner = ["\"previous_at\": \(quote(drift.previous?.timestamp ?? ""))"]
                if let delta = drift.totalDelta {
                    inner.append("\"score_delta\": " + String(format: "%.4f", delta))
                }
                if !drift.newlyFailing.isEmpty {
                    inner.append("\"newly_failing\": ["
                        + drift.newlyFailing.map(quote).joined(separator: ", ") + "]")
                }
                if !drift.alerts.isEmpty {
                    inner.append("\"alerts\": ["
                        + drift.alerts.map(quote).joined(separator: ", ") + "]")
                }
                parts.append("\"drift\": { " + inner.joined(separator: ", ") + " }")
            }
            files.append("  {\n    " + parts.joined(separator: ",\n    ") + "\n  }")
        }

        var head = ["\"rules_file\": \(quote(outcome.rulesPath))",
                    "\"exit_code\": \(outcome.exitCode)",
                    "\"passed\": \(outcome.passedCount)",
                    "\"failed\": \(outcome.failedCount)",
                    "\"errors\": \(outcome.errorCount)"]
        if let threshold = options.failUnder {
            head.append("\"fail_under\": \(number(threshold))")
        }
        return "{\n  " + head.joined(separator: ",\n  ")
            + ",\n  \"files\": [\n" + files.joined(separator: ",\n") + "\n  ]\n}\n"
    }

    /// Báo cáo cho người đọc trên màn hình.
    public static func text(_ outcome: Outcome, options: Options = Options()) -> String {
        var lines: [String] = []
        for file in outcome.files {
            let name = (file.path as NSString).lastPathComponent
            switch file.status {
            case .error:
                lines.append("✖ \(name): \(file.reasons.joined(separator: " · "))")
            case .fail, .pass:
                let mark = file.status == .pass ? "✔" : "✖"
                let total = file.score?.total.map { String(format: "%.1f", $0) } ?? "—"
                var line = "\(mark) \(name): \(total)/100"
                if let before = file.scoreBefore?.total {
                    line += String(format: " (trước khi làm sạch: %.1f)", before)
                }
                if let report = file.report {
                    line += " · \(report.results.filter(\.passed).count)/"
                        + "\(report.results.count) luật đạt · \(report.rowCount) hàng"
                }
                lines.append(line)
                for reason in file.reasons { lines.append("    \(reason)") }
            }
        }
        if outcome.files.count > 1 {
            lines.append("— \(outcome.passedCount) đạt · \(outcome.failedCount) trượt · "
                + "\(outcome.errorCount) lỗi")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Mảnh

    static func quote(_ text: String) -> String {
        var out = "\""
        for character in text.unicodeScalars {
            switch character {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                // Ký tự điều khiển phải thoát thành `\u00XX`, nếu không tệp JSON hỏng. Chữ
                // tiếng Việt thì đi NGUYÊN VẸN: JSON là UTF-8, và một tên cột «doanh_thu_₫»
                // biến thành `₫` chỉ làm tệp khó đọc chứ không an toàn hơn.
                if character.value < 0x20 {
                    out += String(format: "\\u%04x", character.value)
                } else {
                    out.unicodeScalars.append(character)
                }
            }
        }
        return out + "\""
    }

    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "null" }
        return String(format: "%.4f", value)
    }
}
