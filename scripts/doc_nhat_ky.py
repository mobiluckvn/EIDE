#!/usr/bin/env python3
"""Trích phần đáng đọc của nhật ký một TC — bỏ lời chào và phần lặp của vùng trao đổi.

Nhật ký đầy đủ nằm trong `.docx` cho chủ sản phẩm rà; bản trích này để đọc nhanh 76 ca mà không
mất cái cần đọc: tác tử hiểu câu hỏi thành gì, chạy chuỗi nào, nói gì, và màn hình hiện gì.

Cắt ở đây là cắt PHẦN LẶP — lời chào ba dòng giống hệt nhau ở mọi bước, và những dòng
"→ mở màn …" lặp hàng chục lần. Không cắt phần nội dung.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parent.parent


def trich(ma: str, het: bool = False) -> str:
    p = GOC / "docs/test/usecase" / ma / "nhat-ky.md"
    if not p.exists():
        return f"{ma}: CHƯA có nhật ký"
    v = p.read_text(encoding="utf-8")
    khoi = v.split("## Bước ")
    lay = khoi[1:] if het else khoi[-1:]
    ra = [f"===== {ma}"]
    for b in lay:
        b = re.sub(r"VÙNG TRAO ĐỔI.*?bất kỳ lúc nào\.", "[chào]", b, flags=re.S)
        b = re.sub(r"(→ mở màn [^\n]{0,80}?\)\s*){3,}",
                   lambda m: m.group(0)[:160] + " …(lặp) ", b)
        b = re.sub(r"\n{3,}", "\n\n", b)
        ra.append(b.strip())
    return "\n".join(ra)


if __name__ == "__main__":
    het = "--het" in sys.argv
    for ma in [x for x in sys.argv[1:] if x.startswith("TC")]:
        print(trich(ma, het))
        print()
