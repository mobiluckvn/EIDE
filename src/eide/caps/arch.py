"""Namespace arch.* — CDS-12.1 (tập Kỹ nghệ); DDD-14 §2 Module/HwMap/ADR; PRS-16 vai trò `architect`.

Mười một năng lực. Ranh giới quen thuộc, nhưng ở nhóm này nó rõ hơn hẳn nhóm `req.*`:

**Deterministic** — `memory_budget`, `timing_budget`, `compare`, `to_plan`, phần tiền kiểm của
`style_select`, phần kiểm chu trình của `decompose`, phần kiểm đầy đủ của `state_machine`, và
phần checklist của `review`. Phân tích RMS là một bất đẳng thức; tìm chu trình trong đồ thị phụ
thuộc là DFS; cộng ngân sách RAM là phép cộng.

**Có sinh** — `decompose`, `interface_spec`, `state_machine`, `adr`, và phần lý do của
`style_select`/`review`.

## Vì sao phần deterministic ở đây quan trọng hơn ở req.*

Một yêu cầu viết mơ hồ thì người đọc nhận ra. Một hệ thống **không lập lịch được** thì không ai
nhận ra bằng mắt — nó chạy tốt trên bàn, rồi trượt deadline khi tải cao, và triệu chứng là "thỉnh
thoảng bị đơ". `arch.timing_budget` tính `U ≤ n(2^(1/n)−1)` để nói điều đó TRƯỚC khi có dòng mã
nào. Cũng vậy với `memory_budget`: hết Flash lúc biên dịch còn đỡ, hết RAM lúc chạy thì gặp ở
hiện trường.

Nên: những chỗ tính được thì tính, và không hỏi mô hình. Mô hình chỉ viết lý do và đặt tên.
"""
from __future__ import annotations

import json
import re
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide.caps.req import DON_VI, _cung_chu_de, _doc_requirement, do_duoc
from eide_core import store
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# ARCH-01 bước 1, nguyên văn: "RAM < 4 KB → không RTOS; ≥ 3 tác vụ chu kỳ khác nhau + deadline
# < 10 ms → ưu tiên event_driven/rtos; ≥ 2 giao tiếp chặn → rtos; còn lại super_loop/layered".
RAM_TOI_THIEU_RTOS = 4 * 1024        # byte
DEADLINE_NGAT = 10e-3                # giây
SO_TAC_VU_NGAT = 3
SO_GIAO_TIEP_CHAN = 2

KIEU = ("super_loop", "event_driven", "rtos", "layered")

# ARCH-02: "module theo lớp (hal → driver → service → control → app)".
LOP = ("hal", "driver", "service", "control", "app")

# ARCH-04 bước 1: "bảng tham chiếu (driver I2C ~1–2 KB flash, 64 B ram; RTOS kernel theo
# fact/skill)". Con số là ƯỚC LƯỢNG có nguồn, không phải đo — nên năng lực trả kèm `nguon`
# để người đọc biết mức tin cậy, và `code.size` thật sẽ thay chúng khi có.
BANG_UOC_LUONG: dict[str, dict[str, int]] = {
    "hal":     {"flash": 2048, "ram": 128, "stack": 128},
    "driver":  {"flash": 1536, "ram": 64, "stack": 192},
    "service": {"flash": 2048, "ram": 256, "stack": 256},
    "control": {"flash": 3072, "ram": 192, "stack": 320},
    "app":     {"flash": 4096, "ram": 512, "stack": 512},
}
RTOS_KERNEL = {"flash": 6144, "ram": 2048, "stack": 0}

NGUONG_FLASH = 0.85                  # ARCH-04 tc: "Tổng ≤ 85% Flash"

# ARCH-10 bước 1: "Tiêu chí mặc định: RAM, Flash, thời gian thực, độ phức tạp, khả năng mở
# rộng, rủi ro". Trọng số bằng nhau khi người gọi không nêu — một mặc định thiên vị sẵn còn tệ
# hơn không có mặc định, vì nó ẩn.
TIEU_CHI_MAC_DINH = [{"name": n, "weight": 1.0} for n in
                     ("ram", "flash", "thời gian thực", "độ phức tạp", "khả năng mở rộng", "rủi ro")]


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm arch.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


def _ngu_canh(ctx: Context, task: str) -> str:
    from eide.caps.memory import compose
    b = compose({"role": "architect", "task_ref": task}, ctx)["bundle"]
    return "\n\n".join(x["text"] for x in b["blocks"] if x["layer"] != "C1")


# ---------------------------------------------------------------- module: đọc/ghi


# `layer` có từ DDD-14 v1.3 (DEV-069). Trước đó `decompose` tính lớp, kiểm bất biến "phụ thuộc
# chỉ đi xuống lớp dưới" theo nó, rồi mất nó lúc ghi — nên bất biến ấy chỉ kiểm được đúng một
# lần, ngay tại lời gọi decompose, và mọi năng lực đọc ModuleGraph lại từ store đều không dựng
# được gì theo lớp.
COT_MODULE = ("id", "name", "responsibility", "interfaces", "depends", "layer", "arch_style",
              "budget", "fsm", "status")
JSON_MODULE = ("interfaces", "depends", "budget", "fsm")


def _doc_module(root: Path, ids: list[str] | None = None) -> list[dict[str, Any]]:
    db = store.store_path(root)
    if not db.exists():
        return []
    q = f"SELECT {', '.join(COT_MODULE)} FROM module"  # noqa: S608
    with store.open_store(db) as c:
        rows = (c.execute(q + f" WHERE id IN ({','.join('?' * len(ids))})", ids)  # noqa: S608
                if ids else c.execute(q + " ORDER BY id")).fetchall()
    ra = []
    for r in rows:
        d = dict(zip(COT_MODULE, r, strict=True))
        for k in JSON_MODULE:
            if isinstance(d[k], str):
                d[k] = json.loads(d[k])
        ra.append(d)
    return ra


def _ghi_module(root: Path, ds: list[dict[str, Any]]) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        for m in ds:
            c.execute(
                f"INSERT OR REPLACE INTO module ({', '.join(COT_MODULE)})"  # noqa: S608
                f" VALUES ({','.join('?' * len(COT_MODULE))})",
                tuple(json.dumps(m.get(k) if m.get(k) is not None else
                                 ([] if k in ("interfaces", "depends") else None),
                                 ensure_ascii=False) if k in JSON_MODULE else m.get(k)
                      for k in COT_MODULE))
        c.commit()


def _slug(ten: str) -> str:
    s = re.sub(r"[^0-9a-zA-Z]+", "_", ten.lower()).strip("_")
    return f"mod_{s}" if not s.startswith("mod_") else s


# ---------------------------------------------------------------- ARCH-01 style_select


@capability("arch.style_select")
def style_select(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-01 — CDS-12.1. tc: TC-69 "robot → rtos hoặc event_driven có lý do";
    ask "Đổi kiểu kiến trúc dự án đã có".

    Bước 1 là quy tắc, bước 2 mới là mô hình — và thứ tự ấy có lý do. "Chọn kiến trúc" nghe như
    việc phán đoán, nhưng ba mệnh đề đầu là RÀNG BUỘC: RAM 2 KB thì không nhét được kernel RTOS,
    bất kể lập luận hay đến đâu. Để mô hình quyết trước rồi kiểm sau nghĩa là thỉnh thoảng nó
    viết một lý do thuyết phục cho một phương án bất khả thi — và lý do thuyết phục thì khó cãi
    hơn là không có lý do.
    """
    root = _root(ctx)
    ds = _doc_requirement(root, params["reqset_ids"])
    dk = _dieu_kien(root, ds, params["passport"])
    loai, vi_sao = _kieu_theo_quy_tac(dk)

    cu = {m["arch_style"] for m in _doc_module(root)} - {None}
    if cu and loai not in cu and ctx.actor != "human":
        raise EideError("E3000", f"Dự án đã theo kiểu {sorted(cu)}; đổi sang {loai} là thay đổi "
                        "toàn bộ khung mã, cần người quyết (ARCH-01 ask: Đổi kiểu kiến trúc dự "
                        "án đã có)", rule="ARCH-01", gate="*", hien_tai=sorted(cu), de_xuat=loai)

    resp = _gateway(ctx).run(
        "architect",
        f"Kiểu kiến trúc đã được quy tắc tiền kiểm chọn: {loai}. Căn cứ: {vi_sao}.\n"
        f"Số liệu: {json.dumps(dk, ensure_ascii=False)}\n"
        "Viết lý do kỹ thuật cho lựa chọn này và nêu phương án thay thế bị loại. KHÔNG đổi "
        "`style` — nó là kết quả của ràng buộc phần cứng, không phải của lập luận.",
        _SCHEMA_STYLE, system_extra=_ngu_canh(ctx, "chọn kiểu kiến trúc"))

    d = resp.data
    return {"decision": {
        "style": loai,                                    # quy tắc thắng, luôn luôn
        "reasons": vi_sao + list(d.get("reasons") or []),
        "facts": dk["facts"],
        "alternatives": list(d.get("alternatives") or [k for k in KIEU if k != loai]),
        "signals": dk,
    }}


_SCHEMA_STYLE = {
    "type": "object", "required": ["reasons"],
    "properties": {"reasons": {"type": "array", "items": {"type": "string"}},
                   "alternatives": {"type": "array", "items": {"type": "string"}}},
}


def _dieu_kien(root: Path, ds: list[dict[str, Any]], passport: str) -> dict[str, Any]:
    """Rút bốn tín hiệu mà quy tắc ARCH-01 cần, từ yêu cầu và hộ chiếu."""
    chu_ky, deadline_gap, chan = set(), 0, 0
    for r in ds:
        t = (r.get("text") or "").lower()
        dv = do_duoc(t)
        if r.get("kind") == "RT" or "chu kỳ" in t or "mỗi" in t:
            if dv and dv[1] == "thời gian":
                chu_ky.add(dv[0])
            if dv and dv[1] == "thời gian" and dv[0] < DEADLINE_NGAT:
                deadline_gap += 1
        if any(x in t for x in ("uart", "i2c", "spi", "can", "chờ", "blocking", "đợi")):
            chan += 1

    ram = _ram_tu_passport(root, passport)
    return {"ram_bytes": ram, "so_chu_ky_khac_nhau": len(chu_ky),
            "so_deadline_duoi_10ms": deadline_gap, "so_giao_tiep_chan": chan,
            "facts": _facts_ram(root, passport)}


def _facts_ram(root: Path, passport: str) -> list[str]:
    db = store.store_path(root)
    if not db.exists():
        return []
    part = str(passport).split("@")[0]
    with store.open_store(db) as c:
        return [r[0] for r in c.execute(
            "SELECT id FROM fact WHERE predicate='memory_size'"
            "  AND (subject = ? OR subject LIKE ? OR subject LIKE ?)",
            (part, f"%:{part}", f"%:{part}/%")).fetchall()]


def _ram_tu_passport(root: Path, passport: str) -> int | None:
    """RAM của chip theo fact `memory_size`. None nghĩa là CHƯA BIẾT, không phải 0.

    Phân biệt ấy quyết định hành vi: RAM chưa biết thì quy tắc "RAM < 4 KB → không RTOS" phải
    im lặng, chứ không được loại RTOS. Coi None là 0 thì mọi dự án chưa nạp hộ chiếu đều bị đẩy
    về super_loop — một mặc định sai lặng lẽ.
    """
    db = store.store_path(root)
    if not db.exists():
        return None
    part = str(passport).split("@")[0]
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT value, unit, subject FROM fact WHERE predicate='memory_size'"
            "  AND (subject = ? OR subject LIKE ? OR subject LIKE ?)",
            (part, f"%:{part}", f"%:{part}/%")).fetchall()
    for val, unit, subj in rows:
        if "ram" not in (subj or "").lower() and "ram" not in (unit or "").lower():
            continue
        try:
            so = float(json.loads(val))
        except (ValueError, TypeError):
            continue
        return int(so * (DON_VI.get((unit or "").lower()) or ("", 1))[1])
    return None


def _kieu_theo_quy_tac(dk: dict[str, Any]) -> tuple[str, list[str]]:
    """Ba mệnh đề của ARCH-01 bước 1, theo đúng thứ tự văn bản.

    Thứ tự là thứ tự ƯU TIÊN, không phải thứ tự trình bày: mệnh đề RAM là điều kiện LOẠI TRỪ
    (không RTOS), hai mệnh đề sau là điều kiện ĐỀ CỬ. Chạy đề cử trước rồi loại sau cũng ra cùng
    kết quả, nhưng lý do ghi lại sẽ nói "chọn RTOS rồi bỏ" thay vì "RTOS không khả dụng" — và
    nhật ký quyết định là thứ người đọc để hiểu, nên nó phải kể đúng chuyện đã xảy ra.
    """
    ram, vi_sao = dk["ram_bytes"], []
    cam_rtos = ram is not None and ram < RAM_TOI_THIEU_RTOS
    if cam_rtos:
        vi_sao.append(f"RAM {ram} B < {RAM_TOI_THIEU_RTOS} B: kernel RTOS không đủ chỗ")
    elif ram is None:
        vi_sao.append("chưa có fact memory_size cho chip này — quy tắc RAM không áp dụng "
                      "(nạp hộ chiếu rồi chạy lại để chắc chắn)")

    if dk["so_giao_tiep_chan"] >= SO_GIAO_TIEP_CHAN and not cam_rtos:
        vi_sao.append(f"{dk['so_giao_tiep_chan']} giao tiếp có thể chặn: cần luồng tách biệt")
        return "rtos", vi_sao
    if (dk["so_chu_ky_khac_nhau"] >= SO_TAC_VU_NGAT and dk["so_deadline_duoi_10ms"] > 0):
        vi_sao.append(f"{dk['so_chu_ky_khac_nhau']} chu kỳ khác nhau và "
                      f"{dk['so_deadline_duoi_10ms']} deadline < 10 ms")
        return ("event_driven" if cam_rtos else "rtos"), vi_sao
    vi_sao.append("không có tín hiệu đòi lập lịch ưu tiên")
    return ("layered" if dk["so_giao_tiep_chan"] else "super_loop"), vi_sao


# ---------------------------------------------------------------- ARCH-02 decompose


@capability("arch.decompose")
def decompose(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-02 — CDS-12.1. tc: "Không chu trình; mọi FR có module".

    Mô hình đặt tên và chia trách nhiệm; MÃ NGUỒN kiểm hai bất biến rồi mới ghi. Cả hai đều là
    thứ mô hình hay vi phạm mà đọc qua không thấy: một chu trình `driver → service → driver` ẩn
    trong mười module thì mắt người bỏ sót, còn một FR không có module nào nhận thì im lặng
    tuyệt đối — nó chỉ lộ ra ở `req.trace_matrix`, sau khi đã lập kế hoạch và viết mã.
    """
    root = _root(ctx)
    ds = _doc_requirement(root, params["reqset_ids"])
    style = params["style"]
    resp = _gateway(ctx).run(
        "architect",
        f"Chia hệ thống thành module theo lớp {' → '.join(LOP)}, kiểu kiến trúc {style}.\n"
        "Mỗi module: trách nhiệm một câu, lớp, phụ thuộc (chỉ xuống lớp dưới), và danh sách "
        "req_ids mà nó hiện thực. Phụ thuộc KHÔNG được tạo chu trình.\n"
        + json.dumps([{"id": r["id"], "kind": r["kind"], "text": r["text"]} for r in ds],
                     ensure_ascii=False),
        _SCHEMA_DECOMPOSE, system_extra=_ngu_canh(ctx, "phân rã kiến trúc"))

    mods = []
    for m in (resp.data.get("modules") or []):
        mods.append({"id": _slug(m.get("id") or m["name"]), "name": m["name"],
                     "responsibility": m.get("responsibility"),
                     "layer": m.get("layer") if m.get("layer") in LOP else "service",
                     "depends": [_slug(x) for x in (m.get("depends") or [])],
                     "req_ids": list(m.get("req_ids") or []),
                     "arch_style": style, "status": "proposed"})

    loi = _kiem_do_thi(mods, ds)
    if loi:
        raise EideError("E5002", "Phân rã không dùng được: " + "; ".join(loi), issues=loi)

    _ghi_module(root, [{**m, "interfaces": []} for m in mods])
    _noi_trace(root, mods)
    edges = [{"from": m["id"], "to": d} for m in mods for d in m["depends"]]
    return {"module_graph": {"modules": mods, "edges": edges}}


_SCHEMA_DECOMPOSE = {
    "type": "object", "required": ["modules"],
    "properties": {"modules": {"type": "array", "items": {
        "type": "object", "required": ["name", "responsibility"],
        "properties": {"id": {"type": "string"}, "name": {"type": "string"},
                       "responsibility": {"type": "string"},
                       "layer": {"type": "string", "enum": list(LOP)},
                       "depends": {"type": "array", "items": {"type": "string"}},
                       "req_ids": {"type": "array", "items": {"type": "string"}}}}}},
}


def _kiem_do_thi(mods: list[dict[str, Any]], ds: list[dict[str, Any]]) -> list[str]:
    """Hai bất biến của tc, cộng một bất biến của bước 1 ("phụ thuộc không chu trình" theo lớp).

    Gom HẾT lỗi rồi mới báo, không dừng ở lỗi đầu: một phân rã do mô hình sinh thường sai vài
    chỗ cùng lúc, và báo từng cái một buộc người dùng chạy lại năm lần.
    """
    loi, co = [], {m["id"] for m in mods}
    for m in mods:
        for d in m["depends"]:
            if d not in co:
                loi.append(f"{m['id']} phụ thuộc {d} không tồn tại")

    if (chu_trinh := _tim_chu_trinh({m["id"]: m["depends"] for m in mods})):
        loi.append("chu trình phụ thuộc: " + " → ".join(chu_trinh))

    phu = {r for m in mods for r in m["req_ids"]}
    thieu = [r["id"] for r in ds if r.get("kind") == "FR" and r["id"] not in phu]
    if thieu:
        loi.append(f"FR không module nào nhận: {thieu}")

    bac = {ten: i for i, ten in enumerate(LOP)}
    theo_id = {m["id"]: m for m in mods}
    for m in mods:
        for d in m["depends"]:
            if d in theo_id and bac[theo_id[d]["layer"]] > bac[m["layer"]]:
                loi.append(f"{m['id']} ({m['layer']}) phụ thuộc ngược lên "
                           f"{d} ({theo_id[d]['layer']})")
    return loi


def _tim_chu_trinh(canh: dict[str, list[str]]) -> list[str]:
    """Trả ĐƯỜNG ĐI của chu trình, không phải True/False — cùng lý do như `plan.order`.

    "Có chu trình" thì người dùng vẫn phải tự dò mười module để tìm; "app → service → driver →
    app" thì họ sửa được ngay.
    """
    mau: dict[str, int] = {}
    duong: list[str] = []

    def di(u: str) -> list[str]:
        mau[u] = 1
        duong.append(u)
        for v in canh.get(u, []):
            if mau.get(v) == 1:
                return duong[duong.index(v):] + [v]
            if mau.get(v, 0) == 0 and (kq := di(v)):
                return kq
        duong.pop()
        mau[u] = 2
        return []

    for u in canh:
        if mau.get(u, 0) == 0 and (kq := di(u)):
            return kq
    return []


def _noi_trace(root: Path, mods: list[dict[str, Any]]) -> None:
    """Ghi module vào `requirement.trace` — đây là thứ `req.trace_matrix` đọc để báo lỗ hổng."""
    theo_req: dict[str, list[str]] = {}
    for m in mods:
        for r in m["req_ids"]:
            theo_req.setdefault(r, []).append(m["id"])
    if not theo_req:
        return
    from eide.caps.req import _ghi_requirement
    ds = _doc_requirement(root, list(theo_req))
    for r in ds:
        r["trace"] = sorted({*(r.get("trace") or []), *theo_req[r["id"]]})
    _ghi_requirement(root, ds)


# ---------------------------------------------------------------- ARCH-03 map_hw


@capability("arch.map_hw")
def map_hw(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-03 — CDS-12.1; DDD-14 §2 HwMap. tc: TC-69 "xung đột = 0";
    ask "Xung đột chân/timer không tự giải".

    Phát hiện xung đột là deterministic và phải như vậy: hai module cùng đòi PA5 là một sự thật
    về tập hợp, không phải một nhận định. Mô hình chỉ được dùng để CHỌN ngoại vi khi còn chỗ
    trống, không bao giờ để phán một xung đột là chấp nhận được.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    passport = params["passport"]
    dat = _gan_tai_nguyen(root, mods, passport, params.get("board"))

    xung_dot = _tim_xung_dot(dat)
    if xung_dot and ctx.actor != "human":
        raise EideError("E3000", f"{len(xung_dot)} xung đột tài nguyên không tự giải được "
                        "(ARCH-03 ask: Xung đột chân/timer không tự giải)", rule="ARCH-03",
                        gate="*", conflicts=xung_dot,
                        alternative="board.propose_fix để xin phương án đổi chân")

    _ghi_hw_map(root, dat)
    return {"hw_map": dat, "conflicts": xung_dot}


def _gan_tai_nguyen(root: Path, mods: list[dict[str, Any]], passport: str,
                    board: str | None) -> list[dict[str, Any]]:
    """Gán ngoại vi cho module cần phần cứng, lấy từ fact `pin_function` của hộ chiếu."""
    db = store.store_path(root)
    part = str(passport).split("@")[0]
    co_san: list[tuple[str, str]] = []
    if db.exists():
        with store.open_store(db) as c:
            co_san = [(r[0], r[1]) for r in c.execute(
                "SELECT id, subject FROM fact WHERE predicate IN ('pin_function','irq')"
                "  AND (subject = ? OR subject LIKE ? OR subject LIKE ?)",
                (part, f"%:{part}", f"%:{part}/%")).fetchall()]

    ra = []
    for m in mods:
        can = _ngoai_vi_can(m)
        for loai in can:
            khop = [(fid, s) for fid, s in co_san if loai in s.lower()]
            ra.append({"module_id": m["id"],
                       "resource": khop[0][1] if khop else f"chip:{part}/periph:{loai.upper()}",
                       "role": "master" if loai in ("i2c", "spi", "uart") else "input",
                       "fact_ids": [khop[0][0]] if khop else [],
                       "board": board})
    return ra


def _ngoai_vi_can(m: dict[str, Any]) -> list[str]:
    """Ngoại vi suy từ tên và trách nhiệm module — không đoán quá tay.

    Chỉ nhận diện khi tên ngoại vi xuất hiện TƯỜNG MINH. Suy "module cảm biến chắc dùng I2C" là
    loại phỏng đoán tạo ra một HwMap trông đầy đủ nhưng sai, và một bản đồ chân sai thì tệ hơn
    một bản đồ trống: người ta tin nó rồi hàn theo.
    """
    t = f"{m.get('name','')} {m.get('responsibility') or ''}".lower()
    return [x for x in ("i2c", "spi", "uart", "adc", "pwm", "timer", "gpio", "can", "dma")
            if re.search(rf"\b{x}\b", t)]


def _tim_xung_dot(dat: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Một tài nguyên, hai module — trừ khi cả hai đều khai `role='shared'`."""
    theo_tn: dict[str, list[dict[str, Any]]] = {}
    for d in dat:
        theo_tn.setdefault(d["resource"], []).append(d)
    return [{"resource": tn, "modules": [x["module_id"] for x in ds],
             "reason": "hai module trở lên đòi cùng một tài nguyên và không khai shared"}
            for tn, ds in theo_tn.items()
            if len(ds) > 1 and not all(x["role"] == "shared" for x in ds)]


def _ghi_hw_map(root: Path, dat: list[dict[str, Any]]) -> None:
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        for d in dat:
            c.execute("INSERT OR REPLACE INTO hw_map (module_id, resource, role, fact_ids)"
                      " VALUES (?,?,?,?)",
                      (d["module_id"], d["resource"], d["role"],
                       json.dumps(d["fact_ids"], ensure_ascii=False)))
        c.commit()


# ---------------------------------------------------------------- ARCH-04 memory_budget


@capability("arch.memory_budget")
def memory_budget(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-04 — CDS-12.1. tc: "Tổng ≤ 85% Flash"; ask "Vượt ngân sách".

    Ngưỡng 85% không phải sự thận trọng vu vơ: phần Flash còn lại phải đủ cho bootloader, cho
    vùng cấu hình, và cho lần cập nhật sau — một firmware lấp đầy 99% Flash là firmware không
    vá được tại hiện trường. Đó là lý do tc đặt ngưỡng ở tổng, chứ không ở "vừa đủ chỗ".

    Trả `nguon` cho mỗi dòng: `ước lượng` hay `đo`. Một bảng ngân sách trộn lẫn hai loại mà
    không phân biệt sẽ được đọc như thể đã đo hết.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    do_that = _kich_thuoc_da_do(root, [m["id"] for m in mods])

    per, tong = [], {"flash": 0, "ram": 0, "stack": 0}
    for m in mods:
        if (d := do_that.get(m["id"])):
            uoc, nguon = d, "đo"
        else:
            uoc, nguon = BANG_UOC_LUONG.get(_lop_cua(m), BANG_UOC_LUONG["service"]), "ước lượng"
        per.append({"module_id": m["id"], **uoc, "nguon": nguon})
        for k in tong:
            tong[k] += uoc[k]

    if any(m.get("arch_style") == "rtos" for m in mods):
        per.append({"module_id": "rtos_kernel", **RTOS_KERNEL, "nguon": "ước lượng"})
        for k in tong:
            tong[k] += RTOS_KERNEL[k]

    gh = _gioi_han_bo_nho(root, params["passport"])
    # Stack là RAM: nó nằm cùng vùng và cạnh tranh cùng chỗ với biến toàn cục. Cộng riêng rồi
    # so RAM mà quên stack là cách phổ biến nhất để một bản ngân sách "đạt" rồi tràn lúc chạy.
    ram_can = tong["ram"] + tong["stack"]
    ok = _trong_gioi_han(tong["flash"], gh.get("flash"), ram_can, gh.get("ram"))

    kq = {"per_module": per, "total": {**tong, "ram_gom_stack": ram_can},
          "limits": gh, "threshold_flash": NGUONG_FLASH, "ok": ok}
    if ok is False and ctx.actor != "human":
        raise EideError("E3000", f"Vượt ngân sách bộ nhớ: flash {tong['flash']} B / "
                        f"{gh.get('flash')} B (ngưỡng {NGUONG_FLASH:.0%}), ram+stack {ram_can} B"
                        f" / {gh.get('ram')} B (ARCH-04 ask: Vượt ngân sách)",
                        rule="ARCH-04", gate="*", budget=kq)
    return {"budget": kq}


def _lop_cua(m: dict[str, Any]) -> str:
    t = f"{m.get('id','')} {m.get('name','')}".lower()
    for ten in LOP:
        if ten in t:
            return ten
    return "service"


def _trong_gioi_han(flash: int, gh_flash: int | None, ram: int, gh_ram: int | None) -> bool | None:
    """None khi CHƯA BIẾT giới hạn — cùng lý do như `_ram_tu_passport`.

    Không có fact `memory_size` mà trả True thì bản ngân sách nói "đạt" trong khi chưa so với
    gì cả; trả False thì mọi dự án chưa nạp hộ chiếu đều bị chặn. Cả hai đều sai; `None` là câu
    trả lời đúng, và `ask_when` chỉ kích hoạt ở `False`.
    """
    if gh_flash is None and gh_ram is None:
        return None
    if gh_flash is not None and flash > gh_flash * NGUONG_FLASH:
        return False
    if gh_ram is not None and ram > gh_ram:
        return False
    return True


def _gioi_han_bo_nho(root: Path, passport: str) -> dict[str, int]:
    db = store.store_path(root)
    if not db.exists():
        return {}
    part = str(passport).split("@")[0]
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT subject, value, unit FROM fact WHERE predicate='memory_size'"
            "  AND (subject = ? OR subject LIKE ? OR subject LIKE ?)",
            (part, f"%:{part}", f"%:{part}/%")).fetchall()
    gh: dict[str, int] = {}
    for subj, val, unit in rows:
        loai = "flash" if "flash" in (subj or "").lower() else (
            "ram" if "ram" in (subj or "").lower() else None)
        if not loai:
            continue
        try:
            so = float(json.loads(val))
        except (ValueError, TypeError):
            continue
        gh[loai] = int(so * (DON_VI.get((unit or "").lower()) or ("", 1))[1])
    return gh


def _kich_thuoc_da_do(root: Path, ids: list[str]) -> dict[str, dict[str, int]]:
    """Bước 1 nói "+ lịch sử code.size các dự án". Số ĐO luôn thắng số ước lượng."""
    db = store.store_path(root)
    if not db.exists() or not ids:
        return {}
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT target, value, unit FROM measurement WHERE kind='custom' AND target IN "
            f"({','.join('?' * len(ids))})", ids).fetchall()  # noqa: S608
    ra: dict[str, dict[str, int]] = {}
    for target, val, _unit in rows:
        try:
            d = json.loads(val)
        except (ValueError, TypeError):
            continue
        if isinstance(d, dict) and {"flash", "ram"} <= set(d):
            ra[target] = {"flash": int(d["flash"]), "ram": int(d["ram"]),
                          "stack": int(d.get("stack", 0))}
    return ra


# ---------------------------------------------------------------- ARCH-05 timing_budget


@capability("arch.timing_budget")
def timing_budget(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-05 — CDS-12.1. tc: "U tính đúng; không schedulable → cảnh báo";
    ask "Deadline không đạt".

    Điều kiện Liu–Layland cho lập lịch đơn điệu theo chu kỳ (RMS): `U ≤ n(2^(1/n)−1)`. Đây là
    điều kiện ĐỦ, không phải điều kiện cần — một tập tác vụ vượt cận vẫn có thể lập lịch được.
    Nên khi vượt, năng lực nói "không CHỨNG MINH được là lập lịch được", không nói "không lập
    lịch được". Khác biệt ấy quan trọng: báo sai một kiến trúc là bất khả thi sẽ đẩy người ta đi
    làm lại một thiết kế vốn đúng.

    Với n → ∞ cận tiến tới ln 2 ≈ 0,693. Đó là lý do một hệ nhúng nhiều tác vụ hiếm khi an toàn
    khi vượt quá ~69% tải CPU, dù trực giác nói còn 30% dư.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    tasks = [t for m in mods if (t := _tac_vu_cua(root, m))]

    n = len(tasks)
    u = sum(t["wcet_est_us"] / (t["period_ms"] * 1000) for t in tasks) if tasks else 0.0
    can = n * (2 ** (1 / n) - 1) if n else 1.0
    dat = u <= can

    # Ưu tiên theo RMS: chu kỳ ngắn hơn ⇒ ưu tiên cao hơn. Đây là định nghĩa của "đơn điệu theo
    # chu kỳ", không phải một cách sắp xếp tùy chọn.
    for i, t in enumerate(sorted(tasks, key=lambda x: x["period_ms"])):
        t["prio"] = i + 1

    kq = {"tasks": tasks, "utilization": round(u, 4), "bound": round(can, 4),
          "n": n, "schedulable": dat,
          "note": ("đạt cận Liu–Layland" if dat else
                   "vượt cận Liu–Layland — CHƯA CHỨNG MINH được là lập lịch được (đây là điều "
                   "kiện đủ, không phải điều kiện cần); cần phân tích thời gian đáp ứng hoặc "
                   "giảm tải")}
    if not dat and tasks and ctx.actor != "human":
        raise EideError("E3000", f"U = {u:.3f} vượt cận {can:.3f} với {n} tác vụ "
                        "(ARCH-05 ask: Deadline không đạt)", rule="ARCH-05", gate="*", budget=kq)
    return {"budget": kq}


def _tac_vu_cua(root: Path, m: dict[str, Any]) -> dict[str, Any] | None:
    """Chu kỳ từ yêu cầu RT; WCET từ `budget.wcet_us` nếu đã ước lượng, không thì suy từ lớp.

    Module không có chu kỳ thì KHÔNG phải tác vụ chu kỳ và không được vào phép tính — nhét nó
    vào với một chu kỳ bịa sẽ làm sai U theo hướng bi quan, và một cảnh báo bi quan giả cũng
    làm hỏng niềm tin y như một cảnh báo lạc quan giả.
    """
    b = m.get("budget") or {}
    chu_ky = b.get("period_ms") or _chu_ky_tu_req(root, m)
    if not chu_ky:
        return None
    wcet = b.get("wcet_us") or BANG_UOC_LUONG.get(_lop_cua(m), BANG_UOC_LUONG["service"])["stack"]
    return {"module_id": m["id"], "period_ms": float(chu_ky), "wcet_est_us": float(wcet),
            "nguon": "đo" if b.get("wcet_us") else "ước lượng"}


def _chu_ky_tu_req(root: Path, m: dict[str, Any]) -> float | None:
    """Bước 1: "Chu kỳ từ RT requirement"."""
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        rows = c.execute("SELECT text, trace FROM requirement WHERE kind='RT'").fetchall()
    for text, trace in rows:
        if m["id"] not in (trace or "") and not _cung_chu_de(text or "", m.get("name") or ""):
            continue
        if (dv := do_duoc(text or "")) and dv[1] == "thời gian":
            return dv[0] * 1000.0          # giây → ms
    return None


# ---------------------------------------------------------------- ARCH-06 interface_spec


@capability("arch.interface_spec")
def interface_spec(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-06 — CDS-12.1. tc: "Chữ ký biên dịch được (kiểm bằng header stub)".

    tc đòi chữ ký BIÊN DỊCH ĐƯỢC, nên phải kiểm thật chứ không tin mô hình. Không có trình dịch
    chéo trong môi trường test, nên kiểm bằng một bộ phân tích chữ ký C tối thiểu: đủ để bắt
    những lỗi mà mô hình thật sự mắc (thiếu kiểu trả về, ngoặc lệch, thiếu tên tham số), và
    không giả vờ làm được nhiều hơn thế.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    resp = _gateway(ctx).run(
        "architect",
        "Viết giao diện C cho từng module: chữ ký hàm, mã lỗi trả về, ràng buộc gọi "
        "(ISR-safe hay không), và message/queue nếu là RTOS.\n"
        + json.dumps([{"id": m["id"], "name": m["name"],
                       "responsibility": m.get("responsibility")} for m in mods],
                     ensure_ascii=False),
        _SCHEMA_IFACE, system_extra=_ngu_canh(ctx, "đặc tả giao diện"))

    ifaces = list(resp.data.get("interfaces") or [])
    xau = [f"{i.get('module')}: {f.get('sig')} — {ly}"
           for i in ifaces for f in (i.get("functions") or [])
           if (ly := _chu_ky_hong(f.get("sig", "")))]
    if xau:
        raise EideError("E5002", "Chữ ký C không biên dịch được: " + "; ".join(xau), issues=xau)

    theo_mod = {i["module"]: i for i in ifaces}
    for m in mods:
        if m["id"] in theo_mod:
            m["interfaces"] = theo_mod[m["id"]].get("functions") or []
    _ghi_module(root, mods)
    return {"interfaces": ifaces}


_SCHEMA_IFACE = {
    "type": "object", "required": ["interfaces"],
    "properties": {"interfaces": {"type": "array", "items": {
        "type": "object", "required": ["module", "functions"],
        "properties": {
            "module": {"type": "string"},
            "functions": {"type": "array", "items": {
                "type": "object", "required": ["sig"],
                "properties": {"sig": {"type": "string"},
                               "errors": {"type": "array", "items": {"type": "string"}},
                               "timing": {"type": "string"},
                               "isr_safe": {"type": "boolean"}}}},
            "messages": {"type": "array", "items": {"type": "object"}}}}}},
}

# Kiểu C hợp lệ ở vị trí trả về/tham số. Cố ý HẸP: chấp nhận cả những chuỗi lạ thì phép kiểm
# thành trang trí, mà tc đòi nó có tác dụng thật.
# Phần KIỂU, chưa gồm con trỏ. Tách `*` ra riêng là điểm mấu chốt: C cho viết `uint8_t *buf`,
# `uint8_t* buf` và `uint8_t*buf` — cả ba đều hợp lệ, nên khoảng trắng quanh dấu sao phải là
# tùy ý ở CẢ HAI phía. Gộp `*` vào phần kiểu rồi đòi khoảng trắng trước tên sẽ loại đúng cách
# viết phổ biến nhất trong mã nhúng.
_KIEU_C = (r"(?:static\s+|inline\s+|extern\s+|const\s+|volatile\s+)*"
           r"(?:unsigned\s+|signed\s+|struct\s+|enum\s+)?[A-Za-z_]\w*")
_SAO = r"(?:\s*\*+)?"
# Giữa kiểu và tên phải có khoảng trắng HOẶC dấu sao. Dùng `\s*` ở đây là lỗ hổng: nó cho phép
# cắt "bme280_read" thành kiểu "bme280_rea" + tên "d", nên một chữ ký thiếu hẳn kiểu trả về vẫn
# lọt. Đúng luật C: `int f` cần khoảng trắng, `char*f` thì không vì dấu sao đã tách.
_TEN_SAU = r"(?:\s+|\s*\*+\s*)[A-Za-z_]\w*"


def _chu_ky_hong(sig: str) -> str | None:
    """Trả LÝ DO hỏng, hoặc None nếu qua. Trả lý do chứ không trả False: người sửa cần biết
    hỏng ở đâu, và "chữ ký không hợp lệ" thì họ vẫn phải tự dò."""
    s = sig.strip().rstrip(";").strip()
    if not s:
        return "rỗng"
    if s.count("(") != s.count(")"):
        return "ngoặc lệch"
    m = re.fullmatch(rf"\s*({_KIEU_C})(?:\s+|\s*\*+\s*)([A-Za-z_]\w*)\s*\((.*)\)\s*", s, re.S)
    if not m:
        return "không phải dạng `<kiểu> <tên>(<tham số>)`"
    tham = m.group(3).strip()
    if not tham:
        return "danh sách tham số trống — C cần `void` khi không có tham số"
    if tham == "void":
        return None
    for p in _tach_tham_so(tham):
        if p.strip() in ("...",):
            continue
        if re.fullmatch(rf"\s*{_KIEU_C}{_SAO}\s*\(\s*\*+\s*[A-Za-z_]\w*\s*\)\s*\(.*\)\s*",
                        p, re.S):
            continue                      # con trỏ hàm: `void (*cb)(int)`
        if not re.fullmatch(
                rf"\s*{_KIEU_C}(?:{_TEN_SAU})?{_SAO}(?:\s*\[\s*\d*\s*\])?\s*", p, re.S):
            return f"tham số không hợp lệ: {p.strip()!r}"
    return None


def _tach_tham_so(s: str) -> list[str]:
    """Tách theo dấu phẩy ở mức ngoặc 0 — `void f(int a, struct s (*cb)(int, int))` có dấu phẩy
    lồng bên trong mà tách thô sẽ cắt nhầm."""
    ra, sau, muc = [], 0, 0
    for i, c in enumerate(s):
        if c in "([":
            muc += 1
        elif c in ")]":
            muc -= 1
        elif c == "," and muc == 0:
            ra.append(s[sau:i])
            sau = i + 1
    ra.append(s[sau:])
    return ra


# ---------------------------------------------------------------- ARCH-07 state_machine


@capability("arch.state_machine")
def state_machine(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-07 — CDS-12.1. tc: "FSM đầy đủ; diagram.state vẽ được".

    Hai phép kiểm của bước 1 đều là quy tắc, và cả hai bắt đúng loại lỗi mà máy trạng thái do
    mô hình sinh hay mắc:

    - **Mọi (state, event) phải có chuyển hoặc bỏ qua RÕ RÀNG.** Một cặp không khai là một hành
      vi không xác định — và trong firmware, "không xác định" nghĩa là sự kiện đến vào đúng lúc
      sai thì thiết bị kẹt ở một trạng thái không ai lường.
    - **Không trạng thái không tới được.** Trạng thái không tới được thường là dấu hiệu thiếu
      một chuyển tiếp, chứ không phải thừa một trạng thái — nên nó đáng báo.
    """
    root = _root(ctx)
    mods = _doc_module(root, [params["module_id"]])
    if not mods:
        raise EideError("E2000", f"Không có module {params['module_id']}",
                        exists=[], candidates=[], missing=[params["module_id"]])
    m = mods[0]
    resp = _gateway(ctx).run(
        "architect",
        f"Sinh máy trạng thái cho module {m['name']} ({m.get('responsibility')}).\n"
        "Khai ĐẦY ĐỦ: với mọi cặp (trạng thái, sự kiện) phải có một chuyển tiếp, hoặc một mục "
        "`ignore` nói rõ là bỏ qua. Không được để trạng thái nào không tới được từ `initial`.",
        _SCHEMA_FSM, system_extra=_ngu_canh(ctx, f"máy trạng thái {m['name']}"))

    fsm = resp.data
    if (loi := _kiem_fsm(fsm)):
        raise EideError("E5002", "Máy trạng thái không đầy đủ: " + "; ".join(loi), issues=loi)
    m["fsm"] = fsm
    _ghi_module(root, mods)
    return {"fsm": fsm}


_SCHEMA_FSM = {
    "type": "object", "required": ["states", "events", "transitions", "initial"],
    "properties": {
        "states": {"type": "array", "items": {"type": "string"}},
        "events": {"type": "array", "items": {"type": "string"}},
        "initial": {"type": "string"},
        "transitions": {"type": "array", "items": {
            "type": "object", "required": ["from", "event"],
            "properties": {"from": {"type": "string"}, "event": {"type": "string"},
                           "to": {"type": "string"}, "ignore": {"type": "boolean"},
                           "guard": {"type": "string"}, "action": {"type": "string"}}}},
        "invariants": {"type": "array", "items": {"type": "string"}},
    },
}


def _kiem_fsm(fsm: dict[str, Any]) -> list[str]:
    states = list(fsm.get("states") or [])
    events = list(fsm.get("events") or [])
    trans = list(fsm.get("transitions") or [])
    loi = []

    if fsm.get("initial") not in states:
        loi.append(f"initial {fsm.get('initial')!r} không nằm trong states")

    khai = {(t.get("from"), t.get("event")) for t in trans}
    thieu = [(s, e) for s in states for e in events if (s, e) not in khai]
    if thieu:
        loi.append(f"{len(thieu)} cặp (trạng thái, sự kiện) không khai — hành vi không xác "
                   f"định, ví dụ {thieu[:3]}")

    for t in trans:
        if not t.get("ignore") and t.get("to") not in states:
            loi.append(f"chuyển tiếp ({t.get('from')}, {t.get('event')}) tới trạng thái lạ "
                       f"{t.get('to')!r}")

    toi = {fsm.get("initial")}
    doi = True
    while doi:
        doi = False
        for t in trans:
            if t.get("from") in toi and not t.get("ignore") and t.get("to") not in toi:
                toi.add(t.get("to"))
                doi = True
    if (khong_toi := [s for s in states if s not in toi]):
        loi.append(f"trạng thái không tới được từ initial: {khong_toi} — thường là thiếu một "
                   "chuyển tiếp chứ không phải thừa một trạng thái")
    return loi


# ---------------------------------------------------------------- ARCH-08 adr


@capability("arch.adr")
def adr(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-08 — CDS-12.1; DDD-14 §2 ADR. tc: "ADR có ≥ 1 phương án bị loại và citations".

    Hai điều kiện của tc đều bị ép ở mã. Một ADR không có phương án bị loại không phải là một
    quyết định — nó là một lời tuyên bố, và sáu tháng sau không ai biết những gì đã được cân
    nhắc rồi bỏ. Trích dẫn cũng vậy: "chọn RTOS vì nhanh hơn" không kiểm được; "chọn RTOS vì
    fact f_abc ghi context switch 1,2 µs" thì kiểm được.
    """
    root = _root(ctx)
    d = params["decision"]
    resp = _gateway(ctx).run(
        "architect",
        "Hoàn thiện Architecture Decision Record theo mẫu. BẮT BUỘC: ít nhất một phương án bị "
        "loại kèm lý do, và citations trỏ tới fact/source id có thật.\n"
        + json.dumps(d, ensure_ascii=False),
        _SCHEMA_ADR, system_extra=_ngu_canh(ctx, f"ADR {d.get('title','')}"))

    a = resp.data
    opts = list(a.get("options") or [])
    chon = a.get("decision") or d.get("choice")
    bi_loai = [o for o in opts if o.get("name") != chon]
    if not bi_loai:
        raise EideError("E5002", "ADR không có phương án nào bị loại — một quyết định không có "
                        "phương án thay thế là một lời tuyên bố, không phải một quyết định "
                        "(ARCH-08 tc)", options=[o.get("name") for o in opts])
    cit = list(a.get("citations") or [])
    if not (co := _citations_co_that(root, cit)):
        raise EideError("E5002", f"ADR không có trích dẫn kiểm được (đã nêu {cit or 'không có'})"
                        " — 'vì nhanh hơn' không kiểm được, 'vì fact f_abc ghi 1,2 µs' thì có",
                        citations=cit)

    aid = _ma_adr(root)
    now = datetime.now(UTC).isoformat()
    f = root / EIDE_DIR / "docs" / "adr" / f"{aid}.md"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(_adr_md(aid, a, chon, opts, co, now), encoding="utf-8")

    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            c.execute("INSERT OR REPLACE INTO adr (id, title, context, options, decision,"
                      " consequences, citations, status, at) VALUES (?,?,?,?,?,?,?,?,?)",
                      (aid, a.get("title") or d.get("title", ""), a.get("context"),
                       json.dumps(opts, ensure_ascii=False), chon, a.get("consequences"),
                       json.dumps(co, ensure_ascii=False), "proposed", now))
            c.commit()
    return {"adr_id": aid, "path": str(f)}


_SCHEMA_ADR = {
    "type": "object", "required": ["title", "context", "options", "decision", "consequences"],
    "properties": {
        "title": {"type": "string"}, "context": {"type": "string"},
        "decision": {"type": "string"}, "consequences": {"type": "string"},
        "options": {"type": "array", "items": {
            "type": "object", "required": ["name"],
            "properties": {"name": {"type": "string"}, "pros": {"type": "string"},
                           "cons": {"type": "string"}}}},
        "citations": {"type": "array", "items": {"type": "string"}},
    },
}


def _citations_co_that(root: Path, cit: list[str]) -> list[str]:
    """Giữ lại những id THẬT SỰ có trong store. Mô hình bịa id là chuyện thường, và một trích
    dẫn bịa còn tệ hơn không trích dẫn: nó tạo vẻ đã kiểm chứng."""
    db = store.store_path(root)
    if not db.exists() or not cit:
        return []
    with store.open_store(db) as c:
        co = {r[0] for r in c.execute(
            f"SELECT id FROM fact WHERE id IN ({','.join('?' * len(cit))})", cit)}  # noqa: S608
        co |= {r[0] for r in c.execute(
            f"SELECT id FROM source WHERE id IN ({','.join('?' * len(cit))})", cit)}  # noqa: S608
    return [x for x in cit if x in co]


def _ma_adr(root: Path) -> str:
    db = store.store_path(root)
    n = 0
    if db.exists():
        with store.open_store(db) as c:
            for (i,) in c.execute("SELECT id FROM adr").fetchall():
                if (m := re.fullmatch(r"ADR-(\d+)", str(i))):
                    n = max(n, int(m.group(1)))
    return f"ADR-{n + 1:02d}"


def _adr_md(aid: str, a: dict[str, Any], chon: str, opts: list[dict[str, Any]],
            cit: list[str], now: str) -> str:
    d = [f"# {aid} — {a.get('title', '')}", "", f"*Trạng thái:* proposed · *Ngày:* {now[:10]}",
         "", "## Bối cảnh", "", a.get("context") or "—", "", "## Phương án", ""]
    for o in opts:
        dau = "**(chọn)**" if o.get("name") == chon else ""
        d += [f"### {o.get('name')} {dau}".strip(), "",
              f"- Ưu: {o.get('pros') or '—'}", f"- Nhược: {o.get('cons') or '—'}", ""]
    d += ["## Quyết định", "", chon or "—", "", "## Hệ quả", "",
          a.get("consequences") or "—", "", "## Trích dẫn", ""]
    d += [f"- `{x}`" for x in cit]
    return "\n".join(d) + "\n"


# ---------------------------------------------------------------- ARCH-09 review


# Bước 1 liệt kê bảy hạng mục; sáu trong đó kiểm được bằng quy tắc. Mỗi mục ghi kèm `rule` để
# `arch.review` nói ĐƯỢC VÌ SAO, và để người dùng tắt từng quy tắc thay vì tắt cả năng lực.
CHECKLIST = (
    ("coupling", "high", "Phụ thuộc chéo giữa hai module cùng lớp"),
    ("isr_dai", "high", "Hàm gọi từ ISR có vòng lặp hoặc chờ"),
    ("tai_nguyen_chung", "high", "Tài nguyên dùng chung không khai khóa"),
    ("watchdog", "medium", "Không module nào phụ trách watchdog"),
    ("loi_bus", "medium", "Driver bus không khai mã lỗi"),
    ("thu_tu_clock", "medium", "Module dùng ngoại vi nhưng không phụ thuộc lớp hal/clock"),
)

# Dấu hiệu "ISR dài" trong chữ ký/ràng buộc gọi. TC-70 kiểm đúng mục này.
DAU_HIEU_ISR_DAI = ("while", "for(", "for ", "delay", "sleep", "wait", "chờ", "block", "printf",
                    "malloc", "scanf")


@capability("arch.review")
def review(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-09 — CDS-12.1. tc: TC-70 "ISR dài → finding".

    Checklist chạy TRƯỚC mô hình và độc lập với nó. Lý do: những lỗi này là lỗi cấu trúc lặp
    lại, và một quy tắc thì không có ngày nghỉ — mô hình có thể bỏ sót cùng một lỗi ở lần chạy
    thứ hai trên cùng dữ liệu, còn quy tắc thì không.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    findings = _checklist(root, mods)

    resp = _gateway(ctx).run(
        "architect",
        "Soát kiến trúc nhúng dưới đây. Quy tắc tự động đã tìm ra các mục kèm theo — TÌM THÊM "
        "cái chúng bỏ sót, đừng lặp lại.\n"
        f"Module: {json.dumps(mods, ensure_ascii=False, default=str)}\n"
        f"Đã tìm được: {json.dumps(findings, ensure_ascii=False)}",
        _SCHEMA_REVIEW, system_extra=_ngu_canh(ctx, "soát kiến trúc"))

    da_co = {(f["module"], f["rule"]) for f in findings}
    for f in (resp.data.get("findings") or []):
        if (f.get("module"), f.get("rule")) not in da_co:
            findings.append({"severity": f.get("severity", "low"), "module": f.get("module"),
                             "rule": f.get("rule", "architect"), "message": f.get("message", ""),
                             "nguon": "mô hình"})
    return {"findings": findings}


_SCHEMA_REVIEW = {
    "type": "object", "required": ["findings"],
    "properties": {"findings": {"type": "array", "items": {
        "type": "object", "required": ["module", "message"],
        "properties": {"severity": {"type": "string", "enum": ["high", "medium", "low"]},
                       "module": {"type": "string"}, "rule": {"type": "string"},
                       "message": {"type": "string"}}}}},
}


def _checklist(root: Path, mods: list[dict[str, Any]]) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    theo_id = {m["id"]: m for m in mods}
    muc = {k: (sev, mo) for k, sev, mo in CHECKLIST}

    def them(rule: str, mod: str, chi_tiet: str) -> None:
        sev, mo = muc[rule]
        ra.append({"severity": sev, "module": mod, "rule": rule,
                   "message": f"{mo}: {chi_tiet}", "nguon": "quy tắc"})

    for m in mods:
        for d in (m.get("depends") or []):
            if d in theo_id and _lop_cua(theo_id[d]) == _lop_cua(m):
                them("coupling", m["id"], f"phụ thuộc {d} cùng lớp {_lop_cua(m)}")

        for fn in (m.get("interfaces") or []):
            sig = (fn.get("sig") or "").lower()
            mo_ta = f"{sig} {(fn.get('timing') or '').lower()}"
            if fn.get("isr_safe") and any(x in mo_ta for x in DAU_HIEU_ISR_DAI):
                them("isr_dai", m["id"],
                     f"{fn.get('sig')} khai isr_safe nhưng có dấu hiệu chờ/lặp")
            if re.search(r"\b(i2c|spi|uart|can)(_|\b)", sig) and not (fn.get("errors") or []):
                them("loi_bus", m["id"], f"{fn.get('sig')} không khai mã lỗi bus")

        if _ngoai_vi_can(m) and not any(_lop_cua(theo_id[d]) == "hal"
                                        for d in (m.get("depends") or []) if d in theo_id):
            them("thu_tu_clock", m["id"],
                 f"dùng {_ngoai_vi_can(m)} nhưng không phụ thuộc module lớp hal")

    if mods and not any("watchdog" in f"{m['id']} {m.get('responsibility') or ''}".lower()
                        for m in mods):
        them("watchdog", "—", "không module nào nhắc tới watchdog")

    ra.extend(_tai_nguyen_chung(root, mods, muc))
    return ra


def _tai_nguyen_chung(root: Path, mods: list[dict[str, Any]],
                      muc: dict[str, tuple[str, str]]) -> list[dict[str, Any]]:
    """Tài nguyên phần cứng bị hai module dùng chung mà không khai `role='shared'`.

    Khác `arch.map_hw`: ở đó xung đột là lỗi CHẶN (hai module đòi cùng một chân), ở đây là phát
    hiện SOÁT (dùng chung có chủ ý nhưng chưa nói tới khóa). Cùng dữ liệu, hai mức nghiêm trọng.
    """
    db = store.store_path(root)
    if not db.exists() or not mods:
        return []
    ids = [m["id"] for m in mods]
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT resource, module_id, role FROM hw_map WHERE module_id IN "
            f"({','.join('?' * len(ids))})", ids).fetchall()  # noqa: S608
    theo_tn: dict[str, list[tuple[str, str]]] = {}
    for tn, mid, role in rows:
        theo_tn.setdefault(tn, []).append((mid, role))
    sev, mo = muc["tai_nguyen_chung"]
    return [{"severity": sev, "module": ", ".join(m for m, _ in ds), "rule": "tai_nguyen_chung",
             "message": f"{mo}: {tn} dùng bởi {len(ds)} module", "nguon": "quy tắc"}
            for tn, ds in theo_tn.items() if len(ds) > 1]


# ---------------------------------------------------------------- ARCH-10 compare


@capability("arch.compare")
def compare(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-10 — CDS-12.1. tc: TC-70 "bảng có trọng số"; ask "Chọn phương án cuối".

    Chấm điểm do mô hình, CỘNG ĐIỂM do mã. Nghe như chi li thừa, nhưng một mô hình được yêu cầu
    "chấm rồi chọn" hay chọn trước rồi chấm ngược lại cho khớp — và khi ấy bảng trọng số trở
    thành trang trí cho một kết luận đã có sẵn.

    Ở mức T1* `recommendation` chỉ là ĐỀ CỬ; ask "Chọn phương án cuối" nghĩa là chốt phương án
    là việc của người.
    """
    options = params["options"]
    tieu_chi = params.get("criteria") or TIEU_CHI_MAC_DINH
    resp = _gateway(ctx).run(
        "architect",
        "Chấm từng phương án theo từng tiêu chí, thang 1–5, kèm lý do một câu. CHỈ chấm điểm — "
        "không kết luận phương án nào thắng.\n"
        f"Phương án: {json.dumps(options, ensure_ascii=False)}\n"
        f"Tiêu chí: {json.dumps(tieu_chi, ensure_ascii=False)}",
        _SCHEMA_COMPARE, system_extra=_ngu_canh(ctx, "so sánh phương án kiến trúc"))

    diem = {s["option"]: s for s in (resp.data.get("scores") or [])}
    tong_w = sum(float(t.get("weight", 1)) for t in tieu_chi) or 1.0
    bang, ket = [], {}
    for o in options:
        ten = o.get("name") or str(o)
        d = (diem.get(ten) or {}).get("by_criterion") or {}
        hang = {"option": ten}
        s = 0.0
        for t in tieu_chi:
            v = float(d.get(t["name"], {}).get("score", 0) if isinstance(d.get(t["name"]), dict)
                      else d.get(t["name"], 0) or 0)
            hang[t["name"]] = v
            s += v * float(t.get("weight", 1))
        hang["weighted"] = round(s / tong_w, 3)
        ket[ten] = hang["weighted"]
        bang.append(hang)

    tot = max(ket, key=lambda k: ket[k]) if ket else None
    return {"comparison": {
        "matrix": bang, "criteria": tieu_chi, "scores": ket,
        "recommendation": tot,
        "note": "đề cử theo điểm có trọng số; chốt phương án là quyết định của người "
                "(ARCH-10 ask: Chọn phương án cuối)"}}


_SCHEMA_COMPARE = {
    "type": "object", "required": ["scores"],
    "properties": {"scores": {"type": "array", "items": {
        "type": "object", "required": ["option", "by_criterion"],
        "properties": {"option": {"type": "string"},
                       "by_criterion": {"type": "object"}}}}},
}


# ---------------------------------------------------------------- ARCH-11 to_plan


@capability("arch.to_plan")
def to_plan(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ARCH-11 — CDS-12.1. tc: "FEATURES.json có đủ module".

    Ủy quyền cho `plan.order`, không tự sắp lại. Có hai chỗ trong kho biết thứ tự bậc phần cứng
    (clock → gpio → bus → cảm biến → app); để cả hai cùng biết là để chúng trôi khỏi nhau, và
    khi ấy `arch.to_plan` và `plan.order` cho hai thứ tự khác nhau cho cùng một tập module —
    không ai biết cái nào đúng.
    """
    root = _root(ctx)
    mods = _doc_module(root, params["module_ids"])
    if not mods:
        raise EideError("E2000", f"Không có module nào trong {params['module_ids']}",
                        exists=[], candidates=[], missing=list(params["module_ids"]))

    from eide.caps.plan import order
    thu_tu = order({"features": [m["id"] for m in mods]}, ctx)

    _ghi_feature(root, mods)
    f = root / EIDE_DIR / "FEATURES.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(
        {"features": [{"id": m["id"], "title": m["name"],
                       "requirement_ids": _req_cua(root, m["id"])} for m in mods],
         "order": thu_tu["order"], "cycles": thu_tu.get("cycles") or []},
        ensure_ascii=False, indent=2), encoding="utf-8")
    return {"features": [m["id"] for m in mods], "order": thu_tu["order"]}


def _req_cua(root: Path, mid: str) -> list[str]:
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        return [r[0] for r in c.execute("SELECT id FROM requirement WHERE trace LIKE ?",
                                        (f'%"{mid}"%',)).fetchall()]


def _ghi_feature(root: Path, mods: list[dict[str, Any]]) -> None:
    """Mỗi module → một Feature `failing`. `failing` chứ không `blocked`: chưa có bằng chứng nào
    nói nó chạy, và đó đúng nghĩa của `failing` trong DDD-14 §2 Feature."""
    db = store.store_path(root)
    if not db.exists():
        return
    now = datetime.now(UTC).isoformat()
    with store.open_store(db) as c:
        for m in mods:
            c.execute("INSERT OR REPLACE INTO feature (id, title, status, requirement_ids,"
                      " updated_at) VALUES (?,?,?,?,?)",
                      (m["id"], m["name"], "failing",
                       json.dumps(_req_cua(root, m["id"]), ensure_ascii=False), now))
        c.commit()
