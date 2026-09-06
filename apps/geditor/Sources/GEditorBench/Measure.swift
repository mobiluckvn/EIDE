import Foundation

/// Đo thời gian và bộ nhớ dùng chung cho mọi bộ benchmark.
enum Measure {

    static func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now()
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    static func median(_ values: [Double]) -> Double {
        percentile(values, 0.5)
    }

    /// Phân vị theo phương pháp "nearest rank" trên mẫu đã sắp xếp.
    ///
    /// STP §4.1 yêu cầu p95 cho latency: trung bình che mất đúng phần đuôi mà người dùng cảm
    /// nhận được (một lần khựng 200 ms không biến mất khi chia cho 10 000 lần gõ mượt).
    static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[index]
    }

    /// Lặp `iterations` lần, lấy trung vị (quy trình chuẩn STP §4.1).
    static func repeated(_ iterations: Int, _ body: () -> Void) -> Double {
        median((0 ..< iterations).map { _ in milliseconds(body) })
    }
}

/// Số đo bộ nhớ của tiến trình.
///
/// Báo cáo HAI con số vì chúng trả lời hai câu hỏi khác nhau trên file mmap:
///  - `resident`: tổng trang vật lý đang gắn với tiến trình, GỒM trang file-backed sạch do
///    mmap nạp vào khi quét. Quét chỉ mục 1 GB chạm mọi trang nên số này phình lên gần bằng
///    kích thước file — nhưng đó là trang sạch, kernel thu hồi được bất cứ lúc nào.
///  - `footprint`: `phys_footprint` của macOS — thứ Activity Monitor gọi là "Memory" và là
///    thứ NFR-PERF-05 (RAM nhàn rỗi ≤ 80 MB) thực sự nói tới. Trang file-backed sạch KHÔNG
///    tính vào đây, nên nó phản ánh đúng phần RAM mà GEditor chiếm giữ.
///
/// Nhầm hai con số này là cách dễ nhất để kết luận sai rằng piece table trên mmap "ngốn RAM
/// bằng kích thước file".
enum ProcessMemory {

    static func residentBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    static func footprintBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    static func snapshot() -> (residentMB: Double, footprintMB: Double) {
        (Double(residentBytes()) / 1_048_576, Double(footprintBytes()) / 1_048_576)
    }
}

/// Sinh số giả ngẫu nhiên TẤT ĐỊNH — benchmark phải tái lập được giữa các lần chạy và
/// giữa hai kiến trúc, nên không dùng nguồn ngẫu nhiên hệ thống.
struct DeterministicRNG {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func int(_ upperBound: Int) -> Int {
        upperBound <= 0 ? 0 : Int(next() % UInt64(upperBound))
    }
}
