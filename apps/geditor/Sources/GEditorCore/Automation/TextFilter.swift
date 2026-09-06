import Foundation

/// Đưa văn bản qua một lệnh ngoài rồi lấy kết quả về (FR-AUTO-604).
///
/// `sort`, `jq .`, `python3 -c …` — cả một hệ sinh thái công cụ dòng lệnh có sẵn, và một trình
/// soạn thảo cho người làm dữ liệu thì không nên bắt họ chép ra terminal rồi chép ngược lại.
///
/// **CHỈ CÓ Ở BẢN TẢI TRỰC TIẾP.** App Sandbox không cho tạo tiến trình con tuỳ ý, nên bản App
/// Store không có tính năng này — và đó là điều phải NÓI RA ở giao diện chứ không phải để nó
/// im lặng không làm gì. Xem `Distribution.supportsTextFilter`.
///
/// **Ba hàng rào, vì đây là chỗ chạy mã tuỳ ý:**
///
/// 1. **Hạn giờ.** Một lệnh treo — `cat` không có đầu vào, `ssh` chờ mật khẩu — sẽ treo cả
///    ứng dụng nếu chỉ đứng đợi.
/// 2. **Trần cỡ đầu ra.** `yes` sinh vô hạn; đọc hết là hết RAM.
/// 3. **Không qua shell.** Chạy thẳng `execve` với mảng đối số, không `sh -c`: chuỗi người dùng
///    gõ không được diễn giải thành cú pháp shell, nên một dấu `;` trong đối số là dấu chấm phẩy
///    chứ không phải chỗ bắt đầu lệnh thứ hai.
///
/// **Không sửa tài liệu.** Hàm này trả về chuỗi; chỗ gọi quyết định làm gì với nó.
public enum TextFilter {

    public static let defaultTimeout: TimeInterval = 10
    public static let outputLimit = 64 << 20

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case emptyCommand
        case notFound(String)
        case timedOut(TimeInterval)
        case outputTooLarge(limit: Int)
        case failed(status: Int32, stderr: String)

        public var description: String {
            switch self {
            case .emptyCommand: return "Chưa nhập lệnh"
            case .notFound(let name): return "Không tìm thấy lệnh «\(name)»"
            case .timedOut(let seconds):
                return String(format: "Lệnh chạy quá %.0f giây và đã bị dừng", seconds)
            case .outputTooLarge(let limit):
                return "Kết quả vượt \(limit / (1 << 20)) MB và đã bị dừng"
            case .failed(let status, let stderr):
                let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return detail.isEmpty
                    ? "Lệnh kết thúc với mã \(status)"
                    : "Lệnh kết thúc với mã \(status): \(detail)"
            }
        }
    }

    /// Tách dòng lệnh thành chương trình + đối số.
    ///
    /// Hiểu dấu nháy đơn và nháy kép để `jq '.a | .b'` là MỘT đối số. Không hiểu biến môi
    /// trường, ống dẫn hay chuyển hướng — những thứ ấy cần một shell, và mời shell vào là mời
    /// cả một lớp lỗi tiêm lệnh vào theo.
    public static func tokenize(_ command: String) -> [String] {
        var out: [String] = []
        var current = ""
        var quote: Character?
        var hasCurrent = false

        for character in command {
            if let active = quote {
                if character == active { quote = nil } else { current.append(character) }
                continue
            }
            switch character {
            case "'", "\"":
                quote = character
                hasCurrent = true            // `''` là một đối số RỖNG, không phải không có gì
            case " ", "\t":
                if hasCurrent { out.append(current); current = ""; hasCurrent = false }
            default:
                current.append(character)
                hasCurrent = true
            }
        }
        if hasCurrent { out.append(current) }
        return out
    }

    /// Chạy `command`, đưa `input` vào stdin, trả về stdout.
    public static func run(
        command: String,
        input: String,
        timeout: TimeInterval = defaultTimeout,
        outputLimit: Int = outputLimit
    ) throws -> String {
        let parts = tokenize(command)
        guard let program = parts.first, !program.isEmpty else { throw Failure.emptyCommand }

        let process = Process()
        // `/usr/bin/env` để tìm lệnh theo PATH mà vẫn KHÔNG qua shell: `env sort` chạy `sort`
        // như một chương trình, còn `sh -c "sort"` thì diễn giải cả chuỗi theo cú pháp shell.
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = parts

        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        do { try process.run() } catch { throw Failure.notFound(program) }

        // Đọc stdout ở LUỒNG KHÁC trong lúc ghi stdin.
        //
        // Không làm thế thì bế tắc, và đây là loại bế tắc chỉ lộ ra với dữ liệu lớn: ống dẫn có
        // bộ đệm khoảng 64 KB, nên với đầu vào nhỏ mọi thứ chạy tốt. Đầu vào lớn hơn bộ đệm thì
        // ta chặn ở lệnh ghi stdin, trong khi tiến trình con chặn ở lệnh ghi stdout mà không ai
        // đọc — cả hai đứng yên vĩnh viễn.
        var output = Data()
        var truncated = false
        let reader = Thread {
            while true {
                let chunk = outPipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                if output.count + chunk.count > outputLimit {
                    truncated = true
                    process.terminate()
                    break
                }
                output.append(chunk)
            }
        }
        reader.start()

        inPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inPipe.fileHandleForWriting.close()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            usleep(2000)
        }
        if process.isRunning {
            process.terminate()
            // Cho nó một nhịp để chết tử tế, rồi mới giết hẳn — `terminate` gửi SIGTERM và
            // chương trình biết điều sẽ tự dọn.
            usleep(50_000)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            throw Failure.timedOut(timeout)
        }
        process.waitUntilExit()
        while !reader.isFinished { usleep(1000) }

        if truncated { throw Failure.outputTooLarge(limit: outputLimit) }

        guard process.terminationStatus == 0 else {
            let stderr = String(
                decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self
            )
            throw Failure.failed(status: process.terminationStatus, stderr: stderr)
        }
        return String(decoding: output, as: UTF8.self)
    }
}
