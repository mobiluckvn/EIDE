"""Namespace diagram.* — CDS-12.4 (tập Giao diện); UXD-13; DDD-14 §2 Diagram.

Bốn năng lực mốc M1: `lint`, `render`, `block`, `kg_view`.

## Lược đồ là VĂN BẢN, ảnh chỉ là sản phẩm phụ

CON-28 §6 định nghĩa "lược đồ" đúng một câu: *"Sơ đồ ở dạng ngôn ngữ văn bản"*. Đó không phải
chi tiết kỹ thuật mà là một quyết định về nguồn sự thật — nguồn là `src`, còn `.svg`/`.png` là
kết quả dựng lại được. Nên `diagram.block` và `diagram.kg_view` trả **mã lược đồ**, không trả
ảnh; muốn ảnh thì gọi `diagram.render`.

Hệ quả thực tế: lược đồ vào Git dưới dạng khác biệt đọc được, người xem lại được lịch sử "vì
sao cạnh này đổi", và `diagram.lint` kiểm được nội dung. Một PNG thì cả ba đều mất.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.tools import which

# DIAGRAM-01 bước 1: "mmdc, plantuml.jar, dot, d2, wavedrom-cli; svg: sao chép".
BO_RENDER: dict[str, tuple[str, str, list[str]]] = {
    # lang: (lệnh, gói cài, tham số dựng — {src}/{out}/{fmt} thay lúc chạy)
    "mermaid":  ("mmdc", "mermaid-cli", ["-i", "{src}", "-o", "{out}"]),
    "plantuml": ("plantuml", "plantuml", ["-t{fmt}", "-o", "{outdir}", "{src}"]),
    "dot":      ("dot", "graphviz", ["-T{fmt}", "{src}", "-o", "{out}"]),
    "d2":       ("d2", "d2", ["{src}", "{out}"]),
    "wavedrom": ("wavedrom-cli", "wavedrom-cli", ["-i", "{src}", "-{fmt}", "{out}"]),
}
DUOI = {"mermaid": ".mmd", "plantuml": ".puml", "dot": ".dot", "d2": ".d2",
        "wavedrom": ".json", "svg": ".svg"}

TRAN_NUT = 300          # DIAGRAM-04 bước 1 và DIAGRAM-03 ("giới hạn 300 nút")
TIMEOUT_S = 60


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm diagram.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _thu_muc(ctx: Context) -> Path:
    d = _root(ctx) / EIDE_DIR / "diagrams"
    d.mkdir(parents=True, exist_ok=True)
    return d


# ---------------------------------------------------------------- DIAGRAM-04 lint


# Bốn nhóm kiểm của bước 1. Tách thành hằng số có tên để `issues` trả `kind` ổn định — giao diện
# lọc theo nó, và một chuỗi gõ tay trong ba chỗ là ba chỗ sẽ lệch.
KIND_CU_PHAP, KIND_MO_COI, KIND_LA, KIND_KICH_THUOC = "syntax", "orphan", "unknown_node", "size"


@capability("diagram.lint")
def lint(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-04 — CDS-12.4. tc: "Nút không có trong ModuleGraph → issue".

    Phép kiểm đáng giá nhất là `unknown_node`, không phải cú pháp. Một lược đồ sai cú pháp thì
    renderer báo ngay; một lược đồ **đúng cú pháp nhưng vẽ sai hệ thống** thì không ai báo — nó
    được dán vào tài liệu, đưa cho người phản biện, và trở thành mô tả chính thức của một kiến
    trúc không tồn tại.

    `model_ref` cho biết đối chiếu với cái gì (`module` — ModuleGraph; `fsm:<module_id>`; `bom`).
    Không truyền thì bỏ qua nhóm ấy chứ không đoán: đối chiếu với mô hình sai còn tệ hơn không
    đối chiếu, vì nó báo lỗi ở những chỗ đúng và người dùng học cách bỏ qua cả danh sách.
    """
    src, lang = params["src"], params["lang"]
    nut, canh = _doc_do_thi(src, lang)
    issues: list[dict[str, Any]] = []

    if (loi := _cu_phap(src, lang)):
        issues.append({"severity": "high", "kind": KIND_CU_PHAP, "line": loi[0],
                       "message": loi[1]})

    if len(nut) > TRAN_NUT:
        issues.append({"severity": "medium", "kind": KIND_KICH_THUOC, "line": 0,
                       "message": f"{len(nut)} nút vượt {TRAN_NUT} — lược đồ quá lớn thì người "
                                  "xem không đọc được, hãy tách hoặc lọc"})

    noi = {a for a, _ in canh} | {b for _, b in canh}
    for n in sorted(nut - noi):
        if len(nut) > 1:
            issues.append({"severity": "low", "kind": KIND_MO_COI, "line": _dong_cua(src, n),
                           "message": f"nút `{n}` không nối với nút nào"})

    if (ref := params.get("model_ref")):
        biet = _ten_trong_mo_hinh(ctx, ref)
        if biet is not None:
            for n in sorted(nut - biet):
                issues.append({"severity": "high", "kind": KIND_LA, "line": _dong_cua(src, n),
                               "message": f"nút `{n}` không có trong `{ref}` — lược đồ đang vẽ "
                                          "một thứ không tồn tại trong mô hình"})
    return {"issues": issues}


def _doc_do_thi(src: str, lang: str) -> tuple[set[str], list[tuple[str, str]]]:
    """Rút (nút, cạnh) từ mã lược đồ. Chỉ hai ngôn ngữ đồ thị — mermaid và dot.

    Với `plantuml`/`wavedrom`/`d2` thì trả rỗng: kiểm mồ côi và nút lạ trên một định dạng chưa
    phân tích được sẽ báo bừa, mà một danh sách báo bừa thì người dùng bỏ qua cả những mục đúng.
    """
    nut: set[str] = set()
    canh: list[tuple[str, str]] = []
    if lang not in ("mermaid", "dot"):
        return set(), []

    # Duyệt theo TỪNG DÒNG. Quét cả chuỗi bằng `findall` thì nút đích của cạnh này bị nuốt và
    # trở thành điểm bắt đầu không dùng lại được cho cạnh sau — đo được: 305 dòng cạnh chỉ ra
    # 153 cạnh, tức mất đúng một nửa. Hệ quả là số nút sai (kiểm kích thước không bao giờ nổ)
    # và nút "mồ côi" báo bừa. Ngôn ngữ lược đồ vốn theo dòng, nên duyệt theo dòng vừa đúng vừa
    # đơn giản hơn.
    mui = (r"(?:--[->|][^>]*>|-->|---|===|-\.->)" if lang == "mermaid" else r"->")
    khai = (r"^\s*([A-Za-z_][\w]*)\s*[\[({\"]" if lang == "mermaid"
            else r"^\s*([A-Za-z_][\w]*)\s*\[")
    for dong in src.splitlines():
        for m in re.finditer(rf"([A-Za-z_][\w]*)\s*{mui}\s*([A-Za-z_][\w]*)", dong):
            canh.append((m.group(1), m.group(2)))
            nut |= {m.group(1), m.group(2)}
        if (m := re.match(khai, dong)):
            nut.add(m.group(1))
    return nut - {"graph", "digraph", "flowchart", "subgraph", "end", "style", "rankdir",
                  "node", "edge"}, canh


def _dong_cua(src: str, ten: str) -> int:
    for i, d in enumerate(src.splitlines(), 1):
        if re.search(rf"\b{re.escape(ten)}\b", d):
            return i
    return 0


def _cu_phap(src: str, lang: str) -> tuple[int, str] | None:
    """Kiểm cú pháp NHẸ — cân bằng ngoặc và dòng mở đầu bắt buộc.

    Không gọi renderer để kiểm: `diagram.lint` chạy TRƯỚC `diagram.render` (bước 1 của
    DIAGRAM-01), và bắt nó cần một công cụ ngoài thì nó thành vô dụng đúng lúc cần nhất — khi
    máy chưa cài gì.
    """
    if not src.strip():
        return (1, "mã lược đồ rỗng")
    for mo, dong in (("(", ")"), ("[", "]"), ("{", "}")):
        if src.count(mo) != src.count(dong):
            return (0, f"lệch ngoặc: {src.count(mo)} `{mo}` và {src.count(dong)} `{dong}`")
    dau = next((d.strip() for d in src.splitlines() if d.strip()), "")
    mo_dau = {"mermaid": ("graph", "flowchart", "sequenceDiagram", "stateDiagram", "classDiagram",
                          "erDiagram", "gantt", "journey", "pie"),
              "dot": ("digraph", "graph", "strict"),
              "plantuml": ("@startuml", "@startmindmap", "@startgantt"),
              "d2": (), "wavedrom": ("{",), "svg": ("<",)}.get(lang, ())
    if mo_dau and not dau.startswith(mo_dau):
        return (1, f"dòng đầu `{dau[:40]}` không phải mở đầu hợp lệ của {lang} "
                   f"(chờ một trong {list(mo_dau)})")
    return None


def _ten_trong_mo_hinh(ctx: Context, ref: str) -> set[str] | None:
    """Tập tên hợp lệ theo mô hình tham chiếu. None = không tra được ⇒ bỏ qua nhóm kiểm ấy."""
    db = store.store_path(_root(ctx))
    if not db.exists():
        return None
    with store.open_store(db) as c:
        if ref == "module":
            return {r[0] for r in c.execute("SELECT id FROM module")} | \
                   {r[0] for r in c.execute("SELECT name FROM module")}
        if ref.startswith("fsm:"):
            r = c.execute("SELECT fsm FROM module WHERE id=?", (ref[4:],)).fetchone()
            if not r or not r[0]:
                return None
            import json
            return set(json.loads(r[0]).get("states") or [])
        if ref == "bom":
            return {r[0].split("/")[-1].split(":")[-1]
                    for r in c.execute("SELECT DISTINCT subject FROM fact")}
    return None


# ---------------------------------------------------------------- DIAGRAM-01 render


@capability("diagram.render")
def render(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-01 — CDS-12.4. tc: TC-71 "sáu ngôn ngữ"; lỗi E4001, E4000.

    Bước 1 nói `diagram.lint` chạy TRƯỚC. Thứ tự ấy có lý do thực dụng: renderer báo lỗi cú pháp
    bằng thông điệp của riêng nó (`mmdc` in một stack trace JavaScript), còn `lint` nói được
    "dòng 7, lệch ngoặc". Chạy lint trước nghĩa là lỗi thường gặp nhất được báo bằng tiếng người.

    Thiếu renderer thì E4001 **kèm tên gói**, và `lint` vẫn chạy — nên người dùng chưa cài gì
    vẫn biết lược đồ của mình có hợp lệ không. Đó là lý do `lint` không được phép cần công cụ
    ngoài.
    """
    src, lang = params["src"], params["lang"]
    fmt = params.get("fmt", "svg")
    kq_lint = lint({"src": src, "lang": lang}, ctx)["issues"]
    if (nang := [x for x in kq_lint if x["kind"] == KIND_CU_PHAP]):
        raise EideError("E4000", f"Cú pháp {lang} không hợp lệ: {nang[0]['message']}",
                        lang=lang, issues=kq_lint)

    d = _thu_muc(ctx)
    ten = f"dg_{abs(hash(src)) % 10**10:010d}"
    f_src = d / (ten + DUOI.get(lang, ".txt"))
    f_src.write_text(src, encoding="utf-8")

    if lang == "svg":
        # "svg: sao chép" — đã là ảnh vector, dựng lại là biến đổi thừa và có thể làm mất chữ.
        ra = d / (ten + ".svg")
        ra.write_text(src, encoding="utf-8")
        return {"path": str(ra), "lint": kq_lint}

    if lang not in BO_RENDER:
        raise EideError("E1000", f"Ngôn ngữ lược đồ lạ: {lang}", lang=lang,
                        candidates=[*BO_RENDER, "svg"])
    exe_ten, goi, tham = BO_RENDER[lang]
    exe = which(exe_ten)
    if exe is None:
        raise EideError("E4001", f"Thiếu bộ dựng `{exe_ten}` cho {lang} — chạy "
                        f"`eide env install {goi}`. Mã lược đồ đã lưu ở {f_src}, và "
                        f"`diagram.lint` vẫn kiểm được nó mà không cần công cụ nào.",
                        tool=exe_ten, package=goi, src_path=str(f_src), lint=kq_lint)

    ra = d / f"{ten}.{fmt}"
    lenh = [str(exe)] + [t.format(src=f_src, out=ra, fmt=fmt, outdir=d) for t in tham]
    try:
        r = subprocess.run(lenh, capture_output=True, text=True, timeout=TIMEOUT_S, check=False)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise EideError("E4004", f"Bộ dựng {exe_ten} quá hạn hoặc lỗi: {e}", tool=exe_ten) from e
    if r.returncode != 0 or not ra.exists():
        raise EideError("E4000", f"{exe_ten} không dựng được: "
                        f"{(r.stderr or r.stdout or '')[:300]}", tool=exe_ten, lint=kq_lint)
    return {"path": str(ra), "lint": kq_lint}


# ---------------------------------------------------------------- DIAGRAM-02 block


# Ngoại vi nào là "bus" để vẽ thành cạnh, ngoại vi nào là chân rời. Cạnh mang nhãn địa chỉ/tốc
# độ lấy từ fact — đó là điểm khác giữa một sơ đồ khối và một bức tranh: mỗi cạnh truy được về
# một fact có nguồn.
BUS = ("I2C", "SPI", "UART", "USART", "CAN", "USB", "I2S", "SDIO")


@capability("diagram.block")
def block(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-02 — CDS-12.4. tc: TC-72 "nút/cạnh khớp BOM/net".

    Sinh từ BOM và fact, KHÔNG hỏi mô hình. Một sơ đồ khối là ánh xạ trực tiếp của những gì đã
    biết: linh kiện nào có mặt, nối với nhau bằng bus nào, ở địa chỉ nào. Nhờ mô hình vẽ thì nó
    sẽ thêm một cảm biến trông hợp lý mà BOM không có — và sơ đồ khối là thứ người ta dùng để
    đặt hàng linh kiện.

    `node_ids = MPN/ref` theo bước 1: định danh nút là mã linh kiện thật, nên `diagram.lint`
    đối chiếu được với BOM và người đọc tra được ngay.
    """
    board = params["board"]
    bom = list(params.get("bom") or [])
    if not bom:
        bom = _bom_tu_store(ctx, board)
    if not bom:
        raise EideError("E2000", f"Không có BOM cho `{board}` và cũng không truyền `bom` — "
                        "sơ đồ khối phải vẽ từ linh kiện CÓ THẬT, không đoán",
                        exists=[], candidates=[], missing=["bom"])

    canh = _bus_tu_fact(ctx, bom)
    dong = ["flowchart LR"]
    for x in bom:
        nid = _ma_nut(x)
        nhan = x.get("mpn") or x.get("ref") or nid
        vai = x.get("role") or ""
        dong.append(f'  {nid}["{nhan}{f" · {vai}" if vai else ""}"]')
    for a, b, nhan in canh:
        dong.append(f"  {a} ---|{nhan}| {b}")
    src = "\n".join(dong) + "\n"
    return {"diagram": {"lang": "mermaid", "src": src,
                        "nodes": [_ma_nut(x) for x in bom],
                        "edges": [{"from": a, "to": b, "label": n} for a, b, n in canh],
                        "board": board}}


def _ma_nut(x: dict[str, Any]) -> str:
    t = str(x.get("ref") or x.get("mpn") or "n")
    return re.sub(r"[^0-9A-Za-z]+", "_", t)[:40] or "n"


def _bom_tu_store(ctx: Context, board: str) -> list[dict[str, Any]]:
    """BOM từ hộ chiếu board nếu có. Trả rỗng khi không có — bên gọi quyết định làm gì."""
    db = store.store_path(_root(ctx))
    if not db.exists():
        return []
    import json
    with store.open_store(db) as c:
        r = c.execute("SELECT header FROM passport WHERE id = ? OR id LIKE ?",
                      (board, f"{board}@%")).fetchone()
    if not r or not r[0]:
        return []
    return list((json.loads(r[0]) or {}).get("bom") or [])


def _bus_tu_fact(ctx: Context, bom: list[dict[str, Any]]) -> list[tuple[str, str, str]]:
    """Cạnh = bus, nhãn = địa chỉ/tốc độ lấy từ fact.

    Nối MCU với từng linh kiện khai cùng bus. Nhãn rỗng khi chưa có fact — vẽ một cạnh không
    nhãn là trung thực ("có nối, chưa biết địa chỉ"), còn bịa một địa chỉ thì người đọc tin.
    """
    db = store.store_path(_root(ctx))
    dia_chi: dict[str, str] = {}
    if db.exists():
        import json
        with store.open_store(db) as c:
            for subj, gt in c.execute(
                    "SELECT subject, value FROM fact WHERE predicate IN ('address','base_address')"
                    " AND status NOT IN ('superseded','rejected')"):
                dia_chi[subj.rsplit(":", 1)[-1].upper()] = json.loads(gt) if gt else ""
    mcu = next((x for x in bom if (x.get("role") or "").lower() in ("mcu", "soc")), None)
    if mcu is None:
        return []
    ra = []
    for x in bom:
        if x is mcu:
            continue
        b = (x.get("bus") or "").upper()
        if b not in BUS:
            continue
        addr = x.get("address") or dia_chi.get(b, "")
        nhan = f"{b} {addr}".strip() if addr else b
        ra.append((_ma_nut(mcu), _ma_nut(x), nhan))
    return ra


# ---------------------------------------------------------------- DIAGRAM-03 kg_view


@capability("diagram.kg_view")
def kg_view(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-03 — CDS-12.4. tc: "Render được; màu đúng".

    Dùng lại `view.kg_map` cho phần màu và `view.export_map` cho phần sinh DOT, thay vì tự tô
    lại. Hai bảng màu cho cùng một ý nghĩa là hai bảng sẽ lệch — và lệch màu thì `conflict` đỏ ở
    màn hình này lại xám ở màn hình kia, mà màu là thứ người dùng đọc trước cả chữ.
    """
    from eide.caps.view import TRAN_MERMAID, export_map, kg_map
    q = params["query"]
    g = kg_map({"filter": q.get("filter") or {}}, ctx)["graph"]

    if (node := q.get("node")):
        from eide.caps.kg import neighborhood
        sau = int(q.get("depth") or 2)
        con = neighborhood({"node": node, "depth": sau}, ctx)["subgraph"]
        giu = {n["id"] for n in (con.get("nodes") or [])}
        g = {**g, "nodes": [n for n in g["nodes"] if n["id"] in giu],
             "edges": [e for e in g["edges"] if e["from"] in giu and e["to"] in giu]}

    if len(g["nodes"]) > TRAN_NUT:
        raise EideError("E5000", f"{len(g['nodes'])} nút vượt giới hạn {TRAN_NUT} của "
                        "DIAGRAM-03 — thu hẹp bằng `node`+`depth` hoặc `filter`",
                        n_nodes=len(g["nodes"]), limit=TRAN_NUT)
    _ = TRAN_MERMAID
    f = export_map({"view": {"graph": g}, "format": "dot"}, ctx)["file"]
    return {"diagram": {"lang": "dot", "src": Path(f).read_text(encoding="utf-8"),
                        "path": f, "nodes": len(g["nodes"]), "edges": len(g["edges"]),
                        "legend": g.get("legend")}}
