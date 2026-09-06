"""CapabilityRouter — điểm gọi duy nhất cho mọi năng lực (SDD-04 §4.2; APD-08 §4.1; API-15 caps.invoke).

Thứ tự: kiểm input (E1000) → grounding của năng lực → PolicyGate.decide theo cổng/lớp rủi ro → ghi ledger
cap.run.start → chạy handler → kiểm output → ledger cap.run.finish (kèm undo_ref) → trả CapabilityRun.
ASK không phải lỗi: trả status "pending" và đưa vào hàng đợi (queue) để người quyết — API-15 E3000.
"""
from __future__ import annotations

import hashlib
import json
import time
import uuid
from dataclasses import dataclass, field
from typing import Any

from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import ASK, PolicyGate
from eide_core.registry import Registry, get_registry


@dataclass
class Context:
    """Ngữ cảnh chạy (SDD-04 §4.2 RunContext): dự án, mức tự chủ, board, người gọi."""

    project_dir: Any = None
    autonomy: str | None = None
    board: str | None = None
    actor: str = "agent"
    session_id: str = "local"
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass
class CapabilityRun:
    run_id: str
    cap: str
    status: str            # done | pending | rejected | failed
    result: dict[str, Any] | None
    decision: dict[str, Any]
    duration_ms: int
    error: dict[str, Any] | None = None
    undo: str = "none"


class Router:
    def __init__(self, registry: Registry | None = None, gate: PolicyGate | None = None, ledger: Ledger | None = None) -> None:
        self.registry = registry or get_registry()
        self.gate = gate or PolicyGate()
        self.ledger = ledger
        self.queue: list[CapabilityRun] = []

    def invoke(self, cap_id: str, params: dict[str, Any] | None = None, ctx: Context | None = None,
               features: dict[str, Any] | None = None) -> CapabilityRun:
        params, ctx, features = params or {}, ctx or Context(), features or {}
        reg = self.registry.get(cap_id)
        if not reg.implemented:
            raise EideError("E1001", f"Năng lực {cap_id} có trong spec nhưng chưa hiện thực (xem docs/SPRINT-01.md)")
        self.registry.validate_input(cap_id, params)
        run_id = uuid.uuid4().hex[:12]
        t0 = time.perf_counter()
        d = self.gate.decide(reg.spec.gate, {"cap": {"id": cap_id, "risk": reg.spec.risk_class}, **features},
                             risk=reg.spec.risk_class, autonomy=ctx.autonomy, board=ctx.board, tier=reg.spec.tier, actor=ctx.actor)
        dec = {"decision": d.decision, "rule": d.rule_id, "reason": d.reason, "gate": d.gate}
        self._log("cap.run.start", {"run_id": run_id, "cap": cap_id, "actor": ctx.actor,
                                    "args_hash": _h(params), "decision": dec})
        if d.decision == ASK:
            run = CapabilityRun(run_id, cap_id, "pending", None, dec, 0, undo=reg.spec.undo)
            self.queue.append(run)
            self._log("cap.run.finish", {"run_id": run_id, "status": "pending", "error": "E3000"})
            return run
        if d.decision != "APPROVE":
            self._log("cap.run.finish", {"run_id": run_id, "status": "rejected", "error": "E3001"})
            return CapabilityRun(run_id, cap_id, "rejected", None, dec, 0, {"code": "E3001", "message": d.reason})
        # Nhiều năng lực phải tự ghi sự kiện nghiệp vụ của mình vào ledger (API-15 §5:
        # session.open, store.write, acq.state, tool.report…). Router là điểm gọi duy nhất và
        # đã giữ ledger, nên nó là chỗ đúng để đưa xuống — thay vì mỗi handler tự mở một
        # ledger thứ hai và làm gãy chuỗi hash.
        if self.ledger is not None:
            ctx.extra.setdefault("ledger", self.ledger)
        try:
            result = reg.handler(params, ctx)  # type: ignore[misc]
            self.registry.validate_output(cap_id, result)
        except EideError as e:
            ms = int((time.perf_counter() - t0) * 1000)
            self._log("cap.run.finish", {"run_id": run_id, "status": "failed", "error": e.code, "duration_ms": ms})
            return CapabilityRun(run_id, cap_id, "failed", None, dec, ms, e.to_rpc()["data"] | {"message": str(e)})
        ms = int((time.perf_counter() - t0) * 1000)
        self._log("cap.run.finish", {"run_id": run_id, "status": "done", "result_hash": _h(result), "duration_ms": ms})
        return CapabilityRun(run_id, cap_id, "done", result, dec, ms, undo=reg.spec.undo)

    def _log(self, kind: str, data: dict[str, Any]) -> None:
        if self.ledger:
            self.ledger.append(kind, data)


def _h(obj: Any) -> str:
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, default=str).encode()).hexdigest()[:16]
