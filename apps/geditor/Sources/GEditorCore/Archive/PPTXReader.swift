import Foundation

/// Đọc bản trình chiếu `.pptx` thành **dàn ý Markdown**.
///
/// **Dàn ý, không phải bản dựng lại slide.** Vẽ lại một slide đòi bố cục hình học, theme, kế
/// thừa từ slide master, hiệu ứng — cả một engine, và kết quả tốt nhất cũng chỉ bằng bản gốc.
/// Thứ người ta thật sự cần khi mở `.pptx` trong một trình soạn thảo là **chữ**: tìm được, chép
/// được, sửa được, đưa sang tài liệu khác được.
///
/// **Thứ tự slide đọc từ bảng quan hệ, không từ tên tệp.** `slide10.xml` sắp trước `slide2.xml`
/// khi so chuỗi, và sắp sai thứ tự là hỏng đúng thứ duy nhất mà dàn ý phải giữ.
public struct PPTXReader {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notAPresentation

        public var description: String {
            switch self {
            case .notAPresentation: return "Tệp này không phải bản trình chiếu PowerPoint"
            }
        }
    }

    /// Một đoạn chữ trong slide, kèm chỗ nó nằm trong tệp — cần cho việc ghi ngược.
    public struct Line: Equatable, Sendable {
        public var text: String
        /// Chỉ số `<a:p>` trong tệp XML của slide, đếm cả đoạn rỗng.
        public var ordinal: Int
    }

    public struct Slide: Equatable, Sendable {
        public var index: Int
        /// Đường dẫn tệp XML của slide trong file nén.
        public var path: String
        /// Dòng chữ đầu tiên của slide — gần như luôn là tiêu đề.
        public var title: String
        public var lines: [Line]
        public var notes: [Line]
        public var notesPath: String?
        /// Chỉ số `<a:p>` của dòng tiêu đề; `nil` khi slide không có chữ nào.
        public var titleOrdinal: Int?
    }

    /// Mỗi dòng Markdown thuộc về đoạn nào, trong tệp nào. Xem `DOCXReader.Document.LineOwner`.
    public struct LineOwner: Equatable, Sendable {
        /// `nil` = dòng này không sửa ngược được (tiêu đề slide do ta sinh, dòng trắng).
        public var file: String?
        public var paragraph: Int?
        public var prefixLength: Int
    }

    /// Vai trò của một dòng trong dàn ý. Đây là thứ chế độ View dựng cây từ đó.
    public enum LineRole: UInt8, Equatable, Sendable {
        case title, bullet, noteHeading, note, blank
    }

    /// Một dòng Markdown nhìn từ phía DÀN Ý: nó là gì, của slide nào, nằm ở byte nào.
    ///
    /// Song song với `lineOwners` — cái kia trả lời "sửa dòng này thì ghi ngược vào đâu", cái
    /// này trả lời "dựng cây thì dòng này thành nút gì".
    public struct OutlineLine: Equatable, Sendable {
        public var role: LineRole
        /// Chỉ số trong `slides`; `-1` với dòng không thuộc slide nào.
        public var slide: Int
        /// Khoảng byte trong `markdown`.
        public var range: Range<Int>
    }

    public struct Presentation: Equatable, Sendable {
        public var slides: [Slide]
        public var markdown: String
        public var lineOwners: [LineOwner]
        public var outline: [OutlineLine]
    }

    public static func read(path: String) throws -> Presentation {
        let archive = try ZipArchive(path: path)
        guard archive.entries.contains(where: { $0.path == "ppt/presentation.xml" }) else {
            throw Failure.notAPresentation
        }

        let order = (try? archive.data(named: "ppt/_rels/presentation.xml.rels"))
            .flatMap { $0 }
            .map { SlideOrder.parse($0) } ?? [:]
        let ids = (try? archive.data(named: "ppt/presentation.xml"))
            .flatMap { $0 }
            .map { SlideOrder.slideIDs($0) } ?? []

        // Đường đi ưu tiên: thứ tự trong `presentation.xml` → rId → tên tệp. Không có thì lùi về
        // sắp tên tệp theo SỐ (không phải theo chuỗi).
        var paths = ids.compactMap { order[$0] }.map { "ppt/" + $0.replacingOccurrences(
            of: "../", with: "") }
        if paths.isEmpty {
            paths = archive.entries
                .map(\.path)
                .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
                .sorted { slideNumber($0) < slideNumber($1) }
        }

        var slides: [Slide] = []
        for (index, path) in paths.enumerated() {
            guard let data = (try? archive.data(named: path)) ?? nil else { continue }
            let lines = TextParser.lines(data)
            // Ghi chú của người trình bày nằm ở tệp khác, đánh số theo slide.
            let notesPath = "ppt/notesSlides/notesSlide\(index + 1).xml"
            let notesData = (try? archive.data(named: notesPath)) ?? nil
            slides.append(Slide(
                index: index + 1,
                path: path,
                title: lines.first?.text ?? "",
                lines: Array(lines.dropFirst()),
                notes: notesData.map { TextParser.lines($0) } ?? [],
                notesPath: notesData == nil ? nil : notesPath,
                titleOrdinal: lines.first?.ordinal))
        }

        let built = build(from: slides)
        return Presentation(slides: slides, markdown: built.markdown,
                            lineOwners: built.owners, outline: built.outline)
    }

    static func slideNumber(_ path: String) -> Int {
        let name = (path as NSString).lastPathComponent
        let digits = name.drop { !$0.isNumber }.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    static func markdown(from slides: [Slide]) -> String { build(from: slides).markdown }

    /// Dựng dàn ý Markdown VÀ ánh xạ dòng→đoạn cùng một lượt.
    ///
    /// Cùng một lượt vì hai thứ phải khớp tuyệt đối: dựng riêng rồi ghép lại là mời một lỗi
    /// lệch chỉ số mà không bài kiểm nào của phần dựng chữ bắt được.
    static func build(
        from slides: [Slide]
    ) -> (markdown: String, owners: [LineOwner], outline: [OutlineLine]) {
        var out: [String] = []
        var owners: [LineOwner] = []
        var outline: [OutlineLine] = []
        var offset = 0
        var slideIndex = -1

        func add(_ line: String, file: String?, paragraph: Int?, prefix: Int, role: LineRole) {
            out.append(line)
            owners.append(LineOwner(file: file, paragraph: paragraph, prefixLength: prefix))
            let length = line.utf8.count
            outline.append(OutlineLine(
                role: role, slide: role == .blank ? -1 : slideIndex,
                range: offset ..< (offset + length)))
            offset += length + 1        // +1 cho dấu xuống dòng mà `joined` chèn vào
        }

        for slide in slides {
            slideIndex += 1
            if slide.title.isEmpty {
                // Không có chữ nào: dòng tiêu đề là do TA sinh ra, không ứng với đoạn nào.
                add("## " + String(format: "Slide %d", slide.index),
                    file: nil, paragraph: nil, prefix: 0, role: .title)
            } else {
                // Tiền tố gồm "## " cộng "N. " — sửa dòng này là sửa đúng đoạn tiêu đề.
                let prefix = "## \(slide.index). "
                add(prefix + slide.title,
                    file: slide.path, paragraph: slide.titleOrdinal, prefix: prefix.count,
                    role: .title)
            }
            add("", file: nil, paragraph: nil, prefix: 0, role: .blank)

            for line in slide.lines where !line.text.isEmpty {
                add("- " + line.text, file: slide.path, paragraph: line.ordinal, prefix: 2,
                    role: .bullet)
            }
            if !slide.notes.isEmpty {
                add("", file: nil, paragraph: nil, prefix: 0, role: .blank)
                add("> **Ghi chú người trình bày**", file: nil, paragraph: nil, prefix: 0,
                    role: .noteHeading)
                for note in slide.notes where !note.text.isEmpty {
                    add("> " + note.text,
                        file: slide.notesPath, paragraph: note.ordinal, prefix: 2, role: .note)
                }
            }
            add("", file: nil, paragraph: nil, prefix: 0, role: .blank)
        }
        return (out.joined(separator: "\n"), owners, outline)
    }
}

// MARK: - Thứ tự slide

private enum SlideOrder {
    /// rId → đường dẫn tệp slide.
    static func parse(_ data: [UInt8]) -> [String: String] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return [:] }
        return delegate.map
    }

    /// Danh sách rId theo ĐÚNG thứ tự trình chiếu.
    static func slideIDs(_ data: [UInt8]) -> [String] {
        let delegate = IDDelegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        return delegate.ids
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var map: [String: String] = [:]
        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            guard tag(name) == "Relationship",
                  let id = attributes["Id"], let target = attributes["Target"],
                  target.contains("slides/slide") else { return }
            map[id] = target
        }
    }

    private final class IDDelegate: NSObject, XMLParserDelegate {
        var ids: [String] = []
        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            guard tag(name) == "sldId" else { return }
            for (key, value) in attributes where tag(key) == "id" && key.contains("r:") {
                ids.append(value)
            }
            if let direct = attributes["r:id"], !ids.contains(direct) { ids.append(direct) }
        }
    }
}

// MARK: - Chữ trong slide

private enum TextParser {
    /// Mỗi `<a:p>` một dòng; chữ trong đó bị cắt thành nhiều `<a:r>` nên phải nối lại — cùng
    /// bài học với Word.
    static func lines(_ data: [UInt8]) -> [PPTXReader.Line] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return delegate.lines }
        return delegate.lines
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var lines: [PPTXReader.Line] = []
        private var current = ""
        private var insideText = false
        /// Đếm CẢ đoạn rỗng: bộ ghi tìm `<a:p>` theo thứ tự trong tệp, nên chỉ số phải khớp
        /// với tệp chứ không khớp với danh sách đã lọc.
        private var ordinal = -1

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            switch tag(name) {
            case "p": current = ""; ordinal += 1
            case "t": insideText = true
            case "br": current += " "
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideText { current += string }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch tag(name) {
            case "t": insideText = false
            case "p":
                let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { lines.append(.init(text: text, ordinal: ordinal)) }
                current = ""
            default: break
            }
        }
    }
}

private func tag(_ name: String) -> String {
    guard let colon = name.lastIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}
