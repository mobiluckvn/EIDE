# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** mở lại dự án — `ma-tran-truy-vet`

**Tác tử trả lời** *(sau 0.3 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?

**Tác tử trả lời** *(sau 10.9 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  bước 2/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/4 bước, 2 bước cần anh trả lời  → mở màn Nhập tài liệu (tác tử đang chạy `ingest.index_text`)  → mở màn Bản đồ tri thức & hỏi đáp (tác tử đang chạy `view.rag_index`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tài liệu còn đúng không?. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  KẾT QUẢ TỪNG BƯỚC  1. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  TÁC TỬ HỎI  ·  ingest.index_text  files   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 2 tab tác tử đã mở:** Ingest, Graph

### Tab `Ingest`

```
Nhập tài liệu  archive.extract_one · archive.list · archive.query · +27 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Kéo PDF · SVD · ATDF · netlist · BOM vào đây  Màn này đang rỗng — vì: chưa nhập tài liệu nào vào dự án này  Bước kế tiếp: kéo PDF/SVD/BOM vào vùng trên, hoặc chạy `eide ingest <tệp>` ở dòng lệnh  
```

![Ingest](man-01-Ingest.png)

### Tab `Graph`

```
Bản đồ tri thức & hỏi đáp  view.artifacts · view.conflict_board · view.coverage_map · +9 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.   Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![Graph](man-02-Graph.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (1)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `ingest.index_text` đang chờ anh cho biết:
• `files`  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (9)  view.rag_index  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.acceptance  còn 23 giờ  Hoàn tác req.prioritize  còn 23 giờ  Hoàn tác … và 1 mục nữa — xem màn Nhật ký.  ⟩ 
```

**Tác tử trả lời** *(sau 4.6 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  Đã nhận (ý hiểu: `view.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  bước 2/4  Mở chi tiết Dừng khẩn ⏸ DỪNG, đang chờ anh — xong 1/4 bước, 2 bước cần anh trả lời  → mở màn Nhập tài liệu (tác tử đang chạy `ingest.index_text`)  → mở màn Bản đồ tri thức & hỏi đáp (tác tử đang chạy `view.rag_index`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là view.ask: Tài liệu còn đúng không?. Tôi sẽ ingest.index_text, view.rag_index, view.rag_ask, chat.report_back.  1. `ingest.index_text`  2. `view.rag_index`  3. `view.rag_ask`  4. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  KẾT QUẢ TỪNG BƯỚC  1. `view.rag_index` — 0 chunks  Xem đầy đủ ▾ {
  "chunks" : 0,
  "status" : {
  }
}  TÁC TỬ HỎI  ·  ingest.index_text  files   …hoặc gõ câu trả lời khác Trả lời Lượt chạy DỪNG, đang chờ anh trả lời.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC064`.