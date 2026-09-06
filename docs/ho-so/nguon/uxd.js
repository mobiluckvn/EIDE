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
 ['8', 'ReqArch (Yêu cầu & kiến trúc)', 'ReqSet; khả thi; issue; ADR; HwMap; ngân sách', 'req.*, arch.*', 'Mới v1.2'],
 ['9', 'DiagramView (Lược đồ)', 'Mã ↔ hình 6 ngôn ngữ; lint; sync; chèn tài liệu', 'diagram.*', 'Mới v1.2'],
 ['10', 'Doc (Tài liệu)', 'Bộ tài liệu; mục stale; style check; xuất', 'doc.*, report.*', 'Mới v1.2'],
 ['11', 'PlanDiff (Kế hoạch & mã)', 'Kế hoạch có trích dẫn; diff; 4 cổng; review; auto-merge', 'plan.*, code.review, code.merge', 'Giữ + nhãn chính sách'],
 ['12', 'Code (Mã nguồn)', 'Hằng số có fact hover; constant-guard; gửi G3', 'code.*', 'Giữ'],
 ['13', 'Sim (Mô phỏng)', 'Kịch bản; plant; SIL/HIL', 'sim.*', 'Giữ (SIM-20)'],
 ['14', 'Discovery (Dò board)', 'Cổng/probe/ID/tốc độ/bus/nguồn; target.yaml', 'discover.*', 'Mới v1.2'],
 ['15', 'LogAssist (Log & serial)', 'Log lớn; hỏi tại dòng; serial', 'debug.log_stats, debug.ask_at, target.serial', 'Giữ'],
 ['16', 'Debug (Gỡ lỗi probe)', 'EvidencePack; giả thuyết; thí nghiệm', 'debug.*, target.probe_*', 'Giữ'],
 ['17', 'ToolForge (Công cụ tự tạo)', 'Danh sách công cụ; mã; hiệu ứng; test; thăng cấp', 'tool.*', 'Mới v1.2'],
 ['18', 'Bench', 'Tác vụ CF/BF/BC; huy hiệu', 'bench.*', 'Giữ'],
 ['19', 'Registry', 'Gói; template; publish', 'registry.*', 'Giữ'],
 ['20', 'Models (Mô hình & chi phí)', 'Vai trò → mô hình; ngân sách; không offline mặc định', 'policy, gateway', 'Cập nhật'],
 ['21', 'Env (Môi trường)', 'doctor; cài tự động; tools.lock', 'env.*', 'Giữ'],
 ['22', 'FlowMap', 'Bản đồ luồng P0–P7', '—', 'Giữ'],
 ['23', 'Trạng thái/khung (Main shell)', 'Sidebar 20 mục; thanh trạng thái tự chủ; dừng khẩn; tab tệp', 'policy.set_autonomy, emergency_stop', 'Cập nhật v1.2'],
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
  ['Hàng đợi (QueueList)', 'Hai nhóm; mục có tag cổng, tóm tắt, rủi ro, lý do quy tắc, hạn hoàn tác; hành động duyệt/từ chối/hoàn tác/hàng loạt', 'queue.list; gate.decide; undo.apply'],
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
// `primary` là đỏ PTIT. UXD-13 ghi "gần đúng, xác nhận với bộ nhận diện chính thức" — WI-258
// là việc xác nhận ấy; tới khi có xác nhận thì đây là mã dùng chính thức trong sản phẩm.
const TOKENS = {
  color: {
    primary: '#B8121F',      // đỏ PTIT — điều hướng, hành động chính
    accent: '#F2B705',       // vàng sao — việc cần người, cảnh báo nhẹ
    secondary: '#2F4858',    // xám xanh — hành động phụ, tác tử
    ok: '#0b6b52', okBg: '#dff5ee',
    warn: '#7a5200', warnBg: '#fff0cc',
    bad: '#7a0c0c', badBg: '#fde3e1',
    info: '#B8121F', infoBg: '#e6effa',
    bg: '#f4f6f9', surface: '#ffffff', border: '#e1e6ee',
    text: '#1b2430', muted: '#5b6b7f',
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
  'color.primary      #B8121F  (đỏ PTIT — điều hướng, hành động chính; gần đúng, xác nhận với bộ nhận diện chính thức)',
  'color.accent       #F2B705  (vàng sao — việc cần người, cảnh báo nhẹ)',
  'color.secondary    #2F4858  (xám xanh — hành động phụ, tác tử)',
  'color.ok #0b6b52/#dff5ee · color.warn #7a5200/#fff0cc · color.bad #7a0c0c/#fde3e1 · color.info #B8121F/#e6effa',
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
