import XCTest
import AppKit
@testable import EIDEKit

/// Bộ từ vựng hiển thị — bảng, cây, mã, diff, dải trạng thái.
///
/// Đây là NỀN của cả 23 màn, nên chỗ này hỏng thì 23 màn hỏng theo mà không màn nào chỉ được về
/// đây. Test đi theo những thứ có thể sai mà vẫn trông đúng: phép sắp xếp số, cắt dữ liệu quá
/// lớn, chỉ số hàng sau khi sắp xếp.
final class EideTuVungTests: XCTestCase {

    private final class ManThu: ManHinhCoSo {
        init() { super.init(ten: "thử") }
    }

    // MARK: - Bảng

    func testBANGgiuDUsoHANGvaDOCduocTUNGo() {
        let m = ManThu()
        let b = m.themBang(cot: ["tên", "giá trị"],
                           hang: [["SRAM", "393216"], ["FLASH", "4194304"]])
        XCTAssertEqual(b.soHang, 2)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "SRAM")
        XCTAssertEqual(b.oDeTest(hang: 1, cot: 1), "4194304")
    }

    /// Sắp xếp một cột số phải so THEO SỐ.
    ///
    /// So chuỗi thì "1024" đứng trước "96" — bảng trông như đã sắp nên người ta tin nó, và một
    /// bảng ngân sách bộ nhớ sắp sai theo kiểu ấy dẫn thẳng tới kết luận sai về chip nào đủ RAM.
    func testSAPcotSOsoTHEOsoKHONGtheoCHUOI() {
        let m = ManThu()
        let b = m.themBang(cot: ["tên", "byte"],
                           hang: [["A", "1024"], ["B", "96"], ["C", "512"]])
        b.sapDeTest(cot: 1)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 1), "96")
        XCTAssertEqual(b.oDeTest(hang: 1, cot: 1), "512")
        XCTAssertEqual(b.oDeTest(hang: 2, cot: 1), "1024")
    }

    func testSAPlanHAIdaoNGUOCthuTU() {
        let m = ManThu()
        let b = m.themBang(cot: ["x"], hang: [["1"], ["2"], ["3"]])
        b.sapDeTest(cot: 0)
        b.sapDeTest(cot: 0)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "3")
    }

    /// Cột CHỮ vẫn so theo chữ — và so kiểu người đọc, không theo mã Unicode.
    func testSAPcotCHUsoTHEOchuCOdauTIENGviet() {
        let m = ManThu()
        let b = m.themBang(cot: ["tên"], hang: [["ổ cứng"], ["ắc quy"], ["bộ nhớ"]])
        b.sapDeTest(cot: 0)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "ắc quy")
    }

    /// Chỉ số trả về khi bấm phải là chỉ số trong dữ liệu GỐC.
    ///
    /// Sau khi sắp xếp, hàng thứ nhất trên màn không còn là phần tử thứ nhất của mảng. Trả nhầm
    /// chỉ số hiện thì bấm vào một fact mở ra một fact khác — và ở màn xung đột thì đó là chọn
    /// nhầm bên.
    func testBAMhangTRAveCHIsoGOCchuKHONGphaiCHIsoDANGhien() {
        let m = ManThu()
        var nhan: Int?
        let b = m.themBang(cot: ["x"], hang: [["3"], ["1"], ["2"]], chon: { nhan = $0 })
        b.sapDeTest(cot: 0)                       // hiện: 1, 2, 3 → hàng 0 là phần tử gốc thứ 1
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "1")
        b.onChon?(1)
        XCTAssertEqual(nhan, 1)
    }

    func testBANGquaLONthiCATvaNOIra() {
        let m = ManThu()
        let hang = (0..<(EideTuVung.hangToiDa + 50)).map { ["\($0)"] }
        let b = m.themBang(cot: ["x"], hang: hang)
        XCTAssertEqual(b.soHang, EideTuVung.hangToiDa)
        let noi = m.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " ")
        XCTAssertTrue(noi.contains("\(EideTuVung.hangToiDa)/\(EideTuVung.hangToiDa + 50)"),
                      "phải nói rõ cắt bao nhiêu, nhận: \(noi)")
    }

    /// Hàng thiếu ô không được làm sập bảng — dữ liệu từ daemon có thể thiếu trường.
    func testHANGthieuOthiDOCraCHUOIrongCHUkhongNO() {
        let m = ManThu()
        let b = m.themBang(cot: ["a", "b", "c"], hang: [["1"]])
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 2), "")
    }

    // MARK: - Cây

    private func cayMau() -> [EideNutCay] {
        [EideNutCay(ten: "du-an", duong: "/p", laThuMuc: true, con: [
            EideNutCay(ten: "src", duong: "/p/src", laThuMuc: true, con: [
                EideNutCay(ten: "main.c", duong: "/p/src/main.c", laThuMuc: false),
            ], moSan: true),
            EideNutCay(ten: "tests", duong: "/p/tests", laThuMuc: true, con: [
                EideNutCay(ten: "test_pid.c", duong: "/p/tests/test_pid.c", laThuMuc: false),
            ]),
        ], moSan: true)]
    }

    func testCAYmoSANthiHIENcon_khongMOthiGIAU() {
        let m = ManThu()
        let c = m.themCay(goc: cayMau())
        // du-an, src, main.c, tests — `tests` gấp nên `test_pid.c` không tính.
        XCTAssertEqual(c.soHangHien, 4)
    }

    func testCHONtheoDUONGmoMOInutCHAtrenDUONGdi() {
        let m = ManThu()
        let c = m.themCay(goc: cayMau())
        XCTAssertTrue(c.chon(duong: "/p/tests/test_pid.c"))
        XCTAssertEqual(c.soHangHien, 5, "phải mở `tests` ra thì mới chọn được con của nó")
    }

    func testCHONduongKHONGcoTRAve_false() {
        let m = ManThu()
        let c = m.themCay(goc: cayMau())
        XCTAssertFalse(c.chon(duong: "/p/khong-co.c"))
    }

    /// Thư mục RỖNG vẫn phải mở được — nếu không, nó trông y hệt một tệp.
    func testTHUMUCrongVANmoDUOC() {
        let m = ManThu()
        let goc = [EideNutCay(ten: "sim", duong: "/p/sim", laThuMuc: true)]
        let c = m.themCay(goc: goc)
        XCTAssertEqual(c.soHangHien, 1)
        XCTAssertTrue(c.chon(duong: "/p/sim"))
    }

    // MARK: - Mã

    func testMAdemDUNGsoDONGvaSOviPHAM() {
        let m = ManThu()
        let v = m.themMa(dong: [
            EideDongMa(so: 1, chu: "#include <stdio.h>"),
            EideDongMa(so: 2, chu: "#define ADDR 0x76u", fact: "BME280 addr 0x76"),
            EideDongMa(so: 3, chu: "i2c_write8(0xF5u, 0x27u);", viPham: true),
        ])
        XCTAssertEqual(v.soDongMa, 3)
        XCTAssertEqual(v.soViPham, 1)
    }

    func testTOIDONGkhongNOkhiSOdongKHONGton_tai() {
        let m = ManThu()
        let v = m.themMa(dong: [EideDongMa(so: 10, chu: "x")])
        v.toiDong(999)      // không có dòng 999 — không được nổ
        v.toiDong(10)
    }

    /// Số dòng là số dòng THẬT của tệp, không phải chỉ số mảng.
    ///
    /// Màn Mã nguồn hiện một đoạn quanh chỗ vi phạm, nên dòng đầu của khối có thể là dòng 112.
    /// Đánh số lại từ 1 thì cú bấm "mở dòng 117" nhảy tới dòng 5.
    func testSOdongGIUnguyenKHIchiHIENmotDOAN() {
        let m = ManThu()
        var mo: Int?
        let v = m.themMa(dong: (112...118).map { EideDongMa(so: $0, chu: "dòng \($0)") },
                         chonDong: { mo = $0 })
        XCTAssertEqual(v.soDongMa, 7)
        v.onChonDong?(117)
        XCTAssertEqual(mo, 117)
    }

    // MARK: - Diff

    func testDIFFtoMAUdungBAloaiDONG() {
        let m = ManThu()
        let v = m.themDiff("""
            --- a/src/main.c
            +++ b/src/main.c
            @@ -1,3 +1,3 @@
             void main(void)
            -    delay(100);
            +    vTaskDelay(pdMS_TO_TICKS(100));
            """)
        XCTAssertEqual(v.soDongMa, 6)
    }

    /// Dòng `---`/`+++` của phần đầu diff KHÔNG được tô như dòng xoá/thêm.
    ///
    /// Chúng bắt đầu bằng `-` và `+` nên một phép kiểm tiền tố ngây thơ sẽ tô đầu tệp thành một
    /// dòng đỏ và một dòng xanh — người đọc thấy "đã xoá a/src/main.c".
    func testDAUdiffKHONGbiTOnhuDONGxoaTHEM() {
        let m = ManThu()
        let v = m.themDiff("--- a/x.c\n+++ b/x.c\n+thêm thật")
        XCTAssertEqual(v.soDongMa, 3)
        XCTAssertEqual(v.mauDongDeTest(0), EideToken.Mau.muted)
        XCTAssertEqual(v.mauDongDeTest(1), EideToken.Mau.muted)
        XCTAssertEqual(v.mauDongDeTest(2), EideToken.Mau.ok)
    }

    // MARK: - Dải trạng thái

    func testDAItrangTHAIgiuDUso_O() {
        let m = ManThu()
        let d = m.themDaiTrangThai([
            .init("build", "3,1 s", mau: EideToken.Mau.ok),
            .init("Flash", "38%"),
            .init("constant-guard", "1 vi phạm", mau: EideToken.Mau.bad),
        ])
        XCTAssertEqual(d.soO, 3)
    }

    // MARK: - Không lồng vùng cuộn

    /// Khung nhìn nhỏ KHÔNG được bật bộ cuộn riêng.
    ///
    /// Thân màn đã cuộn; một bảng ba hàng có bộ cuộn riêng sẽ nuốt con lăn chuột khi trỏ vào nó,
    /// và người dùng lăn giữa màn thì nội dung ngoài đứng im. Lỗi này không lộ ra trên ảnh chụp.
    func testBANGnhoKHONGbatBOcuonRIENG() {
        let m = ManThu()
        let b = m.themBang(cot: ["x"], hang: [["1"], ["2"], ["3"]])
        XCTAssertFalse(b.coBoCuonDeTest, "bảng ba hàng không được có bộ cuộn riêng")
    }

    func testBANGdaiTHIbatBOcuonRIENG() {
        let m = ManThu()
        let b = m.themBang(cot: ["x"], hang: (0..<80).map { ["\($0)"] })
        XCTAssertTrue(b.coBoCuonDeTest, "bảng 80 hàng vượt trần chiều cao thì phải cuộn được")
    }
}

/// Màn Hộ chiếu chip dựng trên bộ từ vựng — bảng fact thay cho danh sách câu.
final class EidePassportBangTests: XCTestCase {

    private func manVoi(_ facts: [[String: Any]],
                        cit: [[String: Any]] = []) -> PassportView {
        let v = PassportView()
        v.capNhat(ketQua: ["facts": facts, "citations": cit,
                           "tiers": ["gold": facts.count], "latency_ms": 12])
        return v
    }

    private func bang(_ v: NSView) -> EideBangView? {
        if let b = v as? EideBangView { return b }
        for c in v.subviews { if let b = bang(c) { return b } }
        return nil
    }

    private let factMau: [[String: Any]] = [
        ["id": "f_1", "subject": "chip:esp.esp32c3/mem:SRAM", "predicate": "base_address",
         "value": 1070055424, "tier": "gold", "status": "conflict", "method": "parser",
         "confidence": 1.0, "source_id": "src_a"],
        ["id": "f_2", "subject": "chip:esp.esp32c3/mem:SRAM", "predicate": "memory_size",
         "value": 401408, "unit": "byte", "tier": "gold", "status": "normalized",
         "method": "parser", "confidence": 0.71, "source_id": "src_b"],
    ]

    func testFACTdungRAmotBANGchuKHONGphaiDANHsachCAU() throws {
        let v = manVoi(factMau)
        let b = try XCTUnwrap(bang(v), "màn Hộ chiếu phải dựng ra một bảng")
        XCTAssertEqual(b.soHang, 2)
        XCTAssertEqual(v.soDong, 2)
    }

    /// Địa chỉ phải ra hệ 16.
    ///
    /// `1070055424` đúng và vô dụng: không ai đối chiếu được nó với `0x3FC7C000` in trong
    /// datasheet mà không lấy máy tính ra — và đối chiếu chính là việc màn này sinh ra để làm.
    func testDIAchiHIENheXAdecIMAL() throws {
        let b = try XCTUnwrap(bang(manVoi(factMau)))
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 2), "0x3FC7C000")
    }

    /// Kích thước bộ nhớ hiện CẢ KiB lẫn số byte: KiB để so với ngân sách RAM, byte để đi vào
    /// script linker.
    func testKICHthuocBOnhoHIENkibVAbyte() throws {
        let b = try XCTUnwrap(bang(manVoi(factMau)))
        XCTAssertEqual(b.oDeTest(hang: 1, cot: 2), "392 KiB (401408)")
    }

    /// Trạng thái thắng tầng: một fact `gold` đang `conflict` phải hiện XUNG ĐỘT.
    func testFACTvangDANGxungDOThienLAxungDOT() throws {
        let b = try XCTUnwrap(bang(manVoi(factMau)))
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 4), "XUNG ĐỘT")
    }

    /// Cột Nguồn hiện TÊN TỆP, không hiện mã băm.
    func testCOTnguonHIENtenTEPchuKHONGphaiMAbam() throws {
        let b = try XCTUnwrap(bang(manVoi(
            factMau,
            cit: [["source_id": "src_a", "uri": "/tmp/tai-lieu/esp32c3-trm-v1.1.pdf"],
                  ["source_id": "src_b", "uri": "/tmp/tai-lieu/ds-rev0.4.pdf"]])))
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 7), "esp32c3-trm-v1.1.pdf")
    }

    /// Không có `citations` thì rơi về `source_id` chứ không để trống: một ô trống nói rằng fact
    /// này không có nguồn, mà đó là điều nghiêm trọng hơn hẳn "chưa biết tên tệp".
    func testTHIEUcitationsTHIroiVEsourceID() throws {
        let b = try XCTUnwrap(bang(manVoi(factMau)))
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 7), "src_a")
    }

    /// Bấm một hàng mở chuỗi truy nguồn của ĐÚNG fact ấy, kể cả sau khi sắp xếp lại.
    func testBAMhangSAUkhiSAPvanMOdungFACT() throws {
        let v = manVoi(factMau)
        var mo: String?
        v.onXemNguon = { mo = $0 }
        let b = try XCTUnwrap(bang(v))
        b.sapDeTest(cot: 5)                       // sắp theo độ tin: 0.71 lên đầu
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 5), "0.71")
        b.onChon?(1)                              // chỉ số GỐC của fact 0.71 là 1
        XCTAssertEqual(mo, "f_2")
    }

    func testKHONGcoFACTthiKHONGdungBANGrong() {
        let v = manVoi([])
        XCTAssertNil(bang(v), "không fact nào thì đừng dựng một bảng có tiêu đề cột và rỗng ruột")
    }
}

/// Bố cục bảng — chiều cao và cuộn ngang.
///
/// Hai lỗi đo được trên ảnh chụp 15/09/2026, và cả hai đều KHÔNG lộ ra trong một bài kiểm hỏi
/// "bảng có đúng số hàng không": hàng cuối bị cắt ngang, và ba cột cuối nằm ngoài mép không có
/// cách nào tới.
final class EideBangBoCucTests: XCTestCase {

    private final class ManThu: ManHinhCoSo {
        init() { super.init(ten: "thử") }
    }

    /// Khung bảng phải cao đủ cho MỌI hàng, không cắt hàng cuối.
    ///
    /// Một hàng bị cắt nửa dưới trông y như một hàng bình thường nếu không nhìn kỹ — và ở bảng
    /// fact thì hàng cuối có thể là hàng XUNG ĐỘT.
    func testKHUNGcaoDUchoMOIhangKHONGcatHANGcuoi() {
        let m = ManThu()
        let n = 8
        let b = m.themBang(cot: ["a", "b"], hang: (0..<n).map { ["\($0)", "x"] })
        b.layoutSubtreeIfNeeded()
        let canToiThieu = b.caoDauDeTest + CGFloat(n) * b.caoHangDeTest
        XCTAssertGreaterThanOrEqual(b.frame.height, canToiThieu,
                                    "khung cao \(b.frame.height) nhưng cần ít nhất \(canToiThieu)")
    }

    /// Bảng nhiều cột phải cuộn NGANG được.
    ///
    /// Không có nó thì cột nằm ngoài mép bằng cột không tồn tại — chỉ tệ hơn ở chỗ người dùng
    /// biết nó có ở đó.
    func testBANGnhieuCOTcuonNGANGduoc() {
        let m = ManThu()
        let b = m.themBang(cot: (0..<10).map { "cột dài số \($0)" },
                           hang: [(0..<10).map { "giá trị \($0)" }])
        XCTAssertTrue(b.coCuonNgangDeTest)
    }

    /// Bảng nhỏ vẫn KHÔNG được có bộ cuộn dọc — quy tắc "không lồng vùng cuộn" giữ nguyên.
    func testTHEMcuonNGANGkhongLAMbangNHOcoCUONdoc() {
        let m = ManThu()
        let b = m.themBang(cot: ["x"], hang: [["1"], ["2"]])
        XCTAssertFalse(b.coBoCuonDeTest)
    }
}
