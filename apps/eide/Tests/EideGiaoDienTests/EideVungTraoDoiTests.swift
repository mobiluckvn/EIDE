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

    /// A0/A1 và A2–A3 phải nói HAI câu khác nhau: một bên là đúng hợp đồng, bên kia là một
    /// thiếu sót có thật của tầng dưới, và gộp chúng là giấu mất cái thứ hai.
    func testA1NoiRoLaThieuSotChuKhongNoiLaBinhThuong() {
        let a1 = EideTheYHieu.viSaoKhongHoi("A1")
        XCTAssertTrue(a1.contains("DEV-140"), a1)
        XCTAssertTrue(a1.contains("chưa có chỗ dừng"), a1)
        let a2 = EideTheYHieu.viSaoKhongHoi("A2")
        XCTAssertFalse(a2.contains("DEV-140"), "A2 đúng hợp đồng mà vẫn báo thiếu sót — \(a2)")
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
}
