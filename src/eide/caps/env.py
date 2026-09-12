"""Namespace env.* — CDS-12.3; TGT-19 (manifest ISA, toolchain); PLATFORM.md."""
from __future__ import annotations

import json
import platform
import re
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide_core import store, tools
from eide_core.errors import EideError
from eide_core.paths import spec_dir, user_cache
from eide_core.registry import capability
from eide_core.router import Context
from eide_core.sandbox import Sandbox


@capability("env.detect")
def detect(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-01 — CDS-12.3; TGT-19 §discover. OS/arch/python/shell; cổng và probe do discover.* bổ sung (Sprint 2)."""
    return {"env": {"os": tools.os_name(), "os_version": platform.mac_ver()[0] or platform.release(),
                    "arch": tools.arch(), "python": sys.version.split()[0],
                    "shell": platform.uname().system, "ports": [], "probes": []}}


def _ver_ok(found: str | None, minimum: str | None) -> bool:
    if not minimum:
        return found is not None
    if not found:
        return False
    m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", found)
    if not m:
        return False
    got = tuple(int(x or 0) for x in m.groups())
    need = tuple(int(x) for x in minimum.split(".")) + (0,) * (3 - minimum.count(".") - 1)
    return got >= need


@capability("env.check")
def check(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-02 — CDS-12.3; TGT-19 manifest `toolchain`; E2000 khi ISA không có manifest; ok=false kèm install hint."""
    isa = params["isa"]
    path = spec_dir() / "isa" / f"{isa}.yaml"
    if not path.exists():
        raise EideError("E2000", f"ISA '{isa}' chưa có manifest trong docs/spec/isa/ (TGT-19)")
    man = yaml.safe_load(path.read_text(encoding="utf-8"))
    tc = man.get("toolchain", {})
    os_key = {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}[tools.os_name()]
    hints = (tc.get("install") or {}).get(os_key, [])
    wanted = [dict(tc.get("compiler", {}), required=True)] + [dict(t, required=True) for t in tc.get("tools", [])]
    report = []
    for t in wanted:
        exe = tools.which(t["name"])
        ver = tools.version_of(exe) if exe else None
        report.append({"tool": t["name"], "required": t["required"], "found": str(exe) if exe else None,
                       "version": ver, "ok": bool(exe) and _ver_ok(ver, t.get("min")), "min": t.get("min"),
                       "hash": None, "install_hint": None if exe else hints})
    return {"report": report}


@capability("env.sandbox")
def sandbox(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-07 — CDS-12.3; SEC-25 §2; STP-05 TC-SE-03; API-15 E8000, E4004.

    Trả `stdout_ref`/`stderr_ref` là ĐƯỜNG DẪN chứ không phải nội dung: một extractor có thể in
    hàng trăm MB, và nhét chỗ đó vào kết quả năng lực là nhét vào cả ledger (result_hash) lẫn
    ngữ cảnh mô hình. Vượt giới hạn → `violations[]` kèm mã thoát; quá thời gian → E4004 (lỗi
    riêng, không gộp vào E8000 vì cách xử lý khác nhau: một bên nới hạn, một bên xem lại lệnh).
    """
    return chay_sandbox(params["cmd"], ctx, limits=params.get("limits"),
                        allowed_dirs=params.get("allowed_dirs"),
                        network=bool(params.get("network")))


def chay_sandbox(cmd: list[str], ctx: Context, *, limits: dict[str, Any] | None = None,
                 allowed_dirs: list[str] | None = None, network: bool = False,
                 cwd: str | None = None, them_path: list[str] | None = None) -> dict[str, Any]:
    """Ruột của `env.sandbox`, gọi được từ trong nhà với thêm `cwd`.

    `cwd` KHÔNG nằm trong `input_schema` của ENV-07, và cố ý không đưa vào: hợp đồng là thứ tác
    tử gọi được qua Router, mà "chạy ở thư mục nào" là quyết định của người hiện thực một năng
    lực chứ không phải thứ để mô hình chọn. `code.build` cần nó vì `toolchain.build.cmd` của
    TGT-19 viết đường dẫn tương đối so với gốc dự án; các bên gọi khác giữ nguyên thư mục tạm.

    Nới `input_schema` thì đụng `docs/spec/` — cần một mục DEVIATIONS và chữ ký chủ sản phẩm cho
    một thứ không bên ngoài nào cần. Tách hàm rẻ hơn và nói đúng hơn về phạm vi.
    """
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    out = (root / ".eide" / "cache" / "sandbox") if root and (root / ".eide").is_dir() \
        else (user_cache() / "sandbox")
    sb = Sandbox(out_dir=out, ledger=ctx.extra.get("ledger"))
    kq = sb.run(cmd, limits=limits, allowed_dirs=allowed_dirs, network=network, cwd=cwd,
                them_path=them_path)
    return {"exit_code": kq.exit_code, "stdout_ref": kq.stdout_ref,
            "stderr_ref": kq.stderr_ref, "violations": kq.violations}


@capability("env.lock")
def lock(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-05 — CDS-12.3; UC-A03; SEC-25 §5 (tools.lock khi cài); undo restore_config.

    "Trôi" không chỉ là đổi số phiên bản: một công cụ BIẾN MẤT cũng làm bản dựng không lặp lại
    được, nên nó cũng là drift với `now: null`. Đó là lý do phép so đi theo tên công cụ trong
    lock cũ chứ không theo danh sách tìm thấy hôm nay.
    """
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / ".eide").is_dir():
        raise EideError("E2000", "Chưa mở dự án", exists=[], candidates=[], missing=["project"])
    f = root / ".eide" / "tools.lock"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    cu_map = {t["tool"]: t for t in cu.get("tools", [])}

    hien = []
    for ten, _bat_buoc in tools.COMMON_TOOLS:
        exe = tools.which(ten)
        if exe is None and ten not in cu_map:
            continue                      # chưa từng khóa và nay cũng không có → không phải trôi
        hien.append({"tool": ten, "version": tools.version_of(exe) if exe else None,
                     "path": str(exe) if exe else None, "hash": None})
    hien_map = {t["tool"]: t for t in hien}

    drift = []
    for ten, truoc in cu_map.items():
        nay = hien_map.get(ten, {"version": None, "path": None})
        if (nay.get("version") or None) != (truoc.get("version") or None):
            drift.append({"tool": ten, "was": truoc.get("version"), "now": nay.get("version"),
                          "path": nay.get("path")})

    khoa = {"generated": datetime.now(UTC).isoformat(), "os": tools.os_name(),
            "arch": platform.machine(), "tools": hien}
    f.write_text(yaml.safe_dump(khoa, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"lock": khoa, "drift": drift}


# ---------------------------------------------------------------- ENV-03 install
#
# Trình quản lý gói theo hệ điều hành, thứ tự theo mô tả ENV-03 ("brew/apt/pip/cargo/tải chính
# hãng") và TGT-19 §toolchain.install.
#
# `sudo` KHÔNG có trong bảng này, và đó là chủ ý chứ không phải thiếu sót: mọi lệnh ở đây chạy
# được dưới quyền người dùng thường. Một gói buộc phải sudo thì `needs_sudo=True` → `G-OPS-05`
# hỏi người, và người tự gõ lệnh. EIDE không bao giờ tự nâng quyền (SEC-25 §2).
TRINH_QUAN_LY: dict[str, list[tuple[str, list[str]]]] = {
    "macos":   [("brew", ["brew", "install", "{pkg}"]),
                ("pipx", ["pipx", "install", "{pkg}"]),
                ("cargo", ["cargo", "install", "{pkg}"])],
    "linux":   [("apt-get", ["apt-get", "install", "-y", "{pkg}"]),
                ("pipx", ["pipx", "install", "{pkg}"]),
                ("cargo", ["cargo", "install", "{pkg}"])],
    "windows": [("winget", ["winget", "install", "--silent", "{pkg}"]),
                ("pipx", ["pipx", "install", "{pkg}"])],
}

OS_KEY = {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}

# Công cụ ĐÓNG — `ask_when` của ENV-03 gọi tên nhóm này ("toolchain đóng") và ENV-04 tồn tại vì
# nó. Không tự cài được không phải vì khó, mà vì cài đòi chấp nhận license hoặc đăng nhập để
# tải: làm hộ là thay người ký một hợp đồng. Nguồn: TGT-19 §2 (XC8 ghi rõ "guide_install").
CONG_CU_DONG = {
    "xc8": ("Microchip XC8", "https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers"),
    "xc16": ("Microchip XC16", "https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers"),
    "xc32": ("Microchip XC32", "https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers"),
    "iar": ("IAR Embedded Workbench", "https://www.iar.com/products/architectures/"),
    "keil": ("Keil MDK", "https://www.keil.com/download/product/"),
    "mplab": ("MPLAB X IDE", "https://www.microchip.com/en-us/tools-resources/develop/mplab-x-ide"),
    "ipecmd": ("MPLAB IPE (ipecmd)", "https://www.microchip.com/en-us/tools-resources/production/mplab-integrated-programming-environment"),
}

TIMEOUT_CAI = 900          # 15 phút — `brew install gcc-arm-embedded` tải vài trăm MB


def dac_trung_cai(params: dict[str, Any], *, needs_sudo: bool = False) -> dict[str, Any]:
    """Đặc trưng cho `G-OPS` khi gọi `env.install`, theo `features` của G-OPS-04/05.

    Bên gọi truyền qua `router.invoke(..., features=...)`. Cùng lý do như `dac_trung_nguon` của
    `search.*`: cổng chỉ thấy những gì bên gọi đưa cho nó, và nếu mỗi bên gọi tự dựng đặc trưng
    theo cách riêng thì hai chỗ gọi cùng một năng lực sẽ nhận hai quyết định khác nhau.

    Thiếu đặc trưng thì `G-OPS-04`/`G-OPS-05` đều không khớp và rơi xuống `G-OPS-99` — vẫn ASK,
    nên an toàn, nhưng nhật ký quyết định chỉ ghi "Mặc định" thay vì nói gói nào và vì sao.
    """
    return {"op": "install", "package": params.get("tool"), "needs_sudo": bool(needs_sudo)}


@capability("env.install", features=["op", "package", "needs_sudo"])
def install(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-03 — CDS-12.3; TGT-19 §toolchain; POL-17 G-OPS-04/05; SEC-25 §2, §5.
    tc S33/S34, TC-46; lỗi E3000, E4000, E4004; undo `delete_created_files`.

    Ba ràng buộc, và cả ba đều là "không làm một việc":

    - **Không nâng quyền.** `TRINH_QUAN_LY` không có lệnh nào cần sudo. Gói đòi sudo thì cổng
      hỏi người và người tự gõ.
    - **Không tự tải công cụ đóng.** XC8/IAR/Keil → E4001 kèm `alternative=env.guide_install`.
    - **Không chạy trần.** Lệnh cài đi qua `env.sandbox` (có mạng, có hạn giờ): một script cài
      của bên thứ ba là mã lạ, và nó chạy trên máy của người dùng.

    Kiểm lại bằng `tools.which` sau khi cài chứ không tin mã thoát: trình quản lý gói trả 0 vẫn
    có thể đã cài vào một tiền tố ngoài `PATH`, và báo "đã cài" cho một công cụ gọi không được
    thì tệ hơn báo lỗi. (`env.check` không dùng được ở đây vì nó nhận `isa` chứ không nhận tên
    một công cụ — nó kiểm cả bộ toolchain của một ISA.)

    **Thực tế cổng, cần nói thẳng:** danh mục ghi lớp rủi ro "R4→T1 theo danh sách trắng" và
    `G-OPS-04` là quy tắc APPROVE, nhưng APD-08 §2 đặt ngưỡng cứng "mọi R4 luôn hỏi người" ở
    tầng TRƯỚC quy tắc cổng, nên `G-OPS-04` không bao giờ thắng được cho năng lực này — trên
    thực tế **mọi lần cài đều hỏi người**, kể cả gói trong danh sách trắng. Xem DEV-060.
    """
    ten = params["tool"]
    ban = params.get("version")

    if ten.lower() in CONG_CU_DONG:
        nhan, link = CONG_CU_DONG[ten.lower()]
        raise EideError("E4001", f"`{ten}` ({nhan}) là công cụ đóng: cài nó đòi chấp nhận license "
                        "hoặc đăng nhập để tải, nên EIDE không tự cài. Gọi `env.guide_install` để "
                        "lấy các bước và link chính hãng.",
                        tool=ten, alternative="env.guide_install", link=link)

    os_key = OS_KEY[tools.os_name()]
    # Giữ ĐƯỜNG DẪN TUYỆT ĐỐI, không giữ tên. Trong sandbox `PATH` được dựng lại thành
    # `/usr/bin:/bin:/usr/sbin:/sbin` (SEC-25 §3), mà Homebrew nằm ở `/opt/homebrew/bin` — gọi
    # bằng tên thì lệnh không tìm thấy chính trình quản lý gói vừa dò ra ở ngoài.
    ung_vien = [(m, tools.which(m), mau) for m, mau in TRINH_QUAN_LY[os_key] if tools.which(m)]
    if not ung_vien:
        da_thu = [m for m, _ in TRINH_QUAN_LY[os_key]]
        raise EideError("E4001", f"Không có trình quản lý gói nào trên {os_key} (đã thử "
                        f"{', '.join(da_thu)}) — cài một trong số đó rồi gọi lại, hoặc dùng "
                        "`env.guide_install` để cài tay.",
                        tool=ten, tried=da_thu, alternative="env.guide_install")

    mgr, duong_dan, mau = ung_vien[0]
    # Ghim phiên bản chỉ làm được ở brew (`pkg@ver`). Với các trình khác thì bỏ qua chứ KHÔNG
    # cài bừa bản mới nhất rồi im lặng: người xin `renode@1.14` mà nhận 1.15 sẽ dựng ra một bản
    # không lặp lại được, và không ai biết cho tới lúc kết quả lệch.
    if ban and mgr != "brew":
        raise EideError("E4001", f"`{mgr}` không ghim được phiên bản; bỏ `version` để cài bản mới "
                        f"nhất, hoặc cài tay bản {ban} theo `env.guide_install`.",
                        tool=ten, version=ban, manager=mgr, alternative="env.guide_install")
    goi = f"{ten}@{ban}" if ban else ten
    lenh = [str(duong_dan) if i == 0 else x.format(pkg=goi) for i, x in enumerate(mau)]

    t0 = time.perf_counter()
    kq = sandbox({"cmd": lenh, "network": True, "limits": {"wall_s": TIMEOUT_CAI}}, ctx)
    ma = kq["exit_code"]

    exe = tools.which(ten)
    ver = tools.version_of(exe) if exe else None
    dat = ma == 0 and exe is not None

    rep = {"tool": "install", "passed": dat, "log_ref": kq.get("stdout_ref"),
           "metrics": {"package": ten, "manager": mgr, "exit_code": ma,
                       "found": str(exe) if exe else None, "version": ver,
                       "trusted": ten in _goi_tin_cay(ctx)},
           "artifacts": [], "duration_ms": int((time.perf_counter() - t0) * 1000),
           "started_by": ctx.session_id, "at": datetime.now(UTC).isoformat()}
    if root := (Path(ctx.project_dir).expanduser() if ctx.project_dir else None):
        store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", rep)

    if not dat:
        ly = (f"`{mgr}` trả mã {ma}" if ma != 0 else
              f"`{mgr}` báo thành công nhưng `{ten}` vẫn không gọi được — nhiều khả năng cài vào "
              "một tiền tố ngoài PATH")
        raise EideError("E4000", f"Cài `{ten}` không thành: {ly}. Nhật ký: {kq.get('stderr_ref')}",
                        tool=ten, manager=mgr, exit_code=ma, log=kq.get("stderr_ref"))

    _cap_nhat_lock(ctx, ten, ver, exe)
    return {"report": rep}


def _goi_tin_cay(ctx: Context) -> list[str]:
    """Danh sách trắng gói — CHỈ khi niêm `defaults.sig` còn đạt.

    Đọc thẳng `defaults.yaml` mà bỏ qua chữ ký thì ai sửa được tệp là tự cho mình quyền cài gói,
    và cả cơ chế ký trở thành trang trí. Cổng đã xử đúng chuyện này (`PolicyGate._env` bỏ hẳn ba
    khóa khi niêm hỏng); ở đây chỉ đọc lại kết luận ấy để ghi vào ToolReport.
    """
    g = ctx.extra.get("gate")
    if g is None or not getattr(g, "danh_sach_da_ky", False):
        return []
    return list((getattr(g, "config", None) or {}).get("trusted_packages") or [])


def _cap_nhat_lock(ctx: Context, ten: str, ver: str | None, exe: Any) -> None:
    """SEC-25 §5 "tools.lock khi cài". Không ghi thì `env.lock` báo trôi ngay lần chạy sau — một
    công cụ vừa cài xong bị báo là "biến mất so với lock"."""
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / ".eide").is_dir():
        return
    f = root / ".eide" / "tools.lock"
    d = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    ds = [t for t in (d.get("tools") or []) if t.get("tool") != ten]
    ds.append({"tool": ten, "version": ver, "path": str(exe) if exe else None, "hash": None,
               "installed_by": "env.install", "at": datetime.now(UTC).isoformat()})
    d["tools"] = sorted(ds, key=lambda t: t["tool"])
    f.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")


# ---------------------------------------------------------------- ENV-04 guide_install


@capability("env.guide_install")
def guide_install(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-04 — CDS-12.3; TGT-19 §2/§3. R0, **T3**. tc: "Có bước và link chính hãng".

    T3 ở đây không phải mức tự chủ thấp cho chắc ăn, mà là ràng buộc pháp lý: XC8, IAR, Keil đòi
    người chấp nhận license hoặc đăng nhập để tải.

    `links` chỉ trỏ **trang chính hãng**, không trỏ bản mirror hay bản đóng gói lại. Một trình
    dịch tải từ nguồn thứ ba là một trình dịch không ai bảo đảm nội dung — và nó sinh ra firmware
    chạy trên thiết bị thật.
    """
    ten = params["tool"]
    os_key = OS_KEY[tools.os_name()]
    ten_os = {"macos": "macOS", "windows": "Windows", "linux": "Linux"}[os_key]

    if ten.lower() in CONG_CU_DONG:
        nhan, link = CONG_CU_DONG[ten.lower()]
        return {"steps": [
            f"Mở trang chính hãng của {nhan} rồi chọn bản cho {ten_os}.",
            "Đọc và chấp nhận license — bước này EIDE không làm thay được, và đó chính là lý do "
            "năng lực này ở mức T3.",
            f"Cài theo trình cài của hãng, rồi bảo đảm thư mục chứa `{ten}` nằm trong PATH.",
            f"Chạy `eide caps invoke env.check` để EIDE nhận ra `{ten}`, rồi `env.lock` để ghim "
            "phiên bản.",
        ], "links": [link]}

    if (tu_manifest := _huong_dan_tu_manifest(ten, os_key, ten_os)) is not None:
        return tu_manifest

    ds = ", ".join(m for m, _ in TRINH_QUAN_LY[os_key])
    return {"steps": [
        f"`{ten}` không nằm trong nhóm công cụ đóng và cũng không có trong manifest ISA nào, nên "
        "EIDE không có bước cài chính thức cho nó.",
        f"Cách cài thông thường trên {ten_os}: dùng trình quản lý gói của hệ điều hành ({ds}).",
        f"Nếu `{ten}` nằm trong `trusted_packages`, `env.install` cài được tự động — nhưng vì đây "
        "là thao tác lớp R4, EIDE vẫn hỏi anh trước.",
        "Cài xong thì chạy `env.check` rồi `env.lock`.",
    ], "links": []}


def _huong_dan_tu_manifest(ten: str, os_key: str, ten_os: str) -> dict[str, Any] | None:
    """Lệnh cài lấy từ `toolchain.install` của manifest ISA — nguồn duy nhất, không chép tay.

    Chép bảng lệnh cài sang đây thì có hai bản, và bản trong mã là bản không ai sinh lại (cùng
    lỗi với `PRED_W`/DEV-043). Manifest đã có sẵn cả `compiler` lẫn `tools`, nên tra thẳng.
    """
    for f in sorted((spec_dir() / "isa").glob("*.yaml")):
        man = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        tc = man.get("toolchain") or {}
        co = [(tc.get("compiler") or {}).get("name")] + [t.get("name") for t in (tc.get("tools") or [])]
        if ten not in co:
            continue
        lenh = (tc.get("install") or {}).get(os_key) or []
        if not lenh:
            continue
        return {"steps": [f"Theo manifest ISA `{man.get('id', f.stem)}` (TGT-19), trên {ten_os}:",
                          *[f"    $ {x}" for x in lenh],
                          "Cài xong thì chạy `env.check` rồi `env.lock` để ghim phiên bản."],
                "links": []}
    return None


# ---------------------------------------------------------------- ENV-06 install_pack


TEP_MANIFEST = "manifest.json"
TEP_CHU_KY = "manifest.sig"


def _kho_pack() -> Path:
    """Kho gói cục bộ (`~/.eide/packs`). Hàm riêng để test thay được — và để đường dẫn ấy chỉ
    nằm ở MỘT chỗ."""
    from eide_core.paths import user_config
    return user_config() / "packs"


@capability("env.install_pack")
def install_pack(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: ENV-06 — CDS-12.3; PKG-22 (manifest, chữ ký); TGT-19 (ISA profile). Lỗi E4004;
    undo `delete_created_files`. tc: "TC-48 thêm ISA không sửa core".

    `tc` là một bài kiểm về **kiến trúc**, không về một lệnh cài: một ISA mới phải vào được hệ
    thống bằng cách thả gói vào thư mục pack, không bằng cách sửa một bảng trong `src/`. Nếu
    phải sửa mã thì mọi ISA cộng đồng đều phải chờ một bản phát hành của EIDE — và cả ý tưởng
    "pack" mất nghĩa.

    **Kiểm chữ ký trước khi chép.** Một gói ISA quyết định lệnh dựng và cách nạp chip; chạy một
    gói đã bị sửa là để người khác chọn tham số cho `target.flash`. Chữ ký ở đây là băm nội dung
    các tệp trong manifest — đủ để bắt sửa đổi, và PKG-22 sẽ thay bằng chữ ký khoá công khai khi
    registry có thật.

    `registry.pull` là mốc M4 nên chưa tải được gói từ xa: gói phải đã nằm trong kho cục bộ.
    Không có thì E4004 nói thẳng kèm năng lực cần chạy, chứ không im lặng trả rỗng như thể đã
    cài xong.
    """
    from eide.caps.project import EIDE_DIR, _root
    isa = params["isa"]
    nguon = _kho_pack() / isa
    if not (nguon / TEP_MANIFEST).is_file():
        raise EideError("E4004", f"Chưa có gói ISA `{isa}` trong kho cục bộ ({_kho_pack()}). "
                        "Tải về trước rồi cài", candidates=["registry.pull", "registry.search"],
                        exists=[p.name for p in _kho_pack().glob("*")] if _kho_pack().is_dir() else [],
                        missing=[isa])

    man = json.loads((nguon / TEP_MANIFEST).read_text(encoding="utf-8"))
    _kiem_chu_ky(nguon, man, isa)

    root = _root(ctx)
    dich = root / EIDE_DIR / "packs" / isa
    dich.mkdir(parents=True, exist_ok=True)
    da_cai = []
    for ten in [TEP_MANIFEST, *man.get("files", [])]:
        src = nguon / ten
        if not src.is_file():
            raise EideError("E4004", f"Gói `{isa}` khai `{ten}` nhưng tệp không có",
                            missing=[ten], candidates=["registry.pull"], exists=[])
        (dich / ten).parent.mkdir(parents=True, exist_ok=True)
        (dich / ten).write_bytes(src.read_bytes())
        da_cai.append(str(dich / ten))

    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"pack:{isa}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"installed": da_cai}


def _kiem_chu_ky(nguon: Path, man: dict[str, Any], isa: str) -> None:
    import hashlib
    sig = nguon / TEP_CHU_KY
    if not sig.is_file():
        raise EideError("E4004", f"Gói `{isa}` không có `{TEP_CHU_KY}` — không kiểm được toàn "
                        "vẹn, và một gói ISA quyết định lệnh dựng lẫn cách nạp chip",
                        missing=[TEP_CHU_KY], candidates=["registry.pull"], exists=[])
    h = hashlib.sha256()
    for ten in sorted(man.get("files") or []):
        p = nguon / ten
        if p.is_file():
            h.update(p.read_bytes())
    if h.hexdigest() != sig.read_text(encoding="utf-8").strip():
        raise EideError("E4004", f"Chữ ký gói `{isa}` không khớp nội dung — gói đã bị sửa sau "
                        "khi ký", missing=[], candidates=["registry.pull"], exists=[])
