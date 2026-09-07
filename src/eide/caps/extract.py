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
