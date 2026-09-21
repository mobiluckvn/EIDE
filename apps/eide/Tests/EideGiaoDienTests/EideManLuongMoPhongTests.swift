import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S3 Bản đồ luồng · S16 Mô phỏng** — hai màn cuối không cần phần cứng.
@MainActor
final class EideManLuongMoPhongTests: XCTestCase {

    // MARK: - bản đồ pha

    /// Tám pha, đến TỪ TÀI LIỆU. Có một bài kiểm Python đọc lại `bpd.js` để đối chiếu; bài này
    /// chỉ giữ hình dạng phía Swift.
    func testTamPhaVaTraNguocDuocPhaCuaMotNangLuc() {
        XCTAssertEqual(EideBanDoPha.PHA.count, 8)
        XCTAssertEqual(EideBanDoPha.PHA.map(\.ma), ["P0", "P1", "P2", "P3", "P4", "P5", "P6", "P7"])
        XCTAssertEqual(EideBanDoPha.phaCua("chat.parse_intent"), "P0")
        XCTAssertEqual(EideBanDoPha.phaCua("kg.build"), "P1")
    }

    /// **`nil` là một câu trả lời, không phải chỗ trống.** BPD xếp 68 trong 244 năng lực vào tám
    /// quy trình; phần còn lại là năng lực phụ trợ. Gán bừa chúng vào một pha là nói với người
    /// dùng rằng dự án đang ở chỗ khác chỗ nó đang ở.
    func testNangLucNgoaiTamQuyTrinhTraNil() {
        XCTAssertNil(EideBanDoPha.phaCua("view.artifacts"))
        XCTAssertNil(EideBanDoPha.phaCua("khong-co-nang-luc-nay"))
    }

    /// Pha hiện tại = pha của lời gọi GẦN NHẤT có trong bản đồ. `view.timeline` sắp tăng dần.
    func testPhaHienTaiLaLoiGoiGanNhatCoTrongBanDo() {
        let (dem, hienTai, ngoai) = EideManLuong.demTheoPha([
            ["cap": "chat.parse_intent"],
            ["cap": "kg.build"],
            ["cap": "view.artifacts"],       // ngoài tám quy trình
        ])
        XCTAssertEqual(hienTai, "P1", "lấy nhầm lời gọi ngoài bản đồ làm pha hiện tại")
        XCTAssertEqual(dem["P0"], 1)
        XCTAssertEqual(dem["P1"], 1)
        XCTAssertEqual(ngoai, 1)
    }

    /// Con số "ngoài pha" phải trả về, không được nuốt: bỏ nó đi là để người đọc tưởng tám pha
    /// phủ hết mọi việc tác tử làm, rồi đọc "P3: 0" thành "chưa sinh mã".
    func testS3NoiRaSoLoiGoiNgoaiPha() async {
        let m = EideManLuong()
        await m.nap { ten, _ in
            guard ten == "view.timeline" else { return ["status": "done", "result": [String: Any]()] }
            return ["status": "done", "result": ["events": [
                ["cap": "chat.ground", "kind": "cap.run.start"],
                ["cap": "view.artifacts", "kind": "cap.run.start"],
            ]]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("ĐANG Ở P0"), van)
        XCTAssertTrue(van.contains("1 lời gọi KHÔNG thuộc pha nào"), van)
        XCTAssertTrue(van.contains("màn Nhật ký (S2) mới phủ"), "không chỉ chỗ xem đủ — \(van)")
    }

    func testS3RongThiChiDuongRa() async {
        let m = EideManLuong()
        await m.nap { _, _ in ["status": "done", "result": ["events": [Any]()]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có lời gọi năng lực nào"), van)
        XCTAssertTrue(van.contains("P0–P7"), van)
    }

    // MARK: - S16 Mô phỏng

    /// **`unverified` KHÔNG phải `failed`** — phần đáng nhớ nhất của cả khối mô phỏng. "Firmware
    /// làm sai" và "EIDE chưa nhìn thấy được" là hai câu dẫn tới hai việc khác nhau.
    func testBaTrangThaiKyVongKhongGopLamHai() {
        XCTAssertTrue(EideManMoPhong.oKetQua("passed").contains("đạt"))
        XCTAssertTrue(EideManMoPhong.oKetQua("failed").contains("TRƯỢT"))
        let cua = EideManMoPhong.oKetQua("unverified")
        XCTAssertTrue(cua.contains("CHƯA QUAN SÁT"), cua)
        XCTAssertFalse(cua.contains("TRƯỢT"), "gộp unverified vào failed — \(cua)")
    }

    /// Hết giờ khác chạy xong: một lượt bị `timeout` cắt ngang vẫn có thể báo "đạt" cho những
    /// kỳ vọng đã kiểm trước đó, nhưng nó chưa chạy hết kịch bản.
    func testHetGioKhacChayXong() {
        XCTAssertTrue(EideManMoPhong.oKetThuc("timeout").contains("HẾT GIỜ"))
        XCTAssertEqual(EideManMoPhong.oKetThuc("exit"), "chạy xong")
    }

    /// **Màn KHÔNG tự chạy `sim.run` khi mở.** R0 không có nghĩa là rẻ: nó khởi động engine,
    /// nạp firmware và chạy tới hết `duration_s`.
    func testMoManKhongTuChayMoPhong() async {
        var daGoi: [String] = []
        let m = EideManMoPhong()
        await m.nap { ten, tham in
            daGoi.append((tham["id"] as? String) ?? ten)
            return ["status": "done", "result": ["events": [Any]()]]
        }
        XCTAssertFalse(daGoi.contains("sim.run"), "tự chạy mô phỏng lúc mở màn — \(daGoi)")
        XCTAssertTrue(Self.chu(m).contains("chưa có lượt mô phỏng nào"), Self.chu(m))
    }

    func testS16HienLuotGanNhatVaBangKyVong() async {
        let m = EideManMoPhong()
        await m.nap(Self.loiCoLuot())
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("qemu-system-avr"), van)
        XCTAssertTrue(van.contains("CHƯA QUAN SÁT ĐƯỢC"), van)
        XCTAssertTrue(van.contains("1/2 kỳ vọng CHƯA QUAN SÁT ĐƯỢC"), "thiếu băng cảnh báo — \(van)")
        XCTAssertTrue(van.contains("sửa một chỗ không hỏng"), "không nói hậu quả của việc gộp — \(van)")
        XCTAssertTrue(van.contains("HẾT GIỜ"), van)
    }

    /// `sim.run` cũng ghi `tool.report`, nên màn Công cụ tự tạo (S23) không lọc thì nó hiện ra
    /// ở đó như một công cụ tác tử tự viết.
    func testSimRunKhongLotVaoBangCongCuTuTao() async {
        let m = EideManCongCu()
        await m.nap { ten, _ in
            guard ten == "view.timeline" else { return ["status": "done", "result": [String: Any]()] }
            return ["status": "done", "result": ["events": [
                ["kind": "tool.report", "at": "2026-09-21T08:00:00+00:00",
                 "data": ["tool": "sim.run", "passed": true]],
                ["kind": "tool.report", "at": "2026-09-21T08:01:00+00:00",
                 "data": ["tool": "crc16", "passed": true]],
            ]]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("crc16"), van)
        XCTAssertFalse(van.contains("sim.run"),
                       "năng lực dựng sẵn lọt vào bảng công cụ TỰ TẠO — \(van)")
    }

    func testHaiManDaNoiVaKhaiBaoNghe() {
        for (tien, ma) in [("FlowMap", "S3"), ("Sim", "S16")] {
            XCTAssertNotNil(EidePhien.MAN[tien], "`\(tien)` chưa vào bảng màn")
            XCTAssertEqual(EideManHinhDS.man(tien)?.ma, ma)
            XCTAssertNotNil(EideDangKySuKien.BANG[tien], "`\(tien)` chưa khai báo nghe gì")
        }
    }

    private static func loiCoLuot() -> EideGoi {
        { ten, _ in
            guard ten == "view.timeline" else { return ["status": "done", "result": [String: Any]()] }
            return ["status": "done", "result": ["events": [
                ["kind": "tool.report", "at": "2026-09-21T09:00:00+00:00", "data": [
                    "tool": "sim.run", "passed": false, "log_ref": "cache/sim/uart.log",
                    "metrics": [
                        "engine": "qemu-system-avr", "scenario": "sim/dht22.yaml",
                        "feature": "F-01", "duration_s": 5, "terminated_by": "timeout",
                        "n_passed": 1, "n_unverified": 1,
                        "expect": [
                            ["expect": "uart chứa OK", "channel": "uart", "status": "passed"],
                            ["expect": "gpio PB5 lên 1", "channel": "gpio",
                             "status": "unverified", "reason": "engine không có kênh gpio"],
                        ],
                    ],
                ]],
            ]]]
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
