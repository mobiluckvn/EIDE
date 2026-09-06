import XCTest
@testable import GEditorCore

/// Schema / ontology cho đồ thị — FR-KNW-917.
final class GraphSchemaTests: XCTestCase {

    private func schema(_ yaml: String) throws -> GraphSchema {
        try GraphSchema.parse(yaml)
    }

    private func graph(_ dot: String) throws -> DOTGraph {
        try DOTGraph.parse(dot)
    }

    private let hopLe = """
    node_types:
      Person:
        required:
          name: string
          age: number
      Organization:
        required:
          name: string
    edge_types:
      works_at:
        between:
          - [Person, Organization]
      related_to: {}
    """

    // MARK: - Đọc schema

    func testDocDuocLoaiNodeVaCanh() throws {
        let s = try schema(hopLe)
        XCTAssertEqual(s.nodeTypes.map(\.name), ["Person", "Organization"])
        XCTAssertEqual(s.edgeTypes.map(\.name), ["works_at", "related_to"])
        XCTAssertEqual(s.typeAttribute, "type")
    }

    /// Gõ nhầm `node_type:` thay vì `node_types:` mà bị im lặng bỏ qua thì kết quả là "không có
    /// vi phạm nào" — câu trả lời sai theo đúng hướng nguy hiểm nhất.
    func testKhoaLaBiTUCHOIchuKhongImLangBoQua() {
        XCTAssertThrowsError(try schema("node_type:\n  Person: {}\n")) { error in
            XCTAssertTrue("\(error)".contains("node_type"), "\(error)")
        }
    }

    func testSchemaKhongKhaiLoaiNaoBiTUCHOI() {
        XCTAssertThrowsError(try schema("type_attribute: loai\n"))
    }

    func testBetweenSaiHinhDangBiTUCHOI() {
        XCTAssertThrowsError(try schema("""
        edge_types:
          x:
            between:
              - [A]
        """))
    }

    // MARK: - Kiểm đồ thị

    func testDoThiDUNGschemaThiKhongCoViPham() throws {
        let g = try graph("""
        digraph {
          an [type=Person, name="An", age="30"];
          cty [type=Organization, name="An Phát"];
          an -> cty [type=works_at];
        }
        """)
        XCTAssertTrue(try schema(hopLe).validate(g).isEmpty)
    }

    func testNodeKhongKhaiBao() throws {
        let g = try graph("""
        digraph {
          x [type=Alien, name="?"];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.count, 1)
        XCTAssertEqual(v[0].kind, .unknownNodeType)
        // Phải nói ra NHÃN nó thấy: người sửa còn phải quyết định là dữ liệu sai hay schema thiếu.
        XCTAssertTrue(v[0].detail.contains("Alien"), v[0].detail)
    }

    func testThieuThuocTinhBatBuoc() throws {
        let g = try graph("""
        digraph {
          an [type=Person, name="An"];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.map(\.kind), [.missingProperty])
        XCTAssertTrue(v[0].detail.contains("age"), v[0].detail)
    }

    func testSaiKieuDuLieu() throws {
        let g = try graph("""
        digraph {
          an [type=Person, name="An", age="ba mươi"];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.map(\.kind), [.wrongPropertyType])
        XCTAssertTrue(v[0].detail.contains("number"), v[0].detail)
    }

    func testCanhSaiLoai() throws {
        let g = try graph("""
        digraph {
          a [type=Person, name="A", age="1"];
          b [type=Person, name="B", age="2"];
          a -> b [type=works_at];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.map(\.kind), [.edgeBetweenWrongTypes])
        XCTAssertTrue(v[0].detail.contains("Person"), v[0].detail)
    }

    /// `between` RỖNG nghĩa là "mọi cặp", KHÔNG phải "không cặp nào". Hiểu ngược lại thì một
    /// schema chưa khai quan hệ nào sẽ báo mọi cạnh đều sai, và người dùng tắt hẳn tính năng
    /// thay vì sửa schema.
    func testBetweenRONGnghiaLaMOICAPchuKhongPhaiCAMTAT() throws {
        let g = try graph("""
        digraph {
          a [type=Person, name="A", age="1"];
          b [type=Organization, name="B"];
          a -> b [type=related_to];
          b -> a [type=related_to];
        }
        """)
        XCTAssertTrue(try schema(hopLe).validate(g).isEmpty)
    }

    func testCanhKhongKhaiBao() throws {
        let g = try graph("""
        digraph {
          a [type=Person, name="A", age="1"];
          b [type=Organization, name="B"];
          a -> b [type=hates];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.map(\.kind), [.unknownEdgeType])
    }

    // MARK: - Số dòng và thứ tự

    /// Đặc tả đòi "click nhảy đúng dòng định nghĩa", nên mọi vi phạm phải mang số dòng THẬT.
    func testMoiViPhamMangSoDongThat() throws {
        let g = try graph("""
        digraph {
          a [type=Alien];
          b [type=Alien];
        }
        """)
        let v = try schema(hopLe).validate(g)
        XCTAssertEqual(v.count, 2)
        // 0-BASED, theo đúng quy ước của `DOTGraph.line` — xem ghi chú ở `Violation.line`.
        XCTAssertEqual(v.map(\.line), [1, 2], "số dòng phải theo đúng file, 0-based")
    }

    func testKetQuaTATDINHvaSapTheoDong() throws {
        let g = try graph("""
        digraph {
          z [type=Alien];
          a [type=Alien];
        }
        """)
        let s = try schema(hopLe)
        XCTAssertEqual(s.validate(g).map(\.line), s.validate(g).map(\.line))
        XCTAssertEqual(s.validate(g).map(\.line), [1, 2])
    }

    // MARK: - Template

    /// Template phải CHẠY ĐƯỢC ngay, không phải một khung rỗng: một mẫu phải sửa mới dùng được
    /// thì người ta bỏ qua và tự gõ từ đầu.
    func testTemplateDocDuocVaKiemDuocMotDoThiThat() throws {
        let s = try GraphSchema.parse(GraphSchema.template)
        XCTAssertEqual(Set(s.nodeTypes.map(\.name)), ["Person", "Organization", "Location"])

        let g = try graph("""
        digraph {
          an [type=Person, name="An"];
          cty [type=Organization, name="An Phát"];
          hn [type=Location, name="Hà Nội"];
          an -> cty [type=works_at];
          cty -> hn [type=located_in];
        }
        """)
        XCTAssertTrue(s.validate(g).isEmpty, "\(s.validate(g))")
    }

    func testKieuLaThiKHONGphanChuKhongDoanBua() {
        XCTAssertTrue(GraphSchema.hopKieu("bất kỳ", "kiểu-lạ"))
        XCTAssertTrue(GraphSchema.hopKieu("42", "number"))
        XCTAssertFalse(GraphSchema.hopKieu("x", "number"))
        XCTAssertTrue(GraphSchema.hopKieu("true", "boolean"))
    }
}
