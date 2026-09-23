"""Namespace project.* — CDS-12.3 (tập Hiện thực), DDD-14 project/feature, UC-A01."""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import threading
import time
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import git, store, whitelist
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
    # roles.yaml: DDD-14 §yaml khai nó ở mốc M0 nhưng tới 12/09/2026 không chỗ nào sinh ra.
    # Nó là chỗ dự án ĐỔI ĐƯỢC ngân sách ngữ cảnh và trần skill của từng vai trò — hôm nay hai
    # thứ ấy chỉ đọc từ bản cài, nên một dự án muốn cho `librarian` nhiều chỗ hơn phải sửa
    # `docs/spec/`, tức sửa thứ dùng chung cho mọi dự án.
    (eide / "roles.yaml").write_text(_roles_mac_dinh(), encoding="utf-8")
    (eide / "FEATURES.json").write_text(json.dumps({"features": []}, ensure_ascii=False, indent=2), encoding="utf-8")
    (eide / "PROGRESS.md").write_text(f"# {name}\n\n- {time.strftime('%Y-%m-%d %H:%M')} — tạo dự án từ lệnh: \"{params['text']}\"\n", encoding="utf-8")
    (eide / ".gitignore").write_text("store/\nsession/\nindex/\n", encoding="utf-8")
    # KHỞI TẠO kho git ngay lúc tạo dự án — tiền đề của cả tầng phiên bản tệp (UXD-13 v2.0 §6.2,
    # quyết định Q1). Trước 17/09/2026 dự án chỉ có một `.gitignore` mà không có `.git`, nên
    # `code.revert` ném E7001 ("chưa phải kho git") và hoàn tác ba mức không có gì để đứng lên.
    # Một dự án không có lịch sử là một dự án mà "hoàn tác được trong 24 giờ" là lời hứa suông.
    from eide_core import git as _git
    _git.dam_bao_kho(root)
    # KHỞI TẠO store ngay lúc tạo dự án — cùng lý do với `.git` ở trên, và cùng một lỗ hổng.
    #
    # `SUBDIRS` tạo THƯ MỤC `.eide/store/` nhưng không có ai tạo `store.sqlite` trong đó, nên
    # tới 21/09/2026 mọi dự án mới đều mang một cái vỏ rỗng: `project.open` ném E6003 ngay lượt
    # mở đầu tiên, và giao diện chết từ đấy. Đo bằng một phiên thật trên bài CNC — tám lượt gõ,
    # không một câu trả lời nào.
    #
    # Triệu chứng thứ hai độc hơn vì nó IM: `Daemon._cho_gi` bọc `doc_bao_cao` trong
    # `except Exception: return []`, nên E6003 ở đây biến thành "chuỗi không chờ gì cả" — tác tử
    # dừng hỏi người, mà câu hỏi không bao giờ tới được người.
    #
    # Bảo người dùng chạy `eide migrate` tay là sai chỗ: store là một phần của dự án, không phải
    # một bước cài đặt. DDD-14 §5 nói `user_version` phải bằng bản mới nhất mới mở được — vậy
    # thì thứ tạo dự án phải để lại nó ở trạng thái mở được.
    store.migrate(store.store_path(root))
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
    # Bước 5 của MEM-11 §5: **báo cáo "lần trước đã… còn chờ… tôi đề nghị…"**. [DEV-196]
    summary["tiep_tuc"] = _bao_cao_tiep_tuc(root, truoc, stale)
    return {"summary": summary, "migrated": False, "stale_runs": stale}


def _bao_cao_tiep_tuc(root: Path, truoc: SessionMemory | None,
                      stale: list[str]) -> dict[str, Any]:
    """`{dong[], run_id?, de_nghi?}` — mở dự án ra là biết ngay việc đang dở.

    ## Thủ tục này đã viết trong tài liệu từ lâu và chưa bao giờ chạy

    MEM-11 §5 quy định trọn năm bước, kể cả câu đích: *"lần trước đã… còn chờ… tôi đề nghị…"*
    ≤ 10 dòng, mục tiêu **tiếp tục ≤ 15 phút và ≤ 1 câu hỏi**. Bước 4 (`summarize_session`) có
    hiện thực và được gọi đúng chỗ; bước 5 thì không, nên người dùng mở dự án ra và nhận đúng
    một câu "Đã mở X — n tính năng".
    """
    dong: list[str] = []
    luot = None
    if truoc is not None and truoc.turns:
        n = len([t for t in truoc.turns if t.get("by") != "summary"])
        cuoi = next((t for t in reversed(truoc.turns) if t.get("by") == "human"), None)
        dong.append(f"Lần trước: {n} lượt trao đổi"
                    + (f'; câu cuối anh gõ: "{str(cuoi["text"])[:100]}"' if cuoi else ""))

    from eide.caps.memory import luot_gan_nhat_chua_xong
    luot = luot_gan_nhat_chua_xong(root)
    if luot:
        if luot["state"] == "asked":
            thieu = ", ".join(x for w in (luot["waiting"] or []) for x in (w.get("thieu") or []))
            dong.append(f'Còn chờ anh: lượt {luot["run_id"][:10]} dừng để hỏi'
                        + (f" — cần {thieu}" if thieu else ""))
        else:
            hong = ", ".join(f'`{x.get("cap", "?")}`' for x in (luot["failed"] or [])[:2])
            dong.append(f'Việc dở: lượt {luot["run_id"][:10]} ({luot["state"]})'
                        + (f" — hỏng ở {hong}" if hong else ""))
        if luot["text"]:
            dong.append(f'Việc gốc: "{luot["text"][:120]}"')
        # ĐỀ NGHỊ phải là một câu người GÕ ĐƯỢC, không phải một lời khuyên chung. Người đọc
        # "anh nên tiếp tục việc dở" vẫn phải tự nghĩ ra cách nói; "gõ: tiếp tục" thì không.
        dong.append("Tôi đề nghị: gõ **"
                    + ("tiếp tục" if luot["state"] == "asked" else "làm lại")
                    + "** — tôi biết chính xác lượt nào.")
    elif stale:
        dong.append(f"{len(stale)} lượt chạy còn dở từ phiên trước.")

    return {"dong": dong[:10], "run_id": (luot or {}).get("run_id"),
            "de_nghi": ("tiếp tục" if (luot or {}).get("state") == "asked"
                        else "làm lại" if luot else None)}


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
        # `archived` là cờ mà tc của PROJECT-05 đòi ("project.list gắn cờ archived"). Nó đọc từ
        # `constraints.yaml` chứ không từ sự tồn tại của tệp zip: một dự án có thể được đóng gói
        # nhiều lần, và gói cũ nằm lại trong `archive/` không nói gì về trạng thái hiện tại.
        out.append({"id": p.name, "path": str(p), "created": (c.get("project") or {}).get("created"),
                    "last_open": datetime.fromtimestamp(e.stat().st_mtime, UTC).isoformat(),
                    "board": (c.get("target") or {}).get("board"), "passing": sum(1 for x in feats if x.get("status") == "passing"),
                    "total": len(feats), "autonomy": a.get("autonomy"),
                    "archived": bool((c.get("project") or {}).get("archived"))})
    out.sort(key=lambda x: x["last_open"], reverse=True)
    return {"projects": out}


def _root(ctx: Context) -> Path:
    """Thư mục dự án đang mở. Cùng phép kiểm với các năng lực khác trong tệp — tách ra vì
    `set_target` cần nó ở hai chỗ."""
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Cần một dự án đang mở", exists=[], candidates=[],
                        missing=["project"])
    return root


# ---------------------------------------------------------------- PROJECT-06 set_target


# Bước 1: "Suy ISA từ chip qua hộ chiếu/seed (bảng họ chip → ISA)". Bảng ấy KHÔNG viết ở đây:
# nó đã nằm trong `family_patterns` của từng `docs/spec/isa/*.yaml`. Chép lại sang Python là
# tạo bản thứ hai của cùng một sự thật, và hai bản sẽ trôi khỏi nhau ngay lần thêm ISA sau —
# đúng loại lỗi mà DEV-043/DEV-046 đã ghi.
def _isa_tu_chip(chip: str) -> str | None:
    """Khớp tên chip với `family_patterns` trong các manifest ISA.

    Thử CẢ HAI dạng tên mà bộ hồ sơ dùng cho cùng một con chip. `family_patterns` neo đầu chuỗi
    (`^STM32F[2-4]`) nên nó khớp `STM32F411CE` — dạng ví dụ của PROJECT-06 — nhưng không khớp
    `st.stm32f411ce`, vốn là dạng IRI mà `extract.svd` sinh ra cho mọi hộ chiếu chip và cũng là
    dạng ví dụ của SIM-01. Trước khi thử cả hai, ghim một chip bằng dạng IRI cho ra `isa: null`
    trong `constraints.yaml` mà không báo gì, rồi `code.build` sau đó dừng ở "chưa ghim ISA" —
    một câu đúng về triệu chứng và sai về nguyên nhân.
    """
    import re as _re
    ten = chip[len("chip:"):] if chip.startswith("chip:") else chip
    for ung_vien in (ten, ten.rsplit(".", 1)[-1]):
        for f in sorted((spec_dir() / "isa").glob("*.yaml")):
            d = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
            for pat in (d.get("family_patterns") or []):
                if _re.search(pat, ung_vien, _re.I):
                    return d.get("id") or f.stem
    return None


@capability("project.set_target")
def set_target(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-06 — CDS-12.3. tc: "Ghim st.stm32f411ce@x; constraints.yaml cập nhật;
    chip lạ → missing"; undo `restore_config`.

    GHIM phiên bản hộ chiếu, không chỉ ghi tên chip. Khác biệt ấy là toàn bộ giá trị của năng
    lực này: `chip: stm32f411` nói dự án dùng chip gì, còn `chip: st.stm32f411ce@1.2.0` nói nó
    dùng **bản mô tả nào** của chip ấy. Khi hộ chiếu lên phiên bản mới và một offset đổi,
    `passport.diff` chỉ so được nếu biết dự án đang ở bản nào — không ghim thì mọi dự án lặng lẽ
    trôi theo bản mới nhất, và mã sinh tháng trước không tái lập được.

    Chip không có hộ chiếu thì vào `missing` chứ KHÔNG ném lỗi: hợp đồng khai `missing` như một
    trường bình thường, và dự án vẫn lập kế hoạch được trong lúc chờ tài liệu về. E2000 chỉ dành
    cho trường hợp không suy ra nổi chip nào.
    """
    root = _root(ctx)
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    target = dict(cu.get("target") or {})

    chip = params.get("chip") or target.get("chip")
    board = params.get("board") or target.get("board")
    if not chip and not board:
        raise EideError("E2000", "Không suy ra được chip: nêu `chip` hoặc cắm board rồi chạy "
                        "`eide discover`", exists=[], candidates=[], missing=["chip"])

    isa = params.get("isa") or (_isa_tu_chip(chip) if chip else None)
    pins: dict[str, Any] = {"isa": isa}
    missing: list[str] = []

    if chip:
        ghim, co = _ghim(root, chip, params.get("pin_version"))
        pins["chip"] = ghim
        if not co:
            missing.append(f"hộ chiếu cho {chip}")
    if board:
        ghim, co = _ghim(root, board, None, kind="board")
        pins["board"] = ghim
        if not co:
            missing.append(f"hộ chiếu board cho {board}")
    if chip and not isa:
        missing.append(f"ISA cho {chip} (không khớp family_patterns nào trong docs/spec/isa/)")

    cu["target"] = {**target, "chip": chip, "board": board, "isa": isa, "pins": pins}
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(cu, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"pins": pins, "missing": missing}


def _ghim(root: Path, ten: str, ban: str | None, kind: str = "chip") -> tuple[str, bool]:
    """Trả (chuỗi ghim `id@ver`, đã có hộ chiếu trong store chưa).

    Ghim cả khi CHƯA có hộ chiếu — dùng bản người gọi nêu, hoặc `@?` khi chưa biết. Để trống
    thì sau này không phân biệt được "chưa ghim bao giờ" với "đã ghim rồi mất"; `@?` nói rõ là
    đã chọn chip nhưng còn chờ tài liệu.
    """
    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            rows = [r[0] for r in c.execute(
                "SELECT id FROM passport WHERE kind=? AND (id = ? OR id LIKE ?) ORDER BY id",
                (kind, ten, f"%{ten}%@%")).fetchall()]
        if rows:
            khop = [r for r in rows if ban and r.endswith("@" + ban)] or rows
            return khop[-1], True          # bản mới nhất theo thứ tự id
    return f"{ten}@{ban}" if ban else f"{ten}@?", False


# ---------------------------------------------------------------- PROJECT-04 clone


# `keep` của hợp đồng: bốn nhóm, mặc định chỉ tri thức.
NHOM_GIU = ("knowledge", "code", "docs", "features")
# Bảng tri thức đi theo bản sao. `fact` có khoá ngoại tới `source`, và một fact không có nguồn
# là một fact không kiểm được — nên `source` đi cùng dù hợp đồng chỉ nêu "fact, passport".
BANG_TRI_THUC = ("source", "fact", "passport", "passport_fact")
# Thư mục không bao giờ đóng gói: dựng lại được từ store, và là phần lớn nhất.
KHONG_DONG_GOI = ("index", "cache")


@capability("project.clone")
def clone(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-04 — CDS-12.3; DDD-14; API-15 §7. tc: "Bản sao có cùng số fact, ledger
    rỗng"; lỗi E2001, E2000; undo `delete_created_files`.

    Phần dễ sai nhất không phải chép cái gì, mà **không chép cái gì**: ledger, session, index,
    `decision_log`, `run`. Cách viết tự nhiên nhất — chép cả thư mục `.eide/` — làm đúng điều
    ngược lại. Một bản sao mang theo `decision_log` của bản gốc khiến `policy.learn_thresholds`
    học từ những quyết định chưa từng xảy ra trong dự án này, và mỗi dòng ấy trỏ về `run_id`
    không tồn tại ở đây.

    Nên store mới được **dựng lại từ migration** rồi chép sang đúng bốn bảng tri thức, chứ không
    sao chép tệp `store.sqlite`. Chép tệp thì mọi bảng đi theo, kể cả bảng thêm vào sau này mà
    không ai nhớ phải loại trừ.

    `keep` mặc định `["knowledge"]`: mã và tài liệu không đi theo trừ khi nêu. Sao chép cả mã
    theo mặc định thì "clone để thử một hướng khác" biến thành "nhân đôi một dự án đang dở".
    """
    src = Path(params["src"]).expanduser()
    if not (src / EIDE_DIR).is_dir():
        raise EideError("E2000", f"Không có dự án ở {src}", exists=[], candidates=[],
                        missing=[str(src)])
    giu = set(params.get("keep") or ["knowledge"])
    workspace = src.parent
    ten = slugify(params["new_name"])
    dich = workspace / ten
    if (dich / EIDE_DIR).is_dir() or dich.exists():
        raise EideError("E2001", f"Dự án '{ten}' đã tồn tại", options=["reuse", "clone", "new"],
                        path=str(dich))

    goc_cfg = yaml.safe_load((src / EIDE_DIR / "constraints.yaml").read_text(encoding="utf-8")) or {}
    tao = create({"text": f"bản sao của {src.name}", "name": params["new_name"],
                  "dir": str(workspace)}, ctx)
    eide = dich / EIDE_DIR

    # constraints: giữ `target` (chip/board đã ghim là tri thức của dự án), thay phần định danh
    cfg = dict(goc_cfg)
    cfg["project"] = {**(goc_cfg.get("project") or {}), "id": ten, "name": params["new_name"],
                      "created": datetime.now(UTC).isoformat(), "cloned_from": src.name}
    (eide / "constraints.yaml").write_text(
        yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")

    n_fact = 0
    if "knowledge" in giu:
        n_fact = _chep_tri_thuc(src, dich, ctx)
    if "features" in giu and (f := src / EIDE_DIR / "FEATURES.json").exists():
        (eide / "FEATURES.json").write_text(f.read_text(encoding="utf-8"), encoding="utf-8")
    if "code" in giu:
        _chep_ma(src, dich)
    if "docs" in giu:
        for d in ("docs", "diagrams"):
            _chep_cay(src / EIDE_DIR / d, eide / d)

    if (led := ctx.extra.get("ledger")) is not None:
        # API-15 §7 v1.7 có kiểu `project.state` cho cả họ clone/archive/rollback (DEV-081, chủ
        # sản phẩm duyệt 10/09/2026). Trước đó phải mượn `report`.
        led.append("project.state", {"op": "clone", "project": str(dich), "ref": str(src),
                                     "detail": {"keep": sorted(giu), "n_facts": n_fact}})
        led.append("undo.register", {"undo_ref": f"clone:{ten}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"project_id": tao["project_id"], "path": str(dich)}


def _chep_tri_thuc(src: Path, dich: Path, ctx: Context) -> int:
    """Store mới dựng từ migration, rồi chép sang đúng bốn bảng tri thức."""
    cu, moi = store.store_path(src), store.store_path(dich)
    if not cu.exists():
        return 0
    store.migrate(moi, ledger=ctx.extra.get("ledger"))
    n = 0
    with store.open_store(moi) as c:
        c.execute("ATTACH DATABASE ? AS goc", (str(cu),))
        for bang in BANG_TRI_THUC:
            cot = [r[1] for r in c.execute(f"PRAGMA table_info({bang})").fetchall()]  # noqa: S608
            if not cot:
                continue
            ds = ", ".join(cot)
            c.execute(f"INSERT INTO {bang} ({ds}) SELECT {ds} FROM goc.{bang}")  # noqa: S608
        n = c.execute("SELECT COUNT(*) FROM fact").fetchone()[0]
        c.commit()
        c.execute("DETACH DATABASE goc")
    store.write_seal(moi, ctx.extra.get("ledger"))
    return n


def _chep_ma(src: Path, dich: Path) -> None:
    """Mọi thứ ngoài `.eide/` và `.git/`. Bản sao là một dự án MỚI: mang theo lịch sử git của
    bản gốc thì hai dự án có chung commit và `code.revert` ở bên này quay lui cả bên kia."""
    for p in src.iterdir():
        if p.name in (EIDE_DIR, ".git"):
            continue
        _chep_cay(p, dich / p.name) if p.is_dir() else _chep_tep(p, dich / p.name)


def _chep_cay(src: Path, dich: Path) -> None:
    if not src.is_dir():
        return
    for p in src.rglob("*"):
        if p.is_file():
            _chep_tep(p, dich / p.relative_to(src))


def _chep_tep(src: Path, dich: Path) -> None:
    dich.parent.mkdir(parents=True, exist_ok=True)
    dich.write_bytes(src.read_bytes())


# ---------------------------------------------------------------- PROJECT-05 archive


@capability("project.archive")
def archive(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-05 — CDS-12.3. tc: "Zip mở lại được; project.list gắn cờ archived"; lỗi
    E2000; undo `restore_config`; ask "Xóa thật sự (R4)".

    `ask_when` nói rõ việc XÓA là hành động khác, ở lớp rủi ro khác — nên đóng gói **không đụng
    gì tới bản gốc**. Nó chỉ tạo một tệp zip và bật một cờ.

    `index/` và `cache/` không vào gói: chúng dựng lại được từ store và là phần lớn nhất — một
    kho lưu trữ 800 MB vì mang theo cache là một kho không ai lưu.
    """
    root = Path(params["project"]).expanduser()
    if not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", f"Không có dự án ở {root}", exists=[], candidates=[],
                        missing=[str(root)])

    import zipfile
    thu_muc = root.parent / "archive"
    thu_muc.mkdir(parents=True, exist_ok=True)
    dich = thu_muc / f"{root.name}-{datetime.now(UTC).date().isoformat()}.zip"
    with zipfile.ZipFile(dich, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(root.rglob("*")):
            if not p.is_file():
                continue
            rel = p.relative_to(root)
            if rel.parts[0] == ".git" or (rel.parts[:1] == (EIDE_DIR,)
                                          and len(rel.parts) > 1 and rel.parts[1] in KHONG_DONG_GOI):
                continue
            z.write(p, str(rel))

    cfg_p = root / EIDE_DIR / "constraints.yaml"
    cfg = yaml.safe_load(cfg_p.read_text(encoding="utf-8")) if cfg_p.exists() else {}
    cfg.setdefault("project", {})["archived"] = datetime.now(UTC).isoformat()
    cfg_p.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("project.state", {"op": "archive", "project": str(root), "ref": str(dich),
                                     "detail": {"archived_at": cfg["project"]["archived"]}})
        led.append("undo.register", {"undo_ref": f"archive:{root.name}",
                                     "kind": "restore_config", "deadline": ""})
    return {"archived_path": str(dich)}


# ---------------------------------------------------------------- PROJECT-07 rollback


@capability("project.rollback")
def rollback(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-07 — CDS-12.3; CON-28 §4 (tag `known-good/<date>`); API-15 §3 E7001.
    tc: "Sau sửa hỏng → rollback → build đạt"; undo `restore_config`.

    Không nêu `tag` thì lấy **known-good gần nhất** — đó là mặc định trong `input_schema`, và nó
    là lý do năng lực này dùng được trong lúc hoảng. Kho chưa có known-good nào thì nói thẳng
    (E2000) chứ không quay về commit đầu tiên: "trạng thái tốt gần nhất" mà chưa ai từng đánh
    dấu là tốt thì không tồn tại.

    Working tree bẩn → **E7001 trước khi đụng gì**. Quay lui khi còn thay đổi chưa commit là
    cách nhanh nhất để mất chúng, mà người gọi rollback đang hoảng chứ không đang cẩn thận.

    `FEATURES.json` khôi phục từ chính tag ấy: để lại bản `passing` của lần hỏng thì bảng tiến
    độ nói dự án đang chạy tốt trong khi mã vừa bị quay lui — và đó là bảng người ta nhìn để
    quyết định làm gì tiếp.

    "Build kiểm" của bước 1 chạy khi có toolchain; thiếu nó thì `state["build"]` ghi rõ là đã bỏ
    qua chứ không im lặng — một rollback báo thành công mà chưa dựng lần nào là một lời hứa suông.
    """
    root = _root(ctx)
    if not git.la_kho(root):
        raise EideError("E2000", f"{root.name} không phải kho git — không có gì để quay lui",
                        exists=[], candidates=[], missing=["git repo"])
    # Vẫn chặn tệp chưa commit — kể cả tệp MỚI, vì `checkout -B` mang nó sang nhánh vừa quay
    # lui và trộn mã dở dang vào một bản "đã về trạng thái tốt". Nhưng `.eide/` thì bỏ qua: nó
    # là trạng thái của chính EIDE, luôn chưa theo dõi trong mọi dự án, nên không lọc nó ra
    # khiến năng lực này từ chối chạy trên MỌI dự án thật. [DEV-144]
    ban = git.thay_doi_can_chan(root, bo_qua=(f"{EIDE_DIR}/", EIDE_DIR))
    if ban:
        raise EideError("E7001", "Working tree còn thay đổi chưa commit ("
                        + ", ".join(ban[:5]) + ("…" if len(ban) > 5 else "")
                        + "): quay lui bây giờ sẽ mất chúng, hoặc mang chúng sang bản đã quay "
                        "lui. Commit hoặc `git stash` trước", root=str(root), paths=ban[:20])

    tag = params.get("tag") or _known_good_gan_nhat(root)
    if not tag:
        raise EideError("E2000", "Chưa có tag `known-good/*` nào trong kho — chưa lần merge nào "
                        "đánh dấu một trạng thái tốt", exists=[], candidates=["code.merge"],
                        missing=["known-good tag"])
    if git.chay(root, "rev-parse", "--verify", "--quiet", tag, kiem=False).returncode != 0:
        raise EideError("E2000", f"Không có tag `{tag}`", missing=[tag], candidates=[],
                        exists=_cac_tag(root))

    git.chay(root, "checkout", "-B", "auto/rollback", tag)
    commit = git.chay(root, "rev-parse", "HEAD").stdout.strip()

    # `FEATURES.json` về theo cả cây — `checkout -B <tag>` đã làm việc đó, một lệnh `checkout
    # <tag> -- FEATURES.json` sau đó không thêm gì. Nhưng nó chỉ về NẾU git theo dõi tệp ấy, và
    # `.eide/.gitignore` mặc định chỉ loại `store/ session/ index/`. Ai đó thêm cả `.eide/` vào
    # `.gitignore` là đủ để bảng tiến độ của lần hỏng nằm lại sau khi mã đã quay lui — im lặng.
    # Nên trạng thái nói rõ, thay vì hứa một điều không xảy ra.
    theo_doi = git.chay(root, "ls-files", "--error-unmatch", f"{EIDE_DIR}/FEATURES.json",
                        kiem=False).returncode == 0
    f = root / EIDE_DIR / "FEATURES.json"
    feats = (json.loads(f.read_text(encoding="utf-8")).get("features") or []) if f.exists() else []
    state = {"commit": commit, "tag": tag, "features": len(feats),
             "features_restored": theo_doi, "build": _thu_dung(ctx)}

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("project.state", {"op": "rollback", "project": str(root), "ref": tag,
                                     "detail": {"commit": commit,
                                                "features_restored": theo_doi}})
        led.append("undo.register", {"undo_ref": f"rollback:{commit[:12]}",
                                     "kind": "restore_config", "deadline": ""})
    return {"state": state}


def _cac_tag(root: Path) -> list[str]:
    r = git.chay(root, "tag", "--list", "known-good/*", kiem=False)
    return [x for x in r.stdout.split() if x]


def _known_good_gan_nhat(root: Path) -> str | None:
    """Sắp theo thời điểm TẠO tag, không theo tên: `known-good/2026-09-10.2` và
    `known-good/2026-09-10` sắp theo chuỗi cho ra thứ tự sai ngay khi một ngày merge hai lần."""
    r = git.chay(root, "tag", "--list", "known-good/*", "--sort=-creatordate", kiem=False)
    ds = [x for x in r.stdout.splitlines() if x.strip()]
    return ds[0].strip() if ds else None


def _thu_dung(ctx: Context) -> str:
    """Dựng thử sau khi quay lui. Thiếu toolchain không phải lỗi của rollback — nói rõ và đi tiếp."""
    from eide.caps.code import build as code_build
    try:
        kq = code_build({}, ctx)
    except EideError as e:
        return f"bỏ qua ({e.code})"
    except Exception as e:                                  # noqa: BLE001
        return f"bỏ qua ({type(e).__name__})"
    return "ok" if kq.get("ok") else "lỗi"

# Trần skill mỗi vai trò — KAD-07 §5 ("≤ 5 skill mỗi lượt"). Vai trò nào không nêu thì lấy 5.
SKILLS_MAX = {"coder": 5, "architect": 3, "librarian": 3, "debugger": 5, "writer": 2,
              "reviewer": 3, "planner": 3, "cartographer": 2, "intent": 1}


def _roles_mac_dinh() -> str:
    """`roles.yaml` cho một dự án mới — DDD-14 §yaml: `{skills_max, tools[], budget, prompt}`.

    **Ghép từ ba nguồn trong spec, không gõ tay:** ngân sách từ `context/budgets.json`, tên tệp
    prompt từ `prompts/*.md`, danh sách vai trò từ `models.yaml`. Gõ tay ở đây nghĩa là một bản
    chép thứ hai của ba bảng ấy, và nó sẽ trôi khỏi bản gốc ngay lần đầu ai đó sửa một con số —
    đúng loại lỗi DEV-043 và DEV-046 đã ghi.

    `tools` để RỖNG có chủ ý. DDD-14 khai trường ấy, nhưng hôm nay quyền gọi năng lực do
    PolicyGate quyết theo lớp rủi ro và mức tự chủ, không theo vai trò — thêm một danh sách thứ
    hai ở đây sẽ tạo ra hai nguồn sự thật cho cùng một câu hỏi. Trường có mặt để dự án ghi đè
    khi cần; rỗng nghĩa là "theo chính sách", không nghĩa là "không được gọi gì".
    """
    from eide_core.composer import cau_hinh
    mo = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8")) or {}
    ns = (cau_hinh() or {}).get("budget") or {}
    ra: dict[str, Any] = {}
    for ten in (mo.get("roles") or {}):
        b = ns.get(ten) or {}
        ra[ten] = {
            "skills_max": SKILLS_MAX.get(ten, 5),
            "tools": [],
            "budget": {"input": b.get("total"),
                       "output": (mo["roles"][ten] or {}).get("max_output")},
            "prompt": f"prompts/{ten}.md" if (spec_dir() / "prompts" / f"{ten}.md").exists()
                      else None,
        }
    return yaml.safe_dump({"roles": ra}, allow_unicode=True, sort_keys=False)


# ==================== v2.0 — theo dõi tệp đổi NGOÀI EIDE ====================

#: Bộ theo dõi đang chạy, theo thư mục dự án. Tiến trình daemon sống lâu hơn một lời gọi, nên
#: trạng thái này phải nằm ngoài hàm; khoá là đường dẫn đã `resolve()` để hai cách viết cùng
#: một thư mục không tạo hai bộ theo dõi.
_DANG_THEO: dict[str, Any] = {}


@capability("project.watch")
def watch(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PROJECT-10 — CDS-12.3; UXD-13 v2.0 §6.1 và §7.4. Lỗi E2000.

    Nửa còn thiếu của chữ "đồng bộ". Sổ cái thấy mọi việc EIDE làm, nhưng một tệp đổi vì người
    dùng gõ trong Vim, vì `git checkout`, hay vì một trình sinh mã khác thì nó không thấy gì —
    và lượt sau tác tử sinh mã trên bản cũ, ghi đè bản mới trong im lặng.

    **Bỏ qua thay đổi do chính EIDE vừa ghi**, đối chiếu bằng BĂM NỘI DUNG chứ không bằng thời
    gian: `code.merge` ghi xong thì thời gian sửa tệp đổi, và một bộ lọc theo thời gian sẽ báo
    "người vừa sửa tệp" ngay sau mỗi lần tác tử làm việc — tức là nói dối đúng vào thứ năng lực
    này sinh ra để nói thật.
    """
    # Chỉ đọc `ctx.project_dir`: `project` KHÔNG có trong input_schema, nên Router chặn nó
    # bằng E1000 trước khi tới đây — đọc một khoá như thế là viết mã cho một đường không
    # bao giờ đi tới, và người đọc sau tưởng năng lực nhận được tham số ấy.
    root = Path(ctx.project_dir or "").expanduser()
    if not root.name or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "`project.watch` cần một dự án đang mở", missing=["project"])
    khoa = str(root.resolve())
    bat = bool(params.get("enable", True))

    cu = _DANG_THEO.pop(khoa, None)
    if cu is not None:
        cu["dung"] = True
    if not bat:
        return {"watching": False, "path": khoa}

    trang_thai: dict[str, Any] = {"dung": False, "bam": _bam_cay(root)}
    _DANG_THEO[khoa] = trang_thai
    led = ctx.extra.get("ledger")

    def vong() -> None:
        import time as _t
        while not trang_thai["dung"]:
            _t.sleep(CHU_KY_THEO_DOI)
            if trang_thai["dung"]:
                return
            try:
                moi = _bam_cay(root)
            except OSError:
                continue
            for duong, bam in moi.items():
                if trang_thai["bam"].get(duong) != bam and led is not None:
                    led.append("human.file_external",
                               {"path": duong, "diff_summary": "nội dung đổi",
                                "source": "watcher"}, actor="human")
            trang_thai["bam"] = moi

    th = threading.Thread(target=vong, name=f"eide-watch-{root.name}", daemon=True)
    th.start()
    trang_thai["luong"] = th
    return {"watching": True, "path": khoa}


#: Chu kỳ quét, giây. Đủ nhanh để tác tử không kịp sinh mã trên bản cũ trong một lượt, đủ chậm
#: để không hâm nóng đĩa của một dự án vài nghìn tệp.
CHU_KY_THEO_DOI = 1.5

#: Thư mục KHÔNG theo dõi. `.eide/` là nơi chính EIDE ghi sổ cái và store — theo dõi nó thì mỗi
#: sự kiện sinh ra một sự kiện nữa, và vòng lặp ấy không có đáy.
BO_QUA_THEO_DOI = {EIDE_DIR, ".git", "build", "node_modules", ".venv", "__pycache__"}


def _bam_cay(root: Path) -> dict[str, str]:
    """Đường dẫn tương đối → băm nội dung, cho mọi tệp văn bản trong dự án."""
    ra: dict[str, str] = {}
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(root)
        if set(rel.parts) & BO_QUA_THEO_DOI:
            continue
        try:
            ra[str(rel)] = hashlib.sha256(p.read_bytes()).hexdigest()[:16]
        except OSError:
            continue
    return ra
