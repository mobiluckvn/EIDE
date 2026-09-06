import XCTest
@testable import GEditorCore

/// Bộ dựng cây YAML — nền cho chế độ View của YAML.
final class YAMLIndexTests: XCTestCase {

    private func tree(_ yaml: String) -> StructureTree { StructureTree.yaml(text: yaml) }

    private func labels(_ t: StructureTree, of node: Int) -> [String] {
        t.nodes[node].children.map { t.nodes[$0].label }
    }

    // MARK: - Hình dạng

    func testANHxaLONGnhauRAdungTANGvaDUNGnhan() {
        let t = tree("""
            máy_chủ:
              tên: web-01
              cổng: 8080
            """)
        XCTAssertNil(t.failure, t.failure ?? "")
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.label, "$", "một tài liệu thì gốc là $, đúng ký hiệu JSONPath")
        XCTAssertEqual(labels(t, of: t.roots[0]), ["máy_chủ"])
        let server = root.children[0]
        XCTAssertEqual(t.nodes[server].kind, .object)
        XCTAssertEqual(labels(t, of: server), ["tên", "cổng"])
        XCTAssertEqual(t.nodes[t.nodes[server].children[0]].detail, "web-01")
    }

    func testDAYnamNGANGvoiKHOAcuaNO() {
        // `cổng:` rồi `- 80` cùng cột 0 là YAML hợp lệ và là lối viết phổ biến nhất trong thực
        // tế. Bộ dựng nào bắt buộc dãy phải thụt vào sẽ treo cả tệp lên nút gốc.
        let t = tree("""
            cổng:
            - 80
            - 443
            """)
        XCTAssertNil(t.failure, t.failure ?? "")
        let cong = t.nodes[t.roots[0]].children[0]
        XCTAssertEqual(t.nodes[cong].label, "cổng")
        XCTAssertEqual(t.nodes[cong].kind, .array)
        XCTAssertEqual(labels(t, of: cong), ["[0]", "[1]"])
        XCTAssertEqual(t.nodes[t.nodes[cong].children[1]].detail, "443")
    }

    func testDAYthutVAOcungRAcungMOTcay() {
        let ngang = tree("a:\n- 1\n- 2\n")
        let thut = tree("a:\n  - 1\n  - 2\n")
        XCTAssertEqual(ngang.nodes.map(\.label), thut.nodes.map(\.label),
                       "hai lối thụt lề của cùng một dãy phải cho cùng một cây")
    }

    func testMUCdayCHUAanhXAtrenCUNGdong() {
        let t = tree("""
            dịch_vụ:
              - tên: web
                cổng: 80
              - tên: db
                cổng: 5432
            """)
        XCTAssertNil(t.failure, t.failure ?? "")
        let dv = t.nodes[t.roots[0]].children[0]
        XCTAssertEqual(labels(t, of: dv), ["[0]", "[1]"])
        let item = t.nodes[dv].children[0]
        XCTAssertEqual(t.nodes[item].kind, .object)
        XCTAssertEqual(labels(t, of: item), ["tên", "cổng"])
        XCTAssertEqual(t.nodes[t.nodes[item].children[0]].detail, "web")
    }

    func testNUTchuaHIENsoPHANtu() {
        let t = tree("a:\n  b: 1\n  c: 2\nd:\n- x\n")
        let root = t.nodes[t.roots[0]]
        XCTAssertEqual(root.detail, "{2}")
        XCTAssertEqual(t.nodes[root.children[0]].detail, "{2}")
        XCTAssertEqual(t.nodes[root.children[1]].detail, "[1]")
    }

    // MARK: - Kiểu giá trị

    func testNHAYlaTHUphanBIETchuVOIso() {
        // Cả điểm của dấu nháy trong YAML. Bỏ qua nó thì cây tô `"42"` và `42` cùng một màu,
        // đúng ngay chỗ người ta mở cây ra để phân biệt hai thứ ấy.
        let t = tree("a: 42\nb: \"42\"\nc: true\nd: \"true\"\ne: null\nf: 3.5\ng: xin_chào\n")
        let kinds = t.nodes[t.roots[0]].children.map { t.nodes[$0].kind }
        XCTAssertEqual(kinds, [.number, .string, .bool, .string, .null, .number, .string])
        XCTAssertEqual(t.nodes[t.nodes[t.roots[0]].children[1]].detail, "42",
                       "nháy bị bỏ khi HIỆN, chỉ giữ lại ở phần kiểu")
    }

    // MARK: - Ba chỗ cố tình làm nông

    func testTAPhopDANGdongLAmotLA() {
        let t = tree("cổng: [80, 443]\nnhãn: {vai: web}\n")
        let con = t.nodes[t.roots[0]].children.map { t.nodes[$0] }
        XCTAssertTrue(con.allSatisfy { $0.children.isEmpty }, "tập hợp dạng dòng phải là lá")
        XCTAssertEqual(con[0].detail, "[80, 443]", "nội dung hiện nguyên văn, không bung ra")
        XCTAssertEqual(con[1].detail, "{vai: web}")
    }

    func testANCHORvaALIASdiVAOgiaTRInguyenVAN() {
        // `YAMLReader` ném lỗi ở đây. Khung nhìn thì không được — người dùng mở tệp ra để XEM.
        let t = tree("gốc: &mac\n  a: 1\nsao: *mac\n")
        XCTAssertNil(t.failure, t.failure ?? "")
        let con = t.nodes[t.roots[0]].children.map { t.nodes[$0] }
        XCTAssertEqual(con.map(\.label), ["gốc", "sao"])
        XCTAssertEqual(con[1].detail, "*mac")
    }

    // MARK: - Khối chữ

    func testKHOIchuGIUnguyenLAvaKHONGdoiDONGthanhKHOA() {
        // Tệp workflow nào cũng có `run: |`. Trong khối ấy, dòng không có dấu `:` là chuyện bình
        // thường, `#` là nội dung chứ không phải chú thích, và Tab không phải lỗi thụt lề.
        let t = tree("""
            bước:
              chạy: |
                swift build   # dựng
                swift test
              tên: dựng
            """)
        XCTAssertNil(t.failure, t.failure ?? "")
        let bước = t.nodes[t.roots[0]].children[0]
        XCTAssertEqual(labels(t, of: bước), ["chạy", "tên"],
                       "dòng trong khối chữ không được thành khoá")
        let chạy = t.nodes[t.nodes[bước].children[0]]
        XCTAssertEqual(chạy.kind, .string)
        XCTAssertTrue(chạy.detail.contains("swift build   # dựng"), chạy.detail)
        XCTAssertTrue(chạy.detail.contains("swift test"), chạy.detail)
    }

    func testKHOIchuBAOtronCAcacDONGnoiDUNG() {
        let yaml = "chạy: |\n  một\n  hai\ntên: x\n"
        let bytes = Array(yaml.utf8)
        let t = tree(yaml)
        let chạy = t.nodes[t.nodes[t.roots[0]].children[0]]
        XCTAssertEqual(String(decoding: bytes[chạy.range], as: UTF8.self), "chạy: |\n  một\n  hai",
                       "khoảng byte phải bao trọn khoá và cả khối chữ dưới nó")
    }

    func testDONGtrangTRONGkhoiCHUkhongDONGkhoi() {
        let t = tree("chạy: |\n  một\n\n  hai\ntên: x\n")
        XCTAssertNil(t.failure, t.failure ?? "")
        XCTAssertEqual(labels(t, of: t.roots[0]), ["chạy", "tên"])
    }

    func testBIENtheDAUmoKHOIdeuDUOCnhanRA() {
        for dấu in ["|", "|-", "|+", ">", ">-", "|2"] {
            let t = tree("a: \(dấu)\n  nội dung\nb: 1\n")
            XCTAssertNil(t.failure, "\(dấu): \(t.failure ?? "")")
            XCTAssertEqual(labels(t, of: t.roots[0]), ["a", "b"], "\(dấu)")
        }
    }

    func testKHOIchuTRONGmucDAY() {
        let t = tree("- |\n  một\n- hai\n")
        XCTAssertNil(t.failure, t.failure ?? "")
        XCTAssertEqual(labels(t, of: t.roots[0]), ["[0]", "[1]"])
    }

    // MARK: - Nhiều tài liệu

    func testBAtaiLIEUraBAgocCOsoTHUtu() {
        let t = tree("a: 1\n---\nb: 2\n---\nc: 3\n")
        XCTAssertNil(t.failure, t.failure ?? "")
        XCTAssertEqual(t.roots.count, 3)
        XCTAssertEqual(t.roots.map { t.nodes[$0].label }, ["$", "$2", "$3"],
                       "ba gốc cùng tên `$` thì không phân biệt được cái nào là cái nào")
        XCTAssertEqual(labels(t, of: t.roots[1]), ["b"])
    }

    func testDAUtaiLIEUmoDAUtepKHONGsinhGOCrong() {
        let t = tree("---\na: 1\n")
        XCTAssertEqual(t.roots.count, 1)
        XCTAssertEqual(labels(t, of: t.roots[0]), ["a"])
    }

    // MARK: - Chú thích và dấu hai chấm

    func testCHUthichBIbiCATkhoiGIAtriNHUNGkhongCATtrongNHAY() {
        let t = tree("a: web  # máy chủ chính\nb: \"x # y\"\n")
        let con = t.nodes[t.roots[0]].children.map { t.nodes[$0] }
        XCTAssertEqual(con[0].detail, "web")
        XCTAssertEqual(con[1].detail, "x # y", "dấu # trong nháy là nội dung, không phải chú thích")
    }

    func testHAIchamKHONGcoKHOANGtrangKHONGcatKHOA() {
        // `http://máy-chủ` mà cắt ở `:` thì cây mọc ra một khoá `http` không có thật.
        let t = tree("địa_chỉ: http://máy-chủ:8080/đường-dẫn\n")
        let con = t.nodes[t.roots[0]].children.map { t.nodes[$0] }
        XCTAssertEqual(con.map(\.label), ["địa_chỉ"])
        XCTAssertEqual(con[0].detail, "http://máy-chủ:8080/đường-dẫn")
    }

    func testDONGtrangVAdongCHUthichKHONGthanhNUT() {
        let t = tree("# đầu tệp\n\na: 1\n\n# giữa\nb: 2\n")
        XCTAssertEqual(labels(t, of: t.roots[0]), ["a", "b"])
    }

    // MARK: - Khoảng byte

    func testKHOAnaoCUNGtroDUNGvaoKHOAcuaMINHtrongNGUON() {
        let yaml = "máy_chủ:\n  cổng: 8080\n"
        let bytes = Array(yaml.utf8)
        let t = tree(yaml)
        let server = t.nodes[t.roots[0]].children[0]
        XCTAssertEqual(bytes[t.nodes[server].range.lowerBound...].starts(with: Array("máy_chủ".utf8)),
                       true, "nút phải trỏ vào đầu KHOÁ, không vào giá trị")
        let port = t.nodes[server].children[0]
        XCTAssertEqual(String(decoding: bytes[t.nodes[port].range], as: UTF8.self), "cổng: 8080",
                       "lá bao trọn cặp khoá–giá trị")
    }

    func testMOInutBIETminhNAMoDAU() {
        let t = tree("a:\n  b: 1\nc:\n- 2\n")
        for node in t.nodes {
            XCTAssertTrue(node.canJumpToSource, "nút «\(node.label)» không có khoảng byte")
        }
    }

    // MARK: - Từ chối chứ không dựng nửa vời

    func testTABtrongTHUTleBIbatVAnoiRA() {
        // Trình soạn thảo vẽ Tab rộng bằng bốn dấu cách nên mắt thấy thẳng hàng. Không nói ra thì
        // người dùng đi soi một khối "trông đúng mà máy bảo sai".
        let t = tree("a:\n\tb: 1\n")
        guard let failure = t.failure else { return XCTFail("Tab lọt qua") }
        XCTAssertTrue(failure.contains("Tab"), failure)
        XCTAssertTrue(failure.contains("Dòng 2"), failure)
        XCTAssertTrue(t.isEmpty, "đã báo lỗi thì không được trả về nút nào")
    }

    func testDONGloLUNGbiBAT() {
        let t = tree("a: 1\n    b: 2\n")
        XCTAssertNotNil(t.failure, "dòng thụt sâu hơn mà không thuộc về ai vẫn dựng được cây")
    }

    func testDONGkhongCOhaiCHAMbiBAT() {
        XCTAssertNotNil(tree("a: 1\nchỉ là chữ\n").failure)
    }

    func testTEProngVAtepCHIcoCHUthichDEUbiTUchoi() {
        XCTAssertNotNil(tree("").failure)
        XCTAssertNotNil(tree("# chỉ có chú thích\n\n").failure)
    }

    // MARK: - Lồng sâu

    func testLONGvaiNGHINtangKHONGlamTRANngamXEP() {
        // `YAMLReader.parseBlock` đệ quy sẽ chết ở đây; ngăn xếp tường minh thì không.
        let sâu = 2000
        var yaml = ""
        for tầng in 0 ..< sâu { yaml += String(repeating: " ", count: tầng * 2) + "a\(tầng):\n" }
        yaml += String(repeating: " ", count: sâu * 2) + "x: 1\n"
        let t = tree(yaml)
        XCTAssertNil(t.failure, t.failure ?? "")
        XCTAssertEqual(t.nodes.map(\.depth).max(), sâu + 1)
    }
}
