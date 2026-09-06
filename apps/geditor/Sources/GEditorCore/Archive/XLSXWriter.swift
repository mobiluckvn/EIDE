import Foundation

/// Ghi giá trị ô đã sửa ngược vào tệp `.xlsx`, **không đụng tới phần còn lại**.
///
/// **Vì sao sửa tại chỗ chứ không dựng lại sheet.** Bộ đọc chỉ hiểu GIÁ TRỊ ô — nó không hiểu
/// định dạng, ô gộp, công thức, xác thực dữ liệu, định dạng có điều kiện, ghim hàng, bộ lọc.
/// Dựng lại `sheetN.xml` từ những gì nó hiểu là **xoá sạch những gì nó không hiểu**, và người
/// dùng chỉ phát hiện ra khi mở tệp bằng Excel. Nên: tìm đúng ô cần đổi trong XML gốc, thay
/// đúng phần giá trị, giữ nguyên từng byte còn lại.
///
/// Cùng lối "không đụng bản gốc" mà chú thích PDF đang dùng, và cùng lối `mobiluck-reader` đã
/// chốt cho PDF ở §B/§K.
///
/// **Làm việc trên VĂN BẢN XML, không qua cây DOM.** `XMLDocument` đọc rồi ghi lại sẽ đổi thứ
/// tự thuộc tính, cách viết namespace, và khoảng trắng — hàng nghìn byte khác đi cho một thay
/// đổi một ô. Một bộ so tệp sẽ báo cả sheet đã đổi, và một chữ ký số (nếu có) sẽ vỡ.
public enum XLSXWriter {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case shapeChanged(was: Int, now: Int)
        case middleRowChange(row: Int, reason: String)
        case sheetMissing
        case cellNotFound(row: Int, column: Int)
        case verificationFailed(String)

        public var description: String {
            switch self {
            case .shapeChanged(let was, let now):
                return "Số hàng đã đổi từ \(was) thành \(now) — thêm/xoá hàng chưa ghi ngược được"
            case .middleRowChange(let row, let reason):
                return "Thêm/xoá hàng ở GIỮA bảng (từ hàng \(row + 1)) chưa ghi ngược được: \(reason)"
            case .sheetMissing:
                return "Không tìm thấy sheet trong tệp"
            case .cellNotFound(let row, let column):
                return "Không tìm thấy ô ở hàng \(row + 1), cột \(column + 1) trong tệp gốc"
            case .verificationFailed(let detail):
                return "Tệp vừa ghi đọc lại KHÔNG khớp: \(detail)"
            }
        }
    }

    /// Một ô đã đổi.
    public struct Change: Equatable, Sendable {
        public var row: Int
        public var column: Int
        public var value: String

        public init(row: Int, column: Int, value: String) {
            self.row = row
            self.column = column
            self.value = value
        }
    }

    /// Kết quả so hai lưới: ô đã đổi, cộng phần hàng thêm vào hoặc bớt đi ở CUỐI bảng.
    public struct Diff: Equatable, Sendable {
        public var changes: [Change]
        /// Những hàng thêm vào sau hàng cuối cùng của bản gốc.
        public var appended: [[String]]
        /// Số hàng bị cắt đi ở cuối bản gốc.
        public var truncated: Int
    }

    /// So hai lưới, trả về những ô khác nhau.
    ///
    /// So ở mức LƯỚI chứ không ở mức văn bản CSV: hai chuỗi CSV có thể khác nhau chỉ vì cách
    /// trích dẫn (`a` với `"a"`) trong khi giá trị y hệt. So văn bản sẽ báo "đã sửa" cho một
    /// tệp không ai đụng, và lượt ghi ngược sẽ đổi cả nghìn ô mà không cần.
    public static func changes(from old: [[String]], to new: [[String]]) throws -> [Change] {
        guard old.count == new.count else {
            throw Failure.shapeChanged(was: old.count, now: new.count)
        }
        return try diff(from: old, to: new).changes
    }

    /// So hai lưới, chấp nhận cả việc THÊM hoặc BỚT hàng ở CUỐI bảng.
    ///
    /// **Vì sao chỉ ở cuối.** Chèn hay xoá một hàng ở GIỮA làm mọi hàng phía sau đổi số hiệu,
    /// và số hiệu hàng không chỉ nằm ở thuộc tính `r`: công thức (`=A5`), vùng ô gộp, định dạng
    /// có điều kiện, xác thực dữ liệu, vùng in, tên đã đặt — tất cả đều tham chiếu theo A1.
    /// Đánh số lại mà không sửa hết những chỗ ấy là **làm hỏng tệp một cách im lặng**: nó vẫn
    /// mở được, chỉ là vài công thức trỏ sai chỗ. Thêm/bớt ở cuối thì không đụng tới hàng nào
    /// đang có, nên không có gì phải đánh số lại.
    public static func diff(from old: [[String]], to new: [[String]]) throws -> Diff {
        let shared = min(old.count, new.count)
        var changes: [Change] = []
        for index in 0 ..< shared {
            let before = old[index], after = new[index]
            let width = max(before.count, after.count)
            for column in 0 ..< width {
                let a = column < before.count ? before[column] : ""
                let b = column < after.count ? after[column] : ""
                if a != b { changes.append(Change(row: index, column: column, value: b)) }
            }
        }
        return Diff(
            changes: changes,
            appended: new.count > shared ? Array(new[shared...]) : [],
            truncated: max(0, old.count - new.count))
    }

    /// Áp các thay đổi vào tệp, ghi ra `destination`, rồi ĐỌC LẠI để đối chứng.
    ///
    /// Đối chứng không phải thủ tục cho đẹp: một tệp ghi hỏng vẫn nằm trên đĩa trông như tệp
    /// bình thường, và người dùng chỉ phát hiện khi đã gửi nó đi. Cùng luật với "Lưu bản có
    /// chú thích" của PDF.
    public static func write(
        source path: String, sheet: XLSXReader.Sheet, changes: [Change], to destination: String
    ) throws {
        try write(source: path, sheet: sheet,
                  diff: Diff(changes: changes, appended: [], truncated: 0), to: destination)
    }

    public static func write(
        source path: String, sheet: XLSXReader.Sheet, diff: Diff, to destination: String
    ) throws {
        let archive = try ZipArchive(path: path)
        guard let original = try archive.data(named: sheet.path) else { throw Failure.sheetMissing }
        let changes = diff.changes

        var edited = try apply(changes, toSheetXML: original)
        if diff.truncated > 0 || !diff.appended.isEmpty {
            edited = try applyRowCountChange(diff, to: edited)
        }
        try ZipWriter.rewrite(archive, replacing: [sheet.path: edited], to: destination)

        // ĐỐI CHỨNG: mở lại bằng chính bộ đọc và đòi mọi ô vừa sửa mang đúng giá trị mới.
        let again = try XLSXReader(path: destination)
        guard let sameSheet = again.sheets.first(where: { $0.name == sheet.name }) else {
            throw Failure.verificationFailed("mất sheet «\(sheet.name)»")
        }
        let grid = try again.grid(of: sameSheet)
        for (offset, row) in diff.appended.enumerated() {
            let index = grid.rows.count - diff.appended.count + offset
            guard index >= 0, index < grid.rows.count else {
                throw Failure.verificationFailed("hàng thêm vào không có trong tệp")
            }
            for (column, value) in row.enumerated() where !value.isEmpty {
                guard column < grid.rows[index].count, grid.rows[index][column] == value else {
                    throw Failure.verificationFailed(
                        "hàng thêm vào sai ở cột \(column + 1): mong «\(value)»")
                }
            }
        }
        for change in changes {
            guard change.row < grid.rows.count,
                  change.column < grid.rows[change.row].count else {
                throw Failure.verificationFailed(
                    "hàng \(change.row + 1) cột \(change.column + 1) biến mất")
            }
            let actual = grid.rows[change.row][change.column]
            guard actual == change.value else {
                throw Failure.verificationFailed(
                    "hàng \(change.row + 1) cột \(change.column + 1) ra «\(actual)», mong «\(change.value)»")
            }
        }
    }

    /// Ghi ĐÈ chính tệp gốc — nhưng chỉ sau khi bản mới đã đọc lại đúng.
    ///
    /// Thứ tự ở đây là toàn bộ sự an toàn của phép ghi, và nó không được đảo:
    ///
    /// 1. Ghi ra một tệp TẠM bên cạnh.
    /// 2. Mở tệp tạm bằng chính bộ đọc, đòi mọi ô vừa sửa mang đúng giá trị mới.
    /// 3. Chỉ khi ấy mới thay tệp gốc, bằng một phép đổi tên NGUYÊN TỬ.
    ///
    /// Ghi thẳng vào tệp gốc rồi kiểm sau thì lúc phát hiện sai đã muộn: bản gốc không còn.
    /// Đây là cùng một luật với "Lưu bản có chú thích" của PDF, chỉ khác ở chỗ người dùng đã
    /// chủ động mở tệp này để SỬA, nên ghi đè là thứ họ đang xin.
    public static func writeInPlace(
        source path: String, sheet: XLSXReader.Sheet, changes: [Change]
    ) throws {
        try writeInPlace(source: path, sheet: sheet,
                         diff: Diff(changes: changes, appended: [], truncated: 0))
    }

    public static func writeInPlace(
        source path: String, sheet: XLSXReader.Sheet, diff: Diff
    ) throws {
        guard !diff.changes.isEmpty || !diff.appended.isEmpty || diff.truncated > 0 else { return }
        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }

        try write(source: path, sheet: sheet, diff: diff, to: temporary)
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }

    /// Chèn hoặc xoá hàng ở GIỮA bảng, dịch lại mọi tham chiếu A1 — rồi ghi đè tệp gốc.
    ///
    /// Đi qua `XLSXRowEditor.checkSafe` TRƯỚC khi ghi một byte nào: gặp cấu trúc chưa dịch được
    /// thì từ chối cả lượt, chứ không ghi nửa vời rồi để lại một tệp mở được mà trỏ sai.
    public static func writeRowEditInPlace(
        source path: String, sheet: XLSXReader.Sheet,
        shift: A1Reference.Shift, insertedRows: [[String]]
    ) throws {
        guard !shift.isEmpty else { return }
        let archive = try ZipArchive(path: path)
        try XLSXRowEditor.checkSafe(archive: archive, sheet: sheet)

        guard let original = try archive.data(named: sheet.path) else { throw Failure.sheetMissing }
        let edited = try XLSXRowEditor.apply(shift, insertedRows: insertedRows, to: original)

        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try ZipWriter.rewrite(archive, replacing: [sheet.path: edited], to: temporary)

        // ĐỐI CHỨNG: mở lại và đòi đúng số hàng. Sai số hàng nghĩa là phép chèn/xoá đã lệch,
        // và lệch một hàng là đủ để mọi con số phía dưới nói sai.
        let again = try XLSXReader(path: temporary)
        guard let sameSheet = again.sheets.first(where: { $0.name == sheet.name }) else {
            throw Failure.verificationFailed("mất sheet «\(sheet.name)»")
        }
        let before = try XLSXReader(path: path).grid(of: sheet).rows.count
        let after = try again.grid(of: sameSheet).rows.count
        guard after == before + shift.delta else {
            throw Failure.verificationFailed(
                "sau khi sửa có \(after) hàng, mong \(before + shift.delta)")
        }

        // `replaceItemAt` giữ quyền, thẻ mở rộng và bản sao dự phòng của tệp cũ — hơn hẳn xoá
        // rồi đổi tên, vốn để lại một khoảnh khắc không có tệp nào.
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }

    /// Thêm hàng vào cuối `<sheetData>`, hoặc cắt bớt hàng cuối.
    static func applyRowCountChange(_ diff: Diff, to xml: [UInt8]) throws -> [UInt8] {
        var text = String(decoding: xml, as: UTF8.self)
        let rows = try rowRanges(in: text)
        let lastRow = rows.keys.max() ?? -1

        if diff.truncated > 0 {
            // Xoá từ CUỐI lên: xoá xuôi làm mọi phạm vi phía sau lệch.
            let doomed = ((lastRow - diff.truncated + 1) ... lastRow)
                .compactMap { rows[$0] }
                .sorted { $0.lowerBound > $1.lowerBound }
            for range in doomed { text.removeSubrange(range) }
        }

        if !diff.appended.isEmpty {
            guard let close = text.range(of: "</sheetData>") else {
                throw Failure.sheetMissing
            }
            var built = ""
            for (offset, row) in diff.appended.enumerated() {
                let number = lastRow - diff.truncated + 2 + offset
                built += "<row r=\"\(number)\">"
                for (column, value) in row.enumerated() where !value.isEmpty {
                    built += cellXML(
                        reference: cellReference(row: number - 1, column: column),
                        style: nil, value: value)
                }
                built += "</row>"
            }
            text.insert(contentsOf: built, at: close.lowerBound)
        }

        // `<dimension>` khai vùng dữ liệu của sheet. Excel tự sửa lại được, nhưng để nguyên một
        // vùng cũ nhỏ hơn thực tế làm vài công cụ khác chỉ đọc tới hàng cuối cũ.
        if let open = text.range(of: "<dimension ref=\""),
           let end = text.range(of: "\"", range: open.upperBound ..< text.endIndex) {
            let current = String(text[open.upperBound ..< end.lowerBound])
            if let colon = current.firstIndex(of: ":") {
                let start = String(current[current.startIndex ..< colon])
                let tail = String(current[current.index(after: colon)...])
                let letters = tail.prefix { $0.isLetter }
                let newLast = (try rowRanges(in: text).keys.max() ?? 0) + 1
                text.replaceSubrange(open.upperBound ..< end.lowerBound,
                                     with: "\(start):\(letters)\(newLast)")
            }
        }
        return Array(text.utf8)
    }

    // MARK: - Sửa trong XML

    /// Thay giá trị của những ô đã đổi, giữ nguyên mọi byte khác.
    static func apply(_ changes: [Change], toSheetXML xml: [UInt8]) throws -> [UInt8] {
        guard !changes.isEmpty else { return xml }
        var text = String(decoding: xml, as: UTF8.self)

        // Gom theo hàng rồi đi từ CUỐI lên ĐẦU. Sửa từ đầu xuống sẽ làm mọi offset phía sau
        // lệch đi sau mỗi lần thay — cái bẫy kinh điển của sửa văn bản theo vị trí.
        let byRow = Dictionary(grouping: changes, by: \.row)
        let rows = try rowRanges(in: text)

        for rowIndex in byRow.keys.sorted(by: >) {
            guard let range = rows[rowIndex] else {
                let first = byRow[rowIndex]!.first!
                throw Failure.cellNotFound(row: first.row, column: first.column)
            }
            var rowText = String(text[range])
            for change in byRow[rowIndex]!.sorted(by: { $0.column > $1.column }) {
                rowText = try replaceCell(
                    in: rowText, row: rowIndex, column: change.column, value: change.value)
            }
            text.replaceSubrange(range, with: rowText)
        }
        return Array(text.utf8)
    }

    /// Phạm vi văn bản của từng `<row>`, khoá theo chỉ số hàng 0-based.
    ///
    /// Dùng thuộc tính `r` của `<row>` chứ không đếm thứ tự xuất hiện: hàng trống hoàn toàn
    /// KHÔNG có mặt trong tệp, nên đếm thứ tự sẽ lệch ngay sau hàng trống đầu tiên — và ghi
    /// giá trị vào nhầm hàng là kiểu hỏng tệ nhất có thể của một bộ ghi.
    static func rowRanges(in text: String) throws -> [Int: Range<String.Index>] {
        var result: [Int: Range<String.Index>] = [:]
        var cursor = text.startIndex
        while let open = text.range(of: "<row", range: cursor ..< text.endIndex) {
            guard let headerEnd = text.range(of: ">", range: open.upperBound ..< text.endIndex)
            else { break }
            let header = String(text[open.upperBound ..< headerEnd.lowerBound])
            let selfClosing = header.hasSuffix("/")

            let end: String.Index
            if selfClosing {
                end = headerEnd.upperBound
            } else if let close = text.range(of: "</row>", range: headerEnd.upperBound ..< text.endIndex) {
                end = close.upperBound
            } else {
                break
            }
            if let number = attributeValue("r", in: header), let index = Int(number) {
                result[index - 1] = open.lowerBound ..< end
            }
            cursor = end
        }
        return result
    }

    /// Thay giá trị một ô trong văn bản của MỘT hàng.
    ///
    /// Ô vắng mặt thì CHÈN mới, đặt đúng chỗ theo thứ tự cột — Excel đòi ô trong một hàng sắp
    /// tăng dần theo tham chiếu, và một hàng sắp sai thứ tự làm Excel báo tệp hỏng.
    static func replaceCell(
        in rowText: String, row: Int, column: Int, value: String
    ) throws -> String {
        let reference = cellReference(row: row, column: column)
        var cursor = rowText.startIndex
        var insertAt: String.Index?

        while let open = rowText.range(of: "<c ", range: cursor ..< rowText.endIndex) {
            guard let headerEnd = rowText.range(of: ">", range: open.upperBound ..< rowText.endIndex)
            else { break }
            let header = String(rowText[open.upperBound ..< headerEnd.lowerBound])
            let selfClosing = header.hasSuffix("/")
            let end: String.Index
            if selfClosing {
                end = headerEnd.upperBound
            } else if let close = rowText.range(
                of: "</c>", range: headerEnd.upperBound ..< rowText.endIndex) {
                end = close.upperBound
            } else {
                break
            }

            let thisReference = attributeValue("r", in: header) ?? ""
            if thisReference == reference {
                var replaced = rowText
                replaced.replaceSubrange(
                    open.lowerBound ..< end,
                    with: cellXML(reference: reference,
                                  style: attributeValue("s", in: header),
                                  value: value))
                return replaced
            }
            // Ô đầu tiên có cột LỚN HƠN cột cần chèn là chỗ chèn đúng.
            if insertAt == nil,
               let other = XLSXReader.columnIndex(ofReference: thisReference), other > column {
                insertAt = open.lowerBound
            }
            cursor = end
        }

        // Không có ô ấy: chèn mới. Không tìm được chỗ nào thì đặt trước `</row>`.
        let position: String.Index
        if let insertAt {
            position = insertAt
        } else if let close = rowText.range(of: "</row>") {
            position = close.lowerBound
        } else {
            throw Failure.cellNotFound(row: row, column: column)
        }
        var inserted = rowText
        inserted.insert(
            contentsOf: cellXML(reference: reference, style: nil, value: value), at: position)
        return inserted
    }

    /// XML của một ô mang giá trị mới.
    ///
    /// **Chữ luôn ghi thành chuỗi NỘI TUYẾN (`t="inlineStr"`), không vào bảng chuỗi dùng chung.**
    /// Thêm vào `sharedStrings.xml` đòi sửa cả bộ đếm `count`/`uniqueCount` ở đó, và mọi chỉ số
    /// đang trỏ vào bảng ấy phải giữ nguyên nghĩa — một cách sai rất dễ mắc và rất khó thấy.
    /// Chuỗi nội tuyến hợp lệ với mọi phiên bản Excel và chỉ đụng đúng một ô.
    ///
    /// **Giữ nguyên `s` (chỉ số định dạng) của ô cũ.** Bỏ nó đi thì một ô ngày đang hiện
    /// `15/01/2025` sẽ thành `45672` sau khi sửa ô bên cạnh.
    static func cellXML(reference: String, style: String?, value: String) -> String {
        let styleAttribute = style.map { " s=\"\($0)\"" } ?? ""
        // Số thì ghi thành số — giữ được phép tính, sắp xếp, và định dạng của Excel.
        if !value.isEmpty, let _ = Double(value), looksNumeric(value) {
            return "<c r=\"\(reference)\"\(styleAttribute)><v>\(value)</v></c>"
        }
        if value.isEmpty {
            return "<c r=\"\(reference)\"\(styleAttribute)/>"
        }
        return "<c r=\"\(reference)\"\(styleAttribute) t=\"inlineStr\"><is><t xml:space=\"preserve\">"
            + escapeXML(value) + "</t></is></c>"
    }

    /// Chuỗi này có phải SỐ theo nghĩa của bảng tính không.
    ///
    /// `Double("1e5")` và `Double("Infinity")` đều thành công, nhưng ghi chúng vào ô số sẽ cho
    /// ra thứ người dùng không gõ. Và `"0123"` là mã, không phải số — ghi thành số thì mất số 0
    /// đứng đầu, đúng cái bẫy đã gặp với `SOBAODANH`.
    static func looksNumeric(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        var body = Substring(value)
        if body.first == "-" || body.first == "+" { body = body.dropFirst() }
        guard let first = body.first, first.isNumber else { return false }
        if body.count > 1, first == "0", body.dropFirst().first != "." { return false }
        return body.allSatisfy { $0.isNumber || $0 == "." }
            && body.filter { $0 == "." }.count <= 1
    }

    /// `(0, 0)` → `"A1"`.
    static func cellReference(row: Int, column: Int) -> String {
        var letters = ""
        var value = column + 1
        while value > 0 {
            let remainder = (value - 1) % 26
            letters = String(UnicodeScalar(UInt8(65 + remainder))) + letters
            value = (value - 1) / 26
        }
        return letters + String(row + 1)
    }

    static func escapeXML(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(character)
            }
        }
        return out
    }

    /// Giá trị một thuộc tính trong chuỗi thẻ mở.
    static func attributeValue(_ name: String, in header: String) -> String? {
        guard let start = header.range(of: "\(name)=\"") else { return nil }
        guard let end = header.range(of: "\"", range: start.upperBound ..< header.endIndex)
        else { return nil }
        return String(header[start.upperBound ..< end.lowerBound])
    }
}
