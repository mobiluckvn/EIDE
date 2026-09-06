import XCTest
@testable import GEditorCore

/// FR-KNW-922 — Chunk Quality Report.
final class ChunkQualityTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("chunkq-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func write(_ lines: [String], name: String = "chunks.jsonl") throws -> String {
        let path = folder + "/" + name
        try lines.joined(separator: "\n").write(
            toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    private func record(_ text: String, id: String, source: String = "") -> String {
        var object: [String: Any] = ["id": id, "text": text]
        if !source.isEmpty { object["source"] = source }
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }

    private func value(
        _ report: ChunkQuality.Report, _ dimension: QualityRules.Dimension
    ) -> Double? {
        report.score.dimensions.first { $0.dimension == dimension }?.value
    }

    private func note(
        _ report: ChunkQuality.Report, _ dimension: QualityRules.Dimension
    ) -> String? {
        report.score.dimensions.first { $0.dimension == dimension }?.note
    }

    // MARK: - (a) Phân bố token

    /// Bốn chunk, ngưỡng 5…10 âm tiết. Đếm tay: 3 · 12 · 7 · 4 âm tiết.
    func testNGUONGTOKENDemDungSoVuotVaSoQuaNgan() throws {
        let path = try write([
            record("một hai ba", id: "a"),
            record("một hai ba bốn năm sáu bảy tám chín mười mười một mười hai", id: "b"),
            record("một hai ba bốn năm sáu bảy", id: "c"),
            record("một hai ba bốn", id: "d"),
        ])
        let report = try ChunkQuality.run(
            corpus: path, config: .init(maxTokens: 10, minTokens: 5))

        XCTAssertEqual(report.chunkCount, 4)
        XCTAssertEqual(report.chunks.map(\.tokens), [3, 14, 7, 4])
        XCTAssertEqual(report.overLimit.map(\.id), ["b"])
        XCTAssertEqual(report.underLimit.map(\.id), ["a", "d"])
        // 100 × (4 − 1 vượt − 2 quá ngắn) ÷ 4 = 25
        XCTAssertEqual(value(report, .validity) ?? -1, 25, accuracy: 1e-9)
    }

    /// Không khai ngưỡng nào thì chiều HỢP LỆ **không chấm được** — không phải 100.
    ///
    /// Đây là luật đắt nhất của khung FR-DQR và cũng là luật dễ mất nhất: một corpus chưa khai
    /// ngưỡng model mà được cho 100 điểm "hợp lệ" là một điểm số nói dối theo hướng có lợi.
    func testKHONGKHAINGUONGThiKhongChamChuKhongPhaiChoDiem100() throws {
        let path = try write([record("một hai ba", id: "a")])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertNil(value(report, .validity))
        XCTAssertEqual(
            note(report, .validity)?.contains("max_tokens"), true, "\(note(report, .validity) ?? "")")
    }

    /// Tỉ lệ ký tự/token do NGƯỜI DÙNG khai, và nó được in ra trong `detail`.
    func testUOCLUONGTHEOKYTUNoiRaTiLeDaDung() throws {
        let path = try write([record("mười hai ký tự nhé", id: "a")])
        let report = try ChunkQuality.run(
            corpus: path, config: .init(maxTokens: 3, estimator: .characters(perToken: 4)))
        // "mười hai ký tự nhé" = 18 ký tự ÷ 4 = 4,5 → làm tròn 5, vượt ngưỡng 3.
        XCTAssertEqual(report.chunks[0].tokens, 5)
        XCTAssertEqual(report.overLimit.count, 1)
        let detail = report.score.dimensions.first { $0.dimension == .validity }?.detail ?? ""
        XCTAssertTrue(detail.contains("÷ 4"), detail)
        XCTAssertTrue(detail.contains("người dùng"), detail)
    }

    // MARK: - (b) Trùng gần

    /// Hai chunk chỉ khác nhau một chữ phải vào cùng cụm; chunk thứ ba thì không.
    func testTRUNGGANGomHaiChunkGiongNhauVaBoQuaChunkKhac() throws {
        let long = "hợp đồng mua bán nhà đất giữa bên a và bên b ký ngày mười lăm tháng ba"
        let path = try write([
            record(long, id: "a"),
            record("chuyện hoàn toàn khác về thời tiết mùa hè ở đà lạt và những cơn mưa", id: "b"),
            record(long + " năm nay", id: "c"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertEqual(report.duplicateClusters, [[0, 2]])
        // 100 × (3 − 2) ÷ 3
        XCTAssertEqual(value(report, .uniqueness) ?? 0, 100.0 / 3, accuracy: 1e-9)
    }

    /// Jaccard tính tay trên một cặp bé, để chốt rằng shingle là k-gram KÝ TỰ sau chuẩn hoá.
    func testJACCARDTinhTayTrenShingleKyTu() {
        // k = 3. "abcd" → {abc, bcd}; "abce" → {abc, bce}. Giao 1, hợp 3 → 1/3.
        let left = ChunkQuality.shingles(of: "abcd", k: 3).sorted()
        let right = ChunkQuality.shingles(of: "abce", k: 3).sorted()
        XCTAssertEqual(left.count, 2)
        XCTAssertEqual(right.count, 2)
        XCTAssertEqual(ChunkQuality.jaccard(left, right), 1.0 / 3, accuracy: 1e-12)
    }

    /// Chuẩn hoá: khác nhau ở khoảng trắng và hoa/thường thì vẫn là một.
    func testCHUANHOAKhoangTrangVaHoaThuong() {
        let left = ChunkQuality.shingles(of: "Hợp   Đồng\tMua", k: 4).sorted()
        let right = ChunkQuality.shingles(of: "hợp đồng mua", k: 4).sorted()
        XCTAssertEqual(left, right)
    }

    /// Lọc tiền tố KHÔNG được bỏ sót: so kết quả với phép so vét cạn mọi cặp.
    ///
    /// Đây là bài kiểm quan trọng nhất của phần (b), và nó phải được viết CẨN THẬN chứ không
    /// chỉ viết cho có. Bản đầu của bài này dựng ba nhóm văn bản "gần nhau" một cách hiển
    /// nhiên; nó xanh, nhưng khi rút tiền tố ngắn đi một phần tử — tức là phá đúng chỗ chứng
    /// minh dễ sai nhất — **nó vẫn xanh**. Nó đang qua vì lý do sai: các cặp trong corpus ấy
    /// chung quá nhiều shingle hiếm nên tiền tố nào cũng bắt được.
    ///
    /// Bản này sinh 200 văn bản từ một bộ chữ HẸP với độ dài rất khác nhau, gieo cố định. Chữ
    /// hẹp làm nhiều cặp rơi sát ngưỡng 0,8; độ dài khác nhau ép bộ lọc phải dùng đúng công
    /// thức tiền tố cho từng tập chứ không dùng một hằng số. Corpus sinh ra có 28 cụm.
    ///
    /// Đã thử phá để xem bài này ĐỎ ở đâu: tiền tố chia đôi → đỏ; tiền tố = 1 → đỏ; tiền tố
    /// ngắn đi 2 → đỏ. **Tiền tố ngắn đi 1 thì vẫn XANH**, và đó không phải lỗ hổng của bài
    /// kiểm mà là khoảng dư của chính công thức: ta lấy α = ⌈t·|X|⌉ thay vì α chặt hơn tính từ
    /// cỡ của CẢ HAI tập, nên tiền tố dài hơn mức tối thiểu. Ghi ra đây để không ai đọc màu
    /// xanh ấy thành "ngắn đi một là an toàn" — nó chỉ an toàn trên corpus này.
    func testLOCTIENTOKhongBoSotCapNao() throws {
        var generator = SeededGenerator(seed: 922)
        let alphabet = Array("abcde")
        var texts: [String] = []
        for index in 0 ..< 200 {
            if index % 4 != 0, let previous = texts.randomElement(using: &generator) {
                // Biến thể của một văn bản đã có: đổi vài ký tự, thêm/bớt đuôi. Đây là chỗ sinh
                // ra các cặp NẰM SÁT ngưỡng.
                var characters = Array(previous)
                let edits = Int.random(in: 0 ... 4, using: &generator)
                for _ in 0 ..< edits where !characters.isEmpty {
                    let at = Int.random(in: 0 ..< characters.count, using: &generator)
                    characters[at] = alphabet.randomElement(using: &generator)!
                }
                let trim = Int.random(in: 0 ... 5, using: &generator)
                if characters.count > trim + 10 { characters.removeLast(trim) }
                for _ in 0 ..< Int.random(in: 0 ... 5, using: &generator) {
                    characters.append(alphabet.randomElement(using: &generator)!)
                }
                texts.append(String(characters))
            } else {
                let length = Int.random(in: 25 ... 80, using: &generator)
                texts.append(String((0 ..< length).map { _ in
                    alphabet.randomElement(using: &generator)!
                }))
            }
        }
        let path = try write(texts.enumerated().map { record($0.element, id: "c\($0.offset)") })
        let report = try ChunkQuality.run(corpus: path, config: .init(nearDuplicateLimit: 0))

        // Vét cạn: mọi cặp, Jaccard thật, rồi hợp nhất bắc cầu.
        let sets = texts.map { ChunkQuality.shingles(of: $0, k: 5).sorted() }
        var parent = Array(sets.indices)
        func find(_ node: Int) -> Int {
            var node = node
            while parent[node] != node { node = parent[node] }
            return node
        }
        var pairs = 0
        for left in sets.indices {
            for right in (left + 1) ..< sets.count
            where ChunkQuality.jaccard(sets[left], sets[right]) >= 0.8 {
                pairs += 1
                let a = find(left), b = find(right)
                if a != b { parent[max(a, b)] = min(a, b) }
            }
        }
        var groups: [Int: [Int]] = [:]
        for node in sets.indices { groups[find(node), default: []].append(node) }
        let expected = groups.values.filter { $0.count > 1 }
            .map { $0.sorted() }.sorted { ($0.first ?? 0) < ($1.first ?? 0) }

        XCTAssertEqual(report.duplicateClusters, expected)
        // Corpus phải thật sự có nhiều cặp, nếu không bài kiểm không đo gì.
        XCTAssertGreaterThan(pairs, 20, "corpus của bài kiểm quá thưa cặp")
    }

    /// Vượt trần thì chiều KHÔNG TRÙNG **không chấm được**, và lý do nói rõ cách chấm được.
    func testVUOTTRANThiKhongChamChieuKhongTrung() throws {
        let path = try write((0 ..< 5).map { record("chunk số \($0) với ít chữ", id: "c\($0)") })
        let report = try ChunkQuality.run(corpus: path, config: .init(nearDuplicateLimit: 3))
        XCTAssertNil(value(report, .uniqueness))
        XCTAssertEqual(report.nearDuplicateSkipped, 5)
        XCTAssertEqual(note(report, .uniqueness)?.contains("near_dup_limit"), true)
    }

    // MARK: - (c) Boilerplate

    /// Ba chunk cùng một dòng mở → boilerplate ở ngưỡng mặc định 3 lần.
    func testBOILERPLATEBatDoanMoLapLai() throws {
        let header = "Công ty Cổ phần ABC — Tài liệu nội bộ"
        let path = try write([
            record(header + "\nnội dung thứ nhất khác hẳn nhau", id: "a"),
            record(header + "\nnội dung thứ hai cũng khác", id: "b"),
            record(header + "\nnội dung thứ ba lại khác nữa", id: "c"),
            record("không có header\nnội dung thứ tư độc lập", id: "d"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertEqual(report.boilerplate.count, 1)
        XCTAssertEqual(report.boilerplate[0].count, 3)
        XCTAssertEqual(report.boilerplate[0].position, .opening)
        XCTAssertEqual(report.boilerplate[0].lines, [0, 1, 2])
        XCTAssertEqual(report.boilerplateChunks, 3)
        // 100 × (4 − 3) ÷ 4 = 25
        XCTAssertEqual(value(report, .accuracy) ?? -1, 25, accuracy: 1e-9)
    }

    /// Lặp 2 lần thì CHƯA phải boilerplate ở ngưỡng 3.
    func testLAPHAILANChuaPhaiBoilerplate() throws {
        let header = "Công ty Cổ phần ABC — Tài liệu nội bộ"
        let path = try write([
            record(header + "\nnội dung thứ nhất", id: "a"),
            record(header + "\nnội dung thứ hai", id: "b"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertTrue(report.boilerplate.isEmpty)
        XCTAssertEqual(value(report, .accuracy) ?? -1, 100, accuracy: 1e-9)
    }

    /// Chunk MỘT dòng không được tính hai lần (vừa mở vừa kết).
    func testCHUNKMOTDONGKhongTinhHaiLan() throws {
        let same = "một dòng duy nhất lặp lại nhiều lần trong corpus"
        let path = try write((0 ..< 3).map { record(same, id: "c\($0)") })
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertEqual(report.boilerplate.count, 1)
        XCTAssertEqual(report.boilerplate[0].position, .opening)
        XCTAssertEqual(report.boilerplateChunks, 3)
    }

    /// Dòng ngắn (mục lục kiểu "# Chương 1") KHÔNG bị gọi là boilerplate.
    func testDONGNGANKhongBiGoiLaBoilerplate() throws {
        let path = try write((0 ..< 4).map {
            record("# Mục \($0 % 2)\nnội dung riêng số \($0) dài hơn hẳn", id: "c\($0)")
        })
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertTrue(report.boilerplate.isEmpty, "\(report.boilerplate)")
    }

    // MARK: - (d) Coverage theo nguồn

    func testNGUONKHAIBAOThieuThiTruDiemChieuDayDu() throws {
        let path = try write([
            record("nội dung một", id: "a", source: "web"),
            record("nội dung hai", id: "b", source: "web"),
            record("nội dung ba", id: "c", source: "pdf"),
        ])
        let report = try ChunkQuality.run(
            corpus: path, config: .init(declaredSources: ["web", "pdf", "wiki", "email"]))
        XCTAssertEqual(report.missingSources, ["wiki", "email"])
        // 100 × 2 ÷ 4 = 50
        XCTAssertEqual(value(report, .completeness) ?? -1, 50, accuracy: 1e-9)
        XCTAssertEqual(report.sourceCounts.map(\.source), ["web", "pdf"])
    }

    /// Nhất quán = entropy chuẩn hoá. Hai nguồn 2/1: H = −(2/3·ln(2/3) + 1/3·ln(1/3)).
    func testNHATQUANLaEntropyChuanHoaTinhTay() throws {
        let path = try write([
            record("nội dung một", id: "a", source: "web"),
            record("nội dung hai", id: "b", source: "web"),
            record("nội dung ba", id: "c", source: "pdf"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        let entropy = -(2.0 / 3 * log(2.0 / 3) + 1.0 / 3 * log(1.0 / 3))
        XCTAssertEqual(value(report, .consistency) ?? 0, 100 * entropy / log(2.0), accuracy: 1e-9)
    }

    /// Chia đều thì 100; dồn hết vào một nguồn thì KHÔNG chấm được (chỉ có một nguồn).
    func testCHIADEUThi100VaMOTNGUONThiKhongCham() throws {
        let even = try write([
            record("nội dung một", id: "a", source: "web"),
            record("nội dung hai", id: "b", source: "pdf"),
        ], name: "even.jsonl")
        XCTAssertEqual(
            value(try ChunkQuality.run(corpus: even), .consistency) ?? -1, 100, accuracy: 1e-9)

        let single = try write([
            record("nội dung một", id: "a", source: "web"),
            record("nội dung hai", id: "b", source: "web"),
        ], name: "single.jsonl")
        let report = try ChunkQuality.run(corpus: single)
        XCTAssertNil(value(report, .consistency))
        XCTAssertEqual(note(report, .consistency)?.contains("một nguồn"), true)
    }

    // MARK: - Khung chung

    /// Chiều TƯƠI MỚI luôn `nil`, và nó bị LOẠI khỏi điểm tổng chứ không kéo điểm xuống.
    func testTUOIMOIKhongChamDuocVaBiLoaiKhoiDiemTong() throws {
        let path = try write([
            record("nội dung một", id: "a", source: "web"),
            record("nội dung hai", id: "b", source: "pdf"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertNil(value(report, .timeliness))
        XCTAssertEqual(report.score.unscored.map(\.dimension), [.completeness, .validity, .timeliness])
        // Ba chiều chấm được: không trùng 100 · nhất quán 100 · chính xác 100 → tổng 100.
        XCTAssertEqual(report.score.total, 100)
    }

    /// Mọi chiều đều mang theo CÔNG THỨC thật — NFR-DQR-03 đòi người đọc tính lại được.
    func testMOICHIEUDeuCoCongThuc() throws {
        let path = try write([record("nội dung một", id: "a", source: "web")])
        let report = try ChunkQuality.run(corpus: path, config: .init(maxTokens: 100))
        for dimension in report.score.dimensions where dimension.value != nil {
            XCTAssertFalse(dimension.formula.isEmpty, "\(dimension.dimension) thiếu công thức")
            XCTAssertFalse(dimension.detail.isEmpty, "\(dimension.dimension) thiếu số liệu")
        }
    }

    /// Dòng hỏng vẫn GIỮ CHỖ trong đánh số, và được kể ra chứ không bị nuốt.
    func testDONGHONGGiuChoVaDuocKeRa() throws {
        let path = try write([
            record("nội dung một", id: "a"),
            "{ đây không phải json }",
            #"{"id":"c","khong_co_text":1}"#,
            record("nội dung bốn", id: "d"),
        ])
        let report = try ChunkQuality.run(corpus: path)
        XCTAssertEqual(report.chunkCount, 2)
        XCTAssertEqual(report.brokenLines, [1, 2])
        XCTAssertEqual(report.chunks.map(\.line), [0, 3])
    }

    /// Hai lượt chạy cho kết quả GIỐNG HỆT — kể cả thứ tự cụm và thứ tự boilerplate.
    ///
    /// Bài này bắt được đúng một loại lỗi: dùng `Hasher` của Swift (gieo ngẫu nhiên theo tiến
    /// trình) hoặc duyệt một `Set`/`Dictionary` mà không sắp lại.
    func testHAILUOTCHAYChoKetQuaGiongHet() throws {
        var lines: [String] = []
        for index in 0 ..< 30 {
            let base = "đoạn văn số \(index % 7) nói về hợp đồng và biên bản bàn giao thiết bị"
            lines.append(record("Header lặp lại nhiều lần\n" + base, id: "c\(index)",
                                source: index % 3 == 0 ? "web" : "pdf"))
        }
        let path = try write(lines)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try ChunkQuality.run(corpus: path, config: .init(maxTokens: 20), now: now)
        let second = try ChunkQuality.run(corpus: path, config: .init(maxTokens: 20), now: now)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.duplicateClusters.isEmpty)
    }
}

// MARK: - Khối ```quality ở chế độ corpus

/// FR-KNW-922 — nối vào khối ```quality của báo cáo.
final class ChunkQualityBlockTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("chunkblock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    func testKHOICOCORPUSThiSangCheDoChunk() throws {
        let spec = try QualityBlockSpec.parse("""
            corpus: chunks.jsonl
            max_tokens: 512
            min_tokens: 32
            near_dup: 0.9
            shingle: 7
            sources: [web, pdf]
            """)
        XCTAssertEqual(spec.corpus, "chunks.jsonl")
        XCTAssertEqual(spec.chunk.maxTokens, 512)
        XCTAssertEqual(spec.chunk.minTokens, 32)
        XCTAssertEqual(spec.chunk.nearDuplicate, 0.9)
        XCTAssertEqual(spec.chunk.shingle, 7)
        XCTAssertEqual(spec.chunk.declaredSources, ["web", "pdf"])
    }

    /// Không có `corpus` thì khối vẫn ĐÒI `rules_file` như cũ — chế độ mới không nới luật cũ.
    func testKHONGCOCORPUSThiVanDoiRulesFile() {
        XCTAssertThrowsError(try QualityBlockSpec.parse("title: thử"))
    }

    /// Khoá của chế độ chunk dùng nhầm ở chế độ bảng thì báo lỗi NÓI RA vì sao.
    func testKHOACHUNKDungNhamCheDoBangThiBaoRoLyDo() {
        do {
            _ = try QualityBlockSpec.parse("""
                rules_file: luat.yaml
                max_tokens: 512
                """)
            XCTFail("đáng lẽ phải ném lỗi")
        } catch let failure as QualityBlockSpec.Failure {
            XCTAssertTrue(failure.message.contains("chế độ chunk"), failure.message)
            XCTAssertTrue(failure.message.contains("corpus"), failure.message)
        } catch {
            XCTFail("lỗi sai kiểu: \(error)")
        }
    }

    func testNGUONGSAIThiBaoLoiChuKhongNhanBua() {
        XCTAssertThrowsError(try QualityBlockSpec.parse("corpus: a.jsonl\nnear_dup: 2"))
        XCTAssertThrowsError(try QualityBlockSpec.parse("corpus: a.jsonl\nchars_per_token: 0"))
        XCTAssertThrowsError(
            try QualityBlockSpec.parse("corpus: a.jsonl\nboilerplate_repeats: 1"))
    }

    /// Đường ghép đầy đủ: dựng báo cáo thật, thẻ điểm phải có mặt trong HTML.
    func testDUNGBAOCAOThatRaTheDiemChunk() throws {
        let corpus = folder + "/chunks.jsonl"
        let header = "Công ty Cổ phần ABC — Tài liệu nội bộ"
        let lines = (0 ..< 4).map { index -> String in
            let object: [String: Any] = [
                "id": "c\(index)",
                "text": header + "\nnội dung riêng số \(index) dài hơn hẳn phần đầu",
                "source": index == 0 ? "web" : "pdf",
            ]
            return String(decoding: try! JSONSerialization.data(withJSONObject: object),
                          as: UTF8.self)
        }
        try lines.joined(separator: "\n").write(
            toFile: corpus, atomically: true, encoding: .utf8)

        let report = folder + "/bao-cao.greport.md"
        try """
            # Corpus

            ```quality
            corpus: chunks.jsonl
            max_tokens: 40
            sources: [web, pdf, wiki]
            title: Chất lượng corpus
            ```
            """.write(toFile: report, atomically: true, encoding: .utf8)

        let document = try ReportDocument.parse(
            String(contentsOfFile: report, encoding: .utf8))
        let result = try ReportRenderer.render(
            document, in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
            options: ReportRenderer.Options(basePath: folder))

        XCTAssertTrue(result.failures.isEmpty, "\(result.failures)")
        XCTAssertTrue(result.html.contains("Chất lượng corpus"), "thiếu tiêu đề")
        XCTAssertTrue(result.html.contains("Boilerplate"), "thiếu bảng boilerplate")
        XCTAssertTrue(result.html.contains("Phủ theo nguồn"), "thiếu bảng phủ nguồn")
        // Nguồn khai mà KHÔNG có chunk phải là một DÒNG SỐ 0, không phải vắng mặt.
        XCTAssertTrue(result.html.contains("wiki"), "nguồn thiếu phải hiện thành dòng 0")
        // Cùng một bảng KHÔNG được trộn hai quy ước số. Bản đầu in «80.00%» cạnh «0,00%» vì
        // dòng nguồn-thiếu viết tay chuỗi phần trăm thay vì đi qua cùng một chỗ định dạng.
        XCTAssertFalse(result.html.contains("0,00%"), "trộn dấu thập phân trong cùng một bảng")
        // Chiều Tươi mới không chấm được, và câu ấy phải nằm trong HTML.
        XCTAssertTrue(result.html.contains("KHÔNG chấm được"), "thiếu câu về chiều bị loại")
    }

    /// Corpus không đọc được thì khối HỎNG có chỗ nhảy, không làm hỏng cả báo cáo.
    func testCORPUSKhongDocDuocThiKhoiHongChuKhongPhaiCaBaoCao() throws {
        let report = folder + "/bao-cao.greport.md"
        try """
            ```quality
            corpus: khong-co.jsonl
            ```

            Văn xuôi phía sau vẫn phải còn.
            """.write(toFile: report, atomically: true, encoding: .utf8)
        let document = try ReportDocument.parse(
            String(contentsOfFile: report, encoding: .utf8))
        let result = try ReportRenderer.render(
            document, in: TextBuffer(original: MemoryByteSource([])), dialect: .comma,
            options: ReportRenderer.Options(basePath: folder))
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.html.contains("Văn xuôi phía sau vẫn phải còn"))
    }
}
