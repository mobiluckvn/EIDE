const { P, H1, H2, H3, CAP, SP, T, IMG, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-URD-01', 'Yêu cầu người dùng', 'TÀI LIỆU YÊU CẦU NGƯỜI DÙNG (URD)',
  'Yêu cầu từ góc nhìn các bên liên quan của EIDE (Embedded IDE) · theo ISO/IEC/IEEE 29148',
  [['Tài liệu kế tiếp', 'EIDE-SRS-02 — mọi UR phải truy vết tới ít nhất một FR (từ v1.1: FR = năng lực trong Danh mục)']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (EIDE-URD-01): 10 nhóm UR, 9 UQ, 7 CR']],
  'Thêm nhóm UR mới: NL (lệnh ngôn ngữ tự nhiên và tự chủ), KN (kỹ nghệ: yêu cầu, kiến trúc, lược đồ, tài liệu), TQ (bản đồ tri thức và RAG), DT (dò board và kết nối); sửa UR-TT-04, UR-QT-01, UR-MH-02; thêm CR-08…CR-10; ma trận truy vết theo nhóm năng lực');
const c = [];
c.push(H1('1. Giới thiệu'));
c.push(P('Tài liệu này ghi nhận nhu cầu của các bên liên quan đối với EIDE (Embedded IDE, trước đây Hardware Knowledge Workbench — HKW) ở mức "cần gì, vì sao" theo lớp yêu cầu bên liên quan của ISO/IEC/IEEE 29148 [4]. Nội dung kế thừa EIDE-PDA-00 [1] (định vị, bảy nguyên tắc P1–P7, ba kịch bản A/B/C) và ba quyết định đã chốt: Knowledge Plane viết bằng Python; một kho mã `core` dùng chung với EAA-U; registry chạy nội bộ cho khóa học AI-Native trước khi công khai. Mã yêu cầu: **UR-<nhóm>-<số>** với nhóm TT (tri thức), MC (mạch), MA (mã), XM (xác minh), GL (gỡ lỗi), QS (quan sát trong GEditor), MH (mô hình ngôn ngữ), RG (registry), QT (quản trị, an toàn), HT (học tập), và từ v1.1: NL (lệnh ngôn ngữ tự nhiên, tự chủ), KN (kỹ nghệ: yêu cầu, kiến trúc, lược đồ, tài liệu), TQ (bản đồ tri thức, RAG), DT (dò board, kết nối). Yêu cầu chất lượng **UQ-n**, ràng buộc **CR-n**. Ưu tiên M/S/C; giai đoạn M0–M5 theo lộ trình của PDA-00.'));
c.push(H2('1.0. Bối cảnh v1.1: ba thay đổi định hướng'));
c.push(P('Phiên bản 1.1 phản ánh ba quyết định của chủ sản phẩm sau khi rà soát bộ use case [28] và danh mục năng lực [25]: (1) **giao diện chính là lệnh bằng ngôn ngữ tự nhiên** — kỹ sư mô tả điều muốn làm, tác tử hiểu, đối chiếu trạng thái và tự gọi các năng lực; các màn hình khác là nơi xem kết quả và can thiệp, không phải nơi bắt buộc thao tác; (2) **mọi chức năng phần mềm là một năng lực có hợp đồng** (238 năng lực, 27 nhóm) mà cả người (qua giao diện) lẫn tác tử (qua chuỗi điều phối) đều gọi được với cùng chính sách và nhật ký; (3) **tự động hóa tối đa theo EIDE-APD-08** [26]: bản đầu chạy trên một PC có Internet đầy đủ, mức tự chủ A3 mặc định, tác tử "làm rồi báo cáo" với cửa sổ hoàn tác, chỉ hỏi ở hành động không hoàn tác được hoặc rủi ro vật lý. Chế độ cục bộ/không mạng không còn là mặc định và chuyển thành hướng phát triển sau (UR-MH-02).'));
c.push(H2('1.1. Thuật ngữ'));
c.push(T([2300, 7000], ['Thuật ngữ', 'Giải nghĩa'], [
  ['Hộ chiếu (Passport)', 'Tập fact có nguồn về một chip (ChipPassport), một mạch (BoardPassport) hoặc một tập lệnh (ISA profile); định dạng YAML có schema'],
  ['Fact', 'Bản ghi bất biến {subject, predicate, value, source, tier, confidence, confirmed_by, supersedes}'],
  ['Tầng vàng / bạc / đồng', 'Mức tin cậy theo nguồn: tệp có cấu trúc của hãng / PDF và ảnh đã người xác nhận / web và suy luận'],
  ['Knowledge Plane', 'Tiến trình cục bộ giữ hộ chiếu, đồ thị tri thức, cổng người, nhật ký; phơi ra qua MCP và socket'],
  ['Cổng người (Gate)', 'Điểm dừng bắt buộc: G-SRC nguồn, G-FACT fact, G1 kế hoạch, G3 merge, G4 xác nhận vật lý, G5 bàn giao, G-OPS thao tác nguy hiểm'],
  ['.hkp', 'Gói registry: hộ chiếu + skill + benchmark + huy hiệu + chữ ký; không chứa PDF của hãng'],
  ['Constant-guard', 'Hook chặn mã có hằng số địa chỉ/bit không khớp hộ chiếu'],
  ['Năng lực (Capability)', 'Đơn vị chức năng có hợp đồng {mã nhóm.tên, tham số vào, kết quả ra, lớp rủi ro R0–R4, mức tự chủ T1/T1*/T2/T3, grounding, điều kiện hỏi kỹ sư, hoàn tác}; người gọi qua giao diện, tác tử gọi trong chuỗi [25]'],
  ['Tác tử điều phối (Orchestrator)', 'Tầng hiểu lệnh: hiểu ý định → đối chiếu trạng thái → lập chuỗi năng lực → điền mặc định/hỏi gộp → áp chính sách → báo cáo (EIDE-DPS-09 [27])'],
  ['Mức tự chủ A0–A4; lớp rủi ro R0–R4; mức T1/T1*/T2/T3', 'Theo EIDE-APD-08 [26]: A3 mặc định; R4 luôn hỏi; T1 AI làm trọn, T1* tự làm khi chính sách có bằng chứng, T2 AI làm — người duyệt, T3 người làm'],
  ['Lược đồ (diagram)', 'Sơ đồ ở dạng ngôn ngữ văn bản mà GEditor hỗ trợ hiển thị: Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG [31]–[35]'],
]));
c.push(SP());
c.push(H1('2. Bên liên quan'));
c.push(T([2300, 6900], ['Bên liên quan', 'Nhu cầu cốt lõi'], [
  ['Kỹ sư nhúng (startup / cá nhân)', 'Ra lệnh bằng tiếng Việt/Anh và để tác tử làm gần hết; không bịa thanh ghi; làm việc trong repo và IDE sẵn có; chỉ bị hỏi ở việc không hoàn tác được; số lần bấm trong kịch bản chuẩn ≤ 5'],
  ['Kỹ sư chip lạ / chip tùy chỉnh', 'Khai báo hộ chiếu từ SVD/CSV nội bộ; sinh driver từ hộ chiếu; mô phỏng theo mô tả nền tảng'],
  ['Kỹ sư gỡ lỗi hiện trường', 'Mở log/trace nhiều GB; hỏi tác tử ngay tại dòng; chứng cứ từ probe'],
  ['Pack owner / chuyên gia họ chip', 'Định dạng gói rõ; công cụ kiểm định trên board; ghi nhận tác giả'],
  ['Giảng viên, học viên AI-Native', 'Cài nhanh; tiếng Việt; bài tập "viết hộ chiếu" sinh tri thức dùng chung'],
  ['Chủ sản phẩm (CongVT)', 'Một kho core cho EAA-U và EIDE; số liệu vận hành; con đường thương mại hóa (bản Team local-first)'],
  ['Nhà cung cấp LLM, nhà cung cấp tri thức, cộng đồng registry', 'Hệ thống ngoài; EIDE phải chịu được thay đổi API và license'],
]));
c.push(SP());
c.push(H1('3. Yêu cầu người dùng'));
const W = [1100, 3900, 2250, 550, 650, 850];
const H = ['Mã', 'Yêu cầu', 'Tiêu chí chấp nhận', 'Ưu', 'GĐ', 'Nguồn'];
c.push(H2('3.1. TT — Nhận và quản trị tri thức chip'));
c.push(T(W, H, [
  ['UR-TT-01', 'Là kỹ sư, tôi cần kéo thả bất kỳ tệp/thư mục nào (PDF, DOCX, XLSX, HTML, ảnh, .zip/.7z/.tar, SVD/ATDF/EDC/header, KiCad) và hệ thống tự phân loại, mở nén đệ quy, chọn cách trích xuất phù hợp.', 'Thư mục hỗn hợp 10 tệp → bảng phân loại đúng loại và tầng cho ≥ 95% tệp', 'M', 'M1', '[1] §5'],
  ['UR-TT-02', 'Là kỹ sư, tôi cần bản đồ thanh ghi được nhập từ tệp có cấu trúc của hãng khi có (SVD/ATDF/EDC/binding) và chỉ dùng PDF khi không có.', '≥ 500 chip nhập tự động từ SVD/ATDF ở M0; fact từ nguồn vàng không cần duyệt từng dòng', 'M', 'M0', '[1] P1, [8]–[10]'],
  ['UR-TT-03', 'Là kỹ sư, tôi cần mọi fact đều có nguồn (tệp, hash, trang/bbox), mức tin cậy và người xác nhận; sửa fact tạo phiên bản mới, không ghi đè.', 'Mọi fact hiển thị được provenance; lịch sử supersedes xem được', 'M', 'M0', '[1] P2'],
  ['UR-TT-04', 'Là kỹ sư, khi tri thức thiếu, tôi cần hệ thống tự tìm ứng viên trên nhiều nguồn (registry → hãng → docs MCP → web), tự chọn và tải khi nguồn thuộc danh sách tin cậy và license rõ, chỉ hỏi tôi khi nguồn ngoài danh sách, license không rõ hoặc tệp lớn (APD §4 G-SRC).', 'Nguồn hãng có hash/license: tự tải, ghi lý do; nguồn lạ: hỏi một câu gộp; mọi quyết định ghi nhật ký', 'M', 'M1', '[1] §5.1, [26] §4'],
  ['UR-TT-05', 'Là kỹ sư, tôi cần fact tầng bạc đạt ngưỡng được tự duyệt theo chính sách ("auto-reviewed by policy") và chỉ những fact tin cậy thấp/mâu thuẫn mới đưa tôi duyệt theo nhóm với ảnh cắt từ PDF bên cạnh.', '≥ 80% fact bạc từ PDF chính hãng tự duyệt; phần còn lại duyệt ≤ 15 phút cho một cảm biến', 'M', 'M1', '[1] §5.1, [26] §4'],
  ['UR-TT-06', 'Là kỹ sư, tôi cần kiểm định hộ chiếu trên board bằng một lệnh (đọc ID chip, GPIO/UART cơ bản) để gắn huy hiệu "đã xác minh".', 'Kiểm định chạy trên STM32 và AVR; huy hiệu kèm hash log', 'M', 'M1', '[1] §5.1'],
  ['UR-TT-07', 'Là kỹ sư, tôi cần hỏi bằng ngôn ngữ tự nhiên về thanh ghi/chân/timing và nhận câu trả lời có trích dẫn và mức tin cậy.', '100/100 câu hỏi mẫu đúng trên chip đã có hộ chiếu', 'M', 'M0', '[1] §2.2'],
  ['UR-TT-08', 'Là kỹ sư, khi tri thức mới thay tri thức cũ, tôi cần biết mã nào bị ảnh hưởng và được đưa vào backlog kiểm lại.', 'Thay 1 fact → danh sách CodeUnit stale đúng 100%', 'M', 'M2', '[1] §6.2'],
]));
c.push(SP());
c.push(H2('3.2. MC — Mạch và ràng buộc vật lý'));
c.push(T(W, H, [
  ['UR-MC-01', 'Là kỹ sư, tôi cần nhập .kicad_sch để hệ thống dựng BoardPassport (chân – net – linh kiện – bus – địa chỉ) mà không khai báo tay.', 'Bảng chân đúng ≥ 95% so với kiểm tay trên 3 board mẫu', 'M', 'M2', '[1] §4.3, [12]'],
  ['UR-MC-02', 'Là kỹ sư có ảnh schematic (không có tệp CAD), tôi cần mô hình thị giác đề xuất bảng kết nối để tôi xác nhận.', 'Bảng đề xuất kèm ảnh cắt; tôi sửa và duyệt', 'S', 'M2', '[1] §5.1'],
  ['UR-MC-03', 'Là kỹ sư, tôi cần cảnh báo xung đột chân/chức năng (một chân hai chức năng, chân reserved, boot pin) trước khi sinh mã.', 'Ca cố ý PB3 = LED + MOSI được phát hiện', 'M', 'M2', '[1] §6.2'],
  ['UR-MC-04', 'Là kỹ sư, tôi cần ràng buộc điện (điện áp, dòng I/O, pull-up) của mạch được dùng khi tác tử cấu hình ngoại vi.', 'Cấu hình I2C tốc độ cao bị cảnh báo khi pull-up không phù hợp theo fact', 'S', 'M2', '[1] §4.3'],
]));
c.push(SP());
c.push(H2('3.3. MA — Sinh mã từ hộ chiếu'));
c.push(T(W, H, [
  ['UR-MA-01', 'Là kỹ sư dùng Claude Code/Cursor, tôi cần IDE của tôi gọi được EIDE để lấy fact có trích dẫn và để EIDE kiểm mã trước khi tôi thấy.', 'Tool MCP passport.query, kg.conflicts, review.patch hoạt động từ Claude Code', 'M', 'M2', '[1] §7.3, [13]'],
  ['UR-MA-02', 'Là kỹ sư, tôi cần mọi hằng số địa chỉ/bit trong mã sinh ra phải khớp hộ chiếu, nếu không thì bị chặn và tạo yêu cầu nhận tri thức.', 'Constant-guard chặn 100% hằng số không nguồn trong bộ thử', 'M', 'M1', '[1] §7.2'],
  ['UR-MA-03', 'Là kỹ sư, tôi cần kế hoạch có trích dẫn trước khi viết mã và duyệt tại G1; mã chỉ merge sau G3 với reviewer khác hãng.', 'Không có mã trước G1; không merge ngoài G3', 'M', 'M2', '[2], [3]'],
  ['UR-MA-04', 'Là kỹ sư, tôi cần mã sinh ra theo đúng hệ sinh thái (bare-metal, HAL, ESP-IDF, Zephyr) và quy ước repo của tôi.', 'Biên dịch không sửa tay trong khung dự án', 'M', 'M2', '[1] §2.2'],
  ['UR-MA-05', 'Là kỹ sư chip tùy chỉnh, tôi cần sinh driver GPIO/UART/SPI chỉ từ hộ chiếu tôi cung cấp (chip không có trong dữ liệu huấn luyện).', 'Driver chạy trên soft-core RISC-V mẫu', 'S', 'M5', '[1] §2'],
]));
c.push(SP());
c.push(H2('3.4. XM — Xác minh khép kín'));
c.push(T(W, H, [
  ['UR-XM-01', 'Là kỹ sư, tôi cần chuỗi build → size → static → host-test chạy tự động, tự sửa ≤ 3 lần, kết quả chuẩn hóa.', '4 ToolReport đính kèm mọi diff tới G3', 'M', 'M2', '[2]'],
  ['UR-XM-02', 'Là kỹ sư, tôi cần nạp board chỉ sau khi tôi cho phép trong phiên, có verify, qua adapter của ISA profile.', 'Nạp bị từ chối khi chưa cấp quyền; verify sau nạp', 'M', 'M2', '[1] P3'],
  ['UR-XM-03', 'Là kỹ sư, tôi cần kiểm thử chạy trên mô phỏng (Renode/simavr) trước rồi board sau, với kịch bản dùng chung.', 'Cùng kịch bản chạy hai nơi, báo cáo chênh lệch', 'S', 'M3', '[20]'],
  ['UR-XM-04', 'Là kỹ sư, tôi cần xác nhận vật lý (G4) là điều kiện để tính năng chuyển passing và mã được gắn "bằng chứng" trong đồ thị.', 'Feature không passing nếu thiếu G4', 'M', 'M2', '[18]'],
]));
c.push(SP());
c.push(H2('3.5. GL — Gỡ lỗi có chứng cứ'));
c.push(T(W, H, [
  ['UR-GL-01', 'Là kỹ sư, tôi cần tác tử kết nối probe (probe-rs/OpenOCD), dừng lõi, đọc bộ nhớ/thanh ghi; ghi và xóa chỉ khi tôi cấp quyền.', 'Trên STM32 Nucleo: halt/read hoạt động; write bị chặn khi chưa cấp quyền', 'M', 'M3', '[14]'],
  ['UR-GL-02', 'Là kỹ sư, khi HardFault, tôi cần gói chứng cứ (thanh ghi lỗi, stack, dòng mã) và giả thuyết xếp hạng kèm thí nghiệm phân biệt.', 'Lỗi cố ý được chỉ đúng hàm ≥ 80% ca', 'S', 'M3', '[14]'],
  ['UR-GL-03', 'Là kỹ sư, tôi cần mỗi phiên gỡ lỗi được lưu thành DebugSession gắn với fact và mã liên quan để tra lại.', 'DebugSession xuất hiện trong đồ thị và sổ lỗi', 'M', 'M3', '[1] §6.1'],
]));
c.push(SP());
c.push(H2('3.6. QS — Quan sát trong GEditor'));
c.push(T(W, H, [
  ['UR-QS-01', 'Là kỹ sư, tôi cần mở log serial/RTT ≥ 1 GB, tự nhận dấu thời gian và mức log, có thống kê mẫu toàn tệp.', 'Mở 3 GB < 5 giây; thống kê lỗi lặp/khoảng thời gian', 'M', 'M3', '[1] §9'],
  ['UR-QS-02', 'Là kỹ sư, tôi cần chọn vùng log và "hỏi tác tử tại dòng này"; câu trả lời neo vào dòng và lưu được.', 'Kịch bản C hoàn thành với log 1 GB', 'M', 'M3', '[1] §2.3'],
  ['UR-QS-03', 'Là kỹ sư, tôi cần một hàng đợi xác nhận duy nhất cho mọi cổng người (nguồn, fact, diff, nạp, quyền).', 'Mọi gate hiện ở một nơi, có bộ lọc', 'M', 'M3', '[1] §9'],
  ['UR-QS-04', 'Là kỹ sư, tôi cần xem hex/firmware và .map với địa chỉ được giải nghĩa theo hộ chiếu (hover 0x40005400 → I2C1).', 'Giải nghĩa đúng cho chip có SVD', 'S', 'M3', '[1] §9'],
  ['UR-QS-05', 'Là kỹ sư, tôi cần serial console đa cổng trong GEditor với ghi JSONL và expect để kiểm thử.', '2 cổng đồng thời; expect(timeout) hoạt động', 'M', 'M3', '[1] §9'],
  ['UR-QS-06', 'Là kỹ sư, tôi cần xem bản ghi logic analyzer đã decode đồng bộ thời gian với log.', 'sigrok CSV hiển thị; chọn giao dịch → hỏi tác tử', 'C', 'M5', '[23]'],
]));
c.push(SP());
c.push(H2('3.7. MH — Mô hình ngôn ngữ'));
c.push(T(W, H, [
  ['UR-MH-01', 'Là chủ sản phẩm, tôi cần đổi Claude/Gemini/mô hình cục bộ bằng cấu hình; reviewer khác hãng với coder.', 'Bộ tác vụ chuẩn chạy trên ≥ 3 mô hình', 'M', 'M0', '[3]'],
  ['UR-MH-02', 'Là doanh nghiệp (hướng sau), tôi cần tùy chọn chế độ cục bộ: không lượt gọi đám mây, không tải tài liệu ra ngoài. Bản đầu tiên mặc định dùng Internet và LLM đám mây; dự án có thể gắn cờ "nhạy cảm" để tác tử hỏi trước khi gửi tài liệu ra dịch vụ ngoài.', 'Bản đầu: cờ nhạy cảm hoạt động; M5: kiểm lưu lượng = 0 kết nối ngoài khi bật chế độ cục bộ', 'S', 'M5', '[26] §1.1'],
  ['UR-MH-03', 'Là chủ sản phẩm, tôi cần chi phí token theo vai trò/mô hình/tác vụ và ngân sách ngày.', 'CSV chi phí; dừng khi vượt ngân sách', 'M', 'M0', '[3]'],
]));
c.push(SP());
c.push(H2('3.8. RG — Registry'));
c.push(T(W, H, [
  ['UR-RG-01', 'Là Pack owner, tôi cần đóng gói hộ chiếu + skill + benchmark thành .hkp có chữ ký và phát hành lên registry nội bộ.', 'hkw publish tạo gói hợp lệ; registry từ chối gói thiếu license', 'M', 'M4', '[1] §10'],
  ['UR-RG-02', 'Là kỹ sư, tôi cần pull gói theo id@semver, xem huy hiệu (đã xác minh trên board, benchmark theo mô hình) trước khi tin dùng.', 'Huy hiệu hiển thị với hash log kiểm định', 'M', 'M4', '[1] §10.2'],
  ['UR-RG-03', 'Là chủ sản phẩm, tôi cần gieo hạt registry tự động từ CMSIS-SVD và Microchip ATDF với nhãn "chưa kiểm định".', '≥ 500 gói hạt giống', 'M', 'M4', '[8], [9]'],
  ['UR-RG-04', 'Là giảng viên, tôi cần học viên nộp hộ chiếu như bài tập và được ghi tác giả khi gói được kiểm định.', 'Quy trình nộp – kiểm định – ghi công', 'S', 'M4', '[1] §10.3'],
]));
c.push(SP());
c.push(H2('3.9. QT — Quản trị và an toàn'));
c.push(T(W, H, [
  ['UR-QT-01', 'Là kỹ sư, tôi cần mọi thao tác lớp R4 (xóa flash toàn bộ, ghi fuse/option byte, điều khiển động cơ/nguồn/nhiệt, cài phần mềm ngoài danh sách tin cậy, phát hành công khai, gửi tài liệu nhạy cảm ra ngoài) luôn hỏi tôi; thao tác R1–R3 tự làm theo mức tự chủ và có thể hoàn tác.', 'Không có thao tác R4 nào chạy khi chưa cấp quyền; R3 trên board lab tự động và có nhật ký', 'M', 'M1', '[26] §3'],
  ['UR-QT-02', 'Là kỹ sư, tôi cần known-good và hoàn tác một lệnh.', 'hkw rollback khôi phục và build đạt', 'M', 'M2', '[2]'],
  ['UR-QT-03', 'Là kỹ sư, tôi cần tiếp tục phiên sau khi tắt máy nhờ PROGRESS/FEATURES và nhật ký.', 'Phiên mới đọc tiến độ, tiếp tục ≤ 15 phút', 'M', 'M2', '[18]'],
  ['UR-QT-04', 'Là kỹ sư, tôi cần toàn bộ dữ liệu dự án nằm trong `.hkw/` commit được vào Git, không máy chủ.', 'Clone repo trên máy khác → mở được dự án', 'M', 'M0', '[1] §6.3'],
  ['UR-QT-05', 'Là kỹ sư, tôi cần tác tử tự kiểm tra bộ cài, phát hiện công cụ thiếu và tự cài từ danh sách gói tin cậy (toolchain mở, Renode, probe-rs, esptool…); gói ngoài danh sách hoặc cần quyền hệ thống thì hỏi tôi một lần.', 'Máy mới → môi trường build/sim sẵn sàng với ≤ 1 câu hỏi; hồ sơ môi trường tái dựng (tools.lock)', 'M', 'M1', '[2], [25] env.*'],
  ['UR-QT-06', 'Là kỹ sư, tôi cần đặt mức tự chủ (A0–A4) cho dự án và cho từng board, hạ mức ngay bằng một lệnh "dừng".', 'Lệnh dừng hạ về A0 trong < 1 s; thao tác phần cứng đang chờ bị hủy', 'M', 'M1', '[26] §2, §5'],
  ['UR-QT-07', 'Là kỹ sư, tôi cần mọi việc tác tử tự làm (fact tự duyệt, merge tự động, nạp board lab) nằm trong hàng đợi "đã làm — hoàn tác được trong T" với một nút hoàn tác.', 'Hoàn tác merge/fact/nạp khôi phục đúng trạng thái trước; T cấu hình được', 'M', 'M1', '[26] §5'],
]));
c.push(SP());
c.push(H2('3.10. HT — Học tập và đánh giá'));
c.push(T(W, H, [
  ['UR-HT-01', 'Là chủ sản phẩm, tôi cần benchmark theo ba mức, chấm CF/BF/BC trên board, chạy lại khi đổi mô hình/skill.', '≥ 10 tác vụ cho armv7-m và avr8', 'M', 'M2', '[17]'],
  ['UR-HT-02', 'Là học viên, tôi cần hướng dẫn tiếng Việt "viết hộ chiếu cho board X" làm được trong một buổi.', 'Học viên mới hoàn thành ≥ 80%', 'S', 'M4', '[1] §10.3'],
  ['UR-HT-03', 'Là kỹ sư, tôi cần giải thích ngắn (≤ 150 từ, có trích dẫn) cho mỗi quyết định của tác tử.', 'Mỗi CodePatch/Diagnosis có rationale', 'S', 'M2', '[1]'],
  ['UR-HT-04', 'Là kỹ sư, tôi cần hệ thống tổng hợp các lần tôi duyệt/từ chối/hoàn tác thành đề xuất chỉnh ngưỡng tự phê duyệt, và chỉ đổi ngưỡng khi tôi xác nhận.', 'Báo cáo đề xuất ngưỡng hằng tháng; ngưỡng không tự nới lỏng', 'S', 'M2', '[26] §6'],
]));
c.push(SP());
c.push(H2('3.11. NL — Lệnh ngôn ngữ tự nhiên và tự chủ (mới v1.1)'));
c.push(T(W, H, [
  ['UR-NL-01', 'Là kỹ sư, tôi cần ra lệnh bằng ngôn ngữ tự nhiên (tiếng Việt hoặc Anh) cho mọi việc — tạo dự án, dựng tri thức từ zip, cài môi trường, mô phỏng, viết firmware, vẽ sơ đồ, viết tài liệu — và tác tử tự gọi các năng lực cần thiết theo chuỗi.', 'Kịch bản chuẩn (board mới, zip hỗn hợp → firmware chạy trên mô phỏng) hoàn thành từ ≤ 3 câu lệnh và ≤ 5 lần bấm/duyệt', 'M', 'M1', '[26] §1.1, [27]'],
  ['UR-NL-02', 'Là kỹ sư, khi tôi ra lệnh mà đầu vào chưa có gì ("tạo dự án robot hai bánh tự cân bằng"), tôi cần tác tử kiểm tra cái đã tồn tại (dự án, mẫu tham chiếu, board) trước khi tạo, và hỏi tôi dùng luôn hay tạo mới.', 'Kịch bản Z-01…Z-10 của DPS-09 đạt; không tạo trùng; không ghi đè', 'M', 'M1', '[27] §3, [28] sheet 9'],
  ['UR-NL-03', 'Là kỹ sư, tôi cần tác tử điền tham số thiếu bằng mặc định có căn cứ trước, và nếu phải hỏi thì gộp thành một câu có phương án đánh số, phương án mặc định và thời gian chờ.', 'Không quá một câu hỏi/lượt; im lặng quá T ⇒ mặc định và báo', 'M', 'M1', '[27] D2–D3'],
  ['UR-NL-04', 'Là kỹ sư, trước một chuỗi dài tôi cần tác tử nói lại ý hiểu trong 1–2 câu rồi làm ngay phần chắc chắn; tôi sửa được bất cứ lúc nào mà không cần bấm xác nhận.', 'Mọi lệnh lớn có câu "tôi hiểu là… tôi sẽ…" trong ledger', 'M', 'M1', '[27] D4, D6'],
  ['UR-NL-05', 'Là kỹ sư, tôi cần tác tử ghi nhớ lựa chọn của tôi (luôn tạo mới, dùng ST-Link, mô hình ưa thích) để lần sau không hỏi lại, và báo "áp dụng như lần trước".', 'Câu hỏi lặp giảm về 0 sau lần trả lời đầu', 'S', 'M1', '[27] D8, [25] memory.*'],
  ['UR-NL-06', 'Là kỹ sư, tôi cần mọi chức năng tôi bấm được trên giao diện cũng gọi được bằng lệnh, với cùng hợp đồng, cùng chính sách và cùng nhật ký.', '228/238 năng lực có mã gọi; UI và Orchestrator dùng chung registry', 'M', 'M1', '[25]'],
  ['UR-NL-07', 'Là kỹ sư, sau mỗi lệnh tôi cần một báo cáo ngắn: đã làm gì, đang chờ tôi gì, hoàn tác được đến khi nào, chi phí bao nhiêu.', 'Báo cáo ≤ 10 dòng sau mỗi chuỗi; thanh trạng thái hiển thị số việc tự làm/chờ', 'M', 'M1', '[26] §5'],
]));
c.push(SP());
c.push(H2('3.12. KN — Kỹ nghệ: yêu cầu, kiến trúc, lược đồ, tài liệu (mới v1.1)'));
c.push(T(W, H, [
  ['UR-KN-01', 'Là kỹ sư, tôi cần tác tử thu thập và phân tích yêu cầu từ lệnh, tài liệu, ảnh và chat cũ: phân loại FR/NFR/ràng buộc phần cứng, đối chiếu khả thi với hộ chiếu chip/board, phát hiện mâu thuẫn, ưu tiên, sinh tiêu chí chấp nhận và ma trận truy vết.', 'Từ README + BOM → ReqSet có mã UR/FR, ≥ 90% yêu cầu được người chấp nhận không sửa', 'M', 'M1', '[25] req.*'],
  ['UR-KN-02', 'Là kỹ sư, tôi cần tác tử đề xuất kiến trúc firmware (super-loop / event-driven / RTOS / layered) theo yêu cầu và tài nguyên chip, phân rã module, gán module ↔ ngoại vi/chân/ngắt, lập ngân sách RAM/Flash/thời gian, ghi ADR và rà theo checklist nhúng.', 'Kiến trúc có ADR và ngân sách; xung đột tài nguyên = 0 trước khi sinh mã', 'M', 'M2', '[25] arch.*, [36], [38]'],
  ['UR-KN-03', 'Là kỹ sư, tôi cần mọi lược đồ (sơ đồ khối, chân, kiến trúc C4, tuần tự, trạng thái, lưu đồ, giản đồ thời gian, bản đồ bộ nhớ, Gantt) được sinh ở ngôn ngữ mà GEditor đã hỗ trợ (Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG) để tôi xem và sửa ngay trong GEditor.', 'Lược đồ render trong GEditor; lint 0 lỗi; sửa mã lược đồ → cập nhật hình', 'M', 'M1', '[25] diagram.*, [31]–[35]'],
  ['UR-KN-04', 'Là kỹ sư, tôi cần lược đồ đồng bộ hai chiều với mã/kiến trúc (máy trạng thái ↔ mã FSM, sơ đồ kiến trúc ↔ phân rã module) và được cảnh báo khi lệch.', 'Đổi mã FSM → lược đồ trạng thái cập nhật; lệch được liệt kê', 'S', 'M3', '[25] diagram.sync'],
  ['UR-KN-05', 'Là kỹ sư, tôi cần tác tử viết tài liệu theo chuẩn bộ EAA/EIDE (URD, SRS, SAD, SDD, STP, hướng dẫn bring-up, báo cáo kiểm thử) từ tri thức dự án, có bảng thuộc tính, lịch sử, hình đánh số và mục Nguồn; tiếng Việt ưu tiên, thuật ngữ Anh có giải nghĩa, mọi khẳng định có nguồn.', 'Tài liệu sinh ra qua doc.style_check 0 lỗi; mọi số liệu có trích dẫn fact', 'M', 'M2', '[25] doc.*'],
  ['UR-KN-06', 'Là kỹ sư, tôi cần tài liệu và lược đồ được cập nhật khi mã/kiến trúc/fact đổi, với mục lỗi thời được đánh dấu.', 'Đổi fact → mục tài liệu liên quan bị gắn nhãn cần cập nhật', 'S', 'M3', '[25] doc.sync, req.change_impact'],
  ['UR-KN-07', 'Là kỹ sư, tôi cần nhận dạng sơ đồ trong ảnh (schematic, sơ đồ vẽ tay) thành mã lược đồ chỉnh sửa được.', 'Ảnh sơ đồ khối → Mermaid đúng ≥ 80% nút/cạnh', 'C', 'M3', '[25] diagram.from_image'],
]));
c.push(SP());
c.push(H2('3.13. TQ — Bản đồ tri thức và hỏi–đáp RAG (mới v1.1)'));
c.push(T(W, H, [
  ['UR-TQ-01', 'Là kỹ sư, tôi cần xem bản đồ tri thức toàn dự án (chip, board, module, fact, nguồn) tô màu theo tầng, trạng thái và mâu thuẫn; zoom/lọc/tìm; nhấp một nút để xem lân cận, nguồn gốc và mã dùng nó.', 'Đồ thị 50.000 nút hiển thị < 3 s; nhấp fact → mở đúng trang PDF', 'M', 'M1', '[25] view.kg_map, view.provenance'],
  ['UR-TQ-02', 'Là kỹ sư, tôi cần hỏi–đáp bằng ngôn ngữ tự nhiên trên toàn kho tài liệu dự án (PDF, ảnh OCR, mã, chat) và nhận câu trả lời có trích dẫn nhấp mở nguồn, kèm phần giải thích vì sao (đoạn truy hồi, đường lan tỏa trên đồ thị).', '100 câu hỏi mẫu: ≥ 90% đúng, 100% có trích dẫn; hiển thị trace', 'M', 'M1', '[25] view.rag_*, [37]'],
  ['UR-TQ-03', 'Là kỹ sư, tôi cần bản đồ độ phủ (ngoại vi/thanh ghi/chân nào đã có fact, thiếu, đang yêu cầu) và bản đồ tác động khi fact/yêu cầu đổi.', 'Độ phủ tính đúng theo hộ chiếu; tác động khớp kg.impact', 'S', 'M2', '[25] view.coverage_map, view.impact_map'],
  ['UR-TQ-04', 'Là kỹ sư, tôi cần so sánh câu trả lời theo nhiều nguồn (datasheet, errata, cộng đồng) và xuất bản đồ ra DOT/GraphML/Mermaid để chèn tài liệu.', 'So sánh chỉ ra chỗ khác; xuất Mermaid render được', 'S', 'M2', '[25] view.rag_compare, view.export_map'],
]));
c.push(SP());
c.push(H2('3.14. DT — Dò board, probe và kết nối (mới v1.1)'));
c.push(T(W, H, [
  ['UR-DT-01', 'Là kỹ sư, tôi cần tác tử tự dò cổng USB/serial/JTAG-SWD và probe đang cắm (ST-Link, J-Link, CMSIS-DAP, PICkit, ESP USB-JTAG, FTDI), đọc ID chip và đối chiếu hộ chiếu, rồi tự cấu hình target (adapter, tốc độ, cổng) cho dự án.', 'Cắm board → target sẵn sàng trong < 30 s không thao tác; ID không khớp ⇒ cảnh báo', 'M', 'M2', '[25] discover.*, [39]'],
  ['UR-DT-02', 'Là kỹ sư, tôi cần tác tử dò tốc độ kết nối tối ưu (auto-baud serial, SWD/JTAG clock, SPI/I2C clock) bằng cách thử nấc và đo lỗi, không vượt giới hạn datasheet.', 'Baud/clock được chọn với tỷ lệ lỗi 0 trong 1.000 khung; nấc vượt datasheet bị hỏi', 'M', 'M2', '[25] discover.link_speed'],
  ['UR-DT-03', 'Là kỹ sư, tôi cần nhận diện board từ chip ID + quét bus I2C/SPI + ảnh/BOM, với ứng viên xếp hạng từ registry/web.', '3 board mẫu nhận diện đúng; nhiều ứng viên ⇒ hỏi một câu', 'S', 'M2', '[25] discover.board_match, discover.bus_scan'],
  ['UR-DT-04', 'Là kỹ sư, tôi cần biết firmware đang chạy trên board, nguồn cấp và tần số thực trước khi nạp, và dò thiết bị nhúng trên LAN cho board có Wi-Fi/Ethernet.', 'Banner/bootloader nhận diện; điện áp bất thường ⇒ chặn nạp', 'S', 'M3', '[25] discover.firmware_probe, power, clock_measure, network'],
]));
c.push(SP());
c.push(H1('4. Yêu cầu chất lượng'));
c.push(T([1000, 1900, 4000, 2400], ['Mã', 'Thuộc tính', 'Yêu cầu', 'Kiểm tra'], [
  ['UQ-01', 'Trung thực', 'Không fact nào thiếu nguồn; tác tử nói "không tìm thấy" thay vì đoán', 'Kiểm mẫu 100 hằng số'],
  ['UQ-02', 'Tin cậy', 'BC ≥ 90% mức 1–2 trên benchmark với ≥ 2 mô hình khác hãng', 'Báo cáo benchmark'],
  ['UQ-03', 'An toàn', 'Không thao tác không đảo ngược ngoài quyền; không merge ngoài G3', 'Test cưỡng chế + nhật ký'],
  ['UQ-04', 'Hiệu năng', 'passport.query < 200 ms; mở log 3 GB < 5 s; build–nạp–log < 2 phút', 'Đo tự động'],
  ['UQ-05', 'Chi phí', '≤ 8.000 token ngữ cảnh/lượt; ≤ 1 USD/module cỡ driver I2C (cấu hình được)', 'Ledger'],
  ['UQ-06', 'Di động', 'Knowledge Plane và CLI: macOS/Linux/Windows; UI GEditor: macOS', 'CI 3 hệ điều hành'],
  ['UQ-07', 'Bảo mật', 'Khóa API qua biến môi trường; nhật ký không chứa khóa; dự án gắn cờ nhạy cảm ⇒ hỏi trước khi gửi tài liệu ra dịch vụ ngoài; extractor chạy trong sandbox', 'Quét nhật ký; test cờ nhạy cảm'],
  ['UQ-10', 'Tự động hóa', 'Kịch bản chuẩn ≤ 5 lần bấm/duyệt; ≥ 85% năng lực ở mức T1 (AI làm trọn); mọi việc tự làm có hoàn tác', 'Đếm gate trong ledger; thống kê Danh mục'],
  ['UQ-08', 'Dễ mở rộng', 'Thêm extractor/ISA/adapter bằng plugin, không sửa core', 'Thêm ISA mới với 0 dòng core'],
  ['UQ-09', 'Tiếng Việt', 'Giao diện, giải thích, tài liệu bàn giao tiếng Việt; thuật ngữ Anh kèm giải nghĩa', 'Kiểm mẫu'],
]));
c.push(SP());
c.push(H1('5. Ràng buộc'));
c.push(T([1000, 8300], ['Mã', 'Ràng buộc'], [
  ['CR-01', 'Knowledge Plane bằng Python 3.11+; kho `core` dùng chung với EAA-U (Engine, Gateway, Passport, Targets); hai kho sản phẩm riêng'],
  ['CR-02', 'Registry chạy nội bộ (khóa học, tư vấn) trước; công khai sau khi có ý kiến pháp lý về license tài liệu hãng'],
  ['CR-03', 'Không phân phối lại PDF/tài liệu hãng trong gói; chỉ fact + con trỏ nguồn + hash'],
  ['CR-04', 'Toolchain mở là mặc định; toolchain đóng (XC8, IAR, Keil) chỉ qua dòng lệnh, giai đoạn M5'],
  ['CR-05', 'Không GUI riêng ngoài GEditor plugin; các nền tảng khác dùng CLI + MCP'],
  ['CR-06', 'ISA khởi đầu: armv6/7/8-m, rv32, avr8; PIC/xtensa/custom sau M4'],
  ['CR-07', 'Bảo toàn bất biến EAA: gate cưỡng chế (người hoặc chính sách quyết định theo APD-08), ≤ 3 vòng tự sửa, merge chỉ khi ToolReport đạt và G3'],
  ['CR-08', 'Bản đầu tiên: một máy PC của kỹ sư, Internet đầy đủ, LLM đám mây (Claude/Gemini) là mặc định; đa người dùng/máy chủ và chế độ cục bộ là hướng sau'],
  ['CR-09', 'Lược đồ chỉ ở các ngôn ngữ GEditor hỗ trợ (Mermaid, PlantUML, Graphviz/DOT, D2, WaveDrom, SVG); không sinh hình bitmap làm nguồn'],
  ['CR-10', 'Mọi chức năng phải khai báo trong Danh mục năng lực với đủ 13 cột (hợp đồng); chức năng không có trong danh mục không được phơi ra UI hay tác tử'],
]));
c.push(SP());
c.push(H1('6. Ma trận truy vết UR → FR (tóm tắt)'));
c.push(P('Từ v1.1, SRS-02 có hai lớp FR: FR v1.0 theo mô-đun (ACQ, PSP, BRD, AGT, LLM, VER, DBG, MCP, UI, REG, GOV, BEN) và FR theo năng lực (mã = mã năng lực trong Danh mục, ví dụ FR-EXTRACT-05). Bảng dưới truy vết nhóm UR tới cả hai.'));
c.push(T([1200, 3300, 4800], ['Nhóm UR', 'Nhóm FR v1.0 trong EIDE-SRS-02', 'Nhóm năng lực (FR v1.1)'], [
  ['TT', 'FR-ACQ-01…09, FR-PSP-01…06', 'archive, search, extract, passport, kg'], ['MC', 'FR-BRD-01…04', 'board, extract.bom/netlist'], ['MA', 'FR-AGT-01…07, FR-MCP-01…04', 'plan, code, memory'], ['XM', 'FR-VER-01…05', 'sim, target, measure, bench'],
  ['GL', 'FR-DBG-01…04', 'debug'], ['QS', 'FR-UI-01…07', 'view, debug.log_stats, target.serial'], ['MH', 'FR-LLM-01…04', 'memory, policy (ngân sách)'], ['RG', 'FR-REG-01…05', 'registry'], ['QT', 'FR-GOV-01…06, FR-AUT-01…06', 'policy, env, project'], ['HT', 'FR-BEN-01…03', 'bench, report'],
  ['NL', 'FR-DLG-01…08, FR-AUT-01…06', 'chat, policy, memory'], ['KN', 'FR-REQ, FR-ARCH, FR-DIAGRAM, FR-DOC', 'req, arch, diagram, doc'], ['TQ', 'FR-VIEW', 'view, kg'], ['DT', 'FR-DISCOVER', 'discover, target'],
]));
c.push(SP());
c.push(...refParas(H1));
build(m, c, 'EIDE-URD-01_Yeu_cau_nguoi_dung.docx');
