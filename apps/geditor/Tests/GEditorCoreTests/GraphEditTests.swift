import XCTest
@testable import GEditorCore

/// Soạn thảo đồ thị trực quan — FR-KNW-915.
final class GraphEditTests: XCTestCase {

    private let dot = """
    digraph {
        // ghi chú của người dùng
        "a" [label="An"];
        "b" [label="Bình"];
        "a" -> "b" [label="biết"];
    }

    """

    private func apply(_ edits: [TextEdit], to text: String) -> String {
        var b = TextBuffer(text: text)
        b.applyEdits(edits, label: "t")
        return b.text
    }

    // MARK: - Thêm

    func testThemNodeGiuThutLeHienHanh() throws {
        let ra = apply(try GraphEdit.addNode(name: "c", label: "Chi", in: dot), to: dot)
        XCTAssertTrue(ra.contains("    \"c\" [label=\"Chi\"];"), ra)
        // Chú thích của người dùng KHÔNG được mất — công cụ làm mất chú thích thì không ai dùng
        // lần thứ hai.
        XCTAssertTrue(ra.contains("// ghi chú của người dùng"))
        XCTAssertEqual(DOTGraph.parse(ra).nodes.count, 3)
    }

    /// Thụt lề lấy từ chính tệp, không dùng một hằng số. Tệp thụt bằng TAB thì câu mới cũng TAB.
    func testThutLeLayTuCHINHtep() throws {
        let tab = "digraph {\n\t\"a\";\n}\n"
        let ra = apply(try GraphEdit.addNode(name: "b", in: tab), to: tab)
        XCTAssertTrue(ra.contains("\t\"b\";"), ra)
    }

    /// Dòng đầu có thể là chú thích căn lề trái — lấy thụt lề của nó sẽ dán mọi câu mới sát mép.
    func testThutLeLayCaiPHOBIENnhatChuKhongLayDongDau() {
        let text = "digraph {\n// chú thích sát mép\n    \"a\";\n    \"b\";\n}\n"
        XCTAssertEqual(GraphEdit.indent(of: text), "    ")
    }

    func testThemNodeTrungTenBiTUCHOI() {
        XCTAssertThrowsError(try GraphEdit.addNode(name: "a", in: dot))
    }

    func testThemCanh() throws {
        let them = try GraphEdit.addNode(name: "c", in: dot)
        let sau = apply(them, to: dot)
        let ra = apply(try GraphEdit.addEdge(from: "a", to: "c", label: "quen", in: sau), to: sau)
        let g = DOTGraph.parse(ra)
        XCTAssertEqual(g.edges.count, 2)
        XCTAssertTrue(g.edges.contains { $0.from == "a" && $0.to == "c" && $0.label == "quen" })
    }

    /// KHÔNG tự tạo node còn thiếu: người dùng đang kéo từ một node họ NHÌN THẤY, nên nếu một
    /// đầu không có thật thì đó là lỗi của chỗ gọi và im lặng tạo node mới sẽ giấu nó.
    func testThemCanhToiNodeKHONGtonTaiBiTUCHOI() {
        XCTAssertThrowsError(try GraphEdit.addEdge(from: "a", to: "zzz", in: dot)) { e in
            XCTAssertTrue("\(e)".contains("zzz"), "\(e)")
        }
    }

    func testTepKhongCoDauDongBiTUCHOI() {
        XCTAssertThrowsError(try GraphEdit.addNode(name: "x", in: "digraph {\n  \"a\";\n"))
    }

    func testTenNodeCoDauNhayBiTUCHOI() {
        XCTAssertThrowsError(try GraphEdit.addNode(name: "a\"b", in: dot))
        XCTAssertThrowsError(try GraphEdit.addNode(name: "", in: dot))
    }

    // MARK: - Sửa nhãn

    func testDoiNhanNodeDaCoLabel() throws {
        let ra = apply(try GraphEdit.setLabel(of: "a", to: "An Mới", in: dot), to: dot)
        XCTAssertTrue(ra.contains("label=\"An Mới\""), ra)
        XCTAssertFalse(ra.contains("label=\"An\"]"), "nhãn cũ còn sót: \(ra)")
        // Cạnh KHÔNG bị đụng.
        XCTAssertEqual(DOTGraph.parse(ra).edges.count, 1)
    }

    /// Node chưa có `label` thì phải CHÈN thuộc tính, không phải thay — thay một thuộc tính
    /// không tồn tại sẽ không khớp gì và phép sửa im lặng không làm gì.
    func testDoiNhanNodeCHUAcoLabel() throws {
        let text = "digraph {\n    \"a\";\n}\n"
        let ra = apply(try GraphEdit.setLabel(of: "a", to: "An", in: text), to: text)
        XCTAssertEqual(DOTGraph.parse(ra).nodes.first?.label, "An", ra)
    }

    func testDoiNhanNodeCoKhoiThuocTinhKhac() throws {
        let text = "digraph {\n    \"a\" [shape=box];\n}\n"
        let ra = apply(try GraphEdit.setLabel(of: "a", to: "An", in: text), to: text)
        let g = DOTGraph.parse(ra)
        XCTAssertEqual(g.nodes.first?.label, "An", ra)
        XCTAssertEqual(g.nodes.first?.shape, "box", "thuộc tính cũ bị mất: \(ra)")
    }

    /// Node chỉ xuất hiện trong một cạnh thì không có dòng nào để sửa — NÓI RA thay vì sửa nhầm
    /// dòng cạnh.
    func testNodeKhongCoCauLenhKhaiRiengThiNOIRA() {
        let text = "digraph {\n    \"a\" -> \"b\";\n}\n"
        XCTAssertThrowsError(try GraphEdit.setLabel(of: "b", to: "X", in: text))
    }

    // MARK: - Xoá

    /// Bỏ sót phần cạnh là để lại cạnh treo — DOT sẽ tự sinh lại node từ chính những cạnh ấy,
    /// nên node "đã xoá" hiện lại ngay lần vẽ sau.
    func testXoaNodeXoaLuonMOIcanhChamToiNo() throws {
        let ra = apply(try GraphEdit.removeNode("b", in: dot), to: dot)
        let g = DOTGraph.parse(ra)
        XCTAssertFalse(g.nodes.contains { $0.name == "b" }, "node quay lại: \(ra)")
        XCTAssertTrue(g.edges.isEmpty, "còn cạnh treo: \(ra)")
        XCTAssertTrue(ra.contains("\"a\""), "xoá nhầm node khác: \(ra)")
    }

    func testXoaCanhKhongDungToiNodeHaiDau() throws {
        let ra = apply(try GraphEdit.removeEdge(from: "a", to: "b", in: dot), to: dot)
        let g = DOTGraph.parse(ra)
        XCTAssertTrue(g.edges.isEmpty)
        XCTAssertEqual(g.nodes.count, 2, "node hai đầu bị xoá theo: \(ra)")
    }

    func testXoaThuKhongTonTaiBiTUCHOI() {
        XCTAssertThrowsError(try GraphEdit.removeNode("zzz", in: dot))
        XCTAssertThrowsError(try GraphEdit.removeEdge(from: "b", to: "a", in: dot))
    }

    /// Nhiều cạnh cùng chạm một node: mọi khoảng xoá phải áp được cùng lúc mà không dời nhau.
    func testXoaNodeCoNHIEUcanh() throws {
        let text = """
        digraph {
            "a"; "b"; "c";
            "a" -> "b";
            "b" -> "c";
            "c" -> "a";
        }

        """
        let ra = apply(try GraphEdit.removeNode("b", in: text), to: text)
        let g = DOTGraph.parse(ra)
        XCTAssertFalse(g.nodes.contains { $0.name == "b" }, ra)
        XCTAssertEqual(g.edges.count, 1, "chỉ còn c → a: \(ra)")
    }

    // MARK: - Bất biến

    /// Không hàm nào ở đây sửa gì — chúng chỉ TRẢ VỀ sửa đổi. Buffer vẫn là nguồn sự thật duy
    /// nhất, và một `DOTGraph` sửa trong bộ nhớ sẽ là nguồn sự thật thứ hai.
    func testKhongHamNaoTuSuaVanBan() throws {
        let goc = dot
        _ = try GraphEdit.addNode(name: "z", in: dot)
        _ = try GraphEdit.setLabel(of: "a", to: "X", in: dot)
        _ = try GraphEdit.removeNode("b", in: dot)
        XCTAssertEqual(dot, goc)
    }

    /// Mỗi thao tác là MỘT bước hoàn tác — đặc tả đòi nguyên văn.
    func testMoiThaoTacLaMOTbuocHoanTac() throws {
        var b = TextBuffer(text: dot)
        b.applyEdits(try GraphEdit.removeNode("b", in: dot), label: "xoá node")
        let sau = b.text
        XCTAssertNotEqual(sau, dot)
        b.undo()
        XCTAssertEqual(b.text, dot, "một lần hoàn tác phải trả về nguyên trạng")
    }
}
