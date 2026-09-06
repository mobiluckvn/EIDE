"""Tìm công cụ ngoài đa nền tảng (PLATFORM.md quy tắc 2; TGT-19 §toolchain; ENV-* trong CDS-12.3)."""
from __future__ import annotations

import os
import platform
import shutil
import subprocess
from pathlib import Path

EXTRA_PATHS = {
    "Darwin": ["/opt/homebrew/bin", "/usr/local/bin", "~/.cargo/bin", "/Applications/ARM/bin"],
    "Windows": ["C:/Program Files/Git/bin", "~/.cargo/bin", "C:/ProgramData/chocolatey/bin"],
    "Linux": ["/usr/local/bin", "~/.local/bin", "~/.cargo/bin", "/snap/bin"],
}


def os_name() -> str:
    return platform.system()  # Darwin | Windows | Linux


def arch() -> str:
    return platform.machine()  # arm64 | x86_64 | AMD64


def which(name: str) -> Path | None:
    p = shutil.which(name)
    if p:
        return Path(p)
    for d in EXTRA_PATHS.get(os_name(), []):
        cand = Path(d).expanduser() / name
        for ext in ([""] if os_name() != "Windows" else ["", ".exe", ".cmd", ".bat"]):
            f = cand.with_name(cand.name + ext)
            if f.exists() and os.access(f, os.X_OK):
                return f
    return None


def version_of(exe: Path, args: tuple[str, ...] = ("--version",), timeout: float = 10) -> str | None:
    try:
        out = subprocess.run([str(exe), *args], capture_output=True, text=True, timeout=timeout, check=False)
        line = (out.stdout or out.stderr).strip().splitlines()
        return line[0] if line else None
    except (OSError, subprocess.TimeoutExpired):
        return None


# Bộ công cụ EIDE quan tâm trên mọi nền tảng: `eide doctor` báo cáo, `env.lock` khóa phiên bản.
# Đặt ở lõi chứ không ở CLI vì năng lực (`env.lock`) cũng cần — một năng lực import CLI là
# đảo ngược tầng: lõi không được biết gì về giao diện.
COMMON_TOOLS: list[tuple[str, bool]] = [
    ("git", True), ("python3", True), ("node", False), ("cmake", False), ("ninja", False),
    ("arm-none-eabi-gcc", False), ("avr-gcc", False), ("probe-rs", False),
    ("openocd", False), ("renode", False),
]
