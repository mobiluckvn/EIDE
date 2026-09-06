import Foundation

/// Grammar tô màu cho tệp `.mmd` — FR-MMD-006, dựng trên hạ tầng FR-FMT-502.
///
/// ## Vì sao dùng UDL chứ không viết grammar tree-sitter
///
/// `UserDefinedLanguage` là bộ quét TỪ VỰNG theo bảng: từ khoá, chuỗi, chú thích. Nó không hiểu
/// cấu trúc lồng nhau — và với Mermaid thì đó gần như đủ, vì cú pháp Mermaid **không có cấu trúc
/// lồng sâu**: một dòng khai báo, các dòng nội dung, vài khối `subgraph … end`. Thứ người đọc
/// cần phân biệt là *từ khoá / nhãn trong nháy / chú thích*, đúng ba thứ UDL làm được.
///
/// Đổi lại là một grammar tree-sitter cho mười một loại sơ đồ — một dự án riêng, phải build
/// riêng, và phải nuôi theo mỗi bản mermaid mới. Cái giá ấy đổi lấy gấp khối theo cú pháp và
/// danh sách hàm, hai thứ một tệp sơ đồ ba mươi dòng không cần.
///
/// ## Grammar DỰNG SẴN nhưng vẫn nhường tệp của người dùng
///
/// Nó được nối vào CUỐI danh sách `userLanguages`, nên một tệp `grammars/mermaid.json` do người
/// dùng tự viết sẽ thắng. Cùng luật với mọi thứ khác trong `grammars/`: tệp của họ là của họ.
public enum MermaidGrammar {

    public static let language = UserDefinedLanguage(
        name: "Mermaid",
        extensions: [MermaidDocument.fileExtension],
        keywordGroups: [
            // Nhóm `keyword`: từ MỞ ĐẦU một sơ đồ hoặc một khối. Đây là thứ người đọc dùng để
            // định vị mình đang ở đâu trong tệp.
            "keyword": [
                "flowchart", "graph", "sequenceDiagram", "classDiagram", "stateDiagram",
                "stateDiagram-v2", "erDiagram", "gantt", "pie", "mindmap", "timeline",
                "quadrantChart", "gitGraph", "journey", "requirementDiagram",
                "subgraph", "end", "alt", "else", "opt", "loop", "par", "and", "critical",
                "break", "rect", "box", "namespace", "state", "class", "note", "over",
                "section", "title", "direction", "activate", "deactivate", "autonumber",
                "commit", "branch", "checkout", "merge", "cherry-pick",
            ],
            // Nhóm `type`: từ khai một THỰC THỂ hoặc một thuộc tính của nó.
            "type": [
                "participant", "actor", "dateFormat", "axisFormat", "excludes",
                "todayMarker", "tickInterval", "root", "x-axis", "y-axis",
                "quadrant-1", "quadrant-2", "quadrant-3", "quadrant-4",
                "accTitle", "accDescr", "classDef", "linkStyle", "style", "click",
            ],
            // Nhóm `constant`: giá trị và cờ.
            "constant": [
                "TD", "TB", "BT", "LR", "RL", "showData",
                "done", "active", "crit", "milestone", "after",
                "PK", "FK", "UK", "id", "tag", "type",
            ],
        ],
        caseSensitive: true,
        // `%%` là chú thích tới hết dòng. Chỉ thị `%%{ … }%%` cũng bắt đầu bằng `%%`, nên nó
        // được tô như chú thích — đúng về mặt đọc: nó là siêu dữ liệu, không phải nội dung sơ đồ.
        lineComment: "%%",
        blockComment: nil,
        // Chỉ dấu nháy KÉP. Nháy đơn KHÔNG mở chuỗi trong Mermaid, và nhận nhầm nó sẽ tô sai từ
        // chỗ có dấu nháy đơn tới hết tệp — mà tiếng Việt viết `Nguyễn Văn A's` thì hiếm, nhưng
        // `don't` trong một nhãn tiếng Anh thì không hiếm chút nào.
        stringDelimiters: ["\""],
        escapeCharacter: "")
}
