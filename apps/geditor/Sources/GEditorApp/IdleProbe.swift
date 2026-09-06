import AppKit
import Darwin
import GEditorCore

/// Đo app lúc NHÀN RỖI — NFR-PERF-07 (năng lượng).
///
/// **Chỉ tiêu của SRS không phải một con số, và phải nói thẳng điều đó.** NFR-PERF-07 viết:
/// *"Mức «Energy Impact: Low» trong Activity Monitor khi idle; không polling nền; dùng
/// FSEvents/Dispatch Source thay vì vòng lặp kiểm tra."* Vế đầu là một CÁI NHÃN do Activity
/// Monitor tính ra bằng công thức Apple không công bố; không có API nào trả về nó. Nên bài này
/// KHÔNG kết luận "đạt NFR-PERF-07" — nó đo hai đại lượng mà cái nhãn ấy được tính từ đó, và
/// nói rõ đấy là số thay thế.
///
/// Hai đại lượng:
///
/// 1. **Thời gian CPU tiêu trong lúc nhàn rỗi.** Một app hướng sự kiện đúng nghĩa thì đứng
///    trong `mach_msg` chờ, và con số này gần bằng không. Bất kỳ vòng lặp kiểm tra nào cũng
///    hiện ra ở đây ngay.
/// 2. **Số lần đánh thức (wakeup).** Đây mới là thứ tốn pin: mỗi lần đánh thức kéo CPU ra khỏi
///    trạng thái ngủ sâu, và mười lần đánh thức rẻ tiền có thể tốn hơn một lần tính toán dài.
///    Một `Timer` lặp mỗi 2 giây không tốn CPU đáng kể nhưng vẫn ghi dấu ở đây.
///
/// **Vì sao đo từ BÊN TRONG.** `powermetrics` cần quyền root, nên nó không chạy được trong CI
/// và không ai chạy nó thường xuyên. `task_info` thì không cần quyền gì và đọc đúng số của
/// chính tiến trình này.
///
/// **Vì sao vòng chờ ở đây là chờ THẬT.** `RunLoop.run(mode:before:)` với hạn xa chặn trong
/// `mach_msg` y như một app đang nằm im trên màn hình — không phải vòng lặp bận trá hình. Nếu
/// viết thành `while Date() < deadline { }` thì bài đo sẽ báo 100% CPU của chính nó.
enum IdleProbe {

    /// `--measure-idle [số-giây]`
    static func run(on controller: MainWindowController, arguments: [String]) -> Never {
        let seconds = Double(intOption("--measure-idle", in: arguments, default: 20))

        // "1 tab văn bản nhỏ" — cùng điều kiện mà NFR-PERF-05 đặt ra cho phép đo RAM nhàn rỗi,
        // để hai con số nói về cùng một trạng thái.
        controller.useTemporaryStoresForSelfTest()
        controller.resetTabsForSelfTest()
        controller.prepareSelfTestDocument("ten,tuoi\nNguyễn An,30\nTrần Bình,25\n")

        // Để app lắng xuống TRƯỚC khi bấm giờ: ngay sau khi dựng cửa sổ còn một loạt việc hoãn
        // (bố cục, vẽ lần đầu, tô màu cú pháp) và tính chúng vào phần "nhàn rỗi" thì con số
        // nói về lúc khởi động chứ không nói về lúc nhàn rỗi.
        let settle = Date().addingTimeInterval(3)
        while Date() < settle {
            autoreleasepool { _ = RunLoop.current.run(mode: .default, before: settle) }
        }

        let before = sample()
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            autoreleasepool { _ = RunLoop.current.run(mode: .default, before: deadline) }
        }
        let elapsed = seconds
        let after = sample()

        report(seconds: elapsed, before: before, after: after)
    }

    // MARK: - Đọc số

    private struct Sample {
        var cpuSeconds: Double
        var wakeups: Int
        var footprintMB: Double
    }

    private static func sample() -> Sample {
        Sample(cpuSeconds: cpuSeconds(), wakeups: wakeups(), footprintMB: footprintMB())
    }

    /// Tổng thời gian CPU (user + system) của cả tiến trình, tính bằng giây.
    ///
    /// Cộng cả `terminated_threads` lẫn các luồng còn sống: bỏ phần luồng đã kết thúc thì một
    /// luồng nền chạy rồi thoát trong lúc đo sẽ biến mất khỏi con số.
    private static func cpuSeconds() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        var total = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
        total += Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6

        // Luồng đang sống chưa được cộng vào `mach_task_basic_info` cho tới khi chúng kết thúc.
        var threads: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threads, &threadCount) == KERN_SUCCESS,
              let list = threads
        else { return total }
        defer {
            for index in 0 ..< Int(threadCount) { mach_port_deallocate(mach_task_self_, list[index]) }
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: list)),
                          vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size))
        }
        for index in 0 ..< Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadCountInfo = mach_msg_type_number_t(
                MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size)
            let ok = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadCountInfo)) {
                    thread_info(list[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadCountInfo)
                }
            }
            guard ok == KERN_SUCCESS, threadInfo.flags & TH_FLAGS_IDLE == 0 else { continue }
            total += Double(threadInfo.user_time.seconds)
                + Double(threadInfo.user_time.microseconds) / 1e6
            total += Double(threadInfo.system_time.seconds)
                + Double(threadInfo.system_time.microseconds) / 1e6
        }
        return total
    }

    /// Số lần tiến trình bị đánh thức khỏi trạng thái ngủ.
    private static func wakeups() -> Int {
        var info = task_power_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_power_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Int(info.task_interrupt_wakeups) + Int(info.task_platform_idle_wakeups)
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &size)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    // MARK: - Báo cáo

    private static func report(seconds: Double, before: Sample, after: Sample) -> Never {
        let cpu = after.cpuSeconds - before.cpuSeconds
        let percent = cpu / seconds * 100
        let wakes = after.wakeups - before.wakeups
        let wakesPerSecond = Double(wakes) / seconds

        // Hai ngưỡng dưới đây là ĐỀ NGHỊ, không phải chỉ tiêu đã chốt — bộ tài liệu không có
        // con số cho NFR-PERF-07, chỉ có cái nhãn của Activity Monitor.
        //
        // 0,5% CPU: dưới mức này thì phần app góp vào Energy Impact nhỏ hơn nhiễu của chính
        // phép đo. 5 lần đánh thức mỗi giây: đủ chỗ cho nhịp tự lưu và vài nguồn sự kiện của
        // AppKit, nhưng chặn được một `Timer` lặp nhanh vừa lọt vào mã.
        //
        // **SỐ ĐÁNH THỨC MỚI LÀ THỨ BẮT ĐƯỢC LỖI, không phải CPU.** Đo bằng đối chứng âm — chèn
        // một vòng hỏi 60 Hz vào app rồi chạy lại:
        //
        //     bình thường   CPU 0,044%   ·   đánh thức  0,45 lần/giây
        //     vòng 60 Hz    CPU 0,477%   ·   đánh thức 60,60 lần/giây
        //
        // Vòng hỏi ấy **lọt dưới trần CPU** (0,477 < 0,5) mà vượt trần đánh thức 12 lần. Một
        // bài đo chỉ canh CPU sẽ xanh trước đúng thứ nó sinh ra để chặn. Đừng bỏ vế đánh thức,
        // và đừng nới trần của nó.
        let cpuBudget = 0.5
        let wakeBudget = 5.0

        var lines: [String] = []
        lines.append("")
        lines.append("  NFR-PERF-07 — app lúc NHÀN RỖI")
        lines.append(String(format: "  đo %.0f giây, 1 tab văn bản nhỏ", seconds))
        lines.append("")
        lines.append(String(format: "  CPU        %.3f giây trong %.0f giây tường (%.3f%%, trần đề nghị %.1f%%)",
                            cpu, seconds, percent, cpuBudget))
        lines.append(String(format: "  Đánh thức  %d lần (%.2f lần/giây, trần đề nghị %.0f)",
                            wakes, wakesPerSecond, wakeBudget))
        lines.append(String(format: "  RAM        %.1f MB → %.1f MB (NFR-PERF-05: trần 80)",
                            before.footprintMB, after.footprintMB))
        lines.append("")

        let overCPU = percent > cpuBudget
        let overWake = wakesPerSecond > wakeBudget
        if overCPU || overWake {
            lines.append("  ❌ VƯỢT NGƯỠNG ĐỀ NGHỊ — "
                + [overCPU ? "CPU" : nil, overWake ? "đánh thức" : nil]
                    .compactMap { $0 }.joined(separator: " và "))
        } else {
            lines.append("  ✅ trong ngưỡng đề nghị — không có vòng lặp kiểm tra nào chạy nền")
        }

        // Nói ra giới hạn NGAY TRONG bản báo cáo, không giấu nó trong tài liệu.
        //
        // Một con số kèm dấu ✅ rất dễ bị đọc thành "đã đạt chỉ tiêu", và ở đây điều đó SAI:
        // chỉ tiêu là một cái nhãn trong Activity Monitor mà chỉ người ngồi trước máy đọc được.
        lines.append("")
        lines.append("  Đây là SỐ THAY THẾ, không phải chỉ tiêu. NFR-PERF-07 đòi nhãn")
        lines.append("  \"Energy Impact: Low\" trong Activity Monitor — không API nào trả về nhãn ấy.")
        lines.append("  Hai vế còn lại của chỉ tiêu (không polling nền · dùng FSEvents/DispatchSource)")
        lines.append("  được chặn bằng cổng trong scripts/check-core-no-ui.sh.")
        lines.append("")
        print(lines.joined(separator: "\n"))
        if !(overCPU || overWake) { Unattended.removeTemporaryRoots() }
        exit(overCPU || overWake ? 1 : 0)
    }

    private static func intOption(_ name: String, in arguments: [String], default fallback: Int) -> Int {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
              let value = Int(arguments[index + 1])
        else { return fallback }
        return value
    }
}
