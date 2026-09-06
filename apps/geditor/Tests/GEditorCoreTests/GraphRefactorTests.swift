import XCTest
@testable import GEditorCore

/// FR-KNW-916 — tái cấu trúc đồ thị qua changeset duyệt được.
final class GraphRefactorTests: XCTestCase {

    /// Tệp mẫu, số dòng 0-based ghi ngay bên phải để kỳ vọng bên dưới tính tay được.
    private let text = """
        digraph G {
            // A là gốc
            A [label="Alpha"];
            B;
            C;
            A -> B [label="x"];
            A -> C;
            B -> C;
        }
        """
    //   0: digraph G {
    //   1:     // A là gốc
    //   2:     A [label="Alpha"];
    //   3:     B;
    //   4:     C;
    //   5:     A -> B [label="x"];
    //   6:     A -> C;
    //   7:     B -> C;
    //   8: }

    private var graph: DOTGraph { DOTGraph.parse(text) }

    private func applied(_ result: GraphRefactor.Result) -> String {
        EntityResolution.apply(result.edits, to: text)
    }

    // MARK: - Đổi tên

    /// Ba chỗ: dòng khai và hai đầu cạnh. Chú thích KHÔNG tính, nhãn «Alpha» KHÔNG tính.
    func testDOITENBaChoKhongDungChuThich() {
        let result = GraphRefactor.rename("A", to: "Z", in: text, graph: graph)
        XCTAssertEqual(result.edits.count, 3)
        let out = applied(result)
        XCTAssertTrue(out.contains("// A là gốc"), out)
        XCTAssertTrue(out.contains("Z [label=\"Alpha\"];"), out)
        XCTAssertTrue(out.contains("Z -> B"), out)
        XCTAssertTrue(out.contains("Z -> C"), out)
        // «A» chỉ còn trong chú thích — trên đồ thị đọc lại thì không còn node nào tên A.
        XCTAssertFalse(DOTGraph.parse(out).nodes.contains { $0.name == "A" }, out)
    }

    /// **Đổi tên trùng một node đã có là GỘP ngầm — phải báo trước khi áp.**
    func testDOITENTrungNodeDaCoThiBao() {
        let result = GraphRefactor.rename("A", to: "B", in: text, graph: graph)
        XCTAssertFalse(result.edits.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("GỘP") }, "\(result.warnings)")
    }

    func testDOITENNodeKhongCoThiBaoVaKhongSua() {
        let result = GraphRefactor.rename("Q", to: "Z", in: text, graph: graph)
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("không tìm thấy") })
    }

    // MARK: - Gộp

    /// Gộp B vào A.
    ///
    /// Đếm tay: `B` xuất hiện ở dòng 3, 5, 7 → ba phép đổi tên. Sau khi đổi, `B -> C` (dòng 7)
    /// trùng `A -> C` (dòng 6) → xoá trọn dòng 7, và phép đổi tên trên chính dòng ấy bị nuốt.
    /// Còn `A -> B` (dòng 5) thành vòng tự nối.
    func testGOPKhuCanhTrungVaBaoVongTuNoi() {
        let result = GraphRefactor.merge(["A", "B"], into: "A", in: text, graph: graph)
        XCTAssertTrue(result.report.contains { $0.contains("trùng với dòng 7") },
                      "\(result.report)")
        XCTAssertTrue(result.report.contains { $0.contains("khử 1/1 cạnh trùng") },
                      "\(result.report)")
        XCTAssertTrue(result.warnings.contains { $0.contains("VÒNG TỰ NỐI") },
                      "\(result.warnings)")
        let out = applied(result)
        XCTAssertFalse(out.contains("B"), out)
        XCTAssertEqual(out.components(separatedBy: "A -> C").count - 1, 1, out)
        XCTAssertTrue(out.contains("A -> A"), out)
        // Không để lại dòng trống chỗ vừa xoá.
        XCTAssertFalse(out.contains("\n\n"), out)
        // Và văn bản còn lại vẫn đọc được thành đồ thị.
        let again = DOTGraph.parse(out)
        XCTAssertEqual(again.edges.count, 2)
    }

    /// **Dòng có NHIỀU câu lệnh thì không xoá — báo số dòng để người duyệt tự sửa.**
    ///
    /// Bộ đọc chỉ giữ số dòng của cạnh, không giữ phạm vi byte của câu lệnh. Đoán chỗ cắt trên
    /// một dòng hai câu lệnh là cách chắc chắn để làm hỏng tệp mà không ai thấy ngay.
    func testGOPDongNhieuCauLenhThiBaoChuKhongDoan() {
        let dense = """
            digraph G {
                A -> C; B -> C;
            }
            """
        let result = GraphRefactor.merge(
            ["A", "B"], into: "A", in: dense, graph: DOTGraph.parse(dense))
        XCTAssertTrue(result.warnings.contains { $0.contains("dòng 2") }, "\(result.warnings)")
        XCTAssertTrue(result.report.contains { $0.contains("khử 0/1") }, "\(result.report)")
        let out = EntityResolution.apply(result.edits, to: dense)
        XCTAssertEqual(out.components(separatedBy: "A -> C").count - 1, 2, out)
    }

    /// Đồ thị VÔ HƯỚNG: `C -- B` và `A -- C` trùng nhau sau khi gộp B vào A.
    func testGOPTrenDoThiVoHuongKhongPhanBietChieu() {
        let undirected = """
            graph G {
                A -- C;
                C -- B;
            }
            """
        let result = GraphRefactor.merge(
            ["A", "B"], into: "A", in: undirected, graph: DOTGraph.parse(undirected))
        XCTAssertTrue(result.report.contains { $0.contains("khử 1/1") }, "\(result.report)")
        XCTAssertEqual(DOTGraph.parse(
            EntityResolution.apply(result.edits, to: undirected)).edges.count, 1)
    }

    /// Trên đồ thị CÓ HƯỚNG thì đúng cặp ấy KHÔNG trùng — chiều là một phần của quan hệ.
    func testGOPTrenDoThiCoHuongThiChieuTinh() {
        let directed = """
            digraph G {
                A -> C;
                C -> B;
            }
            """
        let result = GraphRefactor.merge(
            ["A", "B"], into: "A", in: directed, graph: DOTGraph.parse(directed))
        XCTAssertFalse(result.report.contains { $0.contains("trùng") }, "\(result.report)")
        XCTAssertEqual(DOTGraph.parse(
            EntityResolution.apply(result.edits, to: directed)).edges.count, 2)
    }

    func testGOPMotMinhKhongLamGi() {
        XCTAssertTrue(GraphRefactor.merge(["A"], into: "A", in: text, graph: graph).isEmpty)
    }

    // MARK: - Tách

    /// Tách A: chuyển cạnh tới C sang A2. Chỉ dòng 6 đổi; dòng 2 và 5 giữ nguyên.
    func testTACHChiChuyenCanhDaChon() {
        let result = GraphRefactor.split(
            "A", movingNeighbours: ["C"], to: "A2", in: text, graph: graph)
        XCTAssertEqual(result.edits.count, 1)
        let out = applied(result)
        XCTAssertTrue(out.contains("A2 -> C"), out)
        XCTAssertTrue(out.contains("A -> B"), out)
        XCTAssertTrue(out.contains("A [label=\"Alpha\"]"), out)
        XCTAssertEqual(DOTGraph.parse(out).edges.count, 3)
    }

    /// **Node mới không được khai riêng, và điều đó được NÓI RA chứ không để người dùng phát hiện.**
    func testTACHNoiRaRangNodeMoiChuaCoCauLenhKhai() {
        let result = GraphRefactor.split(
            "A", movingNeighbours: ["C"], to: "A2", in: text, graph: graph)
        XCTAssertTrue(result.report.contains { $0.contains("KHÔNG được khai riêng") },
                      "\(result.report)")
        XCTAssertFalse(applied(result).contains("A2;"))
    }

    func testTACHDongNhieuCauLenhThiBao() {
        let dense = """
            digraph G {
                A -> B; A -> C;
            }
            """
        let result = GraphRefactor.split(
            "A", movingNeighbours: ["C"], to: "A2", in: dense, graph: DOTGraph.parse(dense))
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("dòng 2") }, "\(result.warnings)")
    }

    func testTACHKhongCoCanhNaoThiBao() {
        let result = GraphRefactor.split(
            "B", movingNeighbours: ["Q"], to: "B2", in: text, graph: graph)
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("không có cạnh nào") })
    }

    func testTACHTenTrungTenCuThiTuChoi() {
        let result = GraphRefactor.split(
            "A", movingNeighbours: ["C"], to: "A", in: text, graph: graph)
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    // MARK: - Trích subgraph

    /// Trích {A, B}: hai node, một cạnh. Hai cạnh còn lại chỉ có MỘT đầu trong lựa chọn.
    func testTRICHChiGiuCanhCoDuHaiDau() {
        let (out, report) = GraphRefactor.extract(["A", "B"], from: graph)
        XCTAssertTrue(report.contains { $0.contains("trích 2 node · 1 cạnh") }, "\(report)")
        XCTAssertTrue(report.contains { $0.contains("bỏ 2 cạnh") }, "\(report)")
        let again = DOTGraph.parse(out)
        XCTAssertEqual(again.nodes.count, 2)
        XCTAssertEqual(again.edges.count, 1)
        XCTAssertTrue(again.isDirected)
        XCTAssertFalse(out.contains("C"), out)
    }

    /// Thuộc tính đi cùng: nhãn node và nhãn cạnh sống sót qua vòng trích.
    func testTRICHGiuThuocTinh() {
        let (out, _) = GraphRefactor.extract(["A", "B"], from: graph)
        let again = DOTGraph.parse(out)
        XCTAssertEqual(again.nodes.first { $0.name == "A" }?.display, "Alpha")
        XCTAssertEqual(again.edges.first?.label, "x")
    }

    /// Tên có khoảng trắng phải được bọc nháy, không thì tệp mới không đọc lại được.
    func testTRICHBocNhayTenCoKhoangTrang() {
        let source = """
            graph G {
                "Nguyễn An" -- "Trần Bình";
            }
            """
        let (out, _) = GraphRefactor.extract(
            ["Nguyễn An", "Trần Bình"], from: DOTGraph.parse(source), name: "phần trích")
        XCTAssertTrue(out.contains("\"phần trích\""), out)
        XCTAssertTrue(out.contains("\"Nguyễn An\" -- \"Trần Bình\""), out)
        let again = DOTGraph.parse(out)
        XCTAssertFalse(again.isDirected)
        XCTAssertEqual(again.edges.count, 1)
    }

    func testTRICHRongVanRaTepHopLe() {
        let (out, report) = GraphRefactor.extract(["Q"], from: graph)
        XCTAssertTrue(report.contains { $0.contains("trích 0 node · 0 cạnh") }, "\(report)")
        XCTAssertTrue(DOTGraph.parse(out).nodes.isEmpty)
    }

    // MARK: - Bản xem trước

    /// Diff kể ĐÚNG những dòng đổi, kèm số dòng 1-based.
    func testDIFFKeTungDong() {
        let result = GraphRefactor.rename("A", to: "Z", in: text, graph: graph)
        let diff = GraphRefactor.diff(result.edits, in: text)
        XCTAssertEqual(diff.count, 3)
        XCTAssertEqual(diff[0], "dòng 3: A [label=\"Alpha\"]; → Z [label=\"Alpha\"];")
        XCTAssertEqual(diff[1], "dòng 6: A -> B [label=\"x\"]; → Z -> B [label=\"x\"];")
        XCTAssertEqual(diff[2], "dòng 7: A -> C; → Z -> C;")
    }

    /// Dòng bị xoá hiện là XOÁ, không hiện thành một dòng rỗng.
    func testDIFFDongBiXoa() {
        let result = GraphRefactor.merge(["A", "B"], into: "A", in: text, graph: graph)
        let diff = GraphRefactor.diff(result.edits, in: text)
        XCTAssertTrue(diff.contains("dòng 8: − B -> C; → XOÁ"), "\(diff)")
    }

    /// **Cắt bớt thì phải NÓI RA đã cắt bao nhiêu.**
    func testDIFFCatBotThiNoiRa() {
        let result = GraphRefactor.rename("A", to: "Z", in: text, graph: graph)
        let diff = GraphRefactor.diff(result.edits, in: text, limit: 2)
        XCTAssertEqual(diff.count, 3)
        XCTAssertEqual(diff.last, "… và 1 dòng nữa")
    }

    func testDIFFRong() {
        XCTAssertTrue(GraphRefactor.diff([], in: text).isEmpty)
    }

    // MARK: - Đếm câu lệnh

    func testDEMCAULENH() {
        XCTAssertEqual(EntityResolution.statementCount("    A -> B;"), 1)
        XCTAssertEqual(EntityResolution.statementCount("    A -> B"), 1)
        XCTAssertEqual(EntityResolution.statementCount("A -> B; A -> C;"), 2)
        XCTAssertEqual(EntityResolution.statementCount("A -> B; A -> C"), 2)
        XCTAssertEqual(EntityResolution.statementCount("   "), 0)
        // Dấu chấm phẩy TRONG chuỗi và trong `[...]` không tính.
        XCTAssertEqual(EntityResolution.statementCount("A [label=\"x; y\"];"), 1)
        XCTAssertEqual(EntityResolution.statementCount("A -> B [a=1; b=2];"), 1)
    }

    // MARK: - Không thao tác nào ghi thẳng

    /// **Vế cứng của đặc tả: mọi phép chỉ trả sửa đổi, văn bản gốc không đổi.**
    func testKHONGPhepNaoGhiThang() {
        let before = text
        _ = GraphRefactor.rename("A", to: "Z", in: text, graph: graph)
        _ = GraphRefactor.merge(["A", "B"], into: "A", in: text, graph: graph)
        _ = GraphRefactor.split("A", movingNeighbours: ["C"], to: "A2", in: text, graph: graph)
        _ = GraphRefactor.extract(["A"], from: graph)
        XCTAssertEqual(text, before)
    }

    /// Sửa đổi trả về luôn TĂNG DẦN và KHÔNG chồng nhau — điều kiện để `apply` đúng.
    func testSUADOITangDanVaKhongChongNhau() {
        for result in [
            GraphRefactor.rename("A", to: "Z", in: text, graph: graph),
            GraphRefactor.merge(["A", "B"], into: "A", in: text, graph: graph),
            GraphRefactor.split("A", movingNeighbours: ["B", "C"], to: "A2", in: text,
                                graph: graph),
        ] {
            var last = 0
            for edit in result.edits {
                XCTAssertGreaterThanOrEqual(edit.range.lowerBound, last)
                last = edit.range.upperBound
            }
        }
    }
}
