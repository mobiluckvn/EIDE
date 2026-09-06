import XCTest
@testable import GEditorCore

/// Bài kiểm ghi ngược `.docx`.
///
/// Vòng tròn ra NGOÀI như `XLSXWriterTests`: LibreOffice dựng tệp → ta đọc → sửa → ta ghi →
/// **LibreOffice đọc lại và xuất ra văn bản**.
final class DOCXWriterTests: XCTestCase {

    func testSUAdoanRoiGHI_LIBREOFFICEdocLaiVANthayCHUmoi() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, """
            # Tiêu đề gốc

            Đoạn thứ nhất chưa sửa.

            Đoạn thứ hai sẽ bị sửa.
            """)

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("Đoạn thứ hai") }) else {
            return XCTFail("không thấy đoạn cần sửa:\n\(original.markdown)")
        }
        lines[index] = "Đoạn thứ hai ĐÃ SỬA — có ký tự < & >."

        let changes = try DOCXWriter.changes(
            from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(changes.count, 1, "tìm sai số đoạn đã đổi: \(changes)")

        let out = root + "/da-sua.docx"
        try DOCXWriter.write(source: source, changes: changes, to: out)

        let text = try docBangLibreOffice(root, out)
        XCTAssertTrue(text.contains("ĐÃ SỬA"), "LibreOffice không thấy chữ mới:\n\(text)")
        XCTAssertTrue(text.contains("< & >"), "ký tự đặc biệt sai:\n\(text)")
        // Đoạn KHÔNG sửa và tiêu đề phải còn nguyên.
        XCTAssertTrue(text.contains("Đoạn thứ nhất chưa sửa"), "mất đoạn không sửa:\n\(text)")
        XCTAssertTrue(text.contains("Tiêu đề gốc"), "mất tiêu đề:\n\(text)")
    }

    func testSUAtieuDeTHIkhongGhiCAdauTHANGvaoTEP() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, "# Tiêu đề gốc\n\nMột đoạn.")

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.hasPrefix("# ") }) else {
            return XCTFail("không thấy tiêu đề:\n\(original.markdown)")
        }
        lines[index] = "# Tiêu đề MỚI"

        let changes = try DOCXWriter.changes(from: original, to: lines.joined(separator: "\n"))
        // Tiền tố `"# "` phải bị bỏ: ghi cả dấu thăng vào tệp thì mở bằng Word sẽ thấy
        // "# Tiêu đề MỚI" in ra như chữ thường.
        XCTAssertEqual(changes.first?.text, "Tiêu đề MỚI",
                       "tiền tố Markdown chưa bị bỏ: \(String(describing: changes.first))")

        let out = root + "/da-sua.docx"
        try DOCXWriter.write(source: source, changes: changes, to: out)
        let text = try docBangLibreOffice(root, out)
        XCTAssertTrue(text.contains("Tiêu đề MỚI"))
        XCTAssertFalse(text.contains("# Tiêu đề"), "dấu thăng lọt vào tệp:\n\(text)")
    }

    func testTHEMdongTHIchoiTUCHOIkemLYDO() throws {
        let document = DOCXReader.Document(
            markdown: "a\n\nb\n", paragraphCount: 2, tableCount: 0,
            lineOwners: [
                .init(paragraph: 0, prefixLength: 0),
                .init(paragraph: nil, prefixLength: 0),
                .init(paragraph: 1, prefixLength: 0),
            ])
        XCTAssertThrowsError(try DOCXWriter.changes(from: document, to: "a\n\nb\nc\n")) { error in
            guard case .lineCountChanged = (error as? DOCXWriter.Failure) else {
                return XCTFail("lỗi sai loại: \(error)")
            }
        }
    }

    func testHANGBANGkhongCOanhXAoTHItuCHOI() {
        // Hàng bảng nay sửa được — nhưng chỉ khi có ánh xạ ô. Không có ánh xạ (tệp lạ, bảng
        // lồng nhau) thì phải từ chối chứ không ghi bừa vào một đoạn nào đó.
        let document = DOCXReader.Document(
            markdown: "| a | b |\n", paragraphCount: 0, tableCount: 1,
            lineOwners: [.init(paragraph: nil, prefixLength: 0)])
        XCTAssertThrowsError(try DOCXWriter.changes(from: document, to: "| x | b |\n")) { error in
            XCTAssertEqual(error as? DOCXWriter.Failure, .notAParagraph(line: 0))
        }
    }

    // MARK: - Nhánh thuần tính toán

    func testDEMdoanKHONGnhamVOIthuocTinhDoan() {
        // `<w:pPr>` và `<w:pStyle>` cũng bắt đầu bằng `<w:p`. Đếm nhầm chúng thành đoạn thì mọi
        // chỉ số đoạn lệch, và bộ ghi sửa vào chỗ khác.
        let xml = "<w:body><w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr>"
            + "<w:r><w:t>A</w:t></w:r></w:p><w:p/><w:p><w:r><w:t>B</w:t></w:r></w:p></w:body>"
        XCTAssertEqual(DOCXWriter.paragraphRanges(in: xml).count, 3)
    }

    func testCHUmoiVAOrunDAUvaLAMRONGcacRunCONlai() throws {
        // Một câu Word thường là nhiều run. Chữ mới vào run đầu, các run sau rỗng — giữ được
        // thuộc tính đoạn và định dạng run đầu, mất định dạng KHÁC NHAU giữa các run.
        let paragraph = "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>"
            + "<w:r><w:rPr><w:b/></w:rPr><w:t>Một </w:t></w:r>"
            + "<w:r><w:t>câu</w:t></w:r></w:p>"
        let out = try DOCXWriter.replaceText(in: paragraph, with: "Câu khác")

        XCTAssertTrue(out.contains(">Câu khác</w:t>"), "chữ mới không vào run đầu: \(out)")
        XCTAssertTrue(out.contains("<w:t></w:t>"), "run thứ hai chưa bị làm rỗng: \(out)")
        // Thuộc tính đoạn và định dạng run đầu phải còn.
        XCTAssertTrue(out.contains("<w:jc w:val=\"center\"/>"), "mất canh lề đoạn: \(out)")
        XCTAssertTrue(out.contains("<w:b/>"), "mất chữ đậm của run đầu: \(out)")
        // `xml:space="preserve"` phải có, nếu không Word cắt khoảng trắng đầu/cuối.
        XCTAssertTrue(out.contains("xml:space=\"preserve\""), "thiếu preserve: \(out)")
    }

    func testDOANRONGvanNHANduocCHUmoi() throws {
        let out = try DOCXWriter.replaceText(in: "<w:p><w:pPr/></w:p>", with: "chữ mới")
        XCTAssertTrue(out.contains("<w:r>"), "không dựng được run: \(out)")
        XCTAssertTrue(out.contains("chữ mới"))
        XCTAssertTrue(out.contains("<w:pPr/>"), "mất thuộc tính đoạn: \(out)")
    }

    // MARK: - Trợ giúp

    func fixtureRootPublic() throws -> String { try fixtureRoot() }
    func dungDOCXPublic(_ root: String, _ md: String) throws -> String { try dungDOCX(root, md) }
    func docBangLibreOfficePublic(_ root: String, _ d: String) throws -> String {
        try docBangLibreOffice(root, d)
    }

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-docxw-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    private func dungDOCX(_ root: String, _ markdown: String) throws -> String {
        let source = root + "/tai-lieu.md"
        try Data((markdown + "\n").utf8).write(to: URL(fileURLWithPath: source))
        try chay(root, ["--headless", "--convert-to", "docx:MS Word 2007 XML",
                        "--infilter=Markdown", "--outdir", root, source])
        let out = root + "/tai-lieu.docx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không dựng được .docx")
        }
        return out
    }

    /// Bắt LibreOffice đọc `.docx` rồi xuất ra văn bản — đối chứng NGOÀI.
    private func docBangLibreOffice(_ root: String, _ docx: String) throws -> String {
        let outDir = root + "/doc-lai"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try chay(root, ["--headless", "--convert-to", "txt:Text (encoded):UTF8",
                        "--outdir", outDir, docx])
        let name = ((docx as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".txt"
        guard let data = FileManager.default.contents(
            atPath: (outDir as NSString).appendingPathComponent(name)) else {
            throw XCTSkip("LibreOffice không đọc lại được tệp vừa ghi")
        }
        return String(decoding: data, as: UTF8.self)
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

// MARK: - Sửa ô trong bảng

extension DOCXWriterTests {

    func testSUAmotOtrongBANG_LIBREOFFICEdocLaiVANthay() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCXPublic(root, """
            Một đoạn mở đầu.

            | Tên | Số |
            |---|---|
            | An | 3 |
            | Bình | 5 |
            """)

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("| An |") }) else {
            return XCTFail("không thấy hàng bảng:\n\(original.markdown)")
        }
        // Sửa ĐÚNG MỘT ô của hàng ấy.
        lines[index] = lines[index].replacingOccurrences(of: "| An |", with: "| Nguyễn An |")

        let changes = try DOCXWriter.changes(from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(changes.count, 1,
                       "phải chỉ ghi ĐÚNG ô đã đổi, không ghi cả hàng: \(changes)")
        XCTAssertEqual(changes.first?.text, "Nguyễn An")

        let out = root + "/da-sua.docx"
        try DOCXWriter.write(source: source, changes: changes, to: out)

        let text = try docBangLibreOfficePublic(root, out)
        XCTAssertTrue(text.contains("Nguyễn An"), "LibreOffice không thấy ô đã sửa:\n\(text)")
        // Ô không sửa và hàng khác phải còn nguyên.
        XCTAssertTrue(text.contains("Bình"), "mất hàng khác:\n\(text)")
        XCTAssertTrue(text.contains("Một đoạn mở đầu"), "mất đoạn ngoài bảng:\n\(text)")
    }

    func testTACHOcuaHANGBANGtrenDAUONGkhongBiTHOAT() {
        XCTAssertEqual(DOCXWriter.tableCells("| a | b |"), ["a", "b"])
        XCTAssertEqual(DOCXWriter.tableCells("| a | b | c |"), ["a", "b", "c"])
        // Ô rỗng vẫn phải giữ chỗ, nếu không thì mọi cột phía sau lệch.
        XCTAssertEqual(DOCXWriter.tableCells("| a |  | c |"), ["a", "", "c"])
        // Dấu ống trong nội dung ô được bộ đọc thoát thành `\|` — tách bừa sẽ cắt ô làm đôi.
        XCTAssertEqual(DOCXWriter.tableCells("| a \\| b | c |"), ["a | b", "c"])
    }

    func testTHEMCOTvaoHANGBANGthiTUCHOI() {
        let document = DOCXReader.Document(
            markdown: "| a | b |\n", paragraphCount: 2, tableCount: 1,
            lineOwners: [.init(paragraph: nil, prefixLength: 0, cells: [0, 1])])
        XCTAssertThrowsError(
            try DOCXWriter.changes(from: document, to: "| a | b | c |\n")
        ) { error in
            XCTAssertEqual(error as? DOCXWriter.Failure, .tableShapeChanged(line: 0))
        }
    }
}
