# Bảng mã tiếng Việt legacy — ghi chép kỹ thuật

| | |
|---|---|
| **Yêu cầu** | FR-ENC-201 (bảng mã Việt legacy), FR-ENC-202 (tự nhận diện), FR-ENC-203 (diễn giải lại vs chuyển đổi) |
| **Mã** | `Sources/GEditorCore/Encoding/` |
| **Sinh bảng** | `scripts/generate-encoding-tables.py` |
| **Ngày** | 20/08/2026 |

Không phải quyết định kiến trúc nên không đánh số ADR. Nhưng bốn điều dưới đây không hiển
nhiên, và người làm tiếp sẽ mất cả ngày để tự phát hiện lại.

---

## 1. Bảng mã được SUY RA, không gõ tay

Một bảng 256 ô gõ sai một ô không làm chương trình hỏng — nó làm hỏng **file của người dùng**,
im lặng: mở ra thấy chữ khác, lưu lại là mất bản gốc. Bảng chép từ một trang web cũng không
kiểm chứng được.

Cả ba bảng vì thế được suy từ bộ chuyển đổi **có sẵn trên máy**, theo hai chiều độc lập, và
bộ sinh bắt hai chiều phải khớp nhau:

| Bảng mã | Nguồn |
|---|---|
| TCVN3 (ABC) | `iconv "TCVN-5712-1:1993"` |
| VISCII | `iconv "VISCII"` |
| Windows-1258 | `iconv "CP1258"` **và** codec `cp1258` của Python — hai hiện thực khác nhau, phải khớp trên cả 256 byte |

Bất biến được kiểm ở mỗi lần sinh: **mã hóa lại ký tự vừa giải mã ra phải cho lại đúng byte
ban đầu**. Không thỏa thì bộ sinh dừng và không ghi file.

## 2. Ba cái bẫy của chính các bộ chuyển đổi hệ thống

Phát hiện khi làm, mỗi cái đều làm bảng sai theo một kiểu riêng:

- **Bộ giải mã TCVN của macOS hỏng ở vùng ASCII** — nó trả `U+0000` cho *mọi* chữ cái ASCII.
  Tin nó thì mọi file tiếng Việt mở ra mất sạch phần chữ không dấu. Vùng ASCII vì vậy lấy
  theo định nghĩa của chuẩn, không hỏi bộ chuyển đổi.
- **Chiều mã hóa nhận cả ký tự thay thế.** VISCII dùng byte `0xA4` cho chữ "ấ", nhưng bộ mã
  hóa cũng nhận `U+00A4 ¤` vào đúng byte đó. Suy bảng từ chiều mã hóa sẽ đặt ký hiệu tiền tệ
  vào giữa vùng đông chữ Việt nhất. **Chiều giải mã mới là bên có thẩm quyền** — đó đúng là
  câu hỏi đang hỏi: "byte này trong file nghĩa là chữ gì".
- **`iconv` âm thầm thay ký tự không có trong bảng mã.** Gạch ngang dài `–` thành `-`. Fixture
  test vì thế phải loại những mẫu như vậy, nếu không nó sẽ bắt codec của ta bắt chước một
  phép thay thế thầm lặng — đúng thứ ta cố ý không làm.

## 3. TCVN3 giấu chữ trong vùng điều khiển

TCVN3 đặt **12 chữ HOA có dấu vào vùng C0** (`0x01`–`0x17`): Ú Ụ Ừ Ử Ữ Ứ Ự Ỳ Ỷ Ỹ Ý Ỵ.
VISCII cũng có 6 chữ ở đó.

Điều may mắn — và bộ sinh **khẳng định lại ở mỗi lần chạy** chứ không coi là hiển nhiên — là
cả hai né đúng `0x00`, `0x09`, `0x0A`, `0x0D`. Nhờ vậy tách dòng và tab vẫn chạy trên file
TCVN3. Nếu một bảng mã nào đó không né, bộ sinh sẽ dừng và báo bảng mã đó không dùng được cho
trình soạn thảo.

## 4. Nhận diện: thống kê byte KHÔNG đủ

TCVN3 và VISCII phủ đúng cùng một kho chữ Việt. Mọi dòng byte hợp lệ ở bảng này đọc sang bảng
kia vẫn ra **100% chữ Việt** — chỉ khác ở chỗ ghép lại có thành từ hay không:

```
đúng (TCVN3):   Cộng hòa Xã hội Chủ nghĩa Việt Nam
sai  (VISCII):  Céng hưa Xở héi Chự nghỵa Viỷt Nam
sai  (CP1258):  Cµng ḥa Xă hµi Chü nghîa Vi®t Nam
```

Dòng thứ ba tách được bằng thống kê (26–37% byte đọc ra chữ Việt). Dòng thứ hai thì không —
nó cần **chính tả**. Bộ nhận diện dùng ba quy tắc, chọn vì chúng đúng với mọi văn bản tiếng
Việt và kiểm được **mà không cần từ điển**:

| | Quy tắc | Bắt được |
|---|---|---|
| A | `đ` chỉ đứng đầu âm tiết | "Viđt" |
| B | Mỗi âm tiết mang tối đa một dấu thanh | "Cụũng" |
| F | Chữ hoa không nằm giữa từ | "hoÌa" |

Một danh sách vần tiếng Việt hợp lệ sẽ mạnh hơn nhiều, nhưng viết nó từ trí nhớ thì đúng bằng
việc gõ tay bảng mã — thứ mà cả module này dựng ra để tránh.

**Hệ quả phải chấp nhận:** trên đoạn văn bản ngắn không có dấu hiệu phân biệt, TCVN3 và VISCII
có thể hòa điểm. Đó là lý do `EncodingDetector.detect` trả về **danh sách xếp hạng kèm phần
trăm** chứ không phải một đáp án — banner "Phát hiện Windows-1258 (62%)" của UI/UX §4.2 cần
đúng con số đó, và người dùng phải chọn lại được.

## 5. Kết hợp dấu lúc giải mã

TCVN3 và CP1258 viết "ế" thành **hai byte**: chữ nền rồi dấu thanh. Giải mã thô cho ra dạng tổ
hợp, trong khi người dùng gõ bàn phím tiếng Việt ra dạng dựng sẵn. Hai dạng khác byte nhau nên
**tìm kiếm trượt, diff báo khác, khóa CSV so sai** — dù trên màn hình trông giống hệt.

Codec vì thế kết hợp **ngay trong lúc giải mã**, và tách ngược lúc mã hóa. Bảng kết hợp (194
cặp) cũng được sinh ra, từ chính chuẩn hóa NFC của Unicode.

## 6. Việc còn lại

1. **VNI-Windows chưa làm.** Nó là bảng mã hai byte (chữ nền + byte dấu) và không có bộ chuyển
   đổi nào trên máy để suy bảng. Cần bản đặc tả của nhà cung cấp — không gõ tay, vì lý do ở §1.
2. **Đọc file lớn theo khối.** `EncodingConverter.decode` hiện nhận `[UInt8]` cả file. Codec
   một byte thì chuyển sang xử lý theo khối rất dễ (không có trạng thái nào vắt qua biên trừ
   một dấu tổ hợp đang chờ), nhưng UTF-16/32 phải đi qua `String` nên cần bộ giải mã riêng.
3. **Nối vào đường mở file** — hiện lõi có đủ mảnh nhưng chưa ai gọi: mở file phải chạy
   `EncodingDetector`, giải mã, và giữ lại byte gốc cho `reinterpret`.
4. **FR-ENC-205 hiện ký tự ẩn** và **FR-ENC-207 mặc định cho file mới** chưa bắt đầu.
