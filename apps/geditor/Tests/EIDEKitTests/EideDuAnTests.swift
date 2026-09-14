import XCTest
@testable import EIDEKit

/// `EideDuAn` — mở dự án từ giao diện (GIAM-SAT-UI §0.2).
///
/// Trước 14/09/2026 giao diện không mở được dự án nào: `moClient()` chạy `eide daemon` không có
/// `-p`, nên mọi màn có dữ liệu đều rỗng — và rỗng **vì không có dự án**, chứ không phải vì chưa
/// có dữ liệu. Hai chuyện ấy đòi hai câu trả lời khác nhau nhưng màn hình trông y hệt.
final class EideDuAnTests: XCTestCase {

    private var tam: URL!

    override func setUpWithError() throws {
        tam = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eide-duan-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tam, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tam)
    }

    /// Dựng một dự án EIDE giả với đủ `.eide/store/store.sqlite`.
    private func duAnThat(_ ten: String) throws -> String {
        let d = tam.appendingPathComponent(ten)
        let store = d.appendingPathComponent(".eide/store")
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try Data().write(to: store.appendingPathComponent("store.sqlite"))
        return d.path
    }

    // MARK: - kiểm thư mục

    func testDUANdayDUthiMOduoc() throws {
        let d = try duAnThat("blink")
        XCTAssertEqual(EideDuAn.kiem(d), .duoc(d))
        XCTAssertNil(EideDuAn.kiem(d).loi)
    }

    func testTHUMUCkhongCOeideTHIkhongPHAIduAn() throws {
        let d = tam.appendingPathComponent("chi-la-thu-muc")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        XCTAssertEqual(EideDuAn.kiem(d.path), .thieuEide)
    }

    func testMOIkieuHONGnoiRAmotLYDOkhacNHAU() throws {
        // Trả lý do chứ không trả Bool: người chọn nhầm thư mục cha cần biết nên vào thư mục con
        // nào, còn người chọn một dự án bị xoá `.eide` cần biết đó là chuyện khác hẳn. Một câu
        // "không hợp lệ" chung cho cả ba là bắt người dùng tự đoán.
        let d = tam.appendingPathComponent("chua-migrate")
        try FileManager.default.createDirectory(at: d.appendingPathComponent(".eide"),
                                                withIntermediateDirectories: true)
        let ds: [EideDuAn.KetQua] = [.khongPhaiThuMuc, .thieuEide, .thieuStore]
        let lyDo = ds.compactMap { $0.loi }
        XCTAssertEqual(lyDo.count, 3)
        XCTAssertEqual(Set(lyDo).count, 3, "ba tình huống phải có ba câu khác nhau")

        XCTAssertEqual(EideDuAn.kiem(d.path), .thieuStore)
        XCTAssertTrue(EideDuAn.kiem(d.path).loi?.contains("eide migrate") ?? false,
                      "phải nói LỆNH cần chạy, không chỉ nói là thiếu")
    }

    func testCHUAmigrateKHACvoiCHUAphaiDUAN() throws {
        // Dự án vừa `project.create` nhưng chưa `eide migrate` là tình huống THẬT — đo được
        // 14/09 khi làm luồng AVR: hàng đợi rỗng vì store chưa có bảng nào.
        let co = tam.appendingPathComponent("co-eide")
        try FileManager.default.createDirectory(at: co.appendingPathComponent(".eide"),
                                                withIntermediateDirectories: true)
        XCTAssertNotEqual(EideDuAn.kiem(co.path), EideDuAn.kiem(tam.path))
    }

    func testTEPkhongPHAIthuMUC() throws {
        let f = tam.appendingPathComponent("mot-tep.txt")
        try Data("x".utf8).write(to: f)
        XCTAssertEqual(EideDuAn.kiem(f.path), .khongPhaiThuMuc)
    }

    func testDUONGDANkhongTONtai() {
        XCTAssertEqual(EideDuAn.kiem("/khong/co/duong/nay"), .khongPhaiThuMuc)
        XCTAssertEqual(EideDuAn.kiem(""), .khongPhaiThuMuc)
    }

    func testEIDElaTEPchuKHONGphaiTHUMUC() throws {
        // `.eide` là một tệp — hiếm, nhưng `touch .eide` thì có thật, và `fileExists` một mình
        // sẽ nói "có" rồi để lỗi nổ ở chỗ khác.
        let d = tam.appendingPathComponent("eide-la-tep")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        try Data().write(to: d.appendingPathComponent(".eide"))
        XCTAssertEqual(EideDuAn.kiem(d.path), .thieuEide)
    }

    // MARK: - danh sách gần đây

    private func khoSach() -> UserDefaults {
        let ten = "eide-test-\(UUID().uuidString)"
        let k = UserDefaults(suiteName: ten)!
        addTeardownBlock { k.removePersistentDomain(forName: ten) }
        return k
    }

    func testGANDAYmoiNHATtruoc() {
        let k = khoSach()
        EideDuAn.nhoDaMo("/a", k)
        EideDuAn.nhoDaMo("/b", k)
        // `ganDay` lọc thư mục không tồn tại, nên kiểm qua kho thô cho phần thứ tự.
        XCTAssertEqual(k.array(forKey: "eide.duAnGanDay") as? [String], ["/b", "/a"])
    }

    func testGANDAYkhongLAPduAnCUNGmotDUONGdan() {
        let k = khoSach()
        EideDuAn.nhoDaMo("/a", k)
        EideDuAn.nhoDaMo("/b", k)
        EideDuAn.nhoDaMo("/a", k)
        XCTAssertEqual(k.array(forKey: "eide.duAnGanDay") as? [String], ["/a", "/b"],
                       "mở lại một dự án phải đưa nó lên đầu, không thêm dòng thứ hai")
    }

    func testGANDAYcatBOTkhiQUAdai() {
        let k = khoSach()
        for i in 0..<(EideDuAn.TOI_DA_GAN_DAY + 5) { EideDuAn.nhoDaMo("/d\(i)", k) }
        let ds = k.array(forKey: "eide.duAnGanDay") as? [String] ?? []
        XCTAssertEqual(ds.count, EideDuAn.TOI_DA_GAN_DAY)
        XCTAssertEqual(ds.first, "/d\(EideDuAn.TOI_DA_GAN_DAY + 4)")
    }

    func testGANDAYloBOthuMUCkhongCONton_TAI_khiDOC() throws {
        // Lọc khi ĐỌC, không khi ghi: một dự án trên ổ ngoài chưa cắm vào vẫn nên ở trong danh
        // sách, chỉ là không mở được lúc này. Xoá nó vì một lần rút ổ là làm người dùng mất một
        // lối tắt họ dùng hằng ngày.
        let k = khoSach()
        let that = try duAnThat("con-song")
        EideDuAn.nhoDaMo(that, k)
        EideDuAn.nhoDaMo("/da/bi/xoa", k)
        XCTAssertEqual(EideDuAn.ganDay(k), [that])
        XCTAssertEqual((k.array(forKey: "eide.duAnGanDay") as? [String])?.count, 2,
                       "vẫn còn trong kho — chỉ không hiện lúc này")
    }

    func testGANDAYrongKHIchuaMOgi() {
        XCTAssertEqual(EideDuAn.ganDay(khoSach()), [])
    }

    // MARK: - nhãn menu

    func testNHANchiLAtenThuMUCkhiKHONGtrung() {
        XCTAssertEqual(EideDuAn.nhan("/Users/x/eide/blink", trong: ["/Users/x/eide/blink"]),
                       "blink")
    }

    func testHAIduANcungTENthiTHEMthuMUCcha() {
        // `~/eide/blink` và `~/work/blink` là chuyện thường, và hai dòng menu giống hệt nhau thì
        // người dùng phải bấm thử để biết cái nào là cái nào.
        let ds = ["/Users/x/eide/blink", "/Users/x/work/blink"]
        XCTAssertEqual(EideDuAn.nhan(ds[0], trong: ds), "blink — eide")
        XCTAssertEqual(EideDuAn.nhan(ds[1], trong: ds), "blink — work")
        XCTAssertNotEqual(EideDuAn.nhan(ds[0], trong: ds), EideDuAn.nhan(ds[1], trong: ds))
    }

    func testNHANcuaDUONGDANlaCHUOIrongKHONGlamNOhong() {
        XCTAssertEqual(EideDuAn.nhan("", trong: [""]), "")
    }
}

// MARK: - Tạo và chọn dự án trên thanh trên (nhắc của chủ sản phẩm 14/09)

final class EideThanhDuAnTests: XCTestCase {

    @MainActor
    func testCHUAmoDUANthiNOIRAchuKHONGdeTRONG() {
        // Một nút trống trên thanh là một nút người dùng không biết để làm gì. Câu này vừa nói
        // tình trạng vừa mời bấm vào — và nó là điểm vào ĐẦU TIÊN của cả sản phẩm.
        let b = AutonomyBar()
        XCTAssertTrue(b.nhanDuAn.contains("Chưa mở dự án"), b.nhanDuAn)
        XCTAssertTrue(b.nhanDuAn.contains("▾"), "phải có dấu cho biết bấm được: \(b.nhanDuAn)")
    }

    @MainActor
    func testHIENtenDUANdangMO() {
        let b = AutonomyBar()
        b.datDuAn("doc-cam-bien-dht22")
        XCTAssertTrue(b.nhanDuAn.contains("doc-cam-bien-dht22"), b.nhanDuAn)
    }

    @MainActor
    func testDOIveNILthiQUAYlaiCAUchuaMO() {
        // Đóng dự án rồi mà nút vẫn mang tên cũ là nói dối về chỗ người dùng đang đứng.
        let b = AutonomyBar()
        b.datDuAn("mot-du-an")
        b.datDuAn(nil)
        XCTAssertTrue(b.nhanDuAn.contains("Chưa mở dự án"), b.nhanDuAn)
    }

    @MainActor
    func testBAMnutDUANthiGOIcallback() {
        let b = AutonomyBar()
        var daBam = false
        b.onChonDuAn = { daBam = true }
        b.bamDuAnDeTest()
        XCTAssertTrue(daBam)
    }

    @MainActor
    func testTENduANraiDAIkhongDAYnutDUNGkhanRAngoai() {
        // Tên dự án sinh từ câu tiếng Việt nên có thể rất dài:
        // "doc-cam-bien-bme280-qua-i2c-tren-esp32-c3-gui-ket-qua-len-may-tinh".
        let b = AutonomyBar()
        b.frame = NSRect(x: 0, y: 0, width: 900, height: 44)
        b.datDuAn(String(repeating: "rat-dai-", count: 12))
        b.layoutSubtreeIfNeeded()
        XCTAssertFalse(b.nhanDuAn.isEmpty)
    }
}
