import Foundation
import GEditorCore

/// Nói chuyện với plugin native qua tiến trình phụ — FR-PLUG-702 · FR-PLUG-703 (ADR-12).
///
/// Một `NativePluginBridge` = MỘT plugin = một tiến trình `geditor-plugin-host` sống lâu. Tiến
/// trình ấy sinh ra ở lần dùng đầu tiên và sống tới khi bị đóng, vì đó là hình dạng PoC-H đã đo
/// (0,010 ms mỗi lần gọi); khởi động lại ở mỗi lần gọi thì cái giá không còn là mười micro-giây.
///
/// ## Ba thứ có thể hỏng, và cả ba đều phải KHÔNG làm treo app
///
/// Plugin là mã của người khác. Nó có quyền hỏng theo mọi cách, và mỗi cách cần một câu trả lời:
///
/// 1. **Nó chạy mãi không trả lời.** Có hạn giờ; quá hạn thì giết tiến trình và nói ra. Đây là
///    khác biệt lớn nhất so với `ScriptRunner`: script JavaScript chạy CÙNG tiến trình nên
///    không ngắt được, và bài học ấy ghi thẳng trong `ScriptRunner` là "luồng kia vẫn quay cho
///    tới khi thoát app". Ở đây plugin nằm ở tiến trình khác, nên `terminate()` là dứt điểm.
/// 2. **Nó chết giữa chừng.** Ống đóng, phép đọc trả về rỗng — phân biệt được với "chưa tới".
/// 3. **Nó trả rác.** Khung thông điệp bắt lỗi, và câu trả lời là một `failure` nói rõ.
///
/// ## Vì sao gọi ĐỒNG BỘ ở đây
///
/// Chỗ gọi (menu, ScriptRunner) đã chạy nền sẵn, và một plugin đúng nghĩa trả lời trong vài
/// mili-giây. Thêm một tầng bất đồng bộ nữa chỉ để chờ mười micro-giây là thêm một tầng trạng
/// thái phải đúng. Hạn giờ ở dưới là thứ giữ cho "đồng bộ" không thành "treo".
final class NativePluginBridge {

    /// Hạn chờ MỘT lời gọi, tính bằng giây.
    ///
    /// 5 giây, cùng con số với `ScriptRunner.timeout` — cùng loại câu hỏi ("người dùng đợi bao
    /// lâu trước khi nghĩ là treo"), nên cùng câu trả lời.
    ///
    /// ## Nới gấp bốn khi chạy dưới thiết bị đo độ phủ
    ///
    /// Đây là lời giải cho một bài tự kiểm chập chờn đã theo dự án nhiều ngày: *"plugin native:
    /// khai tên và biến đổi văn bản"* thỉnh thoảng trượt với *"Plugin không trả lời kịp (5s)"*,
    /// nhưng CHỈ dưới `run-app-coverage.sh`, và chỉ khoảng một lần trong hơn chục lượt. Nhật ký
    /// lỗi được giữ lại (thêm vào từ trước cho đúng mục đích này) là thứ chỉ ra thủ phạm.
    ///
    /// Nguyên nhân không nằm ở sản phẩm: bản dựng có thiết bị đo ghi một bộ đếm cho mỗi nhánh
    /// mã, nên khởi động một TIẾN TRÌNH plugin riêng — nạp dylib, bắt tay JSON, trả lời — mất
    /// gấp nhiều lần bình thường. Máy đang bận thì nó vượt 5 giây.
    ///
    /// Hai cách sửa sai: nới hạn cho MỌI người (bán đi trải nghiệm thật để bài kiểm xanh), hoặc
    /// bỏ qua bài kiểm ấy khi đo độ phủ (mất luôn phần đang kiểm). Cách ở đây giữ nguyên 5 giây
    /// cho người dùng và chỉ nới cho chính bản dựng bị làm chậm — nhận ra qua `LLVM_PROFILE_FILE`,
    /// biến môi trường mà thiết bị đo bắt buộc phải có.
    static var timeout: TimeInterval {
        ProcessInfo.processInfo.environment["LLVM_PROFILE_FILE"] != nil ? 15 : 5
    }

    let url: URL
    private var process: Process?
    private var toHost: FileHandle?
    private var fromHost: FileHandle?
    private var buffer = Data()

    /// Lỗi ở đây đều là thứ SẼ hiện ra cho người dùng, nên câu chữ phải nói được phải làm gì.
    enum Failure: Error, LocalizedError, Equatable {
        case notAvailable
        case hostMissing
        case cannotStart(String)
        case died
        case timedOut
        case protocolBroken(String)
        /// Chính plugin tự báo hỏng — câu chữ là LỜI CỦA PLUGIN, không phải của GEditor.
        case plugin(String)

        var errorDescription: String? {
            switch self {
            // Câu chữ tách khỏi phần NỘI SUY rồi mới bọc `L()`: một chuỗi có `\(…)` bên
            // trong không thể làm khoá dịch, vì khoá phải giống hệt nhau ở mọi lần chạy.
            case .notAvailable:
                return L("Plugin native chỉ có ở bản tải trực tiếp, không có ở bản App Store.")
            case .hostMissing:
                return L("Không tìm thấy tiến trình phụ chạy plugin.")
            case let .cannotStart(reason):
                return L("Không khởi động được tiến trình phụ:") + " \(reason)"
            case .died:
                return L("Tiến trình plugin đã dừng giữa chừng.")
            case .timedOut:
                return L("Plugin không trả lời kịp — đã dừng nó.")
                    + " (\(Int(NativePluginBridge.timeout))s)"
            case let .protocolBroken(detail):
                return L("Plugin trả lời sai giao thức:") + " \(detail)"
            case let .plugin(message):
                return L("Plugin báo lỗi:") + " \(message)"
            }
        }
    }

    init(url: URL) { self.url = url }

    deinit { close() }

    // MARK: - Tìm tiến trình phụ

    /// Tên sản phẩm; cùng tên ở mọi kênh.
    static let hostName = "geditor-plugin-host"

    /// Những chỗ tiến trình phụ có thể nằm, theo thứ tự.
    ///
    /// Cùng luật với `GrammarLibrary.candidatePaths()`, và cùng lý do đã trả giá một lần: hỏi
    /// `Bundle`, KHÔNG suy từ `CommandLine.arguments[0]`. argv[0] là đường TƯƠNG ĐỐI theo chỗ
    /// gọi, mà thư mục hiện hành của app sandbox nằm trong container — nên nó ghép ra một đường
    /// không tồn tại, và triệu chứng là tính năng im lặng biến mất CHỈ ở bản phát hành.
    static func hostCandidates() -> [String] {
        var paths: [String] = []
        if let helpers = Bundle.main.sharedSupportURL {
            paths.append(helpers.appendingPathComponent(hostName).path)
        }
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            paths.append(executable.appendingPathComponent(hostName).path)
        }
        let fromArgv = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        paths.append(fromArgv.appendingPathComponent(hostName).path)
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    static func hostPath() -> String? {
        hostCandidates().first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Vòng đời

    private func start() throws {
        guard Distribution.current == .direct else { throw Failure.notAvailable }
        if process?.isRunning == true { return }

        guard let host = Self.hostPath() else { throw Failure.hostMissing }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: host)
        task.arguments = [url.path]
        let input = Pipe(), output = Pipe()
        task.standardInput = input
        task.standardOutput = output
        // stderr của tiến trình phụ đi thẳng ra stderr của app: đó là chỗ dyld in lý do từ chối
        // nạp dylib, và nuốt nó đi thì triệu chứng chỉ còn là "plugin không chạy".
        task.standardError = FileHandle.standardError

        do { try task.run() } catch { throw Failure.cannotStart(error.localizedDescription) }

        process = task
        toHost = input.fileHandleForWriting
        fromHost = output.fileHandleForReading
        buffer.removeAll()
    }

    func close() {
        try? toHost?.close()
        // Đóng ống là cách kết thúc bình thường; `terminate` chỉ dùng khi nó không chịu đi.
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        toHost = nil
        fromHost = nil
    }

    // MARK: - Gọi

    func describe() throws -> NativePluginManifest {
        switch try send(.describe) {
        case let .manifest(manifest):
            if let reason = manifest.incompatibilityReason() { throw Failure.plugin(reason) }
            return manifest
        case let .failure(message): throw Failure.plugin(message)
        case .replacement: throw Failure.protocolBroken("describe -> replacement")
        }
    }

    /// Chạy một lệnh. Trả `nil` khi plugin cố ý không đổi gì.
    func run(command: String, text: String, selection: Range<Int>?) throws -> String? {
        switch try send(.run(command: command, text: text, selection: selection)) {
        case let .replacement(replacement): return replacement
        case let .failure(message): throw Failure.plugin(message)
        case .manifest: throw Failure.protocolBroken("run -> manifest")
        }
    }

    private func send(_ request: NativePluginRequest) throws -> NativePluginResponse {
        try start()
        guard let toHost, let fromHost else { throw Failure.died }

        do {
            try toHost.write(contentsOf: try NativePluginWire.encode(request))
        } catch {
            close()
            throw Failure.died
        }
        return try readResponse(from: fromHost)
    }

    /// Đọc tới khi đủ MỘT thông điệp, hoặc hết hạn.
    ///
    /// **Hạn giờ ở đây không phải chuyện lịch sự.** Đầu kia là mã của người khác; một vòng lặp
    /// vô hạn trong plugin sẽ giữ luồng này mãi mãi nếu không có hạn. Quá hạn thì GIẾT tiến
    /// trình chứ không chỉ bỏ chờ: bỏ chờ mà để nó sống thì lần gọi sau đọc phải câu trả lời
    /// của lần gọi trước, và hai lời gọi lệch pha nhau là kiểu lỗi khó nhất để lần ra.
    private func readResponse(from handle: FileHandle) throws -> NativePluginResponse {
        let deadline = Date().addingTimeInterval(Self.timeout)
        while true {
            do {
                if let decoded = try NativePluginWire.decode(
                    NativePluginResponse.self, from: buffer
                ) {
                    buffer.removeFirst(decoded.consumed)
                    return decoded.value
                }
            } catch {
                close()
                throw Failure.protocolBroken(String(describing: error))
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                close()
                throw Failure.timedOut
            }

            // `poll` chứ KHÔNG phải `availableData`.
            //
            // Bản đầu của hàm này dùng `FileHandle.availableData`, và nó có hạn giờ trên giấy
            // mà không có trên thực tế: `availableData` CHẶN cho tới khi có byte, nên với một
            // plugin lặp vô hạn thì luồng này đứng mãi và dòng kiểm hạn ở trên không bao giờ
            // chạy tới. Đúng loại "hàng rào có mà như không" — nguy hiểm hơn không có hàng rào,
            // vì đọc mã thì thấy yên tâm.
            //
            // `poll` chờ CÓ HẠN rồi trả về, nên hạn giờ là hạn thật.
            var fd = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&fd, 1, Int32(Swift.min(remaining, 0.25) * 1000))
            if ready < 0 && errno != EINTR {
                close()
                throw Failure.died
            }
            guard ready > 0 else { continue }        // chưa có gì — quay lại kiểm hạn

            var chunk = [UInt8](repeating: 0, count: 64 << 10)
            let count = read(handle.fileDescriptor, &chunk, chunk.count)
            if count == 0 {                          // đầu kia đóng ống
                close()
                throw Failure.died
            }
            if count < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                close()
                throw Failure.died
            }
            buffer.append(contentsOf: chunk[0 ..< count])
        }
    }
}
