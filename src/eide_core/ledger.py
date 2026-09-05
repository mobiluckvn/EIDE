"""Ledger — nhật ký sự kiện append-only có chuỗi hash (SEC-25 §3, API-15 §5 ledger_events.json, DDD-14 decision_log).

Mỗi bản ghi: {seq, ts, kind, actor, data, prev_hash, hash}; hash = sha256(prev_hash + json(bản ghi không có hash)).
Kiểu sự kiện hợp lệ lấy từ docs/spec/api/ledger_events.json; kiểu lạ bị từ chối (E6001).
"""
from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.paths import spec_dir

GENESIS = "0" * 64


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
               "data": data, "prev_hash": self._last_hash}
        rec["hash"] = _hash(rec)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True) + "\n")
        self._last_hash = rec["hash"]
        return rec

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
