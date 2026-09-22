import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **Nhóm THIẾT KẾ (S10–S13).** Cả bốn đứng trên `view.artifacts` (VIEW-14) — năng lực thêm
/// ngày 20/09 vì trước đó không cái nào trong 243 liệt kê được một hiện vật kỹ nghệ đã lưu.
@MainActor
final class EideManThietKeTests: XCTestCase {

    /// **Không màn nào được gọi năng lực SINH lúc mở.** `req.elicit` là R0 nhưng gọi mô hình,
    /// `arch.adr` là R0 nhưng ghi tệp, `diagram.architecture` là R0 nhưng dựng lược đồ mới —
    /// `R0` không có nghĩa là "chỉ đọc trạng thái có sẵn". Mở màn mà gọi chúng là tiêu tiền của
    /// người dùng mỗi lần họ bấm vào cột trái.
    func testBonManDeuKhongGoiNangLucSINHluCmo() async {
        let cam = ["req.elicit", "req.classify", "arch.adr", "arch.decompose", "plan.create",
                   "doc.generate", "diagram.architecture", "diagram.sequence", "chat.send"]
        for tao in [{ EideManYeuCau() as EideManCoSo }, { EideManKeHoach() },
                    { EideManLuocDo() }, { EideManTaiLieu() }] {
            var daGoi: [String] = []
            let m = tao()
            await m.nap { ten, tham in
                daGoi.append((tham["id"] as? String) ?? ten)
                return ["status": "done", "result": ["items": [Any](), "total": 0]]
            }
            for x in cam {
                XCTAssertFalse(daGoi.contains(x), "`\(type(of: m))` gọi `\(x)` lúc mở — \(daGoi)")
            }
            XCTAssertTrue(daGoi.contains("view.artifacts"), "\(type(of: m)): \(daGoi)")
        }
    }

    // MARK: - S10 Yêu cầu & kiến trúc

    /// **`nil` ở cột KHẢ THI là câu trả lời THỨ BA.** "Chưa đối chiếu" khác hẳn "đối chiếu rồi
    /// và không đạt"; gộp thành ô trống thì một yêu cầu chưa ai kiểm trông y hệt một yêu cầu đã
    /// kiểm và sạch.
    func testCotKhaThiPhanBietBaTrangThai() {
        XCTAssertEqual(EideManYeuCau.oKhaThi(nil), "chưa đối chiếu")
        XCTAssertEqual(EideManYeuCau.oKhaThi(""), "chưa đối chiếu")
        XCTAssertEqual(EideManYeuCau.oKhaThi("ok"), "đạt")
        XCTAssertTrue(EideManYeuCau.oKhaThi("no").contains("KHÔNG đạt"))
    }

    /// ADR không trích dẫn gì là ADR không kiểm lại được — KAD-07 dựng cả tầng tri thức để mọi
    /// quyết định truy về một fact.
    func testADRkhongTrichDanThiDanhDau() {
        XCTAssertTrue(EideManYeuCau.oTrichDan([Any]()).contains("không có"))
        XCTAssertTrue(EideManYeuCau.oTrichDan(nil).contains("không có"))
        XCTAssertEqual(EideManYeuCau.oTrichDan(["f_a", "f_b"]), "2 fact")
    }

    func testS10HienBangYeuCauVaADR() async {
        let m = EideManYeuCau()
        await m.nap(Self.loi([
            "requirement": [
                ["id": "FR-01", "kind": "FR", "text": "Đọc DHT22", "priority": "must",
                 "status": "reviewed", "feasibility": "ok"],
                ["id": "NFR-01", "kind": "NFR", "text": "Chu kỳ ≤ 2 s", "priority": "should",
                 "status": "generated"],
            ],
            "adr": [["id": "ADR-01", "title": "Bit-bang", "decision": "dùng bit-bang",
                     "status": "accepted", "citations": [Any]()]],
        ]))
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("2 YÊU CẦU"), van)
        XCTAssertTrue(van.contains("1 CHƯA đối chiếu"), "không đếm phần chưa đối chiếu — \(van)")
        XCTAssertTrue(van.contains("FR-01") && van.contains("đạt"), van)
        XCTAssertTrue(van.contains("QUYẾT ĐỊNH KIẾN TRÚC"), van)
        XCTAssertTrue(van.contains("không có"), "ADR rỗng trích dẫn không bị đánh dấu — \(van)")
    }

    // MARK: - S12 Kế hoạch

    /// Một tính năng không nối về yêu cầu nào là một tính năng không ai truy được vì sao nó tồn
    /// tại — REQ-06 dựng ma trận truy vết chính để chỗ này không trống.
    func testTinhNangKhongNoiYeuCauThiDanhDau() {
        XCTAssertTrue(EideManKeHoach.oYeuCau(nil).contains("không nối yêu cầu"))
        XCTAssertEqual(EideManKeHoach.oYeuCau(["FR-01", "FR-02"]), "FR-01, FR-02")
        XCTAssertTrue(EideManKeHoach.oYeuCau(["a", "b", "c", "d"]).contains("+1"))
    }

    /// **Khối "còn thiếu" lên ĐẦU bảng** — UXC-31 §8 S12. Thứ tự ấy là nội dung: một kế hoạch
    /// thiếu căn cứ vẫn chạy được từng bước và vẫn hỏng ở bước cuối.
    func testKhoiConThieuLenTruocBangBuoc() async {
        let m = EideManKeHoach()
        await m.nap { ten, tham in
            switch (tham["id"] as? String) ?? ten {
            case "plan.sufficiency":
                return ["status": "done", "result": ["sufficient": false,
                                                     "missing": ["timing I2C", "mức I/O"]]]
            default:
                return ["status": "done", "result": [
                    "items": [["id": "F-01", "title": "Đọc cảm biến", "status": "failing",
                               "requirement_ids": ["FR-01"]]],
                    "total": 1]]
            }
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("CÒN THIẾU 2 căn cứ"), van)
        XCTAssertTrue(van.contains("timing I2C"), van)
        // Khối cảnh báo phải đứng TRƯỚC tiêu đề bảng.
        let iThieu = van.range(of: "CÒN THIẾU")?.lowerBound
        let iBang = van.range(of: "TÍNH NĂNG CÓ KẾ HOẠCH")?.lowerBound
        XCTAssertNotNil(iThieu); XCTAssertNotNil(iBang)
        XCTAssertTrue(iThieu! < iBang!, "khối còn thiếu nằm SAU bảng — trái §8 S12")
    }

    // MARK: - S11 Lược đồ

    /// **`stale` trong store là INTEGER (0/1)**, không phải Bool — SQLite không có kiểu boolean.
    /// Đọc bằng `as? Bool` ra `nil` cho MỌI hàng, và cột đồng bộ im lặng báo "khớp".
    func testStaleDocDuocCaDangSoLanBool() {
        XCTAssertTrue(EideManLuocDo.laLech(["stale": 1]))
        XCTAssertFalse(EideManLuocDo.laLech(["stale": 0]))
        XCTAssertTrue(EideManLuocDo.laLech(["stale": true]))
        XCTAssertFalse(EideManLuocDo.laLech([:]), "thiếu cột thì coi là khớp, không đoán bừa")
        XCTAssertTrue(EideManLuocDo.oDongBo(["stale": 1]).contains("LỆCH"))
        XCTAssertTrue(EideManLuocDo.oDongBo(["stale": 0, "synced_with": "/x/main.c"])
                        .contains("main.c"))
    }

    func testS11BangVangVaNutDongBoKhiLech() async {
        let m = EideManLuocDo()
        await m.nap(Self.loi(["diagram": [
            ["id": "DG-01", "kind": "sequence", "lang": "mermaid", "stale": 1],
            ["id": "DG-02", "kind": "block", "lang": "mermaid", "stale": 0],
        ]]))
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("1 lược đồ đang LỆCH"), van)
        XCTAssertTrue(van.contains("tệ hơn không có lược đồ"), "không nói hậu quả — \(van)")
        XCTAssertTrue(van.contains("Đồng bộ DG-01"), "thiếu nút đồng bộ — \(van)")
        XCTAssertFalse(van.contains("Đồng bộ DG-02"), "bày nút cho lược đồ đang khớp — \(van)")
    }

    // MARK: - S13 Tài liệu

    /// Năm loại vấn đề của `doc.style_check` KHÔNG ngang nhau: sai thuật ngữ làm tài liệu khó
    /// đọc, còn `uncited` làm nó **không kiểm được** — đúng thứ cả sản phẩm tồn tại để tránh.
    func testUncitedTachRiengKhoiVanDeVanPhong() {
        let ds: [[String: Any]] = [["kind": "uncited"], ["kind": "term"], ["kind": "lang"]]
        XCTAssertEqual(EideManTaiLieu.soKhongNguon(ds), 1)
        let o = EideManTaiLieu.oVanDe(ds)
        XCTAssertTrue(o.contains("1 KHÔNG NGUỒN"), o)
        XCTAssertTrue(o.contains("2 văn phong"), o)
        XCTAssertEqual(EideManTaiLieu.oVanDe([Any]()), "không")
    }

    func testS13BangDoCanhBaoKhiCoKhangDinhKhongNguon() async {
        let m = EideManTaiLieu()
        await m.nap(Self.loi(["doc": [
            ["id": "DOC-01", "type": "SRS", "path": "docs/srs.md", "lang": "vi",
             "style_issues": [["kind": "uncited"]], "stale_sections": ["§3"]],
        ]]))
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("KHÔNG CÓ NGUỒN"), van)
        XCTAssertTrue(van.contains("không kiểm lại được"), van)
        XCTAssertTrue(van.contains("1 TÀI LIỆU ĐÃ SINH"), van)
    }

    // MARK: - chung

    /// Bốn màn phải có trong bảng màn ĐÃ NỐI và đều khai báo nghe sự kiện (§7.1).
    func testBonManDaNoiVaKhaiBaoNghe() {
        for (tien, ma) in [("ReqArch", "S10"), ("DiagramView", "S11"),
                           ("PlanDiff", "S12"), ("Doc", "S13")] {
            XCTAssertNotNil(EidePhien.MAN[tien], "`\(tien)` chưa vào bảng màn")
            XCTAssertEqual(EideManHinhDS.man(tien)?.ma, ma)
            XCTAssertNotNil(EideDangKySuKien.BANG[tien], "`\(tien)` chưa khai báo nghe gì")
        }
    }

    /// Dự án chưa có store → bốn câu "bước kế tiếp" KHÁC NHAU, vì bốn hiện vật ra đời từ bốn
    /// chỗ khác nhau. Một câu chung sẽ chỉ người dùng tới sai nơi ba lần trong bốn.
    func testBonManNoiBonBuocKeTiepKhacNhau() async {
        var cau: Set<String> = []
        for tao in [{ EideManYeuCau() as EideManCoSo }, { EideManKeHoach() },
                    { EideManLuocDo() }, { EideManTaiLieu() }] {
            let m = tao()
            await m.nap { _, _ in
                ["status": "failed", "cap": "view.artifacts",
                 "error": ["eide_code": "E2000", "message": "Không thấy store"]]
            }
            let van = Self.chu(m)
            XCTAssertTrue(van.contains("Bước kế tiếp"), van)
            cau.insert(van.components(separatedBy: "Bước kế tiếp").last ?? "")
        }
        XCTAssertEqual(cau.count, 4, "hai màn dùng chung một câu bước kế tiếp")
    }

    private static func loi(_ theoLoai: [String: [[String: Any]]]) -> EideGoi {
        { ten, tham in
            guard (tham["id"] as? String) == "view.artifacts",
                  let k = (tham["params"] as? [String: Any])?["kind"] as? String else {
                return ["status": "done", "result": [String: Any]()]
            }
            let ds = theoLoai[k] ?? []
            return ["status": "done", "result": ["items": ds, "total": ds.count, "kind": k]]
        }
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

/// **S12 — dòng "CÒN THIẾU" phải nói được thiếu CÁI GÌ.** [DEV-171]
///
/// `plan.sufficiency` trả `missing[]` gồm các ĐỐI TƯỢNG, và `EideManHoChieu.giaTri` đưa mọi
/// đối tượng về `"{3 khoá}"`. Nên trước bản vá, dòng cảnh báo đọc ra đúng thế này:
///
///     ⚠ `F-01` — CÒN THIẾU 2 căn cứ: {3 khoá}, {3 khoá}
///
/// Đúng số lượng, không một chữ nào nói thiếu gì. Một cảnh báo không nói nổi nội dung của
/// chính nó thì người dùng chỉ còn cách đoán — và đoán sai thì họ bỏ qua.
@MainActor
final class EideMoTaThieuTests: XCTestCase {

    /// Loại quan trọng nhất: thứ tác tử HỎI NGƯỢC người. Nó nằm ở `text`, và `text` phải hiện
    /// nguyên văn — đây là câu hỏi, không phải mã hiệu.
    func testCauHoiCuaTacTuHienNguyenVan() {
        let s = EideManKeHoach.moTaThieu([
            "loai": "hoi_nguoi",
            "text": "Chưa rõ tần số thạch anh (F_CPU) thực tế trên board mạch của người dùng",
            "hanh_dong": "trả lời ở tab Làm rõ yêu cầu (S9)"])
        XCTAssertEqual(s, "Chưa rõ tần số thạch anh (F_CPU) thực tế trên board mạch của người dùng")
    }

    func testQuyetDinhCongHienNguyenVan() {
        let s = EideManKeHoach.moTaThieu([
            "loai": "cong", "text": "Cổng G1 (G1-02) ASK: Thiếu tri thức → mở P1 trước"])
        XCTAssertEqual(s, "Cổng G1 (G1-02) ASK: Thiếu tri thức → mở P1 trước")
    }

    /// Hai loại suy được: chúng KHÔNG có `text`, nên phải dựng câu từ các khoá.
    func testThieuTriThucVaCongCuDungCau() {
        XCTAssertEqual(
            EideManKeHoach.moTaThieu(["loai": "tri_thuc", "predicate": "timing",
                                      "hanh_dong": "search.missing hoặc kg.request"]),
            "chưa có fact nào cho `timing`")
        XCTAssertEqual(
            EideManKeHoach.moTaThieu(["loai": "cong_cu", "ten": "avr-gcc",
                                      "hanh_dong": "env.install"]),
            "thiếu công cụ `avr-gcc`")
    }

    /// KHÔNG được quay lại `{3 khoá}` cho bất kỳ loại nào — kể cả loại thêm sau này.
    func testLoaiLaVanKHONG_ra_ba_khoa() {
        let s = EideManKeHoach.moTaThieu(["loai": "loai_moi_nao_do", "ten": "x"])
        XCTAssertFalse(s.contains("khoá"), s)
    }

    /// `missing[]` của `plan.create` từng trộn chuỗi lẫn đối tượng. Chuỗi phải đi thẳng qua.
    func testChuoiThuanDiThang() {
        XCTAssertEqual(EideManKeHoach.moTaThieu("thiếu timing của I2C"), "thiếu timing của I2C")
    }
}
