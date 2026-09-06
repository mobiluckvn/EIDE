import XCTest
@testable import GEditorCore

/// FR-KNW-920 — liên kết Chunk ↔ Entity ↔ Graph và gói ngữ cảnh.
final class ContextPackageTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ctx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    /// Đồ thị `An — Bình — Chi`, và `Dũng` đứng riêng, `Ế` không ai nhắc.
    private func build() throws
        -> (BM25Index, GraphCSR, HybridRetrieval.EntityDictionary, ContextPackage.Links) {
        let corpus = (folder as NSString).appendingPathComponent("chunks.jsonl")
        try """
            {"id":"c1","text":"hợp đồng do An ký"}
            {"id":"c2","text":"biên bản do Bình lập"}
            {"id":"c3","text":"quyết định do Chi ban hành"}
            {"id":"c4","text":"ghi chú do Dũng viết"}
            {"id":"c5","text":"không nhắc tới ai cả"}
            """.write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let graph = GraphCSR(DOTGraph.parse("""
            graph {
                An -- "Bình";
                "Bình" -- Chi;
                "Dũng";
                "Ế";
            }
            """))
        let dictionary = HybridRetrieval.dictionary(for: graph)
        let links = try ContextPackage.link(index: index, graph: graph, dictionary: dictionary)
        return (index, graph, dictionary, links)
    }

    // MARK: - Ánh xạ ba chiều

    func testANHXABAChieu() throws {
        let (_, graph, _, links) = try build()
        let an = graph.index(of: "An")!
        XCTAssertEqual(links.chunksOfEntity[an], [0])
        XCTAssertEqual(links.entitiesOfChunk[0]?.map { graph.displays[$0] }, ["An"])
        // Chunk cuối không nhắc ai — nó KHÔNG có mặt trong bảng.
        XCTAssertNil(links.entitiesOfChunk[4])
        XCTAssertEqual(links.chunkCount, 5)
    }

    // MARK: - Phân tích phủ

    /// Ba loại lỗ hổng, đếm tay.
    func testBALOAILoHong() throws {
        let (_, graph, dictionary, links) = try build()
        let coverage = ContextPackage.coverage(links, graph: graph, dictionary: dictionary)
        // «Ế» không chunk nào nhắc tới.
        XCTAssertEqual(coverage.unmentionedEntities, ["Ế"])
        // Chunk c5 mồ côi.
        XCTAssertEqual(coverage.orphanChunks, [4])
        XCTAssertEqual(coverage.orphanChunkCount, 1)
        XCTAssertEqual(coverage.mentionedRatio, 4.0 / 5, accuracy: 1e-12)
        XCTAssertEqual(coverage.linkedChunkRatio, 4.0 / 5, accuracy: 1e-12)
    }

    /// **Con số 0 phải nói ra vì sao nó bằng 0.**
    ///
    /// Danh sách marker mặc định CHÍNH LÀ tập node đồ thị, nên "node không có entity đối ứng"
    /// rỗng theo cấu tạo — không phải vì đồ thị sạch. Không nói ra thì người đọc tin vào một
    /// con số vô nghĩa.
    func testNODEKhongCoEntityDoiUngRongTheoCauTao() throws {
        let (_, graph, dictionary, links) = try build()
        let coverage = ContextPackage.coverage(links, graph: graph, dictionary: dictionary)
        XCTAssertTrue(coverage.unmappedNodes.isEmpty)
        XCTAssertTrue(coverage.markersAreGraphNodes)
        XCTAssertTrue(coverage.methodology.contains("theo cấu tạo"), coverage.methodology)
    }

    /// Khai marker riêng thì phép kiểm ấy MỚI có nghĩa.
    func testKHAIMarkerRiengThiPhepKiemCoNghia() throws {
        let (_, graph, dictionary, links) = try build()
        let coverage = ContextPackage.coverage(
            links, graph: graph, dictionary: dictionary, markers: ["An", "Bình"])
        XCTAssertEqual(Set(coverage.unmappedNodes), Set(["Chi", "Dũng", "Ế"]))
        XCTAssertFalse(coverage.markersAreGraphNodes)
        XCTAssertFalse(coverage.methodology.contains("theo cấu tạo"))
    }

    // MARK: - Gói ngữ cảnh

    /// Từ seed «An», bán kính 1: subgraph có An–Bình, chunk có c1 (hop 0) và c2 (hop 1).
    func testGOINGUCANHTuMotSeed() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links,
            config: .init(hops: 1))
        XCTAssertTrue(package.seedFound)
        XCTAssertEqual(package.triples.count, 1)
        XCTAssertEqual(package.triples[0].subject, "An")
        XCTAssertEqual(package.triples[0].object, "Bình")
        XCTAssertEqual(package.chunks.map(\.id), ["c1", "c2"])
        XCTAssertEqual(package.chunks.map(\.hops), [0, 1])
    }

    /// Bán kính 2 kéo thêm Chi và chunk của Chi.
    func testBANKINHHaiKeoThemMotVong() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links,
            config: .init(hops: 2))
        XCTAssertEqual(package.chunks.map(\.id), ["c1", "c2", "c3"])
        XCTAssertEqual(package.chunks.map(\.hops), [0, 1, 2])
        XCTAssertEqual(package.triples.count, 2)
    }

    /// **Cạnh nửa trong nửa ngoài KHÔNG vào gói.**
    ///
    /// Một quan hệ mà gói không mang đủ hai vế sẽ được pipeline bên ngoài đọc như một quan hệ
    /// tới một thực thể không tồn tại.
    func testCANHNuaTrongNuaNgoaiKhongVaoGoi() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links,
            config: .init(hops: 1))
        // Bán kính 1 = {An, Bình}. Cạnh Bình—Chi có một đầu ngoài vùng, phải bị bỏ.
        XCTAssertFalse(package.triples.contains { $0.object == "Chi" || $0.subject == "Chi" })
    }

    /// Seed KHÔNG có trên đồ thị: gói rỗng, và cờ nói ra lý do.
    func testSEEDKhongCoTrenDoThi() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "Không Tồn Tại", index: index, graph: graph, dictionary: dictionary,
            links: links)
        XCTAssertFalse(package.seedFound)
        XCTAssertTrue(package.triples.isEmpty)
        XCTAssertTrue(package.chunks.isEmpty)
    }

    /// Node cô lập: gói có chunk nhưng KHÔNG có triple nào.
    func testNODECoLapCoChunkNhungKhongCoTriple() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "Dũng", index: index, graph: graph, dictionary: dictionary, links: links)
        XCTAssertTrue(package.seedFound)
        XCTAssertTrue(package.triples.isEmpty)
        XCTAssertEqual(package.chunks.map(\.id), ["c4"])
    }

    /// Trần số chunk cắt bớt, nhưng chunk GẦN seed nhất được giữ trước.
    func testTRANChunkGiuChunkGanNhatTruoc() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links,
            config: .init(hops: 2, chunkLimit: 2))
        XCTAssertEqual(package.chunks.map(\.id), ["c1", "c2"])
    }

    // MARK: - Xuất JSONL

    /// Dòng JSONL đọc lại được, và có đủ BA trường phụ lục nêu tên.
    func testDONGJSONLDocLaiDuocVaDuBaTruong() throws {
        let (index, graph, dictionary, links) = try build()
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links,
            config: .init(hops: 1))
        let line = ContextPackage.jsonl(package)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        XCTAssertEqual(object["query_seed"] as? String, "An")
        let triples = try XCTUnwrap(object["triples"] as? [[String: Any]])
        XCTAssertEqual(triples[0]["s"] as? String, "An")
        XCTAssertEqual(triples[0]["o"] as? String, "Bình")
        let chunks = try XCTUnwrap(object["chunks"] as? [[String: Any]])
        XCTAssertEqual(chunks[0]["id"] as? String, "c1")
        XCTAssertEqual(chunks[0]["hops"] as? Int, 0)
        XCTAssertEqual(chunks[0]["entities"] as? [String], ["An"])
    }

    /// Ký tự đặc biệt trong nội dung chunk vẫn ra JSON hợp lệ.
    func testKYTUDACBIETVanRaJSONHopLe() throws {
        let corpus = (folder as NSString).appendingPathComponent("dacbiet.jsonl")
        try #"{"id":"c1","text":"An nói \"xin chào\"\nvà xuống dòng"}"#
            .write(toFile: corpus, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let index = try BM25Index.build(corpus: corpus)
        let graph = GraphCSR(DOTGraph.parse("graph { An -- B }"))
        let dictionary = HybridRetrieval.dictionary(for: graph)
        let links = try ContextPackage.link(index: index, graph: graph, dictionary: dictionary)
        let package = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links)
        let line = ContextPackage.jsonl(package)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(line.utf8)))
    }

    /// Hai lượt cho kết quả GIỐNG HỆT.
    func testHAILUOTGiongHet() throws {
        let (index, graph, dictionary, links) = try build()
        let first = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links)
        let second = ContextPackage.extract(
            seed: "An", index: index, graph: graph, dictionary: dictionary, links: links)
        XCTAssertEqual(first, second)
        XCTAssertEqual(ContextPackage.jsonl(first), ContextPackage.jsonl(second))
    }
}
