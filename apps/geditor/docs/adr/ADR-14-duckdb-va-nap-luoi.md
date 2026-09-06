# ADR-14 — Nhúng DuckDB, và bất biến "khởi động chỉ kích hoạt thứ thực sự cần"

**Trạng thái:** Anh chốt **26/08/2026**, sau PoC-K · **Ngày đo:** 26/08/2026
**Chạy lại:** `scripts/run-poc-k.sh` → `benchmarks/results/poc-k-arm64.json`
**Phạm vi:** **THAY THẾ ADR-11.** Engine SQL tự viết đã bị xoá; DuckDB là engine duy nhất.

> **Lưu ý về SỐ HIỆU ADR.** Số của kho mã và số trong SRS/SAD là hai dãy khác nhau và đang đụng
> nhau: SRS v2.2 gọi ADR-11 là Knowledge Pack, ADR-12 là Agent Pack, ADR-13 là Python Pack; kho
> mã có `ADR-11-sql-engine` và `ADR-12-plugin-native`. Số 14 chọn vì nó chưa bị dùng ở cả hai
> dãy. Việc dọn dứt điểm xem `docs/adr/README.md`.

---

## 1. Quyết định

**Nhúng DuckDB** làm engine truy vấn cho tầng phân tích dữ liệu (Phase 2–4), nạp bằng `dlopen`
khi người dùng thật sự chạy một truy vấn.

Anh chốt kèm **một điều kiện, và điều kiện ấy là phần quan trọng hơn**:

> *"Cần rõ ràng tính năng core khi khởi động chỉ kích hoạt các tính năng thực sự cần thiết thôi,
> còn các tính năng khác thì khi cần mới kích hoạt. Dung lượng app có thể tăng cũng okay. Nhưng
> khởi động phải nhanh."*

Nên ADR này có hai nửa, và nửa thứ hai mới là nửa sống lâu: **dung lượng bundle là thứ được
phép đổi; thời gian khởi động là thứ không.** Một điều kiện chỉ nằm trong tài liệu là điều kiện
sẽ bị phá bởi một dòng `import` của người chưa đọc tài liệu — nên §4 biến nó thành cổng chặn.

## 2. Vì sao — số đo, không phải phỏng đoán

ADR-11 (24/08/2026) chốt tập con SQL tự viết cho FR-CSV-407 và ghi rõ phạm vi lật: *"phần còn
lại của SAD không đổi"*. Phần còn lại ấy có **bảy chỗ** dựa vào DuckDB, và **engine tự viết từ
chối đúng những cú pháp chúng cần** — PoC-K hỏi nó bảy câu và nhận **7/7 lời từ chối có tên**:

| Cú pháp | Engine tự viết | DuckDB | Yêu cầu cần nó |
|---|---|---|---|
| `JOIN` | `Phần thừa ở cuối câu truy vấn` | 5 ms | FR-QRY-005 · FR-DQR-001 `foreign_key` |
| `DISTINCT` | `unsupported("DISTINCT")` | 4 ms | FR-QRY-003 pivot |
| `HAVING` | `unsupported("HAVING")` | 4 ms | FR-QRY-003 |
| `IN (…)` | `unsupported("IN (…)")` | 4 ms | FR-DQR-001 `in_set` |
| `LIKE` | `unsupported("LIKE")` | 2 ms | FR-DQR-001 `regex` |
| `BETWEEN` | `unsupported("BETWEEN")` | 1 ms | FR-DQR-001 `range` |
| subquery | `Bên phải > phải là chuỗi hoặc số` | 3 ms | FR-DQR-002 · FR-KNW-913 |

Và ở những câu **cả hai đều làm được**, đo trên cùng một file 157 MB trong cùng một phiên:

| | Engine tự viết | DuckDB (đọc CSV) | DuckDB (bảng đã nạp) |
|---|---|---|---|
| `WHERE thanh_pho = 'Đà Nẵng'` | 677 ms | 144 ms | **2 ms** |
| `GROUP BY thanh_pho` (5 nhóm) | 791 ms | 147 ms | **4 ms** |
| `GROUP BY ma_kh` (1 triệu nhóm) | 1530 ms | 155 ms | **17 ms** |
| `SELECT * LIMIT 10` | **8 ms** | 86 ms | — |

Nạp bảng một lần tốn 732 ms; sau đó cả phiên Workbench chạy ở **2–17 ms**, tức **100–400×**.
Ô duy nhất engine tự viết thắng là `LIMIT` không kèm `ORDER BY` — nó dừng sớm, DuckDB dựng
đường ống trước.

**Giá phải trả, đo trong bundle:**

- khởi động nguội khi dylib nằm trong bundle mà **không ai mở**: **−3 ms** (đối chứng cặp, cùng
  phiên) → ADR-08 không bị đụng;
- `dlopen` lúc người dùng bấm chạy truy vấn: **6,9 ms**;
- **dung lượng: 94 MB** universal đã strip (arm64 45 + x86_64 48).

Con số 94 MB đáng nói riêng: SAD ghi *"~40 MB"*. Con số ấy đúng cho **một** kiến trúc, mà
NFR-PORT-01 đòi bundle mang cả hai. Anh chấp nhận khoản này — nó là lý do ADR này tồn tại thay
vì chỉ là một dòng trong kế hoạch.

## 3. Ranh giới — sửa 26/08/2026: **MỘT engine, không phải hai**

> **Bản đầu của ADR này giữ engine tự viết cho FR-CSV-407** và để DuckDB gánh phần còn lại. Anh
> bác phương án ấy ngay trong ngày — *"bỏ hết engine tự viết chuyển sang dùng DuckDB cho đảm
> bảo"* — và anh đúng: chính bản đầu đã phải viết ra một cảnh báo rằng hai engine nghĩa là hai
> tập cú pháp, và người dùng không có cách nào đoán câu SQL của mình đang chạy trên cái nào.
> Một ADR phải cảnh báo về chính quyết định của nó là một ADR chưa chốt xong.

**`CSVQuery` + `CSVQueryParser` + `CSVQueryRunner` (1.240 dòng) và 48 bài kiểm của chúng đã bị
XOÁ.** Thay bằng `CSVQueryEngine` (DuckDB) + `DuckDB` (lớp bọc `dlopen`). Mọi đường đi qua một
engine duy nhất: panel SQL, bài tự kiểm, bộ đo.

**Thứ tự thi hành, và vì sao nó quan trọng:** dựng đường mới → cho nó qua đúng bộ kiểm của
đường cũ → **rồi mới xoá**. Xoá trước là để FR-CSV-407 hỏng trong khoảng giữa, trên một nhánh
mà mọi cổng đều xanh vì chẳng còn gì để kiểm.

### 3.1 Được gì

`JOIN` · subquery · `DISTINCT` · `HAVING` · `IN` · `LIKE` · `BETWEEN` — bảy thứ PoC-K đo là
engine cũ từ chối 7/7, nay chạy hết, và mở đường cho FR-QRY-001/003/005/006, FR-DQR-001
(`expr`, `foreign_key`), FR-KNW-907/913, FR-RPT-001. Thêm **suy kiểu cột**: engine cũ đọc mọi
ô thành chuỗi nên `BETWEEN 0 AND 200` là vô nghĩa với nó — đó là lý do rule `range` của
FR-DQR-001 trước đây không khả thi. Và **`NULL` phân biệt được với chuỗi rỗng**, thứ cả cụm
FR-CLN-002 dựng trên.

### 3.2 Mất gì — sáu khoản, không giấu khoản nào

1. ~~**Thông báo lỗi tiếng Việt gọi đúng tên cú pháp chưa làm.**~~ **ĐÃ TRẢ 26/08/2026** —
   `DuckDBErrorText` dịch bốn họ lỗi mà DuckDB thật sự trả về (cột không có · bảng/hàm không có ·
   sai cú pháp · đổi kiểu không được), giữ nguyên tên cột, danh sách cột gợi ý và khối `LINE …`
   kèm dấu mũ. Mẫu lấy từ **lỗi thật của DuckDB 1.5.5**, chép lại từ một lượt chạy mười lăm câu
   sai, không phải viết từ trí nhớ. Họ lỗi lạ đi qua **nguyên văn** kèm nhãn "chưa có bản dịch"
   — đoán một câu tiếng Việt nghe xuôi cho lỗi chưa hiểu là dẫn người dùng đi sai đường, và họ
   không có cách nào biết mình bị dẫn sai (cùng luật với bộ giải thích regex FR-SRCH-110).
   Hai câu riêng cho hai thứ DuckDB gọi chung là "Parser Error": câu không phải SELECT, và câu
   có nhiều lệnh ngăn bởi `;`.
2. **`SELECT * FROM t LIMIT 10`: 8 ms → 86 ms.** Engine cũ dừng sớm; DuckDB dựng đường ống
   trước. Đây là ô duy nhất engine cũ thắng, và nó là câu người ta gõ đầu tiên khi mở một file lạ.
3. **Dòng "quét N hàng · khớp M" ở thanh tóm tắt panel.** Đó là sản phẩm phụ của một bộ quét
   tuần tự; DuckDB chạy song song và không có con số nào tương đương có nghĩa. Bịa một con số
   trông giống nó tệ hơn là bỏ, nên panel nay chỉ nói số hàng ra và thời gian.
4. **Tên cột của phép gộp đổi:** `COUNT(*)` → `count_star()`, `SUM(x)` → `sum(x)`. Người dùng
   thấy ngay. Cách tránh là đặt `AS`, và menu cú pháp của panel nên gợi ý như vậy.
5. **Truy vấn trên buffer ĐANG SỬA nay phải chép ra file tạm** (§3.3). Engine cũ chạy thẳng
   trên vùng nhớ.
6. **Tính năng truy vấn nay có thể VẮNG MẶT.** Trước đây nó luôn chạy vì không phụ thuộc gì.
   Nay thiếu `libduckdb.dylib` là mất hẳn tính năng — app vẫn mở bình thường và nói ra lý do,
   nhưng đó là một chế độ hỏng chưa từng tồn tại.

### 3.3 Dữ liệu vào DuckDB bằng đường nào — hệ quả kiến trúc lớn nhất

Engine cũ chạy **thẳng trên `TextBuffer`**, kể cả khi tài liệu sửa chưa lưu. DuckDB đọc **file**.
Nên có hai đường:

- **Đã lưu, chưa sửa** → trỏ DuckDB vào file gốc, không chép byte nào. Đường của phần lớn lượt dùng.
- **Buffer đã sửa** → phải ghi ra file tạm. Trần **256 MB**, quá thì **nói ra** kèm cách thoát
  ("lưu tài liệu rồi chạy lại"), thay vì để người dùng chờ một việc họ không biết mình đã yêu cầu.

Không có đường thứ ba: DuckDB không nhận một vùng nhớ làm nguồn CSV.

Đường nhanh **so số byte của file với buffer**, không tin cờ `isModified` của tầng trên: đoán
sai ở đây nghĩa là truy vấn chạy trên một phiên bản dữ liệu KHÁC thứ người dùng đang nhìn — sai
trong im lặng, đúng loại hỏng nguy hiểm nhất của sản phẩm này. Có bài kiểm riêng cho nó.

### 3.4 Chỉ-đọc (NFR-QRY-03) — nay cần hai lớp

Engine cũ chỉ biết `SELECT`, nên "chỉ-đọc" là hệ quả của việc nó không làm nổi gì khác. DuckDB
thì **ghi được file** bằng `COPY … TO`. Nên:

1. CSDL nằm **trong bộ nhớ**, file CSV chỉ được đọc qua `read_csv` → file nguồn an toàn theo
   cấu tạo;
2. `inspect` đi qua `duckdb_extract_statements` + `duckdb_prepare` +
   `duckdb_prepared_statement_type`: **đúng một câu**, và câu ấy **phải là SELECT**. Lớp 1 bảo
   vệ file nguồn; lớp 2 bảo vệ mọi file khác trên máy.

Có bài kiểm chạy `COPY t TO '<đường dẫn>'` và **kiểm rằng file ấy không tồn tại sau đó** — chứ
không chỉ kiểm rằng lời gọi ném lỗi.

**Bản đầu của lớp 2 là một mẹo chuỗi, và nó hỏng theo cách chỉ lộ ra khi nhìn kết quả thật.**
Nó bọc câu người dùng vào `SELECT * FROM ( … ) LIMIT 0`. Chặn thì đúng, nhưng **chuỗi bọc lọt
vào thông báo lỗi**: người gõ `SELECT khong_co FROM t` đọc được `LINE 1: SELECT * FROM (SELECT
khong_co FROM t` với dấu mũ chỉ lệch mất bảy cột. Đếm nhiều lệnh cũng không làm nổi, nên
`SELECT 1; COPY t TO '…'` vẫn lọt. Hàng rào cấu trúc thay nó: không mẹo chuỗi, lỗi trỏ đúng
chuỗi người dùng gõ, và `;` bị đếm.

## 4. Bất biến, và cách nó được canh

Điều kiện của anh viết lại thành ba câu kiểm được:

### 4.1 Vế A — dylib CỦA TA phải chưa nạp lúc khởi động

`LazyLoadAudit` hỏi **nhân** qua `_dyld_image_count` tại đúng lúc cửa sổ hiện ra, và đòi
`libduckdb` cùng `libTreeSitterHeavy` **không có mặt**.

Vì sao hỏi nhân chứ không hỏi mã của mình: cổng cũ
(`StartupProbe.grammarLibraryLoadedAtLaunch`) hỏi `GrammarLibrary.isLoaded` — một biến **do
chính mã tự khai**. Nó bắt được đúng một thư viện, và chỉ bắt được chừng nào người thêm thư
viện thứ hai nhớ khai thêm một biến. Danh sách ảnh dyld thì không ai quên khai được, vì không
có gì để khai.

### 4.2 Vế B — hệ thống con phải chưa KÍCH HOẠT

Không có danh sách nào của nhân trả lời được *"đã ai dựng `JSContext` chưa"*, nên vế này dựa
vào việc mỗi hệ thống con đóng dấu `LazyLoadAudit.activate(_:)` ở **đúng một chỗ**: hàm khởi
tạo của chính nó. Yếu hơn vế A, và tài liệu nói thẳng ra như vậy thay vì để người đọc tưởng hai
vế mạnh ngang nhau.

### 4.3 Vế C — framework hệ thống liên kết lúc nạp phải được KHAI

Cổng tĩnh trong `check-core-no-ui.sh` soi `otool -L` của binary sản phẩm và đòi mọi framework
NẶNG phải có trong `LINKED_FRAMEWORKS_ALLOWED` kèm **giá đã đo**. Chốt hai chiều như
`POLLING_ALLOWED`: đỏ khi có cái mới lẻn vào, và cũng đỏ khi khai một cái không còn liên kết.

### 4.4 Vì sao phải tách "đã NẠP" khỏi "đã KÍCH HOẠT"

Bản đầu của `LazyLoadAudit` gộp mọi thứ vào một danh sách "thư viện nặng" rồi hỏi dyld. Chạy
thử một lần là thấy sai: **WebKit, JavaScriptCore và libxml2 đã nằm sẵn trong tiến trình ngay
lúc cửa sổ hiện ra** — 1039 ảnh dyld, phần lớn do AppKit và Foundation kéo vào chứ không phải
do mã của ta. Một cổng chặn chúng sẽ đỏ vĩnh viễn vì lý do ta không sửa được, và **cổng đỏ vĩnh
viễn là cổng sẽ bị tắt**.

Đo tiếp thì rõ vì sao chúng không đáng chặn: framework hệ thống nằm trong **dyld shared cache**,
nên liên kết chúng gần như miễn phí — WebKit **+1,4 ms** trên sàn nhiễu 0,9 ms (PoC-L),
JavaScriptCore **+1,8 ms** trên sàn nhiễu 1,4 ms (đo 26/08/2026, cùng phương pháp). Cả hai đều
không phân biệt được với nhiễu.

Thứ ĐẮT không phải "có mặt" mà là **"bị dựng lên"**: `WKWebView` đầu tiên tốn **830 ms và +35 MB
RAM**; một kết nối DuckDB kéo theo 94 MB dylib. Bất biến này vì thế nói về **kích hoạt**, không
nói về hiện diện — đúng chữ anh dùng.

### 4.5 Cổng đã được xác nhận ĐỎ

Không có bước này thì §4 chỉ là một lời hứa. Chèn một lệnh `dlopen` grammar vào đường khởi động
rồi chạy lại:

- `--measure-startup` → `lazyLoadPass: false`, in ra tên thư viện kèm lý do nó phải lười, **thoát 1**;
- `--self-test` → bài *"khởi động không nạp dylib nặng nào"* **ĐỎ**.

Hoàn nguyên thì cả hai xanh lại. Bài tự kiểm còn có **đối chứng âm bên trong**: nó bắt bộ dò
nhìn một danh sách ảnh giả có chứa thư viện nặng và đòi nhận ra đủ, rồi đòi nó **không** báo bừa
trên một danh sách sạch — vì một bộ dò hỏng cũng trả về "không có gì" y hệt lúc mọi thứ đúng.

## 5. Một chú thích sai bị phơi ra khi làm việc này

`ScriptRunner` viết: *"`import JavaScriptCore` chỉ nạp khi người dùng chạy script lần đầu —
đúng cùng lối với `GrammarLibrary`"*. **Sai**, và `otool -L` chứng minh: JavaScriptCore nằm
trong danh sách liên kết **lúc nạp**. `GrammarLibrary` đi lối khác hẳn — nó `dlopen` thật.

Đo rồi thì sai ấy không tốn gì đáng kể (1,8 ms, dưới sàn nhiễu), và thứ chú thích ấy hứa —
`JSContext` dựng lười — vẫn đúng. Nhưng nó là ví dụ đúng nghĩa của thứ ADR này sinh ra để chặn:
**một câu khẳng định về đường khởi động, không ai đo, sống trong mã hàng tháng trời.** Nay câu
ấy được sửa lại theo số đo, và `JSContext` có `activate("JSContext")` gác thay vì chỉ có lời hứa.

## 6. Cái giá, và cái chưa biết

### 6.1 Đưa dylib vào kho — Git LFS

Ba đường, và hai đường đầu đều phá một thứ:

| | Đường | Phá gì |
|---|---|---|
| A | commit thẳng vào git | 94 MB **vĩnh viễn** trong mọi bản clone, cộng thêm 94 MB nữa mỗi lần nâng phiên bản. Kho đang 26 MB — một lần nâng làm nó gấp bốn |
| B | `curl` lúc dựng | phá đúng bất biến `ci.yml` tự ghi: *"vendor nằm trong kho mã, **không tải về lúc dựng** — NFR-SEC-03 chuỗi cung ứng"*, và làm bản dựng đứt mỗi khi GitHub releases đứt |
| **C** | **Git LFS** ✅ | — |

**Chốt đường C.** Artefact THUỘC kho (clone ra là có, không cần mạng lúc dựng, bất biến
NFR-SEC-03 nguyên vẹn), mà bản clone chỉ kéo phiên bản đang dùng chứ không kéo cả lịch sử. Đã
kiểm: git index giữ **con trỏ 133 byte**, không phải blob 94 MB.

**Cái giá, nói ra:** máy chưa có `git lfs` clone ra một file con trỏ 130 byte thay vì dylib.
Triệu chứng mặc định của nó là **thứ nguy hiểm nhất** — mọi bài kiểm DuckDB `XCTSkip` và bộ
kiểm xanh cho một sản phẩm không truy vấn được. Nên có hai cổng chặn đúng chỗ ấy: `ci.yml` kiểm
cỡ file trước khi dựng, và `requireHydratedDuckDB()` trong bộ kiểm **XCTFail** (không phải skip)
khi thấy file dưới 1 MB, kèm câu `git lfs install && git lfs pull`.

`scripts/vendor-duckdb.sh` nay chỉ dùng khi **nâng phiên bản**, không chạy trong CI.

### 6.2 Còn lại

**Chấp nhận:**

- **+94 MB bundle.** Anh đã chốt là được. Kênh App Store tải nền nên cỡ ít đau hơn; kênh tải
  trực tiếp thì người dùng nhìn thấy con số.
- **Một phụ thuộc phải theo dõi CVE.** DuckDB là mã của người khác chạy trên máy người dùng —
  cùng loại nghĩa vụ mà NFR-SEC-03 đặt ra cho plugin.
- **Hai tập cú pháp SQL** trong một sản phẩm (§3), phải nói rõ trên giao diện.

**Chưa biết, và không giả vờ là đã biết:**

- **Hardened runtime.** Dưới chữ ký ad-hoc, library validation chặn `libduckdb` — **và chặn y
  hệt `libTreeSitterHeavy` ta đang giao**. Đó là tính chất của ký ad-hoc (không có Team ID),
  không phải điểm trừ của DuckDB. Nhưng nó phơi ra rằng `build-universal.sh` chỉ bật
  `--options runtime` ở nhánh có `GEDITOR_SIGN_IDENTITY`, nên **bản dev chưa bao giờ chạy dưới
  hardened runtime** — việc dylib grammar nạp được trong bản ký thật vẫn là **suy luận**. Một
  lần chạy với Developer ID thật trả lời cho cả hai dylib cùng lúc.
- **Phía x86_64.** PoC-K chỉ đo arm64; x86 trên máy đo là Rosetta nên số không dùng được
  (STP §2.1).
- **Parquet và JSONL.** PoC-K đo CSV. Reader Parquet của DuckDB chưa được đo ở cỡ thật.

## 7. Nếu quyết định này sai thì lối ra là gì

DuckDB nạp bằng `dlopen` sau một cửa hẹp, nên gỡ nó ra là thay phần hiện thực phía sau cửa ấy,
không phải sửa mọi chỗ gọi — cùng khuôn `XMLSchemaValidator.libraryCandidates` mà PoC-I để lại.
Engine tự viết vẫn còn nguyên và vẫn phục vụ FR-CSV-407, nên "bỏ DuckDB" không đồng nghĩa với
"mất tính năng truy vấn" — nó đồng nghĩa với "quay về tập cú pháp hẹp hơn", và giao diện đã phải
nói rõ tập cú pháp từ §3 rồi.
