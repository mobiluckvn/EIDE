---
description: Bắt đầu một phiên làm việc — đọc CLAUDE.md, trạng thái spec, chọn việc kế tiếp trong SPRINT
---
Bắt đầu phiên làm việc EIDE theo đúng nguyên tắc "đọc tài liệu rồi phát triển":

1. Đọc `CLAUDE.md` và `docs/INDEX.md` (bắt buộc, kể cả đã đọc ở phiên trước).
2. Chạy `python scripts/spec_status.py` và đọc `docs/SPRINT-01.md`; liệt kê các mục trạng thái `Chưa` theo thứ tự ưu tiên, nêu phụ thuộc.
3. Đọc `docs/DEVIATIONS.md` — nếu có mục `Mở` liên quan đến việc sắp làm thì áp dụng quyết định trong đó, không mở lại tranh luận.
4. Đề xuất **một** việc kế tiếp (một năng lực hoặc một WI), nêu: mã năng lực, tài liệu sẽ đọc (CDS tập nào, quy tắc POL nào, entity DDD nào), tiêu chí xong lấy từ trường `tc` trong cds.json, và nền tảng sẽ kiểm (Mac trước).
5. Dừng lại chờ xác nhận nếu việc ảnh hưởng ≥ 3 nhóm năng lực; nếu không thì tiếp tục bằng `/thuc-hien <ns.name>`.

$ARGUMENTS
