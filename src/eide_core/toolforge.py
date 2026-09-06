"""ToolForge — lõi cho công cụ do tác tử tự viết. WI-020.

Spec: CDS-12.3 TOOL-01…07; SEC-25 §2 (sandbox), §5 (quyền hệ thống); POL-17 cổng G-TOOL
(TOOL-01…05); APD-08 §4.2; API-15 E5003, E8000.

Ba lớp bảo vệ, và chúng KHÁC NHAU về thứ bắt được — đó là lý do phải có cả ba:

  1. Tĩnh (AST)      chặn `import socket` khi không khai `network`. Rẻ, chạy trước khi lưu,
                     nhưng mù trước `__import__("socket")` dựng từ chuỗi.
  2. Động (audit)    `sys.addaudithook` (PEP 578) bắt lời gọi THẬT: mở socket, chạy tiến
                     trình con, ghi tệp. Không vòng qua được bằng mẹo cú pháp.
  3. Sandbox         giới hạn tài nguyên và cách ly tiến trình (SEC-25 §2, `eide_core.sandbox`).

Lớp 1 một mình là bảo vệ giả: TC-TL-02 của CDS-12.3 chính là kịch bản "công cụ gọi socket
NGẦM", và một bộ kiểm AST sẽ cho nó qua.
"""
from __future__ import annotations

import ast
import json
from dataclasses import dataclass, field
from typing import Any

from eide_core.errors import EideError

# TOOL-05 bước 1: suy lớp rủi ro từ hiệu ứng. Lấy MỨC CAO NHẤT trong các hiệu ứng khai báo.
RUI_RO_THEO_HIEU_UNG = {
    "read_fs": "R0",
    "network": "R1",
    "write_project": "R2",
    "hardware": "R3",
    "system": "R4",
}
HIEU_UNG_HOP_LE = set(RUI_RO_THEO_HIEU_UNG)

# TOOL-06 bước 1: mức năng lực suy từ lớp rủi ro.
MUC_THEO_RUI_RO = {"R0": "T1", "R1": "T1", "R2": "T1*", "R3": "T1*", "R4": "T2"}

# Mô-đun bị cấm khi hiệu ứng tương ứng KHÔNG được khai báo (TOOL-03 bước 1).
#
# Danh sách theo hiệu ứng chứ không phải một danh sách đen chung: một công cụ khai `network`
# thì `socket` là hợp lệ, và cấm nó sẽ khiến hiệu ứng khai báo thành vô nghĩa. Điều bị chặn
# không phải "dùng mạng" mà là "dùng mạng mà không nói".
MODULE_THEO_HIEU_UNG = {
    "network": {"socket", "ssl", "http", "http.client", "urllib", "urllib.request", "ftplib",
                "smtplib", "telnetlib", "xmlrpc", "requests", "httpx", "aiohttp", "websockets"},
    "system": {"subprocess", "os", "sys", "ctypes", "signal", "resource", "pty", "shutil",
               "multiprocessing", "importlib", "pkgutil", "site", "sysconfig"},
    "hardware": {"serial", "usb", "pyftdi", "smbus", "spidev", "gpiozero", "RPi"},
}

# Hàm dựng mã lúc chạy — cấm KHÔNG ĐIỀU KIỆN. Không hiệu ứng nào biện minh được cho chúng,
# vì chúng làm mọi phép kiểm tĩnh phía trên thành vô nghĩa: `eval(chuỗi)` có thể là bất cứ gì.
HAM_CAM = {"eval", "exec", "compile", "__import__", "globals", "vars", "breakpoint"}


@dataclass
class ToolSpec:
    """CDS-12.3 TOOL-01: {name, purpose, input_schema, output_schema, effects[], deps[], acceptance[]}."""

    name: str
    purpose: str = ""
    input_schema: dict[str, Any] = field(default_factory=lambda: {"type": "object"})
    output_schema: dict[str, Any] = field(default_factory=lambda: {"type": "object"})
    effects: list[str] = field(default_factory=list)
    deps: list[str] = field(default_factory=list)
    acceptance: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not self.name or not self.name.replace("_", "").isalnum():
            raise EideError("E1000", f"Tên công cụ không hợp lệ: {self.name!r} "
                                     "(chỉ chữ, số và gạch dưới)")
        la = set(self.effects) - HIEU_UNG_HOP_LE
        if la:
            raise EideError("E1000", f"Hiệu ứng không có trong TOOL-05: {sorted(la)}")

    @property
    def risk(self) -> str:
        """Lớp rủi ro = mức CAO NHẤT trong các hiệu ứng (TOOL-05 bước 1)."""
        if not self.effects:
            return "R0"
        return max((RUI_RO_THEO_HIEU_UNG[e] for e in self.effects), key=lambda r: int(r[1]))

    @property
    def tier(self) -> str:
        return MUC_THEO_RUI_RO[self.risk]

    def as_dict(self) -> dict[str, Any]:
        return {"name": self.name, "purpose": self.purpose, "input_schema": self.input_schema,
                "output_schema": self.output_schema, "effects": list(self.effects),
                "deps": list(self.deps), "acceptance": list(self.acceptance)}

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> ToolSpec:
        return cls(name=d.get("name", ""), purpose=d.get("purpose", ""),
                   input_schema=d.get("input_schema") or {"type": "object"},
                   output_schema=d.get("output_schema") or {"type": "object"},
                   effects=list(d.get("effects") or []), deps=list(d.get("deps") or []),
                   acceptance=list(d.get("acceptance") or []))


def module_bi_cam(effects: list[str]) -> set[str]:
    """Tập mô-đun bị cấm với bộ hiệu ứng này."""
    cam: set[str] = set()
    for hieu_ung, ds in MODULE_THEO_HIEU_UNG.items():
        if hieu_ung not in effects:
            cam |= ds
    return cam


def kiem_ast(ma: str, effects: list[str]) -> list[str]:
    """Kiểm tĩnh: trả danh sách vi phạm (rỗng = sạch). TOOL-03 bước 1.

    Bắt cả `import socket` lẫn `from socket import ...` lẫn `import http.client`, vì ba dạng
    ấy cùng một việc và chặn hai trong ba thì không chặn gì.
    """
    try:
        cay = ast.parse(ma)
    except SyntaxError as e:
        raise EideError("E5002", f"Mã công cụ không phân tích được: {e}") from e

    cam = module_bi_cam(effects)
    vi_pham: list[str] = []
    for n in ast.walk(cay):
        if isinstance(n, ast.Import):
            for a in n.names:
                if _khop(a.name, cam):
                    vi_pham.append(f"import {a.name}")
        elif isinstance(n, ast.ImportFrom):
            if n.module and _khop(n.module, cam):
                vi_pham.append(f"from {n.module} import …")
        elif isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in HAM_CAM:
            vi_pham.append(f"{n.func.id}()")
        elif isinstance(n, ast.Attribute) and n.attr in HAM_CAM:
            vi_pham.append(f".{n.attr}")
    return sorted(set(vi_pham))


def _khop(ten: str, cam: set[str]) -> bool:
    """`http.client` bị chặn nếu `http` bị chặn — gói con không phải một lối vòng."""
    phan = ten.split(".")
    return any(".".join(phan[: i + 1]) in cam for i in range(len(phan)))


# ---------------------------------------------------------------- giám sát động

# Sự kiện audit (PEP 578) → hiệu ứng mà nó chứng minh. Chỉ liệt kê những sự kiện NÓI LÊN một
# hiệu ứng; `import`, `compile` v.v. không nằm ở đây vì chúng đã bị lớp AST xử lý.
SU_KIEN_HIEU_UNG = {
    "socket.connect": "network",
    "socket.bind": "network",
    "socket.getaddrinfo": "network",
    "urllib.Request": "network",
    "subprocess.Popen": "system",
    "os.system": "system",
    "os.exec": "system",
    "os.fork": "system",
    "ctypes.dlopen": "system",
    "os.remove": "write_project",
    "os.rename": "write_project",
    "os.mkdir": "write_project",
    "shutil.copyfile": "write_project",
}


class GiamSatHieuUng:
    """Bắt hiệu ứng THẬT bằng `sys.addaudithook` (PEP 578).

    Vì sao cần dù đã có AST: TC-TL-02 là kịch bản "công cụ gọi socket NGẦM". Một công cụ dựng
    tên mô-đun từ chuỗi đi qua được mọi bộ kiểm cú pháp — nhưng không đi qua được chỗ này, vì
    audit hook nằm ở tầng thông dịch, sau khi mọi mẹo cú pháp đã hết tác dụng.

    Hook KHÔNG gỡ được sau khi cài (PEP 578 cố ý như vậy), nên lớp này chỉ bật/tắt việc GHI
    chứ không cài lại hook mỗi lần dùng.
    """

    _da_cai = False
    _dang_ghi = False
    _quan_sat: set[str] = set()

    @classmethod
    def _hook(cls, ten: str, args: tuple) -> None:
        if not cls._dang_ghi:
            return
        hieu_ung = SU_KIEN_HIEU_UNG.get(ten)
        if hieu_ung is None and ten == "open":
            duong_dan = str(args[0]) if args else ""
            # Bộ nhớ đệm bytecode là việc của TRÌNH NẠP, không phải hiệu ứng của công cụ. Không
            # loại nó ra thì MỌI công cụ đều bị chấm là `write_project` ngay khi được import —
            # và `effects_ok` mất hết nghĩa vì nó luôn false.
            if "__pycache__" in duong_dan or duong_dan.endswith((".pyc", ".pyo")):
                return
            # `open` chỉ là ghi khi CHẾ ĐỘ có ghi — đọc tệp là `read_fs`, không phải write.
            che_do = args[1] if len(args) > 1 else "r"
            hieu_ung = "write_project" if che_do and any(c in str(che_do) for c in "wax+") else "read_fs"
        if hieu_ung:
            cls._quan_sat.add(hieu_ung)

    @classmethod
    def bat_dau(cls) -> None:
        import sys
        if not cls._da_cai:
            sys.addaudithook(cls._hook)
            cls._da_cai = True
        cls._quan_sat = set()
        cls._dang_ghi = True

    @classmethod
    def ket_thuc(cls) -> set[str]:
        cls._dang_ghi = False
        return set(cls._quan_sat)


def hieu_ung_khop(quan_sat: set[str], khai_bao: list[str]) -> bool:
    """TOOL-04 bước 2: `observed ⊆ declared` → effects_ok.

    Một chiều, không phải bằng nhau: khai nhiều hơn làm là thừa nhưng an toàn; làm nhiều hơn
    khai là chính thứ cổng G-TOOL sinh ra để chặn (quy tắc TOOL-03 của POL-17).
    """
    return quan_sat <= set(khai_bao)


MAU_CONG_CU = '''"""{purpose}

Công cụ do EIDE tự viết — CDS-12.3 TOOL-03. Hiệu ứng khai báo: {effects}.
KHÔNG sửa tay: sinh lại bằng `tool.write`, sửa bằng `tool.repair`.
"""
from __future__ import annotations

from typing import Any

SPEC = {spec}


def run(args: dict[str, Any], ctx: Any = None) -> dict[str, Any]:
    """{purpose}"""
    raise NotImplementedError
'''


def mau_test(spec: ToolSpec) -> str:
    """Sinh test pytest từ `acceptance` (TOOL-03 bước 2).

    Mỗi ví dụ acceptance thành MỘT test có tên riêng, không gộp thành một vòng lặp: khi hỏng,
    tên test phải nói ngay ví dụ nào hỏng.
    """
    d = ['"""Test sinh từ acceptance của ToolSpec — CDS-12.3 TOOL-03 bước 2."""',
         "import json", "from pathlib import Path", "", "import pytest", "",
         "import tool as m", "", ""]
    for i, vd in enumerate(spec.acceptance or [], 1):
        d += [f"def test_acceptance_{i}():",
              f"    kq = m.run({vd.get('args', {})!r})",
              f"    assert kq == {vd.get('expect')!r}", "", ""]
    if not spec.acceptance:
        d += ["def test_co_ham_run():",
              '    """Không có acceptance thì ít nhất phải gọi được — TOOL-04 cần một thứ để chạy."""',
              "    assert callable(m.run)", ""]
    return "\n".join(d)


def json_gon(x: Any) -> str:
    return json.dumps(x, ensure_ascii=False, indent=4)
