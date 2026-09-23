# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** mở lại dự án — `ota-phan-vung-a-b`

**Tác tử trả lời** *(sau 0.3 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ota-phan-vung-a-b` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.   Thử: đối chiếu FR-GEN-01 với phần cứng thật (còn 2 yêu cầu chưa đối chiếu) Gửi 
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Mô phỏng mất điện đúng lúc đang ghi phân vùng B. Thiết bị phải khởi động lại bằng bản cũ

**Tác tử trả lời** *(sau 6.4 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ota-phan-vung-a-b` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Mô phỏng mất điện đúng lúc đang ghi phân vùng B. Thiết bị phải khởi động lại bằng bản cũ  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Mô phỏng mất điện đúng lúc đang ghi phân vùng B. Thiết bị phải khởi động lại bằng bản cũ  bước 1/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/4 bước, 1 bước cần anh trả lời  → mở màn Mô phỏng (tác tử đang chạy `sim.build_platform`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run: mô phỏng mất điện khi đang ghi phân vùng B. Tôi sẽ sim.build_platform.  1. `sim.build_platform`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.build_platform  Dùng con chip nào?   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-GEN-01 với phần cứng thật (còn 2 yêu cầu chưa đối chiếu) Gửi 
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
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (4)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `ingest.classify` đang chờ anh cho biết:
• `files`  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `sim.build_platform` đang chờ anh cho biết:
• Dùng con chip nào? (`chip`)  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `ingest.index_text` đang chờ anh cho biết:
• `files`  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — CÒN MƠ HỒ  Hệ thống phải hỗ trợ cập nhật OTA sử dụng kiến trúc phân vùng A/B, yêu cầu xác thực chữ ký số (ví dụ: ECDSA/SHA256) cho firmware mới, và tự động quay lui (rollback) về phân vùng cũ nếu firmware mới không xác nhận hoạt động ổn định trong vòng 10 giây sau khi khởi động.  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (6)  req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.classify  còn 23 giờ  Hoàn tác ⟩ 
```

**Tác tử trả lời** *(sau 2.3 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ota-phan-vung-a-b` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Mô phỏng mất điện đúng lúc đang ghi phân vùng B. Thiết bị phải khởi động lại bằng bản cũ  Đã nhận (ý hiểu: `sim.run`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Mô phỏng mất điện đúng lúc đang ghi phân vùng B. Thiết bị phải khởi động lại bằng bản cũ  bước 1/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 0/4 bước, 1 bước cần anh trả lời  → mở màn Mô phỏng (tác tử đang chạy `sim.build_platform`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là sim.run: mô phỏng mất điện khi đang ghi phân vùng B. Tôi sẽ sim.build_platform.  1. `sim.build_platform`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  TÁC TỬ HỎI  ·  sim.build_platform  Dùng con chip nào?   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-GEN-01 với phần cứng thật (còn 2 yêu cầu chưa đối chiếu) Gửi 
```

**Màn đang mở — `Sim`:**

```
NỀN TẢNG MÔ PHỎNG  Nền tảng mô phỏng chưa dựng cho dự án này — `sim.build_platform` sinh `sim/platform.json` từ hộ chiếu chip (cần fact `memory_size` tầng vàng). Bảo tác tử dựng nó ở vùng trao đổi; màn này CHỈ ĐỌC, không tự dựng vì `sim.build_platform` ghi tệp vào dự án.  Màn này đang rỗng — vì: chưa có lượt mô phỏng nào trong dự án này  Bước kế tiếp: bước kế: tác tử chạy `sim.run` — cần một kịch bản (`sim.scenario`) và một firmware đã dựng (`code.build`)  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC059`.