import XCTest
@testable import GEditorCore

/// Giá trị thiếu và làm sạch chữ theo cột (FR-CLN-002, phần còn lại của FR-CLN-001).
final class CSVCleanNullTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    // MARK: - Nhận diện ô thiếu

    func testDefaultPlaceholders() {
        let spec = CSVNullSpec.default
        for value in ["", "  ", "N/A", "n/a", "NULL", "-", "?", "  none  "] {
            XCTAssertTrue(spec.isNull(value), "«\(value)» phải là ô thiếu")
        }
        for value in ["0", "không", "N/A rồi", "--x"] {
            XCTAssertFalse(spec.isNull(value), "«\(value)» KHÔNG phải ô thiếu")
        }
    }

    /// "-" là ô thiếu trong bảng kế toán nhưng là dấu trừ ở cột khác — danh sách phải sửa được.
    func testPlaceholderListIsEditable() {
        let spec = CSVNullSpec(placeholders: ["n/a"], treatEmptyAsNull: true)
        XCTAssertFalse(spec.isNull("-"))
        XCTAssertTrue(spec.isNull("N/A"))
    }

    /// Ô rỗng cũng có thể KHÔNG tính là thiếu, khi chuỗi rỗng là giá trị thật.
    func testEmptyCanBeMeaningful() {
        let spec = CSVNullSpec(placeholders: ["n/a"], treatEmptyAsNull: false)
        XCTAssertFalse(spec.isNull(""))
    }

    // MARK: - Đếm

    /// Người dùng phải thấy danh sách thật của FILE NÀY, không phải danh sách mặc định.
    func testScanCountsByPlaceholder() throws {
        let buffer = document("ma,tinh\nA1,N/A\nA2,\nA3,Huế\nA4,n/a\n")
        let scan = try CSVClean.scanNulls(column: 1, in: buffer, dialect: .comma)

        XCTAssertEqual(scan.nullCells, 3)
        XCTAssertEqual(scan.byPlaceholder["n/a"], 2, "hoa thường gộp về một mục")
        XCTAssertEqual(scan.byPlaceholder[""], 1)
        XCTAssertEqual(scan.firstCells.first?.rowIndex, 1)
    }

    // MARK: - Điền

    func testFillWithDefaultValue() throws {
        let buffer = document("ma,tinh\nA1,N/A\nA2,Huế\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, with: "Chưa rõ"
        )
        XCTAssertEqual(plan.report.cellsChanged, 1)
        buffer.applyEdits(plan.edits, label: "Điền ô thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Chưa rõ\nA2,Huế\n")
    }

    func testForwardFill() throws {
        let buffer = document("ma,tinh\nA1,Huế\nA2,\nA3,N/A\nA4,Đà Nẵng\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, direction: .forward
        )
        buffer.applyEdits(plan.edits, label: "Điền xuôi")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Huế\nA2,Huế\nA3,Huế\nA4,Đà Nẵng\n")
    }

    func testBackwardFill() throws {
        let buffer = document("ma,tinh\nA1,\nA2,N/A\nA3,Huế\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, direction: .backward
        )
        buffer.applyEdits(plan.edits, label: "Điền ngược")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Huế\nA2,Huế\nA3,Huế\n")
    }

    /// Ô thiếu ở đầu cột không có gì phía trên để lấy — điền bừa vào đó là BỊA dữ liệu.
    func testForwardFillLeavesTheHeadAlone() throws {
        let buffer = document("ma,tinh\nA1,\nA2,Huế\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, direction: .forward
        )
        XCTAssertEqual(plan.report.unparsable.count, 1)
        XCTAssertEqual(plan.report.unparsable.first?.rowIndex, 1)
        buffer.applyEdits(plan.edits, label: "Điền xuôi")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,\nA2,Huế\n")
    }

    /// Tương tự ở cuối cột khi điền ngược.
    func testBackwardFillLeavesTheTailAlone() throws {
        let buffer = document("ma,tinh\nA1,Huế\nA2,\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, direction: .backward
        )
        XCTAssertEqual(plan.report.unparsable.count, 1)
        XCTAssertTrue(plan.edits.isEmpty)
    }

    /// Giá trị điền vào có dấu phân tách thì phải được bọc, nếu không hàng bị tách thêm cột.
    func testFilledValueIsQuotedWhenNeeded() throws {
        let buffer = document("ma,tinh\nA1,\n")
        let plan = try CSVClean.fillNulls(
            column: 1, in: buffer, dialect: .comma, with: "Huế, Việt Nam"
        )
        buffer.applyEdits(plan.edits, label: "Điền ô thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,\"Huế, Việt Nam\"\n")
    }

    // MARK: - Xóa hàng

    func testDeleteRowsWithNull() throws {
        let buffer = document("ma,tinh\nA1,Huế\nA2,N/A\nA3,Đà Nẵng\n")
        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)

        XCTAssertEqual(plan.rowsAffected, 1)
        XCTAssertEqual(plan.sampleRows, [2])
        buffer.applyEdits(plan.edits, label: "Xóa hàng thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Huế\nA3,Đà Nẵng\n")
    }

    /// Xóa hàng CUỐI vẫn để file kết thúc bằng một dấu xuống dòng.
    func testDeletingLastRowKeepsTrailingNewline() throws {
        let buffer = document("ma,tinh\nA1,Huế\nA2,\n")
        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)
        buffer.applyEdits(plan.edits, label: "Xóa hàng thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Huế\n")
    }

    func testDeletingConsecutiveRows() throws {
        let buffer = document("ma,tinh\nA1,\nA2,\nA3,Huế\n")
        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(plan.rowsAffected, 2)
        buffer.applyEdits(plan.edits, label: "Xóa hàng thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA3,Huế\n")
    }

    /// Hàng ngắn hơn cột đang xét: ô ấy không tồn tại, mà không tồn tại cũng là không có dữ liệu.
    func testShortRowCountsAsMissing() throws {
        let buffer = document("ma,tinh\nA1,Huế\nA2\n")
        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(plan.rowsAffected, 1)
        buffer.applyEdits(plan.edits, label: "Xóa hàng thiếu")
        XCTAssertEqual(buffer.text, "ma,tinh\nA1,Huế\n")
    }

    /// Hàng tiêu đề không bao giờ bị xóa, kể cả khi ô tiêu đề của cột ấy trống.
    func testHeaderIsNeverDeleted() throws {
        let buffer = document("ma,\nA1,Huế\n")
        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)
        XCTAssertEqual(plan.rowsAffected, 0)
    }

    /// Cả lượt xóa là MỘT bước undo.
    func testDeleteIsOneUndoStep() throws {
        let source = "ma,tinh\nA1,\nA2,Huế\nA3,N/A\n"
        let buffer = document(source)
        let depth = buffer.undoDepth

        let plan = try CSVClean.deleteRowsWithNull(column: 1, in: buffer, dialect: .comma)
        buffer.applyEdits(plan.edits, label: "Xóa hàng thiếu")
        XCTAssertEqual(buffer.undoDepth, depth + 1)
        XCTAssertEqual(buffer.text, "ma,tinh\nA2,Huế\n")

        _ = buffer.undo()
        XCTAssertEqual(buffer.text, source)
    }

    // MARK: - Cắt khoảng trắng

    /// Khoảng trắng KHÔNG NGẮT và zero-width là lý do hai ô nhìn giống hệt nhau mà không khớp.
    func testTrimHandlesInvisibleSpaces() throws {
        let buffer = document("ma,ten\nA1,\" Hà Nội\u{00A0}\"\nA2,\"\u{200B}Huế \"\n")
        let plan = try CSVClean.trimCells(column: 1, in: buffer, dialect: .comma)
        buffer.applyEdits(plan.edits, label: "Cắt khoảng trắng")
        XCTAssertEqual(buffer.text, "ma,ten\nA1,Hà Nội\nA2,Huế\n")
    }

    /// Mặc định chỉ cắt hai đầu: nén khoảng trắng bên trong là SỬA dữ liệu, phải chủ động chọn.
    func testInnerSpacesAreKeptByDefault() throws {
        let buffer = document("ma,ten\nA1,\"Cty  TNHH \"\n")
        let plan = try CSVClean.trimCells(column: 1, in: buffer, dialect: .comma)
        buffer.applyEdits(plan.edits, label: "Cắt khoảng trắng")
        XCTAssertEqual(buffer.text, "ma,ten\nA1,Cty  TNHH\n")
    }

    func testCollapseInner() throws {
        let buffer = document("ma,ten\nA1,\"Mai Lan\u{00A0}Store\"\nA2,\"Cty  TNHH\"\n")
        let plan = try CSVClean.trimCells(
            column: 1, in: buffer, dialect: .comma, collapseInner: true
        )
        buffer.applyEdits(plan.edits, label: "Nén khoảng trắng")
        XCTAssertEqual(buffer.text, "ma,ten\nA1,Mai Lan Store\nA2,Cty TNHH\n")
    }

    // MARK: - Hoa thường

    /// Tiếng Việt có "Đ" và toàn bộ nguyên âm có dấu — một bảng ASCII sẽ để nguyên chúng.
    func testCaseHandlesVietnamese() throws {
        let buffer = document("ma,ten\nA1,nguyễn văn đông\n")
        let upper = try CSVClean.changeCase(column: 1, in: buffer, dialect: .comma, to: .upper)
        XCTAssertEqual(upper.samples.first?.after, "NGUYỄN VĂN ĐÔNG")

        let title = try CSVClean.changeCase(column: 1, in: buffer, dialect: .comma, to: .title)
        XCTAssertEqual(title.samples.first?.after, "Nguyễn Văn Đông")
    }

    /// Hoa đầu từ theo ranh giới đơn giản, KHÔNG theo `capitalized` của Foundation.
    func testTitleCaseKeepsAbbreviations() {
        XCTAssertEqual(CSVClean.titleCased("tp.hcm"), "Tp.Hcm")
        XCTAssertEqual(CSVClean.titleCased("CÔNG TY ANH ĐÀO"), "Công Ty Anh Đào")
        XCTAssertEqual(CSVClean.titleCased("o'brien"), "O'brien", "dấu nháy không mở từ mới")
    }

    /// Ô đã đúng dạng rồi thì không sinh sửa đổi nào.
    func testNoEditsWhenAlreadyClean() throws {
        let buffer = document("ma,ten\nA1,HUẾ\n")
        let plan = try CSVClean.changeCase(column: 1, in: buffer, dialect: .comma, to: .upper)
        XCTAssertTrue(plan.edits.isEmpty)
        XCTAssertEqual(plan.report.cellsAlreadyClean, 1)
    }
}
