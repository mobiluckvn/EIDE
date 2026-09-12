"""Ledger — nhật ký sự kiện append-only có chuỗi hash (SEC-25 §3, API-15 §5 ledger_events.json, DDD-14 decision_log).

Mỗi bản ghi: {seq, ts, kind, actor, data, prev_hash, hash}; hash = sha256(prev_hash + json(bản ghi không có hash)).
Kiểu sự kiện hợp lệ lấy từ docs/spec/api/ledger_events.json; kiểu lạ bị từ chối (E6001).
"""
from __future__ import annotations

import hashlib
import json
import re
from collections.abc import Callable
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.paths import spec_dir

GENESIS = "0" * 64

# API-15 §7: "bộ lọc che chuỗi giống khóa API (regex `sk-|AIza|Bearer `) trước khi ghi".
# Che ở TẦNG LEDGER chứ không ở từng chỗ gọi: ledger là append-only và chống sửa, nên một khóa
# lọt vào đây thì không gỡ ra được nữa mà không phá chuỗi hash — và vẫn phải đổi khóa. Chỗ duy
# nhất chặn được là ngay trước khi ghi.
RE_BI_MAT = re.compile(r"(sk-|AIza|Bearer )[A-Za-z0-9\-_\.]{8,}")


def che_bi_mat(x: Any) -> Any:
    """Thay chuỗi giống khóa bằng `<đã che>`, giữ 4 ký tự đầu để còn truy được là khóa nào."""
    if isinstance(x, str):
        return RE_BI_MAT.sub(lambda m: m.group(0)[:8] + "…<đã che>", x)
    if isinstance(x, dict):
        return {k: che_bi_mat(v) for k, v in x.items()}
    if isinstance(x, list):
        return [che_bi_mat(v) for v in x]
    return x


@lru_cache(maxsize=1)
def event_kinds() -> set[str]:
    kinds: set[str] = set()
    for e in json.loads((spec_dir() / "api" / "ledger_events.json").read_text(encoding="utf-8")):
        for k in e["kind"].split("/"):
            kinds.add(k.strip())
    return kinds


class Ledger:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._last_hash = GENESIS
        self._seq = 0
        # Người quan sát — gọi SAU khi bản ghi đã xuống đĩa và chuỗi băm đã nối.
        #
        # Đây là chỗ duy nhất trong hệ thống thấy được MỌI việc đã xảy ra, nên nó là chỗ đúng để
        # daemon phái sinh sự kiện `event.*` (API-15 §1) cho panel. Cách còn lại — rắc lời gọi
        # "phát sự kiện" vào từng năng lực — thì mỗi năng lực mới là một chỗ có thể quên, và
        # panel sẽ im lặng bỏ sót đúng việc vừa thêm.
        self._quan_sat: list[Callable[[dict[str, Any]], None]] = []
        if self.path.exists():
            for line in self.path.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    rec = json.loads(line)
                    self._last_hash, self._seq = rec["hash"], rec["seq"]

    def append(self, kind: str, data: dict[str, Any], actor: str = "agent") -> dict[str, Any]:
        if kind not in event_kinds():
            raise EideError("E6001", f"Kiểu sự kiện ledger không có trong API-15: {kind}")
        self._seq += 1
        rec = {"seq": self._seq, "ts": datetime.now(UTC).isoformat(), "kind": kind, "actor": actor,
               "data": che_bi_mat(data), "prev_hash": self._last_hash}
        rec["hash"] = _hash(rec)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True) + "\n")
        self._last_hash = rec["hash"]
        # Người quan sát KHÔNG được làm hỏng việc ghi sổ. Một panel đã đóng ống dẫn, một
        # `BrokenPipeError` từ stdout — không lý do nào trong số đó đáng để mất một dòng sổ cái.
        # Sổ cái là bằng chứng; thông báo cho giao diện thì không.
        for f in self._quan_sat:
            try:
                f(rec)
            except Exception:  # noqa: BLE001 — xem giải thích ngay trên
                pass
        return rec

    def theo_doi(self, f: Callable[[dict[str, Any]], None]) -> None:
        """Đăng ký một người quan sát. Gọi sau khi bản ghi đã an toàn trên đĩa."""
        self._quan_sat.append(f)

    def verify(self) -> tuple[bool, int]:
        """Kiểm chuỗi hash; trả (ok, seq lỗi đầu tiên hoặc 0)."""
        prev = GENESIS
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rec = json.loads(line)
            h = rec.pop("hash")
            if rec["prev_hash"] != prev or _hash(rec) != h:
                return False, rec["seq"]
            prev = h
        return True, 0

    def records(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        return [json.loads(x) for x in self.path.read_text(encoding="utf-8").splitlines() if x.strip()]


def _hash(rec: dict[str, Any]) -> str:
    body = json.dumps({k: v for k, v in rec.items() if k != "hash"}, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256((rec["prev_hash"] + body).encode("utf-8")).hexdigest()
