import Foundation

/// Chunk Inspector — FR-KNW-902.
///
/// Đặc tả: *"Nhận diện schema chunk phổ biến (id/text/metadata); thống kê độ dài ký tự/từ/token
/// ước lượng theo histogram; phát hiện chunk rỗng và trùng lặp (hash nội dung); lọc theo
/// metadata."*
///
/// ## Đoán schema là ĐOÁN, và nó phải nói ra rằng nó đang đoán
///
/// Không có chuẩn nào cho tệp chunk. `text` · `content` · `body` · `page_content` (LangChain) ·
/// `passage` (BEIR) đều gặp trong dữ liệu thật, và có tệp không dùng tên nào trong số ấy. Nên
/// bộ này trả về **một danh sách ứng viên có điểm** chứ không trả về một câu khẳng định, và
/// người dùng đổi được lựa chọn.
///
/// Điểm đoán dựa vào hai thứ đo được, không dựa vào cảm giác:
///
/// * **tên** — khớp một trong những tên đã gặp thật, có ghi nguồn ở `knownTextFields`;
/// * **hình dạng dữ liệu** — trường văn bản thì DÀI và gần như luôn có mặt; trường định danh
///   thì ngắn, có mặt ở mọi bản ghi, và **giá trị gần như không lặp**.
///
/// Vế thứ hai là vế cứu được những tệp đặt tên lạ, và nó cũng là vế bắt được tệp đặt tên
/// **đúng mà dùng sai** — một trường tên `id` mà 90% bản ghi trùng giá trị thì nó không phải
/// định danh, dù nó tên gì.
///
/// ## Trùng lặp ở đây là trùng CHÍNH XÁC
///
/// FR-KNW-902 viết *"trùng lặp (hash nội dung)"*, còn FR-KNW-922 lo phần **trùng GẦN**. Hai
/// phép đo khác nhau và cố ý không gộp: trùng chính xác chạy một lượt với bộ nhớ nhỏ và cho
/// câu trả lời chắc chắn; trùng gần tốn hơn nhiều bậc và cho câu trả lời có ngưỡng.
public enum ChunkInspector {

    // MARK: - Tên trường đã gặp thật

    /// Tên trường văn bản, theo thứ tự ưu tiên.
    ///
    /// `page_content` là của LangChain, `passage` là của BEIR/MS MARCO, `chunk` và `content`
    /// gặp trong các pipeline tự viết. Danh sách này chỉ để CỘNG ĐIỂM — hình dạng dữ liệu vẫn
    /// được chấm, và một trường tên lạ mà dài hơn hẳn vẫn thắng.
    public static let knownTextFields = [
        "text", "content", "body", "page_content", "passage", "chunk", "document", "noi_dung",
    ]

    public static let knownIDFields = [
        "id", "_id", "chunk_id", "doc_id", "uuid", "key", "ma",
    ]

    /// Tên trường chứa metadata lồng bên trong.
    public static let knownMetadataFields = ["metadata", "meta", "attributes", "props"]

    // MARK: - Kết quả

    public struct FieldSummary: Equatable, Sendable {
        public var name: String
        /// Các kiểu đã gặp. Nhiều hơn một kiểu là dấu hiệu schema không nhất quán.
        public var kinds: [JSONScanner.Kind]
        /// Số bản ghi CÓ trường này.
        public var presentCount: Int
        /// Số giá trị khác nhau — chỉ đếm tới `distinctLimit` rồi thôi.
        public var distinctCount: Int
        /// Có phải `distinctCount` đã chạm trần không.
        public var distinctCapped: Bool
        /// Tổng độ dài (byte) của giá trị chuỗi — để tính độ dài trung bình.
        public var totalValueBytes: Int
        /// Giá trị hay gặp nhất, để lọc. Chỉ giữ với trường ÍT giá trị khác nhau.
        public var topValues: [(value: String, count: Int)]

        public static func == (left: FieldSummary, right: FieldSummary) -> Bool {
            left.name == right.name && left.kinds == right.kinds
                && left.presentCount == right.presentCount
                && left.distinctCount == right.distinctCount
                && left.distinctCapped == right.distinctCapped
                && left.totalValueBytes == right.totalValueBytes
                && left.topValues.map(\.value) == right.topValues.map(\.value)
                && left.topValues.map(\.count) == right.topValues.map(\.count)
        }

        /// Sửa TẠI CHỖ. Có mặt để chỗ gọi sửa được giá trị nằm trong từ điển mà không tạo
        /// tham chiếu thứ hai — xem chú thích ở `inspect`.
        mutating func apply(_ body: (inout FieldSummary) -> Void) { body(&self) }

        public var averageValueBytes: Double {
            presentCount > 0 ? Double(totalValueBytes) / Double(presentCount) : 0
        }

        /// Tỷ lệ giá trị khác nhau trên số bản ghi có trường. 1,0 = mọi giá trị đều riêng.
        public var distinctRatio: Double {
            presentCount > 0 ? Double(distinctCount) / Double(presentCount) : 0
        }
    }

    public struct Candidate: Equatable, Sendable {
        public var field: String
        /// 0…1. Không phải xác suất — là điểm xếp hạng, và công thức in ra ở `reason`.
        public var score: Double
        public var reason: String
    }

    public struct Schema: Equatable, Sendable {
        /// Ứng viên trường văn bản, điểm giảm dần. Rỗng = không đoán được.
        public var textCandidates: [Candidate]
        public var idCandidates: [Candidate]
        /// Trường còn lại, coi là metadata.
        public var metadataFields: [String]
        /// Khoá bên trong trường metadata lồng (nếu có), dạng `metadata.nguon`.
        public var nestedMetadataField: String?

        public var text: String? { textCandidates.first?.field }
        public var id: String? { idCandidates.first?.field }
    }

    /// Histogram độ dài. Biên là mảng mốc TRÊN của từng khoảng.
    public struct Histogram: Equatable, Sendable {
        public var bounds: [Int]
        public var counts: [Int]
        public var minimum: Int
        public var maximum: Int
        public var total: Int
        public var sum: Int

        public var average: Double { total > 0 ? Double(sum) / Double(total) : 0 }

        /// Nhãn đọc được cho từng cột.
        public func label(_ index: Int) -> String {
            guard index < bounds.count else { return "" }
            let lower = index == 0 ? minimum : bounds[index - 1] + 1
            return index == bounds.count - 1 && bounds[index] >= maximum
                ? "\(lower)–\(maximum)" : "\(lower)–\(bounds[index])"
        }
    }

    public struct Report: Equatable, Sendable {
        public var recordCount: Int
        public var invalidCount: Int
        public var schema: Schema
        public var fields: [FieldSummary]
        public var characters: Histogram
        public var words: Histogram
        public var tokens: Histogram
        /// Dòng có trường văn bản rỗng hoặc chỉ khoảng trắng.
        public var emptyLines: [Int]
        public var emptyCount: Int
        /// Nhóm dòng có nội dung TRÙNG CHÍNH XÁC, mỗi nhóm tăng dần; nhóm sắp theo phần tử đầu.
        public var duplicateGroups: [[Int]]
        public var duplicateCount: Int
        public var wasCancelled: Bool

        /// Trường văn bản đã dùng để thống kê — nói ra vì mọi con số phía trên phụ thuộc nó.
        public var textField: String?
    }

    public struct Config: Equatable, Sendable {
        /// Ép dùng trường này làm văn bản. `nil` = tự đoán.
        public var textField: String?
        /// Số bản ghi đầu dùng để đoán schema. 0 = dùng cả tệp.
        public var sampleSize: Int
        /// Trần số giá trị khác nhau đếm cho mỗi trường.
        public var distinctLimit: Int
        /// Trường có nhiều hơn ngần này giá trị khác nhau thì KHÔNG giữ danh sách lọc.
        public var filterableLimit: Int
        public var topValueCount: Int
        /// Trần số dòng giữ lại trong mỗi danh sách (rỗng, trùng).
        public var listLimit: Int
        public var histogramBuckets: Int

        public init(
            textField: String? = nil, sampleSize: Int = 5_000, distinctLimit: Int = 10_000,
            filterableLimit: Int = 200, topValueCount: Int = 20, listLimit: Int = 1_000,
            histogramBuckets: Int = 12
        ) {
            self.textField = textField
            self.sampleSize = sampleSize
            self.distinctLimit = distinctLimit
            self.filterableLimit = filterableLimit
            self.topValueCount = topValueCount
            self.listLimit = listLimit
            self.histogramBuckets = max(2, histogramBuckets)
        }
    }

    // MARK: - Chạy

    public static func inspect(
        buffer: TextBuffer, config: Config = Config(),
        cancelToken: CancelToken? = nil,
        progress: ((Double) -> Bool)? = nil
    ) -> Report {
        // --- Lượt 1: đoán schema trên mẫu đầu ------------------------------------------
        //
        // Đoán trên MẪU chứ không trên cả tệp: đoán tên trường không cần một triệu bản ghi, và
        // đọc cả GB hai lượt là trả hai lần cho một câu trả lời. Mẫu lấy từ ĐẦU tệp — không
        // phải vì đầu tệp đại diện hơn, mà vì đó là chỗ duy nhất đọc được mà không quét hết.
        var summaries: [String: FieldSummary] = [:]
        var order: [String] = []
        var values: [String: [String: Int]] = [:]
        var nested: String?
        var sampled = 0
        var invalid = 0

        JSONLScan.forEachLine(buffer: buffer, cancelToken: cancelToken) { line, _ in
            guard config.sampleSize == 0 || sampled < config.sampleSize else { return }
            guard !isBlank(line) else { return }
            guard let fields = JSONScanner.topLevelFields(line) else {
                invalid += 1
                return
            }
            sampled += 1
            for field in fields {
                if summaries[field.name] == nil {
                    order.append(field.name)
                    summaries[field.name] = FieldSummary(
                        name: field.name, kinds: [], presentCount: 0, distinctCount: 0,
                        distinctCapped: false, totalValueBytes: 0, topValues: [])
                }
                // `subscript(_:default:)` đi qua `_modify` nên sửa TẠI CHỖ. Viết
                // `var x = table[k] ?? …` rồi gán lại là tạo tham chiếu thứ hai, và mỗi bản ghi
                // thành một lần chép cả bảng — đúng cái bẫy copy-on-write đã làm bộ dựng chỉ
                // mục BM25 thành O(n²).
                summaries[field.name, default: .init(
                    name: field.name, kinds: [], presentCount: 0, distinctCount: 0,
                    distinctCapped: false, totalValueBytes: 0, topValues: [])].apply { summary in
                    summary.presentCount += 1
                    if !summary.kinds.contains(field.kind) { summary.kinds.append(field.kind) }
                    summary.totalValueBytes += field.value.count
                }
                if nested == nil, field.kind == .object,
                   knownMetadataFields.contains(field.name.lowercased()) {
                    nested = field.name
                }
                // Chỉ đếm giá trị KHÁC NHAU cho giá trị NGẮN: với trường văn bản thì con số ấy
                // vô nghĩa (mọi chunk đều khác nhau) và bảng đếm nặng bằng cả tệp.
                guard field.value.count <= shortValueBytes else { continue }
                values[field.name, default: [:]].apply { table in
                    if table.count >= config.distinctLimit {
                        summaries[field.name]?.distinctCapped = true
                        return
                    }
                    table[String(decoding: line[field.value], as: UTF8.self), default: 0] += 1
                }
            }
        }

        for (name, table) in values {
            summaries[name]?.distinctCount = table.count
            guard table.count <= config.filterableLimit else { continue }
            summaries[name]?.topValues = table
                .map { (value: $0.key, count: $0.value) }
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.value < $1.value }
                .prefix(config.topValueCount)
                .map { $0 }
        }

        let fields = order.compactMap { summaries[$0] }
        let schema = guessSchema(fields: fields, sampled: sampled, nested: nested)
        let textField = config.textField ?? schema.text

        // --- Lượt 2: thống kê trên trường văn bản đã chốt ---------------------------------
        var characters: [Int] = []
        var words: [Int] = []
        var tokens: [Int] = []
        var empty: [Int] = []
        var emptyCount = 0
        var hashes: [UInt64: [Int]] = [:]
        var records = 0
        let tokenizer = BM25Tokenizer()
        var cancelled = false

        if let textField {
            let walk = JSONLScan.forEachLine(
                buffer: buffer, cancelToken: cancelToken, progress: progress
            ) { line, index in
                guard !isBlank(line) else { return }
                // Đường nhanh: giá trị KHÔNG có ký tự thoát, nên đếm thẳng trên byte của tệp.
                //
                // Bản đầu dựng một `String` cho mỗi bản ghi rồi gọi `text.count` và
                // `split(whereSeparator: \.isWhitespace)`. Cả hai chạy thuật toán Unicode trên
                // TỪNG ký tự, và bộ lấy mẫu đo được `_swift_stdlib_getBinaryProperties` chiếm
                // **57,7%** cả lượt thống kê — 69,7 giây cho 1 GB so với trần 10,4. Cùng họ
                // với lỗi đã sửa trong bộ cắt token BM25.
                if let range = BM25RawJSON.stringRange(field: textField, in: line) {
                    records += 1
                    let value = UnsafeBufferPointer(
                        start: line.baseAddress! + range.lowerBound, count: range.count)
                    if isBlank(value) {
                        emptyCount += 1
                        if empty.count < config.listLimit { empty.append(index) }
                        return
                    }
                    characters.append(scalarCount(value))
                    words.append(wordCount(value))
                    tokens.append(tokenizer.countTokens(inUTF8: value))
                    hashes[hash(line, range), default: []].append(index)
                    return
                }
                // Đường lui: giá trị có ký tự thoát. Giải mã rồi đếm trên UTF-8 của bản đã
                // giải, để «\n» được tính là MỘT ký tự chứ không phải hai.
                guard let text = decoded(field: textField, in: line) else { return }
                records += 1
                var copy = text
                let blank = copy.withUTF8 { isBlank($0) }
                if blank {
                    emptyCount += 1
                    if empty.count < config.listLimit { empty.append(index) }
                    return
                }
                copy.withUTF8 { value in
                    characters.append(scalarCount(value))
                    words.append(wordCount(value))
                    tokens.append(tokenizer.countTokens(inUTF8: value))
                    var digest: UInt64 = 0xcbf2_9ce4_8422_2325
                    for byte in value {
                        digest ^= UInt64(byte)
                        digest = digest &* 0x0000_0100_0000_01B3
                    }
                    hashes[digest, default: []].append(index)
                }
            }
            cancelled = walk.cancelled
        }

        let groups = hashes.values.filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($0.first ?? 0) < ($1.first ?? 0) }

        return Report(
            recordCount: records, invalidCount: invalid, schema: schema, fields: fields,
            characters: histogram(characters, buckets: config.histogramBuckets),
            words: histogram(words, buckets: config.histogramBuckets),
            tokens: histogram(tokens, buckets: config.histogramBuckets),
            emptyLines: empty, emptyCount: emptyCount,
            duplicateGroups: Array(groups.prefix(config.listLimit)),
            duplicateCount: groups.count, wasCancelled: cancelled,
            textField: textField)
    }

    // MARK: - Đoán schema

    static func guessSchema(
        fields: [FieldSummary], sampled: Int, nested: String?
    ) -> Schema {
        guard sampled > 0 else {
            return Schema(textCandidates: [], idCandidates: [], metadataFields: [],
                          nestedMetadataField: nested)
        }
        var textCandidates: [Candidate] = []
        var idCandidates: [Candidate] = []

        let longest = fields.filter { $0.kinds == [.string] }
            .map(\.averageValueBytes).max() ?? 1

        for field in fields {
            let coverage = Double(field.presentCount) / Double(sampled)
            guard field.kinds == [.string] else { continue }

            // --- ứng viên VĂN BẢN ---
            //
            // 0,5 × độ phủ + 0,3 × độ dài tương đối + 0,2 nếu tên nằm trong danh sách đã gặp.
            // Trọng số in ra trong `reason` để người đọc tự chấm lại.
            let relativeLength = longest > 0 ? field.averageValueBytes / longest : 0
            let nameBonus = knownTextFields.contains(field.name.lowercased()) ? 1.0 : 0.0
            let textScore = 0.5 * coverage + 0.3 * relativeLength + 0.2 * nameBonus
            textCandidates.append(Candidate(
                field: field.name, score: textScore,
                reason: format(0.5 * coverage) + " (phủ " + percent(coverage) + ")"
                    + " + " + format(0.3 * relativeLength)
                    + " (dài trung bình \(Int(field.averageValueBytes.rounded())) byte)"
                    + " + " + format(0.2 * nameBonus)
                    + (nameBonus > 0 ? " (tên quen)" : " (tên lạ)")))

            // --- ứng viên ĐỊNH DANH ---
            //
            // Định danh thì NGẮN, phủ gần hết, và **gần như không lặp**. Vế cuối là vế bắt được
            // một trường tên `id` mà 90% bản ghi trùng giá trị — nó không phải định danh, dù
            // nó tên gì.
            let unique = field.distinctCapped ? 1.0 : field.distinctRatio
            let shortness = field.averageValueBytes <= 64 ? 1.0 : 0.0
            let idName = knownIDFields.contains(field.name.lowercased()) ? 1.0 : 0.0
            let idScore = 0.45 * unique + 0.25 * coverage + 0.15 * shortness + 0.15 * idName
            if unique >= 0.9 || idName > 0 {
                idCandidates.append(Candidate(
                    field: field.name, score: idScore,
                    reason: format(0.45 * unique) + " (riêng " + percent(unique) + ")"
                        + " + " + format(0.25 * coverage) + " (phủ " + percent(coverage) + ")"
                        + " + " + format(0.15 * shortness)
                        + (shortness > 0 ? " (ngắn)" : " (dài)")
                        + " + " + format(0.15 * idName)
                        + (idName > 0 ? " (tên quen)" : " (tên lạ)")))
            }
        }

        textCandidates.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.field < $1.field
        }
        idCandidates.sort { $0.score != $1.score ? $0.score > $1.score : $0.field < $1.field }
        // Trường vừa được chọn làm văn bản thì không đồng thời là định danh.
        if let text = textCandidates.first?.field {
            idCandidates.removeAll { $0.field == text }
        }

        let chosen = Set([textCandidates.first?.field, idCandidates.first?.field].compactMap { $0 })
        let metadata = fields.map(\.name).filter { !chosen.contains($0) }
        return Schema(textCandidates: textCandidates, idCandidates: idCandidates,
                      metadataFields: metadata, nestedMetadataField: nested)
    }

    // MARK: - Lọc theo metadata

    /// Dòng có `field` mang đúng `value` (so trên biểu diễn JSON THÔ của giá trị).
    ///
    /// So trên byte thô chứ không giải mã: người dùng chọn giá trị từ chính danh sách
    /// `topValues` mà lượt quét sinh ra, nên hai bên đang so cùng một thứ.
    public static func lines(
        buffer: TextBuffer, field: String, equals value: String,
        limit: Int = 100_000, cancelToken: CancelToken? = nil
    ) -> [Int] {
        var out: [Int] = []
        let target = Array(value.utf8)
        JSONLScan.forEachLine(buffer: buffer, cancelToken: cancelToken) { line, index in
            guard out.count < limit, let fields = JSONScanner.topLevelFields(line) else { return }
            for candidate in fields where candidate.name == field {
                let slice = line[candidate.value]
                if slice.count == target.count,
                   slice.elementsEqual(target) { out.append(index) }
                break
            }
        }
        return out
    }

    /// Bảng `giá trị trường A` → `giá trị trường B`, quét corpus MỘT lượt.
    ///
    /// FR-KNW-926 cần bảng `id chunk → nguồn` để đếm phủ của bộ đánh giá. Đưa hẳn thành một
    /// hàm công khai thay vì để tầng app tự duyệt dòng: vòng duyệt ấy là chi tiết bên trong
    /// (khối piece table, `leftover`, nhịp tiến độ), và mở nó ra là mời mọi chỗ gọi viết lại
    /// một bản hơi khác.
    ///
    /// Bản ghi thiếu một trong hai trường thì KHÔNG vào bảng — chứ không vào với chuỗi rỗng,
    /// vì một bảng có khoá rỗng sẽ gộp mọi bản ghi thiếu id làm một.
    public static func map(
        buffer: TextBuffer, from key: String, to value: String,
        cancelToken: CancelToken? = nil
    ) -> [String: String] {
        var out: [String: String] = [:]
        JSONLScan.forEachLine(buffer: buffer, cancelToken: cancelToken) { line, _ in
            guard let fields = JSONScanner.topLevelFields(line) else { return }
            var found: String?
            var mapped: String?
            for field in fields where field.kind == .string {
                if field.name == key {
                    found = String(decoding: line[field.value], as: UTF8.self)
                } else if field.name == value {
                    mapped = String(decoding: line[field.value], as: UTF8.self)
                }
            }
            guard let found, let mapped, !found.isEmpty else { return }
            out[found] = mapped
        }
        return out
    }

    // MARK: - Phụ

    static func isBlank(_ line: UnsafeBufferPointer<UInt8>) -> Bool {
        for byte in line where byte != 0x20 && !(byte >= 0x09 && byte <= 0x0D) { return false }
        return true
    }

    /// Đường lui khi `BM25RawJSON` bỏ cuộc (giá trị có ký tự thoát): hỏi bộ đọc đầy đủ.
    private static func decoded(
        field: String, in line: UnsafeBufferPointer<UInt8>
    ) -> String? {
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(buffer: line)) as? [String: Any] else { return nil }
        return object[field] as? String
    }

    /// Số KÝ TỰ, đếm theo **ký tự Unicode** (scalar) chứ không theo cụm hiển thị (grapheme).
    ///
    /// Khác nhau ở văn bản tổ hợp: `"ề"` viết dạng NFD là hai scalar mà một cụm. Chọn scalar vì
    /// hai lý do đo được: đếm grapheme chạy thuật toán ngắt của Unicode trên từng ký tự và
    /// chiếm 57,7% lượt thống kê 1 GB; và con số này được dùng để so với NGƯỠNG ĐỘ DÀI của
    /// model, mà ngưỡng ấy đếm theo scalar/byte chứ không theo cụm hiển thị.
    ///
    /// Trên UTF-8 thì đếm scalar là đếm byte KHÔNG phải byte nối tiếp (`10xxxxxx`).
    static func scalarCount(_ bytes: UnsafeBufferPointer<UInt8>) -> Int {
        var count = 0
        for byte in bytes where (byte & 0xC0) != 0x80 { count += 1 }
        return count
    }

    /// Số TỪ: số lần chuyển từ khoảng trắng sang không-khoảng-trắng.
    ///
    /// Khoảng trắng ở đây là khoảng trắng ASCII. Ký tự trắng Unicode (U+00A0, U+2028…) không
    /// được tính là dấu ngắt — hiếm trong dữ liệu chunk, và nhận diện chúng đòi đúng phép tra
    /// bảng Unicode vừa bỏ đi.
    static func wordCount(_ bytes: UnsafeBufferPointer<UInt8>) -> Int {
        var count = 0
        var inWord = false
        for byte in bytes {
            let space = byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
            if space { inWord = false } else if !inWord { count += 1; inWord = true }
        }
        return count
    }

    /// FNV-1a 64 bit — cố định giữa các lần chạy, khác `Hasher` của Swift.
    static func hash(_ line: UnsafeBufferPointer<UInt8>, _ range: Range<Int>) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for index in range {
            value ^= UInt64(line[index])
            value = value &* 0x0000_0100_0000_01B3
        }
        return value
    }

    /// Histogram chia đều theo GIÁ TRỊ, không theo phân vị.
    ///
    /// Chia theo phân vị cho các cột cao bằng nhau — đẹp, và vô dụng: người xem histogram độ
    /// dài chunk đang tìm cái ĐUÔI, tức mấy chunk dài bất thường, và chia theo phân vị giấu
    /// đúng cái đuôi ấy đi.
    static func histogram(_ values: [Int], buckets: Int) -> Histogram {
        guard let smallest = values.min(), let largest = values.max() else {
            return Histogram(bounds: [], counts: [], minimum: 0, maximum: 0, total: 0, sum: 0)
        }
        let span = max(1, largest - smallest + 1)
        let width = max(1, Int((Double(span) / Double(buckets)).rounded(.up)))
        let count = max(1, Int((Double(span) / Double(width)).rounded(.up)))
        var bounds: [Int] = []
        for index in 0 ..< count { bounds.append(smallest + width * (index + 1) - 1) }
        var counts = [Int](repeating: 0, count: count)
        for value in values {
            let index = min(count - 1, (value - smallest) / width)
            counts[index] += 1
        }
        return Histogram(bounds: bounds, counts: counts, minimum: smallest, maximum: largest,
                         total: values.count, sum: values.reduce(0, +))
    }

    /// Giá trị dài hơn ngần này thì không đếm vào bảng "giá trị khác nhau".
    static let shortValueBytes = 200

    static func format(_ value: Double) -> String { String(format: "%.2f", value) }
    static func percent(_ value: Double) -> String { String(format: "%.0f%%", value * 100) }
}


/// Sửa TẠI CHỖ giá trị của một từ điển lồng trong từ điển khác.
///
/// `values[name, default: [:]].apply { … }` đi qua `_modify` nên bảng con được sửa ngay chỗ
/// nó nằm. Cách viết hiển nhiên hơn — `var table = values[name] ?? [:]` rồi gán lại — tạo tham
/// chiếu thứ hai, và mỗi bản ghi thành một lần chép cả bảng. Đó là đúng cái bẫy đã làm bộ dựng
/// chỉ mục BM25 thành O(n²) và tốn 29 giây cho một corpus 60 MB.
extension Dictionary {
    mutating func apply(_ body: (inout Self) -> Void) { body(&self) }
}
