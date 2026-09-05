const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas, CAPS, NS_ORDER, NS_VI, byNs, count } = require('./eide_common');
const m = meta('EIDE-SRS-02', 'Đặc tả yêu cầu phần mềm', 'ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)',
  'Yêu cầu chức năng, phi chức năng và giao diện của EIDE (Embedded IDE) · theo ISO/IEC/IEEE 29148',
  [['Tài liệu trước', 'EIDE-URD-01 (mọi FR truy vết về UR); Danh mục năng lực v1.1 (nguồn của FR theo năng lực)'], ['Tài liệu kế tiếp', 'EIDE-SAD-03, EIDE-SDD-04, EIDE-STP-05']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (EIDE-SRS-02): 14 UC, 62 FR theo mô-đun, 12 NFR']],
  'Thêm §3B: 228 FR theo năng lực (mã = mã năng lực) sinh từ Danh mục; thêm FR-AUT-01…06 (tự chủ) và FR-DLG-01…08 (hội thoại); sửa FR-ACQ-06, FR-AGT-04, FR-AGT-05, FR-GOV-01, FR-GOV-04, FR-MCP-02; UC15–UC18; NFR-06 (Internet mặc định, cờ nhạy cảm), NFR-13, NFR-14; giao diện lược đồ và USB/probe; tiêu chí nghiệm thu tự động hóa');
const c = [];
c.push(H1('1. Giới thiệu'));
c.push(P('Tài liệu đặc tả yêu cầu phần mềm của EIDE theo lớp yêu cầu hệ thống của ISO/IEC/IEEE 29148 [4]. Từ v1.1, SRS có **hai lớp yêu cầu chức năng**: (a) FR theo mô-đun (§3, kế thừa v1.0, mã FR-ACQ…FR-BEN) mô tả các cơ chế nền — schema, store, gateway, gate, adapter; (b) **FR theo năng lực** (§3B) sinh trực tiếp từ Danh mục năng lực [25]: mỗi năng lực là một FR có mã trùng mã năng lực (ví dụ FR-EXTRACT-05 ⇔ `extract.bom`), kèm lớp rủi ro, mức tự chủ, grounding và điều kiện hỏi kỹ sư — đây là hợp đồng mà cả giao diện lẫn tác tử điều phối gọi. Sản phẩm gồm: Knowledge Plane (daemon Python), Capability Registry, Orchestrator (tầng hiểu lệnh, EIDE-DPS-09 [27]), PolicyGate/Undo (EIDE-APD-08 [26]), bộ extractor, Passport Store + Knowledge Graph + chỉ mục RAG, Agent Runtime (LLM Gateway của core), Tool/Target/Discovery Layer, dịch vụ lược đồ và tài liệu, MCP server/client, GEditor plugin, Registry client, CLI. Bản đầu chạy trên một PC có Internet đầy đủ (CR-08). Phạm vi loại trừ: GUI đa nền tảng, thiết kế mạch (CAD), huấn luyện mô hình, làm việc nhóm đồng thời, chế độ cục bộ/không mạng (M5).'));
c.push(H1('2. Mô tả tổng quan'));
c.push(H2('2.1. Tác nhân'));
c.push(T([2400, 1900, 5000], ['Tác nhân', 'Loại', 'Vai trò'], [
  ['Kỹ sư (Engineer)', 'Người dùng chính', 'Ra lệnh bằng ngôn ngữ tự nhiên; xem kết quả; trả lời câu hỏi gộp; duyệt/hoàn tác; cấp quyền R4'],
  ['Tác tử điều phối (Orchestrator)', 'Tác nhân phần mềm', 'Hiểu lệnh, đối chiếu trạng thái, lập chuỗi năng lực, điền mặc định, áp chính sách, báo cáo (DPS-09)'],
  ['Chính sách tự chủ (PolicyGate)', 'Tác nhân phần mềm', 'Quyết định APPROVE/ASK/REJECT ở mỗi cổng theo lớp rủi ro và mức tự chủ (APD-08)'],
  ['Pack owner', 'Người dùng', 'Soạn skill/benchmark, kiểm định, phát hành .hkp'],
  ['IDE ngoài (MCP client)', 'Hệ thống ngoài', 'Claude Code, Cursor, VS Code gọi tool của EIDE'],
  ['LLM provider', 'Hệ thống ngoài', 'Claude, Gemini, OpenAI-compatible/cục bộ qua Gateway'],
  ['Nguồn tri thức', 'Hệ thống ngoài', 'Registry, kho hãng (SVD/ATDF/EDC), docs MCP của hãng, web'],
  ['Toolchain, probe, board, thiết bị đo', 'Hệ thống ngoài / vật lý', 'Qua adapter; chỉ tương tác sau quyền theo phiên'],
  ['GEditor', 'Hệ thống chủ (host) của plugin', 'Cung cấp engine tệp lớn và khung plugin'],
]));
c.push(SP());
c.push(H2('2.2. Use case'));
c.push(T([900, 2600, 1800, 3900], ['Mã', 'Use case', 'Tác nhân', 'Mô tả'], [
  ['UC01', 'Nhập tài liệu', 'Kỹ sư', 'Kéo thả → phân loại → mở nén → xếp hàng trích xuất'],
  ['UC02', 'Nhận tri thức thiếu', 'Kỹ sư, Librarian', 'Yêu cầu → ứng viên → xác nhận nguồn → trích xuất → chuẩn hóa → duyệt fact'],
  ['UC03', 'Truy vấn hộ chiếu', 'Kỹ sư, IDE ngoài', 'passport.query trả fact + trích dẫn + tier'],
  ['UC04', 'Dựng BoardPassport', 'Kỹ sư, Cartographer', 'Từ KiCad/ảnh → bảng chân/net → kiểm xung đột → duyệt'],
  ['UC05', 'Kiểm định hộ chiếu trên board', 'Kỹ sư, Tester, Tool Layer', 'Firmware ID/GPIO/UART → so sánh → huy hiệu'],
  ['UC06', 'Lập kế hoạch và sinh mã', 'Kỹ sư, Planner, Coder, Reviewer', 'G1 → CodePatch có fact id → constant-guard → 4 cổng công cụ → G3'],
  ['UC07', 'Nạp và quan sát', 'Kỹ sư, Tool Layer', 'Cấp quyền → flash+verify → serial → G4'],
  ['UC08', 'Gỡ lỗi có chứng cứ', 'Kỹ sư, Debugger', 'Chọn vùng log/probe → giả thuyết → thí nghiệm → DebugSession'],
  ['UC09', 'Phân tích ảnh hưởng tri thức', 'Kỹ sư', 'Fact mới → CodeUnit stale → backlog'],
  ['UC10', 'Đóng gói và phát hành', 'Pack owner', 'hkw publish → ký → registry'],
  ['UC11', 'Pull và tin dùng gói', 'Kỹ sư', 'Xem huy hiệu → pull → nạp vào Passport Store'],
  ['UC12', 'Chạy benchmark', 'Pack owner, Tester', 'Bộ tác vụ CF/BF/BC theo mô hình → báo cáo'],
  ['UC13', 'Quản trị môi trường', 'Kỹ sư', 'hkw doctor: kiểm/cài/khóa toolchain; cấu hình mô hình'],
  ['UC14', 'Tiếp tục phiên', 'Kỹ sư', 'Đọc PROGRESS/FEATURES/ledger; build known-good; tiếp tục'],
  ['UC15', 'Ra lệnh ngôn ngữ tự nhiên (mới)', 'Kỹ sư, Orchestrator, PolicyGate', 'Lệnh → hiểu → đối chiếu → mặc định/hỏi gộp → chuỗi năng lực → chính sách → báo cáo (DPS-09; bao trùm mọi UC khác)'],
  ['UC16', 'Dò board và cấu hình target (mới)', 'Orchestrator, Discovery', 'Cắm board → dò cổng/probe → ID chip → đối chiếu hộ chiếu → dò tốc độ → tự cấu hình'],
  ['UC17', 'Yêu cầu → kiến trúc → lược đồ → tài liệu (mới)', 'Kỹ sư, Orchestrator', 'req.* → arch.* → diagram.* → doc.*; ADR, ngân sách, ma trận truy vết; tài liệu chuẩn EAA/EIDE'],
  ['UC18', 'Bản đồ tri thức và hỏi–đáp RAG (mới)', 'Kỹ sư', 'view.kg_map/provenance/coverage; view.rag_ask có trích dẫn và trace'],
]));
c.push(SP());
c.push(P('Bộ 45 use case chi tiết (UC-A01…UC-H04) với luồng chính, luồng thay thế, mức tự chủ theo bước và kịch bản mẫu 17 bước nằm trong tệp Excel [28]; SRS chỉ giữ 18 use case cấp hệ thống để truy vết.'));
c.push(SP());
c.push(H2('2.3. Đặc tả chi tiết UC02 — Nhận tri thức thiếu'));
c.push(T([2400, 6900], ['Mục', 'Nội dung'], [
  ['Tiền điều kiện', 'Dự án đã mở; có ít nhất một nguồn tìm kiếm được cấu hình (registry nội bộ, thư mục cục bộ, web nếu cho phép)'],
  ['Kích hoạt', 'UC03 không khớp; hoặc tác tử tự đánh giá thiếu; hoặc kỹ sư tạo yêu cầu thủ công'],
  ['Luồng chính', '(1) Tạo AcquisitionRequest{need, part, peripheral} → (2) Librarian tìm theo thứ tự registry → cục bộ → hãng → web, trả ứng viên {uri, kind, size, license?, sha256?} → (3) G-SRC: kỹ sư chọn/loại/thêm tệp → (4) tải và trích xuất theo tầng, trả facts[] có locator → (5) chuẩn hóa, hợp nhất, ghi Fact/Source vào store và KG với trạng thái NORMALIZED → (6) G-FACT: kỹ sư duyệt theo nhóm → REVIEWED → (7) tùy chọn UC05 → VERIFIED'],
  ['Luồng thay thế A', 'Không có ứng viên: yêu cầu ở trạng thái REQUESTED, kỹ sư được gợi ý nạp tệp thủ công'],
  ['Luồng thay thế B', 'Mâu thuẫn giữa hai nguồn: hai Fact cùng subject/predicate → cạnh CONFLICTS_WITH; nguồn tầng cao hơn được ưu tiên; đưa vào hàng đợi duyệt bắt buộc'],
  ['Luồng thay thế C', 'Reviewer từ chối nhóm fact: về CONFIRMED kèm ghi chú; extractor chạy lại với gợi ý (trang, bảng)'],
  ['Hậu điều kiện', 'Mọi fact mới có provenance; yêu cầu đóng; nhật ký ghi quyết định ở G-SRC và G-FACT'],
]));
c.push(SP());
c.push(H1('3. Yêu cầu chức năng'));
const W = [1250, 5200, 600, 650, 1600]; const H = ['Mã', 'Yêu cầu', 'Ưu', 'GĐ', 'UR gốc'];
c.push(H2('3.1. ACQ — Nhận tri thức'));
c.push(T(W, H, [
  ['FR-ACQ-01', 'Bộ phân loại tệp theo chữ ký nội dung (không chỉ phần mở rộng); mở nén đệ quy zip/7z/tar/gz với giới hạn độ sâu 5 và kích thước 2 GB; cách ly đường dẫn (chống zip-slip).', 'M', 'M1', 'UR-TT-01'],
  ['FR-ACQ-02', 'Extractor tầng vàng: SVD (CMSIS), ATDF, EDC/.PIC, devicetree binding YAML, header C của hãng (phân tích #define địa chỉ/bit) → Fact với confidence ≥ 0,95.', 'M', 'M0', 'UR-TT-02'],
  ['FR-ACQ-03', 'Extractor tầng bạc cho PDF: bố cục và bảng bằng Docling/pdfplumber [11]; LLM có schema chuyển bảng thành fact; lưu trang, bbox, ảnh cắt; confidence 0,6–0,9.', 'M', 'M1', 'UR-TT-01, TT-05'],
  ['FR-ACQ-04', 'Extractor DOCX/XLSX/HTML/Markdown/ảnh (mô hình thị giác) với cùng hợp đồng Fact.', 'S', 'M1', 'UR-TT-01, MC-02'],
  ['FR-ACQ-05', 'AcquisitionRequest và máy trạng thái REQUESTED → CANDIDATES → CONFIRMED → EXTRACTED → NORMALIZED → REVIEWED → VERIFIED / REJECTED; mọi chuyển trạng thái ghi nhật ký.', 'M', 'M1', 'UR-TT-04'],
  ['FR-ACQ-06', 'Tìm ứng viên theo thứ tự registry → cục bộ → mẫu URL hãng → docs MCP → web; G-SRC do PolicyGate quyết định: tự tải khi nguồn thuộc danh sách tin cậy, hash/license rõ, kích thước ≤ ngưỡng; ngược lại ASK (APD §4).', 'M', 'M1', 'UR-TT-04'],
  ['FR-ACQ-07', 'Hợp nhất fact trùng: ưu tiên tầng cao; giá trị khác → CONFLICTS_WITH và bắt buộc duyệt.', 'M', 'M1', 'UR-TT-03'],
  ['FR-ACQ-08', 'Giao diện duyệt theo nhóm (thanh ghi/chân/điện/errata) với ảnh cắt và nguồn; thao tác chấp nhận/sửa/loại theo nhóm.', 'M', 'M1', 'UR-TT-05'],
  ['FR-ACQ-09', 'Kết nối docs MCP của hãng (Espressif, Nordic) làm nguồn tầng bạc có URL và ngày [15], [16].', 'S', 'M2', 'UR-TT-04'],
]));
c.push(SP());
c.push(H2('3.2. PSP — Hộ chiếu và đồ thị tri thức'));
c.push(T(W, H, [
  ['FR-PSP-01', 'Schema JSON Schema 2020-12 [24] cho ChipPassport, BoardPassport, ISAProfile, Fact, Source; kiểm hợp lệ khi ghi.', 'M', 'M0', 'UR-TT-03'],
  ['FR-PSP-02', 'Fact bất biến; sửa = fact mới với supersedes; truy vấn mặc định trả phiên bản hiện hành, tùy chọn trả lịch sử.', 'M', 'M0', 'UR-TT-03'],
  ['FR-PSP-03', 'Passport Store trên SQLite trong `.hkw/`; đồ thị NetworkX nạp khi mở dự án; tệp có thể commit Git (loại trừ cache).', 'M', 'M0', 'UR-QT-04'],
  ['FR-PSP-04', 'passport.query(part, peripheral?, register?, field?) trả facts + citations + tier trong < 200 ms cho hộ chiếu ≤ 50.000 fact.', 'M', 'M0', 'UR-TT-07'],
  ['FR-PSP-05', 'Truy vấn đồ thị: kg.conflicts(project), kg.impact(fact_id), kg.evidence(feature), kg.neighborhood(node, depth ≤ 2).', 'M', 'M2', 'UR-TT-08, MC-03'],
  ['FR-PSP-06', 'Graph-RAG: chọn ngữ cảnh cho tác tử bằng lan tỏa 2 bước từ module đích rồi mới lấy văn bản; ngân sách token cấu hình.', 'S', 'M2', 'UR-MA-01'],
]));
c.push(SP());
c.push(H2('3.3. BRD — Mạch'));
c.push(T(W, H, [
  ['FR-BRD-01', 'Nhập .kicad_sch qua kicad-cli export netlist [12] → nets, parts, pins; ánh xạ part → ChipPassport/PartPassport theo MPN.', 'M', 'M2', 'UR-MC-01'],
  ['FR-BRD-02', 'Ảnh schematic → mô hình thị giác với schema {nets[]} → đề xuất tầng bạc, bắt buộc duyệt.', 'S', 'M2', 'UR-MC-02'],
  ['FR-BRD-03', 'Kiểm xung đột: một pin nhiều chức năng trái nhau; pin reserved/boot/debug; địa chỉ bus trùng; pull-up thiếu.', 'M', 'M2', 'UR-MC-03, MC-04'],
  ['FR-BRD-04', 'BoardPassport ghi ràng buộc điện và constraints cho Coder (reserved_pins, bus limits).', 'S', 'M2', 'UR-MC-04'],
]));
c.push(SP());
c.push(H2('3.4. AGT — Tác tử'));
c.push(T(W, H, [
  ['FR-AGT-01', 'Sáu vai trò (Librarian, Cartographer, Planner, Coder, Reviewer, Debugger, Tester) với prompt, skill, tool và ngân sách riêng; cấu hình trong roles.yaml.', 'M', 'M2', 'UR-MA-03'],
  ['FR-AGT-02', 'Composer ngữ cảnh 7 lớp (K1–K7) kế thừa EAA [2]; ngân sách ≤ 8.000 token kiểm trước khi gọi.', 'M', 'M2', 'UQ-05'],
  ['FR-AGT-03', 'Constant-guard: quét hằng số dạng địa chỉ/bit/enum trong CodePatch; mỗi hằng số phải trỏ fact id hợp lệ; không → chặn + AcquisitionRequest.', 'M', 'M1', 'UR-MA-02'],
  ['FR-AGT-04', 'Egress-guard: bản đầu chỉ kiểm cờ "nhạy cảm" của dự án (hỏi trước khi gửi tài liệu ra dịch vụ ngoài) và chặn rò rỉ khóa; chế độ cục bộ đầy đủ (chặn mọi adapter đám mây) là tùy chọn M5.', 'S', 'M1', 'UR-MH-02'],
  ['FR-AGT-05', 'Máy trạng thái điều phối với gate G1, G3, G4, G5 + G-SRC, G-FACT, G-OPS cưỡng chế; người quyết định ở mỗi gate là con người hoặc PolicyGate theo FR-AUT; ≤ 3 vòng tự sửa.', 'M', 'M2', 'UR-MA-03, CR-07'],
  ['FR-AGT-06', 'Reviewer bắt buộc khác nhà cung cấp với Coder khi có ≥ 2 nhà cung cấp; nếu không, cảnh báo trong nhật ký.', 'M', 'M2', 'UR-MH-01'],
  ['FR-AGT-07', 'Mỗi đầu ra tác tử có rationale ≤ 150 từ và citations[]; thiếu → từ chối.', 'S', 'M2', 'UR-HT-03'],
]));
c.push(SP());
c.push(H2('3.5. LLM — Gateway đa mô hình'));
c.push(T(W, H, [
  ['FR-LLM-01', 'ModelPort.complete(ModelRequest) → ModelResponse; adapter Claude, Gemini, OpenAI-compatible; schema tool theo mẫu số chung [19].', 'M', 'M0', 'UR-MH-01'],
  ['FR-LLM-02', 'models.yaml ánh xạ vai trò → ứng viên, điều kiện, fallback; different_vendor_from(role).', 'M', 'M0', 'UR-MH-01'],
  ['FR-LLM-03', 'Validator hai lớp: JSON Schema rồi kiểm ngữ nghĩa (fact id tồn tại, tệp trong dự án); một lần sửa.', 'M', 'M0', 'UR-MA-02'],
  ['FR-LLM-04', 'Ledger: request/response/usage/latency/model_id; ngân sách ngày; báo cáo CSV.', 'M', 'M0', 'UR-MH-03'],
]));
c.push(SP());
c.push(H2('3.6. VER / DBG — Xác minh và gỡ lỗi'));
c.push(T(W, H, [
  ['FR-VER-01', 'Bốn cổng công cụ build/size/static/test → ToolReport{passed, log, metrics, artifacts}; giới hạn thời gian mỗi cổng.', 'M', 'M2', 'UR-XM-01'],
  ['FR-VER-02', 'Flash adapter theo ISA profile (avrdude, probe-rs, OpenOCD, idf.py, west, pymcuprog) với verify; chỉ chạy sau G-OPS.', 'M', 'M2', 'UR-XM-02'],
  ['FR-VER-03', 'Serial daemon đa cổng, JSONL {port, ts, line}; serial.expect(pattern, timeout).', 'M', 'M2', 'UR-QS-05'],
  ['FR-VER-04', 'Sim adapter: Renode (.repl), simavr; cùng kịch bản với HIL; báo cáo chênh lệch.', 'S', 'M3', 'UR-XM-03'],
  ['FR-VER-05', 'Feature chỉ passing sau G4; tạo cạnh EVIDENCED_BY tới Measurement/log hash.', 'M', 'M2', 'UR-XM-04'],
  ['FR-DBG-01', 'Probe adapter qua embedded-debugger-mcp [14]: list/connect/halt/run/step/read_memory/set_breakpoint; write/erase yêu cầu G-OPS.', 'M', 'M3', 'UR-GL-01'],
  ['FR-DBG-02', 'diagnose_fault và unwind → EvidencePack; Debugger sinh Diagnosis{hypotheses[], experiment}.', 'S', 'M3', 'UR-GL-02'],
  ['FR-DBG-03', 'DebugSession lưu vào store và đồ thị, liên kết fact/CodeUnit/log range.', 'M', 'M3', 'UR-GL-03'],
  ['FR-DBG-04', 'log.stats(file, range?) do GEditor tính: tần suất mẫu, khoảng thời gian, dòng lặp; trả về cho Debugger thay vì gửi toàn tệp.', 'M', 'M3', 'UR-QS-01'],
]));
c.push(SP());
c.push(H2('3.7. MCP / UI / REG / GOV / BEN'));
c.push(T(W, H, [
  ['FR-MCP-01', 'EIDE MCP server (stdio + HTTP cục bộ) [13] với tool: passport.query, passport.list, kg.conflicts, kg.impact, acquire.request, review.patch, build, flash, serial.expect, probe.*, feature.status, export.report.', 'M', 'M2', 'UR-MA-01'],
  ['FR-MCP-02', 'Tool lớp R4 (erase, fuse, động cơ…) trả về "cần quyền" và mở G-OPS; tool R3 (flash, probe.write) thực thi ngay trên board lab ở mức ≥ A3, ngược lại cần quyền.', 'M', 'M2', 'UR-QT-01'],
  ['FR-MCP-03', 'MCP client tới docs MCP hãng và embedded-debugger-mcp; kiểm sẵn sàng khi mở dự án.', 'S', 'M2', 'UR-TT-04'],
  ['FR-MCP-04', 'Giới hạn ≤ 20 tool/phiên và mô tả tool có ví dụ (ACI).', 'S', 'M2', '[3]'],
  ['FR-UI-01', 'GEditor plugin: trình duyệt hộ chiếu (nhóm, tier, nguồn, nhảy tới trang PDF/bbox).', 'M', 'M3', 'UR-QS-03'],
  ['FR-UI-02', 'Hàng đợi xác nhận hợp nhất cho G-SRC, G-FACT, G1, G3, G4, G5, G-OPS; bộ lọc; phím tắt.', 'M', 'M3', 'UR-QS-03'],
  ['FR-UI-03', 'Log lớn: nhận dấu thời gian/mức; thống kê toàn tệp; chọn vùng → "hỏi tác tử"; trả lời neo dòng, lưu DebugSession.', 'M', 'M3', 'UR-QS-01, QS-02'],
  ['FR-UI-04', 'Serial console đa cổng; gửi lệnh; expect.', 'M', 'M3', 'UR-QS-05'],
  ['FR-UI-05', 'Hex/.map giải nghĩa địa chỉ theo hộ chiếu.', 'S', 'M3', 'UR-QS-04'],
  ['FR-UI-06', 'Đồ thị lân cận của Pin/Register/CodeUnit.', 'S', 'M3', 'UR-QS-03'],
  ['FR-UI-07', 'Waveform sigrok đồng bộ thời gian với log [23].', 'C', 'M5', 'UR-QS-06'],
  ['FR-REG-01', 'Định dạng .hkp: manifest, passport.yaml, skills/, bench/, badges.json, SIGNATURE; không chứa tài liệu hãng.', 'M', 'M4', 'UR-RG-01, CR-03'],
  ['FR-REG-02', 'Ký/kiểm chữ ký (minisign hoặc sigstore [21]); từ chối gói thiếu license hoặc chữ ký sai.', 'M', 'M4', 'UR-RG-01'],
  ['FR-REG-03', 'Registry nội bộ = kho Git + index JSON; hkw publish/pull/search.', 'M', 'M4', 'UR-RG-02'],
  ['FR-REG-04', 'Huy hiệu: verified_on_board{board, date, by, log_sha256}, bench{model, CF/BF/BC}.', 'M', 'M4', 'UR-RG-02'],
  ['FR-REG-05', 'Bộ gieo hạt: nhập CMSIS-SVD packs và Microchip ATDF → gói "unverified".', 'M', 'M4', 'UR-RG-03'],
  ['FR-GOV-01', 'Quyền theo phiên cho thao tác R4 (và R3 ngoài board lab); hết hạn khi đóng phiên; danh sách trắng board lab/gói tin cậy do người ký một lần; nhật ký.', 'M', 'M1', 'UR-QT-01'],
  ['FR-GOV-02', 'known-good và hkw rollback.', 'M', 'M2', 'UR-QT-02'],
  ['FR-GOV-03', 'PROGRESS.md, FEATURES.json, ledger; thủ tục khởi động phiên [18].', 'M', 'M2', 'UR-QT-03'],
  ['FR-GOV-04', 'eide doctor: kiểm/phát hiện thiếu/tự cài từ danh sách gói tin cậy/khóa toolchain theo manifest; gói ngoài danh sách hoặc cần quyền hệ thống ⇒ ASK.', 'M', 'M1', 'UR-QT-05'],
  ['FR-GOV-05', 'Mọi ghi vào Passport Store/KG qua một cổng ghi duy nhất có kiểm schema và nhật ký.', 'M', 'M0', 'UR-TT-03'],
  ['FR-GOV-06', 'Xuất báo cáo/hộ chiếu/benchmark ra docx/pdf/md có mục nguồn.', 'S', 'M4', 'UR-HT-02'],
  ['FR-BEN-01', 'Bộ benchmark theo ISA: ≥ 10 tác vụ, 3 mức, chấm CF/BF/BC trên board [17]; chạy theo mô hình.', 'M', 'M2', 'UR-HT-01'],
  ['FR-BEN-02', 'Kiểm định hộ chiếu (ID/GPIO/UART) là bench đặc biệt sinh huy hiệu.', 'M', 'M1', 'UR-TT-06'],
  ['FR-BEN-03', 'Báo cáo benchmark tự động sau mỗi thay đổi skill/mô hình.', 'S', 'M2', 'UR-HT-01'],
]));
c.push(SP());
c.push(H2('3.8. AUT — Tự chủ (mới v1.1, theo EIDE-APD-08)'));
c.push(T(W, H, [
  ['FR-AUT-01', 'Mức tự chủ A0–A4 ở cấp dự án (`autonomy.yaml`), ghi đè theo board và theo loại hành động; mặc định A3; A4 chỉ khi board lab và có bộ kiểm thử tự động.', 'M', 'M1', 'UR-QT-06'],
  ['FR-AUT-02', 'Lớp rủi ro R0–R4 gắn với từng năng lực trong registry; R4 không bao giờ tự động trừ danh sách trắng do người ký.', 'M', 'M1', 'UR-QT-01'],
  ['FR-AUT-03', 'Hàm quyết định theo cổng policy.decide(action, ctx) → {APPROVE, ASK, REJECT, reason, evidence[]}; ngưỡng trong autonomy.yaml; mọi quyết định ghi decision_log.', 'M', 'M1', 'UR-QT-06, UR-TT-04, UR-TT-05'],
  ['FR-AUT-04', 'Làm rồi báo cáo: hành động R1–R3 được APPROVE thực thi ngay và vào hàng đợi "đã làm — hoàn tác được trong T"; UndoService hoàn tác fact (supersede), merge (git revert), nạp (known-good).', 'M', 'M1', 'UR-QT-07'],
  ['FR-AUT-05', 'Leo thang (ASK, thất bại 2 lần, ngân sách < 20%, board lệch hộ chiếu, mẫu bất thường) qua hàng đợi/chat/thông báo; dừng khẩn hạ A0 < 1 s và hủy thao tác phần cứng đang chờ.', 'M', 'M1', 'UR-QT-06'],
  ['FR-AUT-06', 'Học ngưỡng: tổng hợp quyết định của người thành đề xuất chỉnh ngưỡng; chỉ áp dụng khi người xác nhận; chính sách không tự nới lỏng.', 'S', 'M2', 'UR-HT-04'],
]));
c.push(SP());
c.push(H2('3.9. DLG — Hội thoại và suy luận ý định (mới v1.1, theo EIDE-DPS-09)'));
c.push(T(W, H, [
  ['FR-DLG-01', 'chat.parse_intent: lệnh ngôn ngữ tự nhiên (Việt/Anh) → {intent, slots, is_big_command, confidence} theo schema mẫu số chung; nhận diện lệnh lớn (nhiều bước).', 'M', 'M1', 'UR-NL-01'],
  ['FR-DLG-02', 'chat.ground (D1): trước mọi lệnh tạo/nạp/sinh, tra dự án, hộ chiếu, board, feature, registry với khớp tên gần đúng; trả "đã tồn tại" kèm phương án dùng luôn / nhân bản / tạo mới.', 'M', 'M1', 'UR-NL-02'],
  ['FR-DLG-03', 'chat.fill_defaults (D2): điền tham số thiếu bằng mặc định có căn cứ (autonomy.yaml defaults, preferences.yaml, suy ra từ câu lệnh); ghi ledger; đổi được bằng một câu.', 'M', 'M1', 'UR-NL-03'],
  ['FR-DLG-04', 'chat.clarify (D3): tối đa một câu hỏi gộp/lượt với phương án đánh số, mặc định đánh dấu và ask_timeout; im lặng ⇒ chọn mặc định và báo.', 'M', 'M1', 'UR-NL-03'],
  ['FR-DLG-05', 'chat.restate (D6) và làm ngay phần chắc chắn (D4): câu "tôi hiểu là… tôi sẽ…" trước chuỗi ≥ 3 bước; các bước T1 không phụ thuộc chạy song song với chờ trả lời.', 'M', 'M1', 'UR-NL-04'],
  ['FR-DLG-06', 'chat.orchestrate: lệnh lớn → đồ thị chuỗi năng lực có nhánh và điều kiện; mỗi nút gọi năng lực qua registry với policy.decide trước khi thực thi; theo dõi run_id; tiếp tục sau khi tắt máy.', 'M', 'M2', 'UR-NL-01, UR-NL-06'],
  ['FR-DLG-07', 'chat.report_back: sau mỗi chuỗi, báo cáo ≤ 10 dòng {đã làm, chờ người, hoàn tác được đến, chi phí}; thanh trạng thái cập nhật.', 'M', 'M1', 'UR-NL-07'],
  ['FR-DLG-08', 'memory.* ghi nhớ lựa chọn (D8) và thứ tự nguồn (D5: người nói > dự án > registry/mẫu tham chiếu > web); kịch bản Z-01…Z-10 là bộ kiểm thử hành vi bắt buộc.', 'M', 'M1', 'UR-NL-05'],
]));
c.push(SP());
c.push(H1('3B. Yêu cầu chức năng theo năng lực (sinh từ Danh mục v1.1)'));
c.push(P(`Mỗi dòng dưới đây là một yêu cầu chức năng có mã FR-<NHÓM>-<số> trùng mã trong Danh mục năng lực [25]. Cột **R** là lớp rủi ro (R0 đọc · R1 ghi tri thức · R2 ghi mã · R3 phần cứng lab · R4 không hoàn tác/vật lý), **Mức** là mức tự chủ (T1 AI làm trọn · T1* tự làm khi chính sách có bằng chứng · T2 AI làm — người duyệt · T3 người làm), **Hỏi kỹ sư khi** là điều kiện PolicyGate chuyển sang ASK. Tổng ${CAPS.length} năng lực trong ${NS_ORDER.length} nhóm: T1 ${count(x => x.tier === 'T1')}, T1* ${count(x => x.tier === 'T1*')}, T2 ${count(x => x.tier === 'T2')}, T3 ${count(x => x.tier === 'T3')}; đã có trong M0: ${count(x => x.m0.includes('có'))}. Hợp đồng đầy đủ (tham số vào/ra, grounding, mốc) nằm trong Excel; SDD-04 §4.0 định nghĩa schema hợp đồng.`));
const WC = [1750, 1550, 3300, 500, 600, 1600]; const HC = ['Mã FR', 'Năng lực', 'Yêu cầu', 'R', 'Mức', 'Hỏi kỹ sư khi'];
NS_ORDER.forEach((ns, i) => {
  const rows = byNs(ns);
  c.push(H2(`3B.${i + 1}. ${ns.toUpperCase()} — ${NS_VI[ns]} (${rows.length})`));
  c.push(T(WC, HC, rows.map(r => [`FR-${r.code}`, r.name, `${r.desc}. Vào: ${r.inp}; ra: ${r.out}. Mốc ${r.ms}${r.m0.includes('có') ? ' (M0: ' + r.m0 + ')' : ''}.`, r.risk, r.tier, r.ask]), { size: 19 }));
  c.push(SP());
});
c.push(H1('4. Yêu cầu phi chức năng'));
c.push(T([1200, 2000, 6100], ['Mã', 'Nhóm', 'Yêu cầu'], [
  ['NFR-01', 'An toàn quy trình', 'Không tồn tại đường thực thi cho merge ngoài G3, cho nạp/xóa/ghi ngoài G-OPS, cho fact tầng bạc/đồng vào mã trước G-FACT; test tự động chứng minh'],
  ['NFR-02', 'Trung thực dữ liệu', '100% fact có Source; hằng số trong mã có fact id; tác tử trả "không tìm thấy" khi thiếu'],
  ['NFR-03', 'Hiệu năng', 'passport.query < 200 ms (P95); nhập SVD 1 chip < 2 s; mở log 3 GB < 5 s; build–nạp–log < 2 phút'],
  ['NFR-04', 'Tin cậy dữ liệu', 'Ghi nguyên tử (SQLite WAL); khôi phục sau crash không mất fact đã xác nhận'],
  ['NFR-05', 'Độc lập mô hình', 'Đổi nhà cung cấp bằng cấu hình; bộ kiểm thử hợp đồng Gateway xanh trên ≥ 3 mô hình'],
  ['NFR-06', 'Bảo mật', 'Bản đầu dùng Internet và LLM đám mây; khóa qua biến môi trường; nhật ký không chứa khóa; dự án gắn cờ nhạy cảm ⇒ hỏi trước khi gửi tài liệu ra ngoài; extractor và công cụ cài đặt chạy trong sandbox; chế độ cục bộ 0 kết nối ngoài là tùy chọn M5'],
  ['NFR-07', 'Di động', 'Knowledge Plane/CLI: macOS, Linux, Windows; plugin: macOS (GEditor)'],
  ['NFR-08', 'Mở rộng', 'Extractor, ISA profile, adapter, vai trò tác tử là plugin qua entry point; thêm mới không sửa core'],
  ['NFR-09', 'Truy vết', 'Mọi fact, mã, quyết định gate, lượt gọi mô hình liên kết được với nhau và với người/thời điểm'],
  ['NFR-10', 'Chi phí', '≤ 8.000 token/lượt; ngân sách ngày; báo cáo theo vai trò'],
  ['NFR-11', 'Khả kiểm', 'Bộ test đơn vị + hợp đồng + benchmark trên board; CI chạy phần không cần board'],
  ['NFR-12', 'Ngôn ngữ', 'Giao diện và đầu ra tiếng Việt mặc định; tiếng Anh tùy chọn; lệnh nhận cả hai'],
  ['NFR-13', 'Tự động hóa', 'Kịch bản chuẩn ≤ 5 lần bấm/duyệt và ≤ 3 câu lệnh; ≥ 85% năng lực mức T1; mọi hành động tự làm có hoàn tác và lý do trong decision_log; dừng khẩn < 1 s'],
  ['NFR-14', 'Hợp đồng năng lực', 'Mọi năng lực đăng ký trong Capability Registry với schema 13 trường; UI và Orchestrator gọi cùng một registry; thêm năng lực = thêm khai báo + hiện thực, không sửa Orchestrator'],
  ['NFR-15', 'Chất lượng lược đồ và tài liệu', 'Lược đồ sinh ra qua diagram.lint 0 lỗi và render được trong GEditor; tài liệu qua doc.style_check 0 lỗi (tiếng Việt ưu tiên, thuật ngữ có giải nghĩa, khẳng định có nguồn)'],
]));
c.push(SP());
c.push(H1('5. Yêu cầu giao diện ngoài'));
c.push(T([2300, 6900], ['Giao diện', 'Đặc tả'], [
  ['MCP (server)', 'Theo đặc tả MCP [13]; tool schema là tập con JSON Schema (object/string/number/integer/boolean/array/enum, sâu ≤ 3)'],
  ['Socket GEditor ↔ Knowledge Plane', 'JSON-RPC 2.0 qua Unix socket; sự kiện push cho hàng đợi xác nhận và tiến độ'],
  ['LLM', 'Anthropic Messages API, Google GenAI, OpenAI-compatible; qua ModelPort'],
  ['Toolchain/probe', 'subprocess với timeout; probe-rs/OpenOCD qua embedded-debugger-mcp; pyserial'],
  ['Registry', 'HTTP GET index.json + gói .hkp; publish qua Git push (nội bộ)'],
  ['Tệp', 'SVD, ATDF, EDC, YAML binding, PDF, DOCX, XLSX, HTML, MD, PNG/JPG, zip/rar/7z/tar (lồng nhau), .kicad_sch, .hex/.elf/.bin, .map, CSV sigrok'],
  ['Lược đồ', 'Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG — sinh dạng văn bản, render trong GEditor; xuất PNG/SVG khi chèn tài liệu [31]–[35]'],
  ['Tài liệu xuất', 'docx (docx-js theo mẫu EAA), md, pdf, xlsx (ma trận truy vết, Người–AI), pptx'],
  ['USB / probe / mạng', 'Liệt kê VID/PID (libusb/pyserial), probe-rs/OpenOCD probe list, esptool, mDNS; đọc ID chip qua probe/bootloader [39]'],
  ['Chỉ mục RAG', 'Chunk văn bản/OCR/mã + embedding (qua Gateway) + chỉ mục từ khóa + đồ thị; lưu trong `.eide/index/` (không commit)'],
]));
c.push(SP());
c.push(H1('6. Tiêu chí nghiệm thu tổng quát'));
c.push(P('EIDE v1.0 (hết M4) được nghiệm thu khi: (1) ba kịch bản A/B/C của PDA-00 và kịch bản chuẩn 17 bước [28] chạy đầu-cuối trên STM32 Nucleo và ATmega328P với hai mô hình khác hãng, **từ lệnh ngôn ngữ tự nhiên với ≤ 5 lần bấm/duyệt**; (2) mọi TC Must trong EIDE-STP-05 đạt, gồm TC tự chủ và TC hội thoại Z-01…Z-10; (3) kiểm mẫu 100 hằng số trong mã sinh ra có fact id đúng; (4) nhật ký chứng minh 0 hành động R4 tự động, mọi hành động tự làm có lý do và hoàn tác được; (5) registry nội bộ có ≥ 500 gói hạt giống và ≥ 20 gói đã kiểm định; (6) thêm ISA thứ ba (rv32) với 0 dòng core thay đổi; (7) 228/238 năng lực đăng ký trong registry, ≥ 80% năng lực mốc M0–M2 hiện thực và có TC.'));
c.push(H1('7. Ma trận truy vết UR → FR'));
c.push(T([1500, 7800], ['UR', 'FR'], [
  ['TT-01…08', 'ACQ-01…09; PSP-01…06; GOV-05; BEN-02'], ['MC-01…04', 'BRD-01…04; PSP-05'], ['MA-01…05', 'AGT-01…07; MCP-01…04; LLM-03'],
  ['XM-01…04', 'VER-01…05; MCP-02'], ['GL-01…03', 'DBG-01…04'], ['QS-01…06', 'UI-01…07; DBG-04; VER-03'], ['MH-01…03', 'LLM-01…04; AGT-04, AGT-06'],
  ['RG-01…04', 'REG-01…05; GOV-06'], ['QT-01…07', 'GOV-01…05; PSP-03; AUT-01…05'], ['HT-01…04', 'BEN-01…03; AGT-07; GOV-06; AUT-06'],
  ['NL-01…07', 'DLG-01…08; AUT-03…04; FR-CHAT-*, FR-POLICY-*, FR-MEMORY-*'], ['KN-01…07', 'FR-REQ-*, FR-ARCH-*, FR-DIAGRAM-*, FR-DOC-*'], ['TQ-01…04', 'FR-VIEW-*; PSP-05, PSP-06'], ['DT-01…04', 'FR-DISCOVER-*; VER-02, VER-03'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-SRS-02_Dac_ta_yeu_cau.docx');
