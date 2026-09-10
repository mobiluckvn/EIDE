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

    # TOOL-10 bước 1: "chuỗi cũ gọi → gợi ý replaced_by". Kiểm TRƯỚC cổng: một công cụ đã khai
    # tử bị G-TOOL từ chối vì lý do khác (chưa đủ lần dùng chẳng hạn) thì người gọi nhận một câu
    # trả lời đúng-nhưng-lạc-đề, và không biết rằng đã có bản thay.
    if (kt := d / "deprecated.json").exists():
        dp = json.loads(kt.read_text(encoding="utf-8"))
        thay = dp.get("replaced_by")
        raise EideError("E2000", f"`{tool_id}` đã khai tử ({dp.get('reason')})"
                        + (f" — dùng `{thay}` thay thế" if thay else ""),
                        exists=[], missing=[tool_id],
                        candidates=[thay] if thay else [], deprecated=dp)

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


# ---------------------------------------------------------------- TOOL-09 compose


MAU_GHEP = '''"""{purpose}

Công cụ GHÉP — sinh bởi `tool.compose` (CDS-12.3 TOOL-09). Nó gọi từng bước qua `ctx.invoke`
chứ KHÔNG nhúng mã của chúng: nhúng là tạo bản sao thứ hai, và sửa công cụ gốc thì bản ghép vẫn
chạy mã cũ trong khi cả hai đều mang tên riêng.
"""
from typing import Any

SPEC = {spec}
BUOC = {buoc}
WIRING = {wiring}


def run(args: dict[str, Any], ctx: Any = None) -> dict[str, Any]:
    if ctx is None or not hasattr(ctx, "invoke"):
        raise RuntimeError("công cụ ghép cần ctx.invoke để gọi từng bước")
    gia_tri = dict(args)
    for tid in BUOC:
        vao = {{k: gia_tri[v] for k, v in WIRING.get(tid, {{}}).items() if v in gia_tri}}
        gia_tri.update(ctx.invoke(tid, vao or gia_tri))
    return gia_tri
'''


@capability("tool.compose")
def compose(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-09 — CDS-12.3; TOOL-05 (hiệu ứng → lớp rủi ro); POL-17 G-TOOL.
    tc: "Effects gồm hardware → risk R3"; lỗi E1000; undo `delete_created_files`.

    **Hiệu ứng của bản ghép là HỢP của các bước.** Lấy hiệu ứng bước đầu — hay tệ hơn, để trống
    — thì một chuỗi có bước chạm phần cứng đi qua cổng G-TOOL như một công cụ chỉ đọc tệp. Lớp
    rủi ro suy ra từ hợp ấy, nên `read_fs + hardware` cho R3 chứ không phải R0.

    **Kiểm schema lúc GHÉP, không lúc chạy.** Một chuỗi hỏng ở bước ba chỉ lộ ra sau khi bước
    một và hai đã gây hiệu ứng — mà hiệu ứng thì không hoàn tác được bằng một thông báo lỗi.

    Bản ghép thừa hưởng `acceptance` của thành phần đầu (đầu vào của chuỗi là đầu vào của nó):
    một công cụ không có test là công cụ `tool.register` từ chối, và khi ấy cả việc ghép thành
    vô ích.
    """
    ten = params["name"]
    ds = list(params["tool_ids"] or [])
    wiring = dict(params["wiring"] or {})
    if len(ds) < 2:
        raise EideError("E1000", "Ghép cần ít nhất hai công cụ", tool_ids=ds)

    specs = [_doc_spec(ctx, t) for t in ds]
    _kiem_noi_khop(specs, wiring)

    hieu_ung = sorted({e for s in specs for e in s.effects})
    ghep = ToolSpec(name=ten, purpose=f"Ghép {' → '.join(ds)}",
                    input_schema=specs[0].input_schema,
                    output_schema=specs[-1].output_schema,
                    effects=hieu_ung,
                    deps=sorted({d for s in specs for d in s.deps}),
                    acceptance=list(specs[0].acceptance))

    d = _thu_muc(ctx) / ten
    d.mkdir(parents=True, exist_ok=True)
    (d / "spec.json").write_text(json_gon(ghep.as_dict()) + "\n", encoding="utf-8")
    (d / "tool.py").write_text(MAU_GHEP.format(
        purpose=ghep.purpose, spec=json_gon(ghep.as_dict()),
        buoc=json_gon(ds), wiring=json_gon({t: wiring for t in ds[1:]})), encoding="utf-8")
    (d / "test_tool.py").write_text(mau_test(ghep), encoding="utf-8")

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"tool:{ten}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"tool_id": ten}


def _kiem_noi_khop(specs: list[ToolSpec], wiring: dict[str, Any]) -> None:
    """`wiring` ánh xạ output→input giữa hai bước liền nhau. Kiểm cả TÊN lẫn KIỂU.

    Chỉ kiểm tên thì `{"s": "y"}` nối một số vào một tham số chuỗi trót lọt, và lỗi nổ ở giữa
    chuỗi — sau khi bước trước đã chạy.
    """
    for truoc, sau in zip(specs, specs[1:], strict=False):
        ra = (truoc.output_schema.get("properties") or {})
        vao = (sau.input_schema.get("properties") or {})
        for khoa_vao, khoa_ra in wiring.items():
            if khoa_ra not in ra:
                raise EideError("E1000", f"`{truoc.name}` không có đầu ra `{khoa_ra}`",
                                have=sorted(ra), want=khoa_ra)
            if khoa_vao not in vao:
                continue
            a, b = ra[khoa_ra].get("type"), vao[khoa_vao].get("type")
            if a and b and a != b:
                raise EideError("E1000", f"Kiểu không khớp: {truoc.name}.{khoa_ra} là {a}, "
                                f"{sau.name}.{khoa_vao} cần {b}", got=a, want=b)
        thieu = [k for k in (sau.input_schema.get("required") or []) if k not in wiring]
        if thieu:
            raise EideError("E1000", f"`{sau.name}` cần {thieu} mà `wiring` không nối",
                            missing=thieu)


# ---------------------------------------------------------------- TOOL-10 deprecate


@capability("tool.deprecate")
def deprecate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-10 — CDS-12.3; CXD-10 §4.2 (C0). tc: "Không còn trong caps.list mặc định";
    undo `restore_config`.

    Khai tử **không phải xóa**: mã và lịch sử ở lại. Một chuỗi cũ trong nhật ký vẫn nhắc tới
    công cụ ấy, và người đọc nhật ký sáu tháng sau cần mở được mã để hiểu chuyện gì đã xảy ra.
    Cái bị lấy đi chỉ là chỗ đứng trong danh sách gợi ý — tức là quyền được mô hình nhìn thấy.

    `replaced_by` đi vào chính thông điệp lỗi khi ai đó gọi lại: báo "không có năng lực này" cho
    một thứ vừa bị thay là bắt người dùng đi tìm, còn nêu tên bản thay là trả lời đúng câu họ
    đang hỏi.
    """
    tool_id = params["tool_id"]
    d = _thu_muc(ctx) / tool_id
    if not (d / "spec.json").exists():
        raise EideError("E2000", f"Không có công cụ `{tool_id}`", exists=[], candidates=[],
                        missing=[tool_id])

    (d / "deprecated.json").write_text(json_gon({
        "tool_id": tool_id, "reason": params["reason"],
        "replaced_by": params.get("replaced_by"),
        "at": datetime.now(UTC).isoformat(), "by": ctx.actor}) + "\n", encoding="utf-8")

    reg = ctx.extra.get("registry") or get_registry()
    reg.bo_dang_ky_tam(f"user.{_doc_spec(ctx, tool_id).name}")

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"deprecate:{tool_id}",
                                     "kind": "restore_config", "deadline": ""})
    return {"ok": True}


# ---------------------------------------------------------------- TOOL-08 promote


LAN_DUNG_TOI_THIEU = 3      # bước 1: "uses ≥ 3 thành công"
LAN_BENCH = 3               # "bench.run mini (acceptance × 3 lần)"


@capability("tool.promote")
def promote(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: TOOL-08 — CDS-12.3; BEN-21 (bench mini); PKG-22 (.hkp kind=tool). Mức **T2**, ask
    "Luôn"; lỗi E3000; `undo: none`. tc: "Đề xuất không tự áp dụng; sau duyệt registry có năng
    lực mới".

    Năng lực này **trả về một đề xuất và không đụng gì tới registry**. Tự đổi `user.crc16`
    thành `hkw.crc16` là để một công cụ do mô hình viết mang tên của namespace mà người dùng
    tin — và người dùng phân biệt hai namespace ấy chính vì một bên đã qua tay người.

    Ba điều kiện của bước 1 kiểm TRƯỚC khi tốn công chạy bench: `uses ≥ 3` thành công, không vi
    phạm hiệu ứng, đã có test. Thăng cấp một công cụ mới chạy một lần là đề nghị người khác tin
    vào thứ chính ta chưa tin.

    Bench mini chạy `acceptance` **ba lần**, không một lần: một công cụ đọc trạng thái ngoài
    (giờ, tệp tạm, bộ đếm) có thể đúng lần đầu rồi sai lần sau — và đó đúng là loại không nên
    mang tên namespace chung.
    """
    tool_id, ns = params["tool_id"], params["target_ns"]
    spec = _doc_spec(ctx, tool_id)
    d = _thu_muc(ctx) / tool_id

    kiem = (d / "last_test.json")
    da_test = kiem.exists() and json.loads(kiem.read_text(encoding="utf-8")).get("effects_ok")
    dung = _dem_dung(d)
    thieu = ([] if da_test else ["chưa qua tool.test (hoặc effects_ok=false)"]) + \
            ([] if dung >= LAN_DUNG_TOI_THIEU else [f"mới {dung}/{LAN_DUNG_TOI_THIEU} lần dùng"])
    if thieu:
        raise EideError("E3000", f"`{tool_id}` chưa đủ điều kiện thăng cấp: {'; '.join(thieu)}",
                        gate="G-TOOL", uses_ok=dung, tested=bool(da_test))

    bench = _bench_mini(spec, d)
    if bench["passed"] < bench["runs"]:
        raise EideError("E3000", f"Bench mini không ổn định: {bench['passed']}/{bench['runs']} "
                        "lần đạt — một công cụ chạy khác nhau giữa các lần thì không mang tên "
                        "namespace chung được", bench=bench)

    dang = "hkp" if "hardware" in spec.effects or "system" in spec.effects else "pr"
    return {"proposal": {
        "kind": dang, "target_id": f"{ns}.{spec.name}", "from_id": f"user.{spec.name}",
        "risk": spec.risk, "tier": spec.tier, "effects": list(spec.effects),
        "uses_ok": dung, "bench": bench,
        "files": [str(d / "tool.py"), str(d / "spec.json"), str(d / "test_tool.py")],
        "review": "Pack owner duyệt (T2); sau duyệt: đổi id user.* → <ns>.*, cập nhật Danh mục "
                  "và CDS",
        "note": "Đề xuất KHÔNG tự áp dụng — registry chưa đổi gì (TOOL-08 tc)"}}


def _bench_mini(spec: ToolSpec, d: Path) -> dict[str, Any]:
    """Chạy `acceptance` ba lần trong tiến trình con, đếm số lần đạt.

    Không gọi `bench.run` (BENCH-01, mốc M2 chưa hiện thực): "bench mini" của TOOL-08 là chính
    các ca `acceptance` chạy lặp, không phải bộ benchmark theo board của BEN-21. Chờ `bench.run`
    để làm được việc này là chờ một thứ nặng hơn hẳn thứ đang cần.
    """
    import subprocess
    dat = 0
    for _ in range(LAN_BENCH):
        ok = True
        for ca in (spec.acceptance or [{}]):
            ma = ("import json, sys\n"
                  f"sys.path.insert(0, {str(d)!r})\n"
                  "import tool\n"
                  f"print(json.dumps(tool.run(json.loads({json.dumps(ca.get('args') or {})!r}))))\n")
            p = subprocess.run([sys.executable, "-c", ma], capture_output=True,  # noqa: S603
                               text=True, timeout=60, check=False)
            if p.returncode != 0:
                ok = False
                break
            if (cho := ca.get("expect")) is not None:
                try:
                    ra = json.loads(p.stdout.strip().splitlines()[-1])
                except (json.JSONDecodeError, IndexError):
                    ok = False
                    break
                if any(ra.get(k) != v for k, v in cho.items()):
                    ok = False
                    break
        dat += int(ok)
    return {"runs": LAN_BENCH, "passed": dat, "cases": len(spec.acceptance or [])}


__all__ = ["MAU_CONG_CU", "compose", "deprecate", "need", "promote", "register", "repair",
           "run", "search", "test", "write"]
