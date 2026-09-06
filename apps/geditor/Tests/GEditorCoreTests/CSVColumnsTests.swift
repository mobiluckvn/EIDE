import XCTest
@testable import GEditorCore

/// Tô màu theo cột trên một cửa sổ (FR-CSV-402).
final class CSVColumnsTests: XCTestCase {

    private func text(_ buffer: TextBuffer, _ span: CSVColumnSpan) -> String {
        String(decoding: buffer.bytes(in: span.range), as: UTF8.self)
    }

    func testColumnsOfASimpleTable() {
        let buffer = TextBuffer(text: "ten,tuoi,thanh_pho\nAn,30,Ha Noi\nBinh,25,Hue\n")
        let spans = CSVColumns.spans(in: buffer, range: 0 ..< buffer.count, dialect: .comma)

        let firstRow = spans.filter { $0.row == 0 }.sorted { $0.column < $1.column }
        XCTAssertEqual(firstRow.map { text(buffer, $0) }, ["ten", "tuoi", "thanh_pho"])
        let secondRow = spans.filter { $0.row == 1 }.sorted { $0.column < $1.column }
        XCTAssertEqual(secondRow.map { text(buffer, $0) }, ["An", "30", "Ha Noi"])
    }

    /// Field bọc ngoặc chứa DẤU PHẨY không được làm lệch cột.
    ///
    /// Đây là luật RFC 4180 số 1, và là lý do tô màu phải chạy trên parser chứ không trên
    /// phép tách chuỗi theo dấu phẩy.
    func testQuotedDelimiterDoesNotShiftColumns() {
        let buffer = TextBuffer(text: "a,b,c\n\"mot, hai\",x,y\n")
        let spans = CSVColumns.spans(in: buffer, range: 0 ..< buffer.count, dialect: .comma)
        let row = spans.filter { $0.row == 1 }.sorted { $0.column < $1.column }
        XCTAssertEqual(row.map { text(buffer, $0) }, ["\"mot, hai\"", "x", "y"])
    }

    /// Field bọc chứa XUỐNG DÒNG: một hàng logic trải nhiều dòng vật lý (luật RFC 4180 số 3).
    func testQuotedNewlineKeepsOneLogicalRow() {
        let buffer = TextBuffer(text: "a,b\n\"dong mot\ndong hai\",x\nc,d\n")
        let spans = CSVColumns.spans(in: buffer, range: 0 ..< buffer.count, dialect: .comma)
        let rows = Set(spans.map(\.row))
        XCTAssertEqual(rows.count, 3, "phải là 3 hàng LOGIC, không phải 4 dòng vật lý")
        let middle = spans.filter { $0.row == 1 }.sorted { $0.column < $1.column }
        XCTAssertEqual(middle.map { text(buffer, $0) }, ["\"dong mot\ndong hai\"", "x"])
    }

    // MARK: - Cửa sổ

    /// Bài quan trọng nhất: cột tính trên CỬA SỔ phải bằng cột tính trên CẢ TÀI LIỆU.
    ///
    /// Cắt cửa sổ vào giữa một field bọc chứa xuống dòng sẽ làm mọi cột sau đó lệch một bậc.
    /// Màu lệch cột trên file dữ liệu tệ hơn không màu, vì người dùng đọc theo màu.
    func testWindowAgreesWithWholeDocument() {
        var source = "cot_a,cot_b,cot_c\n"
        for index in 0 ..< 4_000 {
            // Cứ vài hàng lại có một field bọc chứa xuống dòng — đúng thứ làm lệch cột.
            if index % 7 == 0 {
                // Dòng NỐI TIẾP phải chứa dấu phẩy, nếu không thì cắt vào giữa field bọc
                // cũng chẳng lệch cột: parser tự đồng bộ lại ở mỗi dấu xuống dòng, và số
                // field tình cờ vẫn đúng. Đối chứng âm đã chứng minh điều đó — bản đầu của
                // bài này KHÔNG bắt được lỗi vì thiếu đúng dấu phẩy này.
                source += "\"gia tri \(index), co phay\nvat sang dong hai, cung co phay\",b\(index),c\(index)\n"
            } else {
                source += "a\(index),b\(index),c\(index)\n"
            }
        }
        let buffer = TextBuffer(text: source)

        let whole = CSVColumns.spans(in: buffer, range: 0 ..< buffer.count, dialect: .comma)
        let byRange = Dictionary(
            whole.map { ("\($0.range.lowerBound)-\($0.range.upperBound)", $0.column) },
            uniquingKeysWith: { first, _ in first }
        )

        // Cắt CỐ Ý vào giữa một field bọc nhiều dòng.
        //
        // Bản đầu chỉ lấy biên dòng ở giữa file, và chỗ ấy tình cờ rơi vào một hàng bình
        // thường — nên đối chứng âm (bỏ hẳn phép dóng) vẫn xanh. Bài kiểm chọn ngẫu nhiên
        // chỗ dễ thì không kiểm gì cả.
        let all = buffer.bytes(in: 0 ..< buffer.count)
        let marker = Array("vat sang dong hai".utf8)
        var probe = buffer.count / 2
        while probe < buffer.count - marker.count {
            if Array(all[probe ..< probe + marker.count]) == marker { break }
            probe += 1
        }
        // Lùi về đầu dòng vật lý chứa đoạn ấy — đầu dòng này nằm TRONG field bọc.
        var start = probe
        while start > 0, all[start - 1] != UInt8(ascii: "\n") { start -= 1 }
        XCTAssertGreaterThan(start, 0, "không tìm được chỗ cắt nằm trong field bọc")
        let window = start ..< Swift.min(buffer.count, start + 20_000)

        let windowed = CSVColumns.spans(in: buffer, range: window, dialect: .comma)
        XCTAssertFalse(windowed.isEmpty)

        var checked = 0
        for span in windowed {
            let key = "\(span.range.lowerBound)-\(span.range.upperBound)"
            guard let expected = byRange[key] else { continue }   // đoạn bị cắt ở mép
            XCTAssertEqual(span.column, expected, "đoạn «\(text(buffer, span))» lệch cột")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 500, "phải đối chiếu được nhiều đoạn thì bài mới có nghĩa")
    }

    /// Cửa sổ bắt đầu NGAY GIỮA một field bọc nhiều dòng.
    func testWindowStartingInsideAQuotedFieldIsRealigned() {
        var source = "a,b\n"
        source += "\"" + String(repeating: "dong trong ngoac\n", count: 50) + "\",x\n"
        source += "sau,day\n"
        let buffer = TextBuffer(text: source)

        // Chọn một đầu dòng nằm giữa field bọc.
        let inside = source.utf8.count / 2
        let all = buffer.bytes(in: 0 ..< buffer.count)
        var lineStart = inside
        while lineStart > 0, all[lineStart - 1] != UInt8(ascii: "\n") { lineStart -= 1 }

        let safe = CSVColumns.safeRowStart(at: lineStart, in: buffer, dialect: .comma)
        XCTAssertLessThan(safe, lineStart, "phải lùi ra khỏi field bọc")
        XCTAssertEqual(safe, 4, "đầu hàng an toàn là ngay sau dòng header")
    }

    func testNoQuotesMeansEveryLineStartIsSafe() {
        let buffer = TextBuffer(text: "a,b\nc,d\ne,f\n")
        XCTAssertEqual(CSVColumns.safeRowStart(at: 8, in: buffer, dialect: .comma), 8)
        XCTAssertEqual(CSVColumns.safeRowStart(at: 0, in: buffer, dialect: .comma), 0)
    }

    func testEmptyAndOutOfRangeAreSafe() {
        let empty = TextBuffer(text: "")
        XCTAssertTrue(CSVColumns.spans(in: empty, range: 0 ..< 0, dialect: .comma).isEmpty)
        let buffer = TextBuffer(text: "a,b\n")
        XCTAssertTrue(CSVColumns.spans(in: buffer, range: 99 ..< 200, dialect: .comma).isEmpty)
    }

    func testTabDialect() {
        let buffer = TextBuffer(text: "ten\ttuoi\nAn\t30\n")
        let spans = CSVColumns.spans(in: buffer, range: 0 ..< buffer.count, dialect: .tab)
        XCTAssertEqual(spans.filter { $0.row == 1 }.sorted { $0.column < $1.column }
                        .map { text(buffer, $0) }, ["An", "30"])
    }
}
