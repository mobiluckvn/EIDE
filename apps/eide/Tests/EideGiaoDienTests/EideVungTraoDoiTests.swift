import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Vùng trao đổi và bộ chuyển dự án** — UXC-31 §2A.2, §2D.4, §2D.6, §2E.6.
@MainActor
final class EideVungTraoDoiTests: XCTestCase {

    private func dungKhung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }

    // MARK: - §2D.4 placeholder theo pha

    /// Mỗi pha một câu lệnh MẪU, gõ thẳng vào được. Placeholder kiểu "hãy ra lệnh cho tác tử"
    /// dạy được đúng một thứ: rằng ô này nhận chữ.
    func testPlaceholderDoiTheoPhaVaLaMotLenhGoDuoc() {
        let d = EideDock()
        d.datPha("P3")
        XCTAssertTrue(d.goiYHienTai.contains("Ví dụ:"), d.goiYHienTai)
        XCTAssertTrue(d.goiYHienTai.contains("sinh mã"), d.goiYHienTai)
        d.datPha("P5")
        XCTAssertTrue(d.goiYHienTai.contains("log serial"), d.goiYHienTai)
    }

    /// **Chưa biết pha thì về câu chung, KHÔNG đoán.** Một dự án mới tinh mà ô lệnh gợi ý "chạy
    /// mô phỏng kịch bản dht22" là nói với người dùng rằng họ đang ở một chỗ họ chưa tới.
    func testChuaBietPhaThiVeCauChungChuKhongDoan() {
        let d = EideDock()
        d.datPha("P3")
        d.datPha(nil)
        XCTAssertFalse(d.goiYHienTai.contains("Ví dụ:"), d.goiYHienTai)
        d.datPha("P99")
        XCTAssertFalse(d.goiYHienTai.contains("Ví dụ:"), "pha lạ mà vẫn gợi ý — \(d.goiYHienTai)")
    }

    func testDuPhaCuaBanDoBPD() {
        for p in EideBanDoPha.PHA {
            XCTAssertNotNil(EideDock.GOI_Y[p.ma], "pha \(p.ma) không có lệnh mẫu")
        }
    }

    /// §2D.4 vế cuối — đang chạy thì lệnh mới phải được báo là XẾP HÀNG. Không nói thì người
    /// dùng gõ lại lần nữa, và hai lệnh trùng nhau tốn tiền mô hình thật.
    func testDangChayThiLenhMoiDuocBaoXepHang() {
        let d = EideDock()
        d.dangChay = true
        d.guiDeTest("dựng firmware")
        XCTAssertTrue(Self.chu(d).contains("Xếp hàng sau lượt chạy hiện tại"), Self.chu(d))
    }

    func testKhongChayThiKhongBaoXepHang() {
        let d = EideDock()
        d.guiDeTest("dựng firmware")
        XCTAssertFalse(Self.chu(d).contains("Xếp hàng"), Self.chu(d))
    }

    // MARK: - §2D.6 thẻ Ý hiểu

    func testTheYHieuInCauVaDanhSachBuocDanhSo() {
        let t = EideTheYHieu(van: "Tôi hiểu là code_feature: DHT22. Tôi sẽ plan.create, code.write.",
                             buoc: ["plan.create", "code.write", "code.build"],
                             muc: "A2", cho: false)
        let van = Self.chu(t)
        XCTAssertTrue(van.contains("Ý HIỂU"), van)
        XCTAssertTrue(van.contains("chat.restate"), "không ghi năng lực đứng sau — \(van)")
        XCTAssertTrue(van.contains("1. `plan.create`"), "bước không đánh số — \(van)")
        XCTAssertTrue(van.contains("3. `code.build`"), van)
    }

    /// **Không có chỗ dừng thì KHÔNG hiện hai nút.** Một nút "Đúng — làm đi" đặt trên việc đã
    /// làm xong dạy người dùng rằng bấm hay không đều thế, rồi họ thôi đọc cả thẻ.
    func testKhongCoChoDungThiKhongHienHaiNut() {
        let t = EideTheYHieu(van: "x", buoc: ["a"], muc: "A2", cho: false)
        XCTAssertTrue(t.nhanNut.isEmpty, "hiện nút cho một chuỗi đã giao đi — \(t.nhanNut)")
        XCTAssertTrue(Self.chu(t).contains("tự chạy, vẫn in ý hiểu"), Self.chu(t))
    }

    /// A0/A1 và A2–A3 phải nói HAI câu khác nhau — và từ v1.3 khác nhau theo nghĩa mới.
    ///
    /// A2–A3 không hỏi là ĐÚNG hợp đồng. A0/A1 không hỏi là **bất thường**: daemon đặt
    /// `plan_only` cho hai mức ấy ([DEV-140]), nên chuỗi lẽ ra phải đang đợi; thấy câu này ở
    /// A0/A1 nghĩa là daemon đọc một mức khác mức thanh trên đang hiện.
    func testA1NoiRoDayLaBatThuongChuKhongNoiLaBinhThuong() {
        let a1 = EideTheYHieu.viSaoKhongHoi("A1")
        XCTAssertTrue(a1.contains("đã được giao đi"), a1)
        XCTAssertTrue(a1.contains("Dừng khẩn"), a1)
        let a2 = EideTheYHieu.viSaoKhongHoi("A2")
        XCTAssertTrue(a2.contains("tự chạy, vẫn in ý hiểu"), a2)
        XCTAssertFalse(a2.contains("đã được giao đi"),
                       "A2 đúng hợp đồng mà vẫn báo bất thường — \(a2)")
    }

    // MARK: - [DEV-181] thẻ HỎI trong vùng trao đổi

    private static func theHoiMau() -> EideTheHoi {
        EideTheHoi(cap: "env.check", loai: .thieuThamSo(clarId: "CL-abc123", truong: [
            .init(khoa: "isa", hoi: "Chip của thiết bị thuộc kiến trúc tập lệnh nào?",
                  luaChon: [(giaTri: "avr8", giaiThich: "ATmega, ATtiny"),
                            (giaTri: "armv7e-m", giaiThich: "STM32F4, nRF52")])]))
    }

    /// **Câu hỏi bằng tiếng người, không phải tên tham số.**
    ///
    /// Đo đúng chỗ hỏng chủ sản phẩm gặp 22/09/2026: màn hình in "cần anh cho biết: isa", và
    /// câu họ gõ lại là *"isa cho cái gì? Tôi cần bạn tư vấn mà"*. Một thẻ hỏi mà người đọc
    /// xong vẫn không biết nó hỏi gì thì chưa hơn được dòng chữ nó thay thế.
    func testTheHoiInCauHoiTiengNguoiChuKhongPhaiTenThamSo() {
        let van = Self.chu(Self.theHoiMau())
        XCTAssertTrue(van.contains("kiến trúc tập lệnh"), "không có câu hỏi tiếng người — \(van)")
        XCTAssertTrue(van.contains("env.check"), "không nói hỏi vì bước nào — \(van)")
    }

    /// Tập giá trị đóng thì hiện thành NÚT BẤM kèm giải thích — người chọn, không gõ lại.
    func testTapGiaTriDongHienThanhNutChuKhongBatGoLai() {
        let van = Self.chu(Self.theHoiMau())
        XCTAssertTrue(van.contains("avr8"), van)
        XCTAssertTrue(van.contains("ATmega"), "có giá trị mà không nói nó là chip gì — \(van)")
        XCTAssertTrue(van.contains("Trả lời"), "không có nút gửi — \(van)")
    }

    /// **Ô gõ tự do vẫn còn, và nó BỔ SUNG chứ không ghi đè lựa chọn.**
    ///
    /// Người chọn `armv7e-m` rồi gõ thêm tên bo mạch là đang nói thêm, không phải đổi ý. Ghi đè
    /// thì mất một nửa ý họ — và họ không có cách nào biết nửa ấy đã mất.
    func testOGoTuDoGopVoiLuaChonChuKhongGhiDe() {
        let t = Self.theHoiMau()
        Self.bam(t, "avr8")
        Self.go(t, "bo Arduino Uno")
        let tl = t.cauTraLoi()
        XCTAssertTrue(tl.contains("avr8"), "mất lựa chọn đã bấm — \(tl)")
        XCTAssertTrue(tl.contains("Arduino Uno"), "mất chữ người gõ thêm — \(tl)")
    }

    /// Một trường chỉ giữ MỘT giá trị: bấm `armv7e-m` sau `avr8` là đổi ý, không phải chọn cả hai.
    func testBamHaiLanTrongCungMotTruongThiGiuCaiSau() {
        let t = Self.theHoiMau()
        Self.bam(t, "avr8")
        Self.bam(t, "armv7e-m")
        let tl = t.cauTraLoi()
        XCTAssertTrue(tl.contains("armv7e-m"), tl)
        XCTAssertFalse(tl.contains("avr8"), "giữ cả hai giá trị cho một trường — \(tl)")
    }

    /// **Cổng chặn cũng hỏi NGAY Ở ĐÂY.** Chủ sản phẩm chốt 22/09/2026: *"nút duyệt hoặc phê
    /// duyệt luôn ở ô trả lời chat"*. Với người dùng, "thiếu tham số" và "cổng chặn" đều là
    /// *tác tử đang hỏi tôi*; tách đôi là bắt họ học một phân loại của hệ thống.
    func testCongChanHienNutDuyetNgayTrongVungTraoDoi() {
        let t = EideTheHoi(cap: "code.merge", loai: .congChan(
            khoa: "r1:G3", cong: "G3", quyTac: "MERGE-02", lyDo: "chưa có reviewer khác hãng"))
        XCTAssertEqual(t.nhanNut, ["Duyệt", "Từ chối"])
        let van = Self.chu(t)
        XCTAssertTrue(van.contains("G3") && van.contains("MERGE-02"), van)
        XCTAssertTrue(van.contains("reviewer"), "không nói vì sao bị chặn — \(van)")
    }

    /// **Câu trả lời rỗng thì KHÔNG gửi.** Gửi nó đi là ghi một dòng vô nghĩa vào sổ làm rõ rồi
    /// coi câu hỏi đã xong — tác tử thôi hỏi, và không ai biết nó chạy tiếp bằng dữ kiện gì.
    func testCauTraLoiRongThiKhongGui() {
        let t = Self.theHoiMau()
        var daGui = false
        t.onTraLoi = { _, _ in daGui = true }
        Self.bamNut(t, "Trả lời")
        XCTAssertFalse(daGui, "gửi một câu trả lời rỗng")
    }

    /// Bấm Trả lời thì gửi ĐÚNG mã điểm cần làm rõ — sai mã là ghi câu trả lời vào một câu hỏi
    /// khác, và cả hai câu hỏi cùng hỏng trong im lặng.
    func testBamTraLoiGuiDungMaDiemCanLamRo() {
        let t = Self.theHoiMau()
        var nhan: (String, String)?
        t.onTraLoi = { ma, van in nhan = (ma, van) }
        Self.bam(t, "avr8")
        Self.bamNut(t, "Trả lời")
        XCTAssertEqual(nhan?.0, "CL-abc123")
        XCTAssertTrue(nhan?.1.contains("avr8") ?? false, "\(nhan as Any)")
    }

    /// **Báo cáo có câu hỏi ĐỦ dữ kiện → thẻ hỏi hiện ngay trong vùng trao đổi.**
    ///
    /// Đi qua `napSuKien` chứ không gọi thẳng chỗ dựng thẻ: chủ sản phẩm nhận câu hỏi bằng
    /// `event.chat.report`, nên đó mới là đường cần xanh. Một bài kiểm gọi tắt sẽ xanh kể cả
    /// khi sự kiện không nối vào đâu — đúng lỗi đã xảy ra với `--do-nut`.
    func testBaoCaoCoCauHoiThiHIEN_O_TRA_LOI_ngayTrongVungTraoDoi() {
        let (k, ph) = dungKhung()
        ph.napSuKien("event.chat.report", [
            "run_id": "r1", "state": "asked", "done": [], "failed": [],
            "van": "nối LAN cho máy CNC",
            "waiting": [["cap": "env.check", "thieu": ["isa"], "clar_id": "CL-9",
                         "hoi": "Chip thuộc kiến trúc nào?",
                         "truong": [["khoa": "isa", "hoi": "Chip thuộc kiến trúc nào?",
                                     "lua_chon": [["gia_tri": "avr8",
                                                   "giai_thich": "ATmega"]]]]]]])
        let van = Self.chu(k.dock)
        XCTAssertTrue(van.contains("Chip thuộc kiến trúc nào?"), van)
        XCTAssertTrue(van.contains("Trả lời"), "không có ô trả lời trong vùng trao đổi — \(van)")
        XCTAssertEqual(ph.vanGanNhat, "nối LAN cho máy CNC", "không giữ câu gốc để chạy lại")
    }

    /// **Thiếu `clar_id` thì KHÔNG vẽ ô trả lời.**
    ///
    /// Một ô trả lời không biết ghi câu trả lời vào đâu tệ hơn một dòng chữ, vì nó HỨA: người
    /// dùng gõ, bấm, rồi không có gì xảy ra và họ không biết vì sao. Thà nói thẳng còn treo
    /// gì và chỉ sang tab Làm rõ.
    func testThieuMaDiemCanLamRoThiNoiThangChuKhongVeMotONutChet() {
        let (k, ph) = dungKhung()
        ph.napSuKien("event.chat.report", [
            "run_id": "r1", "state": "asked", "done": [], "failed": [],
            "waiting": [["cap": "env.check", "thieu": ["isa"], "vi": "cần anh cho biết: isa"]]])
        let van = Self.chu(k.dock)
        XCTAssertTrue(van.contains("Làm rõ yêu cầu"), "không chỉ chỗ trả lời được — \(van)")
        XCTAssertFalse(van.contains("Trả lời"), "vẽ nút Trả lời mà không có chỗ ghi — \(van)")
    }

    private static func bam(_ v: NSView, _ giaTri: String) {
        for n in nutTrong(v) where n.identifier?.rawValue.hasSuffix("|" + giaTri) == true {
            n.state = .on
            _ = n.target?.perform(n.action, with: n)
            return
        }
        XCTFail("không có nút cho giá trị \(giaTri)")
    }

    private static func bamNut(_ v: NSView, _ nhan: String) {
        for n in nutTrong(v) where n.title == nhan {
            _ = n.target?.perform(n.action, with: n)
            return
        }
        XCTFail("không có nút \(nhan)")
    }

    /// Đi HẾT cây view, không dừng ở hai tầng: ô gõ nằm trong `NSStackView` lồng trong
    /// `NSStackView`, và một đầu dò nông báo "không có ô gõ" cho một thẻ có đủ ô — đỏ vì phép
    /// đo mù, đúng thứ bẫy đã ghi ở `chu(_:)` ngay dưới.
    private static func go(_ v: NSView, _ van: String) {
        guard let o = oGoTrong(v) else { return XCTFail("không có ô gõ tự do") }
        o.stringValue = van
    }

    private static func oGoTrong(_ v: NSView) -> NSTextField? {
        if let t = v as? NSTextField, t.isEditable { return t }
        for c in v.subviews { if let t = oGoTrong(c) { return t } }
        return nil
    }

    private static func nutTrong(_ v: NSView) -> [NSButton] {
        (v as? NSButton).map { [$0] } ?? v.subviews.flatMap { nutTrong($0) }
    }

    func testCoChoDungThiDuHaiNutCuaTaiLieu() {
        let t = EideTheYHieu(van: "x", buoc: ["a"], muc: "A1", cho: true)
        XCTAssertEqual(t.nhanNut, ["Đúng — làm đi", "Sửa ý hiểu"])
    }

    func testDocMucTuChuTuChinhHuyHieu() {
        XCTAssertEqual(EidePhien.mucTu(" Tự chủ A2 "), "A2")
        XCTAssertEqual(EidePhien.mucTu(" ĐÃ DỪNG KHẨN · A0 "), "A0")
        XCTAssertNil(EidePhien.mucTu("chưa đọc được"))
    }

    // MARK: - §2E.6 báo cáo khi run kết thúc

    /// `run.cancelled` phải nói **ai huỷ, lúc nào**. Một lượt chạy biến mất không lời khiến người
    /// dùng phải đoán giữa "tôi bấm Dừng khẩn", "chính sách chặn" và "daemon chết".
    func testRunHuyNoiRoAiVaLucNao() {
        let c = EidePhien.cauHuy(["by": "human:congvt", "at": "2026-09-21T14:03:22+00:00"])
        XCTAssertTrue(c.contains("human:congvt"), c)
        XCTAssertTrue(c.contains("21/09 14:03:22"), c)
    }

    /// Thiếu khoá thì NÓI thiếu, đừng bịa. "lúc 01/01 00:00:00" cho một lượt chạy vừa bị huỷ là
    /// một con số sai trông y như một con số đúng.
    func testThieuKhoaThiNoiKhongRoChuKhongBia() {
        let c = EidePhien.cauHuy([:])
        XCTAssertTrue(c.contains("không rõ ai"), c)
        XCTAssertTrue(c.contains("không rõ lúc nào"), c)
    }

    /// **Báo cáo in ĐÚNG MỘT LẦN.** `run.done` tới nhiều lần (nghe lại sổ cái, nạp lại sau khi
    /// mất daemon), và mỗi lần in một báo cáo là vùng trao đổi đầy bản sao của cùng một việc.
    func testRunDoneLapLaiKhongInHaiLanBaoCao() {
        let (k, ph) = dungKhung()
        let xong: [String: Any] = ["kind": "run.done", "run_id": "r1", "state": "done", "done": 3]
        ph.napSuKien("event.run.progress",
                     ["kind": "run.started", "run_id": "r1", "text": "Dựng firmware",
                      "steps": [["cap": "code.write"]]])
        ph.napSuKien("event.run.progress", xong)
        ph.napSuKien("event.run.progress", xong)
        // Không daemon nên báo cáo không lấy được — nhưng câu BÁO LỖI cũng chỉ được một lần.
        let n = Self.chu(k.dock).components(separatedBy: "không lấy được báo cáo").count - 1
        XCTAssertLessThanOrEqual(n, 1, "in báo cáo \(n) lần cho một lượt chạy")
    }

    /// Huỷ cũng chỉ một câu, cùng lý do.
    func testRunCancelledChiNoiMotLan() {
        let (k, ph) = dungKhung()
        let huy: [String: Any] = ["kind": "run.cancelled", "run_id": "r2", "by": "human"]
        ph.napSuKien("event.run.progress",
                     ["kind": "run.started", "run_id": "r2", "steps": [["cap": "code.write"]]])
        ph.napSuKien("event.run.progress", huy)
        ph.napSuKien("event.run.progress", huy)
        let n = Self.chu(k.dock).components(separatedBy: "Lượt chạy bị huỷ").count - 1
        XCTAssertEqual(n, 1, "nói \(n) lần cho một lần huỷ")
    }

    // MARK: - §2A.2 bộ chuyển dự án

    func testPopoverCoDuBaPhanCuaTaiLieu() {
        let c = EideChonDuAn()
        c.dat([.init(id: "blink", duong: "/kho/blink")])
        let van = Self.chu(c.view)
        XCTAssertTrue(van.contains("Lọc theo tên"), "thiếu ô lọc — \(van)")
        XCTAssertTrue(van.contains("blink"), "thiếu danh sách — \(van)")
        XCTAssertTrue(van.contains("Dự án mới"), "thiếu nút tạo mới — \(van)")
    }

    /// Lọc KHÔNG DẤU, như bảng lệnh ⌘K. Người gõ nhanh không bỏ dấu, và một bộ lọc đòi dấu là
    /// một bộ lọc dùng được đúng một nửa số lần.
    func testLocKhongDau() {
        let c = EideChonDuAn()
        c.dat([.init(id: "do-nhiet-do", duong: "/kho/do-nhiet-do"),
               .init(id: "blink", duong: "/kho/blink")])
        XCTAssertEqual(c.loc("NHIET").map(\.id), ["do-nhiet-do"])
        XCTAssertEqual(c.loc("").count, 2)
    }

    /// **Thiếu khoá thì để trống, không điền 0.** `0/0 tính năng` nói với người dùng rằng dự án
    /// của họ rỗng, trong khi sự thật là `project.list` không trả con số ấy.
    func testThieuSoTinhNangThiKhongBia() {
        let d = EideChonDuAn.DuAn(["id": "x", "path": "/kho/x"])
        XCTAssertFalse(d.dongPhu.contains("0/0"), d.dongPhu)
        XCTAssertTrue(d.dongPhu.contains("chưa đọc được"), d.dongPhu)
        let e = EideChonDuAn.DuAn(["id": "y", "path": "/kho/y", "passing": 2, "total": 7,
                                   "board": "nucleo-f411", "autonomy": "A2"])
        XCTAssertEqual(e.dongPhu, "nucleo-f411 · 2/7 tính năng · A2")
    }

    /// Rỗng vì CHƯA NẠP khác rỗng vì LỌC HẾT — gộp hai câu thì người gõ nhầm một chữ sẽ kết luận
    /// workspace của mình trống.
    func testHaiCauRongKhacNhau() {
        let c = EideChonDuAn()
        c.dat([])
        XCTAssertTrue(Self.chu(c.view).contains("`project.list` chưa trả về gì"), Self.chu(c.view))
        c.dat([.init(id: "blink", duong: "/kho/blink")])
        _ = c.loc("khong-co")
        c.locDeTest("khong-co")
        XCTAssertTrue(Self.chu(c.view).contains("Không dự án nào khớp"), Self.chu(c.view))
    }

    /// **Đổi dự án = thay TOÀN BỘ ngữ cảnh.** Một badge "Chờ tôi 2" còn sót lại trỏ vào hàng đợi
    /// của dự án KHÁC, và người bấm Duyệt ở đó duyệt một việc họ không hề nhìn thấy.
    func testDoiDuAnDongHetTabVaXoaHetBadge() async {
        let (k, ph) = dungKhung()
        ph.moMan("Passport", boiTacTu: false)
        ph.moMan("NhatKy", boiTacTu: false)
        ph.napSuKien("event.run.progress",
                     ["kind": "run.started", "run_id": "r1", "steps": [["cap": "code.write"]]])
        XCTAssertEqual(k.thanhTab.tab.count, 2)

        await ph.doiDuAn("/kho/du-an-khac")
        XCTAssertTrue(k.thanhTab.tab.isEmpty, "còn tab của dự án cũ: \(k.thanhTab.tab)")
        XCTAssertNil(k.vungLamViec.dangMo)
        XCTAssertFalse(Self.chu(k.cotTrai).contains("1"),
                       "badge của dự án cũ còn lại — \(Self.chu(k.cotTrai))")
    }

    /// Bố cục thì GIỮ NGUYÊN: cột phải hẹp hay rộng là lựa chọn của người, không thuộc dự án nào.
    func testDoiDuAnKhongDungToiBoCuc() async {
        let (k, ph) = dungKhung()
        k.nguoiDoiCotPhai(true)
        k.dock.datCao(.moRong, buoc: true)
        await ph.doiDuAn("/kho/du-an-khac")
        XCTAssertTrue(k.cotPhai.hep, "đổi dự án bung lại cột phải người vừa gấp")
        XCTAssertEqual(k.dock.cao, .moRong, "đổi dự án đặt lại chiều cao vùng trao đổi")
    }

    // MARK: - phụ

    private static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField {
            ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                          : t.attributedStringValue.string) + " "
            ra += (t.placeholderString ?? "") + " "
        }
        if let b = v as? NSButton {
            ra += (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string) + " "
        }
        for c in v.subviews { ra += chu(c) }
        return ra
    }
    // MARK: - `chat.send` hỏng thì PHẢI nói ra (bài CNC 21/09/2026)

    /// Một phiên thật tám lượt gõ, KHÔNG một câu trả lời nào, và không một lỗi nào.
    ///
    /// Nguyên nhân ở `EidePhien._gui`: mọi nhánh thêm bong bóng đều có điều kiện (`restate`,
    /// `run_id`, `cho_nguoi`), nên một câu trả lời không khớp nhánh nào đi qua lặng lẽ. Người
    /// dùng thấy bong bóng của chính mình rồi thôi — và kết luận sản phẩm hỏng, đúng như nó
    /// đang hỏng, chỉ là không có đường nào biết hỏng ở đâu.
    ///
    /// Đo phần QUYẾT ĐỊNH ra chữ chứ không dựng cả phiên: `_gui` đi qua daemon thật, tức qua
    /// mô hình, tức qua mạng và qua tiền.
    func testViSaoKhongCoChuoiNeuRaLoiThatChuKhongNoiChungChung() {
        let r: [String: Any] = ["intent_id": "arch.design",
                                "error": ["eide_code": "E6003",
                                          "message": "Chưa có store tại .eide/store/store.sqlite"]]
        let c = EidePhien.viSaoKhongCoChuoi(r)
        XCTAssertTrue(c.contains("E6003"), "phải nêu MÃ lỗi, vì đó là thứ tra được: \(c)")
        XCTAssertTrue(c.contains("store"), "phải nêu câu lỗi thật của lõi: \(c)")
    }

    /// Lỗi lồng trong `run` cũng phải moi ra — `chat.send` trả `asdict(run)` khi lời gọi hỏng.
    func testViSaoKhongCoChuoiDocDuocLoiNamTrongRun() {
        let r: [String: Any] = ["run": ["status": "failed",
                                        "error": ["eide_code": "E5000",
                                                  "message": "Vai trò intent không có nhà cung cấp"]]]
        let c = EidePhien.viSaoKhongCoChuoi(r)
        XCTAssertTrue(c.contains("E5000") && c.contains("nhà cung cấp"), c)
    }

    /// Không biết thì NÓI là không biết — một câu đoán đẩy người dùng đi sửa nhầm chỗ.
    func testViSaoKhongCoChuoiKhongBiaKhiLoiKhongNoiGi() {
        let c = EidePhien.viSaoKhongCoChuoi(["intent_id": "arch.design"])
        XCTAssertTrue(c.contains("không nói lý do"), c)
    }

    /// `asked` KHÔNG phải lỗi và cũng không phải xong — nó là "đang chờ ANH".
    ///
    /// Hiện nguyên chữ `asked` thì người dùng ngồi đợi một chuỗi đang đợi họ. Đo trên bài CNC:
    /// chuỗi `arch.design` dừng ở `arch.style_select` vì thiếu `reqset_ids`, trả `state: asked`.
    func testTrangThaiAskedNoiRaLaDangChoNguoi() {
        XCTAssertTrue(EidePhien.trangThaiChuoi("asked").contains("chờ anh"),
                      EidePhien.trangThaiChuoi("asked"))
        XCTAssertTrue(EidePhien.trangThaiChuoi("planned").contains("gật đầu"),
                      EidePhien.trangThaiChuoi("planned"))
        XCTAssertEqual(EidePhien.trangThaiChuoi("xyz"), "trạng thái chưa rõ")
    }
    /// `failed` phải nói rõ là KHÔNG chờ người — ngược hẳn với `asked`.
    ///
    /// Hai trạng thái này dẫn người dùng đi hai hướng đối lập: một bên "gõ câu trả lời đi",
    /// một bên "đừng ngồi đợi, đi xem lỗi". Nói nhầm hướng thì họ ngồi đợi một câu hỏi không
    /// bao giờ tới.
    func testTrangThaiFailedNoiRoLaKhongChoNguoi() {
        let c = EidePhien.trangThaiChuoi("failed")
        XCTAssertTrue(c.contains("KHÔNG chờ anh"), c)
        XCTAssertFalse(c.contains("đang chờ anh trả lời"), c)
    }
}
