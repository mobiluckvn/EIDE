import XCTest
@testable import GEditorCore

/// FR-KNW-918 · FR-KNW-919 — Retrieval Lab và đánh giá golden set.
final class RetrievalEvalTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("eval-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    /// Corpus nhỏ, mọi kỳ vọng suy từ chính nó bằng cách tính tay.
    private func makeIndex(
        _ lines: [String] = [
            #"{"id":"c1","text":"hợp đồng mua bán nhà đất"}"#,
            #"{"id":"c2","text":"hợp đồng lao động"}"#,
            #"{"id":"c3","text":"biên bản bàn giao nhà"}"#,
            #"{"id":"c4","text":"thời tiết đà lạt mùa hè"}"#,
        ],
        options: BM25Index.Options = .init()
    ) throws -> BM25Index {
        let path = folder + "/corpus.jsonl"
        try (lines.joined(separator: "\n") + "\n").write(
            toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: path))
        return try BM25Index.build(corpus: path, options: options)
    }

    private func write(_ text: String, name: String) throws -> String {
        let path = folder + "/" + name
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Nạp golden set

    func testNAPJSONLDuDangKhoa() throws {
        let path = try write("""
            {"qid":"q1","question":"hợp đồng","relevant_ids":["c1","c2"],"note":"hai bản"}
            {"query":"nhà","expected":["c1","c3"]}

            {"cau_hoi":"đà lạt","ids":"c4"}
            """, name: "golden.jsonl")
        let golden = try RetrievalEval.loadGoldenSet(path: path)
        XCTAssertEqual(golden.count, 3)
        XCTAssertEqual(golden[0].id, "q1")
        XCTAssertEqual(golden[0].relevant, ["c1", "c2"])
        XCTAssertEqual(golden[0].note, "hai bản")
        XCTAssertEqual(golden[1].question, "nhà")
        XCTAssertEqual(golden[1].id, "q2", "thiếu qid thì đánh số theo DÒNG")
        XCTAssertEqual(golden[2].relevant, ["c4"], "id dạng chuỗi cũng nhận")
    }

    /// CSV: id ngăn nhau bằng `;` hoặc `|`, KHÔNG phải `,`.
    func testNAPCSVNganIdBangChamPhayHoacGachDoc() throws {
        let path = try write("""
            qid,question,relevant_ids
            q1,hợp đồng,c1;c2
            q2,nhà,c1|c3
            """, name: "golden.csv")
        let golden = try RetrievalEval.loadGoldenSet(path: path)
        XCTAssertEqual(golden.map(\.id), ["q1", "q2"])
        XCTAssertEqual(golden[0].relevant, ["c1", "c2"])
        XCTAssertEqual(golden[1].relevant, ["c1", "c3"])
    }

    /// Thiếu cột thì báo lỗi NÓI RA tên cột nhận được, không báo "định dạng sai".
    func testTHIEUCOTThiBaoRoTenCotNhanDuoc() throws {
        let path = try write("a,b\n1,2\n", name: "hong.csv")
        XCTAssertThrowsError(try RetrievalEval.loadGoldenSet(path: path)) { error in
            let message = (error as? RetrievalEval.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("question"), message)
        }
    }

    // MARK: - Chỉ số, tính tay

    /// Ba chỉ số trên MỘT câu, tính tay từng bước.
    ///
    /// Corpus: c1 «hợp đồng mua bán nhà đất» · c2 «hợp đồng lao động» · c3 «biên bản bàn giao
    /// nhà» · c4 «thời tiết đà lạt mùa hè». Câu hỏi «hợp đồng» chỉ khớp c1 và c2.
    ///
    /// Kỳ vọng {c1, c2}, k = 4. Cả hai đều nằm trong top-4 nên:
    ///   recall = 2 ÷ 2 = 1
    ///   MRR    = 1 ÷ 1 = 1 (kết quả đúng đầu tiên ở hạng 1)
    ///   nDCG   = (1÷log₂2 + 1÷log₂3) ÷ (1÷log₂2 + 1÷log₂3) = 1
    func testBACHISOTrenMotCauTinhTay() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [.init(id: "q1", question: "hợp đồng", relevant: ["c1", "c2"])],
            k: 4, identifierMap: map)
        XCTAssertEqual(report.summary.recall, 1, accuracy: 1e-12)
        XCTAssertEqual(report.summary.mrr, 1, accuracy: 1e-12)
        XCTAssertEqual(report.summary.ndcg, 1, accuracy: 1e-12)
        XCTAssertEqual(report.queries[0].firstHitRank, 1)
    }

    /// Một id kỳ vọng KHÔNG khớp câu hỏi: recall xuống 1/2, nDCG xuống theo công thức.
    ///
    /// Kỳ vọng {c1, c4}, câu hỏi «hợp đồng». c1 ở hạng 1 hoặc 2; c4 không khớp gì nên không có
    /// trong kết quả. Vậy:
    ///   recall = 1 ÷ 2 = 0,5
    ///   MRR    = 1 ÷ hạng(c1)
    ///   nDCG   = (1÷log₂(hạng+1)) ÷ (1÷log₂2 + 1÷log₂3)
    func testMOTIDKhongKhopThiChiSoGiamDungCongThuc() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [.init(id: "q1", question: "hợp đồng", relevant: ["c1", "c4"])],
            k: 4, identifierMap: map)
        let rank = try XCTUnwrap(report.queries[0].firstHitRank)
        XCTAssertEqual(report.summary.recall, 0.5, accuracy: 1e-12)
        XCTAssertEqual(report.summary.mrr, 1 / Double(rank), accuracy: 1e-12)
        let ideal = 1 / log2(2.0) + 1 / log2(3.0)
        XCTAssertEqual(report.summary.ndcg,
                       (1 / log2(Double(rank) + 1)) / ideal, accuracy: 1e-12)
    }

    /// Không kết quả đúng nào trong top-k thì cả ba chỉ số bằng 0 — nhưng câu VẪN được chấm.
    func testKHONGCHAMDUOCKetQuaNaoThiBangKhongChuKhongPhaiLoai() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [.init(id: "q1", question: "đà lạt", relevant: ["c2"])],
            k: 2, identifierMap: map)
        XCTAssertEqual(report.summary.scoredCount, 1)
        XCTAssertEqual(report.summary.recall, 0, accuracy: 1e-12)
        XCTAssertEqual(report.summary.mrr, 0, accuracy: 1e-12)
        XCTAssertEqual(report.summary.ndcg, 0, accuracy: 1e-12)
        XCTAssertNil(report.queries[0].excludedReason)
    }

    /// Đống cỡ k trả về ĐÚNG k tài liệu tốt nhất — đối chứng với phép sắp vét cạn.
    ///
    /// Bài này canh phép tối ưu đã thay `search`: bản đầu cộng điểm vào từ điển rồi SẮP TOÀN BỘ
    /// tài liệu chạm được; bản mới cộng vào mảng dày rồi lấy top-k bằng đống. Nhanh hơn một
    /// bậc trên corpus lớn, nhưng một cái đống viết sai vẫn trả về "mười kết quả trông hợp lý".
    ///
    /// **Giới hạn của chính bài này:** bản "vét cạn" ở đây gọi `search` với k rất lớn, tức nó
    /// đi qua CÙNG phép so. Nên nó bắt được lỗi cấu trúc đống (đã thử: phá `siftDown` thì đỏ)
    /// nhưng KHÔNG bắt được lỗi trong luật phá hoà — đổi `left < right` thành `left > right`
    /// thì bài này vẫn xanh. Luật phá hoà do `testDIEMBANGNHAUThiTatDinh` bên
    /// `BM25IndexTests` canh, và đã kiểm là nó ĐỎ đúng chỗ.
    func testDONGCoKTraDungKTaiLieuTotNhat() throws {
        // Corpus có nhiều tài liệu cùng chứa từ khoá, độ dài rất khác nhau → điểm rải đều.
        var lines: [String] = []
        for index in 0 ..< 120 {
            let repeats = (index % 7) + 1
            let filler = String(repeating: "chữ đệm ", count: index % 11)
            lines.append(#"{"id":"c\#(index)","text":"\#(String(repeating: "hợp đồng ", count: repeats))\#(filler)"}"#)
        }
        let index = try makeIndex(lines)
        let all = index.search("hợp đồng", k: 1_000)
        XCTAssertGreaterThan(all.count, 40, "corpus bài kiểm phải chạm nhiều tài liệu")

        for k in [1, 3, 10, 25] {
            let top = index.search("hợp đồng", k: k)
            XCTAssertEqual(top.count, min(k, all.count))
            XCTAssertEqual(top.map(\.document), Array(all.prefix(k)).map(\.document),
                           "top-\(k) lệch với phép sắp vét cạn")
            for (a, b) in zip(top, all.prefix(k)) {
                XCTAssertEqual(a.score, b.score, accuracy: 1e-12)
            }
        }
    }

    /// Câu hỏi toàn từ PHỔ BIẾN — ca mà bộ đo cũ không chạm tới.
    ///
    /// Bộ đo PoC-M báo "truy vấn 1,0 ms" và con số ấy đúng, nhưng nó đo bằng câu hỏi gồm từ
    /// HIẾM. Câu hỏi thật lấy từ chính văn bản thì toàn từ phổ biến, và ca ấy chạm tới gần như
    /// mọi tài liệu — chỗ mà bản dùng từ điển tốn 346 ms một câu.
    func testCAUHOITuPhoBienVanTraDungKetQua() throws {
        var lines: [String] = []
        for index in 0 ..< 200 {
            lines.append(#"{"id":"c\#(index)","text":"hợp đồng số \#(index) của bên A"}"#)
        }
        let index = try makeIndex(lines)
        let hits = index.search("hợp đồng của bên", k: 5)
        XCTAssertEqual(hits.count, 5)
        // Mọi tài liệu đều chứa cả bốn từ, nên điểm chỉ khác nhau theo ĐỘ DÀI — và hoà thì
        // tài liệu số hiệu nhỏ hơn thắng.
        let scores = hits.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
        XCTAssertEqual(Set(hits[0].matchedTerms), Set(["hợp", "đồng", "của", "bên"]))
    }

    // MARK: - Ba cái bẫy của một con số đánh giá

    /// **Bẫy 1.** Id kỳ vọng không có trong corpus thì câu bị LOẠI khỏi trung bình, không tính 0.
    ///
    /// Tính 0 thì một bộ đánh giá trỏ vào corpus cũ sẽ cho điểm thấp trông như "BM25 dở", trong
    /// khi thật ra là "bộ đánh giá hỏng" — và không có gì trên màn hình chỉ ra khác biệt ấy.
    func testIDKhongCoTrongCorpusThiLoaiKhoiTrungBinhChuKhongTinh0() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [
                .init(id: "q1", question: "hợp đồng", relevant: ["c1"]),
                .init(id: "q2", question: "nhà", relevant: ["khong-ton-tai"]),
            ],
            k: 4, identifierMap: map)
        XCTAssertEqual(report.summary.queryCount, 2)
        XCTAssertEqual(report.summary.scoredCount, 1, "câu có id lạc phải bị LOẠI")
        XCTAssertEqual(report.summary.recall, 1, accuracy: 1e-12)
        XCTAssertEqual(report.summary.missingIDCount, 1)
        // Và nó phải nằm TRÊN CÙNG danh sách: sửa bộ đánh giá trước, rồi mới đọc số.
        XCTAssertEqual(report.queries[0].query.id, "q2")
        XCTAssertEqual(report.queries[0].missingIDs, ["khong-ton-tai"])
        XCTAssertNotNil(report.queries[0].excludedReason)
    }

    /// **Bẫy 2.** Một id ứng với NHIỀU tài liệu: chạm bất kỳ cái nào là chạm được id, và chỉ
    /// tính MỘT lần.
    ///
    /// Không thế thì một corpus nhân bản chunk lên ba lần sẽ có recall cao hơn mà không truy
    /// hồi tốt hơn chút nào.
    func testIDTrungNhieuTaiLieuChiTinhMotLan() throws {
        let index = try makeIndex([
            #"{"id":"c1","text":"hợp đồng mua bán nhà đất"}"#,
            #"{"id":"c1","text":"hợp đồng mua bán nhà đất bản sao"}"#,
            #"{"id":"c1","text":"hợp đồng mua bán nhà đất bản ba"}"#,
            #"{"id":"c9","text":"thời tiết đà lạt"}"#,
        ])
        let map = try index.identifierMap()
        XCTAssertEqual(map["c1"]?.count, 3, "tiền đề: id c1 ứng với ba tài liệu")
        let report = RetrievalEval.run(
            index: index,
            golden: [.init(id: "q1", question: "hợp đồng", relevant: ["c1"])],
            k: 4, identifierMap: map)
        XCTAssertEqual(report.queries[0].hitCount, 1, "ba tài liệu cùng id vẫn chỉ là MỘT id")
        XCTAssertEqual(report.summary.recall, 1, accuracy: 1e-12)
    }

    /// **Bẫy 3.** `k` nhỏ hơn số id kỳ vọng thì recall có TRẦN toán học, và trần ấy phải hiện ra.
    func testKNhoHonSoIDKyVongThiTranDuocNoiRa() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [.init(id: "q1", question: "hợp đồng nhà", relevant: ["c1", "c2", "c3"])],
            k: 1, identifierMap: map)
        // Trần = min(k, số id) ÷ số id = 1 ÷ 3
        XCTAssertEqual(report.summary.ceiling, 1.0 / 3, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(report.summary.recall, report.summary.ceiling + 1e-12)
    }

    // MARK: - Sắp xếp và so sánh

    /// Câu TỆ NHẤT lên trước — đặc tả đòi "để sửa corpus có trọng tâm".
    func testCAUTENHATLenTruoc() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let report = RetrievalEval.run(
            index: index,
            golden: [
                .init(id: "tot", question: "hợp đồng", relevant: ["c1", "c2"]),
                .init(id: "te", question: "đà lạt", relevant: ["c1"]),
                .init(id: "vua", question: "nhà", relevant: ["c1", "c3"]),
            ],
            k: 4, identifierMap: map)
        XCTAssertEqual(report.queries.first?.query.id, "te")
        let recalls = report.queries.compactMap(\.recall)
        XCTAssertEqual(recalls, recalls.sorted(), "phải TĂNG dần, tức tệ nhất trước")
    }

    /// So hai cấu hình ghép theo `Query.id`, KHÔNG theo vị trí.
    ///
    /// Cả hai lượt đều sắp tệ-nhất-trước, nên ghép theo vị trí sẽ so nhầm câu với câu — và con
    /// số delta khi ấy vô nghĩa mà vẫn trông hợp lý.
    func testSOHAICAUHINHGhepTheoIdKhongTheoViTri() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let golden: [RetrievalEval.Query] = [
            .init(id: "q1", question: "hợp đồng", relevant: ["c1", "c2"]),
            .init(id: "q2", question: "đà lạt", relevant: ["c4"]),
        ]
        let first = RetrievalEval.run(index: index, golden: golden, k: 4, identifierMap: map)
        let second = RetrievalEval.run(index: index, golden: golden, k: 1, identifierMap: map)
        let comparison = RetrievalEval.compare(first, second)
        for row in comparison.rows {
            let left = first.queries.first { $0.query.id == row.query.id }?.recall
            let right = second.queries.first { $0.query.id == row.query.id }?.recall
            XCTAssertEqual(row.left, left)
            XCTAssertEqual(row.right, right)
        }
        // Cấu hình k = 1 không thể tốt hơn k = 4 trên cùng bộ đánh giá.
        XCTAssertLessThanOrEqual(comparison.recallDelta, 1e-12)
    }

    /// Huỷ giữa chừng trả kết quả dùng được kèm cờ.
    func testHUYGiuaChungTraKetQuaKemCo() throws {
        let index = try makeIndex()
        let map = try index.identifierMap()
        let golden = (0 ..< 200).map {
            RetrievalEval.Query(id: "q\($0)", question: "hợp đồng", relevant: ["c1"])
        }
        let token = CancelToken()
        let report = RetrievalEval.run(
            index: index, golden: golden, k: 4, identifierMap: map, cancelToken: token
        ) { _ in token.cancel(); return true }
        XCTAssertTrue(report.wasCancelled)
        XCTAssertLessThan(report.summary.queryCount, 200)
    }

    // MARK: - Nền của FR-KNW-918

    /// Bản đồ định danh đọc corpus MỘT lượt và giữ đúng thứ tự tài liệu.
    func testBANDODINHDANHDungThuTuTaiLieu() throws {
        let index = try makeIndex()
        XCTAssertEqual(try index.identifiers(), ["c1", "c2", "c3", "c4"])
        XCTAssertEqual(try index.identifierMap()["c3"], [2])
    }

    /// Bản ghi thiếu trường định danh nhận chuỗi RỖNG chứ không bị bỏ qua.
    ///
    /// Bỏ qua thì mọi số hiệu phía sau lệch một, và bản đồ định danh trỏ sai — im lặng.
    func testBANGHIThieuDinhDanhVanGiuCho() throws {
        let index = try makeIndex([
            #"{"id":"c1","text":"hợp đồng mua bán"}"#,
            #"{"text":"không có id"}"#,
            #"{"id":"c3","text":"biên bản bàn giao"}"#,
        ])
        XCTAssertEqual(try index.identifiers(), ["c1", "", "c3"])
        XCTAssertEqual(try index.identifierMap()["c3"], [2])
    }

    /// Tô sáng đúng những chỗ mà BỘ TÁCH TOKEN cắt ra token khớp — FR-KNW-918.
    ///
    /// Không phải tìm chuỗi con: tìm chuỗi con sẽ tô sáng một chỗ mà điểm BM25 không hề tính
    /// tới, và người dùng sẽ đọc bảng điểm sai.
    func testTOSANGTheoTokenKhongTheoChuoiCon() throws {
        let index = try makeIndex()
        let text = "Hợp đồng mua bán nhà, hợp-đồng số 12"
        let ranges = index.highlights(in: text, terms: ["hợp", "đồng"])
        let utf16 = Array(text.utf16)
        let words = ranges.map { String(decoding: utf16[$0], as: UTF16.self) }
        XCTAssertEqual(words, ["Hợp", "đồng", "hợp", "đồng"])
    }

    /// Offset trả về là UTF-16 — dùng thẳng được cho `NSRange`.
    func testVITRITOSANGLaOffsetUTF16() throws {
        let index = try makeIndex()
        // Emoji ngoài mặt phẳng cơ bản chiếm HAI đơn vị UTF-16.
        let text = "🙂 hợp đồng"
        let ranges = index.highlights(in: text, terms: ["hợp"])
        XCTAssertEqual(ranges.count, 1)
        let utf16 = Array(text.utf16)
        XCTAssertEqual(String(decoding: utf16[ranges[0]], as: UTF16.self), "hợp")
        XCTAssertEqual(ranges[0].lowerBound, 3, "🙂 chiếm 2 đơn vị, dấu cách 1")
    }

    /// Từ KHÔNG khớp thì không sáng.
    func testTUKHONGKHOPThiKhongSang() throws {
        let index = try makeIndex()
        XCTAssertTrue(index.highlights(in: "biên bản bàn giao", terms: ["hợp"]).isEmpty)
    }
}

// MARK: - Khối ```retrieval trong .greport.md

/// FR-KNW-919 — vế "báo cáo đánh giá tái lập được".
final class RetrievalBlockTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("retblock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try """
            {"id":"c1","text":"hợp đồng mua bán nhà đất"}
            {"id":"c2","text":"hợp đồng lao động"}
            {"id":"c3","text":"biên bản bàn giao nhà"}
            {"id":"c4","text":"thời tiết đà lạt mùa hè"}
            """.write(toFile: folder + "/chunks.jsonl", atomically: true, encoding: .utf8)
        try """
            {"qid":"q1","question":"hợp đồng","relevant_ids":["c1","c2"]}
            {"qid":"q2","question":"đà lạt","relevant_ids":["c4"]}
            {"qid":"q3","question":"nhà","relevant_ids":["c1","khong-ton-tai"]}
            """.write(toFile: folder + "/golden.jsonl", atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func render(_ text: String) throws -> ReportRenderer.Rendered {
        try ReportRenderer.render(
            try ReportDocument.parse(text),
            in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
            options: ReportRenderer.Options(basePath: folder))
    }

    func testKHOIDOIDuCorpusVaGolden() {
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("golden: g.jsonl"))
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("corpus: c.jsonl"))
    }

    /// `compare` khai những gì KHÁC, phần còn lại KẾ THỪA.
    ///
    /// Bắt khai lại toàn bộ hai cấu hình thì hai bên sẽ lệch nhau ở một khoá nào đó mà không ai
    /// để ý, và bảng delta khi ấy đo hai thứ khác nhau.
    func testCOMPAREKeThuaPhanKhongKhai() throws {
        let spec = try RetrievalBlockSpec.parse("""
            corpus: chunks.jsonl
            golden: golden.jsonl
            text_field: noi_dung
            k1: 1.2
            compare:
              k1: 1.6
            """)
        XCTAssertEqual(spec.compare?.k1, 1.6)
        XCTAssertEqual(spec.compare?.b, spec.options.b, "b phải KẾ THỪA")
        XCTAssertEqual(spec.compare?.textField, "noi_dung", "trường văn bản phải KẾ THỪA")
    }

    func testCOMPAREChiDoiDuocThamSoTruyHoi() {
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("""
            corpus: c.jsonl
            golden: g.jsonl
            compare:
              corpus: khac.jsonl
            """)) { error in
            let message = (error as? RetrievalBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("compare"), message)
        }
    }

    func testNGUONGSAIThiBaoLoiChuKhongNhanBua() {
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("corpus: c\ngolden: g\nb: 2"))
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("corpus: c\ngolden: g\nk: 0"))
        XCTAssertThrowsError(
            try RetrievalBlockSpec.parse("corpus: c\ngolden: g\nfail_under: 80"))
    }

    /// Đường ghép đầy đủ: dựng báo cáo thật.
    func testDUNGBAOCAOThatRaBangChiSo() throws {
        let result = try render("""
            # Đánh giá

            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            k: 4
            title: Đánh giá truy hồi
            ```
            """)
        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("Đánh giá truy hồi"))
        XCTAssertTrue(result.html.contains("recall@4"))
        XCTAssertTrue(result.html.contains("MRR"))
        XCTAssertTrue(result.html.contains("nDCG@4"))
        // Công thức phải in ra — NFR-DQR-03.
        XCTAssertTrue(result.html.contains("log₂"), "thiếu công thức nDCG")
        // Id lạc phải được nói ra NGAY, không giấu.
        XCTAssertTrue(result.html.contains("khong-ton-tai"), "id lạc phải được kể tên")
        XCTAssertTrue(result.html.contains("lỗi của bộ đánh giá"))
    }

    /// So hai cấu hình ra bảng delta, và tên hai cấu hình phải in ra.
    func testSOHAICAUHINHRaBangDelta() throws {
        let result = try render("""
            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            k: 2
            compare:
              b: 0
            ```
            """)
        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("Cấu hình 2"))
        XCTAssertTrue(result.html.contains("b=0"), "cấu hình so phải in ra tham số của nó")
    }

    /// `fail_under` cảnh báo và làm CLI trả mã khác 0.
    func testFAILUNDERCanhBaoKhiRecallThap() throws {
        let result = try render("""
            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            k: 1
            fail_under: 0.99
            ```
            """)
        XCTAssertFalse(result.qualityAlerts.isEmpty, "phải cảnh báo khi dưới ngưỡng")
        XCTAssertTrue(result.qualityAlerts[0].message.contains("DƯỚI ngưỡng"))
    }

    // MARK: - Điểm ngoài (FR-KNW-921)

    /// Một khối so ĐÚNG MỘT cặp.
    func testKHAICaCompareLanExternalThiTuChoi() {
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("""
            corpus: c.jsonl
            golden: g.jsonl
            compare:
              b: 0
            external: diem.jsonl
            """)) { error in
            let message = (error as? RetrievalBlockSpec.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("một khối so đúng một cặp"), message)
        }
    }

    func testEXTERNALORDERPhaiHopLeVaCoNghia() {
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("""
            corpus: c.jsonl
            golden: g.jsonl
            external: diem.jsonl
            external_order: lung-tung
            """))
        // Khai chiều mà không khai tệp thì vô nghĩa — nói ra chứ không bỏ qua.
        XCTAssertThrowsError(try RetrievalBlockSpec.parse("""
            corpus: c.jsonl
            golden: g.jsonl
            external_order: ascending
            """))
    }

    /// **Cả thẻ chạy trên PHẦN GIAO**, và số câu bị loại được nói ra.
    ///
    /// Bộ đánh giá có q1/q2/q3; tệp ngoài chỉ có hai câu đầu. Nếu ô điểm lớn ở đầu thẻ vẫn tính
    /// trên cả ba câu thì chính tấm thẻ ấy đang trộn hai tập câu hỏi.
    func testEXTERNALCatVePhanGiaoVaNoiRaSoCauBiLoai() throws {
        try """
            {"query":"hợp đồng","chunk_id":"c1","score":0.9}
            {"query":"hợp đồng","chunk_id":"c2","score":0.5}
            {"query":"đà lạt","chunk_id":"c4","score":0.8}
            """.write(toFile: folder + "/diem.jsonl", atomically: true, encoding: .utf8)
        let result = try render("""
            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            k: 2
            external: diem.jsonl
            ```
            """)
        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("2 câu hỏi"), "phải chấm trên phần giao")
        XCTAssertTrue(result.html.contains("So trên 2 câu"), result.html.prefix(400).description)
        XCTAssertTrue(result.html.contains("1 câu của bộ đánh giá KHÔNG có trong tệp ngoài"))
        XCTAssertTrue(result.html.contains("Điểm ngoài"), "đầu đề cột phải nói đúng hai HỆ")
        XCTAssertTrue(result.html.contains("KHÔNG tính vector"), "ranh giới ADR-11 phải in ra")
        // Biểu đồ so hai hệ — đặc tả đòi "chart so recall@k/MRR hai hệ".
        XCTAssertTrue(result.html.contains("g-chart"), "thiếu biểu đồ so hai hệ")
    }

    /// Id của tệp ngoài mà corpus không có: dấu hiệu HAI BẢN CORPUS khác nhau.
    func testEXTERNALIDLacThiCanhBaoHaiBanCorpus() throws {
        try """
            {"query":"hợp đồng","chunk_id":"ban-cu-001","score":0.9}
            {"query":"đà lạt","chunk_id":"c4","score":0.8}
            """.write(toFile: folder + "/diem.jsonl", atomically: true, encoding: .utf8)
        let result = try render("""
            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            external: diem.jsonl
            ```
            """)
        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("hai bản corpus khác nhau"), "phải cảnh báo")
        XCTAssertTrue(result.html.contains("ban-cu-001"), "phải kể tên id lạc")
    }

    /// Không ghép được câu nào thì khối HỎNG kèm gợi ý, không ra một bảng 0 điểm.
    func testEXTERNALKhongGhepDuocThiHongKemGoiY() throws {
        try """
            {"query":"hợp đồng?","chunk_id":"c1","score":0.9}
            """.write(toFile: folder + "/diem.jsonl", atomically: true, encoding: .utf8)
        let result = try render("""
            ```retrieval
            corpus: chunks.jsonl
            golden: golden.jsonl
            external: diem.jsonl
            ```
            """)
        XCTAssertEqual(result.failures.count, 1)
        let message = result.failures[0].message
        XCTAssertTrue(message.contains("ghép theo CÂU HỎI"), message)
        XCTAssertTrue(message.contains("hợp đồng?"), message)
    }

    /// Tệp thiếu thì khối HỎNG có chỗ nhảy, không làm hỏng cả báo cáo.
    func testTEPTHIEUThiKhoiHongChuKhongPhaiCaBaoCao() throws {
        let result = try render("""
            ```retrieval
            corpus: khong-co.jsonl
            golden: golden.jsonl
            ```

            Văn xuôi phía sau vẫn phải còn.
            """)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.html.contains("Văn xuôi phía sau vẫn phải còn"))
        // **Câu lỗi phải là câu TIẾNG VIỆT của khối**, không phải câu mặc định của Foundation.
        // Trước FR-KNW-921 mọi lỗi khối retrieval hiện ra thành «The operation couldn't be
        // completed» vì bảng ánh xạ lỗi thiếu bốn dòng; bài kiểm cũ chỉ ĐẾM số lỗi nên không ai
        // thấy.
        XCTAssertTrue(result.failures[0].message.contains("khong-co.jsonl"),
                      result.failures[0].message)
        XCTAssertFalse(result.failures[0].message.contains("operation"),
                       result.failures[0].message)
    }
}
