#!/usr/bin/env python3
"""Thêm mục vào docs/DEVIATIONS.md với mã DEV-xxx kế tiếp."""
import argparse
import datetime
import re
from pathlib import Path

ap = argparse.ArgumentParser()
for k in ("doc", "code", "what", "why", "proposal"):
    ap.add_argument(f"--{k}", required=True)
a = ap.parse_args()
f = Path(__file__).resolve().parents[1] / "docs" / "DEVIATIONS.md"
text = f.read_text(encoding="utf-8")
n = max([int(x) for x in re.findall(r"\| DEV-(\d{3}) \|", text)] or [0]) + 1
row = f"| DEV-{n:03d} | {datetime.date.today().isoformat()} | {a.doc} | `{a.code}` | {a.what} | {a.why} | {a.proposal} | Mở |\n"
f.write_text(text.rstrip("\n") + "\n" + row, encoding="utf-8")
print(f"DEV-{n:03d} đã ghi vào docs/DEVIATIONS.md")
