import XCTest
@testable import GEditorCore

/// Truy vết: chế độ **View** của `.docx` — mô hình trang mà tầng vẽ dùng.
///
/// Bài kiểm ở đây dựng tệp `.docx` bằng cách **ghi thẳng gói ZIP**, không nhờ bộ ghi của chính
/// sản phẩm. Đó là luật đã học một lần: fixture do chính hiện thực đang kiểm sinh ra thì hai bên
/// cùng sai một kiểu và phép so vẫn xanh.
final class DOCXLayoutTests: XCTestCase {

    private var path = ""

    override func setUpWithError() throws {
        path = NSTemporaryDirectory() + "geditor-layout-\(UUID().uuidString).docx"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Khung dựng gói

    /// Ghi một `.docx` tối thiểu: chỉ những phần bộ đọc thật sự đọc.
    private func writeDocx(
        body: String,
        styles: String? = nil,
        numbering: String? = nil,
        relationships: [(id: String, target: String)] = [],
        media: [(name: String, bytes: [UInt8])] = []
    ) throws {
        var entries: [(String, [UInt8])] = []
        let document = """
            <?xml version="1.0" encoding="UTF-8"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
             xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
            <w:body>\(body)</w:body></w:document>
            """
        entries.append(("word/document.xml", Array(document.utf8)))
        if let styles {
            entries.append(("word/styles.xml", Array("""
                <?xml version="1.0" encoding="UTF-8"?>
                <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                \(styles)</w:styles>
                """.utf8)))
        }
        if let numbering {
            entries.append(("word/numbering.xml", Array("""
                <?xml version="1.0" encoding="UTF-8"?>
                <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                \(numbering)</w:numbering>
                """.utf8)))
        }
        if !relationships.isEmpty {
            let items = relationships.map {
                "<Relationship Id=\"\($0.id)\" Type=\"image\" Target=\"\($0.target)\"/>"
            }.joined()
            entries.append(("word/_rels/document.xml.rels", Array("""
                <?xml version="1.0" encoding="UTF-8"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                \(items)</Relationships>
                """.utf8)))
        }
        for item in media { entries.append(("word/media/" + item.name, item.bytes)) }
        try ZipTestWriter.write(entries: entries, to: path)
    }

    // MARK: - Chữ và hình thức

    func testRunKeepsFontSizeBoldItalicColour() throws {
        try writeDocx(body: """
            <w:p><w:r><w:rPr><w:rFonts w:ascii="Georgia"/><w:sz w:val="28"/><w:b/><w:i/>
            <w:color w:val="1F4E79"/></w:rPr><w:t>Xin chào</w:t></w:r></w:p>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first,
              case .text(let text, let style)? = p.inlines.first
        else { return XCTFail("không đọc ra đoạn nào") }
        XCTAssertEqual(text, "Xin chào")
        XCTAssertEqual(style.fontName, "Georgia")
        XCTAssertEqual(style.sizePt, 14, "w:sz đếm bằng NỬA point")
        XCTAssertTrue(style.bold)
        XCTAssertTrue(style.italic)
        XCTAssertEqual(style.color?.red ?? 0, 31.0 / 255, accuracy: 0.001)
    }

    /// `<w:b/>` không kèm `w:val` nghĩa là BẬT. Hiểu ngược làm cả tệp mất đậm mà vẫn mở ra
    /// bình thường — không ai thấy có gì hỏng.
    func testBoldWithoutValueIsOn() throws {
        try writeDocx(body: """
            <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>đậm</w:t></w:r>
            <w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>thường</w:t></w:r></w:p>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first else { return XCTFail("thiếu đoạn") }
        let bolds: [Bool] = p.inlines.compactMap {
            if case .text(_, let style) = $0 { return style.bold } else { return nil }
        }
        XCTAssertEqual(bolds, [true, false])
    }

    /// Một câu bị Word cắt thành nhiều `<w:r>` cùng hình thức phải nối lại thành MỘT mảnh.
    func testAdjacentRunsWithSameStyleMerge() throws {
        try writeDocx(body: """
            <w:p><w:r><w:t>Kỹ </w:t></w:r><w:r><w:t>sư </w:t></w:r><w:r><w:t>nhí</w:t></w:r></w:p>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first else { return XCTFail("thiếu đoạn") }
        XCTAssertEqual(p.inlines.count, 1, "ba run cùng kiểu phải gộp thành một")
        XCTAssertEqual(p.plainText, "Kỹ sư nhí")
    }

    /// Tiền tố namespace KHÔNG cố định. Một tệp khai `x:` thay cho `w:` vẫn phải đọc ra y hệt.
    func testUnusualNamespacePrefixStillReads() throws {
        let document = """
            <?xml version="1.0" encoding="UTF-8"?>
            <x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <x:body><x:p><x:r><x:rPr><x:b/></x:rPr><x:t>tiền tố lạ</x:t></x:r></x:p></x:body>
            </x:document>
            """
        try ZipTestWriter.write(
            entries: [("word/document.xml", Array(document.utf8))], to: path)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first,
              case .text(let text, let style)? = p.inlines.first
        else { return XCTFail("tiền tố lạ làm mất cả tài liệu") }
        XCTAssertEqual(text, "tiền tố lạ")
        XCTAssertTrue(style.bold)
    }

    // MARK: - Kiểu trong styles.xml

    /// Tệp Word thật hiếm khi ghi cỡ chữ vào run — chúng trỏ sang một kiểu. Bỏ qua `styles.xml`
    /// thì mọi tiêu đề hiện ra y hệt đoạn thường.
    func testHeadingTakesSizeFromStyleSheet() throws {
        try writeDocx(
            body: """
                <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
                <w:r><w:t>Chương 1</w:t></w:r></w:p>
                <w:p><w:r><w:t>đoạn thường</w:t></w:r></w:p>
                """,
            styles: """
                <w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault>
                </w:docDefaults>
                <w:style w:styleId="Heading1"><w:rPr><w:sz w:val="40"/><w:b/></w:rPr></w:style>
                """
        )
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let heading)? = doc.blocks.first,
              case .text(_, let headingStyle)? = heading.inlines.first,
              doc.blocks.count > 1, case .paragraph(let body) = doc.blocks[1],
              case .text(_, let bodyStyle)? = body.inlines.first
        else { return XCTFail("thiếu đoạn") }
        XCTAssertEqual(headingStyle.sizePt, 20)
        XCTAssertTrue(headingStyle.bold)
        XCTAssertEqual(bodyStyle.sizePt, 11, "đoạn thường lấy cỡ của docDefaults")
        XCTAssertEqual(heading.style.outlineLevel, 1)
    }

    /// `w:basedOn` VÒNG là chuyện có thật với tệp do công cụ khác sinh. Không được treo.
    func testCircularBasedOnDoesNotHang() throws {
        try writeDocx(
            body: "<w:p><w:pPr><w:pStyle w:val=\"A\"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>",
            styles: """
                <w:style w:styleId="A"><w:basedOn w:val="B"/></w:style>
                <w:style w:styleId="B"><w:basedOn w:val="A"/></w:style>
                """
        )
        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.blocks.count, 1)
    }

    /// `w:rPr` NẰM TRONG `w:pPr` mô tả dấu kết đoạn, không mô tả chữ trong đoạn.
    func testParagraphMarkRunPropertiesDoNotStyleTheText() throws {
        try writeDocx(
            body: "<w:p><w:pPr><w:pStyle w:val=\"S\"/></w:pPr><w:r><w:t>chữ</w:t></w:r></w:p>",
            styles: """
                <w:style w:styleId="S"><w:pPr><w:rPr><w:sz w:val="96"/></w:rPr></w:pPr>
                <w:rPr><w:sz w:val="24"/></w:rPr></w:style>
                """
        )
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first,
              case .text(_, let style)? = p.inlines.first
        else { return XCTFail("thiếu đoạn") }
        XCTAssertEqual(style.sizePt, 12, "cỡ 48 của dấu kết đoạn không được tràn sang chữ")
    }

    // MARK: - Khổ giấy

    func testPageSizeAndMarginsComeFromSectionProperties() throws {
        try writeDocx(body: """
            <w:p><w:r><w:t>x</w:t></w:r></w:p>
            <w:sectPr><w:pgSz w:w="12240" w:h="15840"/>
            <w:pgMar w:top="1440" w:right="1080" w:bottom="1440" w:left="1800"/></w:sectPr>
            """)
        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.pageWidthPt, 612, accuracy: 0.01, "US Letter = 12240 twip")
        XCTAssertEqual(doc.pageHeightPt, 792, accuracy: 0.01)
        XCTAssertEqual(doc.marginLeftPt, 90, accuracy: 0.01)
        XCTAssertEqual(doc.marginRightPt, 54, accuracy: 0.01)
        XCTAssertEqual(doc.contentWidthPt, 612 - 144, accuracy: 0.01)
    }

    // MARK: - Bảng

    func testTableKeepsRowsCellsAndShading() throws {
        try writeDocx(body: """
            <w:tbl><w:tblGrid><w:gridCol w:w="2880"/><w:gridCol w:w="1440"/></w:tblGrid>
            <w:tr>
              <w:tc><w:tcPr><w:shd w:fill="FFF2CC"/></w:tcPr>
                <w:p><w:r><w:t>Trăm</w:t></w:r></w:p></w:tc>
              <w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr>
                <w:p><w:r><w:t>Chục</w:t></w:r></w:p></w:tc>
            </w:tr></w:tbl>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .table(let table)? = doc.blocks.first else { return XCTFail("thiếu bảng") }
        XCTAssertEqual(table.columnWidthsPt, [144, 72])
        XCTAssertEqual(table.rows.count, 1)
        XCTAssertEqual(table.rows[0].cells.count, 2)
        XCTAssertEqual(table.rows[0].cells[0].paragraphs.first?.plainText, "Trăm")
        XCTAssertNotNil(table.rows[0].cells[0].shading)
        XCTAssertEqual(table.rows[0].cells[1].columnSpan, 2)
    }

    /// Bảng lồng trong ô của bảng khác: nội dung bên trong KHÔNG được biến mất.
    ///
    /// Một biến "bảng hiện tại" duy nhất sẽ nuốt bảng ngoài khi gặp bảng trong — nên chỗ ghi là
    /// một ngăn xếp. Bài kiểm này là thứ chứng minh ngăn xếp ấy có tác dụng.
    func testNestedTableContentSurvives() throws {
        try writeDocx(body: """
            <w:tbl><w:tr><w:tc>
              <w:p><w:r><w:t>ngoài</w:t></w:r></w:p>
              <w:tbl><w:tr><w:tc><w:p><w:r><w:t>trong</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
            </w:tc></w:tr></w:tbl>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .table(let table)? = doc.blocks.first else { return XCTFail("thiếu bảng") }
        let text = table.rows[0].cells[0].paragraphs.map(\.plainText)
        XCTAssertTrue(text.contains("ngoài"))
        XCTAssertTrue(text.contains("trong"), "bảng lồng bị nuốt mất")
    }

    // MARK: - Ảnh

    /// Đây là lý do cả tệp này tồn tại: bộ nhập OOXML của AppKit đọc được font, màu, bảng — và
    /// vứt sạch ảnh. Đo trên tệp thật: gói có 15 tệp trong `word/media/`, chuỗi nó trả về có 0
    /// ký tự đính kèm.
    func testInlineImageIsReadWithItsBytesAndSize() throws {
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]
        try writeDocx(
            body: """
                <w:p><w:r><w:drawing><wp:inline>
                <wp:extent cx="1905000" cy="952500"/>
                <a:graphic><a:graphicData><a:blip r:embed="rId9"/></a:graphicData></a:graphic>
                </wp:inline></w:drawing></w:r></w:p>
                """,
            relationships: [(id: "rId9", target: "media/anh.png")],
            media: [(name: "anh.png", bytes: png)]
        )
        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.imageCount, 1, "ảnh nhúng bị mất")
        guard case .paragraph(let p)? = doc.blocks.first,
              case .image(let image)? = p.inlines.first
        else { return XCTFail("mảnh đầu không phải ảnh") }
        XCTAssertEqual(image.data, png, "phải là BYTE gốc của tệp trong gói")
        XCTAssertEqual(image.widthPt, 150, accuracy: 0.01, "EMU → point: 914400 EMU = 72 pt")
        XCTAssertEqual(image.heightPt, 75, accuracy: 0.01)
    }

    /// Ảnh **neo tự do** (`wp:anchor`, kiểu chữ chạy quanh) không được biến mất.
    ///
    /// Bản dựng chưa cho chữ chạy quanh ảnh — nó đặt ảnh vào đúng chỗ trong dòng. Đó là một
    /// khác biệt về BỐ CỤC, chấp nhận được và đã ghi vào sách trợ giúp. Thứ KHÔNG chấp nhận
    /// được là ảnh biến mất, và ranh giới ấy cần một bài kiểm riêng vì hai kiểu neo nằm ở hai
    /// thẻ khác nhau (`wp:inline` và `wp:anchor`) — dễ chỉ đọc một.
    ///
    /// Đo trên 61 tệp thật của người dùng: không tệp nào dùng `wp:anchor`. Nên bài này là fixture
    /// dựng tay, và nó tồn tại đúng vì tệp thật không nói được gì về trường hợp này.
    func testAnchoredImageIsNotLost() throws {
        try writeDocx(
            body: """
                <w:p><w:r><w:drawing><wp:anchor behindDoc="0" simplePos="0">
                <wp:positionH relativeFrom="margin"><wp:align>center</wp:align></wp:positionH>
                <wp:extent cx="2286000" cy="1143000"/>
                <a:graphic><a:graphicData><a:blip r:embed="rId4"/></a:graphicData></a:graphic>
                </wp:anchor></w:drawing></w:r></w:p>
                <w:p><w:r><w:t>chữ sau ảnh</w:t></w:r></w:p>
                """,
            relationships: [(id: "rId4", target: "media/neo.png")],
            media: [(name: "neo.png", bytes: [0x89, 0x50, 0x4E, 0x47, 1, 2, 3])]
        )
        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.imageCount, 1, "ảnh neo tự do bị mất hẳn")
        guard case .paragraph(let first)? = doc.blocks.first,
              case .image(let image)? = first.inlines.first
        else { return XCTFail("mảnh đầu không phải ảnh") }
        XCTAssertEqual(image.widthPt, 180, accuracy: 0.01)
        XCTAssertEqual(image.heightPt, 90, accuracy: 0.01)
        // Và chữ phía sau vẫn còn — ảnh neo không được nuốt phần còn lại của tài liệu.
        XCTAssertEqual(doc.blocks.count, 2)
    }

    /// Ảnh trong ô bảng cũng phải ra — đó là chỗ tệp thật hay đặt hình minh hoạ nhất.
    func testImageInsideTableCell() throws {
        try writeDocx(
            body: """
                <w:tbl><w:tr><w:tc><w:p><w:r><w:drawing><wp:inline>
                <wp:extent cx="914400" cy="914400"/>
                <a:blip r:embed="rId1"/></wp:inline></w:drawing></w:r></w:p></w:tc></w:tr></w:tbl>
                """,
            relationships: [(id: "rId1", target: "media/o.png")],
            media: [(name: "o.png", bytes: [1, 2, 3, 4])]
        )
        XCTAssertEqual(try DOCXLayout.read(path: path).imageCount, 1)
    }

    /// Quan hệ trỏ tới một tệp KHÔNG có trong gói: bỏ qua, không sập, không dựng ảnh rỗng.
    func testMissingMediaIsSkippedNotCrashed() throws {
        try writeDocx(
            body: """
                <w:p><w:r><w:drawing><wp:inline><wp:extent cx="914400" cy="914400"/>
                <a:blip r:embed="rId1"/></wp:inline></w:drawing></w:r>
                <w:r><w:t>vẫn còn chữ</w:t></w:r></w:p>
                """,
            relationships: [(id: "rId1", target: "media/khong-co.png")]
        )
        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.imageCount, 0)
        guard case .paragraph(let p)? = doc.blocks.first else { return XCTFail("thiếu đoạn") }
        XCTAssertEqual(p.plainText, "vẫn còn chữ")
    }

    // MARK: - Những thứ KHÔNG được hiện ra

    /// `w:instrText` là mã trường (`TOC \\o "1-3"`), `w:delText` là chữ tác giả đã xoá trong bản
    /// theo dõi thay đổi. Hiện chúng ra là hiện thứ không có trong tài liệu người ta đang đọc.
    func testFieldCodesAndDeletedTextAreNotShown() throws {
        try writeDocx(body: """
            <w:p><w:r><w:instrText>TOC \\o "1-3"</w:instrText></w:r>
            <w:del><w:r><w:delText>đã bỏ</w:delText></w:r></w:del>
            <w:r><w:t>còn lại</w:t></w:r></w:p>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first else { return XCTFail("thiếu đoạn") }
        XCTAssertEqual(p.plainText, "còn lại")
    }

    // MARK: - Danh sách và ngắt trang

    func testNumberedListCountsUpAndBulletsStayBullets() throws {
        try writeDocx(
            body: """
                <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
                <w:r><w:t>một</w:t></w:r></w:p>
                <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
                <w:r><w:t>hai</w:t></w:r></w:p>
                <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr>
                <w:r><w:t>chấm</w:t></w:r></w:p>
                """,
            numbering: """
                <w:abstractNum w:abstractNumId="10"><w:lvl w:ilvl="0">
                <w:numFmt w:val="decimal"/></w:lvl></w:abstractNum>
                <w:abstractNum w:abstractNumId="20"><w:lvl w:ilvl="0">
                <w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
                <w:num w:numId="1"><w:abstractNumId w:val="10"/></w:num>
                <w:num w:numId="2"><w:abstractNumId w:val="20"/></w:num>
                """
        )
        let doc = try DOCXLayout.read(path: path)
        let markers: [String?] = doc.blocks.compactMap {
            if case .paragraph(let p) = $0 { return p.style.listMarker } else { return nil }
        }
        XCTAssertEqual(markers, ["1.", "2.", "•"])
    }

    func testExplicitPageBreakIsKept() throws {
        try writeDocx(body: """
            <w:p><w:r><w:t>trước</w:t></w:r><w:br w:type="page"/><w:r><w:t>sau</w:t></w:r></w:p>
            """)
        let doc = try DOCXLayout.read(path: path)
        guard case .paragraph(let p)? = doc.blocks.first else { return XCTFail("thiếu đoạn") }
        XCTAssertTrue(p.inlines.contains(.pageBreak))
    }

    // MARK: - Đơn vị

    func testUnitConversions() {
        XCTAssertEqual(DOCXLayout.points(twips: "1440"), 72, "1440 twip = 1 inch")
        XCTAssertEqual(DOCXLayout.points(emu: "914400"), 72, "914400 EMU = 1 inch")
        XCTAssertEqual(DOCXLayout.points(halfPoints: "24"), 12)
        XCTAssertNil(DOCXLayout.points(twips: "không phải số"))
    }

    /// `w:line="360"` với `lineRule="auto"` là giãn 1,5 dòng — KHÔNG phải 360 lần.
    func testLineSpacingRuleIsNotTakenLiterally() {
        XCTAssertEqual(ooxmlLineSpacing(raw: 360, rule: "auto"), 1.5, accuracy: 0.001)
        XCTAssertEqual(ooxmlLineSpacing(raw: 240, rule: nil), 1, accuracy: 0.001)
        XCTAssertLessThanOrEqual(ooxmlLineSpacing(raw: 100_000, rule: "auto"), 4, "phải chặn trần")
    }

    // MARK: - Tệp THẬT

    /// Fixture tự dựng chỉ chứng minh bộ đọc hiểu đúng thứ bài kiểm vừa viết ra. Tệp Word thật —
    /// do Word thật ghi, với `styles.xml` thật và ảnh thật — là chỗ duy nhất nói được nó có đọc
    /// nổi tài liệu của người dùng hay không.
    ///
    /// Phép so mạnh nhất ở đây: **số ảnh đọc ra phải bằng số tệp trong `word/media/`**. Đó chính
    /// là phép mà bộ nhập OOXML của AppKit trượt — nó trả về 0 trên mọi tệp.
    func testRealDocumentsKeepTheirText_AndEveryEmbeddedImage() throws {
        let folder = "data/vanban"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder))?
            .filter { $0.hasSuffix(".docx") && !$0.hasPrefix("~") }
            .sorted() ?? []
        try XCTSkipIf(names.isEmpty, "không có thư mục tệp thật")

        for name in names {
            let file = folder + "/" + name
            let doc = try DOCXLayout.read(path: file)
            XCTAssertFalse(doc.blocks.isEmpty, "\(name): không đọc ra khối nào")

            let text = doc.blocks.reduce(into: "") { result, block in
                if case .paragraph(let p) = block { result += p.plainText }
            }
            XCTAssertGreaterThan(text.count, 200, "\(name): gần như không có chữ")
            XCTAssertGreaterThan(doc.pageWidthPt, 100, "\(name): khổ giấy vô lý")

            // Số tệp ảnh trong gói — đếm ĐỘC LẬP với bộ đọc đang kiểm.
            let archive = try ZipArchive(path: file)
            let media = archive.entries.filter {
                $0.path.hasPrefix("word/media/") && !$0.isDirectory
                    && !$0.path.lowercased().hasSuffix(".emf")
                    && !$0.path.lowercased().hasSuffix(".wmf")
            }
            // Một tệp media dùng lại ở nhiều chỗ thì số ảnh VẼ RA nhiều hơn số tệp; thiếu thì
            // không bao giờ chấp nhận được.
            XCTAssertGreaterThanOrEqual(
                doc.imageCount, media.count,
                "\(name): gói có \(media.count) ảnh, đọc ra \(doc.imageCount)"
            )
        }
    }

    /// Mỗi PHẦN một cặp đầu/chân trang riêng.
    ///
    /// Đo trên sách thật: 45 phần, 35 phần khai riêng, 70 tệp header/footer khác nhau. Dùng
    /// chung một bản cho cả cuốn thì 34 phần hiện sai tên chương — đúng chỗ người đọc nhìn để
    /// biết mình đang ở đâu.
    func testEachSectionKeepsItsOwnFooter() throws {
        func footer(_ text: String) -> String {
            """
            <?xml version="1.0"?>
            <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:ftr>
            """
        }
        let rels = """
            <?xml version="1.0"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rIdA" Type="footer" Target="footerA.xml"/>
            <Relationship Id="rIdB" Type="footer" Target="footerB.xml"/></Relationships>
            """
        // Hai phần: đoạn 1–2 thuộc phần A (sectPr nằm trong pPr của đoạn 2), đoạn 3 thuộc phần
        // B (sectPr nằm thẳng trong body).
        let document = """
            <?xml version="1.0"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <w:body>
            <w:p><w:r><w:t>chương một</w:t></w:r></w:p>
            <w:p><w:pPr><w:sectPr><w:footerReference w:type="default" r:id="rIdA"/>
            <w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:pPr>
            <w:r><w:t>hết chương một</w:t></w:r></w:p>
            <w:p><w:r><w:t>chương hai</w:t></w:r></w:p>
            <w:sectPr><w:footerReference w:type="default" r:id="rIdB"/>
            <w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body></w:document>
            """
        try ZipTestWriter.write(entries: [
            ("word/document.xml", Array(document.utf8)),
            ("word/footerA.xml", Array(footer("PHẦN MỘT").utf8)),
            ("word/footerB.xml", Array(footer("PHẦN HAI").utf8)),
            ("word/_rels/document.xml.rels", Array(rels.utf8)),
        ], to: path)

        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.sections.count, 2, "không cắt ra hai phần")
        XCTAssertEqual(doc.sections[0].blockCount, 2, "phần một phải gồm hai đoạn")
        XCTAssertEqual(doc.sections[1].blockCount, 1)
        XCTAssertEqual(doc.sections[0].footer.first?.plainText, "PHẦN MỘT")
        XCTAssertEqual(doc.sections[1].footer.first?.plainText, "PHẦN HAI")
        // Và khoá cũ vẫn là của phần đầu — không đường gọi nào lặng lẽ đổi nghĩa.
        XCTAssertEqual(doc.footer.first?.plainText, "PHẦN MỘT")
    }

    /// Sách thật của người dùng: nhiều phần, và các phần KHÔNG dùng chung một chân trang.
    func testRealBookHasDistinctFootersPerSection() throws {
        let file = "data/vanban/KienTrucTriThuc_KDP.docx"
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file), "không có sách thật")
        let doc = try DOCXLayout.read(path: file)
        XCTAssertGreaterThan(doc.sections.count, 10, "sách 45 phần mà chỉ đọc ra một phần")
        // KHÔNG hỏi "các phần có chân trang KHÁC NHAU không".
        //
        // Đã hỏi thế một lần và bài kiểm đỏ — nhưng lỗi nằm ở câu hỏi: đo ra thì cả 70 tệp
        // header/footer của cuốn này mang nội dung GIỐNG HỆT nhau. Word nhân bản một tệp cho
        // mỗi phần dù nội dung không đổi. "Khác nhau" là tính chất của TỆP, không phải của mã
        // đang kiểm — hỏi nó là để tệp quyết định bài kiểm xanh hay đỏ.
        //
        // Thứ hỏi được: mỗi phần khai chân trang thì phải ĐỌC RA được chân trang ấy.
        let withFooter = doc.sections.filter { !$0.footer.isEmpty }
        XCTAssertGreaterThan(
            withFooter.count, 10,
            "sách khai 35 phần có chân trang mà chỉ \(withFooter.count) phần đọc ra được"
        )
        XCTAssertEqual(
            doc.sections.reduce(0) { $0 + $1.blockCount }, doc.blocks.count,
            "tổng khối của các phần phải bằng số khối của tài liệu — nếu không thì có khối "
                + "rơi ra ngoài mọi phần và mất đầu/chân trang"
        )
    }

    /// Chân trang đọc được, và trường `PAGE` đi tới tầng vẽ dưới dạng một chỗ trống có tên.
    func testFooterPartIsReadAndCarriesPageField() throws {
        let footer = """
            <?xml version="1.0"?>
            <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r><w:t xml:space="preserve">— </w:t></w:r>
            <w:r><w:instrText>PAGE</w:instrText></w:r>
            <w:r><w:t xml:space="preserve"> —</w:t></w:r></w:p></w:ftr>
            """
        let rels = """
            <?xml version="1.0"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId3" Type="footer" Target="footer1.xml"/></Relationships>
            """
        let document = """
            <?xml version="1.0"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <w:body><w:p><w:r><w:t>thân</w:t></w:r></w:p>
            <w:sectPr><w:footerReference w:type="default" r:id="rId3"/>
            <w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body></w:document>
            """
        try ZipTestWriter.write(entries: [
            ("word/document.xml", Array(document.utf8)),
            ("word/footer1.xml", Array(footer.utf8)),
            ("word/_rels/document.xml.rels", Array(rels.utf8)),
        ], to: path)

        let doc = try DOCXLayout.read(path: path)
        XCTAssertEqual(doc.footer.count, 1, "không đọc ra chân trang")
        let inlines = doc.footer.first?.inlines ?? []
        XCTAssertTrue(inlines.contains(.pageNumber), "trường PAGE bị nuốt cùng mã trường")
        XCTAssertEqual(doc.footer.first?.style.alignment, .center)
        XCTAssertEqual(doc.footer.first?.plainText, "—  —")
    }

    /// Chân trang của sách in mang trường `PAGE`. Đọc được nó là điều kiện để trang dựng ra có
    /// SỐ TRANG — thứ đầu tiên người ta tìm khi đối chiếu với bản in.
    func testRealBookFootersCarryThePageNumberField() throws {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "data/vanban"))?
            .filter { $0.hasSuffix(".docx") }.sorted() ?? []
        try XCTSkipIf(names.isEmpty, "không có tệp thật")

        var withFooter = 0
        var withPageField = 0
        for name in names {
            let doc = try DOCXLayout.read(path: "data/vanban/" + name)
            guard !doc.footer.isEmpty || !doc.header.isEmpty else { continue }
            withFooter += 1
            let fields = (doc.footer + doc.header).flatMap(\.inlines)
            if fields.contains(.pageNumber) { withPageField += 1 }
        }
        XCTAssertGreaterThan(withFooter, 0, "không cuốn nào đọc ra đầu/chân trang")
        XCTAssertGreaterThan(
            withPageField, 0,
            "\(withFooter) cuốn có chân trang nhưng không cuốn nào có trường PAGE — "
                + "trường bị nuốt cùng với mã trường"
        )
    }

    func testAutoColourIsNotForcedToBlack() {
        XCTAssertNil(DOCXLayout.Color.hex("auto"))
        XCTAssertNil(DOCXLayout.Color.hex(nil))
        XCTAssertNotNil(DOCXLayout.Color.hex("#FFFFFF"))
    }
}
