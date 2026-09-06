import Foundation

/// Một mẫu sơ đồ hoặc một mẩu cú pháp — FR-MMD-005.
public struct MermaidTemplate: Equatable, Sendable {

    public enum Scope: Equatable, Sendable {
        /// Cả một sơ đồ hoàn chỉnh — chèn vào tài liệu là chạy được ngay.
        case diagram
        /// Một mẩu cú pháp, chèn vào GIỮA một sơ đồ đang có.
        case fragment
    }

    public var kind: MermaidDiagramKind
    public var scope: Scope
    /// Tên hiện trong danh sách, tiếng Việt.
    public var title: String
    /// Một câu nói mẫu này dùng khi nào.
    public var summary: String
    public var source: String

    public init(
        kind: MermaidDiagramKind, scope: Scope = .diagram, title: String, summary: String,
        source: String
    ) {
        self.kind = kind
        self.scope = scope
        self.title = title
        self.summary = summary
        self.source = source
    }
}

/// Thư viện mẫu, mẩu cú pháp và từ khoá Mermaid — FR-MMD-005.
///
/// ## Nhãn trong mẫu viết bằng TIẾNG VIỆT, và đó là yêu cầu chứ không phải sở thích
///
/// Đặc tả viết *"có bản tiếng Việt"*. Một mẫu `A[Start] --> B[End]` thì người dùng phải sửa cả
/// hai nhãn trước khi dùng được, và cái mẫu ấy chỉ tiết kiệm được mấy dấu ngoặc. Mẫu có nhãn
/// tiếng Việt thì chèn xong đã là một sơ đồ đọc được, và người dùng sửa nội dung chứ không sửa
/// ngôn ngữ.
///
/// **Từ khoá thì KHÔNG dịch** — `flowchart`, `participant`, `classDiagram` là cú pháp của
/// mermaid. Dịch chúng là sinh ra một tệp không chạy.
///
/// ## Vì sao thư viện nằm ở LÕI
///
/// Nó là dữ liệu thuần và có luật riêng (mỗi loại phải có ít nhất một mẫu; mẫu phải PHÂN TÍCH
/// RA đúng loại nó khai). Ở lõi thì bài kiểm đọc được luật ấy mà không cần dựng cửa sổ — và có
/// một bài đúng như thế bên dưới: nó chạy `MermaidDocument.declaration` trên từng mẫu.
public enum MermaidLibrary {

    // MARK: - Mẫu cả sơ đồ

    public static let templates: [MermaidTemplate] = diagramTemplates + fragments

    public static func templates(for kind: MermaidDiagramKind) -> [MermaidTemplate] {
        templates.filter { $0.kind == kind }
    }

    /// Đúng một mẫu đầy đủ cho mỗi loại FR-MMD-001 kê tên.
    public static let diagramTemplates: [MermaidTemplate] = [
        MermaidTemplate(
            kind: .flowchart, title: "Lưu đồ quy trình duyệt",
            summary: "Nhánh có/không, thường dùng cho quy trình phê duyệt.",
            source: """
                flowchart TD
                  A[Nhận hồ sơ] --> B{Đủ giấy tờ?}
                  B -->|Đủ| C[Thẩm định]
                  B -->|Thiếu| D[Trả lại bổ sung]
                  C --> E{Đạt?}
                  E -->|Đạt| F[Phê duyệt]
                  E -->|Không đạt| D
                """),
        MermaidTemplate(
            kind: .sequence, title: "Tuần tự — người dùng và hệ thống",
            summary: "Ai gọi ai, theo thứ tự thời gian.",
            source: """
                sequenceDiagram
                  actor ND as Người dùng
                  participant App
                  participant CSDL as Cơ sở dữ liệu
                  ND->>App: Gửi yêu cầu
                  App->>CSDL: Truy vấn
                  CSDL-->>App: Kết quả
                  App-->>ND: Hiển thị
                """),
        MermaidTemplate(
            kind: .classDiagram, title: "Lớp — quan hệ kế thừa",
            summary: "Thuộc tính, phương thức và quan hệ giữa các lớp.",
            source: """
                ---
                title: Sơ đồ lớp tài khoản
                ---
                classDiagram
                  class TaiKhoan {
                    +String maSo
                    +Double soDu
                    +napTien(Double)
                  }
                  class TaiKhoanTietKiem {
                    +Double laiSuat
                  }
                  TaiKhoan <|-- TaiKhoanTietKiem
                """),
        MermaidTemplate(
            kind: .state, title: "Trạng thái — vòng đời đơn hàng",
            summary: "Đơn đi qua những trạng thái nào và bằng sự kiện gì.",
            source: """
                stateDiagram-v2
                  [*] --> MoiTao
                  MoiTao --> DangGiao: xác nhận
                  DangGiao --> DaGiao: giao thành công
                  DangGiao --> Huy: khách từ chối
                  DaGiao --> [*]
                  Huy --> [*]
                """),
        MermaidTemplate(
            kind: .entityRelationship, title: "Thực thể — quan hệ",
            summary: "Bảng và quan hệ một–nhiều, dùng khi thiết kế cơ sở dữ liệu.",
            source: """
                erDiagram
                  KHACH_HANG ||--o{ DON_HANG : "đặt"
                  DON_HANG ||--|{ DONG_HANG : "gồm"
                  KHACH_HANG {
                    string ma_khach PK
                    string ten
                  }
                  DON_HANG {
                    string ma_don PK
                    date ngay_dat
                  }
                """),
        MermaidTemplate(
            kind: .gantt, title: "Gantt — kế hoạch dự án",
            summary: "Việc, thời hạn và phụ thuộc theo tuần.",
            source: """
                gantt
                  title Kế hoạch triển khai
                  dateFormat YYYY-MM-DD
                  axisFormat %d/%m
                  section Chuẩn bị
                    Khảo sát        :a1, 2026-09-01, 7d
                    Chốt yêu cầu    :a2, after a1, 5d
                  section Thực hiện
                    Lập trình       :b1, after a2, 20d
                    Kiểm thử        :b2, after b1, 10d
                """),
        MermaidTemplate(
            kind: .pie, title: "Bánh — tỷ trọng",
            summary: "Cơ cấu theo phần trăm; hợp với ba tới sáu phần.",
            source: """
                pie showData
                  title Cơ cấu doanh thu theo miền
                  "Miền Bắc" : 45
                  "Miền Trung" : 20
                  "Miền Nam" : 35
                """),
        MermaidTemplate(
            kind: .mindmap, title: "Bản đồ tư duy",
            summary: "Ý chính và các nhánh con, dùng khi ghi chép nhanh.",
            source: """
                mindmap
                  root((Dự án GEditor))
                    Soạn thảo
                      Tìm kiếm
                      Đa con nháy
                    Dữ liệu
                      Bảng CSV
                      Truy vấn SQL
                    Báo cáo
                      Biểu đồ
                      Sơ đồ
                """),
        MermaidTemplate(
            kind: .timeline, title: "Dòng thời gian",
            summary: "Mốc theo năm hoặc theo giai đoạn.",
            source: """
                timeline
                  title Các mốc phát hành
                  2026 Q1 : Bản thử nội bộ
                  2026 Q2 : Bản beta công khai
                  2026 Q3 : Bản 1.0 lên App Store
                """),
        MermaidTemplate(
            kind: .quadrant, title: "Bốn góc phần tư — ưu tiên",
            summary: "Xếp việc theo hai trục, thường là tác động và công sức.",
            source: """
                quadrantChart
                  title Ưu tiên việc
                  x-axis "Ít công sức" --> "Nhiều công sức"
                  y-axis "Tác động thấp" --> "Tác động cao"
                  quadrant-1 Làm ngay
                  quadrant-2 Lên kế hoạch
                  quadrant-3 Bỏ qua
                  quadrant-4 Giao lại
                  "Sửa lỗi xuất PDF": [0.2, 0.8]
                  "Viết lại bộ tìm kiếm": [0.8, 0.7]
                  "Đổi màu biểu tượng": [0.2, 0.2]
                """),
        MermaidTemplate(
            kind: .gitGraph, title: "Nhánh Git",
            summary: "Luồng nhánh và điểm gộp.",
            source: """
                gitGraph
                  commit id: "khởi tạo"
                  branch tinh-nang
                  commit id: "thêm bảng CSV"
                  commit id: "thêm biểu đồ"
                  checkout main
                  merge tinh-nang
                """),
    ]

    // MARK: - Mẩu cú pháp

    /// Mẩu chèn vào GIỮA một sơ đồ đang có.
    ///
    /// Ngắn có chủ ý: một mẩu dài thì người dùng phải xoá bớt, và xoá bớt tốn công hơn gõ thêm.
    public static let fragments: [MermaidTemplate] = [
        MermaidTemplate(
            kind: .flowchart, scope: .fragment, title: "Nút có nhãn",
            summary: "Hộp chữ nhật thường.", source: "  A[Nhãn]"),
        MermaidTemplate(
            kind: .flowchart, scope: .fragment, title: "Nút quyết định",
            summary: "Hình thoi, mở ra hai nhánh.", source: "  B{Điều kiện?}"),
        MermaidTemplate(
            kind: .flowchart, scope: .fragment, title: "Cạnh có nhãn",
            summary: "Mũi tên kèm chữ trên đường.", source: "  A -->|nhãn| B"),
        MermaidTemplate(
            kind: .flowchart, scope: .fragment, title: "Nhóm con",
            summary: "Khung bao quanh vài nút.",
            source: """
                  subgraph Tên nhóm
                    A --> B
                  end
                """),
        MermaidTemplate(
            kind: .sequence, scope: .fragment, title: "Người tham gia",
            summary: "Khai một cột dọc, có thể đặt tên hiển thị khác.",
            source: "  participant App as Ứng dụng"),
        MermaidTemplate(
            kind: .sequence, scope: .fragment, title: "Nhánh có/không",
            summary: "Khối alt cho hai đường đi.",
            source: """
                  alt Thành công
                    App-->>ND: Kết quả
                  else Thất bại
                    App-->>ND: Báo lỗi
                  end
                """),
        MermaidTemplate(
            kind: .sequence, scope: .fragment, title: "Vòng lặp",
            summary: "Khối loop.",
            source: """
                  loop Mỗi dòng
                    App->>CSDL: Ghi
                  end
                """),
        MermaidTemplate(
            kind: .classDiagram, scope: .fragment, title: "Lớp có thuộc tính",
            summary: "Khối lớp với trường và phương thức.",
            source: """
                  class TenLop {
                    +String truong
                    +phuongThuc()
                  }
                """),
        MermaidTemplate(
            kind: .state, scope: .fragment, title: "Chuyển trạng thái",
            summary: "Một mũi tên kèm sự kiện.", source: "  TrangThaiA --> TrangThaiB: sự kiện"),
        MermaidTemplate(
            kind: .entityRelationship, scope: .fragment, title: "Quan hệ một–nhiều",
            summary: "Một bên trái ứng nhiều bên phải.",
            source: "  BANG_CHA ||--o{ BANG_CON : \"quan hệ\""),
        MermaidTemplate(
            kind: .gantt, scope: .fragment, title: "Mục việc",
            summary: "Một dòng việc có mã, ngày bắt đầu và độ dài.",
            source: "    Tên việc :ma1, 2026-09-01, 5d"),
    ]

    // MARK: - Từ khoá cho gợi ý

    /// Từ khoá chung, có ở mọi loại sơ đồ.
    static let commonKeywords = ["title", "accTitle", "accDescr", "click", "style", "classDef"]

    /// Từ khoá của từng loại — nguồn cho vế *"autocomplete từ khóa Mermaid"*.
    public static func keywords(for kind: MermaidDiagramKind) -> [String] {
        let specific: [String]
        switch kind {
        case .flowchart:
            specific = ["flowchart", "graph", "subgraph", "end", "direction",
                        "TD", "TB", "BT", "LR", "RL", "linkStyle"]
        case .sequence:
            specific = ["sequenceDiagram", "participant", "actor", "activate", "deactivate",
                        "alt", "else", "opt", "loop", "par", "and", "critical", "break",
                        "rect", "note", "over", "autonumber", "end", "as"]
        case .classDiagram:
            specific = ["classDiagram", "class", "namespace", "note", "cssClass", "link",
                        "callback", "end"]
        case .state:
            specific = ["stateDiagram-v2", "stateDiagram", "state", "note", "direction",
                        "as", "end"]
        case .entityRelationship:
            specific = ["erDiagram", "PK", "FK", "UK"]
        case .gantt:
            specific = ["gantt", "dateFormat", "axisFormat", "section", "excludes",
                        "todayMarker", "tickInterval", "after", "done", "active", "crit",
                        "milestone"]
        case .pie:
            specific = ["pie", "showData"]
        case .mindmap:
            specific = ["mindmap", "root"]
        case .timeline:
            specific = ["timeline", "section"]
        case .quadrant:
            specific = ["quadrantChart", "x-axis", "y-axis",
                        "quadrant-1", "quadrant-2", "quadrant-3", "quadrant-4"]
        case .gitGraph:
            specific = ["gitGraph", "commit", "branch", "checkout", "merge", "cherry-pick",
                        "id", "tag", "type"]
        case .other:
            // Loại lạ vẫn gợi ý được phần chung — ít hơn, nhưng không phải không có gì.
            specific = []
        }
        return specific + commonKeywords
    }

    /// Mọi từ khoá của mọi loại, đã khử trùng — dùng khi chưa biết loại.
    public static let allKeywords: [String] = {
        var seen = Set<String>()
        var out: [String] = []
        for kind in MermaidDiagramKind.named {
            for keyword in keywords(for: kind) where !seen.contains(keyword) {
                seen.insert(keyword)
                out.append(keyword)
            }
        }
        return out
    }()

    // MARK: - Tên node đã khai trong tài liệu

    /// Tên node/thực thể/người tham gia mà tài liệu đã khai — vế *"TÊN NODE đã khai báo"*.
    ///
    /// ## Cách làm: lấy định danh NGOÀI nhãn, không phân tích cú pháp đầy đủ
    ///
    /// Mỗi loại sơ đồ có một cú pháp riêng, và viết mười một bộ phân tích là dựng lại mermaid
    /// bằng Swift. Nhưng cả mười một loại có chung một tính chất dễ khai thác: **định danh đứng
    /// ngoài dấu nhãn, còn chữ cho người đọc đứng trong** `[ ]`, `( )`, `{ }`, `" "`, `| |`,
    /// hoặc sau dấu `:`.
    ///
    /// Nên hàm này bỏ mọi thứ trong nhãn, rồi lấy các từ còn lại và trừ đi từ khoá. Kết quả
    /// KHÔNG hoàn hảo — nó có thể sót một dạng khai lạ, hoặc thừa một từ trong một dòng cú pháp
    /// hiếm gặp. Với gợi ý gõ thì cả hai đều rẻ: sót thì người dùng gõ tay như trước, thừa thì
    /// một dòng lạ trong danh sách. Với một phép chấm điểm hay một phép sửa văn bản thì mức
    /// chính xác này KHÔNG đủ — và đó là lý do nó chỉ được dùng cho gợi ý.
    public static func nodeNames(in source: String) -> [String] {
        let kind = MermaidDocument.declaration(in: source)
            .map(MermaidDiagramKind.from(declaration:)) ?? .other("")
        return nodeNames(in: source, kind: kind)
    }

    /// Loại sơ đồ nào có ĐỊNH DANH để mà gợi ý.
    ///
    /// Năm loại này đặt tên cho từng phần tử rồi nhắc lại tên ấy ở dòng khác — đúng chỗ gợi ý
    /// giúp được. `gantt`, `pie`, `timeline`, `mindmap`, `quadrantChart` thì gần như toàn CHỮ
    /// cho người đọc: rút "tên" từ chúng sẽ trả về những từ vừa gõ xong ở dòng trên, mà gợi ý
    /// theo từ trong tài liệu (FR-CORE-013) đã làm việc ấy rồi. Trả rỗng là câu trả lời đúng,
    /// không phải một chỗ chưa làm.
    static func hasIdentifiers(_ kind: MermaidDiagramKind) -> Bool {
        switch kind {
        case .flowchart, .sequence, .classDiagram, .state, .entityRelationship: return true
        default: return false
        }
    }

    static func nodeNames(in source: String, kind: MermaidDiagramKind) -> [String] {
        guard hasIdentifiers(kind) else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        let keywordSet = Set(allKeywords.map { $0.lowercased() })
        // `erDiagram` KHÔNG dùng `{ } |` làm dấu nhãn: ở đó chúng là ký hiệu lực lượng quan hệ
        // (`||--o{`) và dấu mở khối thuộc tính. Coi chúng là nhãn thì mọi thứ sau dấu đầu tiên
        // bị nuốt, và bảng thứ hai của mỗi quan hệ biến mất.
        let bracketsAreLabels = kind != .entityRelationship

        for rawLine in source.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("%%") { continue }              // chú thích và chỉ thị
            // Phần sau dấu `:` của sequence/gantt/state là CHỮ, không phải định danh — trừ khi
            // dòng ấy khai `participant … as …`. Cắt ở dấu hai chấm đầu tiên không nằm trong
            // nhãn là đủ cho mọi ca thường gặp.
            var depth = 0
            var inQuote = false
            var inPipe = false
            var cut: String.Index?
            var index = line.startIndex
            while index < line.endIndex {
                let character = line[index]
                if character == "\"" { inQuote.toggle() }
                if !inQuote {
                    if bracketsAreLabels {
                        // `|` là dấu ĐÓNG MỞ giống nhau (`-->|nhãn|`), nên nó phải là công tắc
                        // chứ không phải một cặp tăng/giảm. Bản đầu để nó trong cả hai danh
                        // sách mở và đóng, và vì nhánh "mở" xét trước nên MỌI dấu `|` đều tăng
                        // độ sâu — độ sâu không bao giờ về 0 và phần còn lại của sơ đồ biến
                        // mất. Bài kiểm lưu đồ bốn node bắt được: nó chỉ trả về hai.
                        if character == "|" { inPipe.toggle() }
                        if !inPipe {
                            if "[({".contains(character) { depth += 1 }
                            if "])}".contains(character) { depth = max(0, depth - 1) }
                        }
                    }
                    if character == ":", depth == 0, !inPipe { cut = index; break }
                }
                index = line.index(after: index)
            }
            if let cut { line = String(line[line.startIndex ..< cut]) }

            // Bỏ mọi thứ nằm trong nhãn.
            var outside = ""
            depth = 0
            inQuote = false
            inPipe = false
            for character in line {
                if character == "\"" {
                    inQuote.toggle()
                    outside.append(" ")
                    continue
                }
                if inQuote { continue }
                if bracketsAreLabels {
                    if character == "|" {
                        inPipe.toggle()
                        outside.append(" ")
                        continue
                    }
                    if inPipe { continue }
                    if "[({".contains(character) {
                        depth += 1
                        outside.append(" ")
                        continue
                    }
                    if "])}".contains(character) {
                        depth = max(0, depth - 1)
                        outside.append(" ")
                        continue
                    }
                }
                outside.append(depth > 0 ? " " : character)
            }

            for token in tokens(in: outside) {
                guard !keywordSet.contains(token.lowercased()) else { continue }
                guard token.contains(where: { $0.isLetter }) else { continue }
                // `erDiagram` bỏ token MỘT ký tự: `||--o{` cắt ra một chữ `o` là ký hiệu lực
                // lượng, không phải tên bảng. Loại khác thì giữ, vì `A --> B` của lưu đồ là
                // tên node thật và người dùng gõ lại chúng suốt.
                if kind == .entityRelationship, token.count == 1 { continue }
                guard !seen.contains(token) else { continue }
                seen.insert(token)
                out.append(token)
            }
        }
        return out
    }

    /// Cắt một dòng thành định danh. Mũi tên và dấu nối KHÔNG phải định danh.
    private static func tokens(in text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for character in text {
            // Dấu gạch dưới và gạch ngang nằm TRONG tên (`ma_don`, `stateDiagram-v2`), nhưng
            // một chuỗi toàn gạch là mũi tên (`-->`, `--`, `..>`), nên phần lọc ở dưới bỏ mọi
            // token không có chữ cái nào.
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                current.append(character)
            } else if !current.isEmpty {
                out.append(current)
                current = ""
            }
        }
        if !current.isEmpty { out.append(current) }
        // Cắt tiếp ở những đoạn HAI gạch trở lên: `B---C` là một mũi tên giữa hai node, không
        // phải một cái tên. Một gạch ĐƠN thì giữ, vì nó nằm trong tên thật (`stateDiagram-v2`,
        // `cherry-pick`). Bài kiểm `B---C` bắt được bản đầu chỉ cắt gạch ở HAI ĐẦU token.
        var split: [String] = []
        for token in out {
            var piece = ""
            var dashes = 0
            for character in token {
                if character == "-" {
                    dashes += 1
                    continue
                }
                if dashes >= 2 {
                    if !piece.isEmpty { split.append(piece) }
                    piece = ""
                } else if dashes == 1, !piece.isEmpty {
                    piece.append("-")
                }
                dashes = 0
                piece.append(character)
            }
            if !piece.isEmpty { split.append(piece) }
        }
        return split
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
    }

    /// Những chữ đại diện cho phần tử mà MỘT DÒNG mã nói tới — FR-MMD-002.
    ///
    /// ## Vì sao trả về CẢ nhãn lẫn định danh
    ///
    /// Đặc tả muốn một bản đồ `element-id ↔ text-range` dựng từ cây phân tích. Cây ấy nằm trong
    /// mermaid.js và không có API trả ra — nên chỗ nối duy nhất còn lại giữa văn bản và hình vẽ
    /// là **chữ hiện trên phần tử**.
    ///
    /// Nhưng "chữ hiện trên phần tử" là hai thứ khác nhau tuỳ dòng: `A[Nhận hồ sơ]` vẽ ra chữ
    /// *"Nhận hồ sơ"*, còn `A --> B` vẽ ra chữ *"A"* và *"B"*. Trả về cả hai loại rồi để bên
    /// vẽ so khớp là cách duy nhất phủ được cả hai mà không phải hiểu cú pháp của mười một loại
    /// sơ đồ.
    ///
    /// Giới hạn phải nói ra: hai node cùng NHÃN sẽ cùng sáng. Đó là một giới hạn thấy được và
    /// đoán được, khác hẳn một tính năng chết lặng.
    public static func focusWords(inLine line: String, kind: MermaidDiagramKind) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("%%") else { return [] }
        var out: [String] = []
        var seen = Set<String>()
        func add(_ word: String) {
            let text = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !seen.contains(text) else { return }
            seen.insert(text)
            out.append(text)
        }
        // Nhãn TRƯỚC: nó là thứ hiện trên hình, nên khớp được nó là khớp đúng phần tử.
        for label in labels(in: trimmed) { add(label) }
        // Rồi tới định danh — dùng cho những dòng không có nhãn.
        for name in nodeNames(in: trimmed, kind: kind) { add(name) }
        return out
    }

    /// Chữ nằm trong `[ ]`, `( )`, `{ }`, `" "` hoặc `| |` của một dòng.
    static func labels(in line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var depth = 0
        var inQuote = false
        var inPipe = false
        for character in line {
            if character == "\"" {
                inQuote.toggle()
                if !inQuote, !current.isEmpty { out.append(current); current = "" }
                continue
            }
            if inQuote {
                current.append(character)
                continue
            }
            if character == "|" {
                inPipe.toggle()
                if !inPipe, !current.isEmpty { out.append(current); current = "" }
                continue
            }
            if inPipe {
                current.append(character)
                continue
            }
            if "[({".contains(character) {
                depth += 1
                if depth == 1 { current = "" }
                continue
            }
            if "])}".contains(character) {
                depth = max(0, depth - 1)
                if depth == 0, !current.isEmpty { out.append(current); current = "" }
                continue
            }
            if depth > 0 { current.append(character) }
        }
        // Nhãn của mermaid hay được bọc thêm một lớp dấu nháy bên trong ngoặc: `A["Nhãn"]`.
        return out.map {
            var text = $0.trimmingCharacters(in: .whitespaces)
            if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
                text = String(text.dropFirst().dropLast())
            }
            return text
        }.filter { !$0.isEmpty }
    }

    /// Danh sách gợi ý cho một sơ đồ: từ khoá của loại ấy + tên node đã khai.
    ///
    /// Tên node đứng TRƯỚC từ khoá trong danh sách trả về, vì `CompletionEngine` giữ thứ tự khi
    /// điểm bằng nhau: gõ `Kh` giữa một lưu đồ thì `KhachHang` của chính tài liệu đáng hiện
    /// trên `checkout` của gitGraph.
    public static func completionWords(in source: String) -> [String] {
        let kind = MermaidDocument.declaration(in: source)
            .map(MermaidDiagramKind.from(declaration:)) ?? .other("")
        var seen = Set<String>()
        var out: [String] = []
        for word in nodeNames(in: source) + keywords(for: kind) where !seen.contains(word) {
            seen.insert(word)
            out.append(word)
        }
        return out
    }
}
