"""Namespace sim.* — CDS-12.4 SIM-01…SIM-06; SIM-20 §1–§5; STP-05 TC-SM-01…TC-SM-06;
POL-17 (không cổng riêng — cả nhóm đi dải quy tắc chung `*`); DDD-14 `tool_report`.

`defaults.sim_first` bắt mô phỏng chạy **trước** phần cứng, nên nhóm này là chỗ duy nhất tác tử
tự xác minh được mã nó vừa sinh khi chưa có board. Đó cũng là lý do nó phải nói thật về giới hạn
của mình: một kết quả mô phỏng "xanh" mà thật ra chưa kiểm gì thì tệ hơn không mô phỏng, vì nó
đưa một firmware chưa ai quan sát thẳng vào tay người đi nạp board.

Bất biến của cả nhóm: **không kỳ vọng nào được coi là ĐẠT nếu không có kênh quan sát cho nó.**
Một `expect` mà engine hiện có không nhìn thấy được (biến qua monitor, chân GPIO, tín hiệu
plant) trả `unverified` kèm lý do, và một kịch bản có dù một dòng `unverified` thì
`report.passed = false`. Xem `_cham_expect`.

Hai chỗ hiện thực còn nợ, ghi trong DEVIATIONS chứ không giấu trong mã:
  DEV-083  kênh quan sát `var`/`gpio` (monitor Renode, GDB stub) — chưa nối.
  DEV-084  đồng mô phỏng plant ↔ engine chip — `sim.model_plant` chạy độc lập được (và
           `sim.sweep` quét trên nó), nhưng chưa nối vào lượt chạy firmware.
"""
from __future__ import annotations

import json
import math
import re
import shlex
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

from eide.caps.code import manifest_isa
from eide.caps.project import EIDE_DIR
from eide_core import store, tools
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context

# Thư mục mô phỏng của dự án. SIM-20 §2 và §5 viết đường dẫn dạng `sim/platform.repl`,
# `sim/run.resc`, `sim/f04.yaml` — nên `sim/` là gốc, không phải một thư mục con theo engine.
SIM_DIR = "sim"

# Mô tả nền tảng dạng MÁY ĐỌC ĐƯỢC — chỗ nối duy nhất giữa `sim.build_platform` và `sim.run`.
# Không có nó thì `sim.run` phải đoán engine từ đuôi tệp, và đoán sai thì nó chạy `qemu` trên một
# `.repl` của Renode rồi báo "công cụ thất bại" cho một lỗi thuộc về EIDE.
PLATFORM_JSON = "platform.json"

BANG_RENODE = Path(__file__).parent / "data" / "renode_models.yaml"

# Tên tệp thi hành của từng engine. TGT-19 khai `sim: {engine: renode, fallback: qemu}` — tên
# HỌ engine, không phải tên chương trình; mà `qemu` không phải một chương trình nào cả, nó là
# một họ `qemu-system-<kiến trúc>`. Bảng này lấp đúng chỗ ấy. Xem DEVIATIONS DEV-082.
QEMU_THEO_ISA = {
    "armv7e-m": "qemu-system-arm",
    "avr8": "qemu-system-avr",
    "rv32imac": "qemu-system-riscv32",
    "xtensa": "qemu-system-xtensa",
}
EXE_ENGINE = {"renode": ("renode",), "simavr": ("simavr", "simavr-tiny")}

# Engine `native` = firmware dịch cho máy chủ, chạy thẳng (SIM-20 §1 bảng chế độ). Nó không cần
# chương trình mô phỏng nào — artifact TỰ NÓ là chương trình — nên nó luôn "có", và vì thế
# KHÔNG được dùng làm đường lui tự động: rơi vào native trong im lặng nghĩa là mất hết timing và
# mất hết thanh ghi, mà người gọi vẫn đọc `engine` như một lời hứa đã mô phỏng chip.
ENGINE_NATIVE = "native"


def _du_an(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm sim.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _thu_muc_sim(root: Path) -> Path:
    d = root / SIM_DIR
    d.mkdir(parents=True, exist_ok=True)
    return d


def _tuong_doi(root: Path, p: Path) -> str:
    """Đường dẫn trong kết quả là TƯƠNG ĐỐI với gốc dự án, dạng POSIX.

    Hợp đồng viết ví dụ `sim/f04.yaml` và `build/fw.elf`, tức người ta chuyền những chuỗi ấy
    giữa các năng lực và chép chúng vào kịch bản. Trả đường tuyệt đối thì một kịch bản sinh trên
    máy này không dùng lại được trên máy khác — mà dùng lại chính là điều SIM-20 §5 hứa khi nói
    "kịch bản dùng lại nguyên vẹn cho HIL".
    """
    try:
        return p.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return p.as_posix()


def _giai(root: Path, duong: str) -> Path:
    p = Path(duong).expanduser()
    return p if p.is_absolute() else root / p


# ---------------------------------------------------------------- SIM-01 build_platform


def isa_cua_chip(chip: str) -> str | None:
    """ISA của một chip. Ví dụ của SIM-01 là `st.stm32f411ce` — dạng IRI hộ chiếu — nên phép tra
    phải nhận nó; `project._isa_tu_chip` thử cả dạng IRI lẫn dạng trần."""
    from eide.caps.project import _isa_tu_chip

    return _isa_tu_chip(str(chip).strip())


def _iri_chip(chip: str) -> str:
    ten = str(chip).strip()
    return ten if ten.startswith("chip:") else f"chip:{ten}"


def bang_renode() -> dict[str, Any]:
    return yaml.safe_load(BANG_RENODE.read_text(encoding="utf-8")) or {"families": {}}


def _ho_renode(chip: str) -> tuple[str, dict[str, Any]] | tuple[None, None]:
    """Họ chip trong `renode_models.yaml`, khớp theo `match` — cùng cơ chế `family_patterns`."""
    ten = _iri_chip(chip)[len("chip:"):].rsplit(".", 1)[-1]
    for ho, d in (bang_renode().get("families") or {}).items():
        for pat in (d.get("match") or []):
            if re.search(pat, ten, re.I):
                return ho, d
    return None, None


def _tim_exe(engine: str, isa: str, chip: str = "") -> Path | None:
    """Chương trình của engine, hoặc None nếu engine ấy KHÔNG DÙNG ĐƯỢC cho chip này.

    Với qemu, "có chương trình" chưa đủ: QEMU chỉ chạy những bo mạch đã biên dịch sẵn vào nó,
    nên thiếu mục trong `QEMU_MACHINE` cũng là không dùng được — và phải trả None ở ĐÂY, chỗ
    `chon_engine` còn đi tiếp được, chứ không phải lúc `sim.run` đã dựng xong nền tảng.
    """
    if engine == ENGINE_NATIVE:
        return Path("native")           # không có chương trình mô phỏng nào để tìm
    if engine == "qemu":
        ten = QEMU_THEO_ISA.get(isa)
        if not ten or (chip and not _may_qemu(chip)):
            return None
        return tools.which(ten)
    for ten in EXE_ENGINE.get(engine, ()):
        if (p := tools.which(ten)):
            return p
    return None


def chon_engine(isa: str, man: dict[str, Any], chip: str = "") -> dict[str, Any]:
    """Engine theo ISA (SIM-20 §1 bảng chế độ) — engine chính, rồi `fallback` của manifest.

    KHÔNG tự lui về `native`. SIM-20 §1 xếp `native` là một chế độ có chủ đích ("chip không hỗ
    trợ / kiểm logic nhanh", độ tin "chỉ logic; không timing"), không phải một lưới an toàn:
    lui về nó trong im lặng thì `sim.run` vẫn trả `passed=true` cho một firmware chưa hề chạy
    trên mô hình chip nào, và `sim_first` mất hết ý nghĩa. Manifest không khai `sim` gì cả mới
    là "chip không hỗ trợ", và khi ấy `native` là câu trả lời đúng.
    """
    cfg = man.get("sim") or {}
    if not cfg.get("engine"):
        return {"engine": ENGINE_NATIVE, "exe": None, "requested": ENGINE_NATIVE,
                "fallback": False}
    thu = [cfg["engine"], *([cfg["fallback"]] if cfg.get("fallback") else [])]
    for i, e in enumerate(thu):
        if (exe := _tim_exe(e, isa, chip)):
            return {"engine": e, "exe": str(exe), "requested": thu[0], "fallback": i > 0}
    raise EideError("E4001", f"Thiếu engine mô phỏng cho ISA `{isa}`: đã thử "
                    f"{', '.join(thu)} — `env.guide_install` để cài",
                    missing=thu, isa=isa, remedy="env.guide_install")


def _facts_nen_tang(root: Path, chip: str) -> dict[str, Any]:
    """Bản đồ bộ nhớ + ngoại vi của chip, đọc từ hộ chiếu trong store.

    Grounding của SIM-01 là **"Hộ chiếu vàng"**, nên phép đọc lọc theo tầng/`status` chứ không
    lấy mọi thứ trùng subject: một `base_address` tầng bạc chưa duyệt (đọc từ bảng PDF bằng mô
    hình) đủ tốt để hỏi người, nhưng chưa đủ để dựng một nền tảng mà firmware sẽ chạy thật trên
    đó — sai một offset thì mọi thanh ghi lệch và triệu chứng trông y hệt lỗi trong mã.
    """
    db = store.store_path(root)
    goc = _iri_chip(chip)
    ra: dict[str, Any] = {"memory": {}, "periph": {}, "cites": []}
    if not db.exists():
        return ra
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value FROM fact"
            " WHERE (subject = ? OR subject LIKE ?)"
            "   AND predicate IN ('memory_size','base_address','irq')"
            "   AND (tier = 'gold' OR status IN ('reviewed','verified'))"
            "   AND status NOT IN ('superseded','rejected')"
            " ORDER BY subject, predicate", (goc, goc + "/%")).fetchall()
    for fid, subj, vi_tu, gt in rows:
        try:
            v = json.loads(gt)
        except (ValueError, TypeError):
            continue
        if vi_tu == "memory_size" and (m := re.search(r"/mem:([A-Za-z0-9_]+)$", subj)):
            ra["memory"][m.group(1).upper()] = v
            ra["cites"].append(fid)
        elif (m := re.match(rf"^{re.escape(goc)}/periph:([A-Za-z0-9_]+)$", subj)):
            ra["periph"].setdefault(m.group(1), {})[vi_tu] = v
            ra["cites"].append(fid)
    return ra


def _phu_song(chip: str, nen: dict[str, Any]) -> dict[str, Any]:
    """Ngoại vi nào có mô hình sẵn, ngoại vi nào không — bước 1 của SIM-01.

    Ngoại vi không có mô hình KHÔNG bị bỏ qua: nó vào `unsupported` kèm địa chỉ, vì đó chính là
    danh sách việc cho `sim.mock_peripheral`.
    """
    _, ho = _ho_renode(chip)
    bang = (ho or {}).get("peripherals") or {}
    co, khong = [], []
    for ten, d in sorted(nen["periph"].items()):
        khop = next((v for k, v in bang.items() if ten.upper().startswith(k.upper())), None)
        muc = {"name": ten, "base": d.get("base_address"), "irq": d.get("irq")}
        if khop:
            co.append({**muc, "model": khop["model"], "kind": khop.get("kind")})
        else:
            khong.append({**muc, "reason": "không có mô hình trong renode_models.yaml"})
    return {"modeled": co, "unsupported": khong}


def _repl(chip: str, nen: dict[str, Any], pho: dict[str, Any], ho: dict[str, Any]) -> str:
    """`sim/platform.repl` — dạng viết đúng như SIM-20 §2 mô tả."""
    lo = int(nen["memory"].get("FLASH") or 0)
    ram = int(nen["memory"].get("RAM") or 0)
    d = [f"// sinh bởi sim.build_platform từ hộ chiếu {_iri_chip(chip)}",
         "// mọi địa chỉ và kích thước dưới đây trỏ về một fact trong store — xem coverage.cites",
         "cpu: CPU.CortexM @ sysbus",
         '    cpuType: "cortex-m4"',
         "    nvic: nvic",
         f"nvic: {ho['nvic']['model']} @ sysbus {hex(ho['nvic']['base'])}",
         f"flash: Memory.MappedMemory @ sysbus 0x08000000 {{ size: {hex(lo)} }}",
         f"sram: Memory.MappedMemory @ sysbus 0x20000000 {{ size: {hex(ram)} }}"]
    for p in pho["modeled"]:
        dong = f"{p['name'].lower()}: {p['model']} @ sysbus {hex(int(p['base']))}"
        if p.get("irq") is not None:
            dong += f" -> nvic@{int(p['irq'])}"
        d.append(dong)
    for p in pho["unsupported"]:
        d.append(f"// KHÔNG mô phỏng: {p['name']} @ {hex(int(p['base'])) if p.get('base') else '?'}"
                 f" — {p['reason']}")
    return "\n".join(d) + "\n"


def _resc(pho: dict[str, Any]) -> str:
    """`sim/run.resc` — kịch bản nạp của Renode (SIM-20 §2).

    UART đi ra CONSOLE chứ không ra `CreateFileBackend @sim/uart.log` như §2 viết: engine chạy
    trong sandbox SEC-25 §2, nơi tiến trình chỉ ghi được vào thư mục làm việc TẠM của chính lần
    chạy ấy — một tệp dưới `sim/` sẽ bị từ chối, và nếu không bị từ chối thì nó nằm ở thư mục
    tạm mà `sim.run` không biết tên. Console thì `Sandbox` đã bắt sẵn vào `stdout_ref`. Xem
    DEVIATIONS DEV-085.
    """
    uart = next((p["name"].lower() for p in pho["modeled"] if p.get("kind") == "uart"), None)
    d = ["mach create",
         f"machine LoadPlatformDescription @{SIM_DIR}/platform.repl",
         "sysbus LoadELF ${artifact}"]
    if uart:
        d.append(f"showAnalyzer sysbus.{uart}")
    d.append('emulation RunFor "${duration}"')
    d.append("quit")
    return "\n".join(d) + "\n"


@capability("sim.build_platform")
def build_platform(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-01 — CDS-12.4; SIM-20 §1 (bảng chế độ), §2 (sinh nền tảng); TGT-19 `sim.engine`.
    tc: TC-34, TC-SM-01; lỗi E4001; grounding "Hộ chiếu vàng"; undo `delete_created_files`.

    Ba điều được quyết ở đây, và cả ba đều là quyết định "nói thật":

    1. **Engine chọn theo manifest ISA, không theo bảng trong mã.** `docs/spec/isa/*.yaml` đã
       khai `sim: {engine, fallback}`; chép lại sang Python là tạo bản thứ hai của cùng một sự
       thật (cùng lỗi mà DEV-043 ghi).
    2. **Thiếu cả engine chính lẫn đường lui → E4001 ngay**, không lặng lẽ rơi về `native`.
    3. **Ngoại vi không có mô hình vào `coverage.unsupported` kèm địa chỉ**, chứ không biến mất.
       Một `.repl` thiếu ngoại vi trông y hệt một `.repl` đủ, cho tới lúc firmware treo ở lần
       đọc thanh ghi đầu tiên — và lúc ấy người ta đi tìm lỗi trong mã.
    """
    root = _du_an(ctx)
    chip = params["chip"]
    board = params.get("board")
    isa = isa_cua_chip(chip)
    if not isa:
        from eide_core.paths import spec_dir
        raise EideError("E2000", f"Không suy được ISA cho `{chip}` — không khớp "
                        "`family_patterns` nào trong docs/spec/isa/",
                        exists=[f.stem for f in sorted((spec_dir() / "isa").glob("*.yaml"))],
                        candidates=["project.set_target"], missing=[f"ISA cho {chip}"])

    man = manifest_isa(isa)
    eng = chon_engine(isa, man, chip)
    nen = _facts_nen_tang(root, chip)
    if not nen["memory"]:
        raise EideError("E2000", f"Chưa có hộ chiếu vàng cho `{_iri_chip(chip)}`: không fact "
                        "`memory_size` nào đã duyệt — chạy `extract.svd` hoặc `registry.pull`",
                        exists=[], candidates=["extract.svd", "registry.pull"],
                        missing=[f"hộ chiếu vàng cho {_iri_chip(chip)}"])

    pho = _phu_song(chip, nen)
    d = _thu_muc_sim(root)
    tao: list[str] = []
    if eng["engine"] == "renode":
        _, ho = _ho_renode(chip)
        if not (ho or {}).get("nvic"):
            raise EideError("E4001", f"Renode chọn cho `{chip}` nhưng renode_models.yaml chưa có "
                            "họ chip này (SIM-20 §2)", missing=["renode_models.yaml"], isa=isa)
        (d / "platform.repl").write_text(_repl(chip, nen, pho, ho), encoding="utf-8")
        (d / "run.resc").write_text(_resc(pho), encoding="utf-8")
        tao += ["platform.repl", "run.resc"]

    mo_ta = {"chip": _iri_chip(chip), "board": board, "isa": isa,
             "engine": eng["engine"], "exe": eng["exe"],
             "memory": nen["memory"], "modeled": pho["modeled"],
             "unsupported": pho["unsupported"], "files": tao}
    (d / PLATFORM_JSON).write_text(json.dumps(mo_ta, ensure_ascii=False, indent=2),
                                   encoding="utf-8")

    coverage = {
        "engine_requested": eng["requested"], "fallback_used": eng["fallback"],
        "memory": nen["memory"],
        "modeled": [p["name"] for p in pho["modeled"]],
        "unsupported": pho["unsupported"],
        "mock_needed": [p["name"] for p in pho["unsupported"]],
        "cites": sorted(set(nen["cites"])),
        # Kênh quan sát mà engine này thật sự có. `sim.run` đọc đúng danh sách ấy để quyết định
        # một `expect` là chấm được hay `unverified` — nên "hứa" và "chấm" dùng chung một nguồn.
        "observes": sorted(KENH_QUAN_SAT.get(eng["engine"], ())),
    }
    return {"platform_dir": _tuong_doi(root, d), "engine": eng["engine"], "coverage": coverage}


# Kênh quan sát THẬT SỰ có của từng engine, theo hiện thực hôm nay — không theo điều engine có
# thể làm được về nguyên tắc. Renode có monitor đọc biến và Renode có GPIO analyzer; EIDE thì
# CHƯA nối vào cả hai (DEV-083). Bảng này nói điều thứ hai, vì đó mới là điều `sim.run` chấm
# được. Nới nó ra trước khi nối xong đường quan sát là cách nhanh nhất để có một bộ test xanh
# không kiểm gì.
KENH_QUAN_SAT: dict[str, tuple[str, ...]] = {
    "renode": ("uart",),
    "qemu": ("uart",),
    "simavr": ("uart",),
    ENGINE_NATIVE: ("uart",),
}


# ---------------------------------------------------------------- SIM-02 mock_peripheral

# Lớp nền của mock, nhúng THẲNG vào tệp sinh ra chứ không import từ `eide`.
#
# Mock phải chạy được ở hai nơi rất khác nhau: trong trình thông dịch Python nhúng của Renode
# (không có `eide` trên đường dẫn, không cài gói được) và trong bộ test của EIDE. Một tệp
# tự đứng được chạy ở cả hai; một tệp `from eide_core... import` thì chỉ chạy ở chỗ thứ hai —
# tức đúng chỗ không cần nó.
NEN_MOCK = '''
class I2CPeripheral:
    """Ngoại vi I2C slave tối thiểu: một con trỏ thanh ghi và một bảng thanh ghi.

    `Write([reg])` đặt con trỏ; `Write([reg, v, ...])` ghi tiếp từ đó; `Read(n)` đọc burst từ
    con trỏ. Đúng giao thức mà datasheet của BME280/MPU6050 mô tả, và cũng là hình dạng mà
    lớp `I2CPeripheral` của Renode đòi.
    """

    REGS = {}
    ADDRESS = None

    def __init__(self, source=None, noise=0.0):
        self.ptr = 0
        self.source = source
        self.noise = noise
        self.mem = {int(k): int(v.get("reset", 0)) for k, v in self.REGS.items()}

    def Write(self, data):
        data = list(data)
        if not data:
            return
        self.ptr = int(data[0]) & 0xFF
        for i, v in enumerate(data[1:]):
            r = (self.ptr + i) & 0xFF
            if self.REGS.get(r, {}).get("ro"):
                continue
            self.mem[r] = int(v) & 0xFF

    def Read(self, count=1):
        ra = []
        for i in range(int(count)):
            r = (self.ptr + i) & 0xFF
            ra.append(int(self.mem.get(r, 0)) & 0xFF)
        return ra

    def FinishTransmission(self):
        return None
'''


def _facts_linh_kien(root: Path, part: str) -> dict[str, Any]:
    """Địa chỉ + bảng thanh ghi của một linh kiện ngoài, từ hộ chiếu trong store."""
    db = store.store_path(root)
    goc = part if ":" in part else f"part:{part}"
    ra: dict[str, Any] = {"address": None, "regs": {}, "cites": [], "tam": []}
    if not db.exists():
        return ra
    with store.open_store(db) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value, tier, status FROM fact"
            " WHERE (subject = ? OR subject LIKE ?)"
            "   AND predicate IN ('address','offset','reset_value','access')"
            "   AND status NOT IN ('superseded','rejected')"
            " ORDER BY subject, predicate", (goc, goc + "/%")).fetchall()
    for fid, subj, vi_tu, gt, tier, trang_thai in rows:
        try:
            v = json.loads(gt)
        except (ValueError, TypeError):
            continue
        da_duyet = tier == "gold" or trang_thai in ("reviewed", "verified")
        if vi_tu == "address" and subj == goc:
            ra["address"] = v
            ra["cites"].append(fid)
            if not da_duyet:
                ra["tam"].append("address")
        elif (m := re.search(r"/reg:([A-Za-z0-9_]+)$", subj)):
            ten = m.group(1)
            ra["regs"].setdefault(ten, {})[vi_tu] = v
            ra["cites"].append(fid)
            if not da_duyet:
                ra["tam"].append(f"reg:{ten}")
    return ra


def _skill_cong_thuc(root: Path, part: str) -> tuple[Path, str] | None:
    """Skill K5 của `extract.pdf_formula` áp cho linh kiện này, và đoạn mã C trong đó.

    Front-matter `applies_to` là chỗ duy nhất nói skill thuộc về linh kiện nào (EXTRACT-11); dò
    theo tên tệp thì một skill tên `bme280-…` của chip khác cũng khớp.
    """
    thu_muc = root / EIDE_DIR / "skills"
    if not thu_muc.is_dir():
        return None
    ten = part.split(":", 1)[-1]
    for f in sorted(thu_muc.glob("*.md")):
        t = f.read_text(encoding="utf-8", errors="replace")
        if not t.startswith("---"):
            continue
        fm = yaml.safe_load(t.split("---", 2)[1]) or {}
        ap = [str(x).split(":", 1)[-1] for x in (fm.get("applies_to") or [])]
        if ten not in ap:
            continue
        if (m := re.search(r"```c\n(.*?)```", t, re.S)):
            return f, m.group(1)
    return None


_SCHEMA_CONG_THUC = {
    "type": "object", "required": ["name", "python"],
    "properties": {"name": {"type": "string"}, "python": {"type": "string"},
                   "inputs": {"type": "array", "items": {"type": "string"}}},
}


def _dich_cong_thuc(gw: Any, part: str, ma_c: str) -> dict[str, Any]:
    """Công thức C của datasheet → một hàm Python dùng được trong mock.

    Kiểm bằng `ast.parse` chứ không bằng `exec`: chạy mã mô hình vừa viết để xem nó có chạy
    không là mời đúng thứ SEC-25 §4 cấm vào giữa tiến trình cha.
    """
    import ast

    resp = gw.run("coder",
                  f"Chuyển công thức C sau của `{part}` sang MỘT hàm Python thuần (chỉ dùng "
                  "thư viện chuẩn, không import ngoài). Giữ nguyên phép tính và tên biến của "
                  f"datasheet.\n\n```c\n{ma_c}\n```",
                  _SCHEMA_CONG_THUC)
    d = dict(resp.data)
    try:
        cay = ast.parse(d["python"])
    except SyntaxError as e:
        raise EideError("E5002", f"Công thức mô hình trả về không phải Python hợp lệ: {e}",
                        part=part) from e
    ham = [n.name for n in cay.body if isinstance(n, ast.FunctionDef)]
    if d["name"] not in ham:
        raise EideError("E5002", f"Mô hình khai hàm `{d['name']}` nhưng mã chỉ định nghĩa "
                        f"{ham or 'không hàm nào'}", part=part, functions=ham)
    return d


def _ma_mock(part: str, dl: dict[str, Any], cong_thuc: dict[str, Any] | None,
             tam: list[str]) -> str:
    ten_lop = re.sub(r"[^A-Za-z0-9]+", " ", part.split(":", 1)[-1]).title().replace(" ", "")
    regs = {}
    for ten, d in sorted(dl["regs"].items()):
        if (off := d.get("offset")) is None:
            continue
        # `ro` chỉ đặt khi CÓ fact `access` nói thế. Không fact nào nói thì mock cho ghi mọi
        # thanh ghi — và hệ quả phải nói ra: nó KHÔNG bắt được lỗi firmware ghi vào vùng chỉ-đọc.
        # Đoán "thanh ghi ID chắc là chỉ-đọc" thì đúng với BME280 và sai với con sau đó.
        regs[int(off)] = {"name": ten, "reset": int(d.get("reset_value") or 0),
                          "ro": str(d.get("access") or "").lower() in ("ro", "r", "read-only")}
    dong = [f'"""Mock `{part}` — sinh bởi sim.mock_peripheral (SIM-02; SIM-20 §3).',
            "",
            "Bảng thanh ghi lấy TỪ HỘ CHIẾU trong store, không gõ tay: mỗi khoá dưới đây trỏ về",
            "một fact. Tham số không có nguồn nằm trong `PROVISIONAL` và phải hiện lên SimView",
            'như "tham số tạm" (SIM-20 §6).',
            '"""',
            "from __future__ import annotations",
            "",
            f"PART = {part!r}",
            f"ADDRESS = {dl['address']!r}",
            f"PROVISIONAL = {sorted(set(tam))!r}",
            f"CITES = {sorted(set(dl['cites']))!r}",
            "",
            "REGS = {",
            *[f"    {hex(k)}: {v!r},   # {v['name']}" for k, v in sorted(regs.items())],
            "}",
            NEN_MOCK,
            "",
            f"class {ten_lop}Mock(I2CPeripheral):",
            "    REGS = REGS",
            "    ADDRESS = ADDRESS",
            ""]
    if cong_thuc:
        dong += ["    # Công thức của datasheet, dịch từ skill K5 — xem `source` trong skill.",
                 *[f"    {d}" if d.strip() else "" for d in cong_thuc["python"].splitlines()],
                 ""]
    else:
        dong += ["    # Chưa có công thức: mock chỉ trả giá trị reset của thanh ghi. Đọc ID vẫn",
                 "    # đúng, nhưng dữ liệu đo thì KHÔNG — đừng dùng nó để kiểm thuật toán bù.",
                 ""]
    return "\n".join(dong) + "\n"


@capability("sim.mock_peripheral")
def mock_peripheral(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-02 — CDS-12.4; SIM-20 §3 (mock ngoại vi ngoài từ fact); EXTRACT-11 (skill K5
    chứa công thức). tc: TC-SM-02 "Đọc ID trả 0x60"; lỗi E5002; undo `delete_created_files`.

    **Bảng thanh ghi sinh từ fact, công thức sinh từ skill.** Hai nguồn khác nhau vì hai loại
    tri thức khác nhau (KAD-07 §5.1): địa chỉ và giá trị reset là FACT — tra được, đối chiếu
    được; còn công thức bù nhiệt là THỦ TỤC, và EXTRACT-11 đã quyết định thủ tục thành K5 chứ
    không thành fact. Mock cần cả hai, nên nó đọc cả hai chỗ.

    Không có công thức thì mock vẫn sinh ra, và đó là lựa chọn có chủ đích: đọc ID và bảng thanh
    ghi đã đủ cho phần lớn kịch bản bringup (firmware dò được cảm biến chưa?). Điều phải nói
    thẳng là dữ liệu ĐO thì chưa mô phỏng được — nên tệp sinh ra ghi câu ấy vào chính nó, chỗ
    người đọc mã mock sẽ nhìn thấy.
    """
    root = _du_an(ctx)
    part = params["part"]
    goc = part if ":" in part else f"part:{part}"
    dl = _facts_linh_kien(root, goc)
    if not dl["regs"] and dl["address"] is None:
        raise EideError("E2000", f"Không có fact nào cho `{goc}` — cần `extract.pdf_register_map` "
                        "hoặc `registry.pull` trước", exists=[],
                        candidates=["extract.pdf_register_map", "registry.pull"],
                        missing=[goc])

    tam = list(dl["tam"])
    cong_thuc = None
    if (ct := _skill_cong_thuc(root, goc)):
        gw = ctx.extra.get("gateway")
        if gw is None:
            from eide_core.gateway import Gateway
            gw = Gateway(ledger=ctx.extra.get("ledger"))
        cong_thuc = _dich_cong_thuc(gw, goc, ct[1])
    else:
        tam.append("formula")

    d = _thu_muc_sim(root) / "mocks"
    d.mkdir(parents=True, exist_ok=True)
    ten = re.sub(r"[^a-z0-9]+", "_", goc.split(":", 1)[-1].lower()).strip("_")
    p = d / f"{ten}.py"
    p.write_text(_ma_mock(goc, dl, cong_thuc, tam), encoding="utf-8")

    return {"mock_path": _tuong_doi(root, p),
            "params": {"address": dl["address"], "registers": len(dl["regs"]),
                       "noise": 0.02, "formula": (cong_thuc or {}).get("name"),
                       "provisional": sorted(set(tam)), "cites": sorted(set(dl["cites"]))}}


# ---------------------------------------------------------------- SIM-03 model_plant

# Tham số mặc định của robot hai bánh tự cân bằng — SIM-20 §4 viết đúng dãy này:
# "{M: 0.8, m: 0.05, l: 0.06, r: 0.0325, I: 1.9e-3, J: 2.6e-5, g: 9.81, dt: 0.001}".
#
# `g` và `dt` KHÔNG nằm trong `provisional` khi lấy mặc định: gia tốc trọng trường không phải
# thứ chờ ai đo, và bước tích phân là lựa chọn của mô hình chứ không phải thuộc tính của robot.
# Sáu tham số còn lại thì phải đo — SIM-20 §4 nói thẳng "nhãn tạm cho tới khi người đo".
THAM_SO_PLANT: dict[str, dict[str, Any]] = {
    "balancing-robot": {"M": 0.8, "m": 0.05, "l": 0.06, "r": 0.0325,
                        "I": 1.9e-3, "J": 2.6e-5, "g": 9.81, "dt": 0.001},
}
KHONG_CAN_DO = ("g", "dt")

# PID tham chiếu của TC-SM-03 ("PID chuẩn tham chiếu → ổn định ≤ 1,5 s sau nhiễu 5°"). Đo trên
# chính mô hình sinh ra: nhiễu 5° → |θ| < 1° và đứng yên sau 0,099 s, thân xe dịch 2,2 cm. Bộ
# số này không nằm ở mép vực — mọi kp trong khoảng 5…20 đều ổn định dưới 0,15 s — nên nó là một
# mốc tham chiếu, không phải một nghiệm may mắn.
PID_THAM_CHIEU = {"kp": 8.0, "kd": 0.1, "kx": 0.3, "kv": 0.3, "tau_max": 0.2}

MA_PLANT = '''"""Mô hình đối tượng `{template}` — sinh bởi sim.model_plant (SIM-03; SIM-20 §4).

Con lắc ngược trên xe hai bánh: trạng thái x = [phi_x, phi_xd, theta, theta_d] với `theta` là
góc thân (rad, 0 = thẳng đứng) và `phi_x = r·phi` là quãng đường bánh lăn (m). Đầu vào là
mô-men bánh `tau` (N·m). Tích phân RK4 bước `dt`, đồng bộ với tick mô phỏng chip.

Tham số mang nhãn `PROVISIONAL` là tham số CHƯA AI ĐO. Đọc kết quả của một mô hình có nhãn tạm
mà quên mất điều đó là cách nhanh nhất để tin vào một con số không ai chịu trách nhiệm.
"""
from __future__ import annotations

import math

PARAMS = {params!r}
PROVISIONAL = {provisional!r}
PID_REF = {pid!r}


def deriv(x, tau, p=PARAMS):
    """f(x, tau) — phương trình chuyển động phi tuyến (SIM-20 §4).

    Khối lượng quy đổi của phần bánh gồm cả quán tính quay: m_c = 2m + J/r². Bỏ số hạng J/r²
    là bỏ đúng phần khiến bánh nhỏ khó điều khiển hơn bánh to.
    """
    _, xd, th, thd = x
    mc = 2 * p["m"] + p["J"] / p["r"] ** 2
    M, l, I, g = p["M"], p["l"], p["I"], p["g"]
    F = tau / p["r"]
    a11 = mc + M
    a12 = M * l * math.cos(th)
    a22 = I + M * l * l
    b1 = F + M * l * math.sin(th) * thd * thd
    b2 = M * g * l * math.sin(th)
    det = a11 * a22 - a12 * a12
    return [xd, (b1 * a22 - a12 * b2) / det, thd, (a11 * b2 - b1 * a12) / det]


def step(x, tau, p=PARAMS):
    """Một bước RK4."""
    dt = p["dt"]
    k1 = deriv(x, tau, p)
    k2 = deriv([x[i] + dt / 2 * k1[i] for i in range(4)], tau, p)
    k3 = deriv([x[i] + dt / 2 * k2[i] for i in range(4)], tau, p)
    k4 = deriv([x[i] + dt * k3[i] for i in range(4)], tau, p)
    return [x[i] + dt / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) for i in range(4)]


def sensors(x):
    """Điều MPU6050 mock đọc được: góc thân, tốc độ góc, và hai trục gia tốc kế."""
    _, _, th, thd = x
    return {{"theta": th, "gyro_y": thd,
            "accel_x": -9.81 * math.sin(th), "accel_z": 9.81 * math.cos(th)}}


def actuator(step_rate, direction, p=PARAMS):
    """A4988: bước/giây × chiều → mô-men. Bão hòa ở `tau_max` của PID tham chiếu."""
    tau = direction * step_rate * p["r"] * 1e-4
    return max(-PID_REF["tau_max"], min(PID_REF["tau_max"], tau))


def pid(x, gains=None):
    """Bộ điều khiển tham chiếu — dùng để KIỂM mô hình, không phải để nạp vào firmware."""
    g = dict(PID_REF)
    g.update(gains or {{}})
    tau = g["kp"] * x[2] + g["kd"] * x[3] + g["kx"] * x[0] + g["kv"] * x[1]
    return max(-g["tau_max"], min(g["tau_max"], tau))


def run(theta0_deg=5.0, duration_s=3.0, gains=None, controlled=True, p=PARAMS):
    """Chạy mô hình, trả {{settle_s, fallen_s, max_abs_theta, samples}}.

    `settle_s` = lúc SỚM NHẤT mà từ đó tới hết lượt chạy, |θ| < 1° và xe gần như đứng yên. Đo
    "lần đầu chạm ngưỡng" thay vì "chạm và ở lại" sẽ cho một con số đẹp cho một mô hình đang
    dao động qua ngưỡng — nó chạm 0 mỗi nửa chu kỳ.
    """
    x = [0.0, 0.0, math.radians(theta0_deg), 0.0]
    t, settle, fallen, max_th, mau = 0.0, None, None, 0.0, []
    while t < duration_s:
        tau = pid(x, gains) if controlled else 0.0
        x = step(x, tau, p)
        t += p["dt"]
        max_th = max(max_th, abs(x[2]))
        mau.append((round(t, 6), x[2], x[0]))
        if fallen is None and abs(x[2]) > math.radians(45):
            fallen = t
            if not controlled:
                break
        on_dinh = abs(x[2]) < math.radians(1) and abs(x[3]) < 0.5 and abs(x[1]) < 0.2
        settle = (settle if settle is not None else t) if on_dinh else None
    return {{"settle_s": settle, "fallen_s": fallen, "max_abs_theta": max_th, "samples": mau}}
'''


@capability("sim.model_plant")
def model_plant(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-03 — CDS-12.4; SIM-20 §4 (mô hình robot hai bánh). tc: TC-SM-03 "Không điều
    khiển đổ < 1 s; PID tham chiếu ổn định ≤ 1,5 s"; Z-09 "nhãn tạm cho khối lượng";
    undo `delete_created_files`.

    **`provisional` là phần đáng giá nhất của năng lực này.** Một mô hình động lực học luôn cho
    ra số — đẹp, mượt, có đơn vị — bất kể tham số của nó đến từ phép đo hay từ một mẫu tham
    chiếu. Thứ phân biệt hai trường hợp ấy chỉ có thể là một nhãn đi kèm, và SIM-20 §6 nối nhãn
    ấy thẳng lên SimView cùng ô nhập giá trị đo được.

    Tham số người gọi truyền vào KHÔNG mang nhãn tạm, kể cả khi nó trùng giá trị mặc định: nhãn
    nói về NGUỒN của con số, không về giá trị của nó.
    """
    root = _du_an(ctx)
    template = params.get("template") or "balancing-robot"
    if template not in THAM_SO_PLANT:
        raise EideError("E2000", f"Chưa có mẫu plant `{template}` — SIM-20 §4 mô tả "
                        f"{list(THAM_SO_PLANT)}", exists=list(THAM_SO_PLANT),
                        candidates=list(THAM_SO_PLANT), missing=[template])

    nguoi = dict(params.get("params") or {})
    mac_dinh = THAM_SO_PLANT[template]
    la = [k for k in mac_dinh if k not in nguoi]
    if (thua := sorted(set(nguoi) - set(mac_dinh))):
        raise EideError("E1000", f"Tham số không thuộc mẫu `{template}`: {thua}", extra=thua)
    dung = {**mac_dinh, **{k: float(v) for k, v in nguoi.items()}}
    tam = sorted(k for k in la if k not in KHONG_CAN_DO)

    d = _thu_muc_sim(root) / "plant"
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{re.sub(r'[^a-z0-9]+', '_', template.lower()).strip('_')}.py"
    p.write_text(MA_PLANT.format(template=template, params=dung, provisional=tam,
                                 pid=PID_THAM_CHIEU), encoding="utf-8")
    return {"model_path": _tuong_doi(root, p), "params_used": dung, "provisional": tam}


# ---------------------------------------------------------------- SIM-04 scenario

# PLAN-01 `expectation.kind` → `expect.kind` của kịch bản (SIM-20 §5).
#
# Ba dạng kỳ vọng mà `plan.define_feature` cho phép ánh xạ sang ba kênh quan sát khác nhau, và
# ánh xạ này là chỗ hai tài liệu gặp nhau: `serial_pattern` là UART; `probe_reg` là "đọc biến
# qua GDB stub/monitor" mà §5 gọi là `var` (§5 cũng nói chính nó thành `probe` khi chạy HIL);
# `measurement` là số đo vật lý, tức tín hiệu của plant chứ không của chip.
KY_VONG_SANG_EXPECT = {"serial_pattern": "uart", "probe_reg": "var", "measurement": "plant"}

_SCHEMA_KICH_BAN = {
    "type": "object", "required": ["expect"],
    "properties": {
        "expect": {"type": "array", "minItems": 1, "items": {
            "type": "object", "required": ["kind"],
            "properties": {"kind": {"type": "string",
                                    "enum": ["uart", "var", "gpio", "plant"]},
                           "pattern": {"type": "string"}, "symbol": {"type": "string"},
                           "pin": {"type": "string"}, "signal": {"type": "string"},
                           "within_s": {"type": "number"}, "after_s": {"type": "number"},
                           "abs_lt": {"type": "number"}, "toggles_min": {"type": "integer"},
                           "window_s": {"type": "number"}}}},
        "inject": {"type": "array", "items": {"type": "object"}},
        "duration_s": {"type": "number"},
    },
}

# Trường bắt buộc của từng loại `expect`. Thiếu nó thì dòng ấy không chấm được — mà một dòng
# expect không chấm được nằm im trong kịch bản là đúng thứ làm cả bảng kết quả mất nghĩa.
TRUONG_BAT_BUOC = {"uart": ("pattern",), "var": ("symbol",), "gpio": ("pin",),
                   "plant": ("signal",)}


def _doc_feature(root: Path, ma: str) -> dict[str, Any] | None:
    f = root / EIDE_DIR / "FEATURES.json"
    if not f.exists():
        return None
    ds = json.loads(f.read_text(encoding="utf-8"))
    ds = ds if isinstance(ds, list) else (ds.get("features") or [])
    return next((x for x in ds if str(x.get("id")) == ma), None)


def _init_kich_ban(root: Path, mo_ta: dict[str, Any]) -> dict[str, Any]:
    """Khối `init` của SIM-20 §5: plant, mock, cổng UART — lấy từ những gì ĐÃ dựng trong `sim/`.

    Không hỏi mô hình phần này: mock nào tồn tại và plant nào tồn tại là sự thật của thư mục,
    và một mô hình rất sẵn lòng kê ra `mpu6050` cho một dự án chưa hề trích datasheet nào.
    """
    d = root / SIM_DIR
    mocks = sorted(p.stem for p in (d / "mocks").glob("*.py")) if (d / "mocks").is_dir() else []
    plants = sorted(p.stem for p in (d / "plant").glob("*.py")) if (d / "plant").is_dir() else []
    uart = next((p["name"] for p in (mo_ta.get("modeled") or []) if p.get("kind") == "uart"), None)
    baud = ((manifest_isa(mo_ta["isa"]).get("serial") or {}).get("default_baud") or 115200) \
        if mo_ta.get("isa") else 115200
    init: dict[str, Any] = {"mocks": mocks}
    if plants:
        init["plant"] = plants[0]
    if uart:
        init["uart"] = {"port": uart, "baud": baud}
    return init


@capability("sim.scenario")
def scenario(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-04 — CDS-12.4; SIM-20 §5 (định dạng kịch bản); PLAN-01 (`expectation` máy quan
    sát được). tc: "Kịch bản chạy được ở sim.run"; lỗi E5002; undo `delete_created_files`.

    **Loại kỳ vọng do MÃ quyết, chi tiết do mô hình viết.** `plan.define_feature` đã ép
    `expectation.kind` về ba dạng máy quan sát được; ánh xạ ba dạng ấy sang kênh của SIM-20 §5
    là một bảng, không phải một phán đoán. Cái mô hình làm được mà bảng không làm được là đọc
    câu tiếng Việt "in `IMU ok` trong 1 giây đầu" ra thành `pattern` và `within_s`.

    Vì thế phép kiểm sau khi mô hình trả lời không hỏi "câu trả lời có hợp lý không" mà hỏi hai
    câu đóng: loại có đúng loại bảng đã định không, và trường bắt buộc của loại ấy có mặt không.
    Sai một trong hai là E5002 — kịch bản thiếu `pattern` vẫn chạy được ở `sim.run` và vẫn cho
    ra một bảng kết quả, chỉ là bảng ấy không kiểm gì.
    """
    root = _du_an(ctx)
    ma = params["feature"]
    ft = _doc_feature(root, ma)
    if not ft:
        raise EideError("E2000", f"Không có feature `{ma}` trong .eide/FEATURES.json — "
                        "`plan.define_feature` trước", exists=[],
                        candidates=["plan.define_feature"], missing=[f"feature/{ma}"])
    ky_vong = ft.get("expectation") or {}
    loai = KY_VONG_SANG_EXPECT.get(ky_vong.get("kind"))
    if not loai:
        raise EideError("E2000", f"expectation.kind=`{ky_vong.get('kind')}` không ánh xạ được "
                        f"sang kênh nào của SIM-20 §5 ({list(KY_VONG_SANG_EXPECT)})",
                        exists=[], candidates=list(KY_VONG_SANG_EXPECT), missing=["expectation"])

    f_mo_ta = root / SIM_DIR / PLATFORM_JSON
    if not f_mo_ta.exists():
        raise EideError("E2000", "Chưa dựng nền tảng mô phỏng — `sim.build_platform` trước",
                        exists=[], candidates=["sim.build_platform"], missing=[SIM_DIR + "/" + PLATFORM_JSON])
    mo_ta = json.loads(f_mo_ta.read_text(encoding="utf-8"))

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    resp = gw.run("planner",
                  f"Feature `{ma}`: {ft.get('title') or ''}\n"
                  f"Kỳ vọng ({ky_vong.get('kind')}): {ky_vong.get('detail')}\n"
                  f"Ràng buộc: {'; '.join(str(x) for x in (ft.get('constraints') or [])) or '—'}\n\n"
                  f"Viết khối `expect` và `inject` của một kịch bản mô phỏng (SIM-20 §5). Mọi "
                  f"dòng `expect` phải mang kind=`{loai}`.",
                  _SCHEMA_KICH_BAN)
    d = dict(resp.data)

    exp = list(d.get("expect") or [])
    if any(e.get("kind") != loai for e in exp):
        raise EideError("E5002", f"Kỳ vọng `{ky_vong.get('kind')}` phải thành expect kind="
                        f"`{loai}`, mô hình trả {sorted({e.get('kind') for e in exp})}",
                        feature=ma, expected=loai)
    for e in exp:
        if (thieu := [k for k in TRUONG_BAT_BUOC[loai] if not e.get(k)]):
            raise EideError("E5002", f"expect kind=`{loai}` thiếu {thieu} — dòng ấy không chấm "
                            "được", feature=ma, missing=thieu)

    kb = {
        "id": f"{ma}-basic",
        "engine": mo_ta["engine"],
        "artifact": None,
        "duration_s": float(d.get("duration_s") or 5),
        "init": _init_kich_ban(root, mo_ta),
        "inject": list(d.get("inject") or []),
        "expect": exp,
        "record": sorted({e["kind"] for e in exp} | {"uart"}),
        "feature": ma,
    }
    p = _thu_muc_sim(root) / f"{ma.lower()}.yaml"
    p.write_text(yaml.safe_dump(kb, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return {"scenario_path": _tuong_doi(root, p)}


# ---------------------------------------------------------------- SIM-05 run

# Máy ảo của QEMU theo họ chip. QEMU không dựng nền tảng từ mô tả như Renode: nó chỉ chạy những
# bo mạch đã biên dịch sẵn vào chương trình, nên "có qemu" KHÔNG có nghĩa là chạy được chip này.
# Không có mục trong bảng thì engine ấy coi như KHÔNG dùng được, và `chon_engine` đi tiếp —
# thay vì sinh ra một nền tảng chạy lên là báo "machine không tồn tại".
#
# Gán một máy ảo "gần giống" (STM32F411 → netduinoplus2, vốn là STM32F405) sẽ chạy, và đó mới là
# điều nguy hiểm: firmware chạy trên một con chip khác với chip nó được dịch cho, rồi báo ĐẠT.
QEMU_MACHINE: dict[str, dict[str, str]] = {
    "^ATmega328": {"machine": "arduino-uno", "nap": "-bios"},
    "^ATmega2560": {"machine": "arduino-mega-2560-v3", "nap": "-bios"},
    "^ATmega1280": {"machine": "arduino-mega", "nap": "-bios"},
    "^ATmega168": {"machine": "arduino-duemilanove", "nap": "-bios"},
    # RISC-V: máy ảo `virt` — CHUNG cho mọi rv32, không phải mô hình của con chip nào.
    #
    # Khác hẳn bốn dòng trên: `arduino-uno` LÀ một ATmega328P có ngoại vi đúng như silicon, nên
    # một `expect` về thanh ghi TWI chấm được. `virt` thì chỉ có CPU, bộ nhớ và một UART 16550
    # ở 0x10000000 — nó không có I2C của ESP32-C3, không có ADC, không có Wi-Fi. Mọi `expect`
    # chạm ngoại vi thật sẽ ra `unverified`, và đó là câu trả lời ĐÚNG chứ không phải thiếu sót
    # của bảng này.
    #
    # Đường mô phỏng ESP32-C3 THẬT là bản QEMU riêng của Espressif (`qemu-system-riscv32` có
    # máy `esp32c3`), không nằm trong gói `qemu` của Homebrew. Khai `virt` cho phép chạy chuỗi
    # dựng→mô phỏng với mã rv32 chung; khai máy `esp32c3` khi chưa có bản QEMU ấy thì `sim.run`
    # chết ở `-M esp32c3: unsupported machine type` sau khi đã dựng xong nền tảng.
    "^ESP32-?C[0-9]": {"machine": "virt", "nap": "-kernel"},
    "^ESP32-?H[0-9]": {"machine": "virt", "nap": "-kernel"},
    "^GD32V": {"machine": "virt", "nap": "-kernel"},
    "^CH32V": {"machine": "virt", "nap": "-kernel"},
    "^RV32": {"machine": "virt", "nap": "-kernel"},
    "^FE310": {"machine": "sifive_e", "nap": "-kernel"},
}

# Engine có tự dừng khi hết thời gian mô phỏng hay không.
#
# Renode dừng vì `.resc` kết thúc bằng `quit`; một chương trình native dừng khi `main` trả về.
# QEMU và simavr thì chạy mãi — firmware nhúng không bao giờ thoát, đó là điểm của nó. Với hai
# engine ấy, HẾT GIỜ CHÍNH LÀ CÁCH LƯỢT CHẠY KẾT THÚC, nên biến nó thành E4004 là báo lỗi cho
# một lượt chạy hoàn toàn bình thường.
TU_DUNG = {"renode": True, ENGINE_NATIVE: True, "qemu": False, "simavr": False}

BIEN_THOI_GIAN_S = 20      # chỗ cho engine khởi động và nạp ELF, ngoài `duration_s` của kịch bản


def _may_qemu(chip: str) -> dict[str, str] | None:
    ten = _iri_chip(chip)[len("chip:"):].rsplit(".", 1)[-1]
    for pat, d in QEMU_MACHINE.items():
        if re.search(pat, ten, re.I):
            return d
    return None


def _argv(mo_ta: dict[str, Any], exe: str, artifact: Path, kb: dict[str, Any],
          root: Path) -> list[str]:
    """Dòng lệnh của engine. Danh sách chuỗi, không phải chuỗi shell (PLATFORM.md quy tắc 3).

    **Manifest ISA nói trước.** `docs/spec/isa/<isa>.yaml` có trường `sim.cmd`, và khi nó có mặt
    thì nó LÀ dòng lệnh — không phải một gợi ý mà mã dựng lại theo trí nhớ. Trước 14/09/2026 mã
    này dựng tay mọi lệnh qemu và không đọc `sim.cmd` bao giờ, nên `-bios none` của rv32imac
    không tới được qemu: máy `virt` nạp OpenSBI mặc định ở 0x80000000, đúng chỗ linker script
    đặt firmware, và lượt chạy chết bằng "Some ROM regions are overlapping" — một lỗi trông như
    lỗi của người viết firmware. Không ai thấy sớm hơn vì armv7e-m và avr8 không khai `cmd`, nên
    với chúng hai đường trùng nhau. Xem DEV-101.
    """
    engine = mo_ta["engine"]
    thoi_luong = float(kb.get("duration_s") or 5)
    if (tay := _argv_manifest(mo_ta, exe, artifact, thoi_luong)) is not None:
        return tay
    if engine == "renode":
        resc = root / SIM_DIR / "run.resc"
        mau = resc.read_text(encoding="utf-8") if resc.exists() else _resc({"modeled": []})
        chay = root / SIM_DIR / ".run.resc"
        chay.write_text(mau.replace("${artifact}", f"@{artifact}")
                           .replace("${duration}", str(thoi_luong)), encoding="utf-8")
        return [exe, "--disable-xwt", "--plain", "--console", str(chay)]
    if engine == "qemu":
        may = _may_qemu(mo_ta["chip"])
        if not may:
            raise EideError("E4001", f"qemu không có máy ảo cho `{mo_ta['chip']}` — xem "
                            "QEMU_MACHINE trong sim.py", missing=["qemu machine"],
                            chip=mo_ta["chip"])
        return [exe, "-machine", may["machine"], "-nographic", "-serial", "mon:stdio",
                "-no-reboot", may["nap"], str(artifact)]
    if engine == "simavr":
        return [exe, "-m", str(mo_ta.get("mcu") or mo_ta["chip"].rsplit(".", 1)[-1]),
                str(artifact)]
    return [str(artifact)]


def _argv_manifest(mo_ta: dict[str, Any], exe: str, artifact: Path,
                   thoi_luong: float) -> list[str] | None:
    """`sim.cmd` của manifest ISA → argv, hoặc None nếu manifest không khai.

    Thay chương trình đầu dòng bằng `exe` đã dò được: manifest viết `qemu-system-riscv32` trần,
    còn `_tim_exe` mới biết nó nằm ở đâu trên máy này (`/opt/homebrew/bin` hay `/usr/bin`) — và
    PLATFORM.md không cho hard-code đường dẫn. Nhưng THAM SỐ thì lấy nguyên của manifest: đó là
    chỗ đặc tả nói firmware nạp kiểu gì, và mã đoán lại là cách hai bên lệch nhau.
    """
    man = manifest_isa(mo_ta.get("isa") or "") or {}
    cmd = ((man.get("sim") or {}).get("cmd") or "").strip()
    if not cmd:
        return None
    phan = shlex.split(cmd)
    ra = [exe]
    for x in phan[1:]:
        ra.append(x.replace("{artifact}", str(artifact))
                   .replace("{duration}", str(thoi_luong)))
    return ra


def _cham_expect(kb: dict[str, Any], uart: list[str], engine: str) -> list[dict[str, Any]]:
    """Bảng `expect ↔ kết quả` của SIM-20 §5. Ba trạng thái, không phải hai.

    `unverified` tồn tại vì hai câu hỏi khác nhau không được trộn: "firmware làm sai" và "EIDE
    chưa nhìn thấy được". Gộp chúng thành `failed` thì người ta đi sửa firmware cho một chỗ
    không hỏng; gộp thành `passed` thì tệ hơn nhiều.

    **`within_s` chấm được khi và chỉ khi nó không nhỏ hơn thời lượng cả lượt chạy.** Log console
    không mang mốc thời gian theo dòng, nên không biết dòng ấy in ra ở giây thứ mấy — nhưng nếu
    cả lượt chạy chỉ dài `duration_s` và `within_s ≥ duration_s` thì MỌI dòng đều xuất hiện trong
    hạn, và kết luận là chắc chắn. Nhỏ hơn thì chưa biết, và chưa biết thì nói là chưa biết.
    """
    thoi_luong = float(kb.get("duration_s") or 5)
    kenh = KENH_QUAN_SAT.get(engine, ())
    ra = []
    for e in kb.get("expect") or []:
        loai = e.get("kind")
        if loai not in kenh:
            ra.append({**e, "status": "unverified",
                       "reason": f"engine `{engine}` chưa có kênh quan sát `{loai}` (DEV-083)"})
            continue
        mau = str(e.get("pattern") or "")
        thay = [d for d in uart if re.search(mau, d)]
        if not thay:
            ra.append({**e, "status": "failed", "reason": f"không thấy `{mau}` trong UART"})
        elif e.get("within_s") is not None and float(e["within_s"]) < thoi_luong:
            ra.append({**e, "status": "unverified",
                       "reason": f"within_s={e['within_s']} < duration_s={thoi_luong} mà log "
                                 "console không có mốc thời gian theo dòng (DEV-085)"})
        else:
            ra.append({**e, "status": "passed", "matched": thay[0][:200]})
    return ra


def _doc_log(ref: str | None) -> list[str]:
    if not ref or not Path(ref).exists():
        return []
    return [d for d in Path(ref).read_text(encoding="utf-8", errors="replace").splitlines()
            if d.strip()]


def _nen_tang(root: Path) -> dict[str, Any]:
    f = root / SIM_DIR / PLATFORM_JSON
    if not f.exists():
        raise EideError("E2000", "Chưa dựng nền tảng mô phỏng — `sim.build_platform` trước",
                        exists=[], candidates=["sim.build_platform"],
                        missing=[f"{SIM_DIR}/{PLATFORM_JSON}"])
    return json.loads(f.read_text(encoding="utf-8"))


def chay_kich_ban(root: Path, ctx: Context, artifact: Path, kb: dict[str, Any],
                  mo_ta: dict[str, Any]) -> dict[str, Any]:
    """Một lượt chạy engine, trả `{exit_code, uart[], duration_ms, log_ref, het_gio}`.

    Tách khỏi `run` vì `sim.sweep` chạy cùng đường này nhiều lần; gọi `sim.run` qua Router cho
    mỗi ô lưới sẽ sinh một `capability_run` và một mục hoàn tác cho từng ô, làm ngập nhật ký
    bằng thứ không ai muốn hoàn tác riêng lẻ.
    """
    from eide.caps.env import sandbox as env_sandbox

    engine = mo_ta["engine"]
    exe = _tim_exe(engine, mo_ta.get("isa") or "", mo_ta.get("chip") or "")
    if exe is None:
        raise EideError("E4001", f"Thiếu engine `{engine}` — `env.guide_install`",
                        missing=[engine], remedy="env.guide_install")
    argv = _argv(mo_ta, str(exe), artifact, kb, root)
    han = int(float(kb.get("duration_s") or 5)) + BIEN_THOI_GIAN_S

    t0 = time.perf_counter()
    het_gio = False
    try:
        kq = env_sandbox({"cmd": argv, "network": False, "allowed_dirs": [str(root)],
                          "limits": {"wall_s": han}}, ctx)
        ma, log_ref, err_ref = kq["exit_code"], kq["stdout_ref"], kq["stderr_ref"]
    except EideError as e:
        if e.code != "E4004" or TU_DUNG.get(engine, True):
            raise
        # Engine không tự dừng: hết giờ CHÍNH LÀ cách lượt chạy kết thúc (xem `TU_DUNG`).
        het_gio, ma = True, 0
        log_ref, err_ref = e.data.get("stdout_ref"), e.data.get("stderr_ref")
    return {"exit_code": ma, "uart": _doc_log(log_ref), "log_ref": log_ref,
            "err_ref": err_ref, "het_gio": het_gio,
            "duration_ms": int((time.perf_counter() - t0) * 1000)}


@capability("sim.run")
def run(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-05 — CDS-12.4; SIM-20 §5 (kịch bản, bảng expect ↔ kết quả); SEC-25 §2 (sandbox).
    tc: TC-34, TC-SM-04; lỗi E4000, E4004; `undo: none`.

    **`passed` chỉ đúng khi MỌI dòng expect được chấm và đạt.** Một dòng `unverified` — kênh
    quan sát chưa nối, hay một hạn thời gian không suy ra được từ log — kéo cả lượt chạy xuống
    `passed=false`. Đó là lựa chọn có giá: nhiều kịch bản hôm nay sẽ không bao giờ xanh. Nhưng
    `sim_first` dùng chính con số này để cho phép nạp firmware lên board, nên một `passed=true`
    dựa trên những dòng chưa ai kiểm là đúng thứ cơ chế ấy sinh ra để chặn.

    Hết giờ KHÔNG phải lúc nào cũng là lỗi: firmware nhúng không thoát, nên với qemu/simavr thì
    hết giờ là cách lượt chạy kết thúc — xem `TU_DUNG`. Với Renode (`.resc` kết thúc bằng `quit`)
    thì hết giờ là E4004 thật.
    """
    root = _du_an(ctx)
    mo_ta = _nen_tang(root)
    art = _giai(root, params["artifact"])
    if not art.exists():
        raise EideError("E4000", f"Không có artifact {art} — `code.build` trước",
                        artifact=str(art))
    kb_path = _giai(root, params["scenario"])
    if not kb_path.exists():
        raise EideError("E2000", f"Không có kịch bản {kb_path} — `sim.scenario` trước",
                        exists=[], candidates=["sim.scenario"], missing=[str(kb_path)])
    kb = yaml.safe_load(kb_path.read_text(encoding="utf-8")) or {}

    kq = chay_kich_ban(root, ctx, art, kb, mo_ta)
    if kq["exit_code"] != 0:
        raise EideError("E4000", f"Engine `{mo_ta['engine']}` trả mã {kq['exit_code']} — "
                        f"nhật ký: {kq['err_ref']}", engine=mo_ta["engine"],
                        exit_code=kq["exit_code"], log=kq["err_ref"])

    bang = _cham_expect(kb, kq["uart"], mo_ta["engine"])
    dat = bool(bang) and all(d["status"] == "passed" for d in bang)
    rep = {
        # Nhật ký cũng theo quy ước đường dẫn của `_tuong_doi`: sandbox trả đường tuyệt đối của
        # máy này, và dán nguyên nó vào báo cáo thì báo cáo mang theo cây thư mục của người chạy.
        "tool": "sim.run", "passed": dat,
        "log_ref": _tuong_doi(root, Path(kq["log_ref"])) if kq.get("log_ref") else None,
        "metrics": {"engine": mo_ta["engine"], "scenario": _tuong_doi(root, kb_path),
                    "feature": kb.get("feature"), "duration_s": kb.get("duration_s"),
                    "terminated_by": "timeout" if kq["het_gio"] else "exit",
                    "expect": bang,
                    "n_passed": sum(1 for d in bang if d["status"] == "passed"),
                    "n_unverified": sum(1 for d in bang if d["status"] == "unverified")},
        "artifacts": [_tuong_doi(root, art)],
        "duration_ms": kq["duration_ms"], "started_by": ctx.session_id,
        "at": datetime.now(UTC).isoformat(),
        # SIM-05 output_schema: "ToolReport + captured{uart[], gpio[], vars{}}". `gpio`/`vars`
        # rỗng là SỰ THẬT của hiện thực hôm nay, không phải chỗ chờ điền — xem DEV-083.
        "captured": {"uart": kq["uart"], "gpio": [], "vars": {}},
    }
    store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", {k: v for k, v in rep.items() if k != "captured"})
    return {"report": rep}


# ---------------------------------------------------------------- SIM-06 sweep

SO_SONG_TOI_DA = 4          # bước 1 của SIM-06: "chạy song song ≤ 4"
NGAN_SACH_SWEEP_S = 120     # trần cho cả lượt quét; vượt → E4004


def luoi(ranges: dict[str, Any]) -> list[dict[str, float]]:
    """`{"kp": [1, 10, 1]}` → 10 ô. Ba số là [đầu, cuối, bước] — đúng ví dụ của SIM-06.

    Danh sách giá trị tường minh viết `{"kp": {"values": [1, 3, 9]}}`. Không đoán theo độ dài:
    `[1, 2, 3]` vừa có thể là một dải vừa có thể là ba giá trị, và đoán sai thì bảng kết quả có
    số ô đúng nhưng giá trị sai — loại lỗi không ai phát hiện bằng mắt.
    """
    truc: list[list[tuple[str, float]]] = []
    for ten, r in ranges.items():
        if isinstance(r, dict) and "values" in r:
            gt = [float(x) for x in r["values"]]
        elif isinstance(r, (list, tuple)) and len(r) == 3:
            dau, cuoi, buoc = (float(x) for x in r)
            if buoc <= 0:
                raise EideError("E1000", f"`{ten}`: bước phải dương, đang là {buoc}")
            n = int(math.floor((cuoi - dau) / buoc)) + 1
            gt = [round(dau + i * buoc, 10) for i in range(max(n, 1))]
        else:
            raise EideError("E1000", f"`{ten}`: dải phải là [đầu, cuối, bước] hoặc "
                            "{{values: [...]}}")
        truc.append([(ten, v) for v in gt])
    ra: list[dict[str, float]] = [{}]
    for t in truc:
        ra = [{**o, ten: v} for o in ra for ten, v in t]
    return ra


def _nap_plant(root: Path, ten: str) -> Any:
    """Nạp mô-đun plant do `sim.model_plant` sinh ra, theo ĐƯỜNG DẪN chứ không theo tên gói."""
    import importlib.util

    p = root / SIM_DIR / "plant" / f"{ten}.py"
    if not p.exists():
        raise EideError("E2000", f"Không có mô hình plant `{ten}` — `sim.model_plant` trước",
                        exists=[], candidates=["sim.model_plant"], missing=[str(p)])
    spec = importlib.util.spec_from_file_location(f"eide_sim_plant_{ten}", p)
    mod = importlib.util.module_from_spec(spec)              # type: ignore[arg-type]
    spec.loader.exec_module(mod)                             # type: ignore[union-attr]
    return mod


@capability("sim.sweep")
def sweep(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: SIM-06 — CDS-12.4; SIM-20 §4 (plant, PID tham chiếu), §6 (bảng nhiệt trên SimView).
    tc: "Bảng đủ ô; best hợp lý"; lỗi E4004; `undo: none`.

    Quét trên **mô hình đối tượng**, không trên firmware — và đó là giới hạn phải nói ra chứ
    không phải một chỗ bỏ sót. Một tham số của firmware (hằng số PID nằm trong mã, tốc độ bus
    trong cấu hình) chỉ đổi được bằng cách dịch lại firmware cho từng ô lưới, tức mỗi ô là một
    lượt `code.modify` + `code.build`; đó là một chuỗi, không phải một năng lực. Tham số không
    thuộc plant/PID vì thế trả E2000 kèm tên năng lực phải dùng, thay vì quét một thứ rồi báo
    cáo như thể đã quét thứ khác.

    Tiêu chí chọn: ô nào KHÔNG đổ và ổn định sớm nhất. Ô đổ không bao giờ là `best`, kể cả khi
    nó là ô duy nhất — lúc ấy `best` rỗng, vì "tốt nhất trong những cái đều hỏng" là một câu nói
    dối có hình dạng của một kết luận.
    """
    from concurrent.futures import ThreadPoolExecutor

    root = _du_an(ctx)
    kb_path = _giai(root, params["scenario"])
    if not kb_path.exists():
        raise EideError("E2000", f"Không có kịch bản {kb_path} — `sim.scenario` trước",
                        exists=[], candidates=["sim.scenario"], missing=[str(kb_path)])
    kb = yaml.safe_load(kb_path.read_text(encoding="utf-8")) or {}
    ten_plant = (kb.get("init") or {}).get("plant")
    if not ten_plant:
        raise EideError("E2000", "Kịch bản không khai `init.plant` — chưa quét được tham số "
                        "firmware (cần dựng lại firmware mỗi ô lưới)", exists=[],
                        candidates=["sim.model_plant", "code.modify"], missing=["init.plant"])
    mod = _nap_plant(root, ten_plant)

    ranges = dict(params["ranges"])
    hop_le = set(mod.PID_REF) | set(mod.PARAMS)
    if (la := sorted(set(ranges) - hop_le)):
        raise EideError("E2000", f"Tham số {la} không thuộc plant hay PID tham chiếu "
                        f"({sorted(hop_le)}) — quét tham số firmware cần `code.modify` + "
                        "`code.build` cho từng ô", exists=sorted(hop_le),
                        candidates=["code.modify"], missing=la)

    o = luoi(ranges)
    t0 = time.perf_counter()

    def mot_o(g: dict[str, float]) -> dict[str, Any]:
        gains = {k: v for k, v in g.items() if k in mod.PID_REF}
        p = {**mod.PARAMS, **{k: v for k, v in g.items() if k in mod.PARAMS}}
        kq = mod.run(theta0_deg=5.0, duration_s=float(kb.get("duration_s") or 3),
                     gains=gains, p=p)
        return {"params": g, "settle_s": kq["settle_s"], "fallen_s": kq["fallen_s"],
                "max_abs_theta": round(kq["max_abs_theta"], 5),
                "ok": kq["fallen_s"] is None and kq["settle_s"] is not None}

    with ThreadPoolExecutor(max_workers=SO_SONG_TOI_DA) as ex:
        bang = list(ex.map(mot_o, o))
    if (het := time.perf_counter() - t0) > NGAN_SACH_SWEEP_S:
        raise EideError("E4004", f"Quét {len(o)} ô mất {het:.0f} s, quá trần "
                        f"{NGAN_SACH_SWEEP_S} s", cells=len(o), elapsed_s=round(het, 1))

    dat = [d for d in bang if d["ok"]]
    best = min(dat, key=lambda d: d["settle_s"]) if dat else {}
    return {"table": bang, "best": best}
