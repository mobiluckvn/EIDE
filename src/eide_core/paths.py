"""Đường dẫn chuẩn đa nền tảng (PLATFORM.md quy tắc 1; DEP-26).

Spec: docs/spec/ là thư mục đặc tả máy đọc được; cấu hình người dùng qua platformdirs.
"""
from __future__ import annotations

import os
from pathlib import Path

from platformdirs import user_cache_dir, user_config_dir, user_data_dir, user_log_dir

APP = "eide"


def repo_root() -> Path:
    """Gốc kho mã (chứa CLAUDE.md). Cho phép ghi đè bằng EIDE_ROOT khi cài như package."""
    env = os.environ.get("EIDE_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "CLAUDE.md").exists() and (p / "docs" / "spec").exists():
            return p
    return here.parents[2]


def spec_dir() -> Path:
    env = os.environ.get("EIDE_SPEC_DIR")
    return Path(env).expanduser().resolve() if env else repo_root() / "docs" / "spec"


def user_config() -> Path:
    return Path(user_config_dir(APP))


def user_data() -> Path:
    return Path(user_data_dir(APP))


def user_cache() -> Path:
    return Path(user_cache_dir(APP))


def user_log() -> Path:
    return Path(user_log_dir(APP))


def project_dir_default() -> Path:
    """defaults.project_dir trong autonomy.yaml (SDD-04 §6) — mặc định ~/eide."""
    return Path("~/eide").expanduser()


def nap_env() -> list[str]:
    """Nạp `.env` vào `os.environ` — trả tên các biến vừa đặt.

    ## Vì sao cần, và vì sao nó không tự có

    `.env.example` khai `GEMINI_API_KEY` và `ANTHROPIC_API_KEY`; `Gateway` đọc chúng từ
    `os.environ`. Ở giữa hai điều ấy KHÔNG có gì cả — không nơi nào trong mã nạp `.env`. Đo
    16/09/2026 trên máy chủ sản phẩm: `.env` có một khoá Gemini hợp lệ 39 ký tự, `plan.create`
    vẫn trả `E5000 — vai trò planner không có nhà cung cấp nào đã cấu hình`. Khoá nằm trong tệp
    và không bao giờ tới tiến trình; người dùng phải tự `export` mà không gì nói cho họ biết.

    ## Ba ràng buộc, và cả ba đều về an toàn

    1. **Chỉ nạp `.env` ở GỐC KHO**, không nạp ở thư mục dự án. Một dự án tải về từ nơi khác có
       thể mang theo `.env` của người lạ, và nạp nó nghĩa là EIDE gọi mô hình bằng khoá ấy —
       hoặc gửi dữ liệu tới một endpoint do tệp ấy chỉ định.
    2. **KHÔNG ghi đè biến đã có trong môi trường.** Người đã `export` một khoá khác đang cố ý
       làm thế; một tệp trên đĩa không được lặng lẽ thắng lệnh họ vừa gõ.
    3. **Không trả về giá trị, chỉ trả về TÊN.** Hàm này bị gọi ở đường khởi động, và một dòng
       log vô tình in ra danh sách trả về sẽ in cả khoá API. SEC-25 §4 nói khoá không rời tiến
       trình cha; cách chắc nhất là chỗ này không bao giờ cầm chúng dưới dạng trả về.
    """
    f = repo_root() / ".env"
    if not f.exists():
        return []
    dat: list[str] = []
    try:
        noi_dung = f.read_text(encoding="utf-8")
    except OSError:
        return []
    for dong in noi_dung.splitlines():
        s = dong.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        ten, _, gia = s.partition("=")
        ten = ten.removeprefix("export ").strip()
        gia = gia.strip()
        # Bỏ nháy bọc ngoài — người ta hay viết `KEY="giá trị"` theo thói quen shell.
        if len(gia) >= 2 and gia[0] == gia[-1] and gia[0] in "\"'":
            gia = gia[1:-1]
        if not ten or not gia or ten in os.environ:
            continue
        os.environ[ten] = gia
        dat.append(ten)
    return dat
