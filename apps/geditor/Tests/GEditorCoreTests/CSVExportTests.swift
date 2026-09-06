import XCTest
@testable import GEditorCore

/// Chuyển CSV sang định dạng khác (FR-CSV-406).
final class CSVExportTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private let sample = "ma,ten,tien\nA1,Cam,3\nA2,An,1\n"

    // MARK: - Đổi delimiter

    func testChangesDelimiterToTab() throws {
        XCTAssertEqual(
            try CSVExport.convert(buffer(sample), dialect: .comma, to: .tsv),
            "ma\tten\ttien\nA1\tCam\t3\nA2\tAn\t1\n"
        )
    }

    /// Ô có sẵn ký tự Tab phải được BỌC khi đổi sang TSV.
    ///
    /// Không bọc thì nó lặng lẽ tách thành hai cột, và mọi cột sau đó lệch đi — đúng loại hỏng
    /// mà cả nhóm CSV này tồn tại để tránh.
    func testTabInsideAValueIsQuotedWhenConvertingToTSV() throws {
        let source = "a,b\n\"có\ttab\",2\n"
        let out = try CSVExport.convert(buffer(source), dialect: .comma, to: .tsv)
        XCTAssertEqual(out, "a\tb\n\"có\ttab\"\t2\n")

        // Và đọc lại bằng chính parser của ta thì vẫn ra HAI cột.
        let rows = CSVEngine.parse(Array(out.utf8), dialect: .tab)
        XCTAssertEqual(rows.map(\.count), [2, 2])
    }

    /// Dấu phẩy trong ô KHÔNG còn cần bọc khi đã chuyển sang TSV.
    func testCommaNoLongerNeedsQuotingInTSV() throws {
        let out = try CSVExport.convert(buffer("a,b\n\"x, y\",2\n"), dialect: .comma, to: .tsv)
        XCTAssertEqual(out, "a\tb\nx, y\t2\n")
    }

    // MARK: - XML

    func testXMLUsesHeaderNamesAsElements() throws {
        let out = try CSVExport.convert(buffer(sample), dialect: .comma, to: .xml)
        XCTAssertTrue(out.contains("<ma>A1</ma>"), out)
        XCTAssertTrue(out.contains("<ten>Cam</ten>"), out)
        XCTAssertTrue(out.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(out.hasSuffix("</bang>\n"))
    }

    /// Ký tự đặc biệt của XML phải được escape.
    ///
    /// Một dấu `<` chưa escape làm CẢ FILE không phân tích được — hỏng toàn bộ, không phải
    /// hỏng một ô.
    func testXMLEscapesSpecialCharacters() throws {
        let out = try CSVExport.convert(
            buffer("a,b\n\"<tag> & 'nháy'\",2\n"), dialect: .comma, to: .xml
        )
        XCTAssertTrue(out.contains("&lt;tag&gt; &amp; &apos;nháy&apos;"), out)
        XCTAssertFalse(out.contains("<tag>"), "thẻ giả vẫn lọt vào đầu ra")
    }

    /// Tên cột không hợp lệ phải được làm sạch, nhưng chữ tiếng Việt thì GIỮ.
    ///
    /// Bỏ dấu sẽ làm hai cột "ngày" và "ngay" thành một tên — mất dữ liệu của một cột.
    func testXMLSanitisesElementNamesButKeepsVietnamese() {
        XCTAssertEqual(CSVExport.elementName("ngày sinh", fallback: 0), "ngày_sinh")
        XCTAssertEqual(CSVExport.elementName("2026", fallback: 0), "_2026")
        XCTAssertEqual(CSVExport.elementName("", fallback: 4), "cot5")
        XCTAssertEqual(CSVExport.elementName("a<b>c", fallback: 0), "a_b_c")
        XCTAssertNotEqual(CSVExport.elementName("ngày", fallback: 0),
                          CSVExport.elementName("ngay", fallback: 0))
    }

    // MARK: - Markdown

    func testMarkdownTable() throws {
        XCTAssertEqual(
            try CSVExport.convert(buffer(sample), dialect: .comma, to: .markdown),
            """
            | ma | ten | tien |
            | --- | --- | --- |
            | A1 | Cam | 3 |
            | A2 | An | 1 |

            """
        )
    }

    /// Dấu `|` trong ô phải escape, xuống dòng phải thành `<br>`.
    ///
    /// Cả hai đều phá cấu trúc bảng: một dấu `|` chưa escape tách ô thành hai cột và đẩy lệch
    /// mọi cột sau nó.
    func testMarkdownEscapesPipesAndNewlines() throws {
        let out = try CSVExport.convert(
            buffer("a,b\n\"x|y\",\"dòng 1\ndòng 2\"\n"), dialect: .comma, to: .markdown
        )
        XCTAssertTrue(out.contains("x\\|y"), out)
        XCTAssertTrue(out.contains("dòng 1<br>dòng 2"), out)
        // Mọi hàng phải có ĐÚNG số dấu ngăn cột như hàng tiêu đề.
        //
        // Đếm dấu CHƯA escape, không đếm mọi ký tự `|`: bản đầu đếm tất, nên chính dấu `\|`
        // vừa escape đúng lại làm bài kiểm đỏ — bài kiểm sai chứ không phải code sai.
        let bars = out.split(separator: "\n").map { line -> Int in
            var count = 0
            var previous: Character = " "
            for character in line {
                if character == "|", previous != "\\" { count += 1 }
                previous = character
            }
            return count
        }
        XCTAssertEqual(Set(bars).count, 1, "số cột không đều: \(bars)")
    }

    /// Hàng rộng hơn tiêu đề không được cắt cụt.
    func testMarkdownWidensToTheWidestRow() throws {
        let out = try CSVExport.convert(buffer("a,b\n1,2,3\n"), dialect: .comma, to: .markdown)
        XCTAssertTrue(out.contains("| a | b | Cột 3 |"), out)
        XCTAssertTrue(out.contains("| 1 | 2 | 3 |"), out)
    }

    // MARK: - SQL INSERT

    func testSQLQuotesIdentifiersAndStrings() throws {
        let out = try CSVExport.convert(
            buffer(sample), dialect: .comma, to: .sqlInsert, tableName: "khach_hang"
        )
        XCTAssertTrue(
            out.contains("INSERT INTO \"khach_hang\" (\"ma\", \"ten\", \"tien\") VALUES ('A1', 'Cam', '3');"),
            out
        )
    }

    /// Nháy đơn trong giá trị phải NHÂN ĐÔI.
    ///
    /// Đây là chỗ duy nhất trong cả nhóm chuyển đổi mà làm sai không chỉ ra kết quả xấu: câu
    /// lệnh không chạy được, và một giá trị dựng sẵn có thể nối thêm câu lệnh khác vào sau.
    func testSQLDoublesSingleQuotes() {
        XCTAssertEqual(CSVExport.sqlString("O'Brien"), "'O''Brien'")
        XCTAssertEqual(CSVExport.sqlString("'; DROP TABLE x; --"), "'''; DROP TABLE x; --'")
        XCTAssertEqual(CSVExport.sqlIdentifier("cột \"lạ\""), "\"cột \"\"lạ\"\"\"")
    }

    /// Cột suy ra được là SỐ thì viết trần, không bọc nháy.
    func testSQLLeavesNumericColumnsUnquoted() throws {
        var text = "ma,tien\n"
        for row in 1 ... 20 { text += "KH\(row),\(row * 100)\n" }
        let out = try CSVExport.convert(buffer(text), dialect: .comma, to: .sqlInsert)

        XCTAssertTrue(out.contains("VALUES ('KH1', 100);"), out)
        XCTAssertFalse(out.contains("'100'"), "cột số bị bọc thành chuỗi")
    }

    /// Ô rỗng của cột số thành NULL, của cột chữ vẫn là chuỗi rỗng.
    func testSQLEmptyCellsBecomeNullOnlyInNumericColumns() throws {
        var text = "ma,tien\n"
        for row in 1 ... 20 { text += "KH\(row),\(row * 100)\n" }
        text += "KH21,\nKH22,\n,50\n"
        let out = try CSVExport.convert(buffer(text), dialect: .comma, to: .sqlInsert)

        XCTAssertTrue(out.contains("VALUES ('KH21', NULL);"), out)
        XCTAssertTrue(out.contains("VALUES ('', 50);"), out)
    }

    // MARK: - Bản xem trước

    /// Xem trước 5 hàng đi qua ĐÚNG hàm sinh ra bản thật.
    ///
    /// Bài này chốt điều đó bằng cách so: bản xem trước phải là TIỀN TỐ của bản đầy đủ (với
    /// những định dạng nối tiếp từng hàng), chứ không phải một chuỗi na ná.
    func testPreviewIsAPrefixOfTheFullOutput() throws {
        var text = "ma,ten\n"
        for row in 1 ... 50 { text += "KH\(row),Tên \(row)\n" }
        let target = buffer(text)

        for format in [CSVExport.Format.tsv, .sqlInsert] {
            let preview = try CSVExport.convert(target, dialect: .comma, to: format, maxRows: 5)
            let full = try CSVExport.convert(target, dialect: .comma, to: format)
            XCTAssertTrue(full.hasPrefix(preview), "\(format): xem trước không khớp bản thật")
            XCTAssertLessThan(preview.count, full.count)
        }
    }

    func testPreviewLimitsRowCount() throws {
        var text = "ma,ten\n"
        for row in 1 ... 50 { text += "KH\(row),Tên \(row)\n" }
        let target = buffer(text)

        let markdown = try CSVExport.convert(target, dialect: .comma, to: .markdown, maxRows: 5)
        // 1 hàng tiêu đề + 1 hàng gạch + 5 hàng dữ liệu.
        XCTAssertEqual(markdown.split(separator: "\n").count, 7)

        let json = try CSVExport.convert(target, dialect: .comma, to: .json, maxRows: 5)
        XCTAssertEqual(json.components(separatedBy: "\"ma\":").count - 1, 5)

        let xml = try CSVExport.convert(target, dialect: .comma, to: .xml, maxRows: 5)
        XCTAssertEqual(xml.components(separatedBy: "<hang>").count - 1, 5)
    }

    // MARK: - Trường hợp biên

    func testEmptyDocumentGivesEmptyOrSkeletonOutput() throws {
        let empty = buffer("")
        for format in CSVExport.Format.allCases {
            let out = try CSVExport.convert(empty, dialect: .comma, to: format)
            XCTAssertFalse(out.contains("A1"), "\(format)")
        }
        XCTAssertEqual(try CSVExport.convert(empty, dialect: .comma, to: .markdown), "")
        XCTAssertEqual(try CSVExport.convert(empty, dialect: .comma, to: .json), "[]")
    }

    /// Field bọc ngoặc chứa xuống dòng phải sang định dạng mới NGUYÊN VẸN.
    func testQuotedNewlineSurvivesEveryFormat() throws {
        let target = buffer("ma,ghi_chu\nA,\"dòng 1\ndòng 2\"\n")

        let tsv = try CSVExport.convert(target, dialect: .comma, to: .tsv)
        XCTAssertEqual(CSVEngine.parse(Array(tsv.utf8), dialect: .tab).count, 2,
                       "vẫn phải là hai hàng logic")
        XCTAssertTrue(try CSVExport.convert(target, dialect: .comma, to: .json).contains("dòng 1\\ndòng 2"))
        XCTAssertTrue(try CSVExport.convert(target, dialect: .comma, to: .markdown).contains("dòng 1<br>dòng 2"))
        XCTAssertTrue(try CSVExport.convert(target, dialect: .comma, to: .sqlInsert).contains("'dòng 1\ndòng 2'"))
    }

    func testCancellationThrows() throws {
        var text = "a,b\n"
        while text.utf8.count < 2_000_000 { text += "1,2\n" }
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(
            try CSVExport.convert(buffer(text), dialect: .comma, to: .xml, cancelToken: token)
        )
    }
}
