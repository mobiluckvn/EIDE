import XCTest
@testable import GEditorCore

/// FR-MMD-006 — định dạng lại mã sơ đồ.
final class MermaidFormatterTests: XCTestCase {

    func testTHUTLEChuanHoaTheoKhoi() {
        let out = MermaidFormatter.format("""
            flowchart TD
                    A --> B
            B --> C
            """)
        XCTAssertEqual(out, """
            flowchart TD
              A --> B
              B --> C
            """)
    }

    func testDONGKHAIBAOLuonODauCot() {
        let out = MermaidFormatter.format("      flowchart LR\n  A --> B")
        XCTAssertTrue(out.hasPrefix("flowchart LR\n"), out)
    }

    func testKHOISUBGRAPHThutThemMotCap() {
        let out = MermaidFormatter.format("""
            flowchart TD
            subgraph Nhóm
            A --> B
            end
            C --> D
            """)
        XCTAssertEqual(out, """
            flowchart TD
              subgraph Nhóm
                A --> B
              end
              C --> D
            """)
    }

    /// `else` lùi ra một cấp cho chính nó, nhưng khối vẫn mở — cùng lối `else` của mã.
    func testALTELSEEND() {
        let out = MermaidFormatter.format("""
            sequenceDiagram
            alt Thành công
            App-->>ND: Kết quả
            else Thất bại
            App-->>ND: Báo lỗi
            end
            """)
        XCTAssertEqual(out, """
            sequenceDiagram
              alt Thành công
                App-->>ND: Kết quả
              else Thất bại
                App-->>ND: Báo lỗi
              end
            """)
    }

    /// `state Foo` KHÔNG mở khối; `state Foo {` thì có. Dấu `{` cuối dòng là thứ duy nhất
    /// phân biệt, và nhầm nó thì mọi dòng sau bị thụt sai một cấp cho tới hết tệp.
    func testSTATEMotDongKhongMoKhoi() {
        let out = MermaidFormatter.format("""
            stateDiagram-v2
            state Cho
            Cho --> Chay
            """)
        XCTAssertEqual(out, """
            stateDiagram-v2
              state Cho
              Cho --> Chay
            """)
    }

    func testKHOINGOACNHONCuaER() {
        let out = MermaidFormatter.format("""
            erDiagram
            KHACH_HANG {
            string ma_khach PK
            }
            """)
        XCTAssertEqual(out, """
            erDiagram
              KHACH_HANG {
                string ma_khach PK
              }
            """)
    }

    /// Chú thích giữ NGUYÊN VĂN — đặc tả đòi đúng câu ấy.
    func testCHUTHICHGiuNguyenVan() {
        let out = MermaidFormatter.format("""
            flowchart TD
            %%   bảng   căn   bằng   dấu   cách
            A --> B
            """)
        XCTAssertTrue(out.contains("%%   bảng   căn   bằng   dấu   cách"), out)
        // Và nó được thụt cho thẳng hàng với phần thân.
        XCTAssertTrue(out.contains("\n  %%   bảng"), out)
    }

    /// Frontmatter là YAML: thụt lề trong đó MANG NGHĨA, nên formatter không đụng vào.
    func testFRONTMATTERGiuNguyen() {
        let source = """
            ---
            config:
              theme: dark
            ---
            flowchart TD
            A --> B
            """
        let out = MermaidFormatter.format(source)
        XCTAssertTrue(out.hasPrefix("---\nconfig:\n  theme: dark\n---\n"), out)
        XCTAssertTrue(out.hasSuffix("flowchart TD\n  A --> B"), out)
    }

    func testCHITHIINITGiuOCapHienTai() {
        let out = MermaidFormatter.format("%%{init: {\"theme\":\"dark\"}}%%\nflowchart TD\nA-->B")
        XCTAssertTrue(out.hasPrefix("%%{init: {\"theme\":\"dark\"}}%%\nflowchart TD"), out)
    }

    func testDONGTRONGGiuNguyen() {
        let out = MermaidFormatter.format("flowchart TD\n\nA --> B\n\n\nB --> C")
        XCTAssertEqual(out, "flowchart TD\n\n  A --> B\n\n\n  B --> C")
    }

    func testGIUXUONGDONGCuoiTepNeuNguonCo() {
        XCTAssertTrue(MermaidFormatter.format("flowchart TD\nA-->B\n").hasSuffix("\n"))
        XCTAssertFalse(MermaidFormatter.format("flowchart TD\nA-->B").hasSuffix("\n"))
    }

    func testDINHDANGLAIHaiLanRaKetQuaGiongNhau() {
        let source = """
            flowchart TD
                subgraph Nhóm
              A --> B
                    end
            C --> D
            """
        let once = MermaidFormatter.format(source)
        XCTAssertEqual(MermaidFormatter.format(once), once, "formatter phải ổn định")
    }

    func testDOIBEDAYTHUTLE() {
        let out = MermaidFormatter.format(
            "flowchart TD\nA --> B", options: .init(indent: 4))
        XCTAssertEqual(out, "flowchart TD\n    A --> B")
    }

    // MARK: - Thứ tự khai báo

    func testMACDINHKHONGSapLaiThuTu() {
        let source = """
            sequenceDiagram
              ND->>App: Gửi
              participant App
            """
        XCTAssertEqual(MermaidFormatter.format(source), source)
    }

    func testXINThiGomKhaiBaoLenDau() {
        let out = MermaidFormatter.format("""
            sequenceDiagram
            ND->>App: Gửi
            participant App
            participant CSDL
            App->>CSDL: Ghi
            """, options: .init(declarationOrder: .declarationsFirst))
        XCTAssertEqual(out, """
            sequenceDiagram
              participant App
              participant CSDL

              ND->>App: Gửi
              App->>CSDL: Ghi
            """)
    }

    /// Gom khai báo KHÔNG được kéo dòng ra khỏi khối `subgraph` của nó.
    func testGOMKHAIBAOKhongKeoDongRaKhoiKhoi() {
        let out = MermaidFormatter.format("""
            flowchart TD
            A --> B
            subgraph Nhóm
            C[Trong nhóm]
            C --> D
            end
            """, options: .init(declarationOrder: .declarationsFirst))
        // `C[Trong nhóm]` là khai báo, nhưng nó thuộc về `subgraph` — phải ở nguyên trong khối.
        guard let insideBlock = out.range(of: "C[Trong nhóm]"),
              let blockStart = out.range(of: "subgraph Nhóm"),
              let blockEnd = out.range(of: "end") else {
            return XCTFail(out)
        }
        XCTAssertTrue(blockStart.upperBound < insideBlock.lowerBound)
        XCTAssertTrue(insideBlock.upperBound < blockEnd.lowerBound)
    }

    // MARK: - Nhận ra dòng khai báo

    func testNHANRADONGKHAIBAO() {
        XCTAssertTrue(MermaidFormatter.isDeclaration("participant App"))
        XCTAssertTrue(MermaidFormatter.isDeclaration("A[Nhãn dài]"))
        XCTAssertFalse(MermaidFormatter.isDeclaration("A --> B"))
        XCTAssertFalse(MermaidFormatter.isDeclaration("ND->>App: Gửi"))
        XCTAssertFalse(MermaidFormatter.isDeclaration("%% chú thích"))
    }

    /// Một nhãn CHỨA mũi tên không được làm dòng khai báo bị hiểu nhầm thành cạnh.
    func testMUITENTrongNHANKhongTinh() {
        XCTAssertTrue(MermaidFormatter.isDeclaration("A[Bước 1 --> Bước 2]"))
    }
}

/// FR-MMD-006 — grammar tô màu.
final class MermaidGrammarTests: XCTestCase {

    func testNHANDUOITEPMMD() {
        XCTAssertEqual(
            UserDefinedLanguage.matching(
                path: "/a/b/so-do.mmd", in: [MermaidGrammar.language])?.name,
            "Mermaid")
        XCTAssertNil(
            UserDefinedLanguage.matching(path: "/a/b.txt", in: [MermaidGrammar.language]))
    }

    func testCHUTHICHVaCHUOI() {
        XCTAssertEqual(MermaidGrammar.language.lineComment, "%%")
        // Nháy ĐƠN không mở chuỗi trong Mermaid: nhận nhầm nó thì một chữ `don't` trong nhãn sẽ
        // tô sai từ đó tới hết tệp.
        XCTAssertEqual(MermaidGrammar.language.stringDelimiters, ["\""])
    }

    /// Mọi từ khoá mở đầu sơ đồ phải có trong grammar — nếu không, dòng quan trọng nhất của tệp
    /// lại là dòng duy nhất không được tô.
    func testDUTUKHOAMoDauSoDo() {
        let keywords = Set(MermaidGrammar.language.keywordGroups.values.flatMap { $0 })
        for kind in MermaidDiagramKind.named {
            XCTAssertTrue(keywords.contains(kind.keyword), "thiếu từ khoá \(kind.keyword)")
        }
    }

    func testKHONGCoNHOMRONG() {
        for (group, words) in MermaidGrammar.language.keywordGroups {
            XCTAssertFalse(words.isEmpty, "nhóm «\(group)» rỗng")
        }
    }
}
