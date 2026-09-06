import XCTest
@testable import GEditorCore

/// Bộ phát hiện của Bàn làm sạch (FR-CLN-006).
final class CSVCleanScannerTests: XCTestCase {

    private func document(_ text: String) -> TextBuffer { TextBuffer(text: text) }

    /// Dựng cột đủ dài để vượt ngưỡng mẫu tối thiểu.
    private func column(_ values: [String], header: String = "ma,gia_tri") -> TextBuffer {
        var text = header + "\n"
        for (index, value) in values.enumerated() { text += "A\(index),\(value)\n" }
        return document(text)
    }

    func testFindsMixedDateShapes() throws {
        var values = Array(repeating: "2026-07-02", count: 8)
        values.append(contentsOf: ["25/07/2026", "5-Jul-26"])
        let findings = try CSVCleanScanner.scan(in: column(values), dialect: .comma)

        guard let dates = findings.first(where: {
            if case .mixedDates = $0.kind { return true } else { return false }
        }) else { return XCTFail("phải thấy cột ngày hỗn tạp: \(findings.map(\.title))") }

        XCTAssertEqual(dates.cells, 10)
        XCTAssertEqual(dates.columnName, "gia_tri", "phát hiện phải gọi đúng TÊN cột")
        if case let .mixedDates(shapes) = dates.kind {
            XCTAssertEqual(shapes, 3, "ISO, gạch chéo, tên tháng")
        }
    }

    /// Cột ngày MỘT dạng duy nhất thì không có gì để nói.
    func testUniformDateColumnIsSilent() throws {
        let findings = try CSVCleanScanner.scan(
            in: column(Array(repeating: "2026-07-02", count: 12)), dialect: .comma
        )
        XCTAssertTrue(findings.isEmpty, "\(findings.map(\.title))")
    }

    func testFindsMixedNumberConventions() throws {
        var values = Array(repeating: "\"1.234,56\"", count: 6)
        values.append(contentsOf: Array(repeating: "\"9,876.54\"", count: 6))
        let findings = try CSVCleanScanner.scan(in: column(values), dialect: .comma)

        XCTAssertTrue(
            findings.contains { $0.kind == .mixedNumbers },
            "phải thấy cột số lẫn quy ước: \(findings.map(\.title))"
        )
    }

    /// Cột chỉ dùng MỘT quy ước thì im lặng, dù đó là quy ước nào.
    func testConsistentNumbersAreSilent() throws {
        let findings = try CSVCleanScanner.scan(
            in: column(Array(repeating: "\"1.234,56\"", count: 12)), dialect: .comma
        )
        XCTAssertTrue(findings.isEmpty, "\(findings.map(\.title))")
    }

    func testFindsNullsWithTheirRealPlaceholders() throws {
        let findings = try CSVCleanScanner.scan(
            in: column(["Huế", "N/A", "", "Đà Nẵng", "n/a"]), dialect: .comma
        )
        guard let nulls = findings.first(where: {
            if case .nulls = $0.kind { return true } else { return false }
        }) else { return XCTFail("phải thấy ô thiếu") }

        XCTAssertEqual(nulls.cells, 3)
        XCTAssertTrue(nulls.title.contains("«n/a»"), "«\(nulls.title)»")
        XCTAssertTrue(nulls.title.contains("ô rỗng"), "«\(nulls.title)»")
    }

    func testFindsInvisibleWhitespace() throws {
        let findings = try CSVCleanScanner.scan(
            in: column(["\" Huế\"", "\"Đà Nẵng\u{00A0}\"", "Cần Thơ"]), dialect: .comma
        )
        guard let trim = findings.first(where: {
            if case .untrimmed = $0.kind { return true } else { return false }
        }) else { return XCTFail("phải thấy khoảng trắng thừa") }

        XCTAssertEqual(trim.cells, 2)
        if case let .untrimmed(invisible) = trim.kind {
            XCTAssertEqual(invisible, 1, "chỉ một ô có ký tự trắng VÔ HÌNH")
        }
        XCTAssertTrue(trim.title.contains("vô hình"), "«\(trim.title)»")
    }

    /// Cột dưới ngưỡng mẫu không bị kết luận về KIỂU — ba ô số chưa nói lên điều gì.
    func testSmallColumnsAreNotJudgedOnType() throws {
        let findings = try CSVCleanScanner.scan(
            in: column(["2026-07-02", "25/07/2026"]), dialect: .comma
        )
        XCTAssertFalse(findings.contains { if case .mixedDates = $0.kind { true } else { false } })
    }

    /// Mục ảnh hưởng rộng nhất lên đầu — danh mục dài mà xếp theo cột thì mục quan trọng nhất
    /// có thể nằm tận cuối.
    func testFindingsAreSortedByReach() throws {
        var text = "ma,it,nhieu\n"
        for index in 0..<20 {
            text += "A\(index),\(index == 0 ? "N/A" : "x"),\(index < 15 ? "N/A" : "y")\n"
        }
        let findings = try CSVCleanScanner.scan(in: document(text), dialect: .comma)
        XCTAssertEqual(findings.first?.columnName, "nhieu")
        XCTAssertEqual(findings.first?.cells, 15)
    }

    /// Con số của phát hiện phải KHỚP với số ô mà nút hành động thực sự đổi — nếu không, con
    /// số kia chỉ là lời hứa suông.
    func testFindingCountMatchesWhatTheActionChanges() throws {
        var values = Array(repeating: "2026-07-02", count: 8)
        values.append(contentsOf: ["25/07/2026", "5-Jul-26"])
        let buffer = column(values)

        let findings = try CSVCleanScanner.scan(in: buffer, dialect: .comma)
        guard let dates = findings.first(where: {
            if case .mixedDates = $0.kind { return true } else { return false }
        }) else { return XCTFail("phải thấy cột ngày") }

        let plan = try CSVClean.normalizeDates(column: dates.column, in: buffer, dialect: .comma)
        XCTAssertEqual(
            plan.report.cellsChanged + plan.report.cellsAlreadyClean, dates.cells,
            "phát hiện nói \(dates.cells) ô, nút chỉ chạm \(plan.report.cellsChanged) ô"
        )
    }

    /// Một lượt quét cho MỌI cột và mọi phép kiểm (NFR-CLN-01).
    ///
    /// Bài này chạy ở bản DEBUG nên con số nó in ra (~3,5s) không phải con số của sản phẩm:
    /// cùng phép quét ấy ở bản release mất 0,85s. Ngưỡng để rộng vì đây không phải bài đo hiệu
    /// năng — nó đứng canh để một thay đổi biến lượt quét thành nhiều lượt không lọt qua im
    /// lặng. Số đo thật và phần còn nợ ghi ở đầu `CSVCleanScanner`.
    func testScansAWideTableInOnePass() throws {
        var text = "c0,c1,c2,c3,c4,c5,c6,c7,c8,c9\n"
        for row in 0..<100_000 {
            text += "A\(row),2026-07-02,\"1.234,56\",Huế,N/A,x,y,z,1,2\n"
        }
        let buffer = document(text)

        let started = DispatchTime.now().uptimeNanoseconds
        let findings = try CSVCleanScanner.scan(in: buffer, dialect: .comma)
        let seconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9

        XCTAssertTrue(findings.contains { if case .nulls = $0.kind { true } else { false } })
        // Trần 10 s cho một phép quét thường mất ~3 s. Khoảng dư ba lần ấy KHÔNG phải hào phóng
        // — nó là thứ duy nhất giữ cho bài kiểm này không chập chờn, và ngày 28/08/2026 nó vẫn
        // chưa đủ: dưới load average 545 (do nhiều lượt `swift test` chồng nhau trên cùng máy)
        // phép quét mất **66,8 s** và bài kiểm đỏ. Chạy lại trên máy rảnh: 3,17 s.
        //
        // Nên đọc một lần đỏ ở đây là "MÁY ĐANG BẬN", đừng đọc thành "mã chậm đi" — và đừng nới
        // trần để cho nó xanh. Nới trần là bỏ luôn khả năng bắt hồi quy thật, đổi lấy sự yên
        // tĩnh; chỗ sửa đúng là đừng chạy hai lượt kiểm chồng nhau. Nếu CI đỏ ở đây, kiểm tải
        // của runner trước khi kiểm mã.
        XCTAssertLessThan(seconds, 10, "quét 100k × 10 mất \(String(format: "%.1f", seconds))s")
        print("[FR-CLN-006] quét 100k hàng × 10 cột: \(String(format: "%.2f", seconds))s")
    }
}
