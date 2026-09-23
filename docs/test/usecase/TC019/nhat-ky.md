# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** mở lại dự án — `nhap-nhay-led-atmega328p`

**Tác tử trả lời** *(sau 0.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `nhap-nhay-led-atmega328p` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.   Thử: đối chiếu FR-PWR-02 với phần cứng thật (còn 6 yêu cầu chưa đối chiếu) Gửi 
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Mô phỏng luôn cả phần ADC và phần Ethernet PHY của mạch này

**Tác tử trả lời** *(sau 6.5 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `nhap-nhay-led-atmega328p` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Mô phỏng luôn cả phần ADC và phần Ethernet PHY của mạch này  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Mô phỏng luôn cả phần ADC và phần Ethernet PHY của mạch này  bước 1/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/4 bước, 1 bước cần anh trả lời  → mở màn Mô phỏng (tác tử đang chạy `sim.build_platform`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run: ADC và Ethernet PHY. Tôi sẽ sim.build_platform.  1. `sim.build_platform`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.build_platform  Dùng con chip nào?   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-PWR-02 với phần cứng thật (còn 6 yêu cầu chưa đối chiếu) Gửi 
```

**Màn đang mở — `Sim`:**

```
NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 1 tab tác tử đã mở:** Sim

### Tab `Sim`

```
Mô phỏng  sim.build_platform · sim.mock_peripheral · sim.model_plant · +3 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![Sim](man-01-Sim.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (24)  Làm rõ yêu cầu — FUNCTIONAL  Chu kỳ nhấp nháy của LED là bao nhiêu?  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — ENVIRONMENT  Toolchain hoặc môi trường biên dịch nào đang được sử dụng cho dự án này?  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — CHƯA ĐO ĐƯỢC  Mã nguồn firmware phải được biên dịch thành công ra tệp thực thi cho vi điều khiển ATmega328P với kết quả 0 lỗi (0 error).  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — FR  Tỷ lệ sáng/tắt (duty cycle) trong chu kỳ 1 giây là bao nhiêu?  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — MÔI TRƯỜNG HOẠT ĐỘNG  Tần số xung nhịp (clock) của vi điều khiển ATmega328P trong mạch thực tế là bao nhiêu để cấu hình timer/delay chính xác?  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — HW  Tần số xung nhịp (clock frequency) của vi điều khiển ATmega328P đang sử dụng là bao nhiêu?  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `ingest.classify` đang chờ anh cho biết:
• Đọc những tệp nào? (đường dẫn đầy đủ) (`files`)  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — HARDWARE  Chân GPIO nào của ATmega328P được sử dụng để điều khiển LED?  Trả lời ở tab Làm rõ yêu cầu … và 16 mục nữa — xem màn Nhật ký.  HOÀN TÁC ĐƯỢC (93)  req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác … và 85 mục nữa — xem màn Nhật ký.  ⟩ 
```

**Tác tử trả lời** *(sau 2.3 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `nhap-nhay-led-atmega328p` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Mô phỏng luôn cả phần ADC và phần Ethernet PHY của mạch này  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Mô phỏng luôn cả phần ADC và phần Ethernet PHY của mạch này  bước 1/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/4 bước, 1 bước cần anh trả lời  → mở màn Mô phỏng (tác tử đang chạy `sim.build_platform`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run: ADC và Ethernet PHY. Tôi sẽ sim.build_platform.  1. `sim.build_platform`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.build_platform  Dùng con chip nào?   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-PWR-02 với phần cứng thật (còn 6 yêu cầu chưa đối chiếu) Gửi 
```

**Màn đang mở — `Sim`:**

```
NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC019`.