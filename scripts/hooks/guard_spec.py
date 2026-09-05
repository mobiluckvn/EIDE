#!/usr/bin/env python3
"""PreToolUse: chặn sửa trực tiếp docs/spec/*.json, docx, và nhắc quy tắc DEVIATIONS khi sửa docs/spec/.

Claude Code truyền JSON qua stdin: {tool_name, tool_input:{file_path,...}}. Thoát 2 = chặn (stderr gửi về Claude).
"""
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
path = str((data.get("tool_input") or {}).get("file_path") or "")
if not path:
    sys.exit(0)
p = path.replace("\\", "/")
if p.endswith((".docx", ".xlsx")) and "/docs/ho-so/" in p:
    print("Không sửa docx/xlsx trực tiếp — sửa nguồn sinh trong docs/ho-so/nguon/ sau khi mục DEVIATIONS được duyệt.", file=sys.stderr)
    sys.exit(2)
if "/docs/spec/" in p and p.endswith(("cds.json", "caps.json", "ddd.json")):
    print("cds.json/caps.json/ddd.json là tệp sinh — sửa cds_data_*.py / caps.py trong docs/ho-so/nguon/ rồi sinh lại; ghi DEVIATIONS trước.", file=sys.stderr)
    sys.exit(2)
if "/docs/spec/" in p:
    print("Nhắc: đang sửa đặc tả máy đọc được. Phải có mục DEVIATIONS tương ứng (trạng thái Đã duyệt) và cập nhật nguồn sinh.", file=sys.stderr)
sys.exit(0)
