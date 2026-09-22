"""[DEV-178] Nút chuỗi HỎNG kèm lời khuyên dùng được cũng phải lên tab Làm rõ yêu cầu.

[DEV-160] đưa câu hỏi của nút ASK về tab S9, nhưng chỉ nhánh ấy. Đo 22/09/2026 trên bài CNC
chạy qua giao diện: chuỗi "Vẽ lược đồ" chạy `view.artifacts(module)` → 0 mục →
`diagram.architecture` hỏng với *"Chưa có module nào — chạy `arch.decompose` trước"*.

Thông điệp ấy ĐÚNG và DÙNG ĐƯỢC NGAY. Nhưng store của dự án khi ấy có 4 điểm cần làm rõ —
`req.detect_conflict` ×3 và `arch.style_select` ×1 — và KHÔNG cái nào là nó. Người dùng đóng
cửa sổ trò chuyện, mở tab, và thứ đang chặn họ không có ở đó.
"""
from __future__ import annotations

import pytest

from eide.caps.chat import _ghi_loi_chan_chuoi
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


class _Nut:
    def __init__(self, cap): self.cap, self.id = cap, "n2"


@pytest.fixture
def root(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "cổng LAN sang USB"},
                   Context(project_dir=workspace)).result
    d = workspace / res["project_id"]
    store.migrate(store.store_path(d), ledger=r.ledger)
    return d


def _ds(root):
    with store.open_store(store.store_path(root)) as c:
        return c.execute("SELECT text, suggestion, source_cap, status FROM clarification").fetchall()


def test_loi_co_duong_ra_len_tab(root):
    """Phép đo trung tâm: nguyên văn lỗi đã gặp trên bài CNC."""
    _ghi_loi_chan_chuoi(root, "r_abcdef1234", _Nut("diagram.architecture"), {
        "eide_code": "E2000",
        "message": "Chưa có module nào — chạy `arch.decompose` trước; sơ đồ kiến trúc phải vẽ "
                   "từ ModuleGraph có thật, không đoán",
        "candidates": ["arch.decompose"]})
    ds = _ds(root)
    assert len(ds) == 1, ds
    assert "arch.decompose" in ds[0][0] and ds[0][2] == "diagram.architecture"
    assert ds[0][3] == "open"


def test_noi_ro_chay_NANG_LUC_nao(root):
    """`candidates` của E2000 là danh sách năng lực chạy được tiếp. Nói ra thì người dùng khỏi
    phải đọc ngược thông điệp để đoán."""
    _ghi_loi_chan_chuoi(root, "r_abcdef1234", _Nut("diagram.architecture"), {
        "eide_code": "E2000", "message": "Chưa có module nào",
        "candidates": ["arch.decompose", "arch.map_hw"]})
    g = _ds(root)[0][1]
    assert "`arch.decompose`" in g and "`arch.map_hw`" in g and "r_abcdef12" in g


def test_loi_KHONG_co_duong_ra_thi_khong_ghi(root):
    """E5002 (mô hình trả sai schema) là chuyện của máy. Đưa nó lên tab "Làm rõ yêu cầu" là
    biến chỗ ấy thành sọt rác lỗi, và một tab đầy thứ không hành động được là tab người ta
    thôi mở."""
    for ma in ("E5000", "E5002", "E7001", "E1000"):
        _ghi_loi_chan_chuoi(root, "r_1", _Nut("x.y"), {"eide_code": ma, "message": "hỏng"})
    assert _ds(root) == []


def test_thieu_cong_cu_va_store_cu_CO_duong_ra(root):
    """E4001 nói thiếu công cụ gì và `remedy` là `env.install`; E6003 nói chạy `eide migrate`.
    Cả hai đều là việc làm được ngay."""
    _ghi_loi_chan_chuoi(root, "r_1", _Nut("code.build"),
                        {"eide_code": "E4001", "message": "Thiếu avr-gcc để dựng avr8"})
    _ghi_loi_chan_chuoi(root, "r_1", _Nut("project.open"),
                        {"eide_code": "E6003", "message": "store user_version=9, cần 10"})
    assert len(_ds(root)) == 2


def test_thong_diep_rong_thi_khong_ghi_dong_trong(root):
    _ghi_loi_chan_chuoi(root, "r_1", _Nut("x.y"), {"eide_code": "E2000", "message": ""})
    _ghi_loi_chan_chuoi(root, "r_1", _Nut("x.y"), {})
    assert _ds(root) == []


def test_lap_lai_khong_de_ra_ban_sao(root):
    """Mã điểm cần làm rõ băm theo NỘI DUNG ([DEV-151]), nên chạy lại chuỗi ba lần vẫn một dòng."""
    for _ in range(3):
        _ghi_loi_chan_chuoi(root, "r_1", _Nut("diagram.architecture"),
                            {"eide_code": "E2000", "message": "Chưa có module nào"})
    assert len(_ds(root)) == 1
