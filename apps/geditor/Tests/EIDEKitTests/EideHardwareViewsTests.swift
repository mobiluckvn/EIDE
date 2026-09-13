import AppKit
import XCTest

@testable import EIDEKit

/// Bốn màn phần cứng & gỡ lỗi — UXD-13 màn 14, 15, 16, 18.
///
/// Ba trong bốn màn này gọi năng lực CHƯA hiện thực (`discover.*` 0/12, `target.*` 0/9,
/// `bench.*` 0/3 — chờ board). Nên bài test đầu tiên của nhóm không kiểm dữ liệu mà kiểm **câu
/// nói lúc rỗng**: "chưa có dữ liệu" và "năng lực chưa hiện thực" dẫn người dùng đi hai việc
/// khác hẳn nhau, và đoán nhầm nghĩa là đi cắm lại một sợi cáp vẫn tốt.
final class EideHardwareViewsTests: XCTestCase {

    private func chuTrongThan(_ m: ManHinhCoSo) -> String {
        let nhan = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
        let hang = m.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }
        let chu = hang.compactMap { ($0 as? NSTextField)?.stringValue }
        let nut = hang.compactMap { ($0 as? NSButton)?.title }
        return (nhan + chu + nut).joined(separator: " ")
    }

    // MARK: - Trạng thái rỗng phải nói ĐÚNG lý do

    func testMANcanBOARDnoiRaLAchuaHIENTHUCchuKhongNoiChuaCoDuLieu() {
        for m in [DiscoveryView() as ManHinhCoSo, BenchView()] {
            m.capNhat(ketQua: [:])
            let chu = chuTrongThan(m)
            XCTAssertTrue(chu.contains("chưa hiện thực"),
                          "\(type(of: m)) phải nói rõ năng lực chưa có: \(chu)")
            XCTAssertTrue(chu.contains("board"), "\(type(of: m)) phải nói lý do là board: \(chu)")
        }
    }

    func testMANchayDUOCkhongBOARDkhongDOthuaLaCANboard() {
        // `debug.log_stats` và `debug.hypothesize` chạy được ngay hôm nay. Nói chúng cần board
        // là đuổi người dùng đi tìm phần cứng cho một việc làm được trên máy của họ.
        let v = LogAssistView()
        v.capNhat(ketQua: [:])
        let chu = chuTrongThan(v)
        XCTAssertTrue(chu.contains("debug.log_stats"), chu)
    }

    // MARK: - Màn 14: Dò board

    func testDRIVERchuaNAPkhacHANvoiKHONGthayCONGnao() {
        // Ba tình huống, ba việc khác nhau. Gộp thành "không tìm thấy board" là để người dùng
        // đi rút ra cắm lại một sợi cáp vẫn tốt.
        let v = DiscoveryView()
        v.capNhat(ketQua: ["ports": [
            ["dev": "/dev/cu.usbmodem14203", "product": "STM32 STLink", "driver_ok": true],
            ["dev": "/dev/cu.usbserial-A5", "product": "CP2102", "driver_ok": false],
        ]])
        XCTAssertEqual(v.soCong, 2)
        XCTAssertEqual(v.soDriverHong, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("THIẾU DRIVER"), v.tomTat.stringValue)
        XCTAssertTrue(chuTrongThan(v).contains("cài driver"), chuTrongThan(v))
    }

    func testNHANdienCHIPtinCayTHAPcanhBAOdungNAPfirmware() {
        // Nạp firmware theo một phỏng đoán về con chip là cách làm hỏng chip.
        let v = DiscoveryView()
        v.capNhat(ketQua: ["identity": [
            "method": "IDCODE", "raw": "0x0BB11477",
            "passport_match": "st.stm32f411", "confidence": 0.42,
        ]])
        XCTAssertEqual(v.tinChip ?? 0, 0.42, accuracy: 0.001)
        XCTAssertTrue(chuTrongThan(v).contains("Đừng nạp firmware"), chuTrongThan(v))
    }

    func testDONGHOlechCANHbao() {
        // Tần số đo lệch tần số cấu hình là nguyên nhân kinh điển của UART ra ký tự rác — và
        // nó không làm chương trình crash, nên không ai nghi.
        let v = DiscoveryView()
        v.capNhat(ketQua: ["clocks": [
            "sysclk": ["measured": 8_000_000.0, "configured": 84_000_000.0],
        ]])
        XCTAssertTrue(chuTrongThan(v).contains("LỆCH"), chuTrongThan(v))
    }

    func testNUTchonBOARDkhongTUdanhDauLAB() {
        // BOARD-05 đòi `no_actuator`, `current_limited` và `by` — hai cam kết về phần cứng cộng
        // tên người cam kết, rồi ghi vào autonomy.yaml và KÝ. Đánh dấu lab là mở quyền TỰ NẠP
        // FIRMWARE; panel tự điền thay người là tác tử tự cấp quyền ấy cho chính nó.
        //
        // Test giữ điều này ở tầng khung nhìn: callback chỉ mang board_id ra ngoài, không có
        // chỗ nào để panel nhét `no_actuator: true` vào mà không ai thấy.
        let v = DiscoveryView()
        var nhan: String?
        v.onChonBoard = { nhan = $0 }
        v.capNhat(ketQua: ["candidates": [
            ["board_id": "weact.blackpill-f411", "score": 0.93, "reasons": ["IDCODE", "I2C 0x76"]],
        ]])
        let nut = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { $0 as? NSButton }.first
        nut?.performClick(nil)
        XCTAssertEqual(nhan, "weact.blackpill-f411")
    }

    // MARK: - Màn 15: Log

    func testKHOANGLANGlenDAUvaKEMsoDONG() {
        // Chỗ hệ thống NGỪNG NÓI mới là chỗ nó treo, và đó chính là chỗ không có dòng nào để
        // đọc. Một con số giây không kèm số dòng thì vô dụng trên tệp 40 triệu dòng.
        let v = LogAssistView()
        v.capNhat(ketQua: ["stats": [
            "file": "serial-3.log", "lines": 412_233,
            "levels": ["INFO": 400_000, "ERROR": 12],
            "time_span": ["duration_s": 903.4],
            "gaps": [["after_line": 128_004, "before_line": 128_005, "gap_s": 47.2]],
            "top_patterns": [["pattern": "i2c timeout", "count": 812]],
        ]])
        XCTAssertEqual(v.soDongLog, 412_233)
        XCTAssertEqual(v.soKhoangLang, 1)
        XCTAssertEqual(v.soLoi, 12)

        let dau = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSButton)?.title }.first
        XCTAssertEqual(dau, "lặng 47.200 s", "khoảng lặng phải lên đầu")
        XCTAssertTrue(chuTrongThan(v).contains("128004"), chuTrongThan(v))
    }

    func testCHANDOANkhongTRICHDANbiNOIRAlaPHONGdoan() {
        // Cùng vấn đề của `RagAskView`: nghe rất hợp lý và không kiểm được.
        let v = LogAssistView()
        v.capNhat(ketQua: [
            "diagnosis": ["summary": "I2C1 bị giữ mức thấp do thiếu pull-up"],
            "session_id": "dbg_1",
        ])
        XCTAssertTrue(chuTrongThan(v).contains("KHÔNG trích dẫn"), chuTrongThan(v))
    }

    // MARK: - Màn 16: Gỡ lỗi

    func testMACHINEobservableFALSEchanKETluan() {
        // `all_passed` nói kỳ vọng có đạt không; `machine_observable` nói máy có tự kiểm được
        // không. Cùng hình dạng với `unverified` của `sim.*`, cùng lý do để không gộp.
        let v = DebugView()
        v.capNhat(ketQua: [
            "evidence": [["kind": "serial", "summary": "thấy chuỗi HKW", "log_ref": "l_1"]],
            "all_passed": true,
            "machine_observable": false,
        ])
        XCTAssertEqual(v.mayQuanSatDuoc, false)
        XCTAssertTrue(v.tomTat.stringValue.contains("MÁY KHÔNG TỰ KIỂM ĐƯỢC"), v.tomTat.stringValue)
        XCTAssertTrue(chuTrongThan(v).contains("không phải bằng chứng"), chuTrongThan(v))
    }

    func testGIAthuyetKHONGkemTHInghiemBInoiRA() {
        // DEBUG-03 sinh giả thuyết và thí nghiệm phân biệt theo CẶP. Một danh sách giả thuyết
        // không kèm cách phân biệt là danh sách để người đọc chọn cái nghe thuận tai nhất.
        let v = DebugView()
        v.capNhat(ketQua: ["diagnosis": ["hypotheses": [
            ["text": "thiếu pull-up trên SDA", "score": 0.6],
        ]]])
        XCTAssertEqual(v.soGiaThuyet, 1)
        XCTAssertTrue(chuTrongThan(v).contains("KHÔNG có thí nghiệm phân biệt"), chuTrongThan(v))
    }

    func testNUTthiNGHIEMmangTHEOcaOBJECTvaTARGET() {
        // DEBUG-04 nhận `experiment{cap, args, expect}` và `target`, cả hai bắt buộc. Trả một
        // chuỗi mô tả rồi để panel dựng lại là dựng một thí nghiệm KHÁC.
        let v = DebugView()
        var tn: [String: Any]?
        var dich = ""
        v.onChayThiNghiem = { tn = $0; dich = $1 }
        v.capNhat(ketQua: ["diagnosis": [
            "target": "nucleo-f411",
            "hypotheses": [[
                "text": "SCL bị giữ thấp",
                "score": 0.8,
                "experiment": ["cap": "target.probe_read", "args": ["addr": "0x40005400"],
                               "expect": "bit BUSY = 0"],
            ]],
        ]])
        let nut = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { $0 as? NSButton }.first
        XCTAssertNotNil(nut)
        nut?.performClick(nil)
        XCTAssertEqual(tn?["cap"] as? String, "target.probe_read")
        XCTAssertEqual(dich, "nucleo-f411")
    }

    func testBANGCHUNGkhongCOvetLOGbiNOIRA() {
        // Một bằng chứng không truy lại được thì không phải bằng chứng, chỉ là một câu khẳng
        // định thêm.
        let v = DebugView()
        v.capNhat(ketQua: ["evidence": ["kind": "probe", "summary": "CR1 = 0x0001"]])
        XCTAssertTrue(chuTrongThan(v).contains("KHÔNG có vết log"), chuTrongThan(v))
    }

    func testDOIrangBUOCk6DOCkhacDOImotDONGma() {
        // Đổi K6 ảnh hưởng MỌI lần sinh mã sau này, không chỉ một chỗ.
        let v = DebugView()
        v.capNhat(ketQua: ["proposal": [
            "kind": "constraint", "step_text": "hạ tốc I2C xuống 100 kHz",
            "k6_change": ["i2c_speed": 100_000],
        ]])
        XCTAssertTrue(chuTrongThan(v).contains("đổi ràng buộc K6"), chuTrongThan(v))
    }

    // MARK: - Màn 18: Bench

    func testHUYHIEUkhongKEMdiemNGAYbiGOIlaTUchungThuc() {
        // Huy hiệu đi theo gói vào registry, nơi người khác thấy nó mà không thấy lần chạy sinh
        // ra nó. Đây là chỗ duy nhất hai thứ còn đứng cạnh nhau.
        let v = BenchView()
        v.capNhat(ketQua: ["badges": [
            ["badge": "verified", "package": "eide.stm32f4", "score": 0.91, "at": "2026-09-13"],
            ["badge": "verified", "package": "eide.avr8"],
        ]])
        XCTAssertEqual(v.soHuyHieu, 2)
        XCTAssertTrue(chuTrongThan(v).contains("tự chứng thực"), chuTrongThan(v))
    }

    func testTHIEUmotTRONGbaCHIsoCFBFBCduocDANHdau() {
        // Một chỉ số lẻ không so sánh được với gì.
        let v = BenchView()
        v.capNhat(ketQua: ["report": ["tasks": [
            ["task": "sinh driver I2C", "model": "claude", "CF": 0.9, "BF": 0.7, "BC": 0.8],
            ["task": "sửa lỗi build", "model": "gemini", "CF": 0.5],
        ]]])
        XCTAssertEqual(v.soTacVu, 2)
        let hang = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
        XCTAssertEqual(hang.count, 2)
        let mau = hang.compactMap { ($0.last as? NSTextField)?.textColor }
        XCTAssertEqual(mau.last, EideToken.Mau.warn, "tác vụ thiếu chỉ số phải được đánh dấu")
    }

    // MARK: - Chung

    func testBONmanDEUcoNhanTroNangVAnoiRaKhiRong() {
        for m in [DiscoveryView() as ManHinhCoSo, LogAssistView(), DebugView(), BenchView()] {
            m.capNhat(ketQua: [:])
            XCTAssertFalse(chuTrongThan(m).isEmpty, "\(type(of: m)) để trống khi rỗng")
            XCTAssertEqual(m.accessibilityRole(), .group)
            XCTAssertFalse((m.accessibilityLabel() ?? "").isEmpty)
        }
    }
}

/// `EideSo` — đọc số từ JSON mà không quan tâm nó tới dưới dạng nào.
///
/// Bài test này ra đời từ một lần đỏ thật: `gaps: [["after_line": 128004, "gap_s": 47.2]]` —
/// Swift thấy một `Double` trong cùng object nên suy cả dict thành `[String: Double]`, và
/// `as? Int` trả `nil` **trong im lặng**. Triệu chứng không phải một lỗi mà là số 0: "mở log ở
/// dòng 0", tức chỉ người dùng tới một chỗ không phải chỗ hệ thống treo.
///
/// JSON không phân biệt số nguyên với số thực; các cầu nối thì có. Chỗ nào đọc số từ kết quả
/// `caps.invoke` cũng phải chịu được cả ba dạng.
final class EideSoTests: XCTestCase {

    func testDOCduocCAincLANdoubleLANnsnumber() {
        XCTAssertEqual(EideSo.nguyen(42), 42)
        XCTAssertEqual(EideSo.nguyen(42.0), 42)
        XCTAssertEqual(EideSo.nguyen(NSNumber(value: 42)), 42)
        XCTAssertEqual(EideSo.nguyen("42"), 42)
        XCTAssertNil(EideSo.nguyen("bốn hai"))
        XCTAssertNil(EideSo.nguyen(nil))

        XCTAssertEqual(EideSo.thuc(3), 3.0)
        XCTAssertEqual(EideSo.thuc(3.5), 3.5)
        XCTAssertEqual(EideSo.thuc(NSNumber(value: 3.5)), 3.5)
    }

    func testDICTtronINTvaDOUBLEvanDOCduocSOnguyen() {
        // Đúng hình dạng đã làm test đỏ: Swift suy `[String: Double]` cho cả dict.
        let g: [String: Any] = ["after_line": 128_004, "gap_s": 47.2]
        XCTAssertEqual(EideSo.nguyen(g["after_line"]), 128_004)
    }

    func testKHOANGLANGdocDUNGsoDONGduDICTbiSUYthanhDOUBLE() {
        // Kiểm ở tầng khung nhìn, không chỉ ở hàm: đây là chỗ con số ấy thật sự được dùng.
        let v = LogAssistView()
        v.capNhat(ketQua: ["stats": [
            "lines": 500, "gaps": [["after_line": 128_004, "before_line": 128_005, "gap_s": 47.2]],
        ]])
        let hang = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
        let chu = hang.flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " ")
        XCTAssertTrue(chu.contains("128004"), chu)
        XCTAssertFalse(chu.contains("dòng 0"), "số dòng bị đọc thành 0: \(chu)")
    }
}
