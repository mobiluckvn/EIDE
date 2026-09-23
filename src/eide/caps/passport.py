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
        _kiem_nguon(c, facts)
        if pid:
            _bao_dam_passport(c, pid, batch)
        for f in facts:
            kq, fid = _gop_mot(c, f, actor, ctx.extra.get("cap_run_id"))
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


def _kiem_nguon(c: Any, facts: list[dict[str, Any]]) -> None:
    """Mọi `source_id` phải đã có trong bảng `source` — kiểm ở đây, không để SQLite kiểm.

    `fact.source_id` có `REFERENCES source(id)`, nên nạp một lô trỏ tới nguồn chưa đăng ký sẽ
    ném `sqlite3.IntegrityError: FOREIGN KEY constraint failed` — một traceback Python trần,
    không mã lỗi, không nói nguồn nào thiếu. Đo 15/09/2026: gõ `passport.import` với
    `source_id: "trm_v1.1"` trên một store mới, người dùng nhận 20 dòng stack trace kết thúc
    bằng tên một cột SQL. Câu ấy không nói được điều DUY NHẤT họ cần biết — rằng nguồn phải
    đăng ký trước bằng `search.fetch`/`archive.*`.

    Hai điều quan trọng hơn thẩm mỹ. (a) API-15 §4 nói mọi lỗi mang mã E1000–E8002; một
    `IntegrityError` lọt ra ngoài là một lỗi KHÔNG phân loại được, nên bên gọi (daemon, giao
    diện) không có cách nào xử lý khác nhau. (b) Kiểm TRƯỚC khi ghi, đúng như `_kiem_schema` đã
    làm và vì đúng lý do ấy: FK nổ ở fact thứ 300 thì 299 fact đầu đã nằm trong giao dịch.
    """
    thieu = sorted({f["source_id"] for f in facts
                    if not c.execute("SELECT 1 FROM source WHERE id=?",
                                     (f["source_id"],)).fetchone()})
    if thieu:
        raise EideError(
            "E6001",
            f"FactBatch trỏ tới {len(thieu)} nguồn chưa đăng ký: {', '.join(thieu[:5])}"
            + ("…" if len(thieu) > 5 else "")
            + ". Nguồn phải vào store trước (search.fetch, archive.import) — fact không có "
              "nguồn thì không truy được về đâu.",
            issues=[f"source_id không có trong bảng source: {s}" for s in thieu],
            missing_sources=thieu)


def _gop_mot(c: Any, f: dict[str, Any], actor: str,
             run_id: str | None = None) -> tuple[str, str]:
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
        return "ghi", _chen(c, f, "normalized", None, actor, run_id)

    cao_nhat = max(TIER.get(t, 0) for _, t in khac)
    if TIER[f["tier"]] > cao_nhat:
        # Dòng 2: tier cao hơn thì thay thế. `supersedes` trỏ về fact CŨ NHẤT trong nhóm bị thay
        # — cột ấy là đường truy nguyên, nên nó phải trỏ tới cái gì đó chứ không được để trống
        # khi thay nhiều fact cùng lúc.
        moi = _chen(c, f, "normalized", khac[0][0], actor, run_id)
        c.execute(f"UPDATE fact SET status='superseded' WHERE id IN "  # noqa: S608
                  f"({','.join('?' * len(khac))})", [x for x, _ in khac])
        return "ghi", moi
    # Dòng 3: bằng hoặc thấp hơn thì KHÔNG ghi đè — ghi vào với status conflict để người xử lý.
    return "xung_dot", _chen(c, f, "conflict", None, actor, run_id)


def _cung_gia_tri(a: str, b: str) -> bool:
    try:
        return json.dumps(json.loads(a), sort_keys=True) == json.dumps(json.loads(b), sort_keys=True)
    except (ValueError, TypeError):
        return a == b


def _chen(c: Any, f: dict[str, Any], status: str, supersedes: str | None, actor: str,
          run_id: str | None = None) -> str:
    fid = "f_" + secrets.token_hex(8)
    c.execute(
        "INSERT INTO fact (id, subject, predicate, value, unit, source_id, locator, method,"
        " tier, confidence, status, confirmed_by, confirmed_at, supersedes, layer,"
        " conflicts_with, run_id)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
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
         json.dumps(f["conflicts_with"], ensure_ascii=False) if f.get("conflicts_with") else None,
         # [DEV-170] Lượt chạy đã tạo fact này. Cổng ghi này là chỗ DUY NHẤT vào store, nên
         # đóng dấu ở đây là đóng một lần cho mọi năng lực trích xuất.
         run_id))
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

    def _doc(x: Any) -> Any:
        """`value`/`locator` là JSON trong store — nhưng MỘT ô hỏng không được giết cả câu trả
        lời. [DEV-192]

        `json.loads` trần ném `JSONDecodeError`, và `Daemon.handle` đổi nó thành một lỗi nội bộ
        không mã: màn Hộ chiếu chip hiện "không đọc được … JSONDecodeError" và **cả bốn khối
        biến mất**. Một fact ghi sai định dạng là fact ĐÁNG SOI NHẤT trong store, và cách xử lý
        cũ giấu nó cùng với 290 fact lành.

        Trả nguyên chuỗi khi không phải JSON — đúng cách `view.conflict_board._gt` đã làm từ
        trước cho cùng cột ấy; hai chỗ đọc cùng một dữ liệu thì phải chịu được cùng một loại hư.
        """
        if x is None:
            return None
        try:
            return json.loads(x)
        except (TypeError, ValueError):
            return x

    facts, cit, tiers = [], {}, {"gold": 0, "silver": 0, "bronze": 0}
    for r in rows:
        facts.append({"id": r[0], "subject": r[1], "predicate": r[2],
                      "value": _doc(r[3]), "unit": r[4], "tier": r[5],
                      "status": r[6], "method": r[7], "confidence": r[8],
                      "locator": _doc(r[9]),
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


# ---------------------------------------------------------------- PASSPORT-04 diff


@capability("passport.diff")
def diff(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-04 — CDS-12.2; KAD-07 §5.4 (ghim phiên bản); UC-B13. R0, `undo: none`;
    lỗi E2000. tc: "Đổi 1 offset → changed 1".

    So theo **(subject, predicate)**, không so theo `fact.id`: id là danh tính của một BẢN GHI,
    còn câu hỏi ở đây là danh tính của một KHẲNG ĐỊNH. Hai lần trích cùng một thanh ghi từ hai
    bản SVD cho hai id khác nhau dù nội dung y hệt — so theo id thì mọi fact đều "added" và
    "removed", và bảng khác biệt trở thành vô dụng đúng lúc nó cần nhất.

    Chỉ đọc fact hiện hành: bản đã `superseded` ở lại store để truy nguyên, nhưng đưa vào phép
    so thì một hộ chiếu trích lại hai lần trông như đã đổi.
    """
    root = _root(ctx)
    a, b = params["a"], params["b"]
    with store.open_store(store.store_path(root)) as c:
        for pid in (a, b):
            if not c.execute("SELECT 1 FROM passport WHERE id=?", (pid,)).fetchone():
                raise EideError("E2000", f"Không có hộ chiếu `{pid}`", exists=[], candidates=[],
                                missing=[pid])
        ma = _fact_theo_khoa(c, a)
        mb = _fact_theo_khoa(c, b)

    them = [{"subject": s, "predicate": p, "value": v, "fact_id": fid}
            for (s, p), (v, fid) in sorted(mb.items()) if (s, p) not in ma]
    bot = [{"subject": s, "predicate": p, "value": v, "fact_id": fid}
           for (s, p), (v, fid) in sorted(ma.items()) if (s, p) not in mb]
    doi = [{"subject": s, "predicate": p, "old": ma[(s, p)][0], "new": v,
            "old_fact_id": ma[(s, p)][1], "new_fact_id": fid}
           for (s, p), (v, fid) in sorted(mb.items())
           if (s, p) in ma and ma[(s, p)][0] != v]
    return {"added": them, "removed": bot, "changed": doi}


def _fact_theo_khoa(c: Any, pid: str) -> dict[tuple[str, str], tuple[Any, str]]:
    rows = c.execute(
        "SELECT f.subject, f.predicate, f.value, f.id FROM fact f"
        "  JOIN passport_fact pf ON pf.fact_id = f.id"
        " WHERE pf.passport_id = ? AND f.status NOT IN ('superseded','rejected')",
        (pid,)).fetchall()
    ra: dict[tuple[str, str], tuple[Any, str]] = {}
    for subj, pred, gt, fid in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            v = gt
        ra[(subj, pred)] = (v, fid)
    return ra


# ---------------------------------------------------------------- PASSPORT-05 upgrade


@capability("passport.upgrade")
def upgrade(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-05 — CDS-12.2; KAD-07 §5.4; KG-03 `kg.impact`; UC-B13. Mức **T2**, ask
    "Luôn (ảnh hưởng mã)"; lỗi E2000; undo `restore_config`. tc: "Feature dùng fact đổi →
    failing".

    Nâng hộ chiếu là việc **làm cũ đi một phần mã đang chạy**, nên nó không bao giờ tự động —
    đó là lý do T2 chứ không phải sự thận trọng thừa.

    Một feature `passing` dựa trên hằng số vừa đổi thì nó KHÔNG còn passing; nó chỉ chưa được
    kiểm lại. Để nguyên nhãn cũ là nói dối đúng ở chỗ người ta tin nhất — bảng tiến độ. Nên
    năng lực này hạ chúng xuống `failing` và trả về danh sách để người biết phải chạy lại gì.

    `registry.pull` (mốc M4) chưa có, nên bản mới phải đã nằm trong store. Không có thì E2000
    nói thẳng kèm năng lực cần chạy, chứ không ghim một phiên bản không tồn tại.
    """
    root = _root(ctx)
    pid = params["id"]
    ten = pid.split("@", 1)[0]
    moi = f"{ten}@{params['version']}"

    with store.open_store(store.store_path(root)) as c:
        if not c.execute("SELECT 1 FROM passport WHERE id=?", (moi,)).fetchone():
            raise EideError("E2000", f"Chưa có hộ chiếu `{moi}` trong store — tải về trước "
                            "(registry.pull, mốc M4) rồi nâng",
                            exists=[r[0] for r in c.execute(
                                "SELECT id FROM passport WHERE id LIKE ?", (f"{ten}@%",))],
                            candidates=["registry.pull", "passport.import"], missing=[moi])

    kb = diff({"a": pid, "b": moi}, ctx)
    doi = [x["old_fact_id"] for x in kb["changed"]] + [x["fact_id"] for x in kb["removed"]]

    from eide.caps.kg import impact as kg_impact
    cu: list[str] = []
    for fid in doi:
        try:
            cu += kg_impact({"fact_id": fid}, ctx).get("stale_code_units") or []
        except EideError:
            continue
    cu = sorted(set(cu))

    feats = _ha_feature(root, cu)
    _ghim_moi(root, ten, params["version"])
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"upgrade:{pid}",
                                     "kind": "restore_config", "deadline": ""})
    return {"impact": {"stale_code_units": cu, "features_to_recheck": feats,
                       "changed": len(kb["changed"]), "added": len(kb["added"]),
                       "removed": len(kb["removed"]), "pinned": moi}}


def _ha_feature(root: Path, code_units: list[str]) -> list[str]:
    """Feature nào trích dẫn một CodeUnit đã cũ thì về `failing` — "cần tái kiểm", không phải
    "hỏng". Hai chữ ấy khác nhau, nhưng FEATURES.json chỉ có ba trạng thái và `failing` là cái
    duy nhất nói đúng rằng bằng chứng cũ không còn giá trị."""
    from eide.caps.project import EIDE_DIR
    f = root / EIDE_DIR / "FEATURES.json"
    if not f.exists() or not code_units:
        return []
    d = json.loads(f.read_text(encoding="utf-8"))
    doi: list[str] = []
    for x in d.get("features") or []:
        if set(x.get("evidence") or []) & set(code_units) and x.get("status") == "passing":
            x["status"] = "failing"
            x["recheck_reason"] = "hộ chiếu nâng phiên bản: fact bị trích dẫn đã đổi"
            doi.append(x.get("id"))
    if doi:
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    return doi


def _ghim_moi(root: Path, ten: str, ban: str) -> None:
    """Ghim vào `constraints.yaml`. Nâng mà không ghim thì lần mở dự án sau vẫn đọc bản cũ, và
    bảng ảnh hưởng vừa tính ra chẳng thay đổi gì."""
    import yaml

    from eide.caps.project import EIDE_DIR
    p = root / EIDE_DIR / "constraints.yaml"
    cfg = yaml.safe_load(p.read_text(encoding="utf-8")) if p.exists() else {}
    target = cfg.setdefault("target", {})
    pins = target.setdefault("pins", {})
    for k, v in list(pins.items()):
        if str(v).split("@", 1)[0] == ten:
            pins[k] = f"{ten}@{ban}"
            break
    else:
        pins["chip"] = f"{ten}@{ban}"
    p.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")


# ---------------------------------------------------------------- PASSPORT-08 resolve_address

# Khoảng cách tối đa từ địa chỉ hỏi tới `base_address` của một ngoại vi để còn coi là "thuộc
# ngoại vi ấy". 4 KiB là cỡ vùng thanh ghi của một ngoại vi trên phần lớn MCU ARM (một trang),
# và nó cũng là bước nhảy giữa hai ngoại vi liền nhau trong bản đồ bộ nhớ STM32.
#
# Không mở rộng hơn: đoán xa hơn một trang thì một địa chỉ RAM bất kỳ sẽ "thuộc về" ngoại vi
# cuối cùng trước nó, và một câu trả lời sai ở đây tệ hơn im lặng — người ta đang hover chuột
# lên một con số để tin nó.
CUA_SO_NGOAI_VI = 0x1000


@capability("passport.resolve_address")
def resolve_address(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: PASSPORT-08 — CDS-12.2. R0, `errors: []`, `undo: none`. tc: TC-40.

    Địa chỉ → tên ngoại vi/thanh ghi. Đây là năng lực NHỎ NHẤT của cả sản phẩm mà cũng đúng
    tinh thần nhất: một con số trong khung hex của GEditor hay trong tệp `.map` trả lời được câu
    *"ai nói thế, và ở trang nào"*.

    **Ba tầng tra, dừng ở tầng đầu tiên có câu trả lời.** Khớp CHÍNH XÁC một `base_address` hay
    `address` là chắc chắn; không có thì tìm ngoại vi có base GẦN NHẤT còn ở dưới địa chỉ hỏi và
    cách không quá một trang — đó là cách đọc một bản đồ bộ nhớ. Xa hơn thế thì trả rỗng.

    **Chỉ fact `reviewed`/`verified`.** Hover chuột là chỗ người ta tin ngay, không ai dừng lại
    đọc `status`. Trả một fact `normalized` ở đó là khẳng định một con số chưa ai duyệt — cùng
    lý do `code.annotate` không gợi ý chúng.

    `errors: []` nghĩa là không ném: một địa chỉ không tra được là một câu trả lời hợp lệ
    (`subject: null`), không phải một lỗi. Người ta hover lên đủ thứ.
    """
    root = _root(ctx)
    so = _so_dia_chi(params["address"])
    phan = params.get("part")

    dieu = "status IN ('reviewed','verified')"
    tham: list[Any] = []
    if phan:
        dieu += " AND (subject = ? OR subject LIKE ?)"
        tham += [str(phan), f"%{phan}%"]

    db = store.store_path(root)
    if not db.exists():
        return {"subject": None, "facts": []}
    with store.open_store(db) as c:
        rows = c.execute(
            f"SELECT id, subject, predicate, value, unit, source_id FROM fact WHERE {dieu}",
            tham).fetchall()

    khop: list[dict[str, Any]] = []
    gan: list[tuple[int, dict[str, Any]]] = []
    for fid, subj, pred, val, unit, sid in rows:
        gt = json.loads(val) if val else None
        v = _so_dia_chi(gt)
        if v is None:
            continue
        m = {"id": fid, "subject": subj, "predicate": pred, "value": gt,
             "unit": unit, "source_id": sid}
        if so is not None and v == so:
            khop.append(m)
        elif (so is not None and pred in ("base_address", "address")
              and 0 < so - v <= CUA_SO_NGOAI_VI):
            gan.append((so - v, m))

    if khop:
        return {"subject": khop[0]["subject"], "facts": khop}
    if gan:
        gan.sort(key=lambda x: x[0])
        # `offset` kèm theo để người đọc biết đây là SUY RA, không phải khớp thẳng — và biết
        # suy xa bao nhiêu. Một câu trả lời gần đúng mà không nói là gần đúng thì đọc y hệt một
        # câu trả lời chính xác.
        d, m = gan[0]
        return {"subject": m["subject"], "facts": [{**m, "offset": d, "match": "nearest_base"}]}
    return {"subject": None, "facts": []}


def _so_dia_chi(x: Any) -> int | None:
    """`"0x40005400"`, `1073763328`, `"0x40005400u"` → cùng một số. Không đọc được thì None.

    KHÔNG trả 0 khi hỏng: `0x00000000` là một địa chỉ hợp lệ (vector table trên Cortex-M), và
    lẫn nó với "không đọc được" là cách một phép tra bỏ sót đúng thứ nó canh.
    """
    if isinstance(x, bool):
        return None
    if isinstance(x, int):
        return x
    if isinstance(x, float):
        return int(x)
    s = str(x or "").strip().rstrip("uUlL")
    if not s:
        return None
    try:
        return int(s, 0)
    except ValueError:
        return None
