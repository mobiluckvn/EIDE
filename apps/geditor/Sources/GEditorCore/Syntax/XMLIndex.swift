import Foundation

/// Cây XML dạng MẢNG PHẲNG, mỗi nút biết mình nằm ở khoảng byte nào của văn bản gốc.
///
/// ## Vì sao không dùng `XMLTool.Scanner` có sẵn
///
/// Cùng lý do `JSONIndex` không dùng `JSONTool.Parser`, và lý do ấy còn đúng hơn ở đây.
/// `XMLTool.Scanner` dựng cây để **viết lại** — định dạng, thu gọn — nên nó giữ nguyên văn từng
/// đoạn và không cần biết chúng nằm ở đâu. Nó cũng có hai tính chất khiến nó không dùng được cho
/// chế độ View:
///
/// 1. **Nó ĐỆ QUY.** `readElement` gọi lại chính nó cho từng nút con. Một tệp XML lồng vài nghìn
///    tầng — bản kết xuất của máy thì chuyện thường — làm tràn ngăn xếp và app tắt ngóm, không
///    có thông báo nào.
/// 2. **Nó đánh chỉ số theo KÝ TỰ**, còn khung nhìn cần khoảng BYTE để nhảy vào buffer. Quy đổi
///    ký tự sang byte là một vòng quét nữa trên cả tài liệu, và mỗi phép quy đổi là một chỗ để
///    lệch một đơn vị.
///
/// ## Quét trên BYTE, và vì sao thế là an toàn với chữ tiếng Việt
///
/// Mọi dấu phân cách của XML — `<` `>` `/` `=` `"` `'` và khoảng trắng — đều là ASCII, và trong
/// UTF-8 thì **byte tiếp nối luôn ≥ 0x80**, không bao giờ trùng một byte ASCII. Nên quét byte thô
/// không thể cắt nhầm giữa một ký tự nhiều byte: tên thẻ `<khách_hàng>` đi qua nguyên vẹn mà bộ
/// quét không cần biết gì về Unicode.
///
/// ## Chỉ đọc. Không hàm nào ở đây sinh ra sửa đổi.
public struct XMLIndex {

    /// Trần kích thước — cùng trần và cùng lý do với `JSONIndex`.
    public static let sizeLimit = DocumentOutline.sizeLimit

    public enum Kind: UInt8, Sendable {
        case element, attribute, text

        public var isContainer: Bool { self == .element }
    }

    public struct Node: Sendable {
        public let kind: Kind
        /// Tên thẻ, tên thuộc tính, hoặc rỗng với nút chữ.
        public let name: String
        /// Giá trị thuộc tính (đã bỏ dấu nháy) hoặc nội dung chữ. Rỗng với thẻ.
        public let value: String
        /// Khoảng BYTE trong văn bản gốc. Với thẻ, nó bao TRỌN phần tử — từ `<` của thẻ mở tới
        /// `>` của thẻ đóng.
        public let range: Range<Int>
        /// Chỉ số nút cha; `-1` cho gốc.
        public let parent: Int
        public let depth: Int
        public internal(set) var childSpan: Range<Int>
    }

    public private(set) var nodes: [Node] = []
    public private(set) var children: [Int] = []
    public private(set) var failure: XMLIssue?
    public private(set) var tooLarge = false

    public var isEmpty: Bool { nodes.isEmpty }

    public func childIndices(of node: Int) -> ArraySlice<Int> {
        children[nodes[node].childSpan]
    }

    public init(text: String) { self.init(bytes: Array(text.utf8)) }

    public init(bytes: [UInt8]) {
        guard bytes.count <= Self.sizeLimit else {
            tooLarge = true
            return
        }
        var builder = Builder(bytes: bytes)
        do {
            try builder.run()
        } catch let issue as XMLIssue {
            // Lỗi cú pháp thì KHÔNG giữ phần đã dựng: một cây cụt trông như tài liệu chỉ có ngần
            // ấy nội dung. Cùng luật với `JSONIndex`.
            failure = issue
            return
        } catch {
            failure = XMLIssue(message: "\(error)", offset: 0, line: 1, column: 1)
            return
        }
        nodes = builder.nodes
        children = builder.flatChildren
    }
}

// MARK: - Bộ dựng

extension XMLIndex {

    /// Duyệt bằng ngăn xếp TƯỜNG MINH, không đệ quy — xem ghi chú ở đầu tệp.
    fileprivate struct Builder {
        let bytes: [UInt8]
        var index = 0
        var nodes: [Node] = []
        /// Con của từng nút, gom riêng rồi mới trải phẳng ở cuối.
        var kids: [[Int]] = []
        var flatChildren: [Int] = []
        var stack: [Int] = []
        var roots = 0

        init(bytes: [UInt8]) { self.bytes = bytes }

        mutating func run() throws {
            while index < bytes.count {
                if bytes[index] == UInt8(ascii: "<") {
                    try readMarkup()
                } else {
                    readText()
                }
            }
            if let open = stack.last {
                throw issue("Thẻ `<\(nodes[open].name)>` chưa được đóng", at: nodes[open].range.lowerBound)
            }
            guard roots > 0 else {
                throw issue("Không có thẻ nào — tệp rỗng hoặc không phải XML", at: 0)
            }
            flatten()
        }

        /// Trải `kids` thành một mảng liên tục và ghi lại khoảng của từng nút.
        private mutating func flatten() {
            for position in nodes.indices {
                let start = flatChildren.count
                flatChildren.append(contentsOf: kids[position])
                nodes[position].childSpan = start ..< flatChildren.count
            }
        }

        // MARK: Đọc

        private mutating func readMarkup() throws {
            if matches("<!--") { try skip(past: "-->", what: "chú thích"); return }
            if matches("<![CDATA[") {
                let start = index + 9
                try skip(past: "]]>", what: "khối CDATA")
                addText(from: start, to: index - 3)
                return
            }
            if matches("<?") { try skip(past: "?>", what: "chỉ thị xử lý"); return }
            if matches("<!") { try skipDoctype(); return }
            if matches("</") { try readCloseTag(); return }
            try readOpenTag()
        }

        private mutating func readOpenTag() throws {
            let start = index
            index += 1                                   // '<'
            let name = try readName(what: "tên thẻ")
            let node = add(kind: .element, name: name, value: "",
                           range: start ..< bytes.count, parent: stack.last ?? -1)
            if stack.isEmpty { roots += 1 }

            try readAttributes(into: node)
            skipSpace()
            if matches("/>") {
                index += 2
                nodes[node].setRange(start ..< index)
                return
            }
            guard index < bytes.count, bytes[index] == UInt8(ascii: ">") else {
                throw issue("Thẻ `<\(name)` thiếu dấu `>`", at: start)
            }
            index += 1
            stack.append(node)
        }

        private mutating func readCloseTag() throws {
            let start = index
            index += 2                                   // '</'
            let name = try readName(what: "tên thẻ đóng")
            skipSpace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ">") else {
                throw issue("Thẻ đóng `</\(name)` thiếu dấu `>`", at: start)
            }
            index += 1
            guard let open = stack.popLast() else {
                throw issue("Thẻ đóng `</\(name)>` không có thẻ mở nào đang chờ", at: start)
            }
            guard nodes[open].name == name else {
                // Nói ra CẢ HAI tên. "Thẻ không khớp" một mình bắt người dùng tự đi tìm cái kia.
                throw issue(
                    "Thẻ đóng `</\(name)>` không khớp thẻ mở `<\(nodes[open].name)>`", at: start)
            }
            nodes[open].setRange(nodes[open].range.lowerBound ..< index)
        }

        /// Bỏ qua DOCTYPE, kể cả phần khai nội bộ trong `[...]`.
        private mutating func skipDoctype() throws {
            let start = index
            var depth = 0
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "[") { depth += 1 }
                if byte == UInt8(ascii: "]") { depth -= 1 }
                if byte == UInt8(ascii: ">"), depth <= 0 {
                    index += 1
                    return
                }
                index += 1
            }
            throw issue("Khai báo `<!…` chưa được đóng", at: start)
        }

        private mutating func readAttributes(into element: Int) throws {
            while true {
                skipSpace()
                guard index < bytes.count else {
                    throw issue("Thẻ chưa được đóng", at: nodes[element].range.lowerBound)
                }
                let byte = bytes[index]
                if byte == UInt8(ascii: ">") || byte == UInt8(ascii: "/") { return }

                let start = index
                let name = try readName(what: "tên thuộc tính")
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: "=") else {
                    // Thuộc tính không giá trị (kiểu HTML) — nhận, nhưng giá trị rỗng.
                    add(kind: .attribute, name: name, value: "",
                        range: start ..< index, parent: element)
                    continue
                }
                index += 1
                skipSpace()
                let value = try readQuoted(attribute: name, from: start)
                add(kind: .attribute, name: name, value: value,
                    range: start ..< index, parent: element)
            }
        }

        private mutating func readQuoted(attribute: String, from start: Int) throws -> String {
            guard index < bytes.count else {
                throw issue("Thuộc tính `\(attribute)` thiếu giá trị", at: start)
            }
            let quote = bytes[index]
            guard quote == UInt8(ascii: "\"") || quote == UInt8(ascii: "'") else {
                throw issue("Giá trị của `\(attribute)` phải nằm trong dấu nháy", at: index)
            }
            index += 1
            let valueStart = index
            while index < bytes.count, bytes[index] != quote { index += 1 }
            guard index < bytes.count else {
                throw issue("Thuộc tính `\(attribute)` thiếu dấu nháy đóng", at: start)
            }
            let value = String(decoding: bytes[valueStart ..< index], as: UTF8.self)
            index += 1
            return value
        }

        private mutating func readText() {
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: "<") { index += 1 }
            addText(from: start, to: index)
        }

        /// Thêm một nút chữ, BỎ QUA phần chỉ có khoảng trắng.
        ///
        /// Khoảng trắng giữa hai thẻ là thứ định dạng, không phải nội dung. Đưa nó thành nút thì
        /// một tài liệu xuống dòng đẹp sẽ có số nút chữ nhiều gấp đôi số thẻ, và cây thành vô dụng.
        private mutating func addText(from start: Int, to end: Int) {
            guard start < end, start < bytes.count else { return }
            let slice = bytes[start ..< min(end, bytes.count)]
            guard slice.contains(where: { !isSpace($0) }) else { return }
            let text = String(decoding: slice, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            add(kind: .text, name: "", value: text, range: start ..< end, parent: stack.last ?? -1)
        }

        // MARK: Tiện ích

        @discardableResult
        private mutating func add(
            kind: Kind, name: String, value: String, range: Range<Int>, parent: Int
        ) -> Int {
            let position = nodes.count
            nodes.append(Node(kind: kind, name: name, value: value, range: range,
                              parent: parent, depth: stack.count, childSpan: 0 ..< 0))
            kids.append([])
            if parent >= 0 { kids[parent].append(position) }
            return position
        }

        private mutating func readName(what: String) throws -> String {
            let start = index
            while index < bytes.count, isNameByte(bytes[index]) { index += 1 }
            guard index > start else { throw issue("Thiếu \(what)", at: start) }
            return String(decoding: bytes[start ..< index], as: UTF8.self)
        }

        /// Byte hợp lệ trong một tên XML.
        ///
        /// Mọi byte ≥ 0x80 đều nhận: chúng là phần của một ký tự UTF-8, và tên thẻ tiếng Việt —
        /// `<khách_hàng>` — phải đi qua nguyên vẹn.
        private func isNameByte(_ byte: UInt8) -> Bool {
            if byte >= 0x80 { return true }
            switch byte {
            case UInt8(ascii: "a") ... UInt8(ascii: "z"),
                 UInt8(ascii: "A") ... UInt8(ascii: "Z"),
                 UInt8(ascii: "0") ... UInt8(ascii: "9"):
                return true
            case UInt8(ascii: ":"), UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "."):
                return true
            default:
                return false
            }
        }

        private func isSpace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        private mutating func skipSpace() {
            while index < bytes.count, isSpace(bytes[index]) { index += 1 }
        }

        private func matches(_ text: String) -> Bool {
            let needle = Array(text.utf8)
            guard index + needle.count <= bytes.count else { return false }
            return Array(bytes[index ..< index + needle.count]) == needle
        }

        private mutating func skip(past text: String, what: String) throws {
            let start = index
            let needle = Array(text.utf8)
            while index + needle.count <= bytes.count {
                if Array(bytes[index ..< index + needle.count]) == needle {
                    index += needle.count
                    return
                }
                index += 1
            }
            index = bytes.count
            throw issue("\(what.prefix(1).uppercased() + what.dropFirst()) chưa được đóng", at: start)
        }

        private func issue(_ message: String, at offset: Int) -> XMLIssue {
            var line = 1, column = 1
            for position in 0 ..< min(offset, bytes.count) {
                if bytes[position] == 0x0A { line += 1; column = 1 } else { column += 1 }
            }
            return XMLIssue(message: message, offset: offset, line: line, column: column)
        }
    }
}

extension XMLIndex.Node {
    fileprivate mutating func setRange(_ range: Range<Int>) {
        self = XMLIndex.Node(kind: kind, name: name, value: value, range: range,
                             parent: parent, depth: depth, childSpan: childSpan)
    }
}
