import XCTest
@testable import GEditorCore

/// FR-KNW-913 — đọc và dịch tập con openCypher.
final class CypherQueryTests: XCTestCase {

    private func parse(_ text: String) throws -> CypherQuery {
        try CypherQuery.parse(text)
    }

    // MARK: - Mẫu

    func testMOTNODEKhongCanh() throws {
        let query = try parse("MATCH (a) RETURN a")
        XCTAssertEqual(query.nodes.map(\.variable), ["a"])
        XCTAssertTrue(query.edges.isEmpty)
        XCTAssertEqual(query.hops, 0)
    }

    func testNHANVaThuocTinhTrongMau() throws {
        let query = try parse("MATCH (a:Người {name: 'An'})-[r:GỬI]->(b) RETURN a")
        XCTAssertEqual(query.nodes[0].label, "Người")
        XCTAssertEqual(query.nodes[0].properties.map(\.key), ["name"])
        XCTAssertEqual(query.nodes[0].properties.map(\.value), [.text("An")])
        XCTAssertEqual(query.edges[0].type, "GỬI")
        XCTAssertEqual(query.edges[0].variable, "r")
        XCTAssertEqual(query.edges[0].direction, .forward)
    }

    func testBACHIEUCANH() throws {
        XCTAssertEqual(try parse("MATCH (a)-[r]->(b) RETURN a").edges[0].direction, .forward)
        XCTAssertEqual(try parse("MATCH (a)<-[r]-(b) RETURN a").edges[0].direction, .backward)
        XCTAssertEqual(try parse("MATCH (a)-[r]-(b) RETURN a").edges[0].direction, .any)
    }

    func testNODEVoDanhVaCanhVoDanh() throws {
        let query = try parse("MATCH ()-->() RETURN 1")
        XCTAssertEqual(query.nodes.count, 2)
        XCTAssertEqual(query.edges.count, 1)
        XCTAssertEqual(query.edges[0].variable, "")
    }

    /// Trần hop CỨNG — từ chối TRƯỚC khi chạy, kèm lý do.
    func testTRANHOPCung() {
        XCTAssertNoThrow(try parse("MATCH (a)-->(b)-->(c)-->(d) RETURN a"))
        XCTAssertThrowsError(try parse("MATCH (a)-->(b)-->(c)-->(d)-->(e) RETURN a")) { error in
            let message = (error as? CypherQuery.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("vượt trần"), message)
            XCTAssertTrue(message.contains("bùng nổ"), message)
        }
    }

    /// Đường đi độ dài thay đổi bị TỪ CHỐI rõ ràng, không đọc nửa vời.
    func testDUONGDIDoDaiThayDoiBiTuChoi() {
        XCTAssertThrowsError(try parse("MATCH (a)-[*1..3]->(b) RETURN a")) { error in
            XCTAssertTrue((error as? CypherQuery.Failure)?.message.contains("độ dài thay đổi")
                ?? false)
        }
    }

    /// Nhiều mẫu ngăn bởi dấu phẩy bị TỪ CHỐI.
    ///
    /// Bỏ qua lặng lẽ thì truy vấn vẫn chạy và trả về một bảng — bảng ấy đúng cho một câu hỏi
    /// KHÁC với câu người dùng hỏi, và không có gì trông sai cả.
    func testNHIEUMAUBiTuChoi() {
        XCTAssertThrowsError(try parse("MATCH (a), (b) RETURN a")) { error in
            XCTAssertTrue((error as? CypherQuery.Failure)?.message.contains("MỘT mẫu") ?? false)
        }
    }

    // MARK: - WHERE

    func testWHEREVoiAndOrVaNgoac() throws {
        let query = try parse("""
            MATCH (a)-->(b)
            WHERE (a.name = 'An' OR a.name = 'Bình') AND b.kind <> 'nháp'
            RETURN a
            """)
        guard case let .and(left, right) = query.condition else {
            return XCTFail("mong AND ở gốc: \(String(describing: query.condition))")
        }
        guard case .or = left else { return XCTFail("mong OR bên trái") }
        guard case let .compare(_, property, op, value) = right else {
            return XCTFail("mong so sánh bên phải")
        }
        XCTAssertEqual(property, "kind")
        XCTAssertEqual(op, .notEqual)
        XCTAssertEqual(value, .text("nháp"))
    }

    func testPHEPSOSANHChuoi() throws {
        for (text, expected) in [
            ("a.name CONTAINS 'x'", CypherQuery.Comparison.contains),
            ("a.name STARTS WITH 'x'", .startsWith),
            ("a.name ENDS WITH 'x'", .endsWith),
        ] {
            let query = try parse("MATCH (a) WHERE \(text) RETURN a")
            guard case let .compare(_, _, op, _) = query.condition else {
                return XCTFail("không đọc được \(text)")
            }
            XCTAssertEqual(op, expected)
        }
    }

    func testISNULLVaNOT() throws {
        let query = try parse("MATCH (a) WHERE NOT a.kind IS NULL RETURN a")
        guard case let .not(inner) = query.condition,
              case let .isNull(_, property, negated) = inner else {
            return XCTFail("\(String(describing: query.condition))")
        }
        XCTAssertEqual(property, "kind")
        XCTAssertFalse(negated)
    }

    /// Từ khoá chỉ khớp khi nó là NGUYÊN một từ.
    ///
    /// Không có luật ấy thì `MATCH (android)` bị đọc thành từ khoá `AND` cộng một mẩu `roid`,
    /// và câu báo lỗi sẽ nói về một thứ chẳng liên quan tới điều người dùng gõ.
    func testTUKHOAChiKhopNguyenMotTu() throws {
        let query = try parse("MATCH (android) RETURN android")
        XCTAssertEqual(query.nodes[0].variable, "android")
    }

    // MARK: - RETURN

    func testRETURNThuocTinhHamGopVaAlias() throws {
        let query = try parse("""
            MATCH (a)-->(b)
            RETURN DISTINCT a.name, count(b) AS so_ban, collect(b.name) AS ten
            ORDER BY so_ban DESC
            LIMIT 5
            """)
        XCTAssertTrue(query.distinct)
        XCTAssertEqual(query.items.map(\.name), ["a.name", "so_ban", "ten"])
        XCTAssertEqual(query.items[1].aggregate, .count)
        XCTAssertEqual(query.items[2].aggregate, .collect)
        XCTAssertEqual(query.orders, [.init(name: "so_ban", descending: true)])
        XCTAssertEqual(query.limit, 5)
    }

    func testCOUNTSAO() throws {
        let query = try parse("MATCH (a)-->(b) RETURN count(*) AS n")
        XCTAssertTrue(query.items[0].isStar)
        XCTAssertEqual(query.items[0].name, "n")
    }

    func testHAMLABiTuChoiKemDanhSachHamCo() {
        XCTAssertThrowsError(try parse("MATCH (a) RETURN sum(a.x)")) { error in
            let message = (error as? CypherQuery.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("count"), message)
            XCTAssertTrue(message.contains("collect"), message)
        }
    }

    func testTHIEURETURNBiTuChoi() {
        XCTAssertThrowsError(try parse("MATCH (a)"))
    }

    func testCONTHUACHUSauTruyVan() {
        XCTAssertThrowsError(try parse("MATCH (a) RETURN a RÁC")) { error in
            XCTAssertTrue((error as? CypherQuery.Failure)?.message.contains("thừa chữ") ?? false)
        }
    }
}

/// FR-KNW-913 — dịch sang SQL và CHẠY THẬT.
final class CypherSQLTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("cypher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if !folder.isEmpty { try? FileManager.default.removeItem(atPath: folder) }
        super.tearDown()
    }

    private func translate(_ text: String) throws -> CypherSQL.Translation {
        try CypherSQL.translate(try CypherQuery.parse(text))
    }

    // MARK: - Hình dạng SQL

    func testMOTHOPRaMotPhepNoi() throws {
        let sql = try translate("MATCH (a)-[r]->(b) RETURN a.name, b.name").sql
        XCTAssertTrue(sql.contains("FROM node AS \"a\""), sql)
        XCTAssertTrue(sql.contains("JOIN edge AS \"r\" ON \"r\".source = \"a\".id"), sql)
        XCTAssertTrue(sql.contains("JOIN node AS \"b\" ON \"b\".id = \"r\".target"), sql)
    }

    /// Điều kiện nối chỉ được nhắc tới bảng ĐÃ nối — bản đầu vi phạm và DuckDB từ chối ngay.
    func testDIEUKIENNOIKhongThamChieuBangPhiaSau() throws {
        let sql = try translate("MATCH (a)-[r]->(b) RETURN a.name").sql
        let lines = sql.components(separatedBy: "\n")
        guard let edgeLine = lines.first(where: { $0.contains("JOIN edge") }) else {
            return XCTFail(sql)
        }
        XCTAssertFalse(edgeLine.contains("\"b\""),
                       "điều kiện nối cạnh không được nhắc tới node phía sau: \(edgeLine)")
    }

    func testCANHVOHUONGKhopCaHaiChieu() throws {
        let sql = try translate("MATCH (a)-[r]-(b) RETURN a.name").sql
        XCTAssertTrue(sql.contains("OR"), sql)
        XCTAssertTrue(sql.contains("\"r\".source = \"a\".id"), sql)
        XCTAssertTrue(sql.contains("\"r\".target = \"a\".id"), sql)
    }

    func testNHANThanhDieuKienKind() throws {
        let sql = try translate("MATCH (a:Người) RETURN a.name").sql
        XCTAssertTrue(sql.contains("\"a\".kind = 'Người'"), sql)
    }

    /// Dấu nháy trong giá trị được THOÁT khi sang SQL — không thoát là một lỗ tiêm SQL.
    ///
    /// Cypher thoát bằng gạch chéo ngược, SQL thoát bằng cách NHÂN ĐÔI dấu nháy. Hai luật
    /// khác nhau, và chỗ dịch là chỗ duy nhất biết cả hai.
    func testNHAYTrongGiaTriDuocThoat() throws {
        let cypher = "MATCH (a) WHERE a.name = " + "'O" + "\\" + "'Brien' RETURN a.name"
        let sql = try translate(cypher).sql
        XCTAssertTrue(sql.contains("'O''Brien'"), sql)
    }

    /// Một giá trị cố tình mang cú pháp SQL KHÔNG được thoát ra khỏi dấu nháy.
    func testGIATRIMangCuPhapSQLKhongThoatRaDuoc() throws {
        let cypher = "MATCH (a) WHERE a.name = " + "'x" + "\\" + "' OR 1=1 --' RETURN a.name"
        let sql = try translate(cypher).sql
        // Nháy đơn trong giá trị thành nháy đôi, nên phần OR 1=1 vẫn nằm TRONG chuỗi.
        XCTAssertTrue(sql.contains("'x'' OR 1=1 --'"), sql)
        XCTAssertFalse(sql.contains("= 'x' OR"), sql)
    }

    func testHAMGOPSinhGroupBy() throws {
        let sql = try translate("MATCH (a)-->(b) RETURN a.name, count(b) AS n").sql
        XCTAssertTrue(sql.contains("count("), sql)
        XCTAssertTrue(sql.contains("GROUP BY \"a\".name"), sql)
    }

    /// Thuộc tính KHÔNG phải cột thì TỪ CHỐI kèm danh sách cột có thật.
    ///
    /// Sinh SQL với một tên cột lạ thì DuckDB báo lỗi bằng tiếng Anh về một bảng người dùng
    /// chưa từng thấy, và họ sẽ đi tìm lỗi trong tệp DOT của mình.
    func testTHUOCTINHLaBiTuChoiKemDanhSachCot() {
        XCTAssertThrowsError(try translate("MATCH (a) WHERE a.gia > 5 RETURN a.name")) { error in
            let message = (error as? CypherSQL.Failure)?.message ?? ""
            XCTAssertTrue(message.contains("id"), message)
            XCTAssertTrue(message.contains("name"), message)
            XCTAssertTrue(message.contains("kind"), message)
        }
    }

    func testBIENKhongCoTrongMATCHBiTuChoi() {
        XCTAssertThrowsError(try translate("MATCH (a) RETURN z.name")) { error in
            XCTAssertTrue((error as? CypherSQL.Failure)?.message.contains("không có trong MATCH")
                ?? false)
        }
    }

    /// ORDER BY một cột KHÔNG trả về thì từ chối — người đọc bảng không kiểm lại được.
    func testORDERBYCotKhongTraVeBiTuChoi() {
        XCTAssertThrowsError(try translate("MATCH (a) RETURN a.name ORDER BY a.kind"))
    }

    /// Kế hoạch chạy phải NÓI RA số hop, trần, và quy ước cột.
    func testKEHOACHNoiRaSoHopVaQuyUocCot() throws {
        let plan = try translate("MATCH (a)-->(b)-->(c) RETURN a.name").plan
        let text = plan.joined(separator: "\n")
        XCTAssertTrue(text.contains("2 hop"), text)
        XCTAssertTrue(text.contains("trần \(CypherQuery.maximumHops)"), text)
        XCTAssertTrue(text.contains("kind"), text)
        XCTAssertTrue(text.contains("hop 1"), text)
        XCTAssertTrue(text.contains("hop 2"), text)
    }

    /// Quy ước `kind`: `type` > `class` > `shape`, và nó phải khớp giữa TÀI LIỆU và MÃ.
    ///
    /// Bản đầu chú thích bảo `kind` lấy từ `type`/`class` còn mã thì ghi `shape` — hai câu nói
    /// khác nhau về cùng một cột, và người đọc tin câu nào cũng sai một nửa.
    func testQUYUOCKindTheoThuTuTypeClassShape() {
        let graph = DOTGraph.parse("""
            digraph {
                a [type="Người", class="x", shape=box];
                b [class="Nhóm", shape=box];
                c [shape=diamond];
                d;
            }
            """)
        XCTAssertEqual(graph.nodes.map(\.kind), ["Người", "Nhóm", "diamond", nil])
    }

    // MARK: - Chạy thật trên DuckDB

    /// Đồ thị nhỏ, mọi kỳ vọng tính tay.
    ///
    /// ```
    /// An --gửi--> Bình --gửi--> Chi
    /// An --nhắc--> Chi
    /// ```
    private func sampleGraph() -> DOTGraph {
        DOTGraph.parse("""
            digraph {
                an [label="An", shape=nguoi];
                binh [label="Bình", shape=nguoi];
                chi [label="Chi", shape=nhom];
                an -> binh [label="gửi"];
                binh -> chi [label="gửi"];
                an -> chi [label="nhắc"];
            }
            """)
    }

    private func run(_ cypher: String) throws -> CSVQueryEngine.Result {
        let translation = try translate(cypher)
        let sources = try CypherSQL.materialize(sampleGraph(), in: folder)
        // Bảng chính `t` không dùng tới — mọi thứ đọc từ `node` và `edge`.
        let buffer = TextBuffer(original: MemoryByteSource(Array("x\n1\n".utf8)))
        return try CSVQueryEngine.run(
            translation.sql, in: buffer, dialect: .comma, extraSources: sources)
    }

    private func skipIfNoEngine(_ body: () throws -> Void) throws {
        do {
            try body()
        } catch CSVQueryEngine.Failure.unavailable {
            throw XCTSkip("máy này không có libduckdb")
        }
    }

    func testCHAYTHATMotHop() throws {
        try skipIfNoEngine {
            let result = try run(
                "MATCH (a)-[r]->(b) RETURN a.name, b.name ORDER BY a.name, b.name")
            XCTAssertEqual(result.titles, ["a.name", "b.name"])
            XCTAssertEqual(result.rows.count, 3)
            XCTAssertEqual(result.rows[0], ["An", "Bình"])
        }
    }

    /// Hai hop: chỉ có ĐÚNG một đường An → Bình → Chi.
    func testCHAYTHATHaiHop() throws {
        try skipIfNoEngine {
            let result = try run("MATCH (a)-->(b)-->(c) RETURN a.name, b.name, c.name")
            XCTAssertEqual(result.rows.count, 1)
            XCTAssertEqual(result.rows[0], ["An", "Bình", "Chi"])
        }
    }

    /// Nhãn lọc theo `kind` — đồ thị mẫu có hai node `nguoi` và một node `nhom`.
    func testCHAYTHATLocTheoNhan() throws {
        try skipIfNoEngine {
            let result = try run("MATCH (a:nguoi) RETURN a.name ORDER BY a.name")
            XCTAssertEqual(result.rows.map { $0[0] }, ["An", "Bình"])
        }
    }

    /// `count` gom nhóm đúng: An có 2 cạnh đi ra, Bình có 1.
    func testCHAYTHATDemTheoNhom() throws {
        try skipIfNoEngine {
            let result = try run(
                "MATCH (a)-->(b) RETURN a.name, count(b) AS n ORDER BY n DESC, a.name")
            XCTAssertEqual(result.rows.count, 2)
            XCTAssertEqual(result.rows[0], ["An", "2"])
            XCTAssertEqual(result.rows[1], ["Bình", "1"])
        }
    }

    /// Cạnh VÔ HƯỚNG khớp cả hai chiều, và **không đếm gấp đôi**.
    ///
    /// Chi có hai cạnh chạm tới nó (từ Bình và từ An), cả hai đều đi VÀO. Truy vấn vô hướng
    /// phải thấy đúng hai, không phải bốn.
    func testCHAYTHATCanhVoHuongKhongDemGapDoi() throws {
        try skipIfNoEngine {
            let result = try run(
                "MATCH (a {name: 'Chi'})-[r]-(b) RETURN b.name ORDER BY b.name")
            XCTAssertEqual(result.rows.map { $0[0] }, ["An", "Bình"])
        }
    }

    /// WHERE trên nhãn cạnh.
    func testCHAYTHATLocTheoNhanCanh() throws {
        try skipIfNoEngine {
            let result = try run(
                "MATCH (a)-[r]->(b) WHERE r.label = 'nhắc' RETURN a.name, b.name")
            XCTAssertEqual(result.rows.count, 1)
            XCTAssertEqual(result.rows[0], ["An", "Chi"])
        }
    }

    /// `collect` gom thành danh sách.
    func testCHAYTHATCollect() throws {
        try skipIfNoEngine {
            let result = try run(
                "MATCH (a)-->(b) WHERE a.name = 'An' RETURN collect(b.name) AS ds")
            XCTAssertEqual(result.rows.count, 1)
            let text = result.rows[0][0] ?? "<nil>"
            XCTAssertTrue(text.contains("Bình"), "collect trả về: «\(text)»")
            XCTAssertTrue(text.contains("Chi"), "collect trả về: «\(text)»")
        }
    }

    /// `RETURN a` trả CHỮ HIỆN TRÊN NODE, không trả id.
    ///
    /// Người dùng đọc bảng kết quả cạnh sơ đồ, và thứ họ đối chiếu là chữ trên hình. Trả id thì
    /// với một tệp DOT dùng `n1`, `n2` làm tên, cả bảng là những con số vô nghĩa.
    func testCHAYTHATTraVeBienLaChuHienTrenNode() throws {
        try skipIfNoEngine {
            let result = try run("MATCH (a:nhom) RETURN a")
            XCTAssertEqual(result.rows.map { $0[0] }, ["Chi"])
        }
    }
}
