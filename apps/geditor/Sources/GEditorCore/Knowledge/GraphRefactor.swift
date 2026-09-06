import Foundation

/// Bốn phép tái cấu trúc đồ thị, tất cả qua changeset duyệt được — FR-KNW-916.
///
/// Đặc tả: *"ĐỔI TÊN node toàn cục (cập nhật mọi cạnh và thuộc tính tham chiếu — tương đương
/// rename symbol trong IDE); GỘP nhiều node thành một (hợp cạnh, khử cạnh trùng **có báo cáo**);
/// TÁCH node; TRÍCH subgraph theo lựa chọn hoặc theo truy vấn ra file mới. **Không thao tác nào
/// ghi thẳng — tất cả là changeset duyệt được, một bước undo.**"*
///
/// ## Sửa TẠI CHỖ, không viết lại cả tệp
///
/// Cách dễ nhất là dựng lại toàn bộ văn bản DOT từ `DOTGraph`. Nó sai theo một cách rất tốn:
/// tệp của người dùng có chú thích, thứ tự riêng, cách xuống dòng riêng, và những thuộc tính mà
/// bộ đọc chưa hiểu. Viết lại là xoá hết chúng — và một công cụ "tái cấu trúc an toàn" mà làm
/// mất chú thích thì không ai dùng lần thứ hai.
///
/// Nên mọi phép ở đây trả về **danh sách sửa đổi theo vị trí byte**, áp lên chính văn bản gốc.
///
/// ## Chỗ nào không làm tự động được thì BÁO, không đoán
///
/// Bộ đọc DOT giữ SỐ DÒNG của từng cạnh, không giữ phạm vi byte của từng câu lệnh. Nên khi một
/// dòng chứa NHIỀU câu lệnh (`a -> b; a -> c;`), phép xoá hay phép sửa một cạnh trên dòng ấy
/// không xác định được chỗ. Ở đó bộ này **không đoán**: nó bỏ qua và ghi vào `warnings` kèm số
/// dòng, để người duyệt tự sửa. Đoán bừa trên một dòng nhiều câu lệnh là cách chắc chắn để làm
/// hỏng một tệp mà không ai thấy ngay.
public enum GraphRefactor {

    public struct Result: Equatable, Sendable {
        public var edits: [EntityResolution.Edit]
        /// Việc đã làm, để hiện trong bản xem trước.
        public var report: [String]
        /// Việc KHÔNG làm tự động được, kèm số dòng.
        public var warnings: [String]

        public var isEmpty: Bool { edits.isEmpty }
    }

    // MARK: - Đổi tên

    /// Đổi tên node toàn cục — dùng lại đúng bộ của FR-KNW-923.
    ///
    /// Dùng lại chứ không viết bản thứ hai: phép "tìm mọi lần xuất hiện của một định danh, bỏ
    /// qua chú thích, và chỉ chạm giá trị thuộc tính khi khoá là `label`" đã được viết và có
    /// bài kiểm ở đó. Hai bản của cùng một phép đổi tên là hai bản sẽ trôi khỏi nhau.
    public static func rename(
        _ node: String, to newName: String, in text: String, graph: DOTGraph
    ) -> Result {
        guard node != newName, !newName.isEmpty else { return Result(edits: [], report: [], warnings: []) }
        let edits = EntityResolution.renameEdits(in: text, mapping: [node: newName])
        var warnings: [String] = []
        if graph.nodes.contains(where: { $0.name == newName || $0.display == newName }) {
            warnings.append("«\(newName)» đã có trên đồ thị — đổi tên này GỘP hai node làm một "
                + "khi đọc lại")
        }
        if edits.isEmpty {
            warnings.append("không tìm thấy «\(node)» trong văn bản")
        }
        return Result(
            edits: edits,
            report: ["đổi tên «\(node)» → «\(newName)» tại \(edits.count) chỗ"],
            warnings: warnings)
    }

    // MARK: - Gộp

    /// Gộp nhiều node thành một: đổi tên hết về `canonical`, rồi KHỬ CẠNH TRÙNG.
    ///
    /// Khử cạnh trùng là vế mà đặc tả đòi *"có báo cáo"* — và báo cáo ấy quan trọng hơn phép
    /// khử: sau khi gộp, hai cạnh `a→c` và `b→c` thành hai cạnh `X→c` giống hệt nhau, và người
    /// dùng cần biết đã mất đi bao nhiêu quan hệ trùng lặp chứ không phải chỉ thấy đồ thị gọn đi.
    public static func merge(
        _ nodes: [String], into canonical: String, in text: String, graph: DOTGraph
    ) -> Result {
        let sources = nodes.filter { $0 != canonical }
        guard !sources.isEmpty else { return Result(edits: [], report: [], warnings: []) }
        var mapping: [String: String] = [:]
        for node in sources { mapping[node] = canonical }
        var edits = EntityResolution.renameEdits(in: text, mapping: mapping)
        var report = ["gộp \(sources.count + 1) node thành «\(canonical)» tại \(edits.count) chỗ"]
        var warnings: [String] = []

        // --- Khử cạnh trùng ---
        //
        // Tính trên đồ thị SAU khi đổi tên: quy mọi đầu cạnh về tên đích rồi tìm cặp trùng.
        func resolve(_ name: String) -> String { mapping[name] ?? name }
        var seen: [String: Int] = [:]
        var duplicateLines: [Int] = []
        var duplicates = 0
        for edge in graph.edges {
            let from = resolve(edge.from)
            let to = resolve(edge.to)
            // Vòng tự nối SINH RA bởi phép gộp: hai node vừa gộp vốn có cạnh nối nhau.
            //
            // Không tự xoá. Nhiều bộ vẽ đồ thị xoá thẳng, nhưng ở đây cạnh ấy có thể đang mang
            // nhãn mà người dùng cần đọc trước khi bỏ — nên chỉ báo, và báo kèm số dòng.
            if from == to, edge.from != edge.to {
                warnings.append("cạnh «\(edge.from)» → «\(edge.to)» ở dòng \(edge.line + 1) "
                    + "thành VÒNG TỰ NỐI sau khi gộp — giữ nguyên, xoá tay nếu không muốn")
            }
            let key = graph.isDirected
                ? "\(from)\u{1}\(to)"
                : [from, to].sorted().joined(separator: "\u{1}")
            if let first = seen[key] {
                duplicates += 1
                duplicateLines.append(edge.line)
                report.append("cạnh «\(from)» → «\(to)» ở dòng \(edge.line + 1) trùng với dòng "
                    + "\(first + 1)")
            } else {
                seen[key] = edge.line
            }
        }

        if duplicates > 0 {
            let removal = deleteLines(duplicateLines, in: text, graph: graph)
            edits.append(contentsOf: removal.edits)
            warnings.append(contentsOf: removal.warnings)
            report.append("khử \(removal.edits.count)/\(duplicates) cạnh trùng")
        }
        return Result(
            edits: merged(edits), report: report, warnings: warnings)
    }

    // MARK: - Tách

    /// Tách một node: chuyển những cạnh nối tới `neighbours` sang node mới.
    ///
    /// Node mới chỉ xuất hiện qua chính những cạnh ấy — không sinh câu lệnh khai riêng. Sinh
    /// thêm một câu lệnh khai nghĩa là phải đoán chỗ đặt nó và đoán những thuộc tính nào nên
    /// chép sang; cả hai đều là đoán, và người duyệt tự thêm thì chính xác hơn. `report` nói ra
    /// điều đó.
    public static func split(
        _ node: String, movingNeighbours neighbours: [String], to newName: String,
        in text: String, graph: DOTGraph
    ) -> Result {
        guard !newName.isEmpty, newName != node else {
            return Result(edits: [], report: [], warnings: ["tên node mới trùng tên cũ"])
        }
        let moving = Set(neighbours)
        var lines: [Int] = []
        for edge in graph.edges {
            let other = edge.from == node ? edge.to : (edge.to == node ? edge.from : nil)
            guard let other, moving.contains(other) else { continue }
            lines.append(edge.line)
        }
        guard !lines.isEmpty else {
            return Result(edits: [], report: [],
                          warnings: ["không có cạnh nào giữa «\(node)» và danh sách đã chọn"])
        }

        var edits: [EntityResolution.Edit] = []
        var warnings: [String] = []
        var changed = 0
        for line in Set(lines).sorted() {
            guard let range = lineRange(line, in: text) else { continue }
            let statement = String(decoding: Array(text.utf8)[range], as: UTF8.self)
            guard EntityResolution.statementCount(statement) == 1 else {
                warnings.append("dòng \(line + 1) có nhiều câu lệnh — không tách tự động được, "
                    + "tách tay rồi chạy lại")
                continue
            }
            // Trên một dòng MỘT câu lệnh, mọi lần xuất hiện của `node` đều là đầu cạnh ấy.
            let local = EntityResolution.renameEdits(in: statement, mapping: [node: newName])
            guard !local.isEmpty else { continue }
            changed += 1
            for edit in local {
                edits.append(EntityResolution.Edit(
                    range: (range.lowerBound + edit.range.lowerBound)
                        ..< (range.lowerBound + edit.range.upperBound),
                    replacement: edit.replacement))
            }
        }
        return Result(
            edits: merged(edits),
            report: [
                "tách «\(node)»: chuyển \(changed) cạnh sang «\(newName)»",
                "node mới KHÔNG được khai riêng — thêm câu lệnh khai và thuộc tính bằng tay nếu cần",
            ],
            warnings: warnings)
    }

    // MARK: - Trích subgraph

    /// Sinh một tệp DOT mới chứa đúng những node đã chọn và các cạnh GIỮA chúng.
    ///
    /// Cạnh nửa trong nửa ngoài bị bỏ, và số lượng ấy được báo — cùng lý do đã ghi ở
    /// `ContextPackage`: một quan hệ mà tệp mới không mang đủ hai vế sẽ trỏ tới một node không
    /// tồn tại trong chính tệp ấy.
    public static func extract(
        _ names: [String], from graph: DOTGraph, name: String = "trich"
    ) -> (text: String, report: [String]) {
        let wanted = Set(names)
        var lines = [graph.isDirected ? "digraph \(quote(name)) {" : "graph \(quote(name)) {"]
        var kept = 0
        for node in graph.nodes where wanted.contains(node.name) || wanted.contains(node.display) {
            kept += 1
            var parts: [String] = []
            for key in node.attributes.keys.sorted() {
                parts.append("\(key)=\(quote(node.attributes[key]!))")
            }
            lines.append("    \(quote(node.name))"
                + (parts.isEmpty ? "" : " [" + parts.joined(separator: ", ") + "]") + ";")
        }
        let arrow = graph.isDirected ? "->" : "--"
        var edges = 0
        var dropped = 0
        for edge in graph.edges {
            let inside = wanted.contains(edge.from) && wanted.contains(edge.to)
            guard inside else {
                if wanted.contains(edge.from) || wanted.contains(edge.to) { dropped += 1 }
                continue
            }
            edges += 1
            var parts: [String] = []
            for key in edge.attributes.keys.sorted() {
                parts.append("\(key)=\(quote(edge.attributes[key]!))")
            }
            lines.append("    \(quote(edge.from)) \(arrow) \(quote(edge.to))"
                + (parts.isEmpty ? "" : " [" + parts.joined(separator: ", ") + "]") + ";")
        }
        lines.append("}")
        var report = ["trích \(kept) node · \(edges) cạnh"]
        if dropped > 0 {
            report.append("bỏ \(dropped) cạnh chỉ có MỘT đầu nằm trong lựa chọn — một quan hệ "
                + "thiếu vế kia sẽ trỏ tới node không có trong tệp mới")
        }
        return (lines.joined(separator: "\n") + "\n", report)
    }

    static func quote(_ text: String) -> String {
        EntityResolution.needsQuotes(text)
            ? "\"" + text.replacingOccurrences(of: "\"", with: "\\\"") + "\"" : text
    }

    // MARK: - Bản xem trước

    /// Diff theo dòng của một changeset — thứ người duyệt thực sự cần thấy trước khi bấm.
    ///
    /// Không hiện diff mà chỉ hiện "42 thay đổi" thì hộp hỏi chỉ còn là một nút Đồng ý: không
    /// ai từ chối được cái mình không nhìn thấy. Đây là cùng lý lẽ đã ghi ở bản xem trước của
    /// phép thay thế trong FR-SRCH.
    ///
    /// Cắt ở `limit` dòng và **nói ra đã cắt bao nhiêu** — im lặng cắt bớt thì bản xem trước
    /// trở thành lời hứa sai về phạm vi thay đổi.
    public static func diff(
        _ edits: [EntityResolution.Edit], in text: String, limit: Int = 12
    ) -> [String] {
        guard !edits.isEmpty else { return [] }
        let bytes = Array(text.utf8)
        // Ranh giới dòng, tính một lần.
        var lineStarts = [0]
        for (index, byte) in bytes.enumerated() where byte == 0x0A { lineStarts.append(index + 1) }
        func lineIndex(of offset: Int) -> Int {
            var low = 0
            var high = lineStarts.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if lineStarts[middle] <= offset { low = middle } else { high = middle - 1 }
            }
            return low
        }

        var groups: [Int: [EntityResolution.Edit]] = [:]
        for edit in edits { groups[lineIndex(of: edit.range.lowerBound), default: []].append(edit) }

        var out: [String] = []
        var shown = 0
        for line in groups.keys.sorted() {
            guard let range = lineRange(line, in: text), let group = groups[line] else { continue }
            let old = String(decoding: bytes[range], as: UTF8.self)
            if shown == limit {
                out.append("… và \(groups.count - shown) dòng nữa")
                break
            }
            shown += 1
            // Sửa đổi vượt quá cuối dòng = xoá trọn dòng (đã nuốt cả ký tự xuống dòng).
            if group.contains(where: { $0.range.upperBound > range.upperBound }) {
                out.append("dòng \(line + 1): − \(old.trimmingCharacters(in: .whitespaces)) → XOÁ")
                continue
            }
            let local = group.map {
                EntityResolution.Edit(
                    range: ($0.range.lowerBound - range.lowerBound)
                        ..< ($0.range.upperBound - range.lowerBound),
                    replacement: $0.replacement)
            }
            let new = EntityResolution.apply(local, to: old)
            out.append("dòng \(line + 1): \(old.trimmingCharacters(in: .whitespaces)) → "
                + new.trimmingCharacters(in: .whitespaces))
        }
        return out
    }

    // MARK: - Phụ

    /// Xoá trọn những dòng chỉ chứa MỘT câu lệnh; dòng nhiều câu lệnh thì báo, không đoán.
    static func deleteLines(_ lines: [Int], in text: String, graph: DOTGraph) -> Result {
        var edits: [EntityResolution.Edit] = []
        var warnings: [String] = []
        let bytes = Array(text.utf8)
        for line in Set(lines).sorted() {
            guard let range = lineRange(line, in: text) else { continue }
            let statement = String(decoding: bytes[range], as: UTF8.self)
            guard EntityResolution.statementCount(statement) == 1 else {
                warnings.append("dòng \(line + 1) có nhiều câu lệnh — không xoá tự động được")
                continue
            }
            // Nuốt luôn ký tự xuống dòng để không để lại một dòng trống.
            let end = min(bytes.count, range.upperBound + 1)
            edits.append(EntityResolution.Edit(range: range.lowerBound ..< end, replacement: ""))
        }
        return Result(edits: edits, report: [], warnings: warnings)
    }

    /// Phạm vi byte của một dòng, KHÔNG tính ký tự xuống dòng.
    static func lineRange(_ line: Int, in text: String) -> Range<Int>? {
        let bytes = Array(text.utf8)
        var current = 0
        var start = 0
        var index = 0
        while index <= bytes.count {
            if index == bytes.count || bytes[index] == 0x0A {
                if current == line { return start ..< index }
                current += 1
                start = index + 1
            }
            index += 1
        }
        return nil
    }

    /// Gộp và sắp sửa đổi; bỏ những chỗ CHỒNG nhau.
    ///
    /// Chồng nhau xảy ra khi một dòng vừa bị đổi tên vừa bị xoá — và khi ấy phép xoá thắng, vì
    /// đổi tên trên một dòng sắp biến mất là công vô ích, còn áp cả hai thì phạm vi lệch nhau
    /// và văn bản hỏng.
    static func merged(_ edits: [EntityResolution.Edit]) -> [EntityResolution.Edit] {
        let sorted = edits.sorted {
            $0.range.lowerBound != $1.range.lowerBound
                ? $0.range.lowerBound < $1.range.lowerBound
                : $0.range.count > $1.range.count
        }
        var out: [EntityResolution.Edit] = []
        for edit in sorted {
            if let last = out.last, edit.range.lowerBound < last.range.upperBound { continue }
            out.append(edit)
        }
        return out
    }
}

extension EntityResolution {

    /// Số câu lệnh trên một đoạn văn bản DOT — dùng để biết một dòng có sửa tự động được không.
    ///
    /// Đếm dấu `;` ngoài chuỗi và ngoài `[...]`, cộng một. Dòng kết thúc bằng `;` không tính
    /// thành hai: một câu lệnh có dấu chấm phẩy cuối vẫn là một câu lệnh.
    static func statementCount(_ text: String) -> Int {
        var count = 0
        var inString = false
        var depth = 0
        var sawContent = false
        for character in text {
            if character == "\"" { inString.toggle(); continue }
            if inString { continue }
            if character == "[" { depth += 1 }
            if character == "]" { depth = max(0, depth - 1) }
            if character == ";", depth == 0 {
                if sawContent { count += 1 }
                sawContent = false
                continue
            }
            if !character.isWhitespace, character != "{", character != "}" { sawContent = true }
        }
        if sawContent { count += 1 }
        return max(count, 0)
    }
}
