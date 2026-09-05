#!/usr/bin/env python3
"""Kiểm nhất quán docs/spec: capabilities/*.yaml ↔ cds.json ↔ caps.json; rules.yaml biên dịch được; openrpc hợp lệ."""
import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from eide_core.paths import spec_dir  # noqa: E402
from eide_core.policy import compile_rule  # noqa: E402

S = spec_dir()
errs = []
cds = {c["id"]: c for c in json.loads((S / "cds.json").read_text(encoding="utf-8"))}
caps = {c["name"]: c for c in json.loads((S / "caps.json").read_text(encoding="utf-8"))}
if set(cds) != set(caps):
    errs.append(f"cds.json và caps.json lệch: {set(cds) ^ set(caps)}")
seen = set()
for f in sorted((S / "capabilities").glob("*.yaml")):
    for row in yaml.safe_load(f.read_text(encoding="utf-8")):
        seen.add(row["id"])
        if row["id"] not in cds:
            errs.append(f"{f.name}: {row['id']} không có trong cds.json")
        elif row["input"] != cds[row["id"]]["input_schema"] or row["output"] != cds[row["id"]]["output_schema"]:
            errs.append(f"{f.name}: schema {row['id']} khác cds.json")
if seen != set(cds):
    errs.append(f"capabilities/*.yaml thiếu: {set(cds) - seen}")
for r in yaml.safe_load((S / "policy" / "rules.yaml").read_text(encoding="utf-8"))["rules"]:
    try:
        compile_rule(r["when"])
    except Exception as e:  # noqa: BLE001
        errs.append(f"rules.yaml {r['id']}: {e}")
rpc = json.loads((S / "api" / "openrpc.json").read_text(encoding="utf-8"))
names = [m["name"] for m in rpc["methods"]]
if len(names) != len(set(names)):
    errs.append("openrpc.json có phương thức trùng tên")
for e in errs:
    print("LỖI:", e)
print(f"spec: {len(cds)} năng lực, {len(names)} phương thức RPC, {'OK' if not errs else str(len(errs)) + ' lỗi'}")
sys.exit(1 if errs else 0)
