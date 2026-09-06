import XCTest
@testable import GEditorCore

/// Số học cuộn dọc (nền của ADR-01 và FR-CORE-015).
///
/// Bài quan trọng nhất ở đây là VÒNG TRÒN `line → y → line`. Chính chỗ ấy đã hỏng một lần trên
/// file 500 MB và không bài kiểm nào bắt được, vì lúc đó nó nằm lẫn trong view.
final class VerticalGeometryTests: XCTestCase {

    // MARK: - Trường hợp thường

    func testHeightIsLinesTimesLineHeight() {
        let geometry = VerticalGeometry(lineCount: 100, lineHeight: 17, insetHeight: 12)
        XCTAssertEqual(geometry.contentHeight, 100 * 17 + 12)
        XCTAssertEqual(geometry.canvasHeight, 100 * 17 + 12)
        XCTAssertEqual(geometry.scale, 1)
    }

    func testLineToYIsUniform() {
        let geometry = VerticalGeometry(lineCount: 100, lineHeight: 17)
        XCTAssertEqual(geometry.y(ofLine: 0), 0)
        XCTAssertEqual(geometry.y(ofLine: 10), 170)
    }

    func testRoundTripAtEveryLine() {
        let geometry = VerticalGeometry(lineCount: 1_000, lineHeight: 17, insetHeight: 12)
        for line in 0 ..< 1_000 {
            XCTAssertEqual(geometry.line(atY: geometry.y(ofLine: line)), line, "dòng \(line)")
        }
    }

    /// Giữa hai dòng thì phải ra dòng TRÊN — cuộn tới lưng chừng dòng 5 vẫn đang ở dòng 5.
    func testMidLineBelongsToTheLineAbove() {
        let geometry = VerticalGeometry(lineCount: 100, lineHeight: 20)
        XCTAssertEqual(geometry.line(atY: 100), 5)
        XCTAssertEqual(geometry.line(atY: 119.9), 5)
        XCTAssertEqual(geometry.line(atY: 120), 6)
    }

    // MARK: - Kẹp biên

    func testClampsOutsideDocument() {
        let geometry = VerticalGeometry(lineCount: 10, lineHeight: 17)
        XCTAssertEqual(geometry.line(atY: -500), 0)
        XCTAssertEqual(geometry.line(atY: 10_000_000), 9)
        XCTAssertEqual(geometry.y(ofLine: -3), 0)
        XCTAssertEqual(geometry.y(ofLine: 999), geometry.y(ofLine: 9))
    }

    func testEmptyDocumentStillHasACanvas() {
        let geometry = VerticalGeometry(lineCount: 0, lineHeight: 17)
        XCTAssertGreaterThanOrEqual(geometry.canvasHeight, 1)
        XCTAssertEqual(geometry.line(atY: 0), 0)
        XCTAssertEqual(geometry.line(atY: 500), 0)
    }

    // MARK: - Nén khi tài liệu cao hơn trần

    func testHugeDocumentIsCompressedToTheCeiling() {
        // 7,3 triệu dòng × 17 pt = 124 triệu point, vượt xa trần 4 triệu.
        let geometry = VerticalGeometry(lineCount: 7_300_000, lineHeight: 17, maximumHeight: 4_000_000)
        XCTAssertEqual(geometry.canvasHeight, 4_000_000)
        XCTAssertLessThan(geometry.scale, 1)
        XCTAssertGreaterThan(geometry.scale, 0)
    }

    /// Nén rồi thì vòng tròn vẫn phải khép — đây đúng là chỗ lỗi 5.014.364 đã sinh ra.
    ///
    /// Quét DÀY chứ không lấy vài mẫu rải rác. Bản đầu của bài này chỉ thử 8 dòng chọn tay và
    /// nó XANH ngay cả khi bỏ epsilon đi — tức là bài kiểm vô dụng. Quét cạn bằng Python mới
    /// thấy dòng hỏng đầu tiên là 61, rồi 121, 122, 244…: sai số chia dấu phẩy động đẩy kết quả
    /// xuống dưới số nguyên, và phần nguyên rơi về dòng liền trước.
    func testRoundTripSurvivesCompression() {
        let geometry = VerticalGeometry(lineCount: 7_300_000, lineHeight: 17, maximumHeight: 4_000_000)
        XCTAssertLessThan(geometry.scale, 1, "bài này chỉ có nghĩa khi khung THẬT SỰ bị nén")
        for line in 0 ..< 5_000 {
            XCTAssertEqual(geometry.line(atY: geometry.y(ofLine: line)), line, "dòng \(line)")
        }
        for line in [1_000_000, 3_000_000, 5_000_000, 7_299_998, 7_299_999] {
            XCTAssertEqual(geometry.line(atY: geometry.y(ofLine: line)), line, "dòng \(line)")
        }
    }

    func testCompressedMappingStaysMonotonic() {
        let geometry = VerticalGeometry(lineCount: 7_300_000, lineHeight: 17, maximumHeight: 4_000_000)
        var previous = -1
        for step in 0 ... 2_000 {
            let line = geometry.line(atY: Double(step) * 2_000)
            XCTAssertGreaterThanOrEqual(line, previous)
            previous = line
        }
    }

    // MARK: - Ngắt dòng mềm (FR-CORE-015)

    func testWrappingMakesTheDocumentTaller() {
        let flat = VerticalGeometry(lineCount: 1_000, lineHeight: 17)
        let wrapped = VerticalGeometry(lineCount: 1_000, lineHeight: 17, rowsPerLine: 2.5)
        XCTAssertEqual(wrapped.contentHeight, flat.contentHeight * 2.5)
    }

    func testWrappedRoundTripHolds() {
        let geometry = VerticalGeometry(lineCount: 50_000, lineHeight: 17, rowsPerLine: 3.7)
        for line in [0, 1, 999, 25_000, 49_999] {
            XCTAssertEqual(geometry.line(atY: geometry.y(ofLine: line)), line, "dòng \(line)")
        }
    }

    /// Một dòng không bao giờ chiếm ÍT hơn một hàng, kể cả khi đo ra số vô lý.
    func testRowsPerLineNeverGoesBelowOne() {
        XCTAssertEqual(VerticalGeometry(lineCount: 10, lineHeight: 17, rowsPerLine: 0.4).rowsPerLine, 1)
        XCTAssertEqual(VerticalGeometry(lineCount: 10, lineHeight: 17, rowsPerLine: 0).rowsPerLine, 1)
    }

    // MARK: - Số vô nghĩa vào thì không được lan ra

    func testNaNAndZeroAreRejectedAtTheDoor() {
        // Cửa sổ rỗng đo ra 0 hàng / 0 dòng = NaN. Nếu lọt vào thì khung cuộn biến mất.
        let geometry = VerticalGeometry(
            lineCount: 100, lineHeight: .nan, rowsPerLine: .nan, insetHeight: .nan
        )
        XCTAssertEqual(geometry.lineHeight, 1)
        XCTAssertEqual(geometry.rowsPerLine, 1)
        XCTAssertEqual(geometry.insetHeight, 0)
        XCTAssertTrue(geometry.canvasHeight.isFinite)
        XCTAssertEqual(geometry.line(atY: .nan), 0)

        XCTAssertEqual(VerticalGeometry(lineCount: 10, lineHeight: 0).lineHeight, 1)
        XCTAssertEqual(VerticalGeometry(lineCount: 10, lineHeight: -17).lineHeight, 1)
    }

    func testNegativeLineCountBecomesEmpty() {
        XCTAssertEqual(VerticalGeometry(lineCount: -5, lineHeight: 17).lineCount, 0)
    }
}

/// Ba chế độ ngắt dòng mềm (FR-CORE-015).
final class WrapModeTests: XCTestCase {

    func testCyclesThroughAllThreeAndComesBack() {
        var mode = WrapMode.off
        mode = mode.next()
        XCTAssertEqual(mode, .window)
        mode = mode.next()
        XCTAssertEqual(mode, .column(80))
        mode = mode.next()
        XCTAssertEqual(mode, .off)
    }

    func testCycleFromAnyColumnReturnsToOff() {
        XCTAssertEqual(WrapMode.column(72).next(), .off)
    }

    func testOnlyOffIsOff() {
        XCTAssertFalse(WrapMode.off.isOn)
        XCTAssertTrue(WrapMode.window.isOn)
        XCTAssertTrue(WrapMode.column(80).isOn)
    }
}
