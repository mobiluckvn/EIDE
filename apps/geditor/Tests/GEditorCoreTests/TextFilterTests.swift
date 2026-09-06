import XCTest
@testable import GEditorCore

/// Truy vết: FR-AUTO-604 Run / Text Filter qua lệnh ngoài.
final class TextFilterTests: XCTestCase {

    // MARK: - Tách dòng lệnh

    func testTokenizeSimple() {
        XCTAssertEqual(TextFilter.tokenize("sort -u"), ["sort", "-u"])
        XCTAssertEqual(TextFilter.tokenize("   sort   -u  "), ["sort", "-u"])
        XCTAssertEqual(TextFilter.tokenize(""), [])
    }

    /// `jq '.a | .b'` phải là HAI đối số, không phải bốn.
    func testQuotedArgumentStaysWhole() {
        XCTAssertEqual(TextFilter.tokenize("jq '.a | .b'"), ["jq", ".a | .b"])
        XCTAssertEqual(TextFilter.tokenize(#"awk "{print $1}""#), ["awk", "{print $1}"])
    }

    /// `''` là một đối số RỖNG, không phải không có đối số nào.
    func testEmptyQuotedArgumentIsKept() {
        XCTAssertEqual(TextFilter.tokenize("tr ' ' ''"), ["tr", " ", ""])
    }

    // MARK: - Chạy

    func testPassesTextThroughCommand() throws {
        let out = try TextFilter.run(command: "sort", input: "c\na\nb\n")
        XCTAssertEqual(out, "a\nb\nc\n")
    }

    func testVietnameseSurvivesRoundTrip() throws {
        let out = try TextFilter.run(command: "cat", input: "Thừa Thiên Huế\n")
        XCTAssertEqual(out, "Thừa Thiên Huế\n")
    }

    /// Đầu vào LỚN HƠN bộ đệm ống dẫn (~64 KB). Không đọc stdout song song thì cả hai bên
    /// đứng yên vĩnh viễn — và lỗi ấy không lộ ra với đầu vào nhỏ.
    func testLargeInputDoesNotDeadlock() throws {
        let input = String(repeating: "một dòng dữ liệu\n", count: 40_000)
        let out = try TextFilter.run(command: "cat", input: input, timeout: 30)
        XCTAssertEqual(out.utf8.count, input.utf8.count)
    }

    func testEmptyCommandIsRejected() {
        XCTAssertThrowsError(try TextFilter.run(command: "   ", input: "x")) { error in
            XCTAssertEqual(error as? TextFilter.Failure, .emptyCommand)
        }
    }

    func testMissingCommandIsReportedByName() {
        XCTAssertThrowsError(
            try TextFilter.run(command: "lenh-khong-ton-tai-abcxyz", input: "x")
        ) { error in
            guard case .failed = error as? TextFilter.Failure else {
                // `env` báo lỗi qua mã thoát 127 chứ không làm `Process.run` ném — cả hai
                // đường đều chấp nhận được, miễn là KHÔNG trả về thành công.
                XCTAssertEqual(error as? TextFilter.Failure, .notFound("lenh-khong-ton-tai-abcxyz"))
                return
            }
        }
    }

    /// Mã thoát khác 0 phải mang theo stderr: "lệnh kết thúc với mã 2" một mình thì người dùng
    /// không biết sửa gì.
    func testFailureCarriesStderr() {
        XCTAssertThrowsError(
            try TextFilter.run(command: "sh -c 'echo hỏng rồi >&2; exit 3'", input: "")
        ) { error in
            guard case .failed(let status, let stderr) = error as? TextFilter.Failure else {
                return XCTFail("mong .failed, nhận \(error)")
            }
            XCTAssertEqual(status, 3)
            XCTAssertTrue(stderr.contains("hỏng rồi"))
        }
    }

    /// Một lệnh treo không được treo cả ứng dụng.
    func testHangingCommandIsKilled() {
        let started = Date()
        XCTAssertThrowsError(
            try TextFilter.run(command: "sleep 60", input: "", timeout: 1)
        ) { error in
            XCTAssertEqual(error as? TextFilter.Failure, .timedOut(1))
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10, "phải dừng ngay, không đợi hết 60s")
    }

    /// `yes` sinh vô hạn — đọc hết là hết RAM.
    func testUnboundedOutputIsStopped() {
        XCTAssertThrowsError(
            try TextFilter.run(command: "yes", input: "", timeout: 20, outputLimit: 1 << 20)
        ) { error in
            switch error as? TextFilter.Failure {
            case .outputTooLarge, .timedOut: break        // cả hai đều là "đã chặn lại"
            default: XCTFail("mong bị chặn, nhận \(String(describing: error))")
            }
        }
    }

    /// KHÔNG qua shell: một dấu `;` trong đối số là dấu chấm phẩy, không phải chỗ bắt đầu lệnh
    /// thứ hai. Đây là hàng rào chống tiêm lệnh, và nó phải có bài kiểm riêng.
    func testArgumentIsNotInterpretedAsShellSyntax() throws {
        let out = try TextFilter.run(command: "echo 'a; rm -rf /tmp/khong-ton-tai'", input: "")
        XCTAssertEqual(out.trimmingCharacters(in: .newlines), "a; rm -rf /tmp/khong-ton-tai")
    }
}
