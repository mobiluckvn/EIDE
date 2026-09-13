import AppKit
import XCTest

@testable import EIDEKit

/// Đầu-cuối: lệnh người gõ → daemon THẬT → năng lực THẬT → khung nhìn.
///
/// Spec: API-15 §2 `caps.invoke`; UXD-13 §2; GPI-23 §1.
///
/// ## Tầng test này bắt được gì mà ba tầng kia không
///
/// - `Eide*ViewsTests` dựng dữ liệu bằng tay rồi kiểm khung nhìn. Chúng chỉ chứng minh khung
///   nhìn đọc đúng **hình dạng tôi tưởng tượng ra**.
/// - `EideClientTests` kiểm chỗ nối JSON-RPC. Nó không biết gì về khung nhìn.
/// - `EideNapLanDau*` kiểm quy tắc quyết định. Nó không chạy năng lực nào.
///
/// Chỗ hở giữa ba tầng ấy là câu hỏi đắt nhất: **dữ liệu THẬT mà năng lực trả về có hiện được
/// trên khung nhìn không?** Câu trả lời đã là "không" ít nhất hai lần trong dự án này —
/// `DocView` bản đầu đọc `{sections[], stale[]}` mà không hợp đồng nào có, `SimView` đọc
/// `report.expectations` trong khi tên thật là `metrics.expect`. Cả hai lần, test đơn vị vẫn
/// xanh vì chúng dựng đúng cái sai mà mã đọc.
///
/// Nguyên tắc của bộ này: **gọi thật, rồi kiểm khung nhìn KHÔNG rơi vào trạng thái rỗng.** Một
/// khung nhìn rỗng sau khi nhận dữ liệu thật là dấu hiệu nó đọc sai tên trường — im lặng, và
/// trông y hệt "chưa có dữ liệu".
final class EideE2ETests: XCTestCase {

    // MARK: - Dựng một dự án thật trong thư mục tạm

    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var python: String? {
        let fm = FileManager.default
        for v in [".venv-arm", ".venv-x86"] {
            let p = gocKho.appendingPathComponent("\(v)/bin/python")
            if fm.isExecutableFile(atPath: p.path) { return p.path }
        }
        return nil
    }

    /// Dự án dùng chung cho cả lớp: tạo MỘT lần, vì `project.create` mất vài trăm ms và mọi
    /// bài test ở đây chỉ ĐỌC nó.
    private static var duAn: URL?
    private static var loiDung: String?

    override class func setUp() {
        super.setUp()
        guard let py = python else { loiDung = "chưa có .venv-arm/.venv-x86"; return }
        do {
            let tam = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("eide-e2e-\(ProcessInfo.processInfo.processIdentifier)")
            try FileManager.default.createDirectory(at: tam, withIntermediateDirectories: true)

            let p = Process()
            p.executableURL = URL(fileURLWithPath: py)
            p.arguments = ["-m", "eide.cli", "caps", "invoke", "project.create",
                           #"{"text":"dự án E2E cho STM32F411","chip":"st.stm32f411"}"#,
                           "-p", tam.path]
            p.currentDirectoryURL = gocKho
            let ra = Pipe()
            p.standardOutput = ra
            p.standardError = Pipe()
            try p.run()
            let d = ra.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()

            // `caps invoke` in một dòng "-- run …" rồi tới JSON. Cắt từ dấu "{" đầu tiên.
            let s = String(data: d, encoding: .utf8) ?? ""
            guard let i = s.firstIndex(of: "{"),
                  let j = try JSONSerialization.jsonObject(
                    with: Data(s[i...].utf8)) as? [String: Any],
                  let duong = j["path"] as? String else {
                loiDung = "không tạo được dự án: \(s.prefix(300))"
                return
            }
            duAn = URL(fileURLWithPath: duong)
        } catch {
            loiDung = "\(error)"
        }
    }

    override class func tearDown() {
        if let d = duAn?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: d)
        }
        super.tearDown()
    }

    private func moClient() throws -> EideClient {
        if let l = Self.loiDung { throw XCTSkip(l) }
        guard let py = Self.python, let da = Self.duAn else {
            throw XCTSkip("chưa dựng được dự án E2E")
        }
        FileManager.default.changeCurrentDirectoryPath(Self.gocKho.path)
        return EideClient(transport: try EideStdioTransport(
            eide: [py, "-m", "eide.cli"], duAn: da.path))
    }

    /// Gọi một năng lực và trả `result`, hoặc `nil` nếu chuỗi không chạy tới nơi.
    private func chay(_ c: EideClient, _ id: String,
                      _ params: [String: Any] = [:]) async throws -> [String: Any]? {
        let r = try await c.goi(.capsInvoke, ["id": id, "params": params])
        guard (r["status"] as? String) == "done" else { return nil }
        return (r["result"] as? [String: Any]) ?? [:]
    }

    /// Toàn bộ chữ đang hiện trong thân một màn — thứ người dùng thật sự đọc.
    private func chu(_ m: ManHinhCoSo) -> String {
        let nhan = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
        let hang = m.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }
        return ([m.tomTat.stringValue] + nhan
                + hang.compactMap { ($0 as? NSTextField)?.stringValue }
                + hang.compactMap { ($0 as? NSButton)?.title }).joined(separator: " ")
    }

    // MARK: - Màn 2: Tổng quan — chỗ đã bắt được một lỗi thật

    func testMAN2_tongQuanHIENduLIEUthat() async throws {
        let c = try moClient()
        let kq = try await chay(c, "project.status")
        let r = try XCTUnwrap(kq, "project.status không chạy được trên dự án E2E")

        let v = ProjectStatusView()
        v.capNhat(ketQua: r)

        // `report.features` là một OBJECT `{total, passing, failing, first_failing}` và
        // `gates_open` là một SỐ — không phải mảng như bản đầu của khung nhìn giả định. Một
        // khung nhìn đọc sai kiểu sẽ hiện "chưa có tính năng nào" trên mọi dự án, mãi mãi.
        let bc = try XCTUnwrap(r["report"] as? [String: Any])
        XCTAssertNotNil(bc["features"], "hợp đồng đổi: không còn `features`")
        XCTAssertNotNil(bc["cost_today"], "hợp đồng đổi: không còn `cost_today`")

        // Dù dự án mới tinh (0 tính năng), tóm tắt vẫn phải mang chi phí và mức tự chủ — hai
        // con số LUÔN có.
        XCTAssertTrue(v.tomTat.stringValue.contains("USD"), v.tomTat.stringValue)
        XCTAssertFalse(chu(v).contains("Chưa mở dự án nào"),
                       "màn khẳng định chưa mở dự án trong khi vừa đọc được trạng thái của nó")
    }

    // MARK: - Màn 21: Môi trường

    func testMAN21_moiTruongHIENosVAarchTHAT() async throws {
        let c = try moClient()
        let kq = try await chay(c, "env.detect")
        let r = try XCTUnwrap(kq)

        let v = EnvView()
        v.capNhat(ketQua: r)

        let mt = try XCTUnwrap(r["env"] as? [String: Any])
        let os = try XCTUnwrap(mt["os"] as? String)
        XCTAssertTrue(v.tomTat.stringValue.contains(os),
                      "tóm tắt không mang HĐH thật: \(v.tomTat.stringValue)")
        XCTAssertTrue(chu(v).contains(os), chu(v))
    }

    // MARK: - Màn 5: Hộ chiếu chip

    func testMAN5_hoChieuTRENduANtrongNOIRAcachLAMtiep() async throws {
        // Dự án vừa tạo CHƯA có store, nên `passport.list` trả E2000 — và đó không phải hỏng,
        // đó là thứ tự công việc. Điều phải đúng: câu người đọc được nói ra việc tiếp theo,
        // chứ không phải một mã lỗi trần.
        let c = try moClient()
        let r = try await c.goi(.capsInvoke, ["id": "passport.list", "params": [:]])
        if (r["status"] as? String) == "done" {
            let kq = (r["result"] as? [String: Any]) ?? [:]
            XCTAssertNotNil(kq["passports"] ?? kq["items"] ?? kq["list"],
                            "passport.list trả hình dạng lạ: \(kq.keys.sorted())")
            return
        }
        let cau = EidePanel.docLoi(r)
        XCTAssertTrue(cau.contains("nạp tài liệu") || cau.contains("E"),
                      "lỗi nạp màn phải đọc được: \(cau)")
        XCTAssertFalse(cau.contains("trạng thái ?"), cau)
    }

    // MARK: - Màn 7: Bản đồ tri thức

    func testMAN7_banDoTRIthucTRAveHINHdangDOCduoc() async throws {
        let c = try moClient()
        let r = try await c.goi(.capsInvoke, ["id": "view.kg_map", "params": [:]])
        if (r["status"] as? String) == "done" {
            let kq = (r["result"] as? [String: Any]) ?? [:]
            XCTAssertNotNil(kq["graph"] ?? kq["nodes"], "view.kg_map trả: \(kq.keys.sorted())")
        } else {
            XCTAssertFalse(EidePanel.docLoi(r).isEmpty)
        }
    }

    // MARK: - Màn 22: FlowMap — nạp bằng PHƯƠNG THỨC, không phải năng lực

    func testMAN22_flowMapDOCduocHANGdoiTHAT() async throws {
        let c = try moClient()
        let doi = try await c.goi(.queueList, [:])
        let tc = try await c.goi(.autonomyGet, [:])

        var g: [String: Any] = doi
        g["autonomy"] = tc["autonomy"]
        g["stopped"] = tc["stopped"]

        let v = FlowMapView()
        v.capNhat(ketQua: g)

        // Chín cổng luôn hiện đủ, kể cả khi hàng đợi rỗng.
        XCTAssertEqual(v.soDong, 9 + v.soDangCho)
        XCTAssertEqual(v.soDangCho, (doi["items"] as? [[String: Any]])?.count ?? 0)
        XCTAssertFalse(v.mucTuChu.isEmpty, "autonomy.get không trả mức tự chủ")
    }

    // MARK: - Màn 20: Mô hình & chi phí

    func testMAN20_moHinhLAYchiPHItuProjectStatus() async throws {
        let c = try moClient()
        let kq = try await chay(c, "project.status")
        let r = try XCTUnwrap(kq)
        let tc = try await c.goi(.autonomyGet, [:])

        var g: [String: Any] = (r["report"] as? [String: Any]) ?? [:]
        g["autonomy"] = tc["autonomy"]

        let v = ModelsView()
        v.capNhat(ketQua: g)
        XCTAssertTrue(v.tomTat.stringValue.contains("USD"), v.tomTat.stringValue)
        // Và vẫn nói ra phần API-15 chưa cấp — nói thật không phụ thuộc dữ liệu.
        XCTAssertTrue(chu(v).contains("DEV-093"), chu(v))
    }

    // MARK: - Hàng đợi và mức tự chủ — hai thứ U2 đòi LUÔN hiện

    func testHANGdoiVAtuCHUdocDUOCtuDAEMONthat() async throws {
        let c = try moClient()
        let tc = try await c.goi(.autonomyGet, [:])
        XCTAssertNotNil(tc["autonomy"] as? String, "autonomy.get: \(tc)")
        XCTAssertNotNil(tc["stopped"] as? Bool)

        let doi = try await c.goi(.queueList, [:])
        XCTAssertNotNil(doi["items"] as? [[String: Any]], "queue.list: \(doi.keys.sorted())")

        let un = try await c.goi(.undoList, [:])
        XCTAssertNotNil(un["items"] as? [[String: Any]], "undo.list: \(un.keys.sorted())")
    }

    // MARK: - Đường vào ô lệnh, đi trọn

    func testGOcauTIENGVIETthiCHUOIviecCHAYthat() async throws {
        // Lỗi im lặng số 15: panel từng dừng ở `chat.parse_intent`. Bài này đi đúng đường panel
        // đi — `duongVao` phân loại, rồi `chat.send` chạy trọn DPS-09 — nhưng KHÔNG gọi mô
        // hình thật: `chat.send` sẽ hỏng ở bước hiểu ý nếu không có khóa API, và đó vẫn là một
        // câu trả lời đúng (lỗi có mã), không phải một lần treo.
        let c = try moClient()
        guard case .chuoiViec(let t) = EidePanel.duongVao("Tạo dự án robot hai bánh") else {
            return XCTFail("câu tiếng Việt phải đi tới chuỗi việc")
        }
        do {
            let r = try await c.goi(.chatSend, ["text": t])
            // Ba kết quả hợp lệ, và cả ba đều KHÁC "rỗng":
            //   có khóa mô hình  → `{intent_id, run_id?}`;
            //   không có khóa    → CapabilityRun của `chat.parse_intent` với `error` có mã;
            //   cổng chặn        → CapabilityRun `pending`.
            // Thứ KHÔNG được phép xảy ra là một từ điển trống — đó chính là hình dạng lỗi im
            // lặng số 18 để lại: `caps.invoke` trả `[:]` vì client nuốt mất câu trả lời.
            XCTAssertFalse(r.isEmpty, "chat.send trả rỗng — client có nuốt câu trả lời không?")
            let coY = r["intent_id"] != nil
            let laRun = (r["status"] as? String) != nil && r["cap"] != nil
            XCTAssertTrue(coY || laRun, "chat.send trả: \(r.keys.sorted())")
            if laRun, (r["status"] as? String) != "done" {
                XCTAssertNotNil((r["error"] as? [String: Any])?["eide_code"],
                                "chuỗi không chạy được thì phải nói MÃ lỗi")
            }
        } catch let e as EideClient.Failure {
            XCTAssertNotNil(e.maEide, "lỗi phải mang mã API-15: \(e)")
        }
    }

    func testLENHgachCHEOmoDUNGmanVAnapDUNGnangLUC() async throws {
        // `/project.status` → mở màn Main, và vì nó chỉ-đọc nên nạp luôn.
        guard case .moMan(let id, _) = EidePanel.duongVao("/project.status") else {
            return XCTFail("phải là lệnh mở màn")
        }
        let c = try moClient()
        let hd = try await c.goi(.capsDescribe, ["id": id])
        XCTAssertEqual(hd["ui"] as? String, "Main (Tổng quan)",
                       "bảng màn hình đổi: \(hd["ui"] ?? "?")")
        XCTAssertEqual(EidePanel.tuChay(hopDong: hd, id: id, coThamSo: false), .chay)
    }

    // MARK: - Mọi năng lực chỉ-đọc đều chạy được thật

    func testMOInangLUCtrongNAPantoanDEUTRAloiDOCduoc() async throws {
        // `napAnToan` là thứ panel tự chạy khi mở màn, nên mỗi cái phải cho một trong HAI kết
        // quả: chạy xong, hoặc một lỗi CÓ MÃ mà `docLoi` dịch được thành câu hướng dẫn.
        //
        // Đo trên dự án vừa tạo: 5/11 trả E2000 vì chưa có store (`passport.*`, `view.kg_map`,
        // `kg.conflicts`, `view.conflict_board`). Đó KHÔNG phải hỏng — đó là thứ tự công việc,
        // và màn phải nói ra việc tiếp theo thay vì hiện một mã lỗi đỏ.
        let c = try moClient()
        var xau: [String] = []
        for id in EidePanel.napAnToan.sorted() {
            let r = try await c.goi(.capsInvoke, ["id": id, "params": [:]])
            if r.isEmpty { xau.append("\(id): trả RỖNG"); continue }
            if (r["status"] as? String) == "done" { continue }
            guard let e = r["error"] as? [String: Any],
                  let ma = e["eide_code"] as? String, ma.hasPrefix("E") else {
                xau.append("\(id): không chạy và không có mã lỗi")
                continue
            }
            let cau = EidePanel.docLoi(r)
            if cau.count < 10 { xau.append("\(id): câu lỗi quá ngắn — \(cau)") }
        }
        XCTAssertTrue(xau.isEmpty, "năng lực tự nạp trả thứ không dùng được: \(xau)")
    }
}

/// Client phải lọc thông báo `event.*` ra khỏi câu trả lời — lỗi im lặng số 18.
///
/// `serve_stdio` phát `event.*` NGAY TRONG lúc xử lý một lời gọi, trên CÙNG ống dẫn. Bản đầu
/// của `EideClient.goi` đọc đúng một dòng rồi coi nó là câu trả lời: nó nhận lấy thông báo đầu
/// tiên, thấy không có `result`, và trả về `[:]`.
///
/// Hệ quả: **mọi `caps.invoke` từ panel đều trả rỗng** — không lỗi, không treo, chỉ một từ điển
/// trống, và mọi màn hình hiện "chưa có dữ liệu". Các test cũ không bắt được vì chúng gọi
/// `plane.hello` và `caps.list`, hai phương thức không sinh sự kiện nào.
final class EideSuKienTests: XCTestCase {

    /// Hộp gom sự kiện — closure chạy trong actor nên không bắt biến cục bộ được.
    private final class ThuSuKien: @unchecked Sendable {
        private let khoa = NSLock()
        private var _ds: [String] = []
        func them(_ t: String) { khoa.lock(); _ds.append(t); khoa.unlock() }
        var ds: [String] { khoa.lock(); defer { khoa.unlock() }; return _ds }
    }

    /// Ống giả phát ra đúng thứ tự daemon thật phát: hai thông báo rồi mới tới câu trả lời.
    private final class OngGia: EideClient.Transport, @unchecked Sendable {
        var dong: [String]
        init(_ d: [String]) { dong = d }
        func send(_ line: Data) async throws {}
        func receiveLine() async throws -> Data {
            guard !dong.isEmpty else { throw EideClient.Failure.duLieuSai("hết dòng") }
            return Data(dong.removeFirst().utf8)
        }
        func close() async {}
    }

    func testTHONGbaoDIcungONGkhongBIlamCAUtraLOI() async throws {
        let ong = OngGia([
            #"{"jsonrpc":"2.0","method":"event.run.progress","params":{"run_id":"r1"}}"#,
            #"{"jsonrpc":"2.0","method":"event.run.progress","params":{"run_id":"r1","status":"done"}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"status":"done","result":{"report":{"cost_today":0.5}}}}"#,
        ])
        let c = EideClient(transport: ong)
        let thu = ThuSuKien()
        await c.theoDoi { ten, _ in thu.them(ten) }

        let r = try await c.goi(.capsInvoke, ["id": "project.status"])
        XCTAssertEqual((r["status"] as? String), "done",
                       "client nuốt mất câu trả lời: \(r)")
        XCTAssertEqual(thu.ds, ["event.run.progress", "event.run.progress"],
                       "thông báo phải tới được panel, không bị vứt đi")
    }

    func testCAUtraLOIcuaMOTloiGOIcuBIboQUA() async throws {
        // Một lời gọi trước bị huỷ giữa chừng để lại câu trả lời của nó trong ống. Gán nó cho
        // lời gọi này là trả dữ liệu của một câu hỏi khác — im lặng và khó tìm hơn hẳn một lỗi.
        let ong = OngGia([
            #"{"jsonrpc":"2.0","id":99,"result":{"status":"done","result":{"cua":"loi goi cu"}}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"status":"done","result":{"cua":"loi goi nay"}}}"#,
        ])
        let c = EideClient(transport: ong)
        let r = try await c.goi(.capsList, [:])
        XCTAssertEqual(((r["result"] as? [String: Any])?["cua"] as? String), "loi goi nay")
    }

    func testLOIvanDUOCnemRAsauKHIloCthongBAO() async throws {
        let ong = OngGia([
            #"{"jsonrpc":"2.0","method":"event.notice","params":{}}"#,
            // Mã trong `error.code` là mã EIDE (2000), không phải mã JSON-RPC âm — API-15 §3.
            #"{"jsonrpc":"2.0","id":1,"error":{"code":2000,"message":"hỏng","data":{"eide_code":"E2000"}}}"#,
        ])
        let c = EideClient(transport: ong)
        do {
            _ = try await c.goi(.capsInvoke, [:])
            XCTFail("phải ném lỗi")
        } catch let e as EideClient.Failure {
            XCTAssertEqual(e.maEide?.ma, "E2000")
        }
    }
}

/// Panel phải NGHE kênh sự kiện — lỗi im lặng số 19.
///
/// `hienCauHoi` là `public`, có test, và trước hôm nay **chưa từng được gọi**: không chỗ nào
/// trong panel đăng ký người nghe. Daemon phát `event.chat.question` mỗi lần một năng lực cần
/// người chọn, và thẻ câu hỏi gộp của UXD-13 U3 không bao giờ hiện ra — người dùng thấy việc
/// dừng lại mà không thấy câu hỏi.
///
/// Bài test này không dựng cả panel (nó cần daemon và một cửa sổ); nó kiểm hai điều kiện làm
/// nên chỗ nối: client CÓ chỗ đăng ký, và daemon THẬT có phát ra sự kiện ấy.
final class EideKenhSuKienTests: XCTestCase {

    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDAEMONthatPHATsuKIENtrongMOTloiGOI() async throws {
        let fm = FileManager.default
        // LẤY CÁI ĐẦU TIÊN tìm thấy, không ghi đè: máy này có cả hai venv, và bản x86 chạy
        // dưới Rosetta không luôn đủ gói — lặp mà ghi đè thì test lặng lẽ chạy trên venv sai.
        var py: String?
        for v in [".venv-arm", ".venv-x86"] where py == nil {
            let p = Self.gocKho.appendingPathComponent("\(v)/bin/python")
            if fm.isExecutableFile(atPath: p.path) { py = p.path }
        }
        guard let py else { throw XCTSkip("chưa có venv") }
        fm.changeCurrentDirectoryPath(Self.gocKho.path)

        let c = EideClient(transport: try EideStdioTransport(eide: [py, "-m", "eide.cli"]))
        let thu = ThuSuKienChung()
        await c.theoDoi { ten, _ in thu.them(ten) }

        // `caps.invoke` sinh `cap.run.start`/`cap.run.finish` → hai `event.run.progress`.
        _ = try await c.goi(.capsInvoke, ["id": "env.detect", "params": [:]])
        XCTAssertTrue(thu.ds.contains("event.run.progress"),
                      "daemon không phát sự kiện nào trong một lời gọi: \(thu.ds)")
        await c.dong()
    }

    func testMOIsuKIENapi15DEUcoNHANHxuLYhoacCOchuY() throws {
        // Mười sáu phương thức `event.*` của API-15 §1. Bài test đọc thẳng openrpc.json: nếu
        // một sự kiện mới được thêm mà panel không biết, con số lệch và test đỏ — thay vì sự
        // kiện ấy rơi vào `default` mãi mãi.
        let f = Self.gocKho.appendingPathComponent("docs/spec/api/openrpc.json")
        let d = try JSONSerialization.jsonObject(with: try Data(contentsOf: f))
            as? [String: Any] ?? [:]
        let ten = ((d["methods"] as? [[String: Any]]) ?? [])
            .compactMap { $0["name"] as? String }.filter { $0.hasPrefix("event.") }
        XCTAssertEqual(ten.count, 16, "số sự kiện API-15 đổi: \(ten)")

        // Bốn nhóm panel xử lý + phần còn lại cố ý bỏ qua (chưa có chỗ hiện tử tế).
        let daXuLy: Set<String> = [
            "event.chat.question", "event.notice", "event.chat.report",
            "event.queue.changed", "event.gate.opened", "event.undo.registered",
            "event.undo.expired", "event.autonomy.changed",
            "event.knowledge.changed", "event.doc.stale", "event.diagram.stale",
        ]
        let boQua: Set<String> = [
            "event.chat.restated",      // thẻ ý hiểu — chưa dựng
            "event.run.progress",       // tiến độ chuỗi — chưa có chỗ hiện
            "event.job.progress",       // việc nặng chạy nền
            "event.discover.changed",   // cần board
            "event.serial.line",        // cần board
        ]
        let la = Set(ten).subtracting(daXuLy).subtracting(boQua)
        XCTAssertTrue(la.isEmpty, "sự kiện chưa ai quyết định làm gì: \(la.sorted())")
        XCTAssertEqual(daXuLy.count + boQua.count, 16)
    }
}

/// Hộp gom sự kiện dùng chung — closure chạy trong actor nên không bắt biến cục bộ được.
final class ThuSuKienChung: @unchecked Sendable {
    private let khoa = NSLock()
    private var _ds: [String] = []
    func them(_ t: String) { khoa.lock(); _ds.append(t); khoa.unlock() }
    var ds: [String] { khoa.lock(); defer { khoa.unlock() }; return _ds }
}
