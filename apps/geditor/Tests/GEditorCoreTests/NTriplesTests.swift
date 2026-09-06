import XCTest
@testable import GEditorCore

/// Đọc N-Triples thành bảng ba cột — FR-KNW-906.
final class NTriplesTests: XCTestCase {

    func testBaThanhPhanCoBan() {
        let (t, e) = NTriples.parse("<http://a/s> <http://a/p> <http://a/o> .\n")
        XCTAssertTrue(e.isEmpty)
        XCTAssertEqual(t.count, 1)
        XCTAssertEqual(t[0].subject, "<http://a/s>")
        XCTAssertEqual(t[0].predicate, "<http://a/p>")
        XCTAssertEqual(t[0].object, "<http://a/o>")
        XCTAssertEqual(t[0].line, 1)
    }

    /// Hậu tố ngôn ngữ giữ NGUYÊN VĂN. Cắt đi cho "đẹp" là làm mất thông tin không khôi phục
    /// được — và người mở file triple lên là người đang cần đúng thông tin ấy.
    func testLiteralGiuNguyenHauToNgonNgu() {
        let (t, _) = NTriples.parse("<http://a/s> <http://a/name> \"Hà Nội\"@vi .\n")
        XCTAssertEqual(t.first?.object, "\"Hà Nội\"@vi")
    }

    func testLiteralGiuNguyenHauToKieuDuLieu() {
        let dong = "<http://a/s> <http://a/age> \"42\"^^<http://www.w3.org/2001/XMLSchema#int> .\n"
        let (t, _) = NTriples.parse(dong)
        XCTAssertEqual(t.first?.object,
                       "\"42\"^^<http://www.w3.org/2001/XMLSchema#int>")
    }

    /// Dấu nháy ESCAPE bên trong literal không được kết thúc chuỗi sớm — nếu nó kết thúc sớm
    /// thì phần còn lại của dòng trôi sang cột khác, và bảng sai mà vẫn trông hợp lý.
    func testDauNhayEscapeKhongKetThucChuoiSom() {
        let (t, e) = NTriples.parse(
            "<http://a/s> <http://a/p> \"anh ấy nói \\\"xin chào\\\"\" .\n")
        XCTAssertTrue(e.isEmpty, "\(e)")
        XCTAssertEqual(t.first?.object, "\"anh ấy nói \\\"xin chào\\\"\"")
    }

    func testBlankNode() {
        let (t, e) = NTriples.parse("_:b1 <http://a/p> _:b2 .\n")
        XCTAssertTrue(e.isEmpty)
        XCTAssertEqual(t.first?.subject, "_:b1")
        XCTAssertEqual(t.first?.object, "_:b2")
    }

    func testBoQuaDongTrangVaChuThich() {
        let (t, e) = NTriples.parse("""
        # chú thích

        <http://a/s> <http://a/p> <http://a/o> .

        """)
        XCTAssertEqual(t.count, 1)
        XCTAssertTrue(e.isEmpty)
    }

    // MARK: - Dòng hỏng

    /// File triple thật hay ghép từ nhiều nguồn và gần như luôn có vài dòng lệch. Dừng ở dòng
    /// đầu tiên sai nghĩa là người dùng không xem được gì cả vì một dòng trong mười nghìn.
    func testDongHONGkhongLamHongCaLuotDoc() {
        let (t, e) = NTriples.parse("""
        <http://a/s1> <http://a/p> <http://a/o> .
        dòng này hỏng
        <http://a/s2> <http://a/p> <http://a/o> .
        """)
        XCTAssertEqual(t.count, 2, "hai dòng lành vẫn đọc được")
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.line, 2, "phải nói ĐÚNG dòng nào hỏng")
    }

    /// Nhưng KHÔNG im lặng bỏ qua — im lặng là cách một file mất nửa nội dung mà không ai biết.
    func testDongHONGduocDEMchuKhongBiNuot() {
        let (t, e) = NTriples.parse("a\nb\nc\n")
        XCTAssertTrue(t.isEmpty)
        XCTAssertEqual(e.count, 3)
    }

    func testThieuDauChamCuoiDongLaHONG() {
        let (t, e) = NTriples.parse("<http://a/s> <http://a/p> <http://a/o>\n")
        XCTAssertTrue(t.isEmpty)
        XCTAssertEqual(e.first?.reason.contains("."), true)
    }

    func testIRIThieuDauDongLaHONG() {
        let (_, e) = NTriples.parse("<http://a/s <http://a/p> <http://a/o> .\n")
        XCTAssertEqual(e.count, 1)
    }

    // MARK: - Phát ra bảng

    func testBangCoBonCotVaGiuSoDongGoc() {
        let (t, _) = NTriples.parse("""
        <http://a/s> <http://a/p> "x" .
        <http://a/s2> <http://a/p> "y" .
        """)
        let bang = NTriples.table(t)
        let dong = bang.split(separator: "\n")
        XCTAssertEqual(dong.first, "subject\tpredicate\tobject\tdong")
        XCTAssertEqual(dong.count, 3)
        XCTAssertTrue(dong[1].hasSuffix("\t1"), "phải giữ số dòng gốc: \(dong[1])")
        XCTAssertTrue(dong[2].hasSuffix("\t2"))
    }

    /// Vế đặc tả *"field an toàn quoted"*: một literal chứa dấu TAB không được làm vỡ bảng TSV.
    func testLiteralChuaTABkhongLamVoBang() throws {
        let (t, _) = NTriples.parse(
            "<http://a/s> <http://a/p> \"cột\tsau\" .\n")
        let bang = NTriples.table(t, dialect: .tab)

        var soCot: [Int] = []
        try CSVEngine.forEachRow(in: TextBuffer(text: bang), dialect: .tab) { row in
            soCot.append(row.count); return true
        }
        XCTAssertEqual(Set(soCot), [4], "dấu TAB trong literal làm vỡ bảng: \(soCot)")
    }

    func testBangRONGvanCoDongTieuDe() {
        XCTAssertEqual(NTriples.table([]), "subject\tpredicate\tobject\tdong\n")
    }
}
