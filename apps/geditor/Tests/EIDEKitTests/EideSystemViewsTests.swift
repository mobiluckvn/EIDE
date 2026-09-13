import AppKit
import XCTest

@testable import EIDEKit

/// Năm màn hệ thống — UXD-13 màn 17, 19, 20, 21, 22.
///
/// Năm màn này nói về chính EIDE: công cụ nó tự viết, gói tri thức nó nạp, mô hình nó gọi,
/// công cụ ngoài nó chạy, và những chỗ nó phải dừng chờ người. Mọi thứ ở đây **mở rộng quyền
/// của máy**, nên test giữ đúng một điều: không quyền nào được mở rộng mà màn hình im lặng.
final class EideSystemViewsTests: XCTestCase {

    private func chuTrongThan(_ m: ManHinhCoSo) -> String {
        let nhan = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
        let hang = m.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }
        return (nhan + hang.compactMap { ($0 as? NSTextField)?.stringValue }
                     + hang.compactMap { ($0 as? NSButton)?.title }).joined(separator: " ")
    }

    // MARK: - Màn 17: ToolForge

    func testTACDUNGngoaiKHAIbaoCHANviecDANGKY() {
        // Đăng ký công cụ thành `user.*` là đưa nó vào Router, nơi tác tử gọi được mà không hỏi
        // ai nữa. `effects_ok: false` nghĩa là công cụ làm việc bản khai của nó không nói.
        let v = ToolForgeView()
        v.capNhat(ketQua: [
            "tool_id": "t_svd_split",
            "effects": ["đọc tệp trong dự án"],
            "observed_effects": ["đọc tệp trong dự án", "mở kết nối mạng"],
            "effects_ok": false,
        ])
        XCTAssertEqual(v.tacDungKhop, false)
        XCTAssertEqual(v.soTacDungLa, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("NGOÀI KHAI BÁO"), v.tomTat.stringValue)
        XCTAssertTrue(chuTrongThan(v).contains("Đừng đăng ký"), chuTrongThan(v))
        XCTAssertEqual(v.tomTat.textColor, EideToken.Mau.bad)
    }

    func testCHUAchayTESTkhacVoiCHAYraFALSE() {
        let v = ToolForgeView()
        v.capNhat(ketQua: ["tool_id": "t_1", "effects": ["đọc tệp"]])
        XCTAssertNil(v.tacDungKhop)
        XCTAssertFalse(v.tomTat.stringValue.contains("NGOÀI KHAI BÁO"))
    }

    func testTOOLSPECkhongCOtieuCHInghiemThuBInoiRA() {
        // Không có `acceptance[]` thì `tool.test` chẳng có gì để chấm, và "test đã chạy" trở
        // thành một câu không mang thông tin.
        let v = ToolForgeView()
        v.capNhat(ketQua: ["spec": ["name": "svd_split", "purpose": "tách SVD lớn"]])
        XCTAssertTrue(chuTrongThan(v).contains("KHÔNG có tiêu chí"), chuTrongThan(v))
    }

    func testCONGCUdungLAIhienTRUOCkhiVIETmoi() {
        // TOOL-01 tìm cái đã có, vì một kho công cụ tự sinh không kiểm soát sẽ đầy những hàm
        // gần giống nhau.
        let v = ToolForgeView()
        v.capNhat(ketQua: [
            "spec": ["name": "x", "acceptance": ["a"]],
            "reuse": [["tool_id": "t_cu", "score": 0.88]],
        ])
        let dau = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSTextField)?.stringValue }.first
        XCTAssertEqual(dau, "dùng lại: t_cu")
    }

    // MARK: - Màn 19: Registry

    func testGOIkhongCHUkyKHONGbamNAPduoc() {
        // Một gói tri thức là hàng nghìn fact sẽ thành hằng số trong firmware qua
        // `code.constant_guard` — chữ ký ở đây bảo vệ đúng thứ cả tầng tri thức được dựng lên
        // để bảo vệ.
        let v = RegistryView()
        v.capNhat(ketQua: ["packages": [
            ["id": "eide.stm32f4", "version": "1.2.0", "facts": 13_494, "signed": true],
            ["id": "ai.tu-che", "version": "0.1", "facts": 40],
        ]])
        XCTAssertEqual(v.soGoi, 2)
        XCTAssertEqual(v.soKhongKy, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("KHÔNG CHỮ KÝ"), v.tomTat.stringValue)

        // Gói chưa ký KHÔNG được là nút bấm: một cú bấm là nạp nó vào store.
        let nut = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { $0 as? NSButton }.map(\.identifier?.rawValue)
        XCTAssertEqual(nut.compactMap { $0 }, ["eide.stm32f4"])
    }

    func testPUBLISHfalseKHONGphaiLOImaLAchoNGUOIduyet() {
        // REGISTRY-04: nội bộ tự động, công khai HỎI.
        let v = RegistryView()
        v.capNhat(ketQua: ["published": false])
        XCTAssertTrue(chuTrongThan(v).contains("cần anh duyệt"), chuTrongThan(v))
    }

    // MARK: - Màn 20: Models — màn nói ra chính khoảng trống của nó

    func testMANmoHINHnoiRAphanKHONGcoTRONGapi15() {
        // Vẽ ra một bảng mô hình đẹp đẽ từ dữ liệu không có là cách tệ nhất để lấp một khoảng
        // trống giữa hai tài liệu.
        let v = ModelsView()
        v.capNhat(ketQua: ["report": ["cost_today": 0.42], "autonomy": "A3"])
        XCTAssertEqual(v.chiPhiHomNay, 0.42, accuracy: 0.001)
        let chu = chuTrongThan(v)
        XCTAssertTrue(chu.contains("API-15 chưa"), chu)
        XCTAssertTrue(chu.contains("model.call"), chu)
        XCTAssertTrue(chu.contains("DEV-093"), "phải trỏ tới mục DEVIATIONS: \(chu)")
    }

    func testDUNGkhanHIENoMANmoHinh() {
        let v = ModelsView()
        v.capNhat(ketQua: ["report": ["cost_today": 0], "stopped": true])
        XCTAssertTrue(v.tomTat.stringValue.contains("ĐANG DỪNG KHẨN"), v.tomTat.stringValue)
    }

    // MARK: - Màn 21: Môi trường

    func testCONGCUthieuHIENkemCACHcai() {
        // Trên máy Mac, cái người dùng tìm thấy đầu tiên thường là bản Homebrew KHÔNG kèm
        // newlib — cài xong vẫn không dựng được, và thông báo lỗi lúc ấy nói về một tệp header
        // chứ không nói về gói cài sai.
        let v = EnvView()
        v.capNhat(ketQua: ["report": [
            ["tool": "cmake", "ok": true, "version": "3.29"],
            ["tool": "arm-none-eabi-gcc", "ok": false, "required": ">=12"],
        ]])
        XCTAssertEqual(v.soThieu, 1)
        XCTAssertTrue(chuTrongThan(v).contains("bấm để xem cách cài"), chuTrongThan(v))

        // Công cụ thiếu lên trước công cụ đủ.
        let dau = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews.first }
            .compactMap { ($0 as? NSButton)?.title ?? ($0 as? NSTextField)?.stringValue }.first
        XCTAssertEqual(dau, "arm-none-eabi-gcc")
    }

    func testPHIENBANtroiLAcanhBAOnang() {
        // Phiên bản công cụ trôi nghĩa là firmware dựng hôm nay khác firmware dựng tuần trước
        // từ cùng một mã — và không có gì trong mã thay đổi để giải thích điều đó.
        let v = EnvView()
        v.capNhat(ketQua: [
            "lock": ["cmake": "3.29"],
            "drift": [["tool": "arm-none-eabi-gcc", "locked": "13.2", "found": "14.1"]],
        ])
        XCTAssertEqual(v.soTroi, 1)
        XCTAssertTrue(v.tomTat.stringValue.contains("PHIÊN BẢN TRÔI"), v.tomTat.stringValue)
        XCTAssertTrue(chuTrongThan(v).contains("firmware dựng ra sẽ khác"), chuTrongThan(v))
    }

    // MARK: - Màn 22: FlowMap

    func testCHINcongCUAPOL17hienDU_khongChiCaiDangTAC() {
        // Chỉ hiện cổng đang tắc thì người dùng thấy danh sách ngắn và không biết nó ngắn vì
        // mọi thứ trôi chảy hay vì màn hình chỉ biết bấy nhiêu.
        XCTAssertEqual(FlowMapView.congTheoThuTu.count, 9)
        let ma = Set(FlowMapView.congTheoThuTu.map(\.ma))
        for g in ["G-SRC", "G-FACT", "G1", "G-TOOL", "G3", "G4", "G5", "G-OPS", "G-WL"] {
            XCTAssertTrue(ma.contains(g), "thiếu cổng \(g) của POL-17")
        }

        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [], "autonomy": "A3"])
        XCTAssertEqual(v.soDangCho, 0)
        XCTAssertEqual(v.soDong, 9, "chín cổng phải hiện đủ kể cả khi rỗng")
    }

    func testMUCchoNAMduoiDUNGcongCUAno() {
        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [
            ["gate": "G3", "gate_id": "g_12", "reason": "diff #23"],
            ["gate": "G-FACT", "gate_id": "g_13", "reason": "3 fact bạc"],
        ], "autonomy": "A2"])
        XCTAssertEqual(v.soDangCho, 2)
        XCTAssertEqual(v.soDong, 11)   // 9 cổng + 2 mục
        XCTAssertTrue(v.tomTat.stringValue.contains("2 mục chờ anh"), v.tomTat.stringValue)
    }

    func testCONGlaBInoiRAchuKhongBInuotDi() {
        // Một mục chờ ở cổng không có trong POL-17 nghĩa là tài liệu và mã đã lệch nhau, và màn
        // này là chỗ duy nhất nhìn thấy điều đó.
        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [["gate": "G-BIA-RA", "gate_id": "g_99"]]])
        XCTAssertTrue(chuTrongThan(v).contains("KHÔNG có trong POL-17"), chuTrongThan(v))
    }

    func testDUNGkhanNOIRAcachCHAYtiep() {
        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [], "stopped": true])
        XCTAssertTrue(v.dangDungKhan)
        XCTAssertTrue(chuTrongThan(v).contains("Đặt lại mức tự chủ"), chuTrongThan(v))
    }

    // MARK: - Chung

    func testNAMmanDEUnoiRAkhiRONGvaCOnhanTroNang() {
        for m in [ToolForgeView() as ManHinhCoSo, RegistryView(), ModelsView(), EnvView(),
                  FlowMapView()] {
            m.capNhat(ketQua: [:])
            XCTAssertFalse(chuTrongThan(m).isEmpty, "\(type(of: m)) để trống khi rỗng")
            XCTAssertEqual(m.accessibilityRole(), .group)
            XCTAssertFalse((m.accessibilityLabel() ?? "").isEmpty)
        }
    }
}

/// Đối chiếu số màn đã dựng với bảng nguồn `docs/spec/ui/screens.json`.
///
/// Con số "23/23 màn" chỉ có nghĩa nếu nó được ĐO lại mỗi lần chạy test. Một dòng trong tài
/// liệu tiến độ đúng được đúng một ngày — đã xảy ra thật ngày 08/09 (cộng dồn thay vì đo lại,
/// lệch 2) và ngày 12/09 (đếm bằng grep, báo 1/23 trong khi thật là 3/23). Bài test này đọc
/// thẳng bảng nguồn, nên nó đỏ ngay hôm UXD-13 thêm màn thứ 24.
final class EideManDayDuTests: XCTestCase {

    /// Tests/EIDEKitTests → Tests → apps/geditor → apps → EIDE
    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func tenMan() throws -> [String] {
        let f = Self.gocKho.appendingPathComponent("docs/spec/ui/screens.json")
        let d = try Data(contentsOf: f)
        let ds = try JSONSerialization.jsonObject(with: d) as? [[String: Any]] ?? []
        return ds.compactMap { $0["man_hinh"] as? String }
    }

    func testMOImanTRONGscreensJsonDEUcoKhungNhin() throws {
        let man = try tenMan()
        XCTAssertEqual(man.count, 23, "bảng UXD-13 §2 đổi số màn")

        let thieu = man.filter { ten in
            !EidePanel.tienManDaDung.contains { ten.hasPrefix($0) }
        }
        XCTAssertTrue(thieu.isEmpty, "chưa dựng khung nhìn cho: \(thieu)")
    }

    func testKHONGcoTIENtoTHUAtrongBANGman() throws {
        // Chiều ngược lại: một tiền tố không khớp màn nào nghĩa là panel giữ một khung nhìn
        // không ai mở tới được — mã chết trông y như mã đang chạy.
        let man = try tenMan()
        let thua = EidePanel.tienManDaDung.filter { tien in
            !man.contains { $0.hasPrefix(tien) }
        }
        XCTAssertTrue(thua.isEmpty, "tiền tố không khớp màn nào trong screens.json: \(thua)")
    }
}
