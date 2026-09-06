"""Namespace memory.* — CDS-12.6 (tập Hội thoại & bộ nhớ); MEM-11 §5; CXD-10."""
from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.memory import SessionMemory
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.undo import UndoService

EIDE_DIR = ".eide"


def _goc(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])
    return root


def _features(root: Path) -> list[dict[str, Any]]:
    """FEATURES.json sinh từ bảng `feature` của M3 — MEM-11 §5 "cả hai được sinh từ M3, không viết tay"."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with sqlite3.connect(db) as c:
        rows = c.execute("SELECT id, title, status, evidence, verified, run_id"
                         " FROM feature ORDER BY updated_at, id").fetchall()
    return [{"id": r[0], "title": r[1], "status": r[2],
             "evidence": json.loads(r[3]) if r[3] else [],
             "verified": r[4], "run": r[5], "blocked_by": None} for r in rows]


def _autonomy(root: Path) -> str | None:
    f = root / EIDE_DIR / "autonomy.yaml"
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("autonomy") if f.exists() else None


def _board(root: Path) -> str | None:
    f = root / EIDE_DIR / "constraints.yaml"
    if not f.exists():
        return None
    return ((yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("target") or {}).get("board")


def _tu_ledger(led) -> tuple[list[dict], list[dict]]:
    """(việc đã xong, cổng còn mở) — cả hai từ M3, không từ bộ đếm riêng."""
    recs = led.records() if led is not None else []
    xong, cho = [], {}
    ten = {}
    for r in recs:
        d = r.get("data") or {}
        if r["kind"] == "cap.run.start" and d.get("run_id"):
            ten[d["run_id"]] = d.get("cap", "?")
        elif r["kind"] == "cap.run.finish" and d.get("run_id"):
            if d.get("status") == "done":
                xong.append({"run_id": d["run_id"], "cap": ten.get(d["run_id"], "?"), "at": r["ts"]})
            elif d.get("status") == "pending":
                cho[d["run_id"]] = {"run_id": d["run_id"], "cap": ten.get(d["run_id"], "?"), "at": r["ts"]}
        elif r["kind"] == "gate.human" and d.get("gate_id"):
            cho.pop(d["gate_id"], None)
    return xong, list(cho.values())


@capability("memory.progress")
def progress(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-04 — CDS-12.6; MEM-11 §5 (PROGRESS.md, FEATURES.json sinh từ M3); FR-GOV-03.

    `tc` là "nội dung khớp ledger; KHÔNG VIẾT TAY", nên mọi con số ở đây đến từ ledger (M3) và
    bảng `feature` — không có bộ đếm riêng nào. Đây cũng là lý do hai tệp này được ghi đè mỗi
    lần gọi: chúng là ẢNH CHỤP của M3, không phải tài liệu người sửa. Chỗ duy nhất người nói
    được vào là `entry`.
    """
    root = _goc(ctx)
    led = ctx.extra.get("ledger")
    xong, cho = _tu_ledger(led)
    feats = _features(root)
    dat = sum(1 for f in feats if f["status"] == "passing")
    hong = next((f for f in feats if f["status"] == "failing"), None)
    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []

    board = _board(root)
    dong = [f"## Trạng thái {datetime.now(UTC).strftime('%d/%m %H:%M')} · dự án {root.name}"
            f" · {_autonomy(root) or '?'}" + (f" · board {board}" if board else "")]
    dong.append(f"- Đã làm: {len(xong)} việc tự động, {len(cho)} chờ anh"
                + (f" ({', '.join(c['cap'] for c in cho[:3])})" if cho else ""))
    if feats:
        d = f"- Feature: {dat}/{len(feats)} passing"
        if hong:
            d += f"; đang làm {hong['id']} {hong['title']}"
            if hong.get("run"):
                d += f" (run {hong['run']})"
        dong.append(d)
    else:
        dong.append("- Feature: chưa có")
    if undo:
        u = undo[0]
        dong.append(f"- Hoàn tác được đến {(u['deadline'] or 'hết phiên')[:16]}: "
                    + ", ".join(f"{x['cap']} ({x['kind']})" for x in undo[:3]))
    if params.get("entry"):
        dong.append(f"- Ghi chú: {params['entry']}")

    md = "\n".join(dong) + "\n"
    features = {"features": feats}
    (root / EIDE_DIR / "PROGRESS.md").write_text(md, encoding="utf-8")
    (root / EIDE_DIR / "FEATURES.json").write_text(
        json.dumps(features, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"progress_md": md, "features": features}


@capability("memory.summarize_session")
def summarize_session(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: MEMORY-08 — CDS-12.6; MEM-11 §5 (thủ tục khởi động phiên, 5 bước); UC-A06.

    Trả {done, waiting, next, undo_until} — thứ `chat.report_back` đọc ra thành câu "lần trước
    đã… còn chờ… tôi đề nghị…". Mục tiêu của §5 là tiếp tục được trong ≤ 15 phút với ≤ 1 câu
    hỏi, nên `next` phải là một ĐỀ NGHỊ cụ thể chứ không phải một danh sách để người tự chọn.

    Giới hạn ≤ 200 token của hợp đồng là thật, không phải lời khuyên: bản tóm tắt này đi vào
    lượt đầu của phiên mới, và một tóm tắt phình ra sẽ đẩy chính thứ nó tóm tắt ra khỏi ngữ cảnh.
    """
    root = _goc(ctx)
    led = ctx.extra.get("ledger")
    xong, cho = _tu_ledger(led)
    feats = _features(root)
    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []

    done = [f"{c['cap']} ({c['run_id'][:8]})" for c in xong[-5:]]
    waiting = [f"{c['cap']} chờ duyệt ({c['run_id'][:8]})" for c in cho[:5]]

    nxt: list[str] = []
    db = store.store_path(root)
    if db.exists():
        with sqlite3.connect(db) as c:
            do_dang = c.execute("SELECT id, state FROM run WHERE state IN ('running','asked')"
                                " ORDER BY id").fetchall()
        for rid, st in do_dang[:2]:
            nxt.append(f"tiếp tục run {rid} (đang {st})")
    hong = next((f for f in feats if f["status"] == "failing"), None)
    if hong:
        nxt.append(f"làm tiếp {hong['id']} {hong['title']}")
    if not nxt:
        nxt.append("chưa có việc dở — chờ lệnh")

    sid = params.get("session_id")
    phien = SessionMemory.doc(root, sid) if sid else SessionMemory.gan_nhat(root)
    summary = {"done": done, "waiting": waiting, "next": nxt,
               "undo_until": (undo[0]["deadline"] if undo else None)}
    if led is not None:
        led.append("session.summary", {"session_id": phien.session_id if phien else "",
                                       "summary": "; ".join(done[-2:] + nxt[:1])[:400]})
    return {"summary": summary}
