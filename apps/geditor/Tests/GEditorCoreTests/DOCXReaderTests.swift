import XCTest
@testable import GEditorCore

/// Bài kiểm cho bộ đọc `.docx`.
///
/// Fixture: tệp Word THẬT trong `docs/`, và tệp do LibreOffice dựng từ Markdown — hai hiện thực
/// độc lập với bộ đọc này. Cùng luật đã ghi ở `ZipArchiveTests` và `XLSXReaderTests`.
final class DOCXReaderTests: XCTestCase {

    // MARK: - Tệp Word THẬT trong kho

    func testDOCXthatTrongKhoRaMarkdownCoNoiDung() throws {
        let path = kho("docs/GioiThieu_TinhNang_GEditor_v2.0.docx")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path), "không có docx mẫu")

        let document = try DOCXReader.read(path: path)
        XCTAssertGreaterThan(document.paragraphCount, 10, "đọc ra quá ít đoạn")
        XCTAssertGreaterThan(document.markdown.count, 500, "nội dung gần như rỗng")

        // Chữ phải LIỀN MẠCH QUA RANH GIỚI ĐỊNH DẠNG.
        //
        // Đây là phép kiểm đúng thứ cần kiểm, và bản đầu đã đặt sai: nó so số dòng với số đoạn,
        // một phép đo gián tiếp mà bảng làm hỏng (mỗi bảng sinh ra tiêu đề + phân cách + N hàng,
        // không phải một hằng số). Thứ thật sự cần chứng minh là: một đoạn có cả chữ thường lẫn
        // chữ đậm phải ra MỘT dòng. Word cắt đoạn ấy thành nhiều `<w:r>`, và xử lý theo run sẽ
        // đẩy mỗi mảnh xuống một dòng riêng.
        let lines = document.markdown.split(separator: "\n", omittingEmptySubsequences: true)
        let joined = lines.first {
            $0.contains("GEditor giải quyết đúng một việc") && $0.contains("Nền tảng kỹ thuật")
        }
        XCTAssertNotNil(joined,
                        "đoạn có chữ đậm ở giữa bị cắt thành nhiều dòng — run chưa được nối")
        // Không được rò thẻ XML ra ngoài.
        XCTAssertFalse(document.markdown.contains("<w:"), "thẻ Word lọt vào kết quả")
        XCTAssertFalse(document.markdown.contains("xmlns"))
    }

    // MARK: - Tệp do LibreOffice dựng

    func testTIEUDE_DANHSACH_BANG_DAMNGHIENG_quaDuocHet() throws {
        let path = try dungDOCX("""
            # Tiêu đề lớn

            Một đoạn **đậm** và *nghiêng*.

            ## Tiêu đề nhỏ

            - mục một
            - mục hai

            | Tên | Số |
            |---|---|
            | An | 3 |
            | Bình | 5 |
            """)
        defer { try? FileManager.default.removeItem(
            atPath: (path as NSString).deletingLastPathComponent) }

        let markdown = try DOCXReader.read(path: path).markdown

        XCTAssertTrue(markdown.contains("# Tiêu đề lớn"), "mất tiêu đề cấp 1:\n\(markdown)")
        XCTAssertTrue(markdown.contains("## Tiêu đề nhỏ"), "mất tiêu đề cấp 2:\n\(markdown)")
        XCTAssertTrue(markdown.contains("- mục một"), "mất danh sách:\n\(markdown)")
        XCTAssertTrue(markdown.contains("| An | 3 |"), "mất bảng:\n\(markdown)")
        // Hàng phân cách của bảng Markdown — không có nó thì đó không còn là bảng.
        XCTAssertTrue(markdown.contains("|---|"), "bảng thiếu hàng phân cách:\n\(markdown)")
        XCTAssertTrue(markdown.contains("**đậm**"), "mất chữ đậm:\n\(markdown)")
    }

    // MARK: - Nhánh thuần tính toán

    func testNHANRAtieuDeKeCaTenKIEUdaBanDiaHoa() {
        XCTAssertEqual(BodyParserProbe.headingLevel(ofStyle: "Heading1"), 1)
        XCTAssertEqual(BodyParserProbe.headingLevel(ofStyle: "heading3"), 3)
        // Word lưu tên kiểu theo ngôn ngữ của máy soạn tài liệu. Chỉ so "Heading" thì mọi tệp
        // soạn trên máy tiếng Việt/Đức/Pháp mất sạch cấu trúc tiêu đề.
        XCTAssertEqual(BodyParserProbe.headingLevel(ofStyle: "Tiuu2"), 2)
        XCTAssertEqual(BodyParserProbe.headingLevel(ofStyle: "berschrift1"), 1)
        XCTAssertEqual(BodyParserProbe.headingLevel(ofStyle: "Titre4"), 4)
        // Và không được nhận nhầm.
        XCTAssertNil(BodyParserProbe.headingLevel(ofStyle: "Normal"))
        XCTAssertNil(BodyParserProbe.headingLevel(ofStyle: "ListParagraph"))
        XCTAssertNil(BodyParserProbe.headingLevel(ofStyle: "Heading"))     // không có số
    }

    func testDAUNHANkhongBocQuanhKHOANGTRANG() {
        // `**chữ **tiếp` KHÔNG phải chữ đậm trong Markdown — dấu nhấn phải dính liền chữ. Word
        // hay để khoảng trắng ở cuối run in đậm, nên bỏ qua vế này sẽ cho ra những dấu sao hiện
        // nguyên hình trên trang.
        XCTAssertEqual(BodyParserProbe.emphasise("chữ ", bold: true, italic: false), "**chữ** ")
        XCTAssertEqual(BodyParserProbe.emphasise(" chữ", bold: true, italic: false), " **chữ**")
        XCTAssertEqual(BodyParserProbe.emphasise("chữ", bold: true, italic: true), "***chữ***")
        XCTAssertEqual(BodyParserProbe.emphasise("chữ", bold: false, italic: true), "*chữ*")
        // Run chỉ có khoảng trắng thì để nguyên — `** **` là rác.
        XCTAssertEqual(BodyParserProbe.emphasise("   ", bold: true, italic: false), "   ")
        XCTAssertEqual(BodyParserProbe.emphasise("chữ", bold: false, italic: false), "chữ")
    }

    // MARK: - Trợ giúp

    private func dungDOCX(_ markdown: String) throws -> String {
        let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: soffice),
                          "không có LibreOffice trên máy này")

        let root = NSTemporaryDirectory() + "/geditor-docx-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let source = root + "/tai-lieu.md"
        try Data((markdown + "\n").utf8).write(to: URL(fileURLWithPath: source))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: soffice)
        process.arguments = ["--headless", "--convert-to",
                             "docx:MS Word 2007 XML", "--infilter=Markdown",
                             "--outdir", root, source]
        process.environment = ProcessInfo.processInfo.environment
            .merging(["HOME": root]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let out = root + "/tai-lieu.docx"
        guard FileManager.default.fileExists(atPath: out) else {
            throw XCTSkip("LibreOffice không chuyển được Markdown sang .docx")
        }
        return out
    }

    private func kho(_ relative: String) -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relative).path
    }
}
