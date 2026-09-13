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

    /// Gọi một phương thức. `method` là kiểu sinh từ openrpc.json, nên không gõ nhầm được tên.
    @discardableResult
    public func goi(_ method: EideMethod, _ params: [String: Any] = [:]) async throws -> [String: Any] {
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
        var arg = Array(eide.dropFirst()) + ["daemon"]
        if let duAn { arg += ["-p", duAn] }
        process.executableURL = URL(fileURLWithPath: eide[0])
        process.arguments = arg
        process.standardInput = vao
        process.standardOutput = ra
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    public func send(_ line: Data) async throws { guiDongBo(line) }

    /// Đọc tới hết một dòng. JSON-RPC qua stdio dùng một thông điệp một dòng (API-15 §2), nên
    /// biên thông điệp là `\n` — và vì thế phải ĐỆM: một lần `read` có thể trả về nửa dòng,
    /// hoặc một dòng rưỡi.
    public func receiveLine() async throws -> Data { try docDongBo() }

    // Phần đụng khoá nằm trong hàm ĐỒNG BỘ, không phải trong `async`: Swift 6 coi việc giữ
    // `NSLock` bắc qua một điểm `await` là lỗi, vì tác vụ có thể đổi luồng giữa lock và
    // unlock. Ở đây không có `await` nào bên trong, nên khoá không bao giờ bắc qua điểm treo.
    private func guiDongBo(_ line: Data) {
        khoa.lock(); defer { khoa.unlock() }
        vao.fileHandleForWriting.write(line + Data("\n".utf8))
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

    public func close() async {
        vao.fileHandleForWriting.closeFile()
        process.terminate()
        process.waitUntilExit()
    }
}
