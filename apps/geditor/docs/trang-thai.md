# GEditor — Trạng thái công việc

Cập nhật 05/09/2026 · 325 commit · 169k dòng Swift (không kể vendor) · 35k dòng test ·
**2669 test + 375 bài tự kiểm giao diện, 0 lỗi · độ phủ lõi 93,26% · độ phủ tầng app 75,82%** (mốc app 75,0)

> Các con số trên **đo lại ngày 05/09/2026**, không chép từ phiên trước — trừ độ phủ LÕI, là số
> đo 28/08 và chưa chạy lại. Trước lần đo này dòng đầu còn ghi 28/08 · 202 commit · 2255 test ·
> 258 tự kiểm, tức trang đã trôi mất 123 commit và 503 bài kiểm trong tám ngày. Trang này trôi
> **mỗi lần** không ai đo lại; xem §5bis-c cho lần trước.
>
> Đo cùng ngày: `--doc-sweep data/vanban` **63/63 tệp thật sạch** (10 cặp `.docx`/PDF lệch số
> trang trung bình 4,7%) · nợ bản dịch đúng mốc **362** · cổng ADR-14 chạy thật lần đầu (xem
> ngay dưới).
>
> **Một cổng đã im lặng bỏ qua chính nó.** `check-core-no-ui.sh` có nhánh soi framework nặng
> liên kết lúc nạp (ADR-14), nhưng nó cần một bản dựng `release` — mà không ai dựng bản ấy
> thường xuyên, nên suốt thời gian qua nó chỉ in một dòng ⚠️ rồi đi tiếp. Đã dựng và chạy: 6
> framework, tất cả đều đã khai. **Một cổng chỉ "xanh" khi nó chạy được; một dòng cảnh báo giữa
> mười dấu ✅ thì không ai đọc.**

> **ĐỔI MẪU SỐ, 26/08/2026.** Tài liệu này trước nay đếm theo **bộ v1 — 82 FR**, và theo mẫu số
> ấy thì 81 xong · 1 một phần. Nhưng bản thiết kế đang có hiệu lực là **SRS v2.2 / RTM v2.3, có
> 167 FR và 61 NFR**. Cùng một khối lượng đã làm, hai mẫu số cho hai bức tranh:
>
> | Mẫu số | ✅ | ◐ | ⛔ | Tỷ lệ |
> |---|---|---|---|---|
> | Bộ v1 — 82 FR (cách đếm cũ của trang này) | 81 | 1 | 0 | 98,8% |
> | **SRS v2.2 — 167 FR (bản đang có hiệu lực)** | 87 | 1 | **79** | **52,7%** |
>
> *(Hai hàng trên là ảnh chụp ngày 26/08/2026, giữ nguyên làm mốc so sánh. Con số ĐANG ĐÚNG là
> **132 · 1 · 34 = 79,0%** — §5.)*
>
> Cách đếm cũ không sai, nhưng nó **im lặng về 85 mã yêu cầu** mà v2.0–v2.3 thêm vào (KNW, AGT,
> CLN, QRY, RPT, MIN, PY, MMD, DQR). Đọc lướt bảng cũ sẽ hiểu thành "sản phẩm gần xong" trong
> khi theo đặc tả đang ký thì mới đi được hơn nửa đường. Bảng đối chiếu đủ 167 FR ở **§5**;
> kế hoạch khép phần còn lại ở **`docs/ke-hoach-hoan-thien-v2.2.md`**.
>
> **Phase 1 (51 FR) — mở lại rồi KHÉP LẠI trong ngày 28/08/2026**: soát ra `FR-FMT-503` thiếu
> vế "fold theo cấp", và vế ấy đã được viết ngay trong phiên (§5bis-c). **Phase 2 KHÉP 26/08/2026** — ba mã cuối (FR-DQR-001, FR-DQR-002,
> FR-QRY-001) xong cả engine lẫn panel trong ngày: **118 bài kiểm lõi + 4 bài tự kiểm mới**.
> Không mã nào còn ở ◐ vì thiếu giao diện.
>
> **27/08/2026 — cụm FR-DQR khép trọn 6/6** (003 khối ```quality · 004 trôi dạt · 005 cổng CLI ·
> 006 vòng khép kín với Bàn làm sạch), khối ` ```mining ` khép nốt FR-MIN-007, và **FR-MMD bắt
> đầu** và đi được **6/8** — khép trọn phần Phase 3: vendor mermaid vào kho, Mermaid Studio
> đồng bộ hai chiều, sơ đồ trong báo cáo, thư viện mẫu, grammar, formatter và xuất ảnh.
> Xem §5bis-b.

Ký hiệu: **✅** xong · **◐** một phần · **⊘** THAY THẾ bởi một ADR (cố ý không làm) · **⛔** chưa làm · **🔒** bị chặn bởi quyết định chưa chốt

---

## 1. Ba PoC bắt buộc (SAD §8) — cửa vào của mọi mã sản phẩm

| PoC | ADR | Trạng thái |
|---|---|---|
| PoC-B — piece table + mmap | ADR-02 | ✅ **Đã chốt** |
| PoC-C — PCRE2 JIT hai kiến trúc | ADR-03 | ✅ **Đã chốt** |
| PoC-A — engine hiển thị | ADR-01 | ✅ **Đã chốt 20/08/2026** — TextKit 2 + cửa sổ 2 MB trên piece table |
| PoC-D — tô màu cú pháp | ADR-04 | ✅ **Đã chốt 21/08/2026** — tree-sitter trên cửa sổ + lề 64 KB |
| — | **Lên Mac App Store** | ⏳ **ĐANG LÀM** — `docs/appstore-ra-soat.md`. ✅ Hai kênh phát hành (App Store sandbox không CLI · trang web có CLI) — một binary, một đường mã, app tự nhận ra kênh lúc chạy. ✅ App Sandbox bật, 131/131 tự kiểm bên trong bundle đã ký. ✅ `LSApplicationCategoryType` + `CFBundleDocumentTypes` + nhánh đóng `.pkg`. ✅ **Security-scoped bookmark** cho cả TAB lẫn THƯ MỤC workspace: ưu tiên bookmark trước đường dẫn, đếm lượt mở/thả, giữ nguyên đường dẫn người dùng đã thấy. ⛔ Còn: kiểm TAY một lần trong bản đã ký (§5), DuckDB/plugin phải đổi kế hoạch |
| — | **ADR-08 ngân sách khởi động** | ✅ **ĐẠT 24/08/2026 — 465 ms / trần 500** (min 445; RAM 18,0 MB / trần 80). Bốn bước: tách ba grammar nặng (794 → 690 ms), dựng lười giao diện (690 → 574), bỏ bảng ký hiệu khỏi bản giao (→ ~520, §2.12), và chuyển **cả hai mươi** bảng tra grammar sang dylib lười (→ **465**, §2.13 — binary chính 11,20 → **3,47 MB**). Lưu ý khi đọc lại: cùng một bản dựng không đổi cho 507/524/547 ms ở ba phiên đo khác nhau, nên chênh ±40 ms là nhiễu máy chứ không phải hồi quy. §2.12 cũng đo được rằng "nguội" đang đo **lần mở đầu tiên của một file nhân chưa từng thấy**; mọi lần mở sau đó tốn **219 ms** |

Cả ba PoC đã chốt. Còn lại **một lần gõ thật với EVKey** trước phát hành (NFR-USE-02).

Chốt ADR-01 mở khóa: tab, chia đôi màn hình, word wrap, hiện ký tự ẩn, bảng CSV, tô nền dòng
đánh dấu — và multi-caret / column mode / Column Editor, ba thứ **phải tự viết** vì `NSTextView`
không có. Chi tiết trong `docs/adr/ADR-01-display-engine.md` §8.

---

## 2. Phase 1 — bắt buộc cho bản phát hành đầu

### 2.1 Lõi soạn thảo (FR-CORE)

| | Yêu cầu | |
|---|---|---|
| ✅ | 004 Undo/Redo không giới hạn | lõi giữ lịch sử; một thao tác hàng loạt = MỘT bước |
| ✅ | 005 Sắp xếp dòng | từ điển / số / tự nhiên, có menu |
| ✅ | 006 Khử trùng lặp dòng | toàn tài liệu và liên tiếp |
| ✅ | 009 Chuyển đổi TAB ↔ Space | hai chiều theo tab width |
| ✅ | 018 Thông tin vị trí | status bar: dòng, cột, offset, thống kê vùng chọn. Đã sửa lỗi **chết app** khi con trỏ đứng cuối file. **Cột là cột THỊ GIÁC** (24/08/2026) — trước đó nhãn ghi "Cột" mà hiện số BYTE, nên gõ `Nguyễn` xong nó báo 9 trong khi người dùng đếm được 7. Giờ cùng luật với chọn khối cột và tự động thụt lề. Phép đo đi từ đầu dòng nên có chặn ở 200 KB; quá đó thì quay về đếm byte và **nói ra bằng dấu `~`** thay vì hiện một con số trông y hệt mà nghĩa đã khác |
| ✅ | 007 Thao tác dòng | ghép, tách theo độ dài/ký tự, dời lên/xuống (⌥↑/⌥↓), đảo thứ tự, **nhân đôi (⇧⌘D)** và **xóa dòng (⌘K)**. Hai mục cuối từng được ghi là xong ở đây mà thật ra chưa có mã — xem §6. Nhân đôi dòng CUỐI tự thêm EOL; xóa tới hết tài liệu nuốt cả EOL của dòng trước |
| ✅ | 008 Thao tác khoảng trắng | trim, xóa dòng rỗng, nén dòng trống liên tiếp, và **cắt khoảng trắng cuối dòng khi lưu** — mặc định TẮT vì nó sửa những dòng người dùng không chạm tới, và bật sẵn sẽ biến một lần lưu thành diff hàng nghìn dòng trong kho mã của người khác. Là một bước hoàn tác RIÊNG đứng trước phép ghi |
| ✅ | 001 Multi-caret | ⌘D, Cmd+Click, Esc; **⌘D trên từ dài nhanh lên 42 lần** (24/08/2026) — phép dò biên từ đọc từng byte qua `bytes(in:)`, mỗi byte một lần cấp phát và vòng lặp KHÔNG có trần, nên ⌘D giữa một chuỗi base64 1 MB tốn 463 ms. Đọc theo lô 4 KB: **11 ms**. Biên ký tự cũng vậy, 293 → 119 ms; gõ/xóa đồng thời trên mọi caret là **một** bước undo. Lõi 17 test + 5 bài tự kiểm giao diện đi qua đường AppKit thật (`scripts/run-self-test.sh`, có đối chứng âm). Còn Telex + multi-caret (TC-IME-02) cần người gõ tay |
| ✅ | 002 Chế độ chọn cột | Option+kéo chọn khối; gõ/xóa/dán theo cột; dán khối vào một caret giữ đúng hình chữ nhật. **Cột đếm theo THỊ GIÁC**: TAB nở tới nấc kế tiếp theo tab width của người dùng, nên dòng thụt bằng TAB và dòng thụt bằng dấu cách dóng nhau đúng như trên màn hình. Trước 24/08/2026 TAB tính MỘT cột, và với `\tmot` thì kéo trúng chữ lại chọn được RỖNG — đúng loại file (mã nguồn thụt TAB) mà người ta hay chọn cột nhất. Cột đích rơi giữa một TAB thì về biên gần hơn, hoà thì về trái. Chữ nhiều byte vẫn là một cột |
| ✅ | 003 Column Editor | chèn văn bản / dãy số (2·8·10·16, bước âm, đệm 0) / dãy ngày vào mọi dòng khối cột; hộp thoại xem trước; chèn 5.000 dòng là **một** bước undo. 14 test lõi + 2 bài tự kiểm |
| ✅ | 011 Tự động thụt lề | thừa hưởng thụt lề dòng trước, thêm một bậc sau dấu mở khối (`{` với ngôn ngữ ngoặc, `:` với Python/YAML). Đo bằng CỘT nên dòng thụt bằng TAB và dòng thụt bằng dấu cách vẫn khớp nhau trên màn hình. **Không** có luật "gõ `}` thì tự lùi dòng" — luật ấy chạm vào dòng đã gõ xong và là thứ hay bị kêu nhất ở mọi trình soạn thảo có nó |
| ✅ | 012 Khớp ngoặc / thẻ | ⌃⌘B nhảy tới ngoặc khớp. Bộ quét từ vựng nhẹ, không dùng cây cú pháp: khớp ngoặc chạy theo mỗi nhịp con nháy, dựng lại cây cho từng phím mũi tên là biến việc di chuyển thành giật. Dấu ngoặc trong CHUỖI và CHÚ THÍCH không tính. Tài liệu > 1 MB thì **từ chối khớp và nói ra** thay vì neo giữa chừng rồi đoán — bôi sáng sai cặp ngoặc tệ hơn không bôi sáng gì |
| ✅ | 014 Comment nhanh ⌘/ | dấu theo NGÔN NGỮ (`#` Python, `//` Rust, `<!-- -->` XML). Toàn khối đi cùng một hướng: còn một dòng chưa comment thì comment tất, chứ quyết định theo từng dòng biến khối comment dở thành bàn cờ. Dấu chèn ở cột thụt lề nông nhất |
| ✅ | 016 Thu phóng | ⌘= / ⌘− / ⌃⌘0, kẹp 8…32 pt. Là CÁCH NHÌN: không sinh sửa đổi, không vào lịch sử hoàn tác |
| ✅ | 017 Lịch sử clipboard | ⇧⌘V, vòng 20 mục. Sống trong bộ nhớ, **không ghi ra đĩa**: người ta chép mật khẩu và khoá API vào trình soạn thảo suốt. Trần 1 MB mỗi mục |
| ✅ | 015 Word wrap | ba chế độ (tắt / theo cửa sổ / tại cột), ký hiệu ngắt `↩`, giữ thụt lề phần wrap. Số học cuộn dọc chuyển hẳn sang `VerticalGeometry` của lõi nên kiểm được bằng test. Đo trên file 100 MB: nạp cửa sổ 5,4–8,8 ms (tắt) và 11–14 ms (bật); chi tiết ở ADR-01 §8bis |

### 2.2 Tìm kiếm (FR-SRCH) — nhóm hoàn chỉnh nhất

| | Yêu cầu | |
|---|---|---|
| ✅ | 101 Ba chế độ tìm kiếm | thường / whole word / regex |
| ✅ | 102 Regex engine đầy đủ | PCRE2 10.47 có JIT, vendor từ nguồn |
| ✅ | 103 Biến đổi chuỗi thay thế | `$1`, `\U \L \u \l \E` |
| ✅ | 104 Regex an toàn | `match_limit` là chặn quay lui tất định |
| ✅ | 105 Find All & Search Results | có panel kết quả |
| ✅ | 106 Find/Replace in Files | song song, có xem trước và bỏ chọn từng file |
| ✅ | 111 Go to Line | |
| ✅ | 108 Tìm tăng dần | gõ tới đâu tìm tới đó, **không hoãn**: `DocumentSearch` chạy trên mmap và mỗi lần tìm có hạn giờ 5 giây, nên thêm tầng hoãn chỉ làm phản hồi trễ. Nhảy tới kết quả từ CHỖ ĐANG ĐỨNG, không ném người dùng về đầu file |
| ✅ | 109 Đếm & tô hết kết quả | màu VÀNG riêng, khác màu vùng chọn — kết quả đang đứng vẽ bằng vùng chọn thật, dùng chung một màu thì mất dấu chỗ mình đang đứng. Chỉ tô phần nhìn thấy, tìm nhị phân vào danh sách đã sắp sẵn |
| ✅ | 110 Thử & giải thích regex | panel riêng, chạy trên một MẨU văn bản chứ không trên tài liệu 200 MB. Ô mẫu điền sẵn bằng vùng chọn. Cột giải thích tách biểu thức thành mảnh có tên; chỗ không chắc thì nói "không nhận ra" chứ không đoán |
| ✅ | 107 Mark & lọc dòng | đánh dấu theo pattern, đảo dấu, chép/xóa/chỉ giữ dòng đã đánh dấu; **tô nền dòng** bằng token `mark/line`; **chín màu độc lập** (một dòng mang nhiều màu cùng lúc), menu đổi màu có chấm màu; ⌘F2 đánh dấu, F2/⇧F2 nhảy dấu theo phím Notepad++. 12 test lõi + 6 bài tự kiểm |

### 2.3 Bảng mã (FR-ENC)

| | Yêu cầu | |
|---|---|---|
| ✅ | 202 Tự nhận diện bảng mã | vừa sửa lỗi mất dữ liệu ở mẫu dò (commit `1a267ea`) |
| ✅ | 203 Encode-in vs Convert-to | hai thao tác tách bạch, có cảnh báo mất ký tự |
| ✅ | 204 Chuyển đổi EOL | |
| ✅ | 201 Bảng mã hỗ trợ | UTF-8/16/32, Windows-1250…1258, ISO-8859-x (14), Shift-JIS, GB18030, EUC-KR, Big5, TCVN3, VISCII, **VNI-Windows** — 36 bảng mã |
| ✅ | 206 Chuẩn hóa Unicode | NFC/NFD/NFKC/NFKD. Lõi có từ lâu và có test, nhưng tới nay mới có lệnh giao diện gọi tới — quan trọng với tiếng Việt hơn phần lớn ngôn ngữ: macOS sinh NFD, Windows và web dùng NFC, hai file trông giống hệt nhau vẫn khác byte |
| ✅ | 205 Hiện ký tự ẩn | khoảng trắng · tab · xuống dòng · NBSP/zero-width/điều khiển, bật/tắt từng nhóm. NBSP có ký hiệu riêng |

### 2.4 Tài liệu (FR-DOC)

| | Yêu cầu | |
|---|---|---|
| ✅ | 304 Autosave bản nháp | snapshot delta 20 s, có hỏi khôi phục khi mở lại. Đã sửa: trước đây chỉ chụp **tab đang mở** — mở năm tab sửa cả năm thì bốn tab kia mất sạch khi `kill -9` |
| ✅ | 310 Chế độ file lớn | mmap + piece table |
| ✅ | 314 Lưu nâng cao | luôn ghi nguyên tử temp + rename + fsync |
| ✅ | 303 Session | mở lại danh sách tab đúng thứ tự, vị trí con trỏ, tab ghim, màu tab và **trạng thái chia đôi**; **giữ cả tài liệu chưa lưu** qua bản nháp; file mất thì bỏ qua tab ấy và nói ra. Ghi nguyên tử, JSON đọc được bằng mắt. Nhiều cửa sổ: schema đã có, app hiện vẫn một cửa sổ |
| ✅ | 301 Quản lý tab | mở/đóng/chuyển tab, ghim, tô màu, menu ngữ cảnh đủ mục, **kéo đổi vị trí tab** (kiểm bằng cú kéo chuột thật). Chưa có cuộn ngang khi quá nhiều tab |
| ✅ | 309 Theo dõi file (tail -f) | nhận ra cả **cắt cụt** (`> app.log`, cỡ nhỏ đi) lẫn **xoay vòng** (`logrotate` tạo file mới CÙNG TÊN có thể LỚN hơn — so cỡ không bắt được, phải so inode). Dùng `DispatchSource` chứ không hỏi vòng. Khóa tài liệu ở chỉ đọc: vừa cho gõ vừa nạp thêm từ đĩa là hai nguồn sửa đổi tranh nhau |
| ✅ | 311 Chỉ đọc & quyền | tự nhận file không có quyền ghi, chặn ở mọi đường sửa, hiện trên thanh trạng thái, và `geditor --read-only` |
| ✅ | 312 File gần đây · mở lại tab | qua `NSDocumentController` nên dùng chung danh sách với Dock; ⇧⌘T mở lại theo ngăn xếp, bỏ qua file đã bị xoá |
| ✅ | 313 In ấn | in từ một `NSTextView` dựng riêng chứ không in `editorView` — view trên màn hình chỉ giữ CỬA SỔ 2 MB, in nó ra sẽ được đúng phần đang xem trong khi người dùng tưởng đã in cả file. Trần 20 MB, nói rõ khi vượt |
| ✅ | 302 Chia đôi màn hình · nhiều cửa sổ | chia dọc/ngang, **clone cùng tài liệu ở hai nửa** — nội dung đồng bộ tức thì, vị trí cuộn độc lập (TC-DOC-05 kiểm bằng máy, có đối chứng âm). **kéo tab thả sang nửa kia** và lệnh "mở tab này ở nửa kia". **Kéo tab sang CỬA SỔ KHÁC** (⌥⌘N cửa sổ mới, ⌃⌘N tách tab ra cửa sổ mới): `WindowManager` giữ sổ đăng ký, và cửa sổ đầu KHÔNG đặc biệt — một "cửa sổ chính" ngầm định sẽ lộ ra đúng lúc người dùng đóng nó. Vòng kéo tự chạy vẫn dùng được, không cần `NSDraggingSession`: sự kiện chuột vẫn về cửa sổ đã nhận `mouseDown` kể cả khi con trỏ ra ngoài, nên chỉ cần đổi sang toạ độ MÀN HÌNH lúc thả. Thả ra ngoài mọi cửa sổ = tách ra cửa sổ mới, đúng lối Safari. Tab đang GHIM thì không đi đâu cả. Phiên lưu và khôi phục ĐỦ mọi cửa sổ kèm khung |

### 2.5 Còn lại của Phase 1

| | Yêu cầu | |
|---|---|---|
| ✅ | FR-UI-805 Status bar tương tác | encoding, EOL, caret, tab size — bấm đổi được |
| ✅ | FR-UI-803 Preferences · NFR-PORT-03 | cửa sổ Cài đặt ghi vào `settings.json` — file văn bản đọc được bằng mắt, chép giữa các máy được. **Không dùng `UserDefaults`** (ADR-09): plist nhị phân, ở chỗ khác nhau giữa hai kênh phát hành, không diff được, hỏng thì không ai sửa tay nổi. File của bản MỚI HƠN thì từ chối và **không ghi đè** — ghi đè là xoá sạch cấu hình của người đồng bộ hai máy; khoá thiếu thì về mặc định chứ không ném |
| ◐ | FR-UI-804 Đa ngôn ngữ EN/VI | khoá dịch là chính chuỗi tiếng Việt, nên thiếu bản dịch rơi về hành vi hôm nay. Đã dịch: **menu bar, panel Tìm, panel SQL, bảng CSV, Column Editor, sheet chuyển đổi/công thức, tên chín màu đánh dấu**. **Nợ đã ĐẾM được** (24/08/2026, `scripts/scan-untranslated.py`): **475 chuỗi** chưa có bản tiếng Anh — 281 chuỗi TRẦN (bọc `L()` là xong) và 194 chuỗi có **nội suy** (phải tách thành chuỗi định dạng trước, tức sửa mã chứ không phải dịch). Trước đây mục này ghi ✅ kèm câu "chưa dịch một số panel" — đúng về cơ chế nhưng che mất tầm vóc. Có **cổng chốt hai chiều** trong `check-core-no-ui.sh`: đỏ khi con số tăng, và cũng đỏ khi giảm mà quên hạ mốc, để mốc không đứng yên nói dối. Bài tự kiểm vẫn đòi mọi mục menu phải có bản dịch |
| ✅ | FR-UI-801 Theme | năm màu vùng soạn thảo đọc từ `Tokens.theme`; hai theme dựng sẵn + theme người dùng ở `themes/*.json`. Mỗi màu có cả bản sáng lẫn bản tối. Màu gõ sai rơi về theme mặc định, **không** về đen — đen trông như một lựa chọn thiết kế. Đã ĐO trên ảnh: màu nhấn đi từ (221,114,54) sang (106,153,234). **Sửa 24/08/2026:** mười một view dựng nền bằng `layer.backgroundColor = ….cgColor` — một ẢNH CHỤP màu, nên đổi theme thì nền đứng nguyên trong khi phần vẽ bằng `draw(_:)` đổi theo, và cửa sổ thành hai nửa hai màu. Giờ tất cả đi qua `NSView.applyLayerBackground` + `viewDidChangeEffectiveAppearance`, có bài tự kiểm đọc màu layer thật dưới CẢ hai appearance và một cổng chặn ai đó gán thẳng trở lại. Bảng CSV cũng lấy nền từ theme thay vì để `NSTableView` dùng màu hệ thống |
| ✅ | FR-UI-802 Shortcut Mapper | khoá là TÊN SELECTOR, áp SAU khi menu dựng xong nên phím mặc định vẫn đọc ra được. Phím đã có chủ thì **từ chối và nói tên hai lệnh đang tranh nhau**. Preset Notepad++ không sao y nguyên: giữ phía macOS cho lệnh cả hệ điều hành đều có |
| ✅ | FR-FMT-501 Syntax highlighting 20 ngôn ngữ | ADR-04 đã chốt. **Đủ 20 grammar vendor từ nguồn**, truy vấn tô màu nhúng vào mã sinh sẵn, `SyntaxHighlighter` ở lõi chạy đúng quyết định "cửa sổ + lề 64 KB" — 10 test, có đối chứng âm. Lề đã đo trên nhóm bộ quét ngoài: 16 KB đủ cho bash/ruby; **YAML file lớn thì không tô** thay vì tô sai (đã vào mã); **python chưa kết luận**. Đường chạy nền + huỷ (sạch dưới Thread Sanitizer), **đã vẽ ra màn hình**: nhận ngôn ngữ theo đuôi file, hiện ở thanh trạng thái, tô lại sau khi ngừng gõ 150 ms. Mục python đã ĐÓNG: nguyên nhân là thiếu gốc toạ độ thụt lề, sửa bằng phép dóng biên về **dòng cột 0** — Python và YAML giờ khớp tuyệt đối với phân tích cả tài liệu (ADR-04 §2.6) |
| ◐ | FR-AUTO-601/602 Ghi & chạy macro | ghi thao tác gõ + lệnh di chuyển + Find/Replace (kể cả regex, có `$1`); phát 1 lần / N lần / **đến cuối tài liệu** / **trên mọi tab**; hủy được; lưu macro có tên, mỗi macro một file JSON, chín macro đầu tự có ⌃⌘1…9. Cả lần chạy là **một** bước undo. Batch theo thư mục là Phase 2; cho người dùng TỰ chọn phím tắt thuộc Shortcut Mapper (FR-UI-802, Phase 2) |

### 2.6 Ngoài Phase 1 nhưng đã xong

| | Yêu cầu | |
|---|---|---|
| ✅ | FR-AUTO-605 Công cụ dòng lệnh | `geditor file:120:5`, `--wait`, `--read-only`, `--info`, nhận stdin |
| ✅ | FR-CORE-010 Chuyển đổi hoa/thường | HOA, thường, snake_case… |
| ✅ | FR-CSV-404 Thao tác cột theo field | xóa · chèn trái/phải · hoán vị (kéo tiêu đề), tất cả theo RFC 4180 — mỗi lệnh một bước undo |
| ✅ | FR-CSV-405 Validate & lint | kiểm số cột VÀ suy luận kiểu cột (số · ngày · chuỗi) trong một lượt quét; panel danh sách lỗi bấm được để nhảy tới nơi, ô sai kiểu tô đỏ trên bảng. Ngày kiểm cả lịch: 2026-02-31 đúng khuôn nhưng bị bắt |
| ✅ | FR-CSV-406 Chuyển đổi định dạng | CSV → TSV · JSON · XML · Markdown · SQL INSERT, và đổi dấu phân tách (một bước undo). Sheet có xem trước 5 hàng đi qua ĐÚNG hàm sinh bản thật; tài liệu > 64 MB thì khóa "tạo tab mới" và nói rõ vì sao. Lỗi ngắt dòng ở ô xem trước **đã sửa 22/08/2026** — xem §2.7, có bài tự kiểm tự đo lại cái thước của nó |
| ✅ | FR-ENC-207 Mặc định cho file mới | |

### 2.7 Ô xem trước của sheet "Chuyển đổi…" — đã sửa 22/08/2026

Lỗi ngắt dòng đã hết: năm hàng TSV hiện ra đúng năm dòng, xác nhận bằng ảnh chụp cửa sổ thật
(`screencapture` lên chính window của sheet, không phải bản dựng lại trong bộ tự kiểm).

Cách sửa: **bỏ hẳn `NSTextView`** ở ô này. Nay là một `NSTextField` nhiều dòng, `wraps = false`,
nằm trong scroll view, và khung do mã tự đo tự đặt — không ràng buộc nào kéo nó co theo bề ngang
cửa sổ, nên bề ngang khung không còn dính dáng gì tới chỗ chữ xuống dòng. Nền là một view LẬT tự
tô, vì document view nhỏ hơn clip view thì AppKit dán nó vào góc dưới.

Ảnh chụp còn phơi ra hai chỗ nữa, đã sửa luôn:

- **Nấc tab mặc định 28pt** (chưa đầy bốn ký tự đơn cách cỡ 12) làm hai ô dính liền —
  `Chin MuoiSo 123`, trông như bản TSV mất dấu phân tách. Nấc đặt lại thành tám ký tự.
- Phép đo bề ngang phải dùng **cả thuộc tính đoạn** kể cả nấc tab, không riêng font: đo thiếu
  thì ô hẹp hơn chữ và cắt mất phần cuối — không ngắt dòng nhưng vẫn là mất chữ.

**Bài tự kiểm mới tự đo lại cái thước của nó.** Nó vẽ ô ra bitmap rồi lấy chiều cao vệt mực chia
cho chiều cao dòng — không hỏi AppKit về dự định bố trí, vì chính phép hỏi ấy đã đổi bộ máy bố
trí và cho ra bài kiểm xanh trong khi ứng dụng thật ngắt dòng. Rồi nó ép ô về đúng cấu hình hỏng
cũ và đòi con số phải TĂNG: thước không báo được cái hỏng thì bài kiểm tự trượt. Hai chi tiết
học được khi dựng: đếm từng dải mực thì gạch dưới trong `dia_chi` rơi khỏi đường chân chữ và
thành một dải riêng (báo 6 dòng cho 5 hàng), còn dữ liệu thử phải DÀI hơn khung, không thì cấu
hình hỏng cũng chẳng ngắt dòng và bước đo thước chẳng nói gì.

Bài kiểm cũng đòi phần chữ bị cắt phải CUỘN tới được: cắt mà không cho cuộn còn tệ hơn ngắt dòng.

**Việc kế tiếp** (cập nhật 26/08/2026 — hai mục cũ ghi ở đây đều đã xong): khép nốt Phase 2 bằng
**FR-DQR-001/002** và **FR-QRY-001**. Thứ tự và lý do ở `docs/ke-hoach-hoan-thien-v2.2.md`.

---

## 3. Yêu cầu phi chức năng

**61 NFR của SRS v2.2: 30 đạt · 11 một phần · 20 chưa có mã.** Bảng dưới là 31 NFR của bộ v1
(có bốn dòng mới thêm 26/08/2026); 30 NFR của các cụm v2.0–v2.3 ở **§3bis**.

> **Ba con số ấy đổi ngày 28/08/2026, và không phải vì ai viết thêm mã.** Chúng đổi vì §3bis đã
> trôi theo hướng NGƯỢC với thói quen: nó ghi 26 NFR "chưa có mã để đo" trong khi sáu trong số
> đó nay đã có phép đo chạy được và ĐẠT (QRY-02 · DQR-01 · MMD-01 · KNW-02 · KNW-03 · KNW-04),
> vì các cụm FR sinh ra chúng đã khép sau ngày dòng ấy được viết. Một trang trạng thái ghi thấp
> hơn sự thật vẫn là một trang sai — nó làm việc đã trả tiền trông như chưa làm.

| | Yêu cầu | |
|---|---|---|
| ✅ | **NFR-PERF-01 Khởi động nguội** | **481 ms, trần 500 ms** (đo lại 28/08 sau khi liên kết Sparkle — ADR-16 §3; trước đó 465) — `scripts/run-startup-kpi.sh`. Ấm 219 ms. Phân rã: dyld 239 ms + app 221 ms. Đường đi: 794 → 690 (tách ba grammar nặng sang `libTreeSitterHeavy.dylib` nạp bằng `dlopen`) → 574 (panel chỉ vào cửa sổ khi người dùng mở lần đầu; giải Auto Layout lần đầu 96 → 7 ms) → ~520 (bỏ bảng ký hiệu khỏi bản giao) → **465** (chuyển **cả hai mươi** bảng tra grammar sang dylib; binary chính 22 → **3,47 MB**). **Đọc cho đúng:** cùng một bản dựng không đổi cho 507/524/547 ms ở ba phiên đo khác nhau — chênh ±40 ms là nhiễu máy. Và "nguội" ở đây là lần mở ĐẦU TIÊN của một file nhân chưa từng thấy (≈135 ms cố định + ≈10 ms mỗi MB); mọi lần mở sau đó là 219 ms. Số đo ở **`docs/adr/ADR-08-startup-budget.md` §2.9–2.13**. **Đo lại 04/09/2026 sau khi thêm `CrashReporter`: 507 ms** — trong dải nhiễu đã ghi ở trên, nhưng vẫn phải chứng minh không phải hồi quy, nên đã đo ĐỐI CHỨNG bằng cách tắt hẳn bộ bắt sự cố: **549 ms**, tức còn chậm hơn. Phần `app` giữ nguyên **206 ms ở CẢ HAI lượt** — chênh lệch nằm trọn ở `dyld` (300 so 346 ms) trên một máy đang chạy dựng và kiểm liên tục. Bài học của chính phép đo này: khi con số xấu đi, đo đối chứng TRƯỚC khi đổ lỗi cho thay đổi gần nhất |
| ✅ | NFR-PERF-05 RAM nhàn rỗi | **18,0 MB**, trần 80 MB — đo cùng script |
| ✅ | PERF-02/03 Mở 100 MB, 1 GB | đo trong PoC-B |
| ✅ | PERF-04 Độ trễ gõ phím | đo trong PoC-A; **sản phẩm** giờ chạy trên cửa sổ 2 MB, đo thật trên file 500 MB: phys_footprint 34–40 MB (0,07×), gõ và nhảy dòng đều đúng |
| ✅ | PERF-05 Bộ nhớ | đo; hướng đề xuất đạt 0,03× ở 500 MB (trần 1,5×) |
| ✅ | PERF-08 Regex quy mô lớn | |
| ✅ | REL-01 Không mất dữ liệu chưa lưu · REL-02 Ghi file an toàn · REL-05 Regex không sập app | |
| ✅ | MNT-01 Kiến trúc phân lớp | có script CI chặn lõi import UI |
| ✅ | MNT-02 Kiểm thử | **2255 test + 258 bài tự kiểm** (một nhóm chạy cả dưới Thread Sanitizer) — chạy lại 28/08/2026, 0 lỗi cả hai bộ |
| ✅ | PORT-01 Universal Binary · PORT-02 macOS 12+ · PORT-04 Thư viện bên thứ ba | PCRE2 và Scintilla đều vendor từ nguồn |
| ✅ | SEC-02 Không telemetry | không có mã gửi dữ liệu đi đâu |
| ◐ | PERF-06 Find in Files | đo được, nhưng TC-PERF-05/06 **không kết luận được tại chỗ** (cần máy chuẩn STP §2.1; số x86 hiện là Rosetta) |
| ◐ | SEC-01 Ký số & công chứng | đường ống ký thật + notarize + staple đã dựng và đã thử nhánh lỗi; chỉ **chờ tài khoản Developer ID của anh** (đặt `GEDITOR_SIGN_IDENTITY` và `GEDITOR_NOTARY_PROFILE`). **Vế thứ hai — kênh tự cập nhật Sparkle 2 — có mã từ 28/08/2026** (ADR-16): framework vendor vào kho, liên kết lúc nạp, bộ cập nhật dựng lười, chỉ bản tải trực tiếp, và `build-universal.sh` TỪ CHỐI ký khi `SUPublicEDKey` còn là chỗ giữ chỗ. Vẫn ◐ vì **chưa chạy thử một vòng cập nhật đầu-đến-cuối** — cần khoá thật, appcast thật và hai bản khác phiên bản |
| ✅ | MNT-03 CI/CD hai kiến trúc | `.github/workflows/ci.yml`: ràng buộc kiến trúc → test → tự kiểm → dựng universal → **`lipo` xác nhận đủ hai kiến trúc**. Bước cuối không thừa: `swift build` trên runner Apple Silicon ra binary arm64 chạy tốt trên mọi máy CI, và không ai phát hiện phần x86_64 biến mất cho tới khi một người dùng Intel tải về. Benchmark CHẠY nhưng **không so ngưỡng** — ngưỡng chỉ có nghĩa trên máy chuẩn STP §2.1 |
| ✅ | MNT-04 Semver + changelog | `CHANGELOG.md` |
| ✅ | MNT-02 Độ phủ ≥70% | **93,26%** (đo lại 28/08/2026), `scripts/run-coverage.sh`, và cổng ấy nằm trong CI. **Từng xuống 93,04% từ 94,07% (26/08) và đã truy ra lý do:** không có mã cũ nào tụt — cụm FR-QRY và FR-MIN-001 đổ thêm ~900 dòng lõi mới vào mẫu số, phủ 80–97% tuỳ tệp (`AnomalyDetector` 96,8% · `PivotSpec` 86,8% · `QueryCatalog` 84,2% · `QueryLibrary` 80,7%). Pha loãng, không phải thoái lui. Ba tệp dưới 90% là chỗ cần thêm bài kiểm khi quay lại. Chỉ đo `GEditorCore`: lớp app không chạy dưới `swift test`, vendor là mã người khác. Con số này trả lời "phần LÕI đã được kiểm tới đâu", KHÔNG trả lời "cả sản phẩm đã được kiểm tới đâu" |
| ◐ | **MNT-02bis — độ phủ TẦNG APP** | **75,82%** (đo lại 05/09/2026; mốc 75,0 giữ nguyên), `scripts/run-app-coverage.sh` — chạy chính **367** bài tự kiểm dưới bộ đếm. *Dòng này đã trôi hai lần liên tiếp — 75,58%/247 rồi 75,28%/347 — nên số ở đây phải đo lại mỗi lần sửa trang, đừng chép.* Chỗ mỏng nhất 05/09: `CrashReporter` 44,69% · `CorrelationPanel` 57,94% · `TabBarView` 58,37% · `PDFViewerView` 63,14%. Ngày 04/09 cổng này ĐỎ (74,66%) và đã trả về xanh bằng bài kiểm chứ không bằng cách hạ mốc: bốn bài mới đi vào đường nằm sau một hộp chọn file — `Unattended.chooseFile` luôn trả `.abort` trong lượt chạy không người, nên mọi phần việc gộp chung với phép hỏi là mã KHÔNG CÓ đường nào chạy được dưới bộ tự kiểm; cách sửa là tách phần LÀM VIỆC khỏi phần HỎI. Có cổng chốt hai chiều như cổng dịch. **Hai tệp 0% đã ĐÓNG 28/08:** `ColumnEditorPanel.swift` và `SearchResultsView.swift` — cả hai thuộc FR đã ✅ (FR-CORE-003, FR-SRCH-105) mà trước đó không một dòng nào từng chạy trong bất kỳ bài kiểm nào. Bốn bài tự kiểm mới đi qua ĐÚNG những điều khiển người dùng chạm tới (ô nhập, ô xem trước, nút OK/Huỷ) chứ không gọi tắt vào lõi — gọi tắt thì vẫn để nguyên phần NỐI, tức đúng chỗ đang hở. `SearchResultsView` 0% → **70,89%**. Đã xác nhận ĐỎ được: phá `showMessage` thì bài kiểm đỏ, hoàn nguyên thì xanh. **Chỗ mỏng nhất còn lại:** `CorrelationPanel` 57,94% · `TabBarView` 58,37% · `MainWindowController` 65,92% |
| ✅ | REL-04 Ổ mạng & iCloud | ghi trên iCloud Drive và ổ mạng đi qua `NSFileCoordinator`; ổ cục bộ vẫn đi thẳng. **Chưa kiểm tay trên ổ thật** — xem §5 |
| ◐ | USE-03 VoiceOver | view TỰ VẼ (bản đồ tài liệu, thanh tab, hàng tiêu đề CSV) khai vai trò, nhãn và GIÁ TRỊ; bảy view container có nhãn nhóm; ô Tìm/Thay có nhãn thật vì `placeholderString` không phải nhãn. Bài tự kiểm chặn view tự vẽ câm lặng. **Chưa ai ngồi nghe thật** — xem §6 |
| ✅ | USE-04 Trang di cư N++ | `Help ▸ Trợ giúp GEditor` và `Help ▸ Di cư từ Notepad++`, nội dung là chuỗi trong mã chứ không phải file trong bundle |
| ◐ | **USE-02 Bộ gõ tiếng Việt** | 5 kịch bản Telex kiểm bằng máy qua `NSTextInputClient`, có đối chứng âm — Scintilla và `NSTextView` đều 5/5. Còn **một lần gõ thật với EVKey** trước phát hành |
| ◐ | **PERF-07 Năng lượng** | Chỉ tiêu có BA vế, và chỉ một vế cần người. ✅ *"không polling nền"* và *"dùng FSEvents/Dispatch Source thay vì vòng lặp kiểm tra"* — cổng tĩnh trong `check-core-no-ui.sh` với danh sách khai báo TỰ DỌN; hiện chỉ hai chỗ được khai (nhịp tự lưu FR-DOC-304, và `usleep` chờ tiến trình lọc chạy xong — cả hai đều không phải hỏi-vòng-nền). `DirectoryWatcher` dùng FSEvents, `FileTailWatcher` dùng `DispatchSource`. ✅ `GEditorApp --measure-idle N` đo CPU và số lần đánh thức lúc nhàn rỗi: **0,01–0,04% CPU · 0,4–0,6 lần đánh thức/giây** (trần đề nghị 0,5% và 5/giây). ⛔ Vế *"Energy Impact: Low trong Activity Monitor"* thì **không API nào trả về cái nhãn ấy** — cần người ngồi trước máy, xem §6 |
| | ↳ *vì sao phải đếm ĐÁNH THỨC chứ không chỉ CPU* | Đo bằng đối chứng âm: chèn một vòng hỏi 60 Hz vào app rồi chạy lại. CPU lên 0,477% — **vẫn lọt dưới trần 0,5%** — trong khi đánh thức nhảy từ 0,45 lên **60,60 lần/giây**. Một bài đo chỉ canh CPU sẽ xanh trước đúng thứ nó sinh ra để chặn |
| ◐ | **REL-03 Ổn định** | Chỉ tiêu SRS có hai vế. **Vế crash reporter opt-in XONG 04/09/2026** (`CrashReporter`): bắt `NSException` và sáu tín hiệu, ghi báo cáo vào `Application Support/GEditor/crash/`, lần khởi động sau hiện dải thông báo kèm nút **Mở báo cáo** — báo cáo mở thành một TAB, vì sản phẩm này LÀ trình soạn thảo và đọc một tệp chữ ở đây thì tự nhiên hơn một hộp thoại. Ba ràng buộc, theo thứ tự quan trọng: **(1) không một byte nội dung NÀO của tài liệu, và cả ĐƯỜNG DẪN cũng không** — `~/Desktop/luong-thang-12.xlsx` đã nói ra ba điều riêng tư trước khi ai kịp mở nó; bài tự kiểm mở một tài liệu có tên và nội dung mang chuỗi bí mật rồi soi báo cáo, và đã xác nhận ĐỎ được. **(2) Người dùng quyết định, và app nói thẳng là KHÔNG có đường gửi tự động, cũng chưa có máy chủ nào để gửi** — một nút «Gửi» gọi vào hư không thì tệ hơn không có nút. **(3) Bộ xử lý tín hiệu chỉ `write(2)` và `backtrace_symbols_fd`**: mọi thứ tốn bộ nhớ — kể cả nhãn ĐÃ DỊCH của từng tín hiệu — dựng sẵn lúc khởi động, vì ghép chuỗi trong handler là cách chắc chắn biến một sự cố thành hai. Đường TÍN HIỆU — đường mà một sự cố thật đi qua — có cổng riêng `scripts/check-crash-reporter.sh`, chạy trong `check-core-no-ui.sh`: nó LÀM SẬP một tiến trình thật bằng `--crash-signal`, rồi đòi ba điều — chết đúng tín hiệu (handler KHÔNG được nuốt), có báo cáo với ≥ 5 khung ngăn xếp, và không mang đường dẫn nào của người dùng. Cổng ấy **bắt được lỗi ngay lần chạy đầu**: hai lượt thử ghi báo cáo vào Application Support THẬT của người đang ngồi máy, vì cờ đo đạc đặt SAU `install()` mà `install()` đã chốt đường tệp. **Vế tỷ lệ ≥ 99,8% vẫn chưa đo**: nó cần số phiên từ máy người dùng thật, tức cần một đường gửi mà sản phẩm cố ý chưa có. Phần tự động hoá được thì đã làm: `scripts/run-soak.sh` quét **15 hạt giống × 10.000 thao tác** (150 nghìn thao tác), mỗi lượt là một dãy ngẫu nhiên TẤT ĐỊNH gồm **57 loại thao tác** trộn lẫn trên ứng dụng thật (25/08/2026). Nó tìm ra thứ 1181 test lõi và 179 bài tự kiểm không thấy, vì mỗi bài kiểm dựng trạng thái sạch rồi làm ĐÚNG MỘT việc: **chín lỗi làm sập app** và **hai chỗ rò bộ nhớ**. Sau khi sửa: 150 nghìn thao tác không hạt nào sập, RAM lúc rảnh 40–62 MB. Bốn đợt mở rộng tập thao tác (22 → 38 → 50 → 57); hai đợt cuối KHÔNG ra lỗi mới, tức các bản sửa đang giữ. Đã chạy cả **hai lượt 100.000 thao tác** (332 thao tác/giây giữ nguyên suốt chặng, xu hướng bộ nhớ +15 và +22 MB trên trần 40) và một lượt trong **bundle sandbox** với tập thao tác đầy đủ. Chạy được cả TRONG bundle đã ký (`--bundle appstore`), tức trong sandbox |
| | ↳ *chín lỗi sập* | Bốn do **vùng chọn / dấu dòng còn trỏ vào tài liệu đã co lại** — nay kẹp tại chỗ ĐỌC (`MultiSelection.clamped`, `WindowedTextView.selection`, `selectedDocumentRange`, `LineMarkBook.nextMarkedLine(withinLineCount:)`) chứ không kẹp ở từng chỗ gọi. Hai do **hai vùng sửa GIAO NHAU**: dán khối cột đè lên vùng đã bôi đen, và xoá lùi khi một caret đứng ngay sau một vùng chọn (⌘D chọn một từ, Cmd+Click thêm caret ngay sau, Backspace). Một do **tám chỗ quy đổi UTF-16 → offset mà chỉ một chỗ có kẹp** — nay cả tám đi qua một cửa. Hai do **pane hiện sai tài liệu**: xem hai dòng dưới. Và nặng nhất là **quy đổi offset trôi trên tài liệu có byte UTF-8 hỏng** |
| | ↳ *pane hiện sai tài liệu* | Chỉ số tab của mỗi nửa và buffer mà view đang hiện đổi ở hai chỗ khác nhau. Hậu quả KHÔNG phải hiện sai chữ: `onEdit` tính vùng sửa trên buffer của VIEW rồi áp lên buffer của TÀI LIỆU, nên mọi phím gõ tính trên tài liệu này và áp lên tài liệu kia — sập, hoặc sửa im lặng vào một file người dùng không nhìn thấy. Bất biến nay giữ ở `refreshChrome()`, chỗ mọi lệnh đều đi qua. Lỗi thứ hai nấp ngay trong bản sửa thứ nhất: dòng `guard tabs.indices.contains(…) else { continue }` trông như phòng thủ, thật ra là chỗ hở — `paneTabIndices` được phép quá tầm, chỉ getter `activeIndex` tự kẹp lúc đọc, nên hàm đồng bộ BỎ QUA đúng pane đang lệch |
| | ↳ *byte UTF-8 hỏng (`TextWindow`)* | `Document.open` có đường nhanh cho UTF-8 dựng buffer thẳng trên vùng mmap, **không kiểm tính hợp lệ** — nên một file tải dở, một log trộn bảng mã hay một file Latin-1 bị đoán nhầm là đã có byte hỏng ngay khi mở. `TextWindow` quy đổi byte ↔ UTF-16 bằng cách **mã hoá lại** các scalar đã giải mã; một byte hỏng thành `U+FFFD` rộng 3 byte, nên mỗi byte hỏng làm offset trôi thêm 2, TÍCH LUỸ. Sập ở `PieceTable.bytes(in:)` chỉ là triệu chứng dễ thấy; **mốc dòng sau chỗ hỏng cũng lệch**, tức một cú bấm chuột hay một lần gõ rơi đúng chỗ khác — sai trong im lặng, đúng loại hỏng nguy hiểm nhất của sản phẩm này. Sửa: `TextWindow` giữ bảng bề rộng byte THẬT cho những scalar lệch, dựng bằng `UTF8.ForwardParser`. Tài liệu hợp lệ không trả giá gì — nhận ra bằng một phép so sánh (`text.utf8.count == windowBytes.count`). 3 test lõi mới, đã xác nhận ĐỎ khi hoàn nguyên |
| | ↳ *một lượt chạy là chưa đủ* | Hai trong mười lăm hạt giống đầu tiên (11 và 13) sập; **một lượt chạy đơn lẻ có 87% cơ hội bỏ sót lỗi ấy.** Đó là lý do có `run-soak.sh` với bộ hạt giống CỐ ĐỊNH thay vì gọi tay `--soak` một lần |
| | ↳ *hai chỗ rò, cùng một mẫu* | `StatusBarView` và `TabBarView` đều **vứt hết view rồi dựng lại** ở mỗi lần trạng thái đổi — mà cả hai đổi sau gần như mọi thao tác. Mỗi `NSButton` mới kéo theo một chùm đăng ký KVO của AppKit không được thu lại: sau 4.000 lần sửa, heap giữ **226.000 `NSKeyValueDependency`**, bộ nhớ leo tuyến tính ~11 KB mỗi thao tác tới **191 MB** ở 15.000 thao tác (trần RAM nhàn rỗi NFR-PERF-05 là 80 MB). Sửa bằng cách dựng view MỘT LẦN rồi đổ nội dung vào. Đo cặp trong cùng một phiên, 2.000 thao tác: **62 → 1044 thao tác/giây** và RAM lúc rảnh **55,9 → 25,8 MB**. Hai bài tự kiểm mới chặn hồi quy, cả hai đã được xác nhận ĐỎ khi hoàn nguyên bản sửa |
| | ↳ *cách tìm ra* | Đọc mã không ra. Đường đi: `--soak --vet` in bộ nhớ từng thao tác → `--only` chạy riêng từng nhóm để tách nguyên nhân khỏi tương quan → `heap <pid>` chỉ ra lớp nào chiếm chỗ → `MallocStackLogging=1` + `malloc_history` chỉ thẳng ra dòng mã. `--hold N` giữ tiến trình sống đủ lâu để hai công cụ ấy bám vào. Giữ nếp ấy khi bộ nhớ phình lần sau |
| | ↳ *bộ đo tự kiểm chính nó* | Báo cáo kết luận "0 lỗi app định báo cho người dùng", nên trước khi đếm nó **gây một lỗi giả và đòi bộ đếm nhích** — một bộ đếm hỏng cũng cho đúng con số 0 ấy. Cùng lý do, nhịp lấy mẫu bộ nhớ suy từ độ dài lượt chạy (mốc cứng 500 bước không rơi lần nào ở lượt ngắn, và cả báo cáo đọc lại một con số đo lúc khởi động rồi in "✅ ĐẠT"), và dưới 6 mẫu thì báo **CHƯA KẾT LUẬN ĐƯỢC** kèm mã thoát 2 |
| ✅ | SEC-03 Chuỗi cung ứng plugin | **XONG 26/08/2026.** Vế "cài từ đâu / gỡ thế nào" đã có từ ADR-12. Vế còn lại nay là `PluginTrust` ở lõi: **SHA-256 + sổ duyệt JSON đọc được bằng mắt**, ba phán quyết — chưa duyệt thì HỎI (kèm hash, chữ ký đọc qua Security framework, và câu "mã này chạy với quyền của anh, KHÔNG bị giới hạn như script"); đã duyệt và không đổi thì CHẠY, không hỏi lại (hỏi mỗi lần là cách chắc chắn khiến người dùng bấm Đồng ý theo phản xạ); **đã ĐỔI kể từ lần duyệt thì TỪ CHỐI, không hỏi** — đó là hình dạng của một cuộc tấn công chuỗi cung ứng, và người dùng không có cách nào trả lời đúng câu hỏi ấy. Cổng đặt ở `bridge(for:)`, chỗ nghẽn DUY NHẤT dẫn tới mã plugin: kể cả bảng quản lý cũng không đọc được tên lệnh của plugin chưa duyệt, vì đọc được nghĩa là đã chạy nó. 17 test lõi (có vector chuẩn NIST và bộ băm đối chứng viết tách) + 1 bài tự kiểm dựng plugin C thật, duyệt, chạy, rồi THAY file và đòi nó bị chặn |

**Bốn NFR của bộ v1 trước nay không có dòng nào trong bảng này** — thêm 26/08/2026. Thiếu dòng
không có nghĩa là thiếu mã, nhưng nó có nghĩa là **không ai đối chiếu được**, và đó đúng là loại
nợ mà §5 đã một lần bắt được (tính năng "có chỗ bấm mà không có gì phía sau").

| | Yêu cầu | |
|---|---|---|
| ✅ | **SEC-04 Sandbox bản App Store** | đã làm từ lâu nhưng chưa từng mang mã NFR ở đây: App Sandbox bật, security-scoped bookmark cho cả TAB lẫn THƯ MỤC, bản tải trực tiếp không sandbox để đỡ plugin native + CLI. Đúng nguyên văn chỉ tiêu. Còn một lần kiểm TAY (§6.1) |
| ✅ | **SEC-05 Quyền tối thiểu** | **KHÉP 04/09/2026** — cổng tĩnh trong `check-core-no-ui.sh` soi hai hướng: **API** (`AXIsProcessTrusted`, `AXUIElement*`, `CGEventTapCreate`, `CGWindowListCreateImage`, `CGRequestScreenCaptureAccess`, `IOHIDRequestAccess`) và **đường dẫn** tới thư mục macOS bảo vệ thật (`~/Library/Mail|Messages|Safari|Cookies`, `Application Support/AddressBook…`, `/private/var/db/dslocal`). `WindowCapture.swift` được miễn vì chỉ chạy dưới `--capture`. Đã xác nhận cổng ĐỎ được: thả một tệp gọi `AXIsProcessTrusted()` kèm đường `~/Library/Mail` thì nó chỉ đúng cả hai dòng. Bản đầu của cổng bắt nhầm chính phép NHẬN RA sandbox (`NSHomeDirectory().contains("/Library/Containers/")`) — danh sách nay là thư mục được bảo vệ THẬT, không phải mọi đường dưới `/Library` |
| ◐ | **USE-01 Tuân thủ HIG** | menu bar đầy đủ và phím tắt chuẩn Cmd **đã có bài tự kiểm** (bài soi thanh menu chặn `action: nil` + bài chặn phím tắt trùng). Cửa sổ chính là `.titled/.closable/.miniaturizable/.resizable` nên full-screen và Stage Manager chạy theo mặc định AppKit — **nhưng chưa ai kiểm**. Vế "hành vi document-based app chuẩn macOS" thì **cố ý đi lệch**: GEditor không dùng `NSDocument` (xem FR-DOC-305 §4bis) |
| ✅ | **USE-05 Font & hiển thị** | **KHÉP 04/09/2026.** Mặc định SF Mono/Menlo. **Công tắc chữ ghép** ở `Cài đặt…` (`Settings.ligatures`), mặc định TẮT vì một chữ ghép gộp `!=` thành một hình nên số ký tự trên màn hình không còn khớp số ký tự trong tệp — mà sản phẩm này có Column Editor, chế độ cột và ngắt dòng tại cột, ba thứ đều đo bằng cột. Bài tự kiểm đòi công tắc ăn cả chữ ĐANG HIỆN lẫn chữ SẮP GÕ, và **sống qua một lượt cuộn vượt mốc cửa sổ 2 MB** — bản đầu của bài dùng tài liệu 400 dòng và nhát bẻ đi lọt vì cả tài liệu lọt trong một cửa sổ. Cũng nhờ nhát bẻ ấy mà một dòng mã THỪA bị gỡ: `NSTextView.string = …` tự áp `typingAttributes`, nên lượt nạp cửa sổ không cần đặt lại thuộc tính. **Phép đo hiển thị nay có**: vẽ THẬT ra bitmap ở bốn cỡ 8·13·20·32 pt rồi đếm điểm ảnh có mực — chữ có dấu chồng hai tầng (`ế ữ ằ ỗ ợ`), **NFC so với NFD** phải ra gần cùng lượng mực (lệch < 50%; lệch nhiều nghĩa là bản tổ hợp vẽ thành hai hình rời — đúng ca người dùng dán tên tệp từ Finder, vì APFS là NFD), và **emoji phải ra MÀU** vì một ô .notdef cũng có mực nhưng đen trắng |

**Và SEC-01 rộng hơn chỗ trang này đang ghi.** Bảng trên chép SEC-01 thành "ký số & công chứng",
nhưng nguyên văn SRS còn một vế nữa: *"bản cập nhật ký EdDSA (**Sparkle 2**) tải qua HTTPS"*.
`grep Sparkle` trên `Sources/` → **0 file**. Kênh tự cập nhật chưa tồn tại, và nó không nằm trong
"chờ tài khoản Developer ID" — nó là việc viết mã.

### 3bis. Ba mươi NFR của các cụm v2.0–v2.3 — **10 đạt · 1 một phần · 19 chưa**

61 NFR của SRS v2.2 = 31 của bộ v1 (bảng trên) + **30 của các cụm mới**. Bảng này được soát lại
ngày 28/08/2026 bằng cách đọc `benchmarks/results/*.json` chứ không đọc lại chính nó — luật xếp
loại: một mục chỉ vào hàng ✅ khi có **một tệp kết quả mang `pass: true` và nêu đích danh mã
NFR ấy**, hoặc một cổng chạy được trong `check-core-no-ui.sh`.

**Đạt, có số đo:**

| | Mã | |
|---|---|---|
| ✅ | NFR-CLN-01 | **4,45 s** / trần 10 s cho 1 triệu hàng × 20 cột (20 triệu ô, 4,50 triệu ô/giây). *Vế thứ hai — "fuzzy dedup 100 nghìn bản ghi ≤ 60 s" — vẫn chưa đo được vì FR-CLN-004 chưa có mã* |
| ✅ | NFR-CLN-02 | mọi thao tác làm sạch đều có (a) số liệu phát hiện hoặc sheet xem trước, (b) một bước undo, (c) báo cáo sau khi chạy. *Đúng trên thực tế, nhưng chưa có cổng nào mang tên NFR-CLN-02 chặn thao tác thứ bảy quên vế (c)* |
| ✅ | NFR-QRY-02 | **1 triệu điểm**: LTTB 6,1 ms · chia khoảng 66,9 ms · phân vị 81,7 ms — mốc 2 s áp cho phép chậm nhất. `chart-kpi-arm64.json` |
| ✅ | NFR-QRY-03 | truy vấn chỉ-đọc, kết quả luôn ra tab MỚI. Sau khi đổi sang DuckDB thì cần HAI lớp, vì `COPY` ghi được file — có bài kiểm chạy `COPY t TO` rồi đòi file ấy KHÔNG tồn tại |
| ✅ | NFR-DQR-01 | **324 ms** / trần 15.000 cho 1 triệu dòng × 50 rule. Cột đối chứng "từng luật một" mất 15.023 ms — chênh 46× đo đúng giá của việc gom luật vào một lượt quét. `quality-kpi-arm64.json` |
| ✅ | NFR-MMD-01 | **1.099 ms** / trần 2.000 cho 500 node, tính CẢ dựng WKWebView và nạp 3,4 MB JavaScript. Đo bằng chính `MermaidRenderer` mà panel dùng, kể cả hàng rào chặn mạng. `mermaid-kpi-arm64.json` |
| ✅ | NFR-MMD-02 | mermaid **11.17.2** trong bundle, không CDN, phiên bản pin trong bản kê, **có bài tự kiểm đòi trang chạy đúng bản đã vendor** — và từ 28/08 **ghi trong About** (`AppDelegate.aboutCredits`), vế cuối cùng của chỉ tiêu. Ghép ở tầng app chứ không nhét vào `diagnosticSummary` của lõi: bản kê là tài nguyên bundle, lõi không được biết gì về bundle (NFR-MNT-01) |
| ✅ | NFR-KNW-02 | corpus JSONL **1 GB**: mở tới trạng thái duyệt được 3,9 s / trần 10 s; quét thống kê 690 nghìn record 10,1 s / trần 10,35 s. `jsonl-arm64.json` |
| ✅ | NFR-KNW-03 | đồ thị **1 triệu cạnh**: 2-hop 4,3 ms / 2 s · liên thông 4,0 ms / 10 s · PageRank 43,9 ms / 30 s · Louvain 1.074 ms / 60 s. Louvain chạy hai lượt và hai kết quả phải bằng nhau (tất định theo NFR-MIN-02). `graph-arm64.json` |
| ✅ | NFR-KNW-04 | PoC-M: chỉ mục BM25 tự viết đạt cả bốn vế (dựng 1 GB · top-k · đánh giá 1.000 câu · sai số ≤ 1e-9 so cài đặt tham chiếu). `poc-m-arm64.json` |

**Một phần:**

| | Mã | |
|---|---|---|
| ◐ | NFR-QRY-01 | **Ba vế, và cả ba đều cần nói rõ hơn dòng cũ.** Màn hình đầu: 3,5–10,9 ms / trần 300 ms ở bốn phép lọc — nhưng phép thứ năm, *"khớp một hàng CUỐI bảng"*, mất **919 ms** và `pass: false`. Đó là điểm trượt **đã biết và cố ý phơi ra**: `run-clean-kpi.sh` in ❌ mỗi lần chạy mà không làm script đỏ, vì quét tuần tự không thể đạt trần ấy khi kết quả duy nhất nằm cuối file (ghi chú trong `CSVFilter`). Quét hết: 783–2.889 ms, tức **hai trong năm phép vượt trần 2 giây**. Vế *"hủy ≤ 200 ms"* **ĐÃ ĐO 04/09/2026**: `run-mining-kpi.sh` huỷ một phép lọc đang quét giữa chừng (điều kiện không khớp hàng nào, tức ca xấu nhất) và đếm từ lúc gọi `cancel()` — **0,2 ms** / trần 200 ms. Bộ đo từ chối kết luận nếu lượt quét xong trước khi cú huỷ tới, vì khi ấy nó chưa huỷ gì cả. *Dòng cũ ở đây ghi "màn hình đầu 3,5–5 ms" và "quét hết 583–1028 ms" — hai khoảng ấy chỉ đúng nếu bỏ đi những phép chậm nhất, tức đúng chỗ chỉ tiêu muốn hỏi* |


**Chưa đo được — nhưng hai lý do rất khác nhau, và trộn chúng lại là cách mất dấu việc:**

| | Mã | Vì sao |
|---|---|---|
| ✅ | **MIN-01 · MIN-05 · DQR-03** | **ĐO XONG 04/09/2026** — `scripts/run-mining-kpi.sh` (`geditor-bench mining`), ở ĐÚNG cỡ chỉ tiêu: 1 triệu hàng × 20 cột, 1 triệu giỏ hàng, 1.000 nhóm. **Sáu vế ĐẠT** (M4, 04/09): bất thường **99 ms** / trần 10 s · k-means k=20, 50 vòng **26,6 s** / trần 30 s · apriori **38,1 s** / trần 60 s · huỷ **57 ms** / trần 200 ms · group-by 1.000 nhóm **161 ms** / trần 120 s · tất định từng bit ✅ · huỷ giữa chừng giữ **529/1.000** nhóm. Kết quả ở `benchmarks/results/mining-kpi-arm64.json`. **⚠ k-means SÁT TRẦN, và đã có lượt TRƯỢT:** bốn lượt đo cùng buổi cho 24,9 · 25,9 · 26,6 · **33,1 s** — lượt cuối vượt trần 30 s. Nó đạt hay không tuỳ tải máy lúc đo, nên đừng đọc con số 26,6 s như một khoảng an toàn; STP §4.1 đòi trung vị 5 lượt trên máy chuẩn, và phép đo ấy chưa chạy trên MacBook Air M1 của chỉ tiêu. **Và phép đo tìm ra một vi phạm đặc tả sống từ khi cụm FR-MIN khép:** NFR-MIN-05 đòi *«HỦY giữa chừng giữ nguyên kết quả các nhóm đã hoàn tất, đánh dấu rõ»*, còn hiện thực NÉM `OperationCancelled` ra ngoài và mất sạch — bài kiểm cũ `testHuyGiuaChung` lại khoá đúng hành vi sai ấy bằng `XCTAssertThrowsError`. Lỗi có HAI nửa: chặn ở đầu vòng lặp (đã có) không đủ, vì phần lớn thời gian nằm TRONG một nhóm nên cú huỷ gần như luôn rơi vào giữa `TimeSeries.forecast`, và cú ném từ đó cuốn cả hàm. Nay `Report.cancelled` + khối Phương pháp nói ra + panel hiện «ĐÃ HUỶ giữa chừng» ngay trên dòng tóm tắt, không giấu trong tooltip. **Bộ đo cũng phải tự sửa hai lần vì nó xanh giả:** apriori ban đầu sinh 0 luật (dữ liệu ngẫu nhiên đều — con số thời gian khi ấy chỉ đo lượt quét, bỏ hẳn tầng dựng luật), và phép huỷ ban đầu bắn sau khi mọi thứ đã xong rồi báo «giữ 1000/1000 nhóm» như một thành tích |
| ✅ | **RPT-01 · RPT-02 · MIN-04** | **ĐO XONG 04/09/2026.** **RPT-01** (`scripts/run-report-kpi.sh`): 10 khối trên 1 triệu dòng dựng **3.091 ms** / trần 5 s. **Và vế thứ hai của chỉ tiêu — *«cache theo hash(query + trạng thái nguồn)»* — hoá ra CHƯA CÓ MÃ:** bộ đo dựng cùng tài liệu hai lần và thấy 1.313 → 1.207 ms, tức không có cache nào. Nay `ReportBlockCache` (khoá = câu ĐÃ THAY THAM SỐ + dấu phân tách + đường nguồn + cỡ buffer + cỡ và mtime tệp nguồn), nối vào cả preview trong app: lượt dựng lại **3.091 → 0,9 ms**. Đó là con số người dùng gặp nhiều nhất — preview dựng lại sau mỗi lần ngừng gõ, nên sửa một dòng văn xuôi không còn kéo theo mười lượt quét dữ liệu. Cái giá nói thẳng trong mã: trạng thái nguồn đo bằng **cỡ + mtime**, không băm nội dung — băm một tệp 1 triệu dòng mỗi lượt thì đắt hơn thứ nó tiết kiệm. **RPT-02** *(báo cáo tuyệt đối không sửa nguồn)*: bài kiểm so checksum CẢ tệp trên đĩa LẪN buffer, vì DuckDB đọc thẳng tệp nguồn ở vài đường. **MIN-04** *(mọi đầu ra kèm khối Phương pháp)*: `MethodologyBlockTests` gọi tám bộ khai phá ở CẢ hai đường — dữ liệu đẹp, và dữ liệu mà bộ ấy TỪ CHỐI chấm; nhánh từ chối mới là chỗ người dùng gặp nhiều nhất và cũng là chỗ dễ trả về bảng rỗng không kèm lý do |
| ✅ | **MIN-03 · DQR-02 · KNW-05** | **ĐO XONG 04/09/2026.** **MIN-03 và DQR-02** (cả hai P0*, *«chỉ-đọc tuyệt đối — kiểm checksum»*): `ReadOnlyGuaranteeTests` chạy sáu bộ khai phá rồi một lượt chấm điểm đầy đủ, so tổng kiểm CÓ TRỌNG SỐ theo vị trí trên cả tệp lẫn buffer — so chuỗi thì bỏ sót đúng những thay đổi khó thấy nhất (BOM thêm vào đầu, một dấu xuống dòng cuối tệp, CRLF thành LF); và vế *«snapshot ghi tệp RIÊNG»* kiểm bằng cách ghi lịch sử rồi đòi tệp dữ liệu vẫn nguyên checksum. **KNW-05** (`geditor-bench hybrid`): xếp lại top-500 **trung vị 12,5 ms · xấu nhất 13,2 ms** / trần 300 ms, trên corpus 20.000 chunk và đồ thị 2.000 node. Bộ đo ĐẾM số ứng viên thật và từ chối kết luận khi chưa đủ 500 — bản đầu đếm `hits.count` (top-k trả về, 20) thay vì tập ứng viên đưa vào xếp lại, tức báo ĐẠT cho một tải nhẹ hơn chỉ tiêu hai mươi lăm lần |
| ◐ | **KNW-01** | **Đo được phần đo được, 04/09/2026 — và nói ra phần không.** Chỉ tiêu viết *«khi Knowledge Pack KHÔNG CÀI hoặc bị tắt…»*, nhưng ADR-15 đã chốt để Pack nằm TRONG LÕI: trạng thái «không cài» **không tồn tại** trên kiến trúc đã chọn, nên không có bản thứ hai để so 1%. Thứ đo được — và là nội dung thật của «zero-cost» — là **Pack không tốn gì khi chưa ai dùng tới nó**: `--measure-startup` nay chứng minh `heavyLoadedAtLaunch` RỖNG (không `libduckdb`, không BM25Index, không GraphCSR — ba cửa vào của Pack đã đóng dấu `LazyLoadAudit.activate`), và **RAM nhàn rỗi 30,0 MB / trần 80**. Vẫn ◐ vì vế «sai lệch ≤ 1% so với bản không có Pack» không kiểm được mà không bịa ra một bản dựng thứ hai |
| ⛔ | AGT-01…04 · PY-01/02/03 | **chưa có mã FR nào** để mà đo — cả hai cụm ở Phase 5 và 6 |

---

### 3.1 Bộ tài liệu đã lên v2.0 (SRS v1.9)

Đối chiếu bằng máy giữa SRS v1.4 và v1.9: **không mã yêu cầu nào bị bỏ**, và trong toàn bộ
141 mã cũ chỉ đúng MỘT dòng đổi chữ (FR-KNW-901, và chỉ là câu mô tả phạm vi Phụ lục D).
Thêm 46 mã mới, toàn bộ thuộc Phase 2–5: làm sạch dữ liệu (FR-CLN), truy vấn & phân tích
(FR-QRY), báo cáo (FR-RPT), khai phá dữ liệu (FR-MIN) và Knowledge Pack mở rộng (FR-KNW-913…921).
**Phase 1 không đổi một chữ nào**, nên mọi thứ đã code vẫn đúng luật.

Ghi chú của bản v1.5 vẫn giữ nguyên giá trị: 113 mục cũ nguyên vẹn.
Thêm 28 mục cho hai phụ lục mới — Knowledge Pack (Phase 4) và Agent Pack (Phase 5, BYOK) —
đều là plugin, có ranh giới cứng là KHÔNG chạm lõi Phase 1–3. Mọi việc đã làm vẫn đúng luật.

STP mới có 86 test case (trước 70). Ba ca đáng chú ý cho phần đang làm:

| | | |
|---|---|---|
| ✅ | TC-AUTO-01 Ghi & phát macro có regex | phát 20/100 lần cho kết quả như làm tay; macro lưu ra đĩa đọc lại còn nguyên |
| ✅ | TC-AUTO-02 Macro đến EOF | dừng đúng cuối file, không lặp vô hạn (có bài riêng cho macro KHÔNG làm gì), hủy được |
| ✅ | TC-DOC-05 Clone tài liệu ra 2 pane | sửa ở nửa trái thì nửa phải đổi tức thì; hai nửa cuộn độc lập — kiểm bằng máy, hai đối chứng âm |
| ✅ | TC-CORE-13 Word wrap 3 chế độ trên dòng 50.000 ký tự | kiểm bằng máy trong `--self-test`: ba chế độ, ký hiệu wrap, caret đi theo hàng màn hình, không cắt chữ, đổi cỡ cửa sổ thì ngắt lại |
| ✅ | TC-IME-01 Telex ở đầu/giữa/cuối dòng, trước field CSV bọc ngoặc | kiểm bằng máy, 7/7 |
| ⛔ | TC-IME-02 Telex + multi-caret | mã đã viết (soạn ở caret chính, chốt xong nhân sang caret khác) nhưng **chưa kiểm được bằng máy** |
| ⛔ | TC-IME-03 Enter khi đang soạn trong ô Find | chưa kiểm |

---

### 3.2 Nền hiển thị sau khi chốt ADR-01

| | | |
|---|---|---|
| ✅ | `TextWindow` (lõi) | cắt theo biên dòng, quy đổi byte ↔ UTF-16, không quét cả cửa sổ mỗi lần đổi |
| ✅ | `WindowedTextView` (app) | thanh cuộn theo cả tài liệu, nạp lại cửa sổ khi cuộn ra ngoài, API theo offset byte |
| ✅ | `DocumentSearch` (lõi) | tìm/thay không dựng cả tài liệu — khớp thẳng trên mmap, hoặc quét cửa sổ 8 MB |

Đo trên app thật với file 500 MB: `phys_footprint` 34–40 MB (0,07× cỡ file, trần NFR 1,5×);
nhảy tới dòng 5.000.000, gõ ở dòng 3.000.000, tìm ra kết quả ở dòng 6.000.001 — đều đúng.

---

### 3.3 Phase 2 — đã bắt đầu

| | Yêu cầu | |
|---|---|---|
| ✅ | FR-CSV-401 Chế độ CSV-aware | tự nhận diện delimiter (phẩy/chấm phẩy/tab/gạch đứng), parser RFC 4180 sẵn có ở lõi; chế độ bật/tắt ở menu View, thanh trạng thái nói rõ **dấu phân tách** đã nhận |
| ✅ | FR-CSV-402 Tô màu theo cột | rainbow columns theo CHỈ SỐ CỘT LOGIC — field bọc ngoặc chứa dấu phẩy không làm lệch màu; cửa sổ dóng về đầu hàng an toàn. **Hàng tiêu đề dính** khi cuộn qua nó, cùng bảng màu với cột, có tooltip "Cột n: tên" |
| ✅ | FR-CSV-403 Table view | bảng ẢO HOÁ trên `CSVRowIndex` (chỉ mục thưa 1 mốc/64 hàng): 1 triệu hàng dựng chỉ mục 337 ms, tốn 122 KB, **chuyển chế độ ⌥⌘T p99 0,095 ms** (trần đặc tả 100 ms). Bấm tiêu đề = sắp xếp **chỉ hiển thị** (badge nói rõ), nút riêng mới ghi vào file — một bước undo. Cột `#` giữ số hàng trong FILE. Sửa ô ghi ngược có tự bọc ngoặc. Đo ở `scripts/run-csv-table-kpi.sh` |
| ✅ | FR-CSV-404/408 Menu ngữ cảnh trên tiêu đề | ẩn cột (KHÔNG đụng file, có dòng nhắc "Cột ẩn: …") · đổi tên tiêu đề · chèn cột trái/phải · xóa cột (hỏi lại) · kéo tiêu đề để hoán vị. Kéo bị khóa khi đang ẩn cột — lúc ấy vị trí hiển thị không dịch được sang chỉ số cột logic |
| ✅ | FR-CSV-405/406 Kiểm dữ liệu · Chuyển đổi | suy luận kiểu cột, panel lỗi bấm được; xuất TSV/JSON/XML/Markdown/SQL INSERT có xem trước |
| ✅ | FR-CLN-001 Chuẩn hóa theo cột | ngày hỗn tạp → ISO 8601, số Việt/Âu ↔ Anh-Mỹ (không qua `Double` nên số dài không mất chữ số), cắt khoảng trắng kể cả NBSP/zero-width, đổi hoa thường. **Không đoán**: ô mơ hồ được giữ nguyên và đánh dấu; quy ước chỉ hỏi khi dữ liệu không tự nói ra |
| ✅ | FR-CLN-002 Giá trị thiếu | danh sách chuỗi đại diện sửa được; điền giá trị mặc định · điền xuôi · điền ngược · xóa hàng — ô ở đầu/cuối cột không có gì để lấy thì để nguyên, không bịa |
| ✅ | FR-CLN-006 Bàn làm sạch (⇧⌘L) | danh mục phát hiện theo ngữ cảnh file, **một lượt quét cho mọi cột** (1 triệu ô: 0,85s release); mỗi nhóm có số ô + nút sửa, sheet xem trước 10 dòng trước→sau, áp là một bước undo, xong thì quét lại; báo cáo Markdown ra tab mới, kể cả phần CÒN LẠI |
| ✅ | FR-CLN-003 Data Profile | tab thứ hai trong Bàn làm sạch: kiểu, %null, distinct, min/max/mean/σ, hay gặp, giá trị bất thường — **một lượt quét, chỉ đọc, tất định** (băm FNV-1a chứ không dùng `Hasher` gieo hạt ngẫu nhiên). Không DuckDB: mọi thứ hồ sơ cần đều tính được bằng thuật toán cổ điển vài chục dòng. Bấm dòng → nhảy tới ô bất thường. Báo cáo kèm khối **Phương pháp** và nói rõ chỗ nào là ước lượng |
| ✅ | FR-CORE-013 Tự hoàn thành | gợi ý từ trong tài liệu + tên hàm/lớp từ Function List; khớp mờ có thưởng điểm cho khớp liên tiếp/đầu từ con/ứng viên ngắn; gõ không dấu vẫn ra chữ có dấu. Quét **1 MB quanh con nháy** chứ không cả file. Danh sách không cướp bàn phím và im lặng khi bộ gõ đang soạn dở. Ngưỡng ký tự và công tắc cấu hình được |
| ✅ | FR-FMT-504 Công cụ JSON | định dạng · thu gọn · sắp xếp khóa · kiểm cú pháp kèm dòng/cột và câu sửa được ("Dấu phẩy thừa trước dấu }"). **Không qua JSONSerialization** nên giữ nguyên thứ tự khóa và nguyên văn từng số (`1.0` không thành `1`). Tree navigator dùng chung Function List. **JSONPath (⌥⇧J)**: panel truy vấn với danh sách kết quả bấm được — mỗi dòng là số dòng · đường dẫn chuẩn hóa · giá trị, bấm thì nhảy tới và **bôi sáng đúng khoảng byte**. Viết được `$` `.ten` `['dia chi']` `[0]` `[-1]` `[*]` `[a:b:c]` `[0,2]` `..khoa` `..*` `[?(@.gia > x)]` `[?(@.co_san)]`; phần chưa làm (script `[(...)]`, `length()`, `=~`, `&&`) thì **báo lỗi có tên** chứ không lặng lẽ trả rỗng. Chỉ mục JSON phẳng giữ khoảng byte, quét **không đệ quy** (file lồng 20000 tầng không làm tràn ngăn xếp), nhớ tạm theo cặp buffer+revision. Xuất tập khớp ra tab mới, không đụng file gốc (NFR-QRY-03) |
| ✅ | FR-FMT-507 YAML/TOML/INI · **FR-CORE code folding** | lint YAML bắt khóa TRÙNG và Tab trong thụt lề. **Gấp khối (⌥⌘← / ⌥⌘→, gấp tất cả ⌥⇧⌘←) cho MỌI ngôn ngữ**, chọn cách tính theo ngôn ngữ: thụt lề (YAML, Python — dòng trắng ở giữa không cắt khối, ở cuối không thuộc khối) · mục `[…]` (TOML/INI, không lồng `[a.b]` vào `[a]`) · cấu trúc JSON (biên từ `JSONIndex`) · cặp thẻ (XML/HTML, dung thứ với file đang sửa dở, hiểu `>` trong thuộc tính và thẻ rỗng) · **cây cú pháp** (C, C++, Java, Go, Rust, JS, PHP… — không bảng luật, một khối là nút mở/đóng bằng cặp ngoặc khớp; dấu ngoặc trong CHUỖI và CHÚ THÍCH không tính, đếm byte sẽ gấp NHẦM CHỖ). Chú thích nhiều dòng cũng gấp được. Gấp là CÁCH NHÌN: tài liệu không bị chạm, phù hiệu `⋯` cuối dòng đầu, gõ khi đang gấp thì vùng gấp dời theo. **Và «fold theo cấp»** (⌥⌘1…⌥⌘8, tám cấp như Notepad++): cấp đếm theo SỐ VÙNG BAO chứ không theo độ sâu thụt lề — người dùng nói về cái cây họ thấy ở lề trái, không nói về dấu cách. Gấp cấp N trả về ĐÚNG cấp N và THAY THẾ trạng thái đang gấp, vì bấm cấp 1 rồi cấp 2 là đổi cách nhìn chứ không phải gấp thêm. Cấp sâu hơn tài liệu thì nói ra số cấp thật (§5bis-c) |
| ◐ | FR-FMT-505 Công cụ XML | định dạng · thu gọn · kiểm well-formed, **parser viết tay** nên giữ nguyên văn thuộc tính (`ten='Nguyễn'` không thành `ten="Nguyễn"`, `&amp;` không thành `&`) — thứ `XMLParser` của hệ thống không cho vì nó trả nội dung ĐÃ GIẢI MÃ. Lỗi gọi đúng tên cái sai bằng tiếng Việt kèm dòng/cột: "Thẻ `</c>` đóng cho `<b>`", "Thuộc tính `ten` viết hai lần", "2 thẻ gốc". **Nội dung hỗn hợp KHÔNG bị đụng vào** — thụt lại `<p>xin <b>chào</b></p>` là thêm chữ vào chính câu ấy. Gấp khối theo cặp thẻ, dung thứ với file đang sửa dở và hiểu `>` trong giá trị thuộc tính, chú thích, CDATA, thẻ rỗng HTML. **Validate DTD/XSD XONG 25/08/2026** (`XML: kiểm theo DTD/XSD…`): DTD qua `Foundation.XMLDocument`, XSD qua libxml2 HỆ THỐNG nạp lười — không vendor một byte. Nhảy tới lỗi đầu tiên; nói rõ đang kiểm theo GÌ và kèm phiên bản libxml2, vì đây là thư viện hệ thống nên hai máy có thể cho verdict khác nhau ở góc hiếm. DTD chỉ nhận loại NỘI TUYẾN: `<!DOCTYPE … SYSTEM "http://…">` sẽ khiến trình phân tích đi TẢI file ấy về — một lời gọi mạng do NỘI DUNG FILE quyết định, đúng cửa mà XXE khai thác |
| ✅ | FR-DOC-308 Folder as Workspace | sidebar ⌘0 nửa trên: cây thư mục đọc theo từng cấp (bỏ qua .git/node_modules/.build…), theo dõi thay đổi qua **FSEvents** và giữ nguyên thư mục đang mở khi đọc lại, lọc nhanh cả cây (gõ không dấu cũng ra), menu ngữ cảnh tạo/đổi tên/**xóa vào Thùng rác**/hiện trong Finder. Không thao tác nào ghi đè file có sẵn. **Thư mục sống qua lần khởi động**: phiên lưu kèm security-scoped bookmark, và một phiên chỉ có thư mục (chưa mở file nào) vẫn được khôi phục — thư mục biến mất thì nói ra, vì cây rỗng trông giống hệt thư mục không có file |
| ✅ | FR-DOC-306 Bản đồ tài liệu | dải hẹp 92pt bên phải (⌥⌘M): hình dáng tài liệu, dòng đã đánh dấu, khung tầm nhìn; bấm hoặc kéo để nhảy. Mô tả **CẢ file** chứ không chỉ cửa sổ đang mở, và làm được thế vì nó **không đọc nội dung** — chỉ tra chỉ mục dòng của piece tree cho vài trăm dòng đại diện, cộng vài chục byte đầu mỗi dòng để đo thụt lề. Chi phí bám theo SỐ HÀNG bản đồ, không bám cỡ file: **4,72 ms cho file 0,19 MB và 4,93 ms cho file 245 MB / 3 triệu dòng**. Dựng lại chỉ khi tài liệu hoặc bề cao đổi; dời khung tầm nhìn thì chạy theo mọi nhịp cuộn. Ba chỗ đặt sàn tối thiểu vì đúng tỉ lệ không có nghĩa là nhìn thấy được: nét mực ≥ 1 điểm ảnh vật lý, khung tầm nhìn ≥ 6 điểm, dấu dòng ≥ 2 điểm và tràn cả bề ngang |
| ✅ | FR-DOC-307 Function List | sidebar ⌘0: hàm/lớp/phương thức dựng từ cây tree-sitter cho 15 ngôn ngữ, mục cấp cao cho JSON/YAML/TOML/CSS; bấm để nhảy tới định nghĩa, ô lọc theo tên (gõ không dấu cũng ra), thụt lề theo mức lồng. Trần 16 MB thì nói thẳng là không dựng; HTML/XML trả rỗng thay vì liệt kê mọi thẻ |
| ✅ | FR-QRY-002 Filter theo cột | hàng ô lọc dưới tiêu đề Table view: `contains` (mặc định), `=` `!=` `>` `>=` `<` `<=`, khoảng `a..b`, danh sách `a\|b\|c`, `null` / `!null`; nhiều cột là AND; gõ KHÔNG DẤU vẫn ra chữ có dấu (kể cả Đ). Nhãn "N / tổng dòng khớp"; chỉ ảnh hưởng hiển thị; nút xuất tập khớp ra tab mới giữ nguyên byte thô |
| ◐ | NFR-QRY-01 Phản hồi gõ filter | **màn hình đầu tiên 3,5–5 ms** trên 1 triệu hàng × 20 cột (trần 300 ms) — phép lọc chạy hai nhịp, lô đầu hiện ngay rồi quét nốt ở nền. **Quét hết nhanh lên 2–3 lần** 24/08/2026: lọc chữ 2868 → **976 ms**, hai cột AND 2902 → **1028**, số 1074 → **727**. Ba việc: đi `forEachWindow` thay `forEachRow`, so ô thuần ASCII thẳng trên BYTE (không dựng `String`), và **nhớ tạm phép bỏ dấu theo giá trị** — cột đem ra lọc thường ít giá trị phân biệt, nên một triệu lượt gọi ICU thật ra chỉ hỏi đi hỏi lại vài câu. **Trường hợp xấu nhất vẫn chưa đạt:** hàng khớp duy nhất ở cuối bảng mất 968 → **583 ms**, nhưng sàn quét CSV đo được là 556 ms (PoC-G) nên nó chỉ còn cách sàn 5%. Đường ra còn lại: chỉ mục cột hoặc quét song song — thuộc tầng Workbench (FR-QRY-001) |
| ✅ | NFR-CLN-01 Hiệu năng profile | **4,85 s** cho 1 triệu hàng × 20 cột (trần 10 s), `scripts/run-clean-kpi.sh`. Bản đầu 10,01 s — sát trần và trượt; chuyển đường đọc sang byte thì còn một nửa. Con số 17 s ghi trước đó là NGOẠI SUY từ bảng nhỏ và sai gần hai lần so với phép đo thật |
| ✅ | FR-CLN-005 Cleaning Recipe | lưu các bước đã áp thành JSON (schema có version, khóa đọc được bằng mắt, từ chối file của bản mới hơn); mở lại, xem/bật-tắt từng bước rồi chạy — **cột tìm theo TÊN** nên file đổi bố cục không làm công thức chạy nhầm cột, bước không tìm thấy cột thì bỏ qua và nói trước. Cả công thức là một bước undo, có báo cáo. Batch cả thư mục và CLI `geditor --recipe … [--out/--overwrite/--dry-run]` — **mặc định không ghi đè**, kết quả ra «tên-sach.csv» |

---

## 4. Phase 2 / Phase 3 — đã làm thêm

| | Yêu cầu | |
|---|---|---|
| ✅ | FR-FMT-502 Ngôn ngữ tự định nghĩa | bộ quét từ vựng khai bằng JSON trong `grammars/`, KHÔNG dùng tree-sitter: bắt người dùng viết grammar tree-sitter cho định dạng nội bộ của công ty họ là đòi hỏi một trình biên dịch và hiểu biết về LR parsing. Ngôn ngữ dựng sẵn thắng khi trùng đuôi file. Nói thẳng cái nó không làm: không hiểu cấu trúc lồng nhau, nên gấp khối và Function List vẫn thuộc về ngôn ngữ dựng sẵn |
| ✅ | FR-FMT-506 Markdown preview | `NSAttributedString(markdown:)` của hệ thống, **không WebView** — nạp WebKit kéo cả một engine trình duyệt vào tiến trình, đúng thứ ADR-08 đang gỡ khỏi đường khởi động. Giới hạn nói thẳng ở chân cửa sổ: chưa dựng bảng, chưa tô màu khối mã. Trần 4 MB |
| ✅ | FR-FMT-508 Chế độ Log | quét BYTE chứ không regex: file log mở ở cỡ GB và chế độ này chạy trên mọi dòng đang hiện. Chỉ soi 120 byte ĐẦU dòng — quét cả dòng thì một dòng nhắc tới chữ "error" bị tô đỏ và cả file hoá ra đỏ rực. Lọc theo mức ra tab mới, dòng stack trace đi THEO dòng lỗi sinh ra nó |
| ✅ | FR-AUTO-603 Scripting JavaScript | `JavaScriptCore` của hệ thống, nạp lười. API cố ý HẸP (`doc.text`, `doc.selection`, `doc.replace`, `doc.log`) — không phải hàng rào an ninh mà là hàng rào thiết kế: mở rộng về sau thì dễ, thu hẹp thì phá script người dùng đã viết. Chạy ở luồng nền vì không API công khai nào ngắt được một `JSContext`; quá hạn thì bỏ kết quả và **nói ra** rằng luồng kia vẫn ăn một lõi CPU |
| ✅ | FR-AUTO-604 Lọc qua lệnh ngoài | **không qua shell** — chạy thẳng qua `/usr/bin/env` với mảng đối số, nên dấu `;` trong đối số là dấu chấm phẩy chứ không phải lệnh thứ hai. Có hạn giờ và trần cỡ đầu ra. Đọc stdout ở luồng khác trong lúc ghi stdin, nếu không thì bế tắc với đầu vào > 64 KB. **Chỉ bản tải trực tiếp**; bản App Store nói rõ vì sao không |
| ✅ | FR-PLUG-701 · FR-PLUG-705 Gói mở rộng | một gói = MỘT file JSON chứa script + theme + ngôn ngữ tự định nghĩa. Không dùng định dạng nén: nén đòi giải nén ra "đâu đó", và đó là chỗ mọi lỗi của trình cài đặt sinh ra (`../..` trong tên mục, symlink trỏ ra ngoài). Cài là chép file, gỡ là xoá file, danh sách gói suy ra TỪ ĐĨA — không giữ sổ đăng ký, vì người dùng xoá tay một file trong Finder thì một cuốn sổ nói khác đi là cuốn sổ nói dối. Mọi file mang tiền tố tên gói nên hai gói không nuốt nhau. Tên chứa `../` bị TỪ CHỐI và không ghi gì cả |
| ✅ | FR-AUTO-602 Macro trên cả thư mục | dùng lại `MacroRunner`, không có bản hiện thực thứ hai. Mặc định KHÔNG ghi đè, hỏi lại kèm SỐ FILE. Quét thư mục không đệ quy, và bỏ file đã mang hậu tố kết quả |
| ✅ | FR-AUTO-606 Services · AppleScript | `Services ▸ Mở trong GEditor` cho văn bản và file (chạy ở cả hai kênh — đi qua pasteboard, không đòi quyền nào sandbox cấm). AppleScript qua `.sdef`: `document text` (đọc/ghi, một bước hoàn tác), `selected text`, `document path`. Cố ý HẸP — script cần DỮ LIỆU, không cần giả làm người dùng bấm menu |

---

## 4bis. Còn lại — và vì sao

Các mục dưới đây **không phải quên**: mỗi mục vướng một quyết định chưa chốt, và chốt nó là việc
của người quyết định phạm vi sản phẩm chứ không phải của người viết mã.

**Cập nhật 26/08/2026:** ba trong bốn mục dưới đã khép (FR-CSV-407, FR-FMT-505, FR-PLUG-702/703/704);
còn **một** mục treo là FR-DOC-305 hướng (B). Ba quyết định chặn MỚI — DuckDB ở phạm vi rộng,
WKWebView cho Mermaid, và crash reporter — nằm ở `docs/ke-hoach-hoan-thien-v2.2.md` §1.

| | Yêu cầu | Vướng ở đâu |
|---|---|---|
| ✅ | FR-CSV-407 Truy vấn SQL | **XONG, và ĐỔI ENGINE 26/08/2026.** Anh chốt bỏ hẳn tập con SQL tự viết, chuyển sang **DuckDB** (`docs/adr/ADR-14-duckdb-va-nap-luoi.md` §3) — ADR-11 bị thay thế. `CSVQuery` + `CSVQueryParser` + `CSVQueryRunner` (1.240 dòng) và 48 bài kiểm của chúng đã bị xoá; thay bằng `CSVQueryEngine` + lớp bọc `DuckDB` với 29 bài kiểm mới. **Được:** `JOIN` · subquery · `DISTINCT` · `HAVING` · `IN` · `LIKE` · `BETWEEN` — bảy thứ engine cũ từ chối 7/7 — cộng suy kiểu cột (mở đường cho rule `range` của FR-DQR-001) và `NULL` phân biệt được với chuỗi rỗng. **Đã trả xong khoản mất lớn nhất:** `DuckDBErrorText` dịch bốn họ lỗi thật của DuckDB sang tiếng Việt (giữ tên cột, danh sách cột gợi ý, khối `LINE …` kèm dấu mũ); họ lỗi lạ đi qua NGUYÊN VĂN kèm nhãn "chưa có bản dịch" thay vì đoán. **Còn mất:** `LIMIT 10` từ 8 ms lên 86 ms, dòng "quét N hàng" ở panel, tên cột gộp đổi thành `count_star()`, truy vấn trên buffer ĐANG SỬA phải chép ra file tạm (trần 256 MB, nói ra khi vượt), và tính năng nay VẮNG nếu thiếu dylib. Chỉ-đọc (NFR-QRY-03) nay cần hai lớp vì DuckDB ghi được file bằng `COPY` — có bài kiểm chạy `COPY t TO` rồi kiểm rằng file ấy KHÔNG tồn tại. Panel giao diện giữ nguyên |
| ✅ | FR-FMT-505 Validate XSD/DTD | **XONG.** Tiền đề của quyết định cũ đã SAI: không cần vendor gì (`scripts/run-poc-i.sh`). DTD qua `Foundation.XMLDocument` (không thêm phụ thuộc); XSD qua libxml2 **HỆ THỐNG** nạp lười bằng `dlopen` (0,07 ms — đã nằm trong dyld shared cache). Bundle không to thêm, ADR-08 không đụng tới, đường ký không đổi, hardened runtime không chặn (đã đo trong bundle sandbox đã ký). **Nạp lười để hỏng MỀM:** ngày Apple bỏ libxml2, tính năng nói "máy này không có" chứ app không chết. Đổi sang libxml2 vendor về sau chỉ cần thêm đường dẫn vào `XMLSchemaValidator.libraryCandidates` — không chạm chỗ gọi nào. 10 test lõi. **Rủi ro còn lại:** phiên bản libxml2 theo bản macOS (hiện 2.9.13), nên verdict có thể khác nhau ở góc hiếm của XSD |
| ✅ | FR-PLUG-702/703/704 Plugin native, XPC, Manager | **XONG.** Anh chốt 24/08/2026: plugin chỉ ở bản tải trực tiếp (`docs/adr/ADR-12-plugin-native.md`). Kiến trúc theo ADR-12 phương án C — plugin chạy ở **tiến trình riêng** (`geditor-plugin-host`), app chính giữ nguyên entitlement, `disable-library-validation` chỉ nằm ở tiến trình phụ. **API cố ý HẸP** (bài học FR-AUTO-603): một plugin là một phép biến đổi văn bản có tên, đúng hai hàm C — không đọc file, không mạng, không hỏi trạng thái app, không vẽ giao diện. Khung thông điệp dùng tiền tố ĐỘ DÀI vì ống không có biên thông điệp và nội dung là văn bản người dùng. Cài là chép file, gỡ là xoá file, danh sách suy ra TỪ ĐĨA (SEC-03: cài từ đâu, gỡ thế nào — hiện ngay trên menu). Chạy plugin là MỘT bước hoàn tác. 11 test lõi + 6 bài tự kiểm dựng plugin C THẬT bằng `clang` rồi nạp qua tiến trình thật. **Đi lệch một chỗ so với câu chữ FR-PLUG-703:** dùng tiến trình con qua ống chứ không `NSXPCConnection` — đó là hình dạng PoC-H đã ĐO (0,010 ms), và XPC service thật phải nằm trong `Contents/XPCServices` do launchd khởi động nên không bài kiểm tự động nào chạm tới được |
| ◐ | FR-DOC-305 macOS Versions | **Hướng (A) của PoC-J đã làm 25/08/2026** — `Bản đã lưu…`: kho phiên bản CỦA HỆ ĐIỀU HÀNH qua `NSFileVersion`, bảng duyệt của GEditor. Mỗi lần lưu ghi lại bản CŨ trước khi đè (thứ tự bắt buộc — gọi sau thì lịch sử toàn bản mới). Khôi phục là **một sửa đổi bình thường trên buffer**, nên ⌘Z về lại được và file trên đĩa chỉ đổi khi người dùng thật sự lưu — ghi thẳng ra đĩa thì "khôi phục" thành thao tác không hoàn tác được, trên chính thứ tính năng này sinh ra để cứu. Trần **64 MB**: ghi một bản là chép cả file, và với file hàng GB thì mỗi lần ⌘S là hàng GB đi vào đĩa mà người dùng không yêu cầu. Nội dung trả về là BYTE nên file bảng mã cũ và file UTF-8 hỏng đi qua nguyên vẹn. 6 test lõi + 1 bài tự kiểm. **VẪN LÀ ◐, cố ý:** đây KHÔNG phải giao diện lịch sử nguyên bản của macOS (`NSDocument.browseVersions`) mà câu chữ FR đòi — hướng (B) vẫn để ngỏ, giá đã đo ở PoC-J |

---

## 4ter. PHẠM VI v1.0 — CHỐT 28/08/2026: bỏ Agent Pack và Python Pack

**Anh Công chốt: hoàn thành 15 mã còn lại, KHÔNG làm `FR-AGT` (10) và `FR-PY` (9).**

Đây là quyết định `docs/ke-hoach-hoan-thien-v2.2.md` §5 đã đề nghị và để ngỏ từ 26/08, và nó đáng
được ghi thành văn chứ không để lơ lửng — *"không làm cũng là một quyết định hợp lệ, nhưng nó
phải là quyết định được NÓI RA, chứ không phải một mục cứ lùi mãi trong bảng"*.

**Lý do đứng vững:** hai cụm ấy không phải phần còn thiếu của một trình soạn thảo — chúng là hai
sản phẩm riêng dùng chung cái vỏ (một LLM agent, một runtime Python). Chính SRS xếp cả 19 mã ở
**Phase 5–6 và toàn bộ P2**. Phát hành v1.0 mà không có chúng cho ra một sản phẩm đứng vững một
mình, có người dùng thật, và có phản hồi thật để định hình chúng — nếu còn làm.

**Hệ quả với mẫu số, phải nói rõ để không ai đọc nhầm về sau:** bảng §5 vẫn đếm trên **167 FR**
của SRS v2.2, nên `FR-AGT` và `FR-PY` vẫn hiện ⛔ ở đó. Chúng ⛔ vì **ngoài phạm vi v1.0**, không
phải vì bị quên. Mẫu số của v1.0 là **148 FR** (167 − 19), và trên mẫu số ấy hiện là **132/148**.

**Còn lại 15 mã**, tất cả Phase 4 — cập nhật: **11**, và **cụm FR-MMD nay KHÉP TRỌN 8/8**:

| | Mã | |
|---|---|---|
| ~~Mermaid~~ | ~~MMD-004~~ · ~~MMD-008~~ | **CỤM KHÉP 28/08/2026** — 004 (P1 cuối cùng của cả sản phẩm) và 008 (tách/nhúng + tam giác chuyển đổi) |
| ~~Làm sạch~~ | ~~CLN-004~~ | ✅ **xong 28/08/2026** |
| ~~Khai phá~~ | ~~MIN-006~~ | ✅ **xong 28/08/2026** |
| Knowledge Pack | ~~903~~/~~904~~/~~906~~/~~907~~/~~908~~/~~909~~/~~910~~/**911 ⊘**/~~912~~/~~915~~/~~917~~ | 11 mã — **cả 10 mã còn mã nguồn đều xong 28/08** (903, 904, 906…910, 912, 915, 917); **911 THAY THẾ bởi ADR-15** (Pack nằm trong lõi, không đóng gói plugin) |

Cộng `FR-DOC-305` ◐ — vướng một quyết định phạm vi khác, xem §4bis.

---

## 4quater. Mở được ảnh · PDF · Office · file nén — thêm 30/08/2026

**Ngoài bộ 167 FR của SRS v2.2.** Anh nêu 30/08: *"App không view được ảnh, pdf, word, excel,
pptx nên khá bất tiện trong sử dụng"*, và xin mang cả **xem lẫn sửa** từ dự án
`mobiluck-reader` sang. Đây là trạng thái sau ba lượt làm.

### Đã chạy được

| Loại | Mở ra cái gì | Sửa được gì |
|---|---|---|
| **Ảnh** | khung riêng: phóng theo thang cố định, vừa khung, xoay, chép, ⌘+lăn | — |
| **PDF** | PDFKit: trang thu nhỏ, tìm không dấu, chọn/chép chữ | **bôi vàng · gạch chân · ghi chú**, lưu ra BẢN SAO |
| **Excel** | thẳng vào **bảng CSV** của sản phẩm — dùng được cả Query Workbench, làm sạch, biểu đồ, thẻ chất lượng | ✅ **sửa ô và ⌘S ghi ngược vào chính tệp** |
| **Word** | **TRANG TÀI LIỆU dựng ra** (View) · Markdown trong khung soạn thảo (Code) | ✅ **sửa đoạn và ⌘S ghi ngược vào chính tệp** |
| **PowerPoint** | **TRANG SLIDE dựng ra** (View) · dàn ý Markdown kèm ghi chú (Code, và nút «Dàn ý») | ✅ **sửa đoạn và ⌘S ghi ngược vào chính tệp** |
| **File nén** | ZIP · TAR · GZ · XZ tự đọc; **7z · RAR · cab · lha · iso · xar · cpio · ar · bz2 · .Z · .lz** qua libarchive nạp từ nguồn — **cả hai bản, kể cả App Store** | — |

### Chế độ View của Word và PowerPoint — bản dựng trang, 04–05/09/2026

Bản đầu dùng **QuickLook** (chính bộ dựng Finder chạy khi bấm Space). Trung thực, nhưng là hộp
đen **không có API phóng và không có API vừa-bề-ngang**: trên cửa sổ rộng, một trang A4 chiếm
chưa tới một phần ba bề ngang. Anh Công báo đúng điều đó rồi chốt hướng: *"chúng ta không dùng
QuickLook"*.

Nay sản phẩm **tự dựng trang**, theo đúng ranh giới ADR-0001 của Moffice — lõi trả **dữ liệu**,
tầng giao diện đổi thành đối tượng của macOS:

| Tầng | Việc |
|---|---|
| `DOCXLayout` (lõi) | `.docx` → mô hình trang: run có font/cỡ/màu, đoạn có căn lề/giãn dòng/cấp, bảng có gộp ô + tô nền, **ảnh là BYTE**, khổ giấy + lề, **từng PHẦN một cặp đầu/chân trang**, trường `PAGE`/`NUMPAGES` |
| `PPTXLayout` (lõi) | `.pptx` → hình khối có toạ độ: thừa kế khung slide→layout→master, màu theo `theme1.xml`, cỡ chữ mặc định theo cấp ở `p:txStyles`, nhóm hình, xoay |
| `DocumentPageBuilder` | mô hình → `NSAttributedString` (NSTextTable, NSTextAttachment) |
| `DocumentTextPageSource` | **phân trang** — TextKit không biết "trang", chỉ biết ô chứa; trang = một ô chứa bằng vùng chữ |
| `DocumentPagesView` | thẻ giấy trắng trên nền xám, cuộn liên tục, **vừa bề ngang mặc định**, phóng, tìm, chọn chữ |

**Excel là ngoại lệ có chủ ý:** View của nó vẫn là bảng tính sửa được — một bảng tính không có
khổ giấy cho tới lúc in, và lưới ô vốn đã chiếm hết bề ngang.

Người dùng chạm tới: `View | Code · Trang 12/363 · Vừa ngang · Vừa khung · − · +`, ô **Tìm**
(⌘F, bỏ dấu bỏ hoa thường, tô vàng, đếm chỗ khớp), **bôi đen chữ + ⌘C/⌘A**, Page Up/Down/Home/End.

#### Lỗi đắt nhất, và bốn lần bộ đo tự nói dối

Bản đầu cho **cả vùng xem trắng trơn** trong khi mọi phép so đều xanh: `draw` chạy đủ, số trang
đúng, bề ngang đúng, xuất một tờ ra PDF thì đủ chữ đủ màu. Nguyên nhân: `wantsLayer` ép cả cây
bên dưới thành layer-backed, và tờ canvas cao hơn 30.000 pt **vượt giới hạn texture của
CoreAnimation** — nó bỏ trắng chứ không báo lỗi. Nay có `layerBackedAnywhereForSelfTest` canh.

Bộ đo dựng ra để bắt lỗi ấy — **tỉ lệ điểm ảnh có mực trên tờ giấy** — tự nói dối bốn lần:
lấy mẫu ở góc trên trái (báo "trắng" cho ba cuốn có bìa căn giữa) · dải đo chân trang liếm vào
vùng chữ (đối chứng âm ra 5‰) · ngưỡng của cả trang quá cao cho một dòng «— 2 —» (đo được 1711
điểm trên 2 triệu = 0,85‰) · và hỏi kích thước trước khi cửa sổ qua lượt bố cục (chỉ đỏ ở bản
bundle).

#### Đo độ trung thực: số trang so với BẢN IN

Thư mục tài liệu của người dùng có cả `.docx` lẫn PDF đã đem in của cùng cuốn sách — sự thật gần
nhất cho câu *"bản dựng cách bản in bao xa"*. `--doc-sweep` in bảng đối chiếu ấy (loại bản
`preview` vì nó là bản trích). **10 cặp, lệch tuyệt đối trung bình 4,7%.**

Hai chỗ sửa nhờ chính phép đo này, cả hai đều có lý do chứ không phải chỉnh cho vừa số:

- **Lề trong ô bảng** đặt 3 pt cả bốn cạnh, trong khi mặc định của Word là trái/phải 5,4 pt và
  **trên/dưới bằng 0** → 6 pt thừa mỗi hàng. Sách toán 308 bảng dài hơn bản in 17%; sách ít bảng
  chỉ lệch 1,5%. Sau khi sửa: 13,6% → 11,8% (trên tập chưa loại bản trích).
- **`usesFontLeading`**: Word tính giãn dòng đơn theo phần trên+dưới của chữ, không cộng
  `lineGap` của bảng OS/2. Tắt nó: 5,5% → 4,7%.

#### Nói thẳng phần chưa dựng lại

Ảnh **neo tự do** hiện ra như ảnh nằm trong dòng (không cho chữ chạy quanh) — có bài kiểm canh
để nó không BIẾN MẤT · ghi chú chân trang, biểu đồ, SmartArt chưa vẽ · đầu/chân trang chỉ lấy
loại `default` · `.emf`/`.wmf` bỏ qua vì macOS không giải mã được. Đo trên 61 tệp thật của người
dùng: **không tệp nào** dùng `wp:anchor`, ghi chú chân trang, biểu đồ hay SmartArt.

Nền: `ZipArchive` (mmap · ZIP64 · CRC · trần chống zip bomb · chặn Zip Slip) và `MediaKind`
(nhận loại bằng **nội dung**, không bằng đuôi tệp). Một khối mã mở ra hai tính năng — `.docx`,
`.xlsx`, `.pptx` đều LÀ file ZIP.

`PDFKit` đã khai vào `LINKED_FRAMEWORKS_ALLOWED` kèm giá đo được: **+0,31 ms trên sàn nhiễu
8,3 ms** (`scripts/run-poc-n.sh`, giữ nguyên phương pháp PoC-L).

### Ghi ngược Excel — ✅ xong

`ZipWriter` (thay một mục, **chép nguyên byte đã nén** phần còn lại) + `XLSXWriter` (sửa đúng ô
đã đổi trong XML gốc, giữ nguyên từng byte khác).

Ba chốt an toàn, theo đúng thứ tự và không được đảo:

1. So ở mức **LƯỚI** chứ không mức văn bản CSV — hai chuỗi CSV khác nhau chỉ vì cách trích dẫn
   thì giá trị vẫn y hệt, và so văn bản sẽ "sửa" cả nghìn ô không ai đụng.
2. Ghi ra tệp **TẠM**, mở lại bằng chính bộ đọc, đòi mọi ô vừa sửa mang đúng giá trị mới.
3. Chỉ khi ấy mới thay tệp gốc, bằng `replaceItemAt` nguyên tử. Ghi thẳng rồi kiểm sau thì lúc
   phát hiện sai đã muộn — bản gốc không còn.

Bài kiểm đóng vòng tròn **ra ngoài**: LibreOffice dựng tệp → ta đọc → sửa → ta ghi → **LibreOffice
đọc lại**. Tự đọc lại bằng bộ đọc của mình chỉ chứng minh hai nửa của ta khớp nhau.

Giới hạn còn lại của Excel, nói thẳng: **thêm hoặc xoá HÀNG thì từ chối** (`shapeChanged`), vì
ánh xạ hàng mới về XML gốc là một bài khác. Sửa giá trị ô thì đủ cả ba kiểu — chữ, số, ô trống.

### Ghi ngược Word — ✅ xong

`DOCXWriter`, cùng khuôn với `XLSXWriter`: sửa đúng `<w:p>` trong `document.xml`, chép nguyên
byte phần còn lại, ghi ra tệp tạm → đọc lại đối chứng → thay tệp gốc nguyên tử.

Bộ đọc nay trả kèm **ánh xạ dòng Markdown → `<w:p>`** và độ dài tiền tố (`"## "`, `"- "`,
`"> "`). Không có ánh xạ ấy thì lúc lưu phải đoán lại từ văn bản xem dòng nào ứng với đoạn nào
— mà một đoạn thường bắt đầu bằng `- ` là chuyện có thật, và đoán sẽ đúng gần hết rồi ghi nhầm
ở phần còn lại.

**Cái giá phải nói ra:** một đoạn Word gồm nhiều `<w:r>` mang định dạng khác nhau, và khi người
dùng sửa cả đoạn thì không có cách nào biết phần nào của câu MỚI đáng in đậm — thông tin ấy
không tồn tại. Luật: **chữ mới vào run đầu tiên, các run còn lại làm rỗng.** Giữ được thuộc
tính đoạn (`<w:pPr>`) và định dạng run đầu; mất định dạng khác nhau GIỮA các run trong đúng
đoạn ấy. Đoạn không sửa thì không bị đụng một byte nào.

**Từ chối kèm lý do** cho hai ca: thêm/xoá DÒNG (`lineCountChanged`), và sửa HÀNG BẢNG — hàng
bảng không ứng với `<w:p>` nào vì một hàng gồm nhiều ô, mỗi ô lại nhiều đoạn.

### Ghi ngược PowerPoint — ✅ xong

`PPTXWriter`, cùng khuôn với `DOCXWriter`, khác đúng một điểm và điểm ấy quan trọng: PowerPoint
để **mỗi slide trong một tệp XML riêng**, ghi chú người trình bày ở tệp thứ ba. Nên một lượt ghi
thay NHIỀU mục trong file nén, và phải thay chúng trong **cùng một lượt** — ghi từng lượt thì
một lỗi ở tệp thứ hai để lại bản trình chiếu đã sửa nửa vời.

Từ chối kèm lý do: sửa dòng tiêu đề của slide **không có chữ nào** (dòng ấy do GEditor sinh ra,
không ứng với `<a:p>` nào).

### Thêm/xoá hàng Excel và sửa ô bảng Word — ✅ xong 30/08

| Ca | Hiện tại |
|---|---|
| **Thêm/xoá hàng ở CUỐI bảng Excel** | ✅ ghi ngược được |
| **Sửa ô trong bảng Word** | ✅ ghi ngược được, và chỉ ghi ĐÚNG ô đã đổi |
| **Chèn/xoá hàng ở GIỮA bảng Excel** | ✅ ghi ngược được, có dịch lại tham chiếu A1 |
| **Thêm/xoá dòng trong Word · PowerPoint** | ✅ ghi ngược được, đoạn mới thừa kế kiểu hàng xóm |
| Thêm/xoá **cột** trong bảng Word | ⛔ từ chối kèm lý do |
| Định dạng khác nhau **giữa các run** trong đoạn vừa sửa | mất; đoạn không sửa thì nguyên vẹn |

**Chèn/xoá ở GIỮA đi qua `A1Reference` + `XLSXRowEditor`.** Số hiệu hàng không chỉ nằm ở thuộc
tính `r`: công thức (`=A5`), vùng ô gộp, định dạng có điều kiện, xác thực dữ liệu, vùng lọc,
liên kết, vùng dữ liệu — tất cả tham chiếu theo A1. Bỏ sót một chỗ là **làm hỏng tệp im lặng**:
tệp vẫn mở được, chỉ vài công thức trỏ sai.

Hai điểm đáng nhớ của bộ dịch:

- **`$` KHÔNG miễn nhiễm với chèn hàng.** `$A$5` nghĩa là "đừng đổi khi CHÉP công thức đi chỗ
  khác", không phải "đừng đổi khi có hàng chèn vào trên". Excel dịch cả hai loại.
- **Ô bị xoá thành `#REF!`**, đúng như Excel — trỏ nhầm sang hàng khác mới là kiểu hỏng im lặng.

**Cổng an toàn đứng TRƯỚC phép sửa.** `XLSXRowEditor.checkSafe` quét tệp tìm cấu trúc mang tham
chiếu theo hàng mà bộ dịch chưa xử lý (`sortState`, `sparkline`, `protectedRange`, bảng
`tableParts`, tên đã đặt trỏ vào sheet ấy) và **từ chối cả lượt ghi** kèm tên chỗ vướng. Không
có cổng này thì một cấu trúc chưa xử lý sẽ lặng lẽ giữ số hiệu cũ.

### TAR và các bản nén của nó — ✅ xong 31/08

`TarArchive` đọc `.tar`, `.tar.gz`, `.tgz`, `.tar.xz`, `.gz`, `.xz` — **không cần thư viện
ngoài nào**. Định dạng TAR là những khối 512 byte với header văn bản, và hai bộ giải nén đi kèm
đều nằm trong `Compression` của hệ điều hành (`COMPRESSION_ZLIB` cho phần DEFLATE của gzip,
`COMPRESSION_LZMA` cho xz).

Ba chỗ dễ sai, mỗi chỗ một bài kiểm:

- **Vỏ gzip có độ dài THAY ĐỔI.** `COMPRESSION_ZLIB` của Apple là DEFLATE trần; vỏ gzip mang
  tên tệp, chú thích, CRC header đều tuỳ chọn. Nhảy một số byte cố định là hỏng với đúng những
  tệp có ghi tên gốc — tức phần lớn tệp do `gzip` tạo ra.
- **Tên dài đi qua header pax, không phải kiểu `L` của GNU.** `tar` của macOS (bsdtar) dùng
  pax; bỏ qua nó thì mọi tên trên 100 ký tự bị cắt cụt ở đúng ký tự thứ 100 — và cắt cụt trông
  y như một tên thật.
- **Tên từ header mở rộng là đường dẫn TRỌN VẸN.** Ghép thêm trường `prefix` vào nó cho ra một
  đường dẫn lặp chính nó, và lặp vẫn trông như đường dẫn thật.

Nhận ra TAR bằng **checksum của khối header đầu**, không chỉ bằng chữ ký `ustar` — TAR cổ (v7)
không có chữ ký nào.

**BZIP2 từ chối kèm lý do:** `Compression` không có bzip2, và trả về một kho rỗng sẽ khiến
người dùng tưởng tệp hỏng.

### 7z · RAR và bảy định dạng khác — ✅ libarchive nạp từ nguồn, chạy ở CẢ bản App Store

**Đây là một quyết định đã ĐẢO, và cả hai lần đều có lý do ghi lại.**

Lần đầu chọn gọi `/usr/bin/tar` như tiến trình con, vì vendor libarchive nghĩa là hai thư viện
C phải theo dõi bản vá bảo mật, mãi mãi. Nhưng đường ấy chỉ chạy ở bản tải trực tiếp: bản App
Store nằm trong sandbox, và một ứng dụng sinh tiến trình con để đọc file nén là thứ người duyệt
sẽ hỏi. Khi phát hành App Store thành việc làm TRƯỚC và phải đủ tính năng, phương án ấy hết
đường.

Nay: **libarchive 3.7.7 + liblzma 5.6.3 nạp từ nguồn**, liên kết TĨNH (`scripts/vendor-libarchive.sh`).
Hai bản dựng có cùng một danh sách định dạng, và `Distribution.current` biến mất khỏi đường đọc
file nén.

**Một lý do từng ghi ở mục này là SAI, và nay sửa.** Bản trước viết rằng loại
`/usr/lib/libarchive.2.dylib` vì "nó không nằm trong SDK". SDK **có** `libarchive.tbd` — link
được ngay. Cái nó không có là **`archive.h`**. Không header nghĩa là không có hợp đồng API:
muốn gọi thì phải tự khai nguyên mẫu, tức tự đoán một ABI Apple chưa từng hứa giữ. Kết luận cũ
đúng, nhưng đúng vì lý do khác — và đó cũng đúng là lý do `PCRE2` không dùng `libpcre2-8.dylib`.

`zlib`, `bzip2`, `iconv` thì **không** vendor: `zlib.h`, `bzlib.h`, `iconv.h` nằm sẵn trong SDK,
tức Apple có khai chúng là API công khai. Chỉ cần `-lz -lbz2 -liconv`.

**Chỉ nạp nửa ĐỌC, và bỏ ba nhóm mã có chủ ý:**

| Bỏ | Vì |
|---|---|
| `archive_write*` | GEditor không tạo kho nén — bỏ nguyên nửa thư viện, và bỏ theo cả mã NÉN của liblzma (chỉ 50/85 đơn vị được nạp) |
| bộ lọc `program` + `filter_fork_posix` + `archive_cmdline` | chúng **sinh tiến trình con** để giải nén; đó chính là thứ cả lượt vendor này sinh ra để bỏ đi |
| `format_raw` | nó nhận BẤT KỲ chuỗi byte nào là kho có đúng một mục — tệp hỏng sẽ mở ra thành "kho hợp lệ" thay vì báo lỗi |

Không dùng `filter_all`/`format_all` nữa vì chúng đăng ký cả nhóm hai; `LibArchiveReader` gọi
thẳng từng hàm cần, nên danh sách bật là danh sách **đọc được**.

**`iconv` KHÔNG phải tuỳ chọn.** Lượt sinh `config.h` đầu đặt `ENABLE_ICONV=OFF` cho gọn, và
mọi bài kiểm vẫn xanh trừ đúng một bài: tên tệp tiếng Việt trong kho `.7z` đọc ra chuỗi RỖNG.

**`setlocale(LC_CTYPE, "UTF-8")` cũng không bỏ được.** libarchive chuyển tên tệp sang bảng mã
của locale hiện hành; ứng dụng Cocoa không gọi `setlocale` nên locale là "C", và khi ấy cả ba
hàm lấy tên (`pathname`, `pathname_utf8`, `pathname_w`) đều trả NULL. `bsdtar` in tên đúng
chính vì nó gọi `setlocale` lúc khởi động.

**Cổng canh đường spawn** nằm ở `scripts/check-core-no-ui.sh`, và nó canh ở tầng KÝ HIỆU chứ
không `grep` mã nguồn: `grep` bắt nhầm `filter_gzip.c` và `filter_xz.c` vì chúng nhắc tên hàm
trong một nhánh `#else` không bao giờ được biên dịch. Cổng thật kiểm rằng không object nào
trong 45 object đã dựng tham chiếu `fork`/`exec`/`spawn`/`system`/`popen`.

### Bộ kiểm end-to-end — `scripts/run-office-e2e.sh`

Ba bộ kiểm hiện có nhìn ba tầng khác nhau, và **không bộ nào đi hết đường của người dùng**:

| Bộ | Nhìn gì | Thiếu gì |
|---|---|---|
| `swift test` (2.399) | lõi, không cần cửa sổ | không đi qua app |
| `run-self-test.sh` (275) | trong app, nhưng phần lớn gọi thẳng bộ đọc | không đóng/mở lại tab |
| **`run-office-e2e.sh`** | **mở → sửa → ⌘S → ĐÓNG TAB → MỞ LẠI → LibreOffice đọc lại** | — |

Vế "đóng tab rồi mở lại" bắt đúng loại lỗi hay xảy ra nhất ở tầng nối: ghi thành công vào bộ
nhớ mà chưa xuống đĩa, hoặc xuống đĩa rồi mà lần mở sau vẫn đọc bản cũ — cả hai đều XANH với
mọi bài kiểm chỉ nhìn một nửa. Vế "LibreOffice đọc lại" là đối chứng NGOÀI: tự đọc lại bằng bộ
đọc của chính mình xanh y hệt khi cả hai nửa cùng sai.

**Đã xác nhận ĐỎ ĐƯỢC hai lần:** bỏ `replaceItemAt` trong `XLSXWriter.writeInPlace` → E2E đỏ
đúng 3 chỗ về Excel, Word vẫn xanh. Tắt bộ dịch công thức trong `A1Reference` → E2E đỏ ở đúng
phép kiểm công thức.

> ⚠ **Ba bài kiểm của mảng này từng XANH mà không kiểm gì, và cả ba hỏng theo cùng một kiểu.**
>
> 1. Bài `.pptx` gọi LibreOffice `--convert-to txt` — Impress không có bộ xuất văn bản thuần,
>    nên nó `XCTSkip` và in "skipped" giữa một rừng dấu ✅.
> 2. Bài chèn hàng dựng fixture bằng `.fods` với `table:formula` — **LibreOffice bỏ qua thuộc
>    tính ấy**, cho ra tệp `.xlsx` không có một `<f>` nào. Ba bài "công thức dịch đúng chưa"
>    chạy trên một tệp không có công thức nào để mà dịch.
> 3. Phép kiểm đầu tiên cho vế công thức hỏi `xml.contains("A4")` — trúng tham chiếu Ô
>    (`<c r="A4">`) mà phép đánh số lại luôn sinh ra, chứ không trúng công thức.
>
> Cả ba chỉ lộ ra khi **cố ý bẻ sản phẩm rồi đòi bài kiểm phải đỏ**. Và cách truy giống nhau ở
> cả ba: **chạy đúng phép kiểm ấy trên dữ liệu chưa qua mã của mình** — nếu nó vẫn xanh thì
> phép kiểm đang nhìn chỗ khác.
>
> Kèm một sự thật về công cụ đối chứng: **LibreOffice KHÔNG tính lại công thức khi mở `.xlsx`**,
> kể cả khi đã bật `fullCalcOnLoad`. Nó đọc giá trị đã lưu sẵn trong ô. Nên phép đối chứng ngoài
> chỉ chứng minh được "tệp mở được, đủ hàng"; vế "công thức dịch đúng" phải kiểm thẳng vào văn
> bản `<f>` trong tệp.

**Và một giới hạn của bộ chụp ảnh cần nhớ khi soát:** ảnh `media-pdf` và `media-word` ra trắng
ở vùng nội dung chính. Đó là giới hạn đã biết của `WindowCapture` (không bắt được view vẽ qua
layer), không phải lỗi hiển thị — trang thu nhỏ của PDF render đúng từ cùng một tài liệu, và
bài tự kiểm đã kiểm nội dung bằng đường khác.

---

## 5. Bảng đối chiếu 167 FR của SRS v2.2

**Xong 146 · một phần 1 · thay thế 1 · chưa có mã 19** — tổng 167, khớp hai bảng bên dưới.

Theo ưu tiên: **P0 38/38 (100%)** · **P1 75/75 (100%)** · P2 33/52 (63%).

> **Dòng ưu tiên trên vừa trôi mất 12 mã, và cổng máy không bắt được.** Tới sáng 28/08/2026 nó
> còn ghi "P1 62/75 · P2 17/54" — con số của ngày 27/08, đứng ngay dưới một dòng tổng đã cập
> nhật lên 132. Trang tự mâu thuẫn với chính nó trong hai dòng liền nhau. Lý do:
> `phase-table.py --kiem` chỉ đối chiếu **bảng §5.3 và dòng tổng**, không đối chiếu dòng ưu
> tiên — nên dòng ấy quay về đúng chế độ gõ tay mà cả §5.3 sinh ra để thoát khỏi.

Trạng thái ở đây không chép từ tài liệu mà **đối chiếu bằng mã nguồn**: mỗi ✅ có file hoặc
symbol nêu tên ở cột chứng cứ, mỗi ⛔ đã `grep` qua toàn `Sources/` và **không trúng dòng nào**.

### 5.1 Chín nhóm của bộ v1 (82 FR) — khớp gần tuyệt đối

| Nhóm | ✅ | ◐ | ⛔ | Chứng cứ trong mã |
|---|---|---|---|---|
| FR-CORE (18) | 18 | 0 | 0 | `TextBuffer/` (PieceTree · MultiSelection · ColumnEditor · CompletionEngine), `LineOps/`, `ClipboardRing.swift` |
| FR-SRCH (11) | 11 | 0 | 0 | `Search/` (PCRE2SearchEngine · DocumentSearch · FindInFiles · RegexTester) |
| FR-ENC (7) | 7 | 0 | 0 | `Encoding/` — 36 bảng mã, `VNICodec`, `LegacyCodec` |
| FR-DOC (14) | 13 | 1 (305) | 0 | `Session/` (Document · SessionStore · SnapshotStore · Workspace · DocumentVersions) |
| FR-CSV (8) | 8 | 0 | 0 | `CSV/` 23 file · `CSVQuery*` · `SQLPanel.swift` |
| FR-FMT (8) | 8 | 0 | 0 | `Syntax/` (JSONTool · XMLTool · FoldRanges · UserDefinedLanguage · LogFormat · XMLSchemaValidator). **503 khép trọn 28/08** — vế «fold theo cấp» nay có `FoldRanges.ranges(atLevel:in:)` và submenu ⌥⌘1…⌥⌘8 (§5bis-c) |
| FR-AUTO (6) | 6 | 0 | 0 | `Automation/`, `CLIBridge.swift`, `ScriptingSupport.swift`, `Resources/GEditor.sdef` |
| FR-PLUG (5) | 5 | 0 | 0 | `NativePlugin.swift`, `PluginPackage.swift`, target `GEditorPluginHost` |
| FR-UI (5) | 5 | 0 | 0 | `PreferencesPanel`, `KeyBindings`, `Theme.swift`, `Localization.swift` |

### 5.2 Chín nhóm v2.0–v2.3 thêm vào (85 FR) — mới chạm 6

| Nhóm | ✅ | ⛔ | Phase | Tình trạng mã |
|---|---|---|---|---|
| FR-CLN (6) | **6** | 0 | 2 · 004 ở Phase 4 | `CSVClean*.swift` ×6 + `CSVCleanPanel/Sheet`. **004 khép 28/08:** `CSVFuzzyDedup` + `CSVFuzzyDedupSheet` — gom cụm qua `TextDistance.clusters` (thuật toán dùng chung với FR-KNW-923/924), bảng viết tắt phổ biến, và bất biến **không bao giờ tự gộp** có bài kiểm ở cả lõi lẫn giao diện |
| FR-QRY (6) | **6** | 0 | 2–3 | **CỤM KHÉP 26/08/2026.** 001 Workbench · 002 Filter · 003 Pivot · 004 Quick Charts · 005 Catalog bảng ảo · 006 CLI. Ba chốt đáng nhớ: **pivot sinh SQL rồi ĐƯA VÀO ô truy vấn chứ không tự chạy** (đặc tả đòi câu ấy hiển thị và sửa được — "vừa dùng vừa học"); **biểu đồ màn hình và SVG đọc CÙNG một danh sách hình** nên không lệch được; **danh mục so cả cỡ file lẫn mtime** nên sửa một ô giữ nguyên độ dài vẫn bị bắt |
| FR-DQR (6) | **6** | 0 | **2**–3 | **CỤM KHÉP 27/08/2026** — bốn mã Phase 3 xong: **003** khối ` ```quality ` trong `.greport.md` (`QualityCard` + `QualityCache`: thẻ điểm 6 thanh · công thức in thành CHỮ trên trang chứ không tooltip, vì báo cáo được IN ra · bảng luật xếp TRƯỢT lên đầu · cache theo hash(luật) + dấu vân nguồn, chốt theo NGÀY vì `max_age_days` đo bằng ngày · batch 63 tỉnh qua `--param-list`). **004** trôi dạt (`QualityHistory` + `QualityDrift`: JSONL nối đuôi bằng `O_APPEND` nên hai tiến trình không đè nhau, một dòng hỏng chỉ mất một dòng và **được ĐẾM**; ngưỡng khai ở `drift:` và **mọi ngưỡng tắt mặc định** trừ "luật đang đạt nay trượt"; luật khoá theo TIÊU ĐỀ chứ không theo chỉ số nên chèn một luật vào giữa tệp không báo nhầm; tab Xu hướng có biểu đồ + so hai mốc bất kỳ). **005** cổng CLI `--quality … --fail-under … --json` với **mã thoát 0/1/2 chứ không 64/65/66** (một cổng trả 65 sẽ bị viết thành `\|\| true` trong CI); "luật không chạy được" là TRƯỢT chứ không phải lỗi chạy; batch lấy mã NẶNG NHẤT; `--recipe` làm sạch trong bộ nhớ rồi chấm lại và in cả điểm TRƯỚC. **006** vòng khép kín (`QualityFix` ở LÕI, không ở panel): nút mở đúng công cụ — null → Xử lý giá trị thiếu · date → Chuẩn hóa ngày · unique → Khử trùng lặp · regex/in_set → Thay thế nạp sẵn GIÁ TRỊ THẬT đang sai (mẫu regex mô tả cái ĐÚNG, tìm cái sai bằng nó phải bọc phủ định lồng nhau); sửa xong TỰ chấm lại. **001/002 (Phase 2, xong 26/08/2026)** — engine + panel, 60 test lõi + 2 bài tự kiểm. **001:** `YAMLReader` + `QualityRules` + `QualityEngine`, đủ 10 loại luật; NFR-DQR-01 đo **328 ms / trần 15 000** (cách hiển nhiên — mỗi luật một câu — tốn **14 651 ms, 98% ngân sách**, nên gom-một-lượt là điều kiện ĐẠT chứ không phải tối ưu); bấm một luật thì **tô đúng dòng vi phạm và nhảy tới** (ép DuckDB quét tuần tự, vì đọc song song thì số hàng không bảo đảm theo thứ tự file). **002:** `QualityScore` sáu chiều, công thức in trong tooltip (NFR-DQR-03), MAD cho ACCURACY, chiều không chấm được hiện `—` chứ không cho 100. Còn treo một câu hỏi ở §6 mục 10 |
| FR-MIN (8) | **8** | 0 | 3–4 | **001 + 002 + 003 + 004 + 005 + 007 + 008 XONG 26/08/2026** — `AnomalyDetector` (đơn biến z-score · IQR · MAD, đa biến Mahalanobis) + `AnomalyPanel`, 20 test lõi + 1 bài tự kiểm. Bốn chốt: **thanh trượt đọc cột ra bộ nhớ ĐÚNG MỘT LẦN** rồi chỉ chạy lại phép thống kê, nếu không thì mỗi nhịp kéo là một lượt hỏi DuckDB và NFR-PERF-02 vỡ (bài tự kiểm **xoá file khỏi đĩa rồi kéo tiếp** để chứng minh); **màu Mark theo ba mức nặng**, một màu cho tất cả thì vế (b) vô nghĩa; **không đo được thì KHÔNG kết luận** — IQR = 0 hay MAD = 0 thì từ chối chứ không chia liều; **Σ suy biến thì từ chối và nói bỏ cột nào**, không dùng pseudo-inverse để "chạy được". **008 (`AnomalyExplain`, `MahalanobisModel`, 12 test):** phân rã leave-one-out ΔD²(j) = D²đủ − D²(bỏ j), chuẩn hoá 100%, sinh câu *«bất thường chủ yếu do tổ hợp x (50%) × y (50%)»*. Ba điều đáng ghi. (1) **Không dùng phân rã theo số hạng của dạng toàn phương dù nó MIỄN PHÍ** — số hạng ấy CÓ THỂ ÂM khi một cột đi ngược chiều tương quan, và "đóng góp −180%" thì bảng phần trăm vô nghĩa; có bài kiểm dựng đúng điểm sinh ra số âm ấy. (2) ΔD² ≥ 0 là ĐỊNH LÝ chứ không phải may (`D²đủ = D²(bỏ j) + (xⱼ − x̂ⱼ)²/σ²ⱼ|còn lại`), và có bài quét 700 điểm giữ nó. (3) **"Tổng % = 100" của đặc tả có ĐÚNG MỘT chỗ không thể đúng** — tại đúng tâm dữ liệu thì D² = 0 và mọi tỷ lệ là 0/0; trả về 0 chứ không chia đều 100/k, vì chia đều là bịa cấu trúc và sẽ nói "chủ yếu do cột a" về một hàng bình thường. Khối Phương pháp nói rõ 61% nghĩa là *trong phần giải thích được*, không phải *61% khoảng cách*. **005 (`Correlation`, `CorrelationPanel`, 28 test):** Pearson + Spearman mọi cặp, heatmap, bấm ô ra scatter kèm đường hồi quy và R². Bốn chốt. (1) **Hạng TRUNG BÌNH cho giá trị trùng** — xếp hạng ngây thơ làm ρ đổi khi sắp lại bảng, tức NFR-MIN-02 vỡ; có bài hoán đổi hai hàng trùng để giữ. (2) **Ô trống tính theo từng cặp (pairwise), và `n` của từng ô nằm trong bảng** — 0,93 trên 6 hàng không cùng nghĩa với 0,93 trên 6.000. (3) **Cột hằng trả `nil` chứ không trả 0** — 0 nghĩa là "đã đo, không có liên hệ". (4) **Thang lam↔cam, không đỏ–lục**: 8% nam giới đọc thang đỏ–lục thành một mảng xám đồng đều, tức +0,9 và −0,9 trông y hệt nhau; chữ trên ô cũng đổi màu theo nền, vì chữ đen cố định biến mất ở r = −1 — đúng những ô đáng chú ý nhất. Câu *"Tương quan không hàm ý nhân quả"* được kiểm như một yêu cầu, và nằm **trong chính hình vẽ** nên theo được ảnh PNG dán vào báo cáo. `ChartRender.primitives` nhận thêm `trendLine` dạng (hệ số góc, điểm cắt) — hình học thuần tuý, lõi vẽ không biết gì về tương quan. **002 (`Clustering`, `ClusterSheet`, 26 test):** k-means++ seed cố định · DBSCAN có chỉ mục lưới · chuẩn hoá z-score/min-max · silhouette · elbow WCSS · k-distance. Năm chốt. (1) **Chuẩn hoá BẬT mặc định**: `doanh_thu` (hàng triệu) cạnh `so_luong` (hàng đơn vị) thì khoảng cách Euclid gần như hoàn toàn do cột lớn quyết định — không phải "kém tối ưu", mà là trả lời một câu hỏi KHÁC; cách đã chọn ghi vào kết quả. (2) **Silhouette là O(n²) nên nó LẤY MẪU** trên bảng lớn, mẫu theo bước đều chứ không lấy 2.000 dòng ĐẦU (bảng người dùng thường đã sắp, lấy đầu là trúng một cụm), và kết quả tự khai là ước lượng. (3) **DBSCAN dùng lưới không gian** thay cho O(n²), có bài so TỪNG tập hàng xóm với quét thẳng ở 5 bán kính — lưới bỏ sót một ô kề sẽ sai rất khó thấy; lưới tự tắt trên >5 chiều vì `3^d` ô vượt cả số điểm. (4) **Elbow chuẩn hoá cả hai trục trước khi đo dây cung** — không thì trục WCSS (hàng triệu) áp đảo trục k (1…10) và gợi ý luôn là k = 2 bất kể hình dạng; sheet **vẽ đường cong** và nói rõ đây là mẹo đọc đồ thị, vì WCSS luôn giảm nên không có "k tối ưu" thống kê. (5) **Cụm rỗng giữ nguyên tâm cũ**, đặt về gốc toạ độ sẽ hút mất một phần cụm khác và sinh dao động không hội tụ. Bonus: `SeededGenerator` gom bản SplitMix64 mà `PieceTree` chép riêng — lần thứ ba trong phiên gặp mẫu "hai bản của một thuật toán". **004 (`TimeSeries`, `ForecastPanel`, 29 test):** phân rã trend/seasonal/residual · Holt-Winters cộng và nhân · seasonal-naive và naive làm baseline · dải 80%/95%. Năm chốt. (1) **Baseline LUÔN chạy và `verdict` nói thẳng ai thắng** — công cụ dự báo thường trình bày mô hình như sự thật, người dùng không có cách biết "lấy giá trị tháng trước" còn chính xác hơn; khi thua thì câu ấy nằm ở DÒNG ĐẦU và ĐỔI MÀU, không nằm dưới bảng số. (2) **ACF chạy trên SAI PHÂN bậc một** — bản đầu chạy trên chuỗi gốc và trả về chu kỳ **2** cho dữ liệu chu kỳ 4, vì xu hướng làm ACF cao ở mọi độ trễ và đỉnh mùa vụ chìm hẳn; bài kiểm bắt được. (3) **Không đủ hai chu kỳ thì LÙI về naive** — khớp mùa vụ vào nhiễu của một chu kỳ rồi lặp ra tương lai cho một dự báo trông thuyết phục và hoàn toàn bịa. (4) **MAPE gặp số 0 thì nói ra**, và quá 25% kỳ bằng 0 thì trả `nil` — bỏ qua trong im lặng cho một con số tính trên tập con lệch có hệ thống (bỏ đúng những kỳ khó nhất). (5) **Khoảng tin cậy tự khai là XẤP XỈ** (σ√h thay vì ETS) và nói rõ nó nới quá chậm ở tầm xa. Thêm hình `polygon` vào lõi vẽ cho dải tin cậy, và `ChartRender.forecastPrimitives` tính thang MỘT LẦN trên hợp của mọi thành phần kể cả mép dải 95%. **007 (`GroupMining`, `GroupMiningPanel`, 12 test):** mỗi nhóm chạy bất thường / dự báo / tương quan ĐỘC LẬP. Bốn chốt. (1) **Mỗi nhóm một hàng rào IQR riêng** — đặc tả tự gọi đây là "lỗi kinh điển", và nó hỏng theo CẢ HAI chiều: gộp hai chi nhánh quanh 10 và quanh 100 cho hàng rào ±135 nên **bỏ sót** một giá trị 20 rõ ràng bất thường trong nhóm nhỏ (càng nhiều nhóm càng mù), còn nhóm phân tán rộng thì bị hàng rào chung cắt mất đuôi bình thường và **báo nhầm** hàng loạt. Có bài kiểm cho từng chiều, mỗi bài kèm đối chứng chứng minh hàng rào GỘP thật sự sai. (2) **Cột "lệch tương quan" bắt nghịch lý Simpson** — bài kiểm dựng ba nhóm mà trong mỗi nhóm r = −1 còn gộp lại r > 0,9; ai đọc bảng gộp sẽ kết luận NGƯỢC. (3) **Mỗi nhóm tự phát hiện chu kỳ riêng** — bài kiểm dùng một nhóm chu kỳ 4 cạnh một nhóm chu kỳ 7. (4) **Trần 1.000 nhóm cắt kèm CẢNH BÁO**, bắt tình huống chọn nhầm cột nhóm (mã đơn hàng → mỗi hàng một nhóm); panel chỉ đưa cột CHỮ vào danh sách nhóm để chặn từ đầu. Drill = **tô ngược vào dữ liệu gốc** qua Mark engine, đúng nguyên tắc chung của cả cụm FR-MIN. **Block ```mining XONG 27/08/2026** (`MiningCard`, 16 test + 1 tự kiểm): khoá `group_by` · `value` · `pair` · `rank` (`anomalies` · `forecast_error` · `correlation_gap`) · `limit` · `horizon` · `iqr_k` · `min_rows` · `source` · `chart`. Ba chốt. (1) **KHÔNG có khoá nào tắt khối "Phương pháp"** — NFR-MIN-04 viết *"MỌI đầu ra kèm khối Phương pháp"*, và người muốn tắt nó luôn là người đã biết câu trả lời; cái giá là một khối chữ có thể thấy thừa, đổi lấy việc không bao giờ có một báo cáo ba con số không nói chúng ở đâu ra. (2) **MỘT lượt quét cho cả ba cột** — ngoài chuyện tốc độ, ba lượt riêng có thể trả về ba mảng LỆCH NHAU về số hàng nếu tệp đổi giữa chừng, và khi ấy nhãn nhóm của hàng thứ i không còn thuộc cùng hàng với giá trị thứ i. (3) **`pair` trùng `value` thì TỪ CHỐI** — tự tương quan luôn ra r = 1 ở mọi nhóm, tức một cột đầy số 1 trông như một kết quả. Và một lỗi bắt được lúc thử tay: bảng in 3 chữ số thập phân trong khi khối Phương pháp ngay dưới in 2, nên tấm thẻ nói tương quan toàn bộ là **0,999** còn dòng dưới nói **1,00**; nay cả ba nơi (panel · Phương pháp · thẻ) dùng chung `ChartRender.number`. **003 (`Apriori`, `AssociationPanel`, 16 test):** Apriori cắt tỉa bao đóng xuống · hai dạng đầu vào (giỏ một dòng, và hai cột mã·item) · support/confidence/lift/leverage. Bốn chốt. (1) **Bảng sắp theo LIFT, không theo confidence** — nếu vế phải vốn có trong 95% giỏ thì mọi luật dẫn tới nó đều confidence ~95% mà chẳng nói gì, và sắp theo confidence đưa đúng những luật vô nghĩa nhất lên đầu; bài kiểm dựng một luật confidence 100% với lift = 1 và bắt nó phải nằm SAU. (2) **lift < 1 kèm cảnh báo ngay trong hàng** — confidence 80% với P(vế phải) = 95% nghĩa là liên hệ NGƯỢC, một con số đúng dẫn tới kết luận sai. (3) **Bỏ trùng trong cùng một giỏ** — mua hai hộp sữa vẫn là một giao dịch có sữa; không bỏ thì support phồng theo số lượng mua. (4) **Trần ứng viên 200.000 thì DỪNG và nói bảng KHÔNG đầy đủ**, vì support đặt quá thấp làm số ứng viên nổ theo tổ hợp. Bấm một luật thì tô mọi giao dịch chứa nó — ở dạng hai cột, một giao dịch trải trên nhiều hàng nên phải tô HẾT. **Sai lệch có chủ ý so với đặc tả:** đặc tả viết "cắt tỉa hash-tree"; ở đây đếm bằng bảng băm khoá theo tập item — cùng độ phức tạp, ít hơn khoảng hai trăm dòng — và điều đó được ghi trong `methodology` chứ không giấu trong chú thích. **006 khai phá văn bản XONG** — `TextMining.swift` (n-gram 1–3 · TF-IDF · stopword Việt và Anh · từ điển từ ghép của người dùng), lệnh `Khai phá văn bản` dựng bảng từ khoá ra TAB MỚI dạng CSV, nút «Tô lên tài liệu» đi qua đúng Mark engine của FR-KNW-908, và corpus JSONL thì chấm trên TRƯỜNG TEXT chứ không trên cả dòng JSON. Bộ tách từ **dùng chung `BM25Tokenizer`** đúng hợp đồng ghi trong chính tệp ấy — hai bộ tách khác nhau thì bấm một từ khoá sẽ ra số kết quả khác con số vừa hiện trong bảng, và không có gì báo lỗi. *Dòng cũ ở đây ghi «Còn 1: 006» trong khi mã đã có — bảng §5.3 đếm đúng 8/8, chỉ phần chữ trôi.* |
| FR-RPT (6) | **6** | 0 | 3–4 | **CỤM KHÉP TRỌN 27/08/2026** — `Report/` 6 tệp lõi, 79 test + 1 bài tự kiểm. **001** `ReportDocument` + `ReportRenderer` + `ReportPreviewView` (soạn trái, preview phải qua WKWebView). **002** `NumberStyle` (quy ước Việt `1.234,56`) + `ChartRender.Palette` (G-Light · G-Dark · Brand). **003** lưới dashboard từ frontmatter + dấu vân nguồn báo "dữ liệu cũ". **004** `ReportParameters` + hộp nhập trên UI + `geditor --report … --param … --out …`. **005** HTML tự chứa + in/PDF qua `WKWebView.printOperation` — **đóng luôn khoảng trống FR-DOC-313 (In ấn)**. Sáu chốt. (1) **Một khối hỏng KHÔNG giết cả trang** — ném lỗi ra ngoài biến báo cáo tám khối có một lỗi chính tả thành màn hình trắng; mỗi khối ra kết quả HOẶC hộp lỗi tại chỗ kèm số dòng, và CLI trả mã **65** để job đêm không báo thành công nhầm. (2) **Khối chart không khai `query` thì dùng kết quả khối query LIỀN TRƯỚC** — buộc chép câu SQL hai lần thì hai bản sẽ lệch, và bảng nói một đằng biểu đồ nói một nẻo trong cùng một trang. (3) **KHÔNG dùng `NumberFormatter`** — nó theo locale của MÁY, nên cùng một tài liệu dựng trên hai máy cho ra hai tệp khác nhau; quy ước do chính tài liệu khai. (4bis) **006 XONG 27/08/2026 — cụm khép trọn.** `ReportBatch` + `--param-list tinh.csv --out bc/ --name "bao-cao-{tinh}.html"` ở CLI, và **đường chạy từ UI** («Báo cáo: sinh loạt…»): mỗi bộ tham số một tệp, bảng tổng kết ra TAB MỚI. Chạy trên LUỒNG CHÍNH và nhả nhịp giữa các bộ — một lượt dựng chạm `WKWebView` của bộ vẽ sơ đồ, `QualityCache` dùng chung và chính `editorDocument`, cả ba chỉ sống ở luồng chính; đẩy sang luồng nền là mở ra một họ lỗi tranh chấp. Bản xuất từ UI **có sơ đồ đã vẽ**, bằng chất lượng bản xuất một tệp — đó là chỗ khác CLI, nơi không có WebKit. (4) **Nén là nhu cầu bố cục, dấu phân cách là quy ước ngôn ngữ** — nhãn trục vẫn nén nhưng thành `1,2M`, còn bảng số thì KHÔNG nén vì người ta cộng tay. (5) **Markdown tự viết, mọi ký tự đi qua `escape`** — báo cáo được chia sẻ, và một thư viện đầy đủ mang theo HTML thô, tức `<script>` chạy trên máy người nhận; liên kết `javascript:` bị bỏ nhưng giữ lại chữ. (6) **Tham số thay cả trong VĂN XUÔI, nhưng chỉ với tên ĐÃ KHAI** — in ra nguyên `:thang` giữa báo cáo gửi sếp là hỏng khó biện minh, còn thay mọi thứ giống `:tên` sẽ phá `mailto:abc`. WebKit nay liên kết lúc nạp và **đã khai vào cổng ADR-14** kèm số đo PoC-L (+1,4 ms / sàn nhiễu 0,9 ms); khởi động đo lại **464 ms / trần 500**.
| FR-MMD (8) | **8** | 0 | 3–4 | **BẮT ĐẦU 27/08/2026.** `mermaid.min.js` **11.17.2** (MIT, 3,4 MB) vendor vào `vendor/mermaid/` kèm bản kê sha256 sinh bằng máy — **commit thẳng, không qua LFS**: `.gitattributes` cân LFS theo cỡ (94 MB thì mỗi lần nâng cộng 94 MB vĩnh viễn), còn 3,4 MB thì không đáng, và tránh được đúng cái bẫy mà chính tệp ấy nêu — máy chưa cài `git lfs` clone ra con trỏ 130 byte và MỌI sơ đồ im lặng không vẽ. **001 ✅** `MermaidDocument` + `MermaidAsset` + `MermaidRenderer` + `MermaidPanel` (⌥⇧⌘D): vẽ qua WKWebView có `WKContentRuleList` chặn mọi URL (cách PoC-L đã kiểm CÓ đối chứng âm); **không dựng được hàng rào thì KHÔNG nạp trang** — một tính năng không chạy thì thấy được, một hàng rào không chạy thì không. Loại sơ đồ LẠ vẫn vẽ (khác luật "bản mới hơn thì từ chối" của `QualityRules`: ở đó ta diễn giải rồi chấm điểm, ở đây ta chỉ chuyền chữ cho mermaid). **003 ✅** khối ` ```mermaid ` trong `.greport.md` và trong xem trước Markdown: lõi để lại CHỖ TRỐNG có đánh số kèm mã nguồn, app điền SVG vào (`spliceMermaid`) — nhờ thế `ReportPreviewView` giữ nguyên lời hứa KHÔNG JavaScript, HTML xuất ra nhúng SVG tự chứa, và in PDF giữ vector; xem trước Markdown chèn ảnh đính kèm chứ không đổi thành trang web. **NFR-MMD-01 đo trên CHÍNH đường sản phẩm** (`--mermaid-kpi`): 500 node lần đầu **1.099 ms / trần 2.000** (tính cả dựng WKWebView và nạp 3,4 MB JS), cập nhật trung vị **9,4 ms / trần 500**, RAM 79 → 109 MB và chỉ khi mở sơ đồ. **002 ✅ 27/08** đồng bộ HAI CHIỀU: gõ→vẽ (debounce 300 ms), bấm sơ đồ→con nháy nhảy tới dòng, và chọn văn bản→phần tử sáng. Cả hai chiều nối bằng CHỮ hiện trên phần tử, vì mermaid không trả cây phân tích ra để dựng bản đồ `element-id ↔ text-range` như đặc tả hình dung; giới hạn nói ra: hai node cùng nhãn thì cùng sáng. **007 ✅ 27/08** PNG 1x/2x/3x + copy-as-image + nền trong suốt + preset `%%{init}%%` lưu ở `themes/mermaid-brand.json`. Hai điều chỉ biết được bằng cách MỞ MỘT TỆP SVG THẬT: cỡ nằm ở `viewBox` (mermaid ghi `width="100%"`), và **nền mermaid vốn TRONG SUỐT** — nên "nền trong suốt" là mặc định, còn nền ĐỤC mới là thứ phải thêm. Rasterize từ SVG chứ không chụp web view: chụp thì cỡ ảnh đổi theo bề rộng panel. **005 ✅ 27/08** `MermaidLibrary`: 11 mẫu đầy đủ (nhãn TIẾNG VIỆT, từ khoá thì không dịch) + 11 mẩu cú pháp + từ khoá theo loại + rút tên node đã khai. Rút tên node KHÔNG viết 11 bộ phân tích mà khai thác một tính chất chung — định danh đứng NGOÀI dấu nhãn — và mức chính xác ấy chỉ đủ cho GỢI Ý, nên nó chỉ được dùng cho gợi ý; năm loại có định danh thì rút, gantt/pie/timeline/mindmap/quadrant trả rỗng vì rút "tên" từ chúng chỉ ra những từ vừa gõ. **Bài tự kiểm mạnh nhất của cụm: vẽ MỌI mẫu và MỌI mẩu bằng chính mermaid** — bài kiểm ở lõi chỉ đọc được "mẫu khai đúng loại nó nói". **006 ✅ 27/08** grammar dựng trên hạ tầng FR-FMT-502 (không viết grammar tree-sitter: Mermaid không có cấu trúc lồng sâu) · gạch dưới CHẤM đúng dòng (TextKit 2 không có kiểu gạch sóng — ghi ra thay vì giấu) · formatter chỉ đụng KHOẢNG TRẮNG và THỨ TỰ DÒNG, giữ nguyên chú thích và frontmatter, gom khai báo là tuỳ chọn mặc định TẮT. **004, 008 ⛔** (Phase 4) | **004 ✅ 28/08/2026** (`MermaidEdit` + `MermaidEditParse` + `MermaidPropertyTable`, 51 test lõi + 5 bài tự kiểm) — **mục P1 cuối cùng của cả sản phẩm**. Dựng trên ĐÚNG nền FR-KNW-915 vừa đặt: cử chỉ trên hình biên dịch thành `[TextEdit]`, áp một lần, một bước hoàn tác; không hàm nào sửa gì, nên buffer vẫn là nguồn sự thật duy nhất (SAD Hình 4). Sáu chốt. (1) **Bài kiểm đắt nhất là bài chạy qua CHÍNH mermaid.js**: bảng phương ngữ (`class Foo["Nhãn"]`, `ZZ["Nhãn"] { }` của ER, `participant A as X`) là chỗ dễ sai nhất, và sai nghĩa là *sơ đồ đang chạy bỗng không vẽ được nữa* — một bài so chuỗi sẽ xanh với mọi cú pháp bịa ra. Bài tự kiểm dựng năm phương ngữ, làm ba phép trên mỗi cái, và đòi số sơ đồ hỏng bằng 0 sau TỪNG phép; đã xác nhận nó ĐỎ được. (2) **Xoá cạnh KHÔNG được làm biến mất node hai đầu** — khác biệt thật so với DOT: mermaid cho khai node ngay trong câu lệnh cạnh (`A["Nhận"] --> B["Duyệt"]`), nên xoá dòng ấy xoá luôn cả hai node mà người dùng vẫn đang nhìn; nay chúng được khai lại KÈM NHÃN. Hai bài kiểm ở lõi bắt được. (3) **Nhãn neo theo ĐỊNH DANH, không theo cặp ngoặc đầu dòng**: một dòng cạnh mang HAI nhãn, nên «cặp ngoặc đầu tiên» luôn là nhãn của node bên trái và sửa nhãn `B` sẽ ghi đè lên nhãn `A`. (4) **Loại chưa làm NÓI RA lý do** (mindmap dựng cây bằng thụt lề · quadrant đặt điểm bằng toạ độ · gitGraph là chuỗi lệnh có thứ tự) — đặc tả đòi *"hiển thị rõ chỉ soạn text"*, và im lặng không làm gì là cách chắc chắn nhất khiến người dùng nghĩ công cụ hỏng. (5) **gantt và pie sửa qua BẢNG THUỘC TÍNH** vì một lát bánh không có hai đầu để kéo; bảng không giữ dữ liệu riêng — mỗi lượt vẽ đổ lại từ `parse`, mỗi ô sinh một `TextEdit`. (6) **Phép dời toạ độ có tên và có bài kiểm**: `MermaidEdit` tính theo NGUỒN SƠ ĐỒ còn buffer chứa cả tài liệu, nên một khối ` ```mermaid ` giữa tệp Markdown lệch đúng bằng vị trí của nó — cùng họ với lỗi số dòng đã gặp ở FR-KNW-905. Ba lỗi thật do bài kiểm bắt: hai khoảng xoá chồng nhau đúng MỘT byte làm `applyEdits` sập; vị trí chèn vượt cuối văn bản đúng một byte khi nguồn không kết thúc bằng xuống dòng; và ký hiệu lực lượng `o{` của ER bị đếm là mở ngoặc nên dấu `:` ngăn nhãn «nằm trong ngoặc» và không ai tìm thấy. **008 ✅ 28/08/2026 — CỤM KHÉP TRỌN** (`MermaidLink`, 15 test lõi + 2 bài tự kiểm). Hai nửa. (1) **Tam giác Mermaid ↔ DOT ↔ edge list khép kín**: hai chiều còn thiếu đi VÒNG QUA DOT thay vì viết bộ sinh mermaid thứ hai, và hai chiều đã chạy được từ FR-KNW-910 nay mới có mặt trên menu — chúng chạy được nhưng chưa bao giờ bấm tới được. Tính chất nói ra: vòng này KHÔNG giữ định danh (`DOTToMermaid` luôn đặt lại `n0`, `n1`… và đưa tên gốc vào NHÃN), vì tên node DOT có thể chứa ký tự mermaid không nhận. (2) **Tách khối ra tệp `.mmd` giữ tham chiếu**: thân khối được thay bằng MỘT DÒNG CHÚ THÍCH MERMAID HỢP LỆ `%% geditor:file …`. Cách hiển nhiên hơn — ghi lên hàng rào `” ```mermaid file=… “` — đã cân nhắc và BỎ: cả `MermaidDocument` lẫn `ReportDocument` đều đòi chuỗi info khớp đúng, nên một dòng info lạ bị chép nguyên sang Markdown và sơ đồ biến mất khỏi báo cáo; sửa hai bộ đọc để đổi lấy một dòng đẹp hơn là đổi rủi ro thật lấy thứ không ai nhìn. Cái giá được nói thẳng trong tài liệu mã: tệp sau khi tách KHÔNG còn tự chứa, và đường lui là lệnh nhúng ngược. Ghi tệp TRƯỚC, sửa tài liệu SAU — ngược lại thì một lần ghi hỏng để lại tài liệu trỏ vào tệp không tồn tại. Nhúng ngược KHÔNG xoá tệp: xoá là việc Cmd-Z không hoàn tác được. Khối tham chiếu cũng bị CHẶN soạn trực quan, vì "sửa một nơi" nghĩa là nơi ấy. **Và bài kiểm bắt được một lỗi thật của `MermaidRenderer` sống từ đầu cụm**: `drain()` bắt lượt vẽ TRƯỚC phép bỏ bớt hàng đợi, nên nó vẽ đúng lượt vừa bị bỏ còn lượt mới nhất bị `removeFirst()` lấy ra và trao cho kết quả của lượt cũ — sửa tài liệu trong lúc một lượt vẽ đang chạy thì preview đứng ở nội dung cũ tới lần sửa sau, im lặng, và chỉ xảy ra khi gõ nhanh. **Bài kiểm này cũng tự bắt chính nó**: phép hỏi "sau khi tách vẫn vẽ được" ban đầu RỖNG NGHĨA — nội dung tệp giống hệt nội dung vừa nằm trong khối, nên một tầng vẽ không giải tham chiếu vẫn để nguyên kết quả cũ và mọi phép hỏi đều thấy đúng thứ mình mong; đối chứng âm chỉ ra điều đó, và bài kiểm nay sửa tệp rời thành nội dung KHÁC HẲN trước khi hỏi.
| FR-KNW (26) | **25** | 0 (+1 ⊘) | 3–4 | **BẮT ĐẦU 27/08/2026 — kiến trúc chốt ở [ADR-15](adr/ADR-15-knowledge-pack-trong-loi.md): mã nằm TRONG lõi, nạp lười, có cổng canh** (người dùng chốt phương án B). Nền dùng chung: `BM25Index` tự viết (ĐẠT NFR-KNW-04 — dựng 1 GB trong 19–21 s / trần 30 s, đối chứng với bản Python độc lập lệch **0,000e+00**), `JSONLReader`, `JSONScanner`, `JSONLScan.forEachLine`. **922 ✅ 27/08** `ChunkQuality` + `ChunkQualityCard` trong khối ` ```quality ` khi khối khai `corpus:`. Bốn phép đo đều **trên văn bản thô, không model nào tham gia** nên tất định và tính lại được bằng tay. Bốn chốt. (1) **Ánh xạ sáu chiều DQR nói rõ chiều nào KHÔNG chấm được**: Tươi mới luôn `nil` vì JSONL chunk không khai ngày; Hợp lệ `nil` khi chưa khai ngưỡng; Không trùng `nil` khi vượt trần RAM. (2) **Tỉ lệ ký tự/token KHÔNG có mặc định** — nó phụ thuộc model lẫn ngôn ngữ. (3) **Trùng gần dùng lọc tiền tố + lọc độ dài rồi chấm Jaccard THẬT** nên chính xác chứ không xấp xỉ. (4) **Bài kiểm đối chứng vét cạn ban đầu qua vì lý do sai** — rút tiền tố ngắn đi mà vẫn xanh; corpus bài kiểm viết lại tới khi nó ĐỎ. **901 + 902 ✅ 27/08** (`JSONScanner`, `JSONLScan`, `ChunkInspector`, `JSONLPanel`; 51 test lõi + 4 bài tự kiểm). **NFR-KNW-02 đo trên corpus 1 GB thật: mở + index 3,0 s / trần 10 s · nhảy tới một bản ghi 0,007 ms · kiểm cả 690.181 bản ghi 0,9 s · thống kê chunk 8,1 s / trần 10,4 s.** Năm chốt. (1) **Hai chặng, không gộp**: chỉ tiêu đo tới lúc DUYỆT ĐƯỢC, nên mở chỉ mmap + chỉ mục dòng, còn kiểm là việc nền có tiến độ và huỷ — gộp lại là bắt người dùng ngồi trước cửa sổ trống. (2) **Bộ đọc JSON viết tay, và nó NGHIÊM hơn `JSONSerialization` một chỗ có chủ ý**: `JSONSerialization` NHẬN `{\"a\":1,}` còn RFC 8259 thì không, và `json.loads` của Python cũng không — một corpus được chấm \"hợp lệ\" rồi vỡ ở bước sau trong pipeline người dùng là hỏng theo hướng im lặng. Có bài kiểm đối chiếu trên 4.000 chuỗi sinh ngẫu nhiên, và chỗ lệch duy nhất được phép là dấu phẩy thừa. (3) **Tiến độ và huỷ hỏi BÊN TRONG vòng dòng** — bản đầu hỏi giữa các khối piece table, mà một tệp mmap là MỘT khối, nên trên tệp lớn nút Huỷ không bao giờ ăn; một bài kiểm bắt được. (4) **Đoán schema trả DANH SÁCH ỨNG VIÊN CÓ ĐIỂM kèm lý do**, không trả một câu khẳng định; điểm gồm cả hình dạng dữ liệu nên nó bắt được một trường tên `id` mà 90% bản ghi trùng giá trị. (5) **Thống kê chạy trên BYTE**: bản đầu dựng `String` rồi gọi `text.count` và `split(whereSeparator:)`, và bộ lấy mẫu đo `_swift_stdlib_getBinaryProperties` chiếm **57,7%** — 69,7 s cho 1 GB so với trần 10,4; chuyển sang byte còn 8,1 s. «Ký tự» vì thế đếm theo scalar chứ không theo cụm hiển thị, và điều đó được in trong khối Phương pháp chứ không giấu. **918 + 919 ✅ 27/08** (`RetrievalEval`, `RetrievalCard`, `RetrievalPanel`, khối ` ```retrieval `; 27 test lõi + 4 bài tự kiểm). Panel có ô câu hỏi → top-10 kèm điểm và **tô sáng đi qua BỘ TÁCH TOKEN chứ không qua tìm chuỗi con** (tìm chuỗi con sẽ sáng ở chỗ điểm BM25 không hề tính tới); hai núm k1/b kèm câu giải thích **đổi theo giá trị đang đặt**, không phải tooltip tĩnh. Nút Đánh giá sinh một tệp `.greport.md` chứa khối ` ```retrieval ` với đường dẫn TƯƠNG ĐỐI — «tái lập được» nghĩa là chạy lại bằng `geditor --report`, không phải một bảng dùng một lần. Ba cái bẫy của một con số đánh giá đều được xử chứ không để người đọc tự đoán: **id kỳ vọng không có trong corpus thì câu bị LOẠI khỏi trung bình** (tính 0 thì một bộ đánh giá trỏ vào corpus cũ cho điểm thấp trông y hệt một bộ truy hồi dở); **một id ứng với nhiều chunk chỉ tính MỘT lần** (không thì nhân bản chunk làm recall tăng); **k nhỏ hơn số id kỳ vọng thì recall có TRẦN toán học** và trần ấy hiện ra cạnh điểm. **Và bộ đánh giá golden set lật ngược một con số của chính bộ đo:** PoC-M báo «truy vấn 1,0 ms» — đúng, nhưng nó đo bằng câu hỏi gồm từ HIẾM; câu hỏi lấy từ chính văn bản thì toàn từ phổ biến và chạm tới nửa triệu tài liệu, ở đó `search` cũ tốn **346 ms một câu** (1.000 câu mất 346 s / trần 60 s). Nguyên nhân: hai từ điển khoá theo tài liệu, và sắp TOÀN BỘ tài liệu chạm được để lấy top-10. Đổi sang mảng dày + bitmask từ khớp + đống cỡ k: **10,0 s**, và bản đối chứng Python vẫn lệch 0,000e+00 nên phép tối ưu không đổi điểm. **905 ✅ 27/08** (`DOTGraph`, `DOTToMermaid`, 25 test lõi + 3 bài tự kiểm): tệp DOT/Graphviz vẽ bằng **CHÍNH bộ vẽ mermaid**, đúng ADR-15 §7 — không vendor engine vẽ thứ hai. Bốn chốt. (1) **Đọc DOT thì không cần cả Graphviz**: thứ ta cần là CẤU TRÚC (node, cạnh, nhãn), không phải BỐ CỤC (toạ độ) — bố cục là việc của mermaid. (2) **Bộ đọc nói ra những gì nó bỏ qua** (`subgraph` đọc phẳng, `rankdir`, thuộc tính mặc định, cụm `{a b} -> c`) kèm số dòng, và panel hiện chúng bằng màu THƯỜNG chứ không đỏ: một giới hạn đã biết không phải một thứ hỏng. Một sơ đồ vẽ thiếu ba cạnh mà không có gì báo thì tệ hơn hẳn một sơ đồ không vẽ. (3) **Hai nguồn khác nhau, không được lẫn**: thứ đưa cho mermaid là bản CHUYỂN, còn thứ dùng để ánh xạ ngược (bấm node → nhảy dòng, con nháy → tô sáng node) là văn bản DOT GỐC; lẫn hai thứ ấy thì mọi số dòng lệch đúng bằng độ dài phần đầu bản chuyển. Bấm node nhảy tới dòng KHAI chứ không tới dòng nhắc tên. (4) **Ba lỗi thật do bài kiểm bắt**: dấu `}` cuối dòng dính vào tên node cuối; thuộc tính nằm giữa câu lệnh làm rơi mất phần đuôi (cả một cạnh biến mất im lặng); và `hasMermaidContent` không biết DOT nên bảng TỪ CHỐI MỞ với một câu nói sai nguyên nhân. Xuất PNG/SVG dùng lại đường FR-MMD-007. **926 ✅ 27/08** (`GoldenSetBuilder`, 17 test lõi + 3 bài tự kiểm): chế độ gán nhãn ngay trong Retrieval Lab — gõ câu hỏi (đã là truy vấn) → **bấm thẳng vào kết quả** để chọn → Lưu. Hai cú bấm cho một record một chunk, đúng mục tiêu «≤ 3 click + 1 lần gõ». Bốn chốt. (1) **Tệp là nguồn sự thật**: mỗi lần lưu GHI THÊM một dòng JSONL (không viết lại cả tệp), nên sập giữa chừng mất đúng record đang gõ; và người dùng soi bộ đánh giá bằng chính chế độ JSONL của FR-KNW-901 chứ không phải học thêm một trình quản lý. (2) **`qid` sinh từ số CAO NHẤT đã có, không từ số lượng record** — `count + 1` sẽ sinh `qid` TRÙNG sau khi xoá một record ở giữa, và `RetrievalEval.compare` ghép theo `qid` nên nó chỉ thấy một trong hai, im lặng. (3) **Thứ tự khoá JSON cố định**, không đi qua `JSONSerialization` vốn sắp lại khoá theo băm — diff git khi ấy đầy thay đổi giả. (4) **Nguồn chưa có câu hỏi nào được kể tên** trên thanh trạng thái: đó là lỗ hổng lớn nhất của một bộ đánh giá và nó vô hình nếu chỉ nhìn danh sách record. Nút Đánh giá dùng LUÔN bộ đang dựng, không hỏi lại đường dẫn. **Một lỗi thật bắt được bằng bài kiểm vòng tròn:** xuất CSV rồi nhập lại làm MẤT cột ghi chú, vì bộ nạp CSV của 919 chưa đọc cột ấy. **913 ✅ 27/08** (`CypherQuery`, `CypherSQL`, 36 test lõi + 2 bài tự kiểm): THỰC THI tập con openCypher — MATCH ≤ 3 hop có nhãn và thuộc tính, WHERE (AND/OR/NOT, ngoặc, CONTAINS/STARTS WITH/ENDS WITH/IS NULL), RETURN DISTINCT, count/collect, ORDER BY, SKIP/LIMIT. Bốn chốt. (1) **Dịch sang SQL DuckDB** rồi đưa câu SQL vào Query Workbench TRƯỚC khi chạy — hỏng lượt chạy thì người dùng vẫn cầm câu SQL để sửa; và câu ấy là một bài giảng về chính đồ thị của họ (hop là phép nối, nhãn là điều kiện, count là GROUP BY). (2) **Ngoài tập con thì TỪ CHỐI, không đọc nửa vời**: nhiều mẫu ngăn bằng phẩy, `*1..3`, hàm lạ, thuộc tính không phải cột — mỗi thứ một câu nói ra vùng đọc được. Bỏ qua lặng lẽ thì truy vấn vẫn ra một bảng, và bảng ấy đúng cho một câu hỏi KHÁC. (3) **Trần 3 hop CỨNG, từ chối trước khi chạy** kèm lý do; kế hoạch chạy in ra số hop, thứ tự nối, và quy ước cột. (4) **`kind` của node: `type` > `class` > `shape`** — DOT không có khái niệm nhãn, nên quy ước phải chọn và phải nói ra. Ba lỗi thật: điều kiện JOIN tham chiếu bảng CHƯA nối (DuckDB từ chối ngay); `list()` của DuckDB đi qua lớp chuyển giá trị thành NULL nên `collect` đổi sang `string_agg`; và chú thích nói `kind` lấy từ `type`/`class` trong khi mã ghi `shape`. **914 ✅ 27/08** (`GraphCSR`, `GraphAlgorithms`, `GraphOverlay`, 27 test lõi + 1 bài tự kiểm): k-hop · đường đi ngắn nhất (BFS/Dijkstra) · thành phần liên thông · PageRank · Louvain. **NFR-KNW-03 đo trên 1 triệu cạnh: 2-hop 5 ms / trần 2 s · liên thông 4 ms / trần 10 s · PageRank 30 ms / trần 30 s · Louvain 976 ms / trần 60 s**, CSR dựng 201 ms MỘT lần. Sáu chốt. (1) **Ba khung nhìn CSR** (ra · vào · bỏ hướng) và chúng khác nhau về NGHĨA: liên thông trên khung «ra» là liên thông MẠNH, một câu hỏi khác. (2) **Dijkstra hay BFS chọn TỰ ĐỘNG theo dữ liệu** — BFS trên đồ thị có trọng số trả về đường ÍT CẠNH nhất chứ không phải đường RẺ nhất, và người dùng không có cách nào biết công cụ vừa chọn cái nào. (3) **PageRank rải lại điểm của node không có cạnh đi ra** — không rải thì tổng điểm tụt dần về 0 trong khi thứ tự xếp hạng vẫn «trông đúng», nên lỗi ấy sống rất lâu. (4) **Louvain KHÔNG xáo trộn thứ tự node** để tất định (NFR-MIN-02), và cái giá ấy — modularity thấp hơn bản chuẩn vài phần trăm — được nói ra kèm chính con số modularity. (5) **«Kích thước node theo PageRank» thành ĐỘ DÀY VIỀN** vì Mermaid không cho đặt kích thước, và chú giải nói thẳng điều đó — một bản đồ chú giải sai là bản đồ dẫn sai đường; ngưỡng dùng phép so NGẶT nên điểm hoà nhau rơi xuống mức dưới (bản đầu dùng `>=` và một hình sao làm CẢ đồ thị nhảy lên mức dày nhất). (6) **Bộ đo lại suýt nói dối**: bản đầu sinh đồ thị đều tăm tắp nên 2-hop đo được 0 ms; thêm node trung tâm (bậc 6.268) thì phép đo mới nói về ca mà trần 2 giây hỏi tới — cùng bài học đã trả giá ở PoC-M. **925 ✅ 27/08** (`HybridRetrieval`, 14 test lõi + 2 bài tự kiểm) — thứ đặc tả gọi là *trái tim GraphRAG zero-embedding*: score = α·norm(BM25) + (1−α)·G, G là tỷ lệ entity của chunk nằm trong vùng k-hop của entity trong câu hỏi, trọng số 1/hop. **NFR-KNW-05 đo trên corpus 1 GB: xếp lại top-500 xấu nhất 43,8 ms / trần 300 ms.** Năm chốt. (1) **Ràng buộc α = 1 phải trùng BM25 thuần** là cái neo đắt nhất của cả tính năng — nó bắt `norm` phải đơn điệu và bắt luật phá hoà giống HỆT bản BM25; có bài kiểm cả ở lõi lẫn trên giao diện, kể cả ca mọi ứng viên cùng điểm (min-max chia cho 0). (2) **Entity của chunk rút NGAY LÚC HỎI trên đúng 500 ứng viên**, không dựng bảng trước cho cả corpus — 690.000 chunk × 200 token là hàng trăm triệu phép tra để phục vụ 500 chunk. (3) **Không nhận ra entity nào thì rơi về BM25 thuần với MỌI α** — bản đầu để α = 0 cho ra thứ tự SỐ HIỆU TÀI LIỆU, một danh sách trông như bảng xếp hạng mà không mang tin gì, và tệ hơn là mã nói khác chính khối Phương pháp của nó. (4) **Giới hạn phải nói ra: phép lai chỉ XẾP LẠI thứ BM25 đã tìm ra** — nó cải thiện THỨ TỰ chứ không cải thiện ĐỘ PHỦ. (5) **Nhóm câu «đa hop» tách riêng** khi so A/B/C, vì trộn hai nhóm thì một cải thiện lớn trên vài phần trăm số câu bị trung bình hoá thành gần như không có gì. Một lỗi thật do bài tự kiểm bắt: mở corpus khác vẫn dùng đồ thị của corpus trước. **924 ✅ 27/08** (`GraphQuality`, `TextDistance`, `GraphQualityCard`, 21 test lõi + 1 bài tự kiểm): bảy phép kiểm — node mồ côi · cạnh trùng · cạnh treo · thuộc tính bắt buộc thiếu · đảo rời · nhãn trùng gần — ánh xạ sáu chiều DQR, chạy trong khối ` ```quality ` khi khối khai `graph:` (nên vào luôn cổng CLI). Năm chốt. (1) **Khối ```quality nay có BA chế độ** (bảng · corpus chunk · đồ thị) trên cùng một hàng rào và cùng một tấm thẻ điểm — khai cả `corpus` lẫn `graph` thì TỪ CHỐI, một khối chấm một thứ. (2) **`TextDistance` ra đời ở chỗ DÙNG CHUNG ngay lần đầu cần tới**: ba mã yêu cầu (FR-CLN-004, FR-KNW-923, 924) cần cùng phép so mờ, và dự án đã gặp mẫu «hai bản của một thuật toán» ba lần. Bỏ dấu ở đây là ĐÚNG (tìm nhãn đáng lẽ là một), ngược hẳn `BM25Tokenizer` vốn GIỮ dấu. (3) **Chiều không chấm được vẫn trả `nil`**: Tươi mới luôn nil; Hợp lệ nil khi KHÔNG node nào khai riêng (mọi node đều «chưa khai» là câu vô nghĩa, cho 0 điểm là chấm sai); Đầy đủ nil khi chưa khai `require_node`. (4) **Khối Phương pháp nói ra cái CHƯA kiểm được** — vi phạm schema đầy đủ chờ FR-KNW-917, hôm nay chỉ kiểm thuộc tính bắt buộc. (5) **Danh sách lỗi dùng LẠI panel kết quả tìm-trong-thư-mục** thay vì dựng bảng thứ hai: ngữ nghĩa khớp hẳn và người dùng đã học hành vi bấm-nhảy ở đó rồi. `DOTGraph` nay giữ MỌI thuộc tính, không chỉ ba cái có nghĩa với phần vẽ. **920 ✅ 27/08** (`ContextPackage`, 13 test lõi + 1 bài tự kiểm): ánh xạ ba chiều Chunk ↔ Entity ↔ Graph bằng MỘT lượt quét toàn corpus (khác 925 vốn chỉ rút entity trên 500 ứng viên — hai câu hỏi khác nhau đòi hai phạm vi khác nhau); phân tích phủ ba loại lỗ hổng; xuất gói ngữ cảnh JSONL `{query_seed, triples[], chunks[]}`. Bốn chốt. (1) **Phụ lục chỉ nêu BA TÊN TRƯỜNG**, phần còn lại tệp này định nghĩa và viết ra trong chú thích — kèm `hops` ở cả triple lẫn chunk, vì thiếu nó thì pipeline ngoài không phân biệt được «nói thẳng về seed» với «cách seed hai bước». (2) **Con số 0 phải nói ra vì sao nó bằng 0**: danh sách marker mặc định CHÍNH LÀ tập node đồ thị, nên «node không có entity đối ứng» rỗng theo cấu tạo chứ không phải vì đồ thị sạch. (3) **Cạnh nửa trong nửa ngoài KHÔNG vào gói** — một quan hệ thiếu một vế sẽ bị đọc thành quan hệ tới thực thể không tồn tại. (4) **Lỗi thật do bài tự kiểm bắt**: chính panel này xuất ra TAB MỚI, nên sau lệnh đầu tiên «tài liệu đang hoạt động» không còn là corpus và mọi lệnh sau im lặng ngừng chạy; nay panel gắn vào corpus MỘT LẦN lúc mở. **923 ✅ 27/08** (`EntityResolution`, 22 test lõi + 1 bài tự kiểm): chu trình gom biến thể — đề xuất cụm → bảng duyệt CSV → áp changeset ba đầu ra. Sáu chốt. (1) **«Không bao giờ tự merge» quyết định hình dạng cả tệp**: bước đề xuất KHÔNG sửa gì (có bài tự kiểm so tệp trên đĩa trước/sau), và không có bảng duyệt thì không có thay đổi nào. (2) **Bảng duyệt là CSV chứ không phải hộp thoại** — diff được, vào git được, sửa bằng chính bảng CSV của ứng dụng; cột `giu_nguyen` để LOẠI một cụm gom nhầm mà không phải xoá dòng. (3) **Đổi tên chỉ chạm ĐỊNH DANH TRỌN VẸN**, bỏ qua chú thích, và giá trị thuộc tính chỉ đổi khi khoá là `label` — `replacingOccurrences` sẽ đổi cả chữ «An» trong «Ban An toàn». (4) **Phép gộp được KỂ TÊN trước khi hỏi**: đổi tên trùng với node đã có LÀ phép gộp khi DOT đọc lại, và nó không hoàn tác được bằng cách gõ lại. Lượt chạy không người thì `Unattended.ask` trả `.abort` nên không gì được áp — có bài kiểm cho đúng vế ấy. (5) **Ba đầu ra sinh CÙNG LÚC từ một nguồn** (bảng alias, sửa đổi trên DOT, danh sách marker) và cả changeset là MỘT bước undo. (6) **Bằng số lần và bằng độ dài thì bản CÒN DẤU thắng** — không có tiêu chí này thì kết quả rơi vào thứ tự chữ cái, tức công cụ đề xuất bỏ dấu tiếng Việt của chính người dùng; bài tự kiểm bắt được, hai bài kiểm ở lõi trước đó thì không. **916 ✅ 27/08** (`GraphRefactor`, 24 test lõi + 1 bài tự kiểm): bốn phép tái cấu trúc — ĐỔI TÊN toàn cục · GỘP (hợp cạnh, khử cạnh trùng có báo cáo) · TÁCH · TRÍCH subgraph ra tệp mới — tất cả qua changeset duyệt được, MỘT bước undo. Sáu chốt. (1) **Sửa TẠI CHỖ theo vị trí byte, không dựng lại tệp từ `DOTGraph`**: dựng lại là xoá sạch chú thích, thứ tự và những thuộc tính bộ đọc chưa hiểu — một công cụ «tái cấu trúc an toàn» làm mất chú thích thì không ai dùng lần thứ hai. (2) **Dòng có NHIỀU câu lệnh thì BÁO kèm số dòng, không đoán**: bộ đọc giữ số dòng của cạnh chứ không giữ phạm vi byte của câu lệnh, nên trên `a -> b; a -> c;` phép xoá không xác định được chỗ; đoán bừa ở đó là làm hỏng tệp mà không ai thấy ngay. (3) **Vòng tự nối sinh ra bởi phép gộp được báo chứ không tự xoá** — cạnh ấy có thể đang mang nhãn người dùng cần đọc trước khi bỏ. (4) **Dạng chuẩn của phép GỘP dùng LẠI `EntityResolution.suggest` của 923** (hay gặp → dài → CÒN DẤU → thứ tự chữ); viết luật thứ hai ở tầng app thì cùng câu hỏi «bản nào là bản chuẩn» có hai câu trả lời, và bản KHÔNG dấu thắng ở một trong hai — đúng cái bẫy 923 đã vấp. Phép TÁCH cũng từ chối khi vùng chọn có hai ứng viên ngang nhau. (5) **Hộp hỏi hiện DIFF từng dòng chứ không chỉ hiện con số**, và phần bị cắt được nói ra: không ai từ chối được cái mình không nhìn thấy. (6) **Một lỗi thật do bài tự kiểm bắt, và nó là lỗi của cả cụm**: `dotGraph` do lượt vẽ cập nhật, mà lượt vẽ HOÃN 300 ms sau lần gõ cuối — nên ngay sau `undo` (hoặc trong 300 ms sau một phím) các phép này chạy theo số dòng của một văn bản đã không còn. Nay đọc lại đồ thị từ buffer ngay lúc bấm. **921 ✅ 27/08** (`ExternalScores`, 17 test lõi + 4 test khối + 1 bài tự kiểm): nhập tệp điểm JSONL `{query, chunk_id, score}` do pipeline embedding NGOÀI sinh ra và so song song với BM25 trên cùng bộ đánh giá — khoá `external:` của khối ` ```retrieval `, bảng delta theo câu và biểu đồ cột ba chỉ số hai hệ. **Ứng dụng KHÔNG tính vector** (ranh giới ADR-11), và câu ấy in trong khối Phương pháp. Năm chốt. (1) **Ghép theo CÂU HỎI, không theo `qid`** — tệp ngoài không biết `qid`; chuẩn hoá gọn khoảng trắng + thường hoá nhưng GIỮ DẤU, vì bỏ dấu là gộp hai câu hỏi khác nhau. (2) **Cả tấm thẻ chạy trên PHẦN GIAO**: câu nào tệp ngoài không có thì bị loại khỏi CẢ HAI lượt chạy chứ không tính 0 điểm cho hệ ngoài — một tệp ghép hụt vì thừa khoảng trắng sẽ làm hệ ngoài trông thảm hại, và đó là kết luận sai về một lỗi định dạng. Số câu bị loại in ngay cạnh bảng, kèm GỢI Ý câu gần giống (dùng lại `TextDistance`). (3) **Chiều điểm đọc từ TÊN TRƯỜNG người dùng khai** (`score`/`similarity` giảm dần · `distance`/`rank` tăng dần) và in ra cùng kết quả: đoán sai chiều thì bảng xếp hạng lật ngược và hệ ngoài ra gần 0 — một con số trông rất «có ý nghĩa». Tệp đổi trường giữa chừng thì DỪNG, không trộn hai thang. (4) **Id trong tệp ngoài mà corpus không có được đếm và kể tên** — dấu hiệu hai bên chạy trên HAI BẢN corpus khác nhau, cái hỏng tốn kém nhất của một phép so hai hệ. (5) **Một lỗi cũ tìm ra khi làm mã này**: bảng ánh xạ lỗi của `ReportRenderer` thiếu năm kiểu `Failure` của cụm tri thức, nên MỌI lỗi khối ` ```retrieval ` hiện ra thành «The operation couldn't be completed» từ FR-KNW-919 tới giờ; bài kiểm cũ chỉ ĐẾM số lỗi nên không ai thấy. Nay có bài kiểm soi chính câu chữ. **Mười mã còn lại XONG 28/08/2026** — `903` Chunking Preview (ba lối cắt; `overlap` bị kẹp dưới `size`, và không lối nào cắt giữa một ký tự UTF-8) · `904` grammar + thẩm định DOT/Cypher/Turtle/GraphML (thẩm định gọi CHÍNH bộ đọc thật, không viết bản kiểm thứ hai) · `906` N-Triples → bảng bốn cột qua `CSVEngine.escape` · `907` Corpus SQL chạy thẳng trên JSONL/Parquet bằng `read_json_auto`, không dựng bộ đệm CSV trung gian · `908` đánh dấu entity (khớp DÀI NHẤT, biên từ, thường hoá KHÔNG phá dấu tiếng Việt và GIỮ NGUYÊN độ dài byte — bản đầu thường hoá theo ASCII nên «CÔNG TY» không bao giờ khớp) · `909` prompt/tool (frontmatter gấp được, grammar Jinja2, JSON Schema; hai lỗi thật: `.whitespaces` KHÔNG gồm `\n` nên mọi tệp trả `nil`, và JSONPath nội bộ lệch dạng với `JSONIndex.path` nên mọi lỗi rơi về dòng 0) · `910` chuyển đổi tri thức kèm xem trước 5 dòng · `912` API script `jsonl.*` và `graph.*` — **mọi hàm nhận VĂN BẢN, không nhận đường dẫn**, nên script không mở rộng được vùng tệp mà nó với tới · `917` schema/ontology YAML (`between: []` nghĩa là MỌI cặp) · **`915` soạn Graph trực quan**: `GraphEdit` trả `[TextEdit]` chứ không sửa gì, nên buffer vẫn là nguồn sự thật DUY NHẤT (SAD Hình 4); kéo giữa hai node trên hình → thêm cạnh, double-click → sửa nhãn, cả hai sau một CÔNG TẮC tắt mặc định — không có công tắc thì mọi cú kéo để bôi đen chữ đều lặng lẽ sửa tệp. Bốn chốt. (1) **Chữ trên hình là NHÃN, thứ đi vào phép sửa là ĐỊNH DANH**; hai node cùng nhãn thì TỪ CHỐI kèm tên cả hai chứ không lấy cái đầu tiên — đoán sai ở đây là sửa nhầm node. (2) **Xoá node xoá luôn mọi cạnh chạm nó**, vì cạnh treo làm DOT tự sinh lại node và thứ vừa xoá hiện lại ở lượt vẽ sau. (3) **Thụt lề đọc từ chính tệp** và lấy cái PHỔ BIẾN nhất, không lấy của dòng đầu — dòng đầu hay là một chú thích căn lề trái. (4) **Bốn phép cũng có mặt trong danh sách lệnh** để tới được bằng bàn phím (NFR-USE-03). Đối chứng âm đã chạy: phá cầu nối JavaScript thì hai bài cử chỉ ĐỎ, hai bài còn lại vẫn xanh đúng như thiết kế. |
| FR-AGT (10) | 0 | 10 | 5 | `grep Agent\|Keychain` → 0 file |
| FR-PY (9) | 0 | 9 | 6 | `grep PyRuntime` → 0 file |

### 5.3 Theo Phase (mẫu số v2.2)

Bảng này SINH bằng máy từ chính tệp SRS (`01_SRS_GEditor_macOS_v2.2.docx`), không gõ tay:
`scripts/phase-table.py` trích 167 hàng FR kèm cột Ưu tiên và Phase, rồi ghép trạng thái. Cách
cũ — đếm tay — đã từng cho ra "87 xong" khi con số thật là 101.

> **Và nó vừa tái diễn, ở đúng bảng này.** Câu "sinh bằng máy" ở trên đúng vào ngày nó được
> viết, nhưng KHÔNG có script nào trong kho làm việc ấy — nên bảng được sửa tay qua nhiều phiên
> và trôi: hôm 27/08/2026 cột ✅ của nó cộng lại ra **112** trong khi bảng nhóm §5.2 cộng ra
> **117**. Năm mã chênh nhau đã nằm im ở đó nhiều phiên, và không ai nhìn ra vì từng dòng đều
> hợp lý. Nay `scripts/phase-table.py` sinh lại bảng, và `--kiem` đối chiếu được trong CI.

| Phase | ✅ | ◐ | ⊘ | ⛔ | Tổng |
|---|---|---|---|---|---|
| 1 | 46 | 0 | 0 | 0 | **46 — khép** |
| 1–2 | 4 | 0 | 0 | 0 | **4 — khép** |
| 1–3 | 1 | 0 | 0 | 0 | **1 — khép** |
| 2 | 29 | 0 | 0 | 0 | **29 — khép** |
| 2–3 | 3 | 0 | 0 | 0 | **3 — khép** |
| 3 | **39** | 1 | 0 | 0 | 40 |
| 3–4 | 2 | 0 | 0 | 0 | **2 — khép** |
| 4 | 22 | 0 | 1 | 0 | **23 — khép** |
| 5 | 0 | 0 | 0 | 10 | 10 |
| 6 | 0 | 0 | 0 | 9 | 9 |

**Ba chỗ tài liệu này từng nói sai**, tìm ra bằng cách đối chiếu từng mã yêu cầu với mã nguồn:

1. FR-CORE-007 ghi "nhân đôi" là xong — thật ra không có hàm nào làm việc đó; `duplicateLineIndices`
   là hàm TÌM dòng trùng cho khử trùng lặp.
2. FR-CORE-010 ghi ✅ — lõi có đủ 8 kiểu case nhưng menu chỉ nối 3.
3. §4 liệt Document Map, Function List, Folder as Workspace, code folding là "phần còn lại"
   trong khi §3.3 ngay trên đã đánh dấu chúng xong.

Bài học đã vào bộ tự kiểm: một bài soi CHÍNH THANH MENU chặn mục có `action: nil`, và một bài
chặn phím tắt trùng. Tính năng "có chỗ bấm mà không có gì phía sau" là loại nợ khó thấy nhất, vì
nó trông giống hệt tính năng đã xong.

---

## 5bis-e. Chín vế đặc tả nằm dưới một dấu ✅ — 05/09/2026

Đợt rà thứ hai trong ngày hỏi một câu khác: *bảng nói xong, nhưng đặc tả đòi gì?* Cách làm là
đối chiếu **từng vế** của cả **38 mã P0** với mã nguồn — không đọc bảng, không tin chú thích.

Phép đối chiếu tự động (mọi mã FR trong SRS ↔ dấu vết trong `Sources/` và `Tests/`) cho **0
lệch**: mã nào bảng ghi ✅ cũng grep ra được. Nhưng «có nhắc tới mã FR» ≠ «làm đủ vế» — và chín
chỗ sau lộ ra khi đọc từng câu đặc tả:

| Mã | Vế thiếu | Nay |
|---|---|---|
| FR-SRCH-111 | cú pháp «dòng,cột» và offset | `GoToTarget` ở lõi, 7 test |
| FR-CORE-018 | offset con nháy · tổng độ dài | hai mục trên thanh trạng thái |
| FR-AUTO-602 | batch theo **file mask** | ô mask trong hộp chọn thư mục |
| FR-SRCH-105 | lịch sử nhiều lượt tìm · xuất ra tệp | popup lượt + nút Xuất (định dạng `grep -n`) |
| FR-CORE-009 | thụt lề **theo từng ngôn ngữ** | `Settings.languageIndent` |
| FR-CORE-002 | chọn khối cột bằng **bàn phím** | Option+Cmd+mũi tên |
| FR-FMT-505 | đánh giá XPath · tự đóng thẻ | `XMLTool.evaluateXPath` · `closingTag` |
| FR-DOC-314 | Duplicate · Rename · Move · Lưu-thành chọn bảng mã | bốn lệnh mới ở menu File |
| FR-FMT-501 | fallback TextMate · mốc 60 ngôn ngữ | **ADR-17, chờ chốt** — xem dưới |

Và một chỗ **ngược lại**: `FR-DOC-302` bị ghi là còn thiếu «cử chỉ kéo thả tab giữa hai pane»,
nhưng đó là một **chú thích đã trôi** — `dropTab` nhánh 3 làm đúng việc ấy từ lâu và có bài kiểm
đi qua. Suýt viết lại một tính năng đã có, đúng chuyện đã xảy ra với `FR-MIN-006` hôm 04/09.
**Chú thích tự khai còn nợ, sau khi nợ đã trả, đọc lên giống hệt một khoản nợ thật.**

### Ba lần bài kiểm bắt lỗi trong chính mã vừa viết

1. `GoToTarget` — `split` mặc định VỨT phần rỗng, nên `,5` và `5,` đều đọc thành «dòng 5»: một
   chuỗi gõ hụt thành một lệnh hợp lệ, con nháy nhảy đi mà người dùng không ra lệnh ấy.
2. Chọn khối cột bằng bàn phím — bản đầu đọc lại vị trí từ CON NHÁY, mà con nháy đã bị chính
   khối chọn dời đi; ba dòng được chọn nhưng **cả ba đều rỗng**.
3. Mục «cỡ tài liệu» làm thanh trạng thái không co lại được nữa, nên bề rộng tối thiểu của CẢ
   CỬA SỔ nhích lên — bài kiểm ngắt dòng bắt được. **Một mục thông tin không được quyết định
   cửa sổ hẹp tới đâu.**

### Ba cổng bắt ba thiếu sót của chính đợt này

Bốn lệnh mới thiếu **biểu tượng menu**, thiếu **trang trợ giúp**, và 44 khoá dịch mới kéo 32
bảng ngôn ngữ tụt xuống **93%** (ngưỡng 95%). Cổng thứ ba là cổng đắt nhất: phải dịch **86
khoá** — 42 tích từ các phiên trước — sang cả 32 thứ tiếng. Đã dịch xong; nợ dịch còn **359**
và mốc hạ theo.

### FR-FMT-501 KHÔNG viết mã — nó là quyết định phạm vi

Đặc tả đòi ba vế: 20 ngôn ngữ Phase 1 (✅), **60 ngôn ngữ Phase 3**, và **fallback TextMate qua
Oniguruma**. Hai vế sau không phải việc một buổi: `libTreeSitterHeavy.dylib` nặng **18 MB cho ba
grammar**, và khởi động đã ở 465 ms trên trần 500. `docs/adr/ADR-17` nêu ba đường kèm cái giá đã
đo và đề xuất một; **anh chốt trước khi ai viết dòng mã đầu tiên.**

## 5bis-d. Rà trước phát hành 05/09/2026 — bốn lỗi thật, tất cả nằm giữa TAB và CỬA SỔ

Đợt rà đặt đúng một câu hỏi: *sản phẩm còn vấn đề gì chặn phát hành*. Trả lời bằng cách chạy hết
mọi cổng đang có, rồi đọc mã ở những chỗ cổng không với tới.

### Ba lỗi cùng một hình dạng

Một trạng thái mô tả **tài liệu** lại được cất ở **cửa sổ**. Cửa sổ có nhiều tab, nên mỗi biến
như thế là một lần tab này nói thay tab khác:

| Biến | Người dùng thấy gì |
|---|---|
| `csvModeOverride` | bật chế độ CSV (hoặc chỉ bấm ⌥⌘T, vì lệnh ấy tự bật giúp) rồi mở tệp `.json` ở tab mới → thanh trạng thái ghi «CSV · dấu phẩy» cho tệp JSON, và khung soạn thảo tô màu cột lên nó |
| `tailWatcher` | bật theo dõi log ở tab 1, sang tab 2 gõ dở → dòng log kế tiếp **nạp lại tab 2 từ đĩa** và đặt nó chỉ đọc. Phần vừa gõ mất, không thông báo nào, nguyên nhân nằm ở một tab không nhìn thấy |
| `csvIndex` | bảng OFFSET BYTE của tài liệu cũ sống qua lần đổi tab — chưa nổ vì `CSVRowIndex.values` tình cờ kẹp lại theo buffer mới, nhưng `rowStart` và `fields` thì không có phép kẹp ấy |
| **13 panel phân tích** | bảng «Kiểm tra dữ liệu: 2 lỗi ở cột y» nằm nguyên đó khi đã sang một tệp `.txt` không có cột nào, và ô tô đỏ trên bảng CSV đánh theo số hàng của tài liệu cũ |

Hai cái đầu nay thuộc về `EditorTab`; `csvIndex` bị xoá khi đổi tài liệu (cùng chỗ với dấu dòng
và dấu gạch lỗi); mười ba panel đóng lại qua `hideDocumentPanels()`, gọi cạnh
`hideAllViewModes()`. **Câu hỏi để hỏi lần sau, trước khi thêm một `private var` vào
`MainWindowController`: nó mô tả cửa sổ, hay mô tả tệp đang mở?**

Và một hệ quả đáng ghi: luật mới làm đỏ đúng MỘT bài kiểm cũ — phân cụm vẽ biểu đồ **rồi** mới
mở tab kết quả, nên chính cú mở tab ấy dọn mất biểu đồ vừa vẽ. Sửa bằng cách đảo thứ tự, và thứ
tự mới cũng đúng hơn về mặt sản phẩm: hình nằm cạnh bảng `cluster_id` chứ không nằm lại ở tệp
nguồn. **Một bài kiểm đỏ vì luật mới không phải lúc nào cũng là luật sai — ở đây nó chỉ ra một
thứ tự đã sai sẵn.**

### Lỗi thứ tư: cổng chỉ canh được đúng thứ nó soi

Bốn mục cuối của thanh trạng thái (`mode`, `language`, `tabWidth`, `readOnly`) rơi vào
`default: break` — bấm vào không có gì xảy ra. Đây **đúng loại lỗi** mà bài kiểm "mục menu không
có hành động" đã chặn từ 26/08; nó sống sót vì cổng ấy soi thanh **menu**, còn đây là thanh
**trạng thái**.

Chỗ chặn tái diễn lần này không phải một bài kiểm thứ hai mà là **trình biên dịch**:
`handleStatusBarClick` không còn nhánh `default`, nên thêm một `Segment` mà quên nối là lỗi lúc
dựng. Rẻ hơn và chắc hơn mọi bài kiểm viết ra để canh cùng chuyện ấy.

Bốn mục ấy nay làm việc thật: chọn lại **dấu phân tách CSV** (phép đoán sai là lỗi im lặng nhất
của cả nhóm CSV, và trước nay không có đường nói lại), chọn **ngôn ngữ tô màu** (cần cho tệp
không đuôi và tệp mang đuôi nói dối), đổi **độ rộng tab**, và **nói ra vì sao tài liệu chỉ đọc**.

**Sách trợ giúp đã hứa hai trong bốn mục ấy từ trước.** `HelpVI+NgonNgu` viết *"Đổi tay được ở
thanh trạng thái"*, và chú thích của `csvDialect` trong mã ghi *"người dùng đổi được ở status bar
(chưa nối)"* — một lời hứa với người đọc sách và một ghi chú nợ với người đọc mã, cùng nói về
một chỗ, và không cổng nào bắt được vì cả hai đều là chữ. Cách bắt loại này rẻ nhất vẫn là đọc
lại chính những chú thích mình viết.

Và phép đổi dấu phân tách ở thanh trạng thái **không phải** lệnh `CSV ▸ Đổi dấu phân tách…` đã
có: lệnh kia GHI LẠI cả tệp, mục mới chỉ ĐỌC LẠI. Đúng cặp «diễn giải lại» / «chuyển đổi» mà menu
bảng mã đã chia từ lâu — vế «diễn giải lại» của CSV là vế trước nay thiếu, và nó mới là vế người
dùng cần khi phép đoán sai. Sách trợ giúp nay nói rõ chọn cái nào khi nào.

### Hai lần bộ đo suýt nói dối, trong cùng một buổi

1. **Phép hỏi vòng qua hậu quả.** Bài kiểm chỉ mục CSV bản đầu hỏi *"panel kiểm tra có gọi đúng
   tên cột không"* → **XANH**, trong khi chỉ mục của tab trước vẫn còn nguyên 201 hàng. Phải in
   thẳng con số ra mới thấy. Bài kiểm nay hỏi thẳng cái đang sai.
2. **Bài kiểm không đi qua dây nối.** Bản đầu của bài "bốn mục thanh trạng thái" gọi thẳng
   `buildModeMenu()` — nó vẫn xanh cả khi dây nối từ cú bấm bị cắt, mà **dây nối đứt chính là
   hình dạng của lỗi**. Nay nó bấm đúng cái nút, và `present(_:from:)` cất menu lại thay vì bung
   ra ở lượt chạy không người (`NSMenu.popUp` cũng là một vòng lặp modal, cùng bẫy với `NSAlert`
   mà `Unattended` sinh ra để chặn).

Cả ba bài kiểm mới đều đã **xác nhận đỏ được** bằng cách hoàn nguyên đúng dòng vừa sửa.

## 5bis-c. Soát lại 28/08/2026 — chạy thật mọi bộ đo, rồi đối chiếu từng mã với mã nguồn

Phiên này **không viết tính năng nào**. Nó chạy lại toàn bộ bộ đo trên `a7d6d7d` và hỏi một câu
duy nhất: *trang này còn nói đúng về kho mã không?* Câu trả lời là **có, ở phần quan trọng nhất —
và không, ở sáu chỗ**.

### Đo lại được gì

| Phép đo | Kết quả 28/08 | Trang này từng ghi |
|---|---|---|
| `swift build` | ✅ 0 lỗi · **16 cảnh báo** ở mã của ta (xem cuối mục) | — |
| `swift test` | ✅ **2099 · 0 lỗi** · 30,4 s | 1746 |
| `run-self-test.sh` | ✅ **242/242** | 215 |
| `run-coverage.sh` | ✅ **93,26%** | 93,04% |
| `check-core-no-ui.sh` | ✅ 8/8 cổng tĩnh xanh · 470 chuỗi chưa dịch, đúng mốc | 472 |
| `phase-table.py --kiem` | ✅ khớp | — |

Không có gì đỏ. **Sản phẩm đứng vững; thứ trôi là trang giấy.**

### Sáu chỗ trang này nói khác mã

1. **`FR-FMT-503` đang ✅ mà thiếu một vế — và đây là mã P1, Phase 1, tức nằm TRONG phạm vi
   phát hành.** Đặc tả đòi ba thao tác: *"Fold All / Unfold All / fold theo cấp"*. Hai cái đầu
   có thật và có bài tự kiểm; cái thứ ba không có ở đâu cả — `foldAll` chỉ gấp các vùng NGOÀI
   CÙNG, `FoldRange` không mang khái niệm cấp, menu không có mục nào chọn cấp. Đã hạ xuống ◐,
   và **Phase 1 vì thế mở lại**.
2. **Nó cũng là mã ✅ duy nhất không có sợi dây nào nối yêu cầu ↔ mã.** Chuỗi `FR-FMT-503` không
   xuất hiện **ở bất kỳ đâu** trong kho — không trong `Sources/`, không trong `Tests/`, không
   trong tài liệu ADR hay CHANGELOG. Comment nhóm menu gấp mã ở `AppDelegate.swift` gắn nhãn
   `FR-FMT-507`. 131 mã ✅ còn lại đều grep ra được. *Bài học: mã yêu cầu không được nhắc tên
   trong mã nguồn là mã yêu cầu không ai kiểm chứng được — và nó đúng là mã bị ghi quá.*
3. **Dòng "Theo ưu tiên" ở §5 trôi mất 12 mã** vì `--kiem` không soi tới nó. Đã sinh dòng ấy
   bằng máy và đưa vào cổng — xem ghi chú `priority_line()` trong `scripts/phase-table.py`.
4. **§3bis trôi theo hướng NGƯỢC lại: nó ghi thấp hơn sự thật.** Sáu NFR bị kê là "chưa có mã
   để đo" thật ra đã có phép đo chạy được và ĐẠT (QRY-02 · DQR-01 · MMD-01 · KNW-02 · KNW-03 ·
   KNW-04), vì các cụm FR sinh ra chúng khép sau ngày dòng ấy được viết. Tổng NFR đổi từ
   *23 đạt · 11 một phần · 27 chưa* thành **29 · 12 · 20**.
5. **`NFR-MMD-02` phải hạ xuống ◐.** mermaid 11.17.2 nằm trong bundle, pin đúng, có bài tự kiểm
   đòi trang chạy đúng bản đã vendor — nhưng chỉ tiêu còn vế *"ghi trong About"*, và
   `showAbout()` chỉ hiện phiên bản app · kiến trúc · SIMD · kênh phát hành.
6. **`NFR-QRY-01` bị mô tả rộng rãi hơn số đo.** Dòng cũ ghi "màn hình đầu 3,5–5 ms" và "quét
   hết 583–1028 ms". Tệp kết quả có **năm** phép lọc: một phép mất **919 ms** ở màn hình đầu và
   mang `pass: false`, hai phép quét hết vượt trần 2 giây. Điểm trượt ấy **đã được biết và cố ý
   phơi ra** — `run-clean-kpi.sh` in ❌ mỗi lần chạy mà không làm script đỏ, vì quét tuần tự
   không thể đạt trần khi kết quả duy nhất nằm cuối file. Cái sai không nằm ở bộ đo mà ở chỗ
   trang này trích lại nó bằng khoảng số đã bỏ đi hai đầu chậm nhất.

### Một chỗ trang này nói ĐÚNG, đáng ghi lại

Sáu mã ⛔ có tên trong `Sources/` — kiểm lại từng chỗ thì **cả sáu đều là ghi chú trung thực**,
không phải mã ma: `GraphQuality.swift` nói thẳng "chờ FR-KNW-917, hôm nay chỉ kiểm được thuộc
tính bắt buộc", `BM25Tokenizer` nói chưa tách từ ghép vì FR-MIN-006 chưa có mã và **có một bài
kiểm đòi câu ấy phải còn nguyên trong `methodology`**. Đó là cách đúng để một mã chưa làm hiện
diện trong kho.

### Hai ◐ vừa mở ra đã khép lại trong cùng ngày

**`FR-FMT-503` — «fold theo cấp», và Phase 1 khép lại.** Cấp lồng nay là khái niệm của LÕI
(`FoldRanges.levels(of:)` · `ranges(atLevel:in:)` · `outermost(in:)` · `levelCount(of:)`), và
`foldAll` gọi chính hàm ấy thay vì tự lọc vùng ngoài cùng — thuật toán dùng chung ra đời ở chỗ
chung ngay lần đầu. Bốn quyết định đáng ghi:

1. **Cấp đếm theo SỐ VÙNG BAO, không theo độ sâu thụt lề.** Một hàm thụt 8 dấu cách vì nằm trong
   `if` nằm trong `for` vẫn là khối cấp 1 nếu hai cái kia không sinh vùng gấp nào. Người dùng
   bấm "cấp 2" là nói về cái cây họ thấy ở lề trái, không nói về dấu cách.
2. **Cấp N trả về ĐÚNG cấp N**, không kèm phần bên trong — cùng lý do `foldAll` chỉ lấy vùng
   ngoài cùng: vùng ngoài đã giấu phần trong rồi, gấp thêm chỉ khiến mở ra phải bấm nhiều lần.
3. **Gấp cấp THAY THẾ trạng thái đang gấp**, không cộng dồn. Bấm cấp 1 rồi cấp 2 là đổi cách
   nhìn, không phải gấp thêm.
4. **Cấp sâu hơn tài liệu thì NÓI RA số cấp thật.** Bấm cấp 5 trên tài liệu sâu 2 cấp mà màn
   hình không đổi thì trông y hệt một lệnh hỏng.

Menu là submenu ⌥⌘1…⌥⌘8 (tám cấp như Notepad++), chèn ngay sau "Bỏ gấp tất cả" bằng cách **tìm
theo selector chứ không theo chỉ số cứng** — một mục thêm vào menu View ngày mai sẽ làm chỉ số
cứng chèn nhầm chỗ, im lặng. 4 test lõi + 2 bài tự kiểm.

**`NFR-MMD-02` — phiên bản mermaid trong About.** Ghép ở tầng app (`AppDelegate.aboutCredits`)
chứ không nhét vào `diagnosticSummary` của lõi: bản kê mermaid là tài nguyên bundle, mà lõi
không được biết gì về bundle (NFR-MNT-01). Không đọc được bản kê thì **nói ra**, đừng bỏ vế ấy
đi im lặng — một hộp About thiếu dòng ấy trông y hệt hộp About của bản dựng lành lặn. 1 bài tự
kiểm, và nó đòi cả phần chẩn đoán cũ phải còn nguyên.

**Và submenu đầu tiên của sản phẩm làm lộ ra đúng bài học của phiên này.** Ba bài tự kiểm menu
đều chỉ đi MỘT tầng (`mainMenu.items` → `submenu.items`, hết), nên tám mục mới sẽ vô hình với
cả ba: một mục quên nối hành động, hay một phím tắt giành mất của lệnh khác, đều lọt. Đã cho hai
bài đi ĐỆ QUY qua một hàm dùng chung (`SelfTest.allMenuItems(under:path:)`). Bài thứ ba — kiểm
bản dịch — **cố ý để nguyên một tầng**: nó tra ngược NGUYÊN nhan đề trong bảng dịch, mà nhan đề
"Cấp 1" dựng bằng `String(format:)` nên không phải một khoá; chỗ giữ nó là dòng `"Cấp %d"` trong
`Localization.swift`. Cổng dịch đã bắt được đúng hai chuỗi mới quên dịch trong phiên này.

### Cổng chặn khoá riêng vào kho — thêm 28/08/2026

Phát sinh từ một câu hỏi rất thật của anh: *"đẩy khoá vào git luôn cho khỏi mất khi máy hỏng,
kho private mà"*. Nhu cầu đúng, chỗ cất thì sai — và ba lý do đều **cụ thể với kho này**, không
phải khẩu hiệu chung:

1. **Kho được chép sang máy người khác ở mỗi lần push.** `ci.yml` chạy trên runner `macos-14`
   của GitHub với `actions/checkout@v4`. "Private" nói về ai đọc được trang web, không nói về
   nơi tệp đi tới.
2. **Commit không hoàn tác được.** Xoá ở commit sau không xoá khỏi lịch sử; muốn sạch thật thì
   phải viết lại lịch sử **và vẫn phải đổi khoá**.
3. **Khoá EdDSA không phải mật khẩu — nó là quyền chạy mã trên máy mọi người dùng.** Ai giữ nó
   cũng ký được một binary bất kỳ thành "GEditor 1.1", và mọi bản đã cài sẽ tự nuốt, im lặng.
   Đó đúng hình dạng tấn công mà `PluginTrust` (NFR-SEC-03) từ chối theo thiết kế. Để khoá cập
   nhật trong kho là gỡ chính lập luận ấy ở tầng trên nó một bậc.

Nên thay vì đưa khoá vào kho, phiên này dựng hai thứ: **`scripts/check-no-secrets.sh`** (bốn mẫu
dò — PEM · EdDSA Sparkle · mật khẩu notarytool · danh tính ký gán cứng — cộng đuôi tệp chứa
khoá) và **`docs/khoa-va-ky.md`** (bốn khoá, vai từng cái, sinh ở đâu, cất hai bản hai chỗ, và
mất thì hậu quả là gì). Ba chốt đáng nhớ:

- **Bộ dò phải tự chứng minh nó bắt được.** `--tu-kiem` bắn mẫu vật giả vào từng mẫu và đòi
  kêu, rồi bắn một dòng mã bình thường và đòi im — một bộ dò không bao giờ kêu và một bộ dò
  hỏng cho ra cùng một kết quả. Đã kiểm ĐỎ thật: dựng ba mẫu vật (`.pem`, khoá Sparkle giả,
  tệp `.p12` rỗng), `git add`, cổng bắt cả ba rồi mới dọn đi.
- **Chính tệp dò không được kích hoạt mẫu của nó**, nếu không thì cách sửa dễ nhất là tự loại
  mình khỏi phạm vi quét — tức đục một lỗ ngay giữa cổng. Mẫu vật vì thế **ghép lúc chạy**, và
  **không tệp nào được loại trừ**, kể cả nó. *Luật này không phải giả định: móc pre-commit đã
  **bắt đúng tác giả của nó** ở lần commit đầu tiên — mẫu vật `notarytool` viết liền một chuỗi
  nên trúng chính cái mẫu nằm ngay trên nó. Cách sửa đúng là chẻ mẫu vật ra, không phải nới mẫu
  dò; nới mẫu dò là đổi một cổng thật lấy một cổng dễ chịu.*
- **CI chỉ BÁO, móc pre-commit mới NGĂN.** Lúc CI đỏ thì commit đã tồn tại và vẫn phải đổi
  khoá. Móc chỉ đọc và từ chối, không tự sửa — một móc tự sửa thứ nó đo là móc không còn đo
  được gì. `.gitignore` cũng thêm luật, nhưng nó chỉ giúp khi TÊN tệp đúng khuôn; cổng mới là
  thứ đọc NỘI DUNG.

*Việc này không đóng được `NFR-SEC-01` — vế "kênh tự cập nhật Sparkle 2" vẫn còn nguyên.*

**Và sau đó anh vẫn chọn đưa khoá vào kho — quyết định ấy còn hiệu lực, nhưng tệp thì đã gỡ, vì
khoá KHÔNG DÙNG ĐƯỢC.** Khoá sinh bằng ed25519 chuẩn, bố cục `seed‖public` của libsodium, nhìn
thì đúng; đem `bin/sign_update` của chính Sparkle 2.9.6 ra thử thì nó từ chối, kèm một thông báo
tự mâu thuẫn (*"phải 64 hoặc 96 byte… thực tế là 64 byte"*). Thử tiếp ba bố cục 96 byte: cả ba
ký được nhưng **không chữ ký nào thẩm định nổi** bằng khoá công khai tương ứng — kiểm độc lập,
có đối chứng âm. Gỡ đi vì **một khoá ký không chạy mà trông như đã xong thì tệ hơn không có
khoá** — đúng loại nợ §5.3 bắt được nhiều lần. Đường đúng là `generate_keys` của Sparkle, cần
anh chạy vì Keychain sẽ hỏi quyền; chi tiết ở `docs/khoa-va-ky.md` §2bis.

**Hai lần trong một phiên, cùng một kết luận: THỬ BẰNG VẬT THẬT.** Cổng để lọt khoá thật ở lần
thử đầu; và bố cục khoá thì mọi lập luận đều đúng cho tới lúc chạy công cụ của Sparkle. Đọc mã
và đọc tài liệu định dạng đều không thay được việc đem vật thật ra thử.

**Chi tiết vế thứ nhất: khoá thật ĐI LỌT cổng ở lần thử đầu tiên.** Mẫu "EdDSA (Sparkle)" đòi từ
khoá nằm cùng DÒNG với chuỗi base64, mà một tệp khoá thật thì để chú thích ở mấy dòng đầu và
khoá trần ở dòng cuối. Đọc mã không thấy lỗ ấy; **đem một khoá thật ra thử mới thấy**. Đã thêm
hai mẫu (dòng base64 trần đúng cỡ ed25519, và từ khoá trong ĐƯỜNG DẪN) — cổng nay 5 mẫu, vẫn 0
báo nhầm trên toàn kho. Đây là lần thứ tư trong ngày cùng một bài học: *cổng chỉ canh được đúng
thứ nó soi.*

### Ba món nợ chặn phát hành — hai đã trả trong ngày

**Cập nhật cuối ngày 28/08/2026.** Mục này ban đầu ghi "chưa mục nào nhúc nhích"; tới cuối phiên
thì **hai trong ba đã xong**:

| Nợ | Trạng thái |
|---|---|
| Sparkle 2 ký EdDSA | ✅ **mã · khoá thật · appcast thật** (ADR-16). `scripts/make-appcast.sh` đóng gói và sinh feed đã ký, có bước tự thẩm định lại chữ ký bằng chính khoá trong bản giao. **Bắt được một cái bẫy của công cụ Sparkle:** đưa `generate_appcast` một khoá không khớp thì nó chỉ in `Warning:`, ghi feed KHÔNG chữ ký, và **thoát 0** — script ta thoát 1. Còn lại đúng hai thứ, đều ngoài kho mã: **máy chủ HTTPS** cho `geditor.code247.ai`, và **Developer ID** để ký thật |
| Hai panel 0% độ phủ | ✅ **đóng** — 4 bài tự kiểm mới, tầng app 72,47 → 75,58%, mốc nâng lên 75,0 |
| 470 chuỗi chưa dịch | ◐ **giảm còn 368** — dịch TRỌN bốn cụm: Bàn làm sạch (29) · mặt CSV (18) · lệnh File/phiên/bảng mã (34) · **mẫu báo cáo làm sạch** (21). Mốc hạ 470 → 441 → 423 → 389 → 368. **Anh chốt 28/08: báo cáo ĐI THEO ngôn ngữ giao diện** — quyết định sản phẩm, vì báo cáo là tài liệu người dùng gửi đi nên phải cùng thứ tiếng với người nhận. Hai cổng mới sinh ra từ việc này: so bội số ô định dạng giữa hai ngôn ngữ, và hỏi thẳng bảng dịch xem khoá NHIỀU DÒNG có tra được không (lệch một dấu cách thì `L()` im lặng trả nguyên bản tiếng Việt) — cả hai đã xác nhận đỏ được. Còn **368**, `MainWindowController` chiếm 309 |

*Bản ghi gốc của phiên, giữ lại:* `grep Sparkle` → 0 file · 470
chuỗi chưa dịch · `SelfTest.swift` nhắc tên `ColumnEditorPanel` và `SearchResultsView` đúng
**0 lần**. Chín việc cần anh ở §6 thì **không mục nào được đánh dấu đã làm** — phần lớn là việc
kiểm TAY nên kho mã không thể tự trả lời thay, đó chính là lý do chúng nằm ở §6. Mốc App Store
22/08/2026 đã trôi qua sáu ngày, và thứ chặn nó không phải mã — Phase 1–2 đã sẵn sàng từ 26/08.

### Lỗ hổng phát hành: bundle thiếu `geditor-plugin-host`

**`FR-PLUG-702/703/704` đánh ✅ mà không chạy được trong bất kỳ bản nào người dùng nhận.**
`build-universal.sh` **chưa bao giờ** chép `geditor-plugin-host` vào bundle, trong khi
`NativePluginBridge.hostCandidates()` tìm nó ở `Contents/SharedSupport` rồi `Contents/MacOS`.
Tính năng chạy khi khởi động từ `.build` — nơi tiến trình phụ nằm cạnh binary — và **im lặng
biến mất** ở mọi bản giao.

**Vì sao sống lâu đến thế:** sáu bài tự kiểm plugin XANH ở binary trần và ĐỎ trong bundle, mà
`run-self-test.sh` mặc định chạy binary trần và **CI chưa từng chạy đường `--bundle`**. Lộ ra
tình cờ — có khoá Sparkle thật nên tôi chạy tự kiểm trong bundle để xác nhận kênh cập nhật, và
sáu bài kia đỏ theo. Đã kiểm nó có TRƯỚC thay đổi của phiên: stash sạch, dựng lại, vẫn đỏ đúng
sáu bài.

**Sửa, ba chốt đáng nhớ:**

1. **Chép tiến trình phụ vào `Contents/MacOS/`, CHỈ bản tải trực tiếp.** Bản App Store không
   được mang nó — một tiến trình biết `dlopen` mã lạ nằm trong bundle nộp lên là mời từ chối,
   dù nó không bao giờ chạy. Có bước CI riêng canh điều đó.
2. **Bỏ `codesign --deep`, ký TỪ TRONG RA NGOÀI.** `--deep` ký mọi thứ lồng bên trong bằng CÙNG
   entitlement với app — mà tiến trình phụ cần `disable-library-validation` còn app chính tuyệt
   đối không được có (ADR-12). Với `--deep` thì hoặc app bị nới hàng rào, hoặc tiến trình phụ
   mất quyền nó cần; không có đường thứ ba. Nay: thư viện → tiến trình phụ (entitlement RIÊNG)
   → bundle sau cùng. **Kiểm cả hai chiều chứ không tin:** app chính **0** khoá ấy, tiến trình
   phụ **1**, và chữ ký bundle vẫn `valid on disk`.
3. **CI nay chạy tự kiểm CẢ HAI đường** — binary trần và bundle đã ký.

Sau khi sửa: **248/248 trong bundle** (trước 242/248).

*Bài học thứ tư cùng loại trong ngày: **cổng chỉ canh được đúng thứ nó soi** — ở đây thứ không
được soi là chính cái bundle mà người dùng nhận.*

### Cảnh báo build — 16 cái, và không ai đang đếm chúng

Một lượt dựng TĂNG DẦN chỉ in lại cảnh báo của những tệp vừa biên dịch, nên nhìn vào đó rất dễ
kết luận "chỉ có một cảnh báo". Dựng LẠI TỪ ĐẦU (`rm -rf .build`) thì ra **16 cảnh báo trong mã
của ta** — chưa kể Scintilla vendor, là mã người khác. Đã đọc từng cái:

| | |
|---|---|
| **Vô hại, đã xoá trong phiên này** | `let quoted` chết ở `MainWindowController` (sót sau khi tách `readNumericColumn`), và `let minimum` / `let fold` chết ở `BM25Tokenizer` — hai dòng sau còn **mâu thuẫn với comment ngay bên dưới chúng**, vốn nói "KHÔNG có biến cục bộ nào bị closure bắt giữ" |
| **Vô hại, để nguyên** | 4 chỗ `?? ` thừa trong `GEditorBench` · 4 chỗ `var` nên là `let` · 3 chỗ `try` không bọc hàm ném nào trong `DocumentSearch` · `Settings.swift:118` "downcast không làm gì" — chỗ này **đọc kỹ rồi**: `try?` của `decodeIfPresent` đã cho `T?`, nên `as? T` là phép rỗng và hành vi vẫn đúng ý (khoá vắng hoặc giải mã hỏng đều rơi về mặc định) |
| **Đáng theo dõi** | `CSVQueryEngine.swift:281` — *"`done` mutated after capture by sendable closure"*. Hôm nay **đúng**: mọi lần đọc và ghi `done` đều nằm trong cặp `finished.lock()`/`unlock()`. Nhưng đây là loại cảnh báo **thành LỖI khi bật Swift 6 language mode**, nên nó là một khoản nợ có ngày đáo hạn, không phải một hạt bụi |

*Bản thân con số 16 là một phát hiện nhỏ: không cổng nào trong CI đếm cảnh báo, nên chúng tích
lại mà không ai thấy. Một cổng chốt hai chiều kiểu `FR-UI-804` (không cho tăng) sẽ giữ được.*

---

## 5quater. Biểu tượng ứng dụng — thêm 26/08/2026

Trước đó GEditor **không có biểu tượng nào**: `Info.plist` thiếu hẳn `CFBundleIconFile`, nên
Finder và Dock vẽ ô trắng mặc định. Đây là loại thiếu sót không bài kiểm nào bắt được — app vẫn
chạy đúng, và nó chỉ lộ ra khi người dùng đã tải bản giao về.

Nguồn: `Resources/geditor_sunset_C_lockup.png` (1024×1024, anh Công đưa vào). Ảnh đã ở đúng dạng
macOS cần — squircle và bóng đổ vẽ sẵn, không phải để hệ thống cắt mặt nạ.

**`.icns` sinh lúc dựng, không commit.** `scripts/make-icon.sh` dựng mười kích thước rồi gọi
`iconutil`; `build-universal.sh` chạy nó và DỪNG nếu hỏng. Lý do không commit: tệp `.icns` 640 KB
chứa đúng cùng nội dung với ảnh PNG 174 KB, và bản thứ hai thì không ai đọc được để biết nó còn
khớp với bản thứ nhất hay không. `sips` và `iconutil` nằm sẵn trong macOS nên điều này không vi
phạm bất biến "vendor nằm trong kho mã".

**Xác minh bằng chính hệ điều hành**, không bằng cách đọc lại tệp: một script Swift hỏi
`NSWorkspace.icon(forFile:)` rồi kết xuất ảnh ra để xem. Đó mới trả lời được câu *"người dùng sẽ
thấy gì trong Dock"*, và nó bắt được cả trường hợp plist khai sai tên (khai sai thì hỏng IM LẶNG
— app hiện ô trắng mà không báo gì).

**Một quyết định đã hỏi và anh đã chốt:** ở 16 và 32 px, chữ «editor» trong lockup thành một vệt
xám không đọc được. Cách làm chuẩn cho icon dạng lockup là bỏ chữ ở cỡ nhỏ, và bản thử đã dựng
được (dựng lại nền từ chính gradient của ảnh, không vẽ thêm gì). **Anh chọn giữ nguyên ảnh gốc ở
mọi cỡ** — nên bản giao dùng đúng một ảnh cho cả mười kích thước.

## 5bis-a. Chỗ dừng 26/08/2026 (tối) — và việc làm tiếp

Phiên này đóng **hai cụm P1 lớn** và thêm biểu tượng ứng dụng.

| | Trước phiên | Sau phiên |
|---|---|---|
| FR xong | 87 | **106** / 167 |
| P1 | 44/75 | **52/75 (69%)** |
| Test lõi | 1.341 | **1.563** |
| Tự kiểm giao diện | 196 | **203** |
| Độ phủ lõi | 94,07% | 93,04% (pha loãng vì thêm ~3.000 dòng mới) |
| Độ phủ tầng app | 69,46% | 71,85% (mốc nâng 70 → 71,5) |

**Cụm FR-MIN khép Phase 3** — 7/8 (chỉ còn 006 khai phá văn bản, P2 Phase 4): bất thường đơn
biến và Mahalanobis · phân rã leave-one-out · phân cụm k-means/DBSCAN · chuỗi thời gian
Holt-Winters · ma trận tương quan · khai phá theo nhóm · luật kết hợp Apriori.

**Cụm FR-RPT khép Phase 3** — 5/6 (chỉ còn 006 batch report, P2 Phase 4): `.greport.md` với khối
```query và ```chart · preview WKWebView · quy ước số Việt · theme màu · lưới dashboard · tham số
· HTML tự chứa · in/PDF (đóng luôn FR-DOC-313).

**Biểu tượng ứng dụng** — xem §5quater.

## 5bis-b. Chỗ dừng 27/08/2026 — cụm FR-DQR khép, và FR-MMD bắt đầu

| | Trước phiên | Sau phiên |
|---|---|---|
| FR xong | 106 | **117** / 167 |
| P1 | 52/75 | **62/75 (83%)** |
| Test lõi | 1.563 | **1.746** |
| Tự kiểm giao diện | 203 | **215** |
| Độ phủ lõi | 93,04% | 93,20% |
| Độ phủ tầng app | 71,85% | 72,47% (mốc 71,5) |
| NFR-DQR-01 | 328 ms | **324 ms** / trần 15.000 |
| NFR-MMD-01 | chưa có mã | **1.099 ms** / trần 2.000 (500 node, lần đầu) |

**Bốn mã còn lại của FR-DQR xong** — 003 khối ` ```quality `, 004 trôi dạt, 005 cổng CLI,
006 vòng khép kín — **và khối ` ```mining ` khép nốt phần block của FR-MIN-007**. Chi tiết ở
§5.2. Sáu chốt đáng nhớ ngoài phần đã ghi trong bảng:

1. **Công thức chấm điểm phải là CHỮ trên trang, không phải tooltip.** Panel trong app để công
   thức ở tooltip vì ở đó có con trỏ chuột; một báo cáo thì được in ra, gửi qua email, đọc trên
   điện thoại. NFR-DQR-03 đòi *"công thức từng chiều in trong kết quả"*, nên thẻ điểm có khối
   `<details>` — và `@media print` **ép nó mở ra**, vì `<details>` đóng thì phần công thức không
   lên giấy.
2. **Cache chốt theo NGÀY, không theo giây và không theo tuần.** Ngưỡng của chiều TIMELINESS khai
   bằng `max_age_days`, nên điểm chỉ đổi khi sang ngày mới: chốt theo giây thì cache không bao
   giờ trúng, chốt theo tuần thì một báo cáo mở qua đêm nói dữ liệu còn tươi trong khi đã quá
   hạn. Tài liệu CHƯA LƯU thì **không nhớ** — không có dấu vân nào để so.
3. **Mã thoát của cổng là 0/1/2, lệch có chủ ý khỏi `sysexits.h` của phần CLI còn lại.** Đặc tả
   viết thẳng ba mã ấy vì đó là quy ước của công cụ kiểm trong CI. Một cổng trả 65 cho "dữ liệu
   bẩn" sẽ bị viết thành `|| true` trong `.gitlab-ci.yml`, và khi ấy cổng không còn là cổng.
   Ranh giới đi kèm: **"luật không chạy được" là TRƯỢT (1), không phải lỗi chạy (2)** — lệnh đã
   đọc được dữ liệu và câu trả lời là một câu về chất lượng.
4. **Không chấm được điểm mà lại có `--fail-under` thì TRƯỢT.** Coi "không biết" là "đạt" ở một
   cổng chặn là cách cổng ấy mở toang trong im lặng.
5. **Trôi dạt vượt ngưỡng KHÔNG tự làm trượt cổng.** Ngưỡng trôi dạt nói *"đợt này khác đợt
   trước"*, cổng nói *"đợt này có dùng được không"*. Trộn hai câu ấy thì một lần dữ liệu tốt lên
   rồi xấu đi trong ngưỡng cho phép cũng chặn merge. Và **mọi ngưỡng `drift:` tắt theo mặc
   định** trừ "luật đang đạt nay trượt": một cảnh báo bật sẵn với con số do app tự chọn sẽ kêu ở
   lần chạy thứ hai của mọi người, và thứ kêu sai ngay lần đầu thì lần thứ ba đã bị bỏ qua.
6. **Sau khi làm sạch thì KHÔNG truyền đường dẫn nguồn vào lượt chấm lại.** `CSVQueryEngine` đọc
   thẳng từ file khi có đường dẫn, nên đưa đường dẫn vào là chấm bản CHƯA làm sạch mà vẫn ra một
   con số trông rất hợp lý — sai theo hướng khó phát hiện nhất. Có bài kiểm riêng cho đúng nó.

**Một chuyện của chính bộ kiểm:** hai bài kiểm cũ đỏ lên vì lý do giống nhau — chúng tìm một
chuỗi (`grid-template-columns`, `g-error`) trong CẢ trang HTML, mà chuỗi ấy nay cũng có trong
phần CSS mới. Cả hai bài trước đó vẫn xanh **vì lý do sai**: chúng hỏi "trang có chứa chuỗi này
không" trong khi câu cần hỏi là "thẻ này có thuộc tính ấy không". Đã sửa thành so trên THẺ.

### Đã làm trong phiên 27/08/2026

Khối ` ```mining ` (khép FR-MIN-007) · **cụm FR-DQR 6/6** · **FR-MMD 6/8** — khép trọn phần
Phase 3 (001, 002, 003, 005, 006, 007) · **FR-RPT-006 vế UI**, khép trọn cụm FR-RPT 6/6.

Cùng lượt sửa hai khoảng trống thật mà không bài kiểm nào từng chạm tới: preview báo cáo trong
app KHÔNG truyền `basePath` (nên khối ` ```quality ` đi tìm `.gquality.yaml` trong thư mục đang
đứng của tiến trình app), và **dấu gạch lỗi không được xoá khi đổi tab** — chúng là offset BYTE,
nên trên một tab ngắn hơn chúng trỏ ra ngoài tài liệu và làm app SẬP. Cả hai nay có bài tự kiểm.

### Việc làm tiếp, theo thứ tự đề xuất

1. **Phase 3 và Phase 3–4 đều không còn mã ⛔ nào** — 39 + 2 xong, và mục còn lại là
   **FR-DOC-305 ◐** (vướng quyết định phạm vi chứ không vướng mã, xem §6). Cụm FR-KNW đóng góp
   8 mã (901, 902, 905, 913, 918, 919, 922, 926).
2. **FR-KNW (26 mã) là việc lớn tiếp theo**, và câu hỏi kiến trúc đã trả lời bằng cách ĐO chứ
   không bằng cách bàn: ADR-15 ghi ba sự thật đo được (`PluginPackage` không có điểm mở rộng
   panel · plugin native không qua được App Store · DuckDB `fts` phải tải mạng nên không dùng
   được), và PoC-M chứng minh chỉ mục BM25 tự viết đạt cả bốn vế NFR-KNW-04. Thứ tự còn lại:
   **903, 904, 906…912, 915, 917** — phần còn lại của Phụ lục D — **đã xong cả, 28/08/2026**.
   Cụm FR-KNW nay còn đúng `911 ⊘` (thay thế bởi ADR-15). **FR-CLN-004** cũng xong.
3. **Cụm FR-MMD KHÉP TRỌN 28/08/2026** — 004 (soạn trực quan, P1 cuối cùng) và 008 (tách khối
   ra `.mmd` giữ tham chiếu, cùng tam giác Mermaid ↔ DOT ↔ edge list). Trong phạm vi v1.0
   **không còn mã FR nào chưa làm**; phần còn lại là ba món nợ phát hành bên dưới.
4. **Ba món nợ phát hành bên dưới** — chúng không nằm trong bảng FR nhưng chặn ngày 22/08/2026.

### Ba món nợ không nằm trong bảng FR nhưng chặn phát hành

- **NFR-SEC-01** — kênh tự cập nhật Sparkle 2: **đã có mã 28/08/2026** (ADR-16). Còn lại đúng ba
  thứ, và không thứ nào là quyết định nữa: **khoá thật** (`generate_keys`, anh phải chạy vì
  Keychain hỏi quyền), **appcast thật** (`generate_appcast`, cần khoá để ký), và **một vòng cập
  nhật chạy thử đầu-đến-cuối**. Bài kiểm hiện có chứng minh *cổng đóng đúng*, KHÔNG chứng minh
  *cập nhật chạy được* — đừng đọc nhầm hai điều ấy.

### Hai câu hỏi đặc tả để lại (mới, ngoài mục 10 ở §6)

- **`in_set` trượt thì "Thay thế" nạp bao nhiêu giá trị?** Hiện lấy tối đa 30 giá trị SAI khác
  nhau và ghép thành một mẫu regex. Nếu một cột có hàng trăm giá trị lạ thì mẫu ấy dài và người
  dùng sẽ không đọc hết — nhưng cắt bớt trong im lặng thì họ tưởng đã thay hết.
- **`unique` trượt thì khử trùng lặp có đủ không?** Khử trùng lặp làm việc trên DÒNG giống hệt
  nhau, còn luật `unique` nói về MỘT cột. Hai hàng cùng `ma_don` mà khác `doanh_thu` sẽ không bị
  xoá — hiện app nói thẳng còn bao nhiêu vi phạm và tô chúng lên, chứ chưa có công cụ "chọn hàng
  nào giữ".

### Một quyết định vẫn chờ anh

Số hiệu ADR đang đụng nhau giữa bộ tài liệu và kho mã (§ADR README). Nó sẽ thành lỗi thật đúng
lúc bắt đầu Phase 4, khi Knowledge Pack và engine SQL cùng được nhắc trong một câu.

## 5ter. Bài tự kiểm CHẬP CHỜN — đã truy ra 26/08/2026

Nhiều ngày nay `run-app-coverage.sh` thỉnh thoảng đỏ với một bài khác nhau, khoảng một lần trong
hơn chục lượt, và **chỉ dưới bản dựng có thiết bị đo**. Nó không tái hiện được ở bản dựng thường,
nên đã nằm trong mục nợ kỹ thuật với ghi chú "chưa tái hiện".

**Thứ giải được nó là móc giữ nhật ký** — bản đầu của script chỉ in `TRƯỢT 1/188` rồi xoá thư mục
tạm, tức phép đo tự nuốt bằng chứng của chính nó. Móc `cp` vào `benchmarks/results/` được thêm
đúng cho tình huống này, và lần đỏ tiếp theo nó chỉ ra ngay thủ phạm:

> `❌ plugin native: khai tên và biến đổi văn bản` — *"Plugin không trả lời kịp — đã dừng nó. (5s)"*

**Nguyên nhân không nằm ở sản phẩm.** Bản dựng có thiết bị đo ghi một bộ đếm cho mỗi nhánh mã, nên
khởi động một TIẾN TRÌNH plugin riêng — nạp dylib, bắt tay JSON, trả lời — mất gấp nhiều lần bình
thường. Máy đang bận thì nó vượt hạn 5 giây. Hạn ấy đo trải nghiệm người dùng ("đợi bao lâu trước
khi nghĩ là treo"), nên **nới nó cho mọi người là bán đi trải nghiệm thật để bài kiểm xanh**.

Cách sửa: `NativePluginBridge.timeout` thành 15 giây **chỉ khi** thấy `LLVM_PROFILE_FILE` — biến
môi trường mà thiết bị đo bắt buộc phải có. Người dùng vẫn 5 giây.

**Và sửa ấy làm đỏ một bài khác ngay lập tức** — *"plugin native treo bị CẮT, app vẫn sống"*, vốn
ghi cứng `waited < 20` ("5 giây cộng rộng tay"). Khi hạn thành 15 thì 20 không còn là rộng tay
nữa. Điều bài ấy muốn khẳng định là *"cầu nối cắt ĐÚNG hạn nó tự khai, chứ không chờ mãi"*, nên
nó phải **đọc hằng số** thay vì đoán: `NativePluginBridge.timeout + 15`.

Bài học ghi lại: một bài kiểm ghi cứng con số của thứ nó đang kiểm sẽ đỏ oan ngay khi con số ấy
đổi có lý do — và người đọc lúc đó không phân biệt được "cầu nối hỏng" với "bài kiểm cũ".

Xác minh: ba lượt `run-app-coverage.sh` liên tiếp xanh (71,49%), `run-self-test.sh` 200/200.

## 5bis. Chỗ dừng 26/08/2026 — đổi mẫu số

Phiên 26/08 **không viết thêm dòng mã tính năng nào**. Nó làm một việc khác: đối chiếu lại toàn
bộ hiện trạng với **bản thiết kế đang có hiệu lực** thay vì với bộ tài liệu v1 mà trang này quen
đếm theo. Bốn thứ tìm ra:

| | Trước đây trang này ghi | Đối chiếu với SRS v2.2 / RTM v2.3 |
|---|---|---|
| Mẫu số | "82/82 FR" | thiết kế có **167 FR / 61 NFR**; 87 xong · 1 một phần · **79 chưa có mã** |
| Phase 2 | "đã bắt đầu, còn nốt vài mục" | còn **3 mã chưa chạm**: FR-DQR-001, FR-DQR-002 (P1, Phase 2) và FR-QRY-001 (P1, Phase 2–3) |
| NFR | 31 mục, thiếu 4 dòng | thêm **SEC-04 · SEC-05 · USE-01 · USE-05**; và **30 NFR của cụm mới** chưa từng xuất hiện ở đây (§3bis) |
| SEC-01 | "chờ tài khoản Developer ID" | còn một vế là **việc viết mã**: kênh tự cập nhật Sparkle 2 ký EdDSA — `grep Sparkle` → 0 file |

Xác minh của phiên này chạy bằng máy chứ không đọc tài liệu: `swift test` → **1208 test, 0 lỗi**;
`scan-untranslated.py` → **475 chuỗi** chưa dịch (khớp §2.5); và mỗi ⛔ ở §5.2 là một lượt `grep`
qua toàn `Sources/` không trúng dòng nào.

**Rồi phiên này chạy tiếp hai PoC để gỡ hai cái khoá** (`scripts/run-poc-k.sh`,
`scripts/run-poc-l.sh` — kết quả ở `benchmarks/results/`). **Cả hai đều lật một tiền đề đang
được dùng để ra quyết định:**

| | Tiền đề đang dùng | Số đo |
|---|---|---|
| PoC-K | "DuckDB ~40 MB, và nhúng nó đụng ADR-08" | **94 MB** universal đã strip, nhưng khởi động chênh **−3 ms** — cỡ bundle và khởi động là hai chuyện tách rời |
| PoC-K | "engine tự viết đủ dùng, mở rộng sau" | 7/7 cú pháp mà Phase 3 cần đều bị TỪ CHỐI; DuckDB làm được cả bảy, và nhanh hơn **100–400×** khi nạp bảng một lần |
| PoC-L | "WebView kéo cả engine trình duyệt vào đường khởi động" | liên kết WebKit đắt thêm **1,4 ms** trên sàn nhiễu **0,9 ms**. Giá thật nằm ở lần mở đầu (830 ms, +35 MB), không ở khởi động |
| PoC-K | "dylib trong bundle nạp được dưới hardened runtime" | **chưa ai kiểm** — và bản dev ad-hoc không chạy hardened runtime nên không kiểm được. Áp dụng cho cả `libTreeSitterHeavy` ta ĐANG giao |

Bốn dòng trên đổi cách đọc ba quyết định ở §6. Chi tiết, cách đo, và **năm lỗi của chính hai bộ
đo** (mỗi lỗi đều từng cho ra một con số sai trông rất hợp lý) nằm ở
`docs/ke-hoach-hoan-thien-v2.2.md` §1.1–1.2.

**Kế hoạch khép 79 FR + 26 NFR còn lại: `docs/ke-hoach-hoan-thien-v2.2.md`.** Ba quyết định chặn
đầu kế hoạch — DuckDB, WKWebView cho Mermaid, và FR-DOC-305 hướng (B) — đều là quyết định phạm
vi, không phải việc code.

---

### 5bis.1 Chỗ dừng 25/08/2026 — và việc làm tiếp

**82/82 FR của bộ v1 đều đã có mã** (81 xong · 1 một phần: FR-DOC-305, cố ý — xem dưới).
172 commit. Mọi cổng xanh, cây làm việc sạch.

Phiên này khép ba mục từng bị khoá trong §4bis, và **hai trong ba khép được vì tiền đề của
quyết định đã sai** — đo lại rẻ hơn nhiều so với đi chốt một quyết định dựa trên tiền đề chưa
kiểm:

| | Từng ghi là | Hoá ra |
|---|---|---|
| FR-PLUG-702/703/704 | chờ quyết định | anh đã chốt 24/08 — chỉ còn viết mã. **XONG** |
| FR-FMT-505 | "cần vendor libxml2" | **không cần vendor gì** (PoC-I). DTD qua Foundation, XSD qua libxml2 hệ thống nạp lười |
| FR-DOC-305 | "cần chuyển sang NSDocument" | **đúng một nửa** (PoC-J). `NSFileVersion` đủ cho duyệt/khôi phục; chỉ giao diện lịch sử NGUYÊN BẢN mới cần `NSDocument` |

**Việc làm tiếp, theo thứ tự tôi thấy đáng:**

1. **Quyết định của anh — FR-DOC-305 hướng (B).** Làm giao diện lịch sử nguyên bản của macOS thì
   phải chuyển sang `NSDocument`: 413 chỗ chạm tài liệu, **29 chỗ chỉ mục `tabs[]`** (xung đột
   mô hình một-tài-liệu-một-cửa-sổ với tab), 657 dòng phiên/bản nháp/CLI phải hoà lại. Giá đã đo
   ở `scripts/run-poc-j.sh`. Không làm cũng là một quyết định hợp lệ — hướng (A) đã dùng được.
2. **Đo độ phủ tầng APP.** Con số 93,04% chỉ nói về `GEditorCore`; "cả sản phẩm đã được kiểm tới
   đâu" thì hiện chưa ai biết. Đo được bằng cách chạy `--self-test` dưới bộ đếm độ phủ.
3. **Mở rộng bộ soak tiếp.** Bốn đợt đầu cho 9 lỗi sập + 2 chỗ rò; hai đợt cuối sạch. Mỗi lần
   thêm vùng mới là một đợt săn mới — mã mới của phiên này mới chỉ có 3 thao tác chạm tới.
4. **Chín mục ở §6** — tất cả đều cần anh ngồi trước máy.

---

## 6. Việc còn cần anh

1. **Mở lại phiên trong bản App Store — kiểm TAY một lần.** Bookmark đã làm xong và có bài
   kiểm, nhưng phần "quyền sống qua lần khởi động" thì máy không tự kiểm được: bài kiểm chạy
   ngoài sandbox, và bài tự kiểm trong bundle chỉ chạm được file trong container. Cách kiểm:
   dựng `scripts/build-universal.sh`, mở `dist/appstore/GEditor.app`, ⌘O một file trong
   `~/Documents`, thoát app, mở lại — tab ấy phải quay lại kèm nội dung. Nếu hỏng thì triệu
   chứng là tab biến mất mà không có thông báo nào.
2. **Gõ thật một lần với EVKey** trước phát hành (NFR-USE-02) — `geditor-poca`, nút "Nạp 1 MB
   để gõ thử IME". Máy đã kiểm giao thức; cái này kiểm bộ gõ thật gửi đúng chuỗi.
3. **Tài khoản Developer ID** cho NFR-SEC-01 — đường ống ký và công chứng đã dựng sẵn, chỉ
   thiếu `GEDITOR_SIGN_IDENTITY` và `GEDITOR_NOTARY_PROFILE`.
4. **Lưu một file trên iCloud Drive hoặc ổ mạng — kiểm tay một lần** (NFR-REL-04). Đường điều
   phối qua `NSFileCoordinator` đã có, nhưng bài kiểm không dựng được hai loại ổ ấy, và giả lập
   chúng thì chỉ kiểm lại chính đoạn giả lập.
5. **Chạy thử một dòng AppleScript** (FR-AUTO-606) trên bản đã ký:
   `osascript -e 'tell application "GEditor" to get document text'`. Máy kiểm được `.sdef` hợp
   lệ theo DTD và kiểm được các thuộc tính phía Swift, nhưng đường AppleScript của hệ điều hành
   thì cần bundle đã ký và quyền Automation — thứ chỉ cấp được khi có người bấm đồng ý.
6. **Nghe thử bằng VoiceOver một lần** (NFR-USE-03). Máy chặn được view tự vẽ câm lặng; nó không
   trả lời được câu "dùng được không".
7. **Đo khởi động ngay sau khi KHỞI ĐỘNG LẠI MÁY** (ADR-08 §2.12). Khoản 266 ms "lần đầu cho
   mỗi file" là trạng thái nhân giữ trong bộ nhớ, nên nó phải mất khi tắt máy — nhưng đó là
   suy luận, không phải số đo. Cách kiểm: khởi động lại, mở `dist/appstore/GEditor.app` bằng
   `Contents/MacOS/GEditor --measure-startup`, ghi con số; rồi chạy lại đúng lệnh ấy lần hai.
   Nếu lần đầu ≈500 ms và lần hai ≈220 ms thì chỉ tiêu NFR-PERF-01 đang nói về một lần mở mỗi
   ngày, chứ không phải mọi lần mở — và câu ấy đổi cách đọc cả chỉ tiêu.

8. **Chốt có làm crash reporter opt-in hay không** (NFR-REL-03). Chỉ tiêu của SRS là "tỷ lệ
   phiên không crash ≥ 99,8%", và con số ấy **không đo được từ máy này** — nó là số đo từ máy
   người dùng. Bộ chạy dài `--soak` chỉ thay được phần "tìm lỗi sập trước khi phát hành"; nó
   không thay được phép đo. Đây là quyết định phạm vi (có gửi dữ liệu đi hay không, gửi cái gì,
   ai nhận) chứ không phải việc code, nên nó nằm ở đây chứ không nằm trong hàng đợi.

9. **Nhìn Activity Monitor một lần** (NFR-PERF-07). Chỉ tiêu đòi nhãn "Energy Impact: Low", mà
   không API nào trả về nhãn ấy. Máy đã đo hai đại lượng cái nhãn được tính từ đó
   (`GEditorApp --measure-idle 60`: CPU 0,01–0,04%, đánh thức 0,4–0,6 lần/giây — cả hai đều rất
   sâu dưới ngưỡng), nhưng "số thay thế thấp" và "nhãn đúng như SRS viết" là hai mệnh đề khác
   nhau. Cách kiểm: mở `dist/appstore/GEditor.app`, mở một file nhỏ, để yên vài phút, rồi xem
   cột Energy Impact trong Activity Monitor.

Không việc nào ở trên chặn phần đang code.

10. **VALIDITY và CONSISTENCY đếm theo LUẬT hay theo HÀNG?** (FR-DQR-002). Đặc tả viết *"tỷ lệ
    pass của các rule định dạng/dtype/range/regex"* — đếm theo **luật**. Bốn chiều còn lại
    (completeness, uniqueness, accuracy, timeliness) đều đếm theo **hàng**. Chênh nhau rất lớn:
    một luật hỏng ở đúng **một hàng trên một triệu** vẫn kéo VALIDITY từ 100 xuống 0 nếu đó là
    luật định dạng duy nhất. Mã hiện làm **đúng câu chữ** (theo luật) và in cả hai con số ra
    `detail` để người đọc thấy ngay; đổi sang đếm theo hàng là một dòng trong
    `QualityScorer.rulePassRate`. Nhưng nó là quyết định về **ý nghĩa của điểm số**, không phải
    chi tiết hiện thực — nên nó nằm ở đây.

**Ba quyết định cũ ở mục này đã chốt xong** (DuckDB cho FR-CSV-407 · plugin native chỉ ở bản tải
trực tiếp · libxml2 hoá ra không cần vendor). **Bốn quyết định MỚI, phát sinh khi đối chiếu với
SRS v2.2 ngày 26/08** — chi tiết và cái giá của từng đường ở
`docs/ke-hoach-hoan-thien-v2.2.md` §1:

1. ✅ **DuckDB — ĐÃ CHỐT 26/08/2026: nhúng, nạp lười** (`docs/adr/ADR-14-duckdb-va-nap-luoi.md`).
   Anh đồng ý đánh đổi **+94 MB bundle** lấy tầng phân tích, kèm điều kiện *"khởi động chỉ kích
   hoạt tính năng thực sự cần"*. Điều kiện ấy nay là **cổng chặn chạy được**, không phải một
   dòng trong tài liệu:
   - `LazyLoadAudit` hỏi **thẳng nhân** (`_dyld_image_count`) tại đúng lúc cửa sổ hiện ra và đòi
     `libduckdb` · `libTreeSitterHeavy` chưa nạp — thay cho cổng cũ vốn hỏi một **biến do chính
     mã tự khai**, tức chỉ bắt được đúng một thư viện;
   - `--measure-startup` thêm `lazyLoadPass`, **thoát 1** khi vỡ; bài tự kiểm mới có **đối chứng
     âm bên trong** (bắt bộ dò nhìn danh sách giả và đòi nó nhận ra);
   - cổng tĩnh trong `check-core-no-ui.sh` bắt **khai** mọi framework nặng liên kết lúc nạp, kèm
     giá đã đo, chốt hai chiều như `POLLING_ALLOWED`.

   **Đã xác nhận ĐỎ được:** chèn một `dlopen` vào đường khởi động → `--measure-startup` thoát 1
   và bài tự kiểm đỏ; hoàn nguyên thì xanh lại. Sau khi thêm tất cả: khởi động **368 ms / trần
   500** ✅, RAM nhàn rỗi 14,8 MB ✅, `swift test` 1208 ✅, tự kiểm **187/187** ✅ (186 + bài mới).

   ⚠️ **Con số 368 ms cần một dấu hỏi, không phải một tràng vỗ tay.** §3 ghi 465 ms; chênh gần
   100 ms, tức **rộng hơn hẳn dải nhiễu ±40 ms** mà chính ADR-08 mô tả. Bộ đo nạp-lười chỉ thêm
   một lượt đọc danh sách ảnh dyld nên nó **không thể** làm nhanh lên ngần ấy. Nghĩa là hoặc máy
   lúc này rảnh hơn lúc đo 465, hoặc có gì đó khác đã đổi giữa hai lần. Chưa truy ra, và **không
   được dùng 368 làm mốc mới** cho tới khi biết vì sao — một con số đẹp không rõ nguồn gốc thì
   nguy hiểm hơn một con số xấu.

   Số đo dẫn tới quyết định vẫn ở §5bis.

   *(hồ sơ cũ, giữ lại)* ADR-11 mới lật DuckDB cho
   riêng FR-CSV-407, nhưng đặc tả còn dựa vào nó ở **bảy chỗ khác**, và engine tự viết TỪ CHỐI
   cả bảy (JOIN · DISTINCT · HAVING · IN · LIKE · BETWEEN · subquery — 7/7, có ghi nguyên văn
   lỗi). Số đo: **khởi động nguội chênh −3 ms** khi dylib nằm trong bundle mà không ai mở, tức
   ADR-08 **không bị đụng**; `dlopen` 6,9 ms; truy vấn nhanh hơn **4,7–9,9×**, và nếu nạp bảng
   một lần (732 ms) thì **100–400×** (2–17 ms so 677–1530 ms). Hai tiền đề bị lật: dylib
   universal nặng **94 MB** chứ không phải "~40 MB" như SAD ghi (40 MB là **một** kiến trúc, mà
   NFR-PORT-01 đòi cả hai); và hardened runtime chặn `libduckdb` thì **cũng chặn y hệt
   `libTreeSitterHeavy` ta đang giao** — nên đó không phải điểm trừ của DuckDB. **Câu hỏi còn
   lại thuần về sản phẩm: 94 MB bundle có đáng không.** Chặn **11 FR**.
2. **WKWebView cho Mermaid — ĐÃ ĐO 26/08 (`scripts/run-poc-l.sh`).** Tiền đề của FR-FMT-506
   (*"nạp WebKit kéo cả một engine trình duyệt vào tiến trình"*) **sai về thời gian khởi động**:
   liên kết WebKit đắt thêm **1,4 ms** trên sàn nhiễu 0,9 ms — WebKit nằm trong dyld shared
   cache. Giá thật nằm ở **lần mở preview đầu tiên: 830 ms và +35 MB RAM**, cả hai chỉ phải trả
   KHI người dùng bấm mở. Sơ đồ **500 node render 531 ms** / trần 2000 ms của NFR-MMD-01. Chặn
   mạng **có tác dụng thật** (đối chứng âm: bỏ hàng rào ra thì fetch đi được ngay). Chặn **10 FR**,
   và nới được cả FR-FMT-506 (giới hạn "chưa dựng bảng, chưa tô màu khối mã" sinh từ đúng tiền
   đề vừa bị đo là sai).
3. **FR-DOC-305 hướng (B)** — như cũ, nhưng giờ nó **kéo theo NFR-USE-01**: chỉ tiêu đòi "hành vi
   document-based app chuẩn macOS", mà ta đang cố ý đi lệch. Chốt (B), hoặc ghi một ADR nói rõ
   GEditor không phải document-based app — chứ đừng để lơ lửng.
4. **Crash reporter opt-in** (NFR-REL-03) — như cũ. Không chốt thì chỉ tiêu này **vĩnh viễn không
   đóng được**, dù `--soak` có sạch đến đâu.

**Và một việc dọn dẹp nên làm ngay, không cần ai chốt:** mã ADR đang đụng nhau. SRS v2.2 gọi
ADR-11 là Knowledge Pack, ADR-12 là Agent Pack, ADR-13 là Python Pack; kho mã có
`ADR-11-sql-engine.md` và `ADR-12-plugin-native.md`. Sửa bây giờ là đổi tên hai file; sửa lúc bắt
đầu Phase 4 là sửa hàng chục chỗ đã trích dẫn.
