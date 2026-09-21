import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S5 — Hộ chiếu chip.** Mỗi bài ghim một cách màn này có thể sai mà vẫn trông đúng.
@MainActor
final class EideManHoChieuTests: XCTestCase {

    // MARK: - định dạng

    /// `project.set_target` ghim CẢ phiên bản; `passport.query` lọc theo tiền tố `chip:<part>`.
    /// Hỏi kèm `@1.2.0` thì bộ lọc không khớp fact nào, và màn báo "chưa có fact" cho một hộ
    /// chiếu đầy đủ — một câu đúng ngữ pháp và sai hoàn toàn.
    func testBoPhienBanKhoiMaChip() {
        XCTAssertEqual(EideManHoChieu.boPhienBan("st.stm32f411ce@1.2.0"), "st.stm32f411ce")
        XCTAssertEqual(EideManHoChieu.boPhienBan("st.stm32f411ce"), "st.stm32f411ce")
    }

    /// Địa chỉ thanh ghi ở hệ 10 là con số không ai đối chiếu được với datasheet.
    func testDiaChiRaHeMuoiSau() {
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(1_070_055_424, "base_address"), "0x3FC7C000")
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(4, "offset"), "0x04")
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(0, "reset_value"), "0x00")
        // Vị từ KHÔNG phải địa chỉ thì giữ nguyên hệ 10 — `2` chân GPIO không phải `0x02`.
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(2, "pin_count"), "2")
    }

    /// Ngân sách RAM người ta so bằng KiB; script linker thì cần đúng số byte. Giữ cả hai.
    func testKichThuocGiuCaKiBLanByte() {
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(401_408, "memory_size"), "392 KiB (401408)")
        XCTAssertEqual(EideManHoChieu.giaTriTheoViTu(512, "memory_size"), "512")
    }

    /// **Trạng thái thắng tầng.** Một fact `gold` đang mâu thuẫn mà hiện là "vàng" là lời mời
    /// tin một con số đang có hai giá trị.
    func testTrangThaiCanhBaoThangTang() {
        XCTAssertEqual(EideManHoChieu.nhanTang("gold", "conflict"), "⚠ XUNG ĐỘT")
        XCTAssertEqual(EideManHoChieu.nhanTang("gold", "verified"), "vàng")
        XCTAssertEqual(EideManHoChieu.nhanTang("silver", "reviewed"), "bạc")
        XCTAssertEqual(EideManHoChieu.nhanTang("bronze", "verified"), "đồng")
    }

    /// `normalized` KHÔNG phủ định fact, nên nó không được nuốt tầng. Trên hộ chiếu
    /// ATmega328P cả 287 fact đều vàng+normalized: nuốt tầng thì dòng tóm tắt ("vàng 287") và
    /// cột TẦNG ("chưa duyệt") mâu thuẫn nhau, và cả hai mâu thuẫn với chính cổng hằng số —
    /// vốn cho fact vàng đi qua kể cả khi chưa duyệt.
    func testChuaDuyetKhongNuotTang() {
        XCTAssertEqual(EideManHoChieu.nhanTang("gold", "normalized"), "vàng · chưa duyệt")
        XCTAssertEqual(EideManHoChieu.nhanTang("bronze", "normalized"), "đồng · chưa duyệt")
    }

    /// **`0` và `1` không phải `false` và `true`.** `(0 as NSNumber) as? Bool` thành công trên
    /// Darwin, nên một nhánh Bool đứng trước nhánh số nuốt mọi 0/1 trong dữ liệu. `bit_range`
    /// của `ACSR/field:ACIS` là `[0, 1]` — hai bit đầu — và màn từng in ra `[false, true]`.
    func testSoKhongVaMotKhongBienThanhBool() {
        XCTAssertEqual(EideManHoChieu.giaTri([0, 1]), "[0, 1]")
        XCTAssertEqual(EideManHoChieu.giaTri([0, 0]), "[0, 0]")
        XCTAssertEqual(EideManHoChieu.giaTri(1), "1")
        // Bool THẬT thì vẫn phải ra chữ — nhầm hướng kia cũng là nhầm.
        XCTAssertEqual(EideManHoChieu.giaTri(true), "true")
        XCTAssertEqual(EideManHoChieu.giaTri(NSNumber(value: false)), "false")
    }

    /// Mọi dòng thuộc cùng một chip, nên tiền tố `chip:<part>/` chỉ đẩy phần khác nhau ra khỏi
    /// bề rộng cột.
    func testChuTheBoTienToChip() {
        XCTAssertEqual(
            EideManHoChieu.chuTheNgan("chip:st.stm32f411ce/periph:I2C1/reg:CR1",
                                      part: "st.stm32f411ce"),
            "periph:I2C1/reg:CR1")
        XCTAssertEqual(EideManHoChieu.chuTheNgan("chip:st.stm32f411ce", part: "st.stm32f411ce"),
                       "(chip)")
    }

    /// Trang VÀ bbox: trang đưa người tới chỗ, bbox nói con số đọc từ một Ô TRONG BẢNG chứ
    /// không phải do mô hình đoán từ văn xuôi.
    func testViTriCoCaTrangVaBbox() {
        XCTAssertEqual(EideManHoChieu.viTri(["page": 42, "bbox": [72, 530, 180, 14]]),
                       "tr.42 [72,530,180,14]")
        XCTAssertEqual(EideManHoChieu.viTri(["page": 7]), "tr.7")
        XCTAssertEqual(EideManHoChieu.viTri(nil), "—")
    }

    /// `src_ee2e3dd3…` không nói gì với ai — `citations` mang sẵn `uri` để nối.
    func testONguonHienTenTepChuKhongPhaiBamNguon() {
        let uri = EideManHoChieu.banDoNguon([
            ["source_id": "src_ee2e", "uri": "/kho/ds/stm32f411-rm0383.pdf"],
        ])
        let o = EideManHoChieu.oNguon(
            ["source_id": "src_ee2e", "locator": ["page": 42, "bbox": [72, 530]]], uri: uri)
        XCTAssertEqual(o, "stm32f411-rm0383.pdf · tr.42 [72,530]")
        XCTAssertEqual(EideManHoChieu.oNguon(["source_id": "khong-co"], uri: uri), "khong-co")
    }

    /// Một nút mở ra lỗi Finder tệ hơn một nút không có.
    func testChiMoTepCoThat() {
        XCTAssertNil(EideManHoChieu.duongTep("/khong/ton/tai-\(UUID().uuidString).pdf"))
        XCTAssertNil(EideManHoChieu.duongTep("https://st.com/rm0383.pdf"))
        XCTAssertNotNil(EideManHoChieu.duongTep(NSTemporaryDirectory()))
    }

    // MARK: - màn chạy trên một lõi giả

    /// Chưa ghim chip → đúng câu mà UXC-31 §8 S5 quy định, và nó phải nêu CẢ HAI đường ra.
    func testChuaGhimChipThiNoiDungHaiDuongRa() async {
        let m = EideManHoChieu()
        await m.nap { ten, tham in
            XCTAssertEqual(ten, "caps.invoke")
            XCTAssertEqual(tham["id"] as? String, "project.status")
            return ["status": "done", "result": ["report": ["target": [String: Any]()]]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa ghim chip"), van)
        XCTAssertTrue(van.contains("target.detect"), van)
        XCTAssertTrue(van.contains("S4"), van)
    }

    /// **Bài chính.** Màn phải hỏi `passport.query` bằng mã chip ĐÃ RỤNG phiên bản, và bảng
    /// phải mang đủ bốn thứ UXC-31 đòi: hệ 16, tầng, nguồn kèm trang, và ⚠ cho ô mâu thuẫn.
    func testHoiDungPartVaHienDuBonThuUXCDoi() async {
        var partDaHoi: String?
        let m = EideManHoChieu()
        await m.nap { ten, tham in
            XCTAssertEqual(ten, "caps.invoke")
            switch tham["id"] as? String {
            case "project.status":
                return ["status": "done", "result": ["report": ["target": Self.MUC_TIEU]]]
            case "passport.query":
                partDaHoi = (tham["params"] as? [String: Any])?["part"] as? String
                return ["status": "done", "result": Self.KET_QUA]
            default:
                XCTFail("gọi năng lực ngoài hợp đồng: \(tham)")
                return [:]
            }
        }
        XCTAssertEqual(partDaHoi, "st.stm32f411ce", "hỏi kèm @phiên bản thì không khớp fact nào")

        let van = Self.chu(m)
        XCTAssertTrue(van.contains("0x40005400"), "địa chỉ không ra hệ 16 — \(van)")
        XCTAssertTrue(van.contains("⚠ XUNG ĐỘT"), "ô mâu thuẫn không tự nói ra — \(van)")
        XCTAssertTrue(van.contains("S8"), "băng cảnh báo không trỏ sang màn Xung đột — \(van)")
        XCTAssertTrue(van.contains("rm0383.pdf"), "cột nguồn không hiện tên tệp — \(van)")
        XCTAssertTrue(van.contains("tr.42"), "cột nguồn không hiện số trang — \(van)")
        XCTAssertTrue(van.contains("vàng 1"), "không tóm tắt theo tầng — \(van)")
        XCTAssertTrue(van.contains("st.stm32f411ce@1.2.0"), "không nói chip đang ghim — \(van)")
    }

    /// **Bảng tầng và cổng hằng số trả lời hai câu khác nhau.** Mọi fact vừa `passport.import`
    /// đều mang `status = normalized`, nên một màn chỉ hiện "vàng 2 · bạc 0 · đồng 1" đang nói
    /// một câu đúng mà người đọc hiểu thành câu sai: rằng có hai con số dùng được ngay.
    func testNoiRaBaoNhieuFactChuaQuaDuocCongHangSo() async {
        let m = EideManHoChieu()
        await m.nap { _, tham in
            (tham["id"] as? String) == "project.status"
                ? ["status": "done", "result": ["report": ["target": Self.MUC_TIEU]]]
                : ["status": "done", "result": Self.KET_QUA]
        }
        let van = Self.chu(m)
        // f1 vàng+verified qua; f2 bạc+conflict chặn; f3 đồng+normalized chặn.
        XCTAssertTrue(van.contains("2/3 fact CHƯA dùng được"), van)
        XCTAssertTrue(van.contains("constant_guard"), van)
    }

    /// Luật trên màn phải là ĐÚNG luật của cổng, không phải một luật gần giống.
    func testLuatHangSoChepDungCODE04() {
        XCTAssertTrue(EideManHoChieu.quaDuocGuard(["tier": "gold", "status": "normalized"]),
                      "fact vàng đi qua kể cả khi chưa duyệt — TC-04")
        XCTAssertTrue(EideManHoChieu.quaDuocGuard(["tier": "silver", "status": "reviewed"]))
        XCTAssertFalse(EideManHoChieu.quaDuocGuard(["tier": "silver", "status": "normalized"]),
                       "fact bạc chưa duyệt phải bị chặn — TC-06")
    }

    /// `target.chip` là tên TRẦN; thứ `project.set_target` ghim nằm ở `target.pins.chip` kèm
    /// `@phiên bản`. Đọc nhầm khoá là bỏ mất đúng điều PROJECT-06 tồn tại để nói.
    func testHienPHIENBANDaGhimChuKhongChiTenChip() async {
        let m = EideManHoChieu()
        await m.nap { _, tham in
            (tham["id"] as? String) == "project.status"
                ? ["status": "done", "result": ["report": ["target": Self.MUC_TIEU]]]
                : ["status": "done", "result": Self.KET_QUA]
        }
        XCTAssertTrue(Self.chu(m).contains("st.stm32f411ce@1.2.0"), Self.chu(m))
    }

    /// `@?` = đã ghim chip nhưng CHƯA có hộ chiếu để ghim phiên bản. Fact vẫn tra ra, nên
    /// không có gì trên màn tự nói ra chuyện ấy nếu màn không nói.
    func testChuaCoHoChieuThiNoiRaChuKhongImLang() async {
        let m = EideManHoChieu()
        var mt = Self.MUC_TIEU
        mt["pins"] = ["chip": "st.stm32f411ce@?"]
        await m.nap { _, tham in
            (tham["id"] as? String) == "project.status"
                ? ["status": "done", "result": ["report": ["target": mt]]]
                : ["status": "done", "result": Self.KET_QUA]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("CHƯA GHIM"), van)
        XCTAssertTrue(van.contains("passport.diff"), van)
    }

    /// Hợp đồng PASSPORT-02 hứa "< 200 ms". Một ngưỡng mà giao diện không bao giờ hiện là một
    /// ngưỡng không ai biết lúc nó thôi đúng.
    func testQuaHanDoTreThiNoiRa() async {
        let m = EideManHoChieu()
        var kq = Self.KET_QUA
        kq["latency_ms"] = 950
        await m.nap { _, tham in
            (tham["id"] as? String) == "project.status"
                ? ["status": "done", "result": ["report": ["target": ["chip": "st.stm32f411ce"]]]]
                : ["status": "done", "result": kq]
        }
        XCTAssertTrue(Self.chu(m).contains("QUÁ HẠN"), Self.chu(m))
    }

    /// Ghim được chip mà store rỗng là một trạng thái RIÊNG: ghim một chip không tự kéo tri
    /// thức về, và câu "chưa ghim chip" ở đây sẽ đẩy người đi sửa một thứ không hỏng.
    func testGhimRoiMaStoreRongThiNoiDungLyDo() async {
        let m = EideManHoChieu()
        await m.nap { _, tham in
            (tham["id"] as? String) == "project.status"
                ? ["status": "done", "result": ["report": ["target": ["chip": "st.stm32f411ce"]]]]
                : ["status": "done", "result": ["facts": [], "citations": [],
                                                "tiers": [String: Any](), "latency_ms": 3]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có fact nào"), van)
        XCTAssertFalse(van.contains("chưa ghim chip"), "nhầm hai trạng thái rỗng — \(van)")
    }

    /// `view.provenance` trả CẢ chuỗi supersede. Mắt xích thứ hai trở đi là fact ĐÃ BỊ THAY —
    /// hiện nó ngang hàng với fact hiện hành là nói rằng cả hai đều đang đúng.
    func testChuoiNguonPhanBietHienHanhVoiDaThay() {
        let m = EideManHoChieu()
        m.hienChuoi([
            ["source": ["uri": "/kho/ds/rm0383-rev6.pdf"], "locator": ["page": 42],
             "method": "table", "confirmed_by": "congvt"],
            ["source": ["uri": "/kho/ds/rm0383-rev3.pdf"], "locator": ["page": 40],
             "method": "table"],
        ])
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("hiện hành"), van)
        XCTAssertTrue(van.contains("đã thay (1 bước trước)"), van)
        XCTAssertTrue(van.contains("congvt"), "không nói ai đã duyệt — \(van)")
    }

    /// Màn mới phải có mặt trong bảng màn đã nối, kẻo nó rơi vào nhánh "chưa nối dữ liệu" và
    /// trông y hệt một màn chưa làm.
    func testManDaNoiVaoBangMan() {
        XCTAssertNotNil(EidePhien.MAN[EideManHoChieu.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManHoChieu.tien)?.ma, "S5")
    }

    /// **NT2 không được đẩy một màn ra khỏi chính nó.** S5 gọi `project.status` để biết chip đã
    /// ghim; `project.status` thuộc màn Tổng quan. Trước bản sửa 20/09, mở S5 nhảy thẳng sang
    /// S1 và ảnh chụp ra một màn Tổng quan thân trống.
    func testLoiGoiCuaCHINHManKhongTuDayManDi() {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        let ph = EidePhien(khung: k)
        // Đồng hồ tiêm: bài này đo NT2 chứ không đo §2C.3, nên nó phải đứng NGOÀI cửa sổ giữ màn
        // 20 giây. Không có dòng này, bài đỏ vì một luật khác đúng — và đó là một bài kiểm nói
        // sai tên thứ nó vừa bắt được.
        var gio = Date(timeIntervalSince1970: 1_000_000)
        ph.dongHo = { gio }
        ph.datBanDoMan(["project.status": "Main", "passport.query": "Passport"])
        ph.moMan("Passport", boiTacTu: false)
        XCTAssertEqual(k.vungLamViec.dangMo, "Passport")

        // Lời gọi ĐƠN LẺ của chính màn: `cap.run.*`, không `run_id` chuỗi, không `node_id`.
        ph.napSuKien("event.run.progress", ["kind": "cap.run.start", "cap": "project.status"])
        XCTAssertEqual(k.vungLamViec.dangMo, "Passport",
                       "màn tự đẩy mình đi vì chính lời gọi nó phát ra để vẽ")

        // Còn một BƯỚC THẬT của tác tử thì vẫn kéo màn theo — NT2 phải giữ nguyên tác dụng.
        gio += EidePhien.GIU_MAN + 5
        ph.napSuKien("event.run.progress",
                     ["kind": "run.step_started", "run_id": "r1", "cap": "project.status"])
        XCTAssertEqual(k.vungLamViec.dangMo, "Main")
    }

    // MARK: - phụ

    /// `report.target` chép đúng hình dạng LÕI TRẢ VỀ, đo 20/09/2026 bằng
    /// `scripts`-ngoài-kho trên một dự án thật: có CẢ `chip` trần lẫn `pins.chip` mang phiên
    /// bản. Hai khoá ấy khác nhau, và màn đọc nhầm khoá thì mất đúng điều PROJECT-06 nói.
    private static let MUC_TIEU: [String: Any] = [
        "chip": "st.stm32f411ce",
        "board": NSNull(),
        "isa": "armv7e-m",
        "pins": ["isa": "armv7e-m", "chip": "st.stm32f411ce@1.2.0"],
    ]

    /// Một kết quả `passport.query` đủ bốn hình dạng màn phải xử lý: địa chỉ, xung đột, fact
    /// không có nguồn, và fact có locator đầy đủ.
    private static let KET_QUA: [String: Any] = [
        "facts": [
            ["id": "f1", "subject": "chip:st.stm32f411ce/periph:I2C1", "predicate": "base_address",
             "value": 1_073_763_328, "tier": "gold", "status": "verified",
             "source_id": "src_ee2e", "locator": ["page": 42, "bbox": [72, 530, 180, 14]]],
            // `memory_size`, không phải `ram_bytes`: `predicate` là một enum ĐÓNG 16 giá trị
            // trong `docs/spec/data/json/fact.json`, và `passport.import` từ chối tên ngoài
            // enum bằng E6001. Một fixture giao diện mang vị từ không tồn tại được là một
            // fixture không bao giờ gặp lại ngoài đời.
            ["id": "f2", "subject": "chip:st.stm32f411ce", "predicate": "memory_size",
             "value": 131_072, "tier": "silver", "status": "conflict",
             "source_id": "src_ee2e", "locator": ["page": 17]],
            ["id": "f3", "subject": "chip:st.stm32f411ce", "predicate": "package",
             "value": "LQFP48", "tier": "bronze", "status": "normalized"],
        ],
        "citations": [["source_id": "src_ee2e", "uri": "/kho/ds/rm0383.pdf", "kind": "pdf"]],
        "tiers": ["gold": 1, "silver": 1, "bronze": 1],
        "latency_ms": 12,
    ]

    /// Mọi chữ hiện trên màn — kể cả chữ nằm trong chuỗi có thuộc tính của bảng.
    static func chu(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += t.attributedStringValue.string.isEmpty ? t.stringValue
                                                         : t.attributedStringValue.string
        }
        if let b = v as? NSButton { ra += " " + b.title }
        if let p = v as? NSPopUpButton { ra += " " + p.itemTitles.joined(separator: " ") }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}
