"""Namespace view.* — CDS-12.4 (tập Giao diện); UXD-13; KAD-07 §6; CXD-10 §4.5.

Chín năng lực mốc M1. Đây là **tầng trình bày**, không phải tầng tri thức: nó không sinh fact,
không sửa store, không quyết định gì. Nó chỉ trả lời câu hỏi *"cho tôi xem"* — và vì thế phần
lớn là R0, chạy được ở mọi mức tự chủ.

## Bất biến của cả nhóm: không có gì không có nguồn

Mọi thứ nhóm này trả về đều mang theo đường về nguồn. `view.kg_map` giữ `tier`/`status` cho
từng nút; `view.provenance` dựng cả chuỗi tới `Source` kèm `locator`; `view.rag_ask` **từ chối
trả lời** khi không đủ đoạn có điểm — chứ không viết một câu nghe hợp lý.

Lý do là mục đích của cả sản phẩm: EIDE tồn tại để phân biệt "biết" với "nghe có vẻ đúng". Một
màn hình đẹp mà không truy được nguồn thì đúng bằng một câu trả lời của mô hình thường — và tệ
hơn, vì trông có thẩm quyền hơn.
"""
from __future__ import annotations

import json
import secrets
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# VIEW-01: "tô màu theo tier (vàng/bạc/đồng), status (conflict đỏ, superseded xám)".
MAU_TIER = {"gold": "#D4A017", "silver": "#9AA0A6", "bronze": "#8C6239"}
MAU_STATUS = {"conflict": "#C5221F", "superseded": "#BDC1C6", "rejected": "#5F6368"}

TRAN_NUT = 50_000        # VIEW-01: "giới hạn 50.000 nút"
NGUONG_GOM = 5_000       # "gom cụm theo periph khi > 5.000"
TRAN_MERMAID = 300       # VIEW-09: "mermaid giới hạn 300 nút"

# VIEW-05: "không có chunk đủ điểm (< 0,35) → not_found và chat.decline".
NGUONG_DIEM = 0.35
K_MAC_DINH = 8


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm view.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _db(ctx: Context) -> Path:
    return store.store_path(_root(ctx))


# ---------------------------------------------------------------- VIEW-01 kg_map


@capability("view.kg_map")
def kg_map(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-01 — CDS-12.4. tc: TC-78 "< 3 s".

    Gom cụm khi quá `NGUONG_GOM` nút, KHÔNG cắt bớt. Khác biệt ấy quan trọng: cắt thì người xem
    thấy một đồ thị trông đầy đủ nhưng thiếu, và không có gì báo cho họ biết. Gom thì mỗi cụm
    ghi rõ `n` — họ thấy ngay "I2C1 (312 nút)" và bung ra được bằng `view.kg_focus`.

    Màu đi kèm dữ liệu chứ không thay dữ liệu: mỗi nút vẫn có `tier` và `status` nguyên văn.
    Trả về mã màu mà bỏ trạng thái thì giao diện phải suy ngược từ màu — và bản mù màu, bản in
    đen trắng, bản xuất `graphml` đều mất thông tin.
    """
    from eide.caps.kg import _do_thi
    g, _ = _do_thi(ctx)
    loc = params.get("filter") or {}

    thuoc_tinh = _thuoc_tinh_nut(ctx)
    nut = []
    for nid, kind in g.nut.items():
        t = thuoc_tinh.get(nid, {})
        if not _qua_loc(kind, t, loc):
            continue
        nut.append({"id": nid, "kind": kind, "label": _nhan(nid), "tier": t.get("tier"),
                    "status": t.get("status"), "layer": t.get("layer"),
                    "color": MAU_STATUS.get(t.get("status") or "") or
                             MAU_TIER.get(t.get("tier") or "", "#5F6368")})
    if len(nut) > TRAN_NUT:
        raise EideError("E5000", f"Đồ thị {len(nut)} nút vượt trần {TRAN_NUT} — hãy lọc theo "
                        "tier/status/kind trước", n_nodes=len(nut), limit=TRAN_NUT)

    gom = len(nut) > NGUONG_GOM
    if gom:
        nut, canh = _gom_theo_periph(nut, g.canh)
    else:
        co = {n["id"] for n in nut}
        canh = [{"from": a, "type": k, "to": b} for a, k, b in g.canh if a in co and b in co]
    return {"graph": {"nodes": nut, "edges": canh, "clustered": gom,
                      "legend": {"tier": MAU_TIER, "status": MAU_STATUS}}}


def _nhan(nid: str) -> str:
    """Nhãn hiển thị = đoạn cuối của IRI. `chip:st.x/periph:I2C1/reg:CR1` → `reg:CR1`."""
    return nid.rsplit("/", 1)[-1]


def _qua_loc(kind: str, t: dict[str, Any], loc: dict[str, Any]) -> bool:
    for khoa, cot in (("tier", "tier"), ("status", "status"), ("layer", "layer")):
        if (ds := loc.get(khoa)) and t.get(cot) not in ds:
            return False
    return not (loc.get("kinds") and kind not in loc["kinds"])


def _thuoc_tinh_nut(ctx: Context) -> dict[str, dict[str, Any]]:
    """`tier`/`status`/`layer` của mỗi nút. Nút fact lấy theo `subject`, nút fact-id lấy theo id.

    Đồ thị trộn hai loại nút (chủ thể IRI và id fact), nên phải tra cả hai — chỉ tra một loại
    thì một nửa đồ thị không có màu, và "không màu" trông giống "tầng đồng".
    """
    db = _db(ctx)
    if not db.exists():
        return {}
    ra: dict[str, dict[str, Any]] = {}
    with store.open_store(db) as c:
        for fid, subj, tier, st, layer in c.execute(
                "SELECT id, subject, tier, status, layer FROM fact"):
            d = {"tier": tier, "status": st, "layer": layer}
            ra[fid] = d
            # Chủ thể lấy trạng thái NẶNG NHẤT trong các fact của nó: một IRI có một fact mâu
            # thuẫn thì nút ấy phải đỏ, dù chín fact còn lại bình thường. Lấy fact cuối cùng
            # đọc được sẽ cho màu phụ thuộc thứ tự dòng — tức ngẫu nhiên.
            cu = ra.get(subj)
            if cu is None or _nang(st) > _nang(cu.get("status")):
                ra[subj] = d
    return ra


def _nang(status: str | None) -> int:
    return {"conflict": 3, "rejected": 2, "superseded": 1}.get(status or "", 0)


def _gom_theo_periph(nut: list[dict[str, Any]],
                     canh: list[tuple[str, str, str]]) -> tuple[list, list]:
    """Gom nút theo tiền tố tới `periph:`, giữ nguyên số lượng trong `n`."""
    cum: dict[str, list[dict[str, Any]]] = {}
    for n in nut:
        cum.setdefault(_tien_to_periph(n["id"]), []).append(n)
    ra = []
    for khoa, ds in sorted(cum.items()):
        if len(ds) == 1:
            ra.append(ds[0])
            continue
        nang = max(ds, key=lambda x: _nang(x.get("status")))
        ra.append({"id": khoa, "kind": "cluster", "label": f"{_nhan(khoa)} ({len(ds)})",
                   "n": len(ds), "tier": None, "status": nang.get("status"),
                   "color": nang["color"], "cluster": True})
    thuoc = {n["id"]: _tien_to_periph(n["id"]) for n in nut}
    gộp = {(thuoc.get(a, a), k, thuoc.get(b, b)) for a, k, b in canh
           if a in thuoc and b in thuoc and thuoc[a] != thuoc[b]}
    return ra, [{"from": a, "type": k, "to": b} for a, k, b in sorted(gộp)]


def _tien_to_periph(nid: str) -> str:
    i = nid.find("/reg:")
    return nid[:i] if i > 0 else nid


# ---------------------------------------------------------------- VIEW-02 kg_focus


@capability("view.kg_focus")
def kg_focus(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-02 — CDS-12.4. tc: "Có đường tới SVD và bme280.c".

    `paths_to_sources` là phần đáng giá, không phải đồ thị lân cận. Nó trả lời câu người dùng
    thật sự hỏi khi nhấp vào một nút: *"cái này ở đâu ra, và chỗ nào trong mã đang dùng nó?"*
    Một đồ thị lân cận thì họ vẫn phải tự lần từng cạnh.
    """
    from eide.caps.kg import neighborhood
    node = params["node"]
    con = neighborhood({"node": node, **({"depth": params["depth"]} if params.get("depth")
                                         else {})}, ctx)["subgraph"]
    return {"graph": con, "paths_to_sources": _duong_toi_nguon(ctx, node)}


def _duong_toi_nguon(ctx: Context, node: str) -> list[list[str]]:
    """Đường từ một nút tới `Source` (qua fact) và tới `code_unit` (qua CITES).

    Đi bằng SQL chứ không bằng đồ thị: đồ thị chỉ giữ cạnh giữa các nút tri thức, còn `source`
    và `code_unit` là bảng riêng. Dựng chúng thành nút trong đồ thị chính sẽ làm `kg.build`
    nặng lên cho một việc chỉ dùng ở đây.
    """
    db = _db(ctx)
    if not db.exists():
        return []
    ra: list[list[str]] = []
    with store.open_store(db) as c:
        fact = c.execute(
            "SELECT id, source_id FROM fact WHERE id = ? OR subject = ? OR subject LIKE ?",
            (node, node, node + "/%")).fetchall()
        for fid, sid in fact:
            if (s := c.execute("SELECT uri FROM source WHERE id=?", (sid,)).fetchone()):
                ra.append([node, fid, sid, f"uri:{s[0]}"])
        ids = {f[0] for f in fact}
        for cid, cites, path in c.execute("SELECT id, cites, path FROM code_unit").fetchall():
            try:
                dung = set(json.loads(cites or "[]"))
            except ValueError:
                continue
            if dung & ids:
                ra.append([node, next(iter(dung & ids)), cid, f"path:{path}"])
    return ra


# ---------------------------------------------------------------- VIEW-03 provenance


@capability("view.provenance")
def provenance(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-03 — CDS-12.4. tc: "Nhấp → mở đúng trang"; lỗi E2000.

    Trả CẢ chuỗi supersede, không chỉ fact hiện hành. Một fact đã bị thay thế vẫn là một phần
    của câu trả lời "vì sao ta tin con số này": nó cho biết trước đây ta tin gì, ai đổi, và dựa
    vào nguồn nào — mà đó chính là thứ người ta cần khi con số mới cũng sai.
    """
    fid = params["fact_id"]
    db = _db(ctx)
    chain: list[dict[str, Any]] = []
    with store.open_store(db) as c:
        hien_tai = fid
        da_qua: set[str] = set()
        while hien_tai and hien_tai not in da_qua:
            da_qua.add(hien_tai)
            r = c.execute(
                "SELECT f.id, f.subject, f.predicate, f.value, f.unit, f.method, f.tier,"
                "       f.status, f.confidence, f.locator, f.confirmed_by, f.confirmed_at,"
                "       f.supersedes, s.id, s.uri, s.kind, s.tier"
                "  FROM fact f LEFT JOIN source s ON s.id = f.source_id WHERE f.id = ?",
                (hien_tai,)).fetchone()
            if r is None:
                break
            loc = json.loads(r[9]) if r[9] else None
            chain.append({
                "fact_id": r[0], "subject": r[1], "predicate": r[2],
                "value": json.loads(r[3]) if r[3] else None, "unit": r[4],
                "method": r[5], "tier": r[6], "status": r[7], "confidence": r[8],
                "locator": loc,
                "source": {"id": r[13], "uri": r[14], "kind": r[15], "tier": r[16]}
                if r[13] else None,
                "snippet": _trich_doan(ctx, r[13], loc),
                "confirmed_by": r[10], "confirmed_at": r[11],
            })
            hien_tai = r[12]
    if not chain:
        raise EideError("E2000", f"Không có fact {fid}", exists=[], candidates=[], missing=[fid])
    return {"chain": chain}


def _trich_doan(ctx: Context, source_id: str | None, loc: dict[str, Any] | None) -> str | None:
    """Đoạn văn quanh `locator`, lấy từ chỉ mục RAG nếu đã lập.

    Không mở lại PDF ở đây: `view.doc_side_by_side` làm việc ấy khi người dùng thật sự nhấp
    vào. Bắt `view.provenance` mở tệp nghĩa là mỗi lần xem một chuỗi mười fact là mười lần đọc
    PDF — mà năng lực này nằm trong đường vẽ bảng, chạy liên tục.
    """
    if not source_id:
        return None
    from eide_core.rag import RagIndex
    idx = RagIndex(_root(ctx))
    if not idx.path.exists():
        return None
    with store.open_index(idx.path) as c:
        for txt, l2 in c.execute("SELECT text, locator FROM rag_chunk WHERE source_id=?",
                                 (source_id,)).fetchall():
            if loc is None or not l2:
                return txt[:400]
            if json.loads(l2).get("page") == loc.get("page"):
                return txt[:400]
    return None


# ---------------------------------------------------------------- VIEW-04 conflict_board


@capability("view.conflict_board")
def conflict_board(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-04 — CDS-12.4. tc: "Duyệt trên bảng cập nhật store".

    Mỗi hàng mang `actions` — tên năng lực gọi được, không phải nhãn nút. Giao diện tự nghĩ ra
    hành động là giao diện sẽ lệch khỏi những gì chính sách cho phép; để phía sau khai ra thì
    nút bấm và cổng luôn nói cùng một thứ.
    """
    from eide.caps.kg import conflicts
    ds = conflicts({}, ctx)["conflicts"]
    db = _db(ctx)
    rows = []
    with store.open_store(db) as c:
        for i, x in enumerate(ds, 1):
            a, b = (x.get("nodes") or [None, None])[:2]
            ra = c.execute(
                "SELECT f.id, f.subject, f.predicate, f.value, f.tier, f.status, s.uri"
                "  FROM fact f LEFT JOIN source s ON s.id = f.source_id"
                f" WHERE f.id IN ({','.join('?' * len([y for y in (a, b) if y]))})",  # noqa: S608
                [y for y in (a, b) if y]).fetchall()
            if len(ra) < 2:
                continue
            rows.append({
                "conflict_id": f"c_{i:03d}", "subject": ra[0][1], "predicate": ra[0][2],
                "a": {"fact_id": ra[0][0], "value": json.loads(ra[0][3]), "tier": ra[0][4],
                      "status": ra[0][5], "source": ra[0][6]},
                "b": {"fact_id": ra[1][0], "value": json.loads(ra[1][3]), "tier": ra[1][4],
                      "status": ra[1][5], "source": ra[1][6]},
                "tiers": [ra[0][4], ra[1][4]],
                "sources": [ra[0][6], ra[1][6]],
                "detail": x.get("detail"),
                "actions": ["kg.review_facts", "kg.supersede", "view.provenance"],
            })
    return {"rows": rows}


# ---------------------------------------------------------------- VIEW-07 rag_ask


@capability("view.rag_ask")
def rag_ask(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-07 — CDS-12.4. tc: TC-79 "≥ 90%, 100% citations"; lỗi E5002.

    Bước 1 đặt ba ràng buộc, và cả ba đều là ràng buộc về việc KHÔNG nói:

    1. **"writer trả lời CHỈ TỪ chunk"** — không được dùng thứ mô hình biết sẵn. Một câu đúng
       nhưng không có trong tài liệu vẫn là câu không kiểm được, và người dùng không phân biệt
       nổi nó với câu bịa.
    2. **"mọi câu có [n]"** — trích dẫn theo CÂU, không theo đoạn trả lời. Đặt một `[1]` ở cuối
       ba đoạn văn là hình thức: người đọc không biết câu nào đến từ đâu.
    3. **"< 0,35 → not_found"** — thà nói không biết. Đây là chỗ duy nhất trong cả sản phẩm mà
       việc trả về rỗng là kết quả ĐÚNG chứ không phải thất bại.

    Trả `trace_id` để `view.rag_trace` mở lại đúng lần truy hồi ấy. Không có nó thì "vì sao nó
    trả lời thế" chỉ tái hiện được bằng cách chạy lại và hy vọng ra cùng kết quả.
    """
    from eide_core.rag import RagIndex
    q = params["question"]
    k = int(params.get("k") or K_MAC_DINH)
    idx = RagIndex(_root(ctx))
    if not idx.path.exists():
        raise EideError("E5002", "Chưa có chỉ mục RAG — chạy `view.rag_index` trước",
                        remedy="view.rag_index")

    doan = _truy_hoi(ctx, idx, q, k, params.get("scope"))
    tid = "tr_" + secrets.token_hex(6)
    _luu_trace(ctx, tid, q, doan)

    du = [d for d in doan if d["score"] >= NGUONG_DIEM]
    if not du:
        return {"answer": "", "citations": [], "trace_id": tid, "not_found": True}

    resp = _gateway(ctx).run(
        "writer",
        "Trả lời câu hỏi CHỈ bằng thông tin trong các đoạn dưới. Mỗi câu phải kết thúc bằng "
        "chỉ số nguồn dạng [n]. Không có trong đoạn nào thì nói rõ là không có.\n\n"
        f"Câu hỏi: {q}\n\n"
        + "\n\n".join(f"[{i}] {d['text'][:1500]}" for i, d in enumerate(du, 1)),
        _SCHEMA_ANSWER)
    cau_tra_loi = (resp.data.get("answer") or "").strip()
    if not _moi_cau_co_trich_dan(cau_tra_loi):
        raise EideError("E5002", "Câu trả lời có câu không kèm trích dẫn [n] — VIEW-05 bước 1 "
                        "đòi 100% citations", answer=cau_tra_loi[:300], trace_id=tid)
    return {"answer": cau_tra_loi,
            "citations": [{"n": i, "source_id": d["source_id"], "locator": d.get("locator"),
                           "snippet": d["text"][:300], "score": d["score"]}
                          for i, d in enumerate(du, 1)],
            "trace_id": tid, "not_found": False}


_SCHEMA_ANSWER = {"type": "object", "required": ["answer"],
                  "properties": {"answer": {"type": "string"}}}


def _moi_cau_co_trich_dan(t: str) -> bool:
    """Mọi câu phải có `[n]`. Câu quá ngắn (< 12 ký tự) bỏ qua — dấu chấm trong "3.3 V" hay
    "hình 2." không phải kết câu, và chặt câu theo dấu chấm sẽ đẻ ra mảnh vụn."""
    import re as _re
    if not t:
        return False
    return all("[" in c for c in (x.strip() for x in _re.split(r"(?<=[.!?])\s+", t))
               if len(c) >= 12)


def _truy_hoi(ctx: Context, idx: Any, q: str, k: int, scope: list[str] | None) -> list[dict]:
    """Truy hồi lai: FTS5 + lan tỏa đồ thị 2 bước (CXD-10 §4.5).

    Giữ điểm TỪNG THÀNH PHẦN thay vì chỉ điểm gộp — `view.rag_trace` cần đúng thứ ấy, và tính
    lại sau là tính trên một lần truy hồi khác.
    """
    ra: dict[str, dict[str, Any]] = {}
    for d in idx.tim(q, k * 2):
        # `bm25` và `coverage` lấy NGUYÊN từ RagIndex, không tính lại: `view.rag_trace` phải
        # hiển thị đúng những con số đã quyết định thứ hạng, chứ không phải một xấp xỉ của chúng.
        ra[d["id"]] = {**d, "diem": {"bm25": d.get("bm25", d["score"]),
                                     "coverage": d.get("coverage", 0.0),
                                     "vector": 0.0, "graph": 0.0}}

    iri = _iri_lien_quan(ctx, q)
    duong: list[str] = []
    if iri:
        from eide.caps.kg import _do_thi
        g, _ = _do_thi(ctx)
        lan = set()
        for i in iri:
            if i in g.nut:
                con = g.lan_can(i, sau=2)
                lan |= {n["id"] for n in (con.get("nodes") or [])}
                duong.append(i)
        for d in idx.theo_iri(sorted(lan)[:64], k * 2):
            cu = ra.get(d["id"])
            if cu:
                cu["diem"]["graph"] = 1.0
                cu["score"] = max(cu["score"], 0.9)
            else:
                ra[d["id"]] = {**d, "diem": {"bm25": 0.0, "coverage": 0.0,
                                             "vector": 0.0, "graph": 1.0}}

    ds = list(ra.values())
    if scope:
        ds = [d for d in ds if d["source_id"] in scope or d.get("kind") in scope]
    ds.sort(key=lambda d: -d["score"])
    for d in ds:
        d["graph_path"] = duong
    return ds[:k]


def _iri_lien_quan(ctx: Context, q: str) -> list[str]:
    """IRI xuất hiện trong câu hỏi — khớp theo tên đoạn cuối, không đòi người dùng gõ IRI đầy đủ."""
    db = _db(ctx)
    if not db.exists():
        return []
    tu = {w.strip(".,;:()").upper() for w in q.split() if len(w) > 2}
    with store.open_store(db) as c:
        ds = [r[0] for r in c.execute("SELECT DISTINCT subject FROM fact")]
    return [s for s in ds if any(t in s.upper() for t in tu)][:16]


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


def _thu_muc_trace(ctx: Context) -> Path:
    d = _root(ctx) / EIDE_DIR / "cache" / "rag_trace"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _luu_trace(ctx: Context, tid: str, q: str, doan: list[dict[str, Any]]) -> None:
    (_thu_muc_trace(ctx) / f"{tid}.json").write_text(
        json.dumps({"trace_id": tid, "question": q, "chunks": doan}, ensure_ascii=False),
        encoding="utf-8")


# ---------------------------------------------------------------- VIEW-08 rag_trace


@capability("view.rag_trace")
def rag_trace(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-08 — CDS-12.4. tc: "Hiển thị đủ 3 điểm"; lỗi E2000.

    Ba điểm thành phần (`bm25`, `vector`, `graph`) chứ không phải một điểm gộp. Khi câu trả lời
    sai, người sửa cần biết đoạn ấy lọt vào vì trùng từ khóa hay vì lan tỏa đồ thị — hai nguyên
    nhân sửa bằng hai cách khác nhau: một bên là chỉnh truy vấn, một bên là sửa cạnh trong KG.
    """
    tid = params["trace_id"]
    f = _thu_muc_trace(ctx) / f"{tid}.json"
    if not f.is_file():
        raise EideError("E2000", f"Không có vết truy hồi {tid} — vết chỉ giữ trong cache dự án",
                        exists=[], candidates=[], missing=[tid])
    d = json.loads(f.read_text(encoding="utf-8"))
    ch = d.get("chunks") or []
    return {"chunks": [{"id": x["id"], "source_id": x["source_id"], "text": x["text"][:600],
                        "locator": x.get("locator"), "score": x["score"]} for x in ch],
            "scores": {x["id"]: x.get("diem", {"bm25": x["score"], "coverage": 0.0,
                                               "vector": 0.0, "graph": 0.0}) for x in ch},
            "graph_path": (ch[0].get("graph_path") if ch else []) or []}


# ---------------------------------------------------------------- VIEW-09 rag_index


DAI_CHUNK = 800 * 4      # ~800 token; xấp xỉ 4 ký tự/token cho văn bản kỹ thuật


@capability("view.rag_index")
def rag_index(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-09 — CDS-12.4. tc: TC-DD-05 "tái dựng"; lỗi E5000.

    **Tăng dần theo `source.sha256`** là điểm chính, không phải việc chunk. Lập lại chỉ mục cho
    một datasheet 900 trang tốn hàng phút và tốn tiền embedding; làm lại mỗi lần mở dự án thì
    không ai bật tính năng này lần thứ hai. Nguồn có băm không đổi thì bỏ qua — và `rebuild`
    là đường thoát tường minh khi người dùng biết có gì đó hỏng.

    Gắn IRI xuất hiện trong đoạn (`graph_nodes`) ngay lúc lập chỉ mục, không tra lúc truy vấn:
    đó là thứ cho `RagIndex.theo_iri` khớp CHÍNH XÁC thay vì đoán bằng từ khóa.
    """
    from eide_core.rag import Doan, RagIndex
    root = _root(ctx)
    idx = RagIndex(root)
    db = store.store_path(root)
    if not db.exists():
        raise EideError("E5000", "Chưa có store — chạy `eide migrate`", remedy="eide migrate")

    with store.open_store(db) as c:
        q = "SELECT id, uri, sha256, kind FROM source"
        ds = (c.execute(q + f" WHERE id IN ({','.join('?' * len(params['sources']))})",  # noqa: S608
                        params["sources"]).fetchall() if params.get("sources")
              else c.execute(q).fetchall())
        iri_co = [r[0] for r in c.execute("SELECT DISTINCT subject FROM fact")]

    da_co = _da_lap(idx)
    doan: list[Doan] = []
    trang_thai: dict[str, str] = {}
    for sid, uri, sha, kind in ds:
        if not params.get("rebuild") and da_co.get(sid) == sha:
            trang_thai[sid] = "bỏ qua (băm không đổi)"
            continue
        noi = _noi_dung(ctx, uri, kind)
        if noi is None:
            trang_thai[sid] = "không đọc được"
            continue
        idx.xoa_nguon(sid)
        for i, khuc in enumerate(_chia(noi)):
            doan.append(Doan(id=f"rc_{sha[:12]}_{i:04d}", source_id=sid, text=khuc,
                             locator={"uri": uri, "chunk": i, "sha256": sha},
                             graph_nodes=[x for x in iri_co if _ten_ngan(x) in khuc.lower()]))
        trang_thai[sid] = f"lập lại ({sum(1 for d in doan if d.source_id == sid)} đoạn)"
    n = idx.them(doan)
    _ghi_bam(idx, {sid: sha for sid, _, sha, _ in ds if trang_thai.get(sid, "").startswith("lập")})
    return {"chunks": n, "status": trang_thai}


def _ten_ngan(iri: str) -> str:
    """Tên trần của đoạn cuối IRI, bỏ tiền tố loại: `…/periph:I2C1` → `i2c1`.

    So bằng cả `periph:I2C1` là quá hẹp — không tài liệu nào viết tiền tố ấy, nên `graph_nodes`
    sẽ luôn rỗng và `theo_iri` (đường khớp CHÍNH XÁC của Graph-RAG) không bao giờ khớp gì. Lỗi
    ấy im lặng: truy hồi vẫn chạy, chỉ là mất hẳn nhánh đồ thị.
    """
    return _nhan(iri).split(":", 1)[-1].lower()


def _chia(t: str) -> list[str]:
    """Cắt ≤ 800 token, ưu tiên ranh giới đoạn rồi tới ranh giới câu — không cắt giữa câu.

    Cắt giữa câu thì đoạn trả cho `view.rag_ask` mất chủ ngữ hoặc mất con số, và mô hình trả lời
    dựa trên nửa câu ấy sẽ sai theo cách rất khó thấy.
    """
    ra: list[str] = []
    for khoi in t.split("\n\n"):
        khoi = khoi.strip()
        while len(khoi) > DAI_CHUNK:
            cat = max(khoi.rfind(". ", 0, DAI_CHUNK), khoi.rfind("\n", 0, DAI_CHUNK))
            cat = cat + 1 if cat > DAI_CHUNK // 2 else DAI_CHUNK
            ra.append(khoi[:cat].strip())
            khoi = khoi[cat:].strip()
        if khoi:
            ra.append(khoi)
    return ra


def _noi_dung(ctx: Context, uri: str, kind: str) -> str | None:
    p = Path(uri).expanduser()
    if not p.is_file():
        return None
    if kind == "pdf" or p.suffix.lower() == ".pdf":
        try:
            from eide.caps.extract import pdf_layout
            kb = pdf_layout({"file": str(p)}, ctx)["blocks"]
        except EideError:
            return None
        return "\n\n".join(str(b["content"]) for b in kb)
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None


def _bam_file(idx: Any) -> Path:
    return Path(idx.path).with_suffix(".bam.json")


def _da_lap(idx: Any) -> dict[str, str]:
    f = _bam_file(idx)
    if not f.is_file():
        return {}
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except ValueError:
        return {}


def _ghi_bam(idx: Any, moi: dict[str, str]) -> None:
    if not moi:
        return
    _bam_file(idx).write_text(json.dumps({**_da_lap(idx), **moi}, ensure_ascii=False),
                              encoding="utf-8")


# ---------------------------------------------------------------- VIEW-11 doc_side_by_side


@capability("view.doc_side_by_side")
def doc_side_by_side(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-11 — CDS-12.4. tc: "Vùng bôi sáng đúng bbox"; lỗi E2000.

    Trả `bbox` NGUYÊN VĂN từ `locator`, không quy đổi sang toạ độ màn hình. Giao diện biết tỉ lệ
    hiển thị của nó, còn năng lực này thì không — quy đổi ở đây là đoán một con số mà chỉ phía
    kia biết, và sai thì vùng bôi sáng lệch khỏi chỗ cần chỉ.
    """
    ref = params["ref"]
    db = _db(ctx)
    with store.open_store(db) as c:
        f = c.execute(
            "SELECT f.id, f.subject, f.predicate, f.value, f.unit, f.locator, f.tier,"
            "       s.id, s.uri, s.kind FROM fact f LEFT JOIN source s ON s.id = f.source_id"
            " WHERE f.id = ?", (ref,)).fetchone()
        if f:
            loc = json.loads(f[5]) if f[5] else {}
            return {"left": {"source_id": f[7], "uri": f[8], "kind": f[9],
                             "page": loc.get("page"), "bbox": loc.get("bbox"),
                             "locator": loc},
                    "right": {"kind": "fact", "fact_id": f[0], "subject": f[1],
                              "predicate": f[2],
                              "value": json.loads(f[3]) if f[3] else None,
                              "unit": f[4], "tier": f[6]}}
        cu = c.execute("SELECT id, path, symbol, cites, stale FROM code_unit WHERE id=?",
                       (ref,)).fetchone()
        if cu is None:
            raise EideError("E2000", f"`ref` phải là fact_id hoặc code_unit_id — không có {ref}",
                            exists=[], candidates=[], missing=[ref])
        cites = json.loads(cu[3] or "[]")
        trai = None
        if cites:
            r = c.execute(
                "SELECT f.locator, s.id, s.uri, s.kind FROM fact f"
                " LEFT JOIN source s ON s.id = f.source_id WHERE f.id=?", (cites[0],)).fetchone()
            if r:
                loc = json.loads(r[0]) if r[0] else {}
                trai = {"source_id": r[1], "uri": r[2], "kind": r[3],
                        "page": loc.get("page"), "bbox": loc.get("bbox"), "locator": loc}
    return {"left": trai or {"source_id": None, "uri": None, "note": "code_unit chưa trích dẫn "
                             "fact nào — chạy `code.annotate` để nối"},
            "right": {"kind": "code", "code_unit_id": cu[0], "path": cu[1], "symbol": cu[2],
                      "cites": cites, "stale": bool(cu[4])}}


# ---------------------------------------------------------------- VIEW-13 export_map


@capability("view.export_map")
def export_map(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: VIEW-13 — CDS-12.4. tc: "Mermaid render được".

    Năm định dạng, hai mục đích khác nhau. `dot`/`graphml` để công cụ khác đọc; `mermaid` để
    dán vào tài liệu. Trần 300 nút chỉ áp cho mermaid vì đó là ngưỡng nó còn vẽ ra thứ người
    nhìn được — `graphml` 50.000 nút vẫn hợp lệ, chỉ là không ai mở bằng mắt.

    `svg`/`png` cần Graphviz. Không có thì báo E4001 kèm tên gói, KHÔNG lặng lẽ trả `dot` với
    phần mở rộng `.svg` — một tệp mang đuôi sai là thứ hỏng ở chỗ khác, muộn hơn, và khó lần.
    """
    g = params["view"].get("graph") or params["view"]
    dinh_dang = params["format"]
    nut = g.get("nodes") or []
    canh = g.get("edges") or []
    if dinh_dang == "mermaid" and len(nut) > TRAN_MERMAID:
        raise EideError("E5000", f"Mermaid giới hạn {TRAN_MERMAID} nút, đồ thị có {len(nut)} — "
                        "lọc bớt hoặc xuất `graphml`", n_nodes=len(nut), limit=TRAN_MERMAID)

    d = _root(ctx) / EIDE_DIR / "diagrams"
    d.mkdir(parents=True, exist_ok=True)
    if dinh_dang in ("svg", "png"):
        return {"file": str(_graphviz(d, _dot(nut, canh), dinh_dang))}
    noi = {"dot": _dot, "graphml": _graphml, "mermaid": _mermaid}[dinh_dang](nut, canh)
    f = d / f"kg_map.{dinh_dang}"
    f.write_text(noi, encoding="utf-8")
    return {"file": str(f)}


def _ma(nid: str) -> str:
    import re as _re
    return "n_" + _re.sub(r"[^0-9A-Za-z]+", "_", nid)[:60]


def _dot(nut: list[dict], canh: list[dict]) -> str:
    d = ["digraph KG {", '  rankdir=LR; node [shape=box, style="rounded,filled"];']
    for n in nut:
        d.append(f'  {_ma(n["id"])} [label="{n.get("label", n["id"])}", '
                 f'fillcolor="{n.get("color", "#FFFFFF")}", fontcolor="#FFFFFF"];')
    for e in canh:
        d.append(f'  {_ma(e["from"])} -> {_ma(e["to"])} [label="{e.get("type", "")}"];')
    return "\n".join([*d, "}", ""])


def _graphml(nut: list[dict], canh: list[dict]) -> str:
    d = ['<?xml version="1.0" encoding="UTF-8"?>',
         '<graphml xmlns="http://graphml.graphdrawing.org/xmlns">']
    for k in ("label", "tier", "status", "kind"):
        d.append(f'  <key id="{k}" for="node" attr.name="{k}" attr.type="string"/>')
    d.append('  <key id="type" for="edge" attr.name="type" attr.type="string"/>')
    d.append('  <graph id="KG" edgedefault="directed">')
    for n in nut:
        d.append(f'    <node id="{_ma(n["id"])}">')
        for k in ("label", "tier", "status", "kind"):
            if n.get(k):
                d.append(f'      <data key="{k}">{_thoat(str(n[k]))}</data>')
        d.append("    </node>")
    for i, e in enumerate(canh):
        d.append(f'    <edge id="e{i}" source="{_ma(e["from"])}" target="{_ma(e["to"])}">'
                 f'<data key="type">{_thoat(e.get("type", ""))}</data></edge>')
    return "\n".join([*d, "  </graph>", "</graphml>", ""])


def _thoat(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;"))


def _mermaid(nut: list[dict], canh: list[dict]) -> str:
    d = ["graph LR"]
    for n in nut:
        nhan = str(n.get("label", n["id"])).replace('"', "'")
        d.append(f'  {_ma(n["id"])}["{nhan}"]')
        if n.get("color"):
            d.append(f'  style {_ma(n["id"])} fill:{n["color"]},color:#fff')
    for e in canh:
        d.append(f'  {_ma(e["from"])} -->|{e.get("type", "")}| {_ma(e["to"])}')
    return "\n".join([*d, ""])


def _graphviz(d: Path, dot: str, dinh_dang: str) -> Path:
    import subprocess

    from eide_core.tools import which
    exe = which("dot")
    if exe is None:
        raise EideError("E4001", "Xuất svg/png cần Graphviz — chạy `eide env install graphviz`",
                        tool="dot", package="graphviz", alternative="format=dot hoặc mermaid")
    src = d / "kg_map.dot"
    src.write_text(dot, encoding="utf-8")
    ra = d / f"kg_map.{dinh_dang}"
    try:
        subprocess.run([str(exe), f"-T{dinh_dang}", str(src), "-o", str(ra)],
                       capture_output=True, timeout=60, check=True)
    except (OSError, subprocess.SubprocessError) as e:
        raise EideError("E4004", f"Graphviz không dựng được {dinh_dang}: {e}") from e
    return ra
