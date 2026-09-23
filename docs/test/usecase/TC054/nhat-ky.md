# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “giảm dòng tiêu thụ chế độ chờ”

**Tác tử trả lời** *(sau 0.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `giam-dong-tieu-thu-che-do-cho` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
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

**Tôi (người dùng):** Firmware ATmega328P của tôi tốn 12 mA ở chế độ chờ. Giảm xuống và cho tôi số đo trước/sau

**Tác tử trả lời** *(sau 7.6 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `giam-dong-tieu-thu-che-do-cho` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Firmware ATmega328P của tôi tốn 12 mA ở chế độ chờ. Giảm xuống và cho tôi số đo trước/sau  Đã nhận (ý hiểu: `big_command`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Firmware ATmega328P của tôi tốn 12 mA ở chế độ chờ. Giảm xuống và cho tôi số đo trước/sau  bước 2/23  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/23 bước, 1 bước cần anh trả lời  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là big_command: giảm dòng tiêu thụ ở chế độ chờ. Tôi sẽ project.create, archive.list, env.check.  1. `project.create`  2. `archive.list`  3. `env.check`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `archive.list` HỎNG — E2000: Không có tệp /Users/congvt/Documents/EIDE/docs/test/usecase/TC054/du-an/giam-dong-tieu-thu-che-do-cho/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c  KẾT QUẢ TỪNG BƯỚC  1. `project.create` — 1 created · 0 existing · 137 ký tự path · firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c project_id  Xem đầy đủ ▾ {
  "created" : true,
  "existing" : [
  ],
  "next" : [
    "project.set_target"
  ],
  "path" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC054\/du-an\/giam-dong-tieu-thu-che-do-cho\/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c",
  "project_id" : "firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c"
}  TÁC TỬ HỎI  ·  env.check  Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ)  armv7e-m   — STM32F[2-4], STM32L4, nRF52, SAMD5 avr8   — ATmega, ATtiny, AVR(64|128) rv32imac   — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: robot hai bánh tự cân bằng trên ATmega328P Gửi 
```

**Màn đang mở — `Main`:**

```
TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 2 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V
Cần làm rõ	THIẾU THÔNG TIN	Bước `archive.list` dừng: Không có tệp /Users/congvt/Documents/EIDE/docs/test/usecase/TC054/du-an/giam-dong-tieu-thu-che-do-cho/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c
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
Phiên	s_7c2c2f6c81d7
Mở lúc	23/09 07:44:27
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0009 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 3 tab tác tử đã mở:** Main, Ingest, Env

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 2 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V
Cần làm rõ	THIẾU THÔNG TIN	Bước `archive.list` dừng: Không có tệp /Users/congvt/Documents/EIDE/docs/test/usecase/TC054/du-an/giam-dong-tieu-thu-che-do-cho/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c
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
Phiên	s_7c2c2f6c81d7
Mở lúc	23/09 07:44:27
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0009 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![Main](man-01-Main.png)

### Tab `Ingest`

```
Nhập tài liệu  archive.extract_one · archive.list · archive.query · +27 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Kéo PDF · SVD · ATDF · netlist · BOM vào đây  Màn này đang rỗng — vì: chưa nhập tài liệu nào vào dự án này  Bước kế tiếp: kéo PDF/SVD/BOM vào vùng trên, hoặc chạy `eide ingest <tệp>` ở dòng lệnh  
```

![Ingest](man-02-Ingest.png)

### Tab `Env`

```
Môi trường  env.check · env.detect · env.guide_install · +4 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![Env](man-03-Env.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (2)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `env.check` đang chờ anh cho biết:
• Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ) (`isa`)
   Chọn một: armv7e-m — STM32F[2-4], STM32L4, nRF52, SAMD5; avr8 — ATmega, ATtiny, AVR(64|128); rv32imac — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `archive.list` dừng: Không có tệp /Users/congvt/Documents/EIDE/docs/test/usecase/TC054/du-an/giam-dong-tieu-thu-che-do-cho/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (1)  project.create  còn 23 giờ  Hoàn tác ⟩ 
```

**Tác tử trả lời** *(sau 6.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `giam-dong-tieu-thu-che-do-cho` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Firmware ATmega328P của tôi tốn 12 mA ở chế độ chờ. Giảm xuống và cho tôi số đo trước/sau  Đã nhận (ý hiểu: `big_command`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Firmware ATmega328P của tôi tốn 12 mA ở chế độ chờ. Giảm xuống và cho tôi số đo trước/sau  bước 2/23  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/23 bước, 1 bước cần anh trả lời  → Nhập tài liệu mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  → Môi trường mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là big_command: giảm dòng tiêu thụ ở chế độ chờ. Tôi sẽ project.create, archive.list, env.check.  1. `project.create`  2. `archive.list`  3. `env.check`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `archive.list` HỎNG — E2000: Không có tệp /Users/congvt/Documents/EIDE/docs/test/usecase/TC054/du-an/giam-dong-tieu-thu-che-do-cho/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c  KẾT QUẢ TỪNG BƯỚC  1. `project.create` — 1 created · 0 existing · 137 ký tự path · firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c project_id  Xem đầy đủ ▾ {
  "created" : true,
  "existing" : [
  ],
  "next" : [
    "project.set_target"
  ],
  "path" : "\/Users\/congvt\/Documents\/EIDE\/docs\/test\/usecase\/TC054\/du-an\/giam-dong-tieu-thu-che-do-cho\/firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c",
  "project_id" : "firmware-atmega328p-cua-toi-ton-12-ma-o-che-do-c"
}  TÁC TỬ HỎI  ·  env.check  Chip của thiết bị thuộc kiến trúc tập lệnh nào? (cần để chọn chuỗi công cụ)  armv7e-m   — STM32F[2-4], STM32L4, nRF52, SAMD5 avr8   — ATmega, ATtiny, AVR(64|128) rv32imac   — ESP32-?C[0-9], ESP32-?H[0-9], GD32V, CH32V  …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đọc cảm biến BME280 qua I2C, in nhiệt độ qua UART Gửi 
```

**Màn đang mở — `Env`:**

```
Màn này đang rỗng — vì: dự án chưa ghim ISA — `env.check` kiểm chuỗi công cụ THEO ISA, không theo máy  Bước kế tiếp: ghim chip ở màn Hộ chiếu chip (S5) — `project.set_target` suy ISA từ `family_patterns` của manifest  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC054`.