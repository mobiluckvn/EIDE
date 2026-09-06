import Foundation

/// Cây cấu trúc của một tài liệu — nền cho chế độ **View** của JSON, XML và YAML.
///
/// ## Vì sao một mô hình chung cho ba định dạng
///
/// Ba định dạng ấy khác nhau ở cú pháp nhưng giống nhau ở thứ người đọc cần: **khoá, giá trị,
/// và cái gì lồng trong cái gì**. Dựng ba khung nhìn riêng là chép lại ba lần cùng một
/// `NSOutlineView`, ba lần cùng phép gấp/mở, ba lần cùng đường nhảy về nguồn — rồi ba lần ấy
/// trôi khỏi nhau.
///
/// ## Mảng PHẲNG, không phải cây con trỏ
///
/// Giữ nguyên lối `JSONIndex` đã chọn và vì cùng lý do: một tài liệu lồng vài nghìn tầng — sinh
/// ra bằng máy thì chuyện thường — làm tràn ngăn xếp nếu duyệt bằng đệ quy, và app tắt ngóm mà
/// không có thông báo nào. Ở đây tầng lồng chỉ là một con số.
///
/// ## Mỗi nút phải biết mình nằm ở đâu trong NGUỒN
///
/// Đây là điều kiện để View và Code là hai cách nhìn CÙNG MỘT thứ chứ không phải hai bản sao:
/// bấm một nút trong cây thì con nháy nhảy tới đúng chỗ ấy trong văn bản. Không có khoảng byte
/// thì cây chỉ là một bản in đẹp, và người dùng phải tự đi tìm.
///
/// Định dạng nào không cho biết khoảng byte thì nút mang khoảng RỖNG, và khung nhìn **không**
/// cho bấm nhảy — thà không có đường nhảy còn hơn có một đường nhảy tới chỗ sai.
public struct StructureTree: Sendable {

    public enum Kind: String, Sendable {
        case object, array, string, number, bool, null
        /// Thẻ XML.
        case element
        /// Thuộc tính của thẻ XML.
        case attribute
        /// Chữ nằm trong thẻ.
        case text

        public var isContainer: Bool {
            self == .object || self == .array || self == .element
        }
    }

    public struct Node: Sendable {
        /// Khoá, tên thẻ, hoặc `[3]` với phần tử mảng.
        public let label: String
        /// Giá trị rút gọn để hiện cạnh nhãn. Rỗng với nút chứa.
        public let detail: String
        public let kind: Kind
        /// Khoảng byte trong nguồn. Rỗng nghĩa là không biết — xem ghi chú ở đầu tệp.
        public let range: Range<Int>
        public let depth: Int
        public let children: [Int]

        public init(
            label: String, detail: String, kind: Kind,
            range: Range<Int>, depth: Int, children: [Int]
        ) {
            self.label = label
            self.detail = detail
            self.kind = kind
            self.range = range
            self.depth = depth
            self.children = children
        }

        /// Nhảy về nguồn được không.
        public var canJumpToSource: Bool { !range.isEmpty }
    }

    /// Cây này dựng từ định dạng nào — để nói được đường dẫn tới một nút bằng ĐÚNG ngôn ngữ
    /// đường dẫn của định dạng ấy.
    ///
    /// Một cây chung cho bốn định dạng là đúng cho phần HÌNH DẠNG, nhưng đường dẫn thì không có
    /// dạng chung: JSON và YAML nói `$.a.b[0]`, XML nói `/a/b[2]/@c`, còn dàn ý thì không có
    /// ngôn ngữ đường dẫn nào cả.
    public enum Dialect: String, Sendable {
        case json, xml, yaml, outline
    }

    public let nodes: [Node]
    public let roots: [Int]
    /// Vì sao không dựng được. `nil` = dựng xong.
    public let failure: String?
    /// Tài liệu vượt trần — không phải lỗi cú pháp, mà là một lựa chọn có chủ ý.
    public let tooLarge: Bool
    public let dialect: Dialect

    public init(
        nodes: [Node], roots: [Int], failure: String? = nil, tooLarge: Bool = false,
        dialect: Dialect = .json
    ) {
        self.nodes = nodes
        self.roots = roots
        self.failure = failure
        self.tooLarge = tooLarge
        self.dialect = dialect
    }

    public var isEmpty: Bool { nodes.isEmpty }

    /// Tổng số nút — để khung nhìn nói ra quy mô trước khi người dùng cuộn.
    public var count: Int { nodes.count }
}

// MARK: - Từ vị trí con nháy về nút

extension StructureTree {

    /// Nút ứng với vị trí byte `offset` trong nguồn — **chiều ngược của phép nhảy về nguồn**.
    ///
    /// Bấm một nút thì con nháy nhảy về đúng byte của nó; chiều này trả lời câu hỏi kia: *đang
    /// đứng ở byte này thì trong cây là nút nào*. Thiếu nó thì View và Code mới là hai cách nhìn
    /// cùng một tài liệu theo MỘT chiều — mở View từ giữa một tệp mười nghìn dòng cho ra một cây
    /// bắt đầu từ đầu tài liệu, và người dùng phải tự đi tìm lại chỗ mình vừa đứng.
    ///
    /// ## Luật chọn — ba nấc, xét theo thứ tự
    ///
    /// 1. **Nút CHỨA vị trí ấy.** Chứa THẬT (`lower ≤ offset < upper`) thắng chứ chỉ CHẠM đầu
    ///    hoặc cuối (`offset == upper`); rồi sâu nhất; rồi hẹp nhất. Vế "chạm" có mặt vì con nháy
    ///    đứng ở CUỐI một dòng vẫn phải thuộc về dòng ấy — với dàn ý PowerPoint, nơi mỗi nút là
    ///    trọn một dòng, đó là chỗ con nháy hay đứng nhất. Vế "chứa thật thắng chạm" giải đúng
    ///    ranh giới `<a/>|<b/>`: con nháy nằm TRƯỚC ký tự ở vị trí ấy, nên nó thuộc về `b`.
    ///
    /// 2. **Đầu nút hay khe giữa hai con.** Nút chứa mà có con thì còn một câu hỏi nữa: con nháy
    ///    đang ở phần ĐẦU của nút (trước con thứ nhất) hay ở KHE giữa hai con? Ở đầu thì giữ
    ///    nguyên nút ấy — phần đầu là chỗ của chính nó: khoá của một khối YAML, tiêu đề một
    ///    slide, tên thẻ và thuộc tính của một thẻ XML. Ở khe thì chọn con BẮT ĐẦU KẾ TIẾP, vì
    ///    chữ đứng ngay trước một nút thuộc về chính nút ấy — khoá `"dia_chi":` của JSON nằm
    ///    NGOÀI khoảng byte của giá trị, mà con nháy đặt trên khoá thì người dùng đang nói tới
    ///    giá trị ấy chứ không tới cả object.
    ///
    /// 3. **Không nút nào chứa** — con nháy ở khoảng trắng cuối tệp, hay ở một dòng trống giữa
    ///    hai slide: lấy nút BẮT ĐẦU gần nhất phía trước; không có nữa thì gốc đầu tiên.
    ///
    /// Nút không biết chỗ của mình trong nguồn (khoảng RỖNG) thì không được chọn ở bất kỳ nấc
    /// nào — cùng luật với phép nhảy về nguồn, chỉ khác chiều.
    public func nodeIndex(containing offset: Int) -> Int? {
        guard !nodes.isEmpty else { return nil }

        var best = -1
        for (position, node) in nodes.enumerated() where node.canJumpToSource {
            guard node.range.lowerBound <= offset, offset <= node.range.upperBound else { continue }
            if best < 0 || isBetter(position, than: best, at: offset) { best = position }
        }

        if best >= 0 { return descend(from: best, at: offset) }

        var previous = -1
        for (position, node) in nodes.enumerated() where node.canJumpToSource {
            guard node.range.lowerBound <= offset else { continue }
            if previous < 0
                || nodes[position].range.lowerBound > nodes[previous].range.lowerBound
                || (nodes[position].range.lowerBound == nodes[previous].range.lowerBound
                    && nodes[position].depth > nodes[previous].depth) {
                previous = position
            }
        }
        if previous >= 0 { return previous }
        return roots.first
    }

    /// Đường từ GỐC xuống nút ấy — khung nhìn cần cả đường để mở từng tầng một.
    ///
    /// Mở thẳng nút đích mà không mở tổ tiên của nó thì `NSOutlineView` không có hàng nào để
    /// chọn: một nút chỉ có hàng khi mọi tầng trên nó đã mở.
    ///
    /// Cha suy ra từ danh sách con chứ không lưu sẵn trong nút: `Node` cố ý không mang con trỏ
    /// ngược, và một lượt quét là đủ.
    public func path(containing offset: Int) -> [Int] {
        guard let target = nodeIndex(containing: offset) else { return [] }
        return path(to: target)
    }

    /// Đường từ GỐC xuống một nút đã biết chỉ số.
    public func path(to target: Int) -> [Int] {
        guard target >= 0, target < nodes.count else { return [] }
        let parents = parentMap()

        var path = [target]
        var current = target
        // Trần theo số nút: một mảng con dựng sai có thể tạo vòng, và một vòng ở đây làm treo
        // ứng dụng chứ không nổ — thứ khó lần ra nhất.
        var guardCount = 0
        while parents[current] >= 0, guardCount < nodes.count {
            current = parents[current]
            path.append(current)
            guardCount += 1
        }
        return path.reversed()
    }

    /// Cha của từng nút, suy từ danh sách con. `-1` = gốc.
    ///
    /// `Node` cố ý không mang con trỏ ngược — thêm nó là thêm một thứ có thể lệch với danh sách
    /// con. Một lượt quét rẻ hơn một bất biến phải canh.
    func parentMap() -> [Int] {
        var parents = [Int](repeating: -1, count: nodes.count)
        for (position, node) in nodes.enumerated() {
            for child in node.children where child >= 0 && child < nodes.count {
                parents[child] = position
            }
        }
        return parents
    }

    /// Nấc 1: xếp hạng hai ứng viên cùng chứa một vị trí.
    private func isBetter(_ candidate: Int, than current: Int, at offset: Int) -> Bool {
        let new = nodes[candidate]
        let old = nodes[current]
        let newStrict = offset < new.range.upperBound
        let oldStrict = offset < old.range.upperBound
        if newStrict != oldStrict { return newStrict }
        if new.depth != old.depth { return new.depth > old.depth }
        return new.range.count < old.range.count
    }

    /// Nấc 2: đầu nút thì giữ nguyên, khe giữa hai con thì đi xuống con kế tiếp.
    private func descend(from node: Int, at offset: Int) -> Int {
        let children = nodes[node].children.filter { nodes[$0].canJumpToSource }
        guard let first = children.first else { return node }
        if offset < nodes[first].range.lowerBound { return node }
        if let next = children.first(where: { nodes[$0].range.lowerBound > offset }) { return next }
        return node
    }
}

// MARK: - Đường dẫn tới một nút

extension StructureTree {

    /// Đường dẫn tới một nút, viết bằng ngôn ngữ đường dẫn của chính định dạng ấy.
    ///
    /// Việc thật nó giải: người dùng tìm ra một chỗ trong cây rồi cần nói cho công cụ khác biết
    /// chỗ ấy — dán vào ô truy vấn JSONPath ngay trong sản phẩm này, vào một lệnh `yq`, vào một
    /// bài kiểm, hay vào tin nhắn cho đồng nghiệp. Không có nó thì họ đọc đường dẫn bằng mắt rồi
    /// gõ lại tay, và gõ lại tay một đường dẫn tám tầng là gõ sai.
    ///
    /// **JSON và YAML dùng CHUNG cú pháp JSONPath.** Không phải vì YAML "giống JSON", mà vì thứ
    /// người ta dán vào — `yq`, `jq`, ô truy vấn của chính sản phẩm này — đều nói cú pháp ấy.
    ///
    /// **Dàn ý trả về CHỮ của dòng, không trả đường dẫn.** Dàn ý không có ngôn ngữ đường dẫn
    /// nào, nên bịa ra một cú pháp là bịa một thứ không công cụ nào đọc được; còn chữ của dòng
    /// thì dán vào đâu cũng dùng được ngay.
    public func pathText(of index: Int) -> String {
        guard index >= 0, index < nodes.count else { return "" }
        if dialect == .outline { return nodes[index].label }

        let chain = path(to: index)
        guard !chain.isEmpty else { return "" }
        return dialect == .xml ? xmlPath(chain) : jsonPath(chain)
    }

    /// `$.dia_chi.tinh` · `$.diem[2]` · `$['tên có dấu']`
    ///
    /// Cùng luật với `JSONIndex.path(of:)` — và có bài kiểm đòi hai bên khớp nhau trên từng nút
    /// của một tài liệu thật. Hai bản của một quy tắc thì sẽ trôi khỏi nhau; ở đây bản thứ hai
    /// tồn tại vì cây chỉ giữ NHÃN chứ không giữ khoá gốc, nên chỗ neo là bài kiểm.
    private func jsonPath(_ chain: [Int]) -> String {
        let parents = parentMap()
        var text = "$"
        for node in chain {
            let label = nodes[node].label
            let parent = parents[node]
            // Gốc mang nhãn `$` (JSON) hoặc chính khoá của nó (YAML). Nhãn `$` là NÚT GỐC, đã
            // có mặt trong `text` rồi.
            if parent < 0, label == "$" { continue }
            // Phần tử của MẢNG nhận diện theo kiểu của CHA, không theo hình dạng của nhãn: một
            // object hoàn toàn có thể có khoá tên `[0]`, và đọc nhãn thì hai thứ ấy giống hệt
            // nhau — đường dẫn in ra sẽ trỏ vào phần tử mảng thứ nhất thay vì vào khoá ấy.
            if parent >= 0, nodes[parent].kind == .array {
                text += label
                continue
            }
            text += Self.isPlainJSONName(label)
                ? ".\(label)"
                : "['\(label.replacingOccurrences(of: "'", with: "\\'"))']"
        }
        return text
    }

    /// `/don_hang/khach[2]/@tinh` · `/don_hang/tong/text()`
    ///
    /// Chỉ số vị trí CHỈ thêm khi có anh em trùng tên — `[1]` trên một thẻ duy nhất là đúng
    /// XPath nhưng đọc lên như thể còn thẻ thứ hai ở đâu đó.
    private func xmlPath(_ chain: [Int]) -> String {
        let parents = parentMap()
        var text = ""
        for node in chain {
            let item = nodes[node]
            switch item.kind {
            case .attribute:
                text += "/@" + item.label.replacingOccurrences(of: "@", with: "")
            case .text:
                text += "/text()"
            default:
                text += "/" + item.label
                let parent = parents[node]
                let siblings = parent < 0
                    ? roots.filter { nodes[$0].label == item.label && nodes[$0].kind == .element }
                    : nodes[parent].children.filter {
                        nodes[$0].label == item.label && nodes[$0].kind == .element
                    }
                if siblings.count > 1, let position = siblings.firstIndex(of: node) {
                    text += "[\(position + 1)]"      // XPath đếm từ 1
                }
            }
        }
        return text
    }

    /// Tên viết được sau dấu chấm trong JSONPath. Cùng luật với `JSONIndex.isPlainName`.
    private static func isPlainJSONName(_ label: String) -> Bool {
        JSONIndex.isPlainName(label)
    }
}

// MARK: - Dựng từ JSON

extension StructureTree {

    /// Cây cho một tài liệu JSON.
    ///
    /// **Dùng lại `JSONIndex`, không viết bộ phân tích thứ hai.** Kho này đã ba lần gặp mẫu
    /// "hai bản của một thuật toán" và mỗi lần hai bản cho hai kết quả khác nhau trên cùng dữ
    /// liệu. `JSONIndex` đã có đúng thứ cần: cây phẳng, khoảng byte từng nút, không đệ quy, và
    /// một trần cỡ đã cân nhắc.
    public static func json(text: String) -> StructureTree {
        let bytes = Array(text.utf8)
        let index = JSONIndex(bytes: bytes)

        if index.tooLarge {
            return StructureTree(nodes: [], roots: [], tooLarge: true)
        }
        if let failure = index.failure {
            // Có lỗi cú pháp thì KHÔNG dựng cây một nửa: một cây cụt trông như tài liệu chỉ có
            // ngần ấy nội dung, và người dùng đi tìm phần thiếu ở chỗ khác.
            return StructureTree(nodes: [], roots: [], failure: failure.description)
        }
        guard !index.isEmpty else { return StructureTree(nodes: [], roots: []) }

        var nodes: [Node] = []
        nodes.reserveCapacity(index.nodes.count)
        for (position, node) in index.nodes.enumerated() {
            let children = Array(index.childIndices(of: position))
            nodes.append(Node(
                label: label(for: node),
                detail: node.kind.isContainer
                    ? containerDetail(node.kind, count: children.count)
                    : scalarDetail(bytes: bytes, range: node.range),
                kind: kind(from: node.kind),
                range: node.range,
                depth: node.depth,
                children: children
            ))
        }
        let roots = index.nodes.indices.filter { index.nodes[$0].parent < 0 }
        return StructureTree(nodes: nodes, roots: roots)
    }

    private static func label(for node: JSONIndex.Node) -> String {
        if !node.key.isEmpty { return node.key }
        // Nút GỐC không có cha, nên `indexInParent` của nó là −1 — và bản đầu in ra đúng chuỗi
        // `[-1]`, thứ ảnh chụp lộ ra ngay. Dùng `$`: đó là ký hiệu gốc của JSONPath, thứ người
        // dùng đã thấy ở panel truy vấn ngay trong chính sản phẩm này. Bịa một nhãn mới là dạy
        // hai ký hiệu cho cùng một ý.
        if node.parent < 0 { return "$" }
        // Phần tử mảng không có khoá; hiện chỉ số để người đọc đếm được mình đang ở đâu.
        return "[\(node.indexInParent)]"
    }

    private static func kind(from kind: JSONIndex.Kind) -> Kind {
        switch kind {
        case .object: return .object
        case .array: return .array
        case .string: return .string
        case .number: return .number
        case .bool: return .bool
        case .null: return .null
        }
    }

    /// Nút chứa hiện SỐ PHẦN TỬ, không hiện nội dung.
    ///
    /// Cả điểm của một cây gấp được là không phải nhìn nội dung khi chưa cần. Nhưng số phần tử
    /// thì phải thấy ngay: nó là thứ trả lời "có đáng mở ra không".
    private static func containerDetail(_ kind: JSONIndex.Kind, count: Int) -> String {
        kind == .array ? "[\(count)]" : "{\(count)}"
    }

    /// Giá trị vô hướng, cắt ngắn.
    ///
    /// Cắt theo BYTE rồi mới dựng chuỗi, và cắt ở biên ký tự: cắt giữa một ký tự nhiều byte cho
    /// ra một chuỗi hỏng, và chữ tiếng Việt thì ký tự nào cũng nhiều byte.
    static func scalarDetail(bytes: [UInt8], range: Range<Int>, limit: Int = 120) -> String {
        guard !range.isEmpty, range.upperBound <= bytes.count else { return "" }
        let slice = Array(bytes[range])
        if slice.count <= limit {
            return String(decoding: slice, as: UTF8.self)
        }
        var cut = limit
        // Lùi khỏi byte tiếp nối của UTF-8 (`10xxxxxx`) để không cắt giữa một ký tự.
        while cut > 0, slice[cut] & 0xC0 == 0x80 { cut -= 1 }
        return String(decoding: slice[0 ..< cut], as: UTF8.self) + "…"
    }
}

// MARK: - Dựng từ XML

extension StructureTree {

    /// Cây cho một tài liệu XML hoặc HTML.
    ///
    /// Cùng khuôn với `json(text:)` và cùng luật: hỏng cú pháp thì không dựng cây một nửa.
    public static func xml(text: String) -> StructureTree {
        let bytes = Array(text.utf8)
        let index = XMLIndex(bytes: bytes)

        if index.tooLarge { return StructureTree(nodes: [], roots: [], tooLarge: true, dialect: .xml) }
        if let failure = index.failure {
            return StructureTree(nodes: [], roots: [], failure: failure.description, dialect: .xml)
        }
        guard !index.isEmpty else { return StructureTree(nodes: [], roots: [], dialect: .xml) }

        var nodes: [Node] = []
        nodes.reserveCapacity(index.nodes.count)
        for (position, node) in index.nodes.enumerated() {
            let children = Array(index.childIndices(of: position))
            nodes.append(Node(
                label: label(for: node),
                detail: detail(for: node, childCount: children.count),
                kind: kind(from: node.kind),
                range: node.range,
                depth: node.depth,
                children: children
            ))
        }
        let roots = index.nodes.indices.filter { index.nodes[$0].parent < 0 }
        return StructureTree(nodes: nodes, roots: roots, dialect: .xml)
    }

    private static func label(for node: XMLIndex.Node) -> String {
        switch node.kind {
        case .element: return node.name
        // Tiền tố `@` cho thuộc tính — đúng ký hiệu XPath, thứ người dùng đã gặp ở lệnh kiểm
        // XML trong chính sản phẩm này. Không bịa ký hiệu mới cho một ý đã có ký hiệu.
        case .attribute: return "@" + node.name
        case .text: return "#text"
        }
    }

    private static func detail(for node: XMLIndex.Node, childCount: Int) -> String {
        switch node.kind {
        case .element:
            // Thẻ chỉ chứa CHỮ thì hiện luôn chữ ấy: bắt người dùng mở một thẻ ra để thấy đúng
            // một dòng là bắt họ bấm cho một thứ đã có chỗ để hiện.
            return childCount == 0 ? "" : "<\(childCount)>"
        case .attribute, .text:
            return node.value
        }
    }

    private static func kind(from kind: XMLIndex.Kind) -> Kind {
        switch kind {
        case .element: return .element
        case .attribute: return .attribute
        case .text: return .text
        }
    }
}


// MARK: - Dựng từ YAML

extension StructureTree {

    /// Dựng cây từ nguồn YAML. Xem `YAMLIndex` để biết vì sao không dùng `YAMLReader`.
    public static func yaml(text: String) -> StructureTree {
        let bytes = Array(text.utf8)
        let index = YAMLIndex(bytes: bytes)

        if index.tooLarge { return StructureTree(nodes: [], roots: [], tooLarge: true, dialect: .yaml) }
        if let failure = index.failure {
            return StructureTree(nodes: [], roots: [], failure: failure.message, dialect: .yaml)
        }
        guard !index.isEmpty else { return StructureTree(nodes: [], roots: [], dialect: .yaml) }

        var nodes: [Node] = []
        nodes.reserveCapacity(index.nodes.count)
        for (position, node) in index.nodes.enumerated() {
            let children = Array(index.childIndices(of: position))
            nodes.append(Node(
                label: node.name,
                detail: detail(for: node, childCount: children.count),
                kind: kind(for: node),
                range: node.range,
                depth: node.depth,
                children: children
            ))
        }
        let roots = index.nodes.indices.filter { index.nodes[$0].parent < 0 }
        return StructureTree(nodes: nodes, roots: roots, dialect: .yaml)
    }

    private static func detail(for node: YAMLIndex.Node, childCount: Int) -> String {
        switch node.kind {
        case .mapping: return "{\(childCount)}"
        case .sequence: return "[\(childCount)]"
        case .scalar: return node.value
        }
    }

    /// Đoán kiểu của một giá trị YAML để khung nhìn tô đúng màu.
    ///
    /// Chỉ đoán khi giá trị KHÔNG có nháy: trong YAML `"42"` là chữ còn `42` là số, và đó là cả
    /// điểm của dấu nháy. Bỏ qua vế ấy thì cây tô hai thứ khác nhau bằng cùng một màu, ngay tại
    /// chỗ người ta mở cây ra để phân biệt chúng.
    private static func kind(for node: YAMLIndex.Node) -> Kind {
        switch node.kind {
        case .mapping: return .object
        case .sequence: return .array
        case .scalar: break
        }
        if node.quoted { return .string }
        switch node.value {
        case "true", "false", "True", "False", "yes", "no", "on", "off": return .bool
        case "null", "Null", "NULL", "~", "": return .null
        default:
            return Double(node.value) != nil ? .number : .string
        }
    }
}

// MARK: - Dựng từ bản trình chiếu

extension StructureTree {

    /// Dàn ý một bản trình chiếu: mỗi slide là một gốc, gạch đầu dòng là con.
    ///
    /// ## Dựng từ VĂN BẢN ĐANG MỞ, không từ tệp trên đĩa
    ///
    /// Chế độ Code của một tệp `.pptx` là dàn ý Markdown, và người dùng sửa được nó. Đọc lại tệp
    /// `.pptx` để dựng cây thì cây ấy mô tả bản CŨ, còn khoảng byte của nó lại được đem áp vào
    /// buffer MỚI — mỗi nút trỏ lệch một quãng, và bấm vào là con nháy rơi giữa một dòng khác.
    /// Thà dựng từ đúng chuỗi mà người dùng đang nhìn.
    ///
    /// ## Vì sao đọc tiền tố ở đây là an toàn
    ///
    /// `PPTXReader.build` LUÔN viết tiền tố: tiêu đề `## `, gạch đầu dòng `- `, ghi chú `> `.
    /// Chữ của slide đi vào SAU tiền tố, nên một tiêu đề bắt đầu bằng `- ` vẫn ra `## - …`. Vai
    /// trò của dòng vì thế đọc được từ tiền tố mà không nhập nhằng.
    ///
    /// Và để hai bên không trôi khỏi nhau, `PPTXReader.Presentation.outline` ghi lại vai trò của
    /// từng dòng ngay trong lượt sinh — bài kiểm bắt hai cách đọc ấy phải khớp từng dòng.
    public static func powerPoint(markdown: String) -> StructureTree {
        let bytes = Array(markdown.utf8)
        var nodes: [Node] = []
        var roots: [Int] = []
        var currentSlide = -1
        var noteGroup = -1

        func append(_ label: String, _ kind: Kind, _ range: Range<Int>, _ depth: Int) -> Int {
            nodes.append(Node(label: label, detail: "", kind: kind,
                              range: range, depth: depth, children: []))
            return nodes.count - 1
        }
        func addChild(_ parent: Int, _ child: Int) {
            let node = nodes[parent]
            var children = node.children
            children.append(child)
            nodes[parent] = Node(label: node.label, detail: node.detail, kind: node.kind,
                                 range: node.range, depth: node.depth, children: children)
        }

        var offset = 0
        while offset <= bytes.count {
            var end = offset
            while end < bytes.count, bytes[end] != UInt8(ascii: "\n") { end += 1 }
            let range = offset ..< end
            let text = String(decoding: bytes[range], as: UTF8.self)
            offset = end + 1

            if text.hasPrefix("## ") {
                noteGroup = -1
                currentSlide = append(String(text.dropFirst(3)), .object, range, 0)
                roots.append(currentSlide)
            } else if text.hasPrefix("> **"), currentSlide >= 0 {
                // Ghi chú gom vào MỘT nút gấp được. Trải thẳng chúng cạnh gạch đầu dòng thì một
                // slide nói nhiều trông như một slide có nhiều nội dung — đúng thứ dàn ý phải
                // trả lời được bằng mắt.
                let label = text.trimmingCharacters(in: CharacterSet(charactersIn: "> *"))
                noteGroup = append(label, .array, range, 1)
                addChild(currentSlide, noteGroup)
            } else if text.hasPrefix("> "), noteGroup >= 0 {
                addChild(noteGroup, append(String(text.dropFirst(2)), .string, range, 2))
            } else if text.hasPrefix("- "), currentSlide >= 0 {
                addChild(currentSlide, append(String(text.dropFirst(2)), .string, range, 1))
            }
            if end >= bytes.count { break }
        }

        // Số con hiện cạnh nhãn — nó trả lời "có đáng mở ra không".
        for index in nodes.indices where nodes[index].kind.isContainer {
            let node = nodes[index]
            nodes[index] = Node(
                label: node.label,
                detail: node.kind == .array ? "[\(node.children.count)]"
                                            : "{\(node.children.count)}",
                kind: node.kind, range: node.range, depth: node.depth, children: node.children)
        }
        return StructureTree(nodes: nodes, roots: roots, dialect: .outline)
    }
}
