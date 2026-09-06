import Foundation

/// Bảng so sánh trôi dạt trong báo cáo — FR-DQR-004.
///
/// Phần DỮ LIỆU của trôi dạt nằm ở `QualityHistory` (lớp CSV, không biết gì về HTML); tệp này
/// chỉ vẽ. Tách ra vì cùng phép so ấy được ba nơi dùng: báo cáo `.greport.md`, panel xu hướng
/// trong app, và JSON của quality gate CLI — mà chỉ nơi đầu cần HTML.
extension QualityDrift {

    /// Bảng "so với lần chạy trước". Trả về chuỗi rỗng khi chưa có lần trước để mà so.
    public static func html(_ comparison: Comparison) -> String {
        guard let previous = comparison.previous else { return "" }
        let before = previous.timestamp
        let after = comparison.current.timestamp

        var out = "<section class=\"g-drift\"><h4>So với lần chạy trước</h4>"
        var facts: [String] = ["\(MarkdownHTML.escape(before)) → \(MarkdownHTML.escape(after))"]
        if let delta = comparison.totalDelta {
            facts.append("điểm tổng " + signed(delta))
        }
        if let rows = comparison.rowCountDelta {
            facts.append("số hàng \(previous.rowCount) → \(comparison.current.rowCount)"
                + (rows == 0 ? "" : " (" + signedInt(rows) + ")"))
        }
        out += "<p class=\"g-note\">" + facts.joined(separator: " · ") + "</p>"

        // --- Chiều nào tụt ---------------------------------------------------------------
        let moved = comparison.dimensions.filter {
            guard let delta = $0.delta else { return $0.before != $0.after }
            return abs(delta) >= 0.05
        }
        if moved.isEmpty {
            out += "<p class=\"g-note\">Không chiều nào đổi quá 0,05 điểm.</p>"
        } else {
            out += "<div class=\"g-table-wrap\"><table><thead><tr><th>Chiều</th>"
                + "<th>Trước</th><th>Sau</th><th>Lệch</th></tr></thead><tbody>"
            // Tụt nhiều nhất lên đầu — cùng lý do với bảng luật của thẻ điểm.
            for entry in moved.sorted(by: { ($0.delta ?? 0) < ($1.delta ?? 0) }) {
                let delta = entry.delta
                let cssClass = (delta ?? 0) < 0 ? "g-down" : ((delta ?? 0) > 0 ? "g-up" : "")
                out += "<tr class=\"\(cssClass)\"><td class=\"txt\">"
                    + MarkdownHTML.escape(entry.vietnamese) + "</td>"
                    + "<td class=\"num\">" + number(entry.before) + "</td>"
                    + "<td class=\"num\">" + number(entry.after) + "</td>"
                    + "<td class=\"num\">"
                    + (delta.map { signed($0) } ?? "—") + "</td></tr>"
            }
            out += "</tbody></table></div>"
        }

        // --- Luật đổi trạng thái ----------------------------------------------------------
        if !comparison.newlyFailing.isEmpty {
            out += list("Luật MỚI trượt", comparison.newlyFailing, cssClass: "g-down")
        }
        if !comparison.newlyPassing.isEmpty {
            out += list("Luật nay ĐẠT", comparison.newlyPassing, cssClass: "g-up")
        }

        // --- %null từng cột ---------------------------------------------------------------
        let columns = comparison.columns.prefix(10)
        if !columns.isEmpty {
            out += "<div class=\"g-table-wrap\"><table><thead><tr><th>Cột</th>"
                + "<th>%null trước</th><th>%null sau</th><th>Lệch</th></tr></thead><tbody>"
            for entry in columns {
                let cssClass = entry.delta > 0 ? "g-down" : "g-up"
                out += "<tr class=\"\(cssClass)\"><td class=\"txt\">"
                    + MarkdownHTML.escape(entry.column) + "</td>"
                    + "<td class=\"num\">" + percent(entry.before) + "</td>"
                    + "<td class=\"num\">" + percent(entry.after) + "</td>"
                    + "<td class=\"num\">" + signed(entry.delta, digits: 2) + "</td></tr>"
            }
            out += "</tbody></table>"
            if comparison.columns.count > columns.count {
                out += "<p class=\"g-note\">Bảng hiện \(columns.count) / "
                    + "\(comparison.columns.count) cột đã đổi.</p>"
            }
            out += "</div>"
        }

        // Nguồn khác nhau thì lệch điểm CHƯA CHẮC là trôi dạt chất lượng — nói ra.
        if !previous.sourceHash.isEmpty, !comparison.current.sourceHash.isEmpty,
           previous.sourceHash != comparison.current.sourceHash {
            out += "<p class=\"g-note\">Hai lượt chấm trên hai bản dữ liệu KHÁC nhau "
                + "(hash nguồn lệch) — đó là điều bình thường giữa hai đợt nhận dữ liệu.</p>"
        } else if !previous.sourceHash.isEmpty,
                  previous.sourceHash == comparison.current.sourceHash {
            out += "<p class=\"g-note\">Cùng một bản dữ liệu (hash nguồn giống nhau): mọi khác "
                + "biệt phía trên là do BỘ LUẬT đổi, không phải do dữ liệu.</p>"
        }
        out += "</section>"
        return out
    }

    private static func list(_ title: String, _ items: [String], cssClass: String) -> String {
        "<p class=\"g-drift-list \(cssClass)\"><strong>" + MarkdownHTML.escape(title)
            + " (\(items.count)):</strong> "
            + items.prefix(10).map(MarkdownHTML.escape).joined(separator: " · ")
            + (items.count > 10 ? " …" : "") + "</p>"
    }

    private static func number(_ value: Double?) -> String {
        // Chiều KHÔNG chấm được vẫn là `—`, kể cả trong bảng so sánh: đổi nó thành 0 ở đây sẽ
        // sinh ra một dòng "tụt 87 điểm" cho một chiều chưa bao giờ có điểm.
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    private static func signed(_ value: Double, digits: Int = 1) -> String {
        String(format: "%@%.\(digits)f", value >= 0 ? "+" : "−", abs(value))
    }

    private static func signedInt(_ value: Int) -> String {
        (value >= 0 ? "+" : "−") + String(abs(value))
    }

    public static let stylesheet = """
        .g-drift { margin: 1.2em 0; padding: 12px 14px; border-radius: 8px;
                   border: 1px dashed #d0d0d0; }
        .g-drift h4 { margin: 0 0 6px; font-size: 1em; }
        .g-drift table { font-size: 0.88em; }
        .g-drift-list { font-size: 0.9em; }
        .g-drift tr.g-down td:first-child, .g-drift-list.g-down strong { color: #a12a12; }
        .g-drift tr.g-up td:first-child, .g-drift-list.g-up strong { color: #1d6b3a; }
        @media (prefers-color-scheme: dark) {
          .g-drift { border-color: #444; }
          .g-drift tr.g-down td:first-child, .g-drift-list.g-down strong { color: #f0846a; }
          .g-drift tr.g-up td:first-child, .g-drift-list.g-up strong { color: #6fcf8f; }
        }
        @media print { .g-drift { break-inside: avoid; page-break-inside: avoid; } }
        """
}
