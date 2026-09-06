import Foundation
import TreeSitter

/// Một mục trong Function List (FR-DOC-307).
public struct DocumentSymbol: Equatable, Sendable {

    public enum Kind: String, Equatable, Sendable {
        case function
        case method
        case type          // class, struct, interface, enum
        case section       // heading của JSON/YAML/TOML, rule của CSS
    }

    public let name: String
    public let kind: Kind
    /// Offset tài liệu của đầu định nghĩa — chỗ con nháy nhảy tới khi bấm.
    public let offset: Int
    /// Số dòng (đếm từ 1) để hiện cạnh tên.
    public let line: Int
    /// Mức lồng nhau: phương thức trong lớp có `depth` lớn hơn lớp.
    public let depth: Int

    public var displayName: String { name }
}

/// Danh sách hàm / lớp / mục của tài liệu, dựng từ cây cú pháp tree-sitter (FR-DOC-307).
///
/// Đi thẳng trên CÂY chứ không viết truy vấn `.scm`: upstream không phát hành `tags.scm` cho
/// bộ grammar đã vendor, nên viết truy vấn ở đây là tự bịa ra một tệp mà không ai bảo trì
/// giúp. Duyệt cây thì luật nằm trong mã Swift, đọc được, và sai ở đâu thì một bài kiểm chỉ ra
/// đúng chỗ ấy.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi; Function List là một cách nhìn tài liệu.
public enum DocumentOutline {

    /// Trần kích thước để dựng danh sách.
    ///
    /// Function List cần phân tích TOÀN tài liệu — khác hẳn tô màu, vốn chỉ phân tích cửa sổ
    /// đang nhìn (ADR-04). Trên file hàng trăm MB thì phép phân tích ấy vừa lâu vừa ngốn bộ
    /// nhớ, mà kết quả là một danh sách dài tới mức không ai đọc. Trên trần này thì nói thẳng
    /// là không dựng, chứ không để người dùng ngồi chờ một thanh tiến trình không bao giờ xong.
    public static let sizeLimit = 16 * 1024 * 1024

    public struct Result: Equatable, Sendable {
        public let symbols: [DocumentSymbol]
        /// Tài liệu vượt trần — danh sách rỗng, và chỗ gọi phải nói ra vì sao.
        public let tooLarge: Bool
        public let language: SyntaxLanguage?

        public var summary: String {
            if tooLarge {
                return "File lớn hơn \(DocumentOutline.sizeLimit / 1024 / 1024) MB — không dựng danh sách"
            }
            guard let language else { return "Không nhận ra ngôn ngữ" }
            return symbols.isEmpty
                ? "Không tìm thấy mục nào trong file \(language.displayName)"
                : "\(symbols.count) mục · \(language.displayName)"
        }
    }

    /// Dựng danh sách cho cả tài liệu.
    ///
    /// Chạy được ở LUỒNG NỀN: nó chụp byte ra rồi mới phân tích, không giữ tham chiếu tới
    /// buffer (cùng lý do với `SyntaxHighlighter.Request`).
    public static func symbols(
        in buffer: TextBuffer,
        language: SyntaxLanguage?,
        cancelToken: CancelToken = CancelToken()
    ) -> Result {
        guard let language else { return Result(symbols: [], tooLarge: false, language: nil) }
        guard buffer.count <= sizeLimit else {
            return Result(symbols: [], tooLarge: true, language: language)
        }
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        return Result(
            symbols: symbols(in: bytes, language: language, cancelToken: cancelToken),
            tooLarge: false, language: language
        )
    }

    /// Bản làm việc trên mảng byte — không đụng tới buffer nào.
    public static func symbols(
        in bytes: [UInt8],
        language: SyntaxLanguage,
        cancelToken: CancelToken = CancelToken()
    ) -> [DocumentSymbol] {
        guard let handle = language.handle, !bytes.isEmpty else { return [] }
        guard let parser = ts_parser_new() else { return [] }
        defer { ts_parser_delete(parser) }
        guard ts_parser_set_language(parser, handle) else { return [] }

        let rules = Rules.forLanguage(language)
        guard !rules.isEmpty else { return [] }

        return bytes.withUnsafeBufferPointer { region -> [DocumentSymbol] in
            guard let base = region.baseAddress,
                  let tree = ts_parser_parse_string(parser, nil, base, UInt32(region.count))
            else { return [] }
            defer { ts_tree_delete(tree) }

            var out: [DocumentSymbol] = []
            var newlines = NewlineCounter(bytes: region)
            walk(
                node: ts_tree_root_node(tree), depth: 0, rules: rules, region: region,
                newlines: &newlines, into: &out, cancelToken: cancelToken
            )
            return out
        }
    }

    /// Duyệt cây theo chiều sâu, giữ đúng THỨ TỰ XUẤT HIỆN trong file.
    ///
    /// Thứ tự file chứ không sắp xếp theo tên: người dùng bấm vào Function List để nhảy tới
    /// một chỗ họ đang nhớ mang máng là "khoảng giữa file", và danh sách xếp theo abc thì phá
    /// mất trí nhớ ấy. Ai cần abc thì sắp xếp là việc của UI.
    private static func walk(
        node: TSNode,
        depth: Int,
        rules: [String: Rule],
        region: UnsafeBufferPointer<UInt8>,
        newlines: inout NewlineCounter,
        into out: inout [DocumentSymbol],
        cancelToken: CancelToken
    ) {
        if out.count % 128 == 0, (try? cancelToken.check()) == nil { return }

        var childDepth = depth
        let type = String(cString: ts_node_type(node))

        if let rule = rules[type], let name = name(of: node, rule: rule, region: region) {
            let start = Int(ts_node_start_byte(node))
            out.append(DocumentSymbol(
                name: name, kind: rule.kind, offset: start,
                line: newlines.line(atByte: start), depth: depth
            ))
            childDepth = depth + 1
        }

        let count = ts_node_named_child_count(node)
        guard count > 0 else { return }
        for index in 0 ..< count {
            walk(
                node: ts_node_named_child(node, index), depth: childDepth, rules: rules,
                region: region, newlines: &newlines, into: &out, cancelToken: cancelToken
            )
        }
    }

    /// Tên của một định nghĩa.
    ///
    /// Ưu tiên trường `name` do chính grammar khai; chỉ khi grammar không có trường ấy mới
    /// lấy node con đầu tiên theo kiểu đã chỉ định. Đọc theo trường thì đúng với mọi biến thể
    /// cú pháp mà grammar đã lo giúp — còn đếm node con là đoán, và cú pháp nào cũng có ngoại lệ.
    private static func name(
        of node: TSNode, rule: Rule, region: UnsafeBufferPointer<UInt8>
    ) -> String? {
        for field in rule.nameFields {
            let child = field.withCString { ts_node_child_by_field_name(node, $0, UInt32(strlen($0))) }
            if !ts_node_is_null(child) {
                return text(of: child, in: region)
            }
        }
        guard let fallback = rule.fallbackChildType else { return nil }
        let count = ts_node_named_child_count(node)
        for index in 0 ..< count {
            let child = ts_node_named_child(node, index)
            if String(cString: ts_node_type(child)) == fallback {
                return text(of: child, in: region)
            }
        }
        return nil
    }

    private static func text(of node: TSNode, in region: UnsafeBufferPointer<UInt8>) -> String? {
        let start = Int(ts_node_start_byte(node))
        let end = Int(ts_node_end_byte(node))
        guard start < end, end <= region.count else { return nil }
        let slice = UnsafeBufferPointer(rebasing: region[start ..< end])
        var raw = String(decoding: slice, as: UTF8.self)

        // Trong C và C++, tên hàm nằm trong `declarator` cùng với danh sách tham số. Cắt ở
        // dấu ngoặc đơn đầu tiên cho ra đúng cái tên, và làm được cho mọi biến thể khai báo
        // mà không phải đệ quy qua từng lớp con trỏ/mảng của cú pháp C.
        if let paren = raw.firstIndex(of: "(") { raw = String(raw[raw.startIndex ..< paren]) }
        // Xuống dòng trong tên (Go trước đây, và mọi grammar nào đó về sau) là dấu hiệu lấy
        // nhầm node bao ngoài — cắt ở dòng đầu để danh sách không phình thành cả thân hàm.
        if let newline = raw.firstIndex(of: "\n") { raw = String(raw[raw.startIndex ..< newline]) }

        // Khóa của JSON/YAML/TOML hay có dấu nháy bọc; tên trong danh sách thì không cần.
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t"))
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Đếm dòng một lượt, nhớ vị trí đã đếm tới.
    ///
    /// Các định nghĩa đi ra theo thứ tự offset TĂNG DẦN, nên đếm tiếp từ chỗ lần trước là đủ.
    /// Đếm lại từ đầu file cho mỗi mục là O(n²) trên file có vài nghìn hàm.
    struct NewlineCounter {
        let bytes: UnsafeBufferPointer<UInt8>
        private var scanned = 0
        private var line = 1

        init(bytes: UnsafeBufferPointer<UInt8>) { self.bytes = bytes }

        mutating func line(atByte offset: Int) -> Int {
            if offset < scanned {
                // Lùi lại (cây không phải lúc nào cũng đi tới): đếm lại từ đầu, hiếm khi xảy ra.
                scanned = 0
                line = 1
            }
            var index = scanned
            while index < offset, index < bytes.count {
                if bytes[index] == 0x0A { line += 1 }
                index += 1
            }
            scanned = index
            return line
        }
    }
}
