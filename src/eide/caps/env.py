"""Namespace env.* — CDS-12.3; TGT-19 (manifest ISA, toolchain); PLATFORM.md."""
from __future__ import annotations

import platform
import re
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import tools
from eide_core.errors import EideError
from eide_core.paths import spec_dir, user_cache
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.sandbox import Sandbox


@capability("env.detect")
def detect(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-01 — CDS-12.3; TGT-19 §discover. OS/arch/python/shell; cổng và probe do discover.* bổ sung (Sprint 2)."""
    return {"env": {"os": tools.os_name(), "os_version": platform.mac_ver()[0] or platform.release(),
                    "arch": tools.arch(), "python": sys.version.split()[0],
                    "shell": platform.uname().system, "ports": [], "probes": []}}


def _ver_ok(found: str | None, minimum: str | None) -> bool:
    if not minimum:
        return found is not None
    if not found:
        return False
    m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", found)
    if not m:
        return False
    got = tuple(int(x or 0) for x in m.groups())
    need = tuple(int(x) for x in minimum.split(".")) + (0,) * (3 - minimum.count(".") - 1)
    return got >= need


@capability("env.check")
def check(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-02 — CDS-12.3; TGT-19 manifest `toolchain`; E2000 khi ISA không có manifest; ok=false kèm install hint."""
    isa = params["isa"]
    path = spec_dir() / "isa" / f"{isa}.yaml"
    if not path.exists():
        raise EideError("E2000", f"ISA '{isa}' chưa có manifest trong docs/spec/isa/ (TGT-19)")
    man = yaml.safe_load(path.read_text(encoding="utf-8"))
    tc = man.get("toolchain", {})
    os_key = {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}[tools.os_name()]
    hints = (tc.get("install") or {}).get(os_key, [])
    wanted = [dict(tc.get("compiler", {}), required=True)] + [dict(t, required=True) for t in tc.get("tools", [])]
    report = []
    for t in wanted:
        exe = tools.which(t["name"])
        ver = tools.version_of(exe) if exe else None
        report.append({"tool": t["name"], "required": t["required"], "found": str(exe) if exe else None,
                       "version": ver, "ok": bool(exe) and _ver_ok(ver, t.get("min")), "min": t.get("min"),
                       "hash": None, "install_hint": None if exe else hints})
    return {"report": report}


@capability("env.sandbox")
def sandbox(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-07 — CDS-12.3; SEC-25 §2; STP-05 TC-SE-03; API-15 E8000, E4004.

    Trả `stdout_ref`/`stderr_ref` là ĐƯỜNG DẪN chứ không phải nội dung: một extractor có thể in
    hàng trăm MB, và nhét chỗ đó vào kết quả năng lực là nhét vào cả ledger (result_hash) lẫn
    ngữ cảnh mô hình. Vượt giới hạn → `violations[]` kèm mã thoát; quá thời gian → E4004 (lỗi
    riêng, không gộp vào E8000 vì cách xử lý khác nhau: một bên nới hạn, một bên xem lại lệnh).
    """
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    out = (root / ".eide" / "cache" / "sandbox") if root and (root / ".eide").is_dir() \
        else (user_cache() / "sandbox")
    sb = Sandbox(out_dir=out, ledger=ctx.extra.get("ledger"))
    kq = sb.run(params["cmd"], limits=params.get("limits"),
                allowed_dirs=params.get("allowed_dirs"), network=bool(params.get("network")))
    return {"exit_code": kq.exit_code, "stdout_ref": kq.stdout_ref,
            "stderr_ref": kq.stderr_ref, "violations": kq.violations}


@capability("env.lock")
def lock(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-05 — CDS-12.3; UC-A03; SEC-25 §5 (tools.lock khi cài); undo restore_config.

    "Trôi" không chỉ là đổi số phiên bản: một công cụ BIẾN MẤT cũng làm bản dựng không lặp lại
    được, nên nó cũng là drift với `now: null`. Đó là lý do phép so đi theo tên công cụ trong
    lock cũ chứ không theo danh sách tìm thấy hôm nay.
    """
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / ".eide").is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])
    f = root / ".eide" / "tools.lock"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    cu_map = {t["tool"]: t for t in cu.get("tools", [])}

    hien = []
    for ten, _bat_buoc in tools.COMMON_TOOLS:
        exe = tools.which(ten)
        if exe is None and ten not in cu_map:
            continue                      # chưa từng khóa và nay cũng không có → không phải trôi
        hien.append({"tool": ten, "version": tools.version_of(exe) if exe else None,
                     "path": str(exe) if exe else None, "hash": None})
    hien_map = {t["tool"]: t for t in hien}

    drift = []
    for ten, truoc in cu_map.items():
        nay = hien_map.get(ten, {"version": None, "path": None})
        if (nay.get("version") or None) != (truoc.get("version") or None):
            drift.append({"tool": ten, "was": truoc.get("version"), "now": nay.get("version"),
                          "path": nay.get("path")})

    khoa = {"generated": datetime.now(UTC).isoformat(), "os": tools.os_name(),
            "arch": platform.machine(), "tools": hien}
    f.write_text(yaml.safe_dump(khoa, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"lock": khoa, "drift": drift}
