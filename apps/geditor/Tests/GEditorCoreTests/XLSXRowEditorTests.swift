import XCTest
@testable import GEditorCore

/// Bài kiểm chèn/xoá hàng ở GIỮA bảng — phép sửa nguy hiểm nhất của cả mảng này.
///
/// Vòng tròn ra ngoài: LibreOffice dựng tệp CÓ CÔNG THỨC → ta chèn/xoá hàng → **LibreOffice
/// tính lại công thức**. Vế cuối là vế duy nhất chứng minh tham chiếu đã dịch đúng: một công
/// thức trỏ sai vẫn cho ra một con số, và con số ấy trông y như một kết quả thật.
final class XLSXRowEditorTests: XCTestCase {

    // MARK: - Suy ra phép sửa từ hai lưới

    func testCHENmotHANGoGIUA() {
        let old = [["a"], ["1"], ["2"], ["3"]]
        let new = [["a"], ["1"], ["MOI"], ["2"], ["3"]]
        let plan = XLSXRowEditor.plan(from: old, to: new)
        XCTAssertEqual(plan.shift, .init(at: 2, deleted: 0, inserted: 1))
        XCTAssertEqual(plan.inserted, [["MOI"]])
    }

    func testXOAmotHANGoGIUA() {
        let old = [["a"], ["1"], ["2"], ["3"]]
        let new = [["a"], ["1"], ["3"]]
        let plan = XLSXRowEditor.plan(from: old, to: new)
        XCTAssertEqual(plan.shift, .init(at: 2, deleted: 1, inserted: 0))
        XCTAssertTrue(plan.inserted.isEmpty)
    }

    func testCUNGsoHANGthiKHONGphaiChenXoa() {
        // Sửa một ô KHÔNG được diễn giải thành chèn+xoá — nếu không thì mọi công thức bị dịch
        // vô cớ, và tệp đổi ở hàng nghìn chỗ cho một thay đổi một ô.
        let old = [["a"], ["1"], ["2"]]
        let new = [["a"], ["X"], ["2"]]
        let plan = XLSXRowEditor.plan(from: old, to: new)
        XCTAssertTrue(plan.shift.isEmpty, "sửa ô lại bị coi là chèn/xoá hàng")
        XCTAssertEqual(plan.changes.count, 1)
    }

    // MARK: - Vòng tròn qua LibreOffice, có CÔNG THỨC

    func testCHENhang_LIBREOFFICEtinhLAIcongThucDUNG() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }

        // Cột B là công thức nhân đôi cột A.
        let source = try dungXLSXcoCongThuc(root, rows: [10, 20, 30])

        let reader = try XLSXReader(path: source)
        let sheet = reader.sheets[0]
        try XLSXRowEditor.checkSafe(archive: try ZipArchive(path: source), sheet: sheet)

        // ĐỐI CHỨNG TRƯỚC: tệp gốc phải tính đúng đã. Không có vế này thì một fixture hỏng sẽ
        // bị đọc thành "bộ dịch tham chiếu sai" — và đi truy nhầm chỗ.
        let goc = try docCsvBangLibreOffice(root, source)
        XCTAssertTrue(goc.contains("60"), "FIXTURE đã hỏng từ đầu, chưa phải lỗi bộ dịch:\n\(goc)")

        var rows = try reader.grid(of: sheet).rows
        // Chèn một hàng dữ liệu vào GIỮA (sau hàng đầu tiên của dữ liệu).
        rows.insert(["5", ""], at: 2)

        let plan = XLSXRowEditor.plan(from: try reader.grid(of: sheet).rows, to: rows)
        XCTAssertEqual(plan.shift.inserted, 1, "không nhận ra phép chèn: \(plan.shift)")

        let archive = try ZipArchive(path: source)
        let original = try XCTUnwrap(archive.data(named: sheet.path))
        let edited = try XLSXRowEditor.apply(plan.shift, insertedRows: plan.inserted, to: original)
        let out = root + "/da-chen.xlsx"
        try ZipWriter.rewrite(archive, replacing: [sheet.path: edited], to: out)

        // Bộ đọc của ta thấy đúng số hàng và đúng giá trị mới.
        let after = try XLSXReader(path: out).firstGrid()
        XCTAssertEqual(after.rows.count, rows.count, "số hàng sau khi chèn sai")
        XCTAssertEqual(after.rows[2][0], "5", "hàng chèn vào sai chỗ")

        // PHÉP KIỂM THẲNG, và nó phải đứng trước phép kiểm qua LibreOffice.
        //
        // Bản đầu của bài này CHỈ có phép kiểm qua LibreOffice, và nó xanh cả khi bộ dịch công
        // thức bị tắt hoàn toàn — vì LibreOffice đọc giá trị ĐÃ LƯU SẴN trong ô (`<v>`) chứ
        // không tính lại. Bài kiểm mang tên "tính lại công thức" mà không tính lại gì.
        let xmlSau = String(
            decoding: try XCTUnwrap(ZipArchive(path: out).data(named: sheet.path)), as: UTF8.self)
        // Fixture có ba hàng dữ liệu (công thức ở B2, B3, B4). Chèn một hàng vào TRƯỚC hàng 3
        // thì hai công thức dưới phải trôi xuống: A3→A4 và A4→A5. Công thức trên chỗ chèn thì
        // giữ nguyên — nếu nó cũng đổi thì bộ dịch đang dịch cả những chỗ không được đụng.
        let congThuc = Self.congThucTrong(xmlSau)
        XCTAssertEqual(congThuc, ["A2*2", "A4*2", "A5*2"],
                       "công thức chưa được dịch theo hàng: \(congThuc)")

        // ĐỐI CHỨNG NGOÀI: LibreOffice TÍNH LẠI công thức. Nếu tham chiếu bị dịch sai, cột B
        // sẽ ra số khác — và đó là kiểu hỏng không bộ đọc nào của ta thấy được.
        let csv = try docCsvBangLibreOffice(root, out)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Hàng cuối cùng của dữ liệu: A=30, B phải = 60.
        XCTAssertTrue(lines.contains { $0.hasPrefix("30,") && $0.contains("60") },
                      "công thức trỏ sai sau khi chèn hàng:\n\(csv)")
        // Hàng vừa chèn chưa có công thức nên B rỗng — nhưng A phải là 5.
        XCTAssertTrue(lines.contains { $0.hasPrefix("5,") }, "hàng chèn vào mất:\n\(csv)")
    }

    func testXOAhang_LIBREOFFICEtinhLAIcongThucDUNG() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSXcoCongThuc(root, rows: [10, 20, 30])

        let reader = try XLSXReader(path: source)
        let sheet = reader.sheets[0]
        // Cùng đối chứng trước như bài chèn: fixture phải tính đúng trước đã.
        XCTAssertTrue(try docCsvBangLibreOffice(root, source).contains("60"),
                      "FIXTURE đã hỏng từ đầu")

        var rows = try reader.grid(of: sheet).rows
        rows.remove(at: 2)                    // xoá hàng dữ liệu thứ hai (A=20)

        let plan = XLSXRowEditor.plan(from: try reader.grid(of: sheet).rows, to: rows)
        XCTAssertEqual(plan.shift.deleted, 1)

        let archive = try ZipArchive(path: source)
        let original = try XCTUnwrap(archive.data(named: sheet.path))
        let edited = try XLSXRowEditor.apply(plan.shift, insertedRows: [], to: original)
        let out = root + "/da-xoa.xlsx"
        try ZipWriter.rewrite(archive, replacing: [sheet.path: edited], to: out)

        // Xoá hàng 3 (A=20) thì công thức của hàng 4 trôi lên hàng 3: A4*2 → A3*2.
        let xmlSau = String(
            decoding: try XCTUnwrap(ZipArchive(path: out).data(named: sheet.path)), as: UTF8.self)
        let congThuc = Self.congThucTrong(xmlSau)
        XCTAssertEqual(congThuc, ["A2*2", "A3*2"],
                       "công thức chưa dịch theo sau khi xoá hàng: \(congThuc)")

        let csv = try docCsvBangLibreOffice(root, out)
        XCTAssertFalse(csv.contains("20,"), "hàng đã xoá vẫn còn:\n\(csv)")
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertTrue(lines.contains { $0.hasPrefix("30,") && $0.contains("60") },
                      "công thức trỏ sai sau khi xoá hàng:\n\(csv)")
    }

    // MARK: - Cổng an toàn

    func testGAPcauTRUCchuaDICHduocTHIchoiTUCHOI() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSXcoCongThuc(root, rows: [1, 2])

        // Nhét một thẻ nằm trong danh sách "chưa dịch được" vào sheet, rồi đòi cổng chặn.
        let archive = try ZipArchive(path: source)
        let sheet = try XLSXReader(path: source).sheets[0]
        var xml = String(decoding: try XCTUnwrap(archive.data(named: sheet.path)), as: UTF8.self)
        xml = xml.replacingOccurrences(
            of: "</worksheet>", with: "<sortState ref=\"A1:B9\"/></worksheet>")
        let poisoned = root + "/co-sortState.xlsx"
        try ZipWriter.rewrite(archive, replacing: [sheet.path: Array(xml.utf8)], to: poisoned)

        XCTAssertThrowsError(
            try XLSXRowEditor.checkSafe(
                archive: try ZipArchive(path: poisoned),
                sheet: try XLSXReader(path: poisoned).sheets[0])
        ) { error in
            XCTAssertEqual(error as? XLSXRowEditor.Failure, .unsupportedConstruct("sortState"))
        }
    }

    func testTEPBINHTHUONGthiCONGchoQUAduoc() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungXLSXcoCongThuc(root, rows: [1, 2])
        // Đối chứng cho bài trên: một cổng chặn hết là cổng vô dụng.
        XCTAssertNoThrow(try XLSXRowEditor.checkSafe(
            archive: try ZipArchive(path: source),
            sheet: try XLSXReader(path: source).sheets[0]))
    }

    // MARK: - Trợ giúp

    /// Mọi nội dung `<f>…</f>` trong một sheet, theo thứ tự.
    ///
    /// Phải soi ĐÚNG công thức, không soi cả tệp. Bản đầu của bài kiểm này hỏi
    /// `xml.contains("A4")` — và nó xanh cả khi bộ dịch công thức bị tắt, vì `A4` cũng là tham
    /// chiếu Ô (`<c r="A4">`) mà phép đánh số lại luôn sinh ra. Một phép kiểm trúng thứ khác
    /// với thứ nó định kiểm thì xanh vô nghĩa.
    static func congThucTrong(_ xml: String) -> [String] {
        var out: [String] = []
        var cursor = xml.startIndex
        while let open = xml.range(of: "<f>", range: cursor ..< xml.endIndex) {
            guard let close = xml.range(of: "</f>", range: open.upperBound ..< xml.endIndex)
            else { break }
            out.append(String(xml[open.upperBound ..< close.lowerBound]))
            cursor = close.upperBound
        }
        return out
    }

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-rowedit-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    /// Dựng `.xlsx` CÓ CÔNG THỨC: LibreOffice tạo khung, ta tiêm `<f>` vào.
    ///
    /// **Bản đầu dựng fixture bằng `.fods` với `table:formula`, và LibreOffice ĐÃ BỎ QUA nó** —
    /// tệp `.xlsx` sinh ra không có một `<f>` nào. Ba bài kiểm "công thức dịch đúng chưa" vì thế
    /// xanh trên một tệp không có công thức nào để mà dịch; chúng xanh cả khi bộ dịch bị tắt
    /// hoàn toàn.
    ///
    /// Nên: lấy khung tệp do LibreOffice ghi (cấu trúc thật của một `.xlsx`), rồi tiêm công
    /// thức vào bằng `ZipWriter` của chính sản phẩm. Fixture do ta soạn một phần — và đúng vì
    /// thế mà bài kiểm PHẢI có chốt "fixture tính đúng trước đã".
    private func dungXLSXcoCongThuc(_ root: String, rows: [Int]) throws -> String {
        let csv = (["a,gap doi"] + rows.map { "\($0)," }).joined(separator: "\n") + "\n"
        let source = root + "/bang.csv"
        try Data(csv.utf8).write(to: URL(fileURLWithPath: source))
        try chay(root, ["--headless", "--convert-to", "xlsx", "--outdir", root, source])

        let khung = root + "/bang.xlsx"
        guard FileManager.default.fileExists(atPath: khung) else {
            throw XCTSkip("LibreOffice không dựng được khung .xlsx")
        }

        // Tiêm `<f>` vào cột B của từng hàng dữ liệu.
        let archive = try ZipArchive(path: khung)
        let sheetPath = try XLSXReader(path: khung).sheets[0].path
        var xml = String(decoding: try XCTUnwrap(archive.data(named: sheetPath)), as: UTF8.self)
        for index in rows.indices.reversed() {
            let line = index + 2
            let cell = "<c r=\"B\(line)\"><f>A\(line)*2</f><v>\(rows[index] * 2)</v></c>"
            guard let open = xml.range(of: "<row r=\"\(line)\""),
                  let close = xml.range(of: "</row>", range: open.upperBound ..< xml.endIndex)
            else { continue }
            xml.insert(contentsOf: cell, at: close.lowerBound)
        }
        let out = root + "/co-cong-thuc.xlsx"
        try ZipWriter.rewrite(archive, replacing: [sheetPath: Array(xml.utf8)], to: out)
        return out
    }

    /// Bắt LibreOffice đọc `.xlsx` và **TÍNH LẠI** mọi công thức, rồi xuất ra CSV.
    ///
    /// `fullCalcOnLoad="1"` trong `workbook.xml` là thứ bắt nó tính lại. Không có cờ ấy thì mọi
    /// trình bảng tính đều dùng giá trị đã lưu sẵn trong ô — nhanh hơn, và đúng trong đời
    /// thường, nhưng làm mọi bài kiểm "công thức có dịch đúng không" trở thành vô nghĩa.
    private func docCsvBangLibreOffice(_ root: String, _ xlsx: String) throws -> String {
        let forced = try batTinhLai(xlsx, in: root)
        let outDir = root + "/doc-lai-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try chay(root, ["--headless", "--convert-to", "csv", "--outdir", outDir, forced])
        let name = ((forced as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".csv"
        guard let data = FileManager.default.contents(
            atPath: (outDir as NSString).appendingPathComponent(name)) else {
            XCTFail("LibreOffice KHÔNG mở được tệp vừa ghi")
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// Chép tệp ra một bản có `fullCalcOnLoad="1"`, dùng chính `ZipWriter` của sản phẩm.
    private func batTinhLai(_ xlsx: String, in root: String) throws -> String {
        let archive = try ZipArchive(path: xlsx)
        guard let data = try archive.data(named: "xl/workbook.xml") else { return xlsx }
        var text = String(decoding: data, as: UTF8.self)
        if let range = text.range(of: "<calcPr") {
            guard let close = text.range(of: ">", range: range.upperBound ..< text.endIndex)
            else { return xlsx }
            text.replaceSubrange(range.lowerBound ..< close.upperBound,
                                 with: "<calcPr fullCalcOnLoad=\"1\"/>")
        } else if let close = text.range(of: "</workbook>") {
            text.replaceSubrange(close.lowerBound ..< close.lowerBound,
                                 with: "<calcPr fullCalcOnLoad=\"1\"/>")
        }
        let out = root + "/tinh-lai-\(UUID().uuidString).xlsx"
        try ZipWriter.rewrite(archive, replacing: ["xl/workbook.xml": Array(text.utf8)], to: out)
        return out
    }

    private func chay(_ root: String, _ arguments: [String]) throws {
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
