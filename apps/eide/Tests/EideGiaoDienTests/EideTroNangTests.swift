import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **§9 Trợ năng · §6.1 modal ASK.**
@MainActor
final class EideTroNangTests: XCTestCase {

    private func dungKhung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }

    // MARK: - §9.1 điều hướng bằng bàn phím

    /// ⌘1…⌘6 mở màn ĐẦU của mỗi nhóm. Đưa người tới một tiêu đề rồi bắt bấm chuột tiếp thì phím
    /// tắt ấy chưa thay được cái bấm chuột nào.
    func testNhaySauNhomBangPhimTat() {
        let (k, ph) = dungKhung()
        XCTAssertEqual(EideManHinhDS.nhom.count, 6, "số nhóm đổi thì ⌘1…⌘6 không còn phủ hết")
        for i in 1...6 {
            let tien = ph.nhayNhom(i)
            XCTAssertNotNil(tien, "⌘\(i) không mở màn nào")
            XCTAssertEqual(k.vungLamViec.dangMo, tien)
            XCTAssertEqual(tien, EideManHinhDS.nhom[i - 1].man.first?.tien)
        }
        XCTAssertNil(ph.nhayNhom(0))
        XCTAssertNil(ph.nhayNhom(7))
    }

    /// **⌘W đóng TAB, và khi hết tab thì KHÔNG đóng cửa sổ.** Để nó rơi xuống thành "đóng ứng
    /// dụng" là mất việc vì một phím.
    func testDongTabKhongDongCuaSoKhiHetTab() {
        let (k, ph) = dungKhung()
        ph.moMan("Main", boiTacTu: false)
        ph.moMan("NhatKy", boiTacTu: false)
        XCTAssertTrue(ph.dongTabHienTai())
        XCTAssertEqual(k.thanhTab.tab, ["Main"])
        XCTAssertTrue(ph.dongTabHienTai())
        XCTAssertTrue(k.thanhTab.tab.isEmpty)
        XCTAssertFalse(ph.dongTabHienTai(), "hết tab mà ⌘W vẫn báo đã đóng được gì đó")
    }

    /// ⌘S mà S14 không mở thì NÓI RA. Bấm ⌘S không thấy gì xảy ra và không có lời nào là để
    /// người viết mã tin rằng mình đã lưu.
    func testLuuKhiKhongMoS14ThiNoiRa() async {
        let (k, ph) = dungKhung()
        ph.moMan("Main", boiTacTu: false)
        await ph.luuTepHienTai()
        XCTAssertTrue(Self.chu(k.dock).contains("màn ấy đang không mở"), Self.chu(k.dock))
    }

    // MARK: - §9.2 nhãn trợ năng

    /// **Mọi nút bấm được phải có nhãn đọc được.** Quét cả cây khung nhìn của từng màn thay vì
    /// tin trí nhớ: một nút chỉ mang ký hiệu (`✕`, `⟩`, `▁`) là nút VoiceOver đọc thành một dấu
    /// vô nghĩa, và người dùng bàn phím không biết nó làm gì.
    func testMoiNutDeuCoNhanDocDuoc() {
        let (k, ph) = dungKhung()
        var thieu: [String] = []
        for tien in EidePhien.MAN.keys.sorted() {
            ph.moMan(tien, boiTacTu: false)
            k.layoutSubtreeIfNeeded()
            thieu += Self.nutKhongNhan(k).map { "\(tien): \($0)" }
        }
        XCTAssertTrue(thieu.isEmpty, "nút không có nhãn trợ năng: \(Set(thieu).sorted())")
    }

    /// Nhãn phải là TIẾNG VIỆT — §9.2 nói rõ. Một nhãn `"close"` giữa một giao diện tiếng Việt
    /// là chỗ trình đọc màn hình đổi giọng giữa câu.
    func testNhanTroNangLaTiengViet() {
        let t = EideThanhTab()
        t.mo("Main")
        t.layoutSubtreeIfNeeded()
        let nhan = Self.nhanTroNang(t)
        XCTAssertTrue(nhan.contains { $0.hasPrefix("Đóng ") },
                      "nút ✕ không có nhãn tiếng Việt — \(nhan)")
    }

    // MARK: - §9.3 modal ASK

    /// **Esc = lựa chọn AN TOÀN, không bao giờ = đồng ý.** Người bấm Esc là người muốn thoát
    /// khỏi một hộp thoại, không phải người vừa cân nhắc xong.
    func testEscLaVeAnToanChuKhongPhaiDongY() {
        let m = EideModalHoi(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        var chon: Bool?
        m.onChon = { chon = $0 }
        m.mo(maCho: "g1", cap: "code.modify", tep: "/kho/main.c", vi: "")
        m.cancelOperation(nil)
        XCTAssertEqual(chon, false, "Esc duyệt cho tác tử ghi đè")
        XCTAssertTrue(m.isHidden)
    }

    /// Enter cũng không được = đồng ý: nút mặc định là vế AN TOÀN.
    func testNutMacDinhLaVeAnToan() {
        let m = EideModalHoi(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        m.mo(maCho: "g1", cap: "code.modify", tep: "/kho/main.c", vi: "")
        let macDinh = Self.nutCoPhim(m, "\r")
        XCTAssertEqual(macDinh, EideModalHoi.NHAN_AN_TOAN,
                       "Enter gõ vội duyệt cho tác tử ghi đè — \(macDinh ?? "không nút nào")")
    }

    // MARK: - §6.1 đúng hai lựa chọn

    /// "Không lựa chọn thứ ba" là nguyên văn §6.1. Mọi lựa chọn thứ ba người ta hay nghĩ ra đều
    /// là một cách mất việc.
    func testDungHaiLuaChonKhongCoThuBa() {
        let m = EideModalHoi(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        m.mo(maCho: "g1", cap: "code.modify", tep: "/kho/main.c", vi: "buffer bẩn")
        XCTAssertEqual(m.nhanNut.count, 2)
        XCTAssertEqual(m.nhanNut[0], EideModalHoi.NHAN_THUAN)
        XCTAssertEqual(m.nhanNut[1], EideModalHoi.NHAN_AN_TOAN)
        XCTAssertEqual(Self.nut(m).count, 2, "modal có nút thứ ba: \(Self.nut(m))")
    }

    /// **Không có tệp bẩn trong cửa sổ này thì ĐỪNG hứa lưu.** Vế đầu khi ấy chỉ cho tác tử chạy
    /// tiếp, và nhãn phải nói đúng điều đó.
    func testKhongCoBoDemBanThiKhongHuaLuu() {
        let m = EideModalHoi(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        m.mo(maCho: "g1", cap: "code.modify", tep: nil, vi: "")
        XCTAssertNotEqual(m.nhanNut[0], EideModalHoi.NHAN_THUAN)
        XCTAssertTrue(Self.chu(m).contains("không lưu hộ được gì"), Self.chu(m))
    }

    /// Modal chỉ mở MỘT lần cho một mục. `_lamMoi()` chạy sau mỗi lần duyệt, mỗi lần hoàn tác và
    /// mỗi lần một lượt chạy đổi trạng thái — mở vô điều kiện thì nó dựng lại ngay sau khi người
    /// vừa đóng.
    func testModalKhongDungLaiNgaySauKhiNguoiDong() {
        let m = EideModalHoi(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        m.mo(maCho: "g1", cap: "c", tep: nil, vi: "")
        XCTAssertEqual(m.dangHoi, "g1")
        m.dong()
        XCTAssertEqual(m.dangHoi, "", "đóng rồi mà vẫn báo đang hỏi")
    }

    // MARK: - §9.4 giảm chuyển động

    /// Hoạt ảnh LỚN NHẤT trong cửa sổ — khối 272 pt trượt lên xuống — phải theo cờ của hệ điều
    /// hành. Hai chỗ nhấp nháy nhỏ đã theo từ đầu; chỗ này thì chưa, tức người bật cờ vì chuyển
    /// động làm họ chóng mặt vẫn nhận đúng chuyển động mạnh nhất.
    func testDoiChieuCaoVanDungDuNgayCaKhiGiamChuyenDong() {
        let d = EideDock(frame: NSRect(x: 0, y: 0, width: 900, height: 220))
        d.datCao(.thuGon, buoc: true)
        XCTAssertEqual(d.cao, .thuGon, "bỏ hoạt ảnh làm mất luôn phép đổi chiều cao")
        d.datCao(.moRong, buoc: true)
        XCTAssertEqual(d.cao, .moRong)
    }

    // MARK: - phụ

    /// Nút bấm được mà KHÔNG có chữ nào đọc ra: không tiêu đề, không nhãn trợ năng.
    private static func nutKhongNhan(_ v: NSView) -> [String] {
        var ra: [String] = []
        if let b = v as? NSButton, !v.isHidden, b.action != nil {
            let tieu = b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string
            let nhan = b.accessibilityLabel() ?? ""
            // **`accessibilityLabel()` mặc định TRẢ VỀ CHÍNH `title`.** Bản đầu của bài này chỉ
            // hỏi "nhãn có rỗng không", nên nó xanh cho đúng những nút nó sinh ra để bắt: `▁` có
            // nhãn `▁`. Một ký hiệu đơn không phải một nhãn — trình đọc màn hình phát ra một âm
            // vô nghĩa, và người dùng bàn phím không biết nút ấy làm gì.
            let nhanThat = !nhan.isEmpty && nhan != tieu
            if tieu.count <= 2 && !nhanThat { ra.append(tieu.isEmpty ? "(nút không chữ)" : tieu) }
        }
        for c in v.subviews where !c.isHidden { ra += nutKhongNhan(c) }
        return ra
    }

    private static func nhanTroNang(_ v: NSView) -> [String] {
        var ra: [String] = []
        if let n = v.accessibilityLabel(), !n.isEmpty { ra.append(n) }
        for c in v.subviews { ra += nhanTroNang(c) }
        return ra
    }

    private static func nut(_ v: NSView) -> [String] {
        var ra: [String] = []
        if let b = v as? NSButton, !v.isHidden, b.action != nil { ra.append(b.title) }
        for c in v.subviews where !c.isHidden { ra += nut(c) }
        return ra
    }

    private static func nutCoPhim(_ v: NSView, _ phim: String) -> String? {
        if let b = v as? NSButton, b.keyEquivalent == phim { return b.title }
        for c in v.subviews { if let x = nutCoPhim(c, phim) { return x } }
        return nil
    }

    private static func chu(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                          : t.attributedStringValue.string) + " "
        }
        if let b = v as? NSButton {
            ra += (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string) + " "
        }
        for c in v.subviews { ra += chu(c) }
        return ra
    }
}
