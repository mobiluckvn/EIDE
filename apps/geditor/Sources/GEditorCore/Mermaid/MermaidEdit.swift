import Foundation

/// Soạn thảo sơ đồ Mermaid trực quan — FR-MMD-004.
///
/// Đặc tả: *"Thao tác TRÊN SƠ ĐỒ sinh chỉnh sửa văn bản qua applyEdits (mỗi thao tác một bước
/// undo, giữ comment và thụt lề — buffer là nguồn sự thật, nhất quán FR-KNW-915). Phạm vi theo
/// loại sơ đồ ghi rõ: flowchart/state/class/ER — thêm/xóa node và cạnh (kéo từ node nguồn), sửa
/// nhãn double-click; sequence — thêm participant, thêm/đổi thứ tự message; gantt/pie — sửa qua
/// bảng thuộc tính bên cạnh. Loại chưa hỗ trợ visual: hiển thị rõ 'chỉ soạn text'."*
///
/// ## Cùng khuôn `GraphEdit`, và đó là quyết định chứ không phải sự trùng lặp
///
/// Không hàm nào ở đây sửa gì; chúng trả `[TextEdit]` để chỗ gọi áp bằng `applyEdits` — một lần,
/// một bước undo. FR-KNW-915 đã đặt khuôn ấy cho DOT, và mermaid là **cùng một bài toán trên một
/// phương ngữ khác**: nếu ở đây sửa một mô hình trong bộ nhớ rồi mới sinh văn bản thì mô hình ấy
/// thành nguồn sự thật thứ hai, đúng thứ SAD Hình 4 cấm.
///
/// ## Sửa TẠI CHỖ theo dòng, không viết lại cả sơ đồ
///
/// `MermaidFormatter` đã ghi lý do và nó áp nguyên vào đây: cây phân tích thật nằm trong
/// mermaid.js và không có API trả nó ra. Một bộ soạn dựng lại toàn bộ mã sơ đồ từ mô hình đọc
/// được sẽ **xoá đúng những thứ nó chưa hiểu** — chú thích, chỉ thị `%%{init}%%`, `classDef`,
/// `click`, `style`. Nên mọi phép ở đây chỉ chèn một dòng, thay một đoạn trong một dòng, hoặc
/// xoá trọn dòng.
///
/// ## Loại nào soạn được, và loại nào NÓI THẲNG là không
///
/// `support(for:)` trả về đúng bốn mức, và mức `textOnly` mang theo LÝ DO. Đặc tả đòi *"Loại chưa
/// hỗ trợ visual: hiển thị rõ 'chỉ soạn text'"* — một tính năng im lặng không làm gì khi người
/// dùng kéo trên sơ đồ `mindmap` là cách chắc chắn nhất khiến họ nghĩ công cụ hỏng.
public enum MermaidEdit {

    public struct Failure: Error, Equatable {
        public let reason: String
        public init(reason: String) { self.reason = reason }
    }

    // MARK: - Mức hỗ trợ

    public enum Support: Equatable, Sendable {
        /// flowchart · state · class · ER — thêm/xoá node và cạnh, sửa nhãn.
        case nodesAndEdges
        /// sequence — thêm participant, thêm và đổi thứ tự message.
        case sequence
        /// gantt · pie — sửa qua bảng thuộc tính.
        case propertyTable
        /// Chưa soạn trực quan được, kèm lý do.
        case textOnly(String)

        public var isVisual: Bool {
            if case .textOnly = self { return false }
            return true
        }
    }

    public static func support(for kind: MermaidDiagramKind) -> Support {
        switch kind {
        case .flowchart, .state, .classDiagram, .entityRelationship:
            return .nodesAndEdges
        case .sequence:
            return .sequence
        case .gantt, .pie:
            return .propertyTable
        case .mindmap:
            return .textOnly("mindmap dựng cây bằng THỤT LỀ, nên «kéo một nhánh» là đổi cấp thụt "
                + "của cả cụm con — chưa làm")
        case .timeline:
            return .textOnly("timeline gom sự kiện theo dòng thời gian, chưa có thao tác kéo nào "
                + "ánh xạ ngược được — chưa làm")
        case .quadrant:
            return .textOnly("quadrantChart đặt điểm bằng TOẠ ĐỘ, mà kéo trên hình chỉ cho toạ độ "
                + "màn hình — chưa làm")
        case .gitGraph:
            return .textOnly("gitGraph là một chuỗi lệnh có thứ tự (commit, branch, merge); sửa "
                + "trực quan phải hiểu cả lịch sử — chưa làm")
        case let .other(keyword):
            return .textOnly("loại «\(keyword)» mermaid vẽ được nhưng bộ soạn chưa biết cấu trúc")
        }
    }

    // MARK: - Mô hình đọc được

    public struct Node: Equatable, Sendable {
        public var id: String
        public var label: String?
        /// Dòng KHAI node, 0-based trong nguồn sơ đồ. `nil` khi node chỉ xuất hiện trong cạnh.
        public var declLine: Int?
        /// Dòng đang MANG nhãn — có thể là một dòng CẠNH, vì `A["Nhãn"] --> B` đặt nhãn ngay
        /// trong câu lệnh cạnh.
        ///
        /// Tách khỏi `declLine` vì hai thứ này khác nhau và lẫn chúng đã sinh ra một lỗi thật:
        /// sửa nhãn đi thêm một dòng khai MỚI trong khi nhãn cũ vẫn nằm nguyên trên dòng cạnh,
        /// và sơ đồ có hai nhãn cho một node.
        public var labelLine: Int?
        public var display: String { label ?? id }
    }

    public struct Edge: Equatable, Sendable {
        public var from: String
        public var to: String
        public var label: String?
        public var arrow: String
        public var line: Int
    }

    /// Một dòng của bảng thuộc tính — mục gantt hoặc lát bánh.
    public struct Row: Equatable, Sendable {
        public var label: String
        public var value: String
        public var line: Int
        /// `section` đang mở, `nil` với pie và với gantt chưa khai section.
        public var section: String?
    }

    public struct Model: Equatable, Sendable {
        public var kind: MermaidDiagramKind
        public var nodes: [Node]
        public var edges: [Edge]
        public var rows: [Row]
        /// Dòng khai báo loại sơ đồ, 0-based. `nil` khi sơ đồ rỗng.
        public var declarationLine: Int?
        /// Dòng sau dòng cuối cùng có nghĩa — chỗ chèn câu lệnh mới.
        public var insertLine: Int
        /// Số cấp khối còn mở ở cuối nguồn. `> 0` nghĩa là chèn vào cuối sẽ rơi VÀO TRONG khối.
        public var openDepth: Int

        public func node(_ id: String) -> Node? { nodes.first { $0.id == id } }
    }

    // MARK: - Đọc

    /// Đọc cấu trúc từ nguồn sơ đồ. Không bao giờ ném — sơ đồ gõ dở vẫn phải xem trước được.
    public static func parse(_ source: String) -> Model {
        let lines = source.components(separatedBy: "\n")
        let kind = MermaidDocument.declaration(in: source)
            .map(MermaidDiagramKind.from(declaration:)) ?? .other("")
        var nodes: [Node] = []
        var edges: [Edge] = []
        var rows: [Row] = []
        var declarationLine: Int?
        var insertLine = lines.count
        var depth = 0
        var section: String?
        var inFrontmatter = false
        var inDirective = false

        func ghiNode(_ id: String, label: String?, declLine: Int?, at line: Int) {
            guard !id.isEmpty else { return }
            if let i = nodes.firstIndex(where: { $0.id == id }) {
                // Nhãn và dòng khai chỉ được ĐIỀN THÊM, không được ghi đè: `A[Nhãn]` ở dòng cạnh
                // rồi `A` trần ở dòng sau không được xoá mất nhãn vừa đọc.
                if nodes[i].label == nil, let label {
                    nodes[i].label = label
                    nodes[i].labelLine = line
                }
                if nodes[i].declLine == nil, let declLine { nodes[i].declLine = declLine }
            } else {
                nodes.append(Node(id: id, label: label, declLine: declLine,
                                  labelLine: label == nil ? nil : line))
            }
        }

        for (number, raw) in lines.enumerated() {
            let text = raw.trimmingCharacters(in: .whitespaces)

            // Frontmatter YAML `---` … `---` ở đầu sơ đồ.
            if number == 0 || declarationLine == nil, text == "---" {
                inFrontmatter.toggle()
                continue
            }
            if inFrontmatter { continue }
            if inDirective {
                if text.contains("}%%") { inDirective = false }
                continue
            }
            if text.hasPrefix("%%{") {
                if !text.contains("}%%") { inDirective = true }
                continue
            }
            if text.isEmpty || text.hasPrefix("%%") { continue }

            if declarationLine == nil {
                declarationLine = number
                insertLine = number + 1
                continue
            }
            insertLine = number + 1

            // Đóng khối trước khi mở: `}` một mình, `end`.
            let word = text.split(separator: " ").first.map(String.init) ?? ""
            if text == "}" || word == "end" {
                depth = max(0, depth - 1)
                continue
            }
            if word == "section" {
                section = String(text.dropFirst("section".count))
                    .trimmingCharacters(in: .whitespaces)
                continue
            }

            // Bên trong `{ … }` của classDiagram và ER là THÀNH VIÊN, không phải node hay cạnh
            // (`string name`, `+ten()`), nên bỏ qua. Không bỏ qua thì mỗi thuộc tính thành một
            // node ma. Với state thì ngược lại: `state X { … }` chứa chuyển trạng thái THẬT.
            let trongKhoi = depth > 0 && [.classDiagram, .entityRelationship].contains(kind)
            if !trongKhoi {
                switch support(for: kind) {
                case .propertyTable:
                    if let row = parseRow(text, line: number, section: section, kind: kind) {
                        rows.append(row)
                    }
                case .nodesAndEdges, .sequence:
                    if let found = parseEdge(text, kind: kind, line: number) {
                        edges.append(found.edge)
                        ghiNode(found.from.id, label: found.from.label, declLine: nil,
                                at: number)
                        ghiNode(found.to.id, label: found.to.label, declLine: nil, at: number)
                    } else if let found = parseDeclaration(text, kind: kind) {
                        ghiNode(found.id, label: found.label,
                                declLine: found.isDeclaration ? number : nil, at: number)
                    }
                case .textOnly:
                    break
                }
            }
            if text.hasSuffix("{") { depth += 1 }
        }

        return Model(kind: kind, nodes: nodes, edges: edges, rows: rows,
                     declarationLine: declarationLine, insertLine: insertLine, openDepth: depth)
    }

    // MARK: - Phương ngữ

    /// Mũi tên của từng loại, **dài trước ngắn**.
    ///
    /// Thứ tự là một phần của câu trả lời, không phải chuyện thẩm mỹ: tìm `-->` trước `--` thì
    /// một cạnh `A --> B` được đọc đúng; tìm ngược lại thì nó thành `A -` `-> B`.
    static func arrows(for kind: MermaidDiagramKind) -> [String] {
        switch kind {
        case .flowchart:
            return ["-.->", "-.-", "===>", "==>", "===", "-->", "--x", "--o", "---",
                    "~~~", "--"]
        case .state:
            return ["-->"]
        case .classDiagram:
            return ["<|--", "--|>", "..|>", "<|..", "*--", "o--", "--*", "--o", "..>",
                    "<..", "-->", "<--", "..", "--"]
        case .entityRelationship:
            return ["--", ".."]
        case .sequence:
            return ["-->>", "--)", "--x", "->>", "-->", "-)", "--", "-x", "->"]
        default:
            return []
        }
    }

    static func defaultArrow(for kind: MermaidDiagramKind) -> String {
        switch kind {
        case .classDiagram: return "-->"
        case .entityRelationship: return "||--o{"
        case .sequence: return "->>"
        default: return "-->"
        }
    }

    /// Câu lệnh KHAI một node, đúng phương ngữ của từng loại.
    ///
    /// Bảng này là chỗ dễ sai nhất của cả tệp, vì sai nghĩa là **sơ đồ đang chạy bỗng không vẽ
    /// được**. Nên nó không được chấm bằng một bài kiểm chuỗi: có một bài tự kiểm dựng đúng bốn
    /// loại rồi CHẠY QUA MERMAID THẬT sau mỗi phép, và đòi số sơ đồ hỏng bằng 0.
    static func declaration(id: String, label: String?, kind: MermaidDiagramKind) -> String {
        switch kind {
        case .classDiagram:
            return label.map { "class \(id)[\"\(escape($0))\"]" } ?? "class \(id)"
        case .state:
            return label.map { "\(id) : \(escape($0))" } ?? "state \(id)"
        case .entityRelationship:
            // Thực thể ER khai bằng KHỐI thuộc tính; một cái tên trần không phải câu lệnh hợp lệ.
            return label.map { "\(id)[\"\(escape($0))\"] {\n}" } ?? "\(id) {\n}"
        case .sequence:
            return label.map { "participant \(id) as \(escape($0))" } ?? "participant \(id)"
        default:
            return label.map { "\(id)[\"\(escape($0))\"]" } ?? id
        }
    }

    /// Một dòng CẠNH đã dựng sẵn.
    static func statement(
        from: String, to: String, label: String?, kind: MermaidDiagramKind
    ) -> String {
        let arrow = defaultArrow(for: kind)
        switch kind {
        case .flowchart:
            return label.map { "\(from) \(arrow)|\(escape($0))| \(to)" } ?? "\(from) \(arrow) \(to)"
        case .sequence:
            return "\(from)\(arrow)\(to): \(escape(label ?? ""))"
        case .entityRelationship:
            // Nhãn quan hệ là BẮT BUỘC ở erDiagram — thiếu nó thì mermaid không vẽ.
            return "\(from) \(arrow) \(to) : \(escape(label ?? "liên quan"))"
        default:
            return label.map { "\(from) \(arrow) \(to) : \(escape($0))" } ?? "\(from) \(arrow) \(to)"
        }
    }

    // MARK: - Thêm

    public static func addNode(
        id: String, label: String? = nil, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        try guardVisual(model, need: [.nodesAndEdges, .sequence])
        try guardIdentifier(id)
        if model.node(id) != nil { throw Failure(reason: "đã có «\(id)» trong sơ đồ") }
        return [chen(declaration(id: id, label: label, kind: model.kind),
                     into: source, model: model)]
    }

    /// Thêm một cạnh — thao tác "kéo từ node nguồn" của đặc tả.
    ///
    /// KHÔNG tự tạo node còn thiếu, cùng lý do đã ghi ở `GraphEdit.addEdge`: người dùng đang kéo
    /// giữa hai thứ họ NHÌN THẤY, nên một đầu không có thật là lỗi của chỗ gọi.
    public static func addEdge(
        from: String, to: String, label: String? = nil, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        try guardVisual(model, need: [.nodesAndEdges, .sequence])
        for id in [from, to] where model.node(id) == nil {
            throw Failure(reason: "không có «\(id)» trong sơ đồ")
        }
        return [chen(statement(from: from, to: to, label: label, kind: model.kind),
                     into: source, model: model)]
    }

    // MARK: - Sửa nhãn

    /// Đổi nhãn một node — thao tác "double-click" của đặc tả.
    public static func setLabel(
        of id: String, to label: String, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        try guardVisual(model, need: [.nodesAndEdges, .sequence])
        guard let node = model.node(id) else {
            throw Failure(reason: "không có «\(id)» trong sơ đồ")
        }
        let lines = source.components(separatedBy: "\n")

        // Đã có nhãn ở đâu đó → thay ĐÚNG chỗ ấy, kể cả khi nó nằm giữa một dòng CẠNH.
        if let line = node.labelLine, line < lines.count,
           let range = labelRange(in: lines[line], id: id, kind: model.kind) {
            return [TextEdit(range: shiftIntoDocument(range, line: line, lines: lines),
                             text: escape(label))]
        }
        // Có dòng khai nhưng chưa có nhãn → thêm nhãn vào ĐÚNG dòng ấy.
        if let line = node.declLine, line < lines.count,
           let edit = themNhan(label, into: lines[line], line: line, lines: lines,
                               kind: model.kind) {
            return [edit]
        }
        // Chỉ xuất hiện trong cạnh → thêm hẳn một dòng khai. Sửa vào giữa dòng cạnh cũng được,
        // nhưng khi ấy nhãn nằm ở chỗ người đọc không ngờ, và lần sửa sau lại phải tìm nó ở một
        // dòng khác nữa.
        return [chen(declaration(id: id, label: label, kind: model.kind),
                     into: source, model: model)]
    }

    // MARK: - Xoá

    /// Xoá một node VÀ mọi cạnh chạm tới nó.
    ///
    /// Cùng lý do với `GraphEdit.removeNode`: mermaid cũng tự sinh node từ cạnh, nên bỏ sót phần
    /// cạnh là để node "đã xoá" hiện lại ngay lượt vẽ sau.
    public static func removeNode(_ id: String, in source: String) throws -> [TextEdit] {
        let model = parse(source)
        try guardVisual(model, need: [.nodesAndEdges, .sequence])
        guard let node = model.node(id) else {
            throw Failure(reason: "không có «\(id)» trong sơ đồ")
        }
        var dong = Set<Int>()
        if let line = node.declLine { dong.insert(line) }
        for edge in model.edges where edge.from == id || edge.to == id { dong.insert(edge.line) }
        guard !dong.isEmpty else {
            throw Failure(reason: "«\(id)» không có dòng nào để xoá")
        }
        let chamToi = model.edges
            .filter { $0.from == id || $0.to == id }
            .flatMap { [$0.from, $0.to] }
        return xoaDong(dong, in: source)
            + giuLai(chamToi, deleted: dong, except: [id], model: model, source: source)
    }

    public static func removeEdge(from: String, to: String, in source: String) throws -> [TextEdit] {
        let model = parse(source)
        try guardVisual(model, need: [.nodesAndEdges, .sequence])
        let khop = model.edges.filter { $0.from == from && $0.to == to }
        guard !khop.isEmpty else {
            throw Failure(reason: "không có cạnh «\(from)» → «\(to)»")
        }
        let dong = Set(khop.map(\.line))
        return xoaDong(dong, in: source)
            + giuLai([from, to], deleted: dong, except: [], model: model, source: source)
    }

    /// Giữ lại những node sẽ BIẾN MẤT theo dòng vừa xoá, bằng cách khai lại chúng.
    ///
    /// Mermaid cho khai node NGAY TRONG câu lệnh cạnh (`A["Nhận"] --> B["Duyệt"]`), nên xoá một
    /// cạnh có thể xoá luôn cả hai node ở hai đầu — trong khi người dùng chỉ bấm "xoá cạnh" và
    /// vẫn đang nhìn hai node ấy trên hình. Đó là khác biệt thật so với DOT, nơi node hầu như
    /// luôn có câu lệnh khai riêng, và nó là lý do hàm này tồn tại.
    ///
    /// Nhãn được mang theo: khai lại mà mất nhãn thì node "vẫn còn" nhưng đổi tên trước mắt
    /// người dùng.
    static func giuLai(
        _ ids: [String], deleted: Set<Int>, except: [String], model: Model, source: String
    ) -> [TextEdit] {
        var can: [String] = []
        for id in ids where !except.contains(id) && !can.contains(id) {
            if id == "[*]" { continue }   // dấu bắt đầu/kết thúc của state, không phải node
            guard let node = model.node(id) else { continue }
            let coDongKhai = node.declLine.map { !deleted.contains($0) } ?? false
            let conCanhKhac = model.edges.contains {
                !deleted.contains($0.line) && ($0.from == id || $0.to == id)
            }
            if !coDongKhai, !conCanhKhac { can.append(id) }
        }
        guard !can.isEmpty else { return [] }
        // MỘT lần chèn cho tất cả: hai `TextEdit` chèn vào cùng một vị trí rỗng thì thứ tự của
        // chúng trong văn bản không xác định.
        let than = can
            .map { declaration(id: $0, label: model.node($0)?.label, kind: model.kind) }
            .joined(separator: "\n")
        return [chen(than, into: source, model: model)]
    }

    // MARK: - Sequence: đổi thứ tự message

    public enum Direction: Equatable, Sendable { case up, down }

    /// Đổi thứ tự hai message — vế *"thêm/đổi thứ tự message"* của đặc tả.
    ///
    /// ĐỔI CHỖ hai dòng chứ không chèn-rồi-xoá: chèn-rồi-xoá đi qua một trạng thái trung gian có
    /// hai bản của cùng một message, và nếu chỉ nửa đầu được áp thì sơ đồ có một message thừa.
    public static func moveMessage(
        at line: Int, _ direction: Direction, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        guard case .sequence = support(for: model.kind) else {
            throw Failure(reason: "đổi thứ tự message chỉ có ở sequenceDiagram")
        }
        let dong = model.edges.map(\.line).sorted()
        guard let vitri = dong.firstIndex(of: line) else {
            throw Failure(reason: "dòng \(line + 1) không phải một message")
        }
        let khac = direction == .up ? vitri - 1 : vitri + 1
        guard khac >= 0, khac < dong.count else {
            throw Failure(reason: direction == .up
                ? "message này đã ở trên cùng" : "message này đã ở dưới cùng")
        }
        let lines = source.components(separatedBy: "\n")
        let a = min(line, dong[khac]), b = max(line, dong[khac])
        // Chỉ đổi phần NỘI DUNG, giữ nguyên thụt lề của từng dòng: hai message trong một khối
        // `alt` thụt sâu hơn message ngoài khối, và đổi cả phần thụt sẽ làm hỏng cấu trúc.
        let (indentA, noiDungA) = tach(lines[a])
        let (indentB, noiDungB) = tach(lines[b])
        return [
            TextEdit(range: rangeOfLineContent(b, lines: lines), text: indentB + noiDungA),
            TextEdit(range: rangeOfLineContent(a, lines: lines), text: indentA + noiDungB),
        ]
    }

    // MARK: - gantt / pie: bảng thuộc tính

    /// Sửa một dòng của bảng thuộc tính.
    public static func setRow(
        at line: Int, label: String, value: String, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        guard case .propertyTable = support(for: model.kind) else {
            throw Failure(reason: "bảng thuộc tính chỉ có ở gantt và pie")
        }
        guard model.rows.contains(where: { $0.line == line }) else {
            throw Failure(reason: "dòng \(line + 1) không phải một mục của bảng")
        }
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Failure(reason: "tên mục không được rỗng")
        }
        let lines = source.components(separatedBy: "\n")
        let (indent, _) = tach(lines[line])
        return [TextEdit(range: rangeOfLineContent(line, lines: lines),
                         text: indent + rowText(label: label, value: value, kind: model.kind))]
    }

    public static func addRow(
        label: String, value: String, in source: String
    ) throws -> [TextEdit] {
        let model = parse(source)
        guard case .propertyTable = support(for: model.kind) else {
            throw Failure(reason: "bảng thuộc tính chỉ có ở gantt và pie")
        }
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Failure(reason: "tên mục không được rỗng")
        }
        return [chen(rowText(label: label, value: value, kind: model.kind),
                     into: source, model: model)]
    }

    public static func removeRow(at line: Int, in source: String) throws -> [TextEdit] {
        let model = parse(source)
        guard model.rows.contains(where: { $0.line == line }) else {
            throw Failure(reason: "dòng \(line + 1) không phải một mục của bảng")
        }
        return xoaDong([line], in: source)
    }

    static func rowText(label: String, value: String, kind: MermaidDiagramKind) -> String {
        // pie đòi nhãn trong dấu nháy; gantt thì không được có nháy ở tên việc.
        if case .pie = kind { return "\"\(escape(label))\" : \(value)" }
        return "\(label) :\(value.hasPrefix(" ") ? "" : " ")\(value)"
    }

    // MARK: - Từ HÌNH về ĐỊNH DANH

    /// Chữ người dùng bấm trên hình → **định danh** trong mã sơ đồ.
    ///
    /// Cùng luật của `GraphEdit.resolveNode`, và cùng lý do: hình vẽ hiện NHÃN còn mọi phép sửa
    /// dùng ĐỊNH DANH. Hai node cùng nhãn thì NÓI RA thay vì lấy cái đầu tiên — đoán sai ở đây
    /// là sửa nhầm node, và người dùng chỉ thấy hình vẽ không đổi.
    public static func resolveNode(_ text: String, in model: Model) throws -> String {
        let can = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !can.isEmpty else { throw Failure(reason: "chưa chọn phần tử nào") }
        if model.nodes.contains(where: { $0.id == can }) { return can }
        let khop = model.nodes.filter { $0.display == can }
        guard let dau = khop.first else {
            throw Failure(reason: "không có phần tử nào tên hay mang nhãn «\(can)»")
        }
        guard khop.count == 1 else {
            throw Failure(reason: "có \(khop.count) phần tử cùng mang nhãn «\(can)» "
                + "(\(khop.map(\.id).joined(separator: ", "))) — sửa trong văn bản để chỉ rõ")
        }
        return dau.id
    }

    // MARK: - Dời sửa đổi về toạ độ tài liệu

    /// Dời một loạt sửa đổi đi `delta` byte.
    ///
    /// Cần vì mọi phép ở đây tính theo NGUỒN SƠ ĐỒ, còn buffer chứa cả tài liệu: một khối
    /// ` ```mermaid ` nằm giữa một tệp Markdown lệch đi đúng bằng vị trí của nó. Đây là chỗ đã
    /// làm lệch số dòng ở FR-KNW-905 (bản chuyển có thêm một dòng đầu), nên nó là một hàm có tên
    /// và có bài kiểm, không phải một phép cộng rải rác ở chỗ gọi.
    public static func shift(_ edits: [TextEdit], by delta: Int) -> [TextEdit] {
        guard delta != 0 else { return edits }
        return edits.map {
            TextEdit(range: ($0.range.lowerBound + delta) ..< ($0.range.upperBound + delta),
                     bytes: $0.bytes)
        }
    }

    // MARK: - Phụ

    static func guardVisual(_ model: Model, need: [Support]) throws {
        let muc = support(for: model.kind)
        if case let .textOnly(reason) = muc {
            throw Failure(reason: "sơ đồ «\(model.kind.vietnamese)» chỉ soạn text: \(reason)")
        }
        guard need.contains(muc) else {
            throw Failure(reason: "phép này không áp cho sơ đồ «\(model.kind.vietnamese)»")
        }
        guard model.declarationLine != nil else {
            throw Failure(reason: "sơ đồ chưa có dòng khai báo loại")
        }
        guard model.openDepth == 0 else {
            throw Failure(reason: "sơ đồ còn \(model.openDepth) khối chưa đóng — "
                + "đóng chúng rồi thử lại")
        }
    }

    static func guardIdentifier(_ id: String) throws {
        guard !id.isEmpty else { throw Failure(reason: "định danh rỗng") }
        guard !id.contains(where: { $0.isWhitespace }) else {
            throw Failure(reason: "định danh «\(id)» có khoảng trắng — mermaid sẽ đọc thành hai từ")
        }
        for banned in ["\"", "[", "]", "(", ")", "{", "}", "-", ">", "<", "|", ":", ";", "%"]
        where id.contains(banned) {
            throw Failure(reason: "định danh «\(id)» chứa «\(banned)», ký tự có nghĩa trong mermaid")
        }
    }

    /// Chèn một câu lệnh mới vào cuối sơ đồ, theo thụt lề hiện hành.
    static func chen(_ statement: String, into source: String, model: Model) -> TextEdit {
        let lines = source.components(separatedBy: "\n")
        let indent = self.indent(of: source)
        let than = statement.split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }.joined(separator: "\n")
        // Chèn TRƯỚC phần đuôi (dòng trống, hàng rào đóng đã bị cắt khỏi nguồn), tức ngay sau
        // dòng có nghĩa cuối cùng.
        // `min` với độ dài nguồn là bắt buộc, không phải phòng xa: `offset(ofLineStart:)` cộng
        // một byte xuống dòng cho MỖI dòng, nên với nguồn không kết thúc bằng `\n` nó trả về một
        // vị trí vượt quá cuối văn bản đúng một byte — và `applyEdits` sập ngay tại đó.
        let at = min(offset(ofLineStart: model.insertLine, lines: lines), source.utf8.count)
        // Nguồn không kết thúc bằng xuống dòng thì phải THÊM một cái trước câu lệnh mới, nếu
        // không nó dính vào cuối dòng cuối và làm hỏng cả hai.
        let canXuongDong = model.insertLine >= lines.count
        return TextEdit(range: at ..< at,
                        text: canXuongDong ? "\n" + than : than + "\n")
    }

    static func indent(of source: String) -> String {
        // Bỏ qua dòng khai báo loại (luôn sát mép), chú thích, và dòng đóng khối.
        TextIndent.common(of: source) { line in
            line.hasPrefix("%%") || line == "end" || line == "}" || line.hasSuffix("{")
                || MermaidDiagramKind.named.contains { line.hasPrefix($0.keyword) }
        }
    }

    static func xoaDong(_ dong: Set<Int>, in source: String) -> [TextEdit] {
        let lines = source.components(separatedBy: "\n")
        // Sắp GIẢM DẦN: áp từ cuối lên đầu thì các khoảng phía trước không bị dời.
        return dong.sorted(by: >).compactMap { line in
            guard line < lines.count else { return nil }
            let start = offset(ofLineStart: line, lines: lines)
            let end = start + lines[line].utf8.count
            if line + 1 < lines.count {
                return TextEdit(range: start ..< (end + 1), text: "")   // nuốt luôn xuống dòng
            }
            // Dòng CUỐI không có ký tự xuống dòng để nuốt, nên nuốt cái đứng TRƯỚC nó — trừ khi
            // dòng trước cũng đang bị xoá. Không có vế "trừ khi" ấy thì hai khoảng chồng lên
            // nhau đúng một byte và `applyEdits` sập: đó là cách lỗi này bị bắt.
            if start > 0, !dong.contains(line - 1) {
                return TextEdit(range: (start - 1) ..< end, text: "")
            }
            return TextEdit(range: start ..< end, text: "")
        }
    }

    static func tach(_ line: String) -> (indent: String, content: String) {
        let noiDung = line.drop { $0 == " " || $0 == "\t" }
        return (String(line.prefix(line.count - noiDung.count)), String(noiDung))
    }

    static func offset(ofLineStart line: Int, lines: [String]) -> Int {
        var at = 0
        for i in 0 ..< min(line, lines.count) { at += lines[i].utf8.count + 1 }
        return at
    }

    static func rangeOfLineContent(_ line: Int, lines: [String]) -> Range<Int> {
        let start = offset(ofLineStart: line, lines: lines)
        return start ..< (start + lines[line].utf8.count)
    }

    /// Dời một khoảng tính TRONG một dòng về toạ độ của cả nguồn.
    static func shiftIntoDocument(
        _ range: Range<Int>, line: Int, lines: [String]
    ) -> Range<Int> {
        let base = offset(ofLineStart: line, lines: lines)
        return (base + range.lowerBound) ..< (base + range.upperBound)
    }

    static func escape(_ text: String) -> String {
        // Dấu nháy kép trong nhãn làm vỡ chính cặp nháy bọc nó; mermaid không có ký tự thoát nên
        // thay bằng nháy cong — thứ hiện ra đúng như người dùng gõ.
        text.replacingOccurrences(of: "\"", with: "\u{201D}")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
