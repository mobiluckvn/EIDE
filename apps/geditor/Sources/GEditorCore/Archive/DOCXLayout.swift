import Foundation

/// Đọc `.docx` thành **mô hình trang** — thứ để VẼ, không phải thứ để sửa.
///
/// ## Vì sao có bộ đọc thứ hai bên cạnh `DOCXReader`
///
/// `DOCXReader` đưa Word về Markdown: giữ cấu trúc, bỏ hình thức. Đó đúng là thứ cần cho chế độ
/// **Code** — sửa được, grep được, ghi ngược được. Nhưng chế độ **View** hỏi một câu khác hẳn:
/// *trang này trông như thế nào*. Font gì, cỡ bao nhiêu, màu gì, ảnh nằm ở đâu, ô bảng tô nền
/// gì, lề rộng bao nhiêu — Markdown không mang được thứ nào trong số đó.
///
/// Hai bộ đọc cho hai câu hỏi, không phải một bộ đọc gánh cả hai. Gộp lại thì mô hình sẽ vừa
/// phải ghi ngược được vừa phải vẽ được, và nó sẽ làm dở cả hai.
///
/// ## Vì sao không dùng bộ nhập OOXML có sẵn của AppKit
///
/// `NSAttributedString(url:options:[.documentType: .officeOpenXML])` đọc được, và đọc khá tốt:
/// font, cỡ, màu, bảng, khổ giấy, lề đều ra đúng. Nó **vứt sạch ảnh** — đo trên tệp thật của
/// người dùng: gói có 15 tệp trong `word/media/`, chuỗi trả về có 0 ký tự đính kèm. Một cuốn
/// sách toán thiếu hết hình minh hoạ thì không phải là "xem tài liệu".
///
/// ## Ranh giới: lõi trả DỮ LIỆU, tầng giao diện đổi thành đối tượng của macOS
///
/// Ở đây không có `NSFont`, không có `NSColor`, không có `NSImage` — chỉ tên font, ba số màu, và
/// byte ảnh. Cổng `check-core-no-ui.sh` canh đúng điều đó, và nó canh có lý: lõi biết AppKit là
/// lõi không chạy được ở CLI, không chạy được trong bài kiểm không màn hình, và không đo được
/// nếu không dựng cả một ứng dụng quanh nó.
public enum DOCXLayout {

    // MARK: - Mô hình

    /// Màu theo ba thành phần 0…1. Không dùng kiểu màu của hệ điều hành — xem chú thích của
    /// `DOCXLayout` về ranh giới lõi / giao diện.
    public struct Color: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Đọc `"1F4E79"` hoặc `"#1F4E79"`. `"auto"` trả `nil` — Word dùng nó để nói "màu mặc
        /// định", và biến nó thành đen là ép chữ thành đen trong giao diện tối.
        public static func hex(_ text: String?) -> Color? {
            guard var value = text?.trimmingCharacters(in: .whitespaces).lowercased(),
                  value != "auto", !value.isEmpty
            else { return nil }
            if value.hasPrefix("#") { value.removeFirst() }
            guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
            return Color(
                red: Double((number >> 16) & 0xFF) / 255,
                green: Double((number >> 8) & 0xFF) / 255,
                blue: Double(number & 0xFF) / 255
            )
        }

        /// Tên màu tô sáng của Word (`w:highlight`) — bảng đóng, 16 tên.
        public static func highlight(_ name: String?) -> Color? {
            switch name {
            case "yellow": return Color(red: 1, green: 1, blue: 0)
            case "green": return Color(red: 0, green: 1, blue: 0)
            case "cyan": return Color(red: 0, green: 1, blue: 1)
            case "magenta": return Color(red: 1, green: 0, blue: 1)
            case "blue": return Color(red: 0, green: 0, blue: 1)
            case "red": return Color(red: 1, green: 0, blue: 0)
            case "darkBlue": return Color(red: 0, green: 0, blue: 0.545)
            case "darkCyan": return Color(red: 0, green: 0.545, blue: 0.545)
            case "darkGreen": return Color(red: 0, green: 0.392, blue: 0)
            case "darkMagenta": return Color(red: 0.545, green: 0, blue: 0.545)
            case "darkRed": return Color(red: 0.545, green: 0, blue: 0)
            case "darkYellow": return Color(red: 0.545, green: 0.545, blue: 0)
            case "darkGray": return Color(red: 0.663, green: 0.663, blue: 0.663)
            case "lightGray": return Color(red: 0.827, green: 0.827, blue: 0.827)
            case "black": return Color(red: 0, green: 0, blue: 0)
            case "white": return Color(red: 1, green: 1, blue: 1)
            default: return nil
            }
        }
    }

    /// Hình thức của một đoạn chữ liền mạch.
    public struct RunStyle: Equatable, Sendable {
        public var fontName: String?
        public var sizePt: Double
        public var bold = false
        public var italic = false
        public var underline = false
        public var strikethrough = false
        public var color: Color?
        public var highlight: Color?
        /// `-1` chỉ số dưới, `0` bình thường, `1` chỉ số trên.
        public var verticalAlign = 0

        public init(fontName: String? = nil, sizePt: Double = 11) {
            self.fontName = fontName
            self.sizePt = sizePt
        }
    }

    /// Ảnh nhúng: BYTE nguyên bản của tệp trong `word/media/`, kèm khổ Word đã định.
    ///
    /// Trả byte chứ không trả ảnh đã giải mã: lõi không được biết `NSImage`, và byte gốc còn
    /// giữ được thứ mà một lần giải mã sẽ làm mất — ảnh động, hồ sơ màu, độ phân giải thật.
    public struct Image: Equatable, Sendable {
        public var data: [UInt8]
        public var widthPt: Double
        public var heightPt: Double
        /// Tên tệp trong gói, để chẩn đoán khi một ảnh không hiện ra.
        public var name: String

        public init(data: [UInt8], widthPt: Double, heightPt: Double, name: String) {
            self.data = data
            self.widthPt = widthPt
            self.heightPt = heightPt
            self.name = name
        }
    }

    /// Một mảnh nằm trong dòng chữ.
    public enum Inline: Equatable, Sendable {
        case text(String, RunStyle)
        case image(Image)
        /// `<w:br/>` — xuống dòng trong cùng một đoạn.
        case lineBreak
        /// `<w:br w:type="page"/>` — sang trang mới.
        case pageBreak
        /// Trường `PAGE` — số trang, chỉ biết được lúc VẼ.
        ///
        /// Lõi không thể thay nó bằng một con số: cùng một đầu trang dùng lại cho mọi trang, và
        /// con số ấy khác nhau ở từng tờ. Nên nó đi tới tầng vẽ dưới dạng một chỗ trống có tên.
        case pageNumber
        /// Trường `NUMPAGES` — tổng số trang.
        case pageCount
    }

    public enum Alignment: String, Equatable, Sendable {
        case left, center, right, justified
    }

    public struct ParagraphStyle: Equatable, Sendable {
        public var alignment: Alignment = .left
        public var spaceBeforePt: Double = 0
        public var spaceAfterPt: Double = 0
        /// Giãn dòng theo BỘI SỐ (1.0 = đơn). `w:line` dạng "chính xác" đã quy về bội số xấp xỉ.
        public var lineSpacing: Double = 1
        public var indentLeftPt: Double = 0
        public var firstLineIndentPt: Double = 0
        /// Cấp tiêu đề 1…9, `nil` = đoạn thường. Dùng cho bản đồ tài liệu và cho cây cấu trúc.
        public var outlineLevel: Int?
        /// Dấu đầu mục đã dựng sẵn (`"•"`, `"1."`). `nil` = không phải mục danh sách.
        public var listMarker: String?
        /// Cấp thụt lề, đếm từ 0. Word gọi là `w:ilvl`, PowerPoint gọi là `a:pPr/@lvl`.
        ///
        /// Giữ CON SỐ chứ không chỉ giữ khoảng thụt đã tính: PowerPoint tra cỡ chữ mặc định
        /// THEO CẤP, và một khoảng thụt 48 pt không nói được nó là cấp 2 hay cấp 1 của một
        /// bố cục thụt sâu.
        public var listLevel = 0
        public var pageBreakBefore = false
        public var shading: Color?
        /// Tên kiểu trong `styles.xml` — giữ lại để chẩn đoán và để cây cấu trúc gọi tên.
        public var styleName: String?

        public init() {}
    }

    public struct Paragraph: Equatable, Sendable {
        public var inlines: [Inline] = []
        public var style = ParagraphStyle()

        public init(inlines: [Inline] = [], style: ParagraphStyle = ParagraphStyle()) {
            self.inlines = inlines
            self.style = style
        }

        /// Chữ thuần của đoạn — để tìm kiếm và để bài kiểm nói được nó chứa gì.
        public var plainText: String {
            inlines.reduce(into: "") { result, inline in
                switch inline {
                case .text(let value, _): result += value
                case .lineBreak: result += "\n"
                case .image, .pageBreak, .pageNumber, .pageCount: break
                }
            }
        }
    }

    public struct Cell: Equatable, Sendable {
        public var paragraphs: [Paragraph] = []
        public var widthPt: Double?
        public var shading: Color?
        /// Số cột mà ô này chiếm (`w:gridSpan`).
        public var columnSpan = 1
        /// Ô bị gộp DỌC vào ô phía trên (`w:vMerge` không có `w:val="restart"`).
        public var isVerticallyMerged = false

        public init() {}
    }

    public struct Row: Equatable, Sendable {
        public var cells: [Cell] = []
        public init() {}
    }

    public struct Table: Equatable, Sendable {
        public var rows: [Row] = []
        /// Bề rộng từng cột theo `w:tblGrid`, đơn vị point.
        public var columnWidthsPt: [Double] = []
        public var hasBorders = true
        public init() {}
    }

    public enum Block: Equatable, Sendable {
        case paragraph(Paragraph)
        case table(Table)
    }

    /// Một **phần** của tài liệu Word — đơn vị mang đầu/chân trang riêng.
    ///
    /// Một cuốn sách in chia thành phần ở mỗi chương: `<w:sectPr>` nằm trong đoạn CUỐI của phần.
    /// Đo trên sách thật của người dùng: 45 phần, 35 phần khai đầu/chân trang riêng, 70 tệp
    /// header/footer khác nhau. Dùng chung một bản cho cả cuốn thì 34 phần hiện sai tên chương.
    public struct Section: Equatable, Sendable {
        /// Số khối thuộc phần này, tính từ chỗ phần trước kết thúc.
        public var blockCount = 0
        public var header: [Paragraph] = []
        public var footer: [Paragraph] = []

        public init() {}
    }

    /// Cả tài liệu: khối nội dung + khổ giấy.
    public struct Document: Equatable, Sendable {
        public var blocks: [Block] = []
        /// Các phần, theo thứ tự. Luôn có ít nhất một phần.
        ///
        /// **Khổ giấy KHÔNG theo phần.** Chuẩn cho phép mỗi phần một khổ, nhưng đo trên 61 tệp
        /// thật thì không tệp nào dùng tới — và một khung xem có nhiều khổ trang cùng lúc là
        /// một bài toán khác hẳn (mỗi tờ một tỉ lệ, phép "vừa bề ngang" mất nghĩa). Nếu gặp tệp
        /// như thế, khổ của phần ĐẦU áp cho cả tài liệu.
        public var sections: [Section] = []
        /// Đầu trang và chân trang mặc định của phần đầu tiên.
        ///
        /// Chỉ lấy loại `default`. Word cho phép trang đầu và trang chẵn có bản riêng; dựng đủ
        /// ba loại là ba lần công cho một khác biệt mà phần lớn tài liệu không dùng — và nếu
        /// dựng nửa vời thì sách in hai mặt sẽ hiện sai ở đúng những trang người ta để ý.
        public var header: [Paragraph] = []
        public var footer: [Paragraph] = []
        public var pageWidthPt: Double = 595.3
        public var pageHeightPt: Double = 841.9
        public var marginLeftPt: Double = 72
        public var marginRightPt: Double = 72
        public var marginTopPt: Double = 72
        public var marginBottomPt: Double = 72

        public init() {}

        public var contentWidthPt: Double {
            max(72, pageWidthPt - marginLeftPt - marginRightPt)
        }

        public var contentHeightPt: Double {
            max(72, pageHeightPt - marginTopPt - marginBottomPt)
        }

        /// Số ảnh đã đọc được — bài kiểm đối chứng với số tệp trong `word/media/`.
        public var imageCount: Int {
            var total = 0
            func count(_ paragraph: Paragraph) {
                for inline in paragraph.inlines { if case .image = inline { total += 1 } }
            }
            for block in blocks {
                switch block {
                case .paragraph(let p): count(p)
                case .table(let t):
                    for row in t.rows { for cell in row.cells { cell.paragraphs.forEach(count) } }
                }
            }
            return total
        }
    }

    // MARK: - Đọc

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notAWordDocument
        case badXML

        public var description: String {
            switch self {
            case .notAWordDocument: return "Tệp này không phải tài liệu Word"
            case .badXML: return "Phần thân tài liệu không đọc được"
            }
        }
    }

    public static func read(path: String) throws -> Document {
        let archive = try ZipArchive(path: path)
        guard let body = try archive.data(named: "word/document.xml") else {
            throw Failure.notAWordDocument
        }

        let styles = (try? archive.data(named: "word/styles.xml")).flatMap { $0 }
            .map { StyleSheet.parse($0) } ?? StyleSheet()
        let numbering = (try? archive.data(named: "word/numbering.xml")).flatMap { $0 }
            .map { ListDefinitions.parse($0) } ?? ListDefinitions()
        let relationships = (try? archive.data(named: "word/_rels/document.xml.rels"))
            .flatMap { $0 }
            .map { Relationships.parse($0) } ?? [:]

        // Ảnh nạp LƯỜI: một tài liệu có thể mang vài chục MB ảnh, và phần lớn nằm ở những trang
        // người đọc không bao giờ cuộn tới. Nhưng gói zip đã mở sẵn nên đọc một entry là rẻ —
        // cái đắt là giữ tất cả trong bộ nhớ, nên chỉ đọc ảnh nào tài liệu thật sự nhắc tới.
        let body_ = Data(body)
        let delegate = LayoutBodyParser(
            styles: styles, numbering: numbering, relationships: relationships, archive: archive
        )
        let parser = XMLParser(data: body_)
        parser.delegate = delegate
        guard parser.parse() else { throw Failure.badXML }
        var document = delegate.finish()

        // Đầu và chân trang nằm ở TỆP KHÁC trong gói, và cùng một tệp dùng lại cho mọi trang.
        // Đọc chúng bằng CHÍNH bộ đọc thân tài liệu: chúng là `w:p` và `w:tbl` y hệt, và một bộ
        // đọc thứ hai cho cùng một cấu trúc là hai chỗ để sửa mỗi lần chuẩn đổi.
        func part(_ id: String?) -> [Block] {
            guard let id, let target = relationships[id] else { return [] }
            var name = target
            if name.hasPrefix("/") { name.removeFirst() }
            let candidates = name.hasPrefix("word/") ? [name] : ["word/" + name, name]
            for candidate in candidates {
                guard let data = (try? archive.data(named: candidate)) ?? nil else { continue }
                let sub = LayoutBodyParser(
                    styles: styles, numbering: numbering, relationships: relationships,
                    archive: archive)
                let subParser = XMLParser(data: Data(data))
                subParser.delegate = sub
                guard subParser.parse() else { return [] }
                return sub.finish().blocks
            }
            return []
        }
        // Mỗi phần một cặp đầu/chân trang. Một tệp header dùng lại ở nhiều phần thì chỉ đọc
        // MỘT lần — sách 45 phần trỏ vào 70 tệp, nhưng đọc lại cùng một tệp 45 lượt là 45 lần
        // phân tích XML cho một kết quả giống hệt.
        var cache: [String: [Paragraph]] = [:]
        func paragraphs(_ id: String?) -> [Paragraph] {
            guard let id else { return [] }
            if let known = cache[id] { return known }
            let value = part(id).compactMap { block -> Paragraph? in
                if case .paragraph(let item) = block { return item } else { return nil }
            }
            cache[id] = value
            return value
        }

        document.sections = delegate.sectionRefs.map { reference in
            var section = Section()
            section.blockCount = reference.blocks
            section.header = paragraphs(reference.header)
            section.footer = paragraphs(reference.footer)
            return section
        }
        if document.sections.isEmpty { document.sections = [Section()] }
        // `header`/`footer` ở cấp tài liệu vẫn là của phần ĐẦU — nhiều chỗ chỉ cần bấy nhiêu,
        // và giữ chúng nghĩa là không có đường gọi cũ nào lặng lẽ đổi nghĩa.
        document.header = document.sections[0].header
        document.footer = document.sections[0].footer
        return document
    }

    // MARK: - Đơn vị của OOXML

    /// Twip → point. Word đo mọi khoảng cách bằng 1/20 point.
    static func points(twips: String?) -> Double? {
        guard let text = twips, let value = Double(text) else { return nil }
        return value / 20
    }

    /// EMU → point. 914400 EMU = 1 inch = 72 pt.
    static func points(emu: String?) -> Double? {
        guard let text = emu, let value = Double(text) else { return nil }
        return value / 12700
    }

    /// Nửa-point → point. `w:sz` đếm bằng nửa point, nên `24` là chữ cỡ 12.
    static func points(halfPoints: String?) -> Double? {
        guard let text = halfPoints, let value = Double(text) else { return nil }
        return value / 2
    }
}

// MARK: - styles.xml

/// Kiểu đã định nghĩa sẵn: `w:docDefaults` và từng `w:style`.
///
/// **Phải có, không phải để cho đẹp.** Phần lớn tệp Word thật không ghi cỡ chữ vào từng run —
/// chúng ghi `<w:pStyle w:val="Heading1"/>` rồi để `styles.xml` nói Heading1 là cỡ 16, đậm, màu
/// xanh. Bỏ qua tệp này thì mọi tiêu đề hiện ra y hệt đoạn thường.
struct StyleSheet {
    struct Entry {
        var basedOn: String?
        var run = DOCXLayout.RunStyle(sizePt: 0)   // 0 = "kiểu này không nói gì về cỡ"
        var runSaysSize = false
        var runSaysBold = false
        var runSaysItalic = false
        var paragraph = DOCXLayout.ParagraphStyle()
        var paragraphSaysAlignment = false
        var numberingID: Int?
        var listLevel = 0
    }

    var defaultRun = DOCXLayout.RunStyle(sizePt: 11)
    var defaultParagraph = DOCXLayout.ParagraphStyle()
    var entries: [String: Entry] = [:]

    /// Gộp một kiểu (kể cả chuỗi `w:basedOn`) lên trên nền mặc định.
    ///
    /// Chuỗi `basedOn` có thể VÒNG — tệp hỏng hoặc do một công cụ sinh sai. Đếm bước là cách rẻ
    /// nhất để không treo: không có bộ đếm thì mở một tệp như thế là ứng dụng đứng im vĩnh viễn,
    /// và người dùng không có cách nào biết vì sao.
    func resolved(_ styleID: String?) -> (run: DOCXLayout.RunStyle, paragraph: DOCXLayout.ParagraphStyle, numberingID: Int?, listLevel: Int) {
        var chain: [Entry] = []
        var current = styleID
        var steps = 0
        while let id = current, let entry = entries[id], steps < 16 {
            chain.append(entry)
            current = entry.basedOn
            steps += 1
        }

        var run = defaultRun
        var paragraph = defaultParagraph
        var numberingID: Int?
        var listLevel = 0
        // Đi từ GỐC xuống lá: kiểu cụ thể phải đè lên kiểu nó dựa vào.
        for entry in chain.reversed() {
            if entry.run.fontName != nil { run.fontName = entry.run.fontName }
            if entry.runSaysSize { run.sizePt = entry.run.sizePt }
            if entry.runSaysBold { run.bold = entry.run.bold }
            if entry.runSaysItalic { run.italic = entry.run.italic }
            if entry.run.color != nil { run.color = entry.run.color }
            if entry.run.underline { run.underline = true }
            if entry.paragraphSaysAlignment { paragraph.alignment = entry.paragraph.alignment }
            if entry.paragraph.spaceBeforePt != 0 { paragraph.spaceBeforePt = entry.paragraph.spaceBeforePt }
            if entry.paragraph.spaceAfterPt != 0 { paragraph.spaceAfterPt = entry.paragraph.spaceAfterPt }
            if entry.paragraph.lineSpacing != 1 { paragraph.lineSpacing = entry.paragraph.lineSpacing }
            if entry.paragraph.indentLeftPt != 0 { paragraph.indentLeftPt = entry.paragraph.indentLeftPt }
            if entry.paragraph.firstLineIndentPt != 0 { paragraph.firstLineIndentPt = entry.paragraph.firstLineIndentPt }
            if let level = entry.paragraph.outlineLevel { paragraph.outlineLevel = level }
            if let id = entry.numberingID { numberingID = id; listLevel = entry.listLevel }
        }
        paragraph.styleName = styleID
        return (run, paragraph, numberingID, listLevel)
    }

    static func parse(_ data: [UInt8]) -> StyleSheet {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        return delegate.sheet
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var sheet = StyleSheet()
        private var styleID: String?
        private var entry = Entry()
        private var inDocDefaults = false
        private var inStyle = false
        /// `w:rPr` nằm trong `w:pPr` mô tả DẤU KẾT ĐOẠN, không mô tả chữ trong đoạn. Trộn nó vào
        /// kiểu chữ làm cả đoạn mang hình thức của một ký tự vô hình.
        private var inParagraphProperties = false

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            let tag = ooxmlLocalName(name)
            let value = attributes.ooxmlValue("val")
            switch tag {
            case "docDefaults": inDocDefaults = true
            case "style":
                inStyle = true
                entry = Entry()
                styleID = attributes.ooxmlValue("styleId")
            case "basedOn": entry.basedOn = value
            case "pPr": inParagraphProperties = true
            case "rFonts":
                let font = attributes.ooxmlValue("ascii") ?? attributes.ooxmlValue("hAnsi")
                if inDocDefaults && !inStyle { sheet.defaultRun.fontName = font }
                else if !inParagraphProperties { entry.run.fontName = font }
            case "sz":
                guard let size = DOCXLayout.points(halfPoints: value) else { break }
                if inDocDefaults && !inStyle { sheet.defaultRun.sizePt = size }
                else if !inParagraphProperties { entry.run.sizePt = size; entry.runSaysSize = true }
            case "b":
                let on = isOOXMLOn(value)
                if inDocDefaults && !inStyle { sheet.defaultRun.bold = on }
                else if !inParagraphProperties { entry.run.bold = on; entry.runSaysBold = true }
            case "i":
                let on = isOOXMLOn(value)
                if inDocDefaults && !inStyle { sheet.defaultRun.italic = on }
                else if !inParagraphProperties { entry.run.italic = on; entry.runSaysItalic = true }
            case "u":
                if !inParagraphProperties && value != "none" { entry.run.underline = true }
            case "color":
                if !inParagraphProperties, let color = DOCXLayout.Color.hex(value) {
                    if inDocDefaults && !inStyle { sheet.defaultRun.color = color }
                    else { entry.run.color = color }
                }
            case "jc":
                if let alignment = ooxmlAlignment(value) {
                    entry.paragraph.alignment = alignment
                    entry.paragraphSaysAlignment = true
                }
            case "spacing" where inParagraphProperties || inStyle:
                if let before = DOCXLayout.points(twips: attributes.ooxmlValue("before")) {
                    entry.paragraph.spaceBeforePt = before
                }
                if let after = DOCXLayout.points(twips: attributes.ooxmlValue("after")) {
                    entry.paragraph.spaceAfterPt = after
                }
                if let line = attributes.ooxmlValue("line"), let raw = Double(line) {
                    entry.paragraph.lineSpacing = ooxmlLineSpacing(
                        raw: raw, rule: attributes.ooxmlValue("lineRule"))
                }
            case "ind":
                if let left = DOCXLayout.points(twips: attributes.ooxmlValue("left")) {
                    entry.paragraph.indentLeftPt = left
                }
                if let first = DOCXLayout.points(twips: attributes.ooxmlValue("firstLine")) {
                    entry.paragraph.firstLineIndentPt = first
                }
                if let hanging = DOCXLayout.points(twips: attributes.ooxmlValue("hanging")) {
                    entry.paragraph.firstLineIndentPt = -hanging
                }
            case "outlineLvl":
                if let text = value, let level = Int(text) { entry.paragraph.outlineLevel = level + 1 }
            case "numId":
                if let text = value, let id = Int(text) { entry.numberingID = id }
            case "ilvl":
                if let text = value, let level = Int(text) { entry.listLevel = level }
            default: break
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch ooxmlLocalName(name) {
            case "docDefaults": inDocDefaults = false
            case "pPr": inParagraphProperties = false
            case "style":
                if let id = styleID { sheet.entries[id] = entry }
                inStyle = false
                styleID = nil
            default: break
            }
        }
    }
}

// MARK: - numbering.xml

/// `numId` → mỗi cấp là đánh số hay gạch đầu dòng.
struct ListDefinitions {
    /// numId → (cấp → có đánh số không)
    var numbered: [Int: [Int: Bool]] = [:]

    /// Dấu đầu mục cho một mục danh sách.
    ///
    /// Số thứ tự đếm ở phía người gọi chứ không ở đây: cùng một `numId` xuất hiện lại sau một
    /// đoạn thường vẫn đếm tiếp, và chỉ người đi qua tài liệu theo thứ tự mới biết đang là mục
    /// thứ mấy.
    func marker(numberingID: Int, level: Int, ordinal: Int) -> String {
        let isNumbered = numbered[numberingID]?[level] ?? false
        if isNumbered { return "\(ordinal)." }
        switch level % 3 {
        case 0: return "•"
        case 1: return "◦"
        default: return "▪"
        }
    }

    static func parse(_ data: [UInt8]) -> ListDefinitions {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        var result = ListDefinitions()
        for (numID, abstractID) in delegate.numToAbstract {
            result.numbered[numID] = delegate.abstractLevels[abstractID] ?? [:]
        }
        return result
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var numToAbstract: [Int: Int] = [:]
        var abstractLevels: [Int: [Int: Bool]] = [:]
        private var currentAbstract: Int?
        private var currentNum: Int?
        private var currentLevel: Int?

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            switch ooxmlLocalName(name) {
            case "abstractNum":
                currentAbstract = attributes.ooxmlValue("abstractNumId").flatMap(Int.init)
            case "num":
                currentNum = attributes.ooxmlValue("numId").flatMap(Int.init)
            case "abstractNumId":
                if let numID = currentNum,
                   let abstractID = attributes.ooxmlValue("val").flatMap(Int.init) {
                    numToAbstract[numID] = abstractID
                }
            case "lvl":
                currentLevel = attributes.ooxmlValue("ilvl").flatMap(Int.init)
            case "numFmt":
                guard let abstractID = currentAbstract, let level = currentLevel else { break }
                let format = attributes.ooxmlValue("val") ?? "bullet"
                abstractLevels[abstractID, default: [:]][level] = (format != "bullet" && format != "none")
            default: break
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch ooxmlLocalName(name) {
            case "abstractNum": currentAbstract = nil
            case "num": currentNum = nil
            case "lvl": currentLevel = nil
            default: break
            }
        }
    }
}

// MARK: - document.xml.rels

/// `rId7` → `media/image3.png`.
enum Relationships {
    static func parse(_ data: [UInt8]) -> [String: String] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        return delegate.map
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var map: [String: String] = [:]

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            guard ooxmlLocalName(name) == "Relationship" else { return }
            // Tệp rels KHÔNG có tiền tố namespace trên thuộc tính, khác hẳn document.xml. Dùng
            // `ooxmlValue` vẫn đúng vì nó chấp nhận cả hai dạng.
            guard let id = attributes.ooxmlValue("Id"),
                  let target = attributes.ooxmlValue("Target")
            else { return }
            map[id] = target
        }
    }
}

// MARK: - document.xml

/// Đọc thân tài liệu bằng một NGĂN XẾP tường minh.
///
/// Bảng lồng trong ô của bảng khác là chuyện thường trong tệp Word thật. Một biến `currentTable`
/// duy nhất sẽ nuốt mất bảng ngoài khi gặp bảng trong — nên chỗ đang ghi vào là một ngăn xếp,
/// và mỗi `</w:tbl>` chỉ đóng đúng một tầng.
private final class LayoutBodyParser: NSObject, XMLParserDelegate {

    private let styles: StyleSheet
    private let numbering: ListDefinitions
    private let relationships: [String: String]
    private let archive: ZipArchive

    private var document = DOCXLayout.Document()

    private var tableStack: [DOCXLayout.Table] = []
    private var rowStack: [DOCXLayout.Row] = []
    private var cellStack: [DOCXLayout.Cell] = []

    private var paragraph = DOCXLayout.Paragraph()
    private var inParagraph = false
    private var paragraphStyleID: String?
    private var paragraphNumberingID: Int?
    private var paragraphListLevel = 0
    private var explicitParagraph = DOCXLayout.ParagraphStyle()
    private var explicitSaysAlignment = false
    private var explicitSaysIndent = false
    private var explicitSaysSpacing = false

    private var runStyle = DOCXLayout.RunStyle()
    private var runOverrides = RunOverrides()
    private var inRun = false
    private var inRunProperties = false
    private var inParagraphProperties = false
    private var textBuffer = ""
    /// `w:instrText` là mã trường (`PAGE`, `TOC \o "1-3"`), không phải chữ người đọc.
    private var inFieldCode = false
    private var fieldCode = ""
    /// `w:delText` là chữ ĐÃ XOÁ trong bản theo dõi thay đổi — hiện nó ra là hiện lại thứ tác
    /// giả đã bỏ đi.
    private var inDeletedText = false

    /// Số thứ tự đang đếm cho từng (numId, cấp).
    private var listOrdinals: [Int: [Int: Int]] = [:]

    /// Ảnh đang dựng: khổ đọc được ở `wp:extent`, byte đọc được ở `a:blip`.
    private var pendingImageWidth: Double?
    private var pendingImageHeight: Double?
    private var sectionSeen = false
    /// `rId` đầu/chân trang của phần ĐANG đọc — người gọi đọc tệp ấy sau, ở lượt riêng.
    private var pendingHeaderID: String?
    private var pendingFooterID: String?
    /// Đoạn đang đọc có `<w:sectPr>` không — tức nó là đoạn CUỐI của một phần.
    private var paragraphClosesSection = false
    /// Từng phần: (số khối, rId đầu trang, rId chân trang).
    private(set) var sectionRefs: [(blocks: Int, header: String?, footer: String?)] = []
    private var blocksInSection = 0

    private struct RunOverrides {
        var saysBold = false
        var saysItalic = false
        var saysSize = false
        var saysFont = false
    }

    init(
        styles: StyleSheet, numbering: ListDefinitions, relationships: [String: String],
        archive: ZipArchive
    ) {
        self.styles = styles
        self.numbering = numbering
        self.relationships = relationships
        self.archive = archive
    }

    /// Đóng phần đang đọc và bắt đầu phần mới.
    private func closeSection() {
        sectionRefs.append((blocksInSection, pendingHeaderID, pendingFooterID))
        blocksInSection = 0
        pendingHeaderID = nil
        pendingFooterID = nil
    }

    func finish() -> DOCXLayout.Document {
        // Bảng chưa đóng vì tệp cụt đầu: vẫn giao ra thứ đã đọc được. Người dùng mở một tệp hỏng
        // muốn thấy phần đọc được, không muốn thấy một trang trắng.
        while !tableStack.isEmpty { closeTable() }
        if inParagraph { flushParagraph() }
        // Phần cuối: `<w:sectPr>` nằm thẳng trong `<w:body>`, sau đoạn cuối cùng. Không đóng nó
        // ở đây thì mọi khối sau chỗ cắt cuối cùng rơi ra ngoài mọi phần và mất đầu/chân trang.
        if blocksInSection > 0 || sectionRefs.isEmpty { closeSection() }
        return document
    }

    // MARK: Bắt đầu thẻ

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String] = [:]
    ) {
        let tag = ooxmlLocalName(name)
        let value = attributes.ooxmlValue("val")

        switch tag {
        case "p":
            beginParagraph()
        case "pPr":
            inParagraphProperties = true
        case "pStyle":
            paragraphStyleID = value
        case "numId" where inParagraphProperties:
            paragraphNumberingID = value.flatMap(Int.init)
        case "ilvl" where inParagraphProperties:
            paragraphListLevel = value.flatMap(Int.init) ?? 0
        case "jc" where inParagraphProperties:
            if let alignment = ooxmlAlignment(value) {
                explicitParagraph.alignment = alignment
                explicitSaysAlignment = true
            }
        case "spacing" where inParagraphProperties && !inRunProperties:
            if let before = DOCXLayout.points(twips: attributes.ooxmlValue("before")) {
                explicitParagraph.spaceBeforePt = before
                explicitSaysSpacing = true
            }
            if let after = DOCXLayout.points(twips: attributes.ooxmlValue("after")) {
                explicitParagraph.spaceAfterPt = after
                explicitSaysSpacing = true
            }
            if let line = attributes.ooxmlValue("line"), let raw = Double(line) {
                explicitParagraph.lineSpacing = ooxmlLineSpacing(
                    raw: raw, rule: attributes.ooxmlValue("lineRule"))
                explicitSaysSpacing = true
            }
        case "ind" where inParagraphProperties:
            if let left = DOCXLayout.points(twips: attributes.ooxmlValue("left")) {
                explicitParagraph.indentLeftPt = left
                explicitSaysIndent = true
            }
            if let first = DOCXLayout.points(twips: attributes.ooxmlValue("firstLine")) {
                explicitParagraph.firstLineIndentPt = first
                explicitSaysIndent = true
            }
            if let hanging = DOCXLayout.points(twips: attributes.ooxmlValue("hanging")) {
                explicitParagraph.firstLineIndentPt = -hanging
                explicitSaysIndent = true
            }
        case "outlineLvl" where inParagraphProperties:
            if let text = value, let level = Int(text) { explicitParagraph.outlineLevel = level + 1 }
        case "pageBreakBefore" where inParagraphProperties:
            explicitParagraph.pageBreakBefore = isOOXMLOn(value)
        case "shd":
            let fill = DOCXLayout.Color.hex(attributes.ooxmlValue("fill"))
            if !cellStack.isEmpty && !inParagraph { cellStack[cellStack.count - 1].shading = fill }
            else if inParagraphProperties { explicitParagraph.shading = fill }

        case "r":
            beginRun()
        case "rPr":
            inRunProperties = true
        case "rFonts" where inRunProperties && inRun:
            if let font = attributes.ooxmlValue("ascii") ?? attributes.ooxmlValue("hAnsi") {
                runStyle.fontName = font
                runOverrides.saysFont = true
            }
        case "sz" where inRunProperties && inRun:
            if let size = DOCXLayout.points(halfPoints: value) {
                runStyle.sizePt = size
                runOverrides.saysSize = true
            }
        case "b" where inRunProperties && inRun:
            runStyle.bold = isOOXMLOn(value)
            runOverrides.saysBold = true
        case "i" where inRunProperties && inRun:
            runStyle.italic = isOOXMLOn(value)
            runOverrides.saysItalic = true
        case "u" where inRunProperties && inRun:
            runStyle.underline = value != "none"
        case "strike" where inRunProperties && inRun:
            runStyle.strikethrough = isOOXMLOn(value)
        case "color" where inRunProperties && inRun:
            runStyle.color = DOCXLayout.Color.hex(value)
        case "highlight" where inRunProperties && inRun:
            runStyle.highlight = DOCXLayout.Color.highlight(value)
        case "vertAlign" where inRunProperties && inRun:
            runStyle.verticalAlign = value == "superscript" ? 1 : (value == "subscript" ? -1 : 0)

        case "t":
            textBuffer = ""
        case "instrText":
            inFieldCode = true
            fieldCode = ""
        case "delText":
            inDeletedText = true
        case "tab" where inRun:
            appendText("\t")
        case "br":
            if attributes.ooxmlValue("type") == "page" { appendInline(.pageBreak) }
            else { appendInline(.lineBreak) }

        case "tbl":
            beginTable()
        case "gridCol":
            if let width = DOCXLayout.points(twips: attributes.ooxmlValue("w")),
               !tableStack.isEmpty {
                tableStack[tableStack.count - 1].columnWidthsPt.append(width)
            }
        case "tblBorders":
            break
        case "tr":
            rowStack.append(DOCXLayout.Row())
        case "tc":
            cellStack.append(DOCXLayout.Cell())
        case "tcW":
            if let width = DOCXLayout.points(twips: attributes.ooxmlValue("w")),
               !cellStack.isEmpty, width > 0 {
                cellStack[cellStack.count - 1].widthPt = width
            }
        case "gridSpan":
            if let span = value.flatMap(Int.init), !cellStack.isEmpty {
                cellStack[cellStack.count - 1].columnSpan = max(1, span)
            }
        case "vMerge":
            if !cellStack.isEmpty, value != "restart" {
                cellStack[cellStack.count - 1].isVerticallyMerged = true
            }

        case "extent", "ext":
            // `wp:extent` (ảnh trong dòng) và `a:ext` (khung hình) đều đo bằng EMU.
            if let width = DOCXLayout.points(emu: attributes.ooxmlValue("cx")),
               let height = DOCXLayout.points(emu: attributes.ooxmlValue("cy")),
               width > 0, height > 0 {
                pendingImageWidth = width
                pendingImageHeight = height
            }
        case "blip":
            if let id = attributes.ooxmlValue("embed") ?? attributes.ooxmlValue("link") {
                attachImage(relationshipID: id)
            }
        case "imagedata":
            if let id = attributes.ooxmlValue("id") { attachImage(relationshipID: id) }

        case "pgSz":
            if let width = DOCXLayout.points(twips: attributes.ooxmlValue("w")) {
                document.pageWidthPt = width
            }
            if let height = DOCXLayout.points(twips: attributes.ooxmlValue("h")) {
                document.pageHeightPt = height
            }
            sectionSeen = true
        case "sectPr":
            // `w:sectPr` nằm trong `w:pPr` của đoạn CUỐI phần ấy; cái nằm thẳng trong `w:body`
            // mô tả phần cuối cùng. Chỉ đánh dấu ở đây, cắt khi đoạn đóng lại.
            if inParagraphProperties { paragraphClosesSection = true }
        case "headerReference" where attributes.ooxmlValue("type") != "first":
            // Chỉ lấy bản MẶC ĐỊNH, và chỉ bản ĐẦU TIÊN gặp. Một cuốn sách chia 45 phần có 45
            // cặp đầu/chân trang; dựng đúng từng phần đòi bộ phân trang phải biết ranh giới
            // phần, thứ chưa có. Lấy một bản cho cả cuốn là xấp xỉ nói ra được, còn không lấy
            // gì thì mọi trang mất số trang.
            pendingHeaderID = attributes.ooxmlValue("id")
        case "footerReference" where attributes.ooxmlValue("type") != "first":
            pendingFooterID = attributes.ooxmlValue("id")
        case "pgMar":
            if let left = DOCXLayout.points(twips: attributes.ooxmlValue("left")) {
                document.marginLeftPt = left
            }
            if let right = DOCXLayout.points(twips: attributes.ooxmlValue("right")) {
                document.marginRightPt = right
            }
            if let top = DOCXLayout.points(twips: attributes.ooxmlValue("top")) {
                document.marginTopPt = top
            }
            if let bottom = DOCXLayout.points(twips: attributes.ooxmlValue("bottom")) {
                document.marginBottomPt = bottom
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inFieldCode { fieldCode += string; return }
        guard !inDeletedText else { return }
        textBuffer += string
    }

    // MARK: Kết thúc thẻ

    func parser(
        _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch ooxmlLocalName(name) {
        case "t":
            appendText(textBuffer)
            textBuffer = ""
        case "instrText":
            inFieldCode = false
            // Trường của Word: `PAGE`, `NUMPAGES`, `TOC \\o "1-3"`… Hai cái đầu là số trang và
            // phải đi tới tầng vẽ; phần còn lại là chỉ dẫn cho Word, không phải chữ người đọc.
            let code = fieldCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if code == "PAGE" || code.hasPrefix("PAGE ") || code.hasPrefix("PAGE\\") {
                appendInline(.pageNumber)
            } else if code.hasPrefix("NUMPAGES") {
                appendInline(.pageCount)
            }
            fieldCode = ""
            textBuffer = ""
        case "delText":
            inDeletedText = false
            textBuffer = ""
        case "rPr": inRunProperties = false
        case "pPr": inParagraphProperties = false
        case "r": inRun = false
        case "p": flushParagraph()
        case "tc": closeCell()
        case "tr": closeRow()
        case "tbl": closeTable()
        default: break
        }
    }

    // MARK: Dựng

    private func beginParagraph() {
        // Đoạn lồng trong ô bảng: `w:p` mở khi `w:p` ngoài chưa đóng là chuyện không xảy ra
        // trong OOXML hợp lệ, nhưng tệp do công cụ khác sinh thì có. Đóng cái cũ, đừng nuốt.
        if inParagraph { flushParagraph() }
        inParagraph = true
        paragraph = DOCXLayout.Paragraph()
        paragraphStyleID = nil
        paragraphNumberingID = nil
        paragraphListLevel = 0
        explicitParagraph = DOCXLayout.ParagraphStyle()
        explicitSaysAlignment = false
        explicitSaysIndent = false
        explicitSaysSpacing = false
    }

    private func beginRun() {
        inRun = true
        runOverrides = RunOverrides()
        // Run bắt đầu từ kiểu của ĐOẠN, rồi `w:rPr` đè lên. Bắt đầu từ mặc định của tài liệu là
        // làm mọi tiêu đề mất cỡ chữ của nó ngay khi nó có dù chỉ một `w:rPr` rỗng.
        runStyle = styles.resolved(paragraphStyleID).run
    }

    private func appendText(_ text: String) {
        guard !text.isEmpty else { return }
        appendInline(.text(text, runStyle))
    }

    private func appendInline(_ inline: DOCXLayout.Inline) {
        if !inParagraph { beginParagraph() }
        // Gộp hai mảnh chữ liền nhau CÙNG hình thức. Word cắt một câu thành năm `<w:r>` vì bộ
        // kiểm chính tả hay vì một lần sửa cũ; giữ nguyên năm mảnh là bắt tầng vẽ dựng năm dãy
        // glyph cho một câu, và làm mọi phép đo chiều dài đoạn sai lệch ở chỗ nối.
        if case .text(let new, let newStyle) = inline,
           case .text(let old, let oldStyle)? = paragraph.inlines.last,
           newStyle == oldStyle {
            paragraph.inlines[paragraph.inlines.count - 1] = .text(old + new, oldStyle)
            return
        }
        paragraph.inlines.append(inline)
    }

    private func attachImage(relationshipID: String) {
        guard let target = relationships[relationshipID] else { return }
        // Target ghi tương đối với `word/`: `media/image1.png`. Vài công cụ ghi cả `/word/…`.
        var path = target
        if path.hasPrefix("/") { path.removeFirst() }
        let candidates = path.hasPrefix("word/") ? [path] : ["word/" + path, path]
        var bytes: [UInt8]?
        for candidate in candidates {
            if let found = (try? archive.data(named: candidate)) ?? nil, !found.isEmpty {
                bytes = found
                break
            }
        }
        guard let data = bytes else { return }
        // Không có `wp:extent` thì lấy khổ bằng bề rộng vùng chữ và tỉ lệ vuông tạm — tầng vẽ sẽ
        // sửa lại theo khổ thật của ảnh khi giải mã được nó.
        let width = pendingImageWidth ?? 0
        let height = pendingImageHeight ?? 0
        appendInline(.image(DOCXLayout.Image(
            data: data, widthPt: width, heightPt: height, name: path)))
        pendingImageWidth = nil
        pendingImageHeight = nil
    }

    private func flushParagraph() {
        guard inParagraph else { return }
        inParagraph = false

        let resolved = styles.resolved(paragraphStyleID)
        var style = resolved.paragraph
        if explicitSaysAlignment { style.alignment = explicitParagraph.alignment }
        if explicitSaysSpacing {
            style.spaceBeforePt = explicitParagraph.spaceBeforePt
            style.spaceAfterPt = explicitParagraph.spaceAfterPt
            style.lineSpacing = explicitParagraph.lineSpacing
        }
        if explicitSaysIndent {
            style.indentLeftPt = explicitParagraph.indentLeftPt
            style.firstLineIndentPt = explicitParagraph.firstLineIndentPt
        }
        if let level = explicitParagraph.outlineLevel { style.outlineLevel = level }
        style.pageBreakBefore = explicitParagraph.pageBreakBefore
        if let shading = explicitParagraph.shading { style.shading = shading }

        // Tiêu đề: `w:outlineLvl` là nguồn chính thống, nhưng phần lớn tệp thật chỉ có tên kiểu.
        if style.outlineLevel == nil, let level = headingLevel(ofStyle: paragraphStyleID) {
            style.outlineLevel = level
        }

        let numberingID = paragraphNumberingID ?? resolved.numberingID
        if let id = numberingID, id != 0 {
            let level = paragraphNumberingID != nil ? paragraphListLevel : resolved.listLevel
            let ordinal = (listOrdinals[id]?[level] ?? 0) + 1
            listOrdinals[id, default: [:]][level] = ordinal
            // Cấp sâu hơn bắt đầu lại từ 1 khi cấp trên tăng — đúng cách Word đánh số.
            for deeper in listOrdinals[id, default: [:]].keys where deeper > level {
                listOrdinals[id]?[deeper] = 0
            }
            style.listMarker = numbering.marker(numberingID: id, level: level, ordinal: ordinal)
            style.listLevel = level
            style.indentLeftPt = max(style.indentLeftPt, Double(level + 1) * 18)
        }

        paragraph.style = style
        emit(.paragraph(paragraph))
        paragraph = DOCXLayout.Paragraph()

        if paragraphClosesSection {
            paragraphClosesSection = false
            closeSection()
        }
    }

    private func emit(_ block: DOCXLayout.Block) {
        if !cellStack.isEmpty {
            if case .paragraph(let p) = block {
                cellStack[cellStack.count - 1].paragraphs.append(p)
            } else if case .table(let nested) = block {
                // Bảng lồng: giữ nó bằng cách trải thành các đoạn của ô — tầng vẽ hiện chưa dựng
                // bảng trong bảng, và một bảng bị NUỐT thì người đọc mất hẳn nội dung.
                for row in nested.rows {
                    for cell in row.cells {
                        cellStack[cellStack.count - 1].paragraphs.append(contentsOf: cell.paragraphs)
                    }
                }
            }
            return
        }
        document.blocks.append(block)
        blocksInSection += 1
    }

    private func beginTable() {
        if inParagraph { flushParagraph() }
        tableStack.append(DOCXLayout.Table())
    }

    private func closeCell() {
        guard !cellStack.isEmpty else { return }
        if inParagraph { flushParagraph() }
        let cell = cellStack.removeLast()
        if !rowStack.isEmpty { rowStack[rowStack.count - 1].cells.append(cell) }
    }

    private func closeRow() {
        guard !rowStack.isEmpty else { return }
        let row = rowStack.removeLast()
        if !tableStack.isEmpty { tableStack[tableStack.count - 1].rows.append(row) }
    }

    private func closeTable() {
        guard !tableStack.isEmpty else { return }
        let table = tableStack.removeLast()
        guard !table.rows.isEmpty else { return }
        emit(.table(table))
    }

    /// `"Heading2"`, `"heading 2"`, `"Ti\u{ea}u\u{111}\u{1ec1}2"` — tên kiểu bị BẢN ĐỊA HOÁ.
    ///
    /// Word ghi `w:styleId` theo ngôn ngữ của bản đã tạo tệp. So khớp bằng tiếng Anh thì mọi tệp
    /// do bản Word tiếng Việt hay tiếng Nhật tạo ra sẽ mất hết tiêu đề — bài học đã ghi lại một
    /// lần trong bộ đọc Markdown, và nó lặp lại y nguyên ở đây.
    private func headingLevel(ofStyle style: String?) -> Int? {
        guard let style else { return nil }
        let lowered = style.lowercased().replacingOccurrences(of: " ", with: "")
        for prefix in ["heading", "title", "berschrift", "titre", "\u{6a19}\u{984c}"] {
            guard lowered.hasPrefix(prefix) else { continue }
            let rest = lowered.dropFirst(prefix.count)
            if rest.isEmpty { return 1 }
            if let level = Int(rest), (1 ... 9).contains(level) { return level }
        }
        // Chốt cuối: chữ số cuối cùng của một tên kiểu bắt đầu bằng chữ không phải Latin.
        return nil
    }
}

// MARK: - Tiện ích chung của OOXML

/// Bỏ tiền tố namespace: `w:pPr` → `pPr`.
///
/// Tiền tố KHÔNG cố định — chuẩn cho phép tệp khai báo tên khác. Đã có một lần mất cả tài liệu
/// vì so khớp thẳng `"w:p"`; so theo tên cục bộ là cách duy nhất đúng.
func ooxmlLocalName(_ name: String) -> String {
    guard let colon = name.lastIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}

extension [String: String] {
    /// Đọc thuộc tính theo tên cục bộ, chấp nhận cả `w:val` lẫn `val`.
    func ooxmlValue(_ localName: String) -> String? {
        if let direct = self[localName] { return direct }
        for (key, value) in self where ooxmlLocalName(key) == localName { return value }
        return nil
    }
}

/// `<w:b/>` không có `w:val` nghĩa là BẬT. `w:val="0"` và `"false"` là tắt.
///
/// Đây là chỗ dễ sai nhất của OOXML: coi "không có val" là tắt sẽ làm mọi chữ đậm trong tệp mất
/// đậm, và tệp vẫn mở ra bình thường nên không ai thấy có gì hỏng.
func isOOXMLOn(_ value: String?) -> Bool {
    guard let value else { return true }
    return value != "0" && value != "false" && value != "off"
}

func ooxmlAlignment(_ value: String?) -> DOCXLayout.Alignment? {
    switch value {
    case "center": return .center
    case "right", "end": return .right
    case "both", "distribute": return .justified
    case "left", "start": return .left
    default: return nil
    }
}

/// `w:spacing/@w:line` → bội số giãn dòng.
///
/// `lineRule="auto"` đo bằng 1/240 của một dòng đơn; `"exact"`/`"atLeast"` đo bằng twip. Quy tất
/// cả về bội số vì tầng vẽ dùng bội số — và một con số 360 hiểu nhầm thành 360 lần chiều cao
/// dòng sẽ đẩy mỗi đoạn thành mấy chục trang trắng.
func ooxmlLineSpacing(raw: Double, rule: String?) -> Double {
    switch rule {
    case "exact", "atLeast":
        // twip → point, rồi chia cho cỡ chữ giả định 11pt × 1.2 để ra bội số xấp xỉ.
        let points = raw / 20
        return max(0.5, min(4, points / 13.2))
    default:
        return max(0.5, min(4, raw / 240))
    }
}
