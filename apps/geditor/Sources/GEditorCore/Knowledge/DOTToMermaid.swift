import Foundation

/// Chuyển DOT sang Mermaid — ADR-15 §7, nền của FR-KNW-905 và FR-KNW-910.
///
/// ## Phép chuyển này MẤT thông tin, và nó nói ra
///
/// DOT và Mermaid không phủ nhau. Mermaid `flowchart` không có `rankdir` tuỳ ý theo cụm, không
/// có `rank=same`, không có thuộc tính node tuỳ ý, và hình dạng node thì chỉ vài kiểu. Nên bản
/// chuyển giữ đúng thứ vẽ ra được — **cấu trúc**: node, nhãn, cạnh, nhãn cạnh, hướng — và
/// `DOTGraph.warnings` kể ra phần bị bỏ.
///
/// Đó là ranh giới cố ý. Một bản chuyển cố giữ mọi thứ sẽ sinh Mermaid không hợp lệ trên những
/// tệp DOT bình thường, và khi ấy người dùng không xem được gì thay vì xem được phần lớn.
///
/// ## Tên node phải được LÀM SẠCH, và ánh xạ ngược phải giữ lại
///
/// Mermaid không nhận mọi ký tự trong định danh node. Nên tên được làm sạch thành `n0`, `n1`, …
/// và bản đồ `mermaidID → tên DOT` trả về cùng — không có nó thì bấm một node trên hình sẽ
/// không tìm về được dòng nào trong tệp DOT.
public enum DOTToMermaid {

    public struct Converted: Equatable, Sendable {
        public var mermaid: String
        /// `id mermaid` → tên node trong DOT.
        public var identifiers: [String: String]
        /// Chữ hiện trên node → tên node trong DOT. Dùng cho đường bấm-node của FR-MMD-002,
        /// vốn nhận diện phần tử bằng CHỮ hiện trên nó chứ không bằng id.
        public var displayToName: [String: String]
        public var warnings: [String]
    }

    /// Hình dạng DOT → cặp dấu bao của Mermaid.
    ///
    /// Chỉ ánh xạ những hình có nghĩa TƯƠNG ĐƯƠNG. `diamond` → `{}` (quyết định), `ellipse`/
    /// `circle` → `(())`, `box`/`rect` → `[]`. Hình lạ rơi về `[]` chứ không bịa: một `box3d`
    /// vẽ thành hình thoi sẽ đổi NGHĨA của sơ đồ.
    static let shapes: [String: (open: String, close: String)] = [
        "box": ("[", "]"), "rect": ("[", "]"), "rectangle": ("[", "]"), "square": ("[", "]"),
        "diamond": ("{", "}"),
        "ellipse": ("((", "))"), "circle": ("((", "))"), "oval": ("((", "))"),
        "doublecircle": ("(((", ")))"),
        "cylinder": ("[(", ")]"),
        "parallelogram": ("[/", "/]"),
        "hexagon": ("{{", "}}"),
    ]

    /// Kiểu vẽ cho từng node, khoá theo TÊN node trong DOT — FR-KNW-914 tô màu ngược lên hình.
    ///
    /// Giá trị là phần sau `style nX` của Mermaid, ví dụ `fill:#cfe,stroke-width:4px`.
    public typealias NodeStyles = [String: String]

    public static func convert(
        _ graph: DOTGraph, direction: String = "TD", styles: NodeStyles = [:]
    ) -> Converted {
        var lines = ["flowchart \(direction)"]
        var identifiers: [String: String] = [:]
        var displayToName: [String: String] = [:]
        var idOf: [String: String] = [:]

        for (position, node) in graph.nodes.enumerated() {
            let identifier = "n\(position)"
            idOf[node.name] = identifier
            identifiers[identifier] = node.name
            // Chữ hiện trên node là chỗ đường bấm-node nhận diện phần tử. Hai node cùng chữ
            // thì cùng sáng — giới hạn ấy đã có từ FR-MMD-002 và không mới ở đây.
            displayToName[node.display] = node.name
            let shape = shapes[(node.shape ?? "box").lowercased()] ?? ("[", "]")
            lines.append("    \(identifier)\(shape.open)\"\(escape(node.display))\"\(shape.close)")
        }

        let arrow = graph.isDirected ? "-->" : "---"
        for edge in graph.edges {
            guard let from = idOf[edge.from], let to = idOf[edge.to] else { continue }
            if let label = edge.label, !label.isEmpty {
                lines.append("    \(from) \(arrow)|\"\(escape(label))\"| \(to)")
            } else {
                lines.append("    \(from) \(arrow) \(to)")
            }
        }

        // Kiểu vẽ đặt SAU mọi khai báo, theo thứ tự node — Mermaid đọc `style` ở đâu cũng
        // được, nhưng thứ tự cố định giữ cho hai lượt dựng cho ra cùng một chuỗi (tất định).
        for (position, node) in graph.nodes.enumerated() {
            guard let style = styles[node.name], !style.isEmpty else { continue }
            lines.append("    style n\(position) \(style)")
        }

        var warnings = graph.warnings.map { "dòng \($0.line + 1): \($0.message)" }
        if graph.nodes.isEmpty {
            warnings.append("không đọc được node nào — kiểm lại cú pháp DOT")
        }
        return Converted(
            mermaid: lines.joined(separator: "\n"), identifiers: identifiers,
            displayToName: displayToName, warnings: warnings)
    }

    /// Nhãn nằm trong `"…"` của Mermaid, nên dấu nháy kép phải đi ra.
    ///
    /// Mermaid không có cú pháp thoát bên trong nhãn có nháy; nó chỉ đọc tới dấu nháy kế tiếp.
    /// Nên đổi `"` thành `'` — mất một chút hình thức, đổi lấy một sơ đồ vẽ được. Dấu `#` bị
    /// đổi vì Mermaid coi `#nnn;` là thực thể HTML.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "#", with: "＃")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
