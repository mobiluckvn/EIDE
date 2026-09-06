"""Namespace report.* — CDS-12.5 (tập Quản trị); APD-08 §5."""
from __future__ import annotations

import collections
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from eide_core.registry import capability
from eide_core.router import Context
from eide_core.undo import UndoService

# steps: "≤ 40 dòng". Một báo cáo hằng ngày dài hơn một màn hình thì không ai đọc, và một
# báo cáo không ai đọc không phải là "làm rồi báo cáo" (UXD-13 U2) — nó chỉ là ghi chép.
MAX_DONG = 40
TOP_N = 8


@capability("report.progress")
def progress(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REPORT-01 — CDS-12.5; APD-08 §5; API-15 §5 (cap.run.*, model.call, error, gate.human).

    `tc` là "số liệu khớp ledger": mọi con số dưới đây đọc từ ledger, không từ bộ đếm riêng.

    Khác `memory.progress` (MEMORY-04) ở mục đích, không phải ở dữ liệu: MEMORY-04 sinh
    PROGRESS.md — ẢNH CHỤP trạng thái hiện tại để lượt đầu phiên sau đọc; REPORT-01 tổng hợp
    một KHOẢNG THỜI GIAN (ngày/tuần) cho người xem tác tử đã làm gì và tốn bao nhiêu.
    """
    ky = params.get("period", "day")
    mo = datetime.now(UTC) - timedelta(days=7 if ky == "week" else 1)
    led = ctx.extra.get("ledger")
    recs = [r for r in (led.records() if led is not None else [])
            if datetime.fromisoformat(r["ts"]) >= mo]

    ten: dict[str, str] = {}
    xong: list[str] = []
    cho: dict[str, str] = {}
    chi_phi = 0.0
    token_vao = token_ra = 0
    loi: collections.Counter[str] = collections.Counter()
    for r in recs:
        d = r.get("data") or {}
        k = r["kind"]
        if k == "cap.run.start" and d.get("run_id"):
            ten[d["run_id"]] = d.get("cap", "?")
        elif k == "cap.run.finish" and d.get("run_id"):
            if d.get("status") == "done":
                xong.append(ten.get(d["run_id"], "?"))
            elif d.get("status") == "pending":
                cho[d["run_id"]] = ten.get(d["run_id"], "?")
        elif k == "gate.human" and d.get("gate_id"):
            cho.pop(d["gate_id"], None)
        elif k == "model.call":
            chi_phi += float(d.get("cost_usd") or 0)
            token_vao += int(d.get("tokens_in") or 0)
            token_ra += int(d.get("tokens_out") or 0)
        elif k == "error":
            loi[str(d.get("kind", "?"))] += 1

    undo = UndoService(led, getattr(ctx.extra.get("gate"), "config", None)).list() if led else []
    nhan = {"day": "hôm nay", "week": "7 ngày qua"}[ky]
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    dau = f"# Báo cáo {nhan}" + (f" · dự án {root.name}" if root and (root / ".eide").is_dir() else "")

    dong = [dau, ""]
    dong.append(f"- Tác tử tự làm: **{len(xong)}** việc; chờ anh duyệt: **{len(cho)}**")
    if xong:
        for cap, n in collections.Counter(xong).most_common(TOP_N):
            dong.append(f"    - {cap} ×{n}")
    if cho:
        dong.append("- Đang chờ anh:")
        for rid, cap in list(cho.items())[:TOP_N]:
            dong.append(f"    - {cap} ({rid[:8]})")
    if undo:
        dong.append(f"- Hoàn tác được: **{len(undo)}** mục")
        for u in undo[:TOP_N]:
            dong.append(f"    - {u['cap']} ({u['kind']}) đến {(u['deadline'] or 'hết phiên')[:16]}")
    dong.append(f"- Chi phí mô hình: **{chi_phi:.4f} USD** · {token_vao} token vào, {token_ra} ra")
    if loi:
        dong.append("- Sổ lỗi: " + ", ".join(f"{k} ×{n}" for k, n in loi.most_common(TOP_N)))
    if not xong and not cho and not undo:
        dong.append("- Chưa có hoạt động nào trong kỳ.")

    # Cắt ở cuối chứ không bỏ mục: thà nói "còn N dòng nữa" hơn là im lặng bỏ bớt và để người
    # đọc tưởng đã thấy hết.
    if len(dong) > MAX_DONG:
        con = len(dong) - (MAX_DONG - 1)
        dong = dong[: MAX_DONG - 1] + [f"- … còn {con} dòng nữa (xem view.timeline)"]
    return {"md": "\n".join(dong) + "\n"}
