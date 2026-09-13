import AppKit
import XCTest

@testable import EIDEKit

/// Hai thẻ của UXD-13 §4 mà kênh sự kiện phát ra nhưng trước hôm nay không ai hiện.
///
/// Chúng là hai chỗ duy nhất trong cả giao diện trả lời câu hỏi *"máy đang làm gì lúc này"* —
/// mọi khung nhìn khác hiện kết quả, tức thứ đã xong. Giữa lúc một chuỗi 17 bước đang chạy,
/// người dùng nhìn vào panel và thấy hội thoại đứng yên.
final class EideRunCardsTests: XCTestCase {

    private func chu(_ v: NSView) -> String {
        func quet(_ x: NSView) -> [String] {
            var ra: [String] = []
            if let t = x as? NSTextField { ra.append(t.stringValue) }
            if let b = x as? NSButton { ra.append(b.title) }
            for c in x.subviews { ra += quet(c) }
            return ra
        }
        return quet(v).joined(separator: " ")
    }

    // MARK: - Thẻ ý hiểu

    func testTHEyHIEUcoNUTsuaVAnoDIENvaoOlenh() {
        // Nút "Sửa ý hiểu" quan trọng hơn cả câu văn: DPS-09 chấp nhận mô hình hiểu sai, điều
        // không chấp nhận được là người thấy nó sai mà không có đường nói lại.
        let the = RestateCard(text: "Tạo dự án cho STM32F411 với BME280 qua I2C1",
                              buoc: ["dựng tri thức", "sinh driver", "dựng firmware"])
        var dien: String?
        the.onSua = { dien = $0 }

        XCTAssertEqual(the.soBuoc, 3)
        XCTAssertTrue(chu(the).contains("Tôi hiểu là…"), chu(the))

        func timNut(_ v: NSView) -> NSButton? {
            if let b = v as? NSButton, b.title == "Sửa ý hiểu" { return b }
            for c in v.subviews { if let b = timNut(c) { return b } }
            return nil
        }
        timNut(the)?.performClick(nil)
        XCTAssertEqual(dien, "Tạo dự án cho STM32F411 với BME280 qua I2C1")
    }

    func testTHEyHIEUrongNOIRAmayKHONGnoiDUOCgi() {
        // `event.chat.restated` không mang `text` là một lỗi của phía kia, và hiện một thẻ
        // trắng thì người dùng tưởng máy hiểu đúng.
        let the = RestateCard(text: "")
        XCTAssertTrue(chu(the).contains("không nói được nó hiểu gì"), chu(the))
    }

    func testDANHsachBUOCdaiBIcatVAnoiRAdaCAT() {
        let the = RestateCard(text: "x", buoc: (1...12).map { "bước \($0)" })
        XCTAssertEqual(the.soBuoc, 8)
        XCTAssertTrue(chu(the).contains("4 bước nữa"), chu(the))
    }

    // MARK: - Thẻ tiến độ chuỗi

    func testGOPtheoRUNidCHUkhongTAOtheMOImoiThongDIEP() {
        // Một chuỗi 17 bước sinh 34 thông điệp; 34 thẻ chồng nhau thì không ai đọc được cái nào.
        let the = RunProgressCard(runId: "r_1")
        the.capNhat(["run_id": "r_1", "node_id": "n1", "cap": "extract.svd", "state": "running"])
        the.capNhat(["run_id": "r_1", "node_id": "n2", "cap": "kg.build", "state": "running"])
        the.capNhat(["run_id": "r_1", "node_id": "n1", "status": "done"])

        XCTAssertEqual(the.soNut, 2, "cùng node_id phải gộp về một chip")
        XCTAssertFalse(the.daXong)
        XCTAssertTrue(the.tomTat_choTest.contains("1/2 bước"), the.tomTat_choTest)
    }

    func testXONGhetTHIantNUThuy() {
        let the = RunProgressCard(runId: "r_1")
        the.capNhat(["node_id": "n1", "cap": "a", "state": "done"])
        XCTAssertTrue(the.daXong)
        XCTAssertTrue(the.tomTat_choTest.contains("xong"), the.tomTat_choTest)
    }

    func testNUThuyGOIjobCANCELkemDUNGid() {
        let the = RunProgressCard(runId: "job_9")
        var huy: String?
        the.onHuy = { huy = $0 }
        the.capNhat(["job_id": "job_9", "pct": 40])
        XCTAssertEqual(the.phanTram, 40)

        func timNut(_ v: NSView) -> NSButton? {
            if let b = v as? NSButton, b.title == "Huỷ" { return b }
            for c in v.subviews { if let b = timNut(c) { return b } }
            return nil
        }
        timNut(the)?.performClick(nil)
        XCTAssertEqual(huy, "job_9")
    }

    func testLOGtailHIENdongCUOI() {
        // "Đang chạy 40%" là tất cả những gì người dùng biết trong ba phút, nếu không hiện log.
        let the = RunProgressCard(runId: "job_9")
        the.capNhat(["job_id": "job_9", "pct": 60,
                     "log_tail": ["[3/9] Building C object drv_i2c.c.o"]])
        XCTAssertTrue(the.tomTat_choTest.contains("drv_i2c.c.o"), the.tomTat_choTest)
    }

    func testNAMtrangTHAIcoNAMdauHIEUkhacNhau() {
        // UXD-13 §4: xong / đang / chờ / hỏi / song song. "Chờ người" phải nhìn thấy được (U9),
        // nên nó KHÔNG được dùng chung dấu với "đang chạy".
        XCTAssertTrue(RunProgressCard.nhanNut("a", "done").hasPrefix("✓"))
        XCTAssertTrue(RunProgressCard.nhanNut("a", "running").hasPrefix("▸"))
        XCTAssertTrue(RunProgressCard.nhanNut("a", "pending").hasPrefix("?"))
        XCTAssertTrue(RunProgressCard.nhanNut("a", "failed").hasPrefix("✗"))
        XCTAssertTrue(RunProgressCard.nhanNut("a", "cancelled").hasPrefix("⊘"))

        XCTAssertEqual(RunProgressCard.mauTrangThai("pending"), EideToken.Mau.warn)
        XCTAssertEqual(RunProgressCard.mauTrangThai("failed"), EideToken.Mau.bad)
        XCTAssertEqual(RunProgressCard.mauTrangThai("done"), EideToken.Mau.ok)
    }

    func testCHIPmangTENnganCUAnangLUC() {
        XCTAssertTrue(RunProgressCard.nhanNut("extract.pdf_register_map", "done")
                        .contains("pdf_register_map"))
    }
}

/// Phím tắt UXD-13 §6 — và điều kiện khiến chúng không cướp phím của GEditor.
///
/// `⌘L` là "Đi tới dòng…" và `⌘Z` là "Hoàn tác" của trình soạn thảo. Cướp chúng ở mức cửa sổ
/// nghĩa là người đang sửa mã bấm `⌘Z` và thấy một mục hàng đợi bị hoàn tác thay vì dòng vừa
/// gõ — một trong những cách tệ nhất để một tính năng mới làm hỏng một thói quen cũ.
final class EidePhimTatTests: XCTestCase {

    private func su(_ ky: String, cmd: Bool = true, shift: Bool = false) -> NSEvent {
        var m: NSEvent.ModifierFlags = []
        if cmd { m.insert(.command) }
        if shift { m.insert(.shift) }
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: m,
                                timestamp: 0, windowNumber: 0, context: nil,
                                characters: ky, charactersIgnoringModifiers: ky,
                                isARepeat: false, keyCode: 0)!
    }

    func testKHONGbatPHIMkhiNGUOIkhongLAMviecTRONGpanel() {
        // Panel không nằm trong cửa sổ nào → `window` là nil → không được nhận phím nào.
        // Đây là điều kiện giữ `⌘L`/`⌘Z` cho trình soạn thảo.
        let p = EidePanel(client: EideClient(transport: OngIm()))
        for k in ["l", "k", "z", "1"] {
            XCTAssertFalse(p.performKeyEquivalent(with: su(k)),
                           "⌘\(k) không được nhận khi người đang làm việc ngoài panel")
        }
    }

    func testCHINmanDAUcuaBANGduocGANphimCOMMANDso() {
        // ⌘1…⌘9 chuyển chín màn ĐẦU của bảng UXD-13 §2, đúng thứ tự bảng — không phải thứ tự
        // tôi thấy tiện.
        let ten = EidePanel.tienManDaDung
        XCTAssertGreaterThanOrEqual(ten.count, 9)
        XCTAssertEqual(Array(ten.prefix(4)), ["Chat", "Main", "ReviewQueue", "Ingest"])
    }

    /// Ống câm — `EidePanel` cần một client để dựng, nhưng bài test này không gọi daemon.
    private final class OngIm: EideClient.Transport, @unchecked Sendable {
        func send(_ line: Data) async throws {}
        func receiveLine() async throws -> Data {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            return Data()
        }
        func close() async {}
    }
}
