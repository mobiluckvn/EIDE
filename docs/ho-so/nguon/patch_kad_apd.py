# -*- coding: utf-8 -*-
# ---- KAD ----
p = "kad.js"; s = open(p).read()
R = []
R.append(("""  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu theo yêu cầu làm rõ kiến trúc tri thức: 9 loại tri thức trên 3 trục; quy tắc cố định/làm giàu; 10 con đường làm giàu; tổ chức 5 lớp lưu trữ; chính sách phiên bản, xung đột, ngữ cảnh, chia sẻ; ánh xạ hiện trạng M0']]);""",
"""  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-KAD-07): 9 loại tri thức trên 3 trục; quy tắc cố định/làm giàu; 10 con đường làm giàu; tổ chức 5 lớp lưu trữ; chính sách phiên bản, xung đột, ngữ cảnh, chia sẻ; ánh xạ hiện trạng M0']],
  'Thêm K5′ mẫu dự án tham chiếu và K10 tri thức kỹ nghệ (yêu cầu, kiến trúc, ADR, lược đồ, tài liệu); con đường E11 (tác tử sinh tri thức kỹ nghệ) và E12 (dò board); cổng ở E1–E10 ghi mức tự động theo APD-08; §6.9 hiển thị và truy hồi (view.*, chỉ mục RAG); ánh xạ loại tri thức ↔ nhóm năng lực');"""))
R.append(("""c.push(H1('6. Tổ chức tri thức'));""", """c.push(H2('5.2. Bổ sung v1.1: K5′, K10, E11, E12 và cổng theo chính sách'));
c.push(P('Hai loại tri thức được thêm để đáp ứng danh mục năng lực [25]. **K5′ — mẫu dự án tham chiếu** (registry kind=template: hộ chiếu chip/board + BOM + skill + kịch bản mô phỏng + firmware mẫu + tham số vật lý có nguồn) là điểm xuất phát khi đầu vào trống ("tạo dự án robot hai bánh tự cân bằng" → search.reference_projects); nó thuộc lớp L-A/L-B, tier kế thừa gói, không bao giờ ghi đè K3/K6 của dự án. **K10 — tri thức kỹ nghệ của dự án**: ReqSet, ModuleGraph, HwMap, ADR, Diagram, DocArtifact, ma trận truy vết — do tác tử sinh (req.*, arch.*, diagram.*, doc.*) từ K2–K6, thuộc lớp L-C, có trích dẫn fact, được phiên bản theo Git và đánh dấu stale khi fact/mã đổi (req.change_impact, doc.sync, diagram.sync). K10 không phải fact phần cứng: nó là *diễn giải có nguồn* và mọi hằng số trong đó vẫn phải đối chiếu K2/K3.'));
c.push(T([900, 1900, 2300, 1300, 1500, 1400], ['Mã', 'Con đường', 'Cơ chế', 'Cổng', 'Bằng chứng bắt buộc', 'Đích → kết quả'], [
  ['E11', 'Tác tử sinh tri thức kỹ nghệ', 'req.elicit/classify/ground_hw → arch.* → diagram.* → doc.*; mỗi khẳng định trích dẫn fact; style_check', 'Hội thoại (câu hỏi gộp) cho mâu thuẫn; G1 khi đổi kiến trúc dự án đã có', 'citations[] tới K2–K6; lint/style = 0', 'K10 → L-C, status generated → reviewed khi người sửa/chấp nhận'],
  ['E12', 'Dò board và kết nối', 'discover.ports/probes/chip_id/link_speed/bus_scan/firmware/power → Discovery; đối chiếu hộ chiếu', 'Không (R0/R1); ID lệch ⇒ leo thang; nấc tốc độ vượt fact ⇒ ASK', 'raw ID, VID/PID, bảng (nấc, tỷ lệ lỗi), thời điểm', 'K7 (bằng chứng) + đề xuất K3 (board_match) qua G-FACT'],
]));
c.push(SP());
c.push(P('Cổng ở E1–E10 từ v1.1 do PolicyGate quyết định trước khi tới người: E1 và E4 tự động ở ≥ A1 (nguồn hãng/registry ký, hash và license rõ); E2 tự duyệt fact bạc đạt ngưỡng ở ≥ A1 (confidence ≥ 0,85 và nguồn thứ hai hoặc khớp dải), fact OCR/điện/timing chưa có nguồn thứ hai vẫn hỏi; E3 tự động khi hash CAD hợp lệ; E5 tự động trên board lab ở ≥ A3; E6 và E9 giữ nguyên; E7 append-only; E8 không đổi (tầng đồng không thành fact); E10 tự tải khi tên miền trong danh sách tin cậy. Nguyên tắc KAD không đổi: tầng tin cậy của fact phụ thuộc nguồn và bằng chứng, không phụ thuộc ai duyệt — "auto-reviewed by policy" ghi rõ trong confirmed_by để kiểm toán.'));
c.push(H1('6. Tổ chức tri thức'));"""))
R.append(("""c.push(H2('6.7. Vòng đời, dọn dẹp và tái kiểm định'));""", """c.push(H2('6.6b. Ngữ cảnh cho tầng hiểu lệnh (v1.1)'));
c.push(P('Orchestrator dùng một composer riêng, nhỏ hơn: C0 mô tả năng lực (top-k theo từ khóa của lệnh, ≤ 60 token/năng lực, ≤ 1.200 token), C1′ trạng thái dự án tóm tắt (dự án mở, board, hộ chiếu, feature failing đầu, mục chờ), C2′ preferences.yaml và defaults, C7 hai lượt gần nhất. Không đưa fact phần cứng vào bước hiểu lệnh — grounding tra store trực tiếp (deterministic) thay vì nhờ mô hình nhớ.'));
c.push(H2('6.7. Vòng đời, dọn dẹp và tái kiểm định'));"""))
R.append(("""c.push(H1('7. Ví dụ xuyên suốt: BME280 trên WeAct BlackPill F411'));""", """c.push(H2('6.9. Hiển thị và truy hồi: bản đồ tri thức và RAG (v1.1)'));
c.push(P('Nhóm năng lực view.* là "mặt tiền" của kiến trúc tri thức này trong GEditor. **Bản đồ tri thức** (view.kg_map, kg_focus) vẽ đồ thị §6.3 với mã màu theo tier (vàng/bạc/đồng), status (normalized/reviewed/verified/superseded/conflict) và lớp lưu trữ (L-A…L-E); **nguồn gốc** (view.provenance) đi ngược cạnh CITES/SUPERSEDES tới Source và mở đúng locator (trang/bbox) trong PDF; **độ phủ** (view.coverage_map) so cấu trúc hộ chiếu (ngoại vi/thanh ghi/chân) với fact hiện có và AcquisitionRequest đang mở; **tác động** (view.impact_map) là kg.impact + req.change_impact hiển thị. **Hỏi–đáp RAG** (view.rag_ask) truy hồi lai: chỉ mục từ khóa (FTS5) + vector (embedding qua Gateway) trên RagChunk (≤ 800 token, cắt theo bố cục Docling/OCR/mã, gắn subject IRI xuất hiện trong chunk) + lan tỏa đồ thị 2 bước từ các IRI đó (Graph-RAG [37]); câu trả lời bắt buộc có citations tới Source/locator và trace (view.rag_trace: chunk, điểm, đường lan tỏa). Câu hỏi ngoài phạm vi kho → "không tìm thấy" (nguyên tắc K9 chỉ đề xuất). Chỉ mục nằm ở L-E (cache, không commit) và tái dựng được từ Source; view.rag_compare xếp câu trả lời theo tầng nguồn để lộ mâu thuẫn datasheet/errata/cộng đồng.'));
c.push(T([2000, 3300, 4000], ['Loại tri thức', 'Nhóm năng lực tạo/làm giàu', 'Nhóm năng lực hiển thị/dùng'], [
  ['K1 ISA, K2/K2′ chip, K3 board, K4 linh kiện', 'archive, search, extract, passport, board, discover (E12)', 'view (map, provenance, coverage), passport.query, kg.*, code (constant-guard)'],
  ['K5 skill, K5′ mẫu dự án', 'registry, bench, search.reference_projects', 'memory.compose (C3), project.create, sim'],
  ['K6 ràng buộc dự án', 'project, board.constraints, arch.map_hw', 'plan, code, policy'],
  ['K7 bằng chứng', 'target, debug, measure, bench, discover, policy (decision_log)', 'view.timeline, report, policy.learn_thresholds'],
  ['K8 vai trò/quy tắc', 'policy, chat (prompts)', 'memory.compose (C1), chat.*'],
  ['K9 tham số mô hình', '—', 'Mọi vai trò sinh; luôn đối chiếu K2–K6'],
  ['K10 tri thức kỹ nghệ', 'req, arch, diagram, doc', 'view.impact_map, doc.sync, diagram.sync, report'],
]));
c.push(SP());
c.push(H1('7. Ví dụ xuyên suốt: BME280 trên WeAct BlackPill F411'));"""))
R.append(("""  ['K7', 'Ledger lượt gọi mô hình (chi phí, token, hash)', 'debug_session, tool_report, badges (M2–M3)'],
]));""", """  ['K7', 'Ledger lượt gọi mô hình (chi phí, token, hash)', 'debug_session, tool_report, badges, decision_log, discovery (M1–M3)'],
  ['K5′, K10 (v1.1)', 'Chưa có', 'M1: registry templates, requirement/module/adr/diagram/doc_artifact; view.kg_map, rag_index (M1); diagram.sync, doc.sync (M3)'],
]));"""))
miss = 0
for a, b in R:
    if a not in s: print("KAD MISSING:", a[:70]); miss += 1
    s = s.replace(a, b)
open(p, "w").write(s)

# ---- APD ----
p = "apd.js"; s = open(p).read()
R = []
R.append(("kicker: 'EIDE — EMBEDDED IDE · BỘ HỒ SƠ THIẾT KẾ v1.0', footer: 'EIDE — Bộ hồ sơ thiết kế v1.0',", "kicker: 'EIDE — EMBEDDED IDE · BỘ HỒ SƠ THIẾT KẾ v1.1', footer: 'EIDE — Bộ hồ sơ thiết kế v1.1',"))
R.append(("code: 'EIDE-APD-08', short: 'Chính sách tự chủ', version: '1.0',", "code: 'EIDE-APD-08', short: 'Chính sách tự chủ', version: '1.1',"))
R.append(("['Phiên bản', '1.0 — thay thế mô hình \"7 cổng luôn hỏi\" của HKW-PDA-00 §P3 và BPD-06']", "['Phiên bản', '1.1 — thay thế mô hình \"7 cổng luôn hỏi\" của HKW-PDA-00 §P3 và BPD-06; gắn với Danh mục năng lực v1.1']"))
R.append(("  history: [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu']],", "  history: [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu'], ['1.1', '05/09/2026', 'Vũ Trí Công', 'Thêm §3.1 ánh xạ lớp rủi ro/mức tự chủ vào 228 năng lực (cột R, Mức, Hỏi kỹ sư khi của Danh mục); §4.1 quyết định ở mức năng lực (CapabilityRouter); §8 cập nhật trạng thái thay đổi đã thực hiện trong bộ hồ sơ v1.1; mã hkw-core → eide']],"))
R.append(("""c.push(H1('4. Quy tắc tự phê duyệt theo cổng'));""", """c.push(H2('3.1. Ánh xạ vào Danh mục năng lực (v1.1)'));
c.push(P(`Danh mục năng lực [6] gắn cho mỗi năng lực ba cột trực tiếp từ chính sách này: **Lớp rủi ro** (R0–R4), **Mức** (T1 AI làm trọn — tự động ở mức tự chủ tối thiểu của lớp rủi ro; T1* tự làm khi hàm quyết định có bằng chứng, nếu không ASK; T2 AI làm — người duyệt, tức luôn ASK ở cổng tương ứng; T3 người làm — tác tử chỉ chuẩn bị) và **Hỏi kỹ sư khi** (điều kiện ASK cụ thể của năng lực, là đầu vào cho hàm quyết định). Thống kê: R0 ${count(x => x.risk.startsWith('R0'))}, R1 ${count(x => x.risk.startsWith('R1'))}, R2 ${count(x => x.risk.startsWith('R2'))}, R3 ${count(x => x.risk.startsWith('R3'))}, R4 ${count(x => x.risk.startsWith('R4'))}; T1 ${count(x => x.tier === 'T1')}, T1* ${count(x => x.tier === 'T1*')}, T2 ${count(x => x.tier === 'T2')}, T3 ${count(x => x.tier === 'T3')}. Hai năng lực R4 (target.erase_fuse, registry.publish công khai) và ba năng lực T3 (policy.emergency_stop, target.erase_fuse, kg.resolve_conflict khi người chọn) là ranh giới cứng của tự động hóa.`));
c.push(T([2200, 2400, 4600], ['Nhóm', 'Năng lực T1* / T2 tiêu biểu', 'Điều kiện ASK (từ cột "Hỏi kỹ sư khi")'], [
  ['kg', 'kg.review_facts (T1*), kg.resolve_conflict (T2)', 'confidence thấp; mâu thuẫn — người chọn fact hiện hành'],
  ['plan / code', 'plan.create (T1*), code.merge (T1*)', 'Đổi kiến trúc; tài nguyên mới; blocker; chạm ISR/linker; ngoài phạm vi'],
  ['req / arch', 'req.prioritize, arch.style_select, arch.compare (T1*)', 'Đổi ưu tiên M↔S; đổi kiểu kiến trúc dự án đã có; chọn phương án cuối'],
  ['target / debug', 'target.flash, target.probe_write, debug.experiment (T1*); target.erase_fuse (T3)', 'Board không lab; động cơ; xóa flash/fuse luôn hỏi'],
  ['discover', 'discover.board_match (T1*); discover.link_speed (T1, ASK khi vượt datasheet)', 'Nhiều ứng viên điểm gần nhau; nấc tốc độ vượt fact có nguồn'],
  ['diagram / doc', 'diagram.sync, doc.sync (T1*)', 'Lệch lớn giữa lược đồ/tài liệu và mã'],
  ['registry / policy', 'registry.publish (T1*, R2/R4), policy.permit, policy.set_autonomy, policy.learn_thresholds (T2)', 'Phát hành công khai; nới lỏng mức/ngưỡng luôn cần người'],
  ['env', 'env.install_tool (T1 trong danh sách tin cậy; ASK ngoài danh sách hoặc cần quyền hệ thống)', 'Gói lạ; sudo/driver ký'],
]));
c.push(SP());
c.push(H1('4. Quy tắc tự phê duyệt theo cổng'));"""))
R.append(("""c.push(H1('5. Leo thang, cửa sổ hoàn tác và dừng khẩn'));""", """c.push(H2('4.1. Quyết định ở mức năng lực (v1.1)'));
c.push(P('Trong hiện thực, hàm quyết định không chỉ chạy ở bảy cổng mà ở **mọi lời gọi năng lực** thông qua CapabilityRouter.invoke (SDD-04 §4.0): `decide(Action{cap, args, gate?}, ctx)` xét lần lượt (1) lớp rủi ro của năng lực và danh sách trắng, (2) mức tự chủ hiệu lực (dự án → board → loại hành động), (3) quy tắc của cổng nếu năng lực gắn cổng (G-SRC cho search.fetch, G-FACT cho kg.review_facts, G1 cho plan.create, G3 cho code.merge, G-OPS cho target.*, G4 cho target.observe, G5 cho registry.publish), (4) điều kiện "Hỏi kỹ sư khi" riêng của năng lực. Năng lực R0 đi thẳng. Kết quả và đặc trưng tình huống ghi vào decision_log — đây cũng là dữ liệu cho §6.'));
c.push(H1('5. Leo thang, cửa sổ hoàn tác và dừng khẩn'));"""))
R.append(("""c.push(H1('8. Thay đổi cần thực hiện trong bộ hồ sơ và mã'));
c.push(T([2400, 6900], ['Tài liệu / thành phần', 'Thay đổi'], [""", """c.push(H1('8. Thay đổi trong bộ hồ sơ và mã (trạng thái v1.1)'));
c.push(P('Các thay đổi dưới đây đã được thực hiện trong bộ hồ sơ v1.1 (cột "Thay đổi" giữ nguyên làm đặc tả; trạng thái ghi trong ngoặc). Mục còn lại: mã eide-core M1 và mockup.'));
c.push(T([2400, 6900], ['Tài liệu / thành phần', 'Thay đổi'], ["""))
R.append(("['PDA-00 P3', 'Đổi thành:", "['PDA-00 P3 (đã làm v1.1)', 'Đổi thành:"))
R.append(("['URD-01', 'Thêm UR-QT-06", "['URD-01 (đã làm v1.1)', 'Thêm UR-QT-06"))
R.append(("['SRS-02', 'Thêm FR-AUT-01…06", "['SRS-02 (đã làm v1.1)', 'Thêm FR-AUT-01…06"))
R.append(("['SAD-03', 'GateService → PolicyGateService", "['SAD-03 (đã làm v1.1)', 'GateService → PolicyGateService"))
R.append(("['SDD-04', 'autonomy.yaml", "['SDD-04 (đã làm v1.1)', 'autonomy.yaml"))
R.append(("['STP-05', 'TC mới:", "['STP-05 (đã làm v1.1: TC-51…58)', 'TC mới:"))
R.append(("['BPD-06, KAD-07 §5', 'Cột", "['BPD-06, KAD-07 §5 (đã làm v1.1)', 'Cột"))
R.append(("['Use case Excel', 'Cột mới", "['Use case Excel (đã làm: sheet 7 mức tự chủ, cột Mức tự chủ)', 'Cột mới"))
R.append(("['Mockup', 'Bỏ nhãn", "['Mockup (chưa làm)', 'Bỏ nhãn"))
R.append(("['hkw-core (M1)', 'core/engine/policy.py", "['eide-core (M1, chưa làm)', 'core/engine/policy.py"))
R.append(("const refs = ['V. T. Công, \"Bộ hồ sơ thiết kế HKW/EIDE v1.0 (PDA-00 … KAD-07),\" 05/09/2026.',", "const refs = ['V. T. Công, \"Bộ hồ sơ thiết kế EIDE v1.1 (PDA-00 … DPS-09),\" 05/09/2026.',"))
R.append(("'Adancurusul, \"embedded-debugger-mcp,\" GitHub, 2026 (quyền theo phiên cho write/erase).'];", "'Adancurusul, \"embedded-debugger-mcp,\" GitHub, 2026 (quyền theo phiên cho write/erase).', 'V. T. Công, \"EIDE — Danh mục năng lực đầy đủ v1.1 (EIDE_Danh_muc_Nang_luc.xlsx): 228 năng lực, 26 nhóm,\" 05/09/2026.', 'V. T. Công, \"EIDE-DPS-09 — Chính sách hội thoại và suy luận ý định v1.0,\" 05/09/2026.'];"))
R.append(("const { REFS } = require('./eide_common');", "const { REFS, count } = require('./eide_common');"))
for a, b in R:
    if a not in s: print("APD MISSING:", a[:70]); miss += 1
    s = s.replace(a, b)
open(p, "w").write(s); print("missing", miss)
