# ADR-17 — Số ngôn ngữ tô màu, và vế «fallback TextMate»

**Trạng thái:** ĐỀ XUẤT — chờ anh Công chốt · **Ngày:** 05/09/2026 · **Liên quan:** FR-FMT-501,
FR-FMT-502, ADR-04, ADR-08

---

## Vấn đề

SRS FR-FMT-501 (P0) viết:

> Engine tree-sitter (incremental, chính xác theo cú pháp): **tối thiểu 20 ngôn ngữ ở Phase 1 và
> 60 ngôn ngữ ở Phase 3**; **fallback grammar TextMate (`.tmLanguage`) qua Oniguruma**.

Hôm nay sản phẩm có **20 grammar tree-sitter** (đủ vế Phase 1) và **ngôn ngữ tự định nghĩa bằng
JSON** (FR-FMT-502, `grammars/*.json`). Hai vế còn lại — 60 ngôn ngữ, và fallback TextMate —
**chưa làm**, và bảng trạng thái đang tính mã này là ✅ vì vế đầu đã xong.

Đợt rà 05/09/2026 tìm ra điều đó bằng cách đối chiếu từng vế của cả 38 mã P0 với mã nguồn.

## Cái giá đã đo

| | Số đo |
|---|---|
| 20 grammar hiện có | 17 biên dịch tĩnh + 3 nặng trong `libTreeSitterHeavy.dylib` (ADR-08 phương án C) |
| Dylib grammar nặng | 18 MB (bản debug) cho **ba** ngôn ngữ: C#, C++, Ruby |
| Khởi động | 465 ms / trần 500 — đã sát trần, và ADR-08 phải làm bốn bước mới xuống được tới đó |
| UDL JSON | có sẵn, người dùng khai bằng một tệp, không cần biên dịch gì |

Con số 18 MB / 3 ngôn ngữ là chỗ đáng dừng lại: thêm **40 grammar** nữa không phải là «thêm 40
tệp», nó là hàng trăm MB mã C phải vendor, dựng cho hai kiến trúc, và giữ đồng bộ với upstream.

## Ba đường

**A. Vendor thêm 40 grammar tree-sitter.** Đúng câu chữ đặc tả. Cái giá: bundle phình theo trăm
MB, mỗi lần nâng cấp một grammar là một lượt kiểm lại, và ADR-08 phải mở lại vì đường nạp lười
hiện chỉ dựng cho ba ngôn ngữ.

**B. Làm fallback TextMate (`.tmLanguage`).** Cho phép thêm ngôn ngữ mà không biên dịch gì —
đúng tinh thần vế thứ ba của đặc tả. Cái giá: một **engine tô màu THỨ HAI** trong sản phẩm
(quy tắc regex có trạng thái, khác hẳn cây cú pháp), và Oniguruma là thư viện thứ ba phải vendor
bên cạnh PCRE2 — hoặc chấp nhận PCRE2 với những mẫu `.tmLanguage` nó không nhận, tức tô màu
đúng 90% và không ai biết 10% kia nằm đâu.

**C. Chốt UDL JSON là vế «fallback», và lên lịch mở rộng grammar theo nhu cầu thật.**
FR-FMT-502 đã làm đúng việc mà TextMate được đưa vào đặc tả để làm: *người dùng thêm được ngôn
ngữ mà không cần chúng ta dựng lại sản phẩm*. Nó yếu hơn TextMate ở chỗ chỉ tô từ khoá, chuỗi,
chú thích và số — không có trạng thái lồng nhau. Cái giá phải nói thẳng: một ngôn ngữ khai bằng
UDL **không** được tô màu theo cú pháp thật.

## Đề xuất

**C**, kèm hai điều kiện để nó không thành một lời hứa suông:

1. **Nói ra trong sách trợ giúp** rằng ngôn ngữ ngoài danh sách 20 được tô bằng UDL, và UDL tô
   theo từ khoá chứ không theo cú pháp. Người dùng phải biết mình đang nhìn cái gì.
2. **Mốc 60 ngôn ngữ chuyển thành một câu hỏi có dữ liệu**: mở rộng grammar theo tệp người dùng
   thật sự mở, không theo một con số trong đặc tả. `--doc-sweep` đã có sẵn cơ chế đếm loại tệp.

Nếu anh muốn giữ đúng câu chữ đặc tả thì đường **A** là đường duy nhất đúng — và khi ấy nó phải
vào lịch như một khối việc riêng, không phải một dòng trong bảng ✅.

## Điều KHÔNG được làm

Để mã này ở ✅ mà không chốt gì. Một mã P0 tính là xong trong khi hai trong ba vế của nó chưa
tồn tại là đúng kiểu «bảng đúng từng dòng nhưng cho ấn tượng sai» mà `docs/trang-thai.md` §5.3
đã cảnh báo — và lần này chính bảng ấy mắc phải.
