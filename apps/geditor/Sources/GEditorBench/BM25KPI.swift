import Foundation
import GEditorCore

/// PoC-M — BM25 có đạt NFR-KNW-04 không, và điểm có ĐỐI CHỨNG được không.
///
/// NFR-KNW-04 đặt bốn con số, và bộ đo này trả lời cả bốn:
///
/// 1. dựng chỉ mục cho corpus **1 GB ≤ 30 giây**,
/// 2. truy vấn top-k **≤ 500 ms**,
/// 3. điểm **tất định**,
/// 4. và điểm **đối chứng được với cài đặt tham chiếu, sai số ≤ 1e-9**.
///
/// ## Vế thứ tư là vế đáng làm nhất, và nó cần một cài đặt THỨ HAI
///
/// Ba vế đầu là đo tốc độ — chúng nói bộ máy có nhanh không, không nói nó có ĐÚNG không. Một
/// cài đặt BM25 sai công thức vẫn chạy nhanh và vẫn tất định; nó chỉ xếp hạng sai, và không có
/// gì trong sản phẩm chỉ ra điều đó.
///
/// Nên bộ đo xuất corpus nhỏ cùng bảng điểm ra JSON, và `scripts/run-poc-m.sh` chấm lại bằng
/// một cài đặt **viết độc lập bằng Python** từ chính công thức trong sách. Hai bản, hai ngôn
/// ngữ, một công thức — lệch nhau ở đâu là ở đó có người hiểu sai.
enum BM25KPI {

    static func run(arguments: [String]) {
        let sizeMB = intOption("--mb", in: arguments, default: 1_024)
        // Cỡ khối gom trước khi đổ ra một run trên đĩa. Có mặt ở đây vì nó là NÚM ĐÁNH ĐỔI
        // giữa RAM và số lần trộn, và câu hỏi "trộn tốn bao nhiêu" chỉ trả lời được bằng cách
        // đo hai đầu của núm ấy chứ không bằng cách đọc mã.
        let blockMB = intOption("--block-mb", in: arguments, default: 64)
        let options = BM25Index.Options(blockBudget: blockMB << 20)
        let cache = ".build/poc-m"
        try? FileManager.default.createDirectory(
            atPath: cache, withIntermediateDirectories: true)

        // --- Corpus ------------------------------------------------------------------------
        //
        // Sinh bằng bộ sinh có SEED cố định: hai lần chạy phải cho cùng một corpus, nếu không
        // thì hai lần đo không so được với nhau. Cùng lối `SeededGenerator` của FR-MIN-002.
        let corpus = cache + "/corpus-\(sizeMB)mb.jsonl"
        let existing = (try? FileManager.default.attributesOfItem(atPath: corpus)[.size] as? Int)
            ?? nil
        if existing == nil || (existing ?? 0) < sizeMB * 1_000_000 {
            FileHandle.standardError.write(Data("▸ Sinh corpus \(sizeMB) MB…\n".utf8))
            generateCorpus(path: corpus, megabytes: sizeMB)
        }
        let corpusBytes = (try? FileManager.default
            .attributesOfItem(atPath: corpus)[.size] as? Int) ?? 0 ?? 0

        // --- 1. Dựng chỉ mục ---------------------------------------------------------------
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: corpus))
        let buildStart = DispatchTime.now().uptimeNanoseconds
        let rssBefore = residentMB()
        guard let index = try? BM25Index.build(corpus: corpus, options: options) else {
            FileHandle.standardError.write(Data("❌ không dựng được chỉ mục\n".utf8))
            exit(1)
        }
        let buildMs = Double(DispatchTime.now().uptimeNanoseconds - buildStart) / 1_000_000
        let rssPeak = peakResidentMB()
        let indexBytes = (try? FileManager.default
            .attributesOfItem(atPath: BM25Index.indexPath(for: corpus))[.size] as? Int) ?? 0 ?? 0

        // --- 2. Truy vấn --------------------------------------------------------------------
        //
        // Đo trên chỉ mục ĐỌC LẠI TỪ ĐĨA, không dùng bản còn nóng trong bộ nhớ: người dùng thật
        // mở app rồi mới hỏi, nên con số đáng tin là con số của đường ấy.
        guard let reloaded = BM25Index.load(corpus: corpus) else {
            FileHandle.standardError.write(Data("❌ không đọc lại được chỉ mục\n".utf8))
            exit(1)
        }
        // Câu hỏi lấy từ CHÍNH từ vựng của corpus, trộn từ phổ biến với từ hiếm: một bộ câu
        // hỏi toàn từ không có trong corpus sẽ đo đúng đường "không tìm thấy gì" và không đo gì.
        let queries = [
            "hopdong quyetdinh", "bienban bangiao", "thuyloi khoangsan",
            "nganhang thanhtoan chuyenkhoan", "so ngay thang nam",
        ]
        var queryMs: [Double] = []
        var topHits: [[String: Any]] = []
        for query in queries {
            let start = DispatchTime.now().uptimeNanoseconds
            let hits = reloaded.search(query, k: 10)
            queryMs.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            topHits.append([
                "query": query,
                "hits": hits.prefix(3).map {
                    ["doc": $0.document, "score": $0.score] as [String: Any]
                },
            ])
        }

        // --- 3. Tất định ---------------------------------------------------------------------
        var deterministic = true
        let reference = reloaded.search(queries[0], k: 10)
        for _ in 0 ..< 20 {
            let again = reloaded.search(queries[0], k: 10)
            if again.map(\.document) != reference.map(\.document) { deterministic = false }
            for (a, b) in zip(again, reference) where a.score != b.score {
                deterministic = false
            }
        }

        // --- 4. Bảng đối chứng ----------------------------------------------------------------
        //
        // Corpus NHỎ và riêng, để bản Python chấm lại được trong vài giây. Đối chứng không cần
        // cỡ lớn — nó cần đủ ca: từ hiếm, từ phổ biến, tài liệu dài, tài liệu ngắn, từ lặp.
        let checkCorpus = cache + "/doi-chung.jsonl"
        generateCorpus(path: checkCorpus, megabytes: 0, documents: 500)
        try? FileManager.default.removeItem(atPath: BM25Index.indexPath(for: checkCorpus))
        guard let small = try? BM25Index.build(corpus: checkCorpus) else {
            FileHandle.standardError.write(Data("❌ không dựng được chỉ mục đối chứng\n".utf8))
            exit(1)
        }
        var checkRows: [[String: Any]] = []
        for query in queries {
            for hit in small.search(query, k: 20) {
                checkRows.append([
                    "query": query, "doc": hit.document, "score": hit.score,
                ])
            }
        }

        let medianQuery = queryMs.sorted()[queryMs.count / 2]

        // --- Đánh giá golden set: vế thứ ba của NFR-KNW-04 -------------------------------
        //
        // "đánh giá golden set 1.000 câu ≤ 60 giây". Bộ đánh giá SINH RA từ chính corpus: lấy
        // vài từ đầu của một chunk làm câu hỏi, id của chunk ấy làm đáp án. Bộ như thế quá dễ
        // nên recall của nó KHÔNG nói gì về chất lượng truy hồi — nó chỉ đo TỐC ĐỘ, và đó đúng
        // là thứ chỉ tiêu này hỏi. In recall ra để thấy bộ đo không hỏng, không phải để khoe.
        let mapStart = DispatchTime.now().uptimeNanoseconds
        let identifierMap = (try? index.identifierMap()) ?? [:]
        let mapMs = Double(DispatchTime.now().uptimeNanoseconds - mapStart) / 1_000_000
        let golden = syntheticGoldenSet(index: index, count: 1_000)
        let evalStart = DispatchTime.now().uptimeNanoseconds
        let evaluation = RetrievalEval.run(
            index: index, golden: golden, k: 10, identifierMap: identifierMap)
        let evalMs = Double(DispatchTime.now().uptimeNanoseconds - evalStart) / 1_000_000
        let goldenMs = mapMs + evalMs
        let goldenOK = goldenMs <= 60_000

        // --- NFR-KNW-05: xếp lại lai trên top-500 ≤ 300 ms ------------------------------
        //
        // Đồ thị sinh từ chính corpus: mỗi từ khoá hay gặp thành một node, nối thành chuỗi. Nó
        // KHÔNG phải một đồ thị tri thức thật — nó chỉ để đo TỐC ĐỘ xếp lại, và chất lượng truy
        // hồi của nó không nói lên gì. Nói ra ở đây để con số 300 ms không bị đọc thành "phép
        // lai hoạt động tốt".
        let hybridGraph = syntheticGraph(index: index, nodes: 2_000)
        let dictionary = HybridRetrieval.dictionary(for: hybridGraph)
        var rerankMs: [Double] = []
        for question in golden.prefix(50) {
            let result = HybridRetrieval.search(
                question.question, k: 10, index: index, graph: hybridGraph,
                dictionary: dictionary)
            rerankMs.append(result.rerankMilliseconds)
        }
        let medianRerank = rerankMs.isEmpty ? 0 : rerankMs.sorted()[rerankMs.count / 2]
        let worstRerank = rerankMs.max() ?? 0
        let hybridOK = worstRerank <= 300

        let pass = buildMs <= 30_000 && medianQuery <= 500 && deterministic && goldenOK
            && hybridOK
        var out: [String: Any] = [
            "poc": "PoC-M — BM25 Retrieval Lab (FR-KNW-918, NFR-KNW-04)",
            "architecture": architecture(),
            "corpusBytes": corpusBytes,
            "documentCount": index.documentCount,
            "termCount": index.manifest.termCount,
            "totalTokens": index.manifest.totalTokens,
            "buildMs": buildMs,
            "phases": [
                "readMs": BM25Index.lastBuildStats.readMs,
                "recordMs": BM25Index.lastBuildStats.recordMs,
                "splitMs": BM25Index.lastBuildStats.splitMs,
                "parseMs": BM25Index.lastBuildStats.parseMs,
                "tokenizeMs": BM25Index.lastBuildStats.tokenizeMs,
                "postingMs": BM25Index.lastBuildStats.postingMs,
                "flushMs": BM25Index.lastBuildStats.flushMs,
                "mergeMs": BM25Index.lastBuildStats.mergeMs,
                "writeMs": BM25Index.lastBuildStats.writeMs,
            ],
            "buildBudgetMs": 30_000,
            "indexBytes": indexBytes,
            "indexRatio": corpusBytes > 0 ? Double(indexBytes) / Double(corpusBytes) : 0,
            "queryMs": queryMs,
            "queryMedianMs": medianQuery,
            "queryBudgetMs": 500,
            "deterministic": deterministic,
            "rssBeforeMB": rssBefore,
            "rssPeakMB": rssPeak,
            "goldenMs": goldenMs,
            "goldenBudgetMs": 60_000,
            "goldenIdentifierMapMs": mapMs,
            "goldenQueryCount": golden.count,
            "goldenRecall": evaluation.summary.recall,
            "goldenScoredCount": evaluation.summary.scoredCount,
            "hybridRerankMedianMs": medianRerank,
            "hybridRerankWorstMs": worstRerank,
            "hybridRerankBudgetMs": 300,
            "hybridEntityCount": dictionary.count,
            "topHits": topHits,
            "checkCorpus": checkCorpus,
            "checkRows": checkRows,
            "notes": [
                "Corpus sinh bằng bộ sinh có seed cố định — hai lần đo so được với nhau.",
                "Truy vấn đo trên chỉ mục ĐỌC LẠI TỪ ĐĨA, không dùng bản còn nóng trong bộ nhớ.",
                "Bảng «checkRows» để scripts/run-poc-m.sh chấm lại bằng một cài đặt Python viết "
                    + "độc lập: hai ngôn ngữ, một công thức.",
            ],
            "pass": pass,
        ]
        out["tokenizer"] = BM25Tokenizer().methodology

        let json = (try? JSONSerialization.data(
            withJSONObject: out, options: [.prettyPrinted, .sortedKeys]))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        let folder = "benchmarks/results"
        try? FileManager.default.createDirectory(
            atPath: folder, withIntermediateDirectories: true)
        try? json.write(toFile: folder + "/poc-m-\(architecture()).json",
                        atomically: true, encoding: .utf8)
        print(json)
        exit(pass ? 0 : 1)
    }

    // MARK: - Corpus thử

    /// Sinh corpus JSONL giống dữ liệu hành chính tiếng Việt.
    ///
    /// Không lấy văn bản ngẫu nhiên: BM25 sống bằng phân bố tần suất từ, và một corpus gồm các
    /// từ đều nhau cho ra idf gần bằng nhau ở mọi từ — tức một phép đo không giống thứ nó phải
    /// đo. Bộ sinh này trộn **từ phổ biến** (xuất hiện khắp nơi) với **từ hiếm** (vài tài liệu),
    /// đúng hình dạng Zipf mà corpus thật có.
    /// Đồ thị SINH RA từ những từ khoá hay gặp nhất, chỉ để đo tốc độ xếp lại.
    ///
    /// Node = một từ khoá; cạnh nối từ khoá thứ i với thứ i+1 và i+7 → một đồ thị thưa có đường
    /// kính lớn, nên vùng 2-hop không nuốt trọn đồ thị. Đây KHÔNG phải đồ thị tri thức thật.
    static func syntheticGraph(index: BM25Index, nodes: Int) -> GraphCSR {
        var names: [String] = []
        var seen = Set<String>()
        var document = 0
        while names.count < nodes, document < index.documentCount {
            defer { document += max(1, index.documentCount / (nodes * 2)) }
            guard let text = index.text(of: document) else { continue }
            for token in BM25Tokenizer().tokens(in: text).prefix(4)
            where token.count >= 4 && seen.insert(token).inserted {
                names.append(token)
                if names.count >= nodes { break }
            }
        }
        var edges: [(from: Int, to: Int, weight: Double?)] = []
        for node in 0 ..< names.count {
            edges.append((node, (node + 1) % names.count, nil))
            edges.append((node, (node + 7) % names.count, nil))
        }
        return GraphCSR(names: names, isDirected: false, edges: edges)
    }

    /// Bộ đánh giá SINH RA từ chính corpus, chỉ để đo TỐC ĐỘ — xem chú thích ở chỗ gọi.
    static func syntheticGoldenSet(index: BM25Index, count: Int) -> [RetrievalEval.Query] {
        var out: [RetrievalEval.Query] = []
        out.reserveCapacity(count)
        let step = max(1, index.documentCount / max(count, 1))
        var document = 0
        while out.count < count, document < index.documentCount {
            defer { document += step }
            guard let line = index.record(document),
                  let object = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                    as? [String: Any],
                  let identifier = object[index.options.idField] as? String,
                  let text = object[index.options.textField] as? String
            else { continue }
            let words = text.split(separator: " ").prefix(6)
            guard words.count >= 3 else { continue }
            out.append(RetrievalEval.Query(
                id: "q\(out.count)", question: words.joined(separator: " "),
                relevant: [identifier]))
        }
        return out
    }

    static func generateCorpus(path: String, megabytes: Int, documents: Int = 0) {
        // TỪ VỰNG lớn, phân bố ZIPF — không phải vài chục từ đều nhau.
        //
        // Bản đầu của bộ sinh chỉ có 34 từ, và nó nói dối theo hai hướng cùng lúc: mọi từ có
        // idf gần bằng nhau (BM25 mất chính thứ nó đo), và mỗi danh sách posting dài bằng cả
        // corpus (một hình dạng không corpus thật nào có). Nó cũng che mất — rồi tình cờ phơi
        // ra — một lỗi O(n²) trong bộ dựng chỉ mục.
        //
        // Hạng lấy theo `V^u` với `u` đều trên [0,1): hạng thấp (từ phổ biến) gặp rất nhiều,
        // hạng cao (từ hiếm) gặp thưa dần — xấp xỉ Zipf, đủ đúng cho một phép đo.
        let syllables = ["hop", "dong", "quyet", "dinh", "bien", "ban", "cong", "ty", "dia",
                         "chi", "dieu", "khoan", "thuy", "loi", "khoang", "san", "kiem",
                         "toan", "nhuong", "quyen", "tham", "my", "vien", "thong", "bao",
                         "hiem", "van", "phong", "chuyen", "khoan", "ngan", "hang", "thanh",
                         "pho", "quan", "huyen", "xa", "phuong", "so", "ngay", "thang", "nam"]
        var vocabulary: [String] = []
        vocabulary.reserveCapacity(20_000)
        for first in syllables {
            for second in syllables {
                for third in ["", "a", "b", "c", "d", "e", "g", "h", "k", "m", "n", "p"] {
                    vocabulary.append(third.isEmpty ? "\(first)\(second)"
                                                    : "\(first)\(second)\(third)")
                    if vocabulary.count >= 20_000 { break }
                }
                if vocabulary.count >= 20_000 { break }
            }
            if vocabulary.count >= 20_000 { break }
        }

        var generator = SeededGenerator(seed: 2_026)
        let size = Double(vocabulary.count)
        func nextWord() -> String {
            let rank = Int(pow(size, generator.nextUnit()))
            return vocabulary[min(vocabulary.count - 1, max(0, rank))]
        }

        var out = Data()
        out.reserveCapacity(8 << 20)
        FileManager.default.createFile(atPath: path, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        defer { try? handle.close() }

        let target = megabytes > 0 ? megabytes * 1_000_000 : Int.max
        let limit = documents > 0 ? documents : Int.max
        var written = 0
        var index = 0
        while written < target, index < limit {
            var words: [String] = []
            let length = 60 + Int(generator.nextUnit() * 200)
            for _ in 0 ..< length { words.append(nextWord()) }
            let line = "{\"id\":\"c\(index)\",\"nguon\":\"tep-\(index % 50)\","
                + "\"text\":\"\(words.joined(separator: " "))\"}\n"
            let bytes = Data(line.utf8)
            out.append(bytes)
            written += bytes.count
            index += 1
            if out.count >= (8 << 20) {
                handle.write(out)
                out.removeAll(keepingCapacity: true)
            }
        }
        if !out.isEmpty { handle.write(out) }
    }

    // MARK: - Mảnh

    private static func intOption(_ name: String, in arguments: [String], default value: Int)
        -> Int {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
              let parsed = Int(arguments[index + 1]) else { return value }
        return parsed
    }

    /// RSS **đỉnh trong cả đời tiến trình**, chứ không phải RSS tại thời điểm gọi.
    ///
    /// Bản đầu trả `resident_size` và chỗ gọi đặt tên kết quả là `rssPeak`. Hai thứ ấy khác
    /// nhau, và cái khác nhau ấy không hiền: dò cỡ khối từ 4 tới 1024 MB cho ra dãy RAM
    /// 528 → 1180 → 635 → 943 MB — không đơn điệu, không lặp lại, tức là con số ấy đang đo
    /// trạng thái của bộ cấp phát sau khi dựng xong chứ không đo lượng RAM lượt dựng thật sự
    /// cần. Suýt nữa thì nó thành căn cứ để đổi một giá trị mặc định.
    ///
    /// `resident_size_max` là đỉnh mà nhân đã ghi nhận — nó không tụt khi bộ cấp phát trả trang
    /// về, nên nó so được giữa hai lượt chạy.
    private static func peakResidentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size_max) / 1_048_576
    }

    private static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576
    }

    private static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
