"""PROJECT-09 · project.preferences — CDS-12.3; DPS-09 D8.

tc: "Ghi rồi đọc trả đúng; delete xóa".
steps: get/list đọc dự án trước, người sau · set ghi Preference với learned_from · delete xóa ·
"Không lưu dữ liệu nhạy cảm (kiểm regex khóa)" — regex của API-15 §7 là `sk-|AIza|Bearer `.
errors: E1000.
"""
from __future__ import annotations

import pytest
import yaml

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture()
def cau_hinh_rieng(tmp_path, monkeypatch):
    """Tùy chọn phạm vi `user` nằm ngoài dự án — trỏ nó vào tmp để test không đụng máy thật."""
    d = tmp_path / "usercfg"
    d.mkdir()
    monkeypatch.setattr("eide.caps.project.user_config", lambda: d)
    return d


def _du_an(tmp_path, workspace, text="dự án robot dò đường"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l0.jsonl"))
    res = r.invoke("project.create", {"text": text}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return root


def _goi(tmp_path, root, params, actor="human"):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "ledger.jsonl"))
    return r.invoke("project.preferences", params, Context(project_dir=root, actor=actor))


# ---------- tc: ghi rồi đọc trả đúng; delete xóa ----------

def test_set_roi_get_tra_dung(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    run = _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project",
                                "value": {"value": "stlink", "learned_from": "UC-A03"}})
    assert run.status == "done", run
    got = _goi(tmp_path, root, {"op": "get", "key": "probe"}).result["prefs"]
    assert got["probe"]["value"] == "stlink"
    assert got["probe"]["learned_from"] == "UC-A03"
    assert got["probe"]["scope"] == "project"


def test_delete_xoa(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    _goi(tmp_path, root, {"op": "delete", "key": "probe", "scope": "project"})
    assert _goi(tmp_path, root, {"op": "get", "key": "probe"}).result["prefs"] == {}


def test_list_tra_het(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    _goi(tmp_path, root, {"op": "set", "key": "editor", "scope": "user", "value": {"value": "geditor"}})
    prefs = _goi(tmp_path, root, {"op": "list"}).result["prefs"]
    assert set(prefs) == {"probe", "editor"}


def test_op_mac_dinh_la_list(tmp_path, workspace, cau_hinh_rieng):
    """input_schema có `required: []` — gọi `{}` phải chạy được, không nổ."""
    root = _du_an(tmp_path, workspace)
    assert _goi(tmp_path, root, {}).result["prefs"] == {}


# ---------- bước 1: "get/list: đọc dự án trước, người sau" ----------

def test_du_an_che_nguoi_dung(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "user", "value": {"value": "jlink"}})
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    got = _goi(tmp_path, root, {"op": "get", "key": "probe"}).result["prefs"]
    assert got["probe"]["value"] == "stlink" and got["probe"]["scope"] == "project"


def test_khong_co_du_an_thi_van_doc_duoc_pham_vi_user(tmp_path, workspace, cau_hinh_rieng):
    """Tùy chọn `user` sống ngoài dự án, nên nó phải dùng được khi chưa mở dự án nào."""
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "editor", "scope": "user", "value": {"value": "geditor"}})
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l2.jsonl"))
    got = r.invoke("project.preferences", {"op": "get", "key": "editor"},
                   Context(project_dir=None, actor="human")).result["prefs"]
    assert got["editor"]["value"] == "geditor"


def test_user_scope_dung_chung_giua_hai_du_an(tmp_path, workspace, cau_hinh_rieng):
    a = _du_an(tmp_path, workspace, "dự án alpha")
    b = _du_an(tmp_path, workspace, "dự án beta")
    _goi(tmp_path, a, {"op": "set", "key": "editor", "scope": "user", "value": {"value": "geditor"}})
    got = _goi(tmp_path, b, {"op": "get", "key": "editor"}).result["prefs"]
    assert got["editor"]["value"] == "geditor"


def test_project_scope_khong_ro_ri_sang_du_an_khac(tmp_path, workspace, cau_hinh_rieng):
    a = _du_an(tmp_path, workspace, "dự án alpha")
    b = _du_an(tmp_path, workspace, "dự án beta")
    _goi(tmp_path, a, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    assert _goi(tmp_path, b, {"op": "get", "key": "probe"}).result["prefs"] == {}


# ---------- bước 3: "Không lưu dữ liệu nhạy cảm (kiểm regex khóa)" ----------

@pytest.mark.parametrize("bi_mat", [
    "AIzaSyD-nhinnhu-mot-khoa-Gemini-that-0123456",     # regex API-15 §7: AIza
    "sk-proj-abcdefghijklmnopqrstuvwxyz0123456789",     # sk-
    "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",      # Bearer
])
def test_tu_choi_ghi_bi_mat(tmp_path, workspace, cau_hinh_rieng, bi_mat):
    """D8 ghi nhớ CÂU TRẢ LỜI của kỹ sư, không phải khóa của họ. Lọt vào đây là lọt vào git."""
    root = _du_an(tmp_path, workspace)
    run = _goi(tmp_path, root, {"op": "set", "key": "token", "scope": "user", "value": {"value": bi_mat}})
    assert run.status == "failed"
    assert run.error["eide_code"] == "E1000"
    # và thông báo lỗi không được in lại chính chuỗi bí mật
    assert bi_mat not in str(run.error)


def test_bi_mat_nam_sau_trong_object_cung_bi_bat(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    run = _goi(tmp_path, root, {"op": "set", "key": "cfg", "scope": "user",
                                "value": {"value": {"nested": {"k": "AIzaSyD-khoa-nam-sau-ba-lop-0123456789"}}}})
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_chuoi_binh_thuong_khong_bi_bat_nham(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    for v in ["stlink", "luôn tạo mới", "openocd -f interface/stlink.cfg", "Bearer"]:
        run = _goi(tmp_path, root, {"op": "set", "key": "k", "scope": "user", "value": {"value": v}})
        assert run.status == "done", f"{v!r} bị chặn oan"


# ---------- E1000 ----------

def test_set_thieu_key_la_E1000(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    run = _goi(tmp_path, root, {"op": "set", "value": {"value": "x"}})
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_op_la_thi_bi_schema_chan(tmp_path, workspace, cau_hinh_rieng):
    """`op` có enum trong input_schema → Router chặn trước khi vào handler."""
    root = _du_an(tmp_path, workspace)
    with pytest.raises(EideError) as ei:
        _goi(tmp_path, root, {"op": "drop_table", "key": "x"})
    assert ei.value.code == "E1000"


# ---------- nơi lưu (DDD-14 §6 preferences.yaml, §2 bảng preference) ----------

def test_user_scope_ghi_ra_preferences_yaml(tmp_path, workspace, cau_hinh_rieng):
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "editor", "scope": "user", "value": {"value": "geditor"}})
    f = cau_hinh_rieng / "preferences.yaml"
    assert f.exists()
    d = yaml.safe_load(f.read_text(encoding="utf-8"))
    assert d["editor"]["value"] == "geditor"
    assert "at" in d["editor"]


def test_project_scope_ghi_vao_bang_preference(tmp_path, workspace, cau_hinh_rieng):
    """DDD-14 §2: thực thể Preference, PRIMARY KEY (key, scope)."""
    import sqlite3
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    with sqlite3.connect(store.store_path(root)) as c:
        rows = c.execute("SELECT key, scope, value FROM preference").fetchall()
    assert len(rows) == 1 and rows[0][0] == "probe" and rows[0][1] == "project"


def test_ghi_project_scope_giu_nguyen_niem_phong(tmp_path, workspace, cau_hinh_rieng):
    """Ghi QUA CỔNG thì store phải được niêm lại, nếu không project.open sẽ báo E6000 oan."""
    root = _du_an(tmp_path, workspace)
    _goi(tmp_path, root, {"op": "set", "key": "probe", "scope": "project", "value": {"value": "stlink"}})
    ok, chi_tiet = store.verify_seal(store.store_path(root))
    assert ok, chi_tiet
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l3.jsonl"))
    assert r.invoke("project.open", {"project": str(root)},
                    Context(project_dir=workspace)).status == "done"
