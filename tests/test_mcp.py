"""MCP server — API-15 §3. WI-011.

tc của §7: "mọi tool MCP compile trên 3 adapter". Ở đây kiểm phần kiểm được không cần mạng:
schema hợp lệ, trần 20 tool, và chính sách vẫn nằm giữa mọi lời gọi.
"""
from __future__ import annotations

import io
import json

import pytest

from eide.mcp.server import GIAO_THUC, TRAN_TOOL, McpServer, bo_qua, dung_tool, serve_stdio
from eide_core.registry import get_registry


def _phien(dong: list[dict], project=None) -> list[dict]:
    """Chạy một phiên stdio thật và trả các tin nhắn phản hồi."""
    inp = io.StringIO("\n".join(json.dumps(d, ensure_ascii=False) for d in dong) + "\n")
    out = io.StringIO()
    serve_stdio(inp, out, project)
    return [json.loads(x) for x in out.getvalue().splitlines() if x.strip()]


def _kq(msg: dict):
    """Bóc JSON khỏi khối `content[].text` mà MCP bọc quanh kết quả."""
    return json.loads(msg["result"]["content"][0]["text"])


# ---------- danh sách tool


def test_moi_tool_co_input_schema_hop_le():
    """§3: "schema chính là input_schema của năng lực".

    `api/mcp_tools.json` chỉ mang phần CHỌN LỰA (tool nào là "hay dùng") — nó không có
    `inputSchema`. Gắn schema lúc khởi động từ registry là điều làm cho §3 đúng chữ, và cũng là
    thứ giữ cho không có bảng schema thứ hai chép tay bên cạnh `cds.json`.
    """
    jsonschema = pytest.importorskip("jsonschema")
    for t in dung_tool():
        assert t["inputSchema"], f"{t['name']} thiếu inputSchema"
        jsonschema.Draft202012Validator.check_schema(t["inputSchema"])


def test_khong_vuot_tran_20_tool():
    """§3: "tổng ≤ 20 tool/phiên (ACI)".

    Trần này không phải giới hạn kỹ thuật của MCP mà là giới hạn chú ý của mô hình gọi tool:
    238 năng lực thành 238 tool sẽ làm phần mô tả chiếm hết ngữ cảnh và mô hình chọn kém đi.
    """
    assert len(dung_tool()) <= TRAN_TOOL


def test_ba_tool_chung_giu_cho_moi_nang_luc_van_goi_duoc():
    """Chỉ vài tool được phơi, nhưng cả 238 năng lực vẫn tới được — qua hai bước thay vì một."""
    ten = {t["name"] for t in dung_tool()}
    assert {"caps_list", "caps_describe", "caps_invoke", "chat_command"} <= ten


def test_chi_phoi_nang_luc_da_hien_thuc():
    """Một tool trỏ tới năng lực chưa có handler trả E1001 cho MỌI lời gọi, nhưng vẫn ăn một
    suất trong trần 20 và vẫn chiếm chỗ trong phần mô tả mà mô hình phải đọc.

    Danh sách "hay dùng" của API-15 §3 được viết cho sản phẩm hoàn chỉnh; ở giữa chừng, phơi một
    cái cửa khóa còn tệ hơn không có cửa. Nhưng phải NÓI RA cái nào bị bỏ, không thì danh sách
    trông như đã đủ.
    """
    reg = get_registry()
    for t in dung_tool():
        if (cap := t.get("capability")):
            assert cap in reg and reg.get(cap).implemented, f"{t['name']} → {cap} chưa hiện thực"
    assert bo_qua(), "hiện còn năng lực chưa hiện thực — danh sách bỏ qua không được rỗng"
    assert set(bo_qua()).isdisjoint({t["name"] for t in dung_tool()})


# ---------- giao thức


def test_bat_tay_va_liet_ke():
    ra = _phien([
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
    ])
    assert len(ra) == 2, "thông báo (không có id) KHÔNG được trả lời — JSON-RPC 2.0 §4.1"
    assert ra[0]["result"]["protocolVersion"] == GIAO_THUC
    assert ra[0]["result"]["serverInfo"]["name"] == "eide"
    tools = ra[1]["result"]["tools"]
    assert len(tools) == len(dung_tool())
    # `tools/list` chỉ được trả ba trường của MCP; `capability`/`risk` là ghi chú nội bộ.
    assert all(set(t) == {"name", "description", "inputSchema"} for t in tools)


def test_phuong_thuc_la_tra_32601_chu_khong_im_lang():
    ra = _phien([{"jsonrpc": "2.0", "id": 1, "method": "khong/co", "params": {}}])
    assert ra[0]["error"]["code"] == -32601


def test_json_hong_tra_32700_va_van_chay_tiep():
    """Một dòng hỏng không được làm chết cả phiên: MCP là kênh dài, và client sẽ không biết
    server đã im lặng vì lý do gì."""
    inp = io.StringIO('{ hỏng\n{"jsonrpc":"2.0","id":9,"method":"initialize","params":{}}\n')
    out = io.StringIO()
    serve_stdio(inp, out)
    ra = [json.loads(x) for x in out.getvalue().splitlines() if x.strip()]
    assert ra[0]["error"]["code"] == -32700
    assert ra[1]["id"] == 9 and "result" in ra[1]


# ---------- chính sách vẫn ở giữa


def test_caps_list_thay_CA_registry(tmp_path, workspace):
    """Chỉ 7 tool được phơi, nhưng `caps_list` vẫn thấy toàn bộ registry — đó là điều làm cho
    trần 20 không phải một giới hạn về NĂNG LỰC, chỉ là giới hạn về số lối vào trực tiếp."""
    ra = _phien([{"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                  "params": {"name": "caps_list", "arguments": {"ns": "kg"}}}])
    caps = _kq(ra[0])["caps"]
    assert {c["id"] for c in caps} >= {"kg.build", "kg.conflicts"}
    tat_ca = _kq(_phien([{"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                          "params": {"name": "caps_list", "arguments": {}}}])[0])["caps"]
    # Đo từ `cds.json`, không gõ số: bộ hồ sơ thêm năng lực là việc thường xuyên
    # (238 → 241 ở v2.0), và một con số viết cứng biến việc ấy thành một bài test
    # đỏ ở chỗ không liên quan gì tới MCP.
    import json as _json

    from eide_core.paths import spec_dir as _sd
    assert len(tat_ca) == len(_json.loads((_sd() / "cds.json").read_text(encoding="utf-8")))


def test_ASK_tra_pending_chu_khong_phai_loi(tmp_path, workspace):
    """§3: "Tool R3/R4 trả `{status:"pending", gate_id}` khi ASK".

    Ném lỗi ở đây làm mô hình bên kia đọc "việc đang chờ người" thành "việc đã hỏng", và nó sẽ
    THỬ LẠI — mà thử lại một việc đang chờ duyệt là cách tạo ra hàng đợi trùng lặp.
    """
    srv = McpServer(workspace)
    r = srv.tools_call({"name": "caps_invoke",
                        "arguments": {"id": "kg.resolve_conflict",
                                      "args": {"conflict_id": "f_a:f_b", "choice": "a",
                                               "actor": "agent"}}})
    d = json.loads(r["content"][0]["text"])
    assert d["status"] == "pending", d
    assert r["isError"] is False, "pending KHÔNG phải lỗi"
    assert d["gate_id"] and d["cap"] == "kg.resolve_conflict"


def test_loi_that_van_la_loi(tmp_path, workspace):
    srv = McpServer()
    r = srv.tools_call({"name": "caps_describe", "arguments": {"id": "khong.co"}})
    assert r["isError"] is True
    assert json.loads(r["content"][0]["text"])["eide_code"] == "E1001"


def test_tool_khong_ton_tai_la_E1001():
    ra = _phien([{"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                  "params": {"name": "khong_co_tool", "arguments": {}}}])
    assert ra[0]["error"]["data"]["eide_code"] == "E1001"
