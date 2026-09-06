import XCTest
@testable import GEditorCore

/// Khai phá văn bản — FR-MIN-006.
final class TextMiningTests: XCTestCase {

    private func terms(_ r: TextMining.Report) -> [String] { r.terms.map(\.text) }

    private func find(_ r: TextMining.Report, _ text: String) -> TextMining.Term? {
        r.terms.first { $0.text == text }
    }

    // MARK: - n-gram

    func testDemDuocMotHaiVaBaAmTiet() {
        let r = TextMining.run("cơ sở dữ liệu lớn", config: .init(stopwords: []))
        XCTAssertTrue(terms(r).contains("cơ"))
        XCTAssertTrue(terms(r).contains("cơ sở"))
        XCTAssertTrue(terms(r).contains("cơ sở dữ"))
        XCTAssertFalse(terms(r).contains("cơ sở dữ liệu"), "maxN mặc định là 3")
    }

    func testMaxNbiKepVaoKhoang1toi3() {
        XCTAssertEqual(TextMining.Config(maxN: 9).maxN, 3)
        XCTAssertEqual(TextMining.Config(maxN: 0).maxN, 1)
    }

    /// Lọc stopword ở HAI ĐẦU, KHÔNG ở giữa: loại chúng trước khi ghép sẽ dựng ra những cụm
    /// chưa từng xuất hiện trong văn bản.
    func testStopwordLocOHAIDAUchuKhongOGIUA() {
        let r = TextMining.run("hệ thống của dữ liệu", config: .init(maxN: 3))
        // «của» ở giữa nên cụm ba âm tiết vẫn giữ nguyên hình dạng thật của câu.
        XCTAssertTrue(terms(r).contains("thống của dữ"), "\(terms(r))")
        // Nhưng KHÔNG được dựng ra cụm không có trong văn bản.
        XCTAssertFalse(terms(r).contains("hệ thống dữ liệu"))
        // Và cụm bắt đầu hoặc kết thúc bằng stopword thì bị loại.
        XCTAssertFalse(terms(r).contains("của"))
        XCTAssertFalse(terms(r).contains("hệ thống của"))
    }

    func testStopwordTuyBienDuocVaCoSanHaiThuTieng() {
        XCTAssertTrue(TextMining.defaultStopwords.contains("của"))
        XCTAssertTrue(TextMining.defaultStopwords.contains("the"))
        let r = TextMining.run("alpha beta", config: .init(stopwords: ["alpha"]))
        XCTAssertFalse(terms(r).contains("alpha"))
        XCTAssertTrue(terms(r).contains("beta"))
    }

    // MARK: - Từ ghép

    /// Mặc định TẮT: bật sẵn nghĩa là con số tần suất đổi theo một từ điển người dùng chưa từng
    /// thấy, và họ không có cách nào biết vì sao.
    func testGhepTuGhepMacDinhTAT() {
        let r = TextMining.run("cơ sở dữ liệu")
        XCTAssertTrue(r.methodology.contains("KHÔNG ghép từ ghép"), r.methodology)
    }

    func testGhepTuGhepKhiCoTuDien() {
        let tokens = TextMining.ghepTuGhep(["cơ", "sở", "dữ", "liệu", "lớn"],
                                           compounds: ["cơ sở dữ liệu"])
        XCTAssertEqual(tokens, ["cơ sở dữ liệu", "lớn"])
    }

    /// Cùng luật "khớp dài nhất thắng" của `EntityMarker`: có cả «cơ sở» lẫn «cơ sở dữ liệu» thì
    /// cụm dài phải thắng, nếu không nó bị cắt làm đôi và đếm thành hai từ.
    func testCumDAIthangCumNGAN() {
        let tokens = TextMining.ghepTuGhep(["cơ", "sở", "dữ", "liệu"],
                                           compounds: ["cơ sở", "cơ sở dữ liệu"])
        XCTAssertEqual(tokens, ["cơ sở dữ liệu"])
    }

    func testKhongCoTuDienThiTraNguyenVan() {
        let tokens = ["a", "b", "c"]
        XCTAssertEqual(TextMining.ghepTuGhep(tokens, compounds: []), tokens)
    }

    // MARK: - TF-IDF

    /// Từ xuất hiện ở MỌI tài liệu phải xếp dưới từ chỉ có ở một — đó là cả điểm của IDF.
    func testTuDacTrungXepTrenTuPhoBien() {
        let docs = ["báo cáo tài chính", "báo cáo nhân sự", "báo cáo bán hàng"]
        let r = TextMining.run(documents: docs, config: .init(maxN: 1, stopwords: []))
        let phoBien = find(r, "báo")!
        let dacTrung = find(r, "chính")!
        XCTAssertEqual(phoBien.documentCount, 3)
        XCTAssertEqual(dacTrung.documentCount, 1)
        // «báo» xuất hiện 3 lần nhưng ở cả 3 tài liệu; «chính» 1 lần ở 1 tài liệu.
        XCTAssertGreaterThan(dacTrung.tfidf / Double(dacTrung.count),
                             phoBien.tfidf / Double(phoBien.count),
                             "IDF không phạt từ có mặt ở mọi tài liệu")
    }

    /// IDF làm mượt: một corpus MỘT tài liệu không được cho ra cột TF-IDF toàn 0 — khi ấy bảng
    /// xếp hạng rỗng nghĩa và người dùng thấy một cột vô dụng.
    func testMotTaiLieuKhongChoRaCotTFIDFtoan0() {
        let r = TextMining.run("alpha beta alpha", config: .init(maxN: 1, stopwords: []))
        XCTAssertTrue(r.terms.allSatisfy { $0.tfidf > 0 }, "\(r.terms)")
    }

    /// Nhưng phải NÓI RA rằng cột ấy không phân biệt được gì — không để người đọc tưởng nó mang
    /// thông tin nó không mang.
    func testMotTaiLieuThiPHUONGPHAPnoiRaGioiHan() {
        let r = TextMining.run("alpha beta")
        XCTAssertTrue(r.methodology.contains("Chỉ MỘT tài liệu"), r.methodology)
    }

    func testKetQuaTATDINH() {
        let docs = ["a b c", "b c d"]
        let m = TextMining.run(documents: docs, config: .init(stopwords: []))
        let n = TextMining.run(documents: docs, config: .init(stopwords: []))
        XCTAssertEqual(terms(m), terms(n))
    }

    func testGioiHanSoTuKhoa() {
        let r = TextMining.run("a b c d e f g h", config: .init(stopwords: [], limit: 3))
        XCTAssertEqual(r.terms.count, 3)
    }

    // MARK: - Tokenizer dùng chung

    /// Nếu bảng từ khoá tách từ theo một luật và chỉ mục truy hồi tách theo luật khác, thì bấm
    /// một từ khoá sẽ tìm ra số kết quả khác con số vừa hiện trong bảng — mà không gì báo lỗi.
    func testDungCHUNGbotachVoiChiMucTruyHoi() {
        let text = "Nguyễn Văn An"
        let tuMining = TextMining.run(text, config: .init(maxN: 1, stopwords: [])).terms
            .map(\.text).sorted()
        let tuBM25 = Set(BM25Tokenizer().tokens(in: text)).sorted()
        XCTAssertEqual(tuMining, tuBM25)
        XCTAssertTrue(TextMining.run(text).methodology.contains(BM25Tokenizer.name))
    }

    // MARK: - Đầu ra

    func testXuatCSV() throws {
        let r = TextMining.run("alpha beta alpha", config: .init(maxN: 1, stopwords: []))
        let csv = TextMining.csv(r)
        XCTAssertTrue(csv.hasPrefix("tu_khoa,bac,tan_suat,so_tai_lieu,tfidf\n"))

        var soCot: [Int] = []
        try CSVEngine.forEachRow(in: TextBuffer(text: csv), dialect: .comma) { row in
            soCot.append(row.count); return true
        }
        XCTAssertEqual(Set(soCot), [5])
    }

    /// Đặc tả đòi kết quả dùng được làm đầu vào cho entity marker (FR-KNW-908).
    func testKetQuaDungDuocLamDauVaoChoEntityMarker() {
        let r = TextMining.run("cơ sở dữ liệu", config: .init(stopwords: []))
        let entities = TextMining.entities(r)
        XCTAssertFalse(entities.isEmpty)
        // Loại đặt theo BẬC nên entity marker tô ba màu, phân biệt cụm với từ đơn ngay trên trang.
        XCTAssertEqual(Set(entities.map(\.type)), ["1-gram", "2-gram", "3-gram"])

        // Và chúng khớp thật khi đem đi đánh dấu.
        let report = EntityMarker.find(entities, in: TextBuffer(text: "cơ sở dữ liệu"))
        XCTAssertFalse(report.occurrences.isEmpty)
    }

    func testVanBanRONGkhongNemLoi() {
        let r = TextMining.run("")
        XCTAssertTrue(r.terms.isEmpty)
        XCTAssertEqual(r.tokenCount, 0)
    }
}
