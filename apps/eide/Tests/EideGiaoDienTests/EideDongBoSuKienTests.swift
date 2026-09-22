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

        // Hở NHỎ không báo: không phải bản ghi sổ cái nào cũng sinh sự kiện lên giao diện —
        // `context.bundle`, `session.open` là việc nội bộ và daemon cố ý không chuyển tiếp.
        // Xem `NGUONG_HO` và [DEV-163].
        ph.napSuKien("event.knowledge.changed", ["seq": 15, "kind": "store.write"])
        XCTAssertEqual(k.chuDaiCu, "", "hở 3 seq là bình thường — \(k.chuDaiCu)")

        ph.napSuKien("event.knowledge.changed", ["seq": 40, "kind": "store.write"])
        XCTAssertTrue(k.chuDaiCu.contains("thiếu 24 bản ghi"), k.chuDaiCu)
        XCTAssertTrue(k.chuDaiCu.contains("seq 16…39"), k.chuDaiCu)
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
        ph.napSuKien("event.knowledge.changed", ["seq": 90])
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
    /// Badge đếm ĐƠN VỊ VIỆC, không đếm gói tin giao thức. [DEV-156]
    ///
    /// `event.run.progress` gánh hai khái niệm: sự kiện của CHUỖI và `cap.run.*` của từng lời
    /// gọi lẻ — kể cả những lời gọi do chính một màn phát ra để tự vẽ. Đếm từng cái thì một
    /// chuỗi sáu nút thành vài chục.
    ///
    /// Đo 22/09/2026 trên bài CNC: ba câu gõ ra `Nhật ký 470`, `Mã nguồn 713`, `DỰ ÁN 993`,
    /// trên một dự án có đúng 7 yêu cầu. Con số ấy không sai về số học, nhưng nó trả lời một
    /// câu hỏi không ai hỏi — và người ta thôi nhìn badge.
    func testBadgeDemMotChuoiLaMOTviec() {
        let (_, ph) = Self.dung()
        ph.moMan("Main", boiTacTu: false)
        // Sáu nút của CÙNG một chuỗi — người dùng đếm là MỘT việc.
        for i in 1...6 {
            ph.napSuKien("event.run.progress",
                         ["seq": i, "kind": "cap.run.finish", "cap": "req.classify",
                          "run_id": "cap-\(i)", "chain": ["run_id": "r_abc", "i": i, "of": 6]])
        }
        XCTAssertEqual(ph.chuaXem("FlowMap"), 1,
                       "sáu nút của một chuỗi phải là MỘT việc, nhận \(ph.chuaXem("FlowMap"))")
        // Một chuỗi KHÁC là một việc khác.
        ph.napSuKien("event.run.progress",
                     ["seq": 9, "kind": "cap.run.finish", "cap": "sim.run",
                      "run_id": "cap-9", "chain": ["run_id": "r_xyz", "i": 1, "of": 1]])
        XCTAssertEqual(ph.chuaXem("FlowMap"), 2)
    }

    /// Lời gọi LẺ không thuộc chuỗi nào thì mỗi bản ghi sổ cái là một việc.
    ///
    /// Phép gộp chỉ đúng khi có thứ để gộp THEO. Gộp theo `kind` sẽ làm hai lần `store.write`
    /// rời nhau thành một, và giấu mất một việc.
    func testBadgeKhongGopHAIviecROINHAUthanhMOT() {
        let (_, ph) = Self.dung()
        ph.moMan("Main", boiTacTu: false)
        ph.napSuKien("event.knowledge.changed", ["seq": 1, "kind": "store.write"])
        ph.napSuKien("event.knowledge.changed", ["seq": 2, "kind": "store.write"])
        XCTAssertEqual(ph.chuaXem("Passport"), 2)
    }
    /// Hở NHỎ là bình thường — báo nó là dạy người dùng bỏ qua cảnh báo. [DEV-163]
    ///
    /// Đo 22/09/2026 trên một lượt CNC: 5/78 bản ghi không sinh sự kiện (`context.bundle` 4,
    /// `session.open` 1), và giao diện treo biển "thiếu 1 bản ghi sổ cái (seq 22…22)" trong khi
    /// tệp sổ cái HOÀN TOÀN LÀNH — `verify()` trả `(True, 0)`.
    ///
    /// Một cảnh báo toàn vẹn kêu sai tệ hơn không có cảnh báo: nó kêu ở mọi phiên bình thường,
    /// người dùng học cách bỏ qua, rồi lần sổ cái gãy THẬT thì nó kêu và không ai nhìn.
    func testHoNhoKhongBaoDongVIcoLoaiKHONGlenGiaoDien() {
        let (k, ph) = Self.dung()
        ph.napSuKien("event.knowledge.changed", ["seq": 20, "kind": "store.write"])
        // Đúng hình dạng đã đo: `context.bundle` xen vào giữa, giao diện nhảy 21 → 23.
        ph.napSuKien("event.knowledge.changed", ["seq": 23, "kind": "store.write"])
        XCTAssertEqual(k.chuDaiCu, "", "báo động giả cho một sổ cái lành — \(k.chuDaiCu)")
    }
}
