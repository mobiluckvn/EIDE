import Foundation
import GEditorCore
import JavaScriptCore

/// Hai namespace `jsonl.*` và `graph.*` cho API scripting — FR-KNW-912.
///
/// ## Mọi hàm nhận VĂN BẢN, không nhận đường dẫn
///
/// `jsonl.records(text)` chứ không `jsonl.records(path)`. Đó là quyết định về AN NINH, không
/// phải về gu: API script của GEditor cố ý HẸP (ghi ở `ScriptRunner` từ FR-AUTO-603) — script
/// nhận DỮ LIỆU và trả DỮ LIỆU, nó không đọc file, không mở mạng, không hỏi trạng thái app.
/// Nhận đường dẫn là mở đúng cánh cửa ấy: một script tải về từ đâu đó sẽ đọc được `~/.ssh`.
///
/// Script muốn xử lý một file thì mở file ấy trong GEditor rồi dùng `doc.text` — người dùng vẫn
/// là người quyết định file nào được đọc.
///
/// **Một ngoại lệ, và nó nằm ở phía app chứ không phía script:** `graph.query` phải ghi bảng
/// tạm ra đĩa để DuckDB đọc (cùng đường mà panel Cypher đã đi). Thư mục tạm ấy do **app** chọn,
/// script không nêu tên được — nên tính chất "script không chạm đĩa" vẫn còn nguyên.
///
/// ## Mở rộng thì dễ, thu hẹp thì phá
///
/// Cùng nguyên tắc đã ghi ở `ScriptRunner`: bốn hàm mỗi namespace, không hơn. Thêm một hàm về
/// sau là chuyện nhỏ; bỏ một hàm mà script người dùng đã gọi là phá việc của họ.
enum ScriptKnowledgeAPI {

    /// Gắn hai namespace vào một `JSContext`.
    static func install(into context: JSContext) {
        context.setObject(jsonlNamespace(in: context), forKeyedSubscript: "jsonl" as NSString)
        context.setObject(graphNamespace(in: context), forKeyedSubscript: "graph" as NSString)
    }

    // MARK: - jsonl.*

    private static func jsonlNamespace(in context: JSContext) -> JSValue? {
        let ns = JSValue(newObjectIn: context)

        /// `jsonl.records(text)` → mảng đối tượng. Dòng hỏng bị BỎ QUA ở đây, vì `validate` mới
        /// là hàm trả lời câu "có dòng nào hỏng không" — một hàm làm hai việc thì chỗ gọi không
        /// biết nó vừa nhận dữ liệu đủ hay thiếu.
        ///
        /// `skippingBadLines: true` phải nói RÕ ở đây: mặc định của `chunkObjects` là NÉM, vì
        /// chỗ gọi kia là phép chuyển đổi và bỏ qua dòng ở đó là mất dữ liệu im lặng.
        let records: @convention(block) (String) -> [[String: Any]] = { text in
            (try? KnowledgeConvert.chunkObjects(text, skippingBadLines: true)) ?? []
        }
        ns?.setObject(records, forKeyedSubscript: "records" as NSString)

        /// `jsonl.validate(text)` → `{ok, count, errors:[{line, reason}]}`
        let validate: @convention(block) (String) -> [String: Any] = { text in
            var loi: [[String: Any]] = []
            var dung = 0
            for (i, line) in text.split(separator: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                let doi = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))
                if doi is [String: Any] { dung += 1 } else {
                    // Bọc `L()` chứ không chỉ thêm khoá vào bảng dịch: chuỗi này đi ra ngoài
                    // qua `doc.log` của script, nên nó là chữ NGƯỜI DÙNG đọc.
                    loi.append(["line": i + 1, "reason": L("không phải một đối tượng JSON")])
                }
            }
            return ["ok": loi.isEmpty, "count": dung, "errors": loi]
        }
        ns?.setObject(validate, forKeyedSubscript: "validate" as NSString)

        /// `jsonl.stats(text)` → `{count, fields:{tên: {present, coverage}}}`
        ///
        /// `coverage` đếm ô có GIÁ TRỊ THẬT — chuỗi rỗng không tính, cùng luật `CorpusSQL`
        /// (FR-KNW-907). Hai chỗ trả lời cùng một câu thì phải trả lời giống nhau.
        let stats: @convention(block) (String) -> [String: Any] = { text in
            let doi = (try? KnowledgeConvert.chunkObjects(text, skippingBadLines: true)) ?? []
            var co: [String: Int] = [:]
            for d in doi {
                for (k, v) in d where !v.isEmpty { co[k, default: 0] += 1 }
            }
            var truong: [String: Any] = [:]
            for (k, n) in co {
                truong[k] = ["present": n,
                             "coverage": doi.isEmpty ? 0 : Double(n) * 100 / Double(doi.count)]
            }
            return ["count": doi.count, "fields": truong]
        }
        ns?.setObject(stats, forKeyedSubscript: "stats" as NSString)

        return ns
    }

    // MARK: - graph.*

    private static func graphNamespace(in context: JSContext) -> JSValue? {
        let ns = JSValue(newObjectIn: context)

        let nodes: @convention(block) (String) -> [[String: Any]] = { dot in
            DOTGraph.parse(dot).nodes.map {
                ["name": $0.name, "label": $0.display, "line": $0.line,
                 "kind": $0.kind ?? "", "attributes": $0.attributes]
            }
        }
        ns?.setObject(nodes, forKeyedSubscript: "nodes" as NSString)

        let edges: @convention(block) (String) -> [[String: Any]] = { dot in
            DOTGraph.parse(dot).edges.map {
                ["from": $0.from, "to": $0.to, "label": $0.label ?? "", "line": $0.line]
            }
        }
        ns?.setObject(edges, forKeyedSubscript: "edges" as NSString)

        /// `graph.query(dot, cypher)` → `{titles, rows}`; lỗi trả `{error: "…"}`.
        ///
        /// KHÔNG ném ngoại lệ JavaScript: một script chạy hàng loạt file sẽ dừng hẳn ở file đầu
        /// tiên có cú pháp lạ. Trả lỗi thành DỮ LIỆU để script tự quyết bỏ qua hay dừng.
        let query: @convention(block) (String, String) -> [String: Any] = { dot, cypher in
            do {
                let parsed = try CypherQuery.parse(cypher)
                let translation = try CypherSQL.translate(parsed)
                let folder = NSTemporaryDirectory()
                    + "geditor-script-graph-\(UUID().uuidString)"
                defer { try? FileManager.default.removeItem(atPath: folder) }
                let sources = try CypherSQL.materialize(DOTGraph.parse(dot), in: folder)
                let result = try CorpusSQL.run(translation.sql, sources: sources)
                return ["titles": result.titles,
                        "rows": result.rows.map { $0.map { $0 ?? "" } }]
            } catch {
                return ["error": "\(error)"]
            }
        }
        ns?.setObject(query, forKeyedSubscript: "query" as NSString)

        return ns
    }

    /// Phần thêm vào script mẫu — một ví dụ CHẠY ĐƯỢC cho mỗi namespace.
    ///
    /// Không ai đọc tài liệu API để viết dòng đầu tiên; ghi chú ở `ScriptRunner.example` đã nói
    /// điều đó, và nó đúng gấp đôi với một API mà người dùng chưa biết là có.
    static let exampleAppendix = """

    // ── Tri thức (FR-KNW-912) ────────────────────────────────────────────────
    //
    // Mọi hàm nhận VĂN BẢN, không nhận đường dẫn: script nhận dữ liệu và trả dữ
    // liệu, nó không đọc file. Muốn xử lý một file thì mở file ấy trong GEditor.
    //
    //   jsonl.records(text)   → [{…}, …]
    //   jsonl.validate(text)  → {ok, count, errors:[{line, reason}]}
    //   jsonl.stats(text)     → {count, fields:{tên: {present, coverage}}}
    //   graph.nodes(dot)      → [{name, label, line, kind, attributes}]
    //   graph.edges(dot)      → [{from, to, label, line}]
    //   graph.query(dot, cy)  → {titles, rows} — hoặc {error} nếu câu sai
    //
    // Ví dụ: báo những trường phủ dưới 90% trong corpus đang mở.
    //
    // var s = jsonl.stats(doc.text);
    // doc.log(s.count + " bản ghi");
    // for (var ten in s.fields) {
    //     if (s.fields[ten].coverage < 90) {
    //         doc.log(ten + ": phủ " + s.fields[ten].coverage.toFixed(1) + "%");
    //     }
    // }
    """
}
