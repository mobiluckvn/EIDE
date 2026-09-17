const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas, CAPS } = require('./eide_common');
const m = metaNew('EIDE-UXD-13', 'Đặc tả UI/UX', 'ĐẶC TẢ GIAO DIỆN VÀ TRẢI NGHIỆM NGƯỜI DÙNG (UXD)',
  'Nguyên tắc trải nghiệm, kho 23 màn hình (mockup v1.2), sơ đồ điều hướng, thư viện thành phần và trạng thái, tương tác từng màn hình ánh xạ tới năng lực, token thiết kế PTIT, phím tắt, thông báo, khả năng tiếp cận',
  [['Tài liệu trước', 'EIDE-DPS-09 §6, EIDE-APD-08 §8, Danh mục năng lực v1.2, EIDE-API-15 §2'], ['Tệp kèm', 'EIDE-UI-v1.2/ (23 .dc.html, canvas.json, eide-workbench-v12-gallery.html, gen.py để sinh lại, ảnh chụp shot_*.png)'], ['Dùng khi', 'Lập trình plugin GEditor (Swift); viết TC giao diện; đánh giá khả dụng']],
  'Phát hành lần đầu — bổ sung lĩnh vực L28; mockup cập nhật theo v1.1/v1.2');
const c = [];
c.push(H1('1. Nguyên tắc trải nghiệm'));
c.push(T([600, 2700, 6000], ['#', 'Nguyên tắc', 'Thể hiện'], [
  ['U1', 'Lệnh là giao diện chính', 'ChatPanel là màn hình mặc định khi mở dự án; mọi màn hình khác mở được từ lệnh hoặc từ kết quả trong chat; ô lệnh có gợi ý "/" liệt kê năng lực có `ui`'],
  ['U2', 'Làm rồi báo cáo, nhìn thấy được', 'Thanh trạng thái tự chủ luôn hiện: mức, số việc tự làm, số chờ, hạn hoàn tác; hàng đợi tách "chờ tôi" và "đã làm — hoàn tác được"; mỗi việc tự làm có lý do (mã quy tắc) và nút hoàn tác'],
  ['U3', 'Một câu hỏi, có mặc định, có đếm ngược', 'Thẻ câu hỏi gộp: phương án đánh số, phương án mặc định tô đậm, đếm ngược timeout, ghi nhớ lựa chọn (D3, D8)'],
  ['U4', 'Mọi con số có nguồn, một nhấp mở nguồn', 'Fact hiển thị kèm tier và trích dẫn; nhấp → provenance mở đúng trang PDF/bbox; hằng số trong mã hover hiện fact'],
  ['U5', 'Mọi nút là một năng lực', 'Nút bấm gọi caps.invoke; cùng chính sách/nhật ký với tác tử; trạng thái pending hiển thị như mục "chờ tôi"'],
  ['U6', 'Dừng khẩn ở mọi nơi', 'Nút "■ Dừng khẩn" ở sidebar và phím tắt ⌘⇧.; hạ A0 < 1 s; thông báo rõ việc gì bị hủy'],
  ['U7', 'Mật độ kỹ thuật, sáng, PTIT', 'Bàn làm việc mật độ cao, nền sáng; đỏ PTIT cho điều hướng/hành động chính, vàng cho việc cần người, xám xanh cho hành động phụ; IBM Plex Sans/Mono'],
  ['U8', 'Tiếng Việt trước', 'Nhãn tiếng Việt, định danh kỹ thuật giữ nguyên; thuật ngữ Anh có tooltip giải nghĩa (CON-28 glossary)'],
  ['U9', 'Không giấu trạng thái rỗng/lỗi/chờ', 'Mọi panel có ba trạng thái thiết kế sẵn (§5); lỗi hiện mã API-15 và hành động gợi ý'],
  ['U10', 'Khả năng tiếp cận', 'Tương phản ≥ 4,5:1 (WCAG 2.2 AA [56]); điều hướng bàn phím toàn bộ; không dựa vào màu đơn lẻ (kèm nhãn/biểu tượng)'],
]));
c.push(SP());
c.push(P('Cơ sở: mười heuristic khả dụng của Nielsen [54] (hiển thị trạng thái hệ thống ↔ U2, kiểm soát và tự do ↔ U6/hoàn tác, nhất quán ↔ U5, phòng lỗi ↔ U3, nhận biết thay vì nhớ ↔ gợi ý "/"), Human Interface Guidelines macOS [55] cho bố cục cửa sổ/sidebar/toolbar, và WCAG 2.2 [56].'));
c.push(H1('2. Kho màn hình (23) và ánh xạ năng lực'));
const S = [
 ['1', 'Chat (mặc định)', 'Lệnh NL; thẻ ý hiểu; câu hỏi gộp; tiến độ chuỗi; báo cáo; trạng thái tự chủ; ngữ cảnh lượt', 'chat.*, policy.*, memory.compose', 'Cập nhật v1.2'],
 ['2', 'Main (Tổng quan)', 'KPI dự án; feature; gate mở; target đang cắm', 'project.status, target.detect', 'Cập nhật'],
 ['3', 'ReviewQueue (Chờ tôi / Đã làm)', 'Hai danh sách; chi tiết mục; lý do quy tắc; duyệt/từ chối/hoàn tác', 'policy.undo_window, kg.review_facts, gate.decide', 'Cập nhật v1.2'],
 ['4', 'Ingest (Nhập tài liệu)', 'Kéo thả; zip lồng; phân loại; tiến độ trích; nguồn tự tải', 'archive.*, ingest.*, extract.*, search.fetch', 'Giữ + nhãn chính sách'],
 ['5', 'Passport (Hộ chiếu chip)', 'Nhóm/tier/nguồn; nhảy PDF; auto-reviewed', 'passport.*, view.provenance', 'Giữ'],
 ['6', 'Board (Hộ chiếu mạch)', 'Net/pin; xung đột; đánh dấu lab', 'board.*, diagram.pinmap', 'Giữ'],
 ['7', 'Graph → RagAsk (Bản đồ tri thức & hỏi đáp)', 'Bản đồ màu tier/status; nguồn gốc; hỏi–đáp có trích dẫn; trace', 'view.*', 'Mới v1.2 (thay Graph)'],
 ['8', 'NhatKy (Nhật ký hoạt động)', 'Dòng thời gian MỌI sự kiện sổ cái, lọc theo nhóm; bấm một dòng → mở màn chuyên đề; trạng thái chuỗi băm', 'view.timeline', 'Mới v1.x (DEV-107) — màn duy nhất trả lời câu "tác tử vừa làm gì"'],
 ['9', 'XungDot (Xung đột tri thức)', 'Hai bên đặt CÙNG HÀNG, mỗi bên kèm nguồn/tầng/độ tin; chọn A, chọn B, hoặc cả hai có điều kiện', 'kg.conflicts, kg.resolve_conflict', 'Mới v1.x (DEV-109) — trước đó kg.conflicts không gán màn nào, xem DEV-094'],
 ['10', 'LamRo (Làm rõ yêu cầu)', 'Câu tác tử nói lại cách nó hiểu KÈM chuỗi bước sẽ chạy; câu hỏi gộp có phương án và mặc định; nút "Đúng — làm đi" / "Sửa ý hiểu"', 'chat.restate, chat.clarify, chat.parse_intent', 'Mới v1.x (DEV-109) — trước đó chỉ là một thẻ trôi trong dòng chat'],
 ['11', 'ReqArch (Yêu cầu & kiến trúc)', 'ReqSet; khả thi; issue; ADR; HwMap; ngân sách', 'req.*, arch.*', 'Mới v1.2'],
 ['12', 'DiagramView (Lược đồ)', 'Mã ↔ hình 6 ngôn ngữ; lint; sync; chèn tài liệu', 'diagram.*', 'Mới v1.2'],
 ['13', 'Doc (Tài liệu)', 'Bộ tài liệu; mục stale; style check; xuất', 'doc.*, report.*', 'Mới v1.2'],
 ['14', 'PlanDiff (Kế hoạch & mã)', 'Kế hoạch có trích dẫn; diff; 4 cổng; review; auto-merge', 'plan.*, code.review, code.merge', 'Giữ + nhãn chính sách'],
 ['15', 'Code (Mã nguồn)', 'Hằng số có fact hover; constant-guard; gửi G3', 'code.*', 'Giữ'],
 ['16', 'Sim (Mô phỏng)', 'Kịch bản; plant; SIL/HIL', 'sim.*', 'Giữ (SIM-20)'],
 ['17', 'Discovery (Dò board)', 'Cổng/probe/ID/tốc độ/bus/nguồn; target.yaml', 'discover.*', 'Mới v1.2'],
 ['18', 'LogAssist (Log & serial)', 'Log lớn; hỏi tại dòng; serial', 'debug.log_stats, debug.ask_at, target.serial', 'Giữ'],
 ['19', 'Debug (Gỡ lỗi probe)', 'EvidencePack; giả thuyết; thí nghiệm', 'debug.*, target.probe_*', 'Giữ'],
 ['20', 'ToolForge (Công cụ tự tạo)', 'Danh sách công cụ; mã; hiệu ứng; test; thăng cấp', 'tool.*', 'Mới v1.2'],
 ['21', 'Bench', 'Tác vụ CF/BF/BC; huy hiệu', 'bench.*', 'Giữ'],
 ['22', 'Registry', 'Gói; template; publish', 'registry.*', 'Giữ'],
 ['23', 'Models (Mô hình & chi phí)', 'Vai trò → mô hình; ngân sách; không offline mặc định', 'policy, gateway', 'Cập nhật'],
 ['24', 'Env (Môi trường)', 'doctor; cài tự động; tools.lock', 'env.*', 'Giữ'],
 ['25', 'FlowMap (Hành trình & cổng)', 'Bản đồ luồng P0–P7; quyết định của cổng theo từng bước', 'policy.decide', 'Sửa 17/09: trước ghi `—` trong khi panel nạp mặc định `policy.decide`. Lưu ý: bảng này lấy màn ĐẦU TIÊN khớp, mà màn 1 đã nhận `policy.*`, nên khai ở đây KHÔNG tự định tuyến được — xem DEV-122'],
 ['26', 'Trạng thái/khung (Main shell)', 'Điều hướng theo nhóm (26 màn); thanh trạng thái tự chủ; dừng khẩn; tab tệp', 'policy.set_autonomy, policy.emergency_stop', 'Cập nhật v1.2'],
];
c.push(T([500, 2600, 3200, 2200, 800], ['#', 'Màn hình', 'Nội dung chính', 'Năng lực gọi', 'v1.2'], S, { size: 19 }));
c.push(SP());
c.push(P('Ảnh chụp và mã HTML của 23 màn hình nằm trong `EIDE-UI-v1.2/` (mở `eide-workbench-v12-gallery.html`); màn hình sinh từ `gen.py` nên mọi sửa đổi thiết kế làm ở mã và sinh lại.'));
c.push(H1('3. Sơ đồ điều hướng'));
c.push(...CODE([
  'Mở dự án ──► Chat (mặc định)',
  '   Chat ──lệnh/kết quả──► bất kỳ màn hình (liên kết trong thẻ báo cáo: "xem ReqSet", "mở Lược đồ", "mở hàng đợi")',
  '   Sidebar (20 mục, thứ tự theo vòng đời): Chat · Tổng quan · Chờ tôi/Đã làm · Nhập tài liệu · Hộ chiếu chip · Hộ chiếu mạch · Bản đồ tri thức & hỏi đáp · Yêu cầu & kiến trúc · Lược đồ · Tài liệu · Kế hoạch & mã · Mã nguồn · Mô phỏng · Dò board · Log & serial · Gỡ lỗi probe · Công cụ tự tạo · Benchmark · Registry · Mô hình & môi trường',
  '   Thanh trạng thái (mọi màn hình): nhấp "chờ anh" → ReviewQueue(ask); "hoàn tác được" → ReviewQueue(done); "target" → Discovery; "chi phí" → Models',
  '   Từ fact (bất kỳ đâu) ──nhấp──► Provenance (panel trượt) ──► PDF trang/bbox (GEditor)',
  '   Từ hằng số trong Code ──hover──► fact; ──nhấp──► Provenance',
  '   Từ lược đồ ──nút──► module (ReqArch) | state (Code FSM) | linh kiện (Board)',
  '   Từ mục ASK ──"Vì sao hỏi anh"──► quy tắc POL-17 + đặc trưng; ──"Sửa ngưỡng"──► Models/policy (cần ký)',
  '   Dừng khẩn: sidebar + ⌘⇧. ở mọi nơi → hộp xác nhận 1 nút "Dừng" (không cần gõ) → thanh trạng thái đỏ "A0 · đã dừng" cho tới khi người đặt lại',
]));
c.push(SP());
c.push(H1('4. Thư viện thành phần'));
c.push(T([2200, 4100, 3000], ['Thành phần', 'Nội dung / biến thể', 'Sự kiện → năng lực'], [
  ['Thẻ ý hiểu (RestateCard)', 'Tiêu đề "Tôi hiểu là…"; văn bản 1–2 câu; danh sách bước rút gọn; liên kết "Sửa ý hiểu" (mở ô lệnh với văn bản gợi ý)', 'event.chat.restated; sửa → chat.send'],
  ['Thẻ câu hỏi (QuestionCard)', 'Viền vàng; câu hỏi; phương án đánh số (nút; mặc định tô đậm); đếm ngược mm:ss; nhãn "ghi nhớ: <key>"; gõ số 1–9 để chọn', 'event.chat.question → chat.answer; timeout → mặc định'],
  ['Thẻ tiến độ chuỗi (RunProgress)', 'Chip nút theo trạng thái (xong/đang/chờ/hỏi/song song); nhấp nút → chi tiết CapabilityRun; hủy nút', 'event.run.progress; job.cancel'],
  ['Thẻ báo cáo (ReportCard)', 'Bốn mục cố định: Đã làm / Chờ anh / Hoàn tác được đến / Chi phí; mỗi mục có liên kết', 'event.chat.report'],
  ['Thanh tự chủ (AutonomyBar)', 'Mức (A0–A4) · N việc tự làm · M chờ · hạn hoàn tác; đỏ khi dừng; nhấp mở popover đặt mức (nới lỏng → cần ký)', 'autonomy.get/set; event.autonomy.changed'],
  ['Nút dừng khẩn (StopButton)', 'Đỏ viền, luôn thấy; xác nhận 1 nút; ⌘⇧.', 'stop'],
  ['Hàng đợi (QueueList)', 'Hai nhóm; mục có tag cổng, tóm tắt, rủi ro, lý do quy tắc, hạn hoàn tác; hành động duyệt/từ chối/hoàn tác/hàng loạt. Duyệt hàng loạt CHỈ gom các mục cùng cổng VÀ cùng quy tắc, và phải hiện số mục trong nhóm trước khi bấm — gom theo tiêu chí khác là mời người duyệt một đống thay vì một loại quyết định, và khi ấy nút hàng loạt trở thành cách nhanh nhất để đồng ý với thứ mình chưa đọc (DEV-050)', 'queue.list; gate.decide; undo.apply'],
  ['Bảng fact (FactTable)', 'Cột subject/predicate/giá trị/tier/nguồn; chọn nhiều; tô mâu thuẫn; nhấp nguồn → Provenance', 'passport.query; kg.review_facts'],
  ['Panel nguồn gốc (ProvenancePanel)', 'Chuỗi nguồn → trang/bbox → ảnh cắt → người/policy duyệt → supersede; nút mở PDF', 'view.provenance; view.doc_side_by_side'],
  ['Panel đồ thị (GraphPanel)', 'Canvas zoom/pan; màu tier/status/lớp; bộ lọc; nhấp nút → focus; xuất', 'view.kg_map/kg_focus/export_map'],
  ['Khung lược đồ (DiagramFrame)', 'Chia đôi mã ↔ hình; chọn ngôn ngữ; lint inline; nút sync; chèn tài liệu', 'diagram.render/lint/sync; doc.embed_diagram'],
  ['Thẻ nhiệm vụ mô phỏng/HIL (EvidenceCard)', 'Kỳ vọng ↔ quan sát ↔ bằng chứng (hash); auto-verified/ASK', 'target.observe; kg.evidence'],
  ['Thẻ công cụ (ToolCard)', 'Tên, hiệu ứng khai báo → lớp rủi ro, test, số lần dùng; nút chạy/sửa/thăng cấp/vô hiệu', 'tool.*'],
  ['Thông báo (Toast/Notice)', 'Mức info/warn/error với mã lỗi API-15 và hành động gợi ý; không tự biến mất với error', 'event.notice'],
  ['Ô lệnh (CommandBox)', 'Nhập nhiều dòng; "/" gợi ý năng lực (tên + một câu); đính kèm; Enter gửi; lịch sử ↑↓', 'chat.send; caps.list'],
]));
c.push(SP());
c.push(H1('5. Trạng thái bắt buộc của mỗi panel'));
c.push(T([1800, 3700, 3800], ['Trạng thái', 'Hiển thị', 'Ví dụ'], [
  ['Rỗng', 'Một câu nói rõ vì sao rỗng + một hành động (thường là một lệnh gợi ý)', 'Bản đồ tri thức rỗng: "Chưa có hộ chiếu nào — thả tài liệu hoặc gõ: tạo dự án cho chip STM32F411"'],
  ['Đang chờ (loading/pending)', 'Skeleton + tên năng lực đang chạy + nút hủy nếu là job; pending do ASK hiển thị như mục hàng đợi kèm liên kết', '"env.install renode ▶ 2/5 phút" · "Đang chờ anh: G-OPS nạp board robot-ctrl"'],
  ['Lỗi', 'Mã + câu tiếng Việt + hành động; giữ dữ liệu cũ nếu có', '"E4002 Không thấy board — Dò lại | Xem hướng dẫn kết nối"'],
  ['Hoàn tác được', 'Nhãn ↩ với hạn; sau hạn nhãn mờ', 'Mục merge m_0455 ↩ 23h'],
  ['Lỗi thời (stale)', 'Viền vàng + lý do (fact/mã đổi) + nút cập nhật', 'Mục 3.4 SRS sau khi fact f_9e0f đổi'],
]));
c.push(SP());
c.push(H1('6. Tương tác chi tiết theo màn hình (trích)'));
c.push(H2('6.1. Chat'));
c.push(T([2400, 3400, 3500], ['Sự kiện người dùng', 'Hệ thống', 'Phản hồi giao diện'], [
  ['Gõ lệnh + Enter', 'chat.send → parse_intent → ground → fill_defaults', 'Thẻ ý hiểu xuất hiện ≤ 1,5 s; nếu unknown: thẻ hỏi lại 1 câu'],
  ['Nhấp phương án / gõ số', 'chat.answer; memory.remember nếu remember_as', 'Thẻ câu hỏi thu gọn thành dòng "Đã chọn: …"; chuỗi tiếp tục'],
  ['Không trả lời tới hết đếm ngược', 'timeout → mặc định', 'Dòng "Hết giờ — dùng mặc định [1]; anh đổi bằng một câu bất kỳ lúc nào"'],
  ['Nhấp "Sửa ý hiểu"', 'Ô lệnh điền văn bản ý hiểu để người sửa', 'Sau gửi: chuỗi cũ hủy phần chưa chạy; nút đã chạy giữ (hoàn tác được)'],
  ['Nhấp nút chuỗi', 'caps.describe + CapabilityRun', 'Panel trượt: tham số, kết quả, lý do chính sách, log, undo'],
  ['Gõ "dừng"', 'stop', 'Toàn cửa sổ viền đỏ 1 s; thanh trạng thái "A0 · đã dừng"'],
  ['Kéo thả tệp vào ô lệnh', 'attachments → slots.path', 'Chip tệp; lệnh gợi ý "dựng tri thức từ …"'],
]));
c.push(SP());
c.push(H2('6.2. Chờ tôi / Đã làm'));
c.push(T([2400, 3400, 3500], ['Sự kiện', 'Hệ thống', 'Giao diện'], [
  ['Chọn mục ASK', 'queue.list chi tiết + rule + features', 'Panel phải: bằng chứng (fact, ToolReport, review), "Vì sao hỏi anh" (mã quy tắc), nút Duyệt/Sửa/Từ chối'],
  ['Duyệt', 'gate.decide approve → năng lực tiếp tục', 'Mục chuyển sang "Đã làm" với nhãn by=human'],
  ['Hoàn tác mục đã làm', 'undo.apply', 'Xác nhận 1 nút; kết quả (revert commit, fact khôi phục, nạp lại) hiện dòng trạng thái'],
  ['Duyệt hàng loạt (fact)', 'kg.review_facts(group, accept)', 'Chỉ cho phép trong cùng nhóm/nguồn; hiện số lượng'],
  ['Nhấp "Sửa ngưỡng"', 'policy.learn_thresholds/apply', 'Mở Models với đề xuất; nới lỏng cần ký'],
]));
c.push(SP());
c.push(H2('6.3. Bản đồ tri thức & hỏi đáp, Lược đồ, Dò board, Công cụ tự tạo'));
c.push(P('Bản đồ: cuộn = zoom, kéo = pan, nhấp nút = focus 2 bước + panel nguồn gốc, phím F = tìm nút, bộ lọc là chip nhấn (tier/status/lớp); hỏi–đáp: Enter hỏi, nhấp [n] mở nguồn ở panel trượt, nút "Vì sao" mở trace, "So sánh nguồn" chạy rag_compare. Lược đồ: sửa mã bên trái → lint tức thì (≤ 300 ms) và render debounce 500 ms; nút "Sync ↔ mã" hiện diff trước khi áp (to_code cần G3 nếu chạm mã). Dò board: tự chạy khi cắm (event.discover.changed); bảng bước với trạng thái; "Nạp fw mới nhất" đi qua G-OPS. Công cụ tự tạo: thẻ công cụ; "Tạo công cụ mới…" mở ô lệnh với mẫu "viết cho anh công cụ …"; chạy hiện sandbox log; thăng cấp mở PR/registry.'));
c.push(H1('7. Token thiết kế'));
// Token là NGUỒN DUY NHẤT cho ba chỗ dùng chúng: 23 mockup HTML, panel EIDE trong GEditor
// (Swift/AppKit), và tài liệu này. Trước đây chúng chỉ nằm trong văn xuôi §7, nên ba chỗ ấy
// đều chép tay — đúng bài học DEV-018. Nay sinh ra `ui/tokens.json`. Xem DEVIATIONS DEV-025.
//
// WI-258 ĐÃ XONG (16/09/2026): chủ sản phẩm đưa tệp nhận diện chính thức
// `docs/logo-ptit-1.svg`, và bảng màu dưới đây nay LẤY TỪ chính tệp ấy thay vì ước lượng.
//
// Năm màu trong logo: `#DE221A` (đỏ biểu tượng, 10 path), `#B89C0E` và `#EFF003` (vàng ngọn
// đuốc), `#BC2626` (đỏ dòng chữ thứ nhất), `#373D4E` (xám xanh dòng chữ thứ hai).
//
// ## Vì sao `primary` KHÔNG phải `#DE221A`
//
// Đo tương phản trên nền `bg #f4f6f9`: `#DE221A` được **4,46** — dưới ngưỡng AA 4,5 mà chính
// `contrastMin` dưới đây khai, và có một bài test đo nó. Chênh 0,04 là chênh vô nghĩa với mắt
// và rất có nghĩa với người đọc màn hình ở độ sáng thấp.
//
// May là bộ nhận diện đã tự giải quyết chuyện này: dòng chữ trong logo KHÔNG dùng `#DE221A` mà
// dùng `#BC2626` — đỏ đậm hơn, đo được **5,63**. Tức PTIT đã chọn sẵn một đỏ cho chữ và một đỏ
// cho hình. Sản phẩm theo đúng phân vai ấy: `primary` (chữ, viền, hành động) lấy đỏ chữ;
// `brand` (nền lớn, biểu tượng, ảnh nhận diện) lấy đỏ hình.
const TOKENS = {
  color: {
    primary: '#BC2626',      // đỏ PTIT dùng cho CHỮ — lấy từ logo chính thức, tương phản 5,63
    brand: '#DE221A',        // đỏ biểu tượng — CHỈ cho mảng lớn và logo (4,46 < AA cho chữ)
    brandGold: '#B89C0E',    // vàng ngọn đuốc trong logo
    brandGoldLight: '#EFF003', // vàng sáng ở tâm ngọn đuốc
    accent: '#F2B705',       // vàng sao — việc cần người, cảnh báo nhẹ
    secondary: '#373D4E',    // xám xanh — lấy từ dòng chữ thứ hai của logo, tương phản 10,0
    // Bốn màu TRẠNG THÁI lấy từ bản demo UX v2.0 (chủ sản phẩm chốt 17/09/2026). Đo được điều
    // đáng giá nhất: bốn màu gần BẰNG NHAU về độ sáng (tỉ số 1,03–1,22 giữa từng cặp), tức
    // chúng phân biệt bằng SẮC chứ không bằng sáng-tối — đúng nguyên tắc DEV-119 rút ra sau khi
    // `info` đỏ bị đọc nhầm thành cảnh báo. Mỗi màu đo trên nền `bg` mới đều ≥ 4,5.
    ok: '#1d7a4f', okBg: '#e7f4ec',
    warn: '#8a5a00', warnBg: '#fdf3dd',
    // `bad` KHÔNG lấy thẳng `--red` của demo. Demo dùng một đỏ cho cả thương hiệu lẫn lỗi, nên
    // một nút hành động chính và một dòng lỗi trông y hệt nhau — cùng hình dạng lỗi mà DEV-119
    // vừa sửa, chỉ soi gương. Lấy `#A31F1F` (chính là `button.pri:hover` của demo): vẫn trong
    // họ đỏ của bản thiết kế, đo 6,89 trên nền, và khác `primary` 1,24 lần — đủ để mắt tách.
    bad: '#A31F1F', badBg: '#FBECEC',
    // `info` là XANH LAM, không phải đỏ.
    //
    // Cặp `info`/`infoBg` vốn khai `#B8121F` trên `#e6effa`: chữ ĐỎ trên nền XANH. Nền đã nói
    // đúng ý định thiết kế ("thông tin" là xanh), chỉ chữ đi lạc sang màu thương hiệu. Hệ quả
    // đo được 16/09/2026 trong một vòng chạy qua giao diện: dòng "chi phí hôm nay 0.0000 USD"
    // hiện màu ĐỎ — người dùng đọc một con số hoàn toàn bình thường như một cảnh báo. Và `info`
    // đỏ chỉ khác `bad #7a0c0c` 1,83 lần tương phản, tức hai trạng thái ngược nhau gần như cùng
    // một màu.
    info: '#1b5fa5', infoBg: '#e9f1fa',
    bg: '#f5f4f2', surface: '#ffffff', border: '#e2e0dc',
    // `border2` — đường kẻ đậm hơn cho mép vùng (mép trên vùng trao đổi, viền thẻ Run). Bản
    // demo phân hai mức đường kẻ; một mức duy nhất làm mọi mép trông ngang nhau và người không
    // đọc được đâu là ranh giới giữa hai VÙNG, đâu là ranh giới giữa hai hàng.
    border2: '#cfcdc8',
    text: '#1b1b1b', muted: '#6b6b6b',
    // `faint` — nhãn nhóm ở cột trái, gợi ý mờ. Demo dùng `#9a9a9a`, đo được **2,56** trên nền
    // của chính nó: TRƯỢT ngưỡng 4,5 mà `contrastMin` ngay dưới đây khai, và nhãn nhóm là chữ
    // 10,5 px in đậm nên không được hưởng ngoại lệ "chữ lớn". Lấy `#707070` — xám nhạt nhất vẫn
    // đạt AA (4,51). Đây là chỗ DUY NHẤT bảng màu demo bị sửa số.
    faint: '#707070',
  },
  font: { ui: 'IBM Plex Sans', uiSize: 13, uiLine: 1.45, mono: 'IBM Plex Mono', monoSize: 12 },
  space: [4, 8, 12, 16, 24],
  radius: [6, 8, 10],
  layout: { sidebar: 212, topbar: 52, statusbar: 26, contentGap: 16 },
  // UXD-13 U10 / WCAG 2.2 AA: tương phản chữ trên nền ≥ 4,5:1. Ghi ra để test kiểm được,
  // chứ không để nó thành một câu trong tài liệu mà không ai đo.
  contrastMin: 4.5,
  darkMode: false,
};
if (!fs.existsSync('ui')) fs.mkdirSync('ui');
fs.writeFileSync('ui/tokens.json', JSON.stringify(TOKENS, null, 2) + '\n');
c.push(...CODE([
  'color.primary      #BC2626  (đỏ PTIT cho CHỮ — lấy từ logo chính thức, tương phản 5,63 trên nền bg)',
  'color.brand        #DE221A  (đỏ biểu tượng — chỉ dùng cho mảng lớn và logo; 4,46 nên KHÔNG dùng cho chữ)',
  'color.brandGold    #B89C0E  · color.brandGoldLight #EFF003  (vàng ngọn đuốc trong logo)',
  'color.accent       #F2B705  (vàng sao — việc cần người, cảnh báo nhẹ)',
  'color.secondary    #373D4E  (xám xanh — lấy từ dòng chữ thứ hai của logo, tương phản 10,0)',
  'color.ok #0b6b52/#dff5ee · color.warn #7a5200/#fff0cc · color.bad #7a0c0c/#fde3e1 · color.info #1e40af/#e6effa (xanh lam — KHÔNG dùng đỏ thương hiệu cho thông tin)',
  'color.bg #f4f6f9 · color.surface #fff · color.border #e1e6ee · color.text #1b2430 · color.muted #5b6b7f',
  'font.ui  IBM Plex Sans 13px/1.45 (macOS fallback -apple-system) · font.mono IBM Plex Mono 12px',
  'space 4/8/12/16/24 · radius 6/8/10 · shadow.window 0 20px 60px rgba(184,18,31,.14)',
  'layout: sidebar 212px · topbar 52px · statusbar 26px · content gap 16px · card padding 12/14',
  'dark mode: chưa hỗ trợ bản đầu (GEditor sáng); token tách riêng để bổ sung',
]));
c.push(SP());
c.push(H1('8. Phím tắt và thông báo'));
c.push(T([2600, 6700], ['Phím', 'Hành động'], [
  ['⌘L', 'Vào ô lệnh (mọi màn hình)'], ['⌘⇧.', 'Dừng khẩn'], ['⌘K', 'Bảng lệnh: tìm năng lực/màn hình'], ['⌘1…⌘9', 'Chuyển 9 màn hình đầu sidebar'], ['⌘⇧Q', 'Hàng đợi chờ tôi'], ['⌘Z trong hàng đợi', 'Hoàn tác mục đã chọn'],
  ['1–9 khi thẻ câu hỏi hiện', 'Chọn phương án'], ['Esc', 'Đóng panel trượt / hủy câu hỏi (dùng mặc định)'], ['⌘⏎ trong DiagramView', 'Render'], ['F trong bản đồ', 'Tìm nút'],
]));
c.push(SP());
c.push(P('Thông báo: (1) thẻ trong chat cho mọi thứ liên quan chuỗi hiện tại; (2) toast góc phải cho sự kiện nền (cắm board, nguồn tự tải, fact tự duyệt) tự ẩn sau 6 s trừ error; (3) thông báo hệ điều hành (notify) chỉ cho leo thang R3/R4, ngân sách < 20%, board lệch hộ chiếu, hoặc chuỗi dài hoàn thành khi cửa sổ không focus; (4) không âm thanh mặc định.'));
c.push(H1('9. Kiểm thử giao diện'));
c.push(T([1000, 3400, 3700, 1200], ['TC', 'Mục tiêu', 'Kỳ vọng', 'Mức'], [
  ['TC-UX-01', 'Chat mặc định và một lệnh', 'Mở dự án → Chat; gõ lệnh Z-01 → thẻ ý hiểu ≤ 1,5 s, thẻ câu hỏi có mặc định và đếm ngược', 'L2'],
  ['TC-UX-02', 'Thanh tự chủ và dừng khẩn', 'Số liệu khớp ledger; ⌘⇧. → A0 < 1 s; viền đỏ; đặt lại cần người', 'L2'],
  ['TC-UX-03', 'Hàng đợi hai loại', 'Mục ASK và mục auto hiển thị đúng nhóm; hoàn tác merge từ giao diện → git revert', 'L2'],
  ['TC-UX-04', 'Provenance', 'Nhấp fact → mở PDF đúng trang/bbox trong GEditor', 'L2'],
  ['TC-UX-05', 'Trạng thái rỗng/lỗi', 'Dự án mới không hộ chiếu → mọi panel có câu rỗng + hành động; rút board → Discovery hiện E4002 + Dò lại', 'L2'],
  ['TC-UX-06', 'Khả năng tiếp cận', 'Tab đi hết mọi nút; tương phản đo ≥ 4,5:1; VoiceOver đọc thẻ câu hỏi', 'L2'],
  ['TC-UX-07', 'Kịch bản chuẩn ≤ 5 bấm', 'Đếm thao tác người từ ledger UI trong kịch bản 17 bước ≤ 5', 'L4'],
  ['TC-UX-08', 'Lược đồ sửa → lint/render', 'Gõ lỗi cú pháp → lint < 300 ms; sửa → render ≤ 1 s', 'L2'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-UXD-13_Dac_ta_UI_UX.docx');
