import Foundation

/// Ngôn ngữ do người dùng tự định nghĩa (FR-FMT-502).
///
/// **Vì sao KHÔNG làm bằng tree-sitter.** Hai mươi ngôn ngữ dựng sẵn dùng tree-sitter vì grammar
/// của chúng có sẵn, đã được cả cộng đồng kiểm. Bắt người dùng viết một grammar tree-sitter cho
/// định dạng log nội bộ của công ty họ là đòi hỏi vô lý: nó cần một trình biên dịch, một bước
/// build, và hiểu biết về LR parsing. Thứ họ thật sự cần chỉ là "mấy từ này tô xanh, chuỗi trong
/// dấu nháy tô vàng, sau dấu `;` là chú thích".
///
/// Nên UDL ở đây là một **bộ quét từ vựng theo bảng**, khai bằng JSON. Nó KHÔNG hiểu cấu trúc
/// lồng nhau, và nói thẳng điều đó: gấp khối theo cú pháp, danh sách hàm và khớp ngoặc thông
/// minh vẫn thuộc về ngôn ngữ dựng sẵn.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
public struct UserDefinedLanguage: Codable, Equatable, Sendable {

    public var name: String
    /// Đuôi file dẫn tới ngôn ngữ này, không có dấu chấm.
    public var extensions: [String]
    /// Từ khoá, phân theo nhóm để tô khác màu. Khoá là tên nhóm: `keyword`, `type`, `constant`.
    public var keywordGroups: [String: [String]]
    public var caseSensitive: Bool
    public var lineComment: String?
    public var blockComment: [String]?          // [mở, đóng]
    /// Ký tự mở/đóng chuỗi. Mỗi phần tử là MỘT ký tự.
    public var stringDelimiters: [String]
    /// Ký tự thoát trong chuỗi; rỗng nghĩa là ngôn ngữ này không có escape.
    public var escapeCharacter: String

    public init(
        name: String, extensions: [String] = [], keywordGroups: [String: [String]] = [:],
        caseSensitive: Bool = true, lineComment: String? = nil, blockComment: [String]? = nil,
        stringDelimiters: [String] = ["\"", "'"], escapeCharacter: String = "\\"
    ) {
        self.name = name
        self.extensions = extensions
        self.keywordGroups = keywordGroups
        self.caseSensitive = caseSensitive
        self.lineComment = lineComment
        self.blockComment = blockComment
        self.stringDelimiters = stringDelimiters
        self.escapeCharacter = escapeCharacter
    }

    // MARK: - Đọc / ghi

    public static func load(from url: URL) throws -> UserDefinedLanguage {
        try JSONDecoder().decode(UserDefinedLanguage.self, from: try Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// Mọi ngôn ngữ trong thư mục. File hỏng bị BỎ QUA riêng nó, không làm mất cả danh sách.
    public static func all(in directory: URL) -> [UserDefinedLanguage] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .compactMap { try? load(from: directory.appendingPathComponent($0)) }
    }

    /// Ngôn ngữ nhận theo đuôi file, hoặc `nil`.
    ///
    /// Ngôn ngữ DỰNG SẴN thắng khi trùng đuôi: người dùng đặt UDL cho `.py` mà mất tô màu Python
    /// đầy đủ là một cú đổi chác họ không hề yêu cầu. Chỗ gọi giữ thứ tự ấy — xem
    /// `SyntaxLanguage.detect` được hỏi trước.
    public static func matching(path: String, in languages: [UserDefinedLanguage]) -> UserDefinedLanguage? {
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return languages.first { $0.extensions.contains { $0.lowercased() == ext } }
    }

    // MARK: - Quét

    public struct Span: Equatable, Sendable {
        public let range: Range<Int>
        /// Tên nhóm: một khoá của `keywordGroups`, hoặc `"string"` / `"comment"`.
        public let scope: String

        public init(range: Range<Int>, scope: String) {
            self.range = range
            self.scope = scope
        }
    }

    /// Tô một đoạn văn bản. `offset` là vị trí byte của `text` trong tài liệu.
    ///
    /// Thứ tự xét quan trọng: chú thích và chuỗi TRƯỚC từ khoá. Một từ khoá nằm trong chuỗi thì
    /// không phải từ khoá, và xét ngược lại sẽ tô nó lên — trông giống hệt một lỗi cú pháp mà
    /// người dùng đi tìm mãi không ra.
    public func spans(in text: String, offset: Int = 0) -> [Span] {
        let characters = Array(text)
        var byteOffsets = [Int](repeating: 0, count: characters.count + 1)
        var running = offset
        for (index, character) in characters.enumerated() {
            byteOffsets[index] = running
            running += String(character).utf8.count
        }
        byteOffsets[characters.count] = running

        let lineToken = lineComment.map(Array.init)
        let blockOpen = blockComment?.first.map(Array.init)
        let blockClose = blockComment?.last.map(Array.init)
        let quotes = Set(stringDelimiters.compactMap(\.first))
        let escape = escapeCharacter.first

        var spans: [Span] = []
        var index = 0
        while index < characters.count {
            if let lineToken, matches(characters, index, lineToken) {
                let start = index
                while index < characters.count, characters[index] != "\n" { index += 1 }
                spans.append(Span(range: byteOffsets[start] ..< byteOffsets[index], scope: "comment"))
                continue
            }
            if let blockOpen, let blockClose, matches(characters, index, blockOpen) {
                let start = index
                index += blockOpen.count
                while index < characters.count, !matches(characters, index, blockClose) { index += 1 }
                index = Swift.min(characters.count, index + blockClose.count)
                spans.append(Span(range: byteOffsets[start] ..< byteOffsets[index], scope: "comment"))
                continue
            }
            if quotes.contains(characters[index]) {
                let quote = characters[index]
                let start = index
                index += 1
                while index < characters.count {
                    if let escape, characters[index] == escape { index += 2; continue }
                    if characters[index] == quote { index += 1; break }
                    // Chuỗi không vắt qua dòng: một dấu nháy lẻ không được nuốt cả file.
                    if characters[index] == "\n" { break }
                    index += 1
                }
                index = Swift.min(index, characters.count)
                spans.append(Span(range: byteOffsets[start] ..< byteOffsets[index], scope: "string"))
                continue
            }
            if isWord(characters[index]) {
                let start = index
                while index < characters.count, isWord(characters[index]) { index += 1 }
                let word = String(characters[start ..< index])
                if let group = group(of: word) {
                    spans.append(Span(range: byteOffsets[start] ..< byteOffsets[index], scope: group))
                }
                continue
            }
            index += 1
        }
        return spans
    }

    private func group(of word: String) -> String? {
        let needle = caseSensitive ? word : word.lowercased()
        for (name, words) in keywordGroups.sorted(by: { $0.key < $1.key }) {
            for candidate in words where (caseSensitive ? candidate : candidate.lowercased()) == needle {
                return name
            }
        }
        return nil
    }

    private func isWord(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func matches(_ characters: [Character], _ index: Int, _ needle: [Character]) -> Bool {
        guard !needle.isEmpty, index + needle.count <= characters.count else { return false }
        for offset in 0 ..< needle.count where characters[index + offset] != needle[offset] {
            return false
        }
        return true
    }

    /// Một ví dụ đầy đủ để người dùng chép ra sửa.
    ///
    /// Có sẵn giá trị thật ở mọi khoá, vì "dựng file từ đầu và đoán tên khoá" chính là rào cản
    /// làm người ta không bao giờ dùng tới tính năng này.
    public static let example = UserDefinedLanguage(
        name: "Ví dụ — file cấu hình nội bộ",
        extensions: ["mycfg"],
        keywordGroups: [
            "keyword": ["nếu", "thì", "ngược_lại", "lặp", "kết_thúc"],
            "constant": ["đúng", "sai", "rỗng"],
        ],
        caseSensitive: false,
        lineComment: ";",
        blockComment: ["/*", "*/"],
        stringDelimiters: ["\"", "'"],
        escapeCharacter: "\\"
    )
}
