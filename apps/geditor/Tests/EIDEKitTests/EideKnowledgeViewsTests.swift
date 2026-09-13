import AppKit
import XCTest

@testable import EIDEKit

/// Ba khung nhìn tri thức — UXD-13 màn 5, 7, 10.
///
/// Mỗi khung nhìn ở đây có đúng MỘT bất biến đáng test, và cả ba là cùng một bất biến nhìn từ
/// ba phía: **không hiện một con số mà không hiện nguồn của nó.**
///
/// Test đọc `soDong`/`soTrichDan`/`soMucLoiThoi` thay vì dựng cả cửa sổ rồi dò cây khung nhìn.
/// Dò cây thì bài test đỏ mỗi lần ai đó đổi bố cục — và đỏ vì một lý do không liên quan gì tới
/// thứ nó định giữ.
final class EideKnowledgeViewsTests: XCTestCase {

    // MARK: - Màn 5: Hộ chiếu

    func testHoChieuRongThiNOIRAchuKhongDeTrong() {
        let v = PassportView()
        v.capNhat(ketQua: [:])
        XCTAssertEqual(v.soDong, 0)

        // U9: rỗng phải NÓI RA là rỗng. Một khoảng trắng khiến người dùng tưởng đang tải.
        v.capNhat(ketQua: ["facts": [], "citations": [], "tiers": [:], "latency_ms": 3])
        XCTAssertEqual(v.soDong, 0)
    }

    func testHoChieuHienDUdongFact() {
        let v = PassportView()
        v.capNhat(ketQua: [
            "facts": [
                ["id": "f_1", "subject": "chip:st.stm32f411/periph:I2C1",
                 "predicate": "base_address", "value": "0x40005400",
                 "tier": "gold", "status": "verified"],
                ["id": "f_2", "subject": "chip:st.stm32f411/periph:I2C1/reg:CR1",
                 "predicate": "offset", "value": 0, "tier": "silver", "status": "reviewed"],
            ],
            "citations": [["source_id": "src_1", "uri": "STM32F411.svd", "tier": "gold"]],
            "tiers": ["gold": 1, "silver": 1, "bronze": 0],
            "latency_ms": 12,
        ])
        XCTAssertEqual(v.soDong, 2)
    }

    // MARK: - Màn 7: Hỏi đáp — bất biến quan trọng nhất của cả ba màn

    func testKHONGtrichDanThiKHONGhienCauTraLoi() {
        // Đây là chỗ dễ nhân nhượng nhất trong cả giao diện: mô hình đã trả lời rồi, câu văn
        // trôi chảy, và giấu nó đi trông như phần mềm hỏng. Nhưng `view.rag_ask` sinh ra để trả
        // lời CÓ NGUỒN; một câu không nguồn hiện ở đây sẽ được đọc y như một câu có nguồn — và
        // người đọc không có cách nào phân biệt.
        let v = RagAskView()
        v.capNhat(ketQua: [
            "answer": "I2C1 dùng chân PB6 và PB7.",   // nghe rất hợp lý
            "citations": [],                            // …và không có gì đỡ
        ])
        XCTAssertTrue(v.daChanVoTrichDan)
        XCTAssertEqual(v.soTrichDan, 0)
    }

    func testCoTrichDanThiHienCaCauTraLoiLanNguon() {
        let v = RagAskView()
        v.capNhat(ketQua: [
            "answer": "I2C1 dùng chân PB6 và PB7.",
            "citations": [
                ["source_id": "src_1", "uri": "STM32F411.pdf", "page": 47, "tier": "gold"],
                ["source_id": "src_2", "uri": "RM0383.pdf", "tier": "gold"],
            ],
            "trace_id": "tr_9",
        ])
        XCTAssertFalse(v.daChanVoTrichDan)
        XCTAssertEqual(v.soTrichDan, 2)
    }

    func testKhongTimThayGiThiNOIkhacVoiBIchan() {
        // Hai câu khác nhau cho hai tình huống khác nhau: "tri thức chưa phủ" (`not_found` của
        // hợp đồng VIEW-07) và "mô hình trả lời mà không dẫn nguồn". Gộp một câu thì người dùng
        // không biết nên đi trích thêm tài liệu hay nên nghi ngờ mô hình.
        let a = RagAskView()
        a.capNhat(ketQua: ["answer": "", "citations": [], "not_found": true])
        XCTAssertTrue(a.daChanVoTrichDan)

        // `not_found: false` + câu trả lời + không trích dẫn = mô hình tự nói. Vẫn chặn.
        let b = RagAskView()
        b.capNhat(ketQua: ["answer": "Có, dùng PB6.", "citations": [], "not_found": false])
        XCTAssertTrue(b.daChanVoTrichDan)
    }

    // MARK: - Màn 10: Tài liệu — hợp đồng doc.generate / doc.style_check / doc.sync

    func testMucLOITHOIvaSoLIEUkhongTrichDanNOIlenTIEUDE() {
        // `doc.sync` trả `stale[]` (mảng object), `doc.style_check` trả `issues[]{kind,...}`.
        // `uncited` là "số liệu kỹ thuật không có [cite]" — cùng một bất biến với hai màn kia,
        // chỉ khác là lần này con số không nguồn nằm trong tệp sắp gửi người khác đọc.
        let v = DocView()
        v.capNhat(ketQua: [
            "doc_id": "SRS-001",
            "path": "docs/SRS.md",
            "issues": [
                ["kind": "uncited", "location": "§3.2", "text": "I2C1 ở 0x40005400"],
                ["kind": "lang", "location": "§1.1", "text": "dùng nhiều từ tiếng Anh"],
            ],
            "stale": [["heading": "Giao tiếp I2C", "fact_id": "f_1"]],
            "updated": ["§4"],
        ])
        XCTAssertEqual(v.soKhongTrichDan, 1)
        XCTAssertEqual(v.soMucLoiThoi, 1)
        XCTAssertEqual(v.soMuc, 3)   // 1 lỗi thời + 2 lỗi văn phong
    }

    func testSauDOCgenerateMoiCoCONsoThiNOIcachXemCHItiet() {
        // `doc.generate` chỉ trả `style_issues` là một SỐ. Hiện "đã sinh: SRS.md" mà nuốt con
        // số ấy thì nó chỉ còn tồn tại trong store.
        let v = DocView()
        v.capNhat(ketQua: ["doc_id": "SRS-001", "path": "docs/SRS.md", "style_issues": 7])
        XCTAssertEqual(v.soMuc, 0)             // chưa có danh sách chi tiết
        XCTAssertEqual(v.soKhongTrichDan, 0)
    }

    func testTaiLieuRongThiNOIRA() {
        let v = DocView()
        v.capNhat(ketQua: [:])
        XCTAssertEqual(v.soMuc, 0)
        XCTAssertEqual(v.soMucLoiThoi, 0)
    }

    // MARK: - Định dạng dùng chung

    func testTRANGTHAIcanhBaoTHANGtangTinCay() {
        // Một fact `gold` nhưng `conflict` phải hiện là XUNG ĐỘT, không hiện là "vàng": tầng nói
        // nguồn đáng tin tới đâu, trạng thái nói fact NÀY đã dùng được chưa. Hiện tầng ở đó là
        // mời người ta tin một con số đang có hai giá trị mâu thuẫn.
        XCTAssertEqual(EideKnowledgeFormat.nhanTang("gold", "conflict"), "XUNG ĐỘT")
        XCTAssertEqual(EideKnowledgeFormat.nhanTang("gold", "normalized"), "chưa duyệt")
        XCTAssertEqual(EideKnowledgeFormat.nhanTang("gold", "verified"), "vàng")
        XCTAssertEqual(EideKnowledgeFormat.nhanTang("silver", "reviewed"), "bạc")
        XCTAssertEqual(EideKnowledgeFormat.mauTang("gold", "conflict"), EideToken.Mau.bad)
    }

    func testTenNganLayDUOIcuaIRI() {
        // Hiện cả IRI thì mỗi dòng dài gấp ba và phần khác nhau giữa các dòng bị đẩy ra mép.
        XCTAssertEqual(
            EideKnowledgeFormat.tenNgan("chip:st.stm32f411/periph:I2C1/reg:CR1"), "CR1")
        XCTAssertEqual(EideKnowledgeFormat.tenNgan("chip:st.stm32f411"), "st.stm32f411")
        XCTAssertEqual(EideKnowledgeFormat.tenNgan(""), "")
    }

    func testGiaTriGIUnguyenDangHEX() {
        // Người đọc datasheet đọc hex; đổi `0x40005400` thành `1073763328` là bắt họ tự dịch
        // ngược mỗi lần đối chiếu với tài liệu hãng.
        XCTAssertEqual(EideKnowledgeFormat.giaTri("0x40005400"), "0x40005400")
        XCTAssertEqual(EideKnowledgeFormat.giaTri(400_000), "400000")
        XCTAssertEqual(EideKnowledgeFormat.giaTri(3.3), "3.3")
        XCTAssertEqual(EideKnowledgeFormat.giaTri(nil), "—")
        XCTAssertEqual(EideKnowledgeFormat.giaTri([1, 2]), "[1, 2]")
    }

    // MARK: - Đường vào của ô lệnh — chỗ lỗi im lặng #15 đã sống

    func testCauTIENGVIETdiToiCHUOIVIEC_khongPhaiBuocHIEUY() {
        // Panel từng gọi thẳng `chat.parse_intent`, tức bước 1 trong 4 bước DPS-09. Người gõ
        // "Tạo dự án robot" thấy "Tôi hiểu là: project.create (92%)" rồi… hết. Không chuỗi nào
        // được dựng, không việc nào chạy — một giao diện hiểu mọi thứ và không làm gì.
        XCTAssertEqual(EidePanel.duongVao("Tạo cho anh dự án robot hai bánh"),
                       .chuoiViec("Tạo cho anh dự án robot hai bánh"))
    }

    func testLenhGACHCHEOmoMANchuKhongDiVaoBOdoanY() {
        // 19 intent của DPS-09 §4.1 không chứa id nào trong 238 năng lực, nên một lệnh "/" đi
        // qua bộ đoán ý thì năng lực người vừa CHỌN từ menu không bao giờ tới lượt.
        XCTAssertEqual(EidePanel.duongVao("/passport.query st.stm32f411"),
                       .moMan(id: "passport.query", thamSo: "st.stm32f411"))
        XCTAssertEqual(EidePanel.duongVao("/view.rag_ask I2C1 dùng chân nào?"),
                       .moMan(id: "view.rag_ask", thamSo: "I2C1 dùng chân nào?"))
        // `ápDungGoiY` để lại dấu cách cuối: "/doc.generate " — vẫn là mở màn, tham số rỗng.
        XCTAssertEqual(EidePanel.duongVao("/doc.generate "),
                       .moMan(id: "doc.generate", thamSo: ""))
    }

    func testDUONGDANgiuaCAUkhongBiHIEUlaLENH() {
        // "/" chỉ là lệnh khi ở ĐẦU dòng — `CommandBox.tienTo` đã theo quy tắc ấy cho menu gợi
        // ý, và đường vào phải theo cùng quy tắc, nếu không menu và hành động nói hai thứ khác
        // nhau về cùng một dòng chữ.
        XCTAssertEqual(EidePanel.duongVao("sửa giúp src/main.c"),
                       .chuoiViec("sửa giúp src/main.c"))
        XCTAssertEqual(EidePanel.duongVao("   "), .khongCoGi)
        XCTAssertEqual(EidePanel.duongVao("/"), .khongCoGi)
    }

    // MARK: - Cả ba đều có nhãn trợ năng

    func testBaKhungNhinDEUcoNhanTroNang() {
        // NFR-USE-03: đặt tên cho NHÓM, nếu không VoiceOver đọc ra một danh sách trôi nổi.
        for v in [PassportView() as NSView, RagAskView(), DocView()] {
            XCTAssertEqual(v.accessibilityRole(), .group)
            XCTAssertFalse((v.accessibilityLabel() ?? "").isEmpty)
        }
    }
}
