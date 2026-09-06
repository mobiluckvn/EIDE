import XCTest
@testable import GEditorCore

/// Bảng tính NHIỀU SHEET — đọc đúng sheet, và ghi đúng sheet.
///
/// Bài quan trọng nhất ở đây là `testGHIsheetHAIkhongDUNGsheetMOT`. Trước khi có bộ chọn sheet,
/// đường ghi ngược của tầng app cứng ở `sheets.first` — đúng khi chỉ mở được sheet đầu, và trở
/// thành ghi NHẦM SHEET ngay khi người dùng chuyển sang sheet khác. Kiểu hỏng ấy im lặng: tệp
/// vẫn ghi được, vẫn mở lại được, dữ liệu chỉ nằm sai chỗ.
///
/// **Fixture do LibreOffice ghi**, đúng luật đã học: tự dựng XML theo hiểu biết của người viết
/// bộ đọc thì bài kiểm chỉ xác nhận lại hiểu biết ấy.
final class XLSXMultiSheetTests: XCTestCase {

    // MARK: - Đọc

    func testDOCduocTENvaNOIdungCUAtungSHEET() throws {
        let path = try dungHaiSheet()
        defer { don(path) }

        let reader = try XLSXReader(path: path)
        XCTAssertEqual(reader.sheets.map(\.name), ["DoanhThu", "ChiPhi"],
                       "tên sheet phải là tên THẬT và đúng thứ tự trong tệp")

        let doanhThu = try reader.grid(named: "DoanhThu")
        XCTAssertEqual(doanhThu.rows.first, ["thang", "tien"])
        XCTAssertEqual(doanhThu.rows[1], ["1", "100"])

        let chiPhi = try reader.grid(named: "ChiPhi")
        XCTAssertEqual(chiPhi.rows.first, ["muc", "so"])
        XCTAssertEqual(chiPhi.rows[1], ["thue", "7"])
    }

    func testSHEETkhongCOthiNOIraTENchuKHONGroiVEsheetDAU() throws {
        let path = try dungHaiSheet()
        defer { don(path) }
        let reader = try XLSXReader(path: path)

        // Rơi về sheet đầu là cách hỏng im lặng: người dùng nhận dữ liệu của một sheet KHÁC mà
        // không có dấu hiệu nào.
        XCTAssertThrowsError(try reader.grid(named: "KhongCo")) { error in
            XCTAssertEqual(error as? XLSXReader.Failure, .sheetNotFound("KhongCo"))
        }
    }

    // MARK: - Ghi

    func testGHIsheetHAIkhongDUNGsheetMOT() throws {
        let path = try dungHaiSheet()
        defer { don(path) }

        let reader = try XLSXReader(path: path)
        guard let chiPhi = reader.sheets.first(where: { $0.name == "ChiPhi" }) else {
            return XCTFail("không thấy sheet ChiPhi")
        }
        let truoc = try reader.grid(of: chiPhi).rows
        var sau = truoc
        sau[1][1] = "999"

        let diff = try XLSXWriter.diff(from: truoc, to: sau)
        try XLSXWriter.writeInPlace(source: path, sheet: chiPhi, diff: diff)

        // Mở LẠI tệp trên đĩa — không tin vào biến trong bộ nhớ.
        let lai = try XLSXReader(path: path)
        XCTAssertEqual(try lai.grid(named: "ChiPhi").rows[1], ["thue", "999"],
                       "sửa không vào được sheet đích")
        XCTAssertEqual(try lai.grid(named: "DoanhThu").rows[1], ["1", "100"],
                       "ghi vào ChiPhi mà DoanhThu đổi theo — đây là ghi nhầm sheet")
        XCTAssertEqual(lai.sheets.map(\.name), ["DoanhThu", "ChiPhi"],
                       "ghi xong mất sheet hoặc đổi thứ tự")
    }

    func testGHIsheetMOTkhongDUNGsheetHAI() throws {
        // Chiều ngược lại — nếu chỉ kiểm một chiều thì một bộ ghi luôn nhắm vào sheet đầu vẫn
        // xanh ở bài trên khi sheet đích tình cờ là sheet đầu.
        let path = try dungHaiSheet()
        defer { don(path) }

        let reader = try XLSXReader(path: path)
        guard let doanhThu = reader.sheets.first else { return XCTFail("không có sheet nào") }
        let truoc = try reader.grid(of: doanhThu).rows
        var sau = truoc
        sau[1][1] = "555"

        let diff = try XLSXWriter.diff(from: truoc, to: sau)
        try XLSXWriter.writeInPlace(source: path, sheet: doanhThu, diff: diff)

        let lai = try XLSXReader(path: path)
        XCTAssertEqual(try lai.grid(named: "DoanhThu").rows[1], ["1", "555"])
        XCTAssertEqual(try lai.grid(named: "ChiPhi").rows[1], ["thue", "7"],
                       "ghi vào DoanhThu mà ChiPhi đổi theo")
    }

    // MARK: - Dựng fixture bằng LibreOffice

    private func don(_ path: String) {
        try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent)
    }

    /// Một `.xlsx` hai sheet, do LibreOffice ghi từ một tệp ODS phẳng.
    ///
    /// ODS phẳng (`.fods`) là XML một tệp, nên viết được bằng tay mà không phải đóng gói ZIP —
    /// và LibreOffice vẫn là thứ sinh ra tệp `.xlsx` cuối cùng, tức fixture vẫn do hiện thực
    /// độc lập ghi.
    private func dungHaiSheet() throws -> String {
        let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: soffice),
                          "không có LibreOffice trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-2sheet-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

        func cell(_ value: String) -> String {
            let kieu = Int(value) == nil ? "string" : "float"
            let so = Int(value) == nil ? "" : " office:value=\"\(value)\""
            return "<table:table-cell office:value-type=\"\(kieu)\"\(so)>"
                + "<text:p>\(value)</text:p></table:table-cell>"
        }
        func row(_ values: [String]) -> String {
            "<table:table-row>" + values.map(cell).joined() + "</table:table-row>"
        }
        func table(_ name: String, _ rows: [[String]]) -> String {
            "<table:table table:name=\"\(name)\">" + rows.map(row).joined() + "</table:table>"
        }

        let fods = """
            <?xml version="1.0" encoding="UTF-8"?>
            <office:document
              xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
              xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
              xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
              office:version="1.2"
              office:mimetype="application/vnd.oasis.opendocument.spreadsheet">
              <office:body><office:spreadsheet>
                \(table("DoanhThu", [["thang", "tien"], ["1", "100"], ["2", "200"]]))
                \(table("ChiPhi", [["muc", "so"], ["thue", "7"], ["dien", "9"]]))
              </office:spreadsheet></office:body>
            </office:document>
            """
        let source = root + "/bang.fods"
        try Data(fods.utf8).write(to: URL(fileURLWithPath: source))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: soffice)
        process.arguments = ["--headless", "--convert-to", "xlsx", "--outdir", root, source]
        // Hồ sơ người dùng riêng: hai lần chạy song song dùng chung hồ sơ sẽ tranh nhau.
        process.environment = ProcessInfo.processInfo.environment
            .merging(["HOME": root]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let out = root + "/bang.xlsx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không chuyển được tệp hai sheet")
        }
        return out
    }
}
