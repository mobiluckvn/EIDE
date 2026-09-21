import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Nhóm HỆ THỐNG — S21 Môi trường, S22 Mô hình & chi phí, S23 Công cụ tự tạo, S24 Registry.**
@MainActor
final class EideManHeThongTests: XCTestCase {

    // MARK: - S21 Môi trường

    /// BA trạng thái, không hai: `ok=false` gộp cả "chưa cài" lẫn "có nhưng CŨ", mà hai cái ấy
    /// cần hai việc khác hẳn nhau — một cái là cài mới, một cái là nâng cấp.
    func testCongCuCoBaTrangThaiChuKhongHai() {
        XCTAssertTrue(EideManMoiTruong.oTrangThai(["ok": true]).contains("đạt"))
        XCTAssertTrue(EideManMoiTruong.oTrangThai(["ok": false]).contains("chưa cài"))
        XCTAssertTrue(EideManMoiTruong
            .oTrangThai(["ok": false, "found": "/usr/bin/gcc", "version": "9.2"])
            .contains("CŨ"), "gộp 'có nhưng cũ' vào 'chưa cài'")
    }

    /// **"Nút sửa KHÔNG bao giờ chạy sudo"** — §8 S21. Nút gọi `env.guide_install` (R0), không
    /// gọi `env.install` (R4). Một nút "sửa giúp tôi" chạy sudo vòng qua đúng danh sách trắng
    /// đã ký mà POL-17 §3 dựng lên.
    func testNutSuaGoiHuongDanChuKhongGoiCaiDat() async {
        var daGoi: [String] = []
        let m = EideManMoiTruong()
        await m.nap { ten, tham in
            daGoi.append((tham["id"] as? String) ?? ten)
            switch (tham["id"] as? String) ?? "" {
            case "project.status":
                return ["status": "done", "result": ["report": ["target": ["isa": "armv7e-m"]]]]
            default:
                return ["status": "done", "result": ["report": [
                    ["tool": "arm-none-eabi-gcc", "required": true, "ok": false, "min": "12"],
                ]]]
            }
        }
        XCTAssertFalse(daGoi.contains("env.install"), "gọi năng lực R4 lúc mở màn — \(daGoi)")
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Cách cài arm-none-eabi-gcc"), van)
        XCTAssertTrue(van.contains("R4"), "không nói vì sao không tự cài — \(van)")
    }

    /// Hướng dẫn phải nói thẳng EIDE không chạy hộ.
    func testHuongDanNoiRoLamBangTay() {
        let m = EideManMoiTruong()
        m.hienHuongDan("openocd", ["steps": ["brew install openocd"],
                                   "links": ["https://openocd.org"]])
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("EIDE không chạy hộ"), van)
        XCTAssertTrue(van.contains("brew install openocd"), van)
    }

    /// Chưa ghim ISA thì `env.check` không chạy được — và câu rỗng phải nói ĐÚNG lý do, vì
    /// `env.check` kiểm theo ISA chứ không theo máy.
    func testChuaGhimISAthiNoiDungLyDo() async {
        let m = EideManMoiTruong()
        await m.nap { _, _ in
            ["status": "done", "result": ["report": ["target": [String: Any]()]]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa ghim ISA"), van)
        XCTAssertTrue(van.contains("S5"), van)
    }

    // MARK: - S22 Mô hình & chi phí

    /// **`nil` là "chưa đặt hạn mức", không phải 0 USD.** Hai câu ấy trái ngược nhau: một cái
    /// nghĩa là tiêu thoải mái, một cái nghĩa là không được tiêu đồng nào.
    func testHanMucChuaDatKhacVoiKhong() {
        XCTAssertEqual(EideManMoHinh.oHanMuc(nil), "chưa đặt")
        XCTAssertEqual(EideManMoHinh.oHanMuc(NSNull()), "chưa đặt")
        XCTAssertEqual(EideManMoHinh.oHanMuc(0.0), "0.00 USD")
        XCTAssertEqual(EideManMoHinh.oHanMuc(2.5), "2.50 USD")
    }

    /// `sap_het` có BA giá trị, và giá trị thứ ba là phần đáng giữ: `nil` = chưa biết. Một cảnh
    /// báo ngân sách sai hướng thì hoặc làm người ta hoảng, hoặc dạy người ta bỏ qua nó.
    func testSapHetCoBaGiaTri() {
        XCTAssertTrue(EideManMoHinh.oSapHet(nil).contains("chưa biết"))
        XCTAssertTrue(EideManMoHinh.oSapHet(true).contains("CÓ"))
        XCTAssertEqual(EideManMoHinh.oSapHet(false), "không")
    }

    /// Sắp hết ngân sách → băng cảnh báo nói rõ tác tử KHÔNG tự dừng. "Không chạy tiếp im
    /// lặng" là chữ của §8 S22.
    func testSapHetThiBangCanhBaoNoiRoTacTuKhongTuDung() async {
        let m = EideManMoHinh()
        await m.nap { _, _ in
            ["status": "done", "result": ["spent_usd": 1.82, "daily_budget_usd": 2.0,
                                          "remaining_usd": 0.18, "calls_today": 37,
                                          "warn_pct": 20, "sap_het": true]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("SẮP HẾT NGÂN SÁCH"), van)
        XCTAssertTrue(van.contains("KHÔNG tự dừng"), van)
        XCTAssertTrue(van.contains("1.8200 USD"), "mất số đã tiêu — \(van)")
        XCTAssertTrue(van.contains("37"), van)
    }

    /// Bảng VAI → MÔ HÌNH chưa dựng được ([DEV-136]) — màn phải nói thẳng thay vì bỏ trống.
    func testNoiThangRangBangVaiMoHinhChuaCo() async {
        let m = EideManMoHinh()
        await m.nap { _, _ in ["status": "done", "result": ["spent_usd": 0.0, "calls_today": 0]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("VAI → MÔ HÌNH"), van)
        XCTAssertTrue(van.contains("DEV-136"), van)
        XCTAssertTrue(van.contains("chưa đặt"), "hạn mức nil phải là 'chưa đặt' — \(van)")
    }

    /// Thanh hạn mức chỉ vẽ khi CÓ hạn — vẽ một thanh không có mốc là vẽ một con số bịa.
    func testThanhHanMucChiVeKhiCoHan() async {
        let m = EideManMoHinh()
        await m.nap { _, _ in ["status": "done", "result": ["spent_usd": 0.5, "calls_today": 2]] }
        XCTAssertNil(Self.tim(m, EideThanhMuc.self), "vẽ thanh khi chưa đặt hạn mức")

        let m2 = EideManMoHinh()
        await m2.nap { _, _ in
            ["status": "done", "result": ["spent_usd": 0.5, "daily_budget_usd": 2.0,
                                          "remaining_usd": 1.5, "calls_today": 2,
                                          "warn_pct": 20, "sap_het": false]]
        }
        XCTAssertNotNil(Self.tim(m2, EideThanhMuc.self))
    }

    // MARK: - S23 Công cụ tự tạo

    /// Điều kiện thăng cấp chép đúng TOOL-08 ("dùng ≥ 3 lần, 0 lỗi"), và nói RÕ còn thiếu bao
    /// nhiêu — "chưa đủ" mà không nói thiếu gì thì người đọc phải đi tra tài liệu.
    func testDieuKienThangCapNoiRoConThieuBaoNhieu() {
        XCTAssertTrue(EideManCongCu.oThangCap(dat: 3, hong: 0).contains("đủ điều kiện"))
        XCTAssertTrue(EideManCongCu.oThangCap(dat: 1, hong: 0).contains("cần thêm 2"))
        XCTAssertTrue(EideManCongCu.oThangCap(dat: 9, hong: 1).contains("1 lượt hỏng"),
                      "một lượt hỏng vẫn chặn thăng cấp — TOOL-08")
        // Ô bảng phải NGẮN: bản đầu nhét cả câu trích TOOL-08 vào đây và `catVua` cắt mất đuôi.
        for o in [EideManCongCu.oThangCap(dat: 9, hong: 1),
                  EideManCongCu.oThangCap(dat: 1, hong: 0)] {
            XCTAssertLessThan(o.count, 24, "ô quá dài, sẽ bị cắt trong bảng: \(o)")
        }
    }

    /// Đếm theo lượt ĐẠT, không theo tổng lượt chạy: một công cụ chạy 10 lần hỏng 7 thì con số
    /// "10" nói sai hoàn toàn về nó.
    ///
    /// v1.3 — nguồn đổi từ `view.timeline` sang `view.artifacts kind=tool` ([DEV-136]). Bản cũ
    /// lọc `tool.report` trong 500 bản ghi gần nhất, và nó sai theo HAI chiều: công cụ chạy
    /// nhiều từ lâu trôi ra khỏi cửa sổ nên biến mất khỏi danh mục, còn dự án chạy dày thì 500
    /// bản ghi không đủ tới công cụ thứ hai. Phép gộp nay ở SQL.
    func testDemTheoLuotDATkhongTheoTongLuotChay() async {
        let m = EideManCongCu()
        await m.nap { ten, tham in
            guard ten == "caps.invoke",
                  (tham["id"] as? String) == "view.artifacts" else {
                return ["status": "done", "result": [String: Any]()]
            }
            return ["status": "done", "result": ["items": [
                ["tool": "crc16", "dat": 1, "tong": 2, "at": "2026-09-21T08:01:00+00:00"],
                ["tool": "sim.run", "dat": 5, "tong": 5, "at": "2026-09-21T08:02:00+00:00"],
            ], "total": 2, "kind": "tool"]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("crc16"), van)
        XCTAssertTrue(van.contains("1 lượt hỏng"), "báo đủ điều kiện dù có lượt hỏng — \(van)")
        XCTAssertTrue(van.contains("0 lỗi (TOOL-08)"), "câu trích luật mất khỏi tiêu đề — \(van)")
        XCTAssertFalse(van.contains("sim.run"),
                       "năng lực dựng sẵn lọt vào bảng công cụ TỰ TẠO — \(van)")
    }

    // MARK: - S24 Registry

    /// **Không chữ ký là một CẢNH BÁO, không phải một ô trống.** Một gói chưa ký cài vào dự án
    /// là mã của người lạ chạy trên máy anh.
    func testGoiChuaKyLaCanhBaoChuKhongPhaiOTrong() {
        XCTAssertTrue(EideManRegistry.oChuKy(nil).contains("CHƯA KÝ"))
        XCTAssertTrue(EideManRegistry.oChuKy("").contains("CHƯA KÝ"))
        XCTAssertTrue(EideManRegistry.oChuKy("abcdef1234567").hasPrefix("✅"))
        XCTAssertEqual(EideManRegistry.oHuyHieu(["verified_on_board", "bench"]),
                       "verified_on_board · bench")
        XCTAssertEqual(EideManRegistry.oHuyHieu(nil), "—")
    }

    func testS24BangGoiVaTrangThaiRong() async {
        let m = EideManRegistry()
        await m.nap { _, _ in ["status": "done", "result": ["packages": [Any]()]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có gói nào"), van)
        XCTAssertTrue(van.contains("registry.seed"), van)
    }

    // MARK: - chung

    func testBonManDaNoiVaKhaiBaoNghe() {
        for (tien, ma) in [("Env", "S21"), ("Models", "S22"),
                           ("ToolForge", "S23"), ("Registry", "S24")] {
            XCTAssertNotNil(EidePhien.MAN[tien], "`\(tien)` chưa vào bảng màn")
            XCTAssertEqual(EideManHinhDS.man(tien)?.ma, ma)
            XCTAssertNotNil(EideDangKySuKien.BANG[tien], "`\(tien)` chưa khai báo nghe gì")
        }
    }

    private static func tim<T: NSView>(_ v: NSView, _ loai: T.Type) -> T? {
        if let x = v as? T { return x }
        for c in v.subviews { if let x = tim(c, loai) { return x } }
        return nil
    }

    static func chu(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += t.attributedStringValue.string.isEmpty ? t.stringValue
                                                         : t.attributedStringValue.string
        }
        if let b = v as? NSButton { ra += " " + b.title }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}
