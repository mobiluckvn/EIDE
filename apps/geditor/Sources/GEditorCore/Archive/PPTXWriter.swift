import Foundation

/// Ghi chữ đã sửa ngược vào tệp `.pptx`.
///
/// Cùng khuôn với `DOCXWriter`, khác đúng một điểm và điểm ấy quan trọng: **PowerPoint để mỗi
/// slide trong một tệp XML riêng**, còn ghi chú người trình bày ở tệp thứ ba. Nên một lượt ghi
/// có thể phải thay NHIỀU mục trong file nén cùng lúc — và phải thay chúng trong CÙNG một lượt,
/// không phải mỗi tệp một lượt ghi. Ghi từng lượt thì một lỗi ở tệp thứ hai để lại một bản
/// trình chiếu đã sửa nửa vời.
public enum PPTXWriter {

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case lineCountChanged(was: Int, now: Int)
        case notEditable(line: Int)
        case paragraphNotFound(file: String, index: Int)
        case verificationFailed(String)

        public var description: String {
            switch self {
            case .lineCountChanged(let was, let now):
                return "Số dòng đã đổi từ \(was) thành \(now) — thêm/xoá dòng chưa ghi ngược"
                    + " được, hãy dùng «Lưu thành…»"
            case .notEditable(let line):
                return "Dòng \(line + 1) không phải chữ trong slide (tiêu đề do GEditor sinh"
                    + " hoặc dòng trắng) — chưa sửa ngược được"
            case .paragraphNotFound(let file, let index):
                return "Không tìm thấy đoạn thứ \(index + 1) trong \((file as NSString).lastPathComponent)"
            case .verificationFailed(let detail):
                return "Tệp vừa ghi đọc lại KHÔNG khớp: \(detail)"
            }
        }
    }

    public struct Change: Equatable, Sendable {
        public var file: String
        public var paragraph: Int
        public var text: String
    }

    public static func changes(
        from original: PPTXReader.Presentation, to edited: String
    ) throws -> [Change] {
        let before = original.markdown.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")
        guard before.count == after.count else {
            throw Failure.lineCountChanged(was: before.count, now: after.count)
        }

        var result: [Change] = []
        for index in before.indices where before[index] != after[index] {
            guard index < original.lineOwners.count else { throw Failure.notEditable(line: index) }
            let owner = original.lineOwners[index]
            guard let file = owner.file, let paragraph = owner.paragraph else {
                throw Failure.notEditable(line: index)
            }
            let line = after[index]
            result.append(Change(
                file: file, paragraph: paragraph,
                text: String(line.dropFirst(min(owner.prefixLength, line.count)))))
        }
        return result
    }

    public static func write(
        source path: String, changes: [Change], to destination: String
    ) throws {
        let archive = try ZipArchive(path: path)

        // Gom theo TỆP rồi thay tất cả trong MỘT lượt ghi.
        var replacements: [String: [UInt8]] = [:]
        for (file, group) in Dictionary(grouping: changes, by: \.file) {
            guard let original = try archive.data(named: file) else {
                throw Failure.paragraphNotFound(file: file, index: 0)
            }
            replacements[file] = try apply(group, toSlideXML: original, file: file)
        }
        try ZipWriter.rewrite(archive, replacing: replacements, to: destination)

        let again = try PPTXReader.read(path: destination)
        for change in changes where !change.text.isEmpty {
            guard again.markdown.contains(change.text) else {
                throw Failure.verificationFailed("không thấy «\(change.text.prefix(40))»")
            }
        }
    }

    public static func writeInPlace(source path: String, changes: [Change]) throws {
        guard !changes.isEmpty else { return }
        let temporary = path + ".geditor-\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try write(source: path, changes: changes, to: temporary)
        _ = try FileManager.default.replaceItemAt(
            URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: temporary))
    }

    // MARK: - Sửa trong XML

    static func apply(
        _ changes: [Change], toSlideXML xml: [UInt8], file: String
    ) throws -> [UInt8] {
        var text = String(decoding: xml, as: UTF8.self)
        let paragraphs = paragraphRanges(in: text)

        // Từ CUỐI lên ĐẦU — cùng lý do với `DOCXWriter.apply`.
        for change in changes.sorted(by: { $0.paragraph > $1.paragraph }) {
            guard change.paragraph < paragraphs.count else {
                throw Failure.paragraphNotFound(file: file, index: change.paragraph)
            }
            let range = paragraphs[change.paragraph]
            let replaced = replaceText(in: String(text[range]), with: change.text)
            text.replaceSubrange(range, with: replaced)
        }
        return Array(text.utf8)
    }

    /// Phạm vi từng `<a:p …>…</a:p>`.
    ///
    /// `<a:pPr>` cũng bắt đầu bằng `<a:p` — cùng cái bẫy đã gặp với `<w:pPr>` của Word, nên
    /// cùng cách chặn: đòi ký tự kế tiếp phải kết thúc tên thẻ.
    static func paragraphRanges(in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = text.startIndex
        while let open = text.range(of: "<a:p", range: cursor ..< text.endIndex) {
            let after = text.index(open.lowerBound, offsetBy: 4)
            let next = after < text.endIndex ? text[after] : " "
            guard next == " " || next == ">" || next == "/" else {
                cursor = after
                continue
            }
            guard let headerEnd = text.range(of: ">", range: open.upperBound ..< text.endIndex)
            else { break }
            if text[open.upperBound ..< headerEnd.lowerBound].hasSuffix("/") {
                result.append(open.lowerBound ..< headerEnd.upperBound)
                cursor = headerEnd.upperBound
                continue
            }
            guard let close = text.range(
                of: "</a:p>", range: headerEnd.upperBound ..< text.endIndex) else { break }
            result.append(open.lowerBound ..< close.upperBound)
            cursor = close.upperBound
        }
        return result
    }

    /// Chữ mới vào `<a:t>` đầu tiên, các `<a:t>` còn lại làm rỗng.
    ///
    /// Cùng luật và cùng cái giá với Word: giữ thuộc tính đoạn và định dạng run đầu, mất định
    /// dạng khác nhau giữa các run trong đúng đoạn ấy.
    static func replaceText(in paragraph: String, with text: String) -> String {
        var out = paragraph
        var ranges: [Range<String.Index>] = []
        var cursor = out.startIndex
        while let open = out.range(of: "<a:t", range: cursor ..< out.endIndex) {
            guard let headerEnd = out.range(of: ">", range: open.upperBound ..< out.endIndex)
            else { break }
            guard let close = out.range(of: "</a:t>", range: headerEnd.upperBound ..< out.endIndex)
            else { break }
            ranges.append(headerEnd.upperBound ..< close.lowerBound)
            cursor = close.upperBound
        }
        guard !ranges.isEmpty else { return out }
        for range in ranges.reversed() {
            let isFirst = range.lowerBound == ranges[0].lowerBound
            out.replaceSubrange(range, with: isFirst ? DOCXWriter.escapeXML(text) : "")
        }
        return out
    }
}
