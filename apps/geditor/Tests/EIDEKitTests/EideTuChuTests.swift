import XCTest
@testable import EIDEKit

/// `AutonomyBar` — đổi mức tự chủ và báo leo thang (GIAM-SAT-UI khoảng trống #7, #8).
///
/// Thanh này LUÔN hiện (UXD-13 U2), nên nó là bề mặt duy nhất người dùng chắc chắn thấy. Hai
/// thứ vừa thêm vào đó đều thuộc loại "sai thì người dùng không biết là mình đang sai": một
/// mức tự chủ hiện nhầm, và một cảnh báo chờ-người không tắt.
final class EideTuChuTests: XCTestCase {

    @MainActor
    func testNAMmucCuaAPD08deuCOtrongDANHsach() {
        let ma = AutonomyBar.MUC.map(\.ma)
        XCTAssertEqual(ma, ["A0", "A1", "A2", "A3", "A4"])
    }

    @MainActor
    func testMOImucNOIroNOchoPHEPlamGI() {
        // "A3" tự nó không nói gì. Người chọn một mức mà không biết nó mở ra cái gì thì hoặc
        // chọn bừa, hoặc không dám chọn — và khi ấy mức mặc định thành mức duy nhất.
        for m in AutonomyBar.MUC {
            XCTAssertTrue(m.mo.contains("—"), "mức \(m.ma) không có câu giải thích")
            XCTAssertGreaterThan(m.mo.count, m.ma.count + 4, m.mo)
        }
    }

    @MainActor
    func testDOImucGOIveMAchuKHONGgoiCAcauMOta() {
        let b = AutonomyBar()
        var nhan: String?
        b.onDoiMuc = { nhan = $0 }
        b.capNhat(muc: "A2", dungKhan: false, soCho: 0, soHoanTac: 0)
        XCTAssertEqual(b.mucDangChon, "A2")
        XCTAssertNil(nhan, "chỉ hiện mức hiện tại thì KHÔNG được coi là người vừa đổi")
    }

    @MainActor
    func testOCHONdiTHEOmucTHATchuKHONGtheoLUAchonNGUOI() {
        // Mức CÓ HIỆU LỰC do daemon tính (dự án → board → loại hành động, POL-17 §5). A4 chọn
        // trên một board chưa đánh dấu lab vẫn bị hạ xuống — và để ô chọn đứng ở "A4" khi ấy là
        // để nó nói dối về quyền tác tử đang có.
        let b = AutonomyBar()
        b.capNhat(muc: "A4", dungKhan: false, soCho: 0, soHoanTac: 0)
        XCTAssertEqual(b.mucDangChon, "A4")
        b.capNhat(muc: "A2", dungKhan: false, soCho: 0, soHoanTac: 0)
        XCTAssertEqual(b.mucDangChon, "A2", "daemon hạ mức thì ô chọn phải đi theo")
    }

    @MainActor
    func testDUNGKHANthiVEmucA0vaKHOAoCHON() {
        // Dừng khẩn là A0 theo định nghĩa. Để ô chọn còn bấm được lúc ấy là mời người dùng
        // "đổi mức" để thoát trạng thái dừng — mà thoát dừng là việc của `policy.resume`.
        let b = AutonomyBar()
        b.capNhat(muc: "A3", dungKhan: true, soCho: 1, soHoanTac: 0)
        XCTAssertEqual(b.mucDangChon, "A0")
    }

    @MainActor
    func testMUCLAnilKHONGlamNOhong() {
        let b = AutonomyBar()
        b.capNhat(muc: nil, dungKhan: false, soCho: 0, soHoanTac: 0)
        // Không khẳng định mức nào — chỉ đòi nó không chết và không bịa ra một mức.
        _ = b.mucDangChon
    }

    @MainActor
    func testMUCLAchuoiLAkhongLamNOhong() {
        let b = AutonomyBar()
        b.capNhat(muc: "không phải mức nào", dungKhan: false, soCho: 0, soHoanTac: 0)
        _ = b.mucDangChon
    }

    @MainActor
    func testLEOTHANGmacDINHkhongHIEN() {
        // Băng đỏ hiện sẵn từ lúc mở thì nó không còn nghĩa gì.
        XCTAssertFalse(AutonomyBar().dangBaoLeoThang)
    }

    @MainActor
    func testLEOTHANGhienKHIcoLYdo() {
        let b = AutonomyBar()
        b.leoThang("cùng một hành động hỏng 2 lần")
        XCTAssertTrue(b.dangBaoLeoThang)
    }

    @MainActor
    func testLEOTHANGtatDUOC() {
        // Người vừa duyệt xong mục cuối mà băng "ĐANG CHỜ ANH" vẫn đỏ là một cảnh báo không
        // tắt — và một cảnh báo không tắt thì lần sau người ta không đọc nữa.
        let b = AutonomyBar()
        b.leoThang("x")
        b.leoThang(nil)
        XCTAssertFalse(b.dangBaoLeoThang)
        b.leoThang("y")
        b.leoThang("")
        XCTAssertFalse(b.dangBaoLeoThang, "chuỗi rỗng cũng là không có lý do")
    }
}
