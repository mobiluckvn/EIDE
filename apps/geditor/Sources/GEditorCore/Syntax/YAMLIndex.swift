import Foundation

/// Cây YAML dạng MẢNG PHẲNG, mỗi nút biết mình nằm ở khoảng byte nào của văn bản gốc.
///
/// ## Vì sao không dùng `YAMLReader` có sẵn
///
/// `YAMLReader` sinh ra để **lấy giá trị** cho lệnh nhập/xuất dữ liệu, nên nó vứt đi đúng thứ
/// khung nhìn cần và từ chối đúng thứ khung nhìn phải chịu được:
///
/// 1. **Nó không giữ vị trí.** `YAMLValue` là giá trị thuần, không có khoảng byte nào. Không có
///    khoảng byte thì bấm một nút không nhảy về nguồn được, và View thôi là "cách nhìn khác của
///    cùng một thứ" — nó thành một bản in đẹp.
/// 2. **Nó ném lỗi với `---` và với anchor/alias.** Với lệnh nhập dữ liệu thì từ chối là đúng:
///    thà không nhập còn hơn nhập nhầm. Với khung nhìn thì ngược lại — mở một tệp Kubernetes
///    nhiều tài liệu ra mà báo lỗi thì người dùng không xem được gì cả.
/// 3. **Nó gọi đệ quy** (`parseBlock` → `inlineOrBlock` → `parseBlock`). Cùng cái bẫy đã ghi ở
///    `JSONIndex` và `XMLIndex`: tệp lồng sâu làm tràn ngăn xếp, app tắt không một lời.
///
/// ## YAML cấu trúc bằng THỤT LỀ, nên đơn vị quét là DÒNG
///
/// Khác JSON và XML — hai thứ cấu trúc bằng dấu phân cách nên quét được theo byte trôi chảy —
/// YAML lấy cột làm ranh giới khối. Nên bộ dựng này đi theo dòng, và với mỗi dòng chỉ hỏi ba
/// câu: thụt bao nhiêu, đây là phần tử dãy hay cặp khoá, và nó thuộc khối nào đang mở. Ngăn xếp
/// khối là TƯỜNG MINH, không đệ quy.
///
/// Byte vẫn là đơn vị của vị trí: mọi dấu phân cách của YAML — khoảng trắng, `-`, `:`, `#`,
/// nháy — đều là ASCII, mà byte tiếp nối UTF-8 luôn ≥ 0x80, nên khoá `máy_chủ:` đi qua nguyên vẹn.
///
/// ## Ba chỗ cố tình làm nông, và vì sao
///
/// - **Tập hợp dạng dòng** (`cổng: [80, 443]`) là MỘT lá, giá trị hiện nguyên văn. Nội dung đã
///   nằm gọn trên một dòng rồi; bung nó ra thành ba nút con bắt người dùng bấm thêm một cái để
///   thấy thứ họ đang thấy sẵn.
/// - **Anchor và alias** (`&mac`, `*mac`) đi vào giá trị nguyên văn, KHÔNG giải chiếu. Cây soi
///   NGUỒN; một alias đã giải thì nội dung nó trỏ tới nằm ở chỗ khác trong tệp, và nút ấy sẽ
///   mang một khoảng byte nói dối.
/// - **Nhãn kiểu YAML** (`!!str`, `!Ref`) nằm lại trong giá trị. Ở đây không có lược đồ nào để
///   diễn giải chúng.
///
/// ## Chỉ đọc. Không hàm nào ở đây sinh ra sửa đổi.
public struct YAMLIndex {

    /// Trần kích thước — cùng trần và cùng lý do với `JSONIndex` và `XMLIndex`.
    public static let sizeLimit = DocumentOutline.sizeLimit

    public enum Kind: UInt8, Sendable {
        /// Khối khoá–giá trị.
        case mapping
        /// Khối dãy.
        case sequence
        /// Lá.
        case scalar

        public var isContainer: Bool { self != .scalar }
    }

    public struct Node: Sendable {
        public internal(set) var kind: Kind
        /// Khoá, `[3]` với phần tử dãy, hoặc `$` với gốc tài liệu.
        public let name: String
        /// Giá trị vô hướng đã bỏ nháy. Rỗng với nút chứa.
        public internal(set) var value: String
        /// Giá trị gốc có nháy không — để phân biệt `"42"` (chữ) với `42` (số).
        public internal(set) var quoted: Bool
        /// Khoảng BYTE trong nguồn, tính từ đầu KHOÁ tới hết khối thuộc về nó.
        ///
        /// Cố ý khác `JSONIndex` — ở đó khoảng bao GIÁ TRỊ. Trong YAML khối con nằm ở những dòng
        /// **dưới** khoá, nên nhảy tới giá trị là nhảy xuống giữa khối; nhảy tới khoá đặt con
        /// nháy đúng dòng người ta muốn sửa.
        public internal(set) var range: Range<Int>
        /// Chỉ số nút cha; `-1` cho gốc.
        public let parent: Int
        public let depth: Int
        public internal(set) var childSpan: Range<Int>
    }

    public private(set) var nodes: [Node] = []
    public private(set) var children: [Int] = []
    public private(set) var failure: YAMLReader.Failure?
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
        } catch let failure as YAMLReader.Failure {
            // Lỗi cú pháp thì KHÔNG giữ phần đã dựng — cùng luật với `JSONIndex` và `XMLIndex`:
            // một cây cụt trông y như một tài liệu chỉ có ngần ấy nội dung.
            self.failure = failure
            return
        } catch {
            failure = YAMLReader.Failure(line: 1, reason: "\(error)")
            return
        }
        nodes = builder.nodes
        children = builder.flatChildren
    }
}

// MARK: - Bộ dựng

extension YAMLIndex {

    /// Một khối đang mở: dãy hay ánh xạ, và các mục của nó thụt vào bao nhiêu.
    fileprivate struct Frame {
        let node: Int
        let entryIndent: Int
        let isSequence: Bool
    }

    /// Duyệt theo DÒNG bằng ngăn xếp TƯỜNG MINH — xem ghi chú ở đầu tệp.
    fileprivate struct Builder {
        let bytes: [UInt8]
        var nodes: [Node] = []
        var kids: [[Int]] = []
        var flatChildren: [Int] = []
        var frames: [Frame] = []
        /// Cặp khoá vừa đọc mà chưa có giá trị — khối con ở các dòng dưới sẽ treo vào đây.
        var pendingParent = -1
        /// Khối chữ `|` / `>` đang mở: nút giữ nó, và cột của KHOÁ mở ra nó.
        var blockScalar: (node: Int, keyIndent: Int)?
        var documentRoot = -1
        var documentCount = 0
        var lineNumber = 0

        init(bytes: [UInt8]) { self.bytes = bytes }

        // MARK: Vòng ngoài

        mutating func run() throws {
            var index = 0
            while index < bytes.count {
                let lineStart = index
                var lineEnd = index
                while lineEnd < bytes.count, bytes[lineEnd] != UInt8(ascii: "\n") { lineEnd += 1 }
                index = lineEnd < bytes.count ? lineEnd + 1 : lineEnd
                lineNumber += 1
                try consume(lineStart: lineStart, lineEnd: lineEnd)
            }
            blockScalar = nil
            guard documentCount > 0 else {
                throw YAMLReader.Failure(line: 1, reason: "tệp rỗng — không có nội dung YAML nào")
            }
            closeAll(to: bytes.count)
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

        // MARK: Một dòng

        private mutating func consume(lineStart: Int, lineEnd: Int) throws {
            var cursor = lineStart
            while cursor < lineEnd, bytes[cursor] == UInt8(ascii: " ") { cursor += 1 }
            let indent = cursor - lineStart
            let isBlank = cursor >= lineEnd

            // Bên trong khối chữ `|` mọi thứ là NỘI DUNG: dấu `#` không phải chú thích, Tab
            // không phải lỗi thụt lề, và một dòng không có dấu `:` là chuyện bình thường. Nếu
            // không tách nhánh này ra trước, tệp workflow GitHub Actions nào cũng báo lỗi ở dòng
            // đầu tiên của một `run: |`.
            if let block = blockScalar {
                if isBlank || indent > block.keyIndent {
                    absorb(into: block.node, from: cursor, to: lineEnd)
                    return
                }
                blockScalar = nil
            }

            // Tab trong phần thụt lề là lỗi YAML kinh điển: trình soạn thảo vẽ nó rộng bằng bốn
            // dấu cách nên mắt thấy thẳng hàng, còn bộ đọc thì không. Nói thẳng ra, đừng để
            // người dùng đi soi một khối "trông đúng mà máy bảo sai".
            if cursor < lineEnd, bytes[cursor] == UInt8(ascii: "\t") {
                throw YAMLReader.Failure(
                    line: lineNumber,
                    reason: "thụt lề bằng Tab — YAML chỉ nhận dấu cách")
            }

            guard !isBlank else { return }                              // dòng trắng
            if bytes[cursor] == UInt8(ascii: "#") { return }            // dòng chú thích

            let text = slice(cursor, lineEnd)
            if indent == 0, text == "---" || text.hasPrefix("--- ") {
                closeAll(to: lineStart)
                openDocument(at: lineStart)
                let rest = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                guard !rest.isEmpty else { return }
                try place(indent: 0, start: cursor + 4, end: lineEnd, lineStart: lineStart)
                return
            }
            if indent == 0, text == "..." { closeAll(to: lineEnd); return }

            if documentRoot < 0 { openDocument(at: lineStart) }
            try place(indent: indent, start: cursor, end: lineEnd, lineStart: lineStart)
        }

        /// Đặt một mục vào đúng khối. `start` trỏ tới ký tự đầu tiên KHÔNG phải khoảng trắng.
        private mutating func place(
            indent: Int, start: Int, end: Int, lineStart: Int
        ) throws {
            var indent = indent
            var start = start
            // Vòng lặp thay cho đệ quy: `- - khoá: v` mở hai khối trên cùng một dòng.
            while true {
                let isSequenceEntry = bytes[start] == UInt8(ascii: "-")
                    && (start + 1 == end || bytes[start + 1] == UInt8(ascii: " "))

                closeDeeper(than: indent, isSequenceEntry: isSequenceEntry, to: lineStart)

                if isSequenceEntry {
                    let frame = try sequenceFrame(indent: indent, at: start)
                    var restStart = start + 1
                    while restStart < end, bytes[restStart] == UInt8(ascii: " ") { restStart += 1 }
                    let label = "[\(kids[frame].count)]"
                    let item = add(kind: .scalar, name: label, start: start, parent: frame)
                    let rest = trimmedComment(from: restStart, to: end)
                    if withoutProperties(rest).isEmpty {
                        // `-` trơ trọi (hoặc chỉ mang anchor): khối con nằm ở các dòng dưới.
                        pendingParent = item
                        return
                    }
                    // Phần còn lại của dòng có thể lại là một mục — `- khoá: v`, `- - x`. Nó
                    // thụt vào đúng bằng CỘT của nó, đó là điều khiến vòng lặp này chạy đúng.
                    // Nhưng `- 80` thì KHÔNG: `80` không phải mục nào cả, nó là giá trị của mục
                    // vừa tạo. Quay lại vòng lặp với nó là đi đòi một dấu `:` không tồn tại.
                    let nested = bytes[restStart] == UInt8(ascii: "-")
                        && (restStart + 1 == end || bytes[restStart + 1] == UInt8(ascii: " "))
                    guard nested || readKey(start: restStart, end: end) != nil else {
                        if isBlockMarker(withoutProperties(rest)) {
                            nodes[item].range = nodes[item].range.lowerBound ..< end
                            blockScalar = (item, indent)
                            pendingParent = -1
                            return
                        }
                        setScalar(item, raw: rest, valueEnd: valueEnd(from: restStart, to: end))
                        pendingParent = -1
                        return
                    }
                    pendingParent = item
                    indent = restStart - lineStart
                    start = restStart
                    continue
                }

                guard let key = readKey(start: start, end: end) else {
                    throw YAMLReader.Failure(
                        line: lineNumber,
                        reason: "dòng không phải khoá cũng không phải mục dãy — thiếu dấu `:`?")
                }
                let frame = try mappingFrame(indent: indent, at: start)
                let node = add(kind: .scalar, name: key.name, start: start, parent: frame)
                var valueStart = key.valueStart
                while valueStart < end, bytes[valueStart] == UInt8(ascii: " ") { valueStart += 1 }
                let raw = trimmedComment(from: valueStart, to: end)
                if isBlockMarker(withoutProperties(raw)) {
                    nodes[node].value = ""
                    nodes[node].range = nodes[node].range.lowerBound ..< end
                    blockScalar = (node, indent)
                    pendingParent = -1
                    return
                }
                if withoutProperties(raw).isEmpty {
                    pendingParent = node          // khối con ở các dòng dưới
                } else {
                    setScalar(node, raw: raw, valueEnd: valueEnd(from: valueStart, to: end))
                    pendingParent = -1
                }
                return
            }
        }

        // MARK: Khối

        private mutating func openDocument(at start: Int) {
            documentCount += 1
            // Một tài liệu thì gốc là `$`, đúng ký hiệu JSONPath người dùng đã gặp ở panel truy
            // vấn. Nhiều tài liệu thì phải đánh số, nếu không ba gốc `$` cạnh nhau không phân
            // biệt được cái nào là cái nào.
            let name = documentCount == 1 ? "$" : "$\(documentCount)"
            documentRoot = add(kind: .mapping, name: name, start: start, parent: -1)
            frames = []
            pendingParent = documentRoot
        }

        /// Đóng mọi khối thụt sâu hơn `indent`.
        ///
        /// Một mục dãy được phép nằm NGANG với khoá của nó — `cổng:` rồi `- 80` cùng cột 0 là
        /// YAML hợp lệ và rất phổ biến. Nên khi dòng này là mục dãy, khối dãy ngang cột được giữ.
        private mutating func closeDeeper(than indent: Int, isSequenceEntry: Bool, to end: Int) {
            while let top = frames.last {
                if top.entryIndent > indent {
                    close(top, to: end)
                } else if top.entryIndent == indent, top.isSequence != isSequenceEntry {
                    // Dãy NGANG cột với khoá của nó: `cổng:` rồi `- 80` cùng cột 0. Khối ánh xạ
                    // ở cột ấy KHÔNG được đóng — nếu đóng, khối dãy mở ra sẽ treo vào nút gốc và
                    // khoá `cổng` mất sạch con. Điều kiện nhận ra nó: khoá vừa đọc còn đang chờ
                    // giá trị.
                    if !top.isSequence, isSequenceEntry, pendingParent >= 0 { break }
                    close(top, to: end)
                } else {
                    break
                }
            }
            if frames.isEmpty { pendingParent = documentRoot }
        }

        private mutating func close(_ frame: Frame, to end: Int) {
            frames.removeLast()
            nodes[frame.node].range = nodes[frame.node].range.lowerBound ..< end
            pendingParent = -1
        }

        private mutating func closeAll(to end: Int) {
            while let top = frames.last { close(top, to: end) }
            if documentRoot >= 0 {
                nodes[documentRoot].range = nodes[documentRoot].range.lowerBound ..< end
            }
            documentRoot = -1
            pendingParent = -1
        }

        private mutating func sequenceFrame(indent: Int, at start: Int) throws -> Int {
            if let top = frames.last, top.entryIndent == indent, top.isSequence { return top.node }
            return try openFrame(indent: indent, isSequence: true, at: start)
        }

        private mutating func mappingFrame(indent: Int, at start: Int) throws -> Int {
            if let top = frames.last, top.entryIndent == indent, !top.isSequence { return top.node }
            return try openFrame(indent: indent, isSequence: false, at: start)
        }

        private mutating func openFrame(
            indent: Int, isSequence: Bool, at start: Int
        ) throws -> Int {
            // Thụt vào mà không có khoá nào đang chờ nghĩa là dòng này lơ lửng: nó sâu hơn khối
            // trên nó nhưng không thuộc về ai. Đây chính là chỗ tệp YAML sửa tay hay hỏng.
            guard pendingParent >= 0 else {
                throw YAMLReader.Failure(
                    line: lineNumber, reason: "thụt lề không khớp khối phía trên")
            }
            let parent = pendingParent
            // Một khối chỉ có MỘT hình dạng. Trộn `a: 1` với `- x` ở cùng cột là YAML hỏng, và
            // nếu không bắt thì nút cha đổi kiểu giữa chừng — con thêm sau còn đó, con thêm
            // trước thì vẫn treo ở đấy nhưng cây hiện sai loại.
            guard kids[parent].isEmpty else {
                throw YAMLReader.Failure(
                    line: lineNumber,
                    reason: "khối vừa có khoá vừa có mục dãy ở cùng cột")
            }
            nodes[parent].kind = isSequence ? .sequence : .mapping
            frames.append(Frame(node: parent, entryIndent: indent, isSequence: isSequence))
            pendingParent = -1
            return parent
        }

        // MARK: Nút

        private mutating func add(kind: Kind, name: String, start: Int, parent: Int) -> Int {
            let index = nodes.count
            let depth = parent < 0 ? 0 : nodes[parent].depth + 1
            nodes.append(Node(
                kind: kind, name: name, value: "", quoted: false,
                range: start ..< start, parent: parent, depth: depth, childSpan: 0 ..< 0))
            kids.append([])
            if parent >= 0 { kids[parent].append(index) }
            return index
        }

        /// Ghi giá trị vô hướng, và cho khoảng byte chạy từ đầu KHOÁ tới hết giá trị.
        ///
        /// Không tính khoảng bằng độ dài của `raw`: `raw` là phần GIÁ TRỊ, còn khoảng bắt đầu ở
        /// KHOÁ. Cộng độ dài này vào đầu kia cho ra một khoảng cắt giữa khoá — và với khoá tiếng
        /// Việt thì cắt luôn giữa một ký tự nhiều byte.
        private mutating func setScalar(_ node: Int, raw: String, valueEnd: Int) {
            let (value, quoted) = unquote(withoutProperties(raw))
            nodes[node].value = value
            nodes[node].quoted = quoted
            nodes[node].range = nodes[node].range.lowerBound ..< valueEnd
        }

        // MARK: Cắt chữ

        private func slice(_ start: Int, _ end: Int) -> String {
            String(decoding: bytes[start ..< end], as: UTF8.self)
                .trimmingCharacters(in: .whitespaces)
        }

        /// Đọc `khoá:` ở đầu dòng. Trả `nil` nếu không có dấu `:` ngoài nháy.
        private func readKey(start: Int, end: Int) -> (name: String, valueStart: Int)? {
            var index = start
            var quote: UInt8 = 0
            while index < end {
                let byte = bytes[index]
                if quote != 0 {
                    if byte == quote { quote = 0 }
                } else if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                    quote = byte
                } else if byte == UInt8(ascii: ":") {
                    // `:` chỉ kết thúc khoá khi sau nó là khoảng trắng hoặc hết dòng — nếu không
                    // thì `http://máy-chủ` bị cắt làm đôi và cây mọc ra một khoá `http`.
                    let next = index + 1
                    if next >= end || bytes[next] == UInt8(ascii: " ") {
                        let (name, _) = unquote(slice(start, index))
                        return name.isEmpty ? nil : (name, next)
                    }
                } else if byte == UInt8(ascii: "#"), index > start,
                          bytes[index - 1] == UInt8(ascii: " ") {
                    return nil                     // chú thích trước khi gặp `:`
                }
                index += 1
            }
            return nil
        }

        /// Đây có phải dấu mở khối chữ không: `|`, `>`, kèm các biến thể `|-` `>+` `|2`.
        private func isBlockMarker(_ text: String) -> Bool {
            guard let first = text.first, first == "|" || first == ">" else { return false }
            return text.dropFirst().allSatisfy { $0 == "-" || $0 == "+" || $0.isNumber }
        }

        /// Nuốt một dòng nội dung của khối chữ: nới khoảng byte, và gom chữ để hiện cạnh nhãn.
        ///
        /// Chỉ gom tới một trần rồi thôi. Một `run: |` dài trăm dòng mà đổ hết vào ô chi tiết thì
        /// hàng ấy nuốt cả khung nhìn — mà chi tiết chỉ để trả lời "có đáng mở ra không".
        private mutating func absorb(into node: Int, from start: Int, to end: Int) {
            nodes[node].range = nodes[node].range.lowerBound ..< end
            guard nodes[node].value.count < 120, start < end else { return }
            let piece = slice(start, end)
            guard !piece.isEmpty else { return }
            nodes[node].value += nodes[node].value.isEmpty ? piece : " " + piece
        }

        /// Chỗ giá trị kết thúc: hết dòng, hoặc ngay trước phần chú thích ` #…`.
        private func valueEnd(from start: Int, to end: Int) -> Int {
            start + Array(trimmedComment(from: start, to: end).utf8).count
        }

        /// Bỏ phần chú thích ` #…` ở cuối giá trị, tôn trọng nháy.
        private func trimmedComment(from start: Int, to end: Int) -> String {
            var index = start
            var quote: UInt8 = 0
            while index < end {
                let byte = bytes[index]
                if quote != 0 {
                    if byte == quote { quote = 0 }
                } else if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                    quote = byte
                } else if byte == UInt8(ascii: "#"), index > start,
                          bytes[index - 1] == UInt8(ascii: " ") {
                    return slice(start, index - 1)
                }
                index += 1
            }
            return slice(start, end)
        }

        /// Bỏ phần **thuộc tính** ở đầu giá trị: anchor `&tên` và nhãn kiểu `!kiểu` / `!!kiểu`.
        ///
        /// Chúng khai báo về nút chứ không phải nội dung của nút. `gốc: &mac` là một khối có tên,
        /// khối thật nằm ở các dòng dưới — coi `&mac` là giá trị thì những dòng ấy thành lơ lửng
        /// và cả tệp báo lỗi. Alias `*mac` thì ngược lại: nó LÀ giá trị, nên không bị bỏ.
        private func withoutProperties(_ text: String) -> String {
            var rest = Substring(text)
            while let first = rest.first, first == "&" || first == "!" {
                guard let space = rest.firstIndex(of: " ") else { return "" }
                rest = rest[space...].drop(while: { $0 == " " })
            }
            return String(rest)
        }

        private func unquote(_ text: String) -> (String, Bool) {
            guard text.count >= 2, let first = text.first, let last = text.last, first == last,
                  first == "\"" || first == "'"
            else { return (text, false) }
            return (String(text.dropFirst().dropLast()), true)
        }
    }
}
