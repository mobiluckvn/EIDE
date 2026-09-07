const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-SDD-04', 'Thiết kế chi tiết', 'THIẾT KẾ CHI TIẾT (SDD)',
  'Bản vẽ thi công của EIDE (Embedded IDE): cây thư mục, schema dữ liệu, giao diện mô-đun, hợp đồng MCP, CLI · theo IEEE 1016',
  [['Tài liệu trước', 'EIDE-SAD-03, EIDE-APD-08, EIDE-DPS-09, Danh mục năng lực'], ['Tài liệu kế tiếp', 'EIDE-STP-05']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-SDD-04)']],
  'Thêm §4.0 hợp đồng năng lực và Capability Registry/Router; §4.6 Orchestrator; §4.7 PolicyGate/Undo; §4.8 Discovery; §4.9 Diagram; §4.10 Doc; §4.11 ReqArch; §4.12 View/RAG; bảng SQLite mới; autonomy.yaml, preferences.yaml, capabilities/*.yaml; CLI eide "<lệnh>"; JSON-RPC chat/view/diagram; cây thư mục đổi tên eide',
  [['1.3', '07/09/2026', 'Vũ Trí Công',
    '§6 models.yaml: thêm `aliases` (bí danh trong `roles` → mã model THẬT của nhà cung cấp) và '
    + '`pricing` (USD/triệu token). Thiếu `aliases` thì `candidates` là những cái tên không gọi '
    + 'được API nào; thiếu `pricing` thì `policy.daily_budget_usd` không cưỡng chế được và trường '
    + '`cost_usd` của sự kiện `model.call` luôn bằng 0 (DEV-015). Đường dẫn đổi `.hkw/` → `.eide/`.']]);
const c = [];
c.push(H1('1. Giới thiệu'));
c.push(P('Tài liệu mô tả thiết kế ở mức có thể lập trình ngay theo IEEE 1016 [6]: cấu trúc kho mã, schema dữ liệu (JSON Schema 2020-12 [24] và bảng SQLite), giao diện Python của từng mô-đun, hợp đồng tool MCP, hooks, cấu hình và CLI. Mã ví dụ là Python 3.11 với pydantic v2; chữ ký hàm là hợp đồng, thân hàm do lập trình viên (hoặc EAA-U/Claude) hiện thực theo STP.'));
c.push(H1('2. Cấu trúc kho mã'));
c.push(...CODE([
  'core/                          # kho dùng chung (semver, phát hành như gói pip "mobiluck-core")',
  '  core/engine/      state.py gates.py toolreport.py ledger.py',
  '  core/gateway/     port.py request.py adapters/{claude,gemini,openai_compat}.py router.py schema_compiler.py validator.py',
  '  core/passport/    schema/*.json models.py store.py facts.py merge.py',
  '  core/kg/          graph.py queries.py graphrag.py',
  '  core/targets/     isa/*.yaml toolchain.py adapters/{build,flash,serial,probe,sim,measure}.py doctor.py',
  '  core/engine/      + policy.py (PolicyGate, RiskClass, AutonomyLevel) undo.py decision_log.py',
  'eide/                          # sản phẩm (kho hkw-core đổi tên; tên cũ vẫn import được qua alias)',
  '  eide/plane/       app.py api.py rpc.py gate_service.py events.py',
  '  eide/caps/        registry.py router.py schema.py capabilities/*.yaml   # 228 khai báo, 1 tệp/nhóm',
  '  eide/orchestrator/ intent.py ground.py defaults.py clarify.py chain.py runner.py report.py prompts/',
  '  eide/acquire/     request.py finder.py registry_ext.py extractors/{base,svd,atdf,edc,binding,header,pdf,office,html,image,bom,netlist,kicad,archive}.py normalizer.py review.py sandbox.py',
  '  eide/agents/      roles.py composer.py hooks/{constant_guard,egress_guard}.py runtime.py prompts/',
  '  eide/reqarch/     elicit.py classify.py feasibility.py conflicts.py trace.py arch/{style,decompose,hwmap,budget,fsm,adr,review}.py',
  '  eide/diagram/     models.py generators/{block,pinmap,architecture,sequence,state,flow,timing,memory_map,kg_view,gantt}.py render/{mermaid,plantuml,dot,d2,wavedrom,svg}.py lint.py sync.py from_image.py',
  '  eide/doc/         templates/ (eaa_doc.js port) generate.py sections.py api_ref.py datasheet_summary.py bringup.py test_report.py style_check.py sync.py translate.py slides.py',
  '  eide/discover/    ports.py probes.py chip_id.py board_match.py bus_scan.py link_speed.py clock.py power.py firmware.py network.py env_hw.py auto_setup.py',
  '  eide/view/        kg_map.py provenance.py coverage.py impact.py timeline.py rag/{index,chunk,embed,retrieve,trace,compare}.py export.py',
  '  eide/mcp/         server.py client.py tools.py         # tool = năng lực phơi qua Router',
  '  eide/registry/    pack.py sign.py publish.py pull.py seed/{svd_seed,atdf_seed}.py templates.py',
  '  eide/cli/         main.py commands/*.py                # eide "<lệnh NL>" là lệnh mặc định',
  '  tests/            unit/ contract/ dialog/ (Z-01…Z-10) bench/',
  'eide-geditor/                  # Swift, plugin GEditor (ChatPanel mặc định)',
  'eide-packs/       isa/ skills/ bench/ templates/ (mẫu dự án tham chiếu)',
]));
c.push(SP());
c.push(H1('3. Thiết kế dữ liệu'));
c.push(H2('3.1. Schema Fact (JSON Schema 2020-12, rút gọn)'));
c.push(...CODE([
  '{ "$id": "https://hkw.code247.ai/schema/fact.json", "type": "object", "required": ["id","subject","predicate","value","source_id","tier","confidence","status"],',
  '  "properties": {',
  '    "id": {"type":"string","pattern":"^f_[0-9a-f]{16}$"},',
  '    "subject": {"type":"string","description":"IRI: chip:st.stm32f411ce/periph:I2C1/reg:CR1/field:PE"},',
  '    "predicate": {"type":"string","enum":["base_address","offset","bit_range","reset_value","enum","pin_function","voltage_range","timing","irq","description","net","address","other"]},',
  '    "value": {}, "unit": {"type":"string"},',
  '    "source_id": {"type":"string"}, "locator": {"type":"object","properties":{"page":{"type":"integer"},"bbox":{"type":"array","items":{"type":"number"},"minItems":4,"maxItems":4},"xpath":{"type":"string"},"line":{"type":"integer"}}},',
  '    "method": {"type":"string","enum":["parser","layout_llm","vision_llm","manual","inferred"]},',
  '    "tier": {"type":"string","enum":["gold","silver","bronze"]}, "confidence": {"type":"number","minimum":0,"maximum":1},',
  '    "status": {"type":"string","enum":["normalized","reviewed","verified","rejected","superseded"]},',
  '    "confirmed_by": {"type":"string"}, "confirmed_at": {"type":"string","format":"date-time"}, "supersedes": {"type":"string"} },',
  '  "additionalProperties": false }',
]));
c.push(SP());
c.push(H2('3.2. Bảng SQLite (store.sqlite, chế độ WAL)'));
c.push(T([2200, 7100], ['Bảng', 'Cột chính và chỉ mục'], [
  ['source', 'id PK, uri, sha256 UNIQUE, kind, tier, license, fetched_at, confirmed_by, meta JSON'],
  ['fact', 'id PK, subject, predicate, value JSON, unit, source_id FK, locator JSON, method, tier, confidence, status, confirmed_by, confirmed_at, supersedes; INDEX(subject, predicate, status)'],
  ['passport', 'id PK (ns.part@semver), kind, header YAML, created_at, badges JSON'],
  ['passport_fact', 'passport_id FK, fact_id FK, PK(passport_id, fact_id)'],
  ['acq_request', 'id, need, part, peripheral, state, created_at, updated_at, candidates JSON, decisions JSON'],
  ['feature', 'id, title, status, evidence JSON, updated_at'],
  ['tool_report', 'id, tool, passed, log_ref, metrics JSON, artifacts JSON, duration_ms, started_by, at'],
  ['debug_session', 'id, log_ref, range_start, range_end, evidence JSON, hypotheses JSON, outcome, fact_ids JSON, code_ids JSON, at'],
  ['gate_decision', 'id, gate, subject_ref, decision, by, at, note'],
  ['permission', 'session_id, op (flash|erase|write_mem|install|fuse), granted_by, granted_at, expires_at'],
  ['code_unit', 'id, path, symbol, hash, cites JSON (fact ids), uses JSON (subject IRIs)'],
  ['capability_run', 'id, run_id, code, args_hash, actor (human|orchestrator|mcp|cli), decision_id FK, status, started_at, finished_at, result_ref, undo_ref; INDEX(run_id), INDEX(code, started_at)'],
  ['decision_log', 'id, gate, action, risk, autonomy_level, decision (APPROVE|ASK|REJECT), by (policy|human), reason, evidence JSON, features JSON, undone_at; INDEX(gate, decision, by)'],
  ['intent / run', 'intent: id, text, intent, slots JSON, confidence, grounded JSON, defaults JSON, question JSON, at; run: id, intent_id, graph JSON, state, report JSON, cost'],
  ['requirement', 'id, kind (FR|NFR|HW|SAFETY|RT), text, priority (M|S|C|W), acceptance JSON, trace JSON, status'],
  ['module / hw_map / adr', 'module: id, name, responsibility, interfaces JSON, depends JSON; hw_map: module_id, resource IRI, role, PK(module_id, resource); adr: id, title, context, options JSON, decision, consequences, citations JSON, at'],
  ['diagram', 'id, lang, src, source_ref, rendered_ref, lint JSON, synced_with, stale, at'],
  ['doc_artifact', 'id, type, template, path, citations JSON, style_issues JSON, stale_sections JSON, at'],
  ['discovery', 'id, at, ports JSON, probes JSON, chip_id JSON, link_speed JSON, firmware JSON, power JSON, network JSON, target_config JSON'],
  ['rag_chunk (trong index/index.sqlite, không commit)', 'id, source_id, locator JSON, text, embedding BLOB, keywords, graph_nodes JSON; FTS5 trên text'],
  ['preference', 'key, scope (user|project), value JSON, learned_from decision_id, at'],
]));
c.push(SP());
c.push(H2('3.3. Đồ thị'));
c.push(P('Đồ thị được tái dựng từ store khi mở dự án (không phải nguồn sự thật): nút từ passport/fact/code_unit/feature/debug_session; cạnh HAS từ cấu trúc IRI của subject; USES và CITES từ code_unit; SUPERSEDES từ fact.supersedes; CONFLICTS_WITH do merge tạo; EVIDENCED_BY từ feature.evidence. Cache `graph.cache` (pickle của NetworkX) có hash của store để vô hiệu khi store đổi.'));
c.push(H1('4. Giao diện mô-đun (Python)'));
c.push(H2('4.0. Hợp đồng năng lực và Capability Registry (mới v1.1)'));
c.push(P('Mỗi năng lực trong Danh mục [25] là một tệp khai báo YAML (một tệp cho mỗi nhóm) và một hàm hiện thực đăng ký qua decorator. Khai báo là nguồn duy nhất cho: schema tool MCP, mô tả năng lực cho Orchestrator (đưa vào prompt hiểu lệnh), lớp rủi ro/mức cho PolicyGate, sinh bảng FR trong SRS và TC trong STP.'));
c.push(...CODE([
  '# eide/caps/capabilities/extract.yaml (trích)',
  '- code: EXTRACT-05',
  '  id: extract.bom',
  '  name: Trích xuất BOM',
  '  desc: Trích BOM từ schematic/CSV/XLSX/ảnh → linh kiện {ref, MPN, value, qty}; ánh xạ MPN → hộ chiếu',
  '  input:  {type: object, properties: {source: {type: string}, kind: {type: string, enum: [schematic, csv, xlsx, image]}}, required: [source]}',
  '  output: {type: object, properties: {parts: {type: array, items: {type: object}}, unmatched: {type: array, items: {type: string}}}}',
  '  risk: R1',
  '  tier: T1',
  '  grounding: [source_exists, project_open]',
  '  ask_when: ["MPN không khớp hộ chiếu nào và không tìm được trên registry/web"]',
  '  undo: {kind: supersede_facts}',
  '  milestone: M1',
  '  ui: {screen: passport, action: "Trích BOM"}',
  '',
  '# eide/caps/registry.py',
  'class Capability(BaseModel): code: str; id: str; name: str; desc: str; input: dict; output: dict; risk: RiskClass; tier: Tier; grounding: list[str]; ask_when: list[str]; undo: Undo|None; milestone: str; ui: dict|None; impl: str',
  'class CapabilityRegistry:',
  '    def load(self, dir: Path) -> None                       # đọc YAML, kiểm 13 trường, kiểm schema mẫu số chung (sâu ≤ 3, không anyOf/$ref)',
  '    def get(self, id_or_code: str) -> Capability',
  '    def list(self, ns: str|None=None, tier: str|None=None) -> list[Capability]',
  '    def describe_for_llm(self, ids: list[str]) -> str       # mô tả ngắn + ví dụ gọi, ≤ 60 token/năng lực',
  'def capability(id: str):                                    # decorator đăng ký hiện thực',
  '    def wrap(fn): REGISTRY.bind(id, fn); return fn',
  '    return wrap',
  '',
  '# eide/caps/router.py — ĐƯỜNG GỌI DUY NHẤT cho UI, MCP, CLI, Orchestrator',
  'class CapabilityRouter:',
  '    def invoke(self, id: str, args: dict, ctx: CallContext) -> CapabilityResult:',
  '        cap = self.registry.get(id); self.validate(cap.input, args)',
  '        for g in cap.grounding: self.grounding[g](args, ctx)   # ném GroundingError{exists[], candidates[]} → Orchestrator hỏi/dùng luôn',
  '        d = self.policy.decide(Action(cap=cap, args=args), ctx)   # APPROVE | ASK | REJECT',
  '        if d.decision == "ASK": return CapabilityResult.pending(gate_id=self.gates.open(d))',
  '        if d.decision == "REJECT": return CapabilityResult.rejected(d.reason)',
  '        run = self.ledger.start_run(cap, args, ctx.actor, d.id)',
  '        out = cap.impl(args, ctx)                              # có timeout theo cap.milestone/kind; tool nặng trả job_id',
  '        if cap.undo: self.undo.register(run, cap.undo, out)',
  '        self.ledger.finish_run(run, out); return CapabilityResult.ok(out, run_id=run.id, undo_until=self.undo.deadline(run))',
  'class CallContext(BaseModel): actor: Literal["human","orchestrator","mcp","cli"]; project: ProjectRef; session: str; autonomy: AutonomyLevel; run_id: str|None',
]));
c.push(SP());
c.push(H2('4.1. core.passport'));
c.push(...CODE([
  'class Fact(BaseModel): ...                      # theo schema 3.1',
  'class FactBatch(BaseModel): facts: list[Fact]; passport_id: str | None; reason: str',
  'class PassportStore:',
  '    def write(self, batch: FactBatch, actor: str) -> WriteResult      # CỔNG GHI DUY NHẤT: kiểm schema, merge, ledger',
  '    def query(self, part: str, peripheral: str|None=None, register: str|None=None, field: str|None=None, include_history=False) -> QueryResult',
  '    def supersede(self, old_id: str, new: Fact, actor: str) -> Fact',
  '    def passports(self, kind: str|None=None) -> list[PassportHeader]',
  'class QueryResult(BaseModel): facts: list[Fact]; citations: list[Citation]; tiers: dict[str,int]; latency_ms: int',
]));
c.push(SP());
c.push(H2('4.2. hkw.acquire'));
c.push(...CODE([
  'class Extractor(Protocol):                       # plugin qua entry point "hkw.extractors"',
  '    kinds: set[str]                              # {"svd"} | {"pdf"} | {"zip","7z","tar"} ...',
  '    def sniff(self, path: Path) -> float         # 0..1: mức tin nhận diện theo nội dung',
  '    def extract(self, path: Path, ctx: ExtractContext) -> ExtractResult   # facts[], children[] (tệp con từ nén), warnings[]',
  'class Finder:',
  '    def candidates(self, req: AcquisitionRequest) -> list[Candidate]      # registry → local → vendor → web; KHÔNG tải',
  'class AcquisitionService:',
  '    def request(self, need: str, part: str|None, peripheral: str|None) -> AcquisitionRequest',
  '    def confirm(self, req_id: str, chosen: list[str], actor: str) -> None  # G-SRC',
  '    def extract(self, req_id: str) -> ExtractSummary                       # chạy trong Sandbox',
  '    def review(self, req_id: str, group: str, decision: Decision, actor: str) -> None   # G-FACT',
  'class Sandbox: run(extractor, path, limits: Limits{cpu_s=60, mem_mb=1024, wall_s=300, allowed_dirs}) -> ExtractResult',
]));
c.push(SP());
c.push(H2('4.3. core.gateway (kế thừa EAA-U)'));
c.push(...CODE([
  'class ModelRequest(BaseModel): role: str; messages: list[Msg]; tools: list[ToolDef]=[]; output_schema: dict|None; budget: Budget; images: list[Image]=[]',
  'class ModelResponse(BaseModel): text: str|None; tool_calls: list[ToolCall]; structured: dict|None; usage: Usage; stop_reason: Literal["end","tool_use","max_tokens","refusal"]; raw: Any',
  'class ModelPort(Protocol):',
  '    def complete(self, req: ModelRequest) -> ModelResponse',
  '    def count_tokens(self, req: ModelRequest) -> int',
  '    def capabilities(self) -> Caps                 # context, max_output, vision, parallel_tools, json_mode',
  'class Router: pick(role: str, need: Need) -> ModelPort   # theo models.yaml; ghi lý do vào ledger',
  'class Validator: check(resp, schema, semantic: Callable) -> Verdict   # 2 lớp, 1 lần sửa',
]));
c.push(SP());
c.push(H2('4.4. hkw.agents và hooks'));
c.push(...CODE([
  'class Role(BaseModel): name: str; system_prompt: Path; skills_max: int=3; tools: list[str]; budget: Budget; output_schema: dict',
  'class AgentRuntime:',
  '    def run(self, role: str, task: Task, ctx: ProjectContext) -> RoleOutput   # composer → gateway → validator → hooks',
  'class Hook(Protocol): stage: Literal["pre_tool","post_tool","pre_write"]; def __call__(self, ev: HookEvent) -> HookVerdict',
  'class ConstantGuard(Hook):   # pre_write: quét /0x[0-9A-Fa-f]+|\\b\\d+\\b/ trong ngữ cảnh địa chỉ/bit; mỗi hằng số cần "// hkw:fact f_..." khớp store',
  'class EgressGuard(Hook):     # pre_tool: chặn adapter đám mây và upload khi offline_mode',
]));
c.push(SP());
c.push(P('Quy ước chú thích trong mã sinh ra: mỗi hằng số phần cứng kèm `/* hkw:fact f_1a2b... */` (C/C++) hoặc `# hkw:fact ...` (Python/Rust). ConstantGuard chỉ chấp nhận fact có status ∈ {reviewed, verified} hoặc tier = gold; fact bạc chưa duyệt → chặn và tạo AcquisitionRequest tự động.'));
c.push(H2('4.5. core.targets'));
c.push(...CODE([
  'class ISAProfile(BaseModel): id: str; abi: dict; interrupts: dict; toolchain: ToolchainManifest; debug: DebugManifest; sim: SimManifest; skills: list[Path]',
  'class BuildAdapter(Protocol):  def build(self, project: Path, profile: ISAProfile) -> ToolReport',
  'class FlashAdapter(Protocol):  def flash(self, artifact: Path, target: TargetRef, verify=True) -> ToolReport   # yêu cầu Permission(op="flash")',
  'class SerialDaemon:  open(port, baud) / read(n) / expect(pattern, timeout_s) / write(bytes) / stats()',
  'class ProbeAdapter(Protocol):  list/connect/halt/run/step/read_memory/write_memory*/set_breakpoint/diagnose_fault/unwind   # * cần Permission',
  'class SimAdapter(Protocol):    run(artifact, scenario) -> ToolReport',
  'class ToolReport(BaseModel): tool: str; passed: bool; log_ref: str; metrics: dict; artifacts: list[str]; duration_ms: int',
]));
c.push(SP());
c.push(H2('4.6. eide.orchestrator (tầng hiểu lệnh, DPS-09)'));
c.push(...CODE([
  'class Intent(BaseModel): text: str; intent: str; slots: dict; is_big: bool; confidence: float; lang: Literal["vi","en"]',
  'class Grounded(BaseModel): exists: list[Entity]; candidates: list[Entity]; missing: list[str]',
  'class Question(BaseModel): text: str; options: list[Option]; default: int; timeout_s: int      # D3: tối đa một câu/lượt',
  'class ChainNode(BaseModel): id: str; cap: str; args: dict; when: str|None; on_ask: Literal["wait","skip","parallel"]',
  'class Orchestrator:',
  '    def parse_intent(self, text: str, ctx) -> Intent            # mô hình hiểu lệnh (rẻ) với output_schema Intent; registry.describe_for_llm(top-k theo từ khóa)',
  '    def ground(self, it: Intent, ctx) -> Grounded               # D1: tra project/passport/board/feature/registry (khớp gần đúng)',
  '    def fill_defaults(self, it: Intent, g: Grounded, ctx) -> Intent   # D2: autonomy.yaml.defaults, preferences.yaml, suy từ câu; ghi ledger',
  '    def clarify(self, it: Intent, g: Grounded) -> Question|None # D3: chỉ khi thiếu mặc định hoặc không hoàn tác',
  '    def restate(self, it: Intent, chain: list[ChainNode]) -> str  # D6',
  '    def plan_chain(self, it: Intent, g: Grounded, ctx) -> list[ChainNode]   # lệnh lớn → đồ thị; nút T1 không phụ thuộc chạy trước (D4)',
  '    def run(self, chain, ctx) -> Run                              # mỗi nút: router.invoke; ASK ⇒ on_ask; thất bại 2 lần ⇒ policy.escalate; tiếp tục sau tắt máy',
  '    def report(self, run: Run) -> Report                          # D8/APD §5: đã làm, chờ người, hoàn tác đến, chi phí; memory.remember(choices)',
]));
c.push(SP());
c.push(H2('4.7. core.engine.policy và undo (APD-08)'));
c.push(...CODE([
  'class RiskClass(str, Enum): R0="R0"; R1="R1"; R2="R2"; R3="R3"; R4="R4"',
  'class AutonomyLevel(int, Enum): A0=0; A1=1; A2=2; A3=3; A4=4',
  'class Decision(BaseModel): id: str; decision: Literal["APPROVE","ASK","REJECT"]; reason: str; evidence: list[str]; features: dict',
  'class PolicyGate:',
  '    def decide(self, action: Action, ctx: CallContext) -> Decision:',
  '        if action.risk == R4 and not self.whitelist.allows(action): return ASK("R4")',
  '        if ctx.autonomy < MIN_LEVEL[action.risk]: return ASK("autonomy")',
  '        return self.rules[action.gate](action, ctx)           # G-SRC/G-FACT/G1/G3/G-OPS/G4/G5 theo autonomy.yaml.thresholds',
  '    def emergency_stop(self, session) -> None                # hạ A0, hủy hardware pending',
  '    def propose_thresholds(self) -> list[Proposal]           # từ decision_log; chỉ áp dụng khi người xác nhận',
  'class UndoService:',
  '    def register(self, run, undo: Undo, out) -> str; def apply(self, undo_ref) -> None; def list(self, session) -> list[UndoItem]',
  '    # kind: supersede_facts | git_revert | reflash_known_good | delete_created_files | none',
]));
c.push(SP());
c.push(H2('4.8. eide.discover'));
c.push(...CODE([
  'class Port(BaseModel): dev: str; vid: int; pid: int; driver: str|None; kind: Literal["serial","jtag","swd","usb"]',
  'class Probe(BaseModel): kind: Literal["stlink","jlink","cmsis-dap","pickit","esp-usb-jtag","ftdi","avrisp"]; serial: str; fw: str|None',
  'class ChipIdentity(BaseModel): method: Literal["idcode","device_id","signature","jedec","bootloader"]; raw: str; passport_match: str|None; confidence: float',
  'class LinkSpeed(BaseModel): kind: Literal["baud","swd","jtag","spi","i2c"]; chosen: int; tried: list[tuple[int,float]]; limit_fact: str   # (nấc, tỷ lệ lỗi); giới hạn trích từ fact có nguồn',
  'class DiscoveryService:',
  '    def ports(self) -> list[Port]; def probes(self) -> list[Probe]                         # pyserial/libusb, probe-rs list, esptool',
  '    def chip_id(self, probe: Probe) -> ChipIdentity                                        # R0; đối chiếu PassportStore',
  '    def link_speed(self, target: TargetRef, kind: str) -> LinkSpeed                        # thử nấc tăng dần ≤ limit_fact; đo lỗi 1.000 khung; R1',
  '    def board_match(self, ev: Evidence) -> list[Candidate]                                 # chip_id + bus_scan + image/BOM → registry/web',
  '    def auto_setup(self, d: Discovery) -> TargetConfig                                     # adapter ISA, openocd/probe-rs cfg, cổng, tốc độ → .eide/target.yaml',
]));
c.push(SP());
c.push(H2('4.9. eide.diagram'));
c.push(...CODE([
  'class Diagram(BaseModel): lang: Literal["mermaid","plantuml","dot","d2","wavedrom","svg"]; src: str; source_ref: str|None',
  'class Generator(Protocol): def generate(self, model: Any, opts: dict) -> Diagram      # block(BOM+netlist), pinmap(HwMap), architecture(ModuleGraph, C4), sequence(scenario), state(FSM), flow(code|text), timing(facts), memory_map(passport, ld), kg_view(query), gantt(Plan)',
  'class Renderer:  def render(self, d: Diagram, fmt: Literal["svg","png"]) -> Path       # mmdc / plantuml.jar / dot / d2 / wavedrom-cli trong Sandbox; GEditor render trực tiếp src',
  'class Linter:    def lint(self, d: Diagram, model: Any|None) -> list[Issue]             # cú pháp; nút mồ côi; tên không khớp mã/module',
  'class Sync:      def diff(self, d: Diagram, code_or_model) -> Diff; def apply(...)      # FSM ↔ mã máy trạng thái; architecture ↔ ModuleGraph',
]));
c.push(SP());
c.push(H2('4.10. eide.doc'));
c.push(...CODE([
  'class DocSpec(BaseModel): type: Literal["URD","SRS","SAD","SDD","STP","BPD","bringup","test_report","api_ref","datasheet_summary","changelog","slides"]; scope: dict; lang: Literal["vi","en"]',
  'class DocService:',
  '    def generate(self, spec: DocSpec, ctx) -> DocArtifact      # sections từ tri thức (ReqSet, ModuleGraph, fact, ToolReport) → markdown có trích dẫn → docx theo mẫu EAA (thuộc tính, lịch sử, hình đánh số, mục Nguồn)',
  '    def embed_diagram(self, doc, diagram: Diagram, caption) -> DocArtifact',
  '    def style_check(self, doc) -> list[Issue]                   # tiếng Việt ưu tiên; thuật ngữ Anh có giải nghĩa; mọi khẳng định số liệu có fact/source; định dạng bộ hồ sơ',
  '    def sync(self, delta: Delta) -> list[StaleSection]           # fact/mã/kiến trúc đổi → mục lỗi thời',
]));
c.push(SP());
c.push(H2('4.11. eide.reqarch'));
c.push(...CODE([
  'class Requirement(BaseModel): id: str; kind: Literal["FR","NFR","HW","SAFETY","RT"]; text: str; priority: Literal["M","S","C","W"]; acceptance: list[str]; trace: list[str]; source: str',
  'class ReqArchService:',
  '    def elicit(self, text, sources) -> list[Requirement]; def classify(...); def ground_hw(self, reqs, passport) -> FeasibilityReport',
  '    def detect_conflict(self, reqs) -> list[Issue]; def prioritize(...); def trace_matrix(self, project) -> Matrix; def acceptance(...); def change_impact(self, delta) -> ImpactReport',
  '    def style_select(self, reqs, passport) -> ArchDecision       # super_loop | event_driven | rtos | layered; theo NFR thời gian thực, RAM, số ngoại vi',
  '    def decompose(self, reqs, arch) -> ModuleGraph; def map_hw(self, mg, passport) -> HwMap  # kiểm xung đột chân/timer/DMA qua board.check_pins',
  '    def memory_budget(...); def timing_budget(...); def interface_spec(...); def state_machine(...) -> FSM; def adr(...) -> ADR; def review(...) -> list[Finding]; def compare(...) -> Comparison; def to_plan(self, mg) -> Plan',
]));
c.push(SP());
c.push(H2('4.12. eide.view và chỉ mục RAG'));
c.push(...CODE([
  'class RagIndex:',
  '    def build(self, sources: list[Source]) -> IndexStatus   # chunk (≤ 800 token, theo bố cục Docling/OCR/mã) → embedding qua Gateway → FTS5 từ khóa → gắn nút KG (subject IRI trong chunk)',
  '    def retrieve(self, q: str, scope, k=8) -> list[Hit]      # lai: từ khóa + vector + lan tỏa KG 2 bước (Graph-RAG [37]); mỗi Hit có locator để mở đúng trang',
  'class ViewService:',
  '    def kg_map(self, project, filter) -> GraphView; def kg_focus(self, node, depth) -> GraphView; def provenance(self, fact_id) -> ProvenanceChain',
  '    def conflict_board(...); def coverage_map(self, passport) -> Heatmap; def impact_map(self, delta) -> GraphView; def timeline(self, range) -> Timeline',
  '    def rag_ask(self, question, scope) -> Answer{text, citations[], trace_id}; def rag_trace(self, trace_id) -> Trace; def rag_compare(self, question) -> Comparison',
  '    def export_map(self, view, fmt: Literal["dot","graphml","svg","png","mermaid"]) -> Path',
]));
c.push(SP());
c.push(H1('5. Hợp đồng tool MCP'));
c.push(T([2300, 3400, 3600], ['Tool', 'Đầu vào', 'Đầu ra / ghi chú'], [
  ['passport.query', '{part, peripheral?, register?, field?}', '{facts[], citations[], tiers}; < 200 ms'],
  ['passport.list', '{kind?}', '{passports[]}'],
  ['kg.conflicts', '{project}', '{conflicts[]: {type, nodes, detail}}'],
  ['kg.impact', '{fact_id}', '{stale_code_units[], features[]}'],
  ['acquire.request', '{need, part?, peripheral?}', '{request_id, state}; ứng viên hiển thị trong hàng đợi, không tải'],
  ['review.patch', '{files[], cites[]}', '{verdict, violations[]} — chạy ConstantGuard + kiểm tĩnh nhanh'],
  ['build / size / static / test', '{project}', 'ToolReport'],
  ['flash', '{artifact, target}', '{status: "needs_permission", gate_id} hoặc ToolReport'],
  ['serial.expect', '{port, pattern, timeout_s}', '{matched, lines[]}'],
  ['probe.read_memory', '{addr, len}', '{hex}; write/erase → needs_permission'],
  ['feature.status', '{feature_id?}', '{features[]}'],
  ['export.report', '{type: docx|pdf|md, scope}', '{path}'],
  ['caps.list / caps.describe / caps.invoke (v1.1)', '{ns?, tier?} / {id} / {id, args}', 'Phơi toàn bộ registry qua ba tool chung để IDE ngoài gọi bất kỳ năng lực nào; caps.invoke đi qua Router (grounding, PolicyGate, ledger, undo)'],
  ['chat.command (v1.1)', '{text}', '{run_id, restated, question?, report?} — cho phép IDE ngoài gửi lệnh ngôn ngữ tự nhiên'],
  ['discover.scan / discover.link_speed (v1.1)', '{} / {target, kind}', '{ports[], probes[], chip_id} / {chosen, tried[]}'],
  ['diagram.generate / diagram.render (v1.1)', '{kind, source_ref, lang?} / {src, lang, fmt}', '{src, lint[]} / {path}'],
  ['doc.generate (v1.1)', '{type, scope}', '{path, style_issues[]}'],
  ['view.rag_ask (v1.1)', '{question, scope?}', '{answer, citations[], trace_id}'],
]));
c.push(SP());
c.push(P('Schema của mọi tool tuân theo mẫu số chung (object/string/number/integer/boolean/array/enum; sâu ≤ 3; không anyOf/$ref) để cùng một định nghĩa dùng được cho MCP và cho ba adapter LLM [19]. Tool nặng trả `{job_id}` và có `job.status`. Từ v1.1, tool MCP được sinh từ khai báo năng lực (input/output schema) — không viết tay; giới hạn ≤ 20 tool/phiên đạt bằng ba tool chung caps.* cộng các tool thường dùng.'));
c.push(H1('6. Tệp cấu hình'));
c.push(P('`models.yaml` cần **hai phần** mà bản v1.2 chưa nêu, và thiếu phần nào thì một cơ chế cụ thể ngừng hoạt động. `aliases` ánh xạ bí danh trong `roles` (`gemini-flash`, `claude-opus`) sang mã model thật của nhà cung cấp — không có nó, `candidates` là những cái tên không gọi được API nào. `pricing` cho giá theo triệu token — không có nó, `policy.daily_budget_usd` không cưỡng chế được và trường `cost_usd` của sự kiện `model.call` (API-15 §7) luôn bằng 0, tức mọi báo cáo chi phí đều bằng không. Xem DEVIATIONS DEV-015.'));
c.push(...CODE([
  '# .eide/models.yaml',
  'aliases:                       # bí danh → mã model THẬT của nhà cung cấp; không có bảng này',
  '  gemini-flash: gemini-3.8-flash          # thì "gemini-flash" không gọi được API nào',
  '  gemini-pro:   gemini-3.1-pro-preview',
  '  claude-haiku: claude-haiku-4-5-20251001',
  '  claude-sonnet: claude-sonnet-5',
  '  claude-opus:  claude-opus-5',
  'roles:',
  '  librarian: {candidates: [gemini-flash, local/qwen], temperature: 0}',
  '  cartographer: {candidates: [claude-sonnet, gemini-pro], inputs: [image]}',
  '  planner: {candidates: [claude-opus, gemini-pro], min_context: 200k}',
  '  coder: {candidates: [gemini-flash, claude-sonnet], max_output: 16k}',
  '  reviewer: {candidates: [claude-sonnet, gemini-pro], rule: different_vendor_from(coder)}',
  '  debugger: {candidates: [claude-sonnet, gemini-pro]}',
  '  intent: {candidates: [gemini-flash, claude-haiku], temperature: 0, output_schema: Intent}   # v1.1: mô hình hiểu lệnh rẻ',
  '  architect: {candidates: [claude-opus, gemini-pro]}                                          # v1.1: req/arch/adr',
  '  writer: {candidates: [claude-sonnet, gemini-pro]}                                           # v1.1: doc/diagram',
  'policy: {daily_budget_usd: 5, offline_mode: false, fallback_on: [rate_limit, timeout, refusal]}',
  'pricing:                       # USD / 1 triệu token; thiếu bảng này thì daily_budget_usd',
  '  gemini-3.8-flash: {in: 0.30, out: 2.50}      # không cưỡng chế được và model.call.cost_usd',
  '  claude-sonnet-5:  {in: 3.00, out: 15.00}     # luôn bằng 0',
  '',
  '# .eide/autonomy.yaml (v1.1, theo APD-08)',
  'autonomy: A3',
  'boards: {robot-ctrl: {autonomy: A2, reason: "có động cơ"}, nucleo-f411: {lab: true, autonomy: A4}}',
  'thresholds: {fact_silver_auto: 0.85, plan_max_steps: 12, merge_size_growth_pct: 5, flash_per_hour: 20, download_max_mb: 50}',
  'trusted_sources: [st.com, microchip.com, nordicsemi.com, espressif.com, bosch-sensortec.com, github.com/cmsis-svd]',
  'trusted_packages: [gcc-arm-none-eabi, avr-gcc, renode, probe-rs, openocd, esptool, simavr, mermaid-cli, plantuml, graphviz, d2, wavedrom-cli]',
  'undo_window: {facts: 72h, merge: 24h, flash: session}',
  'ask_timeout_s: 120',
  'defaults: {project_dir: ~/eide, model_profile: default, sim_first: true, diagram_lang: mermaid, doc_lang: vi}',
  'escalation: {channels: [queue, chat, notify], budget_warn_pct: 20, fail_retries: 2}',
  '',
  '# .eide/preferences.yaml (v1.1, D8 — ghi từ câu trả lời của người)',
  'create_when_exists: ask        # ask | reuse | new',
  'probe: stlink',
  'always_sim_before_flash: true',
  '',
  '# .hkw/roles.yaml (trích)',
  'coder: {skills_max: 3, tools: [repo.read, repo.write, passport.query, build, size, static, test], budget: {input: 8000, output: 16000}}',
  '',
  '# hkw-packs/isa/armv7e-m.yaml (trích)',
  'id: armv7e-m',
  'toolchain: {compiler: arm-none-eabi-gcc, min: "13.2", check: "arm-none-eabi-gcc --version", install: {macos: "brew install --cask gcc-arm-embedded", linux: "apt install gcc-arm-none-eabi"}}',
  'debug: {adapters: [probe-rs, openocd], probes: [stlink, jlink, cmsis-dap]}',
  'sim: {renode: true}',
  'skills: [skills/armv7e-m/interrupts.md, skills/armv7e-m/clock.md, skills/armv7e-m/i2c.md]',
]));
c.push(SP());
c.push(H1('7. CLI'));
c.push(T([2600, 6700], ['Lệnh', 'Chức năng'], [
  ['eide "<lệnh ngôn ngữ tự nhiên>"', 'Lệnh mặc định (v1.1): Orchestrator hiểu → đối chiếu → chuỗi năng lực → báo cáo; `--dry-run` chỉ in chuỗi; `--ask` bắt buộc hỏi'],
  ['eide caps list|describe|invoke <id> [--json args]', 'Gọi trực tiếp bất kỳ năng lực nào qua Router (v1.1)'],
  ['eide discover [--speed] / eide diagram <kind> / eide doc <type> / eide ask "<câu hỏi>" / eide map', 'Dò board; sinh lược đồ; sinh tài liệu; hỏi–đáp RAG; bản đồ tri thức (v1.1)'],
  ['eide stop / eide undo <ref> / eide autonomy A0..A4', 'Dừng khẩn; hoàn tác; đặt mức tự chủ (v1.1)'],
  ['eide init [--isa armv7e-m] [--board id]', 'Tạo `.eide/`, PROGRESS.md, FEATURES.json, autonomy.yaml, cấu hình mặc định'],
  ['hkw ingest <path|dir>', 'UC01: phân loại, mở nén, xếp hàng trích xuất'],
  ['hkw acquire "<need>" [--part]', 'UC02: tạo yêu cầu và tìm ứng viên'],
  ['hkw review [--group]', 'Duyệt nguồn/fact trong terminal (thay UI khi không có GEditor)'],
  ['hkw query <part> [periph] [reg]', 'UC03'],
  ['hkw board import <file.kicad_sch>', 'UC04'],
  ['hkw verify-passport <id> --target <port|probe>', 'UC05'],
  ['hkw plan / gen <feature> / gate <G> approve|reject', 'UC06'],
  ['hkw flash / serial / probe …', 'UC07, UC08 (mở G-OPS khi cần)'],
  ['hkw bench [--isa] [--model]', 'UC12'],
  ['hkw doctor [--install] [--lock]', 'UC13'],
  ['hkw publish <passport_id> / pull <id@ver> / search', 'UC10, UC11'],
  ['hkw rollback / resume / export', 'GOV-02, GOV-03, GOV-06'],
]));
c.push(SP());
c.push(H1('8. Giao diện GEditor plugin ↔ daemon (JSON-RPC 2.0)'));
c.push(T([3000, 6300], ['Phương thức', 'Mô tả'], [
  ['plane.hello {plugin_version}', 'Handshake; trả api_version, project'],
  ['gate.list / gate.decide {id, decision, note}', 'Hàng đợi xác nhận hợp nhất; sự kiện `gate.changed` push'],
  ['passport.query / passport.browse {id, group}', 'Trình duyệt hộ chiếu'],
  ['log.register {path} / log.stats {path, range}', 'GEditor tính thống kê (native) và đăng ký với daemon để Debugger dùng'],
  ['debug.ask {path, range, question}', 'Kịch bản C; trả `answer` neo range và `session_id`'],
  ['serial.open/close/write; sự kiện serial.line', 'Console'],
  ['hex.resolve {address}', 'Giải nghĩa địa chỉ theo hộ chiếu'],
  ['chat.send {text} / sự kiện chat.restated, chat.question, chat.report, run.progress (v1.1)', 'Cửa sổ trò chuyện mặc định; câu hỏi gộp hiển thị dạng thẻ có phương án và đếm ngược timeout'],
  ['caps.invoke {id, args} (v1.1)', 'Mọi nút bấm trên plugin gọi năng lực qua Router; trả pending{gate_id} khi ASK'],
  ['queue.list {kind: ask|done} / undo.apply {ref} / autonomy.set {level} / stop (v1.1)', 'Hàng đợi tách "chờ tôi" và "đã làm — hoàn tác được"; thanh trạng thái tự chủ; dừng khẩn'],
  ['view.kg_map / view.focus / view.provenance / view.rag_ask / view.trace (v1.1)', 'Panel bản đồ tri thức và hỏi–đáp có trích dẫn nhấp mở nguồn'],
  ['diagram.open {src, lang} / diagram.changed (v1.1)', 'GEditor render Mermaid/PlantUML/DOT/D2/WaveDrom/SVG; sửa mã lược đồ → daemon lint + sync'],
  ['discover.status / sự kiện discover.changed (v1.1)', 'Cắm/rút board → cập nhật thanh trạng thái target'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-SDD-04_Thiet_ke_chi_tiet.docx');
