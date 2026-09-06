import Foundation

/// Bộ đánh giá truy hồi bằng golden set — FR-KNW-919.
///
/// Đặc tả: *"Nạp bộ đánh giá (CSV/JSONL: câu hỏi + danh sách id chunk kỳ vọng); chạy hàng loạt
/// trên chỉ mục BM25 → recall@k, MRR, nDCG@k tổng thể và theo từng câu (sắp theo câu tệ nhất để
/// sửa corpus có trọng tâm); so sánh song song 2 cấu hình; kết quả đổ vào .greport.md thành báo
/// cáo đánh giá tái lập được."*
///
/// ## Con số đánh giá là con số DỄ NÓI DỐI NHẤT trong cả cụm
///
/// Ba chỉ số dưới đây đều là trung bình trên tập câu hỏi, và một trung bình thì che được rất
/// nhiều thứ. Ba cái bẫy có thật, và cả ba đều được xử ở đây chứ không để người đọc tự đoán:
///
/// **1. Id kỳ vọng KHÔNG có trong corpus.** Golden set viết tay hoặc sinh từ một bản corpus cũ
/// thì sẽ trỏ tới những chunk đã biến mất. Recall khi ấy bị chặn trần mà không ai biết vì sao —
/// điểm thấp trông như "BM25 dở" trong khi thật ra là "bộ đánh giá hỏng". Nên mọi id không tìm
/// thấy đều được ĐẾM và kể tên, và câu hỏi nào mất sạch id kỳ vọng thì bị **loại khỏi trung
/// bình** chứ không tính là 0 điểm.
///
/// **2. Id kỳ vọng trỏ tới NHIỀU chunk.** Corpus cào về có id trùng. Ở đây một id ứng với tập
/// tài liệu, và chạm được BẤT KỲ tài liệu nào trong tập ấy là chạm được id — nói ra để người
/// đọc biết mình đang đo gì.
///
/// **3. `k` nhỏ hơn số id kỳ vọng.** Recall@5 trên một câu có 8 chunk đúng thì trần là 0,625 —
/// một con số trông như thất bại nhưng là trần toán học. Nên `Summary` mang theo `ceiling`.
public enum RetrievalEval {

    // MARK: - Golden set

    public struct Query: Equatable, Sendable {
        public var id: String
        public var question: String
        /// Id chunk kỳ vọng, theo đúng thứ tự trong tệp.
        public var relevant: [String]
        public var note: String

        public init(id: String, question: String, relevant: [String], note: String = "") {
            self.id = id
            self.question = question
            self.relevant = relevant
            self.note = note
        }
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Nạp golden set từ CSV hoặc JSONL.
    ///
    /// Nhận diện theo NỘI DUNG chứ không theo đuôi tệp: dòng đầu bắt đầu bằng `{` thì là JSONL.
    /// Đuôi tệp của một bộ đánh giá viết tay hay là `.txt`, và bắt người dùng đổi tên tệp để
    /// công cụ chịu đọc là một yêu cầu vô nghĩa.
    ///
    /// * **JSONL** — mỗi dòng `{"qid": …, "question": …, "relevant_ids": [...], "note": …}`.
    ///   Tên khoá nhận cả vài biến thể hay gặp; xem `questionKeys`/`relevantKeys`.
    /// * **CSV** — cột câu hỏi và cột id, id ngăn nhau bằng `;` hoặc `|` (KHÔNG phải `,`, vì
    ///   dấu phẩy đã là dấu ngăn cột và một ô `"a,b"` sẽ phải bọc ngoặc — đúng chỗ người ta hay
    ///   quên).
    public static func loadGoldenSet(path: String) throws -> [Query] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw Failure(message: "không đọc được bộ đánh giá «\(path)»")
        }
        let text = String(decoding: data, as: UTF8.self)
        let firstLine = text.split(whereSeparator: \.isNewline).first(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }) ?? ""
        let queries = firstLine.trimmingCharacters(in: .whitespaces).hasPrefix("{")
            ? try loadJSONL(text, path: path) : try loadCSV(data, path: path)
        guard !queries.isEmpty else {
            throw Failure(message: "bộ đánh giá «\((path as NSString).lastPathComponent)» "
                + "không có câu hỏi nào đọc được")
        }
        return queries
    }

    static let questionKeys = ["question", "query", "cau_hoi", "q"]
    static let relevantKeys = ["relevant_ids", "relevant", "expected", "ids", "chunk_ids"]
    static let queryIDKeys = ["qid", "id", "ma"]
    static let noteKeys = ["note", "ghi_chu", "ghichu"]

    private static func loadJSONL(_ text: String, path: String) throws -> [Query] {
        var out: [Query] = []
        for (number, line) in text.split(
            separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(trimmed.utf8)) as? [String: Any] else {
                throw Failure(message: "bộ đánh giá dòng \(number + 1): không phải JSON hợp lệ")
            }
            guard let question = firstString(object, questionKeys), !question.isEmpty else {
                throw Failure(message: "bộ đánh giá dòng \(number + 1): thiếu câu hỏi — "
                    + "khoá nhận được: " + questionKeys.joined(separator: ", "))
            }
            guard let relevant = firstList(object, relevantKeys) else {
                throw Failure(message: "bộ đánh giá dòng \(number + 1): thiếu danh sách id kỳ "
                    + "vọng — khoá nhận được: " + relevantKeys.joined(separator: ", "))
            }
            out.append(Query(
                id: firstString(object, queryIDKeys) ?? "q\(number + 1)",
                question: question, relevant: relevant,
                note: firstString(object, noteKeys) ?? ""))
        }
        return out
    }

    private static func loadCSV(_ data: Data, path: String) throws -> [Query] {
        let bytes = [UInt8](data)
        let dialect = CSVEngine.detectDialect(sample: Array(bytes.prefix(64 << 10)))
        let rows = CSVEngine.parse(bytes, dialect: dialect)
        func text(_ field: CSVField) -> String {
            String(decoding: CSVEngine.unescape(Array(bytes[field.range]), dialect: dialect),
                   as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        guard let header = rows.first else {
            throw Failure(message: "bộ đánh giá CSV rỗng")
        }
        func column(_ names: [String]) -> Int? {
            for (index, field) in header.enumerated()
            where names.contains(text(field).lowercased()) { return index }
            return nil
        }
        guard let questionColumn = column(questionKeys) else {
            throw Failure(message: "bộ đánh giá CSV thiếu cột câu hỏi — tên nhận được: "
                + questionKeys.joined(separator: ", "))
        }
        guard let relevantColumn = column(relevantKeys) else {
            throw Failure(message: "bộ đánh giá CSV thiếu cột id kỳ vọng — tên nhận được: "
                + relevantKeys.joined(separator: ", "))
        }
        let idColumn = column(queryIDKeys)
        // Cột ghi chú: có thì đọc, không có thì thôi. Thiếu vế này thì một lượt xuất CSV rồi
        // nhập lại làm MẤT sạch ghi chú trong im lặng — bài kiểm vòng tròn của FR-KNW-926 bắt
        // được, và đó đúng là kiểu hỏng mà một vòng xuất-nhập hay giấu.
        let noteColumn = column(noteKeys)
        var out: [Query] = []
        for (number, row) in rows.dropFirst().enumerated() {
            guard questionColumn < row.count, relevantColumn < row.count else { continue }
            let question = text(row[questionColumn])
            if question.isEmpty { continue }
            // Id ngăn nhau bằng `;` hoặc `|`, KHÔNG phải `,`: dấu phẩy đã là dấu ngăn cột, và
            // một ô `"a,b"` phải bọc ngoặc — đúng chỗ người ta hay quên, và quên thì mọi id
            // dồn vào một chuỗi mà không có gì báo.
            let ids = text(row[relevantColumn])
                .split(whereSeparator: { $0 == ";" || $0 == "|" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            out.append(Query(
                id: idColumn.flatMap { $0 < row.count ? text(row[$0]) : nil } ?? "q\(number + 1)",
                question: question, relevant: ids,
                note: noteColumn.flatMap { $0 < row.count ? text(row[$0]) : nil } ?? ""))
        }
        return out
    }

    private static func firstString(_ object: [String: Any], _ keys: [String]) -> String? {
        for key in keys { if let text = object[key] as? String { return text } }
        return nil
    }

    private static func firstList(_ object: [String: Any], _ keys: [String]) -> [String]? {
        for key in keys {
            if let list = object[key] as? [Any] {
                return list.compactMap { BM25Index.string(from: $0) }
            }
            if let text = object[key] as? String {
                return text.split(whereSeparator: { $0 == ";" || $0 == "|" || $0 == "," })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        return nil
    }

    // MARK: - Kết quả

    public struct QueryResult: Equatable, Sendable {
        public var query: Query
        /// Số hiệu tài liệu trả về, theo thứ hạng.
        public var retrieved: [Int]
        /// Thứ hạng (1-based) của kết quả đúng ĐẦU TIÊN. `nil` = không có trong top-k.
        public var firstHitRank: Int?
        /// Số id kỳ vọng chạm được trong top-k.
        public var hitCount: Int
        /// Số id kỳ vọng CÓ trong corpus. Trần của `hitCount`.
        public var reachableCount: Int
        /// Id kỳ vọng KHÔNG có trong corpus — kể tên, không giấu.
        public var missingIDs: [String]

        /// `nil` khi không id kỳ vọng nào có trong corpus: câu này KHÔNG chấm được.
        public var recall: Double? {
            reachableCount > 0 ? Double(hitCount) / Double(reachableCount) : nil
        }

        public var reciprocalRank: Double? {
            guard reachableCount > 0 else { return nil }
            guard let rank = firstHitRank else { return 0 }
            return 1 / Double(rank)
        }

        /// nDCG@k với mức liên quan NHỊ PHÂN.
        public var ndcg: Double?

        /// Câu này có bị loại khỏi trung bình không, và vì sao.
        public var excludedReason: String? {
            guard reachableCount == 0 else { return nil }
            return query.relevant.isEmpty
                ? "câu hỏi không khai id kỳ vọng nào"
                : "không id kỳ vọng nào có trong corpus (\(query.relevant.count) id)"
        }
    }

    public struct Summary: Equatable, Sendable {
        public var k: Int
        public var queryCount: Int
        /// Số câu được tính vào trung bình.
        public var scoredCount: Int
        public var recall: Double
        public var mrr: Double
        public var ndcg: Double
        /// Trần recall do `k` nhỏ hơn số id kỳ vọng — 1,0 nghĩa là `k` đủ rộng.
        public var ceiling: Double
        /// Tổng số id kỳ vọng không tìm thấy trong corpus.
        public var missingIDCount: Int
        public var elapsedMs: Double
        public var configuration: String
    }

    public struct Report: Equatable, Sendable {
        public var summary: Summary
        /// Theo thứ tự TỆ NHẤT TRƯỚC — đặc tả đòi *"sắp theo câu tệ nhất để sửa corpus có
        /// trọng tâm"*. Câu KHÔNG chấm được nằm trên cùng: chúng là lỗi của bộ đánh giá, và
        /// sửa chúng trước thì mọi con số phía sau mới đáng tin.
        public var queries: [QueryResult]
        public var wasCancelled: Bool
    }

    // MARK: - Chạy

    /// Chạy cả bộ đánh giá trên một chỉ mục.
    ///
    /// - Parameter identifierMap: bản đồ id → tài liệu, lấy từ `BM25Index.identifierMap()`.
    ///   Nhận từ ngoài chứ không tự dựng, vì một lượt so hai cấu hình dùng chung CÙNG corpus và
    ///   dựng lại bản đồ hai lần là quét corpus thừa một lượt.
    public static func run(
        index: BM25Index, golden: [Query], k: Int = 10,
        identifierMap: [String: [Int]],
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> Report {
        run(golden: golden, k: k, identifierMap: identifierMap,
            configuration: describe(index.options), cancelToken: cancelToken,
            progress: progress) { question, limit in
            index.search(question, k: limit).map(\.document)
        }
    }

    /// Chạy bộ đánh giá với MỘT BỘ TRUY HỒI BẤT KỲ.
    ///
    /// Có mặt vì FR-KNW-925 đòi so **A/B/C trên CÙNG golden set**: BM25 thuần, lai với α mặc
    /// định, và lai với α tuỳ chỉnh. Ba lượt ấy phải đi qua đúng một bộ chấm điểm — nếu không
    /// thì bảng delta đang so hai phép đo khác nhau chứ không so hai bộ truy hồi.
    public static func run(
        golden: [Query], k: Int = 10, identifierMap: [String: [Int]],
        configuration: String,
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil,
        retrieve: (_ question: String, _ k: Int) -> [Int]
    ) -> Report {
        let started = DispatchTime.now().uptimeNanoseconds
        var results: [QueryResult] = []
        results.reserveCapacity(golden.count)
        var cancelled = false
        var ceilingSum = 0.0
        var ceilingCount = 0

        for (position, query) in golden.enumerated() {
            if cancelToken?.isCancelled == true { cancelled = true; break }
            if let progress, position % 16 == 0,
               !progress(Double(position) / Double(max(golden.count, 1))) {
                cancelled = true
                break
            }
            var reachable: [Int: String] = [:]      // tài liệu → id kỳ vọng
            var missing: [String] = []
            for identifier in query.relevant {
                if let documents = identifierMap[identifier] {
                    for document in documents { reachable[document] = identifier }
                } else {
                    missing.append(identifier)
                }
            }
            let reachableIDs = Set(reachable.values)
            let hits = retrieve(query.question, k)

            var seen: Set<String> = []
            var firstRank: Int?
            var gain = 0.0
            for (offset, document) in hits.enumerated() {
                guard let identifier = reachable[document] else { continue }
                if firstRank == nil { firstRank = offset + 1 }
                // Một id chạm được nhiều lần chỉ tính MỘT — nếu không, một corpus nhân bản
                // chunk lên ba lần sẽ có recall cao hơn mà không truy hồi tốt hơn chút nào.
                guard seen.insert(identifier).inserted else { continue }
                gain += 1 / (Foundation.log2(Double(offset + 1) + 1))
            }
            var ndcg: Double?
            if !reachableIDs.isEmpty {
                var ideal = 0.0
                for rank in 0 ..< min(k, reachableIDs.count) {
                    ideal += 1 / (Foundation.log2(Double(rank + 1) + 1))
                }
                ndcg = ideal > 0 ? gain / ideal : 0
                ceilingSum += Double(min(k, reachableIDs.count)) / Double(reachableIDs.count)
                ceilingCount += 1
            }
            results.append(QueryResult(
                query: query, retrieved: hits, firstHitRank: firstRank,
                hitCount: seen.count, reachableCount: reachableIDs.count,
                missingIDs: missing, ndcg: ndcg))
        }

        let scored = results.filter { $0.recall != nil }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        let summary = Summary(
            k: k, queryCount: results.count, scoredCount: scored.count,
            recall: mean(scored.compactMap(\.recall)),
            mrr: mean(scored.compactMap(\.reciprocalRank)),
            ndcg: mean(scored.compactMap(\.ndcg)),
            ceiling: ceilingCount > 0 ? ceilingSum / Double(ceilingCount) : 1,
            missingIDCount: results.reduce(0) { $0 + $1.missingIDs.count },
            elapsedMs: elapsed,
            configuration: configuration)

        // Tệ nhất lên trước, và câu KHÔNG chấm được lên trên cùng.
        let ordered = results.sorted { left, right in
            let leftScore = left.recall ?? -1
            let rightScore = right.recall ?? -1
            if leftScore != rightScore { return leftScore < rightScore }
            let leftRank = left.reciprocalRank ?? -1
            let rightRank = right.reciprocalRank ?? -1
            if leftRank != rightRank { return leftRank < rightRank }
            return left.query.id < right.query.id
        }
        return Report(summary: summary, queries: ordered, wasCancelled: cancelled)
    }

    public static func describe(_ options: BM25Index.Options) -> String {
        "k1=\(trim(options.k1)) · b=\(trim(options.b)) · "
            + "\(BM25Tokenizer.name)\(options.tokenizer.foldDiacritics ? " (bỏ dấu)" : "")"
            + " · trường «\(options.textField)»"
    }

    /// Số ngắn gọn cho khối YAML sinh ra: `1` chứ không `1.0`, `0.75` chứ không `0.750000`.
    public static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    // MARK: - So hai cấu hình

    public struct Comparison: Equatable, Sendable {
        public struct Row: Equatable, Sendable {
            public var query: Query
            public var left: Double?
            public var right: Double?
            public var delta: Double?
        }
        public var left: Summary
        public var right: Summary
        /// Theo |delta| GIẢM DẦN: chỗ hai cấu hình khác nhau nhiều nhất là chỗ đáng xem.
        public var rows: [Row]

        public var recallDelta: Double { right.recall - left.recall }
        public var mrrDelta: Double { right.mrr - left.mrr }
        public var ndcgDelta: Double { right.ndcg - left.ndcg }
    }

    /// So hai lượt chạy trên CÙNG bộ đánh giá.
    ///
    /// Ghép theo `Query.id`, không theo vị trí: hai lượt chạy có thể sắp khác nhau (cả hai đều
    /// sắp tệ-nhất-trước), nên ghép theo vị trí sẽ so nhầm câu với câu.
    public static func compare(_ left: Report, _ right: Report) -> Comparison {
        var rightByID: [String: QueryResult] = [:]
        for result in right.queries { rightByID[result.query.id] = result }
        var rows: [Comparison.Row] = []
        for result in left.queries {
            let other = rightByID[result.query.id]
            let a = result.recall
            let b = other?.recall
            rows.append(Comparison.Row(
                query: result.query, left: a, right: b,
                delta: (a != nil && b != nil) ? b! - a! : nil))
        }
        rows.sort {
            let leftDelta = abs($0.delta ?? -1)
            let rightDelta = abs($1.delta ?? -1)
            return leftDelta != rightDelta ? leftDelta > rightDelta
                : $0.query.id < $1.query.id
        }
        return Comparison(left: left.summary, right: right.summary, rows: rows)
    }

    // MARK: - Công thức, in ra cùng kết quả

    /// NFR-DQR-03 đòi mọi điểm số nói ra cách nó được tính; ba chỉ số này cũng vậy.
    public static let formulas: [(name: String, formula: String, note: String)] = [
        ("recall@k", "|{id kỳ vọng} ∩ {id trong top-k}| ÷ |{id kỳ vọng CÓ trong corpus}|",
         "Mẫu số là số id TÌM THẤY ĐƯỢC, không phải số id khai trong bộ đánh giá — id không "
            + "có trong corpus là lỗi của bộ đánh giá, không phải của bộ truy hồi."),
        ("MRR", "trung bình của 1 ÷ (thứ hạng kết quả đúng ĐẦU TIÊN); 0 nếu không có trong top-k",
         "MRR chỉ nhìn kết quả đúng đầu tiên — nó đo «có thấy ngay không», không đo «thấy được "
            + "bao nhiêu»."),
        ("nDCG@k", "DCG ÷ IDCG, DCG = Σ 1 ÷ log₂(hạng + 1) trên các kết quả đúng",
         "Mức liên quan NHỊ PHÂN (đúng/sai), vì golden set chỉ khai danh sách id chứ không khai "
            + "thang điểm."),
    ]
}
