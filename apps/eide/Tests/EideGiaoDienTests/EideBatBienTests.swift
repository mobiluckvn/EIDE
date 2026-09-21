import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Mục 0 của UXC-31 — bất biến. Vi phạm là lỗi CHẶN, không merge.**
///
/// Tám bất biến này khác mọi mục khác của checklist ở chỗ chúng không mô tả một tính năng mà
/// mô tả một thứ **không bao giờ được xảy ra** — và loại mệnh đề ấy không tự kiểm được bằng
/// cách mở màn ra nhìn. Phải có bài kiểm đi hết mọi màn và khẳng định điều xấu không xảy ra ở
/// màn nào.
@MainActor
final class EideBatBienTests: XCTestCase {

    private func dungKhung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }

    // MARK: - B3 vùng trao đổi là BẤT BIẾN

    /// **Không màn nào trong 21 màn che, thay hay bóp vùng trao đổi.**
    ///
    /// Chủ sản phẩm gọi đây là điều kiện tồn tại của sản phẩm: "giao diện để người và máy cùng
    /// trao đổi là phải có và BẤT BIẾN". Một màn dựng sai ràng buộc có thể ăn vào dock mà không
    /// test đơn vị nào của MÀN ẤY thấy — chỗ hỏng nằm giữa màn và khung.
    func testKhongManNaoCheHayBopVungTraoDoi() {
        let (k, ph) = dungKhung()
        for tien in EidePhien.MAN.keys.sorted() {
            ph.moMan(tien, boiTacTu: false)
            k.layoutSubtreeIfNeeded()
            XCTAssertFalse(k.dock.isHidden, "màn \(tien) ẩn mất vùng trao đổi")
            XCTAssertGreaterThanOrEqual(k.dock.frame.height, EideDock.Cao.thuGon.rawValue,
                "màn \(tien) bóp vùng trao đổi còn \(k.dock.frame.height) pt")
            // Vùng làm việc KHÔNG được chờm xuống dock. Toạ độ AppKit gốc dưới-trái, nên
            // "ở trên" nghĩa là `minY` lớn hơn `maxY` của dock.
            XCTAssertGreaterThanOrEqual(k.vungLamViec.frame.minY, k.dock.frame.maxY,
                "màn \(tien) chờm lên vùng trao đổi")
        }
    }

    /// 48 pt là SÀN tuyệt đối — không đường nào đặt được chiều cao nhỏ hơn, vì `Cao` là enum ba
    /// giá trị chứ không phải một con số tự do.
    func testSanBaMuoiTamKhongLuotQuaDuoc() {
        XCTAssertEqual(EideDock.Cao.allCases.map(\.rawValue).min(), 48)
        let d = EideDock()
        for c in EideDock.Cao.allCases {
            d.datCao(c, buoc: true)
            XCTAssertGreaterThanOrEqual(d.cao.rawValue, 48)
        }
    }

    /// Thu gọn hết cỡ thì **vẫn còn ô gõ**. Một vùng trao đổi 48 pt mà không nhập được gì thì nó
    /// chỉ còn là một dải trang trí, và bất biến B3 mất hết nội dung.
    func testThuGonHetCoVanGoDuoc() {
        let d = EideDock(frame: NSRect(x: 0, y: 0, width: 900, height: 48))
        d.datCao(.thuGon, buoc: true)
        d.layoutSubtreeIfNeeded()
        var daGui: String?
        d.onGui = { daGui = $0 }
        d.guiDeTest("vẫn gõ được")
        XCTAssertEqual(daGui, "vẫn gõ được", "thu gọn xong thì không gửi được lệnh nào")
    }

    // MARK: - B6 dữ liệu cũ phải NÓI là cũ

    /// Hạn phải NGẮN hơn hoặc bằng ngưỡng N6 (2 giây), và nhịp tim phải DÀY hơn hạn — nếu không
    /// thì hạn ấy không bao giờ đo được.
    func testNhipTimDayHonHanCuVaHanDatNguongN6() {
        XCTAssertLessThanOrEqual(EidePhien.HAN_CU, 2.0, "hạn dữ liệu cũ vượt tiêu chí N6")
        XCTAssertLessThan(EidePhien.NHIP_TIM, EidePhien.HAN_CU,
                          "nhịp tim thưa hơn hạn — hạn không bao giờ đo tới")
    }

    /// Dải phải nói CŨ BAO LÂU, không chỉ nói "cũ". Con số ấy là thứ người dùng cần để quyết có
    /// tin những gì màn hình đang hiện hay không.
    func testDaiDuLieuCuNoiRoTreBaoLau() {
        let (k, _) = dungKhung()
        XCTAssertEqual(k.chuDaiCu, "", "chưa mất daemon mà đã báo dữ liệu cũ")
        k.datDuLieuCu(true, tre: 7)
        XCTAssertTrue(k.chuDaiCu.contains("7 giây"), k.chuDaiCu)
        XCTAssertFalse(k.nutTaiLai.isHidden, "báo cũ mà không cho tải lại")
    }

    /// Mất daemon và nhảy quãng `seq` là HAI câu khác nhau — gộp lại thì người dùng học được
    /// đúng một phản xạ cho hai tình huống cần hai phản xạ.
    func testMatDaemonVaNhayQuangNoiHaiCauKhacNhau() {
        let (k, _) = dungKhung()
        k.datDuLieuCu(true, tre: 5)
        let mat = k.chuDaiCu
        k.datNhayQuang(10, 14)
        let nhay = k.chuDaiCu
        XCTAssertNotEqual(mat, nhay)
        XCTAssertTrue(nhay.contains("thiếu 3 bản ghi"), nhay)
        XCTAssertTrue(nhay.contains("seq 11…13"), nhay)
    }

    // MARK: - B7 mỗi câu hỏi có ĐÚNG MỘT nơi trả lời

    /// Cột phải là BẢN CHIẾU: nó không nghe sự kiện, không giữ trạng thái nguồn. Cho nó nghe sổ
    /// cái là tạo ra nguồn sự thật thứ hai cho câu "việc gì chờ tôi", và hai nguồn thì sớm muộn
    /// nói hai con số.
    func testCotPhaiKhongDangKyNgheSuKien() {
        for khoa in EideDangKySuKien.BANG.keys {
            XCTAssertNotEqual(khoa, "CotPhai", "cột phải tự nghe sổ cái — thành nguồn thứ hai")
        }
        XCTAssertTrue(EidePhien.MAN["CotPhai"] == nil)
    }

    /// Đúng MỘT màn nghe mọi loại sự kiện, và đó là Nhật ký — nơi trả lời "đã xảy ra gì". Hai
    /// màn cùng nghe tất cả là hai màn cùng nhận trách nhiệm ấy.
    func testChiMotManNgheTatCaVaDoLaNhatKy() {
        let tatCa = EideDangKySuKien.BANG.filter { $0.value == EideDangKySuKien.TAT_CA }
        XCTAssertEqual(tatCa.keys.sorted(), [EideDangKySuKien.MAN_NGHE_TAT_CA])
        XCTAssertEqual(EideManHinhDS.man(EideDangKySuKien.MAN_NGHE_TAT_CA)?.ma, "S2")
    }

    /// Mọi màn đã nối phải KHAI BÁO mình nghe gì. Một màn không khai báo thì hoặc nó không bao
    /// giờ cập nhật, hoặc nó cập nhật theo một đường không ai đọc được ở một chỗ.
    func testMoiManDaNoiDeuKhaiBaoNgheGi() {
        for tien in EidePhien.MAN.keys {
            XCTAssertNotNil(EideDangKySuKien.BANG[tien], "màn `\(tien)` chưa khai báo nghe gì")
        }
    }

    // MARK: - B8 dừng khẩn chạy ở MỌI trạng thái giao diện

    /// **Kể cả khi bảng lệnh đang mở.** Modal nuốt phím là cách thường gặp nhất để một nút dừng
    /// khẩn trở thành không bấm được đúng lúc cần nó nhất.
    func testDungKhanChayDuocKhiBangLenhDangMo() async {
        let (k, ph) = dungKhung()
        k.bangLenh.mo()
        XCTAssertFalse(k.bangLenh.isHidden, "bảng lệnh không mở được thì bài này không đo gì")
        let t0 = ProcessInfo.processInfo.systemUptime
        await ph.dungKhan()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - t0, 1.0,
                          "dừng khẩn mất hơn 1 giây khi modal đang mở")
    }

    /// Và kể cả khi màn chào đang phủ toàn cửa sổ.
    func testDungKhanChayDuocTrenManChao() async {
        let (k, ph) = dungKhung()
        XCTAssertTrue(k.dangChao)
        let t0 = ProcessInfo.processInfo.systemUptime
        await ph.dungKhan()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - t0, 1.0)
    }

    // MARK: - §1.2 / §1.3 chữ và bo góc

    /// **IBM Plex, không phải San Francisco.**
    ///
    /// UXC-31 §1.2 viết "hệ San Francisco… SF Mono 12,5 pt". UXD-13 v2.0 viết "IBM Plex
    /// Sans/Mono" ở U7 và `font.ui IBM Plex Sans 13px/1.45 · font.mono IBM Plex Mono 12px` ở
    /// bảng token. Quy tắc đọc ở đầu chính checklist: **mâu thuẫn thì UXD-13 v2.0 thắng** — nên
    /// mã đúng và §1.2 là tài liệu cũ. Xem [DEV-142].
    ///
    /// Bài này chốt mã vào TOKEN chứ không vào con số chép tay: token sinh ra từ `uxd.js`, nên
    /// lần sau tài liệu đổi thì chỗ này đỏ, chứ không im lặng lệch đi như [DEV-137].
    func testChuLayTuTokenChuKhongChepTay() {
        XCTAssertEqual(EideToken.fontUI.pointSize, 13)
        XCTAssertEqual(EideToken.fontMono.pointSize, 12)
        // Máy chưa cài IBM Plex thì rơi về phông hệ — ĐÚNG như UXD-13 ghi ("macOS fallback
        // -apple-system"). Nên bài kiểm phép cỡ chữ, không phép tên phông: đòi tên là đòi mọi
        // máy chạy CI phải cài một phông không đi kèm macOS.
        XCTAssertFalse(EideToken.fontUI.fontName.isEmpty)
    }

    /// §1.3 — bo góc và lưới 4 pt. Bộ bán kính của UXD-13 là `[6, 8, 10]`; §1.3 nói "thẻ Run
    /// 9 pt", một con số **không có trong bộ ấy**. Cùng lý do trên: token thắng. [DEV-142]
    func testBoGocVaLuoiLayTuToken() {
        XCTAssertEqual(EideToken.radius, [6, 8, 10])
        XCTAssertFalse(EideToken.radius.contains(9), "bộ bán kính có 9 pt — §1.3 nói đúng?")
        for s in EideToken.space {
            XCTAssertEqual(s.truncatingRemainder(dividingBy: 4), 0,
                           "khoảng cách \(s) pt không phải bội số của 4")
        }
    }

    // MARK: - §1.4 ngữ nghĩa màu không dùng chéo

    /// Bốn màu, bốn nghĩa, và thẻ Run là chỗ cả bốn cùng xuất hiện — nên nó là chỗ một lần dùng
    /// chéo lộ ra rõ nhất: xanh dương cho "đang chạy", vàng cho "chờ người", xanh lá cho bước
    /// đã đạt, đỏ cho dừng.
    func testTheRunDungDungBonMauTheoNgetNghia() {
        XCTAssertEqual(EideTheRun.mauBuoc(0, buoc: 2, trangThai: .chay), EideToken.Mau.ok,
                       "bước đã qua không phải màu ĐẠT")
        XCTAssertEqual(EideTheRun.mauBuoc(2, buoc: 2, trangThai: .chay), EideToken.Mau.info,
                       "bước đang chạy không phải màu TÁC TỬ ĐANG LÀM")
        XCTAssertEqual(EideTheRun.mauBuoc(2, buoc: 2, trangThai: .chan), EideToken.Mau.warn,
                       "bước đang chờ người không phải màu CHỜ NGƯỜI")
        XCTAssertNotEqual(EideToken.Mau.ok, EideToken.Mau.info, "hai nghĩa dùng chung một màu")
        XCTAssertNotEqual(EideToken.Mau.warn, EideToken.Mau.bad)
    }
}
