import Foundation

/// Chạy và kết xuất báo cáo — FR-RPT-001 (preview) và FR-RPT-005 (xuất HTML tự chứa).
///
/// ## Một khối hỏng KHÔNG được giết cả báo cáo
///
/// Đây là quyết định lớn nhất của tệp này. Cách hiển nhiên — gặp lỗi thì ném ra ngoài — cho một
/// báo cáo tám khối mà khối thứ ba gõ sai tên cột trở thành một màn hình lỗi trắng trơn. Người
/// dùng mất luôn bảy khối chạy được, và mất cả manh mối về việc khối nào hỏng.
///
/// Nên mỗi khối kết xuất **hoặc kết quả, hoặc một hộp lỗi tại chỗ** kèm số dòng. Cả trang vẫn
/// dựng xong. `Rendered.failures` gom lại để tầng trên đếm và để CLI quyết định mã thoát.
///
/// ## Nguồn dữ liệu là TÀI LIỆU ĐANG MỞ, không phải một kết nối riêng
///
/// Mọi khối `query` chạy qua `CSVQueryEngine` trên chính buffer đang mở, đúng như Query
/// Workbench. Nghĩa là hàng rào chỉ-đọc, bộ dịch lỗi tiếng Việt, và cách nạp nguồn phụ đều dùng
/// chung — không có đường chạy thứ hai để lệch khỏi đường thứ nhất.
///
/// ## HTML TỰ CHỨA: không một yêu cầu mạng nào
///
/// FR-RPT-005 đòi *"HTML tự chứa một file (chart nhúng SVG, CSS nội tuyến, mở offline)"*. Biểu
/// đồ nhúng thành SVG **trong dòng**, không phải `<img src>`; CSS nằm trong `<style>`; không có
/// phông chữ tải về, không có script. Một báo cáo gửi qua email phải mở được trên máy không có
/// mạng, và phải mở được sau ba năm nữa.
public enum ReportRenderer {

    /// Một khối ```mermaid đang chờ được vẽ — FR-MMD-003.
    public struct MermaidPlaceholder: Equatable, Sendable {
        public var blockIndex: Int
        public var line: Int
        public var source: String

        public init(blockIndex: Int, line: Int, source: String) {
            self.blockIndex = blockIndex
            self.line = line
            self.source = source
        }
    }

    public struct BlockFailure: Equatable, Sendable {
        public var blockIndex: Int
        public var line: Int
        public var message: String

        public init(blockIndex: Int, line: Int, message: String) {
            self.blockIndex = blockIndex
            self.line = line
            self.message = message
        }
    }

    public struct Rendered: Equatable, Sendable {
        public var html: String
        public var failures: [BlockFailure]
        /// Số khối đã chạy được, để phân biệt "báo cáo rỗng" với "báo cáo hỏng hết".
        public var succeeded: Int
        /// Dấu vân của tệp nguồn tại lúc kết xuất — FR-RPT-003 (*"chỉ báo dữ liệu cũ khi file
        /// nguồn đã đổi sau lần render"*).
        ///
        /// Dùng lại `QueryCatalog.Fingerprint` chứ không tự so: nó đã so CẢ cỡ lẫn thời điểm
        /// sửa, và đã có bài kiểm cho ca sửa-giữ-nguyên-độ-dài. Hai bản của cùng một phép so là
        /// hai kết luận sẽ lệch nhau.
        public var sourceFingerprint: QueryCatalog.Fingerprint?
        /// Điểm của từng khối ```quality đã chạy, theo thứ tự xuất hiện — FR-DQR-003.
        ///
        /// Có mặt để tầng trên khỏi phải đọc lại HTML mà moi con số ra. Một mã CLI hay một panel
        /// đi phân tích chuỗi HTML của chính mình là chỗ mà đổi một thẻ `<span>` làm hỏng một
        /// cổng chặn merge.
        public var qualityScores: [QualityScore]
        /// Khối ```quality CHẠY ĐƯỢC nhưng điểm dưới ngưỡng, hoặc trôi dạt vượt ngưỡng
        /// (FR-DQR-003 · FR-DQR-004).
        ///
        /// Tách khỏi `failures` vì đây là hai chuyện khác nhau: `failures` là *"khối không chạy
        /// được"*, còn đây là *"khối chạy đúng và kết quả là tin xấu"*. Gộp chúng thì một báo
        /// cáo có điểm 62/100 sẽ hiện hộp lỗi đỏ như thể tệp báo cáo viết sai.
        public var qualityAlerts: [BlockFailure]
        /// Những khối ```mermaid CHƯA được vẽ — FR-MMD-003.
        ///
        /// Rỗng nghĩa là báo cáo không có sơ đồ nào; khác rỗng nghĩa là tầng app còn một việc
        /// phải làm trước khi trang này xem được. Trả ra một danh sách chứ không giấu trong
        /// HTML: chỗ gọi cần biết CÓ hay KHÔNG để quyết định có dựng WKWebView hay không, và
        /// dựng nó chỉ để phát hiện ra không có sơ đồ nào là trả 30 MB cho một câu trả lời rỗng.
        public var mermaid: [MermaidPlaceholder]

        public init(
            html: String, failures: [BlockFailure], succeeded: Int,
            sourceFingerprint: QueryCatalog.Fingerprint? = nil,
            qualityScores: [QualityScore] = [], qualityAlerts: [BlockFailure] = [],
            mermaid: [MermaidPlaceholder] = []
        ) {
            self.html = html
            self.failures = failures
            self.succeeded = succeeded
            self.sourceFingerprint = sourceFingerprint
            self.qualityScores = qualityScores
            self.qualityAlerts = qualityAlerts
            self.mermaid = mermaid
        }

        /// Tệp nguồn đã đổi kể từ lúc kết xuất chưa.
        public func isStale(against path: String?) -> Bool {
            guard let path, let sourceFingerprint else { return false }
            guard let current = QueryCatalog.Fingerprint.read(path: path) else { return true }
            return current != sourceFingerprint
        }

        public var hasFailures: Bool { !failures.isEmpty }
    }

    public struct Options: Sendable {
        public var values: [String: String]
        public var sourcePath: String?
        public var extraSources: [String: String]
        /// Tối đa bao nhiêu HÀNG hiện trong một bảng nhúng.
        public var rowLimit: Int
        public var chartWidth: Double
        public var chartHeight: Double
        /// Thư mục của chính TỆP BÁO CÁO — `rules_file` của khối ```quality giải tương đối với
        /// nó (FR-DQR-003), không phải với thư mục đang đứng.
        public var basePath: String?
        /// Nhớ kết quả chấm điểm giữa các lần dựng. `nil` = chạy lại mỗi lần.
        public var qualityCache: QualityCache?
        /// Nhớ kết quả từng khối ```query — NFR-RPT-01. `nil` = chạy lại mỗi lần.
        public var blockCache: ReportBlockCache?
        /// Ghi lịch sử chất lượng sau mỗi lần khối ```quality chạy — FR-DQR-004.
        public var recordQualityHistory: Bool

        public init(
            values: [String: String] = [:], sourcePath: String? = nil,
            extraSources: [String: String] = [:], rowLimit: Int = 200,
            chartWidth: Double = 720, chartHeight: Double = 360,
            basePath: String? = nil, qualityCache: QualityCache? = nil,
            blockCache: ReportBlockCache? = nil,
            recordQualityHistory: Bool = false
        ) {
            self.values = values
            self.sourcePath = sourcePath
            self.extraSources = extraSources
            self.rowLimit = rowLimit
            self.chartWidth = chartWidth
            self.chartHeight = chartHeight
            self.basePath = basePath
            self.qualityCache = qualityCache
            self.blockCache = blockCache
            self.recordQualityHistory = recordQualityHistory
        }
    }

    // MARK: - Kết xuất

    public static func render(
        _ document: ReportDocument, in buffer: TextBuffer, dialect: CSVDialect,
        options: Options = Options(), cancelToken: CancelToken = CancelToken()
    ) throws -> Rendered {
        let chartDefaults = (try? ChartSpec.defaults(from: document.frontmatter)) ?? ChartSpec()
        let tableStyle = chartDefaults.numberStyle

        var body: [String] = []
        var failures: [BlockFailure] = []
        var qualityScores: [QualityScore] = []
        var qualityAlerts: [BlockFailure] = []
        var mermaid: [MermaidPlaceholder] = []
        var succeeded = 0
        /// Kết quả của khối query gần nhất — khối chart không khai `query` sẽ dùng nó.
        var lastResult: CSVQueryEngine.Result?
        var lastQueryBlock: Int?

        for segment in document.segments {
            try cancelToken.check()
            switch segment {
            case let .markdown(text):
                body.append(MarkdownHTML.render(
                    substituteInProse(text, values: options.values)))

            case let .block(block):
                switch block.kind {
                case .query:
                    do {
                        let result = try run(
                            block.content, in: buffer, dialect: dialect, options: options,
                            cancelToken: cancelToken)
                        lastResult = result
                        lastQueryBlock = block.index
                        body.append(table(result, style: tableStyle, limit: options.rowLimit))
                        succeeded += 1
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "query"))
                    }

                case .chart:
                    // Tách LỖI CÚ PHÁP khỏi LỖI DỮ LIỆU bằng CẤU TRÚC, không bằng kiểu lỗi.
                    //
                    // Bản đầu gói cả hai vào `ChartSpec.Failure` rồi phân biệt bằng `is` — và
                    // nó sai ngay: "kết quả không có cột số nào" là lỗi DỮ LIỆU nhưng dùng
                    // chung kiểu ấy, nên nó mất câu chỉ đường về khối cho mượn. Hai khối `do`
                    // riêng thì không nhầm được: chỗ nào bắt được lỗi, chỗ đó biết lỗi loại gì.
                    let spec: ChartSpec
                    do {
                        spec = try ChartSpec.parse(block.content, inheriting: chartDefaults)
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "chart"))
                        continue
                    }
                    do {
                        let result: CSVQueryEngine.Result
                        if spec.query.isEmpty {
                            guard let inherited = lastResult else {
                                throw ChartSpec.Failure(message:
                                    "khối chart không có khoá «query» và phía trên nó cũng "
                                    + "chưa có khối ```query nào để lấy dữ liệu")
                            }
                            result = inherited
                        } else {
                            result = try run(
                                spec.query, in: buffer, dialect: dialect, options: options,
                                cancelToken: cancelToken)
                        }
                        body.append(try chart(spec, result: result, options: options))
                        succeeded += 1
                    } catch {
                        var text = message(of: error)
                        // Biểu đồ mượn dữ liệu của khối khác thì lỗi phải nói ra nó mượn của
                        // khối nào — nếu không người dùng đi sửa đúng khối chart, nơi không có
                        // câu SQL nào để sửa.
                        if spec.query.isEmpty, let source = lastQueryBlock {
                            text += " (biểu đồ này lấy dữ liệu từ khối query thứ \(source + 1))"
                        }
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line, message: text)
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "chart"))
                    }

                case .quality:
                    // Cùng lối tách hai loại lỗi như khối `chart`: lỗi CÚ PHÁP của spec và lỗi
                    // DỮ LIỆU khi chạy nằm ở hai khối `do` riêng.
                    let spec: QualityBlockSpec
                    do {
                        spec = try QualityBlockSpec.parse(
                            substituteInProse(block.content, values: options.values))
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "quality"))
                        continue
                    }
                    // Chế độ ĐỒ THỊ (FR-KNW-924) rẽ ở đây — cùng hàng rào, cùng khung sáu
                    // chiều, khác thứ được chấm.
                    if !spec.graph.isEmpty {
                        do {
                            let path = QualityCard.resolve(
                                spec.graph, relativeTo: options.basePath)
                            guard let text = try? String(contentsOfFile: path, encoding: .utf8)
                            else {
                                throw QualityBlockSpec.Failure(
                                    message: "không đọc được tệp đồ thị «\(path)»")
                            }
                            let report = GraphQuality.run(
                                DOTGraph.parse(text), config: spec.graphConfig,
                                now: spec.now ?? Date(), cancelToken: cancelToken)
                            qualityScores.append(report.score)
                            body.append(GraphQualityCard.html(
                                report, spec: spec, rowLimit: options.rowLimit))
                            if let threshold = spec.failUnder, let total = report.score.total,
                               total < threshold {
                                let text = "Điểm \(QualityCard.format(total)) DƯỚI ngưỡng "
                                    + "\(QualityCard.format(threshold)) khai trong khối."
                                qualityAlerts.append(BlockFailure(
                                    blockIndex: block.index, line: block.line, message: text))
                                body.append(alertBox([text]))
                            }
                            succeeded += 1
                        } catch {
                            let failure = BlockFailure(
                                blockIndex: block.index, line: block.line,
                                message: message(of: error))
                            failures.append(failure)
                            body.append(errorBox(failure, kind: "quality"))
                        }
                        continue
                    }

                    // Chế độ CHUNK (FR-KNW-922) rẽ ở đây: cùng hàng rào ```quality, cùng
                    // khung sáu chiều, khác thứ được chấm — corpus JSONL thay vì một bảng.
                    if !spec.corpus.isEmpty {
                        do {
                            let path = QualityCard.resolve(
                                spec.corpus, relativeTo: options.basePath)
                            let report = try ChunkQuality.run(
                                corpus: path, config: spec.chunk, now: spec.now ?? Date(),
                                cancelToken: cancelToken)
                            qualityScores.append(report.score)
                            body.append(ChunkQualityCard.html(
                                report, spec: spec, rowLimit: options.rowLimit))
                            if let threshold = spec.failUnder, let total = report.score.total,
                               total < threshold {
                                let text = "Điểm \(QualityCard.format(total)) DƯỚI ngưỡng "
                                    + "\(QualityCard.format(threshold)) khai trong khối."
                                qualityAlerts.append(BlockFailure(
                                    blockIndex: block.index, line: block.line, message: text))
                                body.append(alertBox([text]))
                            }
                            succeeded += 1
                        } catch {
                            let failure = BlockFailure(
                                blockIndex: block.index, line: block.line,
                                message: message(of: error))
                            failures.append(failure)
                            body.append(errorBox(failure, kind: "quality"))
                        }
                        continue
                    }
                    do {
                        let card = try QualityCard.run(
                            spec, basePath: options.basePath, fallbackBuffer: buffer,
                            fallbackSourcePath: options.sourcePath, dialect: dialect,
                            cache: options.qualityCache, cancelToken: cancelToken)
                        qualityScores.append(card.score)

                        // Lịch sử và trôi dạt — FR-DQR-004. Ghi TRƯỚC khi vẽ, để tấm thẻ nói
                        // được "so với lần trước" ngay trong cùng một lượt dựng.
                        var drift: QualityDrift.Comparison?
                        if options.recordQualityHistory {
                            drift = QualityHistory.record(
                                card, rulesPath: card.rulesPath)
                        } else {
                            drift = QualityHistory.compareWithLast(card)
                        }

                        body.append(QualityCard.html(
                            card, spec: spec, style: tableStyle, ruleLimit: options.rowLimit,
                            chartWidth: options.chartWidth, chartHeight: options.chartHeight))

                        var alerts: [String] = []
                        if let threshold = spec.failUnder, let total = card.score.total,
                           total < threshold {
                            alerts.append("Điểm \(QualityCard.format(total)) DƯỚI ngưỡng "
                                + "\(QualityCard.format(threshold)) khai trong khối.")
                        }
                        alerts.append(contentsOf: drift?.alerts ?? [])
                        if !alerts.isEmpty {
                            for text in alerts {
                                qualityAlerts.append(BlockFailure(
                                    blockIndex: block.index, line: block.line, message: text))
                            }
                            body.append(alertBox(alerts))
                        }
                        if let drift, drift.hasPrevious {
                            body.append(QualityDrift.html(drift))
                        }
                        succeeded += 1
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "quality"))
                    }

                case .retrieval:
                    // Cùng lối tách hai loại lỗi như mọi khối khác: lỗi CÚ PHÁP của spec và lỗi
                    // DỮ LIỆU khi chạy nằm ở hai khối `do` riêng.
                    let spec: RetrievalBlockSpec
                    do {
                        spec = try RetrievalBlockSpec.parse(
                            substituteInProse(block.content, values: options.values))
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "retrieval"))
                        continue
                    }
                    do {
                        let result = try RetrievalCard.run(
                            spec, basePath: options.basePath, cancelToken: cancelToken)
                        body.append(RetrievalCard.html(result, spec: spec))
                        if let threshold = spec.failUnder,
                           result.report.summary.recall < threshold {
                            let text = "recall@\(spec.k) "
                                + RetrievalCard.percent(result.report.summary.recall)
                                + " DƯỚI ngưỡng " + RetrievalCard.percent(threshold)
                                + " khai trong khối."
                            qualityAlerts.append(BlockFailure(
                                blockIndex: block.index, line: block.line, message: text))
                            body.append(alertBox([text]))
                        }
                        succeeded += 1
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "retrieval"))
                    }

                case .mermaid:
                    // Để lại CHỖ TRỐNG có đánh số, không vẽ. Lõi không được biết tới WebKit
                    // (NFR-MNT-01), nên vẽ là việc của tầng app — `spliceMermaid` điền vào.
                    //
                    // Chỗ trống mang sẵn một câu nói rõ vì sao nó trống, chứ không phải một ô
                    // trắng: bản HTML dựng từ CLI không có ai điền vào, và một khoảng trắng
                    // không lời giải thích giữa báo cáo là thứ người đọc quy cho lỗi của mình.
                    let source = block.content
                    mermaid.append(MermaidPlaceholder(
                        blockIndex: block.index, line: block.line, source: source))
                    body.append(mermaidPlaceholder(index: block.index, source: source))
                    succeeded += 1

                case .mining:
                    // Cùng lối tách hai loại lỗi như khối `chart` và khối `quality`.
                    let spec: MiningBlockSpec
                    do {
                        spec = try MiningBlockSpec.parse(
                            substituteInProse(block.content, values: options.values))
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "mining"))
                        continue
                    }
                    do {
                        let card = try MiningCard.run(
                            spec, basePath: options.basePath, fallbackBuffer: buffer,
                            fallbackSourcePath: options.sourcePath, dialect: dialect,
                            cancelToken: cancelToken)
                        body.append(MiningCard.html(
                            card, spec: spec, style: tableStyle,
                            chartWidth: options.chartWidth, chartHeight: options.chartHeight))
                        succeeded += 1
                    } catch {
                        let failure = BlockFailure(
                            blockIndex: block.index, line: block.line,
                            message: message(of: error))
                        failures.append(failure)
                        body.append(errorBox(failure, kind: "mining"))
                    }
                }
            }
        }

        let title = document.frontmatter?["title"]?.stringValue ?? ""
        return Rendered(
            html: page(
                title: title, body: body.joined(separator: "\n"),
                columns: columns(from: document.frontmatter)),
            failures: failures, succeeded: succeeded,
            sourceFingerprint: options.sourcePath.flatMap {
                QueryCatalog.Fingerprint.read(path: $0)
            },
            qualityScores: qualityScores, qualityAlerts: qualityAlerts, mermaid: mermaid)
    }

    /// Thay `:tên` trong VĂN XUÔI — chỉ với tham số ĐÃ KHAI.
    ///
    /// ## Vì sao vế "chỉ với tham số đã khai" là điều kiện, không phải tinh chỉnh
    ///
    /// Đặc tả nói tham số dùng trong *"mọi block query"*. Nhưng một mẫu báo cáo tham số hoá gần
    /// như luôn có một câu kiểu *"Số liệu tháng **:thang**"* ở phần mở đầu, và in ra nguyên chữ
    /// `:thang` giữa một báo cáo gửi cho sếp là hỏng theo cách rất khó biện minh.
    ///
    /// Thay MỌI thứ trông giống `:tên` thì lại phá văn bản thật: `mailto:abc`, `ghi chú:xyz`,
    /// tên tệp `C:\temp`. Nên chỉ thay đúng những tên đã có giá trị — tức đã được khai ở
    /// frontmatter hoặc truyền qua `--param`. Một `mailto:abc` chỉ bị đụng khi người dùng có
    /// một tham số tên `abc`, và khi ấy họ thấy ngay.
    ///
    /// Giá trị chèn vào đây là chữ THÔ, không bọc literal SQL: nó đi vào văn bản cho người đọc,
    /// không đi vào câu truy vấn. Phần SQL vẫn đi qua `QueryParameters.substitute`.
    static func substituteInProse(_ text: String, values: [String: String]) -> String {
        guard !values.isEmpty, text.contains(":") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index] == ":" else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }
            // `::` là toán tử ép kiểu của DuckDB, có thể xuất hiện trong đoạn mã trong dòng.
            let next = text.index(after: index)
            if next < text.endIndex, text[next] == ":" {
                result += "::"
                index = text.index(after: next)
                continue
            }
            var end = next
            while end < text.endIndex, text[end].isLetter || text[end].isNumber
                || text[end] == "_" {
                end = text.index(after: end)
            }
            let name = String(text[next ..< end])
            if let value = values[name], !name.isEmpty {
                result += value
                index = end
            } else {
                result.append(":")
                index = next
            }
        }
        return result
    }

    /// Số cột của lưới dashboard — FR-RPT-003.
    ///
    /// Kẹp về 1…4, và kẹp IM LẶNG là đúng ở đây: `columns: 12` không phải lỗi cú pháp, nó chỉ
    /// là một bố cục không đọc được trên màn hình. Nhưng `columns: 0` thì kẹp về 1 chứ không
    /// chia cho 0.
    static func columns(from frontmatter: YAMLValue?) -> Int {
        let declared = frontmatter?["layout"]?["columns"]?.intValue
            ?? frontmatter?["columns"]?.intValue
        return max(1, min(4, declared ?? 1))
    }

    private static func run(
        _ sql: String, in buffer: TextBuffer, dialect: CSVDialect, options: Options,
        cancelToken: CancelToken
    ) throws -> CSVQueryEngine.Result {
        // Thay tham số bằng ĐÚNG hàm mà Query Workbench dùng — giá trị được bọc thành literal
        // SQL, nên một dấu nháy trong `--param` không phá được câu truy vấn.
        let missing = QueryParameters.missing(in: sql, values: options.values)
        guard missing.isEmpty else {
            throw ChartSpec.Failure(message:
                "thiếu giá trị cho tham số: " + missing.map { ":\($0)" }.joined(separator: ", "))
        }
        // Thay tham số TRƯỚC khi băm: hai lượt dựng khác `--param` là hai câu khác nhau, và
        // băm câu gốc sẽ trả về kết quả của tỉnh khác.
        let sqlToRun = QueryParameters.substitute(sql, values: options.values)

        var key: ReportBlockCache.Key?
        if let cache = options.blockCache {
            let fingerprint = options.sourcePath.flatMap { QueryCatalog.Fingerprint.read(path: $0) }
            key = ReportBlockCache.Key(
                sql: sqlToRun, delimiter: dialect.delimiter, sourcePath: options.sourcePath,
                bufferBytes: buffer.count,
                sourceSize: fingerprint?.size ?? -1,
                sourceModified: fingerprint?.modified ?? -1)
            if let key, let hit = cache.value(for: key) { return hit }
        }

        let result = try CSVQueryEngine.run(
            sqlToRun, in: buffer, dialect: dialect, sourcePath: options.sourcePath,
            extraSources: options.extraSources, cancelToken: cancelToken)
        // Chỉ nhớ khi CHẠY XONG: một câu bị huỷ giữa chừng hay ném lỗi không để lại gì trong bộ
        // nhớ tạm, nếu không thì lần sau người dùng nhận lại đúng cái lỗi ấy mà không có cách
        // nào bắt nó chạy lại.
        if let cache = options.blockCache, let key { cache.store(result, for: key) }
        return result
    }

    private static func message(of error: Error) -> String {
        if let failure = error as? CSVQueryEngine.Failure { return failure.message }
        if let failure = error as? ChartSpec.Failure { return failure.message }
        if let failure = error as? QualityBlockSpec.Failure { return failure.message }
        if let failure = error as? MiningBlockSpec.Failure { return failure.message }
        if let failure = error as? QualityRules.Failure { return failure.message }
        if let failure = error as? ReportDocument.Failure { return failure.message }
        // Cụm tri thức. Thiếu bốn dòng này thì mọi lỗi của khối ```retrieval và ```quality
        // «corpus:» hiện ra thành «The operation couldn't be completed» — một câu không nói gì,
        // trong khi lỗi thật đã có sẵn câu tiếng Việt kèm số dòng. Sót từ FR-KNW-919; một bài
        // kiểm cũ chỉ đếm SỐ lỗi nên không ai thấy.
        if let failure = error as? RetrievalBlockSpec.Failure { return failure.message }
        if let failure = error as? RetrievalEval.Failure { return failure.message }
        if let failure = error as? ExternalScores.Failure { return failure.message }
        if let failure = error as? BM25Index.Failure { return failure.message }
        if let failure = error as? ChunkQuality.Failure { return failure.message }
        return error.localizedDescription
    }

    // MARK: - Mảnh HTML

    static func table(
        _ result: CSVQueryEngine.Result, style: NumberStyle, limit: Int
    ) -> String {
        var out = "<div class=\"g-table-wrap\"><table><thead><tr>"
        for title in result.titles { out += "<th>" + MarkdownHTML.escape(title) + "</th>" }
        out += "</tr></thead><tbody>"
        for row in result.rows.prefix(limit) {
            out += "<tr>"
            for (index, cell) in row.enumerated() {
                // Ô SỐ căn phải; ô chữ căn trái. Một cột số căn trái thì hàng nghìn không thẳng
                // cột và mắt không so được độ lớn — đó là toàn bộ lý do người ta xếp số thành cột.
                let text = style.formatCell(cell)
                let isNumeric = cell.flatMap(Double.init) != nil
                out += "<td class=\"\(isNumeric ? "num" : "txt")\">"
                    + MarkdownHTML.escape(text) + "</td>"
                _ = index
            }
            out += "</tr>"
        }
        out += "</tbody></table>"
        if result.rows.count > limit {
            // Cắt bảng mà không nói là cắt thì người đọc cộng tay ra một tổng khác tổng thật.
            out += "<p class=\"g-note\">Bảng hiện \(limit) / \(result.rows.count) hàng đầu.</p>"
        }
        out += "</div>"
        return out
    }

    static func chart(
        _ spec: ChartSpec, result: CSVQueryEngine.Result, options: Options
    ) throws -> String {
        let series: ChartData.Series?
        switch spec.kind {
        case .histogram: series = ChartData.histogramSeries(from: result)
        default: series = ChartData.series(from: result)
        }
        guard let series else {
            throw ChartSpec.Failure(message:
                "kết quả truy vấn không có cột SỐ nào để vẽ — biểu đồ cần ít nhất một cột số")
        }
        // Nhãn trục và chú thích nguồn nằm TRONG hình, không nằm cạnh nó: hình sẽ rời khỏi
        // trang này dưới dạng SVG, và mọi thứ ở ngoài sẽ ở lại.
        var annotated = series
        if !spec.source.isEmpty {
            annotated.samplingNote = [series.samplingNote, spec.source]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        }
        var title = spec.title
        if !spec.yLabel.isEmpty || !spec.xLabel.isEmpty {
            let axes = [spec.yLabel, spec.xLabel].filter { !$0.isEmpty }.joined(separator: " / ")
            title = title.isEmpty ? axes : "\(title) — \(axes)"
        }
        let layout = ChartRender.Layout(
            width: options.chartWidth, height: options.chartHeight)
        let primitives = ChartRender.primitives(
            kind: spec.kind, series: annotated, layout: layout, title: title,
            style: spec.style)
        return "<figure class=\"g-chart\">"
            + ChartRender.svg(primitives, layout: layout, style: spec.style)
            + "</figure>"
    }

    // MARK: - Sơ đồ Mermaid (FR-MMD-003)

    /// Mốc đánh dấu chỗ một sơ đồ sẽ được điền vào.
    ///
    /// Là một chuỗi CỐ ĐỊNH kèm số, không phải một biểu thức chính quy trên HTML: `spliceMermaid`
    /// chỉ cần tìm đúng chuỗi này, nên không có ca nào mà một dấu `<` trong nhãn node của người
    /// dùng làm phép thay trượt sang chỗ khác.
    public static func mermaidMarker(_ index: Int) -> String {
        "<!--geditor-mermaid:\(index)-->"
    }

    static func mermaidPlaceholder(index: Int, source: String) -> String {
        // Mã sơ đồ đi kèm ngay trong chỗ trống, và nó có hai việc. Một: bản HTML dựng từ CLI
        // (không có WebKit) vẫn còn nội dung thật thay vì một ô trắng. Hai: người đọc bản đã
        // vẽ vẫn xem được mã gốc bằng "xem nguồn trang" — sơ đồ là văn bản, và giữ được cái vế
        // ấy là đúng triết lý ADR-09.
        "<figure class=\"g-mermaid\" data-mermaid=\"\(index)\">"
            + mermaidMarker(index)
            + "<details class=\"g-mermaid-source\"><summary>Sơ đồ Mermaid (chưa vẽ)</summary>"
            + "<pre><code>" + MarkdownHTML.escape(source) + "</code></pre>"
            + "<p class=\"g-note\">Bản HTML này dựng ngoài ứng dụng nên chưa có sơ đồ. "
            + "Mở tệp báo cáo trong GEditor để xem và xuất bản có hình.</p></details></figure>"
    }

    /// Điền SVG vào những chỗ trống — tầng app gọi sau khi đã vẽ xong.
    ///
    /// Chỉ số nào KHÔNG có SVG thì giữ nguyên chỗ trống kèm mã nguồn: một sơ đồ hỏng vẫn để lại
    /// mã của nó trên trang, và bảy sơ đồ kia vẫn hiện — cùng luật "một khối hỏng không giết cả
    /// báo cáo".
    public static func spliceMermaid(into html: String, svgs: [Int: String]) -> String {
        var out = html
        for (index, svg) in svgs.sorted(by: { $0.key < $1.key }) {
            let marker = mermaidMarker(index)
            guard out.contains(marker) else { continue }
            // Thay MỐC bằng SVG, và bỏ luôn khối `<details>` mã nguồn đi kèm: khi sơ đồ đã hiện
            // thì khối ấy chỉ còn là một dòng "chưa vẽ" nói sai.
            let opening = "<figure class=\"g-mermaid\" data-mermaid=\"\(index)\">"
            guard let start = out.range(of: opening + marker),
                  let end = out.range(of: "</figure>", range: start.upperBound ..< out.endIndex)
            else {
                out = out.replacingOccurrences(of: marker, with: svg)
                continue
            }
            out.replaceSubrange(
                start.lowerBound ..< end.upperBound, with: opening + svg + "</figure>")
        }
        return out
    }

    /// Hộp CẢNH BÁO — khối chạy đúng, kết quả là tin xấu. Màu và chữ đều khác hộp lỗi.
    static func alertBox(_ messages: [String]) -> String {
        "<div class=\"g-alert\"><strong>Cảnh báo chất lượng</strong><ul>"
            + messages.map { "<li>" + MarkdownHTML.escape($0) + "</li>" }.joined()
            + "</ul></div>"
    }

    static func errorBox(_ failure: BlockFailure, kind: String) -> String {
        "<div class=\"g-error\"><strong>Khối ```\(MarkdownHTML.escape(kind)) "
            + "(dòng \(failure.line + 1)) không chạy được</strong>"
            + "<p>" + MarkdownHTML.escape(failure.message) + "</p></div>"
    }

    /// Khung HTML tự chứa. Không phông tải về, không script, không ảnh ngoài.
    static func page(title: String, body: String, columns: Int = 1) -> String {
        // Lưới đặt trên `<main>`: khối query/chart chiếm một ô, còn văn xuôi TRẢI HẾT chiều
        // ngang. Nếu văn xuôi cũng chiếm một ô thì tiêu đề mục nằm cạnh một biểu đồ và người
        // đọc không biết tiêu đề ấy nói về khối nào.
        let gridStyle = columns > 1
            ? " style=\"display:grid;gap:20px;grid-template-columns:repeat(\(columns),minmax(0,1fr))\""
            : ""
        return """
        <!DOCTYPE html>
        <html lang="vi">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(MarkdownHTML.escape(title.isEmpty ? "Báo cáo GEditor" : title))</title>
        <style>
        \(stylesheet)
        \(QualityCard.stylesheet)
        \(QualityDrift.stylesheet)
        \(MiningCard.stylesheet)
        </style>
        </head>
        <body>
        <main\(gridStyle)>
        \(body)
        </main>
        </body>
        </html>
        """
    }

    /// CSS nội tuyến.
    ///
    /// Phông chữ dùng dải HỆ THỐNG (`-apple-system`, `Segoe UI`, `Roboto`…) chứ không tải về:
    /// một tệp `@font-face` trỏ ra ngoài phá vỡ đúng lời hứa "mở offline", và nhúng phông vào
    /// dạng base64 thì một báo cáo hai trang nặng thêm vài trăm KB phông.
    ///
    /// `@media print` có sẵn ở đây để đóng luôn khoảng trống **FR-DOC-313 (In ấn)** mà FR-RPT-005
    /// nêu: in ra PDF qua đường in của hệ thống, và bảng không bị cắt ngang giữa hàng.
    static let stylesheet = """
        :root { color-scheme: light dark; }
        body {
          font: 15px/1.6 -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
          margin: 0; padding: 32px 24px; color: #1a1a1a; background: #fff;
        }
        main { max-width: 860px; margin: 0 auto; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.6em 0 0.6em; }
        h1 { font-size: 1.9em; } h2 { font-size: 1.45em; } h3 { font-size: 1.2em; }
        p { margin: 0.7em 0; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.9em;
               background: #f2f2f2; padding: 1px 4px; border-radius: 3px; }
        pre { background: #f7f7f7; padding: 12px 14px; border-radius: 6px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        blockquote { margin: 1em 0; padding: 0.2em 1em; border-left: 3px solid #d0d0d0;
                     color: #555; }
        hr { border: none; border-top: 1px solid #e0e0e0; margin: 2em 0; }
        .g-table-wrap { overflow-x: auto; margin: 1.2em 0; }
        table { border-collapse: collapse; width: 100%; font-size: 0.92em; }
        th, td { padding: 6px 10px; border-bottom: 1px solid #e6e6e6; }
        th { text-align: left; background: #fafafa; font-weight: 600;
             border-bottom: 2px solid #d8d8d8; }
        td.num { text-align: right; font-variant-numeric: tabular-nums; }
        .g-chart { margin: 1.4em 0; }
        .g-chart svg { max-width: 100%; height: auto; }
        .g-note { font-size: 0.85em; color: #666; }
        .g-error { margin: 1.2em 0; padding: 12px 14px; border-radius: 6px;
                   background: #fdf1ee; border: 1px solid #e8b4a6; color: #7d2f16; }
        .g-error p { margin: 0.4em 0 0; font-family: ui-monospace, Menlo, monospace;
                     font-size: 0.88em; }
        .g-alert { margin: 1em 0; padding: 10px 14px; border-radius: 6px;
                   background: #fdf7e8; border: 1px solid #e0c98a; color: #6b4c00; }
        .g-mermaid { margin: 1.4em 0; text-align: center; }
        .g-mermaid svg { max-width: 100%; height: auto; }
        .g-mermaid-source { text-align: left; font-size: 0.88em; }
        .g-mermaid-source summary { cursor: pointer; color: #666; }
        .g-alert ul { margin: 0.4em 0 0; padding-left: 1.2em; font-size: 0.9em; }
        main > h1, main > h2, main > h3, main > h4, main > h5, main > h6,
        main > p, main > hr, main > ul, main > ol, main > blockquote, main > pre {
          grid-column: 1 / -1;
        }
        .g-table-wrap, .g-chart, .g-error { min-width: 0; }
        @media (prefers-color-scheme: dark) {
          body { color: #e8e8e8; background: #1c1c1e; }
          code, pre { background: #2a2a2c; }
          th { background: #232325; border-bottom-color: #3a3a3c; }
          th, td { border-bottom-color: #303032; }
          blockquote { border-left-color: #444; color: #aaa; }
          .g-error { background: #3a201a; border-color: #7d3f2c; color: #f0b5a2; }
          .g-alert { background: #33290f; border-color: #6b5a20; color: #f0d79a; }
        }
        @media print {
          body { padding: 0; background: #fff; color: #000; }
          .g-table-wrap { overflow: visible; }
          tr, .g-chart, .g-error, .g-alert { break-inside: avoid; page-break-inside: avoid; }
          h1, h2, h3 { break-after: avoid; page-break-after: avoid; }
        }
        """
}
