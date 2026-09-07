"""CapabilityRouter — điểm gọi duy nhất cho mọi năng lực (SDD-04 §4.2; APD-08 §4.1; API-15 caps.invoke).

Thứ tự: kiểm input (E1000) → grounding của năng lực → PolicyGate.decide theo cổng/lớp rủi ro → ghi ledger
cap.run.start → chạy handler → kiểm output → ledger cap.run.finish (kèm undo_ref) → trả CapabilityRun.
ASK không phải lỗi: trả status "pending" và đưa vào hàng đợi (queue) để người quyết — API-15 E3000.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
import time
import uuid
from dataclasses import dataclass, field, replace
from datetime import UTC, datetime
from typing import Any

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import ASK, PolicyGate
from eide_core.registry import Registry, get_registry
from eide_core.undo import KIND_WINDOW, UndoService


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
        self._cho: dict[str, tuple[str, dict[str, Any], Context, dict[str, Any]]] = {}
        # Hàm hoàn tác theo loại (POL-17 §5). Rỗng lúc này: các loại cần năng lực chưa hiện
        # thực. Đăng ký từ ngoài để `undo.apply` không phải biết về từng nhóm năng lực.
        self.undo_handlers: dict[str, Any] = {}

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
                             risk=reg.spec.risk_class, autonomy=ctx.autonomy, board=ctx.board,
                             tier=reg.spec.tier_hieu_luc, actor=ctx.actor)
        dec = {"decision": d.decision, "rule": d.rule_id, "reason": d.reason, "gate": d.gate}
        self._log("cap.run.start", {"run_id": run_id, "cap": cap_id, "actor": ctx.actor,
                                    "args_hash": _h(params), "decision": dec})
        self._ghi_decision_log(run_id, cap_id, reg, d, ctx, features)
        if d.decision == ASK:
            run = CapabilityRun(run_id, cap_id, "pending", None, dec, 0, undo=reg.spec.undo)
            self.queue.append(run)
            # Giữ tham số và ngữ cảnh để `quyet_dinh()` chạy tiếp được khi người duyệt. Bảng
            # `capability_run` của DDD-14 chỉ lưu `args_hash` (toàn vẹn), không lưu tham số, nên
            # một mục ASK KHÔNG phục hồi được sau khi daemon khởi động lại — xem DEV-049.
            self._cho[run_id] = (cap_id, params, ctx, features)
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
        # `tool.register` nạp nóng một năng lực `user.*` và nó phải vào ĐÚNG registry mà Router
        # đang dùng — `get_registry()` dựng một đối tượng MỚI mỗi lần gọi, nên đăng ký vào đó
        # là đăng ký vào hư không.
        ctx.extra.setdefault("registry", self.registry)
        try:
            result = reg.handler(params, ctx)  # type: ignore[misc]
            self.registry.validate_output(cap_id, result)
        except EideError as e:
            ms = int((time.perf_counter() - t0) * 1000)
            self._log("cap.run.finish", {"run_id": run_id, "status": "failed", "error": e.code, "duration_ms": ms})
            return CapabilityRun(run_id, cap_id, "failed", None, dec, ms, e.to_rpc()["data"] | {"message": str(e)})
        ms = int((time.perf_counter() - t0) * 1000)
        self._log("cap.run.finish", {"run_id": run_id, "status": "done", "result_hash": _h(result),
                                     "duration_ms": ms, "undo_ref": run_id if reg.spec.undo in KIND_WINDOW else None})
        # Việc tác tử vừa TỰ làm phải vào cửa sổ hoàn tác ngay tại đây, không để năng lực tự nhớ.
        # UXD-13 U2 hứa "mỗi việc tự làm có lý do và nút hoàn tác"; nếu việc đăng ký nằm trong
        # từng handler thì lời hứa ấy đúng tới khi ai đó quên một chỗ. Router là điểm gọi duy
        # nhất nên nó là chỗ duy nhất không quên được. POL-17 §5, API-15 §5 undo.register.
        if self.ledger is not None and reg.spec.undo in KIND_WINDOW:
            UndoService(self.ledger, getattr(self.gate, "config", None)).register(
                run_id, reg.spec.undo, cap=cap_id)
        return CapabilityRun(run_id, cap_id, "done", result, dec, ms, undo=reg.spec.undo)

    # ---- người quyết định một mục đang chờ (API-15 §2 `gate.decide`)
    def quyet_dinh(self, run_id: str, quyet: str, by: str = "human",
                   note: str = "") -> CapabilityRun:
        """Người duyệt hoặc từ chối một mục ASK — APD-08 §4.1, UXD-13 U2.

        Ghi câu trả lời vào `decision_log.human_answer` TRƯỚC khi chạy: đó là dữ liệu POLICY-06
        học ("tỷ lệ người APPROVE khi máy ASK", POL-17 §7), và nó phải còn lại kể cả khi lần
        chạy sau đó thất bại — người đã duyệt là một sự thật độc lập với kết quả.

        Duyệt xong thì chạy với `actor="human"`: PolicyGate tầng 5 trả APPROVE cho người gọi
        trực tiếp, nên lời gọi không quay lại hàng đợi một lần nữa. Không đặt cờ ấy thì mục vừa
        duyệt sẽ ASK lại và người bấm duyệt mãi không xong.
        """
        if quyet not in ("approve", "reject"):
            raise EideError("E1000", "gate.decide chỉ nhận approve|reject")
        if by != "human":
            raise EideError("E3000", "Duyệt mục chờ là quyết định của người (APD-08 §1)",
                            rule="GATE-HUMAN", gate="*")
        cho = next((r for r in self.queue if r.run_id == run_id and r.status == "pending"), None)
        if cho is None:
            raise EideError("E2000", f"Không có mục đang chờ với id {run_id}",
                            exists=[r.run_id for r in self.queue], candidates=[], missing=[run_id])
        cap_id, params, ctx, features = self._cho.pop(run_id, (cho.cap, {}, Context(), {}))
        self._cap_nhat_decision_log(ctx, run_id, human_answer=quyet.upper())
        self._log("gate.human", {"gate_id": run_id, "decision": quyet.upper(), "by": by,
                                 "note": note or cho.decision.get("reason", "")})
        self.queue.remove(cho)
        if quyet == "reject":
            self._log("cap.run.finish", {"run_id": run_id, "status": "rejected", "error": "E3001"})
            return CapabilityRun(run_id, cap_id, "rejected", None, cho.decision, 0,
                                 {"code": "E3001", "message": f"người từ chối: {note}" if note
                                  else "người từ chối"})
        ctx_nguoi = replace(ctx, actor="human")
        return self.invoke(cap_id, params, ctx_nguoi, features)

    # ---- người hoàn tác một việc đã tự làm (API-15 §2 `undo.apply`)
    def hoan_tac(self, undo_ref: str, by: str = "human",
                 ctx: Context | None = None) -> dict[str, Any]:
        """Áp dụng hoàn tác — POL-17 §5.

        Ghi `decision_log.undone_at` là nửa còn lại của tín hiệu POLICY-06 học: "tỷ lệ người UNDO
        khi máy APPROVE" (POL-17 §7). Nửa kia là `human_answer` ở `quyet_dinh()`.

        Việc hoàn tác THẬT theo từng loại (git revert, nạp lại known-good, xóa tệp đã tạo) cần
        những năng lực chưa hiện thực. Ở đây trả `applied: false` kèm lý do thay vì im lặng báo
        thành công — một nút "hoàn tác" bấm xong mà không hoàn tác gì là thứ tệ hơn không có nút.
        """
        u = UndoService(self.ledger, getattr(self.gate, "config", None))
        muc = next((m for m in u.list() if m["undo_ref"] == undo_ref), None)
        if muc is None:
            raise EideError("E2000", f"Không có mục hoàn tác còn hạn: {undo_ref}",
                            exists=[m["undo_ref"] for m in u.list()], candidates=[], missing=[undo_ref])
        ham = self.undo_handlers.get(muc["kind"])
        if ham is None:
            ket_qua = {"applied": False, "kind": muc["kind"],
                       "reason": f"chưa có hiện thực hoàn tác cho loại `{muc['kind']}` "
                                 f"(POL-17 §5 giao cho {muc.get('cap') or 'năng lực tương ứng'})"}
        else:
            ket_qua = {"applied": True, "kind": muc["kind"], **(ham(muc) or {})}
        self._log("undo.apply", {"undo_ref": undo_ref, "by": by, "result": ket_qua})
        if ket_qua["applied"]:
            self._cap_nhat_decision_log(ctx or Context(), undo_ref,
                                        undone_at=datetime.now(UTC).isoformat())
        return ket_qua

    def _cap_nhat_decision_log(self, ctx: Context, decision_id: str, **cot: str) -> None:
        """Điền `human_answer` / `undone_at` vào dòng đã ghi lúc quyết định.

        Đây là chỗ bảng khác nhật ký: nhật ký chỉ thêm, còn hai cột này là cập nhật SAU. Không
        có chúng thì POLICY-06 không có gì để học (DEVIATIONS DEV-048).
        """
        if not ctx.project_dir or not cot:
            return
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return
        dat = ", ".join(f"{k}=?" for k in cot)
        try:
            with store.open_store(db) as c:
                c.execute(f"UPDATE decision_log SET {dat} WHERE id=?",  # noqa: S608 — khóa từ mã
                          (*cot.values(), decision_id))
                c.commit()
        except sqlite3.Error:
            pass

    def _ghi_decision_log(self, run_id: str, cap_id: str, reg: Any, d: Any,
                          ctx: Context, features: dict[str, Any]) -> None:
        """Ghi một dòng `decision_log` — DDD-14 §2.

        Nhật ký sự kiện đã có `gate.decision`, nhưng nó CHỈ THÊM: hai cột `human_answer` và
        `undone_at` là những thứ được điền SAU, khi người trả lời một mục ASK hoặc hoàn tác một
        việc đã APPROVE. Một bản ghi chỉ-thêm không mang được cập nhật ấy, nên DDD-14 dựng riêng
        một bảng — và POLICY-06 học ngưỡng đọc đúng hai cột đó ("tỷ lệ người APPROVE khi máy
        ASK", "tỷ lệ người UNDO khi máy APPROVE", POL-17 §7).

        Bảng nằm trong store của dự án, nên không có dự án thì không ghi. Không phải thiếu sót:
        một quyết định ngoài dự án (ví dụ `project.create`) chưa có store nào để thuộc về.
        """
        if not ctx.project_dir:
            return
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return
        try:
            with store.open_store(db) as c:
                c.execute(
                    "INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                    " decision, by, rule, reason, evidence, features, at)"
                    " VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                    (run_id, d.gate, cap_id, reg.spec.risk_class,
                     ctx.autonomy or self.gate.config.get("autonomy", ""), d.decision, ctx.actor,
                     d.rule_id, d.reason, None,
                     json.dumps(features, ensure_ascii=False, default=str),
                     datetime.now(UTC).isoformat()))
                c.commit()
        except sqlite3.Error:
            # Ghi nhật ký quyết định KHÔNG được làm hỏng chính quyết định ấy. Store cũ chưa có
            # bảng (user_version thấp) là trường hợp thật, và bắt người chạy `eide migrate`
            # trước khi được phép làm bất cứ việc gì là một cái giá quá cao cho một dòng thống kê.
            pass

    def _log(self, kind: str, data: dict[str, Any]) -> None:
        if self.ledger:
            self.ledger.append(kind, data)


def _h(obj: Any) -> str:
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, default=str).encode()).hexdigest()[:16]
