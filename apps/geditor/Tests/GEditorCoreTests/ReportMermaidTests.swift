import XCTest
@testable import GEditorCore

/// FR-MMD-003 — khối ```mermaid trong `.greport.md`.
final class ReportMermaidTests: XCTestCase {

    private func buffer() -> TextBuffer {
        TextBuffer(text: "tinh,doanh_thu\nHuế,900000\n")
    }

    private func render(_ text: String) throws -> ReportRenderer.Rendered {
        try ReportRenderer.render(
            try ReportDocument.parse(text), in: buffer(), dialect: .comma)
    }

    private let block = """
        # Quy trình

        ```mermaid
        flowchart TD
          A[Nhận] --> B[Duyệt]
        ```
        """

    /// Lõi KHÔNG vẽ — nó để lại chỗ trống có đánh số, vì vẽ cần một engine JavaScript mà lõi
    /// không được biết tới WebKit (NFR-MNT-01).
    func testLOIDeLaiCHOTRONGCoDanhSo() throws {
        let rendered = try render(block)
        XCTAssertTrue(rendered.failures.isEmpty, "\(rendered.failures)")
        XCTAssertEqual(rendered.succeeded, 1)
        XCTAssertEqual(rendered.mermaid.count, 1)
        XCTAssertEqual(rendered.mermaid[0].blockIndex, 0)
        XCTAssertEqual(rendered.mermaid[0].source, "flowchart TD\n  A[Nhận] --> B[Duyệt]")
        XCTAssertTrue(rendered.html.contains(ReportRenderer.mermaidMarker(0)), rendered.html)
    }

    /// Chỗ trống mang theo MÃ NGUỒN sơ đồ.
    ///
    /// Hai việc: bản HTML dựng từ CLI (không có WebKit) vẫn còn nội dung thật thay vì một ô
    /// trắng, và người đọc bản đã vẽ vẫn xem được mã gốc — sơ đồ là văn bản (ADR-09).
    func testCHOTRONGGiuMaNguonVaNoiViSaoTrong() throws {
        let html = try render(block).html
        XCTAssertTrue(html.contains("A[Nhận] --&gt; B[Duyệt]"), "mã sơ đồ phải còn, đã thoát")
        XCTAssertTrue(html.contains("chưa có sơ đồ"), html)
    }

    func testDIENSVGVaoChoTrong() throws {
        let rendered = try render(block)
        let svg = "<svg id=\"x\"><text>Nhận</text></svg>"
        let filled = ReportRenderer.spliceMermaid(into: rendered.html, svgs: [0: svg])
        XCTAssertTrue(filled.contains(svg), filled)
        XCTAssertFalse(filled.contains(ReportRenderer.mermaidMarker(0)))
        // Điền xong thì khối "chưa vẽ" phải BIẾN MẤT — để lại là một dòng nói sai.
        XCTAssertFalse(filled.contains("chưa có sơ đồ"))
    }

    /// Sơ đồ nào không vẽ được thì giữ nguyên chỗ trống của nó; sơ đồ khác vẫn điền.
    func testMOTSODOHONGKhongKeoTheoSoDoKhac() throws {
        let rendered = try render("""
            ```mermaid
            flowchart TD
              A --> B
            ```

            ```mermaid
            flowchart TD
              C --> D
            ```
            """)
        XCTAssertEqual(rendered.mermaid.count, 2)
        let filled = ReportRenderer.spliceMermaid(
            into: rendered.html, svgs: [1: "<svg id=\"hai\"></svg>"])
        XCTAssertTrue(filled.contains("<svg id=\"hai\"></svg>"))
        XCTAssertTrue(filled.contains(ReportRenderer.mermaidMarker(0)),
                      "sơ đồ chưa vẽ phải giữ nguyên chỗ trống")
        XCTAssertTrue(filled.contains("A --&gt; B"), "và giữ nguyên mã nguồn của nó")
    }

    /// Mốc là một chuỗi CỐ ĐỊNH, nên nhãn node có ký tự HTML cũng không làm phép thay trượt.
    func testNHANNODECoKyTuHTMLKhongPhaPhepThay() throws {
        let rendered = try render("""
            ```mermaid
            flowchart TD
              A["<b>đậm</b> & <chưa đóng"] --> B
            ```
            """)
        let filled = ReportRenderer.spliceMermaid(
            into: rendered.html, svgs: [0: "<svg id=\"ok\"></svg>"])
        XCTAssertTrue(filled.contains("<svg id=\"ok\"></svg>"))
        XCTAssertFalse(filled.contains("<b>đậm</b>"), "nhãn phải được thoát, không thành thẻ")
    }

    func testKHONGCOSODOThiDanhSachRONG() throws {
        let rendered = try render("```query\nSELECT tinh FROM t\n```")
        XCTAssertTrue(rendered.mermaid.isEmpty)
        // Không có gì để điền thì `spliceMermaid` trả lại y nguyên.
        XCTAssertEqual(
            ReportRenderer.spliceMermaid(into: rendered.html, svgs: [:]), rendered.html)
    }

    /// Khối mermaid xen giữa các khối khác phải giữ ĐÚNG thứ tự trong trang.
    func testGIUDUNGTHUTUTrongTrang() throws {
        let rendered = try render("""
            ```query
            SELECT tinh FROM t
            ```

            ```mermaid
            flowchart TD
              A --> B
            ```

            Kết.
            """)
        let body = rendered.html.components(separatedBy: "<main>")[1]
        guard let table = body.range(of: "<table>"),
              let diagram = body.range(of: ReportRenderer.mermaidMarker(1)),
              let tail = body.range(of: "Kết.") else {
            return XCTFail("thiếu một phần: \(body)")
        }
        XCTAssertTrue(table.lowerBound < diagram.lowerBound)
        XCTAssertTrue(diagram.lowerBound < tail.lowerBound)
    }
}
