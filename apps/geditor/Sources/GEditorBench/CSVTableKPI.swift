import Foundation
import GEditorCore

/// Đo Table view CSV — FR-CSV-403.
///
/// Đặc tả nói "chuyển đổi tức thời (< 100 ms với 1 triệu dòng nhờ chỉ mục CSVEngine)". Câu ấy
/// gộp hai chi phí rất khác nhau, và đo gộp thì con số vô nghĩa:
///
///  1. **Dựng chỉ mục** — quét cả file MỘT lần. Không thể dưới 100 ms với 1 triệu hàng, và
///     không cần: nó chạy ở luồng nền ngay khi vào chế độ CSV, trước khi ai bấm chuyển bảng.
///  2. **Chuyển chế độ** — dựng bảng và hỏi những hàng đang nhìn thấy. ĐÂY mới là thứ phải
///     dưới 100 ms, vì người dùng đang chờ nhìn.
///
/// Nên đo tách. Gộp lại thành một con số "chuyển chế độ 3 giây" là tự đặt cho mình một trần
/// không đạt nổi, còn báo cáo mỗi phần nhanh mà giấu phần chậm là nói dối.
struct CSVTableKPIReport: Encodable {

    struct Build: Encodable {
        let rows: Int
        let fixtureMB: Double
        let buildMs: Double
        /// Bộ nhớ chỉ mục giữ: 8 byte cho mỗi mốc.
        let indexKB: Double
        /// Nếu ghi mọi hàng thay vì chỉ mục thưa.
        let denseIndexKB: Double
        let rowCount: Int
        let columnCount: Int
    }

    struct Lookup: Encodable {
        let samples: Int
        /// Đọc một màn hình (40 hàng) tại vị trí ngẫu nhiên — đúng việc `NSTableView` làm.
        let screenP50Ms: Double
        let screenP99Ms: Double
        let screenMaxMs: Double
        /// Đổi offset con nháy → số hàng, để giữ chỗ khi chuyển chế độ.
        let offsetToRowP99Ms: Double
        /// Tổng thời gian một lần chuyển chế độ: định vị con nháy + đổ một màn hình.
        let switchP99Ms: Double
        let budgetMs: Double
        let pass: Bool
    }

    struct Sort: Encodable {
        let rows: Int
        let numericColumnMs: Double
        let textColumnMs: Double
        let applyToFileMs: Double
        let applyEditCount: Int
        let orderCorrect: Bool
    }

    let kpi = ["FR-CSV-403 (Table view)"]
    let architecture: String
    let build: Build
    let lookup: Lookup
    let sort: Sort
    let notes: [String]
}

enum CSVTableKPI {

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("  \(message)\n".utf8))
    }

    static func run(rows: Int, samples: Int) throws -> CSVTableKPIReport {
        log("dựng fixture \(rows) hàng…")
        let bytes = fixture(rows: rows)
        let buffer = TextBuffer(original: MemoryByteSource(bytes))
        let fixtureMB = Double(bytes.count) / 1_048_576

        // --- dựng chỉ mục ---------------------------------------------------------------
        var index: CSVRowIndex?
        let buildMs = Measure.milliseconds {
            index = try? CSVRowIndex.build(in: buffer, dialect: .comma)
        }
        guard let index else { throw BenchError.failed("không dựng được chỉ mục") }

        let anchors = (index.rowCount + CSVRowIndex.anchorStride - 1) / CSVRowIndex.anchorStride
        log(String(format: "  chỉ mục: %.0f ms · %d hàng · %d cột · %.1f KB (dày đặc sẽ là %.1f KB)",
                   buildMs, index.rowCount, index.columnCount,
                   Double(anchors * 8) / 1024, Double(index.rowCount * 8) / 1024))

        // --- tra cứu: đúng việc bảng làm khi cuộn ----------------------------------------
        var rng = DeterministicRNG(seed: 403)
        let screenRows = 40
        var screenTimes: [Double] = []
        var offsetTimes: [Double] = []
        screenTimes.reserveCapacity(samples)
        offsetTimes.reserveCapacity(samples)

        for _ in 0 ..< samples {
            let row = rng.int(max(1, index.rowCount - screenRows))
            screenTimes.append(Measure.milliseconds {
                _ = index.rows(row ..< (row + screenRows), in: buffer)
            })
            // Con nháy ở một chỗ bất kỳ trong tài liệu.
            let offset = rng.int(max(1, buffer.count))
            offsetTimes.append(Measure.milliseconds {
                _ = index.rowNumber(containingOffset: offset, in: buffer)
            })
        }

        let screenSorted = screenTimes.sorted()
        let offsetSorted = offsetTimes.sorted()
        func percentile(_ values: [Double], _ p: Double) -> Double {
            values[min(values.count - 1, Int(Double(values.count) * p))]
        }

        let screenP99 = percentile(screenSorted, 0.99)
        let offsetP99 = percentile(offsetSorted, 0.99)
        let switchP99 = screenP99 + offsetP99
        let lookupPass = switchP99 <= 100

        log(String(format: "  một màn hình 40 hàng: p50 %.3f ms · p99 %.3f ms · max %.3f ms",
                   percentile(screenSorted, 0.5), screenP99, screenSorted.last ?? 0))
        log(String(format: "  offset → số hàng: p99 %.3f ms", offsetP99))
        log(String(format: "  CHUYỂN CHẾ ĐỘ p99 %.3f ms (trần 100 ms) · %@",
                   switchP99, lookupPass ? "ĐẠT" : "KHÔNG ĐẠT"))

        // --- sắp xếp ---------------------------------------------------------------------
        var numericOrder: CSVSort.Order?
        let numericMs = Measure.milliseconds {
            numericOrder = try? CSVSort.order(
                column: 4, direction: .descending, hasHeader: true, index: index, in: buffer
            )
        }
        let textMs = Measure.milliseconds {
            _ = try? CSVSort.order(
                column: 1, direction: .ascending, hasHeader: true, index: index, in: buffer
            )
        }

        var orderCorrect = false
        var applyMs = 0.0
        var editCount = 0
        if let numericOrder {
            // Kiểm ĐÚNG chứ không chỉ kiểm NHANH: cột 4 giảm dần thì mọi giá trị liền kề phải
            // không tăng. Một phép sắp xếp nhanh mà sai thì con số thời gian vô giá trị.
            let head = numericOrder.rows.prefix(2_000).map {
                Double(index.values(ofRow: $0, in: buffer)[4]) ?? -1
            }
            orderCorrect = zip(head, head.dropFirst()).allSatisfy { $0 >= $1 }

            var edits: [TextEdit] = []
            applyMs = Measure.milliseconds {
                edits = (try? CSVSort.applyEdits(
                    numericOrder, hasHeader: true, index: index, in: buffer
                )) ?? []
            }
            editCount = edits.count
        }

        log(String(format: "  sắp xếp cột SỐ %.0f ms · cột CHỮ %.0f ms · ghi vào file %.0f ms (%d edit) · thứ tự %@",
                   numericMs, textMs, applyMs, editCount, orderCorrect ? "đúng" : "SAI"))

        return CSVTableKPIReport(
            architecture: GEditorCore.architecture,
            build: .init(
                rows: rows, fixtureMB: fixtureMB, buildMs: buildMs,
                indexKB: Double(anchors * 8) / 1024,
                denseIndexKB: Double(index.rowCount * 8) / 1024,
                rowCount: index.rowCount, columnCount: index.columnCount
            ),
            lookup: .init(
                samples: samples,
                screenP50Ms: percentile(screenSorted, 0.5),
                screenP99Ms: screenP99,
                screenMaxMs: screenSorted.last ?? 0,
                offsetToRowP99Ms: offsetP99,
                switchP99Ms: switchP99,
                budgetMs: 100,
                pass: lookupPass
            ),
            sort: .init(
                rows: index.rowCount, numericColumnMs: numericMs, textColumnMs: textMs,
                applyToFileMs: applyMs, applyEditCount: editCount, orderCorrect: orderCorrect
            ),
            notes: [
                "Trần 100 ms của đặc tả áp cho CHUYỂN CHẾ ĐỘ, không cho lần dựng chỉ mục — dựng chỉ mục chạy nền một lần khi vào chế độ CSV.",
                "Vị trí tra cứu lấy ngẫu nhiên TẤT ĐỊNH khắp tài liệu: đọc tuần tự sẽ được đệm của hệ điều hành che cho và cho ra con số dễ hơn thực tế.",
                "Fixture có quoted field chứa dấu phẩy và xuống dòng, nên đường phân tích lại khối là đường thật chứ không phải đường tắt.",
                "Con số là của MÁY ĐANG ĐO; phải đo lại trên máy chuẩn STP §2.1 trước khi chốt.",
            ]
        )
    }

    enum BenchError: Error { case failed(String) }

    /// CSV sáu cột, có quoted field chứa dấu phẩy và một field trải hai dòng.
    private static func fixture(rows: Int) -> [UInt8] {
        var out = Array("ma_kh,ho_ten,thanh_pho,ghi_chu,doanh_thu,ngay\n".utf8)
        out.reserveCapacity(rows * 70)
        let names = ["Nguyễn Văn An", "Trần Thị Bình", "Lê Hoàng Cường", "Phạm Thu Dung", "Vũ Minh Đức"]
        let cities = ["Hà Nội", "TP Hồ Chí Minh", "Đà Nẵng", "Huế", "Cần Thơ"]

        for row in 0 ..< rows {
            // Mỗi hàng thứ 97 có field bọc chứa dấu phẩy VÀ xuống dòng — chỗ mà chỉ mục theo
            // dòng vật lý sẽ lệch.
            let note = row % 97 == 0 ? "\"ghi chú có dấu phẩy, và\nxuống dòng\"" : "binh thuong"
            // Tên gắn thêm số thứ tự để cột chữ có MỖI HÀNG MỘT GIÁ TRỊ KHÁC NHAU. Năm cái tên
            // lặp lại một triệu lần sẽ cho phép so sánh gặp toàn chuỗi giống hệt — nhanh giả,
            // và mọi cách nhớ đệm đều ăn gian được trên bộ dữ liệu ấy.
            out.append(contentsOf: Array(
                "KH\(String(format: "%07d", row)),\(names[row % 5]) \(row),\(cities[row % 5]),\(note),\(Double((row * 137) % 900_000) / 2),2026-08-\(String(format: "%02d", row % 28 + 1))\n".utf8
            ))
        }
        return out
    }
}
