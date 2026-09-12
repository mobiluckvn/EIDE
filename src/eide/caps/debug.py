"""Nhóm `debug.*` — CDS-12.4 DEBUG-01…DEBUG-06 (mốc M3); DDD-14 §2 DebugSession.

Nhóm này trả lời một câu mà không nhóm nào khác trả lời: **vì sao firmware làm thế**. Khác biệt
so với `sim.*` là ở hướng đi. `sim.run` hỏi *"nó có làm đúng điều ta chờ không"* và trả về
đạt/không; `debug.*` bắt đầu từ chỗ nó KHÔNG đúng, rồi đi ngược về nguyên nhân.

**Ba bất biến của cả nhóm, và cả ba đều là "không làm một việc".**

1. **Không đọc cả tệp log vào mô hình.** DEBUG-01 nói thẳng: thống kê tính bằng MÃ, mô hình chỉ
   nhìn một VÙNG. Một log 1 GB không vào được ngữ cảnh nào, và kể cả khi vào được thì trả tiền
   token để mô hình tự đếm số dòng ERROR là trả tiền cho một việc `collections.Counter` làm đúng
   hơn.
2. **Không kết luận thay người khi chưa chạy được thí nghiệm.** `debug.experiment` trên một
   board chưa đánh dấu lab thì trả `pending` — không đoán kết quả, không coi như đạt.
3. **Không để một chẩn đoán trôi đi.** `debug.save_session` lưu cả giả thuyết ĐÃ BỊ BÁC, vì lần
   sau gặp lại triệu chứng ấy thì thứ đáng giá nhất là biết hướng nào đã đi và đã sai.

**Vì sao `hypothesize` và `ask_at` phải trích dẫn.** Cả hai gọi mô hình. Một chẩn đoán nghe rất
hợp lý mà không neo vào dòng log nào hay fact nào thì không kiểm lại được — và trong gỡ lỗi
nhúng, một giả thuyết sai được tin là đúng sẽ tốn vài giờ đo đạc vào một chỗ không hỏng.
"""
from __future__ import annotations

import json
import re
import secrets
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# Số mẫu lặp trả về. DEBUG-01 khai `top_patterns[]` mà không nói bao nhiêu; 10 là chỗ dừng của
# "đọc lướt được" — một bảng 50 dòng thì người ta không đọc, và mẫu thứ 50 gần như luôn là
# nhiễu một lần.
TOP_MAU = 10

# Khoảng lặng tính là `gap` khi nó dài gấp ngần này lần khoảng cách trung vị giữa hai dòng.
# Dùng TRUNG VỊ chứ không trung bình: một khoảng lặng 30 giây kéo trung bình lên đủ để chính nó
# thôi bất thường, và đó đúng là thứ ta đang đi tìm.
HE_SO_GAP = 5.0

MUC_LOG = ("TRACE", "DEBUG", "INFO", "WARN", "WARNING", "ERROR", "FATAL", "PANIC")

# Dòng log có mốc thời gian ở đầu: `[12.345]`, `12.345`, `2026-09-12T00:00:00`, `00:00:12.345`.
RE_MOC = re.compile(
    r"^\s*[\[<(]?\s*(?:(?P<iso>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?)"
    r"|(?P<hms>\d{1,2}:\d{2}:\d{2}(?:\.\d+)?)"
    r"|(?P<giay>\d+(?:\.\d+)?))\s*[\]>)]?")

# Số, địa chỉ, id — thay bằng chỗ trống để hai dòng chỉ khác con số gộp thành MỘT mẫu. Không có
# bước này thì `top_patterns` là một danh sách các dòng khác nhau đúng một chữ số, tức vô dụng.
RE_SO = re.compile(r"0[xX][0-9a-fA-F]+|\b\d+(?:\.\d+)?\b")


def _du_an(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / ".eide").is_dir():
        raise EideError("E2000", "Nhóm debug.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _giai(root: Path, p: str) -> Path:
    f = Path(p).expanduser()
    return f if f.is_absolute() else root / f


def _moc_giay(dong: str) -> float | None:
    """Mốc thời gian của một dòng, quy về GIÂY. None nếu dòng không có mốc."""
    m = RE_MOC.match(dong)
    if not m:
        return None
    if (g := m.group("giay")) is not None:
        return float(g)
    if (h := m.group("hms")) is not None:
        gio, phut, giay = h.split(":")
        return int(gio) * 3600 + int(phut) * 60 + float(giay)
    try:
        return datetime.fromisoformat(m.group("iso")).timestamp()
    except ValueError:
        return None


def _mau(dong: str) -> str:
    """Dòng → mẫu: bỏ mốc thời gian ở đầu, thay mọi số bằng `#`."""
    con = RE_MOC.sub("", dong, count=1).strip()
    return RE_SO.sub("#", con)[:200]


# ---------------------------------------------------------------- DEBUG-01 log_stats


@capability("debug.log_stats")
def log_stats(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-01 — CDS-12.4; R0, `errors: [E4004]`, `undo: none`.
    tc: "TC-38 log 1 GB < 5 s".

    **Tính bằng MÃ, không bằng mô hình** — hợp đồng nói thẳng thế, và lý do thì đo được: đọc
    một log 1 GB vào ngữ cảnh là bất khả, còn trả token cho mô hình để nó đếm số dòng ERROR là
    trả tiền cho việc mà `Counter` làm đúng hơn và nhanh hơn bốn bậc độ lớn.

    Đọc theo DÒNG, không `read_text()`: cùng một lý do, ở tầng thấp hơn. Nạp cả tệp vào RAM
    trước khi đếm thì `TC-38` hỏng vì hết bộ nhớ chứ không vì chậm.

    **`gaps[]` là phần đáng giá nhất và cũng là phần dễ làm sai nhất.** Một khoảng lặng bất
    thường trong log nhúng thường là chỗ firmware treo hoặc reset — đúng thứ người gỡ lỗi đi
    tìm. Ngưỡng tính theo TRUNG VỊ chứ không trung bình: một khoảng lặng 30 giây kéo trung bình
    lên đủ để chính nó thôi bất thường, tức phép đo tự che mất thứ nó được dựng lên để tìm.

    `range` thu hẹp vùng đọc (`{"start": n, "end": m}`, đếm theo DÒNG, 1-based, `end` bao gồm).
    Log không có mốc thời gian thì `time_span` và `gaps` là `null`/rỗng — một câu trả lời thật,
    không phải chỗ để đoán.
    """
    root = _du_an(ctx)
    f = _giai(root, params["file"])
    if not f.exists():
        raise EideError("E4004", f"Không có tệp log {f}", file=str(f))

    r = params.get("range") or {}
    dau = int(r.get("start") or 1)
    cuoi = int(r["end"]) if r.get("end") is not None else None

    mau: Counter[str] = Counter()
    muc: Counter[str] = Counter()
    mocs: list[tuple[int, float]] = []
    n_dong = 0
    with f.open("r", encoding="utf-8", errors="replace") as fh:
        for i, dong in enumerate(fh, start=1):
            if i < dau:
                continue
            if cuoi is not None and i > cuoi:
                break
            n_dong += 1
            d = dong.rstrip("\n")
            if not d.strip():
                continue
            mau[_mau(d)] += 1
            hoa = d.upper()
            for m in MUC_LOG:
                if m in hoa:
                    muc["WARN" if m == "WARNING" else m] += 1
                    break
            if (t := _moc_giay(d)) is not None:
                mocs.append((i, t))

    return {"stats": {
        "file": str(f.relative_to(root)) if f.is_relative_to(root) else str(f),
        "lines": n_dong,
        "range": {"start": dau, "end": cuoi},
        "top_patterns": [{"pattern": p, "count": c} for p, c in mau.most_common(TOP_MAU)],
        "levels": dict(sorted(muc.items())),
        "time_span": _khoang(mocs),
        "gaps": _khoang_lang(mocs),
    }}


def _khoang(mocs: list[tuple[int, float]]) -> dict[str, Any] | None:
    if len(mocs) < 2:
        return None
    return {"start_s": mocs[0][1], "end_s": mocs[-1][1],
            "duration_s": round(mocs[-1][1] - mocs[0][1], 6)}


def _khoang_lang(mocs: list[tuple[int, float]]) -> list[dict[str, Any]]:
    """Khoảng lặng dài bất thường, kèm SỐ DÒNG hai đầu để người đọc mở đúng chỗ."""
    if len(mocs) < 3:
        return []
    hieu = [(mocs[i][1] - mocs[i - 1][1], mocs[i - 1][0], mocs[i][0]) for i in range(1, len(mocs))]
    duong = sorted(d for d, _, _ in hieu if d > 0)
    if not duong:
        return []
    giua = duong[len(duong) // 2]
    nguong = giua * HE_SO_GAP
    return [{"after_line": a, "before_line": b, "gap_s": round(d, 6)}
            for d, a, b in hieu if d > nguong][:TOP_MAU]


# ---------------------------------------------------------------- DEBUG-05 save_session


@capability("debug.save_session")
def save_session(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-05 — CDS-12.4; DDD-14 §2 DebugSession; MEM-11 §6. R1, `undo: none`.
    tc: TC-38.

    **Lưu cả giả thuyết ĐÃ BỊ BÁC.** Cám dỗ là chỉ giữ cái đúng cho gọn, nhưng lần sau gặp lại
    đúng triệu chứng ấy thì thứ đáng giá nhất là biết hướng nào đã đi và đã sai — nó cắt đi vài
    giờ đo lại một chỗ không hỏng. Đó cũng là lý do `outcome` có `refuted` chứ không chỉ
    `confirmed`/`open`.

    **Ghi sổ lỗi khi phiên đóng lại bằng một bài học**, tức `outcome != "open"`. Bài học đi vào
    `evidence` dưới dạng id phiên chứ không dưới dạng một đoạn văn: hợp đồng MEMORY-06 khai
    `additionalProperties: false` và KHÔNG có `negative_prompt` trong `input_schema` — trường ấy
    do chính `memory.error_ledger` sinh ra, và đó là chỗ đúng của nó. Nhét sẵn một câu vào đây
    là hai nơi cùng viết một trường, tức hai nơi cùng sai được.

    Phiên `open` KHÔNG ghi sổ lỗi: chưa biết đúng sai thì chưa có bài học, và ghi sớm là dạy
    lần sau tránh một hướng chưa ai chứng minh là sai.
    """
    root = _du_an(ctx)
    chan = params["diagnosis"] or {}
    ket = params["outcome"]

    sid = "ds_" + secrets.token_hex(8)
    gia_thuyet = chan.get("hypotheses") or []
    with store.open_store(store.store_path(root)) as c:
        c.execute(
            "INSERT INTO debug_session (id, log_ref, range_start, range_end, evidence,"
            " hypotheses, outcome, fact_ids, code_ids, at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (sid, chan.get("log_ref"),
             (chan.get("range") or {}).get("start"), (chan.get("range") or {}).get("end"),
             json.dumps(chan.get("evidence") or [], ensure_ascii=False),
             json.dumps(gia_thuyet, ensure_ascii=False), ket,
             json.dumps(chan.get("fact_ids") or [], ensure_ascii=False),
             json.dumps(chan.get("code_ids") or [], ensure_ascii=False),
             datetime.now(UTC).isoformat()))
        c.commit()
    store.write_seal(store.store_path(root), ctx.extra.get("ledger"))

    if ket != "open":
        from eide.caps.memory import error_ledger
        cau = (chan.get("summary") or (gia_thuyet[0].get("text") if gia_thuyet else "") or "")
        error_ledger({
            # `confirmed` = đã tìm ra nguyên nhân thật → `tool_fail`; `refuted` = giả thuyết
            # nghe hợp lý mà sai → `hallucination`, đúng nhóm mà MEM-11 §6 muốn chặn lần sau.
            "kind": "tool_fail" if ket == "confirmed" else "hallucination",
            "role": "debugger",
            "evidence": f"debug_session {sid}: {' '.join(str(cau).split()[:40])}".strip(": "),
        }, ctx)

    if (led := ctx.extra.get("ledger")) is not None:
        # `store.write`, không một kiểu riêng: API-15 §5 khai 26 kiểu sự kiện và `debug.session`
        # không nằm trong đó. Thêm một kiểu là sửa `docs/spec/` — cần mục DEVIATIONS và chữ ký
        # chủ sản phẩm cho một thứ mà kiểu đã có mô tả đúng: đây LÀ một lần ghi vào store.
        led.append("store.write", {"batch_id": sid, "n_facts": 0, "n_conflicts": 0,
                                   "actor": ctx.actor or "agent",
                                   "reason": f"debug.save_session outcome={ket} "
                                             f"n_hypotheses={len(gia_thuyet)}"})
    return {"id": sid}


def _doc_phien(root: Path, sid: str) -> dict[str, Any] | None:
    with store.open_store(store.store_path(root)) as c:
        r = c.execute(
            "SELECT id, log_ref, range_start, range_end, evidence, hypotheses, outcome,"
            " fact_ids, code_ids, at FROM debug_session WHERE id = ?", (sid,)).fetchone()
    if not r:
        return None
    ten = ("id", "log_ref", "range_start", "range_end", "evidence", "hypotheses", "outcome",
           "fact_ids", "code_ids", "at")
    d = dict(zip(ten, r, strict=True))
    for k in ("evidence", "hypotheses", "fact_ids", "code_ids"):
        d[k] = json.loads(d[k]) if d[k] else []
    return d


# ---------------------------------------------------------------- DEBUG-03 hypothesize

_SCHEMA_CHAN_DOAN = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "hypotheses": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "p": {"type": "number"},
                    "supports": {"type": "array", "items": {"type": "string"}},
                    "experiment": {
                        "type": "object",
                        "properties": {"cap": {"type": "string"}, "args": {"type": "object"},
                                       "expect": {"type": "string"},
                                       "cost": {"type": "string",
                                                "enum": ["rẻ", "vừa", "đắt"]}},
                        "required": ["cap", "expect"], "additionalProperties": False},
                },
                "required": ["text", "p", "supports"], "additionalProperties": False,
            },
        },
    },
    "required": ["summary", "hypotheses"], "additionalProperties": False,
}


@capability("debug.hypothesize")
def hypothesize(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-03 — CDS-12.4; vai trò `debugger`. R0, `errors: [E5002]`, `undo: none`.
    tc: "TC-37 ≥ 80% đúng hàm".

    **Giả thuyết phải NEO vào chứng cứ có id.** `supports[]` chỉ được chứa id mà người gọi đã
    đưa vào `evidence_ids` — mô hình bịa thêm một id trông rất giống thật là chuyện thường, và
    một giả thuyết tựa trên chứng cứ không tồn tại thì không bác được, nên nó sống mãi.

    Chứng cứ rỗng → E5002 ngay, không gọi mô hình. Hỏi "vì sao hỏng" mà không đưa dữ kiện nào
    thì thứ nhận lại chỉ có thể là một danh sách nguyên nhân phổ biến của Internet — nghe hợp
    lý, không liên quan gì tới con chip này, và tốn tiền.

    **Xếp hạng theo `p` rồi tới thí nghiệm RẺ NHẤT.** Hợp đồng đòi "thí nghiệm rẻ nhất", và thứ
    tự ấy là thứ tự người ta nên làm: một giả thuyết `p` hơi thấp hơn nhưng kiểm được bằng một
    lệnh đọc thanh ghi đáng thử trước một giả thuyết `p` cao mà phải hàn lại board.
    """
    root = _du_an(ctx)
    ids = [str(x) for x in (params.get("evidence_ids") or [])]
    if not ids:
        raise EideError("E5002", "Không có chứng cứ nào để suy: `evidence_ids` rỗng. "
                        "Chạy `debug.log_stats`/`sim.run` trước rồi đưa id vào.")

    cc = _tra_chung_cu(root, ids)
    thay = [x["id"] for x in cc if x.get("found")]
    if not thay:
        raise EideError("E5002", f"Không tra được chứng cứ nào trong {ids} — kiểm lại id",
                        evidence_ids=ids)

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    resp = gw.run("debugger",
                  "Dưới đây là chứng cứ thu được từ một firmware nhúng đang hỏng. Nêu các giả "
                  "thuyết về NGUYÊN NHÂN, xếp theo `p` giảm dần. Mỗi giả thuyết phải kèm "
                  "`supports` chỉ gồm id chứng cứ CÓ TRONG dữ kiện — không thêm id nào khác — "
                  "và một thí nghiệm phân biệt rẻ nhất có thể.\n\n"
                  + json.dumps(cc, ensure_ascii=False),
                  _SCHEMA_CHAN_DOAN)

    gt = []
    for h in (resp.data.get("hypotheses") or []):
        # Lọc id bịa NGAY TẠI ĐÂY, không để nó chảy xuống `save_session`: một chứng cứ không
        # tồn tại trong store là một giả thuyết không ai bác được.
        h = {**h, "supports": [s for s in (h.get("supports") or []) if s in thay]}
        gt.append(h)
    gt.sort(key=lambda h: (-float(h.get("p") or 0), _gia_thi_nghiem(h)))

    return {"diagnosis": {"summary": (resp.data.get("summary") or "").strip(),
                          "hypotheses": gt, "evidence": cc,
                          "evidence_ids": thay}}


_GIA = {"rẻ": 0, "vừa": 1, "đắt": 2}


def _gia_thi_nghiem(h: dict[str, Any]) -> int:
    return _GIA.get(((h.get("experiment") or {}).get("cost") or "vừa"), 1)


def _tra_chung_cu(root: Path, ids: list[str]) -> list[dict[str, Any]]:
    """Tra id chứng cứ trong store. Không tra được thì NÓI RA, không lặng lẽ bỏ.

    Ba nguồn theo đúng tiền tố id của DDD-14: `tr_` ToolReport, `m_` Measurement, `f_` Fact.
    Một id lạ vẫn được trả về với `found: false` — mô hình cần biết là nó KHÔNG có dữ kiện ấy,
    còn hơn im lặng để nó tưởng mình có.
    """
    ra: list[dict[str, Any]] = []
    with store.open_store(store.store_path(root)) as c:
        for i in ids:
            if i.startswith("tr_"):
                r = c.execute("SELECT tool, passed, metrics, log_ref, at FROM tool_report"
                              " WHERE id = ?", (i,)).fetchone()
                if r:
                    ra.append({"id": i, "found": True, "kind": "tool_report", "tool": r[0],
                               "passed": bool(r[1]), "metrics": json.loads(r[2] or "{}"),
                               "log_ref": r[3], "at": r[4]})
                    continue
            elif i.startswith("m_"):
                r = c.execute("SELECT kind, target, value, unit, at FROM measurement"
                              " WHERE id = ?", (i,)).fetchone()
                if r:
                    ra.append({"id": i, "found": True, "kind": "measurement", "measure": r[0],
                               "target": r[1], "value": json.loads(r[2] or "null"),
                               "unit": r[3], "at": r[4]})
                    continue
            elif i.startswith("f_"):
                r = c.execute("SELECT subject, predicate, value, unit, status FROM fact"
                              " WHERE id = ?", (i,)).fetchone()
                if r:
                    ra.append({"id": i, "found": True, "kind": "fact", "subject": r[0],
                               "predicate": r[1], "value": json.loads(r[2] or "null"),
                               "unit": r[3], "status": r[4]})
                    continue
            ra.append({"id": i, "found": False})
    return ra


# ---------------------------------------------------------------- DEBUG-02 ask_at

_SCHEMA_HOI = {
    "type": "object",
    "properties": {
        "answer": {"type": "string"},
        "cites": {"type": "array", "items": {"type": "string"}},
        "confidence": {"type": "number"},
    },
    "required": ["answer", "cites"], "additionalProperties": False,
}

# Vùng log đưa vào ngữ cảnh. DEBUG-02 khai `range` là tham số BẮT BUỘC, nên người hỏi đã chọn
# vùng — trần này chỉ để một `range` lỡ tay (1..900000) không kéo cả tệp vào mô hình.
TRAN_DONG = 400


@capability("debug.ask_at")
def ask_at(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-02 — CDS-12.4; vai trò `debugger`; KG-04 `kg.neighborhood`. R0,
    `errors: [E5002]`, `undo: none`. tc: "Answer neo range".

    Ngữ cảnh ghép từ BỐN nguồn đúng như hợp đồng: vùng log + thống kê + hộ chiếu quanh từ khóa
    + đơn vị mã có dùng tới. Ghép bằng mã, không nhờ mô hình đi tìm — nó không có quyền đọc tệp,
    và cho nó quyền ấy là đổi một câu hỏi gỡ lỗi thành một lượt duyệt thư mục.

    **`range` là bắt buộc, và đó là điểm của năng lực này.** "Hỏi tại dòng" khác "hỏi về log":
    câu trả lời phải neo vào vùng người ta đang nhìn, nên vùng ấy do người chọn chứ không do mô
    hình đoán. Trần {TRAN_DONG} dòng chỉ để chặn một `range` lỡ tay.

    **Trả lời xong thì LƯU.** Hợp đồng nối thẳng sang `debug.save_session`, và `outcome` là
    `open`: một câu trả lời chưa được thí nghiệm nào xác nhận thì chưa phải kết luận. Ghi nó là
    `confirmed` ở đây sẽ làm `memory.error_ledger` học một bài học chưa ai kiểm.
    """
    root = _du_an(ctx)
    f = _giai(root, params["file"])
    if not f.exists():
        raise EideError("E4004", f"Không có tệp log {f}", file=str(f))
    r = params["range"] or {}
    dau = max(1, int(r.get("start") or 1))
    cuoi = int(r["end"]) if r.get("end") is not None else dau + TRAN_DONG - 1
    cuoi = min(cuoi, dau + TRAN_DONG - 1)

    vung: list[str] = []
    with f.open("r", encoding="utf-8", errors="replace") as fh:
        for i, dong in enumerate(fh, start=1):
            if i < dau:
                continue
            if i > cuoi:
                break
            vung.append(f"{i}: {dong.rstrip()}")

    thong_ke = log_stats({"file": params["file"], "range": {"start": dau, "end": cuoi}},
                         ctx)["stats"]
    ngu_canh = {
        "question": params["question"],
        "file": thong_ke["file"], "range": {"start": dau, "end": cuoi},
        "log": vung, "stats": thong_ke,
        "passport": _lan_can(ctx, vung),
        "code_units": _ma_lien_quan(root, vung),
    }

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    resp = gw.run("debugger",
                  "Trả lời câu hỏi về vùng log dưới đây. Chỉ dùng dữ kiện có trong ngữ cảnh; "
                  "`cites` phải nêu SỐ DÒNG (dạng `L<n>`) hoặc fact id đã xuất hiện. Không đoán "
                  "thanh ghi hay giá trị không có trong hộ chiếu.\n\n"
                  + json.dumps(ngu_canh, ensure_ascii=False),
                  _SCHEMA_HOI)

    chan = {
        "summary": (resp.data.get("answer") or "").strip(),
        "cites": list(resp.data.get("cites") or []),
        "confidence": resp.data.get("confidence"),
        "log_ref": str(f), "range": {"start": dau, "end": cuoi},
        "hypotheses": [], "evidence": [],
        "fact_ids": [x for x in (resp.data.get("cites") or []) if str(x).startswith("f_")],
        "code_ids": [u["id"] for u in ngu_canh["code_units"]],
    }
    sid = save_session({"diagnosis": chan, "outcome": "open"}, ctx)["id"]
    return {"diagnosis": chan, "session_id": sid}


def _lan_can(ctx: Context, vung: list[str]) -> dict[str, Any]:
    """Hộ chiếu quanh từ khóa thấy trong vùng log (KG-04 `kg.neighborhood`).

    Không có đồ thị hay không tra được thì trả rỗng, KHÔNG ném: một câu hỏi về log vẫn trả lời
    được khi chưa trích datasheet nào, chỉ là trả lời nghèo hơn. Ném ở đây biến `debug.ask_at`
    thành thứ chỉ dùng được sau khi đã làm xong việc khác.
    """
    tu = {t for d in vung for t in re.findall(r"\b[A-Z][A-Z0-9_]{2,}\b", d)}
    if not tu:
        return {}
    try:
        from eide.caps.kg import neighborhood
        return neighborhood({"subject": sorted(tu)[0], "depth": 1}, ctx)
    except (EideError, KeyError, TypeError):
        return {}


def _ma_lien_quan(root: Path, vung: list[str]) -> list[dict[str, Any]]:
    """`code_unit` có `uses` chạm tới từ khóa trong vùng log — hợp đồng ghi "code_unit USES"."""
    tu = {t.lower() for d in vung for t in re.findall(r"\b[A-Z][A-Z0-9_]{2,}\b", d)}
    if not tu:
        return []
    ra = []
    with store.open_store(store.store_path(root)) as c:
        for cid, path, uses in c.execute("SELECT id, path, uses FROM code_unit").fetchall():
            ds = json.loads(uses or "[]")
            if any(any(t in str(u).lower() for t in tu) for u in ds):
                ra.append({"id": cid, "path": path, "uses": ds})
    return ra[:20]


# ---------------------------------------------------------------- DEBUG-04 experiment


@capability("debug.experiment", features=["op", "board"])
def experiment(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-04 — CDS-12.4; POL-17 G-OPS; APD-08 §2. **R3**, tier T1*,
    `errors: [E3000, E4002]`, ask "Không lab", `undo: none`.
    tc: "Trên board lab tự chạy; không lab → pending".

    **Lớp rủi ro theo NĂNG LỰC BÊN TRONG, không theo cái vỏ.** Hợp đồng nói rõ: `probe_read` là
    R0, còn `probe_write`/nạp firmware thử là R3. Gán cứng R3 cho mọi thí nghiệm thì một lệnh
    đọc thanh ghi cũng phải hỏi người — và một cổng hỏi cả những lần vô hại là cổng người ta
    bấm qua cho xong. Gán cứng R0 thì ngược lại: một firmware thử được nạp lên board mà không
    ai biết.

    **Không lab → `pending`, không phải "đạt".** E3000 là POLICY_ASK — theo API-15 nó KHÔNG phải
    lỗi mà là trạng thái chờ người. Đây là chỗ khác biệt quan trọng nhất của năng lực này: một
    thí nghiệm chưa chạy thì chưa có chứng cứ, và trả về một `evidence` rỗng kèm `passed: true`
    là dựng ra chứng cứ cho một việc chưa xảy ra.

    Board không có trong cấu hình → E4002 kèm gợi ý `discover.scan`, đúng như bảng lỗi API-15.
    """
    _du_an(ctx)      # thí nghiệm chạy trong ngữ cảnh một dự án; không mở thì E2000 ngay ở đây
    tn = params["experiment"] or {}
    board = params["target"]
    cap = str(tn.get("cap") or "")
    if not cap:
        raise EideError("E1000", "`experiment.cap` không được rỗng — nêu năng lực sẽ chạy")

    gate = ctx.extra.get("gate")
    cfg = getattr(gate, "config", None) or {}
    boards = cfg.get("boards") or {}
    if board not in boards:
        raise EideError("E4002", f"Không có board `{board}` trong cấu hình — chạy `discover.scan`",
                        target=board, remedy="discover.scan")

    # `probe_read` và bạn bè chỉ ĐỌC: R0. Mọi thứ ghi/nạp: R3, và R3 đòi board lab.
    chi_doc = cap.endswith((".probe_read", ".read_mem", ".read_reg", ".observe", ".serial"))
    if not chi_doc and not (boards.get(board) or {}).get("lab"):
        raise EideError(
            "E3000",
            f"Thí nghiệm `{cap}` ghi lên board mà `{board}` chưa được đánh dấu lab — "
            "cần người xác nhận (`board.mark_lab` sau khi kiểm cơ cấu chấp hành và giới hạn dòng)",
            gate_id="G-OPS", target=board, cap=cap, risk="R3")

    from eide_core.registry import get_registry
    reg = get_registry()
    if not reg.get(cap).implemented:
        raise EideError("E4002", f"Năng lực `{cap}` chưa hiện thực — thí nghiệm này cần board "
                        "thật (nhóm `target.*`/`discover.*`, mốc M2)",
                        target=board, cap=cap, remedy="discover.scan")

    kq = reg.get(cap).handler(tn.get("args") or {}, ctx)
    mong = tn.get("expect")
    khop = None if mong is None else (str(mong) in json.dumps(kq, ensure_ascii=False))
    return {"evidence": {"cap": cap, "target": board, "args": tn.get("args") or {},
                         "expect": mong, "matched": khop, "result": kq,
                         "at": datetime.now(UTC).isoformat()}}


# ---------------------------------------------------------------- DEBUG-06 propose_fix


@capability("debug.propose_fix")
def propose_fix(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DEBUG-06 — CDS-12.4; K6 `constraints.yaml`; PLAN-01. R0, `errors: []`,
    ask "Sửa phần cứng", `undo: none`.
    tc: "NACK → giảm bus 100 kHz là constraint".

    **Ba loại sửa, và phân loại chúng là toàn bộ giá trị của năng lực này.** Cùng một triệu
    chứng — I2C NACK — có thể dẫn tới ba việc hoàn toàn khác nhau: sửa MÃ (thiếu chờ ACK), sửa
    RÀNG BUỘC (hạ bus xuống 100 kHz), hay sửa PHẦN CỨNG (thiếu điện trở kéo lên). Đưa nhầm loại
    là đưa người ta đi sai hướng ngay từ bước đầu, và trong ba loại thì `constraint` hay bị bỏ
    sót nhất vì nó không trông giống "một lỗi".

    Phân loại bằng TỪ KHÓA trên câu chẩn đoán chứ không gọi lại mô hình: chẩn đoán đã có rồi,
    và hỏi lại mô hình "đây là loại gì" là mời nó đổi ý giữa hai lời gọi.

    **`hardware` thì dừng ở ĐỀ XUẤT.** `ask_when` của hợp đồng là "Sửa phần cứng" — EIDE không
    có cách nào tự hàn một điện trở, nên thứ đúng nhất nó làm được là nói rõ cần ai làm gì.

    Phiên chưa `confirmed` vẫn trả đề xuất, kèm `needs_confirmation: true`: bước 1 của hợp đồng
    viết "Từ Diagnosis confirmed", nhưng từ chối thẳng thì người dùng mất luôn manh mối mà phiên
    ấy đã có. Nói ra rằng nó chưa được xác nhận là đủ.
    """
    root = _du_an(ctx)
    sid = params["session_id"]
    phien = _doc_phien(root, sid)
    if not phien:
        return {"proposal": {"kind": "unknown", "session_id": sid,
                             "step_text": f"Không tra được phiên `{sid}` trong dự án này.",
                             "needs_confirmation": True}}

    cau = " ".join(
        [str((h or {}).get("text") or "") for h in phien["hypotheses"]]
        + [str(e) for e in phien["evidence"]]).lower()

    loai = _phan_loai(cau)

    de_xuat: dict[str, Any] = {
        "kind": loai, "session_id": sid, "outcome": phien["outcome"],
        "needs_confirmation": phien["outcome"] != "confirmed",
        "fact_ids": phien["fact_ids"], "code_ids": phien["code_ids"],
    }
    if loai == "code":
        de_xuat["step_text"] = ("Sửa mã theo chẩn đoán của phiên " + sid
                                + " — tạo STEP mới bằng `plan.create`, rồi `code.modify`.")
    elif loai == "constraint":
        so = re.search(r"(\d{2,4})\s*k?hz", cau)
        moi = f"{so.group(1)} kHz" if so else "100 kHz"
        de_xuat["step_text"] = (f"Hạ ràng buộc bus xuống {moi} trong `constraints.yaml` (K6), "
                                "rồi dựng và mô phỏng lại.")
        de_xuat["k6_change"] = {"path": "bus_limits.i2c_khz",
                                "value": int(so.group(1)) if so else 100,
                                "reason": f"debug_session {sid}"}
    else:
        de_xuat["step_text"] = ("Cần người sửa phần cứng theo chẩn đoán của phiên " + sid
                                + ". EIDE dừng ở đề xuất: không tự thay đổi mạch được.")
    return {"proposal": de_xuat}


# Một GIỚI HẠN CHỈNH ĐƯỢC: có tên đại lượng kèm đơn vị, tức có một con số trong `constraints.yaml`
# để hạ xuống. Đây là dấu hiệu MẠNH nhất trong ba loại, nên nó được xét trước.
RE_GIOI_HAN = re.compile(
    r"\b\d+\s*(?:k|m)?hz\b|\bbaud\s*\d+|\b\d+\s*baud\b|\bbus[_ ]?limits?\b|\bxung nhịp\b"
    r"|\btốc độ\b|\bclock\b|\btiming\b", re.I)

# Một BỘ PHẬN VẬT LÝ: thứ phải cầm mỏ hàn mới đổi được. Chỉ những danh từ chỉ đích danh linh
# kiện hoặc thao tác tay — cố ý KHÔNG có "dây", "nhiễu", "nguồn": ba từ ấy tả bối cảnh của rất
# nhiều chẩn đoán, kể cả những chẩn đoán mà việc phải làm là hạ tốc độ bus.
TU_PHAN_CUNG = ("điện trở", "kéo lên", "pull-up", "pullup", "tụ", "hàn", "mỏ hàn", "đứt mạch",
                "chân cắm", "jumper", "đảo chân", "sai chân", "linh kiện", "thay board")


def _phan_loai(cau: str) -> str:
    """Chẩn đoán → `constraint` | `hardware` | `code`, xét theo độ MẠNH của dấu hiệu.

    Thứ tự ở đây là toàn bộ phần khó. Bản đầu xét `hardware` trước và phân loại sai câu *"I2C
    NACK vì bus chạy 400 kHz quá nhanh cho dây dài"* thành `hardware`, chỉ vì nó có chữ "dây" —
    trong khi việc phải làm rành rành là hạ 400 kHz xuống. Bài học: một danh từ chỉ bối cảnh
    ("dây", "nhiễu", "nguồn") YẾU hơn một con số kèm đơn vị, vì con số ấy trỏ thẳng vào một dòng
    trong `constraints.yaml`.

    `code` là mặc định chứ không phải một nhánh khớp từ khóa, và đó là chủ ý: phần lớn lỗi
    firmware là lỗi mã, nên đoán sai về phía `code` chỉ tốn một lần đọc lại hàm — còn đoán sai
    về phía `hardware` thì gửi người ta đi đo mạch cho một chỗ không hỏng.
    """
    if RE_GIOI_HAN.search(cau):
        return "constraint"
    if any(t in cau for t in TU_PHAN_CUNG):
        return "hardware"
    return "code"
