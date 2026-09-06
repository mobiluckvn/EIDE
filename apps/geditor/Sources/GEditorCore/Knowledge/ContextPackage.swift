import Foundation

/// Liên kết Chunk ↔ Entity ↔ Graph, và gói ngữ cảnh cho GraphRAG — FR-KNW-920.
///
/// Đặc tả: *"Ánh xạ ba chiều: entity xuất hiện trong chunk nào ↔ tương ứng node nào trên đồ
/// thị. Phân tích PHỦ: entity không có chunk nào nhắc tới, chunk mồ côi không chứa entity, node
/// đồ thị không có entity đối ứng — ba loại lỗ hổng tri thức phổ biến nhất. TRÍCH context
/// package: từ seed entity, lấy subgraph k-hop + toàn bộ chunk liên quan → xuất JSONL (mỗi
/// record: query_seed, triples[], chunks[])."*
///
/// ## Ở đây quét CẢ corpus, khác hẳn FR-KNW-925
///
/// Phép lai chỉ xếp lại 500 ứng viên, nên nó rút entity ngay lúc hỏi. Phân tích phủ thì hỏi một
/// câu khác hẳn — *"entity nào KHÔNG được chunk nào nhắc tới"* — và câu ấy không trả lời được
/// nếu chỉ nhìn 500 chunk. Nên đây là một lượt quét toàn corpus, chạy một lần, có tiến độ và
/// huỷ.
///
/// ## Định dạng gói ngữ cảnh: phụ lục chỉ nêu BA TÊN TRƯỜNG
///
/// Đặc tả nói *"theo định dạng đặc tả ở phụ lục"* và phụ lục chỉ liệt kê `query_seed`,
/// `triples[]`, `chunks[]`. Phần còn lại — hình dạng của một triple, những trường của một chunk
/// — do tệp này định nghĩa, và định nghĩa ấy viết ra đây chứ không để người đọc dò từ mã:
///
/// ```json
/// {"query_seed": "An",
///  "triples": [{"s": "An", "p": "gửi", "o": "Bình", "hops": 1}],
///  "chunks": [{"id": "c1", "text": "…", "entities": ["An"], "hops": 0}]}
/// ```
///
/// `hops` không có trong phụ lục nhưng được thêm vào cả hai chỗ, vì thiếu nó thì pipeline bên
/// ngoài không phân biệt được "chunk nói thẳng về seed" với "chunk cách seed hai bước" — và đó
/// đúng là thông tin mà một gói ngữ cảnh sinh ra để mang.
public enum ContextPackage {

    // MARK: - Ánh xạ ba chiều

    public struct Links: Sendable {
        /// Node đồ thị → những chunk nhắc tới nó (số hiệu dòng trong corpus).
        public var chunksOfEntity: [Int: [Int]]
        /// Chunk → những node nó nhắc tới.
        public var entitiesOfChunk: [Int: [Int]]
        /// Số chunk đã quét.
        public var chunkCount: Int
        public var wasCancelled: Bool
    }

    /// Dựng ánh xạ bằng MỘT lượt quét corpus.
    public static func link(
        index: BM25Index, graph: GraphCSR,
        dictionary: HybridRetrieval.EntityDictionary,
        cancelToken: CancelToken? = nil, progress: ((Double) -> Bool)? = nil
    ) throws -> Links {
        var chunksOfEntity: [Int: [Int]] = [:]
        var entitiesOfChunk: [Int: [Int]] = [:]
        var chunkCount = 0
        var cancelled = false

        try JSONLReader.forEachLine(
            path: index.corpusPath, cancelToken: cancelToken, progress: progress
        ) { line in
            defer { chunkCount += 1 }
            guard !line.bytes.isEmpty,
                  let text = JSONLReader.string(field: index.options.textField, in: line.bytes)
            else { return true }
            let found = HybridRetrieval.entities(in: text, using: dictionary)
            guard !found.isEmpty else { return true }
            entitiesOfChunk[line.number] = found
            for node in found { chunksOfEntity[node, default: []].append(line.number) }
            return true
        }
        cancelled = cancelToken?.isCancelled == true
        return Links(
            chunksOfEntity: chunksOfEntity, entitiesOfChunk: entitiesOfChunk,
            chunkCount: chunkCount, wasCancelled: cancelled)
    }

    // MARK: - Phân tích phủ

    public struct Coverage: Equatable, Sendable {
        /// Entity KHÔNG chunk nào nhắc tới.
        public var unmentionedEntities: [String]
        /// Chunk mồ côi: không chứa entity nào.
        public var orphanChunks: [Int]
        public var orphanChunkCount: Int
        /// Node đồ thị không có entity đối ứng trong danh sách marker.
        public var unmappedNodes: [String]
        public var entityCount: Int
        public var chunkCount: Int
        /// Danh sách marker có TRÙNG với tập node đồ thị không.
        ///
        /// Trùng thì «node không có entity đối ứng» rỗng THEO CẤU TẠO, không phải vì đồ thị
        /// sạch — và điều đó phải nói ra, nếu không người đọc sẽ tin vào một con số 0 vô nghĩa.
        public var markersAreGraphNodes: Bool
        public var methodology: String

        public var mentionedRatio: Double {
            entityCount > 0
                ? Double(entityCount - unmentionedEntities.count) / Double(entityCount) : 0
        }
        public var linkedChunkRatio: Double {
            chunkCount > 0 ? Double(chunkCount - orphanChunkCount) / Double(chunkCount) : 0
        }
    }

    /// Trần số phần tử giữ trong mỗi danh sách — bảng dài hơn thì cắt và NÓI RA.
    public static let listLimit = 500

    public static func coverage(
        _ links: Links, graph: GraphCSR,
        dictionary: HybridRetrieval.EntityDictionary,
        markers: [String] = []
    ) -> Coverage {
        var unmentioned: [String] = []
        for node in 0 ..< graph.nodeCount where links.chunksOfEntity[node] == nil {
            unmentioned.append(graph.displays[node])
        }
        var orphans: [Int] = []
        var orphanCount = 0
        for chunk in 0 ..< links.chunkCount where links.entitiesOfChunk[chunk] == nil {
            orphanCount += 1
            if orphans.count < listLimit { orphans.append(chunk) }
        }

        // Node KHÔNG có entity đối ứng: chỉ có nghĩa khi danh sách marker đến từ NGOÀI đồ thị.
        var unmapped: [String] = []
        let markersAreNodes = markers.isEmpty
        if !markersAreNodes {
            let known = Set(markers.map { TextDistance.normalize($0) })
            for node in 0 ..< graph.nodeCount {
                let name = TextDistance.normalize(graph.displays[node])
                if !known.contains(name) { unmapped.append(graph.displays[node]) }
            }
        }

        var text = "Một lượt quét toàn corpus, khớp entity theo cửa sổ token từ DÀI tới NGẮN. "
            + "Danh sách entity: \(dictionary.source)."
        if markersAreNodes {
            text += " ⚠ Danh sách marker CHÍNH LÀ tập node đồ thị, nên «node không có entity đối "
                + "ứng» rỗng theo cấu tạo — con số 0 ấy không nói lên đồ thị sạch. Khai "
                + "«markers» để phép kiểm ấy có nghĩa."
        }
        return Coverage(
            unmentionedEntities: Array(unmentioned.prefix(listLimit)),
            orphanChunks: orphans, orphanChunkCount: orphanCount,
            unmappedNodes: Array(unmapped.prefix(listLimit)),
            entityCount: graph.nodeCount, chunkCount: links.chunkCount,
            markersAreGraphNodes: markersAreNodes, methodology: text)
    }

    // MARK: - Gói ngữ cảnh

    public struct Triple: Equatable, Sendable {
        public var subject: String
        public var predicate: String
        public var object: String
        /// Khoảng cách từ seed tới đầu GẦN HƠN của cạnh.
        public var hops: Int
    }

    public struct Chunk: Equatable, Sendable {
        public var id: String
        public var text: String
        public var entities: [String]
        /// Khoảng cách nhỏ nhất từ seed tới một entity của chunk.
        public var hops: Int
    }

    public struct Package: Equatable, Sendable {
        public var seed: String
        public var triples: [Triple]
        public var chunks: [Chunk]
        /// Seed KHÔNG có trên đồ thị — gói rỗng, và lý do nói ra.
        public var seedFound: Bool
    }

    public struct Config: Equatable, Sendable {
        public var hops: Int
        /// Trần số chunk mỗi gói. 0 = không trần.
        public var chunkLimit: Int

        public init(hops: Int = 2, chunkLimit: Int = 200) {
            self.hops = max(1, hops)
            self.chunkLimit = max(0, chunkLimit)
        }
    }

    /// Trích gói ngữ cảnh cho MỘT seed.
    public static func extract(
        seed: String, index: BM25Index, graph: GraphCSR,
        dictionary: HybridRetrieval.EntityDictionary, links: Links,
        config: Config = Config(), cancelToken: CancelToken? = nil
    ) -> Package {
        let seeds = HybridRetrieval.entities(in: seed, using: dictionary)
        guard !seeds.isEmpty else {
            return Package(seed: seed, triples: [], chunks: [], seedFound: false)
        }
        var hopOf: [Int: Int] = [:]
        for node in seeds { hopOf[node] = 0 }
        let neighbourhood = GraphAlgorithms.neighbourhood(
            of: seeds, k: config.hops, in: graph, cancelToken: cancelToken)
        for entry in neighbourhood.nodes where hopOf[entry.node] == nil {
            hopOf[entry.node] = entry.hops
        }

        // --- Triple: mọi cạnh có CẢ HAI đầu trong vùng ---
        //
        // Cả hai đầu, không phải một: một cạnh nửa trong nửa ngoài mô tả một quan hệ mà gói này
        // không mang đủ hai vế, và pipeline bên ngoài sẽ đọc nó như một quan hệ tới một thực thể
        // không tồn tại.
        var triples: [Triple] = []
        var seenEdges = Set<String>()
        for node in hopOf.keys.sorted() {
            for position in graph.range(node, .out) {
                let other = graph.target(position, .out)
                guard let otherHops = hopOf[other] else { continue }
                let key = "\(node)\u{1}\(other)"
                guard seenEdges.insert(key).inserted else { continue }
                triples.append(Triple(
                    subject: graph.displays[node],
                    predicate: graph.isDirected ? "→" : "—",
                    object: graph.displays[other],
                    hops: min(hopOf[node] ?? 0, otherHops)))
            }
        }
        triples.sort {
            $0.hops != $1.hops
                ? $0.hops < $1.hops
                : ($0.subject != $1.subject ? $0.subject < $1.subject : $0.object < $1.object)
        }

        // --- Chunk: mọi chunk nhắc tới một node trong vùng ---
        var byChunk: [Int: Int] = [:]          // chunk → hop nhỏ nhất
        for (node, hops) in hopOf {
            for chunk in links.chunksOfEntity[node] ?? [] {
                byChunk[chunk] = min(byChunk[chunk] ?? Int.max, hops)
            }
        }
        var chunks: [Chunk] = []
        for chunk in byChunk.keys.sorted(by: {
            let left = byChunk[$0] ?? 0, right = byChunk[$1] ?? 0
            return left != right ? left < right : $0 < $1
        }) {
            if config.chunkLimit > 0, chunks.count >= config.chunkLimit { break }
            guard let text = index.text(of: chunk) else { continue }
            let entities = (links.entitiesOfChunk[chunk] ?? [])
                .filter { hopOf[$0] != nil }
                .map { graph.displays[$0] }
            chunks.append(Chunk(
                id: identifier(of: chunk, in: index) ?? "dòng \(chunk + 1)",
                text: text, entities: entities, hops: byChunk[chunk] ?? 0))
        }
        return Package(seed: seed, triples: triples, chunks: chunks, seedFound: true)
    }

    static func identifier(of document: Int, in index: BM25Index) -> String? {
        guard let line = index.record(document),
              let object = try? JSONSerialization.jsonObject(with: Data(line.utf8))
                as? [String: Any] else { return nil }
        return object[index.options.idField] as? String
    }

    // MARK: - Xuất JSONL

    /// Một dòng JSONL cho một gói.
    ///
    /// Tự dựng JSON thay vì `JSONSerialization`, cùng lý do đã ghi ở `GoldenSetBuilder`: bản của
    /// hệ thống sắp lại khoá theo băm, nên hai dòng cạnh nhau có thứ tự khoá khác nhau và diff
    /// của git đầy thay đổi giả.
    public static func jsonl(_ package: Package) -> String {
        var parts = ["\"query_seed\":\(json(package.seed))"]
        parts.append("\"triples\":[" + package.triples.map {
            "{\"s\":\(json($0.subject)),\"p\":\(json($0.predicate)),"
                + "\"o\":\(json($0.object)),\"hops\":\($0.hops)}"
        }.joined(separator: ",") + "]")
        parts.append("\"chunks\":[" + package.chunks.map {
            "{\"id\":\(json($0.id)),\"text\":\(json($0.text)),"
                + "\"entities\":[" + $0.entities.map(json).joined(separator: ",") + "],"
                + "\"hops\":\($0.hops)}"
        }.joined(separator: ",") + "]")
        return "{" + parts.joined(separator: ",") + "}"
    }

    static func json(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 { out += String(format: "\\u%04x", scalar.value) }
                else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }
}
