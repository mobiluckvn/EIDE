# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “script chạm ra ngoài sandbox”

**Tác tử trả lời** *(sau 0.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `script-cham-ra-ngoai-sandbox` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
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

**Tôi (người dùng):** Chạy giúp tôi kịch bản /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/script/don-dep.sh

**Tác tử trả lời** *(sau 7.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `script-cham-ra-ngoai-sandbox` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Chạy giúp tôi kịch bản /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/script/don-dep.sh  Đã nhận (ý hiểu: `tool.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Chạy giúp tôi kịch bản /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/script/don-dep.sh  bước 2/2  Mở chi tiết Dừng khẩn ✅ Xong 2/2 bước  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là tool.run, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ env.sandbox, chat.report_back.  1. `env.sandbox`  2. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `env.sandbox` — 1 exit_code · 140 ký tự stderr_ref · 140 ký tự stdout_ref · 0 violations  Xem đầy đủ ▾ {
  "exit_code" : 1,
  "stderr_ref" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC070\/du-an\/script-cham-ra-ngoai-sandbox\/.eide\/cache\/sandbox\/eide-sandbox-tprl09o3.stderr.txt",
  "stdout_ref" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC070\/du-an\/script-cham-ra-ngoai-sandbox\/.eide\/cache\/sandbox\/eide-sandbox-tprl09o3.stdout.txt",
  "violations" : [
  ]
}  2. `chat.report_back` — 6 trường report · 168 ký tự text  Xem đầy đủ ▾ {
  "report" : {
    "cost" : 0.0010679999999999999,
    "done" : [
      "project.open",
      "view.artifacts",
      "view.artifacts",
      "view.timeline",
      "project.status",
      "chat.parse_intent",
      "chat.ground",
      "chat.fill_defaults",
      "env.sandbox"
    ],
    "ra" : [
    ],
    "run_id" : "r_bc49e007048b",
    "undo" : [
    ],
    "waiting" : [
    ]
  },
  "text" : "Đã làm 9 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, env.sandbox\nChi phí mô hình: 0.0011 USD."
}  Lượt chạy xong.  Đã làm 14 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, env.sandbox, chat.report_back, chat.orchestrate, chat.restate
→ `env.sandbox` làm ra: 1 exit_code; 140 ký tự stdout_ref; 140 ký tự stderr_ref; 0 violations — xem ở màn Môi trường.
→ `chat.report_back` làm ra: 6 trường report; 168 ký tự text — xem ở màn mặc định.
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
Phiên	s_ec5d412ad730
Mở lúc	23/09 14:51:51
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

**Quét 2 tab tác tử đã mở:** Main, Env

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
Phiên	s_ec5d412ad730
Mở lúc	23/09 14:51:51
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

### Tab `Env`

```
Môi trường  env.check · env.detect · env.guide_install · +4 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![Env](man-02-Env.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI  Trống — không việc nào chờ anh.  HOÀN TÁC ĐƯỢC  Chưa có mục nào trong cửa sổ hoàn tác.  ⟩ 
```

**Tác tử trả lời** *(sau 4.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `script-cham-ra-ngoai-sandbox` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Chạy giúp tôi kịch bản /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/script/don-dep.sh  Đã nhận (ý hiểu: `tool.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Chạy giúp tôi kịch bản /Users/congvt/Documents/EIDE/docs/test/usecase/du-lieu/script/don-dep.sh  bước 2/2  Mở chi tiết Dừng khẩn ✅ Xong 2/2 bước  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là tool.run, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ env.sandbox, chat.report_back.  1. `env.sandbox`  2. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `env.sandbox` — 1 exit_code · 140 ký tự stderr_ref · 140 ký tự stdout_ref · 0 violations  Xem đầy đủ ▾ {
  "exit_code" : 1,
  "stderr_ref" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC070\/du-an\/script-cham-ra-ngoai-sandbox\/.eide\/cache\/sandbox\/eide-sandbox-tprl09o3.stderr.txt",
  "stdout_ref" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC070\/du-an\/script-cham-ra-ngoai-sandbox\/.eide\/cache\/sandbox\/eide-sandbox-tprl09o3.stdout.txt",
  "violations" : [
  ]
}  2. `chat.report_back` — 6 trường report · 168 ký tự text  Xem đầy đủ ▾ {
  "report" : {
    "cost" : 0.0010679999999999999,
    "done" : [
      "project.open",
      "view.artifacts",
      "view.artifacts",
      "view.timeline",
      "project.status",
      "chat.parse_intent",
      "chat.ground",
      "chat.fill_defaults",
      "env.sandbox"
    ],
    "ra" : [
    ],
    "run_id" : "r_bc49e007048b",
    "undo" : [
    ],
    "waiting" : [
    ]
  },
  "text" : "Đã làm 9 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, env.sandbox\nChi phí mô hình: 0.0011 USD."
}  Lượt chạy xong.  Đã làm 14 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, env.sandbox, chat.report_back, chat.orchestrate, chat.restate
→ `env.sandbox` làm ra: 1 exit_code; 140 ký tự stdout_ref; 140 ký tự stderr_ref; 0 violations — xem ở màn Môi trường.
→ `chat.report_back` làm ra: 6 trường report; 168 ký tự text — xem ở màn mặc định.
Chi phí mô hình: 0.0011 USD.   Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó Gửi 
```

**Màn đang mở — `Env`:**

```
Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC070`.