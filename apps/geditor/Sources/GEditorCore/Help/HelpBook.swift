import Foundation

/// Sách hướng dẫn trong ứng dụng — mô hình dữ liệu, tìm kiếm, và bộ tự soát (NFR-USE-04).
///
/// ## Vì sao nội dung là KHỐI có kiểu, không phải Markdown
///
/// Cách hiển nhiên là để mỗi trang là một chuỗi Markdown rồi dựng nó ra màn hình. Đã thử hướng
/// ấy và bỏ, vì ba lý do cụ thể:
///
/// 1. **`NSAttributedString(markdown:)` không dựng bảng.** Phần lớn giá trị của một trang trợ
///    giúp trình soạn thảo nằm ở bảng phím tắt và bảng khoá cấu hình. Một trang trợ giúp hiện
///    ra dấu `|` thay vì kẻ bảng thì thà đừng có.
/// 2. **Cổng soát được thứ có kiểu, không soát được văn xuôi.** `HelpBook.problems` đọc được
///    "khối mã này thiếu tên ngôn ngữ", "bảng này có hàng lệch số cột", "trang này trỏ tới một
///    trang không tồn tại". Trên một chuỗi Markdown thì cả ba câu ấy đều phải viết bằng regex,
///    và regex trên văn xuôi là thứ báo sai lúc nào không biết.
/// 3. **Dịch được từng mẩu.** Bản tiếng Việt là bản NGUỒN. Khi dịch, thứ đi dịch là từng chuỗi
///    trong từng khối, chứ không phải một trang Markdown mà người dịch phải tự đoán chỗ nào là
///    cú pháp không được đụng vào. Khối `.code` mang cờ `translatable = false` cho chính việc ấy.
///
/// ## Vì sao nội dung nằm trong MÃ, không nằm trong tệp của bundle
///
/// Giữ nguyên quyết định đã có từ `HelpPages`: hai kênh phát hành có bố cục bundle khác nhau, và
/// `GrammarLibrary` từng chết trong sandbox vì suy đường dẫn từ `argv[0]`. Một trang trợ giúp mở
/// không nổi vì tìm không thấy tệp là kiểu hỏng đặc biệt vô duyên — người dùng bấm vào nó đúng
/// lúc họ đang bí.
public struct HelpBook: Sendable {

    public let language: String
    public let chapters: [HelpChapter]

    public init(language: String, chapters: [HelpChapter]) {
        self.language = language
        self.chapters = chapters
    }

    public var allTopics: [HelpTopic] { chapters.flatMap(\.topics) }

    public func topic(id: String) -> HelpTopic? {
        allTopics.first { $0.id == id }
    }

    public func chapter(containing topicID: String) -> HelpChapter? {
        chapters.first { $0.topics.contains { $0.id == topicID } }
    }

    /// Mọi nhan đề lệnh mà sách này nhận là mình có hướng dẫn.
    ///
    /// Đây là vế mà cổng phủ lệnh đối chiếu với thanh menu THẬT. Không suy ra từ văn xuôi: một
    /// trang nhắc tới chữ "Sắp xếp dòng" trong một câu không có nghĩa là nó hướng dẫn lệnh ấy.
    public var coveredCommands: Set<String> {
        Set(allTopics.flatMap(\.commands))
    }

    /// Trang hướng dẫn lệnh `command`, nếu có.
    public func topic(forCommand command: String) -> HelpTopic? {
        allTopics.first { $0.commands.contains(command) }
    }
}

/// Một chương — nhóm trang cùng chủ đề, là mức trên cùng của mục lục.
public struct HelpChapter: Sendable {
    public let id: String
    public let title: String
    /// Một câu nói chương này để làm gì. Hiện dưới tên chương ở mục lục.
    public let summary: String
    public let topics: [HelpTopic]

    public init(id: String, title: String, summary: String, topics: [HelpTopic]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.topics = topics
    }
}

/// Một trang.
public struct HelpTopic: Sendable {
    /// Mã kebab-case, duy nhất trong cả sách. Đây là thứ `.seeAlso` trỏ tới và là thứ menu dùng
    /// để mở thẳng một trang, nên nó KHÔNG được dịch — đổi mã là gãy mọi liên kết.
    public let id: String
    public let title: String
    /// Một câu. Hiện ở mục lục và ở kết quả tìm kiếm.
    public let summary: String
    /// Từ khoá phụ cho ô tìm — tên cũ, tên tiếng Anh, chữ người dùng hay gõ. Không hiện ra.
    public let keywords: [String]
    /// Nhan đề mục menu mà trang này hướng dẫn. Rỗng là hợp lệ (trang khái niệm, trang quy trình).
    public let commands: [String]
    public let blocks: [HelpBlock]

    public init(
        id: String, title: String, summary: String,
        keywords: [String] = [], commands: [String] = [], blocks: [HelpBlock]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.keywords = keywords
        self.commands = commands
        self.blocks = blocks
    }
}

/// Một khối nội dung trong trang.
///
/// Tập khối cố ý HẸP. Mỗi khối mới là một nhánh nữa trong bộ dựng của tầng app, một nhánh nữa
/// trong bộ soát, và một thứ nữa người dịch phải hiểu. Thêm khối khi có trang thật cần đến nó,
/// không thêm cho đủ bộ.
public enum HelpBlock: Sendable {

    /// Đoạn văn. Hiểu `**đậm**` và `` `mã` `` ở mức nội tuyến — xem `HelpInline`.
    case paragraph(String)
    /// Tiêu đề mục trong trang.
    case heading(String)
    case bullets([String])
    /// Các bước có thứ tự. Khác `bullets` ở chỗ THỨ TỰ có nghĩa, và bộ dựng đánh số.
    case steps([String])
    case table(headers: [String], rows: [[String]])
    /// Bảng phím tắt. Là loại riêng chứ không phải `table` hai cột: bộ dựng vẽ phím bằng phông
    /// và nền riêng, và bản dịch chỉ được dịch cột việc — cột phím là ký hiệu, không phải chữ.
    case shortcuts([HelpShortcut])
    /// Khối mã hoặc cấu hình mẫu.
    ///
    /// `language` hiện thành nhãn ở góc khối, và là thứ bộ soát bắt khi thiếu. Nó **không** tô
    /// màu: bộ tô màu thật là tree-sitter, và ADR-08 đã đẩy hai mươi bảng grammar sang dylib nạp
    /// lười để giành lại 465 ms khởi động — kéo chúng vào chỉ để làm đẹp một khối mẫu là trả lại
    /// đúng thứ vừa giành được. Khối mẫu ở đây dài nhất là mươi dòng, và một nhãn `yaml` nói rõ
    /// hơn về việc "dán chỗ nào" so với việc từ khoá được tô xanh.
    case code(language: String, caption: String, source: String)
    /// Hộp lưu ý.
    case note(String)
    /// Hộp cảnh báo — dành cho thứ làm hỏng dữ liệu hoặc không lùi lại được.
    case warning(String)
    /// Liên kết sang trang khác, theo `HelpTopic.id`.
    case seeAlso([String])
}

public struct HelpShortcut: Sendable {
    /// Ký hiệu phím, ví dụ `⇧⌘D`. KHÔNG dịch.
    public let keys: String
    public let action: String

    public init(_ keys: String, _ action: String) {
        self.keys = keys
        self.action = action
    }
}

// MARK: - Tự soát

extension HelpBook {

    /// Mọi chỗ sách tự mâu thuẫn. Rỗng = sạch.
    ///
    /// Đây là thứ bài kiểm đơn vị khẳng định, và nó bắt đúng loại lỗi mà đọc bằng mắt không bắt
    /// được: một trang bị xoá mà năm trang khác vẫn trỏ tới, một bảng thêm cột ở hàng tiêu đề mà
    /// quên ở hàng thứ tư, một mã trang bị chép đôi khi tách chương.
    public func problems() -> [String] {
        var out: [String] = []
        var seenTopicIDs: Set<String> = []
        var seenChapterIDs: Set<String> = []

        for chapter in chapters {
            if chapter.id.isEmpty { out.append("Chương \"\(chapter.title)\" không có mã") }
            if !seenChapterIDs.insert(chapter.id).inserted {
                out.append("Mã chương trùng: \(chapter.id)")
            }
            if chapter.title.isEmpty { out.append("Chương \(chapter.id) không có tên") }
            if chapter.summary.isEmpty { out.append("Chương \(chapter.id) không có câu tóm tắt") }
            if chapter.topics.isEmpty { out.append("Chương \(chapter.id) không có trang nào") }

            for topic in chapter.topics {
                let nhan = "\(chapter.id)/\(topic.id)"
                if topic.id.isEmpty { out.append("Trang \"\(topic.title)\" không có mã") }
                if !seenTopicIDs.insert(topic.id).inserted {
                    out.append("Mã trang trùng: \(topic.id)")
                }
                if topic.id.contains(" ") || topic.id.lowercased() != topic.id {
                    out.append("Mã trang \(topic.id) phải là kebab-case thường, không dấu cách")
                }
                if topic.title.isEmpty { out.append("Trang \(nhan) không có tên") }
                if topic.summary.isEmpty { out.append("Trang \(nhan) không có câu tóm tắt") }
                if topic.blocks.isEmpty { out.append("Trang \(nhan) rỗng") }
                out.append(contentsOf: problems(in: topic, label: nhan))
            }
        }

        // Liên kết chết. Soát SAU khi đã thu hết mã trang, vì một trang được phép trỏ tới trang
        // đứng sau nó.
        for topic in allTopics {
            for block in topic.blocks {
                guard case let .seeAlso(ids) = block else { continue }
                for id in ids where !seenTopicIDs.contains(id) {
                    out.append("Trang \(topic.id) trỏ tới trang không có: \(id)")
                }
                if ids.contains(topic.id) {
                    out.append("Trang \(topic.id) trỏ tới chính nó")
                }
            }
        }
        return out
    }

    private func problems(in topic: HelpTopic, label: String) -> [String] {
        var out: [String] = []
        for (index, block) in topic.blocks.enumerated() {
            let ở = "\(label) khối #\(index + 1)"
            switch block {
            case let .paragraph(text), let .heading(text), let .note(text), let .warning(text):
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    out.append("\(ở) rỗng")
                }
                out.append(contentsOf: HelpInline.problems(in: text).map { "\(ở): \($0)" })
            case let .bullets(items), let .steps(items):
                if items.isEmpty { out.append("\(ở) là danh sách rỗng") }
                for item in items where item.trimmingCharacters(in: .whitespaces).isEmpty {
                    out.append("\(ở) có một mục rỗng")
                }
            case let .table(headers, rows):
                if headers.isEmpty { out.append("\(ở) là bảng không có hàng tiêu đề") }
                if rows.isEmpty { out.append("\(ở) là bảng không có dữ liệu") }
                for (rowIndex, row) in rows.enumerated() where row.count != headers.count {
                    out.append(
                        "\(ở) hàng \(rowIndex + 1) có \(row.count) ô, hàng tiêu đề có \(headers.count)"
                    )
                }
            case let .shortcuts(items):
                if items.isEmpty { out.append("\(ở) là bảng phím rỗng") }
                for item in items where item.keys.isEmpty || item.action.isEmpty {
                    out.append("\(ở) có một dòng phím thiếu vế")
                }
            case let .code(language, _, source):
                // Nhãn ngôn ngữ KHÔNG phải chuyện thẩm mỹ: nó trả lời câu "dán đoạn này vào
                // đâu". Một khối `yaml` và một khối `bash` trông giống hệt nhau trên màn hình,
                // và dán nhầm chỗ thì lỗi báo về sẽ không nhắc gì tới trang trợ giúp.
                if language.isEmpty { out.append("\(ở) là khối mã không có nhãn ngôn ngữ") }
                if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    out.append("\(ở) là khối mã rỗng")
                }
            case let .seeAlso(ids):
                if ids.isEmpty { out.append("\(ở) là danh sách liên kết rỗng") }
            }
        }
        return out
    }
}

// MARK: - Tìm trong sách

extension HelpBook {

    public struct SearchHit: Sendable {
        public let topic: HelpTopic
        public let chapterTitle: String
        /// Câu chứa chữ tìm được, đã cắt gọn. Rỗng khi khớp ở tên trang.
        public let snippet: String
        let score: Int
    }

    /// Tìm trong sách. Gõ KHÔNG DẤU vẫn ra chữ có dấu — cùng luật với ô lọc CSV và ô tìm hàm.
    ///
    /// Xếp hạng theo chỗ khớp chứ không theo số lần khớp: một trang tên đúng chữ người ta gõ gần
    /// như luôn là trang họ muốn, kể cả khi một trang khác nhắc chữ ấy mười lần trong thân bài.
    public func search(_ query: String, limit: Int = 40) -> [SearchHit] {
        let needle = TextFold.fold(query.trimmingCharacters(in: .whitespaces))
        guard !needle.isEmpty else { return [] }

        var hits: [SearchHit] = []
        for chapter in chapters {
            for topic in chapter.topics {
                var score = 0
                var snippet = ""

                let title = TextFold.fold(topic.title)
                if title == needle { score = 1000 }
                else if title.hasPrefix(needle) { score = 800 }
                else if title.contains(needle) { score = 600 }

                if score == 0, topic.keywords.contains(where: { TextFold.fold($0).contains(needle) }) {
                    score = 500
                }
                if score == 0, topic.commands.contains(where: { TextFold.fold($0).contains(needle) }) {
                    score = 450
                }
                if score == 0, TextFold.fold(topic.summary).contains(needle) {
                    score = 300
                    snippet = topic.summary
                }
                if score == 0, let found = firstMatch(of: needle, in: topic) {
                    score = 100
                    snippet = found
                }
                if score > 0 {
                    hits.append(SearchHit(
                        topic: topic, chapterTitle: chapter.title, snippet: snippet, score: score
                    ))
                }
            }
        }
        return hits
            .sorted { ($0.score, $1.topic.title) > ($1.score, $0.topic.title) }
            .prefix(limit)
            .map { $0 }
    }

    /// Câu đầu tiên trong thân bài có chứa chữ cần tìm, đã cắt còn một dòng đọc được.
    private func firstMatch(of needle: String, in topic: HelpTopic) -> String? {
        for block in topic.blocks {
            for text in HelpBlockText.searchable(block) {
                guard TextFold.fold(text).contains(needle) else { continue }
                return HelpBlockText.trim(text)
            }
        }
        return nil
    }
}

/// Rút chữ tìm được ra khỏi một khối.
///
/// `public` vì tầng app cũng cần nó: cổng "trang trợ giúp khớp với mô hình" đọc chữ của một
/// trang rồi đối chiếu với `DisplayView`. Viết một bộ rút chữ thứ hai ở đó là để hai bộ trôi
/// khỏi nhau, và khi ấy cổng canh một thứ khác với thứ người dùng đọc.
public enum HelpBlockText {

    /// Phần chữ của một khối mà ô tìm nên soi tới.
    ///
    /// Khối mã CÓ nằm trong này, và đó là chủ ý: người dùng nhớ tên một khoá cấu hình
    /// (`fail_under`, `iqr_k`) thường xuyên hơn nhớ tên trang chứa nó.
    public static func searchable(_ block: HelpBlock) -> [String] {
        switch block {
        case let .paragraph(text), let .heading(text), let .note(text), let .warning(text):
            return [text]
        case let .bullets(items), let .steps(items):
            return items
        case let .table(headers, rows):
            return headers + rows.flatMap { $0 }
        case let .shortcuts(items):
            return items.map(\.action)
        case let .code(_, caption, source):
            return caption.isEmpty ? [source] : [caption, source]
        case .seeAlso:
            return []
        }
    }

    /// Cắt còn một dòng đọc được, bỏ ký hiệu nội tuyến.
    public static func trim(_ text: String, limit: Int = 160) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard flat.count > limit else { return flat }
        return String(flat.prefix(limit)) + "…"
    }
}
