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


# ---------------------------------------------------------------- DIAGRAM-13 lint


# Bốn nhóm kiểm của bước 1. Tách thành hằng số có tên để `issues` trả `kind` ổn định — giao diện
# lọc theo nó, và một chuỗi gõ tay trong ba chỗ là ba chỗ sẽ lệch.
KIND_CU_PHAP, KIND_MO_COI, KIND_LA, KIND_KICH_THUOC = "syntax", "orphan", "unknown_node", "size"


@capability("diagram.lint")
def lint(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-13 — CDS-12.4. tc: "Nút không có trong ModuleGraph → issue".

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


# ---------------------------------------------------------------- DIAGRAM-10 kg_view


@capability("diagram.kg_view")
def kg_view(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-10 — CDS-12.4. tc: "Render được; màu đúng".

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


# ---------------------------------------------------------------- DIAGRAM-04 architecture

# C4 [36] có bốn mức; hợp đồng dùng ba mức trên. Ánh xạ sang một hệ firmware:
#   context   — hệ thống này, con chip, board, và người vận hành
#   container — các LỚP của firmware (arch.LOP), vì trong firmware "container" không phải tiến
#               trình hay dịch vụ mà là lớp: hal → driver → service → control → app
#   component — từng module và phụ thuộc giữa chúng
LOP_C4 = ("hal", "driver", "service", "control", "app")
NHAN_LOP = {"hal": "HAL — chạm thanh ghi", "driver": "Driver — một ngoại vi một driver",
            "service": "Service — nghiệp vụ không biết chân nào", "control": "Control — điều khiển",
            "app": "App — vòng chính, chính sách"}


@capability("diagram.architecture")
def architecture(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-04 — CDS-12.4; ARCH-02 (ModuleGraph, năm lớp). tc: TC-72.

    Sinh từ **ModuleGraph đã có trong store**, không hỏi mô hình. `arch.decompose` đã quyết định
    module nào thuộc lớp nào và phụ thuộc ra sao, và nó đã kiểm hai bất biến (không chu trình,
    mọi FR có module). Vẽ lại bằng mô hình là mở một đường cho lược đồ nói khác thiết kế — mà
    lược đồ kiến trúc chính là thứ người ta đọc thay cho thiết kế.

    `node_ids = module id` theo bước 1, để `diagram.sync` và `diagram.lint` đối chiếu được với
    bảng `module`. Nhãn hiển thị là `name`, nhưng định danh nút thì phải là id — nếu lấy tên làm
    id thì đổi tên một module sẽ làm mọi lược đồ cũ thành không đối chiếu được.

    **Cạnh chỉ đi xuống lớp.** ARCH-02 cấm phụ thuộc ngược; nếu store có một cạnh đi lên thì nó
    được vẽ kèm nhãn `⚠ ngược lớp` chứ không bị giấu — lược đồ giấu một vi phạm là lược đồ nói
    dối, và chỗ này là chỗ duy nhất người đọc còn có cơ hội thấy nó.
    """
    from eide.caps.arch import _doc_module

    root = _root(ctx)
    muc = params.get("level") or "component"
    lang = params.get("lang") or "mermaid"
    mods = _doc_module(root, list(params["module_ids"]) if params.get("module_ids") else None)

    if muc == "context":
        nut, canh = _c4_context(root, mods)
    elif muc == "container":
        nut, canh = _c4_container(mods)
    else:
        if not mods:
            raise EideError("E2000", "Chưa có module nào — chạy `arch.decompose` trước; sơ đồ "
                            "kiến trúc phải vẽ từ ModuleGraph có thật, không đoán",
                            exists=[], candidates=[], missing=["module"])
        nut, canh = _c4_component(mods)

    src = _ve(nut, canh, lang, huong="TB")
    return {"diagram": {"lang": lang, "src": src, "level": muc,
                        "nodes": [n["id"] for n in nut],
                        "edges": [{"from": a, "to": b, "label": nh} for a, b, nh in canh],
                        "model_ref": "module"}}


def _c4_context(root: Path, mods: list[dict[str, Any]]) -> tuple[list[dict[str, str]], list[tuple[str, str, str]]]:
    """Mức context: hệ thống, chip, board, người. Lấy từ `constraints.yaml`, không bịa tên."""
    import yaml
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    ten = str((cu.get("project") or {}).get("name") or "Firmware")
    tg = cu.get("target") or {}
    nut = [{"id": "sys", "label": f"{ten}\\n({len(mods)} module)", "kind": "system"},
           {"id": "nguoi", "label": "Người vận hành", "kind": "person"}]
    canh = [("nguoi", "sys", "điều khiển, đọc trạng thái")]
    for khoa, nhan in (("chip", "Chip"), ("board", "Board")):
        if (v := tg.get(khoa)):
            nut.append({"id": khoa, "label": f"{nhan}: {v}", "kind": "external"})
            canh.append(("sys", khoa, "chạy trên" if khoa == "chip" else "gắn trên"))
    return nut, canh


def _c4_container(mods: list[dict[str, Any]]) -> tuple[list[dict[str, str]], list[tuple[str, str, str]]]:
    """Mức container: năm LỚP của firmware, chỉ vẽ lớp nào thật sự có module.

    Module dựng TRƯỚC DDD-14 v1.3 không có `layer` (cột ấy thêm ở migration 0005, DEV-069) và
    `layer` để `NULL` nghĩa là "chưa biết" — không suy ngược. Khi không module nào có lớp thì
    nói thẳng ra chứ không gộp bừa mọi module vào `service`: một sơ đồ container gom nhầm lớp
    còn tệ hơn không có sơ đồ, vì nó trông đúng.
    """
    theo: dict[str, list[dict[str, Any]]] = {}
    for m in mods:
        if (lp := str(m.get("layer") or "")) in LOP_C4:
            theo.setdefault(lp, []).append(m)
    if not theo:
        raise EideError("E2000", "Không module nào có `layer`, nên không dựng được mức "
                        "container — chạy lại `arch.decompose` để gán lớp (module dựng trước "
                        "DDD-14 v1.3 chưa có trường này), hoặc dùng `level=\"component\"`.",
                        exists=[m["id"] for m in mods], candidates=list(LOP_C4),
                        missing=["module.layer"])
    co = [x for x in LOP_C4 if x in theo]
    nut = [{"id": x, "label": f"{NHAN_LOP[x]}\\n{len(theo[x])} module", "kind": "container"}
           for x in co]
    canh = [(co[i], co[i + 1], "gọi xuống") for i in range(len(co) - 1)]
    return nut, canh


def _c4_component(mods: list[dict[str, Any]]) -> tuple[list[dict[str, str]], list[tuple[str, str, str]]]:
    """Mức component: từng module, cạnh là `depends`, có đánh dấu cạnh đi NGƯỢC lớp.

    Module chưa có `layer` thì vẫn vẽ được — module và `depends` đều có thật; chỉ mất phần nhãn
    lớp và phần cảnh báo cạnh ngược. Mất một lớp thông tin thì vẽ ít đi, chứ không đoán bù.
    """
    bac = {m["id"]: (LOP_C4.index(m["layer"]) if m.get("layer") in LOP_C4 else -1) for m in mods}
    co = set(bac)
    nut = [{"id": m["id"],
            "label": f"{m['name']}\\n{m['layer']}" if m.get("layer") in LOP_C4 else m["name"],
            "kind": "component"} for m in mods]
    canh = []
    for m in mods:
        for d in (m.get("depends") or []):
            if d not in co:
                continue
            nguoc = bac[m["id"]] >= 0 and bac[d] >= 0 and bac[d] > bac[m["id"]]
            canh.append((m["id"], d, "⚠ ngược lớp" if nguoc else ""))
    return nut, canh


# ---------------------------------------------------------------- DIAGRAM-06 state


@capability("diagram.state")
def state(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-06 — CDS-12.4; ARCH-07 (`arch.state_machine` sinh `module.fsm`). tc: TC-73.

    Vẽ từ `module.fsm` — cùng cấu trúc mà `arch.state_machine` đã kiểm đầy đủ (mọi cặp
    (trạng thái, sự kiện) có khai, không trạng thái nào không tới được). Nên lược đồ này không
    phải một bản vẽ song song mà là một CÁCH ĐỌC của chính máy trạng thái đã kiểm.

    **Sự kiện bỏ qua thành ghi chú, không thành cạnh.** ARCH-07 buộc khai cả những cặp
    `ignore: true`, và số ấy là |trạng thái| × |sự kiện| trừ số chuyển thật — vẽ hết thành
    cạnh tự-lặp thì lược đồ đặc kín và không ai đọc được. Nhưng bỏ hẳn cũng sai: "bỏ qua" là
    một QUYẾT ĐỊNH, và nó phân biệt "đã nghĩ tới rồi" với "quên mất". Nên chúng vào `note`
    cạnh trạng thái — đọc được mà không che mất luồng chính.
    """
    from eide.caps.arch import _doc_module

    root = _root(ctx)
    mid = params["module_id"]
    lang = params.get("lang") or "mermaid"
    mods = _doc_module(root, [mid])
    if not mods:
        raise EideError("E2000", f"Không có module `{mid}`",
                        exists=[], candidates=[], missing=[mid])
    fsm = mods[0].get("fsm") or {}
    if not fsm.get("states"):
        raise EideError("E2000", f"Module `{mid}` chưa có máy trạng thái — chạy "
                        "`arch.state_machine` trước",
                        exists=[mid], candidates=[], missing=[f"fsm:{mid}"])

    states = [str(s) for s in fsm["states"]]
    dau = str(fsm.get("initial") or (states[0] if states else ""))
    chuyen = [t for t in (fsm.get("transitions") or []) if not t.get("ignore")]
    bo_qua: dict[str, list[str]] = {}
    for t in (fsm.get("transitions") or []):
        if t.get("ignore"):
            bo_qua.setdefault(str(t.get("from")), []).append(str(t.get("event")))

    src = (_state_mermaid(states, dau, chuyen, bo_qua) if lang == "mermaid"
           else _state_plantuml(states, dau, chuyen, bo_qua))
    return {"diagram": {"lang": lang, "src": src, "nodes": states,
                        "edges": [{"from": str(t.get("from")), "to": str(t.get("to")),
                                   "label": _nhan_chuyen(t)} for t in chuyen],
                        "initial": dau, "ignored": bo_qua, "model_ref": f"fsm:{mid}"}}


def _nhan_chuyen(t: dict[str, Any]) -> str:
    """`sự_kiện [guard] / hành_động` — cú pháp UML, đọc được ở cả mermaid lẫn PlantUML."""
    s = str(t.get("event") or "")
    if t.get("guard"):
        s += f" [{t['guard']}]"
    if t.get("action"):
        s += f" / {t['action']}"
    return s


def _ma_trang_thai(s: str) -> str:
    return re.sub(r"[^0-9A-Za-z_]+", "_", s)[:40] or "s"


def _state_mermaid(states, dau, chuyen, bo_qua) -> str:
    d = ["stateDiagram-v2", f"  [*] --> {_ma_trang_thai(dau)}"]
    for s in states:
        if (m := _ma_trang_thai(s)) != s:
            d.append(f'  {m} : {s}')
    for t in chuyen:
        d.append(f"  {_ma_trang_thai(str(t.get('from')))} --> "
                 f"{_ma_trang_thai(str(t.get('to')))} : {_nhan_chuyen(t)}")
    for s, ds in sorted(bo_qua.items()):
        d += [f"  note right of {_ma_trang_thai(s)}", f"    bỏ qua: {', '.join(sorted(ds))}",
              "  end note"]
    return "\n".join(d) + "\n"


def _state_plantuml(states, dau, chuyen, bo_qua) -> str:
    d = ["@startuml", f"[*] --> {_ma_trang_thai(dau)}"]
    for s in states:
        if (m := _ma_trang_thai(s)) != s:
            d.append(f'state "{s}" as {m}')
    for t in chuyen:
        d.append(f"{_ma_trang_thai(str(t.get('from')))} --> "
                 f"{_ma_trang_thai(str(t.get('to')))} : {_nhan_chuyen(t)}")
    for s, ds in sorted(bo_qua.items()):
        d.append(f"note right of {_ma_trang_thai(s)} : bỏ qua: {', '.join(sorted(ds))}")
    return "\n".join(d) + "\n@enduml\n"


# ---------------------------------------------------------------- DIAGRAM-03 pinmap

# Net nguồn/đất: có mặt trên gần như mọi chân mà không mang thông tin chức năng nào. Để chúng
# lẫn vào bảng chân thì bảng dài gấp đôi và chỗ cần nhìn bị đẩy xuống dưới.
RE_NGUON_DAT = re.compile(r"^/?(GND|VSS|AGND|DGND|\+?\d+V\d*|VCC|VDD|VBAT|AVDD|3V3|5V)$", re.I)

# Hướng của một tín hiệu bus, khi và chỉ khi biết MCU là bên CHỦ. Đây là quy ước của chính chuẩn
# bus, không phải phỏng đoán về board này — nhưng nó phụ thuộc vai trò, nên không có vai trò
# trong HwMap thì cột hướng để TRỐNG. SDA hai chiều kể cả khi MCU là chủ (tớ kéo ACK).
HUONG_BUS = {"SCL": "ra", "SCK": "ra", "SDA": "hai chiều", "MOSI": "ra", "MISO": "vào",
             "TX": "ra", "RX": "vào", "NSS": "ra", "CS": "ra"}


@capability("diagram.pinmap")
def pinmap(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-03 — CDS-12.4; ARCH-03 (HwMap); BOARD-01/02 (hộ chiếu board, `check_pins`).
    tc: "PB6→SCL BME280 đúng"; undo `delete_created_files`.

    **Ba mảnh ở ba chỗ, và giá trị nằm ở chỗ nối được cả ba**: net từ netlist (chân số mấy nối
    đi đâu), tên chân từ hộ chiếu chip (`pin_function`: chân nào làm được chức năng gì), tên
    linh kiện từ fact `package`. Không mảnh nào tự nó nói được "PB6 là SCL của BME280".

    **Không tra được thì để trống.** Chưa có hộ chiếu chân thì chân 42 vẫn là chân 42 — dòng vẫn
    có (kết nối là thật), nhưng ô `pin` ghi số vật lý và `af` rỗng. Bảng chân là thứ người ta
    cầm đi hàn; một tên chân đoán ra ở đây tốn của người đọc cả buổi dò mạch.

    **Hướng suy từ VAI TRÒ trong HwMap, không từ tên tín hiệu.** SCL do bên chủ phát, nên MCU là
    chủ hay tớ mới quyết định hướng — và điều đó nằm ở `hw_map.role`. Không có HwMap thì cột
    hướng trống chứ không lấy quy ước phổ biến làm sự thật.

    **Xung đột lấy từ chính `board.check_pins`**, không viết phép kiểm thứ hai: hai phép kiểm
    cùng một việc sẽ nói khác nhau đúng lúc quan trọng, và người đọc không biết tin cái nào.

    Lược đồ là **SVG** theo bước 1 — và SVG *là* văn bản, nên bất biến CON-28 §6 của cả nhóm vẫn
    giữ: nó vào git dưới dạng khác biệt đọc được và `diagram.lint` kiểm được nó.
    """
    from eide.caps.board import _bid, doc_net, doc_part

    root = _root(ctx)
    board = params.get("board") or _board_duy_nhat(root)
    nets = doc_net(root, board)
    if not nets:
        from eide.caps.board import _cac_board
        co = _cac_board(root)
        raise EideError("E2000", f"Chưa có net nào cho board `{board}` — chạy "
                        "`extract.kicad_netlist` trước"
                        + (f" (board đang có net: {', '.join(co)})" if co else ""),
                        exists=co, candidates=["extract.kicad_netlist", *co],
                        missing=[f"net:{board}"])

    parts = doc_part(root, board)
    chuc_nang = _chan_chuc_nang(root)
    mcu = _ref_mcu(root, parts, chuc_nang)
    xung_dot = {x["pin"] for x in _xung_dot_chan(ctx, board)}
    vai = _vai_tro_hw_map(root)

    bang = _bang_chan(nets, parts, chuc_nang, mcu, vai, xung_dot,
                      set(params.get("module_ids") or []))
    goi = (parts.get(mcu) or {}) if mcu else {}
    src = _svg_pinmap(board, mcu or "?", str(goi.get("footprint") or ""), bang)
    return {"diagram": {"lang": "svg", "src": src, "board": board, "mcu": mcu or "",
                        "model_ref": _bid(board)},
            "table": bang}


def _board_duy_nhat(root: Path) -> str:
    """`board` là tùy chọn trong hợp đồng. Đúng MỘT board có net thì dùng nó; nhiều hơn thì hỏi
    — chọn bừa một trong hai board là vẽ bản đồ chân của board kia."""
    from eide.caps.board import _cac_board
    co = _cac_board(root)
    if len(co) == 1:
        return co[0]
    raise EideError("E2000", "Không nêu `board` mà store có "
                    + (f"{len(co)} board: {', '.join(co)}" if co else "chưa board nào"),
                    exists=co, candidates=co or ["extract.kicad_netlist"], missing=["board"])


def _chan_chuc_nang(root: Path) -> dict[str, dict[str, Any]]:
    """`{TÊN CHÂN: {functions, fact_id, chip}}` từ fact `pin_function` của hộ chiếu chip."""
    import json
    db = store.store_path(root)
    if not db.exists():
        return {}
    ra: dict[str, dict[str, Any]] = {}
    with store.open_store(db) as c:
        rows = c.execute("SELECT id, subject, value FROM fact WHERE predicate='pin_function'"
                         "  AND status NOT IN ('superseded','rejected')").fetchall()
    for fid, subj, gt in rows:
        try:
            v = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            continue
        ten = str((v.get("pin") if isinstance(v, dict) else None)
                  or str(subj).rsplit(":", 1)[-1]).upper()
        fs = [str(x).upper() for x in
              ((v.get("functions") or v.get("af") or []) if isinstance(v, dict) else [])]
        ra[ten] = {"functions": fs, "fact_id": fid,
                   "chip": str(subj).split("/")[0].split(":", 1)[-1]}
    return ra


def _chuan(s: str) -> str:
    return re.sub(r"[^0-9a-z]+", "", str(s).lower())


def _ref_mcu(root: Path, parts: dict[str, dict[str, Any]],
             chuc_nang: dict[str, dict[str, Any]]) -> str | None:
    """Ref của MCU trên board — từ chip ĐÃ GHIM của dự án, hoặc từ chip của hộ chiếu chân.

    Không đoán bằng "linh kiện nằm trên nhiều net nhất": trên board của test ấy là con cảm biến
    chứ không phải MCU, và đoán sai chỗ này thì cả bảng chân đảo ngược.
    """
    import yaml
    ung_vien = []
    f = root / EIDE_DIR / "constraints.yaml"
    if f.exists():
        cu = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        if (chip := (cu.get("target") or {}).get("chip")):
            ung_vien.append(_chuan(chip))
    ung_vien += [_chuan(v["chip"]) for v in chuc_nang.values() if v.get("chip")]

    for ref, pt in sorted(parts.items()):
        ten = _chuan(pt.get("mpn") or pt.get("value") or "")
        if len(ten) >= 5 and any(ten.startswith(u) or u.startswith(ten) for u in ung_vien if u):
            return ref
    return None


def _vai_tro_hw_map(root: Path) -> dict[str, tuple[str, str]]:
    """`{NGOẠI VI: (module_id, role)}` từ HwMap — ví dụ `I2C1 → (mod_i2c, master)`."""
    import json
    ra: dict[str, tuple[str, str]] = {}
    db = store.store_path(root)
    if not db.exists():
        return ra
    with store.open_store(db) as c:
        try:
            rows = c.execute("SELECT module_id, resource, role FROM hw_map").fetchall()
        except Exception:                       # noqa: BLE001 — store cũ chưa có bảng
            return ra
    for mid, tn, role in rows:
        ra[str(tn).rsplit(":", 1)[-1].upper()] = (mid, str(role or ""))
        _ = json
    return ra


def _xung_dot_chan(ctx: Context, board: str) -> list[dict[str, Any]]:
    """Xung đột từ `board.check_pins`. Nó có thể lỗi (thiếu dữ liệu) mà bản đồ chân vẫn vẽ
    được — bảng không có cột đỏ vẫn hơn không có bảng."""
    from eide.caps.board import check_pins
    try:
        return list(check_pins({"board": board}, ctx)["conflicts"])
    except EideError:
        return []


def _bang_chan(nets: dict[str, list[dict[str, str]]], parts: dict[str, dict[str, Any]],
               chuc_nang: dict[str, dict[str, Any]], mcu: str | None,
               vai: dict[str, tuple[str, str]], xung_dot: set[str],
               loc_module: set[str]) -> list[dict[str, Any]]:
    """Một dòng cho mỗi net TÍN HIỆU có MCU tham gia."""
    ra: list[dict[str, Any]] = []
    for ten, nodes in sorted(nets.items()):
        if RE_NGUON_DAT.match(ten.strip()):
            continue
        nut_mcu = next((n for n in nodes if n.get("ref") == mcu), None)
        if nut_mcu is None:
            continue
        chan, af, fids = _tra_chan(ten, chuc_nang)
        mid, huong = _module_va_huong(af or ten, vai)
        if loc_module and mid not in loc_module:
            continue
        ra.append({
            "pin": chan or f"{mcu}.{nut_mcu.get('pin', '?')}",
            "af": af, "net": ten,
            "part": ", ".join(_nhan_part(n["ref"], parts) for n in nodes
                              if n.get("ref") and n["ref"] != mcu) or "—",
            "part_pin": ", ".join(f"{n['ref']}.{n.get('pin', '?')}" for n in nodes
                                  if n.get("ref") and n["ref"] != mcu),
            "dir": huong, "module": mid,
            "conflict": bool(xung_dot & {f"{mcu}.{nut_mcu.get('pin', '')}", (chan or "").upper()}),
            "fact_ids": fids,
        })
    return ra


def _tra_chan(net: str, chuc_nang: dict[str, dict[str, Any]]) -> tuple[str, str, list[str]]:
    """`(tên chân, AF, fact ids)` — tra TÊN NET ngược về chân qua `pin_function`.

    Netlist chỉ cho số chân (`U1.42`); tên `PB6` nằm trong hộ chiếu chip. Chỗ nối hai thứ ấy là
    TÊN TÍN HIỆU: net `/I2C1_SCL` khớp chức năng `I2C1_SCL` của chân PB6.
    """
    tin_hieu = net.strip("/").upper()
    for chan, v in sorted(chuc_nang.items()):
        for f in v["functions"]:
            if f == tin_hieu:
                return chan, f, [v["fact_id"]]
    return "", "", []


def _module_va_huong(tin_hieu: str, vai: dict[str, tuple[str, str]]) -> tuple[str, str]:
    """`(module, hướng)`. Hướng CHỈ khi HwMap nói MCU là `master` trên ngoại vi ấy."""
    t = tin_hieu.strip("/").upper()
    ngoai_vi, _, hau = t.partition("_")
    mid, role = vai.get(ngoai_vi, ("", ""))
    if role != "master":
        return mid, ""
    return mid, HUONG_BUS.get(hau or t, "")


def _nhan_part(ref: str, parts: dict[str, dict[str, Any]]) -> str:
    pt = parts.get(ref) or {}
    ten = pt.get("mpn") or pt.get("value")
    return f"{ref} · {ten}" if ten else ref


def _svg_pinmap(board: str, mcu: str, package: str, bang: list[dict[str, Any]]) -> str:
    """Hình chip với nhãn chân, chân xung đột tô đỏ. Kích thước theo SỐ DÒNG thật.

    Vẽ tay chứ không qua bộ dựng ngoài: bước 1 đòi SVG, và bắt nó cần `mmdc` thì năng lực này
    hỏng đúng lúc cần nhất — trên máy chưa cài gì. Không có ký tự `<`/`>` nào trong nhãn (chúng
    phá XML), và mọi nhãn đều đi qua `_thoat_xml`.
    """
    cao_dong, le, rong_chip = 26, 20, 180
    cao = max(len(bang), 1) * cao_dong + 2 * le + 20
    x_chip, x_part = le + 130, le + 130 + rong_chip + 150
    d = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{x_part + 260}" height="{cao}" '
         f'viewBox="0 0 {x_part + 260} {cao}" font-family="monospace" font-size="12">',
         f'  <title>Bản đồ chân {_thoat_xml(board)}</title>',
         f'  <rect x="{x_chip}" y="{le}" width="{rong_chip}" height="{max(len(bang), 1) * cao_dong}" '
         'fill="none" stroke="#333" stroke-width="2"/>',
         f'  <text x="{x_chip + rong_chip // 2}" y="{le - 6}" text-anchor="middle">'
         f'{_thoat_xml(mcu)}{f" · {_thoat_xml(package)}" if package else ""}</text>']
    for i, h in enumerate(bang):
        y = le + i * cao_dong + cao_dong // 2 + 4
        # Màu KHÔNG phải kênh duy nhất: thêm dấu ⚠ trước tên chân. Một bản đồ chân chỉ phân
        # biệt bằng đỏ thì người mù màu đọc ra một bảng không có xung đột nào.
        mau = "red" if h["conflict"] else "#333"
        nhan_chan = ("⚠ " if h["conflict"] else "") + h["pin"]
        d += [f'  <text x="{x_chip - 8}" y="{y}" text-anchor="end" fill="{mau}">'
              f'{_thoat_xml(nhan_chan)}</text>',
              f'  <line x1="{x_chip + rong_chip}" y1="{y - 4}" x2="{x_part - 8}" y2="{y - 4}" '
              f'stroke="{mau}"/>',
              f'  <text x="{x_chip + rong_chip + 8}" y="{y - 8}" fill="{mau}">'
              f'{_thoat_xml(h["net"] + (" · " + h["dir"] if h["dir"] else ""))}</text>',
              f'  <text x="{x_part}" y="{y}" fill="{mau}">{_thoat_xml(h["part"])}</text>']
        if h["af"]:
            d.append(f'  <text x="{x_chip + 6}" y="{y}" fill="#666">{_thoat_xml(h["af"])}</text>')
    if not bang:
        d.append(f'  <text x="{x_chip + 6}" y="{le + 20}" fill="#666">chưa có net tín hiệu '
                 'nào của MCU</text>')
    d.append("</svg>")
    return "\n".join(d) + "\n"


def _thoat_xml(s: str) -> str:
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;"))


# ---------------------------------------------------------------- dựng mã lược đồ chung


def _ve(nut: list[dict[str, str]], canh: list[tuple[str, str, str]], lang: str,
        huong: str = "LR") -> str:
    """Cùng một đồ thị, ba ngôn ngữ. Một hàm chứ ba bản sao — ba bản sao thì sửa hình dạng nút
    ở một chỗ và hai chỗ kia lặng lẽ khác đi."""
    if lang == "plantuml":
        d = ["@startuml", "left to right direction" if huong == "LR" else ""]
        d += [f'rectangle "{n["label"]}" as {n["id"]}' for n in nut]
        d += [f"{a} --> {b}" + (f" : {nh}" if nh else "") for a, b, nh in canh]
        return "\n".join(x for x in d if x) + "\n@enduml\n"
    if lang == "d2":
        d = [f'{n["id"]}: "{n["label"]}"' for n in nut]
        d += [f"{a} -> {b}" + (f': "{nh}"' if nh else "") for a, b, nh in canh]
        return "\n".join(d) + "\n"
    d = [f"flowchart {huong}"]
    d += [f'  {n["id"]}["{n["label"]}"]' for n in nut]
    d += [f"  {a} -->" + (f"|{nh}| " if nh else " ") + b for a, b, nh in canh]
    return "\n".join(d) + "\n"
