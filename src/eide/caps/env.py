"""Namespace env.* — CDS-12.3; TGT-19 (manifest ISA, toolchain); PLATFORM.md."""
from __future__ import annotations

import platform
import re
import sys
from typing import Any

import yaml

from eide_core import tools
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context


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
