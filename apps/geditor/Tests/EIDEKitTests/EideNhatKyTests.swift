import XCTest
@testable import EIDEKit

/// `NhatKyView` — màn trả lời câu "tác tử vừa làm gì" (GIAM-SAT-UI §G7).
///
/// Phần lớn bài ở đây kiểm `dich()`, vì đó là chỗ dễ sai nhất của cả màn: nó phải đọc payload
/// của hơn mười loại sự kiện, mỗi loại một hình dạng, và mỗi chỗ đọc sai là một dòng nói sai về
/// một việc đã xảy ra. Một dòng nhật ký sai còn tệ hơn không có dòng nào — người ta tin nó.
final class EideNhatKyTests: XCTestCase {

    // MARK: - dịch sự kiện

    func testNangLucBatDauVaKetThucLaHAIdongKHACnhau() {
        // `cap.run.start` không mang `status`; `finish` thì có. Gộp hai cái thành một dòng làm
        // mất đúng thông tin người giám sát cần: việc đang chạy hay đã xong.
        let bd = NhatKyView.dich("event.run.progress",
                                 ["cap": "extract.atdf", "at": "2026-09-14T07:30:00+00:00"])
        XCTAssertEqual(bd?.nhan, "extract.atdf")
        XCTAssertEqual(bd?.chiTiet, "bắt đầu")

        let kt = NhatKyView.dich("event.run.progress",
                                 ["cap": "extract.atdf", "status": "done",
                                  "at": "2026-09-14T07:30:05+00:00"])
        XCTAssertEqual(kt?.chiTiet, "xong")
        XCTAssertEqual(kt?.mau, EideToken.Mau.ok)
    }

    func testNangLucHONGthiNOIRAmaLOI() {
        // "failed" một mình không giúp được gì. Mã lỗi là thứ tra được trong API-15 §3.
        let d = NhatKyView.dich("event.run.progress",
                                ["cap": "sim.build_platform", "status": "failed",
                                 "error": "E2000"])
        XCTAssertEqual(d?.chiTiet, "failed · E2000")
        XCTAssertEqual(d?.mau, EideToken.Mau.bad)
    }

    func testMaLOIdangDOITUONGcungDOCduoc() {
        // Router trả `error` là chuỗi ở chỗ này và là đối tượng ở chỗ khác. Đọc được cả hai chứ
        // không im lặng bỏ một dạng — im lặng ở đây nghĩa là mất mã lỗi trên dòng thời gian.
        let d = NhatKyView.dich("event.run.progress",
                                ["cap": "x", "status": "failed",
                                 "error": ["eide_code": "E4001", "message": "thiếu công cụ"]])
        XCTAssertEqual(d?.chiTiet, "failed · E4001")
    }

    func testCONGtuDUYETvanLENdongThoiGian() {
        // Khoảng trống #6 của GIAM-SAT-UI: ở mức tự chủ cao, thứ cần giám sát nhất chính là
        // những gì tác tử TỰ duyệt. Trước 14/09 chúng bị bỏ hẳn.
        let d = NhatKyView.dich("event.gate.decided",
                                ["decision": "APPROVE", "rule": "G-SRC-01",
                                 "reason": "Nguồn hãng tin cậy", "action_cap": "search.fetch"])
        XCTAssertEqual(d?.loai, "cổng")
        XCTAssertTrue(d?.nhan.contains("APPROVE") ?? false)
        XCTAssertTrue(d?.nhan.contains("G-SRC-01") ?? false)
        XCTAssertEqual(d?.capId, "search.fetch", "bấm vào phải mở được màn của năng lực ấy")
    }

    func testCONGtuTUCHOIthiMauDO() {
        let d = NhatKyView.dich("event.gate.decided",
                                ["decision": "REJECT", "rule": "G-WL-02"])
        XCTAssertEqual(d?.mau, EideToken.Mau.bad)
    }

    func testMUCCHOnguoiDUYETkhacHANvoiViecMayTUlam() {
        let cho = NhatKyView.dich("event.gate.opened",
                                  ["rule": "G-SRC-99", "reason": "Nguồn ngoài danh sách"])
        XCTAssertEqual(cho?.mau, EideToken.Mau.warn)
        XCTAssertTrue(cho?.nhan.contains("CHỜ NGƯỜI") ?? false)
    }

    func testCHIPHImoHinhHIENsoTOKENvaTIEN() {
        let d = NhatKyView.dich("event.model.call",
                                ["role": "librarian", "tokens_in": 1200, "tokens_out": 340,
                                 "cost_usd": 0.0123])
        XCTAssertEqual(d?.nhan, "librarian")
        XCTAssertTrue(d?.chiTiet.contains("1200 vào") ?? false)
        XCTAssertTrue(d?.chiTiet.contains("340 ra") ?? false)
        XCTAssertTrue(d?.chiTiet.contains("$0.0123") ?? false, d?.chiTiet ?? "")
    }

    func testCHIPHIkhongCOgiaThiKHONGbiaSO() {
        // Không phải lượt gọi nào cũng biết giá (mô hình chạy cục bộ, hoặc gateway không trả).
        // Hiện "$0.0000" là khẳng định nó miễn phí.
        let d = NhatKyView.dich("event.model.call", ["role": "coder", "tokens_in": 10])
        XCTAssertFalse(d?.chiTiet.contains("$") ?? true, d?.chiTiet ?? "")
    }

    func testCONGCUngoaiNOIdatHAYhong() {
        let dat = NhatKyView.dich("event.tool.report",
                                  ["tool": "build", "passed": true, "duration_ms": 5550])
        XCTAssertEqual(dat?.chiTiet, "đạt · 5550 ms")
        XCTAssertEqual(dat?.mau, EideToken.Mau.ok)

        let hong = NhatKyView.dich("event.tool.report", ["tool": "sim.run", "passed": false])
        XCTAssertEqual(hong?.chiTiet, "hỏng")
        XCTAssertEqual(hong?.mau, EideToken.Mau.bad)
    }

    func testTHIEUpassedTHIkhongCOInhaDAT() {
        // `passed` vắng mặt nghĩa là chưa biết. Mặc định "đạt" ở đây là nói dối về một lượt chạy
        // công cụ — đúng loại khẳng định mà cả sản phẩm sinh ra để chống.
        let d = NhatKyView.dich("event.tool.report", ["tool": "size"])
        XCTAssertEqual(d?.chiTiet, "hỏng")
        XCTAssertNotEqual(d?.mau, EideToken.Mau.ok)
    }

    func testLEOTHANGnoiRObangCHU_HOA() {
        // `policy.escalate` nghĩa là tác tử đang DỪNG CHỜ người. Một dòng lẫn vào đám thông báo
        // thường thì người giám sát lướt qua, và tác tử đứng im chờ mãi.
        let d = NhatKyView.dich("event.notice",
                                ["kind": "policy.escalate", "level": "warn",
                                 "text": "cùng một hành động hỏng 2 lần"])
        XCTAssertEqual(d?.loai, "leo thang")
        XCTAssertEqual(d?.nhan, "TÁC TỬ CẦN NGƯỜI")
    }

    func testNGUOIduyetDUOCdanhDAUlaNGUOI() {
        // Dòng do người quyết là dòng duy nhất trên màn mà ai đó đã đọc và đồng ý. Trộn chúng
        // vào việc máy tự làm là xoá mất ranh giới của cả APD-08.
        let d = NhatKyView.dich("event.queue.changed",
                                ["kind": "gate.human", "decision": "APPROVE",
                                 "note": "SPDX Apache-2.0", "actor": "human"])
        XCTAssertEqual(d?.boi, "người")
        XCTAssertTrue(d?.nhan.contains("duyệt") ?? false)
        XCTAssertEqual(d?.chiTiet, "SPDX Apache-2.0", "ghi chú của người phải hiện, không nuốt")
    }

    func testQUEUEchangedKHONGphaiGATEhumanTHIkhongTAOdong() {
        // `event.queue.changed` còn đến từ chỗ khác (`_dong_bo_cho`). Dựng một dòng "người
        // duyệt" cho nó là bịa ra một hành động người chưa làm.
        XCTAssertNil(NhatKyView.dich("event.queue.changed",
                                     ["kind": "queue", "added": ["r1"]]))
    }

    func testTRITHUCgomTHEObangVaSO() {
        // `store.write` là sự kiện ồn nhất: một lượt `extract.svd` ghi hơn 8.000 dòng.
        let d = NhatKyView.dich("event.knowledge.changed", ["table": "fact", "n": 287])
        XCTAssertEqual(d?.nhan, "fact")
        XCTAssertEqual(d?.chiTiet, "287 bản ghi")
    }

    func testYDINHhienCHUOInangLucSAPchay() {
        // A2 của bảng: hôm nay người không biết tác tử sắp làm gì cho tới lúc nó làm xong.
        let d = NhatKyView.dich("event.chat.intent",
                                ["text": "tạo dự án cho ESP32-C3",
                                 "caps": ["project.create", "search.vendor", "extract.svd"]])
        XCTAssertEqual(d?.loai, "ý định")
        XCTAssertEqual(d?.chiTiet, "project.create → search.vendor → extract.svd")
    }

    func testSUKIENlaKHONGbietTHIbỏQUAchuKHONGnổ() {
        XCTAssertNil(NhatKyView.dich("event.serial.line", ["line": "x"]))
        XCTAssertNil(NhatKyView.dich("event.khong-co-that", [:]))
    }

    func testPAYLOADrongKHONGlamNOhong() {
        // Một daemon cũ hơn, một sự kiện thiếu trường — không lý do nào đáng để màn giám sát
        // chết giữa lúc đang giám sát.
        for ten in ["event.run.progress", "event.gate.decided", "event.model.call",
                    "event.tool.report", "event.knowledge.changed", "event.notice",
                    "event.undo.registered", "event.project.changed", "event.chat.intent"] {
            _ = NhatKyView.dich(ten, [:])   // không được nổ
        }
    }

    func testKIEUSAIkhongLamNOhong() {
        // JSON từ daemon không có kiểu tĩnh: một `tokens_in` là chuỗi, một `passed` là số.
        let d = NhatKyView.dich("event.model.call",
                                ["role": 42, "tokens_in": "một nghìn", "cost_usd": "rẻ"])
        XCTAssertNotNil(d, "kiểu sai vẫn phải cho ra một dòng, không được nuốt cả sự kiện")
        XCTAssertFalse(d?.chiTiet.contains("$") ?? true)
    }

    // MARK: - giờ

    func testGIOdoiVEgioMAYchuKHONGgiuUTC() {
        // Sổ cái ghi UTC vì nó là bằng chứng; người đọc màn này đang ngồi trước máy.
        let g = NhatKyView.gioPhut("2026-09-14T07:42:06.162717+00:00")
        XCTAssertEqual(g.count, 8, g)
        XCTAssertEqual(g.filter { $0 == ":" }.count, 2, g)
    }

    func testGIOkhongCOphanGIAYvanDOCduoc() {
        // `datetime.now(UTC).isoformat()` bỏ phần giây lẻ khi nó bằng 0 — có thật trong sổ cái.
        XCTAssertEqual(NhatKyView.gioPhut("2026-09-14T07:42:06+00:00").count, 8)
    }

    func testGIOhongTHIkhongNOvaVANhienDUOCgiDO() {
        XCTAssertFalse(NhatKyView.gioPhut("không phải ngày").isEmpty
                       || NhatKyView.gioPhut("").isEmpty == false && false)
        _ = NhatKyView.gioPhut("")
    }

    // MARK: - màn

    @MainActor
    func testBAtrangThaiRONGkhacNHAU() {
        // Gộp ba câu thành "không có gì" là để người dùng tự đoán — đúng thứ lỗi im lặng số 21
        // đã mắc ở tầng UI.
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        let chuaDuAn = v.tomTatText
        XCTAssertTrue(chuaDuAn.contains("Chưa mở dự án"), chuaDuAn)

        v.datCoDuAn(true)
        let coDuAn = v.tomTatText
        XCTAssertTrue(coDuAn.contains("chưa có việc nào"), coDuAn)
        XCTAssertNotEqual(chuaDuAn, coDuAn, "hai tình huống khác nhau phải nói khác nhau")
    }

    @MainActor
    func testBOLOCgiauHETthiNOIRAchuKHONGgiaVOrong() {
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.datCoDuAn(true)
        v.them("event.model.call", ["role": "librarian", "tokens_in": 10])
        v.chonNhomDeTest("Công cụ")     // nhóm không có dòng nào
        let t = v.tomTatText
        XCTAssertTrue(t.contains("bộ lọc"), t)
        XCTAssertTrue(t.contains("1"), "phải nói vẫn còn bao nhiêu việc trong sổ: \(t)")
    }

    @MainActor
    func testCATbotDONGcuKHIvuotNGUONG() {
        // `extract.svd` của ESP32-C3 ghi hơn 8.000 `store.write` trong một lượt.
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.datCoDuAn(true)
        for i in 0..<(NhatKyView.TOI_DA + 50) {
            v.them("event.knowledge.changed", ["table": "fact", "n": i])
        }
        XCTAssertEqual(v.soDongDeTest, NhatKyView.TOI_DA)
        XCTAssertTrue(v.tomTatText.contains("\(NhatKyView.TOI_DA)"), v.tomTatText)
    }

    @MainActor
    func testDEMriengViecDOnguoiQUYET() {
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.datCoDuAn(true)
        v.them("event.run.progress", ["cap": "kg.build", "status": "done"])
        v.them("event.queue.changed", ["kind": "gate.human", "decision": "APPROVE",
                                       "actor": "human"])
        XCTAssertTrue(v.tomTatText.contains("1 do người quyết"), v.tomTatText)
    }
}

// MARK: - nạp lịch sử qua view.timeline

extension EideNhatKyTests {

    @MainActor
    func testNAPlichSUtuVIEWtimeline() {
        // Lịch sử đi bằng đường HỎI-ĐÁP. Kênh đẩy chỉ mang sự kiện thời gian thực: một khối 200
        // bản ghi đẩy qua stdio làm đầy ống 64 KB và treo daemon — đo được trên dự án ESP32-C3
        // (82 KB). Triệu chứng: cửa sổ mở lên rồi đứng im, không lỗi.
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.capNhat(ketQua: ["events": [
            ["at": "2026-09-14T07:30:00+00:00", "kind": "cap.run.start", "by": "agent",
             "data": ["cap": "extract.atdf", "run_id": "r1"]],
            ["at": "2026-09-14T07:30:05+00:00", "kind": "tool.report", "by": "agent",
             "data": ["tool": "build", "passed": true, "duration_ms": 5550]],
        ]])
        XCTAssertEqual(v.soDongDeTest, 2)
        XCTAssertTrue(v.tomTatText.contains("2 việc"), v.tomTatText)
    }

    @MainActor
    func testKETQUAkhongCOeventsTHIkhongXOAdongDANGdoc() {
        // `_napLaiManDangMo` có thể gọi nhầm năng lực khác. Im lặng xoá dòng thời gian khi ấy
        // là xoá đúng thứ người đang đọc — và không có gì nói cho họ biết vì sao nó biến mất.
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.datCoDuAn(true)
        v.them("event.tool.report", ["tool": "build", "passed": true])
        XCTAssertEqual(v.soDongDeTest, 1)
        v.capNhat(ketQua: ["facts": []])          // kết quả của một năng lực khác
        XCTAssertEqual(v.soDongDeTest, 1, "không có `events` thì đừng đụng vào dòng thời gian")
    }

    @MainActor
    func testLICHSUdaiHONnguongTHIcatBOT() {
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        let ds = (0..<(NhatKyView.TOI_DA + 100)).map {
            ["at": "2026-09-14T07:30:00+00:00", "kind": "store.write", "by": "agent",
             "data": ["table": "fact", "n": $0]] as [String: Any]
        }
        v.capNhat(ketQua: ["events": ds])
        XCTAssertEqual(v.soDongDeTest, NhatKyView.TOI_DA)
    }

    @MainActor
    func testBANghiHONGtrongLICHSUkhongLAMdungCAloat() {
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.capNhat(ketQua: ["events": [
            ["khong-co-kind": true],
            ["kind": "cap.run.start", "data": ["cap": "a"]],
            "không phải từ điển",
            ["kind": "kieu-la-hoac", "data": [:]],
            ["kind": "tool.report", "data": ["tool": "size", "passed": true]],
        ]])
        XCTAssertGreaterThanOrEqual(v.soDongDeTest, 2, "bản ghi hỏng không được nuốt cả lô")
    }

    func testBANGanhXAkhopVOIsuKIENdaemonPHATra() throws {
        // `tenSuKien` là bản sao của `SU_KIEN` trong `rpc.py`, và bản sao thì trôi. Bài test
        // đọc THẲNG `rpc.py` để bắt lúc trôi — đường còn lại (bắt `view.timeline` trả tên sự
        // kiện) là bắt một năng lực biết về giao thức của giao diện.
        let f = EideE2ETests.gocKho.appendingPathComponent("src/eide/daemon/rpc.py")
        let src = try String(contentsOf: f, encoding: .utf8)
        guard let r = src.range(of: "SU_KIEN: dict\\[str, str\\] = \\{[^}]*\\}",
                                options: String.CompareOptions.regularExpression) else {
            return XCTFail("không tìm thấy SU_KIEN trong rpc.py")
        }
        var lech: [String] = []
        for dong in src[r].split(separator: "\n") {
            let phan = dong.split(separator: "\"").map(String.init)
            guard phan.count >= 4 else { continue }
            let kind = phan[1], ev = phan[3]
            guard kind.contains("."), ev.hasPrefix("event.") else { continue }
            let cua_ui = NhatKyView.tenSuKien(kind)
            // `gate.decision` cố ý lệch: daemon phát `event.gate.opened` khi ASK và
            // `event.gate.decided` khi không, còn lịch sử thì luôn là chuyện đã quyết xong.
            if kind == "gate.decision" {
                XCTAssertEqual(cua_ui, "event.gate.decided")
                continue
            }
            if cua_ui != ev { lech.append("\(kind): UI=\(cua_ui) ≠ daemon=\(ev)") }
        }
        XCTAssertTrue(lech.isEmpty, "bảng ánh xạ đã trôi khỏi rpc.py: \(lech)")
    }
}

// MARK: - mở màn từ sidebar

final class EideMoManTuSidebarTests: XCTestCase {

    func testMOImanTUsidebarDUNGnapMacDinh() throws {
        // Đo 14/09/2026 trên bản dựng thật: bấm mục 22 "Nhật ký hoạt động" trên sidebar thì màn
        // mở ra với tiêu đề đúng, thân trống, và câu "Màn NhatKy chưa có nguồn dữ liệu" — sai lý
        // do, vì `napMacDinh` CÓ năng lực cho nó (`view.timeline`).
        //
        // Gốc rễ: `napMacDinh` thêm từ 13/09 (lỗi im lặng số 21) nhưng chỉ chạy ở đường
        // `_napLaiManDangMo`, tức chỉ khi một sự kiện `knowledge.changed` tới. Mở bằng tay thì
        // không ai gọi nó — hai đường vào cùng một màn, chỉ một đường nạp dữ liệu.
        //
        // Kiểm bằng cách đọc mã nguồn: thứ cần giữ là `_moTheoTenMan` có hỏi `napMacDinh`, và
        // không có cách nào quan sát điều ấy từ ngoài mà không dựng cả một daemon.
        let f = EideE2ETests.gocKho
            .appendingPathComponent("apps/geditor/Sources/EIDEKit/EidePanel.swift")
        let src = try String(contentsOf: f, encoding: .utf8)
        guard let ham = src.range(of: "private func _moTheoTenMan(") else {
            return XCTFail("không tìm thấy `_moTheoTenMan`")
        }
        let than = src[ham.lowerBound...].prefix(2000)
        XCTAssertTrue(than.contains("napMacDinh"),
                      "mở màn từ sidebar không hỏi `napMacDinh` — 20 màn sẽ rỗng")
        guard let goiNap = than.range(of: "napMacDinh"),
              let goiKhac = than.range(of: "_napManKhongNangLuc") else {
            return XCTFail("thiếu một trong hai nhánh nạp")
        }
        XCTAssertTrue(goiNap.lowerBound < goiKhac.lowerBound,
                      "`napMacDinh` phải được hỏi TRƯỚC, vì nó phủ nhiều màn hơn")
    }

    func testMOImanTRONGsidebarDEUcoDUONGnapHOACcoLYdo() throws {
        // Mọi màn trên sidebar phải rơi vào đúng một trong ba: có năng lực trong `napMacDinh`,
        // nằm trong hai màn nạp bằng phương thức daemon, hoặc có mặt trong `noUI` với lý do.
        // Không thuộc nhóm nào nghĩa là mở ra sẽ trống mà không ai biết vì sao.
        let f = EideE2ETests.gocKho
            .appendingPathComponent("apps/geditor/Sources/EIDEKit/EidePanel.swift")
        let src = try String(contentsOf: f, encoding: .utf8)
        let batBangPhuongThuc: Set<String> = ["FlowMap", "Models"]

        var thieu: [String] = []
        // Duyệt `EideDieuHuong.NHOM` — bảng màn DUY NHẤT từ 15/09/2026. Trước đó bài này đọc
        // `EideWindowController.manTrenSidebar`, một bản sao thứ ba của cùng danh sách: thêm một
        // màn vào điều hướng mà quên bản sao ấy thì bài này vẫn xanh trong khi màn mới không
        // được kiểm gì.
        for m in EideDieuHuong.NHOM.flatMap(\.man) where m.tien != "Chat" {
            if EidePanel.napMacDinh(choMan: m.tien) != nil { continue }
            if batBangPhuongThuc.contains(m.tien) { continue }
            // Màn còn lại phải ít nhất được nhắc tới trong mã với một câu giải thích — dấu hiệu
            // ai đó đã cân nhắc, không phải bỏ quên.
            if src.contains("\"\(m.tien)\"") { continue }
            thieu.append(m.tien)
        }
        XCTAssertTrue(thieu.isEmpty,
                      "màn trên sidebar không có đường nạp và cũng không được nhắc tới: \(thieu)")
    }
}
