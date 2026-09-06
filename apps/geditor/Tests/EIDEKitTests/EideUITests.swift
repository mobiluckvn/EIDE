import AppKit
import XCTest

@testable import EIDEKit

/// WI-021 — ràng buộc giao diện của UXD-13 mà máy kiểm được.
///
/// U10 viết "tương phản ≥ 4,5:1 (WCAG 2.2 AA)". Một câu như thế trong tài liệu chỉ có giá trị
/// nếu có ai đó đo; nếu không, nó đúng vào ngày viết rồi sai dần theo từng lần đổi màu. Đây là
/// chỗ đo.
final class EideUITests: XCTestCase {

    // MARK: - U7: token đúng bộ nhận diện

    func testMauLayTuTokenChuKhongVietTay() {
        // UXD-13 §7. Nếu ai đổi tokens.json mà quên sinh lại Swift thì `make check-gen` đỏ;
        // test này chốt thêm giá trị để một lần sinh sai không lọt qua im lặng.
        XCTAssertEqual(EideToken.Mau.primary.hexString, "#B8121F")   // đỏ PTIT
        XCTAssertEqual(EideToken.Mau.accent.hexString, "#F2B705")    // vàng — việc cần người
        XCTAssertEqual(EideToken.Mau.secondary.hexString, "#2F4858") // xám xanh — tác tử
    }

    // MARK: - U10: tương phản WCAG 2.2 AA

    func testChuTrenNenDatTuongPhanAA() {
        let nen = EideToken.Mau.surface
        for (ten, mau) in [("text", EideToken.Mau.text), ("muted", EideToken.Mau.muted),
                           ("ok", EideToken.Mau.ok), ("warn", EideToken.Mau.warn),
                           ("bad", EideToken.Mau.bad)] {
            let ts = mau.tuongPhan(nen)
            XCTAssertGreaterThanOrEqual(
                ts, EideToken.tuongPhanToiThieu,
                "\(ten) trên surface chỉ đạt \(String(format: "%.2f", ts)):1, cần ≥ 4,5:1 (U10)")
        }
    }

    func testChuTrangTrenThanhTuChuDatTuongPhan() {
        // Thanh tự chủ dùng chữ trắng trên `secondary`, và khi dừng khẩn thì trên `primary`.
        // Cả hai trạng thái đều phải đọc được, không chỉ trạng thái bình thường.
        for (ten, nen) in [("secondary", EideToken.Mau.secondary), ("primary", EideToken.Mau.primary)] {
            let ts = NSColor.white.tuongPhan(nen)
            XCTAssertGreaterThanOrEqual(
                ts, EideToken.tuongPhanToiThieu,
                "chữ trắng trên \(ten) chỉ đạt \(String(format: "%.2f", ts)):1 (U10)")
        }
    }

    // MARK: - U2, U6, U9: hành vi nhìn thấy được

    @MainActor
    func testThanhTuChuNoiTrangThaiBangCHUKhongChiBangMau() {
        // U10: "không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)". Người mù màu phải đọc được
        // rằng phiên đang dừng, chứ không chỉ thấy thanh đổi sang đỏ.
        let bar = AutonomyBar()
        bar.capNhat(muc: "A3", dungKhan: true, soCho: 2, soHoanTac: 1)
        let chu = bar.subviews.compactMap { ($0 as? NSTextField)?.stringValue }.joined()
        XCTAssertTrue(chu.contains("DỪNG"), "trạng thái dừng phải nói bằng chữ: \(chu)")
        XCTAssertTrue(chu.contains("2 chờ anh"))
        XCTAssertTrue(chu.contains("1 hoàn tác"))
    }

    @MainActor
    func testNutDungKhanCoPhimTat() {
        // U6: "nút ■ Dừng khẩn ở sidebar và phím tắt ⌘⇧." — với tới được mà không cần chuột.
        let bar = AutonomyBar()
        let nut = bar.subviews.compactMap { $0 as? NSButton }.first
        XCTAssertEqual(nut?.keyEquivalent, ".")
        XCTAssertEqual(nut?.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertNotNil(nut?.accessibilityLabel())
    }

    @MainActor
    func testHangDoiRongVanNOIRARongChuKhongDeTrong() {
        // U9: "mọi panel có ba trạng thái thiết kế sẵn"; một khoảng trắng khiến người dùng
        // tưởng đang tải, và chờ một thứ không bao giờ tới.
        let q = ReviewQueueView()
        q.capNhat(cho: [], hoanTac: [])
        let chu = q.moiChu()
        XCTAssertTrue(chu.contains("Không có việc nào chờ anh"))
        XCTAssertTrue(chu.contains("Chưa có việc nào tự làm"))
    }

    @MainActor
    func testHangDoiTachHaiDanhSach() {
        // U2: "hàng đợi TÁCH 'chờ tôi' và 'đã làm — hoàn tác được'". Hai câu hỏi khác nhau.
        let q = ReviewQueueView()
        q.capNhat(cho: [["cap": "target.flash"]],
                  hoanTac: [["cap": "project.create", "deadline": "2026-09-07T03:10:00+00:00"]])
        let chu = q.moiChu()
        XCTAssertTrue(chu.contains("Chờ anh (1)"))
        XCTAssertTrue(chu.contains("target.flash"))
        XCTAssertTrue(chu.contains("Đã làm — hoàn tác được (1)"))
        XCTAssertTrue(chu.contains("project.create"))
    }

    @MainActor
    func testHoiThoaiMoRaDaCoLoiChao() {
        // U1: ChatPanel là màn hình MẶC ĐỊNH — nó phải nói được ngay khi mở, không phải một
        // ô trống chờ người đoán mình làm gì tiếp.
        let c = ChatView()
        XCTAssertTrue(c.moiChu().contains("Sẵn sàng"))
    }
}

// MARK: - tiện ích cho test

extension NSColor {
    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "?" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

extension NSView {
    /// Gom mọi chuỗi hiện trên view — cách kiểm "người dùng ĐỌC được gì", không phải "cây view
    /// có hình dạng nào".
    func moiChu() -> String {
        var ra = (self as? NSTextField)?.stringValue ?? ""
        if let tv = self as? NSTextView { ra += tv.string }
        for v in subviews { ra += " " + v.moiChu() }
        return ra
    }
}
