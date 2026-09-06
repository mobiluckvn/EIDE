import Foundation

/// Vẽ scorecard sức khoẻ đồ thị cho khối ```quality ở chế độ đồ thị — FR-KNW-924.
///
/// Dùng LẠI phần trình bày sáu chiều của `QualityCard`, hệt như `ChunkQualityCard`. Ba chế độ
/// của khối ```quality chia nhau một tấm thẻ điểm; viết ba bản là ba bản sẽ trôi khỏi nhau, và
/// thứ trôi trước tiên bao giờ cũng là câu "chiều này không chấm được".
public enum GraphQualityCard {

    public static let defaultRowLimit = 30

    public static func html(
        _ report: GraphQuality.Report, spec: QualityBlockSpec,
        rowLimit: Int = defaultRowLimit
    ) -> String {
        let score = report.score
        let state = QualityCard.state(total: score.total, threshold: spec.failUnder)

        var facts = [
            "\(report.nodeCount) node · \(report.edgeCount) cạnh",
            "\(report.islands) đảo",
        ]
        if report.orphans.count > 0 { facts.append("\(report.orphans.count) mồ côi") }
        if report.danglingEdges > 0 { facts.append("\(report.danglingEdges) cạnh treo") }
        if report.duplicateEdges > 0 { facts.append("\(report.duplicateEdges) cạnh trùng") }
        if let threshold = spec.failUnder {
            facts.append("ngưỡng \(QualityCard.format(threshold))")
        }
        facts.append("đồ thị: " + (spec.graph as NSString).lastPathComponent)

        var out = QualityCard.header(
            score: score, state: state,
            title: spec.title.isEmpty ? "Sức khoẻ đồ thị" : spec.title, facts: facts)
        out += QualityCard.dimensionBars(score)
        out += QualityCard.unscoredNote(score)
        out += QualityCard.formulas(score)
        out += "<p class=\"g-note\">"
            + MarkdownHTML.escape(GraphQuality.methodology(report)) + "</p>"
        out += "</section>"
        out += problemTable(report, limit: rowLimit)
        return out
    }

    /// Bảng lỗi — đặc tả đòi *"danh sách lỗi click-nhảy-dòng"*.
    ///
    /// Cột DÒNG đứng đầu và là số 1-based: trong một báo cáo HTML thì không bấm nhảy được, nhưng
    /// số dòng vẫn là thứ người đọc gõ vào ô "đi tới dòng". Đường bấm-nhảy thật nằm ở panel.
    private static func problemTable(_ report: GraphQuality.Report, limit: Int) -> String {
        guard !report.problems.isEmpty else {
            return "<p class=\"g-note\">Không tìm thấy lỗi cấu trúc nào.</p>"
        }
        var out = "<div class=\"g-table-wrap\"><table class=\"g-rules\"><caption>"
            + "Lỗi cấu trúc</caption><thead><tr><th>Dòng</th><th>Loại</th><th>Chi tiết</th>"
            + "</tr></thead><tbody>"
        for problem in report.problems.prefix(limit) {
            out += "<tr class=\"g-rule-\(cssClass(problem.kind))\">"
                + "<td class=\"num\">\(problem.line + 1)</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(problem.kind.vietnamese) + "</td>"
                + "<td class=\"txt\">" + MarkdownHTML.escape(problem.detail) + "</td></tr>"
        }
        out += "</tbody></table>"
        if report.problems.count > limit {
            out += "<p class=\"g-note\">Bảng hiện \(limit) / \(report.problems.count) lỗi.</p>"
        }
        return out + "</div>"
    }

    /// Mức nặng của từng loại lỗi.
    ///
    /// Cạnh treo và thiếu thuộc tính bắt buộc là LỖI: đồ thị không dùng được như đã hứa. Node mồ
    /// côi, cạnh trùng và nhãn gần nhau là CẢNH BÁO — chúng có thể cố ý, và nhuộm đỏ một thứ cố
    /// ý là dạy người dùng bỏ qua màu đỏ.
    private static func cssClass(_ kind: GraphQuality.Problem.Kind) -> String {
        switch kind {
        case .danglingEdge, .missingNodeKey, .missingEdgeKey: return "fail"
        case .orphan, .duplicateEdge, .nearLabel: return "warn"
        }
    }
}
