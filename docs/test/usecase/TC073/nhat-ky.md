# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** tạo dự án — “dịch vụ LLM quá tải”

**Tác tử trả lời** *(sau 0.7 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `dich-vu-llm-qua-tai` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
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

**Tôi (người dùng):** Tóm tắt lại dự án này

**Tác tử trả lời** *(sau 32.8 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `dich-vu-llm-qua-tai` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Tóm tắt lại dự án này  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tóm tắt lại dự án này  bước 1/5  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/5 bước, 1 bước cần anh trả lời  → mở màn Yêu cầu & kiến trúc (tác tử đang chạy `arch.decompose`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tóm tắt lại dự án này. Tôi sẽ arch.decompose.  1. `arch.decompose`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  arch.decompose  Dựa trên những yêu cầu nào?  style   …hoặc gõ câu trả lời cho các mục trên Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: nhấp nháy LED và đo dòng tiêu thụ trên ESP32-C3 Gửi 
```

**Màn đang mở — `ReqArch`:**

```
Màn này đang rỗng — vì: chưa có yêu cầu nào — chưa có hiện vật nào thuộc loại này trong store  Bước kế tiếp: ra lệnh cho tác tử ở vùng trao đổi; `req.elicit` → `req.classify` ghi yêu cầu xuống store  
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 2 tab tác tử đã mở:** Main, ReqArch

### Tab `Main`

```
Tổng quan  project.status · target.detect  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  TÍNH NĂNG  Chưa có tính năng nào trong hồ sơ — `plan.define_feature` ghi tính năng xuống store; 0 passing trên 0 tổng.  ĐANG CHỜ TÔI — 3 mục  LOẠI	CHỖ XỬ LÝ	VÌ SAO
Cần làm rõ	THIẾU THÔNG TIN	Kế hoạch `view.ask` đang chờ: Tài liệu kiến trúc hiện tại của hệ thống dịch vụ LLM
Cần làm rõ	THIẾU THÔNG TIN	Bước `arch.decompose` đang chờ anh cho biết:
• Dựa trên những yêu cầu nào? (`reqset_ids`)
• `style`
Cần làm rõ	THIẾU THÔNG TIN	Kế hoạch `view.ask` đang chờ: Yêu cầu chi tiết và ngữ cảnh cụ thể của tính năng view.ask
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
Phiên	s_b74dc596a557
Mở lúc	23/09 07:50:48
Tự chủ hiệu lực	A2
Dừng khẩn	tắt
Lượt trao đổi	2
Mục hoàn tác	0
Chưa có dữ liệu	permits, board (DEV-110)
  NGÂN SÁCH MÔ HÌNH  MỤC	GIÁ TRỊ
Hôm nay	0.0075 USD
Hạn ngày	5.00 USD
Số lời gọi	2
```

![Main](man-01-Main.png)

### Tab `ReqArch`

```
Yêu cầu & kiến trúc  arch.adr · arch.compare · arch.decompose · +17 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Màn này đang rỗng — vì: chưa có yêu cầu nào — chưa có hiện vật nào thuộc loại này trong store  Bước kế tiếp: ra lệnh cho tác tử ở vùng trao đổi; `req.elicit` → `req.classify` ghi yêu cầu xuống store  
```

![ReqArch](man-02-ReqArch.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (3)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Kế hoạch `view.ask` đang chờ: Tài liệu kiến trúc hiện tại của hệ thống dịch vụ LLM  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `arch.decompose` đang chờ anh cho biết:
• Dựa trên những yêu cầu nào? (`reqset_ids`)
• `style`  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Kế hoạch `view.ask` đang chờ: Yêu cầu chi tiết và ngữ cảnh cụ thể của tính năng view.ask  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC  Chưa có mục nào trong cửa sổ hoàn tác.  ⟩ 
```

**Tác tử trả lời** *(sau 4.6 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `dich-vu-llm-qua-tai` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Dự án đã sẵn sàng. Ba thứ cần biết, hết:
1. Ô lệnh ngay dưới đây — gõ một câu tiếng Việt; câu mẫu đang nằm sẵn trong ô.
2. ⌘K mở bảng lệnh — tìm 223 năng lực và 25 màn theo tên hoặc mô tả.
3. Nút ■ Dừng khẩn ở góc trên phải — cắt mọi việc đang chạy, ở bất kỳ lúc nào.  Tóm tắt lại dự án này  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tóm tắt lại dự án này  bước 1/5  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/5 bước, 1 bước cần anh trả lời  → mở màn Yêu cầu & kiến trúc (tác tử đang chạy `arch.decompose`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tóm tắt lại dự án này. Tôi sẽ arch.decompose.  1. `arch.decompose`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  arch.decompose  Dựa trên những yêu cầu nào?  style   …hoặc gõ câu trả lời cho các mục trên Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: robot hai bánh tự cân bằng trên ATmega328P Gửi 
```

**Màn đang mở — `ReqArch`:**

```
Màn này đang rỗng — vì: chưa có yêu cầu nào — chưa có hiện vật nào thuộc loại này trong store  Bước kế tiếp: ra lệnh cho tác tử ở vùng trao đổi; `req.elicit` → `req.classify` ghi yêu cầu xuống store  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC073`.