# Một vòng EIDE qua giao diện — 16/09/2026

*Chạy bằng `GEditorApp --vong-giao-dien`: mỗi bước gọi ĐÚNG hàm mà một cú bấm chuột gọi. Vòng
cuối 14/14 bước, 270 s, trên `~/eide/doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino` (ATmega328P,
firmware thật). Ảnh: `anh-vong-16-09/buoc-NN.png`.*

## Bảy lỗi lộ ra trong các vòng chạy, tất cả đã sửa

| # | Lỗi | Vì sao không bộ test nào bắt được |
|---|---|---|
| 1 | Màn **Nhật ký** bị thay bằng Bản đồ tri thức — tiêu đề đúng, thân sai | Do bản sửa DEV-115 hôm trước: `napMacDinh("NhatKy")` là `view.timeline`, mà năng lực ấy nằm trong `nangLucBanDo`. Mỗi phần có test riêng và đều xanh |
| 2 | **Bản đồ đè lên mọi màn mở sau nó** | `_moTheoTenMan` duyệt `bangMan` để ẩn, mà `banDo` là khung thứ HAI của màn 7 nên không nằm trong bảng. Chỉ lộ khi đi qua nhiều màn liên tiếp |
| 3 | `info` là màu **ĐỎ** nên "chi phí 0.0000 USD" đọc như cảnh báo | Cặp `info`/`infoBg` khai chữ đỏ trên nền XANH — nền nói đúng ý định thiết kế, chữ đi lạc sang màu thương hiệu |
| 4 | **Thẻ tiến độ không bao giờ biến mất**, và mang nhãn là mã băm | 15 thẻ đã xong xếp chồng, kéo cửa sổ lên 4048 px. Thẻ nằm NGOÀI vùng cuộn của hội thoại nên mỗi thẻ cộng thẳng vào chiều cao cửa sổ |
| 5 | **Cửa sổ phình và không co lại**: 720 → 836 → 1009 pt | `PassportView` (viết trước `ManHinhCoSo`) không có vùng cuộn, và biểu mẫu sáu ô đòi 203 pt bắt buộc. AppKit phóng cửa sổ để thoả ràng buộc rồi để nguyên |
| 6 | Đóng màn xong, **biểu mẫu của màn cũ vẫn nằm trên đầu hội thoại** | `dongMan` không chạm `oNhap` |
| 7 | **Ô lệnh biến mất khi mở bất kỳ màn nào** | USECASE UC-B1 nói "một ô lệnh luôn gõ được, không phải một màn" — và hiện thực làm ngược: muốn nói một câu phải BỎ màn đang xem |

## Hai nguyên tắc chủ sản phẩm chốt trong buổi, đã hiện thực

1. **Vùng trao đổi người–máy là BẤT BIẾN.** Hội thoại không bao giờ bị nén về 0; màn chuyên đề
   là thứ đến rồi đi. Trước đó tôi đã sửa sai hai lần theo hướng ngược lại — lần đầu giấu hẳn
   hội thoại khi mở màn, lần sau thu gọn còn ô gõ.
2. **Tác tử làm tới phần nào thì màn ấy TỰ MỞ và được FOCUS.** Sidebar sáng theo, không chỉ đổi
   nội dung — nội dung một đằng điều hướng một nẻo thì người dùng mất dấu mình đang ở đâu. Có
   giữ 20 giây cho màn người vừa tự chọn: một giao diện tự đổi màn dưới tay người đang đọc là
   giao diện không dùng được.

Đo được ở bước 11: đang đứng ở màn `Môi trường`, tác tử chạy `passport.query`, màn `Hộ chiếu
chip` tự mở.

---

## 1. Mở dự án — cửa sổ dựng xong, cột điều hướng có mặt

- ✅ dự án `doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino` · panel sẵn sàng
- 3000 ms
- cửa sổ 720 pt · Auto Layout đòi 122 pt
- ảnh: `buoc-01.png`

## 2. Tổng quan dự án — bấm mục đầu trên sidebar

- ✅ 1 dòng
- 3015 ms
- cửa sổ 720 pt · Auto Layout đòi 601 pt
- ảnh: `buoc-02.png`

## 3. Môi trường — máy này có gì

- ✅ 7 dòng · 1 bảng
- 4000 ms
- cửa sổ 720 pt · Auto Layout đòi 608 pt
- ảnh: `buoc-03.png`

## 4. Nhập tài liệu — trích fact từ một header C

- ✅ 1 dòng
- 7003 ms
- cửa sổ 720 pt · Auto Layout đòi 608 pt
- ảnh: `buoc-04.png`

## 5. Hộ chiếu chip — tra fact vừa trích

- ✅ 290 dòng · 1 bảng
- 4001 ms
- cửa sổ 826 pt · Auto Layout đòi 826 pt
- đòi nhiều nhất: NSTableView đòi 1022 (đang có 1022) · NSView đòi 826 (đang có 826) · EidePanel đòi 826 (đang có 826)
- con của panel: AutonomyBar 34/34 · ChatView 290/290 · EideVungPhai 0/792 · NSStackView 19/19 · EideONhap 203/203 · PassportView 24/200 · RagAskView 80/200 (ẩn) · DocView 63/200 (ẩn) · ProjectStatusView 65/200 (ẩn) · IngestView 65/200 (ẩn) · BoardView 65/200 (ẩn) · ReqArchView 65/200 (ẩn) · DiagramView 65/200 (ẩn) · PlanDiffView 65/200 (ẩn) · CodeView 65/200 (ẩn) · SimView 65/200 (ẩn) · DiscoveryView 65/200 (ẩn) · LogAssistView 65/200 (ẩn) · DebugView 65/200 (ẩn) · BenchView 65/200 (ẩn) · ToolForgeView 65/200 (ẩn) · RegistryView 65/200 (ẩn) · ModelsView 65/200 (ẩn) · EnvView 65/200 (ẩn) · FlowMapView 65/200 (ẩn) · NhatKyView 200/200 (ẩn) · LamRoView 65/200 (ẩn) · XungDotView 65/200 (ẩn) · KgMapView 65/200 (ẩn)
- ảnh: `buoc-05.png`

## 6. Bản đồ tri thức — đồ thị dựng từ store

- ✅ 2 dòng · 1 cây
- 5002 ms
- cửa sổ 826 pt · Auto Layout đòi 671 pt
- ảnh: `buoc-06.png`

## 7. Xung đột tri thức — hai nguồn nói khác nhau

- ✅ 0 dòng
- 4000 ms
- cửa sổ 826 pt · Auto Layout đòi 678 pt
- ảnh: `buoc-07.png`

## 8. Mã nguồn — mở một tệp, xem dấu tri thức ở lề

- ✅ main.c · 0 dòng có fact · 11 dòng vi phạm constant-guard
- 8016 ms
- cửa sổ 826 pt · Auto Layout đòi 608 pt
- ảnh: `buoc-08.png`

## 9. Mô phỏng — chạy firmware thật nếu dự án có

- ✅ 7 dòng · 1 khối mã
- 92005 ms
- cửa sổ 826 pt · Auto Layout đòi 641 pt
- ảnh: `buoc-09.png`

## 10. Ô LỆNH gõ được NGAY TRÊN một màn chuyên đề

- ✅ gõ được CẢ trên màn chuyên đề lẫn ở hội thoại · 6 lượt
- 89006 ms
- cửa sổ 826 pt · Auto Layout đòi 678 pt
- ảnh: `buoc-10.png`

## 11. Tác tử tự MỞ và FOCUS đúng màn của việc nó đang làm

- ✅ đang ở `Env` → tác tử chạy `passport.query` → tự mở `Passport`
- 36004 ms
- cửa sổ 826 pt · Auto Layout đòi 826 pt
- đòi nhiều nhất: NSTableView đòi 3838 (đang có 3838) · NSView đòi 826 (đang có 826) · EidePanel đòi 826 (đang có 826)
- con của panel: AutonomyBar 34/34 · ChatView 290/290 · EideVungPhai 0/792 · NSStackView 19/19 · EideONhap 203/203 · PassportView 24/200 · RagAskView 80/200 (ẩn) · DocView 63/200 (ẩn) · ProjectStatusView 65/200 (ẩn) · IngestView 65/200 (ẩn) · BoardView 65/200 (ẩn) · ReqArchView 65/200 (ẩn) · DiagramView 65/200 (ẩn) · PlanDiffView 65/200 (ẩn) · CodeView 65/200 (ẩn) · SimView 65/200 (ẩn) · DiscoveryView 65/200 (ẩn) · LogAssistView 65/200 (ẩn) · DebugView 65/200 (ẩn) · BenchView 65/200 (ẩn) · ToolForgeView 65/200 (ẩn) · RegistryView 65/200 (ẩn) · ModelsView 65/200 (ẩn) · EnvView 65/200 (ẩn) · FlowMapView 65/200 (ẩn) · NhatKyView 200/200 (ẩn) · LamRoView 65/200 (ẩn) · XungDotView 65/200 (ẩn) · KgMapView 65/200 (ẩn)
- ảnh: `buoc-11.png`

## 12. Nhật ký — mọi việc vừa làm có vào sổ cái không

- ✅ 1311 dòng
- 5002 ms
- cửa sổ 826 pt · Auto Layout đòi 709 pt
- ảnh: `buoc-12.png`

## 13. Mô hình & chi phí — tiêu bao nhiêu trong vòng này

- ✅ 4 dòng
- 4001 ms
- cửa sổ 826 pt · Auto Layout đòi 709 pt
- ảnh: `buoc-13.png`

## 14. Hành trình & cổng — chính sách đã quyết những gì

- ✅ 10 dòng
- 4001 ms
- cửa sổ 826 pt · Auto Layout đòi 709 pt
- ảnh: `buoc-14.png`

---

**14/14 bước chạy được** · tổng 270.1 s
