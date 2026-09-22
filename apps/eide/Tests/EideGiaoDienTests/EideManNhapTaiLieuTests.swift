import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S4 — Nhập tài liệu.** Đường ống này là bước đầu tiên trong đời một dự án; mỗi bài dưới đây
/// ghim một cách nó có thể im lặng làm sai.
@MainActor
final class EideManNhapTaiLieuTests: XCTestCase {

    /// **Bên gọi đầu tiên dispatch trên `extractor`.** Bảy trong chín extractor nhận `file`;
    /// hai cái còn lại không, và gửi sai tên trả E1000 cho đúng hai loại tệp thường gặp.
    /// Bản sinh đôi của bảng này nằm trong `tests/test_ingest_passport.py`, đọc thẳng
    /// `input_schema` — nên một extractor mới nhận tên khác làm phía Python đỏ trước.
    func testThamSoTepDungTenChoTungExtractor() {
        XCTAssertEqual(EideManNhapTaiLieu.THAM_TEP["archive.list"], "path")
        XCTAssertEqual(EideManNhapTaiLieu.THAM_TEP["extract.bom"], "sources")
        XCTAssertNil(EideManNhapTaiLieu.THAM_TEP["extract.svd"], "svd nhận `file`, không ngoại lệ")
    }

    /// `extractor = null` là một CÂU TRẢ LỜI, không phải ô trống. Bỏ trống thì người dùng thấy
    /// tệp mình vừa thả nằm im trong bảng mà không biết vì sao.
    func testKhongCoExtractorThiNoiViSao() {
        XCTAssertTrue(EideManNhapTaiLieu.viSaoKhongTrich("readme").contains("chỉ mục toàn văn"))
        XCTAssertTrue(EideManNhapTaiLieu.viSaoKhongTrich("image").contains("DEV-076"))
        XCTAssertTrue(EideManNhapTaiLieu.viSaoKhongTrich("html").contains("HTML"))
        XCTAssertFalse(EideManNhapTaiLieu.viSaoKhongTrich("unknown").isEmpty)
    }

    /// Dự án chưa nhập gì → đúng câu UXC-31 §8 S4 quy định, VÀ vùng thả vẫn còn: lời mời và
    /// lời giải thích là hai việc khác nhau.
    func testRongVanCoVungThaVaLoiMoi() async {
        let m = EideManNhapTaiLieu()
        await m.nap { _, _ in ["status": "done", "result": ["events": [Any](), "total": 0]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa nhập tài liệu nào"), van)
        XCTAssertTrue(van.contains("kéo PDF/SVD/BOM"), van)
        XCTAssertNotNil(Self.tim(m, EideVungTha.self), "mất vùng kéo-thả ở trạng thái rỗng")
    }

    /// **Đường ống phải đi đúng thứ tự và gọi đúng thứ.** Phân loại → khử trùng → extractor của
    /// từng tệp MỚI. Khử trùng phải chạy TRƯỚC khi trích, vì cả điểm của nó là tránh chạy lại
    /// một lượt trích đắt tiền.
    func testDuongOngGoiDungThuTuVaBoQuaTepTrung() async {
        var daGoi: [String] = []
        let m2 = EideManNhapTaiLieu()
        await m2.nap { ten, tham in
            let id = (tham["id"] as? String) ?? ten
            daGoi.append(id)
            switch id {
            case "ingest.classify":
                return ["status": "done", "result": ["classification": [
                    ["file": "/kho/a.svd", "kind": "svd", "tier": "gold",
                     "extractor": "extract.svd", "confidence": 1.0],
                    ["file": "/kho/cu.atdf", "kind": "atdf", "tier": "gold",
                     "extractor": "extract.atdf", "confidence": 1.0],
                ]]]
            case "ingest.hash_dedupe":
                return ["status": "done", "result": [
                    "new": ["/kho/a.svd"],
                    "dup": [["file": "/kho/cu.atdf", "source_id": "src_cu"]]]]
            case "extract.svd":
                return ["status": "done", "result": ["batch_id": "b1", "n_facts": 412,
                                                     "part": "st.stm32f411ce"]]
            default:
                return ["status": "done", "result": ["events": [Any]()]]
            }
        }
        daGoi.removeAll()
        m2.thaDeTest(["/kho/a.svd", "/kho/cu.atdf"])
        await Self.cho()

        XCTAssertEqual(daGoi.prefix(2).map { $0 }, ["ingest.classify", "ingest.hash_dedupe"],
                       "sai thứ tự — khử trùng phải chạy TRƯỚC khi trích: \(daGoi)")
        XCTAssertTrue(daGoi.contains("extract.svd"), daGoi.description)
        XCTAssertFalse(daGoi.contains("extract.atdf"),
                       "đã trích lại một tệp đã có trong store — \(daGoi)")

        let van = Self.chu(m2)
        XCTAssertTrue(van.contains("412 fact"), van)
        XCTAssertTrue(van.contains("đã có trong store"), van)
    }

    /// `pending` KHÔNG phải lỗi và cũng không phải "0 fact". Extractor là R1: với mức tự chủ
    /// thấp, cổng hỏi người trước khi fact vào store.
    func testTrichChoDuyetThiNoiRaChuKhongBaoKhongFact() async {
        let m = EideManNhapTaiLieu()
        await m.nap { ten, tham in
            switch (tham["id"] as? String) ?? ten {
            case "ingest.classify":
                return ["status": "done", "result": ["classification": [
                    ["file": "/kho/ds.pdf", "kind": "pdf", "tier": "silver",
                     "extractor": "extract.pdf_layout", "confidence": 0.9],
                ]]]
            case "extract.pdf_layout":
                return ["status": "pending", "cap": "extract.pdf_layout",
                        "decision": ["decision": "ASK", "rule": "G-FACT-02", "gate": "G-FACT",
                                     "reason": "Fact tầng bạc cần người duyệt"]]
            default: return ["status": "done", "result": ["events": [Any]()]]
            }
        }
        m.thaDeTest(["/kho/ds.pdf"])
        await Self.cho()
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("CHỜ DUYỆT"), van)
        XCTAssertTrue(van.contains("G-FACT"), van)
        XCTAssertFalse(van.contains("0 fact"), "đọc thành trích được 0 fact — \(van)")
    }

    /// **Bảng nguồn thật** — `archive.sources` (ARCHIVE-08), năng lực thêm theo [DEV-134].
    ///
    /// `n_pending` tách khỏi `n_facts`: gộp hai số thì một datasheet đã nhập trọn vẹn mà chưa
    /// ai duyệt trông y hệt một datasheet đã duyệt xong.
    func testBangNguonTachFACTvoiCHUADUYET() async {
        let m = EideManNhapTaiLieu()
        await m.nap(Self.loiCoNguon())
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("2 NGUỒN ĐÃ NHẬP"), van)
        XCTAssertTrue(van.contains("rm0383.pdf"), van)
        XCTAssertTrue(van.contains("412"), van)
        XCTAssertTrue(van.contains("7 fact chưa dùng được"), "không tổng hợp phần chờ — \(van)")
        XCTAssertTrue(van.contains("CHƯA DUYỆT"), van)
    }

    /// `0` ở cột CHƯA DUYỆT là tin TỐT nhất trong cả bảng — nguồn ấy đã sẵn sàng cho tác tử
    /// sinh mã. Một cột toàn số thì mắt lướt qua đúng cái `0` ấy.
    func testKhongConFactChoThiNoiRaBangCHU() {
        XCTAssertEqual(EideManNhapTaiLieu.oChuaDuyet(0), "— dùng được")
        XCTAssertEqual(EideManNhapTaiLieu.oChuaDuyet(7), "7")
    }

    /// `added_at` đọc từ cột `fetched_at` của DDD-14 §2, và cột ấy RỖNG với tệp người tự bỏ vào
    /// — chỉ `search.fetch` mới điền. Ô trống ở đó đọc như dữ liệu bị mất.
    func testNguonKhongCoMocThoiGianVanNoiRaViSao() async {
        let m = EideManNhapTaiLieu()
        await m.nap(Self.loiCoNguon())
        XCTAssertTrue(Self.chu(m).contains("tệp tại chỗ"), Self.chu(m))
    }

    /// Lịch sử nhập vẫn dựng từ SỔ CÁI, và nằm DƯỚI bảng nguồn: nó trả lời một câu khác —
    /// "lần nhập nào ghi được bao nhiêu", không phải "máy đã đọc những gì".
    func testLichSuNhapVanCoDuoiBangNguon() async {
        let m = EideManNhapTaiLieu()
        await m.nap(Self.loiCoNguon())
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("LƯỢT NHẬP GẦN ĐÂY"), van)
        XCTAssertTrue(van.contains("20/09 09:12"), van)
        XCTAssertTrue(van.contains("FACT MỚI"), "cột FACT trần đọc thành 'lần nhập hỏng' — \(van)")
    }

    /// `reason` của `store.write` là chuỗi RỖNG trong đường đi thường gặp nhất — `passport.import`
    /// không nhận `reason` nên ghi `""`. `?? "…"` không cứu được vì `""` không phải `nil`, và đo
    /// trên cửa sổ thật thì cả cột trống trơn.
    func testLoKhongCoLyDoVanNhanDangDuoc() {
        XCTAssertEqual(EideManNhapTaiLieu.nhanLo(
            ["reason": "", "batch_id": "b_ccb9a8e5f315728a"]), "lô ccb9a8e5f3")
        XCTAssertEqual(EideManNhapTaiLieu.nhanLo(
            ["reason": "extract.svd", "batch_id": "b_x"]), "extract.svd")
        XCTAssertEqual(EideManNhapTaiLieu.nhanLo(["reason": "   "]), "nhập tri thức")
    }

    /// Thư mục KHÔNG đi vào đường ống: `ingest.classify` đọc byte đầu của một TỆP, nên một thư
    /// mục vào đó thành `unknown` kèm lý do vô nghĩa.
    func testThuMucBiLoaiKhoiThaoTacKeo() throws {
        let tam = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("s4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tam, withIntermediateDirectories: true)
        let tep = tam.appendingPathComponent("a.svd")
        try "<device/>".write(to: tep, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tam) }

        let pb = NSPasteboard(name: .init("s4-test-\(UUID().uuidString)"))
        pb.clearContents()
        pb.writeObjects([tam as NSURL, tep as NSURL])
        let ds = EideVungTha.duongDan(GiaKeo(pb))
        XCTAssertEqual(ds, [tep.path], "thư mục lọt vào đường ống — \(ds)")
    }

    func testManDaNoiVaoBangMan() {
        XCTAssertNotNil(EidePhien.MAN[EideManNhapTaiLieu.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManNhapTaiLieu.tien)?.ma, "S4")
    }

    // MARK: - phụ

    /// Lõi giả có hai nguồn thật và một lần nhập trong sổ cái.
    private static func loiCoNguon() -> EideGoi {
        { ten, tham in
            if ten == "view.timeline" {
                return ["status": "done", "result": ["events": [
                    ["kind": "store.write", "at": "2026-09-20T09:12:00+00:00",
                     "data": ["batch_id": "b1", "n_facts": 412, "n_conflicts": 1,
                              "actor": "agent", "reason": "extract.svd"]],
                    ["kind": "cap.run.start", "at": "2026-09-20T09:11:00+00:00", "data": [:]],
                ], "total": 2]]
            }
            guard (tham["id"] as? String) == "archive.sources" else {
                return ["status": "done", "result": [String: Any]()]
            }
            return ["status": "done", "result": ["sources": [
                ["source_id": "s_rm", "uri": "/kho/ds/rm0383.pdf", "kind": "datasheet",
                 "tier": "gold", "added_at": NSNull(), "n_facts": 412, "n_pending": 7],
                ["source_id": "s_er", "uri": "/kho/ds/errata.pdf", "kind": "errata",
                 "tier": "silver", "added_at": "2026-09-19T10:00:00+00:00",
                 "n_facts": 12, "n_pending": 0],
            ]]]
        }
    }

    private static func cho() async {
        for _ in 0..<60 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 150_000_000)
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

/// Một `NSDraggingInfo` tối thiểu — chỉ để `EideVungTha.duongDan` đọc được pasteboard.
private final class GiaKeo: NSObject, NSDraggingInfo {
    private let pb: NSPasteboard
    init(_ pb: NSPasteboard) { self.pb = pb }
    var draggingPasteboard: NSPasteboard { pb }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 0 }
    var numberOfValidItemsForDrop: Int { get { 0 } set { _ = newValue } }
    var draggingFormation: NSDraggingFormation { get { .default } set { _ = newValue } }
    var animatesToDestination: Bool { get { false } set { _ = newValue } }
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to: NSPoint) {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for: NSView?,
                                classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                                using: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    func resetSpringLoading() {}
}
