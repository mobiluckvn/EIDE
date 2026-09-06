import XCTest
@testable import GEditorCore

final class ReportDocumentTests: XCTestCase {

    // MARK: - Khối rào

    func testTACHKhoiQueryVaChartKhoiVanXuoi() throws {
        let document = try ReportDocument.parse("""
            # Báo cáo tháng 8

            Mở đầu.

            ```query
            SELECT * FROM t
            ```

            Giữa hai khối.

            ```chart
            kind: bar
            ```

            Kết.
            """)
        XCTAssertEqual(document.segments.count, 5)
        XCTAssertEqual(document.blocks.map(\.kind), [.query, .chart])
        XCTAssertEqual(document.blocks[0].content, "SELECT * FROM t")
        XCTAssertEqual(document.blocks[1].content, "kind: bar")
        // Thứ tự xen kẽ phải giữ nguyên — báo cáo là một văn bản có mạch.
        if case let .markdown(text) = document.segments[0] {
            XCTAssertTrue(text.hasPrefix("# Báo cáo tháng 8"), text)
        } else {
            XCTFail("đoạn đầu phải là văn xuôi")
        }
        if case let .markdown(text) = document.segments[4] {
            XCTAssertEqual(text.trimmingCharacters(in: .whitespacesAndNewlines), "Kết.")
        } else {
            XCTFail("đoạn cuối phải là văn xuôi")
        }
    }

    func testKHOIMAKHACDiThangSangMarkdown_NGUYENVEN() throws {
        // Đây là chỗ dễ sai nhất của cả trình phân tích: nếu chỉ chuyển DÒNG MỞ sang Markdown
        // rồi tiếp tục vòng lặp bình thường thì nội dung bên trong khối ví dụ bị đọc như tài
        // liệu thật — một dòng ```chart trong khối hướng dẫn sẽ được CHẠY.
        let document = try ReportDocument.parse("""
            Hướng dẫn: viết như sau.

            ```markdown
            ```chart
            kind: bar
            ```
            ```

            Hết.
            """)
        XCTAssertTrue(document.blocks.isEmpty, "\(document.blocks.map(\.kind))")
        let text = document.segments.compactMap {
            if case let .markdown(t) = $0 { return t } else { return nil }
        }.joined(separator: "\n")
        XCTAssertTrue(text.contains("kind: bar"), "nội dung khối ví dụ phải còn nguyên")
    }

    func testKHOISQLTranKhongPhaiKhoiBaoCao() throws {
        let document = try ReportDocument.parse("""
            ```sql
            SELECT 1
            ```
            """)
        XCTAssertTrue(document.blocks.isEmpty)
    }

    func testKHOIKhongDongThiBAOLOIKemSoDong() {
        XCTAssertThrowsError(try ReportDocument.parse("""
            Mở đầu.

            ```query
            SELECT 1
            """)) { error in
            guard let failure = error as? ReportDocument.Failure else {
                return XCTFail("sai kiểu lỗi")
            }
            XCTAssertEqual(failure.line, 2, "phải trỏ vào dòng MỞ khối")
            XCTAssertTrue(failure.message.contains("không có hàng rào"), failure.message)
        }
    }

    func testKHOIRONGThiBAOLOI() {
        // Một khối `query` rỗng chạy ra lỗi DuckDB khó hiểu ở tận trình kết xuất. Bắt ngay ở
        // đây thì thông báo nói được đúng dòng nào trong tệp cần sửa.
        XCTAssertThrowsError(try ReportDocument.parse("```chart\n\n```")) { error in
            XCTAssertTrue(
                (error as? ReportDocument.Failure)?.message.contains("rỗng") == true)
        }
    }

    func testCHISOKhoiVaSODONGDungDeNhayToiChoLoi() throws {
        let document = try ReportDocument.parse("""
            ---
            title: x
            ---
            văn xuôi

            ```query
            SELECT 1
            ```
            văn xuôi

            ```chart
            kind: line
            ```
            """)
        XCTAssertEqual(document.blocks.map(\.index), [0, 1])
        // Số dòng tính theo TỆP, kể cả phần frontmatter — nếu không thì bấm vào lỗi sẽ nhảy
        // lệch đúng bằng độ dài frontmatter.
        XCTAssertEqual(document.blocks[0].line, 5)
        XCTAssertEqual(document.blocks[1].line, 10)
    }

    func testDOANTRANGKhongTaoRaSegment() throws {
        // Nếu không lọc, mỗi khối bị kẹp giữa hai segment rỗng và trình kết xuất sinh ra những
        // thẻ `<p></p>` trống.
        let document = try ReportDocument.parse("""
            ```query
            SELECT 1
            ```

            ```query
            SELECT 2
            ```
            """)
        XCTAssertEqual(document.segments.count, 2)
    }

    // MARK: - Frontmatter

    func testDOCFrontmatter() throws {
        let document = try ReportDocument.parse("""
            ---
            title: Báo cáo tháng 8
            source: ban-hang.csv
            ---
            Nội dung.
            """)
        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertEqual(frontmatter["title"]?.stringValue, "Báo cáo tháng 8")
        XCTAssertEqual(frontmatter["source"]?.stringValue, "ban-hang.csv")
    }

    func testDONGKeNgangKHONGPhaiFrontmatter() throws {
        // `---` phải ở ĐÚNG dòng đầu. Một tài liệu mở bằng dòng trống rồi `---` thì `---` ấy là
        // đường kẻ ngang của Markdown; nuốt nó thành frontmatter sẽ làm mất nội dung mà người
        // dùng đang nhìn thấy trong trình soạn.
        let document = try ReportDocument.parse("""

            ---
            Nội dung.
            """)
        XCTAssertNil(document.frontmatter)
        XCTAssertEqual(document.segments.count, 1)
    }

    func testFrontmatterKhongDongThiBAOLOI() {
        XCTAssertThrowsError(try ReportDocument.parse("---\ntitle: x\nNội dung.")) { error in
            XCTAssertEqual((error as? ReportDocument.Failure)?.line, 0)
        }
    }

    func testLOIYAMLTrongFrontmatterQuyVeSoDongCuaTEP() {
        // YAMLReader đếm dòng trong ĐOẠN frontmatter; người dùng cần số dòng trong TỆP.
        XCTAssertThrowsError(try ReportDocument.parse("""
            ---
            title: x
            \ttab: sai
            ---
            """)) { error in
            guard let failure = error as? ReportDocument.Failure else {
                return XCTFail("sai kiểu lỗi")
            }
            XCTAssertTrue(failure.message.hasPrefix("frontmatter:"), failure.message)
            XCTAssertGreaterThan(failure.line, 0, "phải cộng bù phần frontmatter")
        }
    }

    func testKhongCoFrontmatterVanChayDuoc() throws {
        let document = try ReportDocument.parse("Chỉ có văn xuôi.")
        XCTAssertNil(document.frontmatter)
        XCTAssertEqual(document.segments.count, 1)
    }

    func testTAILIEURONG() throws {
        let document = try ReportDocument.parse("")
        XCTAssertTrue(document.segments.isEmpty)
        XCTAssertTrue(document.blocks.isEmpty)
    }

    func testNHANBIETKhoiQualityVaMining() throws {
        // Hai loại khối này thuộc FR-DQR-003 và FR-MIN-007; trình phân tích nhận ra chúng ngay
        // từ bây giờ để tài liệu có chúng không bị báo là hỏng cú pháp.
        let document = try ReportDocument.parse("""
            ```quality
            rules: x
            ```
            ```mining
            group_by: tinh
            ```
            """)
        XCTAssertEqual(document.blocks.map(\.kind), [.quality, .mining])
    }

    func testTENLoaiKhoiKhongPhanBietHOATHUONG() throws {
        let document = try ReportDocument.parse("```QUERY\nSELECT 1\n```")
        XCTAssertEqual(document.blocks.first?.kind, .query)
    }
}
