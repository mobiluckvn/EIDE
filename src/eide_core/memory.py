"""Bộ nhớ tác tử M1 (working) và M2 (session) — WI-007.

Spec: MEM-11 §2 (sáu loại, ai ghi, quên khi nào), §3 (schema WorkingMemory và SessionMemory),
§5 (PROGRESS/FEATURES và resume); DDD-14 bảng `run` (M1) và `session` (M2, session.sqlite).

Hai loại này là bộ nhớ VẬN HÀNH, không phải tri thức. Bất biến (i) của MEM-11 §2 nói thẳng:
M1–M3 và M6 không bao giờ chứa fact phần cứng mới — một giá trị thanh ghi xuất hiện trong chat
chỉ thành tri thức khi đi qua cổng E2/E5 của KAD. Nên ở đây không có chỗ nào ghi vào bảng
`fact`, và đó là cố ý.

Nơi lưu khác nhau và điều đó có nghĩa: M1 ở `run.working` trong store.sqlite (đi cùng dự án, để
tiếp tục được sau khi tắt máy); M2 ở `session.sqlite` riêng, không commit — lịch sử chat và
quyền theo phiên không thuộc về kho mã của người dùng.
"""
from __future__ import annotations

import json
import sqlite3
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core import store
from eide_core.ledger import Ledger

SCRATCH_MAX = 20      # MEM-11 §3: "≤ 20 dòng"
TURNS_GIU = 5         # số lượt gần nhất giữ nguyên văn; cũ hơn bị gộp (§3 "≥ 3 lượt cũ")
TURNS_GOP = 3


def _now() -> str:
    return datetime.now(UTC).isoformat()


# ---------------------------------------------------------------- M1

@dataclass
class WorkingMemory:
    """MEM-11 §3 — trạng thái của MỘT Run đang chạy."""

    run_id: str
    intent: dict[str, Any] = field(default_factory=dict)
    grounded: dict[str, Any] = field(default_factory=dict)
    defaults_applied: list[dict[str, Any]] = field(default_factory=list)
    chain: list[dict[str, Any]] = field(default_factory=list)
    cursor: dict[str, str] = field(default_factory=dict)      # node_id → pending|running|done|asked|skipped|failed
    vars: dict[str, Any] = field(default_factory=dict)        # kết quả trung gian có tên
    pending_question: dict[str, Any] | None = None
    asked_at: str | None = None
    scratch: list[str] = field(default_factory=list)          # ghi chú của tác tử cho chính nó
    state: str = "running"

    def ghi_chu(self, dong: str) -> None:
        """Thêm một dòng scratch, giữ 20 dòng MỚI nhất.

        Cắt ở đây chứ không lúc lưu: scratch là ghi chú ngắn cho lượt sau, không phải nhật ký —
        nhật ký là ledger (M3) và nó mới là thứ có bằng chứng kiểm được (bất biến ii, §2).
        """
        self.scratch.append(dong)
        del self.scratch[:-SCRATCH_MAX]

    def save(self, conn: sqlite3.Connection) -> None:
        d = {k: v for k, v in self.__dict__.items() if k != "state"}
        conn.execute(
            "INSERT INTO run (id, graph, state, working) VALUES (?,?,?,?)"
            " ON CONFLICT(id) DO UPDATE SET state=excluded.state, working=excluded.working,"
            " graph=excluded.graph",
            (self.run_id, json.dumps(self.chain, ensure_ascii=False), self.state,
             json.dumps(d, ensure_ascii=False)))
        conn.commit()

    @classmethod
    def load(cls, conn: sqlite3.Connection, run_id: str) -> WorkingMemory | None:
        row = conn.execute("SELECT state, working FROM run WHERE id=?", (run_id,)).fetchone()
        if not row or not row[1]:
            return None
        return cls(state=row[0], **json.loads(row[1]))

    def ket_thuc(self, conn: sqlite3.Connection, state: str = "done") -> None:
        """MEM-11 §2 M1 cột "Quên": xóa khi Run kết thúc; bằng chứng ở lại M3 (ledger)."""
        conn.execute("UPDATE run SET state=?, working=NULL, finished_at=? WHERE id=?",
                     (state, _now(), self.run_id))
        conn.commit()
        self.state = state


# ---------------------------------------------------------------- M2

@dataclass
class SessionMemory:
    """MEM-11 §3 — một phiên làm việc (mở → đóng dự án/daemon)."""

    session_id: str
    project: str
    opened_at: str
    autonomy_effective: str | None = None
    stopped: bool = False
    turns: list[dict[str, Any]] = field(default_factory=list)
    undo_items: list[dict[str, Any]] = field(default_factory=list)
    closed_at: str | None = None
    summary: str | None = None
    _root: Path | None = field(default=None, repr=False)

    # ---- vòng đời
    @classmethod
    def mo(cls, project_dir: Path | str, *, project: str, autonomy: str | None = None,
           ledger: Ledger | None = None) -> SessionMemory:
        root = Path(project_dir)
        sm = cls(session_id="s_" + uuid.uuid4().hex[:12], project=project, opened_at=_now(),
                 autonomy_effective=autonomy, _root=root)
        sm._ghi()
        if ledger is not None:
            ledger.append("session.open", {"session_id": sm.session_id, "project": project})
        return sm

    @classmethod
    def doc(cls, project_dir: Path | str, session_id: str) -> SessionMemory | None:
        root = Path(project_dir)
        with store.open_session_db(store.session_path(root)) as c:
            row = c.execute("SELECT id, project, opened_at, closed_at, autonomy_effective,"
                            " stopped, turns, undo_items, summary FROM session WHERE id=?",
                            (session_id,)).fetchone()
        return cls._tu_dong(row, root) if row else None

    @classmethod
    def gan_nhat(cls, project_dir: Path | str) -> SessionMemory | None:
        """Phiên CHƯA đóng, mới nhất. Dùng cho resume (§5)."""
        root = Path(project_dir)
        if not store.session_path(root).exists():
            return None
        with store.open_session_db(store.session_path(root)) as c:
            row = c.execute("SELECT id, project, opened_at, closed_at, autonomy_effective,"
                            " stopped, turns, undo_items, summary FROM session"
                            " WHERE closed_at IS NULL ORDER BY opened_at DESC LIMIT 1").fetchone()
        return cls._tu_dong(row, root) if row else None

    def dong(self, *, summary: str | None = None, ledger: Ledger | None = None) -> None:
        self.closed_at = _now()
        self.summary = summary
        self._ghi()
        if ledger is not None:
            ledger.append("session.summary", {"session_id": self.session_id, "summary": summary or ""})

    # ---- lượt chat
    def them_luot(self, by: str, text: str, run_id: str | None = None) -> None:
        """MEM-11 §3: giữ 5 lượt gần nhất nguyên văn; 3 lượt cũ hơn gộp thành TurnSummary.

        Gộp chứ không xóa: lượt cũ vẫn phải đếm được, vì bản tóm tắt phiên (§5) nói "lần trước
        đã…" và một lịch sử bị cắt cụt sẽ nói sai.
        """
        self.turns.append({"by": by, "text": text, "at": _now(), "run_id": run_id})
        nguyen_van = [t for t in self.turns if t["by"] != "summary"]
        if len(nguyen_van) > TURNS_GIU + TURNS_GOP - 1:
            cu = nguyen_van[:TURNS_GOP]
            gop = {"by": "summary", "n": len(cu), "at": cu[-1]["at"],
                   "text": " · ".join(t["text"][:40] for t in cu)}
            con = [t for t in self.turns if t not in cu]
            truoc = [t for t in con if t["by"] == "summary"]
            self.turns = truoc + [gop] + [t for t in con if t["by"] != "summary"]
        self._ghi()

    # ---- nội bộ
    def _ghi(self) -> None:
        if self._root is None:
            return
        with store.open_session_db(store.session_path(self._root)) as c:
            c.execute(
                "INSERT INTO session (id, project, opened_at, closed_at, autonomy_effective,"
                " stopped, turns, undo_items, summary) VALUES (?,?,?,?,?,?,?,?,?)"
                " ON CONFLICT(id) DO UPDATE SET closed_at=excluded.closed_at,"
                " autonomy_effective=excluded.autonomy_effective, stopped=excluded.stopped,"
                " turns=excluded.turns, undo_items=excluded.undo_items, summary=excluded.summary",
                (self.session_id, self.project, self.opened_at, self.closed_at,
                 self.autonomy_effective, int(self.stopped),
                 json.dumps(self.turns, ensure_ascii=False),
                 json.dumps(self.undo_items, ensure_ascii=False), self.summary))
            c.commit()

    @classmethod
    def _tu_dong(cls, row: tuple, root: Path) -> SessionMemory:
        return cls(session_id=row[0], project=row[1], opened_at=row[2], closed_at=row[3],
                   autonomy_effective=row[4], stopped=bool(row[5]),
                   turns=json.loads(row[6]) if row[6] else [],
                   undo_items=json.loads(row[7]) if row[7] else [],
                   summary=row[8], _root=root)
