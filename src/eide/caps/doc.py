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

import yaml

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


# ---------------------------------------------------------------- DOC-04 datasheet_summary


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
    """Spec: DOC-04 — CDS-12.4. tc: "Mọi số liệu có trang"; lỗi E5002.

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


def _ghi_doc_artifact(root: Path, f: Path, loai: str, *, lang: str = "vi",
                      sections: list[dict[str, Any]] | None = None,
                      citations: list[str] | None = None) -> str:
    """Ghi DocArtifact và TRẢ VỀ id.

    Id băm từ ĐƯỜNG DẪN nên sinh lại cùng một tài liệu cho ra cùng một id — `doc.embed_diagram`
    và `doc.style_check` vì thế trỏ được vào nó qua nhiều lần sinh, thay vì mỗi lần một id mới
    rồi các hình đã chèn mồ côi.
    """
    import hashlib
    did = "doc_" + hashlib.sha256(str(f).encode()).hexdigest()[:16]
    db = store.store_path(root)
    if not db.exists():
        return did
    with store.open_store(db) as c:
        c.execute("INSERT OR REPLACE INTO doc_artifact"
                  " (id, type, path, lang, sections, citations, at) VALUES (?,?,?,?,?,?,?)",
                  (did, loai, str(f), lang,
                   json.dumps(sections or [], ensure_ascii=False),
                   json.dumps(citations or [], ensure_ascii=False),
                   datetime.now(UTC).isoformat()))
        c.commit()
    return did


# ---------------------------------------------------------------- DOC-02 section


@capability("doc.section")
def section(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-02 — CDS-12.4. tc: "Có citations"; lỗi E5002.

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
    # Đòi trích dẫn khi VÀ CHỈ KHI mục có nội dung kỹ thuật để trích dẫn.
    #
    # Bản đầu đòi vô điều kiện, và gọi mô hình THẬT mới lộ ra là sai: hỏi về một module chưa có
    # fact nào, mô hình trả lời "chưa có dữ liệu chi tiết trong ngữ cảnh được cung cấp" — tức
    # nó làm ĐÚNG điều ta muốn, từ chối bịa — rồi bị E5002. Một câu trung thực "không có dữ
    # liệu" thì KHÔNG THỂ có trích dẫn, và bắt nó phải có là dạy mô hình bịa cho đủ.
    #
    # Dùng lại chính `RE_SO_KY_THUAT` của `doc.style_check`: trích dẫn tồn tại để chống lưng cho
    # KHẲNG ĐỊNH, nên không khẳng định gì thì không cần chống lưng.
    if not cit and RE_SO_KY_THUAT.search(md):
        raise EideError("E5002", f"Mục `{target}` nêu số liệu kỹ thuật mà không có trích dẫn "
                        "nào (DOC-05 tc: \"Có citations\") — một mục tài liệu kỹ thuật không "
                        "truy được nguồn thì người phản biện hỏi ngay câu đầu tiên",
                        target=target, markdown=md[:200])

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


# ---------------------------------------------------------------- DOC-05 bringup_guide


@capability("doc.bringup_guide")
def bringup_guide(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-05 — CDS-12.4; BOARD-01 (hộ chiếu board); DDD-14 (`discovery`, `tool_report`,
    `error_ledger`). tc: TC-77; undo `delete_created_files`.

    Tài liệu này viết cho **người ngồi trước một board chưa từng chạy**, nên nó không được là
    một bản tóm tắt đẹp: nó phải trả lời đúng thứ tự các câu hỏi thật — cấp nguồn thế nào, cắm
    probe vào đâu, nạp bằng lệnh gì, làm sao biết đã đúng chip, xem UART ở tốc độ nào, và khi
    im lặng thì xem chỗ nào trước.

    **Không gọi mô hình.** Mọi mục đều là dữ liệu đã có trong store: hộ chiếu board cho nguồn và
    bus, manifest ISA cho probe và tốc độ nạp, `discovery` cho những gì đã dò được, `tool_report`
    cho lần nạp đầu tiên, `error_ledger` cho lỗi đã gặp. Nhờ mô hình viết lại những thứ ấy chỉ
    thêm một cơ hội để một con số bị đổi.

    Mục nào chưa có dữ liệu thì **nói là chưa có**, kèm năng lực cần chạy để có. Một hướng dẫn
    bringup nghe trôi chảy mà thiếu số thật là thứ dẫn người ta đi sai rồi mới biết.
    """
    root = _root(ctx)
    board = str(params["board"])
    from eide.caps.board import doc_net, doc_part

    nets, parts = doc_net(root, board), doc_part(root, board)
    isa = _isa_du_an(root)
    man = _manifest(isa)

    d = [f"# Hướng dẫn bringup — {board}", "",
         f"*Sinh từ store ngày {datetime.now(UTC).date().isoformat()} — {len(nets)} net, "
         f"{len(parts)} linh kiện. Mọi con số dưới đây lấy từ fact và manifest đã có; chỗ nào "
         "chưa có dữ liệu đều ghi rõ là chưa có.*", ""]
    d += _muc_nguon(nets)
    d += _muc_probe(man, isa)
    d += _muc_nap(man, isa, root)
    d += _muc_kiem_id(man, isa)
    d += _muc_uart(man, nets)
    d += _muc_loi_thuong_gap(root)

    f = root / EIDE_DIR / "docs" / f"bringup_{re.sub(r'[^0-9A-Za-z]+', '_', board)}.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("\n".join(d), encoding="utf-8")
    _ghi_doc_artifact(root, f, "bringup_guide")
    return {"path": str(f)}


def _chua_co(viec: str, nang_luc: str) -> list[str]:
    return [f"*Chưa có dữ liệu: {viec}. Chạy `{nang_luc}` để có.*", ""]


def _muc_nguon(nets: dict[str, list[dict[str, str]]]) -> list[str]:
    from eide.caps.board import RE_DAT, RE_NGUON

    d = ["## 1. Cấp nguồn", ""]
    ap = sorted(t for t in nets if RE_NGUON.match(t))
    dat = sorted(t for t in nets if RE_DAT.match(t))
    if not ap and not dat:
        return d + _chua_co("chưa biết net nguồn của board", "extract.kicad_netlist")
    if ap:
        d.append(f"- Net nguồn: {', '.join(f'`{x}`' for x in ap)}")
        d.append("  Cấp đúng mức ghi trên net trước khi cắm probe — cấp nhầm 5 V vào một net "
                 "3V3 hỏng chip trước khi có gì để gỡ.")
    if dat:
        d.append(f"- Net đất: {', '.join(f'`{x}`' for x in dat)} — nối đất chung với probe.")
    return d + [""]


def _muc_probe(man: dict[str, Any], isa: str) -> list[str]:
    d = ["## 2. Cắm probe", ""]
    dbg = (man.get("debug") or {})
    if not dbg:
        return d + _chua_co(f"manifest ISA `{isa}` không mô tả probe", "project.set_target")
    d.append(f"- Probe dùng được: {', '.join(dbg.get('probes') or []) or 'chưa nêu'}")
    if (tocdo := dbg.get("speed_khz") or {}):
        d.append(f"- Tốc độ SWD/JTAG: mặc định {tocdo.get('default')} kHz "
                 f"(khoảng {tocdo.get('min')}–{tocdo.get('max')} kHz). "
                 "Dây dài hay board nhiễu thì hạ xuống mức thấp nhất rồi nâng dần — "
                 "tốc độ quá cao biểu hiện giống hệt chip hỏng.")
    for ten, mo_ta in (CHAN_GO_LOI.get(isa) or {}).items():
        d.append(f"- `{ten}` — {mo_ta}")
    return d + [""]


# Chân gỡ lỗi cần nối, theo ISA. Lấy đúng tên trong `board.CHAN_GIU` để hai chỗ không lệch nhau:
# `board.check_pins` cảnh báo khi ai đó dùng chúng cho việc khác, còn ở đây là lý do vì sao.
CHAN_GO_LOI = {
    "armv7e-m": {"SWDIO": "dữ liệu", "SWCLK": "xung nhịp", "NRST": "reset (nên nối)",
                 "GND": "đất chung — thiếu nó thì probe đọc ra rác chứ không báo lỗi"},
}


def _muc_nap(man: dict[str, Any], isa: str, root: Path) -> list[str]:
    d = ["## 3. Nạp firmware", ""]
    fl = man.get("flash") or {}
    if fl.get("adapters"):
        d.append(f"- Bộ nạp: **{fl.get('default')}** (còn dùng được: "
                 f"{', '.join(x for x in fl['adapters'] if x != fl.get('default'))})")
        d.append(f"- Kiểm lại sau khi nạp: {'có' if fl.get('verify') else 'không'}")
    else:
        d += _chua_co(f"manifest ISA `{isa}` không nêu bộ nạp", "project.set_target")
    if (bao := _lan_nap_dau(root)):
        d.append(f"- Lần nạp gần nhất trong dự án này: `{bao['tool']}` "
                 f"{'ĐẠT' if bao['passed'] else 'KHÔNG ĐẠT'} lúc {bao['at']}")
    return d + [""]


def _lan_nap_dau(root: Path) -> dict[str, Any] | None:
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        r = c.execute("SELECT tool, passed, at FROM tool_report WHERE tool IN ('flash','build')"
                      " ORDER BY at LIMIT 1").fetchone()
    return {"tool": r[0], "passed": bool(r[1]), "at": r[2]} if r else None


def _muc_kiem_id(man: dict[str, Any], isa: str) -> list[str]:
    d = ["## 4. Kiểm đúng chip", ""]
    idr = man.get("id_read") or {}
    if not idr:
        return d + _chua_co(f"manifest ISA `{isa}` không nêu cách đọc ID", "project.set_target")
    d.append(f"- Cách đọc: `{idr.get('method')}` — `{idr.get('cmd')}`")
    if (phu := idr.get("secondary") or {}):
        d.append(f"- Đường dự phòng: đọc thanh ghi `{phu.get('name')}` tại `{phu.get('reg')}` "
                 f"(mặt nạ `{phu.get('mask')}`)")
    d.append("  ID không khớp nghĩa là **đang nạp nhầm chip** — dừng lại, đừng nạp tiếp.")
    return d + [""]


def _muc_uart(man: dict[str, Any], nets: dict[str, list[dict[str, str]]]) -> list[str]:
    d = ["## 5. Xem UART", ""]
    se = man.get("serial") or {}
    if se.get("default_baud"):
        d.append(f"- Tốc độ mặc định: **{se['default_baud']}** bps")
        if se.get("auto_baud_list"):
            d.append(f"- Không ra chữ đọc được thì thử: "
                     f"{', '.join(str(x) for x in se['auto_baud_list'])}")
    uart = sorted(t for t in nets if re.search(r"(^|[/_])(TX|RX|UART|USART)", t, re.IGNORECASE))
    if uart:
        d.append(f"- Net UART trên board: {', '.join(f'`{x}`' for x in uart)}")
    return d + [""]


def _muc_loi_thuong_gap(root: Path) -> list[str]:
    """Từ SỔ LỖI của chính dự án, không phải một danh sách chung.

    Một mục "lỗi thường gặp" chép từ Internet thì ai cũng đã đọc rồi. Cái có ích là lỗi mà DỰ ÁN
    NÀY đã gặp — nó nói đúng board này, đúng toolchain này.
    """
    d = ["## 6. Khi không chạy — xem chỗ này trước", ""]
    db = store.store_path(root)
    ds: list[tuple[Any, ...]] = []
    if db.exists():
        with store.open_store(db) as c:
            ds = c.execute("SELECT kind, negative_prompt, at FROM error_ledger"
                           " ORDER BY at DESC LIMIT 10").fetchall()
    if not ds:
        return d + ["*Sổ lỗi của dự án còn trống — mục này sẽ dày lên sau mỗi lần gỡ lỗi thật.*",
                    ""]
    for kind, nhac, at in ds:
        d.append(f"- **{kind}** ({str(at)[:10]}): {nhac or '—'}")
    return d + [""]


def _isa_du_an(root: Path) -> str:
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return str(((cu.get("target") or {}).get("isa")) or "")


def _manifest(isa: str) -> dict[str, Any]:
    f = spec_dir() / "isa" / f"{isa}.yaml"
    return (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if isa and f.exists() else {}


# ---------------------------------------------------------------- DOC-01 generate

# Mục lục chuẩn theo loại — lấy đúng các đề mục H1 của CHÍNH bộ hồ sơ EIDE (`docs/ho-so/nguon/
# {urd,srs,sad,sdd,stp,bpd}.js`), không tự nghĩ ra. Mỗi mục kèm NGUỒN TRI THỨC theo DOC-01 bước
# 1: mục nào không có nguồn thì tài liệu nói thẳng là chưa có, thay vì để mô hình viết cho đầy.
#
# Bảng này nên nằm trong `docs/spec/`, không nằm trong mã — cùng khuôn với `doc/glossary.json`
# (DEV-025/029/043/046). Xem [DEV-070].
MUC_LUC: dict[str, list[tuple[str, str]]] = {
    "URD": [("1. Giới thiệu", "-"), ("2. Bên liên quan", "-"),
            ("3. Yêu cầu người dùng", "req:UR"), ("4. Yêu cầu chất lượng", "req:NFR"),
            ("5. Ràng buộc", "constraints"), ("6. Ma trận truy vết UR → FR", "trace")],
    "SRS": [("1. Giới thiệu", "-"), ("2. Mô tả tổng quan", "constraints"),
            ("3. Yêu cầu chức năng", "req:FR"), ("4. Yêu cầu phi chức năng", "req:NFR"),
            ("5. Yêu cầu giao diện ngoài", "hw_map"),
            ("6. Tiêu chí nghiệm thu tổng quát", "acceptance"),
            ("7. Ma trận truy vết UR → FR", "trace")],
    "SAD": [("1. Giới thiệu và nguyên tắc kiến trúc", "-"), ("2. Góc nhìn ngữ cảnh", "constraints"),
            ("3. Góc nhìn thành phần", "module"), ("4. Góc nhìn hành vi", "fsm"),
            ("5. Góc nhìn dữ liệu", "fact"), ("6. Góc nhìn triển khai", "-"),
            ("7. Quyết định kiến trúc (ADR)", "adr")],
    "SDD": [("1. Giới thiệu", "-"), ("2. Cấu trúc kho mã", "code_unit"),
            ("3. Thiết kế dữ liệu", "fact"), ("4. Giao diện mô-đun", "module"),
            ("5. Tệp cấu hình", "constraints"), ("6. Ánh xạ phần cứng", "hw_map")],
    "STP": [("1. Giới thiệu", "-"), ("2. Chiến lược và môi trường", "constraints"),
            ("3. Test case", "acceptance"), ("4. Kết quả chạy", "tool_report"),
            ("5. Tiêu chí nghiệm thu", "trace")],
    "BPD": [("1. Giới thiệu", "-"), ("2. Quy ước", "-"), ("3. Luồng nghiệp vụ", "module")],
    "custom": [("1. Nội dung", "fact")],
}

# Mục nào là BẮT BUỘC phải có dữ liệu. `ask_when` của DOC-01 là "Thiếu fact bắt buộc" — một
# SRS không có yêu cầu chức năng nào không phải là một SRS mỏng, nó là một SRS rỗng, và sinh ra
# nó rồi nộp đi là cách tệ nhất để phát hiện chuyện ấy.
BAT_BUOC = {"URD": ("req:UR",), "SRS": ("req:FR",), "SAD": ("module",), "SDD": ("module",),
            "STP": ("acceptance",), "BPD": (), "custom": ()}

# Loại tài liệu có năng lực riêng — DOC-01 liệt kê chúng trong enum `type`, nhưng nội dung thì
# đã có chỗ khác lo. Sinh lại lần thứ hai ở đây là hai bản tài liệu cùng tên khác nội dung.
UY_QUYEN = {"bringup": "doc.bringup_guide", "test_report": "doc.test_report"}


@capability("doc.generate")
def generate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-01 — CDS-12.4; CON-28 §6 (thuật ngữ); DDD-14 §2 DocArtifact. tc: TC-75;
    lỗi E5002, ask "Thiếu fact bắt buộc"; undo `delete_created_files`.

    **Bảng số liệu do MÃ dựng, văn xuôi do MÔ HÌNH viết** — và ranh giới ấy là toàn bộ thiết kế
    của năng lực này. Mỗi mục lấy dữ liệu từ đúng một nguồn tri thức (ReqSet, ModuleGraph,
    HwMap, ADR, fact, ToolReport), dựng thành bảng kèm trích dẫn bằng mã; mô hình chỉ viết phần
    diễn giải quanh bảng. Để mô hình viết cả bảng thì một con số sẽ đổi, và không ai đối chiếu
    lại một tài liệu 40 trang.

    Mục **không có dữ liệu thì nói là chưa có**, kèm năng lực cần chạy — không nhờ mô hình viết
    cho đầy. Một tài liệu đầy đủ hơn dữ liệu là một tài liệu có phần bịa, mà người đọc không
    phân biệt được phần nào. Riêng mục BẮT BUỘC thiếu thì dừng hẳn bằng E3000: một SRS không có
    yêu cầu chức năng nào không phải SRS mỏng, nó là SRS rỗng.

    **Đầu ra là Markdown, không phải docx.** Hợp đồng DOC-01 bước 2 nói "dựng docx qua mẫu",
    nhưng REPORT-02 `report.export` lại khai `docx/pdf/md` và bước 1 của nó là "doc.generate với
    mẫu báo cáo" — tức chuyển định dạng nằm ở REPORT-02, còn DOC-01 lo NỘI DUNG. Làm docx ở cả
    hai chỗ là hai bản dựng cùng một tài liệu. Xem [DEV-070]; `E4001 thiếu node/docx` vì thế
    thuộc đường `report.export`.
    """
    root = _root(ctx)
    loai = params["type"]
    if (uy := UY_QUYEN.get(loai)):
        raise EideError("E2000", f"Tài liệu `{loai}` do `{uy}` sinh — gọi thẳng năng lực ấy. "
                        "Sinh lại ở đây là hai bản cùng tên khác nội dung.",
                        exists=[], candidates=[uy], missing=[uy])

    muc_luc = MUC_LUC.get(loai) or MUC_LUC["custom"]
    lang = params.get("lang") or "vi"
    pham_vi = params.get("scope")

    du_lieu = {khoa: _nguon_tri_thuc(root, khoa, pham_vi) for _, khoa in muc_luc}
    for khoa in BAT_BUOC.get(loai, ()):
        if not (du_lieu.get(khoa) or {}).get("rows"):
            raise EideError("E3000", f"`{loai}` đòi mục `{khoa}` nhưng chưa có dữ liệu nào — "
                            f"chạy `{(du_lieu.get(khoa) or {}).get('remedy', '?')}` trước, hoặc "
                            "xác nhận vẫn muốn sinh một tài liệu rỗng",
                            gate="*", rule="DOC-01", missing=[khoa])

    ten_da = _ten_du_an(root)
    d = [f"# {loai} — {ten_da}", "",
         *_thuoc_tinh(loai, ten_da, lang), "", "## Lịch sử sửa đổi", "",
         "| Bản | Ngày | Người | Thay đổi |", "|---|---|---|---|",
         f"| 1.0 | {datetime.now(UTC).date().isoformat()} | EIDE `doc.generate` | "
         "Sinh lần đầu từ tri thức dự án |", ""]

    sections: list[dict[str, Any]] = []
    trich_dan: list[str] = []
    for tieu_de, khoa in muc_luc:
        than, cits = _than_muc(ctx, root, loai, tieu_de, khoa, du_lieu.get(khoa) or {})
        d += [f"## {tieu_de}", "", *than, ""]
        trich_dan += cits
        sections.append({"heading": tieu_de, "source": khoa,
                         "hash": _bam_muc(than), "citations": cits})

    d += _muc_nguon_tham_khao(root, trich_dan)

    f = root / EIDE_DIR / "docs" / f"{loai}_{re.sub(r'[^0-9A-Za-z]+', '_', ten_da)}.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("\n".join(d), encoding="utf-8")

    did = _ghi_doc_artifact(root, f, loai, lang=lang, sections=sections,
                            citations=sorted(set(trich_dan)))
    issues = style_check({"doc_id": did}, ctx)["issues"]
    _cap_nhat_style_issues(root, did, issues)
    return {"doc_id": did, "path": str(f), "style_issues": len(issues)}


def _ten_du_an(root: Path) -> str:
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return str((cu.get("project") or {}).get("name") or root.name)


def _thuoc_tinh(loai: str, ten: str, lang: str) -> list[str]:
    """Bảng thuộc tính đầu tài liệu — bước 2 đòi "thuộc tính, lịch sử, mục Nguồn"."""
    return ["| Thuộc tính | Giá trị |", "|---|---|",
            f"| Loại | {loai} |", f"| Dự án | {ten} |", f"| Ngôn ngữ | {lang} |",
            f"| Sinh lúc | {datetime.now(UTC).isoformat(timespec='seconds')} |",
            "| Sinh bởi | EIDE `doc.generate` — bảng số liệu dựng từ store, văn xuôi do mô "
            "hình viết quanh bảng |"]


def _bam_muc(than: list[str]) -> str:
    import hashlib
    return hashlib.sha256("\n".join(than).encode("utf-8")).hexdigest()[:16]


# ---- nguồn tri thức: mỗi mục lấy dữ liệu từ ĐÚNG MỘT bảng, và dựng bảng bằng mã


def _nguon_tri_thuc(root: Path, khoa: str, pham_vi: str | None) -> dict[str, Any]:
    """`{rows, header, citations, remedy}` cho một khóa nguồn. `rows` rỗng = chưa có dữ liệu."""
    if khoa == "-":
        return {"rows": [], "header": [], "citations": [], "remedy": ""}
    ham = _NGUON.get(khoa.split(":", 1)[0])
    if ham is None:
        return {"rows": [], "header": [], "citations": [], "remedy": ""}
    return ham(root, khoa.split(":", 1)[1] if ":" in khoa else "", pham_vi)


def _q(root: Path, sql: str, args: tuple = ()) -> list[tuple]:
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        try:
            return c.execute(sql, args).fetchall()
        except Exception:                       # noqa: BLE001 — bảng chưa có ở store cũ
            return []


def _n_req(root: Path, loai: str, _pv: str | None) -> dict[str, Any]:
    dk, args = ("kind LIKE ?", (f"{loai}%",)) if loai else ("1=1", ())
    rows = _q(root, f"SELECT id, kind, text, priority, acceptance, source FROM requirement"  # noqa: S608
                    f" WHERE {dk} ORDER BY id", args)
    return {"header": ["Mã", "Loại", "Nội dung", "Ưu tiên", "Nguồn"],
            "rows": [[r[0], r[1], r[2], r[3] or "—", r[5] or "—"] for r in rows],
            "citations": [str(r[5]) for r in rows if r[5]],
            "remedy": "req.elicit rồi req.classify"}


def _n_module(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT id, name, responsibility, depends, status FROM module ORDER BY id")
    return {"header": ["Id", "Tên", "Trách nhiệm", "Phụ thuộc", "Trạng thái"],
            "rows": [[r[0], r[1], r[2] or "—", ", ".join(json.loads(r[3] or "[]")) or "—",
                      r[4] or "—"] for r in rows],
            "citations": [], "remedy": "arch.decompose"}


def _n_fsm(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    # `_ghi_module` ghi `fsm` bằng `json.dumps(None)` = chuỗi `"null"`, không phải NULL của SQL
    # — nên `WHERE fsm IS NOT NULL` cho qua rồi `json.loads` trả None. Lọc sau khi giải mã.
    rows = _q(root, "SELECT id, name, fsm FROM module WHERE fsm IS NOT NULL ORDER BY id")
    ra = []
    for mid, ten, fsm in rows:
        if not isinstance(d := json.loads(fsm), dict):
            continue
        ra.append([mid, ten, ", ".join(d.get("states") or []),
                   str(d.get("initial") or "—"), str(len(d.get("transitions") or []))])
    return {"header": ["Module", "Tên", "Trạng thái", "Khởi đầu", "Số chuyển"],
            "rows": ra, "citations": [], "remedy": "arch.state_machine"}


def _n_hw_map(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT module_id, resource, role, fact_ids FROM hw_map ORDER BY module_id")
    cits: list[str] = []
    for r in rows:
        cits += list(json.loads(r[3] or "[]"))
    return {"header": ["Module", "Tài nguyên", "Vai", "Fact"],
            "rows": [[r[0], r[1], r[2] or "—", ", ".join(json.loads(r[3] or "[]")) or "—"]
                     for r in rows],
            "citations": cits, "remedy": "arch.map_hw"}


def _n_adr(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT id, title, decision, consequences, status, citations FROM adr"
                    " ORDER BY id")
    cits: list[str] = []
    for r in rows:
        cits += list(json.loads(r[5] or "[]"))
    return {"header": ["Mã", "Tiêu đề", "Quyết định", "Hệ quả", "Trạng thái"],
            "rows": [[r[0], r[1], r[2] or "—", r[3] or "—", r[4] or "—"] for r in rows],
            "citations": cits, "remedy": "arch.adr"}


def _n_fact(root: Path, _l: str, pham_vi: str | None) -> dict[str, Any]:
    dk, args = (("subject LIKE ?", (f"%{pham_vi}%",)) if pham_vi else ("1=1", ()))
    rows = _q(root, "SELECT f.id, f.subject, f.predicate, f.value, f.unit, f.tier, s.uri"
                    "  FROM fact f LEFT JOIN source s ON s.id=f.source_id"
                    f" WHERE {dk} AND f.status NOT IN ('superseded','rejected')"  # noqa: S608
                    " ORDER BY f.subject, f.predicate LIMIT 200", args)
    return {"header": ["Chủ thể", "Vị từ", "Giá trị", "Tầng", "Nguồn"],
            "rows": [[r[1], r[2], f"`{json.loads(r[3])}`{f' {r[4]}' if r[4] else ''}", r[5],
                      Path(r[6]).name if r[6] else "—"] for r in rows],
            "citations": [str(r[0]) for r in rows], "remedy": "extract.* rồi kg.review_facts"}


def _n_code_unit(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT path, symbol, cites, stale FROM code_unit ORDER BY path")
    cits: list[str] = []
    for r in rows:
        cits += list(json.loads(r[2] or "[]"))
    return {"header": ["Tệp", "Ký hiệu", "Trích dẫn fact", "Cũ?"],
            "rows": [[r[0], r[1] or "—", ", ".join(json.loads(r[2] or "[]")) or "—",
                      "có" if r[3] else "không"] for r in rows],
            "citations": cits, "remedy": "code.generate_module"}


def _n_tool_report(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT tool, passed, metrics, at FROM tool_report ORDER BY at DESC LIMIT 50")
    return {"header": ["Công cụ", "Kết quả", "Số đo", "Lúc"],
            "rows": [[r[0], "ĐẠT" if r[1] else "KHÔNG ĐẠT",
                      json.dumps(json.loads(r[2] or "{}"), ensure_ascii=False)[:80], str(r[3])[:19]]
                     for r in rows],
            "citations": [], "remedy": "code.build rồi code.test_host"}


def _n_acceptance(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT id, text, acceptance FROM requirement"
                    " WHERE acceptance IS NOT NULL AND acceptance != '' ORDER BY id")
    ra = []
    for rid, txt, acc in rows:
        try:
            ds = json.loads(acc)
        except (json.JSONDecodeError, TypeError):
            ds = [acc]
        ra.append([rid, txt[:60], " · ".join(str(x) for x in (ds if isinstance(ds, list) else [ds]))])
    return {"header": ["Yêu cầu", "Nội dung", "Tiêu chí nghiệm thu"], "rows": ra,
            "citations": [], "remedy": "req.acceptance"}


def _n_trace(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    rows = _q(root, "SELECT id, kind, trace FROM requirement WHERE trace IS NOT NULL"
                    "   AND trace != '' ORDER BY id")
    ra = []
    for rid, kind, tr in rows:
        try:
            ds = json.loads(tr)
        except (json.JSONDecodeError, TypeError):
            ds = [tr]
        ra.append([rid, kind, ", ".join(str(x) for x in (ds if isinstance(ds, list) else [ds]))])
    return {"header": ["Yêu cầu", "Loại", "Truy vết tới"], "rows": ra,
            "citations": [], "remedy": "req.trace_matrix"}


def _n_constraints(root: Path, _l: str, _pv: str | None) -> dict[str, Any]:
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    ra = []
    for nhom in ("target", "board"):
        for k, v in (cu.get(nhom) or {}).items():
            ra.append([nhom, str(k), json.dumps(v, ensure_ascii=False)[:120]
                       if isinstance(v, (dict, list)) else str(v)])
    return {"header": ["Nhóm", "Khóa", "Giá trị"], "rows": ra, "citations": [],
            "remedy": "project.set_target rồi board.constraints"}


_NGUON = {"req": _n_req, "module": _n_module, "fsm": _n_fsm, "hw_map": _n_hw_map, "adr": _n_adr,
          "fact": _n_fact, "code_unit": _n_code_unit, "tool_report": _n_tool_report,
          "acceptance": _n_acceptance, "trace": _n_trace, "constraints": _n_constraints}


def _bang(header: list[str], rows: list[list[str]]) -> list[str]:
    if not rows:
        return []
    return ["| " + " | ".join(header) + " |",
            "|" + "|".join("---" for _ in header) + "|",
            *["| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |" for r in rows]]


def _than_muc(ctx: Context, root: Path, loai: str, tieu_de: str, khoa: str,
              dl: dict[str, Any]) -> tuple[list[str], list[str]]:
    """Thân một mục: bảng số liệu dựng bằng mã, văn xuôi do mô hình viết QUANH bảng.

    Không có dữ liệu thì nói thẳng, kèm năng lực cần chạy — và **không gọi mô hình**. Nhờ mô
    hình viết một mục không có dữ liệu là dạy nó bịa, rồi phần bịa ấy nằm cạnh phần có thật
    trong cùng một tài liệu và không ai phân biệt được nữa.
    """
    rows = dl.get("rows") or []
    if khoa == "-":
        return _van_xuoi(ctx, loai, tieu_de, ""), []
    if not rows:
        return ([f"*Chưa có dữ liệu cho mục này (nguồn: `{khoa}`). "
                 f"Chạy `{dl.get('remedy') or '?'}` để có.*"], [])
    bang = _bang(list(dl.get("header") or []), rows)
    van = _van_xuoi(ctx, loai, tieu_de, "\n".join(bang[:40]))
    return [*van, "", *bang], list(dl.get("citations") or [])


def _van_xuoi(ctx: Context, loai: str, tieu_de: str, bang: str) -> list[str]:
    """Một đoạn diễn giải cho mục, do vai `writer` viết (PRS-16).

    Mô hình KHÔNG được viết lại con số: nó chỉ diễn giải bảng đã dựng. Đó là lý do bảng được
    truyền vào như ngữ cảnh chứ không phải như một yêu cầu "hãy liệt kê".
    """
    resp = _gateway(ctx).run(
        "writer",
        f"Viết một đoạn ngắn (3–5 câu, tiếng Việt) mở đầu cho mục \"{tieu_de}\" của tài liệu "
        f"{loai}.\n"
        + ("Bảng số liệu của mục đã được dựng sẵn ngay dưới đoạn văn — hãy diễn giải nó, "
           "TUYỆT ĐỐI không nhắc lại hay sửa bất kỳ con số nào trong bảng.\n" if bang else
           "Mục này không có bảng số liệu; viết phần dẫn nhập, không nêu số liệu kỹ thuật nào.\n")
        + "Không bịa dữ liệu không có trong ngữ cảnh.",
        _SCHEMA_SECTION, system_extra=bang)
    return [(resp.data.get("markdown") or "").strip()]


def _muc_nguon_tham_khao(root: Path, trich_dan: list[str]) -> list[str]:
    """Mục "Nguồn" (tài liệu tham khảo) — bước 2 đòi nó, và nó là mục người phản biện đọc
    đầu tiên.

    Tên hàm nói rõ "tham khảo" vì trong cùng tệp này `_muc_nguon` đã mang nghĩa **cấp nguồn
    điện** cho `doc.bringup_guide`. Hai nghĩa của một từ, hai mục hoàn toàn khác nhau — bản đầu
    đặt trùng tên và định nghĩa sau che định nghĩa trước, làm hỏng cả ba test của bringup guide
    mà không có gì báo ở chỗ vừa sửa."""
    ids = sorted(set(x for x in trich_dan if x))
    d = ["## Nguồn", ""]
    if not ids:
        return d + ["*Tài liệu này chưa trích dẫn nguồn nào — mọi mục đều đang thiếu dữ liệu.*", ""]
    rows = _q(root, "SELECT DISTINCT s.id, s.uri, s.tier, s.license FROM fact f"
                    "  JOIN source s ON s.id = f.source_id"
                    f" WHERE f.id IN ({','.join('?' * len(ids))})", tuple(ids))  # noqa: S608
    if not rows:
        return d + [f"- {len(ids)} trích dẫn, chưa tra ngược được về `source` nào", ""]
    return d + _bang(["Nguồn", "URI", "Tầng", "License"],
                     [[r[0], r[1] or "—", r[2] or "—", r[3] or "—"] for r in rows]) + [""]


def _cap_nhat_style_issues(root: Path, did: str, issues: list[dict[str, Any]]) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        c.execute("UPDATE doc_artifact SET style_issues=? WHERE id=?",
                  (json.dumps(issues, ensure_ascii=False), did))
        c.commit()


# ---------------------------------------------------------------- DOC-07 embed_diagram

RE_HINH = re.compile(r"^\*\*Hình (\d+)\.", re.M)


@capability("doc.embed_diagram")
def embed_diagram(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DOC-07 — CDS-12.4; DIAGRAM-01 (`diagram.render`); DDD-14 §2 DocArtifact.
    tc: "Đánh số liên tục"; undo `restore_config`.

    **Số hình đọc từ CHÍNH tài liệu**, không từ một bộ đếm trong cơ sở dữ liệu. Bước 1 nói
    "cập nhật DocArtifact.figures", nhưng DDD-14 §2 DocArtifact không có trường `figures` —
    xem [DEV-071]. Mà kể cả khi có, đếm trong tài liệu vẫn đúng hơn: tài liệu là thứ người đọc
    cầm, nên nếu ai đó sửa tay hay sinh lại nó thì bộ đếm ngoài sẽ lệch, còn cách đếm này thì
    không lệch được. "Đánh số liên tục" là một tính chất CỦA TÀI LIỆU, nên nó phải kiểm được
    trên tài liệu.

    Lược đồ **cũ (stale) thì gắn nhãn ngay dưới hình** thay vì từ chối chèn: một hình cũ vẫn
    nói được phần lớn sự thật, còn một tài liệu thiếu hình thì mất hẳn một cách hiểu. Nhưng nó
    phải nói ra là mình cũ.
    """
    from eide.caps.diagram import render

    root = _root(ctx)
    doc_id = params["doc_id"]
    noi_dung, duong = _doc_noi_dung(root, doc_id)
    if duong is None:
        raise EideError("E2000", f"`{doc_id}` không trỏ tới một tệp nào",
                        exists=[], candidates=[], missing=[doc_id])

    so = max((int(x) for x in RE_HINH.findall(noi_dung)), default=0) + 1
    dg, cu = _doc_diagram(root, params["diagram_id"])
    try:
        anh = render({"src": dg["src"], "lang": dg["lang"], "fmt": "svg"}, ctx)["path"]
        hinh = [f"![{params['caption']}]({anh})"]
    except EideError as e:
        # Thiếu bộ dựng thì chèn MÃ LƯỢC ĐỒ, không bỏ hình. CON-28 §6 định nghĩa lược đồ là
        # "sơ đồ ở dạng ngôn ngữ văn bản" — ảnh chỉ là sản phẩm phụ dựng lại được, nên nguồn
        # vẫn là một hình hợp lệ. Bỏ hình đi vì máy chưa cài `mmdc` là để một chi tiết cài đặt
        # quyết định nội dung tài liệu.
        if e.code != "E4001":
            raise
        hinh = [f"```{dg['lang']}", dg["src"].rstrip(), "```"]

    khoi = [*hinh, "",
            f"**Hình {so}.** {params['caption']}"
            + (" — *lược đồ đã cũ so với mô hình, dựng lại bằng `diagram.sync`*" if cu else "")]
    moi = _chen(noi_dung, "\n".join(khoi), params.get("after_heading"))
    Path(duong).write_text(moi, encoding="utf-8")
    return {"figure_no": so}


def _chen(noi_dung: str, khoi: str, sau_tieu_de: str | None) -> str:
    """Chèn ngay TRƯỚC đề mục kế tiếp sau `after_heading`, hoặc cuối tài liệu.

    Trước đề mục kế tiếp chứ không phải ngay sau dòng tiêu đề: một hình chen giữa tiêu đề và
    đoạn mở đầu đẩy phần văn xuôi xuống dưới hình, và người đọc gặp hình trước khi biết nó vẽ
    cái gì.
    """
    if not sau_tieu_de:
        return noi_dung.rstrip() + "\n\n" + khoi + "\n"
    dong = noi_dung.splitlines()
    can = sau_tieu_de.lstrip("#").strip().lower()
    vt = next((i for i, dg in enumerate(dong)
               if dg.startswith("#") and dg.lstrip("#").strip().lower() == can), None)
    if vt is None:
        return noi_dung.rstrip() + "\n\n" + khoi + "\n"
    ke = next((i for i in range(vt + 1, len(dong)) if dong[i].startswith("#")), len(dong))
    return "\n".join([*dong[:ke], "", khoi, "", *dong[ke:]]).rstrip() + "\n"


def _doc_diagram(root: Path, diagram_id: str) -> tuple[dict[str, Any], bool]:
    """`(diagram, đã_cũ)`. Nhận id trong bảng `diagram`, hoặc đường dẫn tệp mã lược đồ."""
    for cot in ("SELECT lang, src, stale FROM diagram WHERE id=?",):
        if (r := _q(root, cot, (diagram_id,))):
            return {"lang": r[0][0], "src": r[0][1]}, bool(r[0][2])
    p = Path(diagram_id).expanduser()
    if not p.is_absolute():
        p = root / EIDE_DIR / "diagrams" / diagram_id
    if p.is_file():
        from eide.caps.diagram import DUOI
        lang = next((k for k, v in DUOI.items() if v == p.suffix.lower()), "mermaid")
        return {"lang": lang, "src": p.read_text(encoding="utf-8")}, False
    raise EideError("E2000", f"Không tìm được lược đồ `{diagram_id}` — thử id trong bảng "
                    "`diagram` hoặc đường dẫn tệp mã lược đồ",
                    exists=[], candidates=[], missing=[diagram_id])
