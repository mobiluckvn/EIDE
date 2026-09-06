import XCTest
@testable import GEditorCore

/// FR-KNW-918 · NFR-KNW-04 — chỉ mục BM25.
final class BM25TokenizerTests: XCTestCase {

    func testCATTHEORanhGioiChuSo() {
        let tokenizer = BM25Tokenizer()
        XCTAssertEqual(
            tokenizer.tokens(in: "Hợp đồng số 12/2026-QĐ, ký ngày 3.4"),
            ["hợp", "đồng", "số", "12", "2026", "qđ", "ký", "ngày", "3", "4"])
    }

    /// Dấu tiếng Việt GIỮ theo mặc định.
    ///
    /// Bỏ dấu thì `má`, `mà`, `mã`, `ma` gộp làm một — trong một corpus tiếng Việt đó là gộp
    /// những từ chẳng liên quan gì tới nhau, và nó làm hỏng chính thứ BM25 đang đo.
    func testGIUDAUTheoMacDinh() {
        let tokens = BM25Tokenizer().tokens(in: "má mà mã ma")
        XCTAssertEqual(Set(tokens).count, 4, "\(tokens)")

        let folded = BM25Tokenizer(foldDiacritics: true).tokens(in: "má mà mã ma")
        XCTAssertEqual(Set(folded).count, 1, "bật công tắc thì mới gộp: \(folded)")
    }

    /// `_` và `-` là DẤU NGẮT ở đây, khác `CompletionEngine`.
    ///
    /// Người hỏi «hợp đồng» phải khớp được cả `hop-dong` lẫn `hop_dong` trong dữ liệu cào về.
    func testGACHDUOIVaGachNgangLaDauNgat() {
        XCTAssertEqual(BM25Tokenizer().tokens(in: "hop_dong-2026"), ["hop", "dong", "2026"])
    }

    func testMOTATrongKhoiPhuongPhapNoiRaGioiHan() {
        // Giới hạn "chưa tách TỪ GHÉP" phải nằm trong mô tả, không giấu trong mã.
        XCTAssertTrue(BM25Tokenizer().methodology.contains("FR-MIN-006"))
        XCTAssertTrue(BM25Tokenizer().methodology.contains("GIỮ dấu"))
        XCTAssertTrue(BM25Tokenizer(foldDiacritics: true).methodology.contains("BỎ DẤU"))
    }
}

final class BM25IndexTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("bm25-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    /// Corpus nhỏ, MỌI kỳ vọng suy từ chính nó bằng cách tính tay — không suy từ kết quả engine.
    private let corpus = """
        {"id": "c1", "text": "hợp đồng mua bán nhà đất"}
        {"id": "c2", "text": "hợp đồng lao động"}
        {"id": "c3", "text": "biên bản bàn giao nhà"}
        {"id": "c4", "text": "hợp đồng hợp đồng hợp đồng"}

        """

    @discardableResult
    private func build(
        _ text: String? = nil, options: BM25Index.Options = .init(blockBudget: 1 << 20)
    ) throws -> BM25Index {
        let path = folder + "/corpus.jsonl"
        try (text ?? corpus).write(toFile: path, atomically: true, encoding: .utf8)
        return try BM25Index.build(corpus: path, options: options)
    }

    // MARK: - Đúng đắn

    func testDEMTAILIEUVaDoDai() throws {
        let index = try build()
        XCTAssertEqual(index.documentCount, 4)
        // Độ dài: 6, 4, 5, 6 token → tổng 21, trung bình 5,25.
        XCTAssertEqual(index.manifest.totalTokens, 21)
        XCTAssertEqual(index.manifest.averageLength, 5.25, accuracy: 1e-12)
    }

    func testTIMRaDungTaiLieu() throws {
        let index = try build()
        let hits = index.search("hợp đồng", k: 10)
        // c1, c2, c4 chứa cả hai từ; c3 không chứa từ nào.
        XCTAssertEqual(hits.count, 3)
        XCTAssertFalse(hits.contains { $0.document == 2 })
        // c4 lặp ba lần và NGẮN, nên nó phải đứng đầu.
        XCTAssertEqual(hits[0].document, 3)
    }

    func testTUKHONGCOTrongCorpusThiKhongLoi() throws {
        let index = try build()
        XCTAssertTrue(index.search("blockchain", k: 5).isEmpty)
        XCTAssertTrue(index.search("", k: 5).isEmpty)
        XCTAssertTrue(index.search("   ,,,  ", k: 5).isEmpty)
    }

    func testTUKHOPDuocGhiLaiDeToSang() throws {
        let index = try build()
        let hit = try XCTUnwrap(index.search("hợp đồng nhà", k: 1).first)
        XCTAssertFalse(hit.matchedTerms.isEmpty)
        XCTAssertTrue(hit.matchedTerms.allSatisfy { ["hợp", "đồng", "nhà"].contains($0) })
    }

    /// Điểm bằng nhau thì xếp theo số hiệu tài liệu — NFR-KNW-04 đòi TẤT ĐỊNH.
    ///
    /// Không có vế ấy thì thứ tự phụ thuộc thứ tự duyệt `Dictionary` của Swift, vốn đổi giữa
    /// các lần chạy: hai lượt chạy cùng dữ liệu cho hai bảng xếp hạng khác nhau.
    func testDIEMBANGNHAUThiTatDinh() throws {
        let index = try build("""
            {"text": "alpha"}
            {"text": "alpha"}
            {"text": "alpha"}

            """)
        for _ in 0 ..< 20 {
            XCTAssertEqual(index.search("alpha", k: 3).map(\.document), [0, 1, 2])
        }
    }

    func testCHAYHAILANRaCHIMUCGiongNhauTungByte() throws {
        let path = folder + "/corpus.jsonl"
        try corpus.write(toFile: path, atomically: true, encoding: .utf8)
        _ = try BM25Index.build(corpus: path)
        let first = try Data(contentsOf: URL(fileURLWithPath: BM25Index.indexPath(for: path)))
        _ = try BM25Index.build(corpus: path)
        let second = try Data(contentsOf: URL(fileURLWithPath: BM25Index.indexPath(for: path)))
        // `buildMilliseconds` nằm trong manifest nên hai tệp KHÁC nhau ở đúng chỗ ấy; phần
        // THÂN (từ điển + posting) phải giống hệt.
        let firstBody = first[(first.firstIndex(of: 0x0A) ?? 0)...]
        let secondBody = second[(second.firstIndex(of: 0x0A) ?? 0)...]
        XCTAssertEqual(firstBody, secondBody)
    }

    // MARK: - Ghi và đọc lại

    func testDOCLAIChoRaCungKetQua() throws {
        let path = folder + "/corpus.jsonl"
        try corpus.write(toFile: path, atomically: true, encoding: .utf8)
        let built = try BM25Index.build(corpus: path)
        let loaded = try XCTUnwrap(BM25Index.load(corpus: path))
        XCTAssertEqual(loaded.documentCount, built.documentCount)
        XCTAssertEqual(loaded.manifest.termCount, built.manifest.termCount)
        let a = built.search("hợp đồng nhà", k: 10)
        let b = loaded.search("hợp đồng nhà", k: 10)
        XCTAssertEqual(a.map(\.document), b.map(\.document))
        for (x, y) in zip(a, b) { XCTAssertEqual(x.score, y.score, accuracy: 1e-12) }
    }

    /// Corpus đổi thì chỉ mục cũ phải HẾT HIỆU LỰC.
    ///
    /// Một chỉ mục lệch corpus trả về đúng thứ hạng cho một tập tài liệu không còn tồn tại —
    /// kiểu sai không ai phát hiện.
    func testCORPUSDoiThiChiMucHetHieuLuc() throws {
        let path = folder + "/corpus.jsonl"
        try corpus.write(toFile: path, atomically: true, encoding: .utf8)
        _ = try BM25Index.build(corpus: path)
        XCTAssertNotNil(BM25Index.load(corpus: path))

        try (corpus + "{\"text\": \"thêm một dòng\"}\n")
            .write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertNil(BM25Index.load(corpus: path), "corpus dài ra mà chỉ mục vẫn được nhận")
    }

    /// Đổi THAM SỐ cũng làm chỉ mục hết hiệu lực — k1/b/tokenizer đều đi vào điểm số.
    func testDOITHAMSOThiChiMucHetHieuLuc() throws {
        let path = folder + "/corpus.jsonl"
        try corpus.write(toFile: path, atomically: true, encoding: .utf8)
        _ = try BM25Index.build(corpus: path)
        XCTAssertNil(BM25Index.load(corpus: path, options: .init(k1: 1.5)))
        XCTAssertNil(BM25Index.load(
            corpus: path, options: .init(tokenizer: BM25Tokenizer(foldDiacritics: true))))
        XCTAssertNil(BM25Index.load(corpus: path, options: .init(textField: "noi_dung")))
    }

    func testLAYLaiNoiDungBanGhi() throws {
        let index = try build()
        XCTAssertTrue(index.record(0)?.contains("mua bán nhà đất") ?? false)
        XCTAssertEqual(index.text(of: 1), "hợp đồng lao động")
        XCTAssertNil(index.text(of: 99))
    }

    // MARK: - Ca hỏng

    /// Dòng KHÔNG phải JSON vẫn GIỮ CHỖ trong dãy tài liệu.
    ///
    /// Bỏ hẳn nó thì mọi số hiệu phía sau lệch một, và "bấm kết quả để nhảy tới dòng" nhảy sai.
    func testDONGHONGVanGiuCho() throws {
        let index = try build("""
            {"text": "một"}
            { dòng này hỏng
            {"text": "ba"}

            """)
        XCTAssertEqual(index.documentCount, 3)
        XCTAssertEqual(index.search("ba", k: 5).first?.document, 2)
    }

    func testTHIEUTRUONGVANBANThiBoQuaBanGhiAy() throws {
        let index = try build("""
            {"text": "có văn bản"}
            {"khac": "không có trường text"}

            """)
        XCTAssertEqual(index.documentCount, 2)
        XCTAssertEqual(index.documentLengths[1], 0)
    }

    /// Trường `text` là MẢNG đoạn cũng gặp trong corpus thật — nối lại chứ không bỏ qua.
    func testTRUONGVANBANLaMang() throws {
        let index = try build("""
            {"text": ["đoạn một", "đoạn hai"]}

            """)
        XCTAssertEqual(index.documentLengths[0], 4)
        XCTAssertEqual(index.search("hai", k: 1).count, 1)
    }

    // MARK: - Dựng theo khối

    /// Trần bộ nhớ nhỏ ép ra NHIỀU run, và kết quả phải giống hệt khi dựng một khối.
    ///
    /// Đây là bài kiểm đáng giá nhất của phần dựng: bước trộn phải tính LẠI hiệu số hiệu tài
    /// liệu qua ranh giới run, và sai ở đó thì điểm số vẫn ra một con số trông hợp lý.
    func testNHIEUKHOICHoRaKetQuaGiongMotKhoi() throws {
        var lines: [String] = []
        for index in 0 ..< 400 {
            lines.append("{\"text\": \"tài liệu số \(index) về hợp đồng và nhà đất\"}")
        }
        let text = lines.joined(separator: "\n") + "\n"

        let big = try build(text, options: .init(blockBudget: 1 << 30))
        let small = try build(text, options: .init(blockBudget: 4 << 10))
        XCTAssertGreaterThan(small.manifest.termCount, 0)
        XCTAssertEqual(big.manifest.termCount, small.manifest.termCount)
        XCTAssertEqual(big.documentCount, small.documentCount)

        for query in ["hợp đồng", "nhà đất", "tài liệu số 7", "số"] {
            let a = big.search(query, k: 20)
            let b = small.search(query, k: 20)
            XCTAssertEqual(a.map(\.document), b.map(\.document), query)
            for (x, y) in zip(a, b) {
                XCTAssertEqual(x.score, y.score, accuracy: 1e-12, query)
            }
        }
    }

    func testHUYGiuaChungThiKhongDeLaiChiMuc() throws {
        let path = folder + "/corpus.jsonl"
        var lines: [String] = []
        for index in 0 ..< 5_000 { lines.append("{\"text\": \"dòng \(index)\"}") }
        try (lines.joined(separator: "\n") + "\n")
            .write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try BM25Index.build(corpus: path, options: .init(blockBudget: 1 << 20)) { _ in
                false   // hủy ngay ở nhịp tiến độ đầu tiên
            })
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: BM25Index.indexPath(for: path)),
            "hủy giữa chừng mà vẫn ghi ra chỉ mục")
    }
}

// MARK: - Đường tắt đọc JSON (BM25RawJSON)

extension BM25IndexTests {

    /// Đối chiếu bộ dò byte với `JSONSerialization` trên một tập ca hiểm.
    ///
    /// Luật chỉ có hai vế, và vế thứ hai mới là vế giữ cho đường tắt này an toàn:
    ///
    /// 1. bộ dò trả về một dải → dải ấy PHẢI giải ra đúng chuỗi mà bộ đọc đầy đủ cho;
    /// 2. bộ dò trả `nil` → không kết luận gì, chỗ gọi lui về bộ đọc đầy đủ.
    ///
    /// Nói cách khác bài kiểm này KHÔNG ép đường tắt phải nhận nhiều ca. Nó chỉ cấm nó SAI.
    func testDUONGTATJSONKhongBaoGioLechVoiBoDocDayDu() throws {
        let cases: [String] = [
            #"{"text":"xin chào","id":1}"#,
            #"{"id":1,"text":"xin chào"}"#,
            #"{ "id" : 1 , "text" : "có khoảng trắng" }"#,
            #"{"text":""}"#,
            #"{"a":{"text":"LỒNG — không được lấy"},"text":"đúng"}"#,
            #"{"a":[1,2,{"text":"trong mảng"}],"text":"đúng"}"#,
            #"{"text":"dấu ngoặc \" bên trong"}"#,
            #"{"text":"gạch chéo \\ đôi"}"#,
            #"{"text":"thoát unicode \u00e1"}"#,
            #"{"text":123}"#,
            #"{"text":null}"#,
            #"{"text":true,"b":2}"#,
            #"{"other":"không có trường text"}"#,
            #"{}"#,
            #"{"text":"số âm","n":-1.5e10}"#,
            #"{"n":-1.5e10,"text":"sau số âm"}"#,
            #"{"text":"tiếng Việt đủ dấu: ạ ầ ẫ ỡ ự"}"#,
            #"{"te\u0078t":"khoá bị thoát"}"#,
            "không phải JSON",
            #"{"text":"thiếu ngoặc đóng"#,
            "[1,2,3]",
            #"{"text":"cuối dòng"}"#,
        ]

        for line in cases {
            let bytes = Array(line.utf8)
            let fast: String? = bytes.withUnsafeBufferPointer { buffer in
                guard let range = BM25RawJSON.stringRange(field: "text", in: buffer) else {
                    return nil
                }
                return String(decoding: buffer[range], as: UTF8.self)
            }
            guard let fast else { continue }   // vế 2: bỏ cuộc thì không kết luận gì

            let object = (try? JSONSerialization.jsonObject(with: Data(bytes)))
                as? [String: Any]
            let slow = object?["text"] as? String
            XCTAssertEqual(fast, slow, "lệch ở dòng: \(line)")
        }
    }

    /// Ca hiểm nhất: dòng có ký tự thoát PHẢI đi đường chậm và vẫn ra đúng token.
    ///
    /// Bài này chấm cả đường ghép — dựng chỉ mục thật rồi tìm, chứ không chỉ chấm bộ dò.
    func testCHUTHOATVanVaoChiMucDungQuaDuongCham() throws {
        let path = folder + "/thoat.jsonl"
        try #"""
        {"text":"hợp đồng \"khung\" ký ngày mai"}
        {"text":"thư mục C:\\Users\\an"}
        {"text":"thoát unicode \u0111 \u1ea1"}
        {"text":"không thoát gì cả"}
        """#.write(toFile: path, atomically: true, encoding: .utf8)

        let index = try BM25Index.build(corpus: path)
        XCTAssertEqual(index.search("khung", k: 5).map { $0.document }, [0])
        XCTAssertEqual(index.search("users", k: 5).map { $0.document }, [1])
        // `\u0111` là `đ`, `\u1ea1` là `ạ` — chỉ ra đúng nếu chuỗi được GIẢI MÃ, không phải
        // lấy nguyên dải byte `\u0111`.
        XCTAssertEqual(index.search("đ", k: 5).map { $0.document }, [2])
        XCTAssertTrue(index.search("u0111", k: 5).isEmpty)
    }
}
