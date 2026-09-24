# Nhật ký phiên — kịch bản `kich-ban.kb`

Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước
kèm một ảnh chụp cửa sổ thật.

## Bước 1

**Tôi (người dùng):** mở lại dự án — `ma-tran-truy-vet`

**Tác tử trả lời** *(sau 0.4 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

![bước 1](buoc-01.png)

## Bước 2

**Tôi (người dùng):** Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?

**Tác tử trả lời** *(sau 10.9 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  Đã nhận (ý hiểu: `review.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  bước 1/7  Mở chi tiết Dừng khẩn ⚠ Dừng — xong 0/7 bước, 2 bước hỏng (xem Nhật ký)  → mở màn Trình soạn thảo (tác tử đang chạy `code.static`)  → mở màn Bản đồ tri thức & hỏi đáp (tác tử đang chạy `view.rag_ask`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là review.ask, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ ingest.index_text, extract.kicad_netlist, board.check_pins, board.propose_fix và 3 bước nữa.  1. `ingest.index_text`  2. `extract.kicad_netlist`  3. `board.check_pins`  4. `board.propose_fix`  5. `code.static`  6. `view.rag_ask`  7. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `code.static` HỎNG — E2000: Dự án chưa ghim ISA — chạy `project.set_target` trước (mọi lệnh dựng đến từ manifest của một ISA)  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  Lượt chạy DỪNG vì có bước hỏng — KHÔNG chờ anh, xem dòng ✖ ở trên.  Đã làm 314 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, req.elicit, view.kg_map, req.classify, req.detect_conflict, req.prioritize, req.trace_matrix, req.acceptance, chat.report_back, chat.orchestrate, chat.restate
Hoàn tác được 11 mục đến 2026-09-24T23:58.
Chi phí mô hình: 0.0176 USD.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 2](buoc-02.png)

## Bước 3

**Quét 2 tab tác tử đã mở:** Code, Graph

### Tab `Code`

```
Trình soạn thảo  code.annotate · code.build · code.constant_guard · +13 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.  Màn này đang rỗng — vì: không tìm thấy tệp mã nào trong dự án  Bước kế tiếp: bảo tác tử sinh mã (`code.generate_module`), hoặc thêm tệp `.c`/`.h` vào thư mục dự án rồi mở lại màn  
```

![Code](man-01-Code.png)

### Tab `Graph`

```
Bản đồ tri thức & hỏi đáp  view.artifacts · view.conflict_board · view.coverage_map · +10 nữa  Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn.   Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![Graph](man-02-Graph.png)

### Cột phải (cổng, hoàn tác, an toàn)

```
ĐANG CHẠY  Không có lượt chạy nào.  CHỜ TÔI (2)  Làm rõ yêu cầu — THIẾU THÔNG TIN  Bước `code.static` dừng: Dự án chưa ghim ISA — chạy `project.set_target` trước (mọi lệnh dựng đến từ manifest của một ISA)  Trả lời ở tab Làm rõ yêu cầu Làm rõ yêu cầu — CHỨC NĂNG CỤ THỂ  Danh sách các yêu cầu (UR/FR/NFR), tài liệu thiết kế, mã nguồn và các kịch bản kiểm thử (test case) của dự án này hiện đang ở đâu?  Trả lời ở tab Làm rõ yêu cầu HOÀN TÁC ĐƯỢC (11)  req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.trace_matrix  còn 23 giờ  Hoàn tác req.acceptance  còn 23 giờ  Hoàn tác … và 3 mục nữa — xem màn Nhật ký.  ⟩ 
```

**Tác tử trả lời** *(sau 4.6 s)*:

```
VÙNG TRAO ĐỔI  ▁ ▂ ▃ Sẵn sàng. Gõ một câu tiếng Việt; tôi nói lại ý hiểu trước khi làm.  Đã mở `ma-tran-truy-vet` — 0 tính năng trong hồ sơ. Gõ một câu tiếng Việt để bắt đầu.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  Đã nhận (ý hiểu: `review.ask`) — đang làm. Tiến độ hiện ở thẻ Run, kết quả hiện ngay dưới đây khi xong.  Tôi vừa đổi MCU sang ATmega328P. Tài liệu còn đúng không?  bước 1/7  Mở chi tiết Dừng khẩn ⚠ Dừng — xong 0/7 bước, 2 bước hỏng (xem Nhật ký)  → mở màn Trình soạn thảo (tác tử đang chạy `code.static`)  → mở màn Bản đồ tri thức & hỏi đáp (tác tử đang chạy `view.rag_ask`)  Ý HIỂU  ·  chat.restate  Tôi hiểu là review.ask, nhưng KHÔNG rút được đối tượng cụ thể nào từ câu của anh — hãy đọc kỹ các bước dưới trước khi để tôi chạy. Tôi sẽ ingest.index_text, extract.kicad_netlist, board.check_pins, board.propose_fix và 3 bước nữa.  1. `ingest.index_text`  2. `extract.kicad_netlist`  3. `board.check_pins`  4. `board.propose_fix`  5. `code.static`  6. `view.rag_ask`  7. `chat.report_back`  Mức A2 — tác tử tự chạy, vẫn in ý hiểu (§2D.6). Sai thì bấm Dừng khẩn.  ✖ Bước `code.static` HỎNG — E2000: Dự án chưa ghim ISA — chạy `project.set_target` trước (mọi lệnh dựng đến từ manifest của một ISA)  ✖ Bước `view.rag_ask` HỎNG — E5002: Dự án chưa có tài liệu nào để tra cứu, nên chưa có nguồn nào để trả lời. Nhập datasheet/PDF ở màn Nhập tài liệu (S3), hoặc cho tôi đường dẫn tệp.  Lượt chạy DỪNG vì có bước hỏng — KHÔNG chờ anh, xem dòng ✖ ở trên.  Đã làm 314 việc: project.open, view.artifacts, view.timeline, project.status, chat.parse_intent, chat.ground, chat.fill_defaults, req.elicit, view.kg_map, req.classify, req.detect_conflict, req.prioritize, req.trace_matrix, req.acceptance, chat.report_back, chat.orchestrate, chat.restate
Hoàn tác được 11 mục đến 2026-09-24T23:58.
Chi phí mô hình: 0.0176 USD.   Thử: đối chiếu FR-PWR-01 với phần cứng thật Gửi 
```

**Màn đang mở — `Graph`:**

```
 Hỏi một câu về tri thức đã nhập — ví dụ: điện áp cấp của DHT22? Hỏi Hỏi xong, bản đồ LÂN CẬN của thứ được hỏi hiện ngay dưới câu trả lời — hai bước quanh nó, tô theo tầng (vàng/bạc/đồng) và trạng thái duyệt.  Màn này đang rỗng — vì: đồ thị tri thức chưa có nút nào — store chưa có fact  Bước kế tiếp: nhập datasheet/SVD ở màn Nhập tài liệu (S4); đồ thị dựng từ chính fact và nguồn của chúng  
```

![bước 3](buoc-03.png)

---

Hết kịch bản — 3 bước. Ảnh và nhật ký trong `/Users/congvt/Documents/EIDE/docs/test/usecase/TC064`.