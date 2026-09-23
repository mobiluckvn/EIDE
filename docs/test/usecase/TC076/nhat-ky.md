# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “công cụ trả log rỗng”

**Tác tử trả lời** *(sau 0.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `cong-cu-tra-log-rong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
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

**Tôi (người dùng):** Chạy mô phỏng cho dự án này rồi kết luận đạt hay không đạt

**Tác tử trả lời** *(sau 7.4 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `cong-cu-tra-log-rong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Chạy mô phỏng cho dự án này rồi kết luận đạt hay không đạt  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Chạy mô phỏng cho dự án này rồi kết luận đạt hay không đạt  bước 1/1  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/1 bước, 1 bước cần anh trả lời  → Mô phỏng mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ sim.run.  1. `sim.run`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.run  artifact  Chạy kịch bản mô phỏng nào?   …hoặc gõ câu trả lời cho các mục trên Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: robot hai bánh tự cân bằng trên ATmega328P Gửi 
```

**Màn đang mở — `Main`:**

```
TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `sim.run` đang chờ anh cho biết:
• `artifact`
• Chạy kịch bản mô phỏng nào? (`scenario`)
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
Phiên	s_e1a8552267e9
Mở lúc	23/09 07:52:36
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0008 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 2 tab tác tử đã mở:** Main, Sim

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 1 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Bước `sim.run` đang chờ anh cho biết:
• `artifact`
• Chạy kịch bản mô phỏng nào? (`scenario`)
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
Phiên	s_e1a8552267e9
Mở lúc	23/09 07:52:36
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0008 USD
Hạn ngày	5.00 USD
Số lời gọi	1
```

![Main](man-01-Main.png)

### Tab `Sim`

```
Mô phỏng  sim.build_platform · sim.mock_peripheral · sim.model_plant · +3 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![Sim](man-02-Sim.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (1)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `sim.run` đang chờ anh cho biết:
• `artifact`
• Chạy kịch bản mô phỏng nào? (`scenario`)  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC  Chưa có mục nào trong cửa sổ hoàn tác.  ⟩ 
```

**Tác tử trả lời** *(sau 4.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `cong-cu-tra-log-rong` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Chạy mô phỏng cho dự án này rồi kết luận đạt hay không đạt  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Chạy mô phỏng cho dự án này rồi kết luận đạt hay không đạt  bước 1/1  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/1 bước, 1 bước cần anh trả lời  → Mô phỏng mở ở NỀN — anh vừa tự chọn màn khác chưa quá 20 giây (§2C.3). Tab đã thêm, cột trái đang nháy.  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ sim.run.  1. `sim.run`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.run  artifact  Chạy kịch bản mô phỏng nào?   …hoặc gõ câu trả lời cho các mục trên Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: robot hai bánh tự cân bằng trên ATmega328P Gửi 
```

**Màn đang mở — `Sim`:**

```
NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC076`.