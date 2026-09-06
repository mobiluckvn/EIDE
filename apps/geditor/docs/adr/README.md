# Quyết định kiến trúc (ADR)

Mỗi file ở đây ghi **một quyết định đã chốt**, kèm số đo dẫn tới nó và cái giá đã chấp nhận.
ADR không phải kế hoạch: thứ chưa chốt thì nằm ở `docs/ke-hoach-hoan-thien-v2.2.md`, không nằm
ở đây.

| ADR | Quyết định | Chốt | Đo bằng |
|---|---|---|---|
| [ADR-01](ADR-01-display-engine.md) | Engine hiển thị: **TextKit 2** + cửa sổ 2 MB trên piece table | 20/08/2026 | PoC-A |
| [ADR-02](ADR-02-piece-table.md) | Buffer văn bản: **piece table trên mmap** | — | PoC-B |
| [ADR-03](ADR-03-regex-engine.md) | Regex: **PCRE2 + JIT**, vendor từ nguồn | — | PoC-C |
| [ADR-04](ADR-04-syntax-highlighting.md) | Tô màu: **tree-sitter** trên cửa sổ + lề 64 KB | 21/08/2026 | PoC-D |
| [ADR-08](ADR-08-startup-budget.md) | Ngân sách khởi động nguội **500 ms** và cách giữ nó | 24/08/2026 | `run-startup-kpi.sh` |
| [ADR-11](ADR-11-sql-engine.md) | ~~FR-CSV-407: tập con SQL tự viết~~ — **đã bị ADR-14 thay thế 26/08** | 24/08/2026 | PoC-G |
| [ADR-12](ADR-12-plugin-native.md) | Plugin native: **tiến trình riêng**, chỉ ở bản tải trực tiếp | 24/08/2026 | PoC-H |
| [ADR-14](ADR-14-duckdb-va-nap-luoi.md) | **Nhúng DuckDB làm engine SQL DUY NHẤT** (xoá engine tự viết) + bất biến nạp lười | 26/08/2026 | PoC-K, PoC-L |
| [ADR-16](ADR-16-sparkle.md) | **Sparkle 2 vendor vào kho, liên kết lúc nạp, bộ cập nhật thì lười** — chỉ bản tải trực tiếp | 28/08/2026 | đo khởi động hai lượt, §3 |
| [ADR-15](ADR-15-knowledge-pack-trong-loi.md) | **Knowledge Pack nằm TRONG lõi, nạp lười, có cổng canh** — thay ADR-11 của bộ tài liệu | 27/08/2026 | ba phép đo ở §2 |

ADR-05, 06, 07, 09, 10 được nhắc trong SAD nhưng **chưa có file ở kho này** — chúng là quyết
định của bộ tài liệu, chưa phải quyết định đã kiểm bằng mã.

---

## Số hiệu ADR đang đụng nhau — đọc kỹ trước khi trích dẫn

Có **hai dãy số ADR** trong dự án, và chúng không khớp:

| Số | SRS/SAD gọi là | Kho mã gọi là |
|---|---|---|
| ADR-07 | DuckDB cho FR-CSV-407 | *(không có file)* |
| ADR-11 | **Knowledge Pack** (Phụ lục D) | **Engine SQL tự viết** |
| ADR-12 | **Agent Pack** (Phụ lục E) | **Plugin native** |
| ADR-13 | **Python Pack** (Phụ lục F) | *(chưa dùng)* |
| ADR-14 | *(chưa dùng)* | **DuckDB + nạp lười** |
| ADR-15 | *(chưa dùng)* | **Knowledge Pack trong lõi** |

Nên khi đọc "ADR-11" phải biết mình đang đọc tài liệu nào. Va chạm này sẽ thành lỗi thật đúng
lúc bắt đầu Phase 4, khi Knowledge Pack và engine SQL cùng được nhắc trong một câu.

> **27/08/2026 — nó vừa thành lỗi thật.** `ADR-15` phải viết cụm *"ADR-11 của bộ tài liệu"* năm
> lần chỉ để khỏi bị hiểu là engine SQL. Chưa dọn vì vẫn là quyết định của người sở hữu tài
> liệu, nhưng cái giá của việc chưa dọn nay đã nhìn thấy được, không còn là giả định.

**Cách dọn, khi anh chốt:** đổi tên hai file của kho sang tiền tố riêng (`ADR-C11`, `ADR-C12`,
`ADR-C14`…) và giữ dãy trần cho bộ tài liệu. Sửa bây giờ là đổi tên ba file và vài dòng trích
dẫn; sửa sau Phase 4 là sửa trong hàng chục chỗ. Chưa làm vì đổi tên file là quyết định của
người sở hữu tài liệu, không phải của người viết mã — và ADR-14 chọn số 14 chính vì nó chưa bị
dùng ở **cả hai** dãy, nên việc dọn không gấp.
