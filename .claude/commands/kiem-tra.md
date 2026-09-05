---
description: Chạy toàn bộ kiểm tra (ruff, pytest, đối chiếu spec) và báo cáo ngắn
---
Chạy `make check`. Nếu đỏ: sửa cho đến khi xanh; không được nới lỏng test đối chiếu spec (`tests/test_specs_consistency.py`) — nếu test đó đỏ nghĩa là mã đã lệch spec và cần `/sai-khac` hoặc sửa mã. Kết thúc bằng báo cáo 5 dòng: số test, năng lực đã hiện thực/tổng (`python scripts/spec_status.py`), mục DEVIATIONS Mở, nền tảng đã kiểm, việc kế tiếp.
