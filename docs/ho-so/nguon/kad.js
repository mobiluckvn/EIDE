const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { meta, refParas } = require('./eide_common');
const m = meta('EIDE-KAD-07', 'Kiến trúc và tổ chức tri thức', 'KIẾN TRÚC TRI THỨC VÀ TỔ CHỨC TRI THỨC (KAD)',
  'Phân loại tri thức của EIDE (Embedded IDE): loại nào cố định, loại nào được làm giàu, các con đường làm giàu, và cách tổ chức lưu trữ, phiên bản, xung đột, chia sẻ',
  [['Tài liệu trước', 'EIDE-PDA-00 (P1–P7), EIDE-SAD-03 (§5 dữ liệu), EIDE-SDD-04 (§3 schema)'], ['Dùng khi', 'Thiết kế extractor, composer, registry; viết chính sách tri thức; viết Chương lý thuyết về quản trị tri thức phần cứng']],
  [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (HKW-KAD-07): 9 loại tri thức trên 3 trục; quy tắc cố định/làm giàu; 10 con đường làm giàu; tổ chức 5 lớp lưu trữ; chính sách phiên bản, xung đột, ngữ cảnh, chia sẻ; ánh xạ hiện trạng M0']],
  'Thêm K5′ mẫu dự án tham chiếu và K10 tri thức kỹ nghệ (yêu cầu, kiến trúc, ADR, lược đồ, tài liệu); con đường E11 (tác tử sinh tri thức kỹ nghệ) và E12 (dò board); cổng ở E1–E10 ghi mức tự động theo APD-08; §6.9 hiển thị và truy hồi (view.*, chỉ mục RAG); ánh xạ loại tri thức ↔ nhóm năng lực');
const c = [];

c.push(H1('1. Mục đích và câu hỏi cần trả lời'));
c.push(P('Tài liệu này trả lời bốn câu hỏi mà mọi thành phần khác của EIDE phụ thuộc vào: (1) hệ thống chứa *những loại tri thức nào*; (2) loại nào *cố định* (chỉ thay bằng phiên bản), loại nào *được phép làm giàu* và ai được làm giàu; (3) tri thức đi vào hệ thống bằng *những con đường nào*, mỗi con đường cần bằng chứng gì và dừng ở cổng người nào; (4) tri thức được *tổ chức* ra sao — định danh, lớp lưu trữ, đồ thị, phiên bản, xung đột, ngữ cảnh cho tác tử, chia sẻ. Cơ sở lý luận: phân biệt tri thức tuyên bố (declarative: fact về thanh ghi) và tri thức thủ tục (procedural: cách lập trình một họ chip) trong quản trị tri thức kỹ thuật [1]; nguyên tắc provenance của W3C PROV (mọi thực thể có nguồn gốc, tác nhân và hoạt động sinh ra nó) [2]; và kết quả thực nghiệm rằng tri thức thủ tục do chuyên gia soạn cho tác tử vượt xa tri thức do mô hình tự sinh [17].'));

c.push(H1('2. Nguyên tắc nền'));
c.push(T([600, 2800, 5900], ['#', 'Nguyên tắc', 'Hệ quả cho kiến trúc tri thức'], [
  ['N1', 'Tri thức khác dữ liệu ở chỗ có nguồn, mức tin cậy và trách nhiệm', 'Đơn vị nhỏ nhất là Fact có provenance (nguồn, hash, vị trí, phương pháp, người xác nhận); không có "giá trị trần"'],
  ['N2', 'Ba chiều trực giao: nguồn gốc (tier), vòng đời (status), bằng chứng (badge)', 'Không dùng một "điểm tin cậy" duy nhất; tier chỉ đổi khi đổi nguồn, status đổi qua cổng người, badge đổi qua kiểm định vật lý'],
  ['N3', 'Cố định bằng phiên bản, không bằng khóa', 'Tri thức "cố định" không phải bất biến tuyệt đối mà là bất biến trong một phiên bản; thay đổi = phiên bản mới có lịch sử'],
  ['N4', 'Làm giàu bằng lớp phủ, không sửa lõi', 'Tri thức chính hãng (lõi) không bị ghi đè; bổ sung/sửa nằm ở lớp phủ (overlay) có nguồn riêng và được hợp nhất lúc truy vấn'],
  ['N5', 'Mô hình ngôn ngữ không phải nguồn sự thật', 'Điều mô hình "nhớ" là loại tri thức riêng (K9) ở tầng đồng, chỉ dùng để đề xuất, không bao giờ vào mã'],
  ['N6', 'Con người ở mọi điểm thăng hạng', 'Mọi con đường nâng tier/status đều đi qua G-SRC, G-FACT hoặc kiểm định trên board có người cấp quyền'],
  ['N7', 'Tri thức thuộc về ai thì lưu ở đó', 'Hãng/chuẩn → lõi tham chiếu; cộng đồng → registry/overlay; tổ chức/dự án → .hkw/ của dự án; phiên → ngữ cảnh tạm'],
]));
c.push(SP());

c.push(H1('3. Phân loại tri thức'));
c.push(H2('3.1. Chín loại tri thức (trục bản chất)'));
c.push(T([1100, 2600, 2900, 1300, 1400], ['Mã', 'Loại', 'Nội dung điển hình', 'Tính chất', 'Chủ sở hữu'], [
  ['K1', 'Tập lệnh và kiến trúc lõi (ISA)', 'ABI, mô hình ngắt/ngoại lệ, thanh ghi hệ thống, quy ước toolchain, trình gỡ lỗi, mô phỏng; các "bẫy" (PROGMEM, PRIMASK, CSR, bank thanh ghi)', 'Cố định theo phiên bản chuẩn; đổi rất chậm', 'Chuẩn/hãng (Arm, RISC-V Intl, Microchip)'],
  ['K2', 'Chip — lõi', 'Ngoại vi, địa chỉ nền, thanh ghi, offset, bit-field, enum, reset, IRQ, bộ nhớ, clock, pinout, giới hạn điện', 'Cố định theo phiên bản tài liệu hãng (SVD/ATDF/EDC, datasheet rev)', 'Hãng chip'],
  ['K2′', 'Chip — lớp phủ', 'Errata áp dụng, ghi chú cộng đồng, sửa lỗi SVD đã được duyệt, ánh xạ tên thay thế', 'Kiểm soát: làm giàu qua G-FACT; tách khỏi lõi', 'Cộng đồng / tổ chức'],
  ['K3', 'Mạch (board)', 'Net, chân–tín hiệu–linh kiện, bus và địa chỉ, nguồn, pull-up, chân reserved/boot, ràng buộc cơ khí', 'Kiểm soát; thuộc phiên bản phần cứng của dự án', 'Dự án / nhà thiết kế mạch'],
  ['K4', 'Ngoại vi ngoài', 'Cảm biến, driver động cơ, module RF: địa chỉ bus, bảng thanh ghi, chuỗi khởi tạo, timing, điện', 'Kiểm soát; từ PDF bên thứ ba đã người duyệt', 'Cộng đồng / tổ chức'],
  ['K5', 'Kỹ năng và thủ tục', 'Skill theo ISA/chip (mẫu ISR, clock, I2C), checklist review, quy tắc kiểm tĩnh, benchmark, ví dụ đã chạy thật', 'Kiểm soát; do chuyên gia soạn, kiểm định bằng benchmark', 'Chuyên gia / Pack owner'],
  ['K6', 'Dự án', 'Ràng buộc (bộ nhớ, timing, cấm), ARCHITECTURE/PLAN/STEP, FEATURES, quy ước repo, quyết định kiến trúc, pin phiên bản lõi', 'Mở trong dự án; đổi thường xuyên; qua G1/G3', 'Dự án'],
  ['K7', 'Kinh nghiệm vận hành', 'Sổ lỗi, DebugSession, giả thuyết đã kiểm, số đo vật lý, ToolReport, known-good, kết quả benchmark', 'Mở: ghi tự động, append-only, luôn kèm bằng chứng', 'Dự án (tổng hợp ẩn danh có thể chia sẻ)'],
  ['K8', 'Quy trình và quản trị', 'Định nghĩa gate, quyền theo phiên, chính sách mô hình (models.yaml), ngân sách, license', 'Cố định bởi sản phẩm; cấu hình bởi quản trị', 'Sản phẩm / tổ chức'],
  ['K9', 'Tham số mô hình', 'Điều LLM "biết" từ huấn luyện về chip, API, mẫu mã', 'Tạm thời; tầng đồng; chỉ đề xuất, không lưu như fact', 'Nhà cung cấp mô hình'],
]));
c.push(SP());
c.push(H2('3.2. Ba trục và bản đồ'));
c.push(P('Mỗi loại được đặt trên ba trục: *độ ổn định* (cố định / kiểm soát / mở / tạm thời), *quyền sở hữu* (hãng-chuẩn / cộng đồng-registry / tổ chức-dự án / phiên), và *tầng tin cậy mặc định* (vàng / bạc / đồng). Hình 1 là bản đồ hai trục đầu; tầng tin cậy thể hiện bằng màu viền.'));
c.push(...IMG('hinh/kad_taxonomy.png', 600, 360, 'Hình 1. Chín loại tri thức trên hai trục ổn định × sở hữu; màu viền là tầng tin cậy mặc định'));
c.push(T([1000, 1700, 1700, 1500, 3400], ['Loại', 'Ổn định', 'Sở hữu', 'Tier mặc định', 'Nơi lưu (xem §5.2)'], [
  ['K1', 'Cố định', 'Chuẩn/hãng', 'Vàng', 'L-A lõi tham chiếu: hkw-packs/isa/*.yaml + registry'],
  ['K2', 'Cố định', 'Hãng', 'Vàng', 'L-A: ref/<ns.part@ver>/ (seed hoặc pull)'],
  ['K2′', 'Kiểm soát', 'Cộng đồng/tổ chức', 'Bạc (vàng nếu từ errata sheet có cấu trúc)', 'L-B overlay'],
  ['K3', 'Kiểm soát', 'Dự án', 'Vàng-cấu trúc (KiCad) / bạc (ảnh)', 'L-C .hkw/store.sqlite (board passport)'],
  ['K4', 'Kiểm soát', 'Cộng đồng/tổ chức', 'Bạc', 'L-B overlay hoặc L-C; đóng gói được'],
  ['K5', 'Kiểm soát', 'Chuyên gia', 'Bạc → "kiểm định" bằng benchmark', 'hkw-packs/skills + L-B; .hkp'],
  ['K6', 'Mở (trong dự án)', 'Dự án', '— (không phải fact phần cứng)', 'L-C: FEATURES.json, PLAN/STEP, constraints.yaml'],
  ['K7', 'Mở, append-only', 'Dự án', '— (bằng chứng)', 'L-D: ledger, debug_session, tool_report, badges'],
  ['K8', 'Cố định (sản phẩm) / cấu hình', 'Sản phẩm/tổ chức', '—', 'core.engine (mã) + .hkw/models.yaml, roles.yaml'],
  ['K9', 'Tạm thời', 'Nhà cung cấp mô hình', 'Đồng', 'Không lưu; chỉ xuất hiện trong ngữ cảnh phiên và ledger'],
]));
c.push(SP());

c.push(H1('4. Cái gì cố định, cái gì được làm giàu'));
c.push(H2('4.1. Quy tắc bất biến'));
c.push(T([600, 8700], ['#', 'Quy tắc'], [
  ['R1', 'Fact tầng vàng của hãng (K1, K2) **không bao giờ bị ghi đè** bởi fact tầng thấp hơn. Phát hiện sai trong SVD → tạo fact lớp phủ (K2′) với `supersedes` trỏ về fact lõi, nguồn là báo cáo lỗi/errata, qua G-FACT; lõi giữ nguyên để tái lập.'],
  ['R2', 'K1, K2 chỉ thay đổi bằng **phiên bản mới của nguồn** (SVD rev, DFP mới); hệ thống nhập thành hộ chiếu phiên bản mới, không sửa phiên bản cũ; dự án pin phiên bản (§5.4).'],
  ['R3', 'Làm giàu K2′, K4, K5 **chỉ qua cổng người** (G-SRC cho nguồn, G-FACT cho fact); không có đường tự động nào biến đề xuất của tác tử thành fact bạc.'],
  ['R4', 'K3, K6 do **dự án sở hữu** và thay đổi tự do trong dự án nhưng mọi thay đổi ảnh hưởng mã phải qua G1 (kế hoạch) hoặc G3 (merge) và được ghi ledger.'],
  ['R5', 'K7 **chỉ bổ sung, không sửa**; mỗi bản ghi kèm bằng chứng (log hash, ToolReport, số đo); K7 không trực tiếp thay đổi K2–K5 mà chỉ *đề xuất* (ví dụ: 5 phiên gỡ lỗi cùng chỉ ra một thanh ghi sai → mở AcquisitionRequest cho K2′).'],
  ['R6', 'K9 **không bao giờ được lưu như fact** và không bao giờ được trích dẫn trong mã; constant-guard từ chối mọi hằng số không có fact id.'],
  ['R7', 'Thăng hạng tier = **thay nguồn**, không phải "duyệt nhiều lần": bạc chỉ thành vàng khi có nguồn cấu trúc của hãng; duyệt chỉ đổi status; kiểm định board chỉ thêm badge.'],
  ['R8', 'Mọi fact bị thay thế vẫn được **giữ với status superseded** để phân tích ảnh hưởng (mã nào trích dẫn fact cũ) và để kiểm toán.'],
]));
c.push(SP());
c.push(H2('4.2. Ma trận ai được làm gì'));
c.push(T([1300, 1900, 1900, 1900, 2300], ['Loại', 'Tác tử (tự động)', 'Kỹ sư dự án', 'Pack owner / chuyên gia', 'Hãng / registry'], [
  ['K1, K2', 'Đọc; đề xuất K2′', 'Đọc; pin phiên bản; đề xuất K2′', 'Đọc; nhập phiên bản mới (E1)', 'Phát hành nguồn; ký gói'],
  ['K2′, K4', 'Trích xuất (E2) → chờ duyệt; không tự ghi', 'Duyệt G-FACT; sửa; kiểm định board', 'Duyệt; đóng gói .hkp', 'Kiểm chứng gói cộng đồng (tùy chọn)'],
  ['K3', 'Dựng từ CAD (E3) → chờ duyệt', 'Duyệt; sửa; phiên bản hóa theo rev mạch', '—', '—'],
  ['K5', 'Đề xuất bổ sung skill từ K7 (chờ duyệt)', 'Dùng; góp ý', 'Soạn; kiểm định bằng benchmark; phát hành', 'Skill chính hãng (nếu có)'],
  ['K6', 'Cập nhật FEATURES/STEP theo quy trình', 'Sở hữu; duyệt G1/G3', '—', '—'],
  ['K7', 'Ghi tự động có bằng chứng', 'Đọc; chú giải; xuất ẩn danh', 'Đọc tổng hợp để cải thiện K5', 'Nhận benchmark ẩn danh (tùy chọn)'],
  ['K8', 'Tuân theo; không sửa', 'Cấu hình models.yaml trong giới hạn', '—', '—'],
  ['K9', 'Chỉ đề xuất', 'Không thấy trực tiếp; thấy qua đề xuất có nhãn "suy luận"', '—', '—'],
]));
c.push(SP());

c.push(H1('5. Các con đường làm giàu tri thức'));
c.push(P('Mười con đường (E1–E10) được đặc tả bằng cùng một mẫu: nguồn → cơ chế → cổng → bằng chứng bắt buộc → loại tri thức đích → tier/status kết quả. Hình 2 xếp chúng theo thang tin cậy và cho thấy ba chiều trực giao.'));
c.push(...IMG('hinh/kad_ladder.png', 600, 305, 'Hình 2. Thang tin cậy ba chiều và các con đường làm giàu theo tầng'));
c.push(T([900, 1900, 2300, 1300, 1500, 1400], ['Mã', 'Con đường', 'Cơ chế', 'Cổng người', 'Bằng chứng bắt buộc', 'Đích → kết quả'], [
  ['E1', 'Nhập nguồn cấu trúc của hãng', 'Parser xác định SVD/ATDF/EDC/binding/header; hash nguồn; phiên bản', 'G-SRC (chọn nguồn/phiên bản)', 'sha256, phiên bản, license', 'K1, K2 → vàng, reviewed'],
  ['E2', 'Trích xuất tài liệu phi cấu trúc', 'Docling/pdfplumber bố cục → LLM có schema → fact với trang/bbox/ảnh cắt; mô hình thị giác cho ảnh', 'G-SRC rồi G-FACT theo nhóm', 'locator (trang, bbox), ảnh cắt, confidence, người duyệt', 'K2′, K4 → bạc, normalized → reviewed'],
  ['E3', 'Nhập từ CAD', 'kicad-cli netlist → net/pin/part; ánh xạ MPN → hộ chiếu', 'G-FACT (duyệt BoardPassport)', 'hash tệp CAD, rev mạch', 'K3 → vàng-cấu trúc'],
  ['E4', 'Pull từ registry', 'Kiểm chữ ký, license, huy hiệu; nạp vào L-A/L-B', 'G-SRC (chọn gói/phiên bản)', 'chữ ký, manifest, badge', 'K2/K2′/K4/K5 → kế thừa tier của gói'],
  ['E5', 'Kiểm định trên board', 'Firmware đọc ID/GPIO/UART; so với hộ chiếu; ghi log hash', 'G-OPS (nạp)', 'log hash, board id, người, ngày', 'Badge verified_on_board; status → verified'],
  ['E6', 'Chuyên gia soạn skill', 'YAML+Markdown ≤ 600 token, ví dụ đã chạy; chạy benchmark CF/BF/BC', 'Review của Pack owner', 'kết quả benchmark theo mô hình', 'K5 → "kiểm định" khi BC ≥ ngưỡng'],
  ['E7', 'Học từ vận hành', 'Sổ lỗi, DebugSession, ToolReport, Measurement, known-good ghi tự động; tổng hợp mẫu lặp', 'Không (append-only); đề xuất K2′/K5 phải qua G-FACT', 'ToolReport, log, số đo', 'K7 (bằng chứng); đề xuất cho K2′/K5'],
  ['E8', 'Tác tử suy luận', 'Mô hình đề xuất giá trị/giả thuyết có nhãn inferred', 'Không thể vào fact nếu không qua E2/E5', 'confidence, lý do', 'Tầng đồng, không lưu như fact'],
  ['E9', 'Docs MCP của hãng', 'Truy vấn Espressif/Nordic docs MCP; lưu đoạn trích + URL + ngày', 'G-FACT khi chuyển thành fact', 'URL, ngày, phiên bản SDK', 'K2′/K4/K5 → bạc'],
  ['E10', 'Tìm kiếm web', 'Ứng viên nguồn (SVD, PDF, repo) với hash/license nếu tải được', 'G-SRC bắt buộc trước khi tải', 'uri, hash, license', 'Chỉ tạo Candidate/Source; fact đi tiếp qua E1/E2'],
]));
c.push(SP());
c.push(H2('5.1. Quy tắc thăng hạng và thay thế'));
c.push(T([2600, 6700], ['Tình huống', 'Kết quả'], [
  ['Fact mới cùng subject/predicate, cùng giá trị', 'Trùng lặp: giữ fact hiện hành, thêm liên kết hộ chiếu (không tạo fact mới)'],
  ['Fact mới tier cao hơn, giá trị khác', 'Fact mới thay thế (supersedes); fact cũ → superseded; kg.impact liệt kê mã trích dẫn fact cũ → backlog kiểm lại'],
  ['Fact mới tier bằng hoặc thấp hơn, giá trị khác', 'Fact mới status = conflict; cạnh CONFLICTS_WITH; bắt buộc người giải quyết tại G-FACT (chọn một, hoặc đánh dấu cả hai đúng theo điều kiện)'],
  ['Predicate nhiều giá trị (irq, enum, pin_function, net)', 'Không hợp nhất theo (subject, predicate) mà theo (subject, predicate, giá trị): các giá trị cùng tồn tại'],
  ['Nguồn mới cùng loại, phiên bản mới (SVD rev 1.2 → 1.3)', 'Hộ chiếu phiên bản mới; dự án pin phiên bản cũ vẫn chạy; báo cáo diff giữa hai phiên bản để quyết định nâng'],
  ['Kiểm định board thất bại cho fact vàng', 'Không hạ tier; tạo K7 (DebugSession) và đề xuất K2′ có nguồn là log kiểm định; người quyết định'],
]));
c.push(SP());

c.push(H2('5.2. Bổ sung v1.1: K5′, K10, E11, E12 và cổng theo chính sách'));
c.push(P('Hai loại tri thức được thêm để đáp ứng danh mục năng lực [25]. **K5′ — mẫu dự án tham chiếu** (registry kind=template: hộ chiếu chip/board + BOM + skill + kịch bản mô phỏng + firmware mẫu + tham số vật lý có nguồn) là điểm xuất phát khi đầu vào trống ("tạo dự án robot hai bánh tự cân bằng" → search.reference_projects); nó thuộc lớp L-A/L-B, tier kế thừa gói, không bao giờ ghi đè K3/K6 của dự án. **K10 — tri thức kỹ nghệ của dự án**: ReqSet, ModuleGraph, HwMap, ADR, Diagram, DocArtifact, ma trận truy vết — do tác tử sinh (req.*, arch.*, diagram.*, doc.*) từ K2–K6, thuộc lớp L-C, có trích dẫn fact, được phiên bản theo Git và đánh dấu stale khi fact/mã đổi (req.change_impact, doc.sync, diagram.sync). K10 không phải fact phần cứng: nó là *diễn giải có nguồn* và mọi hằng số trong đó vẫn phải đối chiếu K2/K3.'));
c.push(T([900, 1900, 2300, 1300, 1500, 1400], ['Mã', 'Con đường', 'Cơ chế', 'Cổng', 'Bằng chứng bắt buộc', 'Đích → kết quả'], [
  ['E11', 'Tác tử sinh tri thức kỹ nghệ', 'req.elicit/classify/ground_hw → arch.* → diagram.* → doc.*; mỗi khẳng định trích dẫn fact; style_check', 'Hội thoại (câu hỏi gộp) cho mâu thuẫn; G1 khi đổi kiến trúc dự án đã có', 'citations[] tới K2–K6; lint/style = 0', 'K10 → L-C, status generated → reviewed khi người sửa/chấp nhận'],
  ['E12', 'Dò board và kết nối', 'discover.ports/probes/chip_id/link_speed/bus_scan/firmware/power → Discovery; đối chiếu hộ chiếu', 'Không (R0/R1); ID lệch ⇒ leo thang; nấc tốc độ vượt fact ⇒ ASK', 'raw ID, VID/PID, bảng (nấc, tỷ lệ lỗi), thời điểm', 'K7 (bằng chứng) + đề xuất K3 (board_match) qua G-FACT'],
]));
c.push(SP());
c.push(P('Cổng ở E1–E10 từ v1.1 do PolicyGate quyết định trước khi tới người: E1 và E4 tự động ở ≥ A1 (nguồn hãng/registry ký, hash và license rõ); E2 tự duyệt fact bạc đạt ngưỡng ở ≥ A1 (confidence ≥ 0,85 và nguồn thứ hai hoặc khớp dải), fact OCR/điện/timing chưa có nguồn thứ hai vẫn hỏi; E3 tự động khi hash CAD hợp lệ; E5 tự động trên board lab ở ≥ A3; E6 và E9 giữ nguyên; E7 append-only; E8 không đổi (tầng đồng không thành fact); E10 tự tải khi tên miền trong danh sách tin cậy. Nguyên tắc KAD không đổi: tầng tin cậy của fact phụ thuộc nguồn và bằng chứng, không phụ thuộc ai duyệt — "auto-reviewed by policy" ghi rõ trong confirmed_by để kiểm toán.'));
c.push(H1('6. Tổ chức tri thức'));
c.push(H2('6.1. Định danh và không gian tên'));
c.push(T([2200, 3500, 3600], ['Đối tượng', 'Định danh', 'Ghi chú'], [
  ['ISA profile', 'isa:<id>  (armv7e-m, rv32imac, avr8, pic16e, xtensa-lx7, custom.<org>.<name>)', 'Phiên bản theo chuẩn'],
  ['Hộ chiếu chip', '<ns>.<part>@<semver>  (st.stm32f411@1.1.0)', 'ns theo hãng; semver = phiên bản nguồn (SVD version) chuẩn hóa'],
  ['Hộ chiếu mạch', '<ns>.<board>@<semver>  (weact.blackpill-f411@1.0.0; myorg.robot-ctrl@2.1.0)', 'semver = rev mạch'],
  ['Subject IRI', 'chip:<ns.part>/periph:<P>/reg:<R>/field:<F>; chip:…/pin:<PB6>; board:<ns.board>/net:<N>', 'Không chứa phiên bản: phiên bản nằm ở hộ chiếu; cùng subject có nhiều fact theo thời gian'],
  ['Fact', 'f_<sha256(subject|predicate|value|source)[:16]>', 'Bất biến; cùng nội dung từ cùng nguồn → cùng id'],
  ['Source', 's_<sha256(tệp)[:16]>', 'Một tệp = một nguồn dù nhập nhiều lần'],
  ['Gói .hkp', '<passport id> hoặc <ns>.<skill-set>@<semver>', 'Ký số theo người phát hành'],
]));
c.push(SP());
c.push(H2('6.2. Năm lớp lưu trữ'));
c.push(...IMG('hinh/kad_layers.png', 600, 251, 'Hình 3. Năm lớp lưu trữ và quy tắc hợp nhất khi truy vấn'));
c.push(T([1500, 2300, 2600, 2900], ['Lớp', 'Chứa', 'Vị trí', 'Quy tắc'], [
  ['L-A Lõi tham chiếu', 'K1, K2 (vàng, theo phiên bản)', '~/.hkw/ref/ (toàn máy) — SQLite per passport hoặc store chung "ref.sqlite"', 'Chỉ ghi bằng E1/E4; không sửa; xóa chỉ khi không dự án nào pin'],
  ['L-B Lớp phủ', 'K2′, K4, K5', '~/.hkw/overlay/ (tổ chức) và .hkw/overlay/ (dự án)', 'Ghi qua G-FACT; supersedes trỏ về L-A; đóng gói được'],
  ['L-C Dự án', 'K3, K6, pin phiên bản', '.hkw/store.sqlite, FEATURES.json, PROGRESS.md, constraints.yaml, models.yaml', 'Commit Git; thuộc dự án; G1/G3'],
  ['L-D Kinh nghiệm', 'K7', '.hkw/ledger/*.jsonl; bảng debug_session, tool_report, gate_decision', 'Append-only; có hash; xuất ẩn danh tùy chọn'],
  ['L-E Cache/ngữ cảnh', 'tài liệu tải về, ảnh cắt, graph.cache, prompt đã nén', '.hkw/cache/ (không commit)', 'Tái dựng được; không bao giờ là nguồn'],
]));
c.push(SP());
c.push(P('Truy vấn hợp nhất (resolve) cho một subject: lấy fact hiện hành ở L-C (nếu dự án có ghi đè, ví dụ địa chỉ I2C theo mạch) → L-B (overlay tổ chức rồi cộng đồng) → L-A (lõi). Ở mỗi bước áp dụng quy tắc tier: fact L-B/L-C chỉ thắng L-A khi là `supersedes` đã duyệt; nếu không, cả hai trả về với nhãn conflict. L-D chỉ đọc để gắn bằng chứng; L-E không tham gia.'));
c.push(H2('6.3. Đồ thị tri thức: quan hệ giữa các loại'));
c.push(T([2400, 6900], ['Cạnh', 'Nối loại nào với loại nào'], [
  ['HAS', 'K2: chip → periph → reg → field; K3: board → net → pin'],
  ['CONNECTS', 'K3 ↔ K2/K4: net nối pin chip với pin linh kiện ngoài'],
  ['CITES', 'Fact → Source (mọi loại); CodeUnit (K6) → Fact (K2/K3/K4)'],
  ['USES', 'CodeUnit (K6) → periph/pin (K2/K3): cơ sở cho xung đột tài nguyên'],
  ['SUPERSEDES', 'Fact overlay (K2′) → Fact lõi (K2); fact mới → cũ trong cùng lớp'],
  ['CONFLICTS_WITH', 'Hai fact cùng subject/predicate khác giá trị, cùng tier'],
  ['APPLIES_TO', 'Skill (K5) → ISA/chip/ngoại vi mà nó áp dụng; benchmark → Pack'],
  ['EVIDENCED_BY', 'Feature/Fact/Badge → Measurement/DebugSession/ToolReport (K7)'],
  ['DERIVED_FROM', 'Đề xuất K2′/K5 sinh từ tổng hợp K7 (để truy nguyên vì sao có đề xuất)'],
]));
c.push(SP());
c.push(H2('6.4. Phiên bản hóa và ghim (pin)'));
c.push(P('Mỗi dự án ghim phiên bản lõi mà nó dùng trong `constraints.yaml` (`pins: {chip: st.stm32f411@1.1.0, isa: armv7e-m@2024.1, overlay: community.stm32f4-errata@0.3.0}`). Khi có phiên bản mới, EIDE tạo báo cáo khác biệt (fact thêm/bớt/đổi) và kg.impact cho biết mã nào bị ảnh hưởng; nâng phiên bản là một quyết định tại G1. Nhờ vậy: (a) thí nghiệm A/B trong đề án tái lập được; (b) lỗi do tri thức đổi không lẫn với lỗi do mã đổi; (c) gói .hkp tham chiếu chính xác phiên bản lõi mà skill/benchmark đã kiểm định.'));
c.push(H2('6.5. Chính sách xung đột'));
c.push(T([1600, 1800, 1800, 1800, 2300], ['Fact hiện hành ↓ / mới →', 'Vàng', 'Bạc đã duyệt', 'Bạc chưa duyệt', 'Đồng'], [
  ['Vàng', 'Phiên bản mới của nguồn → hộ chiếu mới; khác nguồn cùng tier → conflict', 'Chỉ qua overlay supersedes (G-FACT)', 'Không vào; chờ duyệt', 'Không vào'],
  ['Bạc đã duyệt', 'Thay thế (supersedes), báo ảnh hưởng', 'Conflict, người chọn', 'Chờ duyệt; nếu duyệt → conflict', 'Không vào'],
  ['Bạc chưa duyệt', 'Thay thế', 'Thay thế sau duyệt', 'Giữ cả hai, cùng chờ duyệt', 'Không vào'],
  ['(chưa có)', 'Vào, reviewed', 'Vào, reviewed', 'Vào, normalized', 'Chỉ hiển thị là đề xuất'],
]));
c.push(SP());
c.push(H2('6.6. Ngữ cảnh cho tác tử: loại tri thức nào vào prompt'));
c.push(T([1400, 3000, 2600, 2300], ['Lớp composer', 'Loại tri thức', 'Cách chọn', 'Ngân sách gợi ý'], [
  ['C1 Vai trò và quy tắc', 'K8', 'Cố định theo vai trò', '≤ 400 token'],
  ['C2 Ràng buộc dự án', 'K6 (constraints)', 'Toàn bộ, nén', '≤ 600'],
  ['C3 Skill', 'K5 (≤ 3 skill)', 'Theo ISA/chip/ngoại vi của tác vụ (APPLIES_TO)', '≤ 1.800'],
  ['C4 Fact phần cứng', 'K2, K2′, K3, K4', 'Graph-RAG lan tỏa 2 bước từ subject của tác vụ; chỉ fact hiện hành, có trích dẫn', '≤ 2.500'],
  ['C5 Tác vụ và mã liên quan', 'K6 (STEP, tệp)', 'Tệp trong USES/CITES của module', '≤ 1.500'],
  ['C6 Phản hồi công cụ', 'K7 (ToolReport, log đã lọc, chứng cứ)', 'Lỗi mới nhất; log khớp mẫu; gói chứng cứ', '≤ 900'],
  ['C7 Lịch sử lượt', 'Ngữ cảnh tạm', 'Tối đa 2 lượt', '≤ 300'],
]));
c.push(SP());
c.push(P('K9 không có lớp riêng: mô hình tự dùng tham số của nó, nhưng mọi hằng số trong đầu ra phải đối chiếu được với C4; nếu mô hình "nhớ" một địa chỉ mà C4 không có, constant-guard chặn và mở E10/E2. Đây là cơ chế biến K9 từ rủi ro thành gợi ý tìm kiếm.'));
c.push(H2('6.6b. Ngữ cảnh cho tầng hiểu lệnh (v1.1)'));
c.push(P('Orchestrator dùng một composer riêng, nhỏ hơn: C0 mô tả năng lực (top-k theo từ khóa của lệnh, ≤ 60 token/năng lực, ≤ 1.200 token), C1′ trạng thái dự án tóm tắt (dự án mở, board, hộ chiếu, feature failing đầu, mục chờ), C2′ preferences.yaml và defaults, C7 hai lượt gần nhất. Không đưa fact phần cứng vào bước hiểu lệnh — grounding tra store trực tiếp (deterministic) thay vì nhờ mô hình nhớ.'));
c.push(H2('6.7. Vòng đời, dọn dẹp và tái kiểm định'));
c.push(T([2800, 6500], ['Sự kiện', 'Hành động'], [
  ['Nguồn hãng có phiên bản mới', 'Nhập hộ chiếu mới (E1); báo diff; không đụng phiên bản đã pin'],
  ['Errata mới', 'E2/E9 → K2′ chờ duyệt; kg.impact cho mã dùng ngoại vi bị ảnh hưởng'],
  ['Fact bị thay thế', 'Giữ superseded; mã trích dẫn → stale; Feature liên quan → cần tái kiểm định (G4 lại)'],
  ['Skill đổi', 'Chạy lại benchmark; huy hiệu cũ hết hiệu lực cho phiên bản skill mới'],
  ['Cache đầy', 'Xóa L-E theo LRU; không ảnh hưởng L-A…L-D'],
  ['Hộ chiếu không còn dự án nào pin', 'Được phép xóa khỏi L-A (có xác nhận)'],
  ['K7 quá lớn', 'Nén thành tổng hợp theo tháng; bản ghi gốc lưu trữ nén, hash giữ nguyên'],
]));
c.push(SP());
c.push(H2('6.8. Chia sẻ và quyền riêng tư theo loại'));
c.push(T([1200, 2300, 5800], ['Loại', 'Mặc định', 'Khi đóng gói .hkp'], [
  ['K1, K2', 'Công khai (nếu license nguồn cho phép)', 'Fact + con trỏ nguồn + hash; không kèm tài liệu; trường license bắt buộc'],
  ['K2′, K4', 'Cộng đồng/tổ chức', 'Đóng gói được với nguồn là báo cáo/ghi chú; PDF bên thứ ba chỉ con trỏ'],
  ['K3', 'Riêng tư (IP mạch)', 'Chỉ đóng gói khi chủ mạch chọn; có thể ẩn net không liên quan'],
  ['K5', 'Cộng đồng', 'Đóng gói kèm benchmark và huy hiệu'],
  ['K6', 'Riêng tư', 'Không đóng gói'],
  ['K7', 'Riêng tư', 'Chỉ tổng hợp ẩn danh (tỷ lệ CF/BF/BC theo mô hình) nếu người dùng bật'],
  ['K8', 'Tổ chức', 'Không đóng gói (trừ mẫu chính sách)'],
]));
c.push(SP());

c.push(H2('6.9. Hiển thị và truy hồi: bản đồ tri thức và RAG (v1.1)'));
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
c.push(H1('7. Ví dụ xuyên suốt: BME280 trên WeAct BlackPill F411'));
c.push(T([1300, 3200, 4800], ['Bước', 'Tri thức và con đường', 'Kết quả trong hệ thống'], [
  ['1', 'K1 armv7e-m từ hkw-packs; K2 st.stm32f411@1.1.0 qua E1 (SVD)', 'L-A: 13.439 fact vàng, reviewed; pin trong constraints.yaml'],
  ['2', 'K3 từ .kicad_sch qua E3', 'BoardPassport weact.blackpill-f411: net I2C1_SCL = U1.PB6 ↔ U2.SCL; SDO→GND'],
  ['3', 'K4 BME280 từ PDF qua E10 (tìm) → G-SRC → E2 → G-FACT', 'Overlay bosch.bme280@0.3.0: địa chỉ 0x76 (bạc, reviewed, trang 27 bbox…), bảng thanh ghi'],
  ['4', 'K5 skill armv7e-m/i2c.md (E6, đã benchmark)', 'Composer C3 nạp skill; Coder sinh driver với hkw:fact cho 0x76, CR1.PE…'],
  ['5', 'K6: STEP "đọc nhiệt độ", FEATURES failing → G1, G3', 'Mã merge có CITES tới fact K2/K3/K4'],
  ['6', 'E5: nạp (G-OPS), serial đọc nhiệt độ, G4', 'Feature passing, EVIDENCED_BY log hash; badge verified_on_board cho hộ chiếu mạch'],
  ['7', 'K7: một lỗi NACK ban đầu → DebugSession chỉ ra pull-up thiếu', 'Sổ lỗi + đề xuất K2′? Không — đề xuất K3 (thêm ràng buộc pull-up) qua G-FACT'],
  ['8', 'Đóng gói K4 + K5 thành .hkp (không kèm K3, K6)', 'Registry nội bộ: bosch.bme280@0.3.0 với badge và benchmark theo mô hình'],
]));
c.push(SP());

c.push(H1('8. Ánh xạ tới hiện trạng M0 và bước tiếp theo'));
c.push(T([2200, 3400, 3700], ['Thành phần tri thức', 'Đã có trong M0 (hkw-core)', 'Cần làm ở M1–M2'], [
  ['K2 qua E1', 'Parser SVD (derivedFrom, dim, cluster, enum) và ATDF; 640 chip gieo hạt; store SQLite với tier/status/supersedes; predicate nhiều giá trị', 'EDC/.PIC, binding YAML, header C; phiên bản hóa hộ chiếu theo SVD version'],
  ['Provenance', 'Source (sha256, kind, tier, license), Fact.locator (xpath), ledger ghi mọi write', 'bbox/page cho PDF; người xác nhận qua UI'],
  ['Xung đột và thay thế', 'Merge theo tier; conflict table; supersede(); kg.impact()', 'UI giải quyết mâu thuẫn; overlay tách lớp L-B (hiện gộp trong store)'],
  ['Đồ thị', 'HAS/CITES/SUPERSEDES/CONFLICTS_WITH/USES; conflicts(), impact(), neighborhood()', 'APPLIES_TO, EVIDENCED_BY, CONNECTS (K3, K5, K7)'],
  ['K9 kiểm soát', 'Validator hai lớp; SchemaCompiler mẫu số chung; router khác hãng', 'constant-guard trên CodePatch (M1)'],
  ['K7', 'Ledger lượt gọi mô hình (chi phí, token, hash)', 'debug_session, tool_report, badges, decision_log, discovery (M1–M3)'],
  ['K5′, K10 (v1.1)', 'Chưa có', 'M1: registry templates, requirement/module/adr/diagram/doc_artifact; view.kg_map, rag_index (M1); diagram.sync, doc.sync (M3)'],
]));
c.push(SP());
c.push(H1('9. Rủi ro riêng của kiến trúc tri thức'));
c.push(T([3000, 6300], ['Rủi ro', 'Biện pháp'], [
  ['Lõi và overlay lẫn nhau khi cùng một store', 'Tách vật lý L-A/L-B từ M1: cột `layer` trong fact + store riêng cho ref; truy vấn resolve theo thứ tự lớp'],
  ['Người duyệt "duyệt cho xong" fact bạc', 'Duyệt theo nhóm có ảnh cắt bắt buộc; ghi người duyệt; kiểm định board là điều kiện cho badge, không phải duyệt'],
  ['Overlay cộng đồng sai lan rộng', 'Overlay không bao giờ ghi đè lõi; gói overlay có chữ ký và huy hiệu; dự án pin phiên bản overlay'],
  ['K7 phình to và vô nghĩa', 'Chỉ ghi khi có bằng chứng (ToolReport/log hash); tổng hợp theo tháng; đề xuất K5 chỉ khi mẫu lặp ≥ n lần'],
  ['License nguồn không rõ', 'Trường license bắt buộc ở Source; gói thiếu license bị registry từ chối; PDF không phân phối lại'],
]));
c.push(SP());
// refs: KAD-specific first two, then common
const { Paragraph, TextRun, AlignmentType } = require('docx');
const extra = [
  'I. Nonaka and H. Takeuchi, The Knowledge-Creating Company. Oxford University Press, 1995 (phân biệt tri thức tường minh/ẩn; nền cho tách tri thức tuyên bố và thủ tục).',
  'W3C, "PROV-DM: The PROV Data Model," W3C Recommendation, 2013. [Online]. Available: https://www.w3.org/TR/prov-dm/',
];
const { REFS } = require('./eide_common');
c.push(H1('Tài liệu tham khảo'));
[...extra, ...REFS].forEach((r, i) => c.push(new Paragraph({ children: [new TextRun({ text: `[${i + 1}] ${r}`, font: 'Times New Roman', size: 24 })], alignment: AlignmentType.LEFT, spacing: { line: 276, after: 100 }, indent: { left: 567, hanging: 567 } })));
build(m, c, 'EIDE-KAD-07_Kien_truc_tri_thuc.docx');
