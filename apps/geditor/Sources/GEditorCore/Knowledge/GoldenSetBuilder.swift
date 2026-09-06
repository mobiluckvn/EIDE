import Foundation

/// Dựng bộ đánh giá bằng tay — FR-KNW-926.
///
/// Đặc tả: *"Gỡ rào cản lớn nhất của đánh giá retrieval — tạo bộ đánh giá thủ công quá cực:
/// chế độ GÁN NHÃN ngay trong Retrieval Lab: duyệt/tìm chunk → chọn 1..n chunk đúng → gõ câu
/// hỏi (mục tiêu ≤ 3 click + 1 lần gõ mỗi record) → lưu record JSONL {qid, question,
/// relevant_ids[], note}; trình quản lý: đếm phủ theo nguồn/chủ đề, câu chưa đủ nhãn,
/// import/export CSV."*
///
/// ## Tệp là nguồn sự thật, không phải một cơ sở dữ liệu trong bộ nhớ
///
/// Mỗi lần lưu là ghi thêm MỘT dòng vào tệp JSONL. Ba hệ quả, và cả ba đều là thứ ta muốn:
/// bộ đánh giá vào được git và diff được; ứng dụng sập giữa chừng thì mất đúng record đang gõ;
/// và người dùng mở chính tệp ấy bằng chế độ JSONL (FR-KNW-901) để soi, sửa, lọc — không phải
/// học thêm một trình quản lý riêng.
///
/// ## `qid` phải ỔN ĐỊNH và DUY NHẤT
///
/// Ổn định vì `RetrievalEval.compare` ghép hai lượt chạy theo `qid`; đánh số lại khi xoá một
/// record sẽ làm mọi so sánh với lượt trước ghép nhầm câu với câu. Duy nhất vì hai record cùng
/// `qid` thì lượt so sánh chỉ thấy một trong hai — im lặng.
///
/// Nên `qid` sinh từ số THỨ TỰ CAO NHẤT đã có cộng một, không phải từ số lượng record.
public struct GoldenSetBuilder: Equatable, Sendable {

    public private(set) var queries: [RetrievalEval.Query]
    /// Đường dẫn tệp JSONL. Rỗng = chưa gắn với tệp nào.
    public var path: String

    public init(queries: [RetrievalEval.Query] = [], path: String = "") {
        self.queries = queries
        self.path = path
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Tên tệp mặc định, đặt CẠNH corpus.
    ///
    /// Cạnh corpus vì hai tệp ấy chỉ có nghĩa cùng nhau: một bộ đánh giá không có corpus của nó
    /// là một danh sách id vô nghĩa. Đặt cạnh nhau thì chúng đi cùng nhau khi ai đó chép thư
    /// mục hay commit.
    public static func defaultPath(forCorpus corpus: String) -> String {
        let folder = (corpus as NSString).deletingLastPathComponent
        let name = ((corpus as NSString).lastPathComponent as NSString).deletingPathExtension
        return (folder as NSString).appendingPathComponent("\(name).golden.jsonl")
    }

    // MARK: - Nạp và ghi

    /// Nạp từ tệp; tệp chưa có thì trả về bộ rỗng gắn với đường dẫn ấy.
    public static func load(path: String) throws -> GoldenSetBuilder {
        guard FileManager.default.fileExists(atPath: path) else {
            return GoldenSetBuilder(queries: [], path: path)
        }
        return GoldenSetBuilder(
            queries: try RetrievalEval.loadGoldenSet(path: path), path: path)
    }

    /// Thêm một record và GHI THÊM một dòng vào tệp.
    ///
    /// Ghi thêm (`O_APPEND`) chứ không viết lại cả tệp: viết lại thì một lần lưu hỏng giữa
    /// chừng mất cả bộ đánh giá, còn ghi thêm thì mất đúng dòng đang ghi. Cùng khuôn với nhật
    /// ký trôi dạt của FR-DQR-004.
    @discardableResult
    public mutating func append(
        question: String, relevantIDs: [String], note: String = ""
    ) throws -> RetrievalEval.Query {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw Failure(message: "câu hỏi rỗng — không lưu được")
        }
        let query = RetrievalEval.Query(
            id: nextIdentifier(), question: text,
            relevant: Array(NSOrderedSet(array: relevantIDs)).compactMap { $0 as? String },
            note: note)
        queries.append(query)
        guard !path.isEmpty else { return query }
        try appendLine(encode(query))
        return query
    }

    /// Số thứ tự cao nhất đã dùng, cộng một.
    ///
    /// KHÔNG dùng `queries.count + 1`: xoá một record ở giữa rồi thêm mới sẽ sinh ra một `qid`
    /// trùng với record còn lại, và lượt so sánh hai cấu hình chỉ thấy một trong hai.
    func nextIdentifier() -> String {
        var highest = 0
        for query in queries {
            guard query.id.hasPrefix("q"), let number = Int(query.id.dropFirst()) else { continue }
            highest = max(highest, number)
        }
        return "q\(highest + 1)"
    }

    func encode(_ query: RetrievalEval.Query) -> String {
        // Tự dựng JSON thay vì `JSONSerialization`: bản của hệ thống SẮP LẠI khoá theo băm, nên
        // hai dòng cạnh nhau trong cùng một tệp có thể có thứ tự khoá khác nhau — diff của git
        // khi ấy đầy những thay đổi giả.
        var parts = [
            "\"qid\":\(jsonString(query.id))",
            "\"question\":\(jsonString(query.question))",
            "\"relevant_ids\":[" + query.relevant.map(jsonString).joined(separator: ",") + "]",
        ]
        if !query.note.isEmpty { parts.append("\"note\":\(jsonString(query.note))") }
        return "{" + parts.joined(separator: ",") + "}"
    }

    func jsonString(_ text: String) -> String { JSONText.quoted(text) }

    private func appendLine(_ line: String) throws {
        let data = Data((line + "\n").utf8)
        let manager = FileManager.default
        if !manager.fileExists(atPath: path) {
            guard manager.createFile(atPath: path, contents: data) else {
                throw Failure(message: "không tạo được tệp «\(path)»")
            }
            return
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw Failure(message: "không ghi được vào «\(path)»")
        }
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    /// Ghi lại TOÀN BỘ tệp — dùng sau khi xoá hay sửa record.
    public func rewrite() throws {
        guard !path.isEmpty else { throw Failure(message: "bộ đánh giá chưa gắn với tệp nào") }
        let text = queries.map(encode).joined(separator: "\n") + "\n"
        try AtomicFileWriter.write(Array(text.utf8), to: path)
    }

    public mutating func remove(id: String) {
        queries.removeAll { $0.id == id }
    }

    // MARK: - CSV

    /// Xuất CSV. Id ngăn nhau bằng `;` — cùng quy ước với bộ nạp.
    public func csv() -> String {
        var out = "qid,question,relevant_ids,note\n"
        for query in queries {
            out += [
                query.id, query.question, query.relevant.joined(separator: ";"), query.note,
            ].map(csvField).joined(separator: ",") + "\n"
        }
        return out
    }

    private func csvField(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Nhập từ CSV hoặc JSONL, GỘP vào bộ hiện có.
    ///
    /// Trùng CÂU HỎI thì bỏ qua và đếm, không ghi đè: người nhập thường đang gộp việc của hai
    /// người, và ghi đè im lặng làm mất nhãn của một trong hai.
    @discardableResult
    public mutating func merge(from path: String) throws -> (added: Int, skipped: Int) {
        let incoming = try RetrievalEval.loadGoldenSet(path: path)
        var existing = Set(queries.map { normalize($0.question) })
        var added = 0
        var skipped = 0
        for query in incoming {
            let key = normalize(query.question)
            if existing.contains(key) { skipped += 1; continue }
            existing.insert(key)
            queries.append(RetrievalEval.Query(
                id: nextIdentifier(), question: query.question,
                relevant: query.relevant, note: query.note))
            added += 1
        }
        if added > 0, !self.path.isEmpty { try rewrite() }
        return (added, skipped)
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Trình quản lý

    public struct Coverage: Equatable, Sendable {
        public var total: Int
        /// Record KHÔNG có id kỳ vọng nào — chưa dùng được để đánh giá.
        public var unlabeled: [String]
        /// Câu hỏi TRÙNG nhau (đã chuẩn hoá) — mỗi nhóm là danh sách `qid`.
        public var duplicateQuestions: [[String]]
        /// Số record chạm tới từng nguồn, giảm dần.
        public var bySource: [(source: String, count: Int)]
        /// Nguồn KHAI RỒI mà chưa record nào chạm tới.
        public var missingSources: [String]
        /// Id kỳ vọng không tra được nguồn — thường là id không có trong corpus.
        public var unknownIDs: Int

        public static func == (left: Coverage, right: Coverage) -> Bool {
            left.total == right.total && left.unlabeled == right.unlabeled
                && left.duplicateQuestions == right.duplicateQuestions
                && left.bySource.map(\.source) == right.bySource.map(\.source)
                && left.bySource.map(\.count) == right.bySource.map(\.count)
                && left.missingSources == right.missingSources
                && left.unknownIDs == right.unknownIDs
        }
    }

    /// Đếm phủ.
    ///
    /// - Parameter sourceOf: id chunk → nguồn của nó. Nhận từ ngoài chứ không tự tra, vì bảng
    ///   ấy đến từ `ChunkInspector` và một lượt quét corpus là thứ đắt nhất ở đây.
    /// - Parameter declaredSources: danh sách nguồn đã khai, để chỉ ra nguồn nào chưa được câu
    ///   hỏi nào chạm tới. **Nguồn không có câu hỏi nào là lỗ hổng lớn nhất của một bộ đánh
    ///   giá**, và nó vô hình nếu chỉ nhìn danh sách record.
    public func coverage(
        sourceOf: (String) -> String?, declaredSources: [String] = []
    ) -> Coverage {
        var unlabeled: [String] = []
        var counts: [String: Int] = [:]
        var unknown = 0
        var byQuestion: [String: [String]] = [:]

        for query in queries {
            byQuestion[normalize(query.question), default: []].append(query.id)
            if query.relevant.isEmpty { unlabeled.append(query.id) }
            var touched = Set<String>()
            for identifier in query.relevant {
                guard let source = sourceOf(identifier), !source.isEmpty else {
                    unknown += 1
                    continue
                }
                touched.insert(source)
            }
            for source in touched { counts[source, default: 0] += 1 }
        }

        let duplicates = byQuestion.values.filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($0.first ?? "") < ($1.first ?? "") }
        let bySource = counts.map { (source: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.source < $1.source }
        let missing = declaredSources.filter { counts[$0] == nil }
        return Coverage(
            total: queries.count, unlabeled: unlabeled, duplicateQuestions: duplicates,
            bySource: bySource, missingSources: missing, unknownIDs: unknown)
    }

    /// Tóm tắt một dòng cho thanh trạng thái.
    public func summary(_ coverage: Coverage) -> String {
        var parts = ["\(coverage.total) câu"]
        if !coverage.unlabeled.isEmpty {
            parts.append("\(coverage.unlabeled.count) chưa đủ nhãn")
        }
        if !coverage.duplicateQuestions.isEmpty {
            parts.append("\(coverage.duplicateQuestions.count) câu trùng")
        }
        if !coverage.bySource.isEmpty {
            parts.append("\(coverage.bySource.count) nguồn")
        }
        if !coverage.missingSources.isEmpty {
            parts.append("thiếu: " + coverage.missingSources.prefix(3).joined(separator: ", "))
        }
        if coverage.unknownIDs > 0 {
            parts.append("\(coverage.unknownIDs) id không tra được nguồn")
        }
        return parts.joined(separator: " · ")
    }
}
