const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const m = metaNew('EIDE-POL-17', 'Quy tắc chính sách tự chủ', 'QUY TẮC CHÍNH SÁCH TỰ CHỦ MÁY ĐỌC ĐƯỢC (POL)',
  'Chuyển EIDE-APD-08 thành đặc tả lập trình được: mô hình quyết định, bảng quy tắc theo cổng, danh sách trắng, schema autonomy.yaml, hoàn tác theo loại, máy trạng thái leo thang và dừng khẩn, học ngưỡng, 48 tình huống kiểm thử',
  [['Tài liệu trước', 'EIDE-APD-08, Danh mục năng lực (cột R, Mức, Hỏi khi), EIDE-SDD-04 §4.7'], ['Tệp kèm', 'policy/rules.yaml, policy/autonomy.schema.json, tests/policy/situations.jsonl'], ['Dùng khi', 'Hiện thực core/engine/policy.py, undo.py; viết TC-51…TC-57']],
  'Phát hành lần đầu — bổ sung lĩnh vực L08',
  [['1.1', '06/09/2026', 'Vũ Trí Công',
    'DEV-011: G-SRC-06 (tài liệu có thể không đúng linh kiện) đổi priority 25 → 5. Ở 25 nó nằm sau '
    + 'G-SRC-01 (10), nên tài liệu từ tên miền tin cậy được tự duyệt mà match_score không bao giờ '
    + 'được xét. Tình huống S06 nay ra đúng "ASK G-SRC-06".'],
   ['1.2', '06/09/2026', 'Vũ Trí Công',
    'Đồng bộ nhóm POL sau Sprint 1. §1: nói rõ tầng T2 mượn mã quy tắc và lý do từ dải chặn '
    + '(ưu tiên ≤ 5) thay vì trả về một mã chung, để G-OPS-02 và G5-02 không còn là quy tắc chết '
    + '(DEV-012); và đặc trưng chưa được cung cấp luôn coi là SAI, kể cả khi viết dạng tên trần '
    + '(DEV-033). §2: G-OPS-06 thêm điều kiện op nên không còn khớp lệnh cài gói (DEV-032); thêm '
    + 'cổng G-WL với ba quy tắc cho việc đổi danh sách trắng (DEV-031). §3: danh sách thứ tư đổi '
    + 'tên lab_boards → boards cho khớp schema §4, vốn khai additionalProperties: false nên từ '
    + 'chối chính cái tên §3 bảo dùng (DEV-030); bổ sung ba điểm về giới hạn của niêm. §5: phạm vi '
    + 'cửa sổ hoàn tác trên hai nhật ký và yêu cầu ReviewQueue gộp cả hai (DEV-014); giá trị mặc '
    + 'định của defaults.yaml (DEV-001). §8: thêm S46–S48 phủ cổng G-WL.'],
   ['1.3', '07/09/2026', 'Vũ Trí Công',
    '§1: ghi rõ HAI ngoại lệ của nhánh R0 ở tầng T2 — quy tắc trong dải chặn (ưu tiên ≤ 5) vẫn '
    + 'thắng kể cả khi chỉ ASK, và quy tắc APPROVE khớp thì mượn mã cùng lý do. Không ghi ra thì '
    + 'lần hiện thực sau đọc "bỏ qua tầng sau" theo nghĩa đen và mở lại đúng hai lỗ hổng ấy '
    + '(DEV-040).'],
   ['1.4', '07/09/2026', 'Vũ Trí Công',
    '§2: nói rõ `source.kind` trong quy tắc dùng TỪ VỰNG CHÍNH SÁCH, không phải enum `Source.kind` của DDD-14 §2 — `pdf_vendor` là một phán xét ("PDF tải từ tên miền chính hãng") chứ không phải một định dạng; kèm bảng ánh xạ hai chiều, và ghi rõ bên gọi chịu trách nhiệm ánh xạ. Truyền thẳng enum DDD-14 vào cổng thì mọi datasheet hãng trượt G-SRC-01 rồi rơi xuống G-SRC-99: quyết định vẫn an toàn nhưng lý do sai, và rất khó tìm vì mọi đặc trưng khác đều đúng (DEV-057).']]);
const c = [];
c.push(H1('1. Mô hình quyết định'));
c.push(P('PolicyGate là một hàm thuần: `decide(action, ctx) → Decision`. Đầu vào là **Action** (năng lực, tham số, cổng gắn nếu có, lớp rủi ro từ registry) và **Context** (mức tự chủ hiệu lực, board, đặc trưng tình huống). Quyết định tính theo bốn tầng, dừng ở tầng đầu tiên cho kết quả REJECT hoặc ASK; APPROVE chỉ khi qua cả bốn tầng. Mọi quyết định ghi DecisionLog với lý do là mã quy tắc (ví dụ `G-SRC-03`), không phải văn xuôi, để thống kê và học ngưỡng.'));
c.push(T([600, 2800, 5900], ['Tầng', 'Kiểm', 'Kết quả'], [
  ['T1', 'Dừng khẩn và ngân sách', 'session.stopped → REJECT(STOP); budget_left_pct < 5 → ASK(BUDGET)'],
  ['T2', 'Lớp rủi ro và danh sách trắng', 'R4 và không trong whitelist đã ký → ASK(R4); R3 và board không lab → ASK(R3-NOLAB); R0 → APPROVE(R0), bỏ qua tầng sau TRỪ hai ngoại lệ ở đoạn dưới'],
  ['T3', 'Mức tự chủ hiệu lực', 'effective_level = min(project.autonomy, board.autonomy?, action_type.autonomy?); nếu effective_level < MIN_LEVEL[risk] → ASK(LEVEL)'],
  ['T4', 'Quy tắc của cổng và của năng lực', 'Bảng §2 theo gate (G-SRC, G-FACT, G1, G3, G-OPS, G4, G5, G-TOOL cho công cụ tác tử tự viết) + điều kiện ask_when của năng lực; quy tắc đầu tiên khớp thắng; không khớp quy tắc nào → mặc định của cổng'],
]));
c.push(SP());
c.push(P('**Tầng T2 tra bảng quy tắc trước khi trả lời.** Ngưỡng cứng của T2 ép ASK, nhưng nếu nó trả về ngay một mã chung như `HARD-R4` thì hai quy tắc `G-OPS-02` ("Không hoàn tác") và `G5-02` ("Công khai") không bao giờ thắng — chúng nói về chính những hành động R4 mà T2 vừa chặn, nên chúng thành quy tắc chết và `decision_log` chỉ còn ghi lớp rủi ro chứ không ghi **điều gì sắp xảy ra**. Người duyệt đọc nhật ký để quyết định, nên đó là mất mát thật. Vì vậy T2 tra bảng §2 để **mượn** mã quy tắc và lý do, nhưng chỉ mượn từ dải chặn — quy tắc có ưu tiên ≤ 5. Quy tắc ưu tiên lớn hơn là lời khuyên chung; dùng nó làm lý do cho một hành động R4 là nói nhỏ đi mức nghiêm trọng (ví dụ giải thích một lệnh xóa flash bằng "Board chưa đánh dấu lab"). Và T2 chỉ **siết**, không nới: một quy tắc APPROVE gặp ngưỡng cứng vẫn ra ASK. Xem DEVIATIONS DEV-012.'));
c.push(SP());
c.push(P('**Hai ngoại lệ của nhánh R0 ở tầng T2.** "Bỏ qua tầng sau" đúng với đa số, nhưng không đúng tuyệt đối, và cả hai chỗ trừ ra đều có lý do cụ thể. (a) Quy tắc trong **dải chặn** (ưu tiên ≤ 5) vẫn thắng, kể cả khi nó chỉ ASK: `TOOL-03` chặn công cụ tác tử tự viết chưa qua kiểm thử — mà lớp rủi ro của công cụ ấy được SUY TỪ HIỆU ỨNG NÓ TỰ KHAI, và `effects_ok` tồn tại đúng vì lời khai có thể sai, nên cho R0 vượt qua là tin lời khai của chính thứ đang bị nghi; `G-SRC-07` hỏi khi một dự án nhạy cảm dùng nguồn đòi gửi dữ liệu ra ngoài, mà vài năng lực `search.*` mang nhãn R0 vì chúng "chỉ đọc" — đọc từ một dịch vụ bên ngoài. (b) Quy tắc APPROVE khớp thì tầng T2 **mượn mã và lý do** của nó thay vì trả về mã chung `R0`: không mượn thì `TOOL-01` thành quy tắc chết và `decision_log` mất câu giải thích, đúng khuôn hỏng mà đoạn trên vừa mô tả cho `G-OPS-02`. Xem DEVIATIONS DEV-040.'));
c.push(SP());
c.push(P('**`source.kind` trong quy tắc dùng TỪ VỰNG CHÍNH SÁCH, không phải enum `Source.kind` của DDD-14 §2.** Hai bảng cùng tên nhưng khác mục đích: DDD-14 mô tả ĐỊNH DẠNG (`svd`, `atdf`, `pdf`, `html`, `image`…), còn `G-SRC-01` chờ `pdf_vendor` — không phải một định dạng mà là một PHÁN XÉT: “PDF tải từ tên miền chính hãng”. Phân biệt ấy đáng giữ, vì một PDF từ st.com và một PDF từ diễn đàn cùng định dạng nhưng khác hẳn mức tin cậy, và chính sách quan tâm cái sau. **Bên gọi chịu trách nhiệm ánh xạ** trước khi truyền đặc trưng; ghi vào bảng `source` vẫn dùng enum DDD-14. Truyền thẳng enum DDD-14 vào cổng thì mọi datasheet hãng trượt `G-SRC-01` và rơi xuống `G-SRC-99` (ASK) — quyết định vẫn an toàn nhưng lý do sai, và rất khó tìm ra vì mọi đặc trưng khác đều đúng: chỉ một từ lệch, mà quy tắc không khớp thì im lặng rơi xuống mặc định chứ không báo gì. Xem DEVIATIONS DEV-057.'));
c.push(T([2200, 2200, 4000], ['Từ vựng chính sách', 'Enum DDD-14 §2', 'Điều kiện ánh xạ'], [
  ['pdf_vendor', 'pdf', 'tên miền nguồn là trang chính hãng (bảng TGT-19 §8)'],
  ['pdf', 'pdf', 'PDF khác — diễn đàn, bản chụp lại, nguồn không rõ'],
  ['svd / atdf / edc / binding', 'như nhau', 'không cần ánh xạ'],
]));
c.push(SP());
c.push(P('**Hai đặc trưng của cổng G1 được SUY RA, không do vai trò khai.** `plan.touches_forbidden` và `plan.arch_change` không phải trường mà planner viết vào Plan; chúng tính từ `Plan.steps[].touches` (PRS-16 §4, enum đóng `isr | linker | clock | dma | power | actuator | none`). `touches_forbidden` đúng khi CÓ bước nào chạm một giá trị khác `none` — G1-01 nói "kế hoạch nhỏ", mà một bước động vào ngắt, linker, clock, DMA, nguồn hay cơ cấu chấp hành thì không còn nhỏ. `arch_change` đúng khi có bước chạm `linker` hoặc `clock`, theo chính lý do của G1-03 ("Đổi kiến trúc (RTOS, clock, linker)"); RTOS không có trong enum nên không suy được từ `touches`. Ghi rõ ở đây vì bản v1.2 dùng hai tên ấy mà không nói chúng đến từ đâu, và một hiện thực đọc chúng như trường mức kế hoạch sẽ thấy cả hai luôn sai — G1-03 thành quy tắc chết. Xem DEVIATIONS DEV-061.'));
c.push(SP());
c.push(P('**Đặc trưng chưa được cung cấp luôn được coi là SAI**, dù nó viết dưới dạng thuộc tính (`board.has_actuator`) hay tên trần (`needs_sudo`). Một hiện thực để tên trần vắng mặt mang tính đúng sẽ làm mọi quy tắc chứa `or <tên đó>` khớp vô điều kiện: đo được trên `G-OPS-05` (ưu tiên 5, ASK), nó che hẳn `G-OPS-04` (ưu tiên 10, APPROVE) và không gói nào trong `trusted_packages` được duyệt tự động — cả danh sách gói tin cậy trở nên vô nghĩa mà bốn mươi lăm tình huống §8 vẫn xanh, vì không tình huống nào bỏ trống đặc trưng ấy. Xem DEVIATIONS DEV-033.'));
c.push(SP());
c.push(...CODE([
  'class Action(BaseModel): cap: str; args: dict; gate: str|None; risk: RiskClass; features: dict     # features do năng lực cung cấp (xem §2 cột Đặc trưng)',
  'class Context(BaseModel): autonomy_project: AutonomyLevel; board: BoardRef|None; session: SessionRef; budget_left_pct: float; stopped: bool; whitelist: Whitelist; thresholds: Thresholds',
  'class Decision(BaseModel): id: str; decision: Literal["APPROVE","ASK","REJECT"]; rule: str; reason: str; evidence: list[str]; features: dict; undo: Undo|None; escalate: Escalation|None',
  'MIN_LEVEL = {"R0": 0, "R1": 1, "R2": 2, "R3": 3, "R4": 5}     # R4: không mức nào đủ (chỉ whitelist)',
]));
c.push(SP());
c.push(H1('2. Bảng quy tắc theo cổng (policy/rules.yaml)'));
c.push(P('Mỗi quy tắc: mã, cổng, biểu thức điều kiện trên đặc trưng (cú pháp Python an toàn, chỉ so sánh/logic/in), quyết định, lý do, ưu tiên (số nhỏ xét trước). Đặc trưng do năng lực cung cấp khi gọi Router (registry khai báo `features_provided`). Ngưỡng tham số hóa qua `thresholds.*` trong autonomy.yaml.'));
const RULES = [
 // G-SRC
 ['G-SRC-01', 'G-SRC', 'source.domain in trusted_sources and source.license in allowed_licenses and source.size_mb <= thresholds.download_max_mb and source.kind in ["svd","atdf","edc","binding","pdf_vendor"]', 'APPROVE', 'Nguồn hãng tin cậy, license rõ, trong ngưỡng', 10, 'source.domain, license, size_mb, kind, hash_match'],
 ['G-SRC-02', 'G-SRC', 'source.kind == "registry" and source.signature_valid', 'APPROVE', 'Gói registry đã ký', 10, 'signature_valid'],
 ['G-SRC-03', 'G-SRC', 'source.hash_match == False and source.expected_hash', 'REJECT', 'Hash không khớp hash đã biết', 5, 'hash_match'],
 ['G-SRC-04', 'G-SRC', 'source.size_mb > thresholds.download_max_mb', 'ASK', 'Tệp lớn', 20, 'size_mb'],
 ['G-SRC-05', 'G-SRC', 'source.license not in allowed_licenses', 'ASK', 'License không rõ/không cho phép', 20, 'license'],
 // priority 5 (không phải 25) — cùng nhóm "chặn trước khi tin" với G-SRC-03 (hash lệch) và
 // G-SRC-07 (dự án nhạy cảm). Ở 25 nó nằm SAU G-SRC-01 (10), nên tài liệu từ tên miền tin cậy
 // được tự duyệt mà match_score không bao giờ được xét: datasheet của biến thể chip khác, tải
 // từ đúng trang hãng, vào kho không ai hỏi — rồi mọi fact trích từ nó mang nhãn "nguồn tin
 // cậy". Xem DEVIATIONS DEV-011, tình huống S06.
 ['G-SRC-06', 'G-SRC', 'source.match_score < thresholds.source_match_min', 'ASK', 'Tài liệu có thể không đúng linh kiện/phiên bản', 5, 'match_score'],
 ['G-SRC-07', 'G-SRC', 'project.sensitive and source.requires_upload', 'ASK', 'Dự án nhạy cảm, nguồn yêu cầu gửi dữ liệu ra ngoài', 5, 'requires_upload'],
 ['G-SRC-99', 'G-SRC', 'True', 'ASK', 'Mặc định: nguồn ngoài danh sách tin cậy', 99, ''],
 // G-FACT
 ['G-FACT-01', 'G-FACT', 'fact.tier == "gold"', 'APPROVE', 'Fact tầng vàng', 10, 'tier'],
 ['G-FACT-02', 'G-FACT', 'fact.tier == "silver" and fact.confidence >= thresholds.fact_silver_auto and (fact.second_source or fact.range_ok) and not fact.conflict and fact.method != "vision_llm" and fact.predicate not in ["voltage_range","timing"]', 'APPROVE', 'Bạc đạt ngưỡng, có nguồn thứ hai hoặc khớp dải, không mâu thuẫn', 15, 'confidence, second_source, range_ok, conflict, method, predicate'],
 ['G-FACT-03', 'G-FACT', 'fact.tier == "silver" and fact.predicate in ["voltage_range","timing"] and fact.second_source and fact.confidence >= thresholds.fact_silver_auto', 'APPROVE', 'Fact điện/timing chỉ tự duyệt khi có nguồn thứ hai', 16, 'predicate, second_source'],
 ['G-FACT-04', 'G-FACT', 'fact.conflict', 'ASK', 'Mâu thuẫn với fact hiện hành', 5, 'conflict'],
 ['G-FACT-05', 'G-FACT', 'fact.tier == "bronze"', 'REJECT', 'Tầng đồng không vào fact (KAD E8)', 5, 'tier'],
 ['G-FACT-99', 'G-FACT', 'True', 'ASK', 'Mặc định: bạc dưới ngưỡng / OCR / thiếu nguồn hai', 99, ''],
 // G1
 ['G1-01', 'G1', 'plan.steps <= thresholds.plan_max_steps and plan.all_cited and not plan.new_resources and not plan.touches_forbidden and plan.est_cost_usd <= thresholds.plan_max_cost_usd and not feature.needs_review', 'APPROVE', 'Kế hoạch nhỏ, có trích dẫn, không tài nguyên mới', 10, 'steps, all_cited, new_resources, touches_forbidden, est_cost_usd, needs_review'],
 ['G1-02', 'G1', 'plan.missing', 'ASK', 'Thiếu tri thức → mở P1 trước', 5, 'missing'],
 ['G1-03', 'G1', 'plan.arch_change', 'ASK', 'Đổi kiến trúc (RTOS, clock, linker)', 5, 'arch_change'],
 ['G1-99', 'G1', 'True', 'ASK', 'Mặc định', 99, ''],
 // G3
 ['G3-01', 'G3', 'patch.tools_passed == 4 and patch.constant_guard_violations == 0 and review.verdict == "PASS" and review.max_severity in ["minor","nit","none"] and patch.in_scope and patch.size_growth_pct <= thresholds.merge_size_growth_pct and not patch.touches_isr_linker and reviewer.vendor != coder.vendor', 'APPROVE', 'Đủ bằng chứng máy: 4 cổng, reviewer khác hãng PASS, trong phạm vi', 10, 'tools_passed, constant_guard_violations, verdict, max_severity, in_scope, size_growth_pct, touches_isr_linker, vendors'],
 ['G3-02', 'G3', 'review.max_severity in ["blocker","major"]', 'ASK', 'Reviewer có finding blocker/major', 5, 'max_severity'],
 ['G3-03', 'G3', 'patch.constant_guard_violations > 0', 'REJECT', 'Hằng số không nguồn', 1, 'constant_guard_violations'],
 ['G3-04', 'G3', 'reviewer.vendor == coder.vendor', 'ASK', 'Không có hãng thứ hai (cảnh báo ledger)', 20, 'vendors'],
 ['G3-99', 'G3', 'True', 'ASK', 'Mặc định', 99, ''],
 // G-OPS
 ['G-OPS-01', 'G-OPS', 'board.lab and op in ["flash","reset","rtt","read_mem","write_ram","experiment_no_actuator"] and artifact.passed_g3 and artifact.hash_match and board.flash_count_hour < thresholds.flash_per_hour', 'APPROVE', 'Board lab, artifact qua G3, trong hạn mức', 10, 'board.lab, op, passed_g3, hash_match, flash_count_hour'],
 ['G-OPS-02', 'G-OPS', 'op in ["erase_all","fuse","option_bytes","readout_protect"]', 'ASK', 'Không hoàn tác (R4)', 1, 'op'],
 ['G-OPS-03', 'G-OPS', 'op == "actuator" or board.has_actuator and op in ["flash","experiment"]', 'ASK', 'Cơ cấu chấp hành / board có động cơ', 1, 'op, has_actuator'],
 ['G-OPS-04', 'G-OPS', 'op == "install" and package in trusted_packages', 'APPROVE', 'Cài gói từ danh sách tin cậy', 10, 'package'],
 ['G-OPS-05', 'G-OPS', 'op == "install" and (package not in trusted_packages or needs_sudo)', 'ASK', 'Gói lạ hoặc cần quyền hệ thống', 5, 'package, needs_sudo'],
 // Bảy `op` dưới đây là đúng những thao tác trên BOARD còn tới được ưu tiên 20: tập của
 // G-OPS-01 cộng `experiment` (G-OPS-02/03 đã bắt erase_all/fuse/option_bytes/readout_protect
 // và actuator ở ưu tiên 1). Thiếu điều kiện này, quy tắc khớp cả `op == "install"` và ghi vào
 // decision_log "Board chưa đánh dấu lab" cho một lệnh cài gói — mời người đi nới lỏng chính
 // sách cho một vấn đề không nằm ở board. Xem DEVIATIONS DEV-032.
 ['G-OPS-06', 'G-OPS', 'not board.lab and op in ["flash","reset","rtt","read_mem","write_ram","experiment","experiment_no_actuator"]', 'ASK', 'Board chưa đánh dấu lab (đề nghị đánh dấu nếu không có cơ cấu chấp hành)', 20, 'board.lab, op'],
 ['G-OPS-99', 'G-OPS', 'True', 'ASK', 'Mặc định', 99, ''],
 // G4
 ['G4-01', 'G4', 'expect.machine_observable and expect.all_passed', 'APPROVE', 'Kỳ vọng máy quan sát được đều đạt → auto-verified', 10, 'machine_observable, all_passed'],
 ['G4-02', 'G4', 'expect.machine_observable and not expect.all_passed', 'REJECT', 'Kỳ vọng máy không đạt → Feature vẫn failing, về P3/P5', 5, 'all_passed'],
 ['G4-99', 'G4', 'True', 'ASK', 'Chỉ quan sát bằng mắt/tay', 99, ''],
 // G5
 ['G5-01', 'G5', 'publish.scope == "internal" and pkg.auto_verified and pkg.bench_bc >= thresholds.bench_bc_min and pkg.license_ok and not pkg.contains_project_knowledge', 'APPROVE', 'Phát hành nội bộ gói đã kiểm định', 10, 'scope, auto_verified, bench_bc, license_ok, contains_project_knowledge'],
 ['G5-02', 'G5', 'publish.scope == "public"', 'ASK', 'Công khai (R4)', 1, 'scope'],
 ['G5-03', 'G5', 'pkg.contains_project_knowledge', 'ASK', 'Chứa K3/K6 của dự án', 2, 'contains_project_knowledge'],
 ['G5-99', 'G5', 'True', 'ASK', 'Mặc định', 99, ''],
 // G-TOOL: công cụ do tác tử tự viết (tool.run)
 ['TOOL-01', 'G-TOOL', 'tool.tested and tool.effects_ok and tool.risk == "R0"', 'APPROVE', 'Công cụ chỉ đọc, đã test, hiệu ứng khớp', 10, 'tested, effects_ok, risk'],
 ['TOOL-02', 'G-TOOL', 'tool.tested and tool.effects_ok and tool.risk in ["R1","R2"] and tool.last_fail_count == 0', 'APPROVE', 'Công cụ ghi dự án/mạng đã test, không lỗi gần đây (có hoàn tác)', 12, 'tested, effects_ok, risk, last_fail_count'],
 ['TOOL-03', 'G-TOOL', 'not tool.tested or not tool.effects_ok', 'REJECT', 'Chưa test hoặc hiệu ứng thực tế vượt khai báo', 1, 'tested, effects_ok'],
 ['TOOL-04', 'G-TOOL', 'tool.risk == "R3" and board.lab and tool.uses_ok >= 3', 'APPROVE', 'Công cụ phần cứng đã dùng ≥ 3 lần ok trên board lab', 15, 'risk, board.lab, uses_ok'],
 ['TOOL-05', 'G-TOOL', 'tool.risk == "R4" or "system" in tool.effects', 'ASK', 'Hiệu ứng hệ thống (sudo, ngoài dự án, cài đặt)', 1, 'risk, effects'],
 ['TOOL-99', 'G-TOOL', 'True', 'ASK', 'Mặc định cho công cụ tự viết', 99, ''],
 // Hội thoại / chung
 // G-WL — cổng danh sách trắng. §3 gọi đổi danh sách là "hành động R4 theo cổng riêng" nhưng
 // trước v1.2 không có cổng nào như thế trong bảng này (DEVIATIONS DEV-031). Ba quy tắc:
 // ký là việc của NGƯỜI (không năng lực nào mang mã `policy.sign`, xem §3), nên tác tử chạm
 // vào danh sách là REJECT chứ không phải ASK — hỏi người "cho tôi tự sửa danh sách trắng nhé?"
 // là đúng câu hỏi mà một tác tử bị chiếm quyền sẽ hỏi.
 ['G-WL-01', 'G-WL', 'actor == "human" and wl.verified', 'APPROVE', 'Người ký danh sách trắng, niêm khớp', 5, 'actor, verified'],
 ['G-WL-02', 'G-WL', 'actor != "human"', 'REJECT', 'Chỉ người mới được đổi danh sách trắng (R4)', 1, 'actor'],
 ['G-WL-99', 'G-WL', 'True', 'ASK', 'Mặc định: thay đổi danh sách trắng cần người xác nhận', 99, ''],
 ['GEN-01', '*', 'cap.ask_when_matched', 'ASK', 'Điều kiện "Hỏi kỹ sư khi" của năng lực khớp', 30, 'ask_when_matched'],
 ['GEN-02', '*', 'action.fail_count >= thresholds.fail_retries', 'ASK', 'Thất bại lặp → leo thang', 3, 'fail_count'],
 ['GEN-03', '*', 'action.is_delete_project or action.is_overwrite_project', 'ASK', 'Xóa/ghi đè dự án (R4)', 1, 'is_delete_project, is_overwrite_project'],
];
c.push(T([1000, 800, 3300, 900, 2100, 1200], ['Mã', 'Cổng', 'Điều kiện (đặc trưng)', 'Quyết định', 'Lý do', 'Ưu tiên'], RULES.map(r => [r[0], r[1], r[2], r[3], r[4], String(r[5])]), { size: 18 }));
c.push(SP());
if (!fs.existsSync('policy')) fs.mkdirSync('policy');
const yaml = ['# policy/rules.yaml — sinh từ EIDE-POL-17 §2; PolicyGate nạp lúc khởi động; quy tắc ưu tiên nhỏ xét trước; quy tắc đầu tiên khớp thắng', 'version: 1.0', 'rules:'];
for (const r of RULES) yaml.push(`  - id: ${r[0]}\n    gate: "${r[1]}"\n    when: ${JSON.stringify(r[2])}\n    decision: ${r[3]}\n    reason: ${JSON.stringify(r[4])}\n    priority: ${r[5]}\n    features: ${JSON.stringify(r[6].split(',').map(s => s.trim()).filter(Boolean))}`);
fs.writeFileSync('policy/rules.yaml', yaml.join('\n') + '\n');
c.push(P('Tệp `policy/rules.yaml` kèm theo chứa đúng bảng trên. Trình đánh giá điều kiện là một trình thông dịch biểu thức nhỏ (không `eval`): chỉ cho phép tên đặc trưng, hằng, so sánh, `and/or/not/in`, danh sách; đặc trưng thiếu ⇒ điều kiện sai (an toàn về phía ASK). Người có thể thêm quy tắc riêng trong `.eide/policy.local.yaml` nhưng chỉ được **siết** (đổi APPROVE → ASK), không được nới; nới lỏng chỉ qua đổi ngưỡng có xác nhận (§7).'));
c.push(H1('3. Danh sách trắng và chữ ký'));
c.push(P('Bốn danh sách trong autonomy.yaml, tên và hình dạng theo schema §4: `trusted_sources` (tên miền), `trusted_packages` (gói công cụ), `allowed_licenses` (license được nhận), `boards` (bảng board id → {lab, has_actuator, autonomy, reason}). Mỗi thay đổi danh sách là hành động R4 qua cổng `G-WL` (§2): người ký bằng lệnh `eide policy sign` — ghi băm nội dung + user + thời điểm vào decision_log (sự kiện `policy.sign`, API-15 §5) và tệp `.eide/policy.sig`. PolicyGate từ chối nạp danh sách có băm không khớp chữ ký; khi ấy nó **bỏ hẳn** ba danh sách khỏi biểu thức điều kiện thay vì nạp danh sách rỗng, và ghi lý do "danh sách trắng chưa ký" vào quyết định. Đánh dấu board lab (board.mark_lab) yêu cầu người xác nhận hai điều: không có cơ cấu chấp hành nguy hiểm và nguồn có giới hạn dòng.'));
c.push(SP());
c.push(P('**Ba điểm cần nói rõ về cơ chế này.** (a) Chữ ký ở đây là *niêm*, không phải mật mã: nội dung của nó là băm + người + thời điểm, không có khóa và không có bên thứ ba. Nó phát hiện được sửa đổi vô tình hoặc cẩu thả, chứ không chống được người đã ghi được vào `.eide/` — người ấy sửa danh sách rồi sửa luôn `policy.sig`. Điều làm nó không rỗng nghĩa là yêu cầu ghi vào **hai** nơi: nhật ký là chuỗi băm nối tiếp, nên phép đối chiếu `.sig` với bản ghi `policy.sign` mới nhất bắt được đúng trường hợp sửa hai tệp cạnh nhau. (b) Niêm phủ cấu hình **sau khi hợp nhất** `defaults.yaml` với `autonomy.yaml` của dự án, không phủ nội dung tệp: một dự án bỏ trống `allowed_licenses` vẫn chạy bằng danh sách của tệp mặc định, nên niêm chỉ phủ tệp dự án sẽ để người ký đặt tên mình lên một phần chính sách trong khi phần còn lại đến từ một tệp không ai niêm. (c) Niêm **không** phủ `thresholds` và `autonomy`: hai thứ ấy đổi thường xuyên qua `policy.learn_thresholds` (§7) và có đường kiểm soát riêng — gộp chúng vào sẽ bắt ký lại danh sách trắng mỗi tuần, và một cơ chế bắt ký quá thường xuyên là một cơ chế người ta bấm qua cho xong.'));
c.push(SP());
c.push(P('Việc ký là **lệnh CLI**, không phải năng lực: trong danh mục 238 năng lực không có mã nào cho `policy.sign`. Một năng lực thì Router gọi được, tức tác tử gọi được, tức tác tử tự cấp quyền cho chính nó — hỏng đúng thứ danh sách trắng dựng lên để giữ. Vì lẽ đó quy tắc `G-WL-02` trả REJECT chứ không phải ASK khi bên gọi không phải người.'));
c.push(H1('4. Schema autonomy.yaml'));
const AUTONOMY_SCHEMA = [
  '{ "$id": "https://eide.code247.ai/schema/autonomy.json", "type": "object", "required": ["autonomy", "thresholds"], "additionalProperties": false,',
  '  "properties": {',
  '    "autonomy": {"type": "string", "enum": ["A0","A1","A2","A3","A4"]},',
  '    "boards": {"type": "object", "additionalProperties": {"type": "object", "properties": {"autonomy": {"type": "string", "enum": ["A0","A1","A2","A3","A4"]}, "lab": {"type": "boolean"}, "has_actuator": {"type": "boolean"}, "reason": {"type": "string"}}}},',
  '    "action_types": {"type": "object", "additionalProperties": {"type": "string", "enum": ["A0","A1","A2","A3","A4"]}},',
  '    "thresholds": {"type": "object", "properties": {',
  '        "fact_silver_auto": {"type": "number", "minimum": 0.5, "maximum": 1, "default": 0.85},',
  '        "source_match_min": {"type": "number", "default": 0.7}, "download_max_mb": {"type": "integer", "default": 50},',
  '        "plan_max_steps": {"type": "integer", "default": 12}, "plan_max_cost_usd": {"type": "number", "default": 1.0},',
  '        "merge_size_growth_pct": {"type": "number", "default": 5}, "flash_per_hour": {"type": "integer", "default": 20},',
  '        "bench_bc_min": {"type": "number", "default": 0.9}, "fail_retries": {"type": "integer", "default": 2}, "budget_warn_pct": {"type": "number", "default": 20}}},',
  '    "trusted_sources": {"type": "array", "items": {"type": "string"}}, "trusted_packages": {"type": "array", "items": {"type": "string"}}, "allowed_licenses": {"type": "array", "items": {"type": "string"}},',
  '    "undo_window": {"type": "object", "properties": {"facts": {"type": "string", "default": "72h"}, "merge": {"type": "string", "default": "24h"}, "flash": {"type": "string", "default": "session"}, "files": {"type": "string", "default": "24h"}}},',
  '    "ask_timeout_s": {"type": "integer", "default": 120},',
  '    "defaults": {"type": "object", "properties": {"project_dir": {"type": "string"}, "model_profile": {"type": "string"}, "sim_first": {"type": "boolean"}, "diagram_lang": {"type": "string"}, "doc_lang": {"type": "string"}, "create_when_exists": {"type": "string", "enum": ["ask","reuse","new"]}}},',
  '    "escalation": {"type": "object", "properties": {"channels": {"type": "array", "items": {"type": "string", "enum": ["queue","chat","notify"]}}, "notify": {"type": "object"}}},',
  '    "sensitive": {"type": "boolean", "default": false} } }',
];
c.push(...CODE(AUTONOMY_SCHEMA));
c.push(SP());
c.push(H1('5. Hoàn tác theo loại'));
c.push(T([2000, 3300, 2200, 1800], ['Loại undo', 'Cách hoàn tác', 'Cửa sổ', 'Năng lực dùng'], [
  ['supersede_facts', 'Với mỗi fact tự duyệt: tạo fact mới supersedes với status = superseded, khôi phục fact trước (nếu có) thành hiện hành; ghi lý do "undo:<decision_id>"', 'facts (72h)', 'kg.review_facts, kg.supersede, search.fetch (fact sinh từ nguồn)'],
  ['git_revert', 'git revert commit merge vào auto/ (giữ lịch sử); chạy lại build để xác nhận; FEATURES cập nhật', 'merge (24h)', 'code.merge, code.integrate'],
  ['reflash_known_good', 'Nạp lại artifact known-good gần nhất qua target.flash (được coi là R3 trên board lab, tự động)', 'flash (phiên)', 'target.flash, target.probe_write'],
  ['delete_created_files', 'Xóa tệp/thư mục do năng lực tạo (đường dẫn ghi trong CapabilityRun), không chạm tệp có sẵn', 'files (24h)', 'project.create, doc.generate, diagram.render, env.install_tool (gỡ gói)'],
  ['restore_config', 'Khôi phục tệp cấu hình từ bản sao trước (autonomy/target/constraints)', 'files (24h)', 'discover.auto_setup, policy.set_autonomy'],
  ['none', 'Không hoàn tác (R0 đọc; hoặc R4 đã qua người)', '—', '—'],
]));
c.push(SP());
c.push(P('**Phạm vi của cửa sổ hoàn tác.** DEP-26 §3 đặt một daemon cho mỗi người dùng phục vụ nhiều dự án, nên có **hai** nhật ký: nhật ký dự án (`<dự án>/.eide/store/ledger.jsonl`) và nhật ký người dùng. Sự kiện thuộc về một dự án ghi vào nhật ký dự án; sự kiện liên-dự-án ghi vào nhật ký người dùng. `project.create` thuộc loại thứ hai — lúc nó chạy thì dự án chưa tồn tại, nên chưa có nhật ký nào để ghi vào. Hệ quả cần biết khi hiện thực: `policy.undo_window` gọi bên trong một dự án sẽ **không** thấy mục hoàn tác của việc tạo chính dự án ấy, và **màn hình ReviewQueue (UXD-13) phải gộp cả hai nguồn** — đọc mỗi nhật ký dự án thì người dùng không bao giờ thấy nút hoàn tác cho việc tạo dự án. Xem DEVIATIONS DEV-014.'));
c.push(SP());
c.push(P('**Giá trị mặc định.** Khi một dự án chưa có `.eide/autonomy.yaml`, PolicyGate chạy bằng `policy/defaults.yaml` đi kèm bản cài: các ngưỡng lấy đúng trường `default` của schema §4; `allowed_licenses` = MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, CC-BY-4.0, vendor-doc; `boards` để rỗng, vì đánh dấu board lab đòi người xác nhận hai điều chỉ người cầm board mới biết (§3). Bốn danh sách trong tệp ấy được niêm sẵn (`policy/defaults.sig`) và dự án mới kế thừa niêm khi băm trùng — bắt người ký lại một danh sách họ vừa ký là cách chắc chắn khiến lần ký sau không ai đọc. Cấu hình dự án hợp nhất **lên trên** tệp mặc định, không thay thế nó. Xem DEVIATIONS DEV-001.'));
c.push(SP());
c.push(H1('6. Máy trạng thái leo thang và dừng khẩn'));
c.push(...CODE([
  'Action: DECIDED(APPROVE) → EXECUTING → DONE(undo_deadline) → [UNDONE | EXPIRED]',
  '        DECIDED(ASK)     → QUEUED(ask) → [ANSWERED → EXECUTING | TIMEOUT → (mặc định có? → EXECUTING : QUEUED(escalated))]',
  '        EXECUTING —fail→ RETRY(n) —n ≥ fail_retries→ QUEUED(escalated)',
  'Escalation channels theo mức: queue (luôn) → chat (ASK sau timeout/2) → notify (R3/R4 hoặc ngân sách < warn_pct hoặc board lệch hộ chiếu)',
  'Emergency stop: policy.emergency_stop → session.stopped = true; autonomy_effective = A0; mọi Action EXECUTING với risk ≥ R3 → CANCELLED (gửi abort tới TargetService); QUEUED giữ nguyên; thời gian ≤ 1 s; ghi decision_log STOP; chỉ người mới bỏ trạng thái dừng (policy.set_autonomy)',
]));
c.push(SP());
c.push(H1('7. Học ngưỡng'));
c.push(P('policy.learn_thresholds chạy hằng tuần trên DecisionLog 30 ngày: với mỗi cổng và mỗi nhóm đặc trưng (ví dụ G-FACT × nguồn pdf_vendor × dải confidence 0,05), tính tỷ lệ người APPROVE khi máy ASK (gợi ý nới) và tỷ lệ người UNDO khi máy APPROVE (gợi ý siết). Đề xuất chỉ khi n ≥ 20 và tỷ lệ ≥ 0,9 (nới) hoặc ≥ 0,2 (siết); mỗi đề xuất là một bản ghi {threshold, from, to, evidence_n, rate} hiển thị trong hàng đợi; người xác nhận ⇒ ghi autonomy.yaml + ký; từ chối ⇒ không đề xuất lại cùng nội dung trong 60 ngày. Siết được đề xuất tự động áp dụng tạm (an toàn hơn) cho tới khi người quyết định.'));
c.push(H1('8. Bốn mươi tám tình huống kiểm thử (TC-51)'));
const SIT = [
 ['S01', 'G-SRC', 'A3; st.com; svd; 2 MB; license MIT; hash khớp', 'APPROVE G-SRC-01'],
 ['S02', 'G-SRC', 'A3; forum.st.com; pdf; 1 MB', 'ASK G-SRC-99'],
 ['S03', 'G-SRC', 'A3; st.com; pdf_vendor; 80 MB', 'ASK G-SRC-04'],
 ['S04', 'G-SRC', 'A1; registry; chữ ký hợp lệ', 'APPROVE G-SRC-02'],
 ['S05', 'G-SRC', 'A3; st.com; hash lệch hash đã biết', 'REJECT G-SRC-03'],
 ['S06', 'G-SRC', 'A3; bosch-sensortec.com; match_score 0,4', 'ASK G-SRC-06'],
 ['S07', 'G-SRC', 'A3; dự án nhạy cảm; docs MCP cần upload', 'ASK G-SRC-07'],
 ['S08', 'G-SRC', 'A0; st.com; svd', 'ASK (T3 LEVEL)'],
 ['S09', 'G-FACT', 'A3; gold', 'APPROVE G-FACT-01'],
 ['S10', 'G-FACT', 'A3; silver 0,9; nguồn 2; không mâu thuẫn; parser', 'APPROVE G-FACT-02'],
 ['S11', 'G-FACT', 'A3; silver 0,8; nguồn 2', 'ASK G-FACT-99'],
 ['S12', 'G-FACT', 'A3; silver 0,95; mâu thuẫn', 'ASK G-FACT-04'],
 ['S13', 'G-FACT', 'A3; silver 0,95; vision_llm', 'ASK G-FACT-99'],
 ['S14', 'G-FACT', 'A3; silver 0,9 timing; không nguồn 2', 'ASK G-FACT-99'],
 ['S15', 'G-FACT', 'A3; silver 0,9 timing; nguồn 2', 'APPROVE G-FACT-03'],
 ['S16', 'G-FACT', 'A3; bronze', 'REJECT G-FACT-05'],
 ['S17', 'G-FACT', 'A1; gold', 'APPROVE G-FACT-01'],
 ['S18', 'G1', 'A3; 6 bước; đủ trích dẫn; không tài nguyên mới; 0,3 USD', 'APPROVE G1-01'],
 ['S19', 'G1', 'A3; 14 bước', 'ASK G1-99'],
 ['S20', 'G1', 'A3; missing = [I2C timing]', 'ASK G1-02'],
 ['S21', 'G1', 'A3; đổi sang RTOS', 'ASK G1-03'],
 ['S22', 'G1', 'A1; 6 bước hợp lệ', 'ASK (T3 LEVEL, R2 cần A2)'],
 ['S23', 'G3', 'A3; 4/4 cổng; CG 0; PASS minor; trong phạm vi; +2%; khác hãng', 'APPROVE G3-01'],
 ['S24', 'G3', 'A3; như S23 nhưng major', 'ASK G3-02'],
 ['S25', 'G3', 'A3; CG 2 vi phạm', 'REJECT G3-03'],
 ['S26', 'G3', 'A3; như S23 nhưng cùng hãng', 'ASK G3-04'],
 ['S27', 'G3', 'A3; như S23 nhưng chạm ISR', 'ASK G3-99'],
 ['S28', 'G3', 'A3; như S23 nhưng +8% Flash', 'ASK G3-99'],
 ['S29', 'G-OPS', 'A3; board lab; flash; artifact qua G3; hash khớp; 3 lần/giờ', 'APPROVE G-OPS-01'],
 ['S30', 'G-OPS', 'A3; board không lab; flash', 'ASK G-OPS-06 (T2 R3-NOLAB)'],
 ['S31', 'G-OPS', 'A4; erase_all', 'ASK G-OPS-02 (R4)'],
 ['S32', 'G-OPS', 'A3; board lab có động cơ; flash', 'ASK G-OPS-03'],
 ['S33', 'G-OPS', 'A3; install renode (trusted)', 'APPROVE G-OPS-04'],
 ['S34', 'G-OPS', 'A3; install gói lạ cần sudo', 'ASK G-OPS-05'],
 ['S35', 'G-OPS', 'A3; board lab; flash lần 21 trong giờ', 'ASK G-OPS-99'],
 ['S36', 'G4', 'A3; serial expect + probe đọc đạt', 'APPROVE G4-01'],
 ['S37', 'G4', 'A3; kỳ vọng "LED sáng" không cảm biến', 'ASK G4-99'],
 ['S38', 'G5', 'A4; nội bộ; auto-verified; BC 0,93; license ok', 'APPROVE G5-01'],
 ['S39', 'G5', 'A4; công khai', 'ASK G5-02'],
 ['S40', '*', 'A3; session.stopped; bất kỳ', 'REJECT STOP'],
 ['S41', 'G-TOOL', 'A3; công cụ tự viết đã test, effects [read_fs]', 'APPROVE TOOL-01'],
 ['S42', 'G-TOOL', 'A3; công cụ chưa test', 'REJECT TOOL-03'],
 ['S43', 'G-TOOL', 'A3; effects [write_project], test đạt, 0 lỗi', 'APPROVE TOOL-02'],
 ['S44', 'G-TOOL', 'A3; effects [hardware], board lab, uses_ok 1', 'ASK TOOL-99'],
 ['S45', 'G-TOOL', 'A4; effects [system]', 'ASK TOOL-05'],
 // G-WL — cổng danh sách trắng, thêm ở v1.2 (§3). Không có tình huống nào cho một cổng
 // nghĩa là cổng ấy không được TC-51 kiểm, và test độ phủ trong kho bắt đúng điều đó.
 ['S46', 'G-WL', 'Người chạy `eide policy sign`; niêm khớp cấu hình sau hợp nhất', 'APPROVE G-WL-01'],
 ['S47', 'G-WL', 'Tác tử tự gọi để thêm một tên miền vào trusted_sources', 'REJECT G-WL-02'],
 ['S48', 'G-WL', 'Người ký nhưng băm không khớp niêm (danh sách đã đổi sau khi ký)', 'ASK G-WL-99'],
];
c.push(T([700, 900, 5000, 2700], ['#', 'Cổng', 'Tình huống (mức; đặc trưng)', 'Kỳ vọng (quyết định, quy tắc)'], SIT, { size: 19 }));
fs.writeFileSync('policy/situations.jsonl', SIT.map(s => JSON.stringify({ id: s[0], gate: s[1], situation: s[2], expected: s[3] })).join('\n') + '\n');
c.push(SP());
c.push(P('Tệp `tests/policy/situations.jsonl` chứa 48 tình huống; TC-51 nạp rules.yaml và autonomy.yaml mặc định, dựng Action/Context tương ứng, so quyết định và mã quy tắc. TC-55 đổi `fact_silver_auto` 0,85 → 0,8 và kiểm S11 chuyển thành APPROVE.'));
c.push(H1('9. Giao diện Python'));
c.push(...CODE([
  'class PolicyGate:',
  '    def __init__(self, rules: RuleSet, cfg: AutonomyConfig, whitelist: Whitelist, log: DecisionLog)',
  '    def decide(self, action: Action, ctx: Context) -> Decision              # §1 bốn tầng; thuần, không tác dụng phụ ngoài log',
  '    def effective_level(self, ctx: Context, action: Action) -> AutonomyLevel',
  '    def emergency_stop(self, session: SessionRef) -> None',
  '    def propose_thresholds(self, days=30) -> list[ThresholdProposal]',
  '    def apply_threshold(self, proposal_id: str, by: str) -> None            # yêu cầu by = human; ký lại autonomy.yaml',
  'class RuleSet:  load(path) ; evaluate(gate, features) -> Rule|None         # trình thông dịch biểu thức an toàn',
  'class Whitelist: sources/packages/boards ; verify_signature() ; sign(by)',
  'class UndoService: register(run, kind, payload) ; apply(ref) ; list(session) ; expire()',
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-POL-17_Quy_tac_chinh_sach.docx');
