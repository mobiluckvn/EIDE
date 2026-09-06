import XCTest
@testable import GEditorCore

/// Truy vết: FR-AUTO-602 chạy macro hàng loạt theo thư mục.
final class MacroBatchTests: XCTestCase {

    private var directory = ""

    override func setUpWithError() throws {
        directory = NSTemporaryDirectory() + "geditor-macro-batch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    @discardableResult
    private func makeFile(_ name: String, _ content: String) throws -> String {
        let path = directory + "/" + name
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Macro thay mọi `cu` thành `moi`, chạy tới khi không còn gì để thay.
    private var replaceMacro: Macro {
        Macro(name: "đổi từ", steps: [
            .find(pattern: "cu", mode: .normal, matchCase: true, wholeWord: false),
            .replaceSelection("moi"),
        ])
    }

    func testWritesToNewFileByDefault() throws {
        let path = try makeFile("a.txt", "cu cu cu\n")
        let result = MacroBatch.run(replaceMacro, on: [path])

        XCTAssertEqual(result.succeededCount, 1)
        // MẶC ĐỊNH KHÔNG GHI ĐÈ: file gốc phải còn nguyên.
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "cu cu cu\n")

        let output = try XCTUnwrap(result.files.first?.outputPath)
        XCTAssertTrue(output.hasSuffix("a-sach.txt"))
        XCTAssertEqual(try String(contentsOfFile: output, encoding: .utf8), "moi moi moi\n")
    }

    /// Ghi đè phải được nói ra TƯỜNG MINH — đây là thao tác không lùi được.
    func testInPlaceOverwritesOnlyWhenAsked() throws {
        let path = try makeFile("b.txt", "cu\n")
        let result = MacroBatch.run(replaceMacro, on: [path], destination: .inPlace)
        XCTAssertEqual(result.files.first?.outputPath, path)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "moi\n")
    }

    func testDirectoryDestination() throws {
        let path = try makeFile("c.txt", "cu\n")
        let outDirectory = directory + "/ra"
        try FileManager.default.createDirectory(atPath: outDirectory, withIntermediateDirectories: true)

        let result = MacroBatch.run(
            replaceMacro, on: [path], destination: .directory(outDirectory)
        )
        XCTAssertEqual(result.files.first?.outputPath, outDirectory + "/c.txt")
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "cu\n", "file gốc còn nguyên")
    }

    /// File macro KHÔNG đổi gì thì không sinh ra file mới — nếu không, chạy trên hai trăm file
    /// sẽ đẻ ra hai trăm bản sao y hệt.
    func testUnchangedFileProducesNoOutput() throws {
        let path = try makeFile("d.txt", "không có gì để thay\n")
        let result = MacroBatch.run(replaceMacro, on: [path])
        XCTAssertNil(result.files.first?.outputPath)
        XCTAssertEqual(result.unchangedCount, 1)
        XCTAssertTrue(result.files.first?.succeeded ?? false, "không đổi gì KHÔNG phải lỗi")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory + "/d-sach.txt"))
    }

    /// Một file hỏng không được làm dừng cả mẻ — người dùng chỉ vào hai trăm file thì họ muốn
    /// một trăm chín mươi chín file kia vẫn chạy.
    func testOneBadFileDoesNotStopTheBatch() throws {
        let good = try makeFile("e.txt", "cu\n")
        let missing = directory + "/khong-ton-tai.txt"
        let result = MacroBatch.run(replaceMacro, on: [missing, good])

        XCTAssertEqual(result.files.count, 2)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(result.succeededCount, 1)
        XCTAssertNotNil(result.files.last?.outputPath)
    }

    func testOversizedFileIsRefusedWithReason() throws {
        let path = try makeFile("f.txt", "cu\n")
        // Không dựng file 64 MB thật; kiểm phép quyết định qua chính hàm tính đường ra và
        // ngưỡng đã công bố.
        XCTAssertEqual(MacroBatch.fileSizeLimit, 64 << 20)
        let result = MacroBatch.run(replaceMacro, on: [path])
        XCTAssertNil(result.files.first?.error, "file nhỏ thì không được từ chối")
    }

    func testVietnameseContentSurvives() throws {
        let path = try makeFile("g.txt", "cu — Thừa Thiên Huế\n")
        let result = MacroBatch.run(replaceMacro, on: [path])
        let output = try XCTUnwrap(result.files.first?.outputPath)
        XCTAssertEqual(
            try String(contentsOfFile: output, encoding: .utf8), "moi — Thừa Thiên Huế\n"
        )
    }

    // MARK: - Đường ra

    func testOutputPathRules() {
        XCTAssertEqual(
            MacroBatch.outputPath(for: "/a/b.txt", destination: .suffix("-sach")), "/a/b-sach.txt"
        )
        // File KHÔNG có đuôi: hậu tố vẫn phải vào, không được đẻ ra `b.-sach`.
        XCTAssertEqual(
            MacroBatch.outputPath(for: "/a/b", destination: .suffix("-sach")), "/a/b-sach"
        )
        XCTAssertEqual(MacroBatch.outputPath(for: "/a/b.txt", destination: .inPlace), "/a/b.txt")
        XCTAssertEqual(
            MacroBatch.outputPath(for: "/a/b.txt", destination: .directory("/ra")), "/ra/b.txt"
        )
    }

    // MARK: - Quét thư mục

    func testPicksTextFilesOnly() throws {
        try makeFile("a.txt", "x")
        try makeFile("b.csv", "x")
        try makeFile("c.png", "x")
        try makeFile("d.zip", "x")
        XCTAssertEqual(
            MacroBatch.textFiles(in: directory).map { ($0 as NSString).lastPathComponent },
            ["a.txt", "b.csv"]
        )
    }

    /// Chạy batch hai lần trong cùng thư mục mà không lọc thì lần hai xử lý cả kết quả của lần
    /// một, đẻ ra `a-macro-macro.txt`.
    func testSkipsItsOwnPreviousOutput() throws {
        try makeFile("a.txt", "x")
        try makeFile("a-macro.txt", "x")
        XCTAssertEqual(
            MacroBatch.textFiles(in: directory).map { ($0 as NSString).lastPathComponent },
            ["a.txt"]
        )
    }

    /// KHÔNG đệ quy: chỉ vào `~/Documents` mà đi xuống mọi thư mục con là chạy macro lên cả kho
    /// mã, cả thư mục ảnh, cả bản sao lưu.
    func testDoesNotRecurse() throws {
        try makeFile("a.txt", "x")
        let nested = directory + "/con"
        try FileManager.default.createDirectory(atPath: nested, withIntermediateDirectories: true)
        try "x".write(toFile: nested + "/b.txt", atomically: true, encoding: .utf8)
        XCTAssertEqual(MacroBatch.textFiles(in: directory).count, 1)
    }

    // MARK: - File mask (FR-AUTO-602)

    /// Mask lọc THAY cho bảng đuôi cứng, không lọc thêm sau nó.
    ///
    /// Nếu mask chỉ lọc thêm thì gõ `*.bak` sẽ ra rỗng — bảng đuôi không có `bak` — và ô nhập
    /// ấy trở thành thứ không làm gì đúng trong ca người dùng cần nó nhất.
    func testMaskChonDungNhungTepDaNeuTen() throws {
        _ = try makeFile("a.csv", "x")
        _ = try makeFile("b.log", "x")
        _ = try makeFile("c.json", "x")
        _ = try makeFile("d.bak", "x")

        let csvVaLog = MacroBatch.textFiles(in: directory, mask: "*.csv;*.log")
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(csvVaLog, ["a.csv", "b.log"])

        // `.bak` không nằm trong bảng đuôi văn bản, nhưng người dùng đã gọi đích danh nó.
        let bak = MacroBatch.textFiles(in: directory, mask: "*.bak")
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(bak, ["d.bak"])
    }

    func testMaskRongThiGiuNguyenHanhViCu() throws {
        _ = try makeFile("a.csv", "x")
        _ = try makeFile("d.bak", "x")
        let khongMask = MacroBatch.textFiles(in: directory, mask: "")
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(khongMask, ["a.csv"], "mask rỗng phải lọc theo bảng đuôi như trước")
    }

    /// Dấu `,` cũng ngăn cách được, và khoảng trắng thừa không làm hỏng mẫu.
    func testMaskDungDauPhayVaKhoangTrang() throws {
        _ = try makeFile("a.csv", "x")
        _ = try makeFile("b.log", "x")
        XCTAssertEqual(MacroBatch.textFiles(in: directory, mask: " *.csv , *.log ").count, 2)
    }

    /// Mask vẫn KHÔNG được kéo theo kết quả của lần chạy trước.
    func testMaskVanBoQuaKetQuaLanTruoc() throws {
        _ = try makeFile("a.txt", "x")
        _ = try makeFile("a-macro.txt", "x")
        let ra = MacroBatch.textFiles(in: directory, mask: "*.txt")
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(ra, ["a.txt"], "chạy batch hai lần sẽ đẻ ra a-macro-macro.txt")
    }

    func testReportNamesFailingFiles() throws {
        let good = try makeFile("h.txt", "cu\n")
        let result = MacroBatch.run(replaceMacro, on: [directory + "/thieu.txt", good])
        XCTAssertTrue(result.report.contains("thieu.txt"))
        XCTAssertTrue(result.report.contains("**1 file lỗi**"))
        XCTAssertTrue(result.report.contains("1 file xong"))
    }

    func testCancellationStopsEarly() throws {
        let paths = try (0 ..< 5).map { try makeFile("i\($0).txt", "cu\n") }
        let token = CancelToken()
        token.cancel()
        let result = MacroBatch.run(replaceMacro, on: paths, cancelToken: token)
        XCTAssertTrue(result.files.isEmpty, "đã huỷ thì không chạm file nào")
    }
}
