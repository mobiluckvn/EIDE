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
