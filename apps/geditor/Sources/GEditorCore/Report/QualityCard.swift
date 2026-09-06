import CryptoKit
import Foundation

/// Khối ```quality trong `.greport.md` — FR-DQR-003.
///
/// ```yaml
/// rules_file: .gquality.yaml
/// source: ban-hang-t8.csv       # để trống thì dùng nguồn của cả báo cáo
/// title: Chất lượng dữ liệu bán hàng tháng 8
/// rules: true                   # bảng luật pass/fail
/// chart: violations             # violations · dimensions · none
/// now: 2026-08-26               # cố định mốc để TIMELINESS tất định
/// fail_under: 90                # dưới ngưỡng thì thẻ điểm hiện màu cảnh báo
/// ```
///
/// ## Vì sao khối này CÓ cache còn khối ```query thì không
///
/// Preview dựng lại toàn bộ báo cáo mỗi lần người dùng ngừng gõ. Một khối `query` là một câu
/// SELECT — chạy lại nó tốn đúng một lượt quét. Một khối `quality` là **cả bộ luật cộng sáu
/// chiều điểm**: với 50 luật đó là một lượt quét gộp, một lượt cho mỗi `unique`, một lượt đếm ô
/// rỗng, một lượt cho mỗi cột ACCURACY, một lượt TIMELINESS. Trên một bảng lớn, gõ một dấu phẩy
/// vào phần văn xuôi sẽ trả giá bằng vài giây.
///
/// Nên kết quả được nhớ theo **hash(nội dung tệp luật) + dấu vân của nguồn**, đúng như đặc tả
/// đòi. Hai vế ấy là hai thứ DUY NHẤT đổi được kết quả — trừ `now:` của TIMELINESS, và chính vì
/// thế `now` cũng nằm trong khoá.
///
/// Tài liệu CHƯA LƯU thì không có dấu vân nào để so, nên **không nhớ**: thà chạy lại còn hơn
/// hiện một điểm số của phiên bản dữ liệu trước.
public struct QualityBlockSpec: Equatable, Sendable {

    public enum ChartMode: String, Equatable, Sendable {
        /// Cột số hàng vi phạm của các luật KHÔNG đạt — thứ nói được "sửa cái nào trước".
        case violations
        /// Cột điểm sáu chiều. Cùng số liệu với dải thanh phía trên, nhưng xuất ra ảnh được.
        case dimensions
        case none
    }

    /// Corpus JSONL — có mặt là khối chuyển sang **chế độ chunk** (FR-KNW-922).
    ///
    /// Hai chế độ dùng chung một hàng rào ```quality vì đặc tả FR-KNW-922 nói thẳng *"chạy được
    /// trong block ```quality"*, và vì cả hai chấm trên CÙNG khung sáu chiều DQR-002. Cái khác
    /// nhau là thứ được chấm: một bên là bảng, một bên là corpus chunk.
    public var corpus: String
    /// Cấu hình chế độ chunk. Chỉ có nghĩa khi `corpus` khác rỗng.
    public var chunk: ChunkQuality.Config
    /// Tệp đồ thị DOT — có mặt là khối chuyển sang **chế độ đồ thị** (FR-KNW-924).
    ///
    /// Ba chế độ trên cùng một hàng rào ```quality: bảng, corpus chunk, và đồ thị. Cả ba chấm
    /// trên CÙNG khung sáu chiều DQR-002, nên chúng chia nhau cả cách trình bày lẫn cổng CLI —
    /// tách thành ba loại khối là ba lần viết lại cùng một tấm thẻ điểm.
    public var graph: String
    public var graphConfig: GraphQuality.Config
    public var rulesFile: String
    /// Nguồn riêng của khối. Rỗng = dùng nguồn của cả báo cáo.
    public var source: String
    public var title: String
    public var showRules: Bool
    public var chart: ChartMode
    /// Mốc "bây giờ" cho chiều TIMELINESS. `nil` = lúc chạy.
    public var now: Date?
    /// Dưới ngưỡng này thì thẻ điểm đổi màu và khối bị tính là HỎNG (mã thoát CLI).
    public var failUnder: Double?

    public init(
        rulesFile: String = "", source: String = "", title: String = "",
        showRules: Bool = true, chart: ChartMode = .violations,
        now: Date? = nil, failUnder: Double? = nil,
        corpus: String = "", chunk: ChunkQuality.Config = .init(),
        graph: String = "", graphConfig: GraphQuality.Config = .init()
    ) {
        self.corpus = corpus
        self.chunk = chunk
        self.graph = graph
        self.graphConfig = graphConfig
        self.rulesFile = rulesFile
        self.source = source
        self.title = title
        self.showRules = showRules
        self.chart = chart
        self.now = now
        self.failUnder = failUnder
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    static let knownKeys: Set<String> = [
        "rules_file", "rules", "source", "title", "show_rules", "chart", "now", "fail_under",
    ]

    /// Khoá chỉ có nghĩa ở chế độ chunk. Tách riêng để báo lỗi nói được VÌ SAO một khoá đúng
    /// chính tả vẫn bị từ chối — "khoá này chỉ dùng khi có «corpus»" hữu ích hơn "khoá lạ".
    static let chunkKeys: Set<String> = [
        "corpus", "text_field", "source_field", "id_field", "max_tokens", "min_tokens",
        "chars_per_token", "near_dup", "shingle", "boilerplate_repeats", "near_dup_limit",
        "sources",
    ]

    /// Khoá chỉ có nghĩa ở chế độ đồ thị — FR-KNW-924.
    static let graphKeys: Set<String> = [
        "graph", "require_node", "require_edge", "label_similarity", "fuzzy_limit",
    ]

    public static func parse(_ yaml: String) throws -> QualityBlockSpec {
        let root: YAMLValue
        do {
            root = try YAMLReader.parse(yaml)
        } catch let failure as YAMLReader.Failure {
            throw Failure(message: "khối quality không đọc được: \(failure.message)")
        }
        let isChunk = root["corpus"]?.stringValue?.isEmpty == false
        let isGraph = root["graph"]?.stringValue?.isEmpty == false
        let allKeys = knownKeys.union(chunkKeys).union(graphKeys)
        for key in root.mappingKeys where !allKeys.contains(key) {
            throw Failure(message: "khối quality có khoá lạ «\(key)» — các khoá hiểu được: "
                + allKeys.sorted().joined(separator: ", "))
        }
        guard !(isChunk && isGraph) else {
            throw Failure(message: "khối quality khai cả «corpus» lẫn «graph» — một khối chấm "
                + "MỘT thứ; tách thành hai khối")
        }
        if !isChunk, let stray = root.mappingKeys.first(where: {
            chunkKeys.contains($0) && $0 != "corpus"
        }) {
            throw Failure(message: "khối quality: khoá «\(stray)» chỉ dùng ở chế độ chunk — "
                + "thêm «corpus: <tệp>.jsonl» thì nó mới có nghĩa (FR-KNW-922)")
        }
        if !isGraph, let stray = root.mappingKeys.first(where: {
            graphKeys.contains($0) && $0 != "graph"
        }) {
            throw Failure(message: "khối quality: khoá «\(stray)» chỉ dùng ở chế độ đồ thị — "
                + "thêm «graph: <tệp>.dot» thì nó mới có nghĩa (FR-KNW-924)")
        }

        var spec = QualityBlockSpec()
        if isChunk { return try parseChunk(root, into: &spec) }
        if isGraph { return try parseGraph(root, into: &spec) }
        // `rules` và `rules_file` là một tên gọi hai kiểu — nhưng `rules: true` là bật/tắt BẢNG
        // luật, nên chỉ nhận `rules` làm đường dẫn khi nó là chuỗi.
        if let file = root["rules_file"]?.stringValue {
            spec.rulesFile = file
        } else if let value = root["rules"], value.boolValue == nil,
                  let file = value.stringValue {
            spec.rulesFile = file
        }
        guard !spec.rulesFile.isEmpty else {
            throw Failure(message: "khối quality thiếu khoá «rules_file» — nó trỏ tới tệp "
                + "`.gquality.yaml` chứa bộ luật, giải theo đường dẫn tương đối với chính tệp "
                + "báo cáo")
        }
        if let source = root["source"]?.stringValue { spec.source = source }
        if let title = root["title"]?.stringValue { spec.title = title }
        if let show = root["show_rules"]?.boolValue ?? root["rules"]?.boolValue {
            spec.showRules = show
        }
        if let name = root["chart"]?.stringValue {
            guard let mode = ChartMode(rawValue: name.lowercased()) else {
                throw Failure(message: "khối quality: chart «\(name)» không hiểu — có: "
                    + "violations, dimensions, none")
            }
            spec.chart = mode
        } else if let on = root["chart"]?.boolValue {
            spec.chart = on ? .violations : .none
        }
        if let text = root["now"]?.stringValue {
            guard let date = QualityCard.parseDay(text) else {
                throw Failure(message: "khối quality: «now: \(text)» không đọc được — "
                    + "cần dạng YYYY-MM-DD hoặc YYYY-MM-DD HH:MM:SS")
            }
            spec.now = date
        }
        if let threshold = root["fail_under"]?.doubleValue {
            guard (0...100).contains(threshold) else {
                throw Failure(message: "khối quality: fail_under phải trong 0…100, "
                    + "nhận \(threshold)")
            }
            spec.failUnder = threshold
        }
        return spec
    }

    /// Nhánh chế độ đồ thị — FR-KNW-924.
    private static func parseGraph(
        _ root: YAMLValue, into spec: inout QualityBlockSpec
    ) throws -> QualityBlockSpec {
        spec.graph = root["graph"]?.stringValue ?? ""
        if let title = root["title"]?.stringValue { spec.title = title }
        if let threshold = root["fail_under"]?.doubleValue {
            guard (0...100).contains(threshold) else {
                throw Failure(message: "khối quality: fail_under phải trong 0…100, "
                    + "nhận \(threshold)")
            }
            spec.failUnder = threshold
        }
        var config = GraphQuality.Config()
        if let list = root["require_node"]?.sequenceValue {
            config.requiredNodeKeys = list.compactMap(\.stringValue)
        } else if let one = root["require_node"]?.stringValue {
            config.requiredNodeKeys = [one]
        }
        if let list = root["require_edge"]?.sequenceValue {
            config.requiredEdgeKeys = list.compactMap(\.stringValue)
        } else if let one = root["require_edge"]?.stringValue {
            config.requiredEdgeKeys = [one]
        }
        if let value = root["label_similarity"]?.doubleValue {
            guard value > 0.5, value <= 1 else {
                throw Failure(message: "khối quality: label_similarity là ngưỡng giống nhau, "
                    + "phải trong (0,5…1] — dưới 0,5 thì gần như mọi nhãn đều «gần nhau»; "
                    + "nhận \(value)")
            }
            config.labelSimilarity = value
        }
        if let value = root["fuzzy_limit"]?.doubleValue {
            guard value >= 0 else {
                throw Failure(message: "khối quality: fuzzy_limit phải ≥ 0 (0 = bỏ trần), "
                    + "nhận \(value)")
            }
            config.fuzzyLimit = Int(value)
        }
        spec.graphConfig = config
        return spec
    }

    /// Nhánh chế độ chunk — FR-KNW-922.
    private static func parseChunk(
        _ root: YAMLValue, into spec: inout QualityBlockSpec
    ) throws -> QualityBlockSpec {
        spec.corpus = root["corpus"]?.stringValue ?? ""
        if let title = root["title"]?.stringValue { spec.title = title }
        if let threshold = root["fail_under"]?.doubleValue {
            guard (0...100).contains(threshold) else {
                throw Failure(message: "khối quality: fail_under phải trong 0…100, "
                    + "nhận \(threshold)")
            }
            spec.failUnder = threshold
        }

        var config = ChunkQuality.Config()
        if let field = root["text_field"]?.stringValue { config.textField = field }
        if let field = root["source_field"]?.stringValue { config.sourceField = field }
        if let field = root["id_field"]?.stringValue { config.idField = field }
        if let value = root["max_tokens"]?.doubleValue { config.maxTokens = Int(value) }
        if let value = root["min_tokens"]?.doubleValue { config.minTokens = Int(value) }
        if let ratio = root["chars_per_token"]?.doubleValue {
            guard ratio > 0 else {
                throw Failure(message: "khối quality: chars_per_token phải dương, nhận \(ratio)")
            }
            config.estimator = .characters(perToken: ratio)
        }
        if let value = root["near_dup"]?.doubleValue {
            guard value > 0, value <= 1 else {
                throw Failure(message: "khối quality: near_dup là ngưỡng Jaccard, phải trong "
                    + "(0…1], nhận \(value)")
            }
            config.nearDuplicate = value
        }
        if let value = root["shingle"]?.doubleValue {
            guard value >= 1 else {
                throw Failure(message: "khối quality: shingle phải ≥ 1, nhận \(value)")
            }
            config.shingle = Int(value)
        }
        if let value = root["boilerplate_repeats"]?.doubleValue {
            guard value >= 2 else {
                throw Failure(message: "khối quality: boilerplate_repeats phải ≥ 2 — lặp một "
                    + "lần thì không có gì để gọi là lặp; nhận \(value)")
            }
            config.boilerplateRepeats = Int(value)
        }
        if let value = root["near_dup_limit"]?.doubleValue {
            guard value >= 0 else {
                throw Failure(message: "khối quality: near_dup_limit phải ≥ 0 (0 = bỏ trần), "
                    + "nhận \(value)")
            }
            config.nearDuplicateLimit = Int(value)
        }
        if let list = root["sources"]?.sequenceValue {
            config.declaredSources = list.compactMap(\.stringValue)
        }
        spec.chunk = config
        return spec
    }
}

/// Chạy và vẽ thẻ điểm chất lượng cho một khối ```quality.
public enum QualityCard {

    public struct Result: Equatable, Sendable {
        public var report: QualityEngine.Report
        public var score: QualityScore
        /// Bộ luật đã dùng — mang theo cả ngưỡng `drift` cho FR-DQR-004.
        public var rules: QualityRules
        /// Đường dẫn tệp luật đã dùng — in ra dưới thẻ điểm để người đọc biết chuẩn nào đang áp.
        public var rulesPath: String
        public var sourcePath: String?

        public init(
            report: QualityEngine.Report, score: QualityScore, rules: QualityRules,
            rulesPath: String, sourcePath: String?
        ) {
            self.report = report
            self.score = score
            self.rules = rules
            self.rulesPath = rulesPath
            self.sourcePath = sourcePath
        }
    }

    // MARK: - Chạy

    /// Chấm điểm cho một khối, có đi qua cache nếu được đưa.
    ///
    /// `basePath` là thư mục của TỆP BÁO CÁO — `rules_file` và `source` giải tương đối với nó,
    /// không phải với thư mục đang đứng. Một báo cáo và dữ liệu của nó nằm cạnh nhau trong kho
    /// mã; chạy nó từ thư mục khác mà hỏng là thứ khiến người ta bỏ luôn đường dẫn tương đối.
    public static func run(
        _ spec: QualityBlockSpec,
        basePath: String?,
        fallbackBuffer: TextBuffer,
        fallbackSourcePath: String?,
        dialect: CSVDialect,
        cache: QualityCache? = nil,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        let rulesPath = resolve(spec.rulesFile, relativeTo: basePath)
        guard let rulesText = try? String(contentsOfFile: rulesPath, encoding: .utf8) else {
            throw QualityBlockSpec.Failure(message:
                "không đọc được tệp luật «\(rulesPath)»")
        }
        let rules: QualityRules
        do {
            rules = try QualityRules.load(fromYAML: rulesText)
        } catch let failure as QualityRules.Failure {
            throw QualityBlockSpec.Failure(message:
                "tệp luật \((rulesPath as NSString).lastPathComponent): \(failure.message)")
        }

        // Nguồn: khoá `source` của chính khối, nếu không thì nguồn của cả báo cáo.
        let buffer: TextBuffer
        let sourcePath: String?
        if spec.source.isEmpty {
            buffer = fallbackBuffer
            sourcePath = fallbackSourcePath
        } else {
            let path = resolve(spec.source, relativeTo: basePath)
            guard let bytes = FileManager.default.contents(atPath: path) else {
                throw QualityBlockSpec.Failure(message: "không đọc được nguồn «\(path)»")
            }
            buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
            sourcePath = path
        }

        let now = spec.now ?? Date()
        let key = QualityCache.Key(
            rulesText: rulesText, sourcePath: sourcePath, now: spec.now, today: now)
        if let cache, let key, let hit = cache.value(for: key) {
            return Result(report: hit.report, score: hit.score, rules: rules,
                          rulesPath: rulesPath, sourcePath: sourcePath)
        }

        let report = try QualityEngine.evaluate(
            rules, in: buffer, dialect: dialect, sourcePath: sourcePath,
            cancelToken: cancelToken)
        let score = try QualityScorer.score(
            report, rules: rules, in: buffer, dialect: dialect, sourcePath: sourcePath,
            now: now, cancelToken: cancelToken)
        if let cache, let key {
            cache.store(QualityCache.Entry(report: report, score: score), for: key)
        }
        return Result(report: report, score: score, rules: rules,
                      rulesPath: rulesPath, sourcePath: sourcePath)
    }

    static func resolve(_ path: String, relativeTo base: String?) -> String {
        guard !(path as NSString).isAbsolutePath, let base, !base.isEmpty else { return path }
        return (base as NSString).appendingPathComponent(path)
    }

    /// `YYYY-MM-DD` (hoặc kèm giờ) theo UTC — dùng cho `now:` của khối và `--now` của CLI.
    public static func parseDay(_ text: String) -> Date? {
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    // MARK: - Kết xuất

    /// Thẻ điểm thành HTML. Không script, không ảnh ngoài — cùng luật tự chứa của FR-RPT-005.
    ///
    /// ## Công thức nằm trong TRANG, không nằm trong tooltip
    ///
    /// Panel trong app để công thức ở tooltip vì ở đó có con trỏ chuột. Một báo cáo thì được IN
    /// ra, gửi qua email, đọc trên điện thoại — không có chỗ nào hover được. NFR-DQR-03 đòi
    /// *"công thức từng chiều in trong kết quả"*, nên nó phải là chữ thật trên trang: một khối
    /// `<details>` mở ra được, đứng ngay dưới dải thanh điểm.
    ///
    /// Lý do y hệt cho **chiều không chấm được**: lý do của nó in thành dòng chữ dưới dải thanh,
    /// không phải một ô trống. Ô trống thì người đọc hiểu là "không có vấn đề gì".
    public static func html(
        _ result: Result, spec: QualityBlockSpec, style: NumberStyle, ruleLimit: Int = 200,
        chartWidth: Double = 720, chartHeight: Double = 300
    ) -> String {
        let score = result.score
        let total = score.total
        let threshold = spec.failUnder
        let state = self.state(total: total, threshold: threshold)

        var facts: [String] = ["\(score.rowCount) hàng",
                               "\(result.report.results.count) luật"]
        let errors = result.report.failedErrors.count
        let warnings = result.report.failedWarnings.count
        facts.append(errors == 0 && warnings == 0
            ? "tất cả ĐẠT"
            : "\(errors) lỗi · \(warnings) cảnh báo")
        if let threshold {
            facts.append("ngưỡng \(format(threshold))")
        }
        facts.append("luật: " + (result.rulesPath as NSString).lastPathComponent)
        var out = header(score: score, state: state, title: spec.title, facts: facts)

        out += dimensionBars(score)
        out += unscoredNote(score)
        out += formulas(score)
        out += "</section>"

        // --- Biểu đồ --------------------------------------------------------------------
        if let svg = chart(result, spec: spec, style: style,
                           width: chartWidth, height: chartHeight) {
            out += svg
        }

        // --- Bảng luật -------------------------------------------------------------------
        if spec.showRules, !result.report.results.isEmpty {
            out += ruleTable(result.report, limit: ruleLimit)
        }
        return out
    }

    // MARK: - Phần trình bày dùng chung

    /// Đầu thẻ điểm: con số lớn, màu trạng thái, và dòng "sự thật" tóm tắt.
    ///
    /// Bốn hàm dưới đây tách ra khỏi `html(_:spec:…)` khi FR-KNW-922 cần vẽ MỘT thẻ điểm khác
    /// trên CÙNG khung sáu chiều. Hai bản vẽ riêng cho cùng một khung là hai bản sẽ trôi khỏi
    /// nhau — và thứ trôi trước tiên bao giờ cũng là câu "chiều này không chấm được", đúng câu
    /// đắt nhất của cả khung.
    static func header(score: QualityScore, state: String, title: String, facts: [String])
        -> String {
        var out = "<section class=\"g-score g-score-\(state)\">"
        if !title.isEmpty {
            out += "<h3 class=\"g-score-title\">" + MarkdownHTML.escape(title) + "</h3>"
        }
        out += "<div class=\"g-score-head\"><div class=\"g-score-total\">"
            + "<span class=\"g-score-value\">"
            + (score.total.map { format($0) } ?? "—") + "</span>"
            + "<span class=\"g-score-max\">/100</span></div>"
        out += "<p class=\"g-score-facts\">" + MarkdownHTML.escape(
            facts.joined(separator: " · ")) + "</p></div>"
        return out
    }

    /// Màu trạng thái của thẻ: theo ngưỡng khai trong khối, nếu không thì theo mốc 90/70.
    static func state(total: Double?, threshold: Double?) -> String {
        if let total, let threshold { return total < threshold ? "bad" : "good" }
        if let total { return total >= 90 ? "good" : (total >= 70 ? "warn" : "bad") }
        return "warn"
    }

    static func dimensionBars(_ score: QualityScore) -> String {
        var out = "<ul class=\"g-dims\">"
        for dimension in score.dimensions {
            let name = MarkdownHTML.escape(dimension.dimension.vietnamese)
            if let value = dimension.value {
                let width = max(0, min(100, value))
                out += "<li><span class=\"g-dim-name\">\(name)</span>"
                    + "<span class=\"g-dim-bar\"><i style=\"width:\(format(width, digits: 1))%\">"
                    + "</i></span>"
                    + "<span class=\"g-dim-value\">\(format(value))</span></li>"
            } else {
                out += "<li class=\"g-dim-unscored\"><span class=\"g-dim-name\">\(name)</span>"
                    + "<span class=\"g-dim-bar\"><i style=\"width:0%\"></i></span>"
                    + "<span class=\"g-dim-value\">—</span></li>"
            }
        }
        return out + "</ul>"
    }

    /// Chiều bị LOẠI: nói ra thành chữ, ngay dưới dải thanh — không giấu trong chú thích.
    static func unscoredNote(_ score: QualityScore) -> String {
        let unscored = score.unscored
        guard !unscored.isEmpty else { return "" }
        var out = "<p class=\"g-note g-unscored\">"
            + MarkdownHTML.escape(
                "\(unscored.count) chiều KHÔNG chấm được và bị loại khỏi điểm tổng "
                + "(không được tính là 100): ")
        out += unscored.map {
            "<strong>" + MarkdownHTML.escape($0.dimension.vietnamese) + "</strong> — "
                + MarkdownHTML.escape($0.note ?? $0.detail)
        }.joined(separator: "; ")
        return out + "</p>"
    }

    /// Công thức — NFR-DQR-03 đòi người đọc tính lại được bằng tay.
    static func formulas(_ score: QualityScore) -> String {
        var out = "<details class=\"g-formulas\"><summary>Công thức chấm điểm</summary><dl>"
        for dimension in score.dimensions {
            out += "<dt>" + MarkdownHTML.escape(dimension.dimension.vietnamese)
                + " (trọng số \(format(dimension.weight, digits: 2)))</dt>"
                + "<dd><code>" + MarkdownHTML.escape(dimension.formula) + "</code><br>"
                + MarkdownHTML.escape(dimension.detail) + "</dd>"
        }
        out += "</dl><p class=\"g-note\">Điểm tổng là trung bình có trọng số của những chiều "
            + "chấm được. Mốc thời gian dùng cho chiều «Tươi mới»: "
            + MarkdownHTML.escape(isoSeconds(score.evaluatedAt)) + ".</p></details>"
        return out
    }

    static func ruleTable(_ report: QualityEngine.Report, limit: Int) -> String {
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><thead><tr>"
            + "<th>Mức</th><th>Luật</th><th>Vi phạm</th><th>Tỷ lệ</th></tr></thead><tbody>"
        // Luật KHÔNG ĐẠT lên trước: một bảng năm mươi dòng mà ba dòng đáng đọc nằm rải rác thì
        // người đọc phải dò từng dòng. Thứ tự trong tệp vẫn giữ được TRONG từng nhóm.
        let ordered = report.results.enumerated().sorted { left, right in
            let a = rank(left.element), b = rank(right.element)
            return a == b ? left.offset < right.offset : a < b
        }.map(\.element)
        for result in ordered.prefix(limit) {
            let mark: String
            let cssClass: String
            if result.failure != nil {
                // Trạng thái THỨ BA: không đạt cũng không trượt — luật không chạy được.
                mark = "hỏng"
                cssClass = "broken"
            } else if result.passed {
                mark = "đạt"
                cssClass = "pass"
            } else {
                mark = result.rule.severity == .error ? "lỗi" : "cảnh báo"
                cssClass = result.rule.severity == .error ? "fail" : "warn"
            }
            out += "<tr class=\"g-rule-\(cssClass)\"><td class=\"txt\">"
                + MarkdownHTML.escape(mark) + "</td><td class=\"txt\">"
                + MarkdownHTML.escape(result.failure ?? result.rule.title) + "</td>"
                + "<td class=\"num\">"
                + (result.failure != nil ? "—" : String(result.violations)) + "</td>"
                + "<td class=\"num\">"
                + (result.failure != nil ? "—"
                    : String(format: "%.2f%%", result.violationPercent)) + "</td></tr>"
        }
        out += "</tbody></table>"
        if report.results.count > limit {
            out += "<p class=\"g-note\">Bảng hiện \(limit) / \(report.results.count) luật.</p>"
        }
        out += "</div>"
        return out
    }

    private static func rank(_ result: QualityEngine.RuleResult) -> Int {
        if result.failure != nil { return 1 }
        if result.passed { return 3 }
        return result.rule.severity == .error ? 0 : 2
    }

    static func chart(
        _ result: Result, spec: QualityBlockSpec, style: NumberStyle,
        width: Double, height: Double
    ) -> String? {
        let points: [ChartData.Point]
        let title: String
        switch spec.chart {
        case .none:
            return nil
        case .dimensions:
            points = result.score.dimensions.enumerated().compactMap { index, dimension in
                guard let value = dimension.value else { return nil }
                return ChartData.Point(
                    x: Double(index), y: value, label: dimension.dimension.vietnamese)
            }
            title = "Điểm sáu chiều"
        case .violations:
            // Chỉ luật KHÔNG đạt, xếp theo số hàng vi phạm giảm dần: biểu đồ này trả lời đúng
            // một câu hỏi — *"sửa cái nào trước"*. Vẽ cả luật đạt (cột 0) là đẩy câu trả lời ấy
            // ra rìa hình.
            let failing = result.report.results
                .filter { $0.failure == nil && !$0.passed && $0.violations > 0 }
                .sorted { $0.violations > $1.violations }
                .prefix(12)
            points = failing.enumerated().map { index, entry in
                ChartData.Point(
                    x: Double(index), y: Double(entry.violations),
                    label: entry.rule.column ?? entry.rule.title)
            }
            title = "Số hàng vi phạm theo luật"
        }
        guard !points.isEmpty else { return nil }
        let series = ChartData.Series(
            name: title, points: points, originalCount: points.count)
        let layout = ChartRender.Layout(width: width, height: height)
        let chartStyle = ChartRender.Style(palette: .gLight, numbers: style)
        let primitives = ChartRender.primitives(
            kind: .bar, series: series, layout: layout, title: title, style: chartStyle)
        return "<figure class=\"g-chart\">"
            + ChartRender.svg(primitives, layout: layout, style: chartStyle) + "</figure>"
    }

    /// CSS riêng của thẻ điểm — ghép vào `ReportRenderer.stylesheet`.
    static let stylesheet = """
        .g-score { margin: 1.4em 0; padding: 14px 16px; border-radius: 8px;
                   border: 1px solid #e0e0e0; background: #fafafa; }
        .g-score-title { margin: 0 0 8px; font-size: 1.05em; }
        .g-score-head { display: flex; align-items: baseline; gap: 14px; flex-wrap: wrap; }
        .g-score-value { font-size: 2.4em; font-weight: 700;
                         font-variant-numeric: tabular-nums; }
        .g-score-max { font-size: 1em; color: #666; }
        .g-score-facts { margin: 0; font-size: 0.88em; color: #555; }
        .g-score-good .g-score-value { color: #1d6b3a; }
        .g-score-warn .g-score-value { color: #8a5a00; }
        .g-score-bad .g-score-value { color: #a12a12; }
        .g-dims { list-style: none; margin: 12px 0 0; padding: 0; display: grid;
                  grid-template-columns: max-content 1fr max-content; gap: 4px 10px;
                  align-items: center; }
        .g-dims li { display: contents; }
        .g-dim-name { font-size: 0.88em; }
        .g-dim-bar { height: 9px; border-radius: 5px; background: #e4e4e4;
                     overflow: hidden; min-width: 60px; }
        .g-dim-bar i { display: block; height: 100%; background: #3a7bd5; }
        .g-dim-value { font-size: 0.88em; font-variant-numeric: tabular-nums;
                       text-align: right; }
        .g-dim-unscored .g-dim-name, .g-dim-unscored .g-dim-value { color: #8a5a00; }
        .g-unscored { margin-top: 10px; }
        .g-formulas { margin-top: 12px; font-size: 0.88em; }
        .g-formulas summary { cursor: pointer; }
        .g-formulas dt { font-weight: 600; margin-top: 8px; }
        .g-formulas dd { margin: 2px 0 0 1.2em; color: #555; }
        .g-rules tr.g-rule-fail td { background: #fdf1ee; }
        .g-rules tr.g-rule-warn td, .g-rules tr.g-rule-broken td { background: #fdf7e8; }
        @media (prefers-color-scheme: dark) {
          .g-score { background: #232325; border-color: #3a3a3c; }
          .g-score-facts, .g-formulas dd, .g-score-max { color: #a8a8a8; }
          .g-score-good .g-score-value { color: #6fcf8f; }
          .g-score-warn .g-score-value { color: #e3b341; }
          .g-score-bad .g-score-value { color: #f0846a; }
          .g-dim-bar { background: #3a3a3c; }
          .g-rules tr.g-rule-fail td { background: #3a201a; }
          .g-rules tr.g-rule-warn td, .g-rules tr.g-rule-broken td { background: #33290f; }
        }
        @media print {
          .g-score { break-inside: avoid; page-break-inside: avoid; }
          /* `<details>` đóng thì phần công thức KHÔNG lên giấy — mà NFR-DQR-03 đòi công thức
             nằm trong kết quả. Nên khi in, nó luôn mở. */
          .g-formulas > *:not(summary) { display: revert !important; }
          details { display: block; }
          details > summary { list-style: none; }
        }
        """

    // MARK: - Định dạng

    static func format(_ value: Double, digits: Int = 0) -> String {
        String(format: "%.\(digits)f", value)
    }

    static func isoSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date) + "Z"
    }
}

/// Nhớ kết quả chấm điểm giữa các lần dựng preview — FR-DQR-003 (*"cache theo hash(rules +
/// trạng thái nguồn)"*).
///
/// Là một ĐỐI TƯỢNG được truyền vào, không phải một biến toàn cục. Một cache dùng chung toàn
/// tiến trình sẽ sống qua cả những lượt chạy đáng lẽ phải độc lập — CLI chạy 63 tỉnh, bài kiểm
/// chạy nối nhau — và khi ấy một lỗi cache biểu hiện thành "bài kiểm thứ hai đọc kết quả của
/// bài thứ nhất", loại lỗi khó truy nhất.
public final class QualityCache: @unchecked Sendable {

    public struct Key: Hashable, Sendable {
        /// Băm nội dung tệp luật, không phải đường dẫn: sửa luật mà giữ tên là chuyện thường.
        public var rulesDigest: String
        /// Cỡ + thời điểm sửa của nguồn. `nil` khi tài liệu chưa lưu — xem `init?`.
        public var sourceSize: Int
        public var sourceModified: Double
        public var now: Double

        /// Một NGÀY, tính bằng giây.
        static let day: Double = 86_400

        /// `nil` khi KHÔNG nhớ được: nguồn chưa có trên đĩa thì không có gì để so.
        public init?(rulesText: String, sourcePath: String?, now: Date?, today: Date = Date()) {
            guard let sourcePath,
                  let fingerprint = QueryCatalog.Fingerprint.read(path: sourcePath)
            else { return nil }
            var hasher = SHA256()
            hasher.update(data: Data(rulesText.utf8))
            rulesDigest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            sourceSize = fingerprint.size
            sourceModified = fingerprint.modified
            // Khối khai `now:` thì mốc ấy vào thẳng khoá. Không khai thì mốc là "lúc chạy", và
            // một kết quả nhớ lại sẽ mang mốc của lần chạy ĐẦU — nên khoá chốt theo NGÀY.
            //
            // Ngày là đúng độ phân giải, không phải một con số chọn bừa: ngưỡng của chiều
            // TIMELINESS khai bằng `max_age_days`, nên điểm chỉ đổi khi sang ngày mới. Chốt
            // theo giây thì cache không bao giờ trúng; chốt theo tuần thì một báo cáo mở qua
            // đêm sẽ nói dữ liệu còn tươi trong khi nó đã quá hạn.
            self.now = now.map { $0.timeIntervalSince1970 }
                ?? (today.timeIntervalSince1970 / Key.day).rounded(.down) * Key.day
        }
    }

    public struct Entry: Sendable {
        public var report: QualityEngine.Report
        public var score: QualityScore

        public init(report: QualityEngine.Report, score: QualityScore) {
            self.report = report
            self.score = score
        }
    }

    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    /// Trần số mục nhớ. Một báo cáo có vài khối quality; giữ 32 là đủ rộng cho cả một phiên sửa,
    /// và đủ hẹp để không giữ lại kết quả của những bảng đã đóng từ lâu.
    private let capacity: Int
    private var order: [Key] = []

    public init(capacity: Int = 32) {
        self.capacity = max(1, capacity)
    }

    public func value(for key: Key) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    public func store(_ entry: Entry, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        if entries[key] == nil {
            order.append(key)
            while order.count > capacity {
                entries.removeValue(forKey: order.removeFirst())
            }
        }
        entries[key] = entry
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        order.removeAll()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
