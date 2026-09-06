#!/usr/bin/env python3
"""Stop: nhắc nếu có thay đổi mã trong src/ mà DEVIATIONS/SPRINT không đổi và không có commit — không chặn."""
import subprocess
import sys

try:
    out = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout
except Exception:
    sys.exit(0)
changed = [line[3:] for line in out.splitlines()]
src = [c for c in changed if c.startswith("src/")]
if src and not any(c.startswith("docs/SPRINT") for c in changed):
    print("Nhắc: có thay đổi trong src/ nhưng docs/SPRINT-01.md chưa cập nhật trạng thái. Kiểm tra lại trước khi kết thúc.", file=sys.stderr)
sys.exit(0)
