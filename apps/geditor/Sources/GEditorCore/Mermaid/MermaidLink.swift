import Foundation

/// Tách khối mermaid ra tệp `.mmd` riêng và nhúng ngược lại — FR-MMD-008.
///
/// Đặc tả: *"TÁCH block mermaid từ Markdown/.greport.md ra file .mmd riêng và NHÚNG ngược lại —
/// giữ tham chiếu để sửa một nơi."*
///
/// ## Tham chiếu nằm TRONG khối, không nằm trên hàng rào
///
/// Cách hiển nhiên hơn là ghi lên chính hàng rào — ` ```mermaid file=so-do.mmd `. Đã cân nhắc và
/// **bỏ**, vì hai bộ đọc phải sửa theo: `MermaidDocument.blocks` đòi chuỗi info đúng bằng
/// `mermaid`, còn `ReportDocument.parse` đòi nó khớp đúng tên một `BlockKind` — dòng info lạ sẽ
/// bị chép nguyên sang Markdown và sơ đồ biến mất khỏi báo cáo. Sửa cả hai bộ đọc để đổi lấy một
/// dòng đẹp hơn là đổi một khoản rủi ro thật lấy một thứ không ai nhìn.
///
/// Nên tham chiếu là **một dòng chú thích mermaid hợp lệ**:
///
///     ```mermaid
///     %% geditor:file so-do.mmd
///     ```
///
/// Khối ấy vẫn là mermaid đúng cú pháp, vẫn đi qua cả hai bộ đọc mà không sửa dòng nào, và mọi
/// công cụ khác đọc nó thành một sơ đồ rỗng — không phải một lỗi cú pháp.
///
/// ## Cái giá, nói thẳng ra
///
/// Tệp Markdown sau khi tách **không còn tự chứa**: mở nó trên GitHub sẽ thấy một khối trống,
/// vì chỉ GEditor biết đọc dòng tham chiếu. Đó là cái giá không tránh được của "sửa một nơi", và
/// nó có đường lui một bước: lệnh NHÚNG NGƯỢC dán nội dung trở lại trước khi đem tệp đi nơi khác.
public enum MermaidLink {

    public struct Failure: Error, Equatable {
        public let reason: String
        public init(reason: String) { self.reason = reason }
    }

    /// Dấu mở đầu dòng tham chiếu. Có tiền tố `geditor:` để không đụng chú thích của người dùng.
    public static let marker = "%% geditor:file "

    /// Đường dẫn mà khối này tham chiếu tới. `nil` khi khối chứa sơ đồ thật.
    public static func reference(in source: String) -> String? {
        for line in source.components(separatedBy: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix(marker) else { continue }
            let path = String(text.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            return path.isEmpty ? nil : path
        }
        return nil
    }

    public static func referenceBody(_ path: String) -> String { marker + path }

    // MARK: - Tách

    /// Thay phần thân của khối bằng một dòng tham chiếu; trả kèm nội dung tệp cần ghi.
    ///
    /// KHÔNG tự ghi tệp: tầng lõi không được đụng vào đĩa của người dùng (sandbox và quyền là
    /// việc của tầng app), và trả về nội dung để chỗ gọi ghi bằng `AtomicFileWriter` là cùng
    /// khuôn mọi phép sinh tệp khác trong kho.
    public static func extract(
        _ block: MermaidBlock, in document: String, to path: String
    ) throws -> (edits: [TextEdit], file: String) {
        if let cu = reference(in: block.source) {
            throw Failure(reason: "khối này đã tham chiếu «\(cu)» rồi")
        }
        guard block.fenceLine < block.firstContentLine else {
            // Tệp `.mmd` thuần: cả tệp ĐÃ là một sơ đồ rời, tách nữa là tạo ra một tệp trỏ vào
            // chính nó.
            throw Failure(reason: "tệp này đã là một sơ đồ rời, không có khối nào để tách")
        }
        guard !block.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure(reason: "khối rỗng — không có gì để tách ra")
        }
        let lines = document.components(separatedBy: "\n")
        let range = try contentRange(of: block, lines: lines)
        let indent = self.indent(ofLine: block.fenceLine, lines: lines)
        // Nội dung tệp kết thúc bằng xuống dòng: một tệp văn bản không có dòng cuối là thứ
        // `git diff` báo là "\\ No newline at end of file" ở mọi lần sửa sau đó.
        let file = block.source.hasSuffix("\n") ? block.source : block.source + "\n"
        return ([TextEdit(range: range, text: indent + referenceBody(path) + "\n")], file)
    }

    // MARK: - Nhúng ngược

    /// Thay dòng tham chiếu bằng chính nội dung tệp.
    public static func embed(
        _ block: MermaidBlock, in document: String, content: String
    ) throws -> [TextEdit] {
        guard reference(in: block.source) != nil else {
            throw Failure(reason: "khối này chứa sơ đồ thật, không phải một tham chiếu")
        }
        let lines = document.components(separatedBy: "\n")
        let range = try contentRange(of: block, lines: lines)
        let indent = self.indent(ofLine: block.fenceLine, lines: lines)
        var than = content
        while than.hasSuffix("\n") { than.removeLast() }
        guard !than.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure(reason: "tệp được tham chiếu rỗng — nhúng vào sẽ mất luôn sơ đồ")
        }
        let noiDung = than.components(separatedBy: "\n")
            .map { $0.isEmpty ? $0 : indent + $0 }
            .joined(separator: "\n")
        return [TextEdit(range: range, text: noiDung + "\n")]
    }

    // MARK: - Phụ

    /// Khoảng BYTE của phần THÂN khối: từ đầu dòng nội dung đầu tiên tới đầu hàng rào đóng.
    static func contentRange(of block: MermaidBlock, lines: [String]) throws -> Range<Int> {
        let start = block.firstContentLine
        let end = start + block.contentLineCount
        guard start <= lines.count, end <= lines.count else {
            // Khối đọc từ một văn bản KHÁC với văn bản đang sửa — số dòng khi ấy vô nghĩa, và
            // áp bừa sẽ ghi đè lên một đoạn chẳng liên quan.
            throw Failure(reason: "khối không còn khớp với tài liệu — hãy thử lại")
        }
        return offset(ofLineStart: start, lines: lines) ..< offset(ofLineStart: end, lines: lines)
    }

    /// Thụt lề của hàng rào — khối mermaid nằm trong một mục danh sách thì cả thân thụt theo.
    static func indent(ofLine line: Int, lines: [String]) -> String {
        guard line < lines.count else { return "" }
        let noiDung = lines[line].drop { $0 == " " || $0 == "\t" }
        return String(lines[line].prefix(lines[line].count - noiDung.count))
    }

    static func offset(ofLineStart line: Int, lines: [String]) -> Int {
        var at = 0
        for i in 0 ..< min(line, lines.count) { at += lines[i].utf8.count + 1 }
        return at
    }
}
