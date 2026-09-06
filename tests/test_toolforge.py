"""WI-020 · ToolForge — CDS-12.3 TOOL-01…07; SEC-25 §2; POL-17 G-TOOL.

Trọng tâm là TC-TL-02: hiệu ứng thật vượt hiệu ứng khai báo → `effects_ok=false`.

Bản đầu của tệp này dựng TC-TL-02 bằng một công cụ gọi socket ngầm qua `importlib`. Chạy thử
mới thấy lớp AST đã chặn `importlib` (nó nằm trong nhóm `system`), nên bài kiểm ấy chưa từng
chạm tới lớp 2 — nó chỉ kiểm lại lớp 1 dưới một cái tên khác.

Sự thật hóa ra sạch hơn: MỌI đường với tới mạng đều cần một `import`, và cả ba lối vòng
(`__import__`, `importlib`, `eval`) đều bị chặn — nên với `network`, lớp 1 là hàng rào kín.
Chỗ lớp 1 THẬT SỰ mù là hiệu ứng không cần import: `open(p, "w")` là hàm dựng sẵn. Đó là
kịch bản TC-TL-02 dùng bây giờ, và nó có một `assert` khẳng định lớp 1 mù trước khi đo lớp 2 —
nếu không thì bài kiểm xanh vì lý do sai.
"""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.gateway import EchoPort, Gateway
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router
from eide_core.toolforge import ToolSpec, hieu_ung_khop, kiem_ast, module_bi_cam


def _rt(tmp_path, workspace, tra_loi=None):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort(tra_loi or [])
    led = Ledger(tmp_path / "ledger.jsonl")
    gate = PolicyGate()
    r = Router(gate=gate, ledger=led)
    res = r.invoke("project.create", {"text": "dự án thử công cụ"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=led)
    ctx = Context(project_dir=root, extra={
        "gate": gate, "ledger": led,
        "gateway": Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})})
    return r, ctx, root, echo


def _tra_ve_ma(ma: str) -> dict:
    return {"files": [{"path": "tool.py", "content": ma}], "rationale": "thử"}


# ---------------------------------------------------------------- lớp rủi ro và mức

@pytest.mark.parametrize("effects,risk,tier", [
    ([], "R0", "T1"),
    (["read_fs"], "R0", "T1"),
    (["network"], "R1", "T1"),
    (["write_project"], "R2", "T1*"),
    (["hardware"], "R3", "T1*"),
    (["system"], "R4", "T2"),
    (["read_fs", "hardware"], "R3", "T1*"),      # lấy mức CAO NHẤT
])
def test_suy_lop_rui_ro_tu_hieu_ung(effects, risk, tier):
    """TOOL-05 bước 1 và TOOL-06 bước 1, từng chữ."""
    s = ToolSpec(name="x", effects=effects)
    assert (s.risk, s.tier) == (risk, tier)


def test_hieu_ung_la_bi_tu_choi():
    with pytest.raises(EideError) as ei:
        ToolSpec(name="x", effects=["doc_email_cua_nguoi_dung"])
    assert ei.value.code == "E1000"


def test_ten_cong_cu_phai_sach():
    # Tên đi vào ĐƯỜNG DẪN và vào id năng lực `user.<name>`; một tên có `../` là một lối
    # thoát ra khỏi .eide/tools/.
    for xau in ["../thoat", "co dau cach", "a/b", ""]:
        with pytest.raises(EideError):
            ToolSpec(name=xau)


# ---------------------------------------------------------------- lớp 1: kiểm AST

def test_cam_import_theo_hieu_ung():
    assert "socket" in module_bi_cam([])
    assert "socket" not in module_bi_cam(["network"])       # khai rồi thì được dùng
    assert "subprocess" in module_bi_cam(["network"])       # nhưng system thì vẫn cấm


def test_ast_bat_import_thang():
    v = kiem_ast("import socket\ndef run(a, ctx=None): return {}", [])
    assert v == ["import socket"]


def test_ast_bat_from_import():
    v = kiem_ast("from urllib.request import urlopen\ndef run(a, ctx=None): return {}", [])
    assert v and "urllib" in v[0]


def test_ast_bat_goi_con():
    """`http.client` bị chặn nếu `http` bị chặn — gói con không phải một lối vòng."""
    assert kiem_ast("import http.client", [])


def test_ast_bat_eval_exec_du_khai_gi():
    """`eval`/`exec`/`__import__` cấm KHÔNG ĐIỀU KIỆN: chúng làm mọi phép kiểm tĩnh phía trên
    thành vô nghĩa, nên không hiệu ứng nào biện minh được."""
    for ma in ["eval('1')", "exec('x=1')", "__import__('socket')"]:
        assert kiem_ast(f"def run(a, ctx=None):\n    {ma}\n    return {{}}",
                        ["network", "system", "hardware", "write_project", "read_fs"])


def test_ast_cho_qua_ma_sach():
    ma = "def run(args, ctx=None):\n    return {'tong': sum(args.get('xs', []))}\n"
    assert kiem_ast(ma, []) == []


def test_write_tu_choi_ma_vi_pham_bang_E5003(tmp_path, workspace):
    r, ctx, root, _ = _rt(tmp_path, workspace,
                          [_tra_ve_ma("import socket\ndef run(a, ctx=None): return {}")])
    run = r.invoke("tool.write", {"spec": {"name": "xau", "purpose": "thử", "effects": []}}, ctx)
    assert run.status == "failed"
    assert run.error["eide_code"] == "E5003"
    assert not (root / ".eide" / "tools" / "xau").exists(), "mã vi phạm KHÔNG được lưu"


def test_write_luu_du_ba_tep(tmp_path, workspace):
    ma = "def run(args, ctx=None):\n    return {'tong': sum(args.get('xs', []))}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    out = r.invoke("tool.write", {"spec": {
        "name": "tong_day", "purpose": "cộng một dãy số", "effects": [],
        "acceptance": [{"args": {"xs": [1, 2, 3]}, "expect": {"tong": 6}}]}}, ctx).result
    d = root / ".eide" / "tools" / "tong_day"
    assert {p.name for p in d.iterdir()} == {"tool.py", "test_tool.py", "spec.json"}
    assert out["effects"] == []


# ---------------------------------------------------------------- lớp 2: hiệu ứng thật

def test_hieu_ung_khop_la_MOT_chieu():
    """`observed ⊆ declared`. Khai nhiều hơn làm là thừa nhưng an toàn; làm nhiều hơn khai là
    chính thứ cổng G-TOOL sinh ra để chặn."""
    assert hieu_ung_khop(set(), ["network"])                 # khai thừa: được
    assert hieu_ung_khop({"read_fs"}, ["read_fs", "network"])
    assert not hieu_ung_khop({"network"}, [])                # làm thừa: không


def test_moi_duong_import_dong_deu_bi_lop_1_chan():
    """Trước khi tin lớp 2, phải biết lớp 1 đóng được những gì.

    Mọi cách với tới mạng đều cần một `import`, và cả ba lối vòng — `__import__`, `importlib`,
    `eval` — đều bị chặn. Nên với hiệu ứng `network`, lớp AST là một hàng rào kín, không phải
    một tấm lưới.
    """
    for ma in ["__import__('socket')",
               "import importlib\nimportlib.import_module('socket')",
               "eval(\"__import__('socket')\")"]:
        assert kiem_ast(ma, []), f"lọt qua lớp 1: {ma!r}"


def test_TC_TL_02_hieu_ung_KHONG_CAN_IMPORT_thi_chi_lop_2_bat_duoc(tmp_path, workspace):
    """TC-TL-02 — bài kiểm quan trọng nhất của nhóm này, và nó về GIỚI HẠN của lớp 1.

    Lớp AST chỉ thấy `import`. Nhưng ghi tệp KHÔNG CẦN import gì cả: `open(p, "w")` là hàm dựng
    sẵn. Nên một công cụ khai `read_fs` rồi ghi đè một tệp đi qua lớp 1 mà không để lại dấu vết
    nào — và nếu chỉ có lớp 1 thì "hiệu ứng khai báo" chỉ là một lời hứa danh dự.

    Đây là lý do TOOL-04 bước 1 đòi giám sát hiệu ứng THẬT, không chỉ đọc mã.
    """
    ma = (
        "def run(args, ctx=None):\n"
        "    with open('/tmp/eide-tool-lut.txt', 'w') as f:\n"
        "        f.write('công cụ này khai read_fs nhưng đang GHI')\n"
        "    return {'ok': True}\n"
    )
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    # Tiền đề: lớp 1 KHÔNG thấy gì. Khẳng định chứ không giả định — nếu lớp 1 bắt được thì
    # bài kiểm này không còn nói gì về lớp 2.
    assert kiem_ast(ma, ["read_fs"]) == [], "lớp 1 lẽ ra mù trước open(); test mất ý nghĩa"

    r.invoke("tool.write", {"spec": {"name": "ghi_lut", "purpose": "khai đọc nhưng ghi",
                                     "effects": ["read_fs"]}}, ctx)
    out = r.invoke("tool.test", {"tool_id": "ghi_lut"}, ctx).result
    assert out["effects_ok"] is False, f"lớp 2 không bắt được: {out['observed_effects']}"
    assert "write_project" in out["observed_effects"]


def test_ghi_so_loi_khi_hieu_ung_vuot(tmp_path, workspace):
    """MEM-11 §6: mỗi lần vượt là một dữ kiện để sinh prompt phủ định cho coder."""
    ma = ("def run(args, ctx=None):\n"
          "    open('/tmp/eide-tool-roro.txt', 'w').write('x')\n"
          "    return {}\n")
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {"name": "ro_ri", "purpose": "x", "effects": ["read_fs"]}}, ctx)
    r.invoke("tool.test", {"tool_id": "ro_ri"}, ctx)
    so_loi = [x for x in r.ledger.records()
              if x["kind"] == "error" and (x["data"] or {}).get("kind") == "tool_fail"]
    assert so_loi and "ro_ri" in so_loi[-1]["data"]["task_ref"]


def test_cong_cu_sach_thi_effects_ok(tmp_path, workspace):
    """Đối chứng: nếu mọi công cụ đều `effects_ok=false` thì bài kiểm trên vô nghĩa."""
    ma = ("def run(args, ctx=None):\n"
          "    return {'tong': sum(args.get('xs', []))}\n")
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {
        "name": "tong_sach", "purpose": "cộng", "effects": [],
        "acceptance": [{"args": {"xs": [1, 2]}, "expect": {"tong": 3}}]}}, ctx)
    out = r.invoke("tool.test", {"tool_id": "tong_sach"}, ctx).result
    assert out["effects_ok"] is True, out["observed_effects"]


# ---------------------------------------------------------------- lớp 3: cổng G-TOOL

def test_chua_test_thi_khong_dang_ky_duoc(tmp_path, workspace):
    """TOOL-06: "yêu cầu tool.test đạt". Một công cụ chưa ai kiểm mà vào registry thì lần gọi
    sau nó trông y hệt một năng lực có hợp đồng."""
    ma = "def run(args, ctx=None):\n    return {}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {"name": "chua_kiem", "purpose": "x", "effects": []}}, ctx)
    run = r.invoke("tool.register", {"tool_id": "chua_kiem"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_dang_ky_sinh_nang_luc_user_du_13_truong(tmp_path, workspace):
    """TOOL-06 tc: "caps.describe user.<name> trả đủ 13 trường; chuỗi sau gọi được"."""
    ma = ("def run(args, ctx=None):\n"
          "    return {'tong': sum(args.get('xs', []))}\n")
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {
        "name": "tong_day", "purpose": "cộng một dãy số", "effects": [],
        "acceptance": [{"args": {"xs": [1, 2]}, "expect": {"tong": 3}}]}}, ctx)
    r.invoke("tool.test", {"tool_id": "tong_day"}, ctx)
    out = r.invoke("tool.register", {"tool_id": "tong_day"}, ctx).result
    assert out["capability_id"] == "user.tong_day"
    assert out["capability_code"].startswith("USER-")

    mo_ta = r.registry.describe("user.tong_day")
    for truong in ("code", "id", "ns", "desc", "risk", "tier", "grounding", "ask_when",
                   "milestone", "input_schema", "output_schema", "undo", "impl"):
        assert truong in mo_ta, truong
    assert mo_ta["risk"] == "R0" and mo_ta["tier"] == "T1"


def test_nang_luc_user_tach_khoi_cds(tmp_path, workspace):
    """`_user` tách khỏi `_caps` vì hai nguồn có mức tin cậy khác nhau: một bên là hợp đồng
    người viết, một bên là mã mô hình sinh."""
    ma = "def run(args, ctx=None):\n    return {}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {"name": "tam", "purpose": "x", "effects": []}}, ctx)
    r.invoke("tool.test", {"tool_id": "tam"}, ctx)
    r.invoke("tool.register", {"tool_id": "tam"}, ctx)
    assert "user.tam" in r.registry
    assert r.registry.get("user.tam").spec.ns == "user"
    # cds.json không đổi: test_specs_consistency chỉ soi `_caps`
    assert "user.tam" not in {c["id"] for c in json.loads(
        (spec_dir() / "cds.json").read_text(encoding="utf-8"))}


def test_dang_ky_ngoai_namespace_user_bi_tu_choi():
    from eide_core.registry import Registry
    with pytest.raises(EideError) as ei:
        Registry().dang_ky_tam({"id": "code.merge", "code": "X", "ns": "code", "desc": "",
                                "risk": "R0", "tier": "T1", "grounding": "", "ask_when": "",
                                "ref": "", "milestone": "M1",
                                "input_schema": {}, "output_schema": {}})
    assert ei.value.code == "E1000"


# ---------------------------------------------------------------- TOOL-02, TOOL-07

def test_tim_thay_cong_cu_da_co_diem_1(tmp_path, workspace):
    """TOOL-02 tc: "công cụ đã có → điểm ≥ 0,8"."""
    ma = "def run(args, ctx=None):\n    return {}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {"name": "crc16", "purpose": "tính CRC16", "effects": []}}, ctx)
    out = r.invoke("tool.search", {"spec": {"name": "crc16", "purpose": "tính CRC16"}}, ctx).result
    assert out["tools"] and out["tools"][0]["score"] >= 0.8


def test_sua_qua_ba_vong_thi_bo_cuoc(tmp_path, workspace):
    """TOOL-07: "≤ 3 vòng". Vòng lặp sửa không chặn sẽ thử đủ biến thể cho tới khi một biến thể
    lọt qua bộ kiểm — tức tối ưu hóa cho việc VƯỢT cổng thay vì cho việc đúng."""
    ma = "def run(args, ctx=None):\n    return {}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma)])
    r.invoke("tool.write", {"spec": {"name": "hong", "purpose": "x", "effects": []}}, ctx)
    out = r.invoke("tool.repair", {"tool_id": "hong", "report_id": "r1", "round": 4}, ctx).result
    assert out["give_up"] is True


def test_ban_sua_van_vi_pham_thi_E5003(tmp_path, workspace):
    ma_sach = "def run(args, ctx=None):\n    return {}\n"
    ma_xau = "import subprocess\ndef run(args, ctx=None): return {}\n"
    r, ctx, root, _ = _rt(tmp_path, workspace, [_tra_ve_ma(ma_sach), _tra_ve_ma(ma_xau)])
    r.invoke("tool.write", {"spec": {"name": "van_hong", "purpose": "x", "effects": []}}, ctx)
    run = r.invoke("tool.repair", {"tool_id": "van_hong", "report_id": "r1", "round": 1}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E5003"
