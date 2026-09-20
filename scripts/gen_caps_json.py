#!/usr/bin/env python3
"""Sinh `docs/spec/caps.json` từ `docs/ho-so/nguon/excel/caps.py`.

## Vì sao tệp này cần tồn tại

`caps.json` là danh mục năng lực máy-đọc-được, và nó là đầu vào của gần như mọi thứ:
`gen_cds.py` sinh `cds.json` + `capabilities/*.yaml` từ nó, hai bộ sinh Excel đọc nó,
`validate_specs.py` đối chiếu với nó, và `Registry` nạp `cds.json` sinh ra từ nó.

Danh sách gốc nằm trong `excel/caps.py` — một tệp Python với các bộ `add(ns, rows)`. Tới
20/09/2026 **không kịch bản nào trong kho nối hai đầu ấy lại**: `caps.json` được sinh một lần
ở đâu đó rồi chép vào kho (cùng hình dạng với [DEV-037]). Nghĩa là sửa `caps.py` xong thì
`caps.json` vẫn là bản cũ, và người sửa tưởng mình vừa đổi danh mục.

Chạy: `python scripts/gen_caps_json.py` — hoặc `--kiem` để chỉ đối chiếu, không ghi.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parent.parent
NGUON = GOC / "docs" / "ho-so" / "nguon" / "excel"
DICH = GOC / "docs" / "spec" / "caps.json"

# Thứ tự cột của mỗi dòng trong `caps.py`, sau `(mã, nhóm)` mà `add()` tự gắn.
COT = ("name", "desc", "inp", "out", "risk", "tier", "ground", "ask", "ref", "ms", "m0")


def nap() -> list[dict[str, str]]:
    sys.path.insert(0, str(NGUON))
    import caps  # noqa: PLC0415 — nạp sau khi đã chỉnh sys.path

    return [dict(code=r[0], ns=r[1], **dict(zip(COT, r[2:], strict=True))) for r in caps.C]


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--kiem", action="store_true", help="chỉ đối chiếu, không ghi")
    a = p.parse_args()

    moi = nap()
    cu = json.loads(DICH.read_text(encoding="utf-8")) if DICH.exists() else []

    if moi == cu:
        print(f"caps.json khớp nguồn — {len(moi)} năng lực")
        return 0

    ten_cu = {c["code"] for c in cu}
    ten_moi = {c["code"] for c in moi}
    for c in sorted(ten_moi - ten_cu):
        print(f"  + {c} {next(x['name'] for x in moi if x['code'] == c)}")
    for c in sorted(ten_cu - ten_moi):
        print(f"  - {c} {next(x['name'] for x in cu if x['code'] == c)}")
    doi = [c["code"] for c in moi if c in moi and c not in cu and c["code"] in ten_cu]
    for c in sorted(set(doi)):
        print(f"  ~ {c} đổi nội dung")

    if a.kiem:
        print(f"LỆCH: {len(cu)} → {len(moi)} năng lực. Chạy `python scripts/gen_caps_json.py`.")
        return 1

    DICH.write_text(json.dumps(moi, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"đã ghi {DICH.relative_to(GOC)} — {len(cu)} → {len(moi)} năng lực")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
