import Foundation

/// Đọc bảng tính `.xlsx` thành hàng và cột.
///
/// **Đích đến là BẢNG CSV của chính GEditor, không phải một khung xem riêng.** Sản phẩm này đã
/// có Query Workbench, bàn làm sạch, biểu đồ, thẻ chất lượng dữ liệu, khai phá theo nhóm — tất
/// cả chạy trên dữ liệu dạng cột. Đưa `.xlsx` về đúng dạng ấy là mở khoá toàn bộ chỗ đó bằng
/// một bộ đọc, thay vì dựng một khung xem chỉ để nhìn.
///
/// Cái giá nói thẳng: **mất bố cục.** Font, màu, ô gộp, biểu đồ nhúng, công thức — không thứ
/// nào đi qua. Thứ đi qua là **giá trị**, và với một công cụ phân tích dữ liệu thì giá trị mới
/// là thứ đáng giá. Công thức đi qua dưới dạng **kết quả đã tính sẵn** trong tệp, tức đúng con
/// số Excel đang hiện.
///
/// **Đọc kiểu SAX chứ không dựng cây.** `XMLDocument` nạp cả tài liệu vào bộ nhớ; một sheet
/// 500.000 hàng cho ra một cây DOM hàng GB. `XMLParser` đi qua một lần và chỉ giữ hàng đang
/// dựng.
public struct XLSXReader {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notASpreadsheet
        case noSheets
        case sheetNotFound(String)
        case badXML(part: String)

        public var description: String {
            switch self {
            case .notASpreadsheet: return "Tệp này không phải bảng tính Excel"
            case .noSheets: return "Bảng tính không có sheet nào"
            case .sheetNotFound(let name): return "Không có sheet «\(name)»"
            case .badXML(let part): return "Phần «\(part)» trong tệp không đọc được"
            }
        }
    }

    public struct Sheet: Equatable, Sendable {
        public var name: String
        /// Đường dẫn trong file nén, ví dụ `xl/worksheets/sheet1.xml`.
        public var path: String
    }

    /// Kết quả đọc một sheet.
    public struct Grid: Equatable, Sendable {
        public var rows: [[String]]
        /// Đã cắt bớt vì vượt trần chưa — phải nói ra, không được im lặng.
        public var truncated: Bool
        /// Số cột rộng nhất gặp được; mọi hàng đã được đệm về đúng bề rộng này.
        public var columnCount: Int
    }

    /// Trần số hàng đọc vào bộ nhớ một lượt.
    ///
    /// Excel không cho quá 1.048.576 hàng nên trần này là giới hạn thật của định dạng, không
    /// phải một con số tuỳ tiện. Nhưng vẫn phải có: một tệp dựng bằng máy có thể khai nhiều hơn,
    /// và khi ấy ta nên cắt và NÓI RA thay vì ăn hết bộ nhớ.
    public static let rowLimit = 1_048_576

    public let sheets: [Sheet]
    private let archive: ZipArchive
    private let sharedStrings: [String]
    private let dateStyles: Set<Int>
    private let uses1904: Bool

    // MARK: - Mở

    public init(path: String) throws {
        let archive = try ZipArchive(path: path)
        self.archive = archive

        guard let workbookData = try archive.data(named: "xl/workbook.xml") else {
            throw Failure.notASpreadsheet
        }
        let workbook = try WorkbookParser.parse(workbookData)
        guard !workbook.sheets.isEmpty else { throw Failure.noSheets }
        self.uses1904 = workbook.date1904

        // Tên sheet nối với tệp sheet qua bảng quan hệ, KHÔNG qua thứ tự.
        //
        // Cách hiển nhiên hơn — sheet thứ n là `sheet(n+1).xml` — đúng với phần lớn tệp và sai
        // với những tệp đã từng bị xoá sheet: đánh số tệp giữ nguyên khoảng trống, nên sheet
        // thứ hai có thể nằm ở `sheet3.xml`. Kiểu hỏng ấy là hiện ra ĐÚNG dữ liệu dưới SAI tên.
        let relationships = (try? archive.data(named: "xl/_rels/workbook.xml.rels"))
            .flatMap { $0 }
            .map { RelationshipParser.parse($0) } ?? [:]

        self.sheets = workbook.sheets.enumerated().map { index, sheet in
            let target = sheet.relationshipID.flatMap { relationships[$0] }
            let path = target.map { Self.resolve($0, base: "xl") }
                ?? "xl/worksheets/sheet\(index + 1).xml"
            return Sheet(name: sheet.name, path: path)
        }

        self.sharedStrings = (try? archive.data(named: "xl/sharedStrings.xml"))
            .flatMap { $0 }
            .map { SharedStringParser.parse($0) } ?? []

        self.dateStyles = (try? archive.data(named: "xl/styles.xml"))
            .flatMap { $0 }
            .map { XLSXStyleParser.dateStyleIndexes($0) } ?? []
    }

    /// Đường dẫn tương đối trong OOXML, giải theo thư mục chứa tệp quan hệ.
    private static func resolve(_ target: String, base: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        var parts = base.split(separator: "/").map(String.init)
        for piece in target.split(separator: "/") {
            if piece == ".." { _ = parts.popLast() } else if piece != "." {
                parts.append(String(piece))
            }
        }
        return parts.joined(separator: "/")
    }

    // MARK: - Đọc một sheet

    public func grid(of sheet: Sheet) throws -> Grid {
        guard let data = try archive.data(named: sheet.path) else {
            throw Failure.sheetNotFound(sheet.name)
        }
        let parser = SheetParser(
            sharedStrings: sharedStrings, dateStyles: dateStyles, uses1904: uses1904)
        return parser.parse(data)
    }

    public func grid(named name: String) throws -> Grid {
        guard let sheet = sheets.first(where: { $0.name == name }) else {
            throw Failure.sheetNotFound(name)
        }
        return try grid(of: sheet)
    }

    /// Sheet đầu tiên — thứ mở ra khi người dùng bấm vào tệp.
    public func firstGrid() throws -> Grid {
        guard let sheet = sheets.first else { throw Failure.noSheets }
        return try grid(of: sheet)
    }

    // MARK: - Sang CSV

    /// Dựng văn bản CSV từ một lưới.
    ///
    /// Bọc giá trị bằng `CSVEngine.escape` của lõi, KHÔNG tự viết lại.
    ///
    /// Bản đầu của hàm này có một hàm `quote` riêng — và nó đã lệch với bản của lõi ở đúng một
    /// ca: ô có khoảng trắng ở đầu hoặc cuối. `CSVEngine.escape` bọc ca ấy (nếu không thì đọc
    /// lại sẽ mất khoảng trắng), bản tự viết thì không. Hai bộ luật trích dẫn trong cùng một
    /// kho là chuyện sớm muộn sẽ lệch, và lệch ở chỗ không ai nghĩ tới.
    public static func csv(from grid: Grid, dialect: CSVDialect = .comma) -> String {
        let separator = String(UnicodeScalar(dialect.delimiter))
        var out = ""
        out.reserveCapacity(grid.rows.count * 32)
        for row in grid.rows {
            out += row.map { CSVEngine.escape($0, dialect: dialect) }
                .joined(separator: separator)
            out += "\n"
        }
        return out
    }

    // MARK: - Tham chiếu ô

    /// `"C5"` → cột 2 (0-based). Trả `nil` khi chuỗi không phải tham chiếu ô.
    ///
    /// Cần vì ô trong XLSX là THƯA: `<c r="C5">` không có nghĩa là ô thứ ba của hàng — hai ô
    /// trước nó có thể vắng mặt hoàn toàn. Bỏ qua vế này thì mọi bảng có ô trống bị dồn cột.
    public static func columnIndex(ofReference reference: String) -> Int? {
        var value = 0
        var sawLetter = false
        for character in reference.uppercased() {
            guard let ascii = character.asciiValue else { return nil }
            if ascii >= 65, ascii <= 90 {
                value = value * 26 + Int(ascii - 64)
                sawLetter = true
            } else if ascii >= 48, ascii <= 57 {
                break                     // tới phần số hàng thì thôi
            } else {
                return nil
            }
        }
        return sawLetter ? value - 1 : nil
    }

    /// Đổi số sê-ri ngày của Excel thành chuỗi ISO.
    ///
    /// **Mốc là 30/12/1899, không phải 01/01/1900.** Excel cố ý giữ lại lỗi của Lotus 1-2-3 —
    /// nó tin 1900 là năm nhuận và có ngày 29/02/1900 không tồn tại. Lấy mốc 01/01/1900 rồi trừ
    /// đi sẽ đúng cho mọi ngày từ 01/03/1900 và LỆCH MỘT NGÀY cho hai tháng đầu năm 1900. Mốc
    /// 30/12/1899 nuốt luôn cả hai sai số.
    static func date(fromSerial serial: Double, uses1904: Bool) -> String? {
        guard serial.isFinite, serial >= 0, serial < 2_958_466 else { return nil }
        var components = DateComponents()
        components.year = uses1904 ? 1904 : 1899
        components.month = uses1904 ? 1 : 12
        components.day = uses1904 ? 1 : 30
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let epoch = calendar.date(from: components) else { return nil }

        let days = floor(serial)
        let fraction = serial - days
        // Làm tròn về giây: 0,4 giây lệch là do dấu phẩy động, không phải do dữ liệu.
        let seconds = (fraction * 86_400).rounded()
        guard let moment = calendar.date(
            byAdding: .second, value: Int(days * 86_400 + seconds), to: epoch) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Ngày tròn thì không in phần giờ — một cột ngày sinh mà mọi ô đều kết thúc bằng
        // "00:00:00" là một cột khó đọc hơn hẳn mà không thêm thông tin nào.
        formatter.dateFormat = seconds == 0 && fraction == 0
            ? "yyyy-MM-dd" : "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: moment)
    }
}

// MARK: - workbook.xml

private enum WorkbookParser {
    struct Result {
        var sheets: [(name: String, relationshipID: String?)] = []
        var date1904 = false
    }

    static func parse(_ data: [UInt8]) throws -> Result {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { throw XLSXReader.Failure.badXML(part: "xl/workbook.xml") }
        return delegate.result
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var result = Result()

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            switch local(name) {
            case "sheet":
                result.sheets.append((
                    name: attributes["name"] ?? "Sheet\(result.sheets.count + 1)",
                    relationshipID: attributes["r:id"] ?? attributes["id"]))
            case "workbookPr":
                result.date1904 = attributes["date1904"] == "1"
                    || attributes["date1904"] == "true"
            default: break
            }
        }
    }
}

// MARK: - workbook.xml.rels

private enum RelationshipParser {
    static func parse(_ data: [UInt8]) -> [String: String] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return [:] }
        return delegate.map
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var map: [String: String] = [:]
        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            guard local(name) == "Relationship",
                  let id = attributes["Id"], let target = attributes["Target"] else { return }
            map[id] = target
        }
    }
}

// MARK: - sharedStrings.xml

private enum SharedStringParser {
    static func parse(_ data: [UInt8]) -> [String] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return delegate.strings }
        return delegate.strings
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var strings: [String] = []
        private var current = ""
        private var insideItem = false
        private var insideText = false

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            switch local(name) {
            case "si": insideItem = true; current = ""
            case "t": insideText = true
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            // Chuỗi có định dạng phong phú bị Excel cắt thành nhiều `<r><t>` — nối lại, nếu
            // không thì một ô chữ in đậm giữa câu sẽ chỉ còn lại mảnh cuối.
            if insideItem, insideText { current += string }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch local(name) {
            case "t": insideText = false
            case "si": strings.append(current); insideItem = false
            default: break
            }
        }
    }
}

// MARK: - styles.xml

/// Không `private`: `looksLikeDate` là nhánh dễ sai nhất của cả bộ đọc — phân biệt "tháng" với
/// chữ `m` trong một chuỗi hiển thị — và nó phải kiểm được trực tiếp thay vì phải dựng cả một
/// tệp `.xlsx` cho mỗi ca.
enum XLSXStyleParser {
    /// Chỉ số của những `cellXf` mang định dạng NGÀY.
    ///
    /// Không có bước này thì mọi cột ngày hiện ra dưới dạng số sê-ri — `45678` thay vì
    /// `2025-01-15`. Đó là kiểu hỏng vừa im lặng vừa vô dụng: con số đúng, ý nghĩa mất sạch.
    static func dateStyleIndexes(_ data: [UInt8]) -> Set<Int> {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(data))
        parser.delegate = delegate
        guard parser.parse() else { return [] }

        var result: Set<Int> = []
        for (index, numFmtID) in delegate.cellXfs.enumerated() {
            if builtinDateFormats.contains(numFmtID) { result.insert(index) }
            else if let code = delegate.customFormats[numFmtID], looksLikeDate(code) {
                result.insert(index)
            }
        }
        return result
    }

    /// Mã định dạng dựng sẵn của Excel dành cho ngày và giờ. Chúng không nằm trong tệp — mọi
    /// bảng tính đều ngầm hiểu, nên phải kê ở đây.
    private static let builtinDateFormats: Set<Int> = [
        14, 15, 16, 17, 18, 19, 20, 21, 22,
        27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
        45, 46, 47, 50, 51, 52, 53, 54, 55, 56, 57, 58,
    ]

    /// Mã định dạng tự đặt có phải kiểu ngày/giờ không.
    ///
    /// Bỏ qua phần trong ngoặc kép và sau dấu `\`: một định dạng tiền tệ `#,##0" đ"` có chữ `đ`
    /// vô hại, nhưng `"m"` trong một chuỗi hiển thị thì không được tính là "tháng".
    static func looksLikeDate(_ code: String) -> Bool {
        var inQuote = false
        var iterator = code.makeIterator()
        while let character = iterator.next() {
            if character == "\"" { inQuote.toggle(); continue }
            if character == "\\" { _ = iterator.next(); continue }
            if character == "[" {
                while let skip = iterator.next(), skip != "]" {}
                continue
            }
            guard !inQuote else { continue }
            if "ymdhsYMDHS".contains(character) { return true }
        }
        return false
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var cellXfs: [Int] = []
        var customFormats: [Int: String] = [:]
        private var insideCellXfs = false

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            switch local(name) {
            case "cellXfs": insideCellXfs = true
            case "xf" where insideCellXfs:
                cellXfs.append(Int(attributes["numFmtId"] ?? "0") ?? 0)
            case "numFmt":
                if let id = Int(attributes["numFmtId"] ?? ""), let code = attributes["formatCode"] {
                    customFormats[id] = code
                }
            default: break
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            if local(name) == "cellXfs" { insideCellXfs = false }
        }
    }
}

// MARK: - worksheet

private final class SheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private let dateStyles: Set<Int>
    private let uses1904: Bool

    private var rows: [[String]] = []
    private var row: [String] = []
    private var truncated = false

    private var cellType = ""
    private var cellStyle = -1
    private var cellColumn = 0
    private var value = ""
    private var insideValue = false
    private var insideInlineText = false
    private var widest = 0

    init(sharedStrings: [String], dateStyles: Set<Int>, uses1904: Bool) {
        self.sharedStrings = sharedStrings
        self.dateStyles = dateStyles
        self.uses1904 = uses1904
    }

    func parse(_ data: [UInt8]) -> XLSXReader.Grid {
        let parser = XMLParser(data: Data(data))
        parser.delegate = self
        _ = parser.parse()
        // Đệm mọi hàng về cùng bề rộng. Bảng răng cưa làm mọi thứ phía sau — bảng CSV, truy vấn
        // SQL, thẻ chất lượng — phải tự đoán bề rộng, và mỗi chỗ sẽ đoán một kiểu.
        let padded = rows.map { row -> [String] in
            row.count == widest ? row : row + Array(repeating: "", count: widest - row.count)
        }
        return XLSXReader.Grid(rows: padded, truncated: truncated, columnCount: widest)
    }

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        switch local(name) {
        case "row":
            row = []
            cellColumn = 0
        case "c":
            cellType = attributes["t"] ?? "n"
            cellStyle = Int(attributes["s"] ?? "") ?? -1
            // Ô THƯA: `r="C5"` khi hai ô trước vắng mặt. Đệm cho tới đúng cột.
            if let reference = attributes["r"],
               let column = XLSXReader.columnIndex(ofReference: reference) {
                while row.count < column { row.append("") }
            }
            value = ""
        case "v", "t":
            insideValue = true
        case "is":
            insideInlineText = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideValue { value += string }
    }

    func parser(
        _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch local(name) {
        case "v", "t":
            insideValue = false
        case "is":
            insideInlineText = false
        case "c":
            row.append(render())
            cellColumn += 1
        case "row":
            guard rows.count < XLSXReader.rowLimit else {
                truncated = true
                parser.abortParsing()
                return
            }
            widest = max(widest, row.count)
            rows.append(row)
        default: break
        }
    }

    /// Giá trị hiển thị của ô đang đóng.
    private func render() -> String {
        switch cellType {
        case "s":
            // Chỉ số vào bảng chuỗi dùng chung.
            guard let index = Int(value), sharedStrings.indices.contains(index) else { return "" }
            return sharedStrings[index]
        case "inlineStr", "str":
            return value
        case "b":
            // Excel ghi 0/1; hiện ra TRUE/FALSE như chính nó hiện.
            return value == "1" ? "TRUE" : "FALSE"
        case "e":
            return value          // #DIV/0!, #N/A… — giữ nguyên, đó là thứ Excel hiện
        default:
            guard !value.isEmpty else { return "" }
            if dateStyles.contains(cellStyle), let number = Double(value),
               let stamp = XLSXReader.date(fromSerial: number, uses1904: uses1904) {
                return stamp
            }
            return value
        }
    }
}

// MARK: - Tên thẻ không kèm namespace

/// `"x:sheet"` → `"sheet"`.
///
/// Cần vì tệp do các công cụ khác nhau ghi ra dùng tiền tố khác nhau — Excel thường không dùng
/// tiền tố, còn thư viện sinh tệp thì hay dùng. So chuỗi nguyên vẹn sẽ đọc được tệp của Excel
/// và im lặng trả về bảng rỗng cho tệp của mọi công cụ khác.
private func local(_ name: String) -> String {
    guard let colon = name.lastIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}
