#!/usr/bin/env python3
"""Tóm tắt một TC xuống những dòng quyết định được phán quyết.

Rút đúng sáu thứ: tác tử hiểu câu hỏi thành Ý ĐỊNH gì, định chạy CHUỖI nào, HỎI lại điều gì,
bước nào HỎNG, nói gì ở khung chat, và các TAB có nội dung thật hiện gì.

Bỏ đi: lời chào lặp ở mọi bước, và những dòng "→ mở màn … ở NỀN" lặp hàng chục lần một lượt.
Cả hai đều là cùng một chuỗi ký tự nhân bản, không mang thêm tin nào.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parent.parent


def tom(ma: str, dai: int = 900) -> str:
    thu = GOC / "docs/test/usecase" / ma
    p = thu / "nhat-ky.md"
    if not p.exists():
        return f"===== {ma}: CHƯA chạy"
    v = p.read_text(encoding="utf-8")
    ra = [f"===== {ma}"]

    kq = thu / "ket-qua.json"
    if kq.exists():
        d = json.loads(kq.read_text(encoding="utf-8"))
        ra.append(f"[{d.get('uu_tien')} {d.get('loai')}] {d.get('ten')}")
        ra.append(f"CHỜ: {d.get('cho')}")
        c = d.get("cham", {})
        ra.append(f"sàng: {c.get('so_bo')} · thiếu={c.get('thieu')} · thừa={c.get('thua')}")

    chat = v.split("**Quét")[0]
    for nhan, rx in [("Ý ĐỊNH", r"ý hiểu: `([^`]+)`"),
                     ("CHUỖI", r"Tôi sẽ ([^.]{0,200})\."),
                     ("HỎI", r"TÁC TỬ HỎI\s*·\s*(\S+)\s+(.{0,220}?)(?:…hoặc gõ|Trả lời)"),
                     ("HỎNG", r"✖ Bước `([^`]+)` HỎNG — (E\d+): ([^\n]{0,160})"),
                     ("XONG", r"(✅ Xong \d+/\d+ bước|⏸ DỪNG[^\n]{0,80})")]:
        for m in dict.fromkeys(re.findall(rx, chat)):
            ra.append(f"  {nhan}: {m if isinstance(m, str) else ' | '.join(m)}")

    for m in re.finditer(r"### Tab `([^`]+)`\n\n```\n(.*?)\n```", v, re.S):
        ten, chu = m.group(1), m.group(2)
        chu = re.sub(r"Vùng làm việc trống[^|]{0,120}?tự mở đúng màn\.", "", chu)
        chu = re.sub(r"\s+", " ", chu).strip()
        if "màn trống" in chu or len(chu) < 90:
            continue
        ra.append(f"  TAB {ten}: {chu[:dai]}")

    m = re.search(r"### Cột phải[^`]*```\n(.*?)\n```", v, re.S)
    if m:
        c = re.sub(r"\s+", " ", m.group(1)).strip()
        if len(c) > 60:
            ra.append(f"  CỘT PHẢI: {c[:400]}")
    return "\n".join(ra)


if __name__ == "__main__":
    for ma in [x for x in sys.argv[1:] if x.startswith("TC")]:
        print(tom(ma))
        print()
