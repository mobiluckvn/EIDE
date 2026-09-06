# ADR-12 — Plugin native: chỉ ở bản tải trực tiếp, và chạy NGOÀI tiến trình app

**Trạng thái:** Anh chốt **"plugin chỉ có ở bản tải trực tiếp"** ngày 24/08/2026 ·
**Ngày đo:** 24/08/2026 (PoC-H)
**Chạy lại:** `scripts/run-poc-h.sh` → `benchmarks/results/poc-h-arm64.json`
**Mở khoá:** FR-PLUG-702 (plugin native), FR-PLUG-703 (XPC), FR-PLUG-704 (Manager), SEC-03

---

## 1. Quyết định phạm vi, và câu hỏi nó KHÔNG trả lời

Plugin native xung đột trực tiếp với App Store: điều 2.5.2 cấm tải và chạy mã ngoài bundle.
`docs/appstore-ra-soat.md` §4 ghi nó là một trong hai chỗ "thiết kế đang đi vào đường bị cấm".

Anh chốt: **chấp nhận plugin chỉ có ở bản tải trực tiếp.** Bản App Store không có, và nói rõ vì
sao — đúng cách `geditor` CLI (FR-AUTO-605) và lọc qua lệnh ngoài (FR-AUTO-604) đã làm. Cơ chế
đã có sẵn: `Distribution.current` hỏi thẳng chữ ký của chính tiến trình, một binary, một đường
mã.

**Nhưng quyết định ấy không đủ để bắt tay viết mã**, vì "không sandbox" KHÔNG có nghĩa là nạp
được mã lạ. Bản trực tiếp vẫn phải bật **hardened runtime** — bắt buộc để công chứng — và
hardened runtime bật **library validation**.

`Resources/GEditor-Direct.entitlements` đã ghi thẳng điều này từ trước, trong danh sách "cố ý
KHÔNG có ở đây":

> `allow-dyld-environment-variables` / `disable-library-validation`: mở đường nạp mã lạ. Dylib
> grammar nặng (ADR-08) nằm TRONG bundle và ký cùng bundle nên không cần tới chúng.

Nên phải đo trước: hardened runtime có thật sự chặn không, và nếu có thì lối ra nào rẻ nhất.

---

## 2. PoC-H — số đo

Đo chứ không tra tài liệu: luật ký của Apple đổi theo phiên bản macOS, và thứ quyết định là máy
đang chạy chứ không phải trang tài liệu.

Dựng một "plugin" của bên thứ ba (dylib xuất một hàm) và một tiến trình chủ `dlopen` nó, rồi ký
tiến trình chủ theo bốn cách.

| Tiến trình chủ | Kết quả |
|---|---|
| ad-hoc, **không** hardened runtime | ✅ nạp được |
| ad-hoc, **có** hardened runtime | ❌ **bị chặn** |
| hardened runtime + `disable-library-validation` | ✅ nạp được |
| hardened runtime, plugin ký **cùng danh tính** | ❌ bị chặn — xem cảnh báo §2.1 |

dyld nói thẳng lý do:

```
not valid for use in process: mapping process and mapped file (non-platform)
have different Team IDs
```

**Xác nhận: hardened runtime chặn plugin của bên thứ ba, và không có cách nào vòng qua nó mà
không xin entitlement.** Bỏ hardened runtime không phải một lựa chọn — thiếu nó thì không
notarize được, và không notarize thì Gatekeeper chặn bản tải về.

### 2.1 Một ca CHƯA đo được, và đừng đọc bảng trên như thể đã đo

Hàng thứ tư — "plugin ký cùng danh tính" — chạy với chữ ký **ad-hoc**, và chữ ký ad-hoc **không
có Team ID nào cả**. Nên thông báo "different Team IDs" ở hàng ấy rất có thể là hệ quả của việc
ký ad-hoc chứ không phải câu trả lời cho câu hỏi thật.

Câu hỏi thật là: *một dylib ký bằng ĐÚNG Developer ID của ta có nạp được vào app ta, dưới
hardened runtime, mà không cần entitlement nào không?* Theo cách library validation được mô tả
thì có, nhưng **ở đây tôi chưa đo được** — cần tài khoản Developer ID, thứ đang nằm ở
`docs/trang-thai.md` §6 mục 3.

Nó quan trọng vì nếu đúng thì "plugin do CHÍNH TA ký" là một hình dạng thứ ba, không cần nới
lỏng gì cả — nhưng cũng không còn là một hệ sinh thái mở.

### 2.2 Giá của việc chạy plugin ở tiến trình riêng

| | |
|---|---|
| một lần gọi, tiến trình con sống lâu qua ống | **trung vị 0,010 ms** · min 0,005 · p99 0,024 |

Đo bằng một tiến trình con sống lâu nói chuyện qua ống, không phải XPC thật — đó là **cận
dưới**: XPC thêm phần tuần tự hoá và kiểm quyền, nhưng cùng hình dạng "gửi đi, chờ trả lời" và
cũng không khởi động lại tiến trình ở mỗi lần gọi.

Mười micro-giây. So với bất kỳ việc gì một plugin thật sự làm, khoản này bằng không.

---

## 3. Ba hình dạng, và vì sao chọn hình dạng thứ ba

**A. Xin `disable-library-validation` cho app chính.**
Chạy được (đã đo). Nhưng nó tắt library validation cho **cả tiến trình app**, vĩnh viễn, trên
bản giao cho **mọi người dùng** — kể cả người không bao giờ cài một plugin nào. App này mở file
của người khác, chạy regex JIT, và giữ nội dung chưa lưu; nới lỏng đúng cái hàng rào chặn mã lạ
trong chính tiến trình ấy là trả giá sai chỗ.

**B. Chỉ nhận plugin do ta ký.**
Có thể không cần entitlement nào — nhưng §2.1 nói rõ là **chưa đo được**. Và kể cả đúng, nó
biến "plugin" thành "thứ ta phát hành", tức là không còn là điều FR-PLUG-702 nói tới.

**C. Plugin chạy ở TIẾN TRÌNH RIÊNG.** ✅ **Chọn cái này.**
App chính giữ nguyên library validation và giữ nguyên entitlement như hôm nay — **không thêm
một dòng nào**. Chỉ một tiến trình phụ nhỏ mang `disable-library-validation`, và tiến trình ấy
không giữ tài liệu của người dùng, không có quyền gì ngoài thứ được truyền vào.

Đây cũng chính là thứ FR-PLUG-703 đã ghi từ đầu ("XPC"), và giờ nó có số đo đứng sau: cái giá
là 0,01 ms mỗi lần gọi.

**Phạm vi thiệt hại là lý do thật.** Ở phương án A, một plugin hỏng hoặc độc hại chạy trong
cùng không gian địa chỉ với văn bản người dùng đang sửa. Ở phương án C nó chạy ở một tiến trình
khác, và tiến trình ấy chết thì app vẫn sống — mất tính năng của plugin, không mất công việc
đang làm.

---

## 4. Điều này ràng buộc gì cho mã sắp viết

- **Entitlement của app chính KHÔNG đổi.** Nếu một ngày `GEditor-Direct.entitlements` mọc thêm
  `disable-library-validation` thì đó là dấu hiệu ai đó đã bỏ phương án C mà không sửa ADR này.
  Đáng có một chốt chặn trong `build-universal.sh`.
- **Bản App Store không được mang tiến trình phụ ấy.** Một `.xpc` biết nạp mã lạ nằm trong
  bundle nộp lên App Store là mời từ chối, dù nó không bao giờ chạy.
- **`Distribution.current` quyết lúc chạy**, như CLI và lọc lệnh ngoài. Không có `#if`.
- **SEC-03 (chuỗi cung ứng plugin)** từ "chưa dùng tới" thành việc thật: plugin là mã của người
  khác chạy trên máy người dùng. Tối thiểu phải trả lời được "cài từ đâu" và "gỡ thế nào".

---

## 5. Điều PoC này KHÔNG trả lời

- **Dylib ký bằng Developer ID thật** có nạp được vào app ký cùng Developer ID không (§2.1).
  Cần tài khoản Developer ID.
- **Giá của XPC thật**, kể cả tuần tự hoá và kiểm quyền. Con số 0,01 ms là cận dưới đo bằng
  ống, không phải bằng `NSXPCConnection`.
- **API mà plugin nhìn thấy.** Chưa thiết kế. Bài học từ FR-AUTO-603 (scripting JavaScript) áp
  dụng nguyên vẹn: API cố ý HẸP, vì mở rộng về sau thì dễ còn thu hẹp thì phá thứ người khác đã
  viết.
