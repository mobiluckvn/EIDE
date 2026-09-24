# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “bộ chuyển LAN sang USB cho TV”

**Tác tử trả lời** *(sau 0.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `bo-chuyen-lan-sang-usb-cho-tv` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 224 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.   Mô tả việc cần làm bằng một câu tiếng Việt — tôi rút ra yêu cầu từ đó Gửi 
```

**Màn đang mở — `Main`:**

```
(màn trống)
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Làm bộ chuyển LAN sang USB, cắm vào TV, copy phim qua mạng LAN vào đó để TV xem

**Tác tử trả lời** *(sau 8.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `bo-chuyen-lan-sang-usb-cho-tv` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 224 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Làm bộ chuyển LAN sang USB, cắm vào TV, copy phim qua mạng LAN vào đó để TV xem  Đã nhận (ý hiểu: `project.create`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Làm bộ chuyển LAN sang USB, cắm vào TV, copy phim qua mạng LAN vào đó để TV xem  bước 3/14  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 2/14 bước, 1 bước cần anh trả lời  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là project.create: lam-bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-. Tôi sẽ project.create, search.reference_projects, env.check.  1. `project.create`  2. `search.reference_projects`  3. `env.check`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `project.create` — 1 created · 0 existing · 137 ký tự path · bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua- project_id  Xem đầy đủ ▾ {
  "created" : true,
  "existing" : [
  ],
  "next" : [
    "search.reference_projects"
  ],
  "path" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC001\/du-an\/bo-chuyen-lan-sang-usb-cho-tv\/bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua-",
  "project_id" : "bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua-"
}  2. `search.reference_projects` — 0 templates  Xem đầy đủ ▾ {
  "templates" : [
  ]
}  TÁC TỬ HỎI  ·  env.check  Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ)  armv7e-m   — STM32F[2-4], STM32L4, nRF52, SAMD5 avr8   — ATmega, ATtiny, AVR(64|128) rv32imac   — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: robot hai bánh tự cân bằng trên ATmega328P Gửi 
```

**Màn đang mở — `Main`:**

```
TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V
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
Phiên	s_37db6781ac4a
Mở lúc	24/09 00:04:14
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

**Quét 2 tab tác tử đã mở:** Main, Env

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V
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
Phiên	s_37db6781ac4a
Mở lúc	24/09 00:04:14
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

### Tab `Env`

```
Môi trường  env.check · env.detect · env.guide_install · +4 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![Env](man-02-Env.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (1)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (1)  project.create  còn 23 giờ  Hoàn tác ⟩ 
```

**Tác tử trả lời** *(sau 4.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `bo-chuyen-lan-sang-usb-cho-tv` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 224 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Làm bộ chuyển LAN sang USB, cắm vào TV, copy phim qua mạng LAN vào đó để TV xem  Đã nhận (ý hiểu: `project.create`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Làm bộ chuyển LAN sang USB, cắm vào TV, copy phim qua mạng LAN vào đó để TV xem  bước 3/14  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 2/14 bước, 1 bước cần anh trả lời  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là project.create: lam-bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-. Tôi sẽ project.create, search.reference_projects, env.check.  1. `project.create`  2. `search.reference_projects`  3. `env.check`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  KẾT QUẢ TỪNG BƯỚC  1. `project.create` — 1 created · 0 existing · 137 ký tự path · bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua- project_id  Xem đầy đủ ▾ {
  "created" : true,
  "existing" : [
  ],
  "next" : [
    "search.reference_projects"
  ],
  "path" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC001\/du-an\/bo-chuyen-lan-sang-usb-cho-tv\/bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua-",
  "project_id" : "bo-chuyen-lan-sang-usb-cam-vao-tv-copy-phim-qua-"
}  2. `search.reference_projects` — 0 templates  Xem đầy đủ ▾ {
  "templates" : [
  ]
}  TÁC TỬ HỎI  ·  env.check  Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ)  armv7e-m   — STM32F[2-4], STM32L4, nRF52, SAMD5 avr8   — ATmega, ATtiny, AVR(64|128) rv32imac   — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART Gửi 
```

**Màn đang mở — `Env`:**

```
Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC001`.