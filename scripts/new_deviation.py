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
def o(x: str) -> str:
    """Thoát `|` — nó là dấu ngăn cột của bảng Markdown.

    DEV-058 nói về `1/(1+|bm25|)` và cả dòng vỡ thành 14 cột thay vì 10, nên nó biến mất khỏi
    `dong_bo_tai_lieu.py` mà không có gì báo. Một mục sai khác lặng lẽ rơi khỏi báo cáo đồng bộ
    là đúng thứ mà cả quy trình sai khác sinh ra để chống.
    """
    return x.replace("|", r"\|").replace("\n", " ")


row = (f"| DEV-{n:03d} | {datetime.date.today().isoformat()} | {o(a.doc)} | `{o(a.code)}` | "
       f"{o(a.what)} | {o(a.why)} | {o(a.proposal)} | Mở |\n")
f.write_text(text.rstrip("\n") + "\n" + row, encoding="utf-8")
print(f"DEV-{n:03d} đã ghi vào docs/DEVIATIONS.md")
