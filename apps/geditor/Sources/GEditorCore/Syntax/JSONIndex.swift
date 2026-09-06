import Foundation

/// Cây JSON dạng MẢNG PHẲNG, mỗi nút biết mình nằm ở khoảng byte nào của văn bản gốc.
///
/// **Vì sao không dùng `JSONTool.Parser` có sẵn.** Hai thứ này giải hai bài khác nhau.
/// `JSONTool.Parser` dựng cây để VIẾT LẠI — định dạng, thu gọn, sắp xếp khóa — nên nó giữ
/// nguyên văn từng giá trị và không cần biết chúng nằm ở đâu. JSONPath thì ngược lại: nó không
/// viết gì cả, nhưng mỗi kết quả phải nhảy được tới đúng chỗ trong tài liệu, tức là phải có
/// khoảng byte. Nhồi khoảng byte vào `Value` sẽ làm nặng đường định dạng mà chẳng ai dùng tới.
///
/// **Không đệ quy.** Duyệt bằng ngăn xếp tường minh chứ không gọi đệ quy như `JSONTool.Parser`.
/// Một file JSON lồng vài nghìn tầng — sinh ra bằng máy thì chuyện thường — sẽ làm tràn ngăn
/// xếp và app tắt ngóm, không có thông báo nào. Ở đây tầng lồng chỉ là một con số.
///
/// **Chỉ đọc.** Không hàm nào ở đây sinh ra sửa đổi.
public struct JSONIndex {

    /// Trần kích thước để dựng chỉ mục.
    ///
    /// Cùng trần và cùng lý do với `DocumentOutline.sizeLimit`: chỉ mục phải đọc TOÀN tài liệu,
    /// và trên file hàng trăm MB thì đó là một khoản chờ mà người dùng không được báo trước.
    /// Nói thẳng là không dựng thì tử tế hơn.
    public static let sizeLimit = DocumentOutline.sizeLimit

    public enum Kind: UInt8, Sendable {
        case object, array, string, number, bool, null

        public var isContainer: Bool { self == .object || self == .array }
    }

    public struct Node: Sendable {
        public let kind: Kind
        /// Khóa trong object cha, ĐÃ BỎ dấu nháy. Rỗng nếu cha là mảng hoặc đây là gốc.
        public let key: String
        /// Vị trí trong mảng cha; `-1` nếu cha là object hoặc đây là gốc.
        public let indexInParent: Int
        /// Khoảng BYTE của chính giá trị trong văn bản gốc — không gồm khóa, không gồm dấu phẩy.
        public let range: Range<Int>
        /// Chỉ số nút cha; `-1` cho gốc.
        public let parent: Int
        public let depth: Int
        /// Khoảng chỉ số trong `children` — xem `childIndices(of:)`.
        public internal(set) var childSpan: Range<Int>
    }

    public private(set) var nodes: [Node] = []

    /// Chỉ số các nút con, gom liên tục theo cha. Đọc qua `childIndices(of:)`.
    public private(set) var children: [Int] = []

    /// Tài liệu vượt trần, hoặc không phải JSON hợp lệ.
    public private(set) var failure: JSONIssue?
    public private(set) var tooLarge = false

    public var isEmpty: Bool { nodes.isEmpty }

    public func childIndices(of node: Int) -> ArraySlice<Int> {
        children[nodes[node].childSpan]
    }

    // MARK: - Dựng

    public init(text: String) {
        self.init(bytes: Array(text.utf8))
    }

    public init(bytes: [UInt8]) {
        guard bytes.count <= Self.sizeLimit else {
            tooLarge = true
            return
        }
        var scanner = Scanner(bytes: bytes)
        do {
            nodes = try scanner.run()
        } catch let issue as JSONIssue {
            failure = issue
            nodes = []
            return
        } catch {
            failure = JSONIssue(message: "Không đọc được", offset: 0, line: 1, column: 1)
            nodes = []
            return
        }
        linkChildren()
    }

    /// Gom chỉ số con thành từng khoảng liên tục.
    ///
    /// Hai lượt đếm chứ không `[[Int]]`: một mảng lồng mảng cho vài trăm nghìn nút là vài trăm
    /// nghìn lần cấp phát, và nó hiện ra thành khựng ngay lúc mở file.
    private mutating func linkChildren() {
        guard !nodes.isEmpty else { return }
        var counts = [Int](repeating: 0, count: nodes.count)
        for node in nodes where node.parent >= 0 { counts[node.parent] += 1 }

        var start = 0
        for i in nodes.indices {
            nodes[i].childSpan = start ..< (start + counts[i])
            start += counts[i]
        }

        children = [Int](repeating: 0, count: start)
        var filled = [Int](repeating: 0, count: nodes.count)
        // Nút được sinh ra theo THỨ TỰ TÀI LIỆU, nên đổ theo thứ tự ấy thì con của mỗi cha cũng
        // giữ đúng thứ tự trong file. `$.a[0]` phải ra trước `$.a[1]`.
        for (i, node) in nodes.enumerated() where node.parent >= 0 {
            let slot = nodes[node.parent].childSpan.lowerBound + filled[node.parent]
            children[slot] = i
            filled[node.parent] += 1
        }
    }

    // MARK: - Đường dẫn hiển thị

    /// Đường dẫn chuẩn hóa của một nút, ví dụ `$.store.book[0].title`.
    public func path(of node: Int) -> String {
        var parts: [String] = []
        var current = node
        while current >= 0 {
            let item = nodes[current]
            if item.parent < 0 { break }
            if item.indexInParent >= 0 {
                parts.append("[\(item.indexInParent)]")
            } else if Self.isPlainName(item.key) {
                parts.append(".\(item.key)")
            } else {
                // Khóa có dấu cách, dấu chấm hay chữ tiếng Việt thì phải bọc ngoặc, nếu không
                // đường dẫn in ra sẽ không dán ngược lại vào ô truy vấn được.
                parts.append("['\(item.key.replacingOccurrences(of: "'", with: "\\'"))']")
            }
            current = item.parent
        }
        return "$" + parts.reversed().joined()
    }

    static func isPlainName(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        for (offset, scalar) in key.unicodeScalars.enumerated() {
            let isLetter = (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z")
            let isDigit = scalar >= "0" && scalar <= "9"
            if isLetter || scalar == "_" { continue }
            if isDigit && offset > 0 { continue }
            return false
        }
        return true
    }

    // MARK: - Đọc giá trị vô hướng

    /// Nội dung nguyên văn của nút trong `bytes`, đã bỏ dấu nháy nếu là chuỗi.
    public func scalarText(of node: Int, in bytes: [UInt8]) -> String {
        let item = nodes[node]
        var range = item.range
        if item.kind == .string, range.count >= 2 {
            range = (range.lowerBound + 1) ..< (range.upperBound - 1)
        }
        return String(decoding: bytes[range], as: UTF8.self)
    }

    // MARK: - Bộ quét

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0
        var nodes: [Node] = []

        /// Ngăn xếp các container đang mở: (chỉ số nút, số con đã thấy).
        var open: [(node: Int, count: Int)] = []

        init(bytes: [UInt8]) { self.bytes = bytes }

        mutating func run() throws -> [Node] {
            skipSpace()
            guard index < bytes.count else {
                throw issue("File rỗng, không có giá trị JSON nào")
            }
            try scanValue(key: "", indexInParent: -1, parent: -1, depth: 0)
            skipSpace()
            guard index >= bytes.count else {
                throw issue("Còn thừa nội dung sau giá trị JSON đã kết thúc")
            }
            return nodes
        }

        /// Đọc một giá trị; nếu là container thì đọc luôn cả phần bên trong.
        ///
        /// Vòng lặp + ngăn xếp thay cho đệ quy: xem ghi chú ở đầu tệp.
        private mutating func scanValue(
            key: String, indexInParent: Int, parent: Int, depth: Int
        ) throws {
            var pendingKey = key
            var pendingIndex = indexInParent
            var pendingParent = parent
            var pendingDepth = depth

            while true {
                skipSpace()
                guard index < bytes.count else { throw issue("Thiếu giá trị") }
                let start = index
                let byte = bytes[index]

                if byte == UInt8(ascii: "{") || byte == UInt8(ascii: "[") {
                    let kind: Kind = byte == UInt8(ascii: "{") ? .object : .array
                    index += 1
                    nodes.append(Node(
                        kind: kind, key: pendingKey, indexInParent: pendingIndex,
                        range: start ..< start, parent: pendingParent, depth: pendingDepth,
                        childSpan: 0 ..< 0
                    ))
                    open.append((nodes.count - 1, 0))
                    skipSpace()
                    let close: UInt8 = kind == .object ? UInt8(ascii: "}") : UInt8(ascii: "]")
                    if peek() == close {
                        index += 1
                        try closeContainer()
                    } else if kind == .object {
                        (pendingKey, pendingIndex, pendingParent, pendingDepth) = try openMember()
                        continue
                    } else {
                        pendingKey = ""
                        pendingIndex = 0
                        pendingParent = open[open.count - 1].node
                        pendingDepth += 1
                        continue
                    }
                } else {
                    let kind = try scanScalar()
                    nodes.append(Node(
                        kind: kind, key: pendingKey, indexInParent: pendingIndex,
                        range: start ..< index, parent: pendingParent, depth: pendingDepth,
                        childSpan: 0 ..< 0
                    ))
                }

                // Giá trị vừa xong. Đi tiếp phần tử kế của container đang mở, hoặc đóng nó lại.
                guard let next = try advanceAfterValue() else { return }
                (pendingKey, pendingIndex, pendingParent, pendingDepth) = next
            }
        }

        /// Đọc khóa của mục đầu tiên trong một object vừa mở.
        private mutating func openMember() throws -> (String, Int, Int, Int) {
            let container = open[open.count - 1]
            let key = try readMemberKey()
            return (key, -1, container.node, nodes[container.node].depth + 1)
        }

        private mutating func readMemberKey() throws -> String {
            skipSpace()
            guard peek() == UInt8(ascii: "\"") else {
                throw issue("Khóa của object phải là chuỗi trong dấu nháy kép")
            }
            let raw = try scanStringRange()
            skipSpace()
            guard peek() == UInt8(ascii: ":") else { throw issue("Thiếu dấu hai chấm sau khóa") }
            index += 1
            return unescape(bytes[(raw.lowerBound + 1) ..< (raw.upperBound - 1)])
        }

        /// Sau một giá trị: dấu phẩy thì có mục kế, dấu đóng thì đóng container.
        ///
        /// Trả `nil` khi đã đóng hết — tức là tài liệu kết thúc.
        private mutating func advanceAfterValue() throws -> (String, Int, Int, Int)? {
            while true {
                guard let current = open.last else { return nil }
                open[open.count - 1].count += 1
                skipSpace()
                let isObject = nodes[current.node].kind == .object
                let close: UInt8 = isObject ? UInt8(ascii: "}") : UInt8(ascii: "]")

                switch peek() {
                case UInt8(ascii: ","):
                    index += 1
                    skipSpace()
                    if peek() == close {
                        throw issue("Dấu phẩy thừa trước dấu \(Character(UnicodeScalar(close)))")
                    }
                    let depth = nodes[current.node].depth + 1
                    if isObject {
                        return (try readMemberKey(), -1, current.node, depth)
                    }
                    return ("", open[open.count - 1].count, current.node, depth)
                case close:
                    index += 1
                    try closeContainer()
                    if open.isEmpty { return nil }
                    continue
                default:
                    throw issue(isObject
                        ? "Thiếu dấu phẩy giữa hai mục của object"
                        : "Thiếu dấu phẩy giữa hai phần tử của mảng")
                }
            }
        }

        /// Đóng container trên cùng và chốt khoảng byte của nó.
        private mutating func closeContainer() throws {
            guard let current = open.popLast() else { throw issue("Đóng nhầm") }
            let old = nodes[current.node]
            nodes[current.node] = Node(
                kind: old.kind, key: old.key, indexInParent: old.indexInParent,
                range: old.range.lowerBound ..< index, parent: old.parent, depth: old.depth,
                childSpan: 0 ..< 0
            )
        }

        private mutating func scanScalar() throws -> Kind {
            switch bytes[index] {
            case UInt8(ascii: "\""): _ = try scanStringRange(); return .string
            case UInt8(ascii: "t"): try expect("true"); return .bool
            case UInt8(ascii: "f"): try expect("false"); return .bool
            case UInt8(ascii: "n"): try expect("null"); return .null
            default: try scanNumber(); return .number
            }
        }

        private mutating func scanStringRange() throws -> Range<Int> {
            let start = index
            index += 1
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "\\") {
                    index += 2
                    continue
                }
                if byte == UInt8(ascii: "\"") {
                    index += 1
                    return start ..< index
                }
                if byte == 0x0A { throw issue("Chuỗi chưa đóng — xuống dòng giữa chừng") }
                index += 1
            }
            throw issue("Chuỗi chưa đóng, thiếu dấu nháy kép")
        }

        private mutating func scanNumber() throws {
            let start = index
            if peek() == UInt8(ascii: "-") { index += 1 }
            while let byte = peek(),
                  (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
                    || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "e")
                    || byte == UInt8(ascii: "E") || byte == UInt8(ascii: "+")
                    || byte == UInt8(ascii: "-") {
                index += 1
            }
            guard index > start else { throw issue("Không nhận ra giá trị này là gì") }
        }

        private mutating func expect(_ word: String) throws {
            for byte in word.utf8 {
                guard peek() == byte else { throw issue("Mong đợi `\(word)`") }
                index += 1
            }
        }

        private func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }

        private mutating func skipSpace() {
            while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        /// Bỏ escape của khóa. Chỉ khóa, vì chỉ khóa mới đem đi SO SÁNH với truy vấn.
        ///
        /// Giá trị thì giữ nguyên văn — người dùng muốn thấy đúng thứ họ viết trong file.
        private func unescape(_ slice: ArraySlice<UInt8>) -> String {
            guard slice.contains(UInt8(ascii: "\\")) else {
                return String(decoding: slice, as: UTF8.self)
            }
            var out: [UInt8] = []
            out.reserveCapacity(slice.count)
            var i = slice.startIndex
            while i < slice.endIndex {
                if slice[i] == UInt8(ascii: "\\"), i + 1 < slice.endIndex {
                    let next = slice[i + 1]
                    switch next {
                    case UInt8(ascii: "n"): out.append(0x0A)
                    case UInt8(ascii: "t"): out.append(0x09)
                    case UInt8(ascii: "r"): out.append(0x0D)
                    case UInt8(ascii: "b"): out.append(0x08)
                    case UInt8(ascii: "f"): out.append(0x0C)
                    case UInt8(ascii: "u"):
                        // `\uXXXX` để nguyên: giải nó đúng cách phải ghép cả cặp surrogate, và
                        // làm nửa vời thì khóa tiếng Việt escape sẽ so sánh sai một cách âm thầm.
                        out.append(UInt8(ascii: "\\"))
                        out.append(next)
                    default: out.append(next)
                    }
                    i += 2
                    continue
                }
                out.append(slice[i])
                i += 1
            }
            return String(decoding: out, as: UTF8.self)
        }

        private func issue(_ message: String) -> JSONIssue {
            var line = 1
            var column = 1
            for byte in bytes[0 ..< min(index, bytes.count)] {
                if byte == 0x0A { line += 1; column = 1 } else { column += 1 }
            }
            return JSONIssue(message: message, offset: index, line: line, column: column)
        }
    }
}
