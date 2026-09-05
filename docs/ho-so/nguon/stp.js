const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-STP-05', 'Kế hoạch kiểm thử', 'KẾ HOẠCH VÀ ĐẶC TẢ KIỂM THỬ (STP)',
  'Bốn mức kiểm thử, test case truy vết FR, giao thức benchmark và tiêu chí nghiệm thu · theo ISO/IEC/IEEE 29119-3',
  [['Tài liệu trước', 'EIDE-SRS-02 (§3, §3B), EIDE-SDD-04, EIDE-APD-08, EIDE-DPS-09']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-STP-05): 50 TC, 4 mức']],
  'Thêm mức L2b kiểm thử hội thoại (Z-01…Z-10); TC-51…TC-58 tự chủ; TC-59…TC-66 hội thoại/năng lực; TC-67…TC-82 cho req/arch/diagram/doc/view/discover; sửa TC-02, TC-05, TC-07; quy tắc sinh TC từ Danh mục; cập nhật kế hoạch theo mốc');
const c = [];
c.push(H1('1. Giới thiệu'));
c.push(P('Kế hoạch kiểm thử cho EIDE theo ISO/IEC/IEEE 29119-3 [7]. Bốn mức: đơn vị (pytest, không cần mạng/board), hợp đồng (adapter LLM, extractor, MCP, plugin ↔ daemon) — v1.1 thêm **L2b kiểm thử hội thoại** (kịch bản Z-01…Z-10 của DPS-09 chạy với mô hình hiểu lệnh thật, ghi/phát lại), tích hợp có phần cứng (STM32 Nucleo-F411 và ATmega328P), và nghiệm thu theo ba kịch bản A/B/C cộng kịch bản chuẩn 17 bước từ lệnh ngôn ngữ tự nhiên. Nguyên tắc: mọi bất biến an toàn (R4 không tự động, constant-guard, cổng ghi duy nhất, dừng khẩn, hoàn tác) phải có test chứng minh *không thể* bị vượt, không chỉ test đường đi đúng. **Quy tắc sinh TC từ Danh mục** (v1.1): mỗi năng lực có ít nhất một TC hợp đồng (schema vào/ra, grounding, lớp rủi ro đúng với PolicyGate) sinh tự động từ khai báo YAML — bảng §3.7 chỉ liệt kê TC hành vi đáng chú ý theo nhóm.'));
c.push(H1('2. Chiến lược và môi trường'));
c.push(T([2200, 3500, 3600], ['Mức', 'Phạm vi', 'Môi trường / công cụ'], [
  ['L1 Đơn vị', 'Schema, store, merge, KG queries, state machine, hooks, router, validator, pack/sign', 'pytest, hypothesis (fuzz schema), coverage ≥ 85% core'],
  ['L2 Hợp đồng', 'Ba adapter LLM cùng bộ 5 ca; mỗi extractor với bộ tệp mẫu; MCP tool schema; JSON-RPC plugin', 'pytest + bản ghi/phát lại HTTP (VCR) cho LLM; tệp mẫu trong tests/fixtures'],
  ['L3 Tích hợp phần cứng', 'Build/flash/serial/probe/sim; kiểm định hộ chiếu; benchmark', 'Runner tự host có Nucleo-F411 (ST-Link) + Arduino Uno (ATmega328P) + BME280; Renode; simavr'],
  ['L4 Nghiệm thu', 'Kịch bản A/B/C; tiêu chí SRS §6', 'Thủ công có kịch bản, ghi nhật ký; hai mô hình khác hãng'],
]));
c.push(SP());
c.push(H1('3. Test case'));
const W = [900, 3300, 3100, 1300, 700]; const H = ['TC', 'Mục tiêu', 'Bước / kỳ vọng', 'FR', 'Mức'];
c.push(H2('3.1. Bất biến an toàn (phải có trước mọi thứ khác)'));
c.push(T(W, H, [
  ['TC-01', 'Không có đường merge ngoài G3', 'Quét mã tĩnh: mọi lời gọi merge() nằm sau GateService.require(G3); thử gọi merge trực tiếp → ngoại lệ', 'AGT-05, NFR-01', 'L1'],
  ['TC-02', 'R4 không bao giờ tự động; R3 chỉ tự động trên board lab', 'erase/fuse/động cơ ở mọi mức A0–A4 → ASK (trừ danh sách trắng đã ký); flash trên board không lab → ASK; flash trên board lab ở A3 → APPROVE có decision_log', 'GOV-01, MCP-02, AUT-02', 'L1'],
  ['TC-03', 'Quyền hết hạn khi đóng phiên', 'Cấp quyền, đóng phiên, gọi lại → từ chối', 'GOV-01', 'L1'],
  ['TC-04', 'Constant-guard chặn hằng số không nguồn', '10 patch mẫu có hằng số không chú thích / chú thích fact không tồn tại / fact bạc chưa duyệt → chặn 100%; fact vàng → qua', 'AGT-03', 'L1'],
  ['TC-05', 'Cờ nhạy cảm và khóa API', 'Dự án sensitive=true: search.fetch/upload tài liệu ra dịch vụ ngoài → ASK; nhật ký không chứa khóa (quét regex); (M5) offline_mode=true → 0 kết nối ngoài', 'AGT-04, NFR-06', 'L1'],
  ['TC-06', 'Fact tầng bạc không vào mã trước G-FACT', 'Fact status=normalized → passport.query trả nhưng đánh dấu unreviewed; ConstantGuard từ chối', 'ACQ-05, AGT-03', 'L1'],
  ['TC-07', 'G-SRC theo chính sách', 'Ứng viên st.com có hash/license, ≤ ngưỡng → tự tải, ghi lý do; ứng viên forum lạ → không tải, ASK; tệp > ngưỡng → ASK', 'ACQ-06, AUT-03', 'L1'],
  ['TC-08', 'Cổng ghi duy nhất', 'Ghi trực tiếp SQLite ngoài PassportStore.write → hash store lệch → daemon từ chối mở và yêu cầu rebuild', 'GOV-05', 'L1'],
]));
c.push(SP());
c.push(H2('3.2. Nhận tri thức và hộ chiếu'));
c.push(T(W, H, [
  ['TC-09', 'Nhập SVD', '5 SVD mẫu (STM32F411, nRF52840, RP2040, GD32VF103, LPC55) → hộ chiếu; so 50 thanh ghi ngẫu nhiên với SVD gốc = 100%', 'ACQ-02', 'L2'],
  ['TC-10', 'Nhập ATDF', 'ATmega328P, ATtiny1616 → hộ chiếu; so io header', 'ACQ-02', 'L2'],
  ['TC-11', 'Mở nén đệ quy và chống zip-slip', 'zip lồng 3 cấp + entry "../x" → phân loại đúng, entry độc bị từ chối', 'ACQ-01', 'L1'],
  ['TC-12', 'PDF datasheet cảm biến', 'BME280, MPU6050 PDF → bảng thanh ghi; ≥ 90% fact đúng so với đáp án; mỗi fact có page+bbox', 'ACQ-03', 'L2'],
  ['TC-13', 'Hợp nhất mâu thuẫn', 'Hai nguồn khác giá trị offset → CONFLICTS_WITH, ưu tiên vàng, vào hàng đợi', 'ACQ-07', 'L1'],
  ['TC-14', 'Máy trạng thái AcquisitionRequest', 'Mọi chuyển hợp lệ/không hợp lệ; nhật ký đủ (ai, khi, lý do)', 'ACQ-05', 'L1'],
  ['TC-15', 'passport.query hiệu năng', 'Hộ chiếu 50.000 fact; 1.000 truy vấn; P95 < 200 ms', 'PSP-04, NFR-03', 'L1'],
  ['TC-16', 'Supersede và lịch sử', 'Sửa fact → phiên bản mới; query mặc định trả mới; include_history trả cả hai', 'PSP-02', 'L1'],
  ['TC-17', 'kg.impact', 'Fact bị thay → 3 CodeUnit CITES → stale đúng 3', 'PSP-05', 'L1'],
  ['TC-18', 'Kiểm định hộ chiếu trên board', 'Nucleo: đọc DBGMCU_IDCODE; Uno: signature bytes; so hộ chiếu → huy hiệu với log hash', 'BEN-02', 'L3'],
  ['TC-19', 'Docs MCP hãng làm nguồn bạc', 'Truy vấn API ESP-IDF qua Docs MCP → Source có URL, ngày', 'ACQ-09', 'L2'],
]));
c.push(SP());
c.push(H2('3.3. Mạch'));
c.push(T(W, H, [
  ['TC-20', 'KiCad → BoardPassport', '3 .kicad_sch mẫu → nets/pins; so tay ≥ 95%', 'BRD-01', 'L2'],
  ['TC-21', 'Xung đột chân', 'Schematic cố ý PB3 = LED + MOSI; PA13 dùng làm GPIO → 2 cảnh báo', 'BRD-03', 'L1'],
  ['TC-22', 'Ảnh schematic → đề xuất', 'Ảnh 3 mạch → bảng đề xuất kèm ảnh cắt; bắt buộc trạng thái chờ duyệt', 'BRD-02', 'L2'],
]));
c.push(SP());
c.push(H2('3.4. Gateway, tác tử, MCP'));
c.push(T(W, H, [
  ['TC-23', 'Hợp đồng adapter LLM (5 ca)', 'Tool đơn lồng 2 cấp; 2 tool song song; JSON theo schema Plan; ảnh → bảng; từ chối → stop_reason chuẩn; chạy trên Claude, Gemini, mô hình cục bộ', 'LLM-01', 'L2'],
  ['TC-24', 'Router và different_vendor', 'coder=Gemini → reviewer ≠ Gemini; chỉ có 1 hãng → cảnh báo ghi ledger', 'LLM-02, AGT-06', 'L1'],
  ['TC-25', 'Validator hai lớp', 'JSON hợp lệ nhưng fact id không tồn tại → sửa 1 lần → thất bại → bàn giao người', 'LLM-03', 'L1'],
  ['TC-26', 'Ngân sách ngữ cảnh', 'Composer với ngữ cảnh 12.000 token → nén còn ≤ 8.000 hoặc từ chối gọi', 'AGT-02', 'L1'],
  ['TC-27', 'Ledger và chi phí', 'Ngân sách 0,01 USD → dừng và mở gate', 'LLM-04', 'L1'],
  ['TC-28', 'MCP server từ Claude Code', 'Cấu hình MCP; gọi passport.query, review.patch, flash (needs_permission)', 'MCP-01, MCP-02', 'L2'],
  ['TC-29', 'Schema tool mẫu số chung', 'Compile mọi tool cho 3 adapter; không vi phạm (anyOf/$ref/sâu > 3)', 'MCP-04', 'L1'],
  ['TC-30', 'Rationale và citations bắt buộc', 'Đầu ra thiếu citations → từ chối', 'AGT-07', 'L1'],
]));
c.push(SP());
c.push(H2('3.5. Xác minh, gỡ lỗi, quan sát'));
c.push(T(W, H, [
  ['TC-31', 'Bốn cổng công cụ', 'Dự án mẫu armv7e-m và avr8: build/size/static/test → 4 ToolReport; lỗi cố ý ở mỗi cổng bị bắt', 'VER-01', 'L3'],
  ['TC-32', 'Flash + verify', 'Nucleo qua probe-rs; Uno qua avrdude; verify đạt; sai artifact → thất bại', 'VER-02', 'L3'],
  ['TC-33', 'Serial daemon', '2 cổng; expect(pattern, 5 s) khớp/timeout; JSONL đúng', 'VER-03', 'L3'],
  ['TC-34', 'SIL/HIL cùng kịch bản', 'Renode và Nucleo chạy blink+UART; báo cáo chênh lệch', 'VER-04', 'L3'],
  ['TC-35', 'Feature passing chỉ sau G4', 'Không có G4 → status failing dù ToolReport đạt', 'VER-05', 'L1'],
  ['TC-36', 'Probe cơ bản', 'halt/read_memory/set_breakpoint trên Nucleo; write_memory → needs_permission', 'DBG-01', 'L3'],
  ['TC-37', 'HardFault cố ý', 'Firmware null-deref và stack overflow → EvidencePack; Debugger chỉ đúng hàm ≥ 80% (10 ca)', 'DBG-02', 'L3'],
  ['TC-38', 'log.stats và debug.ask', 'Log 1 GB tổng hợp; stats < 5 s; debug.ask trả answer neo range; DebugSession lưu', 'DBG-04, UI-03', 'L2/L3'],
  ['TC-39', 'Hàng đợi xác nhận hợp nhất', 'Tạo 7 loại gate → cùng xuất hiện; decide qua plugin → daemon cập nhật', 'UI-02', 'L2'],
  ['TC-40', 'Hex/.map giải nghĩa', '0x40005400 → I2C1 với SVD STM32F411', 'UI-05', 'L1'],
]));
c.push(SP());
c.push(H2('3.6. Registry, quản trị, benchmark'));
c.push(T(W, H, [
  ['TC-41', 'Đóng gói và ký', 'publish → .hkp hợp lệ; sửa 1 byte → verify thất bại; thiếu license → từ chối', 'REG-01, REG-02', 'L1'],
  ['TC-42', 'Gieo hạt', 'Nhập 100 SVD → 100 gói unverified với manifest đúng', 'REG-05', 'L2'],
  ['TC-43', 'pull và huy hiệu', 'pull id@ver → nạp store; huy hiệu hiển thị; hash log kiểm được', 'REG-03, REG-04', 'L2'],
  ['TC-44', 'rollback', 'Sửa hỏng → rollback → build đạt', 'GOV-02', 'L3'],
  ['TC-45', 'resume', 'Đóng daemon giữa GENERATE → mở lại → trạng thái và FEATURES đúng', 'GOV-03, NFR-04', 'L1'],
  ['TC-46', 'doctor', 'Thiếu toolchain → báo; --install hỏi trước; --lock ghi tools.lock', 'GOV-04', 'L2'],
  ['TC-47', 'Benchmark CF/BF/BC', 'armv7e-m và avr8: 10 tác vụ × 2 mô hình; báo cáo; BC ≥ 90% mức 1–2', 'BEN-01, NFR-02', 'L3'],
  ['TC-48', 'Thêm ISA không sửa core', 'Thêm rv32imac profile + adapter → diff core = 0; bench chạy', 'NFR-08', 'L2'],
  ['TC-49', 'Mẫu 100 hằng số', 'Từ mã sinh ra ở TC-47: 100 hằng số ngẫu nhiên đều có fact id đúng', 'NFR-02', 'L4'],
  ['TC-50', 'Ba kịch bản A/B/C', 'Theo PDA-00 §2 với hai mô hình khác hãng; thời gian và nhật ký', 'SRS §6', 'L4'],
]));
c.push(SP());
c.push(H2('3.7. Tự chủ và hội thoại (mới v1.1)'));
c.push(T(W, H, [
  ['TC-51', 'Hàm quyết định theo cổng đúng ngưỡng', 'Bộ 40 tình huống (tier, confidence, nguồn, diff, board) → APPROVE/ASK/REJECT đúng bảng APD §4; đổi ngưỡng trong autonomy.yaml → kết quả đổi tương ứng', 'AUT-03', 'L1'],
  ['TC-52', 'Làm rồi báo cáo + hoàn tác', 'Fact bạc tự duyệt → undo → supersede về trạng thái cũ; merge tự động vào auto/ → undo → git revert, build đạt; nạp board lab → undo → known-good nạp lại', 'AUT-04', 'L1/L3'],
  ['TC-53', 'Dừng khẩn', 'Đang chạy chuỗi có nạp chờ → "dừng" → mức A0 trong < 1 s; thao tác phần cứng bị hủy; trạng thái giữ nguyên', 'AUT-05', 'L1'],
  ['TC-54', 'Leo thang', 'Năng lực thất bại 2 lần; ngân sách < 20%; ID chip lệch hộ chiếu → mục ASK trong hàng đợi + thông báo; việc không phụ thuộc vẫn chạy', 'AUT-05', 'L1'],
  ['TC-55', 'Học ngưỡng cần người', 'decision_log 30 ngày → đề xuất; ngưỡng không đổi cho tới khi người xác nhận; đề xuất nới lỏng không tự áp dụng', 'AUT-06', 'L1'],
  ['TC-56', 'Mức tự chủ theo board', 'Dự án A3, board robot-ctrl A2 → flash robot-ctrl ASK, flash nucleo (lab) APPROVE', 'AUT-01', 'L1'],
  ['TC-57', 'Danh sách trắng do người ký', 'Gói mermaid-cli trong trusted_packages → env.install_tool tự cài; gói lạ → ASK; sửa tệp trắng không có chữ ký → từ chối', 'AUT-02, GOV-04', 'L2'],
  ['TC-58', 'Kịch bản chuẩn ≤ 5 lần bấm', 'Kịch bản 17 bước từ 1 câu lệnh ở A3 với board lab: đếm gate ASK trong ledger ≤ 5; báo cáo cuối có đủ 4 mục', 'NFR-13', 'L4'],
  ['TC-59', 'parse_intent', '50 câu lệnh Việt/Anh (kèm lỗi chính tả) → intent + slot đúng ≥ 95%; lệnh lớn nhận diện đúng', 'DLG-01', 'L2b'],
  ['TC-60', 'Grounding — tồn tại thì không tạo trùng', 'Z-02, Z-03, Z-08: có dự án gần giống/mẫu tham chiếu/trùng đúng tên → hỏi dùng luôn/nhân bản/tạo mới; không ghi đè; "xóa X" chỉ khi gõ đúng cụm', 'DLG-02', 'L2b'],
  ['TC-61', 'Mặc định trước, hỏi sau', 'Z-01, Z-06: tham số thiếu điền mặc định có ledger; câu hỏi gộp ≤ 1/lượt; im lặng 120 s → mặc định và báo', 'DLG-03, DLG-04', 'L2b'],
  ['TC-62', 'Nói lại ý hiểu và làm ngay phần chắc chắn', 'Z-07 "làm hết đi": câu tôi hiểu là… trong ledger; các nút T1 không phụ thuộc bắt đầu trước khi người trả lời', 'DLG-05', 'L2b'],
  ['TC-63', 'Chuỗi năng lực có nhánh và tiếp tục sau tắt máy', 'Lệnh lớn → đồ thị ≥ 10 nút; tắt daemon giữa chừng → mở lại → run tiếp đúng nút; nút ASK không chặn nút song song', 'DLG-06', 'L1'],
  ['TC-64', 'Báo cáo và ghi nhớ lựa chọn', 'Sau chuỗi: báo cáo ≤ 10 dòng đủ 4 mục; trả lời "dùng ST-Link" → preferences.yaml; lần sau không hỏi lại (Z-10)', 'DLG-07, DLG-08', 'L2b'],
  ['TC-65', 'Một hợp đồng, hai đường gọi', 'Cùng năng lực gọi từ UI (JSON-RPC caps.invoke), MCP (caps.invoke), CLI và Orchestrator → cùng decision_log, capability_run, undo', 'NFR-14', 'L2'],
  ['TC-66', 'Registry năng lực hợp lệ', 'Nạp 228 khai báo: đủ 13 trường; schema mẫu số chung; mỗi id có impl; mã trùng Danh mục Excel 100%; tool MCP sinh ra compile trên 3 adapter', 'NFR-14, MCP-04', 'L1'],
]));
c.push(SP());
c.push(H2('3.8. Kỹ nghệ, bản đồ tri thức, dò board (mới v1.1)'));
c.push(T(W, H, [
  ['TC-67', 'req.elicit/classify/ground_hw', 'README + BOM robot → ReqSet ≥ 15 yêu cầu phân loại FR/NFR/HW/RT; yêu cầu "ADC 1 MSPS" trên chip 250 kSPS → không khả thi có trích dẫn fact', 'FR-REQ-01…03', 'L2'],
  ['TC-68', 'req.detect_conflict/trace_matrix', 'Hai yêu cầu mâu thuẫn cố ý → Issue; ma trận UR→FR→module→code→test xuất xlsx, lỗ hổng được liệt kê', 'FR-REQ-04, 06', 'L1'],
  ['TC-69', 'arch.style_select/decompose/map_hw', 'ReqSet robot + hộ chiếu F411 → kiến trúc RTOS 3 task có ADR; HwMap không xung đột (board.check_pins = 0); ngân sách RAM/timing trong ngưỡng', 'FR-ARCH-01…05', 'L2'],
  ['TC-70', 'arch.review/compare', 'ModuleGraph có ISR dài cố ý → finding; 2 phương án → bảng so sánh có trọng số và đề xuất', 'FR-ARCH-09, 10', 'L1'],
  ['TC-71', 'diagram.render trên 6 ngôn ngữ', 'Mỗi ngôn ngữ Mermaid/PlantUML/DOT/D2/WaveDrom/SVG: sinh → lint 0 lỗi → render svg/png trong sandbox → GEditor mở được', 'FR-DIAGRAM-01, 13', 'L2'],
  ['TC-72', 'diagram từ mô hình', 'BOM+netlist → sơ đồ khối; HwMap → sơ đồ chân; ModuleGraph → C4; FSM → state; Plan → Gantt; timing fact → WaveDrom: nút/cạnh khớp mô hình 100%', 'FR-DIAGRAM-02…11', 'L1'],
  ['TC-73', 'diagram.sync hai chiều', 'Đổi mã FSM (thêm trạng thái) → lược đồ trạng thái cập nhật; sửa lược đồ kiến trúc → ModuleGraph đổi; lệch cố ý → cảnh báo', 'FR-DIAGRAM-14', 'L1'],
  ['TC-74', 'diagram.from_image', '5 ảnh sơ đồ khối → Mermaid; nút/cạnh đúng ≥ 80%; confidence thấp → trạng thái chờ duyệt', 'FR-DIAGRAM-12', 'L2'],
  ['TC-75', 'doc.generate theo chuẩn EAA/EIDE', 'Sinh SRS từ ReqSet robot → docx có bảng thuộc tính, lịch sử, hình đánh số, mục Nguồn; pandoc → md kiểm cấu trúc; LibreOffice → pdf mở được', 'FR-DOC-01', 'L2'],
  ['TC-76', 'doc.style_check', 'Tài liệu cố ý: thuật ngữ Anh không giải nghĩa, số liệu không trích dẫn, tiếng Anh xen → 3 Issue đúng loại; tài liệu chuẩn → 0', 'FR-DOC-08, NFR-15', 'L1'],
  ['TC-77', 'doc.sync/changelog/bringup', 'Đổi fact địa chỉ I2C → mục tài liệu liên quan stale; changelog từ 10 commit; bring-up guide có bước nạp/kiểm', 'FR-DOC-05, 10, 12', 'L1'],
  ['TC-78', 'view.kg_map/provenance/coverage', 'KG 50.000 nút hiển thị < 3 s; nhấp fact → chuỗi nguồn gốc mở đúng trang PDF; độ phủ khớp hộ chiếu', 'FR-VIEW-01, 03, 05', 'L2'],
  ['TC-79', 'view.rag_ask có trích dẫn và trace', '100 câu hỏi trên kho BME280/F411: đúng ≥ 90%, 100% có citations mở được nguồn; trace hiển thị chunk, điểm, đường lan tỏa; câu ngoài phạm vi → "không tìm thấy"', 'FR-VIEW-07, 08, NFR-02', 'L2'],
  ['TC-80', 'discover.ports/probes/chip_id', 'Cắm Nucleo (ST-Link) và Uno: cổng + probe liệt kê đúng VID/PID; IDCODE/signature khớp hộ chiếu; chip lạ → ID không khớp → cảnh báo', 'FR-DISCOVER-01…03', 'L3'],
  ['TC-81', 'discover.link_speed', 'Serial: auto-baud chọn 115200 với 0 lỗi/1.000 khung; SWD: clock tăng dần tới nấc lỗi → chọn nấc dưới; nấc vượt fact datasheet → ASK', 'FR-DISCOVER-06', 'L3'],
  ['TC-82', 'discover.auto_setup + board_match', 'Cắm board → target.yaml sinh đúng adapter/cổng/tốc độ < 30 s; BlackPill nhận diện từ ID + quét I2C (MPU6050 0x68) + ảnh; nhiều ứng viên → hỏi 1 câu', 'FR-DISCOVER-04, 05, 12', 'L3'],
]));
c.push(SP());
c.push(H1('4. Giao thức benchmark'));
c.push(P('Theo giao thức CF/BF/BC của IoT-SkillsBench [17]: mỗi tác vụ có mô tả, board, kỳ vọng quan sát được (serial pattern, GPIO, số đo), và ba mức (điều khiển cơ bản; giao thức I2C/SPI/UART; tích hợp đa ngoại vi có ngắt). Mỗi lần chạy ghi: mô hình theo vai trò, skill đã nạp, token, số vòng tự sửa, kết cục CF/BF/BC, thời gian. Bộ khởi đầu: 10 tác vụ armv7e-m trên Nucleo-F411 (blink, UART echo, I2C BME280, SPI flash ID, timer PWM, EXTI, DMA UART, RTOS 2 task, watchdog, low-power) và 10 tác vụ avr8 tương đương trên Uno. Ngưỡng nghiệm thu: BC ≥ 90% mức 1–2, ≥ 60% mức 3.'));
c.push(H1('5. Tiêu chí nghiệm thu và kế hoạch chạy'));
c.push(T([2000, 7300], ['Mốc', 'Test bắt buộc đạt'], [
  ['M0', 'TC-01…08 (bất biến), TC-09, TC-10, TC-15, TC-16, TC-23…27, TC-29, TC-66 (registry năng lực)'],
  ['M1', 'M0 + TC-11…14, TC-18, TC-41 (định dạng), TC-46, TC-51…57 (tự chủ), TC-59…65 (hội thoại), TC-67, TC-68, TC-71, TC-76, TC-78, TC-79'],
  ['M2', 'M1 + TC-17, TC-19…22, TC-28, TC-30…33, TC-35, TC-44, TC-45, TC-47, TC-69, TC-70, TC-72, TC-75, TC-77, TC-80…82'],
  ['M3', 'M2 + TC-34, TC-36…40, TC-73, TC-74'],
  ['M4', 'M3 + TC-42, TC-43, TC-48, TC-49, TC-50, TC-58'],
]));
c.push(SP());
c.push(P('Định nghĩa hoàn thành v1.0: mọi TC mức Must đạt trên CI (L1, L2, L2b) và trên runner có board (L3), TC-49, TC-50 và TC-58 đạt với hai mô hình khác hãng, 238 năng lực có TC hợp đồng sinh tự động đạt, và báo cáo benchmark được xuất tự động vào registry cùng gói hộ chiếu tương ứng.'));
c.push(...refParas(H1));
build(m, c, 'EIDE-STP-05_Ke_hoach_kiem_thu.docx');
