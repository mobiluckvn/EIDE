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
        nil,   // N4 → 6.4
        nil,   // N5 → 6.5
        ("N6", "7.2", "EideBatBienTests", "testNhipTimDayHonHanCuVaHanDatNguongN6"),
        ("N7", "2.3", "EideBoCucTests", "testN7VungLamViecConItNhatMotNuaOCuaSoCao900"),
        ("N8", "2B.1", "EideKhungTests", "testDIEU_HUONG_SAU_nhom_moi_nhom_2_den_5_muc"),
        ("N9", "4.2", "EideLamQuenBangLenhTests", "testTimTheoMoTaVaKhongDau"),
        ("N10", "5.2", "EideManMaNguonTests", "testLeDanhDauDongCoChuThichFact"),
    ]

    /// Vì sao hai ô để trống. Ghi ở đây chứ không trong một tệp tài liệu: lý do phải nằm cạnh
    /// chỗ trống, nếu không thì người đọc bảng sau này tưởng ai đó quên điền.
    static let CHAN: [String: String] = [
        "N4": "6.4 hoàn tác 3 mức — `Router.undo_handlers` rỗng THEO THIẾT KẾ đã ghi trong "
            + "`hoan_tac()`: chưa có hiện thực đảo nào, mọi lần bấm trả `applied: false` kèm lý "
            + "do. Viết bài kiểm đòi revert chọn lọc bây giờ là ép lõi hứa thứ nó đang nói "
            + "thẳng là chưa làm.",
        "N5": "6.5 phủ định 'không nhánh nào ghi đè' — cùng hình dạng với B1: một mệnh đề phủ "
            + "định MỌI đường, mà bài kiểm chỉ đi được những đường nó biết. Phần đo được đã đo "
            + "ở 6.2 (merge 3 bên) và `test_LUU_khi_tep_da_doi_tren_dia_thi_KHONG_ghi_de`.",
    ]

    /// Đủ mười ô, không thừa không thiếu.
    func testBangCoDungMuoiTieuChi() {
        XCTAssertEqual(Self.BANG.count, 10)
        let co = Self.BANG.compactMap { $0 }
        XCTAssertEqual(co.count + Self.CHAN.count, 10, "ô trống không khớp số lý do đã ghi")
        XCTAssertEqual(co.map(\.0) + Self.CHAN.keys.sorted(),
                       ["N1", "N2", "N3", "N6", "N7", "N8", "N9", "N10", "N4", "N5"])
    }

    /// **Mỗi ô trỏ vào một hàm kiểm CÓ THẬT.** Đây là phần bảng chép tay không tự làm được: đổi
    /// tên một hàm thì bảng vẫn đọc trôi chảy trong khi nó đã trỏ vào chỗ trống.
    func testMoiTieuChiTroVaoMotBaiKiemCoThat() {
        for o in Self.BANG.compactMap({ $0 }) {
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

    /// Mỗi ô trống phải có lý do, và lý do phải nói ra CHỖ CHẶN chứ không chỉ nói "chưa làm".
    func testMoiOTrongDeuCoLyDoCuThe() {
        for (ma, vi) in Self.CHAN {
            XCTAssertGreaterThan(vi.count, 80, "\(ma): lý do quá ngắn để truy được")
            XCTAssertTrue(vi.contains("`") || vi.contains("6."),
                          "\(ma): lý do không trỏ vào mã hay mục nào")
        }
    }
}
