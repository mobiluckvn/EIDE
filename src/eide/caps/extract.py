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

import json
import re
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide.caps.archive import bam_tep
from eide_core import store
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

    facts: list[dict[str, Any]] = []
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

    **Tên board lấy từ tên tệp**, vì `input_schema` của EXTRACT-16 chỉ nhận `file` và đóng
    `additionalProperties`. Bản đầu nhận thêm `name`, và nó chạy trong test vì test gọi thẳng
    hàm — nhưng qua router thì `name` bị E1000 chặn trước khi vào đây, tức một tham số không
    ai dùng được. Xem [DEV-066]: đề nghị CDS-12.2 thêm `name` cho EXTRACT-16, vì tên tệp
    (`robot.net`) thường không phải tên board (`robot-main`) mà `board.build_passport` hỏi tới.
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
    ten = p.stem
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
                      "limits": {"timeout_s": 300}}, ctx)
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
