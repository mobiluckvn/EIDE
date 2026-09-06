import Foundation

/// Schema / ontology cho đồ thị tri thức — FR-KNW-917.
///
/// ## Vì sao schema là YAML rời chứ không phải khối trong file đồ thị
///
/// Một schema sống lâu hơn bất kỳ file đồ thị nào dùng nó: cùng một ontology dùng lại cho hàng
/// chục lượt trích xuất. Nhét nó vào file `.dot` nghĩa là mỗi lần sinh lại đồ thị là một lần
/// phải chép tay schema sang, và chép tay thì hai bản trôi khỏi nhau.
///
/// ## Ba loại lỗi, và vì sao chúng KHÔNG gộp làm một
///
/// Đặc tả gọi tên ba loại: *"cạnh sai loại, thiếu thuộc tính, node không khai báo"*. Chúng khác
/// nhau ở việc **ai phải sửa gì**:
///
/// - *node không khai báo* — hoặc dữ liệu sai nhãn, hoặc schema thiếu một loại. Người sửa phải
///   quyết định cái nào, nên lỗi phải nói ra nhãn nó thấy.
/// - *cạnh sai loại* — quan hệ này không được phép giữa hai loại ấy. Đây là lỗi MÔ HÌNH, thường
///   là dấu hiệu bộ trích xuất nối nhầm.
/// - *thiếu thuộc tính* — dữ liệu thiếu, schema đúng. Sửa ở nguồn.
///
/// Gộp ba loại thành "vi phạm schema: 47" là lấy đi đúng thông tin người sửa cần.
///
/// ## Mọi lỗi mang SỐ DÒNG
///
/// Đặc tả đòi *"click nhảy đúng dòng định nghĩa"*. `DOTGraph.Node` và `.Edge` đều giữ `line`,
/// nên số dòng đi thẳng từ chỗ đọc tới chỗ báo — không phải dò lại bằng cách tìm chuỗi, cách
/// vốn sai ngay khi hai node trùng tên nhau ở hai chỗ.
public struct GraphSchema: Equatable, Sendable {

    /// Một loại node được khai báo.
    public struct NodeType: Equatable, Sendable {
        public let name: String
        /// Thuộc tính bắt buộc → kiểu (`string`, `number`, `boolean`; rỗng = không kiểm kiểu).
        public let required: [(String, String)]

        public static func == (a: NodeType, b: NodeType) -> Bool {
            a.name == b.name && a.required.count == b.required.count
                && zip(a.required, b.required).allSatisfy { $0 == $1 }
        }
    }

    /// Một loại cạnh, kèm những cặp loại nó được phép nối.
    public struct EdgeType: Equatable, Sendable {
        public let name: String
        /// Cặp `(loại nguồn, loại đích)` hợp lệ. Rỗng = cho phép mọi cặp.
        public let between: [(String, String)]
        public let required: [(String, String)]

        public static func == (a: EdgeType, b: EdgeType) -> Bool {
            a.name == b.name && a.between.count == b.between.count
                && zip(a.between, b.between).allSatisfy { $0 == $1 }
                && a.required.count == b.required.count
                && zip(a.required, b.required).allSatisfy { $0 == $1 }
        }
    }

    public let nodeTypes: [NodeType]
    public let edgeTypes: [EdgeType]
    /// Thuộc tính mang LOẠI của node trong file đồ thị. Mặc định `type`.
    public let typeAttribute: String

    /// Một vi phạm.
    public struct Violation: Equatable, Sendable {
        public enum Kind: String, Equatable, Sendable {
            case unknownNodeType
            case unknownEdgeType
            case edgeBetweenWrongTypes
            case missingProperty
            case wrongPropertyType

            public var displayName: String {
                switch self {
                case .unknownNodeType: return "Node không khai báo"
                case .unknownEdgeType: return "Cạnh không khai báo"
                case .edgeBetweenWrongTypes: return "Cạnh sai loại"
                case .missingProperty: return "Thiếu thuộc tính"
                case .wrongPropertyType: return "Sai kiểu dữ liệu"
                }
            }
        }

        public let kind: Kind
        /// Dòng trong file đồ thị, **0-BASED** — kế thừa nguyên quy ước của `DOTGraph.Node.line`.
        ///
        /// Ghi rõ ở đây vì `DOTGraph` KHÔNG ghi, và một quy ước không được ghi là cách lỗi "bấm
        /// nhảy lệch một dòng" ra đời: tầng giao diện quen với số dòng 1-based của `TextBuffer`
        /// sẽ cộng nhầm, và triệu chứng là con nháy luôn đậu trên dòng ngay trước chỗ sai —
        /// đủ gần để trông như đúng, đủ sai để dẫn người dùng sửa nhầm chỗ.
        ///
        /// Chính bài kiểm của mã này đã đoán nhầm 1-based ở bản đầu và đỏ, nên nó không phải
        /// một lo xa.
        public let line: Int
        public let subject: String
        public let detail: String
    }

    // MARK: - Đọc schema

    public struct Failure: Error, Equatable {
        public let reason: String
    }

    /// Đọc schema từ YAML.
    ///
    /// Khoá lạ ở tầng gốc bị **TỪ CHỐI**, không bỏ qua. Một schema là tệp quyết định "đồ thị này
    /// có đạt chuẩn không"; gõ nhầm `node_type:` thay vì `node_types:` mà bị im lặng bỏ qua thì
    /// kết quả là "không có vi phạm nào" — câu trả lời sai theo đúng hướng nguy hiểm nhất.
    public static func parse(_ text: String) throws -> GraphSchema {
        let root = try YAMLReader.parse(text)
        guard case let .mapping(pairs) = root else {
            throw Failure(reason: "schema phải là một mapping ở tầng gốc")
        }
        var nodeTypes: [NodeType] = []
        var edgeTypes: [EdgeType] = []
        var typeAttribute = "type"

        for (key, value) in pairs {
            switch key {
            case "type_attribute":
                if case let .scalar(s) = value { typeAttribute = s }
            case "node_types":
                nodeTypes = try types(from: value).map {
                    NodeType(name: $0.0, required: $0.2)
                }
            case "edge_types":
                edgeTypes = try types(from: value).map {
                    EdgeType(name: $0.0, between: $0.1, required: $0.2)
                }
            default:
                throw Failure(reason: "khoá lạ ở tầng gốc: «\(key)»")
            }
        }
        guard !nodeTypes.isEmpty || !edgeTypes.isEmpty else {
            throw Failure(reason: "schema không khai loại nào")
        }
        return GraphSchema(nodeTypes: nodeTypes, edgeTypes: edgeTypes,
                           typeAttribute: typeAttribute)
    }

    /// `(tên, cặp between, thuộc tính bắt buộc)`
    private static func types(
        from value: YAMLValue
    ) throws -> [(String, [(String, String)], [(String, String)])] {
        guard case let .mapping(items) = value else {
            throw Failure(reason: "danh sách loại phải là mapping «tên: {…}»")
        }
        return try items.map { name, body in
            var between: [(String, String)] = []
            var required: [(String, String)] = []
            if case let .mapping(fields) = body {
                for (field, content) in fields {
                    switch field {
                    case "between":
                        guard case let .sequence(cap) = content else {
                            throw Failure(reason: "«between» của «\(name)» phải là danh sách")
                        }
                        for muc in cap {
                            guard case let .sequence(doi) = muc, doi.count == 2,
                                  case let .scalar(a) = doi[0], case let .scalar(b) = doi[1]
                            else {
                                throw Failure(
                                    reason: "mỗi mục «between» của «\(name)» phải là [nguồn, đích]")
                            }
                            between.append((a, b))
                        }
                    case "required":
                        guard case let .mapping(thuoc) = content else {
                            throw Failure(reason: "«required» của «\(name)» phải là mapping")
                        }
                        for (ten, kieu) in thuoc {
                            if case let .scalar(k) = kieu { required.append((ten, k)) }
                            else { required.append((ten, "")) }
                        }
                    default:
                        throw Failure(reason: "khoá lạ trong «\(name)»: «\(field)»")
                    }
                }
            }
            return (name, between, required)
        }
    }

    // MARK: - Kiểm đồ thị

    /// Kiểm toàn đồ thị. Trả về vi phạm theo SỐ DÒNG tăng dần — tất định, và đọc xuôi theo file.
    public func validate(_ graph: DOTGraph) -> [Violation] {
        var out: [Violation] = []
        let nodeByName = Dictionary(graph.nodes.map { ($0.name, $0) },
                                    uniquingKeysWith: { a, _ in a })
        let nodeTypeByName = Dictionary(nodeTypes.map { ($0.name, $0) },
                                        uniquingKeysWith: { a, _ in a })
        let edgeTypeByName = Dictionary(edgeTypes.map { ($0.name, $0) },
                                        uniquingKeysWith: { a, _ in a })

        func loai(_ node: DOTGraph.Node?) -> String? {
            node?.attributes[typeAttribute]
        }

        for node in graph.nodes {
            guard let ten = loai(node) else {
                out.append(Violation(kind: .unknownNodeType, line: node.line, subject: node.name,
                                     detail: "không có thuộc tính «\(typeAttribute)»"))
                continue
            }
            guard let khai = nodeTypeByName[ten] else {
                out.append(Violation(kind: .unknownNodeType, line: node.line, subject: node.name,
                                     detail: "loại «\(ten)» không có trong schema"))
                continue
            }
            out += kiemThuocTinh(khai.required, node.attributes, line: node.line,
                                 subject: node.name)
        }

        for edge in graph.edges {
            let ten = edge.attributes[typeAttribute] ?? edge.label
            guard let ten else {
                out.append(Violation(kind: .unknownEdgeType, line: edge.line,
                                     subject: "\(edge.from) → \(edge.to)",
                                     detail: "cạnh không có loại"))
                continue
            }
            guard let khai = edgeTypeByName[ten] else {
                out.append(Violation(kind: .unknownEdgeType, line: edge.line,
                                     subject: "\(edge.from) → \(edge.to)",
                                     detail: "loại cạnh «\(ten)» không có trong schema"))
                continue
            }
            out += kiemThuocTinh(khai.required, edge.attributes, line: edge.line,
                                 subject: "\(edge.from) → \(edge.to)")

            // `between` rỗng nghĩa là "mọi cặp" — KHÔNG phải "không cặp nào". Hiểu ngược lại thì
            // một schema chưa khai quan hệ nào sẽ báo mọi cạnh đều sai, và người dùng tắt hẳn
            // tính năng thay vì sửa schema.
            guard !khai.between.isEmpty else { continue }
            let tuLoai = loai(nodeByName[edge.from])
            let denLoai = loai(nodeByName[edge.to])
            let hopLe = khai.between.contains { $0.0 == tuLoai && $0.1 == denLoai }
            if !hopLe {
                out.append(Violation(
                    kind: .edgeBetweenWrongTypes, line: edge.line,
                    subject: "\(edge.from) → \(edge.to)",
                    detail: "«\(ten)» không nối được \(tuLoai ?? "?") → \(denLoai ?? "?")"))
            }
        }

        return out.sorted { ($0.line, $0.subject) < ($1.line, $1.subject) }
    }

    private func kiemThuocTinh(
        _ required: [(String, String)], _ attributes: [String: String],
        line: Int, subject: String
    ) -> [Violation] {
        var out: [Violation] = []
        for (ten, kieu) in required {
            guard let gia_tri = attributes[ten], !gia_tri.isEmpty else {
                out.append(Violation(kind: .missingProperty, line: line, subject: subject,
                                     detail: "thiếu «\(ten)»"))
                continue
            }
            guard !kieu.isEmpty, !Self.hopKieu(gia_tri, kieu) else { continue }
            out.append(Violation(kind: .wrongPropertyType, line: line, subject: subject,
                                 detail: "«\(ten)» phải là \(kieu), đang là «\(gia_tri)»"))
        }
        return out
    }

    /// Kiểu kiểm ở mức GIÁ TRỊ ĐỌC ĐƯỢC, không ở mức khai báo.
    ///
    /// Thuộc tính trong DOT luôn là chuỗi, nên "number" nghĩa là *chuỗi này đọc ra số được*.
    /// Đòi hơn thế là đòi một hệ kiểu mà định dạng nguồn không có.
    static func hopKieu(_ value: String, _ kieu: String) -> Bool {
        switch kieu.lowercased() {
        case "string", "text": return true
        case "number", "int", "integer", "float", "double": return Double(value) != nil
        case "boolean", "bool": return ["true", "false", "yes", "no", "1", "0"]
            .contains(value.lowercased())
        default: return true      // kiểu lạ thì KHÔNG phán — im lặng đúng hơn đoán bừa.
        }
    }

    /// Template cho một KG phổ biến — đặc tả đòi *"kèm template schema mẫu"*.
    ///
    /// Chọn hình dạng người–tổ chức–địa điểm vì đó là bộ ba mà gần như mọi lượt trích xuất tiếng
    /// Việt bắt đầu từ đó. Template phải CHẠY ĐƯỢC ngay, không phải một khung rỗng: một mẫu phải
    /// sửa mới dùng được thì người ta bỏ qua và tự gõ từ đầu.
    public static let template = """
        # Schema đồ thị tri thức — FR-KNW-917
        #
        # `type_attribute` là tên thuộc tính mang LOẠI của node trong file .dot.
        type_attribute: type

        node_types:
          Person:
            required:
              name: string
          Organization:
            required:
              name: string
          Location:
            required:
              name: string

        edge_types:
          works_at:
            between:
              - [Person, Organization]
          located_in:
            # Một quan hệ dùng được cho nhiều cặp thì kê đủ các cặp.
            between:
              - [Organization, Location]
              - [Person, Location]
          # Không khai `between` nghĩa là CHO PHÉP MỌI CẶP, không phải cấm tất.
          related_to: {}
        """
}
