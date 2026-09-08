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
                      "limits": {"timeout_s": 300}}, ctx)
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
                     "limits": {"timeout_s": TIMEOUT_TEST}}, ctx)
    if d["exit_code"] != 0 or not ra.exists():
        return {"name": f.stem, "file": str(f.relative_to(root)), "status": "compile_error",
                "exit_code": d["exit_code"], "log_ref": d["stderr_ref"]}

    c = env_sandbox({"cmd": [str(ra)], "network": False,
                     "limits": {"timeout_s": TIMEOUT_TEST}}, ctx)
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
    from eide.caps.memory import compose
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

    bundle = compose({"role": "coder", "task_ref": step_ref}, ctx)["bundle"]
    ngu_canh = "\n\n".join(b["text"] for b in bundle["blocks"] if b["layer"] != "C1")
    resp = gw.run("coder", _de_bai(step_ref, buoc, pham_vi), _schema_codepatch(),
                  system_extra=ngu_canh)
    patch = dict(resp.data)

    if (thieu := patch.get("missing_facts")):
        raise EideError("E5003", "Coder dừng vì thiếu fact cho hằng số phần cứng: "
                        + ", ".join(str(x) for x in thieu)
                        + ". Dùng `kg.request`/`search.*` để bổ sung rồi gọi lại.",
                        missing_facts=list(thieu), step_ref=step_ref, violations=[])

    if (ngoai := _ngoai_pham_vi(patch, pham_vi)):
        raise EideError("E8000", f"Patch chạm tệp ngoài phạm vi cho phép: {ngoai}",
                        files=ngoai, allowed=pham_vi, violations=["path"])

    kq = constant_guard({"patch": patch}, ctx)
    if kq["verdict"] == "block":
        raise EideError("E5003", f"{len(kq['violations'])} hằng số phần cứng không có nguồn hợp "
                        "lệ (TC-04) — patch không được lưu.",
                        violations=kq["violations"], step_ref=step_ref)

    pid = _luu_patch(root, step_ref, patch, ctx)
    patch["id"] = pid
    return {"patch": patch, "cites": list(patch.get("cites") or [])}


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
