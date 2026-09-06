import XCTest
@testable import GEditorCore

/// Bài kiểm ghi ngược `.pptx`. Vòng tròn ra ngoài như hai bộ ghi kia.
final class PPTXWriterTests: XCTestCase {

    func testSUAtieuDeSLIDEroiGHI_LIBREOFFICEdocLaiVANthayCHUmoi() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungPPTX(root, ["Slide mot", "Slide hai", "Slide ba"])

        let original = try PPTXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("Slide hai") }) else {
            return XCTFail("không thấy slide cần sửa:\n\(original.markdown)")
        }
        lines[index] = "## 2. DA SUA slide hai"

        let changes = try PPTXWriter.changes(from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(changes.count, 1, "tìm sai số đoạn đã đổi: \(changes)")
        // Tiền tố `"## 2. "` phải bị bỏ — ghi cả nó vào tệp thì slide hiện ra "## 2. DA SUA…".
        XCTAssertEqual(changes.first?.text, "DA SUA slide hai")
        // Và phải sửa đúng tệp slide THỨ HAI.
        XCTAssertTrue(changes.first?.file.contains("slide") == true, "sai tệp: \(changes)")

        let out = root + "/da-sua.pptx"
        try PPTXWriter.write(source: source, changes: changes, to: out)

        let text = try docBangLibreOffice(root, out)
        XCTAssertTrue(text.contains("DA SUA slide hai"), "LibreOffice không thấy chữ mới:\n\(text)")
        XCTAssertFalse(text.contains("## 2."), "tiền tố Markdown lọt vào tệp:\n\(text)")
        // Slide không sửa phải còn nguyên.
        XCTAssertTrue(text.contains("Slide mot"), "mất slide không sửa:\n\(text)")
        XCTAssertTrue(text.contains("Slide ba"), "mất slide không sửa:\n\(text)")
    }

    func testSUAdongTIEUDEdoTASINHraTHIchoiTUCHOI() {
        // Slide không có chữ nào thì dòng "## Slide 2" là do GEditor sinh ra, không ứng với
        // `<a:p>` nào. Ghi bừa vào một đoạn nào đó là dựng chữ ở chỗ slide vốn trống.
        let presentation = PPTXReader.Presentation(
            slides: [], markdown: "## Slide 2\n",
            lineOwners: [.init(file: nil, paragraph: nil, prefixLength: 0)],
            outline: [.init(role: .title, slide: 0, range: 0 ..< 11)])
        XCTAssertThrowsError(
            try PPTXWriter.changes(from: presentation, to: "## Slide HAI\n")
        ) { error in
            XCTAssertEqual(error as? PPTXWriter.Failure, .notEditable(line: 0))
        }
    }

    func testDEMdoanKHONGnhamVOIthuocTinhDoan() {
        // `<a:pPr>` cũng bắt đầu bằng `<a:p` — cùng cái bẫy với `<w:pPr>` của Word.
        let xml = "<p:txBody><a:p><a:pPr algn=\"ctr\"/><a:r><a:t>A</a:t></a:r></a:p>"
            + "<a:p/><a:p><a:r><a:t>B</a:t></a:r></a:p></p:txBody>"
        XCTAssertEqual(PPTXWriter.paragraphRanges(in: xml).count, 3)
    }

    func testCHUmoiVAOrunDAUvaGIUthuocTinh() {
        let paragraph = "<a:p><a:pPr algn=\"ctr\"/>"
            + "<a:r><a:rPr b=\"1\"/><a:t>Một </a:t></a:r>"
            + "<a:r><a:t>câu</a:t></a:r></a:p>"
        let out = PPTXWriter.replaceText(in: paragraph, with: "Câu khác")
        XCTAssertTrue(out.contains(">Câu khác</a:t>"), "chữ mới không vào run đầu: \(out)")
        XCTAssertTrue(out.contains("<a:t></a:t>"), "run thứ hai chưa rỗng: \(out)")
        XCTAssertTrue(out.contains("algn=\"ctr\""), "mất canh lề đoạn: \(out)")
        XCTAssertTrue(out.contains("b=\"1\""), "mất định dạng run đầu: \(out)")
    }

    // MARK: - Trợ giúp

    func fixtureRootPublic() throws -> String { try fixtureRoot() }
    func docBangLibreOfficePublic(_ root: String, _ p: String) throws -> String {
        try docBangLibreOffice(root, p)
    }

    /// Bản trình chiếu có TIÊU ĐỀ và hai dòng nội dung — cần cho bài thêm/xoá dòng.
    func dungPPTXcoNoiDung(_ root: String) throws -> String {
        let fodp = """
            <?xml version="1.0" encoding="UTF-8"?>
            <office:document xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
              xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
              xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
              xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
              xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
              office:version="1.3" office:mimetype="application/vnd.oasis.opendocument.presentation">
              <office:body><office:presentation>
              <draw:page draw:name="A" draw:master-page-name="Default">
                <draw:frame presentation:class="title" svg:width="20cm" svg:height="3cm" \
            svg:x="2cm" svg:y="2cm"><draw:text-box><text:p>Tieu de slide</text:p></draw:text-box>\
            </draw:frame>
                <draw:frame presentation:class="outline" svg:width="20cm" svg:height="8cm" \
            svg:x="2cm" svg:y="6cm"><draw:text-box><text:p>y mot</text:p>\
            <text:p>y hai</text:p></draw:text-box></draw:frame>
              </draw:page>
              </office:presentation></office:body>
            </office:document>
            """
        let source = root + "/noi-dung.fodp"
        try Data(fodp.utf8).write(to: URL(fileURLWithPath: source))
        try chay(root, ["--headless", "--convert-to", "pptx", "--outdir", root, source])
        let out = root + "/noi-dung.pptx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không dựng được .pptx có nội dung")
        }
        return out
    }

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-pptxw-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    private func dungPPTX(_ root: String, _ titles: [String]) throws -> String {
        let pages = titles.map { title in
            """
              <draw:page draw:name="\(title)" draw:master-page-name="Default">
                <draw:frame presentation:class="title" svg:width="20cm" svg:height="3cm" \
            svg:x="2cm" svg:y="2cm"><draw:text-box><text:p>\(title)</text:p></draw:text-box>\
            </draw:frame>
              </draw:page>
            """
        }.joined(separator: "\n")
        let fodp = """
            <?xml version="1.0" encoding="UTF-8"?>
            <office:document xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
              xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
              xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
              xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
              xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
              office:version="1.3" office:mimetype="application/vnd.oasis.opendocument.presentation">
              <office:body><office:presentation>
            \(pages)
              </office:presentation></office:body>
            </office:document>
            """
        let source = root + "/ban.fodp"
        try Data(fodp.utf8).write(to: URL(fileURLWithPath: source))
        try chay(root, ["--headless", "--convert-to", "pptx", "--outdir", root, source])
        let out = root + "/ban.pptx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không dựng được .pptx")
        }
        return out
    }

    /// Bắt LibreOffice đọc `.pptx` rồi xuất ra **`.fodp`** — ODP dạng XML phẳng.
    ///
    /// KHÔNG dùng `txt`: Impress không có bộ xuất văn bản thuần, và lệnh ấy hỏng ngay cả với
    /// tệp gốc chưa qua bộ ghi nào. Bản đầu của bài kiểm này dùng `txt` và vì thế **tự bỏ qua
    /// chính nó** — xanh mà không kiểm gì, đúng loại bài kiểm tệ nhất. `fodp` là XML nên chữ
    /// trong đó tìm được, và nó chứng minh LibreOffice mở được tệp ta vừa ghi.
    ///
    /// Không mở được thì ĐỎ, không `XCTSkip`: skip ở đây là giấu đi đúng thứ bài kiểm tồn tại
    /// để bắt.
    private func docBangLibreOffice(_ root: String, _ pptx: String) throws -> String {
        let outDir = root + "/doc-lai"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try chay(root, ["--headless", "--convert-to", "fodp", "--outdir", outDir, pptx])
        let name = ((pptx as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".fodp"
        guard let data = FileManager.default.contents(
            atPath: (outDir as NSString).appendingPathComponent(name)) else {
            XCTFail("LibreOffice KHÔNG mở được tệp .pptx vừa ghi — bộ ghi hỏng")
            return ""
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

// MARK: - Thêm và xoá dòng trong slide

extension PPTXWriterTests {

    func testTHEMdongVAOslide_LIBREOFFICEdocLaiVANthay() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungPPTXcoNoiDung(root)

        let original = try PPTXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.hasPrefix("- ") }) else {
            return XCTFail("slide không có dòng nội dung nào:\n\(original.markdown)")
        }
        lines.insert("- dong MOI them vao", at: index + 1)

        let plan = try XCTUnwrap(
            try PPTXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n")))
        XCTAssertEqual(plan.insertedTexts, ["dong MOI them vao"], "tiền tố «- » chưa bị bỏ")
        XCTAssertTrue(plan.file.contains("slides/slide"), "sai tệp slide: \(plan.file)")

        let out = root + "/da-them.pptx"
        let archive = try ZipArchive(path: source)
        let edited = try PPTXParagraphEditor.apply(
            plan, to: try XCTUnwrap(archive.data(named: plan.file)))
        try ZipWriter.rewrite(archive, replacing: [plan.file: edited], to: out)

        let text = try docBangLibreOfficePublic(root, out)
        XCTAssertTrue(text.contains("dong MOI them vao"),
                      "LibreOffice không thấy dòng mới:\n\(text)")
        // Số slide phải không đổi.
        XCTAssertEqual(try PPTXReader.read(path: out).slides.count, original.slides.count)
    }

    func testXOAdongTRONGslide() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungPPTXcoNoiDung(root)

        let original = try PPTXReader.read(path: source)
        let lines = original.markdown.components(separatedBy: "\n")
            .filter { !$0.contains("y hai") }

        let plan = try XCTUnwrap(
            try PPTXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n")))
        XCTAssertEqual(plan.deletedParagraphs.count, 1, "tìm sai số dòng bị xoá: \(plan)")

        let out = root + "/da-xoa.pptx"
        let archive = try ZipArchive(path: source)
        let edited = try PPTXParagraphEditor.apply(
            plan, to: try XCTUnwrap(archive.data(named: plan.file)))
        try ZipWriter.rewrite(archive, replacing: [plan.file: edited], to: out)

        let again = try PPTXReader.read(path: out)
        XCTAssertFalse(again.markdown.contains("y hai"), "dòng đã xoá vẫn còn:\n\(again.markdown)")
        XCTAssertTrue(again.markdown.contains("y mot"), "xoá nhầm dòng:\n\(again.markdown)")
    }

    func testXOAdongTIEUDEslideTHIchoiTUCHOI() throws {
        let root = try fixtureRootPublic()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungPPTXcoNoiDung(root)

        let original = try PPTXReader.read(path: source)
        // Bỏ dòng `## 1. …` nghĩa là bỏ cả một SLIDE — việc ấy phải dựng thêm/bớt tệp XML, quan
        // hệ, và mục trong danh sách slide.
        let lines = original.markdown.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("## 1.") }

        XCTAssertThrowsError(
            try PPTXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n"))
        ) { error in
            guard case .slideBoundary = (error as? PPTXParagraphEditor.Failure) else {
                return XCTFail("lỗi sai loại: \(error)")
            }
        }
    }

    func testDONGmoiTHUAKEcaKIEUCHUcuaRUNdau() {
        // Khác Word: trong PowerPoint cỡ chữ và màu nằm ở `<a:rPr>` của từng RUN, không ở kiểu
        // đoạn. Bỏ nó thì dòng mới ra chữ đen cỡ mặc định giữa một slide đã trình bày kỹ.
        let paragraph = "<a:p><a:pPr algn=\"ctr\"/>"
            + "<a:r><a:rPr lang=\"vi\" sz=\"2800\" b=\"1\"/><a:t>A</a:t></a:r></a:p>"
        XCTAssertEqual(PPTXParagraphEditor.properties(of: paragraph), "<a:pPr algn=\"ctr\"/>")
        XCTAssertEqual(PPTXParagraphEditor.runProperties(of: paragraph),
                       "<a:rPr lang=\"vi\" sz=\"2800\" b=\"1\"/>")
    }
}
