import Foundation

/// Vẽ thẻ Chunk Quality Report cho khối ```quality ở chế độ corpus — FR-KNW-922.
///
/// Dùng LẠI phần trình bày sáu chiều của `QualityCard` (đầu thẻ, dải thanh, câu "chiều này
/// không chấm được", bảng công thức) và chỉ thêm bốn bảng riêng của corpus chunk. Hai bản vẽ
/// riêng cho cùng một khung là hai bản sẽ trôi khỏi nhau, và thứ trôi trước tiên bao giờ cũng
/// là câu đắt nhất — câu nói ra chiều nào không chấm được.
public enum ChunkQualityCard {

    /// Số dòng tối đa của mỗi bảng phụ. Bảng dài hơn thì cắt và NÓI RA đã cắt bao nhiêu.
    public static let defaultRowLimit = 20

    public static func html(
        _ report: ChunkQuality.Report, spec: QualityBlockSpec, rowLimit: Int = defaultRowLimit
    ) -> String {
        let score = report.score
        let state = QualityCard.state(total: score.total, threshold: spec.failUnder)

        var facts: [String] = ["\(report.chunkCount) chunk"]
        facts.append("trung vị \(report.medianTokens) token")
        if !report.brokenLines.isEmpty {
            facts.append("\(report.brokenLines.count) dòng hỏng")
        }
        if let threshold = spec.failUnder {
            facts.append("ngưỡng \(QualityCard.format(threshold))")
        }
        facts.append("corpus: " + (spec.corpus as NSString).lastPathComponent)

        var out = QualityCard.header(
            score: score, state: state,
            title: spec.title.isEmpty ? "Chất lượng corpus chunk" : spec.title, facts: facts)
        out += QualityCard.dimensionBars(score)
        out += QualityCard.unscoredNote(score)
        out += QualityCard.formulas(score)

        // Khối "Phương pháp" — NFR-MIN-04. Nó nói ra cách ĐẾM TOKEN, và đó là con số duy nhất
        // trong cả thẻ này mà người đọc dễ hiểu nhầm là con số của model.
        out += "<p class=\"g-note\">Phương pháp: "
            + MarkdownHTML.escape(report.config.estimator.methodology)
            + MarkdownHTML.escape("; trùng gần = Jaccard trên shingle "
                + "\(report.config.shingle)-gram ký tự sau chuẩn hoá (gom khoảng trắng, hạ chữ "
                + "thường), ngưỡng \(ChunkQuality.TokenEstimator.format(report.config.nearDuplicate))"
                + ", so vét cạn trên ứng viên qua lọc tiền tố nên KHÔNG bỏ sót cặp nào.")
            + "</p>"
        out += "</section>"

        out += tokenSection(report, rowLimit: rowLimit)
        out += duplicateSection(report, rowLimit: rowLimit)
        out += boilerplateSection(report, rowLimit: rowLimit)
        out += sourceSection(report, rowLimit: rowLimit)
        out += brokenSection(report, rowLimit: rowLimit)
        return out
    }

    // MARK: - (a) Phân bố token

    private static func tokenSection(_ report: ChunkQuality.Report, rowLimit: Int) -> String {
        let counts = report.chunks.map(\.tokens).sorted()
        guard let smallest = counts.first, let largest = counts.last else { return "" }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Phân bố token</caption><thead><tr><th>Mốc</th><th>Token</th></tr></thead><tbody>"
        for (name, value) in [
            ("nhỏ nhất", smallest), ("phân vị 25", percentile(counts, 0.25)),
            ("trung vị", percentile(counts, 0.50)), ("phân vị 95", percentile(counts, 0.95)),
            ("lớn nhất", largest),
        ] {
            out += "<tr><td class=\"txt\">\(name)</td><td class=\"num\">\(value)</td></tr>"
        }
        out += "</tbody></table></div>"

        let offenders = report.overLimit.map { ($0, "vượt") } + report.underLimit.map { ($0, "ngắn") }
        guard !offenders.isEmpty else { return out }
        // Vượt ngưỡng lên trước, rồi tới quá ngắn — chunk bị model cắt cụt là lỗi nặng hơn.
        let ordered = offenders.sorted {
            $0.1 != $1.1 ? $0.1 > $1.1 : ($0.1 == "vượt" ? $0.0.tokens > $1.0.tokens
                                                         : $0.0.tokens < $1.0.tokens)
        }
        out += "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Chunk ngoài ngưỡng</caption><thead><tr><th>Loại</th><th>Chunk</th>"
            + "<th>Dòng</th><th>Token</th></tr></thead><tbody>"
        for (chunk, kind) in ordered.prefix(rowLimit) {
            out += "<tr class=\"g-rule-\(kind == "vượt" ? "fail" : "warn")\">"
                + "<td class=\"txt\">\(kind)</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(chunk.id) + "</td>"
                + "<td class=\"num\">\(chunk.line + 1)</td>"
                + "<td class=\"num\">\(chunk.tokens)</td></tr>"
        }
        out += "</tbody></table>"
        out += truncationNote(shown: min(rowLimit, ordered.count), total: ordered.count)
        return out + "</div>"
    }

    /// Phân vị theo kiểu "lấy phần tử gần nhất" trên dãy ĐÃ SẮP — không nội suy.
    ///
    /// Không nội suy vì số token là số nguyên và người đọc sẽ đối chiếu con số này với một
    /// chunk có thật; một "phân vị 95 = 412,5 token" thì không chunk nào có.
    static func percentile(_ sorted: [Int], _ fraction: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let index = Int((Double(sorted.count - 1) * fraction).rounded())
        return sorted[max(0, min(sorted.count - 1, index))]
    }

    // MARK: - (b) Trùng gần

    private static func duplicateSection(
        _ report: ChunkQuality.Report, rowLimit: Int
    ) -> String {
        if let skipped = report.nearDuplicateSkipped {
            return "<p class=\"g-note g-unscored\">" + MarkdownHTML.escape(
                "Không chấm TRÙNG GẦN: corpus có \(skipped) chunk, vượt trần "
                + "«near_dup_limit» = \(report.config.nearDuplicateLimit). Đặt "
                + "«near_dup_limit: 0» để bỏ trần — phép so giữ trọn tập shingle của mọi chunk "
                + "trong bộ nhớ, nên trần này là trần RAM chứ không phải trần thuật toán.")
                + "</p>"
        }
        guard !report.duplicateClusters.isEmpty else { return "" }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Cụm trùng gần</caption><thead><tr><th>Cụm</th><th>Số chunk</th>"
            + "<th>Dòng</th></tr></thead><tbody>"
        for (index, cluster) in report.duplicateClusters.prefix(rowLimit).enumerated() {
            let lines = cluster.prefix(12).map { String($0 + 1) }.joined(separator: ", ")
            out += "<tr class=\"g-rule-warn\"><td class=\"num\">\(index + 1)</td>"
                + "<td class=\"num\">\(cluster.count)</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(
                    lines + (cluster.count > 12 ? ", …" : "")) + "</td></tr>"
        }
        out += "</tbody></table>"
        out += truncationNote(
            shown: min(rowLimit, report.duplicateClusters.count),
            total: report.duplicateClusters.count)
        return out + "</div>"
    }

    // MARK: - (c) Boilerplate

    private static func boilerplateSection(
        _ report: ChunkQuality.Report, rowLimit: Int
    ) -> String {
        guard !report.boilerplate.isEmpty else { return "" }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Boilerplate</caption><thead><tr><th>Vị trí</th><th>Số lần</th>"
            + "<th>Đoạn (đã chuẩn hoá)</th>"
            + "<th>Dòng đầu</th></tr></thead><tbody>"
        for item in report.boilerplate.prefix(rowLimit) {
            let preview = item.text.count > 90
                ? String(item.text.prefix(90)) + "…" : item.text
            out += "<tr class=\"g-rule-warn\"><td class=\"txt\">"
                + MarkdownHTML.escape(item.position.vietnamese) + "</td>"
                + "<td class=\"num\">\(item.count)</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(preview) + "</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(
                    item.lines.prefix(8).map { String($0 + 1) }.joined(separator: ", ")
                    + (item.lines.count > 8 ? ", …" : "")) + "</td></tr>"
        }
        out += "</tbody></table>"
        out += truncationNote(
            shown: min(rowLimit, report.boilerplate.count), total: report.boilerplate.count)
        return out + "</div>"
    }

    // MARK: - (d) Coverage theo nguồn

    private static func sourceSection(
        _ report: ChunkQuality.Report, rowLimit: Int
    ) -> String {
        guard !report.sourceCounts.isEmpty || !report.missingSources.isEmpty else { return "" }
        let total = report.sourceCounts.reduce(0) { $0 + $1.count }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Phủ theo nguồn</caption><thead><tr><th>Nguồn</th><th>Chunk</th><th>Tỷ lệ</th>"
            + "</tr></thead><tbody>"
        for item in report.sourceCounts.prefix(rowLimit) {
            let share = total > 0 ? 100 * Double(item.count) / Double(total) : 0
            out += "<tr><td class=\"txt\">" + MarkdownHTML.escape(item.source) + "</td>"
                + "<td class=\"num\">\(item.count)</td>"
                + "<td class=\"num\">" + String(format: "%.2f%%", share) + "</td></tr>"
        }
        // Nguồn KHAI RỒI mà không có chunk nào: dòng số 0, không phải dòng vắng mặt. Một nguồn
        // vắng mặt khỏi bảng là một nguồn người đọc sẽ không nhớ ra là mình đã khai.
        for source in report.missingSources.prefix(rowLimit) {
            out += "<tr class=\"g-rule-fail\"><td class=\"txt\">"
                + MarkdownHTML.escape(source) + "</td>"
                + "<td class=\"num\">0</td><td class=\"num\">"
                + String(format: "%.2f%%", 0.0) + "</td></tr>"
        }
        out += "</tbody></table>"
        out += truncationNote(
            shown: min(rowLimit, report.sourceCounts.count), total: report.sourceCounts.count)
        return out + "</div>"
    }

    // MARK: - Dòng hỏng

    private static func brokenSection(
        _ report: ChunkQuality.Report, rowLimit: Int
    ) -> String {
        guard !report.brokenLines.isEmpty else { return "" }
        let lines = report.brokenLines.prefix(rowLimit).map { String($0 + 1) }
            .joined(separator: ", ")
        return "<p class=\"g-note g-unscored\">" + MarkdownHTML.escape(
            "\(report.brokenLines.count) dòng không có trường «\(report.config.textField)» và "
            + "KHÔNG được chấm: dòng \(lines)"
            + (report.brokenLines.count > rowLimit ? ", …" : "")
            + ". Chúng vẫn giữ chỗ trong đánh số dòng.") + "</p>"
    }

    private static func truncationNote(shown: Int, total: Int) -> String {
        guard total > shown else { return "" }
        return "<p class=\"g-note\">Bảng hiện \(shown) / \(total) dòng.</p>"
    }
}
