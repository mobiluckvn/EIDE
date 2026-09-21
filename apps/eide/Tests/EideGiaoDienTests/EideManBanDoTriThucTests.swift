import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S7 — Bản đồ tri thức & hỏi đáp.** Ràng buộc nặng nhất của cả sản phẩm nằm ở màn này: một
/// câu trả lời hiện ra mà không kèm nguồn bấm được thì cả tầng tri thức bên dưới thành trang trí.
@MainActor
final class EideManBanDoTriThucTests: XCTestCase {

    // MARK: - bố cục đồ thị (thuần, đo được mà không cần vẽ)

    /// Bố cục phải TẤT ĐỊNH: cùng dữ liệu cho cùng hình. Một bố cục lực đẩy đặt nút ở chỗ khác
    /// nhau sau mỗi lần mở — đẹp hơn, và không so được hai lần mở, không chụp ảnh đối chiếu được.
    func testBoCucTatDinhVaKhongPhuThuocThuTuDauVao() {
        let a = EideDoThi.bayBien(Self.NUT)
        let b = EideDoThi.bayBien(Self.NUT.reversed())
        XCTAssertEqual(a, b, "đảo thứ tự đầu vào làm đổi bố cục — hình không so được giữa hai lần mở")
        XCTAssertFalse(a.isEmpty)
    }

    /// Cột đi theo HƯỚNG ĐỌC của đồ thị — nguồn → fact → chủ thể → mã — chứ không theo bảng chữ
    /// cái. Đó là hướng người ta lần một con số về tới trang datasheet đẻ ra nó.
    func testThuTuCotTheoHuongDocChuKhongTheoChuCai() {
        let cot = EideDoThi.cotVaX(Self.NUT).map(\.0)
        XCTAssertEqual(cot, ["source", "fact", "periph", "code_unit"], "\(cot)")
    }

    /// Loại LẠ không bị bỏ — nó xếp sau cùng. Bỏ đi thì đồ thị thiếu nút mà không gì báo.
    func testLoaiLaVanCoCotCuaNo() {
        var ds = Self.NUT
        ds.append(EideNutDoThi(id: "x1", nhan: "x1", loai: "loai_moi_toanh"))
        XCTAssertEqual(EideDoThi.cotVaX(ds).map(\.0).last, "loai_moi_toanh")
    }

    /// Lõi GOM CỤM chứ không cắt (VIEW-01), nên chỗ cắt duy nhất là bên vẽ — và nó không được
    /// im lặng. Một đồ thị hiện 240 nút trong khi có 900 trông đầy đủ và thiếu.
    func testCatBotThiNoiRaBaoNhieuNutChuaVe() {
        let v = EideDoThi()
        let nhieu = (0..<300).map { EideNutDoThi(id: "f_\($0)", nhan: "f\($0)", loai: "fact") }
        v.dat(nut: nhieu, canh: [])
        XCTAssertEqual(v.nut.count, EideDoThi.TOI_DA_VE)
        XCTAssertEqual(v.soBiCat, 300 - EideDoThi.TOI_DA_VE)

        let s = EideManBanDoTriThuc.dongTomTat(soNut: 300, soCanh: 12, gomCum: false, biCat: 60)
        XCTAssertTrue(s.contains("CÒN 60 chưa vẽ"), s)
        XCTAssertFalse(EideManBanDoTriThuc.dongTomTat(soNut: 9, soCanh: 2, gomCum: false, biCat: 0)
                        .contains("chưa vẽ"), "báo cắt khi không cắt gì")
        XCTAssertTrue(EideManBanDoTriThuc.dongTomTat(soNut: 9, soCanh: 2, gomCum: true, biCat: 0)
                        .contains("GOM CỤM"))
    }

    /// Cạnh trỏ ra ngoài tập nút ĐÃ CẮT phải rụng theo — một đường kẻ đi tới hư không vẽ ra một
    /// quan hệ không có trên màn.
    func testCanhTroRaNgoaiTapDaCatThiRung() {
        let v = EideDoThi()
        v.dat(nut: [EideNutDoThi(id: "a", nhan: "a", loai: "fact")],
              canh: [EideCanhDoThi(tu: "a", loai: "CITES", den: "khong-co")])
        XCTAssertTrue(v.canh.isEmpty)
    }

    /// VIEW-01 trả `type`; `kg.lan_toa` trả `kind`. Hai đường cùng đổ về màn này.
    func testCanhNhanCaHaiTenTruong() {
        XCTAssertEqual(EideCanhDoThi(["from": "a", "to": "b", "type": "CITES"])?.loai, "CITES")
        XCTAssertEqual(EideCanhDoThi(["from": "a", "to": "b", "kind": "USES"])?.loai, "USES")
        XCTAssertNil(EideCanhDoThi(["from": "a"]), "cạnh thiếu đích vẫn dựng được")
    }

    func testMauHexDocDuoc() {
        XCTAssertEqual(EideDoThi.mau("#D4A017")?.redComponent ?? 0, 212.0 / 255, accuracy: 0.01)
        XCTAssertNil(EideDoThi.mau("khong-phai-mau"))
        XCTAssertNil(EideDoThi.mau(nil))
    }

    /// "Đồ thị thu phóng" là chữ của UXC-31 §8 S7, và thu phóng phải có CHẶN hai đầu: 0,1× thì
    /// đồ thị thành một chấm, 10× thì không còn gì trên màn hình.
    func testThuPhongCoChanHaiDau() {
        let v = EideDoThi()
        v.dat(nut: Self.NUT, canh: [])
        let cao0 = v.intrinsicContentSize.height
        v.tyLe = 2
        XCTAssertEqual(v.intrinsicContentSize.height, cao0 * 2, accuracy: 0.5,
                       "thu phóng không đổi kích thước nội dung — thanh cuộn sẽ sai")
    }

    // MARK: - hỏi đáp

    /// **`not_found` KHÔNG phải lỗi.** VIEW-07: "< 0,35 → not_found — thà nói không biết". Đây
    /// là chỗ duy nhất trong sản phẩm mà trả về rỗng nghĩa là làm ĐÚNG việc.
    func testKhongDuCanCuHienNhuKetQua_KhongNhuLoi() async {
        let m = EideManBanDoTriThuc()
        await m.nap(Self.loiCoDoThi())
        m.hoiDeTest("điện áp cấp của một con chip chưa nhập?")
        await Self.cho()
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Không đủ căn cứ"), van)
        XCTAssertTrue(van.contains("Bước kế tiếp"), "không chỉ đường đi tiếp — \(van)")
        XCTAssertFalse(van.contains("Không hỏi được"), "hiện như một sự cố — \(van)")
    }

    /// **Bất biến của VIEW-07 giữ tới điểm ảnh cuối cùng.** Lõi đã ném E5002 khi có câu thiếu
    /// `[n]`, nhưng bên vẽ không được dựa vào một lớp khác giữ hộ bất biến của mình.
    func testCauTraLoiKHONGtrichDanThiKhongDuocHien() async {
        let m = EideManBanDoTriThuc()
        await m.nap { ten, tham in
            guard (tham["id"] as? String) == "view.rag_ask" else {
                return try await Self.loiCoDoThi()(ten, tham)
            }
            return ["status": "done", "result": [
                "answer": "DHT22 chạy ở 3,3 V.", "citations": [Any](),
                "trace_id": "tr_1", "not_found": false]]
        }
        m.hoiDeTest("điện áp DHT22?")
        await Self.cho()
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("KHÔNG kèm trích dẫn"), van)
        XCTAssertFalse(van.contains("DHT22 chạy ở 3,3 V"),
                       "đã hiện một câu trả lời không kiểm được — \(van)")
    }

    /// Có trích dẫn thì hiện đủ: số `[n]`, tên nguồn, vị trí trong nguồn, và đoạn trích.
    func testTraLoiCoTrichDanHienDuBonThu() async {
        let m = EideManBanDoTriThuc()
        await m.nap(Self.loiCoDoThi(traLoi: true))
        m.hoiDeTest("điện áp DHT22?")
        await Self.cho()
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("3,3–6,0 V"), van)
        XCTAssertTrue(van.contains("[1]"), van)
        XCTAssertTrue(van.contains("dht22.pdf"), van)
        XCTAssertTrue(van.contains("tr.4"), "mất vị trí trong nguồn — \(van)")
        XCTAssertTrue(van.contains("Vì sao câu trả lời này?"), "không có đường mở vết — \(van)")
    }

    /// tc của VIEW-08: "Hiển thị đủ 3 điểm". Gộp ba thành một con số thì "vì sao" trở lại thành
    /// "tin đi" — không ai biết câu trả lời đến từ khớp CHỮ, khớp NGHĨA hay một bước lan tỏa.
    func testVetTruyHoiHienDuBaThanhPhanDiem() {
        let m = EideManBanDoTriThuc()
        m.hienTrace(["scores": ["bm25": 0.71, "vector": 0.52, "graph": 0.30],
                     "graph_path": ["chip:aosong.dht22", "f_abc"],
                     "chunks": [1, 2, 3]])
        let van = Self.chu(m)
        for k in ["bm25", "vector", "graph"] { XCTAssertTrue(van.contains(k), "thiếu \(k) — \(van)") }
        XCTAssertTrue(van.contains("chip:aosong.dht22 → f_abc"), van)
        XCTAssertTrue(van.contains("3 đoạn"), van)
    }

    /// E5002 "chưa có chỉ mục RAG" là trạng thái THƯỜNG GẶP của một dự án mới, không phải sự cố.
    /// In nguyên mã lỗi ra thì người mở màn — vốn không viết lõi — không biết làm gì tiếp.
    func testChuaCoChiMucRAGthiNoiCachSua() {
        let e = EideKetQua.Loi.hong(cap: "view.rag_ask", ma: "E5002",
                                    van: "Chưa có chỉ mục RAG — chạy `view.rag_index` trước")
        let s = EideManBanDoTriThuc.viSaoHong(e)
        XCTAssertTrue(s.contains("S4"), "không chỉ đường đi tiếp — \(s)")
        XCTAssertFalse(s.hasPrefix("Không hỏi được"), s)
    }

    /// Đồ thị rỗng vẫn phải giữ Ô HỎI: hai thứ trên màn này trả lời hai câu khác nhau, và một
    /// dự án chưa có fact vẫn có thể có tài liệu văn bản đã lập chỉ mục.
    func testDoThiRongVanConOHoi() async {
        let m = EideManBanDoTriThuc()
        await m.nap { _, _ in ["status": "done", "result": ["graph": ["nodes": [Any]()]]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có nút nào"), van)
        XCTAssertTrue(van.contains("S4"), van)
        XCTAssertNotNil(Self.tim(m, NSTextField.self) { $0.placeholderString?.contains("Hỏi") == true },
                        "mất ô hỏi khi đồ thị rỗng")
    }

    /// VIEW-01 ném E5000 khi quá 50.000 nút và bảo "hãy lọc trước" — đó là một CHỈ DẪN, không
    /// phải một sự cố.
    func testDoThiQuaLonThiChuyenChiDanCuaLoiThanhBuocKeTiep() async {
        let m = EideManBanDoTriThuc()
        await m.nap { _, _ in
            ["status": "failed", "cap": "view.kg_map",
             "error": ["eide_code": "E5000", "message": "Đồ thị 61234 nút vượt trần 50000"]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("quá lớn"), van)
        XCTAssertTrue(van.contains("filter"), "không nói lọc bằng cách nào — \(van)")
    }

    func testManDaNoiVaoBangMan() {
        XCTAssertNotNil(EidePhien.MAN[EideManBanDoTriThuc.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManBanDoTriThuc.tien)?.ma, "S7")
    }

    // MARK: - phụ

    private static let NUT: [EideNutDoThi] = [
        .init(id: "src_a", nhan: "dht22.pdf", loai: "source", mau: "#D4A017", tang: "gold"),
        .init(id: "f_1", nhan: "voltage_range", loai: "fact", mau: "#D4A017", tang: "gold"),
        .init(id: "f_2", nhan: "timing", loai: "fact", mau: "#C5221F", trangThai: "conflict"),
        .init(id: "chip:x/periph:I2C1", nhan: "periph:I2C1", loai: "periph"),
        .init(id: "cu_1", nhan: "dht22.c", loai: "code_unit"),
    ]

    private static func loiCoDoThi(traLoi: Bool = false) -> EideGoi {
        { _, tham in
            switch (tham["id"] as? String) ?? "" {
            case "view.kg_map":
                return ["status": "done", "result": ["graph": [
                    "nodes": NUT.map { ["id": $0.id, "label": $0.nhan, "kind": $0.loai,
                                        "color": $0.mau as Any, "tier": $0.tang as Any,
                                        "status": $0.trangThai as Any] },
                    "edges": [["from": "src_a", "type": "CITES", "to": "f_1"]],
                    "clustered": false,
                    "legend": ["tier": ["gold": "#D4A017"], "status": ["conflict": "#C5221F"]],
                ]]]
            case "view.rag_ask":
                return traLoi
                    ? ["status": "done", "result": [
                        "answer": "DHT22 chạy ở 3,3–6,0 V. [1]",
                        "citations": [["n": 1, "source_id": "/kho/ds/dht22.pdf",
                                       "locator": ["page": 4], "snippet": "Supply voltage 3.3-6V",
                                       "score": 0.71]],
                        "trace_id": "tr_1", "not_found": false]]
                    : ["status": "done", "result": [
                        "answer": "", "citations": [Any](), "trace_id": "tr_0", "not_found": true]]
            default:
                return ["status": "done", "result": [String: Any]()]
            }
        }
    }

    private static func cho() async {
        for _ in 0..<60 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private static func tim<T: NSView>(_ v: NSView, _ loai: T.Type,
                                       _ hop: (T) -> Bool = { _ in true }) -> T? {
        if let x = v as? T, hop(x) { return x }
        for c in v.subviews { if let x = tim(c, loai, hop) { return x } }
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
