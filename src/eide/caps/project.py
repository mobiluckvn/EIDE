"""Namespace project.* — CDS-12.3 (tập Hiện thực), DDD-14 project/feature, UC-A01."""
from __future__ import annotations

import json
import re
import sqlite3
import time
import unicodedata
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.paths import project_dir_default, spec_dir
from eide_core.registry import capability
from eide_core.router import Context

EIDE_DIR = ".eide"
SUBDIRS = ["store", "session", "index", "docs", "diagrams"]


def slugify(text: str) -> str:
    """Slug ASCII từ tiếng Việt có dấu (CDS PROJECT-01 bước 1).

    `đ`/`Đ` phải đổi tay TRƯỚC khi chuẩn hóa: NFD tách dấu khỏi nguyên âm (ệ → e + dấu, rồi
    `ascii ignore` bỏ dấu), nhưng `đ` là một chữ cái riêng trong bảng chữ cái tiếng Việt chứ
    không phải `d` cộng dấu — NFD để nguyên, và `ascii ignore` xóa hẳn nó.

    Không phải chuyện thẩm mỹ: slug là ĐỊNH DANH dự án (đường dẫn thư mục, và là khóa dò trùng
    ở bước 2 → E2001). Thiếu bước này thì "máy đo nhiệt độ" và "máy o nhiệt o" ra cùng một
    slug, và dự án thứ hai bị từ chối "đã tồn tại" cho một dự án người dùng chưa hề tạo.
    """
    t = text.replace("đ", "d").replace("Đ", "D")
    t = unicodedata.normalize("NFD", t).encode("ascii", "ignore").decode()
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


@capability("project.open")
def open_project(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-02 — CDS-12.3; DDD-14 §5 user_version; API-15 E6003/E6000/E2000; UC-A06.

    Bước 1 kiểm `.eide/` và user_version (cũ → E6003, KHÔNG tự di trú — hợp đồng giao việc ấy cho
    Orchestrator gọi `eide migrate`); bước 2 kiểm niêm phong toàn vẹn (lệch → E6000); bước 4 đọc
    run còn dở; bước 5 trả summary và ghi ledger `session.open`.

    Bước 3 (tái dựng KG) và phần SessionMemory/summarize_session của bước 4 chờ WI-007 — xem
    DEVIATIONS DEV-008.
    """
    workspace = Path(ctx.project_dir or project_dir_default()).expanduser()
    root = _resolve_project(params["project"], workspace)
    db = store.store_path(root)

    if not db.exists():
        raise EideError("E6003", f"Dự án chưa có store — chạy `eide migrate` trong {root}",
                        found=0, expected=store.LATEST_VERSION, remedy="eide migrate")
    with sqlite3.connect(db) as c:
        v = store.current_version(c)
    if v != store.LATEST_VERSION:
        raise EideError("E6003", f"store user_version={v}, cần {store.LATEST_VERSION}",
                        found=v, expected=store.LATEST_VERSION, remedy="eide migrate")

    ok, chi_tiet = store.verify_seal(db)
    if not ok:
        raise EideError("E6000", f"Store bị ghi ngoài cổng ({chi_tiet.get('reason')}): {db}",
                        handling="rebuild", detail=chi_tiet.get("reason"))

    conn = store.open_store(db)
    try:
        feats = conn.execute("SELECT id, title, status FROM feature ORDER BY updated_at, id").fetchall()
        dau = next((f for f in feats if f[2] == "failing"), None)
        summary = {
            "project": root.name,
            "path": str(root),
            "user_version": v,
            "board": _board_of(root),
            "passports": conn.execute("SELECT count(*) FROM passport").fetchone()[0],
            "features": {"total": len(feats),
                         "passing": sum(1 for f in feats if f[2] == "passing"),
                         "failing": sum(1 for f in feats if f[2] == "failing")},
            "first_failing": {"id": dau[0], "title": dau[1]} if dau else None,
            # "mục chờ": lời gọi đang đợi người quyết (APD-08 ASK → capability_run.status pending)
            "pending": conn.execute("SELECT count(*) FROM capability_run WHERE status='pending'").fetchone()[0],
            # "undo còn hạn": UndoService là Sprint 2 (WI-004 ghi chú) — chưa có nguồn để đọc
            "undo_open": [],
        }
        stale = [r[0] for r in conn.execute("SELECT id FROM run WHERE state IN ('running','asked') ORDER BY id")]
    finally:
        conn.close()

    led = ctx.extra.get("ledger")     # Router đưa xuống; xem router.py
    session_id = uuid.uuid4().hex[:12]
    if led is not None:
        led.append("session.open", {"session_id": session_id, "project": root.name})
    ctx.extra["session_id"] = session_id
    return {"summary": summary, "migrated": False, "stale_runs": stale}


def _resolve_project(gia_tri: str, workspace: Path) -> Path:
    """"id hoặc đường dẫn" (input_schema). Không tìm thấy → E2000 kèm payload API-15 §3."""
    p = Path(gia_tri).expanduser()
    if (p / EIDE_DIR).is_dir():
        return p
    ung_vien = workspace / gia_tri
    if (ung_vien / EIDE_DIR).is_dir():
        return ung_vien
    co = sorted(x.name for x in workspace.iterdir() if (x / EIDE_DIR).is_dir()) if workspace.is_dir() else []
    raise EideError("E2000", f"Không tìm thấy dự án '{gia_tri}' trong {workspace}",
                    exists=co, candidates=[x for x in co if _similar(x, slugify(gia_tri))],
                    missing=[gia_tri])


def _board_of(root: Path) -> str | None:
    f = root / EIDE_DIR / "constraints.yaml"
    if not f.exists():
        return None
    c = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    return (c.get("target") or {}).get("board")


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
