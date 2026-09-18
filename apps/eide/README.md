# EIDE — bản giao diện viết lại (18/09/2026)

Gói Swift **riêng**, viết từ đầu theo đúng hai nguồn:

| Nguồn | Quy định |
|---|---|
| `docs/EIDE_UI_Demo_v2.html` | HÌNH DẠNG — năm vùng, kích thước, màu, bong bóng |
| `docs/EIDE-UXC-31_Checklist_UI_UX_cho_tac_tu.md` | HÀNH VI — bất biến B1–B8, tiêu chí N1–N10 |

## Vì sao một gói riêng

Bản cũ (`apps/geditor/Sources/EIDEKit`) lớn lên bằng cách vá: mỗi yêu cầu mới thêm một vùng,
một ràng buộc, một bảng tra. Tới 18/09 nó có ba bảng màn hình chép tay, ba mươi ràng buộc bố
cục viết tay, và bốn lỗi bố cục sống sót vì không ai nhìn ra hình dạng tổng thể nữa.

Tách gói để ranh giới có thật: không `import EIDEKit` được thì không lỡ tay kéo một quyết định
cũ sang.

## Cái gì được mang sang, cái gì không

| Mang sang | Cách |
|---|---|
| Token màu, cỡ chữ, khoảng cách | **SINH LẠI** từ `docs/spec/ui/tokens.json` (`scripts/gen_ui_swift.py` ghi cho cả hai gói) |
| Tên phương thức JSON-RPC, mã lỗi | **SINH LẠI** từ `docs/spec/api/openrpc.json` |
| Client JSON-RPC | **VIẾT LẠI**, mang theo bốn bài học đã trả giá — xem `EideDaemon` |
| Danh mục 25 màn | **VIẾT LẠI** thành MỘT nguồn `EideManHinhDS` (bản cũ có ba bản sao, cả ba đã lệch) |
| Mọi thứ khác | không mang |

## Phụ thuộc

```
EideApp ──▶ EideGiaoDien ──▶ EideLoi
```

`EideLoi` KHÔNG import AppKit: client và mô hình dữ liệu phải test được mà không dựng cửa sổ.
`EideGiaoDien` không nói chuyện với daemon — nó nhận dữ liệu đã đọc sẵn.

## Chạy

```bash
swift run EideApp                    # mở cửa sổ
swift run EideApp --chup /tmp/anh    # dựng, chụp, thoát — để so với bản demo
swift test                           # bài kiểm bố cục
```

## Ba bài học bố cục đã trả giá, ghi ở đây để không lặp lại

1. **`NSStackView` phá ràng buộc nội bộ của CHÍNH NÓ ở ưu tiên ≤ 999 mà không ghi log.** Mọi
   SÀN đặt bên trong một stack đều có thể bị nuốt im lặng. Bản cũ dựng bố cục bằng stack lồng
   nhau và cửa sổ tụt từ 720 pt xuống 70 pt, không một dòng cảnh báo nào. Vì thế khung ở đây
   dùng ràng buộc tường minh trên khung nhìn thường.
2. **Định nghĩa vòng tròn giải ở giá trị nhỏ nhất.** `A.height == B.height` trong khi chiều cao
   `B` lại suy từ `A` là hợp lệ với Auto Layout, và nó cho ra 0.
3. **`NSScrollView` không có kích thước nội tại.** Thay một `NSTextView` bằng một vùng cuộn là
   mất luôn chiều cao mà bố cục đang dựa vào; phải cho nó một sàn.

## Nối daemon — `EidePhien` (18/09)

`EidePhien` là chỗ DUY NHẤT daemon và khung nhìn biết nhau. Khung nhìn phát ra ý định
(`onChon`, `onGui`, `onDuyet`…), phiên gọi JSON-RPC, rồi đẩy dữ liệu đã đọc trở lại. Bản cũ
không có lớp này: mỗi màn tự gọi `caps.invoke`, nên hai màn hỏi cùng một thứ theo hai cách và
không ai đọc được luồng điều khiển của cả cửa sổ ở một chỗ.

```bash
swift run EideApp --tu-kiem          # 9 phép đo trên dự án tạm — không chạm workspace thật
swift run EideApp --chup /tmp/anh    # chụp cả màn chào lẫn khung đầy đủ
```

`--tu-kiem` tạo dự án dùng một lần trong `$TMPDIR` rồi xoá. Bài tự kiểm của bản cũ chạy trên
dự án đang làm dở và cài cờ dừng khẩn lên đó; hôm sau không ai hiểu vì sao tác tử ngồi im.

### Năm lỗi im lặng của vòng nối này

Tất cả đều hiện ra như dữ liệu bình thường — không lỗi, không log, không test đỏ.

1. **`ISO8601DateFormatter` từ chối dấu thập phân của giây.** `datetime.isoformat()` bên Python
   ghi `…:45.123456+00:00`; bộ phân tích mặc định trả `nil`, nên MỌI mục hoàn tác có hạn thật
   hiện "hạn không rõ". Một dòng chữ vô hại trông y hệt dữ liệu thiếu, trong khi thứ thiếu là
   một cờ `.withFractionalSeconds`.
2. **Mục hoàn tác thiếu `cap` hiện thành "?".** Trường ấy chỉ thêm vào `undo.register` từ giữa
   chặng, nên bản ghi cũ không có. `kind` thì luôn có. Không ai bấm hoàn tác một việc tên "?".
3. **Thẻ ở cột phải tràn ra ngoài vùng cắt.** `NSStackView` để thẻ rộng theo nhãn dài nhất rồi
   đẩy phần thừa ra ngoài — `code.merge_conflict_resolve` dài hơn cột 236 pt, và cái mất đi là
   chữ chứ không phải một cảnh báo.
4. **Cờ dừng khẩn núp sau mức tự chủ.** `autonomy.get` trả cả `autonomy` lẫn `stopped`, mà thanh
   trên chỉ đọc cái đầu: một dự án bị chặn sạch vẫn báo "Tự chủ A2". Người đọc rồi ngồi đợi tác
   tử làm việc mà nó sẽ không bao giờ làm.
5. **Hàng hoàn tác xếp cũ-trước.** Sổ cái trả theo thứ tự ghi; cột chỉ hiện 8 thẻ, nên thứ người
   vừa làm — thứ gần như luôn là thứ họ muốn đảo — nằm ngoài tầm nhìn.

Và một món vệ sinh kho: `apps/eide/.build/` (2588 tệp) từng được commit, vì mẫu `build/` trong
`.gitignore` không khớp `.build/` — dấu chấm đầu là một ký tự thật.

## Màn thật — `EideManCoSo` (18/09)

Ba màn đầu nối dữ liệu: **Tổng quan** (S1, `session.state` + `budget.state`), **Nhật ký** (S2,
`view.timeline`), **Chính sách tự chủ** (S25, `policy.rules`). Bảng `EidePhien.MAN` là chỗ duy
nhất khai một màn đã nối, và có bài kiểm đối chiếu từng khoá với danh mục 25 màn.

Màn nhận đúng MỘT khả năng: gọi một phương thức JSON-RPC. Không tham chiếu daemon, không tham
chiếu khung. Ba thứ mọi màn KHÔNG THỂ quên vì chúng nằm ở lớp cơ sở: nhãn "Đang đọc…", trạng
thái rỗng hai phần (lý do + bước kế tiếp), và bóc vỏ `CapabilityRun`.

### Bảy lỗi im lặng nữa của vòng này

1. **Ba kết cục khác nhau hiện thành một câu.** `caps.invoke` trả nguyên bản ghi lượt chạy khi
   lượt ấy bị cổng giữ, bị từ chối, hoặc hỏng — bên gọi đọc `r["result"]` thấy `nil` cho cả ba.
   Sau khi bấm Dừng khẩn, màn Chính sách báo *"PolicyGate không nạp được quy tắc nào"*: một câu
   vừa sai vừa đáng sợ, trong khi sự thật là lời gọi vừa bị chính cái nút ấy chặn.
2. **`project.open` chưa bao giờ được gọi.** Bật daemon với `-p` mới là nói cho nó biết thư mục;
   năm bước của PROJECT-02 thì không chạy. Mất cả ba: phiên làm việc không mở (màn Tổng quan
   hiện "chưa mở phiên nào" trên một dự án đang mở), niêm store không được kiểm (E6000 đi thẳng
   vào phiên), `user_version` không được so (E6003 hỏng dần thay vì dừng ngay).
3. **Và khi được gọi thì nó trả E2000 trong im lặng.** Tham số `project` nhận TÊN, nhưng daemon
   chạy với `ctx.project_dir` chính là dự án, nên nó tra tên ấy bên trong chính nó. Lỗi nằm
   TRONG kết quả chứ không phải một lỗi JSON-RPC, nên bên gọi vẫn báo "đã mở".
4. **Nhãn "Đang đọc…" bị xoá trước cả `await` đầu tiên.** Màn Nhật ký trên sổ cái lớn đứng
   trắng trơn hơn hai giây — không tiêu đề phụ, không dòng chờ, nhìn y hệt một màn hỏng.
5. **Đọc 9 128 sự kiện để vẽ 120 dòng.** 2 651 ms chờ lõi so với 40 ms vẽ. Sửa ở HỢP ĐỒNG
   (`limit` + `total`, DEV-132) chứ không cắt ở giao diện: cắt ở đây thì mỗi bên gọi tự cắt một
   kiểu, và ai cũng đã trả giá cho toàn bộ dữ liệu rồi.
6. **Bề rộng thân màn định nghĩa vòng tròn.** Stack dọc căn `.leading` không kéo giãn khung nhìn
   con; màn bên trong lại lấy bề rộng theo thân. Auto Layout chấp nhận và giải ra giá trị NHỎ
   NHẤT: bảng bốn cột co còn ~190 pt, chữ tràn ra ngoài nền hàng, mọi cột sau cột thứ hai rơi
   xuống dòng kế. Đủ chữ nên nó đọc như một kiểu trình bày xấu.
7. **Từ điển lồng in bằng mô tả của Objective-C.** Xuống dòng, và escape tiếng Việt thành
   `\U1edbp`. Mỗi bản ghi `cap.run.start` chiếm sáu dòng không ai đọc được.

Và một phép đo mới: `--tu-kiem` nay tính cả THỜI GIAN mở mỗi màn, không chỉ nội dung. Một màn
trắng hơn hai giây là một màn người dùng cho là hỏng, mà không phép kiểm nội dung nào bắt được.
