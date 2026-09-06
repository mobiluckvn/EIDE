import XCTest
@testable import GEditorCore

/// Chỉ mục hàng logic cho Table view (FR-CSV-403).
final class CSVRowIndexTests: XCTestCase {

    private func makeIndex(_ text: String, dialect: CSVDialect = .comma)
        throws -> (CSVRowIndex, TextBuffer)
    {
        let buffer = TextBuffer(text: text)
        return (try CSVRowIndex.build(in: buffer, dialect: dialect), buffer)
    }

    func testCountsLogicalRows() throws {
        let (index, _) = try makeIndex("a,b\n1,2\n3,4\n")
        XCTAssertEqual(index.rowCount, 3)
        XCTAssertEqual(index.columnCount, 2)
    }

    /// File không có ký tự xuống dòng cuối vẫn phải đếm đủ hàng cuối.
    func testLastRowWithoutTrailingNewlineIsCounted() throws {
        let (index, buffer) = try makeIndex("a,b\n1,2")
        XCTAssertEqual(index.rowCount, 2)
        XCTAssertEqual(index.values(ofRow: 1, in: buffer), ["1", "2"])
    }

    /// Một hàng LOGIC có thể trải trên nhiều dòng VẬT LÝ.
    ///
    /// Đây là lý do tồn tại của cả lớp này. Nếu đánh chỉ mục theo dòng vật lý thì hàng 2 dưới
    /// đây sẽ là "và xuống dòng" — bảng lệch hàng từ đó tới hết file.
    func testQuotedNewlineDoesNotSplitARow() throws {
        let text = "ma,ghi_chu,so\nA1,\"có phẩy, và\nxuống dòng\",7\nA2,binh thuong,8\n"
        let (index, buffer) = try makeIndex(text)

        XCTAssertEqual(index.rowCount, 3, "ba hàng logic, dù có bốn dòng vật lý")
        XCTAssertEqual(buffer.lineCount, 4, "đối chứng: đếm theo dòng vật lý cho con số KHÁC")
        XCTAssertEqual(index.values(ofRow: 1, in: buffer), ["A1", "có phẩy, và\nxuống dòng", "7"])
        XCTAssertEqual(index.values(ofRow: 2, in: buffer), ["A2", "binh thuong", "8"])
    }

    /// Hàng nằm GIỮA hai mốc phải đọc đúng — đây là đường phân tích lại.
    func testRowsBetweenAnchorsAreExact() throws {
        var text = "ma,gia_tri\n"
        for row in 1 ... 500 { text += "M\(row),\(row * 3)\n" }
        let (index, buffer) = try makeIndex(text)

        XCTAssertEqual(index.rowCount, 501)
        // Ngay tại mốc, ngay sau mốc, ngay trước mốc kế, và hàng cuối.
        for row in [1, 63, 64, 65, 127, 128, 300, 500] {
            XCTAssertEqual(
                index.values(ofRow: row, in: buffer), ["M\(row)", "\(row * 3)"],
                "hàng \(row) đọc sai"
            )
        }
    }

    /// Đọc cả dãy phải cho ĐÚNG kết quả như đọc từng hàng.
    ///
    /// Đường đọc theo dãy là đường bảng thực sự dùng; đường đọc từng hàng là đường dễ kiểm.
    /// Hai đường lệch nhau thì chỉ có màn hình sai, còn test vẫn xanh.
    func testBatchReadMatchesSingleRowRead() throws {
        var text = "ma,gia_tri\n"
        for row in 1 ... 300 { text += "M\(row),\(row)\n" }
        let (index, buffer) = try makeIndex(text)

        // Dãy cố tình vắt qua biên khối (64).
        let range = 50 ..< 200
        let batch = index.rows(range, in: buffer)
        XCTAssertEqual(batch.count, range.count)
        for (step, row) in range.enumerated() {
            XCTAssertEqual(
                index.values(of: batch[step], in: buffer),
                index.values(ofRow: row, in: buffer),
                "hàng \(row) lệch giữa hai đường đọc"
            )
        }
    }

    func testOutOfRangeRowsAreEmptyNotACrash() throws {
        let (index, buffer) = try makeIndex("a,b\n1,2\n")
        XCTAssertEqual(index.fields(ofRow: -5, in: buffer), [])
        XCTAssertEqual(index.fields(ofRow: 99, in: buffer), [])
        XCTAssertEqual(index.rows(90 ..< 100, in: buffer), [])
        XCTAssertNil(index.rowStart(99, in: buffer))
    }

    func testEmptyDocument() throws {
        let (index, buffer) = try makeIndex("")
        XCTAssertEqual(index.rowCount, 0)
        XCTAssertEqual(index.rowNumber(containingOffset: 0, in: buffer), 0)
    }

    /// Offset → số hàng, hai chiều khớp nhau.
    ///
    /// Đây là thứ giữ chỗ khi chuyển Văn bản ↔ Bảng. Sai một bậc thì mỗi lần chuyển chế độ
    /// người dùng lại trôi đi một hàng.
    func testOffsetToRowRoundTrips() throws {
        var text = "ma,ghi_chu\n"
        for row in 1 ... 400 {
            text += row % 37 == 0 ? "M\(row),\"nhiều dòng\nở đây\"\n" : "M\(row),binh thuong\n"
        }
        let (index, buffer) = try makeIndex(text)

        for row in 0 ..< index.rowCount {
            guard let start = index.rowStart(row, in: buffer) else {
                return XCTFail("không có đầu hàng \(row)")
            }
            XCTAssertEqual(index.rowNumber(containingOffset: start, in: buffer), row,
                           "đầu hàng \(row)")
            // Con nháy ở GIỮA hàng cũng phải cho ra chính hàng ấy — người dùng hiếm khi đứng
            // đúng ký tự đầu dòng.
            XCTAssertEqual(index.rowNumber(containingOffset: start + 2, in: buffer), row,
                           "giữa hàng \(row)")
        }
    }

    /// Hàng thừa cột không được biến mất khỏi bảng.
    func testWidestRowDecidesColumnCount() throws {
        let (index, _) = try makeIndex("a,b\n1,2\n3,4,5,6\n7,8\n")
        XCTAssertEqual(index.columnCount, 2, "số cột chuẩn lấy theo hàng đầu")
        XCTAssertEqual(index.widestRowColumnCount, 4, "bảng phải đủ chỗ cho hàng rộng nhất")
    }

    func testTabDialect() throws {
        let (index, buffer) = try makeIndex("a\tb\n1\t2\n", dialect: .tab)
        XCTAssertEqual(index.rowCount, 2)
        XCTAssertEqual(index.values(ofRow: 1, in: buffer), ["1", "2"])
    }

    /// Hàng dài hơn cửa sổ phân tích ban đầu (64 KB) vẫn phải đọc được.
    ///
    /// Cửa sổ nới ra theo cấp số nhân; nếu quên nhánh ấy thì hàm treo hoặc trả rỗng — và một
    /// ô ghi chú dài vài trăm KB là chuyện có thật trong dữ liệu xuất từ hệ thống khác.
    func testRowLongerThanTheParseWindow() throws {
        let long = String(repeating: "x", count: 200_000)
        let (index, buffer) = try makeIndex("a,b\n1,\(long)\n2,ngắn\n")
        XCTAssertEqual(index.rowCount, 3)
        XCTAssertEqual(index.values(ofRow: 1, in: buffer)[1].count, 200_000)
        XCTAssertEqual(index.values(ofRow: 2, in: buffer), ["2", "ngắn"])
    }

    /// Hủy giữa chừng thì ném lỗi, không trả về chỉ mục cụt.
    ///
    /// Chỉ mục cụt nguy hiểm hơn không có chỉ mục: bảng sẽ hiện đúng một phần file và không ai
    /// biết phần còn lại đã mất.
    func testCancellationThrowsRatherThanTruncating() throws {
        var text = "a,b\n"
        while text.utf8.count < 3_000_000 { text += "1,2\n" }
        let buffer = TextBuffer(text: text)
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(try CSVRowIndex.build(in: buffer, dialect: .comma, cancelToken: token))
    }
}
