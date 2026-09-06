import Foundation

/// Chèn và xoá hàng ở GIỮA một sheet `.xlsx`, dịch lại mọi tham chiếu A1 đi kèm.
///
/// **Cổng an toàn đứng TRƯỚC phép sửa, không sau.** Lớp này quét tệp tìm những chỗ mang tham
/// chiếu theo hàng; chỗ nào nó biết cách dịch thì dịch, chỗ nào KHÔNG biết thì **từ chối cả
/// lượt ghi** kèm tên chỗ ấy. Không có cổng này thì một cấu trúc chưa được xử lý sẽ lặng lẽ giữ
/// nguyên số hiệu cũ, và tệp hỏng theo cách tệ nhất: mở được, trông đúng, vài chỗ trỏ sai.
///
/// Đây là cùng một lối với `LazyLoadAudit` (ADR-14) — hỏi thẳng hiện trạng rồi đòi nó khớp danh
/// sách đã khai, thay vì tin rằng mình đã nghĩ tới hết.
public enum XLSXRowEditor {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case unsupportedConstruct(String)
        case definedNameOnSheet(String)
        case tablePart(String)
        case noSheetData

        public var description: String {
            switch self {
            case .unsupportedConstruct(let name):
                return "Sheet có «\(name)» — chèn/xoá hàng ở giữa sẽ làm nó trỏ sai, và bộ ghi"
                    + " này chưa dịch được nó. Hãy sửa bằng Excel, hoặc dùng «Lưu thành…»"
            case .definedNameOnSheet(let name):
                return "Bảng tính có tên đã đặt «\(name)» trỏ vào sheet này — chèn/xoá hàng sẽ"
                    + " làm nó trỏ sai. Chưa ghi ngược được"
            case .tablePart(let name):
                return "Sheet có bảng («\(name)») — vùng của nó nằm ở tệp khác và bộ ghi này"
                    + " chưa dịch được. Chưa ghi ngược được"
            case .noSheetData:
                return "Sheet không có phần dữ liệu"
            }
        }
    }

    /// Những thẻ mang tham chiếu theo hàng mà lớp này **biết** cách dịch.
    ///
    /// Danh sách này tự dọn theo hướng ngược lại với `POLLING_ALLOWED`: nó không liệt kê thứ
    /// được phép có, mà liệt kê thứ ta xử lý được. Mọi thứ khác trong `unsupported` bên dưới sẽ
    /// chặn lượt ghi.
    static let handled = [
        "row", "c", "f", "mergeCell", "hyperlink", "dataValidation",
        "conditionalFormatting", "autoFilter", "dimension", "sheetView", "pane", "selection",
    ]

    /// Những thẻ mang tham chiếu theo hàng mà lớp này CHƯA dịch được.
    ///
    /// Mỗi cái ở đây là một lời hứa chưa thực hiện, không phải một thứ bị quên: gặp là từ chối,
    /// và câu từ chối gọi đúng tên nó để người dùng biết vì sao.
    static let unsupported = [
        "sortState", "customSheetView", "dataRef", "sparkline", "protectedRange",
        "ignoredError", "phoneticPr", "cellWatch",
    ]

    /// Kiểm tệp có chèn/xoá hàng an toàn được không. Ném lỗi kèm tên chỗ vướng.
    public static func checkSafe(archive: ZipArchive, sheet: XLSXReader.Sheet) throws {
        guard let data = try archive.data(named: sheet.path) else { throw Failure.noSheetData }
        let xml = String(decoding: data, as: UTF8.self)

        for name in unsupported where xml.contains("<\(name)") || xml.contains(":\(name)") {
            throw Failure.unsupportedConstruct(name)
        }

        // Bảng (`<tableParts>`) trỏ sang một tệp khác mang vùng riêng của nó.
        if xml.contains("<tableParts") {
            throw Failure.tablePart((sheet.name))
        }

        // Tên đã đặt nằm ở `workbook.xml`, không ở sheet — nên phải mở riêng ra xem.
        if let workbook = try archive.data(named: "xl/workbook.xml") {
            let text = String(decoding: workbook, as: UTF8.self)
            if let start = text.range(of: "<definedNames") {
                let tail = text[start.lowerBound...]
                // Chỉ chặn khi tên ấy trỏ vào ĐÚNG sheet đang sửa: một tên trỏ sheet khác thì
                // chèn hàng ở đây không đụng tới nó.
                if tail.contains("'\(sheet.name)'!") || tail.contains("\(sheet.name)!") {
                    throw Failure.definedNameOnSheet(sheet.name)
                }
            }
        }
    }

    // MARK: - Áp phép sửa

    /// Áp một phép chèn/xoá hàng lên XML của sheet.
    public static func apply(
        _ shift: A1Reference.Shift, insertedRows: [[String]], to xml: [UInt8]
    ) throws -> [UInt8] {
        guard !shift.isEmpty else { return xml }
        var text = String(decoding: xml, as: UTF8.self)

        // 1. Xoá những `<row>` nằm trong vùng bị xoá, và dịch số hiệu của mọi hàng còn lại.
        text = try rewriteRows(text, shift: shift)

        // 2. Dịch tham chiếu ở những chỗ NGOÀI `<sheetData>`.
        for attribute in ["ref", "sqref"] {
            text = rewriteAttribute(attribute, in: text, shift: shift)
        }

        // 3. Chèn hàng mới.
        if !insertedRows.isEmpty {
            text = try insert(insertedRows, at: shift.at, into: text)
        }
        return Array(text.utf8)
    }

    /// Xoá hàng trong vùng bị xoá và đánh số lại phần còn lại — đi từ CUỐI lên ĐẦU.
    private static func rewriteRows(_ text: String, shift: A1Reference.Shift) throws -> String {
        var out = text
        let ranges = try XLSXWriter.rowRanges(in: out)
        guard !ranges.isEmpty else { return out }

        for index in ranges.keys.sorted(by: >) {
            guard let range = ranges[index] else { continue }
            let rowText = String(out[range])
            guard let number = shift.newRowNumber(for: index + 1) else {
                out.removeSubrange(range)          // hàng này bị xoá
                continue
            }
            guard number != index + 1 else { continue }
            out.replaceSubrange(range, with: renumber(rowText, to: number, shift: shift))
        }
        return out
    }

    /// Đổi số hiệu của một `<row>` và của mọi ô trong nó, và dịch công thức bên trong.
    static func renumber(_ rowText: String, to number: Int, shift: A1Reference.Shift) -> String {
        var out = rowText

        // `<row r="5"` → `<row r="7"`.
        if let open = out.range(of: "r=\""),
           let close = out.range(of: "\"", range: open.upperBound ..< out.endIndex) {
            out.replaceSubrange(open.upperBound ..< close.lowerBound, with: String(number))
        }

        // `<c r="A5"` → `<c r="A7"`, từ CUỐI lên để vị trí không lệch.
        var cellRanges: [Range<String.Index>] = []
        var cursor = out.startIndex
        while let open = out.range(of: "<c r=\"", range: cursor ..< out.endIndex) {
            guard let close = out.range(of: "\"", range: open.upperBound ..< out.endIndex)
            else { break }
            cellRanges.append(open.upperBound ..< close.lowerBound)
            cursor = close.upperBound
        }
        for range in cellRanges.reversed() {
            guard var cell = A1Reference.parseCell(String(out[range])) else { continue }
            cell.row = number
            out.replaceSubrange(range, with: A1Reference.render(cell))
        }

        // Công thức trong ô: `<f>A4+1</f>`.
        var formulaRanges: [Range<String.Index>] = []
        cursor = out.startIndex
        while let open = out.range(of: "<f", range: cursor ..< out.endIndex) {
            guard let headerEnd = out.range(of: ">", range: open.upperBound ..< out.endIndex)
            else { break }
            if out[open.upperBound ..< headerEnd.lowerBound].hasSuffix("/") {
                cursor = headerEnd.upperBound
                continue
            }
            guard let close = out.range(of: "</f>", range: headerEnd.upperBound ..< out.endIndex)
            else { break }
            formulaRanges.append(headerEnd.upperBound ..< close.lowerBound)
            cursor = close.upperBound
        }
        for range in formulaRanges.reversed() {
            let shifted = A1Reference.shiftFormula(String(out[range]), by: shift)
            out.replaceSubrange(range, with: shifted)
        }
        return out
    }

    /// Dịch mọi thuộc tính `ref=` / `sqref=` NGOÀI phần `<sheetData>`.
    ///
    /// Ngoài `sheetData` vì bên trong nó `ref` thuộc về công thức chia sẻ, và phần ấy đã được
    /// `renumber` lo — dịch hai lần là dịch gấp đôi.
    static func rewriteAttribute(
        _ name: String, in text: String, shift: A1Reference.Shift
    ) -> String {
        let dataStart = text.range(of: "<sheetData")
        let dataEnd = text.range(of: "</sheetData>")

        var out = text
        var found: [Range<String.Index>] = []
        var cursor = out.startIndex
        while let open = out.range(of: "\(name)=\"", range: cursor ..< out.endIndex) {
            guard let close = out.range(of: "\"", range: open.upperBound ..< out.endIndex)
            else { break }
            let inside = dataStart.map { open.lowerBound > $0.lowerBound } ?? false
                && (dataEnd.map { open.lowerBound < $0.lowerBound } ?? false)
            if !inside { found.append(open.upperBound ..< close.lowerBound) }
            cursor = close.upperBound
        }
        for range in found.reversed() {
            let value = String(out[range])
            // Bỏ qua thứ không phải tham chiếu ô (ví dụ `ref="rId1"`).
            guard value.first?.isLetter == true || value.first == "$" else { continue }
            out.replaceSubrange(range, with: A1Reference.shiftSqref(value, by: shift))
        }
        return out
    }

    /// Chèn các hàng mới vào đúng vị trí, giữ `<row>` trong `<sheetData>` sắp tăng dần.
    private static func insert(
        _ rows: [[String]], at index: Int, into text: String
    ) throws -> String {
        var out = text
        let ranges = try XLSXWriter.rowRanges(in: out)

        // Chèn TRƯỚC hàng đầu tiên có số hiệu lớn hơn; không có thì trước `</sheetData>`.
        let position: String.Index
        if let next = ranges.keys.filter({ $0 >= index }).min(), let range = ranges[next] {
            position = range.lowerBound
        } else if let close = out.range(of: "</sheetData>") {
            position = close.lowerBound
        } else {
            throw Failure.noSheetData
        }

        var built = ""
        for (offset, row) in rows.enumerated() {
            let number = index + offset + 1
            built += "<row r=\"\(number)\">"
            for (column, value) in row.enumerated() where !value.isEmpty {
                built += XLSXWriter.cellXML(
                    reference: XLSXWriter.cellReference(row: number - 1, column: column),
                    style: nil, value: value)
            }
            built += "</row>"
        }
        out.insert(contentsOf: built, at: position)
        return out
    }

    // MARK: - Suy ra phép sửa từ hai lưới

    /// So hai lưới rồi suy ra MỘT phép chèn/xoá ở giữa, cộng những ô đã đổi.
    ///
    /// **Cắt phần đầu và phần đuôi giống nhau trước.** Phần còn lại ở giữa được coi là "xoá
    /// từng ấy hàng cũ, chèn từng ấy hàng mới vào đúng chỗ" — cách diễn giải này đúng với mọi
    /// phép sửa thật (chèn một hàng, xoá một hàng, thay một khối), và nó cho ra một `Shift`
    /// DUY NHẤT nên phép dịch tham chiếu chỉ phải chạy một lượt.
    ///
    /// Cách khác — dò từng phép chèn/xoá rời rạc bằng LCS — cho ra nhiều `Shift` phải áp lần
    /// lượt, và mỗi lượt lại đổi toạ độ của lượt sau. Nhiều cơ hội sai hơn để đổi lấy một tệp
    /// gọn hơn vài chục byte.
    public static func plan(
        from old: [[String]], to new: [[String]]
    ) -> (shift: A1Reference.Shift, inserted: [[String]], changes: [XLSXWriter.Change]) {
        var head = 0
        while head < old.count, head < new.count, old[head] == new[head] { head += 1 }

        var tail = 0
        while tail < old.count - head, tail < new.count - head,
              old[old.count - 1 - tail] == new[new.count - 1 - tail] { tail += 1 }

        let oldMiddle = old.count - head - tail
        let newMiddle = new.count - head - tail

        // Cùng số hàng ở giữa: không chèn không xoá, chỉ là vài ô đổi.
        if oldMiddle == newMiddle {
            let changes = (try? XLSXWriter.diff(from: old, to: new).changes) ?? []
            return (A1Reference.Shift(at: 0, deleted: 0, inserted: 0), [], changes)
        }

        return (
            A1Reference.Shift(at: head, deleted: oldMiddle, inserted: newMiddle),
            Array(new[head ..< (head + newMiddle)]),
            []
        )
    }
}
