import Foundation

/// Tìm kiếm trên cả tài liệu mà KHÔNG dựng cả tài liệu thành mảng byte.
///
/// Đây là chỗ materialize cuối cùng còn lại sau ADR-01: bấm Tìm trên file 500 MB làm cấp phát
/// 500 MB, mỗi lần bấm.
///
/// Hai đường:
///
/// 1. **Liên tục** — tài liệu chưa sửa (hoặc sửa rất ít) thì piece table chỉ có một mảnh nằm
///    thẳng trên vùng mmap. Khớp thẳng trên vùng nhớ ấy: KHÔNG sao chép byte nào, và đây là
///    trường hợp thường gặp nhất (mở file lớn rồi tìm).
/// 2. **Theo cửa sổ** — tài liệu đã phân mảnh thì quét theo cửa sổ có PHẦN CHỒNG, giới hạn bộ
///    nhớ ở cỡ cửa sổ chứ không ở cỡ file.
///
/// Cửa sổ cắt theo BIÊN DÒNG, không cắt giữa dòng. Lý do không phải thẩm mỹ: `^` và `$` mặc
/// định khớp theo dòng (SearchOptions.multiline), nên một biên cửa sổ nằm giữa dòng sẽ tạo ra
/// một "đầu dòng" giả và `^abc` khớp ở chỗ không phải đầu dòng.
///
/// **Giới hạn đã biết, có chủ ý:** một kết quả khớp DÀI HƠN phần chồng và vắt qua biên cửa sổ
/// sẽ bị bỏ sót. Phần chồng mặc định 1 MB, nên chỉ pattern khớp trên một triệu byte liên tục
/// mới rơi vào trường hợp này — thực tế là regex đã mất kiểm soát chứ không phải nhu cầu thật.
/// Ghi ra đây vì một giới hạn không nói ra sẽ bị hiểu thành "tìm kiếm sai".
public enum DocumentSearch {

    /// Cỡ cửa sổ quét và phần chồng giữa hai cửa sổ liền nhau.
    public static let windowSize = 8 << 20
    public static let overlap = 1 << 20

    /// Tìm mọi kết quả khớp trong tài liệu.
    ///
    /// - Parameter limit: 0 = không giới hạn.
    public static func find(
        pattern: PCRE2Pattern,
        in buffer: TextBuffer,
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> [SearchMatch] {
        guard buffer.count > 0 else { return [] }

        var results: [SearchMatch] = []

        // Đường 1: vùng nhớ liên tục.
        if let contiguous = try buffer.withContiguousBytes({ region -> Result<[SearchMatch], Error> in
            do {
                var found: [SearchMatch] = []
                try pattern.enumerateMatches(in: region, cancelToken: cancelToken) { match in
                    found.append(match)
                    return limit <= 0 || found.count < limit
                }
                return .success(found)
            } catch {
                return .failure(error)
            }
        }) {
            return try contiguous.get()
        }

        // Đường 2: quét theo cửa sổ cắt tại biên dòng.
        var windowStart = 0
        /// Mọi kết quả bắt đầu TRƯỚC mốc này đã được báo ở cửa sổ trước.
        var reported = 0

        while windowStart < buffer.count {
            try cancelToken.check()

            let windowEnd = lineAlignedEnd(from: windowStart, in: buffer)
            let bytes = buffer.bytes(in: windowStart ..< windowEnd)

            try bytes.withUnsafeBytes { region in
                try pattern.enumerateMatches(in: region, cancelToken: cancelToken) { match in
                    let absolute = SearchMatch(
                        range: (match.range.lowerBound + windowStart) ..< (match.range.upperBound + windowStart),
                        groups: match.groups.map { group in
                            group.map { ($0.lowerBound + windowStart) ..< ($0.upperBound + windowStart) }
                        }
                    )
                    if absolute.range.lowerBound >= reported {
                        results.append(absolute)
                        reported = absolute.range.lowerBound + 1
                    }
                    return limit <= 0 || results.count < limit
                }
            }

            if limit > 0, results.count >= limit { break }
            if windowEnd >= buffer.count { break }

            // Biên kế tiếp phải TIẾN, luôn luôn.
            //
            // Bản đầu chỉ lùi về đầu dòng, và với một dòng dài hơn cả cửa sổ thì "đầu dòng"
            // là offset 0 — vòng lặp quay về chỗ cũ và chạy mãi. Test treo 10 phút mới lộ ra.
            var next = lineAlignedStart(before: windowEnd, in: buffer, back: overlap)
            if next <= windowStart { next = Swift.max(windowEnd - overlap, windowStart + 1) }
            if next <= windowStart { next = windowEnd }
            windowStart = next
        }

        return results
    }

    /// Kết quả khớp ĐẦU TIÊN bắt đầu từ `offset`, quay vòng về đầu tài liệu nếu hết.
    ///
    /// `find` trả về MỌI kết quả, nên dùng nó cho việc "tìm chỗ kế tiếp" là quét cả tài liệu
    /// mỗi bước — với macro chạy 100 lần trên file lớn thì đó là 100 lượt quét toàn file.
    ///
    /// Cửa sổ quét bắt đầu từ ĐẦU DÒNG chứa `offset`, không phải từ chính `offset`: cắt giữa
    /// dòng thì `^` không còn là "đầu dòng" và regex neo dòng sẽ khớp sai chỗ. Kết quả nằm
    /// trước `offset` bị bỏ qua.
    public static func findNext(
        pattern: PCRE2Pattern,
        in buffer: TextBuffer,
        from offset: Int,
        wrap: Bool = true,
        cancelToken: CancelToken = CancelToken()
    ) throws -> SearchMatch? {
        guard buffer.count > 0 else { return nil }
        let start = Swift.min(Swift.max(offset, 0), buffer.count)

        if let match = try firstMatch(pattern: pattern, in: buffer, from: start, cancelToken: cancelToken) {
            return match
        }
        // Quay vòng: tới cuối rồi thì tìm lại từ đầu, cùng lý do với ⌘D — không quay vòng thì
        // macro dừng ở giữa file mà không nói vì sao.
        guard wrap, start > 0 else { return nil }
        return try firstMatch(pattern: pattern, in: buffer, from: 0, cancelToken: cancelToken)
    }

    private static func firstMatch(
        pattern: PCRE2Pattern, in buffer: TextBuffer, from offset: Int, cancelToken: CancelToken
    ) throws -> SearchMatch? {
        func shift(_ match: SearchMatch, by base: Int) -> SearchMatch {
            SearchMatch(
                range: (match.range.lowerBound + base) ..< (match.range.upperBound + base),
                groups: match.groups.map { group in
                    group.map { ($0.lowerBound + base) ..< ($0.upperBound + base) }
                }
            )
        }

        // Đường 1: vùng nhớ liên tục — quét thẳng, không cắt cửa sổ.
        if let contiguous = try buffer.withContiguousBytes({ region -> Result<SearchMatch?, Error> in
            do {
                var found: SearchMatch?
                try pattern.enumerateMatches(in: region, cancelToken: cancelToken) { match in
                    guard match.range.lowerBound >= offset else { return true }
                    found = match
                    return false
                }
                return .success(found)
            } catch {
                return .failure(error)
            }
        }) {
            return try contiguous.get()
        }

        // Đường 2: quét theo cửa sổ, bắt đầu từ ĐẦU DÒNG chứa `offset`.
        let line = buffer.lineNumber(atOffset: Swift.min(offset, Swift.max(buffer.count - 1, 0)))
        var windowStart = buffer.offset(ofLineStart: line)

        while windowStart < buffer.count {
            try cancelToken.check()
            let windowEnd = lineAlignedEnd(from: windowStart, in: buffer)
            let bytes = buffer.bytes(in: windowStart ..< windowEnd)

            var found: SearchMatch?
            try bytes.withUnsafeBytes { region in
                try pattern.enumerateMatches(in: region, cancelToken: cancelToken) { match in
                    let absolute = shift(match, by: windowStart)
                    guard absolute.range.lowerBound >= offset else { return true }
                    found = absolute
                    return false
                }
            }
            if let found { return found }
            if windowEnd >= buffer.count { return nil }

            // Biên kế tiếp phải TIẾN, luôn luôn — cùng cái bẫy đã làm treo test 10 phút ở `find`.
            var next = lineAlignedStart(before: windowEnd, in: buffer, back: overlap)
            if next <= windowStart { next = Swift.max(windowEnd - overlap, windowStart + 1) }
            if next <= windowStart { next = windowEnd }
            windowStart = next
        }
        return nil
    }

    /// Kế hoạch thay thế trên cả tài liệu, cũng không dựng cả tài liệu.
    ///
    /// Cùng hai đường và cùng giới hạn như `find`. Offset trong kế hoạch là offset TÀI LIỆU,
    /// nên chỗ gọi áp thẳng bằng `applyEdits` và vẫn là MỘT bước undo (FR-CORE-004).
    public static func replacementEdits(
        pattern: PCRE2Pattern,
        template: String,
        in buffer: TextBuffer,
        limit: Int = 0,
        cancelToken: CancelToken = CancelToken()
    ) throws -> ReplacementPlan {
        guard buffer.count > 0 else {
            return ReplacementPlan(edits: [], matchCount: 0, truncated: false, byteDelta: 0)
        }

        if let plan = try buffer.withContiguousBytes({ region -> Result<ReplacementPlan, Error> in
            do {
                return .success(try pattern.replacementEdits(
                    in: region, template: template, limit: limit, cancelToken: cancelToken
                ))
            } catch {
                return .failure(error)
            }
        }) {
            return try plan.get()
        }

        var edits: [TextEdit] = []
        var matchCount = 0
        var byteDelta = 0
        var truncated = false
        var windowStart = 0
        var reported = 0

        while windowStart < buffer.count {
            try cancelToken.check()

            let windowEnd = lineAlignedEnd(from: windowStart, in: buffer)
            let bytes = buffer.bytes(in: windowStart ..< windowEnd)
            let plan = try bytes.withUnsafeBytes {
                try pattern.replacementEdits(
                    in: $0, template: template,
                    limit: limit > 0 ? limit - matchCount : 0,
                    cancelToken: cancelToken
                )
            }

            for edit in plan.edits {
                let lower = edit.range.lowerBound + windowStart
                // Bỏ những sửa đổi đã sinh ra ở cửa sổ trước — phần chồng khiến chúng xuất
                // hiện hai lần, và áp hai lần là hỏng nội dung chứ không chỉ thừa.
                guard lower >= reported else { continue }
                let upper = edit.range.upperBound + windowStart
                edits.append(TextEdit(range: lower ..< upper, bytes: edit.bytes))
                byteDelta += edit.bytes.count - (upper - lower)
                matchCount += 1
                reported = lower + 1
            }
            truncated = truncated || plan.truncated

            if limit > 0, matchCount >= limit { truncated = true; break }
            if windowEnd >= buffer.count { break }

            var next = lineAlignedStart(before: windowEnd, in: buffer, back: overlap)
            if next <= windowStart { next = Swift.max(windowEnd - overlap, windowStart + 1) }
            if next <= windowStart { next = windowEnd }
            windowStart = next
        }

        return ReplacementPlan(
            edits: edits, matchCount: matchCount, truncated: truncated, byteDelta: byteDelta
        )
    }

    /// Biên cuối cửa sổ, lùi về đầu dòng gần nhất.
    private static func lineAlignedEnd(from start: Int, in buffer: TextBuffer) -> Int {
        let raw = Swift.min(buffer.count, start + windowSize)
        guard raw < buffer.count else { return buffer.count }
        let line = buffer.lineNumber(atOffset: raw)
        let aligned = buffer.offset(ofLineStart: line)
        // Dòng dài hơn cả cửa sổ: không lùi được thì lấy nguyên, thà cắt giữa dòng còn hơn
        // vòng lặp không tiến.
        return aligned > start ? aligned : raw
    }

    /// Biên đầu cửa sổ kế tiếp: lùi `back` byte rồi về đầu dòng.
    private static func lineAlignedStart(before end: Int, in buffer: TextBuffer, back: Int) -> Int {
        let raw = Swift.max(0, end - back)
        let line = buffer.lineNumber(atOffset: raw)
        let aligned = buffer.offset(ofLineStart: line)
        // Phải TIẾN được: nếu phần chồng đẩy ta về đúng chỗ cũ thì vòng lặp đứng im.
        return aligned < end ? Swift.max(aligned, 0) : end
    }
}

public extension TextBuffer {

    /// Chạy `body` trên toàn bộ nội dung nếu nó nằm liên tục trong bộ nhớ; `nil` nếu không.
    ///
    /// `nil` KHÔNG phải lỗi — nó có nghĩa "tài liệu đã phân mảnh, hãy đi đường khác". Trả
    /// `nil` thay vì tự sao chép để chỗ gọi không vô tình cấp phát cả tài liệu mà không biết.
    func withContiguousBytes<T>(_ body: (UnsafeRawBufferPointer) -> T) -> T? {
        guard pieceCount == 1 else { return nil }
        var result: T?
        var chunks = 0
        forEachChunk { chunk in
            chunks += 1
            // Vẫn kiểm số đoạn: `pieceCount == 1` là điều kiện cần, nhưng đoạn rỗng hay cách
            // dựng cây đổi trong tương lai đều có thể phá giả định, và sai ở đây là khớp trên
            // một phần tài liệu rồi báo "không tìm thấy".
            if chunks == 1, chunk.count == count { result = body(chunk) }
        }
        return chunks == 1 ? result : nil
    }
}
