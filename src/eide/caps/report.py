"""Namespace report.* — CDS-12.5 (tập Quản trị); APD-08 §5."""
from __future__ import annotations

import collections
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from eide_core import store
from eide_core.errors import EideError
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


# ---------------------------------------------------------------- REPORT-04 explain


TRAN_TU = 150       # bước 1: "≤ 150 từ"

_SCHEMA_GIAI_THICH = {"type": "object", "required": ["text"],
                      "properties": {"text": {"type": "string"}}}


@capability("report.explain")
def explain(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: REPORT-04 — CDS-12.5; UR-HT-03; POL-17 §7 (DecisionLog); API-15 §7. R0,
    `errors: []`, `undo: none`. tc: "Có mã quy tắc và fact id".

    Câu hỏi năng lực này trả lời — *vì sao nó làm thế* — là câu người ta hỏi khi đang vội, nên
    ≤ 150 từ là ràng buộc chứ không phải gợi ý. Cắt bằng MÃ, không dặn trong prompt.

    **Bằng chứng dựng bằng mã, văn xuôi do mô hình viết quanh nó** — cùng khuôn `doc.generate`.
    Mã quy tắc và fact id lấy thẳng từ `decision_log`/`fact`; mô hình chỉ nối chúng thành câu.
    Để mô hình tự nhớ mã quy tắc là mời nó bịa ra một mã trông rất giống thật.

    Không tra được `id` thì NÓI RA. `errors: []` nghĩa là không ném, nhưng một đoạn văn trôi
    chảy về một quyết định không tồn tại còn tệ hơn một lỗi.
    """
    ma = params["id"]
    su_kien = _tra_su_kien(ctx, ma)
    if not su_kien:
        return {"text": f"Không tra được `{ma}` trong nhật ký, sổ quyết định hay store của dự "
                        "án này. Kiểm lại id, hoặc mở dự án chứa nó rồi hỏi lại."}

    trich = su_kien["citations"]
    tho = su_kien["text"] + (" " + " ".join(f"[{x}]" for x in trich) if trich else "")
    try:
        gw = ctx.extra.get("gateway")
        if gw is None:
            from eide_core.gateway import Gateway
            gw = Gateway(ledger=ctx.extra.get("ledger"))
        resp = gw.run("writer",
                      f"Giải thích ngắn gọn (≤ {TRAN_TU} từ, tiếng Việt) vì sao việc dưới đây "
                      "xảy ra. Nêu NGUYÊN VĂN mọi mã quy tắc và id trong phần dữ kiện, đừng "
                      "nhớ lại từ kiến thức chung.\n\n" + json.dumps(su_kien, ensure_ascii=False),
                      _SCHEMA_GIAI_THICH)
        van = (resp.data.get("text") or "").strip() or tho
    except EideError:
        van = tho

    # Trích dẫn phải CÓ MẶT: mô hình bỏ sót mã quy tắc là chuyện thường, và một lời giải thích
    # không có mã thì không tra ngược được — đúng thứ `tc` của hợp đồng đòi.
    thieu = [x for x in trich if x not in van]
    if thieu:
        van = van.rstrip() + " " + " ".join(f"[{x}]" for x in thieu)
    return {"text": _cat_tu(van, TRAN_TU)}


def _cat_tu(t: str, n: int) -> str:
    tu = t.split()
    return t if len(tu) <= n else " ".join(tu[:n]) + "…"


def _tra_su_kien(ctx: Context, ma: str) -> dict[str, Any] | None:
    """Tra `id` trong ba nguồn theo thứ tự rẻ dần: sổ quyết định, store, nhật ký.

    `citations` là danh sách thứ BẮT BUỘC xuất hiện trong câu trả lời — mã quy tắc, fact id,
    nguồn. Nó là hợp đồng giữa mã và mô hình: mã bảo đảm chúng có mặt, mô hình chỉ viết văn.
    """
    from eide.caps.project import EIDE_DIR
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if root and (root / EIDE_DIR).is_dir():
        db = store.store_path(root)
        if db.exists():
            with store.open_store(db) as c:
                if (r := c.execute(
                        "SELECT id, gate, action_cap, risk, autonomy_level, decision, by, rule,"
                        " reason, human_answer, at FROM decision_log WHERE id=?",
                        (ma,)).fetchone()):
                    return {"loai": "decision", "id": r[0], "gate": r[1], "cap": r[2],
                            "risk": r[3], "autonomy": r[4], "decision": r[5], "by": r[6],
                            "rule": r[7], "reason": r[8], "human_answer": r[9], "at": r[10],
                            "citations": [x for x in (r[7], r[0]) if x],
                            "text": f"Cổng {r[1]} quyết {r[5]} cho `{r[2]}` theo quy tắc {r[7]}"
                                    f" ({r[8] or 'không nêu lý do'}), do {r[6]}."}
                if (r := c.execute(
                        "SELECT id, subject, predicate, value, source_id, tier, method, status"
                        " FROM fact WHERE id=?", (ma,)).fetchone()):
                    return {"loai": "fact", "id": r[0], "subject": r[1], "predicate": r[2],
                            "value": r[3], "source_id": r[4], "tier": r[5], "method": r[6],
                            "status": r[7], "citations": [r[0], r[4]],
                            "text": f"Fact {r[0]}: {r[1]} · {r[2]} = {r[3]}, tầng {r[5]}, rút "
                                    f"bằng {r[6]} từ nguồn {r[4]}, trạng thái {r[7]}."}

    led = ctx.extra.get("ledger")
    for e in reversed(led.records() if led is not None else []):
        d = e.get("data") or {}
        if ma in (e.get("hash", ""), d.get("run_id"), d.get("cr_id"), d.get("id"),
                  d.get("commit"), d.get("gate_id")):
            return {"loai": e["kind"], "id": ma, "at": e.get("ts"), "data": d,
                    "citations": [ma],
                    "text": f"Sự kiện `{e['kind']}` lúc {e.get('ts')}: "
                            f"{json.dumps(d, ensure_ascii=False)[:400]}"}
    return None
