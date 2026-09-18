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

/// Thẻ Run — máy trạng thái nhận sự kiện. Payload chép đúng từ `src/eide/caps/chat.py`.
@MainActor
final class EideTheRunTests: XCTestCase {

    private func _the() -> EideTheRun { EideTheRun(ma: "r1", van: "đọc BME280 qua I2C") }

    func testMotLuotChayTronVenDiHetBonTrangThai() {
        let t = _the()
        XCTAssertEqual(t.trangThai, .chay)
        t.nhan(["kind": "run.started", "run_id": "r1", "n": 7, "text": "đọc BME280 qua I2C",
                "steps": [["id": "n1", "cap": "passport.query"], ["id": "n2", "cap": "code.write"],
                          ["id": "n3", "cap": "sim.run"]]])
        XCTAssertEqual(t.tong, 3)
        XCTAssertEqual(t.buoc, 0)

        t.nhan(["kind": "run.step_started", "run_id": "r1", "cap": "passport.query", "i": 1, "of": 3])
        XCTAssertEqual(t.buoc, 0, "bước 1 ĐANG chạy nghĩa là 0 bước đã xong")
        t.nhan(["kind": "run.step_done", "run_id": "r1", "cap": "passport.query",
                "i": 1, "of": 3, "status": "done"])
        XCTAssertEqual(t.buoc, 1)

        t.nhan(["kind": "run.done", "run_id": "r1", "state": "done", "done": 3])
        XCTAssertEqual(t.trangThai, .xong)
        XCTAssertEqual(t.buoc, 3)
    }

    /// Sự kiện tới KHÔNG theo thứ tự thì thẻ không được lùi: ống sự kiện dùng chung với câu trả
    /// lời, và một bước có thể tới sau bước kế nó.
    func testSuKienDenMuonKhongDayTienDoLUI() {
        let t = _the()
        t.nhan(["kind": "run.step_done", "run_id": "r1", "cap": "b", "i": 5, "of": 8, "status": "done"])
        XCTAssertEqual(t.buoc, 5)
        t.nhan(["kind": "run.step_done", "run_id": "r1", "cap": "a", "i": 2, "of": 8, "status": "done"])
        XCTAssertEqual(t.buoc, 5, "một sự kiện cũ đã kéo tiến độ lùi")
    }

    /// Bị chặn thì thẻ phải nói CHẶN VÌ GÌ — một thẻ đứng im ở "đang chạy" là lời nói sai.
    func testBiChanThiNoiRaThieuGi() {
        let t = _the()
        t.nhan(["kind": "run.started", "run_id": "r1", "steps": [["cap": "sim.run"]]])
        t.nhan(["kind": "run.blocked", "run_id": "r1", "cap": "sim.run",
                "reason": "thiếu tham số", "missing": ["scenario"]])
        XCTAssertEqual(t.trangThai, .chan)
        XCTAssertTrue(_chu(t).contains("scenario"), _chu(t))
    }

    /// Mở ứng dụng giữa một lượt chạy đang dở: sự kiện đầu tiên nghe được KHÔNG phải
    /// `run.started`. Thẻ vẫn phải dựng.
    func testDungTheLUOIKhiNgheGiuaChung() {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        let ph = EidePhien(khung: k)
        let truoc = k.dock.soLuot
        ph.napSuKien("event.run.progress",
                     ["kind": "run.step_started", "run_id": "r9", "cap": "code.write", "i": 3, "of": 8])
        XCTAssertEqual(k.dock.soLuot, truoc + 1)
        XCTAssertTrue(_chu(k.dock).contains("bước 3/8"), _chu(k.dock))
    }

    private func _chu(_ v: NSView) -> String {
        var ra = (v as? NSTextField)?.stringValue ?? ""
        if let b = v as? NSButton { ra += " " + b.title }
        for c in v.subviews { ra += "\n" + _chu(c) }
        return ra
    }
}
