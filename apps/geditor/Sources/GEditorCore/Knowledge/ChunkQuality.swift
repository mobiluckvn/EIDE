import Foundation

/// Chấm chất lượng corpus chunk theo khung FR-DQR — FR-KNW-922.
///
/// Đặc tả: *"Chấm chất lượng corpus theo KHUNG FR-DQR, không cần embedding: (a) phân bố token
/// đối chiếu NGƯỠNG MODEL khai báo; (b) TRÙNG GẦN bằng shingling n-gram ký tự (k=5) + Jaccard
/// trên tập shingle, ngưỡng ≥ 0,8 gom cụm ứng viên (thuật toán cổ điển, tất định); (c)
/// BOILERPLATE: đoạn mở/kết lặp lại ≥ N lần trên toàn corpus; (d) COVERAGE theo metadata nguồn.
/// Tổng hợp thành Chunk Quality Score (các chiều ánh xạ khung DQR-002)."*
///
/// ## "Không cần embedding" là điều kiện, không phải lời khoe
///
/// Bốn phép đo trên đều là phép đo **trên văn bản thô**: đếm, băm, đếm lại. Không có mô hình nào
/// tham gia, nên kết quả tất định bit-by-bit và người đọc tính lại được bằng tay — đúng ba tính
/// chất NFR-DQR-03 đòi. Một bản dùng embedding để đo "trùng ngữ nghĩa" sẽ đo được nhiều hơn, và
/// sẽ không còn tính lại được, không còn tất định, và không chạy được offline.
///
/// ## Ánh xạ sang sáu chiều DQR-002, và vì sao ánh xạ như vậy
///
/// | Chiều DQR | Đo bằng | Ý nghĩa với corpus chunk |
/// |---|---|---|
/// | Đầy đủ | (d) nguồn khai báo có chunk | nguồn nào khai rồi mà không cào được chữ nào |
/// | Hợp lệ | (a) token trong ngưỡng model | chunk vượt ngưỡng bị model cắt cụt; chunk quá ngắn không mang đủ ngữ cảnh |
/// | Không trùng | (b) trùng gần Jaccard | cùng một đoạn cào về nhiều lần thì retrieval trả cùng một thứ k lần |
/// | Nhất quán | (d) phân bố giữa các nguồn | một nguồn chiếm 90% thì mọi phép đánh giá về sau đều nói về nguồn ấy |
/// | Chính xác (ước lượng) | (c) boilerplate | header/footer/disclaimer dính vào chunk làm loãng nội dung thật |
/// | Tươi mới | — | **KHÔNG chấm được**: JSONL chunk không khai ngày |
///
/// Chiều TƯƠI MỚI trả `nil` chứ không trả 100. Đó không phải thiếu sót của tệp này mà là luật
/// của khung: *"chiều nào KHÔNG chấm được thì trả `nil` và nói lý do — nó bị loại khỏi trung
/// bình có trọng số, không được âm thầm tính là 100"*. Một corpus được cho 100 điểm "tươi mới"
/// vì không ai biết nó cũ bao nhiêu là một điểm số nói dối theo hướng có lợi.
public enum ChunkQuality {

    // MARK: - Cấu hình

    /// Cách quy văn bản ra "token" để so với ngưỡng model.
    ///
    /// **Đây là chỗ dễ nói dối nhất trong cả tệp này.** Ngưỡng người dùng khai (`max_tokens:
    /// 512`) là ngưỡng của MỘT bộ tách token cụ thể của MỘT model cụ thể, và ta không có bộ ấy.
    /// Nên hai lựa chọn dưới đây đều nói thẳng chúng đang đếm gì:
    ///
    /// * `.syllable` — đếm bằng chính `BM25Tokenizer`. **Chính xác cái nó định nghĩa**, tất
    ///   định, tính lại được bằng tay; và với tiếng Việt nó đếm ÂM TIẾT, thường ÍT hơn số token
    ///   thật của model từ 1,5 tới 3 lần.
    /// * `.characters(perToken:)` — chia số ký tự cho một tỉ lệ **người dùng phải tự khai**.
    ///   Không có giá trị mặc định, và đó là cố ý: tỉ lệ ký tự/token phụ thuộc model lẫn ngôn
    ///   ngữ, nên một hằng số mặc định ở đây là một con số bịa mà cả báo cáo sẽ dựa vào.
    public enum TokenEstimator: Equatable, Sendable {
        case syllable
        case characters(perToken: Double)

        /// In vào khối "Phương pháp" — NFR-MIN-04 đòi mọi kết quả nói ra cách nó được tính.
        public var methodology: String {
            switch self {
            case .syllable:
                return "đếm token bằng bộ tách âm tiết (\(BM25Tokenizer.name)) — ĐÂY KHÔNG PHẢI "
                    + "bộ tách token của model, với tiếng Việt nó thường đếm ít hơn 1,5–3 lần"
            case let .characters(ratio):
                return "ước lượng token = số ký tự ÷ \(Self.format(ratio)) (tỉ lệ do người dùng "
                    + "khai, không phải mặc định của ứng dụng)"
            }
        }

        static func format(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
        }
    }

    public struct Config: Equatable, Sendable {
        public var textField: String
        public var sourceField: String
        public var idField: String
        /// Chunk có nhiều token hơn ngần này là VƯỢT. `nil` = không chấm vế trên.
        public var maxTokens: Int?
        /// Chunk có ít token hơn ngần này là QUÁ NGẮN. `nil` = không chấm vế dưới.
        public var minTokens: Int?
        public var estimator: TokenEstimator
        /// Jaccard từ ngưỡng này trở lên thì hai chunk là trùng gần.
        public var nearDuplicate: Double
        /// k của shingle ký tự.
        public var shingle: Int
        /// Đoạn mở/kết lặp lại từ ngần này lần trở lên thì bị gọi là boilerplate.
        public var boilerplateRepeats: Int
        /// Trần số chunk cho phép chấm TRÙNG GẦN — xem `nearDuplicateClusters`. 0 = không trần.
        public var nearDuplicateLimit: Int
        /// Danh sách nguồn ĐÃ KHAI. Rỗng = không chấm chiều ĐẦY ĐỦ.
        public var declaredSources: [String]

        public init(
            textField: String = "text", sourceField: String = "source", idField: String = "id",
            maxTokens: Int? = nil, minTokens: Int? = nil,
            estimator: TokenEstimator = .syllable,
            nearDuplicate: Double = 0.8, shingle: Int = 5,
            boilerplateRepeats: Int = 3, nearDuplicateLimit: Int = 20_000,
            declaredSources: [String] = []
        ) {
            self.textField = textField
            self.sourceField = sourceField
            self.idField = idField
            self.maxTokens = maxTokens
            self.minTokens = minTokens
            self.estimator = estimator
            self.nearDuplicate = nearDuplicate
            self.shingle = max(1, shingle)
            self.boilerplateRepeats = max(2, boilerplateRepeats)
            self.nearDuplicateLimit = max(0, nearDuplicateLimit)
            self.declaredSources = declaredSources
        }
    }

    // MARK: - Kết quả

    public struct Chunk: Equatable, Sendable {
        public var line: Int
        public var id: String
        public var source: String
        public var tokens: Int
        public var characters: Int
    }

    public struct Boilerplate: Equatable, Sendable {
        public enum Position: String, Equatable, Sendable {
            case opening, closing

            public var vietnamese: String {
                self == .opening ? "đoạn mở" : "đoạn kết"
            }
        }
        public var position: Position
        public var text: String
        public var count: Int
        /// Vài dòng đầu tiên chứa nó — để bấm nhảy tới.
        public var lines: [Int]
    }

    public struct SourceCount: Equatable, Sendable {
        public var source: String
        public var count: Int
    }

    public struct Report: Equatable, Sendable {
        public var chunkCount: Int
        /// Dòng đọc được nhưng KHÔNG có trường văn bản — vẫn đếm, vẫn kể ra.
        public var brokenLines: [Int]
        public var chunks: [Chunk]
        public var overLimit: [Chunk]
        public var underLimit: [Chunk]
        /// Cụm chunk trùng gần, mỗi cụm là dãy số hiệu dòng TĂNG DẦN; cụm sắp theo phần tử đầu.
        public var duplicateClusters: [[Int]]
        /// `nil` khi corpus vượt trần `nearDuplicateLimit` — không phải khi không có cụm nào.
        public var nearDuplicateSkipped: Int?
        public var boilerplate: [Boilerplate]
        public var boilerplateChunks: Int
        public var sourceCounts: [SourceCount]
        public var missingSources: [String]
        public var config: Config
        public var score: QualityScore

        /// Trung vị số token — con số hay được dán lên báo cáo nhất.
        public var medianTokens: Int {
            guard !chunks.isEmpty else { return 0 }
            let sorted = chunks.map(\.tokens).sorted()
            return sorted[sorted.count / 2]
        }
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    // MARK: - Chạy

    public static func run(
        corpus path: String, config: Config = Config(), now: Date = Date(),
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) throws -> Report {
        var chunks: [Chunk] = []
        var broken: [Int] = []
        var texts: [String] = []
        var openings: [String: [Int]] = [:]
        var closings: [String: [Int]] = [:]
        let tokenizer = BM25Tokenizer()

        try JSONLReader.forEachLine(
            path: path, cancelToken: cancelToken, progress: progress
        ) { line in
            // Dòng rỗng KHÔNG phải lỗi — tệp JSONL hay có dòng trống cuối tệp, và kể nó ra như
            // một bản ghi hỏng thì mọi corpus đều có đúng một lỗi giả.
            if line.bytes.isEmpty { return true }
            guard let text = JSONLReader.string(field: config.textField, in: line.bytes) else {
                broken.append(line.number)
                return true
            }
            let identifier = JSONLReader.string(field: config.idField, in: line.bytes)
                ?? "dòng \(line.number + 1)"
            let source = JSONLReader.string(field: config.sourceField, in: line.bytes) ?? ""
            let tokens: Int
            switch config.estimator {
            case .syllable:
                tokens = tokenizer.tokens(in: text).count
            case let .characters(ratio):
                tokens = Int((Double(text.count) / max(ratio, 0.001)).rounded())
            }
            chunks.append(Chunk(
                line: line.number, id: identifier, source: source,
                tokens: tokens, characters: text.count))
            texts.append(text)

            let (open, close) = edges(of: text)
            if !open.isEmpty { openings[open, default: []].append(line.number) }
            if !close.isEmpty { closings[close, default: []].append(line.number) }
            return true
        }

        guard !chunks.isEmpty else {
            throw Failure(message: "corpus «\(path)» không có bản ghi nào đọc được"
                + (broken.isEmpty ? "" : " (\(broken.count) dòng không có trường "
                    + "«\(config.textField)»)"))
        }

        // --- (a) Phân bố token ------------------------------------------------------------
        let over = config.maxTokens.map { limit in chunks.filter { $0.tokens > limit } } ?? []
        let under = config.minTokens.map { limit in chunks.filter { $0.tokens < limit } } ?? []

        // --- (b) Trùng gần ----------------------------------------------------------------
        var clusters: [[Int]] = []
        var skipped: Int?
        if config.nearDuplicateLimit > 0 && chunks.count > config.nearDuplicateLimit {
            skipped = chunks.count
        } else {
            try cancelToken?.check()
            clusters = nearDuplicateClusters(texts: texts, lines: chunks.map(\.line),
                                             config: config)
        }

        // --- (c) Boilerplate ---------------------------------------------------------------
        var boilerplate: [Boilerplate] = []
        var contaminated: Set<Int> = []
        for (position, table) in [
            (Boilerplate.Position.opening, openings), (Boilerplate.Position.closing, closings),
        ] {
            for (text, lines) in table where lines.count >= config.boilerplateRepeats {
                boilerplate.append(Boilerplate(
                    position: position, text: text, count: lines.count,
                    lines: Array(lines.prefix(20))))
                contaminated.formUnion(lines)
            }
        }
        // Sắp theo số lần giảm dần, hoà thì theo văn bản — hai lượt chạy phải cho cùng thứ tự.
        boilerplate.sort {
            $0.count != $1.count ? $0.count > $1.count
                : ($0.text != $1.text ? $0.text < $1.text
                    : $0.position.rawValue < $1.position.rawValue)
        }

        // --- (d) Coverage theo nguồn ---------------------------------------------------------
        var counts: [String: Int] = [:]
        for chunk in chunks where !chunk.source.isEmpty { counts[chunk.source, default: 0] += 1 }
        let sourceCounts = counts.map { SourceCount(source: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.source < $1.source }
        let missing = config.declaredSources.filter { counts[$0] == nil }

        let score = self.score(
            chunkCount: chunks.count, over: over.count, under: under.count,
            clusters: clusters, nearDuplicateSkipped: skipped,
            contaminated: contaminated.count, sourceCounts: sourceCounts,
            missing: missing, config: config, now: now)

        return Report(
            chunkCount: chunks.count, brokenLines: broken, chunks: chunks,
            overLimit: over, underLimit: under, duplicateClusters: clusters,
            nearDuplicateSkipped: skipped, boilerplate: boilerplate,
            boilerplateChunks: contaminated.count, sourceCounts: sourceCounts,
            missingSources: missing, config: config, score: score)
    }

    // MARK: - (c) Đoạn mở và đoạn kết

    /// Dòng đầu và dòng cuối của một chunk, đã chuẩn hoá.
    ///
    /// Chuẩn hoá là chỗ quyết định phép đo này có bắt được gì không: header cào về cùng một
    /// trang web khác nhau ở khoảng trắng và ở hoa/thường nhiều hơn là ở chữ. Nên: gom khoảng
    /// trắng, cắt hai đầu, hạ chữ thường.
    ///
    /// Dòng ngắn hơn 12 ký tự bị bỏ qua — `"# Chương 1"` lặp lại 40 lần là mục lục, không phải
    /// boilerplate, và kể nó ra thì phần boilerplate của báo cáo toàn những dòng như thế.
    static func edges(of text: String) -> (opening: String, closing: String) {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
        guard let first = lines.first, let last = lines.last else { return ("", "") }
        let opening = first.count >= 12 ? first : ""
        // Chunk chỉ có MỘT dòng thì dòng ấy vừa là mở vừa là kết — đếm nó một lần thôi, không
        // thì mọi chunk một dòng đều tự tính hai lần vào phần trăm nhiễm boilerplate.
        let closing = (lines.count > 1 && last.count >= 12) ? last : ""
        return (opening, closing)
    }

    static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    // MARK: - (b) Trùng gần: shingling + Jaccard, lọc tiền tố

    /// Gom cụm chunk trùng gần. Tất định: không băm ngẫu nhiên, không lấy mẫu.
    ///
    /// ## Vì sao không so từng cặp
    ///
    /// So mọi cặp là O(n²) — 20 000 chunk là 200 triệu phép so tập hợp. Cách cổ điển để tránh
    /// nó mà **không bỏ sót cặp nào** là hai bộ lọc, cả hai đều suy ra từ chính ngưỡng Jaccard:
    ///
    /// **Lọc theo độ dài.** J(A,B) ≥ t kéo theo |A| ≥ t·|B|. Nên duyệt các tập theo cỡ tăng dần
    /// thì chỉ cần xét những tập có cỡ trong khoảng [t·|B|, |B|].
    ///
    /// **Lọc theo tiền tố.** Sắp mọi shingle theo một thứ tự toàn cục (ở đây: tần suất tăng
    /// dần, hoà thì theo giá trị băm). J(A,B) ≥ t kéo theo |A∩B| ≥ t·|A∪B| ≥ t·max(|A|,|B|).
    /// Nếu hai tập giao nhau ít nhất α phần tử thì **tiền tố dài |X| − α + 1 của chúng bắt buộc
    /// phải cắt nhau** — không cắt nhau thì phần dư không đủ chỗ chứa α phần tử chung. Lấy
    /// α = ⌈t·|X|⌉ cho tiền tố dài hơn mức cần, nên bộ lọc này an toàn theo cả hai chiều: không
    /// bỏ sót, chỉ nhận thừa.
    ///
    /// Ứng viên còn lại được chấm Jaccard THẬT, nên kết quả cuối cùng là kết quả chính xác chứ
    /// không phải kết quả xấp xỉ. Đó là điều MinHash/LSH không cho: nhanh hơn, nhưng có xác
    /// suất bỏ sót, và một báo cáo chất lượng nói "không có bản trùng" vì bỏ sót thì tệ hơn là
    /// nói "tôi không chấm được chiều này".
    static func nearDuplicateClusters(
        texts: [String], lines: [Int], config: Config
    ) -> [[Int]] {
        let threshold = config.nearDuplicate
        // Tập shingle của từng chunk, sắp theo GIÁ TRỊ tăng dần — Jaccard hợp nhất kiểu merge
        // trên hai dãy đã sắp, nên thứ tự này là thứ tự nó cần.
        var sets: [[UInt64]] = []
        sets.reserveCapacity(texts.count)
        var frequency: [UInt64: Int] = [:]
        for text in texts {
            let set = shingles(of: text, k: config.shingle).sorted()
            for value in set { frequency[value, default: 0] += 1 }
            sets.append(set)
        }
        // Tiền tố lấy theo một thứ tự toàn cục KHÁC: shingle HIẾM đứng trước, nên tiền tố chứa
        // những shingle đặc trưng nhất và số ứng viên giả ít đi rõ rệt.
        //
        // Giữ hai thứ tự chứ không sắp lại tập mỗi lần dùng: bản đầu để `sets` theo thứ tự tần
        // suất rồi `jaccard` tự `sorted()` — tức là sắp lại một dãy vài nghìn phần tử ở MỖI
        // phép so, và phép so là thứ chạy nhiều nhất trong cả hàm.
        func rarestFirst(_ set: [UInt64], count: Int) -> ArraySlice<UInt64> {
            guard count < set.count else { return set[...] }
            return set.sorted {
                let left = frequency[$0] ?? 0, right = frequency[$1] ?? 0
                return left != right ? left < right : $0 < $1
            }.prefix(count)
        }

        // Duyệt theo cỡ tập TĂNG DẦN, hoà thì theo chỉ số — để lọc độ dài chỉ phải nhìn về sau.
        let order = sets.indices.sorted {
            sets[$0].count != sets[$1].count
                ? sets[$0].count < sets[$1].count : $0 < $1
        }
        var index: [UInt64: [Int]] = [:]
        var parent = Array(sets.indices)

        func find(_ node: Int) -> Int {
            var node = node
            while parent[node] != node { parent[node] = parent[parent[node]]; node = parent[node] }
            return node
        }
        func union(_ left: Int, _ right: Int) {
            let a = find(left), b = find(right)
            guard a != b else { return }
            parent[max(a, b)] = min(a, b)
        }

        for current in order {
            let set = sets[current]
            guard !set.isEmpty else { continue }
            let minimumSize = Int((threshold * Double(set.count)).rounded(.up))
            var seen: Set<Int> = []
            let prefix = Array(rarestFirst(set, count: max(1, set.count - minimumSize + 1)))
            for shingle in prefix {
                for candidate in index[shingle] ?? [] where !seen.contains(candidate) {
                    seen.insert(candidate)
                    // Lọc độ dài: tập đã duyệt luôn NHỎ HƠN HOẶC BẰNG tập hiện tại.
                    guard Double(sets[candidate].count) >= threshold * Double(set.count) else {
                        continue
                    }
                    if jaccard(sets[candidate], set) >= threshold { union(candidate, current) }
                }
            }
            for shingle in prefix { index[shingle, default: []].append(current) }
        }

        var groups: [Int: [Int]] = [:]
        for node in sets.indices { groups[find(node), default: []].append(node) }
        return groups.values
            .filter { $0.count > 1 }
            .map { $0.map { lines[$0] }.sorted() }
            .sorted { ($0.first ?? 0) < ($1.first ?? 0) }
    }

    /// Tập shingle ký tự k-gram, đã băm và bỏ trùng.
    ///
    /// Băm chứ không giữ chuỗi: một chunk 2 000 ký tự cho gần 2 000 shingle, và giữ chúng dưới
    /// dạng `String` thì riêng phần tập hợp đã nặng gấp mười lần chính văn bản.
    ///
    /// Văn bản được chuẩn hoá trước (gom khoảng trắng, hạ chữ thường) vì hai bản cào về của cùng
    /// một trang thường chỉ khác nhau ở đúng hai thứ ấy.
    static func shingles(of text: String, k: Int) -> [UInt64] {
        let normalized = Array(normalize(text).unicodeScalars)
        guard normalized.count >= k else {
            // Chuỗi ngắn hơn k: chính nó là shingle duy nhất. Bỏ hẳn thì mọi chunk ngắn đều có
            // tập rỗng, và tập rỗng thì Jaccard không định nghĩa được.
            return normalized.isEmpty ? [] : [hash(normalized[...])]
        }
        var out: Set<UInt64> = []
        out.reserveCapacity(normalized.count)
        for start in 0 ... (normalized.count - k) {
            out.insert(hash(normalized[start ..< (start + k)]))
        }
        return Array(out)
    }

    /// FNV-1a 64 bit. Chọn nó vì nó viết ra được trong sáu dòng và **cố định giữa các lần chạy**
    /// — `Hasher` của Swift gieo ngẫu nhiên theo tiến trình, nên một báo cáo dùng nó sẽ đổi thứ
    /// tự cụm sau mỗi lần mở lại ứng dụng.
    static func hash(_ scalars: ArraySlice<Unicode.Scalar>) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for scalar in scalars {
            var code = scalar.value
            for _ in 0 ..< 4 {
                value ^= UInt64(code & 0xFF)
                value = value &* 0x0000_0100_0000_01B3
                code >>= 8
            }
        }
        return value
    }

    /// Jaccard trên hai dãy ĐÃ SẮP — hợp nhất kiểu merge, không dựng `Set` trung gian.
    static func jaccard(_ a: [UInt64], _ b: [UInt64]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var i = 0, j = 0, shared = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] { shared += 1; i += 1; j += 1 }
            else if a[i] < b[j] { i += 1 }
            else { j += 1 }
        }
        return Double(shared) / Double(a.count + b.count - shared)
    }

    // MARK: - Điểm

    static func score(
        chunkCount: Int, over: Int, under: Int, clusters: [[Int]],
        nearDuplicateSkipped: Int?, contaminated: Int,
        sourceCounts: [SourceCount], missing: [String], config: Config, now: Date
    ) -> QualityScore {
        let total = Double(chunkCount)
        var dimensions: [QualityScore.DimensionScore] = []

        // Trọng số ĐỀU. Khung FR-DQR cho phép khai trọng số riêng trong `.gquality.yaml`, nhưng
        // ở chế độ chunk thì không có tệp luật nào, và bịa ra một bộ trọng số lệch (kiểu "trùng
        // lặp quan trọng gấp đôi") là bịa ra một phán xét mà không ai ký tên.
        let weight = 1.0

        // --- Đầy đủ: nguồn khai báo có chunk hay không ---
        if config.declaredSources.isEmpty {
            dimensions.append(.init(
                dimension: .completeness, value: nil,
                formula: "100 × (số nguồn khai báo CÓ chunk) ÷ (số nguồn khai báo)",
                detail: "—",
                note: "khối không khai «sources», nên không biết đáng lẽ phải có nguồn nào",
                weight: weight))
        } else {
            let present = config.declaredSources.count - missing.count
            dimensions.append(.init(
                dimension: .completeness,
                value: 100 * Double(present) / Double(config.declaredSources.count),
                formula: "100 × (số nguồn khai báo CÓ chunk) ÷ (số nguồn khai báo)",
                detail: "100 × \(present) ÷ \(config.declaredSources.count)"
                    + (missing.isEmpty ? "" : " · thiếu: " + missing.joined(separator: ", ")),
                weight: weight))
        }

        // --- Hợp lệ: token trong ngưỡng model ---
        if config.maxTokens == nil && config.minTokens == nil {
            dimensions.append(.init(
                dimension: .validity, value: nil,
                formula: "100 × (số chunk trong ngưỡng) ÷ (tổng số chunk)",
                detail: "—",
                note: "khối không khai «max_tokens» lẫn «min_tokens», nên không có ngưỡng nào "
                    + "để đối chiếu",
                weight: weight))
        } else {
            var bounds: [String] = []
            if let maximum = config.maxTokens { bounds.append("≤ \(maximum)") }
            if let minimum = config.minTokens { bounds.append("≥ \(minimum)") }
            let bad = over + under
            dimensions.append(.init(
                dimension: .validity, value: 100 * Double(chunkCount - bad) / total,
                formula: "100 × (số chunk có token \(bounds.joined(separator: " và "))) "
                    + "÷ (tổng số chunk)",
                detail: "100 × (\(chunkCount) − \(over) vượt − \(under) quá ngắn) ÷ \(chunkCount)"
                    + " · \(config.estimator.methodology)",
                weight: weight))
        }

        // --- Không trùng: trùng gần ---
        if let skipped = nearDuplicateSkipped {
            dimensions.append(.init(
                dimension: .uniqueness, value: nil,
                formula: "100 × (số chunk KHÔNG nằm trong cụm trùng gần) ÷ (tổng số chunk)",
                detail: "—",
                note: "corpus có \(skipped) chunk, vượt trần «near_dup_limit» = "
                    + "\(config.nearDuplicateLimit). Nâng trần (hoặc đặt 0 để bỏ trần) thì chấm "
                    + "được — phép lọc tiền tố giữ trọn tập shingle của mọi chunk trong bộ nhớ",
                weight: weight))
        } else {
            let duplicated = clusters.reduce(0) { $0 + $1.count }
            dimensions.append(.init(
                dimension: .uniqueness,
                value: 100 * Double(chunkCount - duplicated) / total,
                formula: "100 × (số chunk KHÔNG nằm trong cụm trùng gần) ÷ (tổng số chunk); "
                    + "trùng gần = Jaccard trên shingle \(config.shingle)-gram ký tự "
                    + "≥ \(TokenEstimator.format(config.nearDuplicate))",
                detail: "100 × (\(chunkCount) − \(duplicated)) ÷ \(chunkCount) · "
                    + "\(clusters.count) cụm",
                weight: weight))
        }

        // --- Nhất quán: phân bố giữa các nguồn ---
        //
        // Entropy chuẩn hoá H ÷ ln(k): 100 khi mọi nguồn góp bằng nhau, 0 khi một nguồn chiếm
        // tất. Chọn entropy thay vì "tỷ lệ nguồn lớn nhất" vì tỷ lệ ấy không phân biệt được
        // "hai nguồn 50/50" với "một nguồn 50% và năm mươi nguồn nhỏ".
        if sourceCounts.count < 2 {
            dimensions.append(.init(
                dimension: .consistency, value: nil,
                formula: "100 × H ÷ ln(k), H = −Σ pᵢ·ln(pᵢ) trên tỷ lệ chunk của từng nguồn",
                detail: "—",
                note: sourceCounts.isEmpty
                    ? "không chunk nào có trường «\(config.sourceField)»"
                    : "corpus chỉ có một nguồn, không có gì để so lệch",
                weight: weight))
        } else {
            let assigned = Double(sourceCounts.reduce(0) { $0 + $1.count })
            var entropy = 0.0
            for item in sourceCounts {
                let share = Double(item.count) / assigned
                entropy -= share * Foundation.log(share)
            }
            let maximum = Foundation.log(Double(sourceCounts.count))
            let biggest = sourceCounts[0]
            dimensions.append(.init(
                dimension: .consistency, value: 100 * entropy / maximum,
                formula: "100 × H ÷ ln(k), H = −Σ pᵢ·ln(pᵢ) trên tỷ lệ chunk của từng nguồn",
                detail: "k = \(sourceCounts.count) nguồn · H = \(String(format: "%.4f", entropy))"
                    + " · ln(k) = \(String(format: "%.4f", maximum))"
                    + " · lớn nhất «\(biggest.source)» \(biggest.count)/\(Int(assigned))",
                weight: weight))
        }

        // --- Chính xác (ước lượng): boilerplate ---
        dimensions.append(.init(
            dimension: .accuracy,
            value: 100 * Double(chunkCount - contaminated) / total,
            formula: "100 × (số chunk KHÔNG dính boilerplate) ÷ (tổng số chunk); boilerplate = "
                + "đoạn mở hoặc đoạn kết lặp ≥ \(config.boilerplateRepeats) lần trên toàn corpus",
            detail: "100 × (\(chunkCount) − \(contaminated)) ÷ \(chunkCount)",
            weight: weight))

        // --- Tươi mới: KHÔNG chấm được ---
        dimensions.append(.init(
            dimension: .timeliness, value: nil,
            formula: "—",
            detail: "—",
            note: "JSONL chunk không khai ngày, và đoán tuổi từ mtime của tệp là đoán tuổi của "
                + "LẦN XUẤT chứ không phải của nội dung",
            weight: weight))

        return QualityScore(
            dimensions: dimensions, rowCount: chunkCount, evaluatedAt: now)
    }
}
