import Foundation

/// Ghi mẫu độ trễ và tính phân vị (STP: KPI dùng p95, không dùng trung bình).
///
/// Trung bình giấu đúng thứ người dùng cảm thấy: gõ 1.000 phím mà 950 phím 1 ms còn 50 phím
/// 300 ms thì trung bình vẫn "16 ms" trong khi trải nghiệm là giật liên tục. p95 và max mới
/// nói ra điều đó.
struct LatencySampler {
    private(set) var samples: [Double] = []

    mutating func record(_ seconds: Double) { samples.append(seconds * 1_000) }

    /// Đo một lần gõ. Trả về mili giây.
    @discardableResult
    mutating func measure<T>(_ body: () -> T) -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = body()
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        return value
    }

    var count: Int { samples.count }

    func percentile(_ p: Double) -> Double {
        guard !samples.isEmpty else { return .nan }
        let sorted = samples.sorted()
        // Phân vị kiểu "nearest rank": với p95 trên 1.000 mẫu là mẫu thứ 950. Không nội suy —
        // số đo độ trễ không phải phân phối liên tục, và nội suy chỉ làm khó đối chiếu.
        let rank = Int((p / 100 * Double(sorted.count)).rounded(.up))
        return sorted[Swift.min(Swift.max(rank, 1), sorted.count) - 1]
    }

    var p50: Double { percentile(50) }
    var p95: Double { percentile(95) }
    var p99: Double { percentile(99) }
    var max: Double { samples.max() ?? .nan }

    var summary: String {
        guard !samples.isEmpty else { return "chưa có mẫu" }
        return String(
            format: "n=%d  p50=%.2f ms  p95=%.2f ms  p99=%.2f ms  max=%.2f ms",
            count, p50, p95, p99, max
        )
    }
}
