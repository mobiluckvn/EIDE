import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **§3 Luồng làm quen · §4 Bảng lệnh.**
@MainActor
final class EideLamQuenBangLenhTests: XCTestCase {

    private func dungKhung() -> (EideKhung, EidePhien) {
        let k = EideKhung(frame: NSRect(x: 0, y: 0, width: 1456, height: 838))
        return (k, EidePhien(khung: k))
    }

    // MARK: - §3.1 màn chào

    /// **ĐÚNG MỘT nút chính.** Người vừa cài xong có đúng một việc phải làm; mọi nút thứ hai
    /// NGANG HÀNG là một ngã rẽ họ phải cân nhắc trước khi biết sản phẩm làm gì.
    ///
    /// Từ 22/09/2026 màn này có thêm "Đổi…" để chọn thư mục lưu ([DEV-182], chủ sản phẩm yêu
    /// cầu). Nên phép đo đổi từ ĐẾM NÚT sang đếm nút CHÍNH — đúng chữ của §3.1. Đếm nút là một
    /// phép đo dễ viết cho một điều khoản nói về thứ khác: một nút phụ nằm trong dòng thông tin
    /// không phải một ngã rẽ, còn hai nút cùng cỡ cạnh nhau thì có, dù đếm ra cùng con số.
    ///
    /// "Nút chính" ở đây = nút có phím tắt Enter. Đó cũng chính là thứ quyết định người dùng đi
    /// đâu khi họ gõ xong và bấm Enter mà không nhìn.
    func testManChaoDungMotNutChinhVaKhongCotPhai() {
        let (k, _) = dungKhung()
        k.layoutSubtreeIfNeeded()
        XCTAssertTrue(k.dangChao)
        let nut = Self.nut(k.manChao)
        let chinh = Self.nutChinh(k.manChao)
        XCTAssertEqual(chinh.count, 1, "màn chào có \(chinh.count) nút CHÍNH: \(chinh)")
        XCTAssertTrue(chinh[0].contains("Tạo dự án đầu tiên"), chinh[0])
        XCTAssertLessThanOrEqual(nut.count, 2, "màn chào có \(nut.count) nút: \(nut)")
        // Màn chào phủ TOÀN cửa sổ, nên cột phải nằm dưới nó — "không cột phải lúc này".
        XCTAssertEqual(k.manChao.frame, k.frame, "màn chào không phủ toàn cửa sổ")
    }

    /// Trạng thái rỗng hai phần của B5 — lý do, rồi bước kế tiếp.
    func testManChaoNoiLyDoRoiBuocKeTiep() {
        let (k, _) = dungKhung()
        let van = Self.chu(k.manChao)
        XCTAssertTrue(van.contains("Chưa có dự án nào"), van)
        XCTAssertTrue(van.contains("Bước kế tiếp"), van)
    }

    // MARK: - §3.2 tiêu chí N1 — ≤ 3 thao tác

    /// **Đếm THAO TÁC, không đếm dòng mã.** N1 nói về số lần người chạm vào chuột/bàn phím từ
    /// lúc mở app tới lúc có dự án: (1) gõ mô tả, (2) bấm nút. Hai.
    ///
    /// Bài này đo bằng cách đi đúng đường người đi — điền ô rồi bấm nút tìm thấy trong cây khung
    /// nhìn — chứ không gọi thẳng `taoDuAn`. Gọi thẳng thì nó đo một đường không ai dùng.
    func testTaoDuAnTrongHaiThaoTac() {
        let (k, _) = dungKhung()
        var daTao: String?
        k.manChao.onTao = { van, _ in daTao = van }

        var thaoTac = 0
        k.manChao.datMoTaDeTest("đọc DHT22 trên ATmega328P")   // thao tác 1: gõ
        thaoTac += 1
        XCTAssertTrue(Self.bam(k.manChao, chua: "Tạo dự án đầu tiên"))  // thao tác 2: bấm
        thaoTac += 1

        XCTAssertEqual(daTao, "đọc DHT22 trên ATmega328P")
        XCTAssertLessThanOrEqual(thaoTac, 3, "tạo dự án mất \(thaoTac) thao tác — trái N1")
    }

    /// Ô để trống mà bấm thì dùng chính câu gợi ý đang hiện — vẫn là hai thao tác, và người dùng
    /// không bị chặn bởi một ô bắt buộc mà họ chưa biết điền gì.
    func testBoTrongOVanTaoDuocBangCauGoiY() {
        let (k, _) = dungKhung()
        var daTao: String?
        k.manChao.onTao = { van, _ in daTao = van }
        XCTAssertTrue(Self.bam(k.manChao, chua: "Tạo dự án đầu tiên"))
        XCTAssertEqual(daTao, k.manChao.goiY, "bỏ trống ô thì không tạo được gì")
    }

    // MARK: - [DEV-182] chọn thư mục lưu dự án

    /// **Màn chào NÓI RA dự án sẽ nằm ở đâu.**
    ///
    /// B5 đòi trạng thái rỗng nói lý do và bước kế tiếp; nó cũng phải nói KẾT QUẢ của bước ấy.
    /// Tới 22/09/2026 màn này im về chỗ lưu, `project.create` ghi vào `~/eide`, và người dùng
    /// tạo xong phải đi tìm dự án của chính mình.
    func testManChaoNoiRoDuAnSeNamO_DAU() {
        let (k, _) = dungKhung()
        let van = Self.chu(k.manChao)
        XCTAssertTrue(van.contains("Lưu tại"), "không nói chỗ lưu — \(van)")
        XCTAssertTrue(van.contains("eide"), van)
        XCTAssertTrue(van.contains("mặc định"), "không nói đây là mặc định đổi được — \(van)")
    }

    /// Chọn thư mục khác thì thư mục ấy ĐI THEO xuống `project.create`, và màn hiện đúng nó.
    ///
    /// Đo cả hai vế: một màn hiện đúng đường dẫn nhưng không truyền nó đi là một màn nói dối,
    /// và lỗi ấy im lặng — dự án vẫn được tạo, chỉ ở nhầm chỗ.
    func testChonThuMucKhacThiDuongDanDI_THEO_xuongLenhTao() {
        let (k, _) = dungKhung()
        var nhan: (String, String?)?
        k.manChao.onTao = { van, thu in nhan = (van, thu) }
        k.manChao.datThuMucDeTest("/Volumes/Data/du-an")
        XCTAssertTrue(Self.chu(k.manChao).contains("/Volumes/Data/du-an"),
                      Self.chu(k.manChao))
        XCTAssertFalse(Self.chu(k.manChao).contains("mặc định"),
                       "đã chọn thư mục riêng mà vẫn ghi là mặc định")
        k.manChao.datMoTaDeTest("đọc DHT22")
        XCTAssertTrue(Self.bam(k.manChao, chua: "Tạo dự án đầu tiên"))
        XCTAssertEqual(nhan?.1, "/Volumes/Data/du-an", "thư mục người chọn không đi theo")
    }

    /// Không chọn gì thì truyền `nil`, KHÔNG truyền chuỗi rỗng: `--dir ""` tạo dự án ở thư mục
    /// hiện hành của tiến trình — một chỗ người dùng không chọn và không đoán được.
    func testKhongChonThiTruyenNilChuKhongPhaiChuoiRong() {
        let (k, _) = dungKhung()
        var nhan: (String, String?)?
        k.manChao.onTao = { van, thu in nhan = (van, thu) }
        XCTAssertTrue(Self.bam(k.manChao, chua: "Tạo dự án đầu tiên"))
        XCTAssertNil(nhan?.1 ?? nil, "truyền \(String(describing: nhan?.1)) thay vì nil")
    }

    // MARK: - §3.3 chào đúng BA thứ

    /// Ba, không bốn. "Không tour dài" là nguyên văn §3.3, và thứ tư trở đi là thứ người dùng
    /// lướt qua — lướt qua một danh sách bốn mục thì họ lướt qua cả ba mục đầu.
    func testChaoDungBaThuVaKhongHonNua() {
        let c = EidePhien.chaoBaThu(soNangLuc: 245)
        XCTAssertTrue(c.contains("1."), c)
        XCTAssertTrue(c.contains("2. ⌘K"), c)
        XCTAssertTrue(c.contains("3."), c)
        XCTAssertFalse(c.contains("4."), "chào bốn thứ — §3.3 nói không tour dài")
        XCTAssertTrue(c.contains("Dừng khẩn"), c)
    }

    /// Số năng lực đếm TỪ REGISTRY, không chép cứng.
    ///
    /// Con số cũ là "244" và nó sai ngay hôm danh mục lên 245. Một câu chào nói sai một con số
    /// KIỂM ĐƯỢC là chỗ rẻ nhất để người dùng học rằng sản phẩm không đáng tin về những con số
    /// nó đưa ra — và họ sẽ mang bài học ấy sang những con số đắt hơn.
    func testSoNangLucTrongCauChaoDenTuRegistry() {
        XCTAssertTrue(EidePhien.chaoBaThu(soNangLuc: 245).contains("245 năng lực"))
        XCTAssertTrue(EidePhien.chaoBaThu(soNangLuc: 300).contains("300 năng lực"))
        // Chưa nạp xong registry thì nói chung chung, KHÔNG bịa một con số.
        let chua = EidePhien.chaoBaThu(soNangLuc: nil)
        XCTAssertTrue(chua.contains("danh mục năng lực"), chua)
        XCTAssertFalse(chua.contains("năng lực và") == false && chua.contains("244"), chua)
    }

    /// Sau khi làm quen thì S1 đang mở — câu chào nói về những thứ trên màn hình, nên màn hình
    /// phải hiện trước.
    func testLamQuenMoS1VaChaoTrongVungTraoDoi() {
        let (k, ph) = dungKhung()
        ph.lamQuen()
        XCTAssertEqual(k.vungLamViec.dangMo, "Main")
        XCTAssertTrue(Self.chu(k.dock).contains("Ba thứ cần biết"), Self.chu(k.dock))
    }

    // MARK: - §3.4 lệnh mẫu xoay vòng

    /// Ba lệnh mẫu phải CHẠY ĐƯỢC THẬT — mỗi câu là một dự án nhúng có thật, không phải ví dụ
    /// trừu tượng kiểu "làm một cái gì đó với cảm biến".
    func testBaLenhMauLaLenhThatVaXoayVong() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 4_000_000)
        ph.dongHo = { gio }
        XCTAssertEqual(EideManChao.MAU.count, 3)

        k.dock.batDauLamQuen(gio)
        let dau = k.dock.goiYHienTai
        XCTAssertTrue(dau.contains(EideManChao.MAU[0]), dau)
        gio += EideDock.XOAY_MOI
        XCTAssertTrue(k.dock.xoayMau(gio))
        XCTAssertNotEqual(k.dock.goiYHienTai, dau, "placeholder không xoay")
        XCTAssertTrue(k.dock.goiYHienTai.contains(EideManChao.MAU[1]), k.dock.goiYHienTai)
    }

    /// **Hết mười phút thì gợi ý theo pha (§2D.4) nhận lại quyền.** Hai luật cùng viết vào một
    /// ô, nên phải nói rõ luật nào thắng lúc nào — không thì ô lệnh nhấp nháy giữa hai nguồn.
    func testHetMuoiPhutThiTraOLaiChoGoiYTheoPha() {
        let (k, ph) = dungKhung()
        var gio = Date(timeIntervalSince1970: 4_000_000)
        ph.dongHo = { gio }
        k.dock.datPha("P3")
        k.dock.batDauLamQuen(gio)
        XCTAssertTrue(k.dock.goiYHienTai.contains("Thử:"), k.dock.goiYHienTai)

        gio += EideDock.GIAI_DOAN_DAU + 1
        XCTAssertFalse(k.dock.xoayMau(gio), "hết mười phút mà vẫn báo còn xoay")
        XCTAssertTrue(k.dock.goiYHienTai.contains("sinh mã"),
                      "không trả ô lại cho gợi ý theo pha — \(k.dock.goiYHienTai)")
    }

    // MARK: - §4.1 mở / đóng / tiêu điểm

    func testBangLenhMoDongVaRongOTimMoiLanMo() {
        let (k, _) = dungKhung()
        XCTAssertTrue(k.bangLenh.isHidden)
        k.bangLenh.mo()
        XCTAssertFalse(k.bangLenh.isHidden)
        k.bangLenh.locDeTest("ho chieu")
        k.bangLenh.dong()
        XCTAssertTrue(k.bangLenh.isHidden)
        // Mở lại phải SẠCH: ô còn chữ cũ thì lần mở sau hiện một danh sách đã lọc mà người dùng
        // không nhớ mình lọc bằng gì.
        k.bangLenh.mo()
        XCTAssertTrue(k.bangLenh.chuTim.isEmpty, "mở lại mà ô tìm còn chữ cũ: \(k.bangLenh.chuTim)")
    }

    /// Esc đóng — qua `cancelOperation`, đường chuẩn của AppKit cho phím Escape.
    func testEscDongBangLenh() {
        let (k, _) = dungKhung()
        k.bangLenh.mo()
        k.bangLenh.cancelOperation(nil)
        XCTAssertTrue(k.bangLenh.isHidden, "Esc không đóng bảng lệnh")
    }

    // MARK: - §4.2 nguồn và cách tìm

    /// Nguồn = 25 màn + năng lực thật. Thiếu vế nào thì bảng lệnh trả lời được một nửa câu hỏi.
    func testNguonGomDu25ManVaNangLuc() {
        let (k, _) = dungKhung()
        k.bangLenh.datNguon(nangLuc: [("passport.query", "tra cứu hộ chiếu chip")])
        XCTAssertEqual(k.bangLenh.soMuc, EideManHinhDS.tatCa.count + 1)
        XCTAssertEqual(EideManHinhDS.tatCa.count, 25)
    }

    /// **Tìm theo MÔ TẢ, không chỉ theo tên** — và không dấu. Người nhớ mình muốn làm gì chứ ít
    /// khi nhớ năng lực nào tên gì.
    func testTimTheoMoTaVaKhongDau() {
        let (k, _) = dungKhung()
        k.bangLenh.datNguon(nangLuc: [("passport.query", "tra cứu hộ chiếu chip"),
                                      ("code.build", "dựng firmware")])
        XCTAssertTrue(k.bangLenh.locDeTest("ho chieu").contains { $0.ma == "passport.query" },
                      "không tìm được qua mô tả không dấu")
        XCTAssertTrue(k.bangLenh.locDeTest("DỰNG").contains { $0.ma == "code.build" },
                      "phân biệt hoa thường")
    }

    // MARK: - §4.3 toast kết quả cổng

    /// Toast phải nói ĐỦ: quyết định, năng lực, cổng, mã quy tắc, lý do. Một toast ghi "DENY"
    /// trần trụi không cho người dùng đường nào đi tiếp.
    func testToastNoiDuQuyetDinhCongVaMaQuyTac() {
        let c = EideToast.cau(["decision": "DENY", "gate": "G-FACT", "rule": "FACT-03",
                               "reason": "hằng số không có fact"], cap: "code.merge")
        XCTAssertTrue(c.contains("DENY"), c)
        XCTAssertTrue(c.contains("G-FACT"), c)
        XCTAssertTrue(c.contains("FACT-03"), c)
        XCTAssertTrue(c.contains("hằng số không có fact"), c)
    }

    /// Thiếu trường thì NÓI thiếu. "không rõ quy tắc" là một câu trả lời; một chỗ trống thì không.
    func testThieuTruongThiNoiThieuChuKhongDeTrong() {
        let c = EideToast.cau(["decision": "ASK"], cap: "x.y")
        XCTAssertTrue(c.contains("ASK"), c)
        XCTAssertTrue(c.contains("không rõ quy tắc"), c)
    }

    func testToastDoiMauTheoQuyetDinh() {
        let t = EideToast()
        XCTAssertEqual(t.chu, "", "toast hiện sẵn lúc chưa có gì")
        t.hien(["decision": "APPROVE", "rule": "R-1"], cap: "a.b")
        XCTAssertTrue(t.chu.contains("APPROVE"), t.chu)
        t.an()
        XCTAssertEqual(t.chu, "")
    }

    // MARK: - §4.4 form tham số sinh từ hợp đồng

    private static let HOP_DONG: [String: Any] = [
        "id": "passport.query",
        "input_schema": [
            "type": "object",
            "required": ["subject", "predicate"],
            "properties": [
                "subject": ["type": "string", "description": "peripheral hoặc thanh ghi"],
                "predicate": ["type": "string", "enum": ["base_address", "reset_value"]],
                "limit": ["type": "integer"],
                "verbose": ["type": "boolean"],
            ],
        ],
    ]

    func testDocDungThamSoBatBuocTuHopDong() {
        XCTAssertEqual(EideFormThamSo.batBuoc(Self.HOP_DONG).sorted(), ["predicate", "subject"])
        XCTAssertTrue(EideFormThamSo.batBuoc(["input_schema": ["type": "object"]]).isEmpty)
    }

    /// **Không cho gọi thiếu** — nút Chạy chết cho tới khi mọi ô bắt buộc có giá trị, và nó nói
    /// rõ còn thiếu ô nào.
    func testNutChayChetKhiConThieuThamSoBatBuoc() {
        let f = EideFormThamSo(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        f.mo(id: "passport.query", mota: Self.HOP_DONG)
        XCTAssertEqual(f.conThieu().sorted(), ["predicate", "subject"])
        XCTAssertTrue(Self.chu(f).contains("Còn thiếu"), Self.chu(f))
        XCTAssertFalse(Self.nutBat(f, chua: "Chạy"), "cho bấm Chạy khi còn thiếu tham số")
    }

    /// Số gửi đi phải là SỐ. Gửi `"5"` cho một trường `integer` sẽ trượt `input_schema` và trả
    /// E1000 — đúng cái lỗi form này sinh ra để tránh.
    func testTruongIntegerGuiDiLaSoChuKhongPhaiChuoi() {
        let f = EideFormThamSo(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        f.mo(id: "passport.query", mota: Self.HOP_DONG)
        f.dienDeTest(["subject": "TIM2", "predicate": "base_address", "limit": "5"])
        let t = f.thamSo()
        XCTAssertEqual(t["subject"] as? String, "TIM2")
        XCTAssertEqual(t["limit"] as? Int, 5, "gửi chuỗi cho trường integer — \(t)")
        XCTAssertTrue(f.conThieu().isEmpty)
    }

    /// Ô tuỳ chọn để trống thì KHÔNG gửi. Gửi `""` cho một trường không bắt buộc là gửi một giá
    /// trị người dùng chưa hề chọn.
    func testOTuyChonDeTrongThiKhongGui() {
        let f = EideFormThamSo(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        f.mo(id: "passport.query", mota: Self.HOP_DONG)
        f.dienDeTest(["subject": "TIM2", "predicate": "base_address"])
        XCTAssertNil(f.thamSo()["limit"], "gửi ô tuỳ chọn còn trống")
    }

    /// Hợp đồng khai bắt buộc mà không khai `properties` thì NÓI RA, đừng hiện một form rỗng có
    /// nút Chạy — bấm vào sẽ gọi thiếu, đúng thứ §4.4 cấm.
    func testHopDongKhuyetPropertiesThiNoiRa() {
        let f = EideFormThamSo(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        f.mo(id: "x.y", mota: ["input_schema": ["required": ["a"]]])
        XCTAssertTrue(Self.chu(f).contains("không dựng được form"), Self.chu(f))
    }

    // MARK: - phụ

    private static func nut(_ v: NSView) -> [String] {
        var ra: [String] = []
        if let b = v as? NSButton, !v.isHidden {
            let t = b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string
            if !t.isEmpty { ra.append(t) }
        }
        for c in v.subviews where !c.isHidden { ra += nut(c) }
        return ra
    }

    private static func bam(_ v: NSView, chua: String) -> Bool {
        if let b = v as? NSButton {
            let t = b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string
            if t.contains(chua), let a = b.action {
                b.sendAction(a, to: b.target)
                return true
            }
        }
        for c in v.subviews where bam(c, chua: chua) { return true }
        return false
    }

    /// Nút CHÍNH = nút nhận phím Enter. Xem `testManChaoDungMotNutChinhVaKhongCotPhai`.
    private static func nutChinh(_ v: NSView) -> [String] {
        var ra: [String] = []
        if let b = v as? NSButton, !v.isHidden, b.keyEquivalent == "\r", !b.title.isEmpty {
            ra.append(b.title)
        }
        for c in v.subviews where !c.isHidden { ra += nutChinh(c) }
        return ra
    }

    private static func nutBat(_ v: NSView, chua: String) -> Bool {
        if let b = v as? NSButton, b.title.contains(chua) { return b.isEnabled }
        for c in v.subviews where nutBat(c, chua: chua) { return true }
        return false
    }

    private static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField {
            ra += (t.attributedStringValue.string.isEmpty ? t.stringValue
                                                          : t.attributedStringValue.string) + " "
            ra += (t.placeholderString ?? "") + " "
        }
        if let b = v as? NSButton {
            ra += (b.attributedTitle.string.isEmpty ? b.title : b.attributedTitle.string) + " "
        }
        for c in v.subviews { ra += chu(c) }
        return ra
    }
    // MARK: - gợi ý ô lệnh phải NÓI VỀ DỰ ÁN NÀY

    /// Ba nguồn gợi ý cũ đều là hằng số về một dự án tưởng tượng.
    ///
    /// Trên một dự án CNC thật, ô lệnh mời người dùng "thử: robot hai bánh tự cân bằng trên
    /// ATmega328P". Chủ sản phẩm gọi đúng tên: *"nút Gửi bạn đưa một câu chẳng liên quan gì để
    /// gợi ý"*. Một gợi ý sai chủ đề tệ hơn không gợi ý — nó dạy người dùng rằng ô này không
    /// biết họ đang làm gì, nên họ thôi đọc nó, kể cả lúc nó nói đúng bước kế tiếp.
    func testGoiYNeuMaYeuCauTHATcuaDuAn() {
        let yc: [[String: Any]] = [["id": "UR-CTL-02", "kind": "HW"],
                                   ["id": "FR-GEN-01", "kind": "FR"]]
        let c = EidePhien.goiYTuDuAn(yeuCau: yc, lamRoMo: 0) ?? ""
        XCTAssertTrue(c.contains("UR-CTL-02"), "phải nêu MÃ thật của dự án: \(c)")
        XCTAssertFalse(c.contains("ATmega328P"), c)
    }

    /// Yêu cầu đã đối chiếu hết mà còn điểm cần làm rõ → nhắc đúng chỗ tác tử đang chờ.
    func testGoiYNhacDiemCanLamRoKhiDaDoiChieuHet() {
        let yc: [[String: Any]] = [["id": "UR-01", "feasibility": "ok"]]
        let c = EidePhien.goiYTuDuAn(yeuCau: yc, lamRoMo: 3) ?? ""
        XCTAssertTrue(c.contains("3 điểm cần làm rõ"), c)
    }

    /// Dự án trắng → mời mô tả việc, KHÔNG nêu một mã bịa ra.
    func testGoiYKhiDuAnChuaCoGi() {
        let c = EidePhien.goiYTuDuAn(yeuCau: [], lamRoMo: 0) ?? ""
        XCTAssertTrue(c.contains("Mô tả việc cần làm"), c)
    }
}
