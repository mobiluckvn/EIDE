import AppKit
import XCTest

@testable import EIDEKit

/// Bốn màn bàn làm việc — UXD-13 màn 2, 4, 6, 8.
///
/// Mỗi màn ở đây có một thứ **không được phép trôi qua trong im lặng**, và đó là thứ test kiểm:
/// chi phí hôm nay (màn 2), tệp phân loại yếu (màn 4), bảng chân chưa kiểm (màn 6), yêu cầu
/// không đo được và ngân sách không xếp nổi lịch (màn 8).
final class EideWorkbenchViewsTests: XCTestCase {

    // MARK: - Màn 2: Tổng quan

    func testCHIPHIhienCaKhiBangKHONG() {
        // Một con số chi phí chỉ xuất hiện lúc nó đã lớn là con số người dùng gặp lần đầu vào
        // đúng lúc muộn nhất.
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": ["features": [], "gates_open": [], "cost_today": 0]])
        XCTAssertEqual(v.chiPhiHomNay, 0)
        XCTAssertTrue(v.tomTat.stringValue.contains("0.00 USD"), v.tomTat.stringValue)
    }

    func testDEMdungTinhNangFAILINGvaCONGdangMo() {
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": [
            "features": [
                ["id": "F-01", "name": "Clock 84 MHz", "status": "passing", "evidence": "log#a91f"],
                ["id": "F-06", "name": "BME280 qua I2C1", "status": "failing", "gate": "G3 diff #23"],
                ["id": "F-07", "name": "PID 200 Hz", "status": "failing"],
            ],
            "gates_open": [["gate": "G3", "reason": "diff #23"]],
            "undo_items": [["undo_ref": "u_1"]],
            "cost_today": 0.42,
            "autonomy": "A3",
            "target": ["chip_id": "st.stm32f411", "port": "/dev/cu.usbmodem", "lab": true],
        ]])
        XCTAssertEqual(v.soTinhNang, 3)
        XCTAssertEqual(v.soFailing, 2)
        XCTAssertEqual(v.soCongMo, 1)
        XCTAssertEqual(v.chiPhiHomNay, 0.42, accuracy: 0.001)
        XCTAssertEqual(v.soDong, 5)   // 1 đích + 3 tính năng + 1 cổng
    }

    func testNHANlabHIENraVInoLAmotQUYEN() {
        // BOARD-05: board đánh dấu lab mới được tự nạp. Đó là một quyền, và một quyền thì phải
        // nhìn thấy được — không nằm im trong một trường boolean.
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": [
            "features": [], "gates_open": [], "cost_today": 0,
            "target": ["chip_id": "st.stm32f411", "lab": true],
        ]])
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("LAB"), chu)
    }

    // MARK: - Màn 4: Nhập tài liệu

    func testTEPphanLoaiYEUduocDAYlenDAUvaTOdo() {
        // Một datasheet bị đọc nhầm thành "văn bản ngữ cảnh" thì 42 fact thanh ghi không bao
        // giờ ra đời — và không có gì báo lỗi, vì không có gì hỏng.
        let v = IngestView()
        v.capNhat(ketQua: ["classification": [
            ["file": "sdk/STM32F411.svd", "kind": "CMSIS-SVD", "tier": "gold",
             "extractor": "extract.svd", "confidence": 0.99],
            ["file": "docs/scan_mo.pdf", "kind": "?", "tier": "bronze",
             "extractor": "", "confidence": 0.31],
        ]])
        XCTAssertEqual(v.soTep, 2)
        XCTAssertEqual(v.soThapTin, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("CHƯA CHẮC"), v.tomTat.stringValue)
    }

    func testNGUONGtinCayGIONGdpS09() {
        // Hai ngưỡng tin cậy khác nhau cho cùng một ý là sản phẩm không giải thích được.
        XCTAssertEqual(IngestView.nguongTin, 0.6)
    }

    func testTEPTRUNGhashNOIraDAcoOdau() {
        let v = IngestView()
        v.capNhat(ketQua: [
            "new": ["a.pdf"],
            "dup": [["file": "b.pdf", "source_id": "src_9"]],
        ])
        XCTAssertEqual(v.soTrung, 1)
        XCTAssertEqual(v.soDong, 1)
    }

    // MARK: - Màn 6: Hộ chiếu mạch — bất biến đắt nhất của đợt này

    func testBANGchanCHUAkiemNOIRAlaCHUAkiem() {
        // `diagram.pinmap` vẽ được bảng chân mà không cần `board.check_pins` chạy trước. Một
        // bảng trông sạch sẽ đọc y như một bảng đã qua kiểm tra — và người ta hàn theo nó.
        let v = BoardView()
        v.capNhat(ketQua: ["table": [
            ["net": "I2C1_SCL", "pin": "PB6", "function": "I2C1_SCL (AF4)"],
            ["net": "LED_STATUS", "pin": "PB3", "function": "GPIO out"],
        ]])
        XCTAssertFalse(v.daKiemChan)
        XCTAssertEqual(v.soChan, 2)
        XCTAssertTrue(v.tomTat.stringValue.contains("CHƯA KIỂM CHÂN"), v.tomTat.stringValue)
    }

    func testCHAYcheckPinsROIthiNOIso0XungDot() {
        // `conflicts: []` là một câu khẳng định ("đã kiểm, sạch"), khác hẳn với việc vắng mặt.
        let v = BoardView()
        v.capNhat(ketQua: ["conflicts": [], "table": [["net": "I2C1_SCL", "pin": "PB6"]]])
        XCTAssertTrue(v.daKiemChan)
        XCTAssertEqual(v.soXungDot, 0)
        XCTAssertTrue(v.tomTat.stringValue.contains("0 xung đột"), v.tomTat.stringValue)
    }

    func testXUNGDOTnangLenDAUdanhSach() {
        let v = BoardView()
        v.capNhat(ketQua: ["conflicts": [
            ["pin": "PA8", "kind": "af", "detail": "nhẹ", "severity": "info"],
            ["pin": "PB3", "kind": "overlap", "detail": "PB3 = SPI1_MOSI đang dùng",
             "severity": "error"],
        ]])
        XCTAssertEqual(v.soXungDot, 2)
        let nhan = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSButton)?.title }
        XCTAssertEqual(nhan.first, "PB3", "xung đột nặng phải lên trước: \(nhan)")
    }

    func testNUTsuaCHANmangTHEOcaObjectXungDot() {
        // BOARD-04 đòi `conflict` là object; trả mỗi tên chân rồi để panel dựng lại là dựng một
        // thứ gần giống bản gốc — "gần giống" ở một đề xuất sửa mạch thì không đủ.
        let v = BoardView()
        var nhan: [String: Any]?
        v.onXemChan = { nhan = $0 }
        v.capNhat(ketQua: ["conflicts": [
            ["pin": "PB3", "kind": "overlap", "detail": "đè SPI1_MOSI", "severity": "error"],
        ]])
        let nut = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { $0 as? NSButton }.first
        XCTAssertNotNil(nut)
        nut?.performClick(nil)
        XCTAssertEqual(nhan?["kind"] as? String, "overlap")
        XCTAssertEqual(nhan?["detail"] as? String, "đè SPI1_MOSI")
    }

    // MARK: - Màn 8: Yêu cầu & kiến trúc

    func testYEUCAUkhongDOduocHIENnhuMOTvanDe() {
        // "phản ứng nhanh" đọc lên nghe như một yêu cầu hoàn chỉnh, và nó sẽ đi thẳng qua kiến
        // trúc, qua mã, tới tận lúc nghiệm thu mới có người hỏi "nhanh là bao nhiêu?".
        let v = ReqArchView()
        v.capNhat(ketQua: ["issues": [
            ["kind": "unmeasurable", "req_ids": ["FR-CTL-02"], "text": "phản ứng nhanh",
             "suggestion": "thời gian ổn định ≤ 1,5 s sau nhiễu 5°"],
        ]])
        XCTAssertEqual(v.soKhongDoDuoc, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("CHƯA ĐO ĐƯỢC"), v.tomTat.stringValue)
    }

    func testLICHkhongXEPduocLENtieuDe() {
        // Kết luận lớn nhất `arch.*` đưa ra được — "kiến trúc này không chạy nổi trên con chip
        // này" — nằm trong một trường boolean dễ trôi qua mắt.
        let v = ReqArchView()
        v.capNhat(ketQua: ["budget": [
            "tasks": [["name": "pid", "period": 1000.0, "wcet_est": 400.0, "prio": 3]],
            "utilization": 1.4,
            "schedulable": false,
        ]])
        XCTAssertFalse(v.nganSachDat)
        XCTAssertTrue(v.tomTat.stringValue.contains("KHÔNG XẾP ĐƯỢC LỊCH"), v.tomTat.stringValue)
    }

    func testVUOTnganSachRAMcungLENtieuDe() {
        let v = ReqArchView()
        v.capNhat(ketQua: ["budget": ["ok": false, "drv_bme280": ["ram": 512, "flash": 4096]]])
        XCTAssertFalse(v.nganSachDat)
        XCTAssertTrue(v.tomTat.stringValue.contains("VƯỢT NGÂN SÁCH"), v.tomTat.stringValue)
    }

    func testYEUCAUchuaNEOphanCungNOIRA() {
        // REQ-03: không neo được vào một fact phần cứng có thật thì nó là mong muốn, chưa là
        // yêu cầu.
        let v = ReqArchView()
        v.capNhat(ketQua: ["reqset": [
            ["id": "FR-SNS-01", "kind": "FR", "text": "đọc IMU 1 kHz", "grounded": "f_5a1c"],
            ["id": "NFR-PWR-01", "kind": "NFR", "text": "chạy ≥ 30 phút"],
        ], "codes_assigned": 2])
        XCTAssertEqual(v.soYeuCau, 2)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("chưa neo phần cứng"), chu)
    }

    // MARK: - Quy tắc chung của lớp cơ sở

    func testMOImanRONGdeuNOIRAlyDO_khongDeTrong() {
        // U9. Đặt vào lớp cơ sở thì quên là chuyện phải cố tình — nhưng vẫn kiểm, vì lớp con
        // có thể `return` sớm trước khi gọi `noiRong`.
        let man: [ManHinhCoSo] = [ProjectStatusView(), IngestView(), BoardView(), ReqArchView()]
        for m in man {
            m.capNhat(ketQua: [:])
            let chu = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            XCTAssertFalse(chu.isEmpty, "\(type(of: m)) để trống khi rỗng")
            XCTAssertFalse(chu.joined().isEmpty, "\(type(of: m)) hiện chuỗi rỗng")
        }
    }

    func testMOImanDEUcoNhanTroNang() {
        for m in [ProjectStatusView() as ManHinhCoSo, IngestView(), BoardView(), ReqArchView()] {
            XCTAssertEqual(m.accessibilityRole(), .group)
            XCTAssertFalse((m.accessibilityLabel() ?? "").isEmpty)
        }
    }

    func testTHANGmucNGHIEMtrongDUNGchungMOTbangMau() {
        // Năm năng lực khác nhau (`board.check_pins`, `arch.review`, `code.static`,
        // `diagram.lint`, `sim.*`) cùng một thang. Mỗi màn tự dịch thì màu thôi có nghĩa.
        XCTAssertEqual(EideMuc.mau("error"), EideToken.Mau.bad)
        XCTAssertEqual(EideMuc.mau("warning"), EideToken.Mau.warn)
        XCTAssertEqual(EideMuc.mau("info"), EideToken.Mau.info)
        XCTAssertLessThan(EideMuc.diem("critical"), EideMuc.diem("warning"))
        XCTAssertLessThan(EideMuc.diem("error"), EideMuc.diem("info"))
    }
}
