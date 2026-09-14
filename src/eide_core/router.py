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
from pathlib import Path
from typing import Any

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger, che_bi_mat
from eide_core.memory import WorkingMemory
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

        # Đặc trưng cho cổng: năng lực tự dựng từ THAM SỐ của chính lời gọi (xem
        # `capability(..., dac_trung=)`), rồi bên gọi chồng thêm nếu nó biết gì hơn.
        #
        # Thứ tự ấy quan trọng: bên gọi thắng vì nó có ngữ cảnh mà năng lực không thấy —
        # `needs_sudo` của `env.install` chẳng hạn, chỉ biết được sau khi dò máy. Nhưng KHÔNG
        # bên gọi nào phải nhớ dựng cái cơ bản: trước 14/09/2026 thì phải, và kết quả là hai
        # bộ dựng đặc trưng (`dac_trung_nguon`, `dac_trung_cai`) viết xong mà không ai gọi —
        # cổng G-SRC 8 quy tắc và G-OPS 7 quy tắc chạy trên đặc trưng rỗng suốt từ đầu.
        if reg.dac_trung is not None:
            try:
                features = {**reg.dac_trung(params), **features}
            except Exception:
                # Bộ dựng hỏng KHÔNG được làm hỏng lời gọi: thiếu đặc trưng thì cổng rơi về
                # quy tắc mặc định (ASK) — an toàn, và đó đúng là hành vi cũ.
                pass
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
            # Giữ tham số để `quyet_dinh()` chạy tiếp được. Trong RAM cho lần gọi ngay, VÀ
            # xuống `run.working` để sống qua lần khởi động lại — MEM-11 §2 định nghĩa M1 đúng
            # là "RAM + run.state (SQLite) ĐỂ TIẾP TỤC SAU TẮT MÁY", và `WorkingMemory` đã có sẵn
            # hai trường `pending_question`/`asked_at` cho chính tình huống này. Xem DEV-049.
            self._cho[run_id] = (cap_id, params, ctx, features)
            self._luu_cho(run_id, cap_id, params, ctx, features, dec)
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
        # `chat.orchestrate` chạy từng nút của chuỗi qua Router — cùng đường đi với mọi lời gọi
        # khác, nên cùng chính sách, cùng nhật ký, cùng hoàn tác. Đưa Router xuống thay vì để nó
        # tự dựng một cái mới: một Router thứ hai sẽ có hàng đợi riêng và ledger riêng, và mục
        # chờ do chuỗi sinh ra sẽ không bao giờ xuất hiện trong hàng đợi người đang nhìn.
        ctx.extra.setdefault("router", self)
        commit_truoc = store.so_commit()
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
        self._niem_lai(ctx, commit_truoc)
        return CapabilityRun(run_id, cap_id, "done", result, dec, ms, undo=reg.spec.undo)

    def _niem_lai(self, ctx: Context, commit_truoc: int) -> None:
        """Niêm lại store sau một năng lực CÓ THỂ GHI — cùng lập luận với `undo.register` trên.

        Niêm (`store.sqlite.seal.json`) tồn tại để `project.open` phát hiện store bị sửa NGOÀI
        EIDE (PROJECT-02 bước 2). Nó chỉ có nghĩa khi mọi ghi hợp lệ đều cập nhật nó — một niêm
        lệch sau mỗi phiên làm việc bình thường là một cảnh báo luôn đỏ, và cảnh báo luôn đỏ thì
        người ta tắt đi.

        Bản đầu để từng năng lực tự gọi `store.write_seal`. `passport.*`, `kg.*`, `search.*`,
        `project.*` nhớ; `req.*`, `arch.*`, `extract.*` quên — và không có gì báo, vì `verify_seal`
        chỉ chạy lúc mở dự án. `scripts/nghiem_thu_sprint2.sh` bước 12 mới lộ ra: chạy chuỗi thật
        bằng CLI xong thì niêm lệch. Đặt ở Router là chỗ duy nhất không quên được.

        Lọc theo **thời điểm sửa tệp**, không theo lớp rủi ro và cũng không theo danh sách năng
        lực. Hai cách kia đều đã thử và đều sai:

        - *Danh sách năng lực*: phải nhớ cập nhật — đúng cái vừa hỏng.
        - *Lớp rủi ro R0*: nghe chắc chắn vì APD-08 §4.1 định nghĩa "lớp R0 chỉ đọc", nhưng đo ra
          thì `req.ground_hw` là R0 mà VẪN ghi (`requirement.feasibility`). Bước 1 của REQ-03 nói
          "so ngưỡng; ghi fact id", và "ghi" ở đó có nghĩa là lưu lại. Nên R0 trong danh mục nói
          về rủi ro với NGƯỜI DÙNG, không phải về việc có chạm store hay không.

        Tín hiệu là **bộ đếm commit** (`store.so_commit()`), so trước và sau handler. Ba cách rẻ
        hơn đều đã thử và đều sai với SQLite chế độ WAL: mtime của tệp chính không đổi khi commit
        (ghi vào `-wal`); mtime của `-wal`/`-shm` lại đổi cả khi chỉ MỞ kết nối để đọc; còn
        `PRAGMA data_version` chỉ phản ánh kết nối khác và không bền qua tiến trình. Đếm ngay tại
        `commit()` thì không có ngoại lệ nào lách được, và lời gọi chỉ đọc không trả giá gì.
        """
        if not ctx.project_dir or store.so_commit() == commit_truoc:
            return                           # không ai commit trong lời gọi này
        try:
            db = store.store_path(Path(ctx.project_dir).expanduser())
            if db.exists():
                store.write_seal(db, self.ledger)
        except (OSError, sqlite3.Error, EideError):
            # Niêm hỏng không được làm hỏng một lời gọi ĐÃ THÀNH CÔNG: kết quả đã có, đã ghi
            # ledger, và người dùng đã thấy nó chạy. Bỏ qua ở đây rồi để `project.open` báo còn
            # trung thực hơn là nuốt mất kết quả.
            pass

    # ---- người quyết định một mục đang chờ (API-15 §2 `gate.decide`)
    def quyet_dinh(self, run_id: str, quyet: str, by: str = "human", note: str = "",
                   ctx_goi_y: Context | None = None) -> CapabilityRun:
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
        goc = self._cho.pop(run_id, None)
        if goc is None:
            # Không có trong RAM ⇒ có thể là mục của một phiên daemon TRƯỚC. Đọc lại từ M1.
            goc = self._doc_cho(run_id, ctx_goi_y)
        if cho is None and goc is None:
            raise EideError("E2000", f"Không có mục đang chờ với id {run_id}",
                            exists=[r.run_id for r in self.queue], candidates=[], missing=[run_id])
        cap_id, params, ctx, features = goc or (cho.cap, {}, Context(), {})
        self._cap_nhat_decision_log(ctx, run_id, human_answer=quyet.upper())
        # `cho` là None khi mục đến từ phiên daemon TRƯỚC: RAM không còn, chỉ store còn.
        ly_do = cho.decision.get("reason", "") if cho is not None else ""
        self._log("gate.human", {"gate_id": run_id, "decision": quyet.upper(), "by": by,
                                 "note": note or ly_do})
        if cho is not None:
            self.queue.remove(cho)
        self._xoa_cho(ctx, run_id, quyet)
        if quyet == "reject":
            self._log("cap.run.finish", {"run_id": run_id, "status": "rejected", "error": "E3001"})
            return CapabilityRun(run_id, cap_id, "rejected", None,
                                 cho.decision if cho is not None else {"decision": "ASK"}, 0,
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
        con_han = u.list()
        muc = next((m for m in con_han if m["undo_ref"] == undo_ref), None)
        if muc is None:
            # HAI trường hợp khác nhau, và gộp chúng làm một là gửi người dùng đi sai hướng.
            #
            # `E7000 UNDO_EXPIRED`: việc ĐÃ xảy ra, đã từng hoàn tác được, và cửa sổ đã đóng —
            # người dùng cần biết để đi tìm cách sửa khác (revert tay, nạp lại bản cũ), không
            # phải để kiểm lại xem mình gõ đúng id chưa.
            # `E2000`: id chưa từng có. Đây mới là lúc bảo họ xem lại danh sách.
            #
            # Trước 12/09/2026 cả hai đều là E2000, và `E7000` khai trong API-15 §3 không chỗ
            # nào ném — cùng họ với ba kiểu sự kiện sổ cái vừa vá (lỗi im lặng 12–14).
            if any(r["kind"] == "undo.expire" and (r["data"] or {}).get("undo_ref") == undo_ref
                   for r in self.ledger.records()):
                raise EideError("E7000", f"Quá cửa sổ hoàn tác cho `{undo_ref}` — việc đã làm "
                                "vẫn còn nguyên, nhưng phải sửa bằng cách khác",
                                undo_ref=undo_ref)
            raise EideError("E2000", f"Không có mục hoàn tác còn hạn: {undo_ref}",
                            exists=[m["undo_ref"] for m in con_han], candidates=[],
                            missing=[undo_ref])
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

    # ---- mục chờ bền qua lần khởi động lại (M1 WorkingMemory, MEM-11 §2 §3)
    def _luu_cho(self, run_id: str, cap_id: str, params: dict[str, Any], ctx: Context,
                 features: dict[str, Any], dec: dict[str, Any]) -> None:
        """Lưu mục chờ vào `run.working`.

        Che bí mật TRƯỚC khi ghi, cùng bộ lọc dùng cho nhật ký (API-15 §7): tham số của một lời
        gọi có thể mang khóa API, và một mục chờ nằm trong store hàng tuần là chỗ tệ nhất để một
        khóa nằm lại. Đây cũng là điểm khác biệt với phương án "thêm cột `args` vào
        capability_run": ở đó không có bước lọc nào, và bảng ấy vốn chỉ giữ băm.
        """
        if not ctx.project_dir:
            return
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return
        wm = WorkingMemory(
            run_id=run_id, state="asked",
            intent={"cap": cap_id, "features": che_bi_mat(features)},
            vars={"params": che_bi_mat(params)},
            pending_question={"decision": dec, "autonomy": ctx.autonomy, "board": ctx.board},
            asked_at=datetime.now(UTC).isoformat())
        try:
            with store.open_store(db) as c:
                wm.save(c)
        except sqlite3.OperationalError:
            pass

    def _doc_cho(self, run_id: str, ctx: Context | None
                 ) -> tuple[str, dict[str, Any], Context, dict[str, Any]] | None:
        if ctx is None or not ctx.project_dir:
            return None
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return None
        try:
            with store.open_store(db) as c:
                wm = WorkingMemory.load(c, run_id)
        except sqlite3.OperationalError:
            return None
        if wm is None or wm.state != "asked":
            return None
        pq = wm.pending_question or {}
        lai = replace(ctx, autonomy=pq.get("autonomy") or ctx.autonomy,
                      board=pq.get("board") or ctx.board)
        return (wm.intent.get("cap", ""), wm.vars.get("params", {}), lai,
                wm.intent.get("features", {}))

    def _xoa_cho(self, ctx: Context, run_id: str, quyet: str) -> None:
        """MEM-11 §2 M1 cột "Quên": xóa khi Run kết thúc; bằng chứng ở lại ledger (M3)."""
        if not ctx.project_dir:
            return
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return
        try:
            with store.open_store(db) as c:
                if (wm := WorkingMemory.load(c, run_id)) is not None:
                    wm.ket_thuc(c, "done" if quyet == "approve" else "rejected")
        except sqlite3.OperationalError:
            pass

    def cho_con_lai(self, ctx: Context) -> list[dict[str, Any]]:
        """Mục chờ của dự án, gồm cả mục từ phiên daemon TRƯỚC — UXD-13 U2.

        Hàng đợi phải bền: người thấy một việc đang chờ hôm nay, tắt máy, mở lại thì nó vẫn phải
        ở đó. Đọc từ store chứ không từ `self.queue`, vì `self.queue` chỉ biết phiên hiện tại.
        """
        if not ctx.project_dir:
            return [{"run_id": r.run_id, "cap": r.cap, "decision": r.decision} for r in self.queue]
        db = store.store_path(ctx.project_dir)
        if not db.exists():
            return []
        with store.open_store(db) as c:
            rows = c.execute("SELECT id, working FROM run WHERE state='asked' ORDER BY id").fetchall()
        ra = []
        for rid, w in rows:
            if not w:
                continue
            d = json.loads(w)
            ra.append({"run_id": rid, "cap": (d.get("intent") or {}).get("cap", ""),
                       "decision": (d.get("pending_question") or {}).get("decision", {}),
                       "asked_at": d.get("asked_at")})
        return ra

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
        except sqlite3.OperationalError:
            pass

    def _ghi_decision_log(self, run_id: str, cap_id: str, reg: Any, d: Any,
                          ctx: Context, features: dict[str, Any]) -> None:
        """Ghi một quyết định cổng vào CẢ HAI nơi — nhật ký `gate.decision` và bảng
        `decision_log` (API-15 §5; DDD-14 §2).

        **Hai nơi, và cả hai đều cần.** Nhật ký CHỈ THÊM và là chuỗi băm nối tiếp, nên nó chứng
        minh được rằng không quyết định nào bị xoá. Bảng thì sửa được, và phải sửa được: hai cột
        `human_answer` và `undone_at` được điền SAU — khi người trả lời một mục ASK hoặc hoàn tác
        một việc đã APPROVE — và POLICY-06 học ngưỡng đọc đúng hai cột đó (POL-17 §7).

        **Vì sao phần nhật ký là bắt buộc chứ không phải trang trí.** `store.BANG_VAN_HANH` loại
        `decision_log` khỏi niêm phong nội dung, và lý do ghi ngay trong `store.py` là *"mọi
        quyết định cũng vào nhật ký `gate.decision`, và nhật ký là chuỗi băm nối tiếp — mạnh hơn
        một niêm phong đơn"*. Tới 12/09/2026, câu ấy KHÔNG ĐÚNG: không chỗ nào phát sự kiện ấy.
        Nghĩa là `decision_log` vừa nằm ngoài niêm, vừa không có trong nhật ký — **sửa bảng để
        giấu một quyết định thì không cơ chế nào phát hiện**, đúng thứ mà lý do loại trừ kia hứa
        là phát hiện được. Hai chú thích trong mã (ở đây và ở `store.py`) cùng khẳng định một cơ
        chế chưa ai viết: lỗi im lặng số 12.

        Phát nhật ký TRƯỚC khi ghi bảng, và không nuốt lỗi ở bước ấy: nếu chuỗi băm không nhận
        được quyết định thì thà hỏng to còn hơn chạy tiếp với một sổ cái thiếu dòng.

        Bảng nằm trong store của dự án, nên không có dự án thì không ghi BẢNG. Nhật ký thì vẫn
        ghi — nó không thuộc về dự án nào, và một quyết định ngoài dự án (`project.create` chẳng
        hạn) vẫn là một quyết định cần truy được.
        """
        if self.ledger is not None:
            self._log("gate.decision", {
                "run_id": run_id, "gate": d.gate, "action_cap": cap_id,
                "risk": reg.spec.risk_class, "decision": d.decision, "by": ctx.actor,
                "rule": d.rule_id, "reason": d.reason,
                "autonomy_level": ctx.autonomy or self.gate.config.get("autonomy", ""),
            })
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
        except sqlite3.OperationalError:
            # Ghi nhật ký quyết định KHÔNG được làm hỏng chính quyết định ấy. Store cũ chưa có
            # bảng (user_version thấp) là trường hợp thật, và bắt người chạy `eide migrate`
            # trước khi được phép làm bất cứ việc gì là một cái giá quá cao cho một dòng thống kê.
            #
            # CHỈ `OperationalError` (thiếu bảng/cột), không phải cả `sqlite3.Error`: nuốt rộng
            # thì một lỗi lập trình — sai tên cột, vi phạm khóa ngoại — trông y hệt "chưa migrate"
            # và im lặng trôi qua. Đã xảy ra thật ở `chat.orchestrate`: `intent_id` nhận tên ý
            # định thay vì khóa ngoại, cả câu chèn hỏng, và không dòng nào được ghi trong nhiều
            # lần chạy mà không ai thấy.
            pass

    def _log(self, kind: str, data: dict[str, Any]) -> None:
        if self.ledger:
            self.ledger.append(kind, data)


def _h(obj: Any) -> str:
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, default=str).encode()).hexdigest()[:16]
