"""Namespace policy.* — CDS-12.5; APD-08 §2, §5; POL-17."""
from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from eide_core.errors import EideError
from eide_core.policy import LEVELS
from eide_core.registry import capability
from eide_core.router import Context

_STATE: dict[str, Any] = {"stopped": False}


@capability("policy.emergency_stop")
def emergency_stop(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-05 — CDS-12.5; APD-08 §5: session.stopped=true, về A0, hủy job EXECUTING lớp ≥ R3 (< 1 s)."""
    _STATE["stopped"] = True
    gate = ctx.extra.get("gate")
    if gate is not None:
        gate.stop()
    cancelled = list(ctx.extra.get("cancel_running", lambda: [])())
    return {"stopped": True, "cancelled": cancelled}


@capability("policy.set_autonomy")
def set_autonomy(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: POLICY-07 — CDS-12.5; APD-08 §2: nới lỏng là R4 → ASK trừ by=human; siết → tức thì; ghi autonomy.yaml; undo restore_config."""
    level, by = params["level"], params["by"]
    if level not in LEVELS:
        raise EideError("E1000", f"Mức không hợp lệ: {level}")
    if not ctx.project_dir:
        raise EideError("E2000", "Chưa mở dự án")
    f = Path(ctx.project_dir) / ".eide" / "autonomy.yaml"
    cfg = yaml.safe_load(f.read_text(encoding="utf-8")) if f.exists() else {"autonomy": "A3"}
    current = cfg.get("autonomy", "A3")
    if LEVELS.index(level) > LEVELS.index(current) and by != "human":
        raise EideError("E3000", f"Nới lỏng {current}→{level} cần người xác nhận", gate="*")
    if params.get("board"):
        cfg.setdefault("boards", {}).setdefault(params["board"], {})["autonomy"] = level
    else:
        cfg["autonomy"] = level
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"effective": level}
