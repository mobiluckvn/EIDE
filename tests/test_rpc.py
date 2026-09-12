import io
import json

from eide.daemon.rpc import Daemon, serve_stdio


def test_hello_and_caps_list():
    d = Daemon()
    r = d.handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "1.2"}})
    assert r["result"]["caps"] == 238
    r = d.handle({"jsonrpc": "2.0", "id": 2, "method": "caps.list", "params": {"ns": "tool"}})
    assert len(r["result"]["caps"]) == 10


def test_version_mismatch_E1002():
    r = Daemon().handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "2.0"}})
    assert r["error"]["data"]["eide_code"] == "E1002"


def test_stdio_roundtrip():
    inp = io.StringIO(json.dumps({"jsonrpc": "2.0", "id": 9, "method": "nope"}) + "\nkhông phải json\n")
    out = io.StringIO()
    serve_stdio(inp, out)
    lines = [json.loads(x) for x in out.getvalue().splitlines()]
    assert lines[0]["error"]["code"] == -32601 and lines[1]["error"]["code"] == -32700


# ---------- bề mặt panel (API-15 §1) — 22 phương thức thêm 12/09/2026

import pytest  # noqa: E402

from eide_core import store  # noqa: E402


@pytest.fixture
def du_an_rpc(tmp_path, workspace):
    """Daemon gắn vào một dự án thật — panel luôn nói chuyện trong ngữ cảnh một dự án."""
    from eide_core.ledger import Ledger
    from eide_core.policy import PolicyGate
    from eide_core.router import Context, Router

    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "panel"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root))
    return Daemon(project=root), root


def _goi(d, ten, params=None):
    return d.handle({"jsonrpc": "2.0", "id": 1, "method": ten, "params": params or {}})


def test_moi_phuong_thuc_dang_ky_deu_CO_trong_spec():
    """Cổng chặn ngược: daemon không được bịa ra một phương thức ngoài `openrpc.json`.

    Cổng cũ trong `test_specs_consistency` đã canh điều này, nhưng nó dễ bị quên khi thêm hàng
    loạt như hôm nay — nên nhắc lại ở đây, cạnh chỗ người ta thật sự thêm phương thức.
    """
    import json as _json

    from eide_core.paths import spec_dir
    spec = {m["name"] for m in _json.loads(
        (spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    assert set(Daemon().methods) <= spec, sorted(set(Daemon().methods) - spec)


def test_alias_view_di_QUA_router_nen_co_ghi_nhat_ky(du_an_rpc):
    """Alias chứ không gọi thẳng handler: mỗi phương thức panel vẫn qua cổng chính sách và vẫn
    vào chuỗi băm. Một đường tắt sẽ nhanh hơn và sẽ bỏ qua cả hai."""
    d, _ = du_an_rpc
    truoc = len(d.ledger.records())
    _goi(d, "view.timeline", {"params": {}})
    sau = [x["kind"] for x in d.ledger.records()[truoc:]]
    assert "cap.run.start" in sau and "gate.decision" in sau


def test_alias_tra_RESULT_chu_khong_tra_ca_ban_ghi_luot_chay(du_an_rpc):
    """Panel gọi `view.*` muốn một đồ thị để vẽ, không muốn một bản ghi lượt chạy."""
    d, _ = du_an_rpc
    r = _goi(d, "view.timeline", {"params": {}})
    assert "result" in r and "status" not in r["result"], r["result"]


def test_sau_alias_LECH_TEN_tro_dung_nang_luc(du_an_rpc):
    """`view.coverage` → `view.coverage_map`. Tên RPC ngắn cho plugin gõ, tên năng lực nói rõ
    nó trả cái gì — bảng ALIAS là chỗ DUY NHẤT giữ ánh xạ ấy."""
    from eide.daemon.rpc import ALIAS
    from eide_core.registry import get_registry

    reg = get_registry()
    for ten_rpc, cap in ALIAS.items():
        assert cap in reg, f"{ten_rpc} → {cap} không phải năng lực nào"
        assert reg.get(cap).implemented, f"{ten_rpc} → {cap} chưa hiện thực"


def test_hex_resolve_tra_loi_cau_ai_noi_the(du_an_rpc):
    """Năng lực nhỏ nhất mà đúng tinh thần sản phẩm nhất: một con số trong khung hex trả lời
    được "ai nói thế". Tra theo GIÁ TRỊ chuẩn hoá nên `0x40005400` và `1073763328` cùng kết quả."""
    import hashlib
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_h", "u", hashlib.sha256(b"s_h").hexdigest(), "svd", "gold", "vendor-doc"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_hex00000000aa", "chip:st.stm32f411/periph:I2C1", "base_address",
                   _json.dumps("0x40005400"), "s_h", "parser", "gold", 1.0, "verified", "A"))
        c.commit()

    for dia_chi in ("0x40005400", "1073763328"):
        r = _goi(d, "hex.resolve", {"address": dia_chi})["result"]
        assert r["subject"] == "chip:st.stm32f411/periph:I2C1", (dia_chi, r)
        assert r["facts"][0]["id"] == "f_hex00000000aa"


def test_hex_resolve_khong_tra_fact_CHUA_DUYET(du_an_rpc):
    """Khung hex là chỗ người ta tin ngay. Trả một fact `normalized` ở đó là khẳng định một con
    số chưa ai duyệt — cùng lý do `code.annotate` không gợi ý chúng."""
    import hashlib
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  ("s_h2", "u", hashlib.sha256(b"s_h2").hexdigest(), "svd", "bronze", "unknown"))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  ("f_hex00000000bb", "chip:x", "base_address", _json.dumps("0xDEAD"),
                   "s_h2", "parser", "bronze", 0.4, "normalized", "C"))
        c.commit()
    assert _goi(d, "hex.resolve", {"address": "0xDEAD"})["result"]["facts"] == []


def test_doc_open_tra_muc_LOI_THOI(du_an_rpc):
    """Panel mở tài liệu thì thấy ngay mục nào lỗi thời — không phải đi hỏi một lệnh khác."""
    import json as _json

    d, root = du_an_rpc
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO doc_artifact (id,type,path,lang,sections,stale_sections,at)"
                  " VALUES (?,?,?,?,?,?,?)",
                  ("doc_p", "SRS", "/x/a.md", "vi",
                   _json.dumps([{"heading": "A"}, {"heading": "B"}]),
                   _json.dumps(["B"]), "2026-09-12T00:00:00Z"))
        c.commit()
    r = _goi(d, "doc.open", {"path": "/x/a.md"})["result"]
    assert [s["heading"] for s in r["sections"]] == ["A", "B"] and r["stale"] == ["B"]


def test_doc_open_tep_khong_co_thi_tra_RONG_chu_khong_no(du_an_rpc):
    d, _ = du_an_rpc
    assert _goi(d, "doc.open", {"path": "/khong/co.md"})["result"] == {"sections": [], "stale": []}


def test_diagram_save_khong_co_id_thi_KHONG_bia_sync_diff(du_an_rpc):
    """Lược đồ mới gõ trong editor chưa có id thì không so được với gì — nói ra bằng cách vắng
    mặt trường ấy thật hơn là trả một diff rỗng trông như "không lệch"."""
    d, _ = du_an_rpc
    r = _goi(d, "diagram.save", {"src": "stateDiagram-v2\n  A --> B\n", "lang": "mermaid"})
    assert "sync_diff" not in r["result"], r["result"]


def test_log_stats_alias_tro_dung_debug_log_stats(du_an_rpc):
    d, root = du_an_rpc
    (root / "a.log").write_text("[1.0] INFO x\n[2.0] ERROR y\n", encoding="utf-8")
    r = _goi(d, "log.stats", {"params": {"file": "a.log"}})["result"]
    assert r["stats"]["lines"] == 2 and r["stats"]["levels"] == {"ERROR": 1, "INFO": 1}
