import Foundation

/// Truy hồi lai BM25 × tín hiệu đồ thị — FR-KNW-925.
///
/// Đặc tả gọi đây là *"trái tim GraphRAG zero-embedding"*, và cho hẳn công thức:
///
/// ```
/// score(q,d) = α · norm(BM25(q,d)) + (1 − α) · G(q,d)
/// ```
///
/// trong đó `norm` là min-max trên **top-N ứng viên BM25** (N mặc định 500), và `G(q,d)` là tỷ
/// lệ entity của chunk `d` nằm trong vùng láng giềng k-hop của những entity xuất hiện trong câu
/// hỏi, **trọng số 1 / khoảng-cách-hop**.
///
/// ## Vì sao entity của chunk chỉ rút trên ỨNG VIÊN, không rút trước cho cả corpus
///
/// Cách hiển nhiên là dựng sẵn bảng `chunk → entity` cho cả corpus. Trên 690.000 chunk × 200
/// token, đó là hàng trăm triệu phép tra chỉ để phục vụ 500 chunk mà một câu hỏi thật sự chạm
/// tới — và bảng ấy phải dựng lại mỗi khi corpus đổi.
///
/// Phép lai chỉ xếp lại **top-N ứng viên**. Nên entity được rút NGAY LÚC HỎI, trên đúng ngần ấy
/// chunk. 500 chunk × 200 token là vài trăm nghìn phép tra — vài mili-giây, nằm gọn trong trần
/// 300 ms của NFR-KNW-05, và không có bảng nào phải nuôi.
///
/// ## Phép lai chỉ XẾP LẠI thứ mà BM25 đã tìm ra
///
/// Giới hạn này phải nói ra vì nó không hiển nhiên: một chunk mà BM25 KHÔNG đưa vào top-N thì
/// tín hiệu đồ thị mạnh đến mấy cũng không cứu được — nó không có mặt để mà xếp lại. Nói cách
/// khác, phép lai cải thiện THỨ TỰ chứ không cải thiện ĐỘ PHỦ.
///
/// Muốn nó cứu được những chunk BM25 bỏ sót thì phải nới `candidateCount`, và cái giá là thời
/// gian xếp lại tăng tuyến tính theo N.
///
/// ## Ràng buộc α = 1 là ràng buộc ĐÁNG GIÁ nhất của cả tính năng
///
/// Đặc tả viết: *"α = 1 phải cho kết quả trùng BM25 thuần (kiểm bằng test)"*. Đó là cái neo:
/// một phép lai không quy về được baseline của nó là một phép lai mà không ai kiểm được. Nó
/// bắt `norm` phải ĐƠN ĐIỆU (min-max là phép biến đổi tuyến tính tăng, nên thứ tự không đổi) và
/// bắt luật phá hoà phải GIỐNG HỆT bản BM25 thuần.
public enum HybridRetrieval {

    public struct Config: Equatable, Sendable {
        /// Trọng số của BM25. 1 = BM25 thuần, 0 = chỉ tín hiệu đồ thị.
        public var alpha: Double
        /// Số ứng viên BM25 đưa vào xếp lại.
        public var candidateCount: Int
        /// Bán kính láng giềng, đặc tả cho 1–2.
        public var hops: Int

        public init(alpha: Double = 0.7, candidateCount: Int = 500, hops: Int = 2) {
            self.alpha = min(1, max(0, alpha))
            self.candidateCount = max(1, candidateCount)
            self.hops = min(2, max(1, hops))
        }
    }

    public struct Hit: Equatable, Sendable {
        public var document: Int
        /// Điểm lai cuối cùng.
        public var score: Double
        public var bm25: Double
        /// BM25 đã chuẩn hoá min-max trên tập ứng viên.
        public var normalizedBM25: Double
        /// Tín hiệu đồ thị, 0…1.
        public var graphSignal: Double
        /// Entity của chunk nằm trong vùng láng giềng, kèm khoảng cách hop.
        public var matchedEntities: [(name: String, hops: Int)]
        /// Số entity của chunk — mẫu số của `graphSignal`.
        public var entityCount: Int

        public static func == (left: Hit, right: Hit) -> Bool {
            left.document == right.document && left.score == right.score
                && left.bm25 == right.bm25 && left.normalizedBM25 == right.normalizedBM25
                && left.graphSignal == right.graphSignal
                && left.entityCount == right.entityCount
                && left.matchedEntities.map(\.name) == right.matchedEntities.map(\.name)
                && left.matchedEntities.map(\.hops) == right.matchedEntities.map(\.hops)
        }
    }

    public struct Result: Equatable, Sendable {
        public var hits: [Hit]
        /// Entity nhận ra trong câu hỏi.
        public var queryEntities: [String]
        /// Số node trong vùng láng giềng k-hop.
        public var neighbourhoodSize: Int
        public var config: Config
        public var methodology: String
        /// Mili-giây cho riêng phần XẾP LẠI, không tính lượt BM25 — NFR-KNW-05 chấm chỗ này.
        public var rerankMilliseconds: Double
    }

    // MARK: - Danh sách entity

    /// Bảng tra entity: chuỗi token đã chuẩn hoá → số hiệu node trên đồ thị.
    ///
    /// ## Entity lấy từ chính TÊN NODE của đồ thị
    ///
    /// Đặc tả nói *"theo danh sách entity marker"*, và FR-KNW-920 (nơi định nghĩa danh sách ấy)
    /// là Phase 4 chưa có mã. Ở đây danh sách mặc định là **tên và nhãn của node trên đồ thị** —
    /// với một đồ thị tri thức thì đó chính là tập entity, và nó không phải bịa ra từ đâu.
    ///
    /// Khi FR-KNW-920 có mã, chỗ thay là hàm này; `entityListSource` nói ra danh sách đang dùng
    /// đến từ đâu, nên báo cáo không bao giờ im lặng về điều đó.
    public struct EntityDictionary: Sendable {
        /// Chuỗi token nối bằng dấu cách → số hiệu node.
        let byTokens: [String: Int]
        /// Số token dài nhất của một entity — giới hạn cửa sổ quét.
        let longest: Int
        public let source: String
        let tokenizer: BM25Tokenizer

        public var count: Int { byTokens.count }
    }

    public static func dictionary(
        for graph: GraphCSR, tokenizer: BM25Tokenizer = BM25Tokenizer(),
        extraMarkers: [String] = []
    ) -> EntityDictionary {
        var byTokens: [String: Int] = [:]
        var longest = 1
        func add(_ text: String, node: Int) {
            let tokens = tokenizer.tokens(in: text)
            guard !tokens.isEmpty else { return }
            longest = max(longest, tokens.count)
            let key = tokens.joined(separator: " ")
            // Hai node cùng chuỗi token: giữ node có SỐ HIỆU NHỎ hơn. Tất định, và trùng tên
            // trong một đồ thị vốn đã là chuyện đáng ngờ — FR-KNW-923 lo việc gộp chúng.
            if let existing = byTokens[key] { byTokens[key] = min(existing, node) }
            else { byTokens[key] = node }
        }
        for node in 0 ..< graph.nodeCount {
            add(graph.names[node], node: node)
            if graph.displays[node] != graph.names[node] {
                add(graph.displays[node], node: node)
            }
        }
        var source = "tên và nhãn node của đồ thị (\(graph.nodeCount) node)"
        if !extraMarkers.isEmpty {
            // Marker phụ trỏ tới node cùng tên nếu có; không có thì bỏ, vì một entity không nằm
            // trên đồ thị thì không sinh ra tín hiệu đồ thị nào.
            var attached = 0
            for marker in extraMarkers {
                let tokens = tokenizer.tokens(in: marker).joined(separator: " ")
                guard let node = byTokens[tokens] else { continue }
                byTokens[tokens] = node
                attached += 1
            }
            source += " + \(attached)/\(extraMarkers.count) marker khai thêm"
        }
        return EntityDictionary(
            byTokens: byTokens, longest: longest, source: source, tokenizer: tokenizer)
    }

    /// Entity xuất hiện trong một đoạn văn bản.
    ///
    /// Quét cửa sổ token từ DÀI tới NGẮN: entity «Ngân hàng Nhà nước» phải thắng «Ngân hàng» khi
    /// cả hai đều có trong danh sách. Khớp ngắn trước thì entity dài không bao giờ được nhận, và
    /// tín hiệu đồ thị sẽ trỏ vào một node chung chung.
    public static func entities(
        in text: String, using dictionary: EntityDictionary
    ) -> [Int] {
        let tokens = dictionary.tokenizer.tokens(in: text)
        guard !tokens.isEmpty else { return [] }
        var out: [Int] = []
        var seen = Set<Int>()
        var index = 0
        while index < tokens.count {
            var matched = false
            var width = min(dictionary.longest, tokens.count - index)
            while width >= 1 {
                let key = tokens[index ..< (index + width)].joined(separator: " ")
                if let node = dictionary.byTokens[key] {
                    if seen.insert(node).inserted { out.append(node) }
                    index += width
                    matched = true
                    break
                }
                width -= 1
            }
            if !matched { index += 1 }
        }
        return out.sorted()
    }

    // MARK: - Tìm

    public static func search(
        _ query: String, k: Int = 10,
        index: BM25Index, graph: GraphCSR, dictionary: EntityDictionary,
        config: Config = Config(), cancelToken: CancelToken? = nil
    ) -> Result {
        let candidates = index.search(query, k: config.candidateCount)
        let started = DispatchTime.now().uptimeNanoseconds

        // --- Vùng láng giềng của entity trong câu hỏi ---
        let queryEntities = entities(in: query, using: dictionary)
        // KHÔNG nhận ra entity nào thì không có tín hiệu đồ thị, và α bao nhiêu cũng vậy.
        //
        // Không có vế này thì với α = 0 mọi chunk cùng điểm 0 và bảng kết quả rơi về THỨ TỰ SỐ
        // HIỆU TÀI LIỆU — một danh sách trông như một bảng xếp hạng nhưng không mang tin gì.
        // Và tệ hơn: khối Phương pháp đã nói "kết quả rơi về đúng BM25 thuần", nên mã và lời
        // giải thích của chính nó nói hai điều khác nhau.
        let alpha = queryEntities.isEmpty ? 1 : config.alpha
        var hopOf: [Int: Int] = [:]
        for node in queryEntities { hopOf[node] = 0 }
        if !queryEntities.isEmpty {
            let neighbourhood = GraphAlgorithms.neighbourhood(
                of: queryEntities, k: config.hops, in: graph, cancelToken: cancelToken)
            for entry in neighbourhood.nodes where hopOf[entry.node] == nil {
                hopOf[entry.node] = entry.hops
            }
        }

        // --- Chuẩn hoá min-max trên tập ứng viên ---
        let scores = candidates.map(\.score)
        let lowest = scores.min() ?? 0
        let highest = scores.max() ?? 0
        let span = highest - lowest

        var hits: [Hit] = []
        hits.reserveCapacity(candidates.count)
        for candidate in candidates {
            // Dải bằng 0 (mọi ứng viên cùng điểm) thì chuẩn hoá thành 1 cho tất cả — giữ đúng
            // thứ tự của BM25 thuần, và đó là điều kiện để ràng buộc α = 1 đứng vững.
            let normalized = span > 0 ? (candidate.score - lowest) / span : 1
            var signal = 0.0
            var matched: [(name: String, hops: Int)] = []
            var entityCount = 0
            if !hopOf.isEmpty, let text = index.text(of: candidate.document) {
                let found = entities(in: text, using: dictionary)
                entityCount = found.count
                if !found.isEmpty {
                    var sum = 0.0
                    for node in found {
                        guard let hops = hopOf[node] else { continue }
                        // Trọng số 1 / khoảng-cách-hop; entity NGAY TRONG câu hỏi (hop 0) tính
                        // trọn vẹn 1 — chia cho 0 thì vô nghĩa, và một entity trùng khớp hẳn là
                        // tín hiệu mạnh nhất có thể.
                        sum += hops == 0 ? 1 : 1 / Double(hops)
                        matched.append((graph.displays[node], hops))
                    }
                    signal = min(1, sum / Double(found.count))
                }
            }
            let score = alpha * normalized + (1 - alpha) * signal
            hits.append(Hit(
                document: candidate.document, score: score, bm25: candidate.score,
                normalizedBM25: normalized, graphSignal: signal,
                matchedEntities: matched, entityCount: entityCount))
        }

        // Luật phá hoà GIỐNG HỆT `BM25Index.search`: điểm bằng nhau thì số hiệu tài liệu nhỏ
        // hơn thắng. Không giống thì ràng buộc α = 1 vỡ ở đúng những chỗ hoà điểm.
        hits.sort { $0.score != $1.score ? $0.score > $1.score : $0.document < $1.document }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000

        return Result(
            hits: Array(hits.prefix(max(0, k))),
            queryEntities: queryEntities.map { graph.displays[$0] },
            neighbourhoodSize: hopOf.count, config: config,
            methodology: methodology(config: config, dictionary: dictionary,
                                     entities: queryEntities.count, region: hopOf.count),
            rerankMilliseconds: elapsed)
    }

    static func methodology(
        config: Config, dictionary: EntityDictionary, entities: Int, region: Int
    ) -> String {
        var text = "score = \(format(config.alpha)) × norm(BM25) + "
            + "\(format(1 - config.alpha)) × G. norm là min-max trên "
            + "\(config.candidateCount) ứng viên BM25 đầu. "
            + "G = tỷ lệ entity của chunk nằm trong vùng \(config.hops)-hop của entity trong câu "
            + "hỏi, trọng số 1/hop. Danh sách entity: \(dictionary.source). "
            + "Phép lai chỉ XẾP LẠI \(config.candidateCount) ứng viên BM25 — chunk nằm ngoài "
            + "danh sách ấy thì tín hiệu đồ thị không cứu được."
        if entities == 0 {
            text += " ⚠ KHÔNG nhận ra entity nào trong câu hỏi, nên G = 0 với mọi chunk và kết "
                + "quả rơi về đúng BM25 thuần."
        } else {
            text += " Câu hỏi chạm \(entities) entity, vùng láng giềng \(region) node."
        }
        return text
    }

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}


// MARK: - Đánh giá A/B/C — FR-KNW-925

extension HybridRetrieval {

    public struct Trial: Equatable, Sendable {
        public var name: String
        public var report: RetrievalEval.Report
        /// Câu ĐA HOP: có ít nhất một chunk đúng chỉ chạm tới vùng láng giềng ở hop ≥ 2.
        public var multiHopQueryIDs: Set<String>

        /// Recall chỉ tính trên nhóm câu ĐA HOP.
        public var multiHopRecall: Double {
            let values = report.queries
                .filter { multiHopQueryIDs.contains($0.query.id) }
                .compactMap(\.recall)
            return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
    }

    public struct Bakeoff: Equatable, Sendable {
        public var trials: [Trial]
        /// So từng cặp với lượt ĐẦU (BM25 thuần) theo từng câu.
        public var comparisons: [RetrievalEval.Comparison]
        public var methodology: String
    }

    /// Chạy A/B/C trên CÙNG bộ đánh giá.
    ///
    /// ## Vì sao nhóm câu «đa hop» phải tách riêng
    ///
    /// Đặc tả đòi *"nhóm câu «đa hop» tách riêng"*, và lý do nằm ở chính thứ đang đo: tín hiệu
    /// đồ thị chỉ có việc làm khi câu trả lời KHÔNG nằm ngay cạnh entity của câu hỏi. Trộn hai
    /// nhóm lại thì một cải thiện lớn trên 10% số câu bị trung bình hoá thành một cải thiện
    /// nhỏ trên tất cả — và người đọc kết luận "phép lai không đáng".
    ///
    /// Câu được đánh dấu đa hop khi ít nhất một chunk ĐÚNG của nó chỉ chạm vùng láng giềng ở
    /// hop ≥ 2. Đó là định nghĩa tính được từ chính dữ liệu, không phải một nhãn gán tay.
    public static func bakeoff(
        golden: [RetrievalEval.Query], k: Int = 10,
        index: BM25Index, graph: GraphCSR, dictionary: EntityDictionary,
        identifierMap: [String: [Int]],
        alphas: [Double] = [0.7, 0.4],
        cancelToken: CancelToken? = nil
    ) -> Bakeoff {
        var trials: [Trial] = []

        trials.append(Trial(
            name: "BM25 thuần",
            report: RetrievalEval.run(
                index: index, golden: golden, k: k, identifierMap: identifierMap,
                cancelToken: cancelToken),
            multiHopQueryIDs: []))

        for alpha in alphas {
            let config = Config(alpha: alpha)
            var multiHop = Set<String>()
            let report = RetrievalEval.run(
                golden: golden, k: k, identifierMap: identifierMap,
                configuration: "lai α=\(format(alpha)) · \(config.hops)-hop",
                cancelToken: cancelToken
            ) { question, limit in
                let result = search(
                    question, k: limit, index: index, graph: graph, dictionary: dictionary,
                    config: config, cancelToken: cancelToken)
                return result.hits.map(\.document)
            }
            // Đánh dấu câu đa hop bằng một lượt quét riêng: cần biết chunk ĐÚNG chạm vùng láng
            // giềng ở hop nào, mà `retrieve` chỉ trả về số hiệu tài liệu.
            for query in golden {
                let result = search(
                    query.question, k: config.candidateCount, index: index, graph: graph,
                    dictionary: dictionary, config: config, cancelToken: cancelToken)
                let relevant = Set(query.relevant.flatMap { identifierMap[$0] ?? [] })
                let deep = result.hits.contains { hit in
                    relevant.contains(hit.document)
                        && !hit.matchedEntities.isEmpty
                        && hit.matchedEntities.allSatisfy { $0.hops >= 2 }
                }
                if deep { multiHop.insert(query.id) }
            }
            trials.append(Trial(name: "lai α=\(format(alpha))", report: report,
                                multiHopQueryIDs: multiHop))
        }

        let comparisons = trials.dropFirst().map {
            RetrievalEval.compare(trials[0].report, $0.report)
        }
        return Bakeoff(
            trials: trials, comparisons: comparisons,
            methodology: "Ba lượt trên CÙNG bộ đánh giá và CÙNG bộ chấm điểm. Câu «đa hop» là "
                + "câu có ít nhất một chunk đúng chỉ chạm vùng láng giềng ở hop ≥ 2 — định "
                + "nghĩa tính được từ dữ liệu, không phải nhãn gán tay. Trộn hai nhóm lại thì "
                + "một cải thiện lớn trên vài phần trăm số câu bị trung bình hoá thành gần như "
                + "không có gì.")
    }
}
