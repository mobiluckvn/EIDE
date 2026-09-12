"""Sandbox — chạy công cụ ngoài dưới giới hạn tài nguyên và cách ly. WI-009.

Spec: SEC-25 §2 (giới hạn, thư mục tạm, môi trường tối thiểu, sandbox-exec/bwrap, ghi ledger
mức cách ly), §3 (khóa không bao giờ ra khỏi tiến trình cha), §5 (lệnh cài là ngoại lệ duy
nhất có mạng); CDS-12.3 ENV-07; STP-05 TC-SE-03; API-15 E8000, E4004.

Nguyên tắc: sandbox KHÔNG hứa nhiều hơn thứ nó làm được. Mức cách ly đạt được được ghi vào
ledger mỗi lần chạy — kể cả khi đạt mức cao nhất — vì người đọc nhật ký cần biết lệnh này chạy
dưới lớp bảo vệ nào, chứ không phải suy ra từ chỗ vắng một dòng.

Đo trên macOS 26 (arm64), 06/09/2026:
  sandbox-exec  có sẵn ở /usr/bin, và CHẶN MẠNG THẬT (socket → PermissionError, đối chứng
                không sandbox thì kết nối được).
  RLIMIT_CPU    hoạt động (SIGXCPU).
  RLIMIT_FSIZE  hoạt động (Errno 27).
  RLIMIT_NOFILE hoạt động (Errno 24).
  RLIMIT_AS     KHÔNG DÙNG ĐƯỢC — đặt ở bất kỳ giá trị nào (thử cả 2 GB) đều làm hỏng chính
                lời gọi exec, vì Python trên macOS đặt trước một vùng địa chỉ rất lớn. Giới hạn
                RAM 1 GB của SEC-25 §2 vì thế được canh bằng RSS ở tiến trình cha. Xem DEV-017.
"""
from __future__ import annotations

import os
import platform
import resource
import shutil
import subprocess
import tempfile
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.ledger import Ledger

# Theo thứ tự bảo vệ giảm dần. `rlimit` là mức lui cuối cùng của SEC-25 §2.
MUC_CACH_LY = ("sandbox-exec", "bwrap", "rlimit")

# SEC-25 §2: "CPU 60 s, RAM 1 GB, tệp mở 256, kích thước ghi 2 GB; wall-clock 300 s".
GIOI_HAN_MAC_DINH: dict[str, int] = {
    "cpu_s": 60,
    "rss_mb": 1024,
    "nofile": 256,
    "fsize_b": 2 * 1024**3,
    "wall_s": 300,
}

# Môi trường được DỰNG LẠI chứ không lọc bớt: lọc bớt là một danh sách đen, và danh sách đen
# nào cũng thiếu một tên. SEC-25 §3 — khóa không bao giờ rời tiến trình cha.
PATH_HE_THONG = "/usr/bin:/bin:/usr/sbin:/sbin"


@dataclass
class KetQua:
    exit_code: int
    stdout_ref: str
    stderr_ref: str
    violations: list[str] = field(default_factory=list)
    isolation: str = "rlimit"
    duration_ms: int = 0


@dataclass
class Sandbox:
    out_dir: Path
    ledger: Ledger | None = None

    def run(self, cmd: list[str], *, limits: dict[str, Any] | None = None,
            allowed_dirs: list[str] | None = None, network: bool = False,
            cwd: str | Path | None = None, them_path: list[str] | None = None) -> KetQua:
        """Chạy `cmd` cách ly. `cwd` mặc định là một thư mục tạm riêng của lần chạy.

        **`cwd` chỉ nhận thư mục ĐÃ nằm trong `allowed_dirs`.** Không có ràng buộc ấy thì tham số
        này là một lối vòng qua chính SEC-25 §2: người gọi chdir vào bất cứ đâu rồi đọc ghi bằng
        đường dẫn tương đối. Có ràng buộc thì nó không cấp thêm quyền nào — chỉ đổi chỗ đứng
        trong phạm vi quyền đã cấp.

        Vì sao cần: `toolchain.build.cmd` của TGT-19 viết `cmake -S . -B build`, và `artifact`
        thì khai `build/*.elf` — cả hai là đường dẫn TƯƠNG ĐỐI so với gốc dự án. Chạy ở thư mục
        tạm thì `.` là một thư mục rỗng, và `cmake` báo "does not appear to contain
        CMakeLists.txt" — một câu đúng về chỗ nó đang đứng và vô nghĩa với người đọc. Xem
        DEVIATIONS DEV-085, phương án (a).
        """
        if not cmd or not isinstance(cmd, list):
            raise EideError("E1000", "cmd phải là danh sách chuỗi (không dùng shell)")
        # Khóa lạ trong `limits` là LỖI, không phải thứ bỏ qua.
        #
        # Trước khi có phép kiểm này, bảy chỗ gọi trong `code.*`, `env.install` và
        # `extract.*` truyền `{"timeout_s": ...}` — một tên không có trong bảng — nên
        # `TIMEOUT_DUNG = 600`, `TIMEOUT_CAI = 900` và `TIMEOUT_TEST = 120` KHÔNG có tác dụng
        # nào cả: mọi lệnh đều chạy dưới hạn mặc định 300 s. `brew install gcc-arm-embedded`
        # vì thế bị giết giữa chừng ở phút thứ năm, và triệu chứng là E4004 "quá thời gian
        # 300 s" cho một lệnh mà mã nguồn nói rõ là được 900 s. Gộp im lặng làm một hằng số
        # trông như đang có hiệu lực, và không test nào thấy vì không test nào chạy đủ lâu.
        if (la := sorted(set(limits or {}) - set(GIOI_HAN_MAC_DINH))):
            raise EideError("E1000", f"Giới hạn không có trong SEC-25 §2: {la} — "
                            f"chỉ nhận {sorted(GIOI_HAN_MAC_DINH)}", extra=la)
        gh = {**GIOI_HAN_MAC_DINH, **(limits or {})}
        doc_duoc = _kiem_allowed_dirs(allowed_dirs or [])

        out = Path(self.out_dir)
        out.mkdir(parents=True, exist_ok=True)
        # Thư mục làm việc TẠM RIÊNG mỗi lần chạy (SEC-25 §2): công cụ ngoài không được thấy
        # thư mục dự án, và hai lần chạy không được giẫm lên nhau.
        tam = Path(tempfile.mkdtemp(prefix="eide-sandbox-", dir=out))
        f_out = out / f"{tam.name}.stdout.txt"
        f_err = out / f"{tam.name}.stderr.txt"
        lam_viec = _kiem_cwd(cwd, doc_duoc) if cwd is not None else tam

        muc, lenh = self._boc(cmd, lam_viec, doc_duoc, network, ho_so_o=tam)
        vi_pham: list[str] = []
        t0 = time.perf_counter()
        with f_out.open("wb") as fo, f_err.open("wb") as fe:
            p = subprocess.Popen(lenh, cwd=lam_viec, stdout=fo, stderr=fe,  # noqa: S603 — cmd dạng danh sách
                                 env=_moi_truong(them_path), preexec_fn=_dat_gioi_han(gh))
            canh = _CanhRSS(p.pid, gh["rss_mb"])
            canh.start()
            try:
                rc = p.wait(timeout=gh["wall_s"])
            except subprocess.TimeoutExpired as e:
                canh.stop()
                _giet(p)
                self._log(cmd, muc, network, -1, ["wall"], t0)
                raise EideError("E4004", f"Quá thời gian {gh['wall_s']} s: {cmd[0]}",
                                violations=["wall"], stdout_ref=str(f_out),
                                stderr_ref=str(f_err)) from e
            finally:
                canh.stop()

        if canh.vuot:
            vi_pham.append("rss")
        # Mã thoát âm = bị tín hiệu. SIGXCPU(24) và SIGXFSZ(25) là chính giới hạn của ta.
        if rc == -24:
            vi_pham.append("cpu")
        err = f_err.read_text(encoding="utf-8", errors="replace")
        if rc == -25 or "Errno 27" in err or "File too large" in err:
            vi_pham.append("fsize")
        if "Errno 24" in err or "Too many open files" in err:
            vi_pham.append("nofile")

        kq = KetQua(exit_code=rc, stdout_ref=str(f_out), stderr_ref=str(f_err),
                    violations=vi_pham, isolation=muc,
                    duration_ms=int((time.perf_counter() - t0) * 1000))
        self._log(cmd, muc, network, rc, vi_pham, t0)
        return kq

    # ---- nội bộ
    def _boc(self, cmd: list[str], cwd: Path, doc_duoc: list[Path],
             network: bool, *, ho_so_o: Path | None = None) -> tuple[str, list[str]]:
        """Chọn mức cách ly cao nhất có trên máy này (SEC-25 §2).

        `ho_so_o` là nơi ĐẶT tệp hồ sơ sandbox, tách khỏi `cwd`: khi người gọi chỉ định `cwd` là
        gốc dự án thì viết `.eide-sandbox.sb` vào đó là rải rác tệp nội bộ của EIDE vào cây mã
        của người dùng — và tệ hơn, một tệp mà `git status` sẽ hỏi.
        """
        if platform.system() == "Darwin" and shutil.which("sandbox-exec"):
            hs = (ho_so_o or cwd) / ".eide-sandbox.sb"
            hs.write_text(_ho_so_macos(cwd, doc_duoc, network), encoding="utf-8")
            return "sandbox-exec", ["/usr/bin/sandbox-exec", "-f", str(hs), *cmd]
        if platform.system() == "Linux" and shutil.which("bwrap"):
            arg = ["bwrap", "--ro-bind", "/usr", "/usr", "--ro-bind", "/bin", "/bin",
                   "--ro-bind", "/lib", "/lib", "--proc", "/proc", "--dev", "/dev",
                   "--bind", str(cwd), str(cwd), "--chdir", str(cwd), "--die-with-parent"]
            for d in doc_duoc:
                arg += ["--ro-bind", str(d), str(d)]
            if not network:
                arg += ["--unshare-net"]
            return "bwrap", [*arg, *cmd]
        return "rlimit", list(cmd)

    def _log(self, cmd: list[str], muc: str, network: bool, rc: int,
             vi_pham: list[str], t0: float) -> None:
        if self.ledger is None:
            return
        self.ledger.append("tool.report", {
            "tool": cmd[0], "passed": rc == 0 and not vi_pham,
            "isolation": muc, "network": network, "violations": vi_pham,
            "exit_code": rc, "duration_ms": int((time.perf_counter() - t0) * 1000)})


def _moi_truong(them_path: list[str] | None = None) -> dict[str, str]:
    """Môi trường tối thiểu — dựng lại từ đầu (SEC-25 §2, §3).

    `HOME` trỏ vào thư mục tạm hệ thống chứ không vào thư mục nhà thật: công cụ ngoài không đọc
    thấy `~/.ssh`, `~/.aws`, `~/.config` của người dùng. Nó phải GHI ĐƯỢC — `brew` tạo
    `$HOME/Library` ngay đầu mỗi lệnh — và hồ sơ sandbox mở quyền ghi cho đúng thư mục ấy.

    **`them_path` — vì sao PATH tối thiểu không đủ cho một bản dựng.** SEC-25 §3 dựng lại `PATH`
    thành `/usr/bin:/bin:/usr/sbin:/sbin`, và chuỗi công cụ nhúng thì không nằm ở đó: Homebrew ở
    `/opt/homebrew/bin`, `~/.cargo/bin`, `/usr/local/bin`. Giải `argv[0]` thành đường dẫn tuyệt
    đối chữa được lệnh ĐẦU TIÊN, nhưng không chữa được việc **công cụ tự gọi công cụ**: `cmake`
    tìm `ninja` qua PATH và báo "unable to find a build program corresponding to Ninja", `make`
    tìm `gcc` cũng thế. Không có tham số này thì `code.build` không thể thành công trên bất kỳ
    máy nào có toolchain ngoài bốn thư mục hệ thống — tức trên mọi máy macOS.

    Bên gọi truyền vào ĐÚNG thư mục của những công cụ mà manifest ISA khai và `env.check` đã tìm
    thấy, không truyền cả `PATH` của người dùng: khác nhau giữa "cho phép chạy chuỗi công cụ đã
    khai" và "cho phép chạy bất cứ thứ gì người dùng từng cài".
    """
    duong = PATH_HE_THONG
    if them_path:
        # Thư mục của công cụ đứng TRƯỚC, nhưng trùng lặp thì bỏ: một PATH dài không sai, nhưng
        # nó làm nhật ký khó đọc và làm phép so trong test thành phụ thuộc thứ tự cài đặt.
        rieng = [d for d in dict.fromkeys(them_path) if d and d not in PATH_HE_THONG.split(os.pathsep)]
        duong = os.pathsep.join([*rieng, PATH_HE_THONG])
    return {"PATH": duong, "HOME": tempfile.gettempdir(), "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8", "TMPDIR": tempfile.gettempdir()}


def _dat_gioi_han(gh: dict[str, Any]):
    def dat() -> None:
        resource.setrlimit(resource.RLIMIT_CPU, (gh["cpu_s"], gh["cpu_s"]))
        resource.setrlimit(resource.RLIMIT_NOFILE, (gh["nofile"], gh["nofile"]))
        resource.setrlimit(resource.RLIMIT_FSIZE, (gh["fsize_b"], gh["fsize_b"]))
        # KHÔNG đặt RLIMIT_AS: trên macOS nó làm hỏng chính lời gọi exec ở mọi giá trị
        # (đã đo 06/09/2026). RAM được canh bằng RSS ở tiến trình cha — xem `_CanhRSS`.
    return dat


class _CanhRSS(threading.Thread):
    """Canh RAM bằng RSS vì RLIMIT_AS không dùng được trên macOS (DEV-017).

    Canh ở tiến trình CHA: tiến trình con không tự giới hạn được mình một cách đáng tin, và
    một công cụ ngoài đang ăn hết RAM là đúng thứ ta không muốn nhờ nó tự dừng.
    """

    def __init__(self, pid: int, rss_mb: int, chu_ky_s: float = 0.2) -> None:
        super().__init__(daemon=True)
        self.pid, self.tran, self.chu_ky = pid, rss_mb * 1024, chu_ky_s
        self.vuot = False
        self._dung = threading.Event()

    def stop(self) -> None:
        self._dung.set()

    def run(self) -> None:
        while not self._dung.wait(self.chu_ky):
            kb = _rss_kb(self.pid)
            if kb is None:
                return
            if kb > self.tran:
                self.vuot = True
                try:
                    os.kill(self.pid, 9)
                except ProcessLookupError:
                    pass
                return


def _rss_kb(pid: int) -> int | None:
    try:
        r = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)],  # noqa: S603, S607
                           capture_output=True, text=True, timeout=5)
        t = r.stdout.strip()
        return int(t) if t else None
    except (subprocess.SubprocessError, ValueError):
        return None


def _giet(p: subprocess.Popen) -> None:
    p.kill()
    try:
        p.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass


def _kiem_allowed_dirs(ds: list[str]) -> list[Path]:
    """SEC-25 §2: "chuẩn hóa đường dẫn và từ chối `..`/tuyệt đối/symlink ra ngoài".

    Từ chối ở đây, TRƯỚC khi chạy: một đường dẫn thoát ra ngoài đã là vi phạm dù công cụ có
    dùng tới nó hay không.
    """
    ra = []
    for d in ds:
        if ".." in Path(d).parts:
            raise EideError("E8000", f"allowed_dirs chứa '..': {d}", violations=["path"])
        p = Path(d).expanduser().resolve()
        if not p.is_dir():
            raise EideError("E8000", f"allowed_dirs không phải thư mục: {d}", violations=["path"])
        ra.append(p)
    return ra


def _kiem_cwd(cwd: str | Path, doc_duoc: list[Path]) -> Path:
    """Thư mục làm việc do người gọi chỉ định — phải nằm TRONG `allowed_dirs`.

    Đây là chỗ giữ cho tham số `cwd` không thành một lối vòng qua SEC-25 §2. Hồ sơ sandbox cấp
    quyền GHI cho thư mục làm việc (`_ho_so_macos`), nên nhận một `cwd` bất kỳ là nhận luôn việc
    cấp quyền ghi cho một thư mục chưa ai xét. Buộc nó nằm trong `allowed_dirs` thì quyền không
    rộng ra: người gọi vốn đã phải khai thư mục ấy, và khai là chỗ `_kiem_allowed_dirs` đã chặn
    `..` cùng liên kết mềm ra ngoài.
    """
    if ".." in Path(cwd).parts:
        raise EideError("E8000", f"cwd chứa '..': {cwd}", violations=["path"])
    p = Path(cwd).expanduser().resolve()
    if not p.is_dir():
        raise EideError("E8000", f"cwd không phải thư mục: {cwd}", violations=["path"])
    if not any(p == d or d in p.parents for d in doc_duoc):
        raise EideError("E8000",
                        f"cwd `{p}` không nằm trong allowed_dirs {[str(d) for d in doc_duoc]} — "
                        "khai nó vào allowed_dirs trước",
                        violations=["path"], cwd=str(p))
    return p


def _ho_so_macos(cwd: Path, doc_duoc: list[Path], network: bool) -> str:
    """Hồ sơ `sandbox-exec`. Đã đo: `(deny network*)` chặn socket thật trên macOS 26.

    Mọi đường dẫn đi qua `os.path.realpath` chứ không dùng nguyên chuỗi. `subpath` của
    `sandbox-exec` so khớp trên đường dẫn ĐÃ GIẢI liên kết mềm, mà trên macOS `/var` là liên kết
    mềm tới `/private/var` — nên `(subpath "/var/folders/…")` không khớp gì cả. Hệ quả trước khi
    sửa: với `out_dir` nằm dưới thư mục tạm (tức mọi test, và cả `user_cache()` trên một số
    máy), tiến trình trong sandbox **không ghi được vào chính thư mục làm việc của nó** — kể cả
    `./a.txt`. Đo 08/09/2026 bằng `echo > ./a.txt` → "Operation not permitted". Không test nào
    thấy vì chưa test nào ghi tệp bên trong sandbox: tất cả chỉ xem mã thoát của lệnh chỉ-đọc.
    """
    that = os.path.realpath
    dong = [
        "(version 1)",
        "(allow default)",
        "; SEC-25 §2 — chỉ ghi được vào thư mục làm việc tạm và /tmp",
        "(deny file-write*)",
        f'(allow file-write* (subpath "{that(cwd)}"))',
        f'(allow file-write* (subpath "{that(tempfile.gettempdir())}"))',
        '(allow file-write-data (literal "/dev/null") (literal "/dev/stdout") (literal "/dev/stderr"))',
    ]
    if not network:
        dong.append("; SEC-25 §2 — không mạng; §5 cho phép mở khi cài đặt")
        dong.append("(deny network*)")
    for d in doc_duoc:
        dong.append(f'(allow file-read* (subpath "{that(d)}"))')
    return "\n".join(dong) + "\n"
