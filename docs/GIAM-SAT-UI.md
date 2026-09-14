# Giám sát và tham gia — từng tác vụ hiện lên giao diện thế nào

*Bản phân tích 14/09/2026, viết để chủ sản phẩm duyệt TRƯỚC khi hiện thực. Cột "hôm nay" đo từ
mã: `EidePanel.nhanSuKien`, 23 khung nhìn trong `EIDEKit`, `SU_KIEN` trong `rpc.py`,
`ledger_events.json`.*

Yêu cầu: *"toàn bộ các tính năng khi hoạt động cần được show lên giao diện để người dùng có thể
giám sát và tham gia vào quá trình nếu muốn"*.

Mỗi tác vụ dưới đây trả lời bốn câu: **hiện cái gì**, **hiện ở đâu và dưới dạng gì**, **người
làm được gì** (hay chỉ xem), và **hôm nay thiếu gì**.

---

## 0. Hai điều kiện nền — không có thì cả tài liệu này vô nghĩa

### 0.1. Giao diện phải thấy việc của tiến trình khác

`Ledger.theo_doi()` chỉ gọi hàm quan sát trong `Ledger.append()` — tức **chỉ cho bản ghi do
chính tiến trình ấy ghi**. Phiên AVR hôm nay: tác tử chạy 28 lời gọi năng lực, ghi 105 sự kiện
vào đúng `ledger.jsonl` của dự án, và một cửa sổ EIDE đang mở **không hiện một dòng nào**.

Mọi ô "có" trong các bảng dưới đều ngầm hiểu là *khi chính giao diện gọi năng lực*. Khi tác tử
làm — tức đúng tình huống bạn muốn giám sát — chúng thành "không".

**Sửa:** daemon theo dõi TỆP `ledger.jsonl` (một luồng đọc phần đuôi), phát `event.*` cho mọi
bản ghi mới bất kể ai ghi. Sổ cái vốn đã là nơi mọi hành vi đi qua và có chuỗi băm chống sửa,
nên nối giao diện vào đó biến "giám sát" thành tính chất của kiến trúc.

### 0.2. Giao diện phải mở được dự án

`EideDaemonLauncher.moClient()` chạy `eide daemon` **không có `-p`**, và cả hai chỗ gọi nó đều
dùng mặc định. Daemon không thuộc dự án nào, nên mọi màn đọc dữ liệu dự án đều rỗng — rỗng *vì
không có dự án*, không phải vì chưa có dữ liệu.

**Sửa:** menu **Tệp → Mở dự án EIDE…** + danh sách gần đây từ `project.list`; mở dự án là khởi
động lại daemon với `-p` (vì `ctx.project_dir` quyết lúc daemon chạy).

---

## A. Khởi động dự án

### A1 · Tạo hoặc mở dự án
**Năng lực:** `project.create` · `project.open` · `project.list` · `project.status`

| | |
|---|---|
| **Hiện gì** | Tên dự án, đường dẫn, đích đã ghim (chip/board/ISA), số tính năng, trạng thái store |
| **Hiện thế nào** | Màn **Tổng quan dự án** — danh sách nhãn-giá trị; tên dự án lên thanh tiêu đề cửa sổ |
| **Người làm gì** | **Tham gia:** chọn dự án để mở, tạo dự án mới bằng câu tiếng Việt trong ô lệnh |
| **Hôm nay** | Màn có, dữ liệu có — **nhưng không mở được dự án nào** (§0.2). `project.list` không gắn màn nào (`EidePanel.noUI`) |

### A2 · Tác tử hiểu ý định và hỏi lại
**Năng lực:** `chat.parse_intent` · `chat.clarify` · `chat.orchestrate`

| | |
|---|---|
| **Hiện gì** | Câu hỏi làm rõ của tác tử; **cách nó hiểu yêu cầu** (restate); chuỗi năng lực nó định chạy |
| **Hiện thế nào** | Thẻ trong dòng hội thoại. `RestateCard` hiện câu hiểu kèm nút; câu hỏi hiện dạng bong bóng chờ trả lời |
| **Người làm gì** | **Tham gia:** trả lời trực tiếp; bấm **"Sửa ý hiểu"** để nạp câu hiểu vào ô lệnh và sửa trước khi gửi |
| **Hôm nay** | Có — `event.chat.question`, `event.chat.restated` đã nối. **Thiếu:** chuỗi năng lực dự định chạy không hiện ra trước, nên người không biết tác tử sắp làm gì cho tới lúc nó làm xong |

---

## B. Thu nhận tri thức

### B1 · Tìm nguồn tài liệu hãng
**Năng lực:** `search.vendor` · `search.rank` · `search.registry`

| | |
|---|---|
| **Hiện gì** | Danh sách ứng viên: URL, hãng, loại (svd/atdf/pdf), **tầng dự kiến** (vàng/bạc), license, điểm xếp hạng và **lý do được điểm** |
| **Hiện thế nào** | Bảng trong màn **Nhập tài liệu**, sắp theo điểm giảm dần; tầng hiện bằng màu |
| **Người làm gì** | **Tham gia:** chọn nguồn nào để tải (hôm nay tác tử tự chọn nguồn đầu bảng) |
| **Hôm nay** | **Thiếu hẳn.** `search.vendor` chạy xong trả JSON ra terminal; không màn nào hiện danh sách ứng viên. Đây là chỗ người dùng có ý kiến rõ nhất — họ biết trang nào của hãng là thật |

### B2 · Tải nguồn — cổng G-SRC
**Năng lực:** `search.fetch`

| | |
|---|---|
| **Hiện gì** | URL, kích thước, license, băm SHA-256, **quy tắc cổng đã khớp** (G-SRC-01/04/05/99) và lý do |
| **Hiện thế nào** | Nếu ASK: một mục trong **Hàng đợi** kèm nguyên văn lý do. Nếu APPROVE: một dòng trong nhật ký hoạt động |
| **Người làm gì** | **Tham gia:** **Duyệt** / **Từ chối** kèm ghi chú. Ghi chú đi vào sổ cái (`gate.human`) |
| **Hôm nay** | Có, và **đã dùng thật** — hai mục duyệt trong phiên AVR. **Thiếu:** không thấy tiến trình tải (gói DFP 35 MB tải 12,8 giây trong im lặng) |

### B3 · Nhập và phân loại tài liệu
**Năng lực:** `ingest.classify` · `ingest.hash_dedupe` · `archive.list` · `archive.query` · `archive.extract_one`

| | |
|---|---|
| **Hiện gì** | Cây tệp trong kho nén, tệp nào được nhận diện là gì, tầng gán cho từng tệp, tệp trùng đã bỏ |
| **Hiện thế nào** | Màn **Nhập tài liệu** — cây thư mục, 50 mục đầu, phần còn lại gộp thành "… và N mục nữa" |
| **Người làm gì** | **Chỉ xem** (đủ). Kéo thả tài liệu vào ô lệnh là đường vào |
| **Hôm nay** | Có và khá đầy đủ |

### B4 · Trích fact
**Năng lực:** `extract.svd` · `extract.atdf` · `extract.header_c` · `extract.pdf_*` · `extract.bom` · `extract.code_constants`

| | |
|---|---|
| **Hiện gì** | Số fact rút được, tầng (vàng/bạc/đồng), **số fact confidence thấp**, xung đột phát hiện, số trang/bbox cho fact từ PDF, hằng số không nguồn |
| **Hiện thế nào** | Màn **Nhập tài liệu** đã có 15 loại kết quả `extract.*`; nên bổ sung **thanh tiến trình** vì đây là việc nặng (ESP32-C3: 8.169 fact) |
| **Người làm gì** | **Chỉ xem** trong lúc chạy; **tham gia** ở bước duyệt fact (B6) |
| **Hôm nay** | Kết quả có; **tiến trình không** — `extract.svd` chạy vài chục giây và màn hình đứng yên |

### B5 · Dựng đồ thị tri thức
**Năng lực:** `kg.build` · `view.kg_map` · `view.coverage_map`

| | |
|---|---|
| **Hiện gì** | Số nút / số cạnh, **độ phủ theo ngoại vi** (ngoại vi nào dưới 50% hiện trước), xung đột |
| **Hiện thế nào** | Màn **Bản đồ tri thức** — đồ thị, xung đột đặt TRÊN đồ thị, độ phủ ghi ở tiêu đề |
| **Người làm gì** | **Tham gia:** bấm vào một nút để xem fact và nguồn của nó |
| **Hôm nay** | Có |

### B6 · Duyệt fact — cổng G-FACT
**Năng lực:** `kg.review_facts`

| | |
|---|---|
| **Hiện gì** | Với mỗi fact chờ duyệt: chủ thể, vị từ, giá trị, **nguồn + trang/bbox**, tầng, confidence, và **vì sao nó bị hỏi** (confidence thấp / mâu thuẫn / từ OCR / là fact điện-timing) |
| **Hiện thế nào** | Hàng đợi, gom theo lô trích xuất. Fact đã tự duyệt hiện dạng đếm ("8.125 tự duyệt"), fact cần người hiện từng cái |
| **Người làm gì** | **Tham gia:** duyệt / từ chối từng fact. **KHÔNG duyệt hàng loạt** — [DEV-050](DEVIATIONS.md): duyệt một chồng mục lẫn nhiều cổng là biến cổng thành con dấu |
| **Hôm nay** | Hàng đợi có; **thiếu** phần hiện fact kèm trích dẫn ngay tại chỗ duyệt — người phải tin con số mà không thấy nguồn |

### B7 · Xung đột tri thức
**Năng lực:** `kg.conflicts` · `kg.resolve_conflict`

| | |
|---|---|
| **Hiện gì** | Hai fact mâu thuẫn đặt cạnh nhau, mỗi bên kèm nguồn và tầng; hệ quả nếu chọn sai |
| **Hiện thế nào** | **Bảng xung đột** — hai cột song song, không phải một danh sách |
| **Người làm gì** | **Tham gia:** chọn bên nào đúng (T3 — người làm, tác tử chỉ chuẩn bị) |
| **Hôm nay** | `kg.conflicts` **không gắn màn nào** (`EidePanel.noUI`). Đây là khoảng trống đáng kể: xung đột là đúng thứ cần người |

### B8 · Tra cứu và hỏi đáp
**Năng lực:** `passport.query` · `view.rag_ask` · `view.rag_trace` · `passport.resolve_address`

| | |
|---|---|
| **Hiện gì** | Fact kèm **trích dẫn bắt buộc**, tầng, độ trễ so với hứa 200 ms; câu trả lời RAG kèm đoạn nguồn |
| **Hiện thế nào** | Màn **Hộ chiếu chip** và **Bản đồ tri thức & hỏi đáp** |
| **Người làm gì** | **Tham gia:** gõ câu hỏi; bấm trích dẫn để mở nguồn |
| **Hôm nay** | Có. `RagAskView` **từ chối hiện câu trả lời không có trích dẫn** — đúng thiết kế |

---

## C. Thiết kế

### C1 · Ghim đích
**Năng lực:** `project.set_target`

| | |
|---|---|
| **Hiện gì** | Chip, board, **ISA suy ra**, những thứ còn thiếu (ví dụ "hộ chiếu board cho arduino-uno") |
| **Hiện thế nào** | Màn **Tổng quan** — dòng "Đích" |
| **Người làm gì** | **Tham gia:** sửa đích; **khai `f_cpu`** và các tham số dựng ([DEV-104](DEVIATIONS.md)) |
| **Hôm nay** | Hiện có; **thiếu** ô sửa — hôm nay phải sửa `.eide/constraints.yaml` bằng tay |

### C2 · Yêu cầu và kiến trúc
**Năng lực:** `req.*` (8) · `arch.*` (11)

| | |
|---|---|
| **Hiện gì** | Yêu cầu theo mức ưu tiên, xung đột giữa các yêu cầu, kiểu kiến trúc đã chọn **kèm lý do**, ngân sách RAM/thời gian, máy trạng thái, ADR |
| **Hiện thế nào** | Màn **Yêu cầu & kiến trúc** |
| **Người làm gì** | **Tham gia:** đổi ưu tiên M↔S, chọn phương án kiến trúc (T1* — tác tử tự làm khi có bằng chứng, không thì hỏi) |
| **Hôm nay** | Màn có; **thiếu** nút đổi ưu tiên và chọn phương án — hiện chỉ xem |

### C3 · Lược đồ
**Năng lực:** `diagram.*` (14)

| | |
|---|---|
| **Hiện gì** | Ảnh lược đồ, **số lỗi lint**, cờ "LỖI THỜI" khi mã đã đổi sau khi vẽ, neo vào đâu |
| **Hiện thế nào** | Màn **Lược đồ** — ảnh + cảnh báo phía trên |
| **Người làm gì** | **Chỉ xem** (đủ) |
| **Hôm nay** | Có, và có phần khó: nó **từ chối cho chèn lược đồ còn lỗi vào tài liệu** |

### C4 · Lập kế hoạch — cổng G1
**Năng lực:** `plan.create` · `plan.define_feature` · `plan.replan`

| | |
|---|---|
| **Hiện gì** | Các bước, thứ tự, phụ thuộc, **vòng phụ thuộc nếu có**, tri thức còn thiếu cho từng bước, ràng buộc, phần mã sẽ bị chạm |
| **Hiện thế nào** | Màn **Kế hoạch & mã** — danh sách bước đánh số, thiếu sót màu đỏ |
| **Người làm gì** | **Tham gia:** duyệt kế hoạch trước khi nó chạy (G1) |
| **Hôm nay** | Có |

---

## D. Sinh mã và dựng

### D1 · Sinh và sửa mã
**Năng lực:** `code.generate` · `code.patch` · `code.self_repair` · `code.constant_guard`

| | |
|---|---|
| **Hiện gì** | Bản vá theo tệp/dòng, **hằng số phần cứng không trỏ về fact nào** (cổng G-FACT chặn), kết quả tự sửa |
| **Hiện thế nào** | Màn **Mã nguồn** + diff trong màn **Kế hoạch & mã** |
| **Người làm gì** | **Tham gia:** đọc diff, duyệt/từ chối merge |
| **Hôm nay** | Có. `CodeView` coi `verdict: block` là chặn thật |

### D2 · Dựng firmware — việc nặng
**Năng lực:** `code.build`

| | |
|---|---|
| **Hiện gì** | **Đang chạy lệnh gì**, thời gian trôi, mã thoát, dòng lỗi trình dịch, đường dẫn artifact |
| **Hiện thế nào** | `RunProgressCard` — thẻ tiến trình gom theo `run_id`, năm trạng thái năm ký hiệu |
| **Người làm gì** | **Tham gia:** **Huỷ** (`job.cancel`) |
| **Hôm nay** | Thẻ tiến trình có, nút huỷ có. **Thiếu:** `tool.report` không lên UI, nên mã thoát và log chỉ thấy trong terminal |

### D3 · Đo kích thước và ngân sách
**Năng lực:** `code.size` · `arch.memory_budget`

| | |
|---|---|
| **Hiện gì** | flash/ram dùng bao nhiêu **trên giới hạn của chip** (lấy từ fact `memory_size`), phần trăm, so với lần dựng trước, ký hiệu chiếm nhiều nhất |
| **Hiện thế nào** | Màn **Mã nguồn** — thanh ngang, cảnh báo vàng ở 85% |
| **Người làm gì** | **Chỉ xem** (đủ) |
| **Hôm nay** | Có |

### D4 · Kiểm tĩnh và test
**Năng lực:** `code.static` · `code.test_host` · `code.review`

| | |
|---|---|
| **Hiện gì** | Vi phạm theo tệp:dòng, mức nghiêm trọng, test đạt/hỏng |
| **Hiện thế nào** | Màn **Mã nguồn** |
| **Người làm gì** | **Chỉ xem**; bấm vào dòng để mở tệp trong màn Mã nguồn |
| **Hôm nay** | Có; **thiếu** liên kết bấm-để-mở |

### D5 · Merge — cổng G3
**Năng lực:** `code.merge`

| | |
|---|---|
| **Hiện gì** | Commit, nhánh, **bốn cổng công cụ đã qua**, reviewer, **hạn hoàn tác** |
| **Hiện thế nào** | Màn **Kế hoạch & mã** |
| **Người làm gì** | **Tham gia:** duyệt merge; **hoàn tác** trong hạn |
| **Hôm nay** | Có, kể cả trường hợp hợp đồng không trả `undo_until` thì nói rõ "không rõ hạn rút lại" |

---

## E. Mô phỏng

### E1 · Dựng nền tảng
**Năng lực:** `sim.build_platform` · `sim.mock_peripheral`

| | |
|---|---|
| **Hiện gì** | Engine chọn (và **có phải fallback không**), vùng nhớ kèm `fact_ids`, ngoại vi **có mô hình** / **chưa có mô hình**, kênh quan sát engine thật sự có |
| **Hiện thế nào** | Màn **Mô phỏng** |
| **Người làm gì** | **Tham gia:** yêu cầu mock cho một ngoại vi chưa có |
| **Hôm nay** | Có |

### E2 · Chạy kịch bản
**Năng lực:** `sim.scenario` · `sim.run` · `sim.sweep`

| | |
|---|---|
| **Hiện gì** | **UART thật theo thời gian thực**, bảng expect ↔ kết quả ba trạng thái (đạt / hỏng / **chưa kiểm được**), lý do từng dòng chưa kiểm được |
| **Hiện thế nào** | Màn **Mô phỏng** — khung console cuộn + bảng kết quả |
| **Người làm gì** | **Tham gia:** dừng lượt chạy; sửa kịch bản rồi chạy lại |
| **Hôm nay** | Bảng kết quả có và phân biệt đúng `unverified` với `failed`. **Thiếu:** UART chỉ hiện sau khi chạy xong — lượt AVR mất 25 giây im lặng rồi mới đổ ra một lần |

---

## F. Phần cứng *(chưa làm được — cần board)*

| Tác vụ | Hiện gì | Người làm gì | Hôm nay |
|---|---|---|---|
| **F1** Dò board (`discover.*`) | Cổng, VID/PID, probe, quyền truy cập | Chọn board để gắn vào dự án | Màn có, **trạng thái rỗng nói đúng lý do** ("năng lực chưa hiện thực" ≠ "chưa có dữ liệu") |
| **F2** Nạp firmware (`target.flash`) — G-OPS | Board đích, artifact, băm, **board đã đánh dấu lab chưa** | **Duyệt** (R3 luôn hỏi người) | Khung có; `board.mark_lab` **cố ý** đòi người xác nhận, panel không tự điền |
| **F3** Serial / log (`serial.*`) | Dòng serial thời gian thực, bất thường | Gửi lệnh, lọc | `event.serial.line` khai trong openrpc, **panel chưa xử lý** |
| **F4** Gỡ lỗi probe (`debug.*`) | Breakpoint, biến, vết | Đặt breakpoint | Màn có, chờ board |

---

## G. Xuyên suốt — phần quan trọng nhất cho giám sát

### G1 · Tác tử gọi mô hình
**Sổ cái:** `model.call`, `context.bundle`

| | |
|---|---|
| **Hiện gì** | Vai trò (`librarian`/`planner`/`coder`…), mô hình, token vào/ra, **chi phí**, độ trễ, gom theo ngày |
| **Hiện thế nào** | Màn **Chi phí mô hình** — bảng gom theo vai trò + biểu đồ theo ngày. **Không hiện nội dung prompt**: ngữ cảnh có thể chứa mã nguồn của bạn |
| **Người làm gì** | **Tham gia:** đặt hạn mức ngày; đổi hồ sơ mô hình |
| **Hôm nay** | **Thiếu hẳn.** `model.call` không map lên UI. Màn `Models` có khung nhưng đọc `models.yaml` (cấu hình) chứ không đọc sổ cái (thực tế) — nên nó nói tác tử *được phép* dùng gì, không nói nó *đã* dùng gì |

### G2 · Cổng hỏi người
**Sổ cái:** `gate.decision` (ASK), `gate.human`

| | |
|---|---|
| **Hiện gì** | Cổng nào, quy tắc nào, lý do nguyên văn, năng lực gì, tham số gì, **hệ quả nếu duyệt** |
| **Hiện thế nào** | **Hàng đợi luôn hiện** (UXD-13 U2), hai danh sách tách bạch: *chờ tôi* và *đã làm — hoàn tác được* |
| **Người làm gì** | **Tham gia:** duyệt / từ chối kèm ghi chú |
| **Hôm nay** | Có. **Thiếu:** quyết định APPROVE và REJECT **không lên UI** (`gate.decision` chỉ phát khi ASK) — nên người không thấy tác tử *tự duyệt* những gì, mà đó chính là thứ cần giám sát nhất ở mức tự chủ cao |

### G3 · Việc nặng đang chạy
**Năng lực:** 12 năng lực trong `CAP_NANG` · `job.status` · `job.cancel`

| | |
|---|---|
| **Hiện gì** | Việc gì, phần trăm, thời gian trôi, đang ở bước nào |
| **Hiện thế nào** | `RunProgressCard` gom theo `run_id`; năm trạng thái năm ký hiệu |
| **Người làm gì** | **Tham gia:** Huỷ |
| **Hôm nay** | Có |

### G4 · Hoàn tác
**Sổ cái:** `undo.register`, `undo.apply`, `undo.expire`

| | |
|---|---|
| **Hiện gì** | Việc đã làm, loại hoàn tác, **hạn còn lại** |
| **Hiện thế nào** | Danh sách thứ hai của hàng đợi — "đã làm, hoàn tác được" |
| **Người làm gì** | **Tham gia:** Hoàn tác |
| **Hôm nay** | Có; `undo.apply` không lên UI nên hoàn tác ở tiến trình khác không phản ánh |

### G5 · Leo thang và dừng khẩn
**Sổ cái:** `policy.escalate`, `stop`, `autonomy.change`

| | |
|---|---|
| **Hiện gì** | Tác tử đang **dừng chờ người** vì lý do gì; mức tự chủ hiện tại |
| **Hiện thế nào** | **Thanh tự chủ luôn hiện** (U2). Leo thang nên là **thông báo nổi**, không phải một dòng lẫn trong hội thoại |
| **Người làm gì** | **Tham gia:** **Dừng khẩn** (nút đỏ) · **đổi mức tự chủ A0…A4** |
| **Hôm nay** | Thanh có, dừng khẩn có. **Thiếu hai thứ:** `policy.escalate` không lên UI; **không có đường đổi mức tự chủ** — muốn đổi A2↔A3 phải sửa `.eide/autonomy.yaml` bằng tay, trong khi đó là núm điều khiển chính của cả APD-08 |

### G6 · Môi trường và công cụ ngoài
**Sổ cái:** `tool.report` · **Năng lực:** `env.check` · `env.install`

| | |
|---|---|
| **Hiện gì** | Công cụ nào có/thiếu, **phiên bản thật**, đạt ngưỡng không, lệnh cài gợi ý; với mỗi lượt chạy: mã thoát, thời gian, đường dẫn log |
| **Hiện thế nào** | Màn **Môi trường** (trạng thái) + màn **Công cụ ngoài** mới (lịch sử chạy) |
| **Người làm gì** | **Tham gia:** bấm cài (R4 — luôn hỏi người); mở log |
| **Hôm nay** | Màn Môi trường có. **Thiếu:** `tool.report` không lên UI — build/size/sim chạy xong chỉ thấy JSON trong terminal |

### G7 · Nhật ký hoạt động *(màn mới)*

| | |
|---|---|
| **Hiện gì** | Dòng thời gian **mọi** sự kiện sổ cái: thời điểm, loại, năng lực, tóm tắt, ai làm (tác tử / người) |
| **Hiện thế nào** | Dòng thời gian cuộn ngược, **lọc theo loại**, tìm theo `run_id`; trạng thái chuỗi băm ở đầu màn |
| **Người làm gì** | **Chỉ xem** — nhưng bấm một dòng thì nhảy tới màn chuyên đề tương ứng |
| **Hôm nay** | **Không có màn nào trả lời được câu "tác tử vừa làm gì"** |

---

## Tổng kết — 13 khoảng trống, xếp theo mức chặn

| # | Khoảng trống | Chặn gì |
|---|---|---|
| 1 | Giao diện mù trước việc tiến trình khác (§0.1) | **Mọi thứ** |
| 2 | Không mở được dự án (§0.2) | **Mọi màn có dữ liệu** |
| 3 | Không có màn nhật ký hoạt động (G7) | Câu hỏi "tác tử vừa làm gì" |
| 4 | `tool.report` không lên UI (G6, D2) | Kết quả build/sim/size |
| 5 | `model.call` không lên UI (G1) | Chi phí token |
| 6 | APPROVE/REJECT của cổng không lên UI (G2) | Giám sát việc tác tử **tự duyệt** |
| 7 | `policy.escalate` không lên UI (G5) | Biết tác tử đang cần người |
| 8 | Không đổi được mức tự chủ (G5) | Núm điều khiển chính của APD-08 |
| 9 | Ứng viên nguồn không hiện (B1) | Người chọn nguồn |
| 10 | Xung đột tri thức không có màn (B7) | Đúng thứ cần người quyết |
| 11 | Fact chờ duyệt không kèm trích dẫn (B6) | Duyệt mà không thấy nguồn |
| 12 | UART hiện sau khi chạy xong (E2) | Theo dõi mô phỏng |
| 13 | Không sửa được đích/ưu tiên từ UI (C1, C2) | Tham gia vào thiết kế |

## Điều KHÔNG đề xuất

- **Không** duyệt hàng loạt ([DEV-050](DEVIATIONS.md)) — biến cổng chính sách thành con dấu.
- **Không** đưa `policy.sign` vào giao diện — nó cố ý là LỆNH chứ không phải năng lực; S47:
  tác tử tự thêm nguồn tin cậy → REJECT G-WL-02. Một nút trong UI thì ranh giới ấy mất.
- **Không** hiện nội dung prompt gửi mô hình — sổ cái đã che khoá API, nhưng ngữ cảnh có thể
  chứa mã nguồn người dùng; màn chi phí cần con số, không cần văn bản.
- **Không** để panel tự điền `board.mark_lab` — đánh dấu lab mở quyền tự nạp firmware, và hai
  điều kiện của nó chỉ người cầm board mới biết.
