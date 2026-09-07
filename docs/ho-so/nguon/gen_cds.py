# -*- coding: utf-8 -*-
"""Sinh cds.json (cho docx) và capabilities/*.yaml từ caps.json + cds_data_*.py"""
import json, re, os, yaml
from cds_data_a import D as A
from cds_data_b import D as B
from cds_data_c import D as C
from cds_data_d import D as DD
DATA = {**A, **B, **C, **DD}
caps = json.load(open("caps.json"))
UNDO_DEFAULT = {"R0": "none", "R1": "supersede_facts", "R2": "delete_created_files", "R3": "reflash_known_good", "R4": "none"}

def parse_type(spec):
    spec = spec.strip(); desc = ""
    if " # " in spec: spec, desc = [x.strip() for x in spec.split(" # ", 1)]
    req = spec.endswith("!"); spec = spec.rstrip("!")
    m = re.match(r"arr<(.+)>$", spec)
    if m:
        item = parse_type(m.group(1))[0]; s = {"type": "array", "items": item}
    elif spec.startswith("enum:"):
        s = {"type": "string", "enum": spec[5:].split("|")}
    elif spec == "json":
        # Giá trị JSON BẤT KỲ — không ràng `type`. Khác `obj`: DDD-14 §2 dùng chữ "object" cho
        # cột kiểu với nghĩa "lưu dạng JSON (số/chuỗi/đối tượng)", nhưng trong JSON Schema
        # `"type":"object"` chỉ nhận đối tượng. Chép thẳng chữ ấy sang làm `project.preferences`
        # từ chối chính ví dụ của nó (`"value":"stlink"`). Xem DEVIATIONS DEV-009.
        s = {}
    else:
        s = {"type": {"str": "string", "int": "integer", "num": "number", "bool": "boolean", "obj": "object"}[spec]}
    if desc: s["description"] = desc
    return s, req

def schema(fields):
    props, req = {}, []
    for k, v in fields.items():
        s, r = parse_type(v); props[k] = s
        if r: req.append(k)
    return {"type": "object", "properties": props, "required": req, "additionalProperties": False}

VOL = {"req": 1, "arch": 1, "diagram": 1, "doc": 1, "plan": 1, "archive": 2, "search": 2, "extract": 2, "passport": 2, "kg": 2, "board": 2, "view": 2,
       "env": 3, "code": 3, "project": 3, "tool": 3, "discover": 4, "sim": 4, "target": 4, "debug": 4, "measure": 4, "bench": 4, "policy": 5, "registry": 5, "report": 5, "chat": 6, "memory": 6}
out, missing = [], []
os.makedirs("capabilities", exist_ok=True)
by_ns = {}
for c in caps:
    d = DATA.get(c["name"])
    if not d: missing.append(c["name"]); continue
    inp, outp = schema(d["inp"]), schema(d["out"])
    rec = dict(code=c["code"], id=c["name"], ns=c["ns"], name=c["name"], desc=c["desc"], risk=c["risk"], tier=c["tier"], grounding=c["ground"], ask_when=c["ask"], ref=c["ref"], milestone=c["ms"], m0=c["m0"],
               input_schema=inp, output_schema=outp, steps=d["steps"], errors=d["err"], undo=d["undo"] or UNDO_DEFAULT[c["risk"][:2]], example=d["ex"], tc=d["tc"], volume=VOL[c["ns"]])
    out.append(rec); by_ns.setdefault(c["ns"], []).append(rec)
for ns, recs in by_ns.items():
    y = [dict(code=r["code"], id=r["id"], name=r["desc"][:80], desc=r["desc"], input=r["input_schema"], output=r["output_schema"], risk=r["risk"], tier=r["tier"], grounding=[r["grounding"]] if r["grounding"] not in ("—", "") else [], ask_when=[r["ask_when"]] if r["ask_when"] not in ("—", "") else [], undo={"kind": r["undo"]}, milestone=r["milestone"], impl=f"eide.{ns}:{r['id'].split('.')[1]}", errors=r["errors"], example=json.loads(r["example"]) if r["example"].startswith("{") else r["example"]) for r in recs]
    yaml.safe_dump(y, open(f"capabilities/{ns}.yaml", "w"), allow_unicode=True, sort_keys=False, width=200)
json.dump(out, open("cds.json", "w"), ensure_ascii=False)
print(len(out), "caps with detail;", "missing:", missing)
