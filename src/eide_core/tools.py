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


# Homebrew để formula "keg-only" NGOÀI `bin/`, chỉ có dưới `opt/<formula>/bin`. Và loại formula
# bị giữ keg-only nhiều nhất lại đúng là loại EIDE cần: trình dịch chéo có đánh số phiên bản.
#
# Đo 22/09/2026: `brew install avr-gcc@14` báo cài xong, `avrdude` và `avr-size` vào PATH bình
# thường, còn `avr-gcc` thì KHÔNG — Homebrew nói thẳng *"keg-only, vì nó có thể xung đột với
# bản avr-gcc khác"*. Người dùng vừa cài xong một trình dịch, thấy "🍺 installed", rồi EIDE vẫn
# báo `E4001 TOOL_MISSING: avr-gcc`. Lời khuyên của Homebrew là sửa `~/.zshrc`, nhưng daemon
# không đọc `.zshrc`: nó chạy với PATH của tiến trình cha.
#
# Nên phải tìm ở đây. Quét `opt/*/bin` chứ không ghi cứng tên formula: `avr-gcc@14` hôm nay,
# `avr-gcc@15` tháng sau, `arm-none-eabi-gcc` và `riscv64-elf-gcc` cũng cùng kiểu. [DEV-172]
GOC_KEG_ONLY = {"Darwin": ["/opt/homebrew/opt", "/usr/local/opt"], "Linux": [], "Windows": []}


def _duoi_theo_os() -> list[str]:
    return ["", ".exe", ".cmd", ".bat"] if os_name() == "Windows" else [""]


def _chay_duoc(thu_muc: Path, name: str) -> Path | None:
    for ext in _duoi_theo_os():
        f = thu_muc / (name + ext)
        if f.exists() and os.access(f, os.X_OK):
            return f
    return None


def which(name: str) -> Path | None:
    p = shutil.which(name)
    if p:
        return Path(p)
    for d in EXTRA_PATHS.get(os_name(), []):
        if (f := _chay_duoc(Path(d).expanduser(), name)) is not None:
            return f
    # Thư mục keg-only. Sắp NGƯỢC theo tên để `avr-gcc@15` được chọn trước `avr-gcc@9`: khi có
    # nhiều bản cùng tồn tại — chính là tình huống Homebrew giữ chúng keg-only để cho phép —
    # thì bản mới là lựa chọn ít bất ngờ hơn. So chuỗi chứ không so số: `@9` đứng sau `@15` theo
    # thứ tự chuỗi, nên cần một khoá tách phần số ra.
    for goc in GOC_KEG_ONLY.get(os_name(), []):
        thu = Path(goc)
        if not thu.is_dir():
            continue
        for d in sorted(thu.iterdir(), key=_khoa_phien_ban, reverse=True):
            if (f := _chay_duoc(d / "bin", name)) is not None:
                return f
    return None


def _khoa_phien_ban(d: Path) -> tuple[str, tuple[int, ...]]:
    """`avr-gcc@14` → `("avr-gcc", (14,))`; `avr-gcc` → `("avr-gcc", ())`.

    Tách phần số để sắp theo GIÁ TRỊ chứ không theo chữ — `@9` lớn hơn `@15` nếu so chuỗi, và
    chọn nhầm ở đây nghĩa là dựng firmware bằng một trình dịch cũ hơn bản người dùng vừa cài.
    """
    ten, _, ban = d.name.partition("@")
    so = tuple(int(x) for x in re.findall(r"\d+", ban))
    return (ten, so)


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
