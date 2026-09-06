import XCTest
@testable import GEditorCore

/// Kiểm thử cầu nối giữa lệnh `geditor` và ứng dụng (SAD §2.4, FR-AUTO-605).
///
/// Chạy cả hai đầu trong cùng tiến trình: server dùng socket ở thư mục tạm, client kết nối
/// tới đúng đường dẫn đó. Không cần ứng dụng thật, nên giao thức được kiểm ở mỗi lần chạy CI
/// chứ không chỉ khi ai đó nhớ mở app lên thử.
final class CLIBridgeTests: XCTestCase {

    /// Hạn CHỜ cho phép bắt tay qua socket — KHÔNG phải một chỉ tiêu hiệu năng.
    ///
    /// Để 5 giây thì bộ kiểm đỏ khi máy bận: đã gặp thật, `swift test` chạy cùng lúc với
    /// `run-coverage.sh` làm `testRequestReachesApplicationIntact` trượt, rồi chạy lại một mình
    /// thì xanh ba lần liên tiếp. Một bài kiểm đổi màu theo tải máy không nói gì về sản phẩm,
    /// và tệ hơn: nó dạy người ta chạy lại cho tới khi xanh.
    ///
    /// Nới rộng thì mất gì? Chỉ mất thời gian ở ca THẬT SỰ hỏng — mà ca ấy hiếm, còn ca đỏ
    /// nhầm thì không hiếm. Nếu cần đo tốc độ bắt tay thì đó là việc của bộ benchmark, không
    /// phải của một hạn chờ trong bài kiểm đúng-sai.
    static let deadline: TimeInterval = 30


    private var socketPath = ""
    private var server: CLIBridgeServer?

    override func setUpWithError() throws {
        // Đường dẫn PHẢI ngắn: `sun_path` chỉ có 104 byte, mà thư mục tạm của XCTest đã dài.
        socketPath = "/tmp/geditor-test-\(UInt32.random(in: 0 ..< 1_000_000)).sock"
    }

    override func tearDownWithError() throws {
        server?.stop()
        server = nil
        unlink(socketPath)
    }

    private func startServer(
        _ handler: @escaping (CLIBridge.OpenRequest) -> Void
    ) throws -> CLIBridgeServer {
        let server = CLIBridgeServer(socketPath: socketPath)
        try server.start(handler: handler)
        self.server = server
        return server
    }

    // MARK: - Cơ bản

    func testRequestReachesApplicationIntact() throws {
        let arrived = expectation(description: "ứng dụng nhận yêu cầu")
        var received: CLIBridge.OpenRequest?
        _ = try startServer { received = $0; arrived.fulfill() }

        let sent = CLIBridge.OpenRequest(
            targets: [.init(path: "/tmp/báo cáo.csv", line: 120, column: 5)],
            readOnly: true, newWindow: true, wait: false
        )
        DispatchQueue.global().async {
            _ = try? CLIBridgeClient.send(sent, socketPath: self.socketPath)
        }

        wait(for: [arrived], timeout: Self.deadline)
        // Đường dẫn có dấu cách và chữ có dấu phải đi qua nguyên vẹn.
        XCTAssertEqual(received, sent)
    }

    func testResponseSaysOpened() throws {
        _ = try startServer { _ in }
        let done = expectation(description: "nhận trả lời")
        var response: CLIBridge.Response?
        DispatchQueue.global().async {
            response = try? CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/a.txt")]),
                socketPath: self.socketPath
            )
            done.fulfill()
        }
        wait(for: [done], timeout: Self.deadline)
        XCTAssertEqual(response?.status, .opened)
    }

    /// Không có ứng dụng nào chạy thì phải nói RÕ, để CLI biết mà đi khởi động app.
    func testReportsNotRunningWhenNobodyListens() {
        XCTAssertThrowsError(
            try CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/a.txt")]),
                socketPath: "/tmp/geditor-không-tồn-tại-\(UUID().uuidString).sock"
            )
        ) { error in
            guard case CLIBridge.Failure.notRunning = error else { return XCTFail("nhận \(error)") }
        }
    }

    /// File socket còn sót sau khi ứng dụng bị kill: có file nhưng không ai nghe. Phải nhận ra
    /// là "không chạy" chứ không treo hay báo lỗi khó hiểu.
    func testStaleSocketFileIsTreatedAsNotRunning() throws {
        FileManager.default.createFile(atPath: socketPath, contents: Data())
        XCTAssertThrowsError(
            try CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/a.txt")]),
                socketPath: socketPath
            )
        ) { error in
            guard case CLIBridge.Failure.notRunning = error else { return XCTFail("nhận \(error)") }
        }
    }

    /// Ứng dụng khởi động lại khi file socket cũ còn đó — `bind` sẽ báo bận nếu không dọn.
    func testServerStartsOverStaleSocketFile() throws {
        FileManager.default.createFile(atPath: socketPath, contents: Data())
        XCTAssertNoThrow(try startServer { _ in })
    }

    /// Socket này mở file tùy ý trong phiên của người dùng — không được cho người khác đọc.
    func testSocketIsPrivateToTheUser() throws {
        _ = try startServer { _ in }
        let mode = try FileManager.default.attributesOfItem(atPath: socketPath)[.posixPermissions]
        XCTAssertEqual((mode as? NSNumber)?.int16Value, 0o600)
    }

    // MARK: - `geditor --wait` (EDITOR của git)

    func testWaitBlocksUntilDocumentCloses() throws {
        let opened = expectation(description: "đã mở")
        let finished = expectation(description: "đã đóng")
        let server = try startServer { _ in opened.fulfill() }

        var response: CLIBridge.Response?
        DispatchQueue.global().async {
            response = try? CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/commit.txt")], wait: true),
                socketPath: self.socketPath, waitForClose: true
            )
            finished.fulfill()
        }

        wait(for: [opened], timeout: Self.deadline)
        // Người chờ đã được ghi danh TRƯỚC khi handler chạy, nên gọi ngay ở đây là an toàn.
        server.documentClosed(path: "/tmp/commit.txt")

        wait(for: [finished], timeout: Self.deadline)
        XCTAssertEqual(response?.status, .closed)
    }

    /// Đóng tài liệu KHÁC không được thả nhầm người đang chờ.
    func testClosingOtherDocumentDoesNotRelease() throws {
        let opened = expectation(description: "đã mở")
        // Semaphore chứ không phải expectation: chỗ này phải chờ HAI lần — lần đầu mong hết
        // giờ, lần sau mong thành công — mà một expectation chỉ chờ được một lần.
        let finished = DispatchSemaphore(value: 0)
        let server = try startServer { _ in opened.fulfill() }

        DispatchQueue.global().async {
            _ = try? CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/a.txt")], wait: true),
                socketPath: self.socketPath, waitForClose: true
            )
            finished.signal()
        }
        wait(for: [opened], timeout: Self.deadline)

        server.documentClosed(path: "/tmp/khác.txt")
        XCTAssertEqual(finished.wait(timeout: .now() + 0.5), .timedOut, "vẫn phải đang chờ")

        server.documentClosed(path: "/tmp/a.txt")
        XCTAssertEqual(finished.wait(timeout: .now() + Self.deadline), .success)
    }

    /// Ứng dụng thoát khi đang có người chờ: CLI phải trở về, không treo vĩnh viễn.
    func testApplicationQuittingReleasesWaiter() throws {
        let opened = expectation(description: "đã mở")
        let finished = expectation(description: "đã thoát")
        let server = try startServer { _ in opened.fulfill() }

        var response: CLIBridge.Response?
        DispatchQueue.global().async {
            response = try? CLIBridgeClient.send(
                CLIBridge.OpenRequest(targets: [.init(path: "/tmp/a.txt")], wait: true),
                socketPath: self.socketPath, waitForClose: true
            )
            finished.fulfill()
        }
        wait(for: [opened], timeout: Self.deadline)

        server.stop()
        wait(for: [finished], timeout: Self.deadline)
        XCTAssertEqual(response?.status, .closed)
    }

    // MARK: - Biên

    func testTooLongSocketPathIsRejectedClearly() {
        let long = "/tmp/" + String(repeating: "d", count: 200) + ".sock"
        XCTAssertThrowsError(try CLIBridge.makeAddress(long)) { error in
            guard case CLIBridge.Failure.socketFailed(let step, _) = error else {
                return XCTFail("nhận \(error)")
            }
            XCTAssertTrue(step.contains("quá dài"), step)
        }
    }

    func testMalformedRequestGetsFailedResponse() throws {
        _ = try startServer { _ in XCTFail("yêu cầu hỏng không được chạm tới ứng dụng") }

        let done = expectation(description: "nhận trả lời")
        DispatchQueue.global().async {
            let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
            var address = try! CLIBridge.makeAddress(self.socketPath)
            _ = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            CLIBridge.writeLine(descriptor, Data("đây không phải JSON".utf8))
            if let line = CLIBridge.readLine(descriptor),
               let response = try? JSONDecoder().decode(CLIBridge.Response.self, from: line) {
                XCTAssertEqual(response.status, .failed)
            } else {
                XCTFail("không nhận được trả lời")
            }
            close(descriptor)
            done.fulfill()
        }
        wait(for: [done], timeout: Self.deadline)
    }
}

/// Nội dung từ ống dẫn (`ps aux | geditor`) — FR-AUTO-605.
final class PipedDocumentTests: XCTestCase {

    private func makeTemporary(_ bytes: [UInt8]) throws -> String {
        let path = NSTemporaryDirectory() + "geditor-pipe-test-\(UUID().uuidString)"
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        return path
    }

    /// Tab từ ống dẫn phải là "chưa có tên": Lưu phải hỏi Lưu ở đâu, chứ không được ghi đè
    /// lên file tạm rồi biến mất cùng nó.
    func testPipedDocumentHasNoPath() throws {
        let path = try makeTemporary(Array("xin chào\n".utf8))
        let document = try Document.fromPipe(temporaryPath: path)
        XCTAssertNil(document.path)
        XCTAssertFalse(document.isReadOnly)
        // Không có đường dẫn thì không có gì để so vân tay: `.unknown`, giống hệt tài liệu
        // chưa có tên. Quan trọng là KHÔNG BAO GIỜ `.modified` — người dùng không được nhận
        // hộp thoại "file đã đổi bên ngoài" cho một file tạm mà chính ứng dụng vừa xóa.
        XCTAssertEqual(document.externalChange(), .unknown)
    }

    /// File tạm bị xóa ngay, nhưng nội dung vẫn đọc được — mmap giữ inode sau `unlink`.
    /// Dữ liệu qua ống dẫn có thể nhạy cảm, không được nằm lại trong /tmp.
    func testTemporaryFileIsRemovedButContentSurvives() throws {
        let text = String(repeating: "dòng dữ liệu tiếng Việt\n", count: 5_000)
        let path = try makeTemporary(Array(text.utf8))
        let document = try Document.fromPipe(temporaryPath: path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "file tạm phải bị xóa")
        XCTAssertEqual(document.buffer.count, text.utf8.count)
        XCTAssertEqual(document.buffer.lineCount, 5_000)
        let firstLine = "dòng dữ liệu tiếng Việt\n"
        XCTAssertEqual(
            String(decoding: document.buffer.bytes(in: 0 ..< firstLine.utf8.count), as: UTF8.self),
            firstLine
        )
    }

    /// Nhận diện bảng mã vẫn chạy: `iconv -f utf8 -t tcvn3 ... | geditor` phải hiện đúng chữ.
    func testPipedContentIsStillDecoded() throws {
        let tcvn3 = EncodingConverter.encode(Array("Tiếng Việt".utf8), to: .tcvn3)
        XCTAssertEqual(tcvn3.unrepresentable, 0)
        let path = try makeTemporary(tcvn3.bytes)
        let document = try Document.fromPipe(temporaryPath: path, encoding: .tcvn3)
        XCTAssertEqual(document.encoding, .tcvn3)
        XCTAssertEqual(
            String(decoding: document.buffer.bytes(in: 0 ..< document.buffer.count), as: UTF8.self),
            "Tiếng Việt"
        )
    }

    /// Yêu cầu chỉ có stdin, không có target — server không được coi là hỏng.
    func testStdinRequestSurvivesRoundTrip() throws {
        let request = CLIBridge.OpenRequest(targets: [], stdinPath: "/tmp/x", wait: false)
        let decoded = try JSONDecoder().decode(
            CLIBridge.OpenRequest.self, from: try JSONEncoder().encode(request)
        )
        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.stdinPath, "/tmp/x")
    }
}
