# Khoá và chữ ký — có những khoá gì, cất ở đâu, mất thì sao

**Cập nhật 28/08/2026.** Trang này tồn tại vì một câu hỏi rất thật: *"máy hỏng thì sao?"*

Câu trả lời ngắn: **mất khoá Sparkle là không cứu được.** Không phải "bất tiện" — là không bao
giờ ký được bản cập nhật nào nữa cho những máy đã cài bằng khoá cũ. Người dùng sẽ đứng lại ở
phiên bản họ đang có, im lặng, và cách duy nhất để họ đi tiếp là tải tay một bản mới. Đó là lý
do trang này nói về sao lưu trước khi nói về bất cứ thứ gì khác.

---

## 1. Bốn khoá, và vai của từng cái

| Khoá | Dùng để | Mất thì |
|---|---|---|
| **EdDSA riêng (Sparkle)** | ký *appcast* + gói cập nhật, để bản đã cài tin bản mới | **Không cứu được.** Phải phát hành khoá mới, và mọi bản đã cài KHÔNG nhận được cập nhật nữa |
| **Developer ID Application** (`.p12` + khoá riêng) | ký app cho bản tải trực tiếp (NFR-SEC-01) | Cứu được — thu hồi rồi xin cấp lại ở Apple Developer. Nhưng **thu hồi có thể làm hỏng cả bản đã phát hành** |
| **App Store Connect API key** (`AuthKey_*.p8`) hoặc mật khẩu riêng cho ứng dụng | công chứng (`notarytool`) | Cứu được dễ — sinh cái mới, huỷ cái cũ |
| **Khoá SSH đẩy git** | push lên `github.com/mobiluckvn/Geditor` | Cứu được dễ — thêm khoá mới trong cài đặt GitHub |

Đường ống ký đọc hai biến môi trường và **không đọc gì trong kho mã**:
`GEDITOR_SIGN_IDENTITY` và `GEDITOR_NOTARY_PROFILE` (xem `scripts/build-universal.sh`).

---

## 2. Vì sao KHÔNG cất trong git, kể cả kho private

Đã cân nhắc và bác bỏ ngày 28/08/2026. Ba lý do, đều cụ thể với kho này:

1. **Kho được chép sang máy người khác ở mỗi lần push.** `.github/workflows/ci.yml` chạy trên
   runner `macos-14` của GitHub với `actions/checkout@v4`. Một khoá trong kho là một khoá nằm
   trên một máy ảo không ai trong nhóm kiểm soát, mỗi lần build. *"Private"* nói về ai đọc được
   trang web, không nói về nơi tệp đi tới.

2. **Commit là thao tác không hoàn tác được.** Xoá ở commit sau không xoá khỏi lịch sử. Muốn
   sạch thật thì phải viết lại lịch sử **và vẫn phải đổi khoá** — nên "lỡ thì sửa" không tồn tại.

3. **Khoá EdDSA không phải mật khẩu, nó là quyền chạy mã trên máy mọi người dùng.** Ai giữ nó
   cũng ký được một binary bất kỳ thành "GEditor 1.1", và mọi bản đã cài sẽ tự nuốt, im lặng.
   Đó đúng hình dạng tấn công mà `PluginTrust` (NFR-SEC-03) từ chối theo thiết kế: *"đã ĐỔI kể
   từ lần duyệt thì TỪ CHỐI, không hỏi"*. Để khoá cập nhật trong kho là gỡ chính lập luận ấy ở
   tầng trên nó một bậc.

**Cổng giữ điều này:** `scripts/check-no-secrets.sh`, chạy trong CI (bước đầu tiên) và cài được
làm móc pre-commit — mục 5.

---

## 2bis. Khoá Sparkle trong kho — ĐÃ CÓ KHOÁ THẬT (28/08/2026)

**Khoá thật đã sinh và đã vào kho.** Anh Công chạy `vendor/sparkle/bin/generate_keys` trên máy
mình; khoá riêng nằm trong Keychain của anh (chỗ `sign_update` đọc lúc phát hành) và một bản sao
ở `secrets/sparkle_eddsa_private.txt` theo quyết định ghi ở §2.

| | |
|---|---|
| `SUPublicEDKey` | `XDhykAxCsgq8poBrEByGNfacMG0kco+4qHHLSTtHZ6A=` — trong `Resources/Info.plist` |
| Khoá riêng | Keychain của anh Công · bản sao `secrets/sparkle_eddsa_private.txt` (32 byte hạt giống, base64) |
| Cổng | `check-no-secrets.sh` vẫn bật; hai đường dẫn khai trong `NGOAI_LE`. Đã kiểm: một khoá thứ hai đặt tên khác VẪN bị chặn |

**Kiểm bằng vòng thật trước khi đưa vào, không tin suông vào định dạng** — đúng chỗ lần trước đã
sai: `sign_update` ký một gói bằng tệp khoá ấy, chữ ký **thẩm định đúng** bằng khoá công khai suy
ra từ chính tệp, và **đối chứng âm** — sửa một byte của gói thì chữ ký bị từ chối. Khoá công khai
suy từ tệp **khớp đúng** khoá `generate_keys -p` đọc từ Keychain, nên bản sao và bản Keychain là
một. Bundle dựng ra mang đúng chuỗi ấy trong `Info.plist`.

**Việc còn lại của anh, làm một lần:** cất `~/Desktop/khoa-sparkle.txt` vào chỗ an toàn (mục 4)
rồi **xoá bản trên Desktop** — Desktop không phải chỗ để một con dấu nằm lâu.

**Từ đây, đổi `SUPublicEDKey` là việc KHÔNG quay lại được** sau lần phát hành công khai đầu tiên:
mọi bản đã cài chỉ tin đúng khoá này.

---

## 2bis-a. *(hồ sơ)* Lần đầu đã hỏng thế nào, và vì sao giữ lại mục này

**Anh Công quyết định ngày 28/08/2026 để khoá riêng trong kho, dạng thô**, sau khi đánh đổi ở §2
được trình bày ba lần. Lý do của anh: kho private, và cần một bản sao lưu phòng khi máy hỏng.
**Quyết định ấy vẫn còn hiệu lực** — mục này không lật nó. Nhưng tệp khoá đã bị gỡ khỏi kho
cùng ngày, vì một lý do khác hẳn: **khoá ấy không dùng được.**

### Chuyện đã xảy ra

Khoá được sinh bằng ed25519 chuẩn rồi mã hoá base64 64 byte (`seed‖public`, đúng bố cục
libsodium). Nhìn thì đúng. Nhưng đem `bin/sign_update` **của chính Sparkle 2.9.6** ra thử thì nó
từ chối, kèm một thông báo tự mâu thuẫn:

```
ERROR! Imported key must be 64 bytes or 96 bytes (for the older format) decoded.
       Instead it is 64 bytes decoded.
```

Nó nói *"phải 64 hoặc 96"* rồi từ chối đúng 64. Thử tiếp ba bố cục 96 byte
(`secret‖pub`, `pub‖secret`, `seed‖pub‖seed`): cả ba đều **ký được**, nhưng không chữ ký nào
thẩm định nổi bằng khoá công khai tương ứng — kiểm độc lập bằng ed25519, có đối chứng âm.

### Và câu trả lời hoá ra nằm trong `--help`, không nằm trong thông báo lỗi

**Định dạng đúng là 32 BYTE — hạt giống (seed) trần.** `generate_keys --help` nói thẳng:
*"if the private key is generated in the new format (i.e. the key file after base64 decoding is
32 bytes), then the exported key file is the base64 encoding of the private seed"*. Thông báo
lỗi của `sign_update` chỉ kể hai định dạng CŨ (64 và 96) và **không nhắc 32** — nên nó dẫn người
đọc đi sai hướng, và tôi đã đi theo.

Đã kiểm bằng vật thật: sinh ed25519, ghi 32 byte hạt giống dạng base64, `sign_update -f` ký được,
chữ ký **thẩm định đúng** bằng khoá công khai tương ứng, và **đối chứng âm** — sửa một byte của
gói thì chữ ký bị từ chối.

*Bài học vẫn giữ nguyên, chỉ đổi chỗ: thông báo lỗi của một công cụ cũng là tài liệu, và nó
cũng lạc hậu được. Khi thông báo lỗi và `--help` nói khác nhau, tin `--help`.*

### Vì sao gỡ đi thay vì để đó

Một khoá ký **không hoạt động mà trông như đã xong** tệ hơn không có khoá: nó là đúng loại nợ mà
`trang-thai.md` §5.3 bắt được nhiều lần — *"tính năng có chỗ bấm mà không có gì phía sau"*. Để
nó nằm trong `secrets/` là mời người sau tin vào một thứ sẽ hỏng đúng lúc phát hành.

Mất mát bằng không: khoá ấy chưa ký gì, chưa vào `Info.plist` của bản nào, và sẽ không bao giờ
được dùng — nên việc nó còn nằm trong lịch sử git không bảo vệ hay đe doạ điều gì.

### Bài học, và nó lặp lại đúng bài học của phiên ấy

**Đọc tài liệu định dạng không thay được việc chạy công cụ thật.** Bố cục `seed‖public` là bố cục
libsodium chuẩn và mọi lập luận đều đúng — chỉ có điều Sparkle không đọc như vậy. Cùng ngày, cổng
`check-no-secrets.sh` cũng chỉ lộ lỗ hổng khi đem **khoá thật** ra thử chứ không phải khi đọc mã.
Hai lần, một kết luận: **thử bằng vật thật.**

### Cách làm ĐÚNG, khi anh sẵn sàng

Sinh bằng chính công cụ của Sparkle. Nay ta đã biết định dạng (32 byte hạt giống) nên về lý
thuyết sinh tay cũng được — nhưng vẫn dùng `generate_keys`, vì nó đặt khoá vào **Keychain**, và
Keychain mới là chỗ `sign_update` đọc khi ký lúc phát hành. Cần **anh** chạy vì Keychain hỏi quyền:

```sh
./bin/generate_keys        # ghi khoá riêng vào Keychain, in khoá công khai
./bin/generate_keys -x khoa-rieng-sparkle.txt   # xuất ra tệp để sao lưu / để commit
```

Đưa tôi tệp ấy thì tôi commit vào `secrets/` theo đúng ý anh, khai lại `NGOAI_LE`, **và lần này
kiểm bằng một vòng ký-rồi-thẩm-định thật trước khi commit** — không commit một khoá chưa chứng
minh được là dùng được.

**Một ghi chú về thời điểm, nói một lần:** tới trước lần phát hành công khai đầu tiên, đổi ý về
chỗ cất khoá vẫn còn miễn phí, vì chưa bản nào ngoài kia tin khoá nào cả. Sau đó thì không.

**Hai việc nên làm kèm, không tốn gì:** vẫn giữ một bản ngoài git theo mục 4 (kho private không
chống được trường hợp mất quyền truy cập tài khoản GitHub), và **đừng bao giờ chuyển kho sang
public** — một cú bấm "Change visibility" là công khai cả lịch sử.

---

## 2ter. URL của appcast — CHỐT `https://geditor.code247.ai/appcast.xml`

Anh giao tôi chọn, 28/08/2026. Chọn theo đúng một tiêu chí, vì chỉ một tiêu chí là không đảo
ngược được: **URL phải sống lâu bằng sản phẩm.** Đổi nó sau khi đã phát hành nghĩa là mọi bản đã
cài không bao giờ thấy bản cập nhật nào nữa, và hỏng **trong im lặng** — người dùng không thấy
lỗi, họ chỉ đứng lại mãi ở phiên bản cũ.

Từ đó suy ra thẳng: URL phải nằm trên **tên miền công ty sở hữu**, không phải tên miền của nhà
cung cấp hosting.

| Phương án | Vì sao không |
|---|---|
| GitHub Pages / `*.github.io` | Kho đang **private** — Pages của kho private cần gói trả phí, và tài sản release cũng đòi xác thực. Ngoài ra đổi nhà cung cấp là đổi URL |
| S3 / Netlify / Vercel với tên miền của họ | Cùng bệnh: rời nhà cung cấp là phải đổi URL, mà đó đúng là thứ không đổi được |
| Một đường dẫn dưới `code247.ai` | Được, nhưng buộc appcast đi chung vòng đời với trang giới thiệu công ty |
| **Subdomain `geditor.code247.ai`** ✅ | Công ty sở hữu tên miền, nên **hosting đổi bên dưới mà URL không đổi**. Tách khỏi trang chính nên trỏ đi đâu cũng được — S3, Netlify, hay một VPS — chỉ sửa DNS |

Ràng buộc kèm theo, đều là điều kiện của Sparkle: **HTTPS bắt buộc** (Sparkle từ chối feed
`http://`), và appcast là **tệp tĩnh** — không cần máy chủ ứng dụng, chỉ cần một chỗ phục vụ
tệp. Sinh bằng `bin/generate_appcast` của Sparkle.

**Đã vào `Resources/Info.plist`** cùng `SUPublicEDKey` (còn là chỗ giữ chỗ) và
`SUEnableAutomaticChecks=false` — xem `docs/adr/ADR-16-sparkle.md`.

---

## 2quater. Giá khởi động của Sparkle — đo hai lần, và lần hai lật lần một

ADR-08 chỉ còn **36 ms dư địa** (463,9 ms trên trần 500), nên câu hỏi *"nạp Sparkle có phá ngân
sách khởi động không"* phải trả lời bằng số trước khi viết dòng mã nào.

Đo 28/08/2026, hai binary giống hệt nhau, một cái liên kết `Sparkle.framework` 2.9.6 và **không
gọi gì trong đó**, 20 lượt mỗi bên:

| | median | min |
|---|---|---|
| không Sparkle | 4,54 ms | 3,64 ms |
| **có Sparkle** | **5,85 ms** | 5,25 ms |

**Chênh ~1,3 ms** trên sàn nhiễu khoảng 1 ms. Framework 3,0 MB.

> ⚠️ **CON SỐ NÀY ĐÃ BỊ CHÍNH ỨNG DỤNG THẬT LẬT.** Sau khi gắn xong, `run-startup-kpi.sh` cho
> **481 ms** so với 463,9 ms trước đó — chênh **~17 ms, không phải 1,3 ms** — và ổn định qua hai
> lượt (482 rồi 480). Binary tổng hợp không có gì để liên kết ngoài Sparkle nên nó đo đúng chi
> phí *mở thêm một tệp*; ứng dụng thật còn phải **đăng ký lớp Objective-C** của Sparkle vào một
> bảng ký hiệu đã lớn sẵn, và khoản ấy tỉ lệ với thứ ĐÃ CÓ chứ không với thứ vừa thêm.
>
> Quyết định giữ nguyên — 481 vẫn dưới trần 500 — nhưng **dư địa ADR-08 từ 36 ms xuống 19 ms**,
> và đó là con số phải nói ra. Chi tiết và hệ quả ở `docs/adr/ADR-16-sparkle.md` §3.

*Vẫn còn một vế chưa đo: `SPUStandardUpdaterController` khởi tạo tốn thêm bao nhiêu — nhưng nó
LƯỜI (chỉ dựng khi người dùng bấm), nên nó không nằm trên đường khởi động.*

---

## 3. Sinh khoá EdDSA và cất nó

```sh
# Sparkle phát hành sẵn công cụ này trong bản tải về của nó.
./bin/generate_keys
```

Nó làm hai việc: ghi **khoá riêng vào Keychain** của máy đang chạy, và in ra **khoá công khai**.

- **Khoá công khai** đi thẳng vào `Info.plist` (`SUPublicEDKey`). Nó *nên* nằm trong kho — công
  khai là đúng bản chất của nó, và nó phải đi cùng app.
- **Khoá riêng** ở lại Keychain. Xuất ra để sao lưu:

```sh
./bin/generate_keys -x khoa-rieng-sparkle.txt   # xuất ra tệp
# …cất tệp ấy đi (mục 4), rồi XOÁ HẲN bản trên đĩa:
rm -P khoa-rieng-sparkle.txt
```

Khôi phục trên máy mới: `./bin/generate_keys -f khoa-rieng-sparkle.txt`.

---

## 4. Cất ở đâu — hai bản, hai chỗ

Một bản sao lưu không phải là sao lưu: ổ cứng hỏng và trình quản lý mật khẩu bị khoá tài khoản
là hai sự cố khác nhau, và một chỗ cất chỉ chống được một trong hai.

1. **Trình quản lý mật khẩu** (1Password, Bitwarden, hoặc iCloud Keychain) — dán nội dung khoá
   vào một mục ghi chú bảo mật. Đây là bản dùng hằng ngày.
2. **Ảnh đĩa mã hoá trên ổ ngoài** — bản không phụ thuộc nhà cung cấp nào:

```sh
hdiutil create -encryption AES-256 -stdinpass -size 10m \
    -volname "GEditor Keys" -fs APFS ~/khoa-geditor.dmg
```

Chép vào đó: khoá riêng Sparkle, `.p12` Developer ID (xuất từ Keychain Access), `AuthKey_*.p8`,
và **một tệp văn bản ghi ngày sinh từng khoá cùng Team ID** — sáu tháng sau không ai nhớ tệp
`.p8` kia thuộc tài khoản nào.

> **Việc phải làm TAY, cố ý.** Không tự động hoá bước này: tự động hoá nghĩa là có một máy nào
> đó cầm được khoá, và khi ấy ta quay lại đúng vấn đề đang tránh.

---

## 5. Móc pre-commit — chỗ NGĂN thật sự

Cổng trong CI chỉ **báo**; lúc nó đỏ thì commit đã tồn tại và anh vẫn phải đổi khoá. Chỗ ngăn
được là máy của anh:

```sh
printf '#!/bin/sh\nexec ./scripts/check-no-secrets.sh --staged\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Móc này **chỉ đọc và từ chối**, không tự sửa gì — một móc tự sửa thứ nó đo là một móc không còn
đo được gì nữa. Kiểm rằng nó sống:

```sh
./scripts/check-no-secrets.sh --tu-kiem   # bắn khoá giả vào bộ dò, đòi nó kêu
```

`.gitignore` đã chặn sẵn các đuôi thường gặp, nhưng `.gitignore` chỉ giúp khi tên tệp đúng
khuôn — cổng mới là thứ đọc NỘI DUNG.

---

## 6. CI cần ký thì lấy khoá ở đâu

**GitHub Actions secrets** (`Settings ▸ Secrets and variables ▸ Actions`): mã hoá phía GitHub,
bơm vào build dưới dạng biến môi trường, không nằm trong kho. Đúng chỗ mà `build-universal.sh`
đang đọc `GEDITOR_SIGN_IDENTITY` và `GEDITOR_NOTARY_PROFILE`.

Hôm nay nhánh ký **chưa chạy trong CI** — nó chờ tài khoản Developer ID (§6 của
`docs/trang-thai.md`). Khi bật, hai điều cần nhớ: secret không hiện lại được sau khi lưu (mất
thì đặt lại, không đọc ra được), và log của Actions **che** giá trị secret nhưng **không che**
thứ do chính script in ra — nên đừng `echo` biến ký ở bất cứ đâu.

---

## 7. Trường hợp xấu nhất — nếu khoá lộ thật

Theo thứ tự, và **làm ngay chứ đừng điều tra trước**:

1. **Developer ID** — thu hồi ở Apple Developer, xin cấp lại, ký và phát hành lại bản mới.
2. **API key công chứng** — huỷ ở App Store Connect, sinh cái mới.
3. **EdDSA Sparkle** — nặng nhất, và **không có nút thu hồi**: khoá công khai đã nằm trong mọi
   bản đã cài. Việc phải làm là phát hành một bản mang khoá công khai MỚI, rồi báo cho người
   dùng tải tay — vì bản cũ vẫn tin khoá cũ. Đây là lý do khoá này được nói tới nhiều nhất trong
   trang này.
4. **Khoá SSH** — gỡ khỏi GitHub, thêm khoá mới.

Sau khi đã xử lý xong mới đi tìm nguyên nhân. Thứ tự ngược lại là thứ tự khiến khoảng thời gian
kẻ tấn công còn dùng được khoá dài ra.
