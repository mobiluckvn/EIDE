const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const D = JSON.parse(fs.readFileSync('ddd.json', 'utf8'));
const m = metaNew('EIDE-DDD-14', 'Từ điển dữ liệu', 'TỪ ĐIỂN DỮ LIỆU, DDL VÀ DI TRÚ (DDD)',
  'Nguồn duy nhất cho mọi thực thể của EIDE: từ điển dữ liệu 29 thực thể / 275 trường, JSON Schema 2020-12, DDL SQLite, thứ tự di trú từ M0, schema các tệp YAML, quy ước định danh',
  [['Tài liệu trước', 'EIDE-SDD-04 §3, EIDE-SAD-03 §5, EIDE-MEM-11 §3, EIDE-POL-17 §4'], ['Tệp kèm', 'ddd_model.py (nguồn), data/json/*.json (27 JSON Schema), data/schema.sql (DDL), gen_ddd.py'], ['Dùng khi', 'Hiện thực pydantic models, migration, kiểm hợp lệ khi ghi; sinh tài liệu API']],
  'Phát hành lần đầu — bổ sung lĩnh vực L05/L31; sinh tự động từ ddd_model.py',
  [['1.1', '07/09/2026', 'Vũ Trí Công',
    '§2 Preference: bảng `preference` giữ RIÊNG scope=project, scope=user nằm ở '
    + '`preferences.yaml` (§6) — bảng nằm trong store TỪNG dự án nên một tùy chọn "user" ghi ở '
    + 'dự án A không đọc được ở dự án B (DEV-010); trường `value` nói rõ là giá trị JSON bất kỳ '
    + 'chứ không chỉ đối tượng, và learned_from/ttl_days là trường ngang hàng (DEV-009). '
    + '§5: mô tả niêm phong `store.sqlite.seal.json` mà PROJECT-02 bước 2 đòi nhưng chưa tài '
    + 'liệu nào định nghĩa (DEV-007).'],
   ['1.2', '07/09/2026', 'Vũ Trí Công',
    '§5: thêm dòng `0003b_m1_session` cho `session.sqlite`. §2 khai Phiên làm việc ở tệp ấy và '
    + 'MEM-11 §2 xếp M2 vào đó, nhưng bảng lịch §5 chỉ có dòng cho `index.sqlite` — nên đọc riêng '
    + '§5 sẽ tưởng bảng `session` bị bỏ sót khỏi store chính (DEV-006).'],
   ['1.3', '07/09/2026', 'Vũ Trí Công',
    '§5: chia rõ bảng TRI THỨC (được niêm phong) và bảng VẬN HÀNH (decision_log, capability_run, '
    + 'run, intent, error_ledger — không niêm, đối chiếu bằng nhật ký). Năm bảng ấy đổi ở mỗi lời '
    + 'gọi năng lực nên đưa vào niêm thì phải niêm lại liên tục, và một niêm phong viết lại liên '
    + 'tục thì không còn là niêm phong (DEV-047).'],
   ['1.4', '07/09/2026', 'Vũ Trí Công',
    '§5: `user_version` của `0004_m2_engineering_hw` sửa 3 → 4 và `0005_m3_debug` sửa 4 → 5; thêm quy tắc `user_version` LUÔN bằng số hiệu tệp migration chạy sau cùng của store chính, còn số hiệu cấp cho cơ sở dữ liệu riêng (0003 index, 0003b session) bị bỏ trống trong dãy một cách cố ý. Với cách đếm số migration đã chạy, bất kỳ số hiệu nào bị một cơ sở dữ liệu riêng dùng tiếp về sau đều làm lệch toàn bộ phiên bản phía sau (DEV-056).'],
   ['1.5', '22/09/2026', 'Vũ Trí Công',
    '§2: thêm trường `Fact.run_id` — LƯỢT CHẠY đã tạo fact này (migration 0010, chỉ mục '
    + '`ix_fact_3`). `source_id` trả lời "fact rút từ tài liệu nào"; nó KHÔNG trả lời "lượt '
    + 'trích xuất nào đã rút nó ra", và một tài liệu đúng vẫn có thể bị một lượt đọc sai. '
    + 'Thiếu cột này thì 18 năng lực khai hoàn tác `supersede_facts` không cái nào hoàn tác '
    + 'nổi: câu đầu tiên của thủ tục POL-17 §5 — "với mỗi fact tự duyệt CỦA LƯỢT NÀY" — không '
    + 'có chỗ nào để hỏi (DEV-170). '
    + '§2: thêm hai thực thể `Clarification` và `ClarificationAnswer` của DEV-151. Chúng đã có '
    + 'trong kho từ migration 0008/0009 nhưng chỉ tồn tại dưới dạng SQL viết tay CHÈN vào cuối '
    + '`data/schema.sql` — mà tệp ấy là bản SINH, nên ai chạy lại `gen_ddd.py` là xoá sạch hai '
    + 'bảng mà không cổng nào kêu (DEV-170). '
    + '§5: bổ sung bốn dòng migration 0007…0010 đã có trong kho nhưng bảng lịch chưa ghi, và '
    + 'bỏ dòng "(M3) debug_session — chưa có migration" nay đã sai. Bảng này mô tả migration ĐÃ '
    + 'CÓ; thiếu một dòng nghĩa là tài liệu và `eide migrate` nói hai điều khác nhau về cùng '
    + 'một store (DEV-170).']]);
const c = [];
c.push(H1('1. Nguyên tắc và quy ước'));
c.push(P('Tài liệu này được sinh từ một mô hình duy nhất (`ddd_model.py`); mọi thay đổi schema phải sửa mô hình rồi sinh lại JSON Schema, DDL và tài liệu — không sửa tay ba nơi. Quy ước: (1) mọi id có tiền tố loại + 16 hex (f_, src_, cr_, d_, r_, it_, dg_, doc_, dv_, e_, m_, tr_, ds_, cu_, acq_), trừ id có nghĩa (F-nn, ADR-nn, UR-/FR-, passport ns.part@semver, module mod_<slug>); (2) IRI subject theo KAD-07 §6.1: `chip:<vendor>.<part>[/periph:X[/reg:Y[/field:Z]]]`, `board:<id>[/net:N|/pin:P]`, `part:<vendor>.<mpn>`, `isa:<id>`; (3) cột JSON lưu TEXT (UTF-8) và được kiểm bằng JSON Schema tương ứng trước khi ghi; (4) thời gian ISO-8601 UTC; (5) mọi bảng có cột `at` hoặc `created_at` để dòng thời gian (view.timeline); (6) SQLite WAL, foreign_keys=ON, user_version tăng theo migration; (7) ba tệp cơ sở dữ liệu: `store.sqlite` (commit Git), `session.sqlite` (không commit), `index/index.sqlite` (không commit, tái dựng được).'));
c.push(H1('2. Từ điển dữ liệu'));
for (const e of D.entities) {
  c.push(H2(`2.${D.entities.indexOf(e) + 1}. ${e.name} — bảng \`${e.table}\`${e.layer ? ' · lớp ' + e.layer : ''} · từ ${e.since}`));
  c.push(P(e.desc + (e.pk.startsWith('(') ? ` Khóa chính: ${e.pk}.` : '') + (e.indexes.length ? ` Chỉ mục: ${e.indexes.join('; ')}.` : '')));
  c.push(T([1700, 1100, 2300, 700, 3500], ['Trường', 'Kiểu JSON', 'SQL', 'Bắt buộc', 'Mô tả / giá trị cho phép'], e.fields.map(f => [f[0], f[1], f[2], f[3] ? '✓' : '', (f[4] || '') + (f[5] ? ` — {${f[5].filter(x => x).join(', ')}}` : '')]), { size: 18 }));
  c.push(SP());
}
c.push(H1('3. JSON Schema'));
c.push(P('27 tệp `data/json/<table>.json` theo JSON Schema 2020-12 [24], `additionalProperties: false`, enum đúng như bảng trên. Ví dụ `decision_log.json` (rút gọn):'));
c.push(...CODE(JSON.stringify(JSON.parse(fs.readFileSync('data/json/decision_log.json', 'utf8')), null, 1).split('\n').slice(0, 40)));
c.push(SP());
c.push(P('Các schema đầu ra của vai trò (Plan, CodePatch, Review, Diagnosis, ReqSet, ModuleGraph, HwMap, ADR, DocSections, Diagram, NetProposal, Candidates, MissingList, Intent, Chain, ContextBundle) tuân thủ mẫu số chung (sâu ≤ 3, không anyOf/$ref) và được đặt cùng thư mục với tiền tố `out_`; PRS-16 §4 và DPS-09 §4.1 liệt kê nội dung; DDD-14 giữ bản chính thức.'));
c.push(H1('4. DDL SQLite'));
c.push(P('Tệp `data/schema.sql` (đã kiểm bằng sqlite3: 32 bảng kể cả FTS5). Trích:'));
c.push(...CODE(fs.readFileSync('data/schema.sql', 'utf8').split('\n').slice(0, 45)));
c.push(SP());
c.push(H1('5. Di trú'));
c.push(T([2200, 900, 6200], ['Migration', 'Mốc', 'Nội dung'], D.migrations));
c.push(SP());
c.push(P('**`user_version` LUÔN bằng số hiệu tệp migration chạy sau cùng của store chính**, không phải số lượng migration đã chạy. Các số hiệu cấp cho cơ sở dữ liệu riêng (`0003_m1_index` cho `index.sqlite`, `0003b_m1_session` cho `session.sqlite`) bị bỏ trống trong dãy này một cách cố ý, nên `0004_m2_engineering_hw` đặt `user_version=4` chứ không phải 3. Quy tắc đồng nhất ấy làm `PRAGMA user_version` của một store bất kỳ đủ để biết tệp nào chạy sau cùng; cách đếm thì phải biết thêm tệp nào thuộc dãy store và tệp nào là cơ sở dữ liệu bên cạnh — và bất kỳ số hiệu nào bị một cơ sở dữ liệu riêng dùng tiếp về sau đều làm LỆCH toàn bộ phiên bản phía sau. Xem DEVIATIONS DEV-056.'));
c.push(P('Quy trình: `eide migrate` đọc `PRAGMA user_version`, chạy tuần tự các migration còn thiếu trong một giao dịch, ghi ledger `store.migrate`; sao lưu `store.sqlite.bak-<version>` trước khi chạy; migration chỉ thêm bảng/cột (không xóa) cho tới v1.0; đổi tên `.hkw` → `.eide` làm ở tầng đường dẫn, giữ symlink một mốc.'));
c.push(SP());
c.push(P('**Niêm phong toàn vẹn `store.sqlite.seal.json`.** CDS-12.3 PROJECT-02 bước 2 đòi "kiểm hash store vs ledger.last_hash → lệch: E6000" nhưng không nói hash ấy tính thế nào hay lưu ở đâu. Niêm phong là một tệp cạnh store, ghi `{content_hash, ledger_last_hash, user_version, at}`, cập nhật sau mỗi lần ghi đi qua cổng (hiện tại: `migrate`). `content_hash` băm **nội dung logic** — các bảng theo tên, các dòng đã sắp — chứ không băm byte của tệp: SQLite ở chế độ WAL đổi byte tệp sau mỗi lần mở, và `VACUUM` viết lại toàn bộ mà không đổi một dữ liệu nào, nên băm byte sẽ báo E6000 mỗi lần mở dự án và người dùng sẽ học cách bỏ qua nó. Sự kiện ledger `store.write` (API-15 §7) mang thêm trường `hash` để nối bản ghi với niêm phong. Xem DEVIATIONS DEV-007.'));
c.push(SP());
c.push(P('**Bảng TRI THỨC và bảng VẬN HÀNH — niêm phong chỉ phủ loại thứ nhất.** `content_hash` của niêm phong băm các bảng tri thức (fact, source, passport, code_unit, feature, requirement, diagram, preference, permission, acq_request, capability) và **bỏ qua** năm bảng ghi chép vận hành: `decision_log`, `capability_run`, `run`, `intent`, `error_ledger`. Lý do: năm bảng ấy đổi ở MỖI lời gọi năng lực, theo đúng thiết kế, nên đưa chúng vào niêm thì phải niêm lại sau từng lời gọi — và một niêm phong phải viết lại liên tục thì không còn là niêm phong; mở dự án sau bất kỳ hoạt động nào cũng sẽ báo E6000 cho một kho hoàn toàn lành. Bỏ ra không mất bảo vệ: mọi quyết định cũng vào nhật ký `gate.decision`, mà nhật ký là chuỗi băm nối tiếp — mạnh hơn một niêm phong đơn, nên ai sửa `decision_log` để giấu một quyết định vẫn lộ khi đối chiếu bảng với nhật ký. Một hệ quả có ích: xóa `decision_log` để dọn dẹp không làm hỏng niêm, tức người dùng dọn được lịch sử vận hành mà không mất khả năng kiểm tra tri thức. Xem DEVIATIONS DEV-047.'));
c.push(SP());
c.push(H1('6. Schema các tệp YAML'));
c.push(T([2200, 2400, 3900, 800], ['Tệp', 'Vai trò', 'Khóa chính', 'Từ'], D.yaml));
c.push(SP());
c.push(P('Mỗi tệp YAML có JSON Schema tương ứng trong `data/json/yaml_<tên>.json` (autonomy: POL-17 §4; capabilities: SDD-04 §4.0; isa: TGT-19; manifest: PKG-22). Daemon kiểm hợp lệ khi nạp; lỗi schema → từ chối mở dự án với thông báo dòng/cột.'));
c.push(H1('7. Quan hệ chính'));
c.push(...CODE([
  'source 1—n fact ; fact n—n passport (passport_fact) ; fact —supersedes→ fact',
  'code_unit —cites→ fact ; code_unit —uses→ subject IRI ; code_unit n—1 module ; module n—n resource (hw_map)',
  'requirement —trace→ module | code_unit | tc | doc_artifact ; feature —requirement_ids→ requirement',
  'intent 1—1 run ; run 1—n capability_run ; capability_run n—1 decision_log ; decision_log —undone_at',
  'tool_report / measurement / debug_session —evidence→ feature ; discovery → target.yaml',
  'diagram —source_ref→ module | hw_map | adr | plan ; doc_artifact —sections.citations→ fact | source',
  'rag_chunk n—1 source ; rag_chunk —graph_nodes→ subject IRI',
]));
c.push(SP());
c.push(H1('8. Kiểm thử'));
c.push(T([1000, 3500, 3600, 1200], ['TC', 'Mục tiêu', 'Kỳ vọng', 'Mức'], [
  ['TC-DD-01', 'DDL hợp lệ', 'schema.sql chạy trên SQLite trống → 32 bảng; PRAGMA foreign_key_check rỗng', 'L1'],
  ['TC-DD-02', 'JSON Schema ↔ pydantic', 'Mọi model pydantic sinh schema tương đương (so bằng jsonschema-diff) với data/json', 'L1'],
  ['TC-DD-03', 'Ghi sai schema bị chặn', 'Ghi fact với predicate ngoài enum → lỗi tại cổng ghi, không có dòng mới', 'L1'],
  ['TC-DD-04', 'Migration tuần tự', 'store v1 (M0) → migrate → user_version 4; dữ liệu M0 nguyên vẹn; bản sao lưu tồn tại', 'L1'],
  ['TC-DD-05', 'Ba tệp DB tách bạch', 'Xóa index/ và session.sqlite → dự án vẫn mở; index tái dựng bằng view.rag_index', 'L1'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-DDD-14_Tu_dien_du_lieu.docx');
