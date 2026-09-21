import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Bố cục khung — UXC-31 §2.2 và §2.3 (tiêu chí N7).**
///
/// Hai mục này không đo được bằng cách đọc chữ trên màn hình: chúng là những con số chỉ xuất
/// hiện sau khi Auto Layout giải xong. Bản cũ của giao diện tụt vùng làm việc xuống 70 pt mà mọi
/// bài kiểm đơn vị vẫn xanh — đúng khoảng trống mà bài này lấp.
@MainActor
final class EideBoCucTests: XCTestCase {

    private func khung(_ rong: CGFloat, _ cao: CGFloat) -> EideKhung {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: rong, height: cao))
        k.layoutSubtreeIfNeeded()
        return k
    }

    // MARK: - §2.3 tiêu chí N7

    /// **N7: cửa sổ cao 900 pt, vùng trao đổi mức chuẩn → vùng làm việc còn ≥ 50 % chiều cao.**
    ///
    /// Đây là bất biến chống lại đúng một kiểu trôi: mỗi lần thêm một dải ngang (băng cảnh báo,
    /// dải dữ liệu cũ, một hàng nút nữa) thì vùng làm việc mất vài pt, không ai thấy, và sau mười
    /// lần thì màn hình chính còn một khe hẹp giữa hai thanh.
    func testN7VungLamViecConItNhatMotNuaOCuaSoCao900() {
        let k = khung(1456, 900)
        XCTAssertEqual(k.dock.cao, .chuan, "bài này chỉ có nghĩa ở vùng trao đổi mức chuẩn")
        let ty = k.vungLamViec.frame.height / 900
        XCTAssertGreaterThanOrEqual(ty, 0.5,
            String(format: "vùng làm việc chỉ còn %.0f%% (%.0f pt / 900 pt)",
                   ty * 100, k.vungLamViec.frame.height))
    }

    /// Vùng trao đổi MỞ RỘNG thì N7 không còn áp dụng — nhưng vùng làm việc vẫn phải trên SÀN
    /// 200 pt, con số `EideKhung` ghim để cửa sổ không tự co lại quanh nội dung.
    func testMoRongVungTraoDoiVanKhongAnHetVungLamViec() {
        let k = khung(1456, 900)
        k.dock.datCao(.moRong, buoc: true)
        k.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(k.vungLamViec.frame.height, 200,
            "vùng làm việc tụt xuống \(k.vungLamViec.frame.height) pt")
    }

    /// Dải "Dữ liệu cũ" bật lên cũng không được ăn thủng sàn ấy.
    func testDaiDuLieuCuKhongAnThungSanVungLamViec() {
        let k = khung(1456, 700)
        k.datDuLieuCu(true, tre: 30)
        k.layoutSubtreeIfNeeded()
        XCTAssertGreaterThanOrEqual(k.vungLamViec.frame.height, 200)
        XCTAssertTrue(k.chuDaiCu.contains("30 giây"), k.chuDaiCu)
    }

    // MARK: - §2.2 cỡ tối thiểu và dải hẹp

    func testCoToiThieuDungConSoCuaTaiLieu() {
        XCTAssertEqual(EideKhung.CO_TOI_THIEU, NSSize(width: 1100, height: 700))
        XCTAssertEqual(EideKhung.RONG_COT_PHAI_HEP, 44)
    }

    /// Chạm ngưỡng thì cột phải thu còn 44 pt — **và KHÔNG biến mất**. "Không được ẩn hẳn" là
    /// điều khoản đáng kể nhất của §2.2: hàng đợi CHỜ TÔI là chỗ duy nhất người dùng biết tác tử
    /// đang đợi mình.
    func testChamNguongThiCotPhaiThuChuKhongAn() {
        let k = khung(1100, 800)
        XCTAssertTrue(k.cotPhai.hep, "cửa sổ chạm ngưỡng mà cột phải vẫn rộng")
        XCTAssertEqual(k.cotPhai.frame.width, EideKhung.RONG_COT_PHAI_HEP, accuracy: 0.5)
        XCTAssertFalse(k.cotPhai.isHidden, "cột phải bị ẩn hẳn — trái §2.2")
        XCTAssertGreaterThan(k.cotPhai.frame.height, 100, "cột phải bị bóp về 0 chiều cao")
    }

    /// Ba con số vẫn đọc được ở dải hẹp — đó là toàn bộ lý do dải ấy tồn tại.
    func testDaiHepVanHienDuBaConSo() {
        let c = EideCotPhai(frame: NSRect(x: 0, y: 0, width: 44, height: 700))
        c.datCho([(ma: "g1", tieuDe: "a", ly: "b"), (ma: "g2", tieuDe: "c", ly: "d")])
        c.datHoanTac([(ma: "u1", nhan: "x", han: "y")])
        c.datHep(true)
        let van = Self.chu(c)
        XCTAssertTrue(van.contains("2"), "mất số CHỜ TÔI — \(van)")
        XCTAssertTrue(van.contains("1"), "mất số HOÀN TÁC — \(van)")
        XCTAssertTrue(van.contains("0"), "khối rỗng biến mất thay vì hiện 0 — \(van)")
    }

    /// Cửa sổ rộng thì cột phải đầy đủ. Nửa còn lại của cùng một luật.
    func testCuaSoRongThiCotPhaiDayDu() {
        let k = khung(1456, 838)
        XCTAssertFalse(k.cotPhai.hep)
        XCTAssertEqual(k.cotPhai.frame.width, EideKhung.RONG_COT_PHAI, accuracy: 0.5)
    }

    /// **Người đã tự bấm gấp thì bề ngang cửa sổ thôi quyết định thay họ.** Không có luật này,
    /// cột vừa gấp xong sẽ tự bung ra ở lần `layout()` kế tiếp — tức ngay lập tức — và nút gấp
    /// trông như hỏng.
    func testNguoiTuGapThiKeoCuaSoKhongBungLai() {
        let k = khung(1456, 838)
        k.nguoiDoiCotPhai(true)
        XCTAssertTrue(k.cotPhai.hep)
        k.frame = NSRect(x: 0, y: 0, width: 1600, height: 838)
        k.layoutSubtreeIfNeeded()
        XCTAssertTrue(k.cotPhai.hep, "cột tự bung ra sau khi người vừa cố ý gấp nó lại")
    }

    /// Nút gấp có ở CẢ HAI trạng thái. Gấp được mà không bung lại được thì người dùng mất hẳn
    /// hàng đợi cho tới lần khởi động sau.
    func testNutGapBungLaiDuocOCaHaiTrangThai() {
        let c = EideCotPhai(frame: NSRect(x: 0, y: 0, width: 236, height: 700))
        var xin: [Bool] = []
        c.onDoiHep = { xin.append($0) }
        XCTAssertTrue(Self.bam(c, chua: "⟩"), "không có nút gấp ở trạng thái rộng")
        XCTAssertTrue(c.hep)
        XCTAssertTrue(Self.bam(c, chua: "⟨"), "không có nút bung ở trạng thái hẹp")
        XCTAssertFalse(c.hep)
        XCTAssertEqual(xin, [true, false])
    }

    // MARK: - phụ

    private static func bam(_ v: NSView, chua: String) -> Bool {
        if let b = v as? NSButton {
            let van = b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string
            if van.contains(chua), let a = b.action {
                b.sendAction(a, to: b.target)
                return true
            }
        }
        for c in v.subviews where bam(c, chua: chua) { return true }
        return false
    }

    private static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField, !t.isHidden { ra += t.stringValue + " " }
        for c in v.subviews where !c.isHidden { ra += chu(c) }
        return ra
    }
}
