import XCTest
@testable import GEditorCore

/// Bài kiểm thêm/xoá ĐOẠN trong `.docx`.
///
/// Vòng tròn ra ngoài như mọi bộ ghi khác: LibreOffice dựng tệp → ta sửa → LibreOffice đọc lại.
final class DOCXParagraphEditorTests: XCTestCase {

    // MARK: - Thêm đoạn

    func testTHEMdoan_LIBREOFFICEdocLaiVANthay() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, """
            Doan mot.

            Doan hai.
            """)

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("Doan mot") }) else {
            return XCTFail("không thấy đoạn mốc:\n\(original.markdown)")
        }
        lines.insert("Doan MOI chen vao.", at: index + 1)

        let plan = try DOCXParagraphEditor.plan(
            from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(plan.insertedTexts, ["Doan MOI chen vao."])
        XCTAssertTrue(plan.deletedParagraphs.isEmpty, "không xoá gì mà lại báo xoá")

        let out = root + "/da-them.docx"
        try apply(plan, from: source, to: out)

        let text = try docBangLibreOffice(root, out)
        XCTAssertTrue(text.contains("Doan MOI chen vao"), "LibreOffice không thấy đoạn mới:\n\(text)")
        XCTAssertTrue(text.contains("Doan mot"), "mất đoạn cũ:\n\(text)")
        XCTAssertTrue(text.contains("Doan hai"), "mất đoạn cũ:\n\(text)")

        // Bộ đọc của ta thấy đúng ba đoạn, và đúng THỨ TỰ.
        let again = try DOCXReader.read(path: out)
        let dong = again.markdown.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(dong, ["Doan mot.", "Doan MOI chen vao.", "Doan hai."],
                       "đoạn mới sai chỗ: \(dong)")
    }

    func testTHEMmucVAOdanhSACHthiTHUAKEkieuDANHSACH() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, """
            - muc mot
            - muc hai
            """)

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("muc mot") }) else {
            return XCTFail("không thấy mục danh sách:\n\(original.markdown)")
        }
        lines.insert("- muc MOI", at: index + 1)

        // Tiền tố `"- "` khớp tiền tố của hàng xóm, nên phép thêm đi qua được — và đoạn mới
        // thừa kế `<w:numPr>` nên nó THÀNH một mục danh sách thật, không phải đoạn thường.
        let plan = try DOCXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(plan.insertedTexts, ["muc MOI"], "tiền tố «- » chưa bị bỏ")

        let out = root + "/da-them-muc.docx"
        try apply(plan, from: source, to: out)

        let again = try DOCXReader.read(path: out)
        XCTAssertTrue(again.markdown.contains("- muc MOI"),
                      "đoạn mới không thành mục danh sách:\n\(again.markdown)")
    }

    // MARK: - Xoá đoạn

    func testXOAdoan_LIBREOFFICEkhongCONthayNoNua() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, """
            Doan mot.

            Doan hai se bi xoa.

            Doan ba.
            """)

        let original = try DOCXReader.read(path: source)
        let lines = original.markdown.components(separatedBy: "\n")
            .filter { !$0.contains("se bi xoa") }

        let plan = try DOCXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n"))
        XCTAssertEqual(plan.deletedParagraphs.count, 1, "tìm sai số đoạn bị xoá: \(plan)")

        let out = root + "/da-xoa.docx"
        try apply(plan, from: source, to: out)

        let text = try docBangLibreOffice(root, out)
        XCTAssertFalse(text.contains("se bi xoa"), "đoạn đã xoá vẫn còn:\n\(text)")
        XCTAssertTrue(text.contains("Doan mot"), "xoá nhầm đoạn:\n\(text)")
        XCTAssertTrue(text.contains("Doan ba"), "xoá nhầm đoạn:\n\(text)")
    }

    // MARK: - Từ chối kèm lý do

    func testDONGmoiMANGkieuKHACthiTUCHOI() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let source = try dungDOCX(root, "Doan mot.\n\nDoan hai.")

        let original = try DOCXReader.read(path: source)
        var lines = original.markdown.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.contains("Doan mot") }) else {
            return XCTFail("không thấy đoạn mốc")
        }
        // Gõ một tiêu đề giữa hai đoạn thường: đó là xin một KIỂU khác, mà kiểu ấy phải tồn tại
        // trong `styles.xml` với đúng tên Word đặt (đã bản địa hoá). Dựng bừa một đoạn thường
        // rồi để nguyên dấu `##` trong chữ là im lặng làm sai ý người dùng.
        lines.insert("## Tieu de moi", at: index + 1)

        XCTAssertThrowsError(
            try DOCXParagraphEditor.plan(from: original, to: lines.joined(separator: "\n"))
        ) { error in
            guard case .newParagraphNeedsStyle = (error as? DOCXParagraphEditor.Failure) else {
                return XCTFail("lỗi sai loại: \(error)")
            }
        }
    }

    func testVUAtheMVUAxoaTRONGmotLUOTthiTUCHOI() {
        // Diễn giải nó thành "xoá rồi chèn" cũng chạy được, nhưng nó vứt mất `<w:pPr>` của
        // những đoạn bị xoá và dựng lại bằng kiểu hàng xóm — tức âm thầm đổi định dạng những
        // đoạn người dùng chỉ SỬA CHỮ.
        let document = DOCXReader.Document(
            markdown: "a\n\nb\n\nc\n", paragraphCount: 3, tableCount: 0,
            lineOwners: [
                .init(paragraph: 0, prefixLength: 0), .init(paragraph: nil, prefixLength: 0),
                .init(paragraph: 1, prefixLength: 0), .init(paragraph: nil, prefixLength: 0),
                .init(paragraph: 2, prefixLength: 0),
            ])
        XCTAssertThrowsError(
            try DOCXParagraphEditor.plan(from: document, to: "a\n\nX\n\nY\n\nc\n")
        ) { error in
            XCTAssertEqual(error as? DOCXParagraphEditor.Failure, .mixedEdit)
        }
    }

    func testXOAhangBANGthiTUCHOI() {
        let document = DOCXReader.Document(
            markdown: "| a | b |\n", paragraphCount: 0, tableCount: 1,
            lineOwners: [.init(paragraph: nil, prefixLength: 0, cells: [0, 1])])
        XCTAssertThrowsError(try DOCXParagraphEditor.plan(from: document, to: "")) { error in
            XCTAssertEqual(error as? DOCXParagraphEditor.Failure,
                           .cannotDeleteTableRow(line: 0))
        }
    }

    // MARK: - Nhánh thuần tính toán

    func testNHANRAtienToMARKDOWN() {
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("## Tieu de"), 3)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("# Tieu de"), 2)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("- muc"), 2)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("> trich"), 2)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("1. mot"), 3)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("van ban thuong"), 0)
        // `#hashtag` không có dấu cách nên không phải tiêu đề.
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength("#hashtag"), 0)
        XCTAssertEqual(DOCXParagraphEditor.markdownPrefixLength(""), 0)
    }

    func testDOANmoiTHUAKEthuocTINHcuaHANGXOM() {
        let paragraph = "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>"
            + "<w:r><w:t>A</w:t></w:r></w:p>"
        XCTAssertEqual(DOCXParagraphEditor.paragraphProperties(of: paragraph),
                       "<w:pPr><w:jc w:val=\"center\"/></w:pPr>")
        // Không có `<w:pPr>` thì trả rỗng, không bịa ra.
        XCTAssertEqual(
            DOCXParagraphEditor.paragraphProperties(of: "<w:p><w:r><w:t>A</w:t></w:r></w:p>"), "")
        // Dạng tự đóng cũng phải nhận.
        XCTAssertEqual(DOCXParagraphEditor.paragraphProperties(of: "<w:p><w:pPr/></w:p>"),
                       "<w:pPr/>")
    }

    // MARK: - Trợ giúp

    private func apply(
        _ plan: DOCXParagraphEditor.Plan, from source: String, to destination: String
    ) throws {
        let archive = try ZipArchive(path: source)
        let original = try XCTUnwrap(archive.data(named: "word/document.xml"))
        let edited = try DOCXParagraphEditor.apply(plan, to: original)
        try ZipWriter.rewrite(archive, replacing: ["word/document.xml": edited], to: destination)
    }

    private func fixtureRoot() throws -> String {
        let root = NSTemporaryDirectory() + "/geditor-docxp-\(UUID().uuidString)"
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

    private func docBangLibreOffice(_ root: String, _ docx: String) throws -> String {
        let outDir = root + "/doc-lai-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try chay(root, ["--headless", "--convert-to", "txt:Text (encoded):UTF8",
                        "--outdir", outDir, docx])
        let name = ((docx as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".txt"
        guard let data = FileManager.default.contents(
            atPath: (outDir as NSString).appendingPathComponent(name)) else {
            XCTFail("LibreOffice KHÔNG mở được tệp vừa ghi")
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
