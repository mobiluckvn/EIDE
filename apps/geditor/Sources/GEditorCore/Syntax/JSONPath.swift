import Foundation

/// Truy vấn JSONPath trên một `JSONIndex` (FR-FMT-504, phần còn nợ).
///
/// **Tập con, và nói rõ tập con ấy gồm gì.** JSONPath đầy đủ (RFC 9535) có cả biểu thức script
/// và hàm; làm hết thì tốn nhiều tuần và phần lớn không ai gõ trong một trình soạn thảo. Chỗ
/// này làm đúng những gì người ta thật sự gõ, và `unsupported` nói thẳng khi gặp phần còn lại —
/// im lặng trả về rỗng cho một cú pháp hợp lệ là cách tệ nhất, vì người dùng sẽ tưởng dữ liệu
/// của họ không có gì khớp.
///
/// | Viết được | Ví dụ |
/// |---|---|
/// | gốc | `$` |
/// | khóa | `$.ten` · `$['dia chi']` · `$["dia chi"]` |
/// | chỉ số | `$.sach[0]` · `$.sach[-1]` (đếm từ cuối) |
/// | mọi phần tử | `$.sach[*]` · `$.sach.*` |
/// | đệ quy | `$..gia` · `$..*` |
/// | lát cắt | `$.sach[0:2]` · `$.sach[::2]` · `$.sach[1:]` |
/// | hợp | `$.sach[0,2]` · `$['ten','gia']` |
/// | lọc | `$.sach[?(@.gia > 100000)]` · `$.sach[?(@.co_san)]` · `$[?(@ == "Số đỏ")]` |
///
/// **Chưa làm:** biểu thức script `[(...)]`, hàm `length()`, so khớp biểu thức chính quy, và
/// phép lọc lồng nhiều điều kiện `&&` `||`. Gặp chúng thì báo lỗi có tên, không đoán.
///
/// **Chỉ đọc.** Truy vấn không bao giờ sinh ra sửa đổi.
public enum JSONPath {

    // MARK: - Kết quả

    public struct Match: Equatable, Sendable {
        /// Đường dẫn chuẩn hóa tới nút, dán ngược vào ô truy vấn được.
        public let path: String
        /// Khoảng BYTE của giá trị trong văn bản gốc — chỗ để nhảy tới và bôi sáng.
        public let range: Range<Int>
        /// Dòng chứa đầu giá trị, đếm từ 1.
        public let line: Int
        /// Trích ngắn để hiện trong danh sách.
        public let preview: String
        public let kind: JSONIndex.Kind
    }

    public enum Failure: Error, Equatable, Sendable {
        /// Cú pháp truy vấn sai. `offset` là vị trí ký tự trong chính truy vấn.
        case syntax(message: String, offset: Int)
        /// Cú pháp JSONPath hợp lệ nhưng phần này chưa làm.
        case unsupported(String)

        public var message: String {
            switch self {
            case .syntax(let message, _): return message
            case .unsupported(let what): return "Chưa hỗ trợ \(what)"
            }
        }
    }

    // MARK: - Chạy

    /// Chạy truy vấn trên văn bản. Ném `Failure` nếu truy vấn sai; trả mảng rỗng nếu không khớp.
    ///
    /// Phân biệt hai chuyện ấy là cả điểm của hàm này: "truy vấn sai" và "không có gì khớp" là
    /// hai kết luận khác nhau, và gộp chúng lại sẽ khiến người dùng đi sửa dữ liệu trong khi
    /// thứ sai là dấu ngoặc họ gõ thiếu.
    public static func run(_ query: String, on index: JSONIndex, bytes: [UInt8]) throws -> [Match] {
        let steps = try parse(query)
        var current = index.isEmpty ? [] : [0]

        for step in steps {
            current = apply(step, to: current, in: index, bytes: bytes)
            if current.isEmpty { break }
        }

        let lines = LineTable(bytes: bytes)
        return current.map { node in
            Match(
                path: index.path(of: node),
                range: index.nodes[node].range,
                line: lines.line(at: index.nodes[node].range.lowerBound),
                preview: preview(of: node, in: index, bytes: bytes),
                kind: index.nodes[node].kind
            )
        }
    }

    /// Trích ngắn của một nút, đủ để nhận ra nó trong danh sách kết quả.
    static func preview(of node: Int, in index: JSONIndex, bytes: [UInt8]) -> String {
        let item = index.nodes[node]
        if item.kind.isContainer {
            let count = index.childIndices(of: node).count
            return item.kind == .object ? "{ \(count) khóa }" : "[ \(count) phần tử ]"
        }
        let text = index.scalarText(of: node, in: bytes)
        return text.count <= 60 ? text : String(text.prefix(60)) + "…"
    }

    // MARK: - Các bước của một truy vấn

    enum Step: Equatable {
        /// `.name` hoặc `['name']`; nhiều tên là phép hợp `['a','b']`.
        case names([String])
        /// `[0]`, `[-1]`, `[0,2]`.
        case indices([Int])
        /// `[*]` hoặc `.*` — mọi con trực tiếp.
        case wildcard
        /// `..` theo sau bởi tên, hoặc `..*`.
        case descendant(name: String?)
        /// `[a:b:c]`. `nil` nghĩa là bỏ trống.
        case slice(from: Int?, to: Int?, step: Int?)
        case filter(Filter)
    }

    enum Filter: Equatable {
        /// `?(@.key)` — có khóa ấy và giá trị không phải `false`/`null`.
        case exists(path: [String])
        case compare(path: [String], op: Comparison, literal: Literal)
    }

    enum Comparison: String, Equatable {
        case equal = "==", notEqual = "!=", less = "<", lessOrEqual = "<="
        case greater = ">", greaterOrEqual = ">="
    }

    enum Literal: Equatable {
        case number(Double)
        case string(String)
        case bool(Bool)
        case null
    }

    // MARK: - Áp một bước

    private static func apply(
        _ step: Step, to nodes: [Int], in index: JSONIndex, bytes: [UInt8]
    ) -> [Int] {
        var out: [Int] = []
        switch step {
        case .names(let names):
            for node in nodes {
                for child in index.childIndices(of: node)
                where index.nodes[child].indexInParent < 0 && names.contains(index.nodes[child].key) {
                    out.append(child)
                }
            }

        case .indices(let wanted):
            for node in nodes where index.nodes[node].kind == .array {
                let children = Array(index.childIndices(of: node))
                for i in wanted {
                    // Chỉ số âm đếm từ cuối, đúng như người ta quen ở Python.
                    let resolved = i < 0 ? children.count + i : i
                    if resolved >= 0 && resolved < children.count { out.append(children[resolved]) }
                }
            }

        case .wildcard:
            for node in nodes { out.append(contentsOf: index.childIndices(of: node)) }

        case .descendant(let name):
            for node in nodes { collectDescendants(of: node, name: name, in: index, into: &out) }

        case .slice(let from, let to, let stride):
            for node in nodes where index.nodes[node].kind == .array {
                let children = Array(index.childIndices(of: node))
                out.append(contentsOf: sliced(children, from: from, to: to, step: stride))
            }

        case .filter(let filter):
            for node in nodes {
                for child in index.childIndices(of: node)
                where matches(filter, node: child, in: index, bytes: bytes) {
                    out.append(child)
                }
            }
        }
        // Giữ THỨ TỰ TÀI LIỆU và bỏ trùng: `$..a..a` có thể chạm cùng một nút hai lần, và một
        // danh sách kết quả có mục lặp thì người dùng đếm sai số lần xuất hiện.
        var seen = Set<Int>()
        return out.filter { seen.insert($0).inserted }.sorted()
    }

    /// Duyệt cả cây con. Dùng ngăn xếp, cùng lý do với `JSONIndex`.
    private static func collectDescendants(
        of root: Int, name: String?, in index: JSONIndex, into out: inout [Int]
    ) {
        var stack = [root]
        while let node = stack.popLast() {
            for child in index.childIndices(of: node).reversed() {
                stack.append(child)
                if let name {
                    if index.nodes[child].indexInParent < 0 && index.nodes[child].key == name {
                        out.append(child)
                    }
                } else {
                    out.append(child)
                }
            }
        }
    }

    private static func sliced(
        _ items: [Int], from: Int?, to: Int?, step: Int?
    ) -> [Int] {
        let count = items.count
        let stride = step ?? 1
        guard stride != 0 else { return [] }

        func clamp(_ value: Int) -> Int { min(max(value, 0), count) }
        func resolve(_ value: Int?, default fallback: Int) -> Int {
            guard let value else { return fallback }
            return clamp(value < 0 ? count + value : value)
        }

        if stride > 0 {
            let start = resolve(from, default: 0)
            let end = resolve(to, default: count)
            guard start < end else { return [] }
            return Swift.stride(from: start, to: end, by: stride).map { items[$0] }
        }
        // Bước âm: đi ngược. `[::-1]` đảo cả mảng.
        let start = resolve(from, default: count - 1)
        let end = from == nil && to == nil ? -1 : (to.map { $0 < 0 ? count + $0 : $0 } ?? -1)
        guard start > end else { return [] }
        return Swift.stride(from: min(start, count - 1), to: max(end, -1), by: stride).map { items[$0] }
    }

    // MARK: - Lọc

    private static func matches(
        _ filter: Filter, node: Int, in index: JSONIndex, bytes: [UInt8]
    ) -> Bool {
        switch filter {
        case .exists(let path):
            guard let target = follow(path, from: node, in: index) else { return false }
            // `?(@.co_san)` với `co_san: false` là KHÔNG khớp — cùng quy ước với JavaScript,
            // và đó là quy ước người gõ JSONPath mang theo.
            switch index.nodes[target].kind {
            case .null: return false
            case .bool: return index.scalarText(of: target, in: bytes) == "true"
            default: return true
            }

        case .compare(let path, let op, let literal):
            guard let target = follow(path, from: node, in: index) else { return false }
            return compare(node: target, in: index, bytes: bytes, op: op, literal: literal)
        }
    }

    /// Đi theo `@.a.b` từ một nút.
    private static func follow(_ path: [String], from node: Int, in index: JSONIndex) -> Int? {
        var current = node
        for name in path {
            guard let next = index.childIndices(of: current).first(where: {
                index.nodes[$0].indexInParent < 0 && index.nodes[$0].key == name
            }) else { return nil }
            current = next
        }
        return current
    }

    private static func compare(
        node: Int, in index: JSONIndex, bytes: [UInt8], op: Comparison, literal: Literal
    ) -> Bool {
        let kind = index.nodes[node].kind
        let text = index.scalarText(of: node, in: bytes)

        switch literal {
        case .number(let wanted):
            // So sánh số phải ra SỐ, không so chuỗi: "9" > "10" theo chuỗi mà 9 < 10 theo số,
            // và một bộ lọc giá cả sai kiểu ấy thì im lặng cho ra tập kết quả sai.
            guard kind == .number, let value = Double(text) else { return false }
            return apply(op, value, wanted)
        case .string(let wanted):
            guard kind == .string else { return false }
            switch op {
            case .equal: return text == wanted
            case .notEqual: return text != wanted
            case .less: return text < wanted
            case .lessOrEqual: return text <= wanted
            case .greater: return text > wanted
            case .greaterOrEqual: return text >= wanted
            }
        case .bool(let wanted):
            guard kind == .bool else { return false }
            let value = text == "true"
            switch op {
            case .equal: return value == wanted
            case .notEqual: return value != wanted
            default: return false
            }
        case .null:
            switch op {
            case .equal: return kind == .null
            case .notEqual: return kind != .null
            default: return false
            }
        }
    }

    private static func apply(_ op: Comparison, _ a: Double, _ b: Double) -> Bool {
        switch op {
        case .equal: return a == b
        case .notEqual: return a != b
        case .less: return a < b
        case .lessOrEqual: return a <= b
        case .greater: return a > b
        case .greaterOrEqual: return a >= b
        }
    }
}
