---
description: In hợp đồng đầy đủ + danh sách tài liệu phải đọc cho một năng lực (ns.name)
---
Với năng lực `$ARGUMENTS`:

1. Chạy `python -m eide.cli caps describe $ARGUMENTS` (PYTHONPATH=src) để lấy hợp đồng: input_schema, output_schema, steps, errors, undo, tc, example, volume.
2. Mở `docs/spec/capabilities/<ns>.yaml` và tìm mục tương ứng; đối chiếu với cds.json (phải trùng).
3. Liệt kê quy tắc chính sách áp dụng: `grep -n "<cổng của năng lực>" docs/spec/policy/rules.yaml` và các tình huống trong `situations.jsonl` cùng cổng.
4. Tìm entity dữ liệu liên quan trong `docs/spec/data/json/` (theo tên trong steps/output) và bảng trong `schema.sql`.
5. Tìm phương thức JSON-RPC/MCP liên quan trong `docs/spec/api/openrpc.json`, `mcp_tools.json`.
6. Nêu use case tham chiếu (`ref` trong hợp đồng) và mở sheet 11 của `docs/ho-so/EIDE_Use_Case_Chi_Tiet_v1.2.xlsx` bằng `python scripts/uc_steps.py <UC-xx>` để xem bước gọi năng lực này.
7. Tóm tắt bằng tiếng Việt: năng lực làm gì, vào/ra, lỗi, cổng, undo, tiêu chí xong; ghi rõ chỗ nào tài liệu chưa đủ để hiện thực (sẽ thành mục DEVIATIONS nếu phải tự quyết).

Không viết mã trong lệnh này.
