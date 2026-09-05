# -*- coding: utf-8 -*-
"""Sinh json/*.json, schema.sql, ddd.json (cho docx) từ ddd_model.py"""
import json, os
from ddd_model import E, YAML_FILES, MIGRATIONS
os.makedirs("data/json", exist_ok=True)
ddl = ["-- EIDE store.sqlite — sinh từ EIDE-DDD-14 (ddd_model.py). PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;"]
for e in E:
    props, req = {}, []
    for f in e["fields"]:
        name, jt, sql, r, desc, enum = f
        p = {"type": "string", "format": "date-time"} if jt == "date-time" else {"type": jt}
        if enum: p["enum"] = [x for x in enum if x is not None]
        if desc: p["description"] = desc
        props[name] = p
        if r: req.append(name)
    schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": f"https://eide.code247.ai/schema/{e['table']}.json", "title": e["name"], "description": e["desc"], "type": "object", "required": req, "properties": props, "additionalProperties": False}
    json.dump(schema, open(f"data/json/{e['table']}.json", "w"), ensure_ascii=False, indent=1)
    cols = [f"  {f[0]} {f[2]}" for f in e["fields"]]
    if e["pk"].startswith("("): cols.append(f"  PRIMARY KEY {e['pk']}")
    ddl.append(f"CREATE TABLE IF NOT EXISTS {e['table']} (\n" + ",\n".join(cols) + "\n);")
    for i, idx in enumerate(e["indexes"]): ddl.append(f"CREATE INDEX IF NOT EXISTS ix_{e['table']}_{i} ON {e['table']} {idx};")
ddl.append("CREATE VIRTUAL TABLE IF NOT EXISTS rag_chunk_fts USING fts5(text, keywords, content='rag_chunk', content_rowid='rowid');")
open("data/schema.sql", "w").write("\n".join(ddl) + "\n")
json.dump({"entities": E, "yaml": YAML_FILES, "migrations": MIGRATIONS}, open("ddd.json", "w"), ensure_ascii=False)
print(len(E), "entities;", sum(len(e["fields"]) for e in E), "fields")
