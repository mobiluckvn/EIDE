import Foundation
import TreeSitter

/// PoC-D — tô màu cú pháp bằng tree-sitter (SAD §8, ADR-04, FR-FMT-501).
///
/// SAD đã chốt hướng ở mức kiến trúc: tree-sitter chính, tmLanguage dự phòng. Việc của PoC
/// này KHÔNG phải chọn lại engine mà là trả lời câu hỏi riêng của GEditor, thứ SAD không thể
/// biết trước:
///
/// > Lớp hiển thị chỉ giữ 2 MB quanh chỗ đang xem (ADR-01). tree-sitter thì phân tích CẢ
/// > tài liệu. Hai điều đó gặp nhau thế nào trên một file hàng Gigabyte?
///
/// Ba khả năng, và PoC đo để loại bớt:
///
/// 1. **Phân tích cả tài liệu.** Đúng cú pháp tuyệt đối, nhưng tốn bao nhiêu thời gian và bao
///    nhiêu bộ nhớ ở 64 MB? ở 1 GB?
/// 2. **Chỉ phân tích cửa sổ 2 MB.** Rẻ, nhưng SAI ở đâu và sai bao nhiêu? Một chú thích
///    `/* */` mở ra trước cửa sổ sẽ làm cả cửa sổ hiểu nhầm.
/// 3. **Ngưỡng**: dưới cỡ nào thì làm cách 1, trên cỡ ấy thì đổi cách.
///
/// Số đo đi vào `docs/adr/ADR-04-syntax-highlighting.md`.
enum PoCD {

    struct Report: Encodable {
        let treeSitterVersion: Int
        let languages: [String]
        let fullParse: [ParseSample]
        let incremental: [IncrementalSample]
        let highlight: [HighlightSample]
        let windowAccuracy: [WindowSample]
        let margin: [MarginSample]
        let notes: [String]
    }

    struct ParseSample: Encodable {
        let language: String
        let megabytes: Int
        let parseMilliseconds: Double
        let bytesPerSecond: Double
    }

    /// Bộ nhớ cây, đo trong MỘT TIẾN TRÌNH RIÊNG.
    ///
    /// Không đo bằng hiệu số `phys_footprint` giữa hai lần trong cùng một tiến trình. Đó đúng
    /// là cái bẫy PoC-A đã ghi lại: phép đo thứ hai dùng lại vùng nhớ mà phép đo thứ nhất vừa
    /// trả, nên nó báo con số nhỏ hơn thật — bản đầu của PoC này báo "cây C tốn 0,0 MB", một
    /// con số vô lý mà vẫn suýt được ghi vào ADR.
    struct MemorySample: Encodable {
        let language: String
        let megabytes: Int
        let footprintBeforeMB: Double
        let footprintAfterMB: Double
        let treeMB: Double
        /// Cây nặng gấp bao nhiêu lần chính văn bản — con số phải so với trần 1,5× của
        /// NFR-PERF-05.
        let treeTimesSource: Double
    }

    struct IncrementalSample: Encodable {
        let language: String
        let megabytes: Int
        /// Phân tích lại sau khi sửa MỘT ký tự — đây là con số quyết định gõ có mượt không.
        let reparseMillisecondsP50: Double
        let reparseMillisecondsP95: Double
    }

    struct HighlightSample: Encodable {
        let language: String
        let megabytes: Int
        /// Chạy truy vấn tô màu trên đúng phần NHÌN THẤY (một màn hình ~100 dòng).
        let visibleQueryMilliseconds: Double
        let capturesInViewport: Int
    }

    struct WindowSample: Encodable {
        let language: String
        /// Chỗ cắt được chọn thế nào — hai chỗ cắt trả lời hai câu khác nhau.
        let cutKind: String
        /// Cắt một lát 2 MB rồi phân tích riêng, so với kết quả phân tích cả file.
        let sliceMegabytes: Int
        let capturesFromFullParse: Int
        let capturesFromSliceParse: Int
        let mismatchedCaptures: Int
        let mismatchPercent: Double
        /// Chú thích/chuỗi đang MỞ tại chỗ cắt — nguyên nhân gốc của sai lệch.
        let cutInsideMultilineConstruct: Bool
        /// Chỗ sai XA NHẤT tính từ đầu lát, theo byte.
        ///
        /// Đây mới là con số quyết định, không phải phần trăm. Phần trăm tính trên cả lát 2 MB
        /// nên nó luôn nhỏ và luôn nghe êm tai; còn cái người dùng thấy là mấy trăm chỗ tô sai
        /// nằm NGAY ĐẦU cửa sổ, đúng chỗ họ vừa cuộn tới. Nếu hỏng chỉ lan vài KB thì cách sửa
        /// là phân tích thêm một đoạn ĐỆM phía trước rồi bỏ phần đệm đi — và con số này nói
        /// đoạn đệm phải dài bao nhiêu.
        let damageExtentBytes: Int
        let damageExtentPercentOfSlice: Double
        /// Chỗ sai nằm ở ĐÂU trong lát: 64 KB đầu, 64 KB cuối, hay ở giữa.
        ///
        /// "Lan tới cuối lát" nghe như hỏng khắp nơi, nhưng 252 chỗ rải trên 2 MB thì rất
        /// thưa. Phân bố mới nói được cách sửa: dồn ở HAI ĐẦU thì thêm đoạn đệm hai phía rồi
        /// bỏ phần đệm là xong; rải đều ở GIỮA thì cách "chỉ phân tích cửa sổ" hỏng tận gốc.
        let mismatchesInFirst64KB: Int
        let mismatchesInLast64KB: Int
        let mismatchesInMiddle: Int
    }

    /// Lề bao nhiêu thì đủ — đo ĐÚNG cái sản phẩm làm (ADR-04 §3).
    ///
    /// Khác `WindowSample`: phép kia cắt một lát rời ra phân tích riêng (lề = 0) để xem hỏng
    /// ở đâu. Phép này phân tích **vùng + lề** rồi chỉ hỏi phần giữa, tức là đúng đường của
    /// `SyntaxHighlighter`. Nó trả lời câu duy nhất còn lại: 64 KB có đủ không, và đủ cho
    /// những ngôn ngữ nào.
    struct MarginSample: Encodable {
        let language: String
        let marginKB: Int
        let contentKB: Int
        let capturesExpected: Int
        let capturesGot: Int
        let mismatched: Int
        let mismatchPercent: Double
        /// Cây phân tích CẢ FILE có nút lỗi không.
        ///
        /// Không đoán "chắc là do bộ quét": `ts_node_has_error` là câu trả lời của chính
        /// tree-sitter. Hai cờ này phân biệt được hai kiểu hỏng hoàn toàn khác nhau — cả file
        /// hỏng, hay lát cắt hỏng — mà con số "lệch bao nhiêu" không phân biệt nổi.
        let fullParseHasError: Bool
        let sliceParseHasError: Bool
        /// Truy vấn có ÂM THẦM bỏ bớt kết quả vì chạm trần số khớp không.
        ///
        /// `ts_query_cursor_did_exceed_match_limit` — nếu đúng, con số capture trả về là số
        /// CỤT chứ không phải số thật, và mọi so sánh dựa trên nó đều vô nghĩa. Đây là kiểu
        /// hỏng tệ nhất: không lỗi, không cảnh báo, chỉ thiếu.
        let fullQueryExceededLimit: Bool
        let sliceQueryExceededLimit: Bool
    }

    // MARK: - Chạy

    static func run(megabytes: [Int], sliceMegabytes: Int) -> Report {
        var fullParse: [ParseSample] = []
        var incremental: [IncrementalSample] = []
        var highlight: [HighlightSample] = []
        var windowAccuracy: [WindowSample] = []

        for language in Language.all {
            for size in megabytes {
                let source = language.fixture(megabytes: size)
                source.withUnsafeBufferPointer { bytes in
                    let base = bytes.baseAddress!

                    // 1. Phân tích cả tài liệu.
                    let parser = ts_parser_new()!
                    defer { ts_parser_delete(parser) }
                    ts_parser_set_language(parser, language.handle)

                    var tree: OpaquePointer?
                    let parseMs = Measure.milliseconds {
                        tree = ts_parser_parse_string(parser, nil, base, UInt32(bytes.count))
                    }
                    guard let tree else { return }

                    // Bộ nhớ KHÔNG đo ở đây — xem `measureMemory` và `scripts/run-poc-d.sh`.
                    fullParse.append(ParseSample(
                        language: language.name,
                        megabytes: size,
                        parseMilliseconds: parseMs,
                        bytesPerSecond: parseMs > 0 ? Double(bytes.count) / (parseMs / 1000) : 0
                    ))

                    // 2. Sửa MỘT ký tự rồi phân tích lại.
                    incremental.append(measureIncremental(
                        language: language, size: size, parser: parser, tree: tree, bytes: bytes
                    ))

                    // 3. Truy vấn tô màu trên một màn hình.
                    highlight.append(measureHighlight(
                        language: language, size: size, tree: tree, bytes: bytes
                    ))

                    ts_tree_delete(tree)
                }
            }

            windowAccuracy.append(contentsOf: measureWindowAccuracy(
                language: language, sliceMegabytes: sliceMegabytes
            ))
        }

        var margin: [MarginSample] = []
        for language in Language.all {
            margin.append(contentsOf: measureMargin(language: language))
        }

        return Report(
            treeSitterVersion: Int(TREE_SITTER_LANGUAGE_VERSION),
            languages: Language.all.map(\.name),
            fullParse: fullParse,
            incremental: incremental,
            highlight: highlight,
            windowAccuracy: windowAccuracy,
            margin: margin,
            notes: [
                "parseMilliseconds: phân tích CẢ tài liệu, cây dựng từ đầu.",
                "reparse: sửa một ký tự ở GIỮA tài liệu rồi ts_parser_parse lại với cây cũ.",
                "visibleQuery: chạy truy vấn highlights.scm giới hạn theo byte range của một màn hình.",
                "windowAccuracy: cắt một lát ở giữa file theo biên dòng rồi phân tích riêng, "
                    + "so số capture với phần tương ứng của cây phân tích cả file.",
                "margin: phân tích VÙNG + LỀ rồi chỉ hỏi phần giữa — đúng đường của "
                    + "SyntaxHighlighter. Đây là phép quyết định lề 64 KB có đủ không.",
            ]
        )
    }

    /// Một phép đo bộ nhớ duy nhất cho một tiến trình. In ra JSON rồi thoát.
    static func measureMemory(languageName: String, megabytes: Int) -> MemorySample? {
        guard let language = Language.all.first(where: { $0.name == languageName }) else { return nil }
        let source = language.fixture(megabytes: megabytes)

        // Đo SAU khi đã dựng xong dữ liệu thử: cái cần biết là cây tốn thêm bao nhiêu, không
        // phải văn bản tốn bao nhiêu.
        let before = ProcessMemory.footprintBytes()
        return source.withUnsafeBufferPointer { bytes -> MemorySample? in
            let parser = ts_parser_new()!
            defer { ts_parser_delete(parser) }
            ts_parser_set_language(parser, language.handle)
            guard let tree = ts_parser_parse_string(
                parser, nil, bytes.baseAddress!, UInt32(bytes.count)
            ) else { return nil }
            let after = ProcessMemory.footprintBytes()
            // Giữ cây SỐNG cho tới sau khi đo — thả sớm thì đo ra bộ nhớ đã trả lại.
            defer { ts_tree_delete(tree) }

            let treeBytes = Double(max(0, after - before))
            return MemorySample(
                language: languageName,
                megabytes: megabytes,
                footprintBeforeMB: Double(before) / 1_048_576,
                footprintAfterMB: Double(after) / 1_048_576,
                treeMB: treeBytes / 1_048_576,
                treeTimesSource: treeBytes / Double(max(bytes.count, 1))
            )
        }
    }

    // MARK: - Từng phép đo

    private static func measureIncremental(
        language: Language, size: Int, parser: OpaquePointer,
        tree: OpaquePointer, bytes: UnsafeBufferPointer<UInt8>
    ) -> IncrementalSample {
        // Sửa ở GIỮA tài liệu, không ở đầu: sửa ở đầu thì tree-sitter phải dựng lại gần hết
        // cây, và con số đo được là trường hợp xấu nhất chứ không phải trường hợp thường.
        //
        // GIỮ LẠI mọi ký tự đã chèn. Bản đầu chèn rồi xoá ngay khỏi mảng mà KHÔNG báo phép
        // xoá cho cây: cây và văn bản lệch nhau ngay từ vòng thứ hai, nên mỗi vòng sau đó
        // thành phân tích lại TỪ ĐẦU. Số đo ra 853 ms cho JSON 8 MB — nghe như tree-sitter
        // không tăng dần được, sự thật là phép đo tự phá chính nó.
        var samples: [Double] = []
        var current = tree
        var mutable = Array(bytes)
        var position = mutable.count / 2

        for round in 0 ..< 20 {
            let character = UInt8(ascii: round % 2 == 0 ? " " : "\t")
            mutable.insert(character, at: position)

            var edit = TSInputEdit(
                start_byte: UInt32(position),
                old_end_byte: UInt32(position),
                new_end_byte: UInt32(position + 1),
                start_point: TSPoint(row: 0, column: 0),
                old_end_point: TSPoint(row: 0, column: 0),
                new_end_point: TSPoint(row: 0, column: 0)
            )
            ts_tree_edit(current, &edit)

            var next: OpaquePointer?
            let ms = mutable.withUnsafeBufferPointer { updated -> Double in
                Measure.milliseconds {
                    next = ts_parser_parse_string(
                        parser, current, updated.baseAddress!, UInt32(updated.count)
                    )
                }
            }
            if current != tree { ts_tree_delete(current) }
            current = next!
            samples.append(ms)
            position += 1
        }
        if current != tree { ts_tree_delete(current) }

        return IncrementalSample(
            language: language.name,
            megabytes: size,
            reparseMillisecondsP50: Measure.median(samples),
            reparseMillisecondsP95: Measure.percentile(samples, 0.95)
        )
    }

    private static func measureHighlight(
        language: Language, size: Int, tree: OpaquePointer, bytes: UnsafeBufferPointer<UInt8>
    ) -> HighlightSample {
        guard let query = language.highlightQuery else {
            return HighlightSample(language: language.name, megabytes: size,
                                   visibleQueryMilliseconds: -1, capturesInViewport: 0)
        }
        // Một màn hình: lấy 8 KB ở giữa tài liệu — cỡ khoảng 100 dòng mã nguồn.
        let start = UInt32(bytes.count / 2)
        let end = UInt32(min(bytes.count, bytes.count / 2 + 8_192))

        var count = 0
        let ms = Measure.milliseconds {
            let cursor = ts_query_cursor_new()!
            defer { ts_query_cursor_delete(cursor) }
            ts_query_cursor_set_byte_range(cursor, start, end)
            ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree))

            var match = TSQueryMatch()
            var captureIndex: UInt32 = 0
            while ts_query_cursor_next_capture(cursor, &match, &captureIndex) {
                count += 1
            }
        }
        return HighlightSample(language: language.name, megabytes: size,
                               visibleQueryMilliseconds: ms, capturesInViewport: count)
    }

    /// Câu hỏi trung tâm: chỉ phân tích CỬA SỔ thì sai bao nhiêu?
    ///
    /// Đo HAI chỗ cắt, vì chúng trả lời hai câu khác nhau:
    ///
    /// - **Cắt tự nhiên** (giữa file, theo biên dòng) — đây là chuyện xảy ra hằng ngày.
    /// - **Cắt ép vào giữa một khối `/* */`** — trường hợp xấu nhất, và là thứ quyết định
    ///   xem cách "chỉ phân tích cửa sổ" có dùng được hay không.
    ///
    /// Không tự KHAI "chỗ cắt nằm trong cấu trúc nhiều dòng" như bản đầu: đó là hằng số tôi
    /// tự viết ra, không phải thứ đo được. Giờ chỗ cắt được TÌM, và nếu không tìm thấy thì
    /// nói thẳng là không tìm thấy.
    private static func measureWindowAccuracy(
        language: Language, sliceMegabytes: Int
    ) -> [WindowSample] {
        let source = language.fixture(megabytes: max(sliceMegabytes * 4, 8))
        let sliceBytes = sliceMegabytes * 1_048_576

        var results: [WindowSample] = []

        // (a) Cắt tự nhiên: giữa file, lùi về biên dòng — đúng như `TextWindowing` làm.
        var natural = source.count / 2
        while natural > 0, source[natural - 1] != UInt8(ascii: "\n") { natural -= 1 }
        results.append(sample(
            language: language, source: source, start: natural,
            sliceBytes: sliceBytes, cutKind: "biên dòng giữa file",
            insideBlock: isInsideBlockComment(source, offset: natural)
        ))

        // (b) Cắt ép vào GIỮA một khối chú thích, nếu ngôn ngữ có.
        if let forced = firstOffsetInsideBlockComment(source, after: source.count / 4) {
            var aligned = forced
            while aligned > 0, source[aligned - 1] != UInt8(ascii: "\n") { aligned -= 1 }
            results.append(sample(
                language: language, source: source, start: aligned,
                sliceBytes: sliceBytes, cutKind: "GIỮA khối chú thích",
                insideBlock: true
            ))
        }
        return results
    }

    private static func sample(
        language: Language, source: [UInt8], start: Int, sliceBytes: Int,
        cutKind: String, insideBlock: Bool
    ) -> WindowSample {
        var end = min(source.count, start + sliceBytes)
        while end > start, end < source.count, source[end - 1] != UInt8(ascii: "\n") { end -= 1 }

        let fullCaptures = captures(language: language, bytes: source, range: start ..< end)
        let slice = Array(source[start ..< end])
        let sliceCaptures = captures(language: language, bytes: slice, range: 0 ..< slice.count)
            .map { ($0.0 + start, $0.1 + start) }

        let fullSet = Set(fullCaptures.map { "\($0.0)-\($0.1)" })
        let sliceSet = Set(sliceCaptures.map { "\($0.0)-\($0.1)" })
        let differences = fullSet.symmetricDifference(sliceSet)
        let mismatched = differences.count

        // Chỗ sai xa nhất, tính từ đầu lát.
        let offsets = differences.compactMap { key -> Int? in
            Int(key.split(separator: "-").first.map(String.init) ?? "").map { $0 - start }
        }
        let farthest = offsets.max() ?? 0
        let length = max(end - start, 1)
        let edge = 64 * 1024
        let head = offsets.filter { $0 < edge }.count
        let tail = offsets.filter { $0 >= length - edge }.count

        return WindowSample(
            language: language.name,
            cutKind: cutKind,
            sliceMegabytes: (end - start) / 1_048_576,
            capturesFromFullParse: fullSet.count,
            capturesFromSliceParse: sliceSet.count,
            mismatchedCaptures: mismatched,
            mismatchPercent: Double(mismatched) * 100 / Double(max(fullSet.count, 1)),
            cutInsideMultilineConstruct: insideBlock,
            damageExtentBytes: farthest,
            damageExtentPercentOfSlice: Double(farthest) * 100 / Double(length),
            mismatchesInFirst64KB: head,
            mismatchesInLast64KB: tail,
            mismatchesInMiddle: max(0, offsets.count - head - tail)
        )
    }

    /// Offset này có nằm trong một khối `/* … */` đang mở không.
    private static func isInsideBlockComment(_ bytes: [UInt8], offset: Int) -> Bool {
        var open = false
        var index = 0
        while index + 1 < offset {
            if bytes[index] == UInt8(ascii: "/"), bytes[index + 1] == UInt8(ascii: "*") {
                open = true
                index += 2
                continue
            }
            if open, bytes[index] == UInt8(ascii: "*"), bytes[index + 1] == UInt8(ascii: "/") {
                open = false
                index += 2
                continue
            }
            index += 1
        }
        return open
    }

    private static func firstOffsetInsideBlockComment(_ bytes: [UInt8], after: Int) -> Int? {
        var index = after
        while index + 1 < bytes.count {
            if bytes[index] == UInt8(ascii: "/"), bytes[index + 1] == UInt8(ascii: "*") {
                // Vào SÂU trong khối, không đứng ngay sau dấu mở: đứng ngay sau thì lát cắt
                // theo biên dòng sẽ lùi về trước dấu mở và chẳng ép được gì.
                var inside = index + 2
                var newlines = 0
                while inside + 1 < bytes.count, newlines < 5 {
                    if bytes[inside] == UInt8(ascii: "\n") { newlines += 1 }
                    if bytes[inside] == UInt8(ascii: "*"), bytes[inside + 1] == UInt8(ascii: "/") {
                        return nil   // khối quá ngắn, thử khối khác
                    }
                    inside += 1
                }
                return inside
            }
            index += 1
        }
        return nil
    }

    /// Với mỗi cỡ lề, đo xem phần GIỮA có khớp với kết quả phân tích cả file không.
    private static func measureMargin(language: Language) -> [MarginSample] {
        let source = language.fixture(megabytes: 4)

        // Vùng cần tô: 256 KB ở giữa file, cắt theo biên dòng.
        var start = source.count / 2
        while start > 0, source[start - 1] != UInt8(ascii: "\n") { start -= 1 }
        var end = min(source.count, start + 256 * 1024)
        while end > start, end < source.count, source[end - 1] != UInt8(ascii: "\n") { end -= 1 }

        let (expectedList, fullExceeded) = capturesAndLimit(
            language: language, bytes: source, range: start ..< end
        )
        let expected = Set(expectedList.map { "\($0.0)-\($0.1)" })
        let fullHasError = hasError(language: language, bytes: source)

        return [0, 16, 64, 256].map { marginKB -> MarginSample in
            let margin = marginKB * 1024
            var scopeStart = max(0, start - margin)
            while scopeStart > 0, source[scopeStart - 1] != UInt8(ascii: "\n") { scopeStart -= 1 }
            var scopeEnd = min(source.count, end + margin)
            while scopeEnd > end, scopeEnd < source.count,
                  source[scopeEnd - 1] != UInt8(ascii: "\n") { scopeEnd -= 1 }

            let slice = Array(source[scopeStart ..< scopeEnd])
            let (gotList, sliceExceeded) = capturesAndLimit(
                language: language, bytes: slice,
                range: (start - scopeStart) ..< (end - scopeStart)
            )
            let got = Set(gotList.map { "\($0.0 + scopeStart)-\($0.1 + scopeStart)" })
            let mismatched = expected.symmetricDifference(got).count
            let sliceHasError = hasError(language: language, bytes: slice)
            return MarginSample(
                language: language.name,
                marginKB: marginKB,
                contentKB: (end - start) / 1024,
                capturesExpected: expected.count,
                capturesGot: got.count,
                mismatched: mismatched,
                mismatchPercent: Double(mismatched) * 100 / Double(max(expected.count, 1)),
                fullParseHasError: fullHasError,
                sliceParseHasError: sliceHasError,
                fullQueryExceededLimit: fullExceeded,
                sliceQueryExceededLimit: sliceExceeded
            )
        }
    }

    /// Cây phân tích có nút lỗi không — câu trả lời của chính tree-sitter.
    private static func hasError(language: Language, bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBufferPointer { buffer -> Bool in
            let parser = ts_parser_new()!
            defer { ts_parser_delete(parser) }
            ts_parser_set_language(parser, language.handle)
            guard let tree = ts_parser_parse_string(
                parser, nil, buffer.baseAddress!, UInt32(buffer.count)
            ) else { return true }
            defer { ts_tree_delete(tree) }
            return ts_node_has_error(ts_tree_root_node(tree))
        }
    }

    private static func captures(
        language: Language, bytes: [UInt8], range: Range<Int>
    ) -> [(Int, Int)] {
        capturesAndLimit(language: language, bytes: bytes, range: range).0
    }

    private static func capturesAndLimit(
        language: Language, bytes: [UInt8], range: Range<Int>
    ) -> ([(Int, Int)], Bool) {
        guard let query = language.highlightQuery else { return ([], false) }
        return bytes.withUnsafeBufferPointer { buffer -> ([(Int, Int)], Bool) in
            let parser = ts_parser_new()!
            defer { ts_parser_delete(parser) }
            ts_parser_set_language(parser, language.handle)
            guard let tree = ts_parser_parse_string(
                parser, nil, buffer.baseAddress!, UInt32(buffer.count)
            ) else { return ([], false) }
            defer { ts_tree_delete(tree) }

            let cursor = ts_query_cursor_new()!
            defer { ts_query_cursor_delete(cursor) }
            ts_query_cursor_set_byte_range(cursor, UInt32(range.lowerBound), UInt32(range.upperBound))
            ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree))

            var found: [(Int, Int)] = []
            var match = TSQueryMatch()
            var captureIndex: UInt32 = 0
            while ts_query_cursor_next_capture(cursor, &match, &captureIndex) {
                let capture = match.captures[Int(captureIndex)]
                found.append((Int(ts_node_start_byte(capture.node)), Int(ts_node_end_byte(capture.node))))
            }
            return (found, ts_query_cursor_did_exceed_match_limit(cursor))
        }
    }
}
