import AppKit
import Darwin
import GEditorCore

/// Đo khởi động nguội và RAM nhàn rỗi của CHÍNH ứng dụng (NFR-PERF-01, NFR-PERF-05).
///
/// Hai chỉ tiêu này là P0 — bắt buộc cho bản phát hành đầu — nhưng chúng chỉ đo được TỪ BÊN
/// TRONG app đang chạy, nên bộ benchmark ngoài (`geditor-bench`) không với tới. Trước phép đo
/// này, cả hai chưa từng có một con số nào.
///
/// Chúng cũng là MỐC cho mọi quyết định thêm thư viện về sau: SAD đã chốt DuckDB là "optional
/// component tải khi bật tính năng SQL" và NFR-KNW-01 đòi zero-cost khi tắt (sai lệch ≤ 1%).
/// Không có mốc thì câu "zero-cost" không kiểm chứng được.
enum StartupProbe {

    /// Mili-giây từ lúc tiến trình bắt đầu tới lúc `main()` chạy dòng đầu tiên.
    ///
    /// Đây là phần của dyld: nạp và liên kết mọi framework, dựng Swift runtime. Mã của ta chưa
    /// chạy dòng nào. Nếu con số này chiếm phần lớn thời gian khởi động thì tối ưu bên trong
    /// `applicationDidFinishLaunching` là tối ưu nhầm chỗ.
    private(set) static var preMainMs: Double = -1

    static func markMainEntered() {
        preMainMs = millisecondsSinceLaunch() ?? -1
    }

    /// Những tầng giao diện đã dựng tại đúng lúc cửa sổ hiện ra (ADR-08 §2.10).
    ///
    /// Chụp lại NGAY tại thời điểm ấy chứ không hỏi lúc chạy bài kiểm: tới lúc bài kiểm chạy
    /// thì chính các bài khác đã mở panel này panel kia, và câu trả lời không còn nói gì về
    /// khởi động nữa.
    static var layersAtLaunch: [String] = []

    /// Dylib bảng tra grammar đã nạp chưa, tại đúng lúc cửa sổ hiện ra (ADR-08 §2.13).
    ///
    /// Cùng lý do với `layersAtLaunch`, và từ 24/08/2026 thì lý do ấy thành bắt buộc: trước
    /// đây chỉ C++/C#/Ruby đi qua dylib nên hỏi `GrammarLibrary.isLoaded` giữa chừng vẫn còn
    /// nghĩa, miễn là bài kiểm đứng trước mọi bài dùng ba ngôn ngữ ấy. Giờ CẢ HAI MƯƠI ngôn
    /// ngữ đều qua dylib, nên bất kỳ bài nào mở một file có tô màu cũng nạp nó — và một bài
    /// kiểm phụ thuộc thứ tự chạy là một bài kiểm sẽ đỏ vì lý do không liên quan.
    static var grammarLibraryLoadedAtLaunch = false

    /// Các mốc trong lúc app tự dựng, để biết thời gian tiêu vào đâu.
    private(set) static var marks: [(String, Double)] = []

    static func mark(_ name: String) {
        marks.append((name, millisecondsSinceLaunch() ?? -1))
    }

    /// Thời điểm tiến trình bắt đầu, lấy từ kernel.
    ///
    /// Phải hỏi kernel chứ không thể đo từ `main()`: phần lớn thời gian khởi động của một app
    /// macOS nằm TRƯỚC `main()` — dyld nạp và liên kết framework. Đo từ `main()` sẽ cho một
    /// con số đẹp mà người dùng không bao giờ cảm nhận được.
    static func processStartTime() -> timeval? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return nil }
        return info.kp_proc.p_starttime
    }

    /// Mili-giây kể từ lúc tiến trình bắt đầu.
    static func millisecondsSinceLaunch() -> Double? {
        guard let start = processStartTime() else { return nil }
        var now = timeval()
        gettimeofday(&now, nil)
        let seconds = Double(now.tv_sec - start.tv_sec)
        let micro = Double(now.tv_usec) - Double(start.tv_usec)
        return seconds * 1000 + micro / 1000
    }

    /// `phys_footprint` — thứ Activity Monitor gọi là "Memory", và là thứ NFR-PERF-05 nói tới.
    ///
    /// Không dùng `resident`: nó gồm cả trang file-backed sạch do mmap nạp vào, nên với một
    /// trình soạn thảo đọc file bằng mmap thì con số ấy phình lên gần bằng kích thước file và
    /// kết luận sai rằng app "ngốn RAM bằng cả file".
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    /// Đo rồi in JSON ra stdout và thoát.
    ///
    /// Gọi khi cửa sổ đã dựng xong và SẴN SÀNG NHẬN GÕ — đúng mốc mà NFR-PERF-01 định nghĩa
    /// ("đo tới khi cửa sổ nhận thao tác gõ"), chứ không phải lúc `applicationDidFinishLaunching`
    /// trả về.
    static func reportAndExit(controller: MainWindowController) -> Never {
        let startup = millisecondsSinceLaunch() ?? -1

        // Chờ một nhịp cho các việc lười (chỉ mục, tô màu nhịp đầu) lắng xuống rồi mới đo RAM:
        // đo ngay khi cửa sổ vừa hiện sẽ bỏ sót phần bộ nhớ mà app chiếm trong lúc idle thật.
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let footprint = footprintMB()
        let tabs = controller.tabPathsForSelfTest.count

        // Bất biến ADR-14: khởi động không được nạp hệ thống con NẶNG nào.
        //
        // Đây là vế thứ BA của phép đo khởi động, và nó là vế duy nhất không tự hỏng theo thời
        // gian: 465 ms hôm nay có thể thành 470 vì máy, nhưng "libduckdb đã nạp" thì hoặc đúng
        // hoặc sai. Một ngày nào đó ai đó thêm `import` vào đường khởi động và con số ms sẽ
        // trôi dần trong nhiễu tới lúc quá trần; dòng này bắt được ngay lần chạy đầu.
        let lazyPass = LazyLoadAudit.passesAtLaunch
        let violationJSON = (LazyLoadAudit.bundledLoadedAtLaunch.map(\.name)
            + LazyLoadAudit.activatedAtLaunch.sorted())
            .map { "\"\($0)\"" }
            .joined(separator: ", ")

        let json = """
        {
          "startupMs": \(String(format: "%.1f", startup)),
          "preMainMs": \(String(format: "%.1f", preMainMs)),
          "appLaunchMs": \(String(format: "%.1f", startup - preMainMs)),
          "startupBudgetMs": 500,
          "startupPass": \(startup >= 0 && startup <= 500),
          "idleFootprintMB": \(String(format: "%.1f", footprint)),
          "idleBudgetMB": 80,
          "memoryPass": \(footprint <= 80),
          "heavyLoadedAtLaunch": [\(violationJSON)],
          "lazyLoadPass": \(lazyPass),
          "imagesAtLaunch": \(LazyLoadAudit.imagesAtLaunch.count),
          "tabs": \(tabs),
          "marks": [\(marks.map { "{\"\($0.0)\": \(String(format: "%.1f", $0.1))}" }.joined(separator: ", "))]
        }
        """
        print(json)
        if !lazyPass {
            FileHandle.standardError.write(Data((LazyLoadAudit.failureMessage() + "\n").utf8))
        }
        exit((startup >= 0 && startup <= 500 && footprint <= 80 && lazyPass) ? 0 : 1)
    }
}
