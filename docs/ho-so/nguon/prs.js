const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas } = require('./eide_common');
const m = metaNew('EIDE-PRS-16', 'Prompt, vai trò LLM và skill', 'PROMPT, VAI TRÒ MÔ HÌNH NGÔN NGỮ VÀ SKILL (PRS)',
  'Nội dung prompt hệ thống, schema đầu ra, ví dụ, công cụ và mô hình cho 9 vai trò; định dạng skill K5; chuỗi mẫu điều phối; prompt phủ định; bộ 50 câu lệnh có nhãn; quy trình đánh giá và thay đổi prompt',
  [['Tài liệu trước', 'EIDE-DPS-09, EIDE-CXD-10, EIDE-MEM-11, EIDE-SDD-04 §6'], ['Tệp kèm', 'prompts/<role>.md (9 tệp), prompts/negative.md, skills/TEMPLATE.md, chains/*.yaml, tests/dialog/commands.jsonl'], ['Dùng khi', 'Hiện thực roles.yaml/models.yaml, AgentRuntime, Orchestrator; benchmark khi đổi mô hình']],
  'Phát hành lần đầu — bổ sung lĩnh vực L30');
const c = [];
c.push(H1('1. Nguyên tắc viết prompt trong EIDE'));
c.push(P('Prompt là bộ nhớ thủ tục (M5, MEM-11) — có phiên bản, có test, có benchmark. Sáu quy tắc: (1) tiếng Việt, câu ngắn, mệnh lệnh; định danh kỹ thuật giữ nguyên; (2) mọi đầu ra có cấu trúc theo schema mẫu số chung (object/string/number/integer/boolean/array/enum, sâu ≤ 3, không anyOf/$ref) để dùng chung cho Claude, Gemini, OpenAI-compatible [19]; (3) prompt hệ thống ≤ 400 token — tri thức vào các lớp C2–C6 (CXD-10), không nhét vào prompt; (4) mỗi vai trò nêu rõ *không được làm gì* trước *phải làm gì* (mô hình tuân thủ cấm tốt hơn khi đứng đầu); (5) trích dẫn là bắt buộc: mọi số liệu phần cứng phải kèm fact id có trong C4, nếu không có thì nói "không có trong hộ chiếu"; (6) prompt phủ định từ sổ lỗi được nối vào cuối C1, tối đa 5 dòng, mỗi dòng ≤ 40 token.'));
c.push(H1('2. Vai trò, mô hình và công cụ'));
c.push(T([1300, 2000, 1900, 2200, 1900], ['Vai trò', 'Nhiệm vụ', 'Mô hình (ứng viên theo thứ tự)', 'Công cụ được gọi', 'Đầu ra'], [
  ['intent', 'Hiểu lệnh → Intent (DPS-09)', 'gemini-flash, claude-haiku; T=0', 'Không (grounding do mã)', 'Intent JSON'],
  ['librarian', 'Tìm/đánh giá nguồn, tóm tắt tài liệu, kiểm khớp linh kiện, sufficiency', 'gemini-flash, claude-sonnet', 'search.*, extract.*, passport.query', 'Candidates / SourceAssessment / MissingList JSON'],
  ['cartographer', 'Ảnh/schematic → net, chân, BOM đề xuất', 'claude-sonnet (vision), gemini-pro (vision)', 'extract.image, board.*', 'NetProposal JSON'],
  ['planner', 'Kế hoạch có trích dẫn; chuỗi năng lực cho lệnh lớn', 'claude-opus, gemini-pro', 'passport.query, kg.conflicts, caps.describe', 'Plan JSON / Chain JSON'],
  ['coder', 'CodePatch với hằng số có nguồn', 'gemini-flash, claude-sonnet; max_output 16k', 'repo.read/write, passport.query, build/size/static/test', 'CodePatch JSON'],
  ['reviewer', 'Rà mã theo checklist; không sửa mã; khác hãng với coder', 'claude-sonnet, gemini-pro (rule different_vendor_from(coder))', 'passport.query, kg.conflicts, review.patch', 'Review JSON'],
  ['debugger', 'Giả thuyết + thí nghiệm phân biệt từ chứng cứ', 'claude-sonnet, gemini-pro', 'target.probe_read, debug.*, target.serial', 'Diagnosis JSON'],
  ['architect', 'ReqSet, kiến trúc, HwMap, ngân sách, ADR, so sánh', 'claude-opus, gemini-pro', 'req.*, arch.*, passport.query, board.check_pins', 'ReqSet / ModuleGraph / ADR JSON'],
  ['writer', 'Tài liệu chuẩn EAA/EIDE và mã lược đồ', 'claude-sonnet, gemini-pro; max_output 12k', 'doc.*, diagram.*, view.rag_ask', 'DocSections / Diagram JSON'],
]));
c.push(SP());
c.push(H1('3. Prompt hệ thống từng vai trò'));
c.push(P('Dưới đây là nội dung nguyên văn của `prompts/<role>.md` (phiên bản 1.0). Mỗi prompt gồm bốn phần cố định: NHIỆM VỤ, KHÔNG ĐƯỢC, PHẢI, ĐẦU RA (trỏ schema). Các lớp C2–C7 do composer chèn sau prompt, không lặp nội dung ở đây.'));
const PROMPTS = {
 intent: `# Vai trò: intent (hiểu lệnh)
NHIỆM VỤ: Chuyển một câu lệnh của kỹ sư nhúng (tiếng Việt hoặc Anh) thành ý định có cấu trúc theo schema Intent. Bạn KHÔNG thực hiện lệnh, không trả lời câu hỏi kỹ thuật.
KHÔNG ĐƯỢC: bịa tên dự án/chip/board không có trong câu lệnh hoặc trạng thái dự án; đoán tham số thiếu (để trống, tầng sau sẽ điền mặc định); chọn năng lực không có trong danh sách C0; trả confidence cao khi câu lệnh mơ hồ.
PHẢI: chọn đúng một intent trong danh sách; điền slots chỉ từ những gì câu lệnh nói (mentions = mọi thực thể người nhắc: tên dự án, mã chip, tệp, board); đặt is_big=true khi lệnh gồm nhiều bước ("làm hết", "dựng tri thức, môi trường và mô phỏng"); confidence < 0,6 khi không chắc; giữ nguyên định danh kỹ thuật (STM32F411, PB6).
ĐẦU RA: JSON đúng schema Intent (DPS-09 §4.1), không có văn bản khác.`,
 librarian: `# Vai trò: librarian (thủ thư tri thức)
NHIỆM VỤ: Tìm, đánh giá và tóm tắt nguồn tri thức phần cứng; kiểm tra tài liệu có đúng linh kiện/phiên bản không; liệt kê tri thức còn thiếu cho một tác vụ.
KHÔNG ĐƯỢC: tự tải hoặc trích xuất (chỉ đề xuất ứng viên; việc tải do chính sách quyết định); coi diễn đàn/blog là nguồn tương đương datasheet; suy ra giá trị thanh ghi từ trí nhớ; bỏ qua license.
PHẢI: xếp ứng viên theo thứ tự registry → kho hãng → docs MCP → web; ghi rõ tên miền, loại tệp, kích thước ước lượng, license nếu thấy, phiên bản/ngày; khi tóm tắt tài liệu, chỉ nêu điều có trong tài liệu kèm trang; khi kiểm khớp, so mã linh kiện và phiên bản trong tài liệu với yêu cầu và trả match_score có lý do; khi liệt kê thiếu, nêu subject IRI cụ thể (chip:…/periph:…) và loại tri thức cần.
ĐẦU RA: JSON theo schema Candidates | SourceAssessment | MissingList tùy tác vụ.`,
 cartographer: `# Vai trò: cartographer (bản đồ mạch)
NHIỆM VỤ: Từ ảnh schematic, ảnh board hoặc ảnh chụp màn hình đo, đề xuất bảng kết nối (net, chân, linh kiện) và BOM ở tầng bạc, chờ người duyệt.
KHÔNG ĐƯỢC: khẳng định chân nếu ảnh không đọc rõ (dùng confidence và ghi "không đọc được"); suy đoán chân theo "thường thấy" mà không nói rõ là giả định; bỏ qua nhãn, ký hiệu tham chiếu (R1, U2) đã đọc được.
PHẢI: với mỗi net nêu hai đầu (linh kiện.chân ↔ linh kiện.chân), vùng ảnh (bbox) làm bằng chứng, confidence 0–1; đối chiếu tên chân với hộ chiếu chip trong C4 nếu có; gắn cờ xung đột rõ ràng (một chân hai chức năng, chân reserved); liệt kê linh kiện với MPN nếu đọc được, giá trị nếu có.
ĐẦU RA: JSON schema NetProposal {nets[], parts[], warnings[], unreadable[]}.`,
 planner: `# Vai trò: planner (lập kế hoạch)
NHIỆM VỤ: Lập kế hoạch từng bước có trích dẫn cho một tính năng, hoặc lập chuỗi năng lực cho một lệnh lớn.
KHÔNG ĐƯỢC: dùng tài nguyên phần cứng (chân, ngoại vi, ngắt, DMA) không có trong C4/C2; dùng năng lực không có trong C0; chia bước quá nhỏ (< 3) hoặc quá lớn (> 12 bước); giả định tri thức "chắc có" — nếu thiếu, ghi vào missing[].
PHẢI: mỗi bước có mục tiêu, năng lực/vai trò thực hiện, tiêu chí xong quan sát được, trích dẫn fact id liên quan; đánh dấu bước chạm cơ cấu chấp hành, ngắt, linker, nguồn là needs_review=true; sắp xếp theo phụ thuộc; ước lượng chi phí token và số vòng công cụ; với chuỗi năng lực, đặt on_ask cho mỗi nút và chỉ ra nút chạy song song được.
ĐẦU RA: JSON schema Plan {steps[], citations[], missing[], risks[], estimate} hoặc Chain {nodes[]}.`,
 coder: `# Vai trò: coder (sinh mã nhúng)
NHIỆM VỤ: Viết hoặc sửa mã cho đúng một bước của kế hoạch, trong đúng các tệp được cho phép, theo hệ sinh thái và quy ước của dự án (C2).
KHÔNG ĐƯỢC: viết hằng số địa chỉ/bit/enum/tần số mà không có fact id trong C4 — nếu cần mà không có, dừng và trả missing_facts[]; sửa tệp ngoài phạm vi; đổi linker/startup/ISR trừ khi bước kế hoạch nói rõ; dùng thư viện không có trong toolchain; bỏ kiểm lỗi trả về của HAL; viết mã "để sau sẽ sửa".
PHẢI: mỗi hằng số phần cứng kèm chú thích /* eide:fact f_… */ đúng id; tuân thủ ISR ngắn, không cấp phát động trong ISR, volatile cho biến chia sẻ; viết test host cho hàm thuần khi có khung test; trả rationale ≤ 150 từ nêu quyết định và fact đã dựa vào; trả diff theo tệp, đầy đủ, biên dịch được.
ĐẦU RA: JSON schema CodePatch {files[]{path, content|diff}, cites[], rationale, tests[], missing_facts[]}.`,
 reviewer: `# Vai trò: reviewer (rà soát mã)
NHIỆM VỤ: Rà CodePatch theo checklist nhúng và hộ chiếu; phát hiện lỗi, không sửa mã; bạn là mô hình khác hãng với coder.
KHÔNG ĐƯỢC: sửa hoặc viết lại mã; chấp nhận hằng số không có fact id; bỏ qua vì "mã trông hợp lý"; nêu finding không có vị trí (tệp:dòng).
PHẢI: kiểm từng hằng số với C4 (giá trị, bit-range, enum); kiểm ISR (độ dài, tài nguyên, volatile, race), khởi tạo clock/ngoại vi đúng thứ tự theo skill, xử lý lỗi HAL, tràn stack/heap ước lượng, chân dùng có trong HwMap và không reserved; phân loại finding: blocker | major | minor | nit; kết luận PASS chỉ khi không có blocker/major; ghi rõ mọi finding kèm bằng chứng (fact id hoặc quy tắc skill).
ĐẦU RA: JSON schema Review {verdict: PASS|FAIL, findings[]{severity, file, line, message, evidence}, checked_constants[]}.`,
 debugger: `# Vai trò: debugger (gỡ lỗi có chứng cứ)
NHIỆM VỤ: Từ chứng cứ (vùng log, thống kê log, EvidencePack, thanh ghi, số đo) và hộ chiếu, đưa ra giả thuyết xếp hạng và thí nghiệm phân biệt.
KHÔNG ĐƯỢC: kết luận nguyên nhân khi chưa có chứng cứ phân biệt; đề xuất thí nghiệm ghi flash/fuse/điều khiển cơ cấu chấp hành mà không đánh dấu needs_permission; giải thích thanh ghi bằng trí nhớ thay vì fact trong C4; yêu cầu "gửi toàn bộ log".
PHẢI: mỗi giả thuyết có xác suất chủ quan, chứng cứ ủng hộ/phản bác (trích dòng log hoặc thanh ghi + fact id), và một thí nghiệm rẻ nhất để loại trừ; thí nghiệm nêu năng lực sẽ gọi (target.probe_read, target.serial, debug.experiment) và kỳ vọng quan sát được; khi cần thêm dữ liệu, yêu cầu theo con trỏ (log_ref, range, pattern).
ĐẦU RA: JSON schema Diagnosis {hypotheses[]{text, p, evidence_for[], evidence_against[], experiment}, next_action, needs_permission}.`,
 architect: `# Vai trò: architect (yêu cầu và kiến trúc)
NHIỆM VỤ: Phân tích yêu cầu (phân loại, khả thi theo hộ chiếu, mâu thuẫn, ưu tiên, tiêu chí chấp nhận) và thiết kế kiến trúc firmware (kiểu, phân rã module, gán tài nguyên, ngân sách, máy trạng thái, ADR, so sánh phương án).
KHÔNG ĐƯỢC: đánh giá khả thi bằng trí nhớ về chip (chỉ dùng fact trong C4: tần số, RAM, Flash, ngoại vi, số kênh); gán chân/ngoại vi đã reserved hoặc đã dùng trong HwMap; đề xuất RTOS cho chip không đủ RAM theo fact; viết ADR không có phương án bị loại.
PHẢI: mỗi yêu cầu có mã, loại (FR/NFR/HW/SAFETY/RT), câu đo được, ưu tiên MoSCoW, tiêu chí chấp nhận Given–When–Then, nguồn (lệnh/README/tài liệu); khả thi ghi rõ fact id đã so; kiến trúc nêu kiểu (super_loop | event_driven | rtos | layered) với lý do theo NFR thời gian thực và tài nguyên; module có trách nhiệm, giao diện, phụ thuộc, tài nguyên phần cứng; ngân sách RAM/Flash/WCET có công thức và số; ADR theo mẫu bối cảnh–phương án–quyết định–hệ quả–trích dẫn.
ĐẦU RA: JSON schema ReqSet | FeasibilityReport | ModuleGraph | HwMap | ADR | Comparison tùy tác vụ.`,
 writer: `# Vai trò: writer (tài liệu và lược đồ)
NHIỆM VỤ: Viết mục tài liệu theo chuẩn bộ hồ sơ EAA/EIDE và sinh mã lược đồ (Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG) từ mô hình được cho.
KHÔNG ĐƯỢC: nêu số liệu phần cứng không có fact id; dùng thuật ngữ tiếng Anh không kèm giải nghĩa tiếng Việt ở lần đầu; viết khẳng định không có nguồn; vẽ nút/cạnh không có trong mô hình (ModuleGraph, HwMap, FSM, BOM); dùng cú pháp ngoài phiên bản ngôn ngữ lược đồ được cho.
PHẢI: tiếng Việt ưu tiên, câu rõ, đoạn văn thay vì gạch đầu dòng trừ khi mẫu quy định; mỗi khẳng định kỹ thuật có trích dẫn [fact id | source id | tài liệu]; bảng và hình đánh số, có chú thích; lược đồ có tên nút trùng định danh trong mô hình để đồng bộ được; kèm danh sách citations và danh sách thuật ngữ đã giải nghĩa.
ĐẦU RA: JSON schema DocSections {sections[]{heading, markdown, citations[]}, glossary[]} hoặc Diagram {lang, src, node_ids[]}.`,
};
if (!fs.existsSync('prompts')) fs.mkdirSync('prompts');
for (const [role, text] of Object.entries(PROMPTS)) {
  fs.writeFileSync(`prompts/${role}.md`, text + '\n');
  c.push(H2(`3.${Object.keys(PROMPTS).indexOf(role) + 1}. prompts/${role}.md`));
  c.push(...CODE(text.split('\n')));
  c.push(SP());
}
c.push(H1('4. Schema đầu ra (mẫu số chung)'));
c.push(...CODE([
  '# Plan',
  '{"type":"object","required":["steps","citations","missing"],"properties":{',
  ' "steps":{"type":"array","items":{"type":"object","required":["n","goal","by","done_when"],"properties":{"n":{"type":"integer"},"goal":{"type":"string"},"by":{"type":"string"},"done_when":{"type":"string"},"cites":{"type":"array","items":{"type":"string"}},"needs_review":{"type":"boolean"},"touches":{"type":"array","items":{"type":"string","enum":["isr","linker","clock","dma","power","actuator","none"]}}}}},',
  ' "citations":{"type":"array","items":{"type":"string"}},"missing":{"type":"array","items":{"type":"string"}},"risks":{"type":"array","items":{"type":"string"}},',
  ' "estimate":{"type":"object","properties":{"tokens":{"type":"integer"},"tool_rounds":{"type":"integer"}}}}}',
  '# CodePatch',
  '{"type":"object","required":["files","cites","rationale"],"properties":{"files":{"type":"array","items":{"type":"object","required":["path","content"],"properties":{"path":{"type":"string"},"content":{"type":"string"},"mode":{"type":"string","enum":["create","replace","diff"]}}}},',
  ' "cites":{"type":"array","items":{"type":"string"}},"rationale":{"type":"string"},"tests":{"type":"array","items":{"type":"string"}},"missing_facts":{"type":"array","items":{"type":"string"}}}}',
  '# Review',
  '{"type":"object","required":["verdict","findings"],"properties":{"verdict":{"type":"string","enum":["PASS","FAIL"]},"findings":{"type":"array","items":{"type":"object","required":["severity","file","line","message"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","nit"]},"file":{"type":"string"},"line":{"type":"integer"},"message":{"type":"string"},"evidence":{"type":"string"}}}},"checked_constants":{"type":"array","items":{"type":"string"}}}}',
  '# Diagnosis',
  '{"type":"object","required":["hypotheses","next_action"],"properties":{"hypotheses":{"type":"array","items":{"type":"object","required":["text","p","experiment"],"properties":{"text":{"type":"string"},"p":{"type":"number"},"evidence_for":{"type":"array","items":{"type":"string"}},"evidence_against":{"type":"array","items":{"type":"string"}},"experiment":{"type":"string"}}}},"next_action":{"type":"string"},"needs_permission":{"type":"boolean"}}}',
  '# ReqSet (mục Requirement), ModuleGraph, HwMap, ADR, DocSections, Diagram, NetProposal, Candidates, MissingList: xem DDD-14 §2 (JSON Schema đầy đủ, cùng quy tắc mẫu số chung)',
]));
c.push(SP());
c.push(H1('5. Định dạng skill (K5) và chuỗi mẫu (K5 thủ tục)'));
c.push(...CODE([
  '# skills/TEMPLATE.md — ≤ 600 token, một chủ đề, ví dụ đã chạy',
  '---',
  'id: skills/armv7e-m/i2c',
  'applies_to: [isa:armv7e-m, periph:I2C]      # cạnh APPLIES_TO trong KG',
  'version: 1.2',
  'verified: {board: nucleo-f411, date: 2026-09-01, bench: {model: claude-sonnet, bc: 0.95}}',
  'tokens: 540',
  '---',
  '## Khi nào dùng: cấu hình và giao dịch I2C chủ trên Cortex-M (STM32 HAL hoặc thanh ghi)',
  '## Quy tắc (mỗi dòng một quy tắc, có lý do)',
  '- Bật clock GPIO và I2C trước khi cấu hình AF; nếu không, ghi thanh ghi bị bỏ qua (RCC gating).',
  '- Chân SCL/SDA: open-drain, pull-up; tốc độ ≤ giới hạn của slave theo fact timing.',
  '- Sau lỗi NACK: xóa cờ, phát STOP, thử lại ≤ 3 lần rồi báo lỗi lên trên, không treo trong vòng chờ.',
  '## Mẫu mã (đã chạy, hằng số trỏ fact của dự án khi dùng)',
  '```c',
  'static int i2c_write_reg(I2C_HandleTypeDef *h, uint8_t addr7, uint8_t reg, uint8_t val) { /* … timeout, kiểm HAL_OK */ }',
  '```',
  '## Lỗi hay gặp: quên pull-up; địa chỉ 7-bit không dịch trái; dùng HAL_Delay trong ISR.',
  '',
  '# chains/new_project_from_zip.yaml — chuỗi mẫu cho intent knowledge.build/big_command',
  'id: chains/new_project_from_zip',
  'trigger_intents: [knowledge.build, big_command]',
  'nodes:',
  '  - {id: n1, cap: project.create, args: {text: "$text"}, on_ask: wait}',
  '  - {id: n2, cap: archive.explore, args: {path: "$path"}, after: [n1]}',
  '  - {id: n3, cap: archive.classify, after: [n2]}',
  '  - {id: n4, cap: extract.auto, args: {files: "$n3.files"}, after: [n3], on_ask: parallel}',
  '  - {id: n5, cap: passport.build, after: [n4]}',
  '  - {id: n6, cap: board.build_passport, after: [n4]}',
  '  - {id: n7, cap: search.missing, after: [n5, n6]}',
  '  - {id: n8, cap: search.web, args: {needs: "$n7.requests"}, when: "$n7.requests", after: [n7], on_ask: parallel}',
  '  - {id: n9, cap: env.check, after: [n5], on_ask: parallel}',
  '  - {id: n10, cap: env.install_tool, args: {missing: "$n9.missing"}, when: "$n9.missing", after: [n9]}',
  '  - {id: n11, cap: sim.build, after: [n10, n6]}',
  '  - {id: n12, cap: req.elicit, args: {sources: ["$path/README*"]}, after: [n3]}',
  '  - {id: n13, cap: plan.create, args: {feature: "$n12.first_feature"}, after: [n12, n11, n5]}',
  '  - {id: n14, cap: chat.report_back, after: [n13]}',
  'limits: {max_nodes: 30, max_cost_usd: 2, max_minutes: 45}',
]));
c.push(SP());
c.push(P('Bộ chuỗi mẫu khởi đầu (chains/): new_project_from_idea (Z-01), new_project_from_zip (Z-07), add_feature (Z-05), debug_from_log (kịch bản C), write_docs (P7), discover_and_flash (Z-10), verify_passport (P1.6), publish_internal (P6). Chuỗi mẫu là gợi ý cho planner (đưa vào C3 như skill); planner có thể chỉnh nhưng nút kết quả phải qua kiểm deterministic (DPS §4.4).'));
c.push(H1('6. Prompt phủ định từ sổ lỗi'));
c.push(P('Mỗi ErrorLedgerEntry (MEM-11 §6) có `negative_prompt` do mô hình rẻ sinh theo schema {rule ≤ 40 token, scope: role+chip|role|global}. Composer nối tối đa 5 dòng mới nhất phù hợp phạm vi vào cuối C1 dưới tiêu đề "Lỗi đã gặp — tránh:". Ví dụ: "Không suy ra bit CTRL_MEAS của BME280 từ trí nhớ; tra fact f_…"; "Không dùng HAL_Delay trong ISR EXTI"; "Nguồn forum.st.com không phải datasheet; chỉ đề xuất, không dùng làm fact". Dòng hết TTL 30 ngày hoặc khi skill tương ứng được cập nhật.'));
c.push(H1('7. Bộ 50 câu lệnh có nhãn cho vai trò intent'));
const CMDS = [
 ['Tạo cho anh dự án robot hai bánh tự cân bằng', 'project.create', 'idea=robot hai bánh tự cân bằng', 'true'],
 ['Mở dự án robot-ctrl', 'project.open', 'project_name=robot-ctrl', 'false'],
 ['Đây là bộ tài liệu board, hãy dựng tri thức, môi trường và mô phỏng rồi viết firmware đọc BME280 phát UART', 'big_command', 'path=<đính kèm>; feature=đọc BME280 phát UART', 'true'],
 ['Làm hết đi', 'big_command', '—', 'true'],
 ['Nhập cái zip này', 'knowledge.build', 'path=<đính kèm>', 'false'],
 ['Chip này có bao nhiêu kênh ADC?', 'view.ask', 'question=…', 'false'],
 ['Địa chỉ I2C của BME280 là gì', 'view.ask', 'question=…; mentions=BME280', 'false'],
 ['Cài môi trường cho STM32', 'env.setup', 'chip=STM32', 'false'],
 ['Thiếu công cụ gì thì cài luôn', 'env.setup', '—', 'false'],
 ['Chạy mô phỏng thử', 'sim.run', '—', 'false'],
 ['Mô phỏng cái robot xem sao', 'sim.run', 'idea=robot', 'false'],
 ['Viết firmware đọc nhiệt độ', 'code.feature', 'feature=đọc nhiệt độ', 'false'],
 ['Thêm tính năng đọc MPU6050 qua I2C1', 'code.feature', 'feature=đọc MPU6050 qua I2C1; mentions=MPU6050,I2C1', 'false'],
 ['Sửa lỗi NACK trên I2C', 'debug.ask', 'question=NACK I2C', 'false'],
 ['Nạp lên board', 'target.flash', '—', 'false'],
 ['Nạp lại bản known-good', 'target.flash', 'feature=known-good', 'false'],
 ['Dừng', 'policy.stop', '—', 'false'],
 ['Dừng tự chủ', 'policy.stop', '—', 'false'],
 ['Đặt mức tự chủ A2 cho board robot', 'policy.set', 'level=A2; board=robot', 'false'],
 ['Phân tích yêu cầu từ README', 'req.analyze', 'path=README', 'false'],
 ['Thiết kế kiến trúc cho firmware này', 'arch.design', '—', 'false'],
 ['Vẽ sơ đồ kiến trúc', 'diagram.draw', 'diagram_kind=architecture', 'false'],
 ['Vẽ sơ đồ chân cho board', 'diagram.draw', 'diagram_kind=pinmap', 'false'],
 ['Vẽ máy trạng thái của module motor', 'diagram.draw', 'diagram_kind=state; mentions=motor', 'false'],
 ['Viết SRS', 'doc.write', 'doc_type=SRS', 'false'],
 ['Viết hướng dẫn bring-up cho board', 'doc.write', 'doc_type=bringup', 'false'],
 ['Viết bộ tài liệu đầy đủ', 'big_command', 'doc_type=all', 'true'],
 ['Board nào đang cắm?', 'discover.scan', '—', 'false'],
 ['Dò tốc độ serial tối ưu', 'discover.scan', 'kind=link_speed', 'false'],
 ['Cho anh xem bản đồ tri thức', 'view.ask', 'diagram_kind=kg_map', 'false'],
 ['Fact này lấy từ đâu?', 'view.ask', 'question=provenance', 'false'],
 ['Bắt đầu với chip ESP32-C3', 'project.create', 'chip=ESP32-C3', 'false'],
 ['Tạo dự án cho board này (kèm ảnh)', 'project.create', 'path=<ảnh>', 'false'],
 ['Create a new project for a balancing robot', 'project.create', 'idea=balancing robot; lang=en', 'true'],
 ['Flash it', 'target.flash', 'lang=en', 'false'],
 ['What is the base address of I2C1?', 'view.ask', 'mentions=I2C1; lang=en', 'false'],
 ['Tiếp tục việc hôm qua', 'project.open', '—', 'false'],
 ['Hoàn tác merge vừa rồi', 'policy.set', 'undo=last_merge', 'false'],
 ['Tại sao anh chọn RTOS?', 'view.ask', 'question=explain decision', 'false'],
 ['Kiểm tra xung đột chân', 'arch.design', 'diagram_kind=check_pins', 'false'],
 ['Tìm datasheet A4988', 'knowledge.build', 'mentions=A4988', 'false'],
 ['Tải datasheet từ trang này (link)', 'knowledge.build', 'path=<url>', 'false'],
 ['Duyệt hết fact chờ đi', 'policy.set', 'approve=pending_facts', 'false'],
 ['So sánh datasheet với errata về I2C', 'view.ask', 'question=compare I2C', 'false'],
 ['Đóng gói hộ chiếu này lên registry lớp', 'big_command', 'publish=internal', 'true'],
 ['Chạy benchmark với Gemini', 'big_command', 'bench; model=gemini', 'true'],
 ['Xóa dự án test-1', 'project.delete', 'project_name=test-1 (R4 → hỏi, POL-17 GEN-03)', 'false'],
 ['abc xyz', 'unknown', '—; confidence < 0,6', 'false'],
 ['Cấu hình I2C1 400 kHz trên PB6/PB7', 'code.feature', 'mentions=I2C1,PB6,PB7', 'false'],
 ['Đo dòng tiêu thụ khi ngủ', 'big_command', 'measure=current; mode=sleep', 'true'],
];
c.push(T([600, 4000, 1700, 2500, 500], ['#', 'Câu lệnh', 'intent', 'slots / mentions', 'is_big'], CMDS.map((r, i) => [String(i + 1), ...r]), { size: 19 }));
fs.writeFileSync('tests_dialog_commands.jsonl', CMDS.map((r, i) => JSON.stringify({ id: i + 1, text: r[0], intent: r[1], slots: r[2], is_big: r[3] === 'true' })).join('\n') + '\n');
c.push(SP());
c.push(P('Tệp `tests/dialog/commands.jsonl` chứa 50 câu này; TC-59 chạy intent trên từng câu và chấm intent đúng ≥ 95%, is_big đúng 100%, confidence < 0,6 cho câu 48.'));
c.push(H1('8. Đánh giá và thay đổi prompt'));
c.push(P('Prompt là mã: mỗi thay đổi là một commit có thông điệp nêu lý do (bản ghi sổ lỗi hoặc benchmark), chạy lại (1) TC-59 cho intent, (2) TC-23 hợp đồng adapter, (3) BEN-21 mức 1–2 cho coder/reviewer/planner trên hai mô hình khác hãng, (4) Z-01…Z-10 cho chuỗi. Tiêu chí chấp nhận: BC không giảm, tỷ lệ trích dẫn đúng ≥ 98%, token vào không tăng > 10%. Prompt và skill ghi phiên bản trong ledger của mỗi lượt gọi (prompt_hash) để truy vết đầu ra về phiên bản prompt.'));
c.push(...refParas(H1));
build(m, c, 'EIDE-PRS-16_Prompt_vai_tro_skill.docx');
