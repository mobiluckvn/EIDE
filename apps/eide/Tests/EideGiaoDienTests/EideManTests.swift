import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// Phép đo cho lớp màn. Mỗi bài ghim đúng một lỗi đã xảy ra thật.
@MainActor
final class EideManTests: XCTestCase {

    /// Ba kết cục của một lượt chạy phải ra ba câu KHÁC NHAU. Trước khi có `boc`, cả ba đều
    /// hiện thành "không có dữ liệu".
    func testBocVoLuotChayNoiRaBaKetCucKhacNhau() throws {
        let xong = try EideKetQua.boc(["status": "done", "result": ["rules": [1, 2]]], "x")
        XCTAssertEqual((xong["rules"] as? [Int])?.count, 2)

        XCTAssertThrowsError(try EideKetQua.boc(
            ["status": "pending", "cap": "code.write",
             "decision": ["decision": "ASK", "rule": "GEN-03", "reason": "Ghi đè (R4)"]], "x")
        ) { e in
            let s = "\(e)"
            XCTAssertTrue(s.contains("ASK"), s)
            XCTAssertTrue(s.contains("GEN-03"), s)
            XCTAssertTrue(s.contains("Ghi đè"), s)
        }

        XCTAssertThrowsError(try EideKetQua.boc(
            ["status": "failed", "cap": "policy.rules",
             "error": ["eide_code": "E3002", "message": "Phiên đang dừng khẩn"]], "x")
        ) { e in
            XCTAssertEqual((e as? EideKetQua.Loi)?.maEide, "E3002")
            XCTAssertTrue("\(e)".contains("dừng khẩn"), "\(e)")
        }
    }

    /// Thân màn phải RỘNG bằng vùng làm việc. Khi bề rộng đến từ chính nội dung, Auto Layout
    /// giải vòng tròn ấy ra giá trị nhỏ nhất và bảng bốn cột hiện thành bốn dòng chồng nhau.
    func testThanManRongBangVungLamViec() {
        let v = EideVungLamViec(frame: NSRect(x: 0, y: 0, width: 1000, height: 600))
        let m = EideManNhatKy()
        v.moMan("NhatKy", nangLucDs: ["view.timeline"])
        v.datMan(m)
        v.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(m.frame.width, 800, "thân màn co lại còn \(m.frame.width) pt")
    }

    /// Bảng là MỘT khung nhìn, bất kể bao nhiêu hàng — hai bản trước dựng 4 và 1 khung nhìn mỗi
    /// hàng, và cả hai đều hỏng vì ràng buộc bên trong stack bị chính stack phá.
    func testBangLaMotKhungNhinDuBaoNhieuHang() {
        let m = EideManNhatKy()
        m.bang(cot: [("A", 80), ("B", 0)], dong: (1...200).map { ["\($0)", "giá trị \($0)"] })
        XCTAssertEqual(m.than.arrangedSubviews.count, 1)
    }

    func testGioDocDuocNgayVaGio() {
        XCTAssertEqual(EideManNhatKy.gio("2026-09-18T16:04:21.123456+00:00"), "18/09 16:04:21")
        XCTAssertEqual(EideManNhatKy.gio(nil), "—")
        XCTAssertEqual(EideManNhatKy.gio("hỏng"), "—")
    }

    /// `agent`, `human`, `human:congvt` là HAI chủ thể, không phải ba.
    func testAiChiCoHaiGiaTri() {
        XCTAssertEqual(EideManNhatKy.ai("human:congvt"), "người")
        XCTAssertEqual(EideManNhatKy.ai("human"), "người")
        XCTAssertEqual(EideManNhatKy.ai("agent"), "máy")
        XCTAssertEqual(EideManNhatKy.ai(nil), "máy")
    }

    /// Từ điển lồng KHÔNG được in bằng mô tả của Objective-C: nó xuống dòng và escape tiếng
    /// Việt thành `\U1edbp`.
    func testGonGangKhongEscapeTiengViet() {
        let s = EideManNhatKy.gonGang(["decision": "APPROVE", "rule": "R0",
                                       "reason": "Lớp R0 chỉ đọc — tự làm"])
        XCTAssertFalse(s.contains("\\U"), s)
        XCTAssertFalse(s.contains("\n"), s)
        XCTAssertTrue(s.contains("APPROVE"), s)
        XCTAssertEqual(EideManNhatKy.gonGang([1, 2, 3]), "[3 mục]")
        XCTAssertEqual(EideManNhatKy.gonGang(true), "true")
    }

    /// Mọi khoá trong bảng màn phải có thật trong danh mục 25 màn — một khoá gõ sai là một màn
    /// không bao giờ mở được, và nó trông y hệt một màn chưa làm.
    func testMoiKhoaTrongBangManDeuCoTrongDanhMuc() {
        for k in EidePhien.MAN.keys {
            XCTAssertNotNil(EideManHinhDS.man(k), "tiền tố `\(k)` không có trong danh mục")
        }
    }
}
