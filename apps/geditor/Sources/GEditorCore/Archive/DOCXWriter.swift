import Foundation

/// Ghi chữ đã sửa ngược vào tệp `.docx`, **không đụng tới phần còn lại**.
///
/// Cùng nguyên tắc với `XLSXWriter`: sửa đúng chỗ trong `word/document.xml`, chép nguyên byte
/// mọi phần khác. Nhưng Word khó hơn Excel một bậc, và chỗ khó nằm ở chính đơn vị chữ.
///
/// **Một đoạn Word gồm nhiều `<w:r>` mang định dạng khác nhau.** Câu *"tổng **137** tính năng"*
/// là ba run: chữ thường, chữ đậm, chữ thường. Khi người dùng sửa cả đoạn thành một câu khác,
/// không có cách nào biết phần nào của câu MỚI đáng in đậm — thông tin ấy không tồn tại.
///
/// Nên luật ở đây nói thẳng: **chữ mới vào run ĐẦU TIÊN, các run còn lại bị làm rỗng.** Giữ
/// được: thuộc tính đoạn (`<w:pPr>` — kiểu, canh lề, số hiệu danh sách) và định dạng của run
/// đầu. Mất: định dạng khác nhau GIỮA các run trong đoạn ấy. Đó là cái giá thật của việc sửa
/// chữ trong Word bằng một trình soạn thảo văn bản thuần, và nó phải được nói ra chứ không
/// giấu — người dùng sửa một đoạn có chữ đậm ở giữa sẽ thấy chữ đậm biến mất.
///
/// Đoạn KHÔNG bị sửa thì không bị đụng tới một byte nào, kể cả định dạng phức tạp nhất.
public enum DOCXWriter {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case lineCountChanged(was: Int, now: Int)
        case notAParagraph(line: Int)
        case tableShapeChanged(line: Int)
        case paragraphNotFound(Int)
        case noBody
        case verificationFailed(String)

        public var description: String {
            switch self {
            case .lineCountChanged(let was, let now):
                return "Số dòng đã đổi từ \(was) thành \(now) — thêm/xoá dòng chưa ghi ngược"
                    + " được, hãy dùng «Lưu thành…»"
            case .notAParagraph(let line):
                return "Dòng \(line + 1) không phải một đoạn của tài liệu — chưa sửa ngược được"
            case .tableShapeChanged(let line):
                return "Số ô của hàng bảng ở dòng \(line + 1) đã đổi — thêm/xoá cột chưa ghi"
                    + " ngược được"
            case .paragraphNotFound(let index):
                return "Không tìm thấy đoạn thứ \(index + 1) trong tệp gốc"
            case .noBody:
                return "Tệp không có phần thân tài liệu"
            case .verificationFailed(let detail):
                return "Tệp vừa ghi đọc lại KHÔNG khớp: \(detail)"
            }
        }
    }

    public struct Change: Equatable, Sendable {
        public var paragraph: Int
        public var text: String
    }

    /// So bản Markdown gốc với bản đang sửa, trả về những ĐOẠN đã đổi.
    ///
    /// Đòi **cùng số dòng**. Đây là giới hạn thật và cố ý: thêm hay bớt một dòng nghĩa là thêm
    /// hay bớt một `<w:p>`, và chèn một đoạn mới đúng chỗ kèm thuộc tính hợp lý là một bài
    /// khác. Từ chối kèm lý do rõ ràng tốt hơn nhiều so với ghi một tệp thiếu đoạn.
    public static func changes(
        from original: DOCXReader.Document, to edited: String
    ) throws -> [Change] {
        let before = original.markdown.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")
        guard before.count == after.count else {
            throw Failure.lineCountChanged(was: before.count, now: after.count)
        }

        var result: [Change] = []
        for index in before.indices where before[index] != after[index] {
            guard index < original.lineOwners.count else {
                throw Failure.notAParagraph(line: index)
            }
            let owner = original.lineOwners[index]

            // Hàng bảng: so từng Ô, và chỉ ghi những ô thật sự đổi. Ghi cả hàng thì mọi ô đều
            // bị dựng lại và mất định dạng dù người dùng chỉ sửa một ô.
            if let cells = owner.cells {
                let oldCells = tableCells(before[index])
                let newCells = tableCells(after[index])
                guard oldCells.count == newCells.count else {
                    throw Failure.tableShapeChanged(line: index)
                }
                for column in oldCells.indices where oldCells[column] != newCells[column] {
                    guard column < cells.count else { throw Failure.tableShapeChanged(line: index) }
                    result.append(Change(paragraph: cells[column], text: newCells[column]))
                }
                continue
            }

            guard let paragraph = owner.paragraph else {
                throw Failure.notAParagraph(line: index)
            }
            // Bỏ đúng tiền tố Markdown mà bộ đọc đã thêm vào, không đoán lại bằng chuỗi: một
            // đoạn thường bắt đầu bằng "- " là chuyện có thật, và cắt nhầm sẽ mất hai ký tự đầu.
            let line = after[index]
            let text = String(line.dropFirst(min(owner.prefixLength, line.count)))
            result.append(Change(paragraph: paragraph, text: text))
        }
        return result
    }

    /// Tách một hàng bảng Markdown `| a | b |` thành từng ô.
    ///
    /// Tách trên dấu `|` KHÔNG bị thoát: bộ đọc ghi `\|` cho ô có chứa dấu ống, và tách bừa
    /// sẽ cắt một ô thành hai rồi làm lệch mọi cột phía sau.
    static func tableCells(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var escaped = false
        // Bỏ dấu `|` mở đầu và kết thúc — chúng là khung, không phải ranh giới ô.
        var body = Substring(line)
        if body.hasPrefix("|") { body = body.dropFirst() }
        if body.hasSuffix("|") { body = body.dropLast() }

        for character in body {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    /// Áp thay đổi, ghi ra `destination`, rồi ĐỌC LẠI để đối chứng.
    public static func write(
        source path: String, changes: [Change], to destination: String
    ) throws {
        let archive = try ZipArchive(path: path)
        guard let original = try archive.data(named: "word/document.xml") else {
            throw Failure.noBody
        }
        let edited = try apply(changes, toDocumentXML: original)
        try ZipWriter.rewrite(archive, replacing: ["word/document.xml": edited], to: destination)

        let again = try DOCXReader.read(path: destination)
        for change in changes {
            // So theo NỘI DUNG chứ không theo dòng: một đoạn dài có thể đổi cách xuống dòng.
            // Chuỗi rỗng thì không tìm được, và cũng không cần tìm.
            guard !change.text.isEmpty else { continue }
            guard again.markdown.contains(change.text) else {
                throw Failure.verificationFailed("không thấy «\(change.text.prefix(40))»")
            }
        }
    }

    /// Ghi đè chính tệp gốc — chỉ sau khi bản mới đã đọc lại đúng. Xem `XLSXWriter.writeInPlace`.
    public static func writeInPlace(source path: String, changes: [Change]) throws {
        guard !changes.isEmpty else { return }
        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try write(source: path, changes: changes, to: temporary)
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }

    // MARK: - Sửa trong XML

    static func apply(_ changes: [Change], toDocumentXML xml: [UInt8]) throws -> [UInt8] {
        guard !changes.isEmpty else { return xml }
        var text = String(decoding: xml, as: UTF8.self)
        let paragraphs = paragraphRanges(in: text)

        // Từ CUỐI lên ĐẦU: sửa xuôi làm mọi vị trí phía sau lệch đi. Cùng cái bẫy với
        // `XLSXWriter.apply`.
        for change in changes.sorted(by: { $0.paragraph > $1.paragraph }) {
            guard change.paragraph < paragraphs.count else {
                throw Failure.paragraphNotFound(change.paragraph)
            }
            let range = paragraphs[change.paragraph]
            let replaced = try replaceText(in: String(text[range]), with: change.text)
            text.replaceSubrange(range, with: replaced)
        }
        return Array(text.utf8)
    }

    /// Phạm vi từng `<w:p …>…</w:p>` theo thứ tự xuất hiện.
    ///
    /// Đếm theo thứ tự là ĐÚNG ở đây, khác với `<row>` của Excel: Word không có đoạn nào bị
    /// lược bỏ khỏi tệp, và cũng không có thuộc tính số thứ tự để mà đọc.
    static func paragraphRanges(in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = text.startIndex
        while let open = find(text, "<w:p", from: cursor) {
            // `<w:pPr>`, `<w:pStyle>` cũng bắt đầu bằng `<w:p` — chỉ nhận khi ký tự kế tiếp
            // kết thúc tên thẻ. Thiếu vế này thì mọi thuộc tính đoạn bị đếm thành đoạn.
            let after = text.index(open.lowerBound, offsetBy: 4)
            let next = after < text.endIndex ? text[after] : " "
            guard next == " " || next == ">" || next == "/" else {
                cursor = after
                continue
            }
            guard let headerEnd = find(text, ">", from: open.upperBound) else { break }
            let header = String(text[open.upperBound ..< headerEnd.lowerBound])
            if header.hasSuffix("/") {
                // `<w:p/>` — đoạn rỗng, vẫn tính là một đoạn.
                result.append(open.lowerBound ..< headerEnd.upperBound)
                cursor = headerEnd.upperBound
                continue
            }
            guard let close = find(text, "</w:p>", from: headerEnd.upperBound) else { break }
            result.append(open.lowerBound ..< close.upperBound)
            cursor = close.upperBound
        }
        return result
    }

    /// Đặt chữ mới vào run ĐẦU TIÊN của đoạn, làm rỗng các run còn lại.
    static func replaceText(in paragraph: String, with text: String) throws -> String {
        var out = paragraph
        var replacedFirst = false
        var cursor = out.startIndex
        var ranges: [Range<String.Index>] = []

        // Gom trước mọi `<w:t …>…</w:t>`, rồi sửa từ CUỐI — sửa tại chỗ trong khi đang duyệt
        // sẽ làm chỉ số phía sau vô hiệu.
        while let open = find(out, "<w:t", from: cursor) {
            guard let headerEnd = find(out, ">", from: open.upperBound) else { break }
            if out[out.index(before: headerEnd.upperBound)] == ">",
               out[open.upperBound ..< headerEnd.lowerBound].hasSuffix("/") {
                cursor = headerEnd.upperBound
                continue
            }
            guard let close = find(out, "</w:t>", from: headerEnd.upperBound) else { break }
            ranges.append(headerEnd.upperBound ..< close.lowerBound)
            cursor = close.upperBound
        }

        guard !ranges.isEmpty else {
            // Đoạn không có run nào (đoạn rỗng): dựng một run tối thiểu trước `</w:p>`.
            guard let close = find(out, "</w:p>") else { throw Failure.noBody }
            out.insert(contentsOf: "<w:r><w:t xml:space=\"preserve\">"
                + escapeXML(text) + "</w:t></w:r>", at: close.lowerBound)
            return out
        }

        for range in ranges.reversed() {
            let isFirst = range.lowerBound == ranges[0].lowerBound
            out.replaceSubrange(range, with: isFirst ? escapeXML(text) : "")
            if isFirst { replacedFirst = true }
        }
        _ = replacedFirst

        // `xml:space="preserve"` trên run đầu: thiếu nó thì Word cắt khoảng trắng đầu/cuối, và
        // một câu kết thúc bằng dấu cách sẽ dính vào câu sau.
        if let open = find(out, "<w:t"), let headerEnd = find(out, ">", from: open.upperBound) {
            let header = String(out[open.lowerBound ..< headerEnd.upperBound])
            if !header.contains("xml:space") {
                out.replaceSubrange(
                    open.lowerBound ..< headerEnd.upperBound,
                    with: "<w:t xml:space=\"preserve\">")
            }
        }
        return out
    }

    static func escapeXML(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(character)
            }
        }
        return out
    }

    private static func find(
        _ text: String, _ needle: String, from: String.Index? = nil
    ) -> Range<String.Index>? {
        text.range(of: needle, range: (from ?? text.startIndex) ..< text.endIndex)
    }
}
