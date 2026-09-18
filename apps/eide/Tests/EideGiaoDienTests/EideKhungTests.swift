import XCTest
import AppKit
@testable import EideGiaoDien

final class EideKhungTests: XCTestCase {

    @MainActor
    func testNAM_VUNG_dung_kich_thuoc_ban_demo() {
        // Ba con số này là HỢP ĐỒNG với `EIDE_UI_Demo_v2.html`, không phải lựa chọn của mã.
        XCTAssertEqual(EideKhung.CAO_THANH_TREN, 46)
        XCTAssertEqual(EideKhung.RONG_COT_TRAI, 198)
        XCTAssertEqual(EideKhung.RONG_COT_PHAI, 236)
    }

    @MainActor
    func testBO_CUC_khong_co_vung_nao_co_ve_0() {
        // Bài học đắt nhất của bản cũ: một bố cục không có kích thước nội tại co về 0 trong im
        // lặng, và cửa sổ tụt từ 720 xuống 70 pt mà không một dòng log nào.
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        k.layoutSubtreeIfNeeded()
        XCTAssertEqual(k.cotTrai.frame.width, 198)
        XCTAssertEqual(k.cotPhai.frame.width, 236)
        XCTAssertEqual(k.thanhTren.frame.height, 46)
        XCTAssertEqual(k.dock.frame.height, 220)
        XCTAssertGreaterThan(k.vungLamViec.frame.height, 200,
                             "vùng làm việc bị ép — nó phải là vùng GIÃN")
        XCTAssertGreaterThan(k.vungLamViec.frame.width, 800)
    }

    @MainActor
    func testDOCK_BA_trang_thai_va_khong_cai_nao_bang_0() {
        // B3: vùng trao đổi là BẤT BIẾN. Thu gọn vẫn để lại ô gõ.
        for c in EideDock.Cao.allCases {
            XCTAssertGreaterThanOrEqual(c.rawValue, 48, "\(c) thấp hơn sàn tuyệt đối")
        }
        XCTAssertEqual(EideDock.Cao.thuGon.rawValue, 48)
        XCTAssertEqual(EideDock.Cao.chuan.rawValue, 220)
        XCTAssertEqual(EideDock.Cao.moRong.rawValue, 320)
    }

    @MainActor
    func testDIEU_HUONG_SAU_nhom_moi_nhom_2_den_5_muc() {
        // Tiêu chí N8 của UXC-31, và giới hạn quét 7±2 của con người.
        XCTAssertEqual(EideManHinhDS.nhom.count, 6)
        for n in EideManHinhDS.nhom {
            XCTAssertTrue((2...5).contains(n.man.count), "\(n.ten): \(n.man.count) mục")
            XCTAssertFalse(n.cauHoi.isEmpty, "\(n.ten) thiếu CÂU HỎI — lý do nhóm tồn tại")
        }
        XCTAssertEqual(EideManHinhDS.tatCa.count, 25)
    }

    @MainActor
    func testMA_MAN_lien_mach_S1_den_S25() {
        // Bản cũ có `2b`, `7b`, `8b` vì ba màn được chèn giữa bảng mà không đánh số lại; người
        // ngoài đọc thấy "26 màn" nhưng số cao nhất là 23.
        XCTAssertEqual(EideManHinhDS.tatCa.map(\.ma), (1...25).map { "S\($0)" })
    }

    @MainActor
    func testTAB_mo_lai_KHONG_tao_ban_thu_hai() {
        let t = EideThanhTab()
        t.mo("Passport"); t.mo("Env"); t.mo("Passport")
        XCTAssertEqual(t.tab, ["Passport", "Env"])
        XCTAssertEqual(t.dangMo, "Passport")
        XCTAssertEqual(t.dong("Passport"), "Env")
        XCTAssertNil(t.dong("Env"))
    }

    @MainActor
    func testVUNG_LAM_VIEC_rong_thi_noi_DU_HAI_phan() {
        // B5: lý do rỗng, và bước kế tiếp. Thiếu vế sau thì người dùng đứng im.
        let v = EideVungLamViec()
        v.moMan("Discovery", nangLucDs: ["discover.ports"])
        v.khiRong(vi: "chưa có bo mạch cắm vào máy", buocKe: "cắm board rồi bấm Dò lại")
        XCTAssertEqual(v.soThan, 2)
    }
}
