import Foundation

/// Client JSON-RPC 2.0 tới daemon `eided` — WI-021.
///
/// Spec: API-15 §2 (JSON-RPC GEditor ↔ daemon), §3 (mã lỗi); GPI-23 §1 ("plugin EIDE là client
/// THUẦN của daemon: không giữ tri thức, không gọi LLM, không chạy công cụ; mọi thứ qua
/// JSON-RPC"); DEP-26 §3 (vòng đời daemon).
///
/// ## Vì sao stdio chứ chưa phải Unix socket
///
/// GP-09 của GPI-23 muốn Unix socket, và DEP-26 §3 mô tả một `eided` sống lâu cho mỗi người
/// dùng. Sprint 1 chốt "chỉ chạy foreground `eide daemon`" qua stdio, nên client này nói
/// chuyện với một tiến trình con. Hai thứ ấy khác nhau ở VÒNG ĐỜI, không khác ở giao thức:
/// cùng JSON-RPC 2.0, cùng khung thông điệp. Khi daemon lên socket, chỉ `Transport` đổi.
///
/// ## Vì sao không giữ trạng thái
///
/// GPI-23 §1 nói plugin là client thuần. Nên ở đây không có cache năng lực, không có bản sao
/// hàng đợi, không có "trạng thái tự chủ" nhớ sẵn: mỗi câu hỏi là một lời gọi. Giữ bản sao là
/// mời hai nguồn sự thật vào một sản phẩm mà cả thiết kế của nó dựa trên việc chỉ có một.
public actor EideClient {

    /// Đường truyền tới daemon. Tách ra để đổi stdio → socket mà không đụng phần còn lại.
    public protocol Transport: Sendable {
        func send(_ line: Data) async throws
        func receiveLine() async throws -> Data
        /// Giết đầu kia ĐỘT NGỘT — chỉ để đo phép phát hiện mất kết nối (UXC-31 B6).
        /// Mặc định không làm gì: một transport trong bộ nhớ không có ai để giết.
        func gietDeTest()
        func close() async
    }

    public enum Failure: Error, CustomStringConvertible {
        case khongKetNoi(String)
        case rpc(code: Int, message: String, eideCode: String?)
        case duLieuSai(String)

        public var description: String {
            switch self {
            case .khongKetNoi(let s): return "Không kết nối được daemon: \(s)"
            case .rpc(let c, let m, let e): return "Lỗi \(e ?? String(c)): \(m)"
            case .duLieuSai(let s): return "Dữ liệu không đọc được: \(s)"
            }
        }

        /// Mã lỗi EIDE nếu daemon trả một mã có trong API-15 §3.
        public var maEide: EideErrorCode? {
            if case .rpc(let c, _, _) = self { return EideErrorCode(rawValue: c) }
            return nil
        }
    }

    private let transport: any Transport
    private var soThuTu = 0

    public init(transport: any Transport) {
        self.transport = transport
    }

    /// Thông báo `event.*` từ daemon — `(tên phương thức, params)`.
    ///
    /// Panel cần chúng để hiện thẻ câu hỏi gộp (U3) và làm mới hàng đợi khi tác tử tự làm việc
    /// (U2). Đặt ở đây vì `goi` là chỗ duy nhất đọc ống dẫn: một kênh sự kiện riêng sẽ phải
    /// tranh cùng một `FileHandle`, và hai bên cùng đọc một ống là cách mất thông điệp.
    private var onSuKien: ((String, [String: Any]) -> Void)?

    /// Đăng ký người nghe. `EideClient` là actor nên trường không gán thẳng từ ngoài được —
    /// và đó là điều tốt: kênh sự kiện chỉ có MỘT người nghe, đặt qua một hàm thì chỗ nào
    /// giành mất nó cũng nhìn thấy được.
    public func theoDoi(_ f: @escaping (String, [String: Any]) -> Void) { onSuKien = f }

    /// Giết daemon đột ngột — chỉ dùng trong bài kiểm B6/N6. Xem `Transport.gietDeTest`.
    public func gietDeTest() { transport.gietDeTest() }

    /// Chốt tuần tự hoá — xem `goi`. Một mutex bất đồng bộ, không phải `Task` nối đuôi:
    /// một `Task` chỉ bao phần CHỜ, nó hoàn thành ngay khi lời gọi trước bắt đầu đọc ống chứ
    /// không đợi đọc xong — nên hai lời gọi vẫn vào ống cùng lúc. (Tôi đã viết nhầm đúng như
    /// thế một lần, và test E2E vẫn treo y nguyên.)
    private var dangBan = false
    private var hangCho: [CheckedContinuation<Void, Never>] = []

    private func vaoHang() async {
        if !dangBan {
            dangBan = true
            return
        }
        await withCheckedContinuation { c in hangCho.append(c) }
    }

    private func roiHang() {
        if hangCho.isEmpty {
            dangBan = false
        } else {
            hangCho.removeFirst().resume()
        }
    }

    /// Gọi một phương thức. `method` là kiểu sinh từ openrpc.json, nên không gõ nhầm được tên.
    ///
    /// ## Vì sao phải xếp hàng, dù đây đã là một actor
    ///
    /// Actor tuần tự hoá từng ĐOẠN mã giữa hai điểm treo, không tuần tự hoá cả một hàm `async`.
    /// `goi` có `await transport.receiveLine()` bên trong vòng đọc, và ở đúng chỗ ấy actor
    /// **nhả quyền** cho lời gọi khác vào. Hai lời gọi đồng thời vì thế tranh nhau đọc một ống:
    /// lời gọi B đọc được câu trả lời của A, thấy `id` khác, `continue` — và A không bao giờ
    /// thấy câu trả lời của mình nữa. **Cả hai treo vĩnh viễn.**
    ///
    /// Đo 15/09/2026: mở một màn phát ra ba lời gọi gần như cùng lúc — `caps.describe` cho ô
    /// nhập, `caps.invoke` để nạp màn, `caps.invoke passport.list` cho gợi ý — và màn "Xung đột
    /// tri thức" đứng ở "Đang đọc trạng thái…" mãi mãi, trong khi daemon trả lời trong 0,4 giây.
    /// Một test E2E gọi ba lượt bằng `async let` treo đủ 10 phút.
    ///
    /// Chốt này xếp chúng nối đuôi: mỗi lời gọi chờ lời gọi trước đọc xong response của nó rồi
    /// mới bắt đầu. Xem lỗi im lặng số 35.
    @discardableResult
    public func goi(_ method: EideMethod, _ params: [String: Any] = [:]) async throws -> [String: Any] {
        await vaoHang()
        defer { roiHang() }
        return try await _goiMotMinh(method, params)
    }

    /// Thân thật của `goi`, chạy khi đã chắc chắn không ai khác đang đọc ống.
    private func _goiMotMinh(_ method: EideMethod,
                             _ params: [String: Any]) async throws -> [String: Any] {
        soThuTu += 1
        let yeu_cau: [String: Any] = ["jsonrpc": "2.0", "id": soThuTu,
                                      "method": method.rawValue, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: yeu_cau) else {
            throw Failure.duLieuSai("không mã hoá được yêu cầu \(method.rawValue)")
        }
        try await transport.send(data)

        // Đọc tới khi gặp câu trả lời CỦA CHÍNH lời gọi này.
        //
        // API-15 §2 cho thông báo `event.*` đi cùng ống với câu trả lời, và `serve_stdio` phát
        // chúng NGAY TRONG lúc xử lý — nên `caps.invoke` sinh hai `event.run.progress` trước
        // khi trả kết quả. Bản đầu đọc đúng một dòng rồi coi nó là câu trả lời: nó nhận lấy
        // thông báo đầu tiên, thấy không có `result`, và trả về `[:]`.
        //
        // Hệ quả im lặng hoàn hảo: **mọi lời gọi `caps.invoke` từ panel đều trả rỗng** — không
        // lỗi, không treo, chỉ một từ điển trống. Màn hình hiện "chưa có dữ liệu" cho mọi thứ.
        // Các test cũ không bắt được vì chúng gọi `plane.hello` và `caps.list`, hai phương thức
        // không sinh sự kiện nào.
        //
        // JSON-RPC 2.0 phân biệt hai loại bằng trường `id`: câu trả lời có, thông báo không.
        var obj: [String: Any] = [:]
        while true {
            let line = try await transport.receiveLine()
            guard let o = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                throw Failure.duLieuSai(String(data: line, encoding: .utf8) ?? "<không phải UTF-8>")
            }
            if let ten = o["method"] as? String, o["id"] == nil {
                onSuKien?(ten, (o["params"] as? [String: Any]) ?? [:])
                continue
            }
            // Câu trả lời của một lời gọi CŨ (ví dụ lần trước bị huỷ giữa chừng) thì bỏ qua:
            // gán nó cho lời gọi này là trả dữ liệu của một câu hỏi khác.
            if let i = o["id"] as? Int, i != soThuTu { continue }
            obj = o
            break
        }
        if let e = obj["error"] as? [String: Any] {
            let code = e["code"] as? Int ?? -1
            let msg = e["message"] as? String ?? ""
            // API-15 §3: daemon đính `eide_code` (dạng Exxxx) vào `data` để phía giao diện
            // hiện đúng mã tài liệu chứ không phải một số JSON-RPC trần trụi.
            let eideCode = (e["data"] as? [String: Any])?["eide_code"] as? String
            throw Failure.rpc(code: code, message: msg, eideCode: eideCode)
        }
        return obj["result"] as? [String: Any] ?? [:]
    }

    public func dong() async { await transport.close() }
}

/// Đường truyền qua tiến trình con `eide daemon` (stdio).
public extension EideClient.Transport {
    func gietDeTest() {}
}

public final class EideStdioTransport: EideClient.Transport, @unchecked Sendable {

    private let process = Process()
    private let vao = Pipe()
    private let ra = Pipe()
    private var dem = Data()
    private let khoa = NSLock()

    /// - Parameters:
    ///   - eide: đường dẫn tới `python -m eide.cli` hoặc tới `eide` đã cài.
    ///   - duAn: thư mục dự án (`-p`), nếu có.
    public init(eide: [String], duAn: String? = nil) throws {
        // Tắt SIGPIPE cho cả tiến trình, MỘT LẦN.
        //
        // Mặc định của Unix là giết tiến trình khi nó ghi vào một ống không còn ai đọc. Với một
        // công cụ dòng lệnh thì đó là hành vi đúng; với một ứng dụng có cửa sổ thì nó nghĩa là:
        // daemon chết → EIDE biến mất khỏi màn hình, không hộp thoại, không log, không cơ hội
        // lưu gì. `SIG_IGN` biến nó thành `EPIPE` trên lời gọi `write`, và `guiDongBo` dịch
        // `EPIPE` thành một câu người đọc được.
        //
        // `dispatch_once` không cần: đặt lại cùng một giá trị nhiều lần là vô hại.
        signal(SIGPIPE, SIG_IGN)
        var arg = Array(eide.dropFirst()) + ["daemon"]
        if let duAn { arg += ["-p", duAn] }
        process.executableURL = URL(fileURLWithPath: eide[0])
        process.arguments = arg
        process.standardInput = vao
        process.standardOutput = ra
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    public func send(_ line: Data) async throws { try guiDongBo(line) }

    /// Đọc tới hết một dòng. JSON-RPC qua stdio dùng một thông điệp một dòng (API-15 §2), nên
    /// biên thông điệp là `\n` — và vì thế phải ĐỆM: một lần `read` có thể trả về nửa dòng,
    /// hoặc một dòng rưỡi.
    public func receiveLine() async throws -> Data { try docDongBo() }

    // Phần đụng khoá nằm trong hàm ĐỒNG BỘ, không phải trong `async`: Swift 6 coi việc giữ
    // `NSLock` bắc qua một điểm `await` là lỗi, vì tác vụ có thể đổi luồng giữa lock và
    // unlock. Ở đây không có `await` nào bên trong, nên khoá không bao giờ bắc qua điểm treo.
    private func guiDongBo(_ line: Data) throws {
        khoa.lock(); defer { khoa.unlock() }
        // `write(contentsOf:)` NÉM lỗi; `write(_:)` thì không — nó bắn `SIGPIPE`, và tín hiệu ấy
        // mặc định GIẾT cả tiến trình. Cùng với `SIG_IGN` đặt ở `EideStdioTransport.init`, một
        // daemon đã chết nay thành một câu lỗi thay vì một cửa sổ biến mất.
        //
        // Đo 16/09/2026: chạy `sim.run` (qemu-system-avr) qua daemon, daemon dừng giữa chừng, và
        // cả EIDE tắt ngay lập tức — mã thoát 141, không hộp thoại, không dòng log, không gì
        // trên màn hình. Người dùng chỉ thấy ứng dụng biến mất giữa lúc đang chạy mô phỏng.
        do {
            try vao.fileHandleForWriting.write(contentsOf: line + Data("\n".utf8))
        } catch {
            throw EideClient.Failure.khongKetNoi(
                "daemon đã dừng — không gửi được lệnh nữa (\(error.localizedDescription)). "
                + "Mở lại dự án để khởi động daemon mới.")
        }
    }

    private func docDongBo() throws -> Data {
        while true {
            khoa.lock()
            if let i = dem.firstIndex(of: UInt8(ascii: "\n")) {
                let dong = Data(dem[dem.startIndex..<i])
                dem = Data(dem[dem.index(after: i)...])
                khoa.unlock()
                return dong
            }
            khoa.unlock()
            let phan = ra.fileHandleForReading.availableData
            if phan.isEmpty {
                throw EideClient.Failure.khongKetNoi("daemon đóng ống")
            }
            khoa.lock(); dem.append(phan); khoa.unlock()
        }
    }

    /// Giết tiến trình daemon KHÔNG đóng ống êm — chỉ dùng để đo phép phát hiện mất kết nối.
    ///
    /// `close()` đóng ống rồi mới `terminate()`, tức là một lần chia tay có thông báo. Bài kiểm
    /// B6 cần đúng thứ ngược lại: daemon biến mất ĐỘT NGỘT, như khi nó bị OOM hay bị người dùng
    /// tắt từ Activity Monitor — vì đó mới là lúc giao diện có nguy cơ hiện dữ liệu cũ mà không
    /// biết mình đang hiện dữ liệu cũ.
    public func gietDeTest() {
        process.terminate()
    }

    public func close() async {
        vao.fileHandleForWriting.closeFile()
        process.terminate()
        process.waitUntilExit()
    }
}
