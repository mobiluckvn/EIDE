import AppKit
import XCTest
@testable import EideGiaoDien

/// **§10.1 — mười tiêu chí nghiệm thu N1…N10 về đúng mười bài kiểm.**
///
/// §10.1 khai một bảng ánh xạ, và một bảng ánh xạ chép tay là thứ **lệch im lặng**: đổi tên một
/// hàm kiểm, xoá một bài, gộp hai bài làm một — bảng vẫn đọc trôi chảy, chỉ là nó trỏ vào chỗ
/// không còn gì. Ở đây bảng được đối chiếu với runtime: mỗi ô phải là một hàm kiểm CÓ THẬT
/// trong bundle này.
///
/// Hai tiêu chí bị chặn ở tầng dưới, và chúng ghi `nil` kèm lý do chứ không trỏ bừa vào một bài
/// gần đúng. Một bảng nghiệm thu nói "đủ mười" trong khi hai ô là phỏng đoán thì nó có hại hơn
/// một bảng nói "tám, còn hai".
@MainActor
final class EideTieuChiTests: XCTestCase {

    /// `(tiêu chí, mục checklist, lớp kiểm, hàm kiểm)`. `nil` = chưa có, kèm lý do ở `CHAN`.
    static let BANG: [(String, String, String, String)?] = [
        ("N1", "3.2", "EideLamQuenBangLenhTests", "testTaoDuAnTrongHaiThaoTac"),
        ("N2", "2E.4", "EideTheRunTests", "testSuKienDenMuonKhongDayTienDoLUI"),
        ("N3", "5.4", "EideManMaNguonTests", "testBufferBanThiBangVangNoiRaHauQuaVoiTacTu"),
        // N4 và N5 sống ở phía LÕI (pytest), không trong gói Swift — nên `lop` để rỗng và phép
        // đối chiếu runtime bỏ qua chúng, đổi lại đòi một đường dẫn `tests/…::…` cụ thể.
        ("N4", "6.4", "", "tests/test_undo_ba_muc.py::test_muc_2_revert_ca_run_GIU_commit_cua_nguoi"),
        ("N5", "6.5", "",
         "tests/test_undo_ba_muc.py::test_N5_khong_duong_nao_ghi_de_ma_khong_qua_merge_hay_xung_dot"),
        ("N6", "7.2", "EideBatBienTests", "testNhipTimDayHonHanCuVaHanDatNguongN6"),
        ("N7", "2.3", "EideBoCucTests", "testN7VungLamViecConItNhatMotNuaOCuaSoCao900"),
        ("N8", "2B.1", "EideKhungTests", "testDIEU_HUONG_SAU_nhom_moi_nhom_2_den_5_muc"),
        ("N9", "4.2", "EideLamQuenBangLenhTests", "testTimTheoMoTaVaKhongDau"),
        ("N10", "5.2", "EideManMaNguonTests", "testLeDanhDauDongCoChuThichFact"),
    ]

    /// Không còn ô trống nào.
    static let CHAN: [String: String] = [:]

    /// Ghi chú LỊCH SỬ: hai tiêu chí này từng để trống, và vì sao. Giữ lại vì nó nói ra điều gì
    /// đã chặn — lần sau gặp lại cùng hình dạng thì nhận ra ngay.
    static let TUNG_CHAN: [String: String] = [
        "N4": "6.4 từng chặn vì `Router.undo_handlers` rỗng — mọi lần bấm Hoàn tác trả "
            + "`applied: false`. Gỡ 21/09 bằng `src/eide/undo_handlers.py`, cộng hai lỗi gốc: "
            + "`code.merge` commit không mang tác giả máy-đọc-được nên phép chọn lọc N4 luôn "
            + "trả rỗng, và `rollback` từ chối chạy vì `.eide/` chưa theo dõi. [DEV-144]",
        "N5": "6.5 phủ định 'không nhánh nào ghi đè' — vẫn KHÔNG chứng minh được theo nghĩa "
            + "tuyệt đối (phủ định MỌI đường, cùng hình dạng B1). Nay kiểm ba lối ghi mà giao "
            + "diện và tác tử thực sự dùng, và cả ba phải từ chối.",
    ]

    /// Đủ mười ô — và nay KHÔNG ô nào trống.
    func testBangCoDungMuoiTieuChi() {
        XCTAssertEqual(Self.BANG.count, 10)
        let co = Self.BANG.compactMap { $0 }
        XCTAssertEqual(co.count, 10, "còn ô trống trong bảng nghiệm thu")
        XCTAssertEqual(Set(co.map(\.0)).count, 10, "hai ô cùng tên tiêu chí")
        XCTAssertTrue(Self.CHAN.isEmpty)
    }

    /// **Mỗi ô trỏ vào một hàm kiểm CÓ THẬT.** Đây là phần bảng chép tay không tự làm được: đổi
    /// tên một hàm thì bảng vẫn đọc trôi chảy trong khi nó đã trỏ vào chỗ trống.
    func testMoiTieuChiTroVaoMotBaiKiemCoThat() {
        // Ô có `lop` rỗng là bài kiểm phía LÕI (pytest) — runtime Swift không thấy được nó,
        // nên chỉ đòi một đường dẫn `tests/<tệp>::<hàm>` để bảng vẫn truy về chỗ cụ thể.
        for o in Self.BANG.compactMap({ $0 }) where o.2.isEmpty {
            XCTAssertTrue(o.3.hasPrefix("tests/") && o.3.contains("::"),
                          "\(o.0): ô lõi phải trỏ `tests/<tệp>::<hàm>` — \(o.3)")
        }
        for o in Self.BANG.compactMap({ $0 }) where !o.2.isEmpty {
            let ten = "EideGiaoDienTests.\(o.2)"
            guard let lop = NSClassFromString(ten) else {
                return XCTFail("\(o.0): không có lớp kiểm `\(o.2)`")
            }
            // Hàm kiểm `async` lộ ra ObjC dưới tên `…WithCompletionHandler:`, nên hỏi mỗi
            // tên trần sẽ báo THIẾU cho một bài đang chạy tốt. Bản đầu của bài này báo N3
            // thiếu đúng vì thế — một bảng nghiệm thu nói sai theo chiều "chưa có" cũng tệ
            // như nói sai theo chiều "đã có".
            let co = lop.instancesRespond(to: Selector(o.3))
                  || lop.instancesRespond(to: Selector(o.3 + "WithCompletionHandler:"))
            XCTAssertTrue(co, "\(o.0) (mục \(o.1)): `\(o.2)` không có hàm `\(o.3)`")
        }
    }

    /// Ghi chú lịch sử vẫn phải trỏ vào chỗ cụ thể — một dòng "từng chặn, nay xong" mà không
    /// nói chặn ở đâu thì lần sau gặp lại cùng vấn đề không ai nhận ra.
    func testGhiChuLichSuVanTruyDuoc() {
        for (ma, vi) in Self.TUNG_CHAN {
            XCTAssertGreaterThan(vi.count, 80, "\(ma): lý do quá ngắn để truy được")
            XCTAssertTrue(vi.contains("`") || vi.contains("6."),
                          "\(ma): lý do không trỏ vào mã hay mục nào")
        }
    }
}
