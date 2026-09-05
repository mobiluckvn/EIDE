const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const m = metaNew('EIDE-MEM-11', 'Kiến trúc bộ nhớ tác tử', 'KIẾN TRÚC BỘ NHỚ CỦA TÁC TỬ (MEM)',
  'Sáu loại bộ nhớ vận hành của tác tử EIDE: nội dung, nơi lưu, chính sách ghi – đọc – quên – hợp nhất, bộ nhớ qua phiên, học từ vận hành, quyền riêng tư, và hợp đồng mức 3 cho nhóm năng lực memory.*',
  [['Tài liệu trước', 'EIDE-KAD-07 (tri thức và 5 lớp lưu trữ), EIDE-CXD-10 (ngữ cảnh), EIDE-APD-08 §6, EIDE-DPS-09 D8'], ['Tài liệu liên quan', 'EIDE-DDD-14 (schema, bảng), EIDE-CDS-12 tập 6 (memory.*)'], ['Dùng khi', 'Hiện thực eide/memory/*, memory.* năng lực, resume, learn; thiết kế bảng; viết Chương lý thuyết về bộ nhớ tác tử']],
  'Phát hành lần đầu — bổ sung lĩnh vực L10 của Rà soát');
const c = [];
c.push(H1('1. Mục đích và vị trí trong kiến trúc'));
c.push(P('KAD-07 trả lời câu hỏi "tri thức phần cứng và dự án là gì, ở đâu"; CXD-10 trả lời "đưa gì vào một lượt gọi". Tài liệu này trả lời câu hỏi còn lại: **tác tử nhớ gì giữa các bước, các lượt, các phiên và các dự án — và quên gì**. Khung phân loại dựa trên kiến trúc nhận thức cho tác tử ngôn ngữ CoALA [44] (bộ nhớ làm việc, tình tiết, ngữ nghĩa, thủ tục), cơ chế phân cấp bộ nhớ của MemGPT [45] (ngữ cảnh chính ↔ kho ngoài, có quản lý), và quy tắc truy hồi theo mới–liên quan–quan trọng của Generative Agents [46]; được điều chỉnh cho ràng buộc của EIDE: mọi tri thức phần cứng vẫn phải đi qua cổng và có nguồn (KAD), bộ nhớ không được trở thành "nguồn sự thật thứ hai".'));
c.push(T([2400, 3300, 3600], ['Tầng', 'Câu hỏi', 'Tài liệu'], [
  ['Tri thức (knowledge)', 'Fact, hộ chiếu, skill, ràng buộc, bằng chứng — cố định/làm giàu thế nào', 'KAD-07'],
  ['Bộ nhớ (memory) — tài liệu này', 'Tác tử giữ trạng thái gì qua bước/lượt/phiên/dự án; ghi, đọc, quên, học', 'MEM-11'],
  ['Ngữ cảnh (context)', 'Chọn gì từ tri thức + bộ nhớ vào một lượt gọi', 'CXD-10'],
]));
c.push(SP());
c.push(H1('2. Sáu loại bộ nhớ'));
c.push(T([1500, 2200, 1500, 1300, 1200, 1600], ['Loại', 'Nội dung', 'Sống bao lâu', 'Lưu ở', 'Ai ghi', 'Quên'], [
  ['M1 Bộ nhớ làm việc (working)', 'Trạng thái của một chuỗi đang chạy: Intent hiện tại, Grounded, mặc định đã áp, nút đang chạy, kết quả trung gian, câu hỏi đang chờ, biến tạm giữa các năng lực', 'Một Run (chuỗi); tối đa vài giờ', 'RAM + run.state (SQLite) để tiếp tục sau tắt máy', 'Orchestrator, Router', 'Xóa khi Run kết thúc; giữ tóm tắt vào M3'],
  ['M2 Bộ nhớ phiên (session)', 'Lịch sử lượt chat, lượt đã tóm tắt, quyền theo phiên (R4), target đang cắm, mức tự chủ hiệu lực, việc "đã làm — hoàn tác được"', 'Một phiên làm việc (mở → đóng dự án/daemon)', 'session.sqlite (không commit)', 'ChatPanel, PolicyGate, Discovery', 'Hết phiên: lịch sử tóm tắt sang M3; quyền hết hạn; undo hết cửa sổ'],
  ['M3 Bộ nhớ tình tiết (episodic)', 'Chuyện đã xảy ra, có bằng chứng: Intent/Run/Report, DecisionLog, CapabilityRun, ToolReport, DebugSession, Measurement, sổ lỗi, thay đổi tri thức (supersede)', 'Lâu dài, append-only', 'store.sqlite + ledger/*.jsonl (commit trừ log lớn)', 'Mọi thành phần qua Ledger', 'Không xóa; tổng hợp theo tháng; log lớn dọn theo TTL, giữ hash'],
  ['M4 Bộ nhớ ngữ nghĩa (semantic)', 'Fact, hộ chiếu, BoardPassport, ràng buộc, ReqSet, ModuleGraph, ADR — tức K1–K6, K10 của KAD', 'Lâu dài, phiên bản hóa', 'store.sqlite, passport.yaml, .eide/docs', 'Chỉ qua PassportStore.write và cổng', 'Supersede, không xóa; tách lớp L-A/L-B'],
  ['M5 Bộ nhớ thủ tục (procedural)', 'Cách làm: prompt vai trò (K8), skill (K5), chuỗi mẫu orchestration, mẫu STEP/tài liệu, quy tắc chính sách và ngưỡng', 'Lâu dài, có phiên bản', 'eide-packs/, prompts/, skills/, autonomy.yaml', 'Người/Pack owner; đề xuất từ M3 phải qua duyệt', 'Thay bằng phiên bản mới; không tự xóa'],
  ['M6 Tùy chọn người dùng (preference)', 'Lựa chọn đã trả lời (D8): create_when_exists, probe, mô hình ưa thích, ngôn ngữ, sim trước nạp; theo phạm vi người/dự án', 'Cho tới khi người đổi', 'preferences.yaml (dự án) + ~/.eide/preferences.yaml (người)', 'Orchestrator sau câu trả lời của người', 'Người nói "hỏi lại tôi mỗi lần"; TTL tùy chọn'],
]));
c.push(SP());
c.push(P('Ba bất biến: (i) M1–M3 và M6 không bao giờ chứa fact phần cứng mới — một giá trị thanh ghi xuất hiện trong chat chỉ thành tri thức khi đi qua E2/E5 của KAD; (ii) mọi bản ghi M3 có bằng chứng máy kiểm được (hash, id) — bộ nhớ tình tiết không lưu "cảm nhận"; (iii) đề xuất thay đổi M5 (ngưỡng, skill, prompt) sinh từ M3 phải qua người (APD §6).'));
c.push(H1('3. Schema từng loại'));
c.push(...CODE([
  '# M1 — WorkingMemory (một Run)',
  'class WorkingMemory(BaseModel):',
  '    run_id: str; intent: Intent; grounded: Grounded; defaults_applied: list[Default]; chain: list[ChainNode]',
  '    cursor: dict[str, NodeState]          # node_id → pending|running|done|asked|skipped|failed(n)',
  '    vars: dict[str, Any]                  # kết quả trung gian có tên (passport_id, artifact, target)',
  '    pending_question: Question | None; asked_at: datetime | None',
  '    scratch: list[str]                    # ghi chú ngắn của tác tử cho chính nó (≤ 20 dòng, không vào ngữ cảnh người)',
  '',
  '# M2 — SessionMemory',
  'class SessionMemory(BaseModel):',
  '    session_id: str; project: str; opened_at: datetime; autonomy_effective: AutonomyLevel',
  '    turns: list[Turn]                     # Turn{by: human|agent, text, at, run_id?}; ≥ 3 lượt cũ được thay bằng TurnSummary',
  '    permissions: list[Permission]         # op, target, granted_at, expires_at (R4/R3 ngoài lab)',
  '    undo_items: list[UndoItem]            # run_id, kind, deadline, applied?',
  '    discovery: Discovery | None; notices: list[Notice]',
  '',
  '# M3 — Episodic: dùng thẳng các bảng intent, run, decision_log, capability_run, tool_report, debug_session, measurement, error_ledger (DDD-14)',
  'class ErrorLedgerEntry(BaseModel): id: str; at: datetime; role: str; kind: Literal["hallucination","refusal","tool_fail","human_reject","undo"]; task_ref: str; evidence: str; negative_prompt: str|None',
  '',
  '# M5 — Procedural: Skill, Prompt, ChainTemplate, PolicyRules (PRS-16, POL-17)',
  'class ChainTemplate(BaseModel): id: str; trigger_intents: list[str]; nodes: list[ChainNode]; version: str; bench: dict|None',
  '',
  '# M6 — Preference',
  'class Preference(BaseModel): key: str; scope: Literal["user","project"]; value: Any; learned_from: str|None; at: datetime; ttl_days: int|None',
]));
c.push(SP());
c.push(H1('4. Chính sách ghi, đọc, quên, hợp nhất'));
c.push(H2('4.1. Ghi (khi nào, ai, cần bằng chứng gì)'));
c.push(T([1400, 3300, 2200, 2400], ['Loại', 'Sự kiện ghi', 'Bằng chứng bắt buộc', 'Ràng buộc'], [
  ['M1', 'Mỗi chuyển trạng thái nút chuỗi; mỗi mặc định áp; mỗi câu hỏi', 'run_id, node_id', 'Ghi đồng bộ (WAL) để resume; ≤ 64 KB/run'],
  ['M2', 'Mỗi lượt chat; cấp/hết quyền; đăng ký undo; cắm/rút board', 'session_id', 'Lượt > 2 → tóm tắt bởi mô hình rẻ (CXD §5)'],
  ['M3', 'Mọi lời gọi năng lực (CapabilityRun); mọi quyết định (DecisionLog); mọi ToolReport/Measurement; mọi supersede; mọi lỗi (ErrorLedger)', 'hash đầu vào/đầu ra, decision_id, log_ref', 'Append-only; không sửa; ghi qua Ledger duy nhất'],
  ['M4', 'Chỉ qua PassportStore.write sau cổng', 'Source, locator, tier', 'KAD-07; MEM không ghi trực tiếp'],
  ['M5', 'Người/Pack owner sửa; hệ thống chỉ *đề xuất* (policy.learn_thresholds, skill từ mẫu lặp ≥ 3)', 'Đề xuất kèm thống kê từ M3', 'Không tự áp dụng'],
  ['M6', 'Sau câu trả lời của người cho Question có remember_as; sau người sửa mặc định 2 lần cùng khóa', 'decision_id/turn_id', 'Không lưu dữ liệu nhạy cảm; người xem và xóa được'],
]));
c.push(SP());
c.push(H2('4.2. Đọc (memory.recall)'));
c.push(P('Truy hồi M3 cho một tác vụ dùng điểm tổng hợp theo Generative Agents [46]: `score = 0,5·relevance + 0,3·recency + 0,2·importance`, trong đó relevance = cosine(embedding tóm tắt bản ghi, mô tả tác vụ) hoặc trùng subject IRI/module (=1); recency = e^(−Δngày/14); importance = 1 nếu bản ghi là human_reject/undo/DebugSession kết luận, 0,6 nếu ToolReport thất bại, 0,3 nếu thành công thường. Lấy top-5 ≤ 300 token cho C7/C6; ưu tiên bản ghi cùng module và cùng chip. Bộ nhớ M6 được đọc bằng khóa chính xác theo phạm vi dự án trước, người sau. M5 đọc theo APPLIES_TO/trigger_intents (CXD §4.4).'));
c.push(H2('4.3. Quên và dọn dẹp'));
c.push(T([1400, 3800, 4100], ['Loại', 'Quy tắc', 'Cơ chế'], [
  ['M1', 'Xóa khi Run done/cancelled; giữ WorkingMemory cuối vào run.state để kiểm toán', 'Trường TTL = 0 sau kết thúc; dọn theo ngày'],
  ['M2', 'Đóng phiên: lịch sử → 1 TurnSummary/phiên vào M3; quyền hết hạn; undo quá hạn → không còn hoàn tác', 'session.close(); ledger.append("session.summary")'],
  ['M3', 'Không xóa bản ghi; log/artefact lớn: TTL 90 ngày (cấu hình), giữ hash + 200 dòng đầu/cuối; tổng hợp theo tháng thành thống kê', 'memory.forget(scope="cache") chỉ chạm cache/; job hằng tháng'],
  ['M4', 'Không quên; supersede; dọn phiên bản cũ theo KAD §6.7', 'PassportStore'],
  ['M5', 'Phiên bản cũ giữ trong Git', '—'],
  ['M6', 'Người nói "hỏi lại tôi mỗi lần" / "quên X"; TTL; xóa dự án xóa preferences dự án', 'memory.forget(scope="preference", key)'],
]));
c.push(SP());
c.push(H2('4.4. Hợp nhất và xung đột'));
c.push(P('Cùng khóa M6 ở hai phạm vi: dự án thắng người. Hai bản ghi M3 mâu thuẫn (ToolReport đạt và Reviewer từ chối cùng một patch) đều giữ, hiển thị theo thời gian. Bộ nhớ làm việc của hai Run song song tách biệt; tài nguyên chung (board) được khóa ở TargetService, không ở bộ nhớ.'));
c.push(H1('5. Bộ nhớ qua phiên: PROGRESS, FEATURES và resume'));
c.push(P('Kế thừa khung "harness dài hạn" [18]: PROGRESS.md là bản tóm tắt cho người và cho lượt đầu của phiên mới; FEATURES.json là danh sách tính năng với trạng thái máy đọc được; cả hai được sinh từ M3, không viết tay. Thủ tục khởi động phiên (project.open → memory.summarize_session lượt trước → chat.report_back): (1) kiểm hash store; (2) đọc FEATURES.json, chọn feature failing đầu; (3) đọc run.state có trạng thái running/asked → đề nghị tiếp tục; (4) đọc 1 TurnSummary phiên trước + 5 bản ghi M3 quan trọng nhất (§4.2); (5) tạo báo cáo "lần trước đã… còn chờ… tôi đề nghị…" ≤ 10 dòng. Mục tiêu: tiếp tục ≤ 15 phút (UR-QT-03) và ≤ 1 câu hỏi.'));
c.push(...CODE([
  '# PROGRESS.md (sinh tự động, ví dụ)',
  '## Trạng thái 05/09 21:40 · dự án robot-ctrl · A3 · board blackpill-f411 (lab)',
  '- Đã làm hôm nay: 12 việc tự động (8 fact tự duyệt, 2 merge auto/, 2 nạp), 2 chờ anh (G1 F-07 PID; G-SRC forum.st.com)',
  '- Feature: 5/8 passing; đang làm F-04 MPU6050 (run r_0192, nút code.review đang chạy)',
  '- Hoàn tác được đến 09:14 06/09: merge m_0455 (bme280 forced mode)',
  '- Lưu ý từ sổ lỗi: coder 2 lần đặt sai bit CTRL_MEAS (neg-12 đã thêm vào prompt)',
  '',
  '# FEATURES.json (trích)',
  '{"features":[{"id":"F-04","title":"Đọc MPU6050 qua I2C1","status":"failing","evidence":[],"run":"r_0192","blocked_by":null},',
  '             {"id":"F-03","title":"BME280 forced mode","status":"passing","evidence":["log:sha256:…","measure:m_88"],"verified":"auto"}]}',
]));
c.push(SP());
c.push(H1('6. Học từ vận hành'));
c.push(T([2300, 3400, 3600], ['Nguồn (M3)', 'Cơ chế', 'Đích (M5/M6) và cổng'], [
  ['Sổ lỗi (human_reject, hallucination, undo)', 'Mỗi bản ghi có negative_prompt ≤ 40 token ("Không suy ra bit CTRL_MEAS từ trí nhớ; tra fact"); gom theo vai trò + chip; top-5 mới nhất vào C1 của vai trò đó (CXD §4.1)', 'M5 (prompt phủ định) — tự động, có TTL 30 ngày, hiển thị cho người'],
  ['DecisionLog (30 ngày)', 'policy.learn_thresholds: thống kê tỷ lệ người duyệt/từ chối/hoàn tác theo đặc trưng (tier, confidence, nguồn, loại diff) → đề xuất ngưỡng', 'M5 (autonomy.yaml) — chỉ khi người xác nhận (APD §6)'],
  ['Mẫu lặp trong DebugSession/ToolReport', 'Cùng nguyên nhân ≥ 3 lần trên cùng chip/ngoại vi → đề xuất skill mới (K5) với ví dụ đã chạy', 'M5 (skill) — Pack owner duyệt, benchmark trước khi dùng'],
  ['Câu trả lời của người', 'remember_as → Preference; người sửa mặc định 2 lần → đề xuất đổi default', 'M6 — tự động, người xem/xóa được'],
  ['Chuỗi đã chạy thành công', 'Đồ thị chuỗi giống nhau ≥ 3 lần cho cùng intent → đề xuất ChainTemplate', 'M5 — người duyệt'],
]));
c.push(SP());
c.push(H1('7. Quyền riêng tư và phạm vi'));
c.push(P('Ba phạm vi: người (~/.eide/), dự án (.eide/ — commit Git trừ session, cache, index), registry (chỉ K2/K4/K5/K5′ đã đóng gói). Không có bộ nhớ nào của tác tử rời máy trừ khi được đóng gói có chủ đích (registry.publish) hoặc là nội dung của lượt gọi LLM — và nội dung gửi LLM tuân thủ cờ "nhạy cảm" (SEC-25). Bản ghi M3 chứa đường dẫn, log, ảnh cắt thuộc dự án; không chứa khóa API (bộ lọc ledger). Người có thể xem toàn bộ M6 và M3 của mình qua view.timeline và xóa M6 bất kỳ lúc nào.'));
c.push(H1('8. Hợp đồng mức 3 cho nhóm memory.*'));
c.push(T([1600, 2200, 2200, 3300], ['Năng lực', 'Vào', 'Ra', 'Thuật toán / ghi chú'], [
  ['memory.compose (MEMORY-01)', '{role, task_ref}', 'ContextBundle', 'CXD-10 §4; đọc M4 (fact), M5 (skill, prompt), M6 (defaults), M2/M3 (C7); ghi ledger context.bundle'],
  ['memory.compress (MEMORY-02)', '{bundle | text, target_tokens, kind}', 'text′, compressions[]', 'CXD-10 §5: history:summarize (mô hình rẻ), facts:tabulate, log:window, code:function_only'],
  ['memory.retrieve (MEMORY-03)', '{subjects[], k}', 'facts[], snippets[]', 'Graph-RAG 2 bước (CXD §4.5) + RagIndex.retrieve cho văn bản; trả kèm locator'],
  ['memory.progress (MEMORY-04)', '{entry?}', 'progress (PROGRESS.md, FEATURES.json)', 'Sinh từ M3 §5; entry tùy chọn thêm ghi chú của người; không viết tay'],
  ['memory.ledger (MEMORY-05)', '{record}', '—', 'Append JSONL với schema theo loại (API-15 §7); lọc khóa; hash chuỗi (prev_hash) để chống sửa'],
  ['memory.error_ledger (MEMORY-06)', '{error}', '—', 'Ghi ErrorLedgerEntry; sinh negative_prompt bằng mô hình rẻ với schema; gom theo vai trò/chip'],
  ['memory.forget (MEMORY-07)', '{scope: cache|session|preference|run, key?}', '—', '§4.3; không bao giờ chạm M4; xóa mềm có nhật ký'],
  ['memory.summarize_session (MEMORY-08)', '—', 'summary {done[], waiting[], next[], undo_until}', '§5 thủ tục khởi động/kết thúc phiên; dùng cho chat.report_back'],
]));
c.push(SP());
c.push(P('Bổ sung hai năng lực nhỏ vào Danh mục v1.2 (tập 6 CDS-12): `memory.recall` (truy hồi tình tiết theo điểm §4.2, vào {task_ref, k} ra episodes[]) và `memory.remember` (ghi Preference từ câu trả lời, vào {key, value, scope, learned_from} ra —, R1, T1).'));
c.push(H1('9. Kiểm thử'));
c.push(T([1000, 3300, 3700, 1300], ['TC', 'Mục tiêu', 'Bước / kỳ vọng', 'Mức'], [
  ['TC-MM-01', 'Resume sau tắt máy', 'Run có nút asked → tắt daemon → mở → WorkingMemory khôi phục, câu hỏi hiện lại với thời gian còn lại', 'L1'],
  ['TC-MM-02', 'Tóm tắt phiên', 'Phiên 30 lượt → 1 TurnSummary ≤ 200 token giữ quyết định và số liệu; lượt gốc vẫn trong M3', 'L2'],
  ['TC-MM-03', 'Bộ nhớ không thành fact', 'Người gõ "địa chỉ BME280 là 0x76" trong chat → không có fact mới; tác tử đề nghị mở E2/E10', 'L1'],
  ['TC-MM-04', 'Recall theo điểm', 'M3 mẫu 50 bản ghi: bản ghi cùng module + human_reject xếp trên bản ghi thành công cũ', 'L1'],
  ['TC-MM-05', 'Preference', 'Trả lời "dùng ST-Link" → preferences.yaml; lần sau không hỏi; "hỏi lại tôi mỗi lần" → xóa', 'L2b'],
  ['TC-MM-06', 'Learn không tự áp dụng', 'DecisionLog mẫu → đề xuất ngưỡng; autonomy.yaml không đổi cho tới khi người xác nhận', 'L1'],
  ['TC-MM-07', 'Forget an toàn', 'memory.forget(scope=cache) → cache trống, store nguyên; scope=run trên run đang chạy → từ chối', 'L1'],
  ['TC-MM-08', 'Ledger chống sửa', 'Sửa 1 dòng JSONL → kiểm chuỗi hash phát hiện', 'L1'],
  ['TC-MM-09', 'Khóa API không vào bộ nhớ', 'Gửi chuỗi giống khóa qua chat → mọi bản ghi M2/M3 đã che', 'L1'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-MEM-11_Kien_truc_bo_nho_tac_tu.docx');
