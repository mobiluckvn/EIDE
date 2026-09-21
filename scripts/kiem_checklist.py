#!/usr/bin/env python3
"""Cưỡng chế luật §11.2 của EIDE-UXC-31 trên chính tệp checklist.

§11.2: *"Tác tử KHÔNG đánh dấu `[x]` mục nào thiếu bằng chứng (bài kiểm hoặc ảnh chụp); mục bị
chặn ghi `[!]` + lý do + hỏi người."*

Đó là một luật về HÀNH VI của tác tử, nên để nó ở dạng một câu trong tài liệu là để nó phụ thuộc
vào trí nhớ của chính cái nó ràng buộc. Ở đây nó thành một phép kiểm:

1. mọi dòng `[x]` phải có chú thích bằng chứng sau dấu `·`;
2. mọi dòng `[!]` phải có lý do;
3. không dòng nào vừa `[x]` vừa nói "CHƯA" — hai lần trong ba ngày tôi suýt để lại đúng thứ đó.

Chạy trong `make check` và trong CI. Trượt là chặn, đúng tinh thần §10.3.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parents[1]
TEP = GOC / "docs/EIDE-UXC-31_Checklist_UI_UX_cho_tac_tu.md"

DONG = re.compile(r"^- \[(x| |!)\] \*\*([^*]+)\*\*(.*)$")
#: Chữ báo "chưa xong" mà một dòng đã tick KHÔNG được chứa.
CAM_KHI_TICK = ("**CHƯA**", "CHƯA đo được", "**MỘT NỬA**")


def main() -> int:
    loi: list[str] = []
    for so, dong in enumerate(TEP.read_text(encoding="utf-8").splitlines(), 1):
        m = DONG.match(dong)
        if not m:
            continue
        danh, ma, duoi = m.group(1), m.group(2).strip(), m.group(3)
        bang_chung = duoi.split("  ·  ", 1)[1].strip() if "  ·  " in duoi else ""

        if danh == "x":
            if not bang_chung:
                loi.append(f"{so}: `{ma}` tick mà KHÔNG có bằng chứng sau dấu `·` (§11.2)")
            for c in CAM_KHI_TICK:
                if c in bang_chung:
                    loi.append(f"{so}: `{ma}` tick nhưng chú thích vẫn nói {c!r} — "
                               "một trong hai nói sai")
        elif danh == "!" and len(bang_chung) < 20:
            loi.append(f"{so}: `{ma}` đánh `[!]` mà không nêu lý do đủ để truy (§11.2)")

    if loi:
        print(f"§11.2 — {len(loi)} vi phạm trong {TEP.relative_to(GOC)}:")
        for x in loi:
            print("  " + x)
        return 1
    print(f"§11.2 khớp: {TEP.relative_to(GOC)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
