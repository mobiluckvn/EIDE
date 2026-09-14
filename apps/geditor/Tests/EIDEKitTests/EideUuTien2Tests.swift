import AppKit
import XCTest
@testable import EIDEKit

/// Ba mục ưu tiên 2 của USECASE §4 — gợi ý ô nhập, bảng đánh đổi, trạng thái phiên.
final class EideUuTien2Tests: XCTestCase {

    // MARK: - Mục 4 · Gợi ý cho ô nhập

    func testRUTgoiYboTIENtoChipVAphienBAN() {
        // Đo 14/09 trên dự án ESP32-C3: `passport.query` với `part: "chip:espressif.esp32c3"`
        // trả RỖNG — tiền tố `chip:` không được bỏ. Một gợi ý điền sẵn giá trị sai còn tệ hơn
        // không gợi ý, vì người dùng tin nó.
        let ds = EidePanel.rutGoiY("passport.list", ["passports": [
            ["id": "chip:espressif.esp32c3@1.0.0"],
            ["id": "chip:microchip.atmega328p@2.1.0"],
        ]])
        XCTAssertEqual(ds, ["espressif.esp32c3", "microchip.atmega328p"])
    }

    func testRUTgoiYchapNHANcaDANGchuoiTRAN() {
        let ds = EidePanel.rutGoiY("passport.list", ["passports": ["st.stm32f411ce"]])
        XCTAssertEqual(ds, ["st.stm32f411ce"])
    }

    func testRUTgoiYtinhNANGtuPROJECTstatus() {
        let ds = EidePanel.rutGoiY("project.status",
                                   ["report": ["features": [["id": "F-01"], ["id": "F-02"]]]])
        XCTAssertEqual(ds, ["F-01", "F-02"])
    }

    func testNGUONkhongBIETthiTRArongCHUkhongDOANbua() {
        // `env.detect` không mang ISA — nó nằm trong manifest. Rút bừa một trường nghe giống là
        // cách tạo ra một gợi ý sai mà không ai kiểm.
        XCTAssertEqual(EidePanel.rutGoiY("env.detect", ["env": ["os": "Darwin"]]), [])
        XCTAssertEqual(EidePanel.rutGoiY("khong.co.that", ["x": 1]), [])
    }

    func testKETQUAhongKHONGlamNOhong() {
        XCTAssertEqual(EidePanel.rutGoiY("passport.list", [:]), [])
        XCTAssertEqual(EidePanel.rutGoiY("passport.list", ["passports": "sai kiểu"]), [])
        XCTAssertEqual(EidePanel.rutGoiY("passport.list", ["passports": [123, true]]), [])
        XCTAssertEqual(EidePanel.rutGoiY("project.status", ["report": "sai"]), [])
    }

    @MainActor
    func testMOTgiaTRIduyNHATthiDIENsan() {
        // Dự án chỉ có một hộ chiếu chip thì bắt người dùng gõ lại tên nó là nghi thức thừa.
        let o = EideONhap(frame: .zero)
        var xin: [String] = []
        o.onLayGoiY = { nguon, nhan in xin.append(nguon); nhan(["espressif.esp32c3"]) }
        o.dungTu(capId: "passport.query",
                 moTa: ["input_schema": ["properties": ["part": ["type": "string"]]]])
        XCTAssertEqual(xin, ["passport.list"], "ô `part` phải xin gợi ý ngay khi dựng")
        let mong = expectation(description: "điền sẵn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { mong.fulfill() }
        wait(for: [mong], timeout: 2)
        XCTAssertEqual(o.thamSo()["part"] as? String, "espressif.esp32c3")
    }

    @MainActor
    func testNHIEUgiaTRIthiGOIYchuKHONGchonHO() {
        // Tập giá trị ở đây là MỞ — một dự án có thể tra một chip chưa có hộ chiếu. Chọn hộ là
        // chặn đúng trường hợp người dùng cần nhất.
        let o = EideONhap(frame: .zero)
        o.onLayGoiY = { _, nhan in nhan(["a.chip1", "b.chip2", "c.chip3"]) }
        o.dungTu(capId: "passport.query",
                 moTa: ["input_schema": ["properties": ["part": ["type": "string"]]]])
        let mong = expectation(description: "gợi ý")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { mong.fulfill() }
        wait(for: [mong], timeout: 2)
        XCTAssertNil(o.thamSo()["part"], "nhiều lựa chọn thì KHÔNG được chọn hộ")
    }

    @MainActor
    func testKHONGcoGOIYthiOvanGOtayDUOC() {
        let o = EideONhap(frame: .zero)
        o.onLayGoiY = { _, nhan in nhan([]) }
        o.dungTu(capId: "passport.query",
                 moTa: ["input_schema": ["properties": ["part": ["type": "string"]]]])
        o.datGiaTri("part", "tu.go.tay")
        XCTAssertEqual(o.thamSo()["part"] as? String, "tu.go.tay")
    }

    @MainActor
    func testNGHIN_HOCHIEUkhongLAMvoOgoiY() {
        let o = EideONhap(frame: .zero)
        o.onLayGoiY = { _, nhan in nhan((0..<2_000).map { "chip\($0)" }) }
        o.dungTu(capId: "passport.query",
                 moTa: ["input_schema": ["properties": ["part": ["type": "string"]]]])
        let mong = expectation(description: "nhiều")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { mong.fulfill() }
        wait(for: [mong], timeout: 3)
        XCTAssertNil(o.thamSo()["part"])
    }

    // MARK: - Mục 6 · Bảng đánh đổi

    @MainActor
    private func _chu(_ m: ManHinhCoSo) -> String {
        func quet(_ v: NSView) -> [String] {
            var ra: [String] = []
            if let t = v as? NSTextField { ra.append(t.stringValue) }
            for c in v.subviews { ra += quet(c) }
            return ra
        }
        return ([m.tomTat.stringValue] + quet(m.cot)).joined(separator: "\n")
    }

    @MainActor
    func testHIENdCAmaTRANvaDIEMchuKHONGchiKHUYENnghi() {
        // `arch.compare` là T1* — khuyến nghị của nó là ĐỀ XUẤT. Hiện mỗi dòng "khuyến nghị:
        // RTOS" thì người không có gì để không đồng ý: họ hoặc gật, hoặc đi hỏi lại từ đầu.
        let v = ReqArchView()
        v.capNhat(ketQua: ["comparison": [
            "recommendation": "super_loop",
            "scores": ["super_loop": 8.5, "rtos": 4.0],
            "matrix": [
                ["option": "super_loop", "RAM": "2 KB", "độ trễ": "thấp"],
                ["option": "rtos", "RAM": "6 KB", "độ trễ": "trung bình"],
            ],
        ]])
        let chu = _chu(v)
        for phai in ["super_loop", "rtos", "2 KB", "6 KB", "8.5", "4.0"] {
            XCTAssertTrue(chu.contains(phai), "thiếu \(phai): \(chu)")
        }
        XCTAssertTrue(chu.contains("★ super_loop"), "phương án khuyến nghị phải đánh dấu: \(chu)")
        XCTAssertTrue(chu.contains("anh quyết"), "phải nói rõ người quyết: \(chu)")
    }

    @MainActor
    func testCOdiemMAkhongCOmaTRANthiVANhienDIEM() {
        // Con số so sánh được là thứ tối thiểu người cần để không đồng ý một cách có căn cứ.
        let v = ReqArchView()
        v.capNhat(ketQua: ["comparison": ["scores": ["a": 7.0, "b": 6.9],
                                          "recommendation": "a"]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("7.0") && chu.contains("6.9"), chu)
    }

    @MainActor
    func testSOSANHrongTHInoiRA() {
        let v = ReqArchView()
        v.capNhat(ketQua: ["comparison": [:]])
        XCTAssertTrue(_chu(v).contains("rỗng"), _chu(v))
    }

    // MARK: - Mục 7 · Trạng thái phiên (M2)

    @MainActor
    func testHIENphienVAsoLUOT() {
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": [:], "session": [
            "session_id": "s_abc123", "turns": 7, "undo_items": 2, "thieu": [],
        ]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("s_abc123"), chu)
        XCTAssertTrue(chu.contains("7 lượt"), chu)
    }

    @MainActor
    func testQUYENr4hienMAUcanhBAO() {
        // Quyền R4 theo phiên cho tác tử làm một việc KHÔNG HOÀN TÁC ĐƯỢC mà không hỏi lại.
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": [:], "session": [
            "session_id": "s_1", "permits": ["target.erase_fuse"], "thieu": [],
        ]])
        XCTAssertTrue(_chu(v).contains("target.erase_fuse"), _chu(v))
        XCTAssertTrue(_chu(v).contains("R4"), _chu(v))
    }

    @MainActor
    func testTRUONGchuaCOthiNOIRAchuKHONGgiauDI() {
        // Im lặng bỏ hai trường thì khoảng trống biến mất khỏi tầm nhìn — đúng khuôn DEV-093.
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": [:], "session": [
            "session_id": "s_1", "permits": [], "board": NSNull(),
            "thieu": ["permits", "board"],
        ]])
        let chu = _chu(v)
        XCTAssertTrue(chu.contains("DEV-110"), "phải trỏ tới mục DEVIATIONS: \(chu)")
        XCTAssertTrue(chu.contains("MEM-11"), chu)
    }

    @MainActor
    func testKHONGcoPHIENthiKHONGhienGIthem() {
        let v = ProjectStatusView()
        v.capNhat(ketQua: ["report": ["cost_today": 0]])
        XCTAssertFalse(_chu(v).contains("phiên"), _chu(v))
    }
}
