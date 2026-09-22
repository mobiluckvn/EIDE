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
/// Bóc vỏ `CapabilityRun` khỏi câu trả lời của daemon.
///
/// `caps.invoke` và mọi alias trả về NGUYÊN bản ghi lượt chạy khi lượt ấy không xong — bị cổng
/// giữ, bị từ chối, hoặc hỏng — và trả thẳng kết quả khi xong. Bên gọi nào tự đọc `r["result"]`
/// sẽ thấy `nil` cho cả ba trường hợp đầu và kết luận "không có dữ liệu".
///
/// Đặt ở đây, trong `EideLoi`, vì đã có HAI bên gọi mắc đúng lỗi ấy: màn Chính sách báo "không
/// nạp được quy tắc nào" sau khi người bấm Dừng khẩn, và phiên làm việc báo "đã mở dự án" cho
/// một `project.open` vừa trả về E2000.
public enum EideKetQua {

    public enum Loi: Error, CustomStringConvertible {
        case chan(cap: String, quyet: String, luat: String, ly: String)
        case hong(cap: String, ma: String, van: String)

        /// Mã lỗi EIDE, nếu có — bên gọi cần nó để gợi ý ĐÚNG cách sửa.
        public var maEide: String? {
            if case .hong(_, let ma, _) = self, !ma.isEmpty { return ma }
            return nil
        }

        public var description: String {
            switch self {
            case .chan(let c, let q, let l, let ly):
                return "cổng chính sách trả \(q) cho `\(c)` theo luật \(l) — \(ly)"
            case .hong(let c, let ma, let van):
                return "`\(c)` không chạy được: \(van)\(ma.isEmpty ? "" : " (\(ma))")"
            }
        }
    }

    public static func boc(_ r: [String: Any], _ ten: String) throws -> [String: Any] {
        guard let tt = r["status"] as? String else { return r }   // không phải một lượt chạy
        if tt == "done" { return (r["result"] as? [String: Any]) ?? [:] }
        let cap = (r["cap"] as? String) ?? ten
        if let e = r["error"] as? [String: Any] {
            throw Loi.hong(cap: cap, ma: (e["eide_code"] as? String) ?? "",
                           van: (e["message"] as? String) ?? tt)
        }
        let qd = (r["decision"] as? [String: Any]) ?? [:]
        throw Loi.chan(cap: cap, quyet: (qd["decision"] as? String) ?? tt.uppercased(),
                       luat: (qd["rule"] as? String) ?? "?",
                       ly: (qd["reason"] as? String) ?? "không nêu lý do")
    }
}

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
    /// Ống stderr của daemon — nơi DUY NHẤT nói vì sao nó chết.
    private let loi = Pipe()
    /// Vòng đệm stderr. Ngoài actor vì `readabilityHandler` chạy ở luồng nền.
    private let demLoi = DemLoiDaemon()
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
    ///
    /// **`async` và chạy ngoài luồng chính.** Bản đầu là hàm đồng bộ gọi thẳng từ `@MainActor`:
    /// cửa sổ đứng hình suốt thời gian `eide` khởi động (~1 s cho `project list`, lâu hơn cho
    /// `project new`) — đúng lúc người vừa bấm nút, tức đúng lúc họ cần biết máy có nhận không.
    /// Không sập, không log, chỉ một cửa sổ chết trong một giây rồi sống lại.
    public static func motLan(_ thamSo: [String]) async throws -> (ma: Int32, json: [String: Any]?, van: String, loi: String) {
        try await Task.detached(priority: .userInitiated) { try _motLanDongBo(thamSo) }.value
    }

    private static func _motLanDongBo(_ thamSo: [String]) throws -> (ma: Int32, json: [String: Any]?, van: String, loi: String) {
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
        // stderr KHÔNG ném vào `/dev/null`.
        //
        // Daemon in vết lỗi và các dòng quyết định chính sách ra stderr; ném chúng đi nghĩa là
        // khi daemon chết, KHÔNG AI biết vì sao — kể cả `traceback.print_exc` mà chính daemon
        // gọi. Đo 22/09/2026 trên bài CNC: daemon chết giữa bước 2, và chỗ duy nhất có thể nói
        // lý do thì đã bị bịt.
        tienTrinh.standardError = loi
        do {
            try tienTrinh.run()
        } catch {
            throw Loi.khongChay("\(error)")
        }
        // ĐÓNG đầu ống KHÔNG dùng trong tiến trình CHA. Đây là lỗi làm cả giao diện treo.
        //
        // `Pipe` mở cả hai đầu ở cả hai tiến trình. Cha chỉ ĐỌC `ra`, nhưng vẫn giữ đầu GHI của
        // nó; nên khi daemon chết, ống vẫn còn một người ghi — chính mình — và
        // `availableData` KHÔNG BAO GIỜ thấy EOF. `_docDong` đứng đợi vĩnh viễn thay vì ném
        // `Loi.mat("daemon đóng ống")`.
        //
        // Đo 22/09/2026: daemon chết giữa `chat.send`; thẻ Run đã nhận đủ sự kiện nên ghi
        // "✅ Xong 6/6 bước", rồi màn hình đứng im mãi mãi — không lỗi, không hết giờ. Chủ sản
        // phẩm nhìn màn hình và nói "vẫn là xong 6/6 bước, chẳng hiển thị thêm cái gì cả".
        // Câu trả lời mang thẻ Ý hiểu, thẻ Kết quả và câu hỏi chờ người không bao giờ tới.
        ra.fileHandleForWriting.closeFile()
        vao.fileHandleForReading.closeFile()
        // Gom stderr vào một vòng đệm để còn kèm vào thông điệp lỗi. Đọc nền, không chặn.
        _batDocNen()
        loi.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if d.isEmpty { h.readabilityHandler = nil; return }
            self?.demLoi.them(String(data: d, encoding: .utf8) ?? "")
        }
    }

    /// Vài dòng cuối stderr, dạng đọc được — rỗng nếu daemon không nói gì.
    public var loiCuoi: String { demLoi.cuoi() }

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

    /// Các lời gọi ĐANG BAY, khớp theo `id` của JSON-RPC.
    private var dangCho: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    /// Lý do ống đứt, nếu đã đứt. Lời gọi tới sau thì hỏng NGAY, không đợi vô ích.
    private var daDut: String?

    /// Gọi daemon. **Song song được** — nhiều lời gọi cùng bay, khớp về theo `id`.
    ///
    /// ## Vì sao bỏ mutex một-lời-gọi-một-lúc
    ///
    /// Bản trước xếp hàng mọi lời gọi và mỗi lời gọi tự đọc ống tới khi gặp câu trả lời của
    /// chính nó. Điều đó làm `chat.send` — chạy đồng bộ cả chuỗi, hai đến bốn phút — **chặn
    /// toàn bộ giao tiếp**: `autonomy.get`, `queue.list`, `undo.list` không chạy được, nhịp tim
    /// không chạy được, nên sau 6 giây màn hình tự treo biển "Dữ liệu cũ — không nghe được
    /// daemon N giây qua" trong khi daemon hoàn toàn khỏe. Mọi màn mở ra lúc ấy đứng ở
    /// "Đang đọc…".
    ///
    /// JSON-RPC có `id` đúng để làm việc này; cái mutex đang bỏ thứ giao thức cho sẵn.
    /// Hạn thời gian theo phương thức, giây. `nil` = không hạn.
    ///
    /// Không một hạn chung: `plane.hello` mà 3 giây không trả lời là daemon có vấn đề, còn
    /// `chat.send` chạy cả chuỗi có mô hình thì hai phút là bình thường. Một hạn chung đủ rộng
    /// cho `chat.send` thì vô dụng với `plane.hello`, và ngược lại thì cắt giữa việc thật.
    ///
    /// Những phương thức KHÔNG hạn là những phương thức có thể chạy lâu một cách hợp lệ. Chúng
    /// không đợi vô hạn nữa nhờ `ongDut()`: ống đứt thì mọi lời gọi đang bay hỏng ngay.
    public static func hanCua(_ phuongThuc: String) -> Double? {
        switch phuongThuc {
        case "plane.hello": return 5
        case "autonomy.get", "autonomy.set", "queue.list", "undo.list", "stop": return 10
        case "chat.send", "chat.resume", "caps.invoke": return nil
        default: return 30
        }
    }

    @discardableResult
    public func goi(_ phuongThuc: String, _ thamSo: [String: Any] = [:]) async throws -> [String: Any] {
        if let vi = daDut { throw Loi.mat(vi) }
        soThuTu += 1
        let id = soThuTu
        let yc: [String: Any] = ["jsonrpc": "2.0", "id": id,
                                 "method": phuongThuc, "params": thamSo]
        guard let d = try? JSONSerialization.data(withJSONObject: yc) else {
            throw Loi.rpc(ma: -1, thongDiep: "không mã hoá được \(phuongThuc)", maEide: nil)
        }
        if let han = Self.hanCua(phuongThuc) {
            // Đặt một hẹn giờ HUỶ: quá hạn thì làm hỏng continuation ấy và nói rõ hạn là bao
            // nhiêu. Không huỷ được lời gọi phía daemon — JSON-RPC không có đường ấy — nên câu
            // trả lời tới muộn sẽ bị `nhanDong` bỏ qua vì `id` đã rút khỏi bảng.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(han * 1_000_000_000))
                await self?.quaHan(id, phuongThuc, han)
            }
        }
        return try await withCheckedThrowingContinuation { cont in
            dangCho[id] = cont
            do { try _gui(d) } catch {
                dangCho[id] = nil
                cont.resume(throwing: error)
            }
        }
    }

    private func quaHan(_ id: Int, _ phuongThuc: String, _ han: Double) {
        guard let c = dangCho.removeValue(forKey: id) else { return }   // đã trả lời rồi
        c.resume(throwing: Loi.mat("`\(phuongThuc)` không trả lời trong \(Int(han)) giây — "
                                   + "daemon còn sống nhưng không đáp"))
    }

    /// Vòng đọc NỀN — một cái duy nhất cho cả đời daemon.
    ///
    /// ## Vì sao phải có
    ///
    /// Trước bản này `onSuKien` được gọi ở đúng một chỗ: bên trong vòng đọc của `goi()`. Nghĩa
    /// là **sự kiện chỉ tới được khi có một lời gọi đang bay**; giữa hai lời gọi chúng nằm
    /// trong đệm ống. Thứ cứu tình huống ấy là nhịp tim — mỗi vài giây gọi `plane.hello`, và
    /// vòng đọc của *nó* mới xả đệm ra. Tức tiến độ của tác tử tới được màn hình nhờ một hiệu
    /// ứng phụ của phép kiểm sống-chết, và nó chậm đúng bằng chu kỳ nhịp tim.
    ///
    /// Đọc trên một `Task.detached` vì `availableData` CHẶN luồng. Chặn luồng của actor thì
    /// `goi()` không vào được actor để đăng ký continuation — bế tắc.
    private func _batDocNen() {
        let ong = ra.fileHandleForReading
        Task.detached { [weak self] in
            var dem = Data()
            while true {
                // Tách dòng TRƯỚC khi đọc thêm: một lần `availableData` có thể mang về nhiều
                // dòng, và bỏ sót chúng là bỏ sót sự kiện.
                while let i = dem.firstIndex(of: 0x0A) {
                    let d = Data(dem[dem.startIndex..<i])
                    dem = Data(dem[dem.index(after: i)...])
                    await self?.nhanDong(d)
                }
                let phan = ong.availableData
                if phan.isEmpty {
                    await self?.ongDut()
                    return
                }
                dem.append(phan)
            }
        }
    }

    /// Một dòng từ daemon: câu trả lời (có `id`) hay sự kiện (không `id`).
    private func nhanDong(_ d: Data) {
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
        if let ten = o["method"] as? String, o["id"] == nil {
            onSuKien?(ten, (o["params"] as? [String: Any]) ?? [:])
            return
        }
        guard let id = o["id"] as? Int, let cont = dangCho.removeValue(forKey: id) else { return }
        if let e = o["error"] as? [String: Any] {
            cont.resume(throwing: Loi.rpc(ma: e["code"] as? Int ?? -1,
                                          thongDiep: e["message"] as? String ?? "",
                                          maEide: (e["data"] as? [String: Any])?["eide_code"] as? String))
        } else {
            cont.resume(returning: o["result"] as? [String: Any] ?? [:])
        }
    }

    /// Ống đứt: làm HỎNG mọi lời gọi đang bay, không để chúng đợi mãi.
    ///
    /// Đây là chỗ bản trước hỏng nặng nhất. Daemon chết giữa `chat.send`, và lời gọi ấy đợi
    /// vĩnh viễn — màn hình đứng ở trạng thái cuối nhận được, không lỗi, không hết giờ.
    private func ongDut() {
        let v = demLoi.cuoi()
        let vi = "daemon đóng ống"
            + (v.isEmpty ? " (daemon không in lý do nào ra stderr)" : " — daemon nói:\n\(v)")
        daDut = vi
        for (_, c) in dangCho { c.resume(throwing: Loi.mat(vi)) }
        dangCho.removeAll()
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

}

/// Vòng đệm mấy dòng stderr gần nhất của daemon.
///
/// Một lớp có khoá riêng chứ không phải trường của `EideDaemon`: `readabilityHandler` chạy trên
/// luồng nền của Foundation, còn `EideDaemon` là actor — chạm vào trạng thái của actor từ đó là
/// một cuộc đua, và trình biên dịch chặn đúng chỗ ấy.
///
/// Giữ TRẦN dòng: daemon có thể in hàng nghìn dòng trong một phiên dài, và giữ hết chúng để
/// dùng tám dòng cuối là đổi một lỗi khó chẩn đoán lấy một chỗ rò bộ nhớ.
final class DemLoiDaemon: @unchecked Sendable {
    private let khoa = NSLock()
    private var dong: [String] = []
    private let tran = 40

    func them(_ s: String) {
        khoa.lock(); defer { khoa.unlock() }
        for d in s.split(separator: "\n", omittingEmptySubsequences: true) {
            dong.append(String(d))
        }
        if dong.count > tran { dong.removeFirst(dong.count - tran) }
    }

    func cuoi(_ n: Int = 8) -> String {
        khoa.lock(); defer { khoa.unlock() }
        return dong.suffix(n).joined(separator: "\n")
    }
}
