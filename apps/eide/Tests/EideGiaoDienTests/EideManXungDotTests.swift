import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S8 — Xung đột tri thức.** Mỗi bài ghim một cách màn quyết-định này có thể nói sai.
@MainActor
final class EideManXungDotTests: XCTestCase {

    // MARK: - thẻ dùng chung (UXC-31 §6.3)

    /// §6.3 cấm viết màn riêng cho xung đột MÃ và bắt dùng lại đúng thẻ này. Ràng buộc ấy chỉ
    /// giữ được nếu thẻ không biết gì về fact — nên bài này dựng nó bằng dữ liệu MÃ.
    func testTheDungDuocChoCaXungDotMA() {
        let t = EideTheXungDot(
            ma: "src/main.c",
            tieuDe: "src/main.c · dòng 42–58",
            phuDe: "hai bên sửa cùng vùng",
            a: .init(nhan: "Người sửa 14:22", giaTri: "TIM2->ARR = 7999;",
                     phu: [("tác giả", "human:congvt")], khoa: "a"),
            b: .init(nhan: "Tác tử Run #7", giaTri: "TIM2->ARR = 15999;",
                     phu: [("tác giả", "agent:run-r_9f3c")], khoa: "b"),
            them: [("Soạn tay", "manual")])
        XCTAssertEqual(t.nhanNut, ["Chọn Người", "Chọn Tác", "Soạn tay"])

        var thu: (String, String)?
        t.onChon = { thu = ($0, $1) }
        (Self.nut(t, "Soạn tay"))?.performClick(nil)
        XCTAssertEqual(thu?.0, "src/main.c")
        XCTAssertEqual(thu?.1, "manual", "thẻ dịch lại khoá — mỗi lần dịch là một chỗ để lệch")
    }

    /// **Hai vế phải đối xứng.** Lõi chỉ đánh `status = conflict` cho fact ĐẾN SAU; fact đến
    /// trước giữ `normalized`. Dùng chung nhãn với màn Hộ chiếu chip thì vế A hiện "vàng · chưa
    /// duyệt" còn vế B hiện "⚠ XUNG ĐỘT" — đọc như thể chỉ một bên bị tranh chấp, trong khi cả
    /// thẻ tồn tại vì CẢ HAI đang tranh chấp.
    func testHaiVeKhongBiDungBatDoiXungVeTrangThai() {
        let a = EideManXungDot.ve(["value": 1, "tier": "gold", "status": "normalized"],
                                  nhan: "A", viTu: "offset")
        let b = EideManXungDot.ve(["value": 2, "tier": "gold", "status": "conflict"],
                                  nhan: "B", viTu: "offset")
        XCTAssertEqual(a.phu.first?.1, b.phu.first?.1,
                       "hai vế cùng tầng mà hiện hai nhãn khác nhau: \(a.phu) vs \(b.phu)")
        // Trạng thái KHÁC conflict vẫn phải nói ra — `superseded` là tin thật.
        XCTAssertEqual(EideManXungDot.tangTrongThe("silver", "superseded"), "đã thay")
    }

    /// `detail` là câu lõi dựng cho SỔ CÁI: giá trị hệ 10, nguồn bằng mã băm. Đặt nó ngay trên
    /// hai cột in cùng hai con số ở hệ 16 kèm tên tệp là bày hai cách đọc cho cùng một dữ liệu,
    /// và cách tệ hơn đứng trước.
    func testCauDETAILcuaLoiKhongLenThe() async {
        let m = EideManXungDot()
        await m.nap(Self.loiGia())
        let van = Self.chu(m)
        XCTAssertFalse(van.contains("1073763328"), "giá trị hệ 10 lọt lên thẻ — \(van)")
        XCTAssertFalse(van.contains("nguồn s_rm"), "nguồn bằng mã băm lọt lên thẻ — \(van)")
        XCTAssertTrue(van.contains("chip:st.stm32f411ce/periph:I2C1"),
                      "mất IRI đầy đủ — thứ người copy ra để tra chỗ khác — \(van)")
    }

    /// Ba lựa chọn của KG-06 phải có đủ mặt. Thiếu `both_conditional` là bỏ mất nhánh đúng của
    /// trường hợp thường gặp nhất: errata chỉ áp cho một revision.
    func testDuBaLuaChonCuaKG06() {
        let t = Self.the()
        XCTAssertEqual(t.nhanNut, ["Chọn A", "Chọn B", "Cả hai — có điều kiện"])
        var khoa: String?
        t.onChon = { khoa = $1 }
        Self.nut(t, "Cả hai — có điều kiện")?.performClick(nil)
        XCTAssertEqual(khoa, "both_conditional")
    }

    // MARK: - định dạng một vế

    /// Một địa chỉ hiện ở hệ 10 tại đây thì người phải tự đổi hệ trong đầu để so với datasheet
    /// — mà so với datasheet chính là việc họ đang làm khi đứng trước màn này.
    func testVeHienDiaChiTheoHeMuoiSau() {
        let v = EideManXungDot.ve(
            ["fact_id": "f_abcdef1234", "value": 1_073_763_328, "tier": "gold",
             "status": "conflict", "source": "/kho/ds/rm0383.pdf"],
            nhan: "A", viTu: "base_address")
        XCTAssertEqual(v.giaTri, "0x40005400")
        XCTAssertEqual(v.khoa, "a")
        XCTAssertEqual(v.nhan, "A · vàng")
        XCTAssertEqual(v.phu.first { $0.0 == "nguồn" }?.1, "rm0383.pdf")
        XCTAssertEqual(v.phu.first { $0.0 == "fact" }?.1, "cdef1234")
    }

    /// `"human"` không phải một cái tên. UXC-31 §8 S8 đòi dòng lịch sử ghi TÊN NGƯỜI, và
    /// `eide_core/git.py` đã có sẵn quy ước `human:<tên>`.
    func testActorMangTenNguoiChuKhongPhaiChuHuman() {
        let ai = EideManXungDot.nguoi()
        XCTAssertTrue(ai.hasPrefix("human:"), ai)
        XCTAssertGreaterThan(ai.count, "human:".count, "tên rỗng — \(ai)")
    }

    // MARK: - màn chạy trên một lõi giả

    /// **`resource_ready = false` KHÁC "sạch".** Không nói ra thì "không thấy xung đột tài
    /// nguyên" đọc thành "đã kiểm và không có".
    func testChuaKiemTaiNguyenThiNoiRa() async {
        let m = EideManXungDot()
        await m.nap { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "view.conflict_board": return ["status": "done", "result": ["rows": [Self.HANG]]]
            case "kg.conflicts":
                return ["status": "done", "result": ["conflicts": [], "resource_ready": false]]
            default: return ["status": "done", "result": [String: Any]()]
            }
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa được kiểm"), van)
        XCTAssertTrue(van.contains("hw_map"), van)
        XCTAssertTrue(van.contains("không có nghĩa là sạch"), van)
    }

    /// Hai vế phải CÙNG hiện ra, kèm tầng và nguồn của mỗi bên — đó là toàn bộ thứ người cần
    /// để quyết.
    func testHaiVeCungHienKemTangVaNguon() async {
        let m = EideManXungDot()
        await m.nap(Self.loiGia())
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("0x40005400"), van)
        XCTAssertTrue(van.contains("0x40005800"), van)
        XCTAssertTrue(van.contains("rm0383.pdf"), van)
        XCTAssertTrue(van.contains("errata-rev-b.pdf"), van)
        XCTAssertTrue(van.contains("1 XUNG ĐỘT ĐANG MỞ"), van)
    }

    /// **Bấm một nút ở đây KHÔNG áp dụng ngay.** KG-06 qua cổng G-FACT nên lời gọi dừng ở
    /// `pending`. Một màn nói "đã xong" lúc ấy là nói sai, và người sẽ đóng máy tin rằng store
    /// đã đổi.
    func testPendingNoiRaLaDANGCHOChuKhongPhaiDaXong() async {
        let m = EideManXungDot()
        var thamDaGui: [String: Any]?
        await m.nap { ten, tham in
            if (tham["id"] as? String) == "kg.resolve_conflict" {
                thamDaGui = tham["params"] as? [String: Any]
                // Chép ĐÚNG thứ lõi trả về, đo 20/09 trên một dự án thật: quy tắc bắt hết theo
                // mức tự chủ, `gate = "*"` — KHÔNG phải một quy tắc G-FACT như tôi đã đoán.
                return ["status": "pending", "cap": "kg.resolve_conflict",
                        "decision": ["decision": "ASK", "gate": "*", "rule": "DEFAULT",
                                     "reason": "Năng lực mức T2 — mặc định hỏi người"]]
            }
            return try await Self.loiGia()(ten, tham)
        }
        Self.bamDau(m, "Chọn A")
        await Self.cho()

        XCTAssertEqual(thamDaGui?["conflict_id"] as? String, "f_a:f_b")
        XCTAssertEqual(thamDaGui?["choice"] as? String, "a")
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("CHỜ TÔI"), "không chỉ người tới chỗ duyệt — \(van)")
        XCTAssertTrue(van.contains("chưa ghi vào store"), van)
        XCTAssertTrue(van.contains("mặc định hỏi người"), "nuốt lý do của cổng — \(van)")
        XCTAssertFalse(van.contains("Đã áp dụng"), "nói đã xong trong khi mới chỉ gửi — \(van)")
        XCTAssertFalse(van.contains("cổng *"), "in ra một cái cổng không có tên — \(van)")
    }

    /// Câu "vì sao còn phải chờ" phải dựng TỪ quyết định của cổng, không viết cứng. Bản đầu ghi
    /// "cổng G-FACT hỏi người" — nghe có thẩm quyền, khớp tài liệu, và không khớp thứ máy trả về.
    func testCauChoDungTuQuyetDinhThatChuKhongVietCung() {
        XCTAssertEqual(
            EideManXungDot.vinao(["rule": "DEFAULT", "gate": "*",
                                  "reason": "Năng lực mức T2 — mặc định hỏi người"]),
            "Năng lực mức T2 — mặc định hỏi người (luật DEFAULT).")
        XCTAssertEqual(
            EideManXungDot.vinao(["rule": "G-FACT-01", "gate": "G-FACT", "reason": "Chọn fact"]),
            "Chọn fact (luật G-FACT-01, cổng G-FACT).")
        XCTAssertTrue(EideManXungDot.vinao(nil).hasSuffix("."), "câu trống không có dấu chấm")
    }

    /// Lỗi của lõi phải ra nguyên mã. E3000 ở đây có nghĩa rất cụ thể — "việc này luôn cần
    /// người" — và nuốt nó thành "không chạy được" là bỏ mất lời giải thích.
    func testLoiLoiRaNGUYENMA() async {
        let m = EideManXungDot()
        await m.nap { ten, tham in
            if (tham["id"] as? String) == "kg.resolve_conflict" {
                return ["status": "failed", "cap": "kg.resolve_conflict",
                        "error": ["eide_code": "E3000",
                                  "message": "Giải quyết xung đột fact luôn cần người"]]
            }
            return try await Self.loiGia()(ten, tham)
        }
        Self.bamDau(m, "Chọn B")
        await Self.cho()
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("E3000"), van)
        XCTAssertTrue(van.contains("luôn cần người"), van)
    }

    /// Rỗng phải kèm quyết định gần nhất, đọc từ SỔ CÁI — "không còn xung đột" và "chưa bao giờ
    /// có xung đột nào" là hai tình trạng khác hẳn nhau.
    func testRongThiNoiQuyetDinhGanNhatDocTuSoCai() async {
        let m = EideManXungDot()
        await m.nap { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "view.conflict_board": return ["status": "done", "result": ["rows": [Any]()]]
            case "kg.conflicts":
                return ["status": "done", "result": ["conflicts": [], "resource_ready": true]]
            default: return ["status": "done", "result": [String: Any]()]
            }
        } // `view.timeline` đi qua `doc()` với tên phương thức, không qua caps.invoke
        XCTAssertTrue(Self.chu(m).contains("không còn xung đột"), Self.chu(m))

        let m2 = EideManXungDot()
        await m2.nap { ten, tham in
            if ten == "view.timeline" {
                return ["status": "done", "result": ["events": [
                    ["kind": "cap.run.start", "at": "2026-09-19T08:00:00+00:00", "data": [:]],
                    ["kind": "gate.human", "at": "2026-09-20T09:12:00+00:00",
                     "data": ["by": "human:congvt", "gate_id": "G-FACT",
                              "note": "kg.resolve_conflict f_a:f_b → a"]],
                ]]]
            }
            switch (tham["id"] as? String) ?? "" {
            case "view.conflict_board": return ["status": "done", "result": ["rows": [Any]()]]
            default: return ["status": "done", "result": ["conflicts": [], "resource_ready": true]]
            }
        }
        let van = Self.chu(m2)
        XCTAssertTrue(van.contains("quyết định gần nhất"), van)
        XCTAssertTrue(van.contains("human:congvt"), van)
        XCTAssertTrue(van.contains("20/09 09:12"), van)
    }

    /// Dự án vừa tạo chưa có `store.sqlite`, và `view.conflict_board` trả E2000. Đó là câu
    /// "chưa có tri thức nào", không phải một sự cố — để nguyên thì màn đẩy người đi kiểm
    /// daemon, một việc không hỏng.
    func testChuaCoStoreThiNoiChuaCoTriThucChuKhongBaoLoi() async {
        let m = EideManXungDot()
        await m.nap { _, tham in
            guard (tham["id"] as? String) == "view.conflict_board" else {
                return ["status": "done", "result": ["conflicts": [], "resource_ready": true]]
            }
            return ["status": "failed", "cap": "view.conflict_board",
                    "error": ["eide_code": "E2000", "message": "Không thấy store của dự án: …"]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có store tri thức"), van)
        XCTAssertTrue(van.contains("S4"), "không chỉ đường đi tiếp — \(van)")
        XCTAssertFalse(van.contains("kiểm tra daemon"), "đẩy người đi sửa thứ không hỏng — \(van)")
    }

    func testManDaNoiVaoBangMan() {
        XCTAssertNotNil(EidePhien.MAN[EideManXungDot.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManXungDot.tien)?.ma, "S8")
    }

    // MARK: - phụ

    private static let HANG: [String: Any] = [
        "conflict_id": "f_a:f_b",
        "subject": "chip:st.stm32f411ce/periph:I2C1",
        "predicate": "base_address",
        "detail": "hai nguồn nói hai địa chỉ nền khác nhau",
        "a": ["fact_id": "f_a", "value": 1_073_763_328, "tier": "gold", "status": "conflict",
              "source": "/kho/ds/rm0383.pdf"],
        "b": ["fact_id": "f_b", "value": 1_073_764_352, "tier": "silver", "status": "conflict",
              "source": "/kho/ds/errata-rev-b.pdf"],
    ]

    private static func loiGia() -> EideGoi {
        { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "view.conflict_board": return ["status": "done", "result": ["rows": [HANG]]]
            case "kg.conflicts":
                return ["status": "done", "result": ["conflicts": [], "resource_ready": true]]
            default: return ["status": "done", "result": [String: Any]()]
            }
        }
    }

    private static func the() -> EideTheXungDot {
        EideTheXungDot(ma: "f_a:f_b", tieuDe: "I2C1 · base_address", phuDe: "",
                       a: EideManXungDot.ve(HANG["a"], nhan: "A", viTu: "base_address"),
                       b: EideManXungDot.ve(HANG["b"], nhan: "B", viTu: "base_address"),
                       them: [("Cả hai — có điều kiện", "both_conditional")])
    }

    /// Bấm nút đầu tiên mang nhãn ấy trong cây khung nhìn của màn.
    private static func bamDau(_ v: NSView, _ nhan: String) {
        if let b = v as? NSButton, b.title == nhan { return b.performClick(nil) }
        for c in v.subviews { bamDau(c, nhan) }
    }

    private static func nut(_ v: NSView, _ nhan: String) -> NSButton? {
        if let b = v as? NSButton, b.title == nhan { return b }
        for c in v.subviews { if let x = nut(c, nhan) { return x } }
        return nil
    }

    /// Nút bấm mở một `Task`; nhường một nhịp cho nó chạy xong.
    private static func cho() async {
        for _ in 0..<40 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    static func chu(_ v: NSView) -> String {
        var ra = ""
        if let t = v as? NSTextField {
            ra += t.attributedStringValue.string.isEmpty ? t.stringValue
                                                         : t.attributedStringValue.string
        }
        if let b = v as? NSButton { ra += " " + b.title }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}
