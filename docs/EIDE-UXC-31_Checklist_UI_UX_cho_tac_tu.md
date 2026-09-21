# EIDE-UXC-31 — CHECKLIST UI/UX CHO TÁC TỬ HIỆN THỰC (v1.0)

| Thuộc tính | Giá trị |
|---|---|
| Mã tài liệu | EIDE-UXC-31 |
| Phiên bản | 1.0 — 17/09/2026 |
| Người lập | Vũ Trí Công (hỗ trợ soạn thảo: Claude) |
| Người hướng dẫn | TS. Nguyễn Trung Hiếu |
| Khuôn khổ | Đề án tốt nghiệp Thạc sĩ ngành Kỹ thuật Điện tử — PTIT |
| Căn cứ | EIDE-UXD-13 v2.0 (đặc tả), EIDE-FTR-30 (tính năng), EIDE-POL-17 (chính sách), demo EIDE_UI_Demo_v2.html (mẫu tham chiếu hành vi) |
| Đối tượng đọc | Tác tử Claude khi hiện thực giao diện Swift/macOS. Mỗi mục `- [ ]` là MỘT việc kiểm được: làm xong thì đổi thành `- [x]` kèm mã commit. KHÔNG được đánh dấu mục chưa có bài kiểm chứng minh. |

## TRẠNG THÁI ÁP DỤNG (tác tử cập nhật, 17/09/2026)

**12 mục đạt · 4 mục bị chặn · 104 mục còn lại.** Ba đợt đã vào kho:

| Đợt | Commit | Nội dung |
|---|---|---|
| 0 | `c997796` | Đóng ba lỗi TÀI LIỆU của bản rà soát (R1/R4/R6). Ba trong sáu phát hiện là lỗi tài liệu chứ không phải lỗi sản phẩm: bộ chuyển dự án đã có từ DEV-113, điều hướng đã nhóm sẵn, Chat không nằm trong sidebar. |
| 1 | `c27d027` | Thẻ Run (R3) + sáu kiểu sự kiện sổ cái `run.*`. Ba lỗi im lặng 59–61. |
| — | `e04c0c6` | Bảng màu theo bản demo, sửa hai giá trị không đạt AA. |
| 2 (lõi) | `3e360a9` | `code.human_save`, `code.merge_conflict_resolve`, `project.watch`; merge 3 bên; 5 quy tắc chính sách; hai lỗ an toàn 62–63. |

**Bốn chỗ tài liệu này đã được sửa số theo đo đạc**, ghi lại để người đọc bản in cũ không lạc:
`23 màn` → **25** (mục 8 của chính tài liệu liệt kê S1–S25); `A0…A3` → **A0…A4** (APD-08 có năm
mức); `238 năng lực` → **241** (v2.0 thêm ba); `53 quy tắc` → **54** (P-EDIT-02 bắt buộc đi kèm
P-EDIT-04, xem DEV-125). Mục 1.5 (Dark Mode) BỎ theo quyết định chủ sản phẩm.

---

## QUY TẮC ĐỌC TÀI LIỆU NÀY (tác tử đọc trước tiên)

- [ ] Đọc hết mục 0 (bất biến) trước khi viết dòng mã đầu tiên; mọi mục sau đều phải thoả bất biến mục 0.
- [ ] Thứ tự hiện thực bắt buộc: mục 0 → 1 → 2 → 7 (sổ cái + sự kiện) → 3 → 4 → 5 → 6 → 8 (từng màn) → 9 → 10 → 11. Không làm màn (mục 8) trước khi xong tầng sự kiện (mục 7).
- [ ] Gặp mâu thuẫn giữa tài liệu này và UXD-13 v2.0 → UXD-13 v2.0 thắng; ghi mâu thuẫn vào sổ cái và báo người, KHÔNG tự chọn.
- [ ] Mọi chuỗi chữ hiển thị: tiếng Việt; thuật ngữ tiếng Anh phải kèm giải thích tiếng Việt lần xuất hiện đầu (ví dụ "bảng lệnh (command palette)").
- [ ] Không phát minh thêm màn, menu, nút ngoài danh mục này. Thiếu thì hỏi, thừa là lỗi.

---

## 0. BẤT BIẾN — VI PHẠM LÀ LỖI CHẶN (blocker), KHÔNG MERGE

- [ ] **B1.** Giao diện KHÔNG có đường nào hiển thị một việc mà sổ cái không có sự kiện tương ứng. Mọi widget trạng thái (thẻ Run, badge, cột phải, timeline) là hàm chiếu của dòng sự kiện sổ cái — không giữ trạng thái nguồn riêng.
- [x] **B2.** Nút bấm của người, lệnh của tác tử, lệnh từ bảng lệnh ⌘K: đi CÙNG MỘT đường gọi năng lực → cổng chính sách → sổ cái. Không có lối tắt riêng cho UI.  ·  **✔ c27d027 · mọi nút panel đi `caps.invoke` → Router → cổng → sổ cái**
- [ ] **B3.** Vùng trao đổi không bao giờ bị màn nào thay thế, che, hay về chiều cao 0. Tối thiểu tuyệt đối 48 pt.
- [x] **B4.** Không ghi đè im lặng: mọi tình huống hai bản cùng tồn tại (người/tác tử, cũ/mới) phải đi qua merge 3 bên hoặc màn xung đột.  ·  **✔ 3e360a9 · `test_LUU_khi_tep_da_doi_tren_dia_thi_KHONG_ghi_de` + merge 3 bên**
- [x] **B5.** Không hiện dữ liệu giả. Màn thiếu dữ liệu → trạng thái rỗng gồm đúng 2 phần: (a) lý do rỗng, (b) bước kế tiếp.  ·  **✔ c997796 · bài tự kiểm mở CẢ 26 màn, khẳng định không màn nào vừa rỗng vừa im**
- [ ] **B6.** Dữ liệu cũ phải nói là cũ: màn mất đồng bộ (seq lệch / mất daemon) hiện nhãn "Dữ liệu cũ — bấm để tải lại" trong ≤ 2 giây (tiêu chí N6).
- [ ] **B7.** Mỗi câu hỏi của người dùng có ĐÚNG MỘT nơi trả lời: "đang làm gì?" = thẻ Run; "việc gì chờ tôi?" = khối Chờ tôi; "đã xảy ra gì?" = Nhật ký. Mọi chỗ khác chỉ là bản chiếu (mirror), không mang dữ liệu riêng.
- [ ] **B8.** Dừng khẩn hạ về A0 và huỷ thao tác đang chờ trong < 1 giây, hoạt động ở MỌI trạng thái giao diện, kể cả khi modal đang mở.

## 1. HỆ THỐNG THIẾT KẾ (design tokens)

- [x] **1.1** Khai báo token màu tập trung một tệp, không hard-code trong view: `--red #BC2626` (hành động chính/PTIT), `--red2 #DE221A` (viền nhấn), `--ok #1D7A4F`, `--warn #8A5A00`, `--blue #1B5FA5` (tác tử đang chạy), nền `#F5F4F2`, panel `#FFFFFF`, chữ chính `#1B1B1B`, chữ phụ `#6B6B6B`, viền `#E2E0DC`.  ·  **✔ e04c0c6 · `EideTokensGenerated.swift` sinh từ `tokens.json`, không hard-code**
- [ ] **1.2** Chữ: hệ San Francisco (mặc định macOS); cỡ nội dung 13 pt, phụ 11–12 pt, tiêu đề màn 16 pt; mã nguồn dùng SF Mono 12.5 pt, giãn dòng 2.0 trong editor.
- [ ] **1.3** Bo góc: panel 8 pt, nút 6 pt, thẻ Run 9 pt. Khoảng cách lưới bội số 4 pt.
- [ ] **1.4** Ngữ nghĩa màu cố định toàn app: xanh lá = có nguồn/đạt; đỏ = vi phạm/chặn/dừng; vàng = chờ người; xanh dương = tác tử đang làm. Không dùng chéo.
- [x] **1.5** ~~Hỗ trợ Dark Mode~~ → **BỎ theo quyết định chủ sản phẩm 17/09/2026.** Sản phẩm chạy MỘT bảng màu sáng, ghim `.aqua` (DEV-114): UXD-13 khai đúng một bảng màu, nên bịa một bảng tối ở tầng mã là quyết định thương hiệu chứ không phải quyết định kỹ thuật. Phép kiểm tương phản ≥ 4,5:1 GIỮ NGUYÊN và đang chạy — xem DEV-124.
- [x] **1.6** Mọi trạng thái KHÔNG truyền đạt bằng màu đơn độc — luôn kèm ký hiệu hoặc chữ (chấm ●, vạch ▎, nhãn) để không phụ thuộc thị giác màu.  ·  **✔ DEV-117 · lề dùng ● và ▎ kèm màu, không dựa màu đơn độc**

## 2. KHUNG MÀN HÌNH (shell) — 5 VÙNG

- [ ] **2.1** Bố cục: thanh trên (cao 46 pt, viền dưới 2 pt màu `--red2`) / hàng chính gồm: cột trái 198 pt · trung tâm co giãn · cột phải 236 pt. Trung tâm = thanh tab + vùng làm việc + vùng trao đổi.
- [ ] **2.2** Cửa sổ tối thiểu 1100 × 700 pt; dưới ngưỡng thì cột phải thu thành dải icon 44 pt (badge vẫn hiện), KHÔNG được ẩn hẳn.
- [ ] **2.3** Ở cửa sổ cao 900 pt, vùng trao đổi mức chuẩn: vùng làm việc còn ≥ 50 % chiều cao (tiêu chí N7 — viết bài kiểm layout tự động).

### 2A. Thanh trên — đúng thứ tự trái → phải, không thêm bớt

- [ ] **2A.1** Logo chữ "EIDE" (đậm, `--red`).
- [ ] **2A.2** Bộ chuyển dự án: tên dự án + mũi tên ▾; bấm mở popover: danh sách `project.list` + ô lọc + nút "Dự án mới" (gọi `project.create`). Đổi dự án = thay toàn bộ ngữ cảnh, đóng hết tab, giữ nguyên bố cục.
- [ ] **2A.3** Huy hiệu mức tự chủ: "Tự chủ A0…A4" — nền xanh dương khi A1–A4, nền đỏ khi A0. Bấm mở màn S25.
- [ ] **2A.4** Bộ đếm "Chờ tôi n" — bấm cuộn tới khối Chờ tôi ở cột phải (không mở màn mới).
- [ ] **2A.5** Bộ đếm "Hoàn tác n" — bấm cuộn tới khối Hoàn tác được.
- [ ] **2A.6** Nút bảng lệnh "⌘K" (viền đứt) + phím tắt ⌘K toàn cục.
- [ ] **2A.7** Nút "■ Dừng khẩn" — luôn ở vị trí cuối cùng bên phải, nền `--red-bg`, chữ `--red`; hành vi theo B8; sau khi dừng, nút đổi thành "Đặt lại mức tự chủ" trỏ S25.
- [ ] **2A.8** Hai bộ đếm 2A.4/2A.5 phái sinh từ cùng nguồn với cột phải (B7) — viết một selector chung, cấm hai phép đếm riêng.

### 2B. Cột trái — điều hướng 6 nhóm / 25 màn

- [ ] **2B.1** Đúng 6 nhóm cấp một, mỗi nhóm 2–5 mục (tiêu chí N8); danh mục và thứ tự CHÍNH XÁC theo mục 8 dưới đây.
- [ ] **2B.2** Tiêu đề nhóm: chữ hoa 10.5 pt màu nhạt; bấm tiêu đề gập/mở nhóm; trạng thái gập lưu theo dự án.
- [ ] **2B.3** Mục đang mở: nền đậm hơn + vạch trái 3 pt `--red` + chữ đậm.
- [ ] **2B.4** Huy hiệu số trên mục và trên tiêu đề nhóm = số việc "Chờ tôi" trỏ về màn ấy; phái sinh từ danh sách pending duy nhất (B7).
- [ ] **2B.5** Khi tác tử tự mở màn: nhóm chứa tự bung + mục nhấp nháy nền vàng đúng 2 nhịp × 300 ms rồi thôi. Không nhấp nháy khi người tự bấm.
- [ ] **2B.6** Không mục nào ngoài 25 màn; "Chat" và "ReviewQueue" KHÔNG được xuất hiện ở đây (đã đổi vai — UXD-13 v2.0 §4).

### 2C. Vùng làm việc + tab

- [ ] **2C.1** Tab như IDE: mở màn nào thêm tab đó (không trùng), đóng bằng ✕, kéo đổi thứ tự; tab đang mở nền trắng chữ đậm.
- [ ] **2C.2** Không tab nào mở: hiện trạng thái rỗng "Vùng làm việc trống — chọn màn ở cột trái, hoặc ra lệnh để tác tử tự mở đúng màn."
- [ ] **2C.3** Quy tắc "không cướp màn": tác tử muốn mở màn trong khi người vừa TỰ chọn màn khác < 20 giây → tab mới mở ở nền (không chiếm focus) + nhấp nháy 2B.5; quá 20 giây → được chiếm focus.
- [ ] **2C.4** Mỗi màn khai báo header chuẩn: tiêu đề (16 pt) + dòng phụ ghi tên năng lực đứng sau (12 pt, màu phụ). Không màn nào không ghi năng lực (chống "màn mồ côi" — phát hiện R6).

### 2D. Vùng trao đổi (chat dock) — 3 trạng thái

- [ ] **2D.1** Ba trạng thái chiều cao: thu gọn 48 pt (chỉ ô nhập) · chuẩn 220 pt · mở rộng tối đa 320 pt (kéo tay, nội dung vượt trần thì cuộn trong).
- [ ] **2D.2** Tự chuyển: (a) Run mới bắt đầu → về chuẩn; (b) người gõ trong editor liên tục 5 giây → thu gọn; (c) không bao giờ đổi trạng thái trong lúc con trỏ đang ở ô lệnh.
- [ ] **2D.3** Hoạt ảnh chuyển ≤ 150 ms, ease-out; ba nút ▁▂▃ góc phải cho chuyển tay.
- [ ] **2D.4** Ô lệnh: placeholder gợi ý một lệnh mẫu theo pha hiện tại của dự án; Enter gửi; đang có Run chạy thì lệnh mới được báo "xếp hàng sau Run hiện tại".
- [ ] **2D.5** Bong bóng: người nền `--red-bg` căn phải ≤ 78 % rộng; tác tử nền trắng viền, căn trái.
- [ ] **2D.6** Trước mọi chuỗi: tác tử in "Ý hiểu (chat.restate)" + danh sách bước dự kiến + hai nút "Đúng — làm đi" / "Sửa ý hiểu" (A1); mức A2–A3 tự chạy nhưng vẫn in ý hiểu.

### 2E. Thẻ Run (Run card) — đặc tả từng pixel hành vi

- [x] **2E.1** Sinh đúng MỘT thẻ cho mỗi Run, đặt trong dòng chat ngay dưới câu lệnh; cột phải chỉ chiếu một dòng (B7, tiêu chí N2).  ·  **✔ c27d027 · một thẻ mỗi `run_id`; nút của chuỗi mang mã CHUỖI**
- [x] **2E.2** Hàng đầu: "Run #id · tên việc" (đậm) + "bước i/n" + link "Mở chi tiết" (mở S2 lọc sẵn theo Run) + link "Dừng" (huỷ Run này, KHÔNG hạ mức tự chủ).  ·  **✔ c27d027 · `Run #7 · <câu người gõ> · 3/8 bước` + Mở chi tiết + Dừng**
- [ ] **2E.3** Thanh tiến độ: n đoạn bằng nhau; xong = xanh lá, đang chạy = xanh dương, chờ người = vàng, chưa tới = xám. Dưới thanh: dòng trạng thái ghi bước hiện tại + tên năng lực dạng mã.
- [x] **2E.4** Trạng thái thẻ chỉ đổi khi nhận sự kiện `run.*` từ sổ cái — cấm setState trực tiếp từ luồng thực thi (B1). Số đoạn "xong" phải luôn bằng số `run.step_done` đã ghi (bài kiểm N2).  ·  **✔ c27d027 · thẻ chỉ đổi khi nhận `run.*`; số bước lấy từ `run.started`**
- [ ] **2E.5** Run bị chặn (`run.blocked`): thẻ hiện "⏸ Chờ anh quyết…" + link mở đúng màn có việc; đồng thời mục xuất hiện ở khối Chờ tôi. Giải quyết xong → thẻ tự chạy tiếp, không cần người quay lại chat.
- [ ] **2E.6** Run kết thúc: `run.done` → tác tử in báo cáo (chat.report_back) ngay dưới thẻ: sản phẩm, cổng đã qua, chi phí, các mục hoàn tác được. `run.cancelled` → thẻ ghi ai huỷ, lúc nào.
- [!] **2E.7** Chuỗi > 20 bước: thanh tiến độ gộp theo pha P0–P7, bấm pha bung chi tiết (quyết định cho câu hỏi mở #3 của UXD-13 v2.0).  ·  **CHẶN: chưa có chuỗi > 20 bước để đo; chuỗi dài nhất hiện là 16 (`code.feature`)**

### 2F. Cột phải — hàng đợi 3 khối cố định

- [ ] **2F.1** Đúng 3 khối, đúng thứ tự: ĐANG CHẠY / CHỜ TÔI / HOÀN TÁC ĐƯỢC. Không khối nào khác.
- [ ] **2F.2** Khối rỗng vẫn hiện tiêu đề + một dòng lý do ("Trống — không việc nào chờ anh."), không ẩn khối (B5).
- [ ] **2F.3** CHỜ TÔI: mỗi mục = tiêu đề + lý do + đích; nền vàng nhạt; bấm mở đúng màn, cuộn tới đúng phần tử. Nguồn: danh sách pending duy nhất (B7).
- [ ] **2F.4** HOÀN TÁC ĐƯỢC: mỗi mục = nhãn + tác giả (`human:` / `agent:run-…`) + thời gian còn lại đếm ngược + nút "hoàn tác" (gọi `code.revert`/`project.rollback` đúng phạm vi). Hết hạn tự rời danh sách kèm sự kiện.
- [ ] **2F.5** Mục của NGƯỜI (lưu tệp) xuất hiện ở đây như mục của tác tử — cùng cơ chế, không phân biệt (UXD-13 v2.0 §7.4).

## 3. LUỒNG LÀM QUEN (onboarding) — trả lời phát hiện R2

- [ ] **3.1** Workspace chưa có dự án → toàn màn là màn hình chào: 1 câu chào, 1 đoạn giải thích trạng thái rỗng, 1 ô gợi ý mô tả dự án một câu, ĐÚNG MỘT nút chính "Tạo dự án đầu tiên (project.create)". Không menu, không cột phải lúc này.
- [ ] **3.2** Tạo dự án xong ≤ 3 thao tác từ lúc mở app (tiêu chí N1 — viết bài kiểm đếm click).
- [ ] **3.3** Sau tạo: mở S1, tác tử chào trong vùng trao đổi + chỉ đúng 3 thứ: nút demo/lệnh mẫu, ⌘K, nút Dừng khẩn. Không tour dài.
- [ ] **3.4** Ô lệnh 10 phút đầu: placeholder xoay vòng 3 lệnh mẫu thật chạy được với dự án vừa tạo.

## 4. BẢNG LỆNH (command palette)

- [ ] **4.1** ⌘K mở overlay giữa-trên màn; Esc đóng; focus vào ô tìm ngay khi mở.
- [ ] **4.2** Nguồn dữ liệu: registry thật (**241** năng lực sau v2.0) + 25 màn; tìm theo tên VÀ mô tả, không phân biệt hoa thường, có dấu/không dấu tiếng Việt (tiêu chí N9).
- [ ] **4.3** Chọn năng lực → đi qua `policy.decide` như mọi lời gọi (B2); toast hiện kết quả cổng (APPROVE/ASK/DENY + mã quy tắc). Chọn màn → mở màn.
- [ ] **4.4** Năng lực cần tham số bắt buộc → mở form tham số sinh từ hợp đồng CDS-12, không cho gọi thiếu.

## 5. TRÌNH SOẠN THẢO (S14) — nơi người và tác tử gặp nhau

- [x] **5.1** Lề trái mỗi dòng có hằng số phần cứng: chấm xanh ● = có `eide:fact` (hover hiện fact + nút mở nguồn đúng trang PDF); vạch đỏ ▎ = không nguồn, dòng nền hồng nhạt + chú thích "← hằng số không trỏ fact — G-FACT chặn merge".  ·  **✔ S14 · lề `NSRulerView`: ● xanh có `eide:fact`, ▎đỏ không nguồn. Hai dấu khác nhau cả HÌNH lẫn MÀU — bản in đen trắng và mắt mù màu vẫn phân biệt được**
- [x] **5.2** Tác tử chèn/sửa chú thích fact → sự kiện tới → lề cập nhật ngay, KHÔNG cần người thao tác (tiêu chí N10).  ·  **✔ S14 · `apDung` của §7.3 — màn ĐẦU TIÊN hiện thực nó; lề dựng lại từ `code.constant_guard` khi sự kiện tới**
- [x] **5.3** Người gõ tự do trong buffer; buffer bẩn (dirty) → băng vàng "Bộ đệm có sửa CHƯA LƯU của anh — tác tử muốn ghi tệp này sẽ bị hỏi (P-EDIT-01)".  ·  **✔ S14 · băng vàng nêu đúng P-EDIT-01; so NỘI DUNG chứ không đếm lần gõ, nên gõ rồi hoàn về như cũ là hết bẩn**
- [x] **5.4** Nút "Lưu" gọi `code.human_save`: commit `human:<tên>` + sự kiện `human.file_save` + mục Hoàn tác — xuất hiện đủ ba nơi trong ≤ 1 giây (tiêu chí N3). Luôn APPROVE mọi mức tự chủ (P-EDIT-02).  ·  **✔ S14 · `code.human_save` kèm `by: human:<tên>`; commit + seq hiện ngay, mục hoàn tác vào cột phải**
- [x] **5.5** Lưu gặp tệp trên đĩa đã đổi từ lúc mở → lỗi **`E6004 FILE_STALE`** (tên `E-SAVE-STALE` không vào được `errors.json`; chủ sản phẩm chốt 17/09) → tự chuyển luồng merge (mục 6), TUYỆT ĐỐI không ghi đè (B4).  ·  **✔ S14 · KHÔNG có nút ghi đè — một nút như thế biến merge ba bên thành tuỳ chọn. E6004 dẫn sang S15, bản của người nằm nguyên trong bộ đệm**
- [x] **5.6** Tác tử đang sửa tệp người đang xem → băng xanh "🤖 Tác tử đang sửa tệp này (Run #n, bước k/m) — xem diff trực tiếp"; người vẫn gõ được.  ·  **✔ S14 · băng XANH, người vẫn gõ được; sự kiện của tệp KHÁC không làm phiền**
- [ ] **5.7** Tự lưu (autosave): mặc định TẮT; bật trong cài đặt thì các lần tự lưu liên tiếp squash thành một commit khi người rời tệp (quyết định cho câu hỏi mở #1).  ·  **CHƯA — có chủ ý.** Mặc định TẮT thì đúng như tài liệu ghi, nhưng nửa sau ("bật trong cài đặt → squash các lần tự lưu liên tiếp thành một commit khi người rời tệp") chưa có: chưa có màn cài đặt nào để bật, và squash commit là việc của `code.human_save` chứ không của giao diện. Ghi ra vì commit ffddd7f nói nhầm mục 5 đã xong trọn 7/7 — thực tế 6/7

## 6. CÙNG SỬA — MERGE 3 BÊN VÀ XUNG ĐỘT MÃ

- [ ] **6.1** Tác tử gọi năng lực ghi mã trên tệp có buffer bẩn của người → cổng trả ASK, modal đúng 2 lựa chọn: "Lưu bản của tôi rồi tác tử tiếp tục" / "Tác tử chờ — tôi sửa tiếp" (P-EDIT-01). Không lựa chọn thứ ba.
- [x] **6.2** Hai chuỗi sửa cùng tệp → merge 3 bên trên tổ tiên chung; vùng không giao nhau tự hợp (commit merge ghi 2 cha); vùng giao nhau → dựng xung đột (P-EDIT-03).  ·  **✔ 3e360a9 · `git merge-file --diff3`; `test_MERGE_ba_ben_tu_hop_vung_khong_giao`**
- [x] **6.3** Màn xung đột MÃ tái dùng đúng component màn Xung đột tri thức (S8): hai vế cùng hàng — "Người sửa hh:mm" / "Tác tử Run #n" — nút Chọn A / Chọn B / Soạn tay; lựa chọn ghi qua `code.merge_conflict_resolve` kèm tên người (một component, hai nguồn dữ liệu — cấm viết màn riêng).  ·  **✔ S15 · dựng `EideTheXungDot` y như S8, có bài kiểm tìm đúng lớp ấy trong cây khung nhìn. Nút thứ ba là *Soạn tay*, và nó KHÔNG gọi năng lực — nó đưa người về S14**
- [ ] **6.4** Hoàn tác 3 mức chạy đúng: 1 commit; cả Run (revert chọn lọc `agent:run-<id>/*`, GIỮ commit người xen giữa — bài kiểm N4); về known-good (`project.rollback`).
- [ ] **6.5** Bài kiểm phủ định N5: dàn cảnh hai bên sửa cùng vùng, khẳng định KHÔNG tồn tại nhánh mã nào ghi đè không qua 6.2/6.3.

## 7. ĐỒNG BỘ SỰ KIỆN (nền của mọi thứ — làm TRƯỚC các màn)

- [x] **7.1** Kênh: giao diện subscribe thông báo JSON-RPC theo LOẠI sự kiện; mỗi màn khai báo tĩnh danh sách loại nó cần — có bảng đăng ký kiểm được, không màn nào subscribe "tất cả".  ·  **✔ 9fa1ffc · `EideDangKySuKien.BANG`; 22 loại lấy từ `EideMethod` (sinh từ openrpc.json), không chép tay. Nhật ký khai `TAT_CA` — hằng số CÓ TÊN, không phải `"*"` — vì §8 S2 đòi "nghe mọi loại"; có bài kiểm đòi ĐÚNG MỘT màn được dùng nó**
- [x] **7.2** Mỗi màn giữ `seq` sổ cái của lần vẽ gần nhất; sự kiện đến áp tuần tự; phát hiện nhảy quãng hoặc mất daemon → nhãn "Dữ liệu cũ — bấm để tải lại" ≤ 2 giây (B6/N6); bấm = query lại từ seq đã có.  ·  **✔ 9fa1ffc · phát hiện nhảy quãng ở `EidePhien` chứ không ở từng màn (`seq` là số TOÀN CỤC); nhảy quãng có câu RIÊNG khác mất daemon; dải có nút Tải lại bấm được**
- [~] **7.3** Sự kiện tới màn đang ĐÓNG → chỉ tăng badge nhóm; tới màn đang MỞ → vẽ lại đúng phần liên quan (diff render, không reload cả màn).  ·  **NỬA ĐẦU XONG 9fa1ffc** (badge cho màn đóng, cộng chung với mục CHỜ TÔI). **Nửa sau CHƯA**: cách lùi hiện tại là nạp lại CHÍNH màn ấy, gộp trong 0,4 s — nạp ngay ở mỗi sự kiện làm màn Nhật ký mất 7,68 s. Điểm mở rộng `EideManCoSo.apDung`; mặc định trả `false` để đếm được còn bao nhiêu màn chưa làm
- [x] **7.4** `project.watch` chạy nền: tệp đổi ngoài EIDE → `human.file_external` kèm diff tóm tắt; bỏ qua thay đổi do chính tác tử vừa ghi (đối chiếu hash).  ·  **✔ 3e360a9 · `project.watch`, lọc theo BĂM nội dung chứ không theo thời gian**
- [ ] **7.5** Lượt kế của tác tử: `memory.compose` nhận khối "thay đổi của người từ lượt trước" (tệp + diff tóm tắt); người sửa trúng vùng thuộc kế hoạch đang chạy → kích `plan.replan`, cấm ghi đè.
- [ ] **7.6** Diff tóm tắt đưa vào ngữ cảnh: ≤ 200 dòng gửi nguyên văn; hơn thì tóm tắt bằng mô hình, ghi rõ "đã tóm tắt" (quyết định cho câu hỏi mở #2).

## 8. TỪNG MÀN — THÀNH PHẦN BẮT BUỘC (mỗi màn: năng lực đứng sau · thành phần · trạng thái rỗng · sự kiện subscribe)

### Nhóm 1 · DỰ ÁN
- [ ] **S1 Tổng quan** — `project.status`, `target.detect` · 4 ô KPI (fact, chờ tôi, hoàn tác, chip đã ghim) + bảng feature (trạng thái, cổng đang mở) · rỗng: "dự án mới — chưa có feature; bước kế: ra lệnh đầu tiên" · nghe: `run.*`, `human.*`, thay đổi pending/undo.
- [ ] **S2 Nhật ký** — `view.timeline` · dòng thời gian MỌI sự kiện (máy + người), mới nhất trên; bộ lọc theo Run, theo tác giả, theo loại; chỉ báo chuỗi băm liền mạch ✔ · rỗng: "sổ cái chưa có sự kiện; bước kế: tạo dự án/ra lệnh" · nghe: mọi loại.
- [x] **S3 Bản đồ luồng** — `view.timeline` lọc theo pha (hết màn mồ côi) · sơ đồ P0→P7, pha hiện tại tô đậm, bấm pha mở S2 lọc sẵn · nghe: `run.*`.  ·  **✔ tám pha P0–P7 rút từ `bpd.js`, có bài kiểm Python đối chiếu ngược. Pha hiện tại SUY từ sổ cái chứ không từ một biến trạng thái. Nói ra số lời gọi NGOÀI pha (68/244 năng lực có trong tám quy trình). Bấm pha: chưa truyền được bộ lọc sang S2, màn nói thẳng**

### Nhóm 2 · TRI THỨC
- [ ] **S4 Nhập tài liệu** — `archive.*`, `ingest.*`, `extract.*` · vùng kéo-thả + bảng nguồn (loại, số fact trích, trạng thái duyệt theo chính sách) + tiến độ trích đang chạy · rỗng: "chưa nhập tài liệu nào; kéo PDF/SVD/BOM vào đây" · nghe: `ingest.*`.
- [ ] **S5 Hộ chiếu chip** — `passport.query`, `view.provenance` · bảng thanh ghi: tên, địa chỉ HỆ 16, tầng (vàng/bạc/nâu), cột nguồn bấm mở ĐÚNG TRANG PDF kèm bbox · ô mâu thuẫn hiện ⚠ trỏ S8 · rỗng: "chưa ghim chip; bước kế: nhập datasheet hoặc target.detect".
- [ ] **S6 Hộ chiếu mạch** — `board.*`, `diagram.pinmap` · bảng net/chân/chức năng/kiểm xung đột + trạng thái khai báo mạch lab (`board.mark_lab`) ghi TÊN NGƯỜI khai · rỗng: "chưa có schematic/BOM".
- [ ] **S7 Bản đồ tri thức & hỏi đáp** — `view.kg_map`, `view.rag_ask` · đồ thị thu phóng (node fact/tài liệu/mã, cạnh CITES/USES/CONFLICT) + ô hỏi; câu trả lời BẮT BUỘC kèm trích dẫn nhấp mở nguồn, không nguồn thì trả "không đủ căn cứ" · nghe: `kg.*`.
- [ ] **S8 Xung đột tri thức** — `kg.conflicts`, `kg.resolve_conflict` · danh sách xung đột mở; mỗi cái: hai vế CÙNG HÀNG, mỗi vế = giá trị + tầng + nguồn bấm được + nút chọn; đã quyết → dòng lịch sử ghi tên người + thời điểm · rỗng: "không còn xung đột mở — quyết định gần nhất: …" · component này DÙNG CHUNG cho xung đột mã (6.3).

### Nhóm 3 · THIẾT KẾ
- [ ] **S9 Làm rõ yêu cầu** — `chat.restate`, `chat.clarify` · thẻ ý hiểu + chuỗi bước + câu hỏi gộp (mỗi câu có mặc định an toàn, người bỏ qua được).
- [ ] **S10 Yêu cầu & kiến trúc** — `req.*`, `arch.*` · bảng FR/NFR với cột khả thi (`req.ground_hw` — căn cứ phần cứng thật) + danh sách ADR (quyết định kiến trúc) kèm fact trích dẫn.
- [ ] **S11 Lược đồ** — `diagram.*` · khung xem 6 loại lược đồ + chỉ báo đồng bộ hai chiều mã ↔ hình (`diagram.sync`): lệch thì băng vàng + nút đồng bộ.
- [ ] **S12 Kế hoạch** — `plan.create` · bảng bước: mô tả + CỘT FACT TRÍCH DẪN (bấm mở nguồn) + `missing[]` hiện thành khối "còn thiếu" đầu bảng · rỗng: "chưa có kế hoạch cho feature này".
- [ ] **S13 Tài liệu** — `doc.*` · bảng tài liệu sinh (trạng thái, mục stale) + nút sinh lại; `doc.style_check`: tiếng Việt ưu tiên + mọi khẳng định có nguồn.

### Nhóm 4 · MÃ NGUỒN
- [ ] **S14 Trình soạn thảo** — toàn bộ mục 5 của checklist này.
- [ ] **S15 Diff & cổng merge** — `code.review`, `code.merge` · khung diff hai cột + bảng cổng (G-FACT, G1/G3/G4/G5): mỗi cổng trạng thái ✅/⛔/⏳ + lý do chặn bấm mở đúng chỗ; merge xong hiện mã commit + tác giả máy-đọc-được + trailer seq + hạn hoàn tác.

### Nhóm 5 · CHẠY THỬ
- [x] **S16 Mô phỏng** — `sim.*` · log UART thật từ simavr + bảng kỳ vọng ĐẠT/TRƯỢT · rỗng: "chưa có lượt mô phỏng; bước kế: tác tử chạy sim.run ở bước N".  ·  **✔ đọc `tool.report` của `sim.run` từ sổ cái, KHÔNG tự chạy mô phỏng lúc mở. Giữ nguyên BA trạng thái kỳ vọng — `unverified` tách khỏi `failed`; hết giờ tách khỏi chạy xong**
- [!] **S17 Dò board** — `discover.*` · rỗng khi không board: "chưa có bo mạch cắm vào — nhóm này chờ một vật ngoài máy tính; discover.ports thấy 0 cổng" (B5, không dữ liệu giả).  ·  **CHẶN: chờ một bo mạch — 8/12 năng lực nhóm này chặn bởi vật ngoài máy tính**
- [ ] **S18 Log & serial** — `debug.log_stats`, `debug.ask_at`, `target.serial` · thống kê log + hỏi-tại-dòng (trả lời neo đúng dòng); phần serial rỗng khi không board, phần log dùng được với log mô phỏng.
- [!] **S19 Gỡ lỗi probe** — `debug.*`, `target.probe_*` · khung EvidencePack / giả thuyết / thí nghiệm; rỗng khi không probe.  ·  **CHẶN: chờ mạch nạp**
- [!] **S20 Bench** — `bench.*` · bảng so mô phỏng ↔ board thật; rỗng nêu rõ cần cả hai vế.  ·  **CHẶN: chờ cả mô phỏng lẫn board thật để SO hai vế**

### Nhóm 6 · HỆ THỐNG
- [x] **S21 Môi trường** — `env.doctor`, `tools.lock` · bảng công cụ: phiên bản, hash khớp lockfile ✅/⚠; nút sửa KHÔNG bao giờ chạy sudo.  ·  **✔ `env.check` theo ISA; BA trạng thái (đạt / chưa cài / **có nhưng CŨ**) vì `ok=false` gộp mất hai việc khác hẳn nhau. Nút sửa gọi `env.guide_install` (R0) — KHÔNG `env.install` (R4), có bài kiểm cấm**
- [x] **S22 Mô hình & chi phí** — · bảng vai → mô hình + KPI chi phí vòng/ngày + thanh hạn mức; chạm hạn mức → sự kiện + băng cảnh báo, không chạy tiếp im lặng.  ·  **✔ `budget.state` + thanh hạn mức; `sap_het` giữ BA giá trị (`nil` = chưa biết). Bảng VAI → MÔ HÌNH CHƯA có — [DEV-136]**
- [x] **S23 Công cụ tự tạo** — `tool.*` · bảng công cụ tạm/thăng cấp; đường thăng cấp bắt buộc qua sandbox + bài kiểm (G-TOOL), hiện số lần dùng đạt.  ·  **✔ đếm lượt ĐẠT theo TOOL-08 (≥3 lần, 0 lỗi); dựng từ sự kiện `tool.report`, tức LỊCH SỬ CHẠY chứ không phải danh mục — [DEV-136]**
- [x] **S24 Registry** — `registry.*` · bảng gói .hkp: chữ ký, license, huy hiệu (verified/bench).  ·  **✔ `registry.search`; cột huy hiệu đứng TRƯỚC phiên bản vì badge là thứ đắt nhất hệ thống. Không chữ ký là CẢNH BÁO, không phải ô trống**
- [ ] **S25 Chính sách tự chủ** — `policy.*` · bảng **54** quy tắc (49 + P-EDIT-01/02/**03/04** + P-RUN-01) chỉ-đọc + mức hiện tại + đổi mức qua `policy.set_autonomy`; ký lại chính sách ghi rõ "làm bằng lệnh dòng lệnh, không phải năng lực".

## 9. TRỢ NĂNG (accessibility) & BÀN PHÍM

- [ ] **9.1** Điều hướng đủ bằng bàn phím: ⌘K bảng lệnh; ⌘1…⌘6 nhảy nhóm; ⌘W đóng tab; ⌘S = `code.human_save`; Esc đóng overlay.
- [ ] **9.2** Mọi phần tử tương tác có nhãn trợ năng tiếng Việt cho VoiceOver; thứ tự focus theo thứ tự thị giác.
- [ ] **9.3** Modal ASK: focus nhốt trong modal, Esc = lựa chọn an toàn ("Tác tử chờ"), KHÔNG bao giờ Esc = đồng ý.
- [ ] **9.4** Hoạt ảnh tôn trọng "Giảm chuyển động" của hệ điều hành (tắt nhấp nháy 2B.5, giữ đổi màu tĩnh).

## 10. BÀI KIỂM NGHIỆM THU — ánh xạ N1–N10 (chạy trên cửa sổ thật, không headless)

- [ ] **10.1** N1 → bài kiểm 3.2 · N2 → 2E.4 · N3 → 5.4 · N4 → 6.4 · N5 → 6.5 · N6 → 7.2 · N7 → 2.3 · N8 → 2B.1 · N9 → 4.2 · N10 → 5.2. Mỗi bài kiểm là một kịch bản tự động thao tác UI thật + đọc sổ cái đối chiếu.
- [ ] **10.2** Thêm bài kiểm phủ định cho B1: tắt daemon → khẳng định KHÔNG widget nào tự đổi trạng thái.
- [ ] **10.3** Toàn bộ 10 bài chạy trong CI trước mọi merge nhánh giao diện; trượt 1 bài = chặn merge.

## 11. ĐỊNH NGHĨA HOÀN THÀNH (Definition of Done) CHO MỖI MÀN

- [ ] **11.1** Header chuẩn 2C.4 ✔ · trạng thái rỗng 2 phần ✔ · danh sách sự kiện subscribe khai báo ✔ · nhãn stale hoạt động ✔ · trợ năng 9.2 ✔ · ảnh chụp so mẫu demo EIDE_UI_Demo_v2.html không lệch cấu trúc ✔ · một dòng trong bảng theo dõi: mã màn, commit, ngày, người/tác tử làm.
- [ ] **11.2** Tác tử KHÔNG đánh dấu `[x]` mục nào thiếu bằng chứng (bài kiểm hoặc ảnh chụp); mục bị chặn ghi `[!]` + lý do + hỏi người.

---
*Hết EIDE-UXC-31 v1.0 — 17/09/2026. Tài liệu này đặt tại `docs/md/EIDE-UXC-31.md` trong repo và được trỏ từ CLAUDE.md; bản Word đối chiếu sinh từ tệp này khi cần nộp hồ sơ.*
