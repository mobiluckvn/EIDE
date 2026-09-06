import XCTest
@testable import GEditorCore

/// FR-KNW-926 — Golden Set Builder.
final class GoldenSetBuilderTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("golden-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private var path: String { (folder as NSString).appendingPathComponent("bo.golden.jsonl") }

    // MARK: - Ghi và nạp

    /// Ghi rồi nạp lại phải ra ĐÚNG những gì đã ghi.
    func testGHIRoiNapLaiRaDungDuLieu() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "hợp đồng lao động", relevantIDs: ["c1", "c2"],
                           note: "hai bản")
        try builder.append(question: "biên bản bàn giao", relevantIDs: ["c3"])

        let reloaded = try GoldenSetBuilder.load(path: path)
        XCTAssertEqual(reloaded.queries.map(\.id), ["q1", "q2"])
        XCTAssertEqual(reloaded.queries[0].question, "hợp đồng lao động")
        XCTAssertEqual(reloaded.queries[0].relevant, ["c1", "c2"])
        XCTAssertEqual(reloaded.queries[0].note, "hai bản")
        XCTAssertEqual(reloaded.queries[1].relevant, ["c3"])
    }

    /// Mỗi lần lưu là GHI THÊM một dòng, không viết lại cả tệp.
    ///
    /// Viết lại thì một lần lưu hỏng giữa chừng mất cả bộ đánh giá; ghi thêm thì mất đúng dòng
    /// đang ghi. Bài này chứng minh bằng cách đọc số dòng sau mỗi lần lưu.
    func testMOILANLUUChiThemMotDong() throws {
        var builder = GoldenSetBuilder(path: path)
        for index in 0 ..< 5 {
            try builder.append(question: "câu \(index)", relevantIDs: ["c\(index)"])
            let text = try String(contentsOfFile: path, encoding: .utf8)
            let lines = text.split(separator: "\n").count
            XCTAssertEqual(lines, index + 1)
        }
    }

    /// Tệp chưa có thì `load` trả bộ RỖNG gắn với đường dẫn ấy, không ném lỗi.
    func testTEPCHUACOThiRaBoRong() throws {
        let builder = try GoldenSetBuilder.load(path: path)
        XCTAssertTrue(builder.queries.isEmpty)
        XCTAssertEqual(builder.path, path)
    }

    /// Câu hỏi rỗng thì TỪ CHỐI — một record không có câu hỏi thì không đánh giá được gì.
    func testCAUHOIRONGThiTuChoi() {
        var builder = GoldenSetBuilder(path: path)
        XCTAssertThrowsError(try builder.append(question: "   ", relevantIDs: ["c1"]))
        XCTAssertTrue(builder.queries.isEmpty)
    }

    /// Chọn TRÙNG một chunk hai lần thì chỉ lưu MỘT, giữ nguyên thứ tự chọn.
    func testCHONTRUNGChiLuuMot() throws {
        var builder = GoldenSetBuilder(path: path)
        let query = try builder.append(question: "câu", relevantIDs: ["c2", "c1", "c2"])
        XCTAssertEqual(query.relevant, ["c2", "c1"])
    }

    // MARK: - `qid` ổn định và duy nhất

    /// `qid` sinh từ số CAO NHẤT đã có, không từ SỐ LƯỢNG record.
    ///
    /// `queries.count + 1` sẽ sinh ra `qid` TRÙNG sau khi xoá một record ở giữa — và lượt so
    /// sánh hai cấu hình ghép theo `qid` khi ấy chỉ thấy một trong hai, im lặng.
    func testQIDSinhTuSoCaoNhatKhongTuSoLuong() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "một", relevantIDs: ["c1"])
        try builder.append(question: "hai", relevantIDs: ["c2"])
        try builder.append(question: "ba", relevantIDs: ["c3"])
        builder.remove(id: "q2")
        let next = try builder.append(question: "bốn", relevantIDs: ["c4"])
        XCTAssertEqual(next.id, "q4")
        XCTAssertEqual(Set(builder.queries.map(\.id)).count, builder.queries.count,
                       "qid phải DUY NHẤT: \(builder.queries.map(\.id))")
    }

    // MARK: - Định dạng JSONL

    /// Thứ tự khoá CỐ ĐỊNH, không đi qua `JSONSerialization`.
    ///
    /// Bản của hệ thống sắp lại khoá theo băm, nên hai dòng cạnh nhau trong cùng một tệp có thể
    /// có thứ tự khoá khác nhau — diff của git khi ấy đầy những thay đổi giả.
    func testTHUTUKHOACoDinh() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "câu", relevantIDs: ["c1"], note: "ghi chú")
        let text = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            #"{"qid":"q1","question":"câu","relevant_ids":["c1"],"note":"ghi chú"}"#)
    }

    /// Không có ghi chú thì KHÔNG in khoá `note` — dòng ngắn hơn và không có ô rỗng vô nghĩa.
    func testKHONGGHICHUThiKhongInKhoa() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "câu", relevantIDs: ["c1"])
        let text = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertFalse(text.contains("note"))
    }

    /// Ký tự đặc biệt trong câu hỏi vẫn ra JSON hợp lệ.
    func testKYTUDACBIETVanRaJSONHopLe() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(
            question: "câu có \"nháy\" và \\ chéo\nvà xuống dòng", relevantIDs: ["c1"])
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let line = text.split(separator: "\n").first.map(String.init) ?? ""
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        XCTAssertEqual(object?["question"] as? String,
                       "câu có \"nháy\" và \\ chéo\nvà xuống dòng")
    }

    // MARK: - CSV

    func testXUATCSVVaNhapLai() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "câu một, có phẩy", relevantIDs: ["c1", "c2"])
        try builder.append(question: "câu hai", relevantIDs: ["c3"], note: "ghi chú")

        let csvPath = (folder as NSString).appendingPathComponent("bo.csv")
        try builder.csv().write(toFile: csvPath, atomically: true, encoding: .utf8)

        var empty = GoldenSetBuilder(
            path: (folder as NSString).appendingPathComponent("khac.jsonl"))
        let result = try empty.merge(from: csvPath)
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(empty.queries[0].question, "câu một, có phẩy")
        XCTAssertEqual(empty.queries[0].relevant, ["c1", "c2"])
        XCTAssertEqual(empty.queries[1].note, "ghi chú")
    }

    /// Nhập mà TRÙNG câu hỏi thì BỎ QUA và đếm, không ghi đè.
    ///
    /// Người nhập thường đang gộp việc của hai người, và ghi đè im lặng làm mất nhãn của một
    /// trong hai.
    func testNHAPTRUNGCauHoiThiBoQuaVaDem() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "hợp đồng", relevantIDs: ["c1"])

        let otherPath = (folder as NSString).appendingPathComponent("khac.jsonl")
        try #"""
            {"qid":"x1","question":"Hợp Đồng","relevant_ids":["c9"]}
            {"qid":"x2","question":"biên bản","relevant_ids":["c3"]}
            """#.write(toFile: otherPath, atomically: true, encoding: .utf8)

        let result = try builder.merge(from: otherPath)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1, "trùng câu hỏi (không phân biệt hoa thường) phải bỏ")
        XCTAssertEqual(builder.queries.count, 2)
        XCTAssertEqual(builder.queries[0].relevant, ["c1"], "nhãn cũ KHÔNG bị ghi đè")
        // `qid` của record nhập vào được đánh lại theo bộ đích, không giữ `x1`/`x2`.
        XCTAssertEqual(builder.queries[1].id, "q2")
    }

    // MARK: - Đếm phủ

    func testDEMPHUTheoNguon() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "một", relevantIDs: ["c1", "c2"])
        try builder.append(question: "hai", relevantIDs: ["c3"])
        try builder.append(question: "ba", relevantIDs: [])

        let sources = ["c1": "web", "c2": "web", "c3": "pdf"]
        let coverage = builder.coverage(
            sourceOf: { sources[$0] }, declaredSources: ["web", "pdf", "wiki"])

        XCTAssertEqual(coverage.total, 3)
        XCTAssertEqual(coverage.unlabeled, ["q3"])
        // Câu «một» chạm hai chunk nhưng CÙNG một nguồn → nguồn `web` chỉ đếm MỘT lần.
        XCTAssertEqual(coverage.bySource.map(\.source), ["pdf", "web"])
        XCTAssertEqual(coverage.bySource.map(\.count), [1, 1])
        XCTAssertEqual(coverage.missingSources, ["wiki"])
    }

    /// **Nguồn không có câu hỏi nào là lỗ hổng lớn nhất của một bộ đánh giá**, và nó vô hình
    /// nếu chỉ nhìn danh sách record.
    func testNGUONKhongCoCauHoiNaoDuocKeRa() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "một", relevantIDs: ["c1"])
        let coverage = builder.coverage(
            sourceOf: { ["c1": "web"][$0] },
            declaredSources: ["web", "pdf", "wiki", "email"])
        XCTAssertEqual(coverage.missingSources, ["pdf", "wiki", "email"])
        XCTAssertTrue(builder.summary(coverage).contains("thiếu: pdf, wiki, email"),
                      builder.summary(coverage))
    }

    func testIDKhongTraDuocNguonDuocDem() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "một", relevantIDs: ["c1", "khong-co"])
        let coverage = builder.coverage(sourceOf: { ["c1": "web"][$0] })
        XCTAssertEqual(coverage.unknownIDs, 1)
        XCTAssertTrue(builder.summary(coverage).contains("không tra được nguồn"))
    }

    func testCAUHOITRUNGDuocKeRa() throws {
        var builder = GoldenSetBuilder(path: path)
        try builder.append(question: "hợp đồng", relevantIDs: ["c1"])
        try builder.append(question: "  Hợp Đồng  ", relevantIDs: ["c2"])
        let coverage = builder.coverage(sourceOf: { _ in nil })
        XCTAssertEqual(coverage.duplicateQuestions, [["q1", "q2"]])
        XCTAssertTrue(builder.summary(coverage).contains("1 câu trùng"))
    }

    // MARK: - Đường ghép với FR-KNW-919

    /// Bộ dựng ra chạy được NGAY bằng bộ đánh giá của FR-KNW-919.
    ///
    /// Đây là chỗ hai cụm gặp nhau, và cũng là chỗ một khác biệt nhỏ về tên khoá sẽ hỏng: bộ
    /// dựng ghi `relevant_ids`, bộ nạp phải đọc đúng khoá ấy.
    func testBODUNGRaChayDuocNgayBangBoDanhGia() throws {
        // Corpus nhỏ, kỳ vọng tính tay.
        let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
        try """
            {"id":"c1","text":"hợp đồng mua bán nhà đất"}
            {"id":"c2","text":"hợp đồng lao động"}
            {"id":"c3","text":"biên bản bàn giao"}
            """.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)

        var builder = GoldenSetBuilder(path: GoldenSetBuilder.defaultPath(forCorpus: corpus))
        try builder.append(question: "hợp đồng", relevantIDs: ["c1", "c2"])

        let golden = try RetrievalEval.loadGoldenSet(path: builder.path)
        let report = RetrievalEval.run(
            index: index, golden: golden, k: 3, identifierMap: try index.identifierMap())
        XCTAssertEqual(report.summary.recall, 1, accuracy: 1e-12)
        XCTAssertEqual(report.summary.scoredCount, 1)
    }

    /// Tệp mặc định nằm CẠNH corpus — hai tệp ấy chỉ có nghĩa cùng nhau.
    func testTEPMACDINHNamCanhCorpus() {
        XCTAssertEqual(
            GoldenSetBuilder.defaultPath(forCorpus: "/a/b/chunks.jsonl"),
            "/a/b/chunks.golden.jsonl")
    }
}
