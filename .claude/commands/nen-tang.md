---
description: Kiểm tra tính đa nền tảng của thay đổi hiện tại (Mac trước, Windows/Linux sau)
---
Rà thay đổi đang có (git diff) theo `docs/PLATFORM.md`: đường dẫn dạng chuỗi có `/` hoặc `\\`; `os.path` thay vì `pathlib`; `shell=True`; tên cổng nối tiếp hard-code; đường dẫn Homebrew/Program Files hard-code; giả định kiến trúc CPU. Liệt kê từng vi phạm với dòng và cách sửa. Sau đó chạy `ruff check --select PTH src tests`. Cuối cùng ghi vào SPRINT-01.md nền tảng đã kiểm thực tế cho việc này (`mac-intel`, `mac-arm`, `win`, `linux`) — chỉ ghi nền tảng đã chạy test thật, không suy đoán.

$ARGUMENTS
