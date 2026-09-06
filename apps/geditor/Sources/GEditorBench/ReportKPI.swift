import Foundation
import GEditorCore

/// NFR-RPT-01 — *"Báo cáo 10 block trên nguồn 1 triệu dòng render ≤ 5 giây; kết quả block được
/// cache theo hash(query + trạng thái nguồn) — chỉ block có nguồn đổi mới chạy lại"*.
///
/// Chỉ tiêu có HAI vế, và bộ đo này hỏi cả hai. Vế thời gian thì hiển nhiên; vế cache thì phải
/// đo bằng cách dựng LẠI đúng tài liệu ấy trên đúng nguồn ấy và xem lượt thứ hai có rẻ đi
/// không. Một bộ đo chỉ hỏi vế đầu sẽ báo ĐẠT cho một hiện thực không có cache nào cả.
enum ReportKPI {

    struct Report: Encodable {
        let kpi: String
        let architecture: String
        let rows: Int
        let blocks: Int
        let firstRenderMs: Double
        let secondRenderMs: Double
        let budgetMs: Double
        /// Lượt hai có rẻ hơn đáng kể không — dấu hiệu của cache theo khối.
        let cacheHelps: Bool
        let succeeded: Int
        let pass: Bool
        let notes: [String]
    }

    static func run(rows: Int) throws -> Report {
        var notes: [String] = []
        FileHandle.standardError.write(Data("   dựng \(rows) hàng…\n".utf8))

        // Nguồn: cùng khuôn fixture với KPI làm sạch, để hai bộ đo nói về cùng một hình dạng
        // dữ liệu chứ không mỗi bộ một kiểu.
        let bytes = CleanKPI.fixture(rows: rows, columns: 8)
        let buffer = TextBuffer(original: MemoryByteSource(bytes))

        // Mười khối, đúng con số chỉ tiêu nói tới: năm truy vấn và năm biểu đồ. Mỗi khối hỏi
        // một câu KHÁC nhau — mười bản sao của một câu sẽ đo trúng cache của DuckDB chứ không
        // đo sức nặng thật của một trang báo cáo.
        var text = "# Báo cáo đo tải\n\n"
        // Tên cột lấy từ CHÍNH fixture (`ma_kh`, `thanh_pho`, `doanh_thu`, `ghi_chu`, `ngay`).
        // Bản đầu bịa ra `trang_thai` và sáu trong mười khối trượt — con số thời gian khi ấy đo
        // một trang báo cáo bốn khối trong khi nhãn ghi mười.
        let columns = ["thanh_pho", "ma_kh", "ghi_chu"]
        for index in 0 ..< 5 {
            let column = columns[index % columns.count]
            text += """
                ```query
                SELECT \(column), COUNT(*) AS so_dong, SUM(doanh_thu) AS tong
                FROM t GROUP BY \(column) ORDER BY tong DESC LIMIT \(5 + index)
                ```

                ```chart
                kind: bar
                query: SELECT \(column), SUM(doanh_thu) AS tong FROM t GROUP BY \(column) ORDER BY tong DESC LIMIT \(5 + index)
                title: Doanh thu theo \(column) (\(index))
                ```


                """
        }

        let document = try ReportDocument.parse(text)
        // Cùng MỘT bộ nhớ tạm cho cả hai lượt — đó là cả điểm của phép đo. Truyền hai bộ khác
        // nhau thì lượt hai luôn "miss" và bộ đo báo không có cache dù cache chạy đúng.
        let cache = ReportBlockCache()
        let options = ReportRenderer.Options(blockCache: cache)
        var succeeded = 0
        let first = Measure.milliseconds {
            if let rendered = try? ReportRenderer.render(
                document, in: buffer, dialect: .comma, options: options) {
                succeeded = rendered.succeeded
            }
        }
        let second = Measure.milliseconds {
            _ = try? ReportRenderer.render(document, in: buffer, dialect: .comma, options: options)
        }

        // "Rẻ đi đáng kể" = dưới một nửa. Ngưỡng lỏng có chủ ý: cache thật thì lượt hai gần như
        // tức thì, còn dao động đo đạc bình thường không bao giờ tới một nửa.
        let cacheHelps = second < first / 2 && cache.hits > 0
        if !cacheHelps {
            notes.append(String(
                format: "KHÔNG thấy dấu hiệu cache theo khối: lượt hai %.0f ms so lượt đầu "
                    + "%.0f ms. Chỉ tiêu đòi «cache theo hash(query + trạng thái nguồn)».",
                second, first))
        }
        notes.append("cache khối: \(cache.hits) lần trúng · \(cache.misses) lần trượt")
        if succeeded != 10 {
            notes.append("chỉ \(succeeded)/10 khối chạy được — con số thời gian đo thiếu khối.")
        }

        let budget = 5_000.0
        return Report(
            kpi: "NFR-RPT-01", architecture: MiningKPI.architecture(),
            rows: rows, blocks: 10,
            firstRenderMs: first, secondRenderMs: second, budgetMs: budget,
            cacheHelps: cacheHelps, succeeded: succeeded,
            pass: first <= budget && succeeded == 10 && cacheHelps,
            notes: notes)
    }
}
