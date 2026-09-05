# -*- coding: utf-8 -*-
p = "bpd.js"; s = open(p).read()
R = []
R.append(("""  [['Tài liệu trước', 'EIDE-SRS-02, EIDE-SAD-03'], ['Dùng khi', 'Viết hướng dẫn sử dụng, huấn luyện học viên, thiết kế UI hàng đợi xác nhận, điền ma trận Người–AI']]);""",
"""  [['Tài liệu trước', 'EIDE-SRS-02, EIDE-SAD-03, EIDE-APD-08, EIDE-DPS-09'], ['Dùng khi', 'Viết hướng dẫn sử dụng, huấn luyện học viên, thiết kế UI hàng đợi (chờ tôi / đã làm), điền ma trận Người–AI']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-BPD-06): sáu quy trình P1–P6']],
  'Thêm P0 tiếp nhận lệnh ngôn ngữ tự nhiên và P7 yêu cầu → kiến trúc → lược đồ → tài liệu; cột "Tự động ở mức" cho mọi cổng; P4 thêm bước dò board; bảng cổng ghi người quyết định = chính sách/người; năng lực gọi ở từng bước');"""))
R.append(("'Sáu quy trình vận hành P1–P6 của EIDE (Embedded IDE): vai trò, bước, đầu vào/đầu ra, cổng người, tri thức sinh ra',",
"'Tám quy trình vận hành P0–P7 của EIDE (Embedded IDE): vai trò, bước, năng lực được gọi, đầu vào/đầu ra, cổng và mức tự động, tri thức sinh ra',"))
R.append(("Sáu quy trình P1–P6 phủ toàn bộ 14 use case của SRS.",
"Từ v1.1 có tám quy trình P0–P7: P0 (tiếp nhận lệnh ngôn ngữ tự nhiên) bao trùm mọi quy trình khác vì kỹ sư khởi phát mọi việc bằng lệnh; P7 phủ phần kỹ nghệ (yêu cầu, kiến trúc, lược đồ, tài liệu) mới bổ sung. Mỗi bước ghi thêm năng lực được gọi (mã trong Danh mục [25]) và, ở bước có cổng, mức tự chủ tối thiểu để chính sách tự quyết định thay người (APD-08 [26])."))
R.append(("Cổng người ký hiệu G-SRC, G-FACT, G1, G3, G4, G5, G-OPS. Thời gian mục tiêu là ước lượng cho dự án cỡ driver một ngoại vi.'));",
"""Cổng ký hiệu G-SRC, G-FACT, G1, G3, G4, G5, G-OPS; từ v1.1 mỗi cổng ghi **"tự động ở mức ≥ Ax"** — ở mức tự chủ đó trở lên PolicyGate tự quyết định khi có bằng chứng (làm rồi báo cáo, có hoàn tác), dưới mức đó hoặc thiếu bằng chứng thì hỏi người; cổng R4 luôn hỏi. Thời gian mục tiêu là ước lượng cho dự án cỡ driver một ngoại vi.'));
c.push(T([1300, 2200, 2400, 3400], ['Cổng', 'Tự động ở mức', 'Điều kiện tự động (tóm tắt APD §4)', 'Luôn hỏi khi'], [
  ['G-SRC', '≥ A1', 'Nguồn tin cậy, hash/license rõ, ≤ ngưỡng', 'Nguồn lạ, license không rõ, tệp lớn'],
  ['G-FACT', '≥ A1', 'Vàng luôn; bạc confidence ≥ 0,85 + nguồn thứ hai/khớp dải', 'Mâu thuẫn; OCR; điện/timing chưa có nguồn 2'],
  ['G1', '≥ A2', 'Kế hoạch ≤ N bước, có trích dẫn, không tài nguyên mới', 'Đổi kiến trúc; tài nguyên mới; thiếu tri thức'],
  ['G3', '≥ A2', '4 cổng công cụ đạt, reviewer khác hãng PASS, diff trong phạm vi', 'Blocker; chạm ISR/linker; tăng size > 5%'],
  ['G-OPS', '≥ A3 (board lab)', 'Nạp/reset/RTT/đọc-ghi RAM trên board lab, artifact qua G3', 'Board không lab; xóa flash; fuse; động cơ; cài gói lạ'],
  ['G4', '≥ A3', 'Kỳ vọng quan sát được bằng máy đạt', 'Chỉ quan sát bằng mắt/tay'],
  ['G5', '≥ A4', 'Phát hành nội bộ gói đã auto-verified', 'Phát hành công khai; chứa K3/K6'],
]));
c.push(SP());"""))
R.append(("""proc('3. P1', 'Nhận tri thức phần cứng',""", """proc('3. P0', 'Tiếp nhận lệnh ngôn ngữ tự nhiên (mới v1.1)', 'Từ một câu lệnh của kỹ sư đến chuỗi năng lực đã chạy và báo cáo, với số câu hỏi tối thiểu (DPS-09).',
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
proc('3. P1', 'Nhận tri thức phần cứng',"""))
R.append(("'Kéo thả tài liệu (UC01); truy vấn không khớp (UC03); tác tử báo thiếu; kỹ sư tạo yêu cầu.',", "'Lệnh P0 (\"dựng tri thức từ zip này\"); kéo thả tài liệu (UC01); truy vấn không khớp (UC03); search.missing báo thiếu.',"))
R.append(("['P1.2', 'T', 'Librarian tìm ứng viên: registry → cục bộ → hãng → web; phân loại tệp kéo thả, mở nén', 'Yêu cầu → Candidate[] (uri, kind, size, license?, hash?)', '—'],",
"['P1.2', 'T', 'archive.explore/classify (zip/rar/7z lồng nhau); search.registry/vendor/docs_mcp/web + search.rank: registry → cục bộ → hãng → docs MCP → web', 'Yêu cầu → Candidate[] (uri, kind, size, license?, hash?)', '—'],"))
R.append(("['P1.3', 'N', 'Xác nhận nguồn: chọn/loại/thêm tệp; xem license', 'Candidate[] → CONFIRMED', '**G-SRC**; GateDecision'],",
"['P1.3', 'T/N', 'search.fetch qua policy.decide: nguồn tin cậy tự tải (≥ A1); nguồn lạ/license không rõ/tệp lớn → hỏi', 'Candidate[] → CONFIRMED', '**G-SRC** tự động ≥ A1; DecisionLog'],"))
R.append(("['P1.4', 'T/K', 'Trích xuất theo tầng trong sandbox; chuẩn hóa; hợp nhất; ghi Fact/Source (NORMALIZED)', 'Tệp → Fact[] có locator, tier, confidence', 'Fact, Source, cạnh CITES/CONFLICTS_WITH'],",
"['P1.4', 'T/K', 'extract.* (svd/atdf/pdf/image OCR/bom/netlist/timing…) trong sandbox; passport.build; kg.build; view.rag_index cập nhật chỉ mục', 'Tệp → Fact[] có locator, tier, confidence', 'Fact, Source, cạnh CITES/CONFLICTS_WITH; RagChunk'],"))
R.append(("['P1.5', 'N', 'Duyệt fact theo nhóm với ảnh cắt; sửa/loại; giải quyết mâu thuẫn', 'Fact[] → REVIEWED', '**G-FACT**; confirmed_by/at'],",
"['P1.5', 'T/N', 'kg.review_facts: vàng và bạc đạt ngưỡng tự duyệt (\"auto-reviewed by policy\"); còn lại người duyệt theo nhóm với ảnh cắt (view.doc_side_by_side); kg.resolve_conflict', 'Fact[] → REVIEWED', '**G-FACT** tự động ≥ A1; confirmed_by = policy|người'],"))
R.append(("['P1.6', 'N/H', 'Kiểm định trên board: cấp quyền nạp firmware ID/GPIO/UART; so sánh', 'Board → Badge verified_on_board', '**G-OPS**; Measurement, huy hiệu'],",
"['P1.6', 'T/H', 'discover.chip_id + bench.verify_passport: đọc ID/GPIO/UART trên board lab tự động; so sánh hộ chiếu', 'Board → Badge verified_on_board', '**G-OPS** tự động ≥ A3 (board lab); Measurement, huy hiệu'],"))
R.append(("['P2.1', 'N', 'Mô tả ý định; cập nhật ARCHITECTURE/PLAN/STEP nếu cần', 'Ý định → STEP.md', 'STEP.md'],",
"['P2.1', 'N/T', 'Lệnh P0 hoặc Feature failing; req.* và arch.* (P7) cung cấp ReqSet/ModuleGraph nếu có', 'Ý định → STEP.md', 'STEP.md'],"))
R.append(("['P2.4', 'N', 'Duyệt kế hoạch; sửa thứ tự/ràng buộc', 'Plan → approved', '**G1**; GateDecision'],",
"['P2.4', 'T/N', 'policy.decide(G1): kế hoạch ≤ N bước, có trích dẫn, không tài nguyên mới → tự duyệt; đổi kiến trúc/tài nguyên mới/thiếu tri thức → người', 'Plan → approved', '**G1** tự động ≥ A2; DecisionLog'],"))
R.append(("['P3.6', 'N', 'Duyệt diff với rationale, citations, 4 ToolReport, Review', 'Diff → merged / rejected(lý do)', '**G3**; GateDecision; reject → sổ lỗi + prompt phủ định'],",
"['P3.6', 'T/N', 'code.merge qua policy.decide(G3): 4 cổng đạt + reviewer khác hãng PASS + diff trong phạm vi → merge vào auto/ với cửa sổ hoàn tác 24 h; blocker/ISR/linker → người', 'Diff → merged / rejected(lý do)', '**G3** tự động ≥ A2; UndoItem; reject → sổ lỗi + prompt phủ định'],"))
R.append((("""    ['P4.1', 'T/H', 'Tester: sinh kịch bản kiểm thử từ kỳ vọng của Feature; chạy SIL (Renode/simavr) nếu có', 'Feature → Scenario, ToolReport(sim)', 'Scenario lưu trong bench/'],
    ['P4.2', 'N', 'Cấp quyền nạp trong phiên', '— → Permission(flash)', '**G-OPS**'],
    ['P4.3', 'H', 'Flash + verify; mở serial; expect theo kịch bản', 'Artifact → ToolReport(flash), log JSONL', 'Log, Measurement'],"""),
("""    ['P4.1', 'T/H', 'sim.build/run: sinh kịch bản kiểm thử từ kỳ vọng của Feature; chạy SIL (Renode/simavr) trước', 'Feature → Scenario, ToolReport(sim)', 'Scenario lưu trong bench/'],
    ['P4.1b', 'T/H', 'discover.ports/probes/chip_id/link_speed/auto_setup: dò board đang cắm, đối chiếu hộ chiếu, chọn tốc độ, cấu hình target (mới v1.1)', 'USB → Discovery, target.yaml', 'Discovery; cảnh báo nếu ID lệch'],
    ['P4.2', 'T/N', 'policy.decide(G-OPS): board lab + artifact qua G3 → tự nạp (≥ A3); board không lab/động cơ → người cấp quyền phiên', '— → APPROVE | Permission(flash)', '**G-OPS** tự động ≥ A3 (board lab)'],
    ['P4.3', 'H', 'target.flash + verify; target.serial; expect theo kịch bản', 'Artifact → ToolReport(flash), log JSONL', 'Log, Measurement'],""")))
R.append(("['P4.5', 'N', 'Xác nhận vật lý (LED, chuyển động, số đo); ghi quan sát', 'Quan sát → confirmed', '**G4**; GateDecision'],",
"['P4.5', 'T/N', 'target.observe: kỳ vọng quan sát được bằng máy (serial expect, probe, LA, camera, đo dòng) → auto-verified; chỉ quan sát bằng mắt/tay → người xác nhận', 'Quan sát → confirmed', '**G4** tự động ≥ A3 khi có cảm biến; DecisionLog'],"))
R.append(("['P5.4', 'N', 'Cấp quyền cho thí nghiệm nếu cần probe write/flash', '— → Permission', '**G-OPS**'],",
"['P5.4', 'T/N', 'debug.experiment qua policy.decide: probe write/RTT/nạp test firmware trên board lab tự động; khác → người', '— → APPROVE | Permission', '**G-OPS** tự động ≥ A3 (board lab)'],"))
R.append(("['P6.4', 'N', 'Duyệt bàn giao/phát hành; ký gói', 'Gói → signed', '**G5**; SIGNATURE'],",
"['P6.4', 'T/N', 'registry.publish qua policy.decide(G5): nội bộ + auto-verified + benchmark ≥ ngưỡng → tự phát hành (≥ A4); công khai/chứa K3-K6 → người ký', 'Gói → signed', '**G5** tự động ≥ A4 (nội bộ); SIGNATURE'],"))
R.append(("""c.push(H1('9. Bảng tổng hợp cổng người và tri thức sinh ra'));""", """proc('9. P7', 'Yêu cầu → kiến trúc → lược đồ → tài liệu (mới v1.1)', 'Từ ý tưởng/lệnh/tài liệu thô đến bộ yêu cầu có mã, kiến trúc có ADR và ngân sách, lược đồ trong GEditor và tài liệu chuẩn EAA/EIDE — tất cả có nguồn và truy vết.',
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
c.push(H1('10. Bảng tổng hợp cổng và tri thức sinh ra'));"""))
R.append((("""c.push(T([1500, 2700, 2300, 2800], ['Cổng', 'Quy trình / bước', 'Người quyết định', 'Bằng chứng để quyết định'], [
  ['G-SRC', 'P1.3', 'Kỹ sư', 'Danh sách ứng viên: nguồn, hash, license, kích thước'],
  ['G-FACT', 'P1.5', 'Kỹ sư / Pack owner', 'Fact theo nhóm, ảnh cắt, mâu thuẫn, mức tin cậy'],
  ['G1', 'P2.4', 'Kỹ sư', 'Kế hoạch có trích dẫn, cảnh báo xung đột'],
  ['G3', 'P3.6', 'Kỹ sư', 'Diff, rationale, citations, 4 ToolReport, Review khác hãng'],
  ['G-OPS', 'P1.6, P4.2, P5.4', 'Kỹ sư', 'Thao tác cụ thể, target, artifact hash'],
  ['G4', 'P4.5', 'Kỹ sư', 'Log, số đo, quan sát vật lý'],
  ['G5', 'P6.4', 'Chủ dự án / Pack owner', 'Báo cáo, benchmark, license'],
]));"""),
("""c.push(T([1300, 2000, 2700, 3300], ['Cổng', 'Quy trình / bước', 'Người quyết định (v1.1)', 'Bằng chứng để quyết định'], [
  ['Hội thoại', 'P0.5, P7.3', 'Kỹ sư (một câu gộp) / mặc định sau timeout', 'Phương án đánh số, mặc định, lý do'],
  ['G-SRC', 'P1.3', 'Chính sách ≥ A1; kỹ sư khi nguồn lạ', 'Danh sách ứng viên: nguồn, hash, license, kích thước'],
  ['G-FACT', 'P1.5', 'Chính sách ≥ A1 (vàng; bạc đạt ngưỡng); kỹ sư/Pack owner khi mâu thuẫn/tin cậy thấp', 'Fact theo nhóm, ảnh cắt, mâu thuẫn, mức tin cậy'],
  ['G1', 'P2.4, P7.8', 'Chính sách ≥ A2; kỹ sư khi đổi kiến trúc/tài nguyên mới', 'Kế hoạch có trích dẫn, cảnh báo xung đột'],
  ['G3', 'P3.6', 'Chính sách ≥ A2 (merge vào auto/, hoàn tác 24 h); kỹ sư khi blocker', 'Diff, rationale, citations, 4 ToolReport, Review khác hãng'],
  ['G-OPS', 'P1.6, P4.2, P5.4', 'Chính sách ≥ A3 trên board lab; kỹ sư cho R4 và board không lab', 'Thao tác cụ thể, target, artifact hash, Discovery'],
  ['G4', 'P4.5', 'Chính sách ≥ A3 khi có cảm biến máy; kỹ sư khi chỉ quan sát bằng mắt', 'Log, số đo, quan sát vật lý'],
  ['G5', 'P6.4', 'Chính sách ≥ A4 (nội bộ); chủ dự án/Pack owner khi công khai', 'Báo cáo, benchmark, license'],
]));""")))
R.append(("""  ['Benchmark, huy hiệu, gói, báo cáo', 'P6', 'registry; badges.json; thư mục export'],
]));""", """  ['Benchmark, huy hiệu, gói, báo cáo', 'P6', 'registry; badges.json; thư mục export'],
  ['Intent, Run, DecisionLog, preferences', 'P0', 'store (intent/run/decision_log); preferences.yaml; ledger'],
  ['ReqSet, ModuleGraph, HwMap, ADR, Diagram, DocArtifact, ma trận truy vết', 'P7', 'store; .eide/docs/ và .eide/diagrams/ (commit Git)'],
  ['Discovery, target.yaml', 'P4.1b', 'store (discovery); .eide/target.yaml'],
]));"""))
R.append(("c.push(...IMG('hinh/hkw_swimlane.png', 600, 273, 'Hình 1. Sáu quy trình trên bốn làn; ô vàng là bước của con người'));",
"c.push(...IMG('hinh/hkw_swimlane.png', 600, 273, 'Hình 1. Sáu quy trình P1–P6 trên bốn làn (v1.0); ô vàng là bước của con người — từ v1.1 phần lớn ô vàng do chính sách quyết định ở mức ≥ Ax, xem bảng §2'));\nc.push(...IMG('hinh/eide_nl_loop.png', 600, 328, 'Hình 2. Quy trình P0 — tám bước tiếp nhận lệnh ngôn ngữ tự nhiên (v1.1)'));"))
miss = 0
for a, b in R:
    if a not in s: print("MISSING:", a[:70]); miss += 1
    s = s.replace(a, b)
open(p, "w").write(s); print("missing", miss)
