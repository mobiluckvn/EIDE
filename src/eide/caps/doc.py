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
