"""Git — lớp mỏng cho `code.merge` / `code.revert`. WI-CODE-12.

Spec: EIDE-CON-28 §4 (nhánh `auto/<feature>`, thông điệp commit `<type>(<scope>): …` kèm trailer
`Eide-Facts` / `Eide-Run` / `Eide-Model` / `Eide-Prompt`, tag `known-good/<date>`);
CDS-12.1 CODE-12/CODE-13; APD-08 (cửa sổ hoàn tác `git_revert`).

**Vì sao git KHÔNG chạy trong sandbox.** `eide_core.sandbox` cấm ghi ra ngoài thư mục làm việc
tạm — đó là cả điểm của nó. Nhưng việc của git ở đây chính là ghi vào thư mục dự án, nên đưa nó
vào sandbox thì hoặc phải mở quyền ghi cho cả dự án (bỏ lớp bảo vệ cho mọi công cụ khác), hoặc
git không làm được gì. Ranh giới đúng là ranh giới SEC-25 §2 vạch ra: sandbox dành cho **công cụ
NGOÀI chạy trên dữ liệu không tin được** (trình giải nén, trình dịch, bộ dựng lược đồ). `git` ở
đây do EIDE gọi với tham số cố định, dạng danh sách, trên chính kho của người dùng — cùng loại
với việc EIDE ghi `.eide/store.sqlite`. Xem DEV-065.
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

from eide_core import tools
from eide_core.errors import EideError

# Danh sách con lệnh được phép. Không phải để chống chính mình, mà để một thay đổi sau này thêm
# `git push` hay `git clean -fdx` vào đây là một thay đổi PHẢI ĐỌC — cả hai đều không hoàn tác
# được, và cả hai đều rất dễ viết ra trong lúc sửa một lỗi khác.
LENH_CHO_PHEP = frozenset({"init", "add", "commit", "checkout", "switch", "branch", "tag",
                           "revert", "rev-parse", "status", "log", "config", "diff",
                           "show", "symbolic-ref", "ls-files",
                           # v2.0 — merge 3 bên khi người và tác tử cùng sửa một tệp.
                           # `merge-file` hợp nhất Ở MỨC DÒNG và tự đánh dấu vùng giao nhau;
                           # tự viết phép hợp nhất là tự viết lại một thuật toán đã đúng ba
                           # mươi năm, và sai ở đó thì sai im lặng vào mã nguồn của người dùng.
                           "merge-base", "merge-file"})


def co_git() -> Path | None:
    return tools.which("git")


def chay(root: Path, *args: str, kiem: bool = True) -> subprocess.CompletedProcess[str]:
    """Chạy `git` trong `root`. Không shell, tham số dạng danh sách (PLATFORM.md quy tắc 3)."""
    exe = co_git()
    if exe is None:
        raise EideError("E4001", "Thiếu `git` — `env.install` hoặc cài theo `env.guide_install`",
                        missing=["git"], remedy="env.install")
    if args and args[0] not in LENH_CHO_PHEP:
        raise EideError("E8000", f"Con lệnh git không nằm trong danh sách cho phép: {args[0]}",
                        violations=["git-subcommand"], allowed=sorted(LENH_CHO_PHEP))
    p = subprocess.run([str(exe), *args], cwd=str(root), capture_output=True,  # noqa: S603
                       text=True, timeout=120)
    if kiem and p.returncode != 0:
        raise EideError("E7001", f"git {' '.join(args)} thất bại: {p.stderr.strip()[:300]}",
                        argv=list(args), returncode=p.returncode, stderr=p.stderr[:1000])
    return p


def la_kho(root: Path) -> bool:
    if co_git() is None:
        return False
    return chay(root, "rev-parse", "--is-inside-work-tree", kiem=False).returncode == 0


def dam_bao_kho(root: Path) -> bool:
    """Tạo kho nếu chưa có. Trả `True` khi vừa tạo.

    Đặt `user.name`/`user.email` ở MỨC KHO, không mức toàn cục: EIDE không được sửa cấu hình git
    của người dùng. Không đặt gì thì `git commit` hỏng trên máy mới với thông điệp về danh tính
    — một lỗi không liên quan gì tới việc đang làm.
    """
    if la_kho(root):
        return False
    chay(root, "init", "-q", "-b", "main")
    if not chay(root, "config", "user.email", kiem=False).stdout.strip():
        chay(root, "config", "user.email", "eide@localhost")
        chay(root, "config", "user.name", "EIDE agent")
    return True


def nhanh_hien_tai(root: Path) -> str | None:
    p = chay(root, "symbolic-ref", "--short", "HEAD", kiem=False)
    return p.stdout.strip() or None


def sang_nhanh(root: Path, ten: str) -> None:
    """Chuyển sang nhánh, tạo nếu chưa có."""
    if chay(root, "rev-parse", "--verify", "--quiet", ten, kiem=False).returncode == 0:
        chay(root, "checkout", "-q", ten)
    else:
        chay(root, "checkout", "-q", "-b", ten)


def co_thay_doi(root: Path) -> bool:
    return bool(chay(root, "status", "--porcelain").stdout.strip())


def tac_gia(ai: str) -> str:
    """Tác giả MÁY ĐỌC ĐƯỢC cho một commit — UXD-13 v2.0 §6.2 (quyết định Q1).

    `human:congvt` hay `agent:run-r_9f3c/step-3` một mình KHÔNG phải tác giả git hợp lệ: git đòi
    dạng `Tên <thư@điện.tử>`, và truyền chuỗi trần vào `--author` làm cả lệnh commit hỏng. Nên
    tên máy-đọc-được đi vào phần TÊN, còn phần thư điện tử là một địa chỉ cục bộ không gửi được.

    Vì sao cần: hoàn tác cả một Run là `git revert` chọn lọc mọi commit của `agent:run-<id>/*`
    trong khi GIỮ commit của người xen giữa (tiêu chí N4). Phép chọn lọc ấy phải đọc được từ
    chính lịch sử, không từ một bảng bên cạnh — bảng bên cạnh thì lệch, còn lịch sử thì không.
    """
    return f"{ai} <{ai.replace('/', '-')}@eide.local>"


def commit(root: Path, thong_diep: str, duong_dan: list[str], *,
           ai: str | None = None, seq: int | None = None) -> str:
    """Thêm ĐÚNG các tệp được nêu rồi commit; trả SHA đầy đủ.

    `git add <đường dẫn>` chứ không `git add -A`: một patch chỉ được đưa vào commit đúng những
    tệp nó khai. Thêm tất cả thì mọi thứ người dùng đang sửa dở trong cây làm việc cũng bị cuốn
    vào một commit mang trailer "do tác tử tạo" — và trailer ấy sẽ nói dối.

    `ai` là tác giả máy-đọc-được (`human:<tên>` / `agent:run-<id>/step-<n>`); `seq` là số thứ tự
    sự kiện sổ cái tương ứng, đi vào trailer `Eide-Ledger-Seq`. Hai thứ ấy nối lịch sử git với
    sổ cái theo cả hai chiều: từ một commit tra ra việc đã ghi, và ngược lại.
    """
    for d in duong_dan:
        chay(root, "add", "--", d)
    if seq is not None:
        thong_diep = f"{thong_diep}\n\nEide-Ledger-Seq: {seq}"
    lenh = ["commit", "-q", "-m", thong_diep]
    if ai:
        lenh += [f"--author={tac_gia(ai)}"]
    chay(root, *lenh, "--", *duong_dan)
    return chay(root, "rev-parse", "HEAD").stdout.strip()


def dat_tag(root: Path, mau: str) -> str:
    """Tag theo `mau`, thêm hậu tố `.1`, `.2`… nếu trùng. CON-28 chỉ định nghĩa một dạng tag
    (`known-good/<date>`), mà một ngày có thể merge nhiều lần."""
    ten = mau
    i = 0
    while chay(root, "rev-parse", "--verify", "--quiet", ten, kiem=False).returncode == 0:
        i += 1
        ten = f"{mau}.{i}"
    chay(root, "tag", ten)
    return ten


def thong_diep(loai: str, pham_vi: str, mo_ta: str, trailer: dict[str, Any]) -> str:
    """`<type>(<scope>): <mô tả tiếng Việt>` + trailer `Eide-*` — CON-28 §4.

    Trailer bị BỎ QUA nếu giá trị rỗng, chứ không ghi `Eide-Facts:` trống. Một trailer rỗng đọc
    như "patch này không dựa trên fact nào", trong khi sự thật có thể là "chỗ này chưa điền".
    """
    d = [f"{loai}({pham_vi}): {mo_ta}", ""]
    for k, v in trailer.items():
        if v in (None, "", [], {}):
            continue
        d.append(f"{k}: {', '.join(str(x) for x in v) if isinstance(v, (list, tuple)) else v}")
    return "\n".join(d) + "\n"
