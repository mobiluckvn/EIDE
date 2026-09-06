import XCTest
@testable import GEditorCore

/// Tách khối sơ đồ ra tệp riêng và nhúng ngược — FR-MMD-008.
final class MermaidLinkTests: XCTestCase {

    private let doc = """
    # Quy trình

    Đoạn chữ TRƯỚC sơ đồ.

    ```mermaid
    flowchart TD
        A["Nhận hồ sơ"] --> B["Duyệt hồ sơ"]
    ```

    Đoạn chữ SAU sơ đồ.

    """

    private func apply(_ edits: [TextEdit], to text: String) -> String {
        var b = TextBuffer(text: text)
        b.applyEdits(edits, label: "t")
        return b.text
    }

    private func block(_ text: String, _ index: Int = 0) -> MermaidBlock {
        MermaidDocument.blocks(in: text)[index]
    }

    // MARK: - Tách

    func testTachThayThanBangMotDongThamChieu() throws {
        let ra = try MermaidLink.extract(block(doc), in: doc, to: "so-do.mmd")
        let sau = apply(ra.edits, to: doc)
        XCTAssertTrue(sau.contains("%% geditor:file so-do.mmd"), sau)
        XCTAssertFalse(sau.contains("flowchart TD"), "thân cũ còn sót:\n\(sau)")
        // Phần chữ quanh khối KHÔNG được đụng.
        XCTAssertTrue(sau.contains("Đoạn chữ TRƯỚC sơ đồ."), sau)
        XCTAssertTrue(sau.contains("Đoạn chữ SAU sơ đồ."), sau)
        // Và tệp mang đúng nội dung cũ.
        XCTAssertTrue(ra.file.contains("A[\"Nhận hồ sơ\"] --> B[\"Duyệt hồ sơ\"]"), ra.file)
    }

    /// Hàng rào vẫn phải đóng mở đúng — khối sau khi tách vẫn là một khối mermaid hợp lệ.
    func testKhoiSauKhiTachVanLaMotKhoiMermaid() throws {
        let sau = apply(try MermaidLink.extract(block(doc), in: doc, to: "s.mmd").edits, to: doc)
        let blocks = MermaidDocument.blocks(in: sau)
        XCTAssertEqual(blocks.count, 1, sau)
        XCTAssertEqual(MermaidLink.reference(in: blocks[0].source), "s.mmd")
    }

    /// Tệp kết thúc bằng xuống dòng: thiếu nó thì `git diff` báo "\\ No newline at end of file"
    /// ở mọi lần sửa sau đó.
    func testTepTachRaKetThucBangXuongDong() throws {
        let ra = try MermaidLink.extract(block(doc), in: doc, to: "s.mmd")
        XCTAssertTrue(ra.file.hasSuffix("\n"), "«\(ra.file)»")
    }

    func testTachHaiLanBiTUCHOI() throws {
        let sau = apply(try MermaidLink.extract(block(doc), in: doc, to: "s.mmd").edits, to: doc)
        XCTAssertThrowsError(try MermaidLink.extract(block(sau), in: sau, to: "t.mmd")) { e in
            XCTAssertTrue("\(e)".contains("s.mmd"), "\(e)")
        }
    }

    /// Tệp `.mmd` thuần đã là một sơ đồ rời — tách nữa là tạo ra một tệp trỏ vào chính nó.
    func testTachTepMmdThuanBiTUCHOI() {
        let text = "flowchart TD\n    A --> B\n"
        XCTAssertThrowsError(
            try MermaidLink.extract(MermaidDocument.wholeFile(text), in: text, to: "s.mmd"))
    }

    func testTachKhoiRONGbiTUCHOI() {
        let text = "```mermaid\n\n```\n"
        XCTAssertThrowsError(try MermaidLink.extract(block(text), in: text, to: "s.mmd"))
    }

    /// Khối nằm trong một mục danh sách thì cả thân thụt theo — dòng tham chiếu cũng phải thế,
    /// nếu không hàng rào đóng và dòng tham chiếu lệch nhau và Markdown vỡ.
    func testGiuThutLeCuaHangRao() throws {
        let text = "- Mục:\n\n  ```mermaid\n  flowchart TD\n      A --> B\n  ```\n"
        let sau = apply(try MermaidLink.extract(block(text), in: text, to: "s.mmd").edits, to: text)
        XCTAssertTrue(sau.contains("  %% geditor:file s.mmd"), sau)
    }

    // MARK: - Nhúng ngược

    func testNhungNguocTraVeNguyenTrang() throws {
        let than = "flowchart TD\n    A[\"Nhận hồ sơ\"] --> B[\"Duyệt hồ sơ\"]"
        let sau = apply(try MermaidLink.extract(block(doc), in: doc, to: "s.mmd").edits, to: doc)
        let lai = apply(
            try MermaidLink.embed(block(sau), in: sau, content: than + "\n"), to: sau)
        XCTAssertEqual(lai, doc, "vòng tách → nhúng không khép kín:\n\(lai)")
    }

    func testNhungVaoKhoiKhongPhaiThamChieuBiTUCHOI() {
        XCTAssertThrowsError(try MermaidLink.embed(block(doc), in: doc, content: "flowchart TD\n"))
    }

    /// Tệp được tham chiếu rỗng thì nhúng vào là MẤT LUÔN sơ đồ — nói ra thay vì làm.
    func testNhungTepRONGbiTUCHOI() throws {
        let sau = apply(try MermaidLink.extract(block(doc), in: doc, to: "s.mmd").edits, to: doc)
        XCTAssertThrowsError(try MermaidLink.embed(block(sau), in: sau, content: "\n\n"))
    }

    func testNhungGiuThutLeCuaHangRao() throws {
        let text = "- Mục:\n\n  ```mermaid\n  %% geditor:file s.mmd\n  ```\n"
        let sau = apply(
            try MermaidLink.embed(block(text), in: text, content: "flowchart TD\n    A --> B\n"),
            to: text)
        XCTAssertTrue(sau.contains("  flowchart TD"), sau)
        XCTAssertTrue(sau.contains("      A --> B"), sau)
    }

    // MARK: - Đọc tham chiếu

    func testDocThamChieu() {
        XCTAssertEqual(MermaidLink.reference(in: "%% geditor:file a/b.mmd"), "a/b.mmd")
        XCTAssertEqual(
            MermaidLink.reference(in: "%% ghi chú\n  %% geditor:file s.mmd\n"), "s.mmd")
        XCTAssertNil(MermaidLink.reference(in: "flowchart TD\n  A --> B"))
        // Chú thích của người dùng KHÔNG được nhận nhầm là tham chiếu.
        XCTAssertNil(MermaidLink.reference(in: "%% file so-do.mmd"))
        XCTAssertNil(MermaidLink.reference(in: "%% geditor:file   "))
    }

    /// Khối tham chiếu vẫn là mermaid ĐÚNG CÚ PHÁP — nó chỉ là một chú thích.
    func testKhoiThamChieuKhongCoDongKhaiBao() {
        XCTAssertNil(MermaidDocument.declaration(in: MermaidLink.referenceBody("s.mmd")))
    }

    /// Khối đọc từ một văn bản KHÁC với văn bản đang sửa: số dòng khi ấy vô nghĩa, và áp bừa sẽ
    /// ghi đè lên một đoạn chẳng liên quan.
    func testKhoiKhongKhopTaiLieuThiTUCHOI() {
        let lac = MermaidBlock(source: "flowchart TD", fenceLine: 900,
                               firstContentLine: 901, index: 0, contentLineCount: 1)
        XCTAssertThrowsError(try MermaidLink.extract(lac, in: doc, to: "s.mmd"))
    }

    // MARK: - Tam giác chuyển đổi (FR-MMD-008 mở rộng FR-KNW-910)

    func testTamGiacMermaidDOTedgeListKhepKin() throws {
        let mermaid = "flowchart TD\n    A[\"Nhận\"] --> B[\"Duyệt\"]\n"
        let edge = try KnowledgeConvert.convert(
            mermaid, from: .graphMermaid, to: .graphEdgeList)
        XCTAssertTrue(edge.contains("A\tB"), edge)

        let lai = try KnowledgeConvert.convert(edge, from: .graphEdgeList, to: .graphMermaid)
        let g = MermaidEdit.parse(lai)
        XCTAssertEqual(g.kind, .flowchart, lai)
        // ĐỊNH DANH KHÔNG được giữ, và đó là một tính chất đã biết của `DOTToMermaid` chứ không
        // phải lỗi ở đây: tên node DOT có thể chứa ký tự mermaid không nhận, nên bộ chuyển luôn
        // đặt lại `n0`, `n1`… và đưa tên gốc vào NHÃN. Bài kiểm chấm đúng cái được giữ.
        let nhan = g.edges.compactMap { canh -> (String, String)? in
            guard let a = g.node(canh.from)?.display, let b = g.node(canh.to)?.display
            else { return nil }
            return (a, b)
        }
        XCTAssertTrue(nhan.contains { $0 == "A" && $1 == "B" }, lai)

        let dot = try KnowledgeConvert.convert(mermaid, from: .graphMermaid, to: .graphDOT)
        XCTAssertTrue(DOTGraph.parse(dot).edges.contains { $0.from == "A" && $0.to == "B" }, dot)
    }
}
