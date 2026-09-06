import Foundation

/// Đọc `.pptx` thành **mô hình slide** — hình khối có toạ độ, không phải một danh sách chữ.
///
/// ## Vì sao phải có, khi đã có `PPTXReader`
///
/// `PPTXReader` rút slide thành dàn ý Markdown: đúng nội dung, sửa được, ghi ngược được. Đó là
/// chế độ **Code**. Chế độ **View** hỏi câu khác: *slide này TRÔNG như thế nào* — hộp chữ nằm ở
/// đâu trên khổ 16:9, nền màu gì, ảnh to bằng nào, tiêu đề cỡ mấy.
///
/// Bản đầu của chế độ View dựng slide bằng cách đổ dàn ý lên một tờ trắng. Nó đọc được, và nó
/// nói thật về giới hạn của mình bằng một dòng chữ trên khung — nhưng "đọc được" không phải thứ
/// người ta mở một bộ slide để tìm. Tệp này là phần trả nợ ấy.
///
/// ## Ba thứ khó của PowerPoint, và cách xử ở đây
///
/// **1. Phần lớn hình khối KHÔNG có toạ độ.** Một `<p:sp>` mang `<p:ph type="title"/>` thừa
/// hưởng cả vị trí lẫn cỡ chữ từ **layout**, layout lại thừa hưởng từ **master**. Bỏ qua chuỗi
/// ấy thì mọi tiêu đề mất chỗ đứng — nên ở đây đi đủ ba tầng: slide → layout → master.
///
/// **2. Màu thường là TÊN, không phải số.** `<a:schemeClr val="accent1"/>` chỉ có nghĩa khi tra
/// bảng màu trong `ppt/theme/theme1.xml`. Không tra thì một bộ slide xanh–cam hiện ra đen trắng.
///
/// **3. Đơn vị đổi ba lần.** Toạ độ đo bằng EMU (914400 = 1 inch), cỡ chữ đo bằng **phần trăm
/// point** (`sz="1800"` là 18 pt), còn góc xoay đo bằng 1/60000 độ.
public enum PPTXLayout {

    // MARK: - Mô hình

    /// Một hình khối trên slide: một hộp có toạ độ, có thể mang chữ, ảnh, hoặc cả hai.
    public struct Shape: Equatable, Sendable {
        /// Toạ độ trên slide, đơn vị point, gốc ở góc TRÊN-TRÁI.
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public var fill: DOCXLayout.Color?
        public var stroke: DOCXLayout.Color?
        public var strokeWidthPt: Double = 0
        public var paragraphs: [DOCXLayout.Paragraph] = []
        public var image: DOCXLayout.Image?
        /// Góc xoay theo độ, thuận chiều kim đồng hồ.
        public var rotation: Double = 0
        /// Hình bầu dục thay vì chữ nhật. Đủ để không vẽ một cái nút tròn thành hộp vuông.
        public var isEllipse = false
        /// Khoá placeholder `"title:"`, `"body:1"` — chỗ để tra khung thừa kế từ layout/master.
        /// `nil` = hình khối tự do, không mượn khung của ai.
        public var placeholderKey: String?

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public var plainText: String {
            paragraphs.map(\.plainText).joined(separator: "\n")
        }
    }

    public struct Slide: Equatable, Sendable {
        public var shapes: [Shape] = []
        public var background: DOCXLayout.Color?
        public init() {}
    }

    public struct Deck: Equatable, Sendable {
        public var slides: [Slide] = []
        /// Khổ slide, point. Mặc định 16:9 của PowerPoint.
        public var widthPt: Double = 960
        public var heightPt: Double = 540
        public init() {}

        public var imageCount: Int {
            slides.reduce(0) { $0 + $1.shapes.filter { $0.image != nil }.count }
        }
    }

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notAPresentation

        public var description: String { "Tệp này không phải bộ slide PowerPoint" }
    }

    // MARK: - Đọc

    public static func read(path: String) throws -> Deck {
        let archive = try ZipArchive(path: path)
        guard let presentation = (try? archive.data(named: "ppt/presentation.xml")) ?? nil else {
            throw Failure.notAPresentation
        }

        var deck = Deck()
        let size = SlideSize.parse(presentation)
        if size.width > 0, size.height > 0 {
            deck.widthPt = size.width
            deck.heightPt = size.height
        }

        // Bảng màu của chủ đề. Thiếu nó thì mọi `schemeClr` rơi về nil và bộ slide mất màu.
        let theme = (try? archive.data(named: "ppt/theme/theme1.xml")).flatMap { $0 }
            .map { ThemeColors.parse($0) } ?? [:]

        for slidePath in slidePaths(archive: archive, presentation: presentation) {
            guard let data = (try? archive.data(named: slidePath)) ?? nil else { continue }
            let slideRels = relationships(archive: archive, for: slidePath)

            // Chuỗi thừa kế: slide → layout → master. Đọc từ XA về GẦN rồi để gần đè lên xa.
            var inherited: [String: Shape] = [:]
            var background: DOCXLayout.Color?
            var titleStyle: [Int: DOCXLayout.RunStyle] = [:]
            var bodyStyle: [Int: DOCXLayout.RunStyle] = [:]
            var otherStyle: [Int: DOCXLayout.RunStyle] = [:]
            if let layoutPath = slideRels.values.first(where: {
                $0.contains("slideLayouts/slideLayout")
            }).map({ normalise($0, relativeTo: slidePath) }) {
                let layoutRels = relationships(archive: archive, for: layoutPath)
                if let masterPath = layoutRels.values.first(where: {
                    $0.contains("slideMasters/slideMaster")
                }).map({ normalise($0, relativeTo: layoutPath) }),
                   let masterData = (try? archive.data(named: masterPath)) ?? nil {
                    let master = ShapeParser.parse(
                        masterData, theme: theme,
                        relationships: relationships(archive: archive, for: masterPath),
                        archive: archive, basePath: masterPath)
                    inherited.merge(master.placeholders) { _, new in new }
                    background = master.background
                    titleStyle = master.titleStyle
                    bodyStyle = master.bodyStyle
                    otherStyle = master.otherStyle
                }
                if let layoutData = (try? archive.data(named: layoutPath)) ?? nil {
                    let layout = ShapeParser.parse(
                        layoutData, theme: theme, relationships: layoutRels,
                        archive: archive, basePath: layoutPath)
                    inherited.merge(layout.placeholders) { _, new in new }
                    background = layout.background ?? background
                }
            }

            let parsed = ShapeParser.parse(
                data, theme: theme, relationships: slideRels,
                archive: archive, basePath: slidePath)

            var slide = Slide()
            slide.background = parsed.background ?? background
            slide.shapes = parsed.shapes.map { shape in
                // Hình khối không có `a:xfrm` mượn khung của placeholder cùng tên ở layout/master.
                guard shape.width <= 0 || shape.height <= 0 else { return shape }
                var filled = shape
                if let key = shape.placeholderKey, let source = inherited[key] {
                    filled.x = source.x
                    filled.y = source.y
                    filled.width = source.width
                    filled.height = source.height
                } else {
                    // Không tra được thì đặt vào giữa slide, chừa lề — thà lệch chỗ còn hơn biến
                    // mất, và một hộp chữ rộng 0 pt thì đúng là biến mất.
                    filled.x = deck.widthPt * 0.08
                    filled.y = deck.heightPt * 0.12
                    filled.width = deck.widthPt * 0.84
                    filled.height = deck.heightPt * 0.76
                }
                return filled
            }
            // Điền cỡ chữ cho những run KHÔNG tự nói cỡ.
            //
            // Đây là bước không được bỏ: phần lớn run trong tệp thật chỉ ghi nội dung, còn con
            // số 44 pt của tiêu đề nằm ở `p:txStyles` của master. Không điền thì mọi slide hiện
            // ra cùng một cỡ chữ — đúng nội dung, sai hẳn hình dạng.
            slide.shapes = slide.shapes.map { shape in
                var filled = shape
                let table = Self.styleTable(
                    for: shape.placeholderKey,
                    title: titleStyle, body: bodyStyle, other: otherStyle)
                filled.paragraphs = shape.paragraphs.map { paragraph in
                    var next = paragraph
                    let fallback = table[paragraph.style.listLevel]
                        ?? table[0]
                        ?? Self.builtInDefault(for: shape.placeholderKey)
                    next.inlines = paragraph.inlines.map { inline in
                        guard case .text(let value, var style) = inline else { return inline }
                        if style.sizePt <= 0 {
                            style.sizePt = fallback.sizePt > 0
                                ? fallback.sizePt
                                : Self.builtInDefault(for: shape.placeholderKey).sizePt
                            // Cỡ chữ của cấp sâu nhỏ dần — PowerPoint làm vậy ngay cả khi master
                            // chỉ khai cấp 1.
                            if table[paragraph.style.listLevel] == nil,
                               paragraph.style.listLevel > 0 {
                                style.sizePt *= pow(0.85, Double(paragraph.style.listLevel))
                            }
                        }
                        if style.color == nil { style.color = fallback.color }
                        if !style.bold { style.bold = fallback.bold }
                        if style.fontName == nil { style.fontName = fallback.fontName }
                        return .text(value, style)
                    }
                    return next
                }
                return filled
            }
            deck.slides.append(slide)
        }
        return deck
    }

    /// Bảng kiểu chữ đúng với loại placeholder của hình khối.
    private static func styleTable(
        for key: String?, title: [Int: DOCXLayout.RunStyle],
        body: [Int: DOCXLayout.RunStyle], other: [Int: DOCXLayout.RunStyle]
    ) -> [Int: DOCXLayout.RunStyle] {
        guard let type = key?.components(separatedBy: ":").first else { return other }
        switch type {
        case "title", "ctrTitle": return title
        case "body", "subTitle", "obj", "": return body
        default: return other
        }
    }

    /// Con số của PowerPoint khi tệp không nói gì cả — 44 pt tiêu đề, 32 pt thân, 18 pt còn lại.
    private static func builtInDefault(for key: String?) -> DOCXLayout.RunStyle {
        let type = key?.components(separatedBy: ":").first
        switch type {
        case "title", "ctrTitle": return DOCXLayout.RunStyle(sizePt: 44)
        case "body", "subTitle", "obj": return DOCXLayout.RunStyle(sizePt: 32)
        default: return DOCXLayout.RunStyle(sizePt: 18)
        }
    }

    // MARK: - Đường dẫn

    private static func slidePaths(archive: ZipArchive, presentation: [UInt8]) -> [String] {
        let order = (try? archive.data(named: "ppt/_rels/presentation.xml.rels")).flatMap { $0 }
            .map { Relationships.parse($0) } ?? [:]
        let ids = SlideSize.slideIDs(presentation)
        var paths = ids.compactMap { order[$0] }
            .filter { $0.contains("slides/slide") }
            .map { normalise($0, relativeTo: "ppt/presentation.xml") }
        if paths.isEmpty {
            // Lùi về sắp theo SỐ, không theo chuỗi: `slide10.xml` phải đứng sau `slide9.xml`.
            paths = archive.entries.map(\.path)
                .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
                .sorted { number(in: $0) < number(in: $1) }
        }
        return paths
    }

    private static func relationships(archive: ZipArchive, for path: String) -> [String: String] {
        let folder = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        let relsPath = folder + "/_rels/" + name + ".rels"
        return (try? archive.data(named: relsPath)).flatMap { $0 }
            .map { Relationships.parse($0) } ?? [:]
    }

    /// `../slideLayouts/slideLayout2.xml` tính từ `ppt/slides/slide1.xml` → `ppt/slideLayouts/…`.
    static func normalise(_ target: String, relativeTo source: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        var parts = ((source as NSString).deletingLastPathComponent as NSString)
            .pathComponents
        for piece in target.components(separatedBy: "/") {
            switch piece {
            case "..": if !parts.isEmpty { parts.removeLast() }
            case ".", "": break
            default: parts.append(piece)
            }
        }
        return parts.joined(separator: "/")
    }

    private static func number(in path: String) -> Int {
        Int(path.filter(\.isNumber)) ?? 0
    }
}

// MARK: - Khổ slide

private enum SlideSize {
    static func parse(_ data: [UInt8]) -> (width: Double, height: Double) {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        return (delegate.width, delegate.height)
    }

    static func slideIDs(_ data: [UInt8]) -> [String] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        return delegate.ids
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var width: Double = 0
        var height: Double = 0
        var ids: [String] = []

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            switch ooxmlLocalName(name) {
            case "sldSz":
                width = DOCXLayout.points(emu: attributes.ooxmlValue("cx")) ?? 0
                height = DOCXLayout.points(emu: attributes.ooxmlValue("cy")) ?? 0
            case "sldId":
                if let id = attributes.ooxmlValue("id"), id.hasPrefix("rId") { ids.append(id) }
            default: break
            }
        }
    }
}

// MARK: - Bảng màu chủ đề

/// `accent1` → màu. Cả `dk1`/`lt1` lẫn bí danh `tx1`/`bg1` mà slide hay dùng.
enum ThemeColors {
    static func parse(_ data: [UInt8]) -> [String: DOCXLayout.Color] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        var map = delegate.map
        // PowerPoint gọi cùng một màu bằng hai tên tuỳ chỗ: `tx1` trong slide chính là `dk1`
        // trong chủ đề. Không nối hai tên ấy thì màu chữ mặc định rơi về nil ở gần như mọi slide.
        for (alias, real) in [("tx1", "dk1"), ("tx2", "dk2"), ("bg1", "lt1"), ("bg2", "lt2")] {
            if map[alias] == nil, let color = map[real] { map[alias] = color }
        }
        return map
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var map: [String: DOCXLayout.Color] = [:]
        private var inScheme = false
        private var slot: String?

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            let tag = ooxmlLocalName(name)
            if tag == "clrScheme" { inScheme = true; return }
            guard inScheme else { return }
            if tag == "srgbClr", let slot, let color = DOCXLayout.Color.hex(
                attributes.ooxmlValue("val")) {
                map[slot] = color
            } else if tag == "sysClr", let slot,
                      let color = DOCXLayout.Color.hex(attributes.ooxmlValue("lastClr")) {
                map[slot] = color
            } else if tag != "srgbClr", tag != "sysClr" {
                slot = tag
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            if ooxmlLocalName(name) == "clrScheme" { inScheme = false }
        }
    }
}

// MARK: - Cây hình khối

/// Đọc `p:spTree` của một slide, layout, hay master — cùng một bộ máy cho cả ba.
private enum ShapeParser {

    struct Result {
        var shapes: [PPTXLayout.Shape] = []
        /// `p:txStyles` của master: kiểu chữ mặc định theo CẤP cho tiêu đề, thân, và phần còn
        /// lại. Đây là chỗ PowerPoint giấu con số 44 pt của mọi tiêu đề.
        var titleStyle: [Int: DOCXLayout.RunStyle] = [:]
        var bodyStyle: [Int: DOCXLayout.RunStyle] = [:]
        var otherStyle: [Int: DOCXLayout.RunStyle] = [:]
        /// Hình khối placeholder theo khoá `"type:idx"` — dùng cho tầng dưới thừa kế.
        var placeholders: [String: PPTXLayout.Shape] = [:]
        var background: DOCXLayout.Color?
    }

    static func parse(
        _ data: [UInt8], theme: [String: DOCXLayout.Color], relationships: [String: String],
        archive: ZipArchive, basePath: String
    ) -> Result {
        let delegate = Delegate(
            theme: theme, relationships: relationships, archive: archive, basePath: basePath)
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        parser.parse()
        delegate.closeShape()
        return delegate.result
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var result = Result()

        private let theme: [String: DOCXLayout.Color]
        private let relationships: [String: String]
        private let archive: ZipArchive
        private let basePath: String

        init(
            theme: [String: DOCXLayout.Color], relationships: [String: String],
            archive: ZipArchive, basePath: String
        ) {
            self.theme = theme
            self.relationships = relationships
            self.archive = archive
            self.basePath = basePath
        }

        // Hình khối đang dựng
        private var shape: PPTXLayout.Shape?
        private var placeholderType: String?
        private var placeholderIndex: String?
        private var inShapeProperties = false
        private var inBackground = false
        private var inTextBody = false
        /// `a:lstStyle` trong `p:txBody` mô tả KIỂU MẶC ĐỊNH, không mô tả chữ có thật. Đọc chữ
        /// trong đó là dựng ra những đoạn rỗng nằm chồng lên chữ thật.
        private var inListStyle = false

        // Đoạn và run đang dựng
        private var paragraph = DOCXLayout.Paragraph()
        /// `sizePt == 0` nghĩa là RUN KHÔNG NÓI CỠ — để `p:txStyles` của master điền sau. Đặt
        /// sẵn 18 ở đây thì mọi tiêu đề 44 pt hiện ra 18 pt và không có cách nào biết vì sao.
        private var run = DOCXLayout.RunStyle(sizePt: 0)
        private var inRunProperties = false
        private var text = ""
        private var bulletSuppressed = false
        private var indentLevel = 0

        // Nhóm: `a:chOff`/`a:chExt` cho biết hệ toạ độ CON, phải quy về hệ của slide.
        private struct GroupTransform {
            var offsetX = 0.0, offsetY = 0.0
            var childX = 0.0, childY = 0.0
            var scaleX = 1.0, scaleY = 1.0
        }
        private var groups: [GroupTransform] = []
        private var pendingGroup: GroupTransform?
        private var inGroupProperties = false

        // Kiểu chữ mặc định đang đọc trong `p:txStyles`
        private enum StyleSlot { case title, body, other }
        private var styleSlot: StyleSlot?
        private var styleLevel: Int?
        private var styleRun = DOCXLayout.RunStyle(sizePt: 0)

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            let tag = ooxmlLocalName(name)
            switch tag {
            case "titleStyle": styleSlot = .title
            case "bodyStyle": styleSlot = .body
            case "otherStyle": styleSlot = .other
            case "lvl1pPr", "lvl2pPr", "lvl3pPr", "lvl4pPr", "lvl5pPr",
                 "lvl6pPr", "lvl7pPr", "lvl8pPr", "lvl9pPr":
                if styleSlot != nil {
                    styleLevel = Int(String(tag.dropFirst(3).prefix(1))).map { $0 - 1 } ?? 0
                    styleRun = DOCXLayout.RunStyle(sizePt: 0)
                }
            case "bg":
                inBackground = true
            case "grpSp":
                pendingGroup = GroupTransform()
            case "grpSpPr":
                inGroupProperties = true
            case "sp", "pic", "graphicFrame", "cxnSp":
                closeShape()
                shape = PPTXLayout.Shape(x: 0, y: 0, width: 0, height: 0)
                placeholderType = nil
                placeholderIndex = nil
            case "ph":
                placeholderType = attributes.ooxmlValue("type") ?? "body"
                placeholderIndex = attributes.ooxmlValue("idx")
            case "spPr":
                inShapeProperties = true
            case "xfrm":
                if let rotation = attributes.ooxmlValue("rot").flatMap(Double.init) {
                    shape?.rotation = rotation / 60000
                }
            case "off":
                let x = DOCXLayout.points(emu: attributes.ooxmlValue("x")) ?? 0
                let y = DOCXLayout.points(emu: attributes.ooxmlValue("y")) ?? 0
                if inGroupProperties { pendingGroup?.offsetX = x; pendingGroup?.offsetY = y }
                else if shape != nil { shape?.x = x; shape?.y = y }
            case "ext":
                let width = DOCXLayout.points(emu: attributes.ooxmlValue("cx")) ?? 0
                let height = DOCXLayout.points(emu: attributes.ooxmlValue("cy")) ?? 0
                if inGroupProperties, pendingGroup != nil {
                    pendingGroup?.scaleX = width
                    pendingGroup?.scaleY = height
                } else if shape != nil {
                    shape?.width = width
                    shape?.height = height
                }
            case "chOff":
                pendingGroup?.childX = DOCXLayout.points(emu: attributes.ooxmlValue("x")) ?? 0
                pendingGroup?.childY = DOCXLayout.points(emu: attributes.ooxmlValue("y")) ?? 0
            case "chExt":
                let width = DOCXLayout.points(emu: attributes.ooxmlValue("cx")) ?? 0
                let height = DOCXLayout.points(emu: attributes.ooxmlValue("cy")) ?? 0
                if var group = pendingGroup {
                    group.scaleX = width > 0 ? group.scaleX / width : 1
                    group.scaleY = height > 0 ? group.scaleY / height : 1
                    pendingGroup = group
                }
            case "prstGeom":
                let preset = attributes.ooxmlValue("prst") ?? ""
                if preset == "ellipse" || preset == "circle" { shape?.isEllipse = true }

            case "srgbClr", "sysClr", "schemeClr":
                let color = resolve(tag: tag, attributes: attributes)
                apply(color: color)
            case "noFill":
                if inRunProperties { break }
                if inShapeProperties { shape?.fill = nil }
            case "ln":
                inLine = true
                if let width = DOCXLayout.points(emu: attributes.ooxmlValue("w")) {
                    shape?.strokeWidthPt = width
                }

            case "blip":
                if let id = attributes.ooxmlValue("embed") { attachImage(relationshipID: id) }

            case "txBody", "txbxContent":
                inTextBody = true
            case "lstStyle":
                inListStyle = true
            case "p" where inTextBody && !inListStyle:
                paragraph = DOCXLayout.Paragraph()
                bulletSuppressed = false
                indentLevel = 0
            case "pPr" where inTextBody:
                if let level = attributes.ooxmlValue("lvl").flatMap(Int.init) {
                    indentLevel = level
                }
                if let alignment = pptAlignment(attributes.ooxmlValue("algn")) {
                    paragraph.style.alignment = alignment
                }
            case "buNone":
                bulletSuppressed = true
            case "r" where inTextBody:
                // Run kế thừa cỡ chữ của run trước trong cùng đoạn — PowerPoint hay chỉ ghi
                // `a:rPr` ở run đầu.
                text = ""
            case "rPr", "defRPr", "endParaRPr":
                inRunProperties = true
                let size = attributes.ooxmlValue("sz").flatMap(Double.init).map { $0 / 100 }
                let bold = attributes.ooxmlValue("b").map(isOOXMLOn)
                let italic = attributes.ooxmlValue("i").map(isOOXMLOn)
                let underline = attributes.ooxmlValue("u").map { $0 != "none" }
                if styleLevel != nil, styleSlot != nil {
                    // Đang ở trong `p:txStyles` — đây là KIỂU MẶC ĐỊNH, không phải chữ có thật.
                    if let size { styleRun.sizePt = size }
                    if let bold { styleRun.bold = bold }
                    if let italic { styleRun.italic = italic }
                    if let underline { styleRun.underline = underline }
                } else {
                    if let size { run.sizePt = size }   // sz đo bằng PHẦN TRĂM point
                    if let bold { run.bold = bold }
                    if let italic { run.italic = italic }
                    if let underline { run.underline = underline }
                }
            case "latin", "cs":
                guard inRunProperties, let font = attributes.ooxmlValue("typeface"),
                      !font.isEmpty, !font.hasPrefix("+")
                else { break }
                if styleLevel != nil { styleRun.fontName = font } else { run.fontName = font }
            case "br" where inTextBody:
                paragraph.inlines.append(.lineBreak)
            case "t" where inTextBody:
                text = ""
            default:
                break
            }
        }

        private var inLine = false

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            let tag = ooxmlLocalName(name)
            switch tag {
            case "titleStyle", "bodyStyle", "otherStyle":
                styleSlot = nil
                styleLevel = nil
            case "lvl1pPr", "lvl2pPr", "lvl3pPr", "lvl4pPr", "lvl5pPr",
                 "lvl6pPr", "lvl7pPr", "lvl8pPr", "lvl9pPr":
                if let slot = styleSlot, let level = styleLevel {
                    switch slot {
                    case .title: result.titleStyle[level] = styleRun
                    case .body: result.bodyStyle[level] = styleRun
                    case .other: result.otherStyle[level] = styleRun
                    }
                }
                styleLevel = nil
            case "bg": inBackground = false
            case "spPr": inShapeProperties = false
            case "grpSpPr":
                inGroupProperties = false
                if let group = pendingGroup { groups.append(group); pendingGroup = nil }
            case "grpSp":
                if !groups.isEmpty { groups.removeLast() }
            case "ln": inLine = false
            case "rPr", "defRPr", "endParaRPr": inRunProperties = false
            case "lstStyle": inListStyle = false
            case "t" where inTextBody && !inListStyle:
                if !text.isEmpty { paragraph.inlines.append(.text(text, run)) }
                text = ""
            case "p" where inTextBody && !inListStyle:
                flushParagraph()
            case "txBody", "txbxContent":
                inTextBody = false
            case "sp", "pic", "graphicFrame", "cxnSp":
                closeShape()
            default:
                break
            }
        }

        // MARK: Dựng

        private func flushParagraph() {
            guard shape != nil else { return }
            paragraph.style.indentLeftPt = Double(indentLevel) * 24
            paragraph.style.listLevel = indentLevel
            // Gạch đầu dòng: PowerPoint bật sẵn cho khung nội dung, tắt cho tiêu đề. Không có
            // `a:buChar` tường minh trong phần lớn tệp — luật này lấy từ hành vi thật của
            // PowerPoint, không lấy từ tệp.
            let isTitle = placeholderType == "title" || placeholderType == "ctrTitle"
            if !bulletSuppressed, !isTitle, !paragraph.plainText.isEmpty {
                paragraph.style.listMarker = indentLevel == 0 ? "•" : "◦"
            }
            if !paragraph.inlines.isEmpty {
                shape?.paragraphs.append(paragraph)
            }
            paragraph = DOCXLayout.Paragraph()
        }

        func closeShape() {
            guard var current = shape else { return }
            shape = nil
            // Quy về hệ toạ độ SLIDE nếu đang nằm trong nhóm.
            for group in groups {
                current.x = group.offsetX + (current.x - group.childX) * group.scaleX
                current.y = group.offsetY + (current.y - group.childY) * group.scaleY
                current.width *= group.scaleX
                current.height *= group.scaleY
            }
            let key = placeholderType.map { "\($0):\(placeholderIndex ?? "")" }
            current.placeholderKey = key
            if let key, current.width > 0, current.height > 0 {
                // Layout và master góp KHUNG cho tầng dưới.
                result.placeholders[key] = current
            }
            guard !current.paragraphs.isEmpty || current.image != nil || current.fill != nil
            else { return }
            result.shapes.append(current)
        }

        private func apply(color: DOCXLayout.Color?) {
            guard let color else { return }
            if inBackground { result.background = color; return }
            if inRunProperties {
                if styleLevel != nil { styleRun.color = color } else { run.color = color }
                return
            }
            if inLine { shape?.stroke = color; return }
            if inShapeProperties { shape?.fill = color }
        }

        private func resolve(
            tag: String, attributes: [String: String]
        ) -> DOCXLayout.Color? {
            switch tag {
            case "srgbClr": return DOCXLayout.Color.hex(attributes.ooxmlValue("val"))
            case "sysClr": return DOCXLayout.Color.hex(attributes.ooxmlValue("lastClr"))
            default:
                guard let name = attributes.ooxmlValue("val") else { return nil }
                return theme[name]
            }
        }

        private func attachImage(relationshipID: String) {
            guard let target = relationships[relationshipID] else { return }
            let path = PPTXLayout.normalise(target, relativeTo: basePath)
            guard let bytes = (try? archive.data(named: path)) ?? nil, !bytes.isEmpty else {
                return
            }
            shape?.image = DOCXLayout.Image(
                data: bytes, widthPt: 0, heightPt: 0, name: path)
        }
    }
}

/// `a:pPr/@algn` → căn lề. Tên khác hẳn Word: `ctr` chứ không `center`.
func pptAlignment(_ value: String?) -> DOCXLayout.Alignment? {
    switch value {
    case "ctr": return .center
    case "r": return .right
    case "just", "dist": return .justified
    case "l": return .left
    default: return nil
    }
}
