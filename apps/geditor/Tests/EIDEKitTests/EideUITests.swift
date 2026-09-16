import AppKit
import XCTest

@testable import EIDEKit

/// WI-021 — ràng buộc giao diện của UXD-13 mà máy kiểm được.
///
/// U10 viết "tương phản ≥ 4,5:1 (WCAG 2.2 AA)". Một câu như thế trong tài liệu chỉ có giá trị
/// nếu có ai đó đo; nếu không, nó đúng vào ngày viết rồi sai dần theo từng lần đổi màu. Đây là
/// chỗ đo.
final class EideUITests: XCTestCase {

    // MARK: - U7: token đúng bộ nhận diện

    func testMauLayTuTokenChuKhongVietTay() {
        // UXD-13 §7. Nếu ai đổi tokens.json mà quên sinh lại Swift thì `make check-gen` đỏ;
        // test này chốt thêm giá trị để một lần sinh sai không lọt qua im lặng.
        //
        // Cập nhật 16/09/2026 (WI-258 xong): ba màu nay lấy từ tệp nhận diện chính thức
        // `docs/logo-ptit-1.svg` thay vì ước lượng. `primary` là đỏ mà logo dùng cho CHỮ
        // (`#BC2626`, tương phản 5,63) chứ không phải đỏ biểu tượng (`#DE221A`, 4,46 — dưới
        // ngưỡng AA mà chính `tokens.json` khai). Xem `EideLogoTests`.
        XCTAssertEqual(EideToken.Mau.primary.hexString, "#BC2626")   // đỏ PTIT — cho chữ
        XCTAssertEqual(EideToken.Mau.brand.hexString, "#DE221A")     // đỏ biểu tượng — mảng lớn
        XCTAssertEqual(EideToken.Mau.accent.hexString, "#F2B705")    // vàng — việc cần người
        XCTAssertEqual(EideToken.Mau.secondary.hexString, "#373D4E") // xám xanh — tác tử
    }

    // MARK: - U10: tương phản WCAG 2.2 AA

    func testChuTrenNenDatTuongPhanAA() {
        let nen = EideToken.Mau.surface
        for (ten, mau) in [("text", EideToken.Mau.text), ("muted", EideToken.Mau.muted),
                           ("ok", EideToken.Mau.ok), ("warn", EideToken.Mau.warn),
                           ("bad", EideToken.Mau.bad)] {
            let ts = mau.tuongPhan(nen)
            XCTAssertGreaterThanOrEqual(
                ts, EideToken.tuongPhanToiThieu,
                "\(ten) trên surface chỉ đạt \(String(format: "%.2f", ts)):1, cần ≥ 4,5:1 (U10)")
        }
    }

    func testChuTrangTrenThanhTuChuDatTuongPhan() {
        // Thanh tự chủ dùng chữ trắng trên `secondary`, và khi dừng khẩn thì trên `primary`.
        // Cả hai trạng thái đều phải đọc được, không chỉ trạng thái bình thường.
        for (ten, nen) in [("secondary", EideToken.Mau.secondary), ("primary", EideToken.Mau.primary)] {
            let ts = NSColor.white.tuongPhan(nen)
            XCTAssertGreaterThanOrEqual(
                ts, EideToken.tuongPhanToiThieu,
                "chữ trắng trên \(ten) chỉ đạt \(String(format: "%.2f", ts)):1 (U10)")
        }
    }

    // MARK: - U2, U6, U9: hành vi nhìn thấy được

    @MainActor
    func testThanhTuChuNoiTrangThaiBangCHUKhongChiBangMau() {
        // U10: "không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)". Người mù màu phải đọc được
        // rằng phiên đang dừng, chứ không chỉ thấy thanh đổi sang đỏ.
        let bar = AutonomyBar()
        bar.capNhat(muc: "A3", dungKhan: true, soCho: 2, soHoanTac: 1)
        let chu = bar.subviews.compactMap { ($0 as? NSTextField)?.stringValue }.joined()
        XCTAssertTrue(chu.contains("DỪNG"), "trạng thái dừng phải nói bằng chữ: \(chu)")
        XCTAssertTrue(chu.contains("2 chờ anh"))
        XCTAssertTrue(chu.contains("1 hoàn tác"))
    }

    @MainActor
    func testNutDungKhanCoPhimTat() {
        // U6: "nút ■ Dừng khẩn ở sidebar và phím tắt ⌘⇧." — với tới được mà không cần chuột.
        let bar = AutonomyBar()
        // Tìm theo TIÊU ĐỀ, không theo vị trí trong `subviews`. Bản cũ lấy nút đầu tiên và đỏ
        // ngay khi thanh có thêm nút chọn dự án (15/09) — một test đỏ vì lý do không liên quan
        // gì tới điều nó canh, và mất một lượt truy ngược để biết đó không phải lỗi thật.
        let nut = bar.subviews.compactMap { $0 as? NSButton }
            .first { $0.title.contains("Dừng khẩn") }
        XCTAssertNotNil(nut, "không tìm thấy nút Dừng khẩn trên thanh tự chủ")
        XCTAssertEqual(nut?.keyEquivalent, ".")
        XCTAssertEqual(nut?.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertNotNil(nut?.accessibilityLabel())
    }

    @MainActor
    func testHangDoiRongVanNOIRARongChuKhongDeTrong() {
        // U9: "mọi panel có ba trạng thái thiết kế sẵn"; một khoảng trắng khiến người dùng
        // tưởng đang tải, và chờ một thứ không bao giờ tới.
        let q = ReviewQueueView()
        q.capNhat(cho: [], hoanTac: [])
        let chu = q.moiChu()
        XCTAssertTrue(chu.contains("Không có việc nào chờ anh"))
        XCTAssertTrue(chu.contains("Chưa có việc nào tự làm"))
    }

    @MainActor
    func testHangDoiTachHaiDanhSach() {
        // U2: "hàng đợi TÁCH 'chờ tôi' và 'đã làm — hoàn tác được'". Hai câu hỏi khác nhau.
        let q = ReviewQueueView()
        q.capNhat(cho: [["cap": "target.flash"]],
                  hoanTac: [["cap": "project.create", "deadline": "2026-09-07T03:10:00+00:00"]])
        let chu = q.moiChu()
        XCTAssertTrue(chu.contains("Chờ anh (1)"))
        XCTAssertTrue(chu.contains("target.flash"))
        XCTAssertTrue(chu.contains("Đã làm — hoàn tác được (1)"))
        XCTAssertTrue(chu.contains("project.create"))
    }

    @MainActor
    func testHoiThoaiMoRaDaCoLoiChao() {
        // U1: ChatPanel là màn hình MẶC ĐỊNH — nó phải nói được ngay khi mở, không phải một
        // ô trống chờ người đoán mình làm gì tiếp.
        let c = ChatView()
        XCTAssertTrue(c.moiChu().contains("Sẵn sàng"))
    }
}

// MARK: - tiện ích cho test

extension NSColor {
    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "?" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

extension NSView {
    /// Gom mọi chuỗi hiện trên view — cách kiểm "người dùng ĐỌC được gì", không phải "cây view
    /// có hình dạng nào".
    func moiChu() -> String {
        var ra = (self as? NSTextField)?.stringValue ?? ""
        if let tv = self as? NSTextView { ra += tv.string }
        for v in subviews { ra += " " + v.moiChu() }
        return ra
    }
}

/// Bộ khởi chạy daemon — DEP-26 §2 (EIDE là gói riêng, GEditor phải TÌM nó).
final class EideLauncherTests: XCTestCase {

    func testTimDuocEideTrongKhoPhatTrien() throws {
        // Kho này có .venv-arm hoặc .venv-x86 sau `make setup`; nếu chưa có thì bỏ qua chứ
        // không đỏ — máy chưa dựng môi trường không phải một lỗi của mã.
        guard let eide = EideDaemonLauncher.timEide() else {
            throw XCTSkip("chưa có venv — chạy `make setup` ở gốc kho EIDE")
        }
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: eide[0]), "\(eide)")
    }

    func testTimThayGocKhoQuaCLAUDEmd() throws {
        // `repo_root()` phía Python tìm ngược từ CLAUDE.md; phía Swift phải tìm ra CÙNG chỗ,
        // nếu không daemon sẽ chạy ở thư mục không có docs/spec và registry rỗng.
        guard let goc = EideDaemonLauncher.gocKho() else {
            throw XCTSkip("không chạy từ bản dựng phát triển")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: goc + "/docs/spec/cds.json"))
    }

    func testBienMoiTruongEIDE_PYTHONThangMoiThu() throws {
        // Người dùng chỉ đích danh thì phải thắng mọi phép đoán — nếu không, một venv cũ nằm
        // cạnh kho sẽ lặng lẽ ghi đè lựa chọn của họ.
        let gia = "/bin/echo"   // tồn tại và chạy được trên mọi máy macOS
        setenv("EIDE_PYTHON", gia, 1)
        defer { unsetenv("EIDE_PYTHON") }
        XCTAssertEqual(EideDaemonLauncher.timEide()?.first, gia)
    }

    func testMoClientThatVaGoiDuocDaemon() async throws {
        guard let c = EideDaemonLauncher.moClient() else {
            throw XCTSkip("chưa có venv")
        }
        let r = try await c.goi(.planeHello, ["client": "GEditor"])
        await c.dong()
        XCTAssertNotNil(r["api_version"])
        XCTAssertNotNil(r["caps"], "daemon phải báo số năng lực — nếu nil thì registry rỗng")
    }
}

// MARK: - Ô lệnh với gợi ý "/" (UXD-13 U1, §4 CommandBox)

final class CommandBoxTests: XCTestCase {

    private func hop() -> CommandBox {
        let b = CommandBox()
        b.napNangLuc([
            .init(id: "kg.build", mota: "Dựng đồ thị tri thức từ store", manHinh: "Graph"),
            .init(id: "kg.conflicts", mota: "Fact mâu thuẫn", manHinh: "ReviewQueue"),
            .init(id: "project.create", mota: "Tạo dự án từ câu lệnh", manHinh: "Chat"),
            .init(id: "khong.man.hinh", mota: "Không thuộc màn hình nào", manHinh: ""),
        ])
        return b
    }

    func testNangLucKhongCoManHinhKhongVaoMenu() {
        // U1: "liệt kê năng lực CÓ `ui`". Một mục menu mở ra thứ không hiện ở đâu là một lời
        // hứa suông, và người dùng chỉ phát hiện sau khi đã bấm.
        XCTAssertEqual(hop().soNangLuc, 3)
    }

    func testChiMoMenuKhiGachCheoODAUDONG() {
        // Một đường dẫn `src/main.c` giữa câu KHÔNG được mở menu — người ta gõ dấu gạch chéo
        // giữa câu thường xuyên hơn là gõ nó để tìm năng lực.
        let b = hop()
        XCTAssertEqual(b.tienTo("/kg"), "kg")
        XCTAssertEqual(b.tienTo("nháy LED\n/pro"), "pro")
        XCTAssertNil(b.tienTo("sửa src/main.c giúp anh"))
        XCTAssertNil(b.tienTo("nháy LED"))
    }

    func testLocUuTienKhopIdTruocKhopMoTa() {
        // Người gõ "/kg" muốn thấy nhóm kg trước một năng lực khác tình cờ có "kg" trong mô tả.
        let ra = hop().loc("tri thức")
        XCTAssertEqual(ra.first?.id, "kg.build", "khớp mô tả vẫn phải ra kết quả")
        let idTruoc = hop().loc("kg")
        XCTAssertEqual(idTruoc.map(\.id), ["kg.build", "kg.conflicts"])
    }

    func testGachCheoTrongLietKeTatCa() {
        XCTAssertEqual(hop().loc("").count, 3)
    }
}

// MARK: - Thẻ câu hỏi gộp (UXD-13 U3, §4 QuestionCard)

final class QuestionCardTests: XCTestCase {

    private func the(timeout: Int = 120) -> QuestionCard {
        QuestionCard(cauHoi: "Anh dùng probe nào?",
                     phuongAn: [.init(nhan: "ST-Link", giaTri: "stlink"),
                                .init(nhan: "J-Link", giaTri: "jlink")],
                     macDinh: 1, timeoutS: timeout, ghiNho: "probe")
    }

    func testDemNguocDinhDangMMSS() {
        // §4: "đếm ngược mm:ss".
        XCTAssertEqual(QuestionCard.mmss(120), "02:00")
        XCTAssertEqual(QuestionCard.mmss(9), "00:09")
        XCTAssertEqual(QuestionCard.mmss(0), "00:00")
        XCTAssertEqual(QuestionCard.mmss(-3), "00:00", "đồng hồ âm phải kẹp về 0")
    }

    func testHetGioChonMacDinhVaBaoRoLaHetGio() {
        // DPS-09 D3: "im lặng quá T ⇒ chọn mặc định và BÁO". Cờ thứ hai đi vào chat.answer để
        // nhật ký phân biệt "người chọn" với "hết giờ lấy mặc định" — hai chuyện rất khác nhau
        // khi sau này có ai hỏi vì sao lại làm thế.
        let t = the()
        var ra: (String, Bool)?
        t.onTraLoi = { ra = ($0, $1) }
        t.chayHetGioNgay()
        XCTAssertEqual(ra?.0, "jlink")
        XCTAssertEqual(ra?.1, true)
    }

    func testChiTraLoiMOTLan() {
        // Người bấm đúng lúc đồng hồ về 0 sẽ gửi hai câu trả lời cho cùng một question_id, và
        // bên kia không có cách nào biết cái nào là thật.
        let t = the()
        var lan = 0
        t.onTraLoi = { _, _ in lan += 1 }
        t.chayHetGioNgay()
        t.chayHetGioNgay()
        XCTAssertEqual(lan, 1)
    }

    func testKhongQuaChinPhuongAn() {
        // §4: "gõ số 1–9 để chọn". Nút thứ 10 là một nút không phím nào tới được.
        let pa = (1...12).map { QuestionCard.PhuongAn(nhan: "P\($0)", giaTri: "v\($0)") }
        let t = QuestionCard(cauHoi: "?", phuongAn: pa, macDinh: 0, timeoutS: 999)
        var ra: String?
        t.onTraLoi = { v, _ in ra = v }
        t.chayHetGioNgay()
        XCTAssertEqual(ra, "v1")
    }
}

// MARK: - Nối thẻ vào hội thoại

final class ChatCardTests: XCTestCase {

    func testTheTuGoSauKhiTraLoiNhungCauTraLoiOLAI() {
        // Để lại một thẻ đã trả lời chỉ làm người dùng tưởng còn phải bấm. Nhưng câu trả lời
        // phải còn dấu vết trong bản ghi hội thoại — nếu không, người quay lại sau nửa tiếng
        // không biết mình đã chọn gì.
        let chat = ChatView()
        let the = QuestionCard(cauHoi: "Probe nào?",
                               phuongAn: [.init(nhan: "ST-Link", giaTri: "stlink"),
                                          .init(nhan: "J-Link", giaTri: "jlink")],
                               macDinh: 0, timeoutS: 999)
        chat.themThe(the)
        XCTAssertEqual(chat.soThe, 1)
        the.chayHetGioNgay()
        XCTAssertEqual(chat.soThe, 0, "thẻ đã trả lời phải tự gỡ")
    }

    func testOLenhLaCommandBoxChuKhongPhaiOMotDong() {
        // §4 CommandBox: "Nhập nhiều dòng". Một NSTextField không xuống dòng được, nên một câu
        // lệnh dài sẽ trôi ngang khỏi tầm nhìn.
        let chat = ChatView()
        chat.oLenh.napNangLuc([.init(id: "kg.build", mota: "x", manHinh: "Graph")])
        XCTAssertEqual(chat.oLenh.soNangLuc, 1)
    }
}
