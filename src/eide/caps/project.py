"""Namespace project.* — CDS-12.3 (tập Hiện thực), DDD-14 project/feature, UC-A01."""
from __future__ import annotations

import json
import re
import sqlite3
import time
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import store, whitelist
from eide_core.errors import EideError
from eide_core.memory import SessionMemory
from eide_core.paths import project_dir_default, spec_dir, user_config
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.undo import UndoService

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


def _ke_thua_niem(defaults: dict[str, Any], autonomy: dict[str, Any], sig: Path) -> None:
    """Chép niêm của bản cài sang dự án mới — POL-17 §3.

    Dự án mới có danh sách trắng GIỐNG HỆT bản mặc định đã ký, nên bắt người ký lại lần nữa là
    bắt ký một thứ họ vừa ký. Mà một cơ chế bắt ký những thứ hiển nhiên là cơ chế người ta gõ
    cho xong mà không đọc — hỏng đúng chỗ nó định giữ.

    Nên: chỉ kế thừa khi băm của dự án TRÙNG băm đã ký của bản cài, và ghi rõ trong `by` rằng
    đây là niêm kế thừa chứ không phải một lần ký mới. Lệch một mục là không kế thừa nữa, dự án
    ở trạng thái chưa ký, và `eide policy sign` là việc của người.

    Bản cài chưa ký ⇒ không ghi gì. Hỏng an toàn: PolicyGate sẽ bỏ danh sách và hỏi người.
    """
    goc = spec_dir() / "policy" / "defaults.sig"
    n = whitelist.doc_nien(goc)
    if n is None or n.hash != whitelist.bam(defaults) or whitelist.bam(autonomy) != n.hash:
        return
    sig.write_text(json.dumps({**n.as_dict(), "by": f"{n.by} (niêm kế thừa từ bản cài)"},
                              ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


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
    autonomy = {k: defaults[k] for k in ("autonomy", "thresholds", "trusted_sources", "trusted_packages",
                                         "allowed_licenses", "boards", "undo_window", "ask_timeout_s",
                                         "defaults", "escalation") if k in defaults}
    if params.get("autonomy"):
        autonomy["autonomy"] = params["autonomy"]
    (eide / "autonomy.yaml").write_text(yaml.safe_dump(autonomy, allow_unicode=True, sort_keys=False), encoding="utf-8")
    _ke_thua_niem(defaults, autonomy, eide / "policy.sig")
    constraints = {"project": {"id": slug, "name": name, "created": datetime.now(UTC).isoformat(), "text": params["text"]},
                   "target": {"chip": params.get("chip"), "board": params.get("board")}}
    (eide / "constraints.yaml").write_text(yaml.safe_dump(constraints, allow_unicode=True, sort_keys=False), encoding="utf-8")
    # models.yaml: chép bản mặc định để dự án đổi mô hình được mà không đụng vào spec (SDD-04 §6)
    (eide / "models.yaml").write_text((spec_dir() / "models.yaml").read_text(encoding="utf-8"), encoding="utf-8")
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

    Bước 4 mở SessionMemory thật (WI-007) và đóng phiên trước lại. Bước 3 "tái dựng KG" xong
    07/09/2026 cùng nhóm `kg.*` — DEV-008 đóng. Cả năm bước của hợp đồng nay có hiện thực.
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
            "autonomy": _autonomy_of(root),
            "passports": conn.execute("SELECT count(*) FROM passport").fetchone()[0],
            "features": {"total": len(feats),
                         "passing": sum(1 for f in feats if f[2] == "passing"),
                         "failing": sum(1 for f in feats if f[2] == "failing")},
            "first_failing": {"id": dau[0], "title": dau[1]} if dau else None,
            # "mục chờ": lời gọi đang đợi người quyết (APD-08 ASK → capability_run.status pending)
            "pending": conn.execute("SELECT count(*) FROM capability_run WHERE status='pending'").fetchone()[0],
            # "undo còn hạn" (output_schema) — POL-17 §5 qua UndoService
            "undo_open": UndoService(led_ctx, getattr(ctx.extra.get("gate"), "config", None)).list()
            if (led_ctx := ctx.extra.get("ledger")) else [],
            # Bước 3 "tái dựng KG từ cache (hash khớp) hoặc từ store" — nhóm kg.* có từ 07/09/2026.
            # Dựng ở đây chứ không để lần gọi kg.* đầu tiên tự dựng: mở dự án là lúc người dùng
            # chờ sẵn, còn một câu hỏi giữa chừng thì không.
            "kg": _dung_kg(root),
        }
        stale = [r[0] for r in conn.execute("SELECT id FROM run WHERE state IN ('running','asked') ORDER BY id")]
    finally:
        conn.close()

    # Bước 4: "Mở SessionMemory mới; memory.summarize_session của phiên trước" (MEM-11 §5).
    # Tóm tắt phiên TRƯỚC được lấy trước khi mở phiên mới — sau đó thì "gần nhất" đã là phiên
    # vừa mở và câu "lần trước đã…" sẽ nói về chính lúc này.
    led = ctx.extra.get("ledger")     # Router đưa xuống; xem router.py
    truoc = SessionMemory.gan_nhat(root)
    if truoc is not None:
        truoc.dong(summary=truoc.summary, ledger=led)
        summary["previous_session"] = {"session_id": truoc.session_id,
                                       "turns": len(truoc.turns), "summary": truoc.summary}
    phien = SessionMemory.mo(root, project=root.name, autonomy=summary.get("autonomy") or ctx.autonomy,
                             ledger=led)
    ctx.extra["session_id"] = phien.session_id
    summary["session_id"] = phien.session_id
    return {"summary": summary, "migrated": False, "stale_runs": stale}


@capability("project.status")
def status(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-08 — CDS-12.3; DDD-14 feature/capability_run; API-15 §5 model.call, gate.human; UC-A06.

    Một bước: "Tổng hợp từ FEATURES, queue, undo, ledger chi phí, session". `tc` là "số liệu khớp
    ledger", nên `gates_open` và `cost_today` đọc THẲNG từ ledger chứ không giữ bộ đếm riêng —
    bộ đếm riêng là thứ trôi khỏi nhật ký mà không ai biết.

    `undo_items` để rỗng cho tới khi có UndoService (Sprint 2) — xem DEVIATIONS DEV-008.
    """
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])

    feats: list[tuple[str, str, str]] = []
    db = store.store_path(root)
    if db.exists():
        with sqlite3.connect(db) as c:
            feats = c.execute("SELECT id, title, status FROM feature ORDER BY updated_at, id").fetchall()
    dau = next((f for f in feats if f[2] == "failing"), None)

    led = ctx.extra.get("ledger")
    recs = led.records() if led is not None else []
    hom_nay = datetime.now(UTC).date().isoformat()
    cost = sum(float((r["data"] or {}).get("cost_usd") or 0)
               for r in recs if r["kind"] == "model.call" and str(r["ts"]).startswith(hom_nay))
    cho: set[str] = set()
    for r in recs:
        d = r["data"] or {}
        if r["kind"] == "cap.run.finish" and d.get("status") == "pending" and d.get("run_id"):
            cho.add(d["run_id"])
        elif r["kind"] == "gate.human" and d.get("gate_id"):
            cho.discard(d["gate_id"])

    autonomy = None
    f = root / EIDE_DIR / "autonomy.yaml"
    if f.exists():
        autonomy = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("autonomy")
    c = root / EIDE_DIR / "constraints.yaml"
    target = (yaml.safe_load(c.read_text(encoding="utf-8")) or {}).get("target") if c.exists() else None

    return {"report": {
        "features": {"total": len(feats),
                     "passing": sum(1 for x in feats if x[2] == "passing"),
                     "failing": sum(1 for x in feats if x[2] == "failing"),
                     "first_failing": dau[0] if dau else None},
        "gates_open": len(cho),
        "undo_items": UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else [],
        "cost_today": round(cost, 6),
        "autonomy": autonomy,
        "target": target,
    }}


# API-15 §7: bộ lọc che chuỗi giống khóa API trước khi ghi ledger. PROJECT-09 bước 3 đòi cùng
# phép kiểm ấy trước khi ghi tùy chọn — cùng một regex, để hai chỗ không trôi khỏi nhau.
RE_BI_MAT = re.compile(r"sk-|AIza|Bearer ")


def _co_bi_mat(x: Any) -> bool:
    """Quét đệ quy: khóa nằm sau ba lớp object vẫn là khóa."""
    if isinstance(x, str):
        return bool(RE_BI_MAT.search(x))
    if isinstance(x, dict):
        return any(_co_bi_mat(v) for v in x.values())
    if isinstance(x, (list, tuple)):
        return any(_co_bi_mat(v) for v in x)
    return False


@capability("project.preferences")
def preferences(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-09 — CDS-12.3; DPS-09 D8; DDD-14 §2 preference + §6 preferences.yaml; undo restore_config.

    Hai phạm vi, hai nơi lưu, và đó không phải tùy tiện: `project` vào bảng `preference` của
    store dự án (DDD-14 §2, khóa chính (key, scope)); `user` vào `preferences.yaml` trong thư
    mục cấu hình người dùng (DDD-14 §6). Nếu để cả hai trong bảng thì tùy chọn phạm vi `user`
    ghi ở dự án A sẽ không thấy được ở dự án B — mà đúng nghĩa của "user" là ngược lại.

    Bước 1 "đọc dự án trước, người sau": tùy chọn dự án che tùy chọn người dùng cùng khóa.
    """
    op = params.get("op", "list")
    key = params.get("key")
    scope = params.get("scope")

    if op in ("get", "set", "delete") and not key:
        raise EideError("E1000", f"op={op} cần `key`")
    if op == "set":
        if params.get("value") is None:
            raise EideError("E1000", "op=set cần `value`")
        # Không in lại chuỗi bị bắt: thông báo lỗi đi vào ledger và ra màn hình.
        if _co_bi_mat(params["value"]):
            raise EideError("E1000", "Giá trị giống khóa API — tùy chọn không lưu dữ liệu nhạy cảm "
                                     "(PROJECT-09 bước 3; regex API-15 §7)", key=key)
        scope = scope or "project"

    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    co_du_an = bool(root and (root / EIDE_DIR).is_dir())

    if op == "set":
        # Bản ghi đúng hình dạng thực thể Preference của DDD-14 §2: `value` là một GIÁ TRỊ JSON
        # bất kỳ, còn `learned_from`/`ttl_days` là trường ngang hàng chứ không nằm trong nó.
        # Bản đầu nhận `value` phải là đối tượng rồi trộn learned_from vào trong — hệ quả là
        # ví dụ của chính hợp đồng (`"value":"stlink"`) bị Router chặn bằng E1000. Xem DEV-009.
        gia_tri: dict[str, Any] = {"value": params["value"],
                                   "learned_from": params.get("learned_from"),
                                   "at": datetime.now(UTC).isoformat()}
        if params.get("ttl_days") is not None:
            gia_tri["ttl_days"] = params["ttl_days"]
        if scope == "user":
            _pref_yaml_set(key, gia_tri)
        else:
            if not co_du_an:
                raise EideError("E2000", "Tùy chọn phạm vi `project` cần một dự án đang mở",
                                exists=[], candidates=[], missing=["project"])
            _pref_db_set(root, key, gia_tri)
        return {"prefs": {key: {**gia_tri, "scope": scope}}}

    if op == "delete":
        pham_vi = [scope] if scope else ["project", "user"]
        for s in pham_vi:
            if s == "user":
                _pref_yaml_del(key)
            elif co_du_an:
                _pref_db_del(root, key)
        return {"prefs": {}}

    # get / list — dự án trước, người sau
    gop: dict[str, Any] = {}
    for k, v in _pref_yaml_all().items():
        gop[k] = {**v, "scope": "user"}
    if co_du_an:
        for k, v in _pref_db_all(root).items():
            gop[k] = {**v, "scope": "project"}
    if op == "get":
        return {"prefs": {key: gop[key]} if key in gop else {}}
    return {"prefs": gop}


def _pref_file() -> Path:
    return user_config() / "preferences.yaml"


def _pref_yaml_all() -> dict[str, Any]:
    f = _pref_file()
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}


def _pref_yaml_set(key: str, gia_tri: dict[str, Any]) -> None:
    d = _pref_yaml_all()
    d[key] = gia_tri
    f = _pref_file()
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")


def _pref_yaml_del(key: str) -> None:
    d = _pref_yaml_all()
    if d.pop(key, None) is not None:
        _pref_file().write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")


def _pref_db_all(root: Path) -> dict[str, Any]:
    db = store.store_path(root)
    if not db.exists():
        return {}
    with sqlite3.connect(db) as c:
        rows = c.execute("SELECT key, value FROM preference WHERE scope='project'").fetchall()
    return {k: json.loads(v) for k, v in rows}


def _pref_db_set(root: Path, key: str, gia_tri: dict[str, Any]) -> None:
    db = store.store_path(root)
    if not db.exists():
        raise EideError("E6003", "Dự án chưa có store — chạy `eide migrate`",
                        found=0, expected=store.LATEST_VERSION, remedy="eide migrate")
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO preference (key, scope, value, learned_from, ttl_days, at)"
                  " VALUES (?,'project',?,?,?,?)"
                  " ON CONFLICT(key, scope) DO UPDATE SET value=excluded.value,"
                  " learned_from=excluded.learned_from, ttl_days=excluded.ttl_days, at=excluded.at",
                  (key, json.dumps(gia_tri, ensure_ascii=False), gia_tri.get("learned_from"),
                   gia_tri.get("ttl_days"), gia_tri["at"]))
    # Ghi qua cổng thì niêm lại, nếu không project.open sẽ báo E6000 cho chính lần ghi hợp lệ này.
    store.write_seal(db)


def _pref_db_del(root: Path, key: str) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    with sqlite3.connect(db) as c:
        c.execute("DELETE FROM preference WHERE key=? AND scope='project'", (key,))
    store.write_seal(db)


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


def _autonomy_of(root: Path) -> str | None:
    f = root / EIDE_DIR / "autonomy.yaml"
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("autonomy") if f.exists() else None


def _dung_kg(root: Path) -> dict[str, Any]:
    """Bước 3 của PROJECT-02. Lỗi ở đây KHÔNG được làm hỏng việc mở dự án.

    Đồ thị là khung nhìn dựng lại được, không phải dữ liệu: một store lạ làm nó dựng hỏng thì
    người dùng vẫn phải mở được dự án để đi sửa. Nên báo `ok: false` kèm lý do thay vì ném lên.
    """
    from eide.caps import kg as nkg

    try:
        g, tu_cache = nkg._do_thi(Context(project_dir=root))
        return {"ok": True, "nodes": len(g.nut), "edges": len(g.canh), "cached": tu_cache}
    except Exception as e:                                    # noqa: BLE001 — xem docstring
        return {"ok": False, "reason": f"{type(e).__name__}: {e}"[:160]}


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
