const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-BPD-06', 'Luồng nghiệp vụ', 'TÀI LIỆU LUỒNG NGHIỆP VỤ (BPD)',
  'Tám quy trình vận hành P0–P7 của EIDE (Embedded IDE): vai trò, bước, năng lực được gọi, đầu vào/đầu ra, cổng và mức tự động, tri thức sinh ra',
  [['Tài liệu trước', 'EIDE-SRS-02, EIDE-SAD-03, EIDE-APD-08, EIDE-DPS-09'], ['Dùng khi', 'Viết hướng dẫn sử dụng, huấn luyện học viên, thiết kế UI hàng đợi (chờ tôi / đã làm), điền ma trận Người–AI']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-BPD-06): sáu quy trình P1–P6']],
  'Thêm P0 tiếp nhận lệnh ngôn ngữ tự nhiên và P7 yêu cầu → kiến trúc → lược đồ → tài liệu; cột "Tự động ở mức" cho mọi cổng; P4 thêm bước dò board; bảng cổng ghi người quyết định = chính sách/người; năng lực gọi ở từng bước');
const c = [];
c.push(H1('1. Giới thiệu'));
c.push(P('Tài liệu mô tả EIDE theo góc nhìn quy trình nghiệp vụ: ai làm gì, ở bước nào, đầu vào và đầu ra là gì, cổng người ở đâu, và tri thức nào được sinh ra và lưu ở đâu. Từ v1.1 có tám quy trình P0–P7: P0 (tiếp nhận lệnh ngôn ngữ tự nhiên) bao trùm mọi quy trình khác vì kỹ sư khởi phát mọi việc bằng lệnh; P7 phủ phần kỹ nghệ (yêu cầu, kiến trúc, lược đồ, tài liệu) mới bổ sung. Mỗi bước ghi thêm năng lực được gọi (mã trong Danh mục [25]) và, ở bước có cổng, mức tự chủ tối thiểu để chính sách tự quyết định thay người (APD-08 [26]). Mỗi quy trình có sơ đồ bơi (swimlane) bốn làn: Kỹ sư/Người duyệt; Tác tử; Knowledge Plane (gate, đồ thị, nhật ký); Tool Layer/Phần cứng. Cách tổ chức này tiếp nối "ma trận pha × vai trò AI × vai trò người × tri thức" của phương pháp AIDD [2].'));
c.push(...IMG('hinh/hkw_swimlane.png', 600, 273, 'Hình 1. Sáu quy trình P1–P6 trên bốn làn (v1.0); ô vàng là bước của con người — từ v1.1 phần lớn ô vàng do chính sách quyết định ở mức ≥ Ax, xem bảng §2'));
c.push(...IMG('hinh/eide_nl_loop.png', 600, 328, 'Hình 2. Quy trình P0 — tám bước tiếp nhận lệnh ngôn ngữ tự nhiên (v1.1)'));
c.push(H1('2. Quy ước'));
c.push(P('Mỗi bước ghi: mã bước, làn (N = người, T = tác tử, K = Knowledge Plane, H = phần cứng/công cụ), hành động, đầu vào, đầu ra, và "tri thức sinh ra" (được ghi vào đâu). Cổng ký hiệu G-SRC, G-FACT, G1, G3, G4, G5, G-OPS; từ v1.1 mỗi cổng ghi **"tự động ở mức ≥ Ax"** — ở mức tự chủ đó trở lên PolicyGate tự quyết định khi có bằng chứng (làm rồi báo cáo, có hoàn tác), dưới mức đó hoặc thiếu bằng chứng thì hỏi người; cổng R4 luôn hỏi. Thời gian mục tiêu là ước lượng cho dự án cỡ driver một ngoại vi.'));
c.push(T([1300, 2200, 2400, 3400], ['Cổng', 'Tự động ở mức', 'Điều kiện tự động (tóm tắt APD §4)', 'Luôn hỏi khi'], [
  ['G-SRC', '≥ A1', 'Nguồn tin cậy, hash/license rõ, ≤ ngưỡng', 'Nguồn lạ, license không rõ, tệp lớn'],
  ['G-FACT', '≥ A1', 'Vàng luôn; bạc confidence ≥ 0,85 + nguồn thứ hai/khớp dải', 'Mâu thuẫn; OCR; điện/timing chưa có nguồn 2'],
  ['G1', '≥ A2', 'Kế hoạch ≤ N bước, có trích dẫn, không tài nguyên mới', 'Đổi kiến trúc; tài nguyên mới; thiếu tri thức'],
  ['G3', '≥ A2', '4 cổng công cụ đạt, reviewer khác hãng PASS, diff trong phạm vi', 'Blocker; chạm ISR/linker; tăng size > 5%'],
  ['G-OPS', '≥ A3 (board lab)', 'Nạp/reset/RTT/đọc-ghi RAM trên board lab, artifact qua G3', 'Board không lab; xóa flash; fuse; động cơ; cài gói lạ'],
  ['G4', '≥ A3', 'Kỳ vọng quan sát được bằng máy đạt', 'Chỉ quan sát bằng mắt/tay'],
  ['G5', '≥ A4', 'Phát hành nội bộ gói đã auto-verified', 'Phát hành công khai; chứa K3/K6'],
]));
c.push(SP());

function proc(code, title, goal, trigger, steps, outputs, kpis) {
  c.push(H1(`${code}. ${title}`));
  c.push(P(`**Mục tiêu:** ${goal}`)); c.push(P(`**Kích hoạt:** ${trigger}`));
  c.push(T([900, 600, 2900, 2300, 2600], ['Bước', 'Làn', 'Hành động', 'Đầu vào → đầu ra', 'Tri thức sinh ra / cổng'], steps));
  c.push(SP());
  c.push(P(`**Kết quả:** ${outputs}`)); c.push(P(`**Chỉ số:** ${kpis}`));
}
proc('3. P0', 'Tiếp nhận lệnh ngôn ngữ tự nhiên (mới v1.1)', 'Từ một câu lệnh của kỹ sư đến chuỗi năng lực đã chạy và báo cáo, với số câu hỏi tối thiểu (DPS-09).',
  'Kỹ sư gõ/nói lệnh trong cửa sổ trò chuyện (màn hình mặc định), từ CLI `eide "<lệnh>"`, hoặc từ IDE ngoài qua chat.command.',
  [
    ['P0.1', 'N', 'Ra lệnh: "Tạo dự án robot hai bánh tự cân bằng" / "Làm hết đi" (sau khi thả zip)', 'Câu lệnh → text', 'Ledger: lệnh gốc'],
    ['P0.2', 'T', 'chat.parse_intent: ý định + tham số; nhận diện lệnh lớn', 'text → Intent', 'Intent (K7)'],
    ['P0.3', 'T/K', 'chat.ground (D1): tra dự án, hộ chiếu, board, mẫu tham chiếu, registry — cái người nói đã tồn tại chưa', 'Intent → Grounded{exists, candidates}', 'Không tạo trùng'],
    ['P0.4', 'T', 'chat.fill_defaults (D2): điền ô trống bằng mặc định có căn cứ (autonomy.yaml, preferences.yaml)', 'Intent → Intent′', 'Ledger: mặc định đã áp'],
    ['P0.5', 'T/N', 'chat.clarify (D3): nếu còn ô trống không có mặc định hoặc lựa chọn không hoàn tác → MỘT câu hỏi gộp có phương án và mặc định; im lặng T ⇒ mặc định', 'Gaps → answer|default', 'Cổng hội thoại (không phải gate rủi ro); preferences.yaml (D8)'],
    ['P0.6', 'T', 'chat.restate (D6) + làm ngay phần chắc chắn (D4): "Tôi hiểu là… tôi sẽ…"; nút T1 không phụ thuộc bắt đầu song song', 'Intent′ → restated + chain', 'Ledger'],
    ['P0.7', 'T/K', 'chat.orchestrate: đồ thị chuỗi năng lực có nhánh; mỗi nút qua Router → grounding → policy.decide → thực thi; ASK không chặn nút song song', 'chain → Run', 'CapabilityRun, DecisionLog; các quy trình P1–P7 được gọi từ đây'],
    ['P0.8', 'T', 'chat.report_back: đã làm / chờ anh / hoàn tác được đến / chi phí; memory.* ghi lựa chọn', 'Run → Report', 'Báo cáo; preferences; thanh trạng thái'],
  ],
  'Chuỗi đã chạy tới mức chính sách cho phép; các mục ASK nằm trong hàng đợi "chờ tôi"; các việc tự làm trong hàng đợi "đã làm — hoàn tác được".',
  'Số câu hỏi/lệnh (mục tiêu ≤ 1); số lần bấm/kịch bản chuẩn (≤ 5); tỷ lệ intent đúng; thời gian từ lệnh đến báo cáo; tỷ lệ hoàn tác.');
proc('3. P1', 'Nhận tri thức phần cứng', 'Từ nhu cầu (chip/ngoại vi/mạch chưa có) đến hộ chiếu có nguồn, đã duyệt, tùy chọn đã kiểm định trên board.',
  'Lệnh P0 ("dựng tri thức từ zip này"); kéo thả tài liệu (UC01); truy vấn không khớp (UC03); search.missing báo thiếu.',
  [
    ['P1.1', 'N/T', 'Tạo yêu cầu nhận tri thức (need, part, peripheral)', 'Mô tả → AcquisitionRequest(REQUESTED)', 'Nhật ký yêu cầu'],
    ['P1.2', 'T', 'archive.explore/classify (zip/rar/7z lồng nhau); search.registry/vendor/docs_mcp/web + search.rank: registry → cục bộ → hãng → docs MCP → web', 'Yêu cầu → Candidate[] (uri, kind, size, license?, hash?)', '—'],
    ['P1.3', 'T/N', 'search.fetch qua policy.decide: nguồn tin cậy tự tải (≥ A1); nguồn lạ/license không rõ/tệp lớn → hỏi', 'Candidate[] → CONFIRMED', '**G-SRC** tự động ≥ A1; DecisionLog'],
    ['P1.4', 'T/K', 'extract.* (svd/atdf/pdf/image OCR/bom/netlist/timing…) trong sandbox; passport.build; kg.build; view.rag_index cập nhật chỉ mục', 'Tệp → Fact[] có locator, tier, confidence', 'Fact, Source, cạnh CITES/CONFLICTS_WITH; RagChunk'],
    ['P1.5', 'T/N', 'kg.review_facts: vàng và bạc đạt ngưỡng tự duyệt ("auto-reviewed by policy"); còn lại người duyệt theo nhóm với ảnh cắt (view.doc_side_by_side); kg.resolve_conflict', 'Fact[] → REVIEWED', '**G-FACT** tự động ≥ A1; confirmed_by = policy|người'],
    ['P1.6', 'T/H', 'discover.chip_id + bench.verify_passport: đọc ID/GPIO/UART trên board lab tự động; so sánh hộ chiếu', 'Board → Badge verified_on_board', '**G-OPS** tự động ≥ A3 (board lab); Measurement, huy hiệu'],
    ['P1.7', 'K', 'Cập nhật đồ thị; nếu fact thay fact cũ → đánh dấu CodeUnit stale, tạo backlog kiểm lại', 'Fact mới → SUPERSEDES, stale list', 'FEATURES.json (mục kiểm lại)'],
  ],
  'Hộ chiếu ở trạng thái reviewed/verified; mọi fact có nguồn; đồ thị cập nhật; yêu cầu đóng.',
  'Thời gian từ yêu cầu đến reviewed (mục tiêu ≤ 1 buổi cho một cảm biến, ≤ 5 phút cho chip có SVD); tỷ lệ fact bị người sửa (đo chất lượng extractor); số mâu thuẫn.');
proc('4. P2', 'Lập kế hoạch có trích dẫn', 'Chuyển yêu cầu tính năng thành kế hoạch từng bước có trích dẫn hộ chiếu, được duyệt tại G1.',
  'Kỹ sư mô tả tính năng (STEP.md hoặc lệnh); FEATURES.json có mục failing.',
  [
    ['P2.1', 'N/T', 'Lệnh P0 hoặc Feature failing; req.* và arch.* (P7) cung cấp ReqSet/ModuleGraph nếu có', 'Ý định → STEP.md', 'STEP.md'],
    ['P2.2', 'T/K', 'Planner: lấy ngữ cảnh Graph-RAG (hộ chiếu chip + mạch + ràng buộc + skill ISA); tự đánh giá đủ thông tin', 'STEP + hộ chiếu → Plan{steps[], citations[], missing[]}', 'Nếu missing → mở P1'],
    ['P2.3', 'K', 'Kiểm xung đột tài nguyên (kg.conflicts) cho các Pin/Peripheral kế hoạch sẽ dùng', 'Plan → cảnh báo xung đột', 'Cạnh dự kiến USES'],
    ['P2.4', 'T/N', 'policy.decide(G1): kế hoạch ≤ N bước, có trích dẫn, không tài nguyên mới → tự duyệt; đổi kiến trúc/tài nguyên mới/thiếu tri thức → người', 'Plan → approved', '**G1** tự động ≥ A2; DecisionLog'],
    ['P2.5', 'K', 'Tách kế hoạch thành Feature con trong FEATURES.json (failing)', 'Plan → Feature[]', 'FEATURES.json'],
  ],
  'Kế hoạch được duyệt; mỗi bước có trích dẫn; Feature con sẵn sàng cho P3.',
  'Số vòng sửa kế hoạch; tỷ lệ kế hoạch thiếu thông tin phải quay về P1; token/kế hoạch.');
proc('5. P3', 'Sinh mã từ hộ chiếu', 'Sinh hoặc sửa một Feature với mọi hằng số phần cứng khớp hộ chiếu, qua bốn cổng công cụ và reviewer khác hãng, merge tại G3.',
  'Feature failing đầu tiên theo thứ tự trong FEATURES.json.',
  [
    ['P3.1', 'T', 'Coder: sinh CodePatch với `hkw:fact` cho mọi hằng số; rationale ≤ 150 từ', 'STEP + ngữ cảnh → CodePatch', 'Cạnh CITES dự kiến'],
    ['P3.2', 'K', 'Hook pre_write: constant-guard, quy ước repo, thư mục cho phép', 'CodePatch → chấp nhận / chặn (+ AcquisitionRequest)', 'Nhật ký hook'],
    ['P3.3', 'H', 'Bốn cổng công cụ: build → size → static → host-test', 'Mã → ToolReport ×4', 'ToolReport'],
    ['P3.4', 'T', 'Tự sửa theo ToolReport, ≤ 3 vòng; quá → bàn giao người kèm log', 'ToolReport → CodePatch\'', 'Sổ lỗi (nếu thất bại)'],
    ['P3.5', 'T', 'Reviewer (khác hãng): checklist ISA/chip; không sửa mã', 'CodePatch → Review{verdict, findings}', 'Findings vào sổ lỗi'],
    ['P3.6', 'T/N', 'code.merge qua policy.decide(G3): 4 cổng đạt + reviewer khác hãng PASS + diff trong phạm vi → merge vào auto/ với cửa sổ hoàn tác 24 h; blocker/ISR/linker → người', 'Diff → merged / rejected(lý do)', '**G3** tự động ≥ A2; UndoItem; reject → sổ lỗi + prompt phủ định'],
    ['P3.7', 'K', 'Merge; commit có thông điệp truy vết (fact ids, model, prompt hash); cập nhật CodeUnit USES/CITES', 'Diff → commit', 'Đồ thị CodeUnit; ledger'],
  ],
  'Mã đã merge, có truy vết tới fact và mô hình; Feature vẫn failing cho tới P4.',
  'Số vòng tự sửa; lỗi build lần đầu; tỷ lệ G3 từ chối và lý do; token/module; hằng số bị chặn bởi constant-guard.');
proc('6. P4', 'Xác minh trên mô phỏng và phần cứng', 'Chứng minh Feature chạy đúng bằng SIL rồi HIL, có xác nhận vật lý của người, và gắn bằng chứng vào đồ thị.',
  'Feature đã merge (P3.7).',
  [
    ['P4.1', 'T/H', 'sim.build/run: sinh kịch bản kiểm thử từ kỳ vọng của Feature; chạy SIL (Renode/simavr) trước', 'Feature → Scenario, ToolReport(sim)', 'Scenario lưu trong bench/'],
    ['P4.1b', 'T/H', 'discover.ports/probes/chip_id/link_speed/auto_setup: dò board đang cắm, đối chiếu hộ chiếu, chọn tốc độ, cấu hình target (mới v1.1)', 'USB → Discovery, target.yaml', 'Discovery; cảnh báo nếu ID lệch'],
    ['P4.2', 'T/N', 'policy.decide(G-OPS): board lab + artifact qua G3 → tự nạp (≥ A3); board không lab/động cơ → người cấp quyền phiên', '— → APPROVE | Permission(flash)', '**G-OPS** tự động ≥ A3 (board lab)'],
    ['P4.3', 'H', 'target.flash + verify; target.serial; expect theo kịch bản', 'Artifact → ToolReport(flash), log JSONL', 'Log, Measurement'],
    ['P4.4', 'T', 'So sánh SIL/HIL và kỳ vọng; nếu lệch → về P3 hoặc P5', 'Log → báo cáo chênh lệch', 'Sổ lỗi nếu lệch'],
    ['P4.5', 'T/N', 'target.observe: kỳ vọng quan sát được bằng máy (serial expect, probe, LA, camera, đo dòng) → auto-verified; chỉ quan sát bằng mắt/tay → người xác nhận', 'Quan sát → confirmed', '**G4** tự động ≥ A3 khi có cảm biến; DecisionLog'],
    ['P4.6', 'K', 'Feature → passing; cạnh EVIDENCED_BY tới log hash/Measurement; known-good mới', 'Feature, evidence', 'FEATURES.json; known-good tag'],
  ],
  'Feature passing có bằng chứng; known-good được cập nhật.',
  'Thời gian build–nạp–log; tỷ lệ Feature lệch SIL/HIL; số lần G4 từ chối.');
proc('7. P5', 'Gỡ lỗi có chứng cứ', 'Từ triệu chứng (log, treo, HardFault) đến nguyên nhân có chứng cứ và bản sửa, với mọi thí nghiệm trên phần cứng được người cho phép.',
  'Lệch ở P4.4; báo cáo lỗi; kỹ sư chọn vùng log trong GEditor.',
  [
    ['P5.1', 'N', 'Chọn vùng log / mô tả triệu chứng; GEditor tính log.stats', 'Log → {range, stats}', 'Log đăng ký với daemon'],
    ['P5.2', 'K', 'Lấy ngữ cảnh: hộ chiếu (thanh ghi liên quan), CodeUnit USES, DebugSession trước', 'range → ngữ cảnh', '—'],
    ['P5.3', 'T', 'Debugger: giả thuyết xếp hạng + thí nghiệm phân biệt (đọc thanh ghi, RTT, breakpoint, test firmware)', 'Ngữ cảnh → Diagnosis', 'Diagnosis'],
    ['P5.4', 'T/N', 'debug.experiment qua policy.decide: probe write/RTT/nạp test firmware trên board lab tự động; khác → người', '— → APPROVE | Permission', '**G-OPS** tự động ≥ A3 (board lab)'],
    ['P5.5', 'H', 'Thực thi thí nghiệm: probe halt/read/diagnose_fault/unwind hoặc nạp test firmware', 'Thí nghiệm → EvidencePack', 'Measurement'],
    ['P5.6', 'T', 'Cập nhật giả thuyết; đề xuất sửa → mở P3 với STEP mới', 'Evidence → Diagnosis\', STEP', '—'],
    ['P5.7', 'K', 'Lưu DebugSession gắn fact/CodeUnit/log; ghi sổ lỗi', 'Phiên → DebugSession', 'Sổ lỗi; đồ thị'],
  ],
  'Nguyên nhân có chứng cứ; bản sửa đi qua P3–P4; phiên gỡ lỗi trở thành tri thức dự án.',
  'Thời gian đến giả thuyết đúng; số thí nghiệm; tỷ lệ chẩn đoán đúng (bench HardFault).');
proc('8. P6', 'Bàn giao, đóng gói và phát hành', 'Xuất sản phẩm bàn giao có nguồn; đóng gói hộ chiếu/skill/benchmark thành .hkp; phát hành lên registry với huy hiệu.',
  'Dự án đạt mốc; Pack owner muốn chia sẻ hộ chiếu; khóa học nộp bài.',
  [
    ['P6.1', 'T', 'Tester chạy benchmark hộ chiếu/ISA theo mô hình; kiểm định lại trên board nếu chưa', 'Bench → kết quả CF/BF/BC, huy hiệu', 'badges.json'],
    ['P6.2', 'T/K', 'Sinh báo cáo (docx/pdf/md) với mục nguồn; ma trận Người–AI từ nhật ký gate', 'Ledger → báo cáo', 'Báo cáo, ma trận'],
    ['P6.3', 'K', 'Đóng gói .hkp: manifest, passport.yaml (fact + con trỏ nguồn, không PDF), skills, bench, badges; kiểm license', 'Store → .hkp', 'Gói'],
    ['P6.4', 'T/N', 'registry.publish qua policy.decide(G5): nội bộ + auto-verified + benchmark ≥ ngưỡng → tự phát hành (≥ A4); công khai/chứa K3-K6 → người ký', 'Gói → signed', '**G5** tự động ≥ A4 (nội bộ); SIGNATURE'],
    ['P6.5', 'K', 'Publish lên registry (Git push / index); ghi tác giả', 'Gói → registry', 'Index; ghi công'],
  ],
  'Tài liệu bàn giao có nguồn; gói trên registry với huy hiệu và chữ ký.',
  'Số gói phát hành; tỷ lệ gói đã kiểm định; lượt pull; thời gian tạo báo cáo.');
proc('9. P7', 'Yêu cầu → kiến trúc → lược đồ → tài liệu (mới v1.1)', 'Từ ý tưởng/lệnh/tài liệu thô đến bộ yêu cầu có mã, kiến trúc có ADR và ngân sách, lược đồ trong GEditor và tài liệu chuẩn EAA/EIDE — tất cả có nguồn và truy vết.',
  'Lệnh P0 ("phân tích yêu cầu cho…", "thiết kế kiến trúc", "vẽ sơ đồ…", "viết SRS"); dự án mới sau P1; yêu cầu đổi.',
  [
    ['P7.1', 'T', 'req.elicit + req.classify: thu thập từ lệnh, README, BOM, ảnh, chat cũ; phân loại FR/NFR/HW/SAFETY/RT; gán mã UR/FR', 'Nguồn thô → ReqSet', 'requirement (K6)'],
    ['P7.2', 'T/K', 'req.ground_hw + req.detect_conflict + req.prioritize: khả thi theo hộ chiếu; mâu thuẫn/mơ hồ; MoSCoW', 'ReqSet → FeasibilityReport, Issue[], ReqSet′', 'Trích dẫn fact; Issue vào hàng đợi nếu không tự giải'],
    ['P7.3', 'T/N', 'Câu hỏi gộp (P0.5) chỉ cho yêu cầu mâu thuẫn không tự giải hoặc ưu tiên M↔S', 'Issue[] → answer|default', 'Cổng hội thoại; T1* req.prioritize'],
    ['P7.4', 'T', 'arch.style_select + arch.decompose + arch.map_hw + arch.memory_budget + arch.timing_budget + arch.interface_spec + arch.state_machine', 'ReqSet′ + hộ chiếu → ArchDecision, ModuleGraph, HwMap, ngân sách, FSM', 'module, hw_map (K6); board.check_pins = 0'],
    ['P7.5', 'T', 'arch.adr + arch.review + arch.compare: ghi ADR có trích dẫn; rà checklist nhúng; so sánh phương án', 'ModuleGraph → ADR[], Findings[], Comparison', 'adr; T1* arch.style_select/compare (đổi kiến trúc dự án đã có → hỏi)'],
    ['P7.6', 'T', 'diagram.block/pinmap/architecture/sequence/state/timing/memory_map/gantt → diagram.lint → diagram.render; mở trong GEditor', 'Mô hình → Diagram (Mermaid/PlantUML/DOT/D2/WaveDrom/SVG)', 'diagram; đồng bộ diagram.sync'],
    ['P7.7', 'T', 'doc.generate (URD/SRS/SAD/SDD/STP/bring-up) + doc.embed_diagram + doc.style_check; req.trace_matrix', 'ReqSet, ModuleGraph, Diagram → DocArtifact (docx/md), Matrix (xlsx)', 'doc_artifact; mục Nguồn; lỗi style = 0'],
    ['P7.8', 'T/N', 'arch.to_plan → P2; kỹ sư xem tài liệu/lược đồ trong GEditor, sửa trực tiếp (mã lược đồ, mục tài liệu) — tác tử đồng bộ ngược', 'ModuleGraph → Plan; sửa của người → sync', 'Plan; diagram.sync; doc.sync'],
    ['P7.9', 'K', 'Khi fact/mã/yêu cầu đổi: req.change_impact + view.impact_map → mục tài liệu/lược đồ stale được gắn nhãn; doc.sync cập nhật', 'Delta → ImpactReport, stale[]', 'doc_artifact.stale_sections; diagram.stale'],
  ],
  'Bộ yêu cầu có mã và tiêu chí chấp nhận; kiến trúc có ADR, HwMap không xung đột, ngân sách; lược đồ render trong GEditor; tài liệu chuẩn EAA/EIDE có mục Nguồn; ma trận truy vết.',
  'Tỷ lệ yêu cầu người chấp nhận không sửa; xung đột tài nguyên trước sinh mã (mục tiêu 0); lỗi style tài liệu; thời gian từ README đến SRS (mục tiêu ≤ 30 phút); tỷ lệ lược đồ lệch mã.');
c.push(H1('10. Bảng tổng hợp cổng và tri thức sinh ra'));
c.push(T([1300, 2000, 2700, 3300], ['Cổng', 'Quy trình / bước', 'Người quyết định (v1.1)', 'Bằng chứng để quyết định'], [
  ['Hội thoại', 'P0.5, P7.3', 'Kỹ sư (một câu gộp) / mặc định sau timeout', 'Phương án đánh số, mặc định, lý do'],
  ['G-SRC', 'P1.3', 'Chính sách ≥ A1; kỹ sư khi nguồn lạ', 'Danh sách ứng viên: nguồn, hash, license, kích thước'],
  ['G-FACT', 'P1.5', 'Chính sách ≥ A1 (vàng; bạc đạt ngưỡng); kỹ sư/Pack owner khi mâu thuẫn/tin cậy thấp', 'Fact theo nhóm, ảnh cắt, mâu thuẫn, mức tin cậy'],
  ['G1', 'P2.4, P7.8', 'Chính sách ≥ A2; kỹ sư khi đổi kiến trúc/tài nguyên mới', 'Kế hoạch có trích dẫn, cảnh báo xung đột'],
  ['G3', 'P3.6', 'Chính sách ≥ A2 (merge vào auto/, hoàn tác 24 h); kỹ sư khi blocker', 'Diff, rationale, citations, 4 ToolReport, Review khác hãng'],
  ['G-OPS', 'P1.6, P4.2, P5.4', 'Chính sách ≥ A3 trên board lab; kỹ sư cho R4 và board không lab', 'Thao tác cụ thể, target, artifact hash, Discovery'],
  ['G4', 'P4.5', 'Chính sách ≥ A3 khi có cảm biến máy; kỹ sư khi chỉ quan sát bằng mắt', 'Log, số đo, quan sát vật lý'],
  ['G5', 'P6.4', 'Chính sách ≥ A4 (nội bộ); chủ dự án/Pack owner khi công khai', 'Báo cáo, benchmark, license'],
]));
c.push(SP());
c.push(T([2200, 3300, 3800], ['Loại tri thức', 'Sinh ra ở', 'Lưu tại'], [
  ['Fact, Source, hộ chiếu', 'P1', 'store.sqlite; passport.yaml; đồ thị'],
  ['Kế hoạch, Feature', 'P2', 'FEATURES.json; ledger'],
  ['CodeUnit với CITES/USES; sổ lỗi', 'P3', 'Git; store; đồ thị'],
  ['Measurement, bằng chứng, known-good', 'P4', 'store; tag Git; FEATURES.json'],
  ['DebugSession, giả thuyết, thí nghiệm', 'P5', 'store; sổ lỗi; đồ thị'],
  ['Benchmark, huy hiệu, gói, báo cáo', 'P6', 'registry; badges.json; thư mục export'],
  ['Intent, Run, DecisionLog, preferences', 'P0', 'store (intent/run/decision_log); preferences.yaml; ledger'],
  ['ReqSet, ModuleGraph, HwMap, ADR, Diagram, DocArtifact, ma trận truy vết', 'P7', 'store; .eide/docs/ và .eide/diagrams/ (commit Git)'],
  ['Discovery, target.yaml', 'P4.1b', 'store (discovery); .eide/target.yaml'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-BPD-06_Luong_nghiep_vu.docx');
