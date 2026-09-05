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
