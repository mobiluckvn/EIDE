"""UndoService — cửa sổ hoàn tác cho việc tác tử đã tự làm (POL-17 §5, APD-08 §5).

Spec: POL-17 §5 (bảng loại undo × cửa sổ), §6 (máy trạng thái: DONE(undo_deadline) → UNDONE |
EXPIRED); API-15 §5 sự kiện `undo.register` / `undo.apply` / `undo.expire`; CDS-12.5 POLICY-03.

Trạng thái nằm TRONG LEDGER, không trong một bảng riêng. Lý do: UXD U2 hứa với người dùng rằng
mỗi việc tự làm đều có lý do và nút hoàn tác, và lời hứa ấy chỉ đáng tin nếu danh sách hoàn tác
được suy ra từ chính cuốn sổ chống sửa — một bảng riêng có thể lệch khỏi nhật ký mà không ai
biết. Đổi lại là phải quét ledger mỗi lần liệt kê; ở quy mô một dự án thì rẻ.
"""
from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta
from typing import Any

from eide_core.ledger import Ledger

# POL-17 §5 — loại hoàn tác → tên cửa sổ trong `undo_window` của autonomy.yaml.
KIND_WINDOW = {
    "supersede_facts": "facts",
    "git_revert": "merge",
    "reflash_known_good": "flash",
    "delete_created_files": "files",
    "restore_config": "files",
    # [DEV-151] Loại thứ SÁU. Năm loại trên hoàn tác một tệp, một commit, hay cả dự án; không
    # loại nào hoàn tác được MỘT DÒNG trong store — mà câu trả lời của người cho một điểm cần
    # làm rõ đúng là một dòng như thế.
    "restore_answer": "files",
}

_DON_VI = {"m": 1 / 60, "h": 1.0, "d": 24.0}


def doc_cua_so(gia_tri: str) -> timedelta | None:
    """"72h" → 72 giờ. "session" → None: cửa sổ theo PHIÊN, không theo đồng hồ (POL-17 §5).

    Trả None cũng có nghĩa "đừng so với thời gian" — người gọi phải xử lý riêng, và
    `UndoService.list` làm đúng thế bằng cách nhìn mốc `session.open` gần nhất.
    """
    if gia_tri == "session":
        return None
    m = re.fullmatch(r"(\d+(?:\.\d+)?)([mhd])", str(gia_tri).strip())
    if not m:
        raise ValueError(f"Cửa sổ hoàn tác không đọc được: {gia_tri!r} (mong '24h', '72h', 'session')")
    return timedelta(hours=float(m.group(1)) * _DON_VI[m.group(2)])


class UndoService:
    def __init__(self, ledger: Ledger, config: dict[str, Any] | None = None) -> None:
        self.ledger = ledger
        self.windows = (config or {}).get("undo_window") or {
            "facts": "72h", "merge": "24h", "flash": "session", "files": "24h"}

    def register(self, undo_ref: str, kind: str, *, cap: str = "", at: str | None = None) -> dict[str, Any]:
        """Ghi `undo.register` {undo_ref, kind, deadline} — API-15 §5."""
        if kind not in KIND_WINDOW:
            raise ValueError(f"Loại hoàn tác không có trong POL-17 §5: {kind}")
        cua_so = self.windows.get(KIND_WINDOW[kind], "24h")
        t0 = datetime.fromisoformat(at) if at else datetime.now(UTC)
        khoang = doc_cua_so(cua_so)
        deadline = (t0 + khoang).isoformat() if khoang else None
        return self.ledger.append("undo.register", {
            "undo_ref": undo_ref, "kind": kind, "cap": cap, "window": KIND_WINDOW[kind],
            "at": t0.isoformat(), "deadline": deadline})

    def list(self, *, now: datetime | None = None) -> list[dict[str, Any]]:
        """Các mục còn hoàn tác được. Mục quá hạn được GHI `undo.expire` rồi mới loại ra.

        Hết hạn là một sự kiện, không phải một phép lọc thầm lặng: nếu chỉ lọc thì sau này
        không ai trả lời được vì sao một việc từng hoàn tác được nay thì không.
        """
        now = now or datetime.now(UTC)
        muc: dict[str, dict[str, Any]] = {}
        xong: set[str] = set()
        phien_moi_nhat: str | None = None
        for r in self.ledger.records():
            d = r.get("data") or {}
            ref = d.get("undo_ref")
            if r["kind"] == "undo.register" and ref:
                muc[ref] = {**d, "seq": r["seq"], "ts": r["ts"]}
            elif r["kind"] in ("undo.apply", "undo.expire") and ref:
                xong.add(ref)
            elif r["kind"] == "session.open":
                phien_moi_nhat = r["ts"]

        con_lai = []
        for ref, m in muc.items():
            if ref in xong:
                continue
            if m.get("deadline"):
                het = datetime.fromisoformat(m["deadline"]) <= now
            else:
                # cửa sổ "session": hết hạn khi có một phiên MỚI mở sau lúc đăng ký
                het = bool(phien_moi_nhat and phien_moi_nhat > m["ts"])
            if het:
                self.ledger.append("undo.expire", {"undo_ref": ref})
            else:
                # `.get`, KHÔNG `m[k]`: sổ cái là chỉ-thêm, nên bản ghi do một phiên bản CŨ
                # hơn ghi sẽ nằm đó mãi mãi. `cap` thêm vào `undo.register` sau ngày đầu, và
                # một bản ghi thiếu nó làm `list()` ném KeyError — tức **cả danh sách hoàn tác
                # chết vì một dòng cũ**. Đo 15/09/2026 trên dự án AVR: `undo.list` trả E1000
                # "Tham số sai: 'cap'", và vùng "Hoàn tác được" của giao diện rỗng vĩnh viễn
                # trong khi sáu việc vẫn đang trong hạn. Xem lỗi im lặng số 34.
                con_lai.append({k: m.get(k) for k in
                                ("undo_ref", "kind", "cap", "window", "at", "deadline")})
        con_lai.sort(key=lambda x: x["at"] or "")
        return con_lai
