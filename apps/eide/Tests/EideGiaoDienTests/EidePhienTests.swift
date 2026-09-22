import AppKit
import XCTest
@testable import EideGiaoDien

/// Ba phép đo cho lớp phiên. Tất cả đều là những chỗ đã HỎNG THẬT trong bản trước và hỏng im
/// lặng: một dòng chữ sai trong cột phải trông y hệt một dòng chữ đúng.
@MainActor
final class EidePhienTests: XCTestCase {

    /// `datetime.isoformat()` của Python có phần thập phân của giây. `ISO8601DateFormatter` mặc
    /// định trả `nil` cho dạng ấy, và mọi mục hoàn tác hiện "hạn không rõ".
    func testHanCoPhanThapPhanVanDocDuoc() {
        let sau = Date().addingTimeInterval(3600)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(EidePhien.conLai(f.string(from: sau), cua: "60m"), "còn 60 phút")
        f.formatOptions = [.withInternetDateTime]
        XCTAssertEqual(EidePhien.conLai(f.string(from: sau), cua: "60m"), "còn 60 phút")
    }

    /// Cửa sổ `session` không có mốc hạn — nhưng hạn của nó rất rõ.
    func testCuaSoPhienKhongPhaiHanKhongRo() {
        XCTAssertEqual(EidePhien.conLai(nil, cua: "session"), "đến khi mở phiên mới")
        XCTAssertEqual(EidePhien.conLai(nil, cua: nil), "hạn không rõ")
        XCTAssertEqual(EidePhien.conLai("không-phải-ngày", cua: "60m"), "hạn không rõ")
    }

    func testMocDaQuaThiNoiRaLaHetHan() {
        let truoc = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-10))
        XCTAssertEqual(EidePhien.conLai(truoc, cua: "60m"), "đã hết hạn")
    }

    /// Màn chào phủ TOÀN cửa sổ khi chưa có dự án, và biến mất hẳn khi đã có.
    func testManChaoPhuToanKhungRoiAnHan() {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        k.layoutSubtreeIfNeeded()
        XCTAssertTrue(k.dangChao)
        XCTAssertEqual(k.manChao.frame, k.bounds)
        k.anManChao()
        XCTAssertFalse(k.dangChao)
    }

    /// Dải "Dữ liệu cũ" chiếm 0 pt khi bình thường: nó không được đẩy vùng làm việc xuống chỉ
    /// vì có mặt trong cây khung nhìn.
    func testDaiDuLieuCuKhongChiemChoKhiBinhThuong() {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        k.layoutSubtreeIfNeeded()
        let cao0 = k.vungLamViec.frame.height
        k.datDuLieuCu(true, tre: 7)
        k.layoutSubtreeIfNeeded()
        XCTAssertEqual(cao0 - k.vungLamViec.frame.height, 28, accuracy: 0.5)
        k.datDuLieuCu(false, tre: 0)
        k.layoutSubtreeIfNeeded()
        XCTAssertEqual(k.vungLamViec.frame.height, cao0, accuracy: 0.5)
    }

    /// Cột phải chỉ hiện `TOI_DA` thẻ — nhưng KHÔNG im lặng về phần bị cắt.
    func testCotPhaiNoiRaPhanBiCat() {
        let c = EideCotPhai(frame: NSRect(x: 0, y: 0, width: 236, height: 800))
        c.datHoanTac((1...20).map { (ma: "u\($0)", nhan: "code.write", han: "còn 3 phút") })
        let van = _chuTrong(c)
        XCTAssertTrue(van.contains("… và \(20 - EideCotPhai.TOI_DA) mục nữa"), van)
    }

    private func _chuTrong(_ v: NSView) -> String {
        var ra = (v as? NSTextField)?.stringValue ?? ""
        for c in v.subviews { ra += "\n" + _chuTrong(c) }
        return ra
    }
}

/// `EidePhien.doiLaiGi` — dòng chữ người dùng ĐỌC sau khi bấm Hoàn tác. [DEV-170]
///
/// "Đã hoàn tác (supersede_facts)" trả lời sai câu hỏi họ đang hỏi: họ không hỏi loại hoàn tác
/// là gì, họ hỏi cái gì vừa đổi. Tên loại là từ vựng của POL-17 §5, không phải của người bấm.
@MainActor
final class EideHoanTacNoiGiTests: XCTestCase {

    func testRutFactThiNoiRoBaoNhieuVaTraLaiBaoNhieu() {
        let s = EidePhien.doiLaiGi(["kind": "supersede_facts",
                                    "superseded": ["f_1", "f_2"], "restored": ["f_0"],
                                    "kept": [] as [Any]])
        XCTAssertEqual(s, " — rút 2 fact, trả 1 fact cũ về")
    }

    /// Fact BỎ QUA cũng phải hiện. Một lượt chạy tạo mười fact mà người đã duyệt tám, bấm hoàn
    /// tác xong chỉ thấy "rút 2 fact" sẽ đọc thành "tám cái kia mất đâu rồi".
    func testFactGiuNguyenCungPhaiHien() {
        let s = EidePhien.doiLaiGi(["superseded": [] as [Any], "restored": [] as [Any],
                                    "kept": [["fact": "f_9", "vi_sao": "người đã xác nhận"]]])
        XCTAssertEqual(s, " — giữ nguyên 1 fact")
    }

    func testLuiCauTraLoiThiNoiQuayVeBanNao() {
        XCTAssertEqual(EidePhien.doiLaiGi(["clar_id": "CL-abc", "quay_ve": "8 MB, 20 giây"]),
                       " — quay về: 8 MB, 20 giây")
        XCTAssertEqual(EidePhien.doiLaiGi(["clar_id": "CL-abc"]),
                       " — điểm này về chưa trả lời")
    }

    func testDaoCommitThiNoiSoCommit() {
        XCTAssertEqual(EidePhien.doiLaiGi(["muc": "run", "reverted": 3]), " — đảo 3 commit")
        XCTAssertEqual(EidePhien.doiLaiGi(["muc": "commit", "commit": "abcdef1234567",
                                           "revert_commit": "9876543210fed"]),
                       " — commit 98765432")
    }

    /// Loại nào không có gì để nói thì IM, chứ không bịa một con số cho đủ câu. `restore_config`
    /// trả về trạng thái dự án, không trả về số đếm nào.
    func testKhongCoGiDeNoiThiImLang() {
        XCTAssertEqual(EidePhien.doiLaiGi(["muc": "known-good", "tag": "v0.1"]), "")
        XCTAssertEqual(EidePhien.doiLaiGi(["superseded": [] as [Any]]), "")
    }
}

/// `EideDoNoiDung.daHien` — phép đo của cổng kiểm soát nội dung màn. [chặng 0b]
///
/// Phép đo cũng phải có phép đo: một bộ dò so chữ sai sẽ hoặc xanh mù (bỏ sót màn rỗng) hoặc
/// đỏ oan (đỏ vì hoa thường), và cả hai đều dẫn tới cùng một kết cục — người ta tắt nó đi.
@MainActor
final class EideDoNoiDungTests: XCTestCase {

    private func muc(_ dau: [String], do_duoc: Bool = true) -> EideDoNoiDung.Muc {
        EideDoNoiDung.Muc(mo_ta: "x", dau_hieu: dau, do_duoc: do_duoc)
    }

    func testCHI_CAN_MOT_dau_hieu_khop() {
        // Một khối dữ liệu diễn đạt được vài cách. Bắt khớp HẾT mọi mẩu chữ biến bộ dò thành
        // phép so giao diện từng pixel — đỏ mỗi lần đổi chữ, và vì thế bị tắt.
        let m = muc(["Tầng", "tier"])
        XCTAssertTrue(EideDoNoiDung.daHien(m, trong: "Bảng nguồn · tier · số fact"))
        XCTAssertTrue(EideDoNoiDung.daHien(m, trong: "Cột Tầng tin cậy"))
        XCTAssertFalse(EideDoNoiDung.daHien(m, trong: "màn này chưa có gì"))
    }

    /// Nhãn có thể viết "Tầng" hay "TẦNG" hay "tang"; một bộ dò đỏ vì chữ hoa là bộ dò dạy
    /// người ta bỏ qua nó.
    func testBO_QUA_hoa_thuong_va_dau_tieng_Viet() {
        XCTAssertTrue(EideDoNoiDung.daHien(muc(["Tầng"]), trong: "CỘT TANG TIN CAY"))
        XCTAssertTrue(EideDoNoiDung.daHien(muc(["CÒN THIẾU"]), trong: "khối còn thiếu"))
    }

    /// Mục chưa có dấu hiệu thì KHÔNG kết tội màn — nhưng script sinh đếm và in chúng ra, nên
    /// chúng không im lặng biến mất khỏi báo cáo.
    func testMuc_CHUA_do_duoc_thi_khong_ket_toi() {
        XCTAssertTrue(EideDoNoiDung.daHien(muc([], do_duoc: false), trong: ""))
    }

    func testDau_hieu_rong_khong_khop_bua() {
        XCTAssertFalse(EideDoNoiDung.daHien(muc([""]), trong: "bất kỳ chữ gì"))
    }

    /// Hợp đồng nội dung phải ĐỌC ĐƯỢC từ kho — thiếu tệp thì cổng phải nói ra, không âm thầm
    /// xanh vì không có gì để so.
    func testDoc_duoc_hop_dong_tu_kho() throws {
        let goc = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent().deletingLastPathComponent()
        guard let hd = EideDoNoiDung.hopDong(goc) else {
            throw XCTSkip("chạy ngoài gốc kho — không tìm thấy docs/spec/ui/man_can_hien.json")
        }
        XCTAssertGreaterThanOrEqual(hd.count, 25)
        XCTAssertNotNil(hd["PlanDiff"])
        XCTAssertTrue(hd.values.allSatisfy { !$0.muc.isEmpty })
    }
}
