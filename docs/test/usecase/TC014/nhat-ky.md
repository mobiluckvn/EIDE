# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “đọc application note tải về”

**Tác tử trả lời** *(sau 0.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `doc-application-note-tai-ve` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
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

**Tôi (người dùng):** Đọc tệp /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/an-note-xyz.md và cho tôi biết trị số trở kéo lên I2C mà tài liệu này khuyến nghị

**Tác tử trả lời** *(sau 9.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `doc-application-note-tai-ve` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Đọc tệp /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/an-note-xyz.md và cho tôi biết trị số trở kéo lên I2C mà tài liệu này khuyến nghị  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Đọc tệp /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/an-note-xyz.md và cho tôi biết trị số trở kéo lên I2C mà   bước 4/4  Mở chi tiết Dừng khẩn ✅ Xong 4/4 bước  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Bản đồ tri thức & hỏi đáp mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: trị số trở kéo lên I2C mà tài liệu này khuyến nghị. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `ingest.index_text` — 1 indexed  Xem đầy đủ ▾ {
  "indexed" : 1
}  2. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  3. `view.rag_ask` —  answer · 0 citations · 1 not_found · tr_2be9a6f8a1bc trace_id  Xem đầy đủ ▾ {
  "answer" : "",
  "citations" : [
  ],
  "not_found" : true,
  "trace_id" : "tr_2be9a6f8a1bc"
}  4. `chat.report_back` — 6 trường report · 247 ký tự text  Xem đầy đủ ▾ {
  "report" : {
    "cost" : 0.001126,
    "done" : [
      "project.open",
      "view.artifacts",
      "view.artifacts",
      "view.timeline",
      "project.status",
      "chat.parse_intent",
      "chat.ground",
      "chat.fill_defaults",
      "ingest.index_text",
      "view.rag_index",
      "view.rag_ask"
    ],
    "ra" : [
    ],
    "run_id" : "r_6c5388783283",
    "undo" : [
      "74566a35ad6a"
    ],
    "waiting" : [
    ]
  },
  "text" : "Đã làm 11 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, ingest.index_text, view.rag_index, view.rag_ask\nHoàn tác được 1 mục đến 2026-09-24T11:04.\nChi phí mô hình: 0.0011 USD."
}  Lượt chạy xong.  Đã làm 16 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, ingest.index_text, view.rag_index, view.rag_ask, chat.report_back, chat.orchestrate, chat.restate
→ `ingest.index_text` làm ra: 1 indexed — xem ở màn Nhập tài liệu.
→ `view.rag_index` làm ra: 0 chunks — xem ở màn Bản đồ tri thức & hỏi đáp.
→ `view.rag_ask` làm ra:  answer; 0 source_id; tr_2be9a6f8a1bc trace_id; True not_found — xem ở màn Bản đồ tri thức & hỏi đáp.
→ `chat.report_back` làm ra: 6 trường report; 247 ký tự text — xem ở màn mặc định.
Hoàn tác được 1 mục đến 2026-09-24T11:04.
Chi phí mô hình: 0.0011 USD.   Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó Gửi 
```

**Màn đang mở — `Main`:**

```
TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 0 mục  Không việc nào chờ anh.  PHẦN CỨNG ĐÃ GHIM  MỤC	GIÁ TRỊ
Chip	<null>
Board	<null>
ISA	chưa biết — tác tử sẽ hỏi khi cần
Hộ chiếu	CHƯA CÓ — nhập datasheet/ATDF ở màn Nhập tài liệu (S3)
  TÁC TỬ VỪA LÀM XONG  LÚC	VIỆC
—	`project.status`
—	`view.artifacts`
—	`project.status`
  PHIÊN LÀM VIỆC  MỤC	GIÁ TRỊ
Phiên	s_b61e613b83ae
Mở lúc	23/09 11:04:39
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0011 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 3 tab tác tử đã mở:** Main, Ingest, Graph

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 0 mục  Không việc nào chờ anh.  PHẦN CỨNG ĐÃ GHIM  MỤC	GIÁ TRỊ
Chip	<null>
Board	<null>
ISA	chưa biết — tác tử sẽ hỏi khi cần
Hộ chiếu	CHƯA CÓ — nhập datasheet/ATDF ở màn Nhập tài liệu (S3)
  TÁC TỬ VỪA LÀM XONG  LÚC	VIỆC
—	`project.status`
—	`view.artifacts`
—	`project.status`
  PHIÊN LÀM VIỆC  MỤC	GIÁ TRỊ
Phiên	s_b61e613b83ae
Mở lúc	23/09 11:04:39
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0011 USD
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
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI  Trống — không việc nào chờ anh.  HOÀN TÁC ĐƯỢC (1)  view.rag_index  còn 23 giờ  Hoàn tác ⟩ 
```

**Tác tử trả lời** *(sau 6.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `doc-application-note-tai-ve` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Đọc tệp /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/an-note-xyz.md và cho tôi biết trị số trở kéo lên I2C mà tài liệu này khuyến nghị  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Đọc tệp /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/an-note-xyz.md và cho tôi biết trị số trở kéo lên I2C mà   bước 4/4  Mở chi tiết Dừng khẩn ✅ Xong 4/4 bước  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Bản đồ tri thức & hỏi đáp mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: trị số trở kéo lên I2C mà tài liệu này khuyến nghị. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `ingest.index_text` — 1 indexed  Xem đầy đủ ▾ {
  "indexed" : 1
}  2. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  3. `view.rag_ask` —  answer · 0 citations · 1 not_found · tr_2be9a6f8a1bc trace_id  Xem đầy đủ ▾ {
  "answer" : "",
  "citations" : [
  ],
  "not_found" : true,
  "trace_id" : "tr_2be9a6f8a1bc"
}  4. `chat.report_back` — 6 trường report · 247 ký tự text  Xem đầy đủ ▾ {
  "report" : {
    "cost" : 0.001126,
    "done" : [
      "project.open",
      "view.artifacts",
      "view.artifacts",
      "view.timeline",
      "project.status",
      "chat.parse_intent",
      "chat.ground",
      "chat.fill_defaults",
      "ingest.index_text",
      "view.rag_index",
      "view.rag_ask"
    ],
    "ra" : [
    ],
    "run_id" : "r_6c5388783283",
    "undo" : [
      "74566a35ad6a"
    ],
    "waiting" : [
    ]
  },
  "text" : "Đã làm 11 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, ingest.index_text, view.rag_index, view.rag_ask\nHoàn tác được 1 mục đến 2026-09-24T11:04.\nChi phí mô hình: 0.0011 USD."
}  Lượt chạy xong.  Đã làm 16 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, ingest.index_text, view.rag_index, view.rag_ask, chat.report_back, chat.orchestrate, chat.restate
→ `ingest.index_text` làm ra: 1 indexed — xem ở màn Nhập tài liệu.
→ `view.rag_index` làm ra: 0 chunks — xem ở màn Bản đồ tri thức & hỏi đáp.
→ `view.rag_ask` làm ra:  answer; 0 source_id; tr_2be9a6f8a1bc trace_id; True not_found — xem ở màn Bản đồ tri thức & hỏi đáp.
→ `chat.report_back` làm ra: 6 trường report; 247 ký tự text — xem ở màn mặc định.
Hoàn tác được 1 mục đến 2026-09-24T11:04.
Chi phí mô hình: 0.0011 USD.   Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC014`.