# ADR-11 — Engine SQL cho FR-CSV-407: tập con tự viết, không DuckDB

> ## ⚠️ ĐÃ BỊ THAY THẾ — 26/08/2026, bởi [ADR-14](ADR-14-duckdb-va-nap-luoi.md)
>
> Anh chốt nhúng DuckDB và **bỏ hẳn engine tự viết**; ba tệp mã và 48 bài kiểm nói ở dưới đã bị
> xoá. Giữ tài liệu này lại vì hai lý do: nó là hồ sơ của một quyết định ĐÚNG tại thời điểm ra
> quyết định, và PoC-G — phép đo dẫn tới nó — vẫn là số đo thật về sàn quét CSV.
>
> Điều lật nó không phải hiệu năng mà là **phạm vi**: SRS v2.2 cần `JOIN`, subquery, `DISTINCT`,
> `HAVING`, `IN`, `LIKE`, `BETWEEN` cho FR-QRY/FR-DQR/FR-KNW, và PoC-K đo engine tự viết từ
> chối cả bảy. Chi tiết ở ADR-14 §2–3.

**Trạng thái:** Anh chốt **tập con tự viết** ngày 24/08/2026, sau PoC-G · **Ngày đo:** 24/08/2026
**Chạy lại:** `scripts/run-poc-g.sh` → `benchmarks/results/poc-g-arm64.json`
**Lật:** lựa chọn DuckDB trong SAD cho FR-CSV-407. Phần còn lại của SAD không đổi.

---

## 1. Vì sao có ADR này

SAD chốt DuckDB làm engine cho FR-CSV-407 (truy vấn SQL trên CSV), đóng gói kiểu *"optional
component tải khi bật tính năng SQL"* — thêm ~40 MB.

Quyết định ấy mất chỗ đứng qua hai lần sửa, **và cả hai lần đều không phải vì DuckDB dở**:

1. **App Store giết nửa "tải về".** Điều 2.5.2 cấm app tải mã lúc chạy rồi thực thi. Nên với
   bản App Store, DuckDB **phải nằm sẵn trong bundle** — không có đường tải sau.
2. **Lập luận dùng để gạch DuckDB hoá ra sai.** Bản rà App Store đầu viết tiếp rằng nằm trong
   bundle nghĩa là *"cộng thẳng ~40 MB vào binary, tức cộng thẳng vào NFR-PERF-01"*. Commit
   `41aee01` sửa lại: câu ấy gộp ba thứ khác nhau làm một.

   > **nằm trong bundle** ≠ **nằm trong binary chính** ≠ **nằm trên đường khởi động**

   Dự án có sẵn cơ chế tách ba thứ ấy, và ADR-08 §2.13 vừa mở rộng nó tới hết cỡ: bundle hiện
   mang **35 MB** bảng tra grammar mà khởi động nguội vẫn 465 ms, vì không ai chạm tới chúng
   cho tới khi mở một file cần tô màu. DuckDB đi đúng đường ấy được.

Nên khi commit ấy sửa một lập luận sai, nó xoá luôn lý do đã dùng để gạch mục này. **Cả lý do
chọn DuckDB lẫn lý do bỏ nó đều không còn đứng** — và đó là lúc phải đo, không phải lúc chọn
theo cảm tính.

Giá thật còn lại của DuckDB, sau khi bỏ hết những lập luận sai: **~40 MB tải về và chiếm đĩa
cho MỌI người dùng**, kể cả người không bao giờ mở panel SQL. Bundle đang 42 MB, nên nó gần như
gấp đôi. Cộng thêm một cái bẫy tuân thủ ở §4.

---

## 2. PoC-G — số đo

Điều PoC này **cố ý không đo: bộ phân tích cú pháp SQL.** Viết parser cho
`SELECT … WHERE … GROUP BY … ORDER BY` là việc đã biết cách làm và đã làm một lần trong chính
dự án này (JSONPath, FR-FMT-504). Thứ chưa ai biết — và thứ có thể giết cả phương án — là chi
phí **thực thi**: mọi câu có `GROUP BY` đều buộc quét hết bảng.

Bảng đo: **1 triệu hàng × 20 cột · 157 MB · 20 triệu ô**, đúng cỡ mà NFR-CLN-01 nói tới. Trung
vị 3 lần, có một lượt quét khởi động trước.

### 2.1 Sàn quét — mọi câu truy vấn đều trả khoản này

| Đường của `CSVEngine` | | |
|---|---|---|
| `forEachRow` — một mảng `CSVField` mỗi hàng | 638 ms | 31,4 triệu ô/giây |
| `forEachWindow` — một mảng mỗi cửa sổ 1 MB | **556 ms** | 36,0 triệu ô/giây |

`forEachRow` tiện hơn nhưng dựng một mảng mới cho MỖI hàng để dời phạm vi sang hệ toạ độ toàn
cục. Chênh 15 %, và mã sản phẩm phải đi đường `forEachWindow`.

### 2.2 Truy vấn

| | |
|---|---|
| `SELECT COUNT(*) WHERE thanh_pho = 'Đà Nẵng'` — so trên **byte** | **556 ms** |
| cùng câu ấy — dựng `String` cho mỗi ô rồi so | 585 ms |
| `SELECT thanh_pho, COUNT(*), SUM, AVG … GROUP BY thanh_pho` (5 nhóm) | **657 ms** |
| `… ORDER BY SUM(doanh_thu) DESC LIMIT 3` | **0 ms** |
| `SELECT ma_kh, SUM(doanh_thu) … GROUP BY ma_kh` (1 **triệu** nhóm) | **737 ms** |

### 2.3 Bộ nhớ — ca xấu nhất

| | |
|---|---|
| bảng băm `GROUP BY ma_kh`, khoá `String`, 1 triệu nhóm | **+48,3 MB** · 50 byte mỗi nhóm |

### 2.4 Đúng-sai

Sáu phép kiểm, tất cả đạt. Mọi kỳ vọng suy thẳng từ **công thức sinh fixture**, không suy từ
đường CSV đang đo — lấy kết quả của phép đo làm đáp án thì phép kiểm không kiểm gì cả. Gồm cả
giá trị cực đoan 999.999.999 cấy giữa bảng, và luật "dòng tiêu đề không phải một nhóm dữ liệu".

---

## 3. Điều số đo nói, gồm cả hai chỗ nó bác tôi

**(a) Phân tích CSV là sàn, mọi thứ khác là nhiễu.** `WHERE` tốn 556 ms trong khi quét không
tính gì đã tốn 556 ms. Phép so sánh gần như miễn phí. `GROUP BY` thêm 100–180 ms lên trên sàn.

Hệ quả cho về sau: khi nào cần nhanh hơn, chỗ phải tối ưu là **bộ phân tích CSV** (quét song
song, hoặc chỉ mục cột) — không phải engine truy vấn. Đây cũng đúng là đường ra mà NFR-QRY-01
đã ghi cho trường hợp xấu nhất của filter.

**(b) Giả thuyết "dựng String là khoản đắt nhất" — SAI.** Tôi viết cả đường đọc byte thô vì tin
rằng hai mươi triệu `String` sẽ giết hiệu năng. Thực đo: chênh **5,6 %**. Lý do giả thuyết sai
là một câu `WHERE` chỉ chạm MỘT cột — một triệu ô, không phải hai mươi triệu. Con số "hai mươi
triệu" chỉ đúng cho `SELECT *`, và PoC này chưa đo ca ấy. Giữ đường byte vì nó đã viết xong,
đúng, và không đắt hơn — nhưng đừng ai đọc mã ấy rồi tưởng nó là chỗ quyết định hiệu năng.

**(c) Rủi ro bộ nhớ nhỏ hơn tôi lo.** Tôi đánh dấu `GROUP BY` cardinality cao là rủi ro chính:
một `Dictionary` của Swift không tràn ra đĩa được như engine cột, nó chỉ lớn lên tới khi hết
RAM. Thực đo: một triệu nhóm tốn **48 MB**, 50 byte mỗi nhóm. Ở cỡ này không thành vấn đề. Ca
thật sự nguy hiểm là bảng **hàng tỉ hàng** với khoá dài — chưa đo, và §6 ghi nó lại.

**(d) Cỡ nhỏ cho kết luận NGƯỢC.** Cùng bài này ở 100 nghìn hàng cho "so byte nhanh gấp đôi so
String" (92,9 vs 202,3 ms). Chạy lại thì thành 56,4 vs 57,9. Phép đo ĐẦU TIÊN đang trả tiền
cache nguội hộ những phép sau, nên **thứ tự đo** quyết định kết quả chứ không phải thứ đang đo.
Đã sửa bằng lượt quét khởi động và trung vị 3 lần. Ghi lại vì đây là cái bẫy chung của mọi
benchmark trong dự án, không riêng bài này.

---

## 4. Cái bẫy tuân thủ của DuckDB — ghi lại kể cả khi đã không chọn

DuckDB có cơ chế extension (`INSTALL httpfs`, `LOAD parquet`…) **tải tệp `.duckdb_extension` từ
mạng lúc chạy rồi nạp nó**, và nó **bật MẶC ĐỊNH**. Đó chính xác là thứ điều 2.5.2 cấm — nghĩa
là chỉ cần vendor DuckDB theo cấu hình mặc định là bản App Store bị từ chối, dù ta không hề gọi
tới tính năng ấy.

Ai quay lại phương án DuckDB thì phải: liên kết TĨNH những extension thật sự cần,
`SET autoinstall_known_extensions=false` và `SET autoload_known_extensions=false`, và không để
câu lệnh `INSTALL` của người dùng đi tới engine.

---

## 5. Quyết định

**Viết một tập con SQL trên `CSVEngine`.** Không vendor DuckDB.

- **Được:** 0 MB thêm vào bản tải · không có gì để xin phép sandbox · không có phụ thuộc ngoài
  nào phải ký, phải công chứng, phải theo dõi lỗ hổng · dùng lại `CSVFilter`, `CSVSort`,
  `CSVColumns`, `CSVProfileStats` đã có và đã kiểm.
- **Mất:** không có JOIN, subquery, cửa sổ hàm, Parquet — trừ khi tự viết. Phạm vi phải nói
  thẳng ra chứ không để người dùng tự khám phá.
- **Luật đã có tiền lệ trong dự án:** cú pháp chưa làm thì **báo lỗi có tên**, không lặng lẽ
  trả rỗng. Đúng cách JSONPath đã làm với `[(...)]`, `length()`, `=~`, `&&`.

Tiền lệ củng cố lựa chọn này: FR-CLN-003 (Data Profile) từng nằm trong danh sách "cần DuckDB"
và cuối cùng làm xong bằng vài chục dòng thuật toán cổ điển.

**Chỉ tiêu đề nghị cho FR-CSV-407** — bộ tài liệu chưa có NFR nào cho mục này: một câu truy vấn
trên 1 triệu hàng × 20 cột **≤ 5 giây**, đặt ngang NFR-CLN-01 (Data Profile ≤ 10 s trên cùng cỡ
bảng) rồi siết một nửa. Số đo hôm nay là 737 ms — dư 6,7 lần.

---

## 6. Mã sản phẩm — đo cạnh PoC, vì một PoC không tái lập được là vô giá trị

`scripts/run-poc-g.sh` chạy CẢ HAI trong một lượt: kế hoạch dựng tay của PoC, và chính
`CSVQueryRunner` với đúng câu SQL ấy. Cột "hiệu" là giá phải trả để đi từ nguyên mẫu tới sản
phẩm — cây `WHERE` đã giải, bảng gộp nhiều ô, kết quả dựng thành chuỗi.

| Câu | PoC | Sản phẩm | Hiệu |
|---|---|---|---|
| `COUNT(*) WHERE thanh_pho = 'Đà Nẵng'` | 568 ms | **619 ms** | +50 |
| `thanh_pho, COUNT(*), SUM, AVG GROUP BY thanh_pho` | 683 ms | **752 ms** | +69 |
| `ma_kh, SUM(doanh_thu) GROUP BY ma_kh` (1 triệu nhóm) | 747 ms | **1454 ms** | +707 |

Phép so này trả tiền ngay: **hai lần nó bắt lỗi trong mã sản phẩm mà bộ kiểm đơn vị không thấy**,
vì cả hai đều chỉ làm chậm chứ không làm sai.

1. **Tra từ điển một lần cho mỗi HÀM GỘP thay vì cho mỗi HÀNG** (+260 ms ở câu gộp thường).
   Đưa vòng lặp vào trong một lần truy cập duy nhất: +260 → +146 ms. Trớ trêu là chính chú
   thích trong PoC-G đã ghi ra cái bẫy ấy, rồi tôi viết lại nó ở mã sản phẩm.
2. **Khoá nhóm là `[String]` kể cả khi `GROUP BY` chỉ một cột** — một lần cấp phát mảng cho mỗi
   hàng. Đổi sang một kiểu khoá không cấp phát ở ca một cột: câu gộp thường +146 → **+69 ms**,
   ca một triệu nhóm +1020 → +707 ms.

**Và một giả thuyết nữa của tôi sai.** Tôi đoán phần đắt còn lại ở ca một triệu nhóm là việc
*vật chất hoá* một triệu hàng kết quả. Đo bằng cách thêm `LIMIT 10` vào đúng câu ấy: **1636 ms
so với 1626 ms — không khác gì**. Nên phần đắt nằm trong chính phép gộp, không ở việc dựng kết
quả. Nguyên nhân thật: mỗi nhóm giữ một MẢNG bộ tích lũy (một ô cho mỗi hàm gộp), tức một triệu
lần cấp phát mảng; PoC chỉ giữ một `Double` mỗi nhóm.

**Khoản +707 ms ấy để nguyên, có chủ ý.** Câu truy vấn thật gộp thành vài nhóm, không thành một
triệu; 1,45 giây vẫn dư 3,4 lần so với trần đề nghị; và sửa nó là thêm một nhánh lưu trữ thứ hai
cho ca một-hàm-gộp — đúng loại phức tạp mà §3(a) nói là đặt sai chỗ. Ghi lại ở đây và trong
`CSVQueryRunner` để lần sau ai cần thì biết chính xác phải cắt ở đâu.

---

## 7. Điều PoC này KHÔNG trả lời

Ghi ra để không ai trích số ở §2 cho một câu hỏi mà chúng không nói tới:

- **JOIN, subquery, cửa sổ hàm.** Chưa đo. `JOIN` đổi hẳn bài toán — nó cần vật chất hoá một
  phía vào bộ nhớ, và câu trả lời rất có thể đổi. Nếu phạm vi cần `JOIN` thì phải PoC lại.
- **`SELECT *` đọc mọi ô.** Chưa đo. Đây là ca duy nhất mà con số "hai mươi triệu `String`"
  thành thật, xem §3(b).
- **File hàng Gigabyte với khoá nhóm dài.** 48 MB cho một triệu khoá ngắn không ngoại suy được
  sang một tỉ khoá dài.
- **Bộ phân tích cú pháp SQL.** Cố ý ngoài phạm vi PoC, xem §2.
