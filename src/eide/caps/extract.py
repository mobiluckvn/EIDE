"""Namespace extract.* — CDS-12.2 (tập Tri thức); KAD-07 §3; DDD-14 §2 Fact.

Hiện thực ở đây: `extract.svd` (EXTRACT-01, M0) và `extract.atdf` (EXTRACT-02, M0). Cả hai là
parser thuần — `method: parser`, `tier: gold` — và đó là điều làm chúng khác hẳn phần còn lại
của namespace này (`extract.pdf_layout`, `extract.image` dùng mô hình, tier bạc).

## Vì sao parser gold còn phải cẩn thận hơn

Fact `tier: gold` đi thẳng qua cổng G-FACT không hỏi ai (quy tắc G-FACT-01). Nghĩa là một lỗi
parser ở đây không bị chặn ở đâu cả: nó thành `base_address` sai trong store, rồi thành hằng số
sai trong mã sinh ra, rồi thành một thanh ghi ghi vào địa chỉ hư không — và triệu chứng ở cuối
chuỗi ấy trông chẳng liên quan gì tới một tệp XML đọc nhầm.

Nên hai parser này thà bỏ sót còn hơn đoán: thẻ không hiểu thì bỏ qua, giá trị không đọc được
thì không sinh fact, `derivedFrom` không giải được thì báo lỗi chứ không giả vờ.
"""
from __future__ import annotations

import hashlib
import json
import re
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.archive import bam_tep
from eide_core import store, tools
from eide_core.errors import EideError
from eide_core.registry import capability
from eide_core.router import Context


def _root(ctx: Context) -> Path:
    root = Path(ctx.project_dir).expanduser() if ctx.project_dir else None
    if not root or not store.store_path(root).exists():
        raise EideError("E2000", "Nhóm extract.* cần một dự án có store",
                        exists=[], candidates=[], missing=["project"])
    return root


def _so(t: str | None) -> int | None:
    """Số trong SVD/ATDF viết bốn kiểu: `0x40005400`, `0X...`, `#0101`, thập phân, và hậu tố
    `k`/`m`. Trả None khi không đọc được — KHÔNG trả 0.

    0 là một địa chỉ hợp lệ (vector table ở 0x00000000), nên dùng nó làm giá trị "không đọc
    được" sẽ sinh ra fact `base_address = 0` trông hoàn toàn bình thường.
    """
    if t is None:
        return None
    t = t.strip()
    try:
        if t.startswith("#"):                       # SVD binary literal: #0101 (x = don't care)
            return int(t[1:].replace("x", "0").replace("X", "0"), 2)
        if t.lower().startswith(("0x", "+0x", "-0x")):
            return int(t, 16)
        if (m := re.fullmatch(r"([+-]?\d+)\s*([kKmMgG])", t)):
            return int(m.group(1)) * {"k": 1024, "m": 1024**2, "g": 1024**3}[m.group(2).lower()]
        return int(t, 0)
    except ValueError:
        return None


def _text(e: ET.Element | None, tag: str) -> str | None:
    if e is None:
        return None
    x = e.find(tag)
    return x.text.strip() if x is not None and x.text else None


# ---------------------------------------------------------------- EXTRACT-01 svd


@capability("extract.svd")
def svd(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-01 — CDS-12.2. tc: TC-09.

    Bước 1: "Parser SVD (derivedFrom, dim, cluster, enum) như M0; *-Community → silver".

    Bốn thứ trong ngoặc là bốn cơ chế của CMSIS-SVD mà bỏ qua thì bản đồ thanh ghi thiếu phần
    lớn nội dung:

    - `derivedFrom` — `I2C2` thường chỉ khai `baseAddress` rồi kế thừa toàn bộ thanh ghi từ
      `I2C1`. Không giải thì I2C2 có đúng một fact.
    - `dim` — mảng ngoại vi/thanh ghi (`TIM%s`, `CH[0-3]`). Không giãn thì bốn kênh thành một.
    - `cluster` — nhóm thanh ghi lồng, offset cộng dồn.
    - `enum` — ý nghĩa từng giá trị của trường; đây là thứ làm khác biệt giữa "bit 3" và
      "bit 3 = 1 nghĩa là bật clock".

    "*-Community → silver": tệp SVD cộng đồng không phải của hãng, nên không được hưởng quyền
    tự duyệt của tầng vàng.
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    try:
        goc = ET.parse(p).getroot()
    except ET.ParseError as e:
        raise EideError("E6001", f"SVD không phải XML hợp lệ: {e}", file=str(p)) from e
    if goc.tag != "device":
        raise EideError("E6001", f"SVD phải có thẻ gốc <device>, gặp <{goc.tag}>", file=str(p))

    ten = _text(goc, "name") or p.stem
    part = _part_iri(goc, ten)
    tier = "silver" if "community" in p.name.lower() else "gold"
    sid = _bao_dam_source(root, p, "svd", tier)

    facts: list[dict[str, Any]] = []
    facts += _bo_nho_svd(goc, part, sid, tier)

    ngoai_vi = {}
    for pe in goc.findall(".//peripherals/peripheral"):
        if (n := _text(pe, "name")):
            ngoai_vi[n] = pe
    for n, pe in ngoai_vi.items():
        facts += _mot_ngoai_vi(pe, n, ngoai_vi, part, sid, tier,
                               params.get("include_descriptions", False))

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part.split(':', 1)[1]}@1.0.0",
                            "kind": "chip", "reason": f"extract.svd {p.name}",
                            "header": {"name": ten, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"], "n_facts": len(facts), "part": part}


def _part_iri(goc: ET.Element, ten: str) -> str:
    """IRI dạng `chip:<ns>.<part>` theo DDD-14 §2 Fact. Nhà sản xuất từ `<vendor>` khi có."""
    ns = (_text(goc, "vendor") or _text(goc, "vendorID") or "").strip().lower()
    ns = re.sub(r"[^a-z0-9]+", "", ns.split()[0]) if ns else ""
    ten = re.sub(r"[^A-Za-z0-9_]+", "", ten).lower()
    return f"chip:{ns}.{ten}" if ns else f"chip:{ten}"


def _bo_nho_svd(goc: ET.Element, part: str, sid: str, tier: str) -> list[dict[str, Any]]:
    """RAM/Flash — chính là fact mà `arch.memory_budget` và `arch.style_select` đọc.

    SVD không có thẻ chuẩn cho dung lượng bộ nhớ; nó nằm trong `<peripheral>` giả tên FLASH/RAM
    hoặc trong `addressBlock`. Rút được thì rút, không thì thôi — `memory_budget` đã xử lý đúng
    trường hợp thiếu (`ok=None`), nên bịa ra ở đây tệ hơn nhiều so với để trống.
    """
    ra = []
    for pe in goc.findall(".//peripherals/peripheral"):
        n = (_text(pe, "name") or "").upper()
        loai = "FLASH" if "FLASH" in n else ("RAM" if ("SRAM" in n or n.endswith("RAM")) else None)
        if not loai:
            continue
        for ab in pe.findall("addressBlock"):
            if (kt := _so(_text(ab, "size"))):
                ra.append({"subject": f"{part}/mem:{loai}", "predicate": "memory_size",
                           "value": kt, "unit": "byte", "source_id": sid, "method": "parser",
                           "tier": tier, "confidence": 1.0})
                break
    return ra


def _mot_ngoai_vi(pe: ET.Element, ten: str, tat_ca: dict[str, ET.Element], part: str,
                  sid: str, tier: str, mo_ta: bool) -> list[dict[str, Any]]:
    ra: list[dict[str, Any]] = []
    goc_pe = _giai_derived(pe, tat_ca)
    base = _so(_text(pe, "baseAddress")) or _so(_text(goc_pe, "baseAddress"))
    if base is None:
        return ra
    iri_pe = f"{part}/periph:{ten}"
    ra.append({"subject": iri_pe, "predicate": "base_address", "value": base,
               "source_id": sid, "method": "parser", "tier": tier, "confidence": 1.0})

    for irq in pe.findall("interrupt"):
        if (v := _so(_text(irq, "value"))) is not None:
            ra.append({"subject": iri_pe, "predicate": "irq", "value": v,
                       "source_id": sid, "method": "parser", "tier": tier, "confidence": 1.0})

    for reg, off in _cac_thanh_ghi(goc_pe):
        for r in _giai_dim(reg, off):
            ra += _mot_thanh_ghi(r[0], r[1], r[2], iri_pe, sid, tier, mo_ta)
    return ra


def _giai_derived(pe: ET.Element, tat_ca: dict[str, ET.Element]) -> ET.Element:
    """`derivedFrom` có thể nối chuỗi (`I2C3` → `I2C2` → `I2C1`). Đi hết chuỗi, chặn vòng lặp.

    Không chặn vòng thì một tệp SVD hỏng (hiếm nhưng có) làm parser treo — và treo giữa lúc nạp
    một thư viện 600 hộ chiếu thì không ai biết nó dừng ở đâu.
    """
    da_qua = set()
    while (cha := pe.get("derivedFrom")):
        if cha in da_qua or cha not in tat_ca:
            break
        da_qua.add(cha)
        pe = tat_ca[cha]
    return pe


def _cac_thanh_ghi(pe: ET.Element) -> list[tuple[ET.Element, int]]:
    """Thanh ghi trực tiếp cộng thanh ghi trong `cluster` (offset cộng dồn)."""
    ra = [(r, 0) for r in pe.findall("registers/register")]
    for cl in pe.findall("registers/cluster"):
        off_cl = _so(_text(cl, "addressOffset")) or 0
        ra += [(r, off_cl) for r in cl.findall("register")]
    return ra


def _giai_dim(reg: ET.Element, off_cha: int) -> list[tuple[ET.Element, str, int]]:
    """Giãn `dim`: `<name>CH%s_CR</name><dim>4</dim><dimIncrement>0x20</dimIncrement>`.

    `dimIndex` cho tên chỉ số tường minh (`A,B,C` hoặc `0-3`); thiếu thì dùng 0..n-1.
    """
    ten = _text(reg, "name") or ""
    off = (_so(_text(reg, "addressOffset")) or 0) + off_cha
    n = _so(_text(reg, "dim"))
    if not n or n <= 1:
        return [(reg, ten, off)]
    buoc = _so(_text(reg, "dimIncrement")) or 4
    chi_so = _dim_index(_text(reg, "dimIndex"), n)
    return [(reg, ten.replace("%s", str(chi_so[i])).replace("[%s]", str(chi_so[i])),
             off + i * buoc) for i in range(n)]


def _dim_index(s: str | None, n: int) -> list[str]:
    if not s:
        return [str(i) for i in range(n)]
    if (m := re.fullmatch(r"\s*(\w+)\s*-\s*(\w+)\s*", s)):
        a, b = m.group(1), m.group(2)
        if a.isdigit() and b.isdigit():
            return [str(i) for i in range(int(a), int(b) + 1)]
        return [chr(c) for c in range(ord(a), ord(b) + 1)]
    return [x.strip() for x in s.split(",")]


def _mot_thanh_ghi(reg: ET.Element, ten: str, off: int, iri_pe: str, sid: str,
                   tier: str, mo_ta: bool) -> list[dict[str, Any]]:
    iri = f"{iri_pe}/reg:{ten}"
    chung = {"source_id": sid, "method": "parser", "tier": tier, "confidence": 1.0}
    ra = [{"subject": iri, "predicate": "offset", "value": off, **chung}]
    if (rv := _so(_text(reg, "resetValue"))) is not None:
        ra.append({"subject": iri, "predicate": "reset_value", "value": rv, **chung})
    if mo_ta and (d := _text(reg, "description")):
        ra.append({"subject": iri, "predicate": "description", "value": " ".join(d.split()),
                   **chung})

    for fl in reg.findall("fields/field"):
        fn = _text(fl, "name")
        if not fn:
            continue
        iri_f = f"{iri}/field:{fn}"
        if (dai := _bit_range(fl)) is not None:
            ra.append({"subject": iri_f, "predicate": "bit_range", "value": list(dai), **chung})
        for ev in fl.findall("enumeratedValues/enumeratedValue"):
            if (en := _text(ev, "name")) and (v := _so(_text(ev, "value"))) is not None:
                ra.append({"subject": iri_f, "predicate": "enum",
                           "value": {"name": en, "value": v}, **chung})
    return ra


def _bit_range(fl: ET.Element) -> tuple[int, int] | None:
    """SVD cho ba cách khai vị trí bit; đọc thiếu một cách nghĩa là mất trường của cả một họ chip."""
    if (br := _text(fl, "bitRange")) and (m := re.fullmatch(r"\[(\d+):(\d+)\]", br.strip())):
        return int(m.group(2)), int(m.group(1))
    lsb, msb = _so(_text(fl, "lsb")), _so(_text(fl, "msb"))
    if lsb is not None and msb is not None:
        return lsb, msb
    off, w = _so(_text(fl, "bitOffset")), _so(_text(fl, "bitWidth"))
    if off is not None:
        return off, off + (w or 1) - 1
    return None


# ---------------------------------------------------------------- EXTRACT-02 atdf


@capability("extract.atdf")
def atdf(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-02 — CDS-12.2. tc: TC-10.

    ATDF là định dạng của Microchip cho AVR — cấu trúc khác SVD hẳn: `<module>` chứa
    `<register-group>` chứa `<register>`, và địa chỉ nền nằm ở `<address-spaces>` chứ không ở
    module. Nên đây là parser riêng, không phải SVD đổi tên thẻ.

    Đây cũng là năng lực đầu tiên trong kho chạm tới AVR — mốc M0 cùng ARM, và tới giờ chưa có
    gì đọc `avr8.yaml` (xem DEV-055).
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    try:
        goc = ET.parse(p).getroot()
    except ET.ParseError as e:
        raise EideError("E6001", f"ATDF không phải XML hợp lệ: {e}", file=str(p)) from e
    if goc.tag != "avr-tools-device-file":
        raise EideError("E6001", "ATDF phải có thẻ gốc <avr-tools-device-file>, gặp "
                        f"<{goc.tag}>", file=str(p))

    dev = goc.find(".//devices/device")
    if dev is None:
        raise EideError("E6001", "ATDF không có <device>", file=str(p))
    ten = re.sub(r"[^A-Za-z0-9_]+", "", dev.get("name") or p.stem).lower()
    part = f"chip:microchip.{ten}"
    sid = _bao_dam_source(root, p, "atdf", "gold")
    chung = {"source_id": sid, "method": "parser", "tier": "gold", "confidence": 1.0}

    facts: list[dict[str, Any]] = []
    for sp in dev.findall(".//address-spaces/address-space"):
        loai = {"prog": "FLASH", "data": "RAM", "eeprom": "EEPROM"}.get(sp.get("id", ""))
        if loai and (kt := _so(sp.get("size"))):
            facts.append({"subject": f"{part}/mem:{loai}", "predicate": "memory_size",
                          "value": kt, "unit": "byte", **chung})

    nen: dict[str, int] = {}
    for seg in dev.findall(".//address-spaces/address-space/memory-segment"):
        if (n := seg.get("name")) and (a := _so(seg.get("start"))) is not None:
            nen[n.upper()] = a

    for mod in goc.findall(".//modules/module"):
        mn = mod.get("name")
        if not mn:
            continue
        iri_m = f"{part}/periph:{mn}"
        for rg in mod.findall("register-group"):
            goc_rg = nen.get((rg.get("name") or "").upper(), 0)
            for reg in rg.findall("register"):
                rn, off = reg.get("name"), _so(reg.get("offset"))
                if not rn or off is None:
                    continue
                iri = f"{iri_m}/reg:{rn}"
                facts.append({"subject": iri, "predicate": "offset",
                              "value": off + goc_rg, **chung})
                if (iv := _so(reg.get("initval"))) is not None:
                    facts.append({"subject": iri, "predicate": "reset_value", "value": iv,
                                  **chung})
                for bf in reg.findall("bitfield"):
                    bn, mask = bf.get("name"), _so(bf.get("mask"))
                    if bn and mask:
                        facts.append({"subject": f"{iri}/field:{bn}", "predicate": "bit_range",
                                      "value": list(_tu_mask(mask)), **chung})
        for irq in mod.findall(".//interrupt"):
            if (v := _so(irq.get("index"))) is not None:
                facts.append({"subject": iri_m, "predicate": "irq", "value": v, **chung})

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"microchip.{ten}@1.0.0",
                            "kind": "chip", "reason": f"extract.atdf {p.name}",
                            "header": {"name": dev.get("name"), "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"], "n_facts": len(facts)}


def _tu_mask(mask: int) -> tuple[int, int]:
    """ATDF khai bit bằng mặt nạ (`0x38`), SVD khai bằng dải. Đổi sang dải để CÙNG một vị từ
    `bit_range` dùng được cho cả hai — nếu không, `kg.query` phải biết fact này từ parser nào."""
    lo = (mask & -mask).bit_length() - 1
    return lo, mask.bit_length() - 1


# ---------------------------------------------------------------- nguồn


def _bao_dam_source(root: Path, p: Path, kind: str, tier: str) -> str:
    """Ghi `source` nếu chưa có, trả `source_id`.

    Băm nội dung làm khóa, không dùng đường dẫn: cùng một tệp SVD trích hai lần từ hai chỗ phải
    ra cùng một `source_id`, nếu không thì `passport.import` không nhận ra là trùng và mỗi lần
    trích lại sinh thêm một bộ fact.
    """
    h = bam_tep(p)
    db = store.store_path(root)
    with store.open_store(db) as c:
        if (r := c.execute("SELECT id FROM source WHERE sha256=?", (h,)).fetchone()):
            return r[0]
        sid = "src_" + h[:16]
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier, size_bytes, fetched_at)"
                  " VALUES (?,?,?,?,?,?,?)",
                  (sid, str(p), h, kind, tier, p.stat().st_size,
                   datetime.now(UTC).isoformat()))
        c.commit()
    return sid


# ---------------------------------------------------------------- EXTRACT-03 edc


@capability("extract.edc")
def edc(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-03 — CDS-12.2. tc: "50 SFR khớp datasheet".

    EDC (`.PIC`) là định dạng của Microchip cho PIC — XML, nhưng cấu trúc khác hẳn cả SVD lẫn
    ATDF: thanh ghi nằm trong `<edc:SFRDef>` với thuộc tính `_addr`, và bit trong `<edc:SFRFieldDef>`
    với `_mask`. Dùng chung parser với ATDF là cách chắc chắn để đọc ra rỗng mà không báo lỗi.

    Namespace `edc:` bắt buộc phải xử lý: `ElementTree` giữ nguyên tiền tố dạng
    `{http://crownking/edc}SFRDef` trong `tag`, nên tìm theo tên trần sẽ không khớp gì cả — và
    "không khớp gì" ở đây trông y hệt "tệp không có thanh ghi nào".
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    try:
        goc = ET.parse(p).getroot()
    except ET.ParseError as e:
        raise EideError("E6001", f"EDC không phải XML hợp lệ: {e}", file=str(p)) from e
    if not _ten(goc.tag).lower().startswith("pic"):
        raise EideError("E6001", f"EDC phải có thẻ gốc <edc:PIC>, gặp <{_ten(goc.tag)}>",
                        file=str(p))

    ten = re.sub(r"[^A-Za-z0-9_]+", "", goc.get("{http://crownking/edc}name")
                 or goc.get("name") or p.stem).lower()
    part = f"chip:microchip.{ten}"
    sid = _bao_dam_source(root, p, "edc", "gold")
    chung = {"source_id": sid, "method": "parser", "tier": "gold", "confidence": 1.0}

    facts: list[dict[str, Any]] = []
    for sfr in goc.iter():
        if _ten(sfr.tag) != "SFRDef":
            continue
        rn, addr = _thuoc_tinh(sfr, "cname", "name"), _so(_thuoc_tinh(sfr, "_addr"))
        if not rn or addr is None:
            continue
        iri = f"{part}/periph:SFR/reg:{rn}"
        facts.append({"subject": iri, "predicate": "address", "value": addr, **chung})
        if (rv := _so(_thuoc_tinh(sfr, "_por", "por"))) is not None:
            facts.append({"subject": iri, "predicate": "reset_value", "value": rv, **chung})
        for fl in sfr.iter():
            if _ten(fl.tag) != "SFRFieldDef":
                continue
            fn, mask = _thuoc_tinh(fl, "cname", "name"), _so(_thuoc_tinh(fl, "_mask", "mask"))
            if fn and mask:
                facts.append({"subject": f"{iri}/field:{fn}", "predicate": "bit_range",
                              "value": list(_tu_mask(mask)), **chung})

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"microchip.{ten}@1.0.0",
                            "kind": "chip", "reason": f"extract.edc {p.name}",
                            "header": {"name": ten, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"], "n_facts": len(facts)}


def _ten(tag: str) -> str:
    """Bỏ namespace `{uri}Local` → `Local`."""
    return tag.rsplit("}", 1)[-1]


def _thuoc_tinh(e: ET.Element, *ten: str) -> str | None:
    """Thuộc tính theo tên, thử cả dạng có namespace. EDC trộn cả hai kiểu trong cùng một tệp."""
    for t in ten:
        for k, v in e.attrib.items():
            if _ten(k) == t:
                return v
    return None


# ---------------------------------------------------------------- EXTRACT-04 header_c


# Quy ước đặt tên trong header hãng. Ba mẫu này phủ gần hết CMSIS và Microchip; mẫu nào không
# khớp thì BỎ QUA, không đoán — một `#define` bất kỳ trong header không nhất thiết là địa chỉ.
MAU_HEADER = (
    (re.compile(r"^\s*#\s*define\s+([A-Z][A-Z0-9_]*)_BASE\s+\(?\s*([^)\n]+?)\s*\)?\s*(?:/\*|//|$)",
                re.M), "base_address"),
    (re.compile(r"^\s*#\s*define\s+([A-Z][A-Z0-9_]*)_Msk\s+\(?\s*(0[xX][0-9a-fA-F]+[UuLl]*)",
                re.M), "bit_mask"),
    (re.compile(r"^\s*#\s*define\s+([A-Z][A-Z0-9_]*)_Pos\s+\(?\s*(\d+)", re.M), "bit_pos"),
)


@capability("extract.header_c")
def header_c(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-04 — CDS-12.2. tc: "Lệch cố ý 1 địa chỉ → conflict 1".

    Bước 2 — "Đối chiếu SVD nếu có → conflicts" — là lý do năng lực này đáng làm, chứ không phải
    bước 1. Header hãng và SVD hãng mô tả CÙNG một con chip từ hai đường khác nhau; chỗ chúng
    bất đồng là chỗ một trong hai sai, và đó là thông tin không lấy được từ riêng nguồn nào.

    Không tự đếm conflict: đẩy qua `passport.import` rồi lấy con số nó trả về. Đếm ở đây là hiện
    thực lại bảng gộp KAD-07 §5.1 lần thứ hai, và hai bản sẽ lệch nhau ngay lần đầu ai đó sửa
    quy tắc gộp.
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    try:
        t = p.read_text(encoding="utf-8", errors="ignore")
    except OSError as e:
        raise EideError("E6001", f"Không đọc được {p}: {e}", file=str(p)) from e

    part = params.get("part") or _part_tu_header(t) or p.stem.lower()
    iri_goc = part if part.startswith("chip:") else f"chip:{part}"
    sid = _bao_dam_source(root, p, "header", "gold")
    chung = {"source_id": sid, "method": "parser", "tier": "gold", "confidence": 1.0}

    facts: list[dict[str, Any]] = _vung_nho_header(t, iri_goc, chung)
    pos: dict[str, int] = {}
    for mau, loai in MAU_HEADER:
        for m in mau.finditer(t):
            ten, gt = m.group(1), _so(m.group(2).rstrip("UuLl"))
            if gt is None:
                continue
            if loai == "base_address":
                facts.append({"subject": f"{iri_goc}/periph:{ten}",
                              "predicate": "base_address", "value": gt, **chung})
            elif loai == "bit_pos":
                pos[ten] = gt
            else:
                facts.append({"subject": _iri_field(iri_goc, ten), "predicate": "bit_range",
                              "value": list(_tu_mask(gt)), **chung})

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part}@1.0.0", "kind": "chip",
                            "reason": f"extract.header_c {p.name}",
                            "header": {"name": part, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"], "n_facts": len(facts), "conflicts": kq["conflicts"]}


# Vùng nhớ trong header hãng: một cặp `<TÊN>_LOW` / `<TÊN>_HIGH`. Quy ước này là của ESP-IDF
# (`soc/soc.h`) nhưng không riêng Espressif — Nordic, NXP cũng khai biên vùng theo cặp low/high.
#
# `SOC_` là tiền tố của Espressif; bỏ nó để tên vùng trong hộ chiếu là `IRAM` chứ không phải
# `SOC_IRAM` — tên vùng đi vào bản đồ bộ nhớ và vào `.repl`, nơi người đọc mong thấy tên vùng
# chứ không thấy tên thư viện.
MAU_BIEN_VUNG = re.compile(
    r"^\s*#\s*define\s+((?:SOC_)?[A-Z][A-Z0-9_]*?)_(LOW|HIGH)\s+\(?\s*([A-Za-z0-9_]+)",
    re.M)

# Tên vùng phải NÓI nó là bộ nhớ. Không có ràng buộc này thì mọi `#define X_LOW/X_HIGH` trong
# header — ngưỡng so sánh, mức logic chân, dải tần — đều thành một vùng nhớ ma trong hộ chiếu.
# Cùng từ khoá mà `_bo_nho_svd` dùng, vì cùng một câu hỏi.
TU_BO_NHO = ("RAM", "ROM", "FLASH")


def _vung_nho_header(t: str, iri_goc: str, chung: dict[str, Any]) -> list[dict[str, Any]]:
    """`SOC_IRAM_LOW`/`SOC_IRAM_HIGH` → fact `base_address` + `memory_size` (byte).

    **Vì sao đường này tồn tại.** `memory_size` là fact mà `sim.build_platform`,
    `arch.memory_budget` và `diagram.memory_map` đều đọc, và cho tới nay chỉ `extract.svd` và
    `extract.atdf` sinh được nó. SVD của Espressif — khác ST — **không khai vùng nhớ nào**:
    không có `<peripheral>` giả tên FLASH/RAM, không `addressBlock` nào phủ SRAM. Nên một dự án
    ESP32 đi hết luồng tri thức (8.169 fact, 15.834 nút) mà vẫn không mô phỏng được, vì thiếu
    đúng một con số. Header chính hãng có con số ấy, ở dạng máy đọc được, không cần mô hình.

    **Vì sao trừ chứ không tin một `_SIZE` có sẵn.** Header hay có cả
    `SOC_MAX_CONTIGUOUS_RAM_SIZE (SOC_IRAM_HIGH - SOC_IRAM_LOW)` — cùng một phép trừ, viết sẵn.
    Đọc biểu thức ấy đòi phải hiểu cú pháp C; đọc hai biên rồi tự trừ thì không, và ra cùng số.

    **Vùng chồng nhau không bị gộp.** ESP32-C3 nhìn cùng 400 KB SRAM qua hai cửa sổ (`IRAM`
    0x4037C000, `DRAM` 0x3FC80000). Cả hai vào hộ chiếu như hai vùng: chúng có địa chỉ khác
    nhau thật, và firmware nạp sai cửa sổ thì treo. Gộp chúng lại thành "400 KB RAM" là bỏ đi
    đúng thông tin phân biệt được hai lỗi ấy.
    """
    bien: dict[str, dict[str, int]] = {}
    tro: dict[tuple[str, str], str] = {}
    so_theo_ten: dict[str, int] = {}
    for m in MAU_BIEN_VUNG.finditer(t):
        ten, canh, gt = m.group(1), m.group(2).lower(), m.group(3)
        if (v := _so(gt.rstrip("UuLl"))) is None:
            # Giá trị là tên một `#define` khác (`SOC_DROM_LOW  SOC_IROM_LOW` — có thật trong
            # soc.h). Ghi lại để giải ở lượt hai; bỏ ngay thì mất hẳn một vùng.
            tro[(ten, canh)] = gt
            continue
        bien.setdefault(ten, {})[canh] = v
        so_theo_ten[f"{ten}_{canh.upper()}"] = v

    for (ten, canh), ref in tro.items():
        if (v := so_theo_ten.get(ref)) is not None:
            bien.setdefault(ten, {}).setdefault(canh, v)

    ra: list[dict[str, Any]] = []
    for ten, c in bien.items():
        lo, hi = c.get("low"), c.get("high")
        if lo is None or hi is None or hi <= lo:
            continue
        goi = re.sub(r"^SOC_", "", ten)
        if not any(k in goi for k in TU_BO_NHO):
            continue
        iri = f"{iri_goc}/mem:{goi}"
        ra.append({"subject": iri, "predicate": "base_address", "value": lo, **chung})
        ra.append({"subject": iri, "predicate": "memory_size", "value": hi - lo,
                   "unit": "byte", **chung})
    return ra


def _part_tu_header(t: str) -> str | None:
    """Tên chip từ `#define STM32F411xE` hoặc chú thích đầu tệp — quy ước CMSIS."""
    if (m := re.search(r"^\s*#\s*define\s+(STM32[A-Z0-9x]+)\s*$", t[:20_000], re.M)):
        return "st." + m.group(1).lower()
    if (m := re.search(r"@file\s+(\S+?)\.h", t[:4000])):
        return m.group(1).lower()
    return None


def _iri_field(goc: str, ten: str) -> str:
    """`I2C_CR1_PE_Msk` → `…/periph:I2C/reg:CR1/field:PE`.

    Tên CMSIS ghép bằng `_` và không có dấu phân cấp, nên phải tách theo quy ước ba đoạn đầu.
    Tên không đủ ba đoạn thì để nguyên dưới `periph:` — đoán sâu hơn sẽ tạo ra IRI không khớp
    với IRI mà `extract.svd` sinh, và khi ấy hai nguồn về cùng một trường KHÔNG gặp nhau: bước 2
    mất tác dụng, mà bước 2 mới là lý do năng lực này tồn tại.
    """
    d = ten.split("_")
    if len(d) >= 3:
        return f"{goc}/periph:{d[0]}/reg:{d[1]}/field:{'_'.join(d[2:])}"
    if len(d) == 2:
        return f"{goc}/periph:{d[0]}/reg:{d[1]}"
    return f"{goc}/periph:{ten}"


# ---------------------------------------------------------------- EXTRACT-21 code_constants


# Hằng số đáng ngờ: địa chỉ, mặt nạ bit, hoặc số lớn không rõ nguồn. Số nhỏ (0, 1, 2…) là chỉ
# số vòng lặp và kích thước mảng — đưa chúng vào `unsourced` thì danh sách toàn nhiễu.
RE_HANG_SO = re.compile(r"\b(0[xX][0-9a-fA-F]{3,}|[0-9]{4,})\b")
RE_CHU_THICH_FACT = re.compile(r"(?://|/\*|#)\s*eide:fact\s+(f_[0-9a-f]+)")
DUOI_MA = (".c", ".h", ".cpp", ".hpp", ".cc", ".rs")


@capability("extract.code_constants")
def code_constants(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-21 — CDS-12.2. tc: "UC-A05: 100 hằng số → phân loại đúng".

    Trả lời một câu hỏi cụ thể: **hằng số nào trong mã không truy được về nguồn nào?** Một
    `0x40005400` viết tay trong driver có thể đúng, có thể là số của con chip người viết dùng
    lần trước. Không phân biệt được thì cả hai trông giống nhau cho tới lúc nạp lên board.

    Chú thích `eide:fact f_xxx` là đường khai báo tường minh; ngoài ra thì đối chiếu GIÁ TRỊ với
    store. Khớp giá trị là bằng chứng yếu hơn chú thích — hai thanh ghi khác nhau có thể trùng
    offset — nên `cites` ghi kèm `how` để người đọc biết mức chắc chắn.
    """
    root = _root(ctx)
    repo = Path(params["repo"]).expanduser()
    if not repo.is_dir():
        raise EideError("E2000", f"Không có thư mục {repo}", exists=[], candidates=[],
                        missing=[str(repo)])

    db = store.store_path(root)
    theo_gt: dict[int, list[str]] = {}
    if db.exists():
        with store.open_store(db) as c:
            for fid, gt in c.execute(
                    "SELECT id, value FROM fact WHERE predicate IN "
                    "('base_address','offset','address','reset_value')"
                    " AND status NOT IN ('superseded','rejected')").fetchall():
                try:
                    theo_gt.setdefault(int(json.loads(gt)), []).append(fid)
                except (ValueError, TypeError):
                    continue

    tep = _cac_tep(repo, params.get("paths"))
    n_cu, chua_nguon = 0, []
    for f in tep:
        try:
            noi = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        n_cu += 1
        for i, dong in enumerate(noi.splitlines(), 1):
            khai = RE_CHU_THICH_FACT.search(dong)
            for m in RE_HANG_SO.finditer(dong):
                gt = _so(m.group(1))
                if gt is None:
                    continue
                if khai:
                    continue                       # đã khai nguồn tường minh
                if gt in theo_gt:
                    continue                       # khớp giá trị trong store
                chua_nguon.append({"file": str(f.relative_to(repo)), "line": i,
                                   "literal": m.group(1)})
    return {"code_units": n_cu, "unsourced": chua_nguon}


def _cac_tep(repo: Path, paths: list[str] | None) -> list[Path]:
    if paths:
        return [x for p in paths for x in repo.glob(p) if x.is_file()]
    return [p for p in sorted(repo.rglob("*"))
            if p.is_file() and p.suffix.lower() in DUOI_MA
            and not any(x in p.parts for x in ("build", ".git", "node_modules"))]


# ---------------------------------------------------------------- EXTRACT-06 pdf_layout


@capability("extract.pdf_layout")
def pdf_layout(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-06 — CDS-12.2. tc: "Bảng thanh ghi nhận dạng là table với bbox";
    lỗi E4001 (thiếu docling), E4004.

    Năng lực này KHÔNG sinh fact. Nó chỉ chuyển một PDF thành khối có `bbox`, và việc tách ấy là
    có chủ ý: bóc bố cục là bài toán xác định (thư viện làm), còn hiểu bảng thanh ghi là bài
    toán suy luận (mô hình làm, ở `extract.pdf_register_map`). Gộp hai việc thì không phân biệt
    được "đọc sai trang" với "hiểu sai bảng", mà hai lỗi ấy sửa bằng hai cách khác nhau.

    `bbox` là thứ làm nên giá trị: nó cho `locator` của fact trỏ về ĐÚNG Ô trong đúng trang, nên
    sau này người kiểm mở datasheet ra là thấy ngay chỗ số ấy đến từ đâu. Một fact "trang 47"
    thì vẫn phải tự dò cả trang.
    """
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    trang = _dai_trang(params.get("pages"))

    if (kq := _docling(p, trang)) is not None:
        return kq
    try:
        import pdfplumber  # noqa: F401
    except ImportError as e:
        raise EideError("E4001", "Cần `docling` hoặc `pdfplumber` để đọc PDF — chạy "
                        "`pip install pdfplumber`", tool="pdfplumber",
                        package="pdfplumber") from e
    return _pdfplumber(p, trang)


def _dai_trang(s: str | None) -> set[int] | None:
    """`"1-3,7"` → {1,2,3,7}. None = mọi trang."""
    if not s:
        return None
    ra: set[int] = set()
    for phan in str(s).split(","):
        phan = phan.strip()
        if "-" in phan:
            a, b = phan.split("-", 1)
            ra.update(range(int(a), int(b) + 1))
        elif phan:
            ra.add(int(phan))
    return ra or None


def _docling(p: Path, trang: set[int] | None) -> dict[str, Any] | None:
    """Dùng docling nếu có. Không có thì trả None để rơi xuống pdfplumber — KHÔNG ném E4001 ở
    đây: hợp đồng chỉ cho phép E4001 khi CẢ HAI đều thiếu, và docling kéo theo PyTorch nên bắt
    buộc nó là bắt người dùng tải 2 GB cho một việc pdfplumber làm đủ tốt."""
    try:
        from docling.document_converter import DocumentConverter
    except ImportError:
        return None
    try:
        d = DocumentConverter().convert(str(p)).document
    except Exception as e:                                    # noqa: BLE001
        raise EideError("E4004", f"docling không đọc được {p.name}: {e}", file=str(p)) from e
    blocks, toc = [], []
    for it in getattr(d, "texts", []):
        pg = _trang_cua(it)
        if trang and pg not in trang:
            continue
        loai = "heading" if "head" in str(getattr(it, "label", "")).lower() else "text"
        blocks.append({"page": pg, "bbox": _bbox_cua(it), "type": loai,
                       "content": getattr(it, "text", "")})
        if loai == "heading":
            toc.append({"page": pg, "title": getattr(it, "text", "")})
    for tb in getattr(d, "tables", []):
        pg = _trang_cua(tb)
        if trang and pg not in trang:
            continue
        blocks.append({"page": pg, "bbox": _bbox_cua(tb), "type": "table",
                       "content": _bang_docling(tb)})
    blocks.sort(key=lambda b: (b["page"], (b["bbox"] or [0, 0, 0, 0])[1]))
    return {"blocks": blocks, "toc": toc}


def _trang_cua(it: Any) -> int:
    for pr in (getattr(it, "prov", None) or []):
        if (n := getattr(pr, "page_no", None)):
            return int(n)
    return 1


def _bbox_cua(it: Any) -> list[float] | None:
    for pr in (getattr(it, "prov", None) or []):
        if (b := getattr(pr, "bbox", None)) is not None:
            return [getattr(b, "l", 0), getattr(b, "t", 0),
                    getattr(b, "r", 0), getattr(b, "b", 0)]
    return None


def _bang_docling(tb: Any) -> list[list[str]]:
    try:
        return [[str(x) for x in hang] for hang in tb.export_to_dataframe().values.tolist()]
    except Exception:                                          # noqa: BLE001
        return []


def _pdfplumber(p: Path, trang: set[int] | None) -> dict[str, Any]:
    import pdfplumber
    blocks: list[dict[str, Any]] = []
    toc: list[dict[str, Any]] = []
    try:
        with pdfplumber.open(p) as pdf:
            for i, page in enumerate(pdf.pages, 1):
                if trang and i not in trang:
                    continue
                bang = _tim_bang(page)
                for t in bang:
                    blocks.append({"page": i, "bbox": list(t.bbox), "type": "table",
                                   "content": [[(x or "").strip() for x in hang]
                                               for hang in t.extract()]})
                # Nhận TIÊU ĐỀ trên cả trang, nhưng chỉ giữ THÂN BÀI nằm ngoài bảng.
                #
                # Hai việc khác nhau và không loại trừ nhau. Chữ trong bảng phải bị loại khỏi
                # khối text — để lại thì mỗi ô xuất hiện hai lần, và `pdf_register_map` thấy
                # cùng một giá trị ở hai chỗ rồi coi đó là "nguồn thứ hai": một sự trùng khớp
                # tự tạo. Nhưng tiêu đề thì không: chiến lược `text` hay nuốt cả dòng tiêu đề
                # vào vùng bảng, và lọc theo bbox sẽ làm `toc` rỗng ở đúng những trang có bảng
                # — tức mất mục lục ở phần đáng tra cứu nhất của datasheet.
                bb = [t.bbox for t in bang]
                for kh in _khoi_van_ban(page, i):
                    if kh["type"] == "heading":
                        toc.append({"page": i, "title": kh["content"]})
                        blocks.append(kh)
                    elif not _trong({"x0": kh["bbox"][0], "top": kh["bbox"][1]}, bb):
                        blocks.append(kh)
    except EideError:
        raise
    except Exception as e:                # noqa: BLE001 — pdfminer ném cả họ PSException riêng
        raise EideError("E4004", f"Không đọc được PDF {p.name}: {e}", file=str(p)) from e
    blocks.sort(key=lambda b: (b["page"], (b["bbox"] or [0, 0, 0, 0])[1]))
    return {"blocks": blocks, "toc": toc}


# Chiến lược tìm bảng. `lines` là mặc định của pdfplumber và đúng cho phần lớn datasheet hãng
# (bảng thanh ghi thường có khung). Nhưng KHÔNG phải tất cả: nhiều tài liệu chỉ căn cột bằng
# khoảng trắng, và ở đó `lines` trả về rỗng — rồi cả bảng thanh ghi trôi vào khối `text`, nơi
# `extract.pdf_register_map` không tìm.
CHIEN_LUOC_BANG = (
    {},                                                     # mặc định: theo đường kẻ
    {"vertical_strategy": "text", "horizontal_strategy": "text"},
)


def _tim_bang(page: Any) -> list[Any]:
    """Thử theo đường kẻ trước, không thấy thì thử theo căn cột.

    Thứ tự có ý nghĩa: chiến lược `text` nhận diện rộng tay hơn, nên chạy nó trước sẽ biến mọi
    đoạn văn căn đều thành "bảng". Chỉ dùng nó khi cách chắc chắn hơn đã trả về rỗng.
    """
    for tt in CHIEN_LUOC_BANG:
        if (b := page.find_tables(table_settings=tt) if tt else page.find_tables()):
            return b
    return []


def _trong(obj: dict[str, Any], bboxes: list[tuple]) -> bool:
    x, y = obj.get("x0", 0), obj.get("top", 0)
    return any(a <= x <= c and b <= y <= d for a, b, c, d in bboxes)


CO_TIEU_DE = 1.15        # cỡ chữ lớn hơn trung vị bao nhiêu lần thì coi là tiêu đề


def _khoi_van_ban(page: Any, so_trang: int) -> list[dict[str, Any]]:
    """Gom chữ thành khối theo DÒNG rồi theo đoạn, và đánh dấu tiêu đề theo CỠ CHỮ.

    Nhận tiêu đề bằng cỡ chữ chứ không bằng biểu thức chính quy trên nội dung: datasheet đánh số
    mục kiểu "8.4.2" nhưng cũng đầy dòng thân bài bắt đầu bằng số. Cỡ chữ thì khách quan, và nó
    là thứ `toc` cần để mục lục không lẫn thân bài.
    """
    chu = page.extract_words(extra_attrs=["size"]) or []
    if not chu:
        return []
    co = sorted(float(w.get("size") or 0) for w in chu)
    trung_vi = co[len(co) // 2] or 1.0

    dong: dict[int, list[dict[str, Any]]] = {}
    for w in chu:
        dong.setdefault(round(float(w["top"]) / 3), []).append(w)

    ra = []
    for _, ws in sorted(dong.items()):
        ws.sort(key=lambda w: w["x0"])
        text = " ".join(w["text"] for w in ws).strip()
        if not text:
            continue
        cx = max(float(w.get("size") or 0) for w in ws)
        ra.append({"page": so_trang,
                   "bbox": [min(float(w["x0"]) for w in ws), min(float(w["top"]) for w in ws),
                            max(float(w["x1"]) for w in ws), max(float(w["bottom"]) for w in ws)],
                   "type": "heading" if cx >= trung_vi * CO_TIEU_DE else "text",
                   "content": text})
    return ra


# ---------------------------------------------------------------- EXTRACT-07 pdf_register_map


# Bước 1: "Chọn bảng có tiêu đề/cột dạng thanh ghi (Register, Address, Bit, Reset…)". Chọn bảng
# là việc CỦA MÃ, không của mô hình: một datasheet 900 trang có hàng trăm bảng, và đưa hết cho
# mô hình vừa tốn vừa làm nó lẫn bảng đặt hàng với bảng thanh ghi.
COT_THANH_GHI = ("register", "address", "offset", "bit", "reset", "field", "name", "access",
                 "rw", "description", "value", "bits")
NGUONG_CHON_BANG = 2          # số cột nhận ra được, tối thiểu


@capability("extract.pdf_register_map")
def pdf_register_map(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-07 — CDS-12.2. tc: TC-12 "≥ 90%"; ask "confidence < ngưỡng".

    Đây là chỗ mô hình thật sự cần: bảng thanh ghi trong PDF không có lược đồ. Cột "Bits" có thể
    là `[7:4]`, `7:4`, `7-4`, hay bốn dòng riêng; "Reset" có thể là `0x00`, `0000 0000`, hay
    `--`. Viết quy tắc cho mọi biến thể là viết lại một trình phân tích không bao giờ đủ.

    Nhưng ba việc quanh nó vẫn là của mã, và tách ra mới đúng:

    1. **Chọn bảng** — theo tiêu đề cột, deterministic. Đưa cả 400 bảng của một datasheet cho mô
       hình thì vừa tốn vừa làm nó lẫn bảng đặt hàng với bảng thanh ghi.
    2. **`locator`** — trang + bbox lấy từ khối, không hỏi mô hình. Mô hình bịa số trang là
       chuyện thường, và một trích dẫn sai còn tệ hơn không trích dẫn.
    3. **`confidence`** — tính từ điểm bảng × độ khớp kiểu, không nhận con số mô hình tự chấm.
       Mô hình tự chấm điểm tin cậy cho chính nó thì con số ấy không mang thông tin.

    Fact ra `tier: silver` theo hợp đồng — trích từ PDF bằng mô hình không bao giờ ngang hàng
    với parser SVD, dù bảng có rõ đến đâu.
    """
    root = _root(ctx)
    part = params["part"]
    khoi = params.get("blocks")
    if khoi is None:
        khoi = pdf_layout({"file": params["file"]}, ctx)["blocks"]
    bang = [b for b in khoi if b.get("type") == "table" and _diem_bang(b) >= NGUONG_CHON_BANG]
    if not bang:
        raise EideError("E5002", "Không thấy bảng nào có dạng bảng thanh ghi trong tài liệu "
                        f"({len([b for b in khoi if b.get('type') == 'table'])} bảng đã xét)",
                        n_tables=len([b for b in khoi if b.get("type") == "table"]))

    p = Path(params["file"]).expanduser()
    sid = _bao_dam_source(root, p, "pdf", "silver")
    iri_goc = part if part.startswith("chip:") else f"chip:{part}"

    facts: list[dict[str, Any]] = []
    thap = 0
    nguong = _nguong_fact(ctx)
    for b in bang:
        resp = _gateway(ctx).run(
            "librarian",
            "Chuyển bảng thanh ghi sau thành fact. Chỉ dùng số CÓ TRONG bảng; ô không đọc được "
            "thì bỏ qua, KHÔNG suy đoán.\n"
            + json.dumps(b.get("content"), ensure_ascii=False)[:12_000],
            _SCHEMA_REGTABLE)
        d_bang = _diem_bang(b) / len(COT_THANH_GHI)
        for r in (resp.data.get("registers") or []):
            for f in _fact_tu_reg(r, iri_goc, sid, b, d_bang):
                if f["confidence"] < nguong:
                    thap += 1
                facts.append(f)

    if not facts:
        raise EideError("E5002", f"{len(bang)} bảng dạng thanh ghi nhưng không rút được fact nào",
                        n_tables=len(bang))

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part}@1.0.0", "kind": "chip",
                            "reason": f"extract.pdf_register_map {p.name}",
                            "header": {"name": part, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"], "n_facts": len(facts), "low_confidence": thap}


_SCHEMA_REGTABLE = {
    "type": "object", "required": ["registers"],
    "properties": {"registers": {"type": "array", "items": {
        "type": "object", "required": ["name"],
        "properties": {
            "name": {"type": "string"},
            "peripheral": {"type": "string"},
            "offset": {"type": "string"},
            "reset_value": {"type": "string"},
            "fields": {"type": "array", "items": {
                "type": "object", "required": ["name"],
                "properties": {"name": {"type": "string"}, "bits": {"type": "string"},
                               "access": {"type": "string"},
                               "enum": {"type": "array", "items": {"type": "object"}}}}}}}}},
}


def _diem_bang(b: dict[str, Any]) -> int:
    """Đếm cột nhận ra được ở HÀNG ĐẦU. Cũng dùng làm tử số của `confidence` — một bảng có đủ
    Register/Address/Bit/Reset đáng tin hơn một bảng chỉ có hai cột đoán được."""
    noi = b.get("content") or []
    if not noi or not isinstance(noi[0], list):
        return 0
    dau = " ".join(str(x or "").lower() for x in noi[0])
    return sum(1 for c in COT_THANH_GHI if c in dau)


def _nguong_fact(ctx: Context) -> float:
    g = ctx.extra.get("gate")
    return float(((getattr(g, "config", None) or {}).get("thresholds") or {})
                 .get("fact_silver_auto", 0.85))


def _fact_tu_reg(r: dict[str, Any], goc: str, sid: str, b: dict[str, Any],
                 d_bang: float) -> list[dict[str, Any]]:
    ten = re.sub(r"[^A-Za-z0-9_]+", "", r.get("name") or "")
    if not ten:
        return []
    pe = re.sub(r"[^A-Za-z0-9_]+", "", r.get("peripheral") or "") or "REG"
    iri = f"{goc}/periph:{pe}/reg:{ten}"
    loc = {"page": b.get("page"), "bbox": b.get("bbox")}
    ra: list[dict[str, Any]] = []

    def them(subject: str, vi_tu: str, gt: Any, khop: float) -> None:
        ra.append({"subject": subject, "predicate": vi_tu, "value": gt, "source_id": sid,
                   "locator": loc, "method": "layout_llm", "tier": "silver",
                   "confidence": round(d_bang * khop, 3)})

    if (off := _so(r.get("offset"))) is not None:
        them(iri, "offset", off, 1.0)
    if (rv := _so(r.get("reset_value"))) is not None:
        them(iri, "reset_value", rv, 1.0)
    for f in (r.get("fields") or []):
        fn = re.sub(r"[^A-Za-z0-9_]+", "", f.get("name") or "")
        if not fn:
            continue
        if (dai := _dai_bit(f.get("bits"))) is not None:
            them(f"{iri}/field:{fn}", "bit_range", list(dai), 1.0)
        for e in (f.get("enum") or []):
            if (v := _so(str(e.get("value")))) is not None and e.get("name"):
                # Enum trong PDF hay bị đọc lệch dòng, nên khớp kiểu thấp hơn: nó vẫn vào store
                # nhưng với confidence dưới ngưỡng ⇒ G-FACT hỏi người. Đúng chỗ để hỏi.
                them(f"{iri}/field:{fn}", "enum", {"name": e["name"], "value": v}, 0.8)
    return ra


def _dai_bit(s: str | None) -> tuple[int, int] | None:
    """`[7:4]`, `7:4`, `7-4`, `7` — bốn cách viết cùng một ý, đều gặp trong datasheet thật."""
    if not s:
        return None
    t = str(s).strip().strip("[]")
    if (m := re.fullmatch(r"(\d+)\s*[:\-]\s*(\d+)", t)):
        a, b = int(m.group(1)), int(m.group(2))
        return (min(a, b), max(a, b))
    if (m := re.fullmatch(r"(\d+)", t)):
        return (int(m.group(1)), int(m.group(1)))
    return None


def _gateway(ctx: Context) -> Any:
    gw = ctx.extra.get("gateway")
    if gw is None:
        from eide_core.gateway import Gateway
        gw = Gateway(ledger=ctx.extra.get("ledger"))
    return gw


# ---------------------------------------------------------------- EXTRACT-08 pdf_electrical


@capability("extract.pdf_electrical")
def pdf_electrical(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-08 — CDS-12.2, mức **T2**. ask "Luôn (an toàn)"; tc: "VDD range đúng;
    timing có min/typ/max".

    T2 và "ask luôn" không phải sự thận trọng thừa. Fact `voltage_range` sai là con đường ngắn
    nhất tới một board cháy: tác tử đọc "3,0–3,6 V" thành "3,0–5,6 V" rồi cấu hình nguồn theo
    đó. G-FACT-03 cũng nói riêng về nhóm này ("điện/timing chỉ tự duyệt khi có nguồn thứ hai").

    Đơn vị chuẩn hóa về gốc (V, A, s, Hz) ngay khi rút, dùng chung bảng `DON_VI` với `req.*`:
    hai bảng đơn vị trong một kho là hai bảng sẽ lệch, và lệch đơn vị thì sai một nghìn lần mà
    con số vẫn trông hợp lý.
    """
    root = _root(ctx)
    part = params["part"]
    p = Path(params["file"]).expanduser()
    khoi = pdf_layout({"file": str(p)}, ctx)["blocks"]
    bang = [b for b in khoi if b.get("type") == "table" and _co_dien(b)]
    if not bang:
        raise EideError("E5002", "Không thấy bảng đặc tính điện/timing nào trong tài liệu",
                        n_tables=len([b for b in khoi if b.get("type") == "table"]))

    sid = _bao_dam_source(root, p, "pdf", "silver")
    iri_goc = part if part.startswith("chip:") else f"chip:{part}"
    facts: list[dict[str, Any]] = []
    for b in bang:
        resp = _gateway(ctx).run(
            "librarian",
            "Rút đặc tính điện/timing từ bảng sau. Mỗi mục: tên, min/typ/max, ĐƠN VỊ nguyên văn "
            "như trong bảng. Ô trống để null, KHÔNG suy đoán.\n"
            + json.dumps(b.get("content"), ensure_ascii=False)[:12_000],
            _SCHEMA_DIEN)
        for m in (resp.data.get("params") or []):
            if (f := _fact_dien(m, iri_goc, sid, b)):
                facts.append(f)

    if not facts:
        raise EideError("E5002", f"{len(bang)} bảng đặc tính nhưng không rút được mục nào",
                        n_tables=len(bang))
    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part}@1.0.0", "kind": "chip",
                            "reason": f"extract.pdf_electrical {p.name}",
                            "header": {"name": part, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"]}


_SCHEMA_DIEN = {
    "type": "object", "required": ["params"],
    "properties": {"params": {"type": "array", "items": {
        "type": "object", "required": ["name"],
        "properties": {"name": {"type": "string"}, "symbol": {"type": "string"},
                       "min": {"type": ["number", "null"]}, "typ": {"type": ["number", "null"]},
                       "max": {"type": ["number", "null"]}, "unit": {"type": "string"},
                       "conditions": {"type": "string"}}}}},
}

TU_DIEN = ("voltage", "current", "vdd", "vcc", "supply", "electrical", "absolute maximum",
           "timing", "ac characteristics", "dc characteristics", "temperature")


def _co_dien(b: dict[str, Any]) -> bool:
    noi = b.get("content") or []
    dau = " ".join(str(x or "").lower() for hang in noi[:2] if isinstance(hang, list)
                   for x in hang)
    return any(t in dau for t in TU_DIEN)


def _fact_dien(m: dict[str, Any], goc: str, sid: str, b: dict[str, Any]) -> dict[str, Any] | None:
    from eide.caps.req import DON_VI
    ten = re.sub(r"[^A-Za-z0-9_]+", "", m.get("symbol") or m.get("name") or "")
    if not ten:
        return None
    dv = DON_VI.get((m.get("unit") or "").strip().lower())
    if dv is None:
        return None                      # đơn vị không nhận ra ⇒ không sinh fact, không đoán
    he, dai_luong = dv[1], dv[0]
    gt = {k: (m[k] * he if isinstance(m.get(k), (int, float)) else None)
          for k in ("min", "typ", "max")}
    if all(v is None for v in gt.values()):
        return None
    vi_tu = "voltage_range" if dai_luong == "điện áp" else (
        "timing" if dai_luong == "thời gian" else "other")
    return {"subject": f"{goc}/param:{ten}", "predicate": vi_tu,
            "value": {**gt, "conditions": m.get("conditions")},
            "unit": {"điện áp": "V", "thời gian": "s"}.get(dai_luong, dai_luong),
            "source_id": sid, "locator": {"page": b.get("page"), "bbox": b.get("bbox")},
            "method": "layout_llm", "tier": "silver", "confidence": 0.7}


# ---------------------------------------------------------------- EXTRACT-09 pdf_pinout


# Tên chân. Hẹp có chủ ý: bảng pinout xen lẫn hàng "Reserved", "NC", ghi chú đánh số và cả dòng
# tổng kết. Nhận bừa thì hộ chiếu có một chân tên "Note" và `board.check_pins` đi tìm nó trên
# board thật, rồi báo thiếu một chân chưa bao giờ tồn tại.
RE_CHAN = re.compile(r"(P[A-Z]\d{1,2}|GPIO\d{1,2}|IO\d{1,2})", re.I)
RE_AF = re.compile(r"AF\s*(\d{1,2})", re.I)
RE_GOI = re.compile(r"\b(LQFP|UFQFPN|UFBGA|TFBGA|WLCSP|VFQFPN|QFN|VQFN|TSSOP|SSOP|SOIC|SOP|"
                    r"PDIP|DIP|BGA)[\s-]?(\d{2,3})\b", re.I)

COT_TEN = ("name", "pin name", "signal", "signal name", "pad name", "port", "pin/port")
COT_SO = ("pin", "pin number", "pin no", "pin no.", "no", "no.", "number", "pin#")
COT_KIEU = ("type", "i/o", "i/o type", "pin type", "i/o structure", "structure")

# Hệ số tin cậy theo LOẠI bảng, nhân với tỉ lệ cột đọc được (cùng khuôn `_fact_tu_reg`). Bảng
# chức năng thay thế mang ba mẩu độc lập kiểm chéo được nhau — tên chân, tên hàm, số AF từ vị
# trí cột — nên nó đáng tin hơn hẳn một bảng chỉ liệt kê tên chân với số thứ tự.
CONF_AF = 0.9
CONF_CHAN = 0.75


@capability("extract.pdf_pinout")
def pdf_pinout(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-09 — CDS-12.2; POL-17 G-FACT; DDD-14 Fact. tc: "PB6 có I2C1_SCL AF4".

    **Đường bảng làm bằng MÃ, không gọi mô hình** — đây là chỗ khác `extract.pdf_register_map`
    một cách có chủ ý. Ở bảng thanh ghi, cột "Bits" có mười cách viết nên mô hình là đúng chỗ.
    Ở đây số AF đến từ **vị trí cột** trong bảng "Alternate function mapping" (AF0…AF15): đọc
    chỉ số cột là việc xác định, và chính `tc` của hợp đồng ("AF4") kiểm đúng cái đó. Hỏi mô
    hình một thứ đếm được là mở đường cho nó đếm sai — mà một chân gán nhầm AF không hỏng lúc
    biên dịch, nó hỏng lúc I2C im lặng trên board.

    Hai loại bảng, hai bộ nhận dạng theo TIÊU ĐỀ CỘT, cùng khuôn `_diem_bang`/`COT_THANH_GHI`
    của EXTRACT-07: (a) bảng định nghĩa chân — Pin/Name/Type; (b) bảng chức năng thay thế — hàng
    tiêu đề có `AF0`…`AF15`. Không nhận ra tiêu đề thì **bỏ bảng**, không đoán.

    Hai loại bảng nói về cùng một chân thì ra **một** fact. Hai fact cùng subject + cùng vị từ
    với value khác nhau là một mâu thuẫn tự tạo: G-FACT-04 đưa nó vào hàng đợi hỏi người, cho
    một câu hỏi mà không ai trả lời được vì cả hai đều đúng.

    Đường "hình package (vision)" của bước 1 **chưa hiện thực** — nó cần `extract.ocr`/
    `extract.image_*` (M2, chưa có). Không thấy bảng nào thì E2000 nói thẳng điều đó kèm
    `candidates`, thay vì trả rỗng như thể tài liệu không có pinout. Xem DEV-076.
    """
    root = _root(ctx)
    part = params["part"]
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])

    khoi = pdf_layout({"file": str(p)}, ctx)["blocks"]
    chan: dict[str, dict[str, Any]] = {}
    n_bang = 0
    for b in khoi:
        if b.get("type") != "table":
            continue
        n_bang += 1
        noi = b.get("content") or []
        if not noi or not isinstance(noi[0], list):
            continue
        if (caf := _cot_af(noi[0])):
            _doc_bang_af(noi, caf, b, chan)
        elif (cc := _cot_chan(noi[0])):
            _doc_bang_chan(noi, cc, b, chan)

    if not chan:
        raise EideError(
            "E2000",
            f"Không thấy bảng pinout hay bảng chức năng thay thế nào trong {p.name} "
            f"({n_bang} bảng đã xét). Pinout ở dạng HÌNH gói chip cần đường vision, hiện chưa "
            "có hiện thực (DEV-076)",
            exists=[], missing=["bảng pinout"],
            candidates=["extract.ocr", "extract.image_board"], n_tables=n_bang)

    sid = _bao_dam_source(root, p, "pdf", "silver")
    iri_goc = part if part.startswith("chip:") else f"chip:{part}"
    facts = [_fact_chan(iri_goc, ten, d, sid) for ten, d in sorted(chan.items())]
    if (pk := _fact_goi(khoi, iri_goc, sid)):
        facts.append(pk)

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part}@1.0.0", "kind": "chip",
                            "reason": f"extract.pdf_pinout {p.name}",
                            "header": {"name": part, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"]}


def _cot_af(hang0: list[Any]) -> dict[int, int]:
    """`{chỉ_số_cột: số_AF}` từ hàng tiêu đề. Cần ≥ 2 cột AF: một ô lẻ ghi "AF" ở đâu đó trong
    một bảng khác không làm nên một bảng chức năng thay thế."""
    ra = {i: int(m.group(1)) for i, o in enumerate(hang0)
          if (m := RE_AF.fullmatch(str(o or "").strip()))}
    return ra if len(ra) >= 2 else {}


def _cot_chan(hang0: list[Any]) -> dict[str, int]:
    """`{"ten": i, "kieu": j}` từ hàng tiêu đề. Không có cột TÊN thì không nhận bảng: số thứ tự
    chân mà không có tên chân thì chẳng năng lực nào hạ nguồn tra được gì."""
    o = [str(x or "").strip().lower() for x in hang0]
    ra: dict[str, int] = {}
    for i, t in enumerate(o):
        if "ten" not in ra and t in COT_TEN:
            ra["ten"] = i
        elif "kieu" not in ra and (t in COT_KIEU or t.startswith("i/o")):
            ra["kieu"] = i
        elif "so" not in ra and t in COT_SO:
            ra["so"] = i
    return ra if "ten" in ra else {}


def _ham(o: Any) -> list[str]:
    """Một ô AF thật có thể chứa hai hàm ngăn bằng `/` hay `,`, và ô trống hay được in là `-`.

    Chú thích dạng `(1)` bị cắt TRƯỚC khi lọc ký tự, không sau: lọc trước thì `TIM4_CH1(1)`
    thành `TIM4_CH11` — một tên hàm không tồn tại, trông vẫn hợp lệ.
    """
    t = re.sub(r"\(\d+\)", "", str(o or ""))
    ra = []
    for phan in re.split(r"[/,]", t):
        ten = re.sub(r"[^A-Za-z0-9_]+", "", phan.strip())
        if ten and ten not in ra:
            ra.append(ten)
    return ra


def _hang_af(hang: list[Any], cot_af: dict[int, int]) -> dict[str, int]:
    """`{tên_hàm: số_AF}` cho một hàng — số lấy từ CHỈ SỐ CỘT, không từ tên."""
    ra: dict[str, int] = {}
    for i, so in sorted(cot_af.items()):
        for f in _ham(hang[i] if i < len(hang) else ""):
            ra.setdefault(f, so)
    return ra


def _ten_chan(o: Any) -> str | None:
    m = RE_CHAN.fullmatch(str(o or "").strip())
    return m.group(1).upper() if m else None


def _gom(chan: dict[str, dict[str, Any]], ten: str, b: dict[str, Any], conf: float) -> dict[str, Any]:
    """Một chân = một mục, dù nó xuất hiện trong mấy bảng.

    `locator` theo nguồn có confidence CAO NHẤT chứ không theo bảng gặp trước: người mở fact ra
    kiểm muốn tới thẳng bảng chứa số AF, không tới bảng chỉ ghi tên chân với số thứ tự.
    """
    d = chan.setdefault(ten, {"pin": ten, "functions": [], "af": {}, "confidence": 0.0,
                              "locator": None})
    if conf > d["confidence"]:
        d["confidence"] = conf
        d["locator"] = {"page": b.get("page"), "bbox": b.get("bbox")}
    return d


def _diem_cot(hang0: list[Any], nhan: int) -> float:
    return min(1.0, nhan / max(1, len(hang0)))


def _doc_bang_af(noi: list[list[Any]], cot_af: dict[int, int], b: dict[str, Any],
                 chan: dict[str, dict[str, Any]]) -> None:
    d_bang = _diem_cot(noi[0], len(cot_af) + 1)
    for hang in noi[1:]:
        if not isinstance(hang, list) or not (ten := _ten_chan(hang[0] if hang else "")):
            continue
        af = _hang_af(hang, cot_af)
        if not af:
            continue
        d = _gom(chan, ten, b, round(CONF_AF * d_bang, 3))
        for f, so in af.items():
            d["af"].setdefault(f, so)
        d["functions"] = [f for f, _ in sorted(d["af"].items(), key=lambda kv: (kv[1], kv[0]))]


def _doc_bang_chan(noi: list[list[Any]], cot: dict[str, int], b: dict[str, Any],
                   chan: dict[str, dict[str, Any]]) -> None:
    d_bang = _diem_cot(noi[0], len(cot))
    for hang in noi[1:]:
        if not isinstance(hang, list) or cot["ten"] >= len(hang):
            continue
        if not (ten := _ten_chan(hang[cot["ten"]])):
            continue
        d = _gom(chan, ten, b, round(CONF_CHAN * d_bang, 3))
        i = cot.get("kieu")
        if i is not None and i < len(hang) and (kieu := str(hang[i] or "").strip()):
            d.setdefault("type", kieu)


def _fact_chan(goc: str, ten: str, d: dict[str, Any], sid: str) -> dict[str, Any]:
    gt = {"pin": ten, "functions": d["functions"], "af": d["af"]}
    if d.get("type"):
        gt["type"] = d["type"]
    return {"subject": f"{goc}/pin:{ten}", "predicate": "pin_function", "value": gt,
            "source_id": sid, "locator": d["locator"], "method": "parser", "tier": "silver",
            "confidence": d["confidence"]}


def _fact_goi(khoi: list[dict[str, Any]], goc: str, sid: str) -> dict[str, Any] | None:
    """Fact `package` khi tài liệu nói ĐÚNG MỘT tên vỏ.

    Nhiều tên vỏ khác nhau trong cùng một PDF là chuyện thường (datasheet họ chip phục vụ cả
    LQFP48 lẫn UFQFPN48), và `part` không cho biết bản nào đang cầm. Chọn bừa một cái là quyết
    hộ người dùng chân nào TỒN TẠI trên con chip của họ — nên khi mơ hồ thì không sinh fact.
    """
    thay: dict[str, dict[str, Any]] = {}
    for b in khoi:
        if b.get("type") not in ("text", "heading"):
            continue
        for m in RE_GOI.finditer(str(b.get("content") or "")):
            ten = (m.group(1) + m.group(2)).upper()
            thay.setdefault(ten, {"page": b.get("page"), "bbox": b.get("bbox")})
    if len(thay) != 1:
        return None
    ten, loc = next(iter(thay.items()))
    return {"subject": goc, "predicate": "package",
            "value": {"name": ten, "pins": int(re.sub(r"\D", "", ten))},
            "source_id": sid, "locator": loc, "method": "parser", "tier": "silver",
            "confidence": CONF_CHAN}


# ---------------------------------------------------------------- EXTRACT-10 pdf_errata


RE_REV = re.compile(r"rev\.?\s*([A-Za-z0-9]+)$|^revision\s+([A-Za-z0-9]+)$", re.I)
COT_TIEU_DE_ERRATA = ("errata title", "title", "description", "summary", "errata", "limitation",
                      "designation", "subject")
COT_MUC = ("section", "id", "no", "no.", "num", "number", "ref", "reference")
# Ô "không áp dụng" trong bảng tóm tắt errata. `-` nghĩa là bản silicon ấy đã sửa lỗi này; tính
# nó vào là dán nhãn lỗi cho một con chip không có lỗi ấy.
O_KHONG = ("", "-", "–", "—", "n/a", "na", "no", "fixed", "not applicable", "none")
CONF_ERRATA = 0.8


@capability("extract.pdf_errata")
def pdf_errata(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-10 — CDS-12.2; KAD-07 §5.1 K2′ và §5.2 R1; POL-17 G-FACT; DDD-14 Fact.
    tc: "Errata I2C → fact có rev". Mức T2, ask "Luôn".

    Errata là **lớp phủ K2′** của KAD-07: nó không sửa lõi K2 mà nằm cạnh, ở lớp lưu trữ L-B
    (`fact.layer = "B"`), và mang theo ĐIỀU KIỆN áp dụng. Quy tắc R1 nói thẳng: fact vàng của
    hãng không bao giờ bị ghi đè bởi tầng thấp hơn — lõi giữ nguyên để tái lập. Nên năng lực này
    chỉ THÊM fact, không đụng gì tới fact SVD đã có.

    Một errata không có `rev` là một errata không dùng được: người đọc không biết con chip trên
    bàn mình có dính hay không. Vì thế rev đọc từ **vị trí cột** của bảng tóm tắt ("Rev A",
    "Rev Z"), bằng mã — cùng lý do với số AF ở EXTRACT-09. Mô hình chỉ được hỏi phần văn xuôi:
    mô tả và cách vòng tránh. Mô hình im lặng thì mục errata vẫn vào store với tiêu đề và rev
    (`method: parser`); thiếu workaround là thiếu tiện lợi, thiếu rev là fact vô dụng.

    Mỗi mục errata một `subject` riêng (`…/errata:<mục>`): `passport._gop_mot` gộp theo
    (subject, predicate), nên dồn mọi mục vào một subject sẽ biến mục thứ hai thành `conflict` —
    một xung đột tự tạo, và G-FACT sẽ hỏi người "hai errata này cái nào đúng?" khi cả hai đều
    đúng. Ngoại vi trong `subject` lấy từ chính store chứ không đoán từ tiêu đề: đoán thì một
    dòng "Note on ADC and DMA" sinh ra hai ngoại vi, một trong hai có thể không có trên chip này.

    Cạnh `CONFLICTS_WITH` mà bước 1 nêu **chưa nối được** — xem DEV-077.
    """
    root = _root(ctx)
    part = params["part"]
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])

    khoi = pdf_layout({"file": str(p)}, ctx)["blocks"]
    muc: list[dict[str, Any]] = []
    n_bang = 0
    for b in khoi:
        if b.get("type") != "table":
            continue
        n_bang += 1
        noi = b.get("content") or []
        if noi and isinstance(noi[0], list) and (c := _cot_errata(noi[0])):
            muc += _doc_bang_errata(noi, c, b)

    if not muc:
        raise EideError(
            "E2000",
            f"Không thấy bảng tóm tắt errata nào trong {p.name} ({n_bang} bảng đã xét). "
            "Bảng tóm tắt là nơi DUY NHẤT nói mục errata áp dụng cho bản silicon nào",
            exists=[], missing=["bảng tóm tắt errata"], candidates=["extract.pdf_layout"],
            n_tables=n_bang)

    iri_goc = part if part.startswith("chip:") else f"chip:{part}"
    _van_xuoi_errata(khoi, muc, ctx, _fact_ung_vien(root, iri_goc))
    sid = _bao_dam_source(root, p, "pdf", "silver")
    pe = _ngoai_vi_da_biet(root, iri_goc)
    facts = [_fact_errata(m, iri_goc, pe, sid) for m in muc]

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{part}@1.0.0", "kind": "chip",
                            "reason": f"extract.pdf_errata {p.name}",
                            "header": {"name": part, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"]}


def _cot_errata(hang0: list[Any]) -> dict[str, Any]:
    """`{"tieu_de": i, "muc": j, "rev": {cột: "A"}}`. Không có cột rev thì không phải bảng tóm
    tắt errata — bỏ, không đoán."""
    o = [str(x or "").strip().lower() for x in hang0]
    rev = {i: (m.group(1) or m.group(2)).upper() for i, t in enumerate(o)
           if (m := RE_REV.search(t))}
    if not rev:
        return {}
    ra: dict[str, Any] = {"rev": rev}
    for i, t in enumerate(o):
        if i in rev:
            continue
        if "tieu_de" not in ra and t in COT_TIEU_DE_ERRATA:
            ra["tieu_de"] = i
        elif "muc" not in ra and t in COT_MUC:
            ra["muc"] = i
    return ra if "tieu_de" in ra else {}


def _co_danh_dau(o: Any) -> bool:
    """Bốn cách viết "có" (A, X, x, yes) và năm cách viết "không" — đều gặp trong errata sheet
    thật. Mặc định của ô không nhận ra là CÓ đánh dấu: bỏ sót một errata nguy hiểm hơn là thừa
    một cảnh báo, và người duyệt ở G-FACT còn nhìn thấy nó."""
    return str(o or "").strip().lower() not in O_KHONG


def _doc_bang_errata(noi: list[list[Any]], cot: dict[str, Any],
                     b: dict[str, Any]) -> list[dict[str, Any]]:
    d_bang = min(1.0, (len(cot["rev"]) + len(cot) - 1) / max(1, len(noi[0])))
    ra = []
    for hang in noi[1:]:
        if not isinstance(hang, list) or cot["tieu_de"] >= len(hang):
            continue
        tieu_de = str(hang[cot["tieu_de"]] or "").strip()
        if not tieu_de:
            continue
        rev = [r for i, r in sorted(cot["rev"].items())
               if i < len(hang) and _co_danh_dau(hang[i])]
        i = cot.get("muc")
        ra.append({"title": tieu_de,
                   "section": str(hang[i] or "").strip() if i is not None and i < len(hang) else "",
                   "rev": rev, "locator": {"page": b.get("page"), "bbox": b.get("bbox")},
                   "confidence": round(CONF_ERRATA * d_bang, 3), "method": "parser"})
    return ra


_SCHEMA_ERRATA = {
    "type": "object", "required": ["items"],
    "properties": {"items": {"type": "array", "items": {
        "type": "object", "required": ["title"],
        "properties": {"title": {"type": "string"}, "description": {"type": "string"},
                       "workaround": {"type": "string"}, "silicon": {"type": "string"},
                       # DDD-14 §2 v1.4 (DEV-077): id fact mà mục errata này PHỦ ĐỊNH. Mô hình
                       # CHỌN trong danh sách ứng viên mã đưa cho nó, không tự nghĩ ra id —
                       # `f_` + 16 hex là thứ mô hình sinh ra dễ như sinh một câu.
                       "contradicts": {"type": "array", "items": {"type": "string"}}}}}},
}


def _van_xuoi_errata(khoi: list[dict[str, Any]], muc: list[dict[str, Any]], ctx: Context,
                     ung_vien: list[tuple[str, str, str]] | None = None) -> None:
    """Mô tả, cách vòng tránh và **fact bị phủ định** — ba thứ nằm ở văn xuôi, đúng chỗ của mô
    hình. Ghép theo TIÊU ĐỀ.

    `ung_vien` là danh sách fact hiện hành của con chip (id, subject, predicate). Mô hình CHỌN
    trong đó chứ không tự nghĩ ra id: `f_` + 16 hex là thứ nó sinh ra dễ như sinh một câu, và
    một cạnh CONFLICTS_WITH trỏ vào hư không làm `kg.conflicts` báo xung đột không tra được.
    Không có ứng viên nào thì KHÔNG hỏi — một câu hỏi "cái nào bị phủ định" trên danh sách rỗng
    không có câu trả lời đúng, mà mô hình vẫn sẽ tìm cách trả lời.

    Mô hình không trả gì (hoặc chưa cấu hình) thì các mục vẫn giữ nguyên tiêu đề và rev đọc từ
    bảng: điều kiện áp dụng là phần không được mất, còn workaround thiếu thì người vẫn tra được
    trong PDF gốc nhờ `locator`.
    """
    van = "\n".join(str(b.get("content") or "") for b in khoi
                    if b.get("type") in ("text", "heading"))
    if not van.strip():
        return
    ds = ung_vien or []
    phan_ung_vien = ("\n\nCác fact ứng viên (chỉ chọn id TRONG danh sách này cho `contradicts`; "
                     "không mục nào phủ định fact nào thì để trống):\n"
                     + "\n".join(f"- {fid}: {subj} / {pred}" for fid, subj, pred in ds[:60])
                     ) if ds else ""
    try:
        resp = _gateway(ctx).run(
            "librarian",
            "Rút từng mục errata từ văn bản sau: tiêu đề nguyên văn, mô tả ngắn, cách vòng "
            "tránh (workaround), phiên bản silicon nếu có nêu. KHÔNG suy đoán phiên bản: nếu "
            "văn bản không nói thì bỏ trống.\n" + van[:12_000] + phan_ung_vien,
            _SCHEMA_ERRATA)
    except EideError:
        return
    hop_le = {fid for fid, _s, _p in ds}
    for it in (resp.data.get("items") or []):
        for m in muc:
            if _cung_tieu_de(m["title"], it.get("title") or ""):
                for k in ("description", "workaround", "silicon"):
                    if it.get(k):
                        m[k] = it[k]
                        m["method"] = "layout_llm"
                if (cw := [x for x in (it.get("contradicts") or []) if x in hop_le]):
                    m["conflicts_with"] = cw
                break


def _chuan(s: str) -> list[str]:
    return [t for t in re.split(r"[^a-z0-9]+", str(s).lower()) if t]


def _cung_tieu_de(a: str, b: str) -> bool:
    """Mô hình hay rút gọn tiêu đề ("I2C analog filter may provide wrong value" → "I2C analog
    filter"). So theo TỪ chứ không so chuỗi: chuỗi khác nhau một dấu phẩy là hai mục khác nhau,
    và khi ấy mọi workaround đều rơi mất trong im lặng."""
    x, y = set(_chuan(a)), set(_chuan(b))
    if not x or not y:
        return False
    return len(x & y) / len(x | y) >= 0.6 or x <= y or y <= x


def _fact_ung_vien(root: Path, goc: str) -> list[tuple[str, str, str]]:
    """Fact hiện hành của CHÍNH con chip này — tập mà mô hình được phép chọn trong đó.

    Giới hạn theo `goc` chứ không lấy cả store: một mục errata của STM32F411 không thể phủ định
    một fact của BME280, và đưa thừa vào danh sách chỉ làm mô hình dễ chọn nhầm hơn.
    """
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        return [(r[0], r[1], r[2]) for r in c.execute(
            "SELECT id, subject, predicate FROM fact WHERE subject LIKE ?"
            "   AND predicate != 'other' AND status NOT IN ('superseded','rejected')"
            " ORDER BY subject LIMIT 200", (f"{goc}%",)).fetchall()]


def _ngoai_vi_da_biet(root: Path, goc: str) -> list[str]:
    """Tên ngoại vi mà store ĐÃ có fact — nguồn duy nhất để nối errata vào đúng nút đồ thị."""
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        rows = c.execute("SELECT DISTINCT subject FROM fact WHERE subject LIKE ?",
                         (f"{goc}/periph:%",)).fetchall()
    ra = {str(s).split("/periph:", 1)[1].split("/")[0] for (s,) in rows}
    return sorted(ra, key=len, reverse=True)


def _fact_errata(m: dict[str, Any], goc: str, pe: list[str], sid: str) -> dict[str, Any]:
    tu = set(_chuan(m["title"]))
    duoi = next((x for x in pe if x.lower() in tu), None)
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", m.get("section") or m["title"])[:60].strip("-")
    subject = f"{goc}/periph:{duoi}/errata:{slug}" if duoi else f"{goc}/errata:{slug}"

    dk: dict[str, Any] = {"rev": m["rev"]}
    if m.get("silicon"):
        dk["silicon"] = m["silicon"]
    gt = {"kind": "errata", "title": m["title"], "conditions": dk}
    for k in ("section", "description", "workaround"):
        if m.get(k):
            gt[k] = m[k]
    f = {"subject": subject, "predicate": "other", "value": gt, "source_id": sid,
         "locator": m["locator"], "method": m["method"], "tier": "silver",
         "confidence": m["confidence"], "layer": "B"}
    if m.get("conflicts_with"):
        f["conflicts_with"] = m["conflicts_with"]
    return f


# ---------------------------------------------------------------- EXTRACT-17 bom


DUOI_BOM = {".csv": "csv", ".tsv": "csv", ".xlsx": "xlsx", ".xlsm": "xlsx",
            ".net": "schematic", ".xml": "schematic", ".kicad_sch": "schematic", ".sch": "schematic",
            ".md": "readme", ".txt": "readme", ".rst": "readme",
            ".png": "image", ".jpg": "image", ".jpeg": "image", ".webp": "image"}

# Tên cột của BOM ngoài đời. Khớp theo Ô đã chuẩn hóa, không theo chuỗi con: "Description" chứa
# "ref" nếu so chuỗi con, và khi ấy cột mô tả thành cột tham chiếu.
COT_BOM = {
    "ref": ("ref", "refs", "reference", "references", "designator", "designators", "refdes",
            "ref des", "part reference"),
    "mpn": ("mpn", "manufacturer part number", "mfr part number", "mfg part number",
            "part number", "partnumber", "p/n", "pn", "mfr. no.", "mpn / part number"),
    "value": ("value", "val", "description", "comment", "part"),
    "qty": ("qty", "quantity", "qnty", "count", "amount"),
    "footprint": ("footprint", "package", "case", "pattern"),
}

# Hậu tố đóng gói/băng, CHỈ nhận khi tách bằng dấu — xem `_mpn_goc` và DEV-078.
HAU_TO_GOI = re.compile(r"[-/](TR|T|T&R|R|REEL|CUT|CT|ND|CT-ND|TR-ND|13|E4|G4)$", re.I)


@capability("extract.bom")
def bom(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-17 — CDS-12.2; KAD-07 §5.1 K3/K4; DDD-14 Fact. tc: "BOM 12 linh kiện đúng
    ref/MPN". ask "Mâu thuẫn giữa nguồn"; `undo: supersede_facts`.

    BOM là danh sách **MUA**: một dòng sai gói là một lô hàng không hàn được lên mạch. Đó là lý
    do gộp trùng ở đây theo **MPN đầy đủ** chứ không theo phần gốc — `STM32F411CEU6` (UFQFPN) và
    `STM32F411CET6` (LQFP) là hai mã hàng, dù cùng một die. Phần gốc vẫn được tính và để riêng ở
    `mpn_base` cho `extract.bom_enrich` tra cứu. Khác hợp đồng ở chỗ này: xem [DEV-078].

    Bốn đường vào, mỗi đường dùng lại thứ đã có: `schematic` qua `doc_netlist` (cùng bộ đọc với
    EXTRACT-16), `csv` qua thư viện chuẩn, `xlsx` qua `_xlsx` của EXTRACT-19, `readme` qua mô
    hình — README không có bảng nên đó là chỗ mô hình đúng việc, khác ba đường kia vốn đã có cấu
    trúc. Đường `image` cần `extract.image_board`/`ocr` (M2, chưa hiện thực): [DEV-079].

    Dòng không có MPN vẫn vào BOM nếu có `value` + `footprint` — điện trở 10k/0603 không có MPN
    trong sơ đồ là chuyện bình thường, và bỏ chúng đi thì BOM thiếu quá nửa số dòng. Dòng không
    có cả hai thì vào `unmatched` chứ không bị nuốt: một linh kiện biến mất khỏi BOM là lỗi
    người ta chỉ phát hiện khi hàng về thiếu.
    """
    root = _root(ctx)
    ngts = [Path(s).expanduser() for s in (params["sources"] or [])]
    if not ngts:
        raise EideError("E5002", "`sources` rỗng", n_sources=0)
    thieu = [str(p) for p in ngts if not p.is_file()]
    if thieu:
        raise EideError("E2000", f"Không có tệp: {', '.join(thieu)}",
                        exists=[], candidates=[], missing=thieu)

    dong: list[dict[str, Any]] = []
    chua_khop: list[str] = []
    for p in ngts:
        loai = params.get("kind") or DUOI_BOM.get(p.suffix.lower())
        if loai == "image":
            raise EideError(
                "E2000", f"Đọc BOM từ ảnh ({p.name}) cần đường vision, hiện chưa có hiện thực "
                "(DEV-079)", exists=[], missing=["vision"],
                candidates=["extract.image_board", "extract.ocr"])
        if loai is None:
            chua_khop.append(f"{p.name}: không nhận ra định dạng BOM")
            continue
        d, u = _doc_nguon_bom(p, loai, ctx)
        dong += d
        chua_khop += u

    ds = _gop_bom(dong)
    if not ds:
        raise EideError("E5002", "Không rút được dòng BOM nào từ "
                        f"{len(ngts)} nguồn ({len(chua_khop)} mục không khớp)",
                        n_sources=len(ngts), unmatched=len(chua_khop))

    _ghi_fact_bom(root, ngts[0], ds, ctx)
    return {"bom": ds, "unmatched": chua_khop}


def _doc_nguon_bom(p: Path, loai: str, ctx: Context) -> tuple[list[dict[str, Any]], list[str]]:
    if loai == "schematic":
        return _bom_netlist(p)
    if loai in ("csv", "xlsx"):
        return _bom_bang(p, loai)
    return _bom_readme(p, ctx)


def _bom_netlist(p: Path) -> tuple[list[dict[str, Any]], list[str]]:
    if p.suffix.lower() in DUOI_SCHEMATIC and p.suffix.lower() != ".xml":
        return [], [f"{p.name}: cần `extract.kicad_netlist` xuất netlist trước"]
    try:
        parts, _nets = doc_netlist(p)
    except (ET.ParseError, ValueError) as e:
        return [], [f"{p.name}: không đọc được netlist ({e})"]
    ra, u = [], []
    for i, (ref, c) in enumerate(sorted(parts.items()), 1):
        d = _dong_bom(ref, c.get("mpn"), c.get("value"), c.get("footprint"), None,
                      {"file": p.name, "row": i})
        (ra if d else u).append(d or f"{p.name}:{ref}: không có MPN lẫn value")
    return ra, u


def _bom_bang(p: Path, loai: str) -> tuple[list[dict[str, Any]], list[str]]:
    if loai == "csv":
        import csv as _csv
        hang = [r for r in _csv.reader(p.read_text(encoding="utf-8-sig").splitlines()) if any(r)]
    else:
        hang = [h for k in _xlsx(p) for h in (k.get("content") or [])]
    if not hang:
        return [], [f"{p.name}: không có hàng nào"]

    cot = _cot_bom(hang[0])
    if "ref" not in cot and "mpn" not in cot:
        return [], [f"{p.name}: không nhận ra cột ref lẫn MPN trong tiêu đề {hang[0]}"]

    def o(h: list[Any], k: str) -> str:
        i = cot.get(k)
        return str(h[i]).strip() if i is not None and i < len(h) else ""

    ra, u = [], []
    for i, h in enumerate(hang[1:], 2):
        d = _dong_bom(o(h, "ref"), o(h, "mpn"), o(h, "value"), o(h, "footprint"),
                      _so(o(h, "qty")), {"file": p.name, "row": i})
        (ra if d else u).append(d or f"{p.name}:{i}: {o(h, 'ref') or 'dòng'} không có MPN lẫn value")
    return ra, u


_SCHEMA_BOM = {
    "type": "object", "required": ["items"],
    "properties": {"items": {"type": "array", "items": {
        "type": "object", "required": ["mpn"],
        "properties": {"mpn": {"type": "string"}, "ref": {"type": "string"},
                       "value": {"type": "string"}, "qty": {"type": ["number", "null"]}}}}},
}


def _bom_readme(p: Path, ctx: Context) -> tuple[list[dict[str, Any]], list[str]]:
    resp = _gateway(ctx).run(
        "librarian",
        "Liệt kê linh kiện phần cứng nhắc tới trong văn bản sau: mã linh kiện (mpn), số lượng "
        "nếu có nêu, ký hiệu trên sơ đồ nếu có. Chỉ lấy thứ CÓ trong văn bản, không suy đoán "
        "linh kiện phụ trợ.\n" + p.read_text(encoding="utf-8", errors="replace")[:12_000],
        _SCHEMA_BOM)
    ra, u = [], []
    for i, it in enumerate((resp.data.get("items") or []), 1):
        d = _dong_bom(it.get("ref") or "", it.get("mpn"), it.get("value"), None,
                      _so(str(it.get("qty") or "")), {"file": p.name, "row": i})
        (ra if d else u).append(d or f"{p.name}: mục {i} không có MPN")
    return ra, u


def _cot_bom(hang0: list[Any]) -> dict[str, int]:
    """`{vai_trò: chỉ_số_cột}` từ hàng tiêu đề. Khớp theo Ô đã chuẩn hóa (bỏ dấu câu, gộp khoảng
    trắng) chứ không theo chuỗi con: "Description" chứa "ref" nếu so chuỗi con, và khi ấy cột mô
    tả thành cột tham chiếu — rồi mọi dòng BOM mang một `ref` là cả một câu."""
    ra: dict[str, int] = {}
    for i, x in enumerate(hang0):
        t = re.sub(r"\s+", " ", str(x or "").strip().lower())
        for vai, ten in COT_BOM.items():
            if vai not in ra and t in ten:
                ra[vai] = i
                break
    return ra


def _dong_bom(ref: Any, mpn: Any, gia_tri: Any, footprint: Any, qty: int | None,
              loc: dict[str, Any]) -> dict[str, Any] | None:
    """Một ô `ref` có thể chứa nhiều ký hiệu ("R3,R4") — đó là cách viết BOM đã gộp sẵn."""
    refs = [t for t in re.split(r"[,;/\s]+", str(ref or "").strip()) if t]
    mpn, gia_tri = str(mpn or "").strip(), str(gia_tri or "").strip()
    fp = str(footprint or "").strip()
    if not mpn and not gia_tri:
        return None
    return {"ref": refs, "mpn": mpn, "value": gia_tri, "footprint": fp,
            "qty": qty, "source_locator": {**loc, "also": []}}


def _mpn_goc(mpn: str) -> str:
    """Bỏ hậu tố đóng gói/băng — CHỈ khi nó tách bằng dấu.

    `LM358DR2G` có `G` là mã mạ chân, nhưng cắt nó thì cũng cắt chữ cái cuối của bất kỳ mã hàng
    nào kết thúc bằng G, và một MPN cắt cụt tra ra linh kiện khác hoặc không ra gì. Dấu `-` là
    thứ duy nhất phân biệt được "hậu tố" với "phần mã hàng" mà không cần một bảng mã của từng
    nhà sản xuất.
    """
    return HAU_TO_GOI.sub("", str(mpn or "").strip())


def _gop_bom(dong: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Gộp theo MPN đầy đủ; không có MPN thì theo (value, footprint).

    `qty` = số ký hiệu DUY NHẤT, không phải tổng các cột qty: cùng một linh kiện xuất hiện ở hai
    nguồn (sơ đồ và bảng mua hàng) là hai lần MÔ TẢ, không phải hai con hàng. Chỉ khi không nguồn
    nào cho ký hiệu — README nói "hai driver A4988" — mới dùng số lượng khai báo.
    """
    gom: dict[tuple[str, str], dict[str, Any]] = {}
    for d in dong:
        khoa = (d["mpn"].upper(), "") if d["mpn"] else ("", f"{d['value']}|{d['footprint']}".upper())
        if (cu := gom.get(khoa)) is None:
            gom[khoa] = dict(d, ref=list(d["ref"]))
            continue
        for r in d["ref"]:
            if r not in cu["ref"]:
                cu["ref"].append(r)
        cu["source_locator"]["also"].append({k: v for k, v in d["source_locator"].items()
                                             if k != "also"})
        for k in ("value", "footprint"):
            cu[k] = cu[k] or d[k]
        if d["qty"] and not cu["qty"]:
            cu["qty"] = d["qty"]

    ra = []
    for d in gom.values():
        d["qty"] = len(d["ref"]) or d["qty"] or 1
        d["mpn_base"] = _mpn_goc(d["mpn"])
        ra.append(d)
    return ra


def _ghi_fact_bom(root: Path, goc: Path, ds: list[dict[str, Any]], ctx: Context) -> None:
    """`undo: supersede_facts` chỉ có nghĩa nếu có fact để thay.

    IRI `board:<tên>/part:<ref>` — CÙNG chỗ mà `extract.kicad_netlist` ghi `package`, nên hai
    nguồn nói về một linh kiện gặp nhau ở một nút thay vì hai. Dòng không có ký hiệu (đến từ
    README) không sinh fact: không có `ref` thì không có chỗ nào trên bản vẽ để gắn nó vào, và
    một fact `board:…/part:` rỗng là một nút không ai tra được.
    """
    sid = _bao_dam_source(root, goc, "bom", "silver")
    bid = f"board:{re.sub(r'[^A-Za-z0-9_.-]+', '-', goc.stem).lower()}"
    facts = [{"subject": f"{bid}/part:{r}", "predicate": "other",
              "value": {"kind": "bom", "mpn": d["mpn"], "value": d["value"],
                        "footprint": d["footprint"], "qty": d["qty"]},
              "source_id": sid, "locator": d["source_locator"], "method": "parser",
              "tier": "silver", "confidence": 1.0}
             for d in ds for r in d["ref"]]
    if not facts:
        return
    from eide.caps.passport import import_
    import_({"batch": {"facts": facts, "passport_id": f"{bid.split(':', 1)[1]}@1.0.0",
                       "kind": "board", "reason": f"extract.bom {goc.name}",
                       "header": {"name": goc.stem, "source": goc.name}},
             "actor": ctx.actor}, ctx)


# ---------------------------------------------------------------- EXTRACT-11 pdf_formula


_SCHEMA_SKILL = {
    "type": "object", "required": ["title", "code_c"],
    "properties": {"title": {"type": "string"}, "summary": {"type": "string"},
                   "code_c": {"type": "string"},
                   "notes": {"type": "array", "items": {"type": "string"}}},
}

EIDE_DIR = ".eide"
THU_MUC_SKILL = "skills"


@capability("extract.pdf_formula")
def pdf_formula(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-11 — CDS-12.2; KAD-07 §5.1 K5 (kỹ năng và thủ tục) và §5.3 E6 (skill là
    Markdown ≤ 600 token, front-matter `applies_to`). tc: "skill có mã C tham chiếu và trang";
    `undo: delete_created_files`.

    **"Không thành fact"** — bước 1 nói thẳng, và đó là ranh giới quan trọng nhất ở đây. Công
    thức bù nhiệt của một cảm biến không phải fact phần cứng: nó là một THỦ TỤC. Một fact có
    `subject` để tra và một giá trị để đối chiếu; một đoạn thuật toán thì không, nên nhét nó vào
    bảng `fact` là làm hỏng chính thứ khiến bảng ấy có ích. Nó thành **K5 — skill dự án**.

    Chỉ đưa cho mô hình ĐÚNG MỤC được nêu, không đưa cả tài liệu: một skill "bù nhiệt" viết từ
    chương đặt hàng trông vẫn rất thuyết phục, và không ai đọc lại một skill để kiểm.

    Cùng `(part, section)` ghi đè cùng một tệp. Sinh `…-2.md` mỗi lần chạy lại thì thư mục skill
    đầy những bản gần giống nhau và không ai biết bản nào đang được nạp vào ngữ cảnh.
    """
    root = _root(ctx)
    part, muc = params["part"], params["section"]
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])

    khoi = pdf_layout({"file": str(p)}, ctx)["blocks"]
    phan, trang = _khoi_cua_muc(khoi, muc)
    if not phan:
        raise EideError("E2000", f"Không thấy mục `{muc}` trong {p.name}. Không đưa cả tài liệu "
                        "cho mô hình: một thủ tục viết từ nhầm chương vẫn trông thuyết phục",
                        exists=[str(x.get("content") or "") for x in _tieu_de(khoi)][:20],
                        candidates=["extract.pdf_layout"], missing=[muc])

    resp = _gateway(ctx).run(
        "librarian",
        f"Rút công thức/thuật toán trong mục dưới đây thành một kỹ năng dùng được: tiêu đề, tóm "
        f"tắt ngắn, và HÀM C hoàn chỉnh hiện thực đúng công thức ấy (kiểu dữ liệu rõ ràng, không "
        f"phụ thuộc thư viện ngoài). Chỉ dùng công thức CÓ trong văn bản. Ngắn gọn — cả skill "
        f"dưới 600 token.\n\n### {muc}\n" + "\n".join(phan)[:12_000],
        _SCHEMA_SKILL)

    ma = str(resp.data.get("code_c") or "").strip()
    if not ma:
        raise EideError("E5002", f"Mô hình không trả mã C cho mục `{muc}` — một skill không có "
                        "mã thì `code.generate_module` không có gì để chép và người đọc vẫn phải "
                        "mở datasheet (DEV-080)", section=muc)

    sp = _ghi_skill(root, part, muc, resp.data, ma, p, trang)
    if (led := ctx.extra.get("ledger")) is not None:
        led.append("undo.register", {"undo_ref": f"skill:{sp.name}",
                                     "kind": "delete_created_files", "deadline": ""})
    return {"skill_path": str(sp)}


def _tieu_de(khoi: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [b for b in khoi if b.get("type") == "heading"]


def _khoi_cua_muc(khoi: list[dict[str, Any]], muc: str) -> tuple[list[str], list[int]]:
    """Văn bản từ tiêu đề khớp `muc` tới tiêu đề kế tiếp, kèm các trang nó trải qua.

    Cắt theo tiêu đề chứ không theo số trang: một mục có thể bắt đầu giữa trang, và lấy trọn
    trang thì nửa đầu là phần cuối của mục trước — mà mô hình không có cách nào biết điều đó.
    """
    dau = None
    for i, b in enumerate(khoi):
        if b.get("type") == "heading" and _chuan_khop(muc, str(b.get("content") or "")):
            dau = i
            break
    if dau is None:
        return [], []

    van, trang = [], []
    for b in khoi[dau:]:
        if b is not khoi[dau] and b.get("type") == "heading":
            break
        van.append(str(b.get("content") or ""))
        if (t := b.get("page")) and t not in trang:
            trang.append(t)
    return van, trang


def _chuan_khop(muc: str, tieu_de: str) -> bool:
    """Tiêu đề trong PDF mang số mục ("4.2.3 Temperature compensation") còn bên gọi thường chỉ
    nêu tên. So theo TỪ để số mục không làm hỏng phép khớp."""
    a, b = set(_chuan(muc)), set(_chuan(tieu_de))
    return bool(a) and a <= b


def _ghi_skill(root: Path, part: str, muc: str, d: dict[str, Any], ma: str, nguon: Path,
               trang: list[int]) -> Path:
    import yaml
    thu_muc = root / EIDE_DIR / THU_MUC_SKILL
    thu_muc.mkdir(parents=True, exist_ok=True)
    ten = re.sub(r"[^a-z0-9]+", "-", f"{part}-{muc}".lower()).strip("-")[:80]
    sp = thu_muc / f"{ten}.md"

    fm = yaml.safe_dump({
        "title": d.get("title") or muc,
        "applies_to": [part if part.startswith("chip:") else f"chip:{part}"],
        "kind": "skill",
        "source": {"file": nguon.name, "section": muc, "pages": trang or [1]},
    }, allow_unicode=True, sort_keys=False).strip()

    ghi_chu = "".join(f"- {x}\n" for x in (d.get("notes") or []))
    trang_txt = ", ".join(f"trang {t}" for t in (trang or [1]))
    sp.write_text(
        f"---\n{fm}\n---\n\n# {d.get('title') or muc}\n\n{d.get('summary') or ''}\n\n"
        f"```c\n{ma}\n```\n\n"
        + (f"## Lưu ý\n\n{ghi_chu}\n" if ghi_chu else "")
        + f"## Nguồn\n\n`{nguon.name}` — mục *{muc}*, {trang_txt}.\n",
        encoding="utf-8")
    return sp


# ---------------------------------------------------------------- EXTRACT-18 bom_enrich


@capability("extract.bom_enrich")
def bom_enrich(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-18 — CDS-12.2; SEARCH-01/02 (chuỗi giảm cấp), KG-08 (`kg.request`);
    TGT-19 §8 bảng nguồn hãng. tc: "A4988 gắn datasheet Allegro". `undo: none`.

    Một BOM chỉ có mã hàng thì mua được nhưng không lập trình được. Bước này nối mỗi dòng với hộ
    chiếu đã có hoặc với datasheet của hãng — và cái gì không tra ra thì thành một
    `AcquisitionRequest` CÓ TÊN trong hàng đợi, chứ không phải một dòng lặng lẽ thiếu nguồn.

    **Hộ chiếu trong store thắng mọi ứng viên tải về**: nó đã qua G-FACT, còn ứng viên mới chỉ là
    một URL chưa ai mở. Chỉ khi không có hộ chiếu mới đi tra.

    Tra theo `mpn_base` chứ không theo mã đầy đủ: URL của hãng lập theo mã gốc — `A4988SETTR-T`
    không có trang riêng, `A4988` thì có. Đây là lý do EXTRACT-17 giữ `mpn_base` lại sau khi gộp
    ([DEV-078]).

    Chuỗi giảm cấp của bước 1 là `search.registry → search.vendor → web`. `search.registry`
    thuộc mốc **M4** (chưa hiện thực), nên hiện chuỗi bắt đầu từ `search.vendor`; thứ tự giữ
    nguyên để khi registry có thì chỉ cần chèn vào đầu. `search.web` chỉ chạy khi đã cấu hình
    nhà cung cấp — chưa cấu hình thì nó ném E4001 và ta đi tiếp xuống `kg.request`, vì thiếu một
    khoá tìm kiếm không phải lý do để cả BOM hỏng.

    Dòng không có MPN (điện trở 10k/0603) KHÔNG sinh yêu cầu: không có gì để đi tìm, và làm ngập
    hàng đợi của người bằng những việc không ai làm được là cách nhanh nhất để họ thôi đọc nó.
    """
    from eide.caps.kg import request as kg_request
    from eide.caps.search import vendor, web

    root = _root(ctx)
    ra: list[dict[str, Any]] = []
    yeu_cau: list[str] = []
    for d in (params["bom"] or []):
        d = dict(d)
        ma = str(d.get("mpn_base") or d.get("mpn") or "").strip()
        if not ma:
            ra.append(d)
            continue

        if (pid := _ho_chieu_khop(root, ma)):
            d["passport"] = pid
        elif (ung := _ung_vien_datasheet(ma, ctx, vendor, web)):
            d["datasheet"] = ung
        elif not _da_yeu_cau(root, ma):
            d["request_id"] = kg_request(
                {"need": f"datasheet hoặc hộ chiếu cho {ma}", "part": ma}, ctx)["request_id"]
            yeu_cau.append(d["request_id"])
        ra.append(d)
    return {"bom": ra, "requests": yeu_cau}


def _ho_chieu_khop(root: Path, ma: str) -> str | None:
    """Hộ chiếu có id dạng `<tên>@<phiên bản>`. So theo phần tên, không phân biệt hoa thường."""
    db = store.store_path(root)
    if not db.exists():
        return None
    with store.open_store(db) as c:
        rows = c.execute("SELECT id FROM passport").fetchall()
    ten = ma.lower()
    for (pid,) in rows:
        goc = str(pid).split("@", 1)[0].lower()
        if goc == ten or ten.startswith(goc):
            return pid
    return None


def _ung_vien_datasheet(ma: str, ctx: Context, vendor: Any, web: Any) -> dict[str, Any] | None:
    """Ứng viên PDF đầu tiên từ hãng; không có thì thử web. Chỉ LIỆT KÊ, không tải — `search.fetch`
    mới là chỗ đi qua cổng G-SRC."""
    for goi, kwargs in ((vendor, {"part": ma}), (web, {"query": f"{ma} datasheet"})):
        try:
            kq = goi(kwargs, ctx)
        except EideError:
            continue                      # chưa cấu hình nhà cung cấp tìm kiếm: đi tiếp
        for u in (kq.get("candidates") or []):
            if str(u.get("kind") or "").lower() in ("pdf", "datasheet", "doc"):
                return u
    return None


def _da_yeu_cau(root: Path, ma: str) -> bool:
    """Một MPN chỉ cần một yêu cầu. Chạy lại `bom_enrich` sau khi thêm một dòng là chuyện thường,
    và mở thêm một yêu cầu trùng mỗi lần thì hàng đợi "chờ anh" thành danh sách không ai đọc."""
    db = store.store_path(root)
    if not db.exists():
        return False
    with store.open_store(db) as c:
        return c.execute("SELECT 1 FROM acq_request WHERE part=? AND state NOT IN"
                         " ('CLOSED','REJECTED') LIMIT 1", (ma,)).fetchone() is not None


# ---------------------------------------------------------------- EXTRACT-05 dt_binding


@capability("extract.dt_binding")
def dt_binding(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-05 — CDS-12.2; KAD-07 §5.1 K4 (ngoại vi ngoài, tầng bạc) và §6.1 (subject
    IRI `<ns.part>`); DDD-14 Fact. tc: "Thuộc tính required đúng".

    Binding device tree là hộ chiếu của một **ngoại vi ngoài**: nó nói con BME280 cần khai những
    thuộc tính nào, và thiếu một thuộc tính bắt buộc thì bản dựng Zephyr đỏ ở chỗ chẳng liên quan
    gì tới nó. Parser thuần, không mô hình: YAML đã có cấu trúc, hỏi mô hình một cây đã phân tích
    được là thêm một chỗ để sai.

    **Hai định dạng, cùng một ý.** Zephyr đặt `required: true` TRONG từng thuộc tính; dt-schema
    của Linux đặt `required:` thành một DANH SÁCH ở cấp cao. Đọc được một mà không đọc được cái
    kia thì năng lực chỉ dùng cho nửa số binding ngoài đời.

    `compatible: "bosch,bme280"` → IRI `chip:bosch.bme280`, đúng khuôn `<ns.part>` của KAD-07
    §6.1. Giữ nguyên dấu phẩy thì cùng một cảm biến có hai IRI khác nhau tuỳ nó được nạp từ
    binding hay từ datasheet, và không truy vấn nào nối được hai bên.

    Tầng **bạc** theo KAD-07 §5.1: binding do cộng đồng/hệ điều hành soạn, không phải tài liệu
    hãng — nên nó qua G-FACT chứ không tự duyệt như SVD.
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])

    import yaml
    try:
        d = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    except (yaml.YAMLError, UnicodeDecodeError) as e:
        raise EideError("E4004", f"Không đọc được binding {p.name}: {e}", file=str(p)) from e
    if not isinstance(d, dict):
        raise EideError("E4004", f"Binding {p.name} không phải một ánh xạ YAML", file=str(p))

    props = d.get("properties") if isinstance(d.get("properties"), dict) else {}
    if not (compat := _compatible(d, props)):
        raise EideError("E2000", f"Binding {p.name} không có `compatible` — không biết nó nói về "
                        "thiết bị nào, và một fact không có chủ thể thì không tra được bằng gì",
                        exists=[], candidates=[], missing=["compatible"])

    bat_buoc = {str(x) for x in (d.get("required") or []) if isinstance(d.get("required"), list)}
    sid = _bao_dam_source(root, p, "binding", "silver")
    goc = f"chip:{compat}"
    facts = [f for ten, dac in props.items()
             if (f := _fact_dtprop(str(ten), dac, goc, sid, bat_buoc, p))]
    if not facts:
        raise EideError("E2000", f"Binding {p.name} không khai thuộc tính nào",
                        exists=[], candidates=[], missing=["properties"])

    from eide.caps.passport import import_
    kq = import_({"batch": {"facts": facts, "passport_id": f"{compat}@1.0.0", "kind": "chip",
                            "reason": f"extract.dt_binding {p.name}",
                            "header": {"name": compat, "source": p.name}},
                  "actor": ctx.actor}, ctx)
    return {"batch_id": kq["batch_id"]}


def _compatible(d: dict[str, Any], props: dict[str, Any]) -> str:
    """Zephyr khai `compatible` ở cấp cao; dt-schema của Linux giấu nó trong
    `properties.compatible.enum|const`. Chuẩn hóa `bosch,bme280` → `bosch.bme280`."""
    x = d.get("compatible")
    if not x:
        c = props.get("compatible") or {}
        x = (c.get("const") if isinstance(c, dict) else None) or \
            (next(iter(c.get("enum") or []), None) if isinstance(c, dict) else None)
    if isinstance(x, list):
        x = next(iter(x), None)
    ten = str(x or "").strip().strip('"')
    return ten.replace(",", ".") if ten else ""


def _fact_dtprop(ten: str, dac: Any, goc: str, sid: str, bat_buoc: set[str],
                 p: Path) -> dict[str, Any] | None:
    """`compatible` không thành fact riêng: nó LÀ chủ thể, không phải một thuộc tính của chủ thể."""
    if ten == "compatible":
        return None
    dac = dac if isinstance(dac, dict) else {}
    gt: dict[str, Any] = {"name": ten, "required": bool(dac.get("required")) or ten in bat_buoc}
    for k, khoa in (("type", "type"), ("enum", "enum"), ("description", "description"),
                    ("const", "const"), ("default", "default")):
        if dac.get(k) is not None:
            gt[khoa] = dac[k]
    return {"subject": f"{goc}/dtprop:{ten}", "predicate": "other", "value": gt,
            "source_id": sid, "locator": {"file": p.name}, "method": "parser",
            "tier": "silver", "confidence": 1.0}


# ---------------------------------------------------------------- EXTRACT-20 readme_goal


_SCHEMA_GOAL = {
    "type": "object", "required": ["goal", "features"],
    "properties": {
        "goal": {"type": "string"},
        "features": {"type": "array", "items": {
            "type": "object", "required": ["title", "expectation"],
            "properties": {
                "title": {"type": "string"},
                "expectation": {
                    "type": "object", "required": ["kind", "detail"],
                    "properties": {"kind": {"type": "string"}, "detail": {"type": "string"}}},
                "priority_guess": {"type": "string"}}}},
        "bom_hints": {"type": "array", "items": {"type": "string"}},
    },
}


@capability("extract.readme_goal")
def readme_goal(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-20 — CDS-12.2; Z-07 bước `req.elicit(README)`; PLAN-01 (kỳ vọng quan sát
    được). tc: "Z-07 sinh F-01…F-08". R0, `undo: none`.

    README là thứ đầu tiên đọc được trong một zip dự án lạ, và nó nói điều mà không tệp SVD nào
    nói: dự án này ĐỂ LÀM GÌ. Nhưng nó là **ý định của người viết**, không phải fact phần cứng —
    nên năng lực này không ghi gì vào store và không có gì để hoàn tác. Nó đề xuất; `passport`
    khẳng định; `plan.define_feature` cấp id F-nn và ghi FEATURES.json.

    Kỳ vọng của mỗi feature bị lọc theo `plan.DANG_KY_VONG` NGAY TẠI ĐÂY, dùng chung hằng số với
    PLAN-01 chứ không chép lại: mô hình rất sẵn lòng viết một câu nghe như đo được mà không đo
    được ("robot chạy mượt"). Giữ nó lại thì `plan.define_feature` mới là chỗ nổ — xa chỗ sai, và
    người đọc lỗi ở đó không biết nó đến từ một dòng trong README.

    "5–10 Feature" của bước 1 đi vào PROMPT, không thành bộ cắt ở đầu ra: một README liệt kê 14
    tính năng thì cắt còn 10 là im lặng đánh rơi bốn cái, và bịa thêm cho đủ 5 còn tệ hơn.
    """
    from eide.caps.plan import DANG_KY_VONG

    text = str(params["text"] or "").strip()
    if not text:
        raise EideError("E5002", "README rỗng: không có gì để đọc. Không hỏi mô hình vì nó sẽ "
                        "bịa ra một dự án, và bịa có sức thuyết phục khi không có gì đối chiếu",
                        reason="empty_text")

    resp = _gateway(ctx).run(
        "librarian",
        "Đọc README sau và trả về: mục tiêu dự án một câu; 5–10 tính năng, MỖI tính năng kèm "
        "kỳ vọng quan sát được bằng máy — `kind` phải là một trong "
        f"{list(DANG_KY_VONG)} và `detail` là mẫu chuỗi/thanh ghi/phép đo cụ thể; danh sách tên "
        "linh kiện nhắc tới. Chỉ dùng thông tin CÓ trong văn bản.\n" + text[:12_000],
        _SCHEMA_GOAL)

    goal = str(resp.data.get("goal") or "").strip()
    feats = [f for f in (resp.data.get("features") or [])
             if (f.get("expectation") or {}).get("kind") in DANG_KY_VONG]
    if not goal or not feats:
        raise EideError("E5002", "Không rút được mục tiêu hoặc tính năng nào có kỳ vọng quan sát "
                        f"được từ README ({len(resp.data.get('features') or [])} đề xuất, "
                        f"{len(feats)} đạt)", n_features=len(feats))

    return {"goal": goal, "features": feats, "bom_hints": _bo_trung(resp.data.get("bom_hints"))}


def _bo_trung(xs: Any) -> list[str]:
    """Giữ THỨ TỰ xuất hiện. `bom_hints` đi thẳng vào `extract.bom` làm gợi ý tra cứu, và trùng
    lặp ở đó thành hai dòng BOM cho cùng một linh kiện."""
    ra: list[str] = []
    for x in (xs or []):
        t = str(x).strip()
        if t and t not in ra:
            ra.append(t)
    return ra


# ---------------------------------------------------------------- EXTRACT-19 office


@capability("extract.office")
def office(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-19 — CDS-12.2. tc: "Bảng trong docx thành block table".

    Trả cùng dạng khối như `extract.pdf_layout` — `page/bbox/type/content` — dù docx và xlsx
    không có trang lẫn tọa độ. Cố ý: `extract.pdf_register_map` nhận `blocks` bất kể chúng từ
    đâu, nên một bảng thanh ghi người ta dán vào Word cũng dùng được đúng đường ấy. Hai dạng
    khối khác nhau thì phải có hai nhánh xử lý, và nhánh thứ hai sẽ không bao giờ được kiểm kỹ
    bằng nhánh thứ nhất.

    `locator` thay bbox bằng chỉ số đoạn/ô — đúng thứ DDD-14 §2 Fact cho phép: "JSON
    {page,bbox,xpath,line}".
    """
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])
    duoi = p.suffix.lower()
    if duoi == ".docx":
        return {"blocks": _docx(p)}
    if duoi in (".xlsx", ".xlsm"):
        return {"blocks": _xlsx(p)}
    if duoi in (".md", ".markdown", ".txt"):
        return {"blocks": _markdown(p)}
    if duoi in (".html", ".htm"):
        return {"blocks": _html(p)}
    raise EideError("E1000", f"extract.office không đọc được {duoi} — nhận .docx/.xlsx/.md/.html",
                    file=str(p))


def _khoi(i: int, loai: str, noi: Any, **loc: Any) -> dict[str, Any]:
    return {"page": None, "bbox": None, "type": loai, "content": noi,
            "locator": {"index": i, **loc}}


def _docx(p: Path) -> list[dict[str, Any]]:
    try:
        import docx
    except ImportError as e:
        raise EideError("E4001", "Cần `python-docx` để đọc .docx — `pip install python-docx`",
                        tool="python-docx", package="python-docx") from e
    d = docx.Document(str(p))
    ra = []
    for i, para in enumerate(d.paragraphs):
        t = para.text.strip()
        if not t:
            continue
        # Kiểu đoạn nói thẳng đây là tiêu đề — chính xác hơn hẳn việc đoán theo cỡ chữ như ở
        # PDF, vì Word lưu ý định của người viết chứ không chỉ lưu hình dạng.
        loai = "heading" if para.style.name.lower().startswith("heading") else "text"
        ra.append(_khoi(i, loai, t, paragraph=i, style=para.style.name))
    for j, tb in enumerate(d.tables):
        ra.append(_khoi(len(d.paragraphs) + j, "table",
                        [[o.text.strip() for o in hang.cells] for hang in tb.rows], table=j))
    return ra


def _xlsx(p: Path) -> list[dict[str, Any]]:
    from openpyxl import load_workbook
    wb = load_workbook(p, data_only=True)
    ra = []
    for j, ws in enumerate(wb.worksheets):
        hang = [[("" if o is None else str(o)) for o in r]
                for r in ws.iter_rows(values_only=True)]
        hang = [r for r in hang if any(x.strip() for x in r)]
        if hang:
            ra.append(_khoi(j, "table", hang, sheet=ws.title))
    return ra


def _markdown(p: Path) -> list[dict[str, Any]]:
    """Bảng Markdown nhận theo dấu `|` và dòng phân cách — không dùng thư viện.

    Thêm một thư viện Markdown cho đúng một việc này là thêm một phụ thuộc để đọc một định dạng
    mà phần cần dùng chỉ có ba dòng cú pháp.
    """
    ra: list[dict[str, Any]] = []
    dong = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    i = 0
    while i < len(dong):
        d = dong[i].strip()
        if d.startswith("#"):
            ra.append(_khoi(i, "heading", d.lstrip("#").strip(), line=i + 1))
        elif d.startswith("|") and i + 1 < len(dong) and re.match(r"^\s*\|[\s:|-]+\|\s*$",
                                                                 dong[i + 1]):
            bang, j = [], i
            while j < len(dong) and dong[j].strip().startswith("|"):
                if not re.match(r"^\s*\|[\s:|-]+\|\s*$", dong[j]):
                    bang.append([o.strip() for o in dong[j].strip().strip("|").split("|")])
                j += 1
            ra.append(_khoi(i, "table", bang, line=i + 1))
            i = j
            continue
        elif d:
            ra.append(_khoi(i, "text", d, line=i + 1))
        i += 1
    return ra


def _html(p: Path) -> list[dict[str, Any]]:
    from html.parser import HTMLParser

    class _P(HTMLParser):
        def __init__(self) -> None:
            super().__init__()
            self.ra: list[dict[str, Any]] = []
            self.bang: list[list[str]] | None = None
            self.hang: list[str] | None = None
            self.o: list[str] | None = None
            self.the = ""

        def handle_starttag(self, tag: str, attrs: Any) -> None:
            self.the = tag
            if tag == "table":
                self.bang = []
            elif tag == "tr" and self.bang is not None:
                self.hang = []
            elif tag in ("td", "th") and self.hang is not None:
                self.o = []

        def handle_endtag(self, tag: str) -> None:
            if tag in ("td", "th") and self.o is not None and self.hang is not None:
                self.hang.append(" ".join(self.o).strip())
                self.o = None
            elif tag == "tr" and self.hang is not None and self.bang is not None:
                self.bang.append(self.hang)
                self.hang = None
            elif tag == "table" and self.bang is not None:
                self.ra.append(_khoi(len(self.ra), "table", self.bang))
                self.bang = None
            self.the = ""

        def handle_data(self, data: str) -> None:
            t = data.strip()
            if not t:
                return
            if self.o is not None:
                self.o.append(t)
            elif self.bang is None:
                loai = "heading" if self.the in ("h1", "h2", "h3", "h4") else "text"
                if self.the not in ("script", "style"):
                    self.ra.append(_khoi(len(self.ra), loai, t))

    pr = _P()
    pr.feed(p.read_text(encoding="utf-8", errors="ignore"))
    return pr.ra


# ================================================================ EXTRACT-16 kicad_netlist

# Netlist KiCad có hai dạng máy đọc được, và cả hai đều dùng được mà KHÔNG cần `kicad-cli`:
#   .net  s-expression  (export (components (comp (ref "U1") …)) (nets (net …)))
#   .xml  kicadxml      cùng cấu trúc, thẻ XML
# `kicad-cli` chỉ cần khi đầu vào là `.kicad_sch` — tức sơ đồ nguồn chưa xuất netlist.
DUOI_NETLIST = {".net", ".xml"}
DUOI_SCHEMATIC = {".kicad_sch", ".sch"}


@capability("extract.kicad_netlist")
def kicad_netlist(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-16 — CDS-12.2; SEC-25 §2 (sandbox). tc: TC-20 ≥ 95%; lỗi E4001.

    Netlist là **nguồn tầng vàng cho một board**: nó do chính người thiết kế mạch xuất ra, nên
    "chân nào nối vào net nào" ở đây chắc chắn hơn mọi thứ đọc được từ ảnh hay từ README. Đó là
    lý do fact sinh ra ở đây mang tier `gold` còn `extract.image_schematic` thì không.

    `kicad-cli` chỉ cần khi đầu vào là sơ đồ nguồn (`.kicad_sch`). Một tệp `.net` hay kicadxml
    đã là netlist rồi — bắt cài cả bộ KiCad để đọc một tệp s-expression là dựng một rào cản
    không có lý do.

    **Tên board:** `name` nếu bên gọi nêu, không thì tên tệp. Hai đường đều cần: tên tệp netlist
    thường là tên bản vẽ (`robot.net`), còn `board.build_passport` hỏi theo tên board
    (`robot-main`) — không thống nhất được thì hộ chiếu dựng xong mà bước sau báo "chưa có net".
    EXTRACT-16 v1.3 mới có `name`; trước đó hiện thực nhận nó mà router chặn bằng E1000, tức
    một tham số không ai dùng được. Xem [DEV-066].
    """
    root = _root(ctx)
    p = Path(params["file"]).expanduser()
    if not p.is_file():
        raise EideError("E2000", f"Không có tệp {p}", exists=[], candidates=[], missing=[str(p)])

    if p.suffix.lower() in DUOI_SCHEMATIC:
        p = _xuat_netlist(p, ctx)
    elif p.suffix.lower() not in DUOI_NETLIST:
        raise EideError("E6001", f"`{p.name}` không phải netlist ({sorted(DUOI_NETLIST)}) hay "
                        f"sơ đồ KiCad ({sorted(DUOI_SCHEMATIC)})", file=str(p))

    parts, nets = doc_netlist(p)
    if not nets:
        raise EideError("E6001", f"Không đọc được net nào từ {p.name} — tệp rỗng hay sai định dạng?",
                        file=str(p), parts=len(parts))

    sid = _bao_dam_source(root, p, "netlist", "gold")
    ten = params.get("name") or p.stem
    bid = f"board:{re.sub(r'[^A-Za-z0-9_.-]+', '-', ten).lower()}"
    pid = f"{bid.split(':', 1)[1]}@1.0.0"
    facts = _facts_netlist(bid, parts, nets, sid)

    from eide.caps.passport import import_
    import_({"batch": {"facts": facts, "passport_id": pid,
                       "kind": "board", "reason": f"extract.kicad_netlist {p.name}",
                       "header": {"name": ten, "source": p.name, "parts": len(parts)}},
             "actor": ctx.actor}, ctx)
    return {"board_passport_id": pid, "nets": len(nets), "parts": len(parts)}


def _xuat_netlist(p: Path, ctx: Context) -> Path:
    """`.kicad_sch` → netlist, qua `kicad-cli` trong sandbox (bước 1 của hợp đồng)."""
    from eide.caps.env import sandbox as env_sandbox
    from eide_core import tools
    exe = tools.which("kicad-cli")
    if exe is None:
        raise EideError("E4001", "Đầu vào là sơ đồ nguồn KiCad nên cần `kicad-cli` để xuất "
                        "netlist. Có sẵn tệp `.net`/`.xml` thì truyền thẳng tệp ấy — không cần "
                        "cài gì.", missing=["kicad-cli"], remedy="env.install", file=str(p))
    ra = p.with_suffix(".net")
    kq = env_sandbox({"cmd": [str(exe), "sch", "export", "netlist", "--format", "kicadxml",
                              "-o", str(ra), str(p)],
                      "network": False, "allowed_dirs": [str(p.parent)],
                      "limits": {"wall_s": 300}}, ctx)
    if kq["exit_code"] != 0 or not ra.exists():
        raise EideError("E4000", f"`kicad-cli` không xuất được netlist từ {p.name}",
                        exit_code=kq["exit_code"], log=kq["stderr_ref"])
    return ra


def doc_netlist(p: Path) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, str]]]]:
    """`(parts, nets)` từ một tệp netlist. Nhận cả kicadxml lẫn s-expression."""
    noi_dung = p.read_text(encoding="utf-8", errors="replace")
    if noi_dung.lstrip().startswith("<"):
        return _netlist_xml(noi_dung)
    return _netlist_sexp(noi_dung)


def _netlist_xml(noi_dung: str) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, str]]]]:
    goc = ET.fromstring(noi_dung)  # noqa: S314 — netlist do người dùng xuất, không phải mạng
    parts = {}
    for c in goc.findall(".//components/comp"):
        ref = c.get("ref") or ""
        if ref:
            parts[ref] = {"ref": ref, "value": _text(c, "value"),
                          "footprint": _text(c, "footprint"), "mpn": _mpn_xml(c)}
    nets: dict[str, list[dict[str, str]]] = {}
    for n in goc.findall(".//nets/net"):
        ten = n.get("name") or f"Net-{n.get('code')}"
        nets[ten] = [{"ref": nd.get("ref") or "", "pin": nd.get("pin") or ""}
                     for nd in n.findall("node")]
    return parts, nets


def _mpn_xml(c: ET.Element) -> str | None:
    for f in c.findall(".//fields/field"):
        if (f.get("name") or "").lower() in ("mpn", "manufacturer part number", "part number"):
            return (f.text or "").strip() or None
    return None


# S-expression: đủ cho netlist KiCad, không phải trình phân tích Lisp đầy đủ. Netlist chỉ dùng
# danh sách lồng và chuỗi trong nháy kép — không có ký tự thoát phức tạp, không có số thực đặc
# biệt, nên một máy trạng thái nhỏ là đủ và không kéo thêm phụ thuộc nào.
def _sexp(s: str) -> Any:
    i, n = 0, len(s)
    ngan_xep: list[list[Any]] = [[]]
    while i < n:
        c = s[i]
        if c == "(":
            moi: list[Any] = []
            ngan_xep[-1].append(moi)
            ngan_xep.append(moi)
        elif c == ")":
            if len(ngan_xep) > 1:
                ngan_xep.pop()
        elif c == '"':
            j = i + 1
            ra = []
            while j < n and s[j] != '"':
                if s[j] == "\\" and j + 1 < n:
                    j += 1
                ra.append(s[j])
                j += 1
            ngan_xep[-1].append("".join(ra))
            i = j
        elif not c.isspace():
            j = i
            while j < n and not s[j].isspace() and s[j] not in "()":
                j += 1
            ngan_xep[-1].append(s[i:j])
            i = j - 1
        i += 1
    return ngan_xep[0]


def _lay(node: list[Any], ten: str) -> list[Any]:
    return [x for x in node if isinstance(x, list) and x and x[0] == ten]


def _gia_tri(node: list[Any], ten: str) -> str | None:
    ds = _lay(node, ten)
    return str(ds[0][1]) if ds and len(ds[0]) > 1 else None


def _netlist_sexp(noi_dung: str) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, str]]]]:
    cay = _sexp(noi_dung)
    goc = cay[0] if cay and isinstance(cay[0], list) else []
    parts: dict[str, dict[str, Any]] = {}
    for kh in _lay(goc, "components"):
        for c in _lay(kh, "comp"):
            if (ref := _gia_tri(c, "ref")):
                parts[ref] = {"ref": ref, "value": _gia_tri(c, "value"),
                              "footprint": _gia_tri(c, "footprint"), "mpn": _mpn_sexp(c)}
    nets: dict[str, list[dict[str, str]]] = {}
    for kh in _lay(goc, "nets"):
        for nt in _lay(kh, "net"):
            ten = _gia_tri(nt, "name") or f"Net-{_gia_tri(nt, 'code')}"
            nets[ten] = [{"ref": _gia_tri(nd, "ref") or "", "pin": _gia_tri(nd, "pin") or ""}
                         for nd in _lay(nt, "node")]
    return parts, nets


def _mpn_sexp(c: list[Any]) -> str | None:
    for kh in _lay(c, "fields"):
        for f in _lay(kh, "field"):
            ten = next((str(x[1]) for x in f if isinstance(x, list) and x and x[0] == "name"
                        and len(x) > 1), "")
            if ten.lower() in ("mpn", "manufacturer part number", "part number"):
                return str(f[-1]) if len(f) > 1 and isinstance(f[-1], str) else None
    return None


def _facts_netlist(bid: str, parts: dict[str, dict[str, Any]],
                   nets: dict[str, list[dict[str, str]]], sid: str) -> list[dict[str, Any]]:
    """Mỗi net một fact `net`, mỗi linh kiện một fact `package`.

    Chủ thể của fact `net` là `board:<tên>/net:<tên net>` — nối được về board mà vẫn phân biệt
    được từng net, nên `board.check_pins` tra thẳng bằng `subject LIKE` thay vì phải giải nén
    một fact khổng lồ chứa cả sơ đồ.
    """
    ra: list[dict[str, Any]] = []
    for ten, nodes in sorted(nets.items()):
        ra.append({"subject": f"{bid}/net:{ten}", "predicate": "net",
                   "value": {"name": ten, "nodes": nodes}, "source_id": sid,
                   "method": "parser", "tier": "gold", "confidence": 1.0,
                   "locator": f"net:{ten}"})
    for ref, pt in sorted(parts.items()):
        ra.append({"subject": f"{bid}/part:{ref}", "predicate": "package",
                   "value": {k: v for k, v in pt.items() if v}, "source_id": sid,
                   "method": "parser", "tier": "gold", "confidence": 1.0,
                   "locator": f"comp:{ref}"})
    return ra


# ================================================================ D3 — đường ẢNH
#
# Bốn năng lực dưới đây là nhóm DUY NHẤT trong `extract.*` nhìn thấy hình. Ba điều chung, và cả
# ba đến thẳng từ hợp đồng:
#
# 1. **`method = vision_llm`.** G-FACT-02 loại riêng phương pháp ấy khỏi tự duyệt, nên mọi fact
#    sinh ra ở đây vào hàng đợi hỏi người — `tier = T2`, `ask_when: "Luôn"`. Đó không phải sự
#    thận trọng thừa: một tên chân đọc nhầm từ ảnh schematic trông y hệt một tên chân đọc đúng.
# 2. **bbox là BẰNG CHỨNG.** Mỗi thứ đọc được kèm toạ độ trong ảnh, để người duyệt mở hình ra
#    và nhìn đúng chỗ. Một đề xuất không có bbox thì người duyệt phải tin hoặc tự dò lại từ đầu.
# 3. **Không đọc được thì NÓI RA.** `unreadable[]` là một phần của hợp đồng EXTRACT-13, không
#    phải một chỗ để trống. Một schematic mờ trả về 3 net và im lặng về 20 net còn lại thì
#    người đọc tưởng bo mạch chỉ có 3 net.

# Ảnh to hơn ngần này thì từ chối — hãng đặt trần ~5 MB cho ảnh inline, và một ảnh 20 MB gửi đi
# chỉ để nhận lại lỗi HTTP là một lượt gọi tốn tiền mà không ai học được gì.
TRAN_ANH_MB = 5

MIME_ANH = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".webp": "image/webp", ".gif": "image/gif"}


def _doc_anh(root: Path, duong: str) -> dict[str, str]:
    """Tệp ảnh → `{media_type, data}` base64, dạng chung của cả Gemini lẫn Claude."""
    import base64

    f = Path(duong).expanduser()
    if not f.is_absolute():
        f = root / f
    if not f.is_file():
        raise EideError("E2000", f"Không có tệp ảnh {f}", exists=[], candidates=[],
                        missing=[str(f)])
    mime = MIME_ANH.get(f.suffix.lower())
    if mime is None:
        raise EideError("E1000", f"Đuôi `{f.suffix}` không phải ảnh — nhận "
                        f"{sorted(MIME_ANH)}", file=str(f))
    b = f.read_bytes()
    if len(b) > TRAN_ANH_MB * 1024 * 1024:
        raise EideError("E1000", f"Ảnh {len(b) / 1024**2:.1f} MB vượt trần {TRAN_ANH_MB} MB — "
                        "thu nhỏ trước khi gửi", file=str(f), size_mb=round(len(b) / 1024**2, 1))
    return {"media_type": mime, "data": base64.b64encode(b).decode("ascii")}


_SCHEMA_OCR = {
    "type": "object",
    "properties": {"text_blocks": {"type": "array", "items": {
        "type": "object",
        "properties": {"text": {"type": "string"},
                       "bbox": {"type": "array", "items": {"type": "number"}},
                       "confidence": {"type": "number"}},
        "required": ["text"], "additionalProperties": False}}},
    "required": ["text_blocks"], "additionalProperties": False,
}


@capability("extract.ocr")
def ocr(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-12 — CDS-12.2. R1, `errors: [E4001]`, `undo: none`.

    Hai đường, ưu tiên `tesseract` nếu máy có: OCR cục bộ **không tốn token và không gửi ảnh ra
    ngoài**, và một trang datasheet scan là tài liệu có thể đang dưới NDA. Chỉ khi không có mới
    gọi vai trò `cartographer`.

    **`confidence − 0,1`** đúng như bước 1 của hợp đồng, ở CẢ HAI đường. Chữ đọc từ ảnh luôn
    kém chắc hơn chữ đọc từ PDF có lớp text, và trừ đi ở đây là chỗ duy nhất phép trừ ấy không
    bị quên.
    """
    root = _root(ctx)
    f = Path(params["file"])
    if not f.is_absolute():
        f = root / f

    if tools.which("tesseract"):
        return {"text_blocks": _ocr_tesseract(root, f, params.get("lang") or "vie+eng", ctx)}

    anh = _doc_anh(root, str(f))
    resp = _gateway(ctx).run(
        "cartographer",
        "Đọc TOÀN BỘ chữ trong ảnh. Mỗi khối văn bản một mục, kèm `bbox` [x0,y0,x1,y1] theo tỉ "
        "lệ 0–1 của ảnh. Không diễn giải, không tóm tắt — chép đúng chữ nhìn thấy.",
        _SCHEMA_OCR, anh=[anh])
    kh = []
    for b in (resp.data.get("text_blocks") or []):
        kh.append({**b, "method": "vision_llm",
                   "confidence": round(max(0.0, float(b.get("confidence") or 0.8) - 0.1), 3)})
    return {"text_blocks": kh}


def _ocr_tesseract(root: Path, f: Path, lang: str, ctx: Context) -> list[dict[str, Any]]:
    """Đường cục bộ. TSV của tesseract cho bbox theo pixel; quy về tỉ lệ 0–1 để trùng dạng với
    đường vision — hai đường trả hai hệ toạ độ là hai chỗ bên gọi phải nhớ."""
    from eide.caps.env import chay_sandbox

    duong = str(tools.which("tesseract"))
    r = chay_sandbox([duong, str(f), "stdout", "-l", lang, "tsv"], ctx, network=False,
                     allowed_dirs=[str(root)], cwd=str(root),
                     them_path=[str(Path(duong).parent)], limits={"wall_s": 120})
    if r["exit_code"] != 0:
        raise EideError("E4001", f"`tesseract` trả mã {r['exit_code']} — nhật ký: "
                        f"{r['stderr_ref']}", missing=["tesseract"], log=r["stderr_ref"])
    dong = Path(r["stdout_ref"]).read_text(encoding="utf-8", errors="replace").splitlines()
    if not dong:
        return []
    cot = dong[0].split("\t")
    ra = []
    for d in dong[1:]:
        o = dict(zip(cot, d.split("\t"), strict=False))
        van = (o.get("text") or "").strip()
        if not van:
            continue
        try:
            x, y, w, h = (int(o[k]) for k in ("left", "top", "width", "height"))
            c = float(o.get("conf") or 0) / 100.0
        except (KeyError, ValueError):
            continue
        ra.append({"text": van, "bbox": [x, y, x + w, y + h], "method": "parser",
                   "confidence": round(max(0.0, c - 0.1), 3)})
    return ra


_SCHEMA_NET = {
    "type": "object",
    "properties": {
        "nets": {"type": "array", "items": {
            "type": "object",
            "properties": {"name": {"type": "string"},
                           "pins": {"type": "array", "items": {"type": "string"}},
                           "bbox": {"type": "array", "items": {"type": "number"}},
                           "confidence": {"type": "number"}},
            "required": ["name", "pins"], "additionalProperties": False}},
        "unreadable": {"type": "array", "items": {
            "type": "object",
            "properties": {"reason": {"type": "string"},
                           "bbox": {"type": "array", "items": {"type": "number"}}},
            "required": ["reason"], "additionalProperties": False}},
    },
    "required": ["nets"], "additionalProperties": False,
}


@capability("extract.image_schematic")
def image_schematic(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-13 — CDS-12.2; POL-17 G-FACT-02. R1, tier **T2**, `errors: [E5002]`,
    ask "Luôn (đề xuất)", `undo: none`.

    **Luôn là ĐỀ XUẤT, không bao giờ là kết luận.** T2 nghĩa là mọi lần gọi đều hỏi người, và
    fact ghi ra mang `method=vision_llm` + `status=normalized` — G-FACT-02 loại riêng
    `vision_llm` khỏi tự duyệt. Một tên chân đọc nhầm từ ảnh trông y hệt một tên chân đọc đúng,
    và nó sẽ đi thẳng vào `code.generate_module` nếu ta để nó tự duyệt.

    **`unreadable[]` là một phần của hợp đồng.** Một schematic mờ trả về 3 net rồi im lặng về 20
    net còn lại thì người đọc tưởng bo mạch chỉ có 3 net — tệ hơn hẳn việc nói "chỗ này không
    đọc được".

    Đối chiếu tên chân với hộ chiếu ghim: chân nào không có trong hộ chiếu thì đánh dấu, chứ
    không loại bỏ. Mô hình có thể đọc đúng một chân mà hộ chiếu chưa trích.
    """
    root = _root(ctx)
    anh = _doc_anh(root, params["image"])
    goi_y = params.get("part_hint") or ""

    resp = _gateway(ctx).run(
        "cartographer",
        "Đọc sơ đồ nguyên lý trong ảnh. Liệt kê các NET (đường nối) cùng danh sách chân nối vào "
        "chúng, dạng `U1.PB6` hoặc `R3.1`. Mỗi net kèm `bbox` [x0,y0,x1,y1] tỉ lệ 0–1.\n"
        "**Chỗ nào không đọc được thì ghi vào `unreadable` kèm lý do — ĐỪNG đoán.** Một net bịa "
        "ra nguy hiểm hơn một net thiếu.\n"
        + (f"Gợi ý linh kiện chính: {goi_y}\n" if goi_y else ""),
        _SCHEMA_NET, anh=[anh])

    nets = list(resp.data.get("nets") or [])
    if not nets and not (resp.data.get("unreadable") or []):
        raise EideError("E5002", "Mô hình không đọc được net nào và cũng không nói chỗ nào "
                        "không đọc được — không dùng được kết quả này", image=params["image"])

    chan_ho_chieu = _chan_trong_ho_chieu(root)
    for n in nets:
        n["method"] = "vision_llm"
        n["status"] = "normalized"
        n["confidence"] = round(float(n.get("confidence") or 0.5), 3)
        n["pins_unknown"] = [p for p in (n.get("pins") or [])
                             if chan_ho_chieu and p.split(".")[-1].upper() not in chan_ho_chieu]

    pid = "prop_" + hashlib.sha256(
        (params["image"] + json.dumps(nets, ensure_ascii=False)).encode()).hexdigest()[:16]
    return {"proposal_id": pid, "nets": nets,
            "unreadable": list(resp.data.get("unreadable") or [])}


def _chan_trong_ho_chieu(root: Path) -> set[str]:
    db = store.store_path(root)
    if not db.exists():
        return set()
    with store.open_store(db) as c:
        rows = c.execute("SELECT subject FROM fact WHERE predicate = 'pin_function'").fetchall()
    return {str(r[0]).rsplit(":", 1)[-1].upper() for r in rows}


_SCHEMA_BOARD = {
    "type": "object",
    "properties": {"parts": {"type": "array", "items": {
        "type": "object",
        "properties": {"label": {"type": "string"}, "mpn_guess": {"type": "string"},
                       "bbox": {"type": "array", "items": {"type": "number"}},
                       "ports": {"type": "array", "items": {"type": "string"}},
                       "confidence": {"type": "number"}},
        "required": ["label"], "additionalProperties": False}}},
    "required": ["parts"], "additionalProperties": False,
}


@capability("extract.image_board")
def image_board(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-14 — CDS-12.2. R1, tier **T2**, `errors: [E5002]`, ask "Luôn".

    Đọc nhãn in trên chip rồi đối chiếu với hộ chiếu đã có (`passport.list`). Nhãn trên chip
    thật thường bị cắt — `STM32F411` in đầy đủ nhưng `CEU6` ở dòng dưới nhỏ xíu — nên `mpn_guess`
    là ĐOÁN, và `matched_passport` cho biết đoán ấy có trùng hộ chiếu nào trong dự án không.

    Trùng thì tin hơn nhiều: người dùng đã trích datasheet của đúng con chip ấy, nên nhãn đọc
    được khớp với thứ họ đang làm — chứ không phải với một con chip cùng họ.
    """
    root = _root(ctx)
    anh = _doc_anh(root, params["image"])
    resp = _gateway(ctx).run(
        "cartographer",
        "Đọc ảnh chụp bo mạch. Liệt kê linh kiện nhìn thấy: `label` là chữ IN TRÊN linh kiện "
        "(chép đúng, kể cả khi cụt), `mpn_guess` là mã hàng đầy đủ nếu đoán được, `bbox` tỉ lệ "
        "0–1, `ports` là các cổng/đầu nối nhận ra được. Đọc được chữ nào chép chữ ấy — đừng "
        "suy ra mã hàng từ hình dáng linh kiện.",
        _SCHEMA_BOARD, anh=[anh])

    ds = list(resp.data.get("parts") or [])
    if not ds:
        raise EideError("E5002", "Mô hình không đọc được linh kiện nào trong ảnh",
                        image=params["image"])
    co = _ho_chieu_da_co(root)
    for p in ds:
        p["method"] = "vision_llm"
        p["confidence"] = round(float(p.get("confidence") or 0.5), 3)
        mpn = str(p.get("mpn_guess") or p.get("label") or "").upper().replace("-", "")
        p["matched_passport"] = next(
            (x for x in co if mpn and (mpn in x.upper().replace("-", "")
                                       or x.upper().replace("-", "") in mpn)), None)
    return {"parts": ds}


def _ho_chieu_da_co(root: Path) -> list[str]:
    db = store.store_path(root)
    if not db.exists():
        return []
    with store.open_store(db) as c:
        return [r[0] for r in c.execute("SELECT id FROM passport").fetchall()]


_SCHEMA_SCOPE = {
    "type": "object",
    "properties": {
        "values": {"type": "array", "items": {
            "type": "object",
            "properties": {"name": {"type": "string"}, "value": {"type": "number"},
                           "unit": {"type": "string"}},
            "required": ["name", "value"], "additionalProperties": False}},
        "scales": {"type": "object",
                   "properties": {"time_per_div": {"type": "string"},
                                  "volt_per_div": {"type": "string"}},
                   "additionalProperties": False},
        "note": {"type": "string"},
    },
    "required": ["values"], "additionalProperties": False,
}


@capability("extract.image_scope")
def image_scope(params: dict[str, Any], ctx: Context) -> dict[str, Any]:
    """Spec: EXTRACT-15 — CDS-12.2; DDD-14 §2 Measurement. R1, tier **T2**, `errors: []`,
    ask "Luôn". Mốc M5.

    **Tạo `Measurement`, KHÔNG tạo fact** — bước 1 của hợp đồng nói thẳng, và đó là ranh giới
    quan trọng nhất của năng lực này. Một giá trị đọc từ ảnh màn hình dao động ký là một QUAN
    SÁT, không phải một sự thật về con chip: nó đúng cho lần đo ấy, trên board ấy, với đầu dò
    đặt ở chỗ ấy. Thành fact thì `code.constant_guard` sẽ cho phép mã trích dẫn nó như thể
    datasheet nói thế.

    `confidence` thấp và ghi thẳng vào bản ghi. Đọc một con số từ lưới ô trên ảnh chụp màn hình
    có sai số của cả người chụp lẫn mô hình, và giấu điều đó đi là mời người ta tin một con số
    không ai đo lại.
    """
    root = _root(ctx)
    anh = _doc_anh(root, params["image"])
    loai = params.get("kind") or "oscilloscope"
    resp = _gateway(ctx).run(
        "cartographer",
        f"Ảnh chụp màn hình thiết bị đo ({loai}). Đọc thang đo (time/div, volt/div) và các giá "
        "trị hiện trên màn hình. Chỉ chép con số NHÌN THẤY — nếu phải suy từ số ô trên lưới thì "
        "ghi vào `note` rằng đó là ước lượng.",
        _SCHEMA_SCOPE, anh=[anh])

    mid = "m_" + hashlib.sha256(
        (params["image"] + json.dumps(resp.data, ensure_ascii=False)).encode()).hexdigest()[:16]
    do = {"id": mid, "kind": "custom", "value": resp.data.get("values") or [],
          "scales": resp.data.get("scales") or {}, "note": resp.data.get("note"),
          "method": "vision_llm", "confidence": 0.3, "source_image": params["image"],
          "at": datetime.now(UTC).isoformat()}

    db = store.store_path(root)
    if db.exists():
        with store.open_store(db) as c:
            c.execute("INSERT OR REPLACE INTO measurement (id, kind, value, at) "
                      "VALUES (?,?,?,?)",
                      (mid, "custom", json.dumps(do, ensure_ascii=False), do["at"]))
            c.commit()
        store.write_seal(db, ctx.extra.get("ledger"))
    return {"measurement": do}
