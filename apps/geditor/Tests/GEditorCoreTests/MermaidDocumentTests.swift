import XCTest
@testable import GEditorCore

/// FR-MMD-001 · FR-MMD-003 — nhận ra khối sơ đồ và loại của nó.
final class MermaidDocumentTests: XCTestCase {

    // MARK: - Tìm khối

    func testTIMKHOIMermaidTrongMarkdown() {
        let blocks = MermaidDocument.blocks(in: """
            # Tiêu đề

            ```mermaid
            flowchart TD
              A --> B
            ```

            Văn xuôi.

            ```mermaid
            pie
              "a": 1
            ```
            """)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].source, "flowchart TD\n  A --> B")
        XCTAssertEqual(blocks[0].fenceLine, 2)
        XCTAssertEqual(blocks[0].firstContentLine, 3)
        XCTAssertEqual(blocks[1].index, 1)
    }

    /// Khối mã KHÁC không được nhận nhầm, kể cả khi bên trong có chữ «mermaid».
    func testKHOIMAKHACKhongBiNhan() {
        let blocks = MermaidDocument.blocks(in: """
            ```swift
            let x = "```mermaid"
            ```

            ```
            flowchart TD
            ```
            """)
        XCTAssertTrue(blocks.isEmpty, "\(blocks)")
    }

    /// Hàng rào CHƯA đóng vẫn lấy tới hết tệp.
    ///
    /// Người dùng đang GÕ DỞ, và một preview tắt ngóm giữa lúc gõ là một preview người ta thôi
    /// mở. Đây là chỗ cố ý khác `ReportDocument.parse`, vốn ném lỗi cho hàng rào không đóng.
    func testHANGRAOCHUADONGVanLayToiHetTep() {
        let blocks = MermaidDocument.blocks(in: "```mermaid\nflowchart TD\n  A --> B")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].source, "flowchart TD\n  A --> B")
    }

    func testDONGCUAMERMAIDBaoLoiQuyVeDongCuaTAILIEU() {
        let blocks = MermaidDocument.blocks(in: """
            văn xuôi
            văn xuôi

            ```mermaid
            flowchart TD
              A -->
            ```
            """)
        // mermaid báo "dòng 2" của SƠ ĐỒ; trong tài liệu đó là dòng thứ 6 (0-based: 5).
        XCTAssertEqual(blocks[0].documentLine(forDiagramLine: 2), 5)
        XCTAssertEqual(blocks[0].documentLine(forDiagramLine: 1), 4)
        // Số dòng 0 hoặc âm (mermaid đôi khi không nói được dòng) rơi về dòng đầu của khối.
        XCTAssertEqual(blocks[0].documentLine(forDiagramLine: 0), 4)
    }

    func testCATEPLaMOTSoDo() {
        let block = MermaidDocument.wholeFile("flowchart LR\n  A --> B\n")
        XCTAssertEqual(block.fenceLine, 0)
        XCTAssertEqual(block.firstContentLine, 0)
        XCTAssertEqual(block.kind, .flowchart)
    }

    // MARK: - Loại sơ đồ

    func testDUMUOIMOTLOAIDacTaKe() {
        let mẫu: [(String, MermaidDiagramKind)] = [
            ("flowchart TD", .flowchart),
            ("graph LR", .flowchart),
            ("sequenceDiagram", .sequence),
            ("classDiagram", .classDiagram),
            ("stateDiagram-v2", .state),
            ("stateDiagram", .state),
            ("erDiagram", .entityRelationship),
            ("gantt", .gantt),
            ("pie showData", .pie),
            ("mindmap", .mindmap),
            ("timeline", .timeline),
            ("quadrantChart", .quadrant),
            ("gitGraph", .gitGraph),
        ]
        for (line, kind) in mẫu {
            XCTAssertEqual(
                MermaidDiagramKind.from(declaration: line), kind, line)
        }
        XCTAssertEqual(MermaidDiagramKind.named.count, 11)
    }

    /// Loại LẠ vẫn vẽ được, chỉ không có mẫu và trợ giúp.
    ///
    /// Từ chối một loại mà mermaid vẽ được là làm hỏng một tài liệu chạy tốt, chỉ vì bảng liệt
    /// kê của ta cũ hơn thư viện.
    func testLOAILAVanNhanRaTenCuaNo() {
        XCTAssertEqual(
            MermaidDiagramKind.from(declaration: "sankey-beta"), .other("sankey-beta"))
        XCTAssertEqual(
            MermaidDiagramKind.from(declaration: "xychart-beta horizontal"),
            .other("xychart-beta"))
    }

    /// `pie` không được khớp với một từ khoá BẮT ĐẦU bằng `pie`.
    func testTUKHOAKhongKhopNuaChung() {
        XCTAssertEqual(MermaidDiagramKind.from(declaration: "pieces"), .other("pieces"))
        XCTAssertEqual(MermaidDiagramKind.from(declaration: "ganttish"), .other("ganttish"))
        // Nhưng `pie` kèm tham số thì vẫn là `pie`.
        XCTAssertEqual(MermaidDiagramKind.from(declaration: "pie title Doanh thu"), .pie)
    }

    // MARK: - Dòng khai báo

    func testBOQUACHUTHICHVaDONGTRONG() {
        XCTAssertEqual(
            MermaidDocument.declaration(in: "\n\n%% ghi chú\n\nflowchart TD\n  A --> B"),
            "flowchart TD")
    }

    /// Chỉ thị `%%{init}%%` của FR-MMD-007 đứng TRƯỚC dòng khai báo.
    func testBOQUACHITHIINIT() {
        let source = """
            %%{init: {"theme": "dark"}}%%
            sequenceDiagram
              A ->> B: chào
            """
        XCTAssertEqual(MermaidDocument.declaration(in: source), "sequenceDiagram")
        XCTAssertEqual(MermaidDocument.blocks(in: "```mermaid\n" + source + "\n```")[0].kind,
                       .sequence)
    }

    /// Chỉ thị viết TRÀN nhiều dòng cũng phải bỏ qua hết.
    func testCHITHINhieuDong() {
        let source = """
            %%{init: {
              "theme": "base",
              "themeVariables": { "primaryColor": "#ff0000" }
            }}%%
            gantt
              title Kế hoạch
            """
        XCTAssertEqual(MermaidDocument.declaration(in: source), "gantt")
    }

    /// Frontmatter YAML (mermaid 10+ dùng để đặt `title`) cũng đứng trước.
    func testBOQUAFRONTMATTER() {
        let source = """
            ---
            title: Quy trình duyệt
            ---
            flowchart LR
              A --> B
            """
        XCTAssertEqual(MermaidDocument.declaration(in: source), "flowchart LR")
    }

    func testSODORONGThiNoiRa() {
        XCTAssertTrue(MermaidDocument.wholeFile("%% chỉ có chú thích\n\n").isEmpty)
        XCTAssertTrue(MermaidDocument.wholeFile("   \n\n").isEmpty)
        XCTAssertFalse(MermaidDocument.wholeFile("pie\n").isEmpty)
    }
}

/// NFR-MMD-02 — mermaid.js vendor trong kho, phiên bản ghim, không CDN.
final class MermaidAssetTests: XCTestCase {

    func testTIMTHAYTEPTrongCayLamViec() throws {
        guard MermaidAsset.isAvailable else {
            return XCTFail(MermaidAsset.failureReason)
        }
        let path = try XCTUnwrap(MermaidAsset.path)
        XCTAssertTrue(path.hasSuffix("mermaid.min.js"), path)
    }

    func testBANKEKhopVoiTEPThat() throws {
        guard MermaidAsset.isAvailable else { throw XCTSkip(MermaidAsset.failureReason) }
        let manifest = try XCTUnwrap(MermaidAsset.manifest, "thiếu VERSION.json")
        XCTAssertEqual(manifest.name, "mermaid")
        XCTAssertEqual(manifest.license, "MIT")
        XCTAssertFalse(manifest.version.isEmpty)
        // Bản kê ghi bằng máy, nên nó phải khớp tệp thật — NFR-SEC-03.
        XCTAssertTrue(MermaidAsset.verifyChecksum(),
                      "sha256 trong VERSION.json không khớp mermaid.min.js")
        let size = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: XCTUnwrap(MermaidAsset.path))[.size]
                as? Int)
        XCTAssertEqual(size, manifest.bytes)
    }

    /// Tệp phải TỰ ĐẶT biến toàn cục `mermaid` — nếu không thì trang HTML nạp nó xong vẫn không
    /// gọi được gì, và triệu chứng là một preview trắng không lời giải thích.
    func testTEPTuDatBienToanCucMermaid() throws {
        guard let source = MermaidAsset.source() else {
            throw XCTSkip(MermaidAsset.failureReason)
        }
        XCTAssertTrue(source.contains("globalThis[\"mermaid\"]")
            || source.contains("window.mermaid"), "không thấy chỗ gán biến toàn cục")
    }

    /// About phải nói ra phiên bản (NFR-MMD-02).
    func testDONGCHOABOUT() throws {
        guard let manifest = MermaidAsset.manifest else {
            throw XCTSkip(MermaidAsset.failureReason)
        }
        XCTAssertTrue(manifest.aboutLine.contains(manifest.version))
        XCTAssertTrue(manifest.aboutLine.contains("offline"))
    }
}
