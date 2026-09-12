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

import hashlib
import re
import subprocess
from datetime import UTC, datetime
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
    # Mermaid có nhiều dạng mũi tên, và dạng CÓ NHÃN (`-->|nhãn|`, `---|nhãn|`) chính là dạng mà
    # `diagram.block`, `diagram.flow` và `diagram.architecture` tự sinh ra. Bản trước bỏ sót
    # chúng, và bỏ sót một cách IM LẶNG: một lược đồ khối đủ hai nút cho ra 0 cạnh và 1 nút, mà
    # kiểm "nút mồ côi" tự tắt khi chỉ có 1 nút — nên hai phép kiểm đáng giá nhất của `lint`
    # không chạy trên đúng những lược đồ EIDE tự sinh, và không có gì báo.
    mui = (r"(?:-{2,3}|={2,3}|-\.-)[->ox]?\s*(?:\|[^|\n]*\|)?"
           if lang == "mermaid" else r"->")
    # …và nút được viết KÈM NHÃN ngay tại chỗ nối: `mcu[STM32F411] ---|I2C| bme[BME280]` là một
    # dòng mermaid hoàn toàn bình thường, người ta viết tay như thế suốt. Không cho phép phần
    # nhãn thì cạnh ấy vô hình, và `diagram.lint` — năng lực sinh ra để kiểm lược đồ NGƯỜI viết
    # — mù đúng với dạng người viết nhiều nhất.
    nhan = r"(?:[\[({][^\n]*?[\])}]\s*)?" if lang == "mermaid" else r"(?:\[[^\n]*?\]\s*)?"
    khai = (r"^\s*([A-Za-z_][\w]*)\s*[\[({\"]" if lang == "mermaid"
            else r"^\s*([A-Za-z_][\w]*)\s*\[")
    for dong in src.splitlines():
        for m in re.finditer(rf"([A-Za-z_][\w]*)\s*{nhan}{mui}\s*([A-Za-z_][\w]*)", dong):
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


# ---------------------------------------------------------------- DIAGRAM-07 flow

RE_TU_KHOA_C = re.compile(r"\b(if|else|for|while|do|switch|return|break|continue)\b")
RE_CASE = re.compile(r"\b(case\s+[^:]+|default)\s*:", re.M)
HINH_NUT = {"start": "([{}])", "end": "([{}])", "decision": "{{{}}}", "loop": "{{{}}}",
            "switch": "{{{}}}", "return": "[{}]", "stmt": "[{}]"}
DAI_NHAN = 60


@capability("diagram.flow")
def flow(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-07 — CDS-12.4; SDD-04. tc: "Nhánh if/else đủ"; undo `delete_created_files`.

    **Hai đường vào rất khác nhau, và kết quả nói rõ mình đến từ đường nào** (`source_kind`).
    Từ MÃ thì lưu đồ là một cách đọc của chính hàm ấy: mọi nhánh có trong mã đều có trong hình,
    và đó là thứ kiểm được. Từ MÔ TẢ thì mô hình vẽ, và khi ấy nó là một bản phác — người đọc
    phải biết mình đang cầm cái nào.

    **`if` không có `else` vẫn có cạnh SAI.** Điều kiện sai thì đi thẳng xuống dưới, không phải
    bế tắc; bỏ cạnh ấy đi là vẽ một hàm khác. Đó đúng là tc của hợp đồng.

    **`return` nối thẳng tới nút kết**, không nối xuống câu lệnh kế tiếp — mã sau `return` không
    chạy, và một mũi tên tới đó là một luồng không tồn tại.

    Bộ đọc CFG là bộ quét câu lệnh của `doc.api_ref` dùng lại, không phải tree-sitter (xem
    [DEV-072]): cùng lý do, và cùng phạm vi — họ C.
    """
    root = _root(ctx)
    nguon = str(params["source"]).strip()
    lang = params.get("lang") or "mermaid"
    tep, ten_ham = _tach_nguon_flow(root, nguon)

    if tep is None:
        return {"diagram": _flow_tu_mo_ta(ctx, nguon, lang)}

    than = _than_ham_c(tep, ten_ham)
    nut, canh = _cfg(than, ten_ham)
    return {"diagram": {"lang": lang, "src": _ve_cfg(nut, canh, lang),
                        "source_kind": "code", "nodes": nut, "edges": canh,
                        "function": ten_ham, "file": str(tep.relative_to(root))
                        if tep.is_relative_to(root) else str(tep)}}


def _tach_nguon_flow(root: Path, nguon: str) -> tuple[Path | None, str]:
    """`source` = `<đường dẫn>:<hàm>` hay một mô tả? Tách bằng ĐUÔI TỆP, không bằng dấu `:`.

    Một mô tả tiếng Việt có dấu hai chấm là chuyện thường ("vòng lặp chính: đọc rồi ghi"), nên
    lấy dấu `:` làm dấu hiệu thì mọi mô tả có dấu câu đều bị hiểu là đường dẫn.
    """
    from eide.caps.doc import DUOI_C
    if ":" not in nguon:
        return None, ""
    duong, _, ham = nguon.rpartition(":")
    p = Path(duong.strip()).expanduser()
    if p.suffix.lower() not in DUOI_C or not re.fullmatch(r"[A-Za-z_]\w*", ham.strip()):
        return None, ""
    f = p if p.is_absolute() else root / p
    if not f.is_file():
        raise EideError("E2000", f"Không có tệp `{duong}`", exists=[], candidates=[],
                        missing=[duong])
    return f, ham.strip()


def _than_ham_c(f: Path, ten: str) -> str:
    """Thân hàm `ten` trong tệp C, đã xóa chú thích và literal (giữ nguyên độ dài để cắt nhãn)."""
    from eide.caps.doc import RE_HAM, _bo_tien_xu_ly, _cau_lenh_ngoai, _lam_sach

    goc = f.read_text(encoding="utf-8", errors="replace")
    sach = _bo_tien_xu_ly(_lam_sach(goc))
    co: list[str] = []
    for dau, cuoi, ket in _cau_lenh_ngoai(sach):
        if ket != "{":
            continue
        m = RE_HAM.match(sach[dau:cuoi].strip())
        if not m:
            continue
        co.append(m.group("ten"))
        if m.group("ten") == ten:
            return sach[cuoi + 1:_dong_ngoac(sach, cuoi)]
    raise EideError("E2000", f"Không có hàm `{ten}` trong `{f.name}`",
                    exists=co, candidates=co, missing=[ten])


def _dong_ngoac(s: str, mo: int) -> int:
    """Vị trí `}` khớp với `{` ở `mo`."""
    sau = 0
    for i in range(mo, len(s)):
        if s[i] == "{":
            sau += 1
        elif s[i] == "}":
            sau -= 1
            if not sau:
                return i
    return len(s)


def _muc(s: str, i: int) -> int:
    """Bỏ qua khoảng trắng từ `i`."""
    while i < len(s) and s[i] in " \t\r\n":
        i += 1
    return i


def _khoi_hoac_cau(s: str, i: int) -> tuple[str, int]:
    """Thân của một `if`/`for`/`while`: một khối `{…}` hoặc đúng MỘT câu lệnh."""
    i = _muc(s, i)
    if i < len(s) and s[i] == "{":
        j = _dong_ngoac(s, i)
        return s[i + 1:j], j + 1
    j = s.find(";", i)
    j = len(s) if j < 0 else j
    return s[i:j], j + 1


def _ngoac_tron(s: str, i: int) -> tuple[str, int]:
    """Nội dung `(...)` bắt đầu từ dấu `(` đầu tiên sau `i`."""
    i = s.find("(", i)
    if i < 0:
        return "", len(s)
    sau, j = 0, i
    while j < len(s):
        if s[j] == "(":
            sau += 1
        elif s[j] == ")":
            sau -= 1
            if not sau:
                return s[i + 1:j], j + 1
        j += 1
    return s[i + 1:], len(s)


def _phan_tich(than: str) -> list[dict[str, Any]]:
    """Danh sách mục mức trên cùng của một thân hàm: stmt · if · loop · do · switch · return."""
    ra: list[dict[str, Any]] = []
    i, n = 0, len(than)
    while (i := _muc(than, i)) < n:
        if than[i] in ";{}":
            if than[i] == "{":                  # khối trần — mở phạm vi, không đổi luồng
                j = _dong_ngoac(than, i)
                ra += _phan_tich(than[i + 1:j])
                i = j + 1
                continue
            i += 1
            continue
        m = RE_TU_KHOA_C.match(than, i)
        tu = m.group(1) if m else ""
        if tu == "if":
            dk, i = _ngoac_tron(than, i)
            thi, i = _khoi_hoac_cau(than, i)
            khac: list[dict[str, Any]] = []
            j = _muc(than, i)
            if than[j:j + 4] == "else" and not (than[j + 4:j + 5] or " ").isalnum():
                nguoc, i = _khoi_hoac_cau(than, j + 4)
                khac = _phan_tich(nguoc)
            ra.append({"kind": "if", "cond": dk, "then": _phan_tich(thi), "else": khac})
        elif tu in ("while", "for"):
            dk, i = _ngoac_tron(than, i)
            th, i = _khoi_hoac_cau(than, i)
            ra.append({"kind": "loop", "cond": f"{tu} ({dk})", "body": _phan_tich(th)})
        elif tu == "do":
            th, i = _khoi_hoac_cau(than, i + 2)
            dk, i = _ngoac_tron(than, i)
            j = than.find(";", i)
            i = len(than) if j < 0 else j + 1
            ra.append({"kind": "do", "cond": f"while ({dk})", "body": _phan_tich(th)})
        elif tu == "switch":
            dk, i = _ngoac_tron(than, i)
            th, i = _khoi_hoac_cau(than, i)
            ra.append({"kind": "switch", "cond": f"switch ({dk})", "cases": _cac_case(th)})
        elif tu in ("return", "break", "continue"):
            j = than.find(";", i)
            j = len(than) if j < 0 else j
            ra.append({"kind": tu if tu == "return" else "jump", "text": than[i:j].strip(),
                       "tu": tu})
            i = j + 1
        else:
            j = _cuoi_cau(than, i)
            if (t := than[i:j].strip()):
                ra.append({"kind": "stmt", "text": t})
            i = j + 1
    return ra


def _cuoi_cau(s: str, i: int) -> int:
    """Vị trí `;` kết thúc một câu lệnh thường, bỏ qua `;` nằm trong ngoặc (`for(;;)`)."""
    sau = 0
    for j in range(i, len(s)):
        if s[j] in "([":
            sau += 1
        elif s[j] in ")]":
            sau -= 1
        elif s[j] == ";" and not sau:
            return j
        elif s[j] == "{" and not sau:
            return j
    return len(s)


def _cac_case(than: str) -> list[tuple[str, list[dict[str, Any]]]]:
    """`[(nhãn, thân)]` cho từng `case`/`default` mức trên cùng của một `switch`."""
    vt = [(m.start(), m.end(), m.group(0).rstrip(":").strip()) for m in RE_CASE.finditer(than)]
    ra: list[tuple[str, list[dict[str, Any]]]] = []
    for k, (_d, c, nhan) in enumerate(vt):
        het = vt[k + 1][0] if k + 1 < len(vt) else len(than)
        ra.append((nhan, _phan_tich(than[c:het])))
    return ra


class _Ctx:
    """Bộ đếm nút và ngăn xếp vòng lặp cho một lượt dựng CFG."""

    def __init__(self) -> None:
        self.nodes: list[dict[str, str]] = []
        self.edges: list[dict[str, str]] = []
        self.n = 0
        self.lap: list[tuple[str, str]] = []     # (đầu vòng, ra khỏi vòng) cho continue/break

    def nut(self, kind: str, label: str) -> str:
        self.n += 1
        i = f"n{self.n}"
        self.nodes.append({"id": i, "kind": kind, "label": _nhan_cfg(label)})
        return i

    def canh(self, a: str, b: str, nhan: str = "") -> None:
        self.edges.append({"from": a, "to": b, "label": nhan})


def _cfg(than: str, ten_ham: str) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    ng = _Ctx()
    dau = ng.nut("start", ten_ham)
    ket = ng.nut("end", "kết thúc")
    ng.lap.append((ket, ket))                    # `break`/`continue` ngoài vòng lặp: về nút kết
    vao = _day(_phan_tich(than), ket, ng, ket)
    ng.canh(dau, vao)
    return ng.nodes, ng.edges


def _day(items: list[dict[str, Any]], tiep: str, ng: _Ctx, ket: str) -> str:
    """Dựng ngược từ cuối: mỗi mục biết nút KẾ TIẾP của mình, nên nối được ngay lúc tạo."""
    cur = tiep
    for it in reversed(items):
        cur = _mot(it, cur, ng, ket)
    return cur


def _mot(it: dict[str, Any], tiep: str, ng: _Ctx, ket: str) -> str:
    loai = it["kind"]
    if loai == "return":
        i = ng.nut("return", it["text"])
        ng.canh(i, ket)                          # về nút KẾT, không xuống câu lệnh sau
        return i
    if loai == "jump":
        i = ng.nut("stmt", it["text"])
        dau_lap, ra_lap = ng.lap[-1]
        ng.canh(i, ra_lap if it["tu"] == "break" else dau_lap)
        return i
    if loai == "if":
        dk = ng.nut("decision", it["cond"])
        ng.canh(dk, _day(it["then"], tiep, ng, ket), "đúng")
        # Không có `else` thì nhánh sai đi THẲNG XUỐNG DƯỚI — vẫn là một cạnh, không phải bế tắc.
        ng.canh(dk, _day(it["else"], tiep, ng, ket) if it["else"] else tiep, "sai")
        return dk
    if loai == "loop":
        dk = ng.nut("loop", it["cond"])
        ng.lap.append((dk, tiep))
        ng.canh(dk, _day(it["body"], dk, ng, ket), "đúng")
        ng.lap.pop()
        ng.canh(dk, tiep, "sai")
        return dk
    if loai == "do":
        dk = ng.nut("loop", it["cond"])
        ng.lap.append((dk, tiep))
        vao = _day(it["body"], dk, ng, ket)
        ng.lap.pop()
        ng.canh(dk, vao, "đúng")
        ng.canh(dk, tiep, "sai")
        return vao                               # thân chạy TRƯỚC rồi mới xét điều kiện
    if loai == "switch":
        sw = ng.nut("switch", it["cond"])
        co_mac_dinh = False
        for nhan, than in it["cases"]:
            co_mac_dinh = co_mac_dinh or nhan == "default"
            ng.lap.append((sw, tiep))
            ng.canh(sw, _day(than, tiep, ng, ket), nhan)
            ng.lap.pop()
        if not co_mac_dinh:
            ng.canh(sw, tiep, "mặc định")
        return sw
    i = ng.nut("stmt", it["text"])
    ng.canh(i, tiep)
    return i


def _nhan_cfg(s: str) -> str:
    """Nhãn một nút. Cắt trước, CÂN BẰNG NGOẶC sau — cắt giữa `ghi(0xF4` để lại một ngoặc lẻ,
    và `diagram.lint` sẽ báo lệch ngoặc trên chính lược đồ mình vừa sinh."""
    t = re.sub(r"\s+", " ", str(s)).strip()
    if len(t) > DAI_NHAN:
        t = t[:DAI_NHAN - 1] + "…"
    t = t.replace('"', "'").replace("|", "/")
    for mo, dong in (("(", ")"), ("[", "]"), ("{", "}")):
        if t.count(mo) != t.count(dong):
            t = t.replace(mo, " ").replace(dong, " ")
    return re.sub(r"\s+", " ", t).strip() or "…"


def _ve_cfg(nut: list[dict[str, str]], canh: list[dict[str, str]], lang: str) -> str:
    if lang == "dot":
        hinh = {"start": "ellipse", "end": "ellipse", "decision": "diamond", "loop": "diamond",
                "switch": "diamond", "return": "box", "stmt": "box"}
        d = ["digraph flow {", "  rankdir=TB;"]
        d += [f'  {n["id"]} [shape={hinh[n["kind"]]}, label="{n["label"]}"];' for n in nut]
        d += [f'  {e["from"]} -> {e["to"]}'
              + (f' [label="{e["label"]}"];' if e["label"] else ";") for e in canh]
        return "\n".join(d) + "\n}\n"
    d = ["flowchart TB"]
    d += [f'  {n["id"]}' + HINH_NUT[n["kind"]].format(f'"{n["label"]}"') for n in nut]
    d += [f'  {e["from"]} -->' + (f'|{e["label"]}| ' if e["label"] else " ") + e["to"]
          for e in canh]
    return "\n".join(d) + "\n"


def _flow_tu_mo_ta(ctx: Context, mo_ta: str, lang: str) -> dict[str, Any]:
    """Đường thứ hai của bước 1: "từ mô tả: writer". Kết quả vẫn phải qua `lint`."""
    mo_dau = {"mermaid": ("flowchart", "graph"), "dot": ("digraph",)}[lang]
    resp = _gateway(ctx).run(
        "writer",
        f"Vẽ lưu đồ ({lang}) cho: {mo_ta}\n"
        f"Bắt đầu bằng `{mo_dau[0]}`. Nhánh điều kiện phải có ĐỦ cả hai lối ra.\n"
        "Chỉ mô tả những bước có trong yêu cầu, không thêm bước nào.",
        _SCHEMA_SEQ)
    src = (resp.data.get("src") or "").strip() + "\n"
    loi = ([{"message": f"dòng đầu không phải `{mo_dau[0]}`"}]
           if not src.lstrip().startswith(mo_dau) else
           [x for x in lint({"src": src, "lang": lang}, ctx)["issues"]
            if x["kind"] == KIND_CU_PHAP])
    if loi:
        raise EideError("E5002", f"Lưu đồ sinh ra không hợp lệ: {loi[0]['message']}",
                        source=mo_ta, issues=loi, src=src[:300])
    nut, canh = _doc_do_thi(src, lang)
    return {"lang": lang, "src": src, "source_kind": "description",
            "nodes": [{"id": n, "kind": "stmt", "label": n} for n in sorted(nut)],
            "edges": [{"from": a, "to": b, "label": ""} for a, b in canh]}


# ---------------------------------------------------------------- DIAGRAM-08 timing

# Tham số nào là CHU KỲ chứ không phải một khoảng giữa hai mép. `tCLK` là chu kỳ của chính tín
# hiệu clock; vẽ nó thành một mũi tên như `tSU` là nói sai một thứ người đọc dùng để chọn tốc độ.
TEN_CHU_KY = ("tclk", "tsclk", "tscl", "tcyc", "tperiod", "tcy")
BAC_THOI_GIAN = ((1.0, "s"), (1e-3, "ms"), (1e-6, "µs"), (1e-9, "ns"), (1e-12, "ps"))
SO_O_SONG = 8               # số ô của một sóng WaveDrom — đủ chỗ cho mép và nhãn, không rối


@capability("diagram.timing")
def timing(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-08 — CDS-12.4; EXTRACT-07 (fact `timing`); MEASURE-01 (`dataset_id`).
    tc: "WaveDrom hợp lệ"; grounding "Fact có nguồn"; undo `delete_created_files`.

    **Mỗi nhãn mang GIÁ TRỊ và NGUỒN.** Một giản đồ thời gian không có số thì vô dụng; có số mà
    không truy được nguồn thì nguy hiểm, vì người ta thiết kế mạch theo nó. Nên nhãn cạnh có
    dạng `tSU ≥ 100 ns [bme280.pdf#p27]`, và `facts` trả về đủ id để lần ngược.

    **`tCLK` thành chu kỳ, không thành mũi tên.** Nó là chu kỳ của chính tín hiệu clock chứ
    không phải khoảng giữa hai mép; vẽ nó như `tSU` là nói sai đúng con số mà người đọc dùng để
    chọn tốc độ bus.

    **Capture từ máy phân tích logic chưa làm được**: nó cần `dataset_id` của
    `measure.capture_signal` — mốc M5, cần phần cứng thật. Nói thẳng bằng E2000 kèm tên năng lực
    sẽ tạo ra dữ liệu ấy, xem [DEV-074]. Vẽ một dạng sóng "minh họa" thay cho mẫu đo thật là
    đúng thứ nhóm này sinh ra để tránh.
    """
    root = _root(ctx)
    src = str(params["source"]).strip()
    if _la_dataset(root, src):
        raise EideError("E2000", f"`{src}` là một bộ mẫu đo (capture), và chuyển mẫu thành "
                        "WaveDrom cần `measure.capture_signal` — mốc M5, chờ phần cứng thật "
                        "(DEV-074). Đường đã làm được: fact `timing` từ datasheet.",
                        exists=[], candidates=["measure.capture_signal"], missing=[src])

    ds = _fact_timing(root, src)
    if not ds:
        raise EideError("E2000", f"Không có fact `timing` nào khớp `{src}` — chạy "
                        "`extract.pdf_electrical` trên datasheet để có (tsu, th, tCLK)",
                        exists=[], candidates=["extract.pdf_electrical", "passport.import"],
                        missing=[f"timing:{src}"])

    chu_ky = next((f for f in ds if f["ten"].lower() in TEN_CHU_KY), None)
    canh = [f for f in ds if f is not chu_ky]
    wd = _wavedrom(src, chu_ky, canh)
    import json
    return {"diagram": {"lang": "wavedrom", "src": json.dumps(wd, ensure_ascii=False, indent=1),
                        "wavedrom": wd, "facts": [f["id"] for f in ds], "source": src}}


def _la_dataset(root: Path, src: str) -> bool:
    db = store.store_path(root)
    if not db.exists():
        return False
    with store.open_store(db) as c:
        try:
            return c.execute("SELECT 1 FROM measurement WHERE id=?", (src,)).fetchone() is not None
        except Exception:                       # noqa: BLE001 — store cũ chưa có bảng
            return False


def _fact_timing(root: Path, src: str) -> list[dict[str, Any]]:
    """Fact `timing` theo danh sách id, hoặc theo tiền tố chủ thể (`chip:bme280`).

    Hai dạng vì hợp đồng ghi "fact ids | dataset_id": id thì chính xác, tiền tố thì tiện — và
    người gõ tay bao giờ cũng gõ tên chip.
    """
    import json
    db = store.store_path(root)
    if not db.exists():
        return []
    ids = [x.strip() for x in re.split(r"[,\s]+", src) if x.strip()]
    with store.open_store(db) as c:
        if len(ids) > 1 or (ids and ids[0].startswith("f_")):
            rows = c.execute(
                "SELECT id, subject, value, unit, source_id, locator FROM fact"
                f" WHERE predicate='timing' AND id IN ({','.join('?' * len(ids))})"  # noqa: S608
                "   AND status NOT IN ('superseded','rejected')", tuple(ids)).fetchall()
        else:
            rows = c.execute(
                "SELECT id, subject, value, unit, source_id, locator FROM fact"
                " WHERE predicate='timing' AND (subject = ? OR subject LIKE ?)"
                "   AND status NOT IN ('superseded','rejected') ORDER BY subject",
                (src, f"{src}/%")).fetchall()
        nguon = {r[0]: r[1] for r in c.execute("SELECT id, uri FROM source")}

    ra = []
    for fid, subj, gt, don_vi, sid, loc in rows:
        try:
            v = json.loads(gt)
            vt = json.loads(loc) if loc else {}
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(v, dict):
            continue
        ra.append({"id": fid, "ten": str(subj).rsplit(":", 1)[-1],
                   "min": v.get("min"), "typ": v.get("typ"), "max": v.get("max"),
                   "unit": don_vi or "s",
                   "trich_dan": _trich_dan_nguon(nguon.get(sid), vt)})
    return ra


def _trich_dan_nguon(uri: str | None, loc: dict[str, Any]) -> str:
    if not uri:
        return ""
    ten = Path(uri).name
    return f"[{ten}#p{loc['page']}]" if loc.get("page") else f"[{ten}]"


def _nhan_thoi_gian(f: dict[str, Any]) -> str:
    """`tSU ≥ 100 ns [ds.pdf#p27]`. Ưu tiên `min` vì đó là con số ràng buộc thiết kế."""
    for khoa, dau in (("min", "≥"), ("typ", "≈"), ("max", "≤")):
        if isinstance(f.get(khoa), (int, float)):
            return f"{f['ten']} {dau} {_do_dai(float(f[khoa]))} {f['trich_dan']}".strip()
    return f"{f['ten']} (chưa có số) {f['trich_dan']}".strip()


def _do_dai(giay: float) -> str:
    for he, ten in BAC_THOI_GIAN:
        if abs(giay) >= he:
            gt = giay / he
            return f"{gt:.10g} {ten}"
    return f"{giay:g} s"


def _wavedrom(chu_the: str, chu_ky: dict[str, Any] | None,
              canh: list[dict[str, Any]]) -> dict[str, Any]:
    """Hai tín hiệu (CLK, DATA) và một cạnh cho mỗi tham số thời gian.

    Không cố suy vị trí thật của từng tham số trên trục: datasheet nói `tSU` đo từ đâu tới đâu
    bằng lời, và đoán vị trí là vẽ ra một khẳng định không có fact. Mỗi tham số vì thế là một
    cạnh có nhãn đầy đủ giá trị + nguồn, đặt lần lượt trên các mép — đủ để đọc, không giả vờ
    chính xác hơn dữ liệu.
    """
    nut_clk = list("." * SO_O_SONG)
    nut_data = list("." * SO_O_SONG)
    edge: list[str] = []
    ten_nut = "abcdefghijklmnopqrstuvwxyz"
    for i, f in enumerate(canh):
        vt = 1 + 2 * i
        if vt + 1 >= SO_O_SONG:
            break
        a, b = ten_nut[2 * i], ten_nut[2 * i + 1]
        nut_clk[vt] = a
        nut_data[vt + 1] = b
        edge.append(f"{a}~>{b} {_nhan_thoi_gian(f)}")

    clk: dict[str, Any] = {"name": "CLK", "wave": "p" + "." * (SO_O_SONG - 1),
                           "node": "".join(nut_clk)}
    if chu_ky:
        clk["period_label"] = _nhan_thoi_gian(chu_ky)
    data = {"name": "DATA", "wave": "x.3" + "." * (SO_O_SONG - 4) + "x",
            "data": ["hợp lệ"], "node": "".join(nut_data)}
    bo_qua = len(canh) - len(edge)
    tieu_de = (f"Giản đồ thời gian — {chu_the} · {len(canh) + (1 if chu_ky else 0)} fact"
               + (f" · {clk['period_label']}" if chu_ky else "")
               + (f" · {bo_qua} tham số không đủ chỗ vẽ" if bo_qua > 0 else ""))
    return {"signal": [clk, data], "edge": edge,
            "head": {"text": tieu_de}, "config": {"hscale": 2}}


# ---------------------------------------------------------------- DIAGRAM-11 gantt

# Trạng thái trong bảng `feature` → thẻ của mermaid gantt. `failing` là trạng thái KHỞI ĐẦU mà
# `arch.to_plan` ghi ("chưa đạt"), không phải "đã hỏng" — nên nó là việc đang làm.
THE_GANTT = {"passing": "done", "failing": "active"}
NGAY_MAC_DINH = 1440        # phút, dùng làm chỗ giữ chỗ khi chưa có kế hoạch để ước lượng


@capability("diagram.gantt")
def gantt(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-11 — CDS-12.4; PLAN-03/05 (`plans/<feature>.json`, `plan.estimate`);
    DDD-14 §2 Feature. tc: "Feature passing đánh dấu done"; undo `delete_created_files`.

    **Trạng thái lấy từ store, không vẽ tay** — một Gantt vẽ tay là thứ đẹp lên theo thời gian
    trong khi dự án thì không. `passing` → `done`, và đó là toàn bộ tc của hợp đồng.

    **Ước lượng lấy từ `plan.estimate`, không có thì NÓI RA.** Mermaid bắt buộc mỗi việc phải có
    độ dài, nên việc chưa có kế hoạch vẫn phải nhận một con số — và đúng lúc ấy nhãn ghi "chưa
    ước lượng". Nhận một con số mặc định rồi im lặng là biến chỗ giữ chỗ thành ước lượng, mà
    người đọc Gantt thì đọc độ dài cột trước khi đọc chữ.

    `plan_id` trỏ một kế hoạch cụ thể thì vẽ CÁC BƯỚC của nó: người hỏi đang xem một tính năng,
    không xem cả dự án.
    """
    from datetime import UTC, datetime

    from eide.caps.plan import doc_plan_feature, estimate

    root = _root(ctx)
    if (pid := params.get("plan_id")):
        d = doc_plan_feature(root, str(pid))
        if not d:
            raise EideError("E2000", f"Không có kế hoạch nào tên `{pid}` trong `.eide/plans/`",
                            exists=_ten_plan(root), candidates=["plan.create"],
                            missing=[f"plan:{pid}"])
        phut = int((estimate({"plan": d.get("plan") or {}}, ctx)["estimate"] or {})
                   .get("minutes") or NGAY_MAC_DINH)
        buoc = list((d.get("plan") or {}).get("steps") or [])
        moi = max(1, round(phut / max(1, len(buoc))))
        tasks = [{"id": _ma_gantt(s.get("id") or f"s{i}"),
                  "label": _nhan_gantt(f"{s.get('goal') or '?'} · {s.get('cap') or ''}"),
                  "tag": "", "minutes": moi, "estimated": True} for i, s in enumerate(buoc)]
        tieu_de = f"Kế hoạch {pid}"
    else:
        tasks = _task_tu_feature(root, ctx)
        tieu_de = f"Tiến độ tính năng — {_ten_du_an_dg(root)}"

    if not tasks:
        raise EideError("E2000", "Chưa có tính năng hay kế hoạch nào để vẽ — chạy `arch.to_plan` "
                        "(sinh Feature từ ModuleGraph) hoặc `plan.create`",
                        exists=[], candidates=["arch.to_plan", "plan.create", "plan.decompose"],
                        missing=["feature"])

    hom_nay = datetime.now(UTC).date().isoformat()
    d = ["gantt", "    dateFormat YYYY-MM-DD", "    axisFormat %d/%m",
         f"    title {tieu_de}",
         "    %% Độ dài lấy từ plan.estimate; việc chưa có kế hoạch ghi rõ trong nhãn.",
         "    section Công việc"]
    truoc: str | None = None
    for t in tasks:
        bd = hom_nay if truoc is None else f"after {truoc}"
        the = f"{t['tag']}, " if t["tag"] else ""
        d.append(f"    {t['label']} :{the}{t['id']}, {bd}, {t['minutes']}m")
        truoc = t["id"]
    return {"diagram": {"lang": "mermaid", "src": "\n".join(d) + "\n",
                        "tasks": tasks, "model_ref": "feature"}}


def _task_tu_feature(root: Path, ctx: Context) -> list[dict[str, Any]]:
    from eide.caps.plan import doc_plan_feature, estimate
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        rows = c.execute("SELECT id, title, status FROM feature ORDER BY updated_at, id").fetchall()
    ra = []
    for fid, title, tt in rows:
        d = doc_plan_feature(root, str(fid))
        co = bool(d and (d.get("plan") or {}).get("steps"))
        phut = (int(estimate({"plan": d["plan"]}, ctx)["estimate"]["minutes"]) if co
                else NGAY_MAC_DINH)
        ra.append({"id": _ma_gantt(fid), "feature": fid,
                   "label": _nhan_gantt(title) + ("" if co else " (chưa ước lượng)"),
                   "tag": THE_GANTT.get(str(tt), ""), "minutes": phut, "estimated": co})
    return ra


def _ten_plan(root: Path) -> list[str]:
    d = root / EIDE_DIR / "plans"
    return sorted(f.stem for f in d.glob("*.json")) if d.is_dir() else []


def _ma_gantt(x: str) -> str:
    return re.sub(r"[^0-9A-Za-z]+", "_", str(x))[:40] or "t"


def _nhan_gantt(x: str) -> str:
    """Nhãn một việc trong gantt. Dữ liệu không được phá cú pháp của lược đồ.

    `:` cắt đôi một dòng gantt (nó là dấu ngăn giữa nhãn và thẻ), còn ngoặc lệch làm chính
    `diagram.lint` báo lỗi trên lược đồ mình vừa sinh. Tiêu đề tính năng là dữ liệu người dùng
    nhập, nên nó sẽ có cả hai — sớm hay muộn.
    """
    return re.sub(r"\s+", " ", re.sub(r"[():\[\]{},]", " ", str(x))).strip() or "việc"


def _ten_du_an_dg(root: Path) -> str:
    import yaml
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return str((cu.get("project") or {}).get("name") or root.name)


# ---------------------------------------------------------------- DIAGRAM-05 sequence

# Participant khai tường minh, và participant khai NGẦM ngay trong mũi tên. Mermaid cho phép cả
# hai; chỉ kiểm dòng `participant` thì hàng rào có một cửa mở, và mô hình đi qua đúng cửa ấy.
RE_PARTICIPANT = re.compile(r"^\s*(?:participant|actor)\s+([A-Za-z_]\w*)", re.M)
RE_MUI_TEN_SEQ = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:-{1,2}>>?|<-{1,2}|x-{1,2}>|-{1,2}\)\s*)"
                            r"\s*([A-Za-z_]\w*)\s*:", re.M)
MO_DAU_SEQ = {"mermaid": "sequenceDiagram", "plantuml": "@startuml"}

_SCHEMA_SEQ = {"type": "object", "required": ["src"],
               "properties": {"src": {"type": "string"}}}


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


@capability("diagram.sequence")
def sequence(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-05 — CDS-12.4; SDD-04; ARCH-02 (ModuleGraph), ARCH-03 (HwMap), ARCH-07
    (`module.fsm`); CXD-10 (`memory.compose` vai `writer`). tc: "Participant khớp module";
    lỗi E5002; undo `delete_created_files`.

    **Lược đồ duy nhất của nhóm do mô hình sinh — nên là lược đồ duy nhất cần hàng rào.** Bước 1
    nói thẳng "writer sinh", và đúng như thế: một kịch bản là một câu chuyện về thứ tự, mà thứ
    tự thì không nằm sẵn trong store như `module.depends` hay `module.fsm`. Nhưng cái giá của
    việc để mô hình viết là nó thêm được một module nghe rất hợp lý mà ModuleGraph không có —
    và lược đồ tuần tự trông thuyết phục hơn mọi lược đồ khác, nên đây là lỗi đắt nhất của cả
    nhóm `diagram.*`.

    Vì thế **mọi participant phải có thật**: module (ARCH-02), ngoại vi trong HwMap (ARCH-03),
    hoặc một ISR nhận ra được theo đúng quy ước tên mà `code.static` dùng. Không khớp → E5002
    kèm danh sách tên bịa, chứ không lặng lẽ vẽ ra.

    **Chưa có module nào thì E2000 TRƯỚC KHI hỏi mô hình**: "participant khớp module" không kiểm
    được, nên câu trả lời chắc chắn bị bỏ — hỏi rồi mới phát hiện là tiêu tiền cho một câu trả
    lời đã biết là sẽ vứt.
    """
    from eide.caps.arch import _doc_module

    root = _root(ctx)
    lang = params.get("lang") or "mermaid"
    scenario = str(params["scenario"])
    mods = _doc_module(root, None)
    if not mods:
        raise EideError("E2000", "Chưa có module nào — chạy `arch.decompose` trước; "
                        "\"participant khớp module\" không kiểm được trên một ModuleGraph rỗng",
                        exists=[], candidates=["arch.decompose"], missing=["module"])

    cho_phep, ngoai_vi = _participant_hop_le(root, mods)
    from eide.caps.memory import compose
    b = compose({"role": "writer", "task_ref": scenario}, ctx)["bundle"]
    ngu_canh = "\n\n".join(x["text"] for x in b["blocks"] if x["layer"] != "C1")

    resp = _gateway(ctx).run(
        "writer",
        f"Vẽ sơ đồ tuần tự ({lang}) cho kịch bản: {scenario}\n"
        f"CHỈ được dùng những participant sau, đúng định danh: {', '.join(sorted(cho_phep))}\n"
        + (f"Ngoại vi kèm địa chỉ đã biết: {ngoai_vi}\n" if ngoai_vi else "")
        + "Thông điệp là lời gọi hàm hoặc giao dịch bus; giao dịch bus phải ghi địa chỉ lấy từ "
          "danh sách trên, không tự nghĩ ra địa chỉ nào.\n"
        f"Bắt đầu bằng `{MO_DAU_SEQ[lang]}`.",
        _SCHEMA_SEQ, system_extra=ngu_canh)

    src = (resp.data.get("src") or "").strip() + "\n"
    if not src.strip().startswith(MO_DAU_SEQ[lang]):
        raise EideError("E5002", f"Mô hình không trả về sơ đồ tuần tự {lang} — dòng đầu là "
                        f"`{src.strip().splitlines()[0][:40] if src.strip() else ''}`, chờ "
                        f"`{MO_DAU_SEQ[lang]}`", scenario=scenario, src=src[:300])
    if (loi := [x for x in lint({"src": src, "lang": lang}, ctx)["issues"]
                if x["kind"] == KIND_CU_PHAP]):
        raise EideError("E5002", f"Sơ đồ tuần tự sinh ra không hợp lệ: {loi[0]['message']}",
                        scenario=scenario, issues=loi, src=src[:300])

    ds = _participant_seq(src)
    # ISR không nằm trong bảng nào của store — nó là một hàm trong mã, và bảng duy nhất biết nó
    # là quy ước đặt tên. Nhận theo TỪ VỰNG, đúng bảng `code.static` dùng.
    if (la := sorted(x for x in set(ds) - cho_phep if not _la_isr(x))):
        raise EideError("E5002", f"{len(la)} participant không có trong ModuleGraph/HwMap: "
                        f"{', '.join(la)} — lược đồ đang kể một hệ thống khác với hệ thống đã "
                        "thiết kế", scenario=scenario, unknown=la,
                        allowed=sorted(cho_phep), src=src[:300])
    return {"diagram": {"lang": lang, "src": src, "scenario": scenario,
                        "participants": ds, "model_ref": "module"}}


def _participant_hop_le(root: Path, mods: list[dict[str, Any]]) -> tuple[set[str], str]:
    """`(tập tên cho phép, mô tả ngoại vi kèm địa chỉ)` — module, ngoại vi trong HwMap, ISR."""
    import json
    cho_phep = {str(m["id"]) for m in mods} | {str(m["name"]) for m in mods if m.get("name")}
    ngoai_vi: dict[str, str] = {}
    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            try:
                for (tn,) in c.execute("SELECT DISTINCT resource FROM hw_map"):
                    ngoai_vi[str(tn).rsplit(":", 1)[-1].upper()] = ""
            except Exception:                   # noqa: BLE001 — store cũ chưa có bảng
                pass
            for subj, gt in c.execute(
                    "SELECT subject, value FROM fact WHERE predicate IN ('address','base_address')"
                    "  AND status NOT IN ('superseded','rejected')"):
                ten = str(subj).rsplit(":", 1)[-1].upper()
                if ten in ngoai_vi:
                    try:
                        ngoai_vi[ten] = str(json.loads(gt))
                    except (json.JSONDecodeError, TypeError):
                        pass
    return cho_phep | set(ngoai_vi), ", ".join(
        f"{k} ({v})" if v else k for k, v in sorted(ngoai_vi.items()))


def _participant_seq(src: str) -> list[str]:
    """Tên participant theo thứ tự xuất hiện — cả khai tường minh lẫn khai ngầm trong mũi tên."""
    ra: list[str] = []
    for ten in RE_PARTICIPANT.findall(src):
        if ten not in ra:
            ra.append(ten)
    for a, b in RE_MUI_TEN_SEQ.findall(src):
        for x in (a, b):
            if x not in ra:
                ra.append(x)
    return ra


# ISR nhận ra bằng TỪ VỰNG, đúng bảng mà `code.static` dùng (CMSIS/STM32, avr-libc). Đặt ở đây
# một tham chiếu chứ không chép lại: hai bảng cùng nghĩa sẽ lệch nhau.
def _la_isr(ten: str) -> bool:
    from eide.caps.code import RE_TEN_ISR
    return bool(RE_TEN_ISR.fullmatch(ten))


# ---------------------------------------------------------------- DIAGRAM-09 memory_map

# Dòng tiêu đề section trong tệp `.map` của GNU ld: `.text  0x08000000  0x1a2c` — ĐÚNG BA cột.
# `code.py::RE_MAP` bắt dòng bốn cột (ký hiệu kèm tệp .obj); ở đây cần dòng tổng của cả section,
# nên nó là một biểu thức khác chứ không phải cùng một cái dùng lỏng tay hơn.
RE_SECTION_MAP = re.compile(r"^(\.[\w.]+)[ \t]+0x([0-9a-fA-F]+)[ \t]+0x([0-9a-fA-F]+)[ \t]*$",
                            re.MULTILINE)
CAO_TOI_DA, CAO_TOI_THIEU = 320, 18      # px cho vùng lớn nhất / nhỏ nhất


@capability("diagram.memory_map")
def memory_map(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-09 — CDS-12.4; PASSPORT-02 (`passport.query`); CODE-06 (`code.size` đọc
    `.map`). tc: "Vùng đúng địa chỉ"; undo `delete_created_files`.

    **Địa chỉ gốc là thứ dễ sai nhất và khó thấy nhất.** Một bản đồ vẽ nhầm `0x08000000` thành
    `0x00000000` vẫn xếp hình chữ nhật đẹp như thường; chỉ đến lúc nạp mới biết. Nên vùng lấy
    thẳng từ fact `memory_size` + `base_address` của hộ chiếu, và mỗi vùng mang theo `fact_ids`
    để truy ngược.

    **Section xếp theo ĐỊA CHỈ, không theo tên.** `.data` nằm trong flash (ảnh nạp) hay trong RAM
    (sau khi chép) tùy chip và tùy linker script — quy ước tên đúng ở đa số chip và sai lặng lẽ ở
    số còn lại. Section rơi ra ngoài mọi vùng thì **nói ra**: đó là dấu hiệu linker script sai
    hoặc hộ chiếu thiếu vùng, và bỏ nó đi thì bản đồ trông đầy đủ trong khi có một mảnh không
    biết nằm đâu.

    **Tỷ lệ là điểm của cả lược đồ** (bước 1: "SVG có tỷ lệ"). Vẽ flash 512 kB bằng ram 128 kB
    thì bản đồ thành một cái bảng, mà thứ người ta nhìn bản đồ để thấy chính là "còn bao nhiêu
    chỗ". Vùng nhỏ vẫn có chiều cao tối thiểu để còn đọc được nhãn.
    """
    root = _root(ctx)
    part = str(params["passport"]).split("@")[0]
    vung = _vung_bo_nho(root, part)
    if not vung:
        raise EideError("E2000", f"Chưa có fact `memory_size` nào cho `{part}` — chạy "
                        "`extract.svd` (hoặc `extract.pdf_electrical`) rồi `passport.import`",
                        exists=[], candidates=["extract.svd", "passport.import"],
                        missing=[f"memory_size:{part}"])

    sections = _section_linker(root, params.get("linker"), vung)
    _ty_le(vung)
    src = _svg_memory_map(part, vung, sections, bool(params.get("linker")))
    return {"diagram": {"lang": "svg", "src": src, "passport": part,
                        "regions": vung, "sections": sections}}


def _vung_bo_nho(root: Path, part: str) -> list[dict[str, Any]]:
    """`[{name, base, size, fact_ids}]` từ `memory_size` + `base_address` của hộ chiếu chip.

    Dùng lại đúng phép tra của `arch._gioi_han_bo_nho` về mặt điều kiện `subject` — cùng câu hỏi
    thì phải cùng câu trả lời — nhưng giữ TÊN VÙNG thật (`sram1`, `ccmram`) thay vì gộp về
    flash/ram: bản đồ bộ nhớ là chỗ duy nhất phân biệt chúng có ích.
    """
    import json

    from eide.caps.req import DON_VI
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value, unit FROM fact"
            " WHERE predicate IN ('memory_size','base_address')"
            "   AND (subject = ? OR subject LIKE ? OR subject LIKE ?)"
            "   AND status NOT IN ('superseded','rejected')",
            (part, f"%:{part}", f"%:{part}/%")).fetchall()

    gom: dict[str, dict[str, Any]] = {}
    for fid, subj, vt, gt, don_vi in rows:
        ten = str(subj).rsplit("/", 1)[-1].split(":")[-1].lower()
        if ten == part.lower():
            continue
        d = gom.setdefault(ten, {"name": ten, "base": None, "size": 0, "fact_ids": []})
        try:
            gia_tri = json.loads(gt)
        except (json.JSONDecodeError, TypeError):
            gia_tri = gt
        if vt == "memory_size":
            try:
                d["size"] = int(float(gia_tri) * (DON_VI.get((don_vi or "").lower())
                                                  or ("", 1))[1])
            except (ValueError, TypeError):
                continue
        else:
            d["base"] = _so(gia_tri)
        d["fact_ids"].append(fid)

    # Chỉ giữ vùng có KÍCH THƯỚC. Một `base_address` lẻ loi không vẽ được thành hình chữ nhật, và
    # vẽ nó với chiều cao bịa ra là đúng thứ bản đồ này sinh ra để tránh.
    return sorted((v for v in gom.values() if v["size"] > 0),
                  key=lambda v: (v["base"] is None, v["base"] or 0))


def _so(x: Any) -> int | None:
    try:
        return int(str(x), 0) if isinstance(x, str) else int(x)
    except (ValueError, TypeError):
        return None


def _section_linker(root: Path, linker: str | None,
                    vung: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """`[{name, base, size, region}]` từ tệp `.map`. `region=""` nghĩa là ngoài mọi vùng."""
    if not linker:
        return []
    f = Path(linker).expanduser()
    if not f.is_absolute():
        f = root / f
    if not f.is_file():
        return []
    ra: list[dict[str, Any]] = []
    for ten, dc, kt in RE_SECTION_MAP.findall(f.read_text(encoding="utf-8", errors="replace")):
        if (n := int(kt, 16)) <= 0:
            continue
        goc = int(dc, 16)
        ra.append({"name": ten, "base": goc, "size": n, "region": _thuoc_vung(goc, vung)})
    return ra


def _thuoc_vung(dia_chi: int, vung: list[dict[str, Any]]) -> str:
    for v in vung:
        if v["base"] is not None and v["base"] <= dia_chi < v["base"] + v["size"]:
            return str(v["name"])
    return ""


def _ty_le(vung: list[dict[str, Any]]) -> None:
    """Gán `px` cho từng vùng theo tỷ lệ kích thước thật, có sàn để nhãn còn đọc được."""
    lon = max((v["size"] for v in vung), default=1) or 1
    for v in vung:
        v["px"] = max(CAO_TOI_THIEU, round(CAO_TOI_DA * v["size"] / lon))


def _svg_memory_map(part: str, vung: list[dict[str, Any]], sections: list[dict[str, Any]],
                    co_linker: bool) -> str:
    le, rong, x = 24, 200, 150
    cao = sum(v["px"] for v in vung) + le * 2 + 40 * (len(vung) - 1) + 40
    d = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{x + rong + 300}" height="{cao}" '
         f'viewBox="0 0 {x + rong + 300} {cao}" font-family="monospace" font-size="12">',
         f'  <title>Bản đồ bộ nhớ {_thoat_xml(part)}</title>']
    y = le
    for v in vung:
        dung = [s for s in sections if s["region"] == v["name"]]
        da = sum(s["size"] for s in dung)
        cao_dung = round(v["px"] * min(da / v["size"], 1)) if v["size"] else 0
        goc = f'0x{v["base"]:08X}' if v["base"] is not None else "địa chỉ gốc chưa có fact"
        d += [f'  <rect x="{x}" y="{y}" width="{rong}" height="{v["px"]}" fill="#f4f4f4" '
              'stroke="#333"/>',
              f'  <text x="{x - 8}" y="{y + 12}" text-anchor="end">{_thoat_xml(goc)}</text>',
              f'  <text x="{x + rong + 10}" y="{y + 14}">{_thoat_xml(v["name"])} · '
              f'{_kb(v["size"])}</text>']
        if cao_dung:
            # Tô từ ĐỈNH xuống: nhãn địa chỉ gốc nằm ở đỉnh, nên trục địa chỉ tăng dần
            # xuống dưới, và phần đã dùng bắt đầu ngay tại địa chỉ gốc. Tô từ đáy lên thì hình
            # vẫn "đúng bao nhiêu phần trăm" nhưng nói sai chỗ nào đang bị chiếm.
            d += [f'  <rect x="{x}" y="{y}" width="{rong}" '
                  f'height="{cao_dung}" fill="#9cc" stroke="none"/>',
                  f'  <text x="{x + rong + 10}" y="{y + 30}" fill="#357">đã dùng {_kb(da)} '
                  f'({round(da / v["size"] * 100)}%): '
                  f'{_thoat_xml(", ".join(s["name"] for s in dung))}</text>']
        y += v["px"] + 40
    if not co_linker:
        d.append(f'  <text x="{x}" y="{y + 10}" fill="#666">Phần đã dùng: chưa có — truyền '
                 '`linker` (tệp .map của code.build) để thấy .text/.data/.bss</text>')
    if (lac := [s for s in sections if not s["region"]]):
        d.append(f'  <text x="{x}" y="{y + 10}" fill="red">⚠ {len(lac)} section ngoài mọi vùng '
                 f'của hộ chiếu: {_thoat_xml(", ".join(s["name"] for s in lac))} — linker script '
                 'sai vùng, hoặc hộ chiếu còn thiếu vùng nhớ</text>')
    d.append("</svg>")
    return "\n".join(d) + "\n"


def _kb(n: int) -> str:
    """Nhãn dung lượng. `KiB`, không phải `kB` — bảng đơn vị của chính kho (`req.DON_VI`) đọc
    `kb` là 1000 byte và `kib` là 1024. Ghi "512 kB" cho 524288 byte là tự mâu thuẫn với phép
    quy đổi mà `arch.memory_budget` và `code.size` đang dùng."""
    return f"{n / 1024:.0f} KiB" if n >= 1024 else f"{n} B"


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


# ---------------------------------------------------------------- DIAGRAM-14 sync

# Trạng thái và chuyển trong lược đồ Mermaid `stateDiagram-v2`:  A --> B : nhãn
RE_CHUYEN_MM = re.compile(r"^\s*(\w+)\s*-->\s*(\w+)\s*(?::\s*(.*))?$", re.M)
# Bảng chuyển trong mã C: `case ST_IDLE:` … `state = ST_RUN;`
RE_CASE_C = re.compile(r"\bcase\s+([A-Z][A-Z0-9_]*)\s*:")
RE_GAN_TRANG_THAI = re.compile(r"\b(?:state|st|fsm)\w*\s*=\s*([A-Z][A-Z0-9_]*)\s*;", re.I)

# Lệch bao nhiêu thì thôi tự áp. "Lệch lớn" của hợp đồng đo bằng TỈ LỆ chứ không bằng số tuyệt
# đối: thiếu 2 trạng thái trong một FSM 3 trạng thái là viết lại, còn trong FSM 30 trạng thái
# là quên hai nhánh.
TI_LE_LECH_LON = 0.34


@capability("diagram.sync", features=["scope"])
def sync(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-14 — CDS-12.4. R0, tier **T1***, `errors: [E3000]`, `undo: none`.
    tc: TC-73.

    **So lược đồ với MÃ, không so với trí nhớ.** Trạng thái trong `stateDiagram-v2` đối chiếu
    với `case ST_…:` và các phép gán `state = ST_…;` trong mã. Đây là chỗ một tài liệu kỹ thuật
    nói dối êm ái nhất: lược đồ vẽ đúng hồi thiết kế, mã đi tiếp, và không ai sửa hình.

    **`check` là mặc định, và đó là chủ ý.** Hợp đồng cho ba hướng (`check`/`to_code`/
    `from_code`) nhưng chỉ `check` không đổi gì. Mặc định vào một hướng ghi là để một lời gọi
    thiếu tham số đi sửa mã.

    **Lệch LỚN thì E3000 thay vì tự áp** — tier T1* nghĩa là tự làm phần hẹp. Ranh giới đo bằng
    TỈ LỆ: thiếu 2 trạng thái trong FSM 3 trạng thái là viết lại cả máy trạng thái, còn trong
    FSM 30 trạng thái là quên hai nhánh. Một ngưỡng tuyệt đối sẽ đúng ở một cỡ và sai ở cỡ kia.

    `to_code`/`from_code` trả `diff` và `applied: false` kèm lý do: sinh patch cho mã C cần
    tree-sitter (hợp đồng nêu đích danh), và viết một bộ sinh patch bằng regex cho ngôn ngữ có
    tiền xử lý là cách chắc chắn làm hỏng mã người khác. Xem DEV-090.
    """
    root = _root(ctx)
    huong = params.get("direction") or "check"
    db = store.store_path(root)
    with store.open_store(db) as c:
        r = c.execute("SELECT id, kind, lang, src, source_ref FROM diagram WHERE id=?",
                      (params["diagram_id"],)).fetchone()
    if not r:
        raise EideError("E2000", f"Không có lược đồ `{params['diagram_id']}`",
                        exists=[], candidates=["diagram.state"], missing=[params["diagram_id"]])
    did, kind, _lang, src, _ref = r

    trong_hinh = _trang_thai_tu_hinh(src) if kind == "state" else _nut_tu_hinh(src)
    trong_ma = _trang_thai_tu_ma(root) if kind == "state" else _module_tu_store(root)

    thieu_ma = sorted(trong_hinh - trong_ma)      # hình có, mã không
    thieu_hinh = sorted(trong_ma - trong_hinh)    # mã có, hình không
    diff = {"kind": kind, "in_diagram_only": thieu_ma, "in_code_only": thieu_hinh,
            "n_diagram": len(trong_hinh), "n_code": len(trong_ma)}

    lech = len(thieu_ma) + len(thieu_hinh)
    mau = max(len(trong_hinh | trong_ma), 1)
    diff["drift_ratio"] = round(lech / mau, 3)
    diff["stale"] = lech > 0

    with store.open_store(db) as c:
        c.execute("UPDATE diagram SET stale=? WHERE id=?", (1 if lech else 0, did))
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))

    if huong == "check":
        return {"diff": diff, "applied": False}

    if diff["drift_ratio"] > TI_LE_LECH_LON:
        raise EideError("E3000", f"Lệch {diff['drift_ratio']:.0%} giữa lược đồ và mã — quá lớn "
                        f"để tự áp ({huong}). Người xem `diff` rồi quyết.",
                        gate_id="G3", diff=diff, direction=huong)
    return {"diff": diff, "applied": False,
            "reason": "Sinh patch cho mã C cần tree-sitter (DIAGRAM-14 nêu đích danh); "
                      "chưa hiện thực — xem DEVIATIONS DEV-090. `diff` ở trên là thật và đủ "
                      "để sửa tay."}


def _trang_thai_tu_hinh(src: str) -> set[str]:
    ra: set[str] = set()
    for a, b, _ in RE_CHUYEN_MM.findall(src or ""):
        ra.update({a, b})
    return {x for x in ra if x not in ("[*]",)}


def _nut_tu_hinh(src: str) -> set[str]:
    return set(re.findall(r"^\s*(\w+)\s*[\[(\{]", src or "", re.M))


def _trang_thai_tu_ma(root: Path) -> set[str]:
    """Trạng thái thấy trong mã: nhãn `case` và vế phải của phép gán trạng thái."""
    ra: set[str] = set()
    for f in sorted((root / "src").rglob("*.c")) + sorted((root / "src").rglob("*.h")):
        van = f.read_text(encoding="utf-8", errors="replace")
        ra.update(RE_CASE_C.findall(van))
        ra.update(RE_GAN_TRANG_THAI.findall(van))
    return ra


def _module_tu_store(root: Path) -> set[str]:
    db = store.store_path(root)
    if not db.exists():
        return set()
    with store.open_store(db) as c:
        return {r[0] for r in c.execute("SELECT name FROM module").fetchall()}


# ---------------------------------------------------------------- DIAGRAM-12 from_image

_SCHEMA_DO_THI = {
    "type": "object",
    "properties": {
        "nodes": {"type": "array", "items": {
            "type": "object",
            "properties": {"id": {"type": "string"}, "label": {"type": "string"},
                           "shape": {"type": "string"}},
            "required": ["id", "label"], "additionalProperties": False}},
        "edges": {"type": "array", "items": {
            "type": "object",
            "properties": {"from": {"type": "string"}, "to": {"type": "string"},
                           "label": {"type": "string"}},
            "required": ["from", "to"], "additionalProperties": False}},
        "confidence": {"type": "number"},
        "unreadable": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["nodes", "edges", "confidence"], "additionalProperties": False,
}

# Dưới ngưỡng này thì lược đồ vào trạng thái CHỜ DUYỆT thay vì dùng ngay — `ask_when` của
# DIAGRAM-12 là "Độ tin cậy thấp". 0,6 chứ không 0,5: một lược đồ vẽ tay đọc đúng một nửa thì
# phần sai nằm rải rác chứ không gom lại, nên nó tệ hơn không có lược đồ nào.
NGUONG_TIN = 0.6


@capability("diagram.from_image")
def from_image(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DIAGRAM-12 — CDS-12.4; vai trò `cartographer` (vision). R0, `errors: [E5002]`,
    ask "Độ tin cậy thấp", `undo: none`.

    Ảnh sơ đồ (kể cả vẽ tay) → mã Mermaid/DOT. Đây là năng lực dễ trông có vẻ chạy tốt nhất
    trong cả sản phẩm, và vì thế là chỗ cần thận trọng nhất: mô hình luôn trả về MỘT đồ thị nào
    đó, kể cả khi nó chỉ đọc được ba nút trong hai mươi.

    **Vì thế `confidence` là trường BẮT BUỘC trong schema, không phải trường tuỳ chọn.** Buộc mô
    hình tự chấm, rồi so với ngưỡng bằng mã — dưới {NGUONG_TIN} thì lược đồ ghi ra với
    `stale = 1` và `needs_review`, chứ không dùng ngay. `unreadable[]` đi kèm cùng lý do với
    `extract.image_schematic`.

    Sinh mã bằng MÃ, không nhờ mô hình viết Mermaid. Mô hình trả `{nodes, edges}` — một cấu trúc
    nó khó sai — còn cú pháp lược đồ thì ta dựng, nên không bao giờ có chuyện nhận về một đoạn
    Mermaid không phân tích được. Cùng khuôn với `diagram.state`/`diagram.flow`.
    """
    root = _root(ctx)
    from eide.caps.extract import _doc_anh
    anh = _doc_anh(root, params["image"])
    ngon_ngu = params.get("target_lang") or "mermaid"

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    resp = gw.run(
        "cartographer",
        "Đọc sơ đồ trong ảnh (có thể vẽ tay) thành một đồ thị. `nodes` là các khối, `edges` là "
        "các mũi tên nối chúng. `confidence` 0–1 là mức tự tin của CHÍNH BẠN về việc đã đọc "
        "đúng và đủ — hãy chấm thấp nếu ảnh mờ hoặc còn khối không đọc được, và liệt kê chúng "
        "vào `unreadable`. Một đồ thị thiếu nửa số nút mà chấm 0,9 là sai hơn cả đọc sai.",
        _SCHEMA_DO_THI, anh=[anh])

    nut = list(resp.data.get("nodes") or [])
    canh = list(resp.data.get("edges") or [])
    if not nut:
        raise EideError("E5002", "Mô hình không đọc được khối nào trong ảnh",
                        image=params["image"])
    tin = round(float(resp.data.get("confidence") or 0.0), 3)

    # Cạnh trỏ tới một nút không tồn tại là dấu hiệu rõ nhất của một lượt đọc hỏng — bỏ nó và
    # HẠ điểm tin, chứ không im lặng sửa. `diagram.lint` sẽ bắt được, nhưng lúc ấy đã muộn hơn.
    co = {n["id"] for n in nut}
    treo = [e for e in canh if e.get("from") not in co or e.get("to") not in co]
    canh = [e for e in canh if e not in treo]
    if treo:
        tin = round(min(tin, NGUONG_TIN - 0.01), 3)

    src = _sinh_ma_do_thi(nut, canh, ngon_ngu)
    did = "dg_" + hashlib.sha256((params["image"] + src).encode()).hexdigest()[:16]
    can_duyet = tin < NGUONG_TIN
    _luu_diagram(root, did, "from_image", ngon_ngu, src, ctx, stale=can_duyet)

    return {"diagram": {"id": did, "lang": ngon_ngu, "src": src,
                        "nodes": len(nut), "edges": len(canh),
                        "dangling_edges": treo,
                        "unreadable": list(resp.data.get("unreadable") or []),
                        "needs_review": can_duyet},
            "confidence": tin}


def _sinh_ma_do_thi(nut: list[dict[str, Any]], canh: list[dict[str, Any]], lang: str) -> str:
    """`{nodes, edges}` → mã lược đồ. Dựng bằng MÃ nên luôn phân tích được."""
    def sach(x: str) -> str:
        return re.sub(r"[^\w]", "_", str(x))[:40] or "n"

    if lang == "dot":
        d = ["digraph G {", '  rankdir="LR";']
        d += [f'  {sach(n["id"])} [label="{n.get("label", n["id"])}"];' for n in nut]
        d += [f'  {sach(e["from"])} -> {sach(e["to"])}'
              + (f' [label="{e["label"]}"]' if e.get("label") else "") + ";" for e in canh]
        return "\n".join([*d, "}"]) + "\n"
    d = ["flowchart LR"]
    d += [f'  {sach(n["id"])}["{n.get("label", n["id"])}"]' for n in nut]
    d += [f'  {sach(e["from"])} -->' + (f'|{e["label"]}|' if e.get("label") else "")
          + f' {sach(e["to"])}' for e in canh]
    return "\n".join(d) + "\n"


def _luu_diagram(root: Path, did: str, kind: str, lang: str, src: str, ctx: Context,
                 *, stale: bool = False) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        c.execute("INSERT OR REPLACE INTO diagram (id, kind, lang, src, stale, at)"
                  " VALUES (?,?,?,?,?,?)",
                  (did, kind, lang, src, 1 if stale else 0, datetime.now(UTC).isoformat()))
        c.commit()
    store.write_seal(db, ctx.extra.get("ledger"))
