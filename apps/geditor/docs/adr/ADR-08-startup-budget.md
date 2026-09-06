# ADR-08 — Ngân sách khởi động nguội (NFR-PERF-01)

**Trạng thái:** ✅ **ĐẠT 24/08/2026 — 465 ms / trần 500** (min 445). Chỉ tiêu NFR-PERF-01 lần
đầu tiên qua, sau khi mở đầu ở 794 ms.
**Đường đi:** §2.9 tách ba grammar nặng (794 → 690) · §2.10 dựng lười giao diện (690 → 574) ·
§2.12 bỏ bảng ký hiệu khỏi bản giao (→ ~520) · §2.13 chuyển **cả hai mươi** bảng tra grammar
sang dylib lười (→ **465**, binary chính 11,20 → 3,47 MB). Anh chốt §2.13 ngày 24/08/2026.
**Đọc con số cho đúng:** cùng một bản dựng KHÔNG đổi cho 507 · 524 · 547 ms ở ba phiên đo khác
nhau trong một buổi. Chênh ±40 ms là nhiễu máy. So sánh chỉ có nghĩa khi hai bản đo trong cùng
một phiên, và §2.11–2.13 nói rõ "nguội" ở đây nghĩa là lần mở ĐẦU TIÊN của một file nhân chưa
từng thấy — mọi lần mở sau đó là 219 ms.
**Chạy lại:** `scripts/run-startup-kpi.sh` → `benchmarks/results/startup-kpi-arm64.json`

---

## 1. Vì sao có ADR này

NFR-PERF-01 (P0) đòi **khởi động nguội ≤ 500 ms** trên Apple Silicon, đo tới khi cửa sổ nhận
được thao tác gõ. Chỉ tiêu ấy chưa từng được đo lần nào cho tới 22/08/2026 — bộ benchmark ngoài
không với tới nó, vì nó chỉ đo được từ bên trong app đang chạy.

Đo xong thì thấy: **794 ms. Trượt gấp rưỡi.**

Đây không phải một bản vá được. Nguyên nhân nằm ở một quyết định đã chốt (ADR-04 dựng grammar
tĩnh) và chạm vào một chỉ tiêu đã chốt, nên nó cần một ADR.

---

## 2. Số đo

Máy đang dùng (Apple Silicon), bản release, trung vị 5 lần. "Nguội" = binary chưa nằm trong
page cache, mô phỏng bằng cách chạy một **bản sao mới** mỗi lần.

### 2.1 GEditor hiện tại

| | Nguội | Ấm |
|---|---|---|
| **tổng** | **794 ms** ❌ (trần 500) | 305 ms |
| dyld — nạp, liên kết, trước `main()` | 501 ms | ~17 ms |
| app — dựng cửa sổ tới lúc nhận gõ | 294 ms | ~290 ms |

RAM nhàn rỗi: **25,2 MB** / trần 80 MB ✅ (NFR-PERF-05 — đạt thoải mái).

**Đo NGUỘI, đừng đo ẤM.** Bản ấm 305 ms nằm gọn trong trần. Chạy đi chạy lại cùng một binary —
cách thử tự nhiên nhất — sẽ kết luận "đạt" cho một chỉ tiêu đang trượt gấp rưỡi.

### 2.2 Chi phí nằm ở đâu — ba phép đối chứng

**(a) Không phải AppKit, không phải mã khởi động của app.** `geditor` CLI dùng **cùng lõi**
nhưng không có AppKit:

| | Nguội | Ấm |
|---|---|---|
| CLI 21 MB | 470–840 ms | **22 ms** |

Ấm chỉ 22 ms mà nguội tới 470–840 ms → chi phí là **đọc binary từ đĩa**, không phải việc gì
chạy trong tiến trình.

**(b) Binary gồm những gì.** `size -m` trên GEditorApp (22 MB):

```
__TEXT   20,7 MB
  __text     2,7 MB   ← mã máy
  __const   17,6 MB   ← bảng tra 20 grammar tree-sitter (ADR-04)
```

**17,6 trên 20,7 MB là bảng tra grammar.** Scintilla vô can — nó chỉ nằm trong PoC-A, không
liên kết vào app.

**(c) 17,6 MB dữ liệu hằng đáng giá bao nhiêu mili-giây.** Thí nghiệm đối chứng: hai app AppKit
tối thiểu, cùng mã (dựng một `NSWindow` rồi đo), khác nhau đúng một khối `__const` 17,6 MB nhúng
bằng `.incbin`:

| | Kích thước | Nguội (3 lần sau) |
|---|---|---|
| mini | 53 KB | 259 · 264 · 271 ms |
| mini + 17,6 MB `__const` | 17 MB | 524 · 498 · 511 ms |

→ **17,6 MB dữ liệu hằng ≈ +240 ms khởi động nguội.**

### 2.3 Bản đã đóng gói và ký — không đổi bản chất

Nghi vấn hợp lý: số ở trên đo trên binary `swift build` trần, còn người dùng chạy một `.app` đã
ký. Nên đo luôn: đóng gói đúng cấu trúc bundle, `codesign` với hardened runtime và entitlements
thật.

| | Nguội | Ấm |
|---|---|---|
| binary trần | 794 ms | 305 ms |
| **.app đã ký (hardened runtime)** | **688 · 735 · 941 ms** | 305 ms |

Cùng một cỡ. Việc trượt chỉ tiêu **không phải** do chưa đóng gói. (Còn một biến chưa loại được:
chữ ký ad-hoc, chưa notarize và chưa qua Gatekeeper lần đầu — cần Developer ID mới đo nốt được,
xem §5 của `docs/trang-thai.md`.)

### 2.4 Ngân sách thật, sau khi đã biết

| Khoản | ms |
|---|---|
| Sàn: một app AppKit tối thiểu, 53 KB | **265** |
| 17,6 MB bảng tra grammar (ADR-04) | **240** |
| Phần còn lại của GEditor (mã, dựng cửa sổ, tab, status bar…) | **290** |
| **Tổng** | **794** |
| Trần NFR-PERF-01 | 500 |

Con số đáng dừng lại: **sàn của một cửa sổ AppKit rỗng đã là 265 ms.** Ngân sách còn lại cho
TOÀN BỘ GEditor là 235 ms — mà riêng bảng tra grammar đã ăn 240 ms.

### 2.5 PoC-E — đo thật phương án C

Anh chọn C (22/08). Trước khi cắt, đo kích thước từng grammar đã biên dịch:

| Grammar | | Grammar | | Grammar |
|---|---|---|---|---|
| **csharp 10,6 MB** | | typescript 3,0 | | java 1,0 |
| **cpp 7,0 MB** | | c 2,8 | | yaml 0,5 · go 0,5 · css 0,4 |
| ruby 4,3 | | rust 2,4 · php 2,3 | | 6 cái còn lại < 0,3 mỗi cái |
| bash 3,0 | | python 1,1 · javascript 1,0 | | |

Phân bố **cực kỳ lệch**: csharp + cpp chiếm gần một nửa. Nên C không cần cắt xuống 5–6 ngôn ngữ
như §3 viết — cắt vài cái nặng nhất là được phần lớn lợi ích.

Dựng thật hai biến thể và đo:

| Bản dựng | Binary | `__const` | Nguội |
|---|---|---|---|
| 20 grammar (hiện tại) | 22 MB | 17,6 MB | **794 ms** |
| 17 grammar (bỏ csharp, cpp, ruby) | 12 MB | 7,1 MB | **674 ms** |
| 0 grammar | 4,1 MB | ~0 | **545 ms** |

**C một mình KHÔNG đủ.** Ngay cả khi bỏ HẾT grammar khỏi binary, khởi động nguội vẫn 545 ms —
trượt trần 500. Kết luận ở §2.2 rằng "chi phí là đọc binary từ đĩa" đúng cho phần dyld, nhưng
nó bỏ sót một khoản cỡ tương đương.

### 2.6 Khoản bị bỏ sót: app tự dựng

Phân rã phần "app" bằng các mốc trong `StartupProbe`:

| Mốc | Chi phí |
|---|---|
| `main()` → `didFinishLaunching` (NSApplication khởi tạo) | ~110 ms |
| dựng menu bar | ~4 ms |
| **dựng `MainWindowController`** | **~122 ms** |
| `showWindow` (vẽ lần đầu) | ~92 ms |

Đo tiếp từng view (mốc tạm đặt trong `init` của mỗi lớp, đã gỡ sau khi đo):

| View | Lần đầu | Lần sau |
|---|---|---|
| `WindowedTextView` (pane soạn thảo) | **49,7 ms** | 0,8 ms |
| `CSVValidationPanel` | **25,5 ms** | — |
| `StatusBarView` | 16,2 ms | 3,8 · 4,7 ms |
| `WorkspaceView` | 7,5 ms | — |
| `CSVTableView` | 4,2 ms | — |
| `TabBarView` | 2,7 ms | — |
| `FunctionListView`, `CSVCleanPanel` | < 1 ms | — |

**Con số quan trọng nhất ở đây là cột "lần sau".** `WindowedTextView` thứ nhất tốn 49,7 ms, cái
thứ hai chỉ 0,8 ms. `CSVValidationPanel` — một panel đơn giản — tốn 25,5 ms chỉ vì nó là view
đầu tiên chạm tới `NSTableView`.

Nghĩa là phần lớn chi phí không phải "dựng nhiều view" mà là **lần đầu chạm vào một lớp AppKit**:
nạp lớp, dựng bộ máy TextKit, khởi tạo hệ thống font. Dựng lười chỉ **DỜI** chi phí ấy sang view
tiếp theo cùng họ, chứ không xóa nó — hoãn `CSVValidationPanel` thì `CSVTableView` sẽ trả 25 ms
thay nó.

> **§2.10 lật ngược kết luận này.** Đoạn trên đúng về phần DỰNG view, nhưng nó đo nhầm chỗ: phần
> đắt không phải dựng mà là lần GIẢI Auto Layout đầu tiên, và khoản ấy thì mất hẳn chứ không dời
> đi đâu. Thực đo được **−116 ms**, không phải −45 ms. Giữ nguyên đoạn này để thấy phép đo nào
> đã sửa nó.

### 2.7 Con đường đạt 500 ms

| | ms |
|---|---|
| Hiện tại | 794 |
| − đưa toàn bộ grammar khỏi binary (C đầy đủ) | −240 |
| − dựng lười các view đang ẩn | **~−45** (không phải −100) |
| **Còn lại** | **~509** — vẫn sát trần, có thể vẫn trượt |

> **Bảng này đã lỗi thời — xem §2.9 và §2.10 để lấy số thật.** Cả hai ước tính ở đây đều lệch:
> tách grammar cho −104 ms (không phải −240, vì chỉ tách ba cái nặng nhất chứ không tách hết), và
> dựng lười cho −116 ms (không phải −45). Hai cái lệch ngược chiều nhau nên tổng thì gần: bảng
> đoán 509 ms, thực đo **574 ms**.

**Sửa lại con số của chính bảng này.** Bản đầu ghi −100 ms cho dựng lười; đo từng view xong thì
thấy quá lạc quan. Chỉ hoãn được trọn vẹn những view mà cả HỌ lớp của nó không bị chạm tới
trong phiên — thực tế là nhóm dùng `NSTableView` khi người dùng ở chế độ văn bản, khoảng 40–50 ms.
`WindowedTextView` 49,7 ms thì không hoãn được: vùng soạn thảo luôn cần ngay.

Phần còn lại của ngân sách nằm ở hai khoản gần như không cắt được: `NSApplication` khởi tạo
~105 ms và `showWindow` (vẽ lần đầu) ~92 ms.

Kết luận thẳng: **C + dựng lười đưa được về khoảng 509 ms — sát trần 500 chứ chưa chắc dưới.**
Nếu muốn chắc chắn đạt thì phải cắt thêm ở `showWindow` (ví dụ hiện cửa sổ trước, đổ nội dung
sau), hoặc chấp nhận sửa trần theo bảng ngân sách như phương án A đề nghị.

### 2.8 PoC-E phần hai — `dlopen` có chạy được không, và giá bao nhiêu

Phương án C cần một cơ chế nạp grammar nằm ngoài binary chính. Trước khi cam kết, dựng thử bằng
clang trực tiếp (chưa đụng `Package.swift`): gộp ba grammar nặng thành một dylib, `dlopen` +
`dlsym` rồi parse thật một đoạn C#.

Grammar không gọi hàm nào của lõi tree-sitter — chúng chỉ `#include "tree_sitter/parser.h"` và
trả về một `TSLanguage` tĩnh. Nên dylib đứng độc lập được.

| | Kết quả |
|---|---|
| dylib (csharp + cpp + ruby) | **10 MB** |
| `dlopen` nguội | **286 · 289 · 309 ms** |
| `dlopen` ấm | **0,3 ms** |
| `dlsym` | 0,0 ms |
| parse thật một đoạn C# | 0,6 ms |
| cây trả về | `(compilation_unit (class_declaration name: (identifier) …` — **ABI khớp** |

**Chi phí không biến mất, nó CHUYỂN CHỖ.** Trước: mọi người trả ~140 ms mỗi lần khởi động cho
ba ngôn ngữ mà phần lớn không dùng. Sau: chỉ người mở file C#/C++/Ruby trả ~290 ms, một lần
trong phiên, và trả được ở luồng nền — tô màu vốn đã bất đồng bộ (`AsyncHighlighter`), nên file
mở ra ngay còn màu đến sau.

PoC ĐẠT. Phương án C khả thi về kỹ thuật.

### 2.9 Sau khi triển khai thật — số đo, không phải ước tính

Ba grammar nặng đã chuyển sang target `TreeSitterHeavy`, dựng thành `libTreeSitterHeavy.dylib`
đặt trong `Contents/Frameworks`, nạp bằng `dlopen` lần đầu người dùng mở C++/C#/Ruby
(`Sources/GEditorCore/Syntax/HeavyGrammars.swift`).

Trung vị 9 lần nguội, 9 lần ấm, cùng máy, cùng script:

| | Trước | Sau | |
|---|---|---|---|
| binary chính | 22 MB | **11,6 MB** | −47% |
| dylib nằm cạnh | — | 10,5 MB | không trên đường khởi động |
| **khởi động nguội** | **794 ms** | **690 ms** | **−104 ms** |
| — phần dyld | 500 ms | 385 ms | −115 ms |
| — phần app tự dựng | 294 ms | 305 ms | +11 ms (nhiễu) |
| khởi động ấm | 328 ms | 328 ms | không đổi |
| RAM nhàn rỗi | 25,4 MB | 25,5 MB | không đổi |

**Khớp dự đoán.** §2.5 đo bản dựng thử 12 MB được 674 ms; bản thật 11,6 MB cho 690 ms. Sai số
16 ms — trong khoảng dao động giữa các lần đo (min 649 · max 731).

**Điều này KHÔNG đủ để đạt chỉ tiêu.** 690 ms vẫn trượt 500 ms, và §2.7 đã nói trước điều ấy:
sàn của một app AppKit rỗng đã là 265 ms, phần còn lại phải cắt từ chỗ khác. Phương án C làm
đúng phần việc của nó và chỉ phần việc ấy.

**Còn lại phải trả ở đâu** (theo §2.6–2.7, chưa làm):

| Việc | Ước tính | Đã đo chưa |
|---|---|---|
| bỏ `showWindow` khỏi đường tới hạn | −92 ms | chưa |
| dựng lười các view phụ | −45 ms | đã đo ở §2.6 |
| còn thiếu để về 500 ms | ~55 ms | chưa biết lấy ở đâu |

**Giá người dùng C++/C#/Ruby phải trả**, theo §2.8: `dlopen` nguội ~290 ms một lần trong phiên,
ở luồng nền — file mở ra ngay, màu đến sau, đúng như vẫn xảy ra với file lớn. Những lần sau
0,3 ms.

**Ba thứ canh cho việc này không hỏng âm thầm**, vì hỏng kiểu nào cũng không ai thấy:

- `Tests/GEditorCoreTests/HeavyGrammarsTests.swift` — ba grammar nạp được thật qua `dlopen`;
  đã kiểm chứng bài này ĐỎ khi giấu dylib đi.
- `scripts/run-self-test.sh` và `scripts/build-universal.sh` — `otool -L` chặn việc app lỡ
  liên kết tĩnh trở lại. Một dòng `import TreeSitterHeavy` lọt vào lớp app là đủ để mất sạch
  phần tiết kiệm mà không tính năng nào hỏng.
- Bài tự kiểm "grammar nặng chưa nạp lúc khởi động" — canh rằng dựng cửa sổ không chạm dylib.

### 2.10 Dựng lười giao diện — nơi chi phí thật sự nằm

§2.6 từng ước tính khoản này **−45 ms** và tôi đã báo con số ấy. Nó sai, vì nó đo nhầm thứ: tôi
đo chi phí DỰNG các view, trong khi phần đắt là lần GIẢI Auto Layout đầu tiên.

Chia nhỏ mốc trong một lần chạy ấm (trước thay đổi):

| Đoạn | Thời gian |
|---|---|
| `NSApplication` khởi tạo tới `didFinishLaunching` | 95 ms |
| dựng menu bar | 4 ms |
| `NSWindow(...)` | 40 ms |
| dựng các view (thuộc tính của controller) | 44 ms |
| tạo danh sách ràng buộc | 0,8 ms |
| **giải Auto Layout lần đầu** | **96 ms** |
| `loadDocument(.untitled())` | 20 ms |
| hiện cửa sổ và vẽ | 10 ms |

Phép đối chứng: dựng đúng cây view ấy nhưng bỏ sáu panel đang ẩn ra ngoài — lần giải đầu tụt
còn **7 ms**. Sáu panel ẩn với chiều cao 0 vẫn bắt Auto Layout đi hết cây con bên trong chúng.
`isHidden` không cứu được gì.

Nên panel giờ chỉ vào cửa sổ khi người dùng mở nó lần đầu (`MainWindowController.attach`).

| | Trước | Sau | |
|---|---|---|---|
| **khởi động nguội** | 690 ms | **574 ms** | **−116 ms** |
| — phần app tự dựng | 305 ms | 207 ms | −98 ms |
| khởi động ấm | 328 ms | 208 ms | −120 ms |
| **RAM nhàn rỗi** | 25,5 MB | **16,6 MB** | −35% |

Khoản RAM là quà kèm, không phải mục tiêu: sáu panel không dựng thì cũng không chiếm chỗ.

Hai chốt chặn, vì kiểu hỏng ở đây chỉ biểu hiện thành "app chậm đi mươi mili-giây":

- Bài tự kiểm "cửa sổ khởi động chỉ dựng ba tầng luôn hiện" — so với ảnh chụp trạng thái lấy
  ĐÚNG lúc cửa sổ hiện ra, nên không phụ thuộc thứ tự chạy các bài. Đã kiểm chứng bài này ĐỎ
  khi cố tình gắn `cleanPanel` vào đường khởi động.
- Bài "mở rồi đóng panel thì panel Ở LẠI" — gắn/gỡ theo từng lần bật/tắt chỉ dời chi phí sang
  chỗ khó chịu hơn.

### 2.11 Sàn của AppKit — điều này đổi cách đọc chỉ tiêu

Trước khi đi tiếp, đo xem một app AppKit **rỗng** tốn bao nhiêu dưới ĐÚNG giao thức của
`run-startup-kpi.sh` (mỗi lần một bản sao mới của binary). App ấy làm đúng những gì GEditor làm
và không hơn: `NSApplication`, một menu, một `NSWindow` cùng `styleMask`, một `NSView` rỗng,
`showWindow`.

| | Binary | Nguội (bản sao mới) | Ấm |
|---|---|---|---|
| app AppKit rỗng | 80 KB | **~320 ms** (dyld ~190) | 130 ms |
| GEditor sau §2.10 | 11,6 MB | 574 ms (dyld 352) | 208 ms |

**Trần 500 ms chỉ chừa ~180 ms cho toàn bộ phần việc của GEditor.** Một app 80 KB không mở file
nào, không tô màu, không có tab, đã tiêu 320 ms trong đó — và 190 ms của nó là dyld, tức là
trước khi dòng mã nào của ta chạy.

Điều này KHÔNG có nghĩa là bỏ cuộc, nhưng nó đổi câu hỏi. GEditor hiện đắt hơn app rỗng đúng
**254 ms**, trong đó ~160 ms là dyld đọc thêm 11,5 MB binary và ~95 ms là việc của chính app.
Cắt tiếp phần app xuống 0 vẫn còn 480 ms — sát trần, với một app không làm gì.

Một biến chưa loại được, và nó có thể lật ngược cả bảng này: giao thức "bản sao mới mỗi lần"
buộc dyld dựng lại launch closure ở MỌI lần đo. Một `.app` cài đặt bình thường được hệ thống
giữ closure ấy. Nếu đúng thế thì con số người dùng thật cảm nhận gần với **208 ms** hơn là
574 ms. Đo được điều này cần bản ký bằng Developer ID — cùng phép đo đã nằm ở §5.

> **24/08/2026.** Phần lớn nghi vấn ấy đã đo được mà KHÔNG cần Developer ID — xem §2.12. Tóm
> tắt: giao thức đang đo **lần khởi động đầu tiên của một file mà nhân chưa từng thấy**, và
> lần thứ hai của chính file ấy tốn 221 ms. Cái chưa đo được thu hẹp lại còn đúng một câu:
> khoản ấy có trở lại sau mỗi lần khởi động máy không.

### 2.12 Bảng ký hiệu — 68 ms không mua gì, và ý nghĩa thật của con số "nguội"

§2.11 dừng lại ở chỗ "dyld tốn 352 ms, chưa biết vào đâu". Bổ nó ra bằng ba phép đo.

**(a) Cùng một file, lần đầu và lần sau.** Chép binary ra đường dẫn mới rồi chạy, sau đó chạy
LẠI CHÍNH bản sao ấy:

| | preMain |
|---|---|
| bản sao mới, chạy lần đầu | **424 ms** |
| bản sao mới, đã `cat` cho mọi trang vào page cache | **277 ms** |
| chạy lại chính bản sao ấy | **11 ms** |

Hàng giữa loại được giả thuyết "chậm vì đọc đĩa": `cp` đã ghi file qua page cache, và ép đọc
thêm một lượt nữa chỉ lấy lại 147 ms trong số 413. **266 ms còn lại là việc nhân và dyld làm
một lần cho mỗi file** — chủ yếu là kiểm chữ ký từng trang — và nó biến mất hoàn toàn ở lần
chạy thứ hai. Tính `codesign -v` trước cũng không giúp: nhân tự kiểm lại theo cách của nó.

**(b) Khoản ấy lớn theo kích thước file.** Cùng giao thức, trên các binary cỡ khác nhau:

| Binary | Cỡ | Lần đầu | Lần sau | Hiệu |
|---|---|---|---|---|
| `/usr/bin/true` | 0,08 MB | 138,5 ms | 2,5 ms | 136,0 ms |
| `/bin/date` | 0,13 MB | 141,4 ms | 4,0 ms | 137,4 ms |
| `geditor` (CLI) | 20,78 MB | 347,5 ms | 6,1 ms | 341,4 ms |

**≈135 ms cố định cho mỗi file lạ, cộng ≈10 ms mỗi MB.** Một app rỗng 80 KB trả 135 ms không
phải vì nó làm gì, mà vì nó là một file nhân chưa từng thấy — đó chính là "sàn AppKit" mà
§2.11 đo ra và quy nhầm cho AppKit.

**(c) Nên mỗi MB thừa trong binary là tiền thật.** Và binary đang mang một khoản thừa rõ ràng:
bảng ký hiệu. `strip -x` trên chính GEditorApp:

| | Cỡ | preMain (bản sao mới) |
|---|---|---|
| như đang giao | 13,33 MB | 363 · 355 ms |
| sau `strip -x` | 11,20 MB | 304 · 279 ms |

2,13 MB đổi lấy **~68 ms**, tức ~32 ms mỗi MB — cao hơn con số của (b) vì binary của app GUI
bị chạm tới nhiều trang hơn một CLI. Bảng ấy không được đọc một lần nào lúc chạy.

`-x` chứ không phải `strip` trần: `-x` chỉ bỏ ký hiệu CỤC BỘ và giữ nguyên metadata mà Swift
runtime cần. Đã chạy 166/166 bài tự kiểm giao diện trên bản đã strip trước khi đưa vào đường
đóng gói, và giữ lại bản chưa strip ở `dist/<kênh>/symbols/` — không có nó thì crash report
mất mọi hàm `private`.

**KPI sau khi strip** (`scripts/run-startup-kpi.sh --runs 7`, arm64):

| | Trước | Sau |
|---|---|---|
| **khởi động nguội** | 601 ms | **507 ms** (min 475) |
| — dyld | 368 ms | 286 ms |
| — app tự dựng | 229 ms | 223 ms |
| khởi động ấm | 232 ms | 221 ms |

`run-startup-kpi.sh` giờ tự strip bản sao nó đo. Không làm thế thì KPI báo một con số xấu hơn
sản phẩm thật — cùng loại sai với cái bẫy dylib mà chính script ấy đã cảnh báo, chỉ ngược
chiều. `build-universal.sh` có một chốt chặn hỏi thẳng bản giao còn ký hiệu cục bộ nào không:
kiểu hỏng ở đây không làm tính năng nào sai, nó chỉ làm app chậm đi 68 ms và không ai thấy.

**(d) Phần app tự dựng, chia nhỏ hơn nữa.** §2.10 để lại một quãng 50 ms không ai giải thích
giữa mốc `menuBar` và `buildContent.start`. Thêm hai mốc thì nó tách ra (lần chạy ấm):

| Đoạn | |
|---|---|
| tiến trình bắt đầu → `didFinishLaunching` | ~85 ms |
| dựng menu bar | 3,6 ms |
| `NSWindow(...)` + `center()` | **36,7 ms** |
| khởi tạo thuộc tính của controller | 15,0 ms |
| `buildContent()` | 25,1 ms |
| `showWindow` (giải bố cục + vẽ lần đầu) | **40,5 ms** |

Không còn khoản nào lớn mà rẻ ở đây. Hai mục đắt nhất là `NSWindow` và lần vẽ đầu, cả hai đều
là việc của AppKit.

**Điều còn lại chưa đo được.** Khoản 266 ms ở (a) là trạng thái nhân giữ trong bộ nhớ, nên nó
mất khi tắt máy. Nghĩa là người dùng gặp con số "nguội" **một lần sau mỗi lần khởi động máy**,
còn mọi lần mở sau đó là 221 ms. Kiểm câu ấy cần khởi động lại máy — đã thêm vào §5.

### 2.13 PoC-F — còn đúng một cần gạt, và nó không phải cái tôi tưởng

Sau §2.12 còn 7 ms trên trần. Câu hỏi: cắt tiếp ở đâu. Trả lời bằng **link map** của `ld` chứ
không bằng kích thước tệp `.o` — ở bản release, `.o` vẫn mang debug info, và nó nói dối theo
hướng rất dễ tin: `MarkdownPreview.swift.o` nặng 2,36 MB nhưng góp vào binary vài chục KB.

Quy từng byte đã liên kết về file sinh ra nó (10,20 MB có tên trong map):

| Nguồn | | |
|---|---|---|
| **grammar tree-sitter (17 ngôn ngữ)** | **7,19 MB** | **70,5 %** |
| GEditorCore | 1,17 MB | 11,5 % |
| GEditorApp | 1,13 MB | 11,0 % |
| PCRE2 | 0,52 MB | 5,1 % |
| lõi tree-sitter | 0,11 MB | 1,1 % |

Nặng nhất: typescript 1,34 · bash 1,30 · rust 1,06 · php 1,00 · c 0,60 MB.

Điều này **đóng lại** mọi hướng khác. `-Osize`, `-dead_strip`, gọt mã Swift — tất cả cùng nhắm
vào 2,3 MB, tức cùng lắm vài chục ms. Chỉ còn grammar.

**(a) Cận trên của phần được, đo chứ không ngoại suy.** Dựng một bản CHỈ ĐỂ ĐO, thay cả 17
bảng tra bằng hàm rỗng (bản ấy không tô màu, và đã bỏ đi ngay sau khi đo):

| | Binary sau strip | Nguội | dyld |
|---|---|---|---|
| như đang giao | 11,20 MB | 507 ms | 286 ms |
| không grammar nào | **3,47 MB** | **~396 ms** | ~190 ms |

**−111 ms**, tức ~14 ms mỗi MB, và về dưới trần 500 với khoảng dư ~100 ms.

**(b) Nhưng "mỗi ngôn ngữ một dylib" là phương án SAI.** Ý tưởng tự nhiên là tách nhỏ để ai mở
Rust chỉ trả tiền cho Rust. Đo `dlopen` nguội trên các dylib grammar dựng riêng (9 lần mỗi
loại, ký ad-hoc như trong bundle, trung vị):

| dylib | Cỡ | `dlopen` nguội | ấm |
|---|---|---|---|
| c | 0,63 MB | 449,6 ms | — |
| php | 1,04 MB | 444,7 ms | — |
| bash | 1,35 MB | 436,7 ms | 0,2 ms |
| typescript | 1,39 MB | 451,2 ms | — |
| `libTreeSitterHeavy` (3 ngôn ngữ) | 10,47 MB | 507,2 ms | 0,4 ms |

**Phí `dlopen` gần như KHÔNG phụ thuộc kích thước**: một dylib 0,63 MB tốn đúng bằng một dylib
1,39 MB. Phí là ~440 ms cố định cho mỗi tệp mới, phần theo cỡ chỉ ~7 ms mỗi MB — cùng hình
dạng "cố định + theo MB" đã thấy ở §2.12(b), chỉ là hằng số lớn hơn nhiều vì `dlopen` một dylib
đi qua `amfid`.

Nên tách nhỏ là **làm tệ đi**: người mở ba ngôn ngữ trả ba lần 440 ms thay vì một lần 500 ms.
Đúng hướng ngược lại — dồn TẤT CẢ grammar vào MỘT dylib lười, vì thêm 7 MB vào nó chỉ đắt thêm
~50 ms cho người thật sự mở file cần tô màu.

(Phép đo đầu tiên của mục này cho ra dãy 149 → 722 ms trên cùng một tệp 0,63 MB. Đó là nhiễu
chứ không phải số liệu; bảng trên là bản đo lại có ký ad-hoc, 9 lần, kèm khoảng min–max.)

**Đánh đổi, và cái đã chốt.** Không có phương án nào vừa nhanh vừa không mất gì:

| | Nguội | Ai trả `dlopen`, và trả gì |
|---|---|---|
| giữ nguyên | ~520 ms | chỉ người mở C#/C++/Ruby — ~507 ms, một lần mỗi phiên, ở luồng nền |
| chuyển 4 grammar nặng nhất (4,79 MB) | ~438 ms | thêm người mở TypeScript/bash/Rust/PHP |
| **chuyển cả 17** ✅ **anh chốt 24/08/2026** | **~396 ms** | mọi người mở file CẦN TÔ MÀU — một lần mỗi phiên, ở luồng nền. Ai chỉ mở `.txt`/`.csv`/`.log` không trả gì |

Người dùng KHÔNG đứng nhìn khoản ấy: `AsyncHighlighter` chạy ở luồng nền, nên cửa sổ mở ngay
và màu đến sau — đúng thứ vẫn xảy ra với file lớn hôm nay.

**Triển khai.** Cả hai mươi grammar giờ nằm ở target `TreeSitterHeavy`; `Sources/TreeSitter`
chỉ còn LÕI. `SyntaxLanguage.handle` từng là một `switch` hai mươi nhánh gọi thẳng
`tree_sitter_<tên>()` — giờ là một dòng qua `GrammarLibrary`, vì hai mươi nhánh cùng gọi một
hàm là hai mươi chỗ để quên khi thêm ngôn ngữ thứ hai mươi mốt.

`HeavyGrammars` đổi tên thành **`GrammarLibrary`**: nó không còn giữ riêng phần "nặng" nào cả,
và một cái tên nói sai về thứ nó chứa là loại nợ khó thấy nhất.

**Hai chốt chặn** (kiểu hỏng ở đây không làm tính năng nào sai, nó chỉ làm app chậm đi):

- `GrammarLibraryTests.testDylibHoldsEverySingleLanguage` so `GrammarLibrary.symbolNames` với
  `SyntaxLanguage.allCases`. Sót một ngôn ngữ là kéo 0,6–1,4 MB bảng tra trở lại đường khởi
  động; thừa một khóa là ngôn ngữ ấy mất màu lúc chạy. Cả hai đều không lộ ra lúc biên dịch.
- Bài tự kiểm "bảng tra grammar chưa nạp lúc khởi động" giờ hỏi **ảnh chụp lúc cửa sổ hiện
  ra** (`StartupProbe.grammarLibraryLoadedAtLaunch`) chứ không hỏi trạng thái hiện thời. Trước
  đây chỉ ba ngôn ngữ đi qua dylib nên hỏi giữa chừng còn có nghĩa; giờ bất kỳ bài nào mở một
  file có tô màu cũng nạp nó, và một bài kiểm phụ thuộc thứ tự chạy sẽ đỏ vì lý do không liên
  quan gì tới thứ nó đo.

---

## 3. Ba phương án

### A. Giữ nguyên, sửa chỉ tiêu

Nhận rằng 500 ms là trần đặt trước khi có số đo, và một app AppKit rỗng đã tốn 265 ms trong đó.

- **Được:** không đụng vào ADR-04, không đụng vào đường ký/công chứng.
- **Mất:** một chỉ tiêu P0 bị sửa để khớp thực tế thay vì ngược lại. Chỉ chấp nhận được nếu
  trần mới có căn cứ — ví dụ 800 ms nguội / 350 ms ấm, kèm chính bảng ngân sách ở §2.4.
- **Còn một biến chưa loại được:** bản ký bằng **Developer ID thật** và đã notarize. §2.3 đã
  loại được nghi vấn "tại chưa đóng gói" (bundle ad-hoc signed cũng ~735 ms), nhưng Gatekeeper
  đối xử với bản đã đăng ký theo cách khác. Cần tài khoản Developer ID mới đo nốt.

### B. Tách grammar ra khỏi đường khởi động

Grammar vẫn biên dịch từ nguồn và vẫn ký cùng app, nhưng nằm trong một dylib riêng trong
bundle, `dlopen` khi mở file đầu tiên cần tô màu.

- **Được:** ước tính −240 ms → khoảng **554 ms**. Vẫn trượt 500 nhưng sát; cộng với việc cắt
  phần "app 294 ms" thì có cửa đạt.
- **Mất:** chạm vào chính lý do ADR-04 chọn dựng tĩnh — "không có thư viện rời để ký, để công
  chứng, hay để lệch ABI với lõi". Phải trả lời được: dylib trong bundle có làm hardened runtime
  và notarization phức tạp thêm không.
- **Phải PoC trước khi chốt:** dựng thật một dylib grammar + `dlopen`, đo lại khởi động nguội và
  đo độ trễ lần tô màu đầu tiên. Con số −240 ms ở trên là suy ra từ thí nghiệm `.incbin`, chưa
  phải đo trên bản thật.

### C. Giảm số grammar dựng sẵn

Dựng tĩnh 5–6 ngôn ngữ hay dùng nhất, số còn lại tải như gói bổ sung (đúng cơ chế mà SAD đã
định cho DuckDB: "optional component tải khi bật").

- **Được:** giảm tuyến tính theo phần bảng tra bỏ đi.
- **Mất:** người dùng mở một file Rust lần đầu thì không có màu cho tới khi tải xong gói — với
  một trình soạn thảo, đó là một sự cố nhìn thấy được. Cần hạ tầng phát hành gói mà dự án chưa có.

---

## 4. Điều ADR này KHÔNG hỏi lại

**DuckDB.** SAD đã chốt: "+~40 MB bundle — tách thành component tải kèm tùy chọn", "optional
component tải khi bật tính năng SQL". Số đo ở §2.2(c) chỉ làm quyết định ấy có bằng chứng: 17,6
MB đáng 240 ms, nên 40 MB nhúng **thẳng vào binary chính** sẽ đẩy khởi động nguội lên quanh 1,3
giây — gấp 2,6 lần trần. Không có gì để bàn lại.

> **Bổ sung 22/08/2026, sau khi chốt mục tiêu App Store.** Phần "tải kèm tùy chọn" của SAD
> KHÔNG dùng được cho bản App Store: điều 2.5.2 cấm tải và thực thi mã lúc chạy. Nhưng kết luận
> ở trên vẫn đứng, vì nó nói về "nhúng thẳng vào binary chính" — mà đó không phải lựa chọn duy
> nhất. Đường đúng là chính §2.9: một dylib trong `Contents/Frameworks`, `dlopen` lần đầu người
> dùng chạy SQL. Đã đo trên grammar nặng: 10,5 MB chuyển ra khỏi binary chính đổi được 104 ms
> khởi động, và người không dùng tới thì không trả gì.
>
> Cái giá còn lại của DuckDB là **dung lượng tải về**, không phải thời gian khởi động. Xem
> `docs/appstore-ra-soat.md` §4 để biết cả cái bẫy extension tự tải của DuckDB.

---

## 5. Việc còn cần anh

~~Chọn giữa A, B, C.~~ Anh chốt C ngày 22/08/2026; đã triển khai, số đo ở §2.9.

Cách triển khai thực tế là **C dùng cơ chế của B**: chỉ ba grammar nặng nhất bị tách, và chúng
đi vào một dylib nằm ngay trong bundle chứ không phải gói tải về. Nghĩa là không cần máy chủ
phát hành, không có trạng thái "chưa tải xong", và cái giá mà §3.C lo — "mở file Rust lần đầu
thì không có màu cho tới khi tải xong" — không xảy ra. Khi nào có hạ tầng phát hành thật thì
chuyển tệp dylib ấy ra ngoài bundle, và chỗ duy nhất phải sửa là `HeavyGrammars.candidatePaths`.

PoC-E đã chạy trước khi sửa mã, đúng luật của dự án (§2.5 đo kích thước, §2.8 đo `dlopen`) —
và nó đáng: §2.5 chứng minh C **một mình không đủ**, trước khi mã nào bị viết ra.

**Việc còn lại cần tới anh, chỉ một:** ký bằng **Developer ID và notarize rồi đo lại**. Đó là
biến duy nhất chưa loại được trong bảng ngân sách (§2.3 mới loại được nghi vấn "tại chưa đóng
gói"), và cũng chính là một trong hai việc đã nằm ở §5 `docs/trang-thai.md` từ trước.

**Còn phải quyết, nhưng chưa gấp:** 690 ms vẫn trượt 500 ms. Sau khi cắt nốt hai khoản ở bảng
§2.9 (~137 ms) thì còn thiếu ~55 ms chưa biết lấy ở đâu, trong khi sàn AppKit rỗng đã là 265 ms.
Nếu tới lúc ấy vẫn không đạt thì câu hỏi quay về phương án **A** — sửa trần cho khớp thực tế,
có bảng ngân sách §2.4 làm căn cứ. Chưa cần trả lời bây giờ; đợi đo xong hai khoản kia đã.
