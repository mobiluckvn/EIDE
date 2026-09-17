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

    func testMANmoHINHnayDOCtuSOcaiCHUkhongTUcauHINH() {
        // [DEV-093] ĐÓNG 15/09/2026. Bản cũ đọc `project.status` + `models.yaml`, tức đọc CẤU
        // HÌNH: nó nói tác tử ĐƯỢC PHÉP dùng mô hình nào, không nói nó ĐÃ dùng gì. Hai câu ấy
        // khác nhau ở đúng chỗ người trả tiền quan tâm.
        //
        // Nay đọc `view.timeline` và lọc `model.call` — mỗi bản ghi có role, tokens, cost_usd.
        let v = ModelsView()
        v.capNhat(ketQua: ["events": [
            ["kind": "model.call", "data": ["role": "librarian", "tokens_in": 1200,
                                            "tokens_out": 340, "cost_usd": 0.42]],
        ]])
        XCTAssertEqual(v.chiPhiHomNay, 0.42, accuracy: 0.001)
        let chu = chuTrongThan(v)
        XCTAssertTrue(chu.contains("librarian"), chu)
        XCTAssertTrue(chu.contains("1200"), chu)
        XCTAssertFalse(chu.contains("DEV-093"), "khoảng trống đã đóng, đừng còn trỏ tới nó: \(chu)")
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

    func testMOIcongCUAPOL17hienDU_khongChiCaiDangTAC() throws {
        // Chỉ hiện cổng đang tắc thì người dùng thấy danh sách ngắn và không biết nó ngắn vì
        // mọi thứ trôi chảy hay vì màn hình chỉ biết bấy nhiêu.
        //
        // Danh sách cổng ĐỌC TỪ `rules.yaml`, không chép tay. Bản trước của bài này liệt kê
        // chín tên ngay trong mã test — tức mắc đúng lỗi mà chú thích của `congTheoThuTu` cảnh
        // báo, chỉ ở phía kiểm: cả hai bên cùng chép từ một trí nhớ, nên cả hai cùng thiếu `*`
        // và bài kiểm vẫn xanh trong khi màn hình báo động giả.
        let f = EideE2ETests.gocKho.appendingPathComponent("docs/spec/policy/rules.yaml")
        let yaml = try String(contentsOf: f, encoding: .utf8)
        var congSpec = Set<String>()
        for dong in yaml.split(separator: "\n") where dong.contains("gate:") {
            let phan = dong.split(separator: ":", maxSplits: 1)
            guard phan.count == 2 else { continue }
            congSpec.insert(phan[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'")))
        }
        XCTAssertFalse(congSpec.isEmpty, "không đọc được cổng nào từ rules.yaml")

        let ma = Set(FlowMapView.congTheoThuTu.map(\.ma))
        XCTAssertEqual(ma, congSpec,
                       "màn Hành trình lệch với POL-17 — thiếu: \(congSpec.subtracting(ma)), "
                       + "thừa: \(ma.subtracting(congSpec))")

        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [], "autonomy": "A3"])
        XCTAssertEqual(v.soDangCho, 0)
        XCTAssertEqual(v.soDong, ma.count, "mọi cổng phải hiện đủ kể cả khi rỗng")
    }

    func testMUCchoNAMduoiDUNGcongCUAno() {
        let v = FlowMapView()
        v.capNhat(ketQua: ["items": [
            ["gate": "G3", "gate_id": "g_12", "reason": "diff #23"],
            ["gate": "G-FACT", "gate_id": "g_13", "reason": "3 fact bạc"],
        ], "autonomy": "A2"])
        XCTAssertEqual(v.soDangCho, 2)
        // Đếm theo bảng cổng chứ không viết cứng: thêm một cổng vào POL-17 là việc hợp lệ, và
        // một con số cứng ở đây biến việc ấy thành một bài test đỏ ở chỗ không liên quan.
        XCTAssertEqual(v.soDong, FlowMapView.congTheoThuTu.count + 2)
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
        XCTAssertEqual(man.count, 26, "bảng UXD-13 §2 đổi số màn — 23 gốc + NhatKy (DEV-107), "
                       + "XungDot và LamRo (DEV-109)")

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

/// Mọi màn phải MỞ ĐƯỢC bằng ít nhất một đường.
///
/// `EideManDayDuTests` kiểm màn nào đã có khung nhìn. Bài này kiểm chuyện khác hẳn và dễ bỏ
/// sót hơn: khung nhìn ấy có với tới được không. Ba màn trong bảng UXD-13 §2 không có năng lực
/// nào trỏ tới — `FlowMap` khai `nang_luc: []`, `Models` khai `policy`/`gateway` (không khớp
/// quy ước `ns.*` hay `ns.name`), `Trạng thái/khung` khai `policy.set_autonomy` nhưng màn 1 đã
/// nhận năng lực ấy trước qua mẫu `policy.*`. Không có lối mở theo tên màn thì `ModelsView` và
/// `FlowMapView` là mã chết: dựng xong, có test, và không cách nào mở ra.
final class EideMoManTests: XCTestCase {

    private static var gocKho: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func bangMan() throws -> [(ten: String, caps: [String])] {
        let f = Self.gocKho.appendingPathComponent("docs/spec/ui/screens.json")
        let ds = try JSONSerialization.jsonObject(with: try Data(contentsOf: f))
            as? [[String: Any]] ?? []
        return ds.map { (($0["man_hinh"] as? String) ?? "",
                         ($0["nang_luc"] as? [String]) ?? []) }
    }

    func testKHONGmanNAOkhaiNangLucRONG() throws {
        // Bài này TỪNG khẳng định `["FlowMap"]` — màn duy nhất khai `nang_luc: []` — và ghi rằng
        // sửa được thì là tin tốt. Sửa ngày 17/09/2026: bảng §2 nay khai `policy.decide` cho
        // FlowMap, đúng thứ panel vẫn nạp mặc định cho màn ấy.
        //
        // Nhưng KHÔNG vì thế mà lối mở theo TÊN màn thành dư thừa, và đó là chỗ bài cũ đoán sai:
        // `_man_hinh()` lấy màn ĐẦU TIÊN khớp, mà màn 1 đã nhận cả `policy.*`. Nên `policy.decide`
        // vẫn trỏ về Chat, và `/FlowMap` vẫn là đường duy nhất mở màn ấy. Xem DEV-122.
        let trong = try bangMan().filter { $0.caps.isEmpty }.map(\.ten)
        XCTAssertEqual(trong, [], "màn khai nang_luc rỗng: \(trong)")
    }

    func testMOImanTRONGbangMOduocBANGtenCUAno() {
        // Tên trong `tienManDaDung` chính là thứ người gõ sau dấu "/". Không trùng nhau và
        // không rỗng — hai điều kiện để `_moTheoTenMan` khớp đúng một màn.
        let ten = EidePanel.tienManDaDung
        XCTAssertEqual(Set(ten).count, ten.count, "có tên màn trùng nhau")
        XCTAssertFalse(ten.contains(where: \.isEmpty))
        for t in ten { XCTAssertFalse(t.contains(" ") && t != "Trạng thái/khung", t) }
    }
}
