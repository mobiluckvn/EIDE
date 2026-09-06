import XCTest
@testable import GEditorCore

/// Bài kiểm cho việc GHI NGƯỢC vào `.xlsx`.
///
/// Vòng tròn đầy đủ: LibreOffice dựng tệp → bộ đọc của ta đọc ra lưới → sửa vài ô → bộ ghi của
/// ta ghi ra tệp mới → **LibreOffice đọc lại tệp ấy**. Vế cuối là vế quan trọng nhất: tự đọc
/// lại bằng chính bộ đọc của mình chỉ chứng minh hai nửa của ta khớp nhau, không chứng minh
/// Excel mở được.
final class XLSXWriterTests: XCTestCase {

    // MARK: - Vòng tròn qua LibreOffice

    func testSUAOroiGHI_LIBREOFFICEdocLaiVANdungGIATRI() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSX(root, """
            ten,so,ghi chu
            An,10,alpha
            Binh,20,beta
            Cuong,30,gamma
            """)

        let reader = try XLSXReader(path: source)
        let sheet = reader.sheets[0]
        let before = try reader.grid(of: sheet)

        // Sửa ba ô, mỗi ô một KIỂU khác nhau: chữ, số, và chữ có ký tự phải thoát trong XML.
        var after = before.rows
        after[1][0] = "Nguyễn An"
        after[2][1] = "999"
        after[3][2] = "a < b & c > d \"trích\""

        let changes = try XLSXWriter.changes(from: before.rows, to: after)
        XCTAssertEqual(changes.count, 3, "tìm sai số ô đã đổi: \(changes)")

        let out = root + "/da-sua.xlsx"
        try XLSXWriter.write(source: source, sheet: sheet, changes: changes, to: out)

        // Đối chứng NGOÀI: bắt LibreOffice đọc tệp vừa ghi rồi xuất ra CSV.
        let csv = try docCsvBangLibreOffice(root, out)
        XCTAssertTrue(csv.contains("Nguyễn An"), "LibreOffice không thấy ô chữ đã sửa:\n\(csv)")
        XCTAssertTrue(csv.contains("999"), "LibreOffice không thấy ô số đã sửa:\n\(csv)")
        XCTAssertTrue(csv.contains("a < b & c > d"), "ô có ký tự đặc biệt sai:\n\(csv)")
        // Và những ô KHÔNG sửa phải còn nguyên.
        XCTAssertTrue(csv.contains("Binh"), "ô không sửa bị mất:\n\(csv)")
        XCTAssertTrue(csv.contains("gamma") || csv.contains("beta"), "mất dữ liệu cũ:\n\(csv)")
    }

    func testGHINGUOCkhongDUNGtoiPHANcònLAIcuaTEP() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSX(root, "a,b\n1,2")

        let reader = try XLSXReader(path: source)
        var after = try reader.grid(of: reader.sheets[0]).rows
        after[1][0] = "999"

        let out = root + "/da-sua.xlsx"
        try XLSXWriter.write(
            source: source, sheet: reader.sheets[0],
            changes: try XLSXWriter.changes(from: try reader.grid(of: reader.sheets[0]).rows,
                                            to: after),
            to: out)

        // Mọi mục KHÁC sheet phải giữ nguyên TỪNG BYTE. Đây là lời hứa trung tâm của bộ ghi:
        // định dạng, biểu đồ, ảnh nhúng, thuộc tính tài liệu — kể cả phần ta không hiểu.
        let old = try ZipArchive(path: source)
        let new = try ZipArchive(path: out)
        let sheetPath = reader.sheets[0].path
        XCTAssertEqual(Set(old.entries.map(\.path)), Set(new.entries.map(\.path)),
                       "danh sách mục trong tệp đã đổi")
        for entry in old.entries where entry.path != sheetPath && !entry.isDirectory {
            let a = try old.data(for: entry)
            let b = try new.data(named: entry.path)
            XCTAssertEqual(a, b, "mục «\(entry.path)» bị đổi dù không ai sửa nó")
        }
    }

    func testTHEMboTHEMhangTHIchoiTUCHOI() throws {
        // Thêm/xoá hàng chưa ghi ngược được. Phải NÓI RA, không được ghi một tệp thiếu hàng rồi
        // để người dùng tự phát hiện.
        let old = [["a"], ["1"]]
        let new = [["a"], ["1"], ["2"]]
        XCTAssertThrowsError(try XLSXWriter.changes(from: old, to: new)) { error in
            XCTAssertEqual(error as? XLSXWriter.Failure, .shapeChanged(was: 2, now: 3))
        }
    }

    // MARK: - Nhánh thuần tính toán

    func testCHIsoOtraVeThamChieu() {
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 0), "A1")
        XCTAssertEqual(XLSXWriter.cellReference(row: 4, column: 2), "C5")
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 25), "Z1")
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 26), "AA1")
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 27), "AB1")
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 51), "AZ1")
        XCTAssertEqual(XLSXWriter.cellReference(row: 0, column: 52), "BA1")
        // Vòng tròn với bộ đọc: hai hàm phải là nghịch đảo của nhau.
        for column in [0, 1, 25, 26, 27, 51, 52, 700] {
            let reference = XLSXWriter.cellReference(row: 3, column: column)
            XCTAssertEqual(XLSXReader.columnIndex(ofReference: reference), column,
                           "«\(reference)» đọc ngược ra sai cột")
        }
    }

    func testSOhayCHUOI_maCHUOIsoKHONGbiGhiThanhSO() {
        XCTAssertTrue(XLSXWriter.looksNumeric("10"))
        XCTAssertTrue(XLSXWriter.looksNumeric("-2.5"))
        XCTAssertTrue(XLSXWriter.looksNumeric("0"))
        XCTAssertTrue(XLSXWriter.looksNumeric("0.5"))
        // `"0123"` là MÃ, không phải số — ghi thành số thì mất số 0 đứng đầu, đúng cái bẫy đã
        // gặp với `SOBAODANH` trong phiên phân tích điểm thi.
        XCTAssertFalse(XLSXWriter.looksNumeric("0123"))
        XCTAssertFalse(XLSXWriter.looksNumeric("01000001"))
        // `Double(...)` nhận cả hai chuỗi dưới đây, nhưng ghi chúng vào ô số cho ra thứ người
        // dùng không gõ.
        XCTAssertFalse(XLSXWriter.looksNumeric("1e5"))
        XCTAssertFalse(XLSXWriter.looksNumeric("Infinity"))
        XCTAssertFalse(XLSXWriter.looksNumeric(""))
        XCTAssertFalse(XLSXWriter.looksNumeric("12a"))
    }

    func testGIUNGUYENchiSoDINHDANGcuaOcu() {
        // Bỏ `s` đi thì một ô ngày đang hiện 15/01/2025 sẽ thành 45672 sau khi sửa ô bên cạnh.
        let xml = XLSXWriter.cellXML(reference: "B2", style: "3", value: "x")
        XCTAssertTrue(xml.contains("s=\"3\""), "mất chỉ số định dạng: \(xml)")
        XCTAssertTrue(xml.contains("t=\"inlineStr\""))
        // Không có `s` thì cũng không được bịa ra.
        XCTAssertFalse(XLSXWriter.cellXML(reference: "B2", style: nil, value: "x").contains(" s="))
    }

    func testOTRONGtrongTEPvanCHENduocDUNGTHUTUcot() throws {
        // Hàng chỉ có ô A và C; sửa ô B thì ô mới phải chèn GIỮA hai ô ấy. Excel đòi ô trong
        // một hàng sắp tăng dần, và sắp sai làm nó báo tệp hỏng.
        let rowText = "<row r=\"1\"><c r=\"A1\"><v>1</v></c><c r=\"C1\"><v>3</v></c></row>"
        let out = try XLSXWriter.replaceCell(in: rowText, row: 0, column: 1, value: "2")
        let a = out.range(of: "r=\"A1\"")!, b = out.range(of: "r=\"B1\"")!, c = out.range(of: "r=\"C1\"")!
        XCTAssertLessThan(a.lowerBound, b.lowerBound)
        XCTAssertLessThan(b.lowerBound, c.lowerBound)
    }

    func testHANGTRONGkhongCoTRONGTEP_nenPHAIdocTHEOthuocTinhR() throws {
        // Hàng 2 vắng mặt hoàn toàn — chuyện bình thường trong XLSX. Đếm theo thứ tự xuất hiện
        // sẽ coi `<row r="3">` là hàng thứ hai, và ghi giá trị vào NHẦM HÀNG.
        let xml = "<sheetData><row r=\"1\"><c r=\"A1\"/></row><row r=\"3\"><c r=\"A3\"/></row></sheetData>"
        let ranges = try XLSXWriter.rowRanges(in: xml)
        XCTAssertEqual(Set(ranges.keys), [0, 2], "khoá hàng sai: \(ranges.keys.sorted())")
    }

    // MARK: - Trợ giúp

    func fixtureRootPublic() throws -> String { try fixtureRoot() }
    func dungXLSXPublic(_ root: String, _ csv: String) throws -> String { try dungXLSX(root, csv) }
    func docCsvBangLibreOfficePublic(_ root: String, _ x: String) throws -> String {
        try docCsvBangLibreOffice(root, x)
    }

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-xlsxw-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    private func dungXLSX(_ root: String, _ csv: String) throws -> String {
        try chay(root, ["--convert-to", "xlsx"], input: root + "/bang.csv", body: csv + "\n")
        return root + "/bang.xlsx"
    }

    /// Bắt LibreOffice đọc một `.xlsx` rồi xuất ra CSV — đối chứng NGOÀI.
    private func docCsvBangLibreOffice(_ root: String, _ xlsx: String) throws -> String {
        let outDir = root + "/doc-lai"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try chayLenh(root, ["--headless", "--convert-to", "csv", "--outdir", outDir, xlsx])
        let name = ((xlsx as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".csv"
        let path = (outDir as NSString).appendingPathComponent(name)
        guard let data = FileManager.default.contents(atPath: path) else {
            throw XCTSkip("LibreOffice không đọc lại được tệp vừa ghi")
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func chay(
        _ root: String, _ arguments: [String], input: String, body: String
    ) throws {
        try Data(body.utf8).write(to: URL(fileURLWithPath: input))
        try chayLenh(root, ["--headless"] + arguments + ["--outdir", root, input])
    }

    private func chayLenh(_ root: String, _ arguments: [String]) throws {
        let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: soffice),
                          "không có LibreOffice trên máy này")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: soffice)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
            .merging(["HOME": root]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
    }
}

// MARK: - Thêm và bớt hàng ở cuối bảng

extension XLSXWriterTests {

    func testTHEMhangOCUOI_LIBREOFFICEdocLaiVANthay() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSXPublic(root, "ten,so\nAn,10\nBinh,20")

        let reader = try XLSXReader(path: source)
        let sheet = reader.sheets[0]
        var rows = try reader.grid(of: sheet).rows
        rows.append(["Cuong", "30"])
        rows.append(["Dung", "40"])

        let diff = try XLSXWriter.diff(from: try reader.grid(of: sheet).rows, to: rows)
        XCTAssertEqual(diff.appended.count, 2, "không nhận ra hai hàng thêm vào")
        XCTAssertTrue(diff.changes.isEmpty, "không ô nào đổi mà vẫn báo có: \(diff.changes)")

        let out = root + "/da-them.xlsx"
        try XLSXWriter.write(source: source, sheet: sheet, diff: diff, to: out)

        let csv = try docCsvBangLibreOfficePublic(root, out)
        XCTAssertTrue(csv.contains("Cuong"), "LibreOffice không thấy hàng mới:\n\(csv)")
        XCTAssertTrue(csv.contains("Dung"), "LibreOffice không thấy hàng mới:\n\(csv)")
        XCTAssertTrue(csv.contains("An"), "mất hàng cũ:\n\(csv)")

        // Bộ đọc của ta cũng phải thấy đúng năm hàng.
        XCTAssertEqual(try XLSXReader(path: out).firstGrid().rows.count, 5)
    }

    func testBOThangOCUOI() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSXPublic(root, "ten,so\nAn,10\nBinh,20\nCuong,30")

        let reader = try XLSXReader(path: source)
        let sheet = reader.sheets[0]
        let before = try reader.grid(of: sheet).rows
        let after = Array(before.dropLast())

        let diff = try XLSXWriter.diff(from: before, to: after)
        XCTAssertEqual(diff.truncated, 1)

        let out = root + "/da-bot.xlsx"
        try XLSXWriter.write(source: source, sheet: sheet, diff: diff, to: out)

        let grid = try XLSXReader(path: out).firstGrid()
        XCTAssertEqual(grid.rows.count, 3, "số hàng sau khi cắt sai")
        let csv = try docCsvBangLibreOfficePublic(root, out)
        XCTAssertFalse(csv.contains("Cuong"), "hàng đã xoá vẫn còn:\n\(csv)")
        XCTAssertTrue(csv.contains("Binh"), "cắt nhầm hàng:\n\(csv)")
    }

    func testCHENhangOGIUAthiVANtuCHOI() throws {
        // Chèn ở giữa làm mọi hàng sau đổi số hiệu, mà số hiệu hàng còn nằm trong công thức,
        // vùng ô gộp, định dạng có điều kiện. `diff` chỉ nhận thêm/bớt ở CUỐI, nên một thay đổi
        // ở giữa sẽ hiện ra thành "cả loạt ô đổi" — vẫn ghi được, nhưng KHÔNG phải chèn hàng.
        //
        // Bài này chốt hành vi ấy để nó không âm thầm đổi: `changes` (bản hẹp) vẫn từ chối.
        let old = [["a"], ["1"], ["2"]]
        let new = [["a"], ["MOI"], ["1"], ["2"]]
        XCTAssertThrowsError(try XLSXWriter.changes(from: old, to: new)) { error in
            XCTAssertEqual(error as? XLSXWriter.Failure, .shapeChanged(was: 3, now: 4))
        }
    }
}
