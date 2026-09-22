"""[DEV-179] Ba trên bốn mẫu chuỗi lớn của sản phẩm không bao giờ chạy được.

Đo 22/09/2026: chủ sản phẩm gõ thẳng vào app một câu mô tả việc CNC LAN→USB. Ý định
`project.create` → mẫu Z-01 "Dự án mới từ ý tưởng" → E5002 *"14 nút vượt ngưỡng 12"*.

Tác tử chọn ĐÚNG mẫu, rồi phép kiểm deterministic bác bỏ chính mẫu của mình.
"""
from __future__ import annotations

import json

from eide_core import chain as chain_mod
from eide_core.paths import spec_dir


def _mau():
    d = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    return d if isinstance(d, list) else (d.get("chains") or [])


def test_moi_mau_chuoi_deu_vua_NGUONG_MAC_DINH():
    """Phép đo trung tâm: một mẫu mà sản phẩm ship kèm mà chính nó từ chối chạy là một mẫu
    chết. Ngưỡng phải phủ được MẪU DÀI NHẤT, nếu không thì nó không phải ngưỡng an toàn — nó
    là một lỗi chờ người dùng gõ đúng câu để lộ ra."""
    qua = [(c["ten"], len(c.get("nodes") or [])) for c in _mau()
           if len(c.get("nodes") or []) > chain_mod.TRAN_NUT]
    assert qua == [], f"mẫu vượt TRAN_NUT={chain_mod.TRAN_NUT}: {qua}"


def test_nguong_KHONG_con_lay_tu_plan_max_steps():
    """`plan_max_steps` (POL-17 §2 G1-01, mặc định 12) là ngưỡng của KẾ HOẠCH KỸ THUẬT — danh
    sách bước một con người ngồi duyệt; PRS-16 §4 còn cấm planner chia quá 12 bước vì lý do ấy.
    Chuỗi là ĐỒ THỊ ĐIỀU PHỐI nội bộ: người dùng không đọc nó.

    Đây là phép đo giữ bản sửa — dùng lại `plan_max_steps` thì bài này đỏ."""
    from pathlib import Path
    van = Path("src/eide/caps/chat.py").read_text(encoding="utf-8")
    i = van.index("thieu_du_kien = chain_mod.kiem(")
    assert "plan_max_steps" not in van[i - 400:i + 300]


def test_Z01_dung_duoc_duoi_nguong_moi():
    """Z-01 là mẫu cho câu mô tả một việc mới từ ý tưởng — đúng thứ chủ sản phẩm vừa gõ."""
    z01 = next(c for c in _mau() if c["ten"].startswith("Dự án mới từ ý tưởng"))
    assert len(z01["nodes"]) == 14
    assert len(z01["nodes"]) <= chain_mod.TRAN_NUT


def test_nguong_van_chan_duoc_chuoi_chay_loan():
    """Ngưỡng vẫn phải là ngưỡng: một chuỗi 100 nút do mô hình sinh loạn phải bị chặn."""
    from eide_core.errors import EideError
    from eide_core.registry import get_registry
    c = chain_mod.Chain(nodes=[chain_mod.Nut(id=f"n{i}", cap="view.artifacts",
                                             args={"kind": "requirement"})
                               for i in range(chain_mod.TRAN_NUT + 5)])
    try:
        chain_mod.kiem(c, get_registry(), tran_nut=chain_mod.TRAN_NUT)
    except EideError as e:
        assert "vượt ngưỡng" in str(e)
    else:
        raise AssertionError("chuỗi quá dài phải bị chặn")
