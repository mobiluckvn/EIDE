import Foundation
import GEditorCore

/// Bản đồ tài liệu phải dựng được trên file BẤT KỲ CỠ NÀO (FR-DOC-306).
///
/// Đây là phép đo kiểm chứng chính lý do thiết kế: bản đồ đọc CHỈ MỤC DÒNG chứ không đọc nội
/// dung, nên chi phí phụ thuộc số HÀNG của bản đồ (vài trăm), không phụ thuộc kích thước file.
/// Nếu con số dưới đây tăng theo cỡ file thì lập luận ấy sai và phải thiết kế lại.
///
/// Bản đồ vẽ lại mỗi lần cuộn, nên nó phải nằm trong ngân sách một khung hình: 16 ms.
struct DocumentMapKPIReport: Encodable {
    struct Result: Encodable {
        let rows: Int
        let milliseconds: Double
        let produced: Int
    }
    let kpi: String
    let file: String
    let bytes: Int
    let lines: Int
    let openMilliseconds: Double
    let budgetMilliseconds: Double
    let pass: Bool
    let results: [Result]
}

enum DocumentMapKPI {

    static func run(path: String, rowCounts: [Int]) throws -> DocumentMapKPIReport {
        let openedAt = Date()
        let document = try Document.open(path: path)
        let openMs = Date().timeIntervalSince(openedAt) * 1000

        var results: [DocumentMapKPIReport.Result] = []
        for rows in rowCounts {
            var best = Double.infinity
            var produced = 0
            for _ in 0 ..< 5 {
                let started = Date()
                let map = DocumentMap(buffer: document.buffer, rowCount: rows)
                best = Swift.min(best, Date().timeIntervalSince(started) * 1000)
                produced = map.rows.count
            }
            results.append(.init(rows: rows, milliseconds: best, produced: produced))
        }

        let slowest = results.map(\.milliseconds).max() ?? 0
        return DocumentMapKPIReport(
            kpi: "FR-DOC-306 — dựng bản đồ tài liệu",
            file: path,
            bytes: document.buffer.count,
            lines: document.buffer.lineCount,
            openMilliseconds: openMs,
            budgetMilliseconds: 16,
            pass: slowest <= 16,
            results: results
        )
    }
}
