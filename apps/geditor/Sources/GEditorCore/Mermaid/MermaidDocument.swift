import Foundation

/// Loại sơ đồ Mermaid — FR-MMD-001 kê tên đúng mười một loại phải vẽ được.
///
/// ## Vì sao có `other` thay vì từ chối loại lạ
///
/// Cả dự án theo luật *"tệp của bản mới hơn thì TỪ CHỐI, không đoán"* (xem `QualityRules`). Ở
/// đây luật ấy KHÔNG áp dụng, và khác biệt đáng nói ra: `QualityRules` là thứ **ta** diễn giải
/// rồi chấm điểm, nên hiểu sai là ra một con số sai. Sơ đồ Mermaid thì do **mermaid.js** vẽ —
/// ta chỉ chuyền chữ qua. Từ chối một loại mà mermaid vẽ được (`sankey`, `xychart`, `kanban`…)
/// là làm hỏng một tài liệu chạy tốt, chỉ vì bảng liệt kê của ta cũ hơn thư viện.
///
/// Nên: loại NHẬN RA thì có tên tiếng Việt, mẫu sẵn và trợ giúp; loại lạ vẫn vẽ, chỉ không có
/// những thứ ấy.
public enum MermaidDiagramKind: Equatable, Sendable {
    case flowchart
    case sequence
    case classDiagram
    case state
    case entityRelationship
    case gantt
    case pie
    case mindmap
    case timeline
    case quadrant
    case gitGraph
    case other(String)

    /// Mười một loại FR-MMD-001 kê tên, theo đúng thứ tự của đặc tả.
    public static let named: [MermaidDiagramKind] = [
        .flowchart, .sequence, .classDiagram, .state, .entityRelationship,
        .gantt, .pie, .mindmap, .timeline, .quadrant, .gitGraph,
    ]

    public var vietnamese: String {
        switch self {
        case .flowchart: return "Lưu đồ"
        case .sequence: return "Tuần tự"
        case .classDiagram: return "Lớp"
        case .state: return "Trạng thái"
        case .entityRelationship: return "Thực thể — quan hệ"
        case .gantt: return "Gantt"
        case .pie: return "Bánh"
        case .mindmap: return "Bản đồ tư duy"
        case .timeline: return "Dòng thời gian"
        case .quadrant: return "Bốn góc phần tư"
        case .gitGraph: return "Nhánh Git"
        case let .other(keyword): return keyword
        }
    }

    /// Từ khoá mở đầu mà người dùng gõ, để chèn mẫu và để gợi ý.
    public var keyword: String {
        switch self {
        case .flowchart: return "flowchart"
        case .sequence: return "sequenceDiagram"
        case .classDiagram: return "classDiagram"
        case .state: return "stateDiagram-v2"
        case .entityRelationship: return "erDiagram"
        case .gantt: return "gantt"
        case .pie: return "pie"
        case .mindmap: return "mindmap"
        case .timeline: return "timeline"
        case .quadrant: return "quadrantChart"
        case .gitGraph: return "gitGraph"
        case let .other(keyword): return keyword
        }
    }

    /// Đoán loại từ dòng khai báo đầu tiên.
    ///
    /// So theo TIỀN TỐ chứ không so bằng: dòng thật thường mang thêm tham số —
    /// `flowchart TD`, `stateDiagram-v2`, `pie showData`, `gitGraph LR:`.
    public static func from(declaration line: String) -> MermaidDiagramKind {
        let text = line.trimmingCharacters(in: .whitespaces)
        // `stateDiagram-v2` phải xét TRƯỚC `stateDiagram`, và `flowchart` trước `graph` —
        // bảng này duyệt theo thứ tự, nên thứ tự của nó là một phần của câu trả lời.
        let table: [(String, MermaidDiagramKind)] = [
            ("flowchart", .flowchart), ("graph", .flowchart),
            ("sequenceDiagram", .sequence),
            ("classDiagram-v2", .classDiagram), ("classDiagram", .classDiagram),
            ("stateDiagram-v2", .state), ("stateDiagram", .state),
            ("erDiagram", .entityRelationship),
            ("gantt", .gantt),
            ("pie", .pie),
            ("mindmap", .mindmap),
            ("timeline", .timeline),
            ("quadrantChart", .quadrant),
            ("gitGraph", .gitGraph),
        ]
        for (prefix, kind) in table where text.hasPrefix(prefix) {
            // `pie` không được khớp với `pieces`: sau từ khoá phải là hết dòng hoặc một ký tự
            // KHÔNG phải chữ/số.
            let rest = text.dropFirst(prefix.count)
            if let next = rest.first, next.isLetter || next.isNumber || next == "-" { continue }
            return kind
        }
        let keyword = text.prefix { !$0.isWhitespace }
        return .other(String(keyword))
    }
}

/// Một khối sơ đồ Mermaid nằm trong một tài liệu văn bản — FR-MMD-003.
///
/// Dùng chung cho cả ba đường vào mà đặc tả nêu: tệp `.mmd` thuần (cả tệp là một sơ đồ), khối
/// ` ```mermaid ` trong Markdown, và khối ấy trong `.greport.md`. Một bộ phân tích cho cả ba
/// chứ không ba bộ — ba bộ thì đến một ngày chúng nhận ra ba tập khối khác nhau trên cùng một
/// tệp, và người dùng thấy sơ đồ hiện trong preview này mà mất trong preview kia.
public struct MermaidBlock: Equatable, Sendable {
    /// Nội dung sơ đồ, KHÔNG gồm hàng rào.
    public var source: String
    /// Dòng của hàng rào mở, 0-based — để chỉ chỗ lỗi và để bấm sơ đồ nhảy về đúng dòng.
    public var fenceLine: Int
    /// Dòng đầu tiên của NỘI DUNG, 0-based. Số dòng mermaid báo lỗi cộng vào đây.
    public var firstContentLine: Int
    /// Thứ tự trong tài liệu.
    public var index: Int
    /// Số dòng NỘI DUNG của khối, không kể hai hàng rào.
    ///
    /// Đếm ra chứ không suy từ `source`: khối rỗng cho `source == ""`, mà `"".components(...)`
    /// trả về MỘT phần tử — nên suy ngược sẽ lệch đúng một dòng ở chính ca dễ gặp nhất. Con số
    /// này là thứ FR-MMD-008 dùng để thay đúng phần thân khi tách/nhúng.
    public var contentLineCount: Int

    public init(
        source: String, fenceLine: Int, firstContentLine: Int, index: Int,
        contentLineCount: Int? = nil
    ) {
        self.source = source
        self.fenceLine = fenceLine
        self.firstContentLine = firstContentLine
        self.index = index
        self.contentLineCount = contentLineCount
            ?? (source.isEmpty ? 0 : source.components(separatedBy: "\n").count)
    }

    public var kind: MermaidDiagramKind {
        MermaidDocument.declaration(in: source)
            .map(MermaidDiagramKind.from(declaration:)) ?? .other("")
    }

    /// Sơ đồ rỗng (chỉ có chú thích, hoặc không có dòng khai báo nào).
    public var isEmpty: Bool { MermaidDocument.declaration(in: source) == nil }

    /// Số dòng TRONG TÀI LIỆU cho một số dòng mermaid báo về (1-based trong khối).
    public func documentLine(forDiagramLine line: Int) -> Int {
        firstContentLine + max(0, line - 1)
    }
}

public enum MermaidDocument {

    /// Đuôi tệp sơ đồ rời — FR-MMD-008 tách/nhúng dùng lại đúng đuôi này.
    public static let fileExtension = "mmd"

    /// Tìm mọi khối ` ```mermaid ` trong một tài liệu Markdown.
    ///
    /// ## Vì sao KHÔNG dùng lại `ReportDocument.parse`
    ///
    /// `ReportDocument` phân tích một định dạng HẸP hơn: nó đòi frontmatter đúng chỗ, nó ném lỗi
    /// khi một khối không đóng, và nó chỉ nhận bốn loại khối của báo cáo. Một tệp Markdown bình
    /// thường vi phạm cả ba điều ấy mà vẫn hoàn toàn hợp lệ. Hàm này chỉ làm một việc và không
    /// bao giờ ném: **tìm khối mermaid, bỏ qua mọi thứ khác**.
    ///
    /// Hàng rào không đóng thì lấy tới hết tệp thay vì bỏ qua — người dùng đang GÕ DỞ, và một
    /// preview tắt ngóm giữa lúc gõ là một preview người ta thôi mở.
    public static func blocks(in text: String) -> [MermaidBlock] {
        var blocks: [MermaidBlock] = []
        let lines = text.components(separatedBy: "\n")
        var cursor = 0
        var index = 0
        while cursor < lines.count {
            let trimmed = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") else {
                cursor += 1
                continue
            }
            let info = String(trimmed.dropFirst(3))
                .trimmingCharacters(in: .whitespaces).lowercased()
            let fenceLine = cursor
            cursor += 1
            var body: [String] = []
            while cursor < lines.count,
                  !lines[cursor].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                body.append(lines[cursor])
                cursor += 1
            }
            // Bỏ qua hàng rào đóng, nếu có.
            if cursor < lines.count { cursor += 1 }
            guard info == "mermaid" else { continue }
            blocks.append(MermaidBlock(
                source: body.joined(separator: "\n"),
                fenceLine: fenceLine, firstContentLine: fenceLine + 1, index: index,
                contentLineCount: body.count))
            index += 1
        }
        return blocks
    }

    /// Cả tệp là MỘT sơ đồ — dùng cho `.mmd`.
    public static func wholeFile(_ text: String) -> MermaidBlock {
        MermaidBlock(source: text, fenceLine: 0, firstContentLine: 0, index: 0)
    }

    /// Dòng KHAI BÁO của một sơ đồ: dòng có nghĩa đầu tiên.
    ///
    /// Bỏ qua ba thứ đứng trước nó, và cả ba đều gặp trong tài liệu thật:
    ///   - frontmatter YAML `---` … `---` (mermaid 10+ dùng để đặt `title`),
    ///   - chỉ thị `%%{init: {...}}%%` (FR-MMD-007 dùng cho theme),
    ///   - chú thích `%%` và dòng trống.
    ///
    /// Bỏ sót vế nào cũng cho ra cùng một triệu chứng: loại sơ đồ bị đoán là "khác", và mọi thứ
    /// suy từ loại — mẫu, gợi ý, trợ giúp — im lặng biến mất.
    public static func declaration(in source: String) -> String? {
        var lines = source.components(separatedBy: "\n")[...]
        // Frontmatter phải nằm ở dòng CÓ NGHĨA đầu tiên.
        var start = 0
        while start < lines.count,
              lines[start].trimmingCharacters(in: .whitespaces).isEmpty { start += 1 }
        if start < lines.count,
           lines[start].trimmingCharacters(in: .whitespaces) == "---" {
            var end = start + 1
            while end < lines.count,
                  lines[end].trimmingCharacters(in: .whitespaces) != "---" { end += 1 }
            if end < lines.count { lines = lines[(end + 1)...] }
        } else {
            lines = lines[start...]
        }

        var insideDirective = false
        for line in lines {
            var text = line.trimmingCharacters(in: .whitespaces)
            if insideDirective {
                // Chỉ thị nhiều dòng: bỏ tới khi thấy `}%%`.
                if let close = text.range(of: "}%%") {
                    insideDirective = false
                    text = String(text[close.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    continue
                }
            }
            while text.hasPrefix("%%{") {
                if let close = text.range(of: "}%%") {
                    text = String(text[close.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    insideDirective = true
                    text = ""
                    break
                }
            }
            if text.isEmpty { continue }
            if text.hasPrefix("%%") { continue }   // chú thích
            return text
        }
        return nil
    }
}
