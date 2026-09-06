import Foundation
import TreeSitter

/// Gấp khối theo CÂY CÚ PHÁP, cho những ngôn ngữ dùng dấu ngoặc (FR-CORE code folding).
///
/// **Vì sao không đếm ngoặc bằng byte.** Đếm `{` và `}` chạy đúng trên file mẫu và sai trên file
/// thật, vì mọi ngôn ngữ đều cho phép dấu ngoặc nằm trong chuỗi và chú thích:
///
/// ```c
/// printf("dùng { để mở khối");   // và } để đóng
/// ```
///
/// Ba dấu ngoặc trong dòng ấy không mở hay đóng khối nào cả. Bộ đếm byte sẽ lệch từ đó tới hết
/// file, và cái sai không dừng ở "gấp thiếu một khối" — nó gấp NHẦM CHỖ, giấu mất những dòng
/// người dùng đang nhìn. Cây cú pháp thì đã biết đâu là chuỗi, đâu là chú thích, đâu là mã.
///
/// **Không có bảng luật theo ngôn ngữ.** `DocumentOutline` cần bảng ấy vì nó phải biết
/// `function_declaration` khác `type_spec` ở chỗ nào. Gấp thì không cần biết tên nút: một khối
/// gấp được là một nút **mở bằng dấu ngoặc và đóng bằng dấu ngoặc khớp**, trải nhiều dòng. Luật
/// ấy đúng cho C, C++, Java, Go, Rust, JavaScript, PHP… mà không phải viết bảng nào, và nó tự
/// đúng theo với mọi grammar cập nhật về sau.
///
/// **Chú thích nhiều dòng cũng gấp được**, vì đó là thứ người ta hay muốn gấp nhất sau khối mã:
/// một khối giấy phép 30 dòng ở đầu file.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
extension FoldRanges {

    /// Vùng gấp lấy từ cây cú pháp của `language`.
    public static func byTree(in buffer: TextBuffer, language: SyntaxLanguage) -> [FoldRange] {
        guard let handle = language.handle else { return [] }
        let bytes = buffer.bytes(in: 0 ..< buffer.count)
        guard !bytes.isEmpty else { return [] }

        guard let parser = ts_parser_new() else { return [] }
        defer { ts_parser_delete(parser) }
        guard ts_parser_set_language(parser, handle) else { return [] }

        var spans: [(start: Int, end: Int)] = []
        bytes.withUnsafeBufferPointer { region in
            guard let base = region.baseAddress,
                  let tree = ts_parser_parse_string(parser, nil, base, UInt32(region.count))
            else { return }
            defer { ts_tree_delete(tree) }
            collect(node: ts_tree_root_node(tree), region: region, into: &spans)
        }
        guard !spans.isEmpty else { return [] }

        var folds: [FoldRange] = []
        var seen = Set<Int>()
        for span in spans {
            let headerLine = buffer.lineNumber(atOffset: span.start)
            let lastLine = buffer.lineNumber(atOffset: Swift.max(span.end - 1, 0))
            guard lastLine > headerLine else { continue }
            // Nhiều nút lồng nhau bắt đầu ở CÙNG một dòng — `if (x) {` cho ra cả nút `if` lẫn
            // nút khối. Chúng gấp ra cùng một kết quả, và hai mục trùng nhau trong danh sách
            // làm lệnh "gấp/mở tại con nháy" phải bấm hai lần mới thấy đổi.
            guard seen.insert(headerLine).inserted else { continue }

            let hiddenStart = buffer.offset(ofLineStart: headerLine + 1)
            let hiddenEnd = buffer.lineRangeForFold(lastLine).upperBound
            guard hiddenStart < hiddenEnd else { continue }
            folds.append(FoldRange(
                headerLine: headerLine, lastLine: lastLine,
                hiddenBytes: hiddenStart ..< hiddenEnd,
                caretHome: buffer.contentRange(ofLine: headerLine).upperBound,
                kind: .brackets
            ))
        }
        return folds.sorted { $0.headerLine < $1.headerLine }
    }

    /// Duyệt cây, nhặt những nút gấp được.
    ///
    /// Duyệt bằng ngăn xếp tường minh chứ không đệ quy: mã sinh bằng máy lồng vài nghìn tầng là
    /// chuyện thường, và tràn ngăn xếp thì app tắt ngóm không thông báo. Cùng lý do với
    /// `JSONIndex`.
    private static func collect(
        node: TSNode, region: UnsafeBufferPointer<UInt8>, into spans: inout [(start: Int, end: Int)]
    ) {
        var stack = [node]
        while let current = stack.popLast() {
            let start = Int(ts_node_start_byte(current))
            let end = Int(ts_node_end_byte(current))
            if end > start, isFoldable(current, start: start, end: end, region: region) {
                spans.append((start, end))
            }
            // Duyệt CẢ nút không tên: khối `{ … }` trong C là một nút `compound_statement` có
            // tên, nhưng dấu `{` và `}` bên trong nó là nút KHÔNG tên, và vài grammar đặt khối
            // ở chỗ chỉ với tới được qua nút không tên.
            let count = ts_node_child_count(current)
            guard count > 0 else { continue }
            for index in stride(from: Int(count) - 1, through: 0, by: -1) {
                stack.append(ts_node_child(current, UInt32(index)))
            }
        }
    }

    /// Nút này có phải một khối gấp được không.
    private static func isFoldable(
        _ node: TSNode, start: Int, end: Int, region: UnsafeBufferPointer<UInt8>
    ) -> Bool {
        guard start < region.count, end <= region.count, end - start >= 2 else { return false }

        let first = region[start]
        let last = region[end - 1]
        if let closer = Self.brackets[first], closer == last { return true }

        // Chú thích nhiều dòng: `/* … */`, `<!-- … -->`, `"""…"""`. Nhận theo TÊN NÚT vì mỗi
        // ngôn ngữ mở đầu một kiểu, nhưng mọi grammar đều gọi nó là "comment".
        let type = String(cString: ts_node_type(node))
        guard type.contains("comment") else { return false }
        // Chú thích một dòng (`// …`) nằm liền nhau không phải một khối — mỗi dòng là một nút
        // riêng, và nút riêng thì không trải nhiều dòng nên đã bị loại ở chỗ gọi.
        return true
    }

    /// Dấu mở → dấu đóng khớp.
    ///
    /// Không có `<`: trong C++ và Java nó vừa là ngoặc nhọn của generic vừa là phép so sánh, và
    /// cây cú pháp cho ra `<` khớp `>` ở những chỗ mà gấp lại chẳng có nghĩa gì.
    private static let brackets: [UInt8: UInt8] = [
        UInt8(ascii: "{"): UInt8(ascii: "}"),
        UInt8(ascii: "["): UInt8(ascii: "]"),
        UInt8(ascii: "("): UInt8(ascii: ")"),
    ]
}
