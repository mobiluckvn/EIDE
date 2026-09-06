import XCTest
@testable import GEditorCore

/// Suy luận và kiểm tra kiểu dữ liệu theo cột (FR-CSV-405).
final class CSVValidationTests: XCTestCase {

    private func buffer(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    /// Dựng một cột đủ dài để vượt ngưỡng mẫu tối thiểu.
    private func document(header: String, rows: [String]) -> TextBuffer {
        buffer(header + "\n" + rows.joined(separator: "\n") + "\n")
    }

    // MARK: - Nhận dạng ngày

    func testRecognisesTheThreeDateShapes() {
        XCTAssertEqual(CSVValidator.dateFormat(of: "2026-08-19"), .iso)
        XCTAssertEqual(CSVValidator.dateFormat(of: "19/08/2026"), .dayFirstSlash)
        XCTAssertEqual(CSVValidator.dateFormat(of: "19-08-2026"), .dayFirstDash)
    }

    /// Đúng khuôn nhưng không tồn tại thì KHÔNG phải ngày.
    ///
    /// Đây chính là loại lỗi mà người ta bật tính năng kiểm tra lên để tìm; nhận bừa theo hình
    /// dạng thì nó lọt qua.
    func testRejectsImpossibleDates() {
        for value in ["31/02/2026", "2026-02-30", "00/01/2026", "2026-13-01", "32/01/2026"] {
            XCTAssertNil(CSVValidator.dateFormat(of: value), "«\(value)» không phải ngày có thật")
        }
    }

    func testLeapYear() {
        XCTAssertEqual(CSVValidator.dateFormat(of: "2024-02-29"), .iso, "2024 là năm nhuận")
        XCTAssertNil(CSVValidator.dateFormat(of: "2026-02-29"), "2026 không nhuận")
        XCTAssertEqual(CSVValidator.dateFormat(of: "2000-02-29"), .iso, "2000 chia hết 400 nên nhuận")
        XCTAssertNil(CSVValidator.dateFormat(of: "1900-02-29"), "1900 chia hết 100 nên KHÔNG nhuận")
    }

    func testRejectsThingsThatAreNotDates() {
        for value in ["", "2026-8-19", "19/8/2026", "abcdefghij", "2026/08/19", "19.08.2026"] {
            XCTAssertNil(CSVValidator.dateFormat(of: value), "«\(value)»")
        }
    }

    // MARK: - Suy luận kiểu cột

    func testInfersNumberDateAndText() throws {
        let target = document(header: "ma,tien,ngay", rows: (1 ... 20).map {
            "KH\($0),\($0 * 1000).5,2026-08-\(String(format: "%02d", $0))"
        })
        let types = try CSVValidator.inferTypes(in: target, dialect: .comma)
        XCTAssertEqual(types, [.text, .number, .date(.iso)])
    }

    /// Mẫu quá ít thì KHÔNG dám kết luận.
    ///
    /// Ba dòng đều là số chưa nói lên gì — một cột mã chứng từ có thể tình cờ mở đầu bằng ba
    /// dòng toàn số, và kết luận vội sẽ báo lỗi cho mọi dòng còn lại.
    func testTooFewSamplesStayText() throws {
        let target = document(header: "a", rows: ["1", "2", "3"])
        XCTAssertEqual(try CSVValidator.inferTypes(in: target, dialect: .comma), [.text])
    }

    /// Cột lẫn lộn thật sự thì về chuỗi và im lặng.
    func testGenuinelyMixedColumnIsText() throws {
        let values = (1 ... 20).map { $0 % 2 == 0 ? "\($0)" : "chuỗi \($0)" }
        let target = document(header: "a", rows: values)
        XCTAssertEqual(try CSVValidator.inferTypes(in: target, dialect: .comma), [.text])
    }

    /// Đa số thắng: một cột số có vài ô hỏng VẪN là cột số.
    ///
    /// Nếu đòi 100% khớp thì đúng những ô hỏng ấy — thứ cần tìm — lại làm cả cột bị xếp là
    /// chuỗi và không báo gì cả.
    func testAFewBadCellsDoNotChangeTheColumnType() throws {
        var values = (1 ... 100).map { "\($0)" }
        values[41] = "chưa có"
        let target = document(header: "a", rows: values)
        XCTAssertEqual(try CSVValidator.inferTypes(in: target, dialect: .comma), [.number])
    }

    func testEmptyCellsDoNotCountTowardsTheType() throws {
        var values = (1 ... 30).map { "\($0)" }
        values.append(contentsOf: Array(repeating: "", count: 30))
        let target = document(header: "a", rows: values)
        XCTAssertEqual(try CSVValidator.inferTypes(in: target, dialect: .comma), [.number],
                       "ba mươi ô rỗng không được làm cột số thành chuỗi")
    }

    // MARK: - Kiểm tra

    func testReportsWrongTypeCells() throws {
        var rows = (1 ... 30).map { "KH\($0),\($0)00" }
        rows[9] = "KH10,chưa thu"
        let target = document(header: "ma,tien", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertEqual(report.types, [.text, .number])
        XCTAssertEqual(report.issues.count, 1)
        XCTAssertEqual(report.issues[0].rowIndex, 10, "hàng tiêu đề là 0, nên hàng thứ 10 là dòng dữ liệu thứ 10")
        XCTAssertEqual(report.issues[0].kind, .wrongType(column: 1, expected: .number, value: "chưa thu"))
        XCTAssertFalse(report.truncated)
    }

    func testReportsBothKindsInOnePass() throws {
        var rows = (1 ... 30).map { "KH\($0),\($0)00" }
        rows[4] = "KH5,100,thừa"
        rows[9] = "KH10,không phải số"
        let target = document(header: "ma,tien", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma)
        let kinds = report.issues.map(\.kind)
        XCTAssertTrue(kinds.contains(.columnCount(expected: 2, actual: 3)))
        XCTAssertTrue(kinds.contains(.wrongType(column: 1, expected: .number, value: "không phải số")))
    }

    /// Hàng tiêu đề không bị kiểm kiểu.
    ///
    /// Tên cột là chữ; báo "tien không phải số" ở mọi file có tiêu đề sẽ chôn vùi lỗi thật.
    func testHeaderRowIsNotTypeChecked() throws {
        let target = document(header: "ma,tien", rows: (1 ... 30).map { "KH\($0),\($0)00" })
        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertTrue(report.issues.isEmpty, "báo nhầm: \(report.issues.map(\.description))")
    }

    func testEmptyCellsAreNotTypeErrors() throws {
        var rows = (1 ... 30).map { "KH\($0),\($0)00" }
        rows[3] = "KH4,"
        let target = document(header: "ma,tien", rows: rows)
        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertTrue(report.issues.isEmpty, "ô rỗng là THIẾU dữ liệu, không phải SAI kiểu")
    }

    /// Ngày sai lịch trong một cột ngày phải bị bắt.
    func testImpossibleDateInADateColumnIsReported() throws {
        var rows = (1 ... 28).map { "K\($0),2026-01-\(String(format: "%02d", $0))" }
        rows[6] = "K7,2026-02-31"
        let target = document(header: "ma,ngay", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertEqual(report.types[1], .date(.iso))
        XCTAssertEqual(report.issues.count, 1)
        XCTAssertEqual(
            report.issues[0].kind, .wrongType(column: 1, expected: .date(.iso), value: "2026-02-31")
        )
    }

    /// Cột ngày dạng DD/MM thì một ô dạng ISO cũng là lỗi.
    ///
    /// Trộn hai dạng trong một cột là lỗi nhập liệu thật, và nó âm thầm phá mọi phép sắp xếp
    /// hay lọc theo ngày về sau.
    func testMixedDateFormatsInOneColumnAreReported() throws {
        var rows = (1 ... 28).map { "K\($0),\(String(format: "%02d", $0))/01/2026" }
        rows[6] = "K7,2026-01-07"
        let target = document(header: "ma,ngay", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertEqual(report.types[1], .date(.dayFirstSlash))
        XCTAssertEqual(report.issues.count, 1)
        XCTAssertEqual(report.issues[0].kind,
                       .wrongType(column: 1, expected: .date(.dayFirstSlash), value: "2026-01-07"))
    }

    /// Chạm trần thì phải NÓI RA là đã cắt.
    ///
    /// "12 lỗi" và "12 lỗi đầu tiên trong số không biết bao nhiêu" là hai kết luận khác hẳn.
    func testTruncationIsReported() throws {
        // Hai mươi ô hỏng trên năm trăm hai mươi ô: dưới ngưỡng 5%, nên cột VẪN là cột số và
        // hai mươi ô kia là lỗi. Bản đầu tôi cho một nửa số ô hỏng — lúc ấy cột thành chuỗi và
        // không có lỗi nào để mà cắt.
        let rows = (1 ... 20).map { "KH\($0),sai" } + (1 ... 500).map { "KH\($0),\($0)" }
        let target = document(header: "ma,tien", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma, limit: 5)
        XCTAssertEqual(report.issues.count, 5)
        XCTAssertTrue(report.truncated)

        let full = try CSVValidator.validate(in: target, dialect: .comma, limit: 0)
        XCTAssertFalse(full.truncated)
        XCTAssertGreaterThan(full.issues.count, 5)
    }

    // MARK: - Số cột (TC-CSV-06)
    //
    // Ba bài dưới đây chuyển từ `CSVOpsTests` sang khi `CSVOps.validate` bị xóa. Giữ hai bản
    // kiểm cùng một thứ là cách chắc chắn để chúng lệch nhau về sau.

    func testFindsRowsWithWrongColumnCount() throws {
        let target = buffer("a,b,c\n1,2,3\n4,5\n6,7,8\n9,10,11,12\n")
        let report = try CSVValidator.validate(in: target, dialect: .comma)

        XCTAssertEqual(report.issues.count, 2)
        XCTAssertEqual(report.issues[0].rowIndex, 2, "hàng thứ ba, đếm từ 0")
        XCTAssertEqual(report.issues[0].kind, .columnCount(expected: 3, actual: 2))
        XCTAssertEqual(report.issues[1].rowIndex, 4)
        XCTAssertEqual(report.issues[1].kind, .columnCount(expected: 3, actual: 4))
    }

    /// Offset phải chỉ đúng đầu hàng để lớp trên nhảy tới được (TC-CSV-06).
    func testColumnCountIssueReportsJumpableOffset() throws {
        let source = "a,b,c\n1,2,3\n4,5\n"
        let target = buffer(source)
        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertEqual(report.issues.count, 1)

        let offset = report.issues[0].offset
        XCTAssertEqual(target.lineNumber(atOffset: offset), 2, "dòng thứ 3, đánh số từ 0")
        XCTAssertEqual(String(decoding: Array(source.utf8)[offset...], as: UTF8.self), "4,5\n")
    }

    func testAcceptsExplicitExpectedColumnCount() throws {
        let target = buffer("a,b\nc,d\n")
        let report = try CSVValidator.validate(in: target, dialect: .comma, expectedColumns: 3)
        XCTAssertEqual(report.issues.count, 2)
    }

    /// Offset trong báo cáo phải trỏ đúng đầu hàng.
    func testIssueOffsetPointsAtTheRowStart() throws {
        var rows = (1 ... 30).map { "KH\($0),\($0)" }
        rows[11] = "KH12,sai"
        let target = document(header: "ma,tien", rows: rows)

        let report = try CSVValidator.validate(in: target, dialect: .comma)
        guard let issue = report.issues.first else { return XCTFail("không tìm ra lỗi") }
        let index = try CSVRowIndex.build(in: target, dialect: .comma)
        XCTAssertEqual(issue.offset, index.rowStart(issue.rowIndex, in: target))
    }

    /// Field bọc ngoặc được kiểm theo GIÁ TRỊ THẬT.
    func testQuotedValuesAreCheckedAfterUnescaping() throws {
        let rows = (1 ... 30).map { "K\($0),\"\($0)\"" }
        let target = document(header: "ma,tien", rows: rows)
        let report = try CSVValidator.validate(in: target, dialect: .comma)
        XCTAssertEqual(report.types[1], .number, "dấu bọc không được làm cột số thành chuỗi")
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testCancellationThrows() throws {
        var text = "a,b\n"
        while text.utf8.count < 2_000_000 { text += "1,2\n" }
        let token = CancelToken()
        token.cancel()
        XCTAssertThrowsError(
            try CSVValidator.validate(in: buffer(text), dialect: .comma, cancelToken: token)
        )
    }

    func testEmptyDocument() throws {
        let report = try CSVValidator.validate(in: buffer(""), dialect: .comma)
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(report.rowsChecked, 0)
    }
}
