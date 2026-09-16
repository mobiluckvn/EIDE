"""Đường dẫn chuẩn và nạp cấu hình môi trường — `eide_core.paths`."""
from __future__ import annotations

import os


def test_nap_env_dat_bien_va_khong_de_lo_gia_tri(tmp_path, monkeypatch):
    """`.env` phải tới được tiến trình — và hàm nạp KHÔNG trả về giá trị.

    Đo 16/09/2026: `.env` của chủ sản phẩm có khoá Gemini hợp lệ 39 ký tự, `plan.create` vẫn trả
    E5000 "không có nhà cung cấp nào đã cấu hình". `Gateway` đọc `os.environ`, `.env.example`
    khai tên biến, và giữa hai điều ấy không có gì cả.
    """
    from eide_core import paths

    (tmp_path / "CLAUDE.md").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "spec").mkdir(parents=True)
    (tmp_path / ".env").write_text(
        '# ghi chú\nGEMINI_API_KEY=abc123\nexport CO_NHAY="xin chào"\nTRONG=\nHONG\n',
        encoding="utf-8")
    monkeypatch.setenv("EIDE_ROOT", str(tmp_path))
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("CO_NHAY", raising=False)

    dat = paths.nap_env()
    assert set(dat) == {"GEMINI_API_KEY", "CO_NHAY"}, "dòng rỗng và dòng thiếu `=` phải bị bỏ"
    assert os.environ["GEMINI_API_KEY"] == "abc123"
    assert os.environ["CO_NHAY"] == "xin chào", "bỏ nháy bọc ngoài và tiền tố `export`"
    # Trả về TÊN, không trả giá trị: một dòng log vô tình in danh sách ấy sẽ in cả khoá API.
    assert all("abc123" not in x for x in dat)


def test_nap_env_KHONG_ghi_de_bien_da_co(tmp_path, monkeypatch):
    """Người đã `export` một khoá khác đang CỐ Ý làm thế.

    Một tệp trên đĩa không được lặng lẽ thắng lệnh họ vừa gõ — đó là cách một khoá cũ quay lại
    mà không ai hiểu vì sao.
    """
    from eide_core import paths

    (tmp_path / "CLAUDE.md").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "spec").mkdir(parents=True)
    (tmp_path / ".env").write_text("GEMINI_API_KEY=trong_tep\n", encoding="utf-8")
    monkeypatch.setenv("EIDE_ROOT", str(tmp_path))
    monkeypatch.setenv("GEMINI_API_KEY", "nguoi_dung_tu_dat")

    assert paths.nap_env() == []
    assert os.environ["GEMINI_API_KEY"] == "nguoi_dung_tu_dat"


def test_nap_env_KHONG_nap_env_cua_thu_muc_du_an(tmp_path, monkeypatch):
    """Chỉ nạp `.env` ở GỐC KHO.

    Một dự án tải về từ nơi khác có thể mang theo `.env` của người lạ; nạp nó nghĩa là EIDE gọi
    mô hình bằng khoá ấy, hoặc gửi dữ liệu tới một endpoint do tệp ấy chỉ định.
    """
    from eide_core import paths

    kho = tmp_path / "kho"
    (kho / "docs" / "spec").mkdir(parents=True)
    (kho / "CLAUDE.md").write_text("x", encoding="utf-8")
    du_an = tmp_path / "du-an-tai-ve"
    du_an.mkdir()
    (du_an / ".env").write_text("KHOA_LA=nguy_hiem\n", encoding="utf-8")
    monkeypatch.setenv("EIDE_ROOT", str(kho))
    monkeypatch.chdir(du_an)
    monkeypatch.delenv("KHOA_LA", raising=False)

    assert paths.nap_env() == []
    assert "KHOA_LA" not in os.environ
