import Foundation

/// Nhập điểm truy hồi do một pipeline NGOÀI sinh ra, để so song song với BM25 — FR-KNW-921.
///
/// Đặc tả: *"Nhập file điểm từ pipeline embedding bên ngoài (JSONL: query, chunk_id, score) và
/// so sánh song song với BM25 trên cùng golden set: bảng delta theo câu, chart so recall@k/MRR
/// hai hệ. **Ứng dụng KHÔNG tính vector** — chỉ phân tích kết quả do công cụ ngoài sinh ra, giữ
/// đúng ranh giới ADR-11."*
///
/// ## Ranh giới: ở đây không có mô hình nào chạy
///
/// Tệp vào là một BẢNG XẾP HẠNG đã có sẵn. Bộ này đọc nó, ghép với golden set, rồi đưa qua
/// đúng bộ chấm điểm của FR-KNW-919 — không nhân vector, không gọi mạng, không nạp mô hình.
/// Câu ấy in trong khối Phương pháp của báo cáo chứ không nằm riêng trong tài liệu.
///
/// ## Ba chỗ một phép so hai hệ hay nói dối, và cả ba xử ở đây
///
/// **1. Ghép câu hỏi bằng CHỮ, không bằng `qid`.** Tệp ngoài không biết `qid` của golden set —
/// nó chỉ có câu hỏi. Nên ghép theo câu hỏi đã chuẩn hoá (gọn khoảng trắng, thường hoá; GIỮ
/// dấu, vì bỏ dấu là gộp hai câu khác nhau). Câu nào tệp ngoài không có thì **bị loại khỏi cả
/// hai lượt chạy**, không phải tính 0 điểm cho hệ ngoài: một tệp ghép hụt vì thừa khoảng trắng
/// sẽ làm hệ ngoài trông thảm hại, và đó là kết luận sai về một lỗi định dạng.
///
/// **2. So phải trên CÙNG tập câu.** BM25 chấm trên 200 câu còn hệ ngoài chấm trên 60 câu nó
/// có mặt là hai con số không so được với nhau. Nên cả hai lượt chạy trên đúng phần giao, và
/// số câu bị loại được nói ra ngay cạnh bảng.
///
/// **3. Điểm không phải lúc nào cũng "càng lớn càng tốt".** Nhiều pipeline xuất KHOẢNG CÁCH
/// (L2, càng nhỏ càng gần) hoặc HẠNG (1 là tốt nhất). Đoán sai chiều thì bảng xếp hạng bị lật
/// ngược và hệ ngoài ra gần 0 điểm — một kết quả trông rất "có ý nghĩa". Nên chiều đọc từ TÊN
/// TRƯỜNG người dùng khai (`score`/`similarity` giảm dần · `distance`/`rank` tăng dần), và tên
/// trường ấy được in ra cùng chiều đã dùng.
public enum ExternalScores {

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Chiều của điểm: lớn hơn là tốt hơn, hay nhỏ hơn là tốt hơn.
    public enum Order: String, Equatable, Sendable {
        case descending, ascending

        public var vietnamese: String {
            self == .descending ? "điểm lớn hơn xếp trên" : "điểm nhỏ hơn xếp trên"
        }
    }

    public struct Hit: Equatable, Sendable {
        public var id: String
        public var score: Double
    }

    public struct File: Equatable, Sendable {
        public var path: String
        public var order: Order
        /// Tên trường điểm ĐỌC ĐƯỢC trong tệp — in ra để người đọc kiểm lại chiều.
        public var scoreField: String
        public var rowCount: Int
        /// Câu hỏi đã chuẩn hoá → bảng xếp hạng đã sắp.
        public var ranking: [String: [Hit]]
        /// Câu hỏi dạng NGUYÊN VĂN của lần gặp đầu, để in ra cho người đọc nhận mặt.
        public var originalQuestions: [String: String]
        public var warnings: [String]

        public var questionCount: Int { ranking.count }

        public var methodology: String {
            "điểm ngoài «\((path as NSString).lastPathComponent)» · trường «\(scoreField)» · "
                + "\(order.vietnamese) · \(rowCount) dòng / \(questionCount) câu · "
                + "ứng dụng KHÔNG tính vector, chỉ đọc kết quả có sẵn"
        }
    }

    static let questionKeys = ["query", "question", "cau_hoi", "q"]
    static let identifierKeys = ["chunk_id", "id", "doc_id", "document_id", "chunk"]
    /// Tên trường điểm, kèm CHIỀU của từng tên. Thứ tự này là thứ tự ưu tiên khi tệp có nhiều.
    static let scoreFields: [(name: String, order: Order)] = [
        ("score", .descending), ("similarity", .descending), ("sim", .descending),
        ("cosine", .descending), ("distance", .ascending), ("dist", .ascending),
        ("rank", .ascending), ("position", .ascending),
    ]

    /// Đọc tệp điểm ngoài.
    ///
    /// - Parameter order: ép chiều, dùng khi tên trường không nói lên chiều. `nil` = đọc theo
    ///   tên trường.
    public static func load(path: String, order forced: Order? = nil) throws -> File {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw Failure(message: "không đọc được tệp điểm ngoài «\(path)»")
        }
        let text = String(decoding: data, as: UTF8.self)
        var rows: [(question: String, id: String, score: Double)] = []
        var order = forced ?? .descending
        var scoreField = ""
        var warnings: [String] = []
        var badLines = 0
        var sawObject = false

        for (number, line) in text.split(
            separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(trimmed.utf8)) as? [String: Any] else {
                throw Failure(message: "tệp điểm ngoài dòng \(number + 1) không phải JSON hợp lệ "
                    + "— định dạng nhận được là JSONL, mỗi dòng một bản ghi "
                    + "{query, chunk_id, score}")
            }
            sawObject = true
            guard let question = firstString(object, questionKeys), !question.isEmpty,
                  let identifier = firstString(object, identifierKeys), !identifier.isEmpty else {
                badLines += 1
                continue
            }
            guard let found = firstScore(object) else {
                badLines += 1
                continue
            }
            if scoreField.isEmpty {
                scoreField = found.field
                if forced == nil { order = found.order }
            } else if found.field != scoreField {
                // Tệp đổi trường điểm giữa chừng: nửa đầu `score`, nửa sau `distance` chẳng hạn.
                // Trộn hai thang vào một bảng xếp hạng là so hai thứ khác nhau, nên DỪNG.
                throw Failure(message: "tệp điểm ngoài dòng \(number + 1) dùng trường «"
                    + found.field + "» trong khi những dòng trước dùng «\(scoreField)» — một tệp "
                    + "một thang điểm")
            }
            rows.append((question, identifier, found.value))
        }

        guard sawObject else {
            throw Failure(message: "tệp điểm ngoài «\((path as NSString).lastPathComponent)» "
                + "không có dòng JSON nào — định dạng nhận được là JSONL")
        }
        guard !rows.isEmpty else {
            throw Failure(message: "tệp điểm ngoài không có dòng nào đủ ba trường — câu hỏi "
                + "(\(questionKeys.joined(separator: "/"))), id chunk "
                + "(\(identifierKeys.joined(separator: "/"))), điểm ("
                + scoreFields.map(\.name).joined(separator: "/") + ")")
        }
        if badLines > 0 {
            warnings.append("\(badLines) dòng thiếu trường nên bị bỏ qua")
        }

        var ranking: [String: [Hit]] = [:]
        var originals: [String: String] = [:]
        var duplicates = 0
        for row in rows {
            let key = normalize(row.question)
            if originals[key] == nil { originals[key] = row.question }
            if ranking[key]?.contains(where: { $0.id == row.id }) == true {
                duplicates += 1
                continue
            }
            ranking[key, default: []].append(Hit(id: row.id, score: row.score))
        }
        if duplicates > 0 {
            // Giữ lần đầu và ĐẾM. Cộng dồn hay lấy max đều là một quyết định của người làm
            // pipeline chứ không phải của công cụ đọc.
            warnings.append("\(duplicates) dòng trùng (cùng câu hỏi, cùng id) — giữ lần đầu")
        }
        for key in ranking.keys {
            ranking[key]?.sort {
                $0.score != $1.score
                    ? (order == .descending ? $0.score > $1.score : $0.score < $1.score)
                    : $0.id < $1.id     // phá hoà tất định, không theo thứ tự trong tệp
            }
        }
        return File(
            path: path, order: order, scoreField: scoreField, rowCount: rows.count,
            ranking: ranking, originalQuestions: originals, warnings: warnings)
    }

    /// Chuẩn hoá câu hỏi để ghép: gọn khoảng trắng, thường hoá, **giữ dấu**.
    ///
    /// Giữ dấu là có chủ ý và ngược với `TextDistance.normalize`: ở đây hai câu khác dấu là hai
    /// câu hỏi khác nhau, còn ở phép gom biến thể entity thì "Nguyen" và "Nguyễn" là một.
    public static func normalize(_ question: String) -> String {
        question.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - Ghép với golden set

    public struct Join: Equatable, Sendable {
        /// Phần GIAO — đúng những câu cả hai bên đều có. Cả hai lượt chạy trên tập này.
        public var matched: [RetrievalEval.Query]
        /// Câu golden mà tệp ngoài không có.
        public var unmatched: [RetrievalEval.Query]
        /// Gợi ý cho câu không ghép được: tệp ngoài có một câu RẤT GIỐNG.
        public var suggestions: [String]
        /// Câu tệp ngoài có mà golden set không có.
        public var extraQuestions: [String]

        public var isEmpty: Bool { matched.isEmpty }
    }

    /// Ghép theo câu hỏi, và **nói ra chỗ ghép hụt kèm gợi ý**.
    ///
    /// Gợi ý dùng `TextDistance` — cùng bộ so mờ của FR-KNW-923/924. Một tệp ngoài lệch đúng
    /// một dấu chấm hỏi sẽ ghép hụt 100%, và không có gợi ý thì người dùng chỉ thấy "0 câu
    /// ghép được" mà không biết vì sao.
    public static func join(_ file: File, golden: [RetrievalEval.Query]) -> Join {
        var matched: [RetrievalEval.Query] = []
        var unmatched: [RetrievalEval.Query] = []
        var suggestions: [String] = []
        var used = Set<String>()
        let outsideKeys = Array(file.ranking.keys)

        for query in golden {
            let key = normalize(query.question)
            if file.ranking[key] != nil {
                used.insert(key)
                matched.append(query)
                continue
            }
            unmatched.append(query)
            guard suggestions.count < 5 else { continue }
            var best = ""
            var bestScore = 0.0
            for candidate in outsideKeys {
                let score = TextDistance.similarity(key, candidate, threshold: 0.85)
                if score > bestScore { bestScore = score; best = candidate }
            }
            if bestScore >= 0.85, let original = file.originalQuestions[best] {
                suggestions.append("«\(query.question)» không có trong tệp ngoài; giống "
                    + String(format: "%.0f%%", bestScore * 100) + " với «\(original)»")
            }
        }
        let extras = outsideKeys.filter { !used.contains($0) }
            .compactMap { file.originalQuestions[$0] }.sorted()
        return Join(matched: matched, unmatched: unmatched, suggestions: suggestions,
                    extraQuestions: extras)
    }

    // MARK: - Đưa qua bộ chấm điểm của 919

    /// Bộ truy hồi đọc từ bảng xếp hạng ngoài, dùng cho `RetrievalEval.run(golden:…retrieve:)`.
    ///
    /// Trả về SỐ HIỆU TÀI LIỆU chứ không trả id, vì đó là thứ bộ chấm điểm nhận — và nhờ vậy
    /// hai hệ đi qua đúng một bộ chấm, đúng lý do `run` có bản tổng quát.
    public static func retriever(
        _ file: File, identifierMap: [String: [Int]]
    ) -> (_ question: String, _ k: Int) -> [Int] {
        { question, k in
            guard let hits = file.ranking[normalize(question)] else { return [] }
            var out: [Int] = []
            var seen = Set<Int>()
            for hit in hits {
                for document in identifierMap[hit.id] ?? [] where seen.insert(document).inserted {
                    out.append(document)
                    if out.count == k { return out }
                }
            }
            return out
        }
    }

    public struct Coverage: Equatable, Sendable {
        public var unknownCount: Int
        public var totalCount: Int
        public var samples: [String]

        public var ratio: Double {
            totalCount == 0 ? 0 : Double(unknownCount) / Double(totalCount)
        }
    }

    /// Id trong tệp ngoài mà corpus KHÔNG có.
    ///
    /// Đây là dấu hiệu của cái hỏng tốn kém nhất trong một phép so hai hệ: **hai bên chạy trên
    /// hai bản corpus khác nhau**. Khi ấy hệ ngoài mất điểm vì trỏ vào những chunk đã biến mất,
    /// và con số ra trông y hệt "embedding thua BM25".
    public static func coverage(_ file: File, identifierMap: [String: [Int]]) -> Coverage {
        var unknown = Set<String>()
        var total = Set<String>()
        for hits in file.ranking.values {
            for hit in hits {
                total.insert(hit.id)
                if identifierMap[hit.id] == nil { unknown.insert(hit.id) }
            }
        }
        return Coverage(unknownCount: unknown.count, totalCount: total.count,
                        samples: Array(unknown.sorted().prefix(10)))
    }

    // MARK: - Phụ

    private static func firstString(_ object: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let text = object[key] as? String { return text }
            if let value = object[key], !(value is NSNull),
               let text = BM25Index.string(from: value) { return text }
        }
        return nil
    }

    private static func firstScore(
        _ object: [String: Any]
    ) -> (field: String, value: Double, order: Order)? {
        for entry in scoreFields {
            guard let value = object[entry.name] else { continue }
            if let number = value as? Double { return (entry.name, number, entry.order) }
            if let number = value as? Int { return (entry.name, Double(number), entry.order) }
            if let text = value as? String, let number = Double(text) {
                return (entry.name, number, entry.order)
            }
        }
        return nil
    }
}
