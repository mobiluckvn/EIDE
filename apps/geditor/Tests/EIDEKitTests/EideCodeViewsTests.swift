import AppKit
import XCTest

@testable import EIDEKit

/// Bốn màn mã & kế hoạch — UXD-13 màn 9, 11, 12, 13.
///
/// Bốn màn nơi máy ĐỀ XUẤT và người DUYỆT. Thứ test giữ ở đây: **một lý do từ chối không được
/// đọc nhẹ hơn nó thật sự là.** `verdict: block`, `sufficient: false`, `unverified` — cả ba đều
/// là những chữ dễ trôi qua mắt nếu giao diện hiện chúng như một dòng bình thường.
final class EideCodeViewsTests: XCTestCase {

    // MARK: - Màn 9: Lược đồ

    func testANHveXONGvanNOIRAloiLINTcuaNo() {
        // `diagram.render` trả cả `path` lẫn `lint[]`. Một lược đồ có nút mồ côi vẫn render ra
        // ảnh hoàn toàn bình thường, rồi ảnh ấy được chèn vào tài liệu và đọc như mô tả đúng
        // của hệ thống.
        let v = DiagramView()
        v.capNhat(ketQua: [
            "path": "docs/hinh/kien-truc.svg",
            "lint": [
                ["severity": "error", "line": 12, "message": "nút `imu` không có cạnh nào"],
                ["severity": "warning", "line": 3, "message": "tên nút trùng"],
            ],
        ])
        XCTAssertEqual(v.soLoi, 2)
        XCTAssertEqual(v.duongDanAnh, "docs/hinh/kien-truc.svg")
        XCTAssertTrue(v.tomTat.stringValue.contains("2 lỗi"), v.tomTat.stringValue)
    }

    func testLINTdungTENkhoaCUAcaHAInangLuc() {
        // `render` gọi danh sách là `lint`, `lint` gọi nó là `issues`. Màn phải nhận cả hai.
        let a = DiagramView()
        a.capNhat(ketQua: ["issues": [["severity": "error", "line": 1, "message": "x"]]])
        XCTAssertEqual(a.soLoi, 1)
    }

    func testDIAGRAMsyncCHUAapDungThiNOIRA() {
        let v = DiagramView()
        v.capNhat(ketQua: ["diff": ["added": ["case A"]], "applied": false])
        XCTAssertFalse(v.daApDung)
        XCTAssertTrue(v.tomTat.stringValue.contains("CHƯA áp dụng"), v.tomTat.stringValue)
    }

    // MARK: - Màn 11: Kế hoạch

    func testKEHOACHthieuTRIthucDAYmissingLENdauMAN() {
        // Duyệt một kế hoạch thiếu tri thức ở cổng G1 là duyệt một việc đã biết trước sẽ phải
        // làm lại. `missing[]` phải đọc được TRƯỚC các bước.
        let v = PlanDiffView()
        v.capNhat(ketQua: [
            "sufficient": false,
            "missing": [
                ["what": "địa chỉ I2C của BME280", "how": "extract.pdf_register_map"],
                ["what": "tần số thạch anh", "how": "hỏi người"],
            ],
            "plan": ["steps": [["title": "cấu hình I2C1", "capability": "code.generate_module",
                                "citations": ["f_1"]]]],
        ])
        XCTAssertEqual(v.duTriThuc, false)
        XCTAssertEqual(v.soThieu, 2)
        XCTAssertTrue(v.tomTat.stringValue.contains("THIẾU TRI THỨC"), v.tomTat.stringValue)

        let dau = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSTextField)?.stringValue }.first
        XCTAssertEqual(dau, "còn thiếu: địa chỉ I2C của BME280")
    }

    func testCHUAchayPLANsufficiencyKHACvoiCHAYraFALSE() {
        // `nil` = chưa chạy, `false` = đã chạy và thiếu. Gộp hai cái là nói dối một nửa.
        let v = PlanDiffView()
        v.capNhat(ketQua: ["plan": ["steps": []]])
        XCTAssertNil(v.duTriThuc)
        XCTAssertFalse(v.tomTat.stringValue.contains("THIẾU TRI THỨC"))
    }

    func testBUOCkhongTRICHDANduocNOIra() {
        // PLAN-03 đòi kế hoạch có trích dẫn fact. Một bước không trích dẫn gì là một bước dựa
        // trên phỏng đoán của mô hình — cùng loại vấn đề với `RagAskView`.
        let v = PlanDiffView()
        v.capNhat(ketQua: ["plan": ["steps": [
            ["title": "đặt PLL 84 MHz", "capability": "code.modify"],
        ]]])
        XCTAssertEqual(v.soBuoc, 1)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("KHÔNG trích dẫn"), chu)
    }

    func testMERGEkhongKEMhanHOANTACthiNOIRAlaKHONGro() {
        // `code.merge` trả `undo_until`; sau mốc ấy `undo.apply` cho E7000. Một giao diện chỉ
        // nói "đã merge" để người dùng tin rằng họ còn rút lại được mãi mãi.
        let co = PlanDiffView()
        co.capNhat(ketQua: ["commit": "a91f3d2", "branch": "auto/f-06",
                            "undo_until": "2026-09-13T12:40:00Z"])
        let chuCo = co.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chuCo.contains("2026-09-13T12:40:00Z"), chuCo)

        let khong = PlanDiffView()
        khong.capNhat(ketQua: ["commit": "a91f3d2", "branch": "auto/f-06"])
        let chu = khong.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("không rõ hạn"), chu)
    }

    func testVONGPHUthuocLENtieuDe() {
        let v = PlanDiffView()
        v.capNhat(ketQua: ["order": ["clock", "gpio"], "cycles": [["i2c", "dma", "i2c"]]])
        XCTAssertEqual(v.soChuTrinh, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("VÒNG PHỤ THUỘC"), v.tomTat.stringValue)
    }

    // MARK: - Màn 12: Mã nguồn — bất biến trung tâm của luận điểm đề án

    func testCONSTANTguardBLOCKdocRAlaCHANchuKhongPhaiCANHbao() {
        // Một `block` hiện ra như một dòng vàng giữa mười dòng khác sẽ được bấm qua, và bấm
        // qua nó một lần là đủ để một địa chỉ thanh ghi mô hình đoán ra đi vào firmware.
        let v = CodeView()
        v.capNhat(ketQua: [
            "verdict": "block",
            "violations": [
                ["file": "src/drv_bme280.c", "line": 42, "literal": "0x76",
                 "reason": "không fact nào khớp giá trị này"],
            ],
        ])
        XCTAssertTrue(v.biChan)
        XCTAssertEqual(v.soViPham, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("CHẶN"), v.tomTat.stringValue)
        XCTAssertEqual(v.tomTat.textColor, EideToken.Mau.bad)
    }

    func testCONSTANTguardPASSkhongDoaNGUOI() {
        let v = CodeView()
        v.capNhat(ketQua: ["verdict": "pass", "violations": []])
        XCTAssertFalse(v.biChan)
        XCTAssertEqual(v.tomTat.textColor, EideToken.Mau.muted)
    }

    func testBONHOsapHETchoCANHbaoTRUOCkhiVuot() {
        // 97% không phải lỗi nên không có gì báo, nhưng nó là lần dựng cuối cùng còn thành công
        // — và người phát hiện ra điều đó lúc thêm tính năng sau thì đã mất một buổi.
        let v = CodeView()
        v.capNhat(ketQua: ["report": [
            "tool": "size", "passed": true,
            "metrics": ["flash_pct": 97, "ram_pct": 41, "text": 49152],
        ]])
        XCTAssertEqual(v.dungDuoc, true)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("sắp hết chỗ"), chu)
    }

    func testNGUONGboNhoLA085() {
        XCTAssertEqual(CodeView.nguongChatBoNho, 0.85)
    }

    func testTUsuaBOcuocNOIRA() {
        // `code.self_repair` có `give_up` — ba vòng không sửa nổi. Hiện một `patch` rỗng mà
        // không nói vì sao thì người tưởng năng lực hỏng.
        let v = CodeView()
        v.capNhat(ketQua: ["patch": ["files": []], "give_up": true])
        XCTAssertTrue(v.tomTat.stringValue.contains("BỎ CUỘC"), v.tomTat.stringValue)
    }

    // MARK: - Màn 13: Mô phỏng — ba trạng thái, không phải hai

    func testUNVERIFIEDkhongGOPvaoFAILED() {
        // `failed` = firmware sai → đi sửa mã. `unverified` = engine không nhìn thấy được →
        // đi đổi engine. Gộp chúng là đẩy người dùng đi sửa một đoạn mã không có lỗi.
        let v = SimView()
        v.capNhat(ketQua: ["report": [
            "tool": "sim.run", "passed": false, "duration_ms": 2400,
            "metrics": [
                "engine": "qemu-system-avr",
                "n_passed": 1, "n_unverified": 2,
                "expect": [
                    ["expect": "uart: HKW ready", "status": "passed"],
                    ["expect": "gpio PB3 lên mức cao", "status": "unverified",
                     "reason": "engine không có kênh GPIO"],
                    ["expect": "biến pid_out trong khoảng", "status": "unverified",
                     "reason": "không đọc được biến"],
                ],
            ],
        ]])
        XCTAssertEqual(v.soKyVong, 3)
        XCTAssertEqual(v.soDat, 1)
        XCTAssertEqual(v.soChuaKiem, 2)
        XCTAssertTrue(v.tomTat.stringValue.contains("KHÔNG QUAN SÁT ĐƯỢC"), v.tomTat.stringValue)

        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " ")
        XCTAssertTrue(chu.contains("KHÔNG phải lỗi firmware"), chu)
    }

    func testDUNGSOdemCUAloiCHUKhongTUdemLai() {
        // Hai chỗ đếm là hai chỗ có thể lệch nhau, và chỗ lệch nằm ở đúng cái quyết định
        // firmware có được nạp lên board hay không (`sim_first`).
        let v = SimView()
        v.capNhat(ketQua: ["report": [
            "passed": false,
            "metrics": ["n_passed": 5, "n_unverified": 1,
                        "expect": [["expect": "a", "status": "passed"]]],
        ]])
        XCTAssertEqual(v.soDat, 5, "phải lấy n_passed của lõi, không đếm lại theo expect[]")
        XCTAssertEqual(v.soChuaKiem, 1)
    }

    func testDUNGVIhetGIOlaMOTphanCUAketQua() {
        // Một kịch bản bị cắt giữa chừng có thể "đạt" mọi dòng đã chấm mà chưa nói được gì về
        // phần sau.
        let v = SimView()
        v.capNhat(ketQua: ["report": [
            "passed": false,
            "metrics": ["terminated_by": "timeout", "n_passed": 2, "n_unverified": 0,
                        "expect": [["expect": "a", "status": "passed"]]],
        ]])
        XCTAssertTrue(v.tomTat.stringValue.contains("DỪNG VÌ HẾT GIỜ"), v.tomTat.stringValue)
    }

    func testQUETthamSOhienHANGtotNHAT() {
        let v = SimView()
        v.capNhat(ketQua: [
            "table": [["kp": 1.0, "overshoot": 12.0], ["kp": 2.0, "overshoot": 4.0]],
            "best": ["kp": 2.0, "overshoot": 4.0],
        ])
        XCTAssertEqual(v.soDong, 3)   // 2 hàng + 1 dòng "tốt nhất"
    }

    // MARK: - Chung

    func testBONmanRONGdeuNOIRAlyDo() {
        for m in [DiagramView() as ManHinhCoSo, PlanDiffView(), CodeView(), SimView()] {
            m.capNhat(ketQua: [:])
            let chu = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            XCTAssertFalse(chu.joined().isEmpty, "\(type(of: m)) để trống khi rỗng")
            XCTAssertEqual(m.accessibilityRole(), .group)
        }
    }
}
