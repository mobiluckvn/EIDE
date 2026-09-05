#!/usr/bin/env python3
"""PostToolUse: sau khi sửa tệp Python → ruff (nếu có) trên tệp đó; sửa capabilities/*.yaml → kiểm khớp cds.json."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
path = (data.get("tool_input") or {}).get("file_path")
if not path:
    sys.exit(0)
p = Path(path)
if p.suffix == ".py" and shutil.which("ruff"):
    r = subprocess.run(["ruff", "check", "--select", "PTH,F,E9", str(p)], capture_output=True, text=True)
    if r.returncode:
        print(r.stdout[-1500:], file=sys.stderr)
if p.suffix == ".yaml" and "capabilities" in p.parts:
    r = subprocess.run([sys.executable, "scripts/validate_specs.py"], capture_output=True, text=True)
    if r.returncode:
        print(r.stdout[-1500:] + r.stderr[-500:], file=sys.stderr)
sys.exit(0)
