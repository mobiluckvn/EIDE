import Foundation

/// Phần ĐỌC của `MermaidEdit` — FR-MMD-004.
///
/// Tách khỏi tệp chính vì nó trả lời một câu hỏi khác: *"dòng này nói gì"*, chứ không phải
/// *"sinh sửa đổi nào"*. Và nó là chỗ chứa toàn bộ khác biệt giữa các phương ngữ mermaid —
/// `A[Nhãn]` của flowchart, `s1 : mô tả` của state, `class Foo` của class, `CUSTOMER ||--o{ ORDER`
/// của ER, `A->>B: chào` của sequence. Gom chúng vào một chỗ để phần sinh sửa đổi không phải biết
/// năm phương ngữ.
///
/// ## Đọc THEO DÒNG, và nói ra vì sao thế là đủ
///
/// Mã mermaid trên thực tế là **một câu lệnh một dòng**; đó là quy ước mà chính tài liệu mermaid
/// dạy và là thứ `MermaidFormatter` đã dựa vào. Bộ đọc này theo đúng quy ước ấy: nó không dựng
/// cây phân tích, và nó **từ chối** thay vì đoán khi một dòng không khớp mẫu nào nó biết.
extension MermaidEdit {

    // MARK: - Cạnh

    struct ParsedEdge {
        var edge: Edge
        var from: Node
        var to: Node
    }

    /// Vị trí (theo chỉ số ký tự) của mọi mũi tên nằm NGOÀI nhãn.
    ///
    /// Phải bỏ qua phần trong `"…"`, `[…]`, `(…)`, `{…}`: một nhãn như `A["a --> b"]` có mũi tên
    /// bên trong, và cắt ở đó thì cả hai nửa đều là rác.
    static func arrowMatches(in line: String, kind: MermaidDiagramKind) -> [(String, Range<Int>)] {
        let chars = Array(line)
        let table = arrows(for: kind)
        var out: [(String, Range<Int>)] = []
        var depth = 0
        var inQuote = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" { inQuote.toggle(); i += 1; continue }
            if inQuote { i += 1; continue }
            if "[({".contains(c) { depth += 1; i += 1; continue }
            if "])}".contains(c) { depth = max(0, depth - 1); i += 1; continue }
            if depth > 0 { i += 1; continue }
            var matched = false
            for arrow in table {
                let n = arrow.count
                guard i + n <= chars.count, String(chars[i ..< (i + n)]) == arrow else { continue }
                out.append((arrow, i ..< (i + n)))
                i += n
                matched = true
                break
            }
            if !matched { i += 1 }
        }
        return out
    }

    static func parseEdge(
        _ line: String, kind: MermaidDiagramKind, line number: Int
    ) -> ParsedEdge? {
        let matches = arrowMatches(in: line, kind: kind)
        guard let first = matches.first else { return nil }
        let chars = Array(line)

        var traiRange = 0 ..< first.1.lowerBound
        var phaiRange = first.1.upperBound ..< chars.count
        var arrow = first.0
        var nhanGiua: String?

        // Dạng `A -- nhãn --> B` của flowchart: hai mũi tên, nhãn nằm giữa. Không xử riêng thì
        // phép cắt lấy mũi tên ĐẦU và node đích trở thành «nhãn --> B».
        if case .flowchart = kind, matches.count >= 2 {
            let second = matches[1]
            nhanGiua = String(chars[first.1.upperBound ..< second.1.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            arrow = second.0
            phaiRange = second.1.upperBound ..< chars.count
            traiRange = 0 ..< first.1.lowerBound
        }

        var trai = String(chars[traiRange]).trimmingCharacters(in: .whitespaces)
        var phai = String(chars[phaiRange])

        // ER dựng lực lượng quan hệ bằng ký hiệu DÍNH vào hai đầu (`KHACH ||--o{ DONHANG`), nên
        // chúng phải được gỡ NGAY — trước cả phép tìm nhãn. Gỡ sau thì dấu `{` của `o{` bị đếm
        // là mở ngoặc, và dấu `:` ngăn nhãn nằm "trong ngoặc" nên không ai tìm thấy nó.
        if case .entityRelationship = kind {
            trai = String(trai.reversed().drop { "|o{}".contains($0) }.reversed())
                .trimmingCharacters(in: .whitespaces)
            phai = String(phai.drop { $0 == " " }.drop { "|o{}".contains($0) })
                .trimmingCharacters(in: .whitespaces)
            arrow = String(chars[first.1])
        }

        // Nhãn: `|nhãn|` ngay sau mũi tên (flowchart), hoặc `: nhãn` ở cuối (mọi loại khác).
        var nhan = nhanGiua
        if case .flowchart = kind, phai.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            let sau = phai.trimmingCharacters(in: .whitespaces).dropFirst()
            if let close = sau.firstIndex(of: "|") {
                nhan = String(sau[..<close]).trimmingCharacters(in: .whitespaces)
                phai = String(sau[sau.index(after: close)...])
            }
        } else if let colon = viTriDauHaiCham(in: phai) {
            let sau = phai.index(phai.startIndex, offsetBy: colon)
            nhan = String(phai[phai.index(after: sau)...]).trimmingCharacters(in: .whitespaces)
            phai = String(phai[..<sau])
        }
        phai = phai.trimmingCharacters(in: .whitespaces)

        guard let from = parseEndpoint(trai), let to = parseEndpoint(phai) else { return nil }
        // Nhãn cạnh cũng phải bóc lớp nháy: `: "đặt"` của ER cho ra `đặt`, không phải `"đặt"` —
        // nếu không thì nhãn hiện trên hình khác nhãn ta cầm trong tay, và mọi phép so khớp
        // "chữ trên hình → định danh" lệch đi đúng hai dấu nháy.
        let nhanSach = nhan.flatMap(goNhan)
        return ParsedEdge(
            edge: Edge(from: from.id, to: to.id, label: nhanSach,
                       arrow: arrow, line: number),
            from: from, to: to)
    }

    /// Vị trí dấu `:` ngăn nhãn — bỏ qua dấu nằm trong nháy hoặc trong ngoặc.
    static func viTriDauHaiCham(in text: String) -> Int? {
        var depth = 0
        var inQuote = false
        for (i, c) in Array(text).enumerated() {
            if c == "\"" { inQuote.toggle(); continue }
            if inQuote { continue }
            if "[({".contains(c) { depth += 1; continue }
            if "])}".contains(c) { depth = max(0, depth - 1); continue }
            if c == ":", depth == 0 { return i }
        }
        return nil
    }

    /// Một đầu cạnh: `A`, `A[Nhãn]`, `A["Nhãn"]`, `A(Nhãn)`, `A{Nhãn}`, `A((Nhãn))`, `[*]`.
    static func parseEndpoint(_ text: String) -> Node? {
        let can = text.trimmingCharacters(in: .whitespaces)
        guard !can.isEmpty else { return nil }
        if can == "[*]" { return Node(id: "[*]", label: nil, declLine: nil) }
        let chars = Array(can)
        var i = 0
        while i < chars.count, !"[({".contains(chars[i]) { i += 1 }
        let id = String(chars[0 ..< i]).trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !id.contains(" ") else { return nil }
        guard i < chars.count else { return Node(id: id, label: nil, declLine: nil) }
        let ben_trong = String(chars[i...])
        return Node(id: id, label: goNhan(ben_trong), declLine: nil)
    }

    /// Bóc phần chữ ra khỏi lớp vỏ hình dạng: `["Nhãn"]`, `[Nhãn]`, `((Nhãn))`, `{Nhãn}`.
    static func goNhan(_ wrapper: String) -> String? {
        var text = wrapper.trimmingCharacters(in: .whitespaces)
        while let first = text.first, let last = text.last,
              "[({".contains(first), "])}".contains(last), text.count >= 2 {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }
        return text.isEmpty ? nil : text
    }

    // MARK: - Khai báo

    /// Những từ mở đầu KHÔNG khai một node — chúng khai cấu hình, khối, hay kiểu vẽ.
    static func keywords(for kind: MermaidDiagramKind) -> Set<String> {
        var common: Set<String> = ["subgraph", "end", "style", "classDef", "click", "linkStyle",
                                   "direction", "accTitle", "accDescr", "note", "title"]
        switch kind {
        case .flowchart:
            common.insert("class")   // ở flowchart, `class A tenCSS` GÁN kiểu, không khai node
        case .sequence:
            common.formUnion(["activate", "deactivate", "autonumber", "loop", "alt", "else",
                              "opt", "par", "and", "critical", "option", "rect", "box",
                              "create", "destroy", "link", "links"])
        case .state:
            common.formUnion(["classDef", "class"])
        default:
            break
        }
        return common
    }

    /// Đọc một dòng KHÔNG có mũi tên. `isDeclaration` = dòng này có phải chỗ KHAI node không —
    /// dòng thành viên của classDiagram nhắc tên lớp nhưng không khai nó.
    static func parseDeclaration(
        _ line: String, kind: MermaidDiagramKind
    ) -> (id: String, label: String?, isDeclaration: Bool)? {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let word = String(text.prefix { !$0.isWhitespace && $0 != "[" && $0 != "(" && $0 != "{" })
        if keywords(for: kind).contains(word) { return nil }

        switch kind {
        case .state:
            // `state "mô tả" as s1` · `state s1 {` · `s1 : mô tả` · `s1`
            if word == "state" {
                let rest = String(text.dropFirst("state".count))
                    .trimmingCharacters(in: .whitespaces)
                if let asRange = rest.range(of: " as ") {
                    let label = goNhan(String(rest[..<asRange.lowerBound]))
                    let id = String(rest[asRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "{", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    return id.isEmpty ? nil : (id, label, true)
                }
                let id = rest.replacingOccurrences(of: "{", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return id.isEmpty ? nil : (id, nil, true)
            }
            if let colon = viTriDauHaiCham(in: text) {
                let id = String(Array(text)[0 ..< colon]).trimmingCharacters(in: .whitespaces)
                let label = String(Array(text)[(colon + 1)...])
                    .trimmingCharacters(in: .whitespaces)
                return id.isEmpty ? nil : (id, label.isEmpty ? nil : label, true)
            }
            return (word, nil, true)

        case .classDiagram:
            if word == "class" {
                let rest = String(text.dropFirst("class".count))
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "{", with: "")
                    .trimmingCharacters(in: .whitespaces)
                guard let node = parseEndpoint(rest) else { return nil }
                return (node.id, node.label, true)
            }
            // `Foo : +ten()` là dòng THÀNH VIÊN: nó nhắc tên lớp nhưng không khai lớp, nên nhãn
            // của nó không phải nhãn lớp. Ghi nhận lớp, không ghi nhận dòng.
            if let colon = viTriDauHaiCham(in: text) {
                let id = String(Array(text)[0 ..< colon]).trimmingCharacters(in: .whitespaces)
                return id.isEmpty ? nil : (id, nil, false)
            }
            guard let node = parseEndpoint(text) else { return nil }
            return (node.id, node.label, true)

        case .sequence:
            guard ["participant", "actor"].contains(word) else { return nil }
            let rest = String(text.dropFirst(word.count)).trimmingCharacters(in: .whitespaces)
            if let asRange = rest.range(of: " as ") {
                let id = String(rest[..<asRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let label = String(rest[asRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                return id.isEmpty ? nil : (id, label.isEmpty ? nil : label, true)
            }
            return rest.isEmpty ? nil : (rest, nil, true)

        default:
            // flowchart và ER: `A`, `A[Nhãn]`, `CUSTOMER {`, `CUSTOMER["Nhãn"] {`
            let rest = text.hasSuffix("{")
                ? String(text.dropLast()).trimmingCharacters(in: .whitespaces) : text
            guard let node = parseEndpoint(rest) else { return nil }
            return (node.id, node.label, true)
        }
    }

    // MARK: - Nhãn trong một dòng khai

    /// Khoảng BYTE (tính trong dòng) của phần CHỮ nhãn — để thay đúng chỗ ấy.
    ///
    /// Trả `nil` khi dòng khai chưa mang nhãn; chỗ gọi khi ấy đi đường "thêm nhãn".
    static func labelRange(
        in line: String, id: String, kind: MermaidDiagramKind
    ) -> Range<Int>? {
        let text = line
        switch kind {
        case .state, .sequence:
            if case .sequence = kind {
                guard let asRange = text.range(of: " as ") else { return nil }
                return byteRange(from: asRange.upperBound, to: text.endIndex, in: text)
            }
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("state"),
               let asRange = text.range(of: " as ") {
                // `state "mô tả" as s1` — nhãn nằm TRƯỚC ` as `, trong cặp nháy.
                let truoc = text[..<asRange.lowerBound]
                guard let mo = truoc.firstIndex(of: "\""),
                      let dong = truoc.lastIndex(of: "\""), mo < dong else { return nil }
                return byteRange(from: text.index(after: mo), to: dong, in: text)
            }
            guard let colon = viTriDauHaiCham(in: text) else { return nil }
            let sau = text.index(text.startIndex, offsetBy: colon + 1)
            var start = sau
            while start < text.endIndex, text[start] == " " { start = text.index(after: start) }
            return byteRange(from: start, to: text.endIndex, in: text)

        default:
            // Neo theo ĐỊNH DANH, không lấy cặp ngoặc đầu tiên của dòng.
            //
            // Một dòng cạnh mang HAI nhãn — `A["Nhận"] --> B["Duyệt"]` — nên "cặp ngoặc đầu
            // tiên" luôn là nhãn của node bên TRÁI, và sửa nhãn của `B` sẽ ghi đè lên nhãn của
            // `A`. Đây là chỗ đã hỏng thật và bài kiểm bắt được.
            guard let mo = viTriVoNhan(of: id, in: text) else { return nil }
            var start = text.index(after: mo)
            var end = dongVo(from: mo, in: text)
            while start < end, "[({".contains(text[start]),
                  "])}".contains(text[text.index(before: end)]) {
                start = text.index(after: start)
                end = text.index(before: end)
            }
            if start < end, text[start] == "\"",
               text[text.index(before: end)] == "\"" {
                start = text.index(after: start)
                end = text.index(before: end)
            }
            return byteRange(from: start, to: end, in: text)
        }
    }

    /// Vị trí dấu mở vỏ nhãn của ĐÚNG định danh này: `id` phải đứng liền ngay trước `[`, `(`
    /// hay `{`, và trước `id` phải là biên từ.
    static func viTriVoNhan(of id: String, in text: String) -> String.Index? {
        var from = text.startIndex
        while let r = text.range(of: id, range: from ..< text.endIndex) {
            from = r.upperBound
            let truoc = r.lowerBound == text.startIndex
                ? nil : text[text.index(before: r.lowerBound)]
            let bienTu = truoc.map { !$0.isLetter && !$0.isNumber && $0 != "_" } ?? true
            if bienTu, r.upperBound < text.endIndex, "[({".contains(text[r.upperBound]) {
                return r.upperBound
            }
        }
        return nil
    }

    /// Vị trí dấu đóng ứng với vỏ nhãn mở tại `mo`.
    static func dongVo(from mo: String.Index, in text: String) -> String.Index {
        var depth = 0
        var inQuote = false
        var i = mo
        while i < text.endIndex {
            let c = text[i]
            if c == "\"" { inQuote.toggle() }
            else if !inQuote, "[({".contains(c) { depth += 1 }
            else if !inQuote, "])}".contains(c) {
                depth -= 1
                if depth == 0 { return i }
            }
            i = text.index(after: i)
        }
        return text.endIndex
    }

    /// Thêm nhãn vào một dòng khai CHƯA có nhãn. `nil` = phương ngữ này không thêm tại chỗ được.
    static func themNhan(
        _ label: String, into line: String, line number: Int, lines: [String],
        kind: MermaidDiagramKind
    ) -> TextEdit? {
        let base = offset(ofLineStart: number, lines: lines)
        switch kind {
        case .sequence:
            let at = base + line.utf8.count
            return TextEdit(range: at ..< at, text: " as \(escape(label))")
        case .state:
            // `state s1` không nhận nhãn tại chỗ — dạng mang mô tả là một câu lệnh KHÁC
            // (`s1 : mô tả`). Trả `nil` để chỗ gọi thêm hẳn dòng ấy.
            return nil
        case .classDiagram, .entityRelationship, .flowchart:
            // Chèn ngay sau ĐỊNH DANH: `class Foo` → `class Foo["Nhãn"]`, `CUSTOMER {` →
            // `CUSTOMER["Nhãn"] {`.
            let text = line
            let sauTuKhoa: String.Index
            if kind == .classDiagram, let r = text.range(of: "class ") {
                sauTuKhoa = r.upperBound
            } else {
                sauTuKhoa = text.firstIndex(where: { !$0.isWhitespace }) ?? text.startIndex
            }
            var end = sauTuKhoa
            while end < text.endIndex, !text[end].isWhitespace, !"[({".contains(text[end]) {
                end = text.index(after: end)
            }
            let at = base + text[..<end].utf8.count
            return TextEdit(range: at ..< at, text: "[\"\(escape(label))\"]")
        default:
            return nil
        }
    }

    static func byteRange(
        from: String.Index, to: String.Index, in text: String
    ) -> Range<Int> {
        text[..<from].utf8.count ..< text[..<to].utf8.count
    }

    // MARK: - Bảng thuộc tính (gantt · pie)

    /// Những khoá cấu hình của gantt/pie — chúng KHÔNG phải mục của bảng.
    static let tableKeywords: Set<String> = [
        "title", "dateformat", "axisformat", "excludes", "includes", "todaymarker",
        "tickinterval", "weekday", "showdata", "accTitle", "acctitle", "accdescr",
        "section", "inclusiveenddates", "topaxis", "displaymode",
    ]

    static func parseRow(
        _ line: String, line number: Int, section: String?, kind: MermaidDiagramKind
    ) -> Row? {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard let colon = viTriDauHaiCham(in: text) else { return nil }
        let chars = Array(text)
        let label = String(chars[0 ..< colon]).trimmingCharacters(in: .whitespaces)
        let value = String(chars[(colon + 1)...]).trimmingCharacters(in: .whitespaces)
        let khoa = label.lowercased().prefix { !$0.isWhitespace }
        guard !tableKeywords.contains(String(khoa)) else { return nil }
        guard !label.isEmpty else { return nil }
        return Row(label: goNhan(label) ?? label, value: value, line: number, section: section)
    }
}
