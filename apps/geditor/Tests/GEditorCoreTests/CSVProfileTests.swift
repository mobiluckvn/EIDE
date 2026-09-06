import XCTest
@testable import GEditorCore

/// Hồ sơ dữ liệu (FR-CLN-003).
final class CSVProfileTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    private func profile(_ text: String) throws -> CSVProfileReport {
        try CSVProfiler.profile(in: document(text), dialect: .comma)
    }

    // MARK: - Kiểu và tỉ lệ null

    func testInfersTypeAndCountsNulls() throws {
        var text = "ma,doanh_so,ngay\n"
        for index in 1...20 {
            let so = index % 5 == 0 ? "N/A" : "\(index * 100)"
            text += "A\(index),\(so),2026-07-\(String(format: "%02d", index % 28 + 1))\n"
        }
        let report = try profile(text)

        XCTAssertEqual(report.rowsScanned, 20)
        XCTAssertEqual(report.columns.count, 3)

        let doanhSo = report.columns[1]
        XCTAssertEqual(doanhSo.name, "doanh_so")
        XCTAssertEqual(doanhSo.type, .number)
        XCTAssertEqual(doanhSo.nullCells, 4)
        XCTAssertEqual(doanhSo.nullPercent, 20, accuracy: 0.001)

        XCTAssertEqual(report.columns[2].type, .date(.iso))
    }

    /// Cột lẫn lộn không thuộc kiểu nào — và hồ sơ nói thẳng là chuỗi, không đoán bừa.
    func testMixedColumnIsText() throws {
        var text = "ma,gia_tri\n"
        for index in 1...20 { text += "A\(index),\(index % 2 == 0 ? "\(index)" : "chữ")\n" }
        XCTAssertEqual(try profile(text).columns[1].type, .text)
    }

    // MARK: - Thống kê số

    /// Trung bình và độ lệch chuẩn tính bằng Welford, đối chiếu công thức tay.
    func testMeanAndDeviation() throws {
        var text = "ma,x\n"
        let values = [2.0, 4, 4, 4, 5, 5, 7, 9, 3, 6, 8, 1]
        for (index, value) in values.enumerated() { text += "A\(index),\(value)\n" }

        let column = try profile(text).columns[1]
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)

        XCTAssertEqual(column.mean ?? 0, mean, accuracy: 1e-9)
        XCTAssertEqual(column.standardDeviation ?? 0, variance.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(column.minimum, "1")
        XCTAssertEqual(column.maximum, "9")
    }

    /// Số kiểu Việt/Âu vẫn vào đúng thống kê — hồ sơ và nút chuẩn hóa phải đọc số như nhau.
    func testVietnameseNumbersAreUnderstood() throws {
        var text = "ma,tien\n"
        for index in 1...12 { text += "A\(index),\"1.234,\(String(format: "%02d", index))\"\n" }

        let column = try profile(text).columns[1]
        XCTAssertEqual(column.type, .number)
        XCTAssertEqual(column.mean ?? 0, 1234.065, accuracy: 0.001)
    }

    /// Min/max của cột NGÀY so trên dạng ISO, không so chuỗi thô.
    func testDateRangeUsesISOOrder() throws {
        var text = "ma,ngay\n"
        // Trộn dạng: so chuỗi thô sẽ xếp "25/07/2026" trước "2026-01-01" và bịa ra một khoảng
        // thời gian không tồn tại.
        for index in 1...10 { text += "A\(index),25/07/2026\n" }
        text += "A11,2026-01-01\nA12,2026-12-31\n"

        let column = try profile(text).columns[1]
        XCTAssertEqual(column.minimum, "2026-01-01")
        XCTAssertEqual(column.maximum, "2026-12-31")
    }

    // MARK: - Distinct và giá trị hay gặp

    func testDistinctAndTopValues() throws {
        var text = "ma,tinh\n"
        for index in 1...100 {
            text += "A\(index),\(index <= 60 ? "Hà Nội" : (index <= 90 ? "Huế" : "Cần Thơ"))\n"
        }
        let column = try profile(text).columns[1]

        XCTAssertEqual(column.distinct, 3)
        XCTAssertTrue(column.distinctExact)
        XCTAssertEqual(column.topValues.first?.value, "Hà Nội")
        XCTAssertEqual(column.topValues.first?.count, 60)
        XCTAssertEqual(column.topValues.map(\.value), ["Hà Nội", "Huế", "Cần Thơ"])
    }

    /// Vượt ngưỡng đếm thì con số thành CẬN DƯỚI và hồ sơ phải nói ra.
    func testDistinctOverflowIsHonest() throws {
        var text = "ma,gia_tri\n"
        for index in 0..<(CSVProfiler.distinctLimit + 500) { text += "A\(index),giá trị \(index)\n" }

        let column = try profile(text).columns[1]
        XCTAssertFalse(column.distinctExact, "phải nói rõ đây không phải con số đếm thật")
        XCTAssertTrue(column.topValues.isEmpty,
                      "danh sách hay gặp dở dang còn tệ hơn không có: nó thiên vị giá trị đến sớm")
        XCTAssertTrue(column.summary.contains("hơn"), "«\(column.summary)»")
    }

    /// Cùng dữ liệu, chạy lại phải ra cùng con số — băm không được gieo hạt ngẫu nhiên.
    func testDeterministic() throws {
        var text = "ma,gia_tri\n"
        for index in 1...500 { text += "A\(index),nhóm \(index % 37)\n" }

        let first = try profile(text).columns[1]
        let second = try profile(text).columns[1]
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.distinct, 37)
    }

    // MARK: - Giá trị bất thường

    func testFindsOutliersWithExplanation() throws {
        var text = "ma,x\n"
        for index in 1...200 { text += "A\(index),\(100 + index % 5)\n" }
        text += "A201,99999\n"

        let column = try profile(text).columns[1]
        XCTAssertEqual(column.outliers.count, 1)
        XCTAssertEqual(column.outliers.first?.value, "99999")
        XCTAssertEqual(column.outliers.first?.rowIndex, 201)
    }

    /// Cột đều đặn thì KHÔNG bịa ra giá trị bất thường.
    func testNoOutliersInUniformColumn() throws {
        var text = "ma,x\n"
        for index in 1...200 { text += "A\(index),\(100 + index % 5)\n" }
        XCTAssertTrue(try profile(text).columns[1].outliers.isEmpty)
    }

    // MARK: - Đọc tài liệu

    func testHeaderNamesTheColumns() throws {
        let report = try profile("ma_kh,ho_ten,doanh_thu\nA1,Nguyễn Văn An,100\n")
        XCTAssertEqual(report.columns.map(\.name), ["ma_kh", "ho_ten", "doanh_thu"])
    }

    /// Ô bọc ngoặc chứa dấu phân tách không được làm lệch cột.
    func testQuotedFields() throws {
        var text = "ma,ten,x\n"
        for index in 1...12 { text += "A\(index),\"Huế, Việt Nam\",\(index)\n" }

        let report = try profile(text)
        XCTAssertEqual(report.columns.count, 3)
        XCTAssertEqual(report.columns[1].topValues.first?.value, "Huế, Việt Nam")
        XCTAssertEqual(report.columns[2].type, .number)
    }

    /// Quét mẫu thì phải nói rõ là mẫu.
    func testPartialScanSaysSo() throws {
        var text = "ma,x\n"
        for index in 1...100 { text += "A\(index),\(index)\n" }

        let report = try CSVProfiler.profile(
            in: document(text), dialect: .comma, maxRows: 10
        )
        XCTAssertTrue(report.partial)
        XCTAssertEqual(report.rowsScanned, 10)
    }

    /// Hồ sơ CHỈ ĐỌC — nguyên tắc đầu tiên của cả cụm phân tích.
    func testProfileNeverTouchesTheDocument() throws {
        let source = "ma,x\nA1,1\nA2,2\n"
        let buffer = document(source)
        let depth = buffer.undoDepth
        _ = try CSVProfiler.profile(in: buffer, dialect: .comma)
        XCTAssertEqual(buffer.text, source)
        XCTAssertEqual(buffer.undoDepth, depth)
    }
}
