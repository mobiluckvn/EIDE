import XCTest
@testable import GEditorCore

/// Chuyển đổi tri thức — FR-KNW-910.
final class KnowledgeConvertTests: XCTestCase {

    private let jsonl = """
    {"id":"c1","text":"Một","heading":"# A","score":0.8}
    {"id":"c2","text":"Hai","source":"tài liệu.md"}
    """

    // MARK: - Chunk

    /// Cột lấy HỢP của mọi bản ghi. JSONL thật hay có trường vắng ở vài dòng, và lấy dòng đầu
    /// làm chuẩn sẽ nuốt im lặng mọi trường xuất hiện muộn.
    func testJSONLsangCSVlayHOPcuaMOIbanGhi() throws {
        let csv = try KnowledgeConvert.convert(jsonl, from: .chunksJSONL, to: .chunksCSV)
        let dong = csv.split(separator: "\n")
        let cot = dong[0].split(separator: ",").map(String.init)
        XCTAssertTrue(cot.contains("source"), "cột chỉ có ở dòng THỨ HAI bị mất: \(cot)")
        XCTAssertTrue(cot.contains("heading"), "cột chỉ có ở dòng ĐẦU bị mất: \(cot)")
        XCTAssertEqual(dong.count, 3)
    }

    /// Trường KHÔNG phải chuỗi được ép về chuỗi nguyên văn thay vì bỏ đi — mất một cột `score`
    /// là mất dữ liệu im lặng.
    func testTruongSOkhongBiBoDi() throws {
        let csv = try KnowledgeConvert.convert(jsonl, from: .chunksJSONL, to: .chunksCSV)
        XCTAssertTrue(csv.contains("0.8"), csv)
    }

    func testJSONLsangMarkdownGiuMetadataTrongChuThich() throws {
        let md = try KnowledgeConvert.convert(jsonl, from: .chunksJSONL, to: .chunksMarkdown)
        XCTAssertTrue(md.contains("## # A"))
        XCTAssertTrue(md.contains("Một"))
        // Chuyển đổi mà mất trường là chuyển đổi một chiều.
        XCTAssertTrue(md.contains("id=c1"), md)
        XCTAssertTrue(md.contains("source=tài liệu.md"), md)
    }

    func testCSVsangJSONLroiNguocLaiGiuDuTruong() throws {
        let csv = "id,text\nc1,Một\nc2,\"Hai, ba\"\n"
        let jsonl = try KnowledgeConvert.convert(csv, from: .chunksCSV, to: .chunksJSONL)
        let dong = jsonl.split(separator: "\n")
        XCTAssertEqual(dong.count, 2)
        let doi = try JSONSerialization.jsonObject(with: Data(dong[1].utf8)) as? [String: String]
        XCTAssertEqual(try XCTUnwrap(doi)["text"], "Hai, ba", "dấu phẩy trong ô làm vỡ chuyển đổi")
    }

    func testDongJSONLhongThiNOIRAsoDong() {
        XCTAssertThrowsError(
            try KnowledgeConvert.convert("{\"a\":1}\nkhông phải json\n",
                                         from: .chunksJSONL, to: .chunksCSV)
        ) { error in
            XCTAssertTrue("\(error)".contains("dòng 2"), "\(error)")
        }
    }

    /// Markdown → chunk là phép CẮT CHUNK, đã có ở FR-KNW-903. Viết bản thứ hai ở đây sẽ cho ra
    /// chunk KHÁC bản xem trước người dùng vừa nhìn.
    func testMarkdownSangChunkDANsangFRKNW903chuKhongTuLam() {
        XCTAssertThrowsError(
            try KnowledgeConvert.convert("# A\n", from: .chunksMarkdown, to: .chunksJSONL)
        ) { error in
            XCTAssertTrue("\(error)".contains("cắt chunk") || "\(error)".contains("CẮT CHUNK"),
                          "\(error)")
        }
    }

    // MARK: - Đồ thị

    private let dot = """
    digraph {
      a [label="An"];
      b [label="Bình"];
      a -> b [label="biết"];
    }
    """

    func testDOTsangEdgeListRoiNguocLai() throws {
        let edges = try KnowledgeConvert.convert(dot, from: .graphDOT, to: .graphEdgeList)
        XCTAssertTrue(edges.hasPrefix("source\ttarget\tlabel"))
        XCTAssertTrue(edges.contains("a\tb\tbiết"), edges)

        let lai = try KnowledgeConvert.convert(edges, from: .graphEdgeList, to: .graphDOT)
        let g = DOTGraph.parse(lai)
        XCTAssertEqual(g.edges.count, 1)
        XCTAssertEqual(g.edges[0].from, "a")
        XCTAssertEqual(g.edges[0].label, "biết")
    }

    /// Vòng tròn DOT → Mermaid → DOT phải giữ được cạnh. Đây là bài đáng giá nhất của nhóm này:
    /// một bộ đọc Mermaid viết sai vẫn chạy được và vẫn ra một đồ thị TRÔNG hợp lý.
    func testVongTronDOTsangMermaidRoiVeDOT() throws {
        let mermaid = try KnowledgeConvert.convert(dot, from: .graphDOT, to: .graphMermaid)
        let lai = try KnowledgeConvert.convert(mermaid, from: .graphMermaid, to: .graphDOT)
        let g = DOTGraph.parse(lai)
        XCTAssertEqual(g.nodes.count, 2, "mất node: \(lai)")
        XCTAssertEqual(g.edges.count, 1, "mất cạnh: \(lai)")
        XCTAssertEqual(Set(g.nodes.compactMap(\.label)), ["An", "Bình"])
    }

    func testMermaidCoNhanCanh() throws {
        let m = """
        flowchart TD
            n0["An"]
            n1["Bình"]
            n0 -->|biết| n1
        """
        let g = try KnowledgeConvert.mermaidToGraph(m)
        XCTAssertEqual(g.edges.count, 1)
        XCTAssertEqual(g.edges[0].label, "biết")
    }

    /// Loại sơ đồ khác phải NÓI RA TÊN LOẠI, không im lặng ra một đồ thị rỗng — đồ thị rỗng trông
    /// y hệt "file không có gì", và người dùng sẽ đi tìm lỗi ở file nguồn.
    func testSoDoKHONGphaiFlowchartThiNOIRAloai() {
        XCTAssertThrowsError(
            try KnowledgeConvert.mermaidToGraph("sequenceDiagram\n  A->>B: chào\n")
        ) { error in
            XCTAssertTrue("\(error)".contains("sequenceDiagram"), "\(error)")
        }
    }

    func testEdgeListThieuCotBiTUCHOI() {
        XCTAssertThrowsError(
            try KnowledgeConvert.convert("source\na\n", from: .graphEdgeList, to: .graphDOT))
    }

    // MARK: - Xem trước

    /// Xem trước đi qua CHÍNH hàm chuyển đổi rồi mới cắt. Bản xem trước đi đường riêng là cách
    /// chắc chắn để nó nói dối đúng lúc người dùng tin nó.
    func testXemTruocLaNamDongDAUcuaKetQuaTHAT() throws {
        let nhieu = (1 ... 20).map { "{\"id\":\"c\($0)\",\"text\":\"t\($0)\"}" }
            .joined(separator: "\n")
        let day_du = try KnowledgeConvert.convert(nhieu, from: .chunksJSONL, to: .chunksCSV)
        let xem = try KnowledgeConvert.preview(nhieu, from: .chunksJSONL, to: .chunksCSV)

        let dongDayDu = day_du.split(separator: "\n", omittingEmptySubsequences: false)
        let dongXem = xem.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(Array(dongXem.prefix(5)), Array(dongDayDu.prefix(5)))
        XCTAssertEqual(dongXem.last, "…", "phải nói ra là đã cắt bớt")
    }

    func testXemTruocNganHonNamDongThiKhongCatGi() throws {
        let xem = try KnowledgeConvert.preview("{\"a\":\"1\"}", from: .chunksJSONL, to: .chunksCSV)
        XCTAssertFalse(xem.contains("…"))
    }

    func testChuyenSangCHINHnoThiTraNguyenVan() throws {
        XCTAssertEqual(try KnowledgeConvert.convert(dot, from: .graphDOT, to: .graphDOT), dot)
    }
}
