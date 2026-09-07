const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas, CAPS, byNs, count } = require('./eide_common');
const D = require('./dialog.json');
const m = meta('EIDE-DPS-09', 'Chính sách hội thoại', 'CHÍNH SÁCH HỘI THOẠI VÀ SUY LUẬN Ý ĐỊNH (DPS)',
  'Tầng hiểu lệnh của tác tử EIDE: bốn trách nhiệm, tám quy tắc D1–D8, schema ý định, đối chiếu trạng thái, mặc định và câu hỏi gộp, lập chuỗi năng lực, kịch bản đầu vào trống Z-01…Z-10, đo lường và kiểm thử',
  [['Tài liệu trước', 'EIDE-APD-08 (chính sách tự chủ), Danh mục năng lực v1.1, Use case chi tiết (sheet 9 kịch bản hội thoại)'], ['Dùng khi', 'Hiện thực eide.orchestrator; viết prompt vai trò intent; thiết kế ChatPanel; viết TC-59…TC-64; viết Chương lý thuyết về tương tác người–tác tử']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu, tách từ phân tích "đầu vào chưa có gì" (sheet 9 Use case) và bốn trách nhiệm của tác tử khi làm việc với kỹ sư']],
  'Phát hành cùng bộ v1.1');
// DPS-09 ra đời cùng bộ v1.1 nên phát hành ở 1.0, không mang ba hàng lịch sử mặc định của
// `meta()`; hai dòng dưới cắt chúng đi. Hàng 1.1 thêm ở đây khi đồng bộ tài liệu.
const LICH_SU = [['1.1', '07/09/2026', 'Vũ Trí Công',
  '§4.1: thêm ý định `project.delete` — POL-17 GEN-03 chặn `action.is_delete_project` như hành '
  + 'động R4, nhưng không có ý định ấy thì "xóa dự án test-1" buộc rơi vào `project.create`, tức '
  + 'tầng hiểu lệnh đọc "xóa" thành "tạo" và cổng không bao giờ được hỏi tới (DEV-021). Mô tả lớp '
  + 'C0 của vai trò `intent` kèm số đo: thiếu C0 thì độ đúng ý định 76%, có C0 đầy đủ 100%, bản '
  + 'thiếu bảng phân biệt 82%. Nói rõ `big_command` KHÔNG kéo theo `is_big=true` vì nhãn ấy còn '
  + 'gánh vai sọt chứa cho 14/27 nhóm chưa có ý định riêng (DEV-035), và ghi phép thử suy `is_big`: '
  + 'toàn bộ một chuỗi mẫu §4.4 → true, một nút của chuỗi → false (DEV-022).']];
m.history = [m.history[0], ...LICH_SU];
m.version = LICH_SU[LICH_SU.length - 1][0];
m.attrs[1] = ['Phiên bản', `${m.version} — ${LICH_SU[LICH_SU.length - 1][3].slice(0, 90)}…`];
const c = [];
c.push(H1('1. Vấn đề và phạm vi'));
c.push(P('Từ v1.1, kỹ sư làm việc với EIDE chủ yếu bằng lệnh ngôn ngữ tự nhiên: "tạo dự án robot hai bánh tự cân bằng", "làm hết đi" (sau khi thả một tệp zip), "nạp lên board", "vẽ sơ đồ kiến trúc rồi viết SRS". Các chức năng phần mềm được khai báo thành năng lực có hợp đồng [25]; câu hỏi còn lại là **tác tử hiểu lệnh, quyết định gọi năng lực nào, với tham số gì, và hỏi người khi nào**. Tài liệu này đặc tả tầng đó — gọi là *tầng hiểu lệnh* (Orchestrator) — tách biệt với phần *sinh* (kế hoạch, mã, chẩn đoán, tài liệu) do các vai trò LLM đảm nhiệm, và tách biệt với *chính sách tự chủ* (APD-08 [26]) quyết định ai duyệt ở mỗi cổng rủi ro. Ba tầng phối hợp: DPS quyết định *hỏi vì thiếu thông tin*, APD quyết định *hỏi vì rủi ro*, vai trò sinh tạo ra nội dung.'));
c.push(P('Câu trả lời cho câu hỏi "những thứ như thế này mô tả ở đâu?" được chốt như sau:'));
c.push(T([2600, 4300, 2400], ['Nội dung', 'Nơi mô tả', 'Lý do'], D.WHERE.map(r => [r[0], r[1], r[2]])));
c.push(SP());
c.push(H1('2. Bốn trách nhiệm của tác tử khi làm việc với kỹ sư'));
c.push(...IMG('hinh/eide_nl_loop.png', 600, 328, 'Hình 1. Tám bước của Orchestrator cho một lệnh; hai chế độ gọi năng lực dùng chung hợp đồng'));
c.push(T([600, 2400, 3700, 2600], ['#', 'Trách nhiệm', 'Nội dung', 'Năng lực / cơ chế'], [
  ['①', 'Hiểu và đối chiếu (grounding)', 'Chuyển lệnh thành ý định có cấu trúc; tra trạng thái thật (dự án, hộ chiếu, board, feature, mẫu tham chiếu, registry) để biết điều người nói đã tồn tại chưa; không bao giờ hành động trên giả định về trạng thái', 'chat.parse_intent, chat.ground; tra store trực tiếp (deterministic), không nhờ mô hình nhớ'],
  ['②', 'Lập chuỗi năng lực', 'Với lệnh lớn, dựng đồ thị các lời gọi năng lực có nhánh và điều kiện; xếp thứ tự theo phụ thuộc dữ liệu; nhận diện nút có thể chạy ngay (T1, không phụ thuộc)', 'chat.orchestrate; plan.*; registry.describe_for_llm cung cấp danh mục cho mô hình'],
  ['③', 'Đảm bảo đủ thông tin: mặc định trước, hỏi sau', 'Điền ô trống bằng mặc định có căn cứ; chỉ hỏi khi không có mặc định hợp lý hoặc lựa chọn không hoàn tác; gộp mọi điểm mơ hồ thành một câu', 'chat.fill_defaults, chat.clarify; autonomy.yaml.defaults; preferences.yaml'],
  ['④', 'Áp chính sách và báo cáo', 'Mỗi lời gọi đi qua PolicyGate (APPROVE/ASK/REJECT); làm rồi báo cáo; tóm tắt đã làm/chờ/hoàn tác/chi phí; ghi nhớ lựa chọn', 'policy.decide, chat.report_back, memory.*; UndoService'],
]));
c.push(SP());
c.push(P('Ngoài bốn trách nhiệm điều phối, tác tử còn **sinh** nội dung (kế hoạch, mã, chẩn đoán, yêu cầu, kiến trúc, lược đồ, tài liệu) — nhưng luôn thông qua một năng lực có hợp đồng và luôn trên tri thức có nguồn (KAD-07). Tách bạch này cho phép kiểm thử tầng hiểu lệnh bằng kịch bản xác định (Z-01…Z-10) độc lập với chất lượng sinh.'));
c.push(H1('3. Tám quy tắc hội thoại D1–D8'));
c.push(P('Các quy tắc áp dụng cho mọi use case, mọi kênh (ChatPanel trong GEditor, CLI `eide "<lệnh>"`, tool MCP chat.command) và mọi mô hình hiểu lệnh. Chúng được hiện thực ở Orchestrator (mã), không phải chỉ ở prompt, để có thể kiểm thử.'));
c.push(T([600, 2300, 4300, 2100], ['Mã', 'Quy tắc', 'Nội dung', 'Vì sao'], D.RULES.map(r => [r[0], r[1], r[2], r[3]])));
c.push(SP());
c.push(H1('4. Đặc tả kỹ thuật'));
c.push(H2('4.1. Schema ý định (mẫu số chung, dùng cho ba adapter LLM)'));
// Schema Intent là NGUỒN DUY NHẤT cho ba chỗ dùng nó: prompt vai trò `intent` (PRS-16 §2),
// Gateway (ép đầu ra có cấu trúc) và test TC-59. Trước đây nó chỉ nằm trong văn xuôi docx,
// nên ba chỗ ấy đều phải chép tay và không có gì giữ chúng khỏi trôi khỏi nhau — đúng bài
// học DEV-018. Nay sinh ra `dialog/intent.schema.json`. Xem DEVIATIONS DEV-019.
const INTENT_SCHEMA = {
  type: 'object',
  required: ['intent', 'slots', 'is_big', 'confidence'],
  properties: {
    intent: { type: 'string', enum: ['project.create', 'project.open', 'knowledge.build', 'env.setup',
      'sim.run', 'code.feature', 'target.flash', 'debug.ask', 'req.analyze', 'arch.design',
      'diagram.draw', 'doc.write', 'view.ask', 'discover.scan', 'policy.stop', 'policy.set',
      'big_command', 'unknown',
      // DEV-021: POL-17 GEN-03 có quy tắc chặn `action.is_delete_project`, nhưng enum không
      // có cách nào NÓI điều đó — nên bộ 50 câu phải gán "Xóa dự án test-1" thành
      // `project.create`, tức dạy tầng hiểu lệnh đọc "xóa" thành "tạo". Thêm ý định thật.
      'project.delete'] },
    slots: { type: 'object', properties: {
      project_name: { type: 'string' }, idea: { type: 'string' }, chip: { type: 'string' },
      board: { type: 'string' }, path: { type: 'string' }, feature: { type: 'string' },
      doc_type: { type: 'string' }, diagram_kind: { type: 'string' },
      question: { type: 'string' }, level: { type: 'string' } } },
    is_big: { type: 'boolean' },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    lang: { type: 'string', enum: ['vi', 'en'] },
    mentions: { type: 'array', items: { type: 'string' } },
  },
};
if (!fs.existsSync('dialog')) fs.mkdirSync('dialog');
// C0 (CXD-10) cho vai trò `intent`: danh sách ý định kèm mô tả một dòng. Prompt intent.md đã
// nói "chọn năng lực không có trong danh sách C0" — tức là nó GIẢ ĐỊNH danh sách này được cấp.
// Trước đây không ai cấp, và đo được TC-59 chỉ 76%: mô hình phải tự đoán `view.ask` khác
// `debug.ask` chỗ nào. Giữ cạnh enum để hai bên không trôi khỏi nhau. Xem DEVIATIONS DEV-021.
const INTENT_MO_TA = [
  ['project.create',  'tạo dự án MỚI từ ý tưởng, tài liệu hoặc mã có sẵn'],
  ['project.open',    'mở hoặc TIẾP TỤC một dự án đã có ("tiếp tục việc hôm qua")'],
  ['project.delete',  'xóa hoặc ghi đè một dự án đã có'],
  ['knowledge.build', 'TÌM/TẢI hoặc nạp tài liệu, datasheet, zip, ảnh vào kho tri thức'],
  ['env.setup',       'cài, kiểm hoặc khóa toolchain và môi trường build'],
  ['sim.run',         'chạy firmware trên mô phỏng'],
  ['code.feature',    'viết hoặc sửa MÃ cho một tính năng, cấu hình ngoại vi'],
  ['target.flash',    'nạp firmware lên board thật'],
  ['debug.ask',       'hỏi về một LỖI ĐANG XẢY RA: log, HardFault, vì sao không chạy'],
  ['req.analyze',     'phân tích, làm rõ hoặc truy vết YÊU CẦU'],
  ['arch.design',     'thiết kế kiến trúc, chia module, ánh xạ phần cứng, kiểm xung đột chân'],
  ['diagram.draw',    'vẽ một lược đồ'],
  ['doc.write',       'viết MỘT tài liệu hoặc một mục tài liệu'],
  ['view.ask',        'hỏi TRI THỨC ĐÃ CÓ: thanh ghi, thông số, "X là gì", "vì sao đã chọn Y" (ADR)'],
  ['discover.scan',   'dò cổng, probe, chip đang cắm'],
  ['policy.stop',     'dừng khẩn, dừng mọi việc đang chạy (kể cả "dừng tự chủ")'],
  ['policy.set',      'đổi mức tự chủ, DUYỆT/từ chối mục chờ, HOÀN TÁC việc đã làm'],
  ['big_command',     'lệnh gồm NHIỀU bước thuộc nhiều nhóm: "làm hết đi", "dựng tri thức rồi viết firmware", "bộ tài liệu đầy đủ". CŨNG dùng tạm cho lệnh MỘT bước thuộc nhóm chưa có ý định riêng (registry, bench, measure, passport, kg, tool, search…) — khi ấy `is_big` vẫn là false'],
  ['unknown',         'không hiểu, hoặc mơ hồ tới mức đoán sẽ sai'],
];
// Hai cặp hay lẫn, nêu thẳng thay vì để mô hình suy:
const INTENT_PHAN_BIET = [
  '`view.ask` hỏi tri thức TĨNH đã có trong hộ chiếu; `debug.ask` hỏi về một hiện tượng ĐANG hỏng.',
  '`doc.write` là một tài liệu; cả BỘ tài liệu là `big_command`.',
  '`arch.design` gồm kiểm xung đột chân và ngân sách tài nguyên, không phải `debug.ask`.',
  '`policy.set` gồm cả duyệt hàng đợi và hoàn tác, không phải `knowledge.build`.',
  '`big_command` KHÔNG kéo theo `is_big = true`: "đo dòng tiêu thụ khi ngủ" là một bước (measure.power) nhưng nhóm `measure` chưa có ý định riêng nên vẫn mang nhãn `big_command`.',
];
// `is_big` suy ra từ chuỗi mẫu §4.4, không gán tay — xem PRS-16 §7 và DEVIATIONS DEV-022.
const IS_BIG_QUY_TAC = [
  'Phép thử: lệnh gọi TOÀN BỘ một chuỗi mẫu §4.4, hay chỉ MỘT NÚT của chuỗi ấy?',
  '  toàn bộ chuỗi → true · một nút → false.',
  'Cùng một nhóm năng lực có thể rơi vào cả hai phía: "viết SRS" là một nút (`doc.write`, false),',
  '"viết bộ tài liệu đầy đủ" là cả chuỗi P7 (true); "nạp lên board" là một nút (false),',
  '"dò board rồi nạp" là cả chuỗi Z-10 (true).',
  'Năm chuỗi mẫu: Z-01 dự án mới từ ý tưởng · Z-07 dự án mới từ tài liệu/zip · Z-05 thêm tính năng · P7 bộ tài liệu · Z-10 dò board rồi nạp.',
  '`big_command` KHÔNG kéo theo true: nhãn ấy còn dùng tạm cho lệnh một bước thuộc nhóm chưa có ý định riêng.',
];
fs.writeFileSync('dialog/intents.md',
  '# C0 — danh sách ý định cho vai trò `intent` (sinh từ DPS-09 §4.1)\n\n'
  + INTENT_MO_TA.map(([k, v]) => `- \`${k}\` — ${v}`).join('\n')
  + '\n\nPhân biệt:\n' + INTENT_PHAN_BIET.map(s => `- ${s}`).join('\n')
  + '\n\nis_big:\n' + IS_BIG_QUY_TAC.map(s => `- ${s}`).join('\n') + '\n');

fs.writeFileSync('dialog/intent.schema.json', JSON.stringify(INTENT_SCHEMA, null, 2) + '\n');
c.push(...CODE([
  '{ "type": "object", "required": ["intent", "slots", "is_big", "confidence"],',
  '  "properties": {',
  '    "intent": {"type": "string", "enum": ["project.create", "project.open", "knowledge.build", "env.setup", "sim.run", "code.feature", "target.flash",',
  '                                          "debug.ask", "req.analyze", "arch.design", "diagram.draw", "doc.write", "view.ask", "discover.scan", "policy.stop", "policy.set", "big_command", "unknown"]},',
  '    "slots": {"type": "object", "properties": {"project_name": {"type": "string"}, "idea": {"type": "string"}, "chip": {"type": "string"}, "board": {"type": "string"},',
  '              "path": {"type": "string"}, "feature": {"type": "string"}, "doc_type": {"type": "string"}, "diagram_kind": {"type": "string"}, "question": {"type": "string"}, "level": {"type": "string"}}},',
  '    "is_big": {"type": "boolean"}, "confidence": {"type": "number", "minimum": 0, "maximum": 1}, "lang": {"type": "string", "enum": ["vi", "en"]},',
  '    "mentions": {"type": "array", "items": {"type": "string"}}   /* thực thể người nhắc: tên dự án, mã chip, tệp — để grounding */ } }',
]));
c.push(SP());
c.push(P('Mô hình hiểu lệnh là mô hình rẻ, temperature 0 (vai trò `intent` trong models.yaml), được cung cấp: danh sách ý định, mô tả ngắn của ≤ 30 năng lực liên quan nhất (chọn theo từ khóa), trạng thái dự án tóm tắt, và 2 lượt gần nhất (KAD §6.6b). Confidence < 0,6 ⇒ coi là `unknown` và hỏi lại bằng một câu diễn giải ("Anh muốn tôi tạo dự án mới hay mở dự án robot-ctrl?").'));
c.push(SP());
c.push(P('**Lớp C0 của vai trò `intent`.** "Danh sách ý định" ở trên là một lớp ngữ cảnh cụ thể, không phải một lời khuyên: nó nằm ở `dialog/intents.md`, sinh từ chính §4.1 này, gồm ba phần — mô tả một dòng cho từng ý định, bảng phân biệt các cặp hay lẫn, và quy tắc suy `is_big`. Phải cấp CẢ danh sách ý định lẫn mô tả năng lực, không phải một trong hai: đo trên bộ 50 câu §7 của PRS-16, thiếu hẳn C0 thì độ đúng ý định là **76%**; có C0 đầy đủ thì **96–100%**; và một bản chỉ có mô tả năng lực mà thiếu bảng phân biệt đo được **82%** — mô hình mất chính chỗ tách `view.ask` khỏi `debug.ask`. Xem DEVIATIONS DEV-021.'));
c.push(SP());
c.push(P('Enum có `project.delete` vì POL-17 quy tắc `GEN-03` chặn `action.is_delete_project` như một hành động R4. Không có ý định ấy thì "xóa dự án test-1" buộc phải rơi vào `project.create`, tức tầng hiểu lệnh đọc "xóa" thành "tạo" — và cổng sinh ra để chặn việc xóa sẽ không bao giờ được hỏi tới, vì hành động tới nơi đã mang tên khác.'));
c.push(SP());
c.push(P('Mười bốn trong hai mươi bảy nhóm năng lực chưa có ý định riêng (`registry`, `bench`, `measure`, `passport`, `kg`, `tool`, `search`, `archive`, `extract`, `board`, `plan`, `report`, `chat`, `memory`). Lệnh một bước thuộc những nhóm ấy hiện mang nhãn `big_command` vì không còn chỗ nào khác — nhưng `is_big` của chúng vẫn là `false`, và hai thứ ấy phải được đọc tách nhau. Xem DEVIATIONS DEV-035.'));
c.push(H2('4.2. Đối chiếu trạng thái (D1)'));
c.push(T([2200, 3600, 3500], ['Đối tượng', 'Cách tra', 'Kết quả đưa vào Grounded'], [
  ['Dự án', 'Tên chuẩn hóa (bỏ dấu, tách từ) so với workspace; khớp gần đúng theo từ khóa (robot, cân bằng, balance); thời gian mở gần nhất', 'exists[] {name, created, features passing/total, board}; candidates[] tương tự'],
  ['Mẫu tham chiếu (K5′)', 'search.reference_projects: registry (kind=template) theo idea; sau đó web (chỉ ứng viên, không tải)', 'templates[] {id@ver, verified_on_board, BOM tóm tắt}'],
  ['Chip / board / hộ chiếu', 'passport.list theo mã chip trong lệnh hoặc ảnh (extract.image → nhãn); discover.ports/probes nếu lệnh liên quan phần cứng', 'passports[]; boards[] {lab?, autonomy}; discovery'],
  ['Feature / mã', 'FEATURES.json; kg.neighborhood theo từ khóa (I2C, BME280)', 'features[] failing/passing; code_units[]'],
  ['Môi trường', 'env.check theo ISA của hộ chiếu', 'missing_tools[]'],
]));
c.push(SP());
c.push(H2('4.3. Mặc định và câu hỏi gộp (D2, D3)'));
c.push(P('Thứ tự tìm mặc định cho một ô trống: (1) preferences.yaml của người/dự án (D8); (2) suy ra từ câu lệnh và Grounded (tên dự án từ ý tưởng; chip từ mẫu tham chiếu; board đang cắm); (3) autonomy.yaml.defaults (mức A3, mô hình, thư mục, sim_first, diagram_lang, doc_lang); (4) mặc định của năng lực trong khai báo. Nếu vẫn trống và ô đó *không* ảnh hưởng hành động không hoàn tác ⇒ chọn phương án an toàn nhất và ghi ledger. Nếu trống *và* ảnh hưởng hành động không hoàn tác (ghi đè dự án, xóa, chọn board có động cơ) ⇒ hỏi. Câu hỏi gộp có định dạng cố định để ChatPanel hiển thị dạng thẻ:'));
c.push(...CODE([
  'Question { text: "Anh có board/tài liệu sẵn không, hay tôi dựng theo mẫu tham chiếu để mô phỏng trước?",',
  '           options: [ {n: 1, label: "Mẫu tham chiếu (mặc định)", value: "template"}, {n: 2, label: "Tôi gửi tài liệu", value: "docs"} ],',
  '           default: 1, timeout_s: 120, remember_as: "create_source" }   // trả lời được ghi vào preferences (D8)',
]));
c.push(SP());
c.push(H2('4.4. Lập chuỗi năng lực (②)'));
c.push(P('Với `is_big = true`, Orchestrator lập đồ thị chuỗi bằng mô hình lập kế hoạch (vai trò planner) có output_schema `Chain{nodes[]: {id, cap, args, when?, on_ask}}` và kiểm tra deterministic sau đó: mọi `cap` tồn tại trong registry; tham số khớp input schema; không có chu trình; số nút ≤ ngưỡng; ước lượng chi phí ≤ ngân sách. Nút có `on_ask = parallel` tiếp tục các nhánh không phụ thuộc khi nút đó chờ người; `wait` dừng nhánh; `skip` bỏ qua với ghi chú. Mẫu chuỗi cho các lệnh lớn thường gặp được lưu như K5 thủ tục (skills/orchestration/*.md) để mô hình bám theo thay vì sáng tác: "dự án mới từ zip", "dự án mới từ ý tưởng", "thêm tính năng", "gỡ lỗi từ log", "viết bộ tài liệu", "dò board và nạp".'));
c.push(T([2600, 6700], ['Lệnh lớn', 'Chuỗi mẫu (rút gọn)'], [
  ['Dự án mới từ ý tưởng (Z-01)', 'project.create → search.reference_projects → [template? registry.pull : req.elicit] → passport.pull → board.build_passport(template) → env.check/install_tool → sim.build → req.classify → arch.style_select/decompose/map_hw → diagram.block/architecture → plan.create → chat.report_back'],
  ['Dự án mới từ zip (Z-07)', 'project.create → archive.explore/classify → extract.* → passport.build → board.build_passport → board.check_pins → search.missing → search.web/vendor → search.fetch → kg.review_facts → view.rag_index → env.* → sim.build/run(hello) → req.elicit(README) → plan.create → code.* → sim.run(test) → doc.bringup_guide → report'],
  ['Thêm tính năng (Z-05)', 'chat.ground(dự án) → req.elicit(feature) → req.ground_hw → arch.map_hw(delta) → plan.create → code.module/integrate/test/review → code.merge → sim.run → [board lab? target.flash → target.observe] → doc.section → report'],
  ['Bộ tài liệu (P7)', 'req.trace_matrix → diagram.* (theo loại tài liệu) → doc.generate(URD, SRS, SAD, SDD, STP) → doc.embed_diagram → doc.style_check → report'],
  ['Dò board và nạp (Z-10)', 'discover.ports/probes → discover.chip_id → [khớp hộ chiếu?] → discover.link_speed → discover.auto_setup → policy.decide(G-OPS) → target.flash → target.serial/observe → report'],
]));
c.push(SP());
c.push(H2('4.5. Ưu tiên nguồn khi suy luận (D5) và ghi nhớ (D8)'));
c.push(P('Khi phải suy ra chip/board/linh kiện/tham số cho một ý tưởng, thứ tự là: điều người nói > dự án hiện có > mẫu tham chiếu trong registry (K5′) > web (chỉ ứng viên). Mọi suy luận được trình bày là **đề xuất có nguồn** ("BOM tham chiếu từ eide.ref.balancing-robot@1.2, đã kiểm định trên board") và mang nhãn tạm cho tới khi người xác nhận hoặc có fact thật (Z-09: tham số vật lý mặc định gắn nhãn "tham số tạm"). Mỗi câu trả lời của người cho một Question có `remember_as` được ghi vào preferences.yaml với phạm vi (người/dự án); lần sau Orchestrator áp dụng và chỉ nhắc "áp dụng như lần trước: dùng ST-Link". Người có thể nói "hỏi lại tôi mỗi lần" để xóa một tùy chọn.'));
c.push(H1('5. Kịch bản đầu vào trống Z-01…Z-10'));
c.push(P('Mười kịch bản dưới đây là đặc tả hành vi *và* bộ kiểm thử bắt buộc (STP-05 TC-59…TC-64, mức L2b): mỗi kịch bản chạy với mô hình hiểu lệnh thật (ghi/phát lại), kiểm tra tác tử tra đúng thứ, làm đúng phần chắc chắn, hỏi đúng một câu (nếu cần) với mặc định đúng, và không tạo trùng/ghi đè.'));
D.SCENARIOS.forEach(z => {
  c.push(H2(`${z[0]} — ${z[1]}`));
  c.push(T([2300, 7000], ['Mục', 'Nội dung'], [
    ['Tác tử kiểm tra gì (D1)', z[2]], ['Kết quả kiểm tra', z[3]], ['Tác tử làm / hỏi gì', z[4]], ['Câu hỏi mẫu', z[5]], ['Mặc định / timeout', z[6]], ['UC / năng lực', z[7]],
  ]));
  c.push(SP());
});
c.push(H1('6. Giao diện hội thoại trong GEditor'));
c.push(P('ChatPanel là màn hình mặc định khi mở dự án (PDA-00 P8). Các thành phần: (1) ô lệnh với gợi ý năng lực khi gõ "/" (mọi năng lực có `ui` đều gọi được bằng lệnh); (2) thẻ "tôi hiểu là… tôi sẽ…" có nút sửa; (3) thẻ câu hỏi gộp với phương án đánh số, mặc định được tô và đếm ngược timeout; (4) dòng tiến độ chuỗi (nút đang chạy, nút chờ, nút song song); (5) thẻ báo cáo cuối với bốn mục và nút hoàn tác cho từng việc tự làm; (6) thanh trạng thái tự chủ "A3 · 12 việc tự làm hôm nay · 2 chờ anh · hoàn tác được đến 09:14" và nút dừng khẩn. Hàng đợi tách "chờ tôi" (ASK) và "đã làm — hoàn tác được" (APPROVE). Câu trả lời của tác tử neo được vào tài liệu, lược đồ, fact hoặc dòng log liên quan (view.*).'));
c.push(H1('7. Đo lường và tiêu chí chấp nhận'));
c.push(T([3000, 3300, 3000], ['Chỉ số', 'Cách đo', 'Mục tiêu bản đầu'], [
  ['Số câu hỏi trên một lệnh', 'Đếm Question trong ledger / số lệnh', '≤ 1 trung bình; 0 sau khi preferences ổn định'],
  ['Số lần bấm/duyệt trong kịch bản chuẩn', 'Đếm ASK + thao tác UI trong ledger', '≤ 5'],
  ['Tỷ lệ ý định đúng', 'Bộ 50 lệnh Việt/Anh có nhãn (TC-59)', '≥ 95%'],
  ['Tạo trùng / ghi đè ngoài ý muốn', 'TC-60; nhật ký project.create', '0'],
  ['Thời gian từ lệnh đến báo cáo (không tính chờ người)', 'Ledger run', 'Kịch bản chuẩn ≤ 30 phút với sim'],
  ['Tỷ lệ hoàn tác việc tự làm', 'UndoService.apply / capability_run tự động', '≤ 5% (cao hơn ⇒ ngưỡng quá lỏng, xem APD §6)'],
  ['Tỷ lệ mặc định bị người đổi', 'Ledger defaults_applied vs. sửa của người', '≤ 20% (cao hơn ⇒ mặc định sai, sửa autonomy.yaml/preferences)'],
]));
c.push(SP());
c.push(H1('8. Rủi ro và biện pháp'));
c.push(T([3000, 6300], ['Rủi ro', 'Biện pháp'], [
  ['Hiểu sai ý định và làm việc không hoàn tác', 'Việc không hoàn tác luôn qua ASK (D7, APD R4); nói lại ý hiểu trước chuỗi dài (D6); confidence thấp ⇒ hỏi'],
  ['Hỏi quá nhiều (quay lại "trợ lý xin phép")', 'Hạn mức một câu/lượt (D3); mặc định trước (D2); ghi nhớ (D8); chỉ số §7 theo dõi'],
  ['Mặc định sai âm thầm', 'Mọi mặc định ghi ledger và hiện trong thẻ "tôi hiểu là"; đổi được bằng một câu; chỉ số tỷ lệ mặc định bị đổi'],
  ['Mô hình hiểu lệnh bịa năng lực/tham số', 'Kiểm deterministic sau mô hình: cap phải tồn tại, args khớp schema; mẫu chuỗi K5 thủ tục'],
  ['Kịch bản hội thoại lệch khi đổi mô hình', 'Z-01…Z-10 là TC L2b chạy lại khi đổi mô hình/prompt; ghi/phát lại'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-DPS-09_Chinh_sach_hoi_thoai.docx');
