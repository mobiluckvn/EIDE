import Foundation

/// Cầu nối giữa lệnh `geditor` và ứng dụng đang chạy (SAD §2.4 CLIBridge, FR-AUTO-605).
///
/// Dùng **Unix domain socket**, không phải XPC. SAD cho phép cả hai, và socket thắng ở đây vì
/// XPC service phải là một bundle riêng nằm trong `.app` — SwiftPM không dựng được loại bundle
/// đó, nên sẽ phải lắp tay trong `build-universal.sh` và ai cũng có thể quên. Socket chỉ là
/// một file trong thư mục dữ liệu của ứng dụng, và cùng một mã chạy được ở cả hai đầu.
///
/// Giao thức: **một dòng JSON mỗi thông điệp**. Không dùng độ dài nhị phân vì `nc` và `python`
/// phải soi được nó khi gỡ lỗi — đây là chỗ mà "xem được bằng mắt" đáng giá hơn vài byte.
public enum CLIBridge {

    /// Yêu cầu mở file, do `geditor` gửi tới ứng dụng.
    public struct OpenRequest: Codable, Equatable {
        public struct Target: Codable, Equatable {
            public var path: String
            public var line: Int?
            public var column: Int?

            public init(path: String, line: Int? = nil, column: Int? = nil) {
                self.path = path
                self.line = line
                self.column = column
            }
        }

        public var targets: [Target]
        /// File tạm chứa nội dung từ ống dẫn (`ps aux | geditor`), mở thành tab chưa có tên.
        ///
        /// Đi qua FILE chứ không nhét vào JSON: `dd | geditor` cả GB thì nội dung không được
        /// nằm trong RAM của cả hai tiến trình, mà phải là thứ mmap được — cùng một đường mà
        /// Large File Mode dùng.
        public var stdinPath: String?
        public var readOnly: Bool
        public var newWindow: Bool
        /// Giữ kết nối tới khi tài liệu được đóng — `EDITOR=geditor -w` của git dựa vào đây.
        public var wait: Bool

        public init(
            targets: [Target], stdinPath: String? = nil,
            readOnly: Bool = false, newWindow: Bool = false, wait: Bool = false
        ) {
            self.targets = targets
            self.stdinPath = stdinPath
            self.readOnly = readOnly
            self.newWindow = newWindow
            self.wait = wait
        }
    }

    public struct Response: Codable, Equatable {
        public enum Status: String, Codable {
            /// Ứng dụng đã nhận và mở file.
            case opened
            /// Tài liệu đã đóng — chỉ gửi khi `wait`.
            case closed
            case failed
        }

        public var status: Status
        public var message: String?

        public init(status: Status, message: String? = nil) {
            self.status = status
            self.message = message
        }
    }

    public enum Failure: Error, CustomStringConvertible {
        case notRunning
        case socketFailed(String, errno: Int32)

        public var description: String {
            switch self {
            case .notRunning: return "Không có GEditor nào đang chạy"
            case .socketFailed(let step, let code):
                return "Socket lỗi ở bước \(step): \(String(cString: strerror(code)))"
            }
        }
    }

    /// Đường dẫn socket. Nằm trong thư mục dữ liệu ứng dụng để mỗi người dùng một cái.
    ///
    /// Giới hạn `sun_path` là 104 byte trên macOS — thư mục Application Support của người dùng
    /// có tên dài bất thường sẽ vượt, nên chỗ gọi phải xử lý được lỗi thay vì cho là chắc chắn.
    public static var socketPath: String {
        AppPaths.applicationSupport.appendingPathComponent("cli.sock").path
    }

    static func makeAddress(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else {
            throw Failure.socketFailed("đường dẫn socket quá dài (\(bytes.count) byte)", errno: ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: bytes)
            destination[bytes.count] = 0
        }
        return address
    }

    /// Đọc một dòng từ socket. `nil` khi phía kia đóng kết nối.
    static func readLine(_ descriptor: Int32) -> Data? {
        var data = Data()
        var byte: UInt8 = 0
        while true {
            let got = read(descriptor, &byte, 1)
            if got == 0 { return data.isEmpty ? nil : data }
            if got < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if byte == UInt8(ascii: "\n") { return data }
            data.append(byte)
        }
    }

    static func writeLine(_ descriptor: Int32, _ data: Data) {
        var payload = data
        payload.append(UInt8(ascii: "\n"))
        payload.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = write(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if written <= 0 {
                    if written < 0 && errno == EINTR { continue }
                    return
                }
                offset += written
            }
        }
    }
}

/// Phía ỨNG DỤNG: lắng nghe yêu cầu mở file từ `geditor`.
public final class CLIBridgeServer {

    private let path: String
    private var listener: Int32 = -1
    private let lock = NSLock()
    /// Kết nối đang chờ tài liệu đóng, theo đường dẫn file.
    private var waiters: [String: [Int32]] = [:]
    private var isRunning = false

    public init(socketPath: String = CLIBridge.socketPath) {
        self.path = socketPath
    }

    deinit { stop() }

    /// Bắt đầu lắng nghe. `handler` được gọi trên MAIN THREAD.
    public func start(handler: @escaping (CLIBridge.OpenRequest) -> Void) throws {
        // Socket cũ còn sót lại sau khi ứng dụng bị kill: `bind` sẽ báo EADDRINUSE nếu không
        // dọn. Xóa trước là an toàn vì chỉ có một ứng dụng dùng đường dẫn này.
        unlink(path)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw CLIBridge.Failure.socketFailed("socket", errno: errno) }

        var address = try CLIBridge.makeAddress(path)
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, size) }
        }
        guard bound == 0 else {
            close(descriptor)
            throw CLIBridge.Failure.socketFailed("bind", errno: errno)
        }
        guard listen(descriptor, 16) == 0 else {
            close(descriptor)
            throw CLIBridge.Failure.socketFailed("listen", errno: errno)
        }
        // Chỉ chủ sở hữu đọc/ghi được: socket này mở file tùy ý trong phiên của người dùng.
        chmod(path, 0o600)

        listener = descriptor
        isRunning = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop(descriptor, handler: handler)
        }
    }

    public func stop() {
        lock.lock()
        isRunning = false
        let pending = waiters.values.flatMap { $0 }
        waiters.removeAll()
        lock.unlock()

        for descriptor in pending { close(descriptor) }
        if listener >= 0 {
            close(listener)
            listener = -1
        }
        unlink(path)
    }

    private func acceptLoop(_ listener: Int32, handler: @escaping (CLIBridge.OpenRequest) -> Void) {
        while true {
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else {
                if errno == EINTR { continue }
                return
            }
            handle(connection, handler: handler)
        }
    }

    private func handle(_ connection: Int32, handler: @escaping (CLIBridge.OpenRequest) -> Void) {
        guard let line = CLIBridge.readLine(connection),
              let request = try? JSONDecoder().decode(CLIBridge.OpenRequest.self, from: line)
        else {
            let response = CLIBridge.Response(status: .failed, message: "yêu cầu không đọc được")
            CLIBridge.writeLine(connection, (try? JSONEncoder().encode(response)) ?? Data())
            close(connection)
            return
        }

        // Ghi danh người chờ TRƯỚC khi gọi handler. Ngược lại là một cuộc đua: handler mở
        // file rồi người dùng đóng ngay, `documentClosed` chạy trước khi kết nối kịp vào danh
        // sách, và `geditor -w` chờ mãi một tài liệu đã đóng từ lâu.
        //
        // Giữ kết nối: đóng ứng dụng cũng làm socket đứt, và phía CLI coi đứt kết nối là "đã
        // xong" — nên không có đường nào để CLI treo vĩnh viễn.
        let waiting = request.wait ? request.targets.first?.path : nil  // ống dẫn: không có gì để chờ
        if let waiting {
            lock.lock()
            waiters[waiting, default: []].append(connection)
            lock.unlock()
        }

        let response = CLIBridge.Response(status: .opened)
        CLIBridge.writeLine(connection, (try? JSONEncoder().encode(response)) ?? Data())

        DispatchQueue.main.async { handler(request) }

        if waiting == nil { close(connection) }
    }

    /// Báo rằng tài liệu ở `path` đã đóng — giải phóng mọi `geditor -w` đang chờ nó.
    public func documentClosed(path: String) {
        lock.lock()
        let pending = waiters.removeValue(forKey: path) ?? []
        lock.unlock()

        let response = CLIBridge.Response(status: .closed)
        let payload = (try? JSONEncoder().encode(response)) ?? Data()
        for descriptor in pending {
            CLIBridge.writeLine(descriptor, payload)
            close(descriptor)
        }
    }
}

/// Phía LỆNH `geditor`: gửi yêu cầu tới ứng dụng đang chạy.
public enum CLIBridgeClient {

    /// Kết nối đứt trong lúc chờ = ứng dụng thoát mà không đóng tài liệu tử tế.
    ///
    /// Phân biệt với đóng bình thường vì hai chuyện này khác nhau với người dùng: `git commit`
    /// mà GEditor bị crash thì thông điệp commit có thể chưa được lưu, và im lặng trả về 0 sẽ
    /// làm git commit nội dung cũ. Ta vẫn trả 0 (file trên đĩa là sự thật), nhưng phải NÓI RA.
    public static let quitMessage = "ứng dụng đã thoát trước khi tài liệu được đóng"

    /// Gửi yêu cầu. Ném `Failure.notRunning` khi không có ứng dụng nào lắng nghe.
    ///
    /// - Parameter waitForClose: chặn tới khi ứng dụng báo tài liệu đã đóng, hoặc tới khi ứng
    ///   dụng thoát (kết nối đứt). Không có timeout: `geditor -w` phải chờ đúng bằng thời gian
    ///   người dùng sửa file, mà cái đó không đoán được.
    @discardableResult
    public static func send(
        _ request: CLIBridge.OpenRequest,
        socketPath: String = CLIBridge.socketPath,
        waitForClose: Bool = false
    ) throws -> CLIBridge.Response {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw CLIBridge.Failure.notRunning
        }

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw CLIBridge.Failure.socketFailed("socket", errno: errno) }
        defer { close(descriptor) }

        var address = try CLIBridge.makeAddress(socketPath)
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, size) }
        }
        guard connected == 0 else {
            // File còn đó nhưng không dùng được = ứng dụng đã chết mà chưa kịp dọn. ENOTSOCK
            // là trường hợp file thường nằm đúng chỗ socket — hiếm, nhưng vẫn là "không chạy"
            // chứ không phải lỗi hệ thống, và CLI cần phân biệt để còn khởi động app.
            throw errno == ECONNREFUSED || errno == ENOENT || errno == ENOTSOCK
                ? CLIBridge.Failure.notRunning
                : CLIBridge.Failure.socketFailed("connect", errno: errno)
        }

        CLIBridge.writeLine(descriptor, try JSONEncoder().encode(request))

        guard let line = CLIBridge.readLine(descriptor),
              let response = try? JSONDecoder().decode(CLIBridge.Response.self, from: line)
        else { throw CLIBridge.Failure.notRunning }

        guard waitForClose, response.status == .opened else { return response }

        // Chờ dòng thứ hai. Kết nối đứt (ứng dụng thoát) cũng tính là đã xong.
        guard let closing = CLIBridge.readLine(descriptor),
              let final = try? JSONDecoder().decode(CLIBridge.Response.self, from: closing)
        else { return CLIBridge.Response(status: .closed, message: quitMessage) }
        return final
    }
}
