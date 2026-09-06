# ADR-01 — Engine hiển thị: Scintilla-Cocoa hay TextKit 2

| | |
|---|---|
| **Trạng thái** | ✅ **Đã chốt (Accepted)** |
| **Ngày** | 20/08/2026 · chốt 20/08/2026 |
| **Quyết định** | **Ứng viên 4** — TextKit 2 qua `NSTextView`, view chỉ giữ cửa sổ ~2 MB, tài liệu nằm trong piece table trên mmap |
| **PoC** | PoC-A (SAD §8) |
| **Yêu cầu liên quan** | NFR-PERF-03, NFR-PERF-04, NFR-PERF-05, NFR-USE-02, FR-CORE-001, FR-CORE-002 |
| **Số liệu thô** | `benchmarks/poc-a-adr01.txt` |
| **Tái lập** | `scripts/run-poc-a.sh` |
| **Người chốt** | Vũ Trí Công (Founder) |

---

## 1. Bối cảnh

SAD nêu **Scintilla-Cocoa là mặc định** cho engine hiển thị, **TextKit 2 là đối chứng**, và
giao PoC-A trả lời bốn câu:

1. latency gõ p95 trên file 500 MB,
2. marked-text với Telex (EVKey),
3. multi-caret 1.000 caret,
4. column mode 10.000 dòng.

PoC-A đo ba câu đầu bằng máy. **Câu 2 chưa đo** — nó cần người thật gõ bằng bộ gõ thật, và
đó là tiêu chí CHẶN PHÁT HÀNH (NFR-USE-02), nên không được đoán. Xem §7.

Ràng buộc đi kèm, từ SRS §3.3:

- **NFR-PERF-04** — latency gõ p95 ≤ 16 ms.
- **NFR-PERF** — *"tiêu thụ bộ nhớ với file lớn ≤ 1,5 lần kích thước file"*.

Ràng buộc thứ hai hóa ra là thứ quyết định, và nó không phải câu SAD giao PoC-A đi hỏi.

### 1.1 Bốn ứng viên, không phải hai

SAD giao hai. Đo xong hai ứng viên ấy thì lộ ra rằng câu hỏi đặt sai (§3.2), nên PoC đẻ thêm
hai ứng viên nữa. Cả bốn đều được dựng thật và đo bằng cùng một bộ đo:

| | Nội dung nằm ở đâu | Kết quả |
|---|---|---|
| **1. Scintilla-Cocoa 5.5.5** | gap buffer riêng của Scintilla | đo được |
| **2. TextKit 2 (`NSTextView`)** | `NSTextStorage` giữ cả tài liệu | đo được |
| **3. TextKit 2 + `NSTextContentManager` tùy biến** | piece table, cấp theo yêu cầu | **KHÔNG chạy** (§6) |
| **4. TextKit 2 + `NSTextView` giữ CỬA SỔ 2 MB** | piece table, view chỉ giữ phần đang xem | đo được — **đề xuất** |

---

## 2. Cách đo

Máy: Apple M2 Pro, 12 lõi, macOS 26.5.2, arm64 native. Nội dung thử là dòng tiếng Việt **có
dấu**, độ dài không đều — không dùng ASCII lặp lại, vì engine nào cũng có đường nhanh cho văn
bản một byte một ký tự, còn người dùng của sản phẩm này thì không gõ ASCII.

Mỗi cặp (engine, cỡ) chạy trong **một tiến trình riêng**. Chung tiến trình thì
`phys_footprint` của engine đo sau bị trừ đi phần engine trước vừa trả lại — bản đo đầu đã ra
số âm — và cỡ lớn có thể bị hệ điều hành giết, mất cả báo cáo.

Phép đo **tự chứng minh** bốn điều ở mỗi lần chạy, và cả bốn đều từng bắt được lỗi thật:

| Kiểm | Vì sao có | Đã bắt được gì |
|---|---|---|
| Đếm lần vẽ (SCN_PAINTED / `draw(_:)`) | view lười vẽ thì số đo là số của việc không làm gì | Scintilla vẽ **0/100** lần trong bản đo đầu (§5.1) |
| Độ dài nội dung tăng đúng số phím | caret sai chỗ hoặc lần chèn bị nuốt cũng cho số đẹp | bắt được lỗi lẫn đơn vị byte/UTF-16 |
| Cỡ khung nhìn và số dòng đang hiện | "gõ nhanh" trên view cao 0 pixel là vô nghĩa | xác nhận cả ba đo trên 1100×480 pt |
| **Chụp màn hình từng engine** | bộ đếm nói "có gọi draw", nó KHÔNG nói "có chữ" | ứng viên 3 vẽ đủ số lần mà màn hình trắng trơn (§5.3) |

Gõ ở **giữa** tài liệu, không phải đầu: chèn ở offset 0 là trường hợp dễ nhất của mọi cấu trúc
dữ liệu, và cũng là trường hợp người dùng ít làm nhất trên file lớn.

---

## 3. Số liệu PoC-A

### 3.1 Latency gõ (300 phím, ép vẽ xong sau mỗi phím)

p95 / max, mili giây:

| Cỡ file | Scintilla | TextKit 2 (cả tài liệu) | **Cửa sổ 2 MB** |
|---|---|---|---|
| 1 MB | 12,30 / 16,23 | 1,24 / 1,74 | 2,24 / 2,70 |
| 10 MB | 8,39 / 29,29 | 1,23 / 1,44 | 3,52 / 8,22 |
| 50 MB | 11,83 / 16,55 | 1,13 / 1,40 | 3,40 / 7,65 |
| 100 MB | 12,41 / 31,29 | 1,11 / 1,36 | 3,40 / 8,01 |
| 250 MB | 14,14 / 73,63 | 1,11 / 1,30 | 3,30 / 7,47 |
| **500 MB** | 8,86 / **148,73** | 1,23 / 1,78 | **3,31 / 8,53** |

Cả ba **đạt** NFR-PERF-04 (p95 ≤ 16 ms) ở mọi cỡ. Nhưng đuôi thì khác hẳn:

- **TextKit 2 phẳng** ở 1,1–1,2 ms, đuôi max không quá 1,8 ms.
- **Cửa sổ 2 MB** phẳng ở 3,3 ms, đuôi max ≤ 8,5 ms — vẫn dưới nửa khung hình. Chậm hơn ứng
  viên 2 vì mỗi lần gõ phải quy đổi offset tài liệu → offset UTF-16 trong cửa sổ; chi phí ấy
  bị chặn trên bởi cỡ cửa sổ chứ không bởi cỡ file, và đó là lý do nó cũng phẳng.
- **Scintilla có đuôi xấu và xấu dần theo cỡ**: max 148 ms ở 500 MB là **9 khung hình bị
  nuốt** trong một lần gõ. p95 không thấy nó; người dùng thì thấy.

### 3.2 Bộ nhớ — chỗ hai ứng viên của SAD cùng trượt

`phys_footprint` (con số Activity Monitor hiện), sau khi nạp:

| Cỡ file | Scintilla | TextKit 2 | **Cửa sổ 2 MB** | Trần NFR (1,5×) |
|---|---|---|---|---|
| 10 MB | 48,1 MB — 4,81× | 23,5 MB — 2,35× | 16,0 MB — 1,60× | 15 MB |
| 50 MB | 171,0 MB — 3,42× | 104,3 MB — 2,09× | **8,7 MB — 0,17×** | 75 MB |
| 100 MB | 323,8 MB — 3,24× | 188,5 MB — 1,89× | **16,2 MB — 0,16×** | 150 MB |
| 250 MB | 784,1 MB — 3,14× | 464,3 MB — 1,86× | **16,1 MB — 0,06×** | 375 MB |
| **500 MB** | **1.555 MB — 3,11×** | **928 MB — 1,86×** | **13,3 MB — 0,03×** | 750 MB |

**Hai ứng viên SAD giao đều vi phạm trần bộ nhớ ở mọi cỡ đã đo.** Scintilla tốn gấp đôi
TextKit 2 vì nó giữ nội dung trong gap buffer riêng **cộng** chỉ mục dòng riêng của nó.

Đây là phát hiện quan trọng nhất của PoC-A, và nó **không nằm trong bốn câu hỏi SAD giao**.
Nó nói rằng câu hỏi đã đặt sai: không phải "engine nào giữ tài liệu tốt hơn", mà **engine nào
chịu được việc KHÔNG giữ tài liệu** — vì tài liệu đã có chỗ của nó rồi, là piece table trên
mmap của ADR-02.

Ứng viên 4 trả lời đúng câu hỏi ấy: **13,3 MB cho file 500 MB**, tức 1/56 trần cho phép. Con
số không tăng theo cỡ file vì nó không phụ thuộc cỡ file — view chỉ giữ 2 MB, phần còn lại là
trang mmap sạch mà hệ điều hành thu hồi được bất cứ lúc nào.

### 3.3 Multi-caret và column mode

| | Scintilla | TextKit 2 | Cửa sổ 2 MB |
|---|---|---|---|
| 1.000 caret (FR-CORE-001) | 3,8–5,3 ms | **KHÔNG hỗ trợ** | chưa làm |
| Column mode 10.000 dòng (FR-CORE-002) | 95–105 ms | **KHÔNG hỗ trợ** | chưa làm |

Ba chữ khác nhau, và khác nhau thật:

- **Scintilla**: có sẵn, nhanh.
- **TextKit 2 qua `NSTextView`**: *không hỗ trợ*, dứt khoát. `selectedRanges` nhận nhiều range
  nhưng đó là nhiều vùng **chọn**, không phải nhiều caret **gõ được**: một phím chỉ thay thế
  vùng chính. Và không có khái niệm chọn theo khối.
- **Cửa sổ 2 MB**: *chưa làm*, không phải không làm được. Ở hướng này vùng chọn là của GEditor
  (nó phải tự quản để ánh xạ cửa sổ ↔ tài liệu), nên không có rào chắn kỹ thuật — chỉ là công
  việc chưa viết. Bảng so sánh phải phân biệt hai chuyện đó, nếu không nó nói dối.

### 3.4 Nạp và nhảy tới cuối file

| Cỡ 500 MB | Scintilla | TextKit 2 | Cửa sổ 2 MB |
|---|---|---|---|
| nạp | 0,389 s | 2,808 s | **0,293 s** |
| nhảy tới dòng cuối | 0,002 s | 0,001 s | 0,004 s |
| nạp lại cửa sổ khi cuộn ra ngoài | — | — | ~4,5 ms |

Số "nạp" không kể thời gian đọc đĩa — nội dung đã nằm sẵn trong RAM khi bấm giờ. Nó đo phần
"đưa vào engine".

Nghịch lý đáng ghi: ở 500 MB, Scintilla nạp nhanh gấp 7 lần TextKit 2 nhưng gõ có đuôi xấu gấp
80 lần. Nó trả tiền trước một lần cho gap buffer riêng, rồi trả tiếp ở mỗi lần vẽ.

### 3.5 Universal binary (NFR-PORT-01)

Rủi ro lớn nhất khi mang Scintilla vào là 41.000 dòng C++ có dựng được cho cả hai kiến trúc
trong một lệnh hay không. **Có**:

```
swift build -c release --arch arm64 --arch x86_64 --product geditor-poca
Architectures in the fat file: geditor-poca are: x86_64 arm64
```

Nên nếu ADR-01 chốt không chọn Scintilla thì cũng **không phải** vì portability.

---

## 4. Quyết định

**TextKit 2 qua `NSTextView`, view chỉ giữ một cửa sổ ~2 MB, tài liệu nằm trong piece table
trên mmap (ứng viên 4).** Vũ Trí Công chốt ngày 20/08/2026.

Vì sao:

1. **Là ứng viên duy nhất đạt trần bộ nhớ** — 0,03× ở 500 MB so với trần 1,5×. Hai ứng viên
   SAD giao đều trượt ở mọi cỡ (§3.2).
2. **Giữ `NSTextView`, nên giữ `NSTextInputClient`** — IME tiếng Việt vẫn là đường của AppKit,
   không phải đường ta tự viết. Với một tiêu chí CHẶN PHÁT HÀNH (NFR-USE-02) thì đây là lý do
   nặng ký nhất, nặng hơn cả bộ nhớ.
3. **Latency đạt yêu cầu với biên rộng** — p95 3,3 ms so với trần 16 ms, và phẳng theo cỡ file.
4. **Nạp nhanh nhất trong ba ứng viên** (0,293 s cho 500 MB).

Cái giá đã được chấp nhận cùng quyết định:

- **Multi-caret và column mode phải tự viết.** Scintilla cho không hai thứ này. Đây là chi phí
  thật và không nhỏ.
- **Mọi thứ tính trên cả tài liệu phải do lõi làm**: tìm kiếm, thay thế, số dòng, nhảy tới
  dòng. Điều này vốn đã đúng với kiến trúc hiện tại (lõi độc lập UI, NFR-MNT-01) — `FindInFiles`,
  `CSVEngine`, `DocumentOps` đều đã chạy trên `TextBuffer` chứ không trên view — nên phần lớn
  không phải chi phí mới.
- **Ánh xạ cửa sổ ↔ tài liệu là chỗ dễ sai**: sửa vắt qua biên cửa sổ, undo vắt qua biên, con
  trỏ khi cửa sổ bị nạp lại. Đây là nơi cần test dày nhất khi làm thật.

---

## 5. Ba lần suýt kết luận sai

### 5.1 Scintilla "nhanh gấp 30 lần" — vì nó không vẽ gì

Bản đo đầu cho Scintilla **0,03 ms mỗi phím**, TextKit 2 0,9 ms. Nghe như thắng tuyệt đối.

Bộ đếm SCN_PAINTED nói: **0 lần vẽ trên 100 phím**. `NSView.display()` là đủ cho view vẽ trực
tiếp, nhưng với view có layer nó chỉ đánh dấu layer cần vẽ — nét vẽ thật xảy ra khi
CoreAnimation commit. Scintilla rơi vào trường hợp thứ hai, TextKit 2 thì không, nên cùng một
dòng lệnh `display()` đo hai thứ khác nhau ở hai bên.

Thêm `CATransaction.flush()` **ở một chỗ dùng chung cho cả hai** (`flushPendingDrawing()` trong
`PoCRunner`, không đặt trong từng adapter): Scintilla thành 8–12 ms p95. Chênh lệch thật
**ngược dấu** với chênh lệch giả.

### 5.2 TextKit 2 suýt bị đo bằng hàm đổi chỉ số của tôi

Bản đầu chèn theo vị trí **byte**, còn `NSTextStorage` đánh chỉ số theo **UTF-16**, nên adapter
TextKit 2 phải quét cả chuỗi để đổi — O(n) ở **mỗi** lần gõ, trên 500 MB. Số đo khi ấy nói về
hàm đổi chỉ số của tôi chứ không nói gì về TextKit 2.

Sửa bằng cách cho mỗi engine giữ caret nội bộ theo đơn vị riêng, và đặt caret **ngoài** vùng
bấm giờ. Cùng bài học lặp lại ở ứng viên 4, nơi phép quy đổi bị chặn trong phạm vi cửa sổ 2 MB
— đó là thiết kế, không phải may.

### 5.3 Bộ đếm nói "có vẽ", màn hình nói "trắng trơn"

Ứng viên 3 báo `số lần vẽ 20/20 phím` và `nội dung tăng đúng` — hai phép tự kiểm đều xanh. Chụp
màn hình thì khung chữ **trắng hoàn toàn**: `draw(_:)` có được gọi, nhưng TextKit không dựng
được đoạn nào để vẽ.

Từ đó bộ đo có thêm cột "số đoạn đã dựng bố cục", và quy trình có thêm một bước không bỏ được:
**chụp màn hình từng engine trước khi tin bảng số**. (Chính bước này cũng suýt cho một kết luận
sai theo chiều ngược lại: ba lần chụp đầu của ứng viên 4 ra màn hình trắng, nhưng là do tôi
chụp trượt vị trí cửa sổ — chụp theo đúng khung cửa sổ thì chữ hiện đủ.)

---

## 6. Ứng viên 3 chết vì sao — `NSTextContentManager` tùy biến

Đây là hướng mà bản ADR-01 đầu tiên **đề xuất**, dựa trên tài liệu của Apple: `NSTextContentManager`
là điểm mở rộng để cấp nội dung từ kho bất kỳ. Dựng thật thì không chạy.

Hai triệu chứng, đo được, tái lập được:

1. **TextKit hỏi nội dung đúng một lần, lấy một đoạn, rồi thôi.** Không đoạn nào được dựng bố
   cục; màn hình trắng. Thay đúng lớp ấy bằng `NSTextContentStorage` của Apple mà **giữ nguyên
   toàn bộ mã vẽ**: 64 đoạn được dựng bố cục và chữ hiện ra. Vậy lỗi nằm ở content manager, không
   ở phần vẽ.
2. **Đưa `NSTextLocation` của mình vào API bố cục thì nổ**:

   ```
   -[NSCountableTextLocation compare:] receiving unmatching type byte 1046292
   ```

   TextKit 2 tự đúc `NSCountableTextLocation` bên trong và đem so với kiểu của ta.

Đã loại trừ hai giả thuyết rẻ trước khi kết luận: **không phải** do lệch đơn vị byte ↔ UTF-16
(chạy lại với nội dung thuần ASCII, nơi hai con số bằng nhau, vẫn hỏng y hệt), và **không phải**
do `NSTextContainer` rộng vô hạn.

Kết luận: trên macOS 26.5, `NSTextContentManager` tùy biến với `NSTextLocation` riêng **không
lái được TextKit 2**. Mã vẫn nằm trong repo (`--engine lazy`) để ai muốn tự kiểm chứng hoặc thử
lại ở bản macOS sau.

Điều này giết **cơ chế**, không giết TextKit 2 — và ứng viên 4 là đường vòng qua nó.

---

## 7. Marked-text tiếng Việt (NFR-USE-02) — đã đo bằng máy

**Cập nhật 20/08/2026: câu hỏi thứ hai của PoC-A đã có câu trả lời bằng máy.**

`geditor-poca --ime` mô phỏng đúng giao thức mà EVKey, OpenKey và bộ gõ Vietnamese của macOS
dùng — `NSTextInputClient`: bộ gõ chặn phím, tự ghép vần, gửi `setMarkedText:` cho từng bước
soạn rồi `insertText:` khi chốt.

| Kịch bản (gõ Telex) | Scintilla | `NSTextView` (ứng viên 2 và 4) |
|---|---|---|
| `vieejt` → việt — dấu nặng lùi vào giữa âm tiết | ✅ | ✅ |
| `ddaay` → đây — đ đầu âm tiết | ✅ | ✅ |
| `toans` → toán — dấu trên nguyên âm chính | ✅ | ✅ |
| huỷ soạn giữa chừng (Esc) | ✅ | ✅ |
| soạn tiếp sau một âm tiết đã chốt | ✅ | ✅ |

Kèm **đối chứng âm**: một `NSTextInputClient` cố tình mắc lỗi kinh điển (nối thêm thay vì thay
vùng marked) bị bắt 5/5. Không có nó thì mọi dấu ✅ ở trên chỉ chứng minh phép kiểm luôn xanh.

**Hệ quả cho quyết định: IME KHÔNG còn phân biệt được hai ứng viên.** Cả hai xử lý đúng giao
thức, nên §4 giữ nguyên và được củng cố — ứng viên 4 giữ `NSTextView` nên thừa hưởng đúng
đường IME đã kiểm.

Ứng viên 3 thì **không có `NSTextInputClient` nào cả** — bỏ `NSTextView` là phải tự hiện thực
giao thức bộ gõ. Đó là lý do thứ hai để loại nó, độc lập với lý do ở §6.

**Vẫn còn một việc phải làm bằng tay trước khi phát hành.** Phép kiểm này chứng minh ỨNG DỤNG
xử lý đúng giao thức; nó không chứng minh EVKey gửi đúng chuỗi ấy, và không bắt được lỗi ở
tầng phím vật lý hay phím tắt. Cần một lần gõ thật với EVKey:

Cần kiểm ở cả **Scintilla** và **TextKit 2** (ứng viên 2 và 4 dùng chung `NSTextView` nên chỉ
cần kiểm một lần):

1. `vieejt` → `việt` — dấu vào đúng nguyên âm, không nhảy ra sau.
2. `ddaay` → `đây` — `đ` ở đầu âm tiết.
3. `toans` → `toán` — dấu trên nguyên âm chính của nguyên âm đôi.
4. Undo giữa chừng chuỗi marked-text về đúng trạng thái trước đó.
5. Chữ đang soạn có gạch chân và không nhảy vị trí.

Chạy: `swift build -c release --product geditor-poca` rồi mở app, bấm **"Nạp 1 MB để gõ thử
IME"**, đổi engine bằng nút chọn ở trên cùng và gõ vào từng bên. Nút **"Kiểm bộ gõ bằng máy"**
chạy lại bảng ở trên bất cứ lúc nào.

**Chưa đo, và cố ý không đo:**

- **x86_64.** Cả ba engine không có phần nào phụ thuộc kiến trúc theo cách đáng ngờ, và số đo
  qua Rosetta trên Apple Silicon không nói được gì về Intel thật (bài học từ PoC-C).
- **Cuộn liên tục qua nhiều cửa sổ.** Mới đo chi phí nạp lại một cửa sổ (~4,5 ms). Cuộn nhanh
  liên tục qua hàng chục cửa sổ là một phép đo riêng, và nó thuộc về bước làm thật.
- **1 GB.** SAD giao PoC-A ở 500 MB. Xu hướng ở §3.2 đã phẳng rõ với ứng viên 4.

---

## 8. Việc chốt ADR-01 mở khóa

Từ lúc chốt, những mục sau hết bị chặn và có thể làm:

| | |
|---|---|
| FR-DOC-301 · 302 | tab, chia đôi màn hình |
| FR-CORE-001 · 002 · 003 | multi-caret, column mode, Column Editor — **phải tự viết** |
| FR-CORE-015 | word wrap |
| FR-ENC-205 | hiện ký tự ẩn |
| FR-CSV-402 · 403 | tô màu theo cột, table view |
| FR-SRCH-107 | tô nền dòng đánh dấu + chín màu bookmark ở lề |
| TC-IME-02 | Telex + multi-caret (chờ FR-CORE-001) |

Thứ tự làm đề xuất: **lớp cửa sổ trước** (ánh xạ cửa sổ ↔ tài liệu, cuộn, caret) vì mọi thứ
còn lại đứng trên nó, và nó cũng là chỗ dễ sai nhất theo chính §4.

## 8bis. Ngắt dòng mềm (FR-CORE-015) — số đo và giới hạn đã biết

Word wrap là mục đầu tiên phá giả định nền của lớp cửa sổ ("chiều cao dòng đều nhau"), nên
phần này ghi lại số đo, vì chúng quyết định cách làm chứ không phải ngược lại.

**Không thể biết chính xác chiều cao tài liệu khi bật ngắt dòng.** Đo trên MacBook đang dùng,
TextKit 2 dựng bố cục ĐẦY ĐỦ một cửa sổ:

| Nội dung | Thời gian |
|---|---|
| 2 MB mã nguồn (~27.000 dòng) | **437 ms** |
| 2 MB toàn dòng 50.000 ký tự | 140 ms |
| 512 KB mã nguồn | 107 ms |
| 256 KB mã nguồn | 56 ms |

Ngân sách một lần nạp cửa sổ là ~4,5 ms, nên ép dựng bố cục là loại thẳng. Cách làm:
`rowsPerLine` ƯỚC LƯỢNG từ độ dài dòng của chính cửa sổ (`TextWindow.rowsPerLine`), rồi đưa
vào `VerticalGeometry` của lõi. Đây là ước lượng **thấp** — ngắt thật gãy ở biên từ — nên
thanh cuộn hơi ngắn hơn thực tế ở tài liệu lớn. Phần chữ thì không bao giờ mất, vì khung cuộn
luôn được nới đến ít nhất là đáy khung chữ, mà khung chữ tự nới theo bố cục thật.

**Cái bẫy đắt nhất: thùng chữ rộng vô hạn.** Chế độ TẮT ngắt dòng thoạt nghe là chế độ rẻ
nhất — không phải tính chỗ gãy. Nhưng đặt `NSTextContainer` rộng vô hạn là bắt TextKit dựng
bố cục cả cửa sổ mới biết mình rộng bao nhiêu. Đo trên file 100 MB / 1,12 triệu dòng, bản
release, thời gian nạp lại cửa sổ khi nhảy dòng:

| Chế độ | Thùng chữ rộng vô hạn | Thùng chữ rộng hữu hạn |
|---|---|---|
| Tắt | **395–501 ms** | **5,4–8,8 ms** |
| Theo cửa sổ | — | 11,1–12,6 ms |
| Tại cột 80 | — | 11,3–13,8 ms |

Bề rộng hữu hạn lấy từ dòng dài nhất của cửa sổ, đếm sẵn trong lượt quét dựng cửa sổ. Đúng
được vì font vùng soạn thảo là font đơn cách. `phys_footprint` trên file 101 MB: 46 MB (0,46×,
trần NFR-PERF-05 là 1,5×).

**Ba lỗi chỉ lộ ra khi chạy thật**, ghi lại vì cả ba đều vô hình khi đọc code:

1. Khung chữ rộng 1 pt, mỗi dòng hiện đúng một chữ cái — bề rộng lấy từ bố cục lúc bố cục
   chưa dựng nên bằng 0.
2. Kéo cửa sổ 1100 → 900 thì khung chữ tụt còn 700: `autoresizingMask = [.width]` là con
   đường thứ hai sửa lén bề rộng, mỗi lần khung cuộn thu lại thì AppKit trừ đúng chừng ấy.
3. Đổi cỡ cửa sổ không ngắt lại → vùng soạn thảo trắng trơn trong khi thanh trạng thái vẫn
   báo tài liệu có 981 ký tự.

Bốn bài trong `--self-test` chặn cả ba, và mỗi bài đã chạy đối chứng âm.

## 9. Việc PoC-A đã mở khóa và việc còn chặn

`MainWindowController` hiện dùng `NSTextView` thuần và nạp cả tài liệu vào view mỗi lần
(`TODO(ADR-01)`). Bảng §3.2 nói rõ vì sao đó là chỗ dựng khung chứ không phải sản phẩm — và
§4 nói rõ phải đổi thành cái gì.

Còn **chặn** cho tới khi ADR-01 được chốt: tab (FR-DOC-301), chia/nhân đôi khung nhìn
(FR-DOC-302), hiện ký tự ẩn (FR-ENC-205), bảng CSV (FR-CSV-403).

**Một lỗi lõi tìm ra nhờ dựng PoC này**, đã sửa riêng (commit `1a267ea`): bộ dò bảng mã lấy
mẫu bằng `prefix(256 KB)`, cắt giữa ký tự nhiều byte, làm file UTF-8 tiếng Việt lớn bị nhận là
VISCII và giải mã sai **cả file**. Với tiếng Việt xác suất cắt trúng là ~2/3. Mọi fixture cũ
đều nhỏ hơn 256 KB nên không bộ test nào bắt được — PoC-A chạm phải chỉ vì nó là thứ đầu tiên
mở file 1 MB trở lên bằng `Document.open`.

---

## 10. Tái lập

```bash
scripts/vendor-scintilla.sh          # nạp Scintilla 5.5.5 (chỉ chạy một lần)
SIZES="1 10 50 100 250 500" SAMPLES=300 scripts/run-poc-a.sh
```

Cần **phiên đồ họa thật** — engine chỉ tiêu tiền khi có cửa sổ để vẽ vào; chạy qua ssh không có
màn hình sẽ ra số vô nghĩa. Mỗi cặp (engine, cỡ) là một tiến trình; báo cáo được ghi nối tiếp
sau mỗi mảnh nên vẫn còn nếu một tiến trình bị giết.
