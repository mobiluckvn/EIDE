"""Tìm công cụ ngoài đa nền tảng (PLATFORM.md quy tắc 2; TGT-19 §toolchain; ENV-* trong CDS-12.3)."""
from __future__ import annotations

import os
import platform
import re
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


# Cờ hỏi phiên bản, theo thứ tự thử. `--version` là quy ước GNU và đúng với gần hết chuỗi công
# cụ; `-v` là của avrdude và vài công cụ nhúng khác.
#
# `-V` KHÔNG có trong danh sách dù nó là quy ước BSD: với avrdude, `-V` nghĩa là **bỏ qua bước
# verify sau khi ghi**. Thử một cờ đoán chừng trên công cụ nạp firmware là đúng loại việc không
# được phép làm, kể cả khi lần này nó vô hại vì không có `-U` đi kèm.
CO_PHIEN_BAN: tuple[tuple[str, ...], ...] = (("--version",), ("-v",), ("version",))

# Một dòng phiên bản có số dạng `7.3` hoặc `8.0-arduino.1`. Dùng để NHẬN DẠNG, không chỉ để
# trích: công cụ không hiểu cờ vẫn in ra một dòng, và phải phân biệt được dòng ấy với dòng thật.
_SO_PHIEN_BAN = re.compile(r"\b\d+\.\d+")


def version_of(exe: Path, args: tuple[str, ...] | None = None,
               timeout: float = 10) -> str | None:
    """Dòng phiên bản của một công cụ, hoặc None nếu không hỏi được.

    **Mã thoát không phải tín hiệu, nội dung mới là.** Đo trên avrdude 8 (14/09/2026):
    `--version` trả mã **0** kèm `"…/avrdude: illegal option -- -"`, còn `-v` trả mã **1** kèm
    đúng `"Avrdude version 8.0-arduino.1"`. Lọc theo mã thoát thì nhận chuỗi rác và bỏ chuỗi
    thật — ngược hẳn. Nên phép chọn là: thử từng cờ, lấy dòng ĐẦU TIÊN trông như một dòng
    phiên bản sau khi đã bỏ các từ là đường dẫn.

    Trước hôm nay hàm trả thẳng dòng đầu của stdout/stderr. Hệ quả đo được: `env.check` ghi
    `version` là thông báo lỗi kia và vẫn kết luận `ok: true`, vì `_ver_ok` tìm thấy `8.0.0`
    trong ĐƯỜNG DẪN nằm trong chính thông báo ấy. Lần đó con số tình cờ đúng; lần sau ai cài
    một avrdude cũ vào thư mục tên `8.0.0` thì nó vẫn "đạt". Xem DEV-106.
    """
    for co in ((args,) if args else CO_PHIEN_BAN):
        try:
            out = subprocess.run([str(exe), *co], capture_output=True, text=True,
                                 timeout=timeout, check=False)
        except (OSError, subprocess.TimeoutExpired):
            return None
        for dong in ((out.stdout or "") + "\n" + (out.stderr or "")).splitlines():
            sach = " ".join(w for w in dong.split() if "/" not in w and "\\" not in w)
            if _SO_PHIEN_BAN.search(sach):
                return dong.strip()
    return None


# Bộ công cụ EIDE quan tâm trên mọi nền tảng: `eide doctor` báo cáo, `env.lock` khóa phiên bản.
# Đặt ở lõi chứ không ở CLI vì năng lực (`env.lock`) cũng cần — một năng lực import CLI là
# đảo ngược tầng: lõi không được biết gì về giao diện.
COMMON_TOOLS: list[tuple[str, bool]] = [
    ("git", True), ("python3", True), ("node", False), ("cmake", False), ("ninja", False),
    ("arm-none-eabi-gcc", False), ("avr-gcc", False), ("probe-rs", False),
    ("openocd", False), ("renode", False),
]
