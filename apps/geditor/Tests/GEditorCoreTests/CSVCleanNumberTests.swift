import XCTest
@testable import GEditorCore

/// Đổi quy ước số Việt/Âu ↔ Anh-Mỹ (FR-CLN-001).
final class CSVCleanNumberTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func certain(_ value: String) -> CSVParsedNumber? {
        guard case let .certain(number, _) = CSVClean.readNumber(value) else { return nil }
        return number
    }

    // MARK: - Đọc một ô

    /// Ô có CẢ HAI dấu thì không còn gì nhập nhằng: dấu đứng sau là dấu thập phân.
    func testBothMarksResolveEachOther() {
        XCTAssertEqual(certain("1.234,56")?.formatted(.anglo, grouped: true), "1,234.56")
        XCTAssertEqual(certain("1,234.56")?.formatted(.vietnamese, grouped: true), "1.234,56")
        XCTAssertEqual(certain("-1.234.567,89")?.formatted(.anglo, grouped: true), "-1,234,567.89")
    }

    /// Một dấu, phần sau KHÔNG phải ba chữ số → chắc chắn là dấu thập phân.
    func testSingleMarkWithShortTailIsDecimal() {
        XCTAssertEqual(certain("1234,5")?.formatted(.anglo, grouped: false), "1234.5")
        XCTAssertEqual(certain("0.75")?.formatted(.vietnamese, grouped: false), "0,75")
        XCTAssertEqual(certain("12,3456")?.formatted(.anglo, grouped: false), "12.3456")
    }

    /// Dấu lặp lại nhiều lần thì nó là dấu NHÓM, không thể là dấu thập phân.
    func testRepeatedMarkIsAGroupMark() {
        guard case let .certain(number, implies) = CSVClean.readNumber("1.234.567") else {
            return XCTFail("phải đọc được")
        }
        XCTAssertEqual(number.formatted(.anglo, grouped: true), "1,234,567")
        XCTAssertEqual(implies, .vietnamese, "chấm nhóm nghìn là quy ước Việt/Âu")
    }

    /// `1.234` đọc được hai cách, lệch nhau một NGHÌN LẦN — và cả hai đều trông bình thường.
    func testThousandTailIsGenuinelyAmbiguous() {
        guard case let .needsStyle(vietnamese, anglo) = CSVClean.readNumber("1.234") else {
            return XCTFail("1.234 phải là mơ hồ")
        }
        XCTAssertEqual(vietnamese.formatted(.anglo, grouped: false), "1234")
        XCTAssertEqual(anglo.formatted(.anglo, grouped: false), "1.234")
    }

    /// Số nguyên trần đọc được nhưng KHÔNG chứng minh gì về quy ước của cột.
    func testPlainIntegerCarriesNoEvidence() {
        guard case let .certain(_, implies) = CSVClean.readNumber("1234567") else {
            return XCTFail("phải đọc được")
        }
        XCTAssertNil(implies)
    }

    /// Những thứ KHÔNG được nhận là số. Mỗi mục là một cách làm hỏng dữ liệu.
    func testRefusesToGuess() {
        let notNumbers = [
            "12.34.567",   // nhóm nghìn sai cỡ — nhận là mở cửa cho mọi chuỗi có dấu chấm
            "1.234 đ",     // bỏ đơn vị đi là đổi ý nghĩa của ô
            "$5",
            "1.2e5",       // ký pháp mũ
            "1..2",
            "1.",
            "abc",
            "",
            "-",
            "2026-07-02",  // ngày không phải số
        ]
        for value in notNumbers {
            XCTAssertEqual(CSVClean.readNumber(value), .notANumber, "«\(value)» không phải số")
        }
    }

    /// Khoảng trắng (kể cả NBSP) chỉ có thể là dấu nhóm, ở cả hai quy ước.
    func testSpaceGrouping() {
        XCTAssertEqual(certain("1 234 567")?.formatted(.vietnamese, grouped: true), "1.234.567")
        XCTAssertEqual(certain("1\u{00A0}234,56")?.formatted(.anglo, grouped: true), "1,234.56")
    }

    /// Không đi qua `Double`: số dài hơn 17 chữ số vẫn giữ NGUYÊN từng chữ số.
    func testLongNumbersKeepEveryDigit() {
        let value = "1.234.567.890.123.456.789,05"
        XCTAssertEqual(
            certain(value)?.formatted(.anglo, grouped: true),
            "1,234,567,890,123,456,789.05"
        )
    }

    // MARK: - Khảo sát cột

    /// Một ô có cả hai dấu là đủ để biết quy ước của cả cột — không cần hỏi.
    func testColumnEvidenceRemovesTheQuestion() throws {
        let buffer = document("ma,tien\nA1,1.234\nA2,\"9.876,54\"\n")
        let scan = try CSVClean.scanNumbers(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .certain(.vietnamese))
        XCTAssertEqual(scan.ambiguousCells, 1)
        XCTAssertFalse(scan.needsQuestion)
    }

    func testAllAmbiguousMeansAsk() throws {
        let buffer = document("ma,tien\nA1,1.234\nA2,9.876\n")
        let scan = try CSVClean.scanNumbers(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .ambiguous)
        XCTAssertTrue(scan.needsQuestion)
    }

    func testConflictingColumnIsReportedAsSuch() throws {
        let buffer = document("ma,tien\nA1,\"1.234,56\"\nA2,\"9,876.54\"\n")
        let scan = try CSVClean.scanNumbers(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(scan.evidence, .conflicting)
    }

    // MARK: - Kế hoạch chuẩn hóa

    func testConvertsColumnToAnglo() throws {
        let buffer = document("ma,tien\nA1,\"1.234,56\"\nA2,\"9.876.543,00\"\n")
        let plan = try CSVClean.normalizeNumbers(column: 1, in: buffer, dialect: .comma, to: .anglo)
        XCTAssertEqual(plan.report.cellsChanged, 2)

        buffer.applyEdits(plan.edits, label: "Đổi quy ước số")
        // Giá trị mới chứa dấu phẩy nên PHẢI còn bọc, nếu không hàng bị tách thành ba cột.
        XCTAssertEqual(buffer.text, "ma,tien\nA1,\"1,234.56\"\nA2,\"9,876,543.00\"\n")
    }

    /// Đổi đi rồi đổi lại phải ra đúng giá trị ban đầu — "hai chiều không mất giá trị".
    func testRoundTrip() throws {
        let source = "ma,tien\nA1,\"1.234,56\"\nA2,\"9.876.543,00\"\n"
        let buffer = document(source)

        let toAnglo = try CSVClean.normalizeNumbers(
            column: 1, in: buffer, dialect: .comma, to: .anglo
        )
        buffer.applyEdits(toAnglo.edits, label: "→ Anh-Mỹ")
        let back = try CSVClean.normalizeNumbers(
            column: 1, in: buffer, dialect: .comma, to: .vietnamese
        )
        buffer.applyEdits(back.edits, label: "→ Việt/Âu")

        XCTAssertEqual(buffer.text, source)
    }

    /// Ô chưa từng có dấu thì KHÔNG được thêm dấu nhóm vào: cột mã số, số điện thoại nằm ở đó.
    func testPlainDigitsAreLeftAlone() throws {
        let buffer = document("ma,so_dt\nA1,0912345678\nA2,1234567\n")
        let plan = try CSVClean.normalizeNumbers(column: 1, in: buffer, dialect: .comma, to: .vietnamese)
        XCTAssertEqual(plan.report.cellsChanged, 0)
        XCTAssertEqual(plan.report.cellsAlreadyClean, 2)
        XCTAssertTrue(plan.edits.isEmpty)
    }

    /// Chưa hỏi quy ước nguồn thì ô mơ hồ để NGUYÊN và bị đánh dấu.
    func testWithoutSourceStyleAmbiguousCellsAreLeftAlone() throws {
        let buffer = document("ma,tien\nA1,1.234\nA2,\"5.678,90\"\n")
        let plan = try CSVClean.normalizeNumbers(column: 1, in: buffer, dialect: .comma, to: .anglo)

        XCTAssertEqual(plan.report.unparsable.map(\.value), ["1.234"])
        buffer.applyEdits(plan.edits, label: "Đổi quy ước số")
        XCTAssertTrue(buffer.text.contains("A1,1.234"), "ô mơ hồ còn nguyên")
    }

    func testSourceStyleAnswersTheAmbiguity() throws {
        let buffer = document("ma,tien\nA1,1.234\n")

        // Đọc "1.234" theo quy ước Việt/Âu: chấm là dấu nhóm → một nghìn hai trăm ba tư.
        let asGroup = try CSVClean.normalizeNumbers(
            column: 1, in: buffer, dialect: .comma, to: .anglo, sourceStyle: .vietnamese
        )
        XCTAssertEqual(asGroup.samples.first?.after, "1,234")

        // Đọc theo Anh-Mỹ: chấm là dấu thập phân → một phẩy hai ba tư, vốn đã đúng dạng đích
        // nên không có gì để sửa. Cùng một ô, hai câu trả lời lệch nhau một nghìn lần.
        let asDecimal = try CSVClean.normalizeNumbers(
            column: 1, in: buffer, dialect: .comma, to: .anglo, sourceStyle: .anglo
        )
        XCTAssertEqual(asDecimal.report.cellsAlreadyClean, 1)
        XCTAssertTrue(asDecimal.edits.isEmpty)
    }

    /// Bỏ dấu nhóm cho ra thứ mọi công cụ khác đọc được.
    func testUngrouped() throws {
        let buffer = document("ma,tien\nA1,\"1.234,56\"\n")
        let plan = try CSVClean.normalizeNumbers(
            column: 1, in: buffer, dialect: .comma, to: .anglo, grouped: false
        )
        buffer.applyEdits(plan.edits, label: "Đổi quy ước số")
        XCTAssertEqual(buffer.text, "ma,tien\nA1,1234.56\n")
    }

    /// Cả cột là MỘT bước undo (FR-CORE-004, NFR-CLN-02).
    func testWholeColumnIsOneUndoStep() throws {
        let source = "ma,tien\nA1,\"1.234,56\"\nA2,\"7.890,12\"\n"
        let buffer = document(source)
        let depth = buffer.undoDepth

        let plan = try CSVClean.normalizeNumbers(column: 1, in: buffer, dialect: .comma, to: .anglo)
        buffer.applyEdits(plan.edits, label: "Đổi quy ước số")
        XCTAssertEqual(buffer.undoDepth, depth + 1)

        _ = buffer.undo()
        XCTAssertEqual(buffer.text, source)
    }
}
