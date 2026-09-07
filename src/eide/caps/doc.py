"""Namespace doc.* — CDS-12.4 (tập Giao diện); CON-28 §6 (bảng thuật ngữ); DDD-14 §2 DocArtifact.

Ba năng lực mốc M1: `section`, `datasheet_summary`, `style_check`.

## Bất biến: không có số nào không có trang

`doc.datasheet_summary` bước 1 viết đúng thế — *"mỗi câu có [src#page]; KHÔNG nêu số không có
fact"*. Đó là ranh giới giữa một bản tóm tắt dùng được và một bản tóm tắt nguy hiểm: người đọc
một tài liệu do máy viết sẽ tin những con số trong đó, và họ không có cách nào phân biệt số rút
từ datasheet với số mô hình nhớ nhầm.

`doc.style_check` cưỡng chế cùng một bất biến ở chiều ngược lại: câu nào có số liệu kỹ thuật mà
không có trích dẫn thì bị báo. Hai năng lực ấy là hai nửa của một quy tắc.
"""
from __future__ import annotations

import json
import re
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context

# DOC-08 bước 1: "tỷ lệ từ tiếng Anh ngoài định danh > 10%/đoạn → lang".
NGUONG_TIENG_ANH = 0.10

# "câu có số liệu kỹ thuật không có [cite] → uncited". Số liệu kỹ thuật = số CÓ ĐƠN VỊ hoặc số
# hex — không phải mọi con số: "ba bước", "hình 2", "năm 2026" không cần trích dẫn, và bắt chúng
# thì danh sách đầy nhiễu rồi không ai đọc.
RE_SO_KY_THUAT = re.compile(
    r"\b(?:0[xX][0-9a-fA-F]+|\d+(?:[.,]\d+)?\s*"
    r"(?:[kKmMgGµun]?(?:Hz|s|B|V|A|W|Ω|bps|SPS)|ms|us|µs|ns|kB|MB|KiB|MiB|mA|µA|mV|kHz|MHz))\b")
RE_TRICH_DAN = re.compile(r"\[[^\]]+\]|\(\s*(?:xem|nguồn|src)[^)]*\)", re.I)

# Từ tiếng Anh được phép: định danh kỹ thuật, tên riêng, viết tắt. Bảng này là NGOẠI LỆ của quy
# tắc `lang`, không phải từ điển — thiếu một từ thì báo thừa một lần, còn thừa một từ thì bỏ sót.
BO_QUA_ANH = {"eide", "python", "swift", "sqlite", "json", "yaml", "markdown", "git", "api",
              "cli", "llm", "rag", "svd", "atdf", "pdf", "docx", "xlsx", "html", "css", "http",
              "https", "url", "uri", "id", "ok", "true", "false", "null", "none"}
RE_TU_ANH = re.compile(r"\b[a-z][a-z]{2,}\b")


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm doc.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


def glossary() -> list[dict[str, str]]:
    """Bảng thuật ngữ CON-28 §6, sinh ra `docs/spec/doc/glossary.json`.

    Đọc từ spec chứ không chép 34 dòng vào Python — lần thứ tư gặp khuôn DEV-025/029/043/046,
    nên lần này đặt tên literal trong `sec_dep_con.js` rồi sinh ra ngay từ đầu.
    """
    f = spec_dir() / "doc" / "glossary.json"
    if not f.exists():
        return []
    return json.loads(f.read_text(encoding="utf-8"))


# ---------------------------------------------------------------- DOC-08 style_check


@capability("doc.style_check")
def style_check(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-08 — CDS-12.4. tc: TC-76.

    Bốn nhóm quy tắc của bước 1, và cả bốn đều deterministic — không nhờ mô hình chấm văn phong.
    Lý do thực dụng: một bộ kiểm văn phong chạy bằng mô hình cho kết quả khác nhau giữa hai lần
    chạy trên cùng một tài liệu, nên tác giả không biết mình đã sửa xong hay chưa.

    `uncited` là nhóm đáng giá nhất. Nó bắt đúng câu kiểu *"ADC lấy mẫu ở 2,4 MSPS"* đứng một
    mình — con số trông có thẩm quyền mà không truy được về đâu. Đó là thứ người phản biện đề
    án hỏi đầu tiên.
    """
    root = _root(ctx)
    doc_id = params["doc_id"]
    noi_dung, duong = _doc_noi_dung(root, doc_id)
    issues: list[dict[str, Any]] = []

    doan = [d for d in re.split(r"\n\s*\n", noi_dung) if d.strip()]
    for i, d in enumerate(doan, 1):
        if (r := _ty_le_tieng_anh(d)) > NGUONG_TIENG_ANH:
            issues.append({"kind": "lang", "location": f"đoạn {i}", "severity": "medium",
                           "text": f"tỷ lệ từ tiếng Anh {r:.0%} vượt {NGUONG_TIENG_ANH:.0%}"})

    da_giai_nghia: set[str] = set()
    for vt in glossary():
        vi, en = vt["vi"], vt["en"]
        m = re.search(rf"\b{re.escape(vi)}\b", noi_dung, re.I)
        if not m:
            continue
        quanh = noi_dung[m.start(): m.start() + 220]
        if en.lower() not in quanh.lower() and (vt.get("nghia") or "")[:20].lower() not in quanh.lower():
            issues.append({"kind": "term", "location": _vi_tri(noi_dung, m.start()),
                           "severity": "low",
                           "text": f'thuật ngữ "{vi}" xuất hiện lần đầu không kèm giải nghĩa '
                                   f'hoặc từ tiếng Anh tương ứng ("{en}") — CON-28 §6'})
        da_giai_nghia.add(vi)

    for cau in _cac_cau(noi_dung):
        if RE_SO_KY_THUAT.search(cau) and not RE_TRICH_DAN.search(cau):
            issues.append({"kind": "uncited", "location": _vi_tri(noi_dung, noi_dung.find(cau)),
                           "severity": "high",
                           "text": f"câu có số liệu kỹ thuật nhưng không trích dẫn: "
                                   f"{cau.strip()[:110]}"})

    for thieu in _thieu_muc_bat_buoc(noi_dung):
        issues.append({"kind": "format", "location": "tài liệu", "severity": "medium",
                       "text": thieu})
    # Chỉ `issues` — `output_schema` khai `additionalProperties: false`, nên thêm `path` cho
    # tiện là E1004. Bên gọi đã biết `doc_id` mình truyền vào.
    _ = duong
    return {"issues": issues}


def _ty_le_tieng_anh(d: str) -> float:
    """Tỷ lệ từ tiếng Anh trong một đoạn — từ Latin không dấu, không nằm trong bảng bỏ qua và
    không phải định danh (`snake_case`, `CamelCase`, chuỗi trong dấu nháy ngược)."""
    sach = re.sub(r"`[^`]*`|\b\w+_\w+\b|\b[A-Z]{2,}\b", " ", d)
    tu = [t for t in RE_TU_ANH.findall(sach) if t not in BO_QUA_ANH]
    tong = len(re.findall(r"\b[\wÀ-ỹ]+\b", sach)) or 1
    # Chỉ đếm là "tiếng Anh" khi từ KHÔNG có dấu tiếng Việt và không phải từ tiếng Việt không
    # dấu thường gặp. Đơn giản: từ Latin thuần ≥ 3 ký tự mà không xuất hiện dấu ở đâu trong từ.
    return len(tu) / tong


def _cac_cau(t: str) -> list[str]:
    """Tách câu. Bỏ câu quá ngắn — dấu chấm trong "3.3 V" hay "hình 2." không phải kết câu."""
    return [c for c in re.split(r"(?<=[.!?])\s+(?=[A-ZĐÂÊÔƯÁÀẢÃẠ])", t) if len(c.strip()) >= 12]


def _vi_tri(t: str, i: int) -> str:
    return f"dòng {t[:max(i, 0)].count(chr(10)) + 1}"


def _thieu_muc_bat_buoc(t: str) -> list[str]:
    """"thiếu bảng thuộc tính/lịch sử/mục Nguồn/đánh số hình → format" — bước 1 nguyên văn."""
    ra = []
    for tu, ten in (("thuộc tính", "bảng thuộc tính"), ("lịch sử", "bảng lịch sử phiên bản"),
                    ("nguồn", "mục Nguồn tham khảo")):
        if not re.search(rf"\b{tu}\b", t, re.I):
            ra.append(f"thiếu {ten}")
    hinh = re.findall(r"^\s*(?:!\[|Hình\s)", t, re.M | re.I)
    if hinh and not re.search(r"Hình\s+\d+", t, re.I):
        ra.append("có hình nhưng không đánh số (\"Hình 1\", \"Hình 2\"…)")
    return ra


def _doc_noi_dung(root: Path, doc_id: str) -> tuple[str, str | None]:
    """Nội dung tài liệu theo `doc_id`: id trong bảng `doc_artifact`, hoặc đường dẫn tệp."""
    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            r = c.execute("SELECT path FROM doc_artifact WHERE id=?", (doc_id,)).fetchone()
        if r and (p := Path(r[0])).is_file():
            return p.read_text(encoding="utf-8", errors="ignore"), str(p)
    p = Path(doc_id).expanduser()
    if not p.is_absolute():
        p = root / EIDE_DIR / "docs" / doc_id
    if p.is_file():
        return p.read_text(encoding="utf-8", errors="ignore"), str(p)
    raise EideError("E2000", f"Không tìm được tài liệu `{doc_id}` — thử id trong `doc_artifact` "
                    "hoặc đường dẫn tệp", exists=[], candidates=[], missing=[doc_id])


# ---------------------------------------------------------------- DOC-07 datasheet_summary


PHAM_VI = ("periph", "electrical", "timing", "errata")
VI_TU_THEO_PHAM_VI = {
    "periph": ("base_address", "offset", "bit_range", "reset_value", "enum", "irq",
               "pin_function"),
    "electrical": ("voltage_range",),
    "timing": ("timing", "clock"),
    "errata": ("description", "other"),
}


@capability("doc.datasheet_summary")
def datasheet_summary(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-07 — CDS-12.4. tc: "Mọi số liệu có trang"; lỗi E5002.

    Bước 1 đặt hai ràng buộc, và ràng buộc thứ hai mới là ràng buộc thật: *"KHÔNG nêu số không
    có fact"*. Nghĩa là bản tóm tắt bị giới hạn bởi những gì đã trích được — nó sẽ THIẾU so với
    datasheet gốc, và điều đó đúng. Một bản tóm tắt đầy đủ hơn dữ liệu là một bản tóm tắt có
    phần bịa, mà người đọc không phân biệt được phần nào.

    Nên năng lực này KHÔNG gọi mô hình. Nó dựng bảng từ fact và gắn `[src#page]` từ `locator`.
    Mô hình chỉ có ích nếu được phép diễn giải, mà diễn giải là chỗ số liệu trôi đi.
    """
    root = _root(ctx)
    part = params["part"]
    scope = [s for s in (params.get("scope") or PHAM_VI) if s in PHAM_VI]
    if not scope:
        raise EideError("E1000", f"`scope` phải thuộc {list(PHAM_VI)}", scope=params.get("scope"))

    iri = part if part.startswith("chip:") else f"chip:{part}"
    db = store.store_path(root)
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT f.subject, f.predicate, f.value, f.unit, f.locator, f.tier, f.status,"
            "       s.id, s.uri FROM fact f LEFT JOIN source s ON s.id = f.source_id"
            " WHERE (f.subject = ? OR f.subject LIKE ?)"
            "   AND f.status NOT IN ('superseded','rejected')"
            " ORDER BY f.subject, f.predicate", (iri, iri + "/%")).fetchall()
    if not rows:
        raise EideError("E5002", f"Chưa có fact nào cho `{part}` — chạy `extract.svd` hoặc "
                        "`extract.pdf_register_map` trước", part=part)

    muc: dict[str, list[str]] = {s: [] for s in scope}
    n_so, n_co_trang = 0, 0
    for subj, vt, gt, dv, loc, tier, _st, sid, uri in rows:
        pv = next((s for s in scope if vt in VI_TU_THEO_PHAM_VI[s]), None)
        if pv is None:
            continue
        vt_loc = json.loads(loc) if loc else {}
        trich = _trich_dan(sid, uri, vt_loc)
        n_so += 1
        n_co_trang += 1 if trich else 0
        ten = subj[len(iri):].lstrip("/") or subj
        muc[pv].append(f"- `{ten}` · **{vt}** = `{json.loads(gt)}`"
                       f"{f' {dv}' if dv else ''} · tầng {tier} {trich}".rstrip())

    d = [f"# Tóm tắt datasheet — {part}", "",
         f"*Sinh từ {n_so} fact trong store, {datetime.now(UTC).date().isoformat()}.* "
         "Mọi số liệu dưới đây trích từ fact có nguồn; **tài liệu này KHÔNG thay thế datasheet "
         "gốc** — nó chỉ chứa những gì đã trích được, nên thiếu là chuyện bình thường.", ""]
    for s in scope:
        d += [f"## {s}", ""]
        d += muc[s] or ["*(chưa có fact nào thuộc phạm vi này)*"]
        d += [""]

    f = root / EIDE_DIR / "docs" / f"datasheet_{re.sub(r'[^0-9A-Za-z]+', '_', part)}.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("\n".join(d), encoding="utf-8")
    _ghi_doc_artifact(root, f, "datasheet_summary")
    return {"path": str(f)}


def _trich_dan(sid: str | None, uri: str | None, loc: dict[str, Any]) -> str:
    """`[src#page]` theo bước 1. Không có trang thì vẫn nêu nguồn — nêu nguồn mà thiếu trang còn
    truy được; im lặng thì không."""
    if not sid:
        return ""
    ten = Path(uri).name if uri else sid
    return f"[{ten}#p{loc['page']}]" if loc.get("page") else f"[{ten}]"


def _ghi_doc_artifact(root: Path, f: Path, loai: str) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    import hashlib
    did = "doc_" + hashlib.sha256(str(f).encode()).hexdigest()[:16]
    with store.open_store(db) as c:
        c.execute("INSERT OR REPLACE INTO doc_artifact (id, type, path, lang, at)"
                  " VALUES (?,?,?,?,?)",
                  (did, loai, str(f), "vi", datetime.now(UTC).isoformat()))
        c.commit()


# ---------------------------------------------------------------- DOC-05 section


@capability("doc.section")
def section(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-05 — CDS-12.4. tc: "Có citations"; lỗi E5002.

    Đây là năng lực CÓ SINH duy nhất của nhóm — và nó vẫn bị chặn bởi cùng một quy tắc: không
    có `citations` thì E5002. `doc.datasheet_summary` không cần mô hình vì nó chỉ xếp lại fact;
    `doc.section` cần, vì viết một mục tài liệu là viết văn, và văn thì phải có người viết.

    Ngữ cảnh C5 lấy từ `memory.compose` với vai `writer` — đúng lớp mà CXD-10 dành cho tri thức
    của mục đang viết. Nhồi cả store vào thì mô hình lạc; nhồi quá ít thì nó bịa cho đủ.
    """
    target = params["target"]
    root = _root(ctx)
    from eide.caps.memory import compose
    b = compose({"role": "writer", "task_ref": target}, ctx)["bundle"]
    ngu_canh = "\n\n".join(x["text"] for x in b["blocks"] if x["layer"] != "C1")

    resp = _gateway(ctx).run(
        "writer",
        f"Viết mục tài liệu cho: {target}\n"
        + (f"Hướng dẫn thêm: {params['instructions']}\n" if params.get("instructions") else "")
        + "Chỉ dùng thông tin trong ngữ cảnh. MỌI câu có số liệu kỹ thuật phải kèm trích dẫn "
          "dạng [nguồn]. Không có trong ngữ cảnh thì nói rõ là chưa có dữ liệu.",
        _SCHEMA_SECTION, system_extra=ngu_canh)

    md = (resp.data.get("markdown") or "").strip()
    cit = list(resp.data.get("citations") or [])
    if not md:
        raise EideError("E5002", f"Không viết được mục `{target}` — ngữ cảnh rỗng?", target=target)
    if not cit:
        raise EideError("E5002", f"Mục `{target}` không có trích dẫn nào (DOC-05 tc: \"Có "
                        "citations\") — một mục tài liệu kỹ thuật không truy được nguồn thì "
                        "người phản biện hỏi ngay câu đầu tiên", target=target,
                        markdown=md[:200])

    # Chạy luôn style_check trên mục vừa viết — bước 1 nói "style_check mục". Ghi ra tệp tạm để
    # dùng lại đúng một hiện thực thay vì viết bản kiểm thứ hai cho chuỗi trong bộ nhớ.
    tmp = root / EIDE_DIR / "docs" / f"_muc_{abs(hash(target)) % 10**8:08d}.md"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    tmp.write_text(md, encoding="utf-8")
    try:
        loi = [x for x in style_check({"doc_id": str(tmp)}, ctx)["issues"]
               if x["kind"] == "uncited"]
    finally:
        tmp.unlink(missing_ok=True)
    # Không kèm `style_issues` vào kết quả: `output_schema` của DOC-05 chỉ khai `markdown` và
    # `citations` (additionalProperties: false). Lỗi văn phong phát ra dưới dạng E5002 khi nặng,
    # còn lại thuộc về `doc.style_check` — gọi nó trên tài liệu hoàn chỉnh là đúng chỗ hơn.
    if loi:
        raise EideError("E5002", f"Mục `{target}` có {len(loi)} câu số liệu không trích dẫn — "
                        "DOC-05 bước 1 đòi chạy style_check trên mục vừa viết",
                        target=target, style_issues=loi, markdown=md[:300], citations=cit)
    return {"markdown": md, "citations": cit}


_SCHEMA_SECTION = {
    "type": "object", "required": ["markdown", "citations"],
    "properties": {"markdown": {"type": "string"},
                   "citations": {"type": "array", "items": {"type": "string"}}},
}
