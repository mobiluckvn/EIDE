import Foundation
import GEditorCore

/// NFR-QRY-02 — *"Render biểu đồ từ 1 triệu điểm ≤ 2 giây nhờ downsample tự động"* (FR-QRY-004).
///
/// Đo bản RELEASE. Cùng phép đo chạy dưới `swift test` (bản debug) cho 1.671 ms cho riêng phép
/// chia khoảng — sát trần 2 giây trước khi vẽ một điểm ảnh nào. Con số ấy không sai, nó chỉ đo
/// một thứ ta không giao: Swift không tối ưu chậm hơn hẳn ở vòng lặp mảng.
enum ChartKPI {
    struct Report: Encodable {
        let kpi: String
        let architecture: String
        let points: Int
        let downsampleMs: Double
        let histogramMs: Double
        let boxMs: Double
        let budgetMs: Double
        let pass: Bool
        let sampledTo: Int
        let notes: [String]
    }

    static func run(points count: Int) -> Report {
        // Sinh TẤT ĐỊNH: cùng bộ đo chạy lại phải cho cùng con số, nếu không thì so hai lần
        // chạy là so hai bộ dữ liệu khác nhau.
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed >> 11) / Double(1 << 53)
        }
        let points = (0 ..< count).map {
            ChartData.Point(x: Double($0), y: sin(Double($0) / 5_000) * 100 + next() * 10)
        }
        let values = points.map(\.y)

        let t0 = DispatchTime.now().uptimeNanoseconds
        let series = ChartData.series(name: "kpi", points: points)
        let downsample = ms(since: t0)

        let t1 = DispatchTime.now().uptimeNanoseconds
        _ = ChartData.histogram(values)
        let histogram = ms(since: t1)

        let t2 = DispatchTime.now().uptimeNanoseconds
        _ = ChartData.box(values)
        let box = ms(since: t2)

        let worst = max(downsample, max(histogram, box))
        return Report(
            kpi: "NFR-QRY-02 — biểu đồ 1 triệu điểm ≤ 2 s",
            architecture: architectureName(),
            points: count,
            downsampleMs: downsample, histogramMs: histogram, boxMs: box,
            budgetMs: 2_000, pass: worst <= 2_000,
            sampledTo: series.points.count,
            notes: [
                "Ba phép đo là ba loại biểu đồ khác nhau, không phải ba lần cùng một phép:"
                    + " đường/phân tán đi qua LTTB, phân bố đi qua chia khoảng, hộp đi qua phân"
                    + " vị. Mốc 2 giây áp cho phép CHẬM NHẤT.",
                "Phần VẼ không nằm trong con số này — nó đo phần TÍNH ở lõi. Phần vẽ nhận tối đa"
                    + " \(ChartData.maximumPoints) điểm nên chi phí của nó không phụ thuộc cỡ"
                    + " dữ liệu.",
            ])
    }

    private static func ms(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    private static func architectureName() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
