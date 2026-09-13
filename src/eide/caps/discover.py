"""Namespace discover.* — CDS-12.3 (DISCOVER-01, 10, 11, 12); TGT-19 §4 (bảng VID/PID);
PLATFORM.md (mã riêng nền tảng); DDD-14 (thực thể `Discovery`).

Nhóm này trả lời câu hỏi đầu tiên của mọi phiên làm việc với phần cứng: **máy này đang thấy
gì?** Bốn năng lực ở đây là bốn cái *không cần board mới chạy được* — và đó không phải một
giới hạn mà là điểm mạnh của chúng:

    Một máy không cắm gì cả thì `discover.ports` trả danh sách rỗng, và **danh sách rỗng là
    câu trả lời đúng**. Nó chính là thứ người dùng cần khi cắm cáp mà không thấy board hiện
    ra: máy tính không nhìn thấy thiết bị nào, nên vấn đề nằm ở cáp, ở nguồn, hoặc ở driver —
    chứ không nằm ở EIDE.

Tám năng lực `discover.*` còn lại (`chip_id`, `bus_scan`, `power`…) cần phần cứng phản hồi,
nên chúng ở mốc sau.

## Vì sao không phụ thuộc `pyserial`

`pyserial` nằm trong nhóm `[hardware]` của `pyproject.toml` và không được cài mặc định. Hợp
đồng DISCOVER-01 nêu nó ở `steps`, nhưng bắt cả nhóm `discover.*` chết vì thiếu một gói tuỳ
chọn thì trái với chính điều nhóm này sinh ra để làm — *nói cho người dùng biết máy đang thấy
gì*. Nên: **dùng `pyserial` khi có, và có đường riêng cho từng hệ điều hành khi không.** Xem
`_liet_ke_cong`.
"""
from __future__ import annotations

import json
import os
import platform
import re
import subprocess
from pathlib import Path
from typing import Any

import yaml

from eide.caps.env import OS_KEY
from eide_core import tools
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context

# Hạn giờ cho các lệnh dò của hệ điều hành. `system_profiler` trên máy nhiều thiết bị USB có
# thể mất vài giây; quá mức này thì coi như không đọc được VID/PID, KHÔNG coi là lỗi — danh
# sách cổng vẫn đúng, chỉ thiếu phần định danh.
TIMEOUT_DO_S = 15.0

# Cổng ảo luôn có trên macOS, không phải thiết bị người dùng cắm vào. Lọc chúng ra vì một danh
# sách mở đầu bằng `Bluetooth-Incoming-Port` khiến người dùng tưởng board đã hiện.
BO_QUA_MAC = re.compile(r"/(cu|tty)\.(Bluetooth|debug-console|wlan-debug)", re.IGNORECASE)


def _bang_probe() -> list[dict[str, Any]]:
    """Bảng VID/PID của TGT-19 §4, dạng máy đọc được.

    Đọc từ `docs/spec/isa/probes.yaml` — bản sinh ra từ CÙNG mảng dữ liệu với bảng in trong
    tài liệu (`tgt_sim.js`). Chép bảng ấy vào Python là tạo bản thứ hai để trôi đi, đúng lỗi
    DEV-043/DEV-046 đã mắc hai lần.
    """
    f = spec_dir() / "isa" / "probes.yaml"
    if not f.exists():
        return []
    return yaml.safe_load(f.read_text(encoding="utf-8")).get("probes") or []


def _khop_probe(vid: str, pid: str) -> dict[str, Any] | None:
    """VID:PID → một mục trong bảng, hoặc `None` nếu không biết thiết bị này."""
    if not vid or not pid:
        return None
    khoa = f"{vid.upper():0>4}:{pid.upper():0>4}"
    for p in _bang_probe():
        if any(u.upper() == khoa for u in p.get("usb") or []):
            return p
    return None


# ---------------------------------------------------------------- liệt kê cổng


def _cong_pyserial() -> list[dict[str, Any]] | None:
    """Đường đa nền tảng, dùng khi `pyserial` có mặt. Trả `None` nếu không có gói."""
    try:
        from serial.tools import list_ports
    except Exception:
        return None
    ra = []
    for p in list_ports.comports():
        ra.append({
            "dev": p.device,
            "vid": f"{p.vid:04X}" if p.vid is not None else "",
            "pid": f"{p.pid:04X}" if p.pid is not None else "",
            "product": p.product or p.description or "",
            "serial": p.serial_number or "",
        })
    return ra


def _cong_macos() -> list[dict[str, Any]]:
    """macOS: `/dev/cu.*` cho cổng, `system_profiler` cho VID/PID.

    Hai nguồn riêng vì macOS không nối chúng lại ở chỗ nào đọc được rẻ: `/dev/cu.usbmodem14203`
    không mang VID/PID, còn `system_profiler` không nói tệp thiết bị. Ghép theo `serial_num` khi
    có — và khi không ghép được thì vẫn trả cổng, chỉ thiếu định danh. Một cổng không rõ VID/PID
    vẫn mở được; một cổng bị giấu đi thì không.
    """
    cong = [{"dev": str(d), "vid": "", "pid": "", "product": "", "serial": ""}
            for d in sorted(Path("/dev").glob("cu.*"))
            if not BO_QUA_MAC.search(str(d))]
    usb = _usb_macos()
    for c in cong:
        # `/dev/cu.usbmodem<serial>` — macOS nhét số sê-ri thiết bị vào tên tệp.
        ten = Path(c["dev"]).name
        for u in usb:
            sn = (u.get("serial_num") or "").strip()
            if sn and sn.lower() in ten.lower():
                c["vid"] = _bon_hex(u.get("vendor_id", ""))
                c["pid"] = _bon_hex(u.get("product_id", ""))
                c["product"] = u.get("_name", "")
                c["serial"] = sn
                break
    return cong


def _usb_macos() -> list[dict[str, Any]]:
    try:
        r = subprocess.run(["system_profiler", "-json", "SPUSBDataType"],
                           capture_output=True, text=True, timeout=TIMEOUT_DO_S, check=False)
        d = json.loads(r.stdout or "{}")
    except Exception:
        return []
    ra: list[dict[str, Any]] = []

    def di(muc: list[dict[str, Any]]) -> None:
        for m in muc:
            if m.get("vendor_id"):
                ra.append(m)
            if m.get("_items"):
                di(m["_items"])

    di(d.get("SPUSBDataType") or [])
    return ra


def _bon_hex(s: str) -> str:
    """`"0x0483  (STMicroelectronics)"` → `"0483"`."""
    m = re.search(r"0x([0-9A-Fa-f]{1,4})", s or "")
    return m.group(1).upper().zfill(4) if m else ""


def _cong_linux() -> list[dict[str, Any]]:
    """Linux: `/dev/ttyUSB*`/`ttyACM*` + `/sys` cho VID/PID."""
    ra = []
    dev = Path("/dev")
    for d in sorted(list(dev.glob("ttyUSB*")) + list(dev.glob("ttyACM*"))):
        c = {"dev": str(d), "vid": "", "pid": "", "product": "", "serial": ""}
        cs = Path("/sys/class/tty") / d.name / "device"
        for _ in range(4):          # đi ngược lên tới nút USB mang idVendor
            if (cs / "idVendor").exists():
                c["vid"] = _doc(cs / "idVendor").upper()
                c["pid"] = _doc(cs / "idProduct").upper()
                c["product"] = _doc(cs / "product")
                c["serial"] = _doc(cs / "serial")
                break
            cs = cs / ".."
        ra.append(c)
    return ra


def _doc(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def _liet_ke_cong() -> list[dict[str, Any]]:
    """Cổng serial đang cắm, theo đường rẻ nhất mà máy này có.

    Thứ tự: `pyserial` (đa nền tảng, có VID/PID sẵn) → đường riêng hệ điều hành. Trên Windows
    không có `pyserial` thì trả rỗng — và đó là một câu trả lời SAI mà ta không giấu được, nên
    `driver_ok` của mọi cổng sẽ là `None` chứ không phải `True`. Xem `_quyen_mo`.
    """
    ds = _cong_pyserial()
    if ds is None:
        # `tools.os_name()` trả tên của `platform.system()` — "Darwin", không phải "macos".
        # `env.py` đã có bảng `OS_KEY` cho đúng việc này; dùng lại thay vì tự chế một bảng thứ
        # hai, vì bảng thứ hai là chỗ hai bên lệch nhau rồi không ai thấy.
        os_ = OS_KEY.get(tools.os_name(), "")
        ds = _cong_macos() if os_ == "macos" else (_cong_linux() if os_ == "linux" else [])
    for c in ds:
        kh = _khop_probe(c["vid"], c["pid"])
        c["kind"] = (kh or {}).get("kind", "serial")
        if kh:
            c["probe"] = kh["id"]
            c["driver_note"] = kh.get("driver_note", "")
        c["driver_ok"] = _quyen_mo(c["dev"])
    return ds


def _quyen_mo(dev: str) -> bool | None:
    """Mở được cổng này không? `None` = không kiểm được trên nền tảng này.

    Đây là phần `driver_ok` của hợp đồng, và nó phân biệt ba tình huống mà DISCOVER-01 gộp
    chung sẽ vô dụng: cổng mở được, cổng có mà **không có quyền** (Linux thiếu nhóm `dialout` —
    lỗi phổ biến nhất của người mới), và "máy này không kiểm được".
    """
    if not dev or OS_KEY.get(tools.os_name()) == "windows":
        return None
    try:
        return os.access(dev, os.R_OK | os.W_OK)
    except Exception:
        return None


# ---------------------------------------------------------------- năng lực


@capability("discover.ports")
def ports(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DISCOVER-01 (CDS-12.3), TGT-19 §4. `{}` → `{ports[]}`.

    Chạy được trên máy không cắm gì: trả `ports: []`, và đó là thông tin thật.
    """
    return {"ports": _liet_ke_cong()}


@capability("discover.env_hw")
def env_hw(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DISCOVER-11 (CDS-12.3). `{}` → `{report{os, ports, drivers_missing[],
    permissions[], fixes[]}}`.

    **`fixes[]` là lệnh gợi ý, không phải lệnh được chạy.** Hợp đồng ghi `ask_when: "Cài driver
    (R2)"`; năng lực này là R0 nên nó chỉ được ĐỀ NGHỊ. Mọi lệnh trả về đây đều để người đọc rồi
    tự chạy — và những lệnh có `sudo` thì SEC-25 §2 cấm EIDE chạy trong mọi trường hợp.
    """
    cong = _liet_ke_cong()
    thieu: list[dict[str, Any]] = []
    quyen: list[dict[str, Any]] = []
    sua: list[str] = []
    os_ = OS_KEY.get(tools.os_name(), "")

    for c in cong:
        if c.get("driver_ok") is False:
            quyen.append({"dev": c["dev"], "van_de": "không có quyền đọc/ghi"})
            if os_ == "linux":
                # Lỗi phổ biến nhất của người mới trên Linux, và cách sửa thì luôn giống nhau.
                sua.append(f"sudo usermod -aG dialout {os.environ.get('USER', '$USER')}"
                           "   # rồi ĐĂNG XUẤT và vào lại")
        if c.get("driver_note") and os_ == "linux" and "udev" in c["driver_note"].lower():
            thieu.append({"dev": c["dev"], "can": c["driver_note"]})

    # Công cụ nạp/gỡ lỗi: thiếu thì không phải lỗi bây giờ, nhưng là lý do `target.flash` sẽ
    # hỏng sau — nói trước rẻ hơn nhiều.
    for cc in ("probe-rs", "openocd", "avrdude", "esptool.py"):
        if tools.which(cc) is None:
            thieu.append({"cong_cu": cc, "vi_sao": "cần cho nạp/gỡ lỗi trên board"})

    return {"report": {
        "os": f"{tools.os_name()} {platform.release()}",
        "arch": tools.arch(),
        "ports": cong,
        "drivers_missing": thieu,
        "permissions": quyen,
        "fixes": sua,
    }}


@capability("discover.network")
def network(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DISCOVER-10 (CDS-12.3). `{subnet?, services?}` → `{devices[]}`.

    **Chỉ quét trong mạng lab đã cấu hình.** Hợp đồng ghi `ask_when: "Quét ngoài mạng lab"` và
    `errors: [E3000]` — quét một dải mạng lạ là hành vi của một công cụ dò quét, và một IDE tự
    làm điều đó trong mạng công ty là chuyện rất khác với việc nó tìm board của chính bạn.

    Dùng `dns-sd`/`avahi-browse` có sẵn của hệ điều hành thay vì thêm phụ thuộc: mDNS là dịch
    vụ của hệ, không phải thư viện của ứng dụng.
    """
    dv = (params.get("services") or ["_eide._tcp", "_arduino._tcp", "_http._tcp"])
    subnet = params.get("subnet")
    if subnet and not _trong_mang_lab(subnet, ctx):
        raise EideError("E3000", f"Quét ngoài mạng lab cần người duyệt: {subnet}")

    lenh = None
    if tools.which("dns-sd"):
        lenh = ["dns-sd", "-B"]
    elif tools.which("avahi-browse"):
        lenh = ["avahi-browse", "-t", "-r", "-p"]
    if lenh is None:
        # Không có công cụ mDNS nào. Trả `devices: []` ở đây là nói dối bằng im lặng — người
        # đọc hiểu là "đã quét, không thấy gì", trong khi thật ra chưa quét lần nào.
        #
        # `output_schema` khoá `additionalProperties: false` nên không có chỗ cho một trường
        # ghi chú, và `errors[]` của DISCOVER-10 chỉ khai E3000. Ném E4001 (TOOL_MISSING — mã
        # có thật trong API-15 §3, và đúng nghĩa tình huống này) là sai khác duy nhất còn lại
        # mà vẫn nói được sự thật. Xem DEVIATIONS DEV-097.
        raise EideError("E4001", "Chưa quét được mDNS: máy này không có `dns-sd` (macOS) "
                                 "hay `avahi-browse` (Linux)",
                        missing=["dns-sd", "avahi-browse"])

    thay: list[dict[str, Any]] = []
    for sv in dv:
        try:
            r = subprocess.run(lenh + [sv], capture_output=True, text=True,
                               timeout=3.0, check=False)
            ket = r.stdout
        except subprocess.TimeoutExpired as e:
            # `dns-sd -B` chạy mãi theo thiết kế; hết giờ là cách dừng nó, không phải lỗi.
            ket = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        except Exception:
            continue
        for d in _doc_mdns(ket, sv):
            if d not in thay:
                thay.append(d)
    return {"devices": thay}


def _trong_mang_lab(subnet: str, ctx: Context) -> bool:
    """`autonomy.yaml` → `defaults.lab_networks[]`. Không khai thì KHÔNG có mạng lab nào."""
    try:
        f = spec_dir() / "policy" / "autonomy.yaml"
        d = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        ds = (d.get("defaults") or {}).get("lab_networks") or []
    except Exception:
        ds = []
    return any(subnet.startswith(str(m).rstrip("*").rstrip(".")) for m in ds)


def _doc_mdns(ra: str, dich_vu: str) -> list[dict[str, Any]]:
    """Bóc tên thiết bị từ đầu ra `dns-sd -B` hoặc `avahi-browse -p`."""
    thay = []
    for d in (ra or "").splitlines():
        if d.startswith("="):                       # avahi-browse -p: =;eth0;IPv4;tên;…
            phan = d.split(";")
            if len(phan) > 3 and phan[3]:
                thay.append({"name": phan[3], "service": dich_vu,
                             "address": phan[7] if len(phan) > 7 else ""})
        else:                                       # dns-sd -B: … Add … <domain> <type> <tên>
            m = re.match(r"\s*\d+:\s+\S+\s+\S+\s+\d+\s+\S+\s+(\S+)\s+(.+)$", d)
            if m and m.group(2).strip() not in ("Instance Name",):
                thay.append({"name": m.group(2).strip(), "service": dich_vu, "address": ""})
    return thay


@capability("discover.auto_setup")
def auto_setup(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: DISCOVER-12 (CDS-12.3), TGT-19 §2/§4. `{discovery_id}` →
    `{target_config, path}`; `errors: [E4003]`, `undo: restore_config`.

    **ID chip không khớp thì KHÔNG ghi gì và ném E4003.** Hợp đồng nói đúng một câu ấy, và nó là
    câu quan trọng nhất của cả năng lực: `target.yaml` quyết định firmware được nạp bằng adapter
    nào, với tốc độ nào, lên con chip nào. Viết một cấu hình "gần đúng" cho một con chip chưa
    nhận diện được là cách nạp firmware của họ STM32F4 lên một con F0.
    """
    did = params["discovery_id"]
    dv = _doc_discovery(did, ctx)
    if dv is None:
        raise EideError("E4003", f"Không có kết quả dò `{did}` — chạy `discover.ports` trước")

    chip = ((dv.get("chip_id") or {}).get("part")
            or (dv.get("chip_id") or {}).get("passport_match") or "")
    if not chip:
        raise EideError("E4003", "Kết quả dò chưa nhận diện được chip — "
                                 "không ghi target.yaml khi chưa biết đích là gì")

    isa = _isa_cua_chip(chip)
    if isa is None:
        raise EideError("E4003", f"Không manifest ISA nào khớp `{chip}` "
                                 f"({', '.join(_ten_isa())})")

    probe = (dv.get("probes") or [{}])[0]
    cong = (dv.get("ports") or [{}])[0]
    cfg: dict[str, Any] = {
        "chip": chip,
        "isa": isa["id"],
        "adapter": (isa.get("flash") or {}).get("default"),
        "probe": probe.get("kind") or probe.get("id") or None,
        "port": cong.get("dev") or None,
        "baud": ((dv.get("link_speed") or {}).get("chosen")
                 or (isa.get("serial") or {}).get("default_baud")),
        "lab": bool(dv.get("lab")),
        "discovery_id": did,
    }

    goc = Path(ctx.project_dir) if ctx.project_dir else None
    if goc is None:
        raise EideError("E2000", "Chưa mở dự án — không biết ghi target.yaml vào đâu")
    dich = goc / ".eide" / "target.yaml"
    dich.parent.mkdir(parents=True, exist_ok=True)
    if dich.exists():
        # `undo: restore_config` của hợp đồng cần một bản cũ để quay về. Sao lưu TRƯỚC khi ghi,
        # không phải sau — giữa hai bước ấy là chỗ một lần ghi hỏng làm mất cấu hình đang chạy.
        dich.with_suffix(".yaml.bak").write_text(dich.read_text(encoding="utf-8"),
                                                 encoding="utf-8")
    dich.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"target_config": cfg, "path": str(dich.relative_to(goc))}


def _doc_discovery(did: str, ctx: Context) -> dict[str, Any] | None:
    """Kết quả dò đã lưu. Sprint này chưa có bảng `discovery` trong store nên đọc từ tệp —
    xem DEVIATIONS DEV-097."""
    if not ctx.project_dir:
        return None
    f = Path(ctx.project_dir) / ".eide" / "discovery" / f"{did}.json"
    if not f.exists():
        return None
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        return None


def _ten_isa() -> list[str]:
    return sorted(p.stem for p in (spec_dir() / "isa").glob("*.yaml")
                  if p.stem != "probes")


def _isa_cua_chip(chip: str) -> dict[str, Any] | None:
    """Chip → manifest ISA, theo `family_patterns` của TGT-19 §2."""
    for p in sorted((spec_dir() / "isa").glob("*.yaml")):
        if p.stem == "probes":
            continue
        d = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        for mau in d.get("family_patterns") or []:
            if re.search(mau, chip, re.IGNORECASE):
                return d
    return None
