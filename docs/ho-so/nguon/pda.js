const { P, H1, H2, H3, CAP, SP, PB, CODE, T, KV, IMG, build } = require('./eaa_doc');
const { Paragraph, TextRun, AlignmentType } = require('docx');
const { CAPS, NS_ORDER, NS_VI, byNs, count, DOCSET, H11, H12 } = require('./eide_common');

const meta = {
  kicker: 'HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG · ĐỀ ÁN TỐT NGHIỆP THẠC SĨ KỸ THUẬT ĐIỆN TỬ · EIDE v1.2', footer: 'EIDE — Phân tích thiết kế sản phẩm v1.2',
  code: 'EIDE-PDA-00', short: 'Phân tích thiết kế sản phẩm', version: '1.2',
  title: 'EIDE — EMBEDDED IDE',
  subtitle: 'Phân tích thiết kế chi tiết để hiện thực hóa: tác tử điều phối theo lệnh ngôn ngữ tự nhiên gọi 238 năng lực có hợp đồng trên một Knowledge Plane với hộ chiếu chip/mạch, đồ thị tri thức, tác tử đa mô hình, registry chia sẻ, và GEditor làm cửa sổ quan sát phần cứng và lược đồ',
  attrs: [
    ['Mã tài liệu', 'EIDE-PDA-00 (trước đây HKW-PDA-00, Product Design Analysis)'],
    ['Phiên bản', '1.2 — đồng bộ với 19 tài liệu bổ sung và năng lực gốc tool.*'],
    ['Ngày lập', '05/09/2026'],
    ['Người lập', 'Vũ Trí Công — học viên cao học (hỗ trợ soạn thảo: Claude)'],
    ['Người hướng dẫn', 'TS. Nguyễn Trung Hiếu'],
    ['Khuôn khổ', 'Đề án tốt nghiệp Thạc sĩ ngành Kỹ thuật Điện tử — Học viện Công nghệ Bưu chính Viễn thông (PTIT)'],
    ['Sản phẩm', 'EIDE (Embedded IDE) — trước đây Hardware Knowledge Workbench (HKW), tên mã "Passport"; sản phẩm độc lập với đề án EAA nhưng tái sử dụng Engine/LLM Gateway của EAA-U; bản đầu chạy trên một PC có Internet; màu thương hiệu PTIT'],
    ['Tài liệu liên quan', 'GEditor v2.2 (154 FR); EAA-U: Phân tích yêu cầu v0.1, Phân tích thiết kế Agent v0.1, EAA-URD-06 v2.0; Danh mục năng lực v1.2 (Excel); Use case chi tiết v1.2 (Excel); Kế hoạch backlog PLN-27; 19 tài liệu bổ sung CXD…CON; mockup EIDE-UI v1.2'],
    ['Bộ hồ sơ', DOCSET],
  ],
  history: [
    ['0.1', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu sau phiên "va đập" ý tưởng: chốt định vị Knowledge Workbench thay vì IDE; hộ chiếu chip/mạch; tri thức máy-đọc-được trước, trích xuất sau; registry chia sẻ; GEditor là bề mặt quan sát'],
    ['1.0', '05/09/2026', 'Vũ Trí Công', 'Bộ hồ sơ HKW v1.0 (URD…BPD, KAD) phát hành trên nền PDA-00; mã M0 (hkw-core) chạy'],
    ['1.1', '05/09/2026', 'Vũ Trí Công', H11 + '. Sửa P3, P4; thêm §1.4 ba thay đổi định hướng, §14 danh mục năng lực, cập nhật lộ trình'],
    ['1.2', '05/09/2026', 'Vũ Trí Công', H12],
  ],
};
const c = [];

// 1
c.push(H1('1. Tầm nhìn, định vị và nguyên tắc sản phẩm'));
c.push(H2('1.1. Một câu định vị'));
c.push(P('*Một môi trường phát triển nhúng nơi kỹ sư ra lệnh bằng ngôn ngữ tự nhiên và tác tử làm gần hết: mỗi con chip và mỗi mạch có một hộ chiếu tri thức có thể xác minh và chia sẻ; tác tử làm việc trên hộ chiếu đó chứ không phải trên trí nhớ của mô hình; mọi chức năng là một năng lực có hợp đồng mà tác tử tự gọi theo chính sách tự chủ; và GEditor là cửa sổ nhìn vào những gì phần cứng thật sự làm và vào các lược đồ, bản đồ tri thức của dự án.*'));
c.push(H2('1.2. Vì sao không gọi là IDE'));
c.push(P('Thị trường trình soạn thảo mã có AI đã có Cursor, Windsurf, Claude Code, GitHub Copilot với đội ngũ hàng trăm người; cạnh tranh ở lớp soạn thảo là cuộc đua không thể thắng bằng nguồn lực một công ty nhỏ. Ngược lại, lớp "tri thức phần cứng có cấu trúc, có nguồn, có thể chia sẻ" còn trống: Embedder có Hardware Catalog nhưng đóng và không cho người dùng tự nuôi tri thức [1]; các hãng chip chỉ phục vụ hệ sinh thái của mình qua MCP server [2], [3]; công cụ ghi chú tri thức như Obsidian hay NotebookLM không hiểu thanh ghi, chân, timing. EIDE đứng ở ô trống đó và nối vào các IDE hiện có qua MCP thay vì thay thế chúng.'));
c.push(H2('1.3. Nguyên tắc sản phẩm (không thương lượng)'));
c.push(T([600, 2800, 5900], ['#', 'Nguyên tắc', 'Hệ quả thiết kế'], [
  ['P1', 'Tri thức máy-đọc-được trước, trích xuất sau', 'Bản đồ thanh ghi lấy từ SVD/ATDF/EDC/binding của hãng khi có [4]–[7]; PDF chỉ cho ngoại vi ngoài; mọi fact từ PDF mang mức tin cậy thấp hơn và cần người xác nhận'],
  ['P2', 'Không có fact nào thiếu nguồn', 'Mỗi fact trong hộ chiếu có provenance (tệp, hash, trang/dòng, phương pháp trích, người xác nhận, thời điểm); tác tử bị chặn khi dùng hằng số không nguồn'],
  ['P3', 'Con người kiểm soát mọi điểm không đảo ngược; mọi điểm còn lại do chính sách tự chủ quyết định (sửa v1.1)', 'Xóa flash, fuse, cơ cấu chấp hành, phát hành công khai, gửi tài liệu nhạy cảm: luôn hỏi người. Chọn nguồn, duyệt fact, kế hoạch, merge, nạp board lab: PolicyGate quyết định APPROVE/ASK/REJECT theo lớp rủi ro và mức tự chủ, có bằng chứng, nhật ký và hoàn tác (EIDE-APD-08)'],
  ['P4', 'Dữ liệu tại máy kỹ sư, mở, không khóa nhà cung cấp (sửa v1.1)', 'Daemon và dữ liệu dự án trên PC của kỹ sư (commit Git được); định dạng hộ chiếu mở (YAML/JSON có schema); LLM đám mây (Claude/Gemini) đổi được bằng cấu hình; Internet đầy đủ là mặc định của bản đầu; toolchain mở là mặc định; chế độ cục bộ hoàn toàn là tùy chọn sau'],
  ['P5', 'Hai tầng tách bạch: chip và mạch', 'ChipPassport (tập lệnh, lõi, ngoại vi trong, thanh ghi) tách khỏi BoardPassport (chân, nguồn, ngoại vi ngoài, ràng buộc cơ khí); dự án = chip + mạch + ràng buộc'],
  ['P6', 'Tri thức là gói có phiên bản, có thể chia sẻ', 'Hộ chiếu, skill, benchmark đóng gói thành .hkp có chữ ký và huy hiệu "đã chạy thật"; registry là hào nước của sản phẩm'],
  ['P7', 'GEditor là bề mặt quan sát, không phải trình soạn thảo cạnh tranh', 'Tập trung vào log/trace/hex/waveform cỡ gigabyte, bản đồ tri thức, lược đồ (Mermaid, PlantUML, DOT, D2, WaveDrom, SVG) và tính năng "hỏi tác tử tại dòng này"; mã nguồn soạn ở IDE người dùng đã quen'],
  ['P8', 'Lệnh ngôn ngữ tự nhiên là giao diện chính (mới v1.1)', 'Cửa sổ trò chuyện là màn hình mặc định; kỹ sư mô tả điều muốn làm; tác tử hiểu, đối chiếu trạng thái, lập chuỗi năng lực, điền mặc định, hỏi tối đa một câu gộp, làm rồi báo cáo (EIDE-DPS-09)'],
  ['P10', 'Tác tử tự tạo công cụ khi thiếu năng lực (mới v1.2)', 'Nhóm tool.*: tác tử tự đặc tả, viết công cụ Python kèm test và hiệu ứng khai báo, kiểm trong sandbox, chạy theo chính sách với lớp rủi ro suy ra từ hiệu ứng, đăng ký thành năng lực tạm và thăng cấp sau khi chứng minh — năng lực gốc có thể sinh ra mọi năng lực khác; Danh mục 238 năng lực thiết kế trước là tập đã được tối ưu và kiểm định'],
  ['P9', 'Mọi chức năng là một năng lực có hợp đồng (mới v1.1)', '238 năng lực trong 27 nhóm, mỗi năng lực khai báo tham số vào/ra, lớp rủi ro, mức tự chủ, grounding, điều kiện hỏi, hoàn tác; người gọi qua giao diện và tác tử gọi trong chuỗi dùng cùng một registry, chính sách và nhật ký'],
]));
c.push(SP());
c.push(H2('1.4. Ba thay đổi định hướng của v1.1'));
c.push(P('Sau khi bộ hồ sơ v1.0 và mã M0 hoàn thành, việc rà soát bộ use case chi tiết cho kịch bản "board mới, zip hỗn hợp" cho thấy thiết kế v1.0 dừng ở quá nhiều điểm chờ người (khoảng 40 lần bấm/duyệt cho một dự án cỡ driver) và giao diện vẫn theo mô hình "người bấm nút". Chủ sản phẩm chốt ba thay đổi: **(1) tác tử làm gần hết theo lệnh ngôn ngữ tự nhiên** — người dùng giảm thao tác đến mức tối thiểu, mục tiêu ≤ 5 lần bấm/duyệt và ≤ 3 câu lệnh cho kịch bản chuẩn; **(2) bản đầu tiên chạy trên một máy PC có Internet đầy đủ** — LLM đám mây, tìm và tải tài liệu trên mạng là hành vi bình thường, không có chế độ offline mặc định; **(3) công việc phân thành ba mức tự chủ** T1 AI làm trọn / T2 AI làm — người duyệt / T3 người làm (cộng T1* tự làm khi chính sách có bằng chứng), trên nền năm mức tự chủ dự án A0–A4 và năm lớp rủi ro R0–R4 của EIDE-APD-08. Hệ quả kiến trúc: các chức năng phần mềm vẫn được xây cho người dùng, nhưng được khai báo thành **năng lực có hợp đồng** để tác tử gọi; tầng hiểu lệnh (Orchestrator) có bốn trách nhiệm — hiểu và đối chiếu, lập chuỗi, đảm bảo đủ thông tin bằng mặc định trước hỏi sau, áp chính sách và báo cáo — cộng phần sinh (mã, chẩn đoán, tài liệu) do các vai trò LLM đảm nhiệm. Tên sản phẩm đổi thành EIDE (Embedded IDE) với màu thương hiệu PTIT.'));
c.push(...IMG('hinh/eide_caps_arch.png', 600, 415, 'Hình 0. Kiến trúc năng lực v1.2: kỹ sư → tác tử điều phối (bốn trách nhiệm) → Capability Registry (27 nhóm, gồm nhóm gốc tool.*) → Knowledge Plane'));

// 2 users & scenarios
c.push(H1('2. Người dùng và ba kịch bản đầu-cuối'));
c.push(T([2400, 3300, 3600], ['Người dùng', 'Nỗi đau hiện tại', 'EIDE giải quyết bằng'], [
  ['Kỹ sư nhúng ở startup phần cứng', 'Mất ngày đọc datasheet 800 trang; AI bịa thanh ghi; không dám để AI nạp board; datasheet là IP không được gửi ra ngoài', 'Hộ chiếu có nguồn; catalog.query thay đọc PDF; cổng người; chế độ cục bộ'],
  ['Kỹ sư dùng chip lạ / chip tùy chỉnh (FPGA soft-core, ASIC nội bộ)', 'Không có BSP, không có ví dụ, AI không biết gì', 'Viết hộ chiếu từ SVD/CSV nội bộ; tác tử sinh driver từ hộ chiếu; mô phỏng Renode theo mô tả nền tảng'],
  ['Kỹ sư gỡ lỗi hiện trường', 'Log serial hàng giờ, bản ghi logic analyzer nhiều GB, không công cụ nào mở nổi và AI không đọc được', 'GEditor mở gigabyte; "hỏi tại dòng"; đối chiếu log với hộ chiếu và mã'],
  ['Giảng viên / học viên AI-Native', 'Thiếu tài liệu tiếng Việt, board rẻ, bài thực hành chạy được', 'Registry hộ chiếu cộng đồng; bài tập "viết hộ chiếu cho board X" sinh tri thức dùng chung'],
]));
c.push(SP());
c.push(H2('2.1. Kịch bản A — "Tôi vừa mua một board chưa ai biết"'));
c.push(P('Kỹ sư kéo thư mục chứa PDF datasheet, tệp .kicad_sch và một .zip SDK của hãng vào EIDE. Acquisition mở .zip, nhận ra trong đó có tệp .svd và header C; đánh dấu SVD là nguồn "vàng" cho bản đồ thanh ghi, header là nguồn đối chiếu; PDF chỉ dùng cho phần điện (điện áp, dòng, timing) và cho các ngoại vi mà SVD không mô tả. Hệ thống trình bản nháp ChipPassport với từng nhóm fact và mức tin cậy; kỹ sư duyệt theo nhóm (không phải từng dòng), sửa hai chỗ. Từ .kicad_sch, Cartographer sinh BoardPassport (chân – tín hiệu – linh kiện) và phát hiện PB3 vừa nối LED vừa là MOSI: cảnh báo xung đột. Kỹ sư bấm "kiểm định": EIDE biên dịch firmware đọc thanh ghi ID chip qua toolchain của ISA profile, nạp (sau khi hỏi), đọc lại giá trị và so với hộ chiếu → gắn huy hiệu "đã xác minh trên board". Toàn bộ mất khoảng một buổi thay vì một tuần, và kết quả là một gói .hkp có thể chia sẻ.'));
c.push(H2('2.2. Kịch bản B — "Viết driver cho cảm biến này, đừng bịa"'));
c.push(P('Từ Claude Code, kỹ sư gõ "viết driver I2C cho BME280 trên board này". Claude Code gọi tool passport.query của EIDE qua MCP; EIDE trả về địa chỉ I2C, bảng thanh ghi, chuỗi khởi tạo, kèm trích dẫn trang datasheet và mức tin cậy. Mã sinh ra được EIDE kiểm bằng hook: mọi hằng số phải khớp hộ chiếu; một hằng số 0x76/0x77 không có trong hộ chiếu → chặn và yêu cầu bổ sung fact (vì chân SDO quyết định địa chỉ, thông tin nằm ở BoardPassport). Sau khi qua build – size – static – host test, EIDE đề nghị nạp và mở cửa sổ serial trong GEditor; kỹ sư xác nhận đọc được nhiệt độ hợp lý → tính năng chuyển "passing", mã được gắn vào đồ thị như bằng chứng cho fact đã dùng.'));
c.push(H2('2.3. Kịch bản C — "Board treo sau 6 giờ, đây là 3 GB log"'));
c.push(P('Kỹ sư mở log 3 GB trong GEditor; nhảy tới đoạn trước khi treo, bôi đen 200 dòng, bấm "hỏi tác tử". EIDE không gửi 3 GB; nó gửi đoạn đã chọn, thống kê mẫu của toàn tệp (tần suất dòng lỗi, khoảng cách thời gian) do GEditor tính, hộ chiếu chip (bảng thanh ghi watchdog, DMA) và đoạn mã liên quan lấy từ đồ thị. Debugger trả về giả thuyết xếp hạng và một thí nghiệm phân biệt: "bật RTT đọc thanh ghi X mỗi 100 ms". Nếu có probe, EIDE đề nghị chạy thí nghiệm ngay; nếu không, sinh firmware kiểm tra. Bản ghi phiên gỡ lỗi được lưu vào sổ lỗi gắn với fact và mã liên quan, thành tri thức của dự án.'));

// 3 architecture
c.push(H1('3. Kiến trúc tổng thể'));
c.push(...IMG('hinh/hkw_arch.png', 600, 415, 'Hình 1. Ba bề mặt (GEditor, IDE ngoài qua MCP, CLI/CI) trên một Knowledge Plane cục bộ; bốn khối trong Knowledge Plane; bốn hệ thống ngoài'));
c.push(H2('3.1. Các thành phần và trách nhiệm'));
c.push(T([2300, 4200, 2800], ['Thành phần', 'Trách nhiệm', 'Tái sử dụng từ'], [
  ['Knowledge Plane (daemon)', 'Tiến trình cục bộ, giao diện gRPC/HTTP nội bộ + MCP server; giữ Passport Store, KG, hàng đợi review, cổng người, nhật ký', 'Engine EAA (máy trạng thái, gate, ToolReport) [8]'],
  ['Acquisition', 'Phát hiện thiếu → tìm ứng viên → xác nhận → trích xuất theo tầng → chuẩn hóa → review → kiểm định', 'Ingest loop + Information Sufficiency Loop của EAA-AIS-05'],
  ['Passport Store + KG', 'Lưu hộ chiếu (YAML có schema) và đồ thị quan hệ; truy vấn xung đột, ảnh hưởng, thay thế; Graph-RAG', 'KG NetworkX + BM25 của EAA; nâng cấp lưu trữ (mục 6)'],
  ['Agent Runtime', 'LLM Gateway đa mô hình; vai trò Librarian, Cartographer, Coder, Debugger, Reviewer; composer ngữ cảnh; hooks', 'LLM Gateway và composer K1–K7 của EAA-U [9]'],
  ['Tool & Target Layer', 'ISA profile, toolchain manifest, adapter build/flash/probe/serial/sim/measure', 'Platform Pack của EAA-U [9]; embedded-debugger-mcp [10]'],
  ['Workbench UI (GEditor)', 'Trình duyệt hộ chiếu, đồ thị, hàng đợi xác nhận, log/trace/hex gigabyte, "hỏi tại dòng", serial, waveform', 'GEditor v2.2 (engine tệp lớn, plugin)'],
  ['Registry client', 'pull/publish gói .hkp, kiểm chữ ký, hiển thị huy hiệu, xử lý license', 'Mới'],
]));
c.push(SP());
c.push(H2('3.2. Ranh giới quan trọng'));
c.push(P('Ba ranh giới quyết định sản phẩm có sống được không. Thứ nhất, **UI không chứa logic tri thức**: GEditor và IDE ngoài đều là client của cùng một Knowledge Plane, nên tri thức và cổng người nhất quán dù người dùng làm việc ở đâu. Thứ hai, **tác tử không chạm phần cứng trực tiếp**: mọi thao tác đi qua Tool Layer với ToolReport và quyền theo phiên; tác tử chỉ "đề nghị". Thứ ba, **mô hình ngôn ngữ không phải nguồn sự thật**: mô hình chỉ được gọi với ngữ cảnh do composer lấy từ hộ chiếu; đầu ra được kiểm hai lớp (schema + đối chiếu hộ chiếu) trước khi có hiệu lực.'));

// 4 passports
c.push(H1('4. Mô hình dữ liệu: hộ chiếu chip và hộ chiếu mạch'));
c.push(H2('4.1. Ba tầng tin cậy và provenance'));
c.push(T([1400, 3300, 4600], ['Tầng', 'Nguồn', 'Quy tắc'], [
  ['Vàng (gold)', 'Tệp có cấu trúc do hãng phát hành: CMSIS-SVD [4], ATDF trong Device Family Pack của Microchip [5], EDC/.PIC [6], devicetree binding của Zephyr [7], header C chính hãng; mô tả tập lệnh hình thức (RISC-V Sail [11], LLVM TableGen [12])', 'Nhập bằng parser xác định; không cần người xác nhận từng fact, chỉ xác nhận nguồn (hash, phiên bản); mức tin cậy 0,95–1,0'],
  ['Bạc (silver)', 'PDF datasheet/reference manual, HTML tài liệu hãng, ảnh schematic', 'Trích xuất bằng công cụ bố cục (Docling [13], pdfplumber) + LLM có schema; mỗi fact kèm trang, bbox, ảnh cắt; bắt buộc người xác nhận theo nhóm; mức 0,6–0,9'],
  ['Đồng (bronze)', 'Web, diễn đàn, repo cộng đồng, suy luận của tác tử', 'Chỉ làm gợi ý; không được dùng để sinh mã cho đến khi được nâng lên bạc/vàng bằng nguồn tốt hơn hoặc kiểm định trên board; mức < 0,6'],
]));
c.push(SP());
c.push(P('Mỗi fact là một bản ghi bất biến: `{id, subject, predicate, value, unit, source{uri, sha256, locator}, method, confidence, confirmed_by, confirmed_at, supersedes}`. Sửa một fact là tạo fact mới với `supersedes` trỏ về fact cũ; đồ thị giữ toàn bộ lịch sử và cho phép hỏi "mã nào đang trích dẫn fact đã bị thay thế".'));
c.push(H2('4.2. ChipPassport'));
c.push(...CODE([
  'passport: chip',
  'id: st.stm32f411ce@1.2.0            # namespace.part@semver',
  'identity: { vendor: STMicroelectronics, part: STM32F411CE, revision: Z, package: UFQFPN48 }',
  'isa: { profile: armv7e-m.thumb2, core: cortex-m4f, fpu: fpv4-sp, endianness: little }',
  'memory: [ {name: FLASH, base: 0x08000000, size: 512K}, {name: SRAM, base: 0x20000000, size: 128K} ]',
  'clocks: { hsi: 16MHz, sysclk_max: 100MHz, sources: [...] }',
  'peripherals:                          # từ SVD (vàng)',
  '  - { name: I2C1, base: 0x40005400, irq: [31, 32], registers_ref: svd#I2C1 }',
  'pins:                                 # từ datasheet/pinout (bạc) hoặc SVD nếu có',
  '  - { pad: PB6, functions: [I2C1_SCL(AF4), TIM4_CH1(AF2), GPIO] }',
  'electrical: { vdd: [1.7V, 3.6V], io_max: 25mA, temp: [-40, 85] }   # bạc, có trang',
  'errata: [ { id: ES0287-2.4.1, affects: I2C1, workaround_ref: doc#... } ]',
  'toolchain_hint: { compiler: arm-none-eabi-gcc, flags: [-mcpu=cortex-m4, -mfpu=fpv4-sp-d16, -mfloat-abi=hard] }',
  'debug: { interfaces: [SWD, JTAG], probe_targets: [probe-rs:STM32F411CETx, openocd:stm32f4x] }',
  'sim: { renode_platform: platforms/cpus/stm32f4.repl }',
  'sources: [ {uri: ..., sha256: ..., tier: gold, kind: svd}, {uri: ..., tier: silver, kind: pdf, pages: 1-149} ]',
  'badges: [ verified_on_board: {board: weact-blackpill-f411, date: ..., by: ...} ]',
]));
c.push(SP());
c.push(H2('4.3. BoardPassport'));
c.push(...CODE([
  'passport: board',
  'id: weact.blackpill-f411@1.0.0',
  'chips: [ { ref: U1, passport: st.stm32f411ce@1.2.0 } ]',
  'external_parts: [ { ref: U2, passport: bosch.bme280@0.3.0, bus: I2C1, addr: 0x76, note: "SDO->GND" } ]',
  'nets:                                # từ KiCad netlist (vàng-cấu trúc) hoặc ảnh schematic (bạc)',
  '  - { name: I2C1_SCL, pins: [U1.PB6, U2.SCL], pullup: 4k7 }',
  'power: { input: [USB 5V, 3V3 pin], regulator: {part: ME6211, imax: 500mA} }',
  'constraints: { reserved_pins: [PA13, PA14], boot_pins: [BOOT0] }',
  'conflicts_checked: true              # Cartographer đã chạy kiểm tra chức năng chân',
  'sources: [ {uri: schematic.kicad_sch, sha256: ..., tier: gold}, {uri: photo_board.jpg, tier: silver} ]',
]));
c.push(SP());
c.push(H2('4.4. ISA profile (tầng tập lệnh)'));
c.push(P('ISA profile là hộ chiếu cấp thấp hơn chip, dùng chung cho mọi chip cùng tập lệnh: quy ước ABI, mô hình ngắt/ngoại lệ, thanh ghi hệ thống, toolchain và trình gỡ lỗi mặc định, trình mô phỏng, và các "bẫy" lập trình đặc thù (ví dụ AVR: bộ nhớ Harvard và PROGMEM; Cortex-M: ưu tiên ngắt và PRIMASK; RISC-V: CSR và mô hình ngắt PLIC/CLINT; PIC16: bank thanh ghi và giới hạn stack). Profile có thể bắt nguồn từ mô tả hình thức khi có (RISC-V Sail [11], LLVM TableGen [12]) và luôn kèm skill do chuyên gia viết. Danh sách khởi đầu: armv6-m, armv7-m/e-m, armv8-m, rv32i/imc/imac, avr8, pic16-enhanced-midrange, pic18, pic24/dspic, mips32-m4k (PIC32MX), xtensa-lx6/lx7, và mẫu `custom` cho chip tùy chỉnh.'));

// 5 acquisition
c.push(H1('5. Đường ống nhận tri thức (Acquisition)'));
c.push(...IMG('hinh/hkw_pipeline.png', 600, 196, 'Hình 2. Sáu bước nhận tri thức; hai bước vàng bắt buộc có con người'));
c.push(H2('5.1. Từng bước'));
c.push(T([2000, 7300], ['Bước', 'Chi tiết hiện thực'], [
  ['1. Phát hiện thiếu', 'Mọi truy vấn passport.query không khớp hộ chiếu nào, hoặc tác tử tự đánh giá "thiếu thông tin" (Information Sufficiency Loop), tạo một *yêu cầu nhận tri thức* với mô tả cần gì (chip, ngoại vi, trường)'],
  ['2. Tìm ứng viên', 'Thứ tự: registry → kho cục bộ → nguồn hãng đã biết (URL pattern theo vendor) → tìm kiếm web. Với mỗi ứng viên: loại (svd/atdf/pdf/zip/repo), kích thước, license nếu đọc được, hash nếu tải được. Không tải tự động quá ngưỡng dung lượng'],
  ['3. Người xác nhận', 'Giao diện liệt kê ứng viên với nguồn, ngày, license, kích thước; người dùng chọn, loại, hoặc tự đưa tệp. Ghi quyết định vào nhật ký (ai, khi nào, vì sao)'],
  ['4. Trích xuất theo tầng', 'Bộ điều phối extractor theo kiểu tệp: .zip/.7z/.tar → mở và phân loại đệ quy; .svd/.atdf/.pic/.yaml/.h → parser xác định; .pdf → Docling/pdfplumber lấy bảng và bố cục [13], sau đó LLM có schema chuyển bảng thành fact, giữ bbox và ảnh cắt; .docx/.xlsx → pandoc/openpyxl; .kicad_sch → kicad-cli netlist [14]; ảnh → mô hình thị giác với schema; .html → readability + bảng. Mỗi extractor trả `facts[]` với confidence và locator'],
  ['5. Chuẩn hóa + KG', 'Ánh xạ vào schema hộ chiếu; hợp nhất trùng lặp (cùng subject/predicate từ nhiều nguồn → giữ nguồn tầng cao nhất, ghi mâu thuẫn nếu giá trị khác); ghi vào Passport Store và đồ thị với provenance'],
  ['6. Review & kiểm định', 'Hàng đợi review theo nhóm (thanh ghi, chân, điện, errata); người dùng duyệt nhóm; với chip có board: chạy "kiểm định ID" (đọc DBGMCU_IDCODE / signature bytes / device ID) và tùy chọn kiểm định chức năng cơ bản (GPIO toggle, UART echo); gắn huy hiệu'],
]));
c.push(SP());
c.push(H2('5.2. Vì sao "mọi loại tệp" vẫn đạt được mà không hứa quá'));
c.push(P('Mọi định dạng đều được *mở* (bước 4 có extractor tổng quát: mở nén, chuyển văn bản), nhưng chỉ định dạng có parser xác định mới sinh fact tầng vàng; các định dạng khác sinh fact tầng bạc/đồng và bắt buộc qua bước 6. Nhờ vậy sản phẩm nhận được tệp bất kỳ mà không bao giờ để một con số chưa xác nhận đi vào mã.'));
c.push(H2('5.3. Pháp lý và license'));
c.push(P('EIDE không phân phối lại PDF của hãng. Gói .hkp chứa fact đã trích xuất kèm con trỏ nguồn (URI, hash, trang), không chứa bản sao tài liệu trừ khi license cho phép (SVD của nhiều hãng phát hành theo Apache-2.0 trong CMSIS pack [4]; ATDF nằm trong pack có điều khoản riêng của Microchip [5]). Trường license trong `sources[]` là bắt buộc và registry từ chối gói thiếu trường này. Đây là điểm cần luật sư xem trước khi mở registry công khai.'));

// 6 KG
c.push(H1('6. Đồ thị tri thức: lược đồ, truy vấn và lưu trữ'));
c.push(H2('6.1. Lược đồ'));
c.push(T([2200, 7100], ['Loại nút', 'Ví dụ / thuộc tính'], [
  ['ISA, Chip, Board, Project', 'Bốn cấp tổ chức; Project tham chiếu Board và ràng buộc'],
  ['Peripheral, Register, Field, Pin, Net, Part', 'Từ hộ chiếu; Register có base+offset, Field có bit range và enum'],
  ['Fact, Source', 'Mỗi giá trị là Fact trỏ tới Source (tệp, hash, locator, tier)'],
  ['CodeUnit (tệp/hàm), Feature', 'Từ dự án; Feature có trạng thái failing/passing (harness dài hạn [15])'],
  ['Measurement, DebugSession, Error', 'Số đo vật lý, phiên gỡ lỗi, lỗi trong sổ lỗi'],
  ['Skill, Benchmark, Badge', 'Tri thức thủ tục và bằng chứng chất lượng của gói'],
]));
c.push(SP());
c.push(T([2600, 6700], ['Loại cạnh', 'Ý nghĩa'], [
  ['HAS / PART_OF', 'Cấu trúc: Chip HAS Peripheral HAS Register HAS Field; Board HAS Net CONNECTS Pin'],
  ['USES', 'CodeUnit USES Register/Field/Pin — sinh tự động khi tác tử ghi mã (từ citations) và bằng phân tích tĩnh'],
  ['CITES', 'Fact CITES Source; CodeUnit CITES Fact'],
  ['SUPERSEDES', 'Fact mới thay Fact cũ; Source phiên bản mới thay cũ'],
  ['CONFLICTS_WITH', 'Hai Fact cùng subject/predicate khác giá trị; hai chức năng cùng Pin'],
  ['EVIDENCED_BY', 'Feature/Fact EVIDENCED_BY Measurement/DebugSession/Badge'],
]));
c.push(SP());
c.push(H2('6.2. Truy vấn cốt lõi mà tìm kiếm văn bản không làm được'));
c.push(T([2800, 6500], ['Truy vấn', 'Cách trả lời trên đồ thị'], [
  ['Xung đột tài nguyên trước khi sinh mã', 'Với module sắp viết: tập Pin/Peripheral dự kiến USES ∩ tập đã USES bởi CodeUnit khác → cảnh báo; chức năng thay thế (AF) cùng Pin → đề xuất'],
  ['Phân tích ảnh hưởng khi thay tri thức', 'Fact mới SUPERSEDES Fact cũ → mọi CodeUnit CITES Fact cũ → đánh dấu stale, đưa vào backlog kiểm lại'],
  ['Mã nào đã được chứng minh trên board', 'CodeUnit ← Feature EVIDENCED_BY Measurement/Badge có ngày và người xác nhận'],
  ['Graph-RAG chọn ngữ cảnh', 'Từ module đích lan tỏa 2 bước qua HAS/USES để lấy Register/Field/Pin liên quan rồi mới lấy đoạn văn bản; giảm token so với BM25 thuần (tiếp nối ADR-08 của EAA)'],
  ['Truy nguyên lỗi hiện trường', 'Error → DebugSession → Register được đọc → CodeUnit USES Register → Fact CITES Source'],
]));
c.push(SP());
c.push(H2('6.3. Lưu trữ'));
c.push(P('Giai đoạn đầu: SQLite làm kho bản ghi (Fact, Source, hộ chiếu) và NetworkX nạp đồ thị vào bộ nhớ khi mở dự án — đủ cho vài trăm nghìn nút và giữ được tính "tệp phẳng, không máy chủ" của local-first; tiếp nối lựa chọn của EAA (không vector DB, BM25 + đồ thị) [8]. Khi cần: chuyển sang Kùzu hoặc DuckDB với phần mở rộng đồ thị, vẫn nhúng trong tiến trình; vector index (sqlite-vss) chỉ thêm cho tìm kiếm ngữ nghĩa trên văn bản mô tả, không dùng cho hằng số. Mọi thứ nằm trong một thư mục `.hkw/` của dự án, có thể commit vào Git (trừ cache tài liệu lớn).'));

// 7 agents
c.push(H1('7. Tầng tác tử'));
c.push(H2('7.1. Vai trò'));
c.push(T([1700, 3500, 2300, 1800], ['Vai trò', 'Nhiệm vụ', 'Tool được cấp', 'Cổng người'], [
  ['Librarian', 'Điều phối nhận tri thức: phân loại tệp, chọn extractor, hợp nhất, đề xuất nhóm review; trả lời câu hỏi tra cứu có trích dẫn', 'acquire.*, extract.*, passport.query, kg.query', 'Bước 3, 6'],
  ['Cartographer', 'Từ netlist/ảnh schematic dựng BoardPassport; kiểm xung đột chân; đề xuất cấu hình AF/clock', 'kicad.netlist, vision.read, kg.conflicts', 'Duyệt BoardPassport'],
  ['Coder', 'Sinh/sửa mã theo STEP, skill ISA/chip, ràng buộc; mọi hằng số phải có fact id', 'repo.*, passport.query, build/size/static/test', 'G3 (merge)'],
  ['Debugger', 'Từ log (qua GEditor), RTT, probe: giả thuyết xếp hạng, thí nghiệm phân biệt, gói chứng cứ', 'log.stats, serial.*, probe.*, measure.*', 'Trước khi chạy thí nghiệm trên board'],
  ['Reviewer', 'Chấm CodePatch theo checklist ISA/chip; khác hãng với Coder', 'repo.read, passport.query', '—'],
  ['Tester', 'Sinh kịch bản SIL/HIL, chạy benchmark hộ chiếu/Pack, cấp huy hiệu', 'sim.run, flash, serial.expect', 'G4 xác nhận vật lý'],
]));
c.push(SP());
c.push(H2('7.2. LLM Gateway và rào chắn'));
c.push(P('Tái sử dụng nguyên thiết kế trong Phân tích thiết kế Agent EAA-U v0.1 [9]: một hợp đồng ModelPort, adapter Claude/Gemini/OpenAI-compatible, schema mẫu số chung, hai lớp kiểm đầu ra, router theo vai trò, reviewer khác hãng, ledger. EIDE bổ sung hai hook đặc thù: (a) *constant-guard* — trước khi ghi mã, quét mọi hằng số dạng địa chỉ/bit và đối chiếu hộ chiếu; không khớp → chặn và tạo yêu cầu nhận tri thức; (b) *egress-guard* — bản đầu kiểm cờ "nhạy cảm" của dự án và chặn rò rỉ khóa; chế độ cục bộ đầy đủ (chặn mọi lượt gọi mô hình đám mây và mọi tải lên tài liệu) là tùy chọn ở M5.'));
c.push(H2('7.3. MCP: EIDE vừa là server vừa là client'));
c.push(T([2400, 6900], ['Hướng', 'Tool'], [
  ['EIDE là MCP server (cho Claude Code, Cursor, VS Code)', 'passport.query(part, peripheral?, field?) → facts+citations; passport.list; kg.conflicts(project); kg.impact(fact_id); acquire.request(description) → ứng viên; build/flash/serial/probe (có quyền); feature.status; export.report'],
  ['EIDE là MCP client (dùng của hãng và cộng đồng)', 'ESP-IDF Tools MCP [2], Espressif Docs MCP, Nordic MCP [3], embedded-debugger-mcp [10]; kết quả docs MCP được nạp thành Source tầng bạc với URL và ngày'],
]));
c.push(SP());

// 8 tool & target
c.push(H1('8. Tầng tập lệnh, toolchain và thiết bị'));
c.push(T([1900, 2400, 2400, 2600], ['ISA profile', 'Toolchain (mở là mặc định)', 'Nạp / gỡ lỗi', 'Mô phỏng'], [
  ['armv6/7/8-m', 'arm-none-eabi-gcc, CMake; Zephyr/west; STM32Cube', 'probe-rs, OpenOCD, pyOCD; ST-Link/J-Link/CMSIS-DAP', 'Renode [16], QEMU (một số board)'],
  ['rv32*', 'riscv-none-elf-gcc; ESP-IDF cho ESP32-C/H', 'OpenOCD, probe-rs; USB-JTAG tích hợp ESP32-C3', 'Renode, QEMU, Spike'],
  ['avr8', 'avr-gcc, avr-libc', 'avrdude, pymcuprog (UPDI)', 'simavr [17]'],
  ['pic16/18, pic24/dspic, mips32 (PIC32MX)', 'XC8/XC16/XC32 dòng lệnh (đóng, bản miễn phí)', 'IPECMD [18], pymcuprog một phần', 'MPLAB X sim (khó tự động) — bỏ qua giai đoạn đầu'],
  ['xtensa-lx6/lx7', 'ESP-IDF', 'OpenOCD (esp-usb-jtag)', 'QEMU-xtensa của Espressif'],
  ['custom', 'Khai báo trong toolchain manifest của hộ chiếu', 'Adapter do người dùng viết theo giao diện Flash/Probe', 'Renode với .repl tùy chỉnh'],
]));
c.push(SP());
c.push(P('Toolchain manifest theo mẫu `tools.yaml` của EAA (tên, phiên bản tối thiểu, lệnh kiểm, cách cài theo hệ điều hành, hash) và lệnh `hkw doctor` ba chế độ (kiểm, cài có hỏi, khóa phiên bản). Thiết bị đo: sigrok-cli cho logic analyzer [19], INA2xx/PPK2 cho năng lượng; mọi số đo là Measurement trong đồ thị.'));

// 9 GEditor
c.push(H1('9. GEditor như bề mặt quan sát phần cứng'));
c.push(T([2600, 6700], ['Tính năng', 'Mô tả và vì sao GEditor phù hợp'], [
  ['Log/trace gigabyte có cấu trúc', 'Mở log serial, RTT, ITM nhiều GB; tự nhận dấu thời gian và mức log; thống kê mẫu (tần suất dòng, khoảng cách thời gian, dòng lặp) tính trên toàn tệp mà không nạp LLM'],
  ['"Hỏi tác tử tại dòng này"', 'Chọn vùng → gửi vùng + thống kê + hộ chiếu + mã liên quan (qua đồ thị) tới Debugger; trả lời neo vào dòng, có thể lưu thành DebugSession'],
  ['Hex/bin và .map', 'Xem firmware, ánh xạ địa chỉ → thanh ghi theo hộ chiếu (hover 0x40005400 hiện I2C1); phân tích .map cho tràn bộ nhớ'],
  ['Waveform', 'Hiển thị bản ghi sigrok đã decode (I2C/SPI/UART) đồng bộ với log theo thời gian; chọn giao dịch → hỏi tác tử'],
  ['Trình duyệt hộ chiếu và đồ thị', 'Xem/duyệt fact theo nhóm, mức tin cậy, nguồn (nhảy tới trang PDF, bbox); đồ thị lân cận của một Pin/Register'],
  ['Hàng đợi xác nhận', 'Một nơi cho mọi cổng người: nguồn cần duyệt, fact cần duyệt, thao tác nguy hiểm cần cấp quyền, diff chờ G3'],
  ['Serial console', 'Đa cổng, ghi JSONL, expect/pattern để kiểm thử, gửi lệnh'],
]));
c.push(SP());
c.push(P('Về mặt kỹ thuật, GEditor (macOS) giao tiếp với Knowledge Plane qua socket cục bộ; toàn bộ tính năng trên là plugin của GEditor theo cơ chế plugin hiện có (7 nhóm, 154 FR ở v2.2), nên không cần viết lại lõi. Nền tảng khác (Linux/Windows) dùng CLI và IDE qua MCP trước; giao diện đa nền tảng là quyết định sau khi có người dùng.'));

// 10 registry
c.push(H1('10. Registry: tri thức phần cứng như package'));
c.push(H2('10.1. Gói .hkp'));
c.push(...CODE([
  'st.stm32f411ce-1.2.0.hkp  (zip)',
  '  manifest.json      # id, version, kind (chip|board|isa|skill|bench), deps, license, authors, signatures',
  '  passport.yaml      # hộ chiếu (fact + provenance, không kèm PDF)',
  '  skills/*.md        # skill do chuyên gia viết cho chip/ISA này',
  '  bench/*.yaml       # bộ tác vụ chuẩn CF/BF/BC + kịch bản kiểm định ID',
  '  badges.json        # verified_on_board {board, date, by, log_hash}, bench results theo mô hình LLM',
  '  SIGNATURE          # chữ ký (sigstore/minisign) của người phát hành',
]));
c.push(SP());
c.push(H2('10.2. Cơ chế tin cậy'));
c.push(P('Mỗi gói mang (a) chữ ký người phát hành, (b) huy hiệu "đã xác minh trên board" với hash của log kiểm định, (c) kết quả benchmark theo mô hình LLM (để biết gói này giúp Claude đạt 41/42 nhưng mô hình cục bộ chỉ 30/42), và (d) số lượt được dùng thành công do client tự nguyện báo. Registry hiển thị ba mức: chính hãng (vendor ký), cộng đồng đã kiểm định, cộng đồng chưa kiểm định. Mô hình này lấy cảm hứng từ cách package registry và Sigstore xây dựng lòng tin cho phần mềm [20], áp dụng cho tri thức.'));
c.push(H2('10.3. Chiến lược gieo hạt'));
c.push(P('Ba nguồn hạt giống: (1) nhập tự động toàn bộ SVD trong CMSIS pack và ATDF trong Microchip pack thành hộ chiếu tầng vàng "chưa kiểm định" — hàng nghìn chip ngay ngày đầu; (2) học viên chương trình AI-Native làm bài tập "viết và kiểm định hộ chiếu cho board X" — mỗi khóa thêm vài chục board đã chạy thật; (3) dự án tư vấn đóng góp hộ chiếu (không kèm IP) khi khách hàng đồng ý. Registry chạy như kho Git + index tĩnh lúc đầu, không cần máy chủ phức tạp.'));

// 11 tech stack
c.push(H1('11. Công nghệ, cấu trúc kho mã và giao diện nội bộ'));
c.push(T([2300, 3400, 3600], ['Khối', 'Công nghệ đề xuất', 'Lý do'], [
  ['Knowledge Plane', 'Python 3.11+, FastAPI (HTTP nội bộ) + MCP SDK; SQLite + NetworkX; pydantic cho schema hộ chiếu', 'Tái dùng Engine EAA; tốc độ phát triển; điểm nóng có thể chuyển sang Rust sau'],
  ['Extractors', 'Docling, pdfplumber, cmsis-svd, lxml (ATDF/EDC), kicad-cli, pandoc, openpyxl; mô hình thị giác qua Gateway', 'Tất cả mã nguồn mở, chạy cục bộ'],
  ['Agent Runtime', 'LLM Gateway của EAA-U (anthropic, google-genai, openai SDK); jsonschema', 'Đã thiết kế, cần hiện thực'],
  ['Tool Layer', 'subprocess adapter; probe-rs/OpenOCD qua embedded-debugger-mcp; pyserial; sigrok-cli; Renode', 'Chuẩn ngành, mở'],
  ['GEditor plugin', 'Swift, cơ chế plugin GEditor; giao tiếp socket JSON-RPC với daemon', 'Tận dụng lõi tệp lớn'],
  ['Registry', 'Kho Git + index JSON tĩnh + CDN; ký bằng minisign/sigstore', 'Chi phí gần 0, minh bạch'],
]));
c.push(SP());
c.push(...CODE([
  'hkw/',
  '  plane/        # daemon: api/, mcp_server/, gates/, ledger/',
  '  passport/     # schema/, store/, kg/ (queries), merge/',
  '  acquire/      # search/, extractors/{svd,atdf,edc,pdf,kicad,zip,office,html,image}/, review/',
  '  agents/       # gateway/ (ModelPort, adapters), roles/, composer/, hooks/',
  '  targets/      # isa_profiles/, toolchains/, adapters/{build,flash,probe,serial,sim,measure}/',
  '  registry/     # client, pack/unpack, sign/verify',
  '  cli/          # hkw ingest|query|build|flash|debug|bench|publish|doctor',
  '  geditor-plugin/  (repo riêng, Swift)',
  '  packs/        # ISA profiles + skill khởi đầu: armv7e-m, rv32imac, avr8, pic16, custom',
]));
c.push(SP());

// 12 roadmap
c.push(H1('12. Lộ trình hiện thực hóa và chỉ số'));
c.push(T([1500, 4300, 3500], ['Giai đoạn', 'Phạm vi', 'Chỉ số hoàn thành'], [
  ['M0 (2 tuần) Khung', 'Schema hộ chiếu + provenance; parser SVD/ATDF → ChipPassport; SQLite+KG; CLI hkw query; Gateway 2 adapter', '≥ 500 chip nhập tự động; 100 truy vấn thanh ghi đúng 100%'],
  ['M1 (5 tuần) Nhận tri thức + tầng hiểu lệnh', 'Acquisition với PDF (Docling), zip/rar lồng nhau, ảnh OCR, BOM; PolicyGate/Undo; Capability Registry + Orchestrator (chat.*); req.*; diagram.render/lint/kg_view; view.kg_map/rag_ask; doc.style_check; env tự cài; kiểm định ID trên STM32 + AVR; constant-guard — 47+ năng lực mốc M1', 'Kịch bản A và Z-01…Z-10 hoàn thành từ lệnh ngôn ngữ tự nhiên trên 3 board; ≤ 5 lần bấm'],
  ['M2 (5 tuần) Mạch, kiến trúc, mã, dò board', 'kicad-cli → BoardPassport; arch.* + diagram.* (kiến trúc, tuần tự, trạng thái, chân, bộ nhớ); plan/code/merge tự động vào auto/; discover.* (cổng, probe, ID chip, tốc độ, auto_setup); MCP server cho Claude Code; build/flash/serial; doc.generate — 56+ năng lực mốc M2', 'Kịch bản B đầu-cuối trên Cortex-M và AVR với 2 mô hình; cắm board → target sẵn sàng < 30 s; tài liệu SRS/SAD sinh tự động'],
  ['M3 (4 tuần) Quan sát + mô phỏng + đồng bộ', 'GEditor plugin: log gigabyte + thống kê + "hỏi tại dòng"; serial console; probe qua embedded-debugger-mcp; Debugger; sim.*; discover.bus_scan/clock/power/network; diagram.sync/from_image; doc.sync/translate/slides', 'Kịch bản C với log ≥ 1 GB; HardFault cố ý được chẩn đoán đúng; lược đồ ↔ mã đồng bộ'],
  ['M4 (3 tuần) Registry', 'Định dạng .hkp, ký, huy hiệu; publish/pull; gieo hạt SVD/ATDF; bài tập học viên', '≥ 20 gói cộng đồng đã kiểm định; 1 khóa học dùng thử'],
  ['M5 (mở) Mở rộng', 'RISC-V, PIC, custom; waveform sigrok; đo năng lượng; Windows/Linux UI', 'Theo nhu cầu người dùng trả tiền'],
]));
c.push(SP());
c.push(P('Chỉ số sản phẩm theo dõi liên tục: tỷ lệ hằng số có nguồn trong mã sinh ra (mục tiêu 100%), tỷ lệ BC trên benchmark theo mô hình, thời gian từ "board mới" đến "hộ chiếu đã kiểm định", số gói registry và số lượt dùng, và chi phí token trên một module.'));

// 13 risks
c.push(H1('13. Rủi ro và quyết định còn mở'));
c.push(T([2800, 3000, 3500], ['Rủi ro / câu hỏi', 'Tác động', 'Hướng xử lý'], [
  ['Trích xuất PDF sai làm hỏng board', 'Mất lòng tin ngay lần đầu', 'P1–P3; kiểm định ID và chức năng cơ bản trước khi cho tác tử dùng fact tầng bạc để ghi thanh ghi'],
  ['License tài liệu hãng khi chia sẻ gói', 'Rủi ro pháp lý cho registry', 'Không phân phối lại PDF; fact + con trỏ; luật sư xem trước khi công khai'],
  ['Phạm vi quá rộng (mọi ISA, mọi tệp, mọi IDE)', 'Không ra được sản phẩm', 'M0–M3 chỉ Cortex-M + AVR, PDF + zip + SVD/ATDF, Claude Code + GEditor; phần còn lại là giao diện'],
  ['Ai trả tiền đầu tiên', 'Không có doanh thu để duy trì', 'Giả thuyết: startup phần cứng cần cục bộ + hộ chiếu riêng (bản Team); cá nhân/học viên miễn phí; kiểm chứng ở M2 bằng 5 phỏng vấn'],
  ['GEditor chỉ có macOS', 'Bỏ lỡ kỹ sư Windows/Linux', 'Knowledge Plane và MCP đa nền tảng từ đầu; UI macOS là lợi thế sớm, không phải giới hạn dài hạn'],
  ['Toolchain đóng (XC8, IAR, Keil)', 'Không tự động hóa được', 'Chỉ dòng lệnh miễn phí; PIC ở M5; ghi rõ trong hộ chiếu toolchain_hint'],
  ['Trùng lặp với EAA-U', 'Hai sản phẩm cùng lõi, phân tán nguồn lực', 'EAA-U là Engine + phương pháp (đề án); EIDE là sản phẩm thương mại dùng Engine đó làm thư viện; một kho mã lõi, hai bao bì'],
]));
c.push(SP());
c.push(P('Ba quyết định anh cần chốt trước M0: (1) tên sản phẩm và việc có công khai registry ngay hay chạy nội bộ cho khóa học trước; (2) Knowledge Plane viết bằng Python (nhanh, tái dùng EAA) hay Rust (hiệu năng, phân phối một tệp) — đề xuất Python cho M0–M3; (3) mức độ tách kho mã giữa EAA-U và EIDE — đề xuất một kho `core` dùng chung cho Engine, Gateway, Passport, Targets, và hai kho sản phẩm.'));

// 14 capability catalog
c.push(H1('14. Danh mục năng lực (tóm tắt v1.1)'));
c.push(P(`Danh mục năng lực [21] là xương sống nối yêu cầu (URD/SRS), thiết kế (SAD/SDD), kiểm thử (STP) và giao diện: ${CAPS.length} năng lực trong ${NS_ORDER.length} nhóm, mỗi năng lực có 13 trường hợp đồng. Phân bố theo mức tự chủ: T1 ${count(x => x.tier === 'T1')} (${Math.round(100 * count(x => x.tier === 'T1') / CAPS.length)}%), T1* ${count(x => x.tier === 'T1*')}, T2 ${count(x => x.tier === 'T2')}, T3 ${count(x => x.tier === 'T3')}; theo lớp rủi ro: R0 ${count(x => x.risk.startsWith('R0'))}, R1 ${count(x => x.risk.startsWith('R1'))}, R2 ${count(x => x.risk.startsWith('R2'))}, R3 ${count(x => x.risk.startsWith('R3'))}, R4 ${count(x => x.risk.startsWith('R4'))}; đã có trong mã M0: ${count(x => x.m0.includes('có'))}. Sáu nhóm bổ sung ở v1.1 (req, arch, diagram, doc, view, discover) và nhóm gốc tool (v1.2: tác tử tự viết công cụ Python và chạy) đưa EIDE từ "bàn tri thức phần cứng" thành môi trường phủ trọn vòng đời kỹ nghệ nhúng: yêu cầu → kiến trúc → lược đồ → mã → mô phỏng/board → tài liệu.`));
c.push(...IMG('hinh/eide_caps_dist.png', 600, 229, 'Hình 9. Phân bố 238 năng lực theo 27 nhóm'));
c.push(T([1500, 3300, 800, 3700], ['Nhóm', 'Tên nhóm', 'Số', 'Năng lực tiêu biểu'], NS_ORDER.map(ns => { const r = byNs(ns); return [ns, NS_VI[ns], String(r.length), r.slice(0, 4).map(x => x.name).join(', ') + (r.length > 4 ? ', …' : '')]; })));
c.push(SP());
c.push(P('Bảng đầy đủ nằm trong EIDE-SRS-02 §3B (mỗi năng lực là một FR) và trong tệp Excel; SDD-04 §4.0 định nghĩa schema hợp đồng và Capability Registry; STP-05 có test case theo nhóm; BPD-06 có quy trình P0 "tiếp nhận lệnh" và P7 "yêu cầu → kiến trúc → tài liệu".'));
// refs
c.push(H1('Tài liệu tham khảo'));
const refs = [
  'Embedder, "Embedder | Enterprise AI Platform for Embedded Software," 2026. [Online]. Available: https://embedder.com/',
  'Espressif Systems, "ESP-IDF Tools Local MCP Server," Developer Portal, Apr. 2026. [Online]. Available: https://developer.espressif.com/blog/2026/04/esp-idf-tools-mcp-server/',
  'Nordic Semiconductor, "AI-assisted development the Nordic way," Nordic DevZone Blog, Jun. 2026. [Online]. Available: https://devzone.nordicsemi.com/nordic/nordic-blog/b/blog/posts/bringing-ai-assisted-development-to-nrf-connect-sdk-and-nrf-cloud',
  'Arm, "CMSIS-SVD: System View Description," Open-CMSIS-Pack. [Online]. Available: https://open-cmsis-pack.github.io/svd-spec/',
  'Microchip Technology, "Microchip Packs Repository (Device Family Packs, ATDF)." [Online]. Available: https://packs.download.microchip.com/',
  'Microchip Technology, "MPLAB X IDE — Device Support (EDC / .PIC files)." [Online]. Available: https://www.microchip.com/en-us/tools-resources/develop/mplab-x-ide',
  'Zephyr Project, "Devicetree bindings," Zephyr Documentation. [Online]. Available: https://docs.zephyrproject.org/latest/build/dts/bindings.html',
  'V. T. Công, "Embedded AIDD Agent (EAA)," GitHub mobiluckvn/Agent, 2026. [Online]. Available: https://github.com/mobiluckvn/Agent',
  'V. T. Công, "Phân tích thiết kế Agent — Kiến trúc agent đa mô hình cho lập trình nhúng (EAA-U) v0.1," 05/09/2026.',
  'Adancurusul, "embedded-debugger-mcp," GitHub, 2026. [Online]. Available: https://github.com/adancurusul/embedded-debugger-mcp',
  'RISC-V International, "Sail RISC-V model (formal ISA specification)," GitHub. [Online]. Available: https://github.com/riscv/sail-riscv',
  'LLVM Project, "TableGen Overview," LLVM Documentation. [Online]. Available: https://llvm.org/docs/TableGen/',
  'IBM, "Docling — document conversion toolkit," GitHub. [Online]. Available: https://github.com/docling-project/docling',
  'KiCad, "kicad-cli — command line interface," KiCad 8 Documentation. [Online]. Available: https://docs.kicad.org/8.0/en/cli/cli.html',
  'Anthropic, "Effective harnesses for long-running agents," Anthropic Engineering. [Online]. Available: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents',
  'Antmicro, "Renode — open source simulation framework." [Online]. Available: https://renode.io/',
  'buserror, "simavr," GitHub. [Online]. Available: https://github.com/buserror/simavr',
  'Microchip Technology, "IPECMD — Automate MPLAB programming process using command line." [Online]. Available: https://support.microchip.com/s/article/Automate-MPLAB-programming-process-using-command-lineIPECMD',
  'sigrok, "sigrok-cli and libsigrokdecode." [Online]. Available: https://sigrok.org/',
  'Sigstore, "Sigstore — signing, verification and provenance for software artifacts." [Online]. Available: https://www.sigstore.dev/',
  'V. T. Công, "EIDE — Danh mục năng lực đầy đủ v1.1 (EIDE_Danh_muc_Nang_luc.xlsx): 238 năng lực, 27 nhóm," 05/09/2026.',
  'V. T. Công, "EIDE-APD-08 — Chính sách tự chủ của tác tử và cổng người thích ứng v1.1," 05/09/2026.',
  'V. T. Công, "EIDE-DPS-09 — Chính sách hội thoại và suy luận ý định v1.0," 05/09/2026.',
  'V. T. Công, "EIDE — Use case chi tiết (EIDE_Use_Case_Chi_Tiet.xlsx)," 05/09/2026.',
];
refs.forEach((r, i) => c.push(new Paragraph({ children: [new TextRun({ text: `[${i + 1}] ${r}`, font: 'Times New Roman', size: 24 })], alignment: AlignmentType.LEFT, spacing: { line: 276, after: 100 }, indent: { left: 567, hanging: 567 } })));

build(meta, c, 'EIDE-PDA-00_Phan_tich_thiet_ke_san_pham.docx');
