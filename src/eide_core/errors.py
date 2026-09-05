"""Mã lỗi thống nhất E1000–E8002 theo EIDE-API-15 (docs/spec/api/errors.json).

Mọi lỗi ném ra từ năng lực phải là EideError với `code` có trong errors.json;
tests/test_specs_consistency.py kiểm tra điều này.
"""
from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from eide_core.paths import spec_dir


@lru_cache(maxsize=1)
def error_table() -> dict[str, dict[str, str]]:
    data = json.loads((spec_dir() / "api" / "errors.json").read_text(encoding="utf-8"))
    return {e["code"]: e for e in data}


class EideError(Exception):
    """Lỗi có mã. `code` ví dụ "E2001"; `name` tra từ bảng (ALREADY_EXISTS)."""

    def __init__(self, code: str, message: str = "", **data: Any) -> None:
        table = error_table()
        if code not in table:
            raise ValueError(f"Mã lỗi {code} không có trong docs/spec/api/errors.json (API-15)")
        self.code = code
        self.name = table[code]["name"]
        self.meaning = table[code]["meaning"]
        self.data = data
        super().__init__(message or self.meaning)

    def to_rpc(self) -> dict[str, Any]:
        """Dạng JSON-RPC error object (API-15 §2): code số = phần số của Exxxx."""
        return {"code": int(self.code[1:]), "message": str(self), "data": {"eide_code": self.code, "name": self.name, **self.data}}
