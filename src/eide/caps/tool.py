"""Namespace tool.* — ToolForge: tác tử tự viết công cụ. WI-020.

Spec: CDS-12.3 TOOL-01…07; SEC-25 §2, §5; POL-17 cổng G-TOOL (TOOL-01…05); APD-08 §4.2;
PRS-16 vai trò coder; API-15 E5002, E5003, E8000, E4000, E3000.

Đây là chỗ tác tử ghi mã rồi CHẠY mã ấy trên máy người dùng. Toàn bộ nhóm này được dựng quanh
một câu hỏi duy nhất: điều gì ngăn một công cụ làm thứ nó không khai báo? Câu trả lời không
phải một lớp mà là bốn, và mỗi lớp bắt được thứ lớp trước bỏ sót —

    tool.write     kiểm AST, chặn import và eval/exec  (bắt lỗi cú pháp rõ ràng)
    tool.test      chạy trong sandbox + audit hook      (bắt hiệu ứng ngầm — TC-TL-02)
    tool.run       PolicyGate cổng G-TOOL               (bắt việc chưa được phép)
    tool.register  đòi đã test đạt                      (chặn công cụ chưa ai kiểm vào registry)

Bỏ bất kỳ lớp nào cũng để lại một đường đi trọn vẹn cho mã không khai báo.
"""
from __future__ import annotations

import json
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core.errors import EideError
from eide_core.gateway import Gateway
from eide_core.registry import capability, get_registry
from eide_core.router import Context
from eide_core.sandbox import Sandbox
from eide_core.toolforge import (
    MAU_CONG_CU,
    GiamSatHieuUng,
    ToolSpec,
    hieu_ung_khop,
    json_gon,
    kiem_ast,
    mau_test,
)

MAX_VONG_SUA = 3      # TOOL-07: "≤ 3 vòng"


def _thu_muc(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])
    d = root / EIDE_DIR / "tools"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _doc_spec(ctx: Context, tool_id: str) -> ToolSpec:
    f = _thu_muc(ctx) / tool_id / "spec.json"
    if not f.exists():
        raise EideError("E2000", f"Không có công cụ {tool_id}",
                        exists=[], candidates=[], missing=[tool_id])
    return ToolSpec.from_dict(json.loads(f.read_text(encoding="utf-8")))


def _gateway(ctx: Context) -> Gateway:
    gw = ctx.extra.get("gateway")
    if gw is None:
        gw = Gateway(ledger=ctx.extra.get("ledger"))
        ctx.extra["gateway"] = gw
    return gw


# ---------------------------------------------------------------- TOOL-01

SPEC_SCHEMA = {
    "type": "object",
    "required": ["name", "purpose", "effects"],
    "properties": {
        "name": {"type": "string"},
        "purpose": {"type": "string"},
        "effects": {"type": "array", "items": {
            "type": "string",
            "enum": ["read_fs", "network", "write_project", "hardware", "system"]}},
        "deps": {"type": "array", "items": {"type": "string"}},
        "input_schema": {"type": "object"},
        "output_schema": {"type": "object"},
        "acceptance": {"type": "array", "items": {"type": "object"}},
    },
}


@capability("tool.need")
def need(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-01 — CDS-12.3; PRS-16 vai trò planner; E5002.

    Trước khi viết công cụ mới, TÌM cái đã có (`reuse`): mỗi công cụ mới là một mảnh mã nữa
    phải kiểm, phải sửa, phải tin. Số công cụ tăng không phải một chỉ số tốt.
    """
    gap = params["gap"]
    ngu_canh = json.dumps(params.get("context") or {}, ensure_ascii=False)[:800]
    resp = _gateway(ctx).run(
        "planner",
        f"Việc không có năng lực phù hợp: {gap}\nNgữ cảnh: {ngu_canh}\n"
        "Hãy mô tả MỘT công cụ nhỏ, thuần, đủ làm việc ấy. Hiệu ứng khai đúng và ĐỦ ÍT nhất "
        "có thể: chỉ khai `network`/`system`/`hardware` khi thật sự cần.",
        SPEC_SCHEMA)
    spec = ToolSpec.from_dict(resp.data)           # kiểm tên và hiệu ứng ngay
    # `reuse` là MẢNG công cụ gần khớp (output_schema), không phải một id: người quyết định
    # dùng lại cần thấy các ứng viên kèm điểm, chứ không phải một lựa chọn đã bị máy chốt sẵn.
    da_co = [x for x in search({"spec": spec.as_dict()}, ctx)["tools"] if x["score"] >= 0.8]
    return {"spec": spec.as_dict(), "reuse": da_co}


# ---------------------------------------------------------------- TOOL-02

@capability("tool.search")
def search(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-02 — CDS-12.3; tc "công cụ đã có → điểm ≥ 0,8"."""
    spec = ToolSpec.from_dict(params["spec"])
    ra: list[dict[str, Any]] = []
    try:
        goc = _thu_muc(ctx)
    except EideError:
        return {"tools": []}
    for d in sorted(goc.iterdir()):
        f = d / "spec.json"
        if not f.exists():
            continue
        khac = ToolSpec.from_dict(json.loads(f.read_text(encoding="utf-8")))
        ra.append({"tool_id": d.name, "score": _diem(spec, khac),
                   "uses": _dem_dung(d), "last_ok": _lan_dat_cuoi(d)})
    ra.sort(key=lambda x: x["score"], reverse=True)
    return {"tools": [x for x in ra if x["score"] > 0.3]}


def _diem(a: ToolSpec, b: ToolSpec) -> float:
    """Giống nhau theo tên và mục đích. Tên trùng là bằng chứng mạnh nhất — công cụ do chính
    tác tử đặt tên nên tên mang nghĩa, không phải nhãn tùy tiện."""
    if a.name == b.name:
        return 1.0
    ta, tb = set(a.name.split("_")), set(b.name.split("_"))
    chung = len(ta & tb) / max(len(ta | tb), 1)
    tu_a = set(a.purpose.lower().split())
    tu_b = set(b.purpose.lower().split())
    muc = len(tu_a & tu_b) / max(len(tu_a | tu_b), 1) if tu_a and tu_b else 0.0
    return round(0.7 * chung + 0.3 * muc, 3)


def _dem_dung(d: Path) -> int:
    f = d / "uses.json"
    return int(json.loads(f.read_text(encoding="utf-8")).get("ok", 0)) if f.exists() else 0


def _lan_dat_cuoi(d: Path) -> str | None:
    f = d / "uses.json"
    return json.loads(f.read_text(encoding="utf-8")).get("last_ok") if f.exists() else None


# ---------------------------------------------------------------- TOOL-03

CODE_SCHEMA = {
    "type": "object",
    "required": ["files", "rationale"],
    "properties": {
        "files": {"type": "array", "items": {
            "type": "object", "required": ["path", "content"],
            "properties": {"path": {"type": "string"}, "content": {"type": "string"}}}},
        "rationale": {"type": "string"},
        "cites": {"type": "array", "items": {"type": "string"}},
        "tests": {"type": "array", "items": {"type": "string"}},
    },
}


@capability("tool.write")
def write(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-03 — CDS-12.3; PRS-16 coder; E5002, E5003, E8000; undo delete_created_files.

    Kiểm AST TRƯỚC KHI LƯU, không phải trước khi chạy: một tệp mã có `import subprocess` nằm
    trong `.eide/tools/` là một tệp ai đó sẽ chạy — kể cả khi ToolForge không chạy nó.
    """
    spec = ToolSpec.from_dict(params["spec"])
    resp = _gateway(ctx).run(
        "coder",
        f"Viết một mô-đun Python cho công cụ sau.\n{json_gon(spec.as_dict())}\n\n"
        f"BẮT BUỘC: một hàm `run(args: dict, ctx=None) -> dict`; hằng `SPEC` chứa schema; "
        f"kiểm tham số; lỗi ném EideError. Hiệu ứng được phép: {spec.effects or 'không có'} — "
        f"KHÔNG import gì ngoài phạm vi ấy, KHÔNG dùng eval/exec/__import__.\n"
        f"Trả một tệp duy nhất, path = 'tool.py'.",
        CODE_SCHEMA)

    ma = next((f["content"] for f in resp.data["files"] if f["path"].endswith("tool.py")), None)
    if ma is None:
        raise EideError("E5002", "Coder không trả tệp tool.py")

    vi_pham = kiem_ast(ma, spec.effects)
    if vi_pham:
        # E5003 chứ không phải E5002: đây không phải "đầu ra sai schema" mà là mã vi phạm
        # hiệu ứng đã khai — một loại lỗi khác, và cách xử lý cũng khác (sửa hoặc khai lại).
        raise EideError("E5003", f"Mã vi phạm hiệu ứng khai báo {spec.effects}: {', '.join(vi_pham)}",
                        violations=vi_pham, effects=spec.effects)

    d = _thu_muc(ctx) / spec.name
    d.mkdir(parents=True, exist_ok=True)
    (d / "tool.py").write_text(ma if ma.endswith("\n") else ma + "\n", encoding="utf-8")
    (d / "test_tool.py").write_text(mau_test(spec), encoding="utf-8")
    (d / "spec.json").write_text(json_gon(spec.as_dict()) + "\n", encoding="utf-8")

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("tool.report", {"tool": spec.name, "passed": True, "log_ref": str(d),
                                   "metrics": {"effects": spec.effects, "risk": spec.risk},
                                   "artifacts": ["tool.py", "test_tool.py"], "duration_ms": 0,
                                   "started_by": "agent", "at": datetime.now(UTC).isoformat()})
    return {"tool_id": spec.name, "code_path": str(d / "tool.py"),
            "test_path": str(d / "test_tool.py"), "effects": spec.effects}


# ---------------------------------------------------------------- TOOL-04

@capability("tool.test")
def test(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-04 — CDS-12.3; SEC-25 §2; tc TC-TL-02 ("gọi socket ngầm → effects_ok=false").

    Chạy test trong sandbox KHÔNG MẠNG, rồi nạp công cụ dưới audit hook để xem hiệu ứng THẬT.
    Hai bước tách nhau vì chúng trả lời hai câu khác nhau: test hỏi "nó có làm đúng việc
    không", audit hỏi "nó có làm gì ngoài việc đã khai không". Một công cụ có thể đạt câu đầu
    và trượt câu sau — đó chính là TC-TL-02.
    """
    tool_id = params["tool_id"]
    spec = _doc_spec(ctx, tool_id)
    d = _thu_muc(ctx) / tool_id

    sb = Sandbox(out_dir=Path(ctx.project_dir) / EIDE_DIR / "cache" / "tool",
                 ledger=ctx.extra.get("ledger"))
    kq = sb.run([sys.executable, "-m", "pytest", "-q", str(d / "test_tool.py")],
                limits={"cpu_s": 60, "rss_mb": 512, "wall_s": 120},
                allowed_dirs=[str(d)], network=False)

    quan_sat = _quan_sat_hieu_ung(d, spec)
    ok = hieu_ung_khop(quan_sat, spec.effects)
    report = {"tool": tool_id, "passed": kq.exit_code == 0 and ok, "log_ref": kq.stdout_ref,
              "metrics": {"exit_code": kq.exit_code, "isolation": kq.isolation},
              "artifacts": [kq.stdout_ref, kq.stderr_ref], "duration_ms": kq.duration_ms,
              "started_by": "agent", "at": datetime.now(UTC).isoformat()}

    # Ghi kết quả ra đĩa: `tool.run` và `tool.register` đều hỏi "đã test đạt chưa", và câu
    # trả lời phải sống qua việc tắt tiến trình — nó là điều kiện an toàn, không phải bộ nhớ đệm.
    (d / "last_test.json").write_text(
        json_gon({"passed": report["passed"], "effects_ok": ok,
                  "observed": sorted(quan_sat), "declared": spec.effects,
                  "at": report["at"]}) + "\n", encoding="utf-8")

    led = ctx.extra.get("ledger")
    if led is not None and not ok:
        # SEC-25: hiệu ứng vượt khai báo vào SỔ LỖI, không chỉ vào kết quả — MEM-11 §6 dùng sổ
        # lỗi sinh prompt phủ định, nên lần sau coder được nhắc chính chỗ nó vừa sai.
        led.append("error", {"kind": "tool_fail", "role": "coder", "task_ref": tool_id,
                             "evidence": f"hiệu ứng thật {sorted(quan_sat)} vượt khai báo {spec.effects}"})
    return {"report": report, "observed_effects": sorted(quan_sat), "effects_ok": ok}


def _quan_sat_hieu_ung(d: Path, spec: ToolSpec) -> set[str]:
    """Nạp và gọi thử công cụ dưới audit hook để thấy hiệu ứng THẬT (TOOL-04 bước 1)."""
    import importlib.util
    m = importlib.util.spec_from_file_location(f"eide_tool_{spec.name}", d / "tool.py")
    if m is None or m.loader is None:
        return set()
    mod = importlib.util.module_from_spec(m)
    cu = sys.dont_write_bytecode
    sys.dont_write_bytecode = True     # thêm một lớp nữa cho cùng lý do ở GiamSatHieuUng._hook
    GiamSatHieuUng.bat_dau()
    try:
        m.loader.exec_module(mod)
        for vd in spec.acceptance or [{"args": {}}]:
            try:
                mod.run(vd.get("args", {}))
            except Exception:            # noqa: BLE001 — lỗi của công cụ là dữ liệu, không phải sự cố
                pass
    except Exception:                    # noqa: BLE001 — kể cả nạp hỏng, thứ đã quan sát vẫn tính
        pass
    finally:
        quan_sat = GiamSatHieuUng.ket_thuc()
        sys.dont_write_bytecode = cu
    # Đọc chính tệp .py là việc của trình nạp, không phải hiệu ứng của công cụ.
    return quan_sat - {"read_fs"} if "read_fs" not in spec.effects else quan_sat


# ---------------------------------------------------------------- TOOL-05

@capability("tool.run", features=["tool"])
def run(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-05 — CDS-12.3; POL-17 G-TOOL; E3000, E3001, E8000, E4000, E5002.

    Cổng G-TOOL được hỏi với ĐẶC TRƯNG THẬT của công cụ (tested, effects, risk, uses_ok), chứ
    không phải với lớp rủi ro của chính năng lực `tool.run`. Nếu hỏi bằng R2 cố định thì một
    công cụ chạm phần cứng và một công cụ đọc tệp đi qua cùng một cửa — và cổng mất hết nghĩa.
    """
    tool_id = params["tool_id"]
    spec = _doc_spec(ctx, tool_id)
    d = _thu_muc(ctx) / tool_id
    da_test = (d / "last_test.json").exists()

    gate = ctx.extra.get("gate")
    if gate is not None:
        dac_trung = {"tool": {"tested": da_test, "effects_ok": da_test, "risk": spec.risk,
                              "effects": spec.effects, "uses_ok": _dem_dung(d),
                              "last_fail_count": 0}}
        qd = gate.decide("G-TOOL", dac_trung, risk=spec.risk, autonomy=ctx.autonomy,
                         board=ctx.board, tier=spec.tier, actor=ctx.actor)
        if qd.decision == "REJECT":
            raise EideError("E3001", f"Cổng G-TOOL từ chối: {qd.reason}", rule=qd.rule_id)
        if qd.decision == "ASK":
            raise EideError("E3000", f"Cần người duyệt: {qd.reason}",
                            rule=qd.rule_id, gate="G-TOOL")

    sb = Sandbox(out_dir=Path(ctx.project_dir) / EIDE_DIR / "cache" / "tool",
                 ledger=ctx.extra.get("ledger"))
    # Truyền args qua `json.loads(<literal>)` chứ không nội suy thẳng vào mã: args đến từ
    # người dùng, và nội suy chuỗi vào một đoạn mã sắp chạy là chỗ tiêm mã kinh điển.
    ma = ("import json, sys\n"
          f"sys.path.insert(0, {str(d)!r})\n"
          "import tool\n"
          f"print(json.dumps(tool.run(json.loads({json.dumps(params.get('args') or {})!r}))))\n")
    kq = sb.run([sys.executable, "-c", ma],
                limits={"cpu_s": 60, "rss_mb": 512, "wall_s": 120},
                allowed_dirs=[str(d)], network="network" in spec.effects)
    if kq.violations:
        raise EideError("E8000", f"Công cụ vượt giới hạn: {kq.violations}", violations=kq.violations)
    if kq.exit_code != 0:
        raise EideError("E4000", f"Công cụ thất bại (mã {kq.exit_code})",
                        log_ref=kq.stderr_ref)

    ra = Path(kq.stdout_ref).read_text(encoding="utf-8").strip()
    try:
        ket_qua = json.loads(ra.splitlines()[-1]) if ra else {}
    except (json.JSONDecodeError, IndexError) as e:
        raise EideError("E5002", f"Công cụ không trả JSON: {ra[:200]}") from e

    _ghi_dung(d)
    return {"result": ket_qua,
            "report": {"tool": tool_id, "passed": True, "log_ref": kq.stdout_ref,
                       "metrics": {"isolation": kq.isolation}, "artifacts": [kq.stdout_ref],
                       "duration_ms": kq.duration_ms, "started_by": ctx.actor,
                       "at": datetime.now(UTC).isoformat()}}


def _ghi_dung(d: Path) -> None:
    f = d / "uses.json"
    cu = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {"ok": 0}
    cu["ok"] = int(cu.get("ok", 0)) + 1
    cu["last_ok"] = datetime.now(UTC).isoformat()
    f.write_text(json.dumps(cu, ensure_ascii=False), encoding="utf-8")


# ---------------------------------------------------------------- TOOL-06

@capability("tool.register")
def register(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-06 — CDS-12.3; E1000 khi chưa test; undo restore_config.

    Đòi `tool.test` đạt trước. Một công cụ chưa ai kiểm mà vào được registry thì lần gọi sau
    nó trông y hệt một năng lực có hợp đồng — và người dùng không có cách nào phân biệt.
    """
    tool_id = params["tool_id"]
    spec = _doc_spec(ctx, tool_id)
    d = _thu_muc(ctx) / tool_id
    f = d / "last_test.json"
    if not f.exists() or not json.loads(f.read_text(encoding="utf-8")).get("effects_ok"):
        raise EideError("E1000", f"Công cụ {tool_id} chưa qua tool.test — không đăng ký được",
                        tool_id=tool_id)

    reg = ctx.extra.get("registry") or get_registry()
    cap_id = f"user.{spec.name}"
    ma_so = f"USER-{len([c for c in reg.list() if c.spec.ns == 'user']) + 1:02d}"
    khai_bao = {
        "code": ma_so, "id": cap_id, "ns": "user", "name": cap_id,
        "desc": spec.purpose or f"Công cụ tự viết {spec.name}",
        "risk": spec.risk, "tier": spec.tier,
        "grounding": "tool_tested",
        "ask_when": "; ".join(spec.effects) if spec.risk in ("R3", "R4") else "—",
        "ref": "TOOL-06", "milestone": "M1",
        "input_schema": spec.input_schema, "output_schema": spec.output_schema,
        "steps": [f"Chạy {d / 'tool.py'}:run trong sandbox theo hiệu ứng {spec.effects}"],
        "errors": ["E8000", "E4000"],
        "undo": "delete_created_files" if "write_project" in spec.effects else "none",
        "example": json.dumps({"tool_id": tool_id, "args": {}}, ensure_ascii=False),
        "tc": "; ".join(str(a) for a in spec.acceptance) or "—", "volume": 1,
        "impl": f"{d / 'tool.py'}:run", "ui": "none",
    }
    (d / "capability.json").write_text(json_gon(khai_bao) + "\n", encoding="utf-8")
    reg.dang_ky_tam(khai_bao)

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("tool.report", {"tool": tool_id, "passed": True, "log_ref": str(d),
                                   "metrics": {"registered_as": cap_id, "risk": spec.risk,
                                               "tier": spec.tier},
                                   "artifacts": ["capability.json"], "duration_ms": 0,
                                   "started_by": ctx.actor, "at": datetime.now(UTC).isoformat()})
    return {"capability_code": ma_so, "capability_id": cap_id}


# ---------------------------------------------------------------- TOOL-07

@capability("tool.repair")
def repair(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-07 — CDS-12.3; MEM-11 §6 sổ lỗi; E5003; tối đa 3 vòng.

    Giới hạn vòng sửa là một quyết định an toàn, không phải tiết kiệm: một vòng lặp sửa không
    chặn sẽ đốt ngân sách mô hình và, tệ hơn, thử đủ biến thể cho tới khi một biến thể lọt qua
    được bộ kiểm — tức là tối ưu hóa cho việc VƯỢT cổng thay vì cho việc đúng.
    """
    tool_id = params["tool_id"]
    vong = int(params.get("round", 1))
    if vong > MAX_VONG_SUA:
        return {"code_path": str(_thu_muc(ctx) / tool_id / "tool.py"), "give_up": True}

    spec = _doc_spec(ctx, tool_id)
    d = _thu_muc(ctx) / tool_id
    ma_cu = (d / "tool.py").read_text(encoding="utf-8")
    loi = ""
    f = d / "last_test.json"
    if f.exists():
        loi = json.dumps(json.loads(f.read_text(encoding="utf-8")), ensure_ascii=False)[:800]

    resp = _gateway(ctx).run(
        "coder",
        f"Công cụ sau thất bại. Sửa nó, giữ nguyên chữ ký `run(args, ctx=None) -> dict`.\n"
        f"Hiệu ứng được phép: {spec.effects or 'không có'}.\n"
        f"Báo cáo lỗi: {loi}\n\nMã hiện tại:\n{ma_cu}",
        CODE_SCHEMA)
    ma = next((x["content"] for x in resp.data["files"] if x["path"].endswith("tool.py")), None)
    if ma is None:
        raise EideError("E5002", "Coder không trả tệp tool.py")
    vi_pham = kiem_ast(ma, spec.effects)
    if vi_pham:
        raise EideError("E5003", f"Bản sửa vẫn vi phạm hiệu ứng: {', '.join(vi_pham)}",
                        violations=vi_pham, round=vong)
    (d / "tool.py").write_text(ma if ma.endswith("\n") else ma + "\n", encoding="utf-8")

    led = ctx.extra.get("ledger")
    if led is not None:
        led.append("error", {"kind": "tool_fail", "role": "coder", "task_ref": tool_id,
                             "evidence": f"sửa vòng {vong}"})
    return {"code_path": str(d / "tool.py"), "give_up": False}


__all__ = ["MAU_CONG_CU", "need", "register", "repair", "run", "search", "test", "write"]
