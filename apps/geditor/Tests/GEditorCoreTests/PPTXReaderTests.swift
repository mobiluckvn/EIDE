import XCTest
@testable import GEditorCore

final class PPTXReaderTests: XCTestCase {

    func testDOCduocSLIDEvaGIUdungTHUTU() throws {
        // Mười hai slide: đủ để bắt lỗi sắp theo CHUỖI, vì khi ấy `slide10` đứng trước `slide2`.
        let titles = (1...12).map { "Tieu de \($0)" }
        let path = try dungPPTX(titles)
        defer { try? FileManager.default.removeItem(
            atPath: (path as NSString).deletingLastPathComponent) }

        let presentation = try PPTXReader.read(path: path)
        XCTAssertEqual(presentation.slides.count, 12, "số slide sai")

        let got = presentation.slides.map(\.title)
        XCTAssertEqual(got, titles, "slide sắp SAI thứ tự — nhiều khả năng đang sắp theo chuỗi")

        // Dàn ý phải đánh số theo đúng thứ tự ấy.
        XCTAssertTrue(presentation.markdown.contains("## 2. Tieu de 2"))
        XCTAssertTrue(presentation.markdown.contains("## 10. Tieu de 10"))
        // Và slide 10 phải nằm SAU slide 2 trong văn bản.
        let two = presentation.markdown.range(of: "## 2. Tieu de 2")
        let ten = presentation.markdown.range(of: "## 10. Tieu de 10")
        XCTAssertNotNil(two); XCTAssertNotNil(ten)
        if let two, let ten { XCTAssertLessThan(two.lowerBound, ten.lowerBound) }
    }

    func testTENTEPsapXepTHEOSOchuKhongTheoCHUOI() {
        // Nhánh lùi: khi không đọc được bảng quan hệ. Sắp theo chuỗi cho ra 1, 10, 11, 2…
        let paths = ["ppt/slides/slide10.xml", "ppt/slides/slide2.xml", "ppt/slides/slide1.xml"]
        let sorted = paths.sorted { PPTXReader.slideNumber($0) < PPTXReader.slideNumber($1) }
        XCTAssertEqual(sorted, [
            "ppt/slides/slide1.xml", "ppt/slides/slide2.xml", "ppt/slides/slide10.xml",
        ])
    }

    func testKHONGPHAIpptxTHInoiRa() throws {
        let path = kho("docs/GioiThieu_TinhNang_GEditor_v2.0.docx")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path), "không có docx mẫu")
        // Một tệp Word cũng là ZIP hợp lệ; bộ đọc phải từ chối bằng NỘI DUNG chứ không sập.
        XCTAssertThrowsError(try PPTXReader.read(path: path)) { error in
            XCTAssertEqual(error as? PPTXReader.Failure, .notAPresentation)
        }
    }

    func testDANYcoTIEUDEvaGACHDAUDONG() {
        func line(_ text: String, _ ordinal: Int) -> PPTXReader.Line {
            .init(text: text, ordinal: ordinal)
        }
        let slides = [
            PPTXReader.Slide(
                index: 1, path: "ppt/slides/slide1.xml", title: "Mở đầu",
                lines: [line("ý một", 1), line("ý hai", 2)], notes: [],
                notesPath: nil, titleOrdinal: 0),
            PPTXReader.Slide(
                index: 2, path: "ppt/slides/slide2.xml", title: "",
                lines: [], notes: [line("nhớ nói chậm", 0)],
                notesPath: "ppt/notesSlides/notesSlide2.xml", titleOrdinal: nil),
        ]
        let markdown = PPTXReader.markdown(from: slides)
        XCTAssertTrue(markdown.contains("## 1. Mở đầu"))
        XCTAssertTrue(markdown.contains("- ý một"))
        // Slide không có chữ vẫn phải xuất hiện — bỏ nó đi thì số slide trong dàn ý lệch với
        // số slide thật, và người đọc đếm nhầm.
        XCTAssertTrue(markdown.contains("## Slide 2"))
        XCTAssertTrue(markdown.contains("> nhớ nói chậm"))
    }

    // MARK: - Trợ giúp

    /// Dựng `.pptx` bằng LibreOffice từ một tệp Impress dạng XML phẳng (`.fodp`).
    private func dungPPTX(_ titles: [String]) throws -> String {
        let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: soffice),
                          "không có LibreOffice trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-pptx-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

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
        let source = root + "/ban-trinh-chieu.fodp"
        try Data(fodp.utf8).write(to: URL(fileURLWithPath: source))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: soffice)
        process.arguments = ["--headless", "--convert-to", "pptx", "--outdir", root, source]
        process.environment = ProcessInfo.processInfo.environment
            .merging(["HOME": root]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let out = root + "/ban-trinh-chieu.pptx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không chuyển được sang .pptx")
        }
        return out
    }

    private func kho(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relative).path
    }
}
