import Foundation
import TreeSitter

/// Truy nguyên chỗ chưa hiểu của Python (ADR-04 §2.6).
///
/// Ba phép đo độc lập cho ba con số khác nhau trên cùng một vùng 256 KB. Đã loại được ba
/// nghi phạm bằng đo: dữ liệu thử hợp lệ, truy vấn không bị cắt cụt, cây không có nút lỗi.
/// Phép đo này nhìn vào CẤU TRÚC CÂY thay vì đếm capture — nếu cây phân tích cả file thưa
/// hơn hẳn thì vấn đề nằm ở khâu phân tích chứ không ở khâu truy vấn.
enum PoCDPython {

    struct Row: Encodable {
        let megabytes: Int
        let bytes: Int
        /// Số nút trong cây — thước đo cấu trúc, không phụ thuộc truy vấn.
        let descendantCount: Int
        let nodesPerKB: Double
        let hasError: Bool
        /// Capture trên CẢ tài liệu, không giới hạn phạm vi.
        let capturesWholeFile: Int
        /// Capture khi giới hạn phạm vi vào 256 KB ở giữa.
        let capturesInMiddle256KB: Int
        /// Cùng vùng ấy nhưng phân tích RIÊNG một lát 256 KB + lề 64 KB.
        let capturesFromSlice: Int
        /// Như trên, nhưng lát bắt đầu ở một dòng KHÔNG THỤT LỀ (đầu một khối top-level).
        ///
        /// Đây là phép thử quyết định: nếu cắt ở dòng không thụt lề mà khớp, thì vấn đề là
        /// NGỮ CẢNH THỤT LỀ chứ không phải cỡ lề — và cách sửa là dóng biên cửa sổ vào dòng
        /// cột 0, chứ không phải nới lề rộng thêm.
        let capturesFromAlignedSlice: Int
        let alignedSliceStartsAtColumnZero: Bool
    }

    static func run(sizes: [Int], languageName: String = "python") -> [Row] {
        guard let language = PoCD.Language.all.first(where: { $0.name == languageName })
        else { return [] }
        return sizes.map { megabytes in
            let source = language.fixture(megabytes: megabytes)

            var start = source.count / 2
            while start > 0, source[start - 1] != UInt8(ascii: "\n") { start -= 1 }
            var end = min(source.count, start + 256 * 1024)
            while end > start, end < source.count, source[end - 1] != UInt8(ascii: "\n") { end -= 1 }

            let (count, hasError) = treeShape(language: language, bytes: source)
            let whole = countCaptures(language: language, bytes: source, range: nil)
            let middle = countCaptures(language: language, bytes: source, range: start ..< end)

            let margin = 64 * 1024
            var sliceStart = max(0, start - margin)
            while sliceStart > 0, source[sliceStart - 1] != UInt8(ascii: "\n") { sliceStart -= 1 }
            let sliceEnd = min(source.count, end + margin)
            let slice = Array(source[sliceStart ..< sliceEnd])
            let fromSlice = countCaptures(
                language: language, bytes: slice,
                range: (start - sliceStart) ..< (end - sliceStart)
            )

            // Lát thứ hai: lùi từ `sliceStart` về dòng KHÔNG THỤT LỀ gần nhất.
            var aligned = sliceStart
            while aligned > 0 {
                var lineStart = aligned
                while lineStart > 0, source[lineStart - 1] != UInt8(ascii: "\n") { lineStart -= 1 }
                let first = lineStart < source.count ? source[lineStart] : UInt8(ascii: " ")
                if first != UInt8(ascii: " "), first != UInt8(ascii: "\t"),
                   first != UInt8(ascii: "\n") {
                    aligned = lineStart
                    break
                }
                aligned = lineStart > 0 ? lineStart - 1 : 0
            }
            let alignedSlice = Array(source[aligned ..< sliceEnd])
            let fromAligned = countCaptures(
                language: language, bytes: alignedSlice,
                range: (start - aligned) ..< (end - aligned)
            )
            let alignedAtColumnZero = aligned == 0
                || (aligned > 0 && source[aligned - 1] == UInt8(ascii: "\n")
                    && source[aligned] != UInt8(ascii: " ") && source[aligned] != UInt8(ascii: "\t"))

            return Row(
                megabytes: megabytes,
                bytes: source.count,
                descendantCount: count,
                nodesPerKB: Double(count) / (Double(source.count) / 1024),
                hasError: hasError,
                capturesWholeFile: whole,
                capturesInMiddle256KB: middle,
                capturesFromSlice: fromSlice,
                capturesFromAlignedSlice: fromAligned,
                alignedSliceStartsAtColumnZero: alignedAtColumnZero
            )
        }
    }

    private static func treeShape(language: PoCD.Language, bytes: [UInt8]) -> (Int, Bool) {
        bytes.withUnsafeBufferPointer { buffer -> (Int, Bool) in
            let parser = ts_parser_new()!
            defer { ts_parser_delete(parser) }
            ts_parser_set_language(parser, language.handle)
            guard let tree = ts_parser_parse_string(
                parser, nil, buffer.baseAddress!, UInt32(buffer.count)
            ) else { return (0, true) }
            defer { ts_tree_delete(tree) }
            let root = ts_tree_root_node(tree)
            return (Int(ts_node_descendant_count(root)), ts_node_has_error(root))
        }
    }

    private static func countCaptures(
        language: PoCD.Language, bytes: [UInt8], range: Range<Int>?
    ) -> Int {
        guard let query = language.highlightQuery else { return 0 }
        return bytes.withUnsafeBufferPointer { buffer -> Int in
            let parser = ts_parser_new()!
            defer { ts_parser_delete(parser) }
            ts_parser_set_language(parser, language.handle)
            guard let tree = ts_parser_parse_string(
                parser, nil, buffer.baseAddress!, UInt32(buffer.count)
            ) else { return 0 }
            defer { ts_tree_delete(tree) }

            let cursor = ts_query_cursor_new()!
            defer { ts_query_cursor_delete(cursor) }
            if let range {
                ts_query_cursor_set_byte_range(cursor, UInt32(range.lowerBound), UInt32(range.upperBound))
            }
            ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree))

            var seen = Set<String>()
            var match = TSQueryMatch()
            var captureIndex: UInt32 = 0
            while ts_query_cursor_next_capture(cursor, &match, &captureIndex) {
                let capture = match.captures[Int(captureIndex)]
                seen.insert("\(ts_node_start_byte(capture.node))-\(ts_node_end_byte(capture.node))")
            }
            return seen.count
        }
    }
}
