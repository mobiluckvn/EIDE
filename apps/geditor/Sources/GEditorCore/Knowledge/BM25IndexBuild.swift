import Foundation

// MARK: - Varint

/// Số nguyên không dấu, 7 bit mỗi byte, bit cao báo "còn nữa".
///
/// Dùng ở mọi chỗ trong khối posting. Chênh lệch không nhỏ: số hiệu tài liệu ghi dạng HIỆU liên
/// tiếp nên phần lớn nằm dưới 128, tức **một byte** thay vì bốn. Trên 120 triệu posting, đó là
/// khác biệt giữa một tệp chỉ mục 1 GB và một tệp 250 MB — và tệp nhỏ hơn cũng là tệp đọc nhanh
/// hơn, vì phần lớn thời gian truy vấn là đọc đĩa chứ không phải tính toán.
func appendVarint(_ value: Int, to bytes: inout [UInt8]) {
    var remaining = UInt64(max(0, value))
    while remaining >= 0x80 {
        bytes.append(UInt8(remaining & 0x7f) | 0x80)
        remaining >>= 7
    }
    bytes.append(UInt8(remaining))
}

/// Số byte mà `appendVarint` sẽ ghi — để đếm ngân sách khối mà không phải đo mảng.
func varintLength(_ value: Int) -> Int {
    var remaining = UInt64(max(0, value))
    var count = 1
    while remaining >= 0x80 {
        remaining >>= 7
        count += 1
    }
    return count
}

func readVarint(_ bytes: [UInt8], _ cursor: inout Int) -> Int {
    var result: UInt64 = 0
    var shift: UInt64 = 0
    while cursor < bytes.count {
        let byte = bytes[cursor]
        cursor += 1
        result |= UInt64(byte & 0x7f) << shift
        if byte & 0x80 == 0 { break }
        shift += 7
    }
    return Int(result)
}

/// Posting của MỘT từ khoá trong khối đang gom.
struct TermBlock {
    var payload: [UInt8] = []
    /// Tài liệu cuối đã ghi vào `payload`. `-1` = chưa có gì.
    var lastDocument: Int32 = -1

    /// Sửa tại chỗ. Có mặt để chỗ gọi làm mọi việc trong MỘT lần truy cập từ điển.
    mutating func with(_ body: (inout TermBlock) -> Void) { body(&self) }
}

extension BM25Index {

    // MARK: - Dựng

    /// Dựng chỉ mục cho một corpus JSONL và ghi ra `<corpus>.bm25idx`.
    ///
    /// - Parameter progress: gọi lại với số byte đã đọc / tổng số byte. Trả `false` để HỦY.
    public static func build(
        corpus path: String, options: Options = Options(),
        progress: ((Double) -> Bool)? = nil
    ) throws -> BM25Index {
        let started = DispatchTime.now().uptimeNanoseconds
        var stats = BuildStats()
        func mark() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
        func since(_ t: UInt64) -> Double {
            Double(DispatchTime.now().uptimeNanoseconds - t) / 1_000_000
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let totalBytes = attributes[.size] as? Int else {
            throw Failure(message: "không đọc được corpus \(path)")
        }
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw Failure(message: "không mở được corpus \(path)")
        }
        defer { try? handle.close() }

        let work = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: path), create: true)
        defer { try? FileManager.default.removeItem(at: work) }

        var runs: [URL] = []
        // Khối đang gom: từ khoá → (posting đã mã hoá varint, tài liệu cuối đã ghi).
        //
        // MỘT từ điển chứ không hai. Bản trước giữ `block` và `lastDocumentOfTerm` riêng, nên
        // mỗi cặp (tài liệu, từ khoá) tốn **bốn lần băm chuỗi**; bộ lấy mẫu đo được thao tác
        // `Dictionary` chiếm **66%** cả lượt dựng. Gộp lại còn một lần băm.
        var block: [String: TermBlock] = [:]
        var blockBytes = 0

        var documentLengths: [Int32] = []
        var recordOffsets: [Int] = [0]
        var totalTokens = 0
        var offset = 0
        var leftover: [UInt8] = []
        var cancelled = false

        func flushBlock() throws {
            guard !block.isEmpty else { return }
            let flushStart = mark()
            defer { stats.flushMs += since(flushStart) }
            // Ghi run đã SẮP theo từ khoá: bước trộn về sau chỉ cần đọc tuần tự k đường.
            var bytes: [UInt8] = []
            bytes.reserveCapacity(blockBytes + block.count * 16)
            for term in block.keys.sorted() {
                let payload = block[term]!.payload
                let utf8 = Array(term.utf8)
                appendVarint(utf8.count, to: &bytes)
                bytes.append(contentsOf: utf8)
                appendVarint(payload.count, to: &bytes)
                bytes.append(contentsOf: payload)
            }
            let url = work.appendingPathComponent("run-\(runs.count).bin")
            try Data(bytes).write(to: url, options: .atomic)
            runs.append(url)
            block.removeAll(keepingCapacity: true)
            blockBytes = 0
        }

        // --- Quét corpus theo khối 8 MB --------------------------------------------------
        //
        // Làm việc trên `[UInt8]` và tìm xuống dòng bằng `memchr`, KHÔNG duyệt `Data` theo byte.
        //
        // Bản đầu viết `data[start...].firstIndex(of: 0x0A)` — đọc thì rõ ràng, chạy thì thảm
        // hoạ: truy cập từng byte của một lát `Data` đi qua đường generic của `Collection`, và
        // PoC-M đo được **24,4 giây trên 200 MB nằm NGOÀI mọi chặng đã đo** (phân tích JSON,
        // tách token, ghi posting cộng lại chỉ 95 ms). Nếu không có bảng chặng ấy thì kết luận
        // hiển nhiên sẽ là "BM25 chậm" và ta đã đi tối ưu nhầm chỗ.
        while true {
            let readStart = mark()
            let chunk = try handle.read(upToCount: 8 << 20)
            stats.readMs += since(readStart)
            guard let chunk, !chunk.isEmpty else { break }
            let splitStart = mark()
            var data = leftover
            data.append(contentsOf: chunk)
            stats.splitMs += since(splitStart)
            var start = 0
            data.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                while start < buffer.count {
                    guard let found = memchr(base + start, 0x0A, buffer.count - start) else {
                        break
                    }
                    let newline = base.distance(to: found.assumingMemoryBound(to: UInt8.self))
                    let line = UnsafeBufferPointer(
                        start: base + start, count: newline - start)
                    offset += line.count + 1
                    recordOffsets.append(offset)
                    let recordStart = DispatchTime.now().uptimeNanoseconds
                    defer {
                        stats.recordMs += Double(
                            DispatchTime.now().uptimeNanoseconds - recordStart) / 1_000_000
                    }
                    indexRecord(line: line, into: &block, blockBytes: &blockBytes,
                          documentLengths: &documentLengths, totalTokens: &totalTokens,
                          options: options)
                    start = newline + 1
                }
            }
            if blockBytes >= options.blockBudget { try flushBlock() }
            leftover = Array(data[start...])
            if let progress, !progress(Double(offset) / Double(max(1, totalBytes))) {
                cancelled = true
                break
            }
        }
        if !cancelled, !leftover.isEmpty {
            // Dòng cuối KHÔNG kết thúc bằng xuống dòng vẫn là một bản ghi.
            offset += leftover.count
            recordOffsets.append(offset)
            leftover.withUnsafeBufferPointer { buffer in
                indexRecord(line: buffer, into: &block, blockBytes: &blockBytes,
                      documentLengths: &documentLengths, totalTokens: &totalTokens,
                      options: options)
            }
        }
        guard !cancelled else { throw Failure(message: "đã hủy") }
        try flushBlock()

        // --- Trộn k đường ------------------------------------------------------------------
        let mergeStart = mark()
        let merged = try merge(runs: runs)
        stats.mergeMs = since(mergeStart)

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        let manifest = Manifest(
            version: Manifest.currentVersion,
            corpus: (path as NSString).lastPathComponent,
            corpusBytes: totalBytes,
            corpusModified: (attributes[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? 0,
            textField: options.textField, idField: options.idField,
            tokenizer: BM25Tokenizer.name,
            foldDiacritics: options.tokenizer.foldDiacritics,
            k1: options.k1, b: options.b,
            documentCount: documentLengths.count,
            totalTokens: totalTokens,
            averageLength: documentLengths.isEmpty
                ? 0 : Double(totalTokens) / Double(documentLengths.count),
            termCount: merged.dictionary.count,
            buildMilliseconds: elapsed)

        let index = BM25Index(
            manifest: manifest, options: options, corpusPath: path,
            recordOffsets: recordOffsets, documentLengths: documentLengths,
            dictionary: merged.dictionary, postings: merged.postings)
        let writeStart = mark()
        try index.write(to: indexPath(for: path))
        stats.writeMs = since(writeStart)
        BM25Index.lastBuildStats = stats
        return index
    }

    /// Đánh chỉ mục MỘT bản ghi.
    private static func indexRecord(
        line: UnsafeBufferPointer<UInt8>, into block: inout [String: TermBlock],
        blockBytes: inout Int,
        documentLengths: inout [Int32], totalTokens: inout Int, options: Options
    ) {
        let document = Int32(documentLengths.count)
        var length: Int32 = 0
        defer { documentLengths.append(length) }

        // Cắt khoảng trắng hai đầu ngay trên vùng byte, không dựng đối tượng trung gian.
        var lower = 0
        var upper = line.count
        while lower < upper,
              line[lower] == 0x20 || line[lower] == 0x09 || line[lower] == 0x0D { lower += 1 }
        while upper > lower,
              line[upper - 1] == 0x20 || line[upper - 1] == 0x09
                  || line[upper - 1] == 0x0D { upper -= 1 }
        guard lower < upper else { return }
        let trimmed = UnsafeBufferPointer(start: line.baseAddress! + lower, count: upper - lower)
        // Dòng KHÔNG phải JSON hợp lệ vẫn giữ chỗ của nó trong dãy tài liệu (độ dài 0).
        //
        // Bỏ hẳn nó thì mọi số hiệu tài liệu phía sau lệch một, và "bấm kết quả để nhảy tới
        // dòng" nhảy sai — một lỗi im lặng. FR-KNW-901 có panel liệt kê record hỏng riêng.
        //
        // Đường tắt: lấy dải byte của trường văn bản mà không dựng đối tượng nào, rồi cắt token
        // thẳng trên dải ấy. `BM25RawJSON` trả `nil` cho mọi dòng nó không chắc — kể cả dòng
        // đúng ngữ pháp nhưng có ký tự thoát — và khi đó bộ đọc đầy đủ nhận lại việc.
        let tokens: [String]
        if let range = BM25RawJSON.stringRange(field: options.textField, in: trimmed) {
            let value = UnsafeBufferPointer(
                start: trimmed.baseAddress! + range.lowerBound, count: range.count)
            tokens = options.tokenizer.tokens(inUTF8: value)
        } else {
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(buffer: trimmed)) as? [String: Any],
                let text = BM25Index.string(from: object[options.textField]) else { return }
            tokens = options.tokenizer.tokens(in: text)
        }
        var frequencies: [String: Int32] = [:]
        frequencies.reserveCapacity(tokens.count)
        for token in tokens {
            frequencies[token, default: 0] += 1
            length += 1
        }
        totalTokens += Int(length)

        for (term, frequency) in frequencies {
            // Ghi THẲNG vào mảng trong từ điển qua `subscript(_:default:)`.
            //
            // Bản đầu viết `var payload = block[term] ?? []` rồi `block[term] = payload` —
            // trông vô hại, nhưng nó tạo THAM CHIẾU THỨ HAI tới mảng, nên mỗi lần thêm hai
            // varint là một lần Swift chép lại CẢ danh sách posting (copy-on-write). Với một
            // từ khoá có mặt ở 56.000 tài liệu, đó là O(n²): PoC-M đo corpus 60 MB mất **29
            // giây** — sát trần 30 s dành cho corpus 1 GB, tức trượt gấp mười bảy lần.
            //
            // `block[term, default: []]` đi qua `_modify`, sửa tại chỗ, không chép.
            // MỘT lần truy cập từ điển cho cả ba việc: đọc tài liệu cuối, ghi posting, cập
            // nhật tài liệu cuối. `subscript(_:default:)` đi qua `_modify` nên sửa tại chỗ.
            var added = 0
            var isNew = false
            block[term, default: TermBlock()].with { entry in
                isNew = entry.lastDocument < 0
                let delta = Int(document - entry.lastDocument - 1)
                added = varintLength(delta) + varintLength(Int(frequency))
                appendVarint(delta, to: &entry.payload)
                appendVarint(Int(frequency), to: &entry.payload)
                entry.lastDocument = document
            }
            blockBytes += added + (isNew ? term.utf8.count + 8 : 0)
        }
    }

    // MARK: - Trộn

    private struct MergeResult {
        var dictionary: [String: (df: Int32, offset: Int)]
        var postings: [UInt8]
    }

    /// Trộn k run đã sắp thành một khối posting duy nhất.
    ///
    /// Đọc CẢ run vào bộ nhớ từng cái một chứ không đọc theo dòng: mỗi run đã bị chặn bởi
    /// `blockBudget`, nên đây là một trần đã biết. Đổi lại được một vòng trộn đơn giản, không
    /// có bộ đệm đọc nào phải nuôi.
    private static func merge(runs: [URL]) throws -> MergeResult {
        var cursors: [(bytes: [UInt8], position: Int, term: String?, payload: ArraySlice<UInt8>)] = []
        for url in runs {
            let bytes = [UInt8](try Data(contentsOf: url))
            var cursor = (bytes: bytes, position: 0, term: String?.none,
                          payload: ArraySlice<UInt8>())
            advance(&cursor)
            cursors.append(cursor)
        }

        var dictionary: [String: (df: Int32, offset: Int)] = [:]
        var postings: [UInt8] = []

        while true {
            // Từ khoá NHỎ NHẤT trong các đầu run.
            var smallest: String?
            for cursor in cursors {
                guard let term = cursor.term else { continue }
                if smallest == nil || term < smallest! { smallest = term }
            }
            guard let term = smallest else { break }

            // Gom mọi posting của từ khoá ấy. Chúng đã tăng dần theo tài liệu TRONG từng run,
            // và các run sinh ra theo thứ tự tài liệu, nên nối lại là vẫn tăng dần — không cần
            // sắp thêm. Hiệu số hiệu tài liệu vì thế phải TÍNH LẠI qua ranh giới run.
            let offset = postings.count
            var count: Int32 = 0
            var lastDocument: Int32 = -1
            for index in cursors.indices where cursors[index].term == term {
                var position = cursors[index].payload.startIndex
                let bytes = cursors[index].bytes
                // Cùng công thức với `search`: `doc = trước + hiệu + 1`, "trước" khởi đầu −1.
                var previousInRun: Int32 = -1
                while position < cursors[index].payload.endIndex {
                    var local = position
                    let delta = Int32(readVarint(bytes, &local))
                    let frequency = readVarint(bytes, &local)
                    position = local
                    let document = previousInRun + delta + 1
                    previousInRun = document
                    appendVarint(Int(document - lastDocument - 1), to: &postings)
                    appendVarint(frequency, to: &postings)
                    lastDocument = document
                    count += 1
                }
                advance(&cursors[index])
            }
            dictionary[term] = (count, offset)
        }
        return MergeResult(dictionary: dictionary, postings: postings)
    }

    /// Đưa con trỏ của một run sang mục kế tiếp.
    private static func advance(
        _ cursor: inout (bytes: [UInt8], position: Int, term: String?,
                         payload: ArraySlice<UInt8>)
    ) {
        guard cursor.position < cursor.bytes.count else {
            cursor.term = nil
            return
        }
        var position = cursor.position
        let nameLength = readVarint(cursor.bytes, &position)
        let name = String(decoding: cursor.bytes[position ..< position + nameLength],
                          as: UTF8.self)
        position += nameLength
        let payloadLength = readVarint(cursor.bytes, &position)
        cursor.term = name
        cursor.payload = cursor.bytes[position ..< position + payloadLength]
        cursor.position = position + payloadLength
    }

    // MARK: - Định dạng tệp
    //
    // ```
    // <JSON manifest>\n
    // varint documentCount, rồi documentCount × varint độ dài
    // varint recordOffsets.count, rồi từng varint HIỆU vị trí byte
    // varint termCount, rồi mỗi từ: varint len + utf8 + varint df + varint offset
    // varint postings.count, rồi khối posting
    // ```
    //
    // Phần đầu là JSON để đọc được bằng `head -1`; phần thân là varint có mô tả ở đây. Đó là
    // nghĩa của *"dạng file mở"* trong NFR-KNW-04 — không phải một khối nhị phân đóng.

    func write(to path: String) throws {
        var bytes: [UInt8] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        bytes.append(contentsOf: [UInt8](try encoder.encode(manifest)))
        bytes.append(0x0A)

        appendVarint(documentLengths.count, to: &bytes)
        for length in documentLengths { appendVarint(Int(length), to: &bytes) }

        appendVarint(recordOffsets.count, to: &bytes)
        var previous = 0
        for offset in recordOffsets {
            appendVarint(offset - previous, to: &bytes)
            previous = offset
        }

        appendVarint(dictionary.count, to: &bytes)
        // Ghi theo THỨ TỰ BẢNG CHỮ CÁI: hai lần dựng trên cùng corpus phải cho hai tệp giống
        // nhau từng byte, nếu không thì không đối chứng được và `git diff` đầy nhiễu.
        for term in dictionary.keys.sorted() {
            let entry = dictionary[term]!
            let utf8 = Array(term.utf8)
            appendVarint(utf8.count, to: &bytes)
            bytes.append(contentsOf: utf8)
            appendVarint(Int(entry.df), to: &bytes)
            appendVarint(entry.offset, to: &bytes)
        }

        appendVarint(postings.count, to: &bytes)
        bytes.append(contentsOf: postings)
        try Data(bytes).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// Đọc lại chỉ mục đã ghi. `nil` khi thiếu tệp, tệp hỏng, hoặc **corpus đã đổi**.
    public static func load(corpus path: String, options: Options = Options()) -> BM25Index? {
        guard let data = FileManager.default.contents(atPath: indexPath(for: path)),
              let newline = data.firstIndex(of: 0x0A) else { return nil }
        guard let manifest = try? JSONDecoder().decode(
            Manifest.self, from: data[data.startIndex ..< newline]) else { return nil }
        guard manifest.isFresh(for: path, options: options) else { return nil }

        let bytes = [UInt8](data[data.index(after: newline)...])
        var cursor = 0
        let documentCount = readVarint(bytes, &cursor)
        var lengths: [Int32] = []
        lengths.reserveCapacity(documentCount)
        for _ in 0 ..< documentCount { lengths.append(Int32(readVarint(bytes, &cursor))) }

        let offsetCount = readVarint(bytes, &cursor)
        var offsets: [Int] = []
        offsets.reserveCapacity(offsetCount)
        var previous = 0
        for _ in 0 ..< offsetCount {
            previous += readVarint(bytes, &cursor)
            offsets.append(previous)
        }

        let termCount = readVarint(bytes, &cursor)
        var dictionary: [String: (df: Int32, offset: Int)] = [:]
        dictionary.reserveCapacity(termCount)
        for _ in 0 ..< termCount {
            let nameLength = readVarint(bytes, &cursor)
            guard cursor + nameLength <= bytes.count else { return nil }
            let term = String(decoding: bytes[cursor ..< cursor + nameLength], as: UTF8.self)
            cursor += nameLength
            let df = Int32(readVarint(bytes, &cursor))
            let offset = readVarint(bytes, &cursor)
            dictionary[term] = (df, offset)
        }

        let postingsCount = readVarint(bytes, &cursor)
        guard cursor + postingsCount <= bytes.count else { return nil }
        let postings = Array(bytes[cursor ..< cursor + postingsCount])

        return BM25Index(
            manifest: manifest, options: options, corpusPath: path,
            recordOffsets: offsets, documentLengths: lengths,
            dictionary: dictionary, postings: postings)
    }

    /// Mở chỉ mục còn hiệu lực, hoặc dựng mới.
    public static func open(
        corpus path: String, options: Options = Options(),
        progress: ((Double) -> Bool)? = nil
    ) throws -> BM25Index {
        if let existing = load(corpus: path, options: options) { return existing }
        return try build(corpus: path, options: options, progress: progress)
    }
}
