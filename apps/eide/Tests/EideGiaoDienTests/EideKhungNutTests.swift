import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Nhóm "chỗ bấm" của UXC-31 §2** — 2A.3/2A.4/2A.5, 2C.1 kéo tab, 2C.3 không cướp màn,
/// 2D.2 tự chuyển chiều cao.
///
/// Bảy mục này nằm chung một bài vì chúng chung một kiểu hỏng: thứ HIỆN RA thì đúng, còn thứ
/// XẢY RA KHI BẤM VÀO thì chưa nối. Không bài kiểm nào bắt được loại hỏng ấy bằng cách đọc
/// chữ trên màn hình — phải bấm.
@MainActor
final class EideKhungNutTests: XCTestCase {

    private func dungKhung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }

    // MARK: - 2A.3 huy hiệu mức tự chủ

    /// Huy hiệu phải là NÚT. Một nhãn hiện "A0" đỏ chót mà bấm không ra gì bắt người dùng đi tìm
    /// màn Chính sách trong cột trái đúng lúc họ đang vội nhất.
    func testHuyHieuMucTuChuBamMoManChinhSach() {
        let (k, ph) = dungKhung()
        XCTAssertNil(k.vungLamViec.dangMo)
        XCTAssertTrue(Self.bam(k.thanhTren, chua: "Tự chủ"), "huy hiệu mức tự chủ không bấm được")
        XCTAssertEqual(k.vungLamViec.dangMo, "ChinhSach")
    }

    /// Chữ trên huy hiệu vẫn đọc được sau khi đổi từ nhãn sang nút — `mucHienTai` là thứ mọi bài
    /// đo khác dùng, và một phép đổi kiểu khung nhìn làm nó trả rỗng sẽ khiến chúng xanh giả.
    func testDoiSangNutKhongLamMatChuTrenHuyHieu() {
        let t = EideThanhTren()
        t.datMuc("A2")
        XCTAssertTrue(t.mucHienTai.contains("Tự chủ A2"), t.mucHienTai)
        t.datMuc("A0", dung: true)
        XCTAssertTrue(t.mucHienTai.contains("ĐÃ DỪNG KHẨN"), t.mucHienTai)
        XCTAssertTrue(t.mucHienTai.contains("A0"), t.mucHienTai)
    }

    // MARK: - 2A.4 / 2A.5 hai bộ đếm

    /// Hai bộ đếm CUỘN tới khối, **không mở màn**. §2A.4 nói thẳng "(không mở màn mới)": cả hai
    /// khối đã nằm trên màn hình rồi, và mở một màn để xem thứ đang hiện là dạy người đi vòng.
    func testHaiBoDemCuonToiKhoiChuKhongMoManMoi() {
        let (k, ph) = dungKhung()
        for chua in ["Chờ tôi", "Hoàn tác"] {
            XCTAssertTrue(Self.bam(k.thanhTren, chua: chua), "bộ đếm `\(chua)` không bấm được")
            XCTAssertNil(k.vungLamViec.dangMo, "bộ đếm `\(chua)` mở màn mới — trái §2A.4")
        }
    }

    /// Cột phải cuộn tới ĐÚNG khối khi nó dài hơn khung. Ba khối đầy thì "Hoàn tác được" nằm
    /// dưới đáy, và đó chính là lúc bộ đếm có việc để làm.
    func testCotPhaiCuonXuongKhiKhoiNamNgoaiTamNhin() {
        let c = EideCotPhai(frame: NSRect(x: 0, y: 0, width: 236, height: 180))
        c.datDangChay((1...6).map { (ma: "r\($0)", dong: "Lượt chạy \($0)") })
        c.datCho((1...6).map { EideCotPhai.MucCho(ma: "g\($0)", tieuDe: "Mục \($0)", ly: "chờ duyệt") })
        c.datHoanTac((1...6).map { (ma: "u\($0)", nhan: "Ghi tệp \($0)", han: "còn 10 phút") })
        c.layoutSubtreeIfNeeded()

        c.cuonToi(.dangChay)
        XCTAssertEqual(c.viTriCuon, 0, accuracy: 12, "cuộn tới khối đầu mà không về đỉnh")
        c.cuonToi(.hoanTac)
        XCTAssertGreaterThan(c.viTriCuon, 0, "khối cuối nằm ngoài tầm nhìn mà cột không cuộn")
    }

    /// **Cửa sổ cao thì phép cuộn là lệnh không-làm-gì, và nút vẫn phải trả lời.** Đây là chỗ dễ
    /// nghiệm thu nhầm nhất: trên màn hình lớn cả ba khối đã hiện, bấm xong không thấy gì đổi, và
    /// người dùng kết luận nút hỏng. Nháy tiêu đề là câu trả lời "đây, chỗ này".
    func testCuonToiKhongNemDuLieuKhiCotVuaManHinh() {
        let c = EideCotPhai(frame: NSRect(x: 0, y: 0, width: 236, height: 900))
        c.datCho([EideCotPhai.MucCho(ma: "g1", tieuDe: "Một mục", ly: "chờ duyệt")])
        c.layoutSubtreeIfNeeded()
        c.cuonToi(.cho)
        XCTAssertEqual(c.viTriCuon, 0, accuracy: 1, "cột vừa màn hình mà vẫn bị đẩy đi")
    }

    // MARK: - 2C.1 kéo đổi thứ tự tab

    func testKeoDoiThuTuTab() {
        let t = EideThanhTab()
        for m in ["Main", "NhatKy", "Passport"] { t.mo(m) }
        XCTAssertTrue(t.doiCho(2, 0))
        XCTAssertEqual(t.tab, ["Passport", "Main", "NhatKy"])
        XCTAssertEqual(t.dangMo, "Passport", "đổi chỗ làm mất tab đang mở")
    }

    /// Chỉ số ngoài khoảng thì KHÔNG làm gì — thả một tab ra ngoài thanh là chuyện bình thường,
    /// và nó không được làm rơi mất một tab.
    func testDoiChoNgoaiKhoangThiKhongLamGi() {
        let t = EideThanhTab()
        for m in ["Main", "NhatKy"] { t.mo(m) }
        XCTAssertFalse(t.doiCho(0, 9))
        XCTAssertFalse(t.doiCho(-1, 0))
        XCTAssertFalse(t.doiCho(1, 1))
        XCTAssertEqual(t.tab, ["Main", "NhatKy"])
    }

    /// Thả vào nửa TRÁI của một tab = đứng trước nó. Quy ước này giống mọi thanh tab người dùng
    /// đã quen; làm ngược lại thì mỗi lần kéo đều lệch một ô.
    func testViTriThaSoVoiMidXChuKhongMepTab() {
        let t = EideThanhTab()
        for m in ["Main", "NhatKy", "Passport"] { t.mo(m) }
        t.frame = NSRect(x: 0, y: 0, width: 600, height: 33)
        t.layoutSubtreeIfNeeded()
        XCTAssertEqual(t.viTriTha(-500), 0, "kéo hẳn ra trái mà không về đầu")
        XCTAssertEqual(t.viTriTha(5000), 2, "kéo hẳn ra phải mà không về cuối")
    }

    /// Nhả tay TRONG ngưỡng vẫn là một cú bấm. Vòng lặp sự kiện tự viết ở `EideNutTab` thay vòng
    /// của AppKit, nên nếu quên nhánh này thì mọi tab thành tab bấm không chuyển được.
    func testNutTabVanLaNutBamDuocKhiKhongKeo() {
        let t = EideThanhTab()
        var daChon: String?
        t.onChon = { daChon = $0 }
        t.mo("Main")
        t.layoutSubtreeIfNeeded()
        XCTAssertTrue(Self.bam(t, chua: EideManHinhDS.nhan("Main")), "không tìm thấy nút tab")
        XCTAssertEqual(daChon, "Main")
    }

    // MARK: - 2C.3 không cướp màn

    /// **Người vừa tự chọn màn dưới 20 giây thì tác tử mở ở NỀN.** Kéo màn hình đi lúc người
    /// đang đọc làm mất chỗ đang đọc, và không có nút quay lại chỗ ấy.
    func testTacTuKhongCuopManTrongHaiMuoiGiay() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 2_000_000)
        ph.dongHo = { gio }
        ph.moMan("Passport", boiTacTu: false)

        gio += 5
        XCTAssertFalse(ph.moMan("NhatKy", boiTacTu: true), "tác tử cướp màn trong 20 giây")
        XCTAssertEqual(k.vungLamViec.dangMo, "Passport", "vùng làm việc bị kéo đi")
        XCTAssertTrue(k.thanhTab.tab.contains("NhatKy"), "mở ở nền mà KHÔNG thêm tab — việc của "
                      + "tác tử bị giấu hẳn, còn tệ hơn cướp màn")
        XCTAssertEqual(k.thanhTab.dangMo, "Passport", "tab nền lại chiếm luôn tiêu điểm")
    }

    /// Quá 20 giây thì được chiếm — nửa sau của cùng một luật, và bỏ nó đi thì tác tử vĩnh viễn
    /// không mở được màn nào sau lần đầu người bấm.
    func testQuaHaiMuoiGiayThiTacTuDuocChiemMan() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 2_000_000)
        ph.dongHo = { gio }
        ph.moMan("Passport", boiTacTu: false)

        gio += EidePhien.GIU_MAN + 1
        XCTAssertTrue(ph.moMan("NhatKy", boiTacTu: true))
        XCTAssertEqual(k.vungLamViec.dangMo, "NhatKy")
    }

    /// Chưa lần nào người tự chọn màn thì không có việc nào đang bị cắt ngang — tác tử mở thẳng.
    func testChuaAiChonManThiTacTuMoThang() {
        let (k, ph) = dungKhung()
        XCTAssertTrue(ph.moMan("NhatKy", boiTacTu: true))
        XCTAssertEqual(k.vungLamViec.dangMo, "NhatKy")
    }

    /// Mở ở nền thì màn ấy **chưa được xem** — badge phải lên. Không thế thì tab mới nằm im giữa
    /// hàng tab, không dấu hiệu nào, và người dùng không bao giờ bấm vào nó.
    func testManMoONenVanTinhLaCHUAXem() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 2_000_000)
        ph.dongHo = { gio }
        ph.moMan("Passport", boiTacTu: false)
        gio += 2
        _ = ph.moMan("NhatKy", boiTacTu: true)
        XCTAssertTrue(Self.chu(k.cotTrai).contains("1"),
                      "mở ở nền mà cột trái không lên badge — \(Self.chu(k.cotTrai))")
    }

    // MARK: - 2D.2 tự chuyển chiều cao vùng trao đổi

    /// (b) Gõ LIÊN TỤC 5 giây → thu gọn. Gõ vài phím rồi thôi thì không.
    func testGoLienTucNamGiayThiThuGonVungTraoDoi() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 3_000_000)
        ph.dongHo = { gio }

        // Gõ ĐỀU mỗi giây. Nhảy thẳng 5 giây rồi gõ một phím là một mạch gõ MỚI sau một quãng
        // nghỉ, không phải "liên tục 5 giây" — và bài kiểm viết thế sẽ đòi mã làm sai §2D.2(b).
        for _ in 0..<2 {
            ph.nguoiGo()
            gio += 1
        }
        XCTAssertEqual(k.dock.cao, .chuan, "mới gõ 2 giây đã thu gọn")

        for _ in 0..<5 {
            ph.nguoiGo()
            gio += 1
        }
        XCTAssertEqual(k.dock.cao, .thuGon)
    }

    /// Ngắt tay quá `NGAT_GO` thì mạch gõ tính lại từ đầu. Không có luật này, mở màn buổi sáng
    /// gõ một phím rồi đi ăn trưa, về gõ phím thứ hai là vùng trao đổi tụt xuống.
    func testNgatTayLauThiMachGoTinhLaiTuDau() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 3_000_000)
        ph.dongHo = { gio }

        ph.nguoiGo()
        gio += 3600
        ph.nguoiGo()
        gio += 1
        ph.nguoiGo()
        XCTAssertEqual(k.dock.cao, .chuan, "một quãng nghỉ dài vẫn bị tính là gõ liên tục")
    }

    /// (c) Con trỏ đang ở ô lệnh thì KHÔNG đổi chiều cao — kể cả khi luật (a) hay (b) đòi đổi.
    /// Người bấm tay thì vẫn đổi, vì đó là lệnh trực tiếp của họ.
    func testNguoiBamTayThiVanDoiDuChoTroDangODoLenh() {
        let d = EideDock()
        d.datCao(.thuGon, buoc: true)
        XCTAssertEqual(d.cao, .thuGon)
        d.datCao(.moRong, buoc: true)
        XCTAssertEqual(d.cao, .moRong)
    }

    /// (a) Run mới → về chuẩn. Đã có từ trước; bài này khoá nó lại để đừng ai gỡ mất.
    func testRunMoiKeoVungTraoDoiVeChuan() {
        let (k, ph) = dungKhung()
        k.dock.datCao(.thuGon, buoc: true)
        ph.napSuKien("event.run.progress",
                     ["kind": "run.started", "run_id": "r1", "text": "Dựng firmware"])
        XCTAssertEqual(k.dock.cao, .chuan, "thẻ Run mới nằm trong vùng cao 48 pt thì không ai thấy")
    }

    // MARK: - phụ

    /// Bấm nút ĐẦU TIÊN có tiêu đề chứa `chua`, đệ quy qua cây khung nhìn. Trả `false` nếu không
    /// có nút nào — một bài kiểm "bấm" mà lặng lẽ không bấm gì thì nó xanh vì không làm gì.
    private static func bam(_ v: NSView, chua: String) -> Bool {
        if let b = v as? NSButton {
            let van = b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string
            if van.contains(chua), let a = b.action {
                b.sendAction(a, to: b.target)
                return true
            }
        }
        for c in v.subviews where bam(c, chua: chua) { return true }
        return false
    }

    private static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField { ra += t.stringValue }
        if let b = v as? NSButton {
            ra += " " + (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string)
        }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}
