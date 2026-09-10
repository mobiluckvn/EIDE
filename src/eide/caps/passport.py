"""Namespace passport.* — CDS-12.2 (tập Tri thức); KAD-07 §5.1; DDD-14 §2 Fact/Passport/PassportFact.

`passport.import` là **cổng ghi duy nhất** vào bảng `fact` (SDD-04 §4.1: `PassportStore.write`
— "CỔNG GHI DUY NHẤT: kiểm schema, merge, ledger"). Mọi đường khác đưa fact vào store đều đi
vòng qua ba thứ cùng lúc: kiểm schema, quy tắc gộp theo tier, và ghi ledger. Fact vào bằng cửa
sau là fact không ai truy nguyên được.

## Bảng gộp của KAD-07 §5.1, nguyên văn ba dòng

| Tình huống | Kết quả |
|---|---|
| Cùng subject/predicate, **cùng giá trị** | Trùng lặp: giữ fact hiện hành, thêm liên kết hộ chiếu, KHÔNG tạo fact mới |
| Fact mới **tier cao hơn**, giá trị khác | Fact mới thay thế (`supersedes`); fact cũ → `superseded`; `kg.impact` liệt kê mã trích dẫn fact cũ |
| Fact mới **tier bằng hoặc thấp hơn**, giá trị khác | Fact mới `status = conflict`; cạnh `CONFLICTS_WITH`; bắt buộc người giải quyết tại G-FACT |

Cộng quy tắc R1: fact tầng vàng của hãng **không bao giờ bị ghi đè** bởi tầng thấp hơn — phát
hiện sai trong SVD thì tạo fact lớp phủ với `supersedes` trỏ về fact lõi, nguồn là errata, và
lõi giữ nguyên để tái lập.

Dòng thứ ba là dòng dễ làm sai nhất: cám dỗ là để fact mới cùng tier ghi đè fact cũ ("mới hơn
thì đúng hơn"). Nhưng hai nguồn cùng tầng nói hai điều khác nhau về CÙNG một thanh ghi thì đó
là thông tin — một trong hai sai, và im lặng chọn cái mới nghĩa là quăng mất bằng chứng rằng có
gì đó không khớp.
"""
from __future__ import annotations

import json
import secrets
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

TIER = {"bronze": 0, "silver": 1, "gold": 2}

# DDD-14 §2 Fact: enum của `predicate`. Vị từ ngoài danh sách này rơi về `other` — KHÔNG được
# ghi thẳng, vì cột có ràng buộc và vì `kg.*`/`req.ground_hw` lọc theo đúng enum ấy.
VI_TU = ("base_address", "offset", "bit_range", "reset_value", "enum", "pin_function",
         "voltage_range", "timing", "irq", "description", "net", "address", "clock",
         "memory_size", "package", "other")

# PASSPORT-02 bước 1: "< 200 ms". Ngưỡng này là hợp đồng với người dùng, không phải mong muốn:
# `passport.query` nằm trong vòng lặp của `req.ground_hw` và `arch.*`, nên chậm ở đây là chậm ở
# mọi nơi.
NGUONG_MS = 200


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not store.store_path(root).exists():
        raise EideError("E2000", "Nhóm passport.* cần một dự án có store",
                        exists=[], candidates=[], missing=["project"])
    return root


# ---------------------------------------------------------------- PASSPORT-01 import


@capability("passport.import")
def import_(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-01 — CDS-12.2; KAD-07 §5.1; SDD-04 §4.1. tc: TC-13, TC-16.

    Trả `written`/`merged`/`conflicts` riêng biệt, và ba con số ấy nói ba chuyện khác nhau:
    `merged` cao nghĩa là đang nạp lại thứ đã có (bình thường), `conflicts` cao nghĩa là hai
    nguồn đang cãi nhau (cần người). Gộp chúng thành một số "đã xử lý" sẽ giấu mất chuyện thứ
    hai — mà đó là chuyện duy nhất đáng để ai đó nhìn.
    """
    batch = params["batch"]
    actor = params["actor"]
    root = _root(ctx)
    db = store.store_path(root)

    facts = list(batch.get("facts") or [])
    if not facts:
        raise EideError("E6001", "FactBatch rỗng — không có gì để ghi", batch_id=None)
    _kiem_schema(facts)

    pid = batch.get("passport_id")
    bid = "b_" + secrets.token_hex(8)
    ghi = gop = xung_dot = 0

    with store.open_store(db) as c:
        if pid:
            _bao_dam_passport(c, pid, batch)
        for f in facts:
            kq, fid = _gop_mot(c, f, actor)
            if kq == "ghi":
                ghi += 1
            elif kq == "gop":
                gop += 1
            else:
                xung_dot += 1
            if pid:
                c.execute("INSERT OR IGNORE INTO passport_fact (passport_id, fact_id) "
                          "VALUES (?,?)", (pid, fid))
        c.commit()

    store.write_seal(db, ctx.extra.get("ledger"))
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("store.write", {"batch_id": bid, "n_facts": ghi, "n_conflicts": xung_dot,
                                   "actor": actor, "reason": batch.get("reason", ""),
                                   "hash": _bam(db)})
    return {"written": ghi, "merged": gop, "conflicts": xung_dot, "batch_id": bid}


def _kiem_schema(facts: list[dict[str, Any]]) -> None:
    """Bước 1 mở đầu bằng "Kiểm schema" — và kiểm TRƯỚC khi ghi dòng nào.

    Ghi được nửa lô rồi mới phát hiện fact thứ 300 sai `tier` sẽ để store ở trạng thái nửa vời:
    một hộ chiếu có 299 fact trông như đã nạp xong. Kiểm hết trước, rồi ghi trong một giao dịch.
    """
    loi = []
    for i, f in enumerate(facts):
        for k in ("subject", "predicate", "value", "source_id", "method", "tier"):
            if f.get(k) in (None, ""):
                loi.append(f"fact[{i}] thiếu `{k}`")
        if f.get("tier") not in TIER:
            loi.append(f"fact[{i}] tier lạ: {f.get('tier')!r}")
        if f.get("predicate") not in VI_TU:
            loi.append(f"fact[{i}] predicate ngoài enum DDD-14: {f.get('predicate')!r}")
        cf = f.get("confidence", 1.0)
        if not isinstance(cf, (int, float)) or not 0 <= cf <= 1:
            loi.append(f"fact[{i}] confidence phải trong [0,1], nhận {cf!r}")
    if loi:
        raise EideError("E6001", f"FactBatch không hợp lệ ({len(loi)} lỗi): "
                        + "; ".join(loi[:5]) + ("…" if len(loi) > 5 else ""), issues=loi)


def _gop_mot(c: Any, f: dict[str, Any], actor: str) -> tuple[str, str]:
    """Ba dòng của bảng KAD-07 §5.1. Trả (kết_quả, fact_id đang hiện hành)."""
    gt = json.dumps(f["value"], ensure_ascii=False, sort_keys=True)
    cu = c.execute(
        "SELECT id, value, tier FROM fact WHERE subject=? AND predicate=?"
        "  AND status NOT IN ('superseded','rejected')",
        (f["subject"], f["predicate"])).fetchall()

    for fid, gt_cu, _tier in cu:
        # So GIÁ TRỊ đã chuẩn hóa, không so chuỗi thô: `{"a":1,"b":2}` và `{"b":2,"a":1}` là
        # cùng một giá trị, và báo chúng mâu thuẫn sẽ đẩy người dùng đi giải quyết một xung đột
        # không tồn tại.
        if _cung_gia_tri(gt_cu, gt):
            return "gop", fid

    khac = [(fid, tier_cu) for fid, gt_cu, tier_cu in cu if not _cung_gia_tri(gt_cu, gt)]
    if not khac:
        return "ghi", _chen(c, f, "normalized", None, actor)

    cao_nhat = max(TIER.get(t, 0) for _, t in khac)
    if TIER[f["tier"]] > cao_nhat:
        # Dòng 2: tier cao hơn thì thay thế. `supersedes` trỏ về fact CŨ NHẤT trong nhóm bị thay
        # — cột ấy là đường truy nguyên, nên nó phải trỏ tới cái gì đó chứ không được để trống
        # khi thay nhiều fact cùng lúc.
        moi = _chen(c, f, "normalized", khac[0][0], actor)
        c.execute(f"UPDATE fact SET status='superseded' WHERE id IN "  # noqa: S608
                  f"({','.join('?' * len(khac))})", [x for x, _ in khac])
        return "ghi", moi
    # Dòng 3: bằng hoặc thấp hơn thì KHÔNG ghi đè — ghi vào với status conflict để người xử lý.
    return "xung_dot", _chen(c, f, "conflict", None, actor)


def _cung_gia_tri(a: str, b: str) -> bool:
    try:
        return json.dumps(json.loads(a), sort_keys=True) == json.dumps(json.loads(b), sort_keys=True)
    except (ValueError, TypeError):
        return a == b


def _chen(c: Any, f: dict[str, Any], status: str, supersedes: str | None, actor: str) -> str:
    fid = "f_" + secrets.token_hex(8)
    c.execute(
        "INSERT INTO fact (id, subject, predicate, value, unit, source_id, locator, method,"
        " tier, confidence, status, confirmed_by, confirmed_at, supersedes, layer,"
        " conflicts_with)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (fid, f["subject"], f["predicate"], json.dumps(f["value"], ensure_ascii=False),
         f.get("unit"), f["source_id"],
         json.dumps(f["locator"], ensure_ascii=False) if f.get("locator") else None,
         f["method"], f["tier"], float(f.get("confidence", 1.0)), status,
         actor if status == "verified" else None,
         datetime.now(UTC).isoformat() if status == "verified" else None,
         supersedes, f.get("layer", "C"),
         # DDD-14 §2 v1.4 (DEV-077): cạnh CONFLICTS_WITH khai được, không chỉ suy được. Cổng ghi
         # này là chỗ DUY NHẤT vào store, nên trường mới phải đi qua đây — nếu không thì không
         # năng lực trích xuất nào khai nổi một cạnh.
         json.dumps(f["conflicts_with"], ensure_ascii=False) if f.get("conflicts_with") else None))
    return fid


def _bao_dam_passport(c: Any, pid: str, batch: dict[str, Any]) -> None:
    if c.execute("SELECT 1 FROM passport WHERE id=?", (pid,)).fetchone():
        return
    c.execute("INSERT INTO passport (id, kind, header, created_at) VALUES (?,?,?,?)",
              (pid, batch.get("kind", "chip"),
               json.dumps(batch.get("header") or {"name": pid.split("@")[0]},
                          ensure_ascii=False),
               datetime.now(UTC).isoformat()))


def _bam(db: Path) -> str:
    with store.open_store(db) as c:
        return store.content_digest(c)


# ---------------------------------------------------------------- PASSPORT-02 query


@capability("passport.query")
def query(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-02 — CDS-12.2. tc: TC-15; bước 1 đòi "< 200 ms".

    `citations` là trường bắt buộc của hợp đồng, và lý do nó tách khỏi `facts` là để bên gọi
    KHÔNG phải tự nối fact với nguồn: `req.ground_hw` cần trả lời "vì sao anh nói ADC đạt
    2,4 MSPS", và câu trả lời phải kèm số hiệu tài liệu, trang, dòng.

    `latency_ms` cũng nằm trong hợp đồng. Đo và trả về chứ không im lặng: nếu nó vượt 200 ms thì
    đó là thứ cần biết trước khi năng lực này bị gọi vài trăm lần trong một vòng lặp.
    """
    t0 = time.perf_counter()
    root = _root(ctx)
    dk, tham = _dieu_kien_iri(params)

    with store.open_store(store.store_path(root)) as c:
        sql = ("SELECT f.id, f.subject, f.predicate, f.value, f.unit, f.tier, f.status,"
               "       f.method, f.confidence, f.locator, s.id, s.uri, s.kind, s.tier"
               "  FROM fact f JOIN source s ON s.id = f.source_id")
        if not params.get("include_history"):
            dk.append("f.status NOT IN ('superseded','rejected')")
        if dk:
            sql += " WHERE " + " AND ".join(dk)
        rows = c.execute(sql + " ORDER BY f.subject, f.predicate", tham).fetchall()

    facts, cit, tiers = [], {}, {"gold": 0, "silver": 0, "bronze": 0}
    for r in rows:
        facts.append({"id": r[0], "subject": r[1], "predicate": r[2],
                      "value": json.loads(r[3]), "unit": r[4], "tier": r[5],
                      "status": r[6], "method": r[7], "confidence": r[8],
                      "locator": json.loads(r[9]) if r[9] else None,
                      "source_id": r[10]})
        tiers[r[5]] = tiers.get(r[5], 0) + 1
        cit[r[10]] = {"source_id": r[10], "uri": r[11], "kind": r[12], "tier": r[13]}

    return {"facts": facts, "citations": list(cit.values()), "tiers": tiers,
            "latency_ms": int((time.perf_counter() - t0) * 1000)}


def _dieu_kien_iri(params: dict[str, Any]) -> tuple[list[str], list[Any]]:
    """Dựng điều kiện theo IRI phân cấp `chip:<part>/periph:<p>/reg:<r>/field:<f>`.

    Lọc theo TIỀN TỐ chứ không so bằng: hỏi về `periph:I2C1` phải trả cả fact của các thanh ghi
    bên trong nó. Nếu chỉ khớp đúng chuỗi thì câu hỏi "I2C1 có gì" trả về đúng một fact
    `base_address` và bỏ sót toàn bộ bản đồ thanh ghi.
    """
    dk: list[str] = []
    tham: list[Any] = []
    iri = ""
    if (part := params.get("part")):
        iri = f"chip:{part}"
        dk.append("(f.subject = ? OR f.subject LIKE ?)")
        tham += [iri, iri + "/%"]
    for khoa, ten in (("peripheral", "periph"), ("register", "reg"), ("field", "field")):
        if (v := params.get(khoa)):
            dk.append("f.subject LIKE ?")
            tham.append(f"%{ten}:{v}%")
    if (q := params.get("q")):
        # Bước 1: "Nếu q: intent nhỏ → part/periph/reg/field". Chưa có mô hình ở đây thì tra
        # thẳng bằng văn bản, KHÔNG đoán cấu trúc: đoán sai sẽ lọc mất fact đúng và người dùng
        # nhận về "không tìm thấy" cho một câu hỏi hoàn toàn hợp lệ.
        dk.append("(f.subject LIKE ? OR f.value LIKE ?)")
        tham += [f"%{q}%", f"%{q}%"]
    return dk, tham


# ---------------------------------------------------------------- PASSPORT-03 list


@capability("passport.list")
def list_(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-03 — CDS-12.2. tc: "≥ 640 sau seed"."""
    root = _root(ctx)
    dk, tham = ("WHERE kind=?", [params["kind"]]) if params.get("kind") else ("", [])
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute(
            "SELECT p.id, p.kind, p.header, p.created_at, p.badges, p.pinned_by,"
            "       (SELECT COUNT(*) FROM passport_fact pf WHERE pf.passport_id = p.id)"
            f"  FROM passport p {dk} ORDER BY p.id", tham).fetchall()  # noqa: S608
    return {"passports": [
        {"id": r[0], "kind": r[1], "header": json.loads(r[2]) if r[2] else {},
         "created_at": r[3], "badges": json.loads(r[4]) if r[4] else [],
         "pinned_by": json.loads(r[5]) if r[5] else [], "n_facts": r[6]}
        for r in rows]}


# ---------------------------------------------------------------- PASSPORT-07 export


@capability("passport.export")
def export(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-07 — CDS-12.2. tc: "Tệp nạp lại được".

    Bước 1: "Xuất fact + Source CON TRỎ (không PDF)". Nhúng cả datasheet vào bản xuất sẽ biến
    một tệp YAML vài trăm KB thành vài chục MB, và tệ hơn: nó phát tán lại tài liệu có bản
    quyền. Con trỏ (uri + sha256) đủ để người nhận tự lấy và kiểm được là đúng bản ấy.

    tc "nạp lại được" nghĩa là bản xuất phải là một FactBatch hợp lệ cho `passport.import` —
    nên nó dùng đúng tên trường ấy, không phải một định dạng riêng.
    """
    root = _root(ctx)
    pid = params["id"]
    dinh_dang = params.get("format", "yaml")
    with store.open_store(store.store_path(root)) as c:
        hp = c.execute("SELECT id, kind, header, created_at, badges FROM passport WHERE id=?",
                       (pid,)).fetchone()
        if hp is None:
            raise EideError("E2000", f"Không có hộ chiếu {pid}", exists=[], candidates=[],
                            missing=[pid])
        rows = c.execute(
            "SELECT f.subject, f.predicate, f.value, f.unit, f.source_id, f.locator, f.method,"
            "       f.tier, f.confidence, f.status"
            "  FROM fact f JOIN passport_fact pf ON pf.fact_id = f.id"
            " WHERE pf.passport_id=? AND f.status NOT IN ('superseded','rejected')"
            " ORDER BY f.subject, f.predicate", (pid,)).fetchall()
        nguon = c.execute(
            "SELECT DISTINCT s.id, s.uri, s.sha256, s.kind, s.tier, s.license"
            "  FROM source s JOIN fact f ON f.source_id = s.id"
            "  JOIN passport_fact pf ON pf.fact_id = f.id WHERE pf.passport_id=?",
            (pid,)).fetchall()

    d = {
        "passport_id": hp[0], "kind": hp[1],
        "header": json.loads(hp[2]) if hp[2] else {}, "created_at": hp[3],
        "badges": json.loads(hp[4]) if hp[4] else [],
        "sources": [{"id": s[0], "uri": s[1], "sha256": s[2], "kind": s[3],
                     "tier": s[4], "license": s[5]} for s in nguon],
        "facts": [{"subject": r[0], "predicate": r[1], "value": json.loads(r[2]),
                   "unit": r[3], "source_id": r[4],
                   "locator": json.loads(r[5]) if r[5] else None, "method": r[6],
                   "tier": r[7], "confidence": r[8], "status": r[9]} for r in rows],
    }

    from eide.caps.project import EIDE_DIR
    f = root / EIDE_DIR / "docs" / f"{pid.replace('/', '_').replace('@', '_')}.{dinh_dang}"
    f.parent.mkdir(parents=True, exist_ok=True)
    if dinh_dang == "json":
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        import yaml
        f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"file": str(f)}
