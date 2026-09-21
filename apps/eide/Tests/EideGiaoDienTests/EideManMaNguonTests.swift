import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Nhóm MÃ NGUỒN — S14 Trình soạn thảo, S15 Diff & cổng merge.**
///
/// UXC-31 gọi S14 là "nơi người và tác tử gặp nhau", và đó là mô tả đúng: đây là chỗ duy nhất
/// cả hai cùng ghi vào một tệp. Mọi bài kiểm dưới đây đều rơi ra từ điều ấy.
@MainActor
final class EideManMaNguonTests: XCTestCase {

    // MARK: - S14 §5.1 lề

    /// §5.1 đòi HAI dấu khác nhau, và khác biệt giữa chúng là luận điểm của cả sản phẩm:
    /// ● xanh = hằng số trỏ về fact đã duyệt; ▎đỏ = hằng số phần cứng KHÔNG nguồn, `G-FACT`
    /// sẽ chặn merge. Một trình soạn thảo bình thường chỉ thấy hai con số.
    func testLeDanhDauDongCoChuThichFact() {
        let ma = """
        #define A 1
        #define CR1 0x40005400  // eide:fact f_abc
        int x = 3;
        """
        XCTAssertEqual(EideManSoanThao.dongCoFact(ma), [2])
        XCTAssertTrue(EideManSoanThao.dongCoFact("không có gì").isEmpty)
    }

    func testLeNhanCaHaiTapVaVeLaiKhiDoi() {
        let le = EideLeSoanThao(scrollView: nil, orientation: .verticalRuler)
        le.dat(khongNguon: [3, 7], coFact: [2])
        XCTAssertEqual(le.khongNguon, [3, 7])
        XCTAssertEqual(le.coFact, [2])
    }

    // MARK: - S14 §5.3 buffer bẩn

    /// §5.3 — câu băng vàng phải nói đúng điều sẽ xảy ra với TÁC TỬ, không chỉ nói "chưa lưu".
    func testBufferBanThiBangVangNoiRaHauQuaVoiTacTu() async {
        let m = EideManSoanThao()
        m.moTepDeTest("/kho/main.c", "int x = 1;")
        XCTAssertFalse(m.ban, "chưa gõ gì mà đã bẩn")
        m.datNoiDungDeTest("int x = 2;")
        XCTAssertTrue(m.chuBang.contains("CHƯA LƯU"), m.chuBang)
        XCTAssertTrue(m.chuBang.contains("P-EDIT-01"), "không nêu luật đứng sau — \(m.chuBang)")
    }

    /// Gõ rồi gõ lại về đúng nội dung cũ thì KHÔNG còn bẩn — so nội dung, không đếm lần gõ.
    func testGoRoiHoanVeNhuCuThiHetBan() {
        let m = EideManSoanThao()
        m.moTepDeTest("/kho/main.c", "a")
        m.datNoiDungDeTest("ab")
        XCTAssertNotEqual(m.chuBang, "")
        m.datNoiDungDeTest("a")
        XCTAssertEqual(m.chuBang, "", "vẫn báo bẩn sau khi nội dung về như cũ")
    }

    // MARK: - S14 §5.6 tác tử đang sửa

    /// §5.6 — băng XANH, và người **vẫn gõ được**. Đây là thông báo, không phải cảnh báo; chặn
    /// bàn phím ở đây biến một lượt chạy nền thành một lần khoá màn hình.
    func testTacTuDangSuaTepNayThiBaoChuKhongChan() async {
        let m = EideManSoanThao()
        m.moTepDeTest("/kho/main.c", "x")
        // Chưa mở tệp nào → không nhận sự kiện của tệp khác.
        XCTAssertFalse(m.apDung("event.run.progress", ["path": "/x/main.c"]))
    }

    /// Sự kiện của tệp KHÁC không được làm phiền — mỗi lượt chạy chạm nhiều tệp, và một băng
    /// hiện lên cho tệp người không mở là một băng họ học cách bỏ qua.
    func testSuKienCuaTepKhacKhongHienBang() {
        let m = EideManSoanThao()
        XCTAssertFalse(m.apDung("event.run.progress", ["path": "/khac/kia.c"]))
        XCTAssertFalse(m.apDung("event.queue.changed", [:]))
    }

    // MARK: - S14 quét tệp

    /// Danh sách tệp phải bỏ `.git/`, `.eide/`, `.build/` — chúng đầy tệp sinh ra, và một danh
    /// sách 4000 mục thì không ai chọn được gì trong đó.
    func testQuetTepBoThuMucSinhRa() throws {
        let goc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("s14-\(UUID().uuidString)")
        let fm = FileManager.default
        for d in ["src", ".git", ".build"] {
            try fm.createDirectory(at: goc.appendingPathComponent(d),
                                   withIntermediateDirectories: true)
        }
        defer { try? fm.removeItem(at: goc) }
        try "int a;".write(to: goc.appendingPathComponent("src/main.c"),
                           atomically: true, encoding: .utf8)
        try "x".write(to: goc.appendingPathComponent(".git/cfg.c"),
                      atomically: true, encoding: .utf8)
        try "x".write(to: goc.appendingPathComponent(".build/gen.c"),
                      atomically: true, encoding: .utf8)
        try "doc".write(to: goc.appendingPathComponent("README.md"),
                        atomically: true, encoding: .utf8)

        let ds = EideManSoanThao.quetTep(goc.path)
        XCTAssertEqual(ds, ["src/main.c"], "\(ds)")
        XCTAssertEqual(EideManSoanThao.quetTep(nil), [])
    }

    // MARK: - S15 §6.3 dùng lại component

    /// **§6.3 cấm viết màn riêng cho xung đột mã.** Lý do không phải tiết kiệm mã: hai màn
    /// quyết định trông khác nhau thì người dùng học hai lần cách đọc một xung đột, và lần thứ
    /// hai họ học đúng lúc căng thẳng nhất — khi mã của họ và mã của tác tử giẫm lên nhau.
    func testS15DungLaiDungCompoNentCuaS8() async {
        let m = EideManDiffMerge()
        await m.nap(Self.loi([["cap": "code.merge_conflict_resolve", "conflict_id": "h1",
                               "path": "src/main.c", "line": 42, "line_end": 58,
                               "run_id": "r_9f3c1122",
                               "human": ["content": "TIM2->ARR = 7999;", "by": "human:congvt"],
                               "agent": ["content": "TIM2->ARR = 15999;", "by": "agent"]]]))
        XCTAssertNotNil(Self.tim(m, EideTheXungDot.self), "không dùng thẻ của S8 — trái §6.3")
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Người sửa"), van)
        XCTAssertTrue(van.contains("Tác tử Run"), van)
        XCTAssertTrue(van.contains("Soạn tay"), "thiếu nút thứ ba của xung đột MÃ — \(van)")
        XCTAssertTrue(van.contains("dòng 42–58"), van)
    }

    /// Nút thứ ba của xung đột MÃ khác của xung đột FACT: hai vùng mã giẫm lên nhau không gộp
    /// được bằng một điều kiện.
    func testNutThuBaCuaXungDotMaKhacCuaXungDotFact() async {
        let m = EideManDiffMerge()
        await m.nap(Self.loi([["cap": "code.merge_conflict_resolve", "conflict_id": "h1"]]))
        let t = Self.tim(m, EideTheXungDot.self)
        XCTAssertEqual(t?.nhanNut.last, "Soạn tay")
        XCTAssertFalse(t?.nhanNut.contains("Cả hai — có điều kiện") ?? true)
    }

    // MARK: - S15 bảng cổng

    /// `⏳` là trạng thái THỨ BA và nó không thừa: "chưa chạy" khác hẳn "chạy rồi và đạt". Gộp
    /// hai cái thành ✅ là nói rằng một cổng chưa ai mở đã mở.
    func testBangCongCoBaTrangThaiChuKhongHai() {
        let b = EideManDiffMerge.bangCong([
            ["decision": ["gate": "G-FACT", "decision": "APPROVE", "reason": "mọi hằng có fact"]],
            ["decision": ["gate": "G3", "decision": "ASK", "reason": "patch chạm ISR"]],
        ])
        let theo = Dictionary(uniqueKeysWithValues: b.map { ($0[0], ($0[1], $0[2])) })
        XCTAssertTrue(theo["G-FACT"]!.0.contains("✅"))
        XCTAssertTrue(theo["G3"]!.0.contains("⛔"))
        XCTAssertTrue(theo["G1"]!.0.contains("⏳"), "gộp 'chưa chạy' vào 'đạt'")
        XCTAssertEqual(theo["G-FACT"]!.1, "mọi hằng có fact", "mất lý do")
        XCTAssertFalse(theo["G1"]!.1.isEmpty, "⏳ mà không nói vì sao")
    }

    /// Không xung đột KHÔNG có nghĩa là merge được — hai câu ấy khác nhau, và gộp chúng là hứa
    /// một thứ cổng chưa cho.
    func testKhongXungDotVanPhaiNoiRoBangCongMoiQuyet() async {
        let m = EideManDiffMerge()
        await m.nap(Self.loi([]))
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Không có xung đột mã nào"), van)
        XCTAssertTrue(van.contains("hai câu ấy khác nhau"), van)
        XCTAssertTrue(van.contains("CỔNG TRÊN ĐƯỜNG MERGE"), van)
    }

    /// Hàng đợi trộn nhiều loại — chỉ mục của `code.*` mới thuộc màn này.
    func testTachXungDotMaKhoiMucChoKhac() {
        XCTAssertTrue(EideManDiffMerge.laXungDotMa(["cap": "code.merge_conflict_resolve"]))
        XCTAssertTrue(EideManDiffMerge.laXungDotMa(["cap": "code.merge"]))
        XCTAssertFalse(EideManDiffMerge.laXungDotMa(["cap": "kg.resolve_conflict"]))
        XCTAssertFalse(EideManDiffMerge.laXungDotMa(["cap": "chat.clarify"]))
    }

    // MARK: - chung

    func testHaiManDaNoiVaKhaiBaoNghe() {
        for (tien, ma) in [("Code", "S14"), ("DiffMerge", "S15")] {
            XCTAssertNotNil(EidePhien.MAN[tien], "`\(tien)` chưa vào bảng màn")
            XCTAssertEqual(EideManHinhDS.man(tien)?.ma, ma)
            XCTAssertNotNil(EideDangKySuKien.BANG[tien], "`\(tien)` chưa khai báo nghe gì")
        }
    }

    private static func loi(_ cho: [[String: Any]]) -> EideGoi {
        { ten, _ in
            ten == "queue.list"
                ? ["status": "done", "result": ["items": cho]]
                : ["status": "done", "result": [String: Any]()]
        }
    }

    private static func tim<T: NSView>(_ v: NSView, _ loai: T.Type) -> T? {
        if let x = v as? T { return x }
        for c in v.subviews { if let x = tim(c, loai) { return x } }
        return nil
    }

    static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField {
            ra += t.attributedStringValue.string.isEmpty ? t.stringValue
                                                         : t.attributedStringValue.string
        }
        if let b = v as? NSButton { ra += " " + b.title }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}
