import CryptoKit
import Foundation

/// Một lần chấm điểm, đóng thành bản ghi — FR-DQR-004.
///
/// ## Vì sao JSONL chứ không phải JSON hay SQLite
///
/// Ghi thêm một dòng vào cuối tệp là thao tác **không đọc lại gì cả**: một lần `open(O_APPEND)`
/// và một lần `write`. Với một tệp JSON đúng chuẩn, thêm một phần tử vào mảng nghĩa là đọc cả
/// tệp, phân tích, nối, ghi lại — nên tệp càng dài thì mỗi lần chấm càng chậm, và một lần ngắt
/// điện giữa chừng làm mất TOÀN BỘ lịch sử chứ không phải dòng cuối.
///
/// SQLite thì ngược lại: nhanh và bền, nhưng lịch sử chất lượng là thứ người ta muốn `git diff`,
/// `tail -1`, và mở bằng bất kỳ công cụ nào. Cùng luật ADR-09 với chính tệp `.gquality.yaml`.
///
/// Một dòng hỏng (đĩa đầy giữa lúc ghi) chỉ mất một dòng — phần còn lại vẫn đọc được. Đó là lý
/// do thật của định dạng này, và `QualityHistory.read` cố ý **đếm và nói ra** số dòng hỏng thay
/// vì lặng lẽ bỏ qua.
public struct QualitySnapshot: Codable, Equatable, Sendable {

    public struct DimensionEntry: Codable, Equatable, Sendable {
        public var name: String
        /// `nil` khi chiều KHÔNG chấm được — giữ nguyên `null` trong JSON, không đổi thành 0.
        public var value: Double?
        public var weight: Double
        public var note: String?

        public init(name: String, value: Double?, weight: Double, note: String?) {
            self.name = name
            self.value = value
            self.weight = weight
            self.note = note
        }
    }

    public struct RuleEntry: Codable, Equatable, Sendable {
        public var title: String
        public var column: String?
        public var severity: String
        public var passed: Bool
        public var violations: Int
        public var failure: String?

        public init(
            title: String, column: String?, severity: String, passed: Bool,
            violations: Int, failure: String?
        ) {
            self.title = title
            self.column = column
            self.severity = severity
            self.passed = passed
            self.violations = violations
            self.failure = failure
        }
    }

    public struct ColumnEntry: Codable, Equatable, Sendable {
        public var column: String
        public var nullPercent: Double

        public init(column: String, nullPercent: Double) {
            self.column = column
            self.nullPercent = nullPercent
        }
    }

    /// ISO-8601 UTC, giây tròn.
    public var timestamp: String
    public var sourcePath: String?
    /// SHA-256 nội dung nguồn. Rỗng khi không tính (xem `QualityHistory.record`).
    public var sourceHash: String
    public var rowCount: Int
    public var total: Double?
    public var dimensions: [DimensionEntry]
    public var rules: [RuleEntry]
    public var columns: [ColumnEntry]
    /// Số mili-giây của lượt chấm — để thấy chính phép đo có chậm đi không.
    public var milliseconds: Double

    public init(
        timestamp: String, sourcePath: String?, sourceHash: String, rowCount: Int,
        total: Double?, dimensions: [DimensionEntry], rules: [RuleEntry],
        columns: [ColumnEntry], milliseconds: Double
    ) {
        self.timestamp = timestamp
        self.sourcePath = sourcePath
        self.sourceHash = sourceHash
        self.rowCount = rowCount
        self.total = total
        self.dimensions = dimensions
        self.rules = rules
        self.columns = columns
        self.milliseconds = milliseconds
    }

    public init(
        report: QualityEngine.Report, score: QualityScore, sourcePath: String?,
        sourceHash: String
    ) {
        self.init(
            timestamp: QualityHistory.iso(score.evaluatedAt),
            sourcePath: sourcePath,
            sourceHash: sourceHash,
            rowCount: score.rowCount,
            total: score.total,
            dimensions: score.dimensions.map {
                DimensionEntry(name: $0.dimension.rawValue, value: $0.value,
                               weight: $0.weight, note: $0.note)
            },
            rules: report.results.map {
                RuleEntry(title: $0.rule.title, column: $0.rule.column,
                          severity: $0.rule.severity.rawValue, passed: $0.passed,
                          violations: $0.violations, failure: $0.failure)
            },
            columns: score.columnNulls.map {
                ColumnEntry(column: $0.column, nullPercent: $0.percent)
            },
            milliseconds: report.milliseconds)
    }

    public var date: Date? { QualityHistory.parseISO(timestamp) }

    public func dimension(_ name: String) -> DimensionEntry? {
        dimensions.first { $0.name == name }
    }
}

/// Đọc và ghi tệp lịch sử `.gquality.history.jsonl` — FR-DQR-004.
public enum QualityHistory {

    /// Tên tệp lịch sử, suy từ tên tệp LUẬT.
    ///
    /// `.gquality.yaml` → `.gquality.history.jsonl`; `chuan-ban-hang.yaml` →
    /// `chuan-ban-hang.history.jsonl`. Đặt CẠNH tệp luật chứ không cạnh dữ liệu, đúng nguyên
    /// văn NFR-DQR-02: *"snapshot lịch sử ghi file RIÊNG cạnh rules, không bao giờ ghi vào file
    /// dữ liệu"*. Một bộ luật chấm cho mười tệp dữ liệu thì mười lượt ấy vào chung một dòng
    /// lịch sử — và đó là điều đúng, vì thứ đang theo dõi là *chất lượng theo chuẩn này*.
    public static func historyPath(forRules rulesPath: String) -> String {
        let directory = (rulesPath as NSString).deletingLastPathComponent
        var name = (rulesPath as NSString).lastPathComponent
        for suffix in [".yaml", ".yml"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return (directory as NSString).appendingPathComponent(name + ".history.jsonl")
    }

    // MARK: - Ghi

    public struct WriteFailure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Nối một snapshot vào cuối tệp lịch sử.
    ///
    /// Mở bằng `O_APPEND`: hai tiến trình cùng ghi (một cổng CI và một cửa sổ app) không xen
    /// vào giữa dòng của nhau, vì kernel bảo đảm mỗi lần `write` một dòng ngắn là nguyên tử ở
    /// chế độ nối đuôi. Ghi bằng `String.write(to:)` thì tiến trình sau ĐÈ MẤT tệp của tiến
    /// trình trước.
    @discardableResult
    public static func append(
        _ snapshot: QualitySnapshot, to path: String
    ) throws -> QualitySnapshot {
        let encoder = JSONEncoder()
        // Khoá sắp thứ tự: hai dòng của cùng một kết quả phải giống nhau từng byte, nếu không
        // `git diff` của tệp lịch sử đầy những thay đổi không có nghĩa.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(snapshot) else {
            throw WriteFailure(message: "không đóng gói được snapshot chất lượng")
        }
        var line = data
        line.append(0x0A)

        let manager = FileManager.default
        if !manager.fileExists(atPath: path) {
            guard manager.createFile(atPath: path, contents: nil) else {
                throw WriteFailure(message: "không tạo được tệp lịch sử \(path)")
            }
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw WriteFailure(message: "không mở được tệp lịch sử \(path) để ghi")
        }
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        return snapshot
    }

    // MARK: - Đọc

    public struct Log: Equatable, Sendable {
        public var snapshots: [QualitySnapshot]
        /// Số dòng KHÔNG đọc được. Nói ra chứ không nuốt: một tệp lịch sử mất nửa số dòng mà
        /// vẫn vẽ ra một đường xu hướng mượt mà là một đường xu hướng nói dối.
        public var brokenLines: Int

        public init(snapshots: [QualitySnapshot] = [], brokenLines: Int = 0) {
            self.snapshots = snapshots
            self.brokenLines = brokenLines
        }

        public var last: QualitySnapshot? { snapshots.last }
        public var isEmpty: Bool { snapshots.isEmpty }
    }

    public static func read(path: String, limit: Int = 500) -> Log {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return Log() }
        let decoder = JSONDecoder()
        var log = Log()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let snapshot = try? decoder.decode(
                QualitySnapshot.self, from: Data(trimmed.utf8))
            else {
                log.brokenLines += 1
                continue
            }
            log.snapshots.append(snapshot)
        }
        // Giữ `limit` bản GẦN NHẤT. Cắt từ đầu chứ không từ cuối: xu hướng đọc từ phải sang.
        if log.snapshots.count > limit {
            log.snapshots.removeFirst(log.snapshots.count - limit)
        }
        return log
    }

    // MARK: - Ghi từ một lượt chấm

    /// Ghi snapshot cho một lượt chấm rồi so với lần gần nhất.
    ///
    /// Trả về phép so **với bản TRƯỚC bản vừa ghi** — nếu không thì mọi lần chạy đều so chính
    /// nó với chính nó và không bao giờ có trôi dạt.
    ///
    /// `hashSource: false` khi thứ vừa được chấm KHÔNG phải nội dung đang nằm trên đĩa — buffer
    /// đang sửa dở. Băm tệp trên đĩa khi ấy là ghi vào lịch sử một dấu vân của dữ liệu KHÁC với
    /// dữ liệu đã cho ra điểm số ấy, và lần so sau sẽ kết luận sai theo hướng tự tin.
    @discardableResult
    public static func record(
        _ card: QualityCard.Result, rulesPath: String, hashSource: Bool = true
    ) -> QualityDrift.Comparison {
        let path = historyPath(forRules: rulesPath)
        let previous = read(path: path).last
        let snapshot = QualitySnapshot(
            report: card.report, score: card.score, sourcePath: card.sourcePath,
            sourceHash: hashSource
                ? (card.sourcePath.flatMap { sha256(ofFileAt: $0) } ?? "") : "")
        // Ghi hỏng KHÔNG được làm hỏng cả lượt chấm: người dùng vẫn phải thấy điểm của mình.
        // Nhưng nó cũng không được im lặng — lỗi đi vào `alerts` của phép so.
        var writeFailure: String?
        do {
            try append(snapshot, to: path)
        } catch let failure as WriteFailure {
            writeFailure = failure.message
        } catch {
            writeFailure = error.localizedDescription
        }
        var comparison = QualityDrift.compare(
            current: snapshot, previous: previous, thresholds: card.rules.drift)
        if let writeFailure {
            comparison.alerts.append("Không ghi được lịch sử chất lượng: \(writeFailure)")
        }
        comparison.historyPath = path
        return comparison
    }

    /// So lượt chấm này với bản gần nhất trong lịch sử, KHÔNG ghi gì.
    ///
    /// Đường dùng cho preview: dựng lại báo cáo mỗi lần ngừng gõ mà lần nào cũng nối một dòng
    /// vào lịch sử thì sau một buổi chiều tệp lịch sử có vài trăm bản ghi của cùng một dữ liệu,
    /// và đường xu hướng thành một hàng rào dày đặc không đọc được.
    public static func compareWithLast(_ card: QualityCard.Result) -> QualityDrift.Comparison {
        let path = historyPath(forRules: card.rulesPath)
        let snapshot = QualitySnapshot(
            report: card.report, score: card.score, sourcePath: card.sourcePath,
            sourceHash: "")
        var comparison = QualityDrift.compare(
            current: snapshot, previous: read(path: path).last,
            thresholds: card.rules.drift)
        comparison.historyPath = path
        return comparison
    }

    // MARK: - Mảnh

    /// SHA-256 của một tệp, đọc theo khối 1 MB.
    ///
    /// Không `Data(contentsOf:)`: một tệp dữ liệu 1 GB thì cách ấy nạp cả GB vào bộ nhớ để rồi
    /// vứt đi, và trên máy 8 GB của chỉ tiêu NFR-PERF-05 nó là một lần hoán trang thấy được.
    public static func sha256(ofFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: date)
    }

    static func parseISO(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

/// So hai lượt chấm — FR-DQR-004 (*"bảng so sánh 2 snapshot bất kỳ: chiều nào tụt, rule nào mới
/// fail"*).
public enum QualityDrift {

    public struct DimensionDelta: Equatable, Sendable {
        public var name: String
        public var vietnamese: String
        public var before: Double?
        public var after: Double?

        public var delta: Double? {
            guard let before, let after else { return nil }
            return after - before
        }

        public init(name: String, before: Double?, after: Double?) {
            self.name = name
            self.vietnamese = QualityRules.Dimension(rawValue: name)?.vietnamese ?? name
            self.before = before
            self.after = after
        }
    }

    public struct ColumnDelta: Equatable, Sendable {
        public var column: String
        public var before: Double
        public var after: Double
        public var delta: Double { after - before }

        public init(column: String, before: Double, after: Double) {
            self.column = column
            self.before = before
            self.after = after
        }
    }

    public struct Comparison: Equatable, Sendable {
        public var current: QualitySnapshot
        public var previous: QualitySnapshot?
        public var dimensions: [DimensionDelta]
        /// Luật ĐANG đạt ở bản trước, nay TRƯỢT.
        public var newlyFailing: [String]
        /// Luật trước trượt, nay đạt — tin tốt vẫn phải hiện ra, nếu không bảng so sánh chỉ
        /// biết kể chuyện xấu và người ta thôi mở nó.
        public var newlyPassing: [String]
        /// Cột có %null TĂNG. Chỉ giữ cột thật sự đổi.
        public var columns: [ColumnDelta]
        public var alerts: [String]
        public var historyPath: String?

        public var hasPrevious: Bool { previous != nil }

        public var totalDelta: Double? {
            guard let before = previous?.total, let after = current.total else { return nil }
            return after - before
        }

        public var rowCountDelta: Int? {
            guard let previous else { return nil }
            return current.rowCount - previous.rowCount
        }

        public init(
            current: QualitySnapshot, previous: QualitySnapshot? = nil,
            dimensions: [DimensionDelta] = [], newlyFailing: [String] = [],
            newlyPassing: [String] = [], columns: [ColumnDelta] = [],
            alerts: [String] = [], historyPath: String? = nil
        ) {
            self.current = current
            self.previous = previous
            self.dimensions = dimensions
            self.newlyFailing = newlyFailing
            self.newlyPassing = newlyPassing
            self.columns = columns
            self.alerts = alerts
            self.historyPath = historyPath
        }
    }

    /// So hai snapshot BẤT KỲ — cùng hàm dùng cho "so với lần trước" và cho bảng so tay hai bản
    /// người dùng chọn trong panel xu hướng.
    public static func compare(
        current: QualitySnapshot, previous: QualitySnapshot?,
        thresholds: QualityRules.Drift = QualityRules.Drift()
    ) -> Comparison {
        var comparison = Comparison(current: current, previous: previous)
        guard let previous else { return comparison }

        // --- Sáu chiều ------------------------------------------------------------------
        // Đi theo thứ tự của bản HIỆN TẠI, rồi thêm chiều chỉ có ở bản cũ vào cuối: một chiều
        // biến mất (người dùng bỏ `uniqueness_key`) cũng là một thay đổi đáng thấy.
        var seen = Set<String>()
        for entry in current.dimensions {
            seen.insert(entry.name)
            comparison.dimensions.append(DimensionDelta(
                name: entry.name, before: previous.dimension(entry.name)?.value,
                after: entry.value))
        }
        for entry in previous.dimensions where !seen.contains(entry.name) {
            comparison.dimensions.append(DimensionDelta(
                name: entry.name, before: entry.value, after: nil))
        }

        // --- Luật -----------------------------------------------------------------------
        //
        // Khoá là TIÊU ĐỀ luật, không phải chỉ số. Chỉ số đổi ngay khi người dùng chèn một luật
        // vào giữa tệp, và khi ấy bảng so sánh báo "mười luật mới trượt" trong khi thật ra
        // không luật nào đổi trạng thái.
        let before = Dictionary(previous.rules.map { ($0.title, $0) }) { first, _ in first }
        let after = Dictionary(current.rules.map { ($0.title, $0) }) { first, _ in first }
        for (title, entry) in after.sorted(by: { $0.key < $1.key }) {
            guard let old = before[title] else { continue }
            if old.passed, !entry.passed { comparison.newlyFailing.append(title) }
            if !old.passed, entry.passed { comparison.newlyPassing.append(title) }
        }

        // --- %null từng cột --------------------------------------------------------------
        let oldColumns = Dictionary(
            previous.columns.map { ($0.column, $0.nullPercent) }) { first, _ in first }
        for entry in current.columns {
            guard let old = oldColumns[entry.column] else { continue }
            // Ngưỡng 0,005 điểm phần trăm: dưới mức ấy thì hai con số làm tròn ra giống nhau,
            // và một bảng đầy dòng "0,00 → 0,00" che mất dòng đáng đọc.
            guard abs(entry.nullPercent - old) >= 0.005 else { continue }
            comparison.columns.append(ColumnDelta(
                column: entry.column, before: old, after: entry.nullPercent))
        }
        comparison.columns.sort { $0.delta > $1.delta }

        comparison.alerts = alerts(for: comparison, thresholds: thresholds)
        return comparison
    }

    /// Cảnh báo theo ngưỡng khai trong YAML.
    ///
    /// Vế *"lệch"* của đặc tả cố ý hiểu MỘT CHIỀU cho điểm số: chỉ TỤT mới cảnh báo. Điểm tăng
    /// vọt cũng là một thay đổi lớn, nhưng nó không phải thứ chặn một đợt dữ liệu — và một cổng
    /// kêu khi chất lượng tốt lên là cổng sẽ bị tắt. Số HÀNG thì ngược lại: đổi theo chiều nào
    /// cũng đáng ngờ, vì một đợt nhận dữ liệu bỗng gấp đôi thường là chép trùng.
    static func alerts(
        for comparison: Comparison, thresholds: QualityRules.Drift
    ) -> [String] {
        guard comparison.previous != nil else { return [] }
        var alerts: [String] = []

        if let limit = thresholds.maxTotalDrop, let delta = comparison.totalDelta,
           -delta > limit {
            alerts.append(String(
                format: "Điểm tổng tụt %.1f điểm (%.1f → %.1f), vượt ngưỡng %.1f khai ở `drift`.",
                -delta, comparison.previous?.total ?? 0, comparison.current.total ?? 0, limit))
        }
        if let limit = thresholds.maxDimensionDrop {
            for entry in comparison.dimensions {
                guard let delta = entry.delta, -delta > limit else { continue }
                alerts.append(String(
                    format: "Chiều «%@» tụt %.1f điểm (%.1f → %.1f), vượt ngưỡng %.1f.",
                    entry.vietnamese, -delta, entry.before ?? 0, entry.after ?? 0, limit))
            }
        }
        if let limit = thresholds.maxRowChangePercent, let previous = comparison.previous,
           previous.rowCount > 0 {
            let change = Double(comparison.current.rowCount - previous.rowCount)
                / Double(previous.rowCount) * 100
            if abs(change) > limit {
                alerts.append(String(
                    format: "Số hàng đổi %.1f%% (%d → %d), vượt ngưỡng %.1f%%.",
                    change, previous.rowCount, comparison.current.rowCount, limit))
            }
        }
        if let limit = thresholds.maxNullIncreasePercent {
            for entry in comparison.columns where entry.delta > limit {
                alerts.append(String(
                    format: "Cột «%@» tăng %.2f điểm phần trăm ô rỗng (%.2f%% → %.2f%%), "
                        + "vượt ngưỡng %.2f.",
                    entry.column, entry.delta, entry.before, entry.after, limit))
            }
        }
        if thresholds.warnOnNewFailure, !comparison.newlyFailing.isEmpty {
            alerts.append("\(comparison.newlyFailing.count) luật đang ĐẠT nay TRƯỢT: "
                + comparison.newlyFailing.prefix(5).joined(separator: " · ")
                + (comparison.newlyFailing.count > 5 ? " …" : ""))
        }
        return alerts
    }

    /// Chuỗi điểm tổng theo thời gian — dữ liệu cho biểu đồ xu hướng của panel và của báo cáo.
    public static func trend(_ log: QualityHistory.Log) -> [(date: Date, total: Double)] {
        log.snapshots.compactMap { snapshot in
            guard let date = snapshot.date, let total = snapshot.total else { return nil }
            return (date, total)
        }
    }
}
