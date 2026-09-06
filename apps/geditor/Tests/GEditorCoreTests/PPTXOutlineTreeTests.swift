import XCTest
@testable import GEditorCore

/// Dàn ý PowerPoint — chế độ View của tệp `.pptx`.
final class PPTXOutlineTreeTests: XCTestCase {

    private func tree(_ markdown: String) -> StructureTree {
        StructureTree.powerPoint(markdown: markdown)
    }

    private func labels(_ t: StructureTree, of node: Int) -> [String] {
        t.nodes[node].children.map { t.nodes[$0].label }
    }

    // MARK: - Hình dạng

    func testMOIslideLAmotGOC() {
        let t = tree("""
            ## 1. Mở đầu

            - Bối cảnh
            - Mục tiêu

            ## 2. Kết quả

            - Doanh thu tăng
            """)
        XCTAssertEqual(t.roots.map { t.nodes[$0].label }, ["1. Mở đầu", "2. Kết quả"])
        XCTAssertEqual(labels(t, of: t.roots[0]), ["Bối cảnh", "Mục tiêu"])
        XCTAssertEqual(t.nodes[t.roots[0]].detail, "{2}", "số gạch đầu dòng phải thấy ngay")
        XCTAssertEqual(t.nodes[t.roots[1]].detail, "{1}")
    }

    func testGHIchuGOMvaoMOTnutGAPduoc() {
        // Trải thẳng ghi chú cạnh gạch đầu dòng thì một slide NÓI nhiều trông như một slide CÓ
        // nhiều nội dung — đúng thứ dàn ý phải trả lời được bằng mắt.
        let t = tree("""
            ## 1. Mở đầu

            - Bối cảnh

            > **Ghi chú người trình bày**
            > Nói chậm ở đoạn này
            > Nhắc số liệu quý trước
            """)
        let con = labels(t, of: t.roots[0])
        XCTAssertEqual(con, ["Bối cảnh", "Ghi chú người trình bày"])
        let nhóm = t.nodes[t.roots[0]].children[1]
        XCTAssertEqual(t.nodes[nhóm].kind, .array)
        XCTAssertEqual(t.nodes[nhóm].detail, "[2]")
        XCTAssertEqual(labels(t, of: nhóm), ["Nói chậm ở đoạn này", "Nhắc số liệu quý trước"])
    }

    func testGHIchuCUAslideNAYkhongCHAYsangSLIDEsau() {
        let t = tree("""
            ## 1. Một

            > **Ghi chú người trình bày**
            > A

            ## 2. Hai

            - B
            """)
        XCTAssertEqual(labels(t, of: t.roots[1]), ["B"],
                       "nhóm ghi chú phải đóng lại khi sang slide mới")
    }

    func testSLIDEkhongCOgachDAUdongVANlaMOTgoc() {
        let t = tree("## 1. Chỉ có tiêu đề\n\n\n## 2. Sau\n")
        XCTAssertEqual(t.roots.count, 2)
        XCTAssertEqual(t.nodes[t.roots[0]].detail, "{0}")
    }

    // MARK: - Nhảy về nguồn

    func testMOInutTROdungDONGcuaMINHtrongDANy() {
        let md = "## 1. Mở đầu\n\n- Bối cảnh\n- Mục tiêu\n"
        let bytes = Array(md.utf8)
        let t = tree(md)
        for node in t.nodes {
            XCTAssertTrue(node.canJumpToSource, "nút «\(node.label)» không có khoảng byte")
        }
        XCTAssertEqual(String(decoding: bytes[t.nodes[t.roots[0]].range], as: UTF8.self),
                       "## 1. Mở đầu")
        let bullet = t.nodes[t.nodes[t.roots[0]].children[1]]
        XCTAssertEqual(String(decoding: bytes[bullet.range], as: UTF8.self), "- Mục tiêu")
    }

    func testCHUtiengVIETkhongLAMlechKHOANGbyte() {
        // Nhãn cắt theo KÝ TỰ còn khoảng đo theo BYTE — chỗ kinh điển để lệch.
        let md = "## 1. Đánh giá chất lượng\n\n- Đo đạc ở Huế\n"
        let bytes = Array(md.utf8)
        let t = tree(md)
        let bullet = t.nodes[t.nodes[t.roots[0]].children[0]]
        XCTAssertEqual(String(decoding: bytes[bullet.range], as: UTF8.self), "- Đo đạc ở Huế")
    }

    // MARK: - Hai cách đọc vai trò dòng phải KHỚP

    func testBOsinhVAboQUETnoiCUNGmotCHUYENtrenTEPthat() throws {
        // `PPTXReader.build` ghi vai trò từng dòng ngay trong lượt sinh Markdown; bộ dựng cây
        // đọc lại vai trò ấy từ TIỀN TỐ của dòng. Hai cách đọc độc lập nhau, nên bắt chúng đối
        // chiếu trên tệp `.pptx` THẬT: cái nào trôi thì bài này đỏ.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("data/vanban/ngon-ngu")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?
            .filter { $0.hasSuffix(".pptx") }.sorted() ?? []
        try XCTSkipIf(files.isEmpty, "không có tệp .pptx thật trong data/vanban")

        for name in files {
            let deck = try PPTXReader.read(path: folder.appendingPathComponent(name).path)
            let t = tree(deck.markdown)

            // Số slide theo bộ sinh và số gốc theo bộ quét.
            let titles = deck.outline.filter { $0.role == .title }
            XCTAssertEqual(t.roots.count, titles.count, "\(name): số slide lệch nhau")

            // Từng dòng tiêu đề phải ứng đúng một gốc, và khoảng byte trùng khít.
            for (root, line) in zip(t.roots, titles) {
                XCTAssertEqual(t.nodes[root].range, line.range,
                               "\(name): khoảng byte của slide lệch")
            }
            let bullets = deck.outline.filter { $0.role == .bullet }.count
            let notes = deck.outline.filter { $0.role == .note }.count
            let leaves = t.nodes.filter { $0.kind == .string }.count
            XCTAssertEqual(leaves, bullets + notes, "\(name): số dòng nội dung lệch nhau")

            // Và cây phải nói được điều gì đó — một cây rỗng thì mọi phép đếm trên đều khớp.
            XCTAssertFalse(t.isEmpty, "\(name): cây rỗng")
            for node in t.nodes {
                XCTAssertLessThanOrEqual(node.range.upperBound, Array(deck.markdown.utf8).count,
                                         "\(name): nút «\(node.label)» trỏ ra ngoài dàn ý")
            }
        }
    }
}
