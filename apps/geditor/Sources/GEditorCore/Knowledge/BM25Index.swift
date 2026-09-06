import Foundation

/// Chỉ mục BM25 trên corpus JSONL — FR-KNW-918, NFR-KNW-04.
///
/// ## Vì sao TỰ VIẾT, không dùng DuckDB FTS
///
/// Đo ngày 27/08/2026: bản DuckDB ta vendor có `json` và `parquet` **liên kết tĩnh**, nhưng
/// `fts` thì **KHÔNG** — cài nó cần **mạng lúc chạy**. Điều đó phá cam kết offline và phá luật
/// App Store (cấm tải mã). NFR-KNW-04 còn đòi *"điểm BM25 đối chứng được với cài đặt tham chiếu,
/// sai số ≤ 1e-9"* — chỉ giữ được khi ta sở hữu công thức. Xem ADR-15 §7.
///
/// ## Dựng chỉ mục theo KHỐI rồi trộn (SPIMI), không gom hết vào RAM
///
/// Corpus 1 GB cho khoảng **120 triệu posting**. Giữ chúng trong bộ nhớ dạng mảng cặp số là hơn
/// một gigabyte RAM — trên máy chuẩn 8 GB của NFR-PERF-05 thì đó là một lần hoán trang thấy
/// được, và nó phá luôn NFR-KNW-01 (*"tắt Pack thì RAM không đổi"*) vì đỉnh RAM ấy còn cao hơn
/// cả app.
///
/// Nên: gom posting vào một khối có TRẦN BỘ NHỚ, đầy thì ghi ra một *run* đã sắp trên đĩa, cuối
/// cùng trộn k đường. Đỉnh RAM vì thế là hằng số do ta chọn, không phải hàm của cỡ corpus.
///
/// ## Chỉ mục nằm CẠNH corpus và tự vô hiệu
///
/// `<corpus>.bm25idx`. Đầu tệp là một dòng JSON đọc được bằng mắt: đường dẫn corpus, cỡ, mtime,
/// trường đã đánh chỉ mục, tên bộ tách từ, k1/b. Mở corpus mà một trong số đó lệch thì chỉ mục
/// bị coi là hết hạn — **không** cố sửa chữa. Một chỉ mục lệch corpus trả về đúng thứ hạng cho
/// một tập tài liệu không còn tồn tại, và đó là kiểu sai không ai phát hiện.
///
/// NFR-KNW-04 gọi đây là *"dạng file mở"*: phần đầu là JSON, phần thân là varint có tài liệu ở
/// §Định dạng bên dưới. Không phải một khối nhị phân đóng.
public final class BM25Index {

    // MARK: - Tham số

    public struct Options: Equatable, Sendable {
        /// Trường JSON chứa văn bản đem đánh chỉ mục.
        public var textField: String
        /// Trường JSON dùng làm định danh chunk. Rỗng = dùng số thứ tự dòng.
        public var idField: String
        public var k1: Double
        public var b: Double
        public var tokenizer: BM25Tokenizer
        /// Trần bộ nhớ cho một khối posting, tính bằng byte.
        public var blockBudget: Int

        public init(
            textField: String = "text", idField: String = "id",
            k1: Double = 1.2, b: Double = 0.75,
            tokenizer: BM25Tokenizer = BM25Tokenizer(),
            blockBudget: Int = 64 << 20
        ) {
            self.textField = textField
            self.idField = idField
            self.k1 = k1
            self.b = b
            self.tokenizer = tokenizer
            self.blockBudget = max(1 << 20, blockBudget)
        }
    }

    /// Đầu tệp — đọc được bằng mắt, và là thứ quyết định chỉ mục còn hiệu lực hay không.
    public struct Manifest: Codable, Equatable, Sendable {
        public static let currentVersion = 1

        public var version: Int
        public var corpus: String
        public var corpusBytes: Int
        public var corpusModified: Double
        public var textField: String
        public var idField: String
        public var tokenizer: String
        public var foldDiacritics: Bool
        public var k1: Double
        public var b: Double
        public var documentCount: Int
        public var totalTokens: Int
        public var averageLength: Double
        public var termCount: Int
        public var buildMilliseconds: Double

        /// Chỉ mục này còn nói đúng về tệp đang nằm trên đĩa không.
        public func isFresh(for path: String, options: Options) -> Bool {
            guard version == Manifest.currentVersion,
                  textField == options.textField, idField == options.idField,
                  tokenizer == BM25Tokenizer.name,
                  foldDiacritics == options.tokenizer.foldDiacritics,
                  k1 == options.k1, b == options.b
            else { return false }
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attributes[.size] as? Int else { return false }
            let modified = (attributes[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? 0
            // So cả CỠ lẫn THỜI ĐIỂM SỬA, cùng lối `QueryCatalog.Fingerprint`: sửa một ô mà
            // giữ nguyên độ dài là ca đã có bài kiểm ở chỗ khác trong dự án.
            return size == corpusBytes && abs(modified - corpusModified) < 0.000_001
        }
    }

    /// Thời gian từng chặng của lượt dựng gần nhất — để PoC-M chỉ ra chỗ tốn, thay vì đoán.
    ///
    /// Là biến TĨNH chứ không phải trường của chỉ mục: nó là số liệu về MỘT LƯỢT CHẠY, không
    /// phải thuộc tính của kết quả. Nhét nó vào manifest thì hai lần dựng cùng corpus cho hai
    /// tệp khác nhau, và tính tất định của chỉ mục mất theo.
    public struct BuildStats: Sendable {
        public var readMs = 0.0
        public var recordMs = 0.0
        public var splitMs = 0.0
        public var parseMs = 0.0
        public var tokenizeMs = 0.0
        public var postingMs = 0.0
        public var flushMs = 0.0
        public var mergeMs = 0.0
        public var writeMs = 0.0
    }

    public nonisolated(unsafe) static var lastBuildStats = BuildStats()

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    // MARK: - Trạng thái

    public let manifest: Manifest
    public let options: Options
    /// Vị trí byte của từng bản ghi trong corpus — để lấy lại nội dung mà không quét lại tệp.
    let recordOffsets: [Int]
    let documentLengths: [Int32]
    /// từ khoá → (df, vị trí trong khối posting)
    let dictionary: [String: (df: Int32, offset: Int)]
    let postings: [UInt8]
    let corpusPath: String

    init(
        manifest: Manifest, options: Options, corpusPath: String,
        recordOffsets: [Int], documentLengths: [Int32],
        dictionary: [String: (df: Int32, offset: Int)], postings: [UInt8]
    ) {
        self.manifest = manifest
        self.options = options
        self.corpusPath = corpusPath
        self.recordOffsets = recordOffsets
        self.documentLengths = documentLengths
        self.dictionary = dictionary
        self.postings = postings
    }

    public var documentCount: Int { documentLengths.count }

    /// Đường dẫn chỉ mục cho một corpus.
    public static func indexPath(for corpus: String) -> String { corpus + ".bm25idx" }

    // MARK: - Truy vấn

    public struct Hit: Equatable, Sendable {
        public var document: Int
        public var score: Double
        /// Từ khoá của câu hỏi thật sự khớp — để tô sáng trong chunk (FR-KNW-918).
        public var matchedTerms: [String]

        public init(document: Int, score: Double, matchedTerms: [String]) {
            self.document = document
            self.score = score
            self.matchedTerms = matchedTerms
        }
    }

    /// Top-k theo BM25.
    ///
    /// Công thức Robertson/Sparck-Jones, đúng bản mà mọi cài đặt tham chiếu dùng:
    ///
    /// ```
    /// idf(t) = ln( 1 + (N − df + 0,5) / (df + 0,5) )
    /// score  = Σ idf(t) · tf · (k1 + 1) / ( tf + k1 · (1 − b + b · |d| / avgdl) )
    /// ```
    ///
    /// Vế `1 +` trong `idf` là chỗ các cài đặt hay lệch nhau: thiếu nó thì một từ có mặt ở hơn
    /// nửa số tài liệu cho idf ÂM, và một tài liệu chứa từ ấy bị trừ điểm — đúng chỗ NFR-KNW-04
    /// đòi đối chứng ≤ 1e-9, nên nó được viết ra đây thay vì để người đọc đoán.
    public func search(_ query: String, k: Int = 10) -> [Hit] {
        let terms = options.tokenizer.tokens(in: query)
        guard !terms.isEmpty, documentCount > 0, k > 0 else { return [] }

        // Mảng DÀY, không phải từ điển.
        //
        // Bản đầu cộng điểm vào `[Int32: Double]` và ghi từ khớp vào `[Int32: [String]]`. Trên
        // corpus 1 GB thì một câu hỏi toàn từ PHỔ BIẾN chạm tới hàng trăm nghìn tài liệu, và
        // mỗi lần chạm là một lần băm cộng một lần cấp phát mảng — đo được **346 ms mỗi câu**,
        // trong khi chính bộ đo báo "truy vấn 1,0 ms". Con số 1,0 ms ấy đúng, nhưng nó đo bằng
        // câu hỏi gồm từ HIẾM; bộ đánh giá golden set mới lòi ra ca thật.
        //
        // Mảng dày đổi băm lấy ghi thẳng theo chỉ số. Cấp phát 690.000 `Double` nghe to nhưng
        // rẻ: hệ điều hành cấp trang KHÔNG rồi mới nạp khi có ai chạm tới.
        var scores = [Double](repeating: 0, count: documentCount)
        // Từ khớp giữ dạng BITMASK chứ không dạng mảng chuỗi: 32 từ đầu của câu hỏi là quá đủ,
        // và một `UInt32` cho mỗi tài liệu rẻ hơn một mảng chuỗi cho mỗi tài liệu vài trăm lần.
        var masks = [UInt32](repeating: 0, count: documentCount)
        var touched: [Int32] = []
        let total = Double(documentCount)
        let average = manifest.averageLength

        // Từ trùng trong câu hỏi CHỈ tính một lần. BM25 chuẩn nhân thêm một hệ số tf của câu
        // hỏi; bản phổ biến (và bản mọi thư viện tham chiếu dùng) bỏ nó, nên ta cũng bỏ — và
        // nói ra ở đây để hai bên đối chứng được.
        var unique: [String] = []
        var seen = Set<String>()
        for term in terms where seen.insert(term).inserted { unique.append(term) }

        for (position, term) in unique.enumerated() {
            guard let entry = dictionary[term] else { continue }
            let bit: UInt32 = position < 32 ? (1 << UInt32(position)) : 0
            let df = Double(entry.df)
            let idf = log(1 + (total - df + 0.5) / (df + 0.5))
            var cursor = entry.offset
            // Giải mã theo ĐÚNG công thức mã hoá: `doc = trước + hiệu + 1`, với "trước" khởi
            // đầu bằng −1. Bản đầu ở đây viết `document += delta` — đúng cho posting đầu tiên
            // và SAI cho mọi posting sau, nên ba tài liệu liên tiếp gộp hết vào tài liệu 0.
            // Hai bài kiểm có kỳ vọng TÍNH TAY bắt được; bài so hai lượt dựng với nhau thì
            // không, vì cả hai lượt cùng sai một kiểu.
            var previous: Int32 = -1
            for _ in 0 ..< Int(entry.df) {
                let delta = Int32(readVarint(postings, &cursor))
                let document = previous + delta + 1
                previous = document
                let frequency = Double(readVarint(postings, &cursor))
                let index = Int(document)
                let length = Double(documentLengths[index])
                let denominator = frequency
                    + options.k1 * (1 - options.b + options.b * length / average)
                // Mọi đóng góp đều DƯƠNG hẳn (idf > 0 với mọi df ≤ N), nên `điểm == 0` là dấu
                // hiệu chắc chắn của "chưa ai chạm" — không cần thêm một mảng cờ nữa.
                if scores[index] == 0 { touched.append(document) }
                scores[index] += idf * frequency * (options.k1 + 1) / denominator
                masks[index] |= bit
            }
        }
        guard !touched.isEmpty else { return [] }

        // Lấy top-k bằng ĐỐNG cỡ k, không sắp toàn bộ.
        //
        // Sắp cả nửa triệu tài liệu chạm được để lấy mười cái đầu là 9,5 triệu phép so cho một
        // câu hỏi. Đống cỡ k đổi nó thành nửa triệu phép so với log₂(k) — trên corpus 1 GB đo
        // được chênh nhau khoảng một bậc.
        //
        // Thứ tự vẫn TẤT ĐỊNH: hoà điểm thì tài liệu có số hiệu NHỎ HƠN thắng, đúng như bản
        // sắp-toàn-bộ trước đây. Không có luật ấy thì hai lượt chạy cho hai bảng khác nhau ở
        // những chỗ hoà — và NFR-KNW-04 đòi tất định.
        func better(_ left: Int32, _ right: Int32) -> Bool {
            let a = scores[Int(left)], b = scores[Int(right)]
            return a != b ? a > b : left < right
        }
        var heap: [Int32] = []                 // đống NHỎ-NHẤT-TRÊN-ĐỈNH theo `better`
        heap.reserveCapacity(min(k, touched.count))

        func siftDown(_ start: Int) {
            var parent = start
            while true {
                let left = parent * 2 + 1
                guard left < heap.count else { break }
                var worst = left
                let right = left + 1
                if right < heap.count, better(heap[worst], heap[right]) { worst = right }
                guard better(heap[parent], heap[worst]) else { break }
                heap.swapAt(parent, worst)
                parent = worst
            }
        }
        func siftUp(_ start: Int) {
            var child = start
            while child > 0 {
                let parent = (child - 1) / 2
                guard better(heap[parent], heap[child]) else { break }
                heap.swapAt(parent, child)
                child = parent
            }
        }

        for document in touched {
            if heap.count < k {
                heap.append(document)
                siftUp(heap.count - 1)
            } else if better(document, heap[0]) {
                heap[0] = document
                siftDown(0)
            }
        }
        heap.sort { better($0, $1) }
        return heap.map { document in
            let mask = masks[Int(document)]
            var matched: [String] = []
            for (position, term) in unique.enumerated()
            where position < 32 && (mask & (1 << UInt32(position))) != 0 {
                matched.append(term)
            }
            return Hit(document: Int(document), score: scores[Int(document)],
                       matchedTerms: matched)
        }
    }

    /// Nội dung thô của một bản ghi, đọc thẳng từ corpus theo vị trí byte đã nhớ.
    public func record(_ document: Int) -> String? {
        guard document >= 0, document + 1 < recordOffsets.count,
              let handle = FileHandle(forReadingAtPath: corpusPath) else { return nil }
        defer { try? handle.close() }
        let start = recordOffsets[document]
        let end = recordOffsets[document + 1]
        guard end > start else { return nil }
        try? handle.seek(toOffset: UInt64(start))
        guard let data = try? handle.read(upToCount: end - start) else { return nil }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Giá trị trường văn bản của một bản ghi — để tô sáng từ khớp.
    public func text(of document: Int) -> String? {
        guard let line = record(document),
              let object = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                as? [String: Any] else { return nil }
        return BM25Index.string(from: object[options.textField])
    }

    /// Định danh của mọi bản ghi, theo thứ tự số hiệu tài liệu.
    ///
    /// ## Vì sao KHÔNG gọi `record(_:)` trong vòng lặp
    ///
    /// `record(_:)` mở một `FileHandle` cho MỖI lần gọi — hợp lý cho mười kết quả hiện trên
    /// màn hình, thảm hoạ cho 690.000 bản ghi. Bản này quét corpus MỘT lượt.
    ///
    /// Bản ghi không có trường định danh nhận một chuỗi rỗng chứ không bị bỏ qua: bỏ qua thì
    /// mọi số hiệu phía sau lệch một, và bản đồ định danh sẽ trỏ sai — im lặng.
    public func identifiers(
        cancelToken: CancelToken? = nil, progress: ((Double) -> Bool)? = nil
    ) throws -> [String] {
        var out: [String] = []
        out.reserveCapacity(documentCount)
        try JSONLReader.forEachLine(
            path: corpusPath, cancelToken: cancelToken, progress: progress
        ) { line in
            guard out.count < documentCount else { return false }
            if line.bytes.isEmpty { out.append(""); return true }
            out.append(JSONLReader.string(field: options.idField, in: line.bytes) ?? "")
            return true
        }
        while out.count < documentCount { out.append("") }
        return out
    }

    /// Bản đồ định danh → số hiệu tài liệu.
    ///
    /// Định danh TRÙNG là chuyện có thật trong corpus cào về, và ở đây nó không hiền: golden
    /// set trỏ tới một id, mà id ấy ứng với ba chunk, thì "chunk đúng" là chunk nào? Bản này
    /// giữ **mọi** tài liệu mang cùng một id, và chỗ gọi quyết định phải làm gì — chứ không
    /// lặng lẽ giữ cái cuối cùng.
    public func identifierMap(
        cancelToken: CancelToken? = nil, progress: ((Double) -> Bool)? = nil
    ) throws -> [String: [Int]] {
        var map: [String: [Int]] = [:]
        for (document, identifier) in try identifiers(
            cancelToken: cancelToken, progress: progress).enumerated()
        where !identifier.isEmpty {
            map[identifier, default: []].append(document)
        }
        return map
    }

    /// Vị trí những từ khớp trong một đoạn văn bản, tính bằng offset UTF-16 — FR-KNW-918.
    public func highlights(in text: String, terms: [String]) -> [Range<Int>] {
        options.tokenizer.matches(in: text, terms: Set(terms))
    }

    static func string(from value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as NSNumber: return number.stringValue
        case let list as [Any]:
            // Trường `text` là MẢNG đoạn cũng gặp trong corpus thật; nối bằng xuống dòng chứ
            // không bỏ qua, vì bỏ qua là im lặng đánh chỉ mục thiếu một phần corpus.
            return list.compactMap { string(from: $0) }.joined(separator: "\n")
        default: return nil
        }
    }
}
