# ADR-15 — Knowledge Pack nằm TRONG lõi, nạp lười, có cổng canh

**Trạng thái:** Anh chốt **27/08/2026** · **Ngày đo:** 27/08/2026
**Phạm vi:** **THAY THẾ ADR-11 của bộ tài liệu** (SRS/SAD v2.2–v2.3: *"Knowledge Pack = MỘT
plugin bundle chạy trên hạ tầng FR-PLUG — không mã nào trong GEditorCore"*).
**Không đụng tới:** ADR-12 (Agent Pack) và ADR-13 (Python Pack) của bộ tài liệu — cả hai vẫn là
plugin riêng, và lý do của chúng khác hẳn (xem §5).

> **Lưu ý về SỐ HIỆU ADR — nay là một vấn đề THẬT.** Hai dãy số đang đụng nhau: bộ tài liệu gọi
> ADR-11 là *Knowledge Pack*, kho mã có `ADR-11-sql-engine`. ADR-14 đã cảnh báo điều này và chọn
> số 14 vì nó trống ở cả hai dãy; số 15 chọn theo cùng cách. Nhưng chính tài liệu này phải viết
> *"ADR-11 của bộ tài liệu"* năm lần để khỏi bị hiểu nhầm — đó là lúc một phiền toái thành một
> lỗi. Việc dọn vẫn chờ quyết định của người sở hữu bộ tài liệu; đề xuất ở `README.md`.

---

## 1. Quyết định

**Mã của Knowledge Pack nằm trong `GEditorCore`/`GEditorApp`, nạp lười, và bị ba cổng canh giữ
cho đúng bất biến "khởi động chỉ kích hoạt thứ thực sự cần" của ADR-14.**

Nó **không** là một plugin bundle, và **không** là một target riêng.

## 2. Vì sao — ba sự thật đã đo, không phải phỏng đoán

ADR-11 của bộ tài liệu viết ra khi hạ tầng plugin còn là một dự định. Hôm nay nó là mã chạy
được, và ba điều sau đo được trong mười phút:

| Tiền đề của ADR-11 | Sự thật hôm nay | Chỗ kiểm |
|---|---|---|
| Pack phát hành như một plugin bundle, gồm *"script + grammar + panel + XPC parser"* | `PluginPackage` cài được **script JS, theme, grammar** — **không có điểm cắm nào cho PANEL** | `PluginPackage.swift` |
| Plugin chạy được ở mọi bản phát hành | Plugin **native chỉ có ở bản tải trực tiếp**; bản App Store từ chối thẳng | `NativePluginRegistry.isSupported` |
| Pack dựa vào DuckDB cho corpus SQL và BM25 | `json` và `parquet` **liên kết tĩnh** (dùng được ngay); **`fts` KHÔNG có**, cài nó cần **mạng lúc chạy** | `duckdb_extensions()` |

Ghép hai dòng đầu: **làm đúng ADR-11 nghĩa là bản App Store không có một mã FR-KNW nào** — kể cả
năm mã P1 mà chính bộ tài liệu đã *nâng ưu tiên và kéo sớm* lên Phase 3 (901, 902, 905, 918,
919). Mục tiêu App Store chốt **22/08/2026**. Một kiến trúc đúng trên giấy mà bỏ rơi nửa số người
dùng của tính năng nó mô tả thì nó sai ở chỗ quan trọng hơn.

Dòng thứ ba đóng một cánh cửa khác: **BM25 bằng DuckDB FTS là phương án chết** — nó vi phạm cam
kết offline (NFR-MMD-02 cùng họ) và luật App Store cấm tải mã. Đặc tả vốn đã ghim *"tự viết
inverted index"*; phép đo biến điều đó từ một lựa chọn thành một ràng buộc.

## 3. Vì sao KHÔNG phải một target riêng (phương án C đã bàn)

Một target `GEditorKnowledge` giữ được ranh giới bằng chính hệ thống build, và đó là ưu điểm
thật. Nhưng nó trả bằng hai thứ:

- **Mất cộng hưởng.** 922 (Chunk Quality Report) là *"chấm theo KHUNG FR-DQR"* — nó cần
  `QualityEngine`, `QualityScore`, khối ` ```quality `. 919 đổ kết quả vào `.greport.md`. 913
  sinh SQL rồi đưa vào Query Workbench. 905 dùng lại `MermaidRenderer`. Một ranh giới target
  giữa chúng biến mỗi lần dùng lại thành một API công khai phải nuôi.
- **Ranh giới target KHÔNG phải thứ đang bảo vệ ta.** Thứ đang bảo vệ khởi động là `LazyLoadAudit`
  và cổng `check-core-no-ui.sh` — chúng soi **framework nào liên kết lúc nạp** và **thư viện nào
  đã kích hoạt**, chứ không soi mã nằm ở target nào. ADR-14 đã học đúng bài này: *"đã NẠP ≠ đã
  KÍCH HOẠT"*.

Nên: giữ **ý định** của ADR-11 (không nằm trên đường khởi động, tắt thì không tốn gì) bằng đúng
cơ chế đã chứng minh được — nạp lười cộng cổng đo — thay vì bằng một hàng rào build không đo gì.

## 4. Điều kiện đi kèm — ba cổng, và chúng là phần sống lâu của ADR này

NFR-KNW-01 đòi *"khi Pack không dùng, KPI nhóm NFR-PERF không đổi — sai lệch ≤ 1%"*. Với phương
án B, câu ấy **phải đo được**, nếu không nó chỉ là một lời hứa:

1. **`scripts/run-startup-kpi.sh`** — khởi động nguội giữ trần 500 ms (ADR-08). Thêm mã Knowledge
   Pack mà số này nhích lên là đã phá bất biến.
2. **`GEditorApp --measure-idle`** — RAM và số lần đánh thức lúc nhàn rỗi. Chỉ mục BM25, bảng
   node/edge, adjacency CSR **không được tồn tại** khi người dùng chưa mở một panel nào.
3. **`LazyLoadAudit`** (cổng ADR-14) — mọi thứ nặng chỉ được kích hoạt khi có người hỏi tới. Mã
   Knowledge Pack không được `import` gì mới ở đường khởi động, và không được dựng `static let`
   tốn kém ở mức tệp.

**Quy tắc thực hành:** mỗi mã FR-KNW đụng tới tài nguyên nặng (chỉ mục, đồ thị, WKWebView) phải
đi kèm một chỗ nói rõ *"cái này dựng lúc nào"* — cùng lối `MermaidAsset.source()` và
`DuckDB.shared`.

## 5. Vì sao Agent Pack và Python Pack KHÔNG theo quyết định này

Ranh giới của chúng khác về **bản chất**, không phải về mức độ:

- **Agent Pack** gọi ra mạng và giữ khoá API. Cô lập nó là cô lập một bề mặt tấn công và một
  cam kết pháp lý (*"dữ liệu không qua MOBILUCK"*), không phải cô lập một chi phí khởi động.
- **Python Pack** chạy mã của người dùng. Cô lập nó là cô lập một tiến trình có thể sập hoặc
  treo.

Knowledge Pack không gọi mạng, không chạy mã lạ, và không giữ bí mật nào. Cái duy nhất nó đe doạ
là **thời gian khởi động và RAM nghỉ** — và đó đúng là thứ ba cổng ở §4 đo được.

Ranh giới cứng của ADR-11 vẫn giữ nguyên: **Pack không có embedding, không vector DB, không gọi
LLM, không agent runtime.** FR-KNW-921 nói thẳng: ứng dụng *"KHÔNG tính vector — chỉ phân tích
kết quả do công cụ ngoài sinh ra"*.

## 6. Hệ quả

- **Được:** bản App Store có đủ 26 mã. Dùng lại thẳng `QualityEngine`, `ReportRenderer`,
  `MermaidRenderer`, `CSVQueryEngine` mà không phải mở API công khai nào.
- **Mất:** không còn cách cài/gỡ Pack như một gói. Nếu sau này cần "tắt Pack", nó là một công
  tắc trong `settings.json`, không phải một thao tác gỡ cài đặt.
- **Phải trả đều:** ba cổng ở §4 chạy trong CI. Ngày nào một trong ba đỏ vì Knowledge Pack, ngày
  ấy phải sửa Pack chứ không nới cổng.
- **Kèm theo:** `jsonl.*` và `graph.*` (FR-KNW-912) vẫn phát hành theo `apiVersion` như ADR-11
  đã định — đó là API cho **script của người dùng**, không liên quan gì tới chỗ mã nằm.

## 7. Ba quyết định nhỏ chốt cùng lúc

| | Chốt | Vì sao |
|---|---|---|
| Bộ đọc JSONL | **trong tiến trình**, không XPC | XPC sinh ra để cô lập mã HAY SẬP (plugin bên thứ ba). Bộ đọc JSONL là mã của ta và chỉ đọc; `CancelToken` đã chạy trên file GB ở bốn chỗ khác |
| Chỉ mục BM25 | **tự viết**, ghi cạnh corpus, vô hiệu theo mtime | `fts` không có và không tải được; NFR-KNW-04 đòi đối chứng ≤ 1e-9 — chỉ làm được khi ta sở hữu công thức |
| Vẽ DOT (FR-KNW-905) | **chuyển DOT → Mermaid**, dùng lại `MermaidRenderer` | Tránh vendor engine vẽ THỨ HAI (~3 MB và một thứ nữa phải nuôi); phép chuyển ấy dù sao cũng phải viết cho FR-KNW-910 |

Bộ tách từ tiếng Việt mà FR-KNW-918 nói *"dùng chung FR-MIN-006"* thì **chưa có** (P2, Phase 4).
918 ship với bộ tách từ đơn giản, có tài liệu, và giới hạn ấy được in trong khối "Phương pháp"
của mọi báo cáo — chứ không giấu.

## 8. PoC-M — chỉ mục BM25 tự viết có chịu nổi NFR-KNW-04 không

Chốt "tự viết chỉ mục" ở §7 chỉ có giá trị nếu bản tự viết ĐẠT chỉ tiêu. `scripts/run-poc-m.sh
1024` đo trên corpus JSONL 1 024 MB (690 181 tài liệu · 110 081 891 token · 19 000 từ khoá):

| Chỉ tiêu NFR-KNW-04 | Trần | Đo được | |
|---|---|---|---|
| Dựng chỉ mục 1 GB | 30 000 ms | **19 000 – 21 000 ms** (5 lượt) | ✅ |
| Truy vấn top-k | 500 ms | **1,0 ms** (trung vị) | ✅ |
| Điểm tất định | — | hai lượt dựng cho cùng thứ tự, hoà điểm phá theo số hiệu tài liệu tăng dần | ✅ |
| Đối chứng cài đặt độc lập | ≤ 1e-9 | **0,000e+00** trên 32 cặp (câu hỏi × tài liệu) | ✅ |

Chỉ mục nặng 187 MB, tức **18% cỡ corpus**.

Vế thứ tư là vế đáng nhất và là vế duy nhất nói về ĐÚNG chứ không về NHANH: bước 2 của script
chấm lại bằng một bản BM25 viết bằng Python thẳng từ công thức Robertson/Sparck-Jones. Ba vế đầu
một bản sai công thức vẫn qua được hết.

### Đường tới 30 giây, và bốn thứ chặn nó

Bản chạy được đầu tiên mất **29 giây cho corpus 60 MB** — trượt gấp mười bảy lần. Bốn lần sửa,
mỗi lần đều bắt đầu bằng một lần lấy mẫu chứ không bằng một phỏng đoán:

1. **O(n²) do copy-on-write.** `var payload = block[term] ?? []` … `block[term] = payload` tạo
   tham chiếu thứ hai, nên mỗi lần thêm posting là một lần chép CẢ danh sách. `subscript(_:
   default:)` đi qua `_modify` nên sửa tại chỗ. 60 MB: 29 s → dưới 2 s.
2. **Duyệt `Data` theo byte.** `data[start...].firstIndex(of: 0x0A)` đi đường generic của
   `Collection`; thay bằng `[UInt8]` + `memchr`.
3. **Bộ cắt token duyệt `Character`.** `Character.isLetter` tra bảng Unicode cho từng ký tự, và
   `String.Iterator.next()` đi vòng qua Objective-C vì chuỗi `JSONSerialization` trả về là
   `NSString` bắc cầu. Duyệt UTF-8 với bảng ASCII + dải Latin: 200 MB 23 s → 8 s.
4. **Kiểm tra độc quyền truy cập lúc chạy chiếm 27%.** Hàm lồng `flush()` bắt giữ biến cục bộ
   nên Swift chèn `swift_beginAccess` vào từng lần sửa; `AccessSet::insert` một mình đã 12,6%.
   Gỡ hàm lồng, vòng lặp có một điểm kết-thúc-token duy nhất: 200 MB 7,6 s → 4,4 s.

Thứ năm là đường tắt đọc JSON (`BM25RawJSON`): lấy dải byte của trường văn bản mà không dựng đối
tượng nào, và **trả `nil` cho mọi dòng nó không chắc** — kể cả dòng đúng ngữ pháp nhưng có ký tự
thoát — để `JSONSerialization` nhận lại việc. Bỏ cuộc thì chậm, không sai; đó là điều kiện để một
bộ đọc JSON viết tay được phép tồn tại trong sản phẩm này. Bài kiểm đối chiếu nó với bộ đọc đầy
đủ trên 22 ca hiểm.

### Hai thứ đã đo và KHÔNG dùng làm căn cứ

**Cỡ khối không phải núm chỉnh tốc độ.** Dò `--block-mb` từ 4 tới 1 024 cho ra 19–22 giây ở mọi
mức — kể cả mức gom cả corpus vào một khối và không trộn lần nào. Bước trộn k đường gần như miễn
phí. Mặc định giữ nguyên 64 MB vì không có dữ liệu nào đòi đổi.

**Con số RAM không lặp lại.** Bộ đo in `rssPeakMB` nhưng đọc `resident_size` — RSS *tại thời điểm
gọi*, không phải đỉnh. Đã sửa sang `resident_size_max`; bản đã sửa vẫn lệch tới 40% giữa hai lượt
cùng cấu hình, vì số trang còn nằm lại phụ thuộc áp lực bộ nhớ của cả máy. NFR-KNW-04 không đặt
trần RAM nên đây là ghi chú; muốn biến thành cổng thì phải đo bằng `phys_footprint` trên máy ở
trạng thái chuẩn STP §2.1.

### Chỗ tốn còn lại, cho ai tối ưu tiếp

Lần lấy mẫu cuối: **22% ở băm chuỗi của `Dictionary`** (`find` 8,9% · `Hasher.combine` 5,7% ·
`Hasher.init` 3,2% · `_finalize` 2,5% · `String.hash` 2,0%) — 110 triệu token, mỗi token một lần
băm để đếm tần suất. Gỡ nó đòi đổi khoá từ `String` sang mã từ khoá nội bộ, tức viết lại bảng
băm. Biên hiện tại (~33%) chưa đáng đổi lấy chừng ấy rủi ro.

---

## Hệ quả với FR-KNW-911 — chốt 28/08/2026

**ADR này THAY THẾ `FR-KNW-911`.** Đặc tả viết: *"Toàn bộ Knowledge Pack phát hành như MỘT gói
plugin (script + grammar + panel + XPC parser) cài/gỡ qua Plugin Manager; **không có mã nào của
Pack nằm trong GEditorCore** hay đường khởi động."*

Câu ấy mô tả đúng phương án mà ADR này đã bác bỏ — và bác bỏ bằng ba phép ĐO, không bằng ý thích:

1. `PluginPackage` **không có điểm mở rộng panel**, mà Knowledge Pack là mười mấy panel;
2. plugin native **không qua được App Store**, nên đóng gói kiểu ấy là tự cắt một kênh phát hành;
3. DuckDB `fts` **phải tải mạng**, phá bất biến "vendor nằm trong kho, không tải lúc dựng".

Anh Công xác nhận lại 28/08/2026 khi cụm KNW đi được 15/26: *"Chúng ta bỏ cái plugin rồi mà.
Tích hợp hết trong lõi chứ."*

**Vì sao ghi vào ADR chứ không chỉ để mã ấy ⛔ trong bảng.** Một mục ⛔ nằm mãi sẽ được người sau
đọc thành việc còn tồn, và có ngày ai đó đi làm nó — rồi phát hiện nó mâu thuẫn với chính ADR
này. `scripts/phase-table.py` vì thế có hạng riêng **⊘ THAY THẾ**, và mỗi mục trong hạng ấy bắt
buộc chỉ tên ADR đã thay nó. ⊘ **ra khỏi mẫu số** của tỷ lệ hoàn thành: hỏi "bao nhiêu phần trăm
việc CẦN LÀM đã xong" thì một mục đã quyết định không làm không còn là việc cần làm.

**Cái giá phải nói ra:** đổi ý về sau tốn hơn hẳn. 15 mã KNW đã viết đều nằm trong `GEditorCore`,
nên quay lại phương án plugin là chuyển cả cụm ra ngoài lõi — không phải một lần refactor nhỏ.
