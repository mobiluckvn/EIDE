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
  + 'toàn bộ một chuỗi mẫu §4.4 → true, một nút của chuỗi → false (DEV-022).'],
  ['1.2', '07/09/2026', 'Vũ Trí Công',
   '§4.4: năm chuỗi mẫu chuyển vào literal đặt tên và sinh ra `dialog/chains.json`, kèm cột ý '
   + 'định kích hoạt (`trigger_intents`) mà CHAT-06 bước 1 nhắc tới nhưng bảng chưa có. Trước đó '
   + 'bảng chỉ nằm trong văn xuôi nên `chat.orchestrate` phải chép tay — cùng khuôn '
   + 'DEV-025/029/043/046.'],
  ['1.3', '07/09/2026', 'Vũ Trí Công',
   '§4.4: thêm trường `nodes` — dạng MÁY DÙNG ĐƯỢC của năm chuỗi mẫu, mỗi nút `{id, cap, when, on_ask}` với `cap` là id THẬT trong danh mục 238. Trước v1.3 chỉ có bản văn xuôi, trong đó chín tên là viết tắt không phân giải được (`passport.build`, `sim.build`, `code.module`, `discover.probes`…), nên phần khung mà mẫu đóng góp cho `chat.orchestrate` nhỏ hơn hẳn ý định của §4.4 — và đúng những bước then chốt lại rơi vào tay planner, tức về lại chỗ "sáng tác" mà mẫu sinh ra để tránh. Nhánh điều kiện biểu diễn bằng `on_ask: skip`. DEV-059.']];
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
      // [DEV-208] Bốn ĐỘNG TỪ mà người dùng gõ nhiều nhất và enum chưa có tên. Chính mô tả
      // của `big_command` dưới đây đã thú nhận chỗ trống: "CŨNG dùng tạm cho lệnh MỘT bước
      // thuộc nhóm chưa có ý định riêng (registry, bench, measure, passport, kg, tool,
      // search…)". Đo 23/09/2026: 14 trên 57 ca trượt rơi vào `big_command` rồi được xử lý
      // như một yêu cầu cần RÚT, trong khi người dùng nhờ RÀ SOÁT, TÌM, TÍNH, CHẠY.
      'review.ask', 'search.ask', 'compute.ask', 'tool.run',
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
  ['req.analyze',     'phân tích, làm rõ hoặc truy vết YÊU CẦU — làm việc TRÊN CHÍNH tập yêu cầu: rút ra, gán mã, tìm chỗ mơ hồ/mâu thuẫn, viết tiêu chí nghiệm thu'],
  ['arch.design',     'thiết kế kiến trúc: chia hệ thống thành MODULE/khối chức năng, chọn kiểu kiến trúc, ánh xạ phần cứng, kiểm xung đột chân, viết ADR'],
  ['diagram.draw',    'vẽ một lược đồ'],
  ['doc.write',       'viết MỘT tài liệu hoặc một mục tài liệu'],
  ['view.ask',        'hỏi TRI THỨC ĐÃ CÓ: thanh ghi, thông số, "X là gì", "vì sao đã chọn Y" (ADR)'],
  ['discover.scan',   'dò cổng, probe, chip đang cắm'],
  ['policy.stop',     'dừng khẩn, dừng mọi việc đang chạy (kể cả "dừng tự chủ")'],
  ['policy.set',      'đổi mức tự chủ, DUYỆT/từ chối mục chờ, HOÀN TÁC việc đã làm'],
  ['big_command',     'lệnh gồm NHIỀU bước thuộc nhiều nhóm: "làm hết đi", "dựng tri thức rồi viết firmware", "bộ tài liệu đầy đủ". CŨNG dùng tạm cho lệnh MỘT bước thuộc nhóm chưa có ý định riêng (registry, bench, measure, passport, kg, tool, search…) — khi ấy `is_big` vẫn là false'],
  ['review.ask',      'RÀ SOÁT một hiện vật có sẵn: netlist, schematic, mã nguồn, BOM — "kiểm giúp", "có lỗi gì không", "đối chiếu X với Y"'],
  ['search.ask',      'TÌM tài liệu hoặc linh kiện: datasheet, errata, mạch tham khảo, linh kiện thay thế, tình trạng vòng đời'],
  ['compute.ask',     'TÍNH một con số kỹ thuật: thời gian dùng pin, tản nhiệt, trở hạn dòng, timing — tính bằng code có kiểm chứng, không nhẩm'],
  ['tool.run',        'CHẠY một lệnh hoặc kịch bản người dùng đưa'],
  ['unknown',         'không hiểu, hoặc mơ hồ tới mức đoán sẽ sai'],
];
// Hai cặp hay lẫn, nêu thẳng thay vì để mô hình suy:
const INTENT_PHAN_BIET = [
  '`view.ask` hỏi tri thức TĨNH đã có trong hộ chiếu; `debug.ask` hỏi về một hiện tượng ĐANG hỏng.',
  '`doc.write` là một tài liệu; cả BỘ tài liệu là `big_command`.',
  '`arch.design` gồm kiểm xung đột chân và ngân sách tài nguyên, không phải `debug.ask`.',
  // [DEV-165] Cặp lẫn thứ ba, đo được 22/09/2026 trên bài CNC.
  '`req.analyze` làm việc TRÊN yêu cầu (rút ra, gán mã, tìm mâu thuẫn); `arch.design` làm việc TỪ yêu cầu ĐỂ RA module. Động từ quyết định, không phải danh từ: "chia hệ thống thành các khối", "thiết kế", "kiến trúc", "module" → `arch.design` — KỂ CẢ khi câu mở đầu bằng "từ các yêu cầu đã có". Một câu nhắc tới yêu cầu không có nghĩa là nó xin phân tích yêu cầu.',
  '`policy.set` gồm cả duyệt hàng đợi và hoàn tác, không phải `knowledge.build`.',
  '`big_command` KHÔNG kéo theo `is_big = true`: "đo dòng tiêu thụ khi ngủ" là một bước (measure.power) nhưng nhóm `measure` chưa có ý định riêng nên vẫn mang nhãn `big_command`.',
  'HƯỚNG ĐÃ CHỐT (DEV-035, 08/09/2026): nhóm năng lực nào còn thiếu thì thêm Ý ĐỊNH RIÊNG cho nhóm ấy, KHÔNG mở rộng nghĩa của `big_command`. `big_command` mô tả HÌNH DẠNG của lệnh (nhiều bước, nhiều nhóm), nên nhét thêm nghĩa "nhóm chưa có ý định" vào là trộn hai chiều phân loại khác nhau vào một nhãn. Việc thêm hoãn tới CHAT-06 `chat.orchestrate` vì lúc ấy Orchestrator phải chọn năng lực cho từng ý định nên bảng ánh xạ thiếu sẽ tự lộ ra; làm sớm thì phải gán nhãn lại cả 50 câu của TC-59 mà chưa có gì bắt buộc.',
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
  '                                          "debug.ask", "req.analyze", "arch.design", "diagram.draw", "doc.write", "view.ask", "discover.scan", "policy.stop", "policy.set", "big_command", "unknown",',
  '                                          "review.ask", "search.ask", "compute.ask", "tool.run", "project.delete"]},',
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
// §4.4 năm chuỗi mẫu. Đặt tên literal để sinh ra `dialog/chains.json`: `chat.orchestrate`
// chọn chuỗi theo ý định TRƯỚC khi nhờ mô hình lập kế hoạch, và một bảng chỉ nằm trong văn
// xuôi thì phần mã phải chép tay — đúng khuôn DEV-025/029/043/046.
//
// Cột thứ ba là ý định kích hoạt (`trigger_intents` mà CHAT-06 bước 1 nhắc tới); nó không
// hiện trong bảng của tài liệu vì tài liệu đã nêu mã kịch bản Z-xx ngay ở cột đầu.
const CHUOI_MAU = [
  ['Dự án mới từ ý tưởng (Z-01)', 'project.create → search.reference_projects → [template? registry.pull : req.elicit] → passport.pull → board.build_passport(template) → env.check/install_tool → sim.build → req.classify → arch.style_select/decompose/map_hw → diagram.block/architecture → plan.create → chat.report_back', ['project.create']],
  ['Dự án mới từ zip (Z-07)', 'project.create → archive.explore/classify → extract.* → passport.build → board.build_passport → board.check_pins → search.missing → search.web/vendor → search.fetch → kg.review_facts → view.rag_index → env.* → sim.build/run(hello) → req.elicit(README) → plan.create → code.* → sim.run(test) → doc.bringup_guide → report', ['knowledge.build']],
  ['Thêm tính năng (Z-05)', 'chat.ground(dự án) → req.elicit(feature) → req.ground_hw → arch.map_hw(delta) → plan.create → code.module/integrate/test/review → code.merge → sim.run → [board lab? target.flash → target.observe] → doc.section → report', ['code.feature']],
  ['Bộ tài liệu (P7)', 'req.trace_matrix → diagram.* (theo loại tài liệu) → doc.generate(URD, SRS, SAD, SDD, STP) → doc.embed_diagram → doc.style_check → report', ['doc.write']],
  ['Dò board và nạp (Z-10)', 'discover.ports/probes → discover.chip_id → [khớp hộ chiếu?] → discover.link_speed → discover.auto_setup → policy.decide(G-OPS) → target.flash → target.serial/observe → report', ['discover.scan', 'target.flash']],
  // Mẫu thứ SÁU, thêm v1.3 ([DEV-147]). `req.analyze` là một trong 19 ý định của
  // `dialog/intent.schema.json` nhưng không mẫu nào nhận nó, và nó cũng không trùng tên một
  // năng lực nào — nên nó rơi xuống planner, và planner phác chuỗi từ văn xuôi nên bắt đầu từ
  // GIỮA quy trình. Đo 21/09/2026 trên bài CNC: tác tử hiểu đúng ("bỏ hẳn việc cầm USB đi
  // lại"), rồi nhảy thẳng vào `arch.decompose` và đi hỏi người `reqset_ids` — đúng thứ mà
  // `req.classify` lẽ ra phải sinh ra hai bước trước đó.
  //
  // Chưa mang mã Z: Z-01…Z-10 là một dãy có thật (PDA §M1) nhưng §4.4 chỉ trải ra năm mục, và
  // mượn một mã mình không biết nội dung là đặt tên cho thứ của người khác.
  ['Làm rõ yêu cầu (DEV-147)', 'req.elicit → req.classify → req.detect_conflict → req.prioritize → req.acceptance → report', ['req.analyze']],
  // [DEV-155] Hai ý định CHÍNH SÁCH. Chúng không trùng tên năng lực nào — tên thật là
  // `policy.emergency_stop` và `policy.set_autonomy` — nên trước v1.3 chúng rơi xuống
  // planner, tức một lệnh DỪNG phải đi qua hai lượt gọi mô hình để được thi hành.
  //
  // Mỗi mẫu đúng MỘT nút: đây là hai việc tức thời, không có gì để lập kế hoạch. Một chuỗi
  // nhiều bước ở đây chỉ thêm chỗ để hỏng.
  ['Dừng khẩn (DEV-155)', 'policy.emergency_stop', ['policy.stop']],
  // [DEV-158] Hai ý định THIẾT KẾ. Trước v1.3 chúng rơi xuống planner, và planner phác
  // chuỗi từ văn xuôi nên bắt đầu từ giữa quy trình rồi đi hỏi người `reqset_ids` — ĐÚNG
  // thứ đang nằm trong store ngay dưới chân nó.
  //
  // Nút ĐẦU là `view.artifacts`: cú pháp `${nX.field}` chỉ trỏ tới nút TRƯỚC, không đọc
  // được store. Nhưng `view.artifacts` là một năng lực, nên cho nó làm nút đầu thì phần
  // còn lại của chuỗi nối được vào dữ liệu đã có — không phải hỏi lại người thứ họ đã nói.
  ['Thiết kế kiến trúc (DEV-158)', 'view.artifacts(requirement) → arch.style_select → arch.decompose → arch.interface_spec → arch.adr → arch.review → report', ['arch.design']],
  // `diagram.architecture` chứ KHÔNG `diagram.block`: block vẽ lược đồ BO MẠCH và đòi
  // `board`, còn người nói "vẽ lược đồ khối cho thiết kế" muốn lược đồ KIẾN TRÚC — thứ
  // không cần tham số bắt buộc nào. Dẫn sai năng lực thì chuỗi dừng để hỏi một bo mạch mà
  // dự án phần mềm không có.
  ['Vẽ lược đồ (DEV-158)', 'view.artifacts(module) → diagram.architecture → report', ['diagram.draw']],
  // ───────────────────────────────────────────────────────────── [DEV-201] bảy ý định bị bỏ rơi
  //
  // Đo 23/09/2026 trên bộ 76 usecase: bảng có 19 ý định nhưng chỉ 10 mẫu, phủ 12 giá trị.
  // BẢY ý định không mẫu nào nhận, nên chúng rơi xuống planner — và planner phác chuỗi từ
  // văn xuôi nên hoặc bắt đầu từ giữa quy trình, hoặc trả về CHUỖI RỖNG rồi lượt bị bác bỏ
  // bằng E5002. Hệ quả nặng nhất: `view.ask` là ý định của MỌI CÂU HỎI, nên tới bản này
  // **sản phẩm không trả lời được một câu hỏi nào**.
  //
  // Đây là lần thứ TƯ cùng một lớp lỗi được vá từng dòng — DEV-147 (`req.analyze`),
  // DEV-155 (hai ý định chính sách), DEV-158 (hai ý định thiết kế), và bây giờ. Nên lần này
  // kèm một phép kiểm toàn phần (`test_moi_y_dinh_deu_co_mau_chuoi`): bảng không được thủng
  // nữa, và một ý định thêm vào sau này không lọt qua được.

  // Câu HỎI. `${_text}` = chính câu người dùng gõ — mẫu là chỗ DUY NHẤT được quyền nói tham
  // số nào nhận nó (xem `_noi_dau_ra` trong chat.py và DEV-121); viết bảng ánh xạ tên vào mã
  // là tự nghĩ ra hành vi.
  ['Trả lời câu hỏi (DEV-201)', 'ingest.index_text → view.rag_index → view.rag_ask → chat.report_back', ['view.ask']],
  // CHẨN ĐOÁN. Cũng bắt đầu bằng trả lời, vì một câu "cảm biến I2C không phản hồi, làm sao
  // biết lỗi phần cứng hay phần mềm" là một CÂU HỎI trước khi là một phiên gỡ lỗi. Ba nút
  // `debug.*` mang `on_ask: skip`: khi dự án đã có bằng chứng (log, capture) thì chúng chạy
  // và làm giàu câu trả lời; chưa có thì bỏ qua, KHÔNG chặn cả chuỗi để đi hỏi `evidence_ids`.
  ['Chẩn đoán (DEV-201)', 'view.rag_index → view.rag_ask → debug.hypothesize → debug.experiment → debug.propose_fix → chat.report_back', ['debug.ask']],
  // MÔ PHỎNG. `sim.build_platform` trước: nền tảng chưa dựng thì `sim.run` không có gì để
  // chạy, và đó đúng là trạng thái mà màn Mô phỏng báo ở bốn ca kiểm thử.
  ['Chạy mô phỏng (DEV-201)', 'sim.build_platform → sim.scenario → sim.run → chat.report_back', ['sim.run']],
  // MỞ LẠI DỰ ÁN. `project.status` sau `project.open` để tác tử có cái mà thuật lại; không
  // có nó thì câu "tiếp tục dự án này, trước đó đã chốt gì" không có nguồn nào để trả lời.
  ['Mở lại dự án (DEV-201)', 'project.open → project.status → view.artifacts(requirement) → chat.report_back', ['project.open']],
  ['Dựng môi trường (DEV-201)', 'env.detect → env.check → env.guide_install → chat.report_back', ['env.setup']],
  ['Lưu trữ dự án (DEV-201)', 'project.archive → chat.report_back', ['project.delete']],
  // KHÔNG HIỂU. Mẫu một nút: hỏi lại cho có trọng tâm. Không có mẫu thì `unknown` rơi xuống
  // planner, và planner ĐOÁN ra một việc — đúng thứ tệ nhất cho một câu chưa hiểu được.
  ['Chưa hiểu, hỏi lại (DEV-201)', 'req.elicit → chat.clarify → chat.report_back', ['unknown']],
  // `big_command` tách khỏi mẫu giải nén Z-07. Nó là thùng chứa mọi câu chưa phân loại được,
  // còn Z-07 là quy trình MỞ MỘT KHO TÀI LIỆU, mở đầu bằng `project.create → archive.list`.
  // Hệ quả đo được: câu của người dùng bị biến thành một ĐƯỜNG DẪN TỆP rồi báo E2000 "Không
  // có tệp …/tim-tren-mang-datasheet-moi-nhat-cua-sen42" — một lỗi TỆP cho một việc TÌM MẠNG.
  // Mười ba ca kiểm thử chết ở đúng chỗ này.
  ['Việc lớn chưa rõ (DEV-201)', 'view.artifacts(requirement) → ingest.classify → ingest.index_text → req.elicit → req.classify → chat.report_back', ['big_command']],
  // ───────────────────────────────────────────── [DEV-208] Bốn động từ, bốn mẫu.
  //
  // KHÔNG năng lực nào mới. Cả bốn chuỗi dưới đây chỉ nối vào thứ đã hiện thực từ lâu —
  // `search.web`, `tool.write`, `tool.run`, `env.sandbox`, `code.static`,
  // `extract.kicad_netlist`. Đo 23/09/2026: 29 năng lực `extract.*`/`ingest.*`/`archive.*` và
  // cả bộ `tool.*` đều hiện thực xong. Thứ thiếu suốt từ đầu là TÊN GỌI để với tới chúng.
  ['Rà soát hiện vật (DEV-208)', 'ingest.index_text → extract.kicad_netlist → board.check_pins → board.propose_fix → code.static → view.rag_ask → chat.report_back', ['review.ask']],
  ['Tìm tài liệu / linh kiện (DEV-208)', 'search.web → search.fetch → chat.report_back', ['search.ask']],
  // UC13 đòi đúng chữ này: "tính bằng code/công thức có kiểm chứng (KHÔNG nhẩm)". `tool.write`
  // sinh một công cụ nhỏ rồi `tool.run` chạy nó — con số ra từ mã chạy được, tái lập được.
  ['Tính toán kỹ thuật (DEV-208)', 'tool.write → tool.run → chat.report_back', ['compute.ask']],
  ['Chạy lệnh trong hộp cát (DEV-208)', 'env.sandbox → chat.report_back', ['tool.run']],
  ['Đổi mức tự chủ (DEV-155)', 'policy.set_autonomy', ['policy.set']],
];
// §4.4 — dạng MÁY DÙNG ĐƯỢC của năm chuỗi trên. Cột `chuoi` ở trên là văn xuôi cho người
// đọc: nó có nhánh điều kiện viết bằng chữ ("[template? … : …]"), ký hiệu nhóm ("extract.*"),
// và tên viết tắt không phải id thật (`passport.build`, `sim.build`, `code.module`…). Chín tên
// như thế không phân giải được, nên phần khung mà mẫu đóng góp cho `chat.orchestrate` nhỏ hơn
// hẳn ý định của §4.4 — và đúng những bước then chốt (dựng hộ chiếu, sinh module, dò probe)
// lại rơi vào tay planner, tức về lại chỗ "sáng tác" mà mẫu sinh ra để tránh. Xem DEV-059.
//
// `cap` dưới đây là id THẬT trong danh mục 238; `when` là id nút phải xong trước (DPS-09 §4.4
// ChainNode); `on_ask` theo enum wait|parallel|skip.
//
// PHẦN TỬ THỨ 5 — `args`, thêm v1.3 (DEV-121). Đây là chỗ MẪU nói bước nào lấy dữ liệu của
// bước nào, bằng tham chiếu `${nX.duong.doc}`. Máy giải tham chiếu đã có sẵn trong
// `eide_core.chain` (`THAM_CHIEU`, `doc_duong`, `giai_tham_chieu`) từ 17/09, nhưng **không có
// dữ liệu để giải**: mô hình `Nut` không có chỗ nào viết được "tham số này lấy từ nút n7".
//
// Hệ quả đo được 17/09 qua giao diện: gõ "đọc cảm biến BME280 qua I2C" trả về một bức tường
// E5002 liệt kê bảy nút thiếu tham số bắt buộc, và KHÔNG một nút nào chạy — vì §4.4 kiểm CẢ
// chuỗi ngay lúc lập, trong khi `code.merge` cần `patch` mà `code.integrate` mới sinh ra.
//
// **Chỉ điền chỗ SUY ĐƯỢC TỪ HỢP ĐỒNG.** Mỗi dòng dưới đây nối một `output_schema` với một
// `input_schema` mà tên và kiểu khớp nhau; chỗ nào phải đoán thì để TRỐNG kèm ghi chú, vì
// viết bừa vào đây là biến một phỏng đoán thành đặc tả. Năm chỗ còn trống và lý do:
//
//   - Z-05 `arch.map_hw.module_ids` — chuỗi Z-05 KHÔNG có nút `arch.decompose`, nên không nút
//     nào trong chuỗi sinh ra `module_graph`. Đây là một lỗ của chính chuỗi mẫu, không phải
//     của phép nối.
//   - Z-05 `code.integrate.modules` — `arr<str>` id module; hai ứng viên (`arch.decompose` và
//     các nút `code.generate_module` chạy nhiều lượt) và không hợp đồng nào nói cái nào.
//   - Z-05 `code.merge.reports` / `review_id` — `reports` là `arr<str>`, không rõ trỏ tới
//     `tool_report` hay `sim.run.report`; `review_id` cần trường `id` BÊN TRONG `code.review
//     .review`, mà `output_schema` của nó khai `{"type":"object"}` trần.
//   - Z-05 `sim.run.artifact` — chuỗi không có nút dựng firmware nào.
//   - Z-05 `doc.section.target` — `target` là mục tài liệu cần viết, không phải đầu ra
//     của nút nào; nó đến từ ý định hoặc từ người.
//
// Chặng SÂU của đường đọc (`plan.steps[0].id`) chỉ kiểm được lúc CHẠY: phần lớn
// `output_schema` khai `{"type":"object"}` kèm một câu mô tả, nên khẳng định hơn thế lúc lập
// là một lời chắc chắn dựa trên không gì cả.
const CHUOI_NUT = {
  'Dự án mới từ ý tưởng (Z-01)': [
    ['n1', 'project.create'], ['n2', 'search.reference_projects', 'n1'],
    ['n3', 'registry.pull', 'n2', 'skip'], ['n4', 'req.elicit', 'n2'],
    ['n5', 'board.build_passport', 'n3', 'skip'], ['n6', 'env.check', 'n1'],
    ['n7', 'sim.build_platform', 'n5', 'skip'],
    ['n8', 'req.classify', 'n4', 'wait', { raw: '${n4.raw}' }],
    ['n9', 'arch.style_select', 'n8', 'wait', { reqset_ids: '${n8.reqset[*].id}' }],
    ['n10', 'arch.decompose', 'n9', 'wait',
      { reqset_ids: '${n8.reqset[*].id}', style: '${n9.decision.style}' }],
    ['n11', 'arch.map_hw', 'n10', 'wait',
      { module_ids: '${n10.module_graph.modules[*].id}' }],
    ['n12', 'diagram.block', 'n10', 'parallel'],
    ['n13', 'plan.create', 'n11'], ['n14', 'chat.report_back', 'n13'],
  ],
  // Sáu nút, dưới trần 12 của §4.4. Ba nút cuối cùng treo vào `n2` chứ không nối tiếp nhau:
  // xung đột, ưu tiên và tiêu chí nghiệm thu đều chỉ cần tập yêu cầu, không cần kết quả của
  // nhau — nối tiếp chúng là bắt người dùng đợi ba lượt mô hình nối đuôi cho ba việc chạy song
  // song được.
  'Dừng khẩn (DEV-155)': [['n1', 'policy.emergency_stop']],
  'Thiết kế kiến trúc (DEV-158)': [
    ['n1', 'view.artifacts', null, 'wait', { kind: 'requirement', limit: 200 }],
    // `passport` KHÔNG suy được: dự án chưa ghim chip nào thì không có gì để suy. Để trống
    // để nút dừng và HỎI — đúng hơn là đoán một con chip.
    ['n2', 'arch.style_select', 'n1', 'wait', { reqset_ids: '${n1.items[*].id}' }],
    ['n3', 'arch.decompose', 'n2', 'wait',
      { reqset_ids: '${n1.items[*].id}', style: '${n2.decision.style}' }],
    ['n4', 'arch.interface_spec', 'n3', 'parallel',
      { module_ids: '${n3.module_graph.modules[*].id}' }],
    ['n5', 'arch.adr', 'n2', 'parallel', { decision: '${n2.decision}' }],
    ['n6', 'arch.review', 'n3', 'parallel',
      { module_ids: '${n3.module_graph.modules[*].id}' }],
    ['n7', 'chat.report_back', 'n6'],
  ],
  'Vẽ lược đồ (DEV-158)': [
    ['n1', 'view.artifacts', null, 'wait', { kind: 'module', limit: 200 }],
    ['n2', 'diagram.architecture', 'n1', 'wait', { module_ids: '${n1.items[*].id}' }],
    ['n3', 'chat.report_back', 'n2'],
  ],
  // `level` và `by` là hai tham số BẮT BUỘC mà chuỗi không suy được: mức mới đến từ câu người
  // nói, tên người đến từ phiên. Để trống thì nút dừng ở "thiếu tham số" và HỎI — đúng hơn là
  // đoán một mức tự chủ.
  'Đổi mức tự chủ (DEV-155)': [['n1', 'policy.set_autonomy']],

  // ─────────────────────────────────────────────────────── [DEV-201] dạng máy chạy được
  //
  // `${_text}` là CÂU GỐC của người dùng. Cú pháp `${nX.field}` chỉ trỏ được sang một nút
  // trước; không có gì trỏ sang chính lời người nói, nên `view.rag_ask.question` — tham số
  // của một năng lực có nhiệm vụ TRẢ LỜI CÂU HỎI — không có cách nào nhận được câu hỏi.
  // `_args_cho` chỉ ghép khi TÊN trùng khít, và nó cố ý từ chối bảng ánh xạ tên ("viết vào
  // mã là tự nghĩ ra hành vi"); chú thích ấy cũng chỉ luôn chỗ đúng để khai — chính mẫu.
  // [DEV-202] `ingest.index_text` đứng đầu và KHÔNG có nút nào phụ thuộc nó.
  //
  // Người dùng gõ "Đọc /…/rm-mcux-v3.1.md rồi cho tôi biết bit nào bật DMA cho SPI2 TX".
  // `chat.parse_intent` rút đúng `slots.path` và `slots.question` — dữ liệu vẫn nằm đó từ
  // đầu, chỉ là không nút nào tiêu thụ. Tới bản trước, mọi đường dẫn đều đi qua
  // `archive.list` (năng lực LIỆT KÊ KHO NÉN) và nhận E1000 "Không nhận ra định dạng nén của
  // dem_xung.c" — một câu lỗi đúng của một năng lực bị gọi sai việc.
  //
  // Không nút nào phụ thuộc n1 là CÓ CHỦ Ý: câu hỏi không kèm đường dẫn thì n1 hỏng (thiếu
  // `files`), và nếu `view.rag_index` chờ nó thì mọi câu hỏi thường cũng chết theo. Một nút
  // làm giàu phải hỏng được mà không kéo ai theo.
  'Trả lời câu hỏi (DEV-201)': [
    ['n1', 'ingest.index_text', null, 'skip', { files: ['${_path}'] }],
    ['n2', 'view.rag_index', null, 'skip'],
    ['n3', 'view.rag_ask', 'n2', 'wait', { question: '${_text}' }],
    ['n4', 'chat.report_back', 'n3'],
  ],
  // Ba nút `debug.*` mang `skip`: có bằng chứng thì làm giàu câu trả lời, chưa có thì bỏ
  // qua. Để `wait` thì một câu hỏi chẩn đoán bình thường sẽ dừng lại đòi `evidence_ids` —
  // đúng lỗi "hỏi tham số năng lực thay vì trả lời bài toán" mà bộ kiểm thử đo được.
  'Chẩn đoán (DEV-201)': [
    ['n1', 'view.rag_index', null, 'skip'],
    ['n2', 'view.rag_ask', 'n1', 'wait', { question: '${_text}' }],
    ['n3', 'debug.hypothesize', 'n2', 'skip'],
    ['n4', 'debug.experiment', 'n3', 'skip'],
    ['n5', 'debug.propose_fix', 'n3', 'skip'],
    ['n6', 'chat.report_back', 'n2'],
  ],
  'Chạy mô phỏng (DEV-201)': [
    ['n1', 'sim.build_platform', null, 'wait'],
    ['n2', 'sim.scenario', 'n1', 'skip'],
    // `scenario_path`, KHÔNG `scenario`: `sim.scenario` trả ra đường dẫn tệp kịch bản, và
    // `sim.run.scenario` nhận chính đường dẫn ấy. Bài kiểm `test_moi_phep_noi_khop_HAI_DAU`
    // bắt được chỗ này — một phép nối sai tên thì chuỗi chết ở phép kiểm deterministic, sau
    // khi vài nút trước đã ghi xuống store.
    ['n3', 'sim.run', 'n2', 'wait', { scenario: '${n2.scenario_path}' }],
    ['n4', 'chat.report_back', 'n3'],
  ],
  // `project` để TRỐNG có chủ ý: `_args_cho` điền nó từ dự án đang mở. Điền cứng ở đây thì
  // mẫu quyết định thay phiên làm việc, và câu "tiếp tục dự án này" sẽ mở nhầm dự án khác.
  'Mở lại dự án (DEV-201)': [
    ['n1', 'project.open'],
    ['n2', 'project.status', 'n1'],
    ['n3', 'view.artifacts', 'n2', 'skip', { kind: 'requirement' }],
    ['n4', 'chat.report_back', 'n3'],
  ],
  'Dựng môi trường (DEV-201)': [
    ['n1', 'env.detect'],
    ['n2', 'env.check', 'n1', 'wait'],
    ['n3', 'env.guide_install', 'n2', 'skip'],
    ['n4', 'chat.report_back', 'n2'],
  ],
  'Lưu trữ dự án (DEV-201)': [
    ['n1', 'project.archive'],
    ['n2', 'chat.report_back', 'n1'],
  ],
  // [DEV-206] `req.elicit` ĐỨNG TRƯỚC, và `chat.clarify` nhận `gaps` của nó.
  //
  // Bản [DEV-201] đặt một nút `chat.clarify` đơn lẻ. Nhưng năng lực ấy đòi `gaps` — danh sách
  // điểm còn mơ hồ — mà không nút nào sinh ra, nên tác tử đi hỏi người dùng đúng chữ `gaps`.
  // Đo lại 23/09/2026 trên TC004: màn Làm rõ yêu cầu hiện "Bước `chat.clarify` đang chờ anh
  // cho biết: • `gaps`". Một câu hỏi bằng tiếng của hợp đồng, hỏi người dùng về một khái niệm
  // nội bộ — và TỆ HƠN cái nó thay thế: trước đó `unknown` rơi xuống planner, và planner ít
  // ra còn hỏi được "Chưa rõ yêu cầu về kết nối mạng (Wi-Fi, Bluetooth, Zigbee, LoRa)".
  //
  // Bài học: bù một mẫu chuỗi mà không kiểm nút đầu có đủ dữ kiện để chạy thì mẫu ấy chỉ đổi
  // chỗ hỏng, không sửa nó. `req.elicit` không đòi tham số bắt buộc nào và nhận `text` — nó
  // rút ra điểm mơ hồ TỪ CHÍNH CÂU người dùng vừa gõ, rồi `chat.clarify` mới có cái để hỏi.
  // [DEV-208] Bốn mẫu động từ.
  // [DEV-209] Netlist đi đường FACT, không đường toàn văn.
  //
  // `ingest.index_text` CỐ Ý chỉ nhận README/ghi chú — ARCHIVE-07 bước 1, và docstring nêu lý
  // do đúng: "đổ datasheet vào FTS5 sẽ khiến `memory.retrieve` trả về đoạn văn không trích dẫn
  // được, cạnh tranh chỗ với fact có trích dẫn". Nên một tệp `.net` cho `0 indexed`, và nới
  // bộ lọc ấy ra là phá một ràng buộc có lý.
  //
  // Đường đúng: `extract.kicad_netlist` đã dựng hộ chiếu bo mạch (đo 23/09/2026 trên TC038:
  // "6 nets · 6 parts", `board_passport_id = mach-co-loi@1.0.0`), và `board.check_pins` đọc
  // chính hộ chiếu ấy rồi trả `conflicts` có `severity` — đúng thứ đề bài chờ: "mức nghiêm
  // trọng, vị trí, đề xuất sửa". `board.propose_fix` lo vế đề xuất.
  'Rà soát hiện vật (DEV-208)': [
    ['n1', 'ingest.index_text', null, 'skip', { files: ['${_path}'] }],
    ['n2', 'extract.kicad_netlist', null, 'skip', { file: '${_path}' }],
    ['n3', 'board.check_pins', 'n2', 'skip', { board: '${n2.board_passport_id}' }],
    ['n4', 'board.propose_fix', 'n3', 'skip', { conflict: '${n3.conflicts[0]}' }],
    ['n5', 'code.static', null, 'skip'],
    ['n6', 'view.rag_ask', null, 'skip', { question: '${_text}' }],
    ['n7', 'chat.report_back', 'n2'],
  ],
  'Tìm tài liệu / linh kiện (DEV-208)': [
    ['n1', 'search.web', null, 'wait', { query: '${_text}' }],
    ['n2', 'search.fetch', 'n1', 'skip', { candidate: '${n1.candidates[0]}' }],
    ['n3', 'chat.report_back', 'n1'],
  ],
  // `spec` là object nên câu người dùng đi vào một khoá bên trong; `args` để rỗng — công cụ
  // vừa sinh ra đã mang sẵn con số trong chính mã của nó.
  'Tính toán kỹ thuật (DEV-208)': [
    // `name` bắt buộc — `ToolSpec.__post_init__` đòi "chỉ chữ, số và gạch dưới", và để trống
    // thì hỏng ngay ở nút đầu với E1000. Tên cố định chứ không sinh theo câu hỏi: công cụ
    // tính toán dùng lại được, và một cái tên mới mỗi lần gõ sẽ đẻ ra rác trong registry.
    ['n1', 'tool.write', null, 'wait',
      { spec: { name: 'tinh_toan_ky_thuat', purpose: '${_text}' } }],
    ['n2', 'tool.run', 'n1', 'wait', { tool_id: '${n1.tool_id}', args: {} }],
    ['n3', 'chat.report_back', 'n2'],
  ],
  'Chạy lệnh trong hộp cát (DEV-208)': [
    ['n1', 'env.sandbox', null, 'wait', { cmd: ['/bin/sh', '${_path}'] }],
    ['n2', 'chat.report_back', 'n1'],
  ],
  'Chưa hiểu, hỏi lại (DEV-201)': [
    ['n1', 'req.elicit'],
    ['n2', 'chat.clarify', 'n1', 'wait', { gaps: '${n1.gaps}' }],
    // `n3` treo vào `n1` chứ không `n2`: mô tả đã đủ rõ thì `gaps` rỗng và `chat.clarify`
    // hỏng với E1000 — nhưng lượt vẫn phải BÁO CÁO. Treo vào nút hỏng là để một lượt không
    // có gì để hỏi kết thúc bằng sự im lặng. [DEV-206]
    ['n3', 'chat.report_back', 'n1'],
  ],
  // Việc lớn chưa rõ: RÚT YÊU CẦU, không giải nén kho tài liệu. `view.artifacts` đứng đầu
  // vì nó đọc được store — cùng lý lẽ với mẫu thiết kế của [DEV-158].
  // [DEV-202] Người dùng nêu tên một tệp thì ĐỌC nó, không đem nó đi giải nén. Hai nút nhập
  // mang `skip` và không ai phụ thuộc — câu không kèm tệp thì chúng hỏng lặng lẽ.
  'Việc lớn chưa rõ (DEV-201)': [
    ['n1', 'view.artifacts', null, 'skip', { kind: 'requirement' }],
    ['n2', 'ingest.classify', null, 'skip', { files: ['${_path}'] }],
    ['n3', 'ingest.index_text', null, 'skip', { files: ['${_path}'] }],
    ['n4', 'req.elicit', null],
    ['n5', 'req.classify', 'n4', 'wait', { raw: '${n4.raw}' }],
    ['n6', 'chat.report_back', 'n5'],
  ],
  'Làm rõ yêu cầu (DEV-147)': [
    ['n1', 'req.elicit'],
    ['n2', 'req.classify', 'n1', 'wait', { raw: '${n1.raw}' }],
    ['n3', 'req.detect_conflict', 'n2', 'parallel', { reqset_ids: '${n2.reqset[*].id}' }],
    ['n4', 'req.prioritize', 'n2', 'parallel', { reqset_ids: '${n2.reqset[*].id}' }],
    ['n5', 'req.acceptance', 'n2', 'parallel', { reqset_ids: '${n2.reqset[*].id}' }],
    ['n6', 'chat.report_back', 'n5'],
  ],
  // [DEV-210] Ba nút `archive.*` mang `skip`, và một đường NHẬP TỆP THƯỜNG chạy song song.
  //
  // Z-07 là quy trình "dự án mới từ ZIP", nên nút đầu là `archive.list`. Nhưng `knowledge.build`
  // cũng là ý định của câu *"đọc netlist /…/mach-hong.net và liệt kê linh kiện"* — một TỆP
  // THƯỜNG. Đo 23/09/2026 trên TC026: `✖ archive.list E1000: Không nhận ra định dạng nén của
  // mach-hong.net`. Câu lỗi ấy có báo lỗi, nhưng báo SAI LÝ DO — tệp ấy hỏng/cụt, không phải
  // sai định dạng nén — và nó chặn luôn `ingest.*` phía sau vì chúng treo vào `archive.unpack`.
  //
  // `n2b` đứng độc lập, không ai phụ thuộc nó và nó không phụ thuộc ai: kho nén thì đường
  // `archive.*` lo, tệp thường thì đường này lo, và không đường nào giết đường kia.
  //
  // ĐÚNG MỘT nút thêm vào, không hai. Z-07 đã 23 nút và `chain.TRAN_NUT` là 24 ([DEV-179]);
  // thêm cả `ingest.classify` nữa là 25 và `test_moi_mau_chuoi_deu_vua_NGUONG_MAC_DINH` đỏ.
  // Nới trần để nhét vừa thứ mình vừa viết là đổi thước cho vừa vật — `n4` đã classify rồi,
  // còn thứ làm cho một tệp thường TRẢ LỜI ĐƯỢC là `index_text`.
  'Dự án mới từ zip (Z-07)': [
    ['n1', 'project.create'],
    ['n2', 'archive.list', 'n1', 'skip'],
    ['n2b', 'ingest.index_text', null, 'skip', { files: ['${_path}'] }],
    ['n3', 'archive.unpack', 'n2', 'skip'], ['n4', 'ingest.classify', 'n3', 'skip'],
    ['n5', 'ingest.hash_dedupe', 'n4'], ['n6', 'extract.svd', 'n5', 'skip'],
    ['n7', 'extract.atdf', 'n5', 'skip'], ['n8', 'extract.pdf_layout', 'n5', 'skip'],
    ['n9', 'extract.pdf_register_map', 'n8', 'skip'], ['n10', 'passport.import', 'n6'],
    ['n11', 'board.build_passport', 'n10', 'skip'], ['n12', 'board.check_pins', 'n11', 'skip'],
    ['n13', 'search.missing', 'n10'], ['n14', 'search.vendor', 'n13'],
    ['n15', 'search.rank', 'n14'], ['n16', 'search.fetch', 'n15'],
    ['n17', 'kg.review_facts', 'n16'], ['n18', 'view.rag_index', 'n17'],
    ['n19', 'env.check', 'n1'], ['n20', 'req.elicit', 'n18'],
    ['n21', 'plan.create', 'n20'], ['n22', 'doc.bringup_guide', 'n21', 'skip'],
    ['n23', 'chat.report_back', 'n21'],
  ],
  'Thêm tính năng (Z-05)': [
    ['n1', 'chat.ground'], ['n2', 'req.elicit', 'n1'],
    ['n3', 'req.classify', 'n2', 'wait', { raw: '${n2.raw}' }],
    ['n4', 'req.ground_hw', 'n3', 'wait', { reqset_ids: '${n3.reqset[*].id}' }],
    ['n5', 'arch.map_hw', 'n4'],        // module_ids: không nút nào sinh — xem ghi chú trên
    ['n6', 'plan.create', 'n5'],
    ['n7', 'code.generate_module', 'n6', 'skip', { step_ref: '${n6.plan.steps[0].id}' }],
    ['n8', 'code.integrate', 'n7', 'skip'],   // modules: hai ứng viên, hợp đồng không phân xử
    ['n9', 'code.generate_tests', 'n7', 'skip'],
    ['n10', 'code.review', 'n8', 'skip', { patch: '${n8.patch}' }],
    ['n11', 'code.merge', 'n10', 'skip', { patch: '${n8.patch}' }],
    ['n12', 'sim.run', 'n11', 'skip'], ['n13', 'target.flash', 'n12', 'skip'],
    ['n14', 'target.observe', 'n13', 'skip'], ['n15', 'doc.section', 'n11', 'skip'],
    ['n16', 'chat.report_back', 'n6'],
  ],
  // [DEV-159] Ba lược đồ chuyển `parallel` → `skip`.
  //
  // `parallel` nghĩa là "nút này chờ người, các nhánh KHÔNG phụ thuộc vẫn chạy tiếp" — nhưng
  // nó vẫn để lại một câu hỏi treo và cả lượt chạy kết thúc ở `asked`. Đo 22/09/2026 trên bài
  // CNC: `diagram.block` đòi `board`, và một dự án phần mềm chưa có bo mạch nào thì câu hỏi ấy
  // KHÔNG BAO GIỜ trả lời được — nên bộ tài liệu dừng vì một lược đồ không áp dụng được.
  //
  // `skip` đúng hơn: lược đồ bo mạch là thứ CÓ THÌ TỐT, không phải điều kiện để viết tài liệu.
  // Một thứ tuỳ chọn mà chặn được cả chuỗi thì nó không còn là tuỳ chọn.
  'Bộ tài liệu (P7)': [
    ['n1', 'req.trace_matrix'], ['n2', 'diagram.block', 'n1', 'skip'],
    ['n3', 'diagram.architecture', 'n1', 'skip'], ['n4', 'diagram.state', 'n1', 'skip'],
    ['n5', 'doc.generate', 'n1'], ['n6', 'doc.embed_diagram', 'n5', 'skip'],
    ['n7', 'doc.style_check', 'n5', 'skip'], ['n8', 'chat.report_back', 'n5'],
  ],
  'Dò board và nạp (Z-10)': [
    ['n1', 'discover.ports'], ['n2', 'discover.probe', 'n1'],
    ['n3', 'discover.chip_id', 'n2'], ['n4', 'discover.board_match', 'n3'],
    ['n5', 'discover.link_speed', 'n3'], ['n6', 'discover.auto_setup', 'n5'],
    ['n7', 'target.flash', 'n6'], ['n8', 'target.serial', 'n7'],
    ['n9', 'target.observe', 'n8'], ['n10', 'chat.report_back', 'n9'],
  ],
};

c.push(T([2600, 6700], ['Lệnh lớn', 'Chuỗi mẫu (rút gọn)'], CHUOI_MAU.map(r => [r[0], r[1]])));
c.push(SP());
c.push(P('Cột "Chuỗi mẫu" ở trên viết cho người đọc. Dạng **máy dùng được** đi kèm trong '
  + '`dialog/chains.json` ở trường `nodes`: mỗi nút `{id, cap, when, on_ask}` với `cap` là id '
  + 'THẬT trong danh mục 238, `when` là nút phải xong trước, và `on_ask` theo enum '
  + '`wait|parallel|skip`. Nhánh điều kiện của bản văn xuôi ("[template? …]") biểu diễn bằng '
  + '`on_ask: skip` — nút bỏ qua được khi điều kiện không thỏa, thay vì chặn cả chuỗi. '
  + '`scripts/kiem_chuoi_chuan.py` đối chiếu `nodes` với registry, nên một tên gõ sai bị bắt '
  + 'ngay thay vì im lặng biến mất khỏi khung mà `chat.orchestrate` dựng. Xem DEVIATIONS '
  + 'DEV-059.'));
c.push(SP());
// v1.3 — DEV-121 điểm (1). Gộp hai tình huống vào một mã là lý do một câu hỏi đáng lẽ hỏi
// người lại giết cả chuỗi.
c.push(P('**Chuỗi SAI khác chuỗi CHƯA ĐỦ DỮ KIỆN (v1.3).** Phép kiểm deterministic ở cuối §4.4 trả về HAI loại kết quả, và chúng dẫn tới hai việc khác hẳn nhau. **Chuỗi sai** — `cap` không có trong registry, có chu trình, vượt trần nút hoặc vượt ngân sách — là lỗi của kế hoạch: `E5002`, không chạy nút nào. **Chuỗi chưa đủ dữ kiện** — một nút thiếu tham số bắt buộc mà không nút trước nào sinh ra — KHÔNG phải lỗi: chuỗi chạy tới đó rồi dừng và hỏi người. Trả `E5002` cho cả hai là biến một câu hỏi trả lời được thành một bức tường lỗi, và đó đúng là thứ đo được ngày 17/09: một lệnh bình thường trả về bảy nút thiếu tham số và không nút nào chạy. Xem DEVIATIONS DEV-121.'));
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
