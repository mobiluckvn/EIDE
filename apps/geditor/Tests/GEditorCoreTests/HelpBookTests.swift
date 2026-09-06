import XCTest
@testable import GEditorCore

/// Bộ soát của chính cuốn sách trợ giúp.
///
/// Bài quan trọng nhất ở đây là `testSACHtiengVietKHONGcoLOInao` — nó chạy `problems()` trên bản
/// nội dung thật. Mọi bài còn lại tồn tại để chứng minh bộ soát ấy **đỏ được**: một bộ soát chỉ
/// biết nói "sạch" thì cũng nói "sạch" trên một cuốn sách gãy hết liên kết.
final class HelpBookTests: XCTestCase {

    // MARK: - Bản nội dung thật

    func testSACHtiengVietKHONGcoLOInao() {
        let problems = HelpContent.vietnamese.problems()
        XCTAssertEqual(problems, [], "Sách trợ giúp tiếng Việt tự mâu thuẫn:\n" + problems.joined(separator: "\n"))
    }

    func testTRANGvaoCUAcoTHAT() {
        XCTAssertNotNil(
            HelpContent.vietnamese.topic(id: HelpContent.entryTopicID),
            "Trang mở đầu \(HelpContent.entryTopicID) không có trong sách — menu Trợ giúp sẽ mở ra một cửa sổ trống"
        )
    }

    func testNGONNGUchuaDICHroiVEtiengVIET() {
        XCTAssertEqual(HelpContent.book(language: "de").language, "vi")
        XCTAssertFalse(HelpContent.isTranslated("de"))
        XCTAssertTrue(HelpContent.isTranslated("vi"))
    }

    // MARK: - Đối chứng âm: bộ soát phải ĐỎ được

    private func sach(_ topics: [HelpTopic]) -> HelpBook {
        HelpBook(language: "vi", chapters: [
            HelpChapter(id: "c", title: "Chương", summary: "Tóm tắt", topics: topics)
        ])
    }

    private func trang(
        id: String = "t", commands: [String] = [], blocks: [HelpBlock] = [.paragraph("Nội dung")]
    ) -> HelpTopic {
        HelpTopic(id: id, title: "Trang", summary: "Tóm tắt", commands: commands, blocks: blocks)
    }

    func testLIENKETchetBIbat() {
        let book = sach([trang(blocks: [.seeAlso(["khong-co-trang-nay"])])])
        XCTAssertTrue(
            book.problems().contains { $0.contains("khong-co-trang-nay") },
            "Bộ soát bỏ lọt một liên kết trỏ vào hư không"
        )
    }

    func testTRANGtroTOIchinhMINHbiBAT() {
        let book = sach([trang(id: "t", blocks: [.seeAlso(["t"])])])
        XCTAssertTrue(book.problems().contains { $0.contains("trỏ tới chính nó") })
    }

    func testMAtrangTRUNGbiBAT() {
        let book = sach([trang(id: "t"), trang(id: "t")])
        XCTAssertTrue(book.problems().contains { $0.contains("Mã trang trùng") })
    }

    func testBANGlechSOcotBIbat() {
        let book = sach([trang(blocks: [
            .table(headers: ["A", "B"], rows: [["1", "2"], ["3"]])
        ])])
        XCTAssertTrue(
            book.problems().contains { $0.contains("hàng 2 có 1 ô") },
            "Một hàng thiếu ô là lỗi đọc bằng mắt không thấy — bộ soát phải thấy"
        )
    }

    func testKHOImaKHONGcoNHANngonNGUbiBAT() {
        let book = sach([trang(blocks: [.code(language: "", caption: "", source: "abc")])])
        XCTAssertTrue(book.problems().contains { $0.contains("không có nhãn ngôn ngữ") })
    }

    func testKHOImaRONGbiBAT() {
        let book = sach([trang(blocks: [.code(language: "swift", caption: "", source: "  \n ")])])
        XCTAssertTrue(book.problems().contains { $0.contains("khối mã rỗng") })
    }

    func testTRANGrongBIbat() {
        let book = sach([trang(blocks: [])])
        XCTAssertTrue(book.problems().contains { $0.contains("rỗng") })
    }

    func testMAtrangVIETHOAbiBAT() {
        let book = sach([trang(id: "Trang-Hoa")])
        XCTAssertTrue(book.problems().contains { $0.contains("kebab-case") })
    }

    func testDAUlelNOItuyenBIbat() {
        let book = sach([trang(blocks: [.paragraph("Gõ `lệnh vào đây")])])
        XCTAssertTrue(
            book.problems().contains { $0.contains("dấu ` lẻ") },
            "Một dấu nháy ngược lẻ in nửa trang bằng phông mã, và chỉ lộ ra khi có người mở trang ấy"
        )
    }

    // MARK: - Phủ lệnh

    func testCOVEREDCOMMANDSgomHETcacTRANG() {
        let book = sach([
            trang(id: "a", commands: ["Lưu"]),
            trang(id: "b", commands: ["Mở…", "Lưu thành…"]),
        ])
        XCTAssertEqual(book.coveredCommands, ["Lưu", "Mở…", "Lưu thành…"])
        XCTAssertEqual(book.topic(forCommand: "Mở…")?.id, "b")
        XCTAssertNil(book.topic(forCommand: "Không có lệnh này"))
    }

    // MARK: - Tìm trong sách

    func testTIMgoKHONGdauRAchuCOdau() {
        let hits = HelpContent.vietnamese.search("bieu thuc chinh quy")
        XCTAssertEqual(
            hits.first?.topic.id, "bieu-thuc-chinh-quy",
            "Gõ không dấu phải ra đúng trang — cùng luật với ô lọc CSV"
        )
    }

    func testTIMtheoTENtrangXEPtruocTIMtrongTHANbai() {
        let hits = HelpContent.vietnamese.search("Macro")
        guard let first = hits.first else { return XCTFail("không tìm thấy gì") }
        XCTAssertTrue(
            TextFold.fold(first.topic.title).contains("macro"),
            "Trang có tên đúng chữ người ta gõ phải đứng trước trang chỉ nhắc tới nó"
        )
    }

    func testTIMtrongKHOImaMAU() {
        // Người dùng nhớ tên một khoá cấu hình thường xuyên hơn nhớ tên trang chứa nó.
        let hits = HelpContent.vietnamese.search("fail_under")
        XCTAssertFalse(hits.isEmpty, "Ô tìm phải soi cả khối mã mẫu")
    }

    func testTIMchuoiRONGtraVErong() {
        XCTAssertTrue(HelpContent.vietnamese.search("   ").isEmpty)
    }

    func testTIMkhongTHAYtraVErongCHUkhongTRAcaSACH() {
        XCTAssertTrue(HelpContent.vietnamese.search("zzzzzkhongcothat").isEmpty)
    }

    // MARK: - Ký hiệu nội tuyến

    func testTACHdoanTHEOkieu() {
        let runs = HelpInline.runs("Bấm **⌘S** rồi gõ `geditor --wait` là xong")
        XCTAssertEqual(runs, [
            .init("Bấm ", .plain),
            .init("⌘S", .strong),
            .init(" rồi gõ ", .plain),
            .init("geditor --wait", .code),
            .init(" là xong", .plain),
        ])
    }

    func testTRONGkhoiMAthiHAIdauSAOlaHAIdauSAO() {
        let runs = HelpInline.runs("Mẫu `\\d**` không phải chữ đậm")
        XCTAssertEqual(runs.filter { $0.style == .strong }, [])
        XCTAssertEqual(runs.first(where: { $0.style == .code })?.text, "\\d**")
    }

    func testPLAINTEXTboMOIkyHIEU() {
        XCTAssertEqual(
            HelpInline.plainText("Bấm **⌘S** rồi gõ `x`"), "Bấm ⌘S rồi gõ x"
        )
    }
}
