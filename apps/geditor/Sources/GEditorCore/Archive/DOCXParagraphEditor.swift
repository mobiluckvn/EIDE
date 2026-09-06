import Foundation

/// Thêm và xoá ĐOẠN trong tệp `.docx`.
///
/// Bổ sung cho `DOCXWriter`, vốn chỉ sửa chữ trong những đoạn đã có. Tách thành lớp riêng vì
/// nó trả lời một câu hỏi khác hẳn — không phải "chữ mới là gì" mà "đoạn mới trông như thế
/// nào" — và câu hỏi ấy không có sẵn câu trả lời trong dữ liệu.
///
/// **Đoạn mới THỪA KẾ `<w:pPr>` của đoạn hàng xóm.** Đó là điều người dùng mong đợi khi gõ
/// Enter ở cuối một đoạn trong Word: đoạn mới cùng kiểu, cùng canh lề, cùng số hiệu danh sách.
/// Nó cũng làm cho việc thêm một mục vào danh sách chạy đúng mà không cần hiểu gì về đánh số.
///
/// **Và đây là chỗ lớp này TỪ CHỐI.** Nếu dòng mới mang tiền tố Markdown KHÁC với tiền tố của
/// hàng xóm — gõ `## Tiêu đề` giữa hai đoạn thường — thì người dùng đang xin một KIỂU khác, và
/// kiểu ấy phải tồn tại trong `styles.xml` của chính tài liệu đó với đúng tên mà Word đặt cho
/// nó (đã bản địa hoá). Dựng bừa một đoạn thường rồi để nguyên dấu `##` trong chữ là im lặng
/// làm sai ý người dùng — nên nó nói ra thay vì đoán.
public enum DOCXParagraphEditor {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case newParagraphNeedsStyle(line: Int, prefix: String)
        case cannotDeleteTableRow(line: Int)
        case noNeighbour
        case mixedEdit

        public var description: String {
            switch self {
            case .newParagraphNeedsStyle(let line, let prefix):
                return "Dòng \(line + 1) bắt đầu bằng «\(prefix)» — đó là một KIỂU khác với đoạn"
                    + " bên cạnh, và bộ ghi này chưa dựng được kiểu mới. Hãy gõ dòng ấy như văn"
                    + " bản thường, hoặc dùng «Lưu thành…»"
            case .cannotDeleteTableRow(let line):
                return "Dòng \(line + 1) là một hàng bảng — xoá hàng bảng chưa ghi ngược được"
            case .noNeighbour:
                return "Không tìm được đoạn bên cạnh để đoạn mới thừa kế kiểu"
            case .mixedEdit:
                return "Vừa thêm vừa xoá dòng trong cùng một lượt — hãy lưu từng bước một"
            }
        }
    }

    /// Một phép sửa số dòng: xoá `deletedParagraphs`, rồi chèn `insertedTexts` sau
    /// `anchorParagraph`.
    public struct Plan: Equatable, Sendable {
        public var deletedParagraphs: [Int]
        public var insertedTexts: [String]
        /// Đoạn mà những đoạn mới sẽ đứng NGAY SAU, và thừa kế `<w:pPr>` của nó.
        public var anchorParagraph: Int?

        public var isEmpty: Bool { deletedParagraphs.isEmpty && insertedTexts.isEmpty }
    }

    // MARK: - Suy ra phép sửa

    /// So bản Markdown gốc với bản đang sửa, suy ra phép thêm/xoá đoạn.
    ///
    /// Cắt phần đầu và phần đuôi giống nhau trước — cùng lối `XLSXRowEditor.plan`. Phần còn lại
    /// ở giữa là "xoá những đoạn cũ ở đó, chèn những dòng mới vào đó".
    public static func plan(
        from original: DOCXReader.Document, to edited: String
    ) throws -> Plan {
        let before = original.markdown.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")

        var head = 0
        while head < before.count, head < after.count, before[head] == after[head] { head += 1 }
        var tail = 0
        while tail < before.count - head, tail < after.count - head,
              before[before.count - 1 - tail] == after[after.count - 1 - tail] { tail += 1 }

        let oldRange = head ..< (before.count - tail)
        let newRange = head ..< (after.count - tail)

        // Đoạn bị xoá: mọi dòng trong vùng cũ CÓ chủ. Dòng trắng không có chủ nên bỏ qua —
        // chúng do bộ đọc sinh ra, không ứng với `<w:p>` nào.
        var deleted: [Int] = []
        for index in oldRange {
            guard index < original.lineOwners.count else { continue }
            let owner = original.lineOwners[index]
            if owner.cells != nil { throw Failure.cannotDeleteTableRow(line: index) }
            if let paragraph = owner.paragraph { deleted.append(paragraph) }
        }

        // Dòng thêm vào: mọi dòng KHÔNG rỗng trong vùng mới.
        let inserted = newRange.compactMap { index -> (Int, String)? in
            let line = after[index]
            return line.trimmingCharacters(in: .whitespaces).isEmpty ? nil : (index, line)
        }

        guard !(deleted.isEmpty && inserted.isEmpty) else { return Plan(
            deletedParagraphs: [], insertedTexts: [], anchorParagraph: nil) }

        // Vừa thêm vừa xoá trong một lượt: từ chối. Diễn giải nó thành "xoá rồi chèn" cũng
        // chạy được, nhưng nó vứt mất `<w:pPr>` của những đoạn bị xoá và dựng lại chúng bằng
        // kiểu của hàng xóm — tức âm thầm đổi định dạng những đoạn người dùng chỉ SỬA CHỮ.
        guard deleted.isEmpty || inserted.isEmpty else { throw Failure.mixedEdit }

        guard !inserted.isEmpty else {
            return Plan(deletedParagraphs: deleted, insertedTexts: [], anchorParagraph: nil)
        }

        // Đoạn hàng xóm: đoạn có chủ gần nhất TRƯỚC vùng chèn.
        var anchor: Int?
        var anchorPrefix = ""
        var probe = head - 1
        while probe >= 0, probe < original.lineOwners.count {
            let owner = original.lineOwners[probe]
            if let paragraph = owner.paragraph {
                anchor = paragraph
                anchorPrefix = String(before[probe].prefix(owner.prefixLength))
                break
            }
            probe -= 1
        }
        guard let anchor else { throw Failure.noNeighbour }

        // Tiền tố của dòng mới phải KHỚP tiền tố của hàng xóm.
        var texts: [String] = []
        for (index, line) in inserted {
            guard line.hasPrefix(anchorPrefix) else {
                throw Failure.newParagraphNeedsStyle(
                    line: index, prefix: String(line.prefix(4)))
            }
            let body = String(line.dropFirst(anchorPrefix.count))
            // Còn tiền tố Markdown nào sót lại nghĩa là người dùng xin một kiểu khác.
            if anchorPrefix.isEmpty, Self.markdownPrefixLength(body) > 0 {
                throw Failure.newParagraphNeedsStyle(
                    line: index, prefix: String(body.prefix(Self.markdownPrefixLength(body))))
            }
            texts.append(body)
        }
        return Plan(deletedParagraphs: deleted, insertedTexts: texts, anchorParagraph: anchor)
    }

    /// Độ dài tiền tố Markdown ở đầu một dòng (`"## "`, `"- "`, `"1. "`, `"> "`), hoặc 0.
    static func markdownPrefixLength(_ line: String) -> Int {
        var index = line.startIndex
        var hashes = 0
        while index < line.endIndex, line[index] == "#" {
            hashes += 1
            index = line.index(after: index)
        }
        if hashes > 0, index < line.endIndex, line[index] == " " { return hashes + 1 }
        if line.hasPrefix("- ") || line.hasPrefix("> ") { return 2 }
        if line.hasPrefix("1. ") { return 3 }
        return 0
    }

    // MARK: - Áp vào XML

    public static func apply(_ plan: Plan, to xml: [UInt8]) throws -> [UInt8] {
        guard !plan.isEmpty else { return xml }
        var text = String(decoding: xml, as: UTF8.self)

        if !plan.insertedTexts.isEmpty {
            guard let anchor = plan.anchorParagraph else { throw Failure.noNeighbour }
            let ranges = DOCXWriter.paragraphRanges(in: text)
            guard anchor < ranges.count else { throw Failure.noNeighbour }
            let anchorText = String(text[ranges[anchor]])
            let properties = paragraphProperties(of: anchorText)

            var built = ""
            for body in plan.insertedTexts {
                built += "<w:p>" + properties
                    + "<w:r><w:t xml:space=\"preserve\">"
                    + DOCXWriter.escapeXML(body) + "</w:t></w:r></w:p>"
            }
            text.insert(contentsOf: built, at: ranges[anchor].upperBound)
        }

        if !plan.deletedParagraphs.isEmpty {
            // Xoá từ CUỐI lên ĐẦU — cùng cái bẫy với mọi phép sửa theo vị trí khác.
            let ranges = DOCXWriter.paragraphRanges(in: text)
            for index in plan.deletedParagraphs.sorted(by: >) where index < ranges.count {
                text.removeSubrange(ranges[index])
            }
        }
        return Array(text.utf8)
    }

    /// `<w:pPr>…</w:pPr>` của một đoạn, hoặc chuỗi rỗng.
    static func paragraphProperties(of paragraph: String) -> String {
        guard let open = paragraph.range(of: "<w:pPr") else { return "" }
        guard let headerEnd = paragraph.range(
            of: ">", range: open.upperBound ..< paragraph.endIndex) else { return "" }
        if paragraph[open.upperBound ..< headerEnd.lowerBound].hasSuffix("/") {
            return String(paragraph[open.lowerBound ..< headerEnd.upperBound])
        }
        guard let close = paragraph.range(
            of: "</w:pPr>", range: headerEnd.upperBound ..< paragraph.endIndex) else { return "" }
        return String(paragraph[open.lowerBound ..< close.upperBound])
    }

    // MARK: - Ghi

    public static func writeInPlace(source path: String, plan: Plan) throws {
        guard !plan.isEmpty else { return }
        let archive = try ZipArchive(path: path)
        guard let original = try archive.data(named: "word/document.xml") else {
            throw DOCXWriter.Failure.noBody
        }
        let edited = try apply(plan, to: original)

        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try ZipWriter.rewrite(archive, replacing: ["word/document.xml": edited], to: temporary)

        // ĐỐI CHỨNG: mở lại và đòi số đoạn khớp với phép sửa vừa làm.
        let before = try DOCXReader.read(path: path).paragraphCount
        let again = try DOCXReader.read(path: temporary)
        let expected = before - plan.deletedParagraphs.count + plan.insertedTexts.count
        guard again.paragraphCount == expected else {
            throw DOCXWriter.Failure.verificationFailed(
                "sau khi sửa có \(again.paragraphCount) đoạn, mong \(expected)")
        }
        for body in plan.insertedTexts where !body.isEmpty {
            guard again.markdown.contains(body) else {
                throw DOCXWriter.Failure.verificationFailed("không thấy «\(body.prefix(40))»")
            }
        }
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }
}
