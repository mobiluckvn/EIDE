# Kế hoạch hoàn thiện GEditor theo SRS v2.2

Lập 26/08/2026 · đối chiếu **SRS v2.2 ↔ SAD v2.3 ↔ STP v2.3 ↔ UI/UX v2.3 ↔ RTM v2.3**
Hiện trạng nguồn: `docs/trang-thai.md` §5 · Phạm vi kế hoạch: **79 FR chưa có mã + 27 NFR chưa
có mã + 11 NFR mới đạt một phần**

---

## 0. Đọc gì trước khi đọc kế hoạch

Đã xong **87/167 FR** và **23/61 NFR** (thêm 11 NFR đạt một phần — phần lớn chờ một lần kiểm tay,
không chờ mã). Phần đã xong không phải nửa dễ: nó gồm toàn bộ Phase 1
(51 FR), gần hết Phase 2, và **bốn mục mà SRS §2.6 xếp vào Phase 3** đã làm sớm — plugin native
(FR-PLUG-702/703/704), SQL trên CSV (FR-CSV-407), AppleScript/Services (FR-AUTO-606) và nhánh
App Store. Bốn PoC bắt buộc đã chốt, ngân sách khởi động đã đạt, độ phủ lõi 94,07%.

Phần còn lại **không cùng loại với phần đã làm**. 79 FR còn lại không phải "thêm lệnh vào trình
soạn thảo" — chúng là bốn sản phẩm con nằm chồng lên trình soạn thảo:

| | Cụm | FR | Bản chất |
|---|---|---|---|
| 1 | QRY + RPT + DQR + MIN | 34 | một **bộ công cụ phân tích dữ liệu** — engine truy vấn, engine vẽ, engine thống kê, engine báo cáo |
| 2 | MMD | 8 | một **trình soạn sơ đồ hai chế độ** với vòng đồng bộ văn bản ↔ hình |
| 3 | KNW | 26 | một **workbench kỹ sư tri thức** — JSONL, đồ thị, BM25, đánh giá retrieval |
| 4 | AGT + PY | 19 | hai **runtime bên ngoài** — LLM client BYOK và CPython out-of-process |

Cộng thêm FR-CLN-004. Đó là lý do kế hoạch này mở đầu bằng **quyết định** chứ không bằng lịch:
ba câu hỏi kiến trúc dưới đây định hình 60 trong 79 FR còn lại, và trả lời sai một câu thì mã
viết ra phải bỏ, chứ không phải sửa.

---

## 1. Ba quyết định chặn — phải chốt trước khi viết dòng mã Phase 3 nào

> **Cập nhật 26/08/2026: hai trong ba đã ĐO XONG.** PoC-K và PoC-L đã chạy, kết quả ở
> `benchmarks/results/poc-k-arm64.json` và `poc-l-arm64.json`. Cả hai đều lật một tiền đề:
> DuckDB **không** tốn gì lúc khởi động (nhưng nặng gấp 2,4 lần con số SAD ghi), và WebKit
> **không** tốn gì lúc khởi động (nên lý do ta từ chối WebView ở FR-FMT-506 là sai). Quyết định
> vẫn là của anh — nhưng giờ nó là quyết định về **sản phẩm**, không còn là câu hỏi kỹ thuật.

### 1.1 DuckDB — ✅ **ĐÃ CHỐT 26/08/2026: nhúng, nạp lười** (`docs/adr/ADR-14-duckdb-va-nap-luoi.md`)

> Anh chốt: **nhúng DuckDB, dung lượng bundle được phép tăng, khởi động thì không.** Kèm một
> điều kiện đã được biến thành cổng chặn chứ không để nằm trong tài liệu: *khởi động chỉ kích
> hoạt tính năng thực sự cần; còn lại khi cần mới kích hoạt.* Cơ chế canh ở ADR-14 §4, đã được
> xác nhận **ĐỎ được** bằng cách cố tình phá. **Gate 1 không còn chặn FR nào.**
>
> **Sửa cùng ngày:** anh chốt tiếp *"bỏ hết engine tự viết"* — nên ADR-11 **bị thay thế**, và
> DuckDB là engine SQL **duy nhất**. `CSVQuery` + `CSVQueryParser` + `CSVQueryRunner` (1.240
> dòng) và 48 bài kiểm của chúng đã bị xoá. Xem ADR-14 §3.

Phần dưới giữ lại nguyên văn vì nó là hồ sơ dẫn tới quyết định.

**Sự việc.** `grep DuckDB` trên SRS v2.2 → **23 lần**. ADR-11 (24/08/2026) lật DuckDB và chốt
tập con SQL tự viết, nhưng chính ADR ấy ghi rõ phạm vi lật:

> *"**Lật:** lựa chọn DuckDB trong SAD cho FR-CSV-407. Phần còn lại của SAD không đổi."*

Phần còn lại ấy có bảy chỗ dựa vào DuckDB, và **năm chỗ đòi cú pháp mà engine tự viết hiện chưa
có**:

| Chỗ dựa vào | Đòi gì | Engine hiện có? |
|---|---|---|
| FR-QRY-001 Query Workbench | console SQL cho **CSV · TSV · JSONL · Parquet** | ⛔ chỉ đọc CSV/TSV |
| FR-QRY-005 Join đa file | **JOIN · UNION** trên bảng ảo nhiều file | ⛔ `JOIN`/`UNION` đang báo "chưa làm" |
| FR-QRY-003 Pivot | sinh SQL có `DISTINCT`, nhiều hàm gộp | ⛔ `DISTINCT` chưa làm |
| FR-DQR-001 rule `expr` + `foreign_key` | biểu thức SQL boolean tùy ý + join liên file | ⛔ |
| FR-KNW-907 Corpus SQL | truy vấn thống kê trên JSONL/Parquet | ⛔ |
| FR-KNW-913 Graph query | dịch openCypher 3 hop **sang SQL** → nhiều JOIN lồng | ⛔ |
| NFR-DQR-01 | *"RuleCompiler gom rule cùng cột thành ít lượt quét DuckDB nhất"* | — |

Engine tự viết hiện làm được `SELECT/AS/WHERE/GROUP BY/ORDER BY/LIMIT/OFFSET` + 5 hàm gộp, và
**báo lỗi có tên** cho `JOIN`, `HAVING`, `DISTINCT`, `LIKE`, `IN`, `BETWEEN`, `UNION`, cửa sổ hàm.
Đúng thiết kế, và đúng cho FR-CSV-407. Nhưng đó chính là danh sách mà bảy chỗ trên cần.

**Ba đường, và cái giá thật của từng đường:**

| | Đường | Được | Mất |
|---|---|---|---|
| **A** | Mở rộng engine tự viết: JOIN băm, subquery, DISTINCT/IN/LIKE/BETWEEN/HAVING, reader JSONL + Parquet | không thêm phụ thuộc; App Store và bản trực tiếp vẫn **một đường mã**; giữ trọn triết lý "báo lỗi có tên" | đây là **gói việc lớn nhất còn lại của cả dự án** — viết một query planner. Riêng Parquet là một định dạng cột nén hoàn chỉnh, không phải "thêm một reader" |
| **B** | Nhúng DuckDB làm dylib **nạp lười** (`dlopen`), cả hai kênh | JOIN · subquery · JSONL · Parquet có ngay; NFR-DQR-01 và NFR-KNW-02 viết đúng nguyên văn SRS | +~40 MB bundle; thêm một phụ thuộc phải build universal (NFR-PORT-04); phải đo lại ADR-08 |
| **C** | DuckDB ở bản trực tiếp, engine tự viết ở bản App Store | — | **loại thẳng**: phá nguyên tắc "một binary, một đường mã" đã chốt ở nhánh App Store, và sinh hai tập hành vi SQL khác nhau cho cùng một tài liệu người dùng |

### ĐÃ ĐO — `scripts/run-poc-k.sh`, 26/08/2026 · `benchmarks/results/poc-k-arm64.json`

| Câu hỏi | Số đo | Đọc thế nào |
|---|---|---|
| **Cỡ thật của dylib universal** | **94 MB** đã strip (arm64 45 + x86_64 48); nguyên bản 111 MB | SAD ghi *"~40 MB"*. Con số ấy chỉ đúng cho **một** kiến trúc, mà NFR-PORT-01 đòi cả hai. Cỡ thật **gấp 2,4 lần** giả định đang dùng để cân nhắc |
| **`dlopen` khi người dùng bấm SQL** | **6,9 ms** | rẻ, cùng bậc với `dlopen` libxml2 mà PoC-I đã chấp nhận |
| **Khởi động nguội khi dylib nằm trong bundle mà KHÔNG ai mở** | **−3 ms** (đối chứng cặp, 5 lần mỗi bên, cùng phiên) | **không tốn gì.** ADR-08 không bị đụng tới. Đúng như cấu tạo dự đoán, và giờ là số đo |
| **Hardened runtime + App Sandbox** | **chặn — nhưng chặn CẢ `libTreeSitterHeavy` của ADR-08** | xem dưới |
| **`WHERE` / `GROUP BY` trên 1 triệu hàng × 20 cột** | tự viết 677 / 791 / 1530 ms · DuckDB **144 / 147 / 155 ms** (4,7× · 5,4× · 9,9×) | đo lại engine tự viết **trong cùng phiên**, không so với 619/752 ms lưu từ phiên khác |
| **Nạp một lần vào bảng rồi hỏi** (hình dạng FR-QRY-001) | nạp 732 ms, sau đó **2 / 4 / 17 ms** | đây mới là con số của một phiên Workbench: **100–400×** |
| **Bảy câu engine tự viết TỪ CHỐI** | DuckDB làm được **cả bảy**, đáp án khớp công thức sinh fixture | JOIN 5 ms · DISTINCT 4 ms · HAVING 4 ms · IN 4 ms · LIKE 2 ms · BETWEEN 1 ms · subquery 3 ms |
| **`SELECT * LIMIT 10`** | tự viết **8 ms** · DuckDB 86 ms | chỗ **duy nhất** engine tự viết thắng — nó dừng sớm, DuckDB dựng đường ống trước |

**Về ô "hardened runtime chặn" — đây là chỗ dễ đọc sai nhất, nên nó có đối chứng.** Dưới chữ ký
**ad-hoc** + hardened runtime, library validation chặn `libduckdb.dylib` với lỗi *"different Team
IDs"*. Nhưng bộ đo chạy ma trận 2×2 và **`libTreeSitterHeavy.dylib` — dylib ta ĐANG GIAO — bị
chặn y hệt**; tắt hardened runtime thì cả hai nạp được. Nghĩa là:

- đây **không** phải điểm trừ của DuckDB. Nó là tính chất của việc ký ad-hoc (không có Team ID);
- và nó phơi ra một **giả định chưa ai kiểm của chính đường ký hiện tại**: `build-universal.sh`
  chỉ bật `--options runtime` ở nhánh có `GEDITOR_SIGN_IDENTITY`, nên **bản dev ad-hoc chưa bao
  giờ chạy dưới hardened runtime**, và việc `libTreeSitterHeavy.dylib` nạp được trong bản đã ký
  thật vẫn là suy luận. Cần một lần chạy với Developer ID thật (§6 mục 3 của trang trạng thái)
  — và lần ấy trả lời cho **cả hai** dylib cùng lúc.

**Hai lỗi của chính bộ đo, ghi lại vì cả hai đều suýt thành kết luận:**

1. `strip` một dylib đã ký làm chữ ký hỏng, và một dylib chữ ký hỏng **không báo lỗi `dlopen`** —
   nhân **giết cả tiến trình bằng SIGKILL** (mã thoát 137). Triệu chứng trông y hệt hết bộ nhớ.
   Phải `codesign` lại ngay sau `strip`.
2. Lượt chạy đầu của ma trận 2×2 cho "OK" ở **cả sáu ô** vì cờ `--options runtime` không được áp
   — bài đo báo xanh cho một cấu hình nó không hề dựng. Bộ đo giờ **in cờ ký thật ra màn hình**
   (`cờ=0x10002(adhoc,runtime)`) làm bằng chứng cấu hình đúng như định.

**Đề nghị: chọn đường B, và giữ nguyên ADR-11 cho FR-CSV-407.** Ba lý do, theo thứ tự sức nặng:

- **Đường A đắt hơn ta tưởng và không có đường tắt.** Bảy khoảng trống không phải bảy tính năng
  nhỏ — `JOIN`, subquery và `HAVING` đòi một query planner. Viết chúng là gói việc lớn nhất còn
  lại của cả dự án, và Parquet (FR-QRY-001, FR-KNW-907) là một định dạng cột nén hoàn chỉnh.
- **Cái giá đo được lại nhỏ hơn ta tưởng.** Khởi động: **0 ms**. Điều duy nhất thật sự đắt là
  **94 MB bundle** — và đó là một con số phải cân, không phải một rào chắn kỹ thuật.
- **Ranh giới sạch.** FR-CSV-407 giữ engine tự viết: nó đã xong, đã đo, thắng ở `LIMIT`, và cho
  thông báo lỗi tiếng Việt tốt hơn. DuckDB chỉ gánh phần JOIN/subquery/JSONL/Parquet mà
  FR-CSV-407 không cần. ADR-11 **không bị lật**, chỉ được nói rõ phạm vi.

**Điều tôi KHÔNG đo được, và nó là thứ anh phải cân:** 94 MB trên một bundle mà ADR-08 vừa kéo
binary chính xuống 3,47 MB. Đó là câu hỏi về sản phẩm (người tải bản 100 MB có bỏ đi không?), về
App Store, và về việc có chấp nhận một phụ thuộc 94 MB phải theo dõi CVE hay không — không phải
câu hỏi về hiệu năng. Ba số liệu để cân: kênh App Store tải nền nên cỡ ít đau hơn; kênh tải trực
tiếp thì người dùng nhìn thấy con số; và NFR-PORT-04 buộc mọi phụ thuộc phải universal — DuckDB
có sẵn bản universal chính thức nên vế ấy đã đạt.

> **Chặn:** FR-QRY-001/003/005/006 · FR-DQR-001/003/005 · FR-KNW-907/913 · FR-RPT-001 — **11 FR**.

### 1.2 WKWebView cho Mermaid — mâu thuẫn trực diện với quyết định của FR-FMT-506

**Sự việc.** Khi làm Markdown preview, ta **cố ý không dùng WebView**, và lý do ghi thẳng trong
`docs/trang-thai.md` §4: *"nạp WebKit kéo cả một engine trình duyệt vào tiến trình, đúng thứ
ADR-08 đang gỡ khỏi đường khởi động"*. FR-MMD-001 thì **bắt buộc** mermaid.js chạy trong
WKWebView sandboxed. Hai quyết định này không thể cùng đúng nếu không đo.

NFR-MMD-01 đã tự nêu lối thoát: *"WKWebView CHỈ khởi tạo khi mở preview lần đầu — khởi động app
và RAM nghỉ không đổi (đo trong CI so baseline)"*. Tức đặc tả đã lường trước và đặt điều kiện.

### ĐÃ ĐO — `scripts/run-poc-l.sh`, 26/08/2026 · `benchmarks/results/poc-l-arm64.json`

| Câu hỏi | Số đo | Đọc thế nào |
|---|---|---|
| **`import WebKit` (liên kết lúc nạp) tốn gì trước `main()`** | **+1,4 ms**, trên **sàn nhiễu 0,9 ms** (15 lần mỗi bên) | **Tiền đề của FR-FMT-506 SAI.** WebKit nằm trong dyld shared cache, nên "kéo cả một engine trình duyệt vào tiến trình" không tốn thời gian khởi động. Kết luận trung thực: **không quá ~2 ms** |
| **Nạp lười bằng `dlopen`** | trước `main()` **0 ms** · lần đầu dùng **0,6 ms** | vẫn rẻ hơn, và là hình dạng NFR-MMD-01 đã đặt điều kiện |
| **Mở preview lần đầu** | dựng `WKWebView` 53 ms · **tới lúc sơ đồ hiện ra 830 ms** | 830 ms ấy gần như toàn bộ là nạp và chạy 2,45 MB mermaid.js một lần |
| **Render sơ đồ 500 node** | **531 ms** / trần NFR-MMD-01 là 2000 ms | **ĐẠT.** Và đếm được 1001 node trong SVG — bằng chứng nó vẽ thật chứ không trả chuỗi rỗng |
| **RAM** | 32,9 → 42,6 (dựng) → **68,4 MB** (sau render), tức **+35 MB** | chỉ tốn **khi đã mở preview**. NFR-PERF-05 (80 MB) nói về RAM **nghỉ**, nên chỉ tiêu không bị đụng — miễn là khởi tạo lười |
| **Chặn mạng (NFR-MMD-03 · NFR-SEC-02)** | có hàng rào: **BỊ CHẶN** · bỏ hàng rào: **ĐI ĐƯỢC** | đối chứng âm **kết luận được**: hàng rào có tác dụng thật, không phải mạng hỏng |

**Sàn nhiễu ở dòng đầu không phải phụ kiện.** Bộ đo có ba binary, và binary "nạp lười" là **bản
sao y hệt** của binary mốc — cùng byte. Nên chênh lệch giữa hai cột ấy **không thể** là hiệu ứng
của WebKit; nó là nhiễu của chính phép đo. Không có nó thì "+1,4 ms" đọc như một kết luận, trong
khi nó chỉ lớn hơn sai số một chút.

**Ba lỗi của chính bộ đo, cả ba đều từng cho ra số sai trông rất hợp lý:**

1. Chờ `compileContentRuleList` bằng `DispatchSemaphore` **ngay trên main queue**, mà callback của
   WebKit cũng về main queue → tự khoá đúng 10 giây rồi hết hạn. Con số "tới lúc sơ đồ hiện ra"
   báo **11 giây**. Sai số ấy không trông giống lỗi — nó trông giống một kết luận về WebKit.
2. Đối chứng mạng dùng `fetch()` cho **"BỊ CHẶN" ở cả hai lượt** — vì trang nạp bằng
   `loadHTMLString(baseURL: nil)` có origin null nên CORS chặn sẵn, bất kể hàng rào. Một phép đo
   luôn cho cùng một chữ thì nó không đo gì. Đổi sang `<img>` (không qua CORS) mới phân biệt được.
3. Dấu nháy ngược trong khối heredoc không trích dẫn → shell **chạy** nội dung giữa hai dấu ấy.
   `run-startup-kpi.sh` đã ghi đúng bài học này từ trước; tôi vẫn giẫm lại.

**Đề nghị: LÀM Mermaid Studio, và khởi tạo WKWebView LƯỜI.** Cái giá thật của WebKit không nằm ở
khởi động (≈0) mà ở **lần mở đầu tiên (830 ms) và +35 MB RAM khi đang mở** — cả hai đều là chi
phí người dùng **chọn** trả khi bấm mở preview.

**Và PoC-L mở khoá thêm một mục không nằm trong kế hoạch ban đầu: FR-FMT-506.** Markdown preview
hiện tự nói ra giới hạn *"chưa dựng bảng, chưa tô màu khối mã"* — giới hạn ấy sinh ra từ chính
tiền đề vừa bị đo là sai. Dùng chung đường render với Mermaid Studio thì nó hết, và FR-MMD-003
(block ```` ```mermaid ```` trong Markdown) vốn đã đòi hai thứ này chạy chung một engine.

> **Chặn:** FR-MMD-001…008 · FR-KNW-905 · FR-MMD-003 ↔ FR-RPT-001 — **10 FR** (và nới được
> FR-FMT-506).

### 1.3 FR-DOC-305 hướng (B) — quyết định treo từ 25/08, vẫn treo

Không đổi so với `docs/trang-thai.md` §4bis. Hướng (A) đã dùng được. Hướng (B) — giao diện lịch
sử nguyên bản của macOS — đòi chuyển sang `NSDocument`: **413 chỗ chạm tài liệu, 29 chỗ chỉ mục
`tabs[]`, 657 dòng phiên/bản nháp/CLI** phải hoà lại (đã đo ở `scripts/run-poc-j.sh`).

**Điểm mới của phiên 26/08:** quyết định này giờ **không còn chỉ về FR-DOC-305**. NFR-USE-01 đòi
*"hành vi document-based app chuẩn macOS"*, và ta đang cố ý đi lệch. Chốt (B) thì đóng cả hai;
chốt "không làm (B)" thì phải ghi một ADR nói rõ GEditor **không** là document-based app và
NFR-USE-01 được đọc theo nghĩa hẹp — chứ không để nó lơ lửng như hiện nay.

> **Chặn:** FR-DOC-305 · NFR-USE-01 — **1 FR + 1 NFR**.

### 1.4 Hai việc dọn dẹp phải làm ngay, không cần chờ ai chốt

**(a) Mã ADR đang đụng nhau.** SRS v2.2 gọi **ADR-11 = Knowledge Pack**, **ADR-12 = Agent Pack**,
**ADR-13 = Python Pack**. Kho mã có `ADR-11-sql-engine.md` và `ADR-12-plugin-native.md`. Hai bộ số
sẽ đâm nhau đúng lúc bắt đầu Phase 4, khi cả hai cùng được nhắc trong một câu. Sửa bây giờ là đổi
tên hai file và vài dòng tham chiếu; sửa sau là sửa trong hàng chục chỗ đã trích dẫn. **Đề nghị:**
đánh số ADR của kho theo dãy riêng không đụng dãy tài liệu (ví dụ `ADR-C11`, `ADR-C12`), và ghi
bảng ánh xạ ở `docs/adr/README.md`.

**(b) Crash reporter opt-in (NFR-REL-03).** Chỉ tiêu là *"tỷ lệ phiên không crash ≥ 99,8%"* — đo
từ máy người dùng, không đo được từ máy này. Đây là quyết định phạm vi (có gửi dữ liệu đi không,
gửi gì, ai nhận) và nó **đụng NFR-SEC-02 "zero telemetry"**. Hai chỉ tiêu này chỉ cùng đúng nếu
crash reporter là opt-in tường minh — SRS đã cho phép: *"mọi thống kê (nếu có) là opt-in rõ ràng"*.
Không chốt thì NFR-REL-03 **vĩnh viễn không đóng được**, dù bộ `--soak` có sạch đến đâu.

---

## 2. Đơn vị đo dùng trong kế hoạch này

Ước lượng bằng ngày công thì bịa. Kế hoạch này đo bằng **thứ đã làm và đã đếm được**:

> **1 đơn vị 407** = khối lượng của FR-CSV-407 (engine SQL tự viết) = **1.574 dòng mã**
> (parser + runner + panel giao diện) + **48 test lõi** + **6 bài tự kiểm** + 1 script đo KPI.

Đối chiếu: cụm 5 FR-CLN đã giao tốn 3.033 dòng lõi + ~1.500 dòng panel ≈ **2,9 đơn vị 407**, tức
~0,6 đơn vị cho mỗi FR loại "engine + panel". Các số dưới đây là **bậc độ lớn**, không phải cam kết.

---

## 3. Chín gói công việc, theo thứ tự phụ thuộc

```
        ┌──────────────────────────────────────────────┐
Gate 1  │ PoC-K: DuckDB              ├──┐              │
Gate 2  │ PoC-L: WKWebView           │  │              │
        └────────────────────────────┴──┼──────────────┘
                                        │
  WP-1 Khép Phase 2 ────────────────────┤
   (DQR-001/002, QRY-001)               │
          │                             │
          ▼                             │
  WP-2 Nền vẽ + Pivot  ◄────────────────┤     WP-6 Mermaid Studio ◄─┘
   (QRY-003/004/005/006)                │      (MMD-001…008)
          │                             │            │
          ├──────────────┬──────────────┤            │
          ▼              ▼              ▼            │
  WP-3 Data Mining   WP-4 Report    WP-5 DQR còn lại │
   (MIN-001…008)      (RPT-001…006)  (DQR-003…006)   │
          └──────────────┴──────────────┴────────────┘
                         │
                         ▼
              WP-7 Knowledge Pack (KNW-901…926)
                         │
                         ▼
              WP-8 Agent Pack  ──►  WP-9 Python Pack

  WP-0 Nợ NFR — chạy song song suốt, không phụ thuộc gói nào
```

### WP-0 — Nợ NFR và nợ kỹ thuật (chạy song song, không chặn ai) · ~4 đơn vị

Đây là gói **nên bắt đầu ngay hôm nay**, vì không mục nào chờ quyết định nào.

| | Việc | Vì sao ưu tiên |
|---|---|---|
| 1 | **Kênh cập nhật Sparkle 2 ký EdDSA** (NFR-SEC-01) | `grep Sparkle` → 0 file. Đây là **việc viết mã**, không phải chờ tài khoản Developer ID như trang trạng thái đang ngụ ý. Không có nó thì bản đã phát hành không vá được |
| 2 | **Ký + hash SHA-256 cho plugin** (NFR-SEC-03) | plugin native đã chạy được **mã của người khác** trên máy người dùng từ 25/08. Vế "cài từ đâu / gỡ thế nào" xong; vế "khớp hash, ngoài danh mục phải xác nhận rủi ro" chưa có dòng nào. Khoảng hở này lớn dần theo số người cài plugin |
| 3 | **Đo độ phủ tầng app** | 94,07% chỉ nói về `GEditorCore`. 24.074 dòng `GEditorApp` hiện **chưa ai biết được kiểm tới đâu**. Chạy `--self-test` dưới bộ đếm độ phủ |
| 4 | **Công tắc ligature + bài đo render tiếng Việt** (NFR-USE-05) | sản phẩm bán cho người gõ tiếng Việt mà "render đúng ký tự tổ hợp ở mọi mức zoom" chưa có bài đo nào |
| 5 | **Cổng tĩnh cho NFR-SEC-05 và NFR-CLN-02** | cả hai hiện đúng trên thực tế nhưng là *quan sát*, không phải *bất biến*. Thêm vào `check-core-no-ui.sh` theo khuôn cổng đã có |
| 6 | **Kiểm HIG** (NFR-USE-01): full-screen, Stage Manager, split view hệ thống | cửa sổ chính đã `.resizable` nên nhiều thứ chạy theo mặc định AppKit — nhưng chưa ai kiểm |
| 7 | **475 chuỗi chưa dịch** (FR-UI-804) | 281 chuỗi trần + 194 chuỗi nội suy. Cổng hai chiều đã có nên con số không tăng lén; nhưng nó cũng không tự giảm |
| 8 | **Mở rộng bộ soak sang mã mới** | 57 loại thao tác hiện có; mã của phiên 25/08 mới chỉ 3 thao tác chạm tới. Mỗi vùng mới là một đợt săn mới — bốn đợt đầu cho 9 lỗi sập + 2 chỗ rò |

### WP-1 — Khép Phase 2 (3 FR còn nợ) · ~4 đơn vị

Đây là **món nợ đúng nghĩa**: ba mã P1 gắn Phase 2 mà Phase 2 đã được coi là gần xong.

| FR | Phụ thuộc | Ghi chú thi công |
|---|---|---|
| ✅ **FR-DQR-001** (engine xong 26/08, panel chưa) | rule theo cột: **không chặn**. Rule `expr` và `foreign_key`: **chặn bởi Gate 1** | Chia đôi mà làm: 8 loại rule theo cột (`not_null`, `unique`, `dtype`, `range`, `length`, `regex`, `in_set`, `date_format`) + `compare` liên cột chạy thẳng trên `CSVCleanScanner` — **một lượt quét cho mọi rule cùng cột**, đúng NFR-DQR-01. Hai loại còn lại (`expr`, `foreign_key`) chờ Gate 1. Schema YAML có `version` và **từ chối file của bản mới hơn**, y như `CSVRecipe` đã làm |
| **FR-DQR-002** Điểm 6 chiều | chiều ACCURACY-PROXY dùng **MAD của FR-MIN-001** | Vòng phụ thuộc này gỡ được rẻ: tách `MADOutlier` thành một kiểu độc lập trong lõi (~50 dòng, thuần số học) và **cả DQR-002 lẫn MIN-001 cùng gọi**. Không có bản hiện thực thứ hai — đúng bài học của `MacroRunner` |
| **FR-QRY-001** Query Workbench | CSV/TSV: **không chặn**. JSONL/Parquet + JOIN: **chặn bởi Gate 1** | Đã có sẵn `CSVQueryRunner` + `SQLPanel` + `CSVQueryRunner.validate` (báo lỗi cú pháp tức thì trên dòng tiêu đề). Việc mới là: lịch sử truy vấn **theo workspace**, saved query đặt tên, tham số `:param` có ô nhập khi chạy, và kết quả **bảng ảo hoá** — dùng lại `CSVRowIndex` chứ không dựng chỉ mục thứ hai |

**Tiêu chí đóng gói:** `TC-DQR-01/02`, `TC-QRY-01` của STP v2.3 xanh; `scripts/run-quality-kpi.sh`
đo **1 triệu dòng × 50 rule ≤ 15 s** (NFR-DQR-01) và chứng minh **hủy ≤ 200 ms**.

### WP-2 — Nền truy vấn & vẽ (4 FR) · ~5 đơn vị · **chặn bởi Gate 1**

Gói này tồn tại vì **ChartRenderer là xương sống dùng chung**: FR-MIN-002/004/005, FR-RPT-001/002/003,
FR-DQR-002/004 đều vẽ bằng nó. Viết một lần, viết sớm.

- **FR-QRY-004 Quick Charts** — bar, line, histogram, scatter, box-plot. Vẽ bằng **Core Graphics,
  không WebView** (giữ nguyên lập luận của FR-FMT-506; Mermaid ở WP-6 là ngoại lệ có PoC riêng).
  NFR-QRY-02: 1 triệu điểm ≤ 2 s nhờ **downsample LTTB, và ghi rõ mức lấy mẫu lên biểu đồ** —
  vẽ 1 triệu điểm thành 800 pixel mà không nói ra là nói dối bằng hình.
- **FR-QRY-003 Pivot** — kéo-thả cột vào Hàng/Giá trị; **câu SQL sinh ra luôn hiển thị và sửa
  tiếp được** trong Workbench. Đây là khuôn "vừa dùng vừa học" mà FR-KNW-913 sẽ dùng lại.
- **FR-QRY-005 Join đa file** — bảng ảo theo workspace, schema suy luận, **catalog tự vô hiệu khi
  file đổi** (dùng `DirectoryWatcher`/FSEvents đã có).
- **FR-QRY-006 Saved query batch & CLI** — `geditor --query bao_cao.sql --out ket_qua.csv`. Đi
  theo đúng khuôn `--recipe` đã có: **mặc định không ghi đè**, có `--dry-run`.

### WP-3 — Data Mining (8 FR) · ~9 đơn vị · phụ thuộc WP-2 (vẽ)

Gói **tự chứa nhất** trong toàn bộ phần còn lại: NFR-MIN-04 cấm mọi phụ thuộc ML, nên tất cả là
thuật toán cổ điển tự cài trong `GEditorCore` — không chờ quyết định nào ngoài ChartRenderer.

Thứ tự thi công theo phụ thuộc nội bộ:
`MIN-001` (z/IQR/MAD/Mahalanobis) → `MIN-008` (leave-one-out, phân rã chính D² của 001) →
`MIN-005` (Pearson/Spearman) → `MIN-002` (k-means++/DBSCAN) → `MIN-004` (Holt-Winters) →
`MIN-003` (Apriori) → `MIN-007` (group-by, chạy 001/004/005 cho từng nhóm) → `MIN-006` (text mining, Phase 4).

Ba ràng buộc phải cài từ dòng mã đầu tiên, không phải bổ sung sau:

1. **NFR-MIN-02 tất định bit-by-bit** — seed cố định **ghi kèm trong mọi kết quả**. Đây là điều
   kiện để test golden tồn tại. Bài học `CSVProfile` đã có sẵn: dùng **băm FNV-1a**, không dùng
   `Hasher` gieo hạt ngẫu nhiên.
2. **NFR-MIN-03 chỉ-đọc tuyệt đối** — Mark chỉ là trạng thái hiển thị, không chạm buffer; mọi kết
   quả ra tab MỚI. Kiểm bằng **checksum file nguồn trước/sau**, không kiểm bằng đọc mã.
3. **NFR-MIN-04 khối "Phương pháp"** — mọi đầu ra kèm thuật toán, tham số, seed, công thức chỉ số.
   Đây là thứ `CSVProfile` đã làm và nên sao y.

### WP-4 — Visualization Report (6 FR) · ~5 đơn vị · phụ thuộc WP-1, WP-2

`.greport.md` là **Markdown mở rộng** với block ```` ```query ```` và ```` ```chart ````, soạn
trái / preview phải. Ba điểm đáng lưu ý:

- **FR-RPT-005 đóng luôn khoảng trống FR-DOC-313** (In ấn) mà RTM F-12 đã ghi. In hiện tại đi qua
  một `NSTextView` dựng riêng có trần 20 MB; đường xuất PDF của báo cáo phải dùng lại cơ chế ấy.
- **NFR-RPT-01 cache theo `hash(query + trạng thái nguồn)`** — chỉ block có nguồn đổi mới chạy
  lại. Cùng khuôn nhớ tạm "buffer + revision" mà `JSONIndex` đang dùng.
- **FR-RPT-003 chỉ báo "dữ liệu cũ"** khi nguồn đã đổi sau lần render. Không có nó thì dashboard
  hiện số cũ mà trông y như số mới — đúng loại sai im lặng mà dự án này đã một lần trả giá
  (`TextWindow` trên byte UTF-8 hỏng).

### WP-5 — DQR còn lại (4 FR) · ~3 đơn vị · phụ thuộc WP-1, WP-4

`DQR-003` (block ```` ```quality ````) cần khung block của WP-4; `DQR-004` (drift) ghi
`.gquality.history.jsonl` **cạnh rules, không bao giờ ghi vào file dữ liệu** (NFR-DQR-02);
`DQR-005` là quality gate CLI **exit 0/1/2** — thứ pipeline CI của khách tiêu thụ, nên schema JSON
đầu ra phải đặc tả trước rồi mới viết; `DQR-006` nối mỗi rule FAIL vào đúng công cụ trong Bàn làm
sạch (`null` → FR-CLN-002, `date_format` → FR-CLN-001, …) rồi **tự chạy lại rule và cập nhật điểm**.

### WP-6 — Mermaid Studio (8 FR) · ~6 đơn vị · **chặn bởi Gate 2** · độc lập với WP-2…5

Chạy song song được với nhánh dữ liệu. Nguyên tắc bất di bất dịch của cụm này —
**VĂN BẢN LÀ NGUỒN SỰ THẬT, sơ đồ chỉ là projection** — trùng khít với bất biến "buffer là nguồn
sự thật" mà SAD đã đặt và `applyEdits` đã thực thi, nên FR-MMD-004 (soạn trực quan) là **biên dịch
thao tác hình thành chỉnh sửa văn bản**, mỗi thao tác một bước undo, giữ nguyên comment và thụt lề.

`MMD-001` (render) → `MMD-002` (bản đồ element-id ↔ text-range, đồng bộ hai chiều) → `MMD-006`
(grammar + format, dùng hạ tầng FR-FMT-502 đã có) → `MMD-005` (template/snippet/autocomplete, dùng
`CompletionEngine` đã có) → `MMD-007` (export) → `MMD-003` (nhúng vào Markdown + report) →
`MMD-004`, `MMD-008` (Phase 4).

### WP-7 — Knowledge Pack (26 FR) · ~18 đơn vị · phụ thuộc WP-2, WP-3, WP-6

Gói lớn nhất, và là **plugin** — ràng buộc cứng của Phụ lục D: không embedding, không vector DB,
không gọi LLM, và **không sửa bất kỳ yêu cầu Phase 1–3 nào**. NFR-KNW-01 đòi *zero-cost khi Pack
tắt* — tức không nạp dylib lúc khởi động, đúng cơ chế `dlopen` mà ADR-08 đã dựng sẵn.

Bốn nhánh, làm được song song sau khi nhánh (1) xong:

1. **Nền JSONL** — 901, 902, 903, 922. Dựng trên Large File Mode + `CSVRowIndex`. NFR-KNW-02:
   index 1 GB ≤ 10 s.
2. **Đồ thị** — 904, 905, 906, 913, 914, 915, 916, 917, 924. `905` dùng **chung engine render với
   WP-6**; `913` dịch openCypher → SQL nên **chặn bởi Gate 1**; `914` (PageRank/Louvain trên CSR)
   dùng chuẩn thuật toán của WP-3.
3. **RAG Lab** — 918 (BM25 inverted index), 919 (recall/MRR/nDCG), 920, 921, 925, 926.
   NFR-KNW-04 đòi *đúng ≤ 1e-9* so bản tham chiếu — nghĩa là phải có bộ đối chứng độc lập trong CI.
4. **Đóng gói** — 907, 908, 909, 910, 911, 912.

### WP-8 — Agent Pack (10 FR) · ~8 đơn vị · Phase 5

Plugin RIÊNG, tách khỏi Knowledge Pack. Ba lớp phanh **bắt buộc** theo Phụ lục E: cổng diff duyệt
(1005), checkpoint phiên (1006), quyền tối thiểu (1007). NFR-AGT-01 (*key không rò khỏi Keychain*)
là **điều kiện chặn phát hành Pack** theo RTM F-09 — bài kiểm phải viết trước tính năng.
NFR-AGT-03: egress duy nhất là provider người dùng chọn, **không proxy qua máy chủ MOBILUCK**.

### WP-9 — Python Pack (9 FR) · ~7 đơn vị · Phase 6

Bất biến vĩnh viễn của ADR-13: **không một dòng CPython nào nạp vào tiến trình editor**. Hình dạng
kiến trúc này ta **đã dựng và đã đo rồi** — `geditor-plugin-host` (ADR-12, PoC-H: 0,010 ms) là
đúng khuôn tiến trình riêng + khung thông điệp có tiền tố độ dài. Python Pack nên dùng lại khuôn
ấy thay vì phát minh lần hai. NFR-PY-03 đòi **trung thực**: không được tuyên bố là sandbox.

---

## 4. Bảng 79 FR còn lại, gắn gói và ràng buộc

| Gói | FR | Số | Phase | Chặn bởi |
|---|---|---|---|---|
| WP-1 | DQR-001, DQR-002, QRY-001 | 3 | 2 · 2–3 | Gate 1 (một phần) |
| WP-2 | QRY-003, QRY-004, QRY-005, QRY-006 | 4 | 3 | Gate 1 |
| WP-3 | MIN-001…008 | 8 | 3 · 006 ở 4 | WP-2 (vẽ) |
| WP-4 | RPT-001…006 | 6 | 3 · 006 ở 4 | WP-1, WP-2 |
| WP-5 | DQR-003…006 | 4 | 3 | WP-1, WP-4 |
| WP-6 | MMD-001…008 | 8 | 3 · 004/008 ở 4 | Gate 2 |
| WP-7 | KNW-901…926 | 26 | 3–4 | WP-2, WP-3, WP-6 · Gate 1 |
| WP-8 | AGT-1001…1010 | 10 | 5 | WP-7 |
| WP-9 | PY-1101…1109 | 9 | 6 | — |
| — | CLN-004 fuzzy dedup | 1 | 4 | — (gắn vào WP-3, cùng họ thuật toán) |

**Tổng ước lượng: ~65 đơn vị 407 ≈ 100.000 dòng mã.** Kho hiện có 50k dòng Swift. Nói thẳng:
**hoàn thiện trọn SRS v2.2 là viết gấp đôi số mã đã viết trong 173 commit vừa qua.** Con số này
không phải để làm nản — nó là để cái mốc "22/08/2026 lên App Store" (`geditor-muc-tieu-app-store`)
được đặt đúng chỗ: **mốc ấy thuộc về Phase 1–2, và Phase 1–2 đã sẵn sàng.**

---

## 5. Đề nghị thứ tự, và một đề nghị về phạm vi

**Ba mươi ngày tới, nếu tôi được chọn:**

1. **WP-0 mục 1–3** (Sparkle · hash plugin · độ phủ tầng app) — không chờ ai, và mục 1–2 là hai
   khoảng hở an ninh đang mở trên một sản phẩm sắp phát hành.
2. ~~PoC-K và PoC-L~~ — **đã chạy 26/08/2026.** Còn lại là **anh chốt**: DuckDB có đáng 94 MB
   bundle không, và Mermaid Studio có làm không. Cả hai giờ là câu hỏi sản phẩm, không phải câu
   hỏi kỹ thuật — mọi rào chắn kỹ thuật đã đo và đều qua.
3. **WP-1** — khép Phase 2 cho đúng nghĩa, phần không bị Gate 1 chặn làm được ngay.
4. **Chốt 1.3 và 1.4(b)** — hai quyết định của anh, không phải việc code.
5. **Một việc PoC-K đẻ ra:** chạy `build-universal.sh` **có** `GEDITOR_SIGN_IDENTITY` một lần và
   mở một file C++ (để `libTreeSitterHeavy.dylib` phải `dlopen`). Hardened runtime + library
   validation chưa bao giờ được kiểm trên dylib ta ĐANG giao; PoC-K phát hiện ra điều đó khi đi
   tìm chuyện khác.

**Và một đề nghị về phạm vi mà tôi nghĩ đáng cân nhắc.** GEditor hôm nay là một trình soạn thảo
văn bản hoàn chỉnh, đã khép Phase 1–2, có 1208 test và 94,07% độ phủ lõi. Bốn cụm WP-6…WP-9
(53 FR, ~39 đơn vị) là **bốn sản phẩm khác** dùng chung một cái vỏ: trình soạn sơ đồ, workbench
tri thức, LLM agent, runtime Python. Chúng đều **P2 và đều nằm ở Phase 4–6** trong chính SRS.

Câu hỏi không phải "có làm không" mà là **"phát hành v1.0 trước hay sau chúng"**. Phát hành sau
Phase 2–3 (WP-0…WP-5, ~30 đơn vị) cho ra một sản phẩm đứng vững một mình, có người dùng thật, và
có phản hồi thật để định hình bốn cụm kia. Phát hành sau tất cả thì bốn cụm ấy được thiết kế
trong im lặng.

Không làm bốn cụm kia **cũng là một quyết định hợp lệ** — như hướng (B) của FR-DOC-305. Nhưng nó
phải là quyết định được nói ra, chứ không phải một mục cứ lùi mãi trong bảng.
