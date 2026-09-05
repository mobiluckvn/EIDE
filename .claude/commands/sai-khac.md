---
description: Ghi một mục sai khác giữa mã và tài liệu vào docs/DEVIATIONS.md
---
Ghi mục sai khác mới. Thu thập đủ 6 trường rồi chạy:

`python scripts/new_deviation.py --doc "<Mã tài liệu §mục>" --code "<tệp/hàm>" --what "<sai khác>" --why "<lý do>" --proposal "<đề xuất sửa tài liệu hoặc mã>"`

Yêu cầu: (a) `--doc` ghi mã tài liệu và mục cụ thể (ví dụ `API-15 §3 errors.json`, `CDS-12.3 TOOL-05 steps[2]`); (b) `--what` mô tả đúng điều mã làm khác tài liệu, không mô tả cảm nhận; (c) `--proposal` nêu rõ **sửa tài liệu** hay **sửa mã**, và nếu sửa tài liệu thì nguồn sinh nào trong `docs/ho-so/nguon/` sẽ đổi. Sau khi ghi, nhắc mã DEV-xxx trong commit và trong SPRINT-01.md.

Ngữ cảnh: $ARGUMENTS
