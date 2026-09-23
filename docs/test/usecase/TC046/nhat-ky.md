# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “không có linh kiện tương đương”

**Tác tử trả lời** *(sau 0.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `khong-co-linh-kien-tuong-duong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.   Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó Gửi 
```

**Màn đang mở — `Main`:**

```
(màn trống)
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì

**Tác tử trả lời** *(sau 12.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `khong-co-linh-kien-tuong-duong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì  bước 2/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/4 bước, 2 bước cần anh trả lời  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Bản đồ tri thức & hỏi đáp mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  KẾT QUẢ TỪNG BƯỚC  1. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  TÁC TỬ HỎI  ·  ingest.index_text  files   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART Gửi 
```

**Màn đang mở — `Main`:**

```
TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `ingest.index_text` đang chờ anh cho biết:
• `files`
 PHẦN CỨNG ĐÃ GHIM  MỤC	GIÁ TRỊ
Chip	<null>
Board	<null>
ISA	chưa biết — tác tử sẽ hỏi khi cần
Hộ chiếu	CHƯA CÓ — nhập datasheet/ATDF ở màn Nhập tài liệu (S3)
  TÁC TỬ VỪA LÀM XONG  LÚC	VIỆC
—	`project.status`
—	`view.artifacts`
—	`project.status`
  PHIÊN LÀM VIỆC  MỤC	GIÁ TRỊ
Phiên	s_3f3e5ace489c
Mở lúc	23/09 13:10:21
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0010 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 3 tab tác tử đã mở:** Main, Ingest, Graph

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `ingest.index_text` đang chờ anh cho biết:
• `files`
 PHẦN CỨNG ĐÃ GHIM  MỤC	GIÁ TRỊ
Chip	<null>
Board	<null>
ISA	chưa biết — tác tử sẽ hỏi khi cần
Hộ chiếu	CHƯA CÓ — nhập datasheet/ATDF ở màn Nhập tài liệu (S3)
  TÁC TỬ VỪA LÀM XONG  LÚC	VIỆC
—	`project.status`
—	`view.artifacts`
—	`project.status`
  PHIÊN LÀM VIỆC  MỤC	GIÁ TRỊ
Phiên	s_3f3e5ace489c
Mở lúc	23/09 13:10:21
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0010 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![Main](man-01-Main.png)

### Tab `Ingest`

```
Nhập tài liệu  archive.extract_one · archive.list · archive.query · +27 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Kéo PDF · SVD · ATDF · netlist · BOM vào đây  Màn này đang rỗng — vì: chưa nhập tài liệu nào vào dự án này  Bước kế tiếp: kéo PDF/SVD/BOM vào vùng trên, hoặc chạy `eide ingest <tệp>` ở dòng lệnh  
```

![Ingest](man-02-Ingest.png)

### Tab `Graph`

```
Bản đồ tri thức & hỏi đáp  view.artifacts · view.conflict_board · view.coverage_map · +9 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.   Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![Graph](man-03-Graph.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (1)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `ingest.index_text` đang chờ anh cho biết:
• `files`  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (1)  view.rag_index  còn 23 giờ  Hoàn tác ⟩ 
```

**Tác tử trả lời** *(sau 6.9 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `khong-co-linh-kien-tuong-duong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì  bước 2/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/4 bước, 2 bước cần anh trả lời  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Bản đồ tri thức & hỏi đáp mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tìm thay thế cho SEN42 — con này đặc thù, nếu không có pin-to-pin thì nói rõ phải sửa mạch và firmware những gì. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  KẾT QUẢ TỪNG BƯỚC  1. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  TÁC TỬ HỎI  ·  ingest.index_text  files   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC046`.