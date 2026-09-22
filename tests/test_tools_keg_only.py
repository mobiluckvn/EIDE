"""[DEV-172] `tools.which` phải tìm được chuỗi công cụ Homebrew để NGOÀI PATH.

Homebrew giữ formula "keg-only" ngoài `bin/`, chỉ có dưới `opt/<formula>/bin`. Và loại bị giữ
keg-only nhiều nhất lại đúng loại EIDE cần: trình dịch chéo có đánh số phiên bản.

Đo 22/09/2026 sau khi cài `avr-gcc@14` trên máy chủ sản phẩm: `avrdude` và `avr-size` vào PATH
bình thường, `avr-gcc` thì KHÔNG. Người dùng thấy `🍺 installed`, rồi EIDE vẫn báo
`E4001 TOOL_MISSING: avr-gcc` — và lời khuyên sửa `~/.zshrc` của Homebrew không cứu được
daemon, vì daemon chạy với PATH của tiến trình cha chứ không đọc `.zshrc`.

PLATFORM.md quy tắc 2 đặt `tools.which()` làm cổng duy nhất ra công cụ ngoài, nên đây là chỗ
đúng để sửa — một lần cho mọi ISA, thay vì mỗi năng lực tự đoán đường dẫn.
"""
from __future__ import annotations

import os
import stat
from pathlib import Path

import pytest

from eide_core import tools


def _exe(thu_muc, ten):
    thu_muc.mkdir(parents=True, exist_ok=True)
    f = thu_muc / ten
    f.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    f.chmod(f.stat().st_mode | stat.S_IXUSR)
    return f


@pytest.fixture
def kho_gia(tmp_path, monkeypatch):
    """Một cây Homebrew giả: `bin/` và `opt/<formula>/bin/`."""
    monkeypatch.setattr(tools, "os_name", lambda: "Darwin")
    monkeypatch.setattr(tools, "EXTRA_PATHS", {"Darwin": [str(tmp_path / "bin")]})
    monkeypatch.setattr(tools, "GOC_KEG_ONLY", {"Darwin": [str(tmp_path / "opt")]})
    # PATH sạch: phép đo phải nói về hai thư mục trên, không về máy đang chạy test.
    monkeypatch.setenv("PATH", str(tmp_path / "trong"))
    return tmp_path


def test_tim_duoc_cong_cu_keg_only(kho_gia):
    """Phép đo trung tâm: trước bản vá, hàm này trả None cho một trình dịch đã cài xong."""
    _exe(kho_gia / "opt" / "avr-gcc@14" / "bin", "avr-gcc")
    assert tools.which("avr-gcc") == kho_gia / "opt" / "avr-gcc@14" / "bin" / "avr-gcc"


def test_ban_MOI_thang_khi_nhieu_ban_cung_ton_tai(kho_gia):
    """Nhiều bản cùng tồn tại CHÍNH LÀ lý do Homebrew giữ chúng keg-only, nên đây không phải
    trường hợp hiếm. Chọn nhầm nghĩa là dựng firmware bằng trình dịch cũ hơn bản vừa cài.

    Và phải so theo GIÁ TRỊ SỐ: `@9` lớn hơn `@15` nếu so chuỗi.
    """
    for v in ("9", "14", "15"):
        _exe(kho_gia / "opt" / f"avr-gcc@{v}" / "bin", "avr-gcc")
    assert tools.which("avr-gcc").parent.parent.name == "avr-gcc@15"


def test_PATH_van_thang_thu_muc_keg_only(kho_gia):
    """Bản trên PATH là bản người dùng CHỌN. Một thư mục `opt/` đè lên nó là EIDE tự ý đổi
    trình dịch sau lưng người dùng."""
    tren_path = _exe(kho_gia / "bin", "avr-gcc")
    _exe(kho_gia / "opt" / "avr-gcc@15" / "bin", "avr-gcc")
    assert tools.which("avr-gcc") == tren_path


def test_khong_co_thi_van_tra_None(kho_gia):
    _exe(kho_gia / "opt" / "avr-gcc@14" / "bin", "avr-gcc")
    assert tools.which("cong-cu-khong-ton-tai") is None


def test_tep_khong_chay_duoc_khong_tinh(kho_gia):
    """Một tệp cùng tên mà không có cờ thi hành là một tệp khác, không phải công cụ."""
    d = kho_gia / "opt" / "avr-gcc@14" / "bin"
    d.mkdir(parents=True)
    (d / "avr-gcc").write_text("đây là ghi chú, không phải chương trình", encoding="utf-8")
    assert tools.which("avr-gcc") is None


def test_thu_muc_goc_khong_ton_tai_thi_khong_no(kho_gia, monkeypatch):
    """Máy không có Homebrew — `/opt/homebrew/opt` không tồn tại. Phải trả None, không ném."""
    monkeypatch.setattr(tools, "GOC_KEG_ONLY",
                        {"Darwin": [str(kho_gia / "khong-he-co")]})
    assert tools.which("avr-gcc") is None


def test_khoa_phien_ban(tmp_path):
    assert tools._khoa_phien_ban(Path("/x/avr-gcc@14")) == ("avr-gcc", (14,))
    assert tools._khoa_phien_ban(Path("/x/avr-gcc")) == ("avr-gcc", ())
    assert tools._khoa_phien_ban(Path("/x/python@3.14")) == ("python", (3, 14))
    # Sắp đúng: không bản nào "@9" chen lên trước "@15".
    ds = [Path(f"/x/avr-gcc@{v}") for v in ("9", "15", "14")]
    assert [p.name for p in sorted(ds, key=tools._khoa_phien_ban, reverse=True)] == [
        "avr-gcc@15", "avr-gcc@14", "avr-gcc@9"]


@pytest.mark.skipif(not Path("/opt/homebrew/opt").is_dir(),
                    reason="cần Homebrew trên máy đang chạy")
def test_tren_may_that_tim_duoc_avr_gcc():
    """Phép đo trên MÁY THẬT — thứ duy nhất trả lời được câu "cài xong thì EIDE thấy chưa".

    Bỏ qua khi không có Homebrew thay vì đỏ: đây là phép đo môi trường, và một cổng đỏ vì máy
    CI không cài brew là một cổng người ta tắt đi.
    """
    p = tools.which("avr-gcc")
    if p is None:
        pytest.skip("máy này chưa cài avr-gcc")
    assert p.exists() and os.access(p, os.X_OK)
