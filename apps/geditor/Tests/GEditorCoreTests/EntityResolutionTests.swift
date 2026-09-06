import XCTest
@testable import GEditorCore

/// FR-KNW-923 — chu trình gom biến thể entity.
final class EntityResolutionTests: XCTestCase {

    // MARK: - Cụm ứng viên

    func testGOMBIENTHEChinhTa() {
        let clusters = EntityResolution.clusters([
            "Nguyễn Văn A", "Nguyen Van A", "Trần Thị B",
        ])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(Set(clusters[0].members), Set(["Nguyễn Văn A", "Nguyen Van A"]))
    }

    /// Trùng HOÀN TOÀN không phải một biến thể — hai lần khai cùng tên chỉ là một entity.
    func testTRUNGHOANTOANKhongPhaiBienThe() {
        let clusters = EntityResolution.clusters(["An", "An", "An"])
        XCTAssertTrue(clusters.isEmpty)
    }

    /// Dạng chuẩn ĐỀ XUẤT: hay gặp nhất trước, hoà thì DÀI nhất.
    ///
    /// Dài nhất khi hoà là có lý do: giữa «NHNN» và «Ngân hàng Nhà nước», bản dài là bản người
    /// đọc ngoài hiểu được.
    func testDANGCHUANDeXuatTheoSoLanRoiDoDai() {
        let byCount = EntityResolution.clusters(
            ["Nguyen Van A", "Nguyễn Văn A"], counts: ["Nguyen Van A": 10, "Nguyễn Văn A": 2])
        XCTAssertEqual(byCount[0].canonical, "Nguyen Van A")

        let byLength = EntityResolution.clusters(["Nguyen Van A", "Nguyen Van Anh"])
        XCTAssertEqual(byLength[0].canonical, "Nguyen Van Anh")
    }

    /// Bằng số lần và bằng ĐỘ DÀI thì bản CÒN DẤU thắng.
    ///
    /// Không có tiêu chí này thì kết quả rơi vào thứ tự chữ cái — và thứ tự chữ cái đặt bản
    /// KHÔNG dấu lên trước, tức công cụ đề xuất bỏ dấu tiếng Việt của chính người dùng. Một bài
    /// tự kiểm bắt được chỗ này; hai bài kiểm ở lõi trước đó thì không, vì chúng dùng hai chuỗi
    /// khác độ dài.
    func testBANGDoDaiThiBanConDauThang() {
        let clusters = EntityResolution.clusters(["Nguyen Van A", "Nguyễn Văn A"])
        XCTAssertEqual(clusters[0].canonical, "Nguyễn Văn A")
    }

    /// Viết tắt: chuỗi chữ cái đầu.
    func testVIETTATTheoChuCaiDau() {
        let clusters = EntityResolution.clusters(["Ngân hàng Nhà nước", "NHNN", "Bộ Tài chính"])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(Set(clusters[0].members), Set(["Ngân hàng Nhà nước", "NHNN"]))
        XCTAssertEqual(clusters[0].canonical, "Ngân hàng Nhà nước", "bản DÀI làm dạng chuẩn")
    }

    /// Luật viết tắt cố ý HẸP — luật rộng hơn sẽ gom nhầm hai tổ chức khác nhau.
    func testLUATVIETTATCoYHep() {
        // «NH Nhà nước» không phải chuỗi chữ cái đầu của «Ngân hàng Nhà nước».
        let clusters = EntityResolution.clusters(["Ngân hàng Nhà nước", "N.H.N.N"])
        XCTAssertTrue(clusters.isEmpty, "\(clusters.map(\.members))")
    }

    func testTATViettatThiKhongGom() {
        let clusters = EntityResolution.clusters(
            ["Ngân hàng Nhà nước", "NHNN"], config: .init(matchAbbreviations: false))
        XCTAssertTrue(clusters.isEmpty)
    }

    /// Độ giống YẾU NHẤT của cụm được báo — cụm lỏng thì người duyệt cần thấy.
    func testDOGIONGYeuNhatDuocBao() {
        let clusters = EntityResolution.clusters(
            ["Nguyen Van A", "Nguyễn Văn A", "Nguyen Van B"], config: .init(similarity: 0.8))
        XCTAssertEqual(clusters.count, 1)
        XCTAssertLessThan(clusters[0].weakestSimilarity, 1)
    }

    // MARK: - Bảng duyệt

    func testBANGDUYETMoiDongMotAlias() {
        let csv = EntityResolution.reviewCSV(
            EntityResolution.clusters(["Nguyen Van A", "Nguyễn Văn A"]))
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "cum,alias,canonical,giu_nguyen,so_lan,do_giong")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].hasPrefix("1,"))
    }

    func testDOCBANGDUYET() throws {
        let mapping = try EntityResolution.parseReview("""
            cum,alias,canonical,giu_nguyen
            1,Nguyen Van A,Nguyễn Văn A,
            1,Nguyễn Văn A,Nguyễn Văn A,
            2,NHNN,Ngân hàng Nhà nước,
            """)
        XCTAssertEqual(mapping, ["Nguyen Van A": "Nguyễn Văn A", "NHNN": "Ngân hàng Nhà nước"])
    }

    /// Cột `giu_nguyen` LOẠI một cụm gom nhầm mà không phải xoá dòng.
    ///
    /// Xoá dòng là thao tác dễ làm nhầm nhất trong một bảng, và nó không để lại dấu vết cho
    /// người duyệt sau.
    func testCOTGiuNguyenLoaiCumGomNham() throws {
        let mapping = try EntityResolution.parseReview("""
            cum,alias,canonical,giu_nguyen
            1,Ngân hàng A,Ngân hàng B,x
            2,Nguyen Van A,Nguyễn Văn A,
            """)
        XCTAssertEqual(mapping, ["Nguyen Van A": "Nguyễn Văn A"])
    }

    /// Một alias gán HAI dạng chuẩn khác nhau thì TỪ CHỐI — không đoán.
    func testMOTALIASHaiDangChuanThiTuChoi() {
        XCTAssertThrowsError(try EntityResolution.parseReview("""
            alias,canonical
            An,An Nguyễn
            An,An Trần
            """))
    }

    func testTHIEUCOTThiBaoRo() {
        XCTAssertThrowsError(try EntityResolution.parseReview("a,b\n1,2\n")) { error in
            XCTAssertTrue((error as? EntityResolution.Failure)?.message.contains("alias")
                ?? false)
        }
    }

    // MARK: - Đổi tên trên văn bản DOT

    private let source = """
        digraph G {
            // An ký hợp đồng — chú thích, KHÔNG được đổi
            An [label="An"];
            Binh [label="Bình", ghi_chu="An"];
            "Ban An toàn" [label="Ban An toàn"];
            An -> Binh;
        }
        """

    /// Chỉ đổi ĐỊNH DANH TRỌN VẸN, không đổi chuỗi con.
    ///
    /// `replacingOccurrences` sẽ đổi cả chữ «An» trong «Ban An toàn» và trong chú thích.
    func testCHIDOIDinhDanhTronVen() {
        let edits = EntityResolution.renameEdits(
            in: source, mapping: ["An": "Nguyễn Văn An"])
        let result = EntityResolution.apply(edits, to: source)
        XCTAssertTrue(result.contains("\"Nguyễn Văn An\" [label=\"Nguyễn Văn An\"]"), result)
        XCTAssertTrue(result.contains("\"Nguyễn Văn An\" -> Binh"), result)
        // Chú thích KHÔNG đổi.
        XCTAssertTrue(result.contains("// An ký hợp đồng"), result)
        // Chuỗi con trong một tên khác KHÔNG đổi.
        XCTAssertTrue(result.contains("\"Ban An toàn\""), result)
    }

    /// Giá trị thuộc tính chỉ đổi khi khoá là `label`.
    ///
    /// Đổi mọi giá trị thì một thuộc tính `ghi_chu="An"` cũng bị sửa — mà nó là văn xuôi của
    /// người ghi chú, không phải một tham chiếu tới entity.
    ///
    /// Bản đầu của bài kiểm này dùng `ghi_chu="An ký"`, và nó qua VÌ LÝ DO SAI: chuỗi ấy vốn đã
    /// không khớp alias, nên bỏ hẳn luật đi thì bài vẫn xanh. Giá trị phải TRÙNG KHÍT alias thì
    /// bài mới thật sự đo luật.
    func testGIATRIThuocTinhChiDoiKhiKhoaLaLabel() {
        let result = EntityResolution.apply(
            EntityResolution.renameEdits(in: source, mapping: ["An": "An Nguyễn"]),
            to: source)
        XCTAssertTrue(result.contains("ghi_chu=\"An\""), result)
        // Nhưng `label` thì PHẢI đổi.
        XCTAssertTrue(result.contains("label=\"An Nguyễn\""), result)
    }

    /// Tên đích cần NHÁY thì được bọc nháy.
    func testTENDICHCanNhayThiDuocBoc() {
        let result = EntityResolution.apply(
            EntityResolution.renameEdits(in: "digraph { An -> B }", mapping: ["An": "An Văn"]),
            to: "digraph { An -> B }")
        XCTAssertTrue(result.contains("\"An Văn\" -> B"), result)
    }

    /// Áp nhiều sửa đổi thì mọi vị trí vẫn đúng — áp từ CUỐI về ĐẦU.
    func testAPNHIEUSuaDoiViTriVanDung() {
        let text = "digraph { A -> B; B -> C }"
        let result = EntityResolution.apply(
            EntityResolution.renameEdits(in: text, mapping: ["A": "Alpha", "C": "Charlie"]),
            to: text)
        XCTAssertEqual(result, "digraph { Alpha -> B; B -> Charlie }")
    }

    // MARK: - Changeset

    /// Ba đầu ra sinh CÙNG LÚC từ một nguồn.
    func testBADAURASinhCungLuc() throws {
        let graph = DOTGraph.parse(source)
        let changeset = EntityResolution.changeset(
            mapping: ["An": "Nguyễn Văn An"], dotText: source, graph: graph)
        XCTAssertEqual(changeset.aliasCSV, "alias,canonical\nAn,Nguyễn Văn An\n")
        XCTAssertFalse(changeset.edits.isEmpty)
        XCTAssertTrue(changeset.markers.contains("Nguyễn Văn An"))
        XCTAssertFalse(changeset.markers.contains("An"))
    }

    /// **Phép gộp được KỂ RA trước, không xảy ra âm thầm.**
    ///
    /// Đổi «Nguyen Van A» thành «Nguyễn Văn A» khi tên sau đã có nghĩa là hai node mang cùng
    /// định danh, và DOT gộp chúng khi đọc lại. Phép gộp ấy có thật; nó chỉ được phép xảy ra
    /// qua một changeset đã duyệt, và người duyệt phải THẤY nó trước.
    func testPHEPGOPDuocKeRaTruoc() {
        let text = """
            digraph {
                "Nguyen Van A" [label="Nguyen Van A"];
                "Nguyễn Văn A" [label="Nguyễn Văn A"];
            }
            """
        let changeset = EntityResolution.changeset(
            mapping: ["Nguyen Van A": "Nguyễn Văn A"], dotText: text,
            graph: DOTGraph.parse(text))
        XCTAssertEqual(changeset.merges.count, 1)
        XCTAssertTrue(changeset.merges[0].contains("đích đã có"), changeset.merges[0])
    }

    /// Alias KHÔNG có trên đồ thị được kể ra — bảng duyệt trỏ vào thứ không tồn tại.
    func testALIASKhongCoTrenDoThiDuocKeRa() {
        let changeset = EntityResolution.changeset(
            mapping: ["Không Có": "Có"], dotText: source, graph: DOTGraph.parse(source))
        XCTAssertEqual(changeset.unknownAliases, ["Không Có"])
        XCTAssertTrue(changeset.edits.isEmpty)
    }

    /// Bảng duyệt RỖNG thì changeset rỗng — không sửa gì cả.
    ///
    /// Đây là vế "không bao giờ tự merge": không có bảng duyệt thì không có thay đổi nào.
    func testBANGDUYETRongThiKhongSuaGi() {
        let changeset = EntityResolution.changeset(
            mapping: [:], dotText: source, graph: DOTGraph.parse(source))
        XCTAssertTrue(changeset.edits.isEmpty)
        XCTAssertTrue(changeset.merges.isEmpty)
    }

    /// Đường ghép: gom → duyệt → áp → đọc lại đồ thị thấy đúng một node.
    func testDUONGGHEPDayDu() throws {
        let text = """
            digraph {
                "Nguyen Van A" -> "Trần Thị B";
                "Nguyễn Văn A" -> "Trần Thị B";
            }
            """
        let graph = DOTGraph.parse(text)
        let names = graph.nodes.map(\.display)
        XCTAssertEqual(names.count, 3, "tiền đề: ba node trước khi gom")

        let clusters = EntityResolution.clusters(names)
        let review = EntityResolution.reviewCSV(clusters)
        // Người dùng duyệt: giữ nguyên bảng đề xuất.
        let mapping = try EntityResolution.parseReview(review)
        let changeset = EntityResolution.changeset(
            mapping: mapping, dotText: text, graph: graph)
        let applied = EntityResolution.apply(changeset.edits, to: text)

        let after = DOTGraph.parse(applied)
        XCTAssertEqual(after.nodes.count, 2, "sau khi gộp còn hai node: \(after.nodes.map(\.name))")
        XCTAssertEqual(after.edges.count, 2, "hai cạnh vẫn còn, chúng chỉ cùng trỏ về một node")
    }
}
