import Foundation

/// **Client JSON-RPC tới `eide daemon`** — API-15 §2.
///
/// Viết lại cho bản mới, mang sang BỐN bài học của bản cũ và không mang gì khác. Mỗi bài dưới
/// đây là một lỗi đã mất nhiều giờ; chúng ở dạng mã chứ không dạng ghi nhớ.
///
/// 1. **Thông báo đi chung ống với câu trả lời.** `serve_stdio` phát `event.*` NGAY trong lúc
///    xử lý, nên một `caps.invoke` sinh hai `event.run.progress` TRƯỚC câu trả lời của chính
///    nó. Đọc một dòng rồi coi đó là câu trả lời sẽ nhận phải thông báo đầu tiên, thấy không có
///    `result`, và trả về rỗng — mọi lời gọi im lặng trả rỗng, màn hình nào cũng "chưa có dữ
///    liệu". Phân biệt bằng trường `id`: câu trả lời có, thông báo không.
///
/// 2. **Hai lời gọi đồng thời tranh nhau đọc một ống.** `actor` tuần tự hoá từng ĐOẠN giữa hai
///    điểm treo, không tuần tự hoá cả một hàm `async`; ở chỗ `await` đọc ống, lời gọi khác vào
///    được. B đọc mất câu trả lời của A, thấy `id` khác, bỏ qua — cả hai treo vĩnh viễn. Cần
///    một chốt thật.
///
/// 3. **SIGPIPE giết ứng dụng.** Daemon chết giữa chừng thì `write` bắn SIGPIPE và tiến trình
///    biến mất: mã thoát 141, không hộp thoại, không log. Bỏ qua tín hiệu ấy một lần lúc khởi
///    động.
///
/// 4. **Kênh sự kiện chỉ được BƠM khi có lời gọi.** Vì ống chỉ được đọc trong `goi`, một giao
///    diện ngồi yên là một giao diện điếc — tác tử chạy ở tiến trình khác, sổ cái đầy sự kiện,
///    màn hình đứng im. Bên dùng phải tự giữ một nhịp; xem `nhipTim`.
public actor EideDaemon {

    public enum Loi: Error, CustomStringConvertible {
        case khongChay(String)
        case mat(String)
        case rpc(ma: Int, thongDiep: String, maEide: String?)

        public var description: String {
            switch self {
            case .khongChay(let s): return "không chạy được daemon: \(s)"
            case .mat(let s): return "mất kết nối: \(s)"
            case .rpc(_, let t, let m): return m.map { "\($0): \(t)" } ?? t
            }
        }
    }

    private let tienTrinh = Process()
    private let vao = Pipe()
    private let ra = Pipe()
    private var soThuTu = 0
    private var dem = Data()
    private var onSuKien: (@Sendable (String, [String: Any]) -> Void)?

    /// Tìm cách chạy `eide daemon`.
    ///
    /// Ba đường, theo thứ tự chắc chắn giảm dần. Nói ra cả ba vì "không chạy được daemon" là lỗi
    /// người dùng gặp trước mọi lỗi khác, và một thông điệp không nói đã thử gì thì không giúp
    /// được ai.
    public static func timLenh() -> [String]? {
        let mt = ProcessInfo.processInfo.environment
        // 1. Người chạy chỉ định thẳng trình thông dịch của venv.
        if let py = mt["EIDE_PYTHON"], FileManager.default.isExecutableFile(atPath: py) {
            return [py, "-m", "eide.cli"]
        }
        // 2. Lệnh `eide` trong PATH.
        for d in (mt["PATH"] ?? "").split(separator: ":") {
            let p = String(d) + "/eide"
            if FileManager.default.isExecutableFile(atPath: p) { return [p] }
        }
        // 3. venv của kho, cho lượt chạy từ thư mục mã.
        for p in ["\(mt["HOME"] ?? "")/Documents/EIDE/.venv-arm/bin/eide",
                  "\(FileManager.default.currentDirectoryPath)/.venv-arm/bin/eide"] {
            if FileManager.default.isExecutableFile(atPath: p) { return [p] }
        }
        return nil
    }

    /// Chạy `eide` MỘT lần rồi lấy JSON trên stdout.
    ///
    /// Tạo dự án là con gà và quả trứng: `EideDaemon(duAn:)` cần sẵn một thư mục dự án, còn
    /// `project.create` chính là thứ tạo ra thư mục ấy. Nên lượt gọi đầu tiên đi qua CLI một
    /// lượt, không qua daemon.
    ///
    /// stderr KHÔNG bị bỏ: dòng `-- run … · <quyết định> theo <luật>` nằm ở đó, và khi
    /// `project.create` bị chính sách chặn thì đó là chỗ DUY NHẤT nói vì sao.
    public static func motLan(_ thamSo: [String]) throws -> (ma: Int32, json: [String: Any]?, van: String, loi: String) {
        guard let lenh = timLenh() else { throw Loi.khongChay("không tìm thấy `eide` (thử $EIDE_PYTHON, $PATH, .venv-arm)") }
        let tt = Process()
        tt.executableURL = URL(fileURLWithPath: lenh[0])
        tt.arguments = Array(lenh.dropFirst()) + thamSo
        let oRa = Pipe(), oLoi = Pipe()
        tt.standardOutput = oRa
        tt.standardError = oLoi
        tt.standardInput = FileHandle.nullDevice
        try tt.run()
        // Đọc HẾT hai ống trước khi chờ: ống 64 KB đầy thì tiến trình con treo, và `waitUntilExit`
        // treo theo — một bế tắc không có thông điệp nào cả.
        let dRa = oRa.fileHandleForReading.readDataToEndOfFile()
        let dLoi = oLoi.fileHandleForReading.readDataToEndOfFile()
        tt.waitUntilExit()
        let van = String(data: dRa, encoding: .utf8) ?? ""
        let loi = String(data: dLoi, encoding: .utf8) ?? ""
        let js = (try? JSONSerialization.jsonObject(with: dRa)) as? [String: Any]
        return (tt.terminationStatus, js, van, loi)
    }

    /// Bật một daemon cho một dự án.
    public init(duAn: String) throws {
        // Bài học 3 — bỏ qua SIGPIPE MỘT LẦN cho cả tiến trình.
        signal(SIGPIPE, SIG_IGN)

        guard let lenh = Self.timLenh() else {
            throw Loi.khongChay("không tìm thấy `eide`. Đã thử: biến môi trường EIDE_PYTHON, "
                                + "lệnh `eide` trong PATH, và .venv-arm của kho.")
        }
        tienTrinh.executableURL = URL(fileURLWithPath: lenh[0])
        tienTrinh.arguments = Array(lenh.dropFirst()) + ["daemon", "-p", duAn]
        tienTrinh.standardInput = vao
        tienTrinh.standardOutput = ra
        tienTrinh.standardError = FileHandle.nullDevice
        do {
            try tienTrinh.run()
        } catch {
            throw Loi.khongChay("\(error)")
        }
    }

    /// Đăng ký người nghe `event.*`. CHỈ MỘT — hai người nghe một kênh là cách mất thông điệp.
    public func theoDoi(_ f: @escaping @Sendable (String, [String: Any]) -> Void) {
        onSuKien = f
    }

    public func dung() {
        vao.fileHandleForWriting.closeFile()
        tienTrinh.terminate()
    }

    /// Giết ĐỘT NGỘT — chỉ để đo phép phát hiện mất kết nối (UXC-31 B6).
    public func gietDeTest() { tienTrinh.terminate() }

    // MARK: - gọi

    /// Chốt tuần tự hoá — bài học 2. Một mutex bất đồng bộ, không phải `Task` nối đuôi: một
    /// `Task` chỉ bao phần CHỜ và hoàn thành ngay khi lời gọi trước bắt đầu đọc ống.
    private var dangBan = false
    private var hangCho: [CheckedContinuation<Void, Never>] = []

    private func vaoHang() async {
        while dangBan {
            await withCheckedContinuation { hangCho.append($0) }
        }
        dangBan = true
    }

    private func roiHang() {
        dangBan = false
        if !hangCho.isEmpty { hangCho.removeFirst().resume() }
    }

    @discardableResult
    public func goi(_ phuongThuc: String, _ thamSo: [String: Any] = [:]) async throws -> [String: Any] {
        await vaoHang()
        defer { roiHang() }

        soThuTu += 1
        let id = soThuTu
        let yc: [String: Any] = ["jsonrpc": "2.0", "id": id,
                                 "method": phuongThuc, "params": thamSo]
        guard let d = try? JSONSerialization.data(withJSONObject: yc) else {
            throw Loi.rpc(ma: -1, thongDiep: "không mã hoá được \(phuongThuc)", maEide: nil)
        }
        try _gui(d)

        // Bài học 1 — đọc tới khi gặp câu trả lời CỦA CHÍNH lời gọi này.
        while true {
            let dong = try _docDong()
            guard let o = try? JSONSerialization.jsonObject(with: dong) as? [String: Any] else {
                continue
            }
            if let ten = o["method"] as? String, o["id"] == nil {
                onSuKien?(ten, (o["params"] as? [String: Any]) ?? [:])
                continue
            }
            guard (o["id"] as? Int) == id else { continue }
            if let e = o["error"] as? [String: Any] {
                throw Loi.rpc(ma: e["code"] as? Int ?? -1,
                              thongDiep: e["message"] as? String ?? "",
                              maEide: (e["data"] as? [String: Any])?["eide_code"] as? String)
            }
            return o["result"] as? [String: Any] ?? [:]
        }
    }

    private func _gui(_ d: Data) throws {
        var b = d
        b.append(0x0A)
        do {
            try vao.fileHandleForWriting.write(contentsOf: b)
        } catch {
            throw Loi.mat("daemon đóng ống khi ghi")
        }
    }

    private func _docDong() throws -> Data {
        while true {
            if let i = dem.firstIndex(of: 0x0A) {
                let d = Data(dem[dem.startIndex..<i])
                dem = Data(dem[dem.index(after: i)...])
                return d
            }
            let phan = ra.fileHandleForReading.availableData
            if phan.isEmpty { throw Loi.mat("daemon đóng ống") }
            dem.append(phan)
        }
    }
}
