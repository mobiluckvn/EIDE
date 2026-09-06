# ADR-16 — Kênh tự cập nhật: Sparkle 2, liên kết lúc nạp

**Trạng thái:** chấp nhận · 28/08/2026
**Chỉ tiêu:** NFR-SEC-01 — *"bản cập nhật ký EdDSA (Sparkle 2) tải qua HTTPS"*
**Thay thế:** không · **Liên quan:** ADR-08 (ngân sách khởi động), ADR-14 (nạp lười), `docs/khoa-va-ky.md`

---

## 1. Bối cảnh

`NFR-SEC-01` có hai vế. Vế "ký số & công chứng" đã có đường ống từ lâu và chỉ chờ tài khoản
Developer ID. Vế thứ hai — **kênh tự cập nhật** — thì tới 28/08/2026 vẫn là `grep Sparkle` → 0
file, tức chưa tồn tại. Nó nằm trong ba món nợ chặn phát hành ở `trang-thai.md`.

Sparkle 2 không phải một lựa chọn trong nhiều lựa chọn: đặc tả **gọi thẳng tên nó**. Nên ADR này
không cân nhắc "dùng gì" mà cân nhắc **"gắn vào thế nào"** — và đó là chỗ có đánh đổi thật.

## 2. Quyết định

1. **Vendor `Sparkle.framework` 2.9.6 vào `vendor/sparkle/`**, commit thẳng (không LFS), theo
   đúng khuôn `vendor-mermaid.sh`. Lý do không LFS: 3,0 MB thì mỗi lần nâng cộng vài MB — chấp
   nhận được — còn LFS mang cái bẫy "clone ra một con trỏ 130 byte" mà `.gitattributes` tự nêu.
   Với `libduckdb` 94 MB đánh đổi ấy đáng; với 3 MB thì không.

2. **Liên kết LÚC NẠP, không `dlopen` lười** như `libduckdb` và `libTreeSitterHeavy`. Xem §3 —
   quyết định này dựa trên một phép đo, và phép đo ấy đã tự sửa mình một lần.

3. **`SPUStandardUpdaterController` thì LƯỜI.** Nó chỉ ra đời ở lần đầu người dùng bấm "Kiểm tra
   bản cập nhật…". `SUEnableAutomaticChecks` để `false`: app không tự đi mạng khi chưa ai cho
   phép, và Sparkle sẽ hỏi người dùng ở lần kiểm tra đầu tiên — đó là chỗ đúng để hỏi.

4. **Chỉ bản tải trực tiếp.** Cổng ở `Distribution.supportsSelfUpdate`, cùng họ với
   `supportsCLIBridge` và `supportsTextFilter`. Bản App Store cập nhật qua Apple; nhúng một kênh
   riêng vào bản nộp lên là lý do bị từ chối duyệt.

   **Nhưng mục menu vẫn CÓ MẶT ở cả hai kênh**, và ở bản App Store nó mở một hộp thoại nói vì
   sao. Một mục menu vắng mặt là câu hỏi hỗ trợ; một câu trả lời tại chỗ thì không.

5. **`SUFeedURL = https://geditor.code247.ai/appcast.xml`** — tên miền công ty sở hữu, subdomain
   riêng. Lý do đầy đủ ở `docs/khoa-va-ky.md` §2ter; tóm tắt: đổi URL sau khi phát hành thì mọi
   bản đã cài đứng lại vĩnh viễn, **trong im lặng**, nên URL phải sống độc lập với nhà cung cấp
   hosting.

6. **`SUPublicEDKey` là khoá THẬT từ 28/08/2026** (`XDhykAxCsgq8poBrEByGNfacMG0kco+4qHHLSTtHZ6A=`),
   sinh bằng `generate_keys` trên máy anh Công và kiểm bằng một vòng ký-rồi-thẩm-định thật kèm
   đối chứng âm — `docs/khoa-va-ky.md` §2bis.

   Cổng vẫn giữ nguyên và vẫn có ích: `build-universal.sh` **từ chối KÝ** khi `Info.plist` mang
   chuỗi giữ chỗ. Bản chưa ký thì cho qua kèm cảnh báo — người ta dựng nó hàng chục lần một
   ngày. Bản đã ký là thứ đi ra ngoài, và một kênh cập nhật trỏ tới khoá không tồn tại sẽ hỏng
   đúng lúc nó quan trọng nhất: khi có bản vá cần đẩy đi.

## 3. Giá khởi động — phép đo đã tự sửa mình

ADR-08 chỉ còn **36 ms** dư địa (463,9 ms trên trần 500), nên câu hỏi này phải trả lời bằng số.

**Lượt đo thứ nhất — bằng một binary tổng hợp.** Hai chương trình Swift giống hệt nhau, một cái
thêm `-framework Sparkle` và **không gọi gì trong đó**, 20 lượt mỗi bên:

| | median |
|---|---|
| không Sparkle | 4,54 ms |
| có Sparkle | 5,85 ms |

**Chênh 1,3 ms.** Kết luận lúc ấy: rẻ, liên kết thẳng.

**Lượt đo thứ hai — bằng ỨNG DỤNG THẬT**, sau khi đã gắn xong, `scripts/run-startup-kpi.sh`:

| | trước | sau | |
|---|---|---|---|
| khởi động nguội (median) | 463,9 ms | **481 ms** | ✅ dưới trần 500 |
| trong đó dyld | 229 ms | 281 ms | |

**Chênh ~17 ms, không phải 1,3 ms** — và ổn định qua hai lượt (482 rồi 480), tức **nằm ngoài
dải nhiễu ±40 ms** mà ADR-08 mô tả thì chưa hẳn, nhưng phần `dyld` tăng đều +52 ms ở cả hai lượt
thì không giải thích được bằng nhiễu.

**Vì sao binary tổng hợp nói dối.** Nó không có gì để liên kết ngoài Sparkle, nên nó đo đúng chi
phí *mở thêm một tệp*. Ứng dụng thật thì phải **đăng ký lớp Objective-C** của Sparkle vào runtime
và ghép chúng vào một bảng ký hiệu đã lớn sẵn — khoản ấy tỉ lệ với thứ đã có, không tỉ lệ với thứ
vừa thêm. Đây là lần thứ ba trong cùng một ngày một bộ đo tự dựng cho ra câu trả lời sai vì mẫu
vật không phải vật thật (xem `trang-thai.md` §5bis-c).

**Quyết định giữ nguyên, nhưng phải nói ra cái giá:** dư địa ADR-08 từ 36 ms xuống còn **19 ms**.
Ở mức ấy, một tính năng khởi động-nặng thêm vào sau này sẽ đẩy chỉ tiêu vỡ, và **chỗ lấy lại dư
địa đầu tiên nên là Sparkle** — nó `dlopen` được, chỉ tốn công hơn vì là framework Objective-C.
Đừng đổi trước khi có lý do; nhưng khi cần, đây là chỗ nhìn tới trước.

## 4. Cái đã cân nhắc và bỏ

| Phương án | Vì sao không |
|---|---|
| `dlopen` lười ngay từ đầu | Chưa cần. 17 ms còn nằm trong trần, và một đường nạp lười cho framework Objective-C phức tạp hơn hẳn cho một dylib C — phải gọi qua `NSClassFromString` và mất hết kiểm tra kiểu lúc biên dịch. Đổi phức tạp lấy 17 ms khi còn 19 ms dư địa là mua sớm |
| Hai binary theo cờ biên dịch | Đẻ ra hai ma trận kiểm thử và một khả năng lệch pha — dựng bằng cờ này, ký bằng entitlement kia. Cùng lý do `Distribution` hỏi chữ ký lúc chạy thay vì đọc `#if` |
| Tự viết kênh cập nhật | Đặc tả gọi tên Sparkle. Và phần khó của việc này không phải tải tệp mà là **thẩm định chữ ký, cài đè an toàn, và khôi phục khi cài dở** — ba thứ Sparkle đã làm mười lăm năm |
| Ẩn mục menu ở bản App Store | Người dùng bấm vào là đang hỏi một câu chính đáng. Ẩn đi biến câu hỏi ấy thành một email hỗ trợ |

## 5. Phát hành một bản — và một cái bẫy của chính công cụ Sparkle

`scripts/make-appcast.sh` đóng gói bản đã dựng thành `.zip` rồi sinh `appcast.xml` đã ký.

**Tách khỏi `build-universal.sh` có chủ ý.** Dựng là việc làm hàng chục lần một ngày; sinh
appcast là việc làm MỘT LẦN cho mỗi bản phát hành, và nó ghi đè một tệp mà mọi bản đã cài ngoài
kia đang hỏi tới. Trộn hai nhịp ấy là mời một lần `--channel direct` lúc nửa đêm đẩy nhầm một
bản dở lên feed.

### Cái bẫy, đã kiểm bằng vật thật 28/08/2026

Đưa `generate_appcast` một khoá **không khớp** `SUPublicEDKey` của bản giao, nó:

1. in đúng một dòng `Warning:` ra stdout,
2. ghi ra một appcast **KHÔNG có `edSignature` nào**,
3. rồi **thoát 0**.

Nghĩa là đường phát hành mặc định — chạy script, thấy *"Wrote 1 new update"*, đẩy lên máy chủ —
cho ra một feed mà **mọi bản đã cài sẽ từ chối**, và không bước nào trong đường ấy kêu lên.
Một `Warning` giữa dòng chảy log không phải một cổng; **mã thoát mới là**.

Nên `make-appcast.sh` **không tin mã thoát của `generate_appcast`**. Nó đọc lại `edSignature` từ
appcast, thẩm định bằng chính `SUPublicEDKey` trong bản giao, và có **đối chứng âm** ngay trong
bước kiểm: cùng chữ ký ấy phải TỪ CHỐI một gói đã thêm một byte — vì một hàm `verify` luôn trả
`true` cũng cho ra đúng dòng ✅. Đã xác nhận cả ba đường:

| Tình huống | `generate_appcast` | `make-appcast.sh` |
|---|---|---|
| khoá đúng | thoát 0 | ✅ thoát 0 |
| gói bị sửa một byte | *(không biết)* | ❌ thoát 1 |
| **ký bằng khoá khác** | **thoát 0**, không chữ ký | ❌ **thoát 1** |

## 6. Còn nợ

- **Một vòng cập nhật chạy thử đầu-đến-cuối.** Còn thiếu đúng hai thứ, và cả hai đều ở ngoài kho
  mã: một **máy chủ HTTPS** phục vụ `geditor.code247.ai` (Sparkle từ chối feed `http://`), và
  **hai bản dựng khác phiên bản** để có cái mà cập nhật lên.
- **Ký thật bằng Developer ID** — chờ tài khoản của anh Công.

*Ranh giới phải giữ cho rõ:* phần đã có được canh bằng 2 test lõi, 1 bài tự kiểm, và bước kiểm
chữ ký trong `make-appcast.sh`. Chúng chứng minh **feed sinh ra là hợp lệ và ký đúng khoá bản
giao**. Chúng **không** chứng minh **app tải về và cài được** — đó là thứ chỉ một vòng chạy thật
qua HTTPS mới trả lời. Đừng đọc nhầm hai điều ấy.
