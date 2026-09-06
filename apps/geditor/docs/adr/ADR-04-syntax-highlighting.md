# ADR-04 — Tô màu cú pháp (FR-FMT-501)

**Trạng thái:** ĐÃ CHỐT 21/08/2026 (Vũ Trí Công) · **Ngày đo:** 21/08/2026 · **PoC:** PoC-D
**Chạy lại:** `scripts/run-poc-d.sh` → `benchmarks/poc-d.json`

---

## 1. Cái đã chốt sẵn, và cái PoC này thật sự hỏi

SAD §3 đã chốt ở mức kiến trúc: **tree-sitter là engine chính, tmLanguage (Oniguruma) là
đường dự phòng** cho ngôn ngữ người dùng tự thêm. PoC-D **không** mở lại lựa chọn ấy.

Câu hỏi PoC-D hỏi là câu mà SAD không thể biết trước, vì nó sinh ra từ việc ghép ADR-04 với
ADR-01:

> Lớp hiển thị chỉ giữ **2 MB** quanh chỗ đang xem. tree-sitter thì phân tích **cả tài liệu**.
> Hai điều đó gặp nhau thế nào trên một file hàng Gigabyte?

---

## 2. Số đo

Máy đang dùng, bản release, tree-sitter 0.26.12 (ABI 15), grammar `json` v0.24.8 và `c` v0.24.2.

### 2.1 Phân tích cả tài liệu

| Ngôn ngữ | Cỡ | Thời gian | Tốc độ |
|---|---|---|---|
| json | 1 MB | 91 ms | 11,5 MB/s |
| json | 8 MB | 520 ms | 16,1 MB/s |
| c | 1 MB | 51 ms | 20,4 MB/s |
| c | 8 MB | 430 ms | 19,5 MB/s |

Ngoại suy tuyến tính: **100 MB ≈ 5–9 giây, 1 GB ≈ 50–90 giây.**

### 2.2 Bộ nhớ của cây — con số giết chết phương án "phân tích cả tài liệu"

Đo trong **tiến trình riêng cho từng phép** (xem §4).

| Ngôn ngữ | Cỡ | Cây | Gấp mấy lần văn bản |
|---|---|---|---|
| json | 1 MB | 29,4 MB | **29,4×** |
| json | 8 MB | 234,8 MB | **29,4×** |
| c | 1 MB | 15,6 MB | **15,6×** |
| c | 8 MB | 124,2 MB | **15,5×** |

Tỉ lệ **không đổi theo cỡ file**, nên nó ngoại suy được: một file 100 MB cần cây 1,5–3 GB.
Trần NFR-PERF-05 là **1,5× cỡ file**. Phân tích cả tài liệu vượt trần ấy ở *mọi* cỡ file, và
vượt bằng một bậc độ lớn chứ không phải sát nút.

### 2.3 Sửa một ký tự rồi phân tích lại

| Ngôn ngữ | Cỡ | p50 | p95 |
|---|---|---|---|
| json | 1 MB | 3,0 ms | 3,5 ms |
| json | 8 MB | 39,1 ms | 51,5 ms |
| c | 1 MB | 0,7 ms | 0,8 ms |
| c | 8 MB | 7,0 ms | 8,0 ms |

Tăng dần hoạt động thật, nhưng chi phí **tỉ lệ với cỡ cây**, không phải với cỡ sửa đổi. Ở cửa
sổ 2 MB, ngoại suy: json ≈ 10 ms, c ≈ 1,8 ms mỗi phím.

### 2.4 Truy vấn tô màu cho phần nhìn thấy

| Ngôn ngữ | Cỡ | Thời gian | Số capture |
|---|---|---|---|
| json | 1 / 8 MB | 0,40 / 0,39 ms | 1262 |
| c | 1 / 8 MB | 0,26 / 0,23 ms | 892 / 847 |

**Không đổi theo cỡ tài liệu** — chi phí theo màn hình, không theo file. Đây là phần rẻ.

### 2.5 Chỉ phân tích CỬA SỔ thì sai ở đâu

Cắt một lát 2 MB theo biên dòng, phân tích riêng, so từng capture với cây phân tích cả file.

| Ngôn ngữ | Chỗ cắt | Lệch | 64 KB đầu | Giữa | 64 KB cuối |
|---|---|---|---|---|---|
| json | biên dòng giữa file | 0 / 215 088 | 0 | **0** | 0 |
| c | biên dòng giữa file | 252 / 157 203 | 0 | **0** | 252 |
| c | GIỮA khối chú thích | 553 / 157 796 | 313 | **0** | 240 |

**Đây là kết quả quyết định của cả PoC.** Mọi chỗ sai nằm ở **hai mép** của lát; phần giữa
**sạch tuyệt đối**, kể cả khi cố ý cắt vào giữa một khối `/* … */`.

Phần trăm ("0,35%") là con số gây hiểu lầm và suýt làm tôi kết luận sai: nó tính trên cả
2 MB nên luôn nghe êm tai, trong khi cái người dùng thấy là **313 chỗ tô sai ngay đầu cửa sổ**
— đúng chỗ họ vừa cuộn tới. Chỉ khi đo **phân bố** mới thấy hình dạng thật của vấn đề, và
cũng chính phân bố ấy chỉ ra cách sửa.

### 2.6 Lề bao nhiêu thì đủ — đo trên nhóm có bộ quét ngoài mang trạng thái

§2.5 cắt một lát RỜI ra phân tích (lề = 0) để xem hỏng ở đâu. Phép này đo đúng cái sản phẩm
làm: phân tích **vùng + lề**, chỉ hỏi phần giữa, so với phân tích cả file. Vùng cần tô 256 KB
ở giữa một file 4 MB.

| Ngôn ngữ | lề 0 | lề 16 KB | lề 64 KB | lề 256 KB | Ghi chú |
|---|---|---|---|---|---|
| json | 0 | 0 | 0 | 0 | |
| c | 144 | **0** | 0 | 0 | chú thích khối |
| bash | 193 | **0** | 0 | 0 | **heredoc** — dấu kết thúc do người viết đặt |
| ruby | 112 | **0** | 0 | 0 | `=begin`/`=end` + heredoc |
| yaml | 2807 | 2806 | 2806 | 2806 | **lề không cứu được** — xem dưới |
| python | 46507 | 46507 | 46507 | 46507 | **chưa kết luận** — xem dưới |

**Lề 16 KB đã đủ** cho bốn ngôn ngữ đo được, kể cả hai ngôn ngữ có bộ quét ngoài mang trạng
thái. Giữ 64 KB làm bội số an toàn: chi phí thêm là 48 KB văn bản mỗi lần phân tích, không
đáng kể so với cửa sổ 2 MB.

#### Python và YAML — nguyên nhân KHÔNG phải cỡ lề

Hai ngôn ngữ này lệch ở mọi cỡ lề, kể cả 256 KB. Truy nguyên (`geditor-bench poc-d-python`)
loại từng nghi phạm bằng đo:

| Nghi phạm | Cách kiểm | Kết quả |
|---|---|---|
| Dữ liệu thử hỏng | `ast.parse` của Python, `YAML.load_file` của Ruby | **hợp lệ** |
| Truy vấn bị cắt cụt | `ts_query_cursor_did_exceed_match_limit` | **không**, ở mọi ngôn ngữ |
| Cây có lỗi | `ts_node_has_error` trên cây cả file | **không** |
| Cây suy giảm theo cỡ file | `ts_node_descendant_count` ở 1/2/4 MB | **44,2 nút/KB, không đổi** |

Và số capture của đường "cả file" tỉ lệ tuyến tính với cỡ file (18.765 → 37.528 → 74.996 ở
1/2/4 MB), tức đường ấy **tự nhất quán**. Bên sai là LÁT CẮT.

Phép đo quyết định: cắt cùng vùng ấy nhưng cho lát bắt đầu ở một dòng **cột 0**.

| | Python | YAML |
|---|---|---|
| Đúng (phân tích cả file) | 4 699 | 2 806 |
| Lát + lề 64 KB, cắt tuỳ ý | 41 808 | 0 |
| Lát + lề, **cắt ở dòng cột 0** | **4 699** | **2 806** |

Khớp tuyệt đối. Nguyên nhân vì thế đã rõ: với ngôn ngữ mà **thụt lề chính là cú pháp**, một
lát bắt đầu giữa khối thụt lề không cho bộ phân tích gốc toạ độ nào. Phần phục hồi lỗi của
Python đọc văn xuôi trong docstring thành mã — nên nhiều capture gấp chín lần; YAML thì bỏ
cuộc hẳn — nên không capture nào.

Nới lề không cứu được vì thứ thiếu **không phải một dấu mở** nằm đâu đó phía trước, mà là gốc
toạ độ thụt lề — thứ chỉ có ở cột 0.

**Đã đưa vào quyết định (§3):** biên đầu của phạm vi phân tích lùi tiếp về dòng cột 0 gần
nhất, tối đa 1 MB. Bốn ngôn ngữ còn lại (json, c, bash, ruby) không đổi một capture nào.

Nhờ đó bỏ được ngoại lệ "YAML file lớn thì không tô" của bản trước: khi chưa biết vì sao thì
không tô là cách xử lý đúng, nhưng khi đã biết thì có cách tốt hơn hẳn.

---

## 3. Quyết định

**Luôn phân tích CỬA SỔ + LỀ, không bao giờ phân tích cả tài liệu.**

- Phạm vi phân tích = cửa sổ hiển thị 2 MB **cộng 64 KB lề mỗi bên**, cắt theo biên dòng.
- Biên ĐẦU lùi tiếp về **dòng bắt đầu ở cột 0** gần nhất (tối đa 1 MB). Bắt buộc với ngôn ngữ
  mà thụt lề là cú pháp — Python, YAML — và vô hại với phần còn lại. Xem §2.6.
- Kết quả tô màu **chỉ dùng phần giữa**; hai lề bị bỏ đi. Số đo §2.5 nói lề 64 KB phủ hết
  vùng hỏng đã quan sát được.
- Không có ngưỡng theo cỡ file: file 10 KB và file 10 GB đi cùng một đường. Không có ngưỡng
  nghĩa là không có hai hành vi để giải thích, và không có cỡ file nào bất ngờ đổi hành vi.

Hệ quả về hiệu năng, suy từ §2:

| | Chi phí |
|---|---|
| Phân tích một cửa sổ 2,13 MB | ~110–190 ms → **phải chạy ngoài main thread** |
| Gõ một phím (phân tích lại tăng dần) | ~2–10 ms → chạy được, nhưng vẫn ngoài main thread |
| Truy vấn tô màu một màn hình | ~0,3 ms → chạy thẳng lúc vẽ được |
| Bộ nhớ cây | ~33–63 MB, **không đổi theo cỡ file** |

Bộ nhớ cây trở thành hằng số thay vì tỉ lệ với file — đó chính là tính chất mà cả kiến trúc
ADR-01 được dựng lên để có.

### Giới hạn nói thẳng

- Lề 64 KB là con số **đo trên hai ngôn ngữ**. Ngôn ngữ có cấu trúc mở dài hơn (heredoc lồng
  nhau, chuỗi nhiều dòng cỡ lớn) có thể cần lề rộng hơn; phải đo lại khi thêm ngôn ngữ.
- Đã đo với nhóm có bộ quét ngoài: `bash` (heredoc) và `ruby` (`=begin`) chỉ cần lề 16 KB;
  `python` và `yaml` cần thêm phép dóng cột 0 (§2.6). Ngôn ngữ nào có cấu trúc mở dài hơn nữa
  vẫn phải đo lại khi thêm vào.
- Nếu suốt 1 MB không có dòng nào ở cột 0, phép dóng bỏ cuộc và dùng biên dòng thường. Với
  ngôn ngữ thụt lề, đó là trường hợp suy giảm đã biết — chưa gặp trên dữ liệu thật.
- Cấu trúc bao trùm CẢ cửa sổ (một mảng JSON 500 MB một dòng) thì cửa sổ nào cũng nằm trong
  lòng nó và không có lề nào cứu được. Với dạng dữ liệu ấy, tô màu theo cú pháp không phải
  công cụ đúng — cần đường dự phòng theo từ vựng.

---

## 4. Ba lần suýt ghi số sai vào tài liệu này

Cả ba đều tự tôi gây ra, và cả ba đều cho ra con số **nghe hợp lý**.

### 4.1 "Cây C tốn 0,0 MB"

Đo bộ nhớ bằng hiệu `phys_footprint` giữa trước và sau, trong **cùng một tiến trình** với các
phép đo khác. Phép đo sau dùng lại vùng nhớ phép đo trước vừa trả, nên nó báo về 0,0 MB — một
con số vô lý mà vẫn suýt vào bảng. Đây đúng là cái bẫy ADR-01 §5 đã ghi lại cho PoC-A, và tôi
vẫn đi lại vào nó. Sửa: `scripts/run-poc-d.sh` chạy **mỗi phép đo bộ nhớ một tiến trình**.

### 4.2 "tree-sitter không tăng dần được: 853 ms mỗi phím"

Phép đo chèn một ký tự, báo phép sửa cho cây, rồi **xoá ký tự khỏi mảng mà không báo phép
xoá**. Từ vòng thứ hai, cây và văn bản lệch nhau, nên mỗi lần "phân tích lại tăng dần" thật ra
là phân tích lại từ đầu. Sau khi sửa: 39 ms cho 8 MB, tức nhanh hơn **hai mươi hai lần** so
với con số sai. Nếu tin con số sai, kết luận của ADR này đã ngược hẳn.

### 4.3 "Chỉ sai 0,35%, chấp nhận được"

Phần trăm tính trên cả lát 2 MB nên nó luôn nhỏ. Đo thêm **chỗ sai xa nhất** thì ra "lan tới
100% của lát" — nghe như hỏng khắp nơi, và làm tôi định bỏ hẳn phương án cửa sổ. Chỉ khi đo
**phân bố theo vị trí** mới thấy sự thật: hai mép hỏng, giữa sạch. Ba cách đo, ba kết luận
khác nhau, trên cùng một dữ liệu.

---

## 5. Việc ADR này mở khoá và việc còn chặn

Mở khoá sau khi chốt: FR-FMT-501 (tô màu), và nền cho FR-DOC-307 Function List cùng
FR-CORE-011 smart indent — cả hai đứng trên cùng cây cú pháp.

Còn **chặn** cho tới khi chốt: mã sản phẩm của tô màu. Theo SAD §8, PoC phải có số trước, và
số đã có ở đây.

Việc phải làm trước khi bật cho người dùng:

1. ✅ **Nhúng truy vấn vào mã nguồn** — `scripts/generate-highlight-queries.py` sinh
   `HighlightQueries.swift`. Không đọc file lúc chạy, không phụ thuộc bundle.
2. ✅ **Vendor đủ 20 grammar**, mỗi cái ghim theo tag. Dựng nguội 3,75 s, 25 MB mã máy,
   universal arm64+x86_64 chạy.
3. ✅ **Đo lại lề** với nhóm có bộ quét ngoài — `bash` và `ruby` cần 16 KB; `python` và `yaml`
   cần phép dóng cột 0, đã truy ra nguyên nhân và đưa vào mã (§2.6).
4. ✅ **Đường chạy nền + huỷ** — `AsyncHighlighter`. Yêu cầu mang BẢN SAO byte chụp trên
   luồng gọi (`TextBuffer` không an toàn đa luồng), hàng đợi nối tiếp, yêu cầu mới huỷ yêu
   cầu cũ. Chạy sạch dưới Thread Sanitizer.
5. ✅ **Vẽ ra màn hình** — `WindowedTextView` nhận kết quả từ `AsyncHighlighter` và đặt màu
   lên `NSTextStorage`. Bảng màu token nằm ở `Tokens.Color.syntax`; UI/UX v2.0 chưa quy định
   bảng ấy (Style Configurator là Phase 2), nên ba nguyên tắc tự đặt được ghi ngay tại chỗ để
   Style Configurator sau này kế thừa.
