import Foundation

/// Khối ```retrieval trong `.greport.md` — FR-KNW-919.
///
/// Đặc tả đòi *"kết quả đổ vào .greport.md thành báo cáo đánh giá **tái lập được**"*. Chữ "tái
/// lập được" là điều kiện, và nó quyết định hình dạng của khối này: mọi thứ cần để chạy lại
/// phải nằm TRONG tài liệu — corpus nào, bộ đánh giá nào, k1/b/tokenizer nào, k bằng mấy.
///
/// ```
/// ```retrieval
/// corpus: chunks.jsonl
/// golden: bo-danh-gia.jsonl
/// k: 10
/// text_field: text
/// k1: 1.2
/// b: 0.75
/// compare:
///   k1: 1.6
///   b: 0.3
/// worst: 15
/// ```
/// ```
///
/// Khoá `compare` là vế *"so sánh song song 2 cấu hình"*: nó khai những gì KHÁC với cấu hình
/// chính, phần còn lại kế thừa. Khai lại toàn bộ hai cấu hình thì hai bên sẽ lệch nhau ở một
/// khoá nào đó mà không ai để ý, và bảng delta khi ấy đo hai thứ khác nhau.
public struct RetrievalBlockSpec: Equatable, Sendable {

    public var corpus: String
    public var golden: String
    public var k: Int
    public var title: String
    /// Số câu TỆ NHẤT hiện trong bảng. 0 = không hiện bảng câu.
    public var worst: Int
    public var options: BM25Index.Options
    /// Cấu hình thứ hai để so, `nil` = không so.
    public var compare: BM25Index.Options?
    /// Tệp điểm ngoài để so — FR-KNW-921. Loại trừ nhau với `compare`.
    public var external: String
    /// Ép chiều điểm ngoài; `nil` = suy từ TÊN TRƯỜNG trong tệp.
    public var externalOrder: ExternalScores.Order?
    /// Dưới ngưỡng này thì khối bị tính là HỎNG (mã thoát CLI).
    public var failUnder: Double?

    public init(
        corpus: String = "", golden: String = "", k: Int = 10, title: String = "",
        worst: Int = 15, options: BM25Index.Options = .init(),
        compare: BM25Index.Options? = nil, external: String = "",
        externalOrder: ExternalScores.Order? = nil, failUnder: Double? = nil
    ) {
        self.corpus = corpus
        self.golden = golden
        self.k = k
        self.title = title
        self.worst = worst
        self.options = options
        self.compare = compare
        self.external = external
        self.externalOrder = externalOrder
        self.failUnder = failUnder
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    static let knownKeys: Set<String> = [
        "corpus", "golden", "k", "title", "worst", "text_field", "id_field", "k1", "b",
        "fold_diacritics", "compare", "fail_under", "external", "external_order",
    ]

    static let tuningKeys: Set<String> = [
        "text_field", "id_field", "k1", "b", "fold_diacritics",
    ]

    public static func parse(_ yaml: String) throws -> RetrievalBlockSpec {
        let root: YAMLValue
        do {
            root = try YAMLReader.parse(yaml)
        } catch let failure as YAMLReader.Failure {
            throw Failure(message: "khối retrieval không đọc được: \(failure.message)")
        }
        for key in root.mappingKeys where !knownKeys.contains(key) {
            throw Failure(message: "khối retrieval có khoá lạ «\(key)» — các khoá hiểu được: "
                + knownKeys.sorted().joined(separator: ", "))
        }
        var spec = RetrievalBlockSpec()
        spec.corpus = root["corpus"]?.stringValue ?? ""
        spec.golden = root["golden"]?.stringValue ?? ""
        guard !spec.corpus.isEmpty else {
            throw Failure(message: "khối retrieval thiếu khoá «corpus» — nó trỏ tới tệp JSONL "
                + "chứa chunk, giải theo đường dẫn tương đối với chính tệp báo cáo")
        }
        guard !spec.golden.isEmpty else {
            throw Failure(message: "khối retrieval thiếu khoá «golden» — nó trỏ tới bộ đánh giá "
                + "(CSV hoặc JSONL: câu hỏi + danh sách id chunk kỳ vọng)")
        }
        if let title = root["title"]?.stringValue { spec.title = title }
        if let value = root["k"]?.doubleValue {
            guard value >= 1 else {
                throw Failure(message: "khối retrieval: k phải ≥ 1, nhận \(value)")
            }
            spec.k = Int(value)
        }
        if let value = root["worst"]?.doubleValue {
            guard value >= 0 else {
                throw Failure(message: "khối retrieval: worst phải ≥ 0, nhận \(value)")
            }
            spec.worst = Int(value)
        }
        if let threshold = root["fail_under"]?.doubleValue {
            guard (0...1).contains(threshold) else {
                throw Failure(message: "khối retrieval: fail_under là recall@k nên nó nằm trong "
                    + "0…1, nhận \(threshold)")
            }
            spec.failUnder = threshold
        }
        spec.options = try tuning(root, base: BM25Index.Options())
        if let compare = root["compare"] {
            guard !compare.mappingKeys.isEmpty else {
                throw Failure(message: "khối retrieval: «compare» phải là một bảng khoá — nó "
                    + "khai những gì KHÁC với cấu hình chính, phần còn lại kế thừa")
            }
            for key in compare.mappingKeys where !tuningKeys.contains(key) {
                throw Failure(message: "khối retrieval: «compare» chỉ đổi được "
                    + tuningKeys.sorted().joined(separator: ", ") + " — khoá «\(key)» thì không")
            }
            spec.compare = try tuning(compare, base: spec.options)
        }
        if let external = root["external"]?.stringValue, !external.isEmpty {
            // Một khối so ĐÚNG MỘT cặp. Khai cả hai thì bảng ba cột nói về ba lượt chạy khác
            // nhau mà chỉ có hai đầu đề — cùng luật với khối ```quality của FR-KNW-924.
            guard spec.compare == nil else {
                throw Failure(message: "khối retrieval khai cả «compare» lẫn «external» — một "
                    + "khối so đúng một cặp; tách thành hai khối")
            }
            spec.external = external
        }
        if let raw = root["external_order"]?.stringValue {
            guard spec.external.isEmpty == false else {
                throw Failure(message: "khối retrieval: «external_order» chỉ có nghĩa khi có "
                    + "«external»")
            }
            guard let order = ExternalScores.Order(rawValue: raw) else {
                throw Failure(message: "khối retrieval: «external_order» nhận «descending» "
                    + "(điểm lớn hơn xếp trên) hoặc «ascending» (khoảng cách/hạng), nhận «"
                    + raw + "»")
            }
            spec.externalOrder = order
        }
        return spec
    }

    private static func tuning(
        _ root: YAMLValue, base: BM25Index.Options
    ) throws -> BM25Index.Options {
        var options = base
        if let field = root["text_field"]?.stringValue { options.textField = field }
        if let field = root["id_field"]?.stringValue { options.idField = field }
        if let value = root["k1"]?.doubleValue {
            guard value >= 0 else {
                throw Failure(message: "khối retrieval: k1 phải ≥ 0, nhận \(value)")
            }
            options.k1 = value
        }
        if let value = root["b"]?.doubleValue {
            guard (0...1).contains(value) else {
                throw Failure(message: "khối retrieval: b nằm trong 0…1 (0 = bỏ qua độ dài tài "
                    + "liệu, 1 = chuẩn hoá hoàn toàn), nhận \(value)")
            }
            options.b = value
        }
        if let fold = root["fold_diacritics"]?.boolValue {
            options.tokenizer = BM25Tokenizer(
                foldDiacritics: fold, minimumLength: options.tokenizer.minimumLength)
        }
        return options
    }
}

/// Chạy và vẽ khối ```retrieval.
public enum RetrievalCard {

    public struct Result: Equatable, Sendable {
        public var report: RetrievalEval.Report
        public var compare: RetrievalEval.Report?
        public var comparison: RetrievalEval.Comparison?
        public var corpusPath: String
        public var goldenPath: String
        /// FR-KNW-921 — tệp điểm ngoài, phép ghép, và độ phủ id.
        public var external: ExternalScores.File?
        public var join: ExternalScores.Join?
        public var coverage: ExternalScores.Coverage?
    }

    public static func run(
        _ spec: RetrievalBlockSpec, basePath: String?,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        let corpus = QualityCard.resolve(spec.corpus, relativeTo: basePath)
        let goldenPath = QualityCard.resolve(spec.golden, relativeTo: basePath)
        var golden = try RetrievalEval.loadGoldenSet(path: goldenPath)

        // `open` dùng lại chỉ mục cạnh corpus nếu nó còn tươi, và dựng lại nếu không —
        // NFR-KNW-04 đòi "tự vô hiệu theo mtime". Một báo cáo dựng lại chỉ mục 1 GB mỗi lần
        // xem trước thì không ai dùng.
        let index = try BM25Index.open(corpus: corpus, options: spec.options)
        let map = try index.identifierMap(cancelToken: cancelToken)

        // --- Điểm ngoài (FR-KNW-921): CẮT golden set về phần giao TRƯỚC khi chạy gì cả ---
        //
        // Cắt trước chứ không so sau. BM25 chấm trên 200 câu còn hệ ngoài chấm trên 60 câu nó
        // có mặt là hai con số không so được với nhau; và nếu chỉ bảng delta dùng phần giao còn
        // ô điểm lớn ở đầu thẻ dùng cả bộ thì chính tấm thẻ ấy trộn hai tập câu hỏi.
        var externalFile: ExternalScores.File?
        var join: ExternalScores.Join?
        var coverage: ExternalScores.Coverage?
        if !spec.external.isEmpty {
            let path = QualityCard.resolve(spec.external, relativeTo: basePath)
            let file = try ExternalScores.load(path: path, order: spec.externalOrder)
            let matched = ExternalScores.join(file, golden: golden)
            guard !matched.matched.isEmpty else {
                throw RetrievalBlockSpec.Failure(message:
                    "tệp điểm ngoài không có câu nào trùng với bộ đánh giá — ghép theo CÂU HỎI, "
                    + "không theo qid. " + (matched.suggestions.first ?? "Kiểm lại khoá «"
                        + ExternalScores.questionKeys.joined(separator: "/") + "»."))
            }
            golden = matched.matched
            externalFile = file
            join = matched
            coverage = ExternalScores.coverage(file, identifierMap: map)
        }

        let report = RetrievalEval.run(
            index: index, golden: golden, k: spec.k, identifierMap: map,
            cancelToken: cancelToken)

        var second: RetrievalEval.Report?
        var comparison: RetrievalEval.Comparison?
        if let options = spec.compare {
            // Cấu hình thứ hai đọc CÙNG corpus nhưng cần chỉ mục riêng: k1/b nằm trong đầu tệp
            // chỉ mục, nên `open` sẽ tự thấy chỉ mục cũ không hợp và dựng lại.
            let other = try BM25Index.open(corpus: corpus, options: options)
            second = RetrievalEval.run(
                index: other, golden: golden, k: spec.k, identifierMap: map,
                cancelToken: cancelToken)
            comparison = RetrievalEval.compare(report, second!)
        }
        if let file = externalFile {
            // Cùng `golden`, cùng `k`, cùng bộ chấm điểm — chỉ khác BỘ TRUY HỒI.
            second = RetrievalEval.run(
                golden: golden, k: spec.k, identifierMap: map,
                configuration: file.methodology, cancelToken: cancelToken,
                retrieve: ExternalScores.retriever(file, identifierMap: map))
            comparison = RetrievalEval.compare(report, second!)
        }
        return Result(report: report, compare: second, comparison: comparison,
                      corpusPath: corpus, goldenPath: goldenPath,
                      external: externalFile, join: join, coverage: coverage)
    }

    // MARK: - HTML

    public static func html(_ result: Result, spec: RetrievalBlockSpec) -> String {
        let summary = result.report.summary
        let state = QualityCard.state(
            total: summary.recall * 100, threshold: spec.failUnder.map { $0 * 100 })

        var facts: [String] = [
            "\(summary.queryCount) câu hỏi",
            "k = \(summary.k)",
            summary.configuration,
        ]
        if summary.scoredCount != summary.queryCount {
            facts.append("\(summary.queryCount - summary.scoredCount) câu KHÔNG chấm được")
        }
        if summary.ceiling < 1 {
            facts.append("trần recall \(percent(summary.ceiling)) (k nhỏ hơn số id kỳ vọng)")
        }
        facts.append("corpus: " + (result.corpusPath as NSString).lastPathComponent)
        facts.append("bộ đánh giá: " + (result.goldenPath as NSString).lastPathComponent)

        var out = "<section class=\"g-score g-score-\(state)\">"
        if !spec.title.isEmpty {
            out += "<h3 class=\"g-score-title\">" + MarkdownHTML.escape(spec.title) + "</h3>"
        }
        out += "<div class=\"g-score-head\"><div class=\"g-score-total\">"
            + "<span class=\"g-score-value\">" + percent(summary.recall) + "</span>"
            + "<span class=\"g-score-max\">recall@\(summary.k)</span></div>"
        out += "<p class=\"g-score-facts\">"
            + MarkdownHTML.escape(facts.joined(separator: " · ")) + "</p></div>"

        out += metricTable(result, spec: spec)

        // Id kỳ vọng lạc — nói NGAY dưới bảng số, không giấu xuống cuối.
        //
        // Một bộ đánh giá trỏ vào corpus cũ cho điểm thấp trông y hệt một bộ truy hồi dở, và
        // người đọc sẽ đi tối ưu k1/b cho một vấn đề không nằm ở đó.
        if summary.missingIDCount > 0 {
            let names = result.report.queries.flatMap(\.missingIDs)
            out += "<p class=\"g-note g-unscored\">" + MarkdownHTML.escape(
                "\(summary.missingIDCount) id kỳ vọng KHÔNG có trong corpus — đây là lỗi của bộ "
                + "đánh giá, không phải của bộ truy hồi. "
                + "Câu mất sạch id kỳ vọng bị loại khỏi trung bình. Vài id đầu: "
                + names.prefix(10).joined(separator: ", ")
                + (names.count > 10 ? ", …" : "")) + "</p>"
        }

        out += "<details class=\"g-formulas\"><summary>Công thức chấm điểm</summary><dl>"
        for entry in RetrievalEval.formulas {
            out += "<dt>" + MarkdownHTML.escape(entry.name) + "</dt><dd><code>"
                + MarkdownHTML.escape(entry.formula) + "</code><br>"
                + MarkdownHTML.escape(entry.note) + "</dd>"
        }
        out += "</dl></details></section>"

        if result.external != nil { out += externalNote(result) }
        if result.compare != nil { out += metricChart(result) }
        if spec.worst > 0 { out += worstTable(result, limit: spec.worst) }
        if let comparison = result.comparison {
            out += comparisonTable(comparison, limit: spec.worst, names: columnNames(result))
        }
        return out
    }

    /// Tên hai cột. Với điểm ngoài thì đây là hai HỆ khác nhau chứ không phải hai cấu hình
    /// của một hệ, và đầu đề phải nói đúng điều đó.
    static func columnNames(_ result: Result) -> (left: String, right: String) {
        result.external == nil ? ("Cấu hình 1", "Cấu hình 2") : ("BM25", "Điểm ngoài")
    }

    private static func metricTable(_ result: Result, spec: RetrievalBlockSpec) -> String {
        let summary = result.report.summary
        let names = columnNames(result)
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><thead><tr>"
            + "<th>Chỉ số</th><th>" + MarkdownHTML.escape(names.left) + "</th>"
        if result.compare != nil {
            out += "<th>" + MarkdownHTML.escape(names.right) + "</th><th>Δ</th>"
        }
        out += "</tr></thead><tbody>"
        let rows: [(String, (RetrievalEval.Summary) -> Double)] = [
            ("recall@\(summary.k)", { $0.recall }),
            ("MRR", { $0.mrr }),
            ("nDCG@\(summary.k)", { $0.ndcg }),
        ]
        for (name, value) in rows {
            out += "<tr><td class=\"txt\">" + MarkdownHTML.escape(name) + "</td>"
                + "<td class=\"num\">" + percent(value(summary)) + "</td>"
            if let other = result.compare?.summary {
                let delta = value(other) - value(summary)
                out += "<td class=\"num\">" + percent(value(other)) + "</td>"
                    + "<td class=\"num g-rule-\(delta >= 0 ? "pass" : "fail")\">"
                    + (delta >= 0 ? "+" : "") + percent(delta) + "</td>"
            }
            out += "</tr>"
        }
        out += "<tr><td class=\"txt\">thời gian</td><td class=\"num\">"
            + String(format: "%.0f ms", summary.elapsedMs) + "</td>"
        if let other = result.compare?.summary {
            out += "<td class=\"num\">" + String(format: "%.0f ms", other.elapsedMs)
                + "</td><td class=\"num\">—</td>"
        }
        out += "</tr></tbody></table>"
        if let other = result.compare?.summary {
            out += "<p class=\"g-note\">"
                + MarkdownHTML.escape("\(names.left): \(summary.configuration) · "
                    + "\(names.right): \(other.configuration)") + "</p>"
        }
        return out + "</div>"
    }

    /// Bảng câu TỆ NHẤT — đặc tả đòi "để sửa corpus có trọng tâm".
    private static func worstTable(_ result: Result, limit: Int) -> String {
        guard !result.report.queries.isEmpty else { return "" }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Câu tệ nhất</caption><thead><tr><th>Câu hỏi</th><th>recall</th>"
            + "<th>hạng đúng đầu</th><th>id kỳ vọng</th></tr></thead><tbody>"
        for entry in result.report.queries.prefix(limit) {
            let cssClass: String
            if entry.excludedReason != nil { cssClass = "broken" }
            else if (entry.recall ?? 0) >= 1 { cssClass = "pass" }
            else if (entry.recall ?? 0) > 0 { cssClass = "warn" }
            else { cssClass = "fail" }
            out += "<tr class=\"g-rule-\(cssClass)\"><td class=\"txt\">"
                + MarkdownHTML.escape(entry.query.question) + "</td>"
                + "<td class=\"num\">"
                + (entry.recall.map { percent($0) } ?? "—") + "</td>"
                + "<td class=\"num\">"
                + (entry.firstHitRank.map { String($0) } ?? "—") + "</td>"
                + "<td class=\"txt\">"
                + MarkdownHTML.escape(entry.excludedReason
                    ?? entry.query.relevant.joined(separator: ", ")) + "</td></tr>"
        }
        out += "</tbody></table>"
        if result.report.queries.count > limit {
            out += "<p class=\"g-note\">Bảng hiện \(limit) / "
                + "\(result.report.queries.count) câu.</p>"
        }
        return out + "</div>"
    }

    private static func comparisonTable(
        _ comparison: RetrievalEval.Comparison, limit: Int,
        names: (left: String, right: String) = ("Cấu hình 1", "Cấu hình 2")
    ) -> String {
        let interesting = comparison.rows.filter { ($0.delta ?? 0) != 0 }
        guard !interesting.isEmpty else {
            return "<p class=\"g-note\">Hai bên cho recall GIỐNG NHAU trên mọi câu.</p>"
        }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Chỗ hai bên khác nhau nhiều nhất</caption><thead><tr><th>Câu hỏi</th>"
            + "<th>" + MarkdownHTML.escape(names.left) + "</th><th>"
            + MarkdownHTML.escape(names.right) + "</th><th>Δ</th></tr></thead><tbody>"
        for row in interesting.prefix(max(limit, 1)) {
            let delta = row.delta ?? 0
            out += "<tr class=\"g-rule-\(delta >= 0 ? "pass" : "fail")\"><td class=\"txt\">"
                + MarkdownHTML.escape(row.query.question) + "</td>"
                + "<td class=\"num\">" + (row.left.map { percent($0) } ?? "—") + "</td>"
                + "<td class=\"num\">" + (row.right.map { percent($0) } ?? "—") + "</td>"
                + "<td class=\"num\">" + (delta >= 0 ? "+" : "") + percent(delta) + "</td></tr>"
        }
        out += "</tbody></table>"
        if interesting.count > limit {
            out += "<p class=\"g-note\">Bảng hiện \(limit) / \(interesting.count) câu khác nhau."
                + "</p>"
        }
        return out + "</div>"
    }

    // MARK: - Điểm ngoài (FR-KNW-921)

    /// Ghi chú của phép so hai hệ — và nó nói ra **mọi thứ đã bị loại**.
    ///
    /// Ba con số ở đây quan trọng ngang bảng điểm: bao nhiêu câu ghép được, bao nhiêu câu golden
    /// bị loại vì tệp ngoài không có, và bao nhiêu id trong tệp ngoài corpus không có. Số thứ ba
    /// là dấu hiệu của cái hỏng tốn kém nhất — hai bên chạy trên HAI BẢN corpus khác nhau — và
    /// khi ấy con số ra trông y hệt "embedding thua BM25".
    private static func externalNote(_ result: Result) -> String {
        guard let file = result.external, let join = result.join else { return "" }
        var lines: [String] = []
        lines.append("So trên \(join.matched.count) câu cả hai bên đều có.")
        if !join.unmatched.isEmpty {
            lines.append("\(join.unmatched.count) câu của bộ đánh giá KHÔNG có trong tệp ngoài "
                + "nên bị loại khỏi CẢ HAI lượt chạy — tính 0 điểm cho hệ ngoài ở đây là kết "
                + "luận sai về một lỗi ghép.")
        }
        if !join.extraQuestions.isEmpty {
            lines.append("\(join.extraQuestions.count) câu chỉ có trong tệp ngoài.")
        }
        lines.append(contentsOf: join.suggestions)
        lines.append(contentsOf: file.warnings)
        if let coverage = result.coverage, coverage.unknownCount > 0 {
            lines.append("\(coverage.unknownCount)/\(coverage.totalCount) id trong tệp ngoài "
                + "KHÔNG có trong corpus (" + percent(coverage.ratio) + ") — nhiều khả năng hai "
                + "bên chạy trên hai bản corpus khác nhau. Vài id: "
                + coverage.samples.prefix(5).joined(separator: ", "))
        }
        lines.append(file.methodology)
        return "<p class=\"g-note g-unscored\">"
            + lines.map { MarkdownHTML.escape($0) }.joined(separator: "<br>") + "</p>"
    }

    /// Biểu đồ cột so ba chỉ số của hai bên — đặc tả đòi *"chart so recall@k/MRR hai hệ"*.
    ///
    /// Sáu cột trong MỘT dãy, xếp cặp cạnh nhau theo từng chỉ số, chứ không phải hai biểu đồ.
    /// Hai biểu đồ cạnh nhau rất dễ có trục khác nhau, và khi ấy hình vẽ nói một chuyện mà con
    /// số nói chuyện khác.
    private static func metricChart(_ result: Result) -> String {
        guard let other = result.compare?.summary else { return "" }
        let summary = result.report.summary
        let names = columnNames(result)
        let metrics: [(String, Double, Double)] = [
            ("recall@\(summary.k)", summary.recall, other.recall),
            ("MRR", summary.mrr, other.mrr),
            ("nDCG@\(summary.k)", summary.ndcg, other.ndcg),
        ]
        var points: [ChartData.Point] = []
        for (index, metric) in metrics.enumerated() {
            points.append(ChartData.Point(
                x: Double(index * 2), y: metric.1, label: "\(metric.0) · \(names.left)"))
            points.append(ChartData.Point(
                x: Double(index * 2 + 1), y: metric.2, label: "\(metric.0) · \(names.right)"))
        }
        let title = "\(names.left) so \(names.right) trên \(summary.queryCount) câu"
        let series = ChartData.Series(name: title, points: points, originalCount: points.count)
        let layout = ChartRender.Layout(width: 720, height: 300)
        let style = ChartRender.Style(palette: .gLight, numbers: NumberStyle())
        return "<figure class=\"g-chart\">"
            + ChartRender.svg(
                ChartRender.primitives(
                    kind: .bar, series: series, layout: layout, title: title, style: style),
                layout: layout, style: style)
            + "</figure>"
    }

    static func percent(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }
}
