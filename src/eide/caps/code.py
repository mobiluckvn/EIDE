"""Namespace code.* — CDS-12.1/12.2; PRS-16 §3 (vai trò coder) và §4 (schema CodePatch);
POL-17 G3; BPD-11 P3.1–P3.5; STP-05 TC-04, TC-06.

Nhóm này là mắt xích giữa "tác tử hiểu và lập kế hoạch" với "có firmware chạy được". Bất biến
của cả nhóm nằm ở `code.constant_guard`: **mọi hằng số phần cứng trong mã sinh ra phải trỏ về
một fact có thật, đã duyệt, và giá trị khớp.** Không có nó thì cả tầng tri thức phía trước —
trích SVD, hộ chiếu, cổng G-FACT — chỉ là trang trí, vì mã cuối cùng vẫn chứa những con số
không ai truy được nguồn.
"""
from __future__ import annotations

import re
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store, tools
from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import capability
from eide_core.router import Context

# ---------------------------------------------------------------- CODE-04 constant_guard

# Chú thích nguồn của một hằng số. PRS-16 §3 (prompt coder) ghi đúng dạng này:
# "mỗi hằng số phần cứng kèm chú thích /* eide:fact f_… */ đúng id".
#
# Chấp nhận cả `//` lẫn `/* */` vì cả hai đều là chú thích C hợp lệ và mô hình dùng lẫn; chấp
# nhận nhiều id trên một dòng vì một dòng có thể có nhiều hằng số.
RE_CHU_THICH = re.compile(r"eide:fact\s+(f_[0-9a-fA-F]+)")

# Literal ỨNG VIÊN. Ba dạng, theo bước 1 của CODE-04 ("địa chỉ/bit/enum/tần số"):
#   0x…  cơ số 16 — ký pháp của địa chỉ, mặt nạ bit, mã thanh ghi
#   0b…  cơ số 2  — mẫu bit
#   số thập phân ≥ NGUONG_THAP_PHAN — tần số, tốc độ baud, chu kỳ
RE_HEX = re.compile(r"\b0[xX][0-9a-fA-F]+[uUlL]*\b")
RE_BIN = re.compile(r"\b0[bB][01]+[uUlL]*\b")
RE_THAP_PHAN = re.compile(r"\b\d{4,}[uUlL]*\b")

# Vì sao 1000 chứ không phải 1. Một hằng số thập phân nhỏ trong mã nhúng gần như luôn là chỉ số
# mảng, số lần lặp, hay một hằng của thuật toán — chặn chúng thì `constant_guard` chặn mọi patch
# và không ai dùng nó nữa. Từ bốn chữ số trở lên thì nó là tần số, baud, hay chu kỳ: những thứ
# PHẢI có nguồn. Ký pháp cơ số 16 và 2 thì bắt hết, không có ngưỡng — viết `0x76` thay vì `118`
# là hành động cố ý nói "đây là một giá trị phần cứng".
NGUONG_THAP_PHAN = 1000

DUOI_C = {".c", ".h", ".cpp", ".hpp", ".cc", ".cxx", ".hh", ".ino", ".s", ".S"}

# Bốn lý do chặn. Tách ra vì chúng dẫn tới bốn hành động khác nhau của người đọc, và gộp lại
# thành "vi phạm" thì người ta phải đọc mã để biết phải làm gì.
LY_DO = {
    "no_fact": "hằng số không có chú thích `eide:fact`",
    "fact_not_found": "chú thích trỏ tới fact không có trong store",
    "fact_not_reviewed": "fact chưa duyệt (cần status reviewed/verified, hoặc tầng gold)",
    "value_mismatch": "giá trị trong mã khác giá trị của fact",
}

# STP-05 TC-06: "Fact status=normalized → … ConstantGuard từ chối". CODE-04 bước 1 cho hai lối
# qua: status đã duyệt, HOẶC tầng vàng. Tầng vàng là tài liệu chính hãng đã phân tích cú pháp —
# TC-04 ghi thẳng "fact vàng → qua".
TRANG_THAI_QUA = {"reviewed", "verified"}
TANG_QUA = {"gold"}


def _bo_chu_thich_va_chuoi(dong: str) -> str:
    """Xóa phần chú thích và chuỗi của một dòng C, giữ nguyên độ dài không quan trọng.

    Bắt buộc phải làm trước khi dò literal, vì chính chú thích nguồn chứa `f_00000000000000ab`
    — một chuỗi có `0` và chữ số hex — và một `printf("addr=0x%08x")` cũng vậy. Không lọc thì
    guard tự báo vi phạm cho chú thích do chính nó đòi hỏi.

    Đây là phép lọc từ vựng, không phải trình phân tích C: nó không hiểu chú thích nhiều dòng
    mở ở dòng trước. `_quet_tep` xử lý phần ấy bằng một cờ trạng thái.
    """
    ra, i, n = [], 0, len(dong)
    while i < n:
        c = dong[i]
        if c == '"' or c == "'":
            dau = c
            i += 1
            while i < n and dong[i] != dau:
                i += 2 if dong[i] == "\\" else 1
            i += 1
            continue
        if dong.startswith("//", i):
            break
        if dong.startswith("/*", i):
            ket = dong.find("*/", i + 2)
            if ket < 0:
                break
            i = ket + 2
            continue
        ra.append(c)
        i += 1
    return "".join(ra)


def _tach_chu_thich(dong: str) -> str:
    """Ngược lại: chỉ giữ phần chú thích, để tìm `eide:fact`."""
    ra = []
    i, n = 0, len(dong)
    while i < n:
        if dong.startswith("//", i):
            ra.append(dong[i:])
            break
        if dong.startswith("/*", i):
            ket = dong.find("*/", i + 2)
            ra.append(dong[i:] if ket < 0 else dong[i:ket + 2])
            if ket < 0:
                break
            i = ket + 2
            continue
        if dong[i] in "\"'":
            dau = dong[i]
            i += 1
            while i < n and dong[i] != dau:
                i += 2 if dong[i] == "\\" else 1
        i += 1
    return " ".join(ra)


# "NGỮ CẢNH PHẦN CỨNG" — chữ của chính CODE-04 bước 1, và chỗ quyết định guard có dùng được hay
# không. Áp cho literal THẬP PHÂN, không áp cho `0x`/`0b`.
#
# Vì sao chỉ thập phân: viết `0x76` thay vì `118` là hành động cố ý nói "đây là giá trị phần
# cứng", nên ký pháp đã là ngữ cảnh. Còn `1000` thì có thể là tần số, mà cũng có thể là cận của
# một vòng lặp — `for (int i = 0; i < 1000; i++)`. Bắt cả hai thì guard kêu ở mọi vòng lặp, người
# ta tắt nó đi, và lúc ấy nó bảo vệ 0%.
#
# Ba dấu hiệu, đều là thành ngữ của C nhúng chứ không phải suy đoán:
RE_DINH_NGHIA = re.compile(r"^\s*#\s*define\b")          # #define I2C_SPEED 400000
RE_TEN_HOA = re.compile(r"\b[A-Z][A-Z0-9_]{1,}\b")       # RCC, CR1, BME280_ADDR
RE_TRUY_CAP = re.compile(r"->")                          # hi2c->Init.ClockSpeed = 400000
# CODE-04 bước 1 nêu riêng "tần số" trong bốn loại literal cần canh. Một biến thường tên
# `baud`/`freq`/`clk` mang tần số mà không có chữ hoa nào và không có `->`:
#   uint32_t baud = 115200;
RE_TU_TAN_SO = re.compile(r"\b(baud|freq|frequency|clk|clock|hz|speed|prescaler|period)\w*\b",
                          re.IGNORECASE)


def _ngu_canh_phan_cung(dong: str) -> bool:
    """Còn sót gì: `int x = 115200;` — không chữ hoa, không `->`, không từ khóa tần số. Bắt được
    nó cần một trình phân tích C thật (biết `x` dùng làm gì), và đó là việc của `code.review`
    (PRS-16 §3, reviewer khác hãng) chứ không phải của một phép lọc từ vựng."""
    return bool(RE_DINH_NGHIA.search(dong) or RE_TEN_HOA.search(dong)
                or RE_TRUY_CAP.search(dong) or RE_TU_TAN_SO.search(dong))


def _literal(dong_sach: str) -> list[str]:
    """Các literal ứng viên trên một dòng đã bỏ chú thích và chuỗi."""
    ra = list(RE_HEX.findall(dong_sach)) + list(RE_BIN.findall(dong_sach))
    if _ngu_canh_phan_cung(dong_sach):
        for t in RE_THAP_PHAN.findall(dong_sach):
            if (v := _so(t)) is not None and v >= NGUONG_THAP_PHAN:
                ra.append(t)
    return ra


def _so(x: Any) -> int | None:
    """Literal C → int. `None` khi không phải số — KHÔNG trả 0: `0x00000000` là một địa chỉ hợp
    lệ, và lẫn nó với "không đọc được" là cách một guard bỏ sót đúng thứ nó canh."""
    s = str(x).strip().rstrip("uUlL")
    if not s:
        return None
    try:
        return int(s, 0)
    except ValueError:
        pass
    m = re.fullmatch(r"([0-9]*\.?[0-9]+)\s*([kKmMgG])?(?:Hz|hz|HZ)?", s)
    if not m:
        return None
    he_so = {"k": 1_000, "m": 1_000_000, "g": 1_000_000_000}.get((m.group(2) or "").lower(), 1)
    return int(float(m.group(1)) * he_so)


def _khop_gia_tri(literal: str, gia_tri: Any) -> bool:
    """So literal trong mã với `fact.value`.

    So bằng SỐ trước: `0x76`, `118`, `0b1110110` là cùng một giá trị, và bắt mã phải viết đúng
    ký pháp của fact là bắt sai chỗ. Không phân tích được thành số thì mới so chuỗi — một fact
    có giá trị là tên enum (`I2C_FASTMODE`) vẫn phải đối chiếu được.
    """
    a, b = _so(literal), _so(gia_tri)
    if a is not None and b is not None:
        return a == b
    return str(literal).strip().rstrip("uUlL").lower() == str(gia_tri).strip().lower()


@capability("code.constant_guard")
def constant_guard(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-04 — CDS-12.1; PRS-16 §3; BPD-11 P3.2; STP-05 TC-04, TC-06.

    **Đây là lý do cả tầng tri thức tồn tại.** Sinh mã mà không nối hằng số về fact thì EIDE chỉ
    là một trình sinh mã nữa; nối được thì mỗi con số trong firmware trả lời được câu "ai nói
    thế, và ở trang nào".

    Bốn điều kiện để một literal đi qua, và mọi điều kiện đều đến từ tài liệu:

    1. có chú thích `eide:fact f_…` trên cùng dòng hoặc dòng ngay trên (PRS-16 §3);
    2. fact ấy CÓ THẬT trong store (TC-04: "chú thích fact không tồn tại → chặn");
    3. `status` là `reviewed`/`verified`, **hoặc** tầng `gold` (CODE-04 bước 1; TC-04 "fact bạc
       chưa duyệt → chặn", "fact vàng → qua"; TC-06 "status=normalized → ConstantGuard từ chối");
    4. giá trị khớp (CODE-04 bước 1).

    **Không tạo `kg.request`**, dù bước 2 của hợp đồng nói thế. CODE-04 là lớp **R0**, mà APD-08
    định nghĩa R0 là lớp CHỈ ĐỌC — `PolicyGate` dựa hẳn vào định nghĩa ấy để cho R0 đi thẳng
    không qua quy tắc cổng. Một năng lực R0 ghi vào store thì lối tắt ấy thành lỗ hổng. Thay vào
    đó mỗi vi phạm loại "thiếu tri thức" mang sẵn trường `need`, và bên gọi (R2, ví dụ
    `code.generate_module`) tạo yêu cầu. Xem DEV-062.

    Chặn NHẦM tệ hơn bỏ sót ở đây, vì `verdict=block` dừng cả `code.generate_module`: nếu guard
    kêu ở mọi `for (i = 0; i < 1000; i++)` thì người ta tắt nó đi, và lúc ấy nó bảo vệ 0%.
    """
    patch = params["patch"] or {}
    files = patch.get("files") or []
    if not isinstance(files, list):
        raise EideError("E1000", "patch.files phải là danh sách (PRS-16 §4 CodePatch)")

    vi_pham: list[dict[str, Any]] = []
    can: dict[str, dict[str, Any]] = {}
    for f in files:
        duong = str(f.get("path") or "")
        if Path(duong).suffix not in DUOI_C:
            continue                    # CODE-04 nói "ngữ cảnh phần cứng" — YAML/Markdown thì không
        vi_pham += _quet_tep(duong, str(f.get("content") or ""), can, ctx)

    return {"verdict": "block" if vi_pham else "pass", "violations": vi_pham}


def _quet_tep(duong: str, noi_dung: str, can: dict[str, dict[str, Any]],
              ctx: Context) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    dong_ds = noi_dung.splitlines()
    trong_chu_thich = False
    chu_thich_truoc: list[str] = []

    for so_dong, dong in enumerate(dong_ds, start=1):
        # Chú thích /* … */ mở ở dòng trước: cả dòng này là chú thích cho tới `*/`. Không theo
        # dõi trạng thái ấy thì một khối chú thích đầu tệp (giấy phép, ghi chú) trở thành hàng
        # chục "vi phạm" — đúng cách làm một guard bị tắt đi.
        con_lai = dong
        if trong_chu_thich:
            ket = dong.find("*/")
            if ket < 0:
                chu_thich_truoc = RE_CHU_THICH.findall(dong)
                continue
            trong_chu_thich = False
            con_lai = dong[ket + 2:]
        mo = con_lai.rfind("/*")
        if mo >= 0 and con_lai.find("*/", mo + 2) < 0:
            trong_chu_thich = True

        sach = _bo_chu_thich_va_chuoi(con_lai)
        fact_dong = RE_CHU_THICH.findall(_tach_chu_thich(con_lai))
        cho_phep = fact_dong + chu_thich_truoc
        chu_thich_truoc = fact_dong if not sach.strip() else []

        for lit in _literal(sach):
            if not cho_phep:
                ra.append(_vp(duong, so_dong, lit, "no_fact"))
                continue
            if any(_dat(fid, lit, can, ctx) for fid in cho_phep):
                continue
            ra.append(_vp(duong, so_dong, lit, _ly_do_hong(cho_phep, lit, can, ctx),
                          fact=cho_phep[0]))
    return ra


def _vp(duong: str, dong: int, lit: str, ly_do: str, fact: str | None = None) -> dict[str, Any]:
    vp = {"file": duong, "line": dong, "literal": lit, "reason": ly_do,
          "message": LY_DO.get(ly_do, ly_do)}
    if fact:
        vp["fact"] = fact
    # `need` chỉ có nghĩa với ba lý do THIẾU TRI THỨC. `value_mismatch` thì fact đã có, đã duyệt,
    # và giá trị khác — đó là lỗi của mã chứ không phải chỗ thiếu tri thức, nên đi tìm tài liệu
    # về nó là đi sai đường.
    if ly_do in ("no_fact", "fact_not_found", "fact_not_reviewed"):
        vp["need"] = f"nguồn cho hằng số {lit} tại {duong}:{dong}"
    return vp


def _ly_do_hong(ds: list[str], lit: str, can: dict[str, dict[str, Any]], ctx: Context) -> str:
    """Lý do CỤ THỂ nhất trong các fact được chú thích: chưa duyệt > không tồn tại > lệch giá trị.

    Thứ tự này không tùy tiện — nó theo việc người đọc phải làm. Một fact chưa duyệt thì bấm
    duyệt là xong; một fact không tồn tại thì phải đi tìm tài liệu.
    """
    tt = [_fact(fid, can, ctx) for fid in ds]
    if any(f is None for f in tt):
        return "fact_not_found"
    if all(not _da_duyet(f) for f in tt if f):
        return "fact_not_reviewed"
    return "value_mismatch"


def _da_duyet(f: dict[str, Any]) -> bool:
    return f.get("status") in TRANG_THAI_QUA or f.get("tier") in TANG_QUA


def _dat(fid: str, lit: str, can: dict[str, dict[str, Any]], ctx: Context) -> bool:
    f = _fact(fid, can, ctx)
    return bool(f) and _da_duyet(f) and _khop_gia_tri(lit, f.get("value"))


def _fact(fid: str, can: dict[str, dict[str, Any]], ctx: Context) -> dict[str, Any] | None:
    """Tra fact, có bộ nhớ đệm trong một lời gọi: một patch nhắc cùng một fact hàng chục lần."""
    if fid in can:
        return can[fid] or None
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    f: dict[str, Any] | None = None
    if root and (root / EIDE_DIR).is_dir() and (db := store.store_path(root)).exists():
        with store.open_store(db) as c:
            r = c.execute("SELECT id, value, status, tier FROM fact WHERE id = ?", (fid,)).fetchone()
        if r:
            f = {"id": r[0], "value": r[1], "status": r[2], "tier": r[3]}
    can[fid] = f or {}
    return f


# ---------------------------------------------------------------- CODE-05/06 build, size

# Không có bảng lệnh dựng nào trong tệp này. `docs/spec/isa/*.yaml` đã mang `toolchain.build.cmd`,
# `artifact`, `map`, và `static.cmd` — chép chúng sang Python là tạo bản thứ hai, và bản trong mã
# là bản không ai sinh lại (cùng lỗi với PRED_W/DEV-043).


def _du_an(ctx: Context, params: dict[str, Any]) -> Path:
    root = Path(params.get("project") or (ctx.project_dir or "")).expanduser()
    if not root.name or not (root / EIDE_DIR).is_dir():
        raise EideError("E2000", "Nhóm code.* cần một dự án đang mở",
                        exists=[], candidates=[], missing=["project"])
    return root


def _muc_tieu(root: Path) -> dict[str, Any]:
    """`target` của dự án — `project.set_target` ghi vào `.eide/constraints.yaml`, không phải vào
    một tệp riêng. Đọc sai tệp thì mọi dự án trông như chưa ghim ISA."""
    import yaml
    f = root / EIDE_DIR / "constraints.yaml"
    cu = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}) if f.exists() else {}
    return dict(cu.get("target") or {})


def _isa_cua(root: Path) -> str:
    """ISA đã ghim của dự án (`project.set_target`). Không có thì không dựng được: mọi lệnh dựng
    đều nằm trong manifest của một ISA cụ thể."""
    isa = (_muc_tieu(root)).get("isa")
    if not isa:
        raise EideError("E2000", "Dự án chưa ghim ISA — chạy `project.set_target` trước "
                        "(mọi lệnh dựng đến từ manifest của một ISA)",
                        exists=[], candidates=[], missing=["isa"])
    return str(isa)


def manifest_isa(isa: str) -> dict[str, Any]:
    import yaml
    f = spec_dir() / "isa" / f"{isa}.yaml"
    if not f.exists():
        raise EideError("E2000", f"ISA '{isa}' chưa có manifest trong docs/spec/isa/ (TGT-19)")
    return yaml.safe_load(f.read_text(encoding="utf-8")) or {}


def tach_lenh(chuoi: str) -> list[list[str]]:
    """`"cmake -S . -B build && cmake --build build"` → hai lệnh dạng DANH SÁCH.

    Manifest viết lệnh dựng thành một chuỗi shell vì đó là dạng người đọc; PLATFORM.md quy tắc 3
    thì cấm gọi lệnh dạng chuỗi, và `Sandbox.run` chỉ nhận danh sách. Tách ở đây, một chỗ.

    Chỉ tách `&&`. `|`, `>` hay `;` KHÔNG được hỗ trợ và cũng không nên: một lệnh dựng cần ống
    dẫn là một lệnh cần shell, mà chạy shell trong sandbox là mở lại đúng cánh cửa vừa đóng.
    """
    import shlex
    if any(x in chuoi for x in ("|", ">", "<", ";", "$(", "`")):
        raise EideError("E2000", f"Lệnh dựng trong manifest ISA cần shell nên không chạy được "
                        f"trong sandbox: {chuoi!r}. Chỉ hỗ trợ chuỗi lệnh nối bằng `&&`.")
    return [shlex.split(x.strip()) for x in chuoi.split("&&") if x.strip()]


# Phân loại lỗi của bước 1 CODE-05: "compile/link/size". Ba loại dẫn tới ba hành động khác nhau
# — sửa mã, sửa cấu hình liên kết, cắt bớt — nên gộp chúng thành "build failed" là vứt đi thông
# tin duy nhất giúp `code.self_repair` biết phải làm gì.
MAU_LOI = [
    ("size", re.compile(r"region `?\w+'? overflowed|will not fit in region|section .* overlaps",
                        re.IGNORECASE)),
    ("link", re.compile(r"undefined reference to|cannot find -l|multiple definition of|"
                        r"ld(?:\.exe)?: ", re.IGNORECASE)),
    ("compile", re.compile(r"^[^\s:]+:\d+:\d+:\s*(?:fatal\s+)?error:", re.MULTILINE)),
]
SO_DONG_LOI = 20            # bước 1: "trích 20 dòng lỗi đầu"


def phan_loai_loi(log: str) -> dict[str, Any]:
    """Nhật ký trình dịch → `{kind, lines[]}`.

    Thứ tự xét quan trọng: một bản dựng tràn Flash cũng in dòng của `ld`, nên nếu xét `link`
    trước thì mọi lỗi tràn bộ nhớ bị dán nhãn "lỗi liên kết" và `code.self_repair` sẽ đi sửa
    khai báo hàm thay vì đi cắt mã.
    """
    for ten, mau in MAU_LOI:
        if mau.search(log):
            dong = [d for d in log.splitlines() if mau.search(d)] or log.splitlines()
            return {"kind": ten, "lines": dong[:SO_DONG_LOI]}
    return {"kind": "unknown", "lines": [d for d in log.splitlines() if d.strip()][:SO_DONG_LOI]}


@capability("code.build")
def build(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-05 — CDS-12.1; TGT-19 `toolchain.build`; SEC-25 §2. tc: TC-31; lỗi E4000, E4001.

    Lệnh dựng đến từ `docs/spec/isa/<isa>.yaml`, không từ một bảng trong mã. Chạy trong sandbox
    **không mạng**: một bản dựng cần tải phụ thuộc lúc biên dịch là một bản dựng không lặp lại
    được, và đó là điều `env.lock` sinh ra để chống.

    Thiếu công cụ → **E4001 trước khi chạy**, kèm đúng danh sách còn thiếu. Để `cmake` tự báo
    "command not found" thì người dùng nhận một dòng lỗi shell thay vì câu "cài arm-none-eabi-gcc
    rồi chạy lại", và `code.self_repair` sẽ tưởng mã sai mà đi sửa mã.
    """
    from eide.caps.env import check as env_check
    from eide.caps.env import sandbox as env_sandbox

    root = _du_an(ctx, params)
    isa = _isa_cua(root)
    man = manifest_isa(isa)
    tc = (man.get("toolchain") or {}).get("build") or {}
    if not tc.get("cmd"):
        raise EideError("E2000", f"Manifest ISA `{isa}` không có `toolchain.build.cmd` (TGT-19)")

    thieu = [r["tool"] for r in env_check({"isa": isa}, ctx)["report"] if not r["ok"]]
    if thieu:
        raise EideError("E4001", f"Thiếu công cụ để dựng {isa}: {', '.join(thieu)} — "
                        "`env.install` hoặc `env.guide_install`",
                        missing=thieu, isa=isa, remedy="env.install")

    t0 = time.perf_counter()
    ma, log_ref, err_ref = 0, None, None
    for lenh in tach_lenh(str(tc["cmd"])):
        kq = env_sandbox({"cmd": lenh, "network": False,
                          "allowed_dirs": [str(root)],
                          "limits": {"timeout_s": TIMEOUT_DUNG}}, ctx)
        ma, log_ref, err_ref = kq["exit_code"], kq["stdout_ref"], kq["stderr_ref"]
        if ma != 0:
            break

    loi = {}
    if ma != 0:
        noi_dung = ""
        for ref in (err_ref, log_ref):
            if ref and Path(ref).exists():
                noi_dung += Path(ref).read_text(encoding="utf-8", errors="replace")
        loi = phan_loai_loi(noi_dung)

    artifact = _khop_dau_tien(root, tc.get("artifact"))
    rep = {"tool": "build", "passed": ma == 0 and artifact is not None, "log_ref": log_ref,
           "metrics": {"isa": isa, "exit_code": ma, "error_kind": loi.get("kind"),
                       "error_lines": loi.get("lines", []),
                       "map": _khop_dau_tien(root, tc.get("map"))},
           "artifacts": [artifact] if artifact else [],
           "duration_ms": int((time.perf_counter() - t0) * 1000),
           "started_by": ctx.session_id, "at": datetime.now(UTC).isoformat()}
    store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", rep)

    if not rep["passed"]:
        ly = f"lỗi {loi.get('kind')}" if ma != 0 else "dựng xong nhưng không thấy artifact"
        raise EideError("E4000", f"Dựng {isa} không thành: {ly}. Nhật ký: {err_ref}",
                        isa=isa, exit_code=ma, error_kind=loi.get("kind"),
                        error_lines=loi.get("lines", []), log=err_ref)
    return {"report": rep}


TIMEOUT_DUNG = 600


def _khop_dau_tien(root: Path, mau: Any) -> str | None:
    """`"build/*.elf"` → đường dẫn thật đầu tiên, hoặc None. Sắp để kết quả ổn định."""
    if not mau:
        return None
    ds = sorted(root.glob(str(mau)))
    return str(ds[0]) if ds else None


# `arm-none-eabi-size` dạng Berkeley — dòng tiêu đề rồi một dòng số:
#    text    data     bss     dec     hex filename
#   12048     108    2064   14220    378c build/fw.elf
RE_SIZE = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\d+)\s+\d+\s+[0-9a-fA-F]+\s+\S", re.MULTILINE)

# Dòng ký hiệu trong tệp .map của GNU ld: địa chỉ, kích thước, rồi tệp .o.
#   .text.i2c_init  0x08000180  0x9c  CMakeFiles/fw.dir/src/i2c.c.obj
RE_MAP = re.compile(r"^\s*(\.\S+)\s+0x([0-9a-fA-F]+)\s+0x([0-9a-fA-F]+)\s+(\S+)", re.MULTILINE)

SO_KY_HIEU = 20             # "top_symbols[]" — 20 là đủ để thấy chỗ phình, không đủ để làm ngập


@capability("code.size")
def size(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-06 — CDS-12.1; ARCH-04 (ngân sách bộ nhớ). tc: "Vượt ngân sách → passed=false";
    lỗi E4000.

    **`passed=false` chứ không phải ném lỗi.** Một firmware vượt ngân sách vẫn dựng ra được và
    vẫn nạp được — nó chỉ không còn chỗ cho bootloader và cho lần cập nhật sau. Đó là một KẾT
    QUẢ ĐO, và `code.self_repair` cần đọc được con số để biết phải cắt bao nhiêu; ném lỗi thì
    thứ duy nhất nó nhận được là "thất bại".

    Ngưỡng lấy đúng của ARCH-04: 85% Flash, và cùng lý do — phần còn lại dành cho bootloader,
    vùng cấu hình, và bản vá tại hiện trường. RAM thì so với 100%: RAM hết là chương trình
    không chạy, không có chỗ cho "dành sau".
    """
    from eide.caps.arch import NGUONG_FLASH
    from eide.caps.env import sandbox as env_sandbox

    # Hợp đồng CODE-06 chỉ nhận `artifact` (`additionalProperties: false`), nên dự án lấy từ
    # ngữ cảnh và tệp `.map` lấy từ manifest ISA — không nhận thêm tham số nào.
    root = _du_an(ctx, {})
    art = Path(params["artifact"])
    if not art.is_absolute():
        art = root / art
    if not art.exists():
        raise EideError("E4000", f"Không thấy artifact {art} — chạy `code.build` trước",
                        artifact=str(art))

    isa = _isa_cua(root)
    man_tc = manifest_isa(isa).get("toolchain") or {}
    ten_size = next((t["name"] for t in (man_tc.get("tools") or [])
                     if str(t.get("name", "")).endswith("size")), "size")
    duong = tools.which(ten_size)
    if duong is None:
        raise EideError("E4001", f"Thiếu `{ten_size}` — `env.install` hoặc `env.guide_install`",
                        missing=[ten_size], remedy="env.install")

    t0 = time.perf_counter()
    kq = env_sandbox({"cmd": [str(duong), str(art)], "network": False,
                      "allowed_dirs": [str(root)], "limits": {"timeout_s": 60}}, ctx)
    if kq["exit_code"] != 0:
        raise EideError("E4000", f"`{ten_size}` trả mã {kq['exit_code']} trên {art}",
                        exit_code=kq["exit_code"], log=kq["stderr_ref"])
    ra = Path(kq["stdout_ref"]).read_text(encoding="utf-8", errors="replace")
    m = RE_SIZE.search(ra)
    if not m:
        raise EideError("E4000", f"Không đọc được kết quả của `{ten_size}`: {ra[:200]!r}")
    text, data, bss = (int(x) for x in m.groups())

    # Flash giữ cả `.text` lẫn `.data` — `.data` nằm trong ảnh nạp rồi được chép sang RAM lúc
    # khởi động, nên nó chiếm chỗ ở CẢ HAI. Bỏ `data` khỏi flash là báo thiếu đúng phần hay
    # tràn nhất ở một firmware nhiều bảng tra.
    flash, ram = text + data, data + bss
    gh = _gioi_han(root)
    bao = {"text": text, "data": data, "bss": bss, "flash": flash, "ram": ram,
           "limits": gh, "threshold_flash": NGUONG_FLASH,
           "flash_pct": round(flash / gh["flash"] * 100, 2) if gh.get("flash") else None,
           "ram_pct": round(ram / gh["ram"] * 100, 2) if gh.get("ram") else None,
           "top_symbols": _ky_hieu_lon(root, _khop_dau_tien(root, (man_tc.get("build") or {}).get("map")))}

    # Chưa biết giới hạn thì KHÔNG kết luận đạt. Một `passed=true` vì thiếu số liệu đọc y hệt
    # một `passed=true` vì vừa vặn, và đó là kiểu im lặng nguy hiểm nhất.
    dat = (bao["flash_pct"] is not None and bao["flash_pct"] <= NGUONG_FLASH * 100
           and (bao["ram_pct"] is None or bao["ram_pct"] <= 100))
    bao["reason"] = None if dat else _vi_sao(bao, NGUONG_FLASH)

    rep = {"tool": "size", "passed": dat, "log_ref": kq["stdout_ref"], "metrics": bao,
           "artifacts": [str(art)], "duration_ms": int((time.perf_counter() - t0) * 1000),
           "started_by": ctx.session_id, "at": datetime.now(UTC).isoformat()}
    store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", rep)
    return {"report": rep}


def _vi_sao(bao: dict[str, Any], nguong: float) -> str:
    if bao["flash_pct"] is None:
        return "chưa biết dung lượng Flash của chip — ghim hộ chiếu bằng `project.set_target`"
    if bao["flash_pct"] > nguong * 100:
        return (f"Flash {bao['flash_pct']}% vượt ngưỡng {nguong:.0%} (chỗ còn lại dành cho "
                "bootloader, vùng cấu hình và bản vá tại hiện trường)")
    return f"RAM {bao['ram_pct']}% vượt 100%"


def _gioi_han(root: Path) -> dict[str, int]:
    """Dung lượng Flash/RAM của chip. Dùng lại phép tra của `arch.memory_budget` — cùng câu hỏi
    thì phải cùng câu trả lời, và hai phép tra khác nhau sẽ lệch nhau đúng lúc quan trọng."""
    from eide.caps.arch import _gioi_han_bo_nho
    chip = _muc_tieu(root).get("chip")
    return _gioi_han_bo_nho(root, str(chip)) if chip else {}


def _ky_hieu_lon(root: Path, map_ref: Any) -> list[dict[str, Any]]:
    """`top_symbols[]` từ tệp `.map`. Không có .map thì trả rỗng — đó là câu trả lời đúng, chứ
    không phải lý do để hỏng cả phép đo kích thước."""
    if not map_ref:
        return []
    f = Path(map_ref)
    if not f.is_absolute():
        f = root / f
    if not f.exists():
        return []
    gom: dict[str, int] = {}
    for ten, _dia_chi, kich, _obj in RE_MAP.findall(
            f.read_text(encoding="utf-8", errors="replace")):
        if (n := int(kich, 16)) > 0:
            gom[ten] = gom.get(ten, 0) + n
    return [{"symbol": k, "bytes": v}
            for k, v in sorted(gom.items(), key=lambda kv: -kv[1])[:SO_KY_HIEU]]
