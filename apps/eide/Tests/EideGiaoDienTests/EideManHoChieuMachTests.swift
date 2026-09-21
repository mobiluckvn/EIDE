import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S6 — Hộ chiếu mạch.** Màn cuối của nhóm TRI THỨC, và là chỗ tri thức chạm vào đồng.
@MainActor
final class EideManHoChieuMachTests: XCTestCase {

    /// Đúng câu UXC-31 §8 S6 quy định cho trạng thái rỗng, và nó phải chỉ được đường ra.
    func testChuaGhimBoardThiNoiDungCauUXCquyDinh() async {
        let m = EideManHoChieuMach()
        await m.nap { _, tham in
            XCTAssertEqual(tham["id"] as? String, "project.status")
            return ["status": "done", "result": ["report": ["target": [String: Any]()]]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có schematic/BOM"), van)
        XCTAssertTrue(van.contains("S4"), van)
    }

    /// Ghim board mà store chưa có net là một trạng thái RIÊNG: bản đồ chân dựng từ netlist chứ
    /// không từ tên board, nên "chưa có schematic" ở đây sẽ đẩy người đi làm lại việc đã làm.
    func testGhimBoardMaChuaCoNetThiNoiDungLyDo() async {
        let m = EideManHoChieuMach()
        await m.nap { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "project.status":
                return ["status": "done", "result": ["report": ["target": ["board": "uno-v3"]]]]
            default:
                return ["status": "failed", "cap": "diagram.pinmap",
                        "error": ["eide_code": "E2000", "message": "Không thấy store"]]
            }
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có net nào"), van)
        XCTAssertFalse(van.contains("chưa có schematic/BOM"), "nhầm hai trạng thái rỗng — \(van)")
    }

    /// **Bảng chân và `check_pins` là HAI nguồn.** Cờ `conflict` của bảng chỉ nói có/không; loại
    /// và mức nặng chỉ `check_pins` có — mà đó là thứ quyết định sửa ngay hay ghi chú lại.
    func testOKiemPhanBietChanVoiCanhBao() {
        XCTAssertEqual(EideManHoChieuMach.oKiem([], coCo: false), "ok")
        XCTAssertTrue(EideManHoChieuMach.oKiem(
            [["kind": "af_conflict", "severity": "blocker"]], coCo: true).hasPrefix("⛔ CHẶN"))
        XCTAssertTrue(EideManHoChieuMach.oKiem(
            [["kind": "missing_pullup", "severity": "major"]], coCo: true).hasPrefix("⚠"))
    }

    /// Hai nguồn LỆCH nhau — cờ bật mà `check_pins` không nêu chân ấy — thì nói ra chứ không
    /// chọn một bên: một trong hai đường đang sai, và giấu đi thì không ai biết đường nào.
    func testHaiNguonLechNhauThiNoiRaChuKhongChonMotBen() {
        let s = EideManHoChieuMach.oKiem([], coCo: true)
        XCTAssertTrue(s.contains("lệch nhau"), s)
        XCTAssertNotEqual(s, "ok")
    }

    /// Bảng chân đủ năm cột UXC-31 đòi — net, chân, chức năng (AF), linh kiện, kiểm xung đột.
    func testBangChanDuCotUXCDoi() async {
        let m = EideManHoChieuMach()
        await m.nap(Self.loiCoMach())
        let van = Self.chu(m)
        for x in ["PB6", "I2C1_SCL", "SCL", "U2 BME280", "⛔ CHẶN"] {
            XCTAssertTrue(van.contains(x), "thiếu `\(x)` — \(van)")
        }
        XCTAssertTrue(van.contains("2 CHÂN · 1 XUNG ĐỘT"), van)
    }

    /// Xung đột mức CHẶN phải nói HẬU QUẢ, không chỉ đếm: người đọc cần biết vì sao không được
    /// bỏ qua nó.
    func testBangChanNoiHauQuaChuKhongChiDem() async {
        let m = EideManHoChieuMach()
        await m.nap(Self.loiCoMach())
        XCTAssertTrue(Self.chu(m).contains("firmware nối sai chân"), Self.chu(m))
    }

    /// **Nút khai báo lab chỉ sống khi CẢ HAI ô được tích.** BOARD-05 trả E1000 khi thiếu một,
    /// và một nút bấm được rồi mới báo lỗi là một nút dạy người dùng bỏ qua thông báo.
    func testNutLabChiSongKhiDuCaHaiLoiKhai() async {
        let m = EideManHoChieuMach()
        await m.nap(Self.loiCoMach())
        XCTAssertFalse(m.nutLabSongKhong, "nút sống khi chưa tích gì")
        m.tichDeTest(khongCoCoCau: true, hanDong: false)
        XCTAssertFalse(m.nutLabSongKhong, "một lời khai là đủ — trái BOARD-05")
        m.tichDeTest(khongCoCoCau: true, hanDong: true)
        XCTAssertTrue(m.nutLabSongKhong)
    }

    /// **Ba trạng thái lab, không hai** — v1.3, [DEV-135].
    ///
    /// Tới 21/09 màn phải nói "CHƯA đọc lại được" vì không năng lực nào đọc ra `boards.<id>`.
    /// Nay `policy.rules` trả `boards`, và `nil` vẫn là một câu trả lời riêng: board CHƯA được
    /// khai, khác hẳn "khai là không".
    func testBaTrangThaiLabKhongGopLamHai() {
        let chua = EideManHoChieuMach.cauTrangThai(nil, board: "nucleo-f411")
        XCTAssertTrue(chua.contains("CHƯA được khai"), chua)

        let day = EideManHoChieuMach.cauTrangThai(
            ["lab": true, "has_actuator": false, "reason": "bàn thí nghiệm"],
            board: "nucleo-f411")
        XCTAssertTrue(day.contains("mạch lab **có**"), day)
        XCTAssertTrue(day.contains("chấp hành **không**"), day)
        XCTAssertTrue(day.contains("bàn thí nghiệm"), day)

        // Thiếu MỘT trường không được đoán thành `false`: BOARD-05 đòi cả hai lời khai vì
        // "không có cơ cấu chấp hành nhưng chưa hạn dòng" vẫn cháy được.
        let thieu = EideManHoChieuMach.cauTrangThai(["lab": true], board: "b1")
        XCTAssertTrue(thieu.contains("chấp hành **CHƯA khai**"), thieu)
    }

    /// Màn đọc trạng thái ấy THẬT, không chỉ có hàm dựng câu.
    func testManDocTrangThaiLabQuaPolicyRules() async {
        let m = EideManHoChieuMach()
        let nen = Self.loiCoMach()
        await m.nap { ten, tham in
            if ten == "policy.rules" || (tham["id"] as? String) == "policy.rules" {
                return ["status": "done",
                        // `uno-v3` — ĐÚNG board mà `loiCoMach()` ghim. Một khoá khác
                        // sẽ cho `nil`, và bài kiểm khi ấy xanh vì nhánh "chưa khai" chứ không
                        // vì màn đọc được gì.
                        "result": ["boards": ["uno-v3": ["lab": true,
                                                         "has_actuator": true]]]]
            }
            return try await nen(ten, tham)
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Trạng thái hiện tại"), van)
        XCTAssertFalse(van.contains("CHƯA đọc lại được"), van)
    }

    /// `touches_code` là thứ quyết định phương án rẻ hay đắt: đổi chân trên mạch là việc của mỏ
    /// hàn, đổi chân đã có mã passing dùng tới là một lần sửa mã kèm chạy lại test.
    func testPhuongAnChamMaDangChayPhaiDuocDanhDau() {
        let m = EideManHoChieuMach()
        m.hienPhuongAn("PB3", [
            ["change": "remap AF sang PB5", "cost": "thấp", "touches_code": false],
            ["change": "đổi sang PA7", "cost": "trung bình", "touches_code": true],
        ])
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("2 phương án cho PB3"), van)
        XCTAssertTrue(van.contains("CHẠM MÃ đang chạy"), van)
    }

    /// BOARD-04 nêu "chưa tra được chân thay thế" khi hộ chiếu chân chưa có — không đoán một
    /// tên chân. Màn phải nói tiếp: lấy hộ chiếu chân ở đâu.
    func testKhongCoPhuongAnThiChiDuongLayHoChieuChan() {
        let m = EideManHoChieuMach()
        m.hienPhuongAn("PB3", [])
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Không có phương án"), van)
        XCTAssertTrue(van.contains("S4"), van)
    }

    /// **Bảng chân rỗng không được kết thúc màn.** `diagram.pinmap` cần fact `pin_function` của
    /// hộ chiếu CHIP để ánh xạ `U1 chân 28` → `PB6`; chưa nhập datasheet chân thì bảng rỗng —
    /// trong khi `check_pins` và `constraints` vẫn chạy trên chính netlist ấy. Đo 20/09 trên một
    /// netlist thật: bảng 0 hàng, mà `check_pins` tìm ra một net I2C thiếu điện trở kéo lên.
    func testBangChanRongVanGiuRangBuocVaKhoiKhaiLab() async {
        let m = EideManHoChieuMach()
        await m.nap { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "project.status":
                return ["status": "done", "result": ["report": ["target": ["board": "mach"]]]]
            case "diagram.pinmap":
                return ["status": "done", "result": ["table": [Any]()]]
            case "board.check_pins":
                return ["status": "done", "result": ["conflicts": [
                    ["pin": "SDA", "kind": "missing_pullup", "severity": "major",
                     "detail": "net I2C không có điện trở kéo lên"]]]]
            case "board.constraints":
                return ["status": "done", "result": ["constraints": ["voltage": 3.3]]]
            default:
                return ["status": "done", "result": [String: Any]()]
            }
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa ánh xạ được chân MCU"), van)
        XCTAssertTrue(van.contains("missing_pullup"), "mất phần kiểm xung đột — \(van)")
        XCTAssertTrue(van.contains("RÀNG BUỘC"), "mất khối ràng buộc — \(van)")
        XCTAssertTrue(van.contains("MẠCH LAB"), "mất khối khai báo lab — \(van)")
        XCTAssertFalse(van.contains("Màn này đang rỗng"), "kết thúc màn khi chỉ một phần rỗng")
    }

    /// `{n khoá}` đúng cho một ô bảng fact và SAI ở bảng ràng buộc. Đo 20/09 trên netlist thật:
    /// `bus_limits · {1 khoá}` giấu mất câu `why` — mà câu ấy nói giới hạn đến TỪ ĐÂU, nên người
    /// đọc kiểm lại được thay vì phải tin.
    func testRangBuocTraiPhangToiLA_KhongRutThanhSoKhoa() {
        let ra = EideManHoChieuMach.phang([
            "bus_limits": ["i2c": ["max_khz": 400, "why": "kéo lên 4700 Ω — đủ cho Fast-mode"]],
            "reserved_pins": [String](),
            "voltage": ["rails": [String: Any]()],
        ])
        let theo = Dictionary(uniqueKeysWithValues: ra.map { ($0[0], $0[1]) })
        XCTAssertEqual(theo["bus_limits.i2c.max_khz"], "400")
        XCTAssertTrue(theo["bus_limits.i2c.why"]?.contains("Fast-mode") == true, "\(theo)")
        XCTAssertFalse(ra.contains { $0[1].contains("khoá") }, "còn ô rút thành số khoá: \(ra)")
        // Mảng rỗng vẫn phải có hàng: "không có chân dành riêng" là một câu trả lời.
        XCTAssertEqual(theo["reserved_pins"], "[]")
        // Từ điển rỗng nói "chưa có", không đếm khoá.
        XCTAssertEqual(theo["voltage.rails"], "chưa có")
    }

    func testManDaNoiVaoBangMan() {
        XCTAssertNotNil(EidePhien.MAN[EideManHoChieuMach.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManHoChieuMach.tien)?.ma, "S6")
    }

    // MARK: - phụ

    private static func loiCoMach() -> EideGoi {
        { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "project.status":
                return ["status": "done", "result": ["report": ["target": [
                    "board": "uno-v3", "chip": "microchip.atmega328p@1.0.0",
                    "pins": ["board": "uno-v3@1.0.0"]]]]]
            case "diagram.pinmap":
                return ["status": "done", "result": ["table": [
                    ["pin": "PB6", "af": "I2C1_SCL", "net": "SCL", "part": "U2 BME280",
                     "dir": "bidir", "conflict": false],
                    ["pin": "PB3", "af": "SPI1_MOSI", "net": "LED", "part": "D1",
                     "dir": "out", "conflict": true],
                ]]]
            case "board.check_pins":
                return ["status": "done", "result": ["conflicts": [
                    ["pin": "PB3", "kind": "af_conflict", "severity": "blocker",
                     "detail": "PB3 vừa là LED vừa là MOSI"],
                ]]]
            case "board.constraints":
                return ["status": "done", "result": ["constraints": [
                    "reserved_pins": ["PA13", "PA14"], "voltage": 3.3]]]
            default:
                return ["status": "done", "result": [String: Any]()]
            }
        }
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
