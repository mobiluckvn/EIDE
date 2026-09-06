import Foundation

/// Đọc bộ nhớ tiến trình đang dùng.
enum MemoryProbe {

    /// `phys_footprint`, KHÔNG phải `resident_size`.
    ///
    /// Với thiết kế mmap của GEditor, `resident_size` đếm cả trang sạch của file ánh xạ — tức
    /// là đếm cả những trang mà hệ điều hành có thể thu hồi bất cứ lúc nào mà không mất gì.
    /// Dùng nó sẽ báo "1 GB RAM" cho một file chỉ đọc mà thực tế không tốn RAM nào của ứng
    /// dụng. `phys_footprint` là con số Activity Monitor hiện, và là con số NFR-PERF nói tới.
    static func footprintBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    static func format(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
