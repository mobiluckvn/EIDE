const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-SAD-03', 'Thiết kế kiến trúc', 'THIẾT KẾ KIẾN TRÚC (SAD)',
  'Các góc nhìn kiến trúc của EIDE (Embedded IDE) · theo ISO/IEC/IEEE 42010',
  [['Tài liệu trước', 'EIDE-SRS-02, EIDE-APD-08, EIDE-DPS-09'], ['Tài liệu kế tiếp', 'EIDE-SDD-04 (bản vẽ thi công)']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-SAD-03): 6 nguyên tắc, 11 thành phần, 10 ADR']],
  'Thêm nguyên tắc A7–A9; góc nhìn năng lực (§3.0) với Capability Registry, Orchestrator, PolicyGate/Undo, Discovery, Diagram, Doc, ReqArch, View/RAG; hành vi §4.5 vòng lệnh ngôn ngữ tự nhiên; dữ liệu mới (CapabilityRun, DecisionLog, RagChunk, Discovery); triển khai bản đầu một PC có Internet; ADR-05 sửa, ADR-11…ADR-14',
  [['1.3', '07/09/2026', 'Vũ Trí Công',
    'Thêm ADR-16: kho `eide` viết mới hoàn toàn, không đổi tên hay kế thừa mã `hkw-core` M0; '
    + 'lõi tách sẵn thành package `eide_core/` ngay từ đầu; CLI dùng argparse thay vì typer/rich. '
    + 'Hệ quả: DEP-26 không còn bước migrate `.hkw` → `.eide` (DEV-003).']]);
const c = [];
c.push(H1('1. Giới thiệu và nguyên tắc kiến trúc'));
c.push(P('Tài liệu mô tả kiến trúc EIDE theo các góc nhìn của ISO/IEC/IEEE 42010 [5]: ngữ cảnh, thành phần, hành vi, dữ liệu, triển khai, và các quyết định kiến trúc (ADR). Bảy nguyên tắc sản phẩm P1–P7 của PDA-00 [1] được chuyển thành sáu nguyên tắc kiến trúc: (A1) một Knowledge Plane, nhiều bề mặt; (A2) tác tử không chạm phần cứng, chỉ đề nghị; (A3) mô hình ngôn ngữ không phải nguồn sự thật; (A4) mọi ghi vào tri thức qua một cổng ghi có schema và nhật ký; (A5) mở rộng bằng plugin, không sửa core; (A6) core dùng chung với EAA-U. Phiên bản 1.1 thêm ba nguyên tắc từ APD-08 [26], DPS-09 [27] và Danh mục năng lực [25]: **(A7) mọi chức năng là một năng lực có hợp đồng** trong một Capability Registry duy nhất — giao diện và tác tử điều phối gọi cùng một hợp đồng; **(A8) làm rồi báo cáo** — người quyết định ở mỗi cổng là con người hay chính sách do lớp rủi ro và mức tự chủ xác định, mọi hành động tự làm có bằng chứng, nhật ký và hoàn tác; **(A9) văn bản là nguồn của lược đồ và tài liệu** — lược đồ sinh ở ngôn ngữ GEditor hỗ trợ (Mermaid, PlantUML, DOT, D2, WaveDrom, SVG), tài liệu sinh theo mẫu EAA/EIDE từ tri thức có nguồn, cả hai đồng bộ được với mã và fact.'));
c.push(H1('2. Góc nhìn ngữ cảnh'));
c.push(...IMG('hinh/hkw_arch.png', 600, 415, 'Hình 1. Ngữ cảnh và các khối chính (kế thừa từ PDA-00)'));
c.push(P('Ba bề mặt (GEditor plugin — trong đó cửa sổ trò chuyện là màn hình mặc định, IDE ngoài qua MCP, CLI/CI) là client thuần của Knowledge Plane. Bốn hệ thống ngoài: registry, nguồn tri thức (kho hãng, docs MCP, web), dịch vụ LLM đám mây, phần cứng (board, probe, thiết bị đo, USB/mạng). Không có bề mặt nào giữ trạng thái tri thức riêng; không có hệ thống ngoài nào được gọi mà không qua adapter có nhật ký. Bản đầu tiên: toàn bộ chạy trên một PC của kỹ sư có Internet đầy đủ.'));
c.push(H1('3. Góc nhìn năng lực (mới v1.1)'));
c.push(...IMG('hinh/eide_caps_arch.png', 600, 415, 'Hình 1b. Kiến trúc năng lực: kỹ sư → Orchestrator (bốn trách nhiệm) → Capability Registry (27 nhóm) → Knowledge Plane'));
c.push(P('Lớp năng lực nằm giữa bề mặt và Knowledge Plane. **Capability Registry** giữ 228 khai báo (hợp đồng 13 trường) và ánh xạ mỗi mã tới một hàm hiện thực (`CapabilityImpl`) trong gói tương ứng. Mọi lời gọi — từ nút bấm trên GEditor, từ tool MCP, từ CLI hay từ chuỗi của Orchestrator — đều đi qua `CapabilityRouter.invoke(code, args, ctx)`: kiểm schema tham số, chạy `grounding` của năng lực, hỏi `PolicyGate.decide` theo lớp rủi ro/mức tự chủ, thực thi, ghi `CapabilityRun` vào ledger, và đăng ký hành động hoàn tác nếu có. Nhờ đó "chức năng cho người dùng" và "năng lực cho tác tử" là một thứ. Bốn nhóm dịch vụ mới ở v1.1: **ReqArchService** (req.*, arch.*), **DiagramService** (diagram.*), **DocService** (doc.*, report.*), **DiscoveryService** (discover.*), và **ViewService** (view.*, gồm chỉ mục RAG). Orchestrator (chat.*) và PolicyGate/Undo (policy.*) là hai dịch vụ xuyên suốt.'));
c.push(T([2300, 2600, 4400], ['Dịch vụ', 'Nhóm năng lực', 'Phụ thuộc chính'], [
  ['Orchestrator', 'chat (8)', 'CapabilityRegistry, PolicyGate, Gateway (mô hình hiểu lệnh), PassportStore/KG (grounding), Memory'],
  ['PolicyGate + UndoService', 'policy (7)', 'autonomy.yaml, decision_log, Git (revert), PassportStore (supersede), TargetService (known-good)'],
  ['ReqArchService', 'req (8), arch (11), plan (7)', 'KG (khả thi, xung đột), Passport, Gateway; sinh ReqSet/ModuleGraph/HwMap/ADR'],
  ['DiagramService', 'diagram (14)', 'Bộ render Mermaid/PlantUML/Graphviz/D2/WaveDrom (tiến trình con, sandbox); GEditor hiển thị; lint'],
  ['DocService', 'doc (12), report (4)', 'Mẫu docx-js/markdown chuẩn EAA; DiagramService; KG (trích dẫn); style_check'],
  ['DiscoveryService', 'discover (12)', 'libusb/pyserial/probe-rs/esptool/mDNS qua adapter; Passport (đối chiếu ID); TargetService (auto_setup)'],
  ['ViewService', 'view (13)', 'KG (bản đồ, lân cận, tác động), RAG index (chunk + embedding + từ khóa + đồ thị), GEditor panel'],
  ['AcquisitionService (mở rộng)', 'archive (7), search (9), extract (21), passport (8), kg (9), board (5)', 'ExtractorRegistry, Finder đa nguồn, Sandbox, PassportStore, GraphService'],
  ['AgentRuntime + TargetService (mở rộng)', 'memory (8), code (16), sim (7), target (9), debug (6), measure (3), bench (3), env (7)', 'Gateway, hooks, adapter build/flash/serial/probe/sim/measure, doctor'],
  ['ProjectService, RegistryClient', 'project (9), registry (5)', 'Store, Git, registry index'],
  ['ToolForge (v1.2)', 'tool (10) — năng lực gốc', 'Coder (PRS-16), Sandbox có giám sát hiệu ứng (SEC-25), PolicyGate cổng G-TOOL (POL-17), Capability Registry (nạp nóng user.*), registry (thăng cấp)'],
]));
c.push(SP());
c.push(H1('3A. Góc nhìn thành phần'));
c.push(H2('3.1. Phân rã kho mã'));
c.push(T([2200, 3500, 3600], ['Kho', 'Gói', 'Nội dung'], [
  ['core (dùng chung EAA-U + EIDE)', 'core.engine, core.gateway, core.passport, core.kg, core.targets, core.tools', 'Máy trạng thái + gate + ToolReport; ModelPort + adapter + router + ledger; schema hộ chiếu + store; đồ thị + truy vấn; ISA profile + adapter build/flash/probe/serial/sim/measure; toolchain manifest + doctor'],
  ['eide (sản phẩm; kho hiện tại hkw-core đổi tên)', 'eide.plane, eide.caps, eide.orchestrator, eide.policy, eide.acquire, eide.agents, eide.reqarch, eide.diagram, eide.doc, eide.discover, eide.view, eide.mcp, eide.registry, eide.cli', 'Daemon + API + hàng đợi; Capability Registry + Router; tầng hiểu lệnh; PolicyGate/Undo; extractor + máy trạng thái nhận tri thức; vai trò tác tử + hooks; yêu cầu/kiến trúc; lược đồ; tài liệu; dò board; bản đồ tri thức/RAG; MCP server/client; đóng gói/ký/pull; CLI'],
  ['eide-geditor (Swift)', 'ChatPanel (mặc định), PassportBrowser, ReviewQueue (chờ tôi / đã làm — hoàn tác), BigLogAssist, SerialConsole, HexMap, KnowledgeMap, RagAsk, DiagramView (Mermaid/PlantUML/DOT/D2/WaveDrom/SVG), SimView, AutonomyStatusBar', 'Plugin GEditor giao tiếp JSON-RPC với daemon; mỗi nút bấm gọi một năng lực'],
  ['eide-packs', 'isa/, skills/, bench/, templates/', 'ISA profile và skill khởi đầu; bộ benchmark; gói hạt giống; mẫu dự án tham chiếu (K5′)'],
]));
c.push(SP());
c.push(H2('3.2. Thành phần bên trong Knowledge Plane'));
c.push(T([2200, 4300, 2800], ['Thành phần', 'Trách nhiệm', 'Giao diện'], [
  ['PlaneAPI', 'HTTP/JSON-RPC cục bộ; xác thực phiên; điều phối yêu cầu tới các dịch vụ', 'REST nội bộ + JSON-RPC socket'],
  ['CapabilityRegistry + Router', 'Khai báo 238 năng lực (hợp đồng), ánh xạ tới hiện thực; invoke = kiểm schema → grounding → PolicyGate → thực thi → ledger → đăng ký hoàn tác', 'caps.list/describe/invoke; CapabilityRun'],
  ['Orchestrator', 'Tầng hiểu lệnh (DPS-09): parse_intent, ground, fill_defaults, clarify, restate, orchestrate (đồ thị chuỗi có nhánh), report_back', 'chat.*; run.status'],
  ['PolicyGateService (thay GateService)', 'Hàng đợi gate; quyết định = policy(action, ctx) ∈ {APPROVE, ASK, REJECT} theo autonomy.yaml; quyền theo phiên cho R4; danh sách trắng board lab/gói; cưỡng chế (không có API bỏ qua); dừng khẩn', 'gate.open/decide(by=human|policy)/list; policy.decide; sự kiện push'],
  ['UndoService', 'Cửa sổ hoàn tác cho việc tự làm: supersede fact, git revert merge, nạp lại known-good; hết hạn T', 'undo.list/apply'],
  ['AcquisitionService', 'Máy trạng thái AcquisitionRequest; gọi Finder, ExtractorRegistry, Normalizer', 'acquire.request/candidates/confirm/extract/review'],
  ['ExtractorRegistry', 'Đăng ký extractor theo entry point; sandbox chạy extractor', 'Extractor.extract(path) → Fact[]'],
  ['PassportStore', 'CRUD hộ chiếu/fact/source trên SQLite; kiểm schema; cổng ghi duy nhất', 'store.write(FactBatch), store.query(...)'],
  ['GraphService', 'Nạp/duy trì đồ thị; truy vấn conflicts/impact/evidence/neighborhood; Graph-RAG', 'kg.*'],
  ['AgentRuntime', 'Vai trò, composer, hooks (constant-guard, egress-guard), vòng lặp có giới hạn; dùng core.gateway', 'agent.run(role, task)'],
  ['TargetService', 'Adapter build/flash/serial/probe/sim/measure theo ISA profile; ToolReport; quyền qua GateService', 'target.*'],
  ['Ledger', 'Nhật ký bất biến (JSONL) cho gate, lượt gọi mô hình, tool, trạng thái nhận tri thức', 'ledger.append/query'],
  ['McpServer / McpClient', 'Phơi tool; kết nối docs MCP hãng và probe MCP', 'MCP stdio/HTTP'],
  ['RegistryClient', 'pack/unpack/sign/verify/publish/pull; huy hiệu; mẫu dự án tham chiếu (kind=template)', 'registry.*'],
  ['ReqArchService', 'Thu thập/phân loại yêu cầu, khả thi theo hộ chiếu, mâu thuẫn, ưu tiên, truy vết; kiến trúc: kiểu, phân rã, HwMap, ngân sách RAM/thời gian, FSM, ADR, review, so sánh', 'req.*, arch.*'],
  ['DiagramService', 'Sinh mã lược đồ từ mô hình (BOM/netlist, HwMap, ModuleGraph, FSM, Plan, timing, KG), render qua bộ render trong sandbox, lint, đồng bộ với mã', 'diagram.*'],
  ['DocService', 'Sinh tài liệu chuẩn EAA/EIDE (thuộc tính, lịch sử, hình đánh số, mục Nguồn), tóm tắt datasheet, bring-up, báo cáo kiểm thử, changelog, slide; style_check; sync', 'doc.*, report.*'],
  ['DiscoveryService', 'Dò cổng/probe/chip ID/firmware/nguồn/bus/LAN; dò tốc độ kết nối (auto-baud, SWD/JTAG/SPI/I2C clock) bằng thử nấc và đo lỗi; auto_setup target', 'discover.*'],
  ['ViewService + RagIndex', 'Bản đồ tri thức, lân cận, nguồn gốc, mâu thuẫn, độ phủ, tác động, dòng thời gian; hỏi–đáp RAG có trích dẫn và trace; xây chỉ mục khi nạp tài liệu', 'view.*'],
]));
c.push(SP());
c.push(H1('4. Góc nhìn hành vi'));
c.push(H2('4.1. Máy trạng thái của yêu cầu nhận tri thức'));
c.push(...IMG('hinh/hkw_state.png', 600, 229, 'Hình 2. Vòng đời AcquisitionRequest; hai trạng thái nền vàng cần con người'));
c.push(H2('4.2. Trình tự kịch bản B — sinh driver từ IDE ngoài'));
c.push(...IMG('hinh/hkw_seq_b.png', 600, 338, 'Hình 3. Sequence: Claude Code gọi EIDE; constant-guard; bốn cổng công cụ; G3, G-OPS, G4'));
c.push(H2('4.3. Máy trạng thái điều phối dự án'));
c.push(P('Kế thừa vòng lặp 13 bước của EAA [2] và thêm ba gate mới. Trạng thái: IDLE → KNOWLEDGE (G-SRC, G-FACT) → PLAN (G1) → GENERATE (Coder ↔ hooks ↔ 4 cổng công cụ, ≤ 3 vòng) → REVIEW (Reviewer khác hãng) → MERGE_GATE (G3) → DEPLOY (G-OPS, flash, serial) → OBSERVE (G4) → EVIDENCE (cạnh EVIDENCED_BY, FEATURES.json) → DELIVER (G5, export/publish). Mọi cạnh chuyển trạng thái được kiểm bởi GateService; không có API "force".'));
c.push(H2('4.3b. Cổng theo chính sách (v1.1)'));
c.push(P('Mọi cạnh chuyển trạng thái vẫn đi qua một cổng, nhưng người quyết định ở cổng là PolicyGate trước, con người sau: `decide(action, ctx)` trả APPROVE (thực thi ngay, ghi lý do và bằng chứng, đăng ký hoàn tác — "làm rồi báo cáo"), ASK (đưa vào hàng đợi "chờ tôi" và leo thang theo kênh) hoặc REJECT. Lớp R4 luôn ASK trừ danh sách trắng do người ký. Lệnh "dừng" hạ mức tự chủ về A0 cho phiên và hủy thao tác phần cứng đang chờ (APD-08 §5).'));
c.push(H2('4.4. Vòng gỡ lỗi (kịch bản C)'));
c.push(P('GEditor gửi {file, range, stats} → Debugger nhận ngữ cảnh gồm vùng log, thống kê toàn tệp, hộ chiếu (thanh ghi liên quan qua kg.neighborhood), CodeUnit liên quan (qua USES) → trả Diagnosis{hypotheses[], experiment} → nếu thí nghiệm cần probe/flash: mở G-OPS → TargetService thực thi → chứng cứ nối vào Diagnosis → lưu DebugSession → GEditor neo câu trả lời vào dòng.'));
c.push(H2('4.5. Vòng lệnh ngôn ngữ tự nhiên (v1.1)'));
c.push(...IMG('hinh/eide_nl_loop.png', 600, 328, 'Hình 4. Tám bước của Orchestrator cho một lệnh; hai chế độ gọi năng lực dùng chung hợp đồng'));
c.push(P('Ví dụ chuỗi cho "Đây là bộ tài liệu board robot, hãy dựng tri thức, môi trường và mô phỏng rồi viết firmware đọc BME280 phát UART": project.create → archive.explore → archive.classify → extract.{svd, pdf, bom, image} → passport.build → board.build_passport → board.check_pins → search.missing → search.web/vendor → search.fetch (APPROVE nếu tên miền hãng) → extract.pdf → kg.review_facts (auto theo ngưỡng) → env.check → env.install_tool (danh sách tin cậy) → sim.build → sim.run(hello) → req.elicit → req.ground_hw → arch.decompose → arch.map_hw → diagram.block/architecture → plan.create → code.module → code.review → code.merge (auto/ + hoàn tác) → sim.run(test) → doc.bringup_guide → chat.report_back. Các nhánh ASK trong ví dụ: nguồn ngoài danh sách, fact confidence thấp, feature chạm động cơ (G1), board chưa đánh dấu lab (G-OPS).'));
c.push(H1('5. Góc nhìn dữ liệu'));
c.push(T([2300, 6900], ['Thực thể', 'Thuộc tính chính'], [
  ['Source', 'id, uri, sha256, kind (svd|atdf|edc|binding|header|pdf|docx|html|image|kicad|web), tier, license, fetched_at, confirmed_by'],
  ['Fact', 'id, subject (IRI), predicate, value, unit, source_id, locator (page/bbox/xpath), method, confidence, status, confirmed_by, confirmed_at, supersedes'],
  ['Passport', 'id (ns.part@semver), kind (chip|board|isa), header YAML, fact_ids[], badges[]'],
  ['Node/Edge (KG)', 'Node{type, key, props}; Edge{type: HAS|USES|CITES|SUPERSEDES|CONFLICTS_WITH|EVIDENCED_BY, from, to, props}'],
  ['Feature', 'id, title, status (failing|passing), evidence_ids[]'],
  ['ToolReport', 'tool, passed, log_ref, metrics, artifacts, duration, started_by'],
  ['DebugSession', 'id, log_ref+range, evidence[], hypotheses[], outcome, fact_ids[], code_ids[]'],
  ['GateDecision', 'gate, subject_ref, decision, by, at, note'],
  ['ModelCall', 'role, model_id, request_hash, response_ref, tokens_in/out, latency, cost'],
  ['Capability (khai báo)', 'code, ns, name, desc, input_schema, output_schema, risk (R0–R4), tier (T1/T1*/T2/T3), grounding[], ask_when[], undo (kind), milestone, impl_ref'],
  ['CapabilityRun', 'id, run_id (chuỗi), code, args_hash, actor (human|orchestrator|mcp), decision_id, status, started/finished, result_ref, undo_ref'],
  ['DecisionLog', 'id, gate, action, risk, autonomy_level, decision (APPROVE|ASK|REJECT), by (policy|human), reason, evidence[], features (tier, confidence, source_kind, diff_size…), undone_at'],
  ['Intent / Run', 'Intent{text, intent, slots, confidence, grounded{exists[], candidates[]}, defaults_applied[], question?}; Run{id, intent_id, graph (nút = năng lực, cạnh = điều kiện), state, report}'],
  ['ReqSet / ModuleGraph / HwMap / ADR', 'Requirement{id, kind FR|NFR|HW|SAFETY|RT, text, priority, acceptance[], trace[]}; Module{id, responsibility, interfaces[], depends[], hw[]}; HwMap{module→periph/pin/irq/dma}; ADR{context, options, decision, consequences, citations[]}'],
  ['Diagram', 'id, lang (mermaid|plantuml|dot|d2|wavedrom|svg), src, source_model_ref, rendered_ref, lint[], synced_with (code_unit|module_graph|fsm), stale'],
  ['DocArtifact', 'id, type (URD|SRS|SAD|SDD|STP|bringup|test_report|…), template, sections[], figures[] (Diagram), citations[] (fact/source), style_issues[], stale_sections[]'],
  ['Discovery', 'ports[] {dev, vid, pid, driver}, probes[] {kind, fw}, chip_id {idcode, match_passport}, link_speed {baud|clk, error_rate}, firmware {banner, version}, power, network[]'],
  ['RagChunk', 'id, source_id, locator, text, embedding_ref, keywords[], graph_nodes[]'],
]));
c.push(SP());
c.push(P('Bố trí lưu trữ trong `.eide/` (tên cũ `.hkw/` vẫn được đọc): `store.sqlite` (Source, Fact, Passport, Feature, ToolReport, DebugSession, GateDecision, DecisionLog, CapabilityRun, Discovery, ReqSet, ModuleGraph, Diagram, DocArtifact); `graph.cache`; `index/` (RagChunk + embedding — không commit); `ledger/*.jsonl`; `cache/`; `docs/` và `diagrams/` (tài liệu, lược đồ sinh ra — commit); `PROGRESS.md`, `FEATURES.json`, `models.yaml`, `roles.yaml`, `autonomy.yaml`, `preferences.yaml`, `tools.lock`.'));
c.push(H1('6. Góc nhìn triển khai'));
c.push(T([2600, 6600], ['Cấu hình', 'Mô tả'], [
  ['Một PC kỹ sư có Internet (bản đầu, mặc định)', 'Daemon `eided` chạy nền (launchd/systemd); GEditor plugin (chat mặc định) và CLI nối qua socket; MCP stdio cho Claude Code; LLM đám mây Claude/Gemini qua Gateway; tìm/tải tài liệu, registry Git trên mạng; toolchain, probe, board, USB cục bộ; bộ render lược đồ cài cục bộ'],
  ['Chế độ cục bộ hoàn toàn (tùy chọn, M5)', 'models.yaml offline_mode → OpenAI-compatible adapter tới Ollama/vLLM; egress-guard chặn đám mây; registry = kho Git nội bộ — không phải mặc định của bản đầu'],
  ['CI (GitHub Actions/nội bộ)', 'hkw bench và test hợp đồng Gateway chạy không cần board; job có board tự host cho benchmark HIL'],
  ['Lớp học', 'Registry nội bộ trên một máy chủ Git; học viên pull gói, publish qua pull request'],
]));
c.push(SP());
c.push(H1('7. Quyết định kiến trúc (ADR)'));
c.push(T([900, 2200, 3300, 2900], ['ADR', 'Quyết định', 'Lý do', 'Hệ quả / thay thế đã cân nhắc'], [
  ['ADR-01', 'Knowledge Plane là daemon Python cục bộ, nhiều bề mặt', 'Tránh chiến tranh IDE; tái dùng EAA; MCP là xu thế hãng chip [15], [16]', 'Cần quản lý vòng đời daemon; thay thế: ứng dụng đơn khối (bị loại)'],
  ['ADR-02', 'Tri thức máy-đọc-được trước, PDF sau; ba tầng tin cậy', 'Giảm hallucination; SVD/ATDF phủ hàng nghìn chip [8], [9]', 'Cần parser cho từng định dạng; PDF chỉ cho ngoại vi ngoài'],
  ['ADR-03', 'Fact bất biến + provenance; sửa bằng supersedes', 'Truy vết, phân tích ảnh hưởng, kiểm toán', 'Store lớn hơn; cần dọn phiên bản cũ theo chính sách'],
  ['ADR-04', 'SQLite + NetworkX trong `.hkw/`, không máy chủ', 'Local-first, commit được, đủ cho vài trăm nghìn nút; tiếp nối ADR-07/08 của EAA', 'Khi vượt quy mô: Kùzu/DuckDB nhúng; không dùng Neo4j server'],
  ['ADR-05 (sửa v1.1)', 'Gate cưỡng chế trong PolicyGateService; người quyết định ở gate là chính sách hoặc con người theo lớp rủi ro và mức tự chủ; không có API bỏ qua', 'Kế thừa bất biến EAA; tự động hóa tối đa nơi có bằng chứng và hoàn tác được (APD-08)', 'Cần autonomy.yaml, decision_log, UndoService; R4 vẫn hỏi người'],
  ['ADR-06', 'LLM Gateway mẫu số chung; reviewer khác hãng', 'Độc lập mô hình; giảm lỗi tương quan [3], [19]', 'Không dùng tính năng riêng hãng ở core; adapter có thể'],
  ['ADR-07', 'Extractor/ISA/adapter là plugin qua entry point, chạy trong sandbox', 'Mở rộng không sửa core; an toàn với tệp lạ', 'Cần API plugin ổn định từ M1'],
  ['ADR-08', 'Gói .hkp không chứa tài liệu hãng; ký số; huy hiệu', 'Pháp lý; lòng tin [21]', 'Người dùng phải tự có tài liệu gốc; con trỏ + hash cho phép kiểm'],
  ['ADR-09', 'GEditor plugin thay vì UI mới; nền tảng khác dùng CLI/MCP', 'Tận dụng engine tệp lớn; tránh viết lại', 'Windows/Linux chưa có UI; chấp nhận cho v1'],
  ['ADR-10', 'Một kho core dùng chung EAA-U/EIDE', 'Một lõi, hai bao bì; tránh phân tán', 'Cần kỷ luật phiên bản core (semver) và test hợp đồng'],
  ['ADR-11 (v1.1)', 'Mọi chức năng là năng lực có hợp đồng trong một Capability Registry; UI, MCP, CLI và Orchestrator gọi cùng Router', 'Người và tác tử dùng cùng chính sách, nhật ký, hoàn tác; thêm năng lực không sửa Orchestrator; danh mục là nguồn của FR/TC', 'Chi phí khai báo 13 trường/năng lực; thay thế: tool riêng cho tác tử (bị loại vì hai đường thực thi)'],
  ['ADR-12 (v1.1)', 'Orchestrator tách hiểu lệnh (deterministic: grounding, registry, policy) khỏi sinh (LLM: kế hoạch, mã, chẩn đoán, tài liệu)', 'Giảm ảo giác ở phần điều phối; kiểm thử được bằng Z-01…Z-10; LLM chỉ ở nơi cần sinh', 'Cần schema Intent mẫu số chung; mô hình hiểu lệnh nhỏ/rẻ, mô hình sinh lớn'],
  ['ADR-13 (v1.1)', 'Lược đồ và tài liệu sinh ở dạng văn bản (Mermaid/PlantUML/DOT/D2/WaveDrom/SVG; markdown → docx theo mẫu EAA), render trong GEditor, đồng bộ với mã/fact', 'Diff được, commit được, LLM sinh/sửa được; GEditor đã hỗ trợ [31]–[35]', 'Cần bộ render cài cục bộ (sandbox); bitmap chỉ là đầu ra'],
  ['ADR-16 (v1.3)', 'Kho `eide` viết mới hoàn toàn: không đổi tên hay kế thừa mã `hkw-core` M0; lõi tách sẵn thành package `eide_core/` ngay từ đầu; CLI dùng `argparse` của thư viện chuẩn thay vì typer/rich', 'Bộ hồ sơ v1.2 tái định nghĩa gần như mọi thành phần, nên mang mã M0 sang sẽ tốn nhiều công gỡ hơn viết lại; tách `eide_core/` từ đầu giữ được ADR-10 (một lõi dùng chung với EAA-U) mà không cần một bước tái cấu trúc sau; ít phụ thuộc thì chạy được trên cả ba nền tảng của PLATFORM.md', 'Mất phần đã kiểm chứng của M0 (24 test, 640 chip seed) và phải dựng lại; DEP-26 không còn bước migrate `.hkw` → `.eide`, nên TC-DP-04 đổi thành nâng cấp trong nội bộ `.eide`. Xem DEVIATIONS DEV-003'],
  ['ADR-15 (v1.2)', 'Tác tử được tự viết và chạy công cụ Python (tool.*) với hiệu ứng khai báo, sandbox giám sát, lớp rủi ro suy ra từ hiệu ứng, cổng G-TOOL, đăng ký nóng thành năng lực tạm', 'Không thể thiết kế trước mọi nhu cầu; năng lực gốc cho phép bootstrap các năng lực khác và xử lý tình huống lạ mà vẫn giữ bất biến an toàn', 'Cần giám sát hiệu ứng tin cậy (audit hook, fs watcher); công cụ tạm không vào registry chia sẻ khi chưa duyệt; thay thế: chỉ cho phép năng lực định nghĩa trước (bị loại vì cứng nhắc)'],
  ['ADR-14 (v1.1)', 'Bản đầu tiên: một PC có Internet, LLM đám mây; chế độ cục bộ và đa người dùng là tùy chọn sau', 'Đơn giản hóa để ra bản đầu; tự động hóa cần tìm kiếm mạng và mô hình mạnh', 'Doanh nghiệp nhạy cảm chờ M5; cờ "nhạy cảm" là biện pháp tạm'],
]));
c.push(SP());
c.push(H1('8. Rủi ro kiến trúc và biện pháp'));
c.push(T([3000, 6300], ['Rủi ro', 'Biện pháp'], [
  ['Daemon và plugin lệch phiên bản', 'Handshake phiên bản API khi kết nối; plugin từ chối daemon cũ'],
  ['Extractor độc hại/tệp xấu làm hỏng daemon', 'Sandbox tiến trình con, giới hạn CPU/RAM/thời gian, cách ly đường dẫn'],
  ['Đồ thị trong bộ nhớ vượt RAM', 'Ngưỡng cảnh báo; chuyển Kùzu khi > 1 triệu nút'],
  ['Trễ MCP làm IDE ngoài chờ', 'Tool nặng (build/flash) chạy bất đồng bộ và trả job id; IDE poll'],
  ['Khóa API rò rỉ qua nhật ký', 'Bộ lọc nhật ký; kiểm tự động'],
  ['Orchestrator lập chuỗi sai hoặc vòng lặp vô hạn', 'Đồ thị chuỗi có giới hạn nút/chi phí; mỗi nút qua PolicyGate; thất bại 2 lần ⇒ leo thang; bộ kiểm thử Z-01…Z-10'],
  ['Chính sách tự phê duyệt quá lỏng', 'Ngưỡng chỉ nới khi người xác nhận; R4 không tự động; hoàn tác và dừng khẩn; báo cáo hằng ngày'],
  ['Bộ render lược đồ (Java/PlantUML, Node/Mermaid) nặng hoặc thiếu', 'env.check phát hiện, env.install_tool từ danh sách tin cậy; Mermaid làm mặc định; render trong sandbox'],
  ['Dò tốc độ kết nối làm hỏng giao tiếp hoặc vượt datasheet', 'discover.link_speed chỉ thử nấc trong giới hạn fact có nguồn; đo lỗi trước khi chốt; nấc vượt ⇒ ASK'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-SAD-03_Thiet_ke_kien_truc.docx');
