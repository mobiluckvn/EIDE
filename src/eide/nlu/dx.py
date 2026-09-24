"""DX — bộ trích xác định (Deterministic eXtractor). Spec: AAD-33 §2.2; AGD-32 Đ1; §10 DXResult.

DX chạy **TRƯỚC mọi lời gọi mô hình** và kết quả của nó là bất biến: mô hình ở S1b không được
ghi đè slot do DX điền (`eide.nlu.merge`). Nó là câu trả lời trực tiếp cho cụm lỗi lớn nhất đo
được ngày 23/09/2026 — 11 ca chết vì `archive.list` nhận một đường dẫn **bịa từ chính câu người
dùng** — và cho tính không tất định của `${_path}`.

## Bảy trường, và mỗi trường vì một ca đo

| Trường     | Vì sao                                                                      |
|------------|-----------------------------------------------------------------------------|
| paths[]    | TC011 mất tệp thứ hai vì `slots.path` là chuỗi đơn; TC016/023 chạy trên đường dẫn không tồn tại |
| chips[]    | TC002/008/015 chặn ở "chip nào?" dù chip đã nêu trong câu                    |
| numbers[]  | TC021 (ngân sách Flash), TC056/057 (tính toán thiếu tham số)                 |
| urls[]     | TC010/072 (tìm tài liệu trên mạng, ưu tiên tên miền nhà sản xuất)            |
| ids[]      | TC065/066 ("làm lại run-0042", khôi phục ngữ cảnh)                           |
| back_refs  | TC065 ("làm lại" / "tiếp tục" — giải bằng tra bảng run, không đoán)          |
| quoted[]   | TC017 ("thay 'void main' bằng…" — chuỗi là DỮ LIỆU, không phải lệnh)         |

## Hai luật của cả tệp

1. **Không gọi mô hình, không cần mạng.** Mọi hàm ở đây kiểm được bằng unit test không khoá API.
2. **Không tồn tại KHÔNG phải là không nói.** Một đường dẫn sai vẫn được giữ lại với
   `exists=false` để S3 hỏi lại — xoá nó đi thì người dùng nhận một câu hỏi trống ("đọc tệp
   nào?") thay vì một câu hỏi có nội dung ("`/docs/ds.pdf` không có ở đó, anh muốn tệp nào?").
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

from eide.nlu.normalize import Utterance, bo_dau, normalize
from eide_core.isa import isa_cua_chip
from eide_core.paths import spec_dir

# ──────────────────────────────────────────────────────────────────── đường dẫn

#: Đường dẫn TUYỆT ĐỐI hoặc `~/…` — giữ nguyên biểu thức của [DEV-208] để hành vi đang đo được
#: không đổi. Phần thêm của v1.4 là ba nguồn nữa: chuỗi trong nháy, tên tệp có đuôi đã biết, và
#: đường dẫn tương đối có dấu `/`.
_TUYET_DOI = re.compile(r"(?:^|\s)((?:~|/)[^\s,;\"'`]+[^\s,;.\"'`])")

#: Đuôi tệp mà EIDE có bộ đọc — nguồn: `ingest.classify` (`archive.py::_NEN_DUNG`) và
#: `docs/spec/data/json/source.json` (enum `kind`). Chỉ những đuôi này được nhận từ một tên tệp
#: TRẦN (không có dấu `/`), vì `main.c` là một tệp còn `v1.2` thì không.
DUOI_BIET = frozenset("""pdf zip rar 7z tar gz xz tgz svd atdf edc h hpp c cpp s md txt csv
    json yaml yml net kicad_net kicad_sch kicad_pcb PcbDoc SchDoc dts dtsi png jpg jpeg svg
    log sal vcd elf hex bin map ld sh py xlsx docx""".split())

_TEN_TEP = re.compile(r"(?:^|[\s\"'`(])([\w.\-]+\.(" + "|".join(sorted(DUOI_BIET)) + r"))\b",
                      re.IGNORECASE)
_TUONG_DOI = re.compile(r"(?:^|\s)((?:\./|\.\./)?[\w.\-]+(?:/[\w.\-]+)+)")

# ──────────────────────────────────────────────────────────────────── nháy, URL, mã

#: Nháy kép/đơn/backtick, cả nháy cong tiếng Việt. Nội dung là DỮ LIỆU (kênh DATA của Đ4).
_NHAY = re.compile(r"[\"“]([^\"”]{1,200})[\"”]|'([^']{1,200})'|`([^`]{1,200})`")

_URL = re.compile(r"\bhttps?://[^\s\"'<>)\]]+|(?<![\w.])(?:www\.)[^\s\"'<>)\]]+", re.IGNORECASE)

#: Mã hiện vật. `run-0042` là dạng của AAD-33 §2.2; `r_<hex>` là dạng `chat.orchestrate` sinh
#: thật (`run_id = "r_" + token_hex(6)`) — nhận cả hai, vì người dùng dán lại thứ họ NHÌN THẤY.
_MA = re.compile(r"\b(REQ-[\w.]+|ADR-[\w.]+|MOD-[\w.]+|UC-?\d+[A-Za-z]?\d*|TC-?\d+"
                 r"|run-\d+|r_[0-9a-f]{8,16})\b")
_LOAI_MA = (("REQ-", "req"), ("ADR-", "adr"), ("MOD-", "module"), ("UC", "usecase"),
            ("TC", "testcase"), ("run-", "run"), ("r_", "run"))

# ──────────────────────────────────────────────────────────────────── số + đơn vị

#: Đơn vị → (hệ số về đơn vị SI cơ sở, tên đơn vị cơ sở). Nguồn: AAD-33 §2.2 hàng `numbers[]`
#: (V, mA, kΩ, MHz, KB, ms, °C, %) mở rộng sang các đơn vị mà UC13 (tính toán) và AGD-32 §4.3
#: (bảng so sánh) dùng: dung lượng pin, công suất, điện dung, tốc độ truyền.
DON_VI: dict[str, tuple[float, str]] = {
    # điện áp / dòng / trở
    "v": (1, "V"), "mv": (1e-3, "V"), "kv": (1e3, "V"), "uv": (1e-6, "V"), "µv": (1e-6, "V"),
    "a": (1, "A"), "ma": (1e-3, "A"), "ua": (1e-6, "A"), "µa": (1e-6, "A"), "na": (1e-9, "A"),
    "ohm": (1, "Ω"), "ω": (1, "Ω"), "kohm": (1e3, "Ω"), "kω": (1e3, "Ω"),
    "mohm": (1e6, "Ω"), "mω": (1e6, "Ω"),
    # tần số
    "hz": (1, "Hz"), "khz": (1e3, "Hz"), "mhz": (1e6, "Hz"), "ghz": (1e9, "Hz"),
    # thời gian
    "s": (1, "s"), "ms": (1e-3, "s"), "us": (1e-6, "s"), "µs": (1e-6, "s"), "ns": (1e-9, "s"),
    "phut": (60, "s"), "gio": (3600, "s"), "min": (60, "s"), "h": (3600, "s"),
    # bộ nhớ — KB thập phân theo cách datasheet dùng, KiB nhị phân
    "b": (1, "B"), "kb": (1e3, "B"), "mb": (1e6, "B"), "gb": (1e9, "B"),
    "kib": (1024, "B"), "mib": (1024**2, "B"), "gib": (1024**3, "B"),
    # công suất / điện dung / dung lượng pin
    "w": (1, "W"), "mw": (1e-3, "W"), "kw": (1e3, "W"), "uw": (1e-6, "W"),
    "f": (1, "F"), "uf": (1e-6, "F"), "µf": (1e-6, "F"), "nf": (1e-9, "F"), "pf": (1e-12, "F"),
    "ah": (3600, "C"), "mah": (3.6, "C"),
    # tốc độ truyền, nhiệt độ, phần trăm
    "bps": (1, "bps"), "kbps": (1e3, "bps"), "mbps": (1e6, "bps"), "baud": (1, "bps"),
    "°c": (1, "°C"), "oc": (1, "°C"), "%": (1, "%"),
}

#: Đơn vị viết ra sau con số. Dài trước ngắn để `mah` không bị `m` + `ah` cắt đôi.
_DV = "|".join(sorted((re.escape(k) for k in DON_VI), key=len, reverse=True))
_SO = r"\d+(?:[.,]\d+)*"
_DAI = re.compile(rf"({_SO})\s*[–—~-]\s*({_SO})\s*({_DV})\b", re.IGNORECASE)
_DON = re.compile(rf"({_SO})\s*({_DV})\b", re.IGNORECASE)


@dataclass(slots=True)
class DXResult:
    """Kết quả DX. Lược đồ: `docs/spec/dialog/dx.schema.json`."""

    paths: list[dict[str, Any]] = field(default_factory=list)
    chips: list[dict[str, Any]] = field(default_factory=list)
    numbers: list[dict[str, Any]] = field(default_factory=list)
    urls: list[dict[str, Any]] = field(default_factory=list)
    ids: list[dict[str, Any]] = field(default_factory=list)
    back_refs: list[str] = field(default_factory=list)
    quoted: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {"paths": self.paths, "chips": self.chips, "numbers": self.numbers,
                "urls": self.urls, "ids": self.ids, "back_refs": self.back_refs,
                "quoted": self.quoted}

    # `paths` dùng ở hai nghĩa khác nhau nên tách hai phép đọc, không để bên gọi tự lọc:
    # một đường dẫn KHÔNG tồn tại vẫn phải đi vào câu hỏi của S3, nhưng KHÔNG được đi vào tham
    # số của một nút đang chạy.
    def duong_chay_duoc(self) -> list[str]:
        """Đường dẫn dùng được để CHẠY một nút — chỉ những tệp có thật."""
        return [p["value"] for p in self.paths if p.get("exists")]

    def duong_de_hoi(self) -> list[str]:
        """Đường dẫn để dựng câu hỏi S3 — kể cả những tệp không tìm thấy."""
        return [p["value"] for p in self.paths]

    def ma_chip(self) -> list[str]:
        return [c["code"] for c in self.chips]


def extract(text: str | Utterance, *, root: Path | str | None = None,
            cwd: Path | str | None = None,
            attachments: list[str] | None = None) -> DXResult:
    """Trích mọi thứ xác định được từ một câu. 0 token.

    `root` là thư mục dự án (để kiểm tệp có thật và để nhận đường dẫn tương đối); `None` thì mọi
    `exists` là `False` và hàm vẫn chạy — DX không bao giờ hỏng vì chưa mở dự án.

    `attachments` là tệp người dùng KÉO THẢ hoặc chọn. Chúng vào `paths[]` với `source="dinh_kem"`
    và vẫn mang `origin="dx"`, vì một tệp người ta vừa đưa vào là dữ kiện chắc chắn nhất trong cả
    lượt — chắc hơn một biểu thức chính quy, và chắc hơn hẳn một phỏng đoán của mô hình. Trước
    [DEV-232] chỗ này là `chat.parse_intent` gán `slots["path"] = attachments[0]`: một chuỗi đơn,
    nên kéo hai datasheet vào thì tệp thứ hai mất ngay ở dòng ấy.
    """
    utt = text if isinstance(text, Utterance) else normalize(str(text or ""))
    goc = Path(root).expanduser() if root else None
    lam_viec = Path(cwd).expanduser() if cwd else goc
    nhay = _trich_nhay(utt.normalized)
    duong = _trich_duong_dan(utt.normalized, nhay, goc, lam_viec)
    duong = _them_dinh_kem(duong, attachments or [], goc, lam_viec)
    urls = _trich_url(utt.normalized)

    # CHE đường dẫn và URL trước khi tìm chip / số / mã hiện vật.
    #
    # `https://st.com/…/stm32f103c8.pdf` chứa chuỗi khớp `family_patterns`, và nhận nó thành một
    # mục `chips[]` là bịa ra một con chip từ một cái tên tệp — rồi `passport.propose` (Đ3) sẽ
    # hỏi người dùng về con chip ấy. Cùng lý lẽ cho `/opt/stm32f411/build.log` và cho số trong
    # `v1.2/ds_4.2V.pdf`: những ký tự ấy đã có một nghĩa khác, và một chuỗi chỉ được mang MỘT
    # nghĩa trong một lượt đọc.
    con_lai = _che(utt.normalized, [p["value"] for p in duong] + [u["value"] for u in urls])
    return DXResult(
        paths=duong,
        chips=_trich_chip(con_lai, bo_dau(con_lai)),
        numbers=_trich_so(con_lai),
        urls=urls,
        ids=_trich_ma(con_lai),
        back_refs=_trich_back_ref(utt.normalized),
        quoted=nhay,
    )


def _che(van: str, chuoi: list[str]) -> str:
    """Thay mọi lần xuất hiện của `chuoi` bằng khoảng trắng, giữ nguyên độ dài chuỗi."""
    for s in sorted({x for x in chuoi if x}, key=len, reverse=True):
        van = van.replace(s, " " * len(s))
    return van


# ──────────────────────────────────────────────────────────────────── đường dẫn

def _trich_duong_dan(van: str, nhay: list[str], goc: Path | None,
                     cwd: Path | None) -> list[dict[str, Any]]:
    """Bốn nguồn, theo thứ tự tin cậy giảm dần; bỏ trùng theo chuỗi đã thấy.

    Thứ tự có nghĩa: một đường dẫn tuyệt đối là điều người dùng nói rõ ràng nhất, còn một tên
    tệp trần (`dem_xung.c`) là suy đoán từ cái đuôi — nên `nguon` được ghi lại để S3 hỏi đúng
    mức ("`dem_xung.c` ở thư mục nào?" chỉ hợp lý cho nguồn `ten_tep`).
    """
    ra: list[dict[str, Any]] = []
    da: set[str] = set()

    def them(gia_tri: str, nguon: str) -> None:
        gia_tri = gia_tri.strip().strip(",;")
        if not gia_tri or gia_tri in da:
            return
        da.add(gia_tri)
        that, trong = _tim_tep(gia_tri, goc, cwd)
        ra.append({"value": gia_tri, "origin": "dx", "source": nguon,
                   "exists": that is not None, "resolved": str(that) if that else None,
                   "in_project": trong})

    for m in _TUYET_DOI.finditer(" " + van):
        them(m.group(1), "tuyet_doi")
    for s in nhay:                                    # chuỗi trong nháy CÓ THỂ là đường dẫn
        if "/" in s or (("." in s) and s.rsplit(".", 1)[-1].lower() in DUOI_BIET):
            them(s, "nhay")
    for m in _TUONG_DOI.finditer(" " + van):
        them(m.group(1), "tuong_doi")
    for m in _TEN_TEP.finditer(" " + van):
        them(m.group(1), "ten_tep")
    return ra


def _them_dinh_kem(duong: list[dict[str, Any]], dinh_kem: list[str], goc: Path | None,
                   cwd: Path | None) -> list[dict[str, Any]]:
    """Tệp đính kèm đứng TRƯỚC các đường dẫn rút từ câu chữ, theo thứ tự người đưa vào.

    Đứng trước vì khi một nút chỉ nhận MỘT tệp (`${_path}` số ít), tệp người vừa kéo vào là ứng
    viên đúng hơn một tên tệp nhắc qua trong câu.
    """
    if not dinh_kem:
        return duong
    da = {p["value"] for p in duong}
    them: list[dict[str, Any]] = []
    for d in dinh_kem:
        d = str(d).strip()
        if not d or d in da:
            continue
        da.add(d)
        that, trong = _tim_tep(d, goc, cwd)
        them.append({"value": d, "origin": "dx", "source": "dinh_kem",
                     "exists": that is not None, "resolved": str(that) if that else None,
                     "in_project": trong})
    return them + duong


def _tim_tep(gia_tri: str, goc: Path | None, cwd: Path | None) -> tuple[Path | None, bool]:
    """`(đường dẫn thật | None, có nằm trong dự án không)`.

    Tìm theo ba chỗ: đúng như người gõ, tương đối thư mục làm việc, tương đối thư mục dự án.
    KHÔNG quét đệ quy cả dự án để tìm một tên tệp trần: một kho 1200 tệp (TC028) có thể có bốn
    tệp cùng tên, và chọn hộ một trong bốn là đúng loại phỏng đoán mà DX tồn tại để bỏ.
    """
    ung_vien: list[Path] = []
    p = Path(gia_tri).expanduser()
    if p.is_absolute() or gia_tri.startswith("~"):
        ung_vien.append(p)
    else:
        for d in (cwd, goc):
            if d is not None:
                ung_vien.append(d / gia_tri)
    for u in ung_vien:
        try:
            if u.exists():
                trong = goc is not None and _nam_trong(u, goc)
                return u, trong
        except OSError:                               # tên quá dài, ký tự lạ của hệ tệp
            continue
    return None, False


def _nam_trong(p: Path, goc: Path) -> bool:
    try:
        p.resolve().relative_to(goc.resolve())
    except (ValueError, OSError):
        return False
    return True


# ──────────────────────────────────────────────────────────────────── chip

@lru_cache(maxsize=1)
def _bang_chip() -> tuple[tuple[re.Pattern[str], str], tuple[tuple[str, str], ...]]:
    """`(regex họ chip, bảng bí danh)` đọc từ `docs/spec/dialog/dx_chips.yaml`."""
    f = spec_dir() / "dialog" / "dx_chips.yaml"
    d = yaml.safe_load(f.read_text(encoding="utf-8")) if f.exists() else {}
    mau = [str(x["pattern"]) for x in (d or {}).get("family_patterns") or []]
    ho = re.compile(r"\b(" + "|".join(mau) + r")\b", re.IGNORECASE) if mau else re.compile(r"(?!x)x")
    bi_danh: list[tuple[str, str]] = []
    for a in (d or {}).get("aliases") or []:
        for ten in [a["ten"], *(a.get("bien_the") or [])]:
            bi_danh.append((bo_dau(str(ten)), str(a["chip"])))
    bi_danh.sort(key=lambda x: len(x[0]), reverse=True)   # bí danh dài khớp trước
    return ho, tuple(bi_danh)


def _trich_chip(van: str, khong_dau: str) -> list[dict[str, Any]]:
    """Mã chip trong câu, đã chuẩn hoá, kèm ISA nếu kho có manifest.

    `in_registry=False` là trạng thái BÌNH THƯỜNG ở v1.4: kho chưa có registry chip (DEV-220,
    Đợt 2). Trường vẫn có mặt để `passport.propose` của Đ3 không phải đổi lược đồ khi registry
    xuất hiện.

    `isa=None` KHÔNG phải lỗi của DX mà là một sự thật cần nói ra: STM32F103 là armv7-m và kho
    chỉ có armv7e-m/avr8/rv32imac, nên `env.check` phải nói thẳng thay vì đưa ba lựa chọn đều
    sai (TC018).
    """
    ho, bi_danh = _bang_chip()
    ra: list[dict[str, Any]] = []
    da: set[str] = set()

    def them(code: str, raw: str, tu_bi_danh: str | None) -> None:
        if code.upper() in da:
            return
        da.add(code.upper())
        ra.append({"code": code, "raw": raw, "alias_of": tu_bi_danh, "origin": "dx",
                   "isa": isa_cua_chip(code), "in_registry": False})

    for m in ho.finditer(van):
        them(m.group(1), m.group(1), None)
    for ten, code in bi_danh:
        if re.search(rf"(?:^|\W){re.escape(ten)}(?:\W|$)", khong_dau):
            them(code, ten, ten)
    return ra


# ──────────────────────────────────────────────────────────────────── số

def _so(s: str) -> float:
    """`"3,0"` → 3.0; `"2.000"` → 2000; `"1.5"` → 1.5.

    Tiếng Việt dùng phẩy làm dấu thập phân và chấm làm dấu nghìn; tiếng Anh thì ngược lại. Luật
    ở đây: **phẩy luôn là dấu thập phân**; **chấm là dấu nghìn CHỈ KHI** theo sau đúng ba chữ số
    và còn chữ số ở trước. Cả hai chiều đều có ca sai — `"2.500"` có thể là hai nghìn rưỡi hoặc
    hai phẩy năm — nên chỗ này giữ `raw` lại: bên nào cần chắc thì hỏi người, và câu hỏi ấy có
    nội dung vì nó in ra chuỗi gốc.
    """
    s = s.strip()
    if re.fullmatch(r"\d{1,3}(?:\.\d{3})+", s):
        return float(s.replace(".", ""))
    return float(s.replace(",", "."))


def _trich_so(van: str) -> list[dict[str, Any]]:
    """Số kèm đơn vị, quy về SI cơ sở; dải `3,0–4,2 V` thành MỘT mục có `min`/`max`."""
    ra: list[dict[str, Any]] = []
    da_dung: list[tuple[int, int]] = []

    for m in _DAI.finditer(van):
        he, co_ban = DON_VI[m.group(3).lower()]
        lo, hi = _so(m.group(1)), _so(m.group(2))
        ra.append({"raw": m.group(0).strip(), "unit": m.group(3), "min": lo, "max": hi,
                   "value": None, "si_min": lo * he, "si_max": hi * he, "si": None,
                   "si_unit": co_ban, "origin": "dx"})
        da_dung.append((m.start(), m.end()))

    for m in _DON.finditer(van):
        if any(a <= m.start() < b for a, b in da_dung):
            continue                                  # đã nằm trong một dải
        he, co_ban = DON_VI[m.group(2).lower()]
        v = _so(m.group(1))
        ra.append({"raw": m.group(0).strip(), "unit": m.group(2), "value": v, "min": None,
                   "max": None, "si": v * he, "si_min": None, "si_max": None,
                   "si_unit": co_ban, "origin": "dx"})
    return ra


# ──────────────────────────────────────────────────────────────────── URL, mã, trỏ ngược

@lru_cache(maxsize=1)
def _nha_san_xuat() -> tuple[str, ...]:
    """`trusted_sources` của POL-17 §2 — không chép tay danh sách tên miền lần thứ hai."""
    f = spec_dir() / "policy" / "defaults.yaml"
    d = yaml.safe_load(f.read_text(encoding="utf-8")) if f.exists() else {}
    return tuple(str(x).lower() for x in (d or {}).get("trusted_sources") or [])


def _trich_url(van: str) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    for m in _URL.finditer(van):
        u = m.group(0).rstrip(".,;:)")
        mien = re.sub(r"^www\.", "", u.split("//")[-1].split("/")[0].lower())
        duoi = u.rsplit(".", 1)[-1].lower() if "." in u.rsplit("/", 1)[-1] else ""
        ra.append({"value": u, "domain": mien, "origin": "dx",
                   "manufacturer": any(mien == t or mien.endswith("." + t) or t.startswith(mien + "/")
                                       for t in _nha_san_xuat()),
                   "kind": "pdf" if duoi == "pdf" else "web"})
    return ra


def _trich_ma(van: str) -> list[dict[str, Any]]:
    """Mã hiện vật. `dangling` để `None`: nói "không có mã này trong store" là việc của S2.

    DX không mở store — nó phải chạy được trước khi dự án mở, và một hàm trích chuỗi mà đi đọc
    SQLite là một hàm không kiểm được bằng unit test. `eide.nlu.dx.giai_ma` làm phần tra bảng,
    và nó nhận `root` làm tham số.
    """
    ra: list[dict[str, Any]] = []
    for m in _MA.finditer(van):
        v = m.group(1)
        loai = next((k for tien, k in _LOAI_MA if v.upper().startswith(tien.upper())), "other")
        if not any(x["value"] == v for x in ra):
            ra.append({"value": v, "kind": loai, "origin": "dx", "dangling": None})
    return ra


def giai_ma(ids: list[dict[str, Any]], root: Path | str | None) -> list[dict[str, Any]]:
    """Điền `dangling` cho các mã `run` bằng một truy vấn store. Không có store → giữ `None`.

    Chỉ tra `run`: đó là loại mã duy nhất mà một câu trỏ ngược cần ("làm lại run-0042"), và mỗi
    bảng thêm vào đây là một truy vấn nữa trên đường sống của mọi lượt gõ.
    """
    if not ids or root is None:
        return ids
    from eide_core import store
    duong = store.store_path(Path(root).expanduser())
    if not Path(duong).exists():
        return ids
    can = [x["value"] for x in ids if x["kind"] == "run"]
    if not can:
        return ids
    try:
        with store.open_store(duong) as c:
            co = {r[0] for r in c.execute(
                f"SELECT id FROM run WHERE id IN ({','.join('?' * len(can))})", can)}
    except Exception:                                  # noqa: BLE001 — store cũ chưa có bảng
        return ids
    for x in ids:
        if x["kind"] == "run":
            x["dangling"] = x["value"] not in co
    return ids


def _trich_back_ref(van: str) -> list[str]:
    """`["lam_lai"]` / `["tiep_tuc"]` / `[]` — dùng chung bộ nhận của [DEV-196]."""
    from eide.nlu.backref import la_cau_tro_nguoc
    tro = la_cau_tro_nguoc(van)
    return [tro] if tro else []


def _trich_nhay(van: str) -> list[str]:
    """Chuỗi trong nháy kép/đơn/backtick — giữ NGUYÊN CHỮ, kể cả khoảng trắng bên trong.

    Đây là kênh DATA của AAD-33 §2.4: *"thay 'void main' bằng…"* (TC017). Nội dung trong nháy
    không bao giờ được diễn giải thành ý định — nó là thứ người dùng muốn tác tử ĐỐI XỬ NHƯ DỮ
    LIỆU, và một chuỗi như `rm -rf /` trong nháy là một ví dụ cần in ra, không phải một lệnh.
    """
    ra: list[str] = []
    for m in _NHAY.finditer(van):
        s = (m.group(1) or m.group(2) or m.group(3) or "").strip()
        if s and s not in ra:
            ra.append(s)
    return ra


def xoa_cache() -> None:
    """Bỏ cache bảng chip và danh sách tên miền — cho test đổi tệp spec rồi tra lại."""
    _bang_chip.cache_clear()
    _nha_san_xuat.cache_clear()
