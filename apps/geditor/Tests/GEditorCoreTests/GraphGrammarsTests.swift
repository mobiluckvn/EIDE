import XCTest
@testable import GEditorCore

/// Grammar và thẩm định cú pháp cho định dạng đồ thị — FR-KNW-904.
final class GraphGrammarsTests: XCTestCase {

    // MARK: - Nhận dạng

    func testNhanDangTheoDuoiFile() {
        XCTAssertEqual(GraphGrammars.Kind.forPath("a.dot"), .dot)
        XCTAssertEqual(GraphGrammars.Kind.forPath("a.gv"), .dot)
        XCTAssertEqual(GraphGrammars.Kind.forPath("q.cypher"), .cypher)
        XCTAssertEqual(GraphGrammars.Kind.forPath("g.ttl"), .turtle)
        XCTAssertEqual(GraphGrammars.Kind.forPath("g.graphml"), .graphml)
    }

    /// Không biết thì trả `nil`. Đoán bừa nghĩa là một tệp `.txt` bị thẩm định theo luật Cypher
    /// và báo hàng loạt lỗi vô nghĩa.
    func testDuoiLaThiTraNilChuKhongDoanBua() {
        XCTAssertNil(GraphGrammars.Kind.forPath("ghi-chu.txt"))
        XCTAssertNil(GraphGrammars.Kind.forPath("khong-co-duoi"))
    }

    // MARK: - Grammar

    func testBonNgonNguDeuCoDuoiRiengVaKhongDungNhau() {
        var thay: [String: String] = [:]
        for ngon_ngu in GraphGrammars.languages {
            for duoi in ngon_ngu.extensions {
                XCTAssertNil(thay[duoi], "đuôi «\(duoi)» khai ở hai ngôn ngữ")
                thay[duoi] = ngon_ngu.name
            }
        }
        XCTAssertEqual(GraphGrammars.languages.count, 4)
    }

    /// Cypher KHÔNG phân biệt hoa thường: người ta gõ cả hai kiểu, và một nửa file không được tô
    /// màu trông như một nửa file bị hỏng.
    func testCypherKhongPhanBietHoaThuong() {
        XCTAssertFalse(GraphGrammars.cypher.caseSensitive)
        XCTAssertTrue(GraphGrammars.dot.caseSensitive, "DOT thì CÓ phân biệt")
    }

    // MARK: - Thẩm định DOT

    func testDOThopLeThiKhongCoLoi() {
        XCTAssertTrue(GraphGrammars.validate("digraph { a -> b; }", kind: .dot).isEmpty)
    }

    /// Đi qua BỘ ĐỌC THẬT (`DOTGraph`), không qua một phép kiểm riêng — một phép kiểm thứ hai sẽ
    /// trôi khỏi bộ đọc và hai bên nói hai chuyện khác nhau về cùng một tệp.
    func testDOThongThiBaoTheoDONGcuaBoDocThat() {
        // `rankdir=LR` là một GÁN THUỘC TÍNH ĐỒ THỊ — `DOTGraph` đọc được nhưng bỏ qua, và nói
        // ra bằng một cảnh báo. Chọn đầu vào này có chủ ý: bản đầu của bài kiểm dùng một DOT mà
        // bộ đọc KHÔNG cảnh báo gì, nên nó so hai danh sách RỖNG và xanh vô nghĩa. Bài tự kiểm
        // giao diện mới bắt được — nó đòi "phải có lỗi" chứ không chỉ đòi "hai bên khớp nhau".
        let text = "digraph {\n  rankdir=LR\n  a -> b;\n}"
        let canh_bao = DOTGraph.parse(text).warnings
        XCTAssertFalse(canh_bao.isEmpty, "đầu vào phải sinh cảnh báo thì bài kiểm mới có nghĩa")

        let chan_doan = GraphGrammars.validate(text, kind: .dot)
        XCTAssertEqual(chan_doan.map(\.line), canh_bao.map(\.line),
                       "chẩn đoán phải khớp NGUYÊN VĂN cảnh báo của bộ đọc")
        XCTAssertEqual(chan_doan.map(\.message), canh_bao.map(\.message))
    }

    // MARK: - Thẩm định Cypher

    func testCypherHopLe() {
        XCTAssertTrue(
            GraphGrammars.validate("MATCH (n) RETURN n", kind: .cypher).isEmpty)
    }

    /// Câu Cypher hay đứng sau vài dòng chú thích, nên neo lỗi vào dòng 0 là chỉ sai chỗ.
    func testCypherHongThiNeoVaoDongCoCHUdauTien() {
        let text = "\n\n// ghi chú\nCÂU NÀY KHÔNG PHẢI CYPHER"
        let d = GraphGrammars.validate(text, kind: .cypher)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].line, 2, "phải neo vào dòng đầu tiên CÓ CHỮ, không phải dòng 0")
    }

    // MARK: - Thẩm định Turtle

    func testTurtleHopLeVoiPrefixDaKhai() {
        let ttl = """
        @prefix ex: <http://example.org/> .
        ex:an ex:biet ex:binh .
        """
        XCTAssertTrue(GraphGrammars.validate(ttl, kind: .turtle).isEmpty,
                      "\(GraphGrammars.validate(ttl, kind: .turtle))")
    }

    func testTurtlePrefixChuaKhai() {
        let d = GraphGrammars.validate("ex:an ex:biet ex:binh .", kind: .turtle)
        XCTAssertTrue(d.contains { $0.message.contains("ex") }, "\(d)")
        XCTAssertEqual(d.first?.line, 0)
    }

    func testTurtleThieuDauChamCuoiCau() {
        let ttl = """
        @prefix ex: <http://example.org/> .
        ex:an ex:biet ex:binh
        """
        XCTAssertTrue(GraphGrammars.validate(ttl, kind: .turtle)
            .contains { $0.message.contains("kết thúc") })
    }

    func testTurtleDauNhayKhongDong() {
        let ttl = """
        @prefix ex: <http://example.org/> .
        ex:an ex:ten "chưa đóng .
        """
        XCTAssertTrue(GraphGrammars.validate(ttl, kind: .turtle)
            .contains { $0.message.contains("nháy") })
    }

    /// Dấu hai chấm bên TRONG một literal không được đọc thành prefix.
    func testDauHaiChamTrongLiteralKhongPhaiPrefix() {
        let ttl = """
        @prefix ex: <http://example.org/> .
        ex:an ex:ghiChu "giờ họp 10:30 nhé" .
        """
        let d = GraphGrammars.validate(ttl, kind: .turtle)
        XCTAssertFalse(d.contains { $0.message.contains("prefix") }, "\(d)")
    }

    func testTurtleBoQuaChuThichVaDongTrang() {
        XCTAssertTrue(GraphGrammars.validate("# chỉ là chú thích\n\n", kind: .turtle).isEmpty)
    }

    // MARK: - Thẩm định GraphML

    func testGraphMLhopLe() {
        let xml = """
        <?xml version="1.0"?>
        <graphml><graph id="g" edgedefault="directed">
        <node id="a"/><node id="b"/><edge source="a" target="b"/>
        </graph></graphml>
        """
        XCTAssertTrue(GraphGrammars.validate(xml, kind: .graphml).isEmpty,
                      "\(GraphGrammars.validate(xml, kind: .graphml))")
    }

    func testGraphMLthieuTheDongThiBaoLoi() {
        let d = GraphGrammars.validate("<graphml><graph></graphml>", kind: .graphml)
        XCTAssertEqual(d.count, 1)
        XCTAssertFalse(d[0].message.isEmpty, "lỗi phải nói được điều gì đó")
    }
}
