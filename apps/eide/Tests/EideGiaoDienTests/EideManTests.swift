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

    /// Điểm dừng tab là mốc TUYỆT ĐỐI: một ô dài hơn cột đẩy ô kế sang mốc sau đó, và cả đuôi
    /// hàng lệch một cột. Đo 20/09 trên màn Hộ chiếu chip — hàng ấy hiện "vàng · chưa duyệt"
    /// nằm dưới tiêu đề NGUỒN, đọc như một fact có nguồn tên "vàng".
    func testOQuaDaiBiCatChuKhongDayLechCotSau() {
        let f = EideToken.fontMono
        let dai = "periph:AC/reg:DIDR1/field:AIN0D/mot/duong/dan/rat/dai"
        let cat = EideManCoSo.catVua(dai, rong: 120, font: f)
        XCTAssertTrue(cat.hasSuffix("…"), cat)
        XCTAssertLessThanOrEqual((cat as NSString).size(withAttributes: [.font: f]).width, 120)
        // Cột CUỐI (`rong == 0`) không cắt: nó chạy hết bề ngang còn lại.
        XCTAssertEqual(EideManCoSo.catVua(dai, rong: 0, font: f), dai)
        // Vừa rồi thì giữ NGUYÊN — cắt một ô đã vừa là bỏ chữ đi không vì gì.
        XCTAssertEqual(EideManCoSo.catVua("CR1", rong: 120, font: f), "CR1")
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

    private func _the(_ tong: Int) -> EideTheRun {
        let t = _the()
        t.nhan(["kind": "run.started", "run_id": "r1", "n": tong,
                "steps": (0..<tong).map { ["id": "n\($0)", "cap": "kg.build"] }])
        return t
    }

    // MARK: - `run.done` không có nghĩa là "xong" (bài CNC 21/09/2026)

    /// Ba tín hiệu trên thẻ phải kể CÙNG một câu chuyện.
    ///
    /// Đo trên chặng A bài CNC: thẻ ghi `bước 6/6  ✅ Xong 0/6 bước` cho một chuỗi dừng ở nút
    /// ĐẦU để hỏi người. Bộ đếm nói đã tới cuối, dòng chữ nói chưa làm gì, dấu ✅ nói mọi thứ
    /// ổn. Nguyên nhân: `run.done` gán cứng `.xong` và `buoc = tong` rồi in số `done` THẬT ở
    /// dòng dưới — hai nguồn khác nhau cho hai con số nằm cạnh nhau.
    func testDungHoiNguoiThiKhongHienDauTickVaBoDemKhongNhayToiCuoi() {
        let t = _the(6)
        t.nhan(["kind": "run.done", "run_id": "r1", "state": "asked",
                "done": 0, "waiting": 1, "failed": 0])
        XCTAssertEqual(t.trangThai, .chan, "dừng hỏi người không phải là xong")
        XCTAssertFalse(t.dongChu.contains("✅"), t.dongChu)
        XCTAssertTrue(t.dongChu.contains("0/6"), t.dongChu)
        XCTAssertTrue(t.demChu.contains("1/6"),
                      "chuỗi dừng ở nút đầu thì bộ đếm phải nói bước 1, nhận: \(t.demChu)")
    }

    func testChayHetThiBoDemVaDongChuKhopNhau() {
        let t = _the(6)
        t.nhan(["kind": "run.done", "run_id": "r1", "state": "done", "done": 6])
        XCTAssertEqual(t.trangThai, .xong)
        XCTAssertTrue(t.dongChu.contains("✅") && t.dongChu.contains("6/6"), t.dongChu)
        XCTAssertTrue(t.demChu.contains("6/6"), t.demChu)
    }

    /// Có nút hỏng thì đừng khoe dấu tick — người đọc sẽ đóng thẻ mà không xem Nhật ký.
    func testCoNutHongThiNoiRa() {
        let t = _the(4)
        t.nhan(["kind": "run.done", "run_id": "r1", "state": "done", "done": 2, "failed": 2])
        XCTAssertFalse(t.dongChu.contains("✅"), t.dongChu)
        XCTAssertTrue(t.dongChu.contains("2 bước hỏng"), t.dongChu)
    }

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

/// Bảng lệnh ⌘K — ba điều UXC-31 §4 đòi, mỗi điều một phép đo.
@MainActor
final class EideBangLenhTests: XCTestCase {

    private func _bang() -> EideBangLenh {
        let b = EideBangLenh(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        b.datNguon(nangLuc: [
            ("passport.query", "Tra thanh ghi/bit từ hộ chiếu chip"),
            ("sim.run", "Chạy firmware trên bộ mô phỏng"),
            ("code.build", "Dựng firmware"),
        ])
        return b
    }

    /// Gõ KHÔNG DẤU vẫn ra. Bắt gõ đủ dấu trong một ô tìm-nhanh là biến phím tắt thành một bài
    /// kiểm tra chính tả.
    func testTimKhongDau() {
        let ds = _bang().locDeTest("ho chieu")
        XCTAssertTrue(ds.contains { $0.ma == "Passport" }, "không tìm ra màn Hộ chiếu chip")
        XCTAssertTrue(ds.contains { $0.ma == "passport.query" }, "không tìm ra qua MÔ TẢ")
    }

    /// `đ` không rụng dấu qua `folding` — nó là một chữ cái riêng, không phải `d` có dấu.
    func testChuDCoGachKhongLotLuoi() {
        XCTAssertEqual(EideBangLenh.bo("Đồng bộ"), "dong bo")
        XCTAssertEqual(EideBangLenh.bo("Hộ chiếu"), "ho chieu")
    }

    /// Tìm được MÀN, không chỉ năng lực — nửa số thứ người ta muốn mở là một màn hình.
    func testManLenTruocKhiDiemBangNhau() {
        let ds = _bang().locDeTest("mo phong")
        XCTAssertEqual(ds.first?.ma, "Sim")
        XCTAssertTrue(ds.first?.laMan == true)
    }

    /// Ô trống thì hiện 25 màn, không hiện 242 năng lực: mở bảng lệnh mà chưa gõ gì là đang tìm
    /// một NƠI để đến.
    func testORongThiHienMan() {
        let ds = _bang().locDeTest("")
        XCTAssertEqual(ds.count, EideManHinhDS.tatCa.count)
        XCTAssertTrue(ds.allSatisfy(\.laMan))
    }

    func testKhongKhopThiNoiCachTimKhac() {
        let b = _bang()
        b.locDeTest("xyzzy-khong-co-that")
        let van = _chuTrong(b)
        XCTAssertTrue(van.contains("Không có mục nào khớp"), van)
        XCTAssertTrue(van.contains("mô tả"), van)
    }

    private func _chuTrong(_ v: NSView) -> String {
        var ra = (v as? NSTextField)?.stringValue ?? ""
        for c in v.subviews { ra += "\n" + _chuTrong(c) }
        return ra
    }
}

/// Hai lượt nạp chồng nhau không được đánh nhau trên một màn — [DEV-164].
@MainActor
final class EideNapChongNhauTests: XCTestCase {

    /// Đo 22/09/2026 bằng ảnh chụp cửa sổ thật giữa một lượt CNC: màn Tổng quan hiện
    /// `Đang đọc…` (của lượt B) cạnh bảng `NGÂN SÁCH MÔ HÌNH` (của lượt A), và THIẾU HẲN bảng
    /// `PHIÊN LÀM VIỆC`.
    ///
    /// Dấu vết ấy khớp chính xác một cuộc đua: `nap` mở đầu bằng `xoa()`, nên lượt sau xoá sạch
    /// những gì lượt trước vừa vẽ, rồi lượt trước tỉnh dậy và vẽ tiếp vào màn của lượt sau.
    /// Nhãn chờ không bao giờ tắt vì lượt A gỡ nhãn của CHÍNH NÓ — thứ `xoa()` đã tháo từ lâu.
    ///
    /// Trước [DEV-154] hiếm khi xảy ra vì mọi lời gọi xếp hàng một.
    func testLuotNapCU_KhongVeVaoManCuaLuotMOI() async {
        let m = EideManChậm()
        // A bắt đầu, dừng ở `await` đầu tiên.
        let a = Task { await m.nap { _, _ in
            try? await Task.sleep(nanoseconds: 400_000_000)
            return ["status": "done", "result": [String: Any]()]
        } }
        try? await Task.sleep(nanoseconds: 80_000_000)
        // B tiếp quản trong lúc A còn đang đợi.
        await m.nap { _, _ in ["status": "done", "result": [String: Any]()] }
        _ = await a.value

        let van = EideManLamRoTests.chu(m)
        XCTAssertFalse(van.contains("Đang đọc…"),
                       "nhãn chờ của lượt cũ còn lại — \(van)")
        XCTAssertEqual(m.soLanVe, 1, "lượt CŨ vẫn vẽ vào màn: \(m.soLanVe) lần")
    }
}

/// Màn giả: `napDuLieu` có một `await` ở giữa để dựng được cuộc đua.
@MainActor
final class EideManChậm: EideManCoSo {
    var soLanVe = 0
    override class var tien: String { "Main" }
    override func napDuLieu(_ goi: @escaping EideGoi) async throws {
        _ = try await doc(goi, "session.state")
        soLanVe += 1
        tieuDePhu("XONG")
    }
}
