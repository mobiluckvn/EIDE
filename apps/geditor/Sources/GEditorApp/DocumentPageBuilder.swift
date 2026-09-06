import AppKit
import GEditorCore

/// Đổi **mô hình trang** của lõi thành đối tượng của macOS: font, màu, ảnh, bảng.
///
/// Đây là phía bên kia của ranh giới mà `DOCXLayout` mô tả. Lõi trả tên font và ba số màu vì nó
/// không được biết AppKit; chỗ duy nhất biến chúng thành `NSFont` và `NSColor` là ở đây.
///
/// **Vì sao dựng `NSAttributedString` chứ không tự vẽ từng dòng.** TextKit đã có sẵn thứ khó
/// nhất: ngắt dòng theo ngôn ngữ, chữ ghép, dấu tiếng Việt chồng lên nguyên âm, chữ phải-sang-
/// trái, và bố cục bảng. Tự viết lại là viết lại một bộ máy mà Apple đã sửa hai mươi năm. Cái
/// tầng này phải tự làm là **phân trang** — TextKit không tự cắt trang, và đó đúng là việc của
/// `DocumentPageSource`.
enum DocumentPageBuilder {

    /// Dựng chuỗi có thuộc tính cho cả tài liệu.
    ///
    /// - Parameter inkOverride: màu chữ thay cho màu tài liệu, dùng khi tài liệu không nói màu.
    ///   Trang giấy ở đây luôn TRẮNG kể cả trong giao diện tối — xem `DocumentPagesView` — nên
    ///   chữ mặc định phải là đen, không phải màu chữ của theme.
    static func attributedString(for document: DOCXLayout.Document) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let box = CGSize(width: document.contentWidthPt, height: document.contentHeightPt)
        for block in document.blocks {
            switch block {
            case .paragraph(let paragraph):
                if paragraph.style.pageBreakBefore, result.length > 0 {
                    result.append(NSAttributedString(string: "\u{000C}"))
                }
                result.append(attributed(paragraph, box: box))
            case .table(let table):
                result.append(attributed(table, box: box))
            }
        }
        // TextKit cần ít nhất một ký tự để dựng được một dòng; tài liệu rỗng mà không có gì thì
        // bộ phân trang đếm ra 0 trang và người dùng thấy một khoảng xám không lời giải thích.
        if result.length == 0 {
            result.append(NSAttributedString(string: " "))
        }
        return result
    }

    /// Dựng đầu hoặc chân trang cho MỘT trang cụ thể.
    ///
    /// Khác thân tài liệu ở đúng một điểm, và điểm ấy là lý do hàm này tồn tại: `PAGE` và
    /// `NUMPAGES` chỉ có giá trị khi đã biết đang vẽ tờ nào. Cùng một chân trang dùng lại cho
    /// 383 tờ, mỗi tờ một con số.
    static func attributed(
        headerOrFooter paragraphs: [DOCXLayout.Paragraph],
        page: Int, of total: Int, width: Double
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let box = CGSize(width: max(1, width), height: 10_000)
        for paragraph in paragraphs {
            var filled = paragraph
            filled.inlines = paragraph.inlines.map { inline in
                switch inline {
                case .pageNumber:
                    return .text("\(page)", numberStyle(in: paragraph))
                case .pageCount:
                    return .text("\(total)", numberStyle(in: paragraph))
                default:
                    return inline
                }
            }
            result.append(attributed(filled, box: box))
        }
        return result
    }

    /// Hình thức cho con số trang: mượn của mảnh chữ ĐỨNG NGAY TRƯỚC nó trong cùng đoạn.
    ///
    /// Trường `PAGE` mang `w:rPr` của chính nó trong tệp, nhưng lõi không giữ lại vì nó chỉ ghi
    /// ra một chỗ trống có tên. Mượn của mảnh liền trước là xấp xỉ đúng gần như luôn luôn: chân
    /// trang «— 12 —» có ba mảnh cùng một kiểu.
    private static func numberStyle(in paragraph: DOCXLayout.Paragraph) -> DOCXLayout.RunStyle {
        firstRunStyle(paragraph) ?? DOCXLayout.RunStyle(sizePt: 9)
    }

    // MARK: - Đoạn

    private static func attributed(
        _ paragraph: DOCXLayout.Paragraph, box: CGSize, inTable: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let style = paragraphStyle(paragraph.style, inTable: inTable)

        if let marker = paragraph.style.listMarker {
            let base = firstRunStyle(paragraph) ?? DOCXLayout.RunStyle()
            result.append(NSAttributedString(
                string: marker + "\t",
                attributes: attributes(for: base, paragraphStyle: style)
            ))
        }

        for inline in paragraph.inlines {
            switch inline {
            case .text(let text, let runStyle):
                result.append(NSAttributedString(
                    string: text, attributes: attributes(for: runStyle, paragraphStyle: style)))
            case .lineBreak:
                result.append(NSAttributedString(
                    string: "\u{2028}",   // ngắt DÒNG, không ngắt đoạn — giữ nguyên khoảng cách
                    attributes: attributes(
                        for: firstRunStyle(paragraph) ?? DOCXLayout.RunStyle(),
                        paragraphStyle: style)))
            case .pageBreak:
                result.append(NSAttributedString(
                    string: "\u{000C}",   // form feed — bộ phân trang tìm đúng ký tự này
                    attributes: [.paragraphStyle: style]))
            case .pageNumber, .pageCount:
                // Số trang chỉ biết được lúc VẼ. Ở thân tài liệu thì bỏ qua — chỉ đầu và chân
                // trang mới dựng qua `attributed(headerOrFooter:…)`, nơi con số đã có.
                break
            case .image(let image):
                if let attachment = attachment(for: image, box: box) {
                    let piece = NSMutableAttributedString(attributedString:
                        NSAttributedString(attachment: attachment))
                    piece.addAttribute(
                        .paragraphStyle, value: style,
                        range: NSRange(location: 0, length: piece.length))
                    result.append(piece)
                }
            }
        }

        result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: style]))

        if let shading = paragraph.style.shading {
            result.addAttribute(
                .backgroundColor, value: color(shading),
                range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    private static func firstRunStyle(_ paragraph: DOCXLayout.Paragraph) -> DOCXLayout.RunStyle? {
        for inline in paragraph.inlines {
            if case .text(_, let style) = inline { return style }
        }
        return nil
    }

    /// Dựng một đoạn chữ của SLIDE.
    ///
    /// Khác Word ở hai chỗ, và cả hai đều quan trọng: chữ mặc định trên slide là **trắng hay
    /// đen tuỳ nền** nên màu phải do chính tệp nói (không có thì để đen), và một hộp chữ
    /// PowerPoint không có "khổ giấy" — nó tự co theo hộp, nên không có trần chiều cao nào để
    /// thu ảnh về.
    static func attributed(
        slideParagraph paragraph: DOCXLayout.Paragraph, width: Double
    ) -> NSAttributedString {
        attributed(paragraph, box: CGSize(width: max(1, width), height: 100_000))
    }

    // MARK: - Bảng

    /// Dựng bảng bằng `NSTextTable` — bộ bố cục của TextKit tự tính chiều cao hàng và tự xuống
    /// dòng trong ô. Vẽ tay từng ô là tự nhận lấy phần khó nhất của bài toán.
    private static func attributed(_ table: DOCXLayout.Table, box: CGSize) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let columnCount = max(1, table.rows.map { $0.cells.reduce(0) { $0 + $1.columnSpan } }.max() ?? 1)

        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false

        for (rowIndex, row) in table.rows.enumerated() {
            var column = 0
            for cell in row.cells {
                let block = NSTextTableBlock(
                    table: textTable, startingRow: rowIndex, rowSpan: 1,
                    startingColumn: column, columnSpan: cell.columnSpan)
                if table.hasBorders {
                    block.setBorderColor(Tokens.Color.paperRule)
                    block.setWidth(0.5, type: .absoluteValueType, for: .border)
                }
                // Lề trong ô theo MẶC ĐỊNH CỦA WORD: trái/phải 108 twip (5,4 pt), **trên và
                // dưới bằng 0**.
                //
                // Bản đầu đặt 3 pt cho cả bốn cạnh, và cái giá đo được: 6 pt thừa mỗi hàng.
                // Một cuốn sách toán 308 bảng dựng ra dài hơn bản in 17%, trong khi cuốn ít
                // bảng chỉ lệch 1,5%. Đây là chỗ khác biệt ấy đi ra.
                block.setWidth(5.4, type: .absoluteValueType, for: .padding, edge: .minX)
                block.setWidth(5.4, type: .absoluteValueType, for: .padding, edge: .maxX)
                block.setWidth(0, type: .absoluteValueType, for: .padding, edge: .minY)
                block.setWidth(0, type: .absoluteValueType, for: .padding, edge: .maxY)
                if let shading = cell.shading { block.backgroundColor = color(shading) }
                if let cellWidth = cell.widthPt, cellWidth > 0 {
                    block.setValue(cellWidth, type: .absoluteValueType, for: .width)
                }

                // Ô rỗng vẫn phải có một đoạn: TextKit bỏ qua ô không có ký tự nào và bảng sẽ
                // lệch cột từ đó trở đi.
                let paragraphs = cell.paragraphs.isEmpty
                    ? [DOCXLayout.Paragraph(inlines: [.text("", DOCXLayout.RunStyle())])]
                    : cell.paragraphs

                for paragraph in paragraphs {
                    let piece = NSMutableAttributedString(attributedString:
                        attributed(paragraph, box: box, inTable: true))
                    piece.enumerateAttribute(
                        .paragraphStyle, in: NSRange(location: 0, length: piece.length)
                    ) { value, range, _ in
                        let base = (value as? NSParagraphStyle) ?? .default
                        // swiftlint:disable:next force_cast
                        let mutable = base.mutableCopy() as! NSMutableParagraphStyle
                        mutable.textBlocks = [block]
                        piece.addAttribute(.paragraphStyle, value: mutable, range: range)
                    }
                    result.append(piece)
                }
                column += cell.columnSpan
            }
        }

        // Một đoạn TRỐNG ngay sau bảng, không thuộc bảng: thiếu nó thì đoạn văn kế tiếp bị hút
        // vào ô cuối cùng và cả phần còn lại của tài liệu nằm trong bảng.
        result.append(NSAttributedString(
            string: "\n", attributes: [.paragraphStyle: NSParagraphStyle.default]))
        return result
    }

    // MARK: - Ảnh

    private static func attachment(
        for image: DOCXLayout.Image, box: CGSize
    ) -> NSTextAttachment? {
        guard let picture = NSImage(data: Data(image.data)) else { return nil }

        var width = image.widthPt
        var height = image.heightPt
        if width <= 0 || height <= 0 {
            // Không có `wp:extent`: lấy khổ thật của ảnh, quy 96 dpi về point như Word làm.
            width = Double(picture.size.width) * 72 / 96
            height = Double(picture.size.height) * 72 / 96
        }
        // Ảnh rộng hơn vùng chữ thì thu lại theo tỉ lệ. Không thu thì nó tràn ra ngoài lề và
        // phần thừa bị cắt cụt — người đọc thấy một nửa bức hình mà không hiểu vì sao.
        if width > box.width, width > 0 {
            height *= box.width / width
            width = box.width
        }
        // Và trần theo CHIỀU CAO vùng chữ. Một ảnh cao hơn cả trang không bao giờ vừa vào ô chứa
        // nào — bộ phân trang khi ấy thêm ô chứa mãi mà không ô nào nhận được gì, tức là treo.
        if height > box.height, height > 0 {
            width *= box.height / height
            height = box.height
        }

        let attachment = NSTextAttachment()
        let cell = NSTextAttachmentCell(imageCell: picture)
        attachment.attachmentCell = cell
        picture.size = NSSize(width: width, height: height)
        attachment.bounds = NSRect(x: 0, y: 0, width: width, height: height)
        return attachment
    }

    // MARK: - Hình thức

    private static func paragraphStyle(
        _ style: DOCXLayout.ParagraphStyle, inTable: Bool
    ) -> NSParagraphStyle {
        let result = NSMutableParagraphStyle()
        switch style.alignment {
        case .left: result.alignment = .left
        case .center: result.alignment = .center
        case .right: result.alignment = .right
        case .justified: result.alignment = .justified
        }
        result.paragraphSpacingBefore = style.spaceBeforePt
        result.paragraphSpacing = style.spaceAfterPt
        result.lineHeightMultiple = style.lineSpacing
        result.headIndent = style.indentLeftPt
        result.firstLineHeadIndent = style.indentLeftPt + max(0, style.firstLineIndentPt)
        if style.listMarker != nil {
            // Dấu đầu mục và chữ cách nhau bằng một điểm dừng tab, để dòng thứ hai của mục thẳng
            // hàng với dòng thứ nhất chứ không thụt về sát dấu.
            result.tabStops = [NSTextTab(textAlignment: .left, location: style.indentLeftPt + 18)]
            result.headIndent = style.indentLeftPt + 18
        }
        // Trong ô bảng thì bỏ khoảng cách trước/sau: chúng cộng dồn với padding của ô và làm mỗi
        // hàng cao gấp đôi thứ Word vẽ ra.
        if inTable {
            result.paragraphSpacingBefore = 0
            result.paragraphSpacing = 0
        }
        return result
    }

    private static func attributes(
        for run: DOCXLayout.RunStyle, paragraphStyle: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(named: run.fontName, size: run.sizePt, bold: run.bold, italic: run.italic),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: run.color.map(color) ?? NSColor.black,
        ]
        if run.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if run.strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let highlight = run.highlight { attributes[.backgroundColor] = color(highlight) }
        if run.verticalAlign != 0 {
            attributes[.superscript] = run.verticalAlign
        }
        return attributes
    }

    /// Chữ trên trang giấy luôn ĐEN mặc định, không lấy màu chữ của theme.
    ///
    /// Trang là một tờ giấy trắng kể cả khi ứng dụng đang ở giao diện tối. Lấy `editorInk` thì ở
    /// chế độ tối chữ sẽ gần trắng — trắng trên trắng.
    static func color(_ value: DOCXLayout.Color) -> NSColor {
        NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

    /// Tìm font theo tên Word, kèm đậm/nghiêng.
    ///
    /// **Tên font trong tệp thường KHÔNG có trên máy này** — "Calibri", "Cambria", "Times New
    /// Roman" là font của Windows. Rơi về một font hệ thống là đúng; rơi về font không dựng được
    /// dấu tiếng Việt thì không. Nên đường dự phòng đi qua `NSFont.systemFont`, thứ luôn có đủ
    /// chữ Việt trên macOS.
    private static func font(
        named name: String?, size: Double, bold: Bool, italic: Bool
    ) -> NSFont {
        let pointSize = max(1, min(400, size))
        let key = FontKey(name: name, size: pointSize, bold: bold, italic: italic)
        if let cached = fontCache.withLock({ $0[key] }) { return cached }

        var resolved: NSFont?
        if let name, !name.isEmpty {
            resolved = NSFont(name: name, size: pointSize)
            if resolved == nil {
                // Tên họ font, ví dụ "Arial Narrow", không phải tên PostScript.
                resolved = NSFontManager.shared.font(
                    withFamily: name, traits: [], weight: 5, size: pointSize)
            }
        }
        var result = resolved ?? NSFont.systemFont(ofSize: pointSize)
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            result = NSFontManager.shared.convert(result, toHaveTrait: traits)
            // `convert` trả về CHÍNH font cũ khi họ font không có kiểu đậm — không phải nil, nên
            // không có cách nào biết nó đã thất bại ngoài việc so lại đặc tính. Font hệ thống
            // luôn có đủ bốn kiểu, nên đó là đường lui đúng.
            let got = NSFontManager.shared.traits(of: result)
            if bold && !got.contains(.boldFontMask) {
                result = NSFontManager.shared.convert(
                    NSFont.systemFont(ofSize: pointSize), toHaveTrait: traits)
            }
        }
        fontCache.withLock { $0[key] = result }
        return result
    }

    private struct FontKey: Hashable {
        var name: String?
        var size: Double
        var bold: Bool
        var italic: Bool
    }

    /// Tra font là phép ĐẮT — `NSFontManager` đi hỏi hệ thống mỗi lần. Một tài liệu 300 trang có
    /// hàng chục nghìn run, và không có bộ nhớ đệm thì riêng việc dựng chuỗi mất vài giây.
    private static let fontCache = Lock<[FontKey: NSFont]>([:])
}

/// Ổ khoá tối giản cho bộ nhớ đệm dùng chung.
final class Lock<Value>: @unchecked Sendable {
    private var value: Value
    private let mutex = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        mutex.lock()
        defer { mutex.unlock() }
        return body(&value)
    }
}
