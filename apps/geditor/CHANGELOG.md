# Nhật ký thay đổi

Theo [Semantic Versioning](https://semver.org/lang/vi/) (NFR-MNT-04).

Chưa có bản phát hành nào ra ngoài, nên mọi thứ dưới đây thuộc `0.x` và giao diện lập trình còn
đổi được. Từ `1.0.0` trở đi mới áp luật semver đầy đủ.

## [Chưa phát hành]

### Thêm

- **Sách trợ giúp có bản tiếng Anh, và đổi ngôn ngữ ngay trong cửa sổ Trợ giúp.** 14 chương ·
  107 trang dịch trọn, chọn bằng popup ở góc trên bên phải — **tách khỏi ngôn ngữ giao diện**:
  một người dùng giao diện tiếng Việt vẫn đọc được bản tiếng Anh để đối chiếu thuật ngữ, và
  ngược lại, không phải đổi cả ứng dụng.
  - Đổi ngôn ngữ **giữ nguyên trang đang đọc**. Đó là lý do mã trang cố ý không dịch: lệch một
    mã thì người đọc bấm đổi tiếng giữa một trang dài và bị ném về mục lục.
  - Popup chỉ liệt kê ngôn ngữ **thật sự có sách**. Một mục chọn vào rồi vẫn thấy tiếng cũ là
    một mục nói dối, và người dùng sẽ đổ cho sản phẩm hỏng.
  - Hai cổng mới canh: mọi bản dịch phải có **cùng bộ mã trang, cùng thứ tự chương, không trang
    rỗng**; và mọi cuốn — không riêng cuốn đang hiện — phải qua phép kiểm liên kết chéo.
- **Trang trợ giúp mới cho thanh trạng thái**, và năm trang cập nhật theo các vế vừa làm: Đi tới
  (ba cách viết), chọn khối cột bằng bàn phím, thụt lề theo ngôn ngữ, file mask của macro, lịch
  sử lượt tìm và nút Xuất.
- **Chín vế đặc tả bị bỏ quên dưới một dấu ✅.** Đợt rà 05/09 đối chiếu từng vế của cả 38 mã P0
  với mã nguồn và tìm ra chín chỗ mã có nhưng thiếu một phần đặc tả:
  - **Đi tới (⌘L) nhận «dòng,cột» và «@vị trí byte»**, không chỉ số dòng. `12,5` hay `118:23` —
    đúng cách trình biên dịch in lỗi ra, nên dán thẳng từ clipboard được.
  - **Thanh trạng thái hiện offset con nháy và cỡ tài liệu.** Offset là thứ bắc cầu giữa thanh
    trạng thái và mọi công cụ khác (lỗi JSON/XML, `--doc-sweep`, khung nhị phân, ô Đi tới).
    Bấm vào mục cỡ tài liệu thì đếm đủ byte · ký tự · từ · dòng.
  - **Chạy macro hàng loạt theo file mask** (`*.csv;*.log`) — trước đây chỉ lọc bằng một bảng
    đuôi cứng, nên không có cách nào bảo nó đừng chạm vào 400 tệp khác trong thư mục.
  - **Lịch sử lượt tìm** trong panel kết quả, và **xuất kết quả ra tab** dạng
    `đường-dẫn:dòng:cột` như `grep -n`.
  - **Thụt lề theo từng ngôn ngữ** (`settings.json` hoặc mục Tab trên thanh trạng thái): Go
    dùng TAB, Python 4 dấu cách, JavaScript 2 — người ta theo quy ước cộng đồng, không theo sở
    thích, và một con số chung làm mỗi tệp chạm vào mọc thêm diff.
  - **Chọn khối cột bằng Option+Cmd+mũi tên** — trước đây chỉ có Option+kéo chuột, tức người
    dùng bàn phím không có đường nào tới chế độ cột và Column Editor.
  - **XML: đánh giá XPath** (kết quả ra tab mới) và **tự đóng thẻ** khi gõ `>` trong `.xml`/`.html`.
  - **Nhân bản · Đổi tên · Chuyển tệp** trong menu File, làm thẳng bằng `FileManager`; cả ba từ
    chối khi đích đã có tệp cùng tên.
  - **Lưu thành… chọn bảng mã và kiểu xuống dòng ngay trong hộp lưu** — chỉ áp cho lần lưu ấy,
    không đổi tài liệu đang mở.
- **Thanh trạng thái đổi được ĐỦ mọi mục.** Bốn mục cuối trước nay bấm vào không có gì xảy ra;
  người dùng không phân biệt được "chưa làm" với "hỏng":
  - **CSV · …** — bật/tắt chế độ CSV và **chọn lại dấu phân tách**. Phép đoán theo nội dung sai
    là lỗi im lặng nhất của cả nhóm CSV: mọi thao tác cột sau đó đều lệch mà không có gì báo, và
    trước đây không có đường nói lại.
  - **Ngôn ngữ** — chọn ngôn ngữ tô màu, hoặc trả về "theo đuôi tệp". Cần cho tệp không đuôi và
    tệp mang đuôi nói dối (`.txt` chứa JSON).
  - **Độ rộng tab** — 2 · 4 · 8, ghi thẳng vào `settings.json`.
  - **Chỉ đọc** — nói ra VÌ SAO (đang theo dõi file · tệp trên đĩa không cho ghi · người dùng tự
    khoá) và mở khoá khi mở khoá được.
- **Thanh trạng thái nói ra «Đang theo dõi»** khi bật `tail -f`. Trước đây điều đó chỉ hiện trong
  một dải băng thoáng qua, nên vài giây sau người dùng chỉ còn thấy một tài liệu không gõ được và
  không có gì giải thích.
- **Tự cập nhật** qua Sparkle 2 (`GEditor ▸ Kiểm tra bản cập nhật…`) — **chỉ bản tải trực tiếp**;
  bản App Store cập nhật qua Mac App Store và mục menu nói thẳng điều đó thay vì mờ đi. App
  không tự đi mạng khi chưa ai cho phép: bộ cập nhật chỉ dựng khi người dùng bấm.
- **Gấp theo cấp** (⌥⌘1…⌥⌘8, tám cấp như Notepad++): cấp đếm theo số vùng bao chứ không theo độ
  sâu thụt lề. Gấp cấp N thay thế trạng thái đang gấp, và cấp sâu hơn tài liệu thì nói ra số cấp
  thật thay vì im lặng không làm gì.
- **Hộp "Về GEditor" ghi phiên bản mermaid** — khi một sơ đồ cũ đột nhiên vẽ khác đi, câu hỏi đầu
  tiên là "bản mermaid nào", và người trả lời là người đang ngồi trước máy.
- **Thao tác dòng**: nhân đôi (⇧⌘D), xóa dòng (⌘K), comment theo ngôn ngữ (⌘/).
- **Khớp ngoặc** (⌃⌘B) — bỏ qua dấu nằm trong chuỗi và chú thích.
- **Tự động thụt lề** khi xuống dòng, theo ngôn ngữ.
- **Thu phóng cỡ chữ** ⌘= / ⌘− / ⌃⌘0.
- **Lịch sử clipboard** (⇧⌘V), giữ trong bộ nhớ, không ghi ra đĩa.
- **Cắt khoảng trắng cuối dòng khi lưu** — tuỳ chọn, mặc định tắt.
- **Chuẩn hóa Unicode** NFC/NFD/NFKC/NFKD.
- **Tìm tăng dần** và **tô mọi kết quả** trên màn hình.
- **Theo dõi file** kiểu `tail -f`, nhận ra cả cắt cụt lẫn xoay vòng log.
- **In ấn**, có trần 20 MB và nói rõ khi vượt.
- **File gần đây** và **mở lại tab vừa đóng** (⇧⌘T).
- **Cửa sổ Cài đặt** ghi vào `settings.json` — file văn bản chép giữa các máy được.
- **Đa ngôn ngữ EN/VI** cho menu bar và panel Tìm.
- **Theme đổi được**, hai theme dựng sẵn và theme người dùng ở `themes/*.json`.
- **Bảng phím tắt đổi được**, có preset Notepad++.
- Trang **Trợ giúp** và **Di cư từ Notepad++** trong menu Help.
- Bản đồ tài liệu (⌥⌘M) mô tả cả file mà không đọc nội dung.
- **Chế độ Log**: tô theo mức nghiêm trọng, lọc "từ mức này trở lên" ra tab mới.
- **Xem trước Markdown**, **thử biểu thức chính quy** có giải thích từng mảnh.
- **Lọc qua lệnh ngoài** (`sort`, `jq`…) — chỉ bản tải trực tiếp.
- **Ngôn ngữ tự định nghĩa** khai bằng JSON trong `grammars/`.
- **Script JavaScript** với API hẹp (`doc.text`, `doc.selection`, `doc.replace`, `doc.log`).
- **Gói mở rộng** `.geditorpkg`: cài/gỡ script, theme và ngôn ngữ tự định nghĩa.
- **Macro chạy trên cả thư mục**, mặc định ghi ra file mới.
- **Services** và **AppleScript**: mở văn bản/file từ ứng dụng khác; đọc/ghi tài liệu bằng script.
- **Nhiều cửa sổ** (⌥⌘N) và **kéo tab sang cửa sổ khác** (⌃⌘N để tách bằng bàn phím). Thả tab ra
  ngoài mọi cửa sổ tách nó thành cửa sổ mới. Tab đang ghim thì không đi đâu. Phiên làm việc lưu
  và khôi phục đủ mọi cửa sổ kèm vị trí.

- **Chất lượng dữ liệu** (FR-DQR): bộ quy tắc `.gquality.yaml` đặt cạnh dữ liệu, điểm sáu chiều
  kèm công thức, và bấm một luật thì tô đúng dòng vi phạm.
  - Khối ` ```quality ` trong báo cáo `.greport.md` → thẻ điểm có sáu thanh, bảng luật và biểu đồ.
  - **Theo dõi trôi dạt**: mỗi lượt chấm ghi một mốc vào `<tên luật>.history.jsonl` cạnh bộ luật;
    tab Xu hướng vẽ điểm theo thời gian và so hai mốc bất kỳ; ngưỡng cảnh báo khai ở `drift:`.
  - **Cổng CI**: `geditor --quality chuan.yaml *.csv --fail-under 90 --json ra.json`, mã thoát
    **0 đạt · 1 trượt · 2 lỗi chạy**. Đi cùng `--recipe` thì làm sạch trong bộ nhớ rồi chấm lại.
  - **Vòng khép kín với Bàn làm sạch**: mỗi luật trượt có nút mở đúng công cụ sửa nó, và sửa
    xong thì điểm tự chấm lại ngay.
- Khối ` ```mining ` trong báo cáo: gom nhóm theo một cột rồi chạy bất thường / dự báo / tương
  quan cho **từng nhóm riêng**, ra bảng xếp hạng nhóm kèm khối "Phương pháp".
- **Sinh loạt báo cáo** từ danh sách tham số:
  `geditor --report thang.greport.md --param-list tinh.csv --out bc/` — mỗi hàng một tệp.

### Sửa

- **Chế độ CSV rò từ tab này sang tab khác.** Bật chế độ CSV — hoặc chỉ cần bấm ⌥⌘T xem bảng, vì
  lệnh ấy tự bật giúp — rồi mở một tệp `.json` ở tab mới: thanh trạng thái ghi «CSV · dấu phẩy»
  cho tệp JSON và khung soạn thảo tô màu cột lên nó. Nay chế độ CSV và dấu phân tách thuộc về
  TAB, không thuộc cửa sổ.
- **Dòng log mới rơi vào tab người dùng đang gõ.** Bật theo dõi một file log ở tab 1, sang tab 2
  gõ dở, và dòng log kế tiếp nạp lại tab 2 từ đĩa rồi đặt nó thành chỉ đọc — phần vừa gõ mất,
  không một thông báo nào, và nguyên nhân nằm ở một tab họ không nhìn thấy. Bộ theo dõi nay thuộc
  về tab đặt nó, và dừng khi tab ấy đóng hoặc rời sang cửa sổ khác.
- **Chỉ mục hàng CSV sống qua lần đổi tab.** Nó là bảng OFFSET BYTE của một tài liệu cụ thể; giữ
  lại khi đã đổi tài liệu là để sẵn một thứ trỏ vào giữa ký tự hoặc ra ngoài tệp mới. Nay xoá
  cùng lúc với dấu dòng và dấu gạch lỗi.
- **Panel phân tích trưng kết quả của một tài liệu khác.** Bảng «Kiểm tra dữ liệu: 2 lỗi ở cột
  y» nằm nguyên đó sau khi người dùng đã sang một tệp `.txt` không có cột nào, và những ô tô đỏ
  trên bảng CSV thì đánh theo số hàng của tài liệu cũ. Mười ba panel mô tả nội dung tệp nay đóng
  cùng lúc với các chế độ View. (Kết quả «Tìm trong nhiều file» thì KHÔNG — nó nói về một thư
  mục, và đóng nó là phá đúng luồng «bấm kết quả → xem → quay lại danh sách».)
- **Khung chung nói ngược với màn hình.** Tài liệu chưa lưu không có đuôi tệp, nên bảng tra chế
  độ trả về "tệp này chỉ có một chế độ hiển thị" và công tắc View/Code tắt — ngay phía trên một
  bảng CSV đang hiện rành rành. Nay hỏi MÀN HÌNH trước, hỏi bảng tra sau.
- **Ô «Kết quả tìm kiếm» mang chữ của tính năng khác.** Sắp xếp một cột hay quét Bàn làm sạch thì
  thông báo của chúng hiện đúng chỗ đáng lẽ ghi «3/17». Chúng nay đi vào dải băng chung.
- Bản đồ tài liệu ra một cột xám đều: nó được dựng lúc bố cục chưa áp bề cao nên chỉ có MỘT
  hàng, và bản đồ hụt ấy được nhớ tạm theo tài liệu nên sống mãi. Số hàng nay nằm trong khoá
  nhớ tạm và view tự báo khi bề cao đổi.
- `--capture` chụp lẫn panel của cảnh trước; mỗi cảnh nay bắt đầu từ cửa sổ sạch.
- Ghi file trên iCloud Drive và ổ mạng đi qua `NSFileCoordinator` (NFR-REL-04).
- `Settings`/`Theme` đọc được file thiếu khoá thay vì ném lỗi lúc khởi động.

### Đo lường

- Đo lại **05/09/2026**: **2669 test lõi · 377 bài tự kiểm giao diện**, 0 trượt. Độ phủ tầng app
  **75,82%** (mốc 75,00) · `--doc-sweep data/vanban` **63/63 tệp thật sạch**, 10 cặp `.docx`/PDF
  lệch số trang trung bình **4,7%** · nợ bản dịch **359** (mốc hạ theo, vì bốn lệnh mới đều đã dịch).
- **33/33 bảng dịch đủ trở lại.** 86 khoá tích từ nhiều phiên trước — trong đó 44 của đợt này — đã dịch sang cả 32 thứ tiếng; bài kiểm «ngôn ngữ đã đăng ký phải dịch gần đủ» (ngưỡng 95%) là thứ bắt được, khi tiếng Pháp tụt xuống 93%.
- Cổng ADR-14 (framework nặng liên kết lúc nạp) trước nay **im lặng bỏ qua** vì máy chưa dựng
  bản release: nó chỉ in một dòng ⚠️ mà không ai đọc. Đã dựng và chạy thật — 6 framework, tất cả
  đều đã khai.
- Độ phủ test của lõi: **93,9%** (`scripts/run-coverage.sh`), cổng ≥70% nằm trong CI.
- Bản đồ tài liệu: 4,7 ms cho file 0,19 MB và 4,9 ms cho file 245 MB / 3 triệu dòng.

### Ghi chú kỹ thuật

- Bộ tự kiểm trước nay chạy trên máy locale tiếng Anh mà không ai biết: bài kiểm bản dịch có
  nhánh "đang chạy tiếng Anh thì bỏ qua", nên nó im lặng không kiểm gì. `--self-test` và
  `--capture` nay KHOÁ ngôn ngữ về tiếng Việt trước khi dựng menu.
- Bảng dịch có khoá trùng làm app chết lúc CHẠY chứ không lúc biên dịch; có cổng chặn trong
  `scripts/check-core-no-ui.sh`.
- Bốn mục menu từng tồn tại với `action: nil` — có chỗ bấm, không có gì xảy ra. Bộ tự kiểm nay
  có một bài soi chính thanh menu và chặn loại lỗi ấy, kèm một bài chặn phím tắt trùng.
- **Cổng ấy canh thanh MENU, và đúng loại lỗi ấy vẫn sống ở thanh TRẠNG THÁI** cho tới
  05/09/2026 — cổng chỉ canh được đúng thứ nó soi. Chỗ chặn tái diễn lần này không phải một bài
  kiểm mà là trình biên dịch: `handleStatusBarClick` không còn nhánh `default`, nên thêm một mục
  mới mà quên nối là lỗi lúc dựng.
- **Ba lỗi sửa trong ngày 05/09 cùng MỘT hình dạng**: một trạng thái thuộc về TÀI LIỆU lại nằm ở
  CỬA SỔ (`csvModeOverride`, `tailWatcher`, `csvIndex`). Cửa sổ có nhiều tab, nên mỗi biến như
  thế là một lần tab này nói thay tab khác. Khi thêm trạng thái mới vào `MainWindowController`,
  hỏi trước: nó mô tả cửa sổ, hay mô tả tệp đang mở?

## Chưa làm

**146/167 yêu cầu chức năng đã xong (05/09/2026)** — 1 một phần, 1 thay thế bởi ADR, 19 chưa có
mã. Phase 1, 2 và 3 khép hoàn toàn.

Mẫu số là **167 FR** của SRS v2.2 / RTM v2.3, không phải 82 như tệp này từng ghi — con số 82
thuộc bộ đặc tả cũ, và một bảng đúng từng dòng vẫn cho ấn tượng sai nếu mẫu số của nó đã cũ.

19 mã chưa có nằm gọn ở **Agent Pack (10, Phase 5)** và **Python Pack (9, Phase 6)** — cả hai
đều ngoài phạm vi v1.0 theo quyết định 28/08/2026. Danh sách đầy đủ kèm lý do từng mục ở
**`docs/trang-thai.md` §5**.
