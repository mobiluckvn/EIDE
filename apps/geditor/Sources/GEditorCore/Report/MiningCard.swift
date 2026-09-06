import Foundation

/// Khối ```mining trong `.greport.md` — vế cuối của FR-MIN-007 (*"block ```mining hỗ trợ khóa
/// group_by"*).
///
/// ```yaml
/// group_by: tinh
/// value: doanh_thu        # cột chạy bất thường và dự báo
/// pair: chi_phi           # cột thứ hai, để đo tương quan trong từng nhóm
/// rank: anomalies         # anomalies · forecast_error · correlation_gap
/// limit: 10
/// horizon: 4
/// iqr_k: 1.5
/// min_rows: 8
/// source: ban-hang.csv    # để trống thì dùng nguồn của cả báo cáo
/// title: Khai phá theo tỉnh
/// chart: true
/// ```
///
/// ## Không có khoá nào TẮT được khối "Phương pháp"
///
/// Thẻ điểm chất lượng cho phép `rules: false` để giấu bảng luật, nên khối này cũng dễ có một
/// khoá `method: false` cho cân đối. Nhưng NFR-MIN-04 viết *"MỌI đầu ra kèm khối Phương pháp:
/// thuật toán, tham số, seed, công thức"*, và một bảng xếp hạng nhóm không kèm phương pháp thì
/// người đọc không có cách nào biết "nhiều bất thường nhất" được đo bằng hàng rào nào.
///
/// Cái giá của việc KHÔNG có khoá ấy là một khối văn bản người ta có thể thấy thừa. Cái giá của
/// việc có nó là một báo cáo gửi ra ngoài với ba con số và không một dòng nào nói chúng ở đâu ra
/// — và người tắt nó đi luôn là người đã biết câu trả lời.
public struct MiningBlockSpec: Equatable, Sendable {

    public var groupBy: String
    /// Cột số chạy bất thường và dự báo.
    public var value: String
    /// Cột thứ hai cho tương quan. Rỗng = bỏ qua phần tương quan.
    public var pair: String
    public var rank: GroupMining.Ranking
    public var limit: Int
    public var horizon: Int
    public var iqrK: Double
    public var minimumRows: Int
    public var source: String
    public var title: String
    public var chart: Bool

    public init(
        groupBy: String = "", value: String = "", pair: String = "",
        rank: GroupMining.Ranking = .anomalies, limit: Int = 10, horizon: Int = 4,
        iqrK: Double = 1.5, minimumRows: Int = 8, source: String = "", title: String = "",
        chart: Bool = true
    ) {
        self.groupBy = groupBy
        self.value = value
        self.pair = pair
        self.rank = rank
        self.limit = limit
        self.horizon = horizon
        self.iqrK = iqrK
        self.minimumRows = minimumRows
        self.source = source
        self.title = title
        self.chart = chart
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    static let knownKeys: Set<String> = [
        "group_by", "value", "pair", "rank", "limit", "horizon", "iqr_k", "min_rows",
        "source", "title", "chart",
    ]

    /// Tên `rank` viết theo lối YAML (gạch dưới), không theo lối Swift.
    ///
    /// `GroupMining.Ranking` đặt tên `forecastError` cho mã Swift; ép người dùng gõ `forecastError`
    /// trong một tệp YAML là mang quy ước của một ngôn ngữ sang một định dạng không dùng nó.
    static let rankNames: [String: GroupMining.Ranking] = [
        "anomalies": .anomalies,
        "forecast_error": .forecastError,
        "correlation_gap": .correlationGap,
    ]

    public static func parse(_ yaml: String) throws -> MiningBlockSpec {
        let root: YAMLValue
        do {
            root = try YAMLReader.parse(yaml)
        } catch let failure as YAMLReader.Failure {
            throw Failure(message: "khối mining không đọc được: \(failure.message)")
        }
        for key in root.mappingKeys where !knownKeys.contains(key) {
            throw Failure(message: "khối mining có khoá lạ «\(key)» — các khoá hiểu được: "
                + knownKeys.sorted().joined(separator: ", "))
        }

        var spec = MiningBlockSpec()
        spec.groupBy = root["group_by"]?.stringValue ?? ""
        guard !spec.groupBy.isEmpty else {
            throw Failure(message: "khối mining thiếu khoá «group_by» — nó là cột dùng để gom "
                + "nhóm (tỉnh, chi nhánh…), và cả khối này chỉ có nghĩa khi mỗi nhóm được chạy "
                + "riêng")
        }
        spec.value = root["value"]?.stringValue ?? ""
        spec.pair = root["pair"]?.stringValue ?? ""
        guard !spec.value.isEmpty else {
            throw Failure(message: "khối mining thiếu khoá «value» — nó là cột SỐ đem chạy bất "
                + "thường và dự báo trong từng nhóm")
        }
        guard spec.pair != spec.value else {
            // Tự tương quan với chính mình luôn ra r = 1 cho mọi nhóm, tức một cột đầy số 1
            // trông như một kết quả. Nói ra thay vì âm thầm bỏ khoá `pair`.
            throw Failure(message: "khối mining: «pair» trùng với «value» — tương quan của một "
                + "cột với chính nó luôn bằng 1 ở mọi nhóm")
        }
        if let name = root["rank"]?.stringValue {
            guard let rank = rankNames[name.lowercased()] else {
                throw Failure(message: "khối mining: rank «\(name)» không hiểu — có: "
                    + rankNames.keys.sorted().joined(separator: ", "))
            }
            spec.rank = rank
        }
        if let limit = root["limit"]?.intValue {
            guard limit >= 1 else {
                throw Failure(message: "khối mining: limit phải từ 1 trở lên, nhận \(limit)")
            }
            spec.limit = limit
        }
        if let horizon = root["horizon"]?.intValue {
            guard horizon >= 1 else {
                throw Failure(message: "khối mining: horizon phải từ 1 trở lên, nhận \(horizon)")
            }
            spec.horizon = horizon
        }
        if let k = root["iqr_k"]?.doubleValue {
            guard k > 0 else {
                throw Failure(message: "khối mining: iqr_k phải lớn hơn 0, nhận \(k)")
            }
            spec.iqrK = k
        }
        if let rows = root["min_rows"]?.intValue {
            guard rows >= 2 else {
                throw Failure(message: "khối mining: min_rows phải từ 2 trở lên, nhận \(rows)")
            }
            spec.minimumRows = rows
        }
        if let source = root["source"]?.stringValue { spec.source = source }
        if let title = root["title"]?.stringValue { spec.title = title }
        if let chart = root["chart"]?.boolValue { spec.chart = chart }
        return spec
    }

    var options: GroupMining.Options {
        var options = GroupMining.Options(
            anomalyColumn: value, forecastColumn: value, horizon: horizon, iqrK: iqrK,
            minimumRows: minimumRows)
        if !pair.isEmpty { options.correlationPair = (value, pair) }
        return options
    }
}

/// Chạy và vẽ khối ```mining.
public enum MiningCard {

    public struct Result: Equatable, Sendable {
        public var report: GroupMining.Report
        public var sourcePath: String?

        public init(report: GroupMining.Report, sourcePath: String?) {
            self.report = report
            self.sourcePath = sourcePath
        }
    }

    // MARK: - Chạy

    public static func run(
        _ spec: MiningBlockSpec,
        basePath: String?,
        fallbackBuffer: TextBuffer,
        fallbackSourcePath: String?,
        dialect: CSVDialect,
        cancelToken: CancelToken = CancelToken()
    ) throws -> Result {
        let buffer: TextBuffer
        let sourcePath: String?
        if spec.source.isEmpty {
            buffer = fallbackBuffer
            sourcePath = fallbackSourcePath
        } else {
            let path = QualityCard.resolve(spec.source, relativeTo: basePath)
            guard let bytes = FileManager.default.contents(atPath: path) else {
                throw MiningBlockSpec.Failure(message: "không đọc được nguồn «\(path)»")
            }
            buffer = TextBuffer(original: MemoryByteSource([UInt8](bytes)))
            sourcePath = path
        }

        // MỘT lượt quét cho cả ba cột, không ba lượt.
        //
        // Cùng lý do đã ghi ở `QualityEngine`: mỗi cột một câu `SELECT` là mỗi cột một lần đọc
        // toàn bảng, và trên bảng lớn cái giá ấy nhân đúng theo số cột. Ở đây còn một lý do thứ
        // hai, nặng hơn: ba lượt quét riêng có thể trả về ba mảng LỆCH NHAU về số hàng nếu tệp
        // đổi giữa chừng, và khi ấy nhãn nhóm của hàng thứ i không còn thuộc cùng hàng với giá
        // trị thứ i — sai theo hướng không ai nhìn ra.
        var projections = [
            "CAST(\(QualityEngine.quoteIdentifier(spec.groupBy)) AS VARCHAR)",
            "TRY_CAST(\(QualityEngine.quoteIdentifier(spec.value)) AS DOUBLE)",
        ]
        if !spec.pair.isEmpty {
            projections.append(
                "TRY_CAST(\(QualityEngine.quoteIdentifier(spec.pair)) AS DOUBLE)")
        }
        let table = try CSVQueryEngine.run(
            "SELECT " + projections.joined(separator: ", ")
                + " FROM \(CSVQueryEngine.tableName)",
            in: buffer, dialect: dialect, sourcePath: sourcePath, cancelToken: cancelToken)

        var labels: [String?] = []
        var values: [[Double]] = spec.pair.isEmpty ? [[]] : [[], []]
        labels.reserveCapacity(table.rows.count)
        for row in table.rows {
            // Ô rỗng ở cột nhóm KHÔNG tạo ra một nhóm tên "" — nó là hàng chưa biết thuộc đâu.
            let label = (row.first ?? nil).flatMap { $0.isEmpty ? nil : $0 }
            labels.append(label)
            values[0].append(number(row, 1))
            if !spec.pair.isEmpty { values[1].append(number(row, 2)) }
        }
        guard !labels.isEmpty else {
            throw MiningBlockSpec.Failure(message: "bảng rỗng — không có hàng nào để gom nhóm")
        }
        guard labels.contains(where: { $0 != nil }) else {
            throw MiningBlockSpec.Failure(message:
                "cột «\(spec.groupBy)» không có giá trị nào — mọi ô đều rỗng")
        }

        let columns = spec.pair.isEmpty ? [spec.value] : [spec.value, spec.pair]
        let report = try GroupMining.run(
            labels: labels, columns: columns, values: values, options: spec.options,
            cancelToken: cancelToken)
        return Result(report: report, sourcePath: sourcePath)
    }

    private static func number(_ row: [String?], _ index: Int) -> Double {
        // Ô không đổi được sang số thành `nan`, và `GroupMining` lọc `isFinite` — nó bị BỎ QUA
        // chứ không thành 0. Một ô lỗi thành 0 sẽ kéo trung vị của cả nhóm.
        guard index < row.count, let text = row[index], let value = Double(text) else {
            return .nan
        }
        return value
    }

    // MARK: - Kết xuất

    public static func html(
        _ result: Result, spec: MiningBlockSpec, style: NumberStyle,
        chartWidth: Double = 720, chartHeight: Double = 300
    ) -> String {
        let report = result.report
        let ranked = report.ranked(by: spec.rank, limit: spec.limit)

        var out = "<section class=\"g-mining\">"
        if !spec.title.isEmpty {
            out += "<h3>" + MarkdownHTML.escape(spec.title) + "</h3>"
        }
        let scored = report.groups.filter { $0.note.isEmpty }.count
        var facts = ["\(report.groups.count) nhóm theo «\(spec.groupBy)»",
                     "\(scored) nhóm chấm được",
                     "xếp theo: " + spec.rank.vietnamese]
        if report.truncated > 0 { facts.append("\(report.truncated) nhóm BỊ CẮT") }
        out += "<p class=\"g-note\">" + MarkdownHTML.escape(facts.joined(separator: " · "))
            + "</p>"

        if ranked.isEmpty {
            // Bảng rỗng KHÔNG được vẽ thành một cái khung trống: nó có nghĩa cụ thể, và nghĩa ấy
            // khác nhau tuỳ vì sao.
            out += "<p class=\"g-note\">Không nhóm nào chấm được theo tiêu chí này — "
                + "\(report.groups.count) nhóm đều dưới \(spec.minimumRows) hàng, hoặc chỉ tiêu "
                + "này (\(MarkdownHTML.escape(spec.rank.vietnamese))) không đo được trên dữ "
                + "liệu đang có.</p>"
        } else {
            out += table(ranked, spec: spec, style: style, pooled: report.pooledCorrelation)
            if spec.chart, let svg = chart(
                ranked, spec: spec, style: style, width: chartWidth, height: chartHeight) {
                out += svg
            }
        }

        // Nhóm KHÔNG chấm được: nói ra, kèm số lượng và lý do đầu tiên.
        let skipped = report.groups.filter { !$0.note.isEmpty }
        if !skipped.isEmpty {
            out += "<p class=\"g-note\">\(skipped.count) nhóm không chấm được — ví dụ «"
                + MarkdownHTML.escape(skipped[0].name) + "»: "
                + MarkdownHTML.escape(skipped[0].note) + "</p>"
        }

        // NFR-MIN-04 — khối Phương pháp, không tắt được. Xem ghi chú ở `MiningBlockSpec`.
        out += "<details class=\"g-formulas\" open><summary>Phương pháp</summary>"
        for line in report.methodology.split(separator: "\n") {
            out += "<p>" + MarkdownHTML.escape(String(line)) + "</p>"
        }
        out += "</details></section>"
        return out
    }

    static func table(
        _ groups: [GroupMining.GroupResult], spec: MiningBlockSpec, style: NumberStyle,
        pooled: Double?
    ) -> String {
        var headers = ["Nhóm", "Số hàng", "Bất thường", "Tỷ lệ"]
        if spec.rank == .forecastError || groups.contains(where: { $0.mape != nil }) {
            headers.append("MAPE")
        }
        let hasCorrelation = !spec.pair.isEmpty
        if hasCorrelation {
            headers.append("r")
            headers.append("Lệch r")
        }

        var out = "<div class=\"g-table-wrap\"><table><thead><tr>"
            + headers.map { "<th>" + MarkdownHTML.escape($0) + "</th>" }.joined()
            + "</tr></thead><tbody>"
        for group in groups {
            out += "<tr><td class=\"txt\">" + MarkdownHTML.escape(group.name) + "</td>"
                + "<td class=\"num\">\(group.rowCount)</td>"
                + "<td class=\"num\">\(group.anomalies)</td>"
                + "<td class=\"num\">" + percent(group.anomalyRate) + "</td>"
            if headers.contains("MAPE") {
                out += "<td class=\"num\">"
                    + (group.mape.map { percent($0) } ?? "—") + "</td>"
            }
            if hasCorrelation {
                out += "<td class=\"num\">"
                    + (group.correlation.map { decimal($0) } ?? "—") + "</td>"
                out += "<td class=\"num\">"
                    + (group.correlationGap.map { decimal($0) } ?? "—") + "</td>"
            }
            out += "</tr>"
        }
        out += "</tbody></table>"
        if hasCorrelation {
            // Mốc để đọc cột "Lệch r" phải nằm CẠNH bảng: không có nó thì 0,8 là to hay nhỏ đều
            // không nói được.
            out += "<p class=\"g-note\">Tương quan trên TOÀN BỘ dữ liệu: "
                + (pooled.map { decimal($0) } ?? "không đo được")
                + " — cột «Lệch r» đo khoảng cách tới mốc này.</p>"
        }
        out += "</div>"
        return out
    }

    static func chart(
        _ groups: [GroupMining.GroupResult], spec: MiningBlockSpec, style: NumberStyle,
        width: Double, height: Double
    ) -> String? {
        let points: [ChartData.Point] = groups.enumerated().compactMap { index, group in
            let value: Double?
            switch spec.rank {
            case .anomalies: value = group.anomalyRate
            case .forecastError: value = group.mape
            case .correlationGap: value = group.correlationGap
            }
            guard let value, value.isFinite else { return nil }
            return ChartData.Point(x: Double(index), y: value, label: group.name)
        }
        guard !points.isEmpty else { return nil }
        let layout = ChartRender.Layout(width: width, height: height)
        let chartStyle = ChartRender.Style(palette: .gLight, numbers: style)
        let series = ChartData.Series(
            name: spec.rank.vietnamese, points: points, originalCount: points.count)
        let primitives = ChartRender.primitives(
            kind: .bar, series: series, layout: layout,
            title: spec.rank.vietnamese, style: chartStyle)
        return "<figure class=\"g-chart\">"
            + ChartRender.svg(primitives, layout: layout, style: chartStyle) + "</figure>"
    }

    /// Định dạng số của bảng — dùng ĐÚNG hàm mà panel `GroupMiningPanel` dùng.
    ///
    /// Không phải để tiết kiệm mã: bản đầu ở đây in 3 chữ số thập phân, và tấm thẻ nói tương
    /// quan toàn bộ là **0,999** trong khi khối Phương pháp ngay dưới nó — dựng bởi
    /// `GroupMining` — nói **1,00**. Hai con số cho cùng một đại lượng trong cùng một khung là
    /// chỗ người đọc thôi tin cả hai. Một quy ước, ba nơi: panel, khối Phương pháp, và thẻ này.
    static func percent(_ value: Double) -> String {
        ChartRender.number(value) + "%"
    }

    static func decimal(_ value: Double) -> String {
        ChartRender.number(value)
    }

    static let stylesheet = """
        .g-mining { margin: 1.4em 0; }
        .g-mining h3 { margin: 0 0 6px; font-size: 1.05em; }
        @media print { .g-mining { break-inside: avoid; page-break-inside: avoid; } }
        """
}
