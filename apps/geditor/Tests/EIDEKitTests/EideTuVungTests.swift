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

/// Màn "Kế hoạch & mã" — nửa MÃ, vốn hoàn toàn vắng mặt tới 15/09/2026.
///
/// Màn này là cổng G3: chỗ người duyệt mã do mô hình sinh ra. Bản cũ hiện kế hoạch rất kỹ rồi
/// dừng — không một dòng mã nào lên màn, dù `code.*` trả `patch`. Người dùng được mời duyệt một
/// thứ họ không nhìn thấy.
final class EidePlanDiffBanVaTests: XCTestCase {

    private func manVoi(_ va: [String: Any]) -> PlanDiffView {
        let v = PlanDiffView()
        v.capNhat(ketQua: ["patch": va])
        return v
    }

    private func khoiMa(_ v: NSView) -> [EideMaView] {
        var ra: [EideMaView] = []
        if let m = v as? EideMaView { ra.append(m) }
        for c in v.subviews { ra += khoiMa(c) }
        return ra
    }

    private let diffMau = """
        --- a/src/bme280.c
        +++ b/src/bme280.c
        @@ -38,6 +38,9 @@
         uint8_t id = i2c_read8(BME280_ADDR, 0xD0);
        +if (id != 0x60) return -ENODEV;
        +uint8_t ctrl = (1u << 5) | 0x3u;
        -i2c_write8(BME280_ADDR, 0xF4, 0x27);
        """

    func testDIFFdungRAmotKHOIma() {
        let v = manVoi(["files": [["path": "src/bme280.c", "content": diffMau, "mode": "diff"]],
                        "cites": ["f_b1"], "rationale": "kiểm id trước khi cấu hình"])
        XCTAssertEqual(v.soTep, 1)
        XCTAssertEqual(khoiMa(v).count, 1, "bản vá một tệp phải ra đúng một khối mã")
    }

    /// Tóm tắt `+n −m` không được đếm hai dòng đầu của diff.
    ///
    /// `+++`/`---` bắt đầu bằng `+`/`-` nhưng là TÊN TỆP. Đếm chúng làm mọi bản vá một-tệp đều
    /// dư ra đúng một dòng thêm và một dòng bớt — một sai số nhỏ, đều, và không ai kiểm.
    func testTOMtatDIFFkhongDEMhaiDONGdauTEP() throws {
        let v = manVoi(["files": [["path": "a.c", "content": diffMau, "mode": "diff"]]])
        let nhan = v.cot.arrangedSubviews.compactMap { hang -> String? in
            guard let s = hang as? NSStackView, s.arrangedSubviews.count == 2,
                  let trai = s.arrangedSubviews[0] as? NSTextField,
                  let phai = s.arrangedSubviews[1] as? NSTextField,
                  trai.stringValue == "a.c" else { return nil }
            return phai.stringValue
        }
        XCTAssertEqual(nhan.first, "+2 −1")
    }

    /// `replace` phải NÓI RA là thay cả tệp.
    ///
    /// Hiện nó như diff là nói dối về phạm vi: người đọc thấy vài dòng và tưởng chỉ đổi bấy
    /// nhiêu, trong khi toàn bộ tệp cũ vừa bị bỏ đi.
    func testREPLACEnoiROlaTHAYcaTEP() {
        let v = manVoi(["files": [["path": "x.c", "content": "a\nb\nc", "mode": "replace"]]])
        XCTAssertEqual(v.soTepThayCaTep, 1)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("THAY CẢ TỆP"), "nhận: \(chu)")
    }

    func testCREATEhienLAtepMOIchuKHONGphaiCANHbao() {
        let v = manVoi(["files": [["path": "moi.c", "content": "int main(void){}", "mode": "create"]]])
        XCTAssertEqual(v.soTepThayCaTep, 1)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("TỆP MỚI"))
        XCTAssertFalse(chu.contains("THAY CẢ TỆP"))
    }

    /// Mã không trích dẫn fact nào phải nói ra — constant-guard sẽ chặn nó ở G-FACT, và biết
    /// trước khi đọc mã thì đỡ hơn biết sau khi duyệt.
    func testKHONGtrichDANthiNOIra() {
        let v = manVoi(["files": [["path": "a.c", "content": diffMau, "mode": "diff"]], "cites": []])
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("KHÔNG trích dẫn fact nào"), "nhận: \(chu)")
    }

    /// `missing_facts` phải lên TRƯỚC mã: mã trích một fact không có là mã dựa trên phỏng đoán.
    func testMISSINGfactsHIENraVAdungTRUOCkhoiMA() {
        let v = manVoi(["files": [["path": "a.c", "content": diffMau, "mode": "diff"]],
                        "missing_facts": ["f_khong_co", "f_cung_khong"]])
        let nhan = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .compactMap { ($0.first as? NSTextField)?.stringValue }
        let iThieu = try? XCTUnwrap(nhan.firstIndex { $0.contains("fact CHƯA CÓ") })
        let iTep = nhan.firstIndex { $0 == "a.c" }
        XCTAssertNotNil(iThieu)
        if let a = iThieu, let b = iTep { XCTAssertLessThan(a, b) }
    }

    /// Bản vá RỖNG không được đọc như "kế hoạch rỗng".
    func testBANvaKHONGcoTEPthiVANnoiDUOCla_khongCOgi() {
        let v = manVoi(["files": [], "rationale": "không cần sửa gì"])
        XCTAssertEqual(v.soTep, 0)
        XCTAssertEqual(khoiMa(v).count, 0)
    }
}

/// Hình học của khối mã trong màn "Kế hoạch & mã".
///
/// Màn này không chụp ảnh được bằng dữ liệu thật: `plan.create` và `code.*` đều cần khoá mô
/// hình, và bản vá chỉ tồn tại sau khi một mô hình sinh ra nó. Nên lớp lỗi mà ảnh chụp thường
/// bắt — khối bị cắt, khối cao 0, khối tràn khỏi khung — phải đo bằng hình học ở đây.
final class EidePlanDiffHinhHocTests: XCTestCase {

    private func dungMan(_ soDong: Int) -> PlanDiffView {
        let diff = (0..<soDong).map { "+dòng thêm số \($0)" }.joined(separator: "\n")
        let v = PlanDiffView()
        v.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        v.capNhat(ketQua: ["patch": ["files": [["path": "a.c", "content": diff, "mode": "diff"]]]])
        v.layoutSubtreeIfNeeded()
        return v
    }

    private func khoiMa(_ v: NSView) -> EideMaView? {
        if let m = v as? EideMaView { return m }
        for c in v.subviews { if let m = khoiMa(c) { return m } }
        return nil
    }

    func testKHOImaCOchieuCAOthatCHUkhongPHAIso0() throws {
        let m = try XCTUnwrap(khoiMa(dungMan(6)))
        XCTAssertGreaterThan(m.frame.height, 40, "khối mã cao \(m.frame.height) pt — gần như không thấy")
    }

    /// Diff DÀI phải dừng ở trần, không kéo màn dài vô tận.
    ///
    /// Một bản vá 3.000 dòng mà khối mã cao 3.000 hàng thì mọi thứ dưới nó — nút Duyệt, khối
    /// rà soát — bị đẩy ra ngoài tầm với.
    func testDIFFdaiDUNGoTRANkhongKEOmanDAIvoTAN() throws {
        let m = try XCTUnwrap(khoiMa(dungMan(3000)))
        XCTAssertLessThanOrEqual(m.frame.height, EideTuVung.caoToiDa + 1)
    }

    /// Diff dài BỊ CẮT, và màn phải nói ra bằng câu của cổng G3.
    ///
    /// Trần 2.000 dòng là có thật và cần thiết (dựng 3.000 hàng view làm treo cửa sổ). Nhưng ở
    /// màn này, "cắt bớt cho gọn" có một nghĩa khác hẳn so với ở một bảng fact: người dùng đang
    /// đứng trước nút Duyệt, và phần bị cắt là **mã họ sắp chấp nhận mà không nhìn thấy**. Nên
    /// câu cảnh báo phải nói đúng điều đó, không nói "để cửa sổ không treo".
    func testDIFFdaiBIcatVAnoiRAbangCAUcuaCONGduyet() throws {
        let v = dungMan(3000)
        let m = try XCTUnwrap(khoiMa(v))
        XCTAssertEqual(m.soDongMa, EideTuVung.hangToiDa)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            .joined(separator: " ")
        XCTAssertTrue(chu.contains("\(EideTuVung.hangToiDa)/3000"), "phải nói rõ cắt bao nhiêu")
        XCTAssertTrue(chu.lowercased().contains("duyệt"),
                      "cảnh báo ở màn duyệt mã phải nói về việc DUYỆT, nhận: \(chu)")
    }

    /// Khối mã không được rộng hơn màn chứa nó.
    func testKHOImaKHONGtranRAngoaiMAN() throws {
        let v = dungMan(6)
        let m = try XCTUnwrap(khoiMa(v))
        XCTAssertLessThanOrEqual(m.frame.width, v.frame.width + 1,
                                 "khối mã rộng \(m.frame.width) trong màn rộng \(v.frame.width)")
    }
}

/// Màn "Bản đồ tri thức" — đồ thị dựng thành cây theo CẠNH.
///
/// Bản cũ nhóm nút theo tầng rồi liệt kê phẳng và không hiện một cạnh nào, dù dòng tóm tắt ngay
/// trên đó đếm chúng. Với dữ liệu thật của dự án demo: 17 nút, 26 cạnh, và cả 26 cạnh biến mất.
final class EideKgCayTests: XCTestCase {

    private func man(_ nodes: [[String: Any]], _ edges: [[String: Any]]) -> KgMapView {
        let v = KgMapView()
        v.capNhat(ketQua: ["graph": ["nodes": nodes, "edges": edges]])
        return v
    }

    private func cay(_ v: NSView) -> EideCayView? {
        if let c = v as? EideCayView { return c }
        for s in v.subviews { if let c = cay(s) { return c } }
        return nil
    }

    private let nodes: [[String: Any]] = [
        ["id": "chip:x", "kind": "chip", "label": "chip:x"],
        ["id": "chip:x/mem:SRAM", "kind": "chip", "label": "mem:SRAM", "tier": "gold"],
        ["id": "f_1", "kind": "fact", "label": "f_1", "tier": "gold", "status": "conflict"],
        ["id": "src_a", "kind": "source", "label": "src_a"],
    ]
    private let edges: [[String: Any]] = [
        ["from": "chip:x", "type": "HAS", "to": "chip:x/mem:SRAM"],
        ["from": "f_1", "type": "ABOUT", "to": "chip:x/mem:SRAM"],
        ["from": "f_1", "type": "CITES", "to": "src_a"],
    ]

    func testDOthiDUNGrAmotCAYchuKHONGphaiDANHsachPHANG() throws {
        let v = man(nodes, edges)
        XCTAssertNotNil(cay(v), "đồ thị phải dựng ra một cây")
        XCTAssertEqual(v.soNut, 4)
        XCTAssertEqual(v.soCanh, 3)
    }

    /// Gốc là nút KHÔNG AI TRỎ TỚI — đúng hình dạng mockup vẽ (`chip:` trên cùng).
    func testGOClaNUTkhongAItroTOI() throws {
        let c = try XCTUnwrap(cay(man(nodes, edges)))
        // chip:x và f_1 là gốc; mem:SRAM và src_a là con → 4 hàng khi mở hết.
        XCTAssertTrue(c.chon(duong: "chip:x"))
        XCTAssertTrue(c.chon(duong: "chip:x/mem:SRAM"), "con của chip phải nằm trong cây")
        XCTAssertTrue(c.chon(duong: "src_a"))
    }

    /// Cạnh TRÙNG không được làm cây hiện cùng một con hai lần.
    ///
    /// `view.kg_map` trả `chip → HAS → mem:SRAM` hai lần trên dữ liệu thật (một lần cho mỗi fact
    /// về cùng chủ thể). Không bỏ trùng thì người đọc tưởng có hai vùng nhớ tên SRAM.
    func testCANHtrungKHONGlamCONxuatHIENhaiLAN() {
        let khong = man(nodes, edges).soNutTrenCay
        let co = man(nodes, edges
                     + [["from": "chip:x", "type": "HAS", "to": "chip:x/mem:SRAM"]]).soNutTrenCay
        XCTAssertEqual(co, khong, "thêm một cạnh TRÙNG không được làm cây dài thêm")
    }

    /// Một nút dùng chung xuất hiện dưới MỌI cha — và đó là chủ ý.
    ///
    /// `mem:SRAM` vừa là con `HAS` của chip vừa là đích `ABOUT` của fact. Gộp lại thành một hàng
    /// sẽ giấu mất một trong hai quan hệ, mà quan hệ mới là thứ màn này hiện ra để nói.
    func testNUTdungCHUNGxuatHIENduoiMOIcha() {
        // 4 nút, nhưng 5 hàng: mem:SRAM nằm dưới cả chip:x lẫn f_1.
        XCTAssertEqual(man(nodes, edges).soNutTrenCay, 5)
    }

    /// Chu trình không được làm cây dựng tới hết bộ nhớ.
    ///
    /// `SUPERSEDES` nối fact cũ với fact mới và có thể vòng lại.
    func testCHUtrinhKHONGlamCAYdungVOtan() {
        let n: [[String: Any]] = [["id": "a", "label": "a"], ["id": "b", "label": "b"]]
        let e: [[String: Any]] = [["from": "a", "type": "SUPERSEDES", "to": "b"],
                                  ["from": "b", "type": "SUPERSEDES", "to": "a"]]
        let v = man(n, e)
        XCTAssertNotNil(cay(v), "đồ thị toàn chu trình vẫn phải ra cây, không ra màn trống")
        XCTAssertLessThan(v.soNutTrenCay, 20, "chu trình phải bị chặn, nhận \(v.soNutTrenCay)")
    }

    /// Nút CÔ LẬP phải hiện ra — như một gốc của chính nó.
    ///
    /// Một fact không ABOUT chủ thể nào, không CITES nguồn nào là fact đáng ngờ nhất trong
    /// store. Bậc vào của nó là 0 nên nó thành gốc và nằm trong cây; giấu nó vì nó không hợp
    /// hình dạng cây là đúng kiểu im lặng màn này phải chống.
    func testNUTcoLAPvanHIENra() throws {
        let v = man(nodes + [["id": "f_co_lap", "label": "f_co_lap", "kind": "fact"]], edges)
        let c = try XCTUnwrap(cay(v))
        XCTAssertTrue(c.chon(duong: "f_co_lap"), "nút cô lập phải nằm trong cây")
    }

    /// Một cụm TOÀN chu trình không tới được từ gốc nào — phải nói ra, không nuốt.
    func testCUMtoanCHUtrinhKHONGtoiduocTHIphaiNOIra() {
        let n: [[String: Any]] = [["id": "goc", "label": "goc"],
                                  ["id": "x", "label": "x"], ["id": "y", "label": "y"]]
        let e: [[String: Any]] = [["from": "x", "type": "SUPERSEDES", "to": "y"],
                                  ["from": "y", "type": "SUPERSEDES", "to": "x"]]
        let v = man(n, e)
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("KHÔNG nối vào đâu"), "nhận: \(chu)")
    }

    /// Bấm một nút trên cây mở đúng nút ấy.
    func testBAMnutTRENcayMOdungNUT() throws {
        let v = man(nodes, edges)
        var mo: String?
        v.onMoNut = { mo = $0 }
        let c = try XCTUnwrap(cay(v))
        XCTAssertTrue(c.chon(duong: "src_a"))
        c.onChon?(EideNutCay(ten: "src_a", duong: "src_a", laThuMuc: false))
        XCTAssertEqual(mo, "src_a")
    }
}

/// Thân màn và cây phải bắt đầu từ ĐẦU, không từ giữa.
final class EideCuonTuDauTests: XCTestCase {

    private final class ManThu: ManHinhCoSo {
        init() { super.init(ten: "thử") }
    }

    /// Nội dung dài hơn khung phải hiện phần ĐẦU.
    ///
    /// Hệ toạ độ mặc định của AppKit có gốc ở góc dưới-trái, nên một `NSStackView` dài hơn khung
    /// neo từ dưới lên: mở màn ra là thấy phần cuối. Một màn mở ra ở cuối danh sách trông y như
    /// một màn thiếu phần đầu — mà dòng đầu thường là dòng quan trọng nhất.
    func testTHANmanBATdauTUdongDAU() {
        let m = ManThu()
        m.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        for i in 0..<60 { m.themDong("dòng \(i)", "x") }
        m.layoutSubtreeIfNeeded()
        let cuon = m.subviews.compactMap { $0 as? NSScrollView }.first
        XCTAssertNotNil(cuon)
        XCTAssertTrue(cuon?.contentView is KhungLat,
                      "khung cuộn của thân màn phải LẬT thì nội dung mới bắt đầu từ trên")
    }

    /// Cây mở sẵn nhiều tầng vẫn phải hiện từ hàng 0.
    ///
    /// `expandItem` đẩy vị trí cuộn theo hàng vừa mở — người đọc thấy một nút con ở dòng đầu và
    /// không biết nó là con của ai.
    func testCAYmoSANvanHIENtuHANGdau() {
        let m = ManThu()
        m.frame = NSRect(x: 0, y: 0, width: 600, height: 300)
        let goc = (0..<20).map { i in
            EideNutCay(ten: "g\(i)", duong: "g\(i)", laThuMuc: true, con: [
                EideNutCay(ten: "c\(i)", duong: "c\(i)", laThuMuc: false),
            ], moSan: true)
        }
        let c = m.themCay(goc: goc)
        m.layoutSubtreeIfNeeded()
        XCTAssertEqual(c.hangDauDeTest, 0, "cây phải hiện từ hàng 0, nhận \(c.hangDauDeTest)")
    }

    /// Cây dài phải cao bằng trần, không co lại thành vài dòng.
    func testCAYdaiCAObangTRAN() {
        let m = ManThu()
        m.frame = NSRect(x: 0, y: 0, width: 600, height: 900)
        let goc = (0..<60).map { EideNutCay(ten: "g\($0)", duong: "g\($0)", laThuMuc: false) }
        let c = m.themCay(goc: goc)
        m.layoutSubtreeIfNeeded()
        XCTAssertEqual(c.frame.height, EideTuVung.caoToiDa, accuracy: 1,
                       "cây dài phải cao \(EideTuVung.caoToiDa) pt, nhận \(c.frame.height)")
    }
}

/// Khung nhìn nhúng phải giữ chiều cao của nó kể cả khi MÀN nhỏ hơn.
///
/// Đây là tình huống thật: panel EIDE cao khoảng 700 pt, và một màn có biểu mẫu ở trên cộng một
/// cây 420 pt thì tổng đã vượt. Nếu cây co lại theo khung chứa thì nó còn vài dòng — đúng thứ
/// thấy trên ảnh chụp màn Bản đồ 15/09/2026.
final class EideKhungNhoTests: XCTestCase {

    private final class ManThu: ManHinhCoSo {
        init() { super.init(ten: "thử") }
    }

    func testCAYgiuCHIEUcaoKHImanNHOhon() {
        let m = ManThu()
        m.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        let goc = (0..<60).map { EideNutCay(ten: "g\($0)", duong: "g\($0)", laThuMuc: false) }
        let c = m.themCay(goc: goc)
        m.layoutSubtreeIfNeeded()
        XCTAssertEqual(c.frame.height, EideTuVung.caoToiDa, accuracy: 1,
                       "màn cao 200 nhưng cây vẫn phải cao \(EideTuVung.caoToiDa) và để thân "
                       + "màn cuộn; nhận \(c.frame.height)")
    }

    func testBANGgiuCHIEUcaoKHImanNHOhon() {
        let m = ManThu()
        m.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        let b = m.themBang(cot: ["x"], hang: (0..<80).map { ["\($0)"] })
        m.layoutSubtreeIfNeeded()
        XCTAssertEqual(b.frame.height, EideTuVung.caoToiDa, accuracy: 1,
                       "nhận \(b.frame.height)")
    }
}

/// Màn "Mô phỏng" — ba khối vốn dùng sai kiểu hiển thị.
final class EideSimBangTests: XCTestCase {

    private func bang(_ v: NSView) -> [EideBangView] {
        var ra: [EideBangView] = []
        if let b = v as? EideBangView { ra.append(b) }
        for c in v.subviews { ra += bang(c) }
        return ra
    }

    private func khoiMa(_ v: NSView) -> [EideMaView] {
        var ra: [EideMaView] = []
        if let m = v as? EideMaView { ra.append(m) }
        for c in v.subviews { ra += khoiMa(c) }
        return ra
    }

    // MARK: - Quét tham số

    private let quet: [[String: Any]] = [
        ["kp": 1.0, "ki": 0.1, "settle_s": 3.4],
        ["kp": 2.0, "ki": 0.1, "settle_s": 2.6],
        ["kp": 3.0, "ki": 0.2, "settle_s": 4.1],
    ]

    func testQUETthamSOdungRAmotBANG() throws {
        let v = SimView()
        v.capNhat(ketQua: ["table": quet, "best": quet[1]])
        let b = try XCTUnwrap(bang(v).first, "quét tham số phải ra một bảng")
        XCTAssertEqual(b.soHang, 3)
        // Cột sắp theo BẢNG CHỮ CÁI: ki, kp, settle_s. `[String: Any]` không giữ thứ tự khoá,
        // nên thứ tự chèn không phải một lựa chọn có thật — sắp theo tên là thứ tự DUY NHẤT
        // dựng lại được như nhau ở mọi lần chạy.
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "0.1")
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 1), "1")
        XCTAssertEqual(b.oDeTest(hang: 1, cot: 2), "2.6")
    }

    /// Cột là HỢP các khoá của mọi hàng.
    ///
    /// Lấy khoá của hàng đầu thì một tham số chỉ xuất hiện từ hàng thứ hai trở đi sẽ biến mất
    /// khỏi bảng mà không ai biết — và đó có thể là tham số làm nên khác biệt.
    func testCOTlaHOPkhoaCUAmoiHANG() throws {
        let v = SimView()
        v.capNhat(ketQua: ["table": [["a": 1], ["a": 2, "b": 9]], "best": [:]])
        let b = try XCTUnwrap(bang(v).first)
        XCTAssertEqual(b.oDeTest(hang: 1, cot: 1), "9")
        // Ô thiếu giá trị hiện `—`, không hiện rỗng: một ô rỗng lẫn với "giá trị là chuỗi rỗng",
        // còn `—` nói thẳng rằng hàng này không có tham số ấy.
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 1), "—", "hàng thiếu khoá vẫn giữ cột")
    }

    /// Hàng tốt nhất được TÔ trong bảng, không tách ra một dòng riêng.
    ///
    /// Tách ra thì người đọc phải tự tìm nó trong bảng để xem nó hơn các hàng khác ở chỗ nào —
    /// mà đó chính là câu hỏi họ mở bảng ra để hỏi.
    func testHANGtotNHATduocTOtrongBANG() throws {
        let v = SimView()
        v.capNhat(ketQua: ["table": quet, "best": quet[1]])
        let b = try XCTUnwrap(bang(v).first)
        XCTAssertEqual(b.mauODeTest(hang: 1, cot: 0), EideToken.Mau.ok)
        XCTAssertNil(b.mauODeTest(hang: 0, cot: 0))
    }

    // MARK: - So sánh SIL ↔ HIL

    func testSOsanhHILdungRAbangBAcot() throws {
        let v = SimView()
        v.capNhat(ketQua: ["diff": ["settle_s": ["sil": 2.6, "hil": 3.1, "verdict": "đạt"],
                                    "latency_ms": ["sil": 4.9, "hil": 5.3, "verdict": "vượt 0,3"]],
                           "proposals": ["cập nhật mô hình ma sát K7 → K5"]])
        let b = try XCTUnwrap(bang(v).first)
        XCTAssertEqual(b.soHang, 2)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 0), "latency_ms")
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 3), "vượt 0,3")
    }

    /// `diff` hình dạng lạ vẫn phải hiện — hợp đồng để nó là `object` tự do.
    ///
    /// Một chỉ số lệch bị nuốt vì hình dạng không khớp là đúng thứ tệ nhất: lệch SIL↔HIL là tin
    /// quan trọng nhất màn này mang.
    func testDIFFhinhDANGlaVANhienRA() throws {
        let v = SimView()
        v.capNhat(ketQua: ["diff": ["gi_do": "khác 12%"], "proposals": []])
        let b = try XCTUnwrap(bang(v).first)
        XCTAssertEqual(b.oDeTest(hang: 0, cot: 3), "khác 12%")
    }

    /// Đề xuất sửa mô hình phải nói rõ là CHỜ DUYỆT.
    func testDExuatNOIroLAchoDUYET() {
        let v = SimView()
        v.capNhat(ketQua: ["diff": ["x": ["sil": 1, "hil": 2]],
                           "proposals": ["đổi K7 thành K5"]])
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("chờ duyệt"), "nhận: \(chu)")
    }

    // MARK: - Log UART

    /// Log hiện ĐỦ, không cắt còn 5 dòng đầu.
    ///
    /// 5 dòng đầu của một log firmware là phần khởi động — đúng phần KHÔNG bao giờ chứa lý do
    /// hỏng. Thứ người ta đọc log để tìm nằm ở cuối, hoặc ở dòng ngay trước khi nó im.
    func testLOGuartHIENdUkhongCATconNAMdong() throws {
        let v = SimView()
        let dong = (0..<40).map { "00:00:0\($0 % 10).000 [INFO] dòng \($0)" }
        v.capNhat(ketQua: ["report": ["passed": true, "captured": ["uart": dong]]])
        let m = try XCTUnwrap(khoiMa(v).first, "log UART phải ra một khối mã")
        XCTAssertEqual(m.soDongMa, 40)
    }
}

/// Tên của một dòng `expect` — hình dạng THẬT của engine, không phải hình dạng ta mong.
final class EideSimTenKyVongTests: XCTestCase {

    /// Hình dạng thật của qemu: `{kind, pattern, within_s, status, matched}`.
    ///
    /// Bản cũ hỏi `expect`/`name` rồi rơi về `"?"`, nên màn hiện sáu dòng `?  đạt` — người dùng
    /// biết có sáu kỳ vọng và không biết kỳ vọng nào.
    func testDUNGtenTUkindVApattern() {
        let e: [String: Any] = ["kind": "uart", "pattern": "EIDE: atmega328p arduino-uno",
                                "within_s": 5, "status": "passed"]
        XCTAssertEqual(SimView.tenKyVong(e), "uart \"EIDE: atmega328p arduino-uno\"")
    }

    func testUUtienKHOAexpectKHIco() {
        XCTAssertEqual(SimView.tenKyVong(["expect": "settle < 3s", "kind": "sim"]), "settle < 3s")
    }

    /// Khoá lạ vẫn phải hiện nguyên — một dòng khó đọc hơn hẳn một dòng không nói gì, và nó chỉ
    /// ra đúng khoá mà hàm còn thiếu.
    func testKHOAlaHIENnguyenCHUkhongRAdauHOI() {
        let t = SimView.tenKyVong(["gpio_toggles": 12, "status": "passed", "matched": "x"])
        XCTAssertEqual(t, "gpio_toggles=12")
        XCTAssertFalse(t.contains("?"))
    }

    func testKHONGcoGIthiNOIroLAkhongTEN() {
        XCTAssertEqual(SimView.tenKyVong(["status": "passed"]), "(kỳ vọng không tên)")
    }

    /// Màn dựng đúng tên cho cả sáu dòng của luồng AVR thật.
    func testSAUdongAVRdeuCOten() {
        let ky: [[String: Any]] = (0..<6).map {
            ["kind": "uart", "pattern": "dòng \($0)", "status": "passed"]
        }
        let v = SimView()
        v.capNhat(ketQua: ["report": ["passed": true,
                                      "metrics": ["expect": ky, "n_passed": 6,
                                                  "n_unverified": 0, "engine": "qemu"]]])
        let nhan = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .compactMap { ($0.first as? NSTextField)?.stringValue }
        XCTAssertEqual(nhan.filter { $0.hasPrefix("uart ") }.count, 6)
        XCTAssertFalse(nhan.contains("?"))
    }
}

/// Màn Mã nguồn — mã có chú thích fact ở lề, thanh đầu tệp, dải cổng công cụ.
///
/// Luận điểm của cả đề án là mọi hằng số phần cứng trong mã truy được về một fact đã duyệt. Một
/// danh sách "tệp này trích 7 fact" chứng minh được con số ấy và KHÔNG chứng minh được điều quan
/// trọng hơn: dòng NÀY dựa trên fact NÀO.
final class EideCodeFactTests: XCTestCase {

    private var tep: URL!

    override func setUpWithError() throws {
        tep = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bme280-\(UUID().uuidString).c")
        try """
            #include "bme280.h"
            /* eide:fact f_b1c2 BME280 addr 0x76 (SDO→GND) */
            #define BME280_ADDR 0x76u
            int init(void) {
                i2c_write8(BME280_ADDR, 0xF5u, 0x27u);
                return 0;
            }
            """.write(to: tep, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tep) }

    private func khoiMa(_ v: NSView) -> EideMaView? {
        if let m = v as? EideMaView { return m }
        for c in v.subviews { if let m = khoiMa(c) { return m } }
        return nil
    }

    private func man(viPham: [[String: Any]] = []) -> CodeView {
        let v = CodeView()
        v.capNhat(ketQua: ["path": tep.path, "verdict": viPham.isEmpty ? "pass" : "block",
                           "violations": viPham])
        return v
    }

    func testHIENmaCUAtepVAdemDONGcoFACT() throws {
        let v = man()
        let m = try XCTUnwrap(khoiMa(v), "màn Mã nguồn phải dựng một khối mã")
        XCTAssertEqual(m.soDongMa, 7)
        XCTAssertEqual(v.soDongCoFact, 1)
    }

    func testDONGviPHAMduocDANHdauTRENkhoiMA() throws {
        let m = try XCTUnwrap(khoiMa(man(viPham: [
            ["file": tep.lastPathComponent, "line": 5, "literal": "0x27",
             "reason": "không có fact"],
        ])))
        XCTAssertEqual(m.soViPham, 1)
    }

    /// Vi phạm của TỆP KHÁC không được đánh dấu lên tệp đang mở.
    func testVIphamTEPkhacKHONGdanhDAUnhamLENtepNAY() throws {
        let m = try XCTUnwrap(khoiMa(man(viPham: [
            ["file": "khac.c", "line": 5, "literal": "0x27"],
        ])))
        XCTAssertEqual(m.soViPham, 0)
    }

    func testTHANHdauTEPnoiSOdongVAphanQUYET() {
        let chu = man().cot.arrangedSubviews
            .compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("7 dòng"), chu)
        XCTAssertTrue(chu.contains("1 dòng có fact"), chu)
        XCTAssertTrue(chu.contains("constant-guard: sạch"), chu)
    }

    /// Nhiều hằng số vi phạm trên MỘT dòng vẫn là một dòng.
    ///
    /// `i2c_write8(ADDR, 0xF5u, 0x27u, …)` cho hai vi phạm cùng dòng. Thanh đầu tệp đếm theo
    /// DÒNG vì lề cũng đánh dấu theo dòng; nói "4 vi phạm" cạnh một danh sách 5 dòng là mâu
    /// thuẫn người đọc thấy ngay, và nó làm họ nghi ngờ cả hai con số.
    func testNHIEUviPHAMcungDONGdemLAmotDONG() throws {
        let v = man(viPham: [
            ["file": tep.lastPathComponent, "line": 5, "literal": "0xF5u"],
            ["file": tep.lastPathComponent, "line": 5, "literal": "0x27u"],
        ])
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("1 dòng vi phạm"), chu)
        XCTAssertEqual(v.soViPham, 2, "vẫn đếm đủ HAI hằng số ở dòng tóm tắt")
        XCTAssertEqual(try XCTUnwrap(khoiMa(v)).soViPham, 1, "lề đánh dấu một dòng")
    }

    func testTEPkhongDOCduocTHIkhongNOnhungPHAInoiRA() {
        let v = CodeView()
        v.capNhat(ketQua: ["path": "/khong/co/tep.c", "verdict": "pass", "violations": []])
        let chu = v.cot.arrangedSubviews.compactMap { ($0 as? NSStackView)?.arrangedSubviews }
            .flatMap { $0 }.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(chu.contains("không đọc được tệp"), chu)
        XCTAssertEqual(v.soTepMa, 0)
    }

    // MARK: - Đọc chú thích fact

    func testDOCduocCHUthichFACTdangEIDE() throws {
        let f = try XCTUnwrap(CodeView.factTrongDong(
            "/* eide:fact f_b1c2 BME280 addr 0x76 */"))
        XCTAssertEqual(f.id, "f_b1c2")
        XCTAssertEqual(f.mo, "f_b1c2 — BME280 addr 0x76")
    }

    /// Tiền tố CŨ `hkw:fact` vẫn phải đọc được.
    ///
    /// Mockup UXD-13 viết bằng tiền tố cũ, và mã sinh ra trước khi đổi tên vẫn nằm trong các dự
    /// án đang có — bỏ qua nó nghĩa là chú thích biến mất khỏi lề đúng ở những tệp lâu đời nhất.
    func testDOCduocCAtienTOcuHKW() throws {
        let f = try XCTUnwrap(CodeView.factTrongDong("// hkw:fact f_old ghi chú cũ"))
        XCTAssertEqual(f.id, "f_old")
    }

    func testDONGkhongCOfactTRAnil() {
        XCTAssertNil(CodeView.factTrongDong("#define X 1"))
        XCTAssertNil(CodeView.factTrongDong("/* eide:fact */"), "không có id thì không phải fact")
    }

    /// Bấm một dòng mang fact mở hộ chiếu của ĐÚNG fact ấy.
    func testBAMdongCOfactMOdungFACT() throws {
        let v = man()
        var mo: String?
        v.onXemFact = { mo = $0 }
        let m = try XCTUnwrap(khoiMa(v))
        m.onChonDong?(2)
        XCTAssertEqual(mo, "f_b1c2")
        m.onChonDong?(1)
        XCTAssertEqual(mo, "f_b1c2", "dòng không có fact thì KHÔNG đổi gì")
    }
}
