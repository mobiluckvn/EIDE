import XCTest
@testable import GEditorCore

/// Bài kiểm cho bộ đọc ZIP.
///
/// **Fixture do `/usr/bin/zip` THẬT tạo ra, không do tay tôi bịa byte.** Đây là cùng một luật
/// đã học ở FR-MMD: với thứ ta ĐỌC của người khác, một fixture tự dựng chỉ kiểm lại chính hiểu
/// biết của người viết bộ đọc — nếu tôi hiểu sai định dạng, tôi sẽ dựng fixture sai theo đúng
/// cách ấy và bài kiểm vẫn xanh. Chạy qua một hiện thực độc lập là cách duy nhất bắt được.
///
/// Và hai fixture mạnh nhất thì đã nằm sẵn trong kho: `.docx` và `.xlsx` trong `docs/` là file
/// ZIP thật do Microsoft Word/Excel ghi ra.
final class ZipArchiveTests: XCTestCase {

    // MARK: - Đọc file do zip(1) tạo

    func testDocFileDoZIPthatTaoRaDocDungTUNGBYTE() throws {
        let noiDung = [
            "chào.txt": "Xin chào — có dấu tiếng Việt.\n",
            "thu-muc/lồng/sâu.md": "# Tiêu đề\n\nMột đoạn.\n",
            "rong.txt": "",
            // Đủ dài để zip thật sự DEFLATE chứ không cất nguyên — nhánh giải nén phải chạy.
            "dai.txt": String(repeating: "một dòng lặp đi lặp lại\n", count: 5_000),
        ]
        let zip = try dungZip(noiDung)
        defer { try? FileManager.default.removeItem(atPath: (zip as NSString).deletingLastPathComponent) }

        let archive = try ZipArchive(path: zip)
        let tep = archive.entries.filter { !$0.isDirectory }
        XCTAssertEqual(Set(tep.map(\.path)), Set(noiDung.keys), "danh sách mục lệch")

        for entry in tep {
            let ra = try archive.data(for: entry)
            XCTAssertEqual(String(decoding: ra, as: UTF8.self), noiDung[entry.path],
                           "nội dung «\(entry.path)» sai")
            XCTAssertEqual(ra.count, entry.uncompressedSize)
        }

        // Có ít nhất một mục thật sự được nén — nếu không thì nhánh deflate chưa ai chạy qua.
        XCTAssertTrue(tep.contains { $0.method == .deflate },
                      "không mục nào deflate: bài kiểm chỉ đang kiểm nhánh «cất nguyên»")
    }

    func testMucCATNGUYENkhongNENvanDocDuoc() throws {
        let zip = try dungZip(["a.txt": "nội dung không nén\n"], khongNen: true)
        defer { try? FileManager.default.removeItem(atPath: (zip as NSString).deletingLastPathComponent) }

        let archive = try ZipArchive(path: zip)
        let entry = try XCTUnwrap(archive.entries.first { $0.path == "a.txt" })
        XCTAssertEqual(entry.method, .stored)
        XCTAssertEqual(String(decoding: try archive.data(for: entry), as: UTF8.self),
                       "nội dung không nén\n")
    }

    // MARK: - Đối chứng ÂM: file hỏng phải bị bắt

    func testSUAMOTBYTEtrongDuLieuThiCRCbatDuoc() throws {
        let zip = try dungZip(["a.txt": String(repeating: "dữ liệu\n", count: 2_000)])
        defer { try? FileManager.default.removeItem(atPath: (zip as NSString).deletingLastPathComponent) }

        // Đọc lành trước — để biết bài kiểm đang so với một trạng thái ĐÚNG.
        let truoc = try ZipArchive(path: zip)
        let entryTruoc = try XCTUnwrap(truoc.entries.first { $0.path == "a.txt" })
        XCTAssertNoThrow(try truoc.data(for: entryTruoc))

        // Lật một bit ở giữa vùng dữ liệu nén.
        var bytes = try [UInt8](Data(contentsOf: URL(fileURLWithPath: zip)))
        bytes[bytes.count / 2] ^= 0xFF
        try Data(bytes).write(to: URL(fileURLWithPath: zip))

        let sau = try ZipArchive(path: zip)
        let entry = try XCTUnwrap(sau.entries.first { $0.path == "a.txt" })
        XCTAssertThrowsError(try sau.data(for: entry)) { error in
            // Hỏng có thể lộ ra ở CRC hoặc ngay ở bước giải nén — cả hai đều là "bắt được".
            // Thứ KHÔNG chấp nhận được là trả về dữ liệu rác mà không nói gì.
            guard error is ZipArchive.Failure else {
                return XCTFail("lỗi lạ: \(error)")
            }
        }
    }

    func testFILEKHONGPHAIZIPthiNOIRAchuKhongDoanBua() throws {
        let path = NSTemporaryDirectory() + "/geditor-\(UUID().uuidString).zip"
        try Data("đây chỉ là văn bản thuần, không phải file nén\n".utf8)
            .write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try ZipArchive(path: path)) { error in
            XCTAssertEqual(error as? ZipArchive.Failure, .notAZip(path: path))
        }
    }

    func testNHANRAzipBANGNOIDUNGchuKhongBangDuoiTep() throws {
        XCTAssertTrue(ZipArchive.looksLikeZip([0x50, 0x4B, 0x03, 0x04]))
        XCTAssertTrue(ZipArchive.looksLikeZip([0x50, 0x4B, 0x05, 0x06]))   // file nén rỗng
        XCTAssertFalse(ZipArchive.looksLikeZip(Array("tinh,doanh_thu\n".utf8)))
        XCTAssertFalse(ZipArchive.looksLikeZip([0x50, 0x4B]))              // quá ngắn
        XCTAssertFalse(ZipArchive.looksLikeZip([0x25, 0x50, 0x44, 0x46]))  // "%PDF"
    }

    // MARK: - Zip Slip

    func testDUONGDANTHOATRANGOAIbiTUCHOI() {
        let goc = "/tmp/dich"
        // Ba lối tấn công, và lối thứ ba là lối người ta hay quên.
        XCTAssertNil(ZipArchive.safeDestination(for: "../../etc/passwd", under: goc))
        XCTAssertNil(ZipArchive.safeDestination(for: "/etc/passwd", under: goc))
        XCTAssertNil(ZipArchive.safeDestination(for: "..\\..\\Windows\\x", under: goc),
                     "dấu \\ của Windows lọt qua phép kiểm dựa trên /")

        // Và đường dẫn lành thì vẫn phải đi qua được — một hàng rào chặn hết là hàng rào vô dụng.
        XCTAssertEqual(ZipArchive.safeDestination(for: "a/b.txt", under: goc), "/tmp/dich/a/b.txt")
        XCTAssertEqual(ZipArchive.safeDestination(for: "./a.txt", under: goc), "/tmp/dich/a.txt")
        // `..` ở GIỮA mà không thoát ra ngoài thì hợp lệ.
        XCTAssertEqual(ZipArchive.safeDestination(for: "a/../b.txt", under: goc), "/tmp/dich/b.txt")
    }

    // MARK: - Fixture MẠNH NHẤT: file Office thật trong kho

    func testFILEDOCXtrongKhoLAfileZIPvaDocDuocPhanRuot() throws {
        let docx = kho("docs/GioiThieu_TinhNang_GEditor_v2.0.docx")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: docx), "không có file docx mẫu")

        let archive = try ZipArchive(path: docx)
        // Ba tệp mà MỌI file .docx hợp lệ đều phải có — đây là bộ xương của OOXML.
        XCTAssertTrue(archive.entries.contains { $0.path == "[Content_Types].xml" })
        XCTAssertTrue(archive.entries.contains { $0.path == "word/document.xml" })

        let xml = try XCTUnwrap(archive.data(named: "word/document.xml"))
        let text = String(decoding: xml, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("<?xml"), "phần ruột không phải XML: \(text.prefix(80))")
        XCTAssertTrue(text.contains("<w:body"), "không thấy thân tài liệu Word")
    }

    func testFILEXLSXtrongKhoDocDuocBangSheet() throws {
        let xlsx = kho("docs/TongHop_TinhNang_GEditor_v2.0.xlsx")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: xlsx), "không có file xlsx mẫu")

        let archive = try ZipArchive(path: xlsx)
        XCTAssertTrue(archive.entries.contains { $0.path == "xl/workbook.xml" })
        XCTAssertTrue(archive.entries.contains { $0.path.hasPrefix("xl/worksheets/sheet") })

        let workbook = try XCTUnwrap(archive.data(named: "xl/workbook.xml"))
        XCTAssertTrue(String(decoding: workbook, as: UTF8.self).contains("<sheet"))
    }

    // MARK: - Trợ giúp

    /// Dựng một file ZIP bằng `/usr/bin/zip` thật.
    private func dungZip(_ files: [String: String], khongNen: Bool = false) throws -> String {
        let zipTool = "/usr/bin/zip"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: zipTool),
                          "không có zip(1) trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-zip-\(UUID().uuidString)"
        let work = root + "/noi-dung"
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)

        for (name, body) in files {
            let full = (work as NSString).appendingPathComponent(name)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            try Data(body.utf8).write(to: URL(fileURLWithPath: full))
        }

        let out = root + "/thu.zip"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zipTool)
        process.arguments = ["-q", "-r"] + (khongNen ? ["-0"] : []) + [out, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: work)
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XCTSkip("zip(1) trả mã \(process.terminationStatus)")
        }
        return out
    }

    /// Đường dẫn tới một tệp trong kho, suy từ vị trí tệp nguồn này.
    private func kho(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }   // Tests/GEditorCoreTests/x.swift
        return root.appendingPathComponent(relative).path
    }
}
