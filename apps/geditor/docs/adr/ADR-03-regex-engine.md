# ADR-03 — Engine regex: PCRE2 + JIT

| | |
|---|---|
| **Trạng thái** | Đã chốt (Accepted), một phần cần đo lại trên phần cứng Intel thật |
| **Ngày** | 20/08/2026 |
| **PoC** | PoC-C (SAD §8) |
| **Yêu cầu liên quan** | FR-SRCH-101…105, NFR-PERF-06, NFR-PERF-08, NFR-REL-05, NFR-PORT-01, NFR-SEC-01, NFR-USE-02 |
| **Số liệu thô** | `benchmarks/results/poc-c-arm64.json`, `benchmarks/results/poc-c-x86_64.json` |
| **Tái lập** | `scripts/run-poc-c.sh` |

---

## 1. Bối cảnh

FR-SRCH-102 đòi **cú pháp PCRE2**, không phải "một loại regex nào đó". Người dùng đến từ
Notepad++ mang theo pattern có `\K`, lookbehind độ dài thay đổi, inline modifier — chạy khác
đi là hỏng công việc của họ, một cách im lặng.

Bản dựng khung dùng `NSRegularExpression` (ICU) làm chỗ dựa tạm và đã ghi sẵn ba lý do nó
không dùng được cho sản phẩm. PoC-C phải xác nhận ba điều đó, chọn engine thay thế, và đo:

- Throughput trên 100 MB — JIT đáng giá bao nhiêu?
- Pattern backtracking độc bị chặn **như thế nào**, và trần đó quy ra bao nhiêu mili giây?
- JIT có chạy trên **cả hai** kiến trúc không (NFR-PORT-01)?

---

## 2. Quyết định

**Dùng PCRE2 10.47, nạp mã nguồn vào repo, bật JIT, bề rộng code unit 8 bit.**

### 2.1 Vì sao nạp mã nguồn thay vì liên kết thư viện có sẵn

| Phương án | Vì sao không |
|---|---|
| `/usr/lib/libpcre2-8.dylib` | macOS có sẵn file này nhưng **không kèm header công khai**. Đó là phụ thuộc nội bộ của hệ thống, Apple đổi hoặc bỏ lúc nào cũng được. |
| Homebrew `pcre2` | Chỉ có kiến trúc của máy đang cài (ở đây: arm64). NFR-PORT-01 đòi **một** bundle chứa native cho cả hai. |
| Nạp mã nguồn | `swift build --arch arm64 --arch x86_64` ra universal thật. **Đã chọn.** |

`scripts/vendor-pcre2.sh` nạp lại từ bản phát hành upstream, **không sửa một dòng nào**. Mọi
lựa chọn build nằm trong `Package.swift` để nhìn một chỗ là biết đang bật gì — chứ không giấu
trong một `config.h` đã vá tay mà lần cập nhật sau sẽ ghi đè mất.

### 2.2 Bề rộng 8 bit, chạy thẳng trên byte

Hợp đồng của toàn bộ lõi là **offset byte** (piece table, chỉ mục dòng, chỉ mục CSV đều vậy).
PCRE2 8 bit khớp thẳng trên vùng nhớ mmap, không dựng chuỗi trung gian — đây chính là thiếu
sót thứ 3 của engine ICU, vốn phải dựng `String` từ cả buffer trước khi tìm.

### 2.3 Trần công sức thay cho "hy vọng pattern lành"

`match_limit` cưỡng chế **bên trong** một lần khớp. Đây là điểm khác biệt bản chất so với
deadline theo đồng hồ, vốn chỉ chen vào được **giữa** hai kết quả — nên một mình nó không bao
giờ cứu được `(a+)+$`. Sản phẩm dùng **cả hai**: `match_limit` chặn từng lần khớp, `CancelToken`
chặn cả lần tìm.

---

## 3. Số liệu PoC-C

PCRE2 10.47, Release build, fixture CSV tiếng Việt có dấu 100 MB (1 310 720 dòng).

> **Cảnh báo khi đọc cột x86_64:** số liệu x86_64 đo **qua Rosetta 2** trên máy Apple Silicon,
> vì đó là phần cứng đang có. Chúng chứng minh **JIT x86-64 sinh mã và chạy đúng**, nhưng
> KHÔNG phải hiệu năng Intel thật. Phải đo lại trên máy chuẩn STP §2.1 (MacBook Pro 13" 2019
> i5) trước khi dùng làm baseline.

### 3.1 JIT có mặt trên cả hai kiến trúc (NFR-PORT-01)

| Kiến trúc | `PCRE2_CONFIG_JIT` | `PCRE2_CONFIG_JITTARGET` |
|---|---|---|
| arm64 | có | ARM-64 (LSE) 64bit (little endian + unaligned) |
| x86_64 | có | x86 64bit (little endian + unaligned) |

Test `testJITAvailableForCurrentArchitecture` khẳng định điều này ở mọi lần chạy CI, nên một
cấu hình build hỏng không thể lặng lẽ rơi về interpreter.

### 3.2 Throughput trên 100 MB

| Pattern | arm64 JIT | arm64 interp | x86_64 JIT † | x86_64 interp † | Kết quả |
|---|---|---|---|---|---|
| `Thừa Thiên Huế` (literal) | **2 934 MB/s** | 849 MB/s | 2 164 MB/s | 489 MB/s | 1 310 720 |
| `\bDH-\d+\b` | **2 378 MB/s** | *quá hạn* ‡ | 1 464 MB/s | *quá hạn* ‡ | 1 310 720 |
| `\d{4}-\d{2}-\d{2}` | 363 MB/s | 56 MB/s | 374 MB/s | 35 MB/s | 1 310 720 |
| `^DH-\d+` | **2 836 MB/s** | 566 MB/s | 1 971 MB/s | 381 MB/s | 1 310 720 |
| `(Huế\|Đà Nẵng\|Hà Nội)` | 527 MB/s | 175 MB/s | 376 MB/s | 109 MB/s | 2 621 440 |
| `\p{L}{4,}` | 346 MB/s | 54 MB/s | 286 MB/s | 37 MB/s | 3 932 160 |
| `[0-9]{6,}` | 931 MB/s | 231 MB/s | 899 MB/s | 141 MB/s | 1 310 720 |
| `(\w{2,})\1` | 117 MB/s | 22 MB/s | 99 MB/s | 14 MB/s | 1 310 720 |

† qua Rosetta 2 · ‡ bị cắt sau 5 s, xem 3.4

Biên dịch pattern: 0,006–0,18 ms; JIT hóa: 0,018–0,18 ms (arm64). Nhỏ so với một lần tìm,
**nhưng không nhỏ so với Find in Files**: 10 000 file × 0,2 ms = 2 giây thuần biên dịch lại.
Vì thế `PCRE2Pattern` là một kiểu riêng dùng lại được, chứ không phải biến cục bộ trong hàm
`find` (FR-SRCH-105, NFR-PERF-06).

### 3.3 Cái bẫy lớn nhất: PCRE2 kiểm UTF-8 lại ở MỖI lần khớp

Đây là phát hiện quan trọng nhất của PoC-C, và nó suýt lọt qua.

PCRE2 kiểm tra tính hợp lệ UTF-8 của **toàn bộ subject** trong **mỗi** lời gọi `pcre2_match`,
trừ khi được bảo là không cần. Một lần tìm toàn cục gọi `pcre2_match` một lần cho **mỗi kết
quả**. Với 26 215 kết quả trên 2 MB:

| | arm64 | x86_64 † |
|---|---|---|
| Kiểm một lần rồi truyền `PCRE2_NO_UTF_CHECK` | **0,7 ms** | **1,1 ms** |
| Để PCRE2 tự kiểm mỗi lần khớp | 12 088,6 ms | 17 554,9 ms |
| | **×18 088** | **×15 818** |

O(n) thành O(n²). Trên 100 MB nó không kết thúc — lần chạy benchmark đầu tiên treo đúng vì
lý do này, không phải vì pattern chậm.

Cách xử lý trong `PCRE2SearchEngine`:

1. Kiểm buffer **một lần** bằng `ByteScan.isValidUTF8` (một lượt tuyến tính).
2. Hợp lệ → biên dịch không có `PCRE2_MATCH_INVALID_UTF`, truyền `PCRE2_NO_UTF_CHECK` cho mọi
   lần khớp. **Đường nhanh, dùng cho hầu hết file.**
3. Không hợp lệ → biên dịch với `PCRE2_MATCH_INVALID_UTF`. Chậm, nhưng vẫn khớp được phần
   lành thay vì hỏng cả lần tìm — cần cho dữ liệu TCVN3/VNI chưa chuyển mã và file mở nhầm
   (FR-ENC-201).

`ByteScan.isValidUTF8` **phải** đúng tuyệt đối: trả `true` nhầm là PCRE2 chạy với giả định sai
và có thể đọc ra ngoài biên — lỗi bộ nhớ chứ không phải lỗi kết quả. Nó bắt cả mã hóa dài dư,
nửa cặp thay thế và điểm mã vượt U+10FFFF, và được đối chứng với bộ giải mã của Swift trên
dữ liệu ngẫu nhiên lẫn văn bản thật bị làm hỏng từng byte (`UTF8ValidationTests`).

### 3.4 Interpreter KHÔNG phải lưới an toàn

`\bDH-\d+\b` chạy bằng interpreter mất **~159 giây** trên 32 MB — gấp hơn 10⁴ lần nhánh JIT,
trong khi cùng pattern đó ở dạng có neo (`^DH-\d+`) chỉ chậm 5 lần. Chênh lệch không đều và
không đoán trước được từ hình dạng pattern.

Kết luận cho sản phẩm: **JIT là yêu cầu, không phải tối ưu hóa.** Khi `pcre2_jit_compile`
thất bại, không được lặng lẽ rơi về interpreter trên tài liệu lớn; phải hạ `match_limit` và
báo cho người dùng biết lần tìm này bị giới hạn. `PCRE2Pattern.isJITCompiled` phơi ra trạng
thái đó — hiện chưa có lớp UI nào đọc, xem 5.2.

### 3.5 Hiệu chỉnh trần backtracking (TC-SRCH-03)

`(a+)+$` trên 60 ký tự `a` rồi `!`: engine phải thử mọi cách chia chuỗi → số bước tăng theo
hàm mũ, và **không có kết quả khớp**. Mọi ô dưới đây đều kết thúc bằng "chạm trần", không ô
nào chạy hết.

| `match_limit` | arm64 JIT | arm64 interp | x86_64 JIT † | x86_64 interp † |
|---|---|---|---|---|
| 1 000 | 0,03 ms | 0,04 ms | 0,12 ms | 0,03 ms |
| 10 000 | 0,05 ms | 0,13 ms | 0,10 ms | 0,21 ms |
| 100 000 | 0,23 ms | 1,06 ms | 0,28 ms | 2,02 ms |
| **1 000 000** | **2,10 ms** | **10,73 ms** | **2,13 ms** | **20,26 ms** |
| 10 000 000 | 21,17 ms | 107,51 ms | 21,02 ms | 196,96 ms |

Ba điều đọc ra được:

- **Thời gian tỉ lệ tuyến tính với trần.** Trần là một núm điều khiển thật, không phải một
  con số cầu may.
- **JIT cũng tôn trọng `match_limit`.** Không hiển nhiên — `depth_limit` thì JIT bỏ qua.
- **Interpreter đặt ra trần thực tế.** Nó tiêu cùng số bước ấy chậm gấp ~5–10 lần, mà nó là
  đường dự phòng, nên phải nằm trong ngân sách.

**Chọn `match_limit` = 1 000 000** (mặc định của `PCRE2Pattern.Limits`). Ngân sách 100 ms cho
một lần khớp — tìm kiếm chạy ngoài main thread, nhưng nút Hủy phải đáp ứng ≤ 200 ms
(NFR-PERF-06) nên một lần khớp không được chiếm quá nửa khoảng đó. Xấu nhất đo được: 10,7 ms
(arm64) và 20,3 ms (x86_64 qua Rosetta) — còn dư gần 5 lần.

Mặc định của PCRE2 là 10 000 000, tức ~108 ms/lần khớp trên arm64 và ~197 ms trên x86_64:
**quá cao cho một trình soạn thảo tương tác**. Đây là lý do phải hiệu chỉnh chứ không nhận
giá trị mặc định.

### 3.6 Gom kết quả hàng loạt (nền của NFR-PERF-08)

1 000 000 kết quả trong **49 ms** (arm64, 20,3 triệu/s) và 55 ms (x86_64 †).

NFR-PERF-08 cho phép 30 giây để **thay thế** 1 triệu kết quả. Phần **tìm** chiếm 0,16% ngân
sách đó. Phần thay thế chưa hiện thực (`pcre2_substitute` chưa được nối) nên NFR-PERF-08 vẫn
chưa đóng — xem 5.1.

### 3.7 Ba thiếu sót của engine ICU: đã xác nhận và đã khắc phục

| Thiếu sót đã ghi trong bản khung | Trạng thái |
|---|---|
| 1. Cú pháp ICU ≠ PCRE (`\K`, lookbehind, inline modifier) | Khắc phục. `testBackslashKResetsMatchStart`, `testVariableLengthLookbehind`. |
| 2. Không có step-limit → một lần khớp giữ luồng vô hạn | Khắc phục. `testCatastrophicBacktrackingFailsFastInsteadOfHanging` (< 2 s), `testLowerMatchLimitCutsEarlier`. |
| 3. Phải dựng `String` từ cả buffer | Khắc phục. `SearchEngine.find` nhận `UnsafeRawBufferPointer`. |

`FoundationSearchEngine` **được giữ lại làm bên đối chứng trong test**, không phải mã chết:
`testAgreesWithFoundationEngineOnCommonPatterns` so kết quả hai engine trên tập pattern đồng
nghĩa. Một hiện thực độc lập là cách rẻ nhất bắt lỗi trong vòng lặp khớp của chính ta.

---

## 4. Hệ quả

### 4.1 Được

- Cú pháp đúng PCRE2, đúng thứ FR-SRCH-102 đòi và đúng thứ người dùng Notepad++ mang theo.
- Trần tất định chặn catastrophic backtracking — TC-SRCH-03 pass, NFR-REL-05 có cơ sở.
- Chạy thẳng trên mmap, không dựng chuỗi → dùng được trên file GB cùng với ADR-02.
- `\w`, `\b`, `\p{L}` hiểu tiếng Việt có dấu nhờ `PCRE2_UCP` (NFR-USE-02).
- Universal thật: JIT sinh mã cho cả hai kiến trúc, không Rosetta cho người dùng cuối.

### 4.2 Mất / phải chấp nhận

- **4,3 MB mã nguồn bên thứ ba trong repo** (60 file `.c`, 17 file `.h`, gồm sljit). Giấy
  phép BSD 3-Clause, tương thích. Đổi lại là một quy trình cập nhật phải theo dõi (CVE của
  PCRE2 nay là việc của dự án này).
- **JIT kéo theo entitlement.** Hardened runtime chặn bộ nhớ vừa ghi vừa thực thi; bản phát
  hành có notarization **bắt buộc** phải có `com.apple.security.cs.allow-jit`, nếu không
  ứng dụng crash ngay lần tìm đầu tiên. Đã thêm `Resources/GEditor.entitlements` và nối vào
  `scripts/build-universal.sh` (NFR-SEC-01).
- **Đường dự phòng interpreter không dùng được cho file lớn** (3.4). Cần xử lý ở lớp trên.
- **Mỗi lần khớp phải nhớ truyền `subjectIsValidUTF8`.** Quên là mất ×18 000 hiệu năng mà
  kết quả vẫn đúng — kiểu hồi quy im lặng nhất. `regexLiteralThroughputMBps` và
  `regexDateThroughputMBps` được thêm vào cổng chặn merge chính vì lý do này.
- **Số liệu x86_64 đo qua Rosetta**, chưa phải hiệu năng Intel thật.

### 4.3 Bị bác bỏ

- **`NSRegularExpression` (ICU)** — ba thiếu sót ở 3.7, đặc biệt là không có step-limit.
- **`Regex` của Swift** — cú pháp riêng, không phải PCRE2; không có trần backtracking phơi ra.
- **RE2 / engine automat** — chặn được backtracking theo thiết kế, nhưng **không có
  backreference và lookaround**, tức là bỏ đúng những pattern người dùng Notepad++ dùng nhiều.
  Đổi tính năng lấy an toàn, trong khi `match_limit` cho cả hai.

---

## 5. Việc còn lại (không chặn ADR-03)

1. ~~**Nối `pcre2_substitute`** cho Replace All để đóng NFR-PERF-08.~~ **Xong** — xem §7.1.
2. ~~**Lớp UI đọc `isJITCompiled`**: khi JIT hỏng, hạ trần và báo.~~ **Xong 20/08/2026** —
   thanh Tìm biên dịch lại pattern với trần bằng một phần mười và nói ra trong ô trạng thái.
3. ~~**Cache pattern đã biên dịch** cho Find in Files.~~ **Xong** — xem §7.2.
4. **Đo lại trên phần cứng Intel thật** (STP §2.1) rồi mới chốt baseline x86_64.
5. **Theo dõi bản vá bảo mật PCRE2**; `scripts/vendor-pcre2.sh <phiên bản>` là đường cập nhật.
6. **Regex explainer** (hành động A-10 trong RTM) — chưa bắt đầu.

---

## 6. Tái lập

```bash
scripts/run-poc-c.sh                 # 100 MB, cả hai kiến trúc
scripts/run-poc-c.sh --mb 32         # bản nhanh khi phát triển
scripts/vendor-pcre2.sh 10.47        # nạp lại mã nguồn PCRE2
```

Đo x86_64 trên máy Apple Silicon cần Rosetta 2 (`softwareupdate --install-rosetta`); thiếu nó
script bỏ qua phần x86_64 và nói rõ là đã bỏ qua, thay vì báo thành công một nửa.

Tính đúng đắn: `Tests/GEditorCoreTests/PCRE2SearchEngineTests.swift` (31 test) và
`UTF8ValidationTests.swift` (9 test). Trọng tâm là vòng lặp khớp toàn cục — khớp rỗng, `\K`
kéo lùi điểm bắt đầu, nhích một ký tự trên UTF-8 và CRLF — ba chỗ mà lỗi không gây crash mà
gây mất kết quả hoặc lặp vô hạn.

---

## 7. Bổ sung sau PoC-C — Replace All và Find in Files

Hai phần này không phải quyết định kiến trúc mới; chúng là hệ quả trực tiếp của việc chọn
PCRE2, và chúng đóng nốt hai KPI cuối còn đo được ở mức lõi. Ghi vào đây vì cả hai đều lộ ra
những chi phí mà không đo thì không thấy.

Số liệu: `benchmarks/results/search-kpi-arm64.json` · tái lập: `scripts/run-search-kpi.sh`

### 7.1 Replace All — TC-PERF-06 / NFR-PERF-08 · ĐẠT

Thay 1 000 000 kết quả trên 100 MB, pattern `(\d{4})-(\d{2})-(\d{2})` → `$3/$2/$1`:

| | |
|---|---|
| Dựng kế hoạch (tìm + giãn chuỗi thay thế) | 392 ms |
| Áp vào piece table | 2 871 ms |
| **Tổng** | **3,26 s** — trần STP là 30 s |
| Undo | 1 901 ms, trong **1 bước** (FR-CORE-004) |
| Footprint đỉnh | 457 MB |

Ba điều đáng ghi:

- **Template dùng tham chiếu nhóm nên phép đo đi qua đường CHẬM.** Mỗi kết quả gọi một lần
  `pcre2_substitute` với `PCRE2_SUBSTITUTE_MATCHED | REPLACEMENT_ONLY`. Chuỗi thay thế thuần
  chữ đi đường nhanh (một mảng byte dùng chung cho mọi `TextEdit`, nhờ copy-on-write) và nhanh
  hơn nhiều — nhưng đo đường nhanh rồi báo cáo là tự cho điểm.
- **`REPLACEMENT_ONLY` là thứ làm cho kiến trúc này chạy được.** Không có nó, `pcre2_substitute`
  trả về CẢ subject đã sửa — tức dựng lại 100 MB trong RAM và biến toàn bộ thao tác thành một
  `TextEdit` khổng lồ, mất sạch lợi ích của piece table.
- **457 MB footprint là giá của một triệu `TextEdit` cộng nội dung cũ cho undo.** Không vi phạm
  NFR-PERF-05 (chỉ nói về RAM *nhàn rỗi*), nhưng là trần thực tế cho số kết quả thay một lần.
  Xem việc còn lại (3).

> **x86_64 CHƯA ĐẠT khi đo qua Rosetta 2: 48,1 s** (bước áp dụng 47,6 s so với 2,9 s native,
> tức chậm 16 lần). Một triệu thao tác trên cây piece là đúng loại mã mà bộ dịch nhị phân xử
> lý kém nhất. Con số này KHÔNG nói gì về Intel thật — nhưng cũng KHÔNG cho phép kết luận
> NFR-PERF-08 đạt trên x86_64. Phải đo trên máy chuẩn STP §2.1 trước khi coi là xong.

### 7.2 Find in Files — TC-PERF-05 / NFR-PERF-06 · CHƯA KẾT LUẬN ĐƯỢC TẠI CHỖ

10 000 file (7 334 file sau bộ lọc `*.csv;*.log`), 72 MB, trên máy M2 Pro 12 lõi (8P + 4E):

| Luồng | Thời gian | Thông lượng | Tăng tốc |
|---|---|---|---|
| 1 | 171 ms | 418 MB/s | 1,00× |
| 2 | 106 ms | 675 MB/s | 1,61× |
| 4 | 71 ms | 1 016 MB/s | 2,43× |
| 8 | 61 ms | 1 177 MB/s | 2,82× |

Tỉ lệ 8/4 = **0,86**, trong khi TC-PERF-05 đòi ≤ 0,60.

**Con số này không kết luận được, và lý do phải nói rõ:** STP đo bằng cách *giới hạn cả máy*
còn 4 rồi 8 lõi (`taskpolicy`) trên máy chuẩn §2.1. Ở đây chỉ giới hạn được *số luồng công
nhân* trên một máy 12 lõi. Hai thí nghiệm khác nhau ở chỗ lượt "4 luồng" vẫn được dùng toàn
bộ băng thông bộ nhớ và cache của cả 12 lõi, nên nó nhanh hơn một máy thật sự chỉ có 4 lõi —
và tỉ lệ 8/4 vì thế bị đẩy lên. **Phải đo lại trên máy chuẩn trước khi kết luận đạt hay không.**

Điều *có thể* kết luận: find-in-files thật sự dùng đa lõi (2,82× trên 8 luồng ở fixture 10 KB,
4,5× ở fixture 50 KB), và kết quả không đổi theo số luồng — điều kiện tiên quyết mà
`testConcurrencyDoesNotChangeResults` canh ở mỗi lần chạy CI.

### 7.3 Ba chi phí ẩn tìm ra khi truy nút thắt

Lần đo đầu cho 334 MB/s một luồng, trong khi bản thân engine chạy 2 934 MB/s (§3.2). Chênh
lệch gần 9 lần nằm ở chi phí **cho mỗi file**, không nằm ở việc tìm kiếm. Truy ra ba thứ:

| Nguyên nhân | Cách xử lý | Kết quả |
|---|---|---|
| `mmap`+lỗi trang+`munmap` cho mỗi file 10 KB — thao tác trên bảng ánh xạ bộ nhớ, các luồng tranh khóa của nhân | `read()` vào bộ đệm dùng lại cho file dưới 1 MB; giữ `mmap` cho file lớn | đo trực tiếp: mmap 117 ms vs read 62 ms ở 8 luồng — **1,9×** |
| `pcre2_jit_stack_create` (một `mmap` `MAP_JIT`) chạy MỘT LẦN MỖI FILE | tách `PCRE2Matcher` giữ `match_data`+`match_context`+JIT stack, mỗi luồng một cái, dùng lại suốt lượt quét | bỏ 10 000 lần `mmap` |
| `ByteScan.isValidUTF8` quét scalar toàn file | thêm `geditor_find_non_ascii` (NEON/AVX2) để nhảy qua vùng ASCII bằng vector | phần ASCII gần như miễn phí |

Tổng cộng: **334 → 418 MB/s một luồng**, và 610 → 1 177 MB/s ở 8 luồng.

Điểm đáng nhớ: cả ba đều là chi phí *hạ tầng cho mỗi file*, không phải chi phí thuật toán.
Trên 10 000 file thì thứ tưởng như không đáng kể lại là toàn bộ vấn đề.

### 7.4 Việc còn lại của phần này

1. **Đo TC-PERF-05 và TC-PERF-06 trên máy chuẩn STP §2.1** — xem 7.1 (x86_64 qua Rosetta
   không đạt) và 7.2 (`taskpolicy`).
2. **Bộ lọc kết quả cho panel Search Results** (FR-SRCH-105): lõi đã trả về đủ dữ liệu
   (đường dẫn, dòng, cột, đoạn xem trước), còn thiếu lớp trình bày.
3. **Thay thế theo lô cho tài liệu rất lớn**: 457 MB footprint ở một triệu kết quả là trần
   thực tế; cần chia lô hoặc nén biểu diễn `TextEdit` nếu muốn vượt.
4. **Bỏ chọn từng file trước khi ghi** (TC-SRCH-07): `replace(files:…)` đã nhận danh sách file
   nên việc này thuộc lớp UI, nhưng chưa có ai gọi.
