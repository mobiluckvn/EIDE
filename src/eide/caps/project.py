"""Namespace project.* — CDS-12.3 (tập Hiện thực), DDD-14 project/feature, UC-A01."""
from __future__ import annotations

import json
import re
import time
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core.errors import EideError
from eide_core.paths import project_dir_default, spec_dir
from eide_core.registry import capability
from eide_core.router import Context

EIDE_DIR = ".eide"
SUBDIRS = ["store", "session", "index", "docs", "diagrams"]


def slugify(text: str) -> str:
    """Slug ASCII từ tiếng Việt có dấu (CDS PROJECT-01 bước 1)."""
    t = unicodedata.normalize("NFD", text).encode("ascii", "ignore").decode()
    t = re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower()
    return t[:48] or "du-an"


def infer_name(text: str) -> str:
    """Suy tên dự án từ câu lệnh: bỏ các cụm mệnh lệnh đầu câu (DPS-09 §Intent)."""
    t = text.strip()
    pat = r"^(hãy|giúp|tạo|làm|mở|cho anh|cho tôi|cho mình|cho em|dự án|project|new|mới|một|1)\s+"
    while re.match(pat, t, flags=re.I):
        t = re.sub(pat, "", t, count=1, flags=re.I)
    return t.strip(" .:") or text.strip()


def _similar(a: str, b: str) -> bool:
    """Trùng gần: Levenshtein ≤ 2 hoặc ≥ 2 từ khóa chung (CDS PROJECT-01 bước 2)."""
    if a == b:
        return True
    if abs(len(a) - len(b)) <= 2 and _lev(a, b) <= 2:
        return True
    return len(set(a.split("-")) & set(b.split("-")) - {"du", "an", "robot"}) >= 2


def _lev(a: str, b: str) -> int:
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


@capability("project.create", features=["name_conflict"])
def create(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-01 — CDS-12.3; POL-17 GEN-03 (ghi đè = R4); DDD-14 project; undo delete_created_files.

    Tạo dự án từ câu lệnh: suy tên/slug/thư mục, kiểm trùng (E2001 nếu trùng đúng tên; gần giống → existing[]
    và created=false khi create_when_exists=ask), tạo .eide/ với cấu trúc SDD-04 §6.
    """
    workspace = Path(params.get("dir") or ctx.project_dir or project_dir_default()).expanduser()
    name = params.get("name") or infer_name(params["text"])
    slug = slugify(name)
    if not slug or slug == "du-an" and not params.get("name"):
        raise EideError("E1000", "Không suy được tên dự án từ câu lệnh; hãy nêu tên")
    workspace.mkdir(parents=True, exist_ok=True)
    existing = [p for p in workspace.iterdir() if (p / EIDE_DIR).is_dir()]
    same = [p for p in existing if p.name == slug]
    if same:
        raise EideError("E2001", f"Dự án '{slug}' đã tồn tại", options=["reuse", "clone", "new"], path=str(same[0]))
    near = [{"id": p.name, "path": str(p)} for p in existing if _similar(p.name, slug)]
    policy = ctx.extra.get("create_when_exists", "ask")
    if near and policy == "ask":
        return {"project_id": slug, "path": str(workspace / slug), "created": False, "existing": near, "next": ["chat.clarify"]}
    root = workspace / slug
    eide = root / EIDE_DIR
    for d in SUBDIRS:
        (eide / d).mkdir(parents=True, exist_ok=True)
    defaults = yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))
    autonomy = {k: defaults[k] for k in ("autonomy", "thresholds", "trusted_sources", "trusted_packages", "undo_window", "ask_timeout_s", "defaults", "escalation") if k in defaults}
    if params.get("autonomy"):
        autonomy["autonomy"] = params["autonomy"]
    (eide / "autonomy.yaml").write_text(yaml.safe_dump(autonomy, allow_unicode=True, sort_keys=False), encoding="utf-8")
    constraints = {"project": {"id": slug, "name": name, "created": datetime.now(UTC).isoformat(), "text": params["text"]},
                   "target": {"chip": params.get("chip"), "board": params.get("board")}}
    (eide / "constraints.yaml").write_text(yaml.safe_dump(constraints, allow_unicode=True, sort_keys=False), encoding="utf-8")
    (eide / "FEATURES.json").write_text(json.dumps({"features": []}, ensure_ascii=False, indent=2), encoding="utf-8")
    (eide / "PROGRESS.md").write_text(f"# {name}\n\n- {time.strftime('%Y-%m-%d %H:%M')} — tạo dự án từ lệnh: \"{params['text']}\"\n", encoding="utf-8")
    (eide / ".gitignore").write_text("store/\nsession/\nindex/\n", encoding="utf-8")
    nxt = []
    if params.get("chip"):
        nxt.append("project.set_target")
    if params.get("docs_path"):
        nxt.append("archive.explore")
    if not nxt:
        nxt.append("search.reference_projects")
    return {"project_id": slug, "path": str(root), "created": True, "existing": near, "next": nxt}


@capability("project.list")
def list_projects(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-03 — CDS-12.3; quét workspace tìm .eide/, sắp theo last_open giảm dần."""
    workspace = Path(params.get("workspace") or ctx.project_dir or project_dir_default()).expanduser()
    if not workspace.is_dir():
        raise EideError("E2000", f"Workspace không tồn tại: {workspace}")
    out = []
    for p in sorted(workspace.iterdir()):
        e = p / EIDE_DIR
        if not e.is_dir():
            continue
        c = yaml.safe_load((e / "constraints.yaml").read_text(encoding="utf-8")) if (e / "constraints.yaml").exists() else {}
        a = yaml.safe_load((e / "autonomy.yaml").read_text(encoding="utf-8")) if (e / "autonomy.yaml").exists() else {}
        f = json.loads((e / "FEATURES.json").read_text(encoding="utf-8")) if (e / "FEATURES.json").exists() else {"features": []}
        feats = f.get("features", [])
        out.append({"id": p.name, "path": str(p), "created": (c.get("project") or {}).get("created"),
                    "last_open": datetime.fromtimestamp(e.stat().st_mtime, UTC).isoformat(),
                    "board": (c.get("target") or {}).get("board"), "passing": sum(1 for x in feats if x.get("status") == "passing"),
                    "total": len(feats), "autonomy": a.get("autonomy")})
    out.sort(key=lambda x: x["last_open"], reverse=True)
    return {"projects": out}
