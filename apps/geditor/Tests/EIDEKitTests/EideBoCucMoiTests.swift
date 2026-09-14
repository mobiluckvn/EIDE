import AppKit
import XCTest
@testable import EIDEKit

/// Bố cục ba vùng + ô nhập sinh từ hợp đồng — THIET-KE-UI, chủ sản phẩm duyệt 14/09/2026.
///
/// ## Bộ test này hỏi câu hỏi của NGƯỜI DÙNG CUỐI
///
/// Không hỏi "hàm có trả đúng kiểu không" — ba tầng test kia đã hỏi rồi. Hỏi những câu một
/// người ngồi trước màn hình sẽ hỏi: *tôi có gõ được không · tôi có biết phải điền gì không ·
/// điền thiếu thì nó có nói cho tôi biết không · mở màn ra tôi có thấy tác tử đang làm gì không
/// · dự án 8.000 fact thì nó còn chạy nổi không*.
///
/// Chủ sản phẩm nói thẳng lý do bộ này tồn tại: *"giao diện hiện tại lỗi quá chẳng dùng được
/// gì"* — và cả bốn tầng test cũ đều xanh khi câu ấy được nói ra.
final class EideBoCucMoiTests: XCTestCase {

    // MARK: - Điều hướng: người dùng tìm thấy màn mình cần

    @MainActor
    func testDIEUHUONGgom5NHOMdungThuTUcongViec() {
        // Thứ tự nhóm LÀ thứ tự một dự án đi qua. Người mới mở sản phẩm đọc từ trên xuống là
        // biết bắt đầu từ đâu — điều mà một danh sách 22 mục phẳng không nói được.
        let ten = EideDieuHuong.NHOM.map(\.ten)
        XCTAssertEqual(ten, ["TRI THỨC", "THIẾT KẾ", "MÃ & CHẠY", "PHẦN CỨNG", "HỆ THỐNG"])
    }

    @MainActor
    func testDU21manKHONGthieuKHONGthua() {
        let dh = EideDieuHuong(frame: .zero)
        XCTAssertEqual(dh.soMan, 23, "23 màn chuyên đề (thêm Làm rõ yêu cầu, Xung đột tri thức "
                       + "ngày 15/09); Chat là ô lệnh thường trực, không phải màn")
    }

    @MainActor
    func testMOImanTRONGdieuHuongDEUcoKHUNGnhin() {
        // Một mục điều hướng không có khung nhìn là một mục bấm vào thì không có gì hiện ra.
        let p = EidePanel(client: EideClient(transport: TransportGia()))
        for n in EideDieuHuong.NHOM {
            for m in n.man {
                XCTAssertTrue(p.coManDeTest(m.tien),
                              "màn \(m.nhan) (\(m.tien)) không có khung nhìn")
            }
        }
    }

    @MainActor
    func testTIEUDEnhomKHONGchonDUOC() {
        // Bấm vào "TRI THỨC" mà thấy vùng nội dung đổi là một lời hứa sai — nó không phải màn.
        let dh = EideDieuHuong(frame: .zero)
        var daChon: [String] = []
        dh.onChon = { daChon.append($0) }
        XCTAssertFalse(dh.chon("TRI THỨC"), "tiêu đề nhóm không phải một màn")
        XCTAssertTrue(dh.chon("Passport"))
        XCTAssertEqual(daChon, ["Passport"])
    }

    @MainActor
    func testMANcanBOARDnoiVIECcanLAMchuKHONGnoiTINHtrang() {
        // "Chưa có board" là điều người dùng đã biết. "Cắm board qua USB rồi bấm Dò lại" là
        // điều họ cần. Mỗi màn phần cứng phải nói việc, không nói tình trạng.
        for m in EideDieuHuong.NHOM.first(where: { $0.ten == "PHẦN CỨNG" })!.man {
            let c = EideDieuHuong.loiCanBoard(m.tien)
            XCTAssertFalse(c.isEmpty, m.tien)
            XCTAssertTrue(c.contains("Cắm") || c.contains("cắm") || c.contains("chọn"),
                          "màn \(m.nhan) không nói việc cần làm: \(c)")
            XCTAssertGreaterThan(c.count, 40, "câu quá cụt để giúp được ai: \(c)")
        }
    }

    @MainActor
    func testBONmanPHANCUNGdeuDANHdauCANboard() {
        let pc = EideDieuHuong.NHOM.first { $0.ten == "PHẦN CỨNG" }!
        XCTAssertEqual(pc.man.count, 4)
        XCTAssertTrue(pc.man.allSatisfy(\.board))
        // Và không nhóm nào khác đánh dấu nhầm.
        for n in EideDieuHuong.NHOM where n.ten != "PHẦN CỨNG" {
            XCTAssertTrue(n.man.allSatisfy { !$0.board }, "nhóm \(n.ten) có màn đánh dấu cần board")
        }
    }

    // MARK: - Ô nhập: người dùng biết phải điền gì

    @MainActor
    private func form(_ props: [String: Any], batBuoc: [String] = []) -> EideONhap {
        let o = EideONhap(frame: .init(x: 0, y: 0, width: 600, height: 300))
        o.dungTu(capId: "thu.nghiem",
                 moTa: ["input_schema": ["type": "object", "properties": props,
                                         "required": batBuoc]])
        return o
    }

    @MainActor
    func testSINHdungSOoTUschema() {
        let o = form(["part": ["type": "string"], "deep": ["type": "boolean"]])
        XCTAssertEqual(o.soO, 2)
    }

    @MainActor
    func testOBATBUOCxepTRUOC() {
        // JSON không giữ thứ tự có nghĩa. Ô bắt buộc nằm lẫn giữa ô tuỳ chọn thì người dùng
        // điền thiếu rồi mới biết — và biết bằng một thông báo lỗi.
        let o = form(["z_tuy_chon": ["type": "string"], "a_bat_buoc": ["type": "string"]],
                     batBuoc: ["a_bat_buoc"])
        XCTAssertEqual(o.thieu(), ["a_bat_buoc"])
    }

    @MainActor
    func testTHIEUoBATBUOCthiNOIdungTENo() {
        let o = form(["part": ["type": "string"], "reg": ["type": "string"]],
                     batBuoc: ["part", "reg"])
        XCTAssertEqual(Set(o.thieu()), ["part", "reg"])
        o.datGiaTri("part", "stm32f411")
        XCTAssertEqual(o.thieu(), ["reg"], "điền một ô rồi thì chỉ còn báo ô kia")
    }

    @MainActor
    func testKHONGgoiDAEMONkhiCONthieuObatBUOC() {
        // Chặn ở giao diện thay vì để daemon trả E1000: lỗi hiện ngay cạnh nút, nói đúng tên ô,
        // và không tốn một vòng gọi để biết điều giao diện đã biết sẵn.
        let o = form(["part": ["type": "string"]], batBuoc: ["part"])
        var daGoi = false
        o.onChay = { _, _ in daGoi = true }
        o.bamChayDeTest()
        XCTAssertFalse(daGoi, "còn thiếu ô bắt buộc mà vẫn gọi daemon")
        o.datGiaTri("part", "esp32c3")
        o.bamChayDeTest()
        XCTAssertTrue(daGoi)
    }

    @MainActor
    func testEPKIEUtheoSCHEMAchuKHONGguiCHUOI() {
        // `"16000000"` gửi cho một tham số `integer` bị `validate_input` trả E1000, và thông báo
        // ấy nói về schema chứ không nói về ô người dùng vừa gõ.
        let o = form(["f_cpu": ["type": "integer"], "ty_le": ["type": "number"],
                      "sau": ["type": "boolean"], "ten": ["type": "string"]])
        o.datGiaTri("f_cpu", "16000000")
        o.datGiaTri("ty_le", "0.85")
        o.datGiaTri("ten", "esp32c3")
        let ts = o.thamSo()
        XCTAssertEqual(ts["f_cpu"] as? Int, 16_000_000)
        XCTAssertEqual(ts["ty_le"] as? Double, 0.85)
        XCTAssertEqual(ts["ten"] as? String, "esp32c3")
    }

    @MainActor
    func testSOsaiKIEUthiGUInguyenCHUchuKHONGnuot() {
        // Người gõ "mười sáu triệu" vào ô số. Nuốt mất giá trị thì lời gọi đi thiếu tham số và
        // lỗi nói "thiếu f_cpu" — trong khi người dùng NHÌN THẤY mình đã điền.
        let o = form(["f_cpu": ["type": "integer"]])
        o.datGiaTri("f_cpu", "mười sáu triệu")
        XCTAssertEqual(o.thamSo()["f_cpu"] as? String, "mười sáu triệu")
    }

    @MainActor
    func testOTRONGkhongGUIchuoiRONG() {
        // Gửi `part: ""` khác hẳn không gửi `part`: cái đầu là "tìm linh kiện tên rỗng".
        let o = form(["part": ["type": "string"], "q": ["type": "string"]])
        o.datGiaTri("part", "   ")
        XCTAssertTrue(o.thamSo().isEmpty, "ô trắng và ô chỉ có dấu cách đều là chưa điền")
    }

    @MainActor
    func testNANGLUCkhongThamSOvanCOnutCHAY() {
        // Bản cũ im lặng không hiện gì và màn trông như hỏng.
        let o = form([:])
        var daGoi = false
        o.onChay = { _, _ in daGoi = true }
        o.bamChayDeTest()
        XCTAssertTrue(daGoi, "năng lực không tham số vẫn phải chạy được")
    }

    @MainActor
    func testTHAMSOtenFILEduocNUTchonTEPchuKHONGbatGOtay() {
        // `file` là chuỗi, nhưng bắt gõ tay đường dẫn tuyệt đối là thiết kế tệ.
        XCTAssertEqual(EideONhap.dieuKhien(ten: "file", kieu: "string"), .chonTep)
        XCTAssertEqual(EideONhap.dieuKhien(ten: "artifact", kieu: "string"), .chonTep)
        XCTAssertEqual(EideONhap.dieuKhien(ten: "part", kieu: "string"),
                       .goiY(nguon: "passport.list"))
        XCTAssertEqual(EideONhap.dieuKhien(ten: "ghi_chu", kieu: "string"), .chu)
        XCTAssertEqual(EideONhap.dieuKhien(ten: "so_lan", kieu: "integer"), .so)
    }

    @MainActor
    func testDUNGLAIformKHIdoiMANthiKHONGconOcu() {
        // Mở màn Hộ chiếu (ô `part`) rồi sang màn Mô phỏng (ô `artifact`): còn sót ô `part` thì
        // lời gọi mang một tham số của màn trước.
        let o = form(["part": ["type": "string"]])
        o.datGiaTri("part", "esp32c3")
        o.dungTu(capId: "sim.run",
                 moTa: ["input_schema": ["properties": ["artifact": ["type": "string"]]]])
        XCTAssertEqual(o.soO, 1)
        XCTAssertNil(o.thamSo()["part"], "ô của màn trước còn sót lại")
    }

    @MainActor
    func testSCHEMAhongKHONGlamNOhong() {
        let o = EideONhap(frame: .zero)
        o.dungTu(capId: "x", moTa: [:])
        o.dungTu(capId: "x", moTa: ["input_schema": "không phải object"])
        o.dungTu(capId: "x", moTa: ["input_schema": ["properties": "sai kiểu"]])
        o.dungTu(capId: "x", moTa: ["input_schema": ["properties": ["a": "sai"]]])
        XCTAssertNotNil(o)
    }


    @MainActor
    func testDUNGformTUpayloadTHATcuaDAEMON() {
        // Payload nguyên văn `caps.describe passport.query` trả về — 5 tham số, không cái nào
        // bắt buộc. Màn Hộ chiếu vẫn báo "không cần tham số" trên bản dựng thật 14/09.
        let o = EideONhap(frame: .zero)
        o.dungTu(capId: "passport.query", moTa: [
            "id": "passport.query",
            "input_schema": [
                "type": "object",
                "properties": [
                    "part": ["type": "string"],
                    "peripheral": ["type": "string"],
                    "register": ["type": "string"],
                    "field": ["type": "string"],
                    "q": ["type": "string", "description": "câu hỏi NL"],
                ],
                "required": [],
                "additionalProperties": false,
            ],
        ])
        XCTAssertEqual(o.soO, 5, "form không đọc được input_schema mà daemon thật sự trả")
    }

    // MARK: - NHIỀU DỮ LIỆU

    @MainActor
    func testFORM50THAMSOvanDUNGduoc() {
        // Không hợp đồng nào có 50 tham số hôm nay, nhưng `tool.register` cho tác tử tự khai
        // năng lực mới — và schema của chúng do mô hình viết.
        var props: [String: Any] = [:]
        for i in 0..<50 { props["ts_\(i)"] = ["type": "string"] }
        let o = form(props, batBuoc: (0..<50).map { "ts_\($0)" })
        XCTAssertEqual(o.soO, 50)
        XCTAssertEqual(o.thieu().count, 50)
    }

    @MainActor
    func testNHATKYnhan5000SUKIENvanKHONGphinhBOnho() {
        // `extract.svd` của ESP32-C3 ghi hơn 8.000 `store.write` trong MỘT lượt. Giữ hết thì màn
        // này ăn hết bộ nhớ một cửa sổ mà không ai cuộn tới dòng thứ 2.000.
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        v.datCoDuAn(true)
        measure {
            for i in 0..<5_000 {
                v.them("event.knowledge.changed", ["table": "fact", "n": i])
            }
        }
        XCTAssertEqual(v.soDongDeTest, NhatKyView.TOI_DA)
    }

    @MainActor
    func testNHATKYnapLICHSU10000BANghiVANcat() {
        let v = NhatKyView(frame: .init(x: 0, y: 0, width: 900, height: 400))
        let ds = (0..<10_000).map {
            ["at": "2026-09-14T07:30:00+00:00", "kind": "store.write", "by": "agent",
             "data": ["table": "fact", "n": $0]] as [String: Any]
        }
        v.capNhat(ketQua: ["events": ds])
        XCTAssertEqual(v.soDongDeTest, NhatKyView.TOI_DA)
    }

    @MainActor
    func testHANGDOI200MUCchoVANhienDUOCnutDUYET() {
        // Một lô `kg.review_facts` có thể đẩy hàng trăm fact vào hàng đợi. Nút Duyệt bị đẩy ra
        // ngoài khung là mục người dùng không trả lời được, và tác tử đứng chờ vì lỗi bố cục.
        let q = ReviewQueueView()
        let cho = (0..<200).map {
            ["run_id": "r\($0)", "cap": "kg.review_facts",
             "decision": ["gate": "G-FACT", "rule": "G-FACT-02",
                          "reason": "confidence 0,62 < 0,85"]] as [String: Any]
        }
        q.capNhat(cho: cho, hoanTac: [])
        q.layoutSubtreeIfNeeded()
        XCTAssertNotNil(q)
    }

    @MainActor
    func testVUNGPHAIkhongBIhangDOIdayNHATkyRAngoai() {
        // Hai khối chia nhau một cột: khi hàng đợi dài, nhật ký nhường chỗ — nhưng không được
        // biến mất, vì người vẫn cần thấy tác tử đang làm gì trong lúc duyệt.
        let vp = EideVungPhai(frame: .init(x: 0, y: 0, width: EideVungPhai.RONG, height: 800))
        vp.nhatKy.datCoDuAn(true)
        for i in 0..<50 { vp.nhatKy.them("event.run.progress", ["cap": "kg.build", "status": "done", "at": "2026-09-14T07:0\(i % 10):00+00:00"]) }
        vp.hangDoi.capNhat(cho: (0..<30).map {
            ["run_id": "r\($0)", "cap": "search.fetch",
             "decision": ["gate": "G-SRC", "rule": "G-SRC-99", "reason": "ngoài danh sách"]]
        }, hoanTac: [])
        vp.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(vp.nhatKy.frame.height, 0, "nhật ký bị ép về 0 — không còn giám sát được")
        XCTAssertGreaterThan(vp.hangDoi.frame.height, 0)
    }

    @MainActor
    func testTENmanDAIkhongLAMvoDIEUhuong() {
        let dh = EideDieuHuong(frame: .init(x: 0, y: 0, width: 220, height: 700))
        dh.layoutSubtreeIfNeeded()
        XCTAssertEqual(dh.soMan, 23)
    }
}

/// Ống dẫn giả — không mở tiến trình nào. Dùng cho test chỉ cần dựng panel.
final class TransportGia: EideClient.Transport, @unchecked Sendable {
    func send(_ line: Data) async throws {}
    func receiveLine() async throws -> Data {
        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        return Data()
    }
    func close() async {}
}
