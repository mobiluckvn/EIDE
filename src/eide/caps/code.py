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
from pathlib import Path
from typing import Any

from eide.caps.project import EIDE_DIR
from eide_core import store
from eide_core.errors import EideError
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
