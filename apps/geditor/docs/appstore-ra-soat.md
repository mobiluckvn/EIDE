# Rà soát: GEditor có lên Mac App Store được không

**Ngày rà:** 22/08/2026 · **Bản mã:** `34bc2fe` · **Cách rà:** đọc mã, không suy đoán — mỗi mục
đều dẫn tệp và dòng.

---

## Kết luận ngắn

**Chưa lên được, nhưng vướng mắc là HỮU HẠN và đã biết hết tên, không phải vấn đề kiến trúc.**

Kiến trúc lõi hoàn toàn hợp lệ với App Store: không nạp mã lạ, không tiến trình con, không ghi
ra ngoài vùng của app, JIT dùng đúng cơ chế Apple cho phép. Cái vướng nằm ở **ba tính năng** và
**hai thủ tục**, chứ không nằm ở piece table hay tree-sitter.

Có một điều phải quyết trước mọi thứ khác: **`geditor` CLI không thể đi cùng bản App Store.**
Đó là một tính năng, không phải một dòng cấu hình — xem §2.

---

## 1. Những gì ĐÃ đúng (đã kiểm, không phải đoán)

| Điểm | Vì sao không vướng |
|---|---|
| **PCRE2 JIT** (ADR-03) | sljit dùng `MAP_JIT` trên Apple (`sljitExecAllocatorApple.c`), và `com.apple.security.cs.allow-jit` **dùng chung được với App Sandbox**. Entitlement này có ở CẢ HAI kênh: `Resources/GEditor-AppStore.entitlements` và `GEditor-Direct.entitlements` |
| **`dlopen` grammar nặng** (ADR-08) | `libTreeSitterHeavy.dylib` nằm TRONG bundle, ký cùng bundle. Không cần `disable-library-validation` — thứ mà App Store từ chối. Nếu ngày nào đó dylib ấy chuyển ra ngoài bundle thì điều này đổi, xem §4 |
| **`mmap`** đọc file lớn | `PROT_READ` + `MAP_PRIVATE` trên file người dùng đã mở (`ByteSource.swift:72`). Không có gì đặc biệt cần xin |
| **Xóa file** | `FileManager.trashItem` (`Workspace.swift:169`), API hợp lệ trong sandbox |
| **Không có tiến trình con** | `Process()` chỉ xuất hiện trong `GEditorCLI/main.swift:348`, tức là ở CLI chứ không ở app |
| **Không nạp mã bên thứ ba** | Chưa có plugin. Grammar biên dịch tĩnh hoặc nằm trong bundle |
| **Chọn thư mục** | Mọi chỗ cần thư mục đều qua `NSOpenPanel` (Find in Files, Workspace, batch công thức — 10 chỗ). Sandbox cấp quyền cho thư mục ấy **trong phiên** — nên các tính năng này CHẠY được, chỉ không sống qua lần khởi động sau (§3) |
| **Đo hiệu năng** | `sysctl KERN_PROC` và `task_info` chỉ hỏi về CHÍNH tiến trình mình, và chỉ chạy dưới cờ `--measure-startup` |

---

## 2. Chặn cứng — phải quyết, không phải phải sửa

### 2.1 `geditor` CLI không thể có mặt trong bản App Store

App Store không cho app đặt tệp ra ngoài vùng chứa của nó, nên không có cách nào đưa `geditor`
vào `PATH`. Và ngay cả khi người dùng tự chép tay, cầu nối cũng đứt: `CLIBridge` dùng socket
Unix ở `AppPaths.applicationSupport/cli.sock` (`CLIBridge.swift:87`), mà khi app chạy trong
sandbox thì đường ấy trỏ vào container — một tiến trình CLI không sandbox không mở được.

Mất theo nó: `geditor file.txt`, `geditor -w` (dùng làm `$EDITOR` cho git), chạy công thức CSV
theo lô từ dòng lệnh.

> **ĐÃ CHỐT 22/08/2026: phương án A — hai bản.** Bản App Store (sandbox, không CLI) và bản tải
> từ trang web (Developer ID + công chứng, có CLI). Đã triển khai:
> `scripts/build-universal.sh [--channel appstore|direct]`, hai tệp entitlement riêng, và app
> **tự nhận ra mình đang ở kênh nào lúc chạy** (`Sources/GEditorCore/Session/Distribution.swift`)
> nên chỉ có MỘT binary và MỘT đường mã.

**Ba lối đi, phải chọn một:**

| | Được | Mất |
|---|---|---|
| **A. Hai bản**: App Store bản không CLI, bản tải thẳng từ web có CLI | giữ đủ tính năng cho người cần | hai đường phát hành, hai lần kiểm thử, người dùng phải hiểu khác biệt |
| **B. Chỉ bán ngoài App Store** (Developer ID + notarize) | giữ nguyên mọi thứ đang có, đường ống ký đã dựng sẵn | mất kênh App Store: không có cài đặt một chạm, không có thanh toán sẵn |
| **C. Chỉ App Store, bỏ CLI** | một bản duy nhất, đơn giản nhất | bỏ một tính năng mà lập trình viên Việt Nam — nhóm người dùng chính của một bản thay thế Notepad++ — dùng thường xuyên |

Tôi nghiêng về **A**, và nếu chỉ được chọn một thì **B**: nhóm người dùng mục tiêu của GEditor
quen tải app từ web, còn `geditor -w` là thứ khó thay thế.

### 2.2 App Sandbox — ✅ đã bật

App Sandbox là **bắt buộc** với mọi app trên Mac App Store. `Resources/GEditor-AppStore.entitlements`
nay có `app-sandbox` + `files.user-selected.read-write`; bản `direct` cố ý KHÔNG có, vì sandbox
là thứ làm đứt cầu nối `geditor`.

Bật xong app **vẫn chạy** — 128/128 bài tự kiểm bên trong bundle đã ký — nhưng §3 vẫn hỏng, và
hỏng im lặng.

**Bật sandbox đã tìm ra ngay một lỗi thật**, đúng loại chỉ xảy ra ở bản phát hành:
`HeavyGrammars` suy đường tới `libTreeSitterHeavy.dylib` từ `CommandLine.arguments[0]`, mà
argv[0] có thể là đường tương đối và thư mục hiện hành của app sandbox nằm trong container.
Hậu quả nếu lọt: C#, C++ và Ruby mất màu cú pháp hoàn toàn, chỉ trong bản gửi cho người dùng.
Đã sửa (hỏi `Bundle`), và `scripts/run-self-test.sh --bundle [appstore|direct]` giữ cho đường
ấy được chạy đều.

---

## 3. Chặn cứng — phải sửa mã

### 3.1 Không có security-scoped bookmark ở BẤT KỲ đâu

```
grep -rn "bookmarkData|securityScoped|startAccessingSecurityScopedResource" Sources/
→ không có kết quả nào
```

Đây là khoản lớn nhất. Sandbox chỉ nhớ quyền truy cập qua bookmark; không có bookmark thì quyền
mất khi app đóng. Hệ quả, theo mức độ nghiêm trọng:

| Tính năng | Chuyện gì xảy ra sau khi bật sandbox |
|---|---|
| **Khôi phục phiên (FR-DOC-303)** | `restoreSession` mở lại tab theo `entry.path` (`MainWindowController.swift:755`). Sau khi bật sandbox, mọi file ngoài container **im lặng không mở được** — người dùng mở app thấy phiên trước biến mất |
| **Folder as Workspace (FR-DOC-308)** | cây thư mục và FSEvents chết ngay lần mở app kế tiếp |
| **File gần đây** | mọi mục đều hỏng |
| **Bản nháp tự động** | phần nội dung vẫn còn (nằm trong container) nhưng không ghi lại được vào file gốc |

**Việc phải làm:** lưu bookmark cạnh đường dẫn trong `SessionStore`, `Workspace` và danh sách
file gần đây; `startAccessingSecurityScopedResource()` khi mở lại và dừng khi đóng tab. Đây là
sửa **thiết kế dữ liệu phiên**, không phải thêm một cờ.

**Ước tính:** 3–5 ngày, cộng một nhóm bài tự kiểm mới. Con số này là ƯỚC TÍNH, chưa đo.

### 3.2 Dữ liệu người dùng cũ không tự chuyển

Bật sandbox thì `~/Library/Application Support/GEditor` đổi thành đường trong container. Cài đặt,
macro, công thức, phiên, bản nháp của bản hiện tại **không tự sang**. Nếu đã có người dùng bản
ngoài App Store thì cần một bước chuyển dữ liệu một lần.

---

## 4. Chặn theo LỘ TRÌNH — chưa code, nhưng thiết kế đang đi vào đường bị cấm

Hai chỗ trong tài liệu hiện tại sẽ bị từ chối nếu làm đúng như đã viết:

1. **DuckDB "optional component tải khi bật tính năng SQL"** (SAD) — App Store cấm app tải về
   và thực thi mã, nên với bản App Store thì DuckDB **phải nằm sẵn trong bundle**.

   > **Sửa lại câu tôi viết ở bản rà đầu.** Bản đầu viết tiếp rằng "khi ấy nó cộng thẳng ~40 MB
   > vào binary, tức cộng thẳng vào NFR-PERF-01". Câu ấy gộp ba thứ khác nhau làm một: **nằm
   > trong bundle** ≠ **nằm trong binary chính** ≠ **nằm trên đường khởi động**.
   >
   > Dự án đã có sẵn cơ chế tách ba thứ ấy, và đã đo: ADR-08 phương án C đóng grammar nặng
   > thành `libTreeSitterHeavy.dylib` trong `Contents/Frameworks`, `dlopen` khi cần. Kết quả
   > thật: binary chính 22 → 11,6 MB, khởi động nguội **794 → 690 ms**, và người không mở
   > C#/C++/Ruby thì không trả một mili-giây nào. DuckDB đi đúng đường ấy: một dylib trong
   > bundle, `dlopen` lần đầu người dùng chạy SQL.
   >
   > Nên cái giá thật của DuckDB **không phải** thời gian khởi động, mà là **dung lượng tải về
   > và dung lượng đĩa** (~40 MB) cho mọi người dùng, kể cả người không bao giờ chạy SQL.
   > App Store không có trần dung lượng nào mà 40 MB chạm tới; đây là câu hỏi về trải nghiệm
   > tải app, không phải câu hỏi kỹ thuật.

   **Một cái bẫy cụ thể phải chặn trước khi viết dòng mã đầu tiên:** DuckDB có cơ chế extension
   (`INSTALL httpfs`, `LOAD parquet`…) **tải tệp `.duckdb_extension` từ mạng lúc chạy rồi nạp
   nó**. Đó chính xác là thứ điều 2.5.2 cấm, và nó bật MẶC ĐỊNH. Phải:
   - liên kết TĨNH những extension thật sự cần,
   - `SET autoinstall_known_extensions=false` và `SET autoload_known_extensions=false`,
   - không để câu lệnh `INSTALL` của người dùng đi tới engine.

   **Và câu hỏi nên hỏi trước cả hai điều trên:** SQL có cần DuckDB không. FR-CLN-003 (Data
   Profile) từng nằm trong danh sách "cần DuckDB" và cuối cùng làm xong bằng vài chục dòng
   thuật toán cổ điển, chạy 4,85 s trên 1 triệu hàng × 20 cột. Nếu FR-QRY-001 chỉ cần
   `SELECT … WHERE … GROUP BY` trên một file CSV thì cái giá 40 MB đáng được cân lại.
2. **Plugin FR-PLUG-70x nạp mã bên thứ ba** — bị từ chối thẳng. Nếu vẫn muốn có plugin trong bản
   App Store thì phải đổi thành plugin **dữ liệu** (theme, grammar, snippet, công thức) hoặc
   script chạy trong JavaScriptCore, không phải mã máy.

**Điều đã làm thì KHÔNG vi phạm:** ADR-08 phương án C đóng gói dylib grammar **trong bundle**.
Ghi lại ở đây để sau này không ai quay về đường "tải gói bổ sung" mà tưởng nó vô hại — nó không
vô hại, nó là lý do bị từ chối.

---

## 5. Thủ tục còn thiếu (nhỏ, nhưng chặn lúc nộp)

| Thiếu | Ở đâu |
|---|---|
| ✅ `LSApplicationCategoryType` | `public.app-category.developer-tools` |
| ✅ `CFBundleDocumentTypes` | khai theo UTI chuẩn (`public.plain-text`, `public.source-code`, CSV/TSV/JSON/XML/YAML/Markdown/log) + `public.data` ở vai Viewer |
| ✅ Chữ ký App Store | `scripts/build-universal.sh --channel appstore` ký bằng `GEDITOR_APPSTORE_IDENTITY` rồi đóng `.pkg` bằng `GEDITOR_APPSTORE_INSTALLER_IDENTITY`. Công chứng CHỈ áp dụng cho kênh `direct` — `notarytool` trên bundle ký bằng 3rd Party Mac Developer sẽ bị từ chối |
| ⛔ Ảnh chụp màn hình, mô tả, chính sách riêng tư | App Store Connect. Chưa có |
| ⛔ Hai danh tính ký | cần tài khoản Apple Developer: `3rd Party Mac Developer Application` và `…Installer` cho App Store, `Developer ID Application` + hồ sơ notarytool cho bản web |

---

## 6. Trả lời thẳng câu hỏi

**Với thiết kế hiện tại: không.** Có bốn thứ chặn, và chúng khác nhau về bản chất:

1. ~~**`geditor` CLI**~~ — ✅ **XONG.** Chốt phương án hai bản; đã dựng hai kênh build, hai tệp
   entitlement, và nhận biết kênh lúc chạy.
2. **Sandbox + bookmark** — sandbox ✅ đã bật; **bookmark chưa làm**, đây là khoản còn lại lớn
   nhất. Ước tính 3–5 ngày, chạm vào tầng phiên và workspace.
3. ~~**Info.plist và đường ký**~~ — ✅ **XONG.** `LSApplicationCategoryType`,
   `CFBundleDocumentTypes`, và nhánh đóng `.pkg` bằng `productbuild`.
4. **DuckDB và plugin** — chưa code, chỉ cần đổi kế hoạch trước khi viết dòng đầu tiên.

**Điều đáng mừng:** không có gì trong lõi phải viết lại. Piece table, mmap, tree-sitter, PCRE2
JIT, dylib nạp lười — tất cả đều hợp lệ y nguyên. Cái giá nằm ở lớp phiên và ở một quyết định
kinh doanh về CLI.

**Điều tôi CHƯA kiểm được, và anh nên tự xác nhận với tài liệu hiện hành của Apple:** luật App
Store đổi theo thời gian, và bản rà này dựa trên hiểu biết của tôi về các yêu cầu ấy chứ không
phải trên một lần nộp thật. Ba điểm đáng kiểm lại trước khi cam kết: (a) `allow-jit` cùng
sandbox có bị hỏi thêm gì không, (b) yêu cầu hiện hành cho app dạng trình soạn thảo truy cập
file rộng, (c) liệu Apple có còn chấp nhận `com.apple.security.files.user-selected.read-write`
cho một app mở file bất kỳ hay đòi thêm lý do.
