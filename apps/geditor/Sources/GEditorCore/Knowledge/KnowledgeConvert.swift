import Foundation

/// Chuyển đổi giữa các dạng tri thức — FR-KNW-910.
///
/// Đặc tả: *"Chunks JSONL ↔ CSV ↔ Markdown; đồ thị DOT ↔ Mermaid ↔ edge list — cùng cơ chế
/// preview 5 dòng trước khi tạo tab mới như FR-CSV-406."*
///
/// ## Cái gì KHÔNG ở đây, và vì sao
///
/// **Markdown → JSONL không nằm trong tệp này.** Nó chính là phép cắt chunk, và phép ấy đã có ở
/// `Chunker` (FR-KNW-903) với ba chiến lược cùng đủ tham số. Viết một bản thứ hai ở đây sẽ cho ra
/// những chunk KHÁC với bản xem trước người dùng vừa nhìn — đúng mẫu "hai bản của một thuật toán"
/// mà kho này đã gặp bốn lần. Lệnh chuyển đổi vì thế chỉ dẫn sang đó.
///
/// ## Mermaid → DOT: chỉ flowchart, và nói ra
///
/// Bộ đọc Mermaid ở đây hiểu **flowchart**, đúng tập con mà `DOTToMermaid` phát ra, cộng vài dạng
/// người ta hay gõ tay. Sequence diagram, gantt, class diagram thì **không** — và nó trả lỗi nói
/// rõ loại sơ đồ chứ không im lặng ra một đồ thị rỗng. Một đồ thị rỗng trông y hệt "file không có
/// gì", và người dùng sẽ đi tìm lỗi ở file nguồn.
public enum KnowledgeConvert {

    public enum Format: String, CaseIterable, Sendable {
        case chunksJSONL
        case chunksCSV
        case chunksMarkdown
        case graphDOT
        case graphMermaid
        case graphEdgeList

        public var displayName: String {
            switch self {
            case .chunksJSONL: return "Chunks — JSONL"
            case .chunksCSV: return "Chunks — CSV"
            case .chunksMarkdown: return "Chunks — Markdown"
            case .graphDOT: return "Đồ thị — DOT"
            case .graphMermaid: return "Đồ thị — Mermaid"
            case .graphEdgeList: return "Đồ thị — edge list (TSV)"
            }
        }
    }

    public struct Failure: Error, Equatable {
        public let reason: String
    }

    /// Năm dòng đầu của kết quả — khuôn xem trước của FR-CSV-406.
    ///
    /// Xem trước đi qua **CHÍNH** hàm chuyển đổi rồi mới cắt, không phải một đường riêng "cho
    /// nhanh". Bản xem trước đi đường riêng là cách chắc chắn để nó nói dối đúng lúc người dùng
    /// tin nó — đã bị một lần ở sheet chuyển đổi CSV, ghi ở đầu `CSVCleanSheet`.
    public static func preview(
        _ text: String, from: Format, to: Format, lines: Int = 5
    ) throws -> String {
        let full = try convert(text, from: from, to: to)
        let dong = full.split(separator: "\n", omittingEmptySubsequences: false)
        guard dong.count > lines else { return full }
        return dong.prefix(lines).joined(separator: "\n") + "\n…"
    }

    public static func convert(_ text: String, from: Format, to: Format) throws -> String {
        if from == to { return text }
        switch (from, to) {
        case (.chunksJSONL, .chunksCSV): return try jsonlToCSV(text)
        case (.chunksJSONL, .chunksMarkdown): return try jsonlToMarkdown(text)
        case (.chunksCSV, .chunksJSONL): return try csvToJSONL(text)
        case (.graphDOT, .graphMermaid):
            return DOTToMermaid.convert(DOTGraph.parse(text)).mermaid
        case (.graphDOT, .graphEdgeList): return edgeList(DOTGraph.parse(text))
        case (.graphEdgeList, .graphDOT): return try edgeListToDOT(text)
        case (.graphMermaid, .graphDOT): return try mermaidToDOT(text)
        case (.graphMermaid, .graphEdgeList): return edgeList(try mermaidToGraph(text))
        // FR-MMD-008 đòi tam giác Mermaid ↔ DOT ↔ edge list KHÉP KÍN. Hai chiều còn thiếu đi
        // vòng qua DOT thay vì viết bộ sinh thứ hai: `DOTToMermaid` đã là đường duy nhất sinh
        // mã mermaid trong kho, và một đường thứ hai sẽ cho ra mã khác nó ở đúng những ca hiếm.
        //
        // Tính chất phải nói ra: vòng này KHÔNG giữ định danh. `DOTToMermaid` luôn đặt lại
        // `n0`, `n1`… và đưa tên gốc vào NHÃN, vì tên node DOT có thể chứa ký tự mermaid không
        // nhận. Đồ thị giữ nguyên hình dạng và nhãn; chỉ định danh là mới.
        case (.graphEdgeList, .graphMermaid):
            return DOTToMermaid.convert(DOTGraph.parse(try edgeListToDOT(text))).mermaid
        case (.graphMermaid, .graphMermaid), (.graphDOT, .graphDOT),
             (.graphEdgeList, .graphEdgeList):
            return text
        case (.chunksMarkdown, _):
            throw Failure(reason:
                "Markdown → chunk là phép CẮT CHUNK — dùng «Xem trước cắt chunk» (FR-KNW-903) "
                    + "để chọn chiến lược, rồi Xuất JSONL từ đó.")
        default:
            throw Failure(reason:
                "Chưa hỗ trợ \(from.displayName) → \(to.displayName).")
        }
    }

    // MARK: - Chunk

    static func jsonlToCSV(_ text: String) throws -> String {
        let doi = try chunkObjects(text)
        guard !doi.isEmpty else { return "" }
        // Cột lấy hợp của MỌI bản ghi, không lấy của bản ghi đầu: JSONL thật hay có trường vắng
        // ở vài dòng, và lấy dòng đầu làm chuẩn sẽ nuốt im lặng mọi trường xuất hiện muộn.
        var cot: [String] = []
        var da: Set<String> = []
        for d in doi { for k in d.keys.sorted() where da.insert(k).inserted { cot.append(k) } }

        var out = cot.map { CSVEngine.escape($0, dialect: .comma) }.joined(separator: ",") + "\n"
        for d in doi {
            out += cot.map { CSVEngine.escape(d[$0] ?? "", dialect: .comma) }
                .joined(separator: ",") + "\n"
        }
        return out
    }

    static func jsonlToMarkdown(_ text: String) throws -> String {
        let doi = try chunkObjects(text)
        var out = ""
        for (i, d) in doi.enumerated() {
            let tieu_de = d["heading"] ?? d["id"] ?? "Chunk \(i + 1)"
            out += "## \(tieu_de)\n\n"
            if let noi_dung = d["text"] { out += noi_dung + "\n\n" }
            // Metadata đi vào một dòng chú thích chứ không biến mất: chuyển đổi mà mất trường là
            // chuyển đổi một chiều, và người dùng chỉ phát hiện khi cần đến trường ấy.
            let meta = d.keys.sorted().filter { $0 != "text" && $0 != "heading" }
            if !meta.isEmpty {
                out += "<!-- " + meta.map { "\($0)=\(d[$0] ?? "")" }.joined(separator: " · ")
                    + " -->\n\n"
            }
        }
        return out
    }

    static func csvToJSONL(_ text: String) throws -> String {
        let buffer = TextBuffer(text: text)
        var tieu_de: [String] = []
        var out = ""
        var dong = 0
        try CSVEngine.forEachRow(in: buffer, dialect: .comma) { row in
            let o = row.map {
                String(decoding: CSVEngine.unescape(buffer.bytes(in: $0.range), dialect: .comma),
                       as: UTF8.self)
            }
            if dong == 0 { tieu_de = o } else {
                let doi = zip(tieu_de, o).map { "\(JSONText.quoted($0.0)):\(JSONText.quoted($0.1))" }
                out += "{" + doi.joined(separator: ",") + "}\n"
            }
            dong += 1
            return true
        }
        return out
    }

    /// Mỗi dòng JSONL thành một từ điển chuỗi→chuỗi.
    ///
    /// `public` vì API scripting (FR-KNW-912) gọi vào đây: `jsonl.records` và `jsonl.stats` phải
    /// đọc JSONL y HỆT cách phép chuyển đổi đọc, nếu không thì một script kiểm dữ liệu rồi báo
    /// "sạch" trong khi phép chuyển đổi lại thấy khác.
    ///
    /// Giá trị KHÔNG phải chuỗi (số, mảng) được ép về chuỗi nguyên văn thay vì bỏ đi: một corpus
    /// có trường `score: 0.8` mà chuyển sang CSV bị mất cột ấy là mất dữ liệu im lặng.
    /// - Parameter skippingBadLines: `false` (mặc định) thì NÉM ở dòng hỏng đầu tiên; `true`
    ///   thì bỏ qua nó và đọc tiếp.
    ///
    ///   Mặc định là NÉM, có chủ ý. Chỗ gọi chính là phép CHUYỂN ĐỔI, và một phép chuyển đổi âm
    ///   thầm bỏ vài dòng cho ra một tệp thiếu dữ liệu mà không ai biết — hỏng theo hướng tệ
    ///   nhất. Chế độ bỏ qua phải được XIN, và chỗ duy nhất xin nó là `jsonl.records` của API
    ///   script (FR-KNW-912), nơi `jsonl.validate` là hàm trả lời câu "có dòng nào hỏng không".
    public static func chunkObjects(
        _ text: String, skippingBadLines: Bool = false
    ) throws -> [[String: String]] {
        var out: [[String: String]] = []
        for (i, line) in text.split(separator: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            guard let doi = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)),
                  let map = doi as? [String: Any] else {
                if skippingBadLines { continue }
                throw Failure(reason: "dòng \(i + 1) không phải một đối tượng JSON")
            }
            var phang: [String: String] = [:]
            for (k, v) in map {
                if let s = v as? String { phang[k] = s }
                else if v is NSNull { phang[k] = "" }
                else if let d = try? JSONSerialization.data(withJSONObject: v,
                                                            options: [.fragmentsAllowed]) {
                    phang[k] = String(decoding: d, as: UTF8.self)
                }
            }
            out.append(phang)
        }
        return out
    }

    // MARK: - Đồ thị

    static func edgeList(_ graph: DOTGraph) -> String {
        var out = "source\ttarget\tlabel\n"
        for e in graph.edges {
            out += [e.from, e.to, e.label ?? ""]
                .map { CSVEngine.escape($0, dialect: .tab) }
                .joined(separator: "\t") + "\n"
        }
        return out
    }

    static func edgeListToDOT(_ text: String) throws -> String {
        let buffer = TextBuffer(text: text)
        var out = "digraph {\n"
        var dong = 0
        var cot: [String] = []
        try CSVEngine.forEachRow(in: buffer, dialect: .tab) { row in
            let o = row.map {
                String(decoding: CSVEngine.unescape(buffer.bytes(in: $0.range), dialect: .tab),
                       as: UTF8.self)
            }
            defer { dong += 1 }
            if dong == 0 { cot = o; return true }
            guard o.count >= 2 else { return true }
            let nhan = o.count > 2 && !o[2].isEmpty ? " [label=\"\(escapeDOT(o[2]))\"]" : ""
            out += "    \"\(escapeDOT(o[0]))\" -> \"\(escapeDOT(o[1]))\"\(nhan);\n"
            return true
        }
        guard cot.count >= 2 else {
            throw Failure(reason: "edge list phải có ít nhất hai cột (source, target)")
        }
        return out + "}\n"
    }

    static func escapeDOT(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Mermaid → đồ thị

    static func mermaidToDOT(_ text: String) throws -> String {
        let g = try mermaidToGraph(text)
        var out = "digraph {\n"
        for n in g.nodes {
            out += "    \"\(escapeDOT(n.name))\" [label=\"\(escapeDOT(n.display))\"];\n"
        }
        for e in g.edges {
            let nhan = e.label.map { " [label=\"\(escapeDOT($0))\"]" } ?? ""
            out += "    \"\(escapeDOT(e.from))\" -> \"\(escapeDOT(e.to))\"\(nhan);\n"
        }
        return out + "}\n"
    }

    /// Đọc flowchart Mermaid. Loại sơ đồ khác thì NÓI RA tên loại.
    static func mermaidToGraph(_ text: String) throws -> DOTGraph {
        let dong = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let khai = dong.first(where: { !$0.isEmpty && !$0.hasPrefix("%%") }) else {
            throw Failure(reason: "sơ đồ rỗng")
        }
        let loai = khai.split(separator: " ").first.map(String.init) ?? khai
        guard loai == "flowchart" || loai == "graph" else {
            throw Failure(reason:
                "chỉ đọc được flowchart; sơ đồ này là «\(loai)» — chuyển tay hoặc dùng DOT làm nguồn.")
        }

        var nhan: [String: String] = [:]
        var edges: [DOTGraph.Edge] = []
        var thuTu: [String] = []
        func ghiNhan(_ id: String, _ label: String?) {
            if !thuTu.contains(id) { thuTu.append(id) }
            if let label, nhan[id] == nil { nhan[id] = label }
        }

        // `A[Nhãn] -->|quan hệ| B(Nhãn khác)` — bắt cả node lẫn cạnh trong một lượt.
        let mauNode = try! NSRegularExpression(
            pattern: #"([A-Za-z0-9_]+)\s*(?:\[\"?([^\]\"]*)\"?\]|\(\"?([^)\"]*)\"?\)|\{\"?([^}\"]*)\"?\})"#)
        let mauCanh = try! NSRegularExpression(
            pattern: #"([A-Za-z0-9_]+)[^\S\n]*(?:\[[^\]]*\]|\([^)]*\)|\{[^}]*\})?\s*-{2,3}>?(?:\|([^|]*)\|)?\s*([A-Za-z0-9_]+)"#)

        for (index, line) in dong.enumerated() {
            if line.isEmpty || line.hasPrefix("%%") || line == khai { continue }
            let ns = line as NSString
            let ca = NSRange(location: 0, length: ns.length)

            for m in mauNode.matches(in: line, range: ca) {
                let id = ns.substring(with: m.range(at: 1))
                var label: String?
                for g in 2 ... 4 where m.range(at: g).location != NSNotFound {
                    label = ns.substring(with: m.range(at: g))
                }
                ghiNhan(id, label)
            }
            if let m = mauCanh.firstMatch(in: line, range: ca) {
                let tu = ns.substring(with: m.range(at: 1))
                let den = ns.substring(with: m.range(at: 3))
                let nhanCanh = m.range(at: 2).location != NSNotFound
                    ? ns.substring(with: m.range(at: 2)) : nil
                ghiNhan(tu, nil); ghiNhan(den, nil)
                edges.append(DOTGraph.Edge(from: tu, to: den, label: nhanCanh, line: index,
                                           weight: nil, attributes: [:]))
            }
        }

        let nodes = thuTu.map {
            DOTGraph.Node(name: $0, label: nhan[$0], line: 0, shape: nil, attributes: [:])
        }
        guard !nodes.isEmpty else {
            throw Failure(reason: "không tìm thấy node nào trong flowchart")
        }
        return DOTGraph(isDirected: true, name: "", nodes: nodes, edges: edges, warnings: [])
    }
}
