import XCTest
@testable import GEditorCore

/// Chạy công thức trên nhiều file (FR-CLN-005).
final class CSVRecipeBatchTests: XCTestCase {

    private var folder = ""

    override func setUpWithError() throws {
        folder = NSTemporaryDirectory() + "geditor-batch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: folder)
    }

    @discardableResult
    private func write(_ name: String, _ contents: String) throws -> String {
        let path = (folder as NSString).appendingPathComponent(name)
        try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
        return path
    }

    private func read(_ path: String) throws -> String {
        String(decoding: try Data(contentsOf: URL(fileURLWithPath: path)), as: UTF8.self)
    }

    private var recipe: CSVRecipe {
        CSVRecipe(name: "chuẩn hóa ngày", steps: [
            CSVRecipeStep(columnName: "ngay", columnIndex: 1,
                          kind: .normalizeDates(order: .dayFirst)),
        ])
    }

    // MARK: - Không ghi đè

    /// Mặc định KHÔNG đụng vào file gốc — kết quả đi vào file mới cạnh nó.
    ///
    /// Người dùng có thể chỉ vào hai trăm file bằng một dòng lệnh; ghi đè là mặc định thì một
    /// lần chạy nhầm sẽ không lấy lại được.
    func testDefaultWritesBesideTheOriginal() throws {
        let source = "ma,ngay\nA1,25/07/2026\n"
        let path = try write("thang7.csv", source)

        let result = CSVRecipeBatch.run(recipe, files: [path])
        XCTAssertEqual(result.succeededCount, 1)
        XCTAssertEqual(try read(path), source, "file gốc phải còn nguyên")

        let output = (folder as NSString).appendingPathComponent("thang7-sach.csv")
        XCTAssertEqual(try read(output), "ma,ngay\nA1,2026-07-25\n")
        XCTAssertEqual(result.files.first?.outputPath, output)
    }

    func testInPlaceOnlyWhenAskedFor() throws {
        let path = try write("thang7.csv", "ma,ngay\nA1,25/07/2026\n")
        _ = CSVRecipeBatch.run(recipe, files: [path], destination: .inPlace)
        XCTAssertEqual(try read(path), "ma,ngay\nA1,2026-07-25\n")
    }

    func testDestinationDirectory() throws {
        let path = try write("thang7.csv", "ma,ngay\nA1,25/07/2026\n")
        let outFolder = (folder as NSString).appendingPathComponent("ra")
        try FileManager.default.createDirectory(atPath: outFolder, withIntermediateDirectories: true)

        _ = CSVRecipeBatch.run(recipe, files: [path], destination: .directory(outFolder))
        let output = (outFolder as NSString).appendingPathComponent("thang7.csv")
        XCTAssertEqual(try read(output), "ma,ngay\nA1,2026-07-25\n")
    }

    /// File không có gì để đổi thì KHÔNG ghi ra file nào.
    func testNothingToChangeWritesNothing() throws {
        let path = try write("sach.csv", "ma,ngay\nA1,2026-07-25\n")
        let result = CSVRecipeBatch.run(recipe, files: [path])

        XCTAssertNil(result.files.first?.outputPath)
        XCTAssertTrue(result.files.first?.succeeded ?? false)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: (folder as NSString).appendingPathComponent("sach-sach.csv")
            ),
            "không đổi gì mà vẫn đẻ ra một bản sao"
        )
    }

    // MARK: - Nhiều file

    /// Mỗi file dò dấu phân tách RIÊNG: thư mục thật hay lẫn file phẩy với file chấm phẩy.
    func testEachFileDetectsItsOwnDialect() throws {
        let commaPath = try write("phay.csv", "ma,ngay\nA1,25/07/2026\n")
        let semicolonPath = try write("champhay.csv", "ma;ngay\nA1;25/07/2026\n")

        let result = CSVRecipeBatch.run(recipe, files: [commaPath, semicolonPath])
        XCTAssertEqual(result.succeededCount, 2)
        XCTAssertEqual(
            try read((folder as NSString).appendingPathComponent("champhay-sach.csv")),
            "ma;ngay\nA1;2026-07-25\n"
        )
    }

    /// Một file hỏng KHÔNG được làm dừng cả mẻ, và phải hiện ra trong báo cáo.
    func testOneBadFileDoesNotStopTheRest() throws {
        let good = try write("tot.csv", "ma,ngay\nA1,25/07/2026\n")
        let missing = (folder as NSString).appendingPathComponent("khong-ton-tai.csv")
        let alsoGood = try write("tot2.csv", "ma,ngay\nA2,26/07/2026\n")

        let result = CSVRecipeBatch.run(recipe, files: [good, missing, alsoGood])
        XCTAssertEqual(result.succeededCount, 2)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertTrue(result.report.contains("File lỗi"), result.report)
        XCTAssertTrue(result.report.contains("khong-ton-tai.csv"), result.report)
    }

    /// File thiếu cột thì bước bị bỏ qua, và báo cáo tổng nói ra chuyện đó.
    func testMissingColumnShowsInTheSummary() throws {
        let full = try write("du.csv", "ma,ngay\nA1,25/07/2026\n")
        let partial = try write("thieu.csv", "ma,gia\nA1,100\n")

        let result = CSVRecipeBatch.run(recipe, files: [full, partial])
        XCTAssertEqual(result.succeededCount, 2)
        XCTAssertEqual(result.withProblems.count, 1)
        XCTAssertTrue(result.report.contains("bước bị bỏ qua"), result.report)
    }

    /// Tóm tắt đứng ĐẦU báo cáo: với hai trăm file, câu hỏi đầu tiên là "có cái nào hỏng không".
    func testReportLeadsWithTheSummary() throws {
        let path = try write("a.csv", "ma,ngay\nA1,25/07/2026\n")
        let report = CSVRecipeBatch.run(recipe, files: [path]).report
        XCTAssertTrue(report.hasPrefix("# Chạy công thức «chuẩn hóa ngày» trên 1 file"), report)
        XCTAssertTrue(report.contains("→ ghi ra"), report)
    }

    // MARK: - Quét thư mục

    func testFindsCSVFilesNotOtherThings() throws {
        try write("a.csv", "x\n")
        try write("b.TSV", "x\n")
        try write("c.txt", "x\n")
        try write("d.pdf", "x\n")
        try FileManager.default.createDirectory(
            atPath: (folder as NSString).appendingPathComponent("con"),
            withIntermediateDirectories: true
        )

        let files = CSVRecipeBatch.csvFiles(in: folder).map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(files, ["a.csv", "b.TSV", "c.txt"])
    }

    /// Dừng giữa chừng thì dừng thật — hai trăm file có thể mất vài phút.
    func testProgressCanStop() throws {
        let first = try write("1.csv", "ma,ngay\nA1,25/07/2026\n")
        let second = try write("2.csv", "ma,ngay\nA2,26/07/2026\n")

        var seen: [String] = []
        let result = CSVRecipeBatch.run(recipe, files: [first, second]) { _, path in
            seen.append(path)
            return seen.count < 2      // dừng trước file thứ hai
        }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: (folder as NSString).appendingPathComponent("2-sach.csv")
            )
        )
    }

    // MARK: - Bảng mã

    /// Batch KHÔNG được đổi bảng mã của người dùng.
    ///
    /// Một file bảng mã cũ chạy qua công thức mà ra UTF-8 là thay đổi không ai yêu cầu, và với
    /// hệ thống đang đọc file ấy thì đó là hỏng.
    func testKeepsTheOriginalEncoding() throws {
        // Một byte ngoài ASCII đủ để lõi xếp file vào nhóm bảng mã Việt cũ (ở đây nhận ra là
        // VISCII). Bài kiểm khẳng định điều đó trước khi kiểm điều cần kiểm — nếu file được
        // đọc là UTF-8 thì phép so bảng mã bên dưới đúng một cách vô nghĩa.
        let path = (folder as NSString).appendingPathComponent("cu.csv")
        let bytes: [UInt8] = Array("ma,ngay,ten\nA1,25/07/2026,Hu".utf8) + [0xD5] + Array("\n".utf8)
        try Data(bytes).write(to: URL(fileURLWithPath: path))

        let document = try Document.open(path: path)
        let sourceEncoding = document.encoding
        XCTAssertNotEqual(sourceEncoding, .utf8, "fixture không còn là bảng mã cũ, bài kiểm mất nghĩa")

        _ = CSVRecipeBatch.run(recipe, files: [path], destination: .inPlace)
        let after = try Document.open(path: path)
        XCTAssertEqual(after.encoding, sourceEncoding, "bảng mã bị đổi sau khi chạy công thức")
        XCTAssertTrue(after.buffer.text.contains("2026-07-25"))
    }
}
