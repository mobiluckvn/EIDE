import Foundation
import TreeSitter

/// Một đoạn đã được xác định loại, tính bằng offset byte của TÀI LIỆU.
public struct HighlightSpan: Equatable, Sendable {
    public let range: Range<Int>
    /// Tên capture của tree-sitter: "keyword", "string", "comment", "function"…
    public let scope: String

    public init(range: Range<Int>, scope: String) {
        self.range = range
        self.scope = scope
    }
}

/// Tô màu cú pháp trên MỘT CỬA SỔ nội dung — hiện thực quyết định ADR-04.
///
/// Không bao giờ phân tích cả tài liệu. Số đo PoC-D nói rõ vì sao:
///
/// - Tốc độ 15–21 MB/s → một file 1 GB mất 50–90 giây.
/// - Cây nặng **15–29 lần văn bản**, tỉ lệ không đổi theo cỡ file. Trần NFR-PERF-05 là 1,5×
///   cỡ file, nên phân tích cả tài liệu vượt trần ở mọi cỡ, và vượt bằng một bậc độ lớn.
///
/// Cách làm: phân tích **cửa sổ + lề 64 KB mỗi bên**, rồi **bỏ hai lề**. PoC-D đo được rằng
/// khi cắt một lát rời ra phân tích riêng, mọi chỗ sai đều nằm ở hai mép và phần giữa sạch
/// tuyệt đối — kể cả khi cố ý cắt vào giữa một khối `/* … */`.
///
/// Không có ngưỡng theo cỡ file: file 10 KB và file 10 GB đi cùng một đường.
public final class SyntaxHighlighter {

    /// Lề mỗi bên. 64 KB là con số ĐO ĐƯỢC ở PoC-D §2.5, không phải con số chọn cho đẹp.
    public static let marginBytes = 64 * 1024

    /// Quãng lùi thêm tối đa để tìm một dòng bắt đầu ở CỘT 0.
    ///
    /// Vượt quá thì thôi tìm và dùng biên dòng thường. Một file mà mọi dòng đều thụt lề suốt
    /// 1 MB là chuyện bệnh lý; quét mãi để chiều nó sẽ làm đứng cả việc tô màu.
    public static let columnZeroSearchLimit = 1 << 20

    public let language: SyntaxLanguage

    private let parser: OpaquePointer
    private let query: OpaquePointer?

    public init?(language: SyntaxLanguage) {
        guard let handle = language.handle, let parser = ts_parser_new() else { return nil }
        guard ts_parser_set_language(parser, handle) else {
            ts_parser_delete(parser)
            return nil
        }
        self.language = language
        self.parser = parser

        // Truy vấn biên dịch MỘT LẦN cho cả vòng đời: PoC-D đo truy vấn chạy mất 0,3 ms, còn
        // biên dịch nó thì đắt hơn nhiều và không phụ thuộc tài liệu.
        if let source = language.highlightQuerySource {
            var errorOffset: UInt32 = 0
            var errorType = TSQueryErrorNone
            query = source.withCString {
                ts_query_new(handle, $0, UInt32(strlen($0)), &errorOffset, &errorType)
            }
        } else {
            query = nil
        }
    }

    deinit {
        if let query { ts_query_delete(query) }
        ts_parser_delete(parser)
    }

    /// Các đoạn cần tô cho phạm vi `range` của tài liệu.
    ///
    /// `range` là phần muốn TÔ; hàm tự nới thêm lề hai bên để phân tích rồi cắt lề đi. Offset
    /// trả về là offset TÀI LIỆU, nên chỗ gọi dùng thẳng.
    ///
    /// Chạy ngoài main thread: PoC-D đo phân tích một cửa sổ 2 MB mất 110–190 ms.
    public func spans(
        in buffer: TextBuffer, range: Range<Int>, cancelToken: CancelToken = CancelToken()
    ) -> [HighlightSpan] {
        guard let request = makeRequest(in: buffer, range: range) else { return [] }
        return spans(for: request, cancelToken: cancelToken)
    }

    /// Một yêu cầu tô màu đã TÁCH KHỎI buffer.
    ///
    /// Đây là thứ đi qua ranh giới luồng, và nó mang theo BẢN SAO byte chứ không mang tham
    /// chiếu tới buffer. `TextBuffer` không an toàn đa luồng: đọc nó ở luồng nền trong khi
    /// người dùng đang gõ ở luồng chính là tranh chấp dữ liệu — không phải "có thể sai màu"
    /// mà là đọc vào vùng nhớ đã bị dời. Chụp 2,13 MB tốn khoảng 0,2 ms trên luồng chính,
    /// và đó là cái giá rẻ nhất trong toàn bộ đường này.
    public struct Request: Sendable {
        public let bytes: [UInt8]
        /// Offset tài liệu của byte đầu tiên trong `bytes`.
        public let baseOffset: Int
        /// Phạm vi (offset TÀI LIỆU) thật sự cần tô — hẹp hơn `bytes` đúng bằng hai lề.
        public let range: Range<Int>
    }

    /// Chụp yêu cầu. GỌI TRÊN LUỒNG SỞ HỮU BUFFER.
    public func makeRequest(in buffer: TextBuffer, range: Range<Int>) -> Request? {
        guard query != nil, buffer.count > 0 else { return nil }
        let scope = analysisRange(for: range, in: buffer)

        let bytes = buffer.bytes(in: scope)
        guard !bytes.isEmpty else { return nil }
        return Request(bytes: bytes, baseOffset: scope.lowerBound, range: range)
    }

    /// Tính các đoạn cần tô. Chạy được ở LUỒNG NỀN — nó không đụng tới buffer nào.
    public func spans(
        for request: Request, cancelToken: CancelToken = CancelToken()
    ) -> [HighlightSpan] {
        guard let query else { return [] }
        let scope = request.baseOffset ..< (request.baseOffset + request.bytes.count)
        let range = request.range

        return request.bytes.withUnsafeBufferPointer { region -> [HighlightSpan] in
            guard let tree = ts_parser_parse_string(
                parser, nil, region.baseAddress!, UInt32(region.count)
            ) else { return [] }
            defer { ts_tree_delete(tree) }

            let cursor = ts_query_cursor_new()!
            defer { ts_query_cursor_delete(cursor) }

            // Chỉ hỏi phần THẬT SỰ cần tô. Lề đã làm xong việc của nó — giúp bộ phân tích hiểu
            // đúng ngữ cảnh — và không được lọt ra kết quả.
            let queryStart = UInt32(range.lowerBound - scope.lowerBound)
            let queryEnd = UInt32(range.upperBound - scope.lowerBound)
            ts_query_cursor_set_byte_range(cursor, queryStart, queryEnd)
            ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree))

            var spans: [HighlightSpan] = []
            var match = TSQueryMatch()
            var captureIndex: UInt32 = 0
            var checked = 0

            while ts_query_cursor_next_capture(cursor, &match, &captureIndex) {
                checked += 1
                if checked % 4096 == 0, (try? cancelToken.check()) == nil { return spans }

                let capture = match.captures[Int(captureIndex)]
                let start = Int(ts_node_start_byte(capture.node)) + scope.lowerBound
                let end = Int(ts_node_end_byte(capture.node)) + scope.lowerBound
                guard end > start else { continue }

                var nameLength: UInt32 = 0
                guard let namePointer = ts_query_capture_name_for_id(
                    query, capture.index, &nameLength
                ) else { continue }

                spans.append(HighlightSpan(
                    range: Swift.max(start, range.lowerBound) ..< Swift.min(end, range.upperBound),
                    scope: String(cString: namePointer)
                ))
            }
            return spans.filter { !$0.range.isEmpty }
        }
    }

    /// Phạm vi thật sự đem đi phân tích: `range` nới ra hai bên, kẹp theo BIÊN DÒNG.
    ///
    /// Kẹp theo biên dòng vì cùng lý do `TextWindowing` làm thế: cắt giữa một ký tự nhiều byte
    /// sinh ra byte rác, và với tiếng Việt thì đó là chuyện gặp ngay chứ không phải hiếm.
    func analysisRange(for range: Range<Int>, in buffer: TextBuffer) -> Range<Int> {
        let wantStart = Swift.max(0, range.lowerBound - Self.marginBytes)
        let wantEnd = Swift.min(buffer.count, range.upperBound + Self.marginBytes)

        let startLine = buffer.lineNumber(atOffset: Swift.min(wantStart, Swift.max(buffer.count - 1, 0)))
        // Lùi tiếp về dòng bắt đầu ở CỘT 0.
        //
        // Đây là chỗ đo được, không phải phòng xa. Với Python và YAML — hai ngôn ngữ mà THỤT
        // LỀ chính là cú pháp — một lát bắt đầu giữa khối thụt lề khiến bộ phân tích không có
        // ngữ cảnh nào, và phần phục hồi lỗi đọc văn xuôi trong docstring thành mã: vùng 256 KB
        // ra 41.808 capture thay vì 4.699. YAML còn tệ hơn: ra 0.
        //
        // Nới lề rộng thêm KHÔNG cứu được (đo tới 256 KB vẫn y nguyên) — vì thiếu không phải
        // là một dấu mở, mà là cả gốc toạ độ thụt lề. Dóng vào cột 0 thì cả hai khớp TUYỆT ĐỐI
        // với phân tích cả file, và bốn ngôn ngữ còn lại không đổi gì.
        let start = columnZeroLineStart(before: buffer.offset(ofLineStart: startLine), in: buffer)

        let endLine = buffer.lineNumber(atOffset: Swift.min(wantEnd, Swift.max(buffer.count - 1, 0)))
        let end = endLine + 1 < buffer.lineCount
            ? buffer.offset(ofLineStart: endLine + 1)
            : buffer.count

        return Swift.min(start, range.lowerBound) ..< Swift.max(end, range.upperBound)
    }

    /// Đầu dòng KHÔNG THỤT LỀ gần nhất tại hoặc trước `offset`.
    ///
    /// Đọc lùi theo khối chứ không từng byte: từng byte thì mỗi lần gọi là hàng chục nghìn
    /// lượt tra piece table.
    func columnZeroLineStart(before offset: Int, in buffer: TextBuffer) -> Int {
        guard offset > 0 else { return 0 }
        let floor = Swift.max(0, offset - Self.columnZeroSearchLimit)
        var cursor = offset
        let chunkSize = 64 * 1024

        while cursor > floor {
            let chunkStart = Swift.max(floor, cursor - chunkSize)
            // Lấy THÊM một byte ở cuối khối.
            //
            // Chú thích trên hàm này nói "đọc lùi theo khối chứ không từng byte", nhưng vòng
            // lặp bên dưới lại đọc đúng MỘT byte cho mỗi dấu xuống dòng gặp phải — tức là mỗi
            // dòng một lần cấp phát mảng, đúng thứ nó bảo tránh. Byte ấy gần như luôn nằm sẵn
            // trong khối đang cầm; chỉ khi dấu xuống dòng rơi đúng cuối khối thì mới thiếu, và
            // một byte dôi ra là đủ cho cả hai ca.
            let lookahead = Swift.min(cursor + 1, buffer.count)
            let chunk = buffer.bytes(in: chunkStart ..< lookahead)

            // Duyệt ngược trong khối, tìm "\n" mà ngay sau nó là ký tự không phải trắng.
            // Bắt đầu từ byte cuối cùng THUỘC khối, không tính byte dôi ra.
            var index = cursor - 1 - chunkStart
            while index >= 0 {
                if chunk[index] == 0x0A {
                    let lineStart = chunkStart + index + 1
                    if lineStart >= offset {
                        index -= 1
                        continue
                    }
                    let next = index + 1
                    // `next == chunk.count` nghĩa là dòng ấy bắt đầu ở đúng cuối tài liệu —
                    // không có ký tự nào, nên nó không phải dòng cột 0.
                    if next < chunk.count {
                        let byte = chunk[next]
                        if byte != 0x20, byte != 0x09, byte != 0x0A { return lineStart }
                    }
                }
                index -= 1
            }
            cursor = chunkStart
        }
        // Chạm đáy: nếu đáy là đầu tài liệu thì đó CHÍNH LÀ cột 0; nếu là trần tìm kiếm thì
        // đành dùng nó, và nói rõ trong tài liệu rằng đây là trường hợp suy giảm.
        return floor
    }
}
