import XCTest
@testable import GEditorCore

/// Chuẩn hóa cột ngày về ISO 8601 (FR-CLN-001).
final class CSVCleanDateTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    // MARK: - Đọc một ô

    func testReadsTheCommonShapes() {
        let cases: [(String, String)] = [
            ("2026-07-02", "2026-07-02"),
            ("2026/07/02", "2026-07-02"),
            ("25/07/2026", "2026-07-25"),   // ngày > 12 nên không nhập nhằng
            ("31-12-2026", "2026-12-31"),
            ("31.12.2026", "2026-12-31"),
            ("5-Jul-26", "2026-07-05"),
            ("5 July 2026", "2026-07-05"),
            ("Jul 5, 2026", "2026-07-05"),
            ("2026-7-2", "2026-07-02"),     // thiếu số 0 đệm vẫn đọc được
        ]
        for (input, expected) in cases {
            guard case let .certain(date, _) = CSVClean.readDate(input) else {
                return XCTFail("«\(input)» phải đọc được chắc chắn")
            }
            XCTAssertEqual(date.iso, expected, "«\(input)»")
        }
    }

    /// Ô mà cả hai số đầu đều ≤ 12 thì đọc được HAI cách — và hàm không được chọn giúp.
    func testAmbiguousCellReportsBothReadings() {
        guard case let .needsOrder(dayFirst, monthFirst) = CSVClean.readDate("03/04/2026") else {
            return XCTFail("03/04/2026 phải là mơ hồ")
        }
        XCTAssertEqual(dayFirst.iso, "2026-04-03")
        XCTAssertEqual(monthFirst.iso, "2026-03-04")
    }

    /// Ô chỉ đọc được một cách chính là BẰNG CHỨNG về quy ước của cả cột.
    func testUnambiguousCellCarriesEvidence() {
        guard case let .certain(_, implies) = CSVClean.readDate("31/12/2026") else {
            return XCTFail("31/12/2026 phải đọc được")
        }
        XCTAssertEqual(implies, .dayFirst)

        guard case let .certain(_, other) = CSVClean.readDate("12/31/2026") else {
            return XCTFail("12/31/2026 phải đọc được")
        }
        XCTAssertEqual(other, .monthFirst)
    }

    /// Những thứ KHÔNG được nhận là ngày. Mỗi mục ở đây là một cách làm hỏng dữ liệu.
    func testRefusesToGuess() {
        let notDates = [
            "2026-07-02 10:30",   // nhận thì phần giờ bị vứt đi — mất dữ liệu
            "1.2.3",              // số hiệu phiên bản
            "1,2,3",              // ô danh sách trong cột không phải ngày
            "31/02/2026",         // đúng khuôn, không tồn tại
            "2026-02-30",
            "00/01/2026",
            "Jul5-2026",          // dính liền, không tách rõ được
            "abc",
            "1234567",
            "07/2026",            // thiếu ngày
        ]
        for value in notDates {
            XCTAssertEqual(CSVClean.readDate(value), .notADate, "«\(value)» không được nhận là ngày")
        }
    }

    /// Năm hai chữ số theo cửa sổ POSIX — cùng quy ước với bảng tính mà dữ liệu vừa xuất ra.
    func testTwoDigitYearWindow() {
        func year(_ value: String) -> Int? {
            guard case let .certain(date, _) = CSVClean.readDate(value) else { return nil }
            return date.year
        }
        XCTAssertEqual(year("15-Mar-26"), 2026)
        XCTAssertEqual(year("15-Mar-69"), 2069, "69 là mốc cuối của thế kỷ này")
        XCTAssertEqual(year("15-Mar-70"), 1970, "70 lật về thế kỷ trước")
        XCTAssertEqual(year("15-Mar-99"), 1999)
    }

    // MARK: - Khảo sát cột

    /// Một ô có ngày > 12 là đủ để biết quy ước của cả cột — không cần hỏi.
    func testColumnEvidenceRemovesTheQuestion() throws {
        let buffer = document("""
        ma,ngay
        A1,03/04/2026
        A2,31/12/2026
        A3,05/06/2026

        """)
        let scan = try CSVClean.scanDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .certain(.dayFirst))
        XCTAssertEqual(scan.ambiguousCells, 2)
        XCTAssertFalse(scan.needsQuestion, "dữ liệu đã tự nói ra quy ước")
    }

    /// Cột toàn ô mơ hồ thì PHẢI hỏi.
    func testAllAmbiguousMeansAsk() throws {
        let buffer = document("ma,ngay\nA1,03/04/2026\nA2,05/06/2026\n")
        let scan = try CSVClean.scanDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .ambiguous)
        XCTAssertTrue(scan.needsQuestion)
    }

    /// Cột lẫn cả hai quy ước: áp một quy ước cho cả cột sẽ làm hỏng đúng những ô kia.
    func testConflictingColumnIsReportedAsSuch() throws {
        let buffer = document("ma,ngay\nA1,31/12/2026\nA2,12/31/2026\nA3,03/04/2026\n")
        let scan = try CSVClean.scanDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .conflicting)
        XCTAssertTrue(scan.needsQuestion)
    }

    // MARK: - Kế hoạch chuẩn hóa

    func testNormalisesMixedShapesToISO() throws {
        let buffer = document("""
        ma,ngay
        A1,25/07/2026
        A2,2026-07-02
        A3,5-Jul-26

        """)
        let plan = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)

        XCTAssertEqual(plan.report.cellsChanged, 2)
        XCTAssertEqual(plan.report.cellsAlreadyClean, 1, "ô đã đúng ISO không bị đụng tới")
        XCTAssertEqual(plan.edits.count, 2, "chỉ sửa ô thực sự đổi")

        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertEqual(buffer.text, """
        ma,ngay
        A1,2026-07-25
        A2,2026-07-02
        A3,2026-07-05

        """)
    }

    /// Chưa hỏi quy ước thì ô mơ hồ để NGUYÊN và bị đánh dấu — không đoán.
    func testWithoutOrderAmbiguousCellsAreLeftAlone() throws {
        let buffer = document("ma,ngay\nA1,03/04/2026\nA2,31/12/2026\n")
        let plan = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)

        XCTAssertEqual(plan.report.unparsable.count, 1)
        XCTAssertEqual(plan.report.unparsable.first?.value, "03/04/2026")
        XCTAssertEqual(plan.report.unparsable.first?.rowIndex, 1)

        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertTrue(buffer.text.contains("A1,03/04/2026"), "ô mơ hồ còn nguyên")
        XCTAssertTrue(buffer.text.contains("A2,2026-12-31"))
    }

    func testOrderAnswersTheAmbiguity() throws {
        let buffer = document("ma,ngay\nA1,03/04/2026\n")
        let dayFirst = try CSVClean.normalizeDates(
            column: 1, in: buffer, dialect: .comma, order: .dayFirst
        )
        let monthFirst = try CSVClean.normalizeDates(
            column: 1, in: buffer, dialect: .comma, order: .monthFirst
        )
        XCTAssertEqual(dayFirst.samples.first?.after, "2026-04-03")
        XCTAssertEqual(monthFirst.samples.first?.after, "2026-03-04")
    }

    /// Hàng tiêu đề không phải dữ liệu — chuẩn hóa nó sẽ xóa mất tên cột.
    func testHeaderIsNeverTouched() throws {
        let buffer = document("ma,02/07/2026\nA1,03/04/2026\n")
        let plan = try CSVClean.normalizeDates(
            column: 1, in: buffer, dialect: .comma, order: .dayFirst
        )
        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertTrue(buffer.text.hasPrefix("ma,02/07/2026"), "tiêu đề còn nguyên")
    }

    /// Ô không phải ngày thì để nguyên và vào danh sách đánh dấu.
    func testNonDatesAreMarkedNotRewritten() throws {
        let buffer = document("ma,ngay\nA1,chưa rõ\nA2,31/12/2026\n")
        let plan = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(plan.report.unparsable.map(\.value), ["chưa rõ"])
        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertTrue(buffer.text.contains("A1,chưa rõ"))
    }

    /// Ô rỗng là THIẾU dữ liệu, không phải ô hỏng — nó thuộc về FR-CLN-002.
    func testEmptyCellsAreNotErrors() throws {
        let buffer = document("ma,ngay\nA1,\nA2,31/12/2026\n")
        let plan = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertTrue(plan.report.unparsable.isEmpty)
        XCTAssertEqual(plan.report.cellsChanged, 1)
    }

    /// Bản xem trước đi qua ĐÚNG hàm áp thật, chỉ khác `maxRows`.
    func testPreviewIsTheSameCodePath() throws {
        var text = "ma,ngay\n"
        for i in 1...50 { text += "A\(i),31/12/2026\n" }
        let buffer = document(text)

        let preview = try CSVClean.normalizeDates(
            column: 1, in: buffer, dialect: .comma, maxRows: CSVClean.sampleLimit
        )
        XCTAssertEqual(preview.samples.count, CSVClean.sampleLimit)
        XCTAssertTrue(preview.report.partial, "phải nói rõ là con số chỉ tính trên mẫu")
        XCTAssertEqual(preview.report.cellsChanged, 10)

        let full = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)
        XCTAssertFalse(full.report.partial)
        XCTAssertEqual(full.report.cellsChanged, 50)
        XCTAssertEqual(Array(full.samples.prefix(CSVClean.sampleLimit)), preview.samples,
                       "mẫu của bản xem trước phải trùng với bản thật")
    }

    /// Toàn bộ một lượt chuẩn hóa là MỘT bước undo (FR-CORE-004, NFR-CLN-02).
    func testWholeColumnIsOneUndoStep() throws {
        let source = "ma,ngay\nA1,31/12/2026\nA2,01/02/2026\nA3,5-Jul-26\n"
        let buffer = document(source)
        let depth = buffer.undoDepth

        let plan = try CSVClean.normalizeDates(
            column: 1, in: buffer, dialect: .comma, order: .dayFirst
        )
        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertEqual(buffer.undoDepth, depth + 1)

        _ = buffer.undo()
        XCTAssertEqual(buffer.text, source)
    }

    /// Ô bọc ngoặc kép vẫn đọc đúng, và giá trị mới không cần bọc thì bỏ bọc đi.
    func testQuotedCells() throws {
        let buffer = document("ma,ngay\nA1,\"31/12/2026\"\n")
        let plan = try CSVClean.normalizeDates(column: 1, in: buffer, dialect: .comma)
        buffer.applyEdits(plan.edits, label: "Chuẩn hóa ngày")
        XCTAssertEqual(buffer.text, "ma,ngay\nA1,2026-12-31\n")
    }
}
