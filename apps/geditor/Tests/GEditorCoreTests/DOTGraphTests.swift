import XCTest
@testable import GEditorCore

/// FR-KNW-905 — đọc DOT và chuyển sang Mermaid (ADR-15 §7).
final class DOTGraphTests: XCTestCase {

    // MARK: - Nhận diện

    func testNHANDIENDOT() {
        XCTAssertTrue(DOTGraph.looksLikeDOT("digraph G { a -> b }", path: nil))
        XCTAssertTrue(DOTGraph.looksLikeDOT("graph { a -- b }", path: nil))
        XCTAssertTrue(DOTGraph.looksLikeDOT("strict digraph { a -> b }", path: nil))
        XCTAssertTrue(DOTGraph.looksLikeDOT("// chú thích\ndigraph G {\n a\n}", path: nil))
        XCTAssertFalse(DOTGraph.looksLikeDOT("flowchart TD\n a --> b", path: nil))
        XCTAssertFalse(DOTGraph.looksLikeDOT("{\"a\":1}", path: nil))
        XCTAssertFalse(DOTGraph.looksLikeDOT("", path: nil))
        // `.dot` cũng là đuôi template Word, nên đuôi MỘT MÌNH không đủ.
        XCTAssertFalse(DOTGraph.looksLikeDOT("nội dung linh tinh", path: "/a/b.dot"))
    }

    // MARK: - Đọc

    func testDOCNODEVaCanhCoBan() {
        let graph = DOTGraph.parse("""
            digraph G {
                a -> b;
                b -> c;
            }
            """)
        XCTAssertTrue(graph.isDirected)
        XCTAssertEqual(graph.name, "G")
        XCTAssertEqual(graph.nodes.map(\.name), ["a", "b", "c"])
        XCTAssertEqual(graph.edges.map { "\($0.from)->\($0.to)" }, ["a->b", "b->c"])
    }

    /// Chuỗi cạnh `a -> b -> c` là HAI cạnh.
    func testCHUOICANHRaHaiCanh() {
        let graph = DOTGraph.parse("digraph { a -> b -> c }")
        XCTAssertEqual(graph.edges.map { "\($0.from)->\($0.to)" }, ["a->b", "b->c"])
    }

    /// Đồ thị VÔ HƯỚNG dùng `--`.
    func testDOTHIVOHUONG() {
        let graph = DOTGraph.parse("graph { a -- b }")
        XCTAssertFalse(graph.isDirected)
        XCTAssertEqual(graph.edges.count, 1)
    }

    func testNHANNODEVaNHANCANH() {
        let graph = DOTGraph.parse("""
            digraph {
                a [label="Bắt đầu", shape=diamond];
                a -> b [label="đồng ý"];
            }
            """)
        XCTAssertEqual(graph.nodes[0].label, "Bắt đầu")
        XCTAssertEqual(graph.nodes[0].shape, "diamond")
        XCTAssertEqual(graph.edges[0].label, "đồng ý")
    }

    /// Tên có dấu nháy và khoảng trắng.
    func testTENCoNhayVaKhoangTrang() {
        let graph = DOTGraph.parse(#"digraph { "Hợp đồng" -> "Biên bản" }"#)
        XCTAssertEqual(graph.nodes.map(\.name), ["Hợp đồng", "Biên bản"])
    }

    /// Chú thích ba kiểu đều bị bỏ, và SỐ DÒNG giữ nguyên.
    ///
    /// Số dòng là điều kiện, không phải tiện lợi: bấm node trên hình nhảy tới dòng nào là dựa
    /// hết vào nó. Một bộ bỏ chú thích làm ngắn văn bản đi sẽ nhảy sai và không có gì báo.
    func testCHUTHICHBiBoNhungSoDongGiuNguyen() {
        let graph = DOTGraph.parse("""
            digraph {
                // chú thích một dòng
                # chú thích kiểu shell
                /* chú thích
                   nhiều dòng */
                a -> b;
            }
            """)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(graph.edges[0].line, 5, "cạnh nằm ở dòng thứ 6 (0-based là 5)")
    }

    /// Dấu `//` bên TRONG chuỗi không phải chú thích.
    func testGACHCHEOTrongChuoiKhongPhaiChuThich() {
        let graph = DOTGraph.parse(#"digraph { a [label="http://vidu.vn"] }"#)
        XCTAssertEqual(graph.nodes.first?.label, "http://vidu.vn")
    }

    /// Nhiều câu lệnh trên một dòng, ngăn bằng `;`.
    func testNHIEUCAULENHTrenMotDong() {
        let graph = DOTGraph.parse("digraph { a -> b; b -> c; c -> a }")
        XCTAssertEqual(graph.edges.count, 3)
    }

    /// Dấu `;` bên trong `[...]` KHÔNG tách câu lệnh.
    func testCHAMPHAYTrongNgoacVuongKhongTachCauLenh() {
        let graph = DOTGraph.parse(#"digraph { a [label="một; hai"]; a -> b }"#)
        XCTAssertEqual(graph.nodes.first?.label, "một; hai")
        XCTAssertEqual(graph.edges.count, 1)
    }

    /// Thuộc tính nằm GIỮA câu lệnh cạnh: phần đuôi KHÔNG được rơi mất.
    ///
    /// `a [label="x"] -> b` không phải dạng DOT người ta hay viết, nhưng nó hợp lệ, và bản đầu
    /// của `splitAttributes` chỉ giữ phần TRƯỚC `[` — nên cả cạnh biến mất trong im lặng. Nhãn
    /// ở vị trí ấy thuộc về CẠNH chứ không thuộc về node, đúng ngữ nghĩa DOT.
    func testTHUOCTINHGiuaCauLenhKhongLamMatPhanDuoi() {
        let graph = DOTGraph.parse(#"digraph { a [label="ghi chú"] -> b }"#)
        XCTAssertEqual(graph.edges.map { "\($0.from)->\($0.to)" }, ["a->b"])
        XCTAssertEqual(graph.edges.first?.label, "ghi chú")
    }

    // MARK: - Nói ra những gì bỏ qua

    /// `subgraph` được đọc PHẲNG, và điều đó được NÓI RA.
    ///
    /// Một sơ đồ vẽ thiếu mà không có gì báo là tệ hơn hẳn một sơ đồ không vẽ.
    func testSUBGRAPHDocPhangVaNoiRa() {
        let graph = DOTGraph.parse("""
            digraph {
                subgraph cluster_0 {
                    a -> b;
                }
                b -> c;
            }
            """)
        XCTAssertEqual(graph.edges.count, 2, "node bên trong subgraph vẫn phải có")
        XCTAssertTrue(graph.warnings.contains { $0.message.contains("subgraph") })
    }

    func testTHUOCTINHMacDinhDuocNoiRaChuKhongNuot() {
        let graph = DOTGraph.parse("""
            digraph {
                node [shape=box];
                rankdir=LR;
                a -> b;
            }
            """)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(graph.warnings.count, 2, "\(graph.warnings)")
        XCTAssertTrue(graph.warnings.contains { $0.message.contains("node") })
        XCTAssertTrue(graph.warnings.contains { $0.message.contains("rankdir") })
    }

    /// Cụm `{a b} -> c` chưa đọc được, và cạnh ấy bị bỏ CÓ BÁO.
    func testCUMOHaiDauCanhDuocBaoLaBoQua() {
        let graph = DOTGraph.parse("digraph { {a b} -> c }")
        XCTAssertTrue(graph.warnings.contains { $0.message.contains("cụm") },
                      "\(graph.warnings)")
    }

    /// Đúng tệp mà bài tự kiểm dùng — để tách "lỗi ở lõi" khỏi "lỗi ở tầng app".
    func testTEPCuaBaiTuKiemCoCanhBao() {
        let graph = DOTGraph.parse("""
            digraph G {
                rankdir=LR;
                subgraph cluster_0 {
                    a -> b;
                }
                b -> c;
            }
            """)
        XCTAssertEqual(graph.nodes.count, 3, "\(graph.nodes)")
        XCTAssertEqual(graph.edges.count, 2, "\(graph.edges)")
        XCTAssertFalse(DOTToMermaid.convert(graph).warnings.isEmpty,
                       "\(graph.warnings)")
    }

    // MARK: - Đồng bộ hai chiều

    /// Dòng KHAI node đè lên dòng nó xuất hiện lần đầu trong một cạnh.
    ///
    /// Bấm một node trên hình thì người dùng muốn tới chỗ ĐỊNH NGHĨA, không tới chỗ nhắc tên.
    func testDONGKHAINodeDeLenDongNhacTen() {
        let graph = DOTGraph.parse("""
            digraph {
                a -> b;
                b [label="Bê"];
            }
            """)
        XCTAssertEqual(graph.line(ofNode: "b"), 2)
        XCTAssertEqual(graph.line(ofNode: "a"), 1)
        // Tra được theo cả NHÃN, vì đường bấm-node nhận diện phần tử bằng chữ hiện trên nó.
        XCTAssertEqual(graph.line(ofNode: "Bê"), 2)
    }

    func testTENNodeTrenMotDong() {
        let graph = DOTGraph.parse("""
            digraph {
                a [label="An"];
                a -> b;
            }
            """)
        XCTAssertEqual(graph.names(onLine: 1), ["An"])
        XCTAssertEqual(Set(graph.names(onLine: 2)), Set(["An", "b"]))
    }

    // MARK: - Chuyển sang Mermaid

    func testCHUYENSANGMermaidGiuCauTruc() {
        let graph = DOTGraph.parse("""
            digraph {
                a [label="Bắt đầu", shape=diamond];
                a -> b [label="đồng ý"];
            }
            """)
        let converted = DOTToMermaid.convert(graph)
        XCTAssertTrue(converted.mermaid.hasPrefix("flowchart TD"))
        XCTAssertTrue(converted.mermaid.contains("n0{\"Bắt đầu\"}"), converted.mermaid)
        XCTAssertTrue(converted.mermaid.contains("n1[\"b\"]"), converted.mermaid)
        XCTAssertTrue(converted.mermaid.contains("n0 -->|\"đồng ý\"| n1"), converted.mermaid)
        XCTAssertEqual(converted.identifiers["n0"], "a")
        XCTAssertEqual(converted.displayToName["Bắt đầu"], "a")
    }

    /// Đồ thị vô hướng dùng `---`, không dùng `-->`.
    func testVOHUONGDungCanhKhongMuiTen() {
        let converted = DOTToMermaid.convert(DOTGraph.parse("graph { a -- b }"))
        XCTAssertTrue(converted.mermaid.contains("n0 --- n1"), converted.mermaid)
        XCTAssertFalse(converted.mermaid.contains("-->"))
    }

    /// Hình LẠ rơi về hộp chứ không bịa — một `box3d` vẽ thành hình thoi sẽ đổi NGHĨA sơ đồ.
    func testHINHLARoiVeHopChuKhongBia() {
        let converted = DOTToMermaid.convert(
            DOTGraph.parse("digraph { a [shape=box3d] }"))
        XCTAssertTrue(converted.mermaid.contains("n0[\"a\"]"), converted.mermaid)
    }

    /// Ký tự phá cú pháp Mermaid được LÀM SẠCH, không để sơ đồ vỡ.
    func testKYTUPhaCuPhapDuocLamSach() {
        let converted = DOTToMermaid.convert(
            DOTGraph.parse(#"digraph { a [label="nói \"xin chào\" và #1"] }"#))
        XCTAssertFalse(converted.mermaid.contains("\"nói \""), converted.mermaid)
        XCTAssertTrue(converted.mermaid.contains("'xin chào'"), converted.mermaid)
        XCTAssertFalse(converted.mermaid.contains("#1"), converted.mermaid)
    }

    /// Cảnh báo của bộ đọc đi THEO sang bản chuyển — không rơi mất giữa hai bước.
    func testCANHBAODiTheoSangBanChuyen() {
        let converted = DOTToMermaid.convert(
            DOTGraph.parse("digraph { rankdir=LR; a -> b }"))
        XCTAssertTrue(converted.warnings.contains { $0.contains("rankdir") },
                      "\(converted.warnings)")
        XCTAssertTrue(converted.warnings[0].hasPrefix("dòng "), "cảnh báo phải kèm số dòng")
    }

    /// Đồ thị RỖNG thì nói ra, không trả một sơ đồ trống.
    func testDOTHIRONGThiNoiRa() {
        let converted = DOTToMermaid.convert(DOTGraph.parse("digraph {}"))
        XCTAssertTrue(converted.warnings.contains { $0.contains("không đọc được node nào") })
    }

    /// Hai lượt chuyển cho kết quả GIỐNG HỆT.
    func testHAILUOTCHUYENGiongHet() {
        let source = """
            digraph G {
                a [label="An"]; b [label="Bình"]; c;
                a -> b [label="gửi"];
                b -> c;
                a -> c;
            }
            """
        let first = DOTToMermaid.convert(DOTGraph.parse(source))
        let second = DOTToMermaid.convert(DOTGraph.parse(source))
        XCTAssertEqual(first, second)
    }

    /// Đường ghép: DOT thật → Mermaid → bộ đọc Mermaid nhận ra đúng loại sơ đồ.
    ///
    /// Bài này canh chỗ hai cụm gặp nhau. Bản chuyển có thể sinh ra chữ trông hợp lý mà
    /// `MermaidDocument` không nhận là sơ đồ nào cả, và khi ấy panel sẽ im lặng không vẽ.
    func testBANCHUYENDuocMermaidNhanRaLaFlowchart() {
        let converted = DOTToMermaid.convert(DOTGraph.parse("""
            digraph {
                "Hợp đồng" -> "Biên bản" [label="kèm theo"];
            }
            """))
        let kind = MermaidDocument.wholeFile(converted.mermaid).kind
        XCTAssertEqual(kind, .flowchart, "\(converted.mermaid)")
    }
}
