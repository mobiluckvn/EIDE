const { P, H1, H2, SP, T, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const m = metaNew('EIDE-DEV-29', 'Quy trình phát triển cùng Claude Code', 'QUY TRÌNH PHÁT TRIỂN CÙNG CLAUDE CODE (DEV)',
  'Nguyên tắc "đọc tài liệu và phát triển", vòng lặp chuẩn, nhật ký sai khác và đồng bộ tài liệu định kỳ, cấu trúc kho, lệnh và hook cho Claude Code, chiến lược ba nền tảng (macOS trước, Windows, Linux), sprint đầu tiên',
  [['Tài liệu trước', 'Toàn bộ bộ hồ sơ v1.2; đặc biệt PLN-27 (backlog), STP-05 (kiểm thử), DEP-26 (triển khai), SEC-25 (an toàn)'], ['Dùng khi', 'Mở kho mã `eide` lần đầu; mỗi phiên làm việc với Claude Code; mỗi lần đồng bộ tài liệu'], ['Kho mã', 'eide (viết mới hoàn toàn theo v1.2; không kế thừa mã hkw-core M0 — DEVIATIONS DEV-003)']],
  'Phát hành lần đầu — bổ sung theo yêu cầu bắt đầu phát triển cùng Claude Code');
const c = [];
c.push(H1('1. Vấn đề và nguyên tắc'));
c.push(P('Bộ hồ sơ v1.2 có 31 tài liệu, 238 năng lực có hợp đồng, 46 quy tắc chính sách, 55 phương thức API, 27 thực thể dữ liệu — đủ chi tiết để một tác tử lập trình (Claude Code [68], [18]) hiện thực mà không phải tự nghĩ ra hành vi. Rủi ro lớn nhất khi phát triển bằng tác tử không phải là viết sai cú pháp mà là **trôi khỏi tài liệu**: tác tử tự đặt tên khác, tự thêm trường, tự đổi mã lỗi, tự "sửa cho chạy" rồi tài liệu và mã không còn khớp. Vì thế quy trình đặt một nguyên tắc duy nhất và ba hệ quả.'));
c.push(P('**Nguyên tắc: đọc tài liệu rồi mới phát triển.** Hệ quả 1 — *tài liệu là nguồn sự thật*: mọi hành vi trong mã truy vết được về một mục tài liệu hoặc một tệp đặc tả máy đọc được (`docs/spec/`). Hệ quả 2 — *sai khác phải được ghi lại*: khi mã buộc phải khác tài liệu (tài liệu sai, thiếu, mâu thuẫn, không khả thi trên nền tảng), tác tử ghi một mục vào `docs/DEVIATIONS.md` trước khi commit, không sửa im lặng. Hệ quả 3 — *tài liệu được cập nhật định kỳ từ nhật ký sai khác*, bằng cách sửa nguồn sinh (`docs/ho-so/nguon/`) rồi sinh lại, vì tài liệu của EIDE là mã (ADR-12, SAD-03).'));
c.push(P('Ba nền tảng đích là macOS (Intel x86_64 và Apple Silicon arm64), Windows và Linux; thứ tự thực hiện là macOS trước. Quy tắc đa nền tảng đặt trong `docs/PLATFORM.md` và được ruff (bộ quy tắc PTH) cùng CI kiểm tự động.'));

c.push(H1('2. Hai tầng tài liệu trong kho mã'));
c.push(P('Kho `eide` mang hai bản của cùng một bộ hồ sơ. `docs/ho-so/` là bản đọc cho người (31 docx, 4 Excel) kèm `nguon/` để sinh lại. `docs/spec/` là bản máy đọc được, dùng trực tiếp lúc chạy và lúc kiểm thử: `cds.json` (238 hợp đồng đầy đủ), `capabilities/<ns>.yaml`, `policy/rules.yaml` + `situations.jsonl` + `defaults.yaml`, `prompts/*.md`, `api/openrpc.json` + `mcp_tools.json` + `errors.json` + `ledger_events.json`, `data/schema.sql` + `json/*.json`, `isa/*.yaml`. Registry nạp `cds.json` lúc khởi động; PolicyGate nạp `rules.yaml`; lớp lỗi từ chối mọi mã không có trong `errors.json`; test đối chiếu (`tests/test_specs_consistency.py`) bảo đảm mã không thể lệch spec mà CI vẫn xanh.'));
c.push(T([2200, 3900, 3200], ['Việc', 'Đọc trước (docx)', 'Đặc tả máy đọc được'], [
  ['Hiện thực một năng lực', 'CDS-12.x (tập theo nhóm), SDD-04 §4', 'capabilities/<ns>.yaml, cds.json'],
  ['Cổng và quyết định', 'APD-08, POL-17', 'policy/rules.yaml, situations.jsonl, defaults.yaml'],
  ['Hiểu lệnh, điều phối', 'DPS-09, PRS-16, CXD-10', 'prompts/*.md'],
  ['Dữ liệu', 'DDD-14, MEM-11', 'data/schema.sql, data/json/'],
  ['API, lỗi, sự kiện', 'API-15', 'api/*.json'],
  ['Chip, toolchain, dò board', 'TGT-19', 'isa/*.yaml'],
  ['Giao diện', 'UXD-13, GPI-23', 'docs/ui/*.dc.html'],
]));
c.push(SP());
c.push(P('Bản đồ đầy đủ "việc → tài liệu" nằm ở `docs/INDEX.md`; Claude Code bắt buộc đọc tệp này đầu mỗi phiên (lệnh `/bat-dau`).'));

c.push(H1('3. Vòng lặp chuẩn cho một việc'));
c.push(P('Một việc là một năng lực (`ns.name`) hoặc một hạng mục hạ tầng WI trong PLN-27. Vòng lặp gồm bảy bước và được mã hóa thành lệnh `/thuc-hien <ns.name>` để tác tử không bỏ bước.'));
c.push(T([700, 3200, 5400], ['#', 'Bước', 'Bằng chứng / công cụ'], [
  ['1', 'Đọc hợp đồng và tài liệu liên quan', '`/doc-nang-luc` in input/output schema, steps, errors, undo, tc, quy tắc POL cùng cổng, entity DDD, phương thức RPC, bước use case (sheet 11)'],
  ['2', 'Viết test trước', 'Mỗi câu trong trường `tc` và mỗi mã lỗi trong `errors` → ≥ 1 test; gọi qua `Router.invoke` để cổng và ledger được kiểm'],
  ['3', 'Hiện thực handler', '`@capability("ns.name")` trong `src/eide/caps/<ns>.py`; docstring dòng đầu `Spec: <CODE> — CDS-12.x; POL-17 …; DDD-14 …`'],
  ['4', 'Kiểm đa nền tảng', '`pathlib`, tiến trình con dạng danh sách, công cụ ngoài qua `eide_core.tools.which`; `/nen-tang`'],
  ['5', 'Kiểm tra', '`make check` = ruff + đối chiếu spec + pytest; phải xanh'],
  ['6', 'Ghi sai khác (nếu có)', '`/sai-khac` → DEV-xxx trong `docs/DEVIATIONS.md`, trạng thái Mở'],
  ['7', 'Cập nhật sprint và commit', 'Dòng trong `docs/SPRINT-01.md` (trạng thái, nền tảng đã kiểm, DEV); commit `[<CODE>] ns.name: …` với phần thân `Đọc: …` và `Sai khác: …`'],
]));
c.push(SP());
c.push(P('Router là điểm gọi duy nhất: kiểm tham số theo `input_schema` (E1000), hỏi PolicyGate theo cổng của năng lực và lớp rủi ro, ghi `cap.run.start`, chạy handler, kiểm kết quả theo `output_schema`, ghi `cap.run.finish`. Quyết định ASK không phải lỗi: lời gọi vào hàng đợi với trạng thái `pending` (API-15 E3000). Nhờ vậy test của từng năng lực đồng thời là test của chính sách và nhật ký.'));

c.push(H1('4. Nhật ký sai khác và đồng bộ tài liệu'));
c.push(P('`docs/DEVIATIONS.md` là bảng có tám cột: mã DEV, ngày, tài liệu và mục, mã nguồn, sai khác, lý do, đề xuất, trạng thái. Trạng thái đi từ `Mở` sang `Đã duyệt` (chủ sản phẩm đồng ý sửa tài liệu) hoặc `Bác` (sửa mã cho khớp tài liệu), rồi `Đã cập nhật tài liệu vX.Y`. Ba mục đã có ngay từ ngày đầu minh họa cách dùng: DEV-001 (rules.yaml tham chiếu ngưỡng nhưng giá trị mặc định không ở một chỗ → thêm `defaults.yaml`), DEV-002 (thiếu mã lỗi cho kết quả năng lực sai schema → tạm dùng E6001, đề xuất E1004), DEV-003 (kho viết mới, không kế thừa hkw-core → sửa WI-001, thêm ADR-16).'));
c.push(P('Đồng bộ tài liệu chạy cuối mỗi sprint hoặc khi có từ năm mục Mở trở lên: lệnh `/dong-bo-tai-lieu` gom các mục theo tài liệu thành bản nháp `docs/sync/<ngày>-<DOC>.md` (mục bị ảnh hưởng, nội dung hiện tại, nội dung đề xuất, tệp nguồn sinh phải sửa, phiên bản đích). Tác tử **không** tự sửa docx hay `docs/spec/` trong bước này. Sau khi chủ sản phẩm duyệt, nguồn sinh được sửa (`<ten>.js`, `cds_data_*.py`, `rules.yaml`…), tài liệu sinh lại, bản mới chép vào `docs/spec/`, và mục DEV đổi trạng thái. Hook `PreToolUse` chặn việc sửa trực tiếp docx/xlsx và các tệp sinh (`cds.json`, `caps.json`, `ddd.json`), nhắc quy tắc khi sửa bất kỳ tệp nào trong `docs/spec/`.'));

c.push(H1('5. Cấu trúc kho và những gì đã chạy'));
c.push(...CODE([
  'eide/',
  '  CLAUDE.md                  # hướng dẫn cho Claude Code (nguyên tắc, vòng lặp, cấu trúc, nền tảng, khi nào hỏi người)',
  '  .claude/commands/          # /bat-dau /doc-nang-luc /thuc-hien /sai-khac /kiem-tra /nen-tang /dong-bo-tai-lieu',
  '  .claude/settings.json      # quyền và hook: guard_spec (PreToolUse), after_edit (PostToolUse), on_stop (Stop)',
  '  docs/INDEX.md DEVIATIONS.md SPRINT-01.md PLATFORM.md decisions/ADR-000-mau.md',
  '  docs/spec/ (chuẩn máy đọc)  docs/ho-so/ (31 docx, 4 xlsx, nguon/)  docs/ui/ (23 mockup)',
  '  src/eide_core/ paths errors registry policy ledger router tools',
  '  src/eide/ cli.py daemon/rpc.py caps/{project,env,policy}.py',
  '  tests/ 7 tệp, 36 test (registry, policy, ledger, project, env+policy, rpc, đối chiếu spec)',
  '  scripts/ spec_status new_deviation validate_specs uc_steps setup-mac.sh hooks/',
  '  .github/workflows/ci.yml   # macos-13 (Intel), macos-14 (Apple Silicon) bắt buộc; windows, ubuntu allow-failure',
  '  pyproject.toml Makefile README.md plugins/geditor/README.md',
]));
c.push(SP());
c.push(P('Trạng thái sau ngày đầu: registry nạp 238 năng lực / 27 nhóm từ spec; PolicyGate biên dịch 46 quy tắc với bộ đánh giá biểu thức an toàn (chỉ so sánh, logic, `in`, thuộc tính — không gọi hàm), năm tầng quyết định (dừng khẩn → ngưỡng cứng lớp rủi ro × mức tự chủ → quy tắc theo cổng → quy tắc chung → mức năng lực T1/T1*/T2/T3 và người gọi trực tiếp); ledger chuỗi hash SHA-256 với kiểu sự kiện lấy từ API-15; sáu năng lực đã hiện thực và kiểm (project.create, project.list, env.detect, env.check, policy.emergency_stop, policy.set_autonomy); CLI `eide doctor | caps list/describe/invoke | project new/list | policy stop/set | spec | daemon`; daemon JSON-RPC 2.0 qua stdio với 9/55 phương thức. `make check` xanh trên Linux (môi trường soạn thảo); việc đầu tiên trên máy Mac là chạy `bash scripts/setup-mac.sh && make check` để ghi nền tảng thật vào SPRINT-01.'));

c.push(H1('6. Chiến lược ba nền tảng'));
c.push(T([2600, 1400, 2600, 2700], ['Nền tảng', 'Thứ tự', 'CI', 'Điểm cần chú ý (PLATFORM.md)'], [
  ['macOS 13+ Intel', '1', 'macos-13, bắt buộc', 'Homebrew ở /usr/local; toolchain ARM qua cask gcc-arm-embedded'],
  ['macOS 14+ Apple Silicon', '1', 'macos-14, bắt buộc', 'Homebrew ở /opt/homebrew; binary x86_64 qua Rosetta; renode/simavr chọn bản arm64'],
  ['Windows 11', '2', 'windows-latest, allow-failure', 'Cổng COMn; đường dẫn Program Files; winget; dịch vụ nền theo Task Scheduler (DEP-26)'],
  ['Linux (Ubuntu 22.04+)', '3', 'ubuntu-latest, allow-failure', 'udev cho probe; systemd; apt'],
]));
c.push(SP());
c.push(P('Bảy quy tắc mã đa nền tảng (pathlib, tiến trình con dạng danh sách, cổng nối tiếp chuẩn hóa theo OS, dịch vụ nền theo OS, không phụ thuộc kiến trúc CPU máy chủ, test không phần cứng chạy trên cả ba OS, năng lực chỉ chạy trên Mac phải ghi rõ) được kiểm bởi ruff PTH, bởi lệnh `/nen-tang` và bởi ma trận CI. Một năng lực chỉ được đánh dấu "Xong" khi cột Nền tảng trong SPRINT ghi nền tảng đã chạy test thật.'));

c.push(H1('7. Sprint 1 và cách giao việc cho Claude Code'));
c.push(P('SPRINT-01 ("xương sống chạy được trên Mac", hai tuần) lấy từ mốc M1 của PLN-27: hạ tầng WI-001/003/004/008/010 đã có bản đầu; còn WI-002 (SQLite store + migration), WI-007 (bộ nhớ M1/M2), WI-009 (sandbox), WI-013 (prompt và Gateway LLM); năng lực còn lại project.open/status/preferences, memory.progress/summarize_session, policy.decide/undo_window/escalate, env.lock/sandbox, report.progress; hai việc của người (WI-257 ký danh sách trắng, WI-258 xác nhận màu PTIT và ngôn ngữ lược đồ GEditor). Sprint 2 là Orchestrator (WI-005), ToolForge tool.* (WI-020) và MCP (WI-011).'));
c.push(P('Phiên làm việc điển hình: mở kho bằng `claude`, gõ `/bat-dau` — tác tử đọc CLAUDE.md và INDEX, chạy `spec_status`, đọc SPRINT và DEVIATIONS, đề xuất một việc kèm tài liệu sẽ đọc và tiêu chí xong; chủ sản phẩm xác nhận; `/thuc-hien <ns.name>`; khi xong `/kiem-tra` in báo cáo năm dòng. Chủ sản phẩm chỉ cần trả lời khi tác tử hỏi ở ba trường hợp trong CLAUDE.md (tài liệu mâu thuẫn chưa có DEV, cần thư viện/dịch vụ trả phí, thay đổi ảnh hưởng từ ba nhóm năng lực trở lên) và duyệt DEVIATIONS mỗi tuần.'));

c.push(H1('8. Tiêu chí chấp nhận quy trình'));
c.push(T([600, 8700], ['#', 'Tiêu chí'], [
  ['1', 'Mọi commit trong `src/` có phần thân `Đọc: …` và `Sai khác: DEV-xxx | không`; `git log --grep "Đọc:"` bằng số commit trong src/'],
  ['2', '`tests/test_specs_consistency.py` xanh liên tục: mã lỗi ⊆ errors.json, phương thức RPC ⊆ openrpc.json, @capability ⊆ cds.json, docstring có `Spec:`'],
  ['3', 'Không mục DEVIATIONS `Mở` quá 7 ngày; sau mỗi đồng bộ, phiên bản tài liệu tăng (v1.3, v1.4…) và `docs/spec/` được sinh lại từ nguồn'],
  ['4', 'CI xanh trên macos-13 và macos-14 cho mọi PR; Windows/Linux không đỏ quá một sprint'],
  ['5', 'SPRINT-xx ghi nền tảng thật cho từng dòng "Xong"'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-DEV-29_Quy_trinh_phat_trien_Claude_Code.docx');
