import XCTest
@testable import GEditorCore
import LZMA

/// Bài kiểm cho `LibArchiveReader` — bộ đọc `.7z`, `.rar` và họ hàng, dựng từ nguồn libarchive
/// nạp vào repo.
///
/// # Fixture đến từ đâu, và bài kiểm chứng minh được gì
///
/// Với `.7z`, `.cpio`, `.zip`, `.tar.bz2` — fixture do **`/usr/bin/tar` của macOS** tạo. Đó là
/// một bản dựng khác, phiên bản khác, do người khác cấu hình; nó là hiện thực độc lập theo
/// đúng nghĩa cần có.
///
/// Với `.rar` thì KHÔNG có công cụ tạo nào trên máy — RAR là định dạng độc quyền và không có
/// bộ nén tự do. Nên fixture RAR ở đây do chính bài kiểm dựng byte-một, rồi được `/usr/bin/tar`
/// đọc lại để xác nhận nó là RAR hợp lệ.
///
/// Phải nói thẳng giới hạn của cách ấy: `bsdtar` của macOS cũng là libarchive. Bài kiểm RAR vì
/// vậy **không** chứng minh bộ giải mã RAR đúng — nó chứng minh thứ đang thật sự có nguy cơ
/// sai trong lượt thay đổi này: rằng lớp bọc Swift lái libarchive đúng, rằng định dạng RAR có
/// được đăng ký, và rằng tên lẫn nội dung đi qua ranh giới C↔Swift nguyên vẹn. Bản thân bộ
/// giải mã RAR là mã upstream, đã có bộ kiểm của upstream.
final class LibArchiveReaderTests: XCTestCase {

    // MARK: - Bản liblzma đang liên kết

    func testLIENKETdungBANlzmaDAvendorCHUkhongPHAIcuaHEdieuHANH() {
        // macOS có sẵn `/usr/lib/liblzma.5.dylib`. Nếu bản dựng vô tình liên kết vào nó thay vì
        // vào nguồn trong `Sources/LZMA/vendor`, mọi bài kiểm khác vẫn XANH — và ta sẽ nộp lên
        // App Store một bundle phụ thuộc vào thư viện không có hợp đồng API.
        //
        // Con số dưới đây phải khớp `PACKAGE_VERSION` trong Sources/LZMA/config/config.h, thứ
        // scripts/vendor-libarchive.sh đối chiếu với phiên bản nguồn nó vừa nạp. Ba chỗ buộc
        // vào nhau thì không chỗ nào trôi một mình được.
        let version = String(cString: lzma_version_string())
        XCTAssertEqual(version, "5.6.3",
                       "liblzma đang liên kết không phải bản đã vendor")
    }

    // MARK: - Đọc kho do hiện thực độc lập tạo ra

    func test7ZDOCduocVAkhopTUNGbyte() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        let noiDung = "noi dung trong kho 7z — có dấu tiếng Việt\n"
        let path = try dungKho(root, duoi: "7z", files: ["ghi-chu.txt": noiDung])

        let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
        let entry = try XCTUnwrap(entries.first { $0.path.hasSuffix("ghi-chu.txt") },
                                  "không thấy mục: \(entries.map(\.path))")
        XCTAssertEqual(entry.size, noiDung.utf8.count)
        XCTAssertEqual(
            String(decoding: try LibArchiveReader.data(archive: path, entry: entry), as: UTF8.self),
            noiDung)
    }

    func testTENcoDAUCACHvanNGUYENven() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // Đây là chỗ bản cũ — đọc bảng chữ do `tar -tv` in ra — dễ hỏng nhất: cắt dòng theo
        // khoảng trắng thì tên chỉ còn mảnh cuối. libarchive trả tên qua API nên không có bước
        // cắt chữ nào, và bài kiểm này chốt lại điều đó.
        let noiDung = "co dau cach\n"
        let path = try dungKho(root, duoi: "7z",
                              files: ["ten co dau cach.txt": noiDung])

        let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
        let entry = try XCTUnwrap(entries.first { $0.path.contains("dau cach") })
        XCTAssertTrue(entry.path.hasSuffix("ten co dau cach.txt"), "tên bị cắt: «\(entry.path)»")
    }

    func testTENtiengVIETdiQUAranhGIOIckhongHONG() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // Tên tệp có dấu là chỗ `archive_entry_pathname` (theo locale) trả ra ký tự rác, còn
        // `archive_entry_pathname_utf8` trả đúng. Bài này chốt ta gọi đúng hàm.
        let ten = "báo-cáo-quý-4.txt"
        let path = try dungKho(root, duoi: "7z", files: [ten: "x\n"])

        let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
        XCTAssertTrue(entries.contains { $0.path.hasSuffix(ten) },
                      "tên tiếng Việt hỏng: \(entries.map(\.path))")
    }

    func testNHIEUdinhDANGkhacNHAUdeuDOCduoc() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // `.tar.bz2` là đường mà `TarArchive` tự viết TỪ CHỐI — Apple `Compression` không có
        // bzip2. `.cpio` thì không bộ đọc nào của GEditor biết trước lượt này.
        let noiDung = "moi dinh dang deu phai ra dung chung mot noi dung\n"
        for duoi in ["7z", "tar.bz2", "cpio", "tar.xz"] {
            let path = try dungKho(root, duoi: duoi, files: ["a.txt": noiDung])
            let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
            let entry = try XCTUnwrap(entries.first { $0.path.hasSuffix("a.txt") },
                                      "\(duoi): không thấy mục")
            XCTAssertEqual(
                String(decoding: try LibArchiveReader.data(archive: path, entry: entry),
                       as: UTF8.self),
                noiDung, "\(duoi): nội dung sai")
        }
    }

    func testDOCduocKHOlonHONmotKHOI() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // Khối đọc là 64 KB. Một mục lớn hơn thế bắt vòng lặp trong `readCurrent` chạy nhiều
        // lượt — chỗ mà lỗi "chỉ lấy khối đầu" sẽ lộ ra. Dữ liệu ngẫu nhiên để bộ nén không
        // ép được nó về vài byte.
        var thoLon = ""
        var seed: UInt64 = 0x2545F4914F6CDD1D
        for _ in 0 ..< 40000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            thoLon += String(UInt8(truncatingIfNeeded: seed >> 33), radix: 16) + " "
        }
        let path = try dungKho(root, duoi: "7z", files: ["lon.txt": thoLon])

        let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
        let entry = try XCTUnwrap(entries.first { $0.path.hasSuffix("lon.txt") })
        let bytes = try LibArchiveReader.data(archive: path, entry: entry)
        XCTAssertGreaterThan(bytes.count, 65536, "fixture chưa đủ lớn để bài kiểm có nghĩa")
        XCTAssertEqual(String(decoding: bytes, as: UTF8.self), thoLon)
    }

    // MARK: - RAR

    func testRAR4DOCduoc() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        let noiDung = "noi dung trong kho rar — có dấu tiếng Việt\n"
        let path = root + "/kho.rar"
        try Data(Self.dungRAR4(ten: "ghi-chu.txt", noiDung: Array(noiDung.utf8)))
            .write(to: URL(fileURLWithPath: path))

        // TRƯỚC HẾT: bắt một hiện thực độc lập xác nhận fixture là RAR hợp lệ. Không có bước
        // này thì một fixture dựng sai vẫn có thể làm bài kiểm xanh — hoặc tệ hơn, làm nó đỏ
        // và ta đi sửa nhầm bộ đọc.
        let (output, status) = Self.chay(["/usr/bin/tar", "-tf", path])
        try XCTSkipUnless(status == 0, "bsdtar không đọc được fixture RAR — fixture dựng sai")
        XCTAssertTrue(output.contains("ghi-chu.txt"))

        let entries = try LibArchiveReader.list(path: path).filter { !$0.isDirectory }
        let entry = try XCTUnwrap(entries.first, "không đọc được kho RAR")
        XCTAssertEqual(entry.path, "ghi-chu.txt")
        XCTAssertEqual(entry.size, noiDung.utf8.count)
        XCTAssertEqual(
            String(decoding: try LibArchiveReader.data(archive: path, entry: entry), as: UTF8.self),
            noiDung)
    }

    // MARK: - Từ chối cho đúng

    func testKHOhongNOIRAlyDOthatCUAthuVIEN() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = root + "/hong.7z"
        // Chữ ký 7z đúng, ruột thì rác — kiểu hỏng của một tệp tải dở, và là kiểu buộc bộ đọc
        // phải đi qua nhánh nhận diện rồi mới đứt.
        try Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C] + Array("khong phai kho".utf8))
            .write(to: URL(fileURLWithPath: path))

        XCTAssertThrowsError(try LibArchiveReader.list(path: path)) { error in
            guard let failure = error as? LibArchiveReader.Failure else {
                return XCTFail("lỗi sai loại: \(error)")
            }
            // Câu từ chối phải mang lý do THẬT của thư viện, không phải một câu chung chung.
            let text = failure.description
            XCTAssertFalse(text.contains("không rõ lý do"), "mất lý do: \(text)")
        }
    }

    func testTEPVANBANthuongKHONGnhanNHAMthanhKHO() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = root + "/ghi-chu.txt"
        try Data("chỉ là một tệp văn bản\n".utf8).write(to: URL(fileURLWithPath: path))

        // Đây là đối chứng cho quyết định KHÔNG bật `archive_read_support_format_raw`. Bật nó
        // thì tệp này mở ra thành "kho hợp lệ có đúng một mục", và `MediaKind` mất đường phân
        // biệt file nén với văn bản.
        XCTAssertThrowsError(try LibArchiveReader.list(path: path),
                             "tệp văn bản thường bị nhận là kho nén — format_raw đang bật?")
    }

    func testKHOcoMATKHAUnoiRAchuKHONGtraVEracRUOI() throws {
        let zipTool = "/usr/bin/zip"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: zipTool), "không có zip(1)")
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        let work = root + "/noi-dung"
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        try Data("bi mat\n".utf8).write(to: URL(fileURLWithPath: work + "/mat.txt"))
        let out = root + "/co-mat-khau.zip"
        let (_, status) = Self.chay([zipTool, "-q", "-j", "-P", "matkhau", out, work + "/mat.txt"])
        try XCTSkipUnless(status == 0, "zip(1) không tạo được kho có mật khẩu")

        // Liệt kê thì được — mục lục không mã hoá. Đọc NỘI DUNG mới phải từ chối, và phải từ
        // chối bằng câu nói rõ "có mật khẩu" chứ không trả về vài byte đã mã hoá.
        let entries = try LibArchiveReader.list(path: out).filter { !$0.isDirectory }
        let entry = try XCTUnwrap(entries.first)
        XCTAssertTrue(entry.isEncrypted, "không nhận ra mục đã mã hoá")
        XCTAssertThrowsError(try LibArchiveReader.data(archive: out, entry: entry)) { error in
            XCTAssertEqual(error as? LibArchiveReader.Failure, .encrypted)
        }
    }

    func testMUCkhongCOthiNOIRAchuKHONGtraVErong() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = try dungKho(root, duoi: "7z", files: ["a.txt": "x\n"])

        let khongCo = LibArchiveReader.Entry(path: "khong-ton-tai.txt", size: 0,
                                             isDirectory: false, modified: nil,
                                             isEncrypted: false)
        XCTAssertThrowsError(try LibArchiveReader.data(archive: path, entry: khongCo)) { error in
            XCTAssertEqual(error as? LibArchiveReader.Failure,
                           .entryNotFound("khong-ton-tai.txt"))
        }
    }

    // MARK: - Hai đường đọc phải cho cùng kết quả

    func testREADALLvaDATAchoCUNGmotKETqua() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // `readAll` duyệt một lượt, `data` mở lại kho cho từng mục. Hai đường khác nhau hoàn
        // toàn ở phía libarchive, nên chúng đối chứng lẫn nhau: một lỗi con trỏ hay lỗi bỏ sót
        // khối trong đường này sẽ không xuất hiện y hệt ở đường kia.
        let files = ["a.txt": "noi dung a\n",
                     "thu-muc/b.txt": "noi dung b dai hon mot chut\n",
                     "c.txt": ""]
        let path = try dungKho(root, duoi: "7z", files: files)

        var theoReadAll: [String: [UInt8]] = [:]
        try LibArchiveReader.readAll(path: path) { entry, bytes in
            theoReadAll[entry.path] = bytes
        }

        var theoData: [String: [UInt8]] = [:]
        for entry in try LibArchiveReader.list(path: path) where !entry.isDirectory {
            theoData[entry.path] = try LibArchiveReader.data(archive: path, entry: entry)
        }

        XCTAssertEqual(theoReadAll.keys.sorted(), theoData.keys.sorted())
        XCTAssertEqual(theoReadAll.count, files.count)
        for (key, value) in theoReadAll {
            XCTAssertEqual(value, theoData[key], "khác nhau ở mục \(key)")
        }
    }

    func testREADALLdungNGAYkhiHANDLERnem() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = try dungKho(root, duoi: "7z",
                              files: ["a.txt": "1\n", "b.txt": "2\n", "c.txt": "3\n"])

        struct Dung: Error {}
        var daGap = 0
        XCTAssertThrowsError(try LibArchiveReader.readAll(path: path) { _, _ in
            daGap += 1
            if daGap == 1 { throw Dung() }
        })
        // Nếu lượt duyệt không dừng thật, con số này sẽ là 3. Đó là khác biệt giữa nút Huỷ
        // dừng được và nút Huỷ chỉ giấu kết quả đi sau khi đã làm xong.
        XCTAssertEqual(daGap, 1, "handler ném lỗi mà lượt duyệt vẫn chạy tiếp")
    }

    // MARK: - Dựng fixture RAR4

    /// Dựng một kho RAR 4 tối giản, một tệp, phương thức "lưu thẳng" (0x30).
    ///
    /// Bố cục theo đặc tả RAR 4: dấu nhận dạng → khối MAIN_HEAD → khối FILE_HEAD kèm dữ liệu →
    /// khối kết thúc. Mỗi khối mở đầu bằng 16 bit thấp của CRC32 tính trên phần thân đứng sau
    /// nó — bỏ qua chỗ ấy thì libarchive từ chối kho ngay, nên nó không phải chi tiết trang trí.
    static func dungRAR4(ten: String, noiDung: [UInt8]) -> [UInt8] {
        func le16(_ value: Int) -> [UInt8] { [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)] }
        func le32(_ value: UInt32) -> [UInt8] {
            (0 ..< 4).map { UInt8((value >> (8 * $0)) & 0xFF) }
        }
        func khoi(_ than: [UInt8]) -> [UInt8] {
            le16(Int(CRC32.compute(than) & 0xFFFF)) + than
        }

        var out: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]   // "Rar!\x1a\x07\x00"

        // MAIN_HEAD — kiểu 0x73, dài 13 byte, hai trường dự trữ để 0.
        out += khoi([0x73] + le16(0) + le16(13) + [UInt8](repeating: 0, count: 6))

        // FILE_HEAD — kiểu 0x74. Cờ 0x8000 = "có trường ADD_SIZE", tức PACK_SIZE bên dưới.
        let tenBytes = Array(ten.utf8)
        var than: [UInt8] = [0x74] + le16(0x8000) + le16(32 + tenBytes.count)
        than += le32(UInt32(noiDung.count))              // PACK_SIZE — bằng UNP_SIZE vì lưu thẳng
        than += le32(UInt32(noiDung.count))              // UNP_SIZE
        than += [0x03]                                   // HOST_OS = Unix
        than += le32(CRC32.compute(noiDung))             // CRC của dữ liệu
        than += le32(0x5000_0000)                        // FTIME dạng MS-DOS
        than += [0x14]                                   // UNP_VER = 2.0
        than += [0x30]                                   // METHOD 0x30 = lưu thẳng, không nén
        than += le16(tenBytes.count)
        than += le32(0x0000_0020)                        // ATTR
        than += tenBytes
        out += khoi(than)
        out += noiDung

        // Khối kết thúc — kiểu 0x7b, cờ 0x4000 ("bỏ qua nếu không hiểu").
        out += khoi([0x7B] + le16(0x4000) + le16(7))
        return out
    }

    // MARK: - Trợ giúp

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-libarc-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    /// Dựng kho bằng `/usr/bin/tar` — một hiện thực khác, để fixture không cùng nguồn gốc với
    /// bộ đọc đang được kiểm.
    private func dungKho(
        _ root: String, duoi: String, files: [String: String]
    ) throws -> String {
        let work = root + "/noi-dung-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        for (name, body) in files {
            let full = (work as NSString).appendingPathComponent(name)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            try Data(body.utf8).write(to: URL(fileURLWithPath: full))
        }
        let out = root + "/kho-\(UUID().uuidString.prefix(8))." + duoi
        let (_, status) = Self.chay(["/usr/bin/tar", "-acf", out, "-C", work, "."])
        guard status == 0, FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("tar(1) không dựng được kho .\(duoi)")
        }
        return out
    }

    @discardableResult
    private static func chay(_ arguments: [String]) -> (String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: arguments[0])
        process.arguments = Array(arguments.dropFirst())
        process.environment = ProcessInfo.processInfo.environment
            .merging(["COPYFILE_DISABLE": "1"]) { _, new in new }
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return ("", -1) }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        _ = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(decoding: data, as: UTF8.self), process.terminationStatus)
    }
}
