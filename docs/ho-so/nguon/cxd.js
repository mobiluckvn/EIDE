const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const m = metaNew('EIDE-CXD-10', 'Kiến trúc ngữ cảnh', 'KIẾN TRÚC NGỮ CẢNH CHO TÁC TỬ (CXD)',
  'Cách EIDE dựng ngữ cảnh cho từng lượt gọi mô hình ngôn ngữ: lớp ngữ cảnh theo vai trò, thuật toán chọn và nén, ngân sách token, định dạng khối, bộ đệm prompt, xử lý tràn, đo lường',
  [['Tài liệu trước', 'EIDE-KAD-07 §6.6 (lớp composer), EIDE-DPS-09, EIDE-SDD-04 §4.3–4.4'], ['Tài liệu liên quan', 'EIDE-MEM-11 (bộ nhớ), EIDE-PRS-16 (prompt), EIDE-CDS-12 tập 6 (memory.compose/compress)'], ['Dùng khi', 'Hiện thực eide/agents/composer.py và memory.compose; viết prompt vai trò; đo chi phí token; viết Chương lý thuyết về context engineering']],
  'Phát hành lần đầu — tách từ KAD-07 §6.6 thành tài liệu mức 3',
  [['1.1', '07/09/2026', 'Vũ Trí Công',
    '§4.5: bảng trọng số vị từ PRED_W chuyển vào khối máy đọc được cạnh EDGE_W và sinh ra '
    + '`context/budgets.json` — trước đó hai nửa của cùng một công thức xếp hạng ở hai dạng khác '
    + 'nhau, một nửa có cổng chống trôi, một nửa chép tay (DEV-043). Nói rõ hai đường vào RAG: '
    + 'theo IRI (deterministic, M1) và theo câu hỏi ngôn ngữ tự nhiên (embedding, M2) — cột '
    + '`embedding` để trống ở M1 nên không phải di trú khi tới M2 (DEV-042).'],
   ['1.2', '07/09/2026', 'Vũ Trí Công',
    '§4.5: định nghĩa thang điểm truy hồi là ĐỒNG BIẾN trong [0,1] và liệt kê bốn thành phần (bm25, coverage, vector, graph) kèm khoảng giá trị. Trước đó §4.5 chỉ nói "truy hồi lai" mà không định nghĩa thang, nên hai hiện thực ngược nhau đều "đúng tài liệu" — và một bản đảo thang vẫn cho thứ hạng đúng nhờ `ORDER BY`, im lặng cho tới khi có ai dùng điểm làm ngưỡng. Thêm `coverage` vì bm25 suy biến trên kho nhỏ: IDF = 0 khi từ có mặt trong mọi tài liệu (DEV-058).']]);
const c = [];
c.push(H1('1. Mục đích, phạm vi và nguyên tắc'));
c.push(P('Mô hình ngôn ngữ chỉ "biết" những gì nằm trong cửa sổ ngữ cảnh của lượt gọi. Với EIDE, ngữ cảnh là nơi tri thức có nguồn (hộ chiếu, mạch, ràng buộc, bằng chứng) gặp tham số của mô hình (K9); chất lượng của mọi đầu ra sinh — kế hoạch, mã, chẩn đoán, yêu cầu, kiến trúc, tài liệu — phụ thuộc trực tiếp vào việc chọn đúng thứ, đủ ít, đúng thứ tự. Tài liệu này đặc tả *kỹ thuật ngữ cảnh* (context engineering [40]) của EIDE ở mức lập trình được: cấu trúc gói ngữ cảnh (ContextBundle), thuật toán dựng cho từng vai trò, ngân sách, nén, định dạng, bộ đệm, xử lý tràn và đo lường. Phạm vi: mọi lượt gọi qua LLM Gateway (core.gateway) từ 9 vai trò của PRS-16 [63]; không bao gồm ngữ cảnh của mô hình embedding (view.rag_index) và ngữ cảnh hiển thị cho người (UXD-13).'));
c.push(T([700, 3000, 5600], ['#', 'Nguyên tắc', 'Hệ quả thiết kế'], [
  ['X1', 'Tri thức vào prompt phải có nguồn', 'Chỉ fact hiện hành (status ∈ {reviewed, verified} hoặc tier gold) kèm fact id; mô hình được yêu cầu trích dẫn id; hằng số không có trong ngữ cảnh bị constant-guard chặn (KAD K9)'],
  ['X2', 'Chọn bằng cấu trúc, không bằng "nhớ"', 'Lựa chọn fact/mã/skill là thuật toán deterministic trên đồ thị và store (Graph-RAG 2 bước), không nhờ mô hình tự nhớ; mô hình chỉ sinh trên những gì được đưa vào'],
  ['X3', 'Ít mà đúng (ngân sách cứng)', 'Mỗi vai trò có ngân sách token cho từng lớp; composer từ chối gọi nếu không nén được về ngân sách; ưu tiên cắt theo thứ tự đã định, không cắt ngẫu nhiên'],
  ['X4', 'Ổn định trước, biến đổi sau', 'Khối tĩnh (vai trò, quy tắc, skill, ràng buộc dự án) đứng trước khối động (fact tác vụ, mã, phản hồi công cụ, lịch sử) để tận dụng bộ đệm prompt của hãng [41]–[43]'],
  ['X5', 'Mỗi khối có nhãn, có nguồn, có thể kiểm', 'Khối ngữ cảnh bọc thẻ XML có thuộc tính nguồn và số token; ledger ghi băm của bundle để tái tạo và kiểm toán; cho phép ablation'],
  ['X6', 'Tách hiểu lệnh khỏi sinh', 'Orchestrator dùng bundle nhỏ (C0, C1′, C2′, C7); các vai trò sinh dùng bundle đầy đủ (DPS-09, KAD §6.6b)'],
]));
c.push(SP());
c.push(H1('2. Mô hình ngữ cảnh: ContextBundle và các lớp'));
c.push(P('Một lượt gọi nhận một **ContextBundle** gồm danh sách khối có thứ tự. Tám loại khối kế thừa bảy lớp C1–C7 của KAD-07 §6.6 và thêm C0 (mô tả năng lực, dùng cho Orchestrator và Planner). Mỗi khối có: loại, nguồn (danh sách id/đường dẫn), số token, độ ưu tiên cắt, băm nội dung.'));
c.push(T([800, 2000, 3300, 1500, 1700], ['Lớp', 'Tên', 'Nội dung', 'Nguồn (KAD)', 'Tính chất'], [
  ['C0', 'Năng lực khả dụng', 'Mô tả ngắn của top-k năng lực liên quan (id, một câu, ví dụ gọi ≤ 60 token/năng lực)', 'Capability Registry', 'Tĩnh theo phiên; chọn theo từ khóa'],
  ['C1', 'Vai trò và quy tắc', 'Prompt hệ thống của vai trò (PRS-16), quy tắc trích dẫn, định dạng đầu ra, prompt phủ định từ sổ lỗi', 'K8', 'Tĩnh; đứng đầu; cache'],
  ['C2', 'Ràng buộc dự án', 'constraints.yaml nén: chip/board, ISA, toolchain, mức tự chủ, quy ước repo, chân cấm, ngân sách RAM/Flash', 'K6', 'Tĩnh theo dự án; cache'],
  ['C3', 'Skill', '≤ 3 skill theo APPLIES_TO (ISA/chip/ngoại vi của tác vụ)', 'K5', 'Bán tĩnh; cache theo tác vụ'],
  ['C4', 'Fact phần cứng', 'Fact hiện hành có id, giá trị, đơn vị, nguồn; dạng bảng gọn; chọn bằng Graph-RAG 2 bước', 'K2, K2′, K3, K4', 'Động theo tác vụ'],
  ['C5', 'Tác vụ và mã liên quan', 'STEP/Feature, ReqSet liên quan, ModuleGraph cục bộ, tệp mã trong USES/CITES (đoạn, không toàn tệp)', 'K6, K10', 'Động'],
  ['C6', 'Phản hồi công cụ và bằng chứng', 'ToolReport mới nhất (lỗi đã lọc), log khớp mẫu, EvidencePack, số đo', 'K7', 'Động; thay mỗi vòng'],
  ['C7', 'Lịch sử lượt', 'Tối đa 2 lượt gần nhất đã tóm tắt; câu hỏi/trả lời của người trong chuỗi hiện tại', 'Bộ nhớ làm việc (MEM-11)', 'Động; cuối cùng'],
]));
c.push(SP());
c.push(H2('2.1. Schema ContextBundle'));
c.push(...CODE([
  '{ "$id": "https://eide.code247.ai/schema/context_bundle.json", "type": "object",',
  '  "required": ["role", "task_ref", "blocks", "budget", "total_tokens", "hash"],',
  '  "properties": {',
  '    "role": {"type": "string", "enum": ["intent", "librarian", "cartographer", "planner", "coder", "reviewer", "debugger", "architect", "writer"]},',
  '    "task_ref": {"type": "string"}, "model_id": {"type": "string"},',
  '    "blocks": {"type": "array", "items": {"type": "object", "required": ["layer", "text", "tokens", "sources", "cut_priority"],',
  '      "properties": {"layer": {"type": "string", "enum": ["C0","C1","C2","C3","C4","C5","C6","C7"]}, "text": {"type": "string"}, "tokens": {"type": "integer"},',
  '                     "sources": {"type": "array", "items": {"type": "string"}}, "cut_priority": {"type": "integer", "minimum": 1, "maximum": 9},',
  '                     "cacheable": {"type": "boolean"}, "hash": {"type": "string"}}}},',
  '    "budget": {"type": "object", "properties": {"C0":{"type":"integer"},"C1":{"type":"integer"},"C2":{"type":"integer"},"C3":{"type":"integer"},"C4":{"type":"integer"},"C5":{"type":"integer"},"C6":{"type":"integer"},"C7":{"type":"integer"},"total":{"type":"integer"}}},',
  '    "total_tokens": {"type": "integer"}, "hash": {"type": "string"}, "compressions": {"type": "array", "items": {"type": "string"}} } }',
]));
c.push(SP());
c.push(H1('3. Ngân sách theo vai trò'));
// Bảng ngân sách, thứ tự cắt và hằng ước lượng token là NGUỒN DUY NHẤT cho Composer
// (`eide_core/composer.py`), cho `models.yaml → roles.<role>.budget`, và cho chính tài liệu
// này. Trước đây chúng chỉ nằm trong văn xuôi §3 và §5. Xem DEVIATIONS DEV-029.
const CXD = {
  // token đầu vào cho mỗi lớp; `null` = lớp ấy không dùng ở vai trò này.
  budget: {
    intent:       { C0: 1200, C1: 300, C2: 400, C3: null, C4: null, C5: null, C6: null, C7: 300, total: 2200 },
    librarian:    { C0: 400, C1: 400, C2: 400, C3: 600, C4: 1500, C5: 600, C6: 600, C7: 300, total: 4800 },
    cartographer: { C0: null, C1: 400, C2: 400, C3: 600, C4: 1800, C5: 400, C6: 400, C7: 200, total: 4200 },
    planner:      { C0: 800, C1: 400, C2: 600, C3: 1800, C4: 2500, C5: 2000, C6: 600, C7: 300, total: 9000 },
    coder:        { C0: null, C1: 400, C2: 600, C3: 1800, C4: 2500, C5: 1500, C6: 900, C7: 300, total: 8000 },
    reviewer:     { C0: null, C1: 400, C2: 600, C3: 1200, C4: 2000, C5: 2500, C6: 900, C7: 200, total: 7800 },
    debugger:     { C0: null, C1: 400, C2: 400, C3: 1200, C4: 2000, C5: 1200, C6: 2200, C7: 300, total: 7700 },
    architect:    { C0: 400, C1: 400, C2: 800, C3: 1500, C4: 2500, C5: 3000, C6: 400, C7: 300, total: 9300 },
    writer:       { C0: null, C1: 400, C2: 600, C3: 1000, C4: 2000, C5: 3000, C6: 400, C7: 300, total: 7700 },
  },
  // §3: giới hạn token ĐẦU RA (schema JSON).
  output_max: { coder: 16000, writer: 12000, _mac_dinh: 4000 },
  // §3 thứ tự cắt khi tràn: số nhỏ cắt TRƯỚC. C1 và C2 không bao giờ cắt.
  cut_priority: { C7: 1, C6: 2, C5: 3, C4: 4, C3: 5, C0: 6, C1: 9, C2: 9 },
  // §3: "1 token ≈ 3,5 ký tự tiếng Việt có dấu, 4 ký tự tiếng Anh" khi adapter không có
  // count_tokens. Lấy 3,5 vì giao diện và tài liệu của EIDE là tiếng Việt — ước thấp hơn
  // thực tế sẽ làm ngân sách bị vượt mà không ai báo.
  chars_per_token: 3.5,
  // §4.5 trọng số cạnh cho Graph-RAG hai bước.
  edge_weight: { HAS: 1.0, CONNECTS: 0.9, USES: 0.8, APPLIES_TO: 0.6, CONFLICTS_WITH: 1.0 },
  // §4.5 trọng số VỊ TỪ. Trước v1.1 bảng này chỉ nằm trong văn xuôi cạnh `edge_weight`, nên
  // hai nửa của cùng một công thức xếp hạng ở hai dạng khác nhau: một nửa máy đọc được, một
  // nửa phải chép tay. Cùng khuôn mẫu DEV-025/DEV-029.
  pred_weight: {
    base_address: 1.0, offset: 1.0, bit_range: 1.0, reset_value: 1.0, address: 1.0, net: 1.0,
    enum: 0.9, pin_function: 0.9, irq: 0.9,
    voltage_range: 0.8, timing: 0.8,
    description: 0.3,           // chỉ khi còn ngân sách
    _mac_dinh: 0.5,             // vị từ không có trong bảng — DDD-14 cho phép `other`
  },
  // §4.2 số năng lực đưa vào C0 theo vai trò.
  k0: { intent: 30, planner: 15, architect: 15, librarian: 8 },
  max_skills: 3,        // §4.4
  history_turns: 2,     // §2 C7
};
if (!fs.existsSync('context')) fs.mkdirSync('context');
fs.writeFileSync('context/budgets.json', JSON.stringify(CXD, null, 2) + '\n');
c.push(P('**Thang điểm truy hồi là ĐỒNG BIẾN: điểm càng cao càng khớp**, trong khoảng [0, 1]. Nói ra vì `bm25()` của SQLite trả số ÂM (càng âm càng khớp), nên một hiện thực chuẩn hóa thiếu cẩn thận cho ra thang ĐẢO — và thứ hạng vẫn đúng nhờ `ORDER BY`, nên lỗi im lặng cho tới khi có ai đó dùng điểm làm NGƯỠNG. Bốn thành phần và cách gộp:'));
c.push(T([1600, 1200, 5600], ['Thành phần', 'Khoảng', 'Nghĩa'], [
  ['bm25', '[0, 1)', 'chuẩn hóa đồng biến từ `bm25()`: `1 − 1/(1 + abs(bm25))`'],
  ['coverage', '[0, 1]', 'tỷ lệ từ khóa câu hỏi thực sự xuất hiện trong đoạn'],
  ['vector', '[0, 1]', 'cosine với embedding câu hỏi (0 khi chưa có embedding)'],
  ['graph', '{0, 1}', '1 nếu đoạn được đánh dấu nói về một IRI trong tập lan tỏa 2 bước'],
]));
c.push(P('Điểm FTS = trung bình của `bm25` và `coverage`. Phải có `coverage` vì **bm25 suy biến trên kho nhỏ**: BM25 nhân với IDF, mà một từ có mặt trong MỌI tài liệu thì IDF = 0 — nên kho một tài liệu luôn cho bm25 = 0 với mọi khớp, và một ngưỡng dựa riêng vào nó sẽ chặn hết mọi câu trả lời của một dự án vừa nạp đúng một datasheet. `coverage` không suy biến và giải thích được cho người dùng (“đoạn này chứa 4/5 từ bạn hỏi”). Đoạn khớp bằng đồ thị giữ điểm riêng (≥ 0,9) và KHÔNG trộn vào thang FTS: khớp `graph_nodes` là sự thật đã ghi lúc lập chỉ mục, còn điểm FTS là ước lượng — gộp hai loại vào một thang thì bên đọc không biết mình đang nhìn cái nào. Xem DEVIATIONS DEV-058.'));
c.push(SP());
c.push(P('Ngân sách tính bằng token đầu vào (đếm bằng count_tokens của adapter; khi không có, ước lượng 1 token ≈ 3,5 ký tự tiếng Việt có dấu, 4 ký tự tiếng Anh). Giá trị dưới đây là mặc định trong `models.yaml → roles.<role>.budget`, tinh chỉnh theo đo lường §9. Tổng của vai trò sinh không vượt 8.000 (NFR-10); Planner và Architect được phép 12.000 khi mô hình có cửa sổ ≥ 200k và dự án bật `context.extended: true`.'));
c.push(T([1300, 700, 700, 700, 700, 800, 800, 800, 700, 900], ['Vai trò', 'C0', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'Tổng'], [
  ['intent (hiểu lệnh)', '1.200', '300', '400 (C1′ trạng thái)', '—', '—', '—', '—', '300', '2.200'],
  ['librarian', '400', '400', '400', '600', '1.500', '600', '600', '300', '4.800'],
  ['cartographer (ảnh)', '—', '400', '400', '600', '1.800', '400', '400', '200', '4.200 + ảnh'],
  ['planner', '800', '400', '600', '1.800', '2.500', '2.000', '600', '300', '9.000'],
  ['coder', '—', '400', '600', '1.800', '2.500', '1.500', '900', '300', '8.000'],
  ['reviewer', '—', '400', '600', '1.200', '2.000', '2.500', '900', '200', '7.800'],
  ['debugger', '—', '400', '400', '1.200', '2.000', '1.200', '2.200', '300', '7.700'],
  ['architect (req/arch/adr)', '400', '400', '800', '1.500', '2.500', '3.000', '400', '300', '9.300'],
  ['writer (doc/diagram)', '—', '400', '600', '1.000', '2.000', '3.000', '400', '300', '7.700'],
]));
c.push(SP());
c.push(P('Đầu ra: coder ≤ 16.000, writer ≤ 12.000, các vai trò khác ≤ 4.000 (schema JSON). Thứ tự cắt khi tràn (cut_priority tăng dần = cắt trước): C7 (1) → C6 phần cũ (2) → C5 mã ngoài phạm vi trực tiếp (3) → C4 fact xa 2 bước (4) → C3 skill thứ ba (5) → C0 (6) → C5 phần còn lại (7) → C4 fact 1 bước (8); C1 và C2 không bao giờ cắt (9).'));
c.push(H1('4. Thuật toán dựng ngữ cảnh'));
c.push(H2('4.1. Composer'));
c.push(...CODE([
  'def compose(role: str, task: Task, ctx: ProjectContext) -> ContextBundle:',
  '    b = Bundle(role, task.ref, budget=BUDGET[role])',
  '    if role in ("intent", "planner", "architect", "librarian"): b.add(C0, select_capabilities(task.text, k=K0[role]))      # §4.2',
  '    b.add(C1, role_prompt(role) + negative_prompts(role, ctx))                                                          # PRS-16, MEM-11 §6',
  '    b.add(C2, compact_constraints(ctx.constraints))                                                                     # §4.3',
  '    if role != "intent":',
  '        b.add(C3, select_skills(task, ctx, max_n=3))                                                                    # §4.4',
  '        b.add(C4, facts_table(select_facts(task, ctx, hops=2)))                                                        # §4.5 Graph-RAG',
  '        b.add(C5, select_code_and_task(task, ctx))                                                                     # §4.6',
  '        b.add(C6, tool_feedback(task, ctx, last_n=1))                                                                  # §4.7',
  '    else: b.add(C1p, project_state_summary(ctx))                                                                       # DPS-09',
  '    b.add(C7, history(ctx.session, turns=2, summarized=True))                                                          # MEM-11',
  '    b = fit_to_budget(b)                                                                                                # §5',
  '    if b.total_tokens > b.budget.total: raise ContextOverflow(b.report())                                              # §7: không gọi',
  '    ledger.append("context.bundle", {"hash": b.hash, "role": role, "tokens": b.per_layer(), "sources": b.sources()})',
  '    return b',
]));
c.push(SP());
c.push(H2('4.2. Chọn năng lực (C0)'));
c.push(P('Điểm của năng lực = BM25(tên + mô tả, câu lệnh) × 1,0 + trùng nhóm với ý định đã nhận diện × 2,0 + được dùng gần đây trong dự án × 0,5. Lấy top-k (intent: 30; planner/architect: 15; librarian: 8), mỗi năng lực một dòng "id — một câu — ví dụ gọi" ≤ 60 token. Không đưa năng lực lớp R4 vào C0 của intent trừ khi câu lệnh chứa từ khóa tương ứng (xóa, fuse, phát hành).'));
c.push(H2('4.3. Nén ràng buộc dự án (C2)'));
c.push(P('constraints.yaml được chuyển thành bảng khóa–giá trị một dòng mỗi mục, bỏ chú thích, gộp danh sách chân cấm thành chuỗi; giữ nguyên các mục an toàn (reserved_pins, bus_limits, autonomy, sensitive). Nếu > 600 token: giữ mục có nhãn `critical`, tóm tắt phần còn lại thành "xem constraints.yaml §x".'));
c.push(H2('4.4. Chọn skill (C3)'));
c.push(P('Ứng viên = skill có cạnh APPLIES_TO tới ISA, chip, hoặc ngoại vi xuất hiện trong tác vụ. Điểm = khớp ngoại vi (3) + khớp chip (2) + khớp ISA (1) + huy hiệu benchmark BC ≥ 0,9 với mô hình đang dùng (1) − skill đã thất bại trong sổ lỗi cho tác vụ tương tự (2). Lấy tối đa 3, tổng ≤ 1.800 token; skill dài hơn 600 token bị từ chối ở registry nên không cần cắt trong skill.'));
c.push(H2('4.5. Chọn fact bằng Graph-RAG hai bước (C4)'));
c.push(...CODE([
  'def select_facts(task, ctx, hops=2) -> list[Fact]:',
  '    seeds = subjects_in(task)                                  # IRI chip/periph/pin/net nhắc trong STEP, ReqSet, tên module, lỗi công cụ',
  '    if not seeds: seeds = ctx.module_graph.hw_of(task.module)   # HwMap của module đang làm',
  '    frontier = set(seeds); scored = {}',
  '    for hop in range(1, hops + 1):',
  '        nxt = set()',
  '        for n in frontier:',
  '            for e in kg.edges(n, types=["HAS", "CONNECTS", "USES", "APPLIES_TO", "CONFLICTS_WITH"]):',
  '                f = e.other(n); w = EDGE_W[e.type] / hop           # HAS 1.0, CONNECTS 0.9, USES 0.8, APPLIES_TO 0.6, CONFLICTS_WITH 1.0 (luôn đưa mâu thuẫn)',
  '                scored[f] = max(scored.get(f, 0), w); nxt.add(f)',
  '        frontier = nxt - set(scored) | frontier',
  '    facts = [fact for node in scored for fact in store.current_facts(node)]           # chỉ status reviewed/verified hoặc gold',
  '    facts = rank(facts, key=lambda f: scored[f.subject] * PRED_W[f.predicate] * (1.0 if f.tier == "gold" else 0.8))',
  '    return take_until_budget(facts, BUDGET[role].C4, always_include=[f for f in facts if f.status == "conflict"])',
]));
c.push(SP());
c.push(P('Trọng số vị từ PRED_W: base_address, offset, bit_range, reset_value, address, net = 1,0; enum, pin_function, irq = 0,9; voltage_range, timing = 0,8; description = 0,3 (chỉ khi còn ngân sách). Fact được trình bày dạng bảng: `| id | subject | predicate | value | unit | tier | src |` — mỗi dòng ≈ 25 token; C4 = 2.500 token ≈ 100 fact. Fact mâu thuẫn luôn có mặt kèm nhãn CONFLICT để mô hình không tự chọn (phải nói "không xác định").'));
c.push(P('**Hai đường vào RAG, và chúng khác nhau về bản chất chứ không chỉ về kỹ thuật.** Đường thứ nhất nhận một **IRI** (`chip:st.stm32f411ce/periph:I2C1`) và trả lời bằng khớp chính xác `graph_nodes` cộng tìm toàn văn — deterministic, rẻ, và là đường mà `memory.retrieve` dùng (mốc M1). Đường thứ hai nhận một **câu hỏi ngôn ngữ tự nhiên** và cần nhúng vector để so ngữ nghĩa — đó là `view.rag_ask` ở mốc M2. Cột `embedding` của `RagChunk` (DDD-14 §2) dành cho đường thứ hai và để trống ở M1: nhúng mỗi đoạn chỉ để so cosine với một chuỗi định danh là tốn tiền mà không thêm thông tin. Cùng một bảng phục vụ cả hai nên không phải di trú khi tới M2. Xem DEVIATIONS DEV-042.'));
c.push(SP());
c.push(H2('4.6. Chọn tác vụ và mã (C5)'));
c.push(P('Thứ tự: (1) STEP.md/Feature hiện tại (nguyên văn, ≤ 600); (2) Requirement liên quan (id + text, ≤ 300); (3) chữ ký hàm và cấu trúc của module đích (từ code_unit, ≤ 400); (4) đoạn mã trong CITES/USES giao với subject của tác vụ — chỉ đoạn (hàm) chứa tham chiếu, không toàn tệp (≤ 1.000); (5) tệp giao diện chung (HAL header) chỉ khi module gọi tới. Đoạn mã kèm đường dẫn:dòng để reviewer đối chiếu.'));
c.push(H2('4.7. Phản hồi công cụ (C6)'));
c.push(P('ToolReport mới nhất theo cổng thất bại: cắt log về (a) 20 dòng đầu chứa "error|undefined|overflow|region", (b) 5 dòng trước và sau mỗi dòng lỗi, (c) số liệu size (text/data/bss, % Flash/RAM). Với debugger: EvidencePack (thanh ghi lỗi, unwind ≤ 12 khung, RTT ≤ 40 dòng) và log.stats của GEditor (mẫu lặp top-10, khoảng thời gian). Log vượt ngân sách được thay bằng tóm tắt thống kê + con trỏ (log_ref, range) để mô hình yêu cầu thêm qua tool nếu cần.'));
c.push(H1('5. Nén và cắt'));
c.push(T([2200, 4200, 2900], ['Kỹ thuật', 'Áp dụng', 'Ghi nhật ký'], [
  ['Tóm tắt lũy tiến lịch sử', 'C7: lượt cũ hơn 2 được tóm tắt thành ≤ 80 token/lượt bởi mô hình rẻ (vai trò intent, temperature 0), giữ quyết định và số liệu', 'compressions += "history:summarize"'],
  ['Bảng hóa fact', 'C4: bỏ description, gộp enum cùng field thành một dòng "A=0,B=1,…"', '"facts:tabulate"'],
  ['Cửa sổ log theo mẫu', 'C6: regex lỗi + ngữ cảnh ±5 dòng; dedupe dòng lặp (đếm ×n)', '"log:window"'],
  ['Cắt mã theo hàm', 'C5: chỉ hàm chứa tham chiếu; thân hàm > 60 dòng → giữ chữ ký + 10 dòng đầu + "…"', '"code:function_only"'],
  ['Rút skill', 'C3: bỏ skill điểm thấp nhất', '"skills:drop:<id>"'],
  ['Thay bằng con trỏ', 'Mọi lớp: thay khối bằng "xem <ref>, gọi tool X để lấy" khi vẫn tràn', '"pointer:<layer>"'],
]));
c.push(SP());
c.push(P('fit_to_budget lặp: nén từng lớp theo bảng trên, rồi cắt theo cut_priority §3, cho tới khi tổng ≤ ngân sách hoặc không còn gì cắt được ngoài C1/C2 → ContextOverflow.'));
c.push(H1('6. Định dạng khối và ví dụ'));
c.push(P('Khối bọc thẻ XML có thuộc tính `layer`, `src` (id cách nhau bởi dấu phẩy), `tokens`. Fact, ràng buộc và số đo ở dạng bảng markdown; mã trong khối ``` có tên tệp; skill ở markdown nguyên bản. Ngôn ngữ chỉ dẫn: tiếng Việt; định danh kỹ thuật giữ nguyên. Ví dụ bundle cho coder (rút gọn):'));
c.push(...CODE([
  '<C1 layer="role" src="prompts/coder.md,errors:neg-12">…prompt hệ thống coder; quy tắc: mọi hằng số phần cứng kèm /* eide:fact f_… */…</C1>',
  '<C2 layer="constraints" src="constraints.yaml">chip=st.stm32f411ce; board=blackpill-f411; isa=armv7e-m; toolchain=arm-none-eabi-gcc 13.2; reserved_pins=PA13,PA14,PB2; i2c1=PB6/PB7 400kHz; autonomy=A3; flash_budget=85%</C2>',
  '<C3 layer="skills" src="skills/armv7e-m/i2c.md,skills/bosch/bme280.md">…</C3>',
  '<C4 layer="facts" src="f_1a2b…,f_3c4d…,+96">',
  '| id | subject | predicate | value | unit | tier | src |',
  '| f_1a2b | chip:st.stm32f411ce/periph:I2C1 | base_address | 0x40005400 | — | gold | svd:stm32f411.svd |',
  '| f_9e0f | part:bosch.bme280 | address | 0x76,0x77 | — | silver | pdf:bme280-ds.pdf#p32 |  …</C4>',
  '<C5 layer="task" src="STEP.md,src/drivers/bme280.h,src/hal/i2c.c#L40-88">…</C5>',
  '<C6 layer="tools" src="tr_0451">build: FAILED — src/drivers/bme280.c:57: error: BME280_REG_CTRL undeclared … (3 lỗi, 0 cảnh báo)</C6>',
  '<C7 layer="history">Lượt trước: đã tạo khung bme280.c; người chọn "đọc theo chế độ forced".</C7>',
]));
c.push(SP());
c.push(H1('7. Bộ đệm prompt (prompt caching) và xử lý tràn'));
c.push(P('Thứ tự C1 → C2 → C3 là tiền tố ổn định trong một tác vụ; composer đánh dấu `cacheable = true` cho ba lớp này và adapter ánh xạ sang cơ chế của hãng: Anthropic đặt `cache_control` ở khối cuối của tiền tố [41]; Gemini dùng cached content với TTL theo phiên [42]; OpenAI-compatible dựa vào bộ đệm tự động theo tiền tố [43]. Gateway ghi `cache_read_tokens` vào ledger để đo tỷ lệ trúng; mục tiêu ≥ 60% trong một tác vụ nhiều vòng. Khi ContextOverflow: (1) Orchestrator thử chia tác vụ (Feature → sub-feature theo ModuleGraph); (2) nếu vẫn tràn, nâng mô hình có cửa sổ lớn hơn theo Router nếu chi phí trong ngân sách; (3) nếu không, leo thang lên người với báo cáo lớp nào chiếm bao nhiêu và gợi ý thu hẹp phạm vi.'));
c.push(H1('8. Ngữ cảnh cho tầng hiểu lệnh (intent)'));
c.push(P('Bundle của intent gồm: C0 (30 năng lực liên quan), C1 (prompt intent, ≤ 300), C1′ trạng thái dự án tóm tắt (dự án mở, board, hộ chiếu, feature failing đầu, số mục chờ, target đang cắm — ≤ 400), C2′ preferences và defaults (≤ 200), C7 (2 lượt). Không có fact phần cứng: grounding tra store trực tiếp (DPS-09 §4.2). Tổng ≤ 2.200 token để mô hình rẻ trả lời < 1 giây.'));
c.push(H1('9. Đo lường và tinh chỉnh'));
c.push(T([2600, 3800, 2700], ['Chỉ số', 'Cách đo (ledger)', 'Mục tiêu / hành động'], [
  ['Token vào theo lớp và vai trò', 'Trung bình, P95 từ context.bundle', 'Vai trò sinh ≤ 8.000 P95; lớp vượt ngân sách 3 lần liên tiếp → cảnh báo cấu hình'],
  ['Tỷ lệ trích dẫn đúng', 'Fact id trong đầu ra ∈ C4 và đúng giá trị (constant-guard)', '≥ 98%; thấp hơn → tăng C4 cho vai trò đó hoặc sửa PRED_W'],
  ['Tỷ lệ "không có trong ngữ cảnh"', 'Constant-guard chặn vì fact cần thiết không nằm trong C4', '≤ 5%; cao → tăng hops hoặc EDGE_W'],
  ['Trúng bộ đệm', 'cache_read_tokens / input_tokens', '≥ 60% trong tác vụ nhiều vòng'],
  ['Ablation', 'Chạy benchmark BEN-21 với bỏ từng lớp (C3, C4, C6) trên 2 mô hình', 'Báo cáo hằng mốc; lớp không ảnh hưởng BC → giảm ngân sách'],
  ['Chi phí/lượt', 'USD từ ledger theo vai trò', 'Coder ≤ 0,05 USD/lượt trung bình'],
]));
c.push(SP());
c.push(H1('10. Giao diện Python'));
c.push(...CODE([
  'class Block(BaseModel): layer: Layer; text: str; tokens: int; sources: list[str]; cut_priority: int; cacheable: bool = False; hash: str',
  'class ContextBundle(BaseModel): role: str; task_ref: str; model_id: str|None; blocks: list[Block]; budget: Budget; total_tokens: int; hash: str; compressions: list[str]',
  'class Composer:',
  '    def compose(self, role: str, task: Task, ctx: ProjectContext) -> ContextBundle',
  '    def select_capabilities(self, text: str, k: int) -> str',
  '    def select_skills(self, task, ctx, max_n=3) -> list[Skill]',
  '    def select_facts(self, task, ctx, hops=2) -> list[Fact]',
  '    def select_code_and_task(self, task, ctx) -> str',
  '    def tool_feedback(self, task, ctx, last_n=1) -> str',
  '    def fit_to_budget(self, b: ContextBundle) -> ContextBundle',
  '    def render(self, b: ContextBundle) -> list[Msg]                    # → ModelRequest.messages với cache marks',
  'class Compressor: summarize_history(turns) ; tabulate_facts(facts) ; window_log(text, patterns, ctx_lines=5) ; function_only(code, refs)',
  '# Năng lực tương ứng: memory.compose (MEMORY-01), memory.compress (MEMORY-02) — hợp đồng chi tiết trong CDS-12 tập 6',
]));
c.push(SP());
c.push(H1('11. Kiểm thử'));
c.push(T([900, 3400, 3700, 1300], ['TC', 'Mục tiêu', 'Bước / kỳ vọng', 'Mức'], [
  ['TC-CX-01', 'Ngân sách cứng', 'Tác vụ với 400 fact liên quan → C4 ≤ 2.500 token; tổng ≤ 8.000; fact mâu thuẫn luôn có mặt', 'L1'],
  ['TC-CX-02', 'Graph-RAG 2 bước', 'KG mẫu BME280↔I2C1↔PB6/PB7: fact 1 bước xếp trước fact 2 bước; fact ngoài 2 bước không xuất hiện', 'L1'],
  ['TC-CX-03', 'Thứ tự cắt', 'Ép ngân sách 4.000 → C7, C6 cũ, C5 ngoài phạm vi bị cắt trước; C1/C2 nguyên vẹn; compressions ghi đúng', 'L1'],
  ['TC-CX-04', 'ContextOverflow', 'Ngân sách 1.000 → ném ContextOverflow với báo cáo lớp; không có lượt gọi mô hình trong ledger', 'L1'],
  ['TC-CX-05', 'Tính tái tạo', 'Cùng task/ctx → cùng hash bundle; đổi 1 fact → hash đổi', 'L1'],
  ['TC-CX-06', 'Bộ đệm', 'Ba lượt liên tiếp cùng tác vụ trên Claude/Gemini → cache_read_tokens > 0 từ lượt 2', 'L2'],
  ['TC-CX-07', 'Trích dẫn đúng', '20 tác vụ coder benchmark: ≥ 98% hằng số có fact id nằm trong C4', 'L3'],
  ['TC-CX-08', 'Bundle intent', '≤ 2.200 token; không chứa fact; C0 có đúng năng lực theo từ khóa', 'L1'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-CXD-10_Kien_truc_ngu_canh.docx');
