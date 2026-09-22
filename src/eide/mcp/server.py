"""MCP server — API-15 §3. WI-011.

    Tool MCP được sinh từ registry lúc khởi động: ba tool chung `caps_list`, `caps_describe`,
    `caps_invoke` + `chat_command` + tối đa 16 tool "nhanh" (một tool = một năng lực hay dùng,
    schema chính là input_schema của năng lực) để tổng ≤ 20 tool/phiên (ACI).

`api/mcp_tools.json` mang phần CHỌN LỰA (tool nào là "hay dùng") vì đó là quyết định biên tập
thuộc về tài liệu; `inputSchema` gắn vào lúc khởi động từ registry. Hai nửa, một nguồn mỗi nửa,
không có bảng nào chép tay — nếu sinh cả tệp ở đây thì có hai bộ sinh cho cùng một tệp và chúng
sẽ trôi khỏi nhau (bài học DEV-018).

## Vì sao ≤ 20 tool

Con số ấy không phải giới hạn kỹ thuật của MCP mà là giới hạn về sự chú ý của mô hình gọi tool:
đưa 238 năng lực thành 238 tool sẽ làm phần mô tả tool chiếm hết ngữ cảnh và mô hình chọn kém đi.
Ba tool chung (`caps_list`/`caps_describe`/`caps_invoke`) giữ cho toàn bộ 238 năng lực vẫn gọi
được — chỉ là qua hai bước thay vì một.

## Chính sách vẫn ở giữa

Mọi lời gọi đi qua `Router.invoke`, tức qua PolicyGate. Một tool MCP KHÔNG phải đường tắt: nếu
chính sách trả ASK thì kết quả là `{status: "pending", gate_id}` (§3) chứ không phải một ngoại lệ
— mô hình bên kia cần đọc được rằng việc đang chờ người, không phải đã hỏng.
"""
from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, TextIO

from eide import __version__, gate_handlers, undo_handlers
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir, user_log
from eide_core.policy import PolicyGate
from eide_core.registry import get_registry
from eide_core.router import Context, Router

# MCP nói JSON-RPC 2.0 nhưng KHÔNG dùng khung `Content-Length` như LSP: mỗi tin nhắn là một
# dòng JSON. Daemon của EIDE (API-15 §2) thì dùng khung ấy — hai giao thức khác nhau trên hai
# socket khác nhau, nên không dùng chung `serve_stdio` của `daemon/rpc.py`.
GIAO_THUC = "2024-11-05"
TRAN_TOOL = 20                      # §3 "tổng ≤ 20 tool/phiên (ACI)"


def _khung(cap_id: str) -> dict[str, Any]:
    reg = get_registry().get(cap_id)
    return {"inputSchema": reg.spec.input_schema, "capability": cap_id,
            "risk": reg.spec.risk_class, "tier": reg.spec.tier_hieu_luc,
            "implemented": reg.implemented}


def bo_qua() -> list[str]:
    """Tool trong `mcp_tools.json` bị bỏ vì năng lực chưa hiện thực — `eide doctor` in ra."""
    reg = get_registry()
    chon = json.loads((spec_dir() / "api" / "mcp_tools.json").read_text(encoding="utf-8"))
    return sorted(t["name"] for t in chon
                  if (c := t.get("capability")) and (c not in reg or not reg.get(c).implemented))


def dung_tool() -> list[dict[str, Any]]:
    """Danh sách tool: phần chọn lựa từ `mcp_tools.json`, schema từ registry."""
    chon = json.loads((spec_dir() / "api" / "mcp_tools.json").read_text(encoding="utf-8"))
    khung = {
        "caps_list": ("Liệt kê năng lực EIDE (238 năng lực, 27 nhóm). Lọc theo `ns`.",
                      {"type": "object", "properties": {"ns": {"type": "string"},
                                                        "implemented": {"type": "boolean"}}}),
        "caps_describe": ("Khai báo đầy đủ của một năng lực: schema vào/ra, các bước, lỗi, hoàn tác.",
                          {"type": "object", "required": ["id"],
                           "properties": {"id": {"type": "string"}}}),
        "caps_invoke": ("Gọi một năng lực EIDE theo id (xem caps_list). Đi qua chính sách tự chủ; "
                        "có thể trả pending khi cần người.",
                        {"type": "object", "required": ["id", "args"],
                         "properties": {"id": {"type": "string"}, "args": {"type": "object"},
                                        "run_id": {"type": "string"}}}),
        "chat_command": ("Gửi một lệnh ngôn ngữ tự nhiên cho EIDE (như gõ trong cửa sổ trò chuyện).",
                         {"type": "object", "required": ["text"],
                          "properties": {"text": {"type": "string"}}}),
    }
    ra: list[dict[str, Any]] = []
    for t in chon:
        ten = t["name"]
        if ten in khung:
            mo_ta, schema = khung[ten]
            ra.append({"name": ten, "description": mo_ta, "inputSchema": schema})
        else:
            cap = t.get("capability") or ten.replace("_", ".", 1)
            reg = get_registry()
            # Chỉ phơi năng lực ĐÃ HIỆN THỰC. Một tool trỏ tới năng lực chưa có handler sẽ trả
            # E1001 cho mọi lời gọi, nhưng vẫn ăn một suất trong trần 20 và vẫn chiếm chỗ trong
            # phần mô tả tool mà mô hình phải đọc. Danh sách "hay dùng" của API-15 §3 được viết
            # cho sản phẩm hoàn chỉnh; ở giữa chừng, phơi một cái cửa khóa còn tệ hơn không có
            # cửa. `bo_qua()` cho biết cái nào bị bỏ, để không ai tưởng danh sách đã đủ.
            if cap not in reg or not reg.get(cap).implemented:
                continue
            ra.append({"name": ten, "description": t.get("description", ""), **_khung(cap)})
    if len(ra) > TRAN_TOOL:
        raise EideError("E1000", f"{len(ra)} tool MCP vượt trần {TRAN_TOOL} của API-15 §3")
    return ra


class McpServer:
    def __init__(self, project: Path | None = None) -> None:
        self.gate = PolicyGate()
        self.ledger = Ledger((project / ".eide" / "store" / "ledger.jsonl") if project
                             else user_log() / "ledger.jsonl")
        self.router = Router(gate=self.gate, ledger=self.ledger)
        self.ctx = Context(project_dir=project, extra={"gate": self.gate, "ledger": self.ledger})
        undo_handlers.dang_ky(self.router, self.ctx)      # §6.4 — xem ghi chú ở `rpc.py`
        # [DEV-176] Cách DUYỆT cổng do handler chạy (G1 trên kế hoạch). Cùng khuôn
        # `undo_handlers`: quên một chỗ thì nút Duyệt chết im lặng ở bề mặt ấy.
        gate_handlers.dang_ky(self.router, self.ctx)
        self.tools = dung_tool()
        self._theo_ten = {t["name"]: t for t in self.tools}

    # ---- phương thức MCP
    def initialize(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"protocolVersion": GIAO_THUC,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "eide", "version": __version__}}

    def tools_list(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"tools": [{k: v for k, v in t.items()
                           if k in ("name", "description", "inputSchema")} for t in self.tools]}

    def tools_call(self, p: dict[str, Any]) -> dict[str, Any]:
        """MCP phân biệt HAI loại hỏng, và phân biệt ấy có ích cho mô hình bên kia.

        Tool không tồn tại là lỗi GIAO THỨC — client gọi sai, trả JSON-RPC error. Tool tồn tại
        nhưng đối số sai hoặc việc thất bại là lỗi THỰC THI — trả `isError: true` trong nội dung,
        để mô hình đọc được thông điệp và sửa đối số ở lần gọi sau thay vì coi cả kênh đã hỏng.
        """
        ten, args = p["name"], p.get("arguments") or {}
        t = self._theo_ten.get(ten)
        if t is None:
            raise EideError("E1001", f"Không có tool MCP: {ten}")
        try:
            return self._goi(ten, t, args)
        except EideError as e:
            return self._noi_dung({"status": "failed", **e.to_rpc()["data"]}, loi=True)
        except KeyError as e:
            return self._noi_dung({"status": "failed", "eide_code": "E1000",
                                   "message": f"thiếu đối số bắt buộc: {e}"}, loi=True)

    def _goi(self, ten: str, t: dict[str, Any], args: dict[str, Any]) -> dict[str, Any]:
        if ten == "caps_list":
            return self._noi_dung({"caps": [
                {"id": c.spec.id, "ns": c.spec.ns, "risk": c.spec.risk_class,
                 "tier": c.spec.tier_hieu_luc, "desc": c.spec.desc, "implemented": c.implemented}
                for c in get_registry().list(args.get("ns"),
                                             args.get("implemented"))]})
        if ten == "caps_describe":
            return self._noi_dung(get_registry().describe(args["id"]))
        if ten == "caps_invoke":
            return self._chay(args["id"], args.get("args") or {})
        if ten == "chat_command":
            return self._chay("chat.parse_intent", {"text": args["text"]})
        return self._chay(t["capability"], args)

    def _chay(self, cap_id: str, args: dict[str, Any]) -> dict[str, Any]:
        """Một lời gọi năng lực qua Router — tức qua PolicyGate.

        ASK KHÔNG phải lỗi. §3: "Tool R3/R4 trả `{status:"pending", gate_id}` khi ASK". Ném
        ngoại lệ ở đây sẽ làm mô hình bên kia đọc "việc đang chờ người" thành "việc đã hỏng", và
        nó sẽ thử lại — mà thử lại một việc đang chờ duyệt là cách tạo ra hàng đợi trùng lặp.
        """
        run = self.router.invoke(cap_id, args, self.ctx)
        d = asdict(run)
        if run.status == "pending":
            return self._noi_dung({"status": "pending", "gate_id": run.run_id,
                                   "decision": run.decision, "cap": cap_id})
        return self._noi_dung(d, loi=run.status == "failed")

    @staticmethod
    def _noi_dung(x: Any, loi: bool = False) -> dict[str, Any]:
        """MCP trả kết quả dạng `content[]`; EIDE trả JSON, nên bọc một khối `text`."""
        return {"content": [{"type": "text", "text": json.dumps(x, ensure_ascii=False, indent=1)}],
                "isError": loi}


def _tra_loi(rid: Any, ket_qua: Any = None, loi: dict[str, Any] | None = None) -> dict[str, Any]:
    d: dict[str, Any] = {"jsonrpc": "2.0", "id": rid}
    if loi is not None:
        d["error"] = loi
    else:
        d["result"] = ket_qua
    return d


def serve_stdio(inp: TextIO, out: TextIO, project: Path | None = None) -> None:
    """Vòng lặp JSON-RPC theo dòng (MCP stdio transport)."""
    srv = McpServer(project)
    ham = {"initialize": srv.initialize, "tools/list": srv.tools_list, "tools/call": srv.tools_call}
    for dong in inp:
        dong = dong.strip()
        if not dong:
            continue
        try:
            req = json.loads(dong)
        except json.JSONDecodeError:
            _ghi(out, _tra_loi(None, loi={"code": -32700, "message": "JSON không hợp lệ"}))
            continue
        rid, ten = req.get("id"), req.get("method", "")
        # Thông báo (không có `id`) — MCP gửi `notifications/initialized`; không trả lời.
        if rid is None and ten.startswith("notifications/"):
            continue
        f = ham.get(ten)
        if f is None:
            _ghi(out, _tra_loi(rid, loi={"code": -32601, "message": f"Không có phương thức {ten}"}))
            continue
        try:
            _ghi(out, _tra_loi(rid, f(req.get("params") or {})))
        except EideError as e:
            r = e.to_rpc()
            _ghi(out, _tra_loi(rid, loi={"code": r["code"], "message": r["message"], "data": r["data"]}))
        except Exception as e:                                  # noqa: BLE001
            _ghi(out, _tra_loi(rid, loi={"code": -32603, "message": f"{type(e).__name__}: {e}"}))


def _ghi(out: TextIO, obj: dict[str, Any]) -> None:
    out.write(json.dumps(obj, ensure_ascii=False) + "\n")
    out.flush()
