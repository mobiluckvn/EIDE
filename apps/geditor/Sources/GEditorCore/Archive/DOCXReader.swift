import Foundation

/// Đọc tài liệu `.docx` thành **Markdown**.
///
/// **Vì sao Markdown chứ không phải văn bản thuần.** GEditor đã có xem trước Markdown, gấp theo
/// cấp, tô màu cú pháp, danh sách hàm nhảy theo tiêu đề. Đưa Word về Markdown là dùng lại cả bốn
/// thứ ấy; đưa về văn bản thuần là vứt cấu trúc đi rồi không lấy lại được. Và Markdown vẫn là
/// văn bản — vẫn ⌘F, vẫn multi-caret, vẫn grep được.
///
/// **Cái giá, nói thẳng:** không giữ font, màu chữ, ảnh nhúng, header/footer, ghi chú lề, hay
/// theo dõi thay đổi. Giữ: tiêu đề theo cấp, đoạn, danh sách có/không đánh số, bảng, đậm và
/// nghiêng, liên kết.
///
/// **Chữ trong Word bị cắt vụn.** Một câu người dùng gõ liền mạch có thể nằm trong năm `<w:r>`
/// khác nhau vì bộ kiểm chính tả, vì một lần sửa cũ, vì con nháy từng dừng ở đó. Nối lại theo
/// ĐOẠN là bắt buộc — xử lý theo từng run sẽ cho ra một tài liệu vỡ vụn giữa các từ.
public struct DOCXReader {

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

    public struct Document: Equatable, Sendable {
        public var markdown: String
        public var paragraphCount: Int
        public var tableCount: Int

        /// Mỗi dòng Markdown thuộc về đoạn `<w:p>` thứ mấy, và tiền tố Markdown dài bao nhiêu.
        ///
        /// Đây là thứ làm cho GHI NGƯỢC khả thi. Không có nó thì lúc lưu phải đoán lại từ văn
        /// bản Markdown xem dòng nào ứng với đoạn nào — mà `## Tiêu đề` và một đoạn thường bắt
        /// đầu bằng `##` là hai thứ khác nhau, còn dòng bảng thì không ứng với đoạn nào cả.
        /// Đoán sẽ đúng gần hết và ghi nhầm chỗ ở phần còn lại.
        public var lineOwners: [LineOwner]

        public struct LineOwner: Equatable, Sendable {
            /// Chỉ số đoạn `<w:p>` theo thứ tự xuất hiện; `nil` = dòng này không phải một đoạn
            /// (dòng trắng, hàng phân cách của bảng).
            public var paragraph: Int?
            /// Số ký tự tiền tố Markdown mà bộ đọc đã thêm (`"## "`, `"- "`, `"> "`).
            public var prefixLength: Int
            /// Với HÀNG BẢNG: chỉ số đoạn của từng ô, theo thứ tự cột.
            ///
            /// Một hàng bảng không ứng với một đoạn nào — nó gồm nhiều ô, mỗi ô lại nhiều đoạn.
            /// Nên nó cần một ánh xạ riêng: ô thứ `i` sửa vào đoạn `cells[i]`. Ô nhiều đoạn thì
            /// chỉ đoạn ĐẦU nhận chữ mới và các đoạn sau bị bỏ trống — cùng luật với run.
            public var cells: [Int]?

            public init(paragraph: Int?, prefixLength: Int, cells: [Int]? = nil) {
                self.paragraph = paragraph
                self.prefixLength = prefixLength
                self.cells = cells
            }
        }
    }

    public static func read(path: String) throws -> Document {
        let archive = try ZipArchive(path: path)
        guard let body = try archive.data(named: "word/document.xml") else {
            throw Failure.notAWordDocument
        }
        // Bảng số hiệu danh sách: cần để biết một mục là "1." hay "-". Thiếu nó thì mọi danh
        // sách đánh số hiện ra thành gạch đầu dòng — đọc được, nhưng mất thứ tự vốn có nghĩa.
        let numbering = (try? archive.data(named: "word/numbering.xml"))
            .flatMap { $0 }
            .map { NumberingParser.parse($0) } ?? [:]

        let delegate = BodyParser(numbering: numbering)
        let parser = XMLParser(data: Data(body))
        parser.delegate = delegate
        guard parser.parse() else { throw Failure.badXML }
        return delegate.finish()
    }
}

// MARK: - numbering.xml

/// `numId` → có phải danh sách ĐÁNH SỐ không.
private enum NumberingParser {
    static func parse(_ data: [UInt8]) -> [Int: Bool] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return [:] }
        // `w:num` trỏ tới `w:abstractNum`; kiểu đánh số nằm ở cái sau.
        var result: [Int: Bool] = [:]
        for (numID, abstractID) in delegate.numToAbstract {
            result[numID] = delegate.orderedAbstract.contains(abstractID)
        }
        return result
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var numToAbstract: [Int: Int] = [:]
        var orderedAbstract: Set<Int> = []
        private var currentNum: Int?
        private var currentAbstract: Int?
        private var currentLevel: Int?

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            switch localName(name) {
            case "num": currentNum = Int(attribute(attributes, "numId") ?? "")
            case "abstractNumId":
                if let num = currentNum, let value = Int(attribute(attributes, "val") ?? "") {
                    numToAbstract[num] = value
                }
            case "abstractNum": currentAbstract = Int(attribute(attributes, "abstractNumId") ?? "")
            case "lvl": currentLevel = Int(attribute(attributes, "ilvl") ?? "")
            case "numFmt":
                // Chỉ xét cấp 0: cấp sâu hơn thường đổi kiểu, và ta chỉ cần biết danh sách này
                // về cơ bản là đánh số hay gạch đầu dòng.
                guard currentLevel == 0, let abstract = currentAbstract else { break }
                let format = attribute(attributes, "val") ?? ""
                if format != "bullet", format != "none" { orderedAbstract.insert(abstract) }
            default: break
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch localName(name) {
            case "num": currentNum = nil
            case "abstractNum": currentAbstract = nil
            case "lvl": currentLevel = nil
            default: break
            }
        }
    }
}

// MARK: - document.xml

/// Không `private`: hai hàm `headingLevel` và `emphasise` là hai nhánh dễ sai nhất của bộ đọc —
/// tên kiểu đã bản địa hoá, và dấu nhấn Markdown không được bọc quanh khoảng trắng. Chúng phải
/// kiểm được trực tiếp thay vì phải dựng một tệp `.docx` cho từng ca.
typealias BodyParserProbe = BodyParser

final class BodyParser: NSObject, XMLParserDelegate {

    private let numbering: [Int: Bool]

    private var lines: [String] = []
    private var owners: [DOCXReader.Document.LineOwner] = []
    private var paragraph = ""
    private var paragraphCount = 0
    private var tableCount = 0

    /// Số thứ tự của `<w:p>` đang dựng, ĐẾM CẢ đoạn rỗng và đoạn trong bảng.
    ///
    /// Khác `paragraphCount` (chỉ đếm đoạn có chữ, dùng cho thống kê): chỉ số này phải khớp
    /// với thứ tự `<w:p>` trong tệp, vì bộ ghi tìm đoạn theo đúng thứ tự ấy.
    private var paragraphOrdinal = -1

    // Kiểu của đoạn đang dựng.
    private var headingLevel: Int?
    private var listLevel: Int?
    private var listOrdered = false
    private var isQuote = false

    // Định dạng chữ của run đang dựng.
    private var bold = false
    private var italic = false
    private var runText = ""
    private var insideText = false
    private var insideDeleted = false
    private var insideFieldCode = false

    // Bảng.
    private var inTable = false
    private var tableRows: [[String]] = []
    private var tableRow: [String] = []
    private var cellParagraphs: [String] = []
    /// Chỉ số `<w:p>` đầu tiên của ô đang dựng; `nil` khi ô chưa có đoạn nào.
    private var cellFirstParagraph: Int?
    private var tableRowCells: [Int] = []
    private var tableRowsCells: [[Int]] = []

    init(numbering: [Int: Bool]) {
        self.numbering = numbering
    }

    func finish() -> DOCXReader.Document {
        flushParagraph()
        // Gộp dòng trắng liên tiếp: Word đầy đoạn rỗng dùng để giãn cách, và giữ nguyên chúng
        // cho ra một tài liệu Markdown loãng gấp đôi mà không thêm thông tin nào.
        //
        // Ánh xạ dòng→đoạn phải gộp THEO, nếu không thì mọi chỉ số sau dòng trắng đầu tiên đều
        // lệch — và bộ ghi sẽ sửa nhầm đoạn.
        var out: [String] = []
        var outOwners: [DOCXReader.Document.LineOwner] = []
        for (line, owner) in zip(lines, owners) {
            if line.isEmpty, out.last?.isEmpty == true { continue }
            out.append(line)
            outOwners.append(owner)
        }
        while out.last?.isEmpty == true { out.removeLast(); outOwners.removeLast() }
        return DOCXReader.Document(
            markdown: out.joined(separator: "\n") + (out.isEmpty ? "" : "\n"),
            paragraphCount: paragraphCount,
            tableCount: tableCount,
            lineOwners: outOwners)
    }

    // MARK: - Thẻ mở

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        switch localName(name) {
        case "p":
            paragraph = ""
            paragraphOrdinal += 1
            headingLevel = nil
            listLevel = nil
            listOrdered = false
            isQuote = false
        case "pStyle":
            let style = attribute(attributes, "val") ?? ""
            headingLevel = Self.headingLevel(ofStyle: style)
            if style.lowercased().contains("quote") { isQuote = true }
        case "numPr":
            listLevel = 0
        case "ilvl":
            listLevel = Int(attribute(attributes, "val") ?? "") ?? 0
        case "numId":
            listOrdered = Int(attribute(attributes, "val") ?? "").flatMap { numbering[$0] } ?? false
        case "b": bold = attribute(attributes, "val") != "0" && attribute(attributes, "val") != "false"
        case "i": italic = attribute(attributes, "val") != "0" && attribute(attributes, "val") != "false"
        case "rPr": bold = false; italic = false
        case "t": insideText = true; runText = ""
        case "delText", "del": insideDeleted = true
        case "instrText": insideFieldCode = true
        case "tab": paragraph += insideDeleted ? "" : "\t"
        case "br": paragraph += insideDeleted ? "" : "  \n"
        case "tbl":
            flushParagraph()
            inTable = true
            tableRows = []
            tableRowsCells = []
            tableCount += 1
        case "tr": tableRow = []; tableRowCells = []
        case "tc": cellParagraphs = []; cellFirstParagraph = nil
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideText, !insideDeleted, !insideFieldCode else { return }
        runText += string
    }

    // MARK: - Thẻ đóng

    func parser(
        _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch localName(name) {
        case "t":
            insideText = false
            paragraph += Self.emphasise(runText, bold: bold, italic: italic)
            runText = ""
        case "delText", "del": insideDeleted = false
        case "instrText": insideFieldCode = false
        case "p":
            if inTable {
                let text = paragraph.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    cellParagraphs.append(text)
                    if cellFirstParagraph == nil { cellFirstParagraph = paragraphOrdinal }
                }
                paragraph = ""
            } else {
                flushParagraph()
            }
        case "tc":
            // Ô nhiều đoạn: nối bằng dấu cách. Xuống dòng bên trong một ô sẽ phá vỡ bảng
            // Markdown — bảng Markdown không có ô nhiều dòng.
            tableRow.append(cellParagraphs.joined(separator: " "))
            // Ô RỖNG vẫn phải có một chỗ trong ánh xạ, nếu không thì chỉ số cột lệch. Dùng
            // `paragraphOrdinal` hiện tại — đoạn cuối cùng đã đi qua trong ô ấy.
            tableRowCells.append(cellFirstParagraph ?? paragraphOrdinal)
        case "tr":
            tableRows.append(tableRow)
            tableRowsCells.append(tableRowCells)
        case "tbl":
            inTable = false
            emitTable()
        default: break
        }
    }

    // MARK: - Dựng dòng

    private func flushParagraph() {
        let text = paragraph.trimmingCharacters(in: .whitespaces)
        paragraph = ""
        guard !text.isEmpty else {
            append("", owner: nil, prefix: 0)
            return
        }
        paragraphCount += 1

        if let level = headingLevel {
            let prefix = String(repeating: "#", count: min(6, level)) + " "
            append(prefix + text, owner: paragraphOrdinal, prefix: prefix.count)
        } else if let level = listLevel {
            let prefix = String(repeating: "  ", count: min(6, level))
                + (listOrdered ? "1. " : "- ")
            append(prefix + text, owner: paragraphOrdinal, prefix: prefix.count)
        } else if isQuote {
            append("> " + text, owner: paragraphOrdinal, prefix: 2)
        } else {
            append(text, owner: paragraphOrdinal, prefix: 0)
        }
        append("", owner: nil, prefix: 0)
    }

    private func append(_ line: String, owner: Int?, prefix: Int) {
        lines.append(line)
        owners.append(.init(paragraph: owner, prefixLength: prefix))
    }

    private func appendRow(_ line: String, cells: [Int]?) {
        lines.append(line)
        owners.append(.init(paragraph: nil, prefixLength: 0, cells: cells))
    }

    private func emitTable() {
        guard !tableRows.isEmpty else { return }
        let width = tableRows.map(\.count).max() ?? 0
        guard width > 0 else { return }

        func row(_ cells: [String]) -> String {
            var padded = cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }
            while padded.count < width { padded.append("") }
            return "| " + padded.joined(separator: " | ") + " |"
        }

        // Hàng đầu thành tiêu đề. Word không phân biệt được chắc chắn hàng tiêu đề với hàng
        // thường, nhưng bảng Markdown BẮT BUỘC có hàng tiêu đề — không có thì nó không còn là
        // bảng. Lấy hàng đầu là phỏng đoán đúng ở gần hết tài liệu thật.
        // Hàng bảng không ứng với MỘT đoạn, nhưng từng Ô thì có — nên nó mang ánh xạ `cells`
        // thay vì `paragraph`. Bộ ghi dùng ánh xạ ấy để sửa đúng ô người dùng vừa đổi.
        appendRow(row(tableRows[0]), cells: tableRowsCells.first)
        append("|" + String(repeating: "---|", count: width), owner: nil, prefix: 0)
        for (index, cells) in tableRows.enumerated().dropFirst() {
            appendRow(row(cells), cells: tableRowsCells[safe: index])
        }
        append("", owner: nil, prefix: 0)
    }

    // MARK: - Trợ giúp

    /// `"Heading2"` · `"Ti\u{1EBF}u\u{0111}\u{1EC1}2"` → 2. `nil` khi không phải tiêu đề.
    ///
    /// Nhận cả tên kiểu đã bản địa hoá: Word lưu tên kiểu theo ngôn ngữ của máy tạo tài liệu,
    /// nên một tệp soạn trên máy tiếng Việt có `w:val="Tiuu1"` chứ không phải `"Heading1"`.
    /// Chỉ so `"Heading"` thì mọi tài liệu ấy mất sạch cấu trúc tiêu đề.
    static func headingLevel(ofStyle style: String) -> Int? {
        let lowered = style.lowercased()
        guard lowered.hasPrefix("heading") || lowered.hasPrefix("ti")
            || lowered.hasPrefix("berschrift")     // tiếng Đức: Überschrift
            || lowered.hasPrefix("titre")          // tiếng Pháp
        else { return nil }
        // Cụm số ở cuối tên kiểu là cấp.
        let digits = lowered.drop { !$0.isNumber }
        guard !digits.isEmpty, let level = Int(digits), level >= 1, level <= 9 else { return nil }
        return level
    }

    /// Bọc dấu nhấn quanh chữ, nhưng KHÔNG bọc quanh khoảng trắng ở hai đầu.
    ///
    /// `**chữ **tiếp` không phải chữ đậm trong Markdown — dấu nhấn phải dính liền chữ. Word thì
    /// hay để khoảng trắng cuối run in đậm, nên bỏ qua vế này sẽ cho ra những dấu sao hiện
    /// nguyên hình trên trang.
    static func emphasise(_ text: String, bold: Bool, italic: Bool) -> String {
        guard bold || italic, !text.isEmpty else { return text }
        let marker = bold && italic ? "***" : (bold ? "**" : "*")
        let leading = text.prefix { $0 == " " || $0 == "\t" }
        let trailing = text.reversed().prefix { $0 == " " || $0 == "\t" }
        let core = text.dropFirst(leading.count).dropLast(trailing.count)
        guard !core.isEmpty else { return text }
        return leading + marker + core + marker + String(trailing.reversed())
    }
}

/// `"w:p"` → `"p"`.
private func localName(_ name: String) -> String {
    guard let colon = name.lastIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Đọc một thuộc tính bất kể nó có tiền tố namespace hay không.
///
/// Cùng lý do với `localName`: `XMLParser` trả tên thuộc tính ĐÚNG NHƯ TRONG TỆP, và tiền tố là
/// do người ghi tệp chọn. Tra thẳng `attribute(attributes, "val")` sẽ đọc được tệp của Word và im lặng
/// bỏ qua mọi thứ ở tệp do thư viện khác sinh ra — kiểu hỏng không báo lỗi, chỉ mất cấu trúc.
private func attribute(_ attributes: [String: String], _ name: String) -> String? {
    if let direct = attributes[name] { return direct }
    for (key, value) in attributes where localName(key) == name { return value }
    return nil
}
