"""Namespace kg.* — CDS-12.2 (tập Tri thức); KAD-07 §6.3 đồ thị, §6.5 chính sách xung đột.

Tám năng lực mốc M0/M1. `kg.evidence` (KG-09) thuộc M2 và cần bảng `measurement` /
`debug_session` chưa có trong store — xem SPRINT-02.md.

Đồ thị là khung nhìn vật chất hóa của store (`eide_core.kg`), cache theo băm nội dung store nên
đổi một fact là lần dựng sau tự thấy. Không năng lực nào ở đây ghi vào đồ thị: muốn đổi tri thức
thì đổi fact, đó là bất biến của KAD-07 §4.1.
"""
from __future__ import annotations

import json
import secrets
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core import kg as dothi
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

EIDE_DIR = ".eide"

# Cache một đồ thị cho mỗi (đường dẫn store, băm nội dung). Băm là băm NỘI DUNG LOGIC
# (`store.content_digest`) chứ không phải băm byte tệp — WAL và VACUUM đổi byte mà không đổi dữ
# liệu, nên cache theo byte sẽ dựng lại đồ thị mỗi lần mở dự án. Xem DEVIATIONS DEV-007.
_CACHE: dict[tuple[str, str], dothi.DoThi] = {}


def _store(ctx: Context) -> Path:
    if not ctx.project_dir:
        raise EideError("E2000", "Nhóm kg.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    db = store.store_path(ctx.project_dir)
    if not db.exists():
        raise EideError("E2000", f"Không thấy store của dự án: {db}",
                        exists=[], candidates=[], missing=["store"])
    return db


def _do_thi(ctx: Context, force: bool = False) -> tuple[dothi.DoThi, bool]:
    """Trả (đồ thị, đã dùng cache)."""
    db = _store(ctx)
    with store.open_store(db) as c:
        digest = store.content_digest(c)
        khoa = (str(db), digest)
        if not force and khoa in _CACHE:
            return _CACHE[khoa], True
        g = dothi.dung(c, digest)
    # Chỉ giữ bản mới nhất của mỗi store: đồ thị cũ không còn ai hỏi tới sau khi store đổi, và
    # giữ chúng lại là một chỗ rò bộ nhớ tăng theo số lần ghi.
    for k in [k for k in _CACHE if k[0] == str(db)]:
        del _CACHE[k]
    _CACHE[khoa] = g
    return g, False


@capability("kg.build")
def build(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-01 — CDS-12.2; KAD-07 §6.3. tc: "Đổi store → rebuild".

    `cached=false` nghĩa là vừa dựng lại, không phải là lỗi. Băm nội dung store đổi ⇒ dựng lại;
    băm không đổi ⇒ dùng bản cũ. `force=true` bỏ qua cache để kiểm chính cơ chế ấy.
    """
    g, tu_cache = _do_thi(ctx, force=bool(params.get("force")))
    return {"nodes": len(g.nut), "edges": len(g.canh), "cached": tu_cache}


@capability("kg.conflicts")
def conflicts(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-02 — CDS-12.2; KAD-07 §6.5. tc: TC-13, TC-21.

    Hai loại xung đột theo hợp đồng: `fact` (cùng subject+predicate, khác giá trị) và `resource`
    (một tài nguyên bị hơn một module dùng). Loại thứ hai đọc `hw_map` — bảng của mốc M2, dựng
    bởi migration `0004_m2_engineering_hw`. Trên store chưa di trú tới đó, trả về rỗng chứ KHÔNG
    im lặng bỏ qua: `resource_ready` nói rõ điều đó, để bên gọi không đọc "không có xung đột tài
    nguyên" thành "đã kiểm và sạch".
    """
    g, _ = _do_thi(ctx)
    ra = [{"type": "fact", "nodes": [a, b], "detail": _chi_tiet_mau_thuan(ctx, a, b)}
          for a, k, b in g.canh if k == "CONFLICTS_WITH"]
    with store.open_store(_store(ctx)) as c:
        co_hw_map = bool(c.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='hw_map'").fetchone())
    return {"conflicts": ra, "resource_ready": co_hw_map}


def _chi_tiet_mau_thuan(ctx: Context, a: str, b: str) -> str:
    with store.open_store(_store(ctx)) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value, tier, source_id FROM fact WHERE id IN (?, ?)",
            (a, b)).fetchall()
    d = {r[0]: r for r in rows}
    if a not in d or b not in d:
        return "một trong hai fact không còn trong store"
    ra, rb = d[a], d[b]
    return (f"{ra[1]} · {ra[2]}: {ra[3]!r} (tier {ra[4]}, nguồn {ra[5]}) "
            f"≠ {rb[3]!r} (tier {rb[4]}, nguồn {rb[5]})")


@capability("kg.impact")
def impact(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-03 — CDS-12.2. tc: TC-17.

    Lần NGƯỢC từ một fact: CodeUnit nào trích dẫn nó, Feature nào phụ thuộc CodeUnit ấy, tài
    liệu và lược đồ nào tham chiếu tới. `doc_artifact` là bảng mốc M2 nên `docs` còn rỗng;
    `diagram` đã có từ M1.
    """
    fid = params["fact_id"]
    db = _store(ctx)
    with store.open_store(db) as c:
        if not c.execute("SELECT 1 FROM fact WHERE id=?", (fid,)).fetchone():
            raise EideError("E2000", f"Không có fact {fid}", exists=[], candidates=[], missing=["fact"])
        cus = [r[0] for r in c.execute("SELECT id, cites FROM code_unit").fetchall()
               if fid in dothi._json_list(r[1])]
        # `code_unit.module_id` được thêm ở migration 0004 (mốc M2), nên ở M1 chưa có cột ấy và
        # đường fact → CodeUnit → Module → Feature chưa nối được. Hỏi schema chứ không bọc
        # try/except: một `OperationalError` bị nuốt sẽ trông y hệt "không có feature nào bị
        # ảnh hưởng", và đó là câu trả lời sai nguy hiểm nhất mà kg.impact có thể đưa ra.
        feats: list[str] = []
        if cus and _co_cot(c, "code_unit", "module_id"):
            rows = c.execute("SELECT id, module_id FROM code_unit WHERE id IN "
                             f"({','.join('?' * len(cus))})", cus).fetchall()
            if {r[1] for r in rows if r[1]}:
                feats = [r[0] for r in c.execute("SELECT id FROM feature").fetchall()]
        dias = [r[0] for r in c.execute("SELECT id, source_ref FROM diagram").fetchall()
                if r[1] and fid in str(r[1])]
    return {"stale_code_units": sorted(cus), "features": sorted(feats),
            "docs": [], "diagrams": sorted(dias)}


def _co_cot(c: sqlite3.Connection, bang: str, cot: str) -> bool:
    return any(r[1] == cot for r in c.execute(f"PRAGMA table_info({bang})").fetchall())


@capability("kg.neighborhood")
def neighborhood(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-04 — CDS-12.2. tc: "Có PB6/PB7 và BME280"."""
    g, _ = _do_thi(ctx)
    sau = int(params.get("depth") or dothi.SAU_MAC_DINH)
    if sau < 1 or sau > dothi.SAU_MAC_DINH:
        raise EideError("E1000", f"depth phải trong 1..{dothi.SAU_MAC_DINH} (KG-04 'BFS ≤ 2 bước')")
    return {"subgraph": g.lan_can(params["node"], sau=sau)}


@capability("kg.supersede")
def supersede(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-07 — CDS-12.2; KAD-07 §5.1. tc: TC-16; undo supersede_facts.

    Fact cũ chuyển `superseded` chứ KHÔNG xóa: KAD-07 §4.1 đặt bất biến "fact là bản ghi bất
    biến có nguồn", nên lịch sử phải đọc lại được — cột `supersedes` của fact mới trỏ về fact cũ
    và đó là đường truy nguyên duy nhất sau này.
    """
    old, moi, actor = params["old"], params["new"], params["actor"]
    db = _store(ctx)
    with store.open_store(db) as c:
        cu = c.execute("SELECT subject, predicate, source_id, tier, layer FROM fact WHERE id=?",
                       (old,)).fetchone()
        if cu is None:
            raise EideError("E2000", f"Không có fact {old}", exists=[], candidates=[], missing=["fact"])
        nid = "f_" + secrets.token_hex(8)
        now = datetime.now(UTC).isoformat()
        c.execute(
            "INSERT INTO fact (id, subject, predicate, value, unit, source_id, locator, method,"
            " tier, confidence, status, confirmed_by, confirmed_at, supersedes, layer)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (nid, moi.get("subject", cu[0]), moi.get("predicate", cu[1]),
             json.dumps(moi.get("value"), ensure_ascii=False), moi.get("unit"),
             moi.get("source_id", cu[2]), json.dumps(moi.get("locator")) if moi.get("locator") else None,
             moi.get("method", "manual"), moi.get("tier", cu[3]), float(moi.get("confidence", 1.0)),
             "reviewed", actor, now, old, moi.get("layer", cu[4])))
        c.execute("UPDATE fact SET status='superseded' WHERE id=?", (old,))
        c.commit()
    _quen_cache(db)
    # Bước 2 của hợp đồng là `kg.impact`, và mục đích của nó là ĐÁNH DẤU chứ không phải trả về:
    # `code_unit.stale` được DDD-14 §2 chú thích đúng hai chữ "Fact đổi". Bản đầu của tôi trả
    # kết quả impact ra ngoài và không ghi gì vào store — tức chạy đúng phép tính rồi vứt đi,
    # còn cột `stale` thì không ai đặt bao giờ.
    hq = impact({"fact_id": old}, ctx)
    if hq["stale_code_units"]:
        with store.open_store(db) as c:
            c.execute("UPDATE code_unit SET stale=1 WHERE id IN "
                      f"({','.join('?' * len(hq['stale_code_units']))})", hq["stale_code_units"])
            c.commit()
        _quen_cache(db)
    store.write_seal(db, ctx.extra.get("ledger"))
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("store.write", {"batch_id": nid, "n_facts": 1, "n_conflicts": 0,
                                   "actor": actor, "reason": params.get("reason", ""),
                                   "hash": _bam(db)})
    return {"new_id": nid}


def _bam(db: Path) -> str:
    """Băm NỘI DUNG LOGIC của store — DEV-007. `store.content_digest` nhận connection."""
    with store.open_store(db) as c:
        return store.content_digest(c)


def _quen_cache(db: Path) -> None:
    for k in [k for k in _CACHE if k[0] == str(db)]:
        del _CACHE[k]


@capability("kg.review_facts", features=["tier", "confidence", "second_source", "conflict",
                                         "method", "predicate", "range_ok"])
def review_facts(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-05 — CDS-12.2; POL-17 G-FACT. tc: S09…S17.

    `decision=policy` chạy PolicyGate cho TỪNG fact và làm đúng ba nhánh của hợp đồng. Nhánh ASK
    không tự quyết: fact ở lại `normalized` và mở một mục chờ — đó là lý do năng lực này mang
    mức T1* ("làm rồi báo cáo") chứ không phải T1.
    """
    nhom, quyet, actor = params["group"], params.get("decision", "policy"), params["actor"]
    # Như KG-06: quyền theo ngữ cảnh, tên theo tham số. Xem chú thích ở `resolve_conflict`.
    if quyet in ("accept", "reject") and ctx.actor != "human":
        raise EideError("E3000", "accept/reject là quyết định của người; tác tử dùng decision=policy",
                        rule="KG-05", gate="G-FACT")
    db = _store(ctx)
    gate = ctx.extra.get("gate")
    duyet = hoi = tu_choi = 0
    with store.open_store(db) as c:
        rows = _theo_nhom(c, nhom)
        for r in rows:
            if quyet == "accept":
                c.execute("UPDATE fact SET status='reviewed', confirmed_by=?, confirmed_at=? WHERE id=?",
                          (actor, datetime.now(UTC).isoformat(), r["id"]))
                duyet += 1
            elif quyet == "reject":
                c.execute("UPDATE fact SET status='rejected', confirmed_by=? WHERE id=?", (actor, r["id"]))
                tu_choi += 1
            else:
                d = gate.decide("G-FACT", {"fact": _dac_trung(c, r)}, risk="R1",
                                autonomy=ctx.autonomy, tier="T1*") if gate else None
                if d is None or d.decision == "APPROVE":
                    c.execute("UPDATE fact SET status='reviewed', confirmed_by='policy',"
                              " confirmed_at=? WHERE id=?", (datetime.now(UTC).isoformat(), r["id"]))
                    duyet += 1
                elif d.decision == "REJECT":
                    c.execute("UPDATE fact SET status='rejected', confirmed_by='policy' WHERE id=?", (r["id"],))
                    tu_choi += 1
                else:
                    hoi += 1        # giữ nguyên `normalized`, mở gate
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
    _quen_cache(db)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("store.write", {"batch_id": nhom, "n_facts": duyet + tu_choi, "n_conflicts": hoi,
                                   "actor": actor, "reason": f"kg.review_facts decision={quyet}",
                                   "hash": _bam(db)})
    return {"reviewed": duyet, "asked": hoi, "rejected": tu_choi}


def _theo_nhom(c: sqlite3.Connection, nhom: str) -> list[dict[str, Any]]:
    """`group` là "batch_id | subject prefix | status" — ba loại, phân biệt bằng hình dạng."""
    cot = "id, subject, predicate, value, tier, confidence, status, method, source_id"
    if nhom in ("normalized", "reviewed", "verified", "rejected", "superseded", "conflict"):
        sql, arg = f"SELECT {cot} FROM fact WHERE status=?", (nhom,)
    elif ":" in nhom or "/" in nhom:
        sql, arg = f"SELECT {cot} FROM fact WHERE subject LIKE ?", (nhom + "%",)
    else:
        sql, arg = f"SELECT {cot} FROM fact WHERE source_id=?", (nhom,)
    ten = cot.split(", ")
    return [dict(zip(ten, r, strict=True)) for r in c.execute(sql, arg).fetchall()]


def _dac_trung(c: sqlite3.Connection, r: dict[str, Any]) -> dict[str, Any]:
    """Đặc trưng mà bảng quy tắc G-FACT hỏi (POL-17 §2 cột Đặc trưng).

    `second_source` tính bằng: có fact KHÁC cùng subject+predicate, cùng giá trị, khác nguồn.
    Đó chính là nghĩa "nguồn thứ hai xác nhận" — hai nguồn độc lập nói cùng một điều.
    """
    cung = c.execute("SELECT value, source_id FROM fact WHERE subject=? AND predicate=? AND id<>?",
                     (r["subject"], r["predicate"], r["id"])).fetchall()
    return {"tier": r["tier"], "confidence": r["confidence"], "method": r["method"],
            "predicate": r["predicate"],
            "second_source": any(v == r["value"] and s != r["source_id"] for v, s in cung),
            "conflict": any(v != r["value"] for v, _ in cung),
            "range_ok": True}


@capability("kg.resolve_conflict")
def resolve_conflict(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-06 — CDS-12.2; KAD-07 §6.5. tc: TC-13 nhánh; ask: Luôn.

    `conflict_id` là cặp "<fact_a>:<fact_b>" mà `kg.conflicts` trả về. Hợp đồng ghi rõ
    "E3000 nếu actor=policy": chọn fact nào đúng là việc của người, và một tác tử tự chọn giữa
    hai fact mâu thuẫn chính là cách một sai lệch tri thức trở thành sự thật trong store.
    """
    # QUYỀN đọc từ `ctx.actor`, không từ `params["actor"]`. Hai thứ ấy khác nhau: tham số ghi
    # TÊN người chịu trách nhiệm vào store (`confirmed_by`), còn ngữ cảnh nói lời gọi này đang
    # chạy trên thẩm quyền của ai.
    #
    # Lẫn hai thứ có hậu quả đo được: một mục ASK do tác tử tạo mang `params["actor"]="agent"`;
    # khi người duyệt nó qua `gate.decide`, Router chạy lại với `ctx.actor="human"` nhưng THAM SỐ
    # vẫn là bản gốc. Kiểm theo tham số thì năng lực từ chối chính lệnh người vừa duyệt — nút
    # "duyệt" bấm xong không làm gì, đúng ở những năng lực cần người duyệt nhất.
    if ctx.actor != "human":
        raise EideError("E3000", "Giải quyết xung đột fact luôn cần người (KG-06 ask: Luôn)",
                        rule="KG-06", gate="G-FACT")
    a, _, b = params["conflict_id"].partition(":")
    if not a or not b:
        raise EideError("E1000", "conflict_id phải có dạng <fact_a>:<fact_b>")
    chon, dk = params["choice"], params.get("condition")
    db = _store(ctx)
    with store.open_store(db) as c:
        co = {r[0] for r in c.execute("SELECT id FROM fact WHERE id IN (?,?)", (a, b)).fetchall()}
        if {a, b} - co:
            raise EideError("E2000", f"Không có fact: {sorted({a, b} - co)}",
                            exists=sorted(co), candidates=[], missing=sorted({a, b} - co))
        if chon == "both_conditional":
            if not dk:
                raise EideError("E1000", "choice=both_conditional cần `condition` (ví dụ 'errata rev B')")
            for f in (a, b):
                c.execute("UPDATE fact SET status='verified', confirmed_by=? WHERE id=?",
                          (params["actor"], f))
            hien = f"{a}+{b}"
        else:
            thang, thua = (a, b) if chon == "a" else (b, a)
            c.execute("UPDATE fact SET status='verified', confirmed_by=? WHERE id=?",
                      (params["actor"], thang))
            c.execute("UPDATE fact SET status='superseded', confirmed_by=? WHERE id=?",
                      (params["actor"], thua))
            hien = thang
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
    _quen_cache(db)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("gate.human", {"gate_id": "G-FACT", "decision": "APPROVE",
                                  "by": params["actor"],
                                  "note": f"kg.resolve_conflict {params['conflict_id']} → {chon}"
                                          + (f" ({dk})" if dk else "")})
    return {"current": hien}


@capability("kg.request")
def request(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: KG-08 — CDS-12.2; DDD-14 AcquisitionRequest. tc: "Request xuất hiện trong queue"."""
    db = _store(ctx)
    rid = "acq_" + secrets.token_hex(6)
    now = datetime.now(UTC).isoformat()
    with store.open_store(db) as c:
        c.execute("INSERT INTO acq_request (id, need, subject, part, peripheral, state,"
                  " candidates, decisions, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (rid, params["need"], params.get("subject"), params.get("part"),
                   params.get("peripheral"), "REQUESTED", None, None, now, now))
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("acq.state", {"acq_id": rid, "from": None, "to": "REQUESTED", "by": "agent"})
    return {"request_id": rid}
