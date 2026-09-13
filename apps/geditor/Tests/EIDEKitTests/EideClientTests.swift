import Foundation
import XCTest

@testable import EIDEKit

/// WI-021 — client JSON-RPC nói chuyện thật với `eide daemon`.
///
/// Spec: API-15 §2, §3, §8 (test hợp đồng); GPI-23 §1 (plugin là client thuần).
///
/// Test này gọi tiến trình Python thật, không giả lập. Đó là chủ ý: thứ dễ hỏng nhất ở đây
/// không phải logic Swift mà là CHỖ NỐI — khung thông điệp, mã lỗi, tên phương thức. Một giả
/// lập viết theo hiểu biết của tôi sẽ đồng ý với tôi, kể cả khi cả hai cùng sai.
final class EideClientTests: XCTestCase {

    /// Gốc kho: Tests/EIDEKitTests → Tests → apps/geditor → apps → EIDE
    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// `python` của venv theo kiến trúc, cùng cách Makefile chọn.
    private static func pythonEide() -> [String]? {
        let fm = FileManager.default
        for venv in [".venv-arm", ".venv-x86", ".venv"] {
            let p = gocKho.appendingPathComponent("\(venv)/bin/python")
            if fm.isExecutableFile(atPath: p.path) { return [p.path, "-m", "eide.cli"] }
        }
        return nil
    }

    private func moClient() throws -> EideClient {
        guard let eide = Self.pythonEide() else {
            throw XCTSkip("chưa có .venv-arm/.venv-x86 — chạy `make setup` ở gốc kho")
        }
        FileManager.default.changeCurrentDirectoryPath(Self.gocKho.path)
        return EideClient(transport: try EideStdioTransport(eide: eide))
    }

    // MARK: - hợp đồng: mã sinh khớp spec

    func testSoPhuongThucKhopSpec() {
        // API-15 §8 (3). Ai thêm phương thức vào openrpc.json mà quên sinh lại thì con số này
        // lệch và test đỏ TRƯỚC khi người dùng bấm một nút không tồn tại.
        XCTAssertEqual(EideMethod.allCases.count, eideSoPhuongThuc)
        XCTAssertEqual(EideErrorCode.allCases.count, eideSoMaLoi)
    }

    func testKhongTenPhuongThucNaoChuaDauCachHoacGachCheo() {
        // OpenRPC 1.3: `name` là MỘT tên gọi được. Đã từng có hai mục gộp hai tên bằng " / ",
        // và một client sinh từ đó không gọi được cái nào — xem DEVIATIONS DEV-023.
        for m in EideMethod.allCases {
            XCTAssertFalse(m.rawValue.contains(" "), "tên có dấu cách: \(m.rawValue)")
            XCTAssertFalse(m.rawValue.contains("/"), "tên có dấu /: \(m.rawValue)")
        }
    }

    func testMaLoiMangCaMaVaCachXuLy() {
        // Một mã lỗi không kèm việc phải làm thì chỉ là một con số hiện lên màn hình.
        XCTAssertEqual(EideErrorCode.migrationRequired.ma, "E6003")
        XCTAssertEqual(EideErrorCode.migrationRequired.cachXuLy, "eide migrate")
    }

    // MARK: - nói chuyện thật với daemon

    func testHelloTraVePhienBanApi() async throws {
        let c = try moClient()
        let r = try await c.goi(.planeHello, ["client": "EIDEKit-test"])
        await c.dong()
        XCTAssertNotNil(r["api_version"], "plane.hello phải trả api_version (API-15 §1 handshake)")
    }

    func testCapsListTraVeNangLucDaHienThuc() async throws {
        let c = try moClient()
        let r = try await c.goi(.capsList, [:])
        await c.dong()
        let caps = (r["caps"] ?? r["capabilities"]) as? [[String: Any]] ?? []
        XCTAssertFalse(caps.isEmpty, "phải có năng lực trong registry")
    }

    func testLoiTuDaemonMangMaEide() async throws {
        // Không chỉ "có lỗi": phía giao diện cần ĐÚNG mã của API-15 để hiện cách xử lý.
        let c = try moClient()
        do {
            // Tên tham số là `id`, theo openrpc.json — không phải `cap_id`. Lần viết đầu tôi
            // đoán sai và chính test này bắt được: đó là lý do nó gọi daemon thật.
            _ = try await c.goi(.capsDescribe, ["id": "khong.he.co.nang.luc.nay"])
            await c.dong()
            XCTFail("phải báo lỗi")
        } catch let e as EideClient.Failure {
            await c.dong()
            XCTAssertNotNil(e.maEide, "lỗi phải mang mã EIDE, nhận: \(e)")
        }
    }

    func testNhieuLoiGoiLienTiepKhongLanDong() async throws {
        // Khung thông điệp là chỗ dễ hỏng nhất của stdio: một lần đọc có thể trả nửa dòng hoặc
        // một dòng rưỡi. Gọi liên tiếp là cách bắt lỗi đệm.
        let c = try moClient()
        for _ in 0..<5 {
            let r = try await c.goi(.planeHello, [:])
            XCTAssertNotNil(r["api_version"])
        }
        await c.dong()
    }
}

/// Premise của quy tắc `EidePanel.tuChay` — kiểm với daemon THẬT, không giả lập.
///
/// `EideNapLanDauTests` kiểm bản thân quy tắc bằng hợp đồng dựng tay. Bài này kiểm điều kiện
/// làm quy tắc ấy có ích: những năng lực nào thật sự thỏa ba điều kiện, và những năng lực nào
/// thì không. Một giả lập viết theo hiểu biết của tôi sẽ đồng ý với tôi, kể cả khi cả hai cùng
/// sai — đó là lý do `EideClientTests` gọi tiến trình Python thật, và bài này đi cùng nó.
final class EideNapLanDauPremiseTests: XCTestCase {

    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func moClient() throws -> EideClient {
        let fm = FileManager.default
        for v in [".venv-arm", ".venv-x86"] {
            let p = Self.gocKho.appendingPathComponent("\(v)/bin/python")
            if fm.isExecutableFile(atPath: p.path) {
                fm.changeCurrentDirectoryPath(Self.gocKho.path)
                return EideClient(transport:
                    try EideStdioTransport(eide: [p.path, "-m", "eide.cli"]))
            }
        }
        throw XCTSkip("chưa có .venv-arm/.venv-x86 — chạy `make setup` ở gốc kho")
    }

    func testNANGLUCchiDOCthatSuTUchayDUOC() async throws {
        // Nếu một ngày `project.status` thôi là R0, hoặc mọc thêm tham số bắt buộc, thì màn
        // Tổng quan lặng lẽ quay về trạng thái "mở ra là rỗng" — đúng lỗi quy tắc này chữa.
        let c = try moClient()
        for id in ["project.status", "passport.query", "env.detect"] {
            let hd = try await c.goi(.capsDescribe, ["id": id])
            XCTAssertEqual(EidePanel.tuChay(hopDong: hd, id: id, coThamSo: false), .chay,
                           "\(id) thôi tự chạy được: risk=\(hd["risk"] ?? "?") "
                         + "undo=\(hd["undo"] ?? "?")")
        }
    }

    func testNANGLUCcoTACdongKHONGtuChay() async throws {
        // Ba hình dạng "không được tự chạy", mỗi cái vướng một điều kiện khác nhau:
        //   `req.trace_matrix` — R0 và không tham số, nhưng GHI TỆP (undo != none);
        //   `board.check_pins` — R0 và không ghi gì, nhưng thiếu tham số bắt buộc;
        //   `target.flash`     — R3, và vướng cả ba.
        let c = try moClient()
        for id in ["req.trace_matrix", "board.check_pins", "target.flash"] {
            let hd = try await c.goi(.capsDescribe, ["id": id])
            guard case .cho = EidePanel.tuChay(hopDong: hd, id: id, coThamSo: false) else {
                return XCTFail("\(id) KHÔNG được tự chạy lúc mở màn nhưng quy tắc cho phép")
            }
        }
    }
}
