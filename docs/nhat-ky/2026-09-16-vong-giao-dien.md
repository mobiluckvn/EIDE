# Một vòng EIDE qua giao diện — 16/09/2026

*Chạy bằng `GEditorApp --vong-giao-dien`: mỗi bước gọi ĐÚNG hàm mà một cú bấm chuột gọi —
`chonManEide` cho sidebar, `chayNhuNguoiDung` cho nút Chạy của biểu mẫu, `moTepTuCay` cho cú bấm
vào tệp. Chạy cùng chuỗi ấy bằng CLI thì đo được lõi và KHÔNG đo được thứ đã hỏng nhiều nhất
trong dự án này: chỗ nối giữa giao diện và lõi.*

*Dự án: `~/eide/doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino` — ATmega328P, có firmware thật
(`build/fw.elf`) và kịch bản mô phỏng. Ảnh từng bước: `anh-vong-16-09/buoc-NN.png`.*

## Ba lỗi lộ ra, cả ba đã sửa trong cùng buổi

| # | Lỗi | Vì sao không bộ test nào bắt được |
|---|---|---|
| 1 | **Màn Nhật ký bị thay bằng Bản đồ tri thức** — tiêu đề ghi "Nhật ký đầy đủ", thân hiện "Bản đồ tri thức" | Do chính tôi gây ra ở DEV-115 hôm trước: `napMacDinh("NhatKy")` là `view.timeline`, mà `view.timeline` nằm trong `nangLucBanDo`, nên phép định tuyến theo năng lực kéo màn sang khung bản đồ. Mỗi phần đều có test riêng và đều xanh |
| 2 | **Bản đồ ĐÈ LÊN mọi màn mở sau nó** — "Mô hình & chi phí" và "Hành trình & cổng" đều hiện thân của bản đồ dưới tiêu đề của chính chúng | `_moTheoTenMan` ẩn mọi màn trong `bangMan` nhưng `banDo` không nằm trong bảng ấy (nó là khung thứ HAI của màn 7). Chỉ lộ ra khi đi QUA NHIỀU màn liên tiếp — mà không bài test nào làm thế |
| 3 | **`info` là màu ĐỎ** nên "chi phí hôm nay 0.0000 USD" hiện như một cảnh báo | Cặp `info`/`infoBg` khai chữ đỏ trên nền XANH: nền đã nói đúng ý định thiết kế, chỉ chữ đi lạc sang màu thương hiệu. Và `info` đỏ chỉ cách `bad` 1,83 lần tương phản — hai trạng thái ngược nhau gần như cùng màu |

Lỗi 1 và 2 cùng một họ: **`banDo` là khung nhìn duy nhất không nằm trong bảng màn**, nên mọi vòng
lặp "cho mọi màn" đều bỏ sót nó. Đó là cái giá của việc màn 7 có hai khung, và cái giá ấy không
hiện ra cho tới khi có người đi hết một vòng.

Một lỗi thứ tư nằm ở PHÉP ĐO chứ không ở sản phẩm: bảng kiểm kê ghi "0 dòng" cho màn Hộ chiếu
đang hiện **290 fact**, vì nó hỏi `soDong` bằng cách ép kiểu về `ManHinhCoSo` — mà ba màn tri
thức viết trước lớp cơ sở nên không kế thừa nó. `soDong` nay nằm trong giao thức `KhungNhinEide`.

---

Máy: GEditor 0.0.1 · arm64 · SIMD: neon · Bản tải trực tiếp
Dự án: /Users/congvt/eide/doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino

## 1. Mở dự án — cửa sổ dựng xong, cột điều hướng có mặt

- ✅ dự án `doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino` · panel sẵn sàng
- 3001 ms
- ảnh: `buoc-01.png`

## 2. Tổng quan dự án — bấm mục đầu trên sidebar

- ✅ 1 dòng
- 3011 ms
- ảnh: `buoc-02.png`

## 3. Môi trường — máy này có gì

- ✅ 7 dòng · 1 bảng
- 4001 ms
- ảnh: `buoc-03.png`

## 4. Nhập tài liệu — trích fact từ một header C

- ✅ 1 dòng
- 7006 ms
- ảnh: `buoc-04.png`

## 5. Hộ chiếu chip — tra fact vừa trích

- ✅ 290 dòng · 1 bảng
- 4001 ms
- ảnh: `buoc-05.png`

## 6. Bản đồ tri thức — đồ thị dựng từ store

- ✅ 2 dòng · 1 cây
- 5002 ms
- ảnh: `buoc-06.png`

## 7. Xung đột tri thức — hai nguồn nói khác nhau

- ✅ 0 dòng
- 4000 ms
- ảnh: `buoc-07.png`

## 8. Mã nguồn — mở một tệp, xem dấu tri thức ở lề

- ✅ main.c · 0 dòng có fact · 11 dòng vi phạm constant-guard
- 8024 ms
- ảnh: `buoc-08.png`

## 9. Mô phỏng — chạy firmware thật nếu dự án có

- ✅ 7 dòng · 1 khối mã
- 92006 ms
- ảnh: `buoc-09.png`

## 10. Nhật ký — mọi việc vừa làm có vào sổ cái không

- ✅ 465 dòng
- 5000 ms
- ảnh: `buoc-10.png`

## 11. Mô hình & chi phí — tiêu bao nhiêu trong vòng này

- ✅ 2 dòng
- 4002 ms
- ảnh: `buoc-11.png`

## 12. Hành trình & cổng — chính sách đã quyết những gì

- ✅ 10 dòng
- 4001 ms
- ảnh: `buoc-12.png`

---

**12/12 bước chạy được** · tổng 144.5 s
