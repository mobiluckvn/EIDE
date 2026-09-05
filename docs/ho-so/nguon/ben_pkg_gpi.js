const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');

// ================= BEN-21 =================
{
const m = metaNew('EIDE-BEN-21', 'Bộ benchmark và kiểm định', 'BỘ BENCHMARK VÀ FIRMWARE KIỂM ĐỊNH HỘ CHIẾU (BEN)',
  'Định nghĩa 20 tác vụ CF/BF/BC cho armv7e-m và avr8 với kỳ vọng máy quan sát được, giao thức chạy và chấm, firmware kiểm định hộ chiếu (ID/GPIO/UART/echo/scan), định dạng kết quả và huy hiệu, quy trình chạy lại',
  [['Tài liệu trước', 'EIDE-STP-05 §4, IoT-SkillsBench [17], EIDE-CDS-12 tập 4 (bench.*), EIDE-TGT-19'], ['Dùng khi', 'Hiện thực bench.run, passport.verify_on_board; đánh giá đổi mô hình/skill/prompt; Chương thực nghiệm đề án']],
  'Phát hành lần đầu — bổ sung lĩnh vực L24');
const c = [];
c.push(H1('1. Giao thức'));
c.push(P('Theo IoT-SkillsBench [17]: mỗi tác vụ có mô tả bằng ngôn ngữ tự nhiên (như kỹ sư ra lệnh), board, kỳ vọng quan sát được bằng máy và ba mức chấm: **CF** (compile-free: biên dịch không lỗi), **BF** (build-and-flash: nạp và chạy không treo trong 10 s), **BC** (behavior-correct: mọi expect đạt). Mỗi lần chạy = một chuỗi EIDE tiêu chuẩn (plan.create → code.generate_module → 4 cổng → code.review → sim.run → target.flash → target.observe) ở mức A3 trên board lab, với mô hình theo vai trò cố định trong hồ sơ benchmark; ghi: mô hình, skill, prompt_hash, token vào/ra, vòng tự sửa, thời gian, kết cục, chi phí. Mỗi tác vụ chạy 3 lần (temperature mặc định) và lấy tỷ lệ BC. Ngưỡng nghiệm thu: BC ≥ 90% mức 1–2, ≥ 60% mức 3 (SRS §6).'));
c.push(H1('2. Firmware kiểm định hộ chiếu (passport.verify_on_board)'));
c.push(P('Một firmware sinh từ mẫu theo ISA, nhận lệnh qua UART (115200 mặc định, auto-baud) và trả JSON dòng: `ID` → đọc IDCODE/signature/chip_id và các thanh ghi nhận dạng theo hộ chiếu; `GPIO <pin> <0|1|in>` → đặt/đọc chân (so với fact pin_function, kiểm chân reserved bị từ chối); `UART` → echo 1.000 khung (dò baud); `I2CSCAN`/`SPIID <cs>` → quét bus (discover.bus_scan); `CLK` → toggle GPIO theo timer để đo tần số (discover.clock_measure); `MEM <addr> <len>` → đọc thanh ghi (so reset_value của hộ chiếu khi vừa reset). Kết quả so với fact → badge `verified_on_board{board, date, by, log_sha256, checks{}}`; lệch → conflict và leo thang.'));
c.push(H1('3. Hai mươi tác vụ khởi đầu'));
const TASKS = [
 ['B-M1', 'armv7e-m', '1', 'Nhấp nháy LED PC13 chu kỳ 500 ms', 'gpio PC13 toggles 8–12 trong 5 s'],
 ['B-M2', 'armv7e-m', '1', 'UART2 115200 in "hello <n>" mỗi 1 s', 'uart pattern "hello \\d+" ≥ 4 trong 5 s'],
 ['B-M3', 'armv7e-m', '1', 'Đọc nút PA0 (EXTI) đảo LED', 'probe write GPIOA.IDR giả lập / sim inject → LED đổi trong 50 ms'],
 ['B-M4', 'armv7e-m', '2', 'I2C1 đọc ID BME280 và in nhiệt độ 1 Hz', 'uart "T=2\\d\\.\\d" ≥ 3; logic decoder I2C thấy 0x76 R'],
 ['B-M5', 'armv7e-m', '2', 'SPI1 đọc JEDEC ID flash W25Q', 'uart "JEDEC EF 40 16"'],
 ['B-M6', 'armv7e-m', '2', 'TIM3 PWM 1 kHz duty 25% trên PA6', 'logic: tần số 1 kHz ±2%, duty 25 ±2'],
 ['B-M7', 'armv7e-m', '2', 'USART DMA nhận 64 byte rồi echo', 'uart echo khớp 100%'],
 ['B-M8', 'armv7e-m', '3', 'FreeRTOS 2 task: cảm biến 100 Hz + telemetry 10 Hz, queue', 'uart 10 Hz ±1; không stall 30 s'],
 ['B-M9', 'armv7e-m', '3', 'Watchdog IWDG 1 s + tự phục hồi sau treo cố ý', 'uart "reset by IWDG" sau lệnh HANG'],
 ['B-M10', 'armv7e-m', '3', 'Low-power STOP + wake bằng RTC 2 s', 'measure current: < 1 mA trong stop; wake mỗi 2 s ±10%'],
 ['B-A1', 'avr8', '1', 'Blink PB5 500 ms', 'gpio toggles'],
 ['B-A2', 'avr8', '1', 'UART0 9600 in hello', 'uart pattern'],
 ['B-A3', 'avr8', '1', 'ADC0 đọc và in mV', 'uart "\\d+ mV"; giá trị ±5% nguồn chuẩn'],
 ['B-A4', 'avr8', '2', 'TWI đọc BME280', 'uart T='],
 ['B-A5', 'avr8', '2', 'SPI đọc ID', 'uart JEDEC'],
 ['B-A6', 'avr8', '2', 'Timer1 PWM 490 Hz', 'logic tần số'],
 ['B-A7', 'avr8', '2', 'INT0 đếm xung in mỗi 1 s', 'logic inject 100 Hz → uart "100"'],
 ['B-A8', 'avr8', '3', 'Bộ lập lịch hợp tác 3 tác vụ', 'uart chu kỳ đúng'],
 ['B-A9', 'avr8', '3', 'Watchdog + EEPROM ghi/đọc bộ đếm reset', 'uart "resets=2" sau 2 lần'],
 ['B-A10', 'avr8', '3', 'Sleep mode + wake WDT', 'current < 5 mA'],
];
c.push(T([800, 1000, 500, 4000, 3000], ['Mã', 'ISA', 'Mức', 'Tác vụ (lệnh)', 'Kỳ vọng máy quan sát'], TASKS, { size: 19 }));
c.push(SP());
c.push(H1('4. Định dạng và huy hiệu'));
c.push(...CODE([
  '# bench/armv7e-m/tasks.yaml',
  '- id: B-M4', '  level: 2', '  board: nucleo-f411 (+BME280 trên I2C1)', '  command: "Đọc ID BME280 qua I2C1 và in nhiệt độ mỗi giây ra UART2"',
  '  expect: [{kind: uart, pattern: "T=2\\\\d\\\\.\\\\d", min_count: 3, within_s: 5}, {kind: logic, decoder: i2c, expect_addr: 0x76}]',
  '  timeout_s: 600', '  max_cost_usd: 0.5',
  '# kết quả bench/results/<date>-<model>.json',
  '{"task": "B-M4", "model": {"planner": "claude-opus", "coder": "gemini-flash", "reviewer": "claude-sonnet"}, "skills": ["armv7e-m/i2c@1.2"], "prompt_hash": "…",',
  ' "runs": [{"cf": true, "bf": true, "bc": true, "rounds": 1, "tokens_in": 21300, "tokens_out": 4100, "cost_usd": 0.11, "seconds": 190, "log_sha256": "…"}], "bc_rate": 1.0}',
  '# huy hiệu gắn gói/skill: {"bench": {"suite": "armv7e-m@1.0", "model": "…", "cf": 1.0, "bf": 1.0, "bc": 0.93, "date": "…", "results_sha256": "…"}}',
]));
c.push(SP());
c.push(H1('5. Chạy lại và báo cáo'));
c.push(P('bench.run chạy lại tự động (nightly, runner có board) khi: đổi mô hình mặc định, đổi skill/prompt (PRS-16 §8), phát hành pack; kết quả xuất doc.test_report và gắn bench.badge; hồi quy (BC giảm > 5 điểm) → mở mục ASK cho Pack owner. Ablation ngữ cảnh (CXD-10 §9) dùng cùng bộ này.'));
c.push(...refParas(H1));
build(m, c, 'EIDE-BEN-21_Bo_benchmark.docx');
}

// ================= PKG-22 =================
{
const m = metaNew('EIDE-PKG-22', 'Đặc tả gói và registry', 'ĐẶC TẢ GÓI .HKP, REGISTRY VÀ MẪU DỰ ÁN THAM CHIẾU (PKG)',
  'Cấu trúc gói .hkp, schema manifest/badges, ký và kiểm chữ ký, index registry, quy trình publish/pull qua Git, gói mẫu dự án tham chiếu (K5′) và gói công cụ (tool.promote), kiểm license',
  [['Tài liệu trước', 'EIDE-SRS-02 FR-REG, EIDE-KAD-07 K5′, EIDE-SEC-25 §4, EIDE-CDS-12 tập 5 (registry.*)'], ['Dùng khi', 'Hiện thực eide.registry; vận hành registry lớp/tổ chức (M4)']],
  'Phát hành lần đầu — bổ sung lĩnh vực L25');
const c = [];
c.push(H1('1. Cấu trúc gói'));
c.push(...CODE([
  '<id>-<version>.hkp  (zip)',
  '├── manifest.json            # bắt buộc (schema §2)',
  '├── passport.yaml            # fact + con trỏ nguồn (uri, sha256, locator) — KHÔNG chứa PDF/tài liệu hãng (CR-03)',
  '├── sources.json             # danh sách Source {id, uri, sha256, kind, tier, license}',
  '├── skills/*.md              # K5 (≤ 600 token/skill, front-matter applies_to)',
  '├── bench/                   # tasks.yaml + results/*.json',
  '├── badges.json              # verified_on_board[], bench[]',
  '├── template/                # chỉ kind=template: bom.csv, board.yaml, sim/{platform.repl, plant.yaml, scenarios/}, firmware/ (mã mẫu có eide:fact), README.md',
  '├── tools/                   # chỉ kind=tool: tool.py, spec.json, test_tool.py (tool.promote)',
  '└── SIGNATURE                # minisign/sigstore trên sha256 của mọi tệp (manifest.files[])',
]));
c.push(SP());
c.push(H1('2. Schema manifest.json'));
c.push(...CODE([
  '{ "type": "object", "required": ["id", "version", "kind", "license", "files", "created_at", "author"], "additionalProperties": false, "properties": {',
  '  "id": {"type": "string", "pattern": "^[a-z0-9_.-]+$"},  "version": {"type": "string", "pattern": "^\\\\d+\\\\.\\\\d+\\\\.\\\\d+$"},',
  '  "kind": {"type": "string", "enum": ["passport-chip", "passport-board", "isa", "skill", "template", "tool", "bundle"]},',
  '  "title": {"type": "string"}, "description": {"type": "string"}, "license": {"type": "string"}, "author": {"type": "string"}, "org": {"type": "string"},',
  '  "created_at": {"type": "string", "format": "date-time"}, "eide_min_version": {"type": "string"},',
  '  "depends": {"type": "array", "items": {"type": "string", "pattern": "^[a-z0-9_.-]+@[~^]?\\\\d+\\\\.\\\\d+(\\\\.\\\\d+)?$"}},',
  '  "parts": {"type": "array", "items": {"type": "string"}}, "isa": {"type": "array", "items": {"type": "string"}},',
  '  "files": {"type": "array", "items": {"type": "object", "required": ["path", "sha256", "bytes"], "properties": {"path": {"type": "string"}, "sha256": {"type": "string"}, "bytes": {"type": "integer"}}}},',
  '  "facts": {"type": "object", "properties": {"count": {"type": "integer"}, "gold": {"type": "integer"}, "silver": {"type": "integer"}}},',
  '  "contains_project_knowledge": {"type": "boolean", "const": false},',
  '  "signature": {"type": "object", "properties": {"scheme": {"type": "string", "enum": ["minisign", "sigstore"]}, "key_id": {"type": "string"}}} } }',
]));
c.push(SP());
c.push(H1('3. Ký, kiểm, license'));
c.push(P('registry.pack tính sha256 mọi tệp → manifest.files; registry.publish ký `sha256(manifest.json)` bằng minisign (khóa Pack owner) hoặc sigstore keyless [21]; registry.pull kiểm chữ ký với khóa công khai trong `registry/keys/` (trust-on-first-use cho registry lớp; danh sách khóa ký bởi quản trị), so sha256 từng tệp, từ chối gói có license không thuộc allowed_licenses hoặc `contains_project_knowledge=true`, quét passport.yaml không chứa nội dung tài liệu (heuristic: không có đoạn > 200 ký tự từ nguồn PDF). Fact nạp vào L-A (gói chính hãng/ký bởi quản trị) hoặc L-B (cộng đồng), tier kế thừa gói, status reviewed/verified theo badge.'));
c.push(H1('4. Registry và quy trình'));
c.push(...CODE([
  'registry/ (kho Git nội bộ, HTTPS hoặc SSH)',
  '├── index.json                 # {packages[]: {id, versions[]: {version, kind, sha256, badges, published_at, author}}} — sinh bởi CI',
  '├── packages/<id>/<id>-<ver>.hkp',
  '├── keys/*.pub',
  '└── README.md',
  'publish (nội bộ): registry.pack → policy G5 → ký → git push nhánh pub/<id>-<ver> → CI kiểm chữ ký/license/schema → merge → index.json cập nhật → ghi tác giả',
  'publish (công khai): như trên nhưng G5 luôn ASK + rà pháp lý license tài liệu hãng',
  'pull: GET index.json (cache 1 h) → chọn phiên bản theo pin (^1.2) → tải .hkp → kiểm → nạp → ghi constraints.yaml pins',
  'seed: registry.seed → gói kind passport-chip, badge unverified, author "seed:cmsis-svd" — 640 chip M0',
]));
c.push(SP());
c.push(H1('5. Gói mẫu dự án tham chiếu (K5′) và gói công cụ'));
c.push(P('Template (`kind=template`, ví dụ `eide.ref.balancing-robot@1.2.0`): depends tới hộ chiếu chip/part; `template/bom.csv` (ref, MPN, value, qty); `board.yaml` (net, pin, bus, địa chỉ — dạng BoardPassport); `sim/` (platform, plant.yaml với tham số có nguồn và cờ provisional, kịch bản); `firmware/` mã mẫu đã chạy (mọi hằng số có eide:fact trỏ fact của gói); `README.md` mục tiêu và Feature gợi ý; badges verified_on_board bắt buộc để hiện ở Z-03. Gói công cụ (`kind=tool`, từ tool.promote): tool.py + spec.json (effects) + test; khi pull, đăng ký như năng lực chính thức trong namespace ghi ở spec sau khi Pack owner duyệt.'));
c.push(H1('6. Kiểm thử'));
c.push(T([1000, 3400, 3700, 1200], ['TC', 'Mục tiêu', 'Kỳ vọng', 'Mức'], [
  ['TC-PK-01', 'Manifest và chữ ký', 'Gói hợp lệ pull được; sửa 1 byte → verify thất bại; thiếu license → từ chối (TC-41)', 'L1'],
  ['TC-PK-02', 'Không chứa tài liệu hãng', 'passport.yaml chứa đoạn văn 300 ký tự từ PDF → registry.pack từ chối', 'L1'],
  ['TC-PK-03', 'Template', 'Pull eide.ref.balancing-robot → project.create từ mẫu → sim chạy', 'L2'],
  ['TC-PK-04', 'Gói công cụ', 'tool.promote → gói kind=tool → pull ở dự án khác → năng lực gọi được', 'L2'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-PKG-22_Dac_ta_goi_registry.docx');
}

// ================= GPI-23 =================
{
const m = metaNew('EIDE-GPI-23', 'Giao diện plugin GEditor', 'GIAO DIỆN PLUGIN GEDITOR (GPI)',
  'Cách EIDE nhúng vào GEditor: yêu cầu đối với khung plugin GEditor, vòng đời plugin, panel và bố cục, render lược đồ, thống kê log native, sự kiện và luồng dữ liệu, ràng buộc hiệu năng, đóng gói và ký; các điểm cần đối chiếu với tài liệu GEditor v2.2',
  [['Tài liệu trước', 'EIDE-SAD-03 §3, EIDE-API-15 §2, EIDE-UXD-13; GEditor v2.2 (154 FR — tài liệu riêng của sản phẩm)'], ['Dùng khi', 'Hiện thực eide-geditor (Swift); mở rộng khung plugin GEditor nếu thiếu API']],
  'Phát hành lần đầu — bổ sung lĩnh vực L27; các mục đánh dấu [GE?] cần xác nhận với tài liệu GEditor');
const c = [];
c.push(H1('1. Vị trí và nguyên tắc'));
c.push(P('GEditor là bề mặt quan sát (PDA P7): plugin EIDE là **client thuần** của daemon `eided` (SAD A1) — không giữ tri thức, không gọi LLM, không chạy công cụ; mọi thứ qua JSON-RPC (API-15 §2). GEditor cung cấp ba thứ EIDE không tự làm: (1) engine tệp lớn (log/hex gigabyte, thống kê native), (2) khung cửa sổ/panel/tab và trình soạn thảo, (3) bộ render lược đồ văn bản (Mermaid, PlantUML, DOT, D2, WaveDrom, SVG) mà GEditor đã hỗ trợ. Tài liệu này liệt kê **yêu cầu của EIDE đối với khung plugin GEditor**; mục có nhãn [GE?] cần đối chiếu với FR của GEditor v2.2 và có thể trở thành yêu cầu bổ sung cho GEditor.'));
c.push(H1('2. Yêu cầu đối với khung plugin GEditor'));
c.push(T([800, 3400, 3000, 2100], ['#', 'Yêu cầu', 'Dùng cho', 'Trạng thái'], [
  ['GP-01', 'Nạp bundle plugin ký Developer ID; vòng đời load/activate/deactivate/unload; khai báo quyền (socket cục bộ, đọc tệp dự án)', 'DEP-26', '[GE?]'],
  ['GP-02', 'API đăng ký mục sidebar (icon, nhãn, đếm) và panel chính; panel trượt (sheet) bên phải; popover từ thanh trạng thái', 'UXD 23 màn hình, ProvenancePanel', '[GE?]'],
  ['GP-03', 'API thanh trạng thái tùy biến (đoạn văn bản + nút) và nút toàn cục ở sidebar', 'AutonomyBar, StopButton', '[GE?]'],
  ['GP-04', 'Render lược đồ từ chuỗi nguồn theo ngôn ngữ; sự kiện khi người sửa nguồn; xuất SVG/PNG', 'DiagramFrame', 'GEditor v2.2 hỗ trợ [xác nhận danh sách ngôn ngữ]'],
  ['GP-05', 'API tệp lớn: mở theo range, thống kê mẫu regex toàn tệp (đếm, khoảng thời gian), đăng ký "neo" chú thích vào dòng/range', 'LogAssist, debug.log_stats, answer neo dòng', 'GEditor engine (FR log) [xác nhận API]'],
  ['GP-06', 'Trình soạn thảo: hover provider (hằng số → fact), diagnostic provider (constant-guard), lệnh ngữ cảnh', 'Code', '[GE?]'],
  ['GP-07', 'Mở PDF/ảnh tới trang và vùng (bbox) với bôi sáng', 'Provenance, doc_side_by_side', '[GE?] — nếu thiếu, dùng viewer riêng trong panel'],
  ['GP-08', 'Serial console tích hợp (hoặc panel văn bản stream) với ghi JSONL', 'target.serial', '[GE?]'],
  ['GP-09', 'Kênh IPC Unix socket từ plugin (sandbox macOS: entitlement)', 'Toàn bộ', 'Cần entitlement app'],
  ['GP-10', 'Thông báo hệ điều hành và toast trong cửa sổ', 'Leo thang', '[GE?]'],
  ['GP-11', 'Kéo thả tệp vào panel (đường dẫn)', 'Ingest, ô lệnh', 'Chuẩn AppKit'],
  ['GP-12', 'Lưu trạng thái panel theo dự án (bố cục, bộ lọc)', 'Tiện nghi', '[GE?]'],
]));
c.push(SP());
c.push(H1('3. Kiến trúc plugin (Swift)'));
c.push(...CODE([
  'eide-geditor/Sources/',
  '  EideCore/        RpcClient (Unix socket, Content-Length framing, Codable models sinh từ openrpc.json), EventBus (event.* → Combine publishers), Caps (invoke/list/describe), Session (hello, project)',
  '  EideUI/          ChatPanel, QueuePanel, PassportPanel, BoardPanel, KnowledgeMapPanel (Canvas), RagAskPanel, ReqArchPanel, DiagramPanel, DocPanel, PlanDiffPanel, SimPanel, DiscoveryPanel, LogAssistPanel, DebugPanel, ToolForgePanel, BenchPanel, RegistryPanel, ModelsEnvPanel, AutonomyBar, StopButton, ProvenanceSheet, QuestionCard, ReportCard, RunProgress',
  '  EideGEditor/     GEPluginEntry (vòng đời), SidebarRegistrar, StatusBarRegistrar, DiagramRendererBridge (gọi bộ render GEditor), LargeFileBridge (log.stats), EditorProviders (hover/diagnostic), PdfBridge',
  'Luồng: GEditor mở dự án → GEPluginEntry.activate → RpcClient.connect → plane.hello → project.open → EventBus phát → panel cập nhật; người bấm → Caps.invoke → kết quả/pending → QueuePanel',
  'Trạng thái: mọi ViewModel chỉ là cache của daemon (không nguồn sự thật); mất kết nối → banner "mất kết nối daemon" + thử lại; api_version lệch → yêu cầu nâng cấp (DEP-26)',
]));
c.push(SP());
c.push(H1('4. Ràng buộc hiệu năng'));
c.push(T([3000, 6300], ['Thao tác', 'Ngưỡng'], [
  ['Handshake + mở dự án', '≤ 1 s (summary từ daemon)'], ['Thẻ ý hiểu sau Enter', '≤ 1,5 s (intent model)'], ['Bản đồ tri thức 50.000 nút', 'Hiển thị ≤ 3 s; tương tác 60 fps ở ≤ 5.000 nút, gom cụm trên đó'],
  ['Lint lược đồ / render', '≤ 300 ms / ≤ 1 s (GEditor render)'], ['log.stats 3 GB', '≤ 5 s (engine GEditor)'], ['Sự kiện run.progress', 'Cập nhật UI ≤ 100 ms; gộp sự kiện khi > 20/s'],
]));
c.push(SP());
c.push(H1('5. Đóng gói và kiểm thử'));
c.push(P('Bundle `.geplugin` ký Developer ID, notarized; phân phối qua GEditor Plugin Manager và tệp tải về; phiên bản plugin ↔ daemon theo semver major (DEP-26). Kiểm thử: XCTest cho RpcClient (framing, lỗi, reconnect), EventBus, ViewModel; UI test cho TC-UX-01…08; test hợp đồng: mã Swift sinh từ openrpc.json phải biên dịch và khớp fixture tests/contract/rpc.'));
c.push(H1('6. Việc cần chốt với GEditor'));
c.push(P('Trước M3: (1) xác nhận danh sách ngôn ngữ lược đồ GEditor render và API gọi từ plugin; (2) API thống kê tệp lớn và neo chú thích; (3) khung sidebar/panel/status bar cho plugin; (4) hover/diagnostic provider trong trình soạn thảo; (5) mở PDF tới bbox; (6) entitlement socket. Mục thiếu sẽ được ghi thành FR bổ sung của GEditor v2.3 hoặc thay bằng thành phần riêng trong plugin (chấp nhận trùng lặp tạm).'));
c.push(...refParas(H1));
build(m, c, 'EIDE-GPI-23_Giao_dien_plugin_GEditor.docx');
}
