import XCTest
@testable import GEditorCore

/// Bộ dịch lỗi DuckDB sang tiếng Việt (ADR-14 §3.2).
///
/// Mọi chuỗi đầu vào ở đây là **nguyên văn DuckDB 1.5.5 trả về**, chép từ một lượt chạy mười
/// lăm câu sai — không phải viết lại từ trí nhớ. Đó là lý do nhóm này bắt được khi upstream đổi
/// cách diễn đạt: bài kiểm sẽ đỏ, thay vì bộ dịch lặng lẽ rơi về "chưa có bản dịch".
final class DuckDBErrorTextTests: XCTestCase {

    func testCotKhongTonTai() {
        let raw = """
            Binder Error: Referenced column "khong_co" not found in FROM clause!
            Candidate bindings: "thanh_pho", "doanh_thu"

            LINE 1: SELECT khong_co FROM t
                           ^
            """
        let out = DuckDBErrorText.vietnamese(raw)
        XCTAssertTrue(out.recognised)
        XCTAssertTrue(out.text.hasPrefix("Không có cột «khong_co» trong bảng."), out.text)
        // Danh sách cột CÓ THẬT là chi tiết quý nhất — engine cũ cũng trả nó, và nó là thứ duy
        // nhất giúp người không biết SQL sửa được ngay.
        XCTAssertTrue(out.text.contains("thanh_pho"), out.text)
        // Khối vị trí giữ NGUYÊN VĂN, kể cả khoảng trắng của dấu mũ.
        XCTAssertTrue(out.text.contains("LINE 1: SELECT khong_co FROM t"), out.text)
        XCTAssertTrue(out.text.contains("^"), out.text)
        // Và KHÔNG in lại dòng tiếng Anh mà câu tiếng Việt đã nuốt vào.
        XCTAssertFalse(out.text.contains("Candidate bindings"), out.text)
    }

    func testBangKhongTonTai() {
        let raw = """
            Catalog Error: Table with name bang_la does not exist!
            Did you mean "pg_proc"?

            LINE 1: SELECT * FROM bang_la
                                  ^
            """
        let out = DuckDBErrorText.vietnamese(raw)
        XCTAssertTrue(out.recognised)
        XCTAssertTrue(out.text.contains("Không có bảng «bang_la»"), out.text)
        // Nói tên bảng ĐÚNG — câu hỏi đầu tiên của người mới mở panel.
        XCTAssertTrue(out.text.contains("«t»"), out.text)
        // Gợi ý của DuckDB cho BẢNG bị bỏ: catalog trong bộ nhớ chỉ có `t` và bảng hệ thống,
        // nên nó gợi ý "pg_proc" — dẫn người dùng đi sai hướng.
        XCTAssertFalse(out.text.contains("pg_proc"), out.text)
    }

    func testHamKhongTonTaiThiGIUgoiY() {
        let raw = """
            Catalog Error: Scalar Function with name khong_ton_tai does not exist!
            Did you mean "json_contains"?
            """
        let out = DuckDBErrorText.vietnamese(raw)
        XCTAssertTrue(out.recognised)
        XCTAssertTrue(out.text.contains("Không có hàm «khong_ton_tai»"), out.text)
        // Khác bảng: DuckDB có hàng trăm hàm THẬT, nên gõ nhầm tên hàm là chuyện thường và gợi
        // ý ở đây có ích.
        XCTAssertTrue(out.text.contains("json_contains"), out.text)
    }

    func testSaiCuPhap() {
        let out = DuckDBErrorText.vietnamese("""
            Parser Error: syntax error at or near "FROM"

            LINE 1: SELECT COUNT( FROM t
                                  ^
            """)
        XCTAssertTrue(out.recognised)
        XCTAssertTrue(out.text.hasPrefix("Câu truy vấn sai cú pháp gần «FROM»."), out.text)
    }

    func testDoiKieuKhongDuoc() {
        let out = DuckDBErrorText.vietnamese(
            "Conversion Error: Could not convert string 'abc' to INT32")
        XCTAssertTrue(out.recognised)
        XCTAssertTrue(out.text.contains("«abc»"), out.text)
        // "INT32" không nói gì với người làm bảng lương.
        XCTAssertTrue(out.text.contains("số nguyên"), out.text)
        XCTAssertFalse(out.text.contains("INT32"), out.text)
    }

    func testKhongNhanRaThiKHONGDOAN() {
        // Luật sống còn của bộ dịch này: một câu tiếng Việt bịa ra cho lỗi ta chưa hiểu sẽ dẫn
        // người dùng đi sai đường, và họ không có cách nào biết mình bị dẫn sai. Cùng luật với
        // bộ giải thích regex của FR-SRCH-110.
        let raw = "Out of Memory Error: failed to allocate 4 GB"
        let out = DuckDBErrorText.vietnamese(raw)
        XCTAssertFalse(out.recognised)
        XCTAssertTrue(out.text.contains(raw), "phải giữ NGUYÊN VĂN: \(out.text)")
        XCTAssertTrue(out.text.contains("chưa có bản dịch"), out.text)
    }

    func testMoiHoLoiCoDoiCHUNG() {
        // Đối chứng cho chính nhóm này: nếu `vietnamese` trả `recognised = true` cho MỌI đầu
        // vào thì năm bài trên xanh mà chẳng chứng minh gì. Bài `testKhongNhanRaThiKHONGDOAN`
        // là một nửa đối chứng; nửa còn lại là chuỗi rỗng.
        XCTAssertFalse(DuckDBErrorText.vietnamese("").recognised)
        XCTAssertFalse(DuckDBErrorText.vietnamese("chuyện gì đó").recognised)
    }
}
