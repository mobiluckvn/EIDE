# ADR-02 — Cấu trúc buffer văn bản: piece table trên mmap

| | |
|---|---|
| **Trạng thái** | Đã chốt (Accepted) |
| **Ngày** | 19/08/2026 |
| **PoC** | PoC-B (SAD §8) |
| **Yêu cầu liên quan** | FR-CORE-004, FR-DOC-310, NFR-PERF-03, NFR-PERF-04, NFR-PERF-05, NFR-MNT-01 |
| **Số liệu thô** | `benchmarks/results/poc-b-arm64.json` |
| **Tái lập** | `scripts/run-poc-b.sh` |

---

## 1. Bối cảnh

GEditor phải mở được file text/CSV hàng Gigabyte và vẫn gõ mượt. Ba ràng buộc va nhau:

- **NFR-PERF-03** — mở file 1 GB tới trạng thái tương tác được, cuộn 60 fps.
- **NFR-PERF-04** — latency gõ p95 ≤ 16 ms (một khung hình ở 60 Hz).
- **NFR-PERF-05** — RAM nhàn rỗi ≤ 80 MB.

SRS §3.4 đã cấm đọc cả file vào một chuỗi liên tục. Câu hỏi còn lại của ADR-02 là **cấu trúc
nào đứng giữa file mmap và lớp hiển thị**, và **chỉ mục dòng sống ở đâu**.

Bản dựng khung ban đầu đã đúng ở hướng lớn (piece table + mmap + add buffer chỉ-nối-thêm)
nhưng cố ý để lại hai chỗ hỏng, có ghi TODO:

1. `PieceTable` giữ piece trong **mảng phẳng** — định vị offset là quét tuyến tính, tách piece
   là `Array.insert` (memmove). Cả hai O(số piece).
2. `TextBuffer` **dựng lại toàn bộ `LineIndex` sau mỗi nhóm sửa** — O(số byte) mỗi lần.

PoC-B tồn tại để trả lời: hai chỗ đó hỏng ở kích thước nào, và cách sửa nào đủ.

---

## 2. Quyết định

**Giữ piece table trên mmap. Thay mảng piece bằng cây, và thay chỉ mục dòng đầy đủ bằng chỉ
mục newline thưa theo khối.**

Ba thành phần:

### 2.1 `PieceTree` — treap theo khóa ngầm

Mỗi nút giữ một piece và **tổng hợp của cả cây con**: số byte, số `\n`, số nút. Khóa là *vị
trí*, không phải giá trị, nên mọi phép sửa quy về hai nguyên thủy `split` và `join`:

```
replace(range, piece):  (head, rest) = split(root, range.lowerBound)
                        (_,    tail) = split(rest, range.count)
                        root = join(join(head, piece), tail)
```

Ưu tiên nút sinh bằng **splitmix64 trên bộ đếm tăng dần**: phân bố như ngẫu nhiên (giữ độ sâu
~1,39·log₂n) nhưng **tất định** — cùng một chuỗi thao tác luôn cho cùng một cây, điều kiện để
benchmark và test tái lập được. Đo thực tế: 20 000 piece → độ sâu 36.

Vì `newlines` được tổng hợp lên cây, `lineCount` là O(1) và `offset(ofLineStart:)` /
`lineNumber(atOffset:)` là O(log n). **Không còn bước dựng lại chỉ mục nào sau khi sửa.**

### 2.2 `NewlineBlockIndex` — chỉ mục newline thưa theo khối 64 KB

Cây trả lời được "piece nào" nhưng không trả lời được "chỗ nào *trong* piece" — và piece đầu
tiên dài bằng cả file. Nên mỗi nguồn byte (file gốc, add buffer) mang một chỉ mục:

```
cumulative[b] = số '\n' trong [0, b × 64 KB)
```

Mọi truy vấn quy về *tra bảng + quét SIMD trong đúng một khối*, chặn trên 64 KB.

Đây là chỗ đánh đổi quan trọng nhất của ADR này. Phương án hiển nhiên — lưu offset của **mọi**
dòng — không dùng được:

| | 1 GB CSV (13 421 772 dòng) |
|---|---|
| `[Int]` đủ mọi dòng | **107 MB** — tự nó đã vượt NFR-PERF-05 (80 MB) |
| Bảng mốc 64 KB/mục | **128 KB** |

Tỉ lệ 1:840, đổi lấy một lần quét ≤ 64 KB cho mỗi truy vấn (≈1,3 µs ở 51 GB/s).

### 2.3 Add buffer chỉ-nối-thêm

Byte đã ghi không bao giờ đổi, nên chỉ mục newline của nó **mở rộng gia tăng**, và piece cũ
luôn còn hiệu lực — undo chỉ cần trỏ lại đoạn cũ chứ không phải khôi phục nội dung.

---

## 3. Số liệu PoC-B

MacBook (arm64, NEON), Release build, fixture CSV tiếng Việt có dấu 1 GB = 13 421 772 dòng.

### 3.1 Mở file 1 GB

| | Cache nguội | Cache nóng |
|---|---|---|
| `mmap` | 6,3 ms | 6,6 ms |
| Dựng chỉ mục newline | 1367,5 ms | 283,9 ms |
| Truy vấn dòng đầu tiên | 0,001 ms | 0,001 ms |
| **Tổng tới lúc tương tác** | **1373,7 ms** (745 MB/s) | **290,5 ms** (3525 MB/s) |

Lần nguội bị chặn bởi **I/O đĩa**, không phải CPU: 745 MB/s xấp xỉ tốc độ đọc tuần tự của SSD,
trong khi cùng phép quét trên dữ liệu đã nằm trong cache đạt 3,5 GB/s. Kết luận: chi phí mở
file là chi phí *đọc file*, cấu trúc dữ liệu không đóng góp đáng kể.

`firstLineQueryMs` ≈ 0 xác nhận không có công việc nào bị hoãn lại và giấu sau bước mở.

### 3.2 Bộ nhớ — hai con số, đừng nhầm

| | 1 GB đang mở |
|---|---|
| footprint nền (chưa mở gì) | 1,5 MB |
| **footprint sau khi mở** | **2,3 MB** |
| resident sau khi mở | 1030,7 MB |
| footprint sau 10 000 lần sửa | 5,7 MB |
| bảng mốc chỉ mục newline | 128 KB |

`resident` gồm **trang mmap sạch** mà bước quét chỉ mục chạm vào; chúng là bản sao của nội dung
đĩa, kernel thu hồi bất cứ lúc nào và **không** tính vào `phys_footprint` — thứ Activity Monitor
gọi là "Memory" và là thứ NFR-PERF-05 thực sự ràng buộc.

**Mở file 1 GB tốn 0,8 MB RAM thật.** NFR-PERF-05 (≤ 80 MB) còn nguyên biên độ cho lớp hiển thị.

> Cảnh báo khi đọc lại số này: ai nhìn `resident` rồi kết luận "piece table trên mmap ngốn RAM
> bằng kích thước file" là đã đọc sai cột. Mọi báo cáo về sau phải ghi rõ dùng cột nào.

### 3.3 Gõ phím trên file 1 GB

10 000 lần gõ lẻ, mỗi lần gồm cả việc status bar đọc lại vị trí con trỏ (FR-CORE-018):

| p50 | p95 | p99 | max |
|---|---|---|---|
| 4,0 µs | **6,5 µs** | 9,0 µs | 47,1 µs |

Ngân sách NFR-PERF-04 là 16 ms. Phần lõi chiếm **0,04%**. Toàn bộ 16 ms còn lại thuộc về engine
hiển thị — đúng như PoC-A giả định khi so Scintilla-Cocoa với TextKit 2.

Tra cứu dòng trên tài liệu đã phân mảnh 20 001 piece: offset→dòng p95 **4,4 µs**, dòng→offset
p95 **10,0 µs**.

### 3.4 Một nhóm 10 000 sửa = một bước undo (FR-CORE-004)

| áp dụng | undo | redo | piece sau | độ sâu cây |
|---|---|---|---|---|
| 30,7 ms | 15,0 ms | 19,2 ms | 20 000 | 36 |

### 3.5 Điểm gãy của mảng piece phẳng

2 000 lần gõ, nguồn trong RAM (loại nhiễu I/O), so **đúng hai cấu trúc** với nhau:

| Kích thước | Cây piece | Mảng phẳng | Tỉ lệ |
|---|---|---|---|
| 4 MB | 3,9 ms | 186,7 ms | ×48 |
| 16 MB | 4,3 ms | 513,6 ms | ×118 |
| 64 MB | 5,3 ms | 2 387,2 ms | ×447 |
| 256 MB | 6,0 ms | 9 746,6 ms | ×1 632 |

Đọc theo cột chứ không theo tỉ lệ:

- **Cây gần như phẳng theo kích thước file** (3,9 → 6,0 ms khi file to lên 64 lần) — đúng như
  O(log n) dự đoán.
- **Mảng phẳng tăng tuyến tính theo kích thước file**, vì chi phí bị chi phối bởi việc quét lại
  toàn tài liệu sau mỗi lần sửa. Quy về mỗi lần gõ: 0,09 ms ở 4 MB → 1,19 ms ở 64 MB →
  4,87 ms ở 256 MB, tức **~19 µs cho mỗi MB nội dung**.

Chuyển thành điểm gãy, lấy ngân sách NFR-PERF-04 là 16 ms cho toàn bộ đường gõ:

| Ngưỡng | Mảng phẳng đạt tới ở |
|---|---|
| Lõi chiếm 10% ngân sách (1,6 ms) | ~85 MB |
| Lõi chiếm 50% ngân sách (8 ms) | ~420 MB |
| Lõi chiếm 100% ngân sách (16 ms) | ~840 MB |

Nghĩa là bản mảng phẳng đủ dùng cho một trình soạn thảo mã nguồn thông thường, và **hỏng
NFR-PERF-04 trên file 1 GB ngay cả khi lớp hiển thị nhanh vô hạn** — đúng thứ GEditor tồn tại
để làm. Cây piece ở cùng phép đo là 3,0 µs mỗi lần gõ ở 256 MB và gần như không đổi theo kích
thước, nên không có ngưỡng nào để vượt.

### 3.6 Ảnh hưởng lên KPI lõi đang có (fixture 32 MB, cùng máy)

| KPI | Trước PoC-B | Sau PoC-B |
|---|---|---|
| `batchEdit10kMs` | 93,13 ms | **22,61 ms** |
| `interactiveTypingP95Ms` | *(chưa đo)* | 0,0035 ms |
| `lineQueryP95Ms` | *(chưa đo)* | 0,0091 ms |

Các KPI còn lại (parse CSV, quét newline, ghi atomic, dựng `LineIndex`) không đổi ngoài nhiễu đo.

---

## 4. Hệ quả

### 4.1 Được

- NFR-PERF-05 và phần lõi của NFR-PERF-04 đạt với biên độ rất rộng trên file 1 GB.
- Không còn bước O(n) nào trên đường gõ phím.
- Cấu trúc tất định → benchmark và test tái lập được từng bit.
- File gốc vẫn bất biến; add buffer chỉ nối thêm → undo không giới hạn vẫn rẻ (FR-CORE-004).

### 4.2 Mất / phải chấp nhận

- **Chi phí mở = chi phí đọc file.** 1,37 s cho 1 GB cache nguội. Muốn nhanh hơn phải dựng chỉ
  mục *lười theo khối* và cho phép tương tác trước khi quét xong — chưa làm, xem 5.1.
- **Quét chỉ mục chạm mọi trang**, đẩy `resident` lên gần bằng kích thước file. Trang sạch nên
  vô hại về mặt RAM, nhưng làm số liệu dễ bị đọc sai và có thể gây áp lực bộ nhớ trên máy 8 GB
  khi mở nhiều file lớn cùng lúc.
- **Phân mảnh không có ngưỡng gộp.** 10 000 lần sửa → 20 000 piece. Cây chịu được (độ sâu 36),
  nhưng một phiên rất dài sẽ tăng đều. Xem 5.2.
- **Không có giới hạn bộ nhớ undo.** Add buffer chỉ nối thêm nên mọi nội dung từng gõ đều được
  giữ. Ở 10 000 lần gõ chỉ là 0,6 KB, nhưng dán lặp lại nội dung lớn thì tăng tuyến tính.

### 4.3 Bị bác bỏ

- **Chuỗi liên tục / gap buffer** — SRS §3.4 đã cấm, và 1 GB trong RAM vi phạm NFR-PERF-05.
- **Chỉ mục dòng đầy đủ `[Int]`** — 107 MB cho 1 GB, xem 2.2.
- **Chia file gốc thành chunk 64 KB rồi lưu `lineStarts` cho từng chunk** (cách VS Code làm cho
  buffer trong RAM) — với mmap thì không cần: một lượt quét SIMD trên vùng đã ánh xạ rẻ hơn và
  không phải sao chép nội dung ra khỏi trang file.

---

## 5. Việc còn lại (không chặn ADR-02)

1. **Dựng chỉ mục lười theo khối** để mở file lớn tương tác được ngay, quét nền phần còn lại.
   Chỉ đáng làm nếu 1,37 s bị coi là quá lâu — quyết định sau khi PoC-A cho biết engine hiển
   thị tốn thêm bao nhiêu (NFR-PERF-03).
2. **Ngưỡng gộp piece (consolidate)**: gộp các piece liền kề cùng nguồn khi số piece vượt
   ngưỡng. Chưa có bằng chứng là cần — nên chưa làm, nhưng `pieceCount`/`treeDepth` đã được
   phơi ra để theo dõi.
3. **Trần bộ nhớ cho add buffer + undo**, gắn với FR-DOC-304 (bản nháp chưa lưu).
4. **`madvise(MADV_DONTNEED)` sau khi dựng chỉ mục** để trả trang sớm — cần đo xem có làm chậm
   lần cuộn đầu tiên không.
5. **Đo trên Intel x86_64 (AVX2)**. Mọi số ở trên là arm64/NEON. NFR-PORT-01 đòi cả hai kiến
   trúc; baseline benchmark cũng tách theo kiến trúc vì lý do này.

---

## 6. Tái lập

```bash
scripts/run-poc-b.sh                 # đủ 1 GB
scripts/run-poc-b.sh --mb 256        # bản nhanh khi phát triển
GEDITOR_FIXTURE_DIR=/Volumes/X scripts/run-poc-b.sh   # đổi nơi chứa fixture
```

Fixture sinh ngoài repo (STP §2.2) và được dùng lại nếu đã đúng kích thước. Cần ~2 GB trống.

Tính đúng đắn của cấu trúc được canh bởi `Tests/GEditorCoreTests/PieceTreeTests.swift`: mọi
khẳng định đều so với một hiện thực **ngây thơ, hiển nhiên đúng** (đếm `\n` bằng vòng lặp) chứ
không so với chính nó — sai sót ở đây không gây crash mà làm lệch số dòng, kiểu lỗi chỉ lộ ra
khi người dùng đã sửa nhầm dòng trên file thật.

---

## 7. Bổ sung 20/08/2026 — một lỗi mà PoC-B không bắt được

Khi nối `LineOps`/`CSVEngine` vào tài liệu thật (khử trùng lặp, xóa cột CSV), cây piece lộ ra
suy biến **O(n²)** trên đường XÓA HÀNG LOẠT. Ghi lại ở đây vì bài học nằm ở chỗ *vì sao bộ đo
không thấy*, chứ không chỉ ở bản vá.

### 7.1 Triệu chứng

| Số edit xóa | Thời gian áp dụng | Độ sâu cây |
|---|---|---|
| 25 000 | 7,7 s | — |
| 50 000 | 30,1 s | — |
| 100 000 | **134,8 s** | — |
| 20 001 piece | | **6 281** (kỳ vọng ~36) |

Gấp bốn thời gian khi gấp đôi số edit — bậc hai. Cây đã thành gần như một danh sách liên kết.

### 7.2 Nguyên nhân

`PieceTree.split` khi cắt vào GIỮA một piece dùng lại chính nút cũ cho nửa đầu và chỉ tạo nút
mới cho nửa sau. Nửa đầu vì thế **giữ nguyên ưu tiên cũ**.

Xóa hàng loạt cắt đi cắt lại cùng một piece (`applyEdits` sắp giảm dần theo offset, nên mỗi
lần xóa lại cắt vào piece bên trái đang lớn dần). Ưu tiên của nút đó không bao giờ được sinh
lại, tính ngẫu nhiên — thứ duy nhất giữ cho treap cân bằng — mất đi.

Kiểm chứng dứt điểm: **xóa theo thứ tự giảm dần cho độ sâu ~n/3; xóa theo thứ tự tăng dần cho
độ sâu 26.** Cùng số lượng edit, cùng dữ liệu, chỉ khác thứ tự.

### 7.3 Vì sao PoC-B không thấy

PoC-B đo **chèn** và **thay thế**, không đo **xóa**. Hai đường đầu luôn tạo nút mới cho nội
dung thay vào, nên ưu tiên vẫn được sinh lại đều đặn và cây vẫn cân bằng. Đường xóa không tạo
nút nào — và đó chính là đường mà "xóa dòng trùng" và "xóa cột" đi qua.

Bài học: một benchmark đo *ba thao tác* trên một cấu trúc *bốn nhánh* thì phần không đo được
không phải là "chưa tối ưu", nó là "chưa biết". Test `testTreeStaysBalancedUnderSequentialAppends`
cũng chỉ phủ đường chèn.

### 7.4 Bản vá

Cả hai nửa nhận nút mới với ưu tiên mới, và nửa đầu được nối lại với cây con trái bằng `join`
thay vì gán thẳng — gán thẳng sẽ phá tính chất heap khi ưu tiên mới nhỏ hơn ưu tiên của cây
con trái.

Phép `join` thêm ban đầu làm `batchEdit10kMs` xấu đi 22,6 → 47,6 ms. Truy tiếp thì phần lớn
chi phí đó không nằm ở `join` mà ở việc tính lại số newline của nửa mới: nó đi qua hai lần tra
`NewlineBlockIndex`, mỗi lần quét trung bình nửa khối 64 KB, trong khi đoạn cần đếm thường chỉ
vài chục byte. Đếm thẳng khi đoạn ngắn hơn 16 KB:

| | Trước sửa cân bằng | Sau sửa cân bằng | Sau khi đếm thẳng đoạn ngắn |
|---|---|---|---|
| `batchEdit10kMs` (32 MB) | 22,6 ms | 47,6 ms | **15,5 ms** |
| Xóa cột 100 000 hàng | 134,8 s | 0,31 s | **0,28 s** |

Kết quả cuối tốt hơn cả hai bản trước trên cả hai đường.

### 7.5 Số liệu PoC-B đo lại sau bản vá

| | Trước | Sau |
|---|---|---|
| Một nhóm 10 000 sửa | 30,7 ms | **22,6 ms** |
| Undo nhóm đó | 15,0 ms | **11,8 ms** |
| Độ sâu cây (20 000 piece) | 36 | 33 |
| Gõ phím p95 (file 1 GB) | 6,5 µs | 6,1 µs |

### 7.6 Hai KPI mới đóng được nhờ bản vá

Tiêu chí lấy nguyên từ STP; số liệu: `benchmarks/results/ops-kpi-arm64.json`, tái lập bằng
`scripts/run-ops-kpi.sh`.

| | Yêu cầu | Đo được | Trần |
|---|---|---|---|
| **TC-CORE-08** khử trùng lặp 1 triệu dòng, 40% trùng | FR-CORE-006 | **1,22 s** · 600 000 dòng còn lại, đúng thứ tự bản đầu, 1 bước undo | 3 s |
| **TC-CSV-03** xóa cột 3 trên CSV 1 triệu hàng | FR-CSV-404 | **2,82 s** · quoted field nguyên vẹn, 1 bước undo | 5 s |

Khử trùng lặp sinh 239 695 `TextEdit` cho 600 000 dòng bị xóa — các vùng liền nhau đã được gộp.

### 7.7 Việc còn lại của phần này

1. **Đo cả bốn nhánh trong PoC-B**, không chỉ ba: thêm xóa hàng loạt vào bộ đo thường xuyên
   thay vì chỉ có test độ sâu.
2. ~~**Xóa cột hiện dựng cả tài liệu trong RAM** để đưa cho parser.~~ **Xong 20/08/2026** —
   `CSVEngine.forEachRow` đọc theo cửa sổ 1 MB, phân tích các hàng trọn vẹn rồi bắt đầu lại
   từ hàng bị cắt; bộ nhớ dùng là một cửa sổ cộng một hàng, không phụ thuộc kích thước tài
   liệu. TC-CSV-03 không đổi (2,76 s so với 2,82 s).
