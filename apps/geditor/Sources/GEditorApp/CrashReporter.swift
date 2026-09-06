import AppKit
import Darwin
import GEditorCore

/// Bắt sự cố và để lại một báo cáo NGẮN, chờ người dùng quyết định — NFR-REL-03.
///
/// Chỉ tiêu viết: *"Tỷ lệ phiên không crash ≥ 99,8%; **crash reporter opt-in** gửi kèm ngữ cảnh
/// tối thiểu, **không kèm nội dung tài liệu**"*. Vế tỷ lệ chỉ đo được từ máy người dùng thật,
/// và nó không đo được nếu không có gì ghi lại sự cố — nên phần này là điều kiện của phần kia.
///
/// ## Ba ràng buộc, theo thứ tự quan trọng
///
/// **1. KHÔNG một byte nội dung tài liệu nào vào báo cáo.** Người dùng sản phẩm này mở hợp
/// đồng, bảng lương, dữ liệu dân cư. Báo cáo vì thế chỉ mang: phiên bản, macOS, kiến trúc, tên
/// tín hiệu, và ngăn xếp lời gọi. **Kể cả ĐƯỜNG DẪN tệp cũng không** — `/Users/an/Desktop/
/// luong-thang-12.xlsx` đã nói ra ba điều riêng tư trước khi ai kịp mở nó. Có bài kiểm mở một
/// tài liệu chứa chuỗi bí mật rồi soi báo cáo.
///
/// **2. Người dùng quyết định, không phải sản phẩm.** Báo cáo nằm yên trên đĩa; lần chạy sau
/// app NÓI RA rằng nó có, và người dùng chọn xem, giữ, hay xoá. **Không có đường gửi tự động,
/// và cũng chưa có máy chủ nào để gửi** — nói thẳng điều đó thay vì dựng một nút "Gửi" gọi vào
/// hư không. Xem `pendingNotice`.
///
/// **3. Bộ xử lý tín hiệu chỉ được làm những việc AN TOÀN.** Trong một handler, phần lớn hàm
/// thư viện là cấm — kể cả `malloc`, kể cả `String`. Nên mọi thứ tốn bộ nhớ được dựng SẴN lúc
/// khởi động (`preparedHeader`), và handler chỉ còn `write(2)` cùng `backtrace_symbols_fd`.
/// Dựng chuỗi trong handler là cách chắc chắn để một sự cố biến thành hai.
enum CrashReporter {

    /// Bật hay không. Tắt trong lượt chạy không người: bộ tự kiểm cố ý gây ra lỗi ở vài chỗ, và
    /// một handler bắt tín hiệu sẽ nuốt mất chúng.
    private(set) static var isInstalled = false

    /// Header dựng SẴN lúc khởi động — xem ràng buộc 3.
    private static var preparedHeader: [UInt8] = []
    /// Đường tệp dựng sẵn, dạng C, để handler không phải dựng chuỗi.
    private static var reportPath: [CChar] = []
    /// Nhãn của TỪNG tín hiệu, đã dịch và đã chuyển sang byte lúc khởi động.
    ///
    /// Dựng sẵn cả sáu thay vì ghép chuỗi trong handler, và điều đó giải cùng lúc hai chuyện:
    /// `String(format:)` cùng bộ dịch đều KHÔNG an toàn trong bộ xử lý tín hiệu (chúng cấp phát
    /// bộ nhớ), và một chuỗi dựng lúc khởi động thì dịch được như mọi chuỗi khác.
    private static var signalLabels: [Int32: [UInt8]] = [:]

    private static let signals: [(Int32, String)] = [
        (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"), (SIGILL, "SIGILL"),
        (SIGFPE, "SIGFPE"), (SIGABRT, "SIGABRT"), (SIGTRAP, "SIGTRAP"),
    ]

    // MARK: - Cài đặt

    static func install() {
        guard !isInstalled, !Unattended.isActive else { return }
        prepare()
        NSSetUncaughtExceptionHandler { exception in
            // `NSException` đi qua đường Objective-C, không qua tín hiệu — ở đây còn dựng chuỗi
            // được, và tên với lý do của nó là thứ đáng giá nhất trong cả báo cáo.
            CrashReporter.writeReport(
                reason: "NSException \(exception.name.rawValue)",
                detail: exception.reason ?? "",
                callStack: exception.callStackSymbols)
        }
        for (number, _) in signals {
            signal(number) { received in
                CrashReporter.handle(signal: received)
            }
        }
        isInstalled = true
    }

    /// Dựng sẵn mọi thứ tốn bộ nhớ.
    private static func prepare() {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "dev"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif
        let header = """
            GEditor \(version) (\(build))
            macOS: \(os)
            Kiến trúc: \(arch)
            Báo cáo này KHÔNG chứa nội dung hay đường dẫn tài liệu của bạn.

            """
        preparedHeader = Array(header.utf8)

        for (number, name) in signals {
            signalLabels[number] = Array((LF("Tín hiệu: %@", name) + "\n").utf8)
        }

        let name = "crash-\(Int(Date().timeIntervalSince1970)).txt"
        let path = AppPaths.crashDirectory.appendingPathComponent(name).path
        reportPath = path.utf8CString.map { $0 }
        try? FileManager.default.createDirectory(
            at: AppPaths.crashDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Lúc sự cố

    /// Handler tín hiệu. Chỉ `write(2)` và `backtrace_symbols_fd` — xem ràng buộc 3.
    private static func handle(signal number: Int32) {
        let descriptor = reportPath.withUnsafeBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return open(base, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        }
        if descriptor >= 0 {
            preparedHeader.withUnsafeBufferPointer { _ = write(descriptor, $0.baseAddress, $0.count) }
            // Chỉ TRA BẢNG rồi ghi — không ghép chuỗi, không cấp phát.
            if let label = signalLabels[number] {
                label.withUnsafeBufferPointer {
                    _ = write(descriptor, $0.baseAddress, $0.count)
                }
            }
            var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
            let count = backtrace(&frames, Int32(frames.count))
            backtrace_symbols_fd(&frames, count, descriptor)
            close(descriptor)
        }
        // Trả tín hiệu về hành vi mặc định rồi tự gửi lại: tiến trình phải CHẾT như nó vốn sẽ
        // chết. Nuốt tín hiệu đi thì app sống tiếp trong một trạng thái đã hỏng, và thứ người
        // dùng mất sau đó còn nhiều hơn một lần đóng đột ngột.
        signal(number, SIG_DFL)
        raise(number)
    }

    /// Đường cho `NSException` — ở đây còn dựng chuỗi được.
    static func writeReport(reason: String, detail: String, callStack: [String]) {
        var text = String(decoding: preparedHeader, as: UTF8.self)
        text += LF("Lý do: %@", reason) + "\n"
        if !detail.isEmpty { text += LF("Chi tiết: %@", detail) + "\n" }
        text += "\n" + callStack.joined(separator: "\n") + "\n"
        let path = String(cString: reportPath)
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Lần chạy sau

    /// Những báo cáo đang chờ, mới nhất trước.
    static func pendingReports() -> [URL] {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(
            at: AppPaths.crashDirectory, includingPropertiesForKeys: [.contentModificationDateKey]))
            ?? []
        return files
            .filter { $0.pathExtension == "txt" }
            .sorted { left, right in
                let a = (try? left.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let b = (try? right.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return a > b
            }
    }

    /// Câu nói với người dùng ở lần chạy sau. `nil` = không có gì để nói.
    ///
    /// Nói ra CẢ điều sản phẩm KHÔNG làm: không có đường gửi tự động. Một nút "Gửi" chỉ chép
    /// tệp đi đâu đó mà người dùng không biết là chỗ nào thì tệ hơn không có nút nào.
    static func pendingNotice() -> String? {
        let reports = pendingReports()
        guard let latest = reports.first else { return nil }
        let when = (try? latest.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        let time = when.map { formatter.string(from: $0) } ?? ""
        if reports.count > 1 {
            // Một chuỗi LIỀN, không ghép hai mảnh: bộ dò nợ dịch soi từng chuỗi trong mã, nên
            // `"…" + "…"` là hai chuỗi và mảnh đầu sẽ mãi mãi nằm trong danh sách chưa dịch.
            return LF("""
                GEditor đã đóng đột ngột %d lần. Báo cáo gần nhất: %@ — mở để xem, \
                không có gì được gửi đi.
                """, reports.count, time)
        }
        return LF("GEditor đã đóng đột ngột lúc %@ — mở báo cáo để xem, không có gì được gửi đi.",
                  time)
    }

    /// Người dùng chọn xoá: bỏ hết.
    static func discardReports() {
        for url in pendingReports() { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Chứng minh đường TÍN HIỆU chạy thật

    /// `--crash-signal <tên>` — tự gây ra một sự cố để chứng minh handler ghi được báo cáo.
    ///
    /// **Vì sao phải có cờ này.** Bài tự kiểm chỉ đi được đường `NSException`; đường TÍN HIỆU —
    /// đường mà một sự cố thật đi qua — thì không, vì nó giết tiến trình. Không có cờ này thì
    /// phần quan trọng nhất của `CrashReporter` là một hàng rào chỉ có trên giấy: nó biên dịch
    /// được, trông đúng, và chưa ai từng thấy nó ghi ra một byte nào.
    ///
    /// Cờ này KHÔNG đổi hành vi sản phẩm: nó chỉ tồn tại như một lối vào, và `scripts/
    /// check-crash-reporter.sh` là chỗ duy nhất gọi nó. App thật không bao giờ đi qua đây.
    static func runCrashSignalProbeIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--crash-signal") else { return }
        let name = index + 1 < arguments.count ? arguments[index + 1] : "SIGSEGV"
        // Thư mục báo cáo phải nằm ở chỗ script chỉ định, không ở Application Support thật của
        // người đang chạy máy.
        if let root = arguments.firstIndex(of: "--crash-root"), root + 1 < arguments.count {
            AppPaths.applicationSupportOverride = URL(
                fileURLWithPath: arguments[root + 1], isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: AppPaths.crashDirectory, withIntermediateDirectories: true)
        install()
        guard isInstalled else {
            FileHandle.standardError.write(Data("crash-signal: handler chưa cài\n".utf8))
            exit(2)
        }
        let number = signals.first { $0.1 == name }?.0 ?? SIGSEGV
        raise(number)
        // Tới được đây nghĩa là handler đã NUỐT tín hiệu — chính là điều nó không được làm.
        FileHandle.standardError.write(Data("crash-signal: tiến trình sống sót\n".utf8))
        exit(3)
    }

    // MARK: - Cửa cho bài tự kiểm

    /// Dựng một báo cáo NHƯ THẬT mà không cần làm sập tiến trình.
    ///
    /// Đi qua đúng `writeReport` mà `NSException` đi, nên bài kiểm soi được đúng thứ người dùng
    /// sẽ đọc — kể cả phần header dựng sẵn.
    static func writeReportForSelfTest(reason: String) -> URL? {
        if preparedHeader.isEmpty { prepare() }
        writeReport(reason: reason, detail: "self-test",
                    callStack: Thread.callStackSymbols)
        return pendingReports().first
    }
}
