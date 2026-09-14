import AppKit
import XCTest
@testable import EIDEKit

/// Ba màn ưu tiên 1 của USECASE §4 — chủ sản phẩm duyệt 15/09/2026.
///
/// UC-B2/B3 (làm rõ yêu cầu), UC-C9 (xung đột tri thức), UC-F7 (chi phí từ sổ cái).
///
/// Câu hỏi của bộ này vẫn là câu hỏi người dùng cuối: *tôi có hiểu mình đang đồng ý với cái gì
/// không · tôi có đủ thông tin để chọn một bên không · tiền đi đâu*. Và mỗi màn đều phải chịu
/// được dữ liệu thật: một dự án có hàng trăm xung đột, hàng nghìn lượt gọi mô hình.
final class EideUuTien1Tests: XCTestCase {

    // MARK: - UC-B2/B3 · Làm rõ yêu cầu

    @MainActor
    func testNOIlaiCACHhieuVAchuoiSEchay() {
        // Một câu "tôi hiểu là anh muốn đọc cảm biến" không nói cho ai biết rằng nó sắp tải
        // 35 MB tài liệu và ghi 8.000 fact. Chuỗi bước là thứ người dùng thật sự đồng ý với.
        let v = LamRoView()
        v.capNhat(ketQua: [
            "text": "Tôi hiểu là: đọc BME280 qua I2C trên ESP32-C3, in ra UART.",
            "chain": [["cap": "search.vendor"], ["cap": "extract.svd"], ["cap": "kg.build"]],
        ])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("Tôi hiểu là"), chu)
        XCTAssertTrue(chu.contains("search.vendor → extract.svd → kg.build"), chu)
        XCTAssertTrue(chu.contains("3 bước"), chu)
    }

    @MainActor
    func testCHUAnoiLAIthiCHUAcoNUTdongY() {
        // Người không thể đồng ý với một thứ chưa được nói thành câu. Chỉ có `intent` thô thì
        // hiện nó ra, và nói rõ đang chờ `chat.restate`.
        let v = LamRoView()
        v.capNhat(ketQua: ["intent": ["name": "doc_cam_bien", "chip": "esp32c3"]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("chưa nói lại"), chu)
        XCTAssertFalse(chu.contains("Đúng — làm đi"), "chưa có câu hiểu mà đã mời đồng ý")
    }

    @MainActor
    func testSUAYHIEUnapLAIcauGOCchuKHONGxoaTRANG() {
        // Người dùng sửa MỘT CHỮ trong câu của mình, không gõ lại từ đầu.
        let v = LamRoView()
        var nhan: String?
        v.onSuaYHieu = { nhan = $0 }
        v.capNhat(ketQua: ["text": "tôi hiểu là…", "source_text": "đọc BME280 trên ESP32-C3"])
        v.bamSuaDeTest()
        XCTAssertEqual(nhan, "đọc BME280 trên ESP32-C3")
    }

    @MainActor
    func testCAUHOIgopHIENduPHUONGanVAmacDINH() {
        // `chat.clarify` trả câu hỏi GỘP có phương án và mặc định. Một bong bóng chat không đặt
        // được bốn lựa chọn; màn này phải đặt được.
        let v = LamRoView()
        v.capNhat(ketQua: ["question": [
            "text": "Vài chỗ cần anh chốt:",
            "gaps": [
                ["key": "baud", "question": "Tốc độ UART?", "options": ["9600", "115200"],
                 "default": "115200"],
                ["key": "sim_truoc", "question": "Chạy mô phỏng trước khi nạp?",
                 "options": ["có", "không"], "default": "có"],
                ["key": "ghi_chu", "question": "Ghi chú thêm?"],
            ],
        ]])
        XCTAssertEqual(v.soOTraLoi, 3)
        XCTAssertTrue(_chu(v).contains("Tốc độ UART?"), _chu(v))
    }

    @MainActor
    func testMACDINHkhongCOtrongDANHsachTHIkhongCHONbua() {
        // Chọn bừa mục đầu rồi gọi đó là mặc định là bịa ra một lựa chọn hợp đồng không nói.
        let v = LamRoView()
        v.capNhat(ketQua: ["question": ["gaps": [
            ["key": "x", "question": "Chọn?", "options": ["a", "b"], "default": "z"],
        ]]])
        let dap = v.dapDeTest()
        XCTAssertEqual(dap["x"], "a", "NSPopUpButton luôn có mục đang chọn — nhưng mặc định 'z' "
                       + "không được coi là người đã chọn")
    }

    @MainActor
    func testHETGIOkhacHANvoiNGUOItraLOI() {
        // "Hết giờ lấy mặc định" và "người chọn" là hai chuyện rất khác nhau khi truy lại sau.
        let v = LamRoView()
        v.capNhat(ketQua: ["question": ["text": "x"], "answer": ["baud": "115200"],
                           "by": "timeout"])
        XCTAssertTrue(_chu(v).contains("hết giờ"), _chu(v))

        let v2 = LamRoView()
        v2.capNhat(ketQua: ["question": ["text": "x"], "answer": ["baud": "9600"], "by": "human"])
        XCTAssertTrue(_chu(v2).contains("người trả lời"), _chu(v2))
    }

    @MainActor
    func testKHONGcoGIcanLAMroTHInoiRAviecTIEPtheo() {
        let v = LamRoView()
        v.capNhat(ketQua: [:])
        XCTAssertTrue(_chu(v).contains("ô lệnh"), "màn rỗng phải nói việc tiếp theo: \(_chu(v))")
    }

    // MARK: - UC-C9 · Xung đột tri thức

    private func _xungDot(_ n: Int) -> [String: Any] {
        ["conflicts": (0..<n).map { i in
            ["id": "c\(i)", "type": "fact", "detail": "chip:x/periph:I2C\(i)/base_address",
             "nodes": [
                ["id": "f_a\(i)", "value": "0x40005400", "source_id": "src_svd",
                 "tier": "gold", "confidence": 1.0],
                ["id": "f_b\(i)", "value": "0x40005800", "source_id": "src_pdf",
                 "tier": "silver", "confidence": 0.72, "locator": "tr.412"],
             ]] as [String: Any]
        }, "resource_ready": true]
    }

    @MainActor
    func testHAIbenHIENcungNGUONvaTANG() {
        // Người chọn giữa 0x40005400 và 0x40005800 mà không biết cái nào từ SVD hãng, cái nào
        // từ một bảng PDF quét, thì họ đang tung đồng xu.
        let v = XungDotView()
        v.capNhat(ketQua: _xungDot(1))
        let chu = _chu(v)
        for phai in ["0x40005400", "0x40005800", "src_svd", "src_pdf", "gold", "silver", "tr.412"] {
            XCTAssertTrue(chu.contains(phai), "thiếu \(phai) — người chọn mà không có căn cứ")
        }
    }

    @MainActor
    func testCHONmotBENgoiDUNGthamSO() {
        let v = XungDotView()
        var goi: (String, String, String?)?
        v.onChon = { goi = ($0, $1, $2) }
        v.capNhat(ketQua: _xungDot(1))
        v.bamChonDeTest(id: "c0", ben: "a")
        XCTAssertEqual(goi?.0, "c0")
        XCTAssertEqual(goi?.1, "a")
        XCTAssertNil(goi?.2)
    }

    @MainActor
    func testKHONGcoXUNGdotTHInoiRAlaDAkiem() {
        let v = XungDotView()
        v.capNhat(ketQua: ["conflicts": [], "resource_ready": true])
        XCTAssertTrue(_chu(v).contains("Không có xung đột"), _chu(v))
    }

    @MainActor
    func testCHUAkiemDUOCtaiNGUYENthiPHAInoiRA() {
        // "0 xung đột" khi chưa kiểm được là câu nói dối nguy hiểm nhất màn này có thể nói.
        let v = XungDotView()
        v.capNhat(ketQua: ["conflicts": [], "resource_ready": false])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("TÀI NGUYÊN"), chu)
        XCTAssertTrue(chu.contains("hộ chiếu mạch"), chu)
    }

    @MainActor
    func testXUNGdotCHIcoMOTbenTHIkhongCHOchon() {
        // Một xung đột chỉ có một nút thì không có gì để chọn giữa — nút phải tắt, không phải
        // gửi một lời gọi `choice: "b"` trỏ vào hư không.
        let v = XungDotView()
        v.capNhat(ketQua: ["conflicts": [["id": "c1", "nodes": [["id": "f_a", "value": "1"]]]]])
        XCTAssertEqual(v.soXungDot, 1)
        XCTAssertFalse(v.nutChonBatDeTest(), "chỉ một bên mà nút Chọn vẫn bấm được")
    }

    @MainActor
    func testTRAM_XUNGDOTvanDUNGduoc() {
        // Một lô `extract.pdf_*` trên một chip lớn có thể sinh hàng trăm xung đột.
        let v = XungDotView()
        v.capNhat(ketQua: _xungDot(300))
        XCTAssertEqual(v.soXungDot, 300)
    }

    @MainActor
    func testNODEdangIDtranKHONGlamNOhong() {
        // `nodes` có thể là id trần thay vì object — hợp đồng KG-02 chỉ nói `nodes[]`.
        let v = XungDotView()
        v.capNhat(ketQua: ["conflicts": [["id": "c1", "nodes": ["f_a", "f_b"]]]])
        XCTAssertEqual(v.soXungDot, 1)
    }

    // MARK: - UC-F7 · Chi phí từ sổ cái

    private func _goiMoHinh(_ n: Int, vai: [String] = ["librarian", "coder", "planner"])
        -> [String: Any] {
        ["events": (0..<n).map { i in
            ["kind": "model.call", "at": "2026-09-15T08:00:00+00:00", "by": "agent",
             "data": ["role": vai[i % vai.count], "model": "m",
                      "tokens_in": 100 + i, "tokens_out": 20,
                      "cost_usd": 0.001, "ms": 500]] as [String: Any]
        }]
    }

    @MainActor
    func testGOMtheoVAItroVAsapTHEOchiPHI() {
        // Người mở màn này muốn biết TIỀN ĐI ĐÂU — vai trò tốn nhất phải nằm dòng đầu.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [
            ["kind": "model.call", "data": ["role": "re", "tokens_in": 10, "cost_usd": 0.01]],
            ["kind": "model.call", "data": ["role": "coder", "tokens_in": 10, "cost_usd": 0.50]],
            ["kind": "model.call", "data": ["role": "coder", "tokens_in": 10, "cost_usd": 0.50]],
        ]])
        let chu = _chu(v)
        guard let iCoder = chu.range(of: "coder"), let iRe = chu.range(of: "re ") ?? chu.range(of: "\nre") else {
            return XCTAssertTrue(chu.contains("coder"), chu)
        }
        XCTAssertTrue(iCoder.lowerBound < iRe.lowerBound, "vai trò tốn nhất phải lên đầu: \(chu)")
    }

    @MainActor
    func testKHONGcoGIAthiNOIRAchuKHONGhienKHONGdong() {
        // Hiện "0,0000 USD" là khẳng định nó miễn phí.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [
            ["kind": "model.call", "data": ["role": "coder", "tokens_in": 900, "tokens_out": 80]],
        ]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("không trả") || chu.contains("cục bộ"), chu)
        XCTAssertTrue(chu.contains("900"), "số token vẫn phải đúng: \(chu)")
    }

    @MainActor
    func testCHUAgoiMOHINHlanNAOkhacVOIchuaDOCduocSOcai() {
        // Hai tình huống, hai câu — gộp lại là bắt người dùng tự đoán.
        let a = ModelsView()
        a.capNhat(ketQua: ["events": []])
        let b = ModelsView()
        b.capNhat(ketQua: [:])
        XCTAssertNotEqual(_chu(a), _chu(b))
        XCTAssertTrue(_chu(b).contains("sổ cái"), _chu(b))
    }

    @MainActor
    func testKHONGhienNOIdungPROMPT() {
        // Sổ cái đã che khoá API, nhưng che khoá khác với không đưa mã nguồn người dùng ra một
        // cửa sổ có thể đang chia sẻ màn hình.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [
            ["kind": "model.call", "data": ["role": "coder", "tokens_in": 10,
                                            "prompt": "MÃ NGUỒN RIÊNG CỦA NGƯỜI DÙNG"]],
        ]])
        XCTAssertFalse(_chu(v).contains("MÃ NGUỒN RIÊNG"), _chu(v))
    }

    @MainActor
    func testNGHIN_LUOTgoiVANgomDUOC() {
        let v = ModelsView()
        v.capNhat(ketQua: _goiMoHinh(3_000))
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("3000 lượt"), chu)
        // Gom theo vai trò nên số DÒNG không tăng theo số lượt — đó là cả điểm của việc gom.
        XCTAssertLessThan(v.soDong, 20, "3.000 lượt gọi không được thành 3.000 dòng")
    }

    @MainActor
    func testSUKIENkhacMODELcallBIloBO() {
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [
            ["kind": "cap.run.start", "data": ["cap": "kg.build"]],
            ["kind": "store.write", "data": ["table": "fact"]],
        ]])
        XCTAssertTrue(_chu(v).contains("Chưa có lượt gọi"), _chu(v))
    }

    // MARK: - tiện ích

    @MainActor
    private func _chu(_ m: ManHinhCoSo) -> String {
        func quet(_ v: NSView) -> [String] {
            var ra: [String] = []
            if let t = v as? NSTextField { ra.append(t.stringValue) }
            if let b = v as? NSButton { ra.append(b.title) }
            for c in v.subviews { ra += quet(c) }
            return ra
        }
        return ([m.tomTat.stringValue] + quet(m.cot)).joined(separator: "\n")
    }
}
