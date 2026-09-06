import XCTest
@testable import GEditorCore

/// Kiểm thử Find/Replace in Files (FR-SRCH-105, FR-SRCH-106, NFR-PERF-06).
final class FindInFilesTests: XCTestCase {

    private var root = ""

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "/geditor-fif-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    @discardableResult
    private func write(_ relativePath: String, _ contents: String) throws -> String {
        let path = "\(root)/\(relativePath)"
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
        return path
    }

    @discardableResult
    private func writeBytes(_ relativePath: String, _ bytes: [UInt8]) throws -> String {
        let path = "\(root)/\(relativePath)"
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        return path
    }

    private func read(_ path: String) throws -> String {
        String(decoding: try Data(contentsOf: URL(fileURLWithPath: path)), as: UTF8.self)
    }

    // MARK: - Duyệt và lọc

    func testCollectsFilesRecursivelyAndSkipsExcludedDirectories() throws {
        try write("a.txt", "x")
        try write("con/b.txt", "x")
        try write(".git/c.txt", "x")
        try write("node_modules/d.txt", "x")

        let files = FindInFiles.collectFiles(root: root).map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(files.sorted(), ["a.txt", "b.txt"], "thư mục nhiễu phải bị bỏ theo mặc định")
    }

    func testIncludeAndExcludeGlobs() throws {
        try write("một.csv", "x")
        try write("hai.txt", "x")
        try write("ba.log", "x")

        var options = FindInFiles.Options(includeGlobs: ["*.csv", "*.log"])
        var files = FindInFiles.collectFiles(root: root, options: options)
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(files.sorted(), ["ba.log", "một.csv"])

        options = FindInFiles.Options(includeGlobs: ["*"], excludeGlobs: ["*.log"])
        files = FindInFiles.collectFiles(root: root, options: options)
            .map { ($0 as NSString).lastPathComponent }
        XCTAssertEqual(files.sorted(), ["hai.txt", "một.csv"])
    }

    // MARK: - Tìm

    func testReportsLineColumnAndPreview() throws {
        try write("đơn.csv", "dòng một\ndòng hai có TÌM ở đây\ndòng ba\n")
        let summary = try FindInFiles.search(
            root: root, pattern: "TÌM", searchOptions: SearchOptions(mode: .normal)
        )

        XCTAssertEqual(summary.results.count, 1)
        let hit = try XCTUnwrap(summary.results.first?.hits.first)
        XCTAssertEqual(hit.line, 2, "số dòng là 1-based")
        XCTAssertEqual(hit.byteColumn, "dòng hai có ".utf8.count + 1, "cột tính bằng byte, 1-based")
        XCTAssertEqual(hit.lineText, "dòng hai có TÌM ở đây")
    }

    func testFindsAcrossManyFiles() throws {
        for index in 0 ..< 30 {
            try write("f\(index).txt", index % 3 == 0 ? "có mục tiêu\n" : "không có gì\n")
        }
        let summary = try FindInFiles.search(
            root: root, pattern: "mục tiêu", searchOptions: SearchOptions(mode: .normal)
        )
        XCTAssertEqual(summary.results.count, 10)
        XCTAssertEqual(summary.totalHits, 10)
        XCTAssertEqual(summary.filesScanned, 30)
    }

    func testCRLFLinesAreCountedCorrectly() throws {
        try write("crlf.txt", "một\r\nhai\r\nmục tiêu\r\n")
        let summary = try FindInFiles.search(
            root: root, pattern: "mục tiêu", searchOptions: SearchOptions(mode: .normal)
        )
        let hit = try XCTUnwrap(summary.results.first?.hits.first)
        XCTAssertEqual(hit.line, 3)
        XCTAssertEqual(hit.lineText, "mục tiêu", "CR cuối dòng phải bị cắt khỏi đoạn xem trước")
    }

    func testBinaryFilesAreSkipped() throws {
        try write("văn-bản.txt", "mục tiêu")
        try writeBytes("nhị-phân.bin", Array("mục tiêu".utf8) + [0x00, 0x01, 0x02])

        let summary = try FindInFiles.search(
            root: root, pattern: "mục tiêu", searchOptions: SearchOptions(mode: .normal)
        )
        XCTAssertEqual(summary.results.count, 1)
        XCTAssertEqual(summary.results[0].path, "\(root)/văn-bản.txt")
        XCTAssertEqual(summary.filesSkipped.values.first, .binary)
    }

    /// File có byte hỏng vẫn phải tìm được — pattern dùng chung được biên dịch cho dữ liệu
    /// sạch, nên đường xử lý riêng cho file hỏng phải thật sự chạy (FR-ENC-201).
    func testFilesWithInvalidUTF8AreStillSearched() throws {
        try writeBytes("hỏng.txt", Array("trước ".utf8) + [0xFF] + Array(" mục tiêu".utf8))
        let summary = try FindInFiles.search(
            root: root, pattern: "mục tiêu", searchOptions: SearchOptions(mode: .normal)
        )
        XCTAssertEqual(summary.totalHits, 1)
    }

    func testLimitPerFile() throws {
        try write("nhiều.txt", String(repeating: "x\n", count: 100))
        let summary = try FindInFiles.search(
            root: root, pattern: "x", searchOptions: SearchOptions(mode: .normal),
            options: FindInFiles.Options(limitPerFile: 7)
        )
        XCTAssertEqual(summary.totalHits, 7)
        XCTAssertTrue(summary.results[0].truncated)
    }

    /// NFR-PERF-06 dựa trên việc chạy nhiều luồng. Song song mà đổi KẾT QUẢ thì mọi con số
    /// hiệu năng đều vô nghĩa, nên đây là điều kiện tiên quyết của phép đo.
    func testConcurrencyDoesNotChangeResults() throws {
        for index in 0 ..< 60 {
            try write("f\(index).txt", String(repeating: "mục tiêu \(index)\n", count: index + 1))
        }

        func run(_ concurrency: Int) throws -> [(String, Int)] {
            let summary = try FindInFiles.search(
                root: root, pattern: "mục tiêu", searchOptions: SearchOptions(mode: .normal),
                options: FindInFiles.Options(concurrency: concurrency)
            )
            return summary.results.map { ($0.path, $0.hits.count) }
        }

        let single = try run(1)
        let many = try run(8)
        XCTAssertEqual(single.map(\.0), many.map(\.0), "thứ tự kết quả phải ổn định")
        XCTAssertEqual(single.map(\.1), many.map(\.1))
        XCTAssertEqual(single.reduce(0) { $0 + $1.1 }, 1830, "tổng 1+2+…+60")
    }

    /// TC-SRCH-06 đòi hủy giữa chừng đáp ứng ≤ 200 ms. Ở mức lõi điều đó có nghĩa là lời gọi
    /// `search` phải TRẢ VỀ trong ngần ấy thời gian sau khi token bị hủy, chứ không chạy nốt
    /// danh sách file rồi mới báo.
    func testCancellationReturnsWithinTwoHundredMilliseconds() throws {
        for index in 0 ..< 400 {
            try write("f\(index).txt", String(repeating: "x\n", count: 5_000))
        }
        let token = CancelToken(timeout: 0.001)
        let start = Date()

        XCTAssertThrowsError(
            try FindInFiles.search(
                root: root, pattern: "x", searchOptions: SearchOptions(mode: .normal),
                options: FindInFiles.Options(concurrency: 2), cancelToken: token
            )
        ) { XCTAssertTrue($0 is DeadlineExceeded, "nhận \($0)") }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2, "TC-SRCH-06 đòi hủy ≤ 200 ms, mất \(elapsed)s")
    }

    // MARK: - Thay thế (FR-SRCH-106)

    func testDryRunReportsWithoutTouchingFiles() throws {
        let path = try write("a.txt", "cũ cũ cũ")
        let pattern = try PCRE2Pattern(pattern: "cũ", options: SearchOptions(mode: .normal))

        let plans = try FindInFiles.replace(
            files: [path], pattern: pattern, template: "mới", dryRun: true
        )
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].matchCount, 3)
        XCTAssertFalse(plans[0].applied)
        XCTAssertEqual(try read(path), "cũ cũ cũ", "chạy thử KHÔNG được đụng vào file")
    }

    func testReplaceWritesFileAtomically() throws {
        let path = try write("a.txt", "một\nhai\nba\n")
        let pattern = try PCRE2Pattern(pattern: "^(\\w+)$", options: SearchOptions(mode: .regex))

        let done = try FindInFiles.replace(
            files: [path], pattern: pattern, template: "[\\U$1\\E]", dryRun: false
        )
        XCTAssertTrue(done[0].applied)
        XCTAssertEqual(try read(path), "[MỘT]\n[HAI]\n[BA]\n")

        // Không để lại file tạm nào trong thư mục.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root)
            .filter { $0.hasPrefix(".geditor-") }
        XCTAssertTrue(leftovers.isEmpty, "còn sót file tạm: \(leftovers)")
    }

    func testReplaceAcrossManyFilesMatchesDryRun() throws {
        var paths: [String] = []
        for index in 0 ..< 25 {
            paths.append(try write("f\(index).txt", String(repeating: "cũ\n", count: index + 1)))
        }
        let pattern = try PCRE2Pattern(pattern: "cũ", options: SearchOptions(mode: .normal))

        let preview = try FindInFiles.replace(
            files: paths, pattern: pattern, template: "mới", dryRun: true
        )
        let applied = try FindInFiles.replace(
            files: paths, pattern: pattern, template: "mới", dryRun: false
        )

        XCTAssertEqual(preview.map(\.path), applied.map(\.path))
        XCTAssertEqual(preview.map(\.matchCount), applied.map(\.matchCount),
                       "bản xem trước phải khớp bản ghi thật, nếu không dry-run là vô dụng")
        XCTAssertEqual(preview.map(\.byteDelta), applied.map(\.byteDelta))

        for (index, path) in paths.enumerated() {
            XCTAssertEqual(try read(path), String(repeating: "mới\n", count: index + 1))
        }
    }

    func testReplaceLeavesNonMatchingFilesUntouched() throws {
        let path = try write("a.txt", "không có gì ở đây")
        let before = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        let pattern = try PCRE2Pattern(pattern: "vắng mặt", options: SearchOptions(mode: .normal))

        let done = try FindInFiles.replace(
            files: [path], pattern: pattern, template: "x", dryRun: false
        )
        XCTAssertTrue(done.isEmpty, "file không khớp không được xuất hiện trong kết quả")
        let after = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        XCTAssertEqual(before, after, "file không khớp KHÔNG được ghi lại")
    }
}
