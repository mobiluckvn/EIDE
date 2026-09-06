import XCTest
@testable import GEditorCore

/// Bài kiểm bộ đọc TAR. Fixture do `/usr/bin/tar` THẬT tạo ra — cùng luật với `ZipArchiveTests`.
final class TarArchiveTests: XCTestCase {

    private let noiDung = [
        "ghi-chu.txt": "Xin chào — có dấu tiếng Việt.\n",
        "thu-muc/long/sau.md": "# Tiêu đề\n\nMột đoạn.\n",
        "dai.txt": String(repeating: "một dòng lặp lại\n", count: 3_000),
    ]

    func testTARthuanDocDungTUNGBYTE() throws {
        let (root, path) = try dungTar(nen: nil)
        defer { try? FileManager.default.removeItem(atPath: root) }
        try kiemNoiDung(path)
    }

    func testTARGZdocDuoc() throws {
        let (root, path) = try dungTar(nen: "z")
        defer { try? FileManager.default.removeItem(atPath: root) }
        try kiemNoiDung(path)
    }

    func testTARXZdocDuoc() throws {
        let (root, path) = try dungTar(nen: "J")
        defer { try? FileManager.default.removeItem(atPath: root) }
        try kiemNoiDung(path)
    }

    func testTARBZ2thiNOIRAchuKhongTraBANGRONG() throws {
        let (root, path) = try dungTar(nen: "j")
        defer { try? FileManager.default.removeItem(atPath: root) }
        // `Compression` không có bzip2. Trả về một kho rỗng sẽ khiến người dùng tưởng tệp hỏng.
        XCTAssertThrowsError(try TarArchive(path: path)) { error in
            XCTAssertEqual(error as? TarArchive.Failure, .unsupportedCompression("bzip2"))
        }
    }

    func testTENDAIhonMOTTRAMkyTUvanDUNG() throws {
        // Tên trên 100 ký tự không vừa trường `name` của header, nên GNU tar ghi nó thành một
        // MỤC RIÊNG đứng trước. Bỏ qua vế ấy thì tên hiện ra bị cắt cụt.
        let ten = "thu-muc-rat-dai/" + String(repeating: "a", count: 120) + ".txt"
        let (root, path) = try dungTar(nen: nil, files: [ten: "nội dung\n"])
        defer { try? FileManager.default.removeItem(atPath: root) }

        let archive = try TarArchive(path: path)
        let mucs = archive.entries.filter { !$0.isDirectory }
            .map { $0.path.hasPrefix("./") ? String($0.path.dropFirst(2)) : $0.path }
        XCTAssertEqual(mucs, [ten], "tên dài bị cắt: \(mucs)")
    }

    // MARK: - Nhánh thuần tính toán

    func testNHANRAheaderTARbangCHECKSUM() {
        // Kiểm bằng checksum chứ không chỉ bằng chữ ký `ustar`: TAR cổ (v7) không có chữ ký ấy.
        var block = [UInt8](repeating: 0, count: 512)
        for (index, byte) in Array("a.txt".utf8).enumerated() { block[index] = byte }
        for (index, byte) in Array("0000010".utf8).enumerated() { block[124 + index] = byte }
        // Chưa điền checksum → phải TỪ CHỐI.
        XCTAssertFalse(TarArchive.isTarHeader(block))

        var sum = 0
        for (index, byte) in block.enumerated() {
            sum += (148 ..< 156).contains(index) ? 32 : Int(byte)
        }
        let octal = String(format: "%06o", sum)
        for (index, byte) in Array(octal.utf8).enumerated() { block[148 + index] = byte }
        block[154] = 0
        block[155] = UInt8(ascii: " ")
        XCTAssertTrue(TarArchive.isTarHeader(block), "header đúng mà vẫn bị từ chối")
    }

    func testDOCSOhe8() {
        var block = [UInt8](repeating: 0, count: 512)
        for (index, byte) in Array("0000144\0".utf8).enumerated() { block[124 + index] = byte }
        XCTAssertEqual(TarArchive.octal(block, 124, 12), 100)   // 0o144
    }

    // MARK: - Trợ giúp

    private func kiemNoiDung(_ path: String) throws {
        let archive = try TarArchive(path: path)
        // `tar` của macOS ghi đường dẫn kèm tiền tố `./` — đó là nội dung THẬT của kho, nên bộ
        // đọc phải trả đúng như vậy và bài kiểm chuẩn hoá ở phía nó.
        let mucs = archive.entries.filter { !$0.isDirectory }
        let ten = mucs.map { $0.path.hasPrefix("./") ? String($0.path.dropFirst(2)) : $0.path }
        XCTAssertEqual(Set(ten), Set(noiDung.keys), "danh sách mục lệch")
        for entry in mucs {
            let key = entry.path.hasPrefix("./") ? String(entry.path.dropFirst(2)) : entry.path
            let ra = try archive.data(for: entry)
            XCTAssertEqual(String(decoding: ra, as: UTF8.self), noiDung[key],
                           "nội dung «\(entry.path)» sai")
        }
    }

    /// Dựng kho bằng `/usr/bin/tar` thật. `nen`: `nil` · `"z"` gzip · `"j"` bzip2 · `"J"` xz.
    private func dungTar(
        nen: String?, files: [String: String]? = nil
    ) throws -> (root: String, path: String) {
        let tarTool = "/usr/bin/tar"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: tarTool),
                          "không có tar(1) trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-tar-\(UUID().uuidString)"
        let work = root + "/noi-dung"
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        for (name, body) in files ?? noiDung {
            let full = (work as NSString).appendingPathComponent(name)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            try Data(body.utf8).write(to: URL(fileURLWithPath: full))
        }

        let out = root + "/kho.tar" + (nen.map { ["z": ".gz", "j": ".bz2", "J": ".xz"][$0] ?? "" } ?? "")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tarTool)
        process.arguments = ["-c\(nen ?? "")f", out, "-C", work, "."]
        // `tar` của macOS mặc định ghi kèm tệp metadata AppleDouble (`._ten`) cho mỗi mục. Đó
        // là nội dung thật của kho — bộ đọc PHẢI liệt kê chúng — nhưng ở bài kiểm này chúng chỉ
        // làm nhiễu thứ đang đo, nên tắt đi bằng biến môi trường của chính `copyfile`.
        process.environment = ProcessInfo.processInfo.environment
            .merging(["COPYFILE_DISABLE": "1"]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XCTSkip("tar(1) trả mã \(process.terminationStatus)")
        }
        return (root, out)
    }
}
