"""JSON-RPC 2.0 daemon — API-15 §1 (docs/spec/api/openrpc.json). Sprint 1: stdio, tập con phương thức.

Phương thức đã có: plane.hello, caps.list, caps.describe, caps.invoke, queue.list, autonomy.get, autonomy.set, stop,
project.list. Tên/tham số/kết quả bám openrpc.json; test_specs_consistency kiểm tra mọi tên đăng ký đều có trong spec.
"""
from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import asdict
from pathlib import Path
from typing import Any, TextIO

from eide import __version__
from eide_core.errors import EideError, error_table
from eide_core.ledger import Ledger
from eide_core.paths import user_log
from eide_core.policy import PolicyGate
from eide_core.registry import get_registry
from eide_core.router import Context, Router

API_VERSION = "1.2"


class Daemon:
    def __init__(self, project: Path | None = None) -> None:
        self.gate = PolicyGate()
        self.ledger = Ledger((project / ".eide" / "store" / "ledger.jsonl") if project else user_log() / "ledger.jsonl")
        self.router = Router(gate=self.gate, ledger=self.ledger)
        self.ctx = Context(project_dir=project, extra={"gate": self.gate})
        self.methods: dict[str, Callable[[dict[str, Any]], Any]] = {
            "plane.hello": self.hello, "caps.list": self.caps_list, "caps.describe": self.caps_describe,
            "caps.invoke": self.caps_invoke, "queue.list": self.queue_list, "autonomy.get": self.autonomy_get,
            "autonomy.set": self.autonomy_set, "stop": self.stop, "project.list": self.project_list,
        }

    # ---- phương thức
    def hello(self, p: dict[str, Any]) -> dict[str, Any]:
        client = p.get("api_version", API_VERSION)
        if str(client).split(".")[0] != API_VERSION.split(".")[0]:
            raise EideError("E1002", f"Plugin API {client} không tương thích daemon {API_VERSION}")
        return {"daemon": __version__, "api_version": API_VERSION, "caps": len(get_registry().list()),
                "autonomy": self.gate.config.get("autonomy")}

    def caps_list(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"caps": [{"id": c.spec.id, "code": c.spec.code, "ns": c.spec.ns, "risk": c.spec.risk_class,
                          "tier": c.spec.tier, "implemented": c.implemented} for c in get_registry().list(p.get("ns"))]}

    def caps_describe(self, p: dict[str, Any]) -> dict[str, Any]:
        return get_registry().describe(p["id"])

    def caps_invoke(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke(p["id"], p.get("params", {}), self.ctx, p.get("features"))
        return asdict(run)

    def queue_list(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"items": [asdict(r) for r in self.router.queue]}

    def autonomy_get(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"autonomy": self.ctx.autonomy or self.gate.config.get("autonomy"), "stopped": self.gate.stopped}

    def autonomy_set(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("policy.set_autonomy", {"level": p["level"], "by": p.get("by", "human")}, self.ctx)
        return asdict(run)

    def stop(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("policy.emergency_stop", {}, self.ctx)
        return asdict(run)

    def project_list(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("project.list", p, self.ctx)
        return run.result or {"projects": []}

    # ---- khung JSON-RPC
    def handle(self, msg: dict[str, Any]) -> dict[str, Any]:
        rid = msg.get("id")
        try:
            name = msg["method"]
            if name not in self.methods:
                return _err(rid, -32601, f"Phương thức không có: {name}")
            return {"jsonrpc": "2.0", "id": rid, "result": self.methods[name](msg.get("params") or {})}
        except EideError as e:
            return {"jsonrpc": "2.0", "id": rid, "error": e.to_rpc()}
        except (KeyError, TypeError) as e:
            # Tham số thiếu/sai kiểu là E1000 INVALID_ARGS của API-15 §3, không phải một mã
            # JSON-RPC trần. Client (EIDEKit) tra `eide_code` để hiện CÁCH XỬ LÝ mà tài liệu
            # khuyến nghị; thiếu nó thì phía giao diện chỉ có một con số âm để đưa cho người dùng.
            return _err(rid, -32602, f"Tham số sai: {e}", eide_code="E1000")


def _err(rid: Any, code: int, message: str, eide_code: str | None = None) -> dict[str, Any]:
    err: dict[str, Any] = {"code": code, "message": message}
    if eide_code:
        err["data"] = {"eide_code": eide_code, "name": error_table()[eide_code]["name"]}
    return {"jsonrpc": "2.0", "id": rid, "error": err}


def serve_stdio(inp: TextIO, out: TextIO, project: Path | None = None) -> None:
    d = Daemon(project)
    for line in inp:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            resp = _err(None, -32700, "JSON không hợp lệ")
        else:
            resp = d.handle(msg)
        out.write(json.dumps(resp, ensure_ascii=False) + "\n")
        out.flush()
