#!/usr/bin/env python3
"""Trạng thái hiện thực so với spec: mỗi nhóm bao nhiêu năng lực đã có handler; tập CDS tương ứng.

Dùng: python scripts/spec_status.py [--ns tool] [--json]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from eide_core.registry import get_registry  # noqa: E402

VOL_NAME = {1: "12.1 Kỹ nghệ", 2: "12.2 Tri thức", 3: "12.3 Hiện thực & tự tạo công cụ", 4: "12.4 Xác minh", 5: "12.5 Quản trị", 6: "12.6 Hội thoại & bộ nhớ"}


def spec_status(ns: str | None = None, as_json: bool = False) -> dict:
    reg = get_registry()
    rows = {}
    for c in reg.list(ns=ns):
        s = c.spec
        r = rows.setdefault(s.ns, {"ns": s.ns, "volume": VOL_NAME.get(s.volume, "?"), "total": 0, "implemented": 0, "m1_pending": []})
        r["total"] += 1
        r["implemented"] += int(c.implemented)
        if not c.implemented and s.milestone in ("M0", "M1"):
            r["m1_pending"].append(s.id)
    if as_json:
        print(json.dumps(list(rows.values()), ensure_ascii=False, indent=1))
    else:
        for r in rows.values():
            print(f"{r['ns']:9} {r['implemented']:3}/{r['total']:<3} CDS-{r['volume']:<34} chưa (M0/M1): {', '.join(r['m1_pending'][:6])}{' …' if len(r['m1_pending']) > 6 else ''}")
        tot = sum(r["total"] for r in rows.values())
        imp = sum(r["implemented"] for r in rows.values())
        print(f"Tổng: {imp}/{tot} năng lực đã hiện thực")
    return rows


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--ns")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    spec_status(a.ns, a.json)
