import Foundation

/// Thêm và xoá dòng chữ trong slide `.pptx`.
///
/// Cùng khuôn với `DOCXParagraphEditor`: đoạn mới thừa kế `<a:pPr>` **và cả `<a:rPr>` của run
/// đầu** ở đoạn hàng xóm. Vế thứ hai là khác biệt so với Word và nó bắt buộc: trong PowerPoint,
/// cỡ chữ và màu chữ nằm ở `<a:rPr>` của từng run chứ không ở kiểu đoạn. Dựng một đoạn mới
/// không có `<a:rPr>` cho ra một dòng chữ đen cỡ mặc định giữa một slide đã trình bày kỹ.
///
/// **Chỉ thêm/xoá được dòng NỘI DUNG của slide.** Dòng tiêu đề `## N. …` mà bộ đọc sinh ra là
/// mốc phân slide, không phải chữ; thêm/xoá nó nghĩa là thêm/xoá cả một SLIDE — việc ấy phải
/// dựng thêm tệp XML, quan hệ, và mục trong danh sách slide, nên nó bị từ chối kèm lý do.
public enum PPTXParagraphEditor {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case slideBoundary(line: Int)
        case noNeighbour
        case mixedEdit
        case verificationFailed(String)

        public var description: String {
            switch self {
            case .slideBoundary(let line):
                return "Dòng \(line + 1) là mốc phân slide — thêm hoặc xoá cả một slide chưa ghi"
                    + " ngược được, hãy dùng «Lưu thành…»"
            case .noNeighbour:
                return "Không tìm được dòng bên cạnh để dòng mới thừa kế kiểu"
            case .mixedEdit:
                return "Vừa thêm vừa xoá dòng trong cùng một lượt — hãy lưu từng bước một"
            case .verificationFailed(let detail):
                return "Tệp vừa ghi đọc lại KHÔNG khớp: \(detail)"
            }
        }
    }

    public struct Plan: Equatable, Sendable {
        /// Tệp slide bị đụng tới. Một lượt chỉ sửa MỘT slide — thêm dòng vào hai slide cùng lúc
        /// không phải thao tác người dùng làm được bằng một lần gõ.
        public var file: String
        public var deletedParagraphs: [Int]
        public var insertedTexts: [String]
        public var anchorParagraph: Int?

        public var isEmpty: Bool { deletedParagraphs.isEmpty && insertedTexts.isEmpty }
    }

    // MARK: - Suy ra phép sửa

    public static func plan(
        from original: PPTXReader.Presentation, to edited: String
    ) throws -> Plan? {
        let before = original.markdown.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")
        guard before.count != after.count else { return nil }

        var head = 0
        while head < before.count, head < after.count, before[head] == after[head] { head += 1 }
        var tail = 0
        while tail < before.count - head, tail < after.count - head,
              before[before.count - 1 - tail] == after[after.count - 1 - tail] { tail += 1 }

        let oldRange = head ..< (before.count - tail)
        let newRange = head ..< (after.count - tail)

        var deleted: [Int] = []
        var file: String?
        for index in oldRange {
            guard index < original.lineOwners.count else { continue }
            let owner = original.lineOwners[index]
            // Dòng tiêu đề slide: bộ đọc gán `file` cho nó, nên phải phân biệt bằng TIỀN TỐ.
            if before[index].hasPrefix("## ") { throw Failure.slideBoundary(line: index) }
            guard let paragraph = owner.paragraph, let owned = owner.file else { continue }
            deleted.append(paragraph)
            file = owned
        }

        let inserted = newRange.compactMap { index -> (Int, String)? in
            let line = after[index]
            if line.hasPrefix("## ") { return nil }
            return line.trimmingCharacters(in: .whitespaces).isEmpty ? nil : (index, line)
        }
        guard !(deleted.isEmpty && inserted.isEmpty) else { return nil }
        guard deleted.isEmpty || inserted.isEmpty else { throw Failure.mixedEdit }

        guard !inserted.isEmpty else {
            guard let file else { throw Failure.noNeighbour }
            return Plan(file: file, deletedParagraphs: deleted,
                        insertedTexts: [], anchorParagraph: nil)
        }

        // Hàng xóm: dòng có chủ gần nhất TRƯỚC vùng chèn, trong cùng slide.
        var anchor: Int?
        var anchorPrefix = ""
        var probe = head - 1
        while probe >= 0, probe < original.lineOwners.count {
            let owner = original.lineOwners[probe]
            if let paragraph = owner.paragraph, let owned = owner.file {
                anchor = paragraph
                file = owned
                anchorPrefix = String(before[probe].prefix(owner.prefixLength))
                break
            }
            probe -= 1
        }
        guard let anchor, let file else { throw Failure.noNeighbour }

        var texts: [String] = []
        for (_, line) in inserted {
            let body = line.hasPrefix(anchorPrefix)
                ? String(line.dropFirst(anchorPrefix.count))
                : line
            texts.append(body)
        }
        return Plan(file: file, deletedParagraphs: deleted,
                    insertedTexts: texts, anchorParagraph: anchor)
    }

    // MARK: - Áp vào XML

    public static func apply(_ plan: Plan, to xml: [UInt8]) throws -> [UInt8] {
        guard !plan.isEmpty else { return xml }
        var text = String(decoding: xml, as: UTF8.self)

        if !plan.insertedTexts.isEmpty {
            guard let anchor = plan.anchorParagraph else { throw Failure.noNeighbour }
            let ranges = PPTXWriter.paragraphRanges(in: text)
            guard anchor < ranges.count else { throw Failure.noNeighbour }
            let anchorText = String(text[ranges[anchor]])

            var built = ""
            for body in plan.insertedTexts {
                built += "<a:p>" + properties(of: anchorText)
                    + "<a:r>" + runProperties(of: anchorText)
                    + "<a:t>" + DOCXWriter.escapeXML(body) + "</a:t></a:r></a:p>"
            }
            text.insert(contentsOf: built, at: ranges[anchor].upperBound)
        }

        if !plan.deletedParagraphs.isEmpty {
            let ranges = PPTXWriter.paragraphRanges(in: text)
            for index in plan.deletedParagraphs.sorted(by: >) where index < ranges.count {
                text.removeSubrange(ranges[index])
            }
        }
        return Array(text.utf8)
    }

    static func properties(of paragraph: String) -> String {
        element("a:pPr", in: paragraph)
    }

    /// `<a:rPr>` của run ĐẦU TIÊN — nơi PowerPoint giữ cỡ chữ và màu chữ.
    static func runProperties(of paragraph: String) -> String {
        element("a:rPr", in: paragraph)
    }

    private static func element(_ name: String, in text: String) -> String {
        guard let open = text.range(of: "<\(name)") else { return "" }
        guard let headerEnd = text.range(of: ">", range: open.upperBound ..< text.endIndex)
        else { return "" }
        if text[open.upperBound ..< headerEnd.lowerBound].hasSuffix("/") {
            return String(text[open.lowerBound ..< headerEnd.upperBound])
        }
        guard let close = text.range(
            of: "</\(name)>", range: headerEnd.upperBound ..< text.endIndex) else { return "" }
        return String(text[open.lowerBound ..< close.upperBound])
    }

    // MARK: - Ghi

    public static func writeInPlace(source path: String, plan: Plan) throws {
        guard !plan.isEmpty else { return }
        let archive = try ZipArchive(path: path)
        guard let original = try archive.data(named: plan.file) else {
            throw Failure.verificationFailed("không có \(plan.file)")
        }
        let edited = try apply(plan, to: original)

        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try ZipWriter.rewrite(archive, replacing: [plan.file: edited], to: temporary)

        let again = try PPTXReader.read(path: temporary)
        for body in plan.insertedTexts where !body.isEmpty {
            guard again.markdown.contains(body) else {
                throw Failure.verificationFailed("không thấy «\(body.prefix(40))»")
            }
        }
        // Số slide phải KHÔNG đổi: lớp này chỉ sửa chữ trong slide, không thêm bớt slide nào.
        let before = try PPTXReader.read(path: path).slides.count
        guard again.slides.count == before else {
            throw Failure.verificationFailed(
                "số slide đổi từ \(before) thành \(again.slides.count)")
        }
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }
}
