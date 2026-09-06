import Foundation

/// Chu trình gom biến thể entity — FR-KNW-923.
///
/// Đặc tả: *"MỘT pipeline nối ba năng lực đã có: (1) quét danh sách entity → fuzzy matching →
/// cụm ứng viên có điểm; (2) người dùng duyệt từng cụm và CHỌN dạng chuẩn; (3) sinh ĐỒNG THỜI
/// ba đầu ra nhất quán trong một changeset: bảng ánh xạ alias→canonical (CSV), chuỗi rename
/// node trên đồ thị, cập nhật danh sách entity marker. **Không bao giờ tự merge — mọi thứ qua
/// duyệt.**"*
///
/// ## "Không bao giờ tự merge" là ràng buộc quyết định hình dạng của cả tệp này
///
/// Nên pipeline chia làm HAI nửa, và nửa sau **chỉ chạy khi có bảng duyệt**:
///
/// 1. `clusters(...)` đề xuất — nó không sửa gì cả;
/// 2. `reviewCSV(...)` sinh bảng để người dùng sửa, mỗi dòng một alias, cột `canonical` điền
///    sẵn một ĐỀ XUẤT;
/// 3. `changeset(...)` nhận bảng ĐÃ DUYỆT và sinh ba đầu ra.
///
/// Bảng duyệt là một tệp CSV chứ không phải một hộp thoại: nó diff được, vào git được, và người
/// dùng sửa nó bằng chính bảng CSV của ứng dụng này. Cùng khuôn với bộ đánh giá golden set
/// (FR-KNW-926) — tệp là nguồn sự thật.
///
/// ## Đổi tên trên DOT LÀ phép gộp, và đó là điều đã được duyệt
///
/// Đổi `"Nguyen Van A"` thành `"Nguyễn Văn A"` khi tên sau đã có nghĩa là hai node mang cùng
/// một định danh — và DOT gộp chúng làm một khi đọc lại. Phép gộp ấy CÓ THẬT, nhưng nó xảy ra
/// qua một changeset người dùng đã duyệt, không phải tự động. `Changeset.merges` kể tên những
/// chỗ ấy để người duyệt thấy trước.
public enum EntityResolution {

    // MARK: - Cụm ứng viên

    public struct Cluster: Equatable, Sendable {
        /// Các biến thể, theo thứ tự xuất hiện.
        public var members: [String]
        /// Dạng chuẩn ĐỀ XUẤT — người dùng đổi được.
        public var canonical: String
        /// Độ giống NHỎ NHẤT trong cụm — cụm càng lỏng thì càng đáng ngờ.
        public var weakestSimilarity: Double
        /// Số lần xuất hiện của từng biến thể, nếu chỗ gọi đưa vào.
        public var counts: [String: Int]

        public var size: Int { members.count }
    }

    public struct Config: Equatable, Sendable {
        public var similarity: Double
        /// Nhận cả biến thể VIẾT TẮT (chữ cái đầu).
        public var matchAbbreviations: Bool
        /// Trần số entity đưa vào phép so mờ. 0 = không trần.
        public var limit: Int

        public init(similarity: Double = 0.85, matchAbbreviations: Bool = true,
                    limit: Int = 20_000) {
            self.similarity = min(1, max(0.5, similarity))
            self.matchAbbreviations = matchAbbreviations
            self.limit = max(0, limit)
        }
    }

    /// Gom biến thể.
    ///
    /// - Parameter counts: số lần xuất hiện, dùng để chọn dạng chuẩn đề xuất. Không có thì
    ///   chọn theo độ dài.
    public static func clusters(
        _ entities: [String], counts: [String: Int] = [:], config: Config = Config(),
        cancelToken: CancelToken? = nil
    ) -> [Cluster] {
        // Bỏ trùng HOÀN TOÀN trước: hai lần khai cùng một tên không phải một biến thể.
        var unique: [String] = []
        var seen = Set<String>()
        for entity in entities {
            let text = entity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, seen.insert(text).inserted else { continue }
            unique.append(text)
        }
        guard config.limit == 0 || unique.count <= config.limit else { return [] }

        var groups = TextDistance.clusters(
            unique, threshold: config.similarity, cancelToken: cancelToken)

        if config.matchAbbreviations {
            groups = merge(groups, with: abbreviationPairs(unique), count: unique.count)
        }

        return groups.map { group in
            let members = group.map { unique[$0] }
            var weakest = 1.0
            for left in 0 ..< members.count {
                for right in (left + 1) ..< members.count {
                    weakest = min(weakest, TextDistance.similarity(
                        members[left], members[right], threshold: 0))
                }
            }
            return Cluster(
                members: members, canonical: suggest(members, counts: counts),
                weakestSimilarity: members.count > 1 ? weakest : 1,
                counts: counts.filter { members.contains($0.key) })
        }
    }

    /// Dạng chuẩn ĐỀ XUẤT, theo bốn tiêu chí xếp thứ tự.
    ///
    /// 1. **Hay gặp nhất.** Dạng người ta dùng nhiều là dạng ít gây ngạc nhiên nhất.
    /// 2. **Dài nhất.** Giữa «NHNN» và «Ngân hàng Nhà nước», bản dài là bản một người đọc ngoài
    ///    hiểu được. Viết tắt tiện cho người gõ, không tiện cho người đọc lại.
    /// 3. **CÒN DẤU.** Giữa «Nguyễn Văn A» và «Nguyen Van A» — bằng số lần, bằng độ dài — bản
    ///    còn dấu là bản mang nhiều thông tin hơn. Không có tiêu chí này thì kết quả rơi vào
    ///    thứ tự chữ cái, và thứ tự chữ cái đặt bản KHÔNG dấu lên trước; một bài tự kiểm bắt
    ///    được đúng chỗ ấy.
    /// 4. **Thứ tự chữ.** Tất định, và chỉ để phá hoà lần cuối.
    ///
    /// Đây là ĐỀ XUẤT, không phải quyết định: người duyệt sửa cột `canonical` là xong.
    public static func suggest(_ members: [String], counts: [String: Int]) -> String {
        members.max {
            let left = counts[$0] ?? 0, right = counts[$1] ?? 0
            if left != right { return left < right }
            if $0.count != $1.count { return $0.count < $1.count }
            let leftMarks = diacriticCount($0), rightMarks = diacriticCount($1)
            if leftMarks != rightMarks { return leftMarks < rightMarks }
            return $0 > $1
        } ?? members.first ?? ""
    }

    /// Số ký tự KHÔNG thuộc ASCII — thước đo "còn dấu" đủ dùng cho tiếng Việt.
    static func diacriticCount(_ text: String) -> Int {
        text.unicodeScalars.filter { $0.value > 127 }.count
    }

    /// Cặp (viết tắt, dạng đầy đủ) — chữ cái đầu của từng từ.
    ///
    /// ## Ranh giới: đây là luật HẸP, và nó cố ý hẹp
    ///
    /// Chỉ nhận đúng một luật: chuỗi chữ cái đầu của các từ. «NHNN» ↔ «Ngân hàng Nhà nước» thì
    /// nhận; «NH Nhà nước», «N.H.N.N», «NHTMCP» thì không. Luật rộng hơn sẽ gom nhầm — hai tổ
    /// chức khác nhau rất hay có cùng chữ cái đầu — và một cụm gom nhầm mà người duyệt bấm
    /// "đồng ý" là một phép gộp sai đi thẳng vào dữ liệu.
    static func abbreviationPairs(_ values: [String]) -> [(Int, Int)] {
        var initialsOf: [String: [Int]] = [:]
        var normalized: [String] = []
        for value in values {
            let words = TextDistance.normalize(value).split(separator: " ")
            normalized.append(TextDistance.normalize(value).replacingOccurrences(of: " ", with: ""))
            guard words.count >= 2 else { continue }
            let initials = String(words.compactMap(\.first))
            initialsOf[initials, default: []].append(values.firstIndex(of: value) ?? 0)
        }
        var pairs: [(Int, Int)] = []
        for (index, compact) in normalized.enumerated() {
            // Chỉ chuỗi NGẮN mới là ứng viên viết tắt, và nó phải toàn chữ cái.
            guard compact.count >= 2, compact.count <= 6 else { continue }
            for full in initialsOf[compact] ?? [] where full != index {
                pairs.append((min(index, full), max(index, full)))
            }
        }
        return pairs
    }

    /// Gộp thêm những cặp rời vào tập cụm đã có.
    static func merge(_ groups: [[Int]], with pairs: [(Int, Int)], count: Int) -> [[Int]] {
        guard !pairs.isEmpty else { return groups }
        var parent = Array(0 ..< count)
        func find(_ node: Int) -> Int {
            var node = node
            while parent[node] != node { parent[node] = parent[parent[node]]; node = parent[node] }
            return node
        }
        func union(_ left: Int, _ right: Int) {
            let a = find(left), b = find(right)
            if a != b { parent[max(a, b)] = min(a, b) }
        }
        for group in groups {
            for member in group.dropFirst() { union(group[0], member) }
        }
        for pair in pairs { union(pair.0, pair.1) }
        var table: [Int: [Int]] = [:]
        for index in 0 ..< count { table[find(index), default: []].append(index) }
        return table.values.filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { ($0.first ?? 0) < ($1.first ?? 0) }
    }

    // MARK: - Bảng duyệt

    /// Bảng để người dùng DUYỆT. Cột `canonical` điền sẵn đề xuất; sửa nó là chọn dạng chuẩn.
    ///
    /// Cột `giu_nguyen` để người duyệt LOẠI một cụm gom nhầm: điền `x` thì dòng ấy không sinh
    /// thay đổi nào. Không có cột này thì cách duy nhất để từ chối một cụm là xoá dòng, và xoá
    /// dòng là thao tác dễ làm nhầm nhất trong một bảng.
    public static func reviewCSV(_ clusters: [Cluster]) -> String {
        var out = "cum,alias,canonical,giu_nguyen,so_lan,do_giong\n"
        for (number, cluster) in clusters.enumerated() {
            for member in cluster.members {
                out += [
                    String(number + 1), member, cluster.canonical, "",
                    String(cluster.counts[member] ?? 0),
                    String(format: "%.2f", cluster.weakestSimilarity),
                ].map(field).joined(separator: ",") + "\n"
            }
        }
        return out
    }

    private static func field(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
        public init(message: String) { self.message = message }
    }

    /// Đọc bảng đã duyệt thành ánh xạ `alias → canonical`.
    ///
    /// Bỏ những dòng `giu_nguyen` có đánh dấu, và bỏ những dòng mà alias TRÙNG canonical (không
    /// có gì để đổi).
    public static func parseReview(_ csv: String) throws -> [String: String] {
        let bytes = Array(csv.utf8)
        let dialect = CSVEngine.detectDialect(sample: Array(bytes.prefix(64 << 10)))
        let rows = CSVEngine.parse(bytes, dialect: dialect)
        guard let header = rows.first else {
            throw Failure(message: "bảng duyệt rỗng")
        }
        func text(_ field: CSVField) -> String {
            String(decoding: CSVEngine.unescape(Array(bytes[field.range]), dialect: dialect),
                   as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        func column(_ name: String) -> Int? {
            for (index, field) in header.enumerated()
            where text(field).lowercased() == name { return index }
            return nil
        }
        guard let aliasColumn = column("alias"), let canonicalColumn = column("canonical") else {
            throw Failure(message: "bảng duyệt thiếu cột «alias» hoặc «canonical»")
        }
        let keepColumn = column("giu_nguyen")

        var mapping: [String: String] = [:]
        for row in rows.dropFirst() {
            guard aliasColumn < row.count, canonicalColumn < row.count else { continue }
            if let keepColumn, keepColumn < row.count, !text(row[keepColumn]).isEmpty {
                continue
            }
            let alias = text(row[aliasColumn])
            let canonical = text(row[canonicalColumn])
            guard !alias.isEmpty, !canonical.isEmpty, alias != canonical else { continue }
            if let existing = mapping[alias], existing != canonical {
                throw Failure(message: "alias «\(alias)» được gán hai dạng chuẩn khác nhau: "
                    + "«\(existing)» và «\(canonical)»")
            }
            mapping[alias] = canonical
        }
        return mapping
    }

    // MARK: - Changeset

    public struct Edit: Equatable, Sendable {
        public var range: Range<Int>
        public var replacement: String
    }

    public struct Changeset: Equatable, Sendable {
        /// Bảng ánh xạ alias → canonical, dạng CSV.
        public var aliasCSV: String
        /// Sửa đổi trên văn bản DOT, theo vị trí byte TĂNG DẦN và không chồng nhau.
        public var edits: [Edit]
        /// Danh sách entity marker sau khi áp.
        public var markers: [String]
        /// Những chỗ phép đổi tên làm HAI node thành MỘT khi đọc lại.
        public var merges: [String]
        /// Alias không tìm thấy trên đồ thị — bảng duyệt trỏ vào thứ không có.
        public var unknownAliases: [String]

        public var isEmpty: Bool { edits.isEmpty && aliasCSV.isEmpty }
    }

    /// Sinh ba đầu ra CÙNG LÚC từ bảng đã duyệt.
    ///
    /// Cùng lúc và từ MỘT nguồn: ba đầu ra sinh ở ba chỗ khác nhau là ba chỗ để chúng lệch
    /// nhau, và một bảng ánh xạ nói khác đồ thị là thứ không ai phát hiện cho tới lúc truy vấn
    /// ra kết quả rỗng.
    public static func changeset(
        mapping: [String: String], dotText: String, graph: DOTGraph, markers: [String] = []
    ) -> Changeset {
        var csv = "alias,canonical\n"
        for alias in mapping.keys.sorted() {
            csv += field(alias) + "," + field(mapping[alias]!) + "\n"
        }

        let existingNames = Set(graph.nodes.map(\.name))
        let existingLabels = Set(graph.nodes.map(\.display))
        var unknown: [String] = []
        for alias in mapping.keys.sorted()
        where !existingNames.contains(alias) && !existingLabels.contains(alias) {
            unknown.append(alias)
        }

        // Chỗ đổi tên làm hai node thành một: tên đích ĐÃ tồn tại trên đồ thị.
        var merges: [String] = []
        for alias in mapping.keys.sorted() {
            let canonical = mapping[alias]!
            if existingNames.contains(canonical) || existingLabels.contains(canonical) {
                merges.append("«\(alias)» → «\(canonical)» (đích đã có trên đồ thị)")
            }
        }

        let edits = renameEdits(in: dotText, mapping: mapping)

        var updated = Set(markers.isEmpty ? graph.nodes.map(\.display) : markers)
        for (alias, canonical) in mapping {
            updated.remove(alias)
            updated.insert(canonical)
        }
        return Changeset(
            aliasCSV: csv, edits: edits, markers: updated.sorted(), merges: merges,
            unknownAliases: unknown)
    }

    /// Vị trí mọi lần xuất hiện của một ĐỊNH DANH trong văn bản DOT.
    ///
    /// ## Vì sao không thay chuỗi thô
    ///
    /// `text.replacingOccurrences(of: "An", with: …)` sẽ đổi cả chữ «An» trong `label="Ban An
    /// toàn"` và trong một chú thích. Bộ này chỉ nhận **định danh trọn vẹn**: một chuỗi trong
    /// nháy kép, hoặc một dãy chữ/số/gạch dưới đứng riêng — và bỏ qua chú thích.
    ///
    /// Giá trị thuộc tính (`x = "An"`) được xử lý theo NGHĨA: chỉ đổi khi khoá là `label`, vì
    /// đó là chỗ chứa TÊN HIỂN THỊ của entity. Đổi mọi giá trị thì một thuộc tính `ghi_chu="An
    /// ký"` cũng bị sửa.
    static func renameEdits(in text: String, mapping: [String: String]) -> [Edit] {
        guard !mapping.isEmpty else { return [] }
        var edits: [Edit] = []
        let bytes = Array(text.utf8)
        var index = 0
        var lastKey = ""          // khoá thuộc tính vừa gặp, khi ta đang ở phần giá trị
        var afterEquals = false

        func flushToken(_ token: String, _ start: Int, _ end: Int, quoted: Bool) {
            // Ở phần GIÁ TRỊ thì chỉ đổi khi khoá là `label`.
            if afterEquals, lastKey.lowercased() != "label" { return }
            guard let canonical = mapping[token] else { return }
            let replacement = quoted || needsQuotes(canonical)
                ? "\"" + canonical.replacingOccurrences(of: "\"", with: "\\\"") + "\""
                : canonical
            edits.append(Edit(range: start ..< end, replacement: replacement))
        }

        while index < bytes.count {
            let byte = bytes[index]
            // --- chú thích ---
            if byte == 0x2F, index + 1 < bytes.count, bytes[index + 1] == 0x2F {
                while index < bytes.count, bytes[index] != 0x0A { index += 1 }
                continue
            }
            if byte == 0x23 {
                while index < bytes.count, bytes[index] != 0x0A { index += 1 }
                continue
            }
            if byte == 0x2F, index + 1 < bytes.count, bytes[index + 1] == 0x2A {
                index += 2
                while index + 1 < bytes.count,
                      !(bytes[index] == 0x2A && bytes[index + 1] == 0x2F) { index += 1 }
                index = min(bytes.count, index + 2)
                continue
            }
            // --- chuỗi trong nháy ---
            if byte == 0x22 {
                let start = index
                index += 1
                var value: [UInt8] = []
                while index < bytes.count, bytes[index] != 0x22 {
                    if bytes[index] == 0x5C, index + 1 < bytes.count {
                        value.append(bytes[index + 1])
                        index += 2
                        continue
                    }
                    value.append(bytes[index])
                    index += 1
                }
                index = min(bytes.count, index + 1)
                let token = String(decoding: value, as: UTF8.self)
                flushToken(token, start, index, quoted: true)
                if !afterEquals { lastKey = token }
                afterEquals = false
                continue
            }
            // --- định danh trần ---
            if isIdentifier(byte) {
                let start = index
                while index < bytes.count, isIdentifier(bytes[index]) { index += 1 }
                let token = String(decoding: bytes[start ..< index], as: UTF8.self)
                flushToken(token, start, index, quoted: false)
                if !afterEquals { lastKey = token }
                afterEquals = false
                continue
            }
            if byte == 0x3D { afterEquals = true }
            else if byte != 0x20 && byte != 0x09 { afterEquals = false }
            index += 1
        }
        return edits.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Byte thuộc về một định danh DOT trần.
    ///
    /// Chữ có dấu (byte ≥ 0x80) cũng tính: DOT không cho tên có dấu khi không bọc nháy, nhưng
    /// tệp thật thì có, và bỏ qua chúng nghĩa là không đổi tên được đúng những entity tiếng
    /// Việt mà tính năng này sinh ra để phục vụ.
    static func isIdentifier(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A)
            || (byte >= 0x61 && byte <= 0x7A) || byte == 0x5F || byte >= 0x80
    }

    static func needsQuotes(_ text: String) -> Bool {
        text.isEmpty || text.utf8.contains { !isIdentifier($0) }
    }

    /// Áp changeset lên văn bản — dùng cho bản xem trước và cho bài kiểm.
    ///
    /// Áp từ CUỐI về ĐẦU để mọi vị trí phía trước không bị dịch.
    public static func apply(_ edits: [Edit], to text: String) -> String {
        var bytes = Array(text.utf8)
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            guard edit.range.lowerBound >= 0, edit.range.upperBound <= bytes.count else { continue }
            bytes.replaceSubrange(edit.range, with: Array(edit.replacement.utf8))
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
