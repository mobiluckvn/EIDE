import Foundation

/// Soạn thảo đồ thị trực quan — FR-KNW-915.
///
/// Đặc tả: *"thêm node/cạnh (kéo từ node nguồn), sửa nhãn/thuộc tính (double-click), xóa — MỌI
/// thao tác sinh chỉnh sửa văn bản tương ứng qua applyEdits (mỗi thao tác một bước undo), tôn
/// trọng format/thụt lề hiện hành của file. Buffer văn bản vẫn là NGUỒN SỰ THẬT DUY NHẤT —
/// preview chỉ là projection hai chiều."*
///
/// ## Buffer là nguồn sự thật, và điều đó quyết định cả kiểu trả về
///
/// Không hàm nào ở đây sửa gì. Chúng trả `[TextEdit]` để chỗ gọi áp bằng `applyEdits` — một
/// lần, một bước undo. Nếu chúng sửa một `DOTGraph` rồi mới sinh văn bản thì đồ thị trong bộ nhớ
/// đã thành nguồn sự thật thứ hai, và hai nguồn sự thật là hai chỗ để lệch nhau.
///
/// Đây là cùng khuôn `GraphRefactor` (FR-KNW-916) đã đặt, và dùng lại nó có chủ ý: hai bộ sinh
/// sửa đổi cho cùng một định dạng là đúng mẫu lỗi kho này đã gặp bốn lần.
///
/// ## Sửa TẠI CHỖ, không viết lại cả tệp
///
/// Tệp của người dùng có chú thích, thứ tự riêng, và những thuộc tính bộ đọc chưa hiểu. Dựng lại
/// toàn bộ DOT từ `DOTGraph` là xoá hết chúng — và một công cụ soạn thảo làm mất chú thích thì
/// không ai dùng lần thứ hai.
public enum GraphEdit {

    public struct Failure: Error, Equatable {
        public let reason: String
    }

    // MARK: - Thụt lề

    /// Thụt lề của các câu lệnh bên trong `{ … }`, đọc từ chính tệp.
    ///
    /// Thuật toán nằm ở `TextIndent` — dùng chung với `MermaidEdit`; ở đây chỉ khai *dòng nào
    /// của DOT không được tính*: chú thích, và dòng mở/đóng khối vốn thụt ở một cấp khác.
    static func indent(of text: String) -> String {
        TextIndent.common(of: text) {
            $0.hasPrefix("//") || $0.hasPrefix("#") || $0.hasPrefix("}") || $0.contains("{")
        }
    }

    /// Vị trí BYTE để chèn một câu lệnh mới: ngay trước dấu `}` cuối cùng.
    ///
    /// Trả `nil` khi tệp không có dấu đóng — chèn vào một tệp DOT dở dang là làm nó dở hơn, và
    /// người dùng sẽ không hiểu vì sao câu lệnh của họ nằm ngoài đồ thị.
    static func insertionPoint(in text: String) -> Int? {
        guard let i = text.lastIndex(of: "}") else { return nil }
        return text.utf8.distance(from: text.utf8.startIndex, to: i.samePosition(in: text.utf8)!)
    }

    // MARK: - Thêm

    /// Thêm một node. `label` rỗng thì không ghi thuộc tính `label`.
    public static func addNode(
        name: String, label: String? = nil, in text: String
    ) throws -> [TextEdit] {
        try guardName(name)
        guard let at = insertionPoint(in: text) else {
            throw Failure(reason: "tệp không có dấu «}» đóng đồ thị")
        }
        if DOTGraph.parse(text).nodes.contains(where: { $0.name == name }) {
            throw Failure(reason: "đã có node tên «\(name)»")
        }
        let thuoc_tinh = label.map { " [label=\"\(escape($0))\"]" } ?? ""
        return [TextEdit(range: at ..< at,
                         text: "\(indent(of: text))\"\(escape(name))\"\(thuoc_tinh);\n")]
    }

    /// Thêm một cạnh — thao tác "kéo từ node nguồn" của đặc tả.
    ///
    /// KHÔNG tự tạo node còn thiếu. DOT cho phép một cạnh nhắc tới node chưa khai và tự sinh nó,
    /// nhưng ở đây người dùng đang kéo từ một node họ NHÌN THẤY tới một node họ NHÌN THẤY — nếu
    /// một trong hai không có thật thì đó là lỗi của chỗ gọi, và im lặng tạo node mới sẽ giấu nó.
    public static func addEdge(
        from: String, to: String, label: String? = nil, in text: String
    ) throws -> [TextEdit] {
        try guardName(from); try guardName(to)
        let graph = DOTGraph.parse(text)
        for ten in [from, to] where !graph.nodes.contains(where: { $0.name == ten }) {
            throw Failure(reason: "không có node «\(ten)»")
        }
        guard let at = insertionPoint(in: text) else {
            throw Failure(reason: "tệp không có dấu «}» đóng đồ thị")
        }
        let mui = graph.isDirected ? "->" : "--"
        let thuoc_tinh = label.map { " [label=\"\(escape($0))\"]" } ?? ""
        return [TextEdit(
            range: at ..< at,
            text: "\(indent(of: text))\"\(escape(from))\" \(mui) \"\(escape(to))\"\(thuoc_tinh);\n")]
    }

    // MARK: - Sửa

    /// Đổi nhãn một node — thao tác "double-click" của đặc tả.
    ///
    /// Node ĐÃ có `label` thì thay đúng giá trị ấy; chưa có thì chèn thêm thuộc tính. Hai đường
    /// khác nhau vì thay một thuộc tính không tồn tại sẽ không khớp gì cả và phép sửa im lặng
    /// không làm gì.
    public static func setLabel(
        of node: String, to label: String, in text: String
    ) throws -> [TextEdit] {
        let graph = DOTGraph.parse(text)
        guard let target = graph.nodes.first(where: { $0.name == node }) else {
            throw Failure(reason: "không có node «\(node)»")
        }
        let bytes = Array(text.utf8)
        guard let dong = dongCuaKhai(node: target, in: graph, bytes: bytes, text: text) else {
            throw Failure(reason: "node «\(node)» không có câu lệnh khai riêng — chưa sửa nhãn được")
        }
        let noiDung = String(decoding: bytes[dong], as: UTF8.self)

        if let r = noiDung.range(of: #"label\s*=\s*"[^"]*""#, options: .regularExpression) {
            let start = dong.lowerBound + noiDung.utf8.distance(
                from: noiDung.utf8.startIndex, to: r.lowerBound.samePosition(in: noiDung.utf8)!)
            let end = dong.lowerBound + noiDung.utf8.distance(
                from: noiDung.utf8.startIndex, to: r.upperBound.samePosition(in: noiDung.utf8)!)
            return [TextEdit(range: start ..< end, text: "label=\"\(escape(label))\"")]
        }
        // Chưa có `[...]` thì chèn cả khối; có rồi thì chèn vào ngay sau dấu `[`.
        if let i = noiDung.firstIndex(of: "[") {
            let at = dong.lowerBound + noiDung.utf8.distance(
                from: noiDung.utf8.startIndex, to: noiDung.utf8.index(after: i.samePosition(in: noiDung.utf8)!))
            return [TextEdit(range: at ..< at, text: "label=\"\(escape(label))\", ")]
        }
        guard let semi = noiDung.lastIndex(of: ";") else {
            throw Failure(reason: "câu lệnh khai node «\(node)» không kết thúc bằng «;»")
        }
        let at = dong.lowerBound + noiDung.utf8.distance(
            from: noiDung.utf8.startIndex, to: semi.samePosition(in: noiDung.utf8)!)
        return [TextEdit(range: at ..< at, text: " [label=\"\(escape(label))\"]")]
    }

    // MARK: - Xoá

    /// Xoá một node VÀ mọi cạnh chạm tới nó.
    ///
    /// Bỏ sót phần cạnh là để lại cạnh treo — mà DOT sẽ tự sinh lại node từ chính những cạnh ấy,
    /// nên node "đã xoá" hiện lại ngay lần vẽ sau. Người dùng bấm Xoá, thấy nó biến mất, rồi thấy
    /// nó quay về: đúng loại hỏng khiến người ta mất tin vào công cụ.
    public static func removeNode(_ name: String, in text: String) throws -> [TextEdit] {
        let graph = DOTGraph.parse(text)
        guard graph.nodes.contains(where: { $0.name == name }) else {
            throw Failure(reason: "không có node «\(name)»")
        }
        let bytes = Array(text.utf8)
        var xoa: [Range<Int>] = []
        if let node = graph.nodes.first(where: { $0.name == name }),
           let dong = dongCuaKhai(node: node, in: graph, bytes: bytes, text: text) {
            xoa.append(dong)
        }
        for edge in graph.edges where edge.from == name || edge.to == name {
            if let dong = dongCua(line: edge.line, bytes: bytes) { xoa.append(dong) }
        }
        // Gộp và sắp GIẢM DẦN: hai cạnh có thể nằm cùng một dòng, và áp từ cuối lên đầu thì các
        // khoảng phía trước không bị dời.
        var duy_nhat: [Range<Int>] = []
        for r in xoa.sorted(by: { $0.lowerBound > $1.lowerBound }) where !duy_nhat.contains(r) {
            duy_nhat.append(r)
        }
        return duy_nhat.map { TextEdit(range: $0, text: "") }
    }

    /// Xoá một cạnh. Node hai đầu KHÔNG bị đụng tới.
    public static func removeEdge(from: String, to: String, in text: String) throws -> [TextEdit] {
        let graph = DOTGraph.parse(text)
        let bytes = Array(text.utf8)
        let khop = graph.edges.filter { $0.from == from && $0.to == to }
        guard !khop.isEmpty else {
            throw Failure(reason: "không có cạnh «\(from)» → «\(to)»")
        }
        var out: [TextEdit] = []
        for edge in khop.sorted(by: { $0.line > $1.line }) {
            if let dong = dongCua(line: edge.line, bytes: bytes) {
                out.append(TextEdit(range: dong, text: ""))
            }
        }
        return out
    }

    // MARK: - Từ HÌNH về TÊN

    /// Chữ người dùng bấm trên hình → **tên** node trong văn bản.
    ///
    /// Cần một phép đổi riêng vì hai thứ ấy khác nhau: hình vẽ hiện `label`, còn mọi phép ở đây
    /// sửa `name`. Nhầm hai thứ thì một cú double-click vào «An» đi tìm node tên «An» và không
    /// thấy, trong khi node ấy tên `a`.
    ///
    /// Tên khớp ĐÚNG thì thắng trước — một tệp có node tên `a` và một node khác nhãn `a` thì
    /// định danh phải thắng nhãn. Còn **hai node cùng nhãn thì NÓI RA**, không lấy cái đầu tiên:
    /// ở chỗ nhảy con nháy thì đoán sai chỉ tốn một lần cuộn, còn ở đây đoán sai là sửa nhầm
    /// node — và người dùng thấy đúng cái node họ vừa bấm vẫn y nguyên.
    public static func resolveNode(_ text: String, in graph: DOTGraph) throws -> String {
        let can = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !can.isEmpty else { throw Failure(reason: "chưa chọn node nào") }
        if graph.nodes.contains(where: { $0.name == can }) { return can }
        let khop = graph.nodes.filter { $0.display == can }
        guard let dau = khop.first else {
            throw Failure(reason: "không có node nào tên hay mang nhãn «\(can)»")
        }
        guard khop.count == 1 else {
            throw Failure(reason: "có \(khop.count) node cùng mang nhãn «\(can)» "
                + "(\(khop.map(\.name).joined(separator: ", "))) — sửa trong văn bản để chỉ rõ")
        }
        return dau.name
    }

    // MARK: - Phụ

    /// Khoảng BYTE của cả một dòng, kể cả ký tự xuống dòng.
    static func dongCua(line: Int, bytes: [UInt8]) -> Range<Int>? {
        var start = 0
        var dem = 0
        var i = 0
        while i < bytes.count {
            if dem == line { start = i; break }
            if bytes[i] == 0x0A { dem += 1 }
            i += 1
        }
        guard dem == line else { return nil }
        var end = start
        while end < bytes.count, bytes[end] != 0x0A { end += 1 }
        if end < bytes.count { end += 1 }
        return start ..< end
    }

    /// Dòng khai của một node — chỉ khi nó có câu lệnh khai RIÊNG.
    ///
    /// `DOTGraph` tự sinh node khi nó xuất hiện trong một cạnh, và những node ấy không có dòng
    /// nào để sửa. Trả `nil` để chỗ gọi nói ra thay vì sửa nhầm dòng cạnh.
    static func dongCuaKhai(
        node: DOTGraph.Node, in graph: DOTGraph, bytes: [UInt8], text: String
    ) -> Range<Int>? {
        guard let dong = dongCua(line: node.line, bytes: bytes) else { return nil }
        let noiDung = String(decoding: bytes[dong], as: UTF8.self)
        // Dòng có mũi tên là dòng CẠNH, không phải dòng khai node.
        guard !noiDung.contains("->"), !noiDung.contains("--") else { return nil }
        return dong
    }

    /// Tên node không được chứa dấu nháy hay xuống dòng — chúng làm vỡ cú pháp DOT.
    static func guardName(_ name: String) throws {
        guard !name.isEmpty else { throw Failure(reason: "tên node rỗng") }
        guard !name.contains("\n"), !name.contains("\"") else {
            throw Failure(reason: "tên node «\(name)» chứa ký tự làm vỡ cú pháp DOT")
        }
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
