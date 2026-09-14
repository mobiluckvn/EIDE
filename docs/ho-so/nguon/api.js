const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas, CAPS, NS_ORDER } = require('./eide_common');
const m = metaNew('EIDE-API-15', 'Đặc tả giao diện lập trình', 'ĐẶC TẢ GIAO DIỆN LẬP TRÌNH: JSON-RPC, MCP, REST, CLI, MÃ LỖI, LEDGER (API)',
  'Đặc tả máy đọc được mọi phương thức, sự kiện, mã lỗi và bản ghi nhật ký của EIDE; phần lớn sinh từ Capability Registry để giao diện người dùng, IDE ngoài, dòng lệnh và tác tử điều phối dùng chung một đường gọi',
  [['Tài liệu trước', 'EIDE-SDD-04 §4.0, §5, §7, §8; EIDE-DDD-14'], ['Tệp kèm', 'api/openrpc.json (JSON-RPC), api/mcp_tools.json (tool MCP sinh từ registry), api/errors.json, api/ledger_events.json'], ['Dùng khi', 'Hiện thực eide/plane/rpc.py, eide/mcp/server.py, eide/cli; plugin GEditor (Swift); test hợp đồng TC-28, TC-65']],
  'Phát hành lần đầu — bổ sung lĩnh vực L26/L33',
  [['1.1', '06/09/2026', 'Vũ Trí Công',
    'DEV-023: tách hai mục methods[].name chứa hai tên gộp bằng " / " thành bốn mục riêng — '
    + 'OpenRPC 1.3 quy định name là MỘT tên phương thức, và một client sinh từ tài liệu ấy không '
    + 'gọi được cái nào trong hai. Số phương thức: 55 → 57.'],
   ['1.2', '06/09/2026', 'Vũ Trí Công',
    '§7: thêm kiểu sự kiện ledger `policy.sign {hash, by, keys[], alg}`. POL-17 §3 đòi ghi việc '
    + 'ký danh sách trắng vào decision_log nhưng không kiểu nào có trường `hash` — mà băm chính là '
    + 'thứ phép đối chiếu .sig ↔ nhật ký cần đọc (DEV-031).'],
   ['1.3', '06/09/2026', 'Vũ Trí Công',
    '§7: thêm kiểu `policy.escalate {ref, reason, channels[], level}`. POL-17 §6 có một máy '
    + 'trạng thái leo thang nhưng không kiểu sự kiện nào ghi được nó, nên hiện thực phải mượn '
    + 'kiểu `question` — và khi đó không phân biệt được câu hỏi thường với câu hỏi đã leo thang, '
    + 'tức chỉ số "bao nhiêu việc phải leo thang" không tính được (DEV-013).'],
   ['1.4', '07/09/2026', 'Vũ Trí Công',
    '§7: `store.write` thêm trường `hash` để nối bản ghi với niêm phong toàn vẹn '
    + '`store.sqlite.seal.json` (DDD-14 §5). CDS-12.3 PROJECT-02 bước 2 đòi kiểm hash store '
    + 'nhưng không sự kiện nào mang được nó (DEV-007).'],
   ['1.5', '07/09/2026', 'Vũ Trí Công',
    '§3: thêm mã lỗi `E1004 OUTPUT_SCHEMA` cho trường hợp kết quả một năng lực không khớp '
    + '`output_schema`. E1000 là tham số vào sai, E5002 là đầu ra mô hình sai — không mã nào '
    + 'dành cho lỗi hiện thực này, nên nó phải mượn E6001 vốn dành cho ghi sai schema dữ liệu '
    + 'DDD-14, làm hai loại lỗi rất khác nhau lẫn vào một mã (DEV-002).'],
   ['1.6', '07/09/2026', 'Vũ Trí Công',
    '§3: danh sách tool nhanh nay IN RA từ chính literal sinh `api/mcp_tools.json`. Trước đó văn '
    + 'xuôi liệt kê 16 tên không khớp năng lực nào trong khi literal có 12 id thật — hai danh sách '
    + 'trong cùng một tài liệu, và literal mới là thứ sinh ra tệp (DEV-045).']]);
const quick = ['passport.query', 'kg.conflicts', 'kg.impact', 'kg.request', 'code.review', 'env.build', 'target.flash', 'target.serial', 'target.probe_read', 'report.export', 'view.rag_ask', 'discover.ports'];
const c = [];
c.push(H1('1. Nguyên tắc'));
c.push(P('Bốn bề mặt gọi (plugin GEditor qua JSON-RPC 2.0 [50] trên Unix socket, IDE ngoài qua MCP [13], REST nội bộ cho CI/kiểm thử, CLI) đều đi tới cùng `CapabilityRouter.invoke` (SDD-04 §4.0). Vì vậy: (1) mọi năng lực tự động là một phương thức `caps.invoke` với `input_schema`/`output_schema` từ khai báo — không viết tay; (2) chỉ có một tập phương thức "khung" (phiên, hàng đợi, chat, sự kiện, job) viết tay và liệt kê dưới đây; (3) mọi lỗi dùng chung bảng mã §6; (4) mọi lời gọi có `request_id` xuất hiện trong ledger để truy vết đầu-cuối; (5) phiên bản API semver trong handshake, thay đổi phá vỡ chỉ ở phiên bản lớn.'));
c.push(H1('2. JSON-RPC 2.0 — GEditor plugin ↔ daemon'));
c.push(P('Socket: `~/.eide/run/eided.sock` (macOS/Linux), named pipe trên Windows; khung tin nhắn: `Content-Length` như LSP; thông báo (notification) từ daemon → plugin dùng phương thức bắt đầu bằng `event.`. Tệp `api/openrpc.json` theo OpenRPC 1.3 [49] chứa toàn bộ schema; bảng dưới là danh sách phương thức khung.'));
const RPC = [
 ['plane.hello', '{plugin_version, client}', '{api_version, daemon_version, project?, capabilities_hash}', 'Handshake; từ chối khi major khác'],
 ['project.list / project.open / project.close', '{} / {path|id} / {}', '{projects[]} / {project, state_summary} / {}', 'Mở dự án = M2 SessionMemory mới'],
 ['session.state', '{}', '{session_id, opened_at, autonomy_effective, stopped, turns, undo_items, permits[], board?}', 'Đọc M2 của phiên đang mở (MEM-11 §2). `permits`/`board` rỗng cho tới khi SessionMemory lưu chúng — DEV-110'],
 ['chat.send', '{text, attachments?[]}', '{intent_id, run_id?}', 'Đưa lệnh vào Orchestrator; kết quả đến qua sự kiện'],
 ['chat.answer', '{question_id, option?, text?}', '{}', 'Trả lời câu hỏi gộp'],
 ['chat.history', '{limit?, before?}', '{turns[]}', 'Từ session.turns'],
 ['caps.list', '{ns?, tier?, risk?, screen?}', '{capabilities[]{code, id, name, desc, risk, tier, ui}}', 'Từ registry'],
 ['caps.describe', '{id}', '{capability (đủ 13 trường + schema)}', ''],
 ['caps.invoke', '{id, args, run_id?}', '{status: ok|pending|rejected, result?, run_id, undo_until?, gate_id?, error?}', 'Đường gọi duy nhất; tool nặng trả job_id trong result'],
 ['queue.list', '{kind: ask|done|all, gate?, limit?}', '{items[]{id, kind, gate, cap, summary, risk, evidence[], deadline?, undo_ref?}}', 'Hàng đợi chờ tôi / đã làm'],
 ['gate.decide', '{gate_id, decision: approve|reject, note?}', '{}', 'Người quyết định mục ASK'],
 ['undo.list / undo.apply', '{} / {undo_ref}', '{items[]} / {result}', 'Hoàn tác việc tự làm'],
 ['autonomy.get / autonomy.set', '{} / {level, board?}', '{effective, project, boards{}} / {}', 'set là R4 khi nới lỏng → gate'],
 ['stop', '{}', '{}', 'Dừng khẩn < 1 s'],
 ['job.status / job.cancel', '{job_id}', '{state, progress, log_tail[], result?}', 'Tool nặng (build, flash, extract, render, install)'],
 ['view.kg_map / view.focus / view.provenance / view.coverage / view.impact / view.timeline', 'theo năng lực view.*', 'GraphView / ProvenanceChain / Heatmap / Timeline', 'Alias caps.invoke để plugin gọi ngắn'],
 ['view.rag_ask / view.rag_trace', '{question, scope?} / {trace_id}', '{answer, citations[], trace_id} / {chunks[], scores[], path[]}', ''],
 ['passport.query / passport.browse', '{part, periph?, reg?, field?} / {id, group}', 'QueryResult / {groups[], facts[]}', '< 200 ms'],
 ['log.register / log.stats / debug.ask', '{path} / {path, range} / {path, range, question}', '{} / {stats} / {answer, session_id}', 'GEditor tính stats native'],
 ['serial.open / serial.close / serial.write / serial.expect', '{port, baud} / {port} / {port, bytes} / {port, pattern, timeout_s}', '{} / {} / {} / {matched, lines[]}', 'Sự kiện serial.line'],
 ['diagram.open / diagram.save', '{src, lang} / {id, src}', '{id, lint[]} / {lint[], sync_diff?}', 'GEditor render'],
 ['doc.open', '{path}', '{sections[], stale[]}', ''],
 ['discover.status', '{}', 'Discovery', 'Cập nhật qua event.discover.changed'],
 ['hex.resolve', '{address}', '{subject, facts[]}', ''],
];
c.push(T([2600, 2400, 2600, 1700], ['Phương thức', 'Tham số', 'Kết quả', 'Ghi chú'], RPC, { size: 19 }));
c.push(SP());
c.push(H2('2.1. Sự kiện (daemon → plugin)'));
const EV = [
 ['event.chat.restated', '{intent_id, text}', 'Thẻ "tôi hiểu là…"'], ['event.chat.question', '{question_id, text, options[], default, timeout_s, remember_as?}', 'Thẻ câu hỏi gộp'],
 ['event.chat.report', '{run_id, done[], waiting[], undo_until?, cost_usd}', 'Thẻ báo cáo cuối'], ['event.run.progress', '{run_id, node_id, cap, state, pct?}', 'Dòng tiến độ chuỗi'],
 ['event.queue.changed', '{kind, added[], removed[]}', ''], ['event.gate.opened', '{gate_id, gate, cap, summary, risk, evidence[]}', 'Mục ASK mới'],
 ['event.undo.registered', '{undo_ref, deadline}', ''], ['event.undo.expired', '{undo_ref}', ''], ['event.autonomy.changed', '{effective, reason}', 'Kể cả STOP'],
 ['event.discover.changed', 'Discovery', 'Cắm/rút board'], ['event.serial.line', '{port, ts, line}', ''],
 ['event.job.progress', '{job_id, pct, log_tail[]}', ''], ['event.knowledge.changed', '{facts_added, facts_superseded, conflicts, stale_code_units[]}', 'Sau extract/review'],
 ['event.doc.stale', '{id, sections[]}', ''], ['event.diagram.stale', '{id, node_ids[]}', ''], ['event.notice', '{level, text, ref?}', 'Cảnh báo chung'],
 // v1.x — năm sự kiện GIÁM SÁT (DEV-107). Mười sáu sự kiện trên chỉ kể những thứ ĐÒI người
 // làm gì đó; năm cái dưới kể những thứ tác tử TỰ làm xong, và ở mức tự chủ cao thì đó mới là
 // phần người cần nhìn. Đo 14/09/2026: 13 trong 26 kiểu sổ cái không có đường nào lên giao diện.
 ['event.gate.decided', '{gate, rule, decision, cap, reason}', 'Cổng tự quyết APPROVE/REJECT — không vào hàng đợi'],
 ['event.model.call', '{role, model, tokens_in, tokens_out, cost_usd, ms}', 'Chi phí; KHÔNG mang nội dung prompt'],
 ['event.tool.report', '{tool, passed, exit_code, duration_ms, log_ref}', 'build/size/sim/install chạy xong'],
 ['event.project.changed', '{id, state, target?}', 'Đổi dự án hoặc đích đã ghim'],
 ['event.chat.intent', '{intent_id, text, caps[]}', 'Tác tử hiểu ý định thành chuỗi năng lực nào'],
];
c.push(T([3000, 3800, 2500], ['Sự kiện', 'Payload', 'Dùng cho'], EV, { size: 19 }));
c.push(SP());
c.push(P('**`session.state`** (v1.x, DEV-110) — đọc M2 của phiên đang mở: `{session_id, opened_at, autonomy_effective, stopped, turns, undo_items, permits[], board}`. MEM-11 §2 kể M2 gồm cả *quyền theo phiên (R4)* và *target đang cắm*; hai trường ấy có trong payload nhưng RỖNG cho tới khi `SessionMemory` lưu chúng — giao diện hiện đúng thứ có thật và nói ra phần chưa có, thay vì vẽ một bảng từ dữ liệu không tồn tại.'));
c.push(SP());
c.push(H1('3. MCP server (cho Claude Code, Cursor, VS Code)'));
c.push(P('Tool MCP được sinh từ registry lúc khởi động: ba tool chung `caps_list`, `caps_describe`, `caps_invoke` + `chat_command` + tối đa 16 tool "nhanh" (một tool = một năng lực hay dùng, schema chính là input_schema của năng lực) để tổng ≤ 20 tool/phiên (ACI). Danh sách nhanh mặc định in ra từ chính literal sinh `api/mcp_tools.json` (xem cuối tài liệu), nên hai chỗ không thể trôi khỏi nhau: ' + quick.map(x => x.replace('.', '_')).join(', ') + '. Tool R3/R4 trả `{status:"pending", gate_id}` khi ASK. Tên tool dùng dấu gạch dưới (MCP không cho dấu chấm). Tệp `api/mcp_tools.json` là đầu ra sinh tự động; kiểm bằng SchemaCompiler mẫu số chung trước khi phơi.'));
c.push(...CODE([
  '{ "name": "caps_invoke", "description": "Gọi một năng lực EIDE theo id (xem caps_list). Đi qua chính sách tự chủ; có thể trả pending khi cần người.",',
  '  "inputSchema": {"type":"object","required":["id","args"],"properties":{"id":{"type":"string"},"args":{"type":"object"},"run_id":{"type":"string"}}} }',
  '{ "name": "chat_command", "description": "Gửi một lệnh ngôn ngữ tự nhiên cho EIDE (như gõ trong cửa sổ trò chuyện).",',
  '  "inputSchema": {"type":"object","required":["text"],"properties":{"text":{"type":"string"}}} }',
]));
c.push(SP());
c.push(H1('4. REST nội bộ (CI, kiểm thử)'));
c.push(T([2800, 1200, 5300], ['Đường dẫn', 'Phương thức', 'Mô tả'], [
  ['/v1/caps', 'GET', 'Danh sách năng lực (= caps.list)'], ['/v1/caps/{id}', 'GET', 'Khai báo'], ['/v1/caps/{id}:invoke', 'POST', 'Body = args; trả như caps.invoke'],
  ['/v1/chat', 'POST', '{text} → {intent_id, run_id}'], ['/v1/runs/{id}', 'GET', 'Trạng thái chuỗi, báo cáo'], ['/v1/jobs/{id}', 'GET', 'Job'],
  ['/v1/queue', 'GET', 'Hàng đợi'], ['/v1/gates/{id}', 'POST', '{decision, note}'], ['/v1/ledger', 'GET', 'Truy vấn sự kiện (from, to, kind)'],
  ['/v1/health', 'GET', 'Phiên bản, dự án, hash store, mức tự chủ, stopped'],
]));
c.push(SP());
c.push(P('Chỉ lắng nghe 127.0.0.1; xác thực bằng token trong `~/.eide/run/token`; CI dùng REST để chạy kịch bản chuẩn không cần GEditor.'));
c.push(H1('5. CLI'));
c.push(T([3400, 5900], ['Lệnh', 'Tham số, mã thoát'], [
  ['eide "<lệnh ngôn ngữ tự nhiên>" [--dry-run] [--ask] [--json]', 'Mặc định; --dry-run in chuỗi không chạy; --ask ép hỏi mọi mặc định; mã thoát 0 xong, 2 đang chờ người (in gate_id), 3 bị từ chối, 1 lỗi'],
  ['eide init [--isa] [--board] [--dir] [--autonomy A0..A4]', 'Tạo .eide/; 0/1'],
  ['eide caps list [--ns] [--tier] [--risk] | describe <id> | invoke <id> [--json args | --arg k=v…]', 'Kết quả JSON khi --json'],
  ['eide chat', 'Chế độ tương tác trong terminal (REPL) thay ChatPanel'],
  ['eide queue [--ask|--done] | eide gate <id> approve|reject [--note] | eide undo <ref> | eide stop | eide autonomy [A0..A4] [--board]', 'Quản trị'],
  ['eide discover [--speed] [--json] | eide flash [--target] | eide serial <port> [--baud auto] | eide sim run <scenario>', 'Phần cứng/mô phỏng (mở gate khi cần)'],
  ['eide ingest <path> | eide acquire "<need>" | eide query <part> [periph] [reg] | eide review [--group] | eide ask "<câu hỏi>" | eide map [--export dot|mermaid]', 'Tri thức'],
  ['eide req analyze [--src] | eide arch design | eide diagram <kind> [--lang] | eide doc <type> [--lang]', 'Kỹ nghệ'],
  ['eide plan <feature> | eide gen <feature> | eide bench [--isa] [--model] | eide publish <id> | eide pull <id@ver> | eide search <q>', 'Kế thừa v1.0'],
  ['eide doctor [--install] [--lock] | eide migrate | eide policy sign | eide resume | eide export <type> | eide rollback', 'Vận hành'],
]));
c.push(SP());
c.push(H1('6. Bảng mã lỗi'));
const ERR = [
 ['E1000', 'INVALID_ARGS', 'Tham số không khớp input_schema', 'Trả chi tiết trường sai; không ghi run'],
 ['E1001', 'UNKNOWN_CAPABILITY', 'id không có trong registry', ''],
 ['E1002', 'API_VERSION', 'Phiên bản plugin/daemon không tương thích', 'Handshake'],
 ['E1003', 'UNAUTHORIZED', 'Token REST sai', ''],
 // E1000 là tham số VÀO sai; E5002 là đầu ra MÔ HÌNH sai schema. Kết quả của một năng lực
 // không khớp `output_schema` không thuộc cả hai: đó là lỗi hiện thực, và Registry kiểm nó
 // ở mọi lời gọi để bắt sớm (STP-05). Trước v1.5 phải mượn E6001 SCHEMA_VIOLATION, vốn dành
 // cho ghi sai schema dữ liệu DDD-14 — nên hai loại lỗi rất khác nhau lẫn vào một mã. DEV-002.
 ['E1004', 'OUTPUT_SCHEMA', 'Kết quả năng lực không khớp output_schema (lỗi hiện thực)', 'Registry kiểm sau mỗi lời gọi'],
 ['E2000', 'GROUNDING_FAILED', 'Tiền điều kiện không thỏa: dự án chưa mở, nguồn không tồn tại, hộ chiếu thiếu', 'Payload {exists[], candidates[], missing[]} để Orchestrator hỏi/dùng luôn'],
 ['E2001', 'ALREADY_EXISTS', 'Tạo trùng (dự án, feature)', 'Kèm phương án reuse|clone|new'],
 ['E3000', 'POLICY_ASK', 'Cần người (không phải lỗi; status pending)', 'gate_id'],
 ['E3001', 'POLICY_REJECT', 'Chính sách từ chối', 'rule, reason'],
 ['E3002', 'STOPPED', 'Phiên đang dừng khẩn', ''],
 ['E3003', 'BUDGET_EXCEEDED', 'Vượt ngân sách ngày', ''],
 ['E4000', 'TOOL_FAILED', 'Công cụ ngoài thất bại (build, flash, render…)', 'ToolReport ref'],
 ['E4001', 'TOOL_MISSING', 'Thiếu công cụ', 'Gợi ý env.install_tool'],
 ['E4002', 'TARGET_NOT_FOUND', 'Không có board/probe phù hợp', 'Gợi ý discover.scan'],
 ['E4003', 'CHIP_ID_MISMATCH', 'ID chip không khớp hộ chiếu', 'Leo thang'],
 ['E4004', 'TIMEOUT', 'Quá thời gian job/serial/probe', ''],
 ['E5000', 'MODEL_ERROR', 'Lỗi gọi mô hình (rate limit, refusal, schema)', 'Router fallback trước khi ném'],
 ['E5001', 'CONTEXT_OVERFLOW', 'Không nén được về ngân sách (CXD-10 §7)', 'Báo cáo lớp'],
 ['E5002', 'OUTPUT_INVALID', 'Đầu ra mô hình sai schema sau 1 lần sửa', ''],
 ['E5003', 'CONSTANT_GUARD', 'Hằng số không nguồn trong mã', 'violations[]'],
 ['E6000', 'STORE_INTEGRITY', 'Hash store lệch / ghi ngoài cổng', 'Yêu cầu rebuild'],
 ['E6001', 'SCHEMA_VIOLATION', 'Ghi sai JSON Schema (DDD-14)', ''],
 ['E6002', 'CONFLICT', 'Fact mâu thuẫn cần người', ''],
 ['E6003', 'MIGRATION_REQUIRED', 'user_version cũ', 'eide migrate'],
 ['E7000', 'UNDO_EXPIRED', 'Quá cửa sổ hoàn tác', ''],
 ['E7001', 'UNDO_FAILED', 'Hoàn tác không thành (revert xung đột…)', 'Leo thang'],
 ['E8000', 'SANDBOX_VIOLATION', 'Extractor/công cụ vượt giới hạn', 'SEC-25'],
 ['E8001', 'LICENSE_BLOCKED', 'License không cho phép', ''],
 ['E8002', 'SENSITIVE_UPLOAD', 'Dự án nhạy cảm cần xác nhận gửi ra ngoài', ''],
];
c.push(T([900, 2300, 3900, 2200], ['Mã', 'Tên', 'Ý nghĩa', 'Payload / xử lý'], ERR, { size: 19 }));
fs.mkdirSync('api', { recursive: true });
fs.writeFileSync('api/errors.json', JSON.stringify(ERR.map(e => ({ code: e[0], name: e[1], meaning: e[2], handling: e[3] })), null, 1));
c.push(SP());
c.push(P('Lỗi JSON-RPC: `{code: -32000 - <mã EIDE>, message, data: {eide_code, payload}}`; REST: HTTP 400 (E1xxx), 409 (E2001, E6002), 202 (E3000 pending), 403 (E3001/E3002/E1003), 424 (E4xxx), 502 (E5000), 500 (E6xxx). CLI ánh xạ sang mã thoát §5.'));
c.push(H1('7. Ledger: sự kiện và schema'));
const LED = [
 ['context.bundle', '{role, hash, tokens{C0..C7}, sources[], compressions[], model_id}', 'CXD-10'],
 ['model.call', '{role, model_id, request_hash, prompt_hash, tokens_in, tokens_out, cache_read_tokens, latency_ms, cost_usd, stop_reason, error_kind?}', 'Gateway'],
 ['cap.run.start / cap.run.finish', '{run_id, cr_id, cap, actor, args_hash, decision_id} / {cr_id, status, result_hash, duration_ms, undo_ref?, error?}', 'Router'],
 ['gate.decision', 'DecisionLog', 'PolicyGate'],
 ['gate.human', '{gate_id, decision, by, note}', 'Người'],
 // POL-17 §3 đòi ghi việc ký danh sách trắng vào decision_log, nhưng tới v1.1 không có kiểu
 // nào cho nó. `gate.human` là chỗ gần nhất, song nó không có trường `hash` — mà băm chính là
 // thứ phép đối chiếu `.sig` ↔ nhật ký cần đọc; nhét băm vào `note` dạng văn xuôi thì bước đối
 // chiếu thành ra phân tích chuỗi tự do. Xem DEVIATIONS DEV-031.
 ['policy.sign', '{hash, by, keys[], alg}', 'eide policy sign'],
 // POL-17 §6 có hẳn một máy trạng thái leo thang, nhưng tới v1.2 không kiểu sự kiện nào ghi
 // được nó — `question` là chỗ gần nhất và nó không phân biệt được câu hỏi thường với câu hỏi
 // ĐÃ leo thang, tức thống kê "bao nhiêu việc phải leo thang" không tính được. DEVIATIONS DEV-013.
 ['policy.escalate', '{ref, reason, channels[], level}', 'policy.escalate'],
 ['undo.register / undo.apply / undo.expire', '{undo_ref, kind, deadline} / {undo_ref, by, result} / {undo_ref}', 'UndoService'],
 ['autonomy.change / stop', '{from, to, by, reason}', ''],
 ['store.write', '{batch_id, n_facts, n_conflicts, actor, reason, hash}', 'PassportStore'],
 ['acq.state', '{acq_id, from, to, by}', 'AcquisitionService'],
 ['tool.report', 'ToolReport', 'TargetService'],
 ['discover.result', 'Discovery', ''],
 ['intent / question / answer / report', 'Intent / Question / {question_id, answer, by: human|timeout} / Report', 'Orchestrator'],
 ['error', 'ErrorLedgerEntry', 'Mọi thành phần'],
 ['session.open / session.summary', '{session_id, project} / {session_id, summary}', ''],
 ['store.migrate', '{from_version, to_version}', ''],
 // `project.clone`/`archive`/`rollback` (CDS-12.3 PROJECT-04/05/07) đều đổi trạng thái một dự án
 // ở mức VẬT THỂ, và bước 3 của PROJECT-04 nói thẳng "ghi ledger project.clone với nguồn" — mà
 // không kiểu nào trong bảng này ghi được. Một kiểu cho cả họ chứ không ba kiểu riêng: chúng
 // luôn được đọc CÙNG NHAU khi dựng lại lịch sử một dự án. DEVIATIONS DEV-081.
 ['project.state', '{op: clone|archive|rollback, project, ref, detail}', 'ProjectService'],
];
c.push(T([2400, 5200, 1700], ['Loại sự kiện', 'Trường', 'Nguồn'], LED, { size: 19 }));
fs.writeFileSync('api/ledger_events.json', JSON.stringify(LED.map(l => ({ kind: l[0], fields: l[1], source: l[2] })), null, 1));
c.push(SP());
c.push(P('Định dạng JSONL: `{ts, kind, request_id, session_id, project, prev_hash, hash, data}`; `hash = sha256(prev_hash + canonical(data))` để chống sửa (TC-MM-08); tệp xoay theo ngày `ledger/YYYY-MM-DD.jsonl`; bộ lọc che chuỗi giống khóa API (regex `sk-|AIza|Bearer `) trước khi ghi.'));
c.push(H1('8. Sinh tự động và test hợp đồng'));
c.push(P('`eide api gen` đọc registry và sinh: `api/openrpc.json` (phương thức khung + `caps.invoke` với `oneOf` theo id được thay bằng mô tả phẳng để tuân thủ mẫu số chung), `api/mcp_tools.json`, tài liệu md. Test hợp đồng: (1) mọi tool MCP compile trên 3 adapter; (2) mọi phương thức JSON-RPC có ví dụ chạy được trong `tests/contract/rpc/*.json`; (3) plugin Swift dùng bộ mã sinh từ openrpc.json (không viết tay chuỗi phương thức); (4) mã lỗi trong mã nguồn chỉ được lấy từ `api/errors.json`.'));
// openrpc skeleton
const openrpc = { openrpc: '1.3.2', info: { title: 'EIDE JSON-RPC', version: '1.0.0' }, methods: RPC.flatMap(r => r[0].split(' / ').map(n => ({ name: n.trim(), summary: r[3], params: [{ name: 'params', schema: { type: 'object', description: r[1] } }], result: { name: 'result', schema: { type: 'object', description: r[2] } } }))).concat(EV.map(e => ({ name: e[0], summary: e[2], params: [{ name: 'params', schema: { type: 'object', description: e[1] } }], result: { name: 'result', schema: { type: 'null' } } }))) };
fs.writeFileSync('api/openrpc.json', JSON.stringify(openrpc, null, 1));
const tools = [{ name: 'caps_list' }, { name: 'caps_describe' }, { name: 'caps_invoke' }, { name: 'chat_command' }].concat(CAPS.filter(x => quick.includes(x.name)).map(x => ({ name: x.name.replace('.', '_'), description: x.desc, capability: x.name, risk: x.risk })));
fs.writeFileSync('api/mcp_tools.json', JSON.stringify(tools, null, 1));
c.push(...refParas(H1));
build(m, c, 'EIDE-API-15_Dac_ta_giao_dien_lap_trinh.docx');
