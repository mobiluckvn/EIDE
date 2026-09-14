"""Namespace code.* — CDS-12.1/12.2; PRS-16 §3 (vai trò coder) và §4 (schema CodePatch);
POL-17 G3; BPD-11 P3.1–P3.5; STP-05 TC-04, TC-06.

Nhóm này là mắt xích giữa "tác tử hiểu và lập kế hoạch" với "có firmware chạy được". Bất biến
của cả nhóm nằm ở `code.constant_guard`: **mọi hằng số phần cứng trong mã sinh ra phải trỏ về
một fact có thật, đã duyệt, và giá trị khớp.** Không có nó thì cả tầng tri thức phía trước —
trích SVD, hộ chiếu, cổng G-FACT — chỉ là trang trí, vì mã cuối cùng vẫn chứa những con số
không ai truy được nguồn.
"""
from __future__ import annotations

import json
import re
import time
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
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

# Tệp KIỂM THỬ không bị quét, và đây là một quyết định thiết kế chứ không phải một lỗ hổng.
#
# Một test khẳng định `bme280_dia_chi() == 0x76` đang KIỂM giá trị, không KHAI nó. Bắt nó trích
# dẫn cùng fact mà mã đang kiểm cũng trích dẫn thì cả hai lấy số từ một chỗ, và test không còn
# kiểm gì nữa — nó chỉ xác nhận rằng hai bản sao của cùng một biến bằng nhau. Viết literal ra là
# đúng cách viết test.
#
# Tìm ra bằng gọi mô hình THẬT (`tests/test_that.py`): coder chú thích đúng trong `src/`, rồi bị
# chặn vì ba lần `0x76` trong tệp test nó tự viết. Giả lập không thể lộ ra chuyện này vì giả lập
# trả đúng cái tôi bảo nó trả. Xem DEV-064.
#
# Lỗ hổng còn lại — nhét mã điều khiển vào `tests/` để né guard — bị chặn ở chỗ khác: `code.build`
# dựng theo `CMakeLists` của dự án, và `code.test_host` chỉ chạy trên máy chủ.
THU_MUC_KHONG_QUET = ("tests/",)

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
        if any(duong.replace("\\", "/").startswith(x) for x in THU_MUC_KHONG_QUET):
            continue
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


def _giai_placeholder(cmd: str, root: Path, isa: str) -> str:
    """`make -C . MCU={mcu} F_CPU={f_cpu}` → giá trị thật của dự án này.

    TGT-19 dùng placeholder xuyên suốt — `flash.cmd` có `{programmer} {part} {port} {hex}`,
    `id_read.cmd` có `{port}`, `sim.cmd` có `{artifact}` — và mỗi chỗ dùng chúng đều tự giải.
    `build.cmd` là chỗ DUY NHẤT không giải: nó chạy chuỗi nguyên văn, nên `avr8` truyền cho
    `make` một biến `MCU` mang đúng bảy ký tự `{mcu}`. Lỗi nằm im vì manifest `armv7e-m` và
    `rv32imac` viết lệnh cmake không placeholder — và vì chưa ai dựng AVR bao giờ. Xem DEV-104.

    **Không giải được thì DỪNG, không đoán.** Arduino Uno chạy 16 MHz và tôi biết điều đó,
    nhưng không fact nào trong dự án này nói thế — `f_cpu` phải đến từ `constraints.yaml` hay
    hộ chiếu board. Điền theo trí nhớ là gieo một hằng số không nguồn vào tận dòng lệnh dựng,
    nơi không cổng nào của EIDE còn nhìn thấy nó; và sai `F_CPU` thì UART ra ký tự rác trong
    khi mọi thứ khác trông vẫn đúng.
    """
    dich = _muc_tieu(root)
    gia_tri: dict[str, Any] = {
        "isa": isa,
        # `microchip.atmega328p` → `atmega328p`: `make` và `avr-gcc -mmcu=` cần tên trần.
        "mcu": str(dich.get("mcu") or dich.get("chip") or "").split("@")[0].rsplit(".", 1)[-1],
        "chip": str(dich.get("chip") or "").split("@")[0],
        "board": str(dich.get("board") or "").split("@")[0],
        "f_cpu": dich.get("f_cpu"),
    }
    thieu = sorted({t for t in re.findall(r"\{([a-z_]+)\}", cmd) if not gia_tri.get(t)})
    if thieu:
        raise EideError(
            "E2000",
            f"`toolchain.build.cmd` của `{isa}` cần {', '.join('{' + t + '}' for t in thieu)} "
            "mà dự án chưa khai — đặt trong `.eide/constraints.yaml` mục `target` "
            "(ví dụ `f_cpu: 16000000`) hoặc nạp hộ chiếu board có thông số ấy.",
            exists=sorted(k for k, v in gia_tri.items() if v),
            candidates=["project.set_target", "board.import"],
            missing=[f"target.{t}" for t in thieu])
    return re.sub(r"\{([a-z_]+)\}", lambda m: str(gia_tri.get(m.group(1), m.group(0))), cmd)


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
    from eide.caps.env import chay_sandbox
    from eide.caps.env import check as env_check

    root = _du_an(ctx, params)
    isa = _isa_cua(root)
    man = manifest_isa(isa)
    tc = (man.get("toolchain") or {}).get("build") or {}
    if not tc.get("cmd"):
        raise EideError("E2000", f"Manifest ISA `{isa}` không có `toolchain.build.cmd` (TGT-19)")

    bao_cao = env_check({"isa": isa}, ctx)["report"]
    thieu = [r["tool"] for r in bao_cao if not r["ok"]]
    if thieu:
        raise EideError("E4001", f"Thiếu công cụ để dựng {isa}: {', '.join(thieu)} — "
                        "`env.install` hoặc `env.guide_install`",
                        missing=thieu, isa=isa, remedy="env.install")

    # Thư mục của ĐÚNG những công cụ manifest ISA khai, để `cmake` gọi được `ninja` và `make`
    # gọi được `gcc` bên trong sandbox. Không mở cả `PATH` của người dùng: cho phép chạy chuỗi
    # công cụ đã khai khác với cho phép chạy bất cứ thứ gì máy này từng cài. Xem DEV-088.
    bin_cong_cu = [str(Path(d).parent) for r in bao_cao if (d := tools.which(r["tool"]))]

    t0 = time.perf_counter()
    ma, log_ref, err_ref = 0, None, None
    for lenh in tach_lenh(_giai_placeholder(str(tc["cmd"]), root, isa)):
        # ĐƯỜNG DẪN TUYỆT ĐỐI, không tên trần. Sandbox dựng lại `PATH` thành
        # `/usr/bin:/bin:/usr/sbin:/sbin` (SEC-25 §3), mà `cmake`/`ninja`/`make` do người dùng
        # cài thì nằm ở `/opt/homebrew/bin` (macOS), `/usr/local/bin`, hay `~/.cargo/bin`. Truyền
        # tên trần thì lệnh chết ngay ở `execvp()` với "No such file or directory" — một câu nói
        # về `cmake` mà nghe như nói về tệp nguồn, và `phan_loai_loi` xếp nó vào `unknown`.
        #
        # `env.install` và `code.static` đã giải sẵn như thế; `code.build` thì không, và vì
        # KHÔNG TEST NÀO TỪNG DỰNG THÀNH CÔNG nên chỗ này chưa bao giờ chạy tới. Hệ quả: trên
        # đúng nền tảng thứ tự 1 của PLATFORM.md, `code.build` không thể thành công.
        lenh[0] = str(tools.which(lenh[0]) or lenh[0])
        # Chạy Ở GỐC DỰ ÁN. `build.cmd` của TGT-19 viết `cmake -S . -B build`, và `artifact`
        # khai `build/*.elf` — đều tương đối so với gốc dự án. Ở thư mục tạm thì `.` rỗng và
        # `cmake` báo "does not appear to contain CMakeLists.txt": đúng về chỗ nó đứng, vô nghĩa
        # với người đọc. `root` đã nằm trong `allowed_dirs` nên không quyền nào rộng thêm ra.
        kq = chay_sandbox(lenh, ctx, network=False, allowed_dirs=[str(root)],
                          limits={"wall_s": TIMEOUT_DUNG}, cwd=str(root),
                          them_path=bin_cong_cu)
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
                      "allowed_dirs": [str(root)], "limits": {"wall_s": 60}}, ctx)
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
    truoc = _flash_lan_truoc(root)
    gh = _gioi_han(root)
    bao = {"text": text, "data": data, "bss": bss, "flash": flash, "ram": ram,
           # `flash_truoc` không dùng ở đây; nó là mốc để `code.merge` tính `size_growth_pct`
           # cho `G3-01`. Không ghi lúc ĐO thì lúc merge không còn chỗ nào biết, và ngưỡng
           # `merge_size_growth_pct` trở thành một quy tắc không bao giờ khớp.
           "flash_truoc": truoc,
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


def _flash_lan_truoc(root: Path) -> int | None:
    """Flash của lần `code.size` ĐẠT gần nhất — mốc so cho `size_growth_pct`.

    Chỉ lấy lần `passed=1`: so với một bản dựng đã tràn bộ nhớ thì "tăng 0%" nghĩa là vẫn tràn,
    và con số ấy sẽ được đọc như một tin tốt.
    """
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        r = c.execute("SELECT metrics FROM tool_report WHERE tool='size' AND passed=1"
                      " ORDER BY at DESC LIMIT 1").fetchone()
    if not r or not r[0]:
        return None
    return (json.loads(r[0]) or {}).get("flash")


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


# ---------------------------------------------------------------- CODE-07 static

# Nhận diện ISR — bằng TỪ VỰNG, không bằng trình phân tích C. Ba dạng, mỗi dạng là một quy ước
# thật của một hệ sinh thái:
#   CMSIS/STM32   void TIM2_IRQHandler(void)      — hậu tố `_IRQHandler` / `_Handler`
#   AVR (avr-libc) ISR(TIMER1_COMPA_vect)          — macro `ISR(...)`
#   trình dịch     __attribute__((interrupt)) …    — thuộc tính đứng trước
RE_TEN_ISR = re.compile(r"\b\w*(?:_IRQHandler|_Handler|_isr|_ISR)\b")
RE_ISR_MACRO = re.compile(r"^\s*ISR\s*\(", re.MULTILINE)
RE_THUOC_TINH_ISR = re.compile(r"__attribute__\s*\(\s*\(\s*interrupt|__interrupt\b")
RE_THUOC_TINH_DAY_DU = re.compile(r"__attribute__\s*\(\((?:[^()]|\([^()]*\))*\)\)")

# Định nghĩa hàm. Khoảng trắng đầu dòng được phép vì `__attribute__((interrupt))` bị xóa thành
# khoảng trắng trước khi dò.
#
# `if (x) {` KHÔNG khớp, và không cần danh sách từ khóa để loại: khuôn đòi một token kiểu
# (`[A-Za-z_][\w \t\*]*?`) rồi mới tới tên rồi mới tới `(`, mà `if` chỉ có đúng một token trước
# ngoặc. Bản trước có một `TU_KHOA_C` để chặn chuyện ấy; đã bỏ sau khi kiểm đột biến cho thấy
# gỡ nó ra không đổi kết quả ở ca nào — một lớp bảo vệ không bao giờ chạy tới thì lần sau ai đọc
# cũng tin là nó đang bảo vệ.
RE_HAM = re.compile(r"^[ \t]*[A-Za-z_][\w \t\*]*?\b(\w+)\s*\([^;{]*\)\s*\{", re.MULTILINE)

# Ba quy tắc Pack, tên lấy đúng từ `toolchain.static.rules` của manifest ISA — không đặt tên mới.
RE_DELAY = re.compile(r"\b(\w*[Dd]elay\w*|_delay_ms|_delay_us|sleep|usleep|vTaskDelay)\s*\(")
RE_CAP_PHAT = re.compile(r"\b(malloc|calloc|realloc|free|aligned_alloc|strdup)\s*\(")
RE_SO_THUC = re.compile(r"\b(float|double)\b|\b\d+\.\d+[fF]?\b")


@capability("code.static")
def static(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-07 — CDS-12.1; TGT-19 `toolchain.static` (cmd + rules). tc: "Lỗi cố ý bị bắt";
    lỗi E4001.

    Hai lớp, và chúng trả lời hai câu khác nhau. `cppcheck` bắt lỗi C nói chung — con trỏ, tràn
    mảng, biến chưa khởi tạo. **Quy tắc Pack** bắt ba thứ mà một trình phân tích C đa dụng không
    có lý do gì để coi là lỗi, nhưng trên vi điều khiển thì là lỗi:

    - `no_delay_in_isr` — chờ bận trong ngắt khóa mọi ngắt ưu tiên thấp hơn, và trên một hệ có
      watchdog thì nó là một lần khởi động lại.
    - `no_malloc` — cấp phát động trên hệ nhúng dẫn tới phân mảnh không hồi phục được; hệ chạy
      hàng tháng thì hỏng sau vài tuần, tức sau khi đã xuất xưởng.
    - `no_float_isr_without_fpu` — số thực không FPU là gọi thư viện phần mềm, hàng trăm chu kỳ
      trong một chỗ phải đo bằng chục chu kỳ.

    Tên ba quy tắc lấy nguyên từ `toolchain.static.rules` của manifest, không đặt tên mới: một
    finding mang tên khác tên trong Pack thì không nối được về quy tắc nào cả.

    Thiếu cả `cppcheck` lẫn `clang-tidy` → **E4001, nhưng mang theo `partial_findings`**. Ném
    lỗi trắng thì các phát hiện của quy tắc Pack — vốn chạy được mà không cần công cụ nào — bị
    vứt đi cùng, và người dùng mất thông tin chỉ vì máy thiếu một gói.
    """
    from eide.caps.env import sandbox as env_sandbox

    root = _du_an(ctx, params)
    isa = _isa_cua(root)
    tc_static = (manifest_isa(isa).get("toolchain") or {}).get("static") or {}

    t0 = time.perf_counter()
    pack = _quy_tac_pack(root, isa, tc_static.get("rules") or [])

    cong_cu = next((c for c in ("cppcheck", "clang-tidy") if tools.which(c)), None)
    if cong_cu is None:
        raise EideError("E4001", "Thiếu cppcheck (và clang-tidy) — `env.install`. Các quy tắc "
                        f"Pack vẫn chạy và tìm được {len(pack)} phát hiện, kèm trong lỗi này.",
                        missing=["cppcheck"], remedy="env.install", partial_findings=pack)

    lenh = tach_lenh(str(tc_static.get("cmd") or f"{cong_cu} src"))[0]
    lenh[0] = str(tools.which(lenh[0]) or lenh[0])
    kq = env_sandbox({"cmd": lenh, "network": False, "allowed_dirs": [str(root)],
                      "limits": {"wall_s": 300}}, ctx)
    ngoai = _doc_cppcheck(Path(kq["stderr_ref"]), Path(kq["stdout_ref"]))

    ds = pack + ngoai
    rep = {"tool": "static", "passed": not ds, "log_ref": kq["stderr_ref"],
           "metrics": {"isa": isa, "tool": cong_cu, "findings": ds,
                       "by_rule": _dem(ds), "pack_rules": tc_static.get("rules") or []},
           "artifacts": [], "duration_ms": int((time.perf_counter() - t0) * 1000),
           "started_by": ctx.session_id, "at": datetime.now(UTC).isoformat()}
    store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", rep)
    return {"report": rep}


def _dem(ds: list[dict[str, Any]]) -> dict[str, int]:
    ra: dict[str, int] = {}
    for f in ds:
        ra[f["rule"]] = ra.get(f["rule"], 0) + 1
    return ra


RE_CPPCHECK = re.compile(r"^(?P<file>[^:]+):(?P<line>\d+):(?:\d+:)?\s*"
                         r"(?P<sev>error|warning|style|performance|portability|information):\s*"
                         r"(?P<msg>.+?)(?:\s*\[(?P<id>[\w\-\.]+)\])?$", re.MULTILINE)


def _doc_cppcheck(*refs: Path) -> list[dict[str, Any]]:
    """cppcheck in ra **stderr**, không phải stdout — đọc nhầm luồng thì mọi dự án đều "sạch"."""
    ra: list[dict[str, Any]] = []
    for f in refs:
        if not f.exists():
            continue
        for m in RE_CPPCHECK.finditer(f.read_text(encoding="utf-8", errors="replace")):
            ra.append({"file": m["file"], "line": int(m["line"]),
                       "severity": "major" if m["sev"] == "error" else "minor",
                       "rule": m["id"] or f"cppcheck.{m['sev']}", "message": m["msg"].strip()})
    return ra


def _quy_tac_pack(root: Path, isa: str, rules: list[str]) -> list[dict[str, Any]]:
    """Ba quy tắc Pack trên mọi tệp C của dự án. Chỉ chạy quy tắc có TRONG manifest: bật một quy
    tắc mà Pack không khai là áp luật của ISA này lên ISA khác."""
    co_fpu = _co_fpu(root, isa)
    ra: list[dict[str, Any]] = []
    for f in sorted(root.rglob("*")):
        if f.suffix not in DUOI_C or not f.is_file() or EIDE_DIR in f.parts or "build" in f.parts:
            continue
        ra += _quet_pack(f.relative_to(root), f.read_text(encoding="utf-8", errors="replace"),
                         rules, co_fpu)
    return ra


def _quet_pack(duong: Path, noi_dung: str, rules: list[str],
               co_fpu: bool | None) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    dong_ds = noi_dung.splitlines()

    if "no_malloc" in rules:
        for i, dong in enumerate(dong_ds, 1):
            sach = _bo_chu_thich_va_chuoi(dong)
            for m in RE_CAP_PHAT.finditer(sach):
                ra.append(_pf(duong, i, "no_malloc", "major",
                              f"cấp phát động `{m.group(1)}` — phân mảnh heap trên hệ chạy dài "
                              "là lỗi xuất hiện sau khi đã xuất xưởng"))

    for ten, dau, cuoi in _than_isr(noi_dung):
        for i in range(dau, cuoi + 1):
            sach = _bo_chu_thich_va_chuoi(dong_ds[i - 1])
            if "no_delay_in_isr" in rules and (m := RE_DELAY.search(sach)):
                ra.append(_pf(duong, i, "no_delay_in_isr", "blocker",
                              f"`{m.group(1)}` trong ISR `{ten}` — chờ bận trong ngắt khóa mọi "
                              "ngắt ưu tiên thấp hơn"))
            if "no_float_isr_without_fpu" in rules and co_fpu is not True \
                    and RE_SO_THUC.search(sach):
                chac = co_fpu is False
                ra.append(_pf(duong, i, "no_float_isr_without_fpu",
                              "major" if chac else "minor",
                              f"số thực trong ISR `{ten}` — "
                              + ("chip không có FPU nên đây là gọi thư viện phần mềm, hàng trăm "
                                 "chu kỳ" if chac else
                                 "chưa biết chip có FPU không (ghim hộ chiếu bằng "
                                 "`project.set_target` để kết luận chắc)")))
    return ra


def _pf(duong: Path, dong: int, rule: str, sev: str, msg: str) -> dict[str, Any]:
    return {"file": str(duong), "line": dong, "severity": sev, "rule": rule, "message": msg}


def _than_isr(noi_dung: str) -> list[tuple[str, int, int]]:
    """`(tên, dòng mở, dòng đóng)` của mỗi hàm là ISR. Đếm ngoặc để biết thân hàm kết thúc ở đâu.

    Phép đếm ngoặc bỏ qua ngoặc trong chuỗi và chú thích — không bỏ thì một `printf("}")` cắt
    thân hàm sớm và nửa sau của ISR không được quét.
    """
    ra: list[tuple[str, int, int]] = []
    dong_ds = noi_dung.splitlines()
    # `__attribute__((interrupt))` đứng trước tên hàm làm `RE_HAM` không khớp: ngoặc của thuộc
    # tính bị đọc như ngoặc tham số. Xóa thuộc tính bằng KHOẢNG TRẮNG CÙNG ĐỘ DÀI để mọi vị trí
    # vẫn trỏ đúng vào văn bản gốc — thay bằng chuỗi rỗng thì số dòng và phép nhìn-lui lệch hết.
    ban_do = RE_THUOC_TINH_DAY_DU.sub(lambda m: " " * len(m.group(0)), noi_dung)
    for m in RE_HAM.finditer(ban_do):
        ten = m.group(1)
        dau_dong = noi_dung.count("\n", 0, m.start()) + 1
        # Nhìn trên VĂN BẢN GỐC, từ đầu dòng trước cho tới TÊN hàm — không tới `m.start()`.
        # Thuộc tính đã bị xóa thành khoảng trắng trong `ban_do` nên nó nằm TRONG khoảng khớp,
        # không nằm trước nó; lấy tới `m.start()` thì `truoc` rỗng và thuộc tính không bao giờ
        # thấy được. Chỉ hai dòng: lui xa hơn thì một ISR ở đầu tệp làm mọi hàm sau cũng thành ISR.
        dong_nay = noi_dung.rfind("\n", 0, m.start()) + 1
        dau_khoi = noi_dung.rfind("\n", 0, max(0, dong_nay - 1)) + 1
        truoc = noi_dung[dau_khoi:m.start(1)]
        la_isr = bool(RE_TEN_ISR.fullmatch(ten) or RE_THUOC_TINH_ISR.search(truoc)
                      or RE_ISR_MACRO.search(noi_dung[m.start():m.end()]))
        if not la_isr:
            continue
        sau = ban_do.count("\n", 0, m.end() - 1) + 1
        ra.append((ten, dau_dong, _dong_dong_ngoac(dong_ds, sau)))
    for m in RE_ISR_MACRO.finditer(noi_dung):
        dau_dong = noi_dung.count("\n", 0, m.start()) + 1
        ra.append(("ISR", dau_dong, _dong_dong_ngoac(dong_ds, dau_dong)))
    return ra


def _dong_dong_ngoac(dong_ds: list[str], tu_dong: int) -> int:
    sau = 0
    for i in range(tu_dong - 1, len(dong_ds)):
        sach = _bo_chu_thich_va_chuoi(dong_ds[i])
        sau += sach.count("{") - sach.count("}")
        if sau <= 0 and i >= tu_dong - 1 and "{" in "".join(
                _bo_chu_thich_va_chuoi(d) for d in dong_ds[tu_dong - 1:i + 1]):
            return i + 1
    return len(dong_ds)


def _co_fpu(root: Path, isa: str) -> bool | None:
    """`True`/`False`/`None`. `None` = CHƯA BIẾT, và nó khác `False` ở mức nghiêm trọng của
    finding: chắc chắn không FPU là lỗi, chưa biết thì là lời nhắc."""
    abi = manifest_isa(isa).get("abi") or {}
    fpu = str(abi.get("fpu") or "").lower()
    if fpu in ("none", "no", "false"):
        return False
    if fpu in ("yes", "true", "required"):
        return True
    chip = _muc_tieu(root).get("chip")          # `optional` → phải hỏi hộ chiếu của chip
    if not chip:
        return None
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        r = c.execute("SELECT value FROM fact WHERE predicate='fpu' AND subject LIKE ?"
                      " ORDER BY id LIMIT 1", (f"%{str(chip).split('@')[0]}%",)).fetchone()
    if not r:
        return None
    return str(r[0]).strip().lower() not in ("none", "0", "false", "no")


# ---------------------------------------------------------------- CODE-08 test_host

# Bố cục kiểm thử trên máy chủ. CDS-12.1 CODE-08 nói "biên dịch host với mock ngoại vi
# (ctypes/CMock); chạy; JUnit → ToolReport" nhưng KHÔNG nói tệp nằm ở đâu, nên quy ước này do
# hiện thực đặt ra và được ghi ở DEV-063:
#
#   tests/host/test_*.c   một tệp = một chương trình test độc lập
#   tests/mock/*.c        mock ngoại vi, liên kết vào MỌI chương trình test
#   src/, include/        thư mục include
#
# Vì sao mỗi tệp một chương trình chứ không gộp: một test làm hỏng bộ nhớ thì chỉ giết chính nó,
# và tên tệp trở thành tên ca test mà không cần khung nào. Đó cũng là thành ngữ phổ biến nhất
# của unit test C nhúng — tệp test `#include` thẳng đơn vị đang kiểm.
MAU_TEST_HOST = "tests/host/test_*.c"
THU_MUC_MOCK = "tests/mock"
TRINH_DICH_HOST = ("cc", "gcc", "clang")
TIMEOUT_TEST = 120


@capability("code.test_host")
def test_host(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-08 — CDS-12.1. tc: "Test fail → passed=false"; lỗi E4000.

    Chạy trên MÁY CHỦ, không trên chip — nên nó kiểm được logic thuần (bộ lọc, máy trạng thái,
    phép quy đổi đơn vị) mà không cần board, và đó là cách duy nhất `code.self_repair` có vòng
    phản hồi trước khi có phần cứng. Cái nó KHÔNG kiểm được là thời gian thực và thanh ghi thật;
    `sim.*` rồi `bench.*` mới trả lời hai câu ấy.

    Không có tệp test nào thì `passed=false`, không phải `true`. Một dự án chưa viết test và một
    dự án có test đều xanh phải đọc khác nhau — gộp chúng lại là biến ToolReport thành thứ luôn
    nói "ổn".
    """
    root = _du_an(ctx, params)
    ds = sorted(root.glob(MAU_TEST_HOST))
    if (loc := params.get("filter")):
        ds = [f for f in ds if loc in f.name]

    t0 = time.perf_counter()
    if not ds:
        rep = _bao_test(root, [], t0, ctx,
                        f"không có tệp nào khớp `{MAU_TEST_HOST}`"
                        + (f" và bộ lọc `{loc}`" if loc else ""))
        return {"report": rep}

    cc = next((tools.which(c) for c in TRINH_DICH_HOST if tools.which(c)), None)
    if cc is None:
        raise EideError("E4001", f"Thiếu trình dịch máy chủ ({', '.join(TRINH_DICH_HOST)})",
                        missing=list(TRINH_DICH_HOST), remedy="env.install")

    mock = sorted((root / THU_MUC_MOCK).glob("*.c"))
    ca = [_mot_test(f, root, cc, mock, ctx) for f in ds]
    return {"report": _bao_test(root, ca, t0, ctx)}


def _mot_test(f: Path, root: Path, cc: Any, mock: list[Path], ctx: Context) -> dict[str, Any]:
    """Dịch rồi chạy một tệp test. Lỗi DỊCH và lỗi CHẠY là hai kết quả khác nhau, không gộp:
    cái đầu là mã không biên dịch được, cái sau là hành vi sai — hai việc phải sửa khác nhau."""
    import tempfile

    from eide.caps.env import sandbox as env_sandbox

    ra = Path(tempfile.mkdtemp(prefix="eide-host-")) / f.stem
    lenh = [str(cc), "-std=c11", "-g", "-O0", "-o", str(ra),
            f"-I{root / 'src'}", f"-I{root / 'include'}", f"-I{root / THU_MUC_MOCK}",
            str(f), *[str(m) for m in mock]]
    d = env_sandbox({"cmd": lenh, "network": False, "allowed_dirs": [str(root)],
                     "limits": {"wall_s": TIMEOUT_TEST}}, ctx)
    if d["exit_code"] != 0 or not ra.exists():
        return {"name": f.stem, "file": str(f.relative_to(root)), "status": "compile_error",
                "exit_code": d["exit_code"], "log_ref": d["stderr_ref"]}

    c = env_sandbox({"cmd": [str(ra)], "network": False,
                     "limits": {"wall_s": TIMEOUT_TEST}}, ctx)
    return {"name": f.stem, "file": str(f.relative_to(root)),
            "status": "passed" if c["exit_code"] == 0 else "failed",
            "exit_code": c["exit_code"], "log_ref": c["stdout_ref"],
            **_junit(Path(c["stdout_ref"]))}


RE_JUNIT = re.compile(r"<testsuite\b[^>]*>")


def _thuoc_tinh(the: str, ten: str) -> int:
    """Đọc một thuộc tính số của thẻ. Tách hàm vì gộp ba thuộc tính vào MỘT biểu thức chính quy
    với nhóm tùy chọn thì thứ tự thuộc tính trong tệp quyết định nhóm nào bắt được — và JUnit
    không quy định thứ tự. Đo được: `failures="2" errors="1"` đọc ra 0 và 0."""
    m = re.search(rf'\b{ten}="(\d+)"', the)
    return int(m.group(1)) if m else 0


def _junit(stdout: Path) -> dict[str, Any]:
    """"JUnit → ToolReport" của bước 1: đọc `<testsuite tests= failures= errors=>` nếu chương
    trình test in ra. Không in thì mã thoát là tất cả những gì có — và nói ra điều đó."""
    if not stdout.exists():
        return {"detail": "không có đầu ra"}
    m = RE_JUNIT.search(stdout.read_text(encoding="utf-8", errors="replace"))
    if not m:
        return {"detail": "mã thoát (chương trình test không in JUnit XML)"}
    the = m.group(0)
    return {"tests": _thuoc_tinh(the, "tests"), "failures": _thuoc_tinh(the, "failures"),
            "errors": _thuoc_tinh(the, "errors"), "detail": "JUnit XML"}


def _bao_test(root: Path, ca: list[dict[str, Any]], t0: float, ctx: Context,
              ly_do: str | None = None) -> dict[str, Any]:
    hong = [c for c in ca if c["status"] != "passed"]
    rep = {"tool": "test_host", "passed": bool(ca) and not hong,
           "log_ref": ca[0]["log_ref"] if ca else None,
           "metrics": {"total": len(ca), "failed": len(hong), "cases": ca,
                       "reason": ly_do or (f"{len(hong)}/{len(ca)} ca không đạt" if hong else None)},
           "artifacts": [], "duration_ms": int((time.perf_counter() - t0) * 1000),
           "started_by": ctx.session_id, "at": datetime.now(UTC).isoformat()}
    store.ghi_tool_report(store.store_path(root), rep)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("tool.report", rep)
    return rep


# ---------------------------------------------------------------- CODE-01 generate_module

THU_MUC_PATCH = "patches"

# Bước 4 của hợp đồng: "kiểm tệp trong phạm vi". Mặc định khi bên gọi không nêu `files_allowed` —
# tác tử được viết vào mã nguồn và test của dự án, không được đụng cấu hình dựng, linker, hay
# bất cứ thứ gì trong `.eide/`.
PHAM_VI_MAC_DINH = ("src/", "include/", "tests/")
CAM_TUYET_DOI = (EIDE_DIR + "/", ".git/", "..")


@capability("code.generate_module")
def generate_module(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-01 — CDS-12.1; PRS-16 §3 (coder) và §4 (CodePatch); CXD-10 (compose);
    POL-17 G1 (grounding "G1 approved"). tc: "Mọi hằng số có eide:fact", TC-04;
    lỗi E5001, E5002, E5003; undo `delete_created_files`.

    Năm bước của hợp đồng, và ba trong năm là **từ chối**:

    1. Tiền điều kiện `G1 approved` — kế hoạch của feature phải đã qua cổng G1. Không có kế
       hoạch, hoặc cổng trả ASK, thì dừng: sinh mã cho một kế hoạch chưa ai duyệt là làm ngược
       thứ tự mà cả APD-08 dựng ra.
    2. `memory.compose(coder)` — ngữ cảnh có ngân sách, và **C4 là các fact của dự án**: mô hình
       không trích được id fact mà nó chưa từng thấy.
    3. Mô hình sinh CodePatch theo schema PRS-16 §4 (đọc từ `out_schemas.json`, không chép tay).
    4. `code.constant_guard` — vi phạm thì **E5003**, không phải cảnh báo. Đây là chỗ TC-04 gặp
       CODE-01, và là lý do cả tầng tri thức tồn tại.
    5. Kiểm tệp trong phạm vi → E8000 nếu ra ngoài.

    **Không ghi vào repo.** Patch nằm ở `.eide/patches/<id>.json` cho tới khi `code.merge` qua
    cổng G3. Sinh mã và ghi mã là hai quyết định khác nhau, và chỉ quyết định thứ hai mới cần
    reviewer khác hãng.

    `missing_facts` của mô hình được TÔN TRỌNG: coder khai nó khi cần một hằng số mà C4 không
    có, và prompt PRS-16 §3 dạy nó "dừng và trả missing_facts[]" thay vì bịa. Phạt nó vì trung
    thực thì lần sau nó bịa cho đủ — cùng bài học với `doc.section`.
    """
    from eide.caps.plan import doc_plan_feature

    root = _du_an(ctx, params)
    step_ref = str(params["step_ref"])
    feature = step_ref.split("/")[0]

    ke_hoach = doc_plan_feature(root, feature)
    if ke_hoach is None:
        raise EideError("E2000", f"Chưa có kế hoạch cho `{feature}` — chạy `plan.create` trước "
                        "(CODE-01 đòi grounding \"G1 approved\")",
                        exists=[], candidates=[], missing=[f"plan/{feature}"])
    qd = ke_hoach.get("decision") or {}
    if qd.get("decision") != "APPROVE":
        raise EideError("E3000", f"Kế hoạch `{feature}` chưa qua cổng G1 "
                        f"({qd.get('decision') or 'chưa hỏi'} — {qd.get('reason') or '?'}). "
                        "CODE-01 đòi grounding \"G1 approved\".",
                        gate="G1", rule=qd.get("rule"), feature=feature, plan_decision=qd)

    buoc = _tim_buoc(ke_hoach, step_ref)
    pham_vi = list(params.get("files_allowed") or PHAM_VI_MAC_DINH)

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    patch = sinh_patch(root, gw, step_ref, _de_bai(step_ref, buoc, pham_vi), pham_vi, ctx,
                       ngu_canh_cho=step_ref)
    return {"patch": patch, "cites": list(patch.get("cites") or [])}


def sinh_patch(root: Path, gw: Any, tham_chieu: str, de_bai: str, pham_vi: list[str],
               ctx: Context, *, ngu_canh_cho: str = "", them: str = "") -> dict[str, Any]:
    """Một lượt coder → CodePatch → ba phép kiểm → lưu patch tạm.

    Bốn năng lực đi qua đúng đường này — `generate_module`, `modify`, `integrate`,
    `self_repair` — nên nó nằm ở một chỗ. Bốn bản sao của cùng ba phép kiểm là bốn chỗ để quên
    một phép, và cái bị quên sẽ là `constant_guard`: nó là phép duy nhất trong ba cái mà bỏ đi
    thì mọi test khác vẫn xanh.

    Thứ tự ba phép kiểm cũng cố định: `missing_facts` trước (mô hình tự khai thiếu), rồi phạm vi
    tệp, rồi hằng số. Đảo lại thì một patch ngoài phạm vi bị báo là "hằng số không nguồn", và
    người đọc đi sửa sai chỗ.
    """
    from eide.caps.memory import compose
    bundle = compose({"role": "coder", "task_ref": ngu_canh_cho or tham_chieu}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    if them:
        ngu_canh += "\n\n" + them

    resp = gw.run("coder", de_bai, _schema_codepatch(), system_extra=ngu_canh)
    patch = dict(resp.data)
    # Ai viết patch này — cần cho HAI hợp đồng sau: CODE-11 đòi grounding "≥ 2 hãng", và quy tắc
    # `G3-01` so `reviewer.vendor != coder.vendor`. Không ghi lại lúc sinh thì lúc merge không
    # còn chỗ nào biết, và cả hai điều kiện ấy chỉ còn cách tin lời bên gọi.
    patch["by"] = {"role": "coder", "model_id": resp.model_id,
                   "vendor": gw.hang_cua(resp.model_id)}

    if (thieu := patch.get("missing_facts")):
        raise EideError("E5003", "Coder dừng vì thiếu fact cho hằng số phần cứng: "
                        + ", ".join(str(x) for x in thieu)
                        + ". Dùng `kg.request`/`search.*` để bổ sung rồi gọi lại.",
                        missing_facts=list(thieu), step_ref=tham_chieu, violations=[])

    if (ngoai := _ngoai_pham_vi(patch, pham_vi)):
        raise EideError("E8000", f"Patch chạm tệp ngoài phạm vi cho phép: {ngoai}",
                        files=ngoai, allowed=pham_vi, violations=["path"])

    kq = constant_guard({"patch": patch}, ctx)
    if kq["verdict"] == "block":
        raise EideError("E5003", f"{len(kq['violations'])} hằng số phần cứng không có nguồn hợp "
                        "lệ (TC-04) — patch không được lưu.",
                        violations=kq["violations"], step_ref=tham_chieu)

    patch["id"] = _luu_patch(root, tham_chieu, patch, ctx)
    return patch


def _schema_codepatch() -> dict[str, Any]:
    from eide.caps.plan import schema_vai_tro
    return schema_vai_tro("CodePatch")


def _tim_buoc(ke_hoach: dict[str, Any], step_ref: str) -> dict[str, Any]:
    """Bước cụ thể trong kế hoạch. Không tìm thấy thì trả rỗng chứ không ném lỗi: `step_ref` có
    thể trỏ cả một feature (`F-04`), và lúc ấy đề bài là chính feature ấy."""
    ma = step_ref.split("/", 1)[1] if "/" in step_ref else None
    ds = ((ke_hoach.get("plan") or {}).get("steps")) or []
    return next((b for b in ds if str(b.get("id")) == ma), {}) if ma else {}


def _de_bai(step_ref: str, buoc: dict[str, Any], pham_vi: list[str]) -> str:
    d = [f"Viết mã cho bước `{step_ref}`."]
    if buoc.get("goal"):
        d.append(f"Mục tiêu: {buoc['goal']}")
    if buoc.get("done_when"):
        d.append(f"Xong khi: {buoc['done_when']}")
    if buoc.get("touches"):
        d.append(f"Bước này chạm: {', '.join(buoc['touches'])}")
    d.append("Chỉ được sửa tệp trong: " + ", ".join(pham_vi))
    return "\n".join(d)


def _ngoai_pham_vi(patch: dict[str, Any], pham_vi: list[str]) -> list[str]:
    """Đường dẫn phải nằm trong phạm vi, và `..` bị TỪ CHỐI chứ không được rút gọn.

    `src/../.eide/policy.sig` bắt đầu bằng `src/`, nên một phép so tiền tố thô cho nó qua — và
    tác tử ghi đè được chữ ký chính sách bằng một patch trông hoàn toàn trong phạm vi.

    Từ chối thay vì rút gọn rồi so lại, vì một `..` trong đường dẫn của patch không bao giờ là ý
    định lành: coder được cho danh sách thư mục cho phép, và cách viết đúng luôn là đường dẫn
    thẳng. Rút gọn rồi cho qua là dạy nó rằng lối vòng cũng chấp nhận được.
    """
    ra: list[str] = []
    for f in patch.get("files") or []:
        p = str(f.get("path") or "")
        chuan = PurePosixPath(p.replace("\\", "/"))
        if p.startswith("/") or any(x == ".." for x in chuan.parts):
            ra.append(p)
            continue
        s = str(chuan)
        if any(s.startswith(c) for c in CAM_TUYET_DOI) or not any(
                s == c.rstrip("/") or s.startswith(c) for c in pham_vi):
            ra.append(p)
    return ra


def _luu_patch(root: Path, step_ref: str, patch: dict[str, Any], ctx: Context) -> str:
    """Lưu patch tạm — bước 5 của hợp đồng: "không ghi repo cho tới merge"."""
    import secrets
    pid = "patch_" + secrets.token_hex(6)
    f = root / EIDE_DIR / THU_MUC_PATCH / f"{pid}.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps({"id": pid, "step_ref": step_ref, "patch": patch,
                             "at": datetime.now(UTC).isoformat()},
                            ensure_ascii=False, indent=1), encoding="utf-8")
    # `undo.register`, không phải một loại sự kiện mới: API-15 §5 là enum ĐÓNG, và undo của
    # CODE-01 đúng là `delete_created_files` — tệp patch chính là thứ nó sẽ xóa.
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"patch:{pid}", "kind": "delete_created_files",
                                     "cap": "code.generate_module", "step_ref": step_ref,
                                     "files": [x.get("path") for x in (patch.get("files") or [])],
                                     "cites": patch.get("cites") or []})
    return pid


def doc_patch(root: Path, pid: str) -> dict[str, Any] | None:
    f = root / EIDE_DIR / THU_MUC_PATCH / f"{pid}.json"
    return json.loads(f.read_text(encoding="utf-8")) if f.exists() else None


# ---------------------------------------------------------------- CODE-09 generate_tests

# `kind` theo mô tả output của CODE-09: "path, content, kind host|sim|hil". Ba loại chạy ở ba
# nơi khác nhau, và thư mục theo đó — cùng quy ước với `code.test_host` (DEV-063).
LOAI_TEST = {"host": "tests/host/", "sim": "tests/sim/", "hil": "tests/hil/"}

_SCHEMA_TESTS = {
    "type": "object",
    "required": ["tests"],
    "properties": {"tests": {"type": "array", "items": {
        "type": "object", "required": ["path", "content", "kind"],
        "properties": {"path": {"type": "string"}, "content": {"type": "string"},
                       "kind": {"type": "string", "enum": list(LOAI_TEST)},
                       "covers": {"type": "string"}}}}},
}


@capability("code.generate_tests")
def generate_tests(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-09 — CDS-12.1; PRS-16 §3; PLAN-01 (`expectation`). tc: "Có ít nhất 1 test host
    và 1 kịch bản"; lỗi E5002; undo `delete_created_files`.

    Nguồn của test là **`expectation` của Feature**, không phải là mã. Đó là cả điểm của việc
    `plan.define_feature` ép kỳ vọng thành thứ máy quan sát được: một test sinh từ mã chỉ khẳng
    định mã làm đúng cái nó đang làm, còn test sinh từ kỳ vọng mới bắt được lúc mã làm sai.

    tc đòi **hai loại**, và đó là một đòi hỏi có lý chứ không phải chỉ tiêu số lượng: test host
    kiểm được logic thuần ngay hôm nay mà không cần gì; kịch bản `sim`/`hil` kiểm phần chạm
    ngoại vi, thứ mà host không bao giờ chạm tới. Chỉ có một loại thì hoặc bỏ trống nửa hệ
    thống, hoặc phải chờ board mới biết mình sai.
    """
    from eide.caps.memory import compose

    root = _du_an(ctx, {})
    feature = str(params["feature"])
    ft = _doc_feature(root, feature)
    if ft is None:
        raise EideError("E2000", f"Không có feature `{feature}` trong FEATURES.json",
                        exists=[], candidates=[], missing=[feature])

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    bundle = compose({"role": "coder", "task_ref": feature}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("coder", _de_bai_test(feature, ft), _SCHEMA_TESTS, system_extra=ngu_canh)

    ds = [dict(x) for x in (resp.data.get("tests") or [])]
    for x in ds:
        x["path"] = _duong_test(str(x.get("path") or ""), str(x.get("kind") or "host"))

    loai = {x["kind"] for x in ds}
    if "host" not in loai or not (loai & {"sim", "hil"}):
        raise EideError("E5002", "CODE-09 đòi ít nhất 1 test host VÀ 1 kịch bản sim/hil; "
                        f"nhận được {sorted(loai) or 'không có test nào'}. Test host kiểm logic "
                        "thuần ngay hôm nay; kịch bản kiểm phần chạm ngoại vi mà host không "
                        "bao giờ chạm tới.", kinds=sorted(loai), feature=feature)
    return {"tests": ds}


def _duong_test(duong: str, kind: str) -> str:
    """Đưa đường dẫn về đúng thư mục của loại. Mô hình hay trả `test_x.c` trần hoặc `tests/x.c`;
    để nguyên thì `code.test_host` không tìm thấy, và cả vòng sinh-dựng-kiểm đứt ở khớp giữa hai
    năng lực của cùng một nhóm."""
    thu_muc = LOAI_TEST.get(kind, LOAI_TEST["host"])
    ten = PurePosixPath(duong.replace("\\", "/")).name or "test.c"
    if kind == "host" and not ten.startswith("test_"):
        ten = "test_" + ten
    return thu_muc + ten


def _doc_feature(root: Path, feature: str) -> dict[str, Any] | None:
    f = root / EIDE_DIR / "FEATURES.json"
    if not f.exists():
        return None
    ds = json.loads(f.read_text(encoding="utf-8"))
    ds = ds if isinstance(ds, list) else (ds.get("features") or [])
    return next((x for x in ds if str(x.get("id")) == feature), None)


def _de_bai_test(feature: str, ft: dict[str, Any]) -> str:
    ky_vong = ft.get("expectation") or {}
    d = [f"Sinh test cho feature `{feature}`: {ft.get('title') or ''}".rstrip(),
         f"Kỳ vọng ({ky_vong.get('kind')}): {ky_vong.get('detail')}"]
    if ft.get("constraints"):
        d.append("Ràng buộc: " + "; ".join(str(x) for x in ft["constraints"]))
    d.append("Cần ÍT NHẤT một test `host` (logic thuần, chạy trên máy chủ) và một kịch bản "
             "`sim` hoặc `hil` (phần chạm ngoại vi).")
    return "\n".join(d)


# ---------------------------------------------------------------- CODE-11 review


@capability("code.review")
def review(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-11 — CDS-12.1; PRS-16 §3 (reviewer) và §4 (Review); models.yaml
    `roles.reviewer.rule = different_vendor_from(coder)`. Grounding **"≥ 2 hãng"**.
    tc: TC-24, TC-30; lỗi E5002.

    **Reviewer phải khác hãng với coder**, và đó không phải sự cầu kỳ: hai mô hình cùng hãng
    chia nhau dữ liệu huấn luyện và cả những chỗ mù của nhau, nên một lỗi mà coder không thấy
    thì reviewer cùng hãng cũng có xu hướng không thấy. Cả cơ chế review chỉ có giá trị bằng
    phần độc lập giữa hai bên.

    Không sửa mã — bước 1 của hợp đồng nói thẳng "không sửa mã". Reviewer trả `findings` có
    tệp:dòng; ai sửa là việc của `code.self_repair`. Trộn hai vai vào một lượt gọi thì mô hình
    vừa chấm vừa chữa bài của chính nó.

    Hãng của cả hai bên vào ledger (`vendors`) vì `G3-01` đọc đúng cặp ấy khi quyết định merge.
    """
    root = _du_an(ctx, {})
    patch = params["patch"] or {}
    hang_coder = ((patch.get("by") or {}).get("vendor"))

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    from eide.caps.memory import compose
    bundle = compose({"role": "reviewer", "task_ref": str(patch.get("id") or "")}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("reviewer", _de_bai_review(patch), _schema_review(), system_extra=ngu_canh)
    hang_reviewer = gw.hang_cua(resp.model_id)

    rv = dict(resp.data)
    rv["vendors"] = {"coder": hang_coder, "reviewer": hang_reviewer}
    # Nói ra khi ĐỘC LẬP không đạt, thay vì lặng lẽ trả một Review trông bình thường. Một bản
    # review cùng hãng vẫn có ích, nhưng nó KHÔNG thỏa grounding "≥ 2 hãng" của CODE-11, và
    # `G3-01` sẽ từ chối — người đọc cần biết lý do ngay ở đây chứ không phải ở cổng.
    rv["independent"] = bool(hang_coder and hang_reviewer and hang_coder != hang_reviewer)
    if not rv["independent"]:
        rv["note"] = (f"reviewer ({hang_reviewer}) không khác hãng với coder ({hang_coder}) — "
                      "chưa thỏa grounding \"≥ 2 hãng\" của CODE-11")
    rv["max_severity"] = _muc_nang_nhat(rv.get("findings") or [])

    rid = _luu_review(root, patch, rv, ctx)
    rv["id"] = rid
    return {"review": rv}


MUC_DO = ["nit", "minor", "major", "blocker"]


def _muc_nang_nhat(ds: list[dict[str, Any]]) -> str:
    """`G3-01` so `review.max_severity in ["minor","nit","none"]`, nên `"none"` là giá trị khi
    KHÔNG có finding nào — không phải chuỗi rỗng, và không phải thiếu trường."""
    co = [str(f.get("severity")) for f in ds if f.get("severity") in MUC_DO]
    return max(co, key=MUC_DO.index) if co else "none"


def _schema_review() -> dict[str, Any]:
    from eide.caps.plan import schema_vai_tro
    return schema_vai_tro("Review")


def _de_bai_review(patch: dict[str, Any]) -> str:
    d = ["Rà patch sau theo checklist nhúng. KHÔNG sửa mã — chỉ nêu findings kèm tệp:dòng."]
    if patch.get("rationale"):
        d.append(f"Lý do của coder: {patch['rationale']}")
    for f in patch.get("files") or []:
        d.append(f"\n--- {f.get('path')} ---\n{f.get('content') or ''}")
    return "\n".join(d)


def _luu_review(root: Path, patch: dict[str, Any], rv: dict[str, Any], ctx: Context) -> str:
    import secrets
    rid = "rv_" + secrets.token_hex(6)
    f = root / EIDE_DIR / "reviews" / f"{rid}.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps({"id": rid, "patch_id": patch.get("id"), "review": rv,
                             "at": datetime.now(UTC).isoformat()},
                            ensure_ascii=False, indent=1), encoding="utf-8")
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("model.call", {"role": "reviewer", "review_id": rid,
                                  "vendors": rv["vendors"], "verdict": rv.get("verdict"),
                                  "max_severity": rv["max_severity"]})
    return rid


def doc_review(root: Path, rid: str) -> dict[str, Any] | None:
    f = root / EIDE_DIR / "reviews" / f"{rid}.json"
    return json.loads(f.read_text(encoding="utf-8")) if f.exists() else None


# ---------------------------------------------------------------- CODE-12 merge

# "4 cổng" của G3-01 (`patch.tools_passed == 4`). Bốn cái này, không phải bốn cái bất kỳ: dựng
# được, vừa bộ nhớ, sạch phân tích tĩnh, qua test máy chủ. Đó là toàn bộ bằng chứng MÁY có thể
# đưa ra trước khi chạm phần cứng.
BON_CONG = ("build", "size", "static", "test_host")

# Tệp chạm tới linker hoặc khởi động — `patch.touches_isr_linker` của G3-01. Sai một dòng trong
# `.ld` hay `startup_*.s` thì firmware không khởi động, và triệu chứng không trỏ về chỗ sai.
RE_TEP_LINKER = re.compile(r"(?:^|/)(?:.*\.ld|.*\.icf|.*linker.*|startup[_.].*|.*vector.*)$",
                           re.IGNORECASE)

LOAI_COMMIT = "feat"          # CON-28 §4: type ∈ feat|fix|docs|refactor|test|chore|knowledge


@capability("code.merge", features=["tools_passed", "constant_guard_violations", "verdict",
                                    "max_severity", "in_scope", "size_growth_pct",
                                    "touches_isr_linker", "vendors"])
def merge(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-12 — CDS-12.1; POL-17 G3-01…04; CON-28 §4 (nhánh, thông điệp, trailer, tag);
    APD-08 (cửa sổ hoàn tác). tc: S23…S28, TC-52; lỗi E3000, E3001, E7001; undo `git_revert`.

    Đây là chỗ mã **thật sự vào kho**, và cũng là chỗ duy nhất trong cả nhóm `code.*` cần bốn
    loại bằng chứng cùng lúc: bốn báo cáo công cụ, một bản review khác hãng, phép quét hằng số,
    và phạm vi tệp. Bảy đặc trưng của `G3-01` được **tính lại ở đây**, không nhận từ bên gọi —
    một cổng đọc con số do bên xin cấp phép tự khai thì không phải là cổng.

    `constant_guard` chạy LẠI dù `code.generate_module` đã chạy. Patch nằm trên đĩa giữa hai lần
    gọi và có thể đã bị sửa; và `G3-03` là quy tắc REJECT ở ưu tiên 1 — thứ đáng chạy lại.

    Nhánh `auto/<feature>` theo CON-28 §4: mã do tác tử sinh không vào thẳng `main`. Thông điệp
    commit mang trailer `Eide-Facts` / `Eide-Run` / `Eide-Model` / `Eide-Prompt` để mỗi dòng mã
    truy về được fact, lượt chạy, và mô hình đã viết nó.
    """
    from eide_core import git

    root = _du_an(ctx, {})
    patch = params["patch"] or {}
    feature = str(params["feature"])
    dac_trung = dac_trung_G3(root, patch, params["reports"], str(params["review_id"]), ctx)

    gate = ctx.extra.get("gate")
    d = gate.decide("G3", dac_trung, risk="R2", autonomy=ctx.autonomy, tier="T1*",
                    actor=ctx.actor) if gate else None
    if d is not None and d.decision == "REJECT":
        raise EideError("E3001", f"Cổng G3 từ chối merge: {d.reason} ({d.rule_id})",
                        rule=d.rule_id, reason=d.reason, gate="G3", features=dac_trung)
    if d is not None and d.decision != "APPROVE":
        raise EideError("E3000", f"Merge cần người duyệt: {d.reason} ({d.rule_id})",
                        rule=d.rule_id, reason=d.reason, gate="G3", features=dac_trung)

    git.dam_bao_kho(root)
    nhanh = f"auto/{feature}"
    git.sang_nhanh(root, nhanh)
    duong = _ghi_tep(root, patch)

    by = patch.get("by") or {}
    tin_nhan = git.thong_diep(
        LOAI_COMMIT, feature, patch.get("rationale") or f"sinh mã cho {feature}",
        {"Eide-Facts": patch.get("cites") or [], "Eide-Run": ctx.session_id,
         "Eide-Model": by.get("model_id"), "Eide-Prompt": _bam_prompt(patch),
         "Eide-Review": params["review_id"]})
    sha = git.commit(root, tin_nhan, duong)
    tag = git.dat_tag(root, f"known-good/{datetime.now(UTC).date().isoformat()}")

    _ghi_code_unit(root, patch, sha)
    han = _dang_ky_undo(ctx, sha, feature)
    # Tên tag vào ledger chứ không vào kết quả: hợp đồng CODE-12 khai đúng ba trường
    # (`additionalProperties: false`). Nó vẫn phải ghi lại được ở đâu đó — một tag không ai biết
    # tên thì lần sau muốn quay về known-good phải đi dò.
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("report", {"cap": "code.merge", "commit": sha, "branch": nhanh, "tag": tag,
                              "feature": feature, "files": duong,
                              "cites": patch.get("cites") or []})
    return {"commit": sha, "branch": nhanh, "undo_until": han}


def dac_trung_G3(root: Path, patch: dict[str, Any], reports: list[str], review_id: str,
                 ctx: Context) -> dict[str, Any]:
    """Bảy đặc trưng mà `G3-01` hỏi (POL-17 §2), TÍNH LẠI từ store và từ chính patch.

    Bên gọi truyền vào `reports` và `review_id` — hai con TRỎ, không phải hai kết luận. Nhận
    thẳng `tools_passed=4` từ bên gọi thì bất kỳ ai gọi được năng lực này cũng merge được bất
    kỳ thứ gì.
    """
    from eide.caps.code import doc_review

    bao = _doc_reports(root, reports)
    dat = {b["tool"] for b in bao if b.get("passed")}
    rv = (doc_review(root, review_id) or {}).get("review") or {}
    ven = rv.get("vendors") or {}
    return {
        "patch": {
            "tools_passed": sum(1 for t in BON_CONG if t in dat),
            "constant_guard_violations": len(
                constant_guard({"patch": patch}, ctx)["violations"]),
            "in_scope": not _ngoai_pham_vi(patch, list(PHAM_VI_MAC_DINH)),
            "size_growth_pct": _tang_kich_thuoc(bao),
            "touches_isr_linker": _cham_isr_linker(patch),
        },
        "review": {"verdict": rv.get("verdict"), "max_severity": rv.get("max_severity", "none")},
        "coder": {"vendor": (patch.get("by") or {}).get("vendor")},
        "reviewer": {"vendor": ven.get("reviewer")},
    }


def _doc_reports(root: Path, ids: list[str]) -> list[dict[str, Any]]:
    db = store.store_path(root)
    if not db.exists() or not ids:
        return []
    with store.open_store(db) as c:
        rows = c.execute(
            f"SELECT tool, passed, metrics FROM tool_report WHERE id IN ({','.join('?' * len(ids))})",  # noqa: S608
            list(ids)).fetchall()
    return [{"tool": t, "passed": bool(p), "metrics": json.loads(m) if m else {}}
            for t, p, m in rows]


def _tang_kich_thuoc(bao: list[dict[str, Any]]) -> float:
    """`size_growth_pct` — phần trăm Flash tăng thêm so với lần đo TRƯỚC.

    Không có lần trước thì 0, và đó là câu trả lời đúng chứ không phải giá trị an toàn cho qua:
    lần dựng đầu tiên của một feature không "tăng" so với gì cả. Ngưỡng `merge_size_growth_pct`
    canh việc một patch nhỏ làm phình firmware, và chuyện ấy chỉ có nghĩa khi có mốc để so.
    """
    m = next((b["metrics"] for b in bao if b["tool"] == "size"), None)
    if not m:
        return 0.0
    truoc, nay = m.get("flash_truoc"), m.get("flash")
    if not truoc or not nay:
        return 0.0
    return round((nay - truoc) / truoc * 100, 2)


def _cham_isr_linker(patch: dict[str, Any]) -> bool:
    """Chạm tới ISR hoặc kịch bản liên kết. Hai thứ này gộp trong một đặc trưng của POL-17 vì
    chúng cùng một loại rủi ro: sai thì firmware không chạy, và triệu chứng không trỏ về chỗ
    sai — người gỡ sẽ đi tìm trong mã ứng dụng."""
    for f in patch.get("files") or []:
        duong = str(f.get("path") or "")
        if RE_TEP_LINKER.search(duong):
            return True
        if Path(duong).suffix in DUOI_C and _than_isr(str(f.get("content") or "")):
            return True
    return False


def _ghi_tep(root: Path, patch: dict[str, Any]) -> list[str]:
    ra: list[str] = []
    for f in patch.get("files") or []:
        d = root / str(f.get("path"))
        d.parent.mkdir(parents=True, exist_ok=True)
        d.write_text(str(f.get("content") or ""), encoding="utf-8")
        ra.append(str(f.get("path")))
    return ra


def _bam_prompt(patch: dict[str, Any]) -> str:
    """`Eide-Prompt: <hash>` của CON-28 — băm phần đầu vào đã quyết định nội dung patch.

    Băm chứ không chép: prompt đầy đủ chứa cả ngữ cảnh dự án, có thể dài hàng chục nghìn ký tự,
    và nhét nó vào thông điệp commit là nhét vào mọi lần `git log`.
    """
    import hashlib
    goc = json.dumps({"rationale": patch.get("rationale"), "cites": patch.get("cites"),
                      "files": [f.get("path") for f in (patch.get("files") or [])]},
                     ensure_ascii=False, sort_keys=True)
    return "sha256:" + hashlib.sha256(goc.encode("utf-8")).hexdigest()[:16]


def _ghi_code_unit(root: Path, patch: dict[str, Any], sha: str) -> None:
    """Bước 2: "cập nhật code_unit CITES/USES". Đây là cạnh nối MÃ về FACT trong đồ thị tri
    thức — không có nó thì `kg.impact` không biết fact nào đổi làm mã nào cũ đi."""
    import hashlib
    import secrets
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        for f in patch.get("files") or []:
            noi_dung = str(f.get("content") or "")
            c.execute("INSERT INTO code_unit (id, path, hash, cites, uses, stale)"
                      " VALUES (?,?,?,?,?,0)",
                      ("cu_" + secrets.token_hex(6), str(f.get("path")),
                       hashlib.sha256(noi_dung.encode("utf-8")).hexdigest(),
                       json.dumps(patch.get("cites") or []), json.dumps([])))
        c.commit()


def _dang_ky_undo(ctx: Context, sha: str, feature: str) -> str:
    """`undo: git_revert`, cửa sổ 24 h theo `undo_window.merge` của POL-17 §3."""
    from eide_core.undo import UndoService
    led = ctx.extra.get("ledger")
    if led is None:
        return ""
    reg = UndoService(led, (getattr(ctx.extra.get("gate"), "config", None) or {}))
    return str(reg.register(f"commit:{sha}", "git_revert", cap="code.merge").get("deadline") or "")


# ---------------------------------------------------------------- CODE-13 revert


@capability("code.revert")
def revert(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-13 — CDS-12.1; CON-28 §4. tc: "Build đạt sau revert"; lỗi E7001.

    `git revert` chứ không `git reset`: lịch sử của một kho có mã do tác tử sinh phải cộng dồn,
    không được viết lại. Ai đọc `git log` sau này cần thấy CẢ hai việc — đã merge, rồi đã hoàn
    tác vì lý do gì — chứ không thấy một khoảng trống.
    """
    from eide_core import git

    root = _du_an(ctx, {})
    sha, ly_do = str(params["commit"]), str(params["reason"])
    if not git.la_kho(root):
        raise EideError("E7001", f"{root} chưa phải kho git — không có gì để hoàn tác",
                        commit=sha)
    if git.chay(root, "rev-parse", "--verify", "--quiet", f"{sha}^{{commit}}",
                kiem=False).returncode != 0:
        raise EideError("E7001", f"Không có commit `{sha}` trong kho", commit=sha)

    git.chay(root, "revert", "--no-edit", "--no-commit", sha)
    moi = git.commit(root, git.thong_diep(
        "fix", "revert", f"hoàn tác {sha[:8]}: {ly_do}",
        {"Eide-Revert": sha, "Eide-Run": ctx.session_id}), ["."])
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.apply", {"undo_ref": f"commit:{sha}", "kind": "git_revert",
                                  "revert_commit": moi, "reason": ly_do})
    return {"revert_commit": moi}


# ---------------------------------------------------------------- CODE-02 modify


@capability("code.modify")
def modify(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-02 — CDS-12.1; CXD-10 (lớp C5 = tệp hiện có, C6 = finding).
    tc: "Diff chỉ chạm hàm liên quan"; ask "Chạm ISR/linker"; lỗi E5003;
    undo `delete_created_files`.

    Khác `generate_module` ở một điểm quyết định mọi thứ còn lại: **tệp đã có sẵn**. Mô hình
    phải thấy nội dung hiện tại, nếu không nó viết lại cả tệp theo trí nhớ về "một driver BME280
    trông như thế nào" — và mọi thứ người khác đã sửa trong đó biến mất mà không ai thấy trong
    diff, vì diff so với bản mới chứ không so với ý định.

    `ask_when` của hợp đồng là **"Chạm ISR/linker"**, và phép kiểm chạy trên KẾT QUẢ chứ không
    trên yêu cầu: người dùng xin "thêm timeout" mà mô hình sửa luôn vector ngắt thì ý định vô
    hại, hậu quả thì không.
    """
    root = _du_an(ctx, {})
    duong = str(params["file"])
    f = root / duong
    if not f.exists():
        raise EideError("E2000", f"Không có tệp `{duong}` để sửa — `code.generate_module` tạo mã "
                        "mới, `code.modify` chỉ sửa mã đã có",
                        exists=[], candidates=[], missing=[duong])
    if _ngoai_pham_vi({"files": [{"path": duong}]}, list(PHAM_VI_MAC_DINH)):
        raise EideError("E8000", f"`{duong}` nằm ngoài phạm vi tác tử được sửa",
                        files=[duong], allowed=list(PHAM_VI_MAC_DINH), violations=["path"])

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    hien = f.read_text(encoding="utf-8", errors="replace")
    patch = sinh_patch(root, gw, f"modify:{duong}",
                       _de_bai_sua(duong, str(params["intent"]), params.get("findings") or []),
                       [duong], ctx, ngu_canh_cho=duong,
                       them=f"# C5 — nội dung hiện tại của {duong}\n```c\n{hien}\n```")

    if _cham_isr_linker(patch) and ctx.actor != "human":
        raise EideError("E3000", f"Sửa `{duong}` chạm tới ISR hoặc kịch bản liên kết — "
                        "CODE-02 ask: \"Chạm ISR/linker\". Sai một dòng ở đó thì firmware không "
                        "khởi động, và triệu chứng không trỏ về chỗ sai.",
                        rule="CODE-02", gate="*", file=duong, patch_id=patch.get("id"))
    return {"patch": patch}


def _de_bai_sua(duong: str, y_dinh: str, findings: list[dict[str, Any]]) -> str:
    d = [f"Sửa tệp `{duong}`. Ý định: {y_dinh}",
         "**Diff tối thiểu**: chỉ chạm hàm liên quan; giữ nguyên phần còn lại của tệp từng dòng "
         "một. Trả lại TOÀN BỘ nội dung tệp sau khi sửa."]
    if findings:
        d.append("Các finding cần xử lý:")
        d += [f"  - {x.get('file', duong)}:{x.get('line', '?')} [{x.get('severity', '?')}] "
              f"{x.get('message', '')}" for x in findings]
    return "\n".join(d)


# ---------------------------------------------------------------- CODE-03 integrate


@capability("code.integrate")
def integrate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-03 — CDS-12.1; PLAN-04 (`plan.order`); ARCH-06 (`arch.interface_spec`).
    tc: "Build đạt sau tích hợp"; ask "Xung đột tài nguyên"; lỗi E5003.

    Thứ tự khởi tạo KHÔNG do mô hình nghĩ ra: nó là kết quả của `plan.order`, vốn sắp theo phụ
    thuộc và theo bậc phần cứng (clock → GPIO → bus → cảm biến → app). Thứ tự ấy là ràng buộc
    vật lý — cấu hình I2C trước khi bật clock cho nó thì thanh ghi ghi vào hư không — nên hỏi mô
    hình là mời ảo giác vào chỗ có câu trả lời đúng.

    Xung đột tài nguyên được kiểm TRƯỚC khi gọi mô hình. Sinh mã glue cho hai module cùng đòi
    một chân rồi mới phát hiện là tiêu một lượt gọi để tạo ra thứ chắc chắn phải bỏ đi.
    """
    from eide.caps.plan import order as plan_order

    root = _du_an(ctx, {})
    mods = list(params["modules"])

    if (xung_dot := _xung_dot_tai_nguyen(root, mods)) and ctx.actor != "human":
        raise EideError("E3000", f"{len(xung_dot)} xung đột tài nguyên giữa các module "
                        "(CODE-03 ask: \"Xung đột tài nguyên\") — `arch.map_hw` hoặc "
                        "`board.propose_fix` trước.",
                        rule="CODE-03", gate="*", conflicts=xung_dot)

    thu_tu = plan_order({"features": mods}, ctx)["order"]
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    patch = sinh_patch(root, gw, "integrate:" + ",".join(mods),
                       _de_bai_tich_hop(thu_tu, _giao_dien(root, mods)),
                       [*PHAM_VI_MAC_DINH, "CMakeLists.txt"], ctx)
    return {"patch": patch, "init_order": thu_tu}


def _de_bai_tich_hop(thu_tu: list[str], giao_dien: dict[str, Any]) -> str:
    d = ["Sinh mã ghép nối (`main`/`app`) cho các module dưới đây.",
         "THỨ TỰ KHỞI TẠO — bắt buộc theo đúng dãy này, đã sắp theo phụ thuộc và bậc phần cứng:",
         "  " + " → ".join(thu_tu)]
    if giao_dien:
        d.append("Chữ ký giao diện đã chốt (arch.interface_spec) — gọi đúng, không đổi:")
        for m, ds in giao_dien.items():
            for s in ds:
                d.append(f"  {m}: {s}")
    d.append("Cập nhật cấu hình dựng nếu cần thêm tệp nguồn.")
    return "\n".join(d)


def _giao_dien(root: Path, mods: list[str]) -> dict[str, list[str]]:
    """Chữ ký hàm đã chốt ở `arch.interface_spec`. Không có bảng `module` thì trả rỗng và nói ra
    bằng chỗ vắng — mô hình sẽ tự đặt chữ ký, và `code.build` là chỗ phát hiện lệch."""
    db = store.store_path(root)
    if not db.exists():
        return {}
    with store.open_store(db) as c:
        if not c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='module'"
                         ).fetchone():
            return {}
        rows = c.execute(
            f"SELECT id, interfaces FROM module WHERE id IN ({','.join('?' * len(mods))})",  # noqa: S608
            mods).fetchall()
    ra: dict[str, list[str]] = {}
    for mid, iface in rows:
        try:
            ds = json.loads(iface) if iface else []
        except json.JSONDecodeError:
            continue
        sig = [str(x.get("sig")) for x in ds if isinstance(x, dict) and x.get("sig")]
        if sig:
            ra[mid] = sig
    return ra


def _xung_dot_tai_nguyen(root: Path, mods: list[str]) -> list[dict[str, Any]]:
    """Hai module cùng đòi một tài nguyên phần cứng — bảng `hw_map` của `arch.map_hw`."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        if not c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='hw_map'"
                         ).fetchone():
            return []
        rows = c.execute(
            f"SELECT module_id, resource FROM hw_map WHERE module_id IN ({','.join('?' * len(mods))})",  # noqa: S608
            mods).fetchall()
    theo: dict[str, list[str]] = {}
    for mid, res in rows:
        theo.setdefault(str(res), []).append(str(mid))
    return [{"resource": r, "modules": sorted(set(ms))} for r, ms in sorted(theo.items())
            if len(set(ms)) > 1]


# ---------------------------------------------------------------- CODE-10 self_repair

VONG_TOI_DA = 3               # "round ≤ 3"; "> 3 → give_up" (CODE-10 bước 1, ask "Lần 3")


@capability("code.self_repair")
def self_repair(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-10 — CDS-12.1; CXD-10 (C6 = lỗi đã lọc); DDD-14 `error_ledger`.
    tc: "Lỗi cú pháp sửa trong 1 vòng; lỗi thiết kế → give_up ở vòng 3"; ask "Lần 3";
    lỗi E5003.

    Giới hạn ba vòng là điểm chính, không phải phần phụ. Một mô hình sửa mãi không dừng sẽ tiêu
    hết ngân sách để đi vòng quanh cùng một lỗi thiết kế — và mỗi vòng lại trông như có tiến
    triển vì thông điệp lỗi đổi. `give_up` thành thật ở vòng ba rẻ hơn nhiều so với vòng thứ
    mười.

    **C6 là lỗi ĐÃ LỌC**, không phải cả nhật ký. Một bản dựng hỏng in ra hàng trăm dòng, trong
    đó lỗi thật là hai dòng đầu và phần còn lại là hệ quả; đưa hết vào ngữ cảnh thì mô hình đi
    sửa hệ quả. `code.build` đã phân loại và cắt 20 dòng đầu — dùng lại đúng phần ấy.
    """
    root = _du_an(ctx, {})
    vong = int(params["round"])
    patch = params["patch"] or {}
    rid = str(params["report_id"])
    bao = _doc_report_id(root, rid)
    if bao is None:
        raise EideError("E2000", f"Không có ToolReport `{rid}`", exists=[], candidates=[],
                        missing=[rid])

    if vong > VONG_TOI_DA:
        _ghi_error_ledger(root, rid, bao, patch, vong)
        if (led := ctx.extra.get("ledger")) is not None:
            led.append("policy.escalate", {"cap": "code.self_repair", "report_id": rid,
                                           "round": vong, "reason": "quá 3 vòng tự sửa"})
        return {"patch": patch, "give_up": True}

    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))

    moi = sinh_patch(root, gw, f"repair:{rid}:{vong}", _de_bai_sua_loi(bao, vong, patch),
                     list(PHAM_VI_MAC_DINH), ctx,
                     them="# C6 — lỗi của lượt trước\n" + _tom_tat_loi(bao))
    return {"patch": moi, "give_up": False}


def _doc_report_id(root: Path, rid: str) -> dict[str, Any] | None:
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        r = c.execute("SELECT tool, passed, metrics FROM tool_report WHERE id=?", (rid,)).fetchone()
    if not r:
        return None
    return {"tool": r[0], "passed": bool(r[1]),
            "metrics": json.loads(r[2]) if r[2] else {}}


def _tom_tat_loi(bao: dict[str, Any]) -> str:
    """Chỉ phần đã lọc: loại lỗi + 20 dòng `code.build` đã cắt, hoặc findings của `static`, hoặc
    các ca không đạt của `test_host`."""
    m = bao.get("metrics") or {}
    d = [f"Công cụ `{bao['tool']}` báo KHÔNG ĐẠT."]
    if m.get("error_kind"):
        d.append(f"Loại lỗi: {m['error_kind']}")
    for dong in (m.get("error_lines") or [])[:SO_DONG_LOI]:
        d.append(f"  {dong}")
    for f in (m.get("findings") or [])[:SO_DONG_LOI]:
        d.append(f"  {f.get('file')}:{f.get('line')} [{f.get('rule')}] {f.get('message')}")
    for c in (m.get("cases") or []):
        if c.get("status") != "passed":
            d.append(f"  {c.get('file')}: {c.get('status')} (mã thoát {c.get('exit_code')})")
    if m.get("reason"):
        d.append(f"  {m['reason']}")
    return "\n".join(d)


def _de_bai_sua_loi(bao: dict[str, Any], vong: int, patch: dict[str, Any]) -> str:
    d = [f"Vòng tự sửa {vong}/{VONG_TOI_DA}. Sửa patch trước cho hết lỗi mà `{bao['tool']}` báo.",
         "Sửa ĐÚNG nguyên nhân, không đi vòng: đừng tắt cảnh báo, đừng bỏ phép kiểm, đừng "
         "chú thích mã lỗi ra ngoài."]
    if vong >= VONG_TOI_DA:
        d.append("Đây là vòng cuối. Nếu nguyên nhân là một quyết định THIẾT KẾ chứ không phải "
                 "một lỗi cục bộ, hãy nói thẳng trong `rationale` thay vì thử một cách khác.")
    for f in patch.get("files") or []:
        d.append(f"\n--- {f.get('path')} ---\n{f.get('content') or ''}")
    return "\n".join(d)


def _ghi_error_ledger(root: Path, rid: str, bao: dict[str, Any], patch: dict[str, Any],
                      vong: int) -> None:
    """DDD-14 `error_ledger` — bước 1: "> 3 → give_up + error_ledger + leo thang".

    `negative_prompt` là phần có ích nhất: lần sau composer nạp nó vào C6 để mô hình không thử
    lại đúng con đường đã thất bại ba lần.
    """
    import secrets
    db = store.store_path(root)
    if not db.exists():
        return
    with store.open_store(db) as c:
        c.execute("INSERT INTO error_ledger (id, role, kind, task_ref, chip, evidence,"
                  " negative_prompt, ttl_until, at) VALUES (?,?,?,?,?,?,?,?,?)",
                  ("el_" + secrets.token_hex(6), "coder",
                   (bao.get("metrics") or {}).get("error_kind") or bao["tool"],
                   patch.get("id") or rid, _muc_tieu(root).get("chip"),
                   json.dumps({"report_id": rid, "round": vong,
                               "metrics": bao.get("metrics") or {}}, ensure_ascii=False),
                   f"Đã thử {vong - 1} vòng tự sửa cho lỗi `{bao['tool']}` mà không xong — "
                   "nhiều khả năng là quyết định thiết kế, không phải lỗi cục bộ.",
                   None, datetime.now(UTC).isoformat()))
        c.commit()


# ---------------------------------------------------------------- CODE-14 annotate

# Điểm tin cậy của một gợi ý. Ba mức, và khoảng cách giữa chúng có ý: khớp cả giá trị lẫn TÊN
# (`BME280_ADDR` ↔ fact về `bme280`) gần như chắc chắn đúng; khớp mỗi giá trị thì một địa chỉ
# `0x40` có thể là mười thứ khác nhau trong cùng một chip.
DIEM_KHOP = {"gia_tri+ten": 0.95, "gia_tri+ngu_canh": 0.7, "gia_tri": 0.4}

# Dưới ngưỡng này thì không gợi ý. `0.4` (chỉ khớp giá trị, không khớp tên) được GIỮ LẠI có chủ
# ý — nó vẫn đáng hiện, chỉ là kèm điểm thấp để người đọc biết phải tự kiểm. Cắt nó đi thì
# những hằng số khó nhất, vốn là những hằng số đáng nối nhất, không bao giờ được gợi ý.
NGUONG_GOI_Y = 0.35


@capability("code.annotate")
def annotate(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-14 — CDS-12.1; PRS-16 §3. R2, `errors: []`, `undo: none`.
    tc: "0x40005400 → f_1a2b".

    **Chiều ngược của `code.constant_guard`.** Guard hỏi *"hằng số này có nguồn chưa"* và CHẶN;
    năng lực này hỏi *"hằng số này có lẽ là fact nào"* và ĐỀ XUẤT. Cùng một phép so literal ↔
    `fact.value`, dùng lại nguyên `_khop_gia_tri` — hai phép so khác nhau cho cùng một câu hỏi
    là hai phép so sẽ lệch nhau đúng lúc quan trọng.

    **Chỉ ĐỀ XUẤT, không sửa tệp.** Hợp đồng viết rõ "người/coder áp dụng qua `code.modify`", và
    `undo: none` là hệ quả chứ không phải thiếu sót: năng lực này không đổi gì thì không có gì
    để hoàn tác. Tự chèn chú thích vào mã người viết là thay họ khẳng định rằng con số ấy ĐÚNG
    LÀ fact kia — mà điểm 0,4 nghĩa là chính ta cũng chưa chắc.

    **Bỏ qua literal ĐÃ có chú thích.** Gợi ý lại một dòng đã nối rồi là nhiễu, và tệ hơn: nếu
    fact ta gợi ý khác fact đang có, người đọc sẽ tưởng có mâu thuẫn trong khi chỉ là ta chưa
    nhìn.

    Điểm tin cậy phân ba mức vì một địa chỉ `0x40` khớp giá trị với hàng chục fact trong cùng
    một chip; chỉ khi TÊN trong mã (`BME280_ADDR`) cũng chạm vào subject của fact thì gợi ý mới
    gần như chắc chắn.
    """
    root = _du_an(ctx, params)
    f = Path(params["file"])
    if not f.is_absolute():
        f = root / f
    if not f.exists():
        return {"suggestions": []}

    facts = _fact_da_duyet(root)
    ra: list[dict[str, Any]] = []
    for i, dong in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if RE_CHU_THICH.search(dong):
            continue
        sach = _bo_chu_thich_va_chuoi(dong)
        ten_trong_dong = {t.lower() for t in RE_TEN_HOA.findall(sach)}
        for lit in _literal(sach):
            for fid, subject, predicate, value in facts:
                if not _khop_gia_tri(lit, value):
                    continue
                muc = _muc_khop(subject, predicate, ten_trong_dong, sach)
                diem = DIEM_KHOP[muc]
                if diem < NGUONG_GOI_Y:
                    continue
                ra.append({"line": i, "literal": lit, "fact_id": fid,
                           "confidence": diem, "match": muc,
                           "subject": subject, "predicate": predicate,
                           "annotation": f"/* eide:fact {fid} */"})
    # Cùng một literal khớp nhiều fact thì giữ thứ tự điểm giảm dần — người đọc xem cái đầu
    # trước, và cái đầu phải là cái đáng tin nhất.
    ra.sort(key=lambda s: (s["line"], -s["confidence"], s["fact_id"]))
    return {"suggestions": ra}


def _muc_khop(subject: str, predicate: str, ten_trong_dong: set[str], dong: str) -> str:
    """Mức khớp giữa một fact và một dòng mã đã khớp GIÁ TRỊ.

    "Tên" ở đây là phần cuối của subject IRI (`chip:st.stm32f411/periph:I2C1` → `i2c1`) so với
    các định danh CHỮ HOA trên dòng. Dùng phần cuối chứ không cả IRI: cả IRI thì không tên nào
    trong mã khớp nổi, còn phần cuối lại đúng là thứ lập trình viên đặt tên theo.
    """
    duoi = str(subject).rsplit(":", 1)[-1].rsplit("/", 1)[-1].lower()
    duoi_goc = re.sub(r"[^a-z0-9]", "", duoi)
    for t in ten_trong_dong:
        goc = re.sub(r"[^a-z0-9]", "", t)
        if duoi_goc and (duoi_goc in goc or goc in duoi_goc):
            return "gia_tri+ten"
    if str(predicate).lower() in dong.lower():
        return "gia_tri+ngu_canh"
    return "gia_tri"


def _fact_da_duyet(root: Path) -> list[tuple[str, str, str, Any]]:
    """Fact `reviewed`/`verified` — đúng tập mà `constant_guard` cho đi qua.

    Gợi ý một fact `normalized` là gợi ý người ta nối mã vào một con số chưa ai duyệt, và lần
    sau chính `constant_guard` sẽ chặn đúng dòng ta vừa bảo họ viết.
    """
    with store.open_store(store.store_path(root)) as c:
        rows = c.execute(
            "SELECT id, subject, predicate, value FROM fact"
            " WHERE status IN ('reviewed','verified') ORDER BY id").fetchall()
    return [(r[0], r[1], r[2], json.loads(r[3]) if r[3] else None) for r in rows]


# ---------------------------------------------------------------- CODE-15 docs

_SCHEMA_README = {
    "type": "object",
    "properties": {"markdown": {"type": "string"}},
    "required": ["markdown"], "additionalProperties": False,
}


@capability("code.docs")
def docs(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-15 — CDS-12.1; DOC-03 (`doc.style_check`). R2, `errors: [E5002]`,
    `undo: none`. tc: "style_check 0 lỗi".

    **API dựng bằng MÃ, văn xuôi do mô hình viết quanh nó** — cùng khuôn `doc.generate` và
    `report.explain`. Danh sách hàm, tham số và fact trích dẫn lấy từ header và từ `code_unit`;
    mô hình chỉ nối chúng thành câu. Để mô hình tự đọc mã rồi nhớ lại chữ ký hàm là mời nó bịa
    ra một hàm trông rất giống thật.

    **`tc` là "style_check 0 lỗi", nên phép kiểm ấy chạy ở đây** — không giao một README mà
    chính bộ soát của dự án còn chê. Còn lỗi sau một lần sửa → E5002.

    Trích dẫn fact là phần bắt buộc, không phải trang trí: một README module driver nói "địa chỉ
    0x76" mà không nêu fact nào thì nó vừa tạo ra một nguồn sự thật thứ hai, cạnh tranh với
    store — đúng thứ `code.constant_guard` tồn tại để chặn.
    """
    root = _du_an(ctx, params)
    ten_mod = params["module"]
    mo_ta = _mo_ta_module(root, ten_mod)
    if not mo_ta["files"]:
        raise EideError("E2000", f"Không thấy tệp nào của module `{ten_mod}`",
                        exists=[], candidates=["code.generate_module"], missing=[ten_mod])

    from eide.caps.doc import _gateway
    gw = _gateway(ctx)
    resp = gw.run("writer",
                  "Viết README cho module firmware dưới đây, tiếng Việt, Markdown. Dùng ĐÚNG "
                  "danh sách API trong dữ kiện — không thêm hàm nào, không đổi chữ ký. Mọi hằng "
                  "số phần cứng nêu trong bài phải kèm trích dẫn fact dạng [f_…] có trong dữ "
                  "kiện.\n\n" + json.dumps(mo_ta, ensure_ascii=False),
                  _SCHEMA_README)
    van = (resp.data.get("markdown") or "").strip()

    # Trích dẫn phải CÓ MẶT — mô hình bỏ sót là chuyện thường, và một README không tra ngược
    # được thì nó là nguồn sự thật thứ hai.
    thieu = [f for f in mo_ta["facts"] if f["id"] not in van]
    if thieu:
        van += "\n\n## Nguồn\n\n" + "\n".join(
            f"- `{f['id']}` — {f['subject']} · {f['predicate']}" for f in thieu) + "\n"

    out = root / "src" / ten_mod / "README.md"
    if not out.parent.is_dir():
        out = root / "docs" / f"{ten_mod}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(van + ("\n" if not van.endswith("\n") else ""), encoding="utf-8")

    from eide.caps.doc import style_check
    loi = style_check({"path": str(out)}, ctx).get("issues") or []
    if loi:
        raise EideError("E5002", f"README của `{ten_mod}` còn {len(loi)} lỗi văn phong — "
                        "xem `doc.style_check`", issues=loi[:10], path=str(out))
    return {"path": str(out.relative_to(root) if out.is_relative_to(root) else out)}


RE_HAM_C = re.compile(
    r"^\s*(?!#)(?:static\s+|inline\s+|extern\s+)*"
    r"([A-Za-z_][\w \t*]*?)\s+([A-Za-z_]\w*)\s*\(([^;{)]*)\)\s*[;{]", re.M)


def _mo_ta_module(root: Path, ten: str) -> dict[str, Any]:
    """API + fact của một module, dựng từ header và `code_unit` — không nhờ mô hình đọc mã."""
    thu_muc = [root / "src" / ten, root / "src", root]
    tep: list[Path] = []
    for d in thu_muc:
        if d.is_dir():
            tep = [f for f in sorted(d.rglob("*.h")) + sorted(d.rglob("*.c"))
                   if ten.lower() in str(f).lower()]
            if tep:
                break
    api = []
    for f in tep:
        van = f.read_text(encoding="utf-8", errors="replace")
        for kieu, ham, tham in RE_HAM_C.findall(van):
            api.append({"file": f.name, "returns": kieu.strip(), "name": ham,
                        "params": " ".join(tham.split())})

    facts: list[dict[str, Any]] = []
    db = store.store_path(root)
    if db.exists():
        ids: set[str] = set()
        for f in tep:
            ids.update(RE_CHU_THICH.findall(f.read_text(encoding="utf-8", errors="replace")))
        if ids:
            with store.open_store(db) as c:
                q = ",".join("?" * len(ids))
                facts = [{"id": r[0], "subject": r[1], "predicate": r[2],
                          "value": json.loads(r[3]) if r[3] else None}
                         for r in c.execute(
                             f"SELECT id, subject, predicate, value FROM fact WHERE id IN ({q})",
                             sorted(ids)).fetchall()]
    return {"module": ten, "files": [str(f.relative_to(root)) for f in tep],
            "api": api[:60], "facts": facts}


# ---------------------------------------------------------------- CODE-16 refactor

_SCHEMA_REFACTOR = {
    "type": "object",
    "properties": {
        "files": {"type": "array", "items": {
            "type": "object",
            "properties": {"path": {"type": "string"}, "content": {"type": "string"}},
            "required": ["path", "content"], "additionalProperties": False}},
        "rationale": {"type": "string"},
    },
    "required": ["files"], "additionalProperties": False,
}


@capability("code.refactor")
def refactor(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: CODE-16 — CDS-12.1; G3 (`code.review`); CODE-08 `test_host`. R2,
    `errors: [E5003]`, `undo: none`. tc: "Test trước/sau pass như nhau".

    **Bất biến là KHÔNG ĐỔI HÀNH VI, và nó được KIỂM chứ không được hứa.** Hợp đồng viết "bắt
    buộc test host trước/sau giống nhau" — nên năng lực này chạy `code.test_host` hai lần và so
    kết quả từng bài. Một bản tái cấu trúc làm đổi một bài test là một bản tái cấu trúc đã đổi
    hành vi, dù văn xuôi giải thích có hay tới đâu.

    **So theo TỪNG BÀI, không so theo tổng số bài đạt.** Hai bài cùng đổi trạng thái ngược chiều
    nhau giữ nguyên tổng — và đó đúng là hình dạng của một lỗi tái cấu trúc: sửa một chỗ, làm
    hỏng chỗ khác, con số tổng không nhúc nhích.

    Không có bài test nào chạy được TRƯỚC khi sửa → E5003 và không sửa gì. Tái cấu trúc mà không
    có lưới an toàn thì thứ duy nhất ta biết sau đó là mã đã khác đi.

    Trả `patch` chứ không ghi đè: `undo: none` vì nó không đổi gì trên đĩa — người gọi đưa
    `patch` qua `code.modify` (đi qua G3) như mọi thay đổi mã khác.
    """
    root = _du_an(ctx, params)
    pham_vi = [str(x) for x in (params["scope"] or [])]
    if not pham_vi:
        raise EideError("E1000", "`scope` rỗng — nêu tệp hoặc thư mục cần tái cấu trúc")

    truoc = _ket_qua_test(ctx)
    if not truoc:
        raise EideError("E5003", "Không có bài test máy chủ nào chạy được TRƯỚC khi sửa — tái "
                        "cấu trúc mà không có lưới an toàn thì thứ duy nhất ta biết sau đó là "
                        "mã đã khác đi. Viết test bằng `code.generate_tests` trước.",
                        reason="no_baseline")

    tep = _tep_trong_pham_vi(root, pham_vi)
    goc = {str(f.relative_to(root)): f.read_text(encoding="utf-8", errors="replace")
           for f in tep}
    from eide.caps.doc import _gateway
    resp = _gateway(ctx).run(
        "coder",
        "Tái cấu trúc mã dưới đây theo quy ước đã nêu. TUYỆT ĐỐI KHÔNG đổi hành vi quan sát "
        "được: không đổi chữ ký hàm công khai, không đổi giá trị hằng số, không đổi thứ tự tác "
        "động lên thanh ghi. Giữ nguyên mọi chú thích `eide:fact`.\n\n"
        + json.dumps({"rules": params.get("rules") or [], "files": goc}, ensure_ascii=False),
        _SCHEMA_REFACTOR)

    sua = {f["path"]: f["content"] for f in (resp.data.get("files") or [])}
    la = sorted(set(sua) - set(goc))
    if la:
        raise EideError("E5003", f"Bản tái cấu trúc chạm tệp ngoài `scope`: {la}",
                        reason="out_of_scope", files=la)

    # Chạy test trên bản SỬA bằng cách ghi tạm, chạy, rồi trả lại — không để lại dấu vết trên
    # cây mã của người dùng dù kết quả thế nào.
    try:
        for p, noi_dung in sua.items():
            (root / p).write_text(noi_dung, encoding="utf-8")
        sau = _ket_qua_test(ctx)
    finally:
        for p, noi_dung in goc.items():
            (root / p).write_text(noi_dung, encoding="utf-8")

    doi = sorted(k for k in set(truoc) | set(sau) if truoc.get(k) != sau.get(k))
    if doi:
        raise EideError("E5003", f"Tái cấu trúc làm đổi kết quả {len(doi)} bài test: "
                        f"{doi[:5]} — đây là đổi HÀNH VI, không phải tái cấu trúc.",
                        reason="behaviour_changed", changed=doi,
                        before={k: truoc.get(k) for k in doi[:5]},
                        after={k: sau.get(k) for k in doi[:5]})

    return {"patch": {"files": [{"path": p, "content": c} for p, c in sorted(sua.items())],
                      "rationale": resp.data.get("rationale") or "",
                      "tests_unchanged": sorted(truoc)}}


def _ket_qua_test(ctx: Context) -> dict[str, str]:
    """`{tên bài: trạng thái}` từ `code.test_host`. Rỗng khi không chạy được bài nào."""
    try:
        rep = test_host({}, ctx)["report"]
    except EideError:
        return {}
    return {c["name"]: c["status"] for c in (rep.get("metrics", {}).get("cases") or [])}


def _tep_trong_pham_vi(root: Path, pham_vi: list[str]) -> list[Path]:
    ra: list[Path] = []
    for x in pham_vi:
        p = root / x
        if p.is_dir():
            ra += sorted(p.rglob("*.c")) + sorted(p.rglob("*.h"))
        elif p.is_file():
            ra.append(p)
    return ra
