import XCTest
@testable import GEditorCore

/// Lint YAML cơ bản (FR-FMT-507).
final class YAMLLintTests: XCTestCase {

    // MARK: - Khóa trùng

    /// YAML không báo lỗi khi khóa trùng; nó lặng lẽ lấy bản CUỐI.
    ///
    /// Người sửa file nhìn khóa ở trên, đổi giá trị, rồi không hiểu vì sao chẳng có tác dụng gì.
    func testFindsDuplicateKeys() {
        let source = """
        may_chu: alpha
        cong: 8080
        may_chu: beta
        """
        let issues = YAMLLint.check(source)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.line, 3)
        XCTAssertEqual(issues.first?.kind, .duplicateKey("may_chu", firstLine: 1))
        XCTAssertTrue(issues.first!.message.contains("ĐÈ"), issues.first!.message)
    }

    /// Cùng tên khóa ở HAI KHỐI khác nhau là hợp lệ — đó là chuyện thường trong YAML.
    func testSameKeyInDifferentBlocksIsFine() {
        let source = """
        phat_trien:
          cong: 8080
        san_xuat:
          cong: 80
        """
        XCTAssertTrue(YAMLLint.check(source).isEmpty)
    }

    /// Hai mục danh sách có cùng cấu trúc là hợp lệ, không phải khóa trùng.
    func testListItemsWithTheSameShapeAreFine() {
        let source = """
        may_chu:
          - ten: alpha
            cong: 8080
          - ten: beta
            cong: 8081
        """
        XCTAssertTrue(YAMLLint.check(source).map(\.description).isEmpty,
                      "\(YAMLLint.check(source).map(\.description))")
    }

    func testDuplicateInsideNestedBlock() {
        let source = """
        goc:
          a: 1
          b: 2
          a: 3
        """
        let issues = YAMLLint.check(source)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.line, 4)
    }

    // MARK: - Thụt lề

    /// Tab trong phần thụt lề: YAML cấm hẳn, và trình phân tích thường báo lỗi ở một dòng KHÁC
    /// hẳn chỗ có Tab — nên đọc thông điệp gốc hay dẫn đi sai đường.
    func testFindsTabIndent() {
        let source = "goc:\n\tcon: 1\n"
        let issues = YAMLLint.check(source)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.kind, .tabIndent)
        XCTAssertEqual(issues.first?.line, 2)
    }

    func testFindsMisalignedIndent() {
        let source = """
        goc:
          a: 1
           b: 2
        """
        let issues = YAMLLint.check(source)
        XCTAssertEqual(issues.map(\.line), [3])
        if case let .badIndent(found) = issues.first?.kind { XCTAssertEqual(found, 3) }
    }

    // MARK: - Không báo nhầm

    /// Báo nhầm một lỗi không có thật còn tệ hơn không báo: nó dạy người dùng bỏ qua cảnh báo.
    func testStaysQuietOnValidFiles() {
        let source = """
        # Cấu hình GEditor
        ten: GEditor
        phien_ban: "2.0"

        thu_muc:
          goc: /tmp
          tam: /var/tmp

        may_chu:
          - ten: alpha
            cong: 8080
          - ten: beta
            cong: 8081

        ghi_chu: |
          Dòng này là dữ liệu.
            Kể cả khi thụt lề lung tung.
          ten: không phải khóa
        """
        XCTAssertTrue(YAMLLint.check(source).map(\.description).isEmpty,
                      "\(YAMLLint.check(source).map(\.description))")
    }

    /// Dấu hai chấm trong dấu nháy không mở ra một khóa mới.
    func testColonInsideQuotesIsNotAKey() {
        XCTAssertEqual(YAMLLint.mappingKey(of: #"gio: "12:30""#), "gio")
        XCTAssertNil(YAMLLint.mappingKey(of: "# chú thích: có dấu hai chấm"))
        XCTAssertNil(YAMLLint.mappingKey(of: "khong_phai_cap"))
        // YAML đòi khoảng trắng sau dấu hai chấm; `a:b` là một giá trị, không phải cặp.
        XCTAssertNil(YAMLLint.mappingKey(of: "a:b"))
    }

    func testEmptyFileAndCommentsOnly() {
        XCTAssertTrue(YAMLLint.check("").isEmpty)
        XCTAssertTrue(YAMLLint.check("# chỉ có chú thích\n---\n").isEmpty)
    }
}
