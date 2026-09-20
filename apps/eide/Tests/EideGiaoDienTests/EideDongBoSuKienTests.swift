import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **UXC-31 §7 — Đồng bộ sự kiện.** Tài liệu gọi mục này là "nền của mọi thứ — làm TRƯỚC các
/// màn"; ta làm sau tám màn, nên mỗi bài dưới đây vừa là phép kiểm vừa là phép đối chiếu ngược
/// với những màn đã có.
@MainActor
final class EideDongBoSuKienTests: XCTestCase {

    // MARK: - §7.1 bảng đăng ký

    /// "**không màn nào subscribe tất cả**" — trừ đúng một màn, và màn ấy phải là Nhật ký.
    ///
    /// §8 S2 ghi "nghe: MỌI LOẠI" cho Nhật ký, nên hai mục của cùng tài liệu kéo ngược nhau.
    /// Cách hoà: Nhật ký khai bằng `TAT_CA` — một hằng số CÓ TÊN, sinh từ hợp đồng — chứ không
    /// bằng chuỗi `"*"`. Bảng vẫn đọc được, và một sự kiện mới vẫn phải được ai đó quyết cho
    /// chảy vào đâu.
    func testDungMotManDuocNgheTatCa() {
        let tatCa = EideDangKySuKien.BANG.filter { $0.value == EideDangKySuKien.TAT_CA }
        XCTAssertEqual(Array(tatCa.keys), [EideDangKySuKien.MAN_NGHE_TAT_CA])
        XCTAssertFalse(EideDangKySuKien.BANG.values.contains { $0.contains("*") },
                       "có màn subscribe bằng ký tự đại diện")
    }

    /// Mọi loại khai trong bảng phải là một sự kiện CÓ THẬT trong hợp đồng đã sinh. Một tên gõ
    /// sai là một màn không bao giờ được đánh thức, và nó trông y hệt một màn chưa làm.
    func testMoiLoaiKhaiBaoDeuCoTrongHopDong() {
        for (man, ds) in EideDangKySuKien.BANG {
            for loai in ds {
                XCTAssertTrue(EideDangKySuKien.TAT_CA.contains(loai),
                              "`\(man)` khai `\(loai)` — không có trong `EideMethod`")
            }
        }
    }

    /// Mọi khoá trong bảng phải là một màn CÓ THẬT trong danh mục 25 màn.
    func testMoiKhoaTrongBangDeuLaManCoThat() {
        for man in EideDangKySuKien.BANG.keys {
            XCTAssertNotNil(EideManHinhDS.man(man), "tiền tố `\(man)` không có trong danh mục")
        }
    }

    /// **Màn đã nối dữ liệu thì phải khai báo nghe gì.** Một màn hiện dữ liệu sống mà không
    /// nghe sự kiện nào là một màn đứng yên trong khi thế giới đổi — và người dùng không có
    /// cách nào biết.
    func testMoiManDaNoiDuLieuDeuCoKhaiBaoNghe() {
        for tien in EidePhien.MAN.keys {
            XCTAssertNotNil(EideDangKySuKien.BANG[tien],
                            "màn `\(tien)` đã nối dữ liệu nhưng không khai báo nghe gì (§7.1)")
        }
    }

    func testTraNguocDuocManNaoCanMotLoai() {
        let ds = EideDangKySuKien.manCan("event.knowledge.changed")
        XCTAssertTrue(ds.contains("Passport") && ds.contains("XungDot") && ds.contains("Graph"), "\(ds)")
        XCTAssertTrue(ds.contains("NhatKy"), "Nhật ký nghe mọi loại nên phải có mặt — \(ds)")
    }

    // MARK: - §7.2 nhảy quãng

    /// **Nhảy quãng KHÁC mất daemon**, và khác ở chỗ nguy hơn: mất daemon là không nghe thấy
    /// gì, còn nhảy quãng là màn hình VẪN đang cập nhật nên trông như đang đúng. Hai câu phải
    /// khác nhau, nếu không người dùng học một phản xạ cho hai tình huống cần hai phản xạ.
    func testNhayQuangSeqBatDuocVaNoiThIEUBAONHIEU() {
        let (k, ph) = Self.dung()
        ph.napSuKien("event.knowledge.changed", ["seq": 10, "kind": "store.write"])
        XCTAssertEqual(k.chuDaiCu, "", "bản ghi đầu tiên không nói lên điều gì")
        ph.napSuKien("event.knowledge.changed", ["seq": 11, "kind": "store.write"])
        XCTAssertEqual(k.chuDaiCu, "", "liền mạch mà vẫn báo thiếu")

        ph.napSuKien("event.knowledge.changed", ["seq": 15, "kind": "store.write"])
        XCTAssertTrue(k.chuDaiCu.contains("thiếu 3 bản ghi"), k.chuDaiCu)
        XCTAssertTrue(k.chuDaiCu.contains("seq 12…14"), k.chuDaiCu)
        XCTAssertFalse(k.chuDaiCu.contains("không nghe được daemon"),
                       "dùng chung câu với mất daemon — \(k.chuDaiCu)")
    }

    /// Sự kiện KHÔNG mang `seq` (`event.job.progress`, `event.notice`) không được coi là nhảy
    /// quãng — chúng không đến từ sổ cái.
    func testSuKienKhongMangSeqKhongLamBaoDong() {
        let (k, ph) = Self.dung()
        ph.napSuKien("event.knowledge.changed", ["seq": 4])
        ph.napSuKien("event.job.progress", ["job_id": "j1", "pct": 40])
        ph.napSuKien("event.knowledge.changed", ["seq": 5])
        XCTAssertEqual(k.chuDaiCu, "")
        XCTAssertEqual(ph.seqDangNghe, 5)
    }

    /// "bấm = query lại từ seq đã có" — nút phải có thật và phải xoá dải.
    func testBamTaiLaiXoaDaiVaNapLaiMan() {
        let (k, ph) = Self.dung()
        ph.napSuKien("event.knowledge.changed", ["seq": 2])
        ph.napSuKien("event.knowledge.changed", ["seq": 9])
        XCTAssertNotEqual(k.chuDaiCu, "")
        ph._taiLai()
        XCTAssertEqual(k.chuDaiCu, "", "bấm Tải lại mà dải vẫn còn")
    }

    // MARK: - §7.3 badge cho màn đóng

    /// "Sự kiện tới màn đang ĐÓNG → chỉ tăng badge nhóm." Không mở màn, không kéo focus.
    func testSuKienToiManDANGDONGchiTangBadge() {
        let (k, ph) = Self.dung()
        ph.moMan("Main", boiTacTu: false)
        XCTAssertEqual(ph.chuaXem("Passport"), 0)

        ph.napSuKien("event.knowledge.changed", ["seq": 1, "kind": "store.write"])
        ph.napSuKien("event.knowledge.changed", ["seq": 2, "kind": "store.write"])
        XCTAssertEqual(ph.chuaXem("Passport"), 2)
        XCTAssertEqual(k.vungLamViec.dangMo, "Main", "màn đóng lại kéo được focus — trái §7.3")
        XCTAssertGreaterThanOrEqual(k.cotTrai.choTheoMan["Passport"] ?? 0, 2)
    }

    /// Mở màn ra là đã xem — badge về 0. Một badge không bao giờ tắt là một badge người ta thôi
    /// nhìn.
    func testMoManThiPhanChuaXemVeKhong() {
        let (_, ph) = Self.dung()
        ph.moMan("Main", boiTacTu: false)
        ph.napSuKien("event.knowledge.changed", ["seq": 1])
        XCTAssertEqual(ph.chuaXem("Passport"), 1)
        ph.moMan("Passport", boiTacTu: false)
        XCTAssertEqual(ph.chuaXem("Passport"), 0)
    }

    /// Màn KHÔNG khai báo nghe loại ấy thì không được tăng badge — đó là cả điểm của §7.1.
    func testManKhongKhaiBaoThiKhongTangBadge() {
        let (_, ph) = Self.dung()
        ph.moMan("Main", boiTacTu: false)
        ph.napSuKien("event.knowledge.changed", ["seq": 1])
        XCTAssertEqual(ph.chuaXem("ChinhSach"), 0,
                       "màn Chính sách không khai nghe `knowledge.changed` mà vẫn bị đánh thức")
    }

    /// Mặc định `apDung` trả `false` — và đó là chủ ý: một lớp cơ sở tự ý nạp lại sẽ giấu mất
    /// việc màn con chưa hiện thực diff render của §7.3. Để `false` thì đếm được còn bao nhiêu
    /// màn chưa làm phần ấy.
    func testApDungMacDinhTraFalseDeDemDuocNoConThieu() {
        let chuaLamDiffRender = EidePhien.MAN.filter { !$0.value().apDung("event.notice", [:]) }
        XCTAssertEqual(chuaLamDiffRender.count, EidePhien.MAN.count,
                       "có màn đã làm diff render — cập nhật ghi chú §7.3 trong CONG-VIEC.md")
    }

    private static func dung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }
}
